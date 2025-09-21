import Foundation

public final class BattleSimulation {
    public private(set) var state: BattleState
    private let content: ContentDatabase
    private let config: BattleConfig

    private let fieldLength: Int
    private var rng: RNG
    private var pendingAttacks: [(attacker: UnitID, defender: UnitID, damage: Int)] = []
    private var replayActions: [Int: [BattleReplay.Action]] = [:]

    public init(setup: BattleSetup, content: ContentDatabase, seed: UInt64, config: BattleConfig = BattleConfig()) throws {
        self.state = BattleState(setup: setup)
        self.content = content
        self.config = config
        self.fieldLength = config.fieldLengthTiles
        self.rng = RNG(seed: seed)
        try bootstrap(placements: setup.playerPlacements, team: .player)
        try bootstrap(placements: setup.enemyPlacements, team: .enemy)
        state.spellsHand = content.spells.keys.sorted()
    }

    // MARK: - Public API

    public func isComplete() -> Bool {
        state.outcome != .inProgress
    }

    @discardableResult
    public func simulateUntilFinished(maxTicks: Int = 60 * 60 * 5) -> BattleOutcome {
        while state.outcome == .inProgress && state.tick < maxTicks {
            step()
        }
        if state.outcome == .inProgress {
            // timeout: declare defeat to be safe for now
            state.outcome = .defeat
        }
        return state.outcome
    }

    public func battleHash() -> UInt64 {
        let digest = state.digest()
        var hash: UInt64 = 0
        hash = SeedFactory.mix(hash &+ UInt64(digest.tick))
        hash = SeedFactory.mix(hash ^ UInt64(bitPattern: Int64(rawOutcomeValue(digest.outcome))))
        hash = SeedFactory.mix(hash &+ UInt64(bitPattern: Int64(digest.playerPyreHP)))
        hash = SeedFactory.mix(hash ^ UInt64(bitPattern: Int64(digest.enemyPyreHP)))
        hash = SeedFactory.mix(hash &+ UInt64(digest.playerUnits))
        hash = SeedFactory.mix(hash ^ UInt64(digest.enemyUnits))
        return hash
    }

    public func performSkirmishManeuver(lane1: Lane, lane2: Lane, slot: Int = 1) -> Bool {
        // Only allow once per battle
        guard !state.skirmishManeuverUsed else { return false }
        
        // Validate lanes are adjacent
        guard abs(Int(lane1.index) - Int(lane2.index)) == 1 else { return false }
        
        // Validate slot is mid (1)
        guard slot == 1 else { return false }
        
        // Find units to swap
        var unit1: UnitInstance?
        var unit1ID: UnitID?
        var unit2: UnitInstance?
        var unit2ID: UnitID?
        
        for unitID in state.orderedUnitIDs {
            guard let unit = state.units[unitID], unit.hp > 0 else { continue }
            if unit.team == .player && unit.lane == lane1 && unit.slot == slot {
                unit1 = unit
                unit1ID = unitID
            } else if unit.team == .player && unit.lane == lane2 && unit.slot == slot {
                unit2 = unit
                unit2ID = unitID
            }
        }
        
        // Perform swap if both units exist
        if let u1 = unit1, let u1ID = unit1ID,
           let u2 = unit2, let u2ID = unit2ID {
            var swapped1 = u1
            var swapped2 = u2
            swapped1.lane = lane2
            swapped2.lane = lane1
            state.units[u1ID] = swapped1
            state.units[u2ID] = swapped2
            state.skirmishManeuverUsed = true
            return true
        }
        
        return false
    }
    
    @discardableResult
    public func cast(spellID: String, target: SpellTarget) -> Bool {
        guard state.outcome == .inProgress else { return false }
        guard state.castsRemaining > 0 else { return false }
        guard state.spellsHand.contains(spellID) else { return false }
        guard let spell = content.spells[spellID] else { return false }
        guard state.energyRemaining >= spell.cost else { return false }

        let applied = apply(spell: spell, target: target, casterTeam: .player)
        guard applied else { return false }

        state.energyRemaining -= spell.cost
        state.castsRemaining -= 1
        return true
    }

    // MARK: - Tick Loop

    public func step() {
        guard state.outcome == .inProgress else { return }
        applyReplayActionsIfNeeded()
        processStatuses()
        updateCooldowns()
        acquireTargetsAndMove()
        resolvePendingAttacks()
        performPyreAttacks()
        checkVictoryConditions()
        state.advanceTick()
    }

