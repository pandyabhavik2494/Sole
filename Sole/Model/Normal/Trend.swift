import Foundation

/// The last four weeks against the twelve before.
struct Trend: Equatable, Sendable {
    enum Direction: Equatable, Sendable { case up, down, steady }
    enum Meaning: Equatable, Sendable {
        case better
        /// Moving the less healthy way. Shown as "Changing", in amber.
        case worse
        /// Moving, but neither way is better (weight without a goal).
        case neutral
        case steady
    }

    var recentMean: Double
    var priorMean: Double
    var recentDays: Int
    var priorDays: Int
    var direction: Direction
    var meaning: Meaning

    var change: Double { recentMean - priorMean }
}

enum TrendRules {
    static let recentDays = 28
    static let priorDays = 84
    static let minimumDays = 14

    /// Mean of the 28 days before `today` vs. the 84 days before those, leaving out `excluded`
    /// days. Nil when the metric has no trend or either window has fewer than 14 days.
    static func trend(_ metric: Metric, values: [DayKey: Double], today: DayKey, excluding excluded: Set<DayKey> = []) -> Trend? {
        guard let threshold = metric.trendThreshold else { return nil }

        func window(_ offsets: ClosedRange<Int>) -> [Double] {
            offsets.compactMap { offset in
                let key = today.adding(days: -offset)
                guard !excluded.contains(key), let value = values[key], value.isFinite else { return nil }
                return value
            }
        }
        let recent = window(1...recentDays)
        let prior = window((recentDays + 1)...(recentDays + priorDays))
        guard recent.count >= minimumDays, prior.count >= minimumDays else { return nil }

        let recentMean = recent.reduce(0, +) / Double(recent.count)
        let priorMean = prior.reduce(0, +) / Double(prior.count)
        let change = recentMean - priorMean
        let direction: Trend.Direction = abs(change) < threshold.amount(around: priorMean) ? .steady : change > 0 ? .up : .down

        let meaning: Trend.Meaning
        switch (direction, metric.polarity) {
        case (.steady, _): meaning = .steady
        case (.up, .higherIsBetter), (.down, .lowerIsBetter): meaning = .better
        case (.down, .higherIsBetter), (.up, .lowerIsBetter), (.down, .onlyLowIsConcern): meaning = .worse
        case (.up, .onlyLowIsConcern): meaning = .steady
        case (_, .neutral): meaning = .neutral
        }
        return Trend(recentMean: recentMean, priorMean: priorMean, recentDays: recent.count, priorDays: prior.count, direction: direction, meaning: meaning)
    }
}

/// Smoothed body weight, so one salty dinner doesn't look like gaining a kilo.
enum TrendWeight {
    static let alpha = 0.1

    /// Exponential moving average over days with a weigh-in, oldest first. Days without a
    /// weigh-in carry no value (the average simply continues from the last one).
    static func smoothed(_ values: [DayKey: Double]) -> [DayKey: Double] {
        var result: [DayKey: Double] = [:]
        var average: Double?
        for day in values.keys.sorted() {
            guard let value = values[day], value.isFinite else { continue }
            let next = average.map { $0 + alpha * (value - $0) } ?? value
            result[day] = next
            average = next
        }
        return result
    }

    /// Change in trend weight over the last `days` days, from the latest smoothed value back to
    /// the last smoothed value on or before `days` days earlier. Nil without both ends.
    static func change(_ smoothed: [DayKey: Double], overDays days: Int, endingOn today: DayKey) -> Double? {
        guard let latestDay = smoothed.keys.filter({ $0 <= today }).max(),
              today.days(to: latestDay) > -days,
              let latest = smoothed[latestDay] else { return nil }
        let cutoff = latestDay.adding(days: -days)
        guard let earlierDay = smoothed.keys.filter({ $0 <= cutoff }).max(),
              cutoff.days(to: earlierDay) > -days,
              let earlier = smoothed[earlierDay] else { return nil }
        return latest - earlier
    }
}
