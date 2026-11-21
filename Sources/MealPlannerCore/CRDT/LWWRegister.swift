import Foundation

/// Last-writer-wins register. Merge keeps the value with the greater clock.
public struct LWWRegister<Value: Hashable & Codable & Sendable>: Hashable, Codable, Sendable {
    public var value: Value
    public var clock: HLC

    public init(value: Value, clock: HLC) {
        self.value = value
        self.clock = clock
    }

    public func merged(with other: LWWRegister<Value>) -> LWWRegister<Value> {
        clock >= other.clock ? self : other
    }

    public func updated(to newValue: Value, at newClock: HLC) -> LWWRegister<Value> {
        LWWRegister(value: newValue, clock: newClock)
    }
}
