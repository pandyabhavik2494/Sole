import Foundation
import HealthKit

/// One hour's low and high heart rate.
struct HourRange: Hashable, Sendable {
    var hour: Date
    var min: Double
    var max: Double
}

/// Reads Sole's v2 metrics from Apple Health as daily statistics, and writes weight.
///
/// Every query is a statistics query (Health aggregates on its side and dedupes overlapping
/// sources by the user's priority); raw heart-rate samples are never loaded. Methods are
/// `@concurrent`, so they run off the main actor whoever calls them, and return value types.
final class HealthMetricsService: Sendable {
    let healthStore: HKHealthStore

    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: Types

    static func quantityType(for metric: Metric) -> HKQuantityType? {
        switch metric {
        case .steps: HKQuantityType(.stepCount)
        case .restingHeartRate: HKQuantityType(.restingHeartRate)
        case .walkingHeartRate: HKQuantityType(.walkingHeartRateAverage)
        case .heartRate: HKQuantityType(.heartRate)
        case .activeEnergy: HKQuantityType(.activeEnergyBurned)
        case .restingEnergy: HKQuantityType(.basalEnergyBurned)
        case .bloodOxygen: HKQuantityType(.oxygenSaturation)
        case .weight: HKQuantityType(.bodyMass)
        }
    }

    /// The canonical unit Sole stores, and the factor that turns HealthKit's value into it.
    private static func unit(for metric: Metric) -> (unit: HKUnit, scale: Double) {
        switch metric {
        case .steps: (.count(), 1)
        case .restingHeartRate, .walkingHeartRate, .heartRate: (.count().unitDivided(by: .minute()), 1)
        case .activeEnergy, .restingEnergy: (.kilocalorie(), 1)
        // HealthKit stores oxygen saturation as a fraction (0.97); Sole shows percent.
        case .bloodOxygen: (.percent(), 100)
        case .weight: (.gramUnit(with: .kilo), 1)
        }
    }

    private static let sleepType = HKCategoryType(.sleepAnalysis)

