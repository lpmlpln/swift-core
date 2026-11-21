import Foundation

/// A mergeable map of last-writer-wins registers.
public struct LWWMap<Key: Hashable & Codable & Sendable, Value: Hashable & Codable & Sendable>: Hashable, Codable, Sendable {
    public var entries: [Key: LWWRegister<Value>]

    public init(entries: [Key: LWWRegister<Value>] = [:]) {
        self.entries = entries
    }

    public subscript(key: Key) -> LWWRegister<Value>? {
        get { entries[key] }
        set { entries[key] = newValue }
    }

    public func merged(with other: LWWMap<Key, Value>) -> LWWMap<Key, Value> {
        var result = entries
        for (key, register) in other.entries {
            if let existing = result[key] {
                result[key] = existing.merged(with: register)
            } else {
                result[key] = register
            }
        }
        return LWWMap(entries: result)
    }

    public mutating func set(_ value: Value, for key: Key, at clock: HLC) {
        entries[key] = LWWRegister(value: value, clock: clock)
    }

    public mutating func removeValue(for key: Key) {
        entries.removeValue(forKey: key)
    }

    private struct Entry: Codable {
        var key: Key
        var register: LWWRegister<Value>
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decoded = try container.decode([Entry].self)
        entries = Dictionary(uniqueKeysWithValues: decoded.map { ($0.key, $0.register) })
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let sorted = entries
            .map { Entry(key: $0.key, register: $0.value) }
            .sorted { String(describing: $0.key) < String(describing: $1.key) }
        try container.encode(sorted)
    }
}
