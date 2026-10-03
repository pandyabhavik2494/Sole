import Foundation
import Observation

/// The daily goal and distance unit, stored on this iPhone.
@MainActor
@Observable
final class Preferences {
    static let defaultGoal = 8_000
    static let goalRange = 1_000...50_000

    var dailyGoal: Int {
        didSet { defaults.set(dailyGoal, forKey: Keys.goal) }
    }

    var distanceUnit: DistanceUnit {
        didSet { defaults.set(distanceUnit.rawValue, forKey: Keys.unit) }
    }

    var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: Keys.onboarded) }
    }

    /// Hides weight everywhere: Today, Trends, Recap, widgets, Siri and the doctor report.
    var hidesWeight: Bool {
        didSet { defaults.set(hidesWeight, forKey: Keys.hidesWeight) }
    }

    private enum Keys {
        static let goal = "dailyGoal"
        static let unit = "distanceUnit"
        static let onboarded = "hasOnboarded"
        static let hidesWeight = "hidesWeight"
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedGoal = defaults.object(forKey: Keys.goal) as? Int
        dailyGoal = storedGoal.map { min(max($0, Self.goalRange.lowerBound), Self.goalRange.upperBound) } ?? Self.defaultGoal
        distanceUnit = defaults.string(forKey: Keys.unit).flatMap(DistanceUnit.init(rawValue:)) ?? .localeDefault
        hasOnboarded = defaults.bool(forKey: Keys.onboarded)
        hidesWeight = defaults.bool(forKey: Keys.hidesWeight)
    }
}
