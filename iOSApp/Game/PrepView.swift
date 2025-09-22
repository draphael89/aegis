import CoreEngine
import SwiftUI

struct PrepView: View {
    @EnvironmentObject private var run: RunViewModel
    @Environment(\.dismiss) private var dismiss

    let onStartBattle: (Encounter) -> Void

    private var prep: PrepState? { run.prepState }

    var body: some View {
        NavigationStack {
            if let prep {
                VStack(spacing: 16) {
                    energySection(prep)
                    deckSection(prep)
                    gridSection(prep)
                    Spacer()
                    actionButtons(prep)
                }
                .padding()
                .navigationTitle("Battle Prep")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            run.cancelPrep()
                            dismiss()
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.6))
            }
        }
    }

    private func energySection(_ prep: PrepState) -> some View {
        HStack {
            Text("Remaining Energy")
                .font(.headline)
            Spacer()
            Text("\(prep.remainingEnergy)")
                .font(.title).bold()
        }
    }

    private func deckSection(_ prep: PrepState) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(prep.deck) { card in
                    Button {
                        run.selectCard(card)
                    } label: {
                        VStack(spacing: 4) {
                            Text(run.displayName(for: card.archetype.key))
                                .font(.headline)
                            Text(card.isHero ? "Hero" : "Cost: \(card.cost)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(width: 120, height: 64)
                        .background(prep.selectedCardID == card.id ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func gridSection(_ prep: PrepState) -> some View {
        VStack(spacing: 12) {
            ForEach(Array(Lane.allCases.enumerated()), id: \.offset) { _, lane in
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { slotIndex in
                        let slot = PrepSlot(lane: lane, slot: slotIndex)
                        slotButton(slot: slot, prep: prep)
                    }
                }
            }
        }
    }

    private func slotButton(slot: PrepSlot, prep: PrepState) -> some View {
        let placement = prep.placement(for: slot)
        return Button {
            if prep.selectedCard != nil {
                run.placeSelectedCard(at: slot)
            } else {
                run.cycleStance(at: slot)
            }
        } label: {
            VStack(spacing: 6) {
                if let placement {
                    Text(run.displayName(for: placement.archetypeKey))
                        .font(.subheadline)
                        .bold()
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text("Stance: \(placement.stance.displayName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if !placement.isHero {
                        Text("Remove")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    } else {
                        Text("Hero")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("Empty")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .padding(8)
            .background(placementBackground(for: placement))
            .cornerRadius(12)
        }
        .simultaneousGesture(LongPressGesture().onEnded { _ in
            if let placement = placement, !placement.isHero {
                run.removePlacement(at: slot)
            }
        })
        .disabled(prep.selectedCard == nil && placement == nil)
    }

    private func placementBackground(for placement: UnitPlacement?) -> Color {
        guard let placement else { return Color.gray.opacity(0.12) }
        return placement.isHero ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2)
    }

    private func actionButtons(_ prep: PrepState) -> some View {
        VStack(spacing: 12) {
            Button {
                if let encounter = run.commitPrep() {
                    onStartBattle(encounter)
                    dismiss()
                }
            } label: {
                Text("Start Battle")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(prep.hasHeroPlaced ? Color.accentColor : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .disabled(!prep.hasHeroPlaced)
        }
    }
}

private extension Stance {
    var displayName: String {
        switch self {
        case .guard: return "Guard"
        case .skirmish: return "Skirmish"
        case .hunter: return "Hunter"
        }
    }
}
