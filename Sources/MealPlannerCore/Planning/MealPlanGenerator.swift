import Foundation

/// Generates a plan from accessible recipes and user rules.
///
/// The generator is deterministic for a given request and seed. It is used by
/// both the backend and the iOS app so online and offline plans are identical.
public struct MealPlanGenerator: Sendable {
    private let nodeLimit: Int

    public init(nodeLimit: Int = 100_000) {
        self.nodeLimit = nodeLimit
    }

    public func generate(_ request: PlanGenerationRequest) -> PlanGenerationResult {
        guard request.dayCount > 0, !request.slots.isEmpty else {
            return PlanGenerationResult(
                failure: PlanGenerationFailure(
                    code: .invalidInput,
                    message: "A plan needs at least one day and one meal slot."
                )
            )
        }

        let slots = Array(Set(request.slots)).sorted { lhs, rhs in
            (MealSlot.allCases.firstIndex(of: lhs) ?? 0) < (MealSlot.allCases.firstIndex(of: rhs) ?? 0)
        }

        guard !request.candidates.isEmpty else {
            return PlanGenerationResult(
                failure: PlanGenerationFailure(
                    code: .noCandidates,
                    message: "There are no recipes available for this plan.",
                    reasons: ["Add recipes or unblock recipes before generating a plan."]
                )
            )
        }

        let dates = request.startDate.dates(count: request.dayCount)
        let candidatesByID = Dictionary(uniqueKeysWithValues: request.candidates.map { ($0.recipe.id, $0) })
        var warnings: [PlanWarning] = []

        let units = makeUnits(
            dates: dates,
            slots: slots,
            lockedEntries: request.lockedEntries
        )
        let batches = makeBatches(
            units: units,
            rules: request.rules,
            candidatesByID: candidatesByID,
            warnings: &warnings
        )

        let candidatePool = request.candidates.filter { candidate in
            dates.contains { date in
                request.rules.allows(candidate.recipe, on: date)
            }
        }

        if candidatePool.isEmpty {
            return PlanGenerationResult(
                warnings: warnings,
                failure: PlanGenerationFailure(
                    code: .noCandidates,
                    message: "No recipe matches the selected dietary or cooking-time rules.",
                    reasons: ["Relax the dietary or cook-time rules, or add compatible recipes."]
                )
            )
        }

        var solver = Solver(
            batches: batches,
            candidates: candidatePool,
            rules: request.rules,
            startDate: request.startDate,
            nodeLimit: nodeLimit,
            seed: request.seed
        )

        guard let assigned = solver.solve() else {
            return PlanGenerationResult(
                warnings: warnings,
                failure: PlanGenerationFailure(
                    code: .unsatisfiable,
                    message: "No plan satisfies the selected rules.",
                    reasons: solver.failureReasons()
                )
            )
        }

        warnings.append(contentsOf: solver.warnings)
        let entries = assigned
            .flatMap { makeEntries(for: $0, rules: request.rules) }
            .sorted { lhs, rhs in
                if lhs.key.date != rhs.key.date {
                    return lhs.key.date < rhs.key.date
                }
                return (MealSlot.allCases.firstIndex(of: lhs.key.slot) ?? 0)
                    < (MealSlot.allCases.firstIndex(of: rhs.key.slot) ?? 0)
            }

        return PlanGenerationResult(entries: entries, warnings: warnings)
    }

    private func makeUnits(
        dates: [CalendarDate],
        slots: [MealSlot],
        lockedEntries: [PlanEntryKey: PlanEntry]
    ) -> [PlanningUnit] {
        dates.flatMap { date in
            slots.map { slot in
                let key = PlanEntryKey(date: date, slot: slot)
                return PlanningUnit(
                    key: key,
                    lockedEntry: lockedEntries[key]
                )
            }
        }
    }

