import Foundation
import Testing
@testable import CoreEngine

@Test("encounter seed is deterministic")
func encounterSeedDeterminism() {
    let runSeed: UInt64 = 0xDEADBEEFCAFEBABE
    let nodeID = UUID(uuidString: "D9A54F62-7BB7-4C06-AF0D-7E79D407F7B3")!

    let seedA = SeedFactory.encounterSeed(runSeed: runSeed, floor: 2, nodeID: nodeID)
    let seedB = SeedFactory.encounterSeed(runSeed: runSeed, floor: 2, nodeID: nodeID)
    #expect(seedA == seedB)

    let seedDifferentFloor = SeedFactory.encounterSeed(runSeed: runSeed, floor: 3, nodeID: nodeID)
    #expect(seedDifferentFloor != seedA)

    let otherNode = UUID(uuidString: "0B38E8F4-E4D3-4CF1-9675-8FA7196E5AC9")!
    let seedDifferentNode = SeedFactory.encounterSeed(runSeed: runSeed, floor: 2, nodeID: otherNode)
    #expect(seedDifferentNode != seedA)
}

@Test("makeRunSeed produces mixed entropy")
func runSeedProvidesEntropy() {
    var seeds: Set<UInt64> = []
    for _ in 0..<32 {
        seeds.insert(SeedFactory.makeRunSeed())
    }
    #expect(seeds.count > 1)
}
