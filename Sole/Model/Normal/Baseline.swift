import Foundation

/// The middle half of recent daily values: what "usual" means for one metric.
struct UsualRange: Equatable, Sendable {
    /// 25th percentile.
    var low: Double
    var median: Double
    /// 75th percentile.
    var high: Double
    /// Days the range was learned from.
    var days: Int
    /// Days in the window left out because they were tagged sick or travel.
    var excludedDays: Int

    func contains(_ value: Double) -> Bool { value >= low && value <= high }
}

enum Baseline {
    /// Days before today that the usual range is learned from.
    static let windowDays = 28
    /// Fewer days than this and the metric is still "Learning".
    static let minimumDays = 7

    /// The usual range from the `windowDays` days before `day` (never including `day` itself),
    /// leaving out `excluded` days. Nil when fewer than `minimumDays` days have data.
    static func usualRange(_ values: [DayKey: Double], before day: DayKey, excluding excluded: Set<DayKey> = []) -> UsualRange? {
        var window: [Double] = []
        var excludedCount = 0
        for offset in 1...windowDays {
            let key = day.adding(days: -offset)
            guard let value = values[key], value.isFinite else { continue }
            if excluded.contains(key) {
                excludedCount += 1
            } else {
                window.append(value)
            }
        }
        guard window.count >= minimumDays else { return nil }
        let sorted = window.sorted()
        return UsualRange(
            low: percentile(sorted, 0.25),
            median: percentile(sorted, 0.5),
            high: percentile(sorted, 0.75),
            days: sorted.count,
            excludedDays: excludedCount
        )
    }

    /// Percentile `p` (0…1) of sorted values, interpolating linearly between neighbours
    /// (the same method as a spreadsheet's PERCENTILE.INC).
    static func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard let first = sorted.first else { return .nan }
        guard sorted.count > 1 else { return first }
        let position = min(max(p, 0), 1) * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let fraction = position - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
    }

    static func median(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : percentile(values.sorted(), 0.5)
    }
}
