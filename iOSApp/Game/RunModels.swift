import CoreEngine
import Foundation
import MetaKit

struct RunNode: Identifiable, Equatable {
    enum Kind: String { case battle, elite, event, shop, treasure, boss }

    let id: UUID
    let kind: Kind
    var isCompleted: Bool
    var isLocked: Bool

    var displayName: String {
        switch kind {
        case .battle: return "Battle"
        case .elite: return "Elite"
        case .event: return "Event"
        case .shop: return "Shop"
        case .treasure: return "Treasure"
        case .boss: return "Boss"
        }
    }

    init(id: UUID = UUID(), kind: Kind, isCompleted: Bool = false, isLocked: Bool = false) {
        self.id = id
        self.kind = kind
        self.isCompleted = isCompleted
        self.isLocked = isLocked
    }
}

struct Encounter {
    let node: RunNode
    let setup: BattleSetup
    let seed: UInt64
}

final class RunViewModel: ObservableObject {
    @Published private(set) var catalog: ContentCatalog
    @Published private(set) var nodes: [RunNode]
    @Published private(set) var activeEncounter: Encounter?
    @Published private(set) var lastOutcome: BattleOutcome?

    private(set) var runSeed: UInt64

    init(
        catalog: ContentCatalog = ContentCatalogFactory.makeVerticalSliceCatalog(),
        runSeed: UInt64 = SeedFactory.makeRunSeed()
    ) {
        self.catalog = catalog
        self.runSeed = runSeed
        self.nodes = [
            RunNode(kind: .battle),
            RunNode(kind: .battle, isLocked: true),
            RunNode(kind: .boss, isLocked: true)
        ]
    }

    func prepareEncounter(for node: RunNode) {
        guard let index = nodes.firstIndex(of: node), !nodes[index].isCompleted else { return }
        let seed = SeedFactory.encounterSeed(
            runSeed: runSeed,
            floor: index,
            nodeID: node.id
        )
        activeEncounter = Encounter(
            node: node,
            setup: Self.defaultSetup(catalog: catalog),
            seed: seed
        )
        lastOutcome = nil
        var updated = nodes
        updated[index].isLocked = false
        if index + 1 < updated.count {
            updated[index + 1].isLocked = false
        }
        nodes = updated
    }

    func resolvePendingEncounter() {
        guard let encounter else { return }
        let outcome = lastOutcome ?? .defeat
        if let index = nodes.firstIndex(of: encounter.node) {
            var updated = nodes
            updated[index].isCompleted = true
            if index + 1 < updated.count {
                updated[index + 1].isLocked = false
            }
            nodes = updated
        }
        activeEncounter = nil
        lastOutcome = outcome
    }

    func recordOutcome(_ outcome: BattleOutcome) {
        lastOutcome = outcome
    }

    private var encounter: Encounter? { activeEncounter }

    private static func defaultSetup(catalog: ContentCatalog) -> BattleSetup {
        BattleSetup(
            playerPlacements: [
                UnitPlacement(archetypeKey: HeroKey.achilles, lane: .mid, slot: 1, stance: .guard, isHero: true),
                UnitPlacement(archetypeKey: UnitKey.spearman, lane: .mid, slot: 0, stance: .guard),
                UnitPlacement(archetypeKey: UnitKey.archer, lane: .left, slot: 1, stance: .hunter),
                UnitPlacement(archetypeKey: UnitKey.healer, lane: .right, slot: 2, stance: .skirmish)
            ],
            enemyPlacements: [
                UnitPlacement(archetypeKey: UnitKey.spearman, lane: .mid, slot: 0, stance: .guard),
                UnitPlacement(archetypeKey: UnitKey.archer, lane: .left, slot: 1, stance: .guard),
                UnitPlacement(archetypeKey: UnitKey.healer, lane: .right, slot: 2, stance: .skirmish)
            ],
            playerPyre: Pyre(team: .player, hp: 200, attack: 8, attackIntervalTicks: 72),
            enemyPyre: Pyre(team: .enemy, hp: 200, attack: 8, attackIntervalTicks: 72),
            energy: 10
        )
    }
}
