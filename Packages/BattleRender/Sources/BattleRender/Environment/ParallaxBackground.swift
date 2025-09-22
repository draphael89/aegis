import Foundation
import SpriteKit

@MainActor
public final class ParallaxBackground: SKNode {
    
    public struct Layer {
        let textureName: String
        let scrollSpeed: CGFloat
        let zPosition: CGFloat
        let opacity: CGFloat
        let animated: Bool
        let tileHorizontally: Bool
    }
    
    private var layers: [ParallaxLayer] = []
    private let screenSize: CGSize
    private var baseScrollSpeed: CGFloat = 20.0
    
    public init(screenSize: CGSize) {
        self.screenSize = screenSize
        super.init()
        setupDefaultLayers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupDefaultLayers() {
        let layerConfigs = [
            Layer(
                textureName: "stars",
                scrollSpeed: 0.1,
                zPosition: -100,
                opacity: 1.0,
                animated: true,
                tileHorizontally: true
            ),
            Layer(
                textureName: "mountains",
                scrollSpeed: 0.3,
                zPosition: -90,
                opacity: 0.9,
                animated: false,
                tileHorizontally: true
            ),
            Layer(
                textureName: "temple",
                scrollSpeed: 0.6,
                zPosition: -80,
                opacity: 1.0,
                animated: true,
                tileHorizontally: false
            )
        ]
        
        for config in layerConfigs {
            addLayer(config)
        }
    }
    
    public func addLayer(_ config: Layer) {
        let layer = ParallaxLayer(
            config: config,
            screenSize: screenSize
        )
        layer.zPosition = config.zPosition
        addChild(layer)
        layers.append(layer)
    }
    
    public func update(deltaTime: TimeInterval) {
        for layer in layers {
            layer.update(deltaTime: deltaTime, baseSpeed: baseScrollSpeed)
        }
    }
    
    public func setScrollSpeed(_ speed: CGFloat) {
        baseScrollSpeed = speed
    }
    
    public func reset() {
        for layer in layers {
            layer.reset()
        }
    }
}

@MainActor
private final class ParallaxLayer: SKNode {
    
    private let config: ParallaxBackground.Layer
    private let screenSize: CGSize
    private var sprites: [SKSpriteNode] = []
    private var currentOffset: CGFloat = 0
    private var animationTime: TimeInterval = 0
    
    init(config: ParallaxBackground.Layer, screenSize: CGSize) {
        self.config = config
        self.screenSize = screenSize
        super.init()
        setupSprites()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSprites() {
        let asset = AssetCatalog.AssetType.background(name: config.textureName)
        
        guard let texture = AssetCatalog.shared.texture(for: asset, frame: "default") else {
            return
        }
        
        texture.filteringMode = .nearest
        
        if config.tileHorizontally {
            let textureSize = texture.size()
            let tilesNeeded = Int(ceil(screenSize.width / textureSize.width)) + 2
            
            for i in 0..<tilesNeeded {
                let sprite = SKSpriteNode(texture: texture)
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                sprite.position = CGPoint(
                    x: CGFloat(i) * textureSize.width - screenSize.width / 2,
                    y: 0
                )
                sprite.alpha = config.opacity
                addChild(sprite)
                sprites.append(sprite)
                
                if config.animated {
                    addAnimationToSprite(sprite, asset: asset)
                }
            }
        } else {
            let sprite = SKSpriteNode(texture: texture)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            sprite.position = .zero
            sprite.alpha = config.opacity
            
            let scale = max(
                screenSize.width / texture.size().width,
                screenSize.height / texture.size().height
            ) * 1.2
            sprite.setScale(scale)
            
            addChild(sprite)
            sprites.append(sprite)
            
            if config.animated {
                addAnimationToSprite(sprite, asset: asset)
            }
        }
    }
    
    private func addAnimationToSprite(_ sprite: SKSpriteNode, asset: AssetCatalog.AssetType) {
        switch config.textureName {
        case "stars":
            addStarTwinkle(to: sprite)
        case "temple":
            addTorchFlickers(to: sprite, asset: asset)
        default:
            break
        }
    }
    
    private func addStarTwinkle(to sprite: SKSpriteNode) {
        let twinkle = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 2.0),
            SKAction.fadeAlpha(to: 1.0, duration: 2.0)
        ])
        
        let randomDelay = SKAction.wait(forDuration: Double.random(in: 0...3))
        let sequence = SKAction.sequence([randomDelay, SKAction.repeatForever(twinkle)])
        sprite.run(sequence)
    }
    
    private func addTorchFlickers(to sprite: SKSpriteNode, asset: AssetCatalog.AssetType) {
        for _ in 0..<3 {
            let torch = SKSpriteNode(color: .clear, size: CGSize(width: 16, height: 32))
            torch.position = CGPoint(
                x: CGFloat.random(in: -sprite.size.width/3...sprite.size.width/3),
                y: CGFloat.random(in: -sprite.size.height/4...0)
            )
            
            let flicker = AnimationBuilder.buildAnimation(
                from: EnvironmentAnimations.torchFlicker,
                asset: .effect(name: "torch")
            )
            torch.run(flicker)
            
            let glow = SKShapeNode(circleOfRadius: 12)
            glow.fillColor = AegisColorPalette.torchLight
            glow.strokeColor = .clear
            glow.blendMode = .add
            torch.addChild(glow)
            
            let glowPulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.4),
                SKAction.scale(to: 0.9, duration: 0.4)
            ])
            glow.run(SKAction.repeatForever(glowPulse))
            
            sprite.addChild(torch)
        }
    }
    
    func update(deltaTime: TimeInterval, baseSpeed: CGFloat) {
        animationTime += deltaTime
        
        if config.tileHorizontally {
            let scrollAmount = config.scrollSpeed * baseSpeed * CGFloat(deltaTime)
            currentOffset -= scrollAmount
            
            for sprite in sprites {
                sprite.position.x -= scrollAmount
                
                if let textureSize = sprite.texture?.size() {
                    if sprite.position.x < -screenSize.width/2 - textureSize.width {
                        sprite.position.x += textureSize.width * CGFloat(sprites.count)
                    }
                }
            }
        } else {
            let wobble = sin(animationTime * 0.5) * 2.0
            position.x = wobble * config.scrollSpeed
        }
    }
    
    func reset() {
        currentOffset = 0
        animationTime = 0
        
        if config.tileHorizontally {
            if let textureSize = sprites.first?.texture?.size() {
                for (i, sprite) in sprites.enumerated() {
                    sprite.position.x = CGFloat(i) * textureSize.width - screenSize.width / 2
                }
            }
        } else {
            position = .zero
        }
    }
}