    private func makeBatches(
        units: [PlanningUnit],
        rules: PlanRules,
        candidatesByID: [UUID: PlanningCandidate],
        warnings: inout [PlanWarning]
    ) -> [Batch] {
        var batches: [Batch] = []
        var batchIndex = 0

        for slot in Array(Set(units.map(\.key.slot))).sorted(by: slotOrder) {
            let slotUnits = units
                .filter { $0.key.slot == slot }
                .sorted { $0.key.date < $1.key.date }
            let batchDays = rules.batchCooking?.days ?? 1
            let appliesToSlot = rules.batchCooking?.slots.contains(slot) ?? false
            let groupSize = appliesToSlot ? max(2, batchDays) : 1

            var pending: [PlanningUnit] = []

            func flushPending() {
                guard !pending.isEmpty else { return }
                let firstDate = pending[0].key.date
                let id = "batch-\(slot.rawValue)-\(firstDate.isoString)-\(batchIndex)"
                batchIndex += 1
                batches.append(
                    Batch(
                        id: id,
                        units: pending,
                        fixedRecipe: nil,
                        lockedEntry: nil,
                        slot: slot
                    )
                )
                pending = []
            }

            for unit in slotUnits {
                if let locked = unit.lockedEntry {
                    if appliesToSlot && !pending.isEmpty {
                        warnings.append(
                            PlanWarning(
                                kind: .batchBrokenByLockedEntry,
                                message: "A locked meal on \(unit.key.date.isoString) splits a batch.",
                                entryKey: unit.key
                            )
                        )
                    }
                    flushPending()
                    let recipe = candidatesByID[locked.recipeID]?.recipe
                    let id = "batch-\(slot.rawValue)-\(unit.key.date.isoString)-\(batchIndex)"
                    batchIndex += 1
                    batches.append(
                        Batch(
                            id: id,
                            units: [unit],
                            fixedRecipe: recipe,
                            lockedEntry: locked,
                            slot: slot
                        )
                    )
                } else {
                    pending.append(unit)
                    if pending.count == groupSize {
                        flushPending()
                    }
                }
            }

            if !pending.isEmpty {
                if appliesToSlot && pending.count < groupSize {
                    warnings.append(
                        PlanWarning(
                            kind: .batchShorterThanRequested,
                            message: "The last batch for \(slot.displayName) is shorter than \(groupSize) days."
                        )
                    )
                }
                flushPending()
            }
        }

        return batches
    }

    private func slotOrder(_ lhs: MealSlot, _ rhs: MealSlot) -> Bool {
        (MealSlot.allCases.firstIndex(of: lhs) ?? 0) < (MealSlot.allCases.firstIndex(of: rhs) ?? 0)
    }

    private func makeEntries(for assigned: AssignedBatch, rules: PlanRules) -> [PlanEntry] {
        assigned.batch.units.enumerated().map { index, unit in
            let servings: Int
            if let locked = unit.lockedEntry {
                servings = locked.servings
            } else if let recipe = assigned.recipe {
                servings = rules.servings(for: unit.key.slot, recipe: recipe)
            } else {
                servings = 1
            }

            return PlanEntry(
                key: unit.key,
                recipeID: assigned.recipe?.id ?? unit.lockedEntry?.recipeID ?? UUID(),
                servings: servings,
                isLocked: unit.lockedEntry?.isLocked ?? false,
                isLeftover: index > 0,
                batchID: assigned.batch.id,
                recipeTitleSnapshot: assigned.recipe?.title ?? unit.lockedEntry?.recipeTitleSnapshot
            )
        }
    }
}

private struct PlanningUnit: Sendable {
    var key: PlanEntryKey
    var lockedEntry: PlanEntry?
}

private struct Batch: Sendable {
    var id: String
    var units: [PlanningUnit]
    var fixedRecipe: Recipe?
    var lockedEntry: PlanEntry?
    var slot: MealSlot

    var date: CalendarDate { units[0].key.date }

    var isLocked: Bool { lockedEntry != nil }
}

private struct AssignedBatch: Sendable {
    var batch: Batch
    var recipe: Recipe?
    var candidate: PlanningCandidate?
}

private struct Solver: Sendable {
    let batches: [Batch]
    let candidates: [PlanningCandidate]
    let rules: PlanRules
    let startDate: CalendarDate
    let nodeLimit: Int
    let seed: UInt64
    private(set) var warnings: [PlanWarning] = []

    private var nodesVisited = 0

    init(
        batches: [Batch],
        candidates: [PlanningCandidate],
        rules: PlanRules,
        startDate: CalendarDate,
        nodeLimit: Int,
        seed: UInt64
    ) {
        self.batches = batches
        self.candidates = candidates
        self.rules = rules
        self.startDate = startDate
        self.nodeLimit = nodeLimit
        self.seed = seed
    }

    mutating func solve() -> [AssignedBatch]? {
        var rng = SeededRandomNumberGenerator(seed: seed)
        let orderedBatches = batches.sorted { lhs, rhs in
            if lhs.isLocked != rhs.isLocked { return lhs.isLocked }
            let lhsCount = validCandidates(for: lhs, assigned: []).count
            let rhsCount = validCandidates(for: rhs, assigned: []).count
            if lhsCount != rhsCount { return lhsCount < rhsCount }
            return lhs.date < rhs.date
        }

        let result = search(index: 0, assigned: [], orderedBatches: orderedBatches, rng: &rng)
        if let result {
            for assigned in result where assigned.batch.isLocked {
                if assigned.recipe == nil {
                    warnings.append(
                        PlanWarning(
                            kind: .recipeUnavailable,
                            message: "A locked recipe is no longer available. Replace it to update the plan.",
                            entryKey: assigned.batch.units.first?.key
                        )
                    )
                    continue
                }
                let others = result.filter { $0.batch.id != assigned.batch.id }
                if let conflict = conflictMessage(for: assigned, assigned: others) {
                    warnings.append(
                        PlanWarning(
                            kind: .lockedEntryConflictsWithRules,
                            message: conflict,
                            entryKey: assigned.batch.units.first?.key
                        )
                    )
                }
            }
        }
        return result
    }

