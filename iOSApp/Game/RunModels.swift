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

struct PrepSlot: Hashable {
    let lane: Lane
    let slot: Int
}

struct PrepCard: Identifiable, Equatable {
    let id: String
    let archetype: UnitArchetype

    var cost: Int { archetype.cost }
    var isHero: Bool { archetype.key == HeroKey.achilles }
}

struct PrepState {
    let node: RunNode
    let deck: [PrepCard]
    var selectedCardID: String?
    var placements: [PrepSlot: UnitPlacement]
    var remainingEnergy: Int
    let costByKey: [String: Int]

    var selectedCard: PrepCard? { deck.first { $0.id == selectedCardID } }

    func placement(for slot: PrepSlot) -> UnitPlacement? {
        placements[slot]
    }

    var hasHeroPlaced: Bool {
        placements.values.contains { $0.isHero }
    }

    var playerPlacements: [UnitPlacement] {
        placements.values.sorted { lhs, rhs in
            if lhs.lane.index == rhs.lane.index {
                return lhs.slot < rhs.slot
            }
            return lhs.lane.index < rhs.lane.index
        }
    }
}

final class RunViewModel: ObservableObject {
    @Published private(set) var catalog: ContentCatalog
    @Published private(set) var nodes: [RunNode]
    @Published private(set) var activeEncounter: Encounter?
    @Published private(set) var lastOutcome: BattleOutcome?
    @Published private(set) var prepState: PrepState?

    private(set) var runSeed: UInt64
    private var unitIndex: [String: UnitArchetype]
    private let mapGraph: MapGraph
    private var completedNodeIDs: Set<UUID> = []
    private var allowedNodeIDs: Set<UUID>
    private var currentColumnIndex: Int = 0

    init(
        catalog: ContentCatalog = ContentCatalogFactory.makeVerticalSliceCatalog(),
        runSeed: UInt64 = SeedFactory.makeRunSeed()
    ) {
        self.catalog = catalog
        self.runSeed = runSeed
        self.unitIndex = Dictionary(uniqueKeysWithValues: catalog.units.map { ($0.key, $0) })
        self.mapGraph = catalog.makeMapGraph(runSeed: runSeed)
        let startIDs = Set(mapGraph.nodes(in: 0).map(\MapNode.id))
        self.allowedNodeIDs = startIDs
        self.nodes = Self.makeRunNodes(for: 0,
                                       in: mapGraph,
                                       allowed: startIDs,
                                       completed: completedNodeIDs)
    }

    func startPrep(for node: RunNode) {
        guard !node.isCompleted, allowedNodeIDs.contains(node.id) else { return }

        let deck = makeDeck()
        let costByKey = Dictionary(uniqueKeysWithValues: deck.map { ($0.archetype.key, $0.cost) })
        var state = PrepState(
            node: node,
            deck: deck,
            selectedCardID: deck.first(where: { !$0.isHero })?.id ?? deck.first?.id,
            placements: [:],
            remainingEnergy: 10,
            costByKey: costByKey
        )
        autoPlaceHero(into: &state)
        prepState = state
    }

    func cancelPrep() {
        prepState = nil
    }

    func selectCard(_ card: PrepCard) {
        guard var state = prepState else { return }
        state.selectedCardID = card.id
        prepState = state
    }

    func placeSelectedCard(at slot: PrepSlot) {
        guard var state = prepState, let card = state.selectedCard else { return }
        if applyPlacement(of: card, at: slot, in: &state) {
            prepState = state
        }
    }

    func cycleStance(at slot: PrepSlot) {
        guard var state = prepState, var placement = state.placements[slot] else { return }
        let all = Stance.allCases
        if let idx = all.firstIndex(of: placement.stance) {
            placement.stance = all[(idx + 1) % all.count]
            state.placements[slot] = placement
            prepState = state
        }
    }

    func removePlacement(at slot: PrepSlot) {
        guard var state = prepState, let placement = state.placements[slot], !placement.isHero else { return }
        state.placements.removeValue(forKey: slot)
        if let refund = state.costByKey[placement.archetypeKey] {
            state.remainingEnergy += refund
        }
        prepState = state
    }

    func commitPrep() -> Encounter? {
        guard var state = prepState, state.hasHeroPlaced else { return nil }
        let (enemyPlacements, playerPyre, enemyPyre) = Self.baseBattleComponents()
        let playerPlacements = state.playerPlacements
        guard !playerPlacements.isEmpty else { return nil }

        let energy = max(0, state.remainingEnergy)
        let setup = BattleSetup(
            playerPlacements: playerPlacements,
            enemyPlacements: enemyPlacements,
            playerPyre: playerPyre,
            enemyPyre: enemyPyre,
            energy: energy
        )

        let node = state.node
        let column = mapGraph.node(with: node.id)?.column ?? currentColumnIndex
        let seed = SeedFactory.encounterSeed(
            runSeed: runSeed,
            floor: column,
            nodeID: node.id
        )

        prepState = nil
        activeEncounter = Encounter(node: node, setup: setup, seed: seed)
        lastOutcome = nil
        return activeEncounter
    }

    func resolvePendingEncounter() {
        guard let encounter else { return }
        let outcome = lastOutcome ?? .defeat
        if outcome == .victory {
            completedNodeIDs.insert(encounter.node.id)
            if let mapNode = mapGraph.node(with: encounter.node.id) {
                let nextColumn = mapNode.column + 1
                if nextColumn < mapGraph.columns {
                    let outgoing = Set(mapGraph.outgoingIDs(for: mapNode.id))
                    allowedNodeIDs = outgoing.isEmpty
                        ? Set(mapGraph.nodes(in: nextColumn).map(\MapNode.id))
                        : outgoing
                    currentColumnIndex = nextColumn
                    nodes = Self.makeRunNodes(for: nextColumn,
                                              in: mapGraph,
                                              allowed: allowedNodeIDs,
                                              completed: completedNodeIDs)
                } else {
                    nodes = []
                }
            }
        } else {
            // defeat → keep same column, allow reattempt of selected node
            allowedNodeIDs = [encounter.node.id]
            nodes = Self.makeRunNodes(for: currentColumnIndex,
                                      in: mapGraph,
                                      allowed: allowedNodeIDs,
                                      completed: completedNodeIDs)
        }
        activeEncounter = nil
        lastOutcome = outcome
    }

