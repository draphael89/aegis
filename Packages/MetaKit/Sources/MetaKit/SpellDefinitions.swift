import Foundation

public enum SpellDefinitions {
    public static func all() -> [SpellDefinition] {
        [
            SpellDefinition(
                id: SpellKey.heal,
                cost: 2,
                effect: .heal(amount: 25, radius: nil)
            ),
            SpellDefinition(
                id: SpellKey.fireball,
                cost: 3,
                effect: .fireball(damage: 60, radius: 1)
            )
        ]
    }
}

public enum TrapDefinitions {
    public static func all() -> [TrapDefinition] {
        [
            TrapDefinition(
                id: TrapKey.spikes,
                cost: 1,
                effect: .spikes(damage: 6)
            )
        ]
    }
}

public enum ArtifactDefinitions {
    public static func all() -> [ArtifactDefinition] {
        [
            ArtifactDefinition(
                id: ArtifactKey.phalanxCrest,
                effect: .frontSlotArmor(amount: 3),
                description: "+3 armor to front slot allies"
            ),
            ArtifactDefinition(
                id: ArtifactKey.lyreOfApollo,
                effect: .onKillHeal(amount: 5),
                description: "Allies heal 5 on kill in their lane"
            )
        ]
    }
}
