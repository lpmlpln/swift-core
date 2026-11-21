import Testing
import Foundation
@testable import MealPlannerCore

@Suite("CRDT primitives")
struct CRDTPrimitiveTests {
    let nodeA = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    let nodeB = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!

    @Test("HLC is monotonic")
    func hlcMonotonic() {
        var generator = HLCGenerator(nodeID: nodeA)
        let fixed = Date(timeIntervalSince1970: 1_000)
        var previous = generator.now(at: fixed)
        for _ in 0..<100 {
            let next = generator.now(at: fixed)
            #expect(next > previous)
            previous = next
        }
    }

    @Test("HLC advances past remote clock")
    func hlcReceive() {
        var generator = HLCGenerator(nodeID: nodeA)
        _ = generator.now(at: Date(timeIntervalSince1970: 10))
        let remote = HLC(wallTimeMillis: 5_000, counter: 0, nodeID: nodeB)
        let merged = generator.receive(remote, at: Date(timeIntervalSince1970: 1))
        #expect(merged.wallTimeMillis == 10_000)
        #expect(merged.nodeID == nodeA)
        #expect(merged > remote)
    }

    @Test("HLC ordering is total")
    func hlcOrdering() {
        let a = HLC(wallTimeMillis: 100, counter: 0, nodeID: nodeA)
        let b = HLC(wallTimeMillis: 100, counter: 1, nodeID: nodeA)
        let c = HLC(wallTimeMillis: 100, counter: 1, nodeID: nodeB)
        #expect(a < b)
        #expect(b < c)
        #expect(a < c)
    }

    @Test("LWW register keeps the later clock")
    func registerMerge() {
        let older = LWWRegister(value: "a", clock: HLC(wallTimeMillis: 1, counter: 0, nodeID: nodeA))
        let newer = LWWRegister(value: "b", clock: HLC(wallTimeMillis: 2, counter: 0, nodeID: nodeA))
        #expect(older.merged(with: newer).value == "b")
        #expect(newer.merged(with: older).value == "b")
    }

    @Test("LWW map merge is commutative")
    func mapCommutative() {
        let clockA = HLC(wallTimeMillis: 10, counter: 0, nodeID: nodeA)
        let clockB = HLC(wallTimeMillis: 20, counter: 0, nodeID: nodeB)

        var left = LWWMap<String, Int>()
        left.set(1, for: "x", at: clockA)
        left.set(5, for: "z", at: clockA)

        var right = LWWMap<String, Int>()
        right.set(2, for: "x", at: clockB)
        right.set(3, for: "y", at: clockB)

        #expect(left.merged(with: right) == right.merged(with: left))
        #expect(left.merged(with: right)["x"]?.value == 2)
        #expect(left.merged(with: right)["y"]?.value == 3)
    }

    @Test("LWW map round trips through JSON")
    func mapCodable() throws {
        var map = LWWMap<String, Int>()
        map.set(42, for: "answer", at: HLC(wallTimeMillis: 1, counter: 0, nodeID: nodeA))
        let data = try JSONEncoder().encode(map)
        let decoded = try JSONDecoder().decode(LWWMap<String, Int>.self, from: data)
        #expect(decoded == map)
    }

    @Test("Merge laws hold on random registers")
    func mergeLaws() {
        var generator = SeededRandomNumberGenerator(seed: 99)
        for _ in 0..<200 {
            func randomClock() -> HLC {
                HLC(
                    wallTimeMillis: Int64(generator.next() % 1_000),
                    counter: UInt32(generator.next() % 5),
                    nodeID: generator.next() % 2 == 0 ? nodeA : nodeB
                )
            }
            let a = LWWRegister(value: Int(generator.next() % 100), clock: randomClock())
            let b = LWWRegister(value: Int(generator.next() % 100), clock: randomClock())
            let c = LWWRegister(value: Int(generator.next() % 100), clock: randomClock())

            #expect(a.merged(with: b) == b.merged(with: a))
            #expect(a.merged(with: a) == a)
            #expect(
                a.merged(with: b).merged(with: c)
                    == a.merged(with: b.merged(with: c))
            )
        }
    }
}
