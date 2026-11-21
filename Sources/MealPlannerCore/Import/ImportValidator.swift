import Foundation

/// A recipe as returned by an importer (JSON-LD or model extraction) before validation.
public struct ImportedRecipeDraft: Hashable, Codable, Sendable {
    public var title: String?
    public var description: String?
    public var servings: Int?
    public var prepMinutes: Int?
    public var cookMinutes: Int?
    public var ingredients: [ImportedIngredient]
    public var instructions: [String]
    public var cuisine: String?
    public var dishType: String?
    public var mainIngredient: String?
    public var dietaryTags: [String]
    public var imageURLs: [URL]
    public var sourceURL: URL?

    public init(
        title: String? = nil,
        description: String? = nil,
        servings: Int? = nil,
        prepMinutes: Int? = nil,
        cookMinutes: Int? = nil,
        ingredients: [ImportedIngredient] = [],
        instructions: [String] = [],
        cuisine: String? = nil,
        dishType: String? = nil,
        mainIngredient: String? = nil,
        dietaryTags: [String] = [],
        imageURLs: [URL] = [],
        sourceURL: URL? = nil
    ) {
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
        self.dietaryTags = dietaryTags
        self.imageURLs = imageURLs
        self.sourceURL = sourceURL
    }
}

public struct ImportedIngredient: Hashable, Codable, Sendable {
    public var raw: String
    public var name: String?
    public var quantity: Decimal?
    public var unit: String?
    public var note: String?

    public init(raw: String, name: String? = nil, quantity: Decimal? = nil, unit: String? = nil, note: String? = nil) {
        self.raw = raw
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.note = note
    }
}

public enum ImportValidationError: String, Error, Hashable, Sendable {
    case missingTitle
    case missingIngredients
    case missingInstructions
    case invalidServings
    case tooManyImages
    case missingSourceURL
}

public struct ImportedRecipe: Hashable, Sendable {
    public var recipe: Recipe
    public var warnings: [String]

    public init(recipe: Recipe, warnings: [String] = []) {
        self.recipe = recipe
        self.warnings = warnings
    }
}

/// Validates importer output and turns it into a canonical public recipe.
public enum ImportValidator {
    public static let maxImages = 5

    public static func validate(
        _ draft: ImportedRecipeDraft,
        ownerID: UUID?,
        recipeID: UUID = UUID(),
        now: Date = Date()
    ) throws -> ImportedRecipe {
        var warnings: [String] = []

        let title = draft.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { throw ImportValidationError.missingTitle }

        guard let sourceURL = draft.sourceURL else { throw ImportValidationError.missingSourceURL }

        let ingredients = draft.ingredients.compactMap { ingredient -> Ingredient? in
            let name = (ingredient.name ?? ingredient.raw).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let unit = ingredient.unit.flatMap(MeasurementUnit.parse)
            if ingredient.unit != nil && unit == nil {
                warnings.append("Unknown unit '\(ingredient.unit!)' for \(name).")
            }
            return Ingredient(
                name: name,
                quantity: ingredient.quantity,
                unit: unit,
                note: ingredient.note,
                category: IngredientCategorizer.infer(from: IngredientNormalizer.normalize(name))
            )
        }
        guard !ingredients.isEmpty else { throw ImportValidationError.missingIngredients }

        let instructions = draft.instructions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !instructions.isEmpty else { throw ImportValidationError.missingInstructions }

        let servings = draft.servings ?? 2
        guard servings > 0 else { throw ImportValidationError.invalidServings }

        var imageURLs = draft.imageURLs
        if imageURLs.count > maxImages {
            imageURLs = Array(imageURLs.prefix(maxImages))
            warnings.append("Only the first \(maxImages) images were kept.")
        }

        let images = imageURLs.enumerated().map { index, url in
            RecipeImage(url: url, sourceURL: url, sortOrder: index)
        }

        let recipe = Recipe(
            id: recipeID,
            ownerID: ownerID,
            title: title,
            description: draft.description?.trimmingCharacters(in: .whitespacesAndNewlines),
            servings: servings,
            prepMinutes: draft.prepMinutes,
            cookMinutes: draft.cookMinutes,
            ingredients: ingredients,
            instructions: instructions,
            cuisine: draft.cuisine,
            dishType: draft.dishType,
            mainIngredient: draft.mainIngredient,
            dietaryTags: Set(draft.dietaryTags),
            images: images,
            visibility: .public,
            isImported: true,
            sourceURL: sourceURL
        )

        return ImportedRecipe(recipe: recipe, warnings: warnings)
    }
}