    // MARK: - Bootstrap

    private func bootstrap(placements: [UnitPlacement], team: Team) throws {
        for placement in placements {
            guard (0...2).contains(placement.slot) else {
                throw CoreEngineError.invalidPlacementSlot(placement.slot)
            }
            let archetype = try content.archetype(for: placement.archetypeKey)
            let startTile = startTile(for: team, slot: placement.slot)
            // Apply Phalanx Crest armor for front slot units
            let artifacts = team == .player ? state.playerArtifacts : state.enemyArtifacts
            let armor = (placement.slot == 0 && artifacts.contains("artifact.phalanxCrest")) ? 2 : 0
            
            let unit = UnitInstance(
                archetypeKey: archetype.key,
                team: team,
                lane: placement.lane,
                slot: placement.slot,
                xTile: startTile,
                hp: placement.initialHP ?? archetype.maxHP,
                attackCooldown: 0,
                stance: placement.stance,
                isHero: placement.isHero,
                isVeteran: placement.isVeteran,
                armor: armor
            )
            state.insert(unit)
        }
    }

    private func startTile(for team: Team, slot: Int) -> Int {
        switch team {
        case .player:
            return max(0, slot) // player front line near 0
        case .enemy:
            return fieldLength - 1 - slot
        }
    }

    // MARK: - Statuses & Cooldowns

    private func processStatuses() {
        for unitID in state.orderedUnitIDs {
            guard var unit = state.units[unitID], unit.hp > 0 else { continue }
            unit.statuses.removeAll { status in
                switch status {
                case let .rally(expires, _):
                    return state.tick >= expires
                case let .burn(_, expires):
                    if state.tick >= expires { return true }
                    unit.hp -= damage(for: status)
                    return false
                case let .slow(_, expires):
                    return state.tick >= expires
                }
            }
            if unit.hp <= 0 {
                state.units[unitID] = unit
                handleDeath(of: unit)
                continue
            }
            state.units[unitID] = unit
        }
        
        // Apply Achilles hero aura: +10% attack speed to adjacent allies (same slot, neighboring lanes)
        for unitID in state.orderedUnitIDs {
            guard let heroUnit = state.units[unitID],
                  heroUnit.hp > 0,
                  heroUnit.archetypeKey == "hero.achilles" else { continue }
            
            // Find adjacent allies (same slot, neighboring lanes)
            for allyID in state.orderedUnitIDs {
                guard var ally = state.units[allyID],
                      ally.hp > 0,
                      ally.team == heroUnit.team,
                      ally.id != heroUnit.id,
                      ally.slot == heroUnit.slot,
                      abs(Int(ally.lane.index) - Int(heroUnit.lane.index)) == 1 else { continue }
                
                // Apply rally effect for 1 tick (will be reapplied next tick)
                ally.statuses.append(.rally(expiresAtTick: state.tick + 1, attackSpeedModifierPct: 10))
                state.units[allyID] = ally
            }
        }
    }

    private func damage(for status: StatusEffect) -> Int {
        switch status {
        case let .burn(damage, _):
            return damage
        default:
            return 0
        }
    }

    private func updateCooldowns() {
        for unitID in state.orderedUnitIDs {
            guard var unit = state.units[unitID], unit.hp > 0 else { continue }
            if unit.attackCooldown > 0 {
                unit.attackCooldown -= 1
            }
            state.units[unitID] = unit
        }
    }

    // MARK: - Movement & Targeting

    private func acquireTargetsAndMove() {
        pendingAttacks.removeAll(keepingCapacity: true)

        for unitID in state.orderedUnitIDs {
            guard var unit = state.units[unitID], unit.hp > 0 else { continue }
            guard let archetype = content.units[unit.archetypeKey] else { continue }

            if archetype.role == .healer {
                healerAction(for: unitID, archetype: archetype)
                continue
            }

            var unitMutated = false

            if let targetID = selectTarget(for: unit) {
                guard let target = state.units[targetID], target.hp > 0 else { continue }
                let distance = abs(unit.xTile - target.xTile)
                if distance <= archetype.rangeTiles {
                    attemptAttack(attacker: unitID, unit: unit, targetID: targetID, archetype: archetype)
                } else if canMove(unit: unit, archetype: archetype) {
                    // Ranged units hold position if target is within range
                    let isRanged = archetype.rangeTiles > 1
                    if !isRanged {
                        unit.xTile += stepDirection(for: unit)
                        unit = clamp(unit: unit)
                        unitMutated = true
                    }
                }
            } else if canMove(unit: unit, archetype: archetype) {
                unit.xTile += stepDirection(for: unit)
                unit = clamp(unit: unit)
                unitMutated = true
            }

            if unitMutated {
                // Check for spike trap triggers when unit moves
                checkTrapTrigger(for: &unit)
                state.units[unitID] = unit
            }
        }
    }