    func recordOutcome(_ outcome: BattleOutcome) {
        lastOutcome = outcome
    }

    private var encounter: Encounter? { activeEncounter }

    private static func defaultSetup(catalog: ContentCatalog) -> BattleSetup {
        let (enemyPlacements, playerPyre, enemyPyre) = baseBattleComponents()
        return BattleSetup(
            playerPlacements: [
                UnitPlacement(archetypeKey: HeroKey.achilles, lane: .mid, slot: 1, stance: .guard, isHero: true),
                UnitPlacement(archetypeKey: UnitKey.spearman, lane: .mid, slot: 0, stance: .guard),
                UnitPlacement(archetypeKey: UnitKey.archer, lane: .left, slot: 1, stance: .hunter),
                UnitPlacement(archetypeKey: UnitKey.healer, lane: .right, slot: 2, stance: .skirmish)
            ],
            enemyPlacements: enemyPlacements,
            playerPyre: playerPyre,
            enemyPyre: enemyPyre,
            energy: 10
        )
    }

    private static func baseBattleComponents() -> ([UnitPlacement], Pyre, Pyre) {
        let enemyPlacements = [
            UnitPlacement(archetypeKey: UnitKey.spearman, lane: .mid, slot: 0, stance: .guard),
            UnitPlacement(archetypeKey: UnitKey.archer, lane: .left, slot: 1, stance: .guard),
            UnitPlacement(archetypeKey: UnitKey.healer, lane: .right, slot: 2, stance: .skirmish)
        ]
        let playerPyre = Pyre(team: .player, hp: 200, attack: 8, attackIntervalTicks: 72)
        let enemyPyre = Pyre(team: .enemy, hp: 200, attack: 8, attackIntervalTicks: 72)
        return (enemyPlacements, playerPyre, enemyPyre)
    }

    private static func makeRunNodes(for column: Int,
                                     in graph: MapGraph,
                                     allowed: Set<UUID>,
                                     completed: Set<UUID>) -> [RunNode] {
        graph.nodes(in: column).map { mapNode in
            let kind = mapRunKind(for: mapNode.kind)
            return RunNode(id: mapNode.id,
                           kind: kind,
                           isCompleted: completed.contains(mapNode.id),
                           isLocked: !allowed.contains(mapNode.id))
        }
    }

    private static func mapRunKind(for type: BattleNodeType) -> RunNode.Kind {
        switch type {
        case .battle: return .battle
        case .elite: return .elite
        case .event: return .event
        case .shop: return .shop
        case .treasure: return .treasure
        case .boss: return .boss
        }
    }

    private func makeDeck() -> [PrepCard] {
        catalog.units.map { PrepCard(id: $0.key, archetype: $0) }
            .sorted { lhs, rhs in
                if lhs.isHero != rhs.isHero { return lhs.isHero }
                return lhs.archetype.key < rhs.archetype.key
            }
    }

    private func autoPlaceHero(into state: inout PrepState) {
        guard let hero = state.deck.first(where: { $0.isHero }) else { return }
        let slot = PrepSlot(lane: .mid, slot: 1)
        _ = applyPlacement(of: hero, at: slot, in: &state, ignoreEnergy: true)
        if state.selectedCardID == nil {
            state.selectedCardID = state.deck.first(where: { !$0.isHero })?.id
        }
    }

    private func applyPlacement(of card: PrepCard, at slot: PrepSlot, in state: inout PrepState, ignoreEnergy: Bool = false) -> Bool {
        if let existing = state.placements[slot] {
            if existing.isHero && !card.isHero { return false }
            if !existing.isHero {
                if let refund = state.costByKey[existing.archetypeKey] {
                    state.remainingEnergy += refund
                }
            }
            state.placements.removeValue(forKey: slot)
        }

        if card.isHero {
            if let heroSlot = state.placements.first(where: { $0.value.isHero })?.key {
                state.placements.removeValue(forKey: heroSlot)
            }
        }

        if !card.isHero && !ignoreEnergy {
            let cost = state.costByKey[card.archetype.key] ?? card.cost
            guard state.remainingEnergy >= cost else { return false }
            state.remainingEnergy -= cost
        }

        var placement = UnitPlacement(
            archetypeKey: card.archetype.key,
            lane: slot.lane,
            slot: slot.slot,
            stance: defaultStance(for: card.archetype),
            isHero: card.isHero
        )
        placement.isVeteran = false
        state.placements[slot] = placement
        return true
    }

    private func defaultStance(for archetype: UnitArchetype) -> Stance {
        switch archetype.role {
        case .melee: return .guard
        case .ranged: return .hunter
        case .healer: return .skirmish
        case .buffer: return .guard
        }
    }

    func displayName(for archetypeKey: String) -> String {
        if let archetype = unitIndex[archetypeKey] {
            if archetype.key == HeroKey.achilles { return "Achilles" }
            if archetype.key == UnitKey.spearman { return "Spearman" }
            if archetype.key == UnitKey.archer { return "Archer" }
            if archetype.key == UnitKey.healer { return "Healer" }
            if archetype.key == UnitKey.patroclus { return "Patroclus" }
        }
        return archetypeKey
    }
}
