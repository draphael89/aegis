import CoreEngine
import Foundation

public enum ContentCatalogFactory {
    public static func makeVerticalSliceCatalog() -> ContentCatalog {
        let units = UnitDefinitions.archetypes()
        let spells = SpellDefinitions.all()
        let traps = TrapDefinitions.all()
        let artifacts = ArtifactDefinitions.all()
        let heroes = [HeroDefinitions.achilles(using: units)]
        let mapWeights = MapDefinitions.verticalSliceWeights()
        return ContentCatalog(
            units: units,
            spells: spells,
            traps: traps,
            artifacts: artifacts,
            heroes: heroes,
            mapWeights: mapWeights
        )
    }
}
