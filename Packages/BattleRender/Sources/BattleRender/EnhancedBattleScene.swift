import CoreEngine
import Foundation
import MetaKit
import SpriteKit

@MainActor
public final class EnhancedBattleScene: SKScene {
    public weak var battleDelegate: BattleSceneDelegate?
    
    private let configuration: BattleSceneConfiguration
    private var placementGrid: PlacementGrid
    private var simulation: BattleSimulation?
    private var content: ContentCatalog?
    private var unitIndex: [String: UnitArchetype] = [:]
    private var lastKnownHP: [UnitID: Int] = [:]
    
    private var accumulator: TimeInterval = 0
    private var previousTime: TimeInterval = 0
    private let fixedDelta: TimeInterval
    
    private var unitNodes: [UnitID: PixelUnitNode] = [:]
    private let unitPool: NodePool<PixelUnitNode>
    private let damagePool: NodePool<SKLabelNode>
    
    private var parallaxBackground: ParallaxBackground!
    private var spellRenderer: SpellEffectsRenderer!
    
    private let laneBandNodes: [SKShapeNode]
    private let energyLabel = SKLabelNode(fontNamed: "Press Start 2P")
    private let cameraNode = SKCameraNode()
    private var introSweepCompleted = false
    private var cameraRestPosition: CGPoint = .zero
    
    private var hitstopTimer: TimeInterval = 0
    private var shakeTimer: TimeInterval = 0
    private var shakeDuration: TimeInterval = 0
    private var shakeAmplitude: CGFloat = 0
    
    private var lastPlayerPyreHP: Int?
    private var lastEnemyPyreHP: Int?
    
