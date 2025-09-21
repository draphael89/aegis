import CoreEngine
import Foundation

public enum HeroDefinitions {
    public static func achilles(using units: [UnitArchetype]) -> HeroDefinition {
        let heroArchetype: UnitArchetype
        if let predefined = units.first(where: { $0.key == HeroKey.achilles }) {
            heroArchetype = predefined
        } else {
            heroArchetype = UnitArchetype(
                key: HeroKey.achilles,
                role: .melee,
                maxHP: 200,
                attack: 12,
                attackIntervalTicks: 60,
                rangeTiles: 1,
                speedTilesPerSecond: 2,
                cost: 0
            )
        }
        return HeroDefinition(
            id: HeroKey.achilles,
            displayName: "Achilles",
            archetype: heroArchetype,
            passiveDescription: "+10% attack speed to adjacent allies"
        )
    }
}
