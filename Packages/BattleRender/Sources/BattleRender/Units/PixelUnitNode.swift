import CoreEngine
import Foundation
import SpriteKit

@MainActor
public final class PixelUnitNode: SKNode {
    
    private let spriteNode: SKSpriteNode
    private let healthBar: HealthBarNode
    private let shadowNode: SKShapeNode
    private let stanceIndicator: SKSpriteNode
    private let weaponLayer: SKSpriteNode?
    
    private var animationController: UnitAnimationController?
    private(set) var unitID: UnitID?
    private var archetypeKey: String = ""
    private var team: Team = .player
    
    private let baseSize = CGSize(width: 32, height: 32)
    
    public init() {
        self.spriteNode = SKSpriteNode(color: .clear, size: baseSize)
        self.healthBar = HealthBarNode()
        self.shadowNode = SKShapeNode(ellipseOf: CGSize(width: 20, height: 8))
        self.stanceIndicator = SKSpriteNode(color: .clear, size: CGSize(width: 16, height: 16))
        self.weaponLayer = SKSpriteNode(color: .clear, size: baseSize)
        
        super.init()
        
        setupNodes()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupNodes() {
        shadowNode.fillColor = SKColor(white: 0, alpha: 0.3)
        shadowNode.strokeColor = .clear
        shadowNode.position = CGPoint(x: 0, y: -14)
        shadowNode.zPosition = -1
        addChild(shadowNode)
        
        spriteNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        spriteNode.texture?.filteringMode = .nearest
        spriteNode.zPosition = 0
        addChild(spriteNode)
        
        if let weaponLayer {
            weaponLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            weaponLayer.zPosition = 1
            addChild(weaponLayer)
        }
        
        healthBar.position = CGPoint(x: 0, y: baseSize.height * 0.6)
        healthBar.zPosition = 2
        addChild(healthBar)
        
        stanceIndicator.position = CGPoint(x: baseSize.width * 0.4, y: -baseSize.height * 0.4)
        stanceIndicator.zPosition = 2
        addChild(stanceIndicator)
    }
    
    public func configure(with unit: UnitInstance, archetype: UnitArchetype) {
        self.unitID = unit.id
        self.archetypeKey = archetype.key
        self.team = unit.team
        
        let unitName = mapUnitName(archetype.key)
        let asset = AssetCatalog.AssetType.unit(name: unitName)
        
        animationController = UnitAnimationController(
            unitNode: self,
            asset: asset,
            team: unit.team
        )
        
        healthBar.configure(current: unit.hp, max: archetype.maxHP)
        updateStanceIndicator(unit.stance)
        
        if let defaultTexture = AssetCatalog.shared.texture(for: asset, frame: "idle_0") {
            spriteNode.texture = defaultTexture
        }
        
        animationController?.playIdle()
        
        alpha = unit.hp > 0 ? 1.0 : 0.0
    }
    
    public func updateHealth(current: Int, max: Int) {
        healthBar.updateHealth(current: current, max: max)
    }
    
    public func updateStance(_ stance: Stance) {
        updateStanceIndicator(stance)
    }
    
    public func playAttack(completion: @escaping () -> Void) {
        animationController?.playAttack(completion: completion)
    }
    
    public func playHit() {
        animationController?.playHit()
        
        let flash = SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.05),
            SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.05)
        ])
        spriteNode.run(flash)
    }
    
    public func playDeath(completion: @escaping () -> Void) {
        animationController?.playDeath {
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            self.run(fadeOut, completion: completion)
        }
    }
    
    public func playWalk() {
        animationController?.playWalk()
    }
    
    public func playSpawn() {
        setScale(0.0)
        alpha = 1.0
        
        let pop = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.1, duration: 0.15),
                SKAction.fadeIn(withDuration: 0.1)
            ]),
            SKAction.scale(to: 1.0, duration: 0.1)
        ])
        run(pop)
        
        animationController?.playIdle()
    }
    
    private func updateStanceIndicator(_ stance: Stance) {
        let iconName: String
        let color: SKColor
        
        switch stance {
        case .guard:
            iconName = "shield"
            color = AegisColorPalette.bronze
        case .skirmish:
            iconName = "dash"
            color = AegisColorPalette.laurelGreen
        case .hunter:
            iconName = "target"
            color = AegisColorPalette.crimson
        }
        
        if let texture = AssetCatalog.shared.texture(for: .ui(name: "icons"), frame: iconName) {
            stanceIndicator.texture = texture
            stanceIndicator.color = color
            stanceIndicator.colorBlendFactor = 0.5
        }
    }
    
    private func mapUnitName(_ key: String) -> String {
        switch key {
        case HeroKey.achilles: return "achilles"
        case UnitKey.spearman: return "spearman"
        case UnitKey.archer: return "archer"
        case UnitKey.healer: return "healer"
        case UnitKey.eliteHoplite: return "hoplite"
        case UnitKey.mythicBeast: return "beast"
        default: return "spearman"
        }
    }
    
    func updateSprite(with texture: SKTexture) {
        spriteNode.texture = texture
    }
}