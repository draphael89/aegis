import SwiftUI
import CoreEngine

struct BattleHUD: View {
    @ObservedObject var battleState: BattleStateViewModel
    
    var body: some View {
        VStack {
            topBar
            Spacer()
            bottomControls
        }
        .animation(.easeInOut(duration: 0.3), value: battleState.currentEnergy)
    }
    
    private var topBar: some View {
        HStack {
            pyreHealth(team: .player)
            
            Spacer()
            
            turnIndicator
            
            Spacer()
            
            pyreHealth(team: .enemy)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    private var bottomControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                EnergyMeter(
                    current: battleState.currentEnergy,
                    maximum: battleState.maxEnergy
                )
                .frame(width: 200)
                
                Spacer()
                
                spellSlots
                
                Spacer()
                
                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(hudBackground)
        }
    }
    
    private func pyreHealth(team: Team) -> some View {
        VStack(spacing: 4) {
            Text(team == .player ? "Your Pyre" : "Enemy Pyre")
                .font(.custom("Press Start 2P", size: 8))
                .foregroundColor(.aegisParchment)
            
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 24))
                    .foregroundColor(pyreFlameColor(team: team))
                    .shadow(color: pyreFlameColor(team: team).opacity(0.6), radius: 4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(pyreHP(team: team))")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    pyreHealthBar(team: team)
                        .frame(width: 100, height: 6)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.aegisShadowNavy.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(pyreFlameColor(team: team).opacity(0.5), lineWidth: 1)
                    )
            )
        }
    }
    
    private func pyreHealthBar(team: Team) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black.opacity(0.5))
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [
                                pyreFlameColor(team: team),
                                pyreFlameColor(team: team).opacity(0.7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * pyreHealthRatio(team: team))
                    .animation(.easeInOut(duration: 0.3), value: pyreHealthRatio(team: team))
            }
        }
    }
    
    private var turnIndicator: some View {
        VStack(spacing: 4) {
            Text("Turn \(battleState.currentTurn)")
                .font(.custom("Press Start 2P", size: 10))
                .foregroundColor(.aegisHighlightGold)
            
            Text("Phase: \(battleState.phase.displayName)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.aegisParchment.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.aegisShadowNavy.opacity(0.9))
                .overlay(
                    Capsule()
                        .stroke(Color.aegisHighlightGold.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    private var spellSlots: some View {
        HStack(spacing: 12) {
            ForEach(battleState.availableSpells) { spell in
                SpellSlot(
                    spell: spell,
                    isAvailable: battleState.canCastSpell(spell),
                    action: {
                        battleState.selectSpell(spell)
                    }
                )
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 8) {
            if battleState.skirmishAvailable {
                BronzeButton("Skirmish") {
                    battleState.activateSkirmish()
                }
                .frame(width: 140)
            }
            
            BronzeButton("End Turn", isEnabled: battleState.canEndTurn) {
                battleState.endTurn()
            }
            .frame(width: 140)
        }
    }
    
    private var hudBackground: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 20,
            topTrailingRadius: 20
        )
        .fill(
            LinearGradient(
                colors: [
                    Color.aegisShadowNavy.opacity(0.95),
                    Color.aegisNightBlue.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                topTrailingRadius: 20
            )
            .stroke(
                LinearGradient(
                    colors: [
                        Color.aegisBronze.opacity(0.6),
                        Color.aegisBronze.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 2
            )
        )
        .shadow(color: .aegisShadowNavy.opacity(0.5), radius: 10, x: 0, y: -5)
    }
    
    private func pyreFlameColor(team: Team) -> Color {
        team == .player ? .aegisAegeanTeal : .aegisCrimson
    }
    
    private func pyreHP(team: Team) -> Int {
        team == .player ? battleState.playerPyreHP : battleState.enemyPyreHP
    }
    
    private func pyreHealthRatio(team: Team) -> Double {
        let current = Double(pyreHP(team: team))
        let max = Double(team == .player ? battleState.playerPyreMaxHP : battleState.enemyPyreMaxHP)
        guard max > 0 else { return 0 }
        return current / max
    }
}

struct SpellSlot: View {
    let spell: SpellInfo
    let isAvailable: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(slotBackground)
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor, lineWidth: 2)
                        )
                    
                    Image(spell.iconName)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 32, height: 32)
                        .opacity(isAvailable ? 1.0 : 0.3)
                }
                
                HStack(spacing: 2) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 10))
                    Text("\(spell.cost)")
                        .font(.custom("Press Start 2P", size: 8))
                }
                .foregroundColor(costColor)
            }
        }
        .disabled(!isAvailable)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering && isAvailable
        }
    }
    
    private var slotBackground: LinearGradient {
        if isAvailable {
            return LinearGradient(
                colors: [
                    Color.aegisNightBlue.opacity(0.8),
                    Color.aegisNightBlue.opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.aegisStoneGray.opacity(0.4),
                    Color.aegisStoneGray.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var borderColor: LinearGradient {
        LinearGradient(
            colors: [
                isAvailable ? Color.aegisHighlightGold : Color.aegisStoneGray,
                isAvailable ? Color.aegisBronze : Color.aegisStoneGray.opacity(0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var costColor: Color {
        isAvailable ? .aegisHighlightGold : .aegisStoneGray
    }
}

class BattleStateViewModel: ObservableObject {
    @Published var currentEnergy: Int = 10
    @Published var maxEnergy: Int = 10
    @Published var currentTurn: Int = 1
    @Published var phase: BattlePhase = .preparation
    @Published var playerPyreHP: Int = 200
    @Published var playerPyreMaxHP: Int = 200
    @Published var enemyPyreHP: Int = 200
    @Published var enemyPyreMaxHP: Int = 200
    @Published var skirmishAvailable: Bool = true
    @Published var canEndTurn: Bool = true
    @Published var availableSpells: [SpellInfo] = []
    
    func canCastSpell(_ spell: SpellInfo) -> Bool {
        currentEnergy >= spell.cost
    }
    
    func selectSpell(_ spell: SpellInfo) {
        guard canCastSpell(spell) else { return }
        currentEnergy -= spell.cost
    }
    
    func activateSkirmish() {
        skirmishAvailable = false
    }
    
    func endTurn() {
        currentTurn += 1
    }
}

struct SpellInfo: Identifiable {
    let id: String
    let name: String
    let iconName: String
    let cost: Int
}

enum BattlePhase {
    case preparation
    case combat
    case resolution
    
    var displayName: String {
        switch self {
        case .preparation: return "Prep"
        case .combat: return "Battle"
        case .resolution: return "End"
        }
    }
}