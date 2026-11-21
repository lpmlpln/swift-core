import Foundation

public struct ShoppingItemState: Hashable, Codable, Sendable {
    public var name: LWWRegister<String>
    public var quantity: LWWRegister<Decimal?>
    public var unit: LWWRegister<MeasurementUnit?>
    public var note: LWWRegister<String?>
    public var category: LWWRegister<IngredientCategory>
    public var checked: LWWRegister<Bool>
    public var deleted: LWWRegister<Bool>

    public init(
        name: LWWRegister<String>,
        quantity: LWWRegister<Decimal?>,
        unit: LWWRegister<MeasurementUnit?>,
        note: LWWRegister<String?>,
        category: LWWRegister<IngredientCategory>,
        checked: LWWRegister<Bool>,
        deleted: LWWRegister<Bool>
    ) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.note = note
        self.category = category
        self.checked = checked
        self.deleted = deleted
    }

    public init(item: ShoppingItem, clock: HLC) {
        self.init(
            name: LWWRegister(value: item.name, clock: clock),
            quantity: LWWRegister(value: item.quantity, clock: clock),
            unit: LWWRegister(value: item.unit, clock: clock),
            note: LWWRegister(value: item.note, clock: clock),
            category: LWWRegister(value: item.category, clock: clock),
            checked: LWWRegister(value: item.isChecked, clock: clock),
            deleted: LWWRegister(value: false, clock: clock)
        )
    }

    public static func deleted(clock: HLC) -> ShoppingItemState {
        ShoppingItemState(
            name: LWWRegister(value: "", clock: clock),
            quantity: LWWRegister(value: nil, clock: clock),
            unit: LWWRegister(value: nil, clock: clock),
            note: LWWRegister(value: nil, clock: clock),
            category: LWWRegister(value: .other, clock: clock),
            checked: LWWRegister(value: false, clock: clock),
            deleted: LWWRegister(value: true, clock: clock)
        )
    }

    public func merged(with other: ShoppingItemState) -> ShoppingItemState {
        ShoppingItemState(
            name: name.merged(with: other.name),
            quantity: quantity.merged(with: other.quantity),
            unit: unit.merged(with: other.unit),
            note: note.merged(with: other.note),
            category: category.merged(with: other.category),
            checked: checked.merged(with: other.checked),
            deleted: deleted.merged(with: other.deleted)
        )
    }

    public func materialize(key: String) -> ShoppingItem? {
        guard !deleted.value else { return nil }
        return ShoppingItem(
            key: key,
            name: name.value,
            quantity: quantity.value,
            unit: unit.value,
            note: note.value,
            category: category.value,
            isChecked: checked.value
        )
    }
}

public struct ShoppingListDocument: Hashable, Codable, Sendable {
    public var schemaVersion: Int
    public var planID: UUID
    public var sourcePlanHash: LWWRegister<String>
    public var items: [String: ShoppingItemState]

    public init(
        schemaVersion: Int = 1,
        planID: UUID,
        sourcePlanHash: LWWRegister<String>,
        items: [String: ShoppingItemState] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.planID = planID
        self.sourcePlanHash = sourcePlanHash
        self.items = items
    }

    public init(list: ShoppingList, clock: HLC) {
        self.init(
            planID: list.planID,
            sourcePlanHash: LWWRegister(value: list.sourcePlanHash, clock: clock)
        )
        apply(list: list, clock: clock, replaceItems: true)
    }

    public func merged(with other: ShoppingListDocument) -> ShoppingListDocument {
        var mergedItems = items
        for (key, state) in other.items {
            if let existing = mergedItems[key] {
                mergedItems[key] = existing.merged(with: state)
            } else {
                mergedItems[key] = state
            }
        }
        return ShoppingListDocument(
            schemaVersion: max(schemaVersion, other.schemaVersion),
            planID: planID,
            sourcePlanHash: sourcePlanHash.merged(with: other.sourcePlanHash),
            items: mergedItems
        )
    }

    public mutating func apply(list: ShoppingList, clock: HLC, replaceItems: Bool = false) {
        sourcePlanHash = sourcePlanHash.updated(to: list.sourcePlanHash, at: clock)
        for item in list.items {
            items[item.key] = ShoppingItemState(item: item, clock: clock)
        }
        if replaceItems {
            let currentKeys = Set(list.items.map(\.key))
            for key in items.keys where !currentKeys.contains(key) {
                if items[key]?.deleted.value == false {
                    items[key] = .deleted(clock: clock)
                }
            }
        }
    }

    public mutating func setChecked(_ checked: Bool, itemKey: String, clock: HLC) {
        guard var state = items[itemKey] else { return }
        state.checked = state.checked.updated(to: checked, at: clock)
        items[itemKey] = state
    }

    public func materializedItems() -> [ShoppingItem] {
        items.compactMap { key, state in state.materialize(key: key) }
            .sorted { lhs, rhs in
                let lhsOrder = IngredientCategory.allCases.firstIndex(of: lhs.category) ?? 0
                let rhsOrder = IngredientCategory.allCases.firstIndex(of: rhs.category) ?? 0
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    public func materialize(now: Date = Date()) -> ShoppingList {
        ShoppingList(
            planID: planID,
            items: materializedItems(),
            generatedAt: now,
            sourcePlanHash: sourcePlanHash.value
        )
    }

    public var stateHash: String {
        StableHash.of(self)
    }
}
