import Foundation
import SwiftData

/// Owns the app's long-lived objects. Created once by `SoleApp`.
@MainActor
final class AppModel {
    let container: ModelContainer
    let preferences: Preferences
    let engine: StepEngine

    init() {
        container = Persistence.makeContainer()
        preferences = Preferences()
        engine = StepEngine(store: StepStore(context: container.mainContext), preferences: preferences)
    }
}
