import CoreEngine
import Foundation

public struct ValidationIssue: Sendable, Equatable, CustomStringConvertible {
    public enum Severity: String, Sendable {
        case error
        case warning
    }

    public let severity: Severity
    public let message: String

    public init(severity: Severity, message: String) {
        self.severity = severity
        self.message = message
    }

    public var description: String { "\(severity.rawValue.uppercased()): \(message)" }
}

public enum ContentValidator {
    public static func validate(catalog: ContentCatalog) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        issues.append(contentsOf: checkUnique(keys: catalog.units.map(\.key), kind: "unit"))
        issues.append(contentsOf: checkUnique(keys: catalog.spells.map(\.id), kind: "spell"))
        issues.append(contentsOf: checkUnique(keys: catalog.traps.map(\.id), kind: "trap"))
        issues.append(contentsOf: checkUnique(keys: catalog.artifacts.map(\.id), kind: "artifact"))
        issues.append(contentsOf: checkUnique(keys: catalog.heroes.map(\.id), kind: "hero"))

        for unit in catalog.units {
            if unit.maxHP <= 0 {
                issues.append(.init(severity: .error, message: "Unit \(unit.key) must have positive HP"))
            }
            if unit.attackIntervalTicks <= 0 {
                issues.append(.init(severity: .error, message: "Unit \(unit.key) must have positive attack interval"))
            }
            if unit.speedTilesPerSecond < 0 {
                issues.append(.init(severity: .error, message: "Unit \(unit.key) has negative speed"))
            }
        }

        for spell in catalog.spells where spell.cost < 0 {
            issues.append(.init(severity: .error, message: "Spell \(spell.id) has negative cost"))
        }

        for trap in catalog.traps where trap.cost < 0 {
            issues.append(.init(severity: .error, message: "Trap \(trap.id) has negative cost"))
        }

        for hero in catalog.heroes {
            if !catalog.units.contains(where: { $0.key == hero.archetype.key }) {
                issues.append(.init(severity: .warning, message: "Hero \(hero.id) archetype \(hero.archetype.key) not present in unit catalog"))
            }
        }

        // Map weights: ensure boss column exists and each column contains boss only at last.
        if catalog.mapWeights.totalColumns <= 0 {
            issues.append(.init(severity: .error, message: "Map must have at least one column"))
        }
        if let last = catalog.mapWeights.columns.last {
            if last.weights[.boss] != 1.0 {
                issues.append(.init(severity: .warning, message: "Final column should be boss-only"))
            }
        }

        return issues
    }

    private static func checkUnique(keys: [String], kind: String) -> [ValidationIssue] {
        var seen: Set<String> = []
        var issues: [ValidationIssue] = []
        for key in keys {
            if !seen.insert(key).inserted {
                issues.append(.init(severity: .error, message: "Duplicate \(kind) id: \(key)"))
            }
        }
        return issues
    }
}
