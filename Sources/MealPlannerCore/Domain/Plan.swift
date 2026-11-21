import Foundation

public enum PlanRole: String, CaseIterable, Codable, Hashable, Sendable {
    case owner
    case editor
    case viewer

    public var canEdit: Bool { self == .owner || self == .editor }
    public var canManageMembers: Bool { self == .owner }
    public var canEditRules: Bool { self == .owner }
    public var canDelete: Bool { self == .owner }
}

public struct PlanEntryKey: Hashable, Codable, Sendable, CustomStringConvertible {
    public var date: CalendarDate
    public var slot: MealSlot

    public init(date: CalendarDate, slot: MealSlot) {
        self.date = date
        self.slot = slot
    }

    public init?(rawValue: String) {
        let parts = rawValue.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let date = CalendarDate(isoString: String(parts[0])),
              let slot = MealSlot(rawValue: String(parts[1]))
        else {
            return nil
        }
        self.date = date
        self.slot = slot
    }

    public var rawValue: String {
        "\(date.isoString)|\(slot.rawValue)"
    }

    public var description: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let key = PlanEntryKey(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a plan entry key in YYYY-MM-DD|slot format."
            )
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct PlanEntry: Identifiable, Hashable, Codable, Sendable {
    public var key: PlanEntryKey
    public var recipeID: UUID
    public var servings: Int
    public var isLocked: Bool
    public var isLeftover: Bool
    public var batchID: String?
    public var recipeTitleSnapshot: String?

    public var id: String { key.rawValue }

    public init(
        key: PlanEntryKey,
        recipeID: UUID,
        servings: Int,
        isLocked: Bool = false,
        isLeftover: Bool = false,
        batchID: String? = nil,
        recipeTitleSnapshot: String? = nil
    ) {
        self.key = key
        self.recipeID = recipeID
        self.servings = servings
        self.isLocked = isLocked
        self.isLeftover = isLeftover
        self.batchID = batchID
        self.recipeTitleSnapshot = recipeTitleSnapshot
    }
}

public struct Plan: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var ownerID: UUID
    public var name: String
    public var startDate: CalendarDate
    public var dayCount: Int
    public var slots: [MealSlot]
    public var rules: PlanRules
    public var entries: [PlanEntry]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        ownerID: UUID,
        name: String,
        startDate: CalendarDate,
        dayCount: Int,
        slots: [MealSlot],
        rules: PlanRules,
        entries: [PlanEntry] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.startDate = startDate
        self.dayCount = max(1, dayCount)
        self.slots = slots
        self.rules = rules
        self.entries = entries
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var dates: [CalendarDate] {
        startDate.dates(count: dayCount)
    }

    public func entry(for key: PlanEntryKey) -> PlanEntry? {
        entries.first { $0.key == key }
    }

    public func entries(on date: CalendarDate) -> [PlanEntry] {
        entries.filter { $0.key.date == date }
    }
}
