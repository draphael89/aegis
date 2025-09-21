import Foundation

public struct UnitPlacement: Equatable, Codable, Sendable {
    public var archetypeKey: String
    public var lane: Lane
    public var slot: Int
    public var stance: Stance
    public var isHero: Bool
    public var isVeteran: Bool
    public var initialHP: Int?

    public init(
        archetypeKey: String,
        lane: Lane,
        slot: Int,
        stance: Stance,
        isHero: Bool = false,
        isVeteran: Bool = false,
        initialHP: Int? = nil
    ) {
        self.archetypeKey = archetypeKey
        self.lane = lane
        self.slot = slot
        self.stance = stance
        self.isHero = isHero
        self.isVeteran = isVeteran
        self.initialHP = initialHP
    }
}

public struct BattleSetup: Codable, Equatable, Sendable {
    public var playerPlacements: [UnitPlacement]
    public var enemyPlacements: [UnitPlacement]
    public var playerPyre: Pyre
    public var enemyPyre: Pyre
    public var energy: Int

    public init(
        playerPlacements: [UnitPlacement],
        enemyPlacements: [UnitPlacement],
        playerPyre: Pyre,
        enemyPyre: Pyre,
        energy: Int
    ) {
        self.playerPlacements = playerPlacements
        self.enemyPlacements = enemyPlacements
        self.playerPyre = playerPyre
        self.enemyPyre = enemyPyre
        self.energy = energy
    }
}

public struct BattleState {
    public private(set) var tick: Int = 0
    public var outcome: BattleOutcome = .inProgress
    public var units: [UnitID: UnitInstance] = [:]
    public var orderedUnitIDs: [UnitID] = []
    public var playerPyre: Pyre
    public var enemyPyre: Pyre
    public var energyRemaining: Int

    public init(setup: BattleSetup) {
        self.playerPyre = setup.playerPyre
        self.enemyPyre = setup.enemyPyre
        self.energyRemaining = setup.energy
    }

    mutating func advanceTick() {
        tick += 1
    }

    func units(for team: Team) -> [UnitInstance] {
        orderedUnitIDs.compactMap { units[$0] }.filter { $0.team == team }
    }

    mutating func insert(_ unit: UnitInstance) {
        units[unit.id] = unit
        orderedUnitIDs.append(unit.id)
    }

    mutating func remove(unitID: UnitID) {
        units.removeValue(forKey: unitID)
        if let idx = orderedUnitIDs.firstIndex(of: unitID) {
            orderedUnitIDs.remove(at: idx)
        }
    }

    func livingUnitCount(for team: Team) -> Int {
        units.values.filter { $0.team == team && $0.hp > 0 }.count
    }

    func digest() -> BattleDigest {
        BattleDigest(
            tick: tick,
            outcome: outcome,
            playerPyreHP: playerPyre.hp,
            enemyPyreHP: enemyPyre.hp,
            playerUnits: livingUnitCount(for: .player),
            enemyUnits: livingUnitCount(for: .enemy)
        )
    }
}

public struct ContentDatabase: Sendable {
    public var units: [String: UnitArchetype]

    public init(units: [UnitArchetype]) {
        self.units = Dictionary(uniqueKeysWithValues: units.map { ($0.key, $0) })
    }

    public func archetype(for key: String) throws -> UnitArchetype {
        guard let archetype = units[key] else {
            throw CoreEngineError.missingArchetype(key)
        }
        return archetype
    }
}

public enum CoreEngineError: Error {
    case missingArchetype(String)
    case invalidPlacementSlot(Int)
}
