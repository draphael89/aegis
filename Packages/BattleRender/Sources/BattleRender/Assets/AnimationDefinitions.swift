import Foundation
import SpriteKit

public struct AnimationDefinition: Sendable {
    public let name: String
    public let frames: Int
    public let duration: TimeInterval
    public let repeatForever: Bool
    
    public var timePerFrame: TimeInterval {
        duration / Double(frames)
    }
    
    public init(name: String, frames: Int, duration: TimeInterval, repeatForever: Bool = true) {
        self.name = name
        self.frames = frames
        self.duration = duration
        self.repeatForever = repeatForever
    }
}

public struct UnitAnimations {
    public static let idle = AnimationDefinition(name: "idle", frames: 4, duration: 0.5)
    public static let walk = AnimationDefinition(name: "walk", frames: 4, duration: 0.33)
    public static let attack = AnimationDefinition(name: "attack", frames: 4, duration: 0.25, repeatForever: false)
    public static let hit = AnimationDefinition(name: "hit", frames: 2, duration: 0.1, repeatForever: false)
    public static let death = AnimationDefinition(name: "death", frames: 4, duration: 0.4, repeatForever: false)
    
    public static func all() -> [AnimationDefinition] {
        [idle, walk, attack, hit, death]
    }
}

public struct SpellAnimations {
    public static let fireballCast = AnimationDefinition(name: "fireball_cast", frames: 6, duration: 0.3, repeatForever: false)
    public static let fireballImpact = AnimationDefinition(name: "fireball_impact", frames: 8, duration: 0.4, repeatForever: false)
    public static let healSparkle = AnimationDefinition(name: "heal", frames: 12, duration: 0.6, repeatForever: false)
    public static let lyreResonance = AnimationDefinition(name: "lyre", frames: 8, duration: 1.0)
    public static let rallyBuff = AnimationDefinition(name: "rally", frames: 6, duration: 0.5)
}

public struct TrapAnimations {
    public static let spikesTrigger = AnimationDefinition(name: "spikes", frames: 6, duration: 0.3, repeatForever: false)
    public static let spikesIdle = AnimationDefinition(name: "spikes_idle", frames: 2, duration: 0.4)
}

public struct EnvironmentAnimations {
    public static let torchFlicker = AnimationDefinition(name: "torch", frames: 4, duration: 0.5)
    public static let starTwinkle = AnimationDefinition(name: "stars", frames: 3, duration: 2.0)
    public static let campfireFlames = AnimationDefinition(name: "campfire", frames: 6, duration: 0.6)
}

@MainActor
public final class AnimationBuilder {
    
    public static func buildAnimation(
        from definition: AnimationDefinition,
        asset: AssetCatalog.AssetType
    ) -> SKAction {
        let textures = AssetCatalog.shared.textures(
            for: asset,
            prefix: definition.name,
            count: definition.frames
        )
        
        guard !textures.isEmpty else {
            return SKAction.wait(forDuration: definition.duration)
        }
        
        let animate = SKAction.animate(
            with: textures,
            timePerFrame: definition.timePerFrame
        )
        
        return definition.repeatForever
            ? SKAction.repeatForever(animate)
            : animate
    }
    
    public static func buildOneShotAnimation(
        from definition: AnimationDefinition,
        asset: AssetCatalog.AssetType,
        completion: @escaping () -> Void
    ) -> SKAction {
        let animation = buildAnimation(from: definition, asset: asset)
        return SKAction.sequence([
            animation,
            SKAction.run(completion)
        ])
    }
}
