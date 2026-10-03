import Foundation
import SwiftData

/// Sole's store lives on the iPhone. Apple Health is the long-term copy: it keeps the iPhone's
/// and Apple Watch's steps and syncs them through the user's iCloud, so after a reinstall or on a
/// new iPhone Sole rebuilds its history by importing from Health.
enum Persistence {
    static let schema = Schema([HourlySteps.self, DailySummary.self, DailyMetric.self, DayTag.self])

    static func makeContainer() -> ModelContainer {
        do {
            let configuration = ModelConfiguration("Sole", schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Couldn't open Sole's store: \(error)")
        }
    }

    static func makeInMemoryContainer() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Couldn't create an in-memory store: \(error)")
        }
    }
}
