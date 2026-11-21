import Testing
import Foundation
@testable import MealPlannerCore

@Suite("Plan and shopping CRDT documents")
struct CRDTDocumentTests {
    let ownerID = UUID()
    let nodeA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    let nodeB = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!

    func clock(_ millis: Int64, _ node: UUID) -> HLC {
        HLC(wallTimeMillis: millis, counter: 0, nodeID: node)
    }

    func samplePlan() -> Plan {
        let entries = (0..<3).map { index in
            PlanEntry(
                key: PlanEntryKey(date: Fixtures.date("2026-02-0\(index + 1)"), slot: .dinner),
                recipeID: UUID(),
                servings: 2,
                recipeTitleSnapshot: "Meal \(index)"
            )
        }
        return Plan(
            ownerID: ownerID,
            name: "Week",
            startDate: Fixtures.date("2026-02-01"),
            dayCount: 3,
            slots: [.dinner],
            rules: .default,
            entries: entries
        )
    }

    @Test("Materializes a plan document")
    func materialize() {
        let plan = samplePlan()
        let document = PlanDocument(plan: plan, clock: clock(1, nodeA))
        let result = document.materialize(ownerID: ownerID)
        #expect(result.name == plan.name)
        #expect(result.entries.count == 3)
        #expect(result.startDate == plan.startDate)
    }

    @Test("Merges different fields of the same entry")
    func fieldLevelMerge() throws {
        let plan = samplePlan()
        let entry = plan.entries[0]

        var left = PlanDocument(plan: plan, clock: clock(10, nodeA))
        var right = PlanDocument(plan: plan, clock: clock(10, nodeA))

        // A changes servings; B changes the lock. Both must survive.
        var changedServings = entry
        changedServings.servings = 6
        left.apply(entry: changedServings, clock: clock(20, nodeA))

        var changedLock = entry
        changedLock.isLocked = true
        right.apply(entry: changedLock, clock: clock(15, nodeB))

        let merged = left.merged(with: right)
        let state = try #require(merged.entries[entry.key.rawValue])
        #expect(state.servings.value == 6)
        #expect(state.locked.value == true)
    }

    @Test("Resolves same-field edits by clock")
    func sameFieldMerge() throws {
        let plan = samplePlan()
        let entry = plan.entries[0]

        var left = PlanDocument(plan: plan, clock: clock(10, nodeA))
        var right = PlanDocument(plan: plan, clock: clock(10, nodeA))

        var a = entry
        a.servings = 3
        left.apply(entry: a, clock: clock(20, nodeA))

        var b = entry
        b.servings = 9
        right.apply(entry: b, clock: clock(30, nodeB))

        let merged = left.merged(with: right)
        #expect(merged.entries[entry.key.rawValue]?.servings.value == 9)
    }

    @Test("Merge is commutative, associative and idempotent")
    func mergeLaws() {
        let plan = samplePlan()
        let base = PlanDocument(plan: plan, clock: clock(1, nodeA))

        var a = base
        a.metadata.name = a.metadata.name.updated(to: "A", at: clock(5, nodeA))
        var b = base
        b.metadata.name = b.metadata.name.updated(to: "B", at: clock(6, nodeB))
        var c = base
        c.metadata.dayCount = c.metadata.dayCount.updated(to: 10, at: clock(7, nodeA))

        #expect(a.merged(with: b) == b.merged(with: a))
        #expect(a.merged(with: a) == a)
        #expect(a.merged(with: b).merged(with: c) == a.merged(with: b.merged(with: c)))
    }

    @Test("Tombstones prevent resurrection")
    func tombstones() throws {
        let plan = samplePlan()
        let entry = plan.entries[0]
        let key = entry.key

        var left = PlanDocument(plan: plan, clock: clock(1, nodeA))
        var right = PlanDocument(plan: plan, clock: clock(1, nodeA))

        left.markDeleted(entryKey: key, clock: clock(50, nodeA))

        // Stale replica still has the old entry.
        right.apply(entry: entry, clock: clock(10, nodeB))

        let merged = left.merged(with: right)
        #expect(merged.entries[key.rawValue]?.deleted.value == true)
        #expect(merged.materializedEntries().contains { $0.key == key } == false)
    }

    @Test("Replicas converge regardless of merge order")
    func convergence() {
        let plan = samplePlan()
        var replicas = [0, 1, 2].map { _ in PlanDocument(plan: plan, clock: clock(1, nodeA)) }

        for (index, _) in replicas.enumerated() {
            var entry = plan.entries[index]
            entry.servings = index + 2
            replicas[index].apply(entry: entry, clock: clock(Int64(index + 10), nodeB))
        }

        let forward = replicas[0]
            .merged(with: replicas[1])
            .merged(with: replicas[2])
        let backward = replicas[2]
            .merged(with: replicas[1])
            .merged(with: replicas[0])

        #expect(forward == backward)
    }

    @Test("Shopping list preserves checked state across regeneration")
    func checkedState() {
        let list = ShoppingList(
            planID: UUID(),
            items: [
                ShoppingItem(key: "milk|volume", name: "Milk", quantity: 1, unit: .liter, category: .dairy, isChecked: false),
                ShoppingItem(key: "eggs|count|piece", name: "Eggs", quantity: 6, unit: .piece, category: .dairy, isChecked: false),
            ],
            sourcePlanHash: "v1"
        )

        var document = ShoppingListDocument(list: list, clock: clock(1, nodeA))
        document.setChecked(true, itemKey: "milk|volume", clock: clock(5, nodeA))

        // Regeneration updates the quantity but must keep the check-off.
        var regenerated = list
        regenerated.items[0].quantity = 2
        regenerated.sourcePlanHash = "v2"

        var regeneratedDocument = ShoppingListDocument(list: regenerated, clock: clock(10, nodeB))
        let checkedState = document.items["milk|volume"]!.checked
        regeneratedDocument.items["milk|volume"]!.checked = checkedState

        let merged = document.merged(with: regeneratedDocument)
        #expect(merged.items["milk|volume"]?.quantity.value == 2)
        #expect(merged.items["milk|volume"]?.checked.value == true)
    }

    @Test("Shopping list drops removed items via tombstones")
    func removedItems() {
        let list = ShoppingList(
            planID: UUID(),
            items: [ShoppingItem(key: "a", name: "Apple", category: .produce)],
            sourcePlanHash: "v1"
        )
        let document = ShoppingListDocument(list: list, clock: clock(1, nodeA))
        #expect(document.materializedItems().count == 1)

        var empty = ShoppingList(planID: list.planID, items: [], sourcePlanHash: "v2")
        empty.items = []
        var regenerated = document
        regenerated.apply(list: empty, clock: clock(2, nodeA), replaceItems: true)

        #expect(regenerated.materializedItems().isEmpty)
    }

    @Test("Documents round trip through JSON")
    func codable() throws {
        let plan = samplePlan()
        let document = PlanDocument(plan: plan, clock: clock(1, nodeA))
        let data = try JSONEncoder().encode(document)
        let decoded = try JSONDecoder().decode(PlanDocument.self, from: data)
        #expect(decoded == document)

        let list = ShoppingListDocument(
            planID: plan.id,
            sourcePlanHash: LWWRegister(value: "hash", clock: clock(1, nodeA)),
            items: ["x": ShoppingItemState(
                item: ShoppingItem(key: "x", name: "X"),
                clock: clock(1, nodeA)
            )]
        )
        let listData = try JSONEncoder().encode(list)
        let decodedList = try JSONDecoder().decode(ShoppingListDocument.self, from: listData)
        #expect(decodedList == list)
    }
}
