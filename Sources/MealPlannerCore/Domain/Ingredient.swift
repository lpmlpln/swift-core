import Foundation

public enum IngredientCategory: String, CaseIterable, Codable, Hashable, Sendable {
    case produce
    case meat
    case seafood
    case dairy
    case bakery
    case pantry
    case frozen
    case spices
    case drinks
    case other
}

public struct Ingredient: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var quantity: Decimal?
    public var unit: MeasurementUnit?
    public var note: String?
    public var category: IngredientCategory

    public init(
        id: UUID = UUID(),
        name: String,
        quantity: Decimal? = nil,
        unit: MeasurementUnit? = nil,
        note: String? = nil,
        category: IngredientCategory = .other
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.note = note
        self.category = category
    }

    public var normalizedName: String {
        IngredientNormalizer.normalize(name)
    }
}

public enum IngredientNormalizer {
    private static let uncountable: Set<String> = [
        "asparagus", "couscous", "hummus", "molasses", "rice", "quinoa",
        "pasta", "spaghetti", "flour", "sugar", "salt", "pepper", "oil",
        "water", "milk", "butter", "cheese", "yogurt", "bread", "meat",
    ]

    public static func normalize(_ raw: String) -> String {
        var value = raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")

        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        value = String(value.unicodeScalars.filter { allowed.contains($0) })
        value = value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard !value.isEmpty else { return "" }

        var words = value.split(separator: " ").map(String.init)
        if let last = words.last {
            words[words.count - 1] = singularize(last)
        }
        return words.joined(separator: " ")
    }

    private static func singularize(_ word: String) -> String {
        guard word.count > 3, !uncountable.contains(word) else { return word }

        if word.hasSuffix("ies") {
            return String(word.dropLast(3)) + "y"
        }
        if word.hasSuffix("oes") {
            return String(word.dropLast(2))
        }
        if word.hasSuffix("ches") || word.hasSuffix("shes") || word.hasSuffix("xes") || word.hasSuffix("zes") {
            return String(word.dropLast(2))
        }
        if word.hasSuffix("ses") {
            return String(word.dropLast(2))
        }
        if word.hasSuffix("s"), !word.hasSuffix("ss") {
            return String(word.dropLast())
        }
        return word
    }
}
