import Foundation
import SwiftData

/// How an incoming hourly value is combined with one already stored for the same hour and source.
enum UpsertPolicy {
    /// Keep whichever is larger. Used for older sensor hours, so a count saved while Sole was open
    /// is never lowered by a later, partial sensor read.
    case keepHigher
    /// Overwrite. Used where the incoming value is the truth, such as Health after a deletion.
    case replace
}

/// Reads and writes Sole's SwiftData store.
@MainActor
final class StepStore {
    let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    // MARK: Hourly rows

    func rows(from start: Date, to end: Date, source: StepSource? = nil) -> [HourlySteps] {
        let descriptor: FetchDescriptor<HourlySteps>
        if let raw = source?.rawValue {
            descriptor = FetchDescriptor(
                predicate: #Predicate { $0.hourStart >= start && $0.hourStart < end && $0.sourceRaw == raw },
                sortBy: [SortDescriptor(\.hourStart)]
            )
        } else {
            descriptor = FetchDescriptor(
                predicate: #Predicate { $0.hourStart >= start && $0.hourStart < end },
                sortBy: [SortDescriptor(\.hourStart)]
            )
        }
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Writes hourly values for one source and returns the days whose totals changed.
    ///
    /// - Parameter clearing: when set, rows for this source inside the range that aren't in
    ///   `samples` are deleted. Health uses this so a walk deleted in Health disappears from Sole.
    @discardableResult
    func upsert(
        _ samples: [HourSample],
        source: StepSource,
        clearing range: Range<Date>? = nil,
        policy: (Date) -> UpsertPolicy
    ) -> Set<Date> {
        let hours = samples.map(\.hour)
        guard let first = [hours.min(), range?.lowerBound].compactMap({ $0 }).min(),
              let lastHour = [hours.max(), range.flatMap { calendar.date(byAdding: .hour, value: -1, to: $0.upperBound) }].compactMap({ $0 }).max(),
              let end = calendar.date(byAdding: .hour, value: 1, to: lastHour)
        else { return [] }

        var changedDays = Set<Date>()
        var existing: [Date: HourlySteps] = [:]

        // Should a second row ever exist for the same (hour, source), fold it into one.
        for row in rows(from: first, to: end, source: source) {
            if let kept = existing[row.hourStart] {
                kept.steps = max(kept.steps, row.steps)
                kept.distanceMeters = max(kept.distanceMeters, row.distanceMeters)
                kept.floorsAscended = max(kept.floorsAscended, row.floorsAscended)
                kept.healthWrittenSteps = max(kept.healthWrittenSteps, row.healthWrittenSteps)
                context.delete(row)
                changedDays.insert(calendar.startOfDay(for: row.hourStart))
            } else {
                existing[row.hourStart] = row
            }
        }

        var seen = Set<Date>()
        for sample in samples {
            seen.insert(sample.hour)
            if let row = existing[sample.hour] {
                let new: HourSample
                switch policy(sample.hour) {
                case .replace:
                    new = sample
                case .keepHigher:
                    new = HourSample(
                        hour: sample.hour,
                        steps: max(row.steps, sample.steps),
                        distanceMeters: max(row.distanceMeters, sample.distanceMeters),
                        floors: max(row.floorsAscended, sample.floors)
                    )
                }
                guard new != row.sample else { continue }
                row.steps = new.steps
                row.distanceMeters = new.distanceMeters
                row.floorsAscended = new.floors
                row.updatedAt = .now
                changedDays.insert(calendar.startOfDay(for: sample.hour))
            } else if sample.steps > 0 || sample.distanceMeters > 0 || sample.floors > 0 {
                context.insert(HourlySteps(
                    hourStart: sample.hour,
                    source: source,
                    steps: sample.steps,
                    distanceMeters: sample.distanceMeters,
                    floorsAscended: sample.floors
                ))
                changedDays.insert(calendar.startOfDay(for: sample.hour))
            }
        }

        if let range {
            for (hour, row) in existing where range.contains(hour) && !seen.contains(hour) {
                context.delete(row)
                changedDays.insert(calendar.startOfDay(for: hour))
            }
        }
        return changedDays
    }

    // MARK: Days

    /// Rebuilds the daily summaries for the given days from their hourly rows.
    ///
    /// Today, and any day without a summary yet, takes `goal`. Past days keep the goal they had.
    func recomputeDays(_ days: Set<Date>, goal: Int, now: Date = .now) {
        guard let first = days.min(), let last = days.max(),
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return }

        var rowsByDay: [Date: [(source: StepSource, sample: HourSample)]] = [:]
        for row in rows(from: first, to: end) {
            rowsByDay[calendar.startOfDay(for: row.hourStart), default: []].append((row.source, row.sample))
        }
        var summaries = summariesByDay(from: first, to: end)
        let today = calendar.startOfDay(for: now)

        for day in days {
            let totals = StepMath.merge(rowsByDay[day] ?? []).values
            let steps = totals.reduce(0) { $0 + $1.steps }
            let distance = totals.reduce(0) { $0 + $1.distanceMeters }
            let floors = totals.reduce(0) { $0 + $1.floors }

            let summary: DailySummary
            if let existing = summaries[day] {
                summary = existing
                if day == today { summary.goal = goal }
            } else {
                guard steps > 0 || day == today else { continue }
                summary = DailySummary(day: day, goal: goal)
                context.insert(summary)
                summaries[day] = summary
            }
            if summary.steps != steps || summary.distanceMeters != distance || summary.floors != floors {
                summary.steps = steps
                summary.distanceMeters = distance
                summary.floors = floors
                summary.updatedAt = .now
            }
        }
    }

    /// Summaries keyed by day, with any duplicates for a day folded into one.
    func summariesByDay(from start: Date, to end: Date) -> [Date: DailySummary] {
        var result: [Date: DailySummary] = [:]
        for summary in summaries(from: start, to: end) {
            let day = calendar.startOfDay(for: summary.day)
            if let kept = result[day] {
                kept.steps = max(kept.steps, summary.steps)
                kept.distanceMeters = max(kept.distanceMeters, summary.distanceMeters)
                kept.floors = max(kept.floors, summary.floors)
                context.delete(summary)
            } else {
                result[day] = summary
            }
        }
        return result
    }

    func summaries(from start: Date, to end: Date) -> [DailySummary] {
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.day >= start && $0.day < end },
            sortBy: [SortDescriptor(\.day)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func allSummaries() -> [DailySummary] {
        let descriptor = FetchDescriptor<DailySummary>(sortBy: [SortDescriptor(\.day)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func dayDetail(for day: Date) -> DayDetail {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return .empty(for: start) }
        let merged = StepMath.merge(rows(from: start, to: end).map { ($0.source, $0.sample) })
        let hours = StepMath.hours(of: start, calendar: calendar).map {
            merged[$0] ?? HourTotal(hour: $0, steps: 0, distanceMeters: 0, floors: 0)
        }
        return DayDetail(day: start, hours: hours)
    }

    /// Days in a row that met their goal, ending today (or yesterday if today isn't met yet).
    func currentStreak(now: Date = .now) -> Int {
        let start = calendar.date(byAdding: .day, value: -400, to: calendar.startOfDay(for: now)) ?? .distantPast
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        var goalMet: [Date: Bool] = [:]
        for summary in summaries(from: start, to: end) {
            let day = calendar.startOfDay(for: summary.day)
            goalMet[day] = (goalMet[day] ?? false) || summary.goalMet
        }
        return StepMath.currentStreak(goalMet: goalMet, today: now, calendar: calendar)
    }

    func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
