import Foundation
import SwiftData

/// Where an hour's count came from.
enum StepSource: String, Codable, CaseIterable {
    /// This iPhone's motion coprocessor, read with CMPedometer.
    case phone
    /// Apple Health, excluding Sole's own samples: Apple Watch, other apps, older history.
    case health
    /// Entered by hand. Added on top of the sensor count.
    case manual
}

/// One hour of steps from one source. A day's total is built from these with `StepMath`.
///
/// Rows are kept unique by (hourStart, source) in `StepStore`.
@Model
final class HourlySteps {
    var hourStart: Date = Date.distantPast
    var sourceRaw: String = StepSource.phone.rawValue
    var steps: Int = 0
    var distanceMeters: Double = 0
    var floorsAscended: Int = 0
    var updatedAt: Date = Date.now
    /// Steps last written to Apple Health for this hour (phone rows only). -1 when never written.
    var healthWrittenSteps: Int = -1

    init(hourStart: Date, source: StepSource, steps: Int, distanceMeters: Double, floorsAscended: Int) {
        self.hourStart = hourStart
        self.sourceRaw = source.rawValue
        self.steps = steps
        self.distanceMeters = distanceMeters
        self.floorsAscended = floorsAscended
        self.updatedAt = .now
    }

    var source: StepSource { StepSource(rawValue: sourceRaw) ?? .phone }

    var sample: HourSample {
        HourSample(hour: hourStart, steps: steps, distanceMeters: distanceMeters, floors: floorsAscended)
    }
}

/// One day's merged totals, kept so History, streaks and export don't re-add hourly rows,
/// and so each day remembers the goal that was set at the time.
@Model
final class DailySummary {
    var day: Date = Date.distantPast
    var steps: Int = 0
    var distanceMeters: Double = 0
    var floors: Int = 0
    var goal: Int = 8_000
    var updatedAt: Date = Date.now

    init(day: Date, goal: Int) {
        self.day = day
        self.goal = goal
    }

    var goalMet: Bool { goal > 0 && steps >= goal }
}
