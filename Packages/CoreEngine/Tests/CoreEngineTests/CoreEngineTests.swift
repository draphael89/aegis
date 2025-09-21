import Foundation
import Testing
@testable import CoreEngine

private enum Fixtures {
    static let spearman = UnitArchetype(
        key: "spearman",
        role: .melee,
        maxHP: 60,
        attack: 8,
        attackIntervalTicks: 60,
        rangeTiles: 1,
        speedTilesPerSecond: 2,
        cost: 2
    )

    static let archer = UnitArchetype(
        key: "archer",
        role: .ranged,
        maxHP: 40,
        attack: 7,
        attackIntervalTicks: 60,
        rangeTiles: 4,
        speedTilesPerSecond: 2,
        cost: 3
    )

    static let healer = UnitArchetype(
        key: "healer",
        role: .healer,
        maxHP: 45,
        attack: 0,
        attackIntervalTicks: 45,
        rangeTiles: 4,
        speedTilesPerSecond: 2,
        cost: 3
    )

    static let content = ContentDatabase(units: [spearman, archer, healer])

    static func defaultSetup() -> BattleSetup {
        BattleSetup(
            playerPlacements: [
                UnitPlacement(
                    archetypeKey: "spearman",
                    lane: .mid,
                    slot: 0,
                    stance: .guard,
                    isHero: true,
                    initialHP: 80
                ),
                UnitPlacement(
                    archetypeKey: "archer",
                    lane: .left,
                    slot: 1,
                    stance: .hunter
                )
            ],
            enemyPlacements: [
                UnitPlacement(
                    archetypeKey: "spearman",
                    lane: .mid,
                    slot: 0,
                    stance: .guard,
                    isHero: false,
                    initialHP: 40
                ),
                UnitPlacement(
                    archetypeKey: "archer",
                    lane: .left,
                    slot: 1,
                    stance: .guard
                )
            ],
            playerPyre: Pyre(team: .player, hp: 200, attack: 6, attackIntervalTicks: 72),
            enemyPyre: Pyre(team: .enemy, hp: 200, attack: 4, attackIntervalTicks: 72),
            energy: 10
        )
    }
}

@Test("Simulation produces deterministic outcome for identical seeds")
func deterministicOutcome() throws {
    let setup = Fixtures.defaultSetup()
    let replay = BattleReplay(seed: 42, setup: setup)

    let hashA = try replay.hashOutcome(content: Fixtures.content)
    let hashB = try replay.hashOutcome(content: Fixtures.content)

    #expect(hashA == hashB)
}

@Test("Player defeats mirrored enemy stack")
func playerVictorious() throws {
    let setup = BattleSetup(
        playerPlacements: [
            UnitPlacement(
                archetypeKey: "spearman",
                lane: .mid,
                slot: 0,
                stance: .guard,
                isHero: false,
                initialHP: 120
            ),
            UnitPlacement(
                archetypeKey: "archer",
                lane: .mid,
                slot: 1,
                stance: .guard,
                isHero: false,
                initialHP: 80
            )
        ],
        enemyPlacements: [],
        playerPyre: Pyre(team: .player, hp: 200, attack: 0, attackIntervalTicks: 999),
        enemyPyre: Pyre(team: .enemy, hp: 8, attack: 0, attackIntervalTicks: 999),
        energy: 10
    )
    var config = BattleConfig()
    config.fieldLengthTiles = 4
    let simulation = try BattleSimulation(
        setup: setup,
        content: Fixtures.content,
        seed: 123,
        config: config
    )
    let outcome = simulation.simulateUntilFinished(maxTicks: 60 * 120)
    #expect(outcome == .victory)
    #expect(simulation.state.enemyPyre.hp == 0)
}

@Test("Golden replay encodes and replays")
func replayEncodingRoundTrip() throws {
    let setup = Fixtures.defaultSetup()
    let replay = BattleReplay(seed: 999, setup: setup)

    let encoder = JSONEncoder()
    let data = try encoder.encode(replay)
    let decoded = try JSONDecoder().decode(BattleReplay.self, from: data)

    let originalHash = try replay.hashOutcome(content: Fixtures.content)
    let decodedHash = try decoded.hashOutcome(content: Fixtures.content)
    #expect(originalHash == decodedHash)
}

@Test("Victory requires pyre destruction")
func victoryRequiresPyreDestruction() throws {
    let setup = BattleSetup(
        playerPlacements: [],
        enemyPlacements: [],
        playerPyre: Pyre(team: .player, hp: 200, attack: 0, attackIntervalTicks: 999),
        enemyPyre: Pyre(team: .enemy, hp: 200, attack: 0, attackIntervalTicks: 999),
        energy: 10
    )
    let simulation = try BattleSimulation(
        setup: setup,
        content: Fixtures.content,
        seed: 1
    )
    for _ in 0..<20 { simulation.step() }
    #expect(simulation.state.outcome == .inProgress)
    #expect(simulation.state.enemyPyre.hp == 200)
}

@Test("Healer restores allies within range")
func healerRestoresAlliesWithinRange() throws {
    let setup = BattleSetup(
        playerPlacements: [
            UnitPlacement(
                archetypeKey: "healer",
                lane: .mid,
                slot: 1,
                stance: .guard
            ),
            UnitPlacement(
                archetypeKey: "spearman",
                lane: .mid,
                slot: 0,
                stance: .guard,
                initialHP: 30
            )
        ],
        enemyPlacements: [],
        playerPyre: Pyre(team: .player, hp: 200, attack: 0, attackIntervalTicks: 999),
        enemyPyre: Pyre(team: .enemy, hp: 200, attack: 0, attackIntervalTicks: 999),
        energy: 10
    )

    let simulation = try BattleSimulation(
        setup: setup,
        content: Fixtures.content,
        seed: 77
    )

    guard let targetID = simulation.state.units.values.first(where: { $0.archetypeKey == "spearman" })?.id else {
        Issue.record("Missing spearman in simulation")
        return
    }
    let initialHP = simulation.state.units[targetID]?.hp ?? 0

    for _ in 0..<120 {
        simulation.step()
    }

    let healedHP = simulation.state.units[targetID]?.hp ?? 0
    #expect(healedHP > initialHP)
    if let maxHP = Fixtures.content.units["spearman"]?.maxHP {
        #expect(healedHP <= maxHP)
    }
}
