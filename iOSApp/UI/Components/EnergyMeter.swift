import SwiftUI

struct EnergyMeter: View {
    let current: Int
    let maximum: Int
    
    @State private var coinRotation: Double = 0
    @State private var glowAnimation: Double = 0
    
    private var energyRatio: Double {
        guard maximum > 0 else { return 0 }
        return Double(current) / Double(maximum)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            energyCoin
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Energy")
                        .font(.custom("Press Start 2P", size: 10))
                        .foregroundColor(.aegisParchment)
                    
                    Text("\(current) / \(maximum)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(energyColor)
                }
                
                energyBar
            }
        }
        .padding(12)
        .background(backgroundPanel)
        .onAppear {
            startAnimations()
        }
    }
    
    private var energyCoin: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.aegisHighlightGold,
                            Color.aegisBronze
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.aegisHighlightGold,
                                    Color.aegisBronze.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .aegisShadowNavy.opacity(0.4), radius: 4, x: 0, y: 2)
            
            Image(systemName: "bolt.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.aegisParchment)
                .shadow(color: .aegisShadowNavy.opacity(0.5), radius: 2, x: 1, y: 1)
            
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    ),
                    lineWidth: 1
                )
                .frame(width: 36, height: 36)
        }
        .rotation3DEffect(
            .degrees(coinRotation),
            axis: (x: 0, y: 1, z: 0)
        )
        .overlay(
            Circle()
                .stroke(
                    Color.aegisHighlightGold.opacity(glowAnimation),
                    lineWidth: 2
                )
                .scaleEffect(1.0 + glowAnimation * 0.2)
                .blur(radius: 2)
        )
    }
    
    private var energyBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.aegisShadowNavy.opacity(0.3))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: energyGradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * energyRatio, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: energyRatio)
                
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.aegisBronze.opacity(0.5), lineWidth: 1)
                    .frame(height: 8)
                
                ForEach(0..<maximum, id: \.self) { index in
                    Rectangle()
                        .fill(Color.aegisShadowNavy.opacity(0.2))
                        .frame(width: 1, height: 6)
                        .position(
                            x: geometry.size.width * (Double(index + 1) / Double(maximum)),
                            y: 4
                        )
                }
            }
        }
        .frame(height: 8)
    }
    
    private var backgroundPanel: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [
                        Color.aegisShadowNavy.opacity(0.9),
                        Color.aegisNightBlue.opacity(0.8)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.aegisBronze.opacity(0.6),
                                Color.aegisBronze.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
    
    private var energyColor: Color {
        if energyRatio > 0.6 {
            return .aegisHighlightGold
        } else if energyRatio > 0.3 {
            return Color(red: 1.0, green: 0.8, blue: 0.2)
        } else {
            return .aegisCrimson
        }
    }
    
    private var energyGradientColors: [Color] {
        if energyRatio > 0.6 {
            return [
                Color.aegisHighlightGold,
                Color.aegisHighlightGold.opacity(0.8)
            ]
        } else if energyRatio > 0.3 {
            return [
                Color(red: 1.0, green: 0.8, blue: 0.2),
                Color(red: 1.0, green: 0.6, blue: 0.1)
            ]
        } else {
            return [
                Color.aegisCrimson,
                Color.aegisCrimson.opacity(0.8)
            ]
        }
    }
    
    private func startAnimations() {
        withAnimation(
            Animation
                .easeInOut(duration: 3)
                .repeatForever(autoreverses: false)
        ) {
            coinRotation = 360
        }
        
        withAnimation(
            Animation
                .easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
        ) {
            glowAnimation = 0.6
        }
    }
}