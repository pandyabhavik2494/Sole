import Foundation

/// Where a cumulative metric (steps, active energy) usually is by this time of day.
enum UsualPace {
    /// Weeks of the same weekday looked at.
    static let weeks = 8
    /// Fewer same-weekdays with data than this and there is no usual pace yet.
    static let minimumDays = 3

    /// The median total by the same clock time on the same weekday over the last `weeks` weeks.
    ///
    /// - Parameter hourly: values by the start of each hour (any hours; missing hours are zero).
    ///   A past day counts only if it has some data, so days the phone was off don't drag the
    ///   median to zero. The hour containing the cut-off counts in proportion.
    static func expected(hourly: [Date: Double], at now: Date, calendar: Calendar) -> Double? {
        let today = DayKey(now, calendar: calendar)
        let startOfToday = today.start(in: calendar)
        let elapsed = calendar.dateComponents([.hour, .minute, .second], from: startOfToday, to: now)

        var totals: [Double] = []
        for week in 1...weeks {
            let day = today.adding(days: -7 * week)
            let start = day.start(in: calendar)
            let end = day.adding(days: 1).start(in: calendar)
            // Same wall-clock time on that day. On a DST day this follows the clock, not elapsed seconds.
            let cutoff = calendar.date(bySettingHour: elapsed.hour ?? 0, minute: elapsed.minute ?? 0, second: elapsed.second ?? 0, of: start) ?? start

            var dayTotal = 0.0
            var byCutoff = 0.0
            for (hour, value) in hourly where hour >= start && hour < end {
                dayTotal += value
                let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hour) ?? hour.addingTimeInterval(3600)
                if hourEnd <= cutoff {
                    byCutoff += value
                } else if hour < cutoff {
                    byCutoff += value * cutoff.timeIntervalSince(hour) / hourEnd.timeIntervalSince(hour)
                }
            }
            if dayTotal > 0 { totals.append(byCutoff) }
        }
        guard totals.count >= minimumDays else { return nil }
        return Baseline.median(totals)
    }
}

/// Today's running total against the usual pace.
struct PaceComparison: Equatable, Sendable {
    var actual: Double
    var expected: Double

    var difference: Double { actual - expected }

    enum Position: Equatable, Sendable { case ahead, onPace, behind }

    /// Ahead or behind only when the gap is bigger than the metric's threshold, and never for a
    /// gap smaller than `floor` (early in the morning a few hundred steps is noise).
    func position(threshold: Metric.Threshold, floor: Double) -> Position {
        let margin = max(threshold.amount(around: expected), floor)
        if difference > margin { return .ahead }
        if difference < -margin { return .behind }
        return .onPace
    }
}
