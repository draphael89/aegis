import Testing
@testable import CoreEngine

@Suite("Spells")
struct SpellsTests {
    @Test("Heal clamps to max HP and consumes energy")
    func healClampsToMaxHP() throws {
        let units: [UnitArchetype] = [
            UnitArchetype(key: "spearman", role: .melee, maxHP: 60, attack: 8, attackIntervalTicks: 60, rangeTiles: 1, speedTilesPerSecond: 2, cost: 2)
        ]
        let spells: [SpellArchetype] = [
            SpellArchetype(key: "heal", cost: 2, effect: .heal(amount: 25, radius: nil))
        ]
        let content = ContentDatabase(units: units, spells: spells)
        let setup = BattleSetup(
            playerPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard, isHero: true, initialHP: 50)
            ],
            enemyPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard)
            ],
            playerPyre: Pyre(team: .player, hp: 200, attack: 8, attackIntervalTicks: 72),
            enemyPyre: Pyre(team: .enemy, hp: 200, attack: 8, attackIntervalTicks: 72),
            energy: 10
        )
        let simulation = try BattleSimulation(setup: setup, content: content, seed: 12345)

        #expect(simulation.cast(spellID: "heal", target: .lanePoint(lane: .mid, xTile: 0)))
        #expect(simulation.state.energyRemaining == 8)
        #expect(simulation.state.castsRemaining == 1)

        let healedUnit = simulation.state.units.values.first { $0.team == .player }!
        #expect(healedUnit.hp == 60)
    }

    @Test("Fireball damages enemies within radius deterministically")
    func fireballDamagesInRadius() throws {
        let units: [UnitArchetype] = [
            UnitArchetype(key: "spearman", role: .melee, maxHP: 60, attack: 8, attackIntervalTicks: 60, rangeTiles: 1, speedTilesPerSecond: 2, cost: 2)
        ]
        let spells: [SpellArchetype] = [
            SpellArchetype(key: "fireball", cost: 3, effect: .fireball(damage: 60, radius: 1))
        ]
        let content = ContentDatabase(units: units, spells: spells)
        let setup = BattleSetup(
            playerPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard, isHero: true)
            ],
            enemyPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard),
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 1, stance: .guard),
                UnitPlacement(archetypeKey: "spearman", lane: .left, slot: 0, stance: .guard)
            ],
            playerPyre: Pyre(team: .player, hp: 200, attack: 8, attackIntervalTicks: 72),
            enemyPyre: Pyre(team: .enemy, hp: 200, attack: 8, attackIntervalTicks: 72),
            energy: 10
        )
        let simulation = try BattleSimulation(setup: setup, content: content, seed: 67890)

        #expect(simulation.cast(spellID: "fireball", target: .lanePoint(lane: .mid, xTile: 28)))
        #expect(simulation.state.energyRemaining == 7)
        #expect(simulation.state.castsRemaining == 1)

        let livingEnemies = simulation.state.units.values.filter { $0.team == .enemy && $0.hp > 0 }
        #expect(livingEnemies.count == 1)
        #expect(livingEnemies.first?.lane == .left)
    }
}
