import Foundation

public final class BattleSimulation {
    public private(set) var state: BattleState
    private let content: ContentDatabase
    private let config: BattleConfig

    private let fieldLength: Int
    private var rng: RNG
    private var pendingAttacks: [(attacker: UnitID, defender: UnitID, damage: Int)] = []

    public init(setup: BattleSetup, content: ContentDatabase, seed: UInt64, config: BattleConfig = BattleConfig()) throws {
        self.state = BattleState(setup: setup)
        self.content = content
        self.config = config
        self.fieldLength = config.fieldLengthTiles
        self.rng = RNG(seed: seed)
        try bootstrap(placements: setup.playerPlacements, team: .player)
        try bootstrap(placements: setup.enemyPlacements, team: .enemy)
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
        var hasher = Hasher()
        let digest = state.digest()
        hasher.combine(digest.tick)
        hasher.combine(digest.outcome == .victory)
        hasher.combine(digest.playerPyreHP)
        hasher.combine(digest.enemyPyreHP)
        hasher.combine(digest.playerUnits)
        hasher.combine(digest.enemyUnits)
        let value = hasher.finalize()
        return UInt64(bitPattern: Int64(value))
    }

    // MARK: - Tick Loop

    public func step() {
        guard state.outcome == .inProgress else { return }
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
        var updatedUnits: [UnitID: UnitInstance] = state.units
        pendingAttacks.removeAll(keepingCapacity: true)

        for unitID in state.orderedUnitIDs {
            guard var unit = state.units[unitID], unit.hp > 0 else { continue }
            guard let archetype = content.units[unit.archetypeKey] else { continue }

            if let targetID = selectTarget(for: unit) {
                guard let target = state.units[targetID], target.hp > 0 else { continue }
                let distance = abs(unit.xTile - target.xTile)
                if distance <= archetype.rangeTiles {
                    attemptAttack(attacker: unitID, unit: unit, targetID: targetID, archetype: archetype)
                } else if canMove(unit: unit, archetype: archetype) {
                    unit.xTile += stepDirection(for: unit)
                    unit = clamp(unit: unit)
                }
            } else {
                if canMove(unit: unit, archetype: archetype) {
                    unit.xTile += stepDirection(for: unit)
                    unit = clamp(unit: unit)
                }
            }
            updatedUnits[unitID] = unit
        }

        state.units = updatedUnits
    }

    private func selectTarget(for unit: UnitInstance) -> UnitID? {
        let enemies = state.units.values.filter { $0.team != unit.team && $0.hp > 0 }
        guard !enemies.isEmpty else { return nil }

        let sorted = enemies.sorted { lhs, rhs in
            targetPriority(of: lhs, relativeTo: unit) < targetPriority(of: rhs, relativeTo: unit)
        }
        return sorted.first?.id
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
        attackerInstance.attackCooldown = max(1, archetype.attackIntervalTicks)
        state.units[attacker] = attackerInstance
    }

    private func modifiedDamage(for unit: UnitInstance, base: Int) -> Int {
        var result = base
        for status in unit.statuses {
            switch status {
            case let .rally(_, boost):
                result += (result * boost) / 100
            default:
                continue
            }
        }
        return max(0, result)
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
        let comparison: (UnitInstance, UnitInstance) -> Bool = team == .player
            ? { lhs, rhs in lhs.xTile < rhs.xTile }
            : { lhs, rhs in lhs.xTile > rhs.xTile }
        return state.units.values
            .filter { $0.team == team && $0.hp > 0 }
            .sorted(by: comparison)
            .first
    }

    private func checkVictoryConditions() {
        guard state.outcome == .inProgress else { return }
        let playerAlive = state.units.values.contains { $0.team == .player && $0.hp > 0 }
        let enemyAlive = state.units.values.contains { $0.team == .enemy && $0.hp > 0 }
        if !playerAlive {
            state.outcome = .defeat
        } else if !enemyAlive {
            state.outcome = .victory
        }
    }
}
