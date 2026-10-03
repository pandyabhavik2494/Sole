import SwiftUI

/// The rounded surface every section of Sole sits on.
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// A small labelled number, such as distance or floors.
struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// "5 day goal streak" with a nudge toward tomorrow's number.
struct StreakCard: View {
    let streak: Int
    let todaySteps: Int
    let goal: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(streak)")
                .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
                .foregroundStyle(Palette.good)
            VStack(alignment: .leading, spacing: 2) {
                Text("day goal streak")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Palette.goodSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        if todaySteps >= goal {
            "Goal met today. Keep it going tomorrow."
        } else if streak == 0 {
            "Hit \(Format.steps(goal)) today to start one."
        } else {
            "Hit \(Format.steps(goal)) today to make it \(streak + 1)."
        }
    }
}
