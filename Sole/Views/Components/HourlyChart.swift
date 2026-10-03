import Charts
import SwiftUI

/// Steps for each hour of one day.
struct HourlyChart: View {
    let detail: DayDetail
    var height: CGFloat = 120

    var body: some View {
        Chart(detail.hours) { hour in
            BarMark(
                x: .value("Hour", hour.hour, unit: .hour),
                y: .value("Steps", hour.steps)
            )
            .foregroundStyle(Palette.accent)
            .cornerRadius(2)
        }
        .chartXScale(domain: (detail.hours.first?.hour ?? detail.day)...(detail.hours.last.map { $0.hour.addingTimeInterval(3600) } ?? detail.day))
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour(), anchor: .topLeading)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let steps = value.as(Int.self) { Text(Format.compactSteps(steps)) }
                }
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Steps by hour")
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let walked = detail.hours.filter { $0.steps > 0 }
        guard let peak = detail.peakHour else { return "No steps yet" }
        return "\(walked.count) hours with steps. Busiest hour \(peak.hour.formatted(.dateTime.hour())) with \(Format.steps(peak.steps)) steps."
    }
}
