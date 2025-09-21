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
                isVeteran: placement.isVeteran
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
                    unit.xTile += stepDirection(for: unit)
                    unit = clamp(unit: unit)
                    unitMutated = true
                }
            } else if canMove(unit: unit, archetype: archetype) {
                unit.xTile += stepDirection(for: unit)
                unit = clamp(unit: unit)
                unitMutated = true
            }

            if unitMutated {
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

    // MARK: - Damage Resolution

    private func resolvePendingAttacks() {
        guard !pendingAttacks.isEmpty else { return }
        for attack in pendingAttacks {
            guard var defender = state.units[attack.defender], defender.hp > 0 else { continue }
            defender.hp -= attack.damage
            state.units[attack.defender] = defender
            if defender.hp <= 0 {
                handleDeath(of: defender)
            }
        }
        pendingAttacks.removeAll(keepingCapacity: true)
    }

    private func handleDeath(of unit: UnitInstance) {
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
            target.hp -= copy.attack
            state.units[target.id] = target
            if target.hp <= 0 {
                handleDeath(of: target)
            }
            copy.cooldown = copy.attackIntervalTicks
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
