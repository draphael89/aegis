import Foundation

public struct BattleReplay: Codable {
    public struct Action: Codable, Equatable {
        public enum Kind: String, Codable {
            case cast
        }

        public let kind: Kind
        public let tick: Int
        public let identifier: String
        public let lane: Lane?
        public let xTile: Int?

        public init(kind: Kind, tick: Int, identifier: String, lane: Lane? = nil, xTile: Int? = nil) {
            self.kind = kind
            self.tick = tick
            self.identifier = identifier
            self.lane = lane
            self.xTile = xTile
        }
    }

    public let seed: UInt64
    public let setup: BattleSetup
    public let actions: [Action]

    public init(seed: UInt64, setup: BattleSetup, actions: [Action] = []) {
        self.seed = seed
        self.setup = setup
        self.actions = actions.sorted { $0.tick < $1.tick }
    }

    @discardableResult
    public func run(content: ContentDatabase, config: BattleConfig = BattleConfig()) throws -> BattleOutcome {
        let simulation = try makeSimulation(content: content, config: config)
        return simulation.simulateUntilFinished()
    }

    public func hashOutcome(content: ContentDatabase, config: BattleConfig = BattleConfig()) throws -> UInt64 {
        let simulation = try makeSimulation(content: content, config: config)
        simulation.simulateUntilFinished()
        return simulation.battleHash()
    }

    private func makeSimulation(content: ContentDatabase, config: BattleConfig) throws -> BattleSimulation {
        let simulation = try BattleSimulation(
            setup: setup,
            content: content,
            seed: seed,
            config: config
        )
        return simulation
    }
}
