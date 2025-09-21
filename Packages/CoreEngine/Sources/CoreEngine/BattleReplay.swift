import Foundation

public struct BattleReplay: Codable {
    public let seed: UInt64
    public let setup: BattleSetup

    public init(seed: UInt64, setup: BattleSetup) {
        self.seed = seed
        self.setup = setup
    }

    @discardableResult
    public func run(content: ContentDatabase, config: BattleConfig = BattleConfig()) throws -> BattleOutcome {
        let simulation = try BattleSimulation(
            setup: setup,
            content: content,
            seed: seed,
            config: config
        )
        return simulation.simulateUntilFinished()
    }

    public func hashOutcome(content: ContentDatabase, config: BattleConfig = BattleConfig()) throws -> UInt64 {
        let simulation = try BattleSimulation(
            setup: setup,
            content: content,
            seed: seed,
            config: config
        )
        simulation.simulateUntilFinished()
        return simulation.battleHash()
    }
}
