import SwiftUI

/// "Here's your normal": the ranges Sole learned from Health history, shown right after Health
/// access is granted so the first launch already pays off.
struct YourNormalView: View {
    @Environment(MetricsEngine.self) private var metrics
    var buttonTitle = "Start using Sole"
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(eyebrow)
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 40)
                    Text("Here's your normal.")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Palette.ink)
                    Text(intro)
                        .foregroundStyle(Palette.muted)

                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Reading your Health history…")
                                .foregroundStyle(Palette.muted)
                        }
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                    } else if rows.isEmpty {
                        ContentUnavailableView(
                            "Nothing to learn from yet",
                            systemImage: "heart.text.square",
                            description: Text("Health doesn't have readings Sole can use yet. Sole learns your normal as days come in; each measure needs 7 days.")
                        )
                        .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(rows) { row in
                                NormalRow(row: row)
                                if row.id != rows.last?.id { Divider().padding(.leading, 52) }
                            }
                        }
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            Button(action: onDone) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.accent)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background { GlowBackground(progress: 0.6) }
    }

    // MARK: Content

    private var isLoading: Bool {
        metrics.access == .requested && metrics.lastRefresh == nil
    }

    private var eyebrow: String {
        guard let start = metrics.historyStart else { return "Learned from your Health data" }
        return "Learned from \(Span.describe(from: start, to: metrics.insights.day)) of Health data"
    }

    private var intro: String {
        "From now on Sole compares each day with these ranges and tells you when something moves."
    }

    private var rows: [NormalRowModel] {
        let insights = metrics.insights
        let units = metrics.units
        var rows: [NormalRowModel] = []
        for metric in [Metric.steps, .restingHeartRate, .walkingHeartRate, .activeEnergy, .bloodOxygen] {
            guard let range = insights[metric].range else { continue }
            var detail: String?
            if metric == .steps {
                let pattern = WeekPattern.weekdayVersusWeekend((metrics.series[.steps] ?? [:]).mapValues(\.value), endingBefore: insights.day)
                detail = ["a day", pattern].compactMap { $0 }.joined(separator: " · ")
            } else if metric == .activeEnergy {
                detail = "a day"
            }
            rows.append(NormalRowModel(metric: metric, value: units.rangeText(range, for: metric), detail: detail))
        }
        let weights = (metrics.series[.weight] ?? [:]).mapValues(\.value)
        let smoothed = TrendWeight.smoothed(weights)
        if let latestDay = smoothed.keys.max(), let latest = smoothed[latestDay], latestDay.days(to: insights.day) <= 30 {
            var detail: String?
            if let change = TrendWeight.change(smoothed, overDays: 90, endingOn: insights.day), abs(change) >= 0.1 {
                detail = "\(change < 0 ? "down" : "up") \(units.formatChange(change, for: .weight)) in 3 months"
            }
            rows.append(NormalRowModel(metric: .weight, title: "Weight trend", value: units.format(latest, for: .weight), detail: detail))
        }
        return rows
    }
}

private struct NormalRowModel: Identifiable {
    var metric: Metric
    var title: String?
    var value: String
    var detail: String?
    var id: Metric { metric }
}

private struct NormalRow: View {
    let row: NormalRowModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.metric.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(row.metric.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text(row.title ?? row.metric.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text(row.value)
                    .font(.system(.body, design: .rounded, weight: .bold).monospacedDigit())
                    .foregroundStyle(Palette.ink)
                if let detail = row.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
            .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
