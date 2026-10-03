import SwiftUI

/// "Usual", "Better" or "Worth a look", with a symbol so it never relies on colour alone.
struct StatusPill: View {
    let status: Status

    var body: some View {
        Label(status.title, systemImage: status.symbol)
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status == .usual ? Palette.ink.opacity(0.75) : status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status.softColor, in: Capsule())
            .fixedSize()
    }
}

/// "6 usual · 1 better · 0 worth a look".
struct TallyChips: View {
    let tally: Tally

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            VStack(alignment: .leading, spacing: 6) { chips }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tally.usual) usual, \(tally.better) better, \(tally.worthALook) worth a look")
    }

    @ViewBuilder
    private var chips: some View {
        chip("\(tally.usual) usual", color: Palette.ink.opacity(0.75), background: Palette.surface.opacity(0.85))
        chip("\(tally.better) better", color: Palette.good, background: Palette.goodSoft)
        chip("\(tally.worthALook) worth a look", color: tally.worthALook > 0 ? Palette.watch : Palette.muted, background: tally.worthALook > 0 ? Palette.watchSoft : Palette.surface.opacity(0.85))
    }

    private func chip(_ text: String, color: Color, background: Color) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
    }
}

/// What a vitals row shows. Built by `VitalRowModel.make` so Today and widgets agree on wording.
struct VitalRowModel: Identifiable {
    var metric: Metric
    var title: String
    var value: String?
    var unit: String?
    var status: Status
    /// "usual 58–63", "670 moving + 1,640 resting", "Needs Apple Watch data".
    var detail: String
    /// One sentence for VoiceOver.
    var accessibilityText: String

    var id: Metric { metric }
}

/// One metric as a row: value, status word and its usual range in numbers. Rows reflow at large
/// text sizes rather than squeezing into a grid.
struct VitalRow: View {
    let model: VitalRowModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            HStack(spacing: 12) {
                Image(systemName: model.metric.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(model.metric.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text(model.detail)
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 6) }
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
                if let value = model.value {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(value)
                            .font(.system(.title3, design: .rounded, weight: .bold).monospacedDigit())
                            .foregroundStyle(Palette.ink)
                        if let unit = model.unit {
                            Text(unit)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }
                // Heart rate and weight have no usual/better wording, so no pill.
                if model.status != .noData, model.metric.statusThreshold != nil {
                    StatusPill(status: model.status)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.accessibilityText)
    }
}

/// A titled group of rows on one card.
struct VitalsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Palette.muted)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(subviews.indices, id: \.self) { index in
                        subviews[index]
                        if index < subviews.count - 1 { Divider().padding(.leading, 56) }
                    }
                }
            }
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

