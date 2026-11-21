import Foundation

public enum UniquenessScope: String, CaseIterable, Codable, Hashable, Sendable {
    case recipe
    case dishType
    case cuisine
    case mainIngredient
}

public struct UniquenessRule: Codable, Hashable, Sendable {
    public var scope: UniquenessScope
    /// nil means the whole plan; otherwise the constraint applies within this many days.
    public var windowDays: Int?

    public init(scope: UniquenessScope, windowDays: Int? = nil) {
        self.scope = scope
        self.windowDays = windowDays
    }
}

public struct BatchCookingRule: Codable, Hashable, Sendable {
    public var days: Int
    public var slots: Set<MealSlot>

    public init(days: Int, slots: Set<MealSlot> = [.dinner]) {
        self.days = max(2, days)
        self.slots = slots
    }
}

public struct CookTimeRule: Codable, Hashable, Sendable {
    public var weekdayMinutes: Int
    public var weekendMinutes: Int

    public init(weekdayMinutes: Int, weekendMinutes: Int) {
        self.weekdayMinutes = weekdayMinutes
        self.weekendMinutes = weekendMinutes
    }

    public func limit(for date: CalendarDate) -> Int {
        date.isWeekend ? weekendMinutes : weekdayMinutes
    }
}

public struct PlanRules: Codable, Hashable, Sendable {
    public var version: Int
    public var uniqueness: [UniquenessRule]
    public var batchCooking: BatchCookingRule?
    public var maxCookMinutes: CookTimeRule?
    public var requiredDietaryTags: Set<String>
    public var excludedDietaryTags: Set<String>
    public var preferFavorites: Bool
    public var servingsBySlot: [MealSlot: Int]

    public init(
        version: Int = 1,
        uniqueness: [UniquenessRule] = [],
        batchCooking: BatchCookingRule? = nil,
        maxCookMinutes: CookTimeRule? = nil,
        requiredDietaryTags: Set<String> = [],
        excludedDietaryTags: Set<String> = [],
        preferFavorites: Bool = true,
        servingsBySlot: [MealSlot: Int] = [:]
    ) {
        self.version = version
        self.uniqueness = uniqueness
        self.batchCooking = batchCooking
        self.maxCookMinutes = maxCookMinutes
        self.requiredDietaryTags = Set(requiredDietaryTags.map { $0.lowercased() })
        self.excludedDietaryTags = Set(excludedDietaryTags.map { $0.lowercased() })
        self.preferFavorites = preferFavorites
        self.servingsBySlot = servingsBySlot
    }

    public static let `default` = PlanRules()

    public static let everyMealUnique = PlanRules(
        uniqueness: [
            UniquenessRule(scope: .recipe),
            UniquenessRule(scope: .dishType),
            UniquenessRule(scope: .mainIngredient),
        ]
    )

    public func servings(for slot: MealSlot, recipe: Recipe) -> Int {
        servingsBySlot[slot] ?? recipe.servings
    }

    public func allows(_ recipe: Recipe, on date: CalendarDate) -> Bool {
        let required = Set(requiredDietaryTags.map { $0.lowercased() })
        let excluded = Set(excludedDietaryTags.map { $0.lowercased() })
        guard required.isSubset(of: recipe.dietaryTags) else { return false }
        guard excluded.isDisjoint(with: recipe.dietaryTags) else { return false }
        if let maxCookMinutes, let total = recipe.totalMinutes, total > maxCookMinutes.limit(for: date) {
            return false
        }
        return true
    }
}
