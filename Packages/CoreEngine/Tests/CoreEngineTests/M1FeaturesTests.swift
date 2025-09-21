import Testing
@testable import CoreEngine
import Foundation

struct M1FeaturesTests {
    
    // MARK: - Test Helpers
    
    private func makeTestContent() -> ContentDatabase {
        ContentDatabase(
            units: [
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
                    key: "hero.achilles",
                    role: .melee,
                    maxHP: 200,
                    attack: 12,
                    attackIntervalTicks: 60,
                    rangeTiles: 1,
                    speedTilesPerSecond: 2,
                    cost: 0
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
        )
    }
    
    // MARK: - Ranged Hold Behavior Tests
    
    @Test("Ranged units hold position when target is within range")
    func rangedHoldBehavior() throws {
        let content = makeTestContent()
        let setup = BattleSetup(
            playerPlacements: [
                UnitPlacement(archetypeKey: "archer", lane: .mid, slot: 1, stance: .guard)
            ],
            enemyPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard)
            ],
            playerPyre: Pyre(team: .player, hp: 100, attack: 5, attackIntervalTicks: 60),
            enemyPyre: Pyre(team: .enemy, hp: 100, attack: 5, attackIntervalTicks: 60),
            energy: 10
        )
        
        let sim = try BattleSimulation(setup: setup, content: content, seed: 42)
        
        // Get initial positions
        let initialArcherX = sim.state.units.values.first(where: { $0.archetypeKey == "archer" })?.xTile ?? -1
        
        // Advance simulation
        for _ in 0..<30 {
            sim.step()
        }
        