extension VitalRowModel {
    /// Builds the row for a metric from today's insights.
    @MainActor
    static func make(_ metric: Metric, metrics: MetricsEngine) -> VitalRowModel {
        let insights = metrics.insights
        let insight = insights[metric]
        let units = metrics.units
        let today = insights.day

        func rangeDetail(_ prefix: String = "usual") -> String {
            if let range = insight.range { return "\(prefix) \(units.rangeText(range, for: metric))" }
            return insight.status == .noData ? noDataText(metric) : "Learning your normal"
        }

        func ago(_ value: DailyValue) -> String {
            switch value.day.days(to: today) {
            case 0: ""
            case 1: " · yesterday"
            case let days: " · \(days) days ago"
            }
        }

        switch metric {
        case .activeEnergy:
            // "Burned": active + resting, judged on active (resting barely moves).
            let active = insight.value?.day == today ? insight.value?.value : nil
            let resting = insights[.restingEnergy].value.flatMap { $0.day == today ? $0.value : nil }
            let total = (active ?? 0) + (resting ?? 0)
            let detail: String
            if let active, let resting {
                detail = "\(units.number(active, for: .activeEnergy)) moving + \(units.number(resting, for: .restingEnergy)) resting"
            } else if active != nil {
                detail = rangeDetail("usual moving")
            } else {
                detail = insight.status == .noData ? noDataText(metric) : "No energy recorded yet today"
            }
            let value = total > 0 ? units.number(total, for: .activeEnergy) : nil
            return VitalRowModel(
                metric: metric, title: "Burned", value: value, unit: value == nil ? nil : units.symbol(for: .activeEnergy),
                status: insight.status, detail: detail,
                accessibilityText: [ "Burned", value.map { "\($0) \(units.symbol(for: .activeEnergy)) so far today" }, detail, insight.status.title ].compactMap { $0 }.joined(separator: ", ")
            )

        case .heartRate:
            let hours = metrics.todayHeartRate
            let today = insight.value?.day == today ? insight.value : nil
            let low = today?.min ?? hours.map(\.min).min()
            let high = today?.max ?? hours.map(\.max).max()
            var detail = noDataText(metric)
            var value: String?
            if let low, let high {
                value = "\(Int(low.rounded()))–\(Int(high.rounded()))"
                if let peak = hours.max(by: { $0.max < $1.max }) {
                    detail = "Today's range · peaked around \(peak.hour.formatted(.dateTime.hour()))"
                } else {
                    detail = "Today's range"
                }
            }
            return VitalRowModel(
                metric: metric, title: "Heart rate", value: value, unit: value == nil ? nil : "bpm",
                status: value == nil ? .noData : .usual, detail: detail,
                accessibilityText: value.map { "Heart rate today ranged from \($0) beats per minute. \(detail)" } ?? "Heart rate, \(detail)"
            )

        case .weight:
            let smoothed = TrendWeight.smoothed((metrics.series[.weight] ?? [:]).mapValues(\.value))
            var detail = insight.status == .noData ? "Log it with the + button" : "Learning your trend"
            if let change = TrendWeight.change(smoothed, overDays: 7, endingOn: today) {
                detail = abs(change) < 0.05 ? "Steady this week" : "Trend \(change < 0 ? "down" : "up") \(units.formatChange(change, for: .weight)) this week"
            }
            if let latest = insight.value { detail += ago(latest) }
            let value = insight.value.map { units.number($0.value, for: .weight) }
            return VitalRowModel(
                metric: metric, title: "Weight", value: value, unit: value == nil ? nil : units.symbol(for: .weight),
                status: insight.value == nil ? .noData : .usual, detail: detail,
                accessibilityText: ["Weight", value.map { "\($0) \(units.symbol(for: .weight))" }, detail].compactMap { $0 }.joined(separator: ", ")
            )

        default:
            let value = insight.value.map { units.number($0.value, for: metric) }
            var detail = rangeDetail()
            if let latest = insight.value { detail += ago(latest) }
            let title: String = switch metric {
            case .restingHeartRate: "Resting"
            case .walkingHeartRate: "Walking average"
            default: metric.title
            }
            return VitalRowModel(
                metric: metric, title: title, value: value, unit: value == nil ? nil : (metric == .bloodOxygen ? "%" : units.symbol(for: metric)),
                status: insight.status, detail: detail,
                accessibilityText: spokenSentence(metric, insight: insight, units: units)
            )
        }
    }

    static func noDataText(_ metric: Metric) -> String {
        metric.usuallyNeedsWatch ? "No data · needs Apple Watch" : "No data in Health"
    }

    /// "Resting heart rate 56 bpm, below your usual range of 58 to 63. Better."
    static func spokenSentence(_ metric: Metric, insight: MetricInsight, units: UnitPreferences) -> String {
        guard let value = insight.value else { return "\(metric.title), no data" }
        var sentence = "\(metric.title) \(units.format(value.value, for: metric))"
        if let range = insight.range {
            let low = units.number(range.low, for: metric)
            let high = units.number(range.high, for: metric)
            let position = value.value < range.low ? "below" : value.value > range.high ? "above" : "within"
            sentence += ", \(position) your usual range of \(low) to \(high)"
        } else {
            sentence += ", still learning your usual range"
        }
        return sentence + ". \(insight.status.title)."
    }
}
