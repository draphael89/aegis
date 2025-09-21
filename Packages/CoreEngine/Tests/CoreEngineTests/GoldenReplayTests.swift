import Foundation
import Testing
@testable import CoreEngine

private enum GoldenFixtures {
    static func loadReplay(named name: String) throws -> BattleReplay {
        let baseURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../Fixtures/Replays", isDirectory: true)
            .standardizedFileURL
        let url = baseURL.appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(BattleReplay.self, from: data)
    }

    static func baselineContent() -> ContentDatabase {
        let units: [UnitArchetype] = [
            UnitArchetype(
                key: "spearman",
                role: .melee,
                maxHP: 60,
                attack: 8,
                attackIntervalTicks: 60,
                rangeTiles: 1,
                speedTilesPerSecond: 2,
                cost: 2
            ),
            UnitArchetype(
                key: "archer",
                role: .ranged,
                maxHP: 40,
                attack: 7,
                attackIntervalTicks: 60,
                rangeTiles: 4,
                speedTilesPerSecond: 2,
                cost: 3
            ),
            UnitArchetype(
                key: "healer",
                role: .healer,
                maxHP: 45,
                attack: 0,
                attackIntervalTicks: 45,
                rangeTiles: 4,
                speedTilesPerSecond: 2,
                cost: 3
            )
        ]
        let spells: [SpellArchetype] = [
            SpellArchetype(key: "heal", cost: 2, effect: .heal(amount: 25, radius: nil)),
            SpellArchetype(key: "fireball", cost: 3, effect: .fireball(damage: 60, radius: 1))
        ]
        return ContentDatabase(units: units, spells: spells)
    }
}

@Test("Golden replay – pyre push encounter")
func goldenReplayPyrePush() throws {
    let replay = try GoldenFixtures.loadReplay(named: "push")
    let content = GoldenFixtures.baselineContent()
    let hash = try replay.hashOutcome(content: content)
    #expect(hash == 0x79434B6DE019C8BC)
}

@Test("Golden replay – baseline encounter")
func goldenReplayBaseline() throws {
    let replay = try GoldenFixtures.loadReplay(named: "baseline")
    let content = GoldenFixtures.baselineContent()
    let reference = BattleReplay(
        seed: 11029837421286059893,
        setup: BattleSetup(
            playerPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard, isHero: true),
                UnitPlacement(archetypeKey: "archer", lane: .left, slot: 1, stance: .hunter),
                UnitPlacement(archetypeKey: "healer", lane: .right, slot: 2, stance: .skirmish)
            ],
            enemyPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard),
                UnitPlacement(archetypeKey: "archer", lane: .left, slot: 1, stance: .guard),
                UnitPlacement(archetypeKey: "healer", lane: .right, slot: 2, stance: .skirmish)
            ],
            playerPyre: Pyre(team: .player, hp: 200, attack: 8, attackIntervalTicks: 72),
            enemyPyre: Pyre(team: .enemy, hp: 200, attack: 8, attackIntervalTicks: 72),
            energy: 10
        )
    )
    #expect(replay.seed == reference.seed)
    #expect(replay.setup == reference.setup)
    let hash = try replay.hashOutcome(content: content)
    #expect(hash == 16706351794060325347) // Updated for Swift 6.0 and M1 features
}

@Test("Golden replay – baseline encounter with spell casts")
func goldenReplayBaselineWithCasts() throws {
    let replay = try GoldenFixtures.loadReplay(named: "baseline_casts")
    let content = GoldenFixtures.baselineContent()
    let hash = try replay.hashOutcome(content: content)
    #expect(hash == 3971531962232489497) // Updated for Swift 6.0 and M1 features
}
