import BattleRender
import Combine
import CoreEngine
import MetaKit
import SpriteKit
import SwiftUI

final class BattleSceneCoordinator: NSObject, ObservableObject, BattleSceneDelegate {
    @Published var outcome: BattleOutcome?
    weak var runViewModel: RunViewModel?
    func battleScene(_ scene: BattleScene, didFinish outcome: BattleOutcome) {
        Task { @MainActor in
            runViewModel?.recordOutcome(outcome)
            switch outcome {
            case .victory:
                Haptics.success()
            case .defeat:
                Haptics.error()
            case .inProgress:
                break
            }
            self.outcome = outcome
        }
    }
}

struct BattleContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var run: RunViewModel

    let encounter: Encounter
    @StateObject private var coordinator = BattleSceneCoordinator()
    @State private var scene = BattleScene()
    @State private var hasPresentedBattle = false

    var body: some View {
        SpriteView(scene: scene, options: [.ignoresSiblingOrder])
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .background(Color.black)
            .onAppear {
                coordinator.runViewModel = run
                Haptics.light()
                configureSceneIfNeeded()
            }
            .onReceive(coordinator.$outcome.compactMap { $0 }) { _ in
                dismiss()
            }
    }

    @MainActor
    private func configureSceneIfNeeded() {
        guard !hasPresentedBattle else { return }
        scene.battleDelegate = coordinator
        do {
            try scene.presentBattle(setup: encounter.setup, catalog: run.catalog, seed: encounter.seed)
            scene.startIfNeeded()
            hasPresentedBattle = true
        } catch {
            assertionFailure("Failed to present battle: \(error)")
            dismiss()
        }
    }
}
