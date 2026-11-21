import Testing
import Foundation
@testable import MealPlannerCore

@Suite("Meal plan generator")
struct MealPlanGeneratorTests {
    let generator = MealPlanGenerator()

    func request(
        days: Int = 7,
        slots: [MealSlot] = [.dinner],
        rules: PlanRules = .default,
        candidates: [PlanningCandidate]? = nil,
        locked: [PlanEntryKey: PlanEntry] = [:],
        seed: UInt64 = 42
    ) -> PlanGenerationRequest {
        PlanGenerationRequest(
            startDate: Fixtures.date("2026-01-05"),
            dayCount: days,
            slots: slots,
            rules: rules,
            candidates: candidates ?? Fixtures.candidates(),
            lockedEntries: locked,
            seed: seed
        )
    }

    @Test("Generates one entry per day and slot")
    func entryCount() {
        let result = generator.generate(request(days: 5, slots: [.breakfast, .dinner]))
        #expect(result.isSuccess)
        #expect(result.entries.count == 10)
        #expect(Set(result.entries.map(\.key.date)).count == 5)
    }

    @Test("Is deterministic for the same seed")
    func determinism() {
        let candidates = Fixtures.candidates()
        let first = generator.generate(request(candidates: candidates, seed: 7))
        let second = generator.generate(request(candidates: candidates, seed: 7))
        #expect(first.entries.map(\.recipeID) == second.entries.map(\.recipeID))
    }

    @Test("Seeds vary the plan when candidates score equally")
    func seedVariation() {
        // Equal cook times and no favorites, so the seeded shuffle decides.
        let candidates = (0..<10).map { index in
            PlanningCandidate(recipe: Fixtures.recipe("Recipe \(index)", minutes: 30), isFavorite: false)
        }
        let rules = PlanRules(preferFavorites: false)
        let plans = (1...5).map { seed in
            generator.generate(request(rules: rules, candidates: candidates, seed: UInt64(seed)))
                .entries.map(\.recipeID)
        }
        #expect(Set(plans.map { $0.map(\.uuidString).joined() }).count > 1)
    }

    @Test("Fails when there are no candidates")
    func noCandidates() {
        let result = generator.generate(request(candidates: []))
        #expect(!result.isSuccess)
        #expect(result.failure?.code == .noCandidates)
    }

    @Test("Fails on invalid input")
    func invalidInput() {
        let result = generator.generate(request(days: 0))
        #expect(result.failure?.code == .invalidInput)
    }

    @Test("Keeps locked entries and their recipe")
    func lockedEntries() {
        let candidates = Fixtures.candidates()
        let key = PlanEntryKey(date: Fixtures.date("2026-01-07"), slot: .dinner)
        let locked = PlanEntry(
            key: key,
            recipeID: candidates[3].recipe.id,
            servings: 4,
            isLocked: true
        )

        let result = generator.generate(request(locked: [key: locked]))
        #expect(result.isSuccess)
        let entry = result.entries.first { $0.key == key }
        #expect(entry?.recipeID == candidates[3].recipe.id)
        #expect(entry?.isLocked == true)
        #expect(entry?.servings == 4)
    }

