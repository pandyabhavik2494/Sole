import Foundation
import Observation

/// The daily goal and distance unit, synced across the user's devices with iCloud key-value storage
/// and mirrored locally so they work without iCloud.
@MainActor
@Observable
final class Preferences {
    static let defaultGoal = 8_000
    static let goalRange = 1_000...50_000

    var dailyGoal: Int {
        didSet {
            guard dailyGoal != oldValue else { return }
            write(dailyGoal, forKey: Keys.goal)
        }
    }

    var distanceUnit: DistanceUnit {
        didSet {
            guard distanceUnit != oldValue else { return }
            write(distanceUnit.rawValue, forKey: Keys.unit)
        }
    }

    /// Per device, not synced: each iPhone needs its own permission prompts.
    var hasOnboarded: Bool {
        didSet { local.set(hasOnboarded, forKey: Keys.onboarded) }
    }

    private enum Keys {
        static let goal = "dailyGoal"
        static let unit = "distanceUnit"
        static let onboarded = "hasOnboarded"
    }

    @ObservationIgnored private let local: UserDefaults
    @ObservationIgnored private let cloud: NSUbiquitousKeyValueStore?
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(local: UserDefaults = .standard, cloud: NSUbiquitousKeyValueStore? = .default) {
        self.local = local
        self.cloud = cloud
        cloud?.synchronize()

        let storedGoal = cloud?.object(forKey: Keys.goal) as? Int ?? local.object(forKey: Keys.goal) as? Int
        dailyGoal = storedGoal.map { min(max($0, Self.goalRange.lowerBound), Self.goalRange.upperBound) } ?? Self.defaultGoal
        let storedUnit = cloud?.string(forKey: Keys.unit) ?? local.string(forKey: Keys.unit)
        distanceUnit = storedUnit.flatMap(DistanceUnit.init(rawValue:)) ?? .localeDefault
        hasOnboarded = local.bool(forKey: Keys.onboarded)

        if let cloud {
            observer = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: cloud,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.reloadFromCloud() }
            }
        }
    }

    private func reloadFromCloud() {
        guard let cloud else { return }
        if let goal = cloud.object(forKey: Keys.goal) as? Int, Self.goalRange.contains(goal) {
            dailyGoal = goal
        }
        if let unit = cloud.string(forKey: Keys.unit).flatMap(DistanceUnit.init(rawValue:)) {
            distanceUnit = unit
        }
    }

    private func write(_ value: Any, forKey key: String) {
        local.set(value, forKey: key)
        cloud?.set(value, forKey: key)
    }
}
