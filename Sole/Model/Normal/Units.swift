import Foundation

enum MassUnit: String, Codable, Sendable, CaseIterable {
    case kilograms, pounds, stones
}

enum EnergyUnit: String, Codable, Sendable, CaseIterable {
    case kilocalories, kilojoules
}

/// The units the user picked in the Health app. Sole stores kilograms and kilocalories and
/// converts only for display, so changing units in Health never rewrites the cache.
struct UnitPreferences: Codable, Equatable, Sendable {
    var mass: MassUnit
    var energy: EnergyUnit

    static let metric = UnitPreferences(mass: .kilograms, energy: .kilocalories)

    static let poundsPerKilogram = 2.204_622_621_8
    static let kilojoulesPerKilocalorie = 4.184

    /// Builds preferences from HealthKit unit strings (`HKUnit.unitString`), such as "lb" or "kJ".
    /// Unknown strings fall back to `fallback`.
    init(massUnitString: String?, energyUnitString: String?, fallback: UnitPreferences = .metric) {
        switch massUnitString {
        case "kg": mass = .kilograms
        case "lb": mass = .pounds
        case "st": mass = .stones
        default: mass = fallback.mass
        }
        switch energyUnitString {
        case "kcal", "Cal": energy = .kilocalories
        case "kJ": energy = .kilojoules
        default: energy = fallback.energy
        }
    }

    init(mass: MassUnit, energy: EnergyUnit) {
        self.mass = mass
        self.energy = energy
    }

    /// Converts a canonical value (kg, kcal, …) into the user's unit.
    func display(_ value: Double, for metric: Metric) -> Double {
        switch metric {
        case .weight:
            switch mass {
            case .kilograms: value
            case .pounds: value * Self.poundsPerKilogram
            case .stones: value * Self.poundsPerKilogram / 14
            }
        case .activeEnergy, .restingEnergy:
            energy == .kilojoules ? value * Self.kilojoulesPerKilocalorie : value
        default:
            value
        }
    }

    /// Converts a value typed in the user's unit back to canonical.
    func canonical(_ value: Double, for metric: Metric) -> Double {
        let one = display(1, for: metric)
        return one == 0 ? value : value / one
    }

    func symbol(for metric: Metric) -> String {
        switch metric {
        case .steps: "steps"
        case .restingHeartRate, .walkingHeartRate, .heartRate: "bpm"
        case .activeEnergy, .restingEnergy: energy == .kilojoules ? "kJ" : "kcal"
        case .bloodOxygen: "%"
        case .weight:
            switch mass {
            case .kilograms: "kg"
            case .pounds: "lb"
            case .stones: "st"
            }
        }
    }

    /// Decimal places worth showing for a metric in this unit.
    func fractionDigits(for metric: Metric) -> Int {
        metric == .weight ? 1 : 0
    }

    /// "56", "2,310", "74.6": the number alone, in the user's unit.
    func number(_ value: Double, for metric: Metric, locale: Locale = .current) -> String {
        let digits = fractionDigits(for: metric)
        return display(value, for: metric).formatted(.number.precision(.fractionLength(digits)).locale(locale))
    }

    /// "56 bpm", "97%", "74.6 kg".
    func format(_ value: Double, for metric: Metric, locale: Locale = .current) -> String {
        let number = number(value, for: metric, locale: locale)
        return metric == .bloodOxygen ? "\(number)%" : "\(number) \(symbol(for: metric))"
    }

    /// A change such as "2 bpm" or "0.4 kg", always positive; the caller says up or down.
    func formatChange(_ delta: Double, for metric: Metric, locale: Locale = .current) -> String {
        let digits = metric == .weight ? 1 : 0
        let number = abs(display(delta, for: metric)).formatted(.number.precision(.fractionLength(digits)).locale(locale))
        switch metric {
        case .bloodOxygen: return "\(number) points"
        case .steps: return "\(number) steps"
        default: return "\(number) \(symbol(for: metric))"
        }
    }
}
