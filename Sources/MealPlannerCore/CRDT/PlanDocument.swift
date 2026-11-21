import Foundation

public struct PlanMetadataState: Hashable, Codable, Sendable {
    public var name: LWWRegister<String>
    public var startDate: LWWRegister<CalendarDate>
    public var dayCount: LWWRegister<Int>
    public var slots: LWWRegister<[MealSlot]>
    public var rules: LWWRegister<PlanRules>
    public var deleted: LWWRegister<Bool>

    public init(
        name: LWWRegister<String>,
        startDate: LWWRegister<CalendarDate>,
        dayCount: LWWRegister<Int>,
        slots: LWWRegister<[MealSlot]>,
        rules: LWWRegister<PlanRules>,
        deleted: LWWRegister<Bool>
    ) {
        self.name = name
        self.startDate = startDate
        self.dayCount = dayCount
        self.slots = slots
        self.rules = rules
        self.deleted = deleted
    }

    public static func empty(clock: HLC) -> PlanMetadataState {
        PlanMetadataState(
            name: LWWRegister(value: "Meal plan", clock: clock),
            startDate: LWWRegister(value: .reference, clock: clock),
            dayCount: LWWRegister(value: 7, clock: clock),
            slots: LWWRegister(value: [.dinner], clock: clock),
            rules: LWWRegister(value: .default, clock: clock),
            deleted: LWWRegister(value: false, clock: clock)
        )
    }

    public func merged(with other: PlanMetadataState) -> PlanMetadataState {
        PlanMetadataState(
            name: name.merged(with: other.name),
            startDate: startDate.merged(with: other.startDate),
            dayCount: dayCount.merged(with: other.dayCount),
            slots: slots.merged(with: other.slots),
            rules: rules.merged(with: other.rules),
            deleted: deleted.merged(with: other.deleted)
        )
    }

    public mutating func apply(_ plan: Plan, clock: HLC) {
        name = name.updated(to: plan.name, at: clock)
        startDate = startDate.updated(to: plan.startDate, at: clock)
        dayCount = dayCount.updated(to: plan.dayCount, at: clock)
        slots = slots.updated(to: plan.slots, at: clock)
        rules = rules.updated(to: plan.rules, at: clock)
    }
}

public struct PlanEntryState: Hashable, Codable, Sendable {
    public var recipeId: LWWRegister<UUID?>
    public var servings: LWWRegister<Int>
    public var locked: LWWRegister<Bool>
    public var isLeftover: LWWRegister<Bool>
    public var batchId: LWWRegister<String?>
    public var recipeTitleSnapshot: LWWRegister<String?>
    public var deleted: LWWRegister<Bool>

    public init(
        recipeId: LWWRegister<UUID?>,
        servings: LWWRegister<Int>,
        locked: LWWRegister<Bool>,
        isLeftover: LWWRegister<Bool>,
        batchId: LWWRegister<String?>,
        recipeTitleSnapshot: LWWRegister<String?>,
        deleted: LWWRegister<Bool>
    ) {
        self.recipeId = recipeId
        self.servings = servings
        self.locked = locked
        self.isLeftover = isLeftover
        self.batchId = batchId
        self.recipeTitleSnapshot = recipeTitleSnapshot
        self.deleted = deleted
    }

    public init(entry: PlanEntry, clock: HLC) {
        self.init(
            recipeId: LWWRegister(value: entry.recipeID, clock: clock),
            servings: LWWRegister(value: entry.servings, clock: clock),
            locked: LWWRegister(value: entry.isLocked, clock: clock),
            isLeftover: LWWRegister(value: entry.isLeftover, clock: clock),
            batchId: LWWRegister(value: entry.batchID, clock: clock),
            recipeTitleSnapshot: LWWRegister(value: entry.recipeTitleSnapshot, clock: clock),
            deleted: LWWRegister(value: false, clock: clock)
        )
    }

    public static func deleted(clock: HLC) -> PlanEntryState {
        PlanEntryState(
            recipeId: LWWRegister(value: nil, clock: clock),
            servings: LWWRegister(value: 0, clock: clock),
            locked: LWWRegister(value: false, clock: clock),
            isLeftover: LWWRegister(value: false, clock: clock),
            batchId: LWWRegister(value: nil, clock: clock),
            recipeTitleSnapshot: LWWRegister(value: nil, clock: clock),
            deleted: LWWRegister(value: true, clock: clock)
        )
    }

    public func merged(with other: PlanEntryState) -> PlanEntryState {
        PlanEntryState(
            recipeId: recipeId.merged(with: other.recipeId),
            servings: servings.merged(with: other.servings),
            locked: locked.merged(with: other.locked),
            isLeftover: isLeftover.merged(with: other.isLeftover),
            batchId: batchId.merged(with: other.batchId),
            recipeTitleSnapshot: recipeTitleSnapshot.merged(with: other.recipeTitleSnapshot),
            deleted: deleted.merged(with: other.deleted)
        )
    }

    public var isVisible: Bool {
        !deleted.value && recipeId.value != nil
    }

    public func materialize(key: PlanEntryKey) -> PlanEntry? {
        guard isVisible, let recipeID = recipeId.value else { return nil }
        return PlanEntry(
            key: key,
            recipeID: recipeID,
            servings: servings.value,
            isLocked: locked.value,
            isLeftover: isLeftover.value,
            batchID: batchId.value,
            recipeTitleSnapshot: recipeTitleSnapshot.value
        )
    }
}

