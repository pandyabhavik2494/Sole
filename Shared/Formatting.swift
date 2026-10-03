import Foundation

enum DistanceUnit: String, CaseIterable, Identifiable, Codable {
    case kilometers
    case miles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kilometers: "Kilometres"
        case .miles: "Miles"
        }
    }

    var symbol: String {
        switch self {
        case .kilometers: "km"
        case .miles: "mi"
        }
    }

    func value(fromMeters meters: Double) -> Double {
        switch self {
        case .kilometers: meters / 1000
        case .miles: meters / 1609.344
        }
    }

    static var localeDefault: DistanceUnit {
        Locale.current.measurementSystem == .us ? .miles : .kilometers
    }
}

enum Format {
    static func steps(_ value: Int) -> String {
        value.formatted(.number)
    }

    static func distance(_ meters: Double, unit: DistanceUnit) -> String {
        let value = unit.value(fromMeters: meters)
        return "\(value.formatted(.number.precision(.fractionLength(1)))) \(unit.symbol)"
    }

    /// A compact count for tight spaces such as chart axes and Lock Screen widgets: 7.8k.
    static func compactSteps(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName).precision(.significantDigits(1...2)))
    }
}
