import Foundation

public struct MapNode: Identifiable, Codable, Sendable {
    public let id: UUID
    public let column: Int
    public let kind: BattleNodeType
    public var outgoing: [UUID]

    public init(id: UUID = UUID(), column: Int, kind: BattleNodeType, outgoing: [UUID] = []) {
        self.id = id
        self.column = column
        self.kind = kind
        self.outgoing = outgoing
    }
}

public struct MapGraph: Codable, Sendable {
    public let nodes: [MapNode]
    public let columns: Int

    public init(nodes: [MapNode], columns: Int) {
        self.nodes = nodes
        self.columns = columns
    }

    public func nodes(in column: Int) -> [MapNode] {
        nodes.filter { $0.column == column }
    }

    public func node(with id: UUID) -> MapNode? {
        nodes.first { $0.id == id }
    }

    public func outgoingIDs(for id: UUID) -> [UUID] {
        node(with: id)?.outgoing ?? []
    }
}

struct DeterministicRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextDouble() -> Double {
        Double(nextUInt64()) / Double(UInt64.max)
    }

    mutating func nextInt(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(nextUInt64() % UInt64(upperBound))
    }
}