    private func selectTarget(for unit: UnitInstance) -> UnitID? {
        var bestID: UnitID?
        var bestPriority: (Int, Int, String)?

        for candidate in state.units.values where candidate.team != unit.team && candidate.hp > 0 {
            let priority = targetPriority(of: candidate, relativeTo: unit)
            if bestPriority == nil || priority < bestPriority! {
                bestPriority = priority
                bestID = candidate.id
            }
        }

        return bestID
    }

    private func targetPriority(of enemy: UnitInstance, relativeTo unit: UnitInstance) -> (Int, Int, String) {
        let laneScore: Int
        if enemy.lane == unit.lane { laneScore = 0 }
        else if abs(Int(enemy.lane.index) - Int(unit.lane.index)) == 1 { laneScore = 1 }
        else { laneScore = 2 }

        let stanceBias: Int
        switch unit.stance {
        case .guard:
            stanceBias = abs(enemy.xTile - unit.xTile)
        case .skirmish:
            stanceBias = enemy.hp
        case .hunter:
            let isRangedTarget = (content.units[enemy.archetypeKey]?.rangeTiles ?? 1) > 1
            stanceBias = isRangedTarget ? 0 : 1
        }

        return (laneScore, stanceBias, enemy.id.rawValue.uuidString)
    }

    private func attemptAttack(attacker: UnitID, unit: UnitInstance, targetID: UnitID, archetype: UnitArchetype) {
        guard var attackerInstance = state.units[attacker] else { return }
        guard attackerInstance.attackCooldown == 0 else { return }

        let damage = modifiedDamage(for: attackerInstance, base: archetype.attack)
        pendingAttacks.append((attacker: attacker, defender: targetID, damage: damage))
        attackerInstance.attackCooldown = attackInterval(for: attackerInstance, base: archetype.attackIntervalTicks)
        state.units[attacker] = attackerInstance
    }

    private func modifiedDamage(for unit: UnitInstance, base: Int) -> Int {
        base
    }

    private func attackInterval(for unit: UnitInstance, base: Int) -> Int {
        var interval = base
        for status in unit.statuses {
            switch status {
            case let .rally(_, boost):
                interval = max(1, interval * max(0, 100 - boost) / 100)
            case let .slow(percent, _):
                interval = max(1, interval * (100 + percent) / 100)
            default:
                continue
            }
        }
        return max(1, interval)
    }

    private func stepDirection(for unit: UnitInstance) -> Int {
        switch unit.team {
        case .player: return 1
        case .enemy: return -1
        }
    }

    private func clamp(unit: UnitInstance) -> UnitInstance {
        var copy = unit
        copy.xTile = max(0, min(fieldLength, copy.xTile))
        return copy
    }

    private func canMove(unit: UnitInstance, archetype: UnitArchetype) -> Bool {
        guard archetype.speedTilesPerSecond > 0 else { return false }
        let moveInterval = max(1, config.tickRate / archetype.speedTilesPerSecond)
        return state.tick % moveInterval == 0
    }

    private func checkTrapTrigger(for unit: inout UnitInstance) {
        // Check if unit is entering enemy trap zone for the first time
        let opposingTeam = unit.team == .player ? Team.enemy : Team.player
        
        // Check if trap has already been triggered for this lane
        if state.trapTriggered[opposingTeam]?[unit.lane] == true { return }
        
        // Check if there's a trap in this lane (initialized in BattleState.init)
        guard state.trapTriggered[opposingTeam]?[unit.lane] == false else { return }
        
        // Determine if unit has entered the trap zone (first third of enemy field)
        let enteringZone: Bool
        if unit.team == .player {
            // Player units moving right, enemy traps trigger in right third
            enteringZone = unit.xTile >= (fieldLength * 2 / 3)
        } else {
            // Enemy units moving left, player traps trigger in left third
            enteringZone = unit.xTile <= (fieldLength / 3)
        }
        
        if enteringZone {
            // Apply spike damage
            unit.hp = max(0, unit.hp - 6)
            
            // Mark trap as triggered
            state.trapTriggered[opposingTeam]?[unit.lane] = true
            
            if unit.hp <= 0 {
                handleDeath(of: unit)
            }
        }
    }

