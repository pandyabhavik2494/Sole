import Foundation

enum AppGroup {
    static let identifier = "group.com.pandyabhavik.Sole"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Today's numbers, written by the app into the shared App Group so the widgets can show them
/// without opening the app's database.
struct WidgetSnapshot: Codable, Equatable {
    /// Start of the day these numbers belong to.
    var day: Date
    var steps: Int
    var distanceMeters: Double
    var floors: Int
    var goal: Int
    var unit: DistanceUnit
    var updatedAt: Date

    private static let key = "widgetSnapshot"

    static func load(from defaults: UserDefaults = AppGroup.defaults) -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save(to defaults: UserDefaults = AppGroup.defaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1)
    }

    static let placeholder = WidgetSnapshot(
        day: Calendar.current.startOfDay(for: .now),
        steps: 7_842,
        distanceMeters: 5_900,
        floors: 12,
        goal: 10_000,
        unit: .localeDefault,
        updatedAt: .now
    )
}