        // Archer should not have moved closer since enemy is within range (4 tiles)
        let finalArcherX = sim.state.units.values.first(where: { $0.archetypeKey == "archer" })?.xTile ?? -1
        #expect(finalArcherX == initialArcherX, "Ranged unit should hold position when target is in range")
    }
    
    // MARK: - Pyre Inner-Third Rule Tests
    
    @Test("Pyres only shoot when enemies are in inner third of field")
    func pyreInnerThirdRule() throws {
        let content = makeTestContent()
        let fieldLength = 30
        let innerThirdStart = fieldLength / 3  // 10
        let innerThirdEnd = fieldLength * 2 / 3  // 20
        
        // Place unit outside inner third initially
        let setup = BattleSetup(
            playerPlacements: [],
            enemyPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard)
            ],
            playerPyre: Pyre(team: .player, hp: 100, attack: 10, attackIntervalTicks: 60),
            enemyPyre: Pyre(team: .enemy, hp: 100, attack: 10, attackIntervalTicks: 60),
            energy: 10
        )
        
        let sim = try BattleSimulation(setup: setup, content: content, seed: 42)
        
        // Enemy starts at position 29 (fieldLength - 1)
        let enemy = sim.state.units.values.first(where: { $0.team == .enemy })
        #expect(enemy != nil)
        
        // Run simulation until enemy moves into inner third
        var enemyHitByPyre = false
        for _ in 0..<300 {
            sim.step()
            if let enemy = sim.state.units.values.first(where: { $0.team == .enemy }) {
                if enemy.hp < 60 {  // Enemy took damage from pyre
                    enemyHitByPyre = true
                    // Verify enemy is in inner third
                    #expect(enemy.xTile >= innerThirdStart && enemy.xTile <= innerThirdEnd,
                           "Pyre should only damage enemies in inner third")
                    break
                }
            }
        }
        
        #expect(enemyHitByPyre, "Pyre should eventually hit enemy when in inner third")
    }
    
    // MARK: - Achilles Hero Aura Tests
    
    @Test("Achilles provides +10% attack speed aura to adjacent allies")
    func achillesHeroAura() throws {
        let content = makeTestContent()
        let setup = BattleSetup(
            playerPlacements: [
                UnitPlacement(archetypeKey: "hero.achilles", lane: .mid, slot: 1, stance: .guard, isHero: true),
                UnitPlacement(archetypeKey: "spearman", lane: .left, slot: 1, stance: .guard),  // Adjacent
                UnitPlacement(archetypeKey: "spearman", lane: .right, slot: 1, stance: .guard), // Adjacent
                UnitPlacement(archetypeKey: "spearman", lane: .left, slot: 0, stance: .guard)   // Not adjacent (different slot)
            ],
            enemyPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard)
            ],
            playerPyre: Pyre(team: .player, hp: 100, attack: 5, attackIntervalTicks: 60),
            enemyPyre: Pyre(team: .enemy, hp: 100, attack: 5, attackIntervalTicks: 60),
            energy: 10
        )
        
        let sim = try BattleSimulation(setup: setup, content: content, seed: 42)
        
        // Step once to apply auras
        sim.step()
        
        // Check adjacent allies have rally status
        let adjacentLeft = sim.state.units.values.first(where: { 
            $0.archetypeKey == "spearman" && $0.lane == .left && $0.slot == 1 
        })
        let adjacentRight = sim.state.units.values.first(where: { 
            $0.archetypeKey == "spearman" && $0.lane == .right && $0.slot == 1 
        })
        let nonAdjacent = sim.state.units.values.first(where: { 
            $0.archetypeKey == "spearman" && $0.lane == .left && $0.slot == 0 
        })
        
        #expect(adjacentLeft?.statuses.contains(where: { 
            if case .rally = $0 { return true }
            return false
        }) == true, "Adjacent ally (left) should have rally status")
        
        #expect(adjacentRight?.statuses.contains(where: { 
            if case .rally = $0 { return true }
            return false
        }) == true, "Adjacent ally (right) should have rally status")
        
        #expect(nonAdjacent?.statuses.contains(where: { 
            if case .rally = $0 { return true }
            return false
        }) == false, "Non-adjacent ally should not have rally status")
    }
    
    // MARK: - Phalanx Crest Artifact Tests
    
    @Test("Phalanx Crest provides armor to front slot units")
    func phalanxCrestArmor() throws {
        let content = makeTestContent()
        let setup = BattleSetup(
            playerPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard),  // Front slot
                UnitPlacement(archetypeKey: "spearman", lane: .left, slot: 1, stance: .guard)  // Mid slot
            ],
            enemyPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard)
            ],
            playerPyre: Pyre(team: .player, hp: 100, attack: 5, attackIntervalTicks: 60),
            enemyPyre: Pyre(team: .enemy, hp: 100, attack: 5, attackIntervalTicks: 60),
            energy: 10,
            playerArtifacts: ["artifact.phalanxCrest"]
        )
        
        let sim = try BattleSimulation(setup: setup, content: content, seed: 42)
        
        // Check that front slot unit has armor
        let frontUnit = sim.state.units.values.first(where: { 
            $0.team == .player && $0.slot == 0 
        })
        let midUnit = sim.state.units.values.first(where: { 
            $0.team == .player && $0.slot == 1 
        })
        
        #expect(frontUnit?.armor == 2, "Front slot unit should have 2 armor from Phalanx Crest")
        #expect(midUnit?.armor == 0, "Mid slot unit should have no armor")
    }
    
    // MARK: - Lyre of Apollo Artifact Tests
    
    @Test("Lyre of Apollo heals most wounded ally on kill")
    func lyreOfApolloHeal() throws {
        let content = makeTestContent()
        let setup = BattleSetup(
            playerPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard),
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 1, stance: .guard, initialHP: 25)  // Wounded
            ],
            enemyPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard, initialHP: 1)  // Very low HP for guaranteed first-hit kill
            ],
            playerPyre: Pyre(team: .player, hp: 100, attack: 5, attackIntervalTicks: 60),
            enemyPyre: Pyre(team: .enemy, hp: 100, attack: 5, attackIntervalTicks: 60),
            energy: 10,
            playerArtifacts: ["artifact.lyreOfApollo"]
        )
        
        let sim = try BattleSimulation(setup: setup, content: content, seed: 42)
        
        // Get initial HP of wounded ally
        let woundedAllyID = sim.state.units.values.first(where: {
            $0.team == .player && $0.slot == 1
        })?.id
        let woundedInitialHP = 25
        
        // Run simulation until enemy dies (should be very quick with 1 HP enemy)
        var enemyDied = false
        for i in 0..<120 {
            sim.step()
            if sim.state.units.values.first(where: { $0.team == .enemy }) == nil {
                enemyDied = true
                break  // Enemy died
            }
        }
        
        #expect(enemyDied, "Enemy should have died during simulation")
        
        // Check that wounded ally was healed
        if let allyID = woundedAllyID,
           let woundedAlly = sim.state.units[allyID] {
            #expect(woundedAlly.hp > woundedInitialHP, "Wounded ally should be healed after kill with Lyre of Apollo. Current HP: \(woundedAlly.hp), Initial: \(woundedInitialHP)")
        } else {
            Issue.record("Wounded ally not found after battle")
        }
    }
    
    // MARK: - Spikes Trap Tests
    
    @Test("Spikes trap damages first enemy entering lane")
    func spikesTrapDamage() throws {
        let content = makeTestContent()
        let setup = BattleSetup(
            playerPlacements: [],
            enemyPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .mid, slot: 0, stance: .guard)
            ],
            playerPyre: Pyre(team: .player, hp: 100, attack: 5, attackIntervalTicks: 60),
            enemyPyre: Pyre(team: .enemy, hp: 100, attack: 5, attackIntervalTicks: 60),
            energy: 10,
            playerArtifacts: ["trap.spikes"],
            playerTraps: [.mid: "trap.spikes"]
        )
        
        let sim = try BattleSimulation(setup: setup, content: content, seed: 42)
        
        // Enemy starts with 60 HP
        let initialHP = 60
        
        // Run simulation until enemy enters trap zone (left third of field)
        var trapTriggered = false
        for _ in 0..<200 {
            sim.step()
            if let enemy = sim.state.units.values.first(where: { $0.team == .enemy }) {
                if enemy.hp < initialHP {
                    // Enemy took damage - should be exactly 6 from spike trap
                    #expect(initialHP - enemy.hp >= 6, "Spike trap should deal at least 6 damage")
                    trapTriggered = true
                    break
                }
            }
        }
        
        #expect(trapTriggered, "Spike trap should trigger when enemy enters zone")
    }
    
    // MARK: - Skirmish Maneuver Tests
    
    @Test("Skirmish Maneuver swaps adjacent mid slot units")
    func skirmishManeuverSwap() throws {
        let content = makeTestContent()
        let setup = BattleSetup(
            playerPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .left, slot: 1, stance: .guard),
                UnitPlacement(archetypeKey: "archer", lane: .mid, slot: 1, stance: .guard)
            ],
            enemyPlacements: [],
            playerPyre: Pyre(team: .player, hp: 100, attack: 5, attackIntervalTicks: 60),
            enemyPyre: Pyre(team: .enemy, hp: 100, attack: 5, attackIntervalTicks: 60),
            energy: 10
        )
        
        let sim = try BattleSimulation(setup: setup, content: content, seed: 42)
        
        // Verify initial positions
        let spearmanBefore = sim.state.units.values.first(where: { $0.archetypeKey == "spearman" })
        let archerBefore = sim.state.units.values.first(where: { $0.archetypeKey == "archer" })
        
        #expect(spearmanBefore?.lane == .left)
        #expect(archerBefore?.lane == .mid)
        
        // Perform skirmish maneuver
        let success = sim.performSkirmishManeuver(lane1: .left, lane2: .mid, slot: 1)
        #expect(success, "Skirmish maneuver should succeed")
        
        // Verify units swapped lanes
        let spearmanAfter = sim.state.units.values.first(where: { $0.archetypeKey == "spearman" })
        let archerAfter = sim.state.units.values.first(where: { $0.archetypeKey == "archer" })
        
        #expect(spearmanAfter?.lane == .mid, "Spearman should be in mid lane after swap")
        #expect(archerAfter?.lane == .left, "Archer should be in left lane after swap")
        
        // Try to use maneuver again - should fail
        let secondAttempt = sim.performSkirmishManeuver(lane1: .mid, lane2: .right, slot: 1)
        #expect(!secondAttempt, "Skirmish maneuver should only work once per battle")
    }
    
    @Test("Skirmish Maneuver validates adjacent lanes and mid slot")
    func skirmishManeuverValidation() throws {
        let content = makeTestContent()
        let setup = BattleSetup(
            playerPlacements: [
                UnitPlacement(archetypeKey: "spearman", lane: .left, slot: 1, stance: .guard),
                UnitPlacement(archetypeKey: "archer", lane: .right, slot: 1, stance: .guard)
            ],
            enemyPlacements: [],
            playerPyre: Pyre(team: .player, hp: 100, attack: 5, attackIntervalTicks: 60),
            enemyPyre: Pyre(team: .enemy, hp: 100, attack: 5, attackIntervalTicks: 60),
            energy: 10
        )
        
        let sim = try BattleSimulation(setup: setup, content: content, seed: 42)
        
        // Try to swap non-adjacent lanes - should fail
        let nonAdjacentSwap = sim.performSkirmishManeuver(lane1: .left, lane2: .right, slot: 1)
        #expect(!nonAdjacentSwap, "Cannot swap non-adjacent lanes")
        
        // Try to swap front slot - should fail
        let frontSlotSwap = sim.performSkirmishManeuver(lane1: .left, lane2: .mid, slot: 0)
        #expect(!frontSlotSwap, "Can only swap mid slot units")
        
        // Try to swap back slot - should fail
        let backSlotSwap = sim.performSkirmishManeuver(lane1: .left, lane2: .mid, slot: 2)
        #expect(!backSlotSwap, "Can only swap mid slot units")
    }
}