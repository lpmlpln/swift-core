import Foundation

public struct PlanDTO: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var ownerID: UUID
    public var name: String
    public var startDate: CalendarDate
    public var dayCount: Int
    public var slots: [MealSlot]
    public var rules: PlanRules
    public var myRole: PlanRole
    public var members: [PlanMemberDTO]
    public var entries: [PlanEntryDTO]
    public var shoppingList: ShoppingListDTO?
    public var warnings: [String]
    public var updatedAt: Date

    public init(
        id: UUID,
        ownerID: UUID,
        name: String,
        startDate: CalendarDate,
        dayCount: Int,
        slots: [MealSlot],
        rules: PlanRules,
        myRole: PlanRole,
        members: [PlanMemberDTO] = [],
        entries: [PlanEntryDTO] = [],
        shoppingList: ShoppingListDTO? = nil,
        warnings: [String] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.startDate = startDate
        self.dayCount = dayCount
        self.slots = slots
        self.rules = rules
        self.myRole = myRole
        self.members = members
        self.entries = entries
        self.shoppingList = shoppingList
        self.warnings = warnings
        self.updatedAt = updatedAt
    }

    public var dates: [CalendarDate] {
        startDate.dates(count: dayCount)
    }

    public func entries(on date: CalendarDate) -> [PlanEntryDTO] {
        entries.filter { $0.date == date }
    }
}

public struct PlanEntryDTO: Codable, Hashable, Sendable, Identifiable {
    public var id: String { "\(date.isoString)|\(slot.rawValue)" }

    public var date: CalendarDate
    public var slot: MealSlot
    public var recipeID: UUID
    public var recipeTitle: String
    public var imageURL: URL?
    public var servings: Int
    public var isLocked: Bool
    public var isLeftover: Bool
    public var batchID: String?

    public init(
        date: CalendarDate,
        slot: MealSlot,
        recipeID: UUID,
        recipeTitle: String,
        imageURL: URL? = nil,
        servings: Int,
        isLocked: Bool = false,
        isLeftover: Bool = false,
        batchID: String? = nil
    ) {
        self.date = date
        self.slot = slot
        self.recipeID = recipeID
        self.recipeTitle = recipeTitle
        self.imageURL = imageURL
        self.servings = servings
        self.isLocked = isLocked
        self.isLeftover = isLeftover
        self.batchID = batchID
    }
}

public struct PlanMemberDTO: Codable, Hashable, Sendable {
    public var userID: UUID
    public var displayName: String
    public var email: String
    public var role: PlanRole
    public var joinedAt: Date

    public init(
        userID: UUID,
        displayName: String,
        email: String = "",
        role: PlanRole,
        joinedAt: Date = Date()
    ) {
        self.userID = userID
        self.displayName = displayName
        self.email = email
        self.role = role
        self.joinedAt = joinedAt
    }
}

public struct PlanCreateRequest: Codable, Hashable, Sendable {
    public var name: String
    public var startDate: CalendarDate
    public var dayCount: Int
    public var slots: [MealSlot]
    public var rules: PlanRules
    public var seed: UInt64?

    public init(
        name: String,
        startDate: CalendarDate,
        dayCount: Int,
        slots: [MealSlot] = [.dinner],
        rules: PlanRules = .default,
        seed: UInt64? = nil
    ) {
        self.name = name
        self.startDate = startDate
        self.dayCount = dayCount
        self.slots = slots
        self.rules = rules
        self.seed = seed
    }
}

public struct PlanUpdateRequest: Codable, Hashable, Sendable {
    public var name: String?
    public var startDate: CalendarDate?
    public var dayCount: Int?
    public var slots: [MealSlot]?
    public var rules: PlanRules?

    public init(
        name: String? = nil,
        startDate: CalendarDate? = nil,
        dayCount: Int? = nil,
        slots: [MealSlot]? = nil,
        rules: PlanRules? = nil
    ) {
        self.name = name
        self.startDate = startDate
        self.dayCount = dayCount
        self.slots = slots
        self.rules = rules
    }
}

public struct PlanEntryUpdateRequest: Codable, Hashable, Sendable {
    public var recipeID: UUID
    public var servings: Int?
    public var lock: Bool?
    public var applyToBatch: Bool?

    public init(recipeID: UUID, servings: Int? = nil, lock: Bool? = nil, applyToBatch: Bool? = nil) {
        self.recipeID = recipeID
        self.servings = servings
        self.lock = lock
        self.applyToBatch = applyToBatch
    }
}

public struct PlanMemberRequest: Codable, Hashable, Sendable {
    public var userID: UUID
    public var role: PlanRole

    public init(userID: UUID, role: PlanRole = .editor) {
        self.userID = userID
        self.role = role
    }
}

public struct RecalculateRequest: Codable, Hashable, Sendable {
    public var seed: UInt64?
    public init(seed: UInt64? = nil) { self.seed = seed }
}

// MARK: - Shopping

public struct ShoppingItemDTO: Codable, Hashable, Sendable, Identifiable {
    public var key: String
    public var name: String
    public var quantity: Decimal?
    public var unit: String?
    public var note: String?
    public var category: IngredientCategory
    public var isChecked: Bool

    public var id: String { key }

    public init(
        key: String,
        name: String,
        quantity: Decimal? = nil,
        unit: String? = nil,
        note: String? = nil,
        category: IngredientCategory = .other,
        isChecked: Bool = false
    ) {
        self.key = key
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.note = note
        self.category = category
        self.isChecked = isChecked
    }
}

public struct ShoppingListDTO: Codable, Hashable, Sendable {
    public var planID: UUID
    public var items: [ShoppingItemDTO]
    public var isStale: Bool
    public var generatedAt: Date

    public init(planID: UUID, items: [ShoppingItemDTO], isStale: Bool = false, generatedAt: Date = Date()) {
        self.planID = planID
        self.items = items
        self.isStale = isStale
        self.generatedAt = generatedAt
    }
}

public struct ShoppingCheckRequest: Codable, Hashable, Sendable {
    public var itemKey: String
    public var isChecked: Bool

    public init(itemKey: String, isChecked: Bool) {
        self.itemKey = itemKey
        self.isChecked = isChecked
    }
}

// MARK: - Friends

public struct FriendDTO: Codable, Hashable, Sendable {
    public var userID: UUID
    public var displayName: String
    public var email: String
    public var status: FriendStatus
    public var requestedAt: Date

    public init(userID: UUID, displayName: String, email: String, status: FriendStatus, requestedAt: Date = Date()) {
        self.userID = userID
        self.displayName = displayName
        self.email = email
        self.status = status
        self.requestedAt = requestedAt
    }
}

public enum FriendStatus: String, Codable, Hashable, Sendable {
    case pendingOutgoing
    case pendingIncoming
    case accepted
}

public struct FriendRequest: Codable, Hashable, Sendable {
    public var email: String
    public init(email: String) { self.email = email }
}
