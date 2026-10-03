#if DEBUG
import Foundation

/// Fills the store with 120 days of made-up steps, for the simulator (which has no step sensor)
/// and for screenshots. Run with the launch argument `-seedSampleData`.
@MainActor
enum SampleData {
    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-seedSampleData") }

    static func seed(into store: StepStore, goal: Int, calendar: Calendar = .current) {
        var generator = SeededGenerator(seed: 42)
        let now = Date.now
        let today = calendar.startOfDay(for: now)
        var samples: [HourSample] = []
        var days = Set<Date>()

        for offset in 0..<120 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            days.insert(day)
            let activeDay = Double.random(in: 0.5...1.6, using: &generator)
            for hour in StepMath.hours(of: day, calendar: calendar) where hour < now {
                let clock = calendar.component(.hour, from: hour)
                guard (7...21).contains(clock) else { continue }
                let peak = [8, 12, 18].contains(clock) ? 2.6 : 1.0
                let steps = Int(Double.random(in: 150...650, using: &generator) * peak * activeDay)
                samples.append(HourSample(hour: hour, steps: steps, distanceMeters: Double(steps) * 0.75, floors: Int.random(in: 0...2, using: &generator)))
            }
        }
        store.upsert(samples, source: .phone) { _ in .keepHigher }
        store.recomputeDays(days, goal: goal)
        store.save()
    }
}

extension SampleData {
    /// About 13 months of made-up Health metrics and two tagged days, so every v2 screen has data
    /// in the simulator. Resting heart rate falls over the last month; a sick day spikes it.
    static func seedMetrics(into store: MetricsStore, calendar: Calendar = .current) {
        var generator = SeededGenerator(seed: 7)
        let today = DayKey(.now, calendar: calendar)
        let first = today.adding(days: -400)
        let sick = today.adding(days: -6)
        let travel = today.adding(days: -20)
        var values: [Metric: [DailyValue]] = [:]

        func noise(_ amount: Double) -> Double { Double.random(in: -amount...amount, using: &generator) }

        for day in (first...today).days {
            let age = Double(day.days(to: today))
            let recentDrop = age < 30 ? (30 - age) / 30 * 4 : 0
            let spike = day == sick ? 9.0 : day == sick.adding(days: 1) ? 5 : 0
            let rhr = 61 - recentDrop + spike + noise(1.6)
            values[.restingHeartRate, default: []].append(DailyValue(day: day, metric: .restingHeartRate, value: rhr, min: nil, max: nil))
            values[.walkingHeartRate, default: []].append(DailyValue(day: day, metric: .walkingHeartRate, value: 101 - recentDrop / 2 + noise(2.5), min: nil, max: nil))
            values[.heartRate, default: []].append(DailyValue(day: day, metric: .heartRate, value: 74 + noise(4), min: rhr - 6 + noise(2), max: 135 + noise(20)))
            let partial = day == today ? 0.45 : 1
            values[.activeEnergy, default: []].append(DailyValue(day: day, metric: .activeEnergy, value: (640 + noise(170)) * partial, min: nil, max: nil))
            values[.restingEnergy, default: []].append(DailyValue(day: day, metric: .restingEnergy, value: (1_640 + noise(30)) * partial, min: nil, max: nil))
            if Int.random(in: 0..<10, using: &generator) < 8 {
                values[.bloodOxygen, default: []].append(DailyValue(day: day, metric: .bloodOxygen, value: 97 + noise(1), min: 94 + noise(1), max: 99))
            }
            if Int.random(in: 0..<10, using: &generator) < 5 || day == today {
                values[.weight, default: []].append(DailyValue(day: day, metric: .weight, value: 76.2 - (400 - age) / 400 * 1.8 + noise(0.4), min: nil, max: nil))
            }
        }
        for (metric, daily) in values {
            store.replace(metric, with: daily, from: first, through: today)
        }
        store.setTags([.sick], on: sick)
        store.setTags([.travel], on: travel)
        store.setTags([.lateNight], on: today.adding(days: -2))
        store.save()
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
#endif
