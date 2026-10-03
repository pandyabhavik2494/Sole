import Foundation
import SwiftData

/// Owns the app's long-lived objects. Created once by `SoleApp`.
@MainActor
final class AppModel {
    let container: ModelContainer
    let preferences: Preferences
    let engine: StepEngine
    let metrics: MetricsEngine
    let router = Router()

    init() {
        container = Persistence.makeContainer()
        preferences = Preferences()
        engine = StepEngine(store: StepStore(context: container.mainContext), preferences: preferences)
        engine.startObservingHealth()
        metrics = MetricsEngine(store: MetricsStore(context: container.mainContext), stepStore: engine.store)
        metrics.start()

        #if DEBUG
        if SampleData.isRequested {
            SampleData.seed(into: engine.store, goal: preferences.dailyGoal)
            SampleData.seedMetrics(into: metrics.store)
            preferences.hasOnboarded = true
            engine.refreshToday()
            metrics.reloadFromCache()
        }
        #endif
    }
}
