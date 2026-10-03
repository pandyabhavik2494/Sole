import CoreMotion
import SwiftUI

struct TodayView: View {
    @Environment(StepEngine.self) private var engine
    @Environment(Preferences.self) private var preferences
    @Environment(Router.self) private var router

    var body: some View {
        let today = engine.today
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(today.day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.subheadline)
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if engine.motionStatus == .denied || engine.motionStatus == .restricted {
                        MotionAccessBanner()
                    }

                    NavigationLink {
                        HistoryView()
                    } label: {
                        ProgressArc(steps: today.steps, goal: preferences.dailyGoal)
                            .frame(width: 250, height: 250)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows your step history")

                    HStack(spacing: 10) {
                        StatTile(value: Format.distance(today.distanceMeters, unit: preferences.distanceUnit), label: "Distance")
                        StatTile(value: Format.steps(today.floors), label: today.floors == 1 ? "Floor" : "Floors")
                        StatTile(value: "\(engine.streak) \(engine.streak == 1 ? "day" : "days")", label: "Goal streak")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("By hour")
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
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background { GlowBackground(progress: Double(today.steps) / Double(max(preferences.dailyGoal, 1))) }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { router.sheet = .settings }
                }
            }
            .refreshable { await engine.sync() }
        }
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
