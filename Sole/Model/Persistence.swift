import Foundation
import SwiftData

enum Persistence {
    static let schema = Schema([HourlySteps.self, DailySummary.self])
    static let cloudContainerIdentifier = "iCloud.com.pandyabhavik.Sole"

    /// The app's store, synced to the user's private iCloud database.
    ///
    /// `.automatic` picks the CloudKit container from the entitlements. If iCloud can't be set up
    /// (no signing team, or a build without the iCloud capability) Sole still works from a local store.
    static func makeContainer() -> ModelContainer {
        do {
            let configuration = ModelConfiguration("Sole", schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            do {
                let configuration = ModelConfiguration("Sole", schema: schema, cloudKitDatabase: .none)
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                fatalError("Couldn't open Sole's store: \(error)")
            }
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
