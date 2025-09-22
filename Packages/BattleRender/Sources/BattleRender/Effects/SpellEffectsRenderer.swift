import Foundation
import SpriteKit
import CoreEngine

@MainActor
public final class SpellEffectsRenderer {
    
    private weak var scene: SKScene?
    private let effectPool: NodePool<SKSpriteNode>
    private let particlePool: NodePool<SKEmitterNode>
    
    public init(scene: SKScene) {
        self.scene = scene
        
        self.effectPool = NodePool<SKSpriteNode>(factory: {
            let node = SKSpriteNode(color: .clear, size: CGSize(width: 64, height: 64))
            node.texture?.filteringMode = .nearest
            return node
        }, reset: { node in
            node.removeAllActions()
            node.removeAllChildren()
            node.alpha = 1.0
            node.setScale(1.0)
            node.zRotation = 0
            node.color = .white
            node.colorBlendFactor = 0
        })
        
        self.particlePool = NodePool<SKEmitterNode>(factory: {
            SKEmitterNode()
        }, reset: { node in
            node.removeAllActions()
            node.particleBirthRate = 0
            node.resetSimulation()
        })
    }
    
    public func playFireball(from origin: CGPoint, to target: CGPoint, completion: @escaping () -> Void) {
        let fireball = effectPool.acquire()
        fireball.position = origin
        fireball.zPosition = 100
        
        let asset = AssetCatalog.AssetType.effect(name: "fireball")
        if let texture = AssetCatalog.shared.texture(for: asset, frame: "fireball_cast_0") {
            fireball.texture = texture
        }
        
        scene?.addChild(fireball)
        
        let castAnimation = AnimationBuilder.buildAnimation(
            from: SpellAnimations.fireballCast,
            asset: asset
        )
        
        let distance = hypot(target.x - origin.x, target.y - origin.y)
        let duration = min(0.5, TimeInterval(distance / 400))
        
        let projectileMove = SKAction.move(to: target, duration: duration)
        projectileMove.timingMode = .easeIn
        
        let rotation = SKAction.rotate(byAngle: .pi * 2, duration: duration)
        
        let trail = createFireTrail()
        fireball.addChild(trail)
        
        let projectileGroup = SKAction.group([
            castAnimation,
            projectileMove,
            rotation
        ])
        
        let impact = SKAction.run { [weak self] in
            self?.playFireballImpact(at: target)
        }
        
        let cleanup = SKAction.run { [weak self] in
            trail.particleBirthRate = 0
            self?.effectPool.release(fireball)
            completion()
        }
        
        let sequence = SKAction.sequence([
            projectileGroup,
            impact,
            SKAction.wait(forDuration: 0.1),
            cleanup
        ])
        
        fireball.run(sequence)
    }
    
    private func playFireballImpact(at position: CGPoint) {
        let impact = effectPool.acquire()
        impact.position = position
        impact.zPosition = 101
        impact.setScale(1.5)
        
        scene?.addChild(impact)
        
        let asset = AssetCatalog.AssetType.effect(name: "fireball")
        let impactAnimation = AnimationBuilder.buildOneShotAnimation(
            from: SpellAnimations.fireballImpact,
            asset: asset
        ) { [weak self] in
            self?.effectPool.release(impact)
        }
        
        let expand = SKAction.scale(to: 2.0, duration: 0.2)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        let group = SKAction.group([impactAnimation, expand, fade])
        
        impact.run(group)
        
        createExplosionParticles(at: position)
        shakeCamera(intensity: 0.3)
    }
    
    public func playHeal(at position: CGPoint, radius: Int?, completion: @escaping () -> Void) {
        let heal = effectPool.acquire()
        heal.position = position
        heal.zPosition = 95
        
        scene?.addChild(heal)
        
        let asset = AssetCatalog.AssetType.effect(name: "heal")
        let healAnimation = AnimationBuilder.buildAnimation(
            from: SpellAnimations.healSparkle,
            asset: asset
        )
        
        let rise = SKAction.moveBy(x: 0, y: 20, duration: 0.6)
        let fade = SKAction.fadeOut(withDuration: 0.3)
        let scale = SKAction.scale(to: 1.3, duration: 0.6)
        
        let sparkles = createHealSparkles()
        heal.addChild(sparkles)
        
        if let radius = radius, radius > 0 {
            let ring = createHealRing(radius: CGFloat(radius * 16))
            ring.position = position
            scene?.addChild(ring)
            
            let ringExpand = SKAction.scale(to: 1.5, duration: 0.4)
            let ringFade = SKAction.fadeOut(withDuration: 0.4)
            let ringGroup = SKAction.group([ringExpand, ringFade])
            let ringCleanup = SKAction.removeFromParent()
            
            ring.run(SKAction.sequence([ringGroup, ringCleanup]))
        }
        
        let cleanup = SKAction.run { [weak self] in
            sparkles.particleBirthRate = 0
            self?.effectPool.release(heal)
            completion()
        }
        
        let sequence = SKAction.sequence([
            SKAction.group([healAnimation, rise, scale]),
            fade,
            cleanup
        ])
        
        heal.run(sequence)
    }
    
