import Foundation

/// Every number Sole explains. Values are stored in canonical units: count, bpm, kcal, percent
/// (0–100) and kilograms; `UnitPreferences` converts them for display.
enum Metric: String, CaseIterable, Codable, Sendable, Identifiable {
    case steps
    case restingHeartRate
    case walkingHeartRate
    case heartRate
    case activeEnergy
    case restingEnergy
    case bloodOxygen
    case weight

    var id: String { rawValue }

    /// Which way is good, for status words and trend colours.
    enum Polarity: Sendable {
        case higherIsBetter
        case lowerIsBetter
        /// Only a fall is worth a look; a rise is still usual (blood oxygen).
        case onlyLowIsConcern
        /// Never better or worse, only usual (weight without a goal, heart rate, resting energy).
        case neutral
    }

    /// How far outside the usual range a value must be before it counts.
    enum Threshold: Equatable, Sendable {
        /// In the metric's canonical unit, such as 3 bpm.
        case absolute(Double)
        /// A fraction of the usual median, such as 0.15 for 15%.
        case relative(Double)

        func amount(around median: Double) -> Double {
            switch self {
            case .absolute(let value): value
            case .relative(let fraction): abs(median) * fraction
            }
        }
    }

    var title: String {
        switch self {
        case .steps: "Steps"
        case .restingHeartRate: "Resting heart rate"
        case .walkingHeartRate: "Walking heart rate"
        case .heartRate: "Heart rate"
        case .activeEnergy: "Active energy"
        case .restingEnergy: "Resting energy"
        case .bloodOxygen: "Blood oxygen"
        case .weight: "Weight"
        }
    }

    /// Lower-case name for use inside sentences.
    var phrase: String {
        switch self {
        case .steps: "steps"
        case .restingHeartRate: "resting heart rate"
        case .walkingHeartRate: "walking heart rate"
        case .heartRate: "heart rate"
        case .activeEnergy: "active energy"
        case .restingEnergy: "resting energy"
        case .bloodOxygen: "blood oxygen"
        case .weight: "weight"
        }
    }

    var polarity: Polarity {
        switch self {
        case .steps, .activeEnergy: .higherIsBetter
        case .restingHeartRate, .walkingHeartRate: .lowerIsBetter
        case .bloodOxygen: .onlyLowIsConcern
        case .heartRate, .restingEnergy, .weight: .neutral
        }
    }

    /// Minimum distance outside the usual range before a status changes. Nil: no status.
    var statusThreshold: Threshold? {
        switch self {
        case .steps: .relative(0.15)
        case .restingHeartRate: .absolute(3)
        case .walkingHeartRate: .absolute(4)
        case .activeEnergy: .relative(0.10)
        case .bloodOxygen: .absolute(2)
        case .heartRate, .restingEnergy, .weight: nil
        }
    }

    /// Minimum change between trend windows before a trend is reported. Nil: no trend.
    var trendThreshold: Threshold? {
        switch self {
        case .steps: .relative(0.10)
        case .restingHeartRate: .absolute(2)
        case .walkingHeartRate: .absolute(3)
        case .activeEnergy: .relative(0.10)
        case .bloodOxygen: .absolute(1)
        case .weight: .absolute(0.5)
        case .heartRate, .restingEnergy: nil
        }
    }

    /// Adds up over the day (so today is partial until midnight) rather than an average or reading.
    var isCumulative: Bool {
        switch self {
        case .steps, .activeEnergy, .restingEnergy: true
        default: false
        }
    }

    /// Recorded only by Apple Watch on most setups, so "no data" usually means "no Watch".
    var usuallyNeedsWatch: Bool {
        switch self {
        case .restingHeartRate, .walkingHeartRate, .heartRate, .restingEnergy, .bloodOxygen: true
        case .steps, .activeEnergy, .weight: false
        }
    }

    /// Metrics read from Health by `HealthMetricsService` (steps come from `StepEngine`).
    static let fromHealth: [Metric] = [.restingHeartRate, .walkingHeartRate, .heartRate, .activeEnergy, .restingEnergy, .bloodOxygen, .weight]
}

/// One day's statistics for one metric, in canonical units.
struct DailyValue: Hashable, Sendable {
    var day: DayKey
    var metric: Metric
    /// Sum for cumulative metrics, average for heart and oxygen, latest for weight.
    var value: Double
    var min: Double?
    var max: Double?
}
