import Foundation
import SwiftData

/// Reads and writes the `DailyMetric` cache and day tags. Main actor only, like every SwiftData
/// access in Sole.
@MainActor
final class MetricsStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Daily values

    /// Cached values for one metric between two days, inclusive.
    func values(for metric: Metric, from start: DayKey, through end: DayKey) -> [DayKey: DailyValue] {
        let raw = metric.rawValue
        let low = start.rawValue
        let high = end.rawValue
        let descriptor = FetchDescriptor<DailyMetric>(predicate: #Predicate {
            $0.metricRaw == raw && $0.dayKey >= low && $0.dayKey <= high
        })
        var result: [DayKey: DailyValue] = [:]
        for row in (try? context.fetch(descriptor)) ?? [] {
            if let daily = row.daily { result[daily.day] = daily }
        }
        return result
    }

    /// The oldest cached day for any metric, or nil when the cache is empty.
    func oldestDay() -> DayKey? {
        var descriptor = FetchDescriptor<DailyMetric>(sortBy: [SortDescriptor(\.dayKey)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first.map { DayKey(rawValue: $0.dayKey) }
    }

    /// Replaces the cache for one metric over a range of days with what Health returned.
    ///
    /// Days in the range that Health no longer has are removed (data deleted in Health). An empty
    /// answer for the whole range is ignored instead: Health returns nothing when read access is
    /// off, and that shouldn't wipe the cache. Returns whether anything changed.
    @discardableResult
    func replace(_ metric: Metric, with incoming: [DailyValue], from start: DayKey, through end: DayKey) -> Bool {
        guard !incoming.isEmpty else { return false }
        let raw = metric.rawValue
        let low = start.rawValue
        let high = end.rawValue
        let descriptor = FetchDescriptor<DailyMetric>(predicate: #Predicate {
            $0.metricRaw == raw && $0.dayKey >= low && $0.dayKey <= high
        })
        var existing: [Int: DailyMetric] = [:]
        for row in (try? context.fetch(descriptor)) ?? [] {
            if existing[row.dayKey] != nil {
                context.delete(row)
            } else {
                existing[row.dayKey] = row
            }
        }

        var changed = false
        var seen = Set<Int>()
        for daily in incoming where daily.metric == metric {
            let key = daily.day.rawValue
            seen.insert(key)
            if let row = existing[key] {
                if row.value != daily.value || row.minValue != daily.min || row.maxValue != daily.max {
                    row.value = daily.value
                    row.minValue = daily.min
                    row.maxValue = daily.max
                    row.updatedAt = .now
                    changed = true
                }
            } else {
                context.insert(DailyMetric(daily))
                changed = true
            }
        }
        for (key, row) in existing where !seen.contains(key) {
            context.delete(row)
            changed = true
        }
        return changed
    }

    // MARK: Tags

    func tags(from start: DayKey, through end: DayKey) -> [DayKey: Set<DayTagKind>] {
        let low = start.rawValue
        let high = end.rawValue
        let descriptor = FetchDescriptor<DayTag>(predicate: #Predicate { $0.dayKey >= low && $0.dayKey <= high })
        var result: [DayKey: Set<DayTagKind>] = [:]
        for tag in (try? context.fetch(descriptor)) ?? [] {
            if let kind = tag.kind { result[tag.day, default: []].insert(kind) }
        }
        return result
    }

    func allTags() -> [DayKey: Set<DayTagKind>] {
        tags(from: DayKey(rawValue: 0), through: DayKey(rawValue: 99_991_231))
    }

    /// Sets the tags on one day to exactly `kinds`.
    func setTags(_ kinds: Set<DayTagKind>, on day: DayKey) {
        let key = day.rawValue
        let descriptor = FetchDescriptor<DayTag>(predicate: #Predicate { $0.dayKey == key })
        let existing = (try? context.fetch(descriptor)) ?? []
        var kept = Set<DayTagKind>()
        for tag in existing {
            if let kind = tag.kind, kinds.contains(kind), !kept.contains(kind) {
                kept.insert(kind)
            } else {
                context.delete(tag)
            }
        }
        for kind in kinds.subtracting(kept) {
            context.insert(DayTag(day: day, kind: kind))
        }
    }

    func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
