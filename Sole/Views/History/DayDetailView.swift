import SwiftUI

/// One day's total and its steps by hour.
struct DayDetailView: View {
    let day: Date

    @Environment(StepEngine.self) private var engine
    @Environment(Preferences.self) private var preferences
    @State private var detail: DayDetail?
    @State private var goal: Int?

    var body: some View {
        let detail = detail ?? .empty(for: day)
        let goal = goal ?? preferences.dailyGoal
        ScrollView {
            VStack(spacing: 16) {
                ProgressArc(steps: detail.steps, goal: goal, lineWidth: 14)
                    .frame(width: 210, height: 210)

                HStack(spacing: 10) {
                    StatTile(value: Format.distance(detail.distanceMeters, unit: preferences.distanceUnit), label: "Distance")
                    StatTile(value: Format.steps(detail.floors), label: detail.floors == 1 ? "Floor" : "Floors")
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("By hour")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        if let peak = detail.peakHour {
                            Text("Peak \(Format.steps(peak.steps)) at \(peak.hour.formatted(.dateTime.hour()))")
                                .font(.footnote)
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    HourlyChart(detail: detail, height: 160)
                }
                .card()
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Palette.background)
        .navigationTitle(day.formatted(.dateTime.weekday(.wide).day().month()))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            self.detail = engine.store.dayDetail(for: day)
            self.goal = engine.store.summaries(from: day, to: day.addingTimeInterval(86_400)).first?.goal
        }
    }
}
