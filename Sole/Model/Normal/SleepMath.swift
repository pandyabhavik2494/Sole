import Foundation

enum SleepMath {
    /// The window "last night" covers: 6 pm the day before `day` until noon on `day`.
    static func lastNightWindow(for day: DayKey, calendar: Calendar) -> DateInterval {
        let start = day.start(in: calendar)
        let from = calendar.date(byAdding: .hour, value: -6, to: start) ?? start
        let to = calendar.date(byAdding: .hour, value: 12, to: start) ?? start
        return DateInterval(start: from, end: max(from, to))
    }

    /// Total time asleep, counting overlapping intervals once. An Apple Watch and an iPhone often
    /// both record the same night; adding them would double it.
    static func asleepDuration(_ intervals: [DateInterval], within window: DateInterval? = nil) -> TimeInterval {
        let clipped: [DateInterval] = intervals.compactMap { interval in
            guard let window else { return interval }
            return interval.intersection(with: window)
        }
        var total: TimeInterval = 0
        var current: DateInterval?
        for interval in clipped.sorted(by: { $0.start < $1.start }) {
            if let open = current, interval.start <= open.end {
                current = DateInterval(start: open.start, end: max(open.end, interval.end))
            } else {
                if let open = current { total += open.duration }
                current = interval
            }
        }
        if let open = current { total += open.duration }
        return total
    }
}
