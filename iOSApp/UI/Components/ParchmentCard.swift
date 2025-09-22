import SwiftUI
import CoreEngine

struct ParchmentCard: View {
    let title: String
    let subtitle: String?
    let cost: Int?
    let portrait: String?
    let isSelected: Bool
    let isHero: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            parchmentBackground
            
            VStack(spacing: 4) {
                if let portrait = portrait {
                    portraitView(portrait)
                        .frame(width: 64, height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.aegisShadowNavy.opacity(0.3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(borderColor, lineWidth: 2)
                        )
                }
                
                Text(title)
                    .font(.custom("Press Start 2P", size: 10))
                    .foregroundColor(.aegisShadowNavy)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.aegisStoneGray)
                }
                
                if !isHero {
                    if let cost = cost {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.aegisHighlightGold)
                            Text("\(cost)")
                                .font(.custom("Press Start 2P", size: 12))
                                .foregroundColor(.aegisShadowNavy)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.aegisHighlightGold.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.aegisHighlightGold.opacity(0.5), lineWidth: 1)
                                )
                        )
                    }
                } else {
                    heroIndicator
                }
            }
            .padding(12)
        }
        .frame(width: 140, height: 180)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var parchmentBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.aegisParchment,
                            Color.aegisParchment.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image("parchment_texture")
                        .resizable()
                        .opacity(0.3)
                        .blendMode(.multiply)
                )
            
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            borderColor,
                            borderColor.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: isSelected ? 3 : 2
                )
            
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.aegisHighlightGold.opacity(0.4), lineWidth: 1)
                    .padding(2)
            }
        }
        .shadow(color: .aegisShadowNavy.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    private func portraitView(_ imageName: String) -> some View {
        Image(imageName)
            .resizable()
            .interpolation(.none)
            .aspectRatio(contentMode: .fit)
    }
    
    private var heroIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.system(size: 12))
                .foregroundColor(.aegisHighlightGold)
            Text("HERO")
                .font(.custom("Press Start 2P", size: 8))
                .foregroundColor(.aegisHighlightGold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.aegisHighlightGold.opacity(0.3),
                            Color.aegisHighlightGold.opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.aegisHighlightGold, lineWidth: 1)
                )
        )
    }
    
    private var borderColor: Color {
        if isSelected {
            return .aegisHighlightGold
        } else if isHero {
            return .aegisOlympusPurple
        } else {
            return .aegisBronze
        }
    }
}