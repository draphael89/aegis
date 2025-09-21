import Foundation

public enum MapDefinitions {
    public static func verticalSliceWeights() -> MapNodeWeights {
        let totalColumns = 10
        let columns: [MapNodeWeights.Column] = (0..<totalColumns).map { column in
            let weights: [BattleNodeType: Double]
            switch column {
            case 0:
                weights = [.battle: 0.6, .event: 0.4]
            case 1, 2:
                weights = [.battle: 0.5, .event: 0.2, .treasure: 0.2, .shop: 0.1]
            case 3,4,5:
                weights = [.battle: 0.45, .elite: 0.25, .event: 0.15, .treasure: 0.1, .shop: 0.05]
            case 6,7:
                weights = [.battle: 0.4, .elite: 0.35, .event: 0.1, .treasure: 0.1, .shop: 0.05]
            case 8:
                weights = [.elite: 0.5, .treasure: 0.3, .shop: 0.2]
            default:
                weights = [.boss: 1.0]
            }
            return MapNodeWeights.Column(columnIndex: column, weights: weights)
        }
        return MapNodeWeights(columns: columns, totalColumns: totalColumns)
    }
}
