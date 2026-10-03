import Foundation

/// Fixed calendars so tests don't depend on the machine's time zone.
enum TestCalendars {
    static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    static let losAngeles = calendar("America/Los_Angeles")
    static let london = calendar("Europe/London")
    static let tokyo = calendar("Asia/Tokyo")
    static let kolkata = calendar("Asia/Kolkata")

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, in calendar: Calendar = losAngeles) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
