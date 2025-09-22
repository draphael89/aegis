import Foundation
import SpriteKit

@MainActor
public final class HealthBarNode: SKNode {
    
    private let backgroundBar: SKShapeNode
    private let healthFill: SKShapeNode
    private let frameNode: SKSpriteNode
    private let shieldIcon: SKSpriteNode?
    
    private let barWidth: CGFloat = 28
    private let barHeight: CGFloat = 4
    private var currentHealthRatio: CGFloat = 1.0
    
    public override init() {
        self.backgroundBar = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 1)
        self.healthFill = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 1)
        self.frameNode = SKSpriteNode(color: .clear, size: CGSize(width: barWidth + 4, height: barHeight + 4))
        self.shieldIcon = SKSpriteNode(color: .clear, size: CGSize(width: 8, height: 8))
        
        super.init()
        
        setupNodes()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupNodes() {
        backgroundBar.fillColor = SKColor(white: 0.1, alpha: 0.8)
        backgroundBar.strokeColor = AegisColorPalette.bronze.withAlphaComponent(0.6)
        backgroundBar.lineWidth = 1.0
        backgroundBar.zPosition = 0
        addChild(backgroundBar)
        
        healthFill.strokeColor = .clear
        healthFill.zPosition = 1
        addChild(healthFill)
        
        if let frameTexture = AssetCatalog.shared.texture(for: .ui(name: "frames"), frame: "health_bar") {
            frameNode.texture = frameTexture
            frameNode.texture?.filteringMode = .nearest
            frameNode.zPosition = 2
            addChild(frameNode)
        }
        
        if let shieldIcon {
            shieldIcon.position = CGPoint(x: -barWidth / 2 - 6, y: 0)
            shieldIcon.zPosition = 3
            shieldIcon.isHidden = true
            addChild(shieldIcon)
        }
    }
    
    public func configure(current: Int, max: Int) {
        updateHealth(current: current, max: max)
    }
    
    public func updateHealth(current: Int, max maxValue: Int) {
        let clamped = Swift.max(0, Swift.min(maxValue, current))
        currentHealthRatio = maxValue == 0 ? 0 : CGFloat(clamped) / CGFloat(maxValue)
        
        let fillWidth = currentHealthRatio * barWidth
        let fillRect = CGRect(x: -barWidth / 2, y: -barHeight / 2, width: fillWidth, height: barHeight)
        let fillPath = CGPath(rect: fillRect, transform: nil)
        
        healthFill.path = fillPath
        updateHealthColor()
        
        if currentHealthRatio < 1.0 && currentHealthRatio > 0 {
            animateDamage()
        } else if currentHealthRatio == 0 {
            animateDeath()
        }
    }
    
    private func updateHealthColor() {
        let color: SKColor
        
        if currentHealthRatio > 0.66 {
            color = AegisColorPalette.laurelGreen
        } else if currentHealthRatio > 0.33 {
            color = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        } else {
            color = AegisColorPalette.crimson
        }
        
        healthFill.fillColor = color
    }
    
    public func showShield(_ show: Bool) {
        guard let shieldIcon else { return }
        
        if show {
            if let texture = AssetCatalog.shared.texture(for: .ui(name: "icons"), frame: "shield_small") {
                shieldIcon.texture = texture
                shieldIcon.isHidden = false
                
                let pulse = SKAction.sequence([
                    SKAction.scale(to: 1.2, duration: 0.3),
                    SKAction.scale(to: 1.0, duration: 0.3)
                ])
                shieldIcon.run(SKAction.repeatForever(pulse))
            }
        } else {
            shieldIcon.isHidden = true
            shieldIcon.removeAllActions()
        }
    }
    
    private func animateDamage() {
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.healthFill.fillColor = .white
            },
            SKAction.wait(forDuration: 0.05),
            SKAction.run { [weak self] in
                self?.updateHealthColor()
            }
        ])
        
        healthFill.run(flash)
    }
    
    private func animateDeath() {
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        run(fadeOut)
    }
}
