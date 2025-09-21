import Foundation

public enum MapDefinitions {
    public static func verticalSliceWeights() -> MapNodeWeights {
        let totalColumns = 10
        let columns: [MapNodeWeights.Column] = (0..<totalColumns).map { column in
            let weights: [BattleNodeType: Double]
            switch column {
            case 0:
                weights = [.battle: 0.6, .event: 0.4]
            case 1, 2:
                weights = [.battle: 0.5, .event: 0.2, .treasure: 0.2, .shop: 0.1]
            case 3,4,5:
                weights = [.battle: 0.45, .elite: 0.25, .event: 0.15, .treasure: 0.1, .shop: 0.05]
            case 6,7:
                weights = [.battle: 0.4, .elite: 0.35, .event: 0.1, .treasure: 0.1, .shop: 0.05]
            case 8:
                weights = [.elite: 0.5, .treasure: 0.3, .shop: 0.2]
            default:
                weights = [.boss: 1.0]
            }
            return MapNodeWeights.Column(columnIndex: column, weights: weights)
        }
        return MapNodeWeights(columns: columns, totalColumns: totalColumns)
    }

    public static func generateMap(using weights: MapNodeWeights, seed: UInt64) -> MapGraph {
        let totalColumns = weights.totalColumns
        guard totalColumns > 1 else {
            let boss = MapNode(column: 0, kind: .boss)
            return MapGraph(nodes: [boss], columns: totalColumns)
        }

        var rng = DeterministicRNG(seed: seed)
        var columns: [[MapNode]] = Array(repeating: [], count: totalColumns)

        for column in 0..<totalColumns {
            if column == totalColumns - 1 {
                let bossID = deterministicUUID(rng: &rng)
                columns[column] = [MapNode(id: bossID, column: column, kind: .boss, outgoing: [])]
                continue
            }

            let columnWeights = weightColumn(weights, index: column)
            let count = nodeCount(for: column, totalColumns: totalColumns, rng: &rng)
            var generated: [MapNode] = []
            for _ in 0..<count {
                let kind = sampleKind(weights: columnWeights, rng: &rng)
                let nodeID = deterministicUUID(rng: &rng)
                generated.append(MapNode(id: nodeID, column: column, kind: kind, outgoing: []))
            }
            if column == 0 && generated.count < 2 {
                let extraID = deterministicUUID(rng: &rng)
                generated.append(MapNode(id: extraID, column: column, kind: .battle, outgoing: []))
            }
            columns[column] = generated
        }

        // Build edges column by column
        for column in 0..<(totalColumns - 1) {
            let nextColumn = column + 1
            let nextNodeIDs = columns[nextColumn].map(\MapNode.id)
            guard !nextNodeIDs.isEmpty else { continue }

            for index in columns[column].indices {
                var targets: [UUID] = []
                let first = nextNodeIDs[rng.nextInt(nextNodeIDs.count)]
                targets.append(first)
                if nextNodeIDs.count > 1 && rng.nextDouble() < 0.5 {
                    var second = nextNodeIDs[rng.nextInt(nextNodeIDs.count)]
                    if nextNodeIDs.count > 1 {
                        var attempts = 0
                        while second == first && attempts < 4 {
                            second = nextNodeIDs[rng.nextInt(nextNodeIDs.count)]
                            attempts += 1
                        }
                    }
                    if second != first {
                        targets.append(second)
                    }
                }
                columns[column][index].outgoing = Array(Set(targets))
            }

            // Ensure every node in next column has at least one inbound edge
            var inboundCounts: [UUID: Int] = [:]
            for node in columns[column] {
                for target in node.outgoing {
                    inboundCounts[target, default: 0] += 1
                }
            }
            for targetIndex in columns[nextColumn].indices {
                let nodeID = columns[nextColumn][targetIndex].id
                if inboundCounts[nodeID, default: 0] == 0 {
                    let sourceIndex = rng.nextInt(columns[column].count)
                    columns[column][sourceIndex].outgoing.append(nodeID)
                }
            }
        }

        // Guarantee at least two distinct start paths if possible
        if columns.count > 2, columns[0].count >= 2, columns[1].count >= 2 {
            let firstTargets = Set(columns[0][0].outgoing)
            if firstTargets.count == 1 {
                let alternative = columns[1][1].id
                if !columns[0][0].outgoing.contains(alternative) {
                    columns[0][0].outgoing.append(alternative)
                }
            }
        }

        let allNodes = columns.flatMap { $0 }
        return MapGraph(nodes: allNodes, columns: totalColumns)
    }

    private static func nodeCount(for column: Int, totalColumns: Int, rng: inout DeterministicRNG) -> Int {
        if column == totalColumns - 1 { return 1 }
        if column == totalColumns - 2 { return 2 }
        return rng.nextDouble() < 0.6 ? 2 : 3
    }

    private static func weightColumn(_ weights: MapNodeWeights, index: Int) -> [BattleNodeType: Double] {
        if index < weights.columns.count {
            return weights.columns[index].weights
        }
        return [.battle: 1.0]
    }

    private static func sampleKind(weights: [BattleNodeType: Double], rng: inout DeterministicRNG) -> BattleNodeType {
        let total = weights.values.reduce(0.0, +)
        if total <= 0 { return .battle }
        let pick = rng.nextDouble() * total
        var cumulative: Double = 0
        for (kind, value) in weights {
            let weight = max(0, value)
            cumulative += weight
            if pick <= cumulative {
                return kind == .boss ? .battle : kind
            }
        }
        return .battle
    }

    private static func deterministicUUID(rng: inout DeterministicRNG) -> UUID {
        var raw = [UInt8](repeating: 0, count: 16)
        var value = rng.nextUInt64()
        var local = value
        for idx in 0..<8 {
            raw[idx] = UInt8(truncatingIfNeeded: local)
            local >>= 8
        }
        value = rng.nextUInt64()
        local = value
        for idx in 8..<16 {
            raw[idx] = UInt8(truncatingIfNeeded: local)
            local >>= 8
        }
        return UUID(uuid: (
            raw[0], raw[1], raw[2], raw[3],
            raw[4], raw[5], raw[6], raw[7],
            raw[8], raw[9], raw[10], raw[11],
            raw[12], raw[13], raw[14], raw[15]
        ))
    }
}
