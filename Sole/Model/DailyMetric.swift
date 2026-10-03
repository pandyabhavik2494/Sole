import Foundation
import SwiftData

/// One day's statistics for one Health metric. A cache: it can be rebuilt from Health at any
/// time, and exists so charts, baselines and widgets don't wait on Health queries.
@Model
final class DailyMetric {
    #Unique<DailyMetric>([\.dayKey, \.metricRaw])

    /// `DayKey.rawValue` (yyyymmdd).
    var dayKey: Int = 0
    var metricRaw: String = Metric.restingHeartRate.rawValue
    var value: Double = 0
    var minValue: Double?
    var maxValue: Double?
    var updatedAt: Date = Date.now

    init(_ daily: DailyValue) {
        dayKey = daily.day.rawValue
        metricRaw = daily.metric.rawValue
        value = daily.value
        minValue = daily.min
        maxValue = daily.max
        updatedAt = .now
    }

    var daily: DailyValue? {
        guard let metric = Metric(rawValue: metricRaw) else { return nil }
        return DailyValue(day: DayKey(rawValue: dayKey), metric: metric, value: value, min: minValue, max: maxValue)
    }
}

/// Something the user said about a day. Sick and travel days are left out of "your normal".
enum DayTagKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case sick, travel, lateNight, alcohol, hardWorkout, stressed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sick: "Sick"
        case .travel: "Travel"
        case .lateNight: "Late night"
        case .alcohol: "Alcohol"
        case .hardWorkout: "Hard workout"
        case .stressed: "Stressed"
        }
    }

    var symbol: String {
        switch self {
        case .sick: "thermometer.medium"
        case .travel: "airplane"
        case .lateNight: "moon.stars.fill"
        case .alcohol: "wineglass.fill"
        case .hardWorkout: "figure.run"
        case .stressed: "brain.head.profile"
        }
    }

    /// Whether days with this tag are left out of usual ranges and trends.
    var excludesFromNormal: Bool { self == .sick || self == .travel }
}

/// A tag on a day. Stays on this iPhone (Health can't store it), so it's included in the CSV export.
@Model
final class DayTag {
    #Unique<DayTag>([\.dayKey, \.kindRaw])

    var dayKey: Int = 0
    var kindRaw: String = DayTagKind.sick.rawValue
    var createdAt: Date = Date.now

    init(day: DayKey, kind: DayTagKind) {
        dayKey = day.rawValue
        kindRaw = kind.rawValue
        createdAt = .now
    }

    var day: DayKey { DayKey(rawValue: dayKey) }
    var kind: DayTagKind? { DayTagKind(rawValue: kindRaw) }
}
