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
                    isHero: true
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
            playerPyre: Pyre(team: .player, hp: 200, attack: 8, attackIntervalTicks: 72),
            enemyPyre: Pyre(team: .enemy, hp: 200, attack: 8, attackIntervalTicks: 72),
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
    let setup = Fixtures.defaultSetup()
    let simulation = try BattleSimulation(
        setup: setup,
        content: Fixtures.content,
        seed: 123
    )
    let outcome = simulation.simulateUntilFinished(maxTicks: 60 * 120)
    #expect(outcome == .victory)
    #expect(simulation.state.enemyPyre.hp >= 0)
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
