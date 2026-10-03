import Foundation

/// Everything Sole knows about one metric today.
struct MetricInsight: Equatable, Sendable {
    var metric: Metric
    /// Today's value, or the latest recent one for readings that arrive once a day (resting heart
    /// rate is usually computed later in the morning) and for weight.
    var value: DailyValue?
    /// Usual daily range, learned from the 28 days before `value`'s day.
    var range: UsualRange?
    var assessment: Assessment
    var trend: Trend?
    /// For cumulative metrics: today's running total against the usual pace.
    var pace: PaceComparison?

    var status: Status { assessment.status }
    /// Days between the value and `today` (0 when it's today's).
    func age(on today: DayKey) -> Int? { value.map { $0.day.days(to: today) } }
}

struct Tally: Equatable, Sendable {
    var usual = 0
    var better = 0
    var worthALook = 0

    var total: Int { usual + better + worthALook }
}

struct Headline: Equatable, Sendable {
    var title: String
    var detail: String
}

/// The answer to "how am I doing?", built from plain values so it is the same sentence every
/// time for the same data.
struct Insights: Equatable, Sendable {
    var day: DayKey
    var metrics: [Metric: MetricInsight]
    var tally: Tally
    var headline: Headline

    subscript(metric: Metric) -> MetricInsight {
        metrics[metric] ?? MetricInsight(metric: metric, value: nil, range: nil, assessment: .noData, trend: nil, pace: nil)
    }

    static func empty(day: DayKey) -> Insights {
        Insights(day: day, metrics: [:], tally: Tally(), headline: Headline(title: "Here's your day so far.", detail: ""))
    }
}

enum InsightBuilder {
    struct Input: Sendable {
        var series: [Metric: [DayKey: DailyValue]]
        var tags: [DayKey: Set<DayTagKind>]
        /// Merged steps by hour for at least the last 8 weeks.
        var hourlySteps: [Date: Double]
        /// Active energy by hour for at least the last 8 weeks.
        var hourlyActiveEnergy: [Date: Double]
        var now: Date
        var calendar: Calendar
        var locale: Locale = .current
    }

    /// How many days back a once-a-day reading may come from and still count as "today's".
    static func lookbackDays(_ metric: Metric) -> Int {
        switch metric {
        case .steps, .activeEnergy, .restingEnergy, .heartRate: 0
        case .restingHeartRate, .walkingHeartRate, .bloodOxygen: 1
        case .weight: 30
        }
    }

    /// Metrics that get a status and count in the tally.
    static let judgedMetrics: [Metric] = Metric.allCases.filter { $0.statusThreshold != nil }

    static func build(_ input: Input) -> Insights {
        let today = DayKey(input.now, calendar: input.calendar)
        let excluded = Set(input.tags.filter { $0.value.contains(where: \.excludesFromNormal) }.keys)

        var metrics: [Metric: MetricInsight] = [:]
        for metric in Metric.allCases {
            metrics[metric] = insight(for: metric, input: input, today: today, excluded: excluded)
        }

        var tally = Tally()
        for metric in judgedMetrics {
            switch metrics[metric]?.status {
            case .usual: tally.usual += 1
            case .better: tally.better += 1
            case .worthALook: tally.worthALook += 1
            default: break
            }
        }

        let weekday = input.now.formatted(Date.FormatStyle(locale: input.locale, calendar: input.calendar, timeZone: input.calendar.timeZone).weekday(.wide))
        let headline = headline(metrics: metrics, weekday: weekday)
        return Insights(day: today, metrics: metrics, tally: tally, headline: headline)
    }