    public init(configuration: BattleSceneConfiguration = BattleSceneConfiguration()) {
        self.configuration = configuration
        self.placementGrid = PlacementGrid(configuration: configuration, fieldLength: configuration.fieldLengthTiles)
        self.fixedDelta = 1.0 / 60.0
        
        self.unitPool = NodePool<PixelUnitNode>(factory: {
            PixelUnitNode()
        }, reset: { node in
            node.updateHealth(current: 0, max: 1)
            node.alpha = 1.0
        })
        
        self.damagePool = NodePool<SKLabelNode>(factory: {
            let label = SKLabelNode(fontNamed: "Press Start 2P")
            label.fontSize = 14
            label.fontColor = .white
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = 70
            return label
        }, reset: { label in
            label.removeAllActions()
            label.alpha = 1.0
            label.text = nil
        })
        
        var bands: [SKShapeNode] = []
        for lane in Lane.allCases {
            let rect = placementGrid.bandRect(for: lane)
            let node = SKShapeNode(rect: rect, cornerRadius: 4)
            node.fillColor = AegisColorPalette.nightBlue.withAlphaComponent(0.05)
            node.strokeColor = AegisColorPalette.bronze.withAlphaComponent(0.2)
            node.lineWidth = 2
            node.zPosition = 1
            
            let pattern: [CGFloat] = [5, 3]
            let path = CGPath(rect: rect, transform: nil)
            node.path = path
            node.lineCap = .round
            
            bands.append(node)
        }
        self.laneBandNodes = bands
        
        super.init(size: configuration.canvasSize)
        
        scaleMode = .aspectFit
        backgroundColor = AegisColorPalette.midnightIndigo
        
        setupScene()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupScene() {
        parallaxBackground = ParallaxBackground(screenSize: configuration.canvasSize)
        parallaxBackground.position = CGPoint(x: configuration.canvasSize.width / 2, y: configuration.canvasSize.height / 2)
        addChild(parallaxBackground)
        
        energyLabel.fontSize = 10
        energyLabel.fontColor = AegisColorPalette.parchment
        energyLabel.horizontalAlignmentMode = .left
        energyLabel.verticalAlignmentMode = .top
        energyLabel.position = CGPoint(
            x: -configuration.canvasSize.width / 2 + 16,
            y: configuration.canvasSize.height / 2 - 16
        )
        energyLabel.zPosition = 50
        
        let energyBackground = SKShapeNode(rectOf: CGSize(width: 120, height: 24), cornerRadius: 4)
        energyBackground.fillColor = AegisColorPalette.shadowNavy.withAlphaComponent(0.8)
        energyBackground.strokeColor = AegisColorPalette.bronze.withAlphaComponent(0.6)
        energyBackground.position = CGPoint(x: 60, y: -12)
        energyBackground.zPosition = -1
        energyLabel.addChild(energyBackground)
        
        camera = cameraNode
        cameraRestPosition = CGPoint(x: configuration.canvasSize.width / 2, y: configuration.canvasSize.height / 2)
        cameraNode.position = cameraRestPosition
        addChild(cameraNode)
        cameraNode.addChild(energyLabel)
        
        for node in laneBandNodes {
            node.isAntialiased = false
            addChild(node)
        }
        
        spellRenderer = SpellEffectsRenderer(scene: self)
        
        Task {
            await AssetCatalog.shared.preloadAssets()
        }
    }
    
    public func presentBattle(setup: BattleSetup, catalog: ContentCatalog, seed: UInt64) throws {
        self.content = catalog
        self.unitIndex = Dictionary(uniqueKeysWithValues: catalog.units.map { ($0.key, $0) })
        
        let database = catalog.makeContentDatabase()
        simulation = try BattleSimulation(setup: setup, content: database, seed: seed)
        
        rebuildUnitNodes()
        updateEnergyDisplay()
        
        accumulator = 0
        previousTime = 0
        introSweepCompleted = false
        hitstopTimer = 0
        shakeTimer = 0
        shakeDuration = 0
        shakeAmplitude = 0
        
        lastPlayerPyreHP = simulation?.state.playerPyre.hp
        lastEnemyPyreHP = simulation?.state.enemyPyre.hp
        
        runIntroCameraSweep()
    }
    
    public func startIfNeeded() {
        guard simulation != nil else { return }
        isPaused = false
    }
    
    public override func update(_ currentTime: TimeInterval) {
        guard let simulation else { return }
        
        if previousTime == 0 {
            previousTime = currentTime
            return
        }
        
        let delta = min(currentTime - previousTime, 0.25)
        previousTime = currentTime
        
        parallaxBackground.update(deltaTime: delta)
        
        accumulator += delta
        while accumulator >= fixedDelta {
            if hitstopTimer > 0 {
                hitstopTimer = max(0, hitstopTimer - fixedDelta)
                accumulator -= fixedDelta
                continue
            }
            
            simulation.step()
            checkPyreDamage(in: simulation)
            accumulator -= fixedDelta
        }
        
        syncNodes(with: simulation)
        updateCameraShake(delta: delta)
        updateEnergyDisplay()
        
        if simulation.state.outcome != .inProgress {
            battleDelegate?.battleScene(self, didFinish: simulation.state.outcome)
        }
    }
    
    private func rebuildUnitNodes() {
        for (_, node) in unitNodes {
            unitPool.release(node)
        }
        unitNodes.removeAll(keepingCapacity: true)
        
        guard let simulation else { return }
        
        for unit in simulation.state.units.values {
            guard let archetype = unitIndex[unit.archetypeKey] else { continue }
            
            let node = unitPool.acquire()
            node.position = placementGrid.position(for: unit.lane, slot: unit.slot, xTile: unit.xTile)
            node.configure(with: unit, archetype: archetype)
            node.zPosition = 10 + CGFloat(unit.lane.index)
            addChild(node)
            unitNodes[unit.id] = node
            
            node.playSpawn()
        }
    }
    
    private func syncNodes(with simulation: BattleSimulation) {
        let stateUnits = simulation.state.units
        var seen: Set<UnitID> = []
        
        for (id, unit) in stateUnits {
            seen.insert(id)
            guard let archetype = unitIndex[unit.archetypeKey] else { continue }
            
            if let node = unitNodes[id] {
                let position = placementGrid.position(for: unit.lane, slot: unit.slot, xTile: unit.xTile)
                
                if node.position != position {
                    node.playWalk()
                    let move = SKAction.move(to: position, duration: 0.2)
                    node.run(move) { [weak node] in
                        node?.playIdle()
                    }
                }
                
                if let previousHP = lastKnownHP[id] {
                    if unit.hp != previousHP {
                        node.updateHealth(current: unit.hp, max: archetype.maxHP)
                        let delta = unit.hp - previousHP
                        
                        if delta < 0 {
                            node.playHit()
                            spawnDamageNumber(amount: -delta, isHeal: false, at: position)
                            triggerHitstop(duration: 0.05)
                            triggerCameraShake(amplitude: 2, duration: 0.1)
                        } else if delta > 0 {
                            spawnDamageNumber(amount: delta, isHeal: true, at: position)
                        }
                    }
                } else {
                    node.configure(with: unit, archetype: archetype)
                }
                
                node.updateStance(unit.stance)
            } else {
                let node = unitPool.acquire()
                node.position = placementGrid.position(for: unit.lane, slot: unit.slot, xTile: unit.xTile)
                node.configure(with: unit, archetype: archetype)
                node.zPosition = 10 + CGFloat(unit.lane.index)
                addChild(node)
                unitNodes[id] = node
                node.playSpawn()
            }
            
            lastKnownHP[id] = unit.hp
        }
        
        let deadUnits = unitNodes.keys.filter { !seen.contains($0) }
        for id in deadUnits {
            if let node = unitNodes[id] {
                node.playDeath { [weak self, weak node] in
                    guard let self, let node else { return }
                    self.unitPool.release(node)
                }
                
                triggerHitstop(duration: 0.08)
                triggerCameraShake(amplitude: 4, duration: 0.15)
            }
            unitNodes.removeValue(forKey: id)
            lastKnownHP.removeValue(forKey: id)
        }
    }
    
    private func runIntroCameraSweep() {
        guard !introSweepCompleted else { return }
        
        let top = CGPoint(x: size.width / 2.0, y: size.height * 0.9)
        let mid = CGPoint(x: size.width / 2.0, y: size.height * 0.55)
        let bottom = CGPoint(x: size.width / 2.0, y: size.height * 0.35)
        
        cameraRestPosition = bottom
        cameraNode.position = top
        
        let sweep = SKAction.sequence([
            SKAction.move(to: mid, duration: 0.6).withEaseInOut(),
            SKAction.wait(forDuration: 0.2),
            SKAction.move(to: bottom, duration: 0.6).withEaseInOut(),
            SKAction.run { [weak self] in
                guard let self else { return }
                self.introSweepCompleted = true
                self.cameraNode.position = bottom
            }
        ])
        
        cameraNode.run(sweep)
    }
    
    private func spawnDamageNumber(amount: Int, isHeal: Bool, at position: CGPoint) {
        guard amount > 0 else { return }
        
        let label = damagePool.acquire()
        label.text = isHeal ? "+\(amount)" : "-\(amount)"
        label.fontColor = isHeal ? AegisColorPalette.healthGreen : AegisColorPalette.crimson
        label.position = position
        label.alpha = 1.0
        addChild(label)
        
        let rise = SKAction.moveBy(x: 0, y: 24, duration: 0.5)
        let fade = SKAction.fadeOut(withDuration: 0.5)
        let scale = SKAction.scale(to: 1.2, duration: 0.2)
        let shrink = SKAction.scale(to: 0.8, duration: 0.3)
        
        let group = SKAction.group([
            rise,
            fade,
            SKAction.sequence([scale, shrink])
        ])
        
        let cleanup = SKAction.run { [weak self, weak label] in
            guard let self, let label else { return }
            self.damagePool.release(label)
        }
        
        label.run(SKAction.sequence([group, cleanup]))
    }
    
    private func updateEnergyDisplay() {
        guard let simulation else { return }
        energyLabel.text = "⚡ \(simulation.state.energyRemaining)"
    }
    
    private func triggerHitstop(duration: TimeInterval) {
        hitstopTimer = max(hitstopTimer, duration)
    }
    
    private func triggerCameraShake(amplitude: CGFloat, duration: TimeInterval) {
        shakeAmplitude = max(shakeAmplitude, amplitude)
        shakeDuration = max(shakeDuration, duration)
        shakeTimer = max(shakeTimer, duration)
    }
    
    private func updateCameraShake(delta: TimeInterval) {
        guard introSweepCompleted else { return }
        
        if shakeTimer > 0 {
            shakeTimer = max(0, shakeTimer - delta)
            let progress = shakeDuration > 0 ? CGFloat(shakeTimer / shakeDuration) : 0
            let damped = progress * progress
            let offsetX = (CGFloat.random(in: -1...1)) * shakeAmplitude * damped
            let offsetY = (CGFloat.random(in: -1...1)) * shakeAmplitude * damped
            cameraNode.position = CGPoint(x: cameraRestPosition.x + offsetX, y: cameraRestPosition.y + offsetY)
        } else {
            cameraNode.position = cameraRestPosition
            shakeAmplitude = 0
            shakeDuration = 0
        }
    }
    
    private func checkPyreDamage(in simulation: BattleSimulation) {
        let playerHP = simulation.state.playerPyre.hp
        let enemyHP = simulation.state.enemyPyre.hp
        
        if let last = lastPlayerPyreHP, playerHP < last {
            triggerHitstop(duration: 0.05)
            triggerCameraShake(amplitude: 3, duration: 0.1)
        }
        
        if let last = lastEnemyPyreHP, enemyHP < last {
            triggerHitstop(duration: 0.05)
            triggerCameraShake(amplitude: 3, duration: 0.1)
        }
        
        lastPlayerPyreHP = playerHP
        lastEnemyPyreHP = enemyHP
    }
}

private extension SKAction {
    func withEaseInOut() -> SKAction {
        timingMode = .easeInEaseOut
        return self
    }
}