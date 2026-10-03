import CoreMotion
import SwiftUI

struct TodayView: View {
    @Environment(StepEngine.self) private var engine
    @Environment(Preferences.self) private var preferences
    @Environment(Router.self) private var router
    @Environment(MetricsEngine.self) private var metrics

    var body: some View {
        let today = engine.today
        let insights = metrics.insights
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(insights)

                    if engine.motionStatus == .denied || engine.motionStatus == .restricted {
                        MotionAccessBanner()
                    }
                    if metrics.access == .notRequested {
                        ConnectHealthCard()
                    }

                    stepsCard(today: today, insights: insights)

                    if metrics.access != .unavailable {
                        vitals
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Steps by hour")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Spacer()
                            if let peak = today.peakHour {
                                Text("Peak \(Format.steps(peak.steps)) at \(peak.hour.formatted(.dateTime.hour()))")
                                    .font(.footnote)
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                        HourlyChart(detail: today)
                    }
                    .card()

                    Text("Sole compares you with your own history. It isn't medical advice; talk to a doctor about readings that worry you.")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background { GlowBackground(progress: Double(today.steps) / Double(max(preferences.dailyGoal, 1))) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(today.day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.muted)
                        .fixedSize()
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { router.sheet = .settings }
                }
            }
            .navigationDestination(for: Metric.self) { metric in
                MetricDetailView(metric: metric)
            }
            .refreshable {
                await engine.sync()
                metrics.stepsDidChange()
                await metrics.refresh()
            }
            .onChange(of: today.steps) { _, steps in metrics.todayStepsDidChange(steps) }
        }
    }

    // MARK: Sections

    private func header(_ insights: Insights) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(insights.headline.title)
                .font(.system(.title, design: .default, weight: .bold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !insights.headline.detail.isEmpty {
                Text(insights.headline.detail)
                    .font(.body)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if insights.tally.total > 0 {
                TallyChips(tally: insights.tally)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private func stepsCard(today: DayDetail, insights: Insights) -> some View {
        let pace = insights[.steps].pace
        return NavigationLink {
            HistoryView()
        } label: {
            VStack(spacing: 12) {
                ProgressArc(steps: today.steps, goal: preferences.dailyGoal, usualPace: pace.map { Int($0.expected) })
                    .frame(width: 230, height: 230)
                if let pace {
                    paceLine(pace)
                }
                HStack(spacing: 10) {
                    StatTile(value: Format.distance(today.distanceMeters, unit: preferences.distanceUnit), label: "Distance")
                    StatTile(value: Format.steps(today.floors), label: today.floors == 1 ? "Floor" : "Floors")
                    StatTile(value: "\(engine.streak) \(engine.streak == 1 ? "day" : "days")", label: "Goal streak")
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows your step history")
    }

    private func paceLine(_ pace: PaceComparison) -> some View {
        let difference = Int(pace.difference.rounded())
        let position = pace.position(threshold: Metric.steps.statusThreshold ?? .relative(0.15), floor: StatusRules.paceFloor(.steps))
        let text: String
        let symbol: String
        let color: Color
        switch position {
        case .ahead:
            text = "\(Format.steps(abs(difference))) ahead of usual"; symbol = "arrowtriangle.up.fill"; color = Palette.good
        case .behind:
            text = "\(Format.steps(abs(difference))) behind usual"; symbol = "arrowtriangle.down.fill"; color = Palette.watch
        case .onPace:
            text = "On your usual pace"; symbol = "equal"; color = Palette.muted
        }
        return VStack(spacing: 2) {
            Label(text, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text("Tick = your usual by \(Date.now.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(text). By this time on a usual \(Date.now.formatted(.dateTime.weekday(.wide))) you've walked \(Format.steps(Int(pace.expected))) steps.")
    }

    private var vitals: some View {
        VStack(alignment: .leading, spacing: 16) {
            VitalsSection(title: "Heart") {
                ForEach([Metric.restingHeartRate, .walkingHeartRate, .heartRate]) { metric in
                    NavigationLink(value: metric) { VitalRow(model: .make(metric, metrics: metrics)) }
                        .buttonStyle(.plain)
                }
            }
            if let sleep = metrics.lastNightSleep {
                SleepChip(duration: sleep)
            }
            VitalsSection(title: "Energy & body") {
                ForEach(bodyMetrics) { metric in
                    NavigationLink(value: metric) { VitalRow(model: .make(metric, metrics: metrics)) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var bodyMetrics: [Metric] {
        preferences.hidesWeight ? [.activeEnergy, .bloodOxygen] : [.activeEnergy, .bloodOxygen, .weight]
    }
}

/// "Last night: 7 h 20 m sleep", context for heart metrics.
struct SleepChip: View {
    let duration: TimeInterval

    var body: some View {
        Label("Last night: \(Format.duration(duration)) asleep", systemImage: "moon.zzz.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.sleep)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Palette.sleep.opacity(0.12), in: Capsule())
    }
}

private struct MotionAccessBanner: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Motion & Fitness is off", systemImage: "figure.walk.motion")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Text("Sole needs it to count steps with your iPhone's sensor. Turn it on in Settings › Privacy & Security › Motion & Fitness.")
                .font(.footnote)
                .foregroundStyle(Palette.muted)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Shown until the v2 Health types have been asked for: on a fresh install that skipped Health,
/// and once after upgrading from v1 (which only asked for steps).
struct ConnectHealthCard: View {
    @Environment(MetricsEngine.self) private var metrics
    @Environment(Router.self) private var router
    @State private var isConnecting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("See how your body is doing", systemImage: "heart.text.square.fill")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text("Let Sole read heart rate, energy, blood oxygen, weight and sleep from Apple Health. It learns your normal from your history and tells you when something moves.")
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
            Button {
                isConnecting = true
                Task {
                    await metrics.connect()
                    isConnecting = false
                    if metrics.access == .requested { router.sheet = .normal }
                }
            } label: {
                Text(isConnecting ? "Connecting…" : "Connect Apple Health")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.heart)
            .disabled(isConnecting)
        }
        .card()
    }
}