    // MARK: - Damage Resolution

    private func resolvePendingAttacks() {
        guard !pendingAttacks.isEmpty else { return }
        for attack in pendingAttacks {
            guard var defender = state.units[attack.defender], defender.hp > 0 else { continue }
            
            // Track attacker for Lyre of Apollo
            state.lastAttacker[attack.defender] = attack.attacker
            
            // Apply armor reduction
            let damageAfterArmor = max(0, attack.damage - defender.armor)
            defender.hp -= damageAfterArmor
            state.units[attack.defender] = defender
            
            if defender.hp <= 0 {
                handleDeath(of: defender)
            }
        }
        pendingAttacks.removeAll(keepingCapacity: true)
    }

    private func handleDeath(of unit: UnitInstance) {
        // Check for Lyre of Apollo on-kill heal
        if let attackerID = state.lastAttacker[unit.id],
           let attacker = state.units[attackerID] {
            let artifacts = attacker.team == .player ? state.playerArtifacts : state.enemyArtifacts
            if artifacts.contains("artifact.lyreOfApollo") {
                // Find most wounded ally in the same lane as the attacker
                var mostWoundedID: UnitID?
                var lowestHPRatio: Double = 1.0
                
                for allyID in state.orderedUnitIDs {
                    guard let ally = state.units[allyID],
                          ally.team == attacker.team,
                          ally.lane == attacker.lane,
                          ally.hp > 0,
                          let archetype = content.units[ally.archetypeKey] else { continue }
                    
                    let hpRatio = Double(ally.hp) / Double(archetype.maxHP)
                    if hpRatio < lowestHPRatio {
                        lowestHPRatio = hpRatio
                        mostWoundedID = allyID
                    }
                }
                
                // Heal the most wounded ally by 5
                if let targetID = mostWoundedID,
                   var target = state.units[targetID],
                   let archetype = content.units[target.archetypeKey] {
                    target.hp = min(target.hp + 5, archetype.maxHP)
                    state.units[targetID] = target
                }
            }
        }
        
        state.remove(unitID: unit.id)
        if unit.team == .player {
            if unit.isHero {
                state.outcome = .defeat
            }
        } else {
            if unit.isHero {
                state.outcome = .victory
            }
        }
    }

    // MARK: - Pyre Phase

    private func performPyreAttacks() {
        performPyreAttack(forTeam: .player, targetTeam: .enemy)
        performPyreAttack(forTeam: .enemy, targetTeam: .player)
        advanceStacksTowardPyre(for: .player)
        advanceStacksTowardPyre(for: .enemy)
    }

    private func performPyreAttack(forTeam team: Team, targetTeam: Team) {
        switch team {
        case .player:
            state.playerPyre = updated(pyre: state.playerPyre, against: targetTeam)
        case .enemy:
            state.enemyPyre = updated(pyre: state.enemyPyre, against: targetTeam)
        }
    }

    private func updated(pyre: Pyre, against targetTeam: Team) -> Pyre {
        var copy = pyre
        if copy.cooldown > 0 {
            copy.cooldown -= 1
        }
        guard copy.cooldown == 0 else { return copy }
        if var target = frontUnit(for: targetTeam) {
            // Pyre inner-third rule: only shoot if target is in the middle third of the field
            let innerThirdStart = fieldLength / 3
            let innerThirdEnd = fieldLength * 2 / 3
            let targetInInnerThird = target.xTile >= innerThirdStart && target.xTile <= innerThirdEnd
            
            if targetInInnerThird {
                target.hp -= copy.attack
                state.units[target.id] = target
                if target.hp <= 0 {
                    handleDeath(of: target)
                }
                copy.cooldown = copy.attackIntervalTicks
            }
        }
        return copy
    }

    private func advanceStacksTowardPyre(for team: Team) {
        for unitID in state.orderedUnitIDs {
            guard let unit = state.units[unitID], unit.team == team, unit.hp > 0 else { continue }
            if (team == .player && unit.xTile >= fieldLength) || (team == .enemy && unit.xTile <= 0) {
                applyDamage(toPyreOf: opposingTeam(for: team), amount: unitDamageValue(unit))
                handleDeath(of: unit)
            }
        }
    }

    private func opposingTeam(for team: Team) -> Team {
        team == .player ? .enemy : .player
    }

    private func unitDamageValue(_ unit: UnitInstance) -> Int {
        content.units[unit.archetypeKey]?.attack ?? 0
    }

