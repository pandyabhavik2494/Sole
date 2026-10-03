import SwiftData
import SwiftUI

@main
struct SoleApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model.engine)
                .environment(model.preferences)
                .modelContainer(model.container)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await model.engine.becameActive() }
            case .background:
                model.engine.enteredBackground()
            default:
                break
            }
        }
    }
}
