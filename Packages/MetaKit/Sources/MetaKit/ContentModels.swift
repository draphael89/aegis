import CoreEngine
import Foundation

public struct SpellDefinition: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case heal(amount: Int, radius: Int?)
        case fireball(damage: Int, radius: Int)
        case rally(attackSpeedPercent: Int, durationTicks: Int)
    }

    public let id: String
    public let cost: Int
    public let effect: Effect

    public init(id: String, cost: Int, effect: Effect) {
        self.id = id
        self.cost = cost
        self.effect = effect
    }
}

public struct TrapDefinition: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case spikes(damage: Int)
    }

    public let id: String
    public let cost: Int
    public let effect: Effect

    public init(id: String, cost: Int, effect: Effect) {
        self.id = id
        self.cost = cost
        self.effect = effect
    }
}

public struct ArtifactDefinition: Equatable, Sendable {
    public enum Effect: Equatable, Sendable {
        case frontSlotArmor(amount: Int)
        case onKillHeal(amount: Int)
    }

    public let id: String
    public let effect: Effect
    public let description: String

    public init(id: String, effect: Effect, description: String) {
        self.id = id
        self.effect = effect
        self.description = description
    }
}

public struct HeroDefinition: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let archetype: UnitArchetype
    public let passiveDescription: String

    public init(id: String, displayName: String, archetype: UnitArchetype, passiveDescription: String) {
        self.id = id
        self.displayName = displayName
        self.archetype = archetype
        self.passiveDescription = passiveDescription
    }
}

public struct MapNodeWeights: Equatable, Sendable {
    public struct Column: Equatable, Sendable {
        public let columnIndex: Int
        public let weights: [BattleNodeType: Double]

        public init(columnIndex: Int, weights: [BattleNodeType: Double]) {
            self.columnIndex = columnIndex
            self.weights = weights
        }
    }

    public let columns: [Column]
    public let totalColumns: Int

    public init(columns: [Column], totalColumns: Int) {
        self.columns = columns
        self.totalColumns = totalColumns
    }
}

public enum BattleNodeType: String, CaseIterable, Codable, Sendable {
    case battle
    case elite
    case event
    case treasure
    case shop
    case boss
}

public struct ContentCatalog: Sendable {
    public let units: [UnitArchetype]
    public let spells: [SpellDefinition]
    public let traps: [TrapDefinition]
    public let artifacts: [ArtifactDefinition]
    public let heroes: [HeroDefinition]
    public let mapWeights: MapNodeWeights

    public init(
        units: [UnitArchetype],
        spells: [SpellDefinition],
        traps: [TrapDefinition],
        artifacts: [ArtifactDefinition],
        heroes: [HeroDefinition],
        mapWeights: MapNodeWeights
    ) {
        self.units = units
        self.spells = spells
        self.traps = traps
        self.artifacts = artifacts
        self.heroes = heroes
        self.mapWeights = mapWeights
    }

    public func makeContentDatabase() -> ContentDatabase {
        let spellArchetypes = spells.map { spell in
            SpellArchetype(key: spell.id, cost: spell.cost, effect: spell.effect.toCoreEffect())
        }
        return ContentDatabase(units: units, spells: spellArchetypes)
    }
}

private extension SpellDefinition.Effect {
    func toCoreEffect() -> SpellEffect {
        switch self {
        case let .heal(amount, radius):
            return .heal(amount: amount, radius: radius)
        case let .fireball(damage, radius):
            return .fireball(damage: damage, radius: radius)
        case let .rally(percent, duration):
            return .rally(attackSpeedPercent: percent, durationTicks: duration)
        }
    }
}
