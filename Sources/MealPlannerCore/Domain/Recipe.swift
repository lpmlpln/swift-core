import Foundation

public enum RecipeVisibility: String, Codable, Hashable, Sendable {
    case `public`
    case `private`
}

public struct RecipeImage: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var url: URL
    public var sourceURL: URL?
    public var sortOrder: Int

    public init(id: UUID = UUID(), url: URL, sourceURL: URL? = nil, sortOrder: Int = 0) {
        self.id = id
        self.url = url
        self.sourceURL = sourceURL
        self.sortOrder = sortOrder
    }
}

public struct Recipe: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var ownerID: UUID?
    public var title: String
    public var description: String?
    public var servings: Int
    public var prepMinutes: Int?
    public var cookMinutes: Int?
    public var ingredients: [Ingredient]
    public var instructions: [String]
    public var cuisine: String?
    public var dishType: String?
    public var mainIngredient: String?
    public var dietaryTags: Set<String>
    public var images: [RecipeImage]
    public var visibility: RecipeVisibility
    public var isImported: Bool
    public var sourceURL: URL?

    public init(
        id: UUID = UUID(),
        ownerID: UUID? = nil,
        title: String,
        description: String? = nil,
        servings: Int,
        prepMinutes: Int? = nil,
        cookMinutes: Int? = nil,
        ingredients: [Ingredient],
        instructions: [String],
        cuisine: String? = nil,
        dishType: String? = nil,
        mainIngredient: String? = nil,
        dietaryTags: Set<String> = [],
        images: [RecipeImage] = [],
        visibility: RecipeVisibility = .private,
        isImported: Bool = false,
        sourceURL: URL? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.description = description
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.ingredients = ingredients
        self.instructions = instructions
        self.cuisine = cuisine
        self.dishType = dishType
        self.mainIngredient = mainIngredient
        self.dietaryTags = Set(dietaryTags.map { $0.lowercased() })
        self.images = images
        self.visibility = visibility
        self.isImported = isImported
        self.sourceURL = sourceURL
    }

    public var totalMinutes: Int? {
        guard prepMinutes != nil || cookMinutes != nil else { return nil }
        return (prepMinutes ?? 0) + (cookMinutes ?? 0)
    }

    public func containsDietaryTags(_ tags: Set<String>) -> Bool {
        let normalized = Set(tags.map { $0.lowercased() })
        return normalized.isSubset(of: dietaryTags)
    }
}

public struct RecipePersonalization: Hashable, Codable, Sendable {
    public var title: String?
    public var servings: Int?
    public var instructions: [String]?
    public var ingredients: [Ingredient]?
    public var notes: String?

    public init(
        title: String? = nil,
        servings: Int? = nil,
        instructions: [String]? = nil,
        ingredients: [Ingredient]? = nil,
        notes: String? = nil
    ) {
        self.title = title
        self.servings = servings
        self.instructions = instructions
        self.ingredients = ingredients
        self.notes = notes
    }

    public func applying(to recipe: Recipe) -> Recipe {
        var result = recipe
        if let title { result.title = title }
        if let servings { result.servings = servings }
        if let instructions { result.instructions = instructions }
        if let ingredients { result.ingredients = ingredients }
        return result
    }
}
