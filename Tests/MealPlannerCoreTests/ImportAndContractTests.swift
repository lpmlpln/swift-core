import Testing
import Foundation
@testable import MealPlannerCore

@Suite("URL normalization and import validation")
struct ImportTests {
    @Test("Normalizes equivalent URLs")
    func normalization() {
        let a = URLNormalizer.normalize("https://www.Example.com/recipes/pasta/?utm_source=news&utm_medium=email")
        let b = URLNormalizer.normalize("http://example.com/recipes/pasta")
        #expect(a != nil)
        #expect(a == b)
    }

    @Test("Drops fragments and default ports")
    func fragments() {
        #expect(
            URLNormalizer.normalize("https://example.com:443/recipe#steps")
                == "https://example.com/recipe"
        )
    }

    @Test("Rejects non-http URLs")
    func rejectsInvalid() {
        #expect(URLNormalizer.normalize("ftp://example.com/recipe") == nil)
        #expect(URLNormalizer.normalize("javascript:alert(1)") == nil)
        #expect(URLNormalizer.normalize("") == nil)
        #expect(URLNormalizer.normalize("https://") == nil)
    }

    @Test("Sorts query parameters")
    func sortsQuery() {
        #expect(
            URLNormalizer.normalize("https://example.com/r?b=2&a=1")
                == "https://example.com/r?a=1&b=2"
        )
    }

    @Test("Validates a good draft")
    func validDraft() throws {
        let draft = ImportedRecipeDraft(
            title: "Pasta",
            servings: 2,
            ingredients: [ImportedIngredient(raw: "200 g spaghetti", name: "Spaghetti", quantity: 200, unit: "g")],
            instructions: ["Boil.", "Serve."],
            imageURLs: [URL(string: "https://example.com/a.jpg")!],
            sourceURL: URL(string: "https://example.com/pasta")!
        )

        let imported = try ImportValidator.validate(draft, ownerID: UUID())
        #expect(imported.recipe.title == "Pasta")
        #expect(imported.recipe.visibility == .public)
        #expect(imported.recipe.isImported)
        #expect(imported.recipe.ingredients.first?.unit == .gram)
        #expect(imported.recipe.images.count == 1)
        #expect(imported.warnings.isEmpty)
    }

    @Test("Rejects drafts without required fields")
    func invalidDrafts() {
        let base = ImportedRecipeDraft(
            title: "Pasta",
            ingredients: [ImportedIngredient(raw: "spaghetti", name: "Spaghetti")],
            instructions: ["Boil."],
            sourceURL: URL(string: "https://example.com/pasta")!
        )

        #expect(throws: ImportValidationError.missingTitle) {
            var draft = base
            draft.title = " "
            try ImportValidator.validate(draft, ownerID: nil)
        }

        #expect(throws: ImportValidationError.missingIngredients) {
            var draft = base
            draft.ingredients = []
            try ImportValidator.validate(draft, ownerID: nil)
        }

        #expect(throws: ImportValidationError.missingInstructions) {
            var draft = base
            draft.instructions = []
            try ImportValidator.validate(draft, ownerID: nil)
        }

        #expect(throws: ImportValidationError.missingSourceURL) {
            var draft = base
            draft.sourceURL = nil
            try ImportValidator.validate(draft, ownerID: nil)
        }
    }

    @Test("Caps the number of images")
    func imageCap() throws {
        let images = (0..<10).compactMap { URL(string: "https://example.com/\($0).jpg") }
        let draft = ImportedRecipeDraft(
            title: "Pasta",
            ingredients: [ImportedIngredient(raw: "spaghetti", name: "Spaghetti")],
            instructions: ["Boil."],
            imageURLs: images,
            sourceURL: URL(string: "https://example.com/pasta")!
        )
        let imported = try ImportValidator.validate(draft, ownerID: nil)
        #expect(imported.recipe.images.count == ImportValidator.maxImages)
        #expect(imported.warnings.count == 1)
    }

    @Test("Warns about unknown units")
    func unknownUnit() throws {
        let draft = ImportedRecipeDraft(
            title: "Pasta",
            ingredients: [ImportedIngredient(raw: "2 furlongs spaghetti", name: "Spaghetti", quantity: 2, unit: "furlong")],
            instructions: ["Boil."],
            sourceURL: URL(string: "https://example.com/pasta")!
        )
        let imported = try ImportValidator.validate(draft, ownerID: nil)
        #expect(imported.recipe.ingredients.first?.unit == nil)
        #expect(imported.warnings.count == 1)
    }
}

