import CoreEngine
import Testing
import MetaKit
import SpriteKit
@testable import BattleRender

@Test("Placement grid produces deterministic coordinates")
func placementGridDeterminism() {
    let config = BattleSceneConfiguration()
    let grid = PlacementGrid(configuration: config, fieldLength: 30)
    let positionA = grid.position(for: .mid, slot: 1, xTile: 10)
    let positionB = grid.position(for: .mid, slot: 1, xTile: 10)
    #expect(positionA == positionB)
}

@MainActor
@Test("Battle scene syncs nodes with simulation state")
func battleSceneSync() throws {
    let catalog = ContentCatalogFactory.makeVerticalSliceCatalog()
    let setup = BattleSetup(
        playerPlacements: [
            UnitPlacement(archetypeKey: UnitKey.spearman, lane: .left, slot: 0, stance: .guard, isHero: true)
        ],
        enemyPlacements: [
            UnitPlacement(archetypeKey: UnitKey.spearman, lane: .left, slot: 0, stance: .guard)
        ],
        playerPyre: Pyre(team: .player, hp: 200, attack: 8, attackIntervalTicks: 72),
        enemyPyre: Pyre(team: .enemy, hp: 200, attack: 8, attackIntervalTicks: 72),
        energy: 10
    )

    let scene = BattleScene()
    try scene.presentBattle(setup: setup, catalog: catalog, seed: 99)
    scene.update(1.0 / 60.0)
    #expect(!scene.children.isEmpty)
}
