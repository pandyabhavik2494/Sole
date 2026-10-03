import Foundation
import SwiftData
import Testing
@testable import Sole

@MainActor
struct StepStoreTests {
    let container = Persistence.makeInMemoryContainer()
    let calendar = Calendar.current
    var store: StepStore { StepStore(context: container.mainContext, calendar: calendar) }

    func hour(_ offset: Int, from base: Date = Calendar.current.startOfDay(for: .now)) -> Date {
        calendar.date(byAdding: .hour, value: offset, to: base)!
    }

    @Test func keepHigherNeverLowersRestoredHistory() {
        let store = store
        let h = hour(9)
        store.upsert([HourSample(hour: h, steps: 2_000, distanceMeters: 1_500, floors: 1)], source: .phone) { _ in .keepHigher }
        store.upsert([HourSample(hour: h, steps: 0, distanceMeters: 0, floors: 0)], source: .phone) { _ in .keepHigher }
        #expect(store.rows(from: h, to: hour(10), source: .phone).first?.steps == 2_000)
    }

    @Test func replaceOverwrites() {
        let store = store
        let h = hour(9)
        store.upsert([HourSample(hour: h, steps: 2_000, distanceMeters: 0, floors: 0)], source: .phone) { _ in .keepHigher }
        store.upsert([HourSample(hour: h, steps: 1_500, distanceMeters: 0, floors: 0)], source: .phone) { _ in .replace }
        #expect(store.rows(from: h, to: hour(10), source: .phone).first?.steps == 1_500)
    }

    @Test func duplicateRowsAreFolded() {
        let store = store
        let context = container.mainContext
        let h = hour(9)
        context.insert(HourlySteps(hourStart: h, source: .phone, steps: 800, distanceMeters: 0, floorsAscended: 0))
        context.insert(HourlySteps(hourStart: h, source: .phone, steps: 900, distanceMeters: 0, floorsAscended: 0))
        store.upsert([HourSample(hour: h, steps: 850, distanceMeters: 0, floors: 0)], source: .phone) { _ in .keepHigher }
        let rows = store.rows(from: h, to: hour(10), source: .phone)
        #expect(rows.count == 1)
        #expect(rows.first?.steps == 900)
    }

    @Test func clearingRemovesHoursDeletedInHealth() {
        let store = store
        store.upsert([
            HourSample(hour: hour(8), steps: 400, distanceMeters: 0, floors: 0),
            HourSample(hour: hour(9), steps: 600, distanceMeters: 0, floors: 0),
        ], source: .health) { _ in .replace }
        store.upsert([HourSample(hour: hour(9), steps: 600, distanceMeters: 0, floors: 0)], source: .health, clearing: hour(0)..<hour(24)) { _ in .replace }
        #expect(store.rows(from: hour(0), to: hour(24), source: .health).map(\.steps) == [600])
    }

    @Test func dailySummaryUsesTheHigherSourceEachHour() {
        let store = store
        let day = calendar.startOfDay(for: .now)
        store.upsert([
            HourSample(hour: hour(8), steps: 1_000, distanceMeters: 0, floors: 0),
            HourSample(hour: hour(9), steps: 3_000, distanceMeters: 0, floors: 0),
        ], source: .phone) { _ in .replace }
        store.upsert([
            HourSample(hour: hour(8), steps: 1_200, distanceMeters: 0, floors: 0),
            HourSample(hour: hour(10), steps: 500, distanceMeters: 0, floors: 0),
        ], source: .health) { _ in .replace }
        store.recomputeDays([day], goal: 4_000)

        let summary = store.summaries(from: day, to: hour(24)).first
        #expect(summary?.steps == 4_700)
        #expect(summary?.goalMet == true)
        #expect(store.dayDetail(for: day).steps == 4_700)
    }

    @Test func pastDaysKeepTheirGoal() {
        let store = store
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))!
        store.upsert([HourSample(hour: hour(9, from: yesterday), steps: 9_000, distanceMeters: 0, floors: 0)], source: .phone) { _ in .replace }
        store.recomputeDays([yesterday], goal: 8_000)
        store.recomputeDays([yesterday], goal: 10_000)
        #expect(store.summaries(from: yesterday, to: hour(24, from: yesterday)).first?.goal == 8_000)
    }
}