    private static func insight(for metric: Metric, input: Input, today: DayKey, excluded: Set<DayKey>) -> MetricInsight {
        let daily = input.series[metric] ?? [:]
        let numbers = daily.mapValues(\.value)
        let trend = TrendRules.trend(metric, values: numbers, today: today, excluding: excluded)

        if metric == .steps || metric == .activeEnergy {
            let range = Baseline.usualRange(numbers, before: today, excluding: excluded)
            let hourly = metric == .steps ? input.hourlySteps : input.hourlyActiveEnergy
            let todayValue = daily[today]
            let pace = UsualPace.expected(hourly: hourly, at: input.now, calendar: input.calendar).map {
                PaceComparison(actual: todayValue?.value ?? 0, expected: $0)
            }
            let assessment = StatusRules.assess(metric, pace: pace, hasHistory: !daily.isEmpty)
            return MetricInsight(metric: metric, value: todayValue, range: range, assessment: assessment, trend: trend, pace: pace)
        }

        let latest = (0...lookbackDays(metric)).lazy.compactMap { daily[today.adding(days: -$0)] }.first
        let range = Baseline.usualRange(numbers, before: latest?.day ?? today, excluding: excluded)
        let assessment: Assessment
        if metric.isCumulative {
            // Resting energy builds through the day, so today's partial total isn't judged.
            assessment = latest == nil ? (daily.isEmpty ? .noData : .learning) : range == nil ? .learning : .usual
        } else {
            assessment = StatusRules.assess(metric, value: latest?.value, range: range)
        }
        return MetricInsight(metric: metric, value: latest, range: range, assessment: assessment, trend: trend, pace: nil)
    }

    // MARK: Headline

    /// Anything worth a look first (largest first), else anything better, else "usual". The
    /// second line covers the rest, then steps against a usual day like this one.
    static func headline(metrics: [Metric: MetricInsight], weekday: String) -> Headline {
        // Steps have their own line, so the title is about everything else.
        let candidates = judgedMetrics.filter { $0 != .steps }.compactMap { metrics[$0] }
        let ranked = candidates
            .filter { $0.status == .worthALook || $0.status == .better }
            .sorted { lhs, rhs in
                if (lhs.status == .worthALook) != (rhs.status == .worthALook) { return lhs.status == .worthALook }
                if lhs.assessment.severity != rhs.assessment.severity { return lhs.assessment.severity > rhs.assessment.severity }
                return Metric.allCases.firstIndex(of: lhs.metric)! < Metric.allCases.firstIndex(of: rhs.metric)!
            }

        var title: String
        var parts: [String] = []
        if let lead = ranked.first {
            title = sentence(for: lead)
            let others = ranked.dropFirst()
            let othersWorth = others.filter { $0.status == .worthALook }.count
            if others.isEmpty {
                parts.append("Everything else is in your usual range.")
            } else if othersWorth > 0 {
                parts.append(othersWorth == 1 ? "One more thing is worth a look." : "\(othersWorth) more things are worth a look.")
            } else {
                parts.append(others.count == 1 ? "One more is better than usual." : "\(others.count) more are better than usual.")
            }
        } else if candidates.contains(where: { $0.status == .usual }) {
            title = "Everything is in your usual range."
        } else if candidates.contains(where: { $0.status == .learning }) {
            title = "Sole is learning your normal."
            parts.append("Each measure needs 7 days of data.")
        } else {
            title = "Here's your day so far."
        }

        let steps = metrics[.steps]
        if let pace = steps?.pace {
            switch pace.position(threshold: Metric.steps.statusThreshold ?? .relative(0.15), floor: StatusRules.paceFloor(.steps)) {
            case .ahead: parts.append("You're ahead of a usual \(weekday).")
            case .behind: parts.append("You're behind a usual \(weekday).")
            case .onPace: parts.append("You're on pace for a usual \(weekday).")
            }
        }
        return Headline(title: title, detail: parts.joined(separator: " "))
    }

    static func sentence(for insight: MetricInsight) -> String {
        let name = insight.metric.title
        switch insight.status {
        case .better:
            return "\(name) is better than usual."
        case .worthALook:
            return insight.assessment.direction == .below ? "\(name) is lower than usual." : "\(name) is higher than usual."
        default:
            return "\(name) is in your usual range."
        }
    }
}
