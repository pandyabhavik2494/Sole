import Foundation
import Testing
@testable import Sole

struct StepMathTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    func date(_ day: Int, _ hour: Int = 0, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @Test func phoneAndWatchForTheSameHourCountOnce() {
        let hour = date(3, 9)
        let merged = StepMath.merge([
            (.phone, HourSample(hour: hour, steps: 1_200, distanceMeters: 900, floors: 2)),
            (.health, HourSample(hour: hour, steps: 1_350, distanceMeters: 850, floors: 3)),
        ])
        #expect(merged[hour] == HourTotal(hour: hour, steps: 1_350, distanceMeters: 900, floors: 3))
    }

    @Test func differentHoursAreKeptApart() {
        let merged = StepMath.merge([
            (.phone, HourSample(hour: date(3, 9), steps: 500, distanceMeters: 0, floors: 0)),
            (.health, HourSample(hour: date(3, 10), steps: 700, distanceMeters: 0, floors: 0)),
        ])
        #expect(merged.values.reduce(0) { $0 + $1.steps } == 1_200)
    }

    @Test func manualStepsAddToTheSensorCount() {
        let hour = date(3, 9)
        let merged = StepMath.merge([
            (.phone, HourSample(hour: hour, steps: 1_000, distanceMeters: 0, floors: 0)),
            (.manual, HourSample(hour: hour, steps: 300, distanceMeters: 0, floors: 0)),
        ])
        #expect(merged[hour]?.steps == 1_300)
    }

    @Test func daylightSavingDaysHaveTheRightNumberOfHours() {
        #expect(StepMath.hours(of: date(3), calendar: calendar).count == 24)
        #expect(StepMath.hours(of: date(1, month: 11), calendar: calendar).count == 25)
        #expect(StepMath.hours(of: date(8, month: 3), calendar: calendar).count == 23)
    }

    @Test func streakCountsBackFromToday() {
        let met = [date(1): true, date(2): true, date(3): true]
        #expect(StepMath.currentStreak(goalMet: met, today: date(3, 18), calendar: calendar) == 3)
    }

    @Test func streakRunsThroughYesterdayUntilTodayIsMet() {
        let met = [date(1): true, date(2): true, date(3): false]
        #expect(StepMath.currentStreak(goalMet: met, today: date(3, 8), calendar: calendar) == 2)
    }

    @Test func aMissedDayBreaksTheStreak() {
        let met = [date(1): true, date(2): false, date(3): true]
        #expect(StepMath.currentStreak(goalMet: met, today: date(3, 20), calendar: calendar) == 1)
        #expect(StepMath.currentStreak(goalMet: [:], today: date(3), calendar: calendar) == 0)
    }
}
