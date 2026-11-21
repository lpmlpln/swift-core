import Foundation

public struct SyncCursor: Codable, Hashable, Sendable {
    public var value: String
    public var serverTime: Date

    public init(value: String, serverTime: Date = Date()) {
        self.value = value
        self.serverTime = serverTime
    }
}

public struct SyncPlanPayload: Codable, Hashable, Sendable {
    public var planID: UUID
    public var schemaVersion: Int
    public var state: PlanDocument
    public var revoked: Bool

    public init(planID: UUID, schemaVersion: Int = 1, state: PlanDocument, revoked: Bool = false) {
        self.planID = planID
        self.schemaVersion = schemaVersion
        self.state = state
        self.revoked = revoked
    }
}

public struct SyncShoppingPayload: Codable, Hashable, Sendable {
    public var planID: UUID
    public var schemaVersion: Int
    public var state: ShoppingListDocument
    public var revoked: Bool

    public init(planID: UUID, schemaVersion: Int = 1, state: ShoppingListDocument, revoked: Bool = false) {
        self.planID = planID
        self.schemaVersion = schemaVersion
        self.state = state
        self.revoked = revoked
    }
}

public struct SyncRecipePayload: Codable, Hashable, Sendable {
    public var recipe: RecipeDTO
    public var deleted: Bool

    public init(recipe: RecipeDTO, deleted: Bool = false) {
        self.recipe = recipe
        self.deleted = deleted
    }
}

public struct SyncFriendPayload: Codable, Hashable, Sendable {
    public var friend: FriendDTO
    public var deleted: Bool

    public init(friend: FriendDTO, deleted: Bool = false) {
        self.friend = friend
        self.deleted = deleted
    }
}

public struct SyncPullResponse: Codable, Hashable, Sendable {
    public var recipes: [SyncRecipePayload]
    public var plans: [SyncPlanPayload]
    public var shoppingLists: [SyncShoppingPayload]
    public var friends: [SyncFriendPayload]
    public var cursor: SyncCursor
    public var serverTime: Date

    public init(
        recipes: [SyncRecipePayload] = [],
        plans: [SyncPlanPayload] = [],
        shoppingLists: [SyncShoppingPayload] = [],
        friends: [SyncFriendPayload] = [],
        cursor: SyncCursor,
        serverTime: Date = Date()
    ) {
        self.recipes = recipes
        self.plans = plans
        self.shoppingLists = shoppingLists
        self.friends = friends
        self.cursor = cursor
        self.serverTime = serverTime
    }
}

public struct SyncPushRequest: Codable, Hashable, Sendable {
    public var deviceID: UUID
    public var plans: [SyncPlanPayload]
    public var shoppingLists: [SyncShoppingPayload]

    public init(deviceID: UUID, plans: [SyncPlanPayload] = [], shoppingLists: [SyncShoppingPayload] = []) {
        self.deviceID = deviceID
        self.plans = plans
        self.shoppingLists = shoppingLists
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = try container.decode(UUID.self, forKey: .deviceID)
        plans = try container.decodeIfPresent([SyncPlanPayload].self, forKey: .plans) ?? []
        shoppingLists = try container.decodeIfPresent([SyncShoppingPayload].self, forKey: .shoppingLists) ?? []
    }
}

public struct SyncRejection: Codable, Hashable, Sendable {
    public var planID: UUID
    public var code: APIErrorCode
    public var message: String

    public init(planID: UUID, code: APIErrorCode, message: String) {
        self.planID = planID
        self.code = code
        self.message = message
    }
}

public struct SyncWarning: Codable, Hashable, Sendable {
    public var planID: UUID
    public var entryKey: String?
    public var recipeID: UUID?
    public var message: String

    public init(planID: UUID, entryKey: String? = nil, recipeID: UUID? = nil, message: String) {
        self.planID = planID
        self.entryKey = entryKey
        self.recipeID = recipeID
        self.message = message
    }
}

public struct SyncPushResponse: Codable, Hashable, Sendable {
    public var plans: [SyncPlanPayload]
    public var shoppingLists: [SyncShoppingPayload]
    public var rejections: [SyncRejection]
    public var warnings: [SyncWarning]
    public var cursor: SyncCursor

    public init(
        plans: [SyncPlanPayload] = [],
        shoppingLists: [SyncShoppingPayload] = [],
        rejections: [SyncRejection] = [],
        warnings: [SyncWarning] = [],
        cursor: SyncCursor
    ) {
        self.plans = plans
        self.shoppingLists = shoppingLists
        self.rejections = rejections
        self.warnings = warnings
        self.cursor = cursor
    }
}
