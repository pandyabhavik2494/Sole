import SwiftUI

/// A 270° arc that fills toward the daily goal, with the step count in the middle.
struct ProgressArc: View {
    let steps: Int
    let goal: Int
    var lineWidth: CGFloat = 18

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

#Preview {
    ProgressArc(steps: 7_842, goal: 10_000)
        .frame(width: 260, height: 260)
        .padding()
        .background(Palette.background)
}
