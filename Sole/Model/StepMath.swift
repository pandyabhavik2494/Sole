import Foundation

/// One hour's values from one source, detached from SwiftData.
struct HourSample: Hashable {
    var hour: Date
    var steps: Int
    var distanceMeters: Double
    var floors: Int
}

/// One hour after merging every source.
struct HourTotal: Hashable, Identifiable {
    var hour: Date
    var steps: Int
    var distanceMeters: Double
    var floors: Int

    var id: Date { hour }
}

/// A day of hourly totals, used by Today and the day detail screen.
struct DayDetail: Equatable {
    var day: Date
    var hours: [HourTotal]

    var steps: Int { hours.reduce(0) { $0 + $1.steps } }
    var distanceMeters: Double { hours.reduce(0) { $0 + $1.distanceMeters } }
    var floors: Int { hours.reduce(0) { $0 + $1.floors } }
    var peakHour: HourTotal? { hours.filter { $0.steps > 0 }.max { $0.steps < $1.steps } }

    static func empty(for day: Date, calendar: Calendar = .current) -> DayDetail {
        DayDetail(day: day, hours: StepMath.hours(of: day, calendar: calendar).map {
            HourTotal(hour: $0, steps: 0, distanceMeters: 0, floors: 0)
        })
    }
}

enum StepMath {
    /// Merges rows for the same hour.
    ///
    /// The iPhone and Apple Health (often an Apple Watch) measure the same walking, so for each
    /// metric the hour keeps the higher of the two rather than adding them. That way carrying a
    /// phone while wearing a watch counts once. Manual entries are added on top.
    static func merge(_ rows: [(source: StepSource, sample: HourSample)]) -> [Date: HourTotal] {
        var measured: [Date: HourTotal] = [:]
        var manual: [Date: HourTotal] = [:]

        for (source, sample) in rows {
            switch source {
            case .phone, .health:
                var total = measured[sample.hour] ?? HourTotal(hour: sample.hour, steps: 0, distanceMeters: 0, floors: 0)
                total.steps = max(total.steps, sample.steps)
                total.distanceMeters = max(total.distanceMeters, sample.distanceMeters)
                total.floors = max(total.floors, sample.floors)
                measured[sample.hour] = total
            case .manual:
                // Duplicate manual rows for one hour (from two devices) are the same entry, so keep the larger.
                var total = manual[sample.hour] ?? HourTotal(hour: sample.hour, steps: 0, distanceMeters: 0, floors: 0)
                total.steps = max(total.steps, sample.steps)
                total.distanceMeters = max(total.distanceMeters, sample.distanceMeters)
                total.floors = max(total.floors, sample.floors)
                manual[sample.hour] = total
            }
        }

        for (hour, extra) in manual {
            var total = measured[hour] ?? HourTotal(hour: hour, steps: 0, distanceMeters: 0, floors: 0)
            total.steps += extra.steps
            total.distanceMeters += extra.distanceMeters
            total.floors += extra.floors
            measured[hour] = total
        }
        return measured
    }

    /// The start of every hour in a day. Usually 24; 23 or 25 on daylight saving days.
    static func hours(of day: Date, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        var result: [Date] = []
        var hour = start
        while hour < end {
            result.append(hour)
            guard let next = calendar.date(byAdding: .hour, value: 1, to: hour) else { break }
            hour = next
        }
        return result
    }

    /// Consecutive days that met their goal, ending today. If today's goal isn't met yet the
    /// streak runs through yesterday, so it doesn't reset to zero every morning.
    static func currentStreak(goalMet: [Date: Bool], today: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: today)
        if goalMet[day] != true {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while goalMet[day] == true {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}

extension Calendar {
    func startOfHour(for date: Date) -> Date {
        dateInterval(of: .hour, for: date)?.start ?? date
    }
}
