import Foundation

/// Hybrid Logical Clock used to order CRDT writes across devices.
public struct HLC: Hashable, Comparable, Codable, Sendable {
    public var wallTimeMillis: Int64
    public var counter: UInt32
    public var nodeID: UUID

    public init(wallTimeMillis: Int64, counter: UInt32, nodeID: UUID) {
        self.wallTimeMillis = wallTimeMillis
        self.counter = counter
        self.nodeID = nodeID
    }

    public static func < (lhs: HLC, rhs: HLC) -> Bool {
        if lhs.wallTimeMillis != rhs.wallTimeMillis {
            return lhs.wallTimeMillis < rhs.wallTimeMillis
        }
        if lhs.counter != rhs.counter {
            return lhs.counter < rhs.counter
        }
        return lhs.nodeID.uuidString < rhs.nodeID.uuidString
    }
}

/// Generates monotonically increasing clocks for one device.
public struct HLCGenerator: Sendable {
    public let nodeID: UUID
    private var last: HLC

    public init(nodeID: UUID, last: HLC? = nil) {
        self.nodeID = nodeID
        self.last = last ?? HLC(wallTimeMillis: 0, counter: 0, nodeID: nodeID)
    }

    public var current: HLC { last }

    public mutating func now(at date: Date = Date()) -> HLC {
        let wall = Int64(date.timeIntervalSince1970 * 1_000)
        if wall > last.wallTimeMillis {
            last = HLC(wallTimeMillis: wall, counter: 0, nodeID: nodeID)
        } else {
            last = HLC(wallTimeMillis: last.wallTimeMillis, counter: last.counter + 1, nodeID: nodeID)
        }
        return last
    }

    public mutating func receive(_ remote: HLC, at date: Date = Date()) -> HLC {
        let wall = Int64(date.timeIntervalSince1970 * 1_000)
        let maxWall = max(wall, last.wallTimeMillis, remote.wallTimeMillis)
        let counter: UInt32
        if maxWall == last.wallTimeMillis && maxWall == remote.wallTimeMillis {
            counter = max(last.counter, remote.counter) + 1
        } else if maxWall == last.wallTimeMillis {
            counter = last.counter + 1
        } else if maxWall == remote.wallTimeMillis {
            counter = remote.counter + 1
        } else {
            counter = 0
        }
        last = HLC(wallTimeMillis: maxWall, counter: counter, nodeID: nodeID)
        return last
    }
}
