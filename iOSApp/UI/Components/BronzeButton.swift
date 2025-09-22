import SwiftUI

struct BronzeButton: View {
    let title: String
    let action: () -> Void
    let isEnabled: Bool
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if isEnabled {
                Haptics.light()
                action()
            }
        }) {
            ZStack {
                bronzeFrame
                
                Text(title)
                    .font(.custom("Press Start 2P", size: 12))
                    .foregroundColor(textColor)
                    .shadow(color: .black.opacity(0.5), radius: 1, x: 1, y: 1)
            }
        }
        .disabled(!isEnabled)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var bronzeFrame: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(backgroundGradient)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderGradient, lineWidth: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(innerHighlight, lineWidth: 1)
                    .padding(2)
            )
            .shadow(color: shadowColor, radius: 4, x: 0, y: 2)
            .frame(minHeight: 44)
            .padding(.horizontal, 16)
    }
    
    private var backgroundGradient: LinearGradient {
        if !isEnabled {
            return LinearGradient(
                colors: [
                    Color.aegisStoneGray.opacity(0.3),
                    Color.aegisStoneGray.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        
        if isHovered || isPressed {
            return LinearGradient(
                colors: [
                    Color.aegisHighlightGold.opacity(0.4),
                    Color.aegisBronze.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        
        return LinearGradient(
            colors: [
                Color.aegisBronze.opacity(0.6),
                Color.aegisBronze.opacity(0.4)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                isEnabled ? Color.aegisBronze : Color.aegisStoneGray,
                isEnabled ? Color.aegisBronze.opacity(0.7) : Color.aegisStoneGray.opacity(0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var innerHighlight: LinearGradient {
        LinearGradient(
            colors: [
                Color.aegisHighlightGold.opacity(isEnabled ? 0.3 : 0.1),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .center
        )
    }
    
    private var textColor: Color {
        if !isEnabled {
            return .aegisStoneGray
        }
        return isHovered ? .aegisHighlightGold : .aegisParchment
    }
    
    private var shadowColor: Color {
        isEnabled ? .aegisShadowNavy.opacity(0.4) : .clear
    }
}

struct BronzeButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}