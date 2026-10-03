import Foundation
import HealthKit

/// Two-way sync with Apple Health.
///
/// - Reads hourly steps, distance and flights from every source except Sole (Apple Watch, other
///   apps, the iPhone's own history). Statistics queries let Health dedupe overlapping sources by
///   the user's source priority, exactly as the Health app does.
/// - Writes Sole's own hourly sensor counts back. Each sample carries a sync identifier for its
///   hour, so rewriting an hour replaces the earlier sample instead of adding a second one.
final class HealthService: Sendable {
    let healthStore = HKHealthStore()

    private let stepType = HKQuantityType(.stepCount)
    private let distanceType = HKQuantityType(.distanceWalkingRunning)
    private let flightsType = HKQuantityType(.flightsClimbed)
    private var allTypes: Set<HKQuantityType> { [stepType, distanceType, flightsType] }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Asks for v1's step types and v2's metrics in one sheet, so the user sees it once.
    func requestAuthorization() async throws {
        try await healthStore.requestAuthorization(toShare: HealthMetricsService.shareTypes, read: HealthMetricsService.readTypes)
    }

    /// Whether the permission sheet has already been shown. Health never tells an app whether
    /// read access was granted, only whether it has asked.
    func hasRequestedAuthorization() async -> Bool {
        guard Self.isAvailable else { return false }
        let status = try? await healthStore.statusForAuthorizationRequest(toShare: allTypes, read: allTypes)
        return status == .unnecessary
    }

    var canWriteSteps: Bool {
        healthStore.authorizationStatus(for: stepType) == .sharingAuthorized
    }

    // MARK: Reading

    /// Hourly totals from every source except Sole, for whole hours from `start` to `end`.
    func hourlyTotals(from start: Date, to end: Date) async throws -> [HourSample] {
        async let steps = hourlySums(of: stepType, unit: .count(), from: start, to: end)
        async let distance = hourlySums(of: distanceType, unit: .meter(), from: start, to: end)
        async let flights = hourlySums(of: flightsType, unit: .count(), from: start, to: end)
        let (stepSums, distanceSums, flightSums) = try await (steps, distance, flights)

        let hours = Set(stepSums.keys).union(distanceSums.keys).union(flightSums.keys)
        return hours.sorted().map { hour in
            HourSample(
                hour: hour,
                steps: Int((stepSums[hour] ?? 0).rounded()),
                distanceMeters: distanceSums[hour] ?? 0,
                floors: Int((flightSums[hour] ?? 0).rounded())
            )
        }
    }

    /// When the oldest step sample from any source other than Sole begins, or nil when there is none.
    func earliestStepDate() async throws -> Date? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: stepType, predicate: notSole)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: 1
        )
        return try await descriptor.result(for: healthStore).first?.startDate
    }

    private var notSole: NSPredicate {
        NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: HKSource.default()))
    }

    private func hourlySums(of type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date) async throws -> [Date: Double] {
        let inRange = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [inRange, notSole])),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(hour: 1)
        )
        let collection = try await descriptor.result(for: healthStore)
        var sums: [Date: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
            if let sum = statistics.sumQuantity()?.doubleValue(for: unit), sum > 0 {
                sums[statistics.startDate] = sum
            }
        }
        return sums
    }

    // MARK: Writing

    /// Saves Sole's sensor counts for completed hours, replacing anything Sole saved for those hours before.
    func save(_ hours: [HourSample], calendar: Calendar = .current) async throws {
        let version = Int(Date.now.timeIntervalSince1970)
        var samples: [HKQuantitySample] = []

        for hour in hours {
            guard let end = calendar.date(byAdding: .hour, value: 1, to: hour.hour) else { continue }
            func metadata(_ kind: String) -> [String: Any] {
                [
                    HKMetadataKeySyncIdentifier: "sole.\(kind).\(Int(hour.hour.timeIntervalSince1970))",
                    HKMetadataKeySyncVersion: version,
                ]
            }
            if hour.steps > 0 {
                samples.append(HKQuantitySample(type: stepType, quantity: HKQuantity(unit: .count(), doubleValue: Double(hour.steps)), start: hour.hour, end: end, metadata: metadata("steps")))
            }
            if hour.distanceMeters > 0 {
                samples.append(HKQuantitySample(type: distanceType, quantity: HKQuantity(unit: .meter(), doubleValue: hour.distanceMeters), start: hour.hour, end: end, metadata: metadata("distance")))
            }
            if hour.floors > 0 {
                samples.append(HKQuantitySample(type: flightsType, quantity: HKQuantity(unit: .count(), doubleValue: Double(hour.floors)), start: hour.hour, end: end, metadata: metadata("flights")))
            }
        }
        guard !samples.isEmpty else { return }
        try await healthStore.save(samples)
    }

    // MARK: Background updates

    /// Calls `onChange` whenever steps change in Health, including while Sole is in the background.
    /// Must be set up at launch for background delivery to wake the app.
    func observeStepChanges(_ onChange: @escaping @MainActor () async -> Void) {
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { _, completion, error in
            guard error == nil else { completion(); return }
            // HealthKit allows the completion handler to be called from any thread.
            let done = UncheckedSendable(completion)
            Task { @MainActor in
                await onChange()
                done.value()
            }
        }
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .hourly) { _, _ in }
    }
}

/// Carries a value HealthKit documents as thread-safe across an isolation boundary.
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
