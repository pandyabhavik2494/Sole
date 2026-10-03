import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Every stored day as a spreadsheet file, for the share sheet.
struct CSVExport: Transferable {
    struct Row {
        var day: Date
        var steps: Int
        var distanceMeters: Double
        var floors: Int
        var goal: Int
    }

    let rows: [Row]
    let unit: DistanceUnit

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(export.fileName)
            try export.csv.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }

    var fileName: String {
        "Sole steps \(Date.now.formatted(.iso8601.year().month().day())).csv"
    }

    var csv: String {
        var lines = ["date,steps,distance_\(unit.symbol),floors,goal,goal_met"]
        let dayFormat = Date.ISO8601FormatStyle(timeZone: .current).year().month().day()
        for row in rows {
            let distance = unit.value(fromMeters: row.distanceMeters).formatted(.number.precision(.fractionLength(2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
            lines.append("\(row.day.formatted(dayFormat)),\(row.steps),\(distance),\(row.floors),\(row.goal),\(row.steps >= row.goal ? "yes" : "no")")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
