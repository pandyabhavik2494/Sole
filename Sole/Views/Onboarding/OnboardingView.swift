import SwiftUI

/// Three short screens: what Sole does, the two permissions, then a daily goal.
/// Declining Health still works: Sole counts with the sensor alone.
struct OnboardingView: View {
    @Environment(StepEngine.self) private var engine
    @Environment(Preferences.self) private var preferences
    @Environment(MetricsEngine.self) private var metrics
    @State private var page = 0
    @State private var showsNormal = false
    @State private var isRequesting = false
    @State private var motionAsked = false
    @State private var healthAsked = false

    var body: some View {
        if showsNormal {
            YourNormalView(onDone: finish)
                .transition(.opacity)
        } else {
            pages
        }
    }

    private var pages: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                permissions.tag(1)
                goal.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            VStack(spacing: 16) {
                PageDots(count: 3, current: page)
                Button(action: advance) {
                    Text(buttonTitle)
                        .font(.headline)
                        .foregroundStyle(Palette.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isRequesting)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Palette.background)
    }

    // MARK: Pages

    private var welcome: some View {
        page(
            symbol: "shoeprints.fill",
            title: "Every step, counted",
            text: "Sole counts your steps with your iPhone's own motion sensor, and reads your heart, energy, weight and blood oxygen from Apple Health. It learns what's normal for you and tells you, in plain words, how you're doing."
        ) { EmptyView() }
    }

    private var permissions: some View {
        page(
            symbol: "hand.raised.fill",
            title: "Let Sole count your steps",
            text: "Sole uses your iPhone's motion sensor and Apple Health. Your data stays on your iPhone and in Health."
        ) {
            VStack(spacing: 10) {
                PermissionRow(symbol: "figure.walk.motion", tint: Color(uiColor: UIColor(rgb: 0xFF9F0A)), title: "Motion & Fitness", detail: "Counts steps, distance and floors", done: motionAsked)
                if HealthService.isAvailable {
                    PermissionRow(symbol: "heart.fill", tint: Color(uiColor: UIColor(rgb: 0xFF3B5C)), title: "Apple Health", detail: "Reads steps, heart, energy, weight and sleep", done: healthAsked)
                }
                Text("You can skip Health. Sole will count with the sensor alone.")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
    }

    private var goal: some View {
        @Bindable var preferences = preferences
        return page(
            symbol: "flag.checkered",
            title: "Pick a daily goal",
            text: "Days you reach it turn green and build your streak. You can change it any time in Settings."
        ) {
            VStack(spacing: 12) {
                Text(Format.steps(preferences.dailyGoal))
                    .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText(value: Double(preferences.dailyGoal)))
                Text("steps a day")
                    .foregroundStyle(Palette.muted)
                Stepper("Daily goal", value: $preferences.dailyGoal.animation(), in: 2_000...30_000, step: 500)
                    .labelsHidden()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func page(symbol: String, title: String, text: String, @ViewBuilder content: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                    .padding(.bottom, 8)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Palette.ink)
                Text(text)
                    .foregroundStyle(Palette.muted)
                content()
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: Actions

    private func finish() {
        preferences.hasOnboarded = true
        Task {
            await engine.becameActive()
            metrics.stepsDidChange()
        }
    }

    private var buttonTitle: String {
        switch page {
        case 1: motionAsked && (healthAsked || !HealthService.isAvailable) ? "Continue" : "Allow access"
        case 2: healthAsked ? "Continue" : "Start counting"
        default: "Continue"
        }
    }

    private func advance() {
        switch page {
        case 1 where !(motionAsked && (healthAsked || !HealthService.isAvailable)):
            isRequesting = true
            Task {
                await engine.requestMotionAccess()
                motionAsked = true
                if HealthService.isAvailable {
                    await engine.connectHealth()
                    healthAsked = true
                    // Start learning "your normal" while the goal page is up.
                    Task { await metrics.refresh() }
                }
                isRequesting = false
                page = 2
            }
        case 2:
            if healthAsked {
                withAnimation { showsNormal = true }
            } else {
                finish()
            }
        default:
            page += 1
        }
    }
}

private struct PermissionRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let done: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(detail).font(.footnote).foregroundStyle(Palette.muted)
            }
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.good)
            }
        }
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Palette.ink : Palette.line)
                    .frame(width: index == current ? 18 : 7, height: 7)
            }
        }
        .animation(.easeInOut, value: current)
        .accessibilityHidden(true)
    }
}