    func failureReasons() -> [String] {
        var reasons: [String] = []
        if nodesVisited >= nodeLimit {
            reasons.append("The planner reached its search limit. Try relaxing uniqueness or adding recipes.")
        }
        for batch in batches where !batch.isLocked {
            let count = validCandidates(for: batch, assigned: []).count
            if count == 0 {
                reasons.append("No recipe is available for \(batch.slot.displayName) on \(batch.date.isoString).")
            }
        }
        if reasons.isEmpty {
            reasons.append("Try relaxing uniqueness rules, reducing batch length, or adding more recipes.")
        }
        return reasons
    }

    private mutating func search(
        index: Int,
        assigned: [AssignedBatch],
        orderedBatches: [Batch],
        rng: inout SeededRandomNumberGenerator
    ) -> [AssignedBatch]? {
        if index == orderedBatches.count { return assigned }
        if nodesVisited >= nodeLimit { return nil }
        nodesVisited += 1

        let batch = orderedBatches[index]
        if batch.isLocked {
            let assignedBatch = AssignedBatch(
                batch: batch,
                recipe: batch.fixedRecipe,
                candidate: batch.fixedRecipe.flatMap { recipe in
                    candidates.first { $0.recipe.id == recipe.id }
                }
            )
            return search(
                index: index + 1,
                assigned: assigned + [assignedBatch],
                orderedBatches: orderedBatches,
                rng: &rng
            )
        }

        var options = validCandidates(for: batch, assigned: assigned)
        guard !options.isEmpty else { return nil }

        options.shuffle(using: &rng)
        let indexed = Array(options.enumerated()).sorted { lhs, rhs in
            let lhsScore = score(lhs.element, batch: batch)
            let rhsScore = score(rhs.element, batch: batch)
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            return lhs.offset < rhs.offset
        }

        for entry in indexed {
            let candidate = entry.element
            let assignedBatch = AssignedBatch(batch: batch, recipe: candidate.recipe, candidate: candidate)
            if let result = search(
                index: index + 1,
                assigned: assigned + [assignedBatch],
                orderedBatches: orderedBatches,
                rng: &rng
            ) {
                return result
            }
        }

        return nil
    }

    private func score(_ candidate: PlanningCandidate, batch: Batch) -> Double {
        var score = 0.0
        if candidate.isFavorite && rules.preferFavorites {
            score += 100
        }
        if let lastUsed = candidate.lastUsedDate {
            let days = abs(startDate.days(until: lastUsed))
            if days < 14 {
                score -= Double(14 - days) * 2
            }
        }
        if let total = candidate.recipe.totalMinutes {
            score -= Double(total) * 0.01
        }
        return score
    }

    private func validCandidates(for batch: Batch, assigned: [AssignedBatch]) -> [PlanningCandidate] {
        candidates.filter { candidate in
            guard batch.units.allSatisfy({ rules.allows(candidate.recipe, on: $0.key.date) }) else {
                return false
            }
            return conflictMessage(
                for: AssignedBatch(batch: batch, recipe: candidate.recipe, candidate: candidate),
                assigned: assigned
            ) == nil
        }
    }

    private func conflictMessage(for candidate: AssignedBatch, assigned: [AssignedBatch]) -> String? {
        guard let recipe = candidate.recipe else { return nil }
        for previous in assigned {
            guard let previousRecipe = previous.recipe else { continue }
            for rule in rules.uniqueness {
                if let window = rule.windowDays {
                    let distance = abs(candidate.batch.date.days(until: previous.batch.date))
                    if distance > window { continue }
                }
                switch rule.scope {
                case .recipe:
                    if recipe.id == previousRecipe.id {
                        return "\(recipe.title) repeats a recipe already used in this plan."
                    }
                case .dishType:
                    if let a = normalized(recipe.dishType), let b = normalized(previousRecipe.dishType), a == b {
                        return "\(recipe.title) repeats the dish type '\(a)'."
                    }
                case .cuisine:
                    if let a = normalized(recipe.cuisine), let b = normalized(previousRecipe.cuisine), a == b {
                        return "\(recipe.title) repeats the cuisine '\(a)'."
                    }
                case .mainIngredient:
                    if let a = normalized(recipe.mainIngredient), let b = normalized(previousRecipe.mainIngredient), a == b {
                        return "\(recipe.title) repeats the main ingredient '\(a)'."
                    }
                }
            }
        }
        return nil
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}
