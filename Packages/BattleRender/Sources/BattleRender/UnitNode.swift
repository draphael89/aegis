import CoreEngine
import Foundation
import SpriteKit

final class UnitNode: SKSpriteNode {
    private(set) var unitID: UnitID?
    private let healthBar = SKShapeNode(rectOf: CGSize(width: 28, height: 4), cornerRadius: 2)

    init(size: CGSize) {
        super.init(texture: nil, color: .white, size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        healthBar.fillColor = .green
        healthBar.strokeColor = .clear
        healthBar.position = CGPoint(x: 0, y: size.height * 0.6)
        addChild(healthBar)
        self.colorBlendFactor = 1.0
        self.texture = nil
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with unit: UnitInstance, archetype: UnitArchetype) {
        self.unitID = unit.id
        self.alpha = unit.hp > 0 ? 1.0 : 0.0
        updateHealth(current: unit.hp, max: archetype.maxHP)
        color = unit.team == .player ? .cyan : .red
        colorBlendFactor = 1.0
    }

    func updateHealth(current: Int, max maxValue: Int) {
        let clamped = max(0, min(maxValue, current))
        let ratio = maxValue == 0 ? 0 : CGFloat(clamped) / CGFloat(maxValue)
        let width = max(0.0, ratio) * 28.0
        let rect = CGRect(x: -14, y: -2, width: width, height: 4)
        let path = CGPath(rect: rect, transform: nil)
        healthBar.path = path
        healthBar.fillColor = ratio > 0.5 ? .green : .orange
    }
}
