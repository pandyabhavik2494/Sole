import SwiftUI

extension Metric {
    var color: Color {
        switch self {
        case .steps: Palette.accent
        case .restingHeartRate, .walkingHeartRate, .heartRate: Palette.heart
        case .activeEnergy, .restingEnergy: Palette.energy
        case .bloodOxygen: Palette.oxygen
        case .weight: Palette.weight
        }
    }

    var symbol: String {
        switch self {
        case .steps: "shoeprints.fill"
        case .restingHeartRate: "heart.fill"
        case .walkingHeartRate: "figure.walk"
        case .heartRate: "waveform.path.ecg"
        case .activeEnergy: "flame.fill"
        case .restingEnergy: "bed.double.fill"
        case .bloodOxygen: "lungs.fill"
        case .weight: "scalemass.fill"
        }
    }
}

extension Status {
    var color: Color {
        switch self {
        case .better: Palette.good
        case .worthALook: Palette.watch
        case .usual: Palette.muted
        case .learning, .noData: Palette.muted.opacity(0.8)
        }
    }

    var softColor: Color {
        switch self {
        case .better: Palette.goodSoft
        case .worthALook: Palette.watchSoft
        default: Palette.line.opacity(0.5)
        }
    }

    /// Never colour alone: each status also has a shape.
    var symbol: String {
        switch self {
        case .better: "arrow.up.heart.fill"
        case .worthALook: "exclamationmark.circle.fill"
        case .usual: "checkmark.circle"
        case .learning: "hourglass"
        case .noData: "minus.circle"
        }
    }
}

extension UnitPreferences {
    /// "58–63 bpm", "7,900–10,800 steps": a usual range in the user's units. Steps round to 100.
    func rangeText(_ range: UsualRange, for metric: Metric) -> String {
        if metric == .steps {
            let low = (range.low / 100).rounded() * 100
            let high = (range.high / 100).rounded() * 100
            return "\(Format.steps(Int(low)))–\(Format.steps(Int(high)))"
        }
        let low = number(range.low, for: metric)
        let high = number(range.high, for: metric)
        let suffix = metric == .bloodOxygen ? "%" : " \(symbol(for: metric))"
        return low == high ? "\(low)\(suffix)" : "\(low)–\(high)\(suffix)"
    }
}
