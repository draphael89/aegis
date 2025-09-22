import CoreEngine
import Foundation
import SpriteKit

@MainActor
public final class UnitAnimationController {
    
    public enum AnimationState {
        case idle
        case walking
        case attacking
        case hit
        case dying
        case dead
    }
    
    private weak var unitNode: PixelUnitNode?
    private let asset: AssetCatalog.AssetType
    private let team: Team
    private var currentState: AnimationState = .idle
    private var currentAction: SKAction?
    private let actionKey = "unitAnimation"
    
    public init(unitNode: PixelUnitNode, asset: AssetCatalog.AssetType, team: Team) {
        self.unitNode = unitNode
        self.asset = asset
        self.team = team
    }
    
    public func playIdle() {
        guard currentState != .dying && currentState != .dead else { return }
        
        currentState = .idle
        let animation = AnimationBuilder.buildAnimation(
            from: UnitAnimations.idle,
            asset: asset
        )
        
        unitNode?.removeAction(forKey: actionKey)
        unitNode?.run(animation, withKey: actionKey)
    }
    
    public func playWalk() {
        guard currentState != .dying && currentState != .dead else { return }
        guard currentState != .walking else { return }
        
        currentState = .walking
        let animation = AnimationBuilder.buildAnimation(
            from: UnitAnimations.walk,
            asset: asset
        )
        
        unitNode?.removeAction(forKey: actionKey)
        unitNode?.run(animation, withKey: actionKey)
    }
    
    public func playAttack(completion: @escaping () -> Void) {
        guard currentState != .dying && currentState != .dead else {
            completion()
            return
        }
        
        currentState = .attacking
        
        let attackAnimation = AnimationBuilder.buildOneShotAnimation(
            from: UnitAnimations.attack,
            asset: asset
        ) { [weak self] in
            self?.playIdle()
            completion()
        }
        
        let weaponSwing = SKAction.sequence([
            SKAction.rotate(byAngle: -.pi / 6, duration: 0.1),
            SKAction.rotate(byAngle: .pi / 3, duration: 0.05),
            SKAction.rotate(byAngle: -.pi / 6, duration: 0.1)
        ])
        
        unitNode?.removeAction(forKey: actionKey)
        unitNode?.run(attackAnimation, withKey: actionKey)
        
        if let weaponNode = unitNode?.children.first(where: { $0.name == "weapon" }) {
            weaponNode.run(weaponSwing)
        }
    }
    
    public func playHit() {
        guard currentState != .dying && currentState != .dead else { return }
        
        let wasAttacking = currentState == .attacking
        currentState = .hit
        
        let hitAnimation = AnimationBuilder.buildOneShotAnimation(
            from: UnitAnimations.hit,
            asset: asset
        ) { [weak self] in
            if wasAttacking {
                self?.currentState = .attacking
            } else {
                self?.playIdle()
            }
        }
        
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -2, y: 0, duration: 0.025),
            SKAction.moveBy(x: 4, y: 0, duration: 0.05),
            SKAction.moveBy(x: -2, y: 0, duration: 0.025)
        ])
        
        unitNode?.removeAction(forKey: actionKey)
        unitNode?.run(SKAction.group([hitAnimation, shake]), withKey: actionKey)
    }
    
    public func playDeath(completion: @escaping () -> Void) {
        guard currentState != .dying && currentState != .dead else {
            completion()
            return
        }
        
        currentState = .dying
        
        let deathAnimation = AnimationBuilder.buildOneShotAnimation(
            from: UnitAnimations.death,
            asset: asset
        ) { [weak self] in
            self?.currentState = .dead
            completion()
        }
        
        let fall = SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.moveBy(x: 0, y: -8, duration: 0.2),
            SKAction.fadeAlpha(to: 0.3, duration: 0.1)
        ])
        
        unitNode?.removeAction(forKey: actionKey)
        unitNode?.run(SKAction.group([deathAnimation, fall]), withKey: actionKey)
    }
    
    public func stopAllAnimations() {
        unitNode?.removeAction(forKey: actionKey)
    }
    
    public func updateTexture(for frame: String) {
        guard let texture = AssetCatalog.shared.texture(for: asset, frame: frame) else { return }
        unitNode?.updateSprite(with: texture)
    }
}