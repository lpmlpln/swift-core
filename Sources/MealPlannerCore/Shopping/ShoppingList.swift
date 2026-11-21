import Foundation

public struct ShoppingItem: Identifiable, Hashable, Codable, Sendable {
    public var key: String
    public var name: String
    public var quantity: Decimal?
    public var unit: MeasurementUnit?
    public var note: String?
    public var category: IngredientCategory
    public var isChecked: Bool
    public var sourceRecipeIDs: [UUID]

    public var id: String { key }

    public init(
        key: String,
        name: String,
        quantity: Decimal? = nil,
        unit: MeasurementUnit? = nil,
        note: String? = nil,
        category: IngredientCategory = .other,
        isChecked: Bool = false,
        sourceRecipeIDs: [UUID] = []
    ) {
        self.key = key
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.note = note
        self.category = category
        self.isChecked = isChecked
        self.sourceRecipeIDs = sourceRecipeIDs
    }
}

public struct ShoppingList: Hashable, Codable, Sendable {
    public var planID: UUID
    public var items: [ShoppingItem]
    public var generatedAt: Date
    public var sourcePlanHash: String

    public init(
        planID: UUID,
        items: [ShoppingItem],
        generatedAt: Date = Date(),
        sourcePlanHash: String = ""
    ) {
        self.planID = planID
        self.items = items
        self.generatedAt = generatedAt
        self.sourcePlanHash = sourcePlanHash
    }
}

public struct ShoppingIngredientInput: Sendable {
    public var recipe: Recipe
    public var servings: Int
    public var isLeftover: Bool

    public init(recipe: Recipe, servings: Int, isLeftover: Bool = false) {
        self.recipe = recipe
        self.servings = servings
        self.isLeftover = isLeftover
    }
}
