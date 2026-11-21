import Foundation

public struct IngredientAggregator: Sendable {
    public init() {}

    public func aggregate(
        planID: UUID,
        entries: [ShoppingIngredientInput],
        generatedAt: Date = Date(),
        sourcePlanHash: String = ""
    ) -> ShoppingList {
        var accumulators: [String: Accumulator] = [:]

        for entry in entries where !entry.isLeftover {
            guard entry.servings > 0, entry.recipe.servings > 0 else { continue }
            let scale = Decimal(entry.servings) / Decimal(entry.recipe.servings)

            for ingredient in entry.recipe.ingredients {
                let normalized = ingredient.normalizedName
                guard !normalized.isEmpty else { continue }
                let quantity = ingredient.quantity.map { $0 * scale }
                let accumulatorKey = Accumulator.key(
                    normalizedName: normalized,
                    unit: ingredient.unit
                )

                var accumulator = accumulators[accumulatorKey] ?? Accumulator(
                    key: accumulatorKey,
                    name: ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    normalizedName: normalized,
                    unit: ingredient.unit,
                    category: ingredient.category,
                    note: ingredient.note
                )
                accumulator.add(
                    quantity: quantity,
                    unit: ingredient.unit,
                    note: ingredient.note,
                    category: ingredient.category,
                    recipeID: entry.recipe.id
                )
                accumulators[accumulatorKey] = accumulator
            }
        }

        let items = accumulators.values
            .map { $0.materialize() }
            .sorted { lhs, rhs in
                let lhsOrder = IngredientCategory.allCases.firstIndex(of: lhs.category) ?? 0
                let rhsOrder = IngredientCategory.allCases.firstIndex(of: rhs.category) ?? 0
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

        return ShoppingList(
            planID: planID,
            items: items,
            generatedAt: generatedAt,
            sourcePlanHash: sourcePlanHash
        )
    }
}

private struct Accumulator {
    var key: String
    var name: String
    var normalizedName: String
    var unit: MeasurementUnit?
    var category: IngredientCategory
    var note: String?
    var baseQuantity: Decimal?
    var countQuantity: Decimal?
    var hasAnyQuantity: Bool = false
    var sourceRecipeIDs: Set<UUID> = []

    static func key(normalizedName: String, unit: MeasurementUnit?) -> String {
        guard let unit else {
            return "\(normalizedName)|unitless"
        }
        switch unit.dimension {
        case .mass:
            return "\(normalizedName)|mass"
        case .volume:
            return "\(normalizedName)|volume"
        case .count:
            return "\(normalizedName)|count|\(unit.rawValue)"
        case .qualitative:
            return "\(normalizedName)|qualitative|\(unit.rawValue)"
        case .unknown:
            return "\(normalizedName)|unknown|\(unit.rawValue)"
        }
    }

    mutating func add(
        quantity: Decimal?,
        unit: MeasurementUnit?,
        note: String?,
        category: IngredientCategory,
        recipeID: UUID
    ) {
        if self.note == nil, let note { self.note = note }
        if self.category == .other, category != .other { self.category = category }
        if self.unit == nil { self.unit = unit }
        sourceRecipeIDs.insert(recipeID)

        guard let quantity else { return }
        hasAnyQuantity = true

        switch unit?.dimension {
        case .mass, .volume:
            guard let base = UnitConverter.toBase(quantity, unit: unit!) else { return }
            baseQuantity = (baseQuantity ?? 0) + base
        case .count, .unknown, .qualitative, .none:
            countQuantity = (countQuantity ?? 0) + quantity
        }
    }

    func materialize() -> ShoppingItem {
        let resolvedCategory = category == .other
            ? IngredientCategorizer.infer(from: normalizedName)
            : category

        guard hasAnyQuantity else {
            return ShoppingItem(
                key: key,
                name: displayName,
                quantity: nil,
                unit: unit,
                note: note,
                category: resolvedCategory,
                sourceRecipeIDs: sourceRecipeIDs.sorted { $0.uuidString < $1.uuidString }
            )
        }

        switch unit?.dimension {
        case .mass:
            let base = baseQuantity ?? 0
            let displayUnit: MeasurementUnit = base >= 1_000 ? .kilogram : .gram
            let value = UnitConverter.fromBase(base, unit: displayUnit) ?? base
            return ShoppingItem(
                key: key,
                name: displayName,
                quantity: Self.round(value, scale: 2),
                unit: displayUnit,
                note: note,
                category: resolvedCategory,
                sourceRecipeIDs: sourceRecipeIDs.sorted { $0.uuidString < $1.uuidString }
            )
        case .volume:
            let base = baseQuantity ?? 0
            let displayUnit: MeasurementUnit
            if base >= 1_000 {
                displayUnit = .liter
            } else if base >= 240 {
                displayUnit = .cup
            } else {
                displayUnit = .milliliter
            }
            let value = UnitConverter.fromBase(base, unit: displayUnit) ?? base
            let rounded = displayUnit == .cup
                ? Self.roundToQuarter(value)
                : Self.round(value, scale: 2)
            return ShoppingItem(
                key: key,
                name: displayName,
                quantity: rounded,
                unit: displayUnit,
                note: note,
                category: resolvedCategory,
                sourceRecipeIDs: sourceRecipeIDs.sorted { $0.uuidString < $1.uuidString }
            )
        case .count, .unknown, .qualitative, .none:
            return ShoppingItem(
                key: key,
                name: displayName,
                quantity: countQuantity.map { Self.round($0, scale: 2) },
                unit: unit,
                note: note,
                category: resolvedCategory,
                sourceRecipeIDs: sourceRecipeIDs.sorted { $0.uuidString < $1.uuidString }
            )
        }
    }

    private var displayName: String {
        guard let first = name.first else { return name }
        return first.uppercased() + name.dropFirst()
    }

    private static func round(_ value: Decimal, scale: Int) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .plain)
        return output
    }

    private static func roundToQuarter(_ value: Decimal) -> Decimal {
        let scaled = value * 4
        let rounded = round(scaled, scale: 0)
        return rounded / 4
    }
}

public enum IngredientCategorizer {
    private static let keywords: [IngredientCategory: Set<String>] = [
        .produce: [
            "onion", "garlic", "tomato", "potato", "carrot", "pepper", "lettuce",
            "spinach", "broccoli", "apple", "banana", "lemon", "lime", "avocado",
            "cucumber", "zucchini", "mushroom", "celery", "cabbage", "kale",
        ],
        .meat: [
            "chicken", "beef", "pork", "turkey", "lamb", "bacon", "sausage", "ham",
        ],
        .seafood: [
            "fish", "salmon", "tuna", "shrimp", "prawn", "cod", "trout", "sardine",
        ],
        .dairy: [
            "milk", "cheese", "butter", "yogurt", "cream", "egg", "mozzarella",
            "parmesan", "feta",
        ],
        .bakery: [
            "bread", "baguette", "tortilla", "bun", "roll", "pita", "croissant",
        ],
        .frozen: [
            "frozen", "ice cream", "peas",
        ],
        .spices: [
            "salt", "pepper", "cumin", "paprika", "oregano", "basil", "thyme",
            "cinnamon", "turmeric", "curry powder", "chili", "nutmeg",
        ],
        .drinks: [
            "water", "juice", "wine", "beer", "coffee", "tea", "stock", "broth",
        ],
    ]

    public static func infer(from normalizedName: String) -> IngredientCategory {
        let words = Set(normalizedName.split(separator: " ").map(String.init))
        for (category, keys) in keywords {
            if !keys.isDisjoint(with: words) {
                return category
            }
        }
        return .other
    }
}
