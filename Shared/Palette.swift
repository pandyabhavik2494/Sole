import SwiftUI
import UIKit

/// Sole's colours, matching docs/mockups.html. Each has a light and a dark value.
enum Palette {
    static let ink = Color(light: 0x16213A, dark: 0xE7EBF3)
    static let muted = Color(light: 0x5D6A80, dark: 0x9AA5B8)
    static let background = Color(light: 0xEEF1F4, dark: 0x0F1420)
    static let surface = Color(light: 0xFFFFFF, dark: 0x171E2D)
    static let line = Color(light: 0xD6DCE5, dark: 0x2A3346)
    /// Saffron: progress toward the goal.
    static let accent = Color(light: 0xE8A317, dark: 0xF2B53A)
    static let accentSoft = Color(light: 0xFBEDC9, dark: 0x3B3120)
    /// Green: goal met.
    static let good = Color(light: 0x2F9E6A, dark: 0x4CC48B)
    static let goodSoft = Color(light: 0xD9F1E4, dark: 0x1A3428)
    /// Text drawn on top of the accent colour.
    static let onAccent = Color(light: 0x1A1406, dark: 0x1A1406)
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
