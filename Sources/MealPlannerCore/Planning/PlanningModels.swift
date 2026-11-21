import Foundation

public struct PlanningCandidate: Identifiable, Hashable, Sendable {
    public var recipe: Recipe
    public var isFavorite: Bool
    public var lastUsedDate: CalendarDate?

    public var id: UUID { recipe.id }

    public init(recipe: Recipe, isFavorite: Bool = false, lastUsedDate: CalendarDate? = nil) {
        self.recipe = recipe
        self.isFavorite = isFavorite
        self.lastUsedDate = lastUsedDate
    }
}

public struct PlanGenerationRequest: Sendable {
    public var planID: UUID
    public var startDate: CalendarDate
    public var dayCount: Int
    public var slots: [MealSlot]
    public var rules: PlanRules
    public var candidates: [PlanningCandidate]
    public var lockedEntries: [PlanEntryKey: PlanEntry]
    public var seed: UInt64

    public init(
        planID: UUID = UUID(),
        startDate: CalendarDate,
        dayCount: Int,
        slots: [MealSlot],
        rules: PlanRules,
        candidates: [PlanningCandidate],
        lockedEntries: [PlanEntryKey: PlanEntry] = [:],
        seed: UInt64 = 0
    ) {
        self.planID = planID
        self.startDate = startDate
        self.dayCount = dayCount
        self.slots = slots
        self.rules = rules
        self.candidates = candidates
        self.lockedEntries = lockedEntries
        self.seed = seed
    }
}

public struct PlanWarning: Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case batchBrokenByLockedEntry
        case lockedEntryConflictsWithRules
        case unknownCookTime
        case recipeUnavailable
        case batchShorterThanRequested
    }

    public var kind: Kind
    public var message: String
    public var entryKey: PlanEntryKey?

    public init(kind: Kind, message: String, entryKey: PlanEntryKey? = nil) {
        self.kind = kind
        self.message = message
        self.entryKey = entryKey
    }
}

public struct PlanGenerationFailure: Hashable, Codable, Sendable {
    public enum Code: String, Codable, Sendable {
        case invalidInput
        case noCandidates
        case unsatisfiable
    }

    public var code: Code
    public var message: String
    public var reasons: [String]

    public init(code: Code, message: String, reasons: [String] = []) {
        self.code = code
        self.message = message
        self.reasons = reasons
    }
}

public struct PlanGenerationResult: Sendable {
    public var entries: [PlanEntry]
    public var warnings: [PlanWarning]
    public var failure: PlanGenerationFailure?

    public init(
        entries: [PlanEntry] = [],
        warnings: [PlanWarning] = [],
        failure: PlanGenerationFailure? = nil
    ) {
        self.entries = entries
        self.warnings = warnings
        self.failure = failure
    }

    public var isSuccess: Bool { failure == nil }
}
