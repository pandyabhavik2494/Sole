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

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
#endif
