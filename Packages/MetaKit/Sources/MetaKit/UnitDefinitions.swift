import CoreEngine
import Foundation

public enum UnitDefinitions {
    public static func archetypes() -> [UnitArchetype] {
        [
            UnitArchetype(
                key: UnitKey.spearman,
                role: .melee,
                maxHP: 60,
                attack: 8,
                attackIntervalTicks: 60,
                rangeTiles: 1,
                speedTilesPerSecond: 2,
                cost: 2
            ),
            UnitArchetype(
                key: UnitKey.archer,
                role: .ranged,
                maxHP: 40,
                attack: 7,
                attackIntervalTicks: 60,
                rangeTiles: 4,
                speedTilesPerSecond: 2,
                cost: 3
            ),
            UnitArchetype(
                key: UnitKey.healer,
                role: .healer,
                maxHP: 45,
                attack: 0,
                attackIntervalTicks: 45,
                rangeTiles: 4,
                speedTilesPerSecond: 2,
                cost: 3
            ),
            UnitArchetype(
                key: UnitKey.patroclus,
                role: .melee,
                maxHP: 80,
                attack: 10,
                attackIntervalTicks: 54,
                rangeTiles: 1,
                speedTilesPerSecond: 2,
                cost: 3
            ),
            UnitArchetype(
                key: HeroKey.achilles,
                role: .melee,
                maxHP: 200,
                attack: 12,
                attackIntervalTicks: 60,
                rangeTiles: 1,
                speedTilesPerSecond: 2,
                cost: 0
            )
        ]
    }
}