    @Test("Unique recipe rule prevents repeats")
    func uniqueRecipes() {
        let rules = PlanRules(uniqueness: [UniquenessRule(scope: .recipe)])
        let result = generator.generate(request(days: 6, rules: rules, candidates: Fixtures.candidates(count: 12)))
        #expect(result.isSuccess)
        let ids = result.entries.map(\.recipeID)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Unique recipe rule reports unsatisfiable plans")
    func unsatisfiable() {
        let rules = PlanRules(uniqueness: [UniquenessRule(scope: .recipe)])
        let result = generator.generate(request(days: 5, rules: rules, candidates: Fixtures.candidates(count: 3)))
        #expect(!result.isSuccess)
        #expect(result.failure?.code == .unsatisfiable)
        #expect(!(result.failure?.reasons.isEmpty ?? true))
    }

    @Test("Batch cooking reuses one recipe for consecutive days")
    func batchCooking() {
        let rules = PlanRules(batchCooking: BatchCookingRule(days: 3, slots: [.dinner]))
        let result = generator.generate(request(days: 3, rules: rules))
        #expect(result.isSuccess)

        let entries = result.entries.sorted { $0.key.date < $1.key.date }
        #expect(entries.count == 3)
        #expect(Set(entries.map(\.recipeID)).count == 1)
        #expect(entries[0].isLeftover == false)
        #expect(entries[1].isLeftover == true)
        #expect(entries[2].isLeftover == true)
        #expect(Set(entries.map(\.batchID)).count == 1)
    }

    @Test("Batch cooking creates multiple batches")
    func multipleBatches() {
        let rules = PlanRules(batchCooking: BatchCookingRule(days: 2, slots: [.dinner]))
        let result = generator.generate(request(days: 6, rules: rules))
        #expect(result.isSuccess)
        #expect(Set(result.entries.compactMap(\.batchID)).count == 3)
    }

    @Test("Locked entries split batches with a warning")
    func lockedSplitsBatch() {
        let candidates = Fixtures.candidates()
        let rules = PlanRules(batchCooking: BatchCookingRule(days: 3, slots: [.dinner]))
        let key = PlanEntryKey(date: Fixtures.date("2026-01-06"), slot: .dinner)
        let locked = PlanEntry(key: key, recipeID: candidates[2].recipe.id, servings: 2, isLocked: true)

        let result = generator.generate(request(days: 3, rules: rules, locked: [key: locked]))
        #expect(result.isSuccess)
        #expect(result.entries.contains { $0.key == key && $0.recipeID == candidates[2].recipe.id })
    }

    @Test("Excludes recipes violating dietary rules")
    func dietaryRules() {
        var vegan = Fixtures.recipe("Vegan Bowl", tags: ["vegan"])
        vegan.ingredients = [Fixtures.ingredient("Tofu", 200, .gram)]
        let meat = Fixtures.recipe("Steak", tags: ["meat"])

        let rules = PlanRules(requiredDietaryTags: ["vegan"])
        let result = generator.generate(
            request(days: 2, rules: rules, candidates: [
                PlanningCandidate(recipe: vegan),
                PlanningCandidate(recipe: meat),
            ])
        )
        #expect(result.isSuccess)
        #expect(result.entries.allSatisfy { $0.recipeID == vegan.id })
    }

    @Test("Excludes recipes with excluded tags")
    func excludedTags() {
        let rules = PlanRules(excludedDietaryTags: ["nuts"])
        let nutty = Fixtures.recipe("Nut Roast", tags: ["nuts"])
        let plain = Fixtures.recipe("Plain Rice")
        let result = generator.generate(
            request(days: 2, rules: rules, candidates: [
                PlanningCandidate(recipe: nutty),
                PlanningCandidate(recipe: plain),
            ])
        )
        #expect(result.entries.allSatisfy { $0.recipeID == plain.id })
    }

    @Test("Enforces weekday cook-time limits")
    func cookTimeLimit() {
        let slow = Fixtures.recipe("Slow Roast", minutes: 120)
        let quick = Fixtures.recipe("Quick Pasta", minutes: 20)
        let rules = PlanRules(maxCookMinutes: CookTimeRule(weekdayMinutes: 30, weekendMinutes: 180))
        // 2026-01-05 is a Monday.
        let result = generator.generate(
            request(days: 1, rules: rules, candidates: [
                PlanningCandidate(recipe: slow),
                PlanningCandidate(recipe: quick),
            ])
        )
        #expect(result.isSuccess)
        #expect(result.entries.first?.recipeID == quick.id)
    }

    @Test("Prefers favorites when scoring")
    func prefersFavorites() {
        let favorite = Fixtures.recipe("Favorite")
        let other = Fixtures.recipe("Other")
        let result = generator.generate(
            request(days: 1, rules: PlanRules(preferFavorites: true), candidates: [
                PlanningCandidate(recipe: other, isFavorite: false),
                PlanningCandidate(recipe: favorite, isFavorite: true),
            ])
        )
        #expect(result.entries.first?.recipeID == favorite.id)
    }

    @Test("Uses per-slot servings")
    func slotServings() {
        let recipe = Fixtures.recipe("Big Batch", servings: 2)
        let rules = PlanRules(servingsBySlot: [.dinner: 4])
        let result = generator.generate(
            request(days: 1, rules: rules, candidates: [PlanningCandidate(recipe: recipe)])
        )
        #expect(result.entries.first?.servings == 4)
    }

    @Test("Satisfies uniqueness invariants under random seeds")
    func uniquenessProperty() {
        let rules = PlanRules(uniqueness: [
            UniquenessRule(scope: .recipe),
            UniquenessRule(scope: .dishType),
        ])
        for seed in UInt64(0)..<20 {
            let result = generator.generate(
                request(days: 5, rules: rules, candidates: Fixtures.candidates(count: 24), seed: seed)
            )
            guard result.isSuccess else { continue }
            #expect(Set(result.entries.map(\.recipeID)).count == result.entries.count)
        }
    }
}
