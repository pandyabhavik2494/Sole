import Foundation
import Testing
@testable import Sole

struct DayKeyTests {
    @Test func takesTheDayInTheCalendarsTimeZone() {
        // 11 pm in Los Angeles on 3 Oct is already 4 Oct in London and Tokyo.
        let date = TestCalendars.date(2026, 10, 3, 23)
        #expect(DayKey(date, calendar: TestCalendars.losAngeles) == DayKey(year: 2026, month: 10, day: 3))
        #expect(DayKey(date, calendar: TestCalendars.london) == DayKey(year: 2026, month: 10, day: 4))
        #expect(DayKey(date, calendar: TestCalendars.tokyo) == DayKey(year: 2026, month: 10, day: 4))
    }

    @Test func rawValueRoundTrips() {
        let key = DayKey(year: 2026, month: 3, day: 8)
        #expect(key.rawValue == 20_260_308)
        #expect(DayKey(rawValue: key.rawValue) == key)
    }

    @Test func addingDaysCrossesMonthsYearsAndLeapDays() {
        #expect(DayKey(year: 2026, month: 12, day: 31).adding(days: 1) == DayKey(year: 2027, month: 1, day: 1))
        #expect(DayKey(year: 2028, month: 2, day: 28).adding(days: 1) == DayKey(year: 2028, month: 2, day: 29))
        #expect(DayKey(year: 2026, month: 3, day: 1).adding(days: -1) == DayKey(year: 2026, month: 2, day: 28))
        #expect(DayKey(year: 2026, month: 1, day: 1).days(to: DayKey(year: 2027, month: 1, day: 1)) == 365)
    }

    @Test func daylightSavingDaysAreStillOneDay() {
        // US clocks spring forward on 8 Mar 2026 and fall back on 1 Nov 2026.
        let la = TestCalendars.losAngeles
        let spring = DayKey(year: 2026, month: 3, day: 8)
        let fall = DayKey(year: 2026, month: 11, day: 1)
        #expect(spring.adding(days: 1).start(in: la).timeIntervalSince(spring.start(in: la)) == 23 * 3600)
        #expect(fall.adding(days: 1).start(in: la).timeIntervalSince(fall.start(in: la)) == 25 * 3600)
        #expect(DayKey(spring.start(in: la), calendar: la) == spring)
        #expect(DayKey(fall.start(in: la).addingTimeInterval(24.5 * 3600), calendar: la) == fall)
    }

    @Test func startIsMidnightInTheGivenZone() {
        let key = DayKey(year: 2026, month: 10, day: 3)
        #expect(key.start(in: TestCalendars.kolkata) == TestCalendars.date(2026, 10, 3, in: TestCalendars.kolkata))
    }

    @Test func weekdayIsSundayFirst() {
        #expect(DayKey(year: 2026, month: 10, day: 3).weekday == 7) // Saturday
        #expect(DayKey(year: 2026, month: 10, day: 4).weekday == 1) // Sunday
    }

    @Test func rangeListsEveryDay() {
        let range = DayKey(year: 2026, month: 2, day: 27)...DayKey(year: 2026, month: 3, day: 2)
        #expect(range.days.map(\.day) == [27, 28, 1, 2])
    }
}

struct SleepMathTests {
    let calendar = TestCalendars.losAngeles

    func interval(_ startHour: Double, _ endHour: Double) -> DateInterval {
        let base = TestCalendars.date(2026, 10, 3)
        return DateInterval(start: base.addingTimeInterval(startHour * 3600), end: base.addingTimeInterval(endHour * 3600))
    }

    @Test func watchAndPhoneOverlapCountOnce() {
        // Watch 23:00–06:30, iPhone 23:30–07:00 (hours relative to midnight on 3 Oct).
        let total = SleepMath.asleepDuration([interval(-1, 6.5), interval(-0.5, 7)])
        #expect(total == 8 * 3600)
    }

    @Test func gapsAreNotCounted() {
        let total = SleepMath.asleepDuration([interval(-1, 2), interval(3, 7)])
        #expect(total == 7 * 3600)
    }

    @Test func clipsToTheWindow() {
        let window = SleepMath.lastNightWindow(for: DayKey(year: 2026, month: 10, day: 3), calendar: calendar)
        // An afternoon nap the day before (2–4 pm) is outside last night's window.
        let total = SleepMath.asleepDuration([interval(-10, -8), interval(-1, 6)], within: window)
        #expect(total == 7 * 3600)
    }

    @Test func emptyIsZero() {
        #expect(SleepMath.asleepDuration([]) == 0)
    }

    @Test func windowRunsFromSixPmToNoon() {
        let window = SleepMath.lastNightWindow(for: DayKey(year: 2026, month: 10, day: 3), calendar: calendar)
        #expect(window.start == TestCalendars.date(2026, 10, 2, 18))
        #expect(window.end == TestCalendars.date(2026, 10, 3, 12))
    }
}

struct UnitPreferencesTests {
    @Test func readsHealthKitUnitStrings() {
        #expect(UnitPreferences(massUnitString: "lb", energyUnitString: "kJ") == UnitPreferences(mass: .pounds, energy: .kilojoules))
        #expect(UnitPreferences(massUnitString: "st", energyUnitString: "Cal") == UnitPreferences(mass: .stones, energy: .kilocalories))
        #expect(UnitPreferences(massUnitString: "kg", energyUnitString: "kcal") == .metric)
    }

    @Test func unknownStringsUseTheFallback() {
        let fallback = UnitPreferences(mass: .pounds, energy: .kilocalories)
        #expect(UnitPreferences(massUnitString: nil, energyUnitString: "furlongs", fallback: fallback) == fallback)
    }

    @Test func convertsForDisplayAndBack() {
        let imperial = UnitPreferences(mass: .pounds, energy: .kilojoules)
        #expect(abs(imperial.display(80, for: .weight) - 176.37) < 0.01)
        #expect(abs(imperial.canonical(176.37, for: .weight) - 80) < 0.01)
        #expect(imperial.display(500, for: .activeEnergy) == 2_092)
        #expect(UnitPreferences(mass: .stones, energy: .kilocalories).display(63.5029, for: .weight).rounded() == 10)
        // Heart rate and oxygen are never converted.
        #expect(imperial.display(56, for: .restingHeartRate) == 56)
    }

    @Test func formatsWithSymbols() {
        let locale = Locale(identifier: "en_US")
        #expect(UnitPreferences.metric.format(74.64, for: .weight, locale: locale) == "74.6 kg")
        #expect(UnitPreferences.metric.format(97, for: .bloodOxygen, locale: locale) == "97%")
        #expect(UnitPreferences.metric.format(2_310, for: .activeEnergy, locale: locale) == "2,310 kcal")
        #expect(UnitPreferences.metric.formatChange(-1.5, for: .bloodOxygen, locale: locale) == "2 points")
        #expect(UnitPreferences(mass: .pounds, energy: .kilocalories).formatChange(-0.5, for: .weight, locale: locale) == "1.1 lb")
    }
}
