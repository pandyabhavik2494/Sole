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
        engine.startObservingHealth()

        #if DEBUG
        if SampleData.isRequested {
            SampleData.seed(into: engine.store, goal: preferences.dailyGoal)
            preferences.hasOnboarded = true
            engine.refreshToday()
        }
        #endif
    }
}