    /// v1's step types plus everything v2 reads. Asked for in one sheet.
    static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.stepCount), HKQuantityType(.distanceWalkingRunning), HKQuantityType(.flightsClimbed), sleepType,
        ]
        for metric in Metric.fromHealth {
            if let type = quantityType(for: metric) { types.insert(type) }
        }
        return types
    }

    static var shareTypes: Set<HKSampleType> {
        [HKQuantityType(.stepCount), HKQuantityType(.distanceWalkingRunning), HKQuantityType(.flightsClimbed), HKQuantityType(.bodyMass)]
    }

    // MARK: Authorization

    func requestAuthorization() async throws {
        try await healthStore.requestAuthorization(toShare: Self.shareTypes, read: Self.readTypes)
    }

    /// Whether the v2 permission sheet has been shown. Health never says whether read access was
    /// granted, only whether it has asked.
    func hasRequestedAuthorization() async -> Bool {
        guard Self.isAvailable else { return false }
        let status = try? await healthStore.statusForAuthorizationRequest(toShare: Self.shareTypes, read: Self.readTypes)
        return status == .unnecessary
    }

    var canWriteWeight: Bool {
        healthStore.authorizationStatus(for: HKQuantityType(.bodyMass)) == .sharingAuthorized
    }

    // MARK: Daily statistics

    /// One value per day with data, for days starting at local midnight from `start` up to `end`.
    @concurrent
    func dailyValues(for metric: Metric, from start: Date, to end: Date, calendar: Calendar) async throws -> [DailyValue] {
        guard let type = Self.quantityType(for: metric), start < end else { return [] }
        let options: HKStatisticsOptions = switch metric {
        case .steps, .activeEnergy, .restingEnergy: .cumulativeSum
        case .weight: .mostRecent
        default: [.discreteAverage, .discreteMin, .discreteMax]
        }
        let anchor = calendar.startOfDay(for: start)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: anchor, end: end)),
            options: options,
            anchorDate: anchor,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: healthStore)
        let (unit, scale) = Self.unit(for: metric)

        var values: [DailyValue] = []
        collection.enumerateStatistics(from: anchor, to: end) { statistics, _ in
            let day = DayKey(statistics.startDate, calendar: calendar)
            let value: Double?
            switch metric {
            case .steps, .activeEnergy, .restingEnergy:
                value = statistics.sumQuantity()?.doubleValue(for: unit)
            case .weight:
                value = statistics.mostRecentQuantity()?.doubleValue(for: unit)
            default:
                value = statistics.averageQuantity()?.doubleValue(for: unit)
            }
            guard let value, value > 0 else { return }
            values.append(DailyValue(
                day: day,
                metric: metric,
                value: value * scale,
                min: statistics.minimumQuantity().map { $0.doubleValue(for: unit) * scale },
                max: statistics.maximumQuantity().map { $0.doubleValue(for: unit) * scale }
            ))
        }
        return values
    }

    /// Hourly totals of a cumulative metric (for "usual pace"), keyed by the hour's start.
    @concurrent
    func hourlySums(for metric: Metric, from start: Date, to end: Date, calendar: Calendar) async throws -> [Date: Double] {
        guard metric.isCumulative, let type = Self.quantityType(for: metric), start < end else { return [:] }
        let anchor = calendar.startOfDay(for: start)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: anchor, end: end)),
            options: .cumulativeSum,
            anchorDate: anchor,
            intervalComponents: DateComponents(hour: 1)
        )
        let collection = try await descriptor.result(for: healthStore)
        let unit = Self.unit(for: metric).unit
        var sums: [Date: Double] = [:]
        collection.enumerateStatistics(from: anchor, to: end) { statistics, _ in
            if let sum = statistics.sumQuantity()?.doubleValue(for: unit), sum > 0 {
                sums[statistics.startDate] = sum
            }
        }
        return sums
    }

    /// Heart rate low and high for each hour with readings, for "when it peaked".
    @concurrent
    func hourlyHeartRate(from start: Date, to end: Date) async throws -> [HourRange] {
        guard start < end else { return [] }
        let type = HKQuantityType(.heartRate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
            options: [.discreteMin, .discreteMax],
            anchorDate: start,
            intervalComponents: DateComponents(hour: 1)
        )
        let collection = try await descriptor.result(for: healthStore)
        let unit = HKUnit.count().unitDivided(by: .minute())
        var hours: [HourRange] = []
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            if let low = statistics.minimumQuantity()?.doubleValue(for: unit),
               let high = statistics.maximumQuantity()?.doubleValue(for: unit) {
                hours.append(HourRange(hour: statistics.startDate, min: low, max: high))
            }
        }
        return hours
    }

    // MARK: Sleep

    /// Asleep intervals (any stage) that overlap the window, from every source. Overlaps between
    /// sources are resolved by `SleepMath`, not here.
    @concurrent
    func asleepIntervals(from start: Date, to end: Date) async throws -> [DateInterval] {
        let asleep: Set<Int> = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: Self.sleepType, predicate: HKQuery.predicateForSamples(withStart: start, end: end))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: healthStore)
        return samples
            .filter { asleep.contains($0.value) && $0.endDate > $0.startDate }
            .map { DateInterval(start: $0.startDate, end: $0.endDate) }
    }

    // MARK: Sources and units

    /// Names of the apps and devices that recorded a metric, such as "Bhavik's Apple Watch".
    @concurrent
    func sourceNames(for metric: Metric) async throws -> [String] {
        guard let type = Self.quantityType(for: metric) else { return [] }
        let descriptor = HKSourceQueryDescriptor(predicate: .quantitySample(type: type))
        return try await descriptor.result(for: healthStore).map(\.name).sorted()
    }

    /// Mass and energy units chosen in the Health app.
    @concurrent
    func preferredUnits() async -> UnitPreferences {
        let mass = HKQuantityType(.bodyMass)
        let energy = HKQuantityType(.activeEnergyBurned)
        let units = try? await healthStore.preferredUnits(for: [mass, energy])
        let fallback = UnitPreferences(mass: Locale.current.measurementSystem == .us ? .pounds : .kilograms, energy: .kilocalories)
        return UnitPreferences(massUnitString: units?[mass]?.unitString, energyUnitString: units?[energy]?.unitString, fallback: fallback)
    }

    /// The earliest date Health allows apps to read.
    var earliestPermittedDate: Date { healthStore.earliestPermittedSampleDate() }

    // MARK: Writing

    /// Saves a weight reading (kilograms) to Health.
    func saveWeight(kilograms: Double, at date: Date) async throws {
        let type = HKQuantityType(.bodyMass)
        let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kilograms), start: date, end: date)
        try await healthStore.save(sample)
    }

    // MARK: Background updates

    /// Calls `onChange` whenever any v2 metric or sleep changes in Health, including in the
    /// background. Heart types are delivered at most hourly. Must be set up at launch.
    func observeChanges(_ onChange: @escaping @MainActor @Sendable () async -> Void) {
        var types: [HKSampleType] = Metric.fromHealth.compactMap(Self.quantityType(for:))
        types.append(Self.sleepType)
        for type in types {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                guard error == nil else { completion(); return }
                // HealthKit allows the completion handler to be called from any thread.
                let done = UncheckedSendable(completion)
                Task { @MainActor in
                    await onChange()
                    done.value()
                }
            }
            healthStore.execute(query)
            healthStore.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }
}
