import Testing
import Foundation
@testable import MealPlannerCore

enum Fixtures {
    static func date(_ iso: String) -> CalendarDate {
        CalendarDate(isoString: iso)!
    }

    static func ingredient(
        _ name: String,
        _ quantity: Decimal? = nil,
        _ unit: MeasurementUnit? = nil,
        category: IngredientCategory = .other
    ) -> Ingredient {
        Ingredient(name: name, quantity: quantity, unit: unit, category: category)
    }

    static func recipe(
        _ title: String,
        servings: Int = 2,
        ingredients: [Ingredient] = [],
        minutes: Int = 30,
        cuisine: String? = "Test",
        dishType: String? = "Dinner",
        mainIngredient: String? = nil,
        tags: Set<String> = []
    ) -> Recipe {
        Recipe(
            title: title,
            servings: servings,
            cookMinutes: minutes,
            ingredients: ingredients,
            instructions: ["Cook it."],
            cuisine: cuisine,
            dishType: dishType,
            mainIngredient: mainIngredient,
            dietaryTags: tags,
            visibility: .public
        )
    }

    /// A varied candidate set big enough for most planner tests.
    static func candidates(count: Int = 12) -> [PlanningCandidate] {
        let dishTypes = ["Pasta", "Soup", "Salad", "Roast", "Curry", "Tacos"]
        let cuisines = ["Italian", "Thai", "Mexican", "French", "Indian", "Greek"]
        let mains = ["Chicken", "Beef", "Tofu", "Fish", "Lentils", "Eggs"]
        return (0..<count).map { index in
            let recipe = recipe(
                "Recipe \(index)",
                ingredients: [ingredient("Ingredient \(index)", 100, .gram, category: .produce)],
                minutes: 20 + index,
                cuisine: cuisines[index % cuisines.count],
                dishType: dishTypes[index % dishTypes.count],
                mainIngredient: mains[index % mains.count]
            )
            return PlanningCandidate(recipe: recipe, isFavorite: index % 3 == 0)
        }
    }
}
