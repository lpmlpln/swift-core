import Foundation

/// Stable API error codes shared by the backend and the iOS client.
public enum APIErrorCode: String, Codable, Sendable, CaseIterable {
    case unauthorized = "UNAUTHORIZED"
    case forbidden = "FORBIDDEN"
    case notFound = "NOT_FOUND"
    case validation = "VALIDATION_FAILED"
    case conflict = "CONFLICT"
    case rateLimited = "RATE_LIMITED"
    case magicLinkExpired = "MAGIC_LINK_EXPIRED"
    case magicLinkUsed = "MAGIC_LINK_USED"
    case appleTokenInvalid = "APPLE_TOKEN_INVALID"
    case planRoleInsufficient = "PLAN_ROLE_INSUFFICIENT"
    case planAccessRevoked = "PLAN_ACCESS_REVOKED"
    case recipeUnavailable = "RECIPE_UNAVAILABLE"
    case importFailed = "IMPORT_FAILED"
    case importDuplicate = "IMPORT_DUPLICATE"
    case syncInvalidState = "SYNC_INVALID_STATE"
    case syncCursorStale = "SYNC_CURSOR_STALE"
    case serverError = "SERVER_ERROR"
    case network = "NETWORK_ERROR"
    case offline = "OFFLINE"
    case unknown = "UNKNOWN"
}

public struct APIErrorBody: Codable, Hashable, Sendable {
    public struct Payload: Codable, Hashable, Sendable {
        public var code: String
        public var message: String
        public var details: [String: String]?

        public init(code: String, message: String, details: [String: String]? = nil) {
            self.code = code
            self.message = message
            self.details = details
        }
    }

    public var error: Payload

    public init(error: Payload) {
        self.error = error
    }

    public init(code: APIErrorCode, message: String, details: [String: String]? = nil) {
        self.error = Payload(code: code.rawValue, message: message, details: details)
    }
}
