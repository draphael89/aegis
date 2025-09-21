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

public struct BattleSetup: Equatable, Sendable {
    public var playerPlacements: [UnitPlacement]
    public var enemyPlacements: [UnitPlacement]
    public var playerPyre: Pyre
    public var enemyPyre: Pyre
    public var energy: Int
    public var playerArtifacts: [String] = []
    public var enemyArtifacts: [String] = []
    public var playerTraps: [Lane: String] = [:]
    public var enemyTraps: [Lane: String] = [:]

    public init(
        playerPlacements: [UnitPlacement],
        enemyPlacements: [UnitPlacement],
        playerPyre: Pyre,
        enemyPyre: Pyre,
        energy: Int,
        playerArtifacts: [String] = [],
        enemyArtifacts: [String] = [],
        playerTraps: [Lane: String] = [:],
        enemyTraps: [Lane: String] = [:]
    ) {
        self.playerPlacements = playerPlacements
        self.enemyPlacements = enemyPlacements
        self.playerPyre = playerPyre
        self.enemyPyre = enemyPyre
        self.energy = energy
        self.playerArtifacts = playerArtifacts
        self.enemyArtifacts = enemyArtifacts
        self.playerTraps = playerTraps
        self.enemyTraps = enemyTraps
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
    public var spellsHand: [String]
    public var castsRemaining: Int
    public var playerArtifacts: [String] = []
    public var enemyArtifacts: [String] = []
    public var trapTriggered: [Team: [Lane: Bool]] = [.player: [:], .enemy: [:]]
    public var lastAttacker: [UnitID: UnitID] = [:]  // For Lyre of Apollo
    public var skirmishManeuverUsed: Bool = false

    public init(setup: BattleSetup) {
        self.playerPyre = setup.playerPyre
        self.enemyPyre = setup.enemyPyre
        self.energyRemaining = setup.energy
        self.spellsHand = []
        self.castsRemaining = 2
        self.playerArtifacts = setup.playerArtifacts
        self.enemyArtifacts = setup.enemyArtifacts
        // Initialize trap tracking - traps are not triggered yet
        for lane in Lane.allCases {
            if setup.playerTraps[lane] != nil {
                self.trapTriggered[.player]?[lane] = false
            }
            if setup.enemyTraps[lane] != nil {
                self.trapTriggered[.enemy]?[lane] = false
            }
        }
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
    public var spells: [String: SpellArchetype]

    public init(units: [UnitArchetype], spells: [SpellArchetype] = []) {
        self.units = Dictionary(uniqueKeysWithValues: units.map { ($0.key, $0) })
        self.spells = Dictionary(uniqueKeysWithValues: spells.map { ($0.key, $0) })
    }

    public func archetype(for key: String) throws -> UnitArchetype {
        guard let archetype = units[key] else {
            throw CoreEngineError.missingArchetype(key)
        }
        return archetype
    }

    public func spell(for key: String) throws -> SpellArchetype {
        guard let spell = spells[key] else {
            throw CoreEngineError.missingSpell(key)
        }
        return spell
    }
}

public enum CoreEngineError: Error {
    case missingArchetype(String)
    case missingSpell(String)
    case invalidPlacementSlot(Int)
}

// MARK: - Codable
extension BattleSetup: Codable {
    enum CodingKeys: String, CodingKey {
        case playerPlacements, enemyPlacements, playerPyre, enemyPyre, energy
        case playerArtifacts, enemyArtifacts, playerTraps, enemyTraps
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.playerPlacements = try container.decode([UnitPlacement].self, forKey: .playerPlacements)
        self.enemyPlacements = try container.decode([UnitPlacement].self, forKey: .enemyPlacements)
        self.playerPyre = try container.decode(Pyre.self, forKey: .playerPyre)
        self.enemyPyre = try container.decode(Pyre.self, forKey: .enemyPyre)
        self.energy = try container.decode(Int.self, forKey: .energy)
        
        // New fields with defaults for backward compatibility
        self.playerArtifacts = try container.decodeIfPresent([String].self, forKey: .playerArtifacts) ?? []
        self.enemyArtifacts = try container.decodeIfPresent([String].self, forKey: .enemyArtifacts) ?? []
        self.playerTraps = try container.decodeIfPresent([Lane: String].self, forKey: .playerTraps) ?? [:]
        self.enemyTraps = try container.decodeIfPresent([Lane: String].self, forKey: .enemyTraps) ?? [:]
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(playerPlacements, forKey: .playerPlacements)
        try container.encode(enemyPlacements, forKey: .enemyPlacements)
        try container.encode(playerPyre, forKey: .playerPyre)
        try container.encode(enemyPyre, forKey: .enemyPyre)
        try container.encode(energy, forKey: .energy)
        try container.encode(playerArtifacts, forKey: .playerArtifacts)
        try container.encode(enemyArtifacts, forKey: .enemyArtifacts)
        try container.encode(playerTraps, forKey: .playerTraps)
        try container.encode(enemyTraps, forKey: .enemyTraps)
    }
}
