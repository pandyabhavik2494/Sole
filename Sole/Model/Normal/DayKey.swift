import Foundation

/// A calendar day (year, month, day) independent of time zone.
///
/// Daily values are keyed by this rather than by `Date`, so a day stays the same day after
/// travelling across time zones and a 23- or 25-hour daylight saving day is still one day.
/// Components are always Gregorian, taken in the user's time zone.
struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar`'s time zone.
    init(_ date: Date, calendar: Calendar = .current) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// `yyyymmdd`, used to store the key in SwiftData.
    var rawValue: Int { year * 10_000 + month * 100 + day }

    init(rawValue: Int) {
        self.init(year: rawValue / 10_000, month: rawValue / 100 % 100, day: rawValue % 100)
    }

    /// Midnight at the start of this day in `calendar`'s time zone.
    func start(in calendar: Calendar = .current) -> Date {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let noon = gregorian.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
        return gregorian.startOfDay(for: noon)
    }

    /// The day `count` days later (or earlier when negative). Pure date arithmetic, no time zone.
    func adding(days count: Int) -> DayKey {
        let date = Self.utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
        let moved = Self.utc.date(byAdding: .day, value: count, to: date) ?? date
        return DayKey(moved, calendar: Self.utc)
    }

    /// Whole days from `self` to `other`; positive when `other` is later.
    func days(to other: DayKey) -> Int {
        let from = Self.utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
        let to = Self.utc.date(from: DateComponents(year: other.year, month: other.month, day: other.day, hour: 12)) ?? .distantPast
        return Self.utc.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// 1 = Sunday … 7 = Saturday.
    var weekday: Int {
        let date = Self.utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
        return Self.utc.component(.weekday, from: date)
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.rawValue < rhs.rawValue }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()
}

extension ClosedRange where Bound == DayKey {
    /// Every day in the range, oldest first.
    var days: [DayKey] {
        let count = lowerBound.days(to: upperBound)
        guard count >= 0 else { return [] }
        return (0...count).map { lowerBound.adding(days: $0) }
    }
}
