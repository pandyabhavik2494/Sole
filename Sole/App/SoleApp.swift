import SwiftData
import SwiftUI

@main
struct SoleApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model.engine)
                .environment(model.preferences)
                .environment(model.router)
                .environment(model.metrics)
                .modelContainer(model.container)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Before onboarding, wait: the first sensor read shows the permission prompt.
                guard model.preferences.hasOnboarded else { return }
                Task {
                    await model.engine.becameActive()
                    model.metrics.stepsDidChange()
                    await model.metrics.refresh()
                }
            case .background:
                model.engine.enteredBackground()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(StepEngine.backgroundRefreshID)) {
            await model.engine.backgroundRefresh()
            await model.metrics.refresh()
        }
    }
}
