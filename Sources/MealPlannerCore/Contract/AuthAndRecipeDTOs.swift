import Foundation

// MARK: - Auth

public struct MagicLinkRequest: Codable, Hashable, Sendable {
    public var email: String
    public init(email: String) { self.email = email }
}

public struct MagicLinkResponse: Codable, Hashable, Sendable {
    public var status: String
    public init(status: String = "sent") { self.status = status }
}

public struct AppleSignInRequest: Codable, Hashable, Sendable {
    public var identityToken: String
    public var authorizationCode: String?
    public var nonce: String
    public var displayName: String?

    public init(identityToken: String, authorizationCode: String? = nil, nonce: String, displayName: String? = nil) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.nonce = nonce
        self.displayName = displayName
    }
}

public struct RefreshRequest: Codable, Hashable, Sendable {
    public var refreshToken: String
    public init(refreshToken: String) { self.refreshToken = refreshToken }
}

public struct TokenPair: Codable, Hashable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresInSeconds: Int
    public var user: UserDTO

    public init(accessToken: String, refreshToken: String, expiresInSeconds: Int, user: UserDTO) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresInSeconds = expiresInSeconds
        self.user = user
    }
}

public struct UserDTO: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var email: String
    public var displayName: String
    public var isAdmin: Bool
    public var measurementSystem: MeasurementSystem
    public var createdAt: Date

    public init(
        id: UUID,
        email: String,
        displayName: String,
        isAdmin: Bool = false,
        measurementSystem: MeasurementSystem = .metric,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.isAdmin = isAdmin
        self.measurementSystem = measurementSystem
        self.createdAt = createdAt
    }
}

public enum MeasurementSystem: String, Codable, Hashable, Sendable {
    case metric
    case imperial
}

public struct DeviceRegistration: Codable, Hashable, Sendable {
    public var deviceID: UUID
    public var name: String
    public var platform: String

    public init(deviceID: UUID, name: String, platform: String = "ios") {
        self.deviceID = deviceID
        self.name = name
        self.platform = platform
    }
}

// MARK: - Recipes

public struct RecipeDTO: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var ownerID: UUID?
    public var title: String
    public var description: String?
    public var servings: Int
    public var prepMinutes: Int?
    public var cookMinutes: Int?
    public var ingredients: [IngredientDTO]
    public var instructions: [String]
    public var cuisine: String?
    public var dishType: String?
    public var mainIngredient: String?
    public var dietaryTags: [String]
    public var images: [RecipeImageDTO]
    public var visibility: RecipeVisibility
    public var isImported: Bool
    public var sourceURL: URL?
    public var isFavorite: Bool
    public var isBlocked: Bool
    public var isOwner: Bool
    public var personalization: PersonalizationDTO?
    public var updatedAt: Date

    public init(
        id: UUID,
        ownerID: UUID?,
        title: String,
        description: String? = nil,
        servings: Int,
        prepMinutes: Int? = nil,
        cookMinutes: Int? = nil,
        ingredients: [IngredientDTO],
        instructions: [String],
        cuisine: String? = nil,
        dishType: String? = nil,
        mainIngredient: String? = nil,
        dietaryTags: [String] = [],
        images: [RecipeImageDTO] = [],
        visibility: RecipeVisibility,
        isImported: Bool = false,
        sourceURL: URL? = nil,
        isFavorite: Bool = false,
        isBlocked: Bool = false,
        isOwner: Bool = false,
        personalization: PersonalizationDTO? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.description = description
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.ingredients = ingredients
        self.instructions = instructions
        self.cuisine = cuisine
        self.dishType = dishType
        self.mainIngredient = mainIngredient
        self.dietaryTags = dietaryTags
        self.images = images
        self.visibility = visibility
        self.isImported = isImported
        self.sourceURL = sourceURL
        self.isFavorite = isFavorite
        self.isBlocked = isBlocked
        self.isOwner = isOwner
        self.personalization = personalization
        self.updatedAt = updatedAt
    }
}

public struct IngredientDTO: Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var quantity: Decimal?
    public var unit: String?
    public var note: String?
    public var category: IngredientCategory

    public init(
        id: UUID = UUID(),
        name: String,
        quantity: Decimal? = nil,
        unit: String? = nil,
        note: String? = nil,
        category: IngredientCategory = .other
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.note = note
        self.category = category
    }
}

public struct RecipeImageDTO: Codable, Hashable, Sendable {
    public var id: UUID
    public var url: URL
    public var sortOrder: Int

    public init(id: UUID = UUID(), url: URL, sortOrder: Int = 0) {
        self.id = id
        self.url = url
        self.sortOrder = sortOrder
    }
}

public struct PersonalizationDTO: Codable, Hashable, Sendable {
    public var title: String?
    public var servings: Int?
    public var instructions: [String]?
    public var ingredients: [IngredientDTO]?
    public var notes: String?
    public var updatedAt: Date?

    public init(
        title: String? = nil,
        servings: Int? = nil,
        instructions: [String]? = nil,
        ingredients: [IngredientDTO]? = nil,
        notes: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.title = title
        self.servings = servings
        self.instructions = instructions
        self.ingredients = ingredients
        self.notes = notes
        self.updatedAt = updatedAt
    }
}

public struct RecipeCreateRequest: Codable, Hashable, Sendable {
    public var title: String
    public var description: String?
    public var servings: Int
    public var prepMinutes: Int?
    public var cookMinutes: Int?
    public var ingredients: [IngredientDTO]
    public var instructions: [String]
    public var cuisine: String?
    public var dishType: String?
    public var mainIngredient: String?
    public var dietaryTags: [String]
    public var visibility: RecipeVisibility

    public init(
        title: String,
        description: String? = nil,
        servings: Int,
        prepMinutes: Int? = nil,
        cookMinutes: Int? = nil,
        ingredients: [IngredientDTO],
        instructions: [String],
        cuisine: String? = nil,
        dishType: String? = nil,
        mainIngredient: String? = nil,
        dietaryTags: [String] = [],
        visibility: RecipeVisibility = .private
    ) {
        self.title = title
        self.description = description
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.ingredients = ingredients
        self.instructions = instructions
        self.cuisine = cuisine
        self.dishType = dishType
        self.mainIngredient = mainIngredient
        self.dietaryTags = dietaryTags
        self.visibility = visibility
    }
}

public struct RecipeImportRequest: Codable, Hashable, Sendable {
    public var url: String
    public init(url: String) { self.url = url }
}

public struct RecipeImportResponse: Codable, Hashable, Sendable {
    public var jobID: UUID
    public var status: ImportJobStatus
    public var existingRecipeID: UUID?

    public init(jobID: UUID, status: ImportJobStatus, existingRecipeID: UUID? = nil) {
        self.jobID = jobID
        self.status = status
        self.existingRecipeID = existingRecipeID
    }
}

public enum ImportJobStatus: String, Codable, Hashable, Sendable {
    case queued
    case fetching
    case extracting
    case storingImages
    case succeeded
    case failed
    case duplicate
}

public struct ImportJobDTO: Codable, Hashable, Sendable {
    public var id: UUID
    public var status: ImportJobStatus
    public var sourceURL: URL
    public var recipeID: UUID?
    public var errorCode: String?
    public var errorMessage: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        status: ImportJobStatus,
        sourceURL: URL,
        recipeID: UUID? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.status = status
        self.sourceURL = sourceURL
        self.recipeID = recipeID
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Pagination

public struct PageDTO<Item: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    public var items: [Item]
    public var nextCursor: String?

    public init(items: [Item], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}
