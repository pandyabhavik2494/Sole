import SwiftUI

enum AppTab: String {
    case today, history, settings
}

struct RootView: View {
    @Environment(StepEngine.self) private var engine
    @Environment(Preferences.self) private var preferences
    @State private var tab = RootView.initialTab

    var body: some View {
        if preferences.hasOnboarded {
            tabs
        } else {
            OnboardingView()
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "figure.walk") }
                .tag(AppTab.today)
            HistoryView()
                .tabItem { Label("History", systemImage: "chart.bar.fill") }
                .tag(AppTab.history)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(Palette.accent)
        .onChange(of: preferences.dailyGoal) { engine.goalDidChange() }
        .onChange(of: preferences.distanceUnit) { engine.preferencesDidChange() }
    }

    /// Debug builds accept `-tab history` (or `settings`) at launch, for screenshots.
    private static var initialTab: AppTab {
        #if DEBUG
        UserDefaults.standard.string(forKey: "tab").flatMap(AppTab.init(rawValue:)) ?? .today
        #else
        .today
        #endif
    }
}
