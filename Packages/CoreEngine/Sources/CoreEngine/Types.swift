import Foundation

public enum Team: UInt8, CaseIterable, Codable, Sendable {
    case player
    case enemy

    var direction: Int {
        switch self {
        case .player: return 1
        case .enemy: return -1
        }
    }
}

public enum Lane: UInt8, CaseIterable, Codable, Sendable {
    case left
    case mid
    case right

    public var index: Int { Int(rawValue) }
}

public enum Role: UInt8, Codable, Sendable {
    case melee
    case ranged
    case healer
    case buffer
}

public enum Stance: UInt8, Codable, Sendable {
    case `guard`
    case skirmish
    case hunter
}

public struct UnitArchetype: Codable, Hashable, Sendable {
    public let key: String
    public let role: Role
    public let maxHP: Int
    public let attack: Int
    public let attackIntervalTicks: Int
    public let rangeTiles: Int
    public let speedTilesPerSecond: Int
    public let cost: Int

    public init(
        key: String,
        role: Role,
        maxHP: Int,
        attack: Int,
        attackIntervalTicks: Int,
        rangeTiles: Int,
        speedTilesPerSecond: Int,
        cost: Int
    ) {
        self.key = key
        self.role = role
        self.maxHP = maxHP
        self.attack = attack
        self.attackIntervalTicks = attackIntervalTicks
        self.rangeTiles = rangeTiles
        self.speedTilesPerSecond = speedTilesPerSecond
        self.cost = cost
    }
}

public enum StatusEffect: Equatable, Sendable {
    case rally(expiresAtTick: Int, attackSpeedModifierPct: Int)
    case burn(damagePerTick: Int, expiresAtTick: Int)
    case slow(percent: Int, expiresAtTick: Int)
}

public enum SpellEffect: Equatable, Sendable {
    case heal(amount: Int, radius: Int?)
    case fireball(damage: Int, radius: Int)
    case rally(attackSpeedPercent: Int, durationTicks: Int)
}

public struct SpellArchetype: Equatable, Sendable {
    public let key: String
    public let cost: Int
    public let effect: SpellEffect

    public init(key: String, cost: Int, effect: SpellEffect) {
        self.key = key
        self.cost = cost
        self.effect = effect
    }
}

public enum SpellTarget: Equatable, Sendable {
    case unit(UnitID)
    case lanePoint(lane: Lane, xTile: Int)
}

public struct UnitID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init() {
        self.rawValue = UUID()
    }
}

public struct UnitInstance: Identifiable, Equatable, Sendable {
    public let id: UnitID
    public let archetypeKey: String
    public var team: Team
    public var lane: Lane
    /// slot index within lane: 0=front, 1=mid, 2=back
    public var slot: Int
    /// Integer tile progress along battlefield, 0 at player pyre to `fieldLengthTiles` at enemy pyre.
    public var xTile: Int
    public var hp: Int
    public var attackCooldown: Int
    public var stance: Stance
    public var statuses: [StatusEffect]
    public var isHero: Bool
    public var isVeteran: Bool

    public init(
        id: UnitID = UnitID(),
        archetypeKey: String,
        team: Team,
        lane: Lane,
        slot: Int,
        xTile: Int,
        hp: Int,
        attackCooldown: Int,
        stance: Stance,
        statuses: [StatusEffect] = [],
        isHero: Bool,
        isVeteran: Bool
    ) {
        self.id = id
        self.archetypeKey = archetypeKey
        self.team = team
        self.lane = lane
        self.slot = slot
        self.xTile = xTile
        self.hp = hp
        self.attackCooldown = attackCooldown
        self.stance = stance
        self.statuses = statuses
        self.isHero = isHero
        self.isVeteran = isVeteran
    }
}

public struct Pyre: Equatable, Codable, Sendable {
    public var team: Team
    public var hp: Int
    public var attack: Int
    public var attackIntervalTicks: Int
    public var cooldown: Int

    public init(team: Team, hp: Int, attack: Int, attackIntervalTicks: Int) {
        self.team = team
        self.hp = hp
        self.attack = attack
        self.attackIntervalTicks = attackIntervalTicks
        self.cooldown = attackIntervalTicks
    }
}

public enum BattleOutcome: Equatable, Sendable {
    case inProgress
    case victory
    case defeat
}

public struct BattleDigest: Hashable, Sendable {
    public let tick: Int
    public let outcome: BattleOutcome
    public let playerPyreHP: Int
    public let enemyPyreHP: Int
    public let playerUnits: Int
    public let enemyUnits: Int

    public init(tick: Int, outcome: BattleOutcome, playerPyreHP: Int, enemyPyreHP: Int, playerUnits: Int, enemyUnits: Int) {
        self.tick = tick
        self.outcome = outcome
        self.playerPyreHP = playerPyreHP
        self.enemyPyreHP = enemyPyreHP
        self.playerUnits = playerUnits
        self.enemyUnits = enemyUnits
    }
}

public enum BattleEvent: Equatable {
    case unitSpawned(UnitInstance)
    case unitDied(UnitID)
    case pyreDamaged(team: Team, delta: Int)
    case battleEnded(BattleOutcome)
}

public struct BattleConfig {
    public var fieldLengthTiles: Int = 30
    public var laneWidthPixels: Int = 96
    public var tickRate: Int = 60

    public init() {}
}
