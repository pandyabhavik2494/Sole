import Charts
import SwiftData
import SwiftUI

enum HistoryRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: String { rawValue }

    var component: Calendar.Component {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }
}

/// One bar in the History chart: a day, or for the year view a month's daily average.
struct HistoryBar: Identifiable {
    var date: Date
    var steps: Int
    var goalMet: Bool
    var isCurrent: Bool
    var id: Date { date }
}

struct HistoryView: View {
    @Environment(StepEngine.self) private var engine
    @Environment(Preferences.self) private var preferences
    @Query(sort: \DailySummary.day) private var summaries: [DailySummary]

    @State private var range: HistoryRange = .week
    @State private var anchor = Date.now

    private let calendar = Calendar.current

    var body: some View {
        let byDay = summariesByDay
        let period = calendar.dateInterval(of: range.component, for: anchor) ?? DateInterval(start: anchor, duration: 86_400)
        let days = daysWithData(in: period, from: byDay)
        let bars = bars(for: period, from: byDay)

        Group {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Range", selection: $range) {
                        ForEach(HistoryRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 10) {
                        periodHeader(period)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Daily average")
                                .font(.footnote)
                                .foregroundStyle(Palette.muted)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(Format.steps(average(of: days)))
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
                                    .foregroundStyle(Palette.ink)
                                Text("steps")
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                        historyChart(bars)
                    }
                    .card()

                    StreakCard(streak: engine.streak, todaySteps: engine.today.steps, goal: preferences.dailyGoal)

                    HStack(spacing: 10) {
                        if let best = days.max(by: { $0.steps < $1.steps }) {
                            StatTile(value: Format.steps(best.steps), label: "Best day · \(best.day.formatted(bestDayFormat))")
                        } else {
                            StatTile(value: "–", label: "Best day")
                        }
                        StatTile(value: Format.steps(days.reduce(0) { $0 + $1.steps }), label: totalLabel)
                    }

                    dayList(period: period, byDay: byDay)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Palette.background)
            .navigationTitle("Steps")
            .navigationDestination(for: Date.self) { day in
                DayDetailView(day: day)
            }
            .onChange(of: range) { anchor = .now }
        }
    }

    // MARK: Sections

    private func periodHeader(_ period: DateInterval) -> some View {
        let isCurrent = period.contains(.now)
        return HStack {
            Button {
                move(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous \(range.rawValue.lowercased())")
            Spacer()
            Text(title(for: period))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Spacer()
            Button {
                move(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isCurrent)
            .accessibilityLabel("Next \(range.rawValue.lowercased())")
        }
        .font(.body.weight(.semibold))
    }

    private func historyChart(_ bars: [HistoryBar]) -> some View {
        let goal = preferences.dailyGoal
        let unit: Calendar.Component = range == .year ? .month : .day
        return Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value(range == .year ? "Month" : "Day", bar.date, unit: unit),
                    y: .value("Steps", bar.steps)
                )
                .foregroundStyle(bar.isCurrent ? Palette.accent : bar.goalMet ? Palette.good : Palette.line)
                .cornerRadius(range == .month ? 2 : 5)
            }
            RuleMark(y: .value("Goal", goal))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(Palette.muted.opacity(0.7))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Goal")
                        .font(.caption2)
                        .foregroundStyle(Palette.muted)
                }
        }
        .chartXAxis {
            switch range {
            case .week:
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            case .month:
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.day(), centered: true)
                }
            case .year:
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let steps = value.as(Int.self) { Text(Format.compactSteps(steps)) }
                }
            }
        }
        .frame(height: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(range == .year ? "Daily average by month" : "Steps by day")
        .accessibilityValue(bars.filter { $0.steps > 0 }.map {
            "\($0.date.formatted(range == .year ? .dateTime.month(.wide) : .dateTime.weekday(.wide).day())): \(Format.steps($0.steps))"
        }.joined(separator: ", "))
    }

    @ViewBuilder
    private func dayList(period: DateInterval, byDay: [Date: DailySummary]) -> some View {
        if range == .year {
            let months = monthRows(in: period, from: byDay)
            if !months.isEmpty {
                VStack(spacing: 0) {
                    ForEach(months, id: \.month) { row in
                        Button {
                            anchor = row.month
                            range = .month
                            DispatchQueue.main.async { anchor = row.month }
                        } label: {
                            listRow(title: row.month.formatted(.dateTime.month(.wide)), value: "\(Format.steps(row.average)) avg", met: row.average >= preferences.dailyGoal)
                        }
                        if row.month != months.last?.month { Divider().padding(.leading, 14) }
                    }
                }
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        } else {
            let days = daysWithData(in: period, from: byDay).reversed()
            if !days.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(days), id: \.day) { summary in
                        NavigationLink(value: summary.day) {
                            listRow(title: summary.day.formatted(.dateTime.weekday(.wide).day().month()), value: Format.steps(summary.steps), met: summary.goalMet)
                        }
                        if summary.day != days.last?.day { Divider().padding(.leading, 14) }
                    }
                }
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func listRow(title: String, value: String, met: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Palette.ink)
            Spacer()
            if met {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Palette.good)
                    .accessibilityLabel("Goal met")
            }
            Text(value)
                .monospacedDigit()
                .foregroundStyle(Palette.muted)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.muted.opacity(0.6))
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: Data

    private var summariesByDay: [Date: DailySummary] {
        var result: [Date: DailySummary] = [:]
        for summary in summaries {
            let day = calendar.startOfDay(for: summary.day)
            if let existing = result[day], existing.steps >= summary.steps { continue }
            result[day] = summary
        }
        return result
    }

    private func daysWithData(in period: DateInterval, from byDay: [Date: DailySummary]) -> [DayRow] {
        byDay.values
            .filter { period.contains($0.day) && $0.day < period.end && $0.steps > 0 }
            .sorted { $0.day < $1.day }
            .map { DayRow(day: calendar.startOfDay(for: $0.day), steps: $0.steps, goalMet: $0.goalMet) }
    }

    private func bars(for period: DateInterval, from byDay: [Date: DailySummary]) -> [HistoryBar] {
        let today = calendar.startOfDay(for: .now)
        if range == .year {
            return monthRows(in: period, from: byDay).map {
                HistoryBar(date: $0.month, steps: $0.average, goalMet: $0.average >= preferences.dailyGoal, isCurrent: calendar.isDate($0.month, equalTo: today, toGranularity: .month))
            }
        }
        var bars: [HistoryBar] = []
        var day = period.start
        while day < period.end {
            let summary = byDay[day]
            bars.append(HistoryBar(date: day, steps: summary?.steps ?? 0, goalMet: summary?.goalMet ?? false, isCurrent: day == today))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return bars
    }

    private func monthRows(in period: DateInterval, from byDay: [Date: DailySummary]) -> [MonthRow] {
        let today = calendar.startOfDay(for: .now)
        var rows: [MonthRow] = []
        var month = period.start
        while month < period.end, month <= today {
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            let days = byDay.values.filter { $0.day >= month && $0.day < next }
            let total = days.reduce(0) { $0 + $1.steps }
            // Average over the days that have passed, so the current month isn't diluted by the future.
            let elapsed = max(1, calendar.dateComponents([.day], from: month, to: min(next, calendar.date(byAdding: .day, value: 1, to: today) ?? next)).day ?? 1)
            if total > 0 {
                rows.append(MonthRow(month: month, average: total / elapsed))
            }
            month = next
        }
        return rows
    }

    private func average(of days: [DayRow]) -> Int {
        guard !days.isEmpty else { return 0 }
        return days.reduce(0) { $0 + $1.steps } / days.count
    }

    private func move(by value: Int) {
        anchor = calendar.date(byAdding: range.component, value: value, to: anchor) ?? anchor
    }

    private func title(for period: DateInterval) -> String {
        let last = period.end.addingTimeInterval(-1)
        switch range {
        case .week:
            return "\(period.start.formatted(.dateTime.day().month())) – \(last.formatted(.dateTime.day().month()))"
        case .month:
            return period.start.formatted(.dateTime.month(.wide).year())
        case .year:
            return period.start.formatted(.dateTime.year())
        }
    }

    private var bestDayFormat: Date.FormatStyle {
        range == .week ? .dateTime.weekday(.abbreviated) : .dateTime.day().month(.abbreviated)
    }

    private var totalLabel: String {
        switch range {
        case .week: "This week"
        case .month: "This month"
        case .year: "This year"
        }
    }
}

private struct DayRow {
    var day: Date
    var steps: Int
    var goalMet: Bool
}

private struct MonthRow {
    var month: Date
    var average: Int
}
