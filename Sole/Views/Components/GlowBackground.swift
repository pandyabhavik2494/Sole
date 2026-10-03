import SwiftUI

/// The soft coloured backdrop behind each tab, so the glass tab bar and buttons have something to
/// refract. It warms up as today's steps approach the goal. With Reduce Transparency on it is the
/// flat system background instead.
struct GlowBackground: View {
    var progress: Double = 0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if reduceTransparency {
            Palette.background.ignoresSafeArea()
        } else {
            let strength = colorScheme == .dark ? 0.55 : 1.0
            let warmth = 0.25 + 0.45 * min(max(progress, 0), 1)
            ZStack {
                Palette.background
                RadialGradient(colors: [Palette.accent.opacity(warmth * strength), .clear], center: .topLeading, startRadius: 10, endRadius: 420)
                RadialGradient(colors: [Palette.heart.opacity(0.18 * strength), .clear], center: .topTrailing, startRadius: 10, endRadius: 380)
                RadialGradient(colors: [Palette.oxygen.opacity(0.16 * strength), .clear], center: .bottom, startRadius: 10, endRadius: 520)
            }
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.8), value: progress)
        }
    }
}