    private func applyDamage(toPyreOf team: Team, amount: Int) {
        guard amount > 0 else { return }
        if team == .player {
            state.playerPyre.hp -= amount
            if state.playerPyre.hp <= 0 {
                state.playerPyre.hp = 0
                state.outcome = .defeat
            }
        } else {
            state.enemyPyre.hp -= amount
            if state.enemyPyre.hp <= 0 {
                state.enemyPyre.hp = 0
                state.outcome = .victory
            }
        }
    }

    private func frontUnit(for team: Team) -> UnitInstance? {
        var best: UnitInstance?

        for candidate in state.units.values where candidate.team == team && candidate.hp > 0 {
            guard let currentBest = best else {
                best = candidate
                continue
            }

            let shouldReplace = team == .player
                ? candidate.xTile < currentBest.xTile
                : candidate.xTile > currentBest.xTile

            if shouldReplace {
                best = candidate
            }
        }

        return best
    }

    private func checkVictoryConditions() {
        guard state.outcome == .inProgress else { return }
        if state.playerPyre.hp <= 0 {
            state.outcome = .defeat
            return
        }
        if state.enemyPyre.hp <= 0 {
            state.outcome = .victory
        }
    }
}

// MARK: - Spells & Replay Actions

extension BattleSimulation {
    func registerReplayActions(_ actions: [BattleReplay.Action]) {
        replayActions = Dictionary(grouping: actions, by: { $0.tick })
    }
}

private extension BattleSimulation {
    func applyReplayActionsIfNeeded() {
        guard let actions = replayActions[state.tick] else { return }
        defer { replayActions[state.tick] = nil }

        for action in actions {
            switch action.kind {
            case .cast:
                guard content.spells[action.identifier] != nil else { continue }
                let target: SpellTarget
                if let lane = action.lane, let x = action.xTile {
                    target = .lanePoint(lane: lane, xTile: x)
                } else if let anchor = defaultAnchor(for: action.identifier) {
                    target = anchor
                } else {
                    continue
                }
                _ = cast(spellID: action.identifier, target: target)
            }
        }
    }

    func defaultAnchor(for spellID: String) -> SpellTarget? {
        // Fallback for replays missing explicit lane/x. Use mid lane at player front.
        guard content.spells[spellID] != nil else { return nil }
        return .lanePoint(lane: .mid, xTile: 0)
    }

    func apply(spell: SpellArchetype, target: SpellTarget, casterTeam: Team) -> Bool {
        switch spell.effect {
        case let .heal(amount, radius):
            return applyHeal(amount: amount, radius: radius, target: target, team: casterTeam)
        case let .fireball(damage, radius):
            return applyFireball(damage: damage, radius: radius, target: target, casterTeam: casterTeam)
        case let .rally(percent, duration):
            return applyRally(percent: percent, duration: duration, target: target, team: casterTeam)
        }
    }

    func applyHeal(amount: Int, radius: Int?, target: SpellTarget, team: Team) -> Bool {
        guard let anchor = targetAnchor(for: target) else { return false }
        let maxDistance = radius ?? 0
        let allies = state.units.values.filter {
            $0.team == team && $0.hp > 0 && abs($0.xTile - anchor.xTile) <= maxDistance && abs(Int($0.lane.index) - Int(anchor.lane.index)) <= 0
        }

        let wounded = allies.compactMap { unit -> UnitInstance? in
            guard let maxHP = maxHP(for: unit), unit.hp < maxHP else { return nil }
            return unit
        }

        guard !wounded.isEmpty else { return false }

        let sorted = wounded.sorted { healPriority(for: $0, anchor: anchor) < healPriority(for: $1, anchor: anchor) }

        if radius == nil {
            guard var best = sorted.first, let maxHP = maxHP(for: best) else { return false }
            best.hp = min(maxHP, best.hp + amount)
            state.units[best.id] = best
            return true
        }

        var applied = false
        for var ally in sorted {
            guard let maxHP = maxHP(for: ally) else { continue }
            if ally.hp < maxHP {
                ally.hp = min(maxHP, ally.hp + amount)
                state.units[ally.id] = ally
                applied = true
            }
        }

        return applied
    }

