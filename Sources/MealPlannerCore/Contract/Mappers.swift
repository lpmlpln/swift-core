import Foundation

public extension IngredientDTO {
    init(ingredient: Ingredient) {
        self.init(
            id: ingredient.id,
            name: ingredient.name,
            quantity: ingredient.quantity,
            unit: ingredient.unit?.rawValue,
            note: ingredient.note,
            category: ingredient.category
        )
    }

    func domain() -> Ingredient {
        Ingredient(
            id: id,
            name: name,
            quantity: quantity,
            unit: unit.flatMap(MeasurementUnit.parse),
            note: note,
            category: category
        )
    }
}

public extension RecipeDTO {
    init(recipe: Recipe, isFavorite: Bool = false, isBlocked: Bool = false, personalization: PersonalizationDTO? = nil) {
        self.init(
            id: recipe.id,
            ownerID: recipe.ownerID,
            title: recipe.title,
            description: recipe.description,
            servings: recipe.servings,
            prepMinutes: recipe.prepMinutes,
            cookMinutes: recipe.cookMinutes,
            ingredients: recipe.ingredients.map(IngredientDTO.init(ingredient:)),
            instructions: recipe.instructions,
            cuisine: recipe.cuisine,
            dishType: recipe.dishType,
            mainIngredient: recipe.mainIngredient,
            dietaryTags: recipe.dietaryTags.sorted(),
            images: recipe.images.map { RecipeImageDTO(id: $0.id, url: $0.url, sortOrder: $0.sortOrder) },
            visibility: recipe.visibility,
            isImported: recipe.isImported,
            sourceURL: recipe.sourceURL,
            isFavorite: isFavorite,
            isBlocked: isBlocked,
            isOwner: recipe.ownerID != nil,
            personalization: personalization,
            updatedAt: Date()
        )
    }

    /// The canonical recipe without personalization.
    func canonical() -> Recipe {
        Recipe(
            id: id,
            ownerID: ownerID,
            title: title,
            description: description,
            servings: servings,
            prepMinutes: prepMinutes,
            cookMinutes: cookMinutes,
            ingredients: ingredients.map { $0.domain() },
            instructions: instructions,
            cuisine: cuisine,
            dishType: dishType,
            mainIngredient: mainIngredient,
            dietaryTags: Set(dietaryTags),
            images: images.map { RecipeImage(id: $0.id, url: $0.url, sortOrder: $0.sortOrder) },
            visibility: visibility,
            isImported: isImported,
            sourceURL: sourceURL
        )
    }

    /// The recipe the user sees and that planning/shopping must use.
    func effective() -> Recipe {
        var recipe = canonical()
        if let personalization {
            var overlay = RecipePersonalization(
                title: personalization.title,
                servings: personalization.servings,
                instructions: personalization.instructions,
                ingredients: personalization.ingredients?.map { $0.domain() }
            )
            recipe = overlay.applying(to: recipe)
        }
        return recipe
    }
}

public extension PlanEntryDTO {
    func domain() -> PlanEntry {
        PlanEntry(
            key: PlanEntryKey(date: date, slot: slot),
            recipeID: recipeID,
            servings: servings,
            isLocked: isLocked,
            isLeftover: isLeftover,
            batchID: batchID,
            recipeTitleSnapshot: recipeTitle
        )
    }

    init(entry: PlanEntry, recipeTitle: String, imageURL: URL? = nil) {
        self.init(
            date: entry.key.date,
            slot: entry.key.slot,
            recipeID: entry.recipeID,
            recipeTitle: recipeTitle,
            imageURL: imageURL,
            servings: entry.servings,
            isLocked: entry.isLocked,
            isLeftover: entry.isLeftover,
            batchID: entry.batchID
        )
    }
}

public extension PlanDTO {
    func domain() -> Plan {
        Plan(
            id: id,
            ownerID: ownerID,
            name: name,
            startDate: startDate,
            dayCount: dayCount,
            slots: slots,
            rules: rules,
            entries: entries.map { $0.domain() },
            createdAt: updatedAt,
            updatedAt: updatedAt
        )
    }
}

public extension ShoppingItemDTO {
    func domain() -> ShoppingItem {
        ShoppingItem(
            key: key,
            name: name,
            quantity: quantity,
            unit: unit.flatMap(MeasurementUnit.parse),
            note: note,
            category: category,
            isChecked: isChecked
        )
    }

    init(item: ShoppingItem) {
        self.init(
            key: item.key,
            name: item.name,
            quantity: item.quantity,
            unit: item.unit?.rawValue,
            note: item.note,
            category: item.category,
            isChecked: item.isChecked
        )
    }
}

public extension ShoppingListDTO {
    func domain() -> ShoppingList {
        ShoppingList(
            planID: planID,
            items: items.map { $0.domain() },
            generatedAt: generatedAt,
            sourcePlanHash: ""
        )
    }
}
