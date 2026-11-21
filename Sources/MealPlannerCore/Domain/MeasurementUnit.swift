import Foundation

public enum UnitDimension: String, Codable, Hashable, Sendable {
    case mass
    case volume
    case count
    case qualitative
    case unknown
}

/// Units used by recipe ingredients.
///
/// The raw values are canonical short codes stored in the API and database.
public enum MeasurementUnit: String, CaseIterable, Codable, Hashable, Sendable {
    case gram = "g"
    case kilogram = "kg"
    case ounce = "oz"
    case pound = "lb"

    case milliliter = "ml"
    case liter = "l"
    case teaspoon = "tsp"
    case tablespoon = "tbsp"
    case cup = "cup"
    case fluidOunce = "fl oz"
    case pint = "pt"
    case quart = "qt"

    case piece = "piece"
    case clove = "clove"
    case can = "can"
    case slice = "slice"
    case bunch = "bunch"
    case package = "package"

    case pinch = "pinch"
    case dash = "dash"
    case toTaste = "to taste"
    case asNeeded = "as needed"
    case unknown = "unknown"

    public var dimension: UnitDimension {
        switch self {
        case .gram, .kilogram, .ounce, .pound:
            .mass
        case .milliliter, .liter, .teaspoon, .tablespoon, .cup, .fluidOunce, .pint, .quart:
            .volume
        case .piece, .clove, .can, .slice, .bunch, .package:
            .count
        case .pinch, .dash, .toTaste, .asNeeded:
            .qualitative
        case .unknown:
            .unknown
        }
    }

    /// Factor to the dimension's base unit: grams, milliliters, or count.
    public var baseFactor: Decimal? {
        switch self {
        case .gram: 1
        case .kilogram: 1_000
        case .ounce: Decimal(string: "28.349523125")
        case .pound: Decimal(string: "453.59237")

        case .milliliter: 1
        case .liter: 1_000
        case .teaspoon: Decimal(string: "4.92892159375")
        case .tablespoon: Decimal(string: "14.78676478125")
        case .cup: Decimal(string: "236.5882365")
        case .fluidOunce: Decimal(string: "29.5735295625")
        case .pint: Decimal(string: "473.176473")
        case .quart: Decimal(string: "946.352946")

        case .piece, .clove, .can, .slice, .bunch, .package:
            1
        case .pinch, .dash, .toTaste, .asNeeded, .unknown:
            nil
        }
    }

    public var displayName: String {
        switch self {
        case .gram: "g"
        case .kilogram: "kg"
        case .ounce: "oz"
        case .pound: "lb"
        case .milliliter: "ml"
        case .liter: "l"
        case .teaspoon: "tsp"
        case .tablespoon: "tbsp"
        case .cup: "cup"
        case .fluidOunce: "fl oz"
        case .pint: "pt"
        case .quart: "qt"
        case .piece: "piece"
        case .clove: "clove"
        case .can: "can"
        case .slice: "slice"
        case .bunch: "bunch"
        case .package: "package"
        case .pinch: "pinch"
        case .dash: "dash"
        case .toTaste: "to taste"
        case .asNeeded: "as needed"
        case .unknown: "unknown"
        }
    }

    public var isConvertible: Bool {
        baseFactor != nil && dimension != .unknown
    }

    /// Parses common recipe unit spellings. Returns nil for unknown units.
    public static func parse(_ raw: String) -> MeasurementUnit? {
        let normalized = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "  ", with: " ")

        switch normalized {
        case "g", "gr", "gram", "grams":
            return .gram
        case "kg", "kilogram", "kilograms":
            return .kilogram
        case "oz", "ounce", "ounces":
            return .ounce
        case "lb", "lbs", "pound", "pounds":
            return .pound
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres":
            return .milliliter
        case "l", "liter", "liters", "litre", "litres":
            return .liter
        case "tsp", "teaspoon", "teaspoons":
            return .teaspoon
        case "tbsp", "tbs", "tablespoon", "tablespoons":
            return .tablespoon
        case "cup", "cups":
            return .cup
        case "fl oz", "floz", "fluid ounce", "fluid ounces":
            return .fluidOunce
        case "pt", "pint", "pints":
            return .pint
        case "qt", "quart", "quarts":
            return .quart
        case "piece", "pieces", "pc", "pcs":
            return .piece
        case "clove", "cloves":
            return .clove
        case "can", "cans", "tin", "tins":
            return .can
        case "slice", "slices":
            return .slice
        case "bunch", "bunches":
            return .bunch
        case "package", "packages", "pkg", "pkgs", "packet", "packets":
            return .package
        case "pinch", "pinches":
            return .pinch
        case "dash", "dashes":
            return .dash
        case "to taste":
            return .toTaste
        case "as needed":
            return .asNeeded
        default:
            return nil
        }
    }
}

public enum UnitConverter {
    public static func toBase(_ value: Decimal, unit: MeasurementUnit) -> Decimal? {
        guard let factor = unit.baseFactor else { return nil }
        return value * factor
    }

    public static func fromBase(_ value: Decimal, unit: MeasurementUnit) -> Decimal? {
        guard let factor = unit.baseFactor, factor != 0 else { return nil }
        return value / factor
    }

    public static func convert(
        _ value: Decimal,
        from source: MeasurementUnit,
        to target: MeasurementUnit
    ) -> Decimal? {
        guard source.dimension == target.dimension,
              let base = toBase(value, unit: source),
              let converted = fromBase(base, unit: target)
        else {
            return nil
        }
        return converted
    }

    public static func canConvert(_ lhs: MeasurementUnit, _ rhs: MeasurementUnit) -> Bool {
        lhs.dimension == rhs.dimension && lhs.isConvertible && rhs.isConvertible
    }
}