    func applyFireball(damage: Int, radius: Int, target: SpellTarget, casterTeam: Team) -> Bool {
        guard let anchor = targetAnchor(for: target) else { return false }
        let enemyTeam = opposingTeam(for: casterTeam)
        let enemies = state.units.values.filter {
            $0.team == enemyTeam && $0.hp > 0 && $0.lane == anchor.lane && abs($0.xTile - anchor.xTile) <= radius
        }

        guard !enemies.isEmpty else { return false }

        let sorted = enemies.sorted { fireballPriority(for: $0, anchor: anchor) < fireballPriority(for: $1, anchor: anchor) }

        for var enemy in sorted {
            enemy.hp -= damage
            state.units[enemy.id] = enemy
            if enemy.hp <= 0 {
                handleDeath(of: enemy)
            }
        }

        return true
    }

    func applyRally(percent: Int, duration: Int, target: SpellTarget, team: Team) -> Bool {
        guard let anchor = targetAnchor(for: target) else { return false }
        let allies = state.units.values.filter {
            $0.team == team && $0.hp > 0 && $0.lane == anchor.lane && abs($0.xTile - anchor.xTile) <= 0
        }

        guard !allies.isEmpty else { return false }

        let expires = state.tick + duration
        var applied = false
        let sorted = allies.sorted { healPriority(for: $0, anchor: anchor) < healPriority(for: $1, anchor: anchor) }
        for var ally in sorted {
            ally.statuses.append(.rally(expiresAtTick: expires, attackSpeedModifierPct: percent))
            state.units[ally.id] = ally
            applied = true
        }
        return applied
    }

    func targetAnchor(for target: SpellTarget) -> (lane: Lane, xTile: Int)? {
        switch target {
        case let .unit(id):
            guard let unit = state.units[id] else { return nil }
            return (unit.lane, unit.xTile)
        case let .lanePoint(lane, xTile):
            return (lane, xTile)
        }
    }

    func healPriority(for unit: UnitInstance, anchor: (lane: Lane, xTile: Int)) -> (Int, Int, String) {
        let lanePenalty = abs(Int(unit.lane.index) - Int(anchor.lane.index))
        let distance = abs(unit.xTile - anchor.xTile)
        return (lanePenalty, distance, unit.id.rawValue.uuidString)
    }

    func fireballPriority(for unit: UnitInstance, anchor: (lane: Lane, xTile: Int)) -> (Int, Int, String) {
        let distance = abs(unit.xTile - anchor.xTile)
        return (distance, unit.slot, unit.id.rawValue.uuidString)
    }
}

private extension BattleSimulation {
    func rawOutcomeValue(_ outcome: BattleOutcome) -> Int {
        switch outcome {
        case .inProgress: return 0
        case .victory: return 1
        case .defeat: return 2
        }
    }
}

// MARK: - Healer support

private extension BattleSimulation {
    func healerAction(for unitID: UnitID, archetype: UnitArchetype) {
        guard var healer = state.units[unitID] else { return }

        if let targetID = selectHealTarget(for: healer, range: archetype.rangeTiles),
           var target = state.units[targetID],
           let maxHP = maxHP(for: target),
           target.hp < maxHP {
            if healer.attackCooldown == 0 {
                let amount = healAmount(for: archetype)
                target.hp = min(maxHP, target.hp + amount)
                state.units[targetID] = target
                healer.attackCooldown = max(1, archetype.attackIntervalTicks)
            }
            state.units[unitID] = healer
            return
        }

        if canMove(unit: healer, archetype: archetype) {
            healer.xTile += stepDirection(for: healer)
            healer = clamp(unit: healer)
        }

        state.units[unitID] = healer
    }

    func selectHealTarget(for unit: UnitInstance, range: Int) -> UnitID? {
        var bestID: UnitID?
        var bestPriority: (Int, Int, String)?

        for ally in state.units.values {
            guard ally.team == unit.team, ally.id != unit.id, ally.hp > 0,
                  let maxHP = maxHP(for: ally), ally.hp < maxHP else { continue }
            let distance = abs(unit.xTile - ally.xTile)
            guard distance <= range else { continue }
            let lanePenalty = abs(Int(ally.lane.index) - Int(unit.lane.index))
            let priority = (lanePenalty, ally.hp, ally.id.rawValue.uuidString)
            if bestPriority == nil || priority < bestPriority! {
                bestPriority = priority
                bestID = ally.id
            }
        }

        return bestID
    }

    func maxHP(for unit: UnitInstance) -> Int? {
        content.units[unit.archetypeKey]?.maxHP
    }

    func healAmount(for archetype: UnitArchetype) -> Int {
        max(4, archetype.attackIntervalTicks / 8)
    }
}
