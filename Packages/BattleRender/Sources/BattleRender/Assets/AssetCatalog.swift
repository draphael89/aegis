import Foundation
import SpriteKit

@MainActor
public final class AssetCatalog {
    public static let shared = AssetCatalog()
    
    private var textureCache: [String: SKTexture] = [:]
    private var atlasCache: [String: SKTextureAtlas] = [:]
    
    private init() {}
    
    public enum AssetType {
        case unit(name: String)
        case effect(name: String)
        case ui(name: String)
        case background(name: String)
        
        var atlasName: String {
            switch self {
            case .unit(let name): return "unit_\(name)"
            case .effect(let name): return "fx_\(name)"
            case .ui(let name): return "ui_\(name)"
            case .background(let name): return "bg_\(name)"
            }
        }
    }
    
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    public func preloadAssets() async {
        let atlasNames = [
            "unit_achilles",
            "unit_spearman",
            "unit_archer",
            "unit_healer",
            "unit_hoplite",
            "unit_beast",
            "fx_fireball",
            "fx_heal",
            "fx_lyre",
            "fx_spikes",
            "ui_buttons",
            "ui_frames",
            "ui_icons",
            "bg_temple",
            "bg_mountains",
            "bg_stars"
        ]
        
        await withTaskGroup(of: Void.self) { group in
            for name in atlasNames {
                group.addTask { [weak self] in
                    await self?.loadAtlas(named: name)
                }
            }
        }
    }
    
    @MainActor
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    private func loadAtlas(named name: String) async {
        let atlas = SKTextureAtlas(named: name)
        atlasCache[name] = atlas
        
        await withCheckedContinuation { continuation in
            atlas.preload {
                continuation.resume()
            }
        }
    }
    
    public func texture(for asset: AssetType, frame: String? = nil) -> SKTexture? {
        let atlasName = asset.atlasName
        let textureName = frame ?? "default"
        let cacheKey = "\(atlasName)_\(textureName)"
        
        if let cached = textureCache[cacheKey] {
            return cached
        }
        
        guard let atlas = atlasCache[atlasName] else {
            let atlas = SKTextureAtlas(named: atlasName)
            atlasCache[atlasName] = atlas
            let texture = atlas.textureNamed(textureName)
            texture.filteringMode = .nearest
            textureCache[cacheKey] = texture
            return texture
        }
        
        let texture = atlas.textureNamed(textureName)
        texture.filteringMode = .nearest
        textureCache[cacheKey] = texture
        return texture
    }
    
    public func textures(for asset: AssetType, prefix: String, count: Int) -> [SKTexture] {
        (0..<count).compactMap { index in
            texture(for: asset, frame: "\(prefix)_\(index)")
        }
    }
}