public struct PlanDocument: Hashable, Codable, Sendable {
    public var schemaVersion: Int
    public var planID: UUID
    public var metadata: PlanMetadataState
    public var entries: [String: PlanEntryState]

    public init(
        schemaVersion: Int = 1,
        planID: UUID,
        metadata: PlanMetadataState,
        entries: [String: PlanEntryState] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.planID = planID
        self.metadata = metadata
        self.entries = entries
    }

    public init(plan: Plan, clock: HLC) {
        self.init(
            planID: plan.id,
            metadata: PlanMetadataState.empty(clock: clock),
            entries: [:]
        )
        apply(plan: plan, clock: clock, replaceEntries: true)
    }

    public func merged(with other: PlanDocument) -> PlanDocument {
        var mergedEntries = entries
        for (key, state) in other.entries {
            if let existing = mergedEntries[key] {
                mergedEntries[key] = existing.merged(with: state)
            } else {
                mergedEntries[key] = state
            }
        }
        return PlanDocument(
            schemaVersion: max(schemaVersion, other.schemaVersion),
            planID: planID,
            metadata: metadata.merged(with: other.metadata),
            entries: mergedEntries
        )
    }

    public mutating func apply(plan: Plan, clock: HLC, replaceEntries: Bool = false) {
        metadata.apply(plan, clock: clock)
        for entry in plan.entries {
            apply(entry: entry, clock: clock)
        }
        if replaceEntries {
            let currentKeys = Set(plan.entries.map { $0.key.rawValue })
            for key in entries.keys where !currentKeys.contains(key) {
                if entries[key]?.deleted.value == false {
                    entries[key] = .deleted(clock: clock)
                }
            }
        }
    }

    public mutating func apply(entry: PlanEntry, clock: HLC) {
        guard var state = entries[entry.key.rawValue] else {
            entries[entry.key.rawValue] = PlanEntryState(entry: entry, clock: clock)
            return
        }

        // Only write registers whose value actually changed so concurrent edits
        // to different fields of the same meal both survive the merge.
        if state.recipeId.value != entry.recipeID {
            state.recipeId = state.recipeId.updated(to: entry.recipeID, at: clock)
        }
        if state.servings.value != entry.servings {
            state.servings = state.servings.updated(to: entry.servings, at: clock)
        }
        if state.locked.value != entry.isLocked {
            state.locked = state.locked.updated(to: entry.isLocked, at: clock)
        }
        if state.isLeftover.value != entry.isLeftover {
            state.isLeftover = state.isLeftover.updated(to: entry.isLeftover, at: clock)
        }
        if state.batchId.value != entry.batchID {
            state.batchId = state.batchId.updated(to: entry.batchID, at: clock)
        }
        if state.recipeTitleSnapshot.value != entry.recipeTitleSnapshot {
            state.recipeTitleSnapshot = state.recipeTitleSnapshot.updated(to: entry.recipeTitleSnapshot, at: clock)
        }
        if state.deleted.value {
            state.deleted = state.deleted.updated(to: false, at: clock)
        }
        entries[entry.key.rawValue] = state
    }

    public mutating func markDeleted(entryKey: PlanEntryKey, clock: HLC) {
        entries[entryKey.rawValue] = .deleted(clock: clock)
    }

    public mutating func setLocked(_ locked: Bool, entryKey: PlanEntryKey, clock: HLC) {
        guard var state = entries[entryKey.rawValue] else { return }
        state.locked = state.locked.updated(to: locked, at: clock)
        entries[entryKey.rawValue] = state
    }

    public mutating func setRecipe(
        _ recipeID: UUID,
        titleSnapshot: String?,
        servings: Int,
        entryKey: PlanEntryKey,
        clock: HLC
    ) {
        guard var state = entries[entryKey.rawValue] else { return }
        state.recipeId = state.recipeId.updated(to: recipeID, at: clock)
        state.recipeTitleSnapshot = state.recipeTitleSnapshot.updated(to: titleSnapshot, at: clock)
        state.servings = state.servings.updated(to: servings, at: clock)
        state.deleted = state.deleted.updated(to: false, at: clock)
        entries[entryKey.rawValue] = state
    }

    public func materializedEntries() -> [PlanEntry] {
        entries.compactMap { key, state in
            guard let entryKey = PlanEntryKey(rawValue: key) else { return nil }
            return state.materialize(key: entryKey)
        }
        .sorted { lhs, rhs in
            if lhs.key.date != rhs.key.date { return lhs.key.date < rhs.key.date }
            return (MealSlot.allCases.firstIndex(of: lhs.key.slot) ?? 0)
                < (MealSlot.allCases.firstIndex(of: rhs.key.slot) ?? 0)
        }
    }

    public func materialize(ownerID: UUID, now: Date = Date()) -> Plan {
        materialize(ownerID: ownerID, entries: materializedEntries(), now: now)
    }

    public func materialize(ownerID: UUID, entries: [PlanEntry], now: Date = Date()) -> Plan {
        Plan(
            id: planID,
            ownerID: ownerID,
            name: metadata.name.value,
            startDate: metadata.startDate.value,
            dayCount: metadata.dayCount.value,
            slots: metadata.slots.value,
            rules: metadata.rules.value,
            entries: entries,
            createdAt: now,
            updatedAt: now
        )
    }

    public var stateHash: String {
        StableHash.of(self)
    }
}
