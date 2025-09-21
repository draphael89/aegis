import Foundation
import Testing
@testable import MetaKit

@Test("Vertical slice catalog validates cleanly")
func verticalSliceCatalogIsValid() {
    let catalog = ContentCatalogFactory.makeVerticalSliceCatalog()
    let issues = ContentValidator.validate(catalog: catalog)
    #expect(issues.filter { $0.severity == .error }.isEmpty)
}

@Test("Validator catches duplicate ids")
func validatorFlagsDuplicates() {
    let catalog = ContentCatalog(
        units: UnitDefinitions.archetypes() + [UnitDefinitions.archetypes().first!],
        spells: SpellDefinitions.all(),
        traps: TrapDefinitions.all(),
        artifacts: ArtifactDefinitions.all(),
        heroes: [HeroDefinitions.achilles(using: UnitDefinitions.archetypes())],
        mapWeights: MapDefinitions.verticalSliceWeights()
    )
    let issues = ContentValidator.validate(catalog: catalog)
    #expect(issues.contains { $0.message.contains("Duplicate unit id") })
}
