import BattleRender
import CoreEngine
import MetaKit
import SwiftUI

@main
struct AegisApp: App {
    @StateObject private var runViewModel = RunViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(runViewModel)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var run: RunViewModel
    @State private var showingPrep = false
    @State private var showingBattle = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Trials of Olympus")
                        .font(.largeTitle).bold()
                    Text("Vertical slice loop")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                MapColumnView(nodes: run.nodes) { node in
                    run.startPrep(for: node)
                    showingPrep = true
                }
                if let outcome = run.lastOutcome {
                    Text(outcomeText(outcome))
                        .font(.headline)
                        .foregroundStyle(outcome == .victory ? .green : .red)
                        .transition(.opacity)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Run Overview")
            .sheet(isPresented: $showingPrep, onDismiss: {
                if run.prepState != nil {
                    run.cancelPrep()
                }
            }) {
                PrepView { _ in
                    showingBattle = true
                }
                .environmentObject(run)
            }
            .sheet(isPresented: $showingBattle, onDismiss: {
                run.resolvePendingEncounter()
            }) {
                if let encounter = run.activeEncounter {
                    BattleContainerView(encounter: encounter)
                        .environmentObject(run)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func outcomeText(_ outcome: BattleOutcome) -> String {
        switch outcome {
        case .victory: return "Victory!"
        case .defeat: return "Defeat"
        case .inProgress: return "Battle ongoing"
        }
    }
}

struct MapColumnView: View {
    let nodes: [RunNode]
    let onSelect: (RunNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Path")
                .font(.title3)
                .bold()
            ForEach(nodes) { node in
                Button {
                    onSelect(node)
                } label: {
                    HStack {
                        Text(node.displayName)
                        Spacer()
                        if node.isCompleted {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else if node.isLocked {
                            Image(systemName: "lock.fill").foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.15)))
                }
                .disabled(node.isLocked || node.isCompleted)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