@Suite("DTO contracts")
struct ContractTests {
    @Test("Recipe DTO round trips through JSON")
    func recipeRoundTrip() throws {
        let dto = RecipeDTO(
            id: UUID(),
            ownerID: UUID(),
            title: "Soup",
            servings: 4,
            ingredients: [IngredientDTO(name: "Onion", quantity: 2, unit: "piece", category: .produce)],
            instructions: ["Chop.", "Simmer."],
            dietaryTags: ["vegan"],
            visibility: .public
        )
        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONDecoder().decode(RecipeDTO.self, from: data)
        #expect(decoded == dto)
        #expect(decoded.effective().ingredients.first?.unit == .piece)
    }

    @Test("Personalization overlays the canonical recipe")
    func personalization() {
        let dto = RecipeDTO(
            id: UUID(),
            ownerID: UUID(),
            title: "Soup",
            servings: 4,
            ingredients: [IngredientDTO(name: "Onion", quantity: 2, unit: "piece")],
            instructions: ["Chop."],
            visibility: .public,
            personalization: PersonalizationDTO(title: "My Soup", servings: 2)
        )
        let canonical = dto.canonical()
        let effective = dto.effective()
        #expect(canonical.title == "Soup")
        #expect(canonical.servings == 4)
        #expect(effective.title == "My Soup")
        #expect(effective.servings == 2)
    }

    @Test("Plan DTO maps to a domain plan")
    func planMapping() throws {
        let dto = PlanDTO(
            id: UUID(),
            ownerID: UUID(),
            name: "Week",
            startDate: Fixtures.date("2026-01-05"),
            dayCount: 2,
            slots: [.dinner],
            rules: .default,
            myRole: .owner,
            entries: [
                PlanEntryDTO(
                    date: Fixtures.date("2026-01-05"),
                    slot: .dinner,
                    recipeID: UUID(),
                    recipeTitle: "Soup",
                    servings: 2
                )
            ]
        )
        let plan = dto.domain()
        #expect(plan.entries.count == 1)
        #expect(plan.entries[0].key.date == Fixtures.date("2026-01-05"))
    }

    @Test("Sync payloads round trip")
    func syncRoundTrip() throws {
        let plan = Plan(
            ownerID: UUID(),
            name: "Week",
            startDate: Fixtures.date("2026-01-05"),
            dayCount: 1,
            slots: [.dinner],
            rules: .default,
            entries: [
                PlanEntry(key: PlanEntryKey(date: Fixtures.date("2026-01-05"), slot: .dinner), recipeID: UUID(), servings: 2)
            ]
        )
        let clock = HLC(wallTimeMillis: 1, counter: 0, nodeID: UUID())
        let document = PlanDocument(plan: plan, clock: clock)
        let request = SyncPushRequest(
            deviceID: UUID(),
            plans: [SyncPlanPayload(planID: plan.id, state: document)]
        )
        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(SyncPushRequest.self, from: data)
        #expect(decoded.plans.first?.state == document)
    }

    @Test("Error bodies use stable codes")
    func errorCodes() throws {
        let body = APIErrorBody(code: .planAccessRevoked, message: "No access")
        let data = try JSONEncoder().encode(body)
        let decoded = try JSONDecoder().decode(APIErrorBody.self, from: data)
        #expect(decoded.error.code == "PLAN_ACCESS_REVOKED")
    }
}
