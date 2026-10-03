import Foundation
import SwiftData
import Testing
@testable import Sole

@MainActor
struct MetricsStoreTests {
    let container = Persistence.makeInMemoryContainer()
    var store: MetricsStore { MetricsStore(context: container.mainContext) }

    let first = DayKey(year: 2026, month: 9, day: 1)
    let last = DayKey(year: 2026, month: 9, day: 30)

    func value(_ day: Int, _ value: Double, _ metric: Metric = .restingHeartRate) -> DailyValue {
        DailyValue(day: DayKey(year: 2026, month: 9, day: day), metric: metric, value: value, min: nil, max: nil)
    }

    @Test func replaceWritesAndUpdates() {
        let store = store
        store.replace(.restingHeartRate, with: [value(1, 60), value(2, 61)], from: first, through: last)
        store.replace(.restingHeartRate, with: [value(1, 58), value(2, 61)], from: first, through: last)
        let values = store.values(for: .restingHeartRate, from: first, through: last)
        #expect(values.count == 2)
        #expect(values[DayKey(year: 2026, month: 9, day: 1)]?.value == 58)
    }

    @Test func daysDeletedInHealthAreRemoved() {
        let store = store
        store.replace(.restingHeartRate, with: [value(1, 60), value(2, 61)], from: first, through: last)
        store.replace(.restingHeartRate, with: [value(2, 61)], from: first, through: last)
        #expect(store.values(for: .restingHeartRate, from: first, through: last).keys.map(\.day) == [2])
    }

    @Test func anEmptyAnswerKeepsTheCache() {
        // Health returns nothing when read access is off; that must not wipe history.
        let store = store
        store.replace(.restingHeartRate, with: [value(1, 60)], from: first, through: last)
        let changed = store.replace(.restingHeartRate, with: [], from: first, through: last)
        #expect(!changed)
        #expect(store.values(for: .restingHeartRate, from: first, through: last).count == 1)
    }

    @Test func daysOutsideTheRangeAreLeftAlone() {
        let store = store
        store.replace(.restingHeartRate, with: [value(1, 60), value(20, 61)], from: first, through: last)
        store.replace(.restingHeartRate, with: [value(20, 62)], from: DayKey(year: 2026, month: 9, day: 15), through: last)
        #expect(store.values(for: .restingHeartRate, from: first, through: last).count == 2)
    }

    @Test func metricsAreKeptApart() {
        let store = store
        store.replace(.restingHeartRate, with: [value(1, 60)], from: first, through: last)
        store.replace(.weight, with: [value(1, 74.5, .weight)], from: first, through: last)
        #expect(store.values(for: .restingHeartRate, from: first, through: last).count == 1)
        #expect(store.values(for: .weight, from: first, through: last)[DayKey(year: 2026, month: 9, day: 1)]?.value == 74.5)
    }

    @Test func tagsAreSetExactly() {
        let store = store
        let day = DayKey(year: 2026, month: 9, day: 5)
        store.setTags([.sick, .lateNight], on: day)
        store.setTags([.sick, .alcohol], on: day)
        #expect(store.tags(from: first, through: last)[day] == [.sick, .alcohol])
        store.setTags([], on: day)
        #expect(store.tags(from: first, through: last)[day] == nil)
    }
}
