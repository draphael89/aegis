import Foundation
import SpriteKit
import SwiftUI

public struct AegisColorPalette {
    
    public static let midnightIndigo = SKColor(hex: 0x1B1D40)
    public static let nightBlue = SKColor(hex: 0x263572)
    public static let parchment = SKColor(hex: 0xF4E4C1)
    public static let bronze = SKColor(hex: 0xC47A40)
    public static let laurelGreen = SKColor(hex: 0x7AB46F)
    public static let crimson = SKColor(hex: 0xA64040)
    public static let stoneGray = SKColor(hex: 0x6A6D77)
    public static let highlightGold = SKColor(hex: 0xF7C15E)
    public static let shadowNavy = SKColor(hex: 0x0F1027)
    public static let cloudLavender = SKColor(hex: 0xB7B4D8)
    
    public static let marbleWhite = SKColor(hex: 0xF8F5F0)
    public static let olympusPurple = SKColor(hex: 0x6B4C8A)
    public static let aegeanTeal = SKColor(hex: 0x4A9B9B)
    public static let oliveBranch = SKColor(hex: 0x8B9556)
    public static let terracotta = SKColor(hex: 0xC66B3D)
    public static let amberGlow = SKColor(hex: 0xFFA500)
    public static let wineRed = SKColor(hex: 0x722F37)
    public static let ashGray = SKColor(hex: 0x4B4B4D)
    
    public static let torchLight = SKColor(hex: 0xFFD700).withAlphaComponent(0.8)
    public static let starlight = SKColor(hex: 0xE6E6FA).withAlphaComponent(0.9)
    public static let moonGlow = SKColor(hex: 0xCAE1FF).withAlphaComponent(0.6)
    
    public static let healthGreen = SKColor(hex: 0x5FDD5F)
    public static let healthYellow = SKColor(hex: 0xFFD23F)
    public static let healthRed = SKColor(hex: 0xDD5F5F)
    public static let energyBlue = SKColor(hex: 0x5F9FDD)
    public static let manaViolet = SKColor(hex: 0x9F5FDD)
    
    public static func teamColor(for team: Team) -> SKColor {
        switch team {
        case .player:
            return aegeanTeal
        case .enemy:
            return crimson
        }
    }
    
    public static func rarityColor(for rarity: RarityLevel) -> SKColor {
        switch rarity {
        case .common:
            return stoneGray
        case .uncommon:
            return laurelGreen
        case .rare:
            return energyBlue
        case .epic:
            return olympusPurple
        case .legendary:
            return highlightGold
        }
    }
    
    public static func damageTypeColor(for type: DamageType) -> SKColor {
        switch type {
        case .physical:
            return terracotta
        case .magical:
            return manaViolet
        case .fire:
            return amberGlow
        case .divine:
            return highlightGold
        case .poison:
            return laurelGreen
        }
    }
}

public enum RarityLevel {
    case common, uncommon, rare, epic, legendary
}

public enum DamageType {
    case physical, magical, fire, divine, poison
}

extension SKColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(hex & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

#if canImport(SwiftUI)
extension Color {
    public static let aegisMidnightIndigo = Color(SKColor(hex: 0x1B1D40))
    public static let aegisNightBlue = Color(SKColor(hex: 0x263572))
    public static let aegisParchment = Color(SKColor(hex: 0xF4E4C1))
    public static let aegisBronze = Color(SKColor(hex: 0xC47A40))
    public static let aegisLaurelGreen = Color(SKColor(hex: 0x7AB46F))
    public static let aegisCrimson = Color(SKColor(hex: 0xA64040))
    public static let aegisStoneGray = Color(SKColor(hex: 0x6A6D77))
    public static let aegisHighlightGold = Color(SKColor(hex: 0xF7C15E))
    public static let aegisShadowNavy = Color(SKColor(hex: 0x0F1027))
    public static let aegisCloudLavender = Color(SKColor(hex: 0xB7B4D8))
}
#endif