import Testing
import Foundation
@testable import MealPlannerCore

@Suite("Shopping list aggregation")
struct IngredientAggregatorTests {
    let aggregator = IngredientAggregator()

    @Test("Scales ingredients by servings")
    func scalesServings() {
        let recipe = Fixtures.recipe(
            "Soup",
            servings: 2,
            ingredients: [Fixtures.ingredient("Carrot", 100, .gram, category: .produce)]
        )
        let list = aggregator.aggregate(
            planID: UUID(),
            entries: [ShoppingIngredientInput(recipe: recipe, servings: 4)]
        )
        #expect(list.items.count == 1)
        #expect(list.items[0].quantity == 200)
        #expect(list.items[0].unit == .gram)
    }

    @Test("Combines compatible units")
    func combinesUnits() {
        let a = Fixtures.recipe("A", ingredients: [Fixtures.ingredient("Flour", 500, .gram)])
        let b = Fixtures.recipe("B", ingredients: [Fixtures.ingredient("Flour", 1, .kilogram)])
        let list = aggregator.aggregate(
            planID: UUID(),
            entries: [
                ShoppingIngredientInput(recipe: a, servings: 2),
                ShoppingIngredientInput(recipe: b, servings: 2),
            ]
        )
        #expect(list.items.count == 1)
        #expect(list.items[0].quantity == Decimal(string: "1.5"))
        #expect(list.items[0].unit == .kilogram)
    }

    @Test("Keeps incompatible units separate")
    func incompatibleUnits() {
        let a = Fixtures.recipe("A", ingredients: [Fixtures.ingredient("Milk", 200, .milliliter)])
        let b = Fixtures.recipe("B", ingredients: [Fixtures.ingredient("Milk", 1, .piece)])
        let list = aggregator.aggregate(
            planID: UUID(),
            entries: [
                ShoppingIngredientInput(recipe: a, servings: 2),
                ShoppingIngredientInput(recipe: b, servings: 2),
            ]
        )
        #expect(list.items.count == 2)
    }

    @Test("Counts leftovers only once")
    func leftoversCountedOnce() {
        let recipe = Fixtures.recipe(
            "Chili",
            servings: 2,
            ingredients: [Fixtures.ingredient("Beans", 400, .gram)]
        )
        let list = aggregator.aggregate(
            planID: UUID(),
            entries: [
                ShoppingIngredientInput(recipe: recipe, servings: 2, isLeftover: false),
                ShoppingIngredientInput(recipe: recipe, servings: 2, isLeftover: true),
                ShoppingIngredientInput(recipe: recipe, servings: 2, isLeftover: true),
            ]
        )
        #expect(list.items.count == 1)
        #expect(list.items[0].quantity == 400)
    }

    @Test("Keeps ingredients without quantity")
    func qualitativeIngredients() {
        let recipe = Fixtures.recipe(
            "Salad",
            ingredients: [Fixtures.ingredient("Salt", nil, nil, category: .spices)]
        )
        let list = aggregator.aggregate(
            planID: UUID(),
            entries: [ShoppingIngredientInput(recipe: recipe, servings: 2)]
        )
        #expect(list.items.count == 1)
        #expect(list.items[0].quantity == nil)
    }

    @Test("Groups items by category order")
    func categoryOrdering() {
        let recipe = Fixtures.recipe("Mixed", ingredients: [
            Fixtures.ingredient("Salt", 1, .teaspoon, category: .spices),
            Fixtures.ingredient("Chicken", 300, .gram, category: .meat),
            Fixtures.ingredient("Apple", 2, .piece, category: .produce),
        ])
        let list = aggregator.aggregate(
            planID: UUID(),
            entries: [ShoppingIngredientInput(recipe: recipe, servings: 2)]
        )
        let categories = list.items.map(\.category)
        #expect(categories == [.produce, .meat, .spices])
    }

    @Test("Normalizes names when grouping")
    func nameGrouping() {
        let a = Fixtures.recipe("A", ingredients: [Fixtures.ingredient("Tomatoes", 2, .piece)])
        let b = Fixtures.recipe("B", ingredients: [Fixtures.ingredient("tomato", 3, .piece)])
        let list = aggregator.aggregate(
            planID: UUID(),
            entries: [
                ShoppingIngredientInput(recipe: a, servings: 2),
                ShoppingIngredientInput(recipe: b, servings: 2),
            ]
        )
        #expect(list.items.count == 1)
        #expect(list.items[0].quantity == 5)
    }

    @Test("Ignores zero or negative servings")
    func ignoresInvalidServings() {
        let recipe = Fixtures.recipe("A", ingredients: [Fixtures.ingredient("Rice", 100, .gram)])
        let list = aggregator.aggregate(
            planID: UUID(),
            entries: [ShoppingIngredientInput(recipe: recipe, servings: 0)]
        )
        #expect(list.items.isEmpty)
    }
}
