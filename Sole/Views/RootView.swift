import SwiftUI

enum AppTab: String {
    case today, trends, recap
    /// Not a screen: the floating + button. Selecting it opens the Add sheet.
    case add
}

/// Sheets that can be opened from anywhere: the + button, the gear, Siri and Control Center.
enum AppSheet: String, Identifiable {
    case add, settings
    var id: String { rawValue }
}

@MainActor
@Observable
final class Router {
    var tab: AppTab = Router.initialTab
    var sheet: AppSheet? = Router.initialSheet

    /// Debug builds accept `-tab trends` (or `recap`) and `-sheet settings` (or `add`) at launch, for screenshots.
    private static var initialTab: AppTab {
        #if DEBUG
        UserDefaults.standard.string(forKey: "tab").flatMap(AppTab.init(rawValue:)) ?? .today
        #else
        .today
        #endif
    }

    private static var initialSheet: AppSheet? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "sheet").flatMap(AppSheet.init(rawValue:))
        #else
        nil
        #endif
    }
}

struct RootView: View {
    @Environment(StepEngine.self) private var engine
    @Environment(Preferences.self) private var preferences
    @Environment(Router.self) private var router

    var body: some View {
        if preferences.hasOnboarded {
            tabs
        } else {
            OnboardingView()
        }
    }

    private var tabs: some View {
        @Bindable var router = router
        return TabView(selection: tabSelection) {
            Tab("Today", systemImage: "sun.max.fill", value: AppTab.today) {
                TodayView()
            }
            Tab("Trends", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.trends) {
                TrendsView()
            }
            Tab("Recap", systemImage: "rectangle.stack.fill", value: AppTab.recap) {
                RecapView()
            }
            // A prominent (iOS 27) or search (iOS 26) role places this tab in its own glass circle
            // beside the tab bar, where the spec puts the + button. Selecting it opens the Add sheet.
            Tab("Add", systemImage: "plus", value: AppTab.add, role: Self.addRole) {
                Color.clear
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Palette.accent)
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .add:
                AddSheet()
            case .settings:
                NavigationStack {
                    SettingsView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done", systemImage: "checkmark") { router.sheet = nil }
                            }
                        }
                }
            }
        }
        .onChange(of: preferences.dailyGoal) { engine.goalDidChange() }
        .onChange(of: preferences.distanceUnit) { engine.preferencesDidChange() }
    }

    private static var addRole: TabRole {
        if #available(iOS 27, *) { .prominent } else { .search }
    }

    /// Keeps the + tab from ever becoming the selected screen.
    private var tabSelection: Binding<AppTab> {
        Binding {
            router.tab
        } set: { tab in
            if tab == .add {
                router.sheet = .add
            } else {
                router.tab = tab
            }
        }
    }
}
