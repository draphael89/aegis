import Foundation
import Testing
@testable import MetaKit

@Test("Boss column is boss-only")
func mapGraphBossColumn() {
    let catalog = ContentCatalogFactory.makeVerticalSliceCatalog()
    let graph = catalog.makeMapGraph(runSeed: 1)
    let lastColumn = graph.columns - 1
    let bosses = graph.nodes(in: lastColumn)
    #expect(!bosses.isEmpty)
    #expect(bosses.allSatisfy { $0.kind == .boss })
}

@Test("Each node has inbound edge from previous column")
func mapGraphConnectivity() {
    let catalog = ContentCatalogFactory.makeVerticalSliceCatalog()
    let graph = catalog.makeMapGraph(runSeed: 2)
    #expect(graph.columns > 1)
    for column in 1..<graph.columns {
        let nodes = graph.nodes(in: column)
        for node in nodes {
            var inbound = false
            for previous in graph.nodes(in: column - 1) {
                if previous.outgoing.contains(node.id) {
                    inbound = true
                    break
                }
            }
            #expect(inbound, "Node in column \(column) lacked inbound edge")
        }
    }
}

@Test("Map generation is deterministic per seed")
func mapGraphDeterminism() {
    let catalog = ContentCatalogFactory.makeVerticalSliceCatalog()
    let graphA = catalog.makeMapGraph(runSeed: 42)
    let graphB = catalog.makeMapGraph(runSeed: 42)
    let graphC = catalog.makeMapGraph(runSeed: 99)

    #expect(graphA.nodes.map(\MapNode.id) == graphB.nodes.map(\MapNode.id))
    #expect(graphA.nodes.map(\MapNode.kind) == graphB.nodes.map(\MapNode.kind))

    #expect(graphA.nodes.map(\MapNode.id) != graphC.nodes.map(\MapNode.id))
}
