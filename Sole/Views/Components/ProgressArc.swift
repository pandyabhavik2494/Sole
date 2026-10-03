import SwiftUI

/// A 270° arc that fills toward the daily goal, with the step count in the middle.
struct ProgressArc: View {
    let steps: Int
    let goal: Int
    var lineWidth: CGFloat = 18
    /// Where you usually are by now on this weekday, drawn as a tick across the arc.
    var usualPace: Int?

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1)
    }

    private var goalMet: Bool { goal > 0 && steps >= goal }

    var body: some View {
        ZStack {
            arc(to: 1)
                .stroke(Palette.line, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            arc(to: progress)
                .stroke(goalMet ? Palette.good : Palette.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .animation(.easeOut(duration: 0.6), value: progress)

            if let usualPace, goal > 0 {
                PaceTick(fraction: min(Double(usualPace) / Double(goal), 1), lineWidth: lineWidth)
            }

            VStack(spacing: 4) {
                Text(Format.steps(steps))
                    .font(.system(size: 54, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText(value: Double(steps)))
                    .animation(.default, value: steps)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("of \(Format.steps(goal)) steps")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                Text(goalMet ? "Goal reached" : "\(Format.steps(goal - steps)) to go")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(goalMet ? Palette.good : Palette.accent)
                    .padding(.top, 2)
            }
            .padding(.horizontal, lineWidth * 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Format.steps(steps)) of \(Format.steps(goal)) steps")
        .accessibilityValue(goalMet ? "Goal reached" : "\(Format.steps(goal - steps)) to go")
    }

    /// Opens at the bottom: starts at 7:30 on a clock face and sweeps 270° clockwise.
    private func arc(to fraction: Double) -> some Shape {
        Circle()
            .trim(from: 0, to: 0.75 * fraction)
            .rotation(.degrees(135))
    }
}

/// A short bar across the arc at `fraction` of the way round.
private struct PaceTick: View {
    let fraction: Double
    let lineWidth: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            let angle = Angle.degrees(135 + 270 * fraction)
            Capsule()
                .fill(Palette.ink)
                .frame(width: lineWidth + 10, height: 3.5)
                .overlay(Capsule().stroke(Palette.surface, lineWidth: 1))
                .rotationEffect(angle)
                .position(
                    x: proxy.size.width / 2 + radius * cos(angle.radians),
                    y: proxy.size.height / 2 + radius * sin(angle.radians)
                )
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    ProgressArc(steps: 7_842, goal: 10_000, usualPace: 6_700)
        .frame(width: 260, height: 260)
        .padding()
        .background(Palette.background)
}