    public func playLyreResonance(at position: CGPoint, duration: TimeInterval) {
        let lyre = effectPool.acquire()
        lyre.position = position
        lyre.zPosition = 90
        
        scene?.addChild(lyre)
        
        let asset = AssetCatalog.AssetType.effect(name: "lyre")
        let lyreAnimation = AnimationBuilder.buildAnimation(
            from: SpellAnimations.lyreResonance,
            asset: asset
        )
        
        let notes = createMusicNotes()
        lyre.addChild(notes)
        
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.5),
            SKAction.scale(to: 0.9, duration: 0.5)
        ])
        
        let cleanup = SKAction.run { [weak self] in
            notes.particleBirthRate = 0
            self?.effectPool.release(lyre)
        }
        
        lyre.run(SKAction.sequence([
            SKAction.group([
                lyreAnimation,
                SKAction.repeat(pulse, count: Int(duration))
            ]),
            SKAction.fadeOut(withDuration: 0.3),
            cleanup
        ]))
        
        createResonanceWaves(at: position, count: 3)
    }
    
    public func playRally(at position: CGPoint, completion: @escaping () -> Void) {
        let rally = effectPool.acquire()
        rally.position = position
        rally.zPosition = 92
        
        scene?.addChild(rally)
        
        let asset = AssetCatalog.AssetType.effect(name: "rally")
        let rallyAnimation = AnimationBuilder.buildAnimation(
            from: SpellAnimations.rallyBuff,
            asset: asset
        )
        
        let banner = createRallyBanner()
        rally.addChild(banner)
        
        let rise = SKAction.moveBy(x: 0, y: 30, duration: 0.5)
        let wave = SKAction.sequence([
            SKAction.rotate(byAngle: .pi / 12, duration: 0.2),
            SKAction.rotate(byAngle: -.pi / 6, duration: 0.4),
            SKAction.rotate(byAngle: .pi / 12, duration: 0.2)
        ])
        
        let cleanup = SKAction.run { [weak self] in
            self?.effectPool.release(rally)
            completion()
        }
        
        rally.run(SKAction.sequence([
            SKAction.group([rallyAnimation, rise, wave]),
            SKAction.fadeOut(withDuration: 0.3),
            cleanup
        ]))
    }
    
    private func createFireTrail() -> SKEmitterNode {
        let trail = particlePool.acquire()
        
        trail.particleTexture = AssetCatalog.shared.texture(
            for: .effect(name: "particles"),
            frame: "fire_particle"
        )
        trail.particleBirthRate = 100
        trail.particleLifetime = 0.5
        trail.particleLifetimeRange = 0.2
        trail.particleScale = 0.3
        trail.particleScaleRange = 0.1
        trail.particleScaleSpeed = -0.5
        trail.emissionAngle = .pi
        trail.emissionAngleRange = .pi / 4
        trail.particleSpeed = 50
        trail.particleSpeedRange = 20
        trail.particleAlpha = 0.8
        trail.particleAlphaSpeed = -1.5
        trail.particleColor = AegisColorPalette.amberGlow
        trail.particleColorBlendFactor = 1.0
        trail.particleBlendMode = .add
        
        return trail
    }
    
    private func createHealSparkles() -> SKEmitterNode {
        let sparkles = particlePool.acquire()
        
        sparkles.particleTexture = AssetCatalog.shared.texture(
            for: .effect(name: "particles"),
            frame: "sparkle"
        )
        sparkles.particleBirthRate = 30
        sparkles.particleLifetime = 1.0
        sparkles.particleLifetimeRange = 0.5
        sparkles.particleScale = 0.2
        sparkles.particleScaleRange = 0.1
        sparkles.emissionAngleRange = .pi * 2
        sparkles.particleSpeed = 30
        sparkles.particleSpeedRange = 15
        sparkles.particleAlpha = 1.0
        sparkles.particleAlphaSpeed = -1.0
        sparkles.particleColor = AegisColorPalette.healthGreen
        sparkles.particleColorBlendFactor = 0.7
        sparkles.particleBlendMode = .add
        sparkles.particlePositionRange = CGVector(dx: 20, dy: 20)
        
        return sparkles
    }
    
    private func createHealRing(radius: CGFloat) -> SKShapeNode {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = AegisColorPalette.healthGreen
        ring.lineWidth = 3.0
        ring.fillColor = .clear
        ring.glowWidth = 2.0
        ring.zPosition = 94
        ring.setScale(0.5)
        
        return ring
    }
    
    private func createMusicNotes() -> SKEmitterNode {
        let notes = particlePool.acquire()
        
        notes.particleTexture = AssetCatalog.shared.texture(
            for: .effect(name: "particles"),
            frame: "note"
        )
        notes.particleBirthRate = 5
        notes.particleLifetime = 2.0
        notes.particleScale = 0.5
        notes.particleScaleRange = 0.2
        notes.emissionAngle = .pi / 2
        notes.emissionAngleRange = .pi / 6
        notes.particleSpeed = 30
        notes.particleAlpha = 0.8
        notes.particleAlphaSpeed = -0.4
        notes.particleColor = AegisColorPalette.highlightGold
        notes.particleColorBlendFactor = 0.5
        notes.yAcceleration = 10
        
        return notes
    }
    
    private func createResonanceWaves(at position: CGPoint, count: Int) {
        for i in 0..<count {
            let delay = TimeInterval(i) * 0.3
            
            let wave = SKShapeNode(circleOfRadius: 20)
            wave.strokeColor = AegisColorPalette.highlightGold.withAlphaComponent(0.6)
            wave.lineWidth = 2.0
            wave.fillColor = .clear
            wave.position = position
            wave.zPosition = 89
            wave.setScale(0.1)
            
            scene?.addChild(wave)
            
            let expand = SKAction.scale(to: 3.0, duration: 1.0)
            let fade = SKAction.fadeOut(withDuration: 1.0)
            let group = SKAction.group([expand, fade])
            let cleanup = SKAction.removeFromParent()
            
            wave.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                group,
                cleanup
            ]))
        }
    }
    
    private func createRallyBanner() -> SKSpriteNode {
        let banner = SKSpriteNode(color: .clear, size: CGSize(width: 32, height: 48))
        
        if let texture = AssetCatalog.shared.texture(for: .effect(name: "rally"), frame: "banner") {
            banner.texture = texture
            banner.texture?.filteringMode = .nearest
        }
        
        banner.anchorPoint = CGPoint(x: 0.5, y: 0)
        banner.color = AegisColorPalette.crimson
        banner.colorBlendFactor = 0.3
        
        return banner
    }
    
    private func createExplosionParticles(at position: CGPoint) {
        let explosion = particlePool.acquire()
        
        explosion.particleTexture = AssetCatalog.shared.texture(
            for: .effect(name: "particles"),
            frame: "ember"
        )
        explosion.position = position
        explosion.zPosition = 102
        explosion.particleBirthRate = 200
        explosion.numParticlesToEmit = 20
        explosion.particleLifetime = 0.5
        explosion.particleScale = 0.4
        explosion.particleScaleSpeed = -0.8
        explosion.emissionAngleRange = .pi * 2
        explosion.particleSpeed = 100
        explosion.particleSpeedRange = 50
        explosion.particleAlpha = 1.0
        explosion.particleAlphaSpeed = -2.0
        explosion.particleColor = AegisColorPalette.amberGlow
        explosion.particleColorBlendFactor = 1.0
        explosion.particleBlendMode = .add
        
        scene?.addChild(explosion)
        
        let cleanup = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.removeFromParent()
        ])
        
        explosion.run(cleanup)
    }
    
    private func shakeCamera(intensity: CGFloat) {
        guard let camera = scene?.camera else { return }
        
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -intensity * 4, y: intensity * 2, duration: 0.02),
            SKAction.moveBy(x: intensity * 8, y: -intensity * 4, duration: 0.04),
            SKAction.moveBy(x: -intensity * 4, y: intensity * 2, duration: 0.02)
        ])
        
        camera.run(shake)
    }
}