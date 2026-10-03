import Foundation

/// Plain-language patterns in daily values.
enum WeekPattern {
    /// "higher on weekdays" / "higher at weekends" when the medians differ by more than
    /// `threshold` (fraction), from the last `days` days. Nil when there's no clear pattern or
    /// fewer than 3 of each.
    static func weekdayVersusWeekend(_ values: [DayKey: Double], endingBefore today: DayKey, days: Int = 56, threshold: Double = 0.1) -> String? {
        var weekdays: [Double] = []
        var weekends: [Double] = []
        for offset in 1...days {
            let day = today.adding(days: -offset)
            guard let value = values[day] else { continue }
            if day.weekday == 1 || day.weekday == 7 { weekends.append(value) } else { weekdays.append(value) }
        }
        guard weekdays.count >= 3, weekends.count >= 3,
              let weekday = Baseline.median(weekdays), let weekend = Baseline.median(weekends),
              max(weekday, weekend) > 0 else { return nil }
        let difference = (weekday - weekend) / max(weekday, weekend)
        if difference > threshold { return "higher on weekdays" }
        if difference < -threshold { return "higher at weekends" }
        return nil
    }

    /// The weekday (1 = Sunday) with the highest median over the last `days` days, if it beats the
    /// next best by more than `threshold`. Used for "Saturdays are your most active day."
    static func mostActiveWeekday(_ values: [DayKey: Double], endingBefore today: DayKey, days: Int = 84, threshold: Double = 0.1) -> Int? {
        var byWeekday: [Int: [Double]] = [:]
        for offset in 1...days {
            let day = today.adding(days: -offset)
            if let value = values[day] { byWeekday[day.weekday, default: []].append(value) }
        }
        let medians = byWeekday.filter { $0.value.count >= 4 }.compactMapValues(Baseline.median)
        let ranked = medians.sorted { $0.value > $1.value }
        guard ranked.count >= 5, let best = ranked.first, best.value > 0 else { return nil }
        let runnerUp = ranked[1].value
        return (best.value - runnerUp) / best.value > threshold ? best.key : nil
    }
}

enum Span {
    /// "2 years, 4 months", "5 months", "3 weeks", "6 days" between two days.
    static func describe(from start: DayKey, to end: DayKey) -> String {
        let days = max(0, start.days(to: end))
        var months = (end.year - start.year) * 12 + (end.month - start.month)
        if end.day < start.day { months -= 1 }
        months = max(0, months)
        func plural(_ count: Int, _ word: String) -> String { "\(count) \(word)\(count == 1 ? "" : "s")" }
        if months >= 12 {
            let years = months / 12
            let rest = months % 12
            return rest == 0 ? plural(years, "year") : "\(plural(years, "year")), \(plural(rest, "month"))"
        }
        if months >= 1 { return plural(months, "month") }
        if days >= 14 { return plural(days / 7, "week") }
        return plural(days, "day")
    }
}
