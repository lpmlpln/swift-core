import Foundation

public enum MealSlot: String, CaseIterable, Codable, Hashable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack

    public var displayName: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }
}
