import Foundation

/// The word shown next to every number.
enum Status: String, Sendable, CaseIterable {
    case usual
    /// Outside the usual range in the healthy direction.
    case better
    /// Outside the usual range the other way. Amber, never red.
    case worthALook
    /// Fewer than 7 days of data.
    case learning
    /// Nothing recorded (no Watch, or read access off).
    case noData

    var title: String {
        switch self {
        case .usual: "Usual"
        case .better: "Better"
        case .worthALook: "Worth a look"
        case .learning: "Learning"
        case .noData: "No data"
        }
    }

    /// Counted in the tally ("6 usual · 1 better · 0 worth a look").
    var isJudged: Bool { self == .usual || self == .better || self == .worthALook }
}

/// A status plus how far out it is, used to rank what the headline talks about.
struct Assessment: Equatable, Sendable {
    var status: Status
    /// Which side of usual the value is on, if outside it by more than the threshold.
    var direction: Direction?
    /// Distance outside the range in multiples of the metric's threshold (0 when usual).
    var severity: Double

    enum Direction: Equatable, Sendable { case above, below }

    static let noData = Assessment(status: .noData, direction: nil, severity: 0)
    static let learning = Assessment(status: .learning, direction: nil, severity: 0)
    static let usual = Assessment(status: .usual, direction: nil, severity: 0)
}

enum StatusRules {
    /// Compares a value with its usual range.
    static func assess(_ metric: Metric, value: Double?, range: UsualRange?) -> Assessment {
        guard let value else { return .noData }
        guard let range else { return .learning }
        guard let threshold = metric.statusThreshold else { return .usual }
        let margin = threshold.amount(around: range.median)
        guard margin > 0 else { return .usual }

        let above = value - range.high
        let below = range.low - value
        if above > margin {
            return judged(metric, .above, severity: above / margin)
        } else if below > margin {
            return judged(metric, .below, severity: below / margin)
        }
        return .usual
    }

    /// Compares today's running total of a cumulative metric with its usual pace.
    static func assess(_ metric: Metric, pace: PaceComparison?, hasHistory: Bool) -> Assessment {
        guard let pace else { return hasHistory ? .learning : .noData }
        guard let threshold = metric.statusThreshold else { return .usual }
        let margin = max(threshold.amount(around: pace.expected), paceFloor(metric))
        switch pace.position(threshold: threshold, floor: paceFloor(metric)) {
        case .ahead: return judged(metric, .above, severity: pace.difference / margin)
        case .behind: return judged(metric, .below, severity: -pace.difference / margin)
        case .onPace: return .usual
        }
    }

    /// The smallest pace gap worth mentioning, in canonical units.
    static func paceFloor(_ metric: Metric) -> Double {
        switch metric {
        case .steps: 500
        case .activeEnergy: 50
        default: 0
        }
    }

    private static func judged(_ metric: Metric, _ direction: Assessment.Direction, severity: Double) -> Assessment {
        let status: Status
        switch (metric.polarity, direction) {
        case (.higherIsBetter, .above), (.lowerIsBetter, .below): status = .better
        case (.higherIsBetter, .below), (.lowerIsBetter, .above), (.onlyLowIsConcern, .below): status = .worthALook
        case (.onlyLowIsConcern, .above), (.neutral, _): return .usual
        }
        return Assessment(status: status, direction: direction, severity: severity)
    }
}
