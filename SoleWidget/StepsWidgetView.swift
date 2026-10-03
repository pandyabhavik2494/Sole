import SwiftUI
import WidgetKit

struct StepsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StepsEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var goalMet: Bool { snapshot.goal > 0 && snapshot.steps >= snapshot.goal }
    private var progressColor: Color { goalMet ? Palette.good : Palette.accent }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Steps", systemImage: "shoeprints.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.muted)
            Spacer()
            Text(Format.steps(snapshot.steps))
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(remaining)
                .font(.caption)
                .foregroundStyle(goalMet ? Palette.good : Palette.muted)
                .padding(.bottom, 8)
            ProgressView(value: snapshot.progress)
                .tint(progressColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 18) {
            ZStack {
                arc(to: 1).stroke(Palette.line, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                arc(to: snapshot.progress).stroke(progressColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                VStack(spacing: 0) {
                    Text(Format.steps(snapshot.steps))
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("steps")
                        .font(.caption2)
                        .foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, 14)
            }
            .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 8) {
                Text(remaining)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(progressColor)
                stat(Format.distance(snapshot.distanceMeters, unit: snapshot.unit), "Distance")
                stat(Format.steps(snapshot.floors), snapshot.floors == 1 ? "Floor" : "Floors")
            }
            Spacer(minLength: 0)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Palette.ink)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Palette.muted)
        }
    }

    // MARK: Lock Screen

    private var circular: some View {
        Gauge(value: snapshot.progress) {
            Image(systemName: "shoeprints.fill")
        } currentValueLabel: {
            Text(Format.compactSteps(snapshot.steps))
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("\(Format.steps(snapshot.steps)) steps", systemImage: "shoeprints.fill")
                .font(.headline)
                .widgetAccentable()
            Text(remaining)
                .font(.caption)
            Gauge(value: snapshot.progress) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
        }
    }

    private var inline: some View {
        Label("\(Format.steps(snapshot.steps)) steps", systemImage: "shoeprints.fill")
    }

    // MARK: Helpers

    private var remaining: String {
        goalMet ? "Goal reached" : "\(Format.steps(snapshot.goal - snapshot.steps)) to go"
    }

    private func arc(to fraction: Double) -> some Shape {
        Circle()
            .trim(from: 0, to: 0.75 * fraction)
            .rotation(.degrees(135))
    }
}

#Preview(as: .systemSmall) {
    StepsWidget()
} timeline: {
    StepsEntry(date: .now, snapshot: .placeholder)
}

#Preview(as: .systemMedium) {
    StepsWidget()
} timeline: {
    StepsEntry(date: .now, snapshot: .placeholder)
}
