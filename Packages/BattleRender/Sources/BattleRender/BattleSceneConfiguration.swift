import CoreEngine
import Foundation
import SpriteKit

public struct BattleSceneConfiguration: Sendable {
    public let canvasSize: CGSize
    public let laneWidth: CGFloat
    public let friendlyOrigin: CGPoint
    public let tileHeight: CGFloat

    public init(
        canvasSize: CGSize = CGSize(width: 360, height: 640),
        laneWidth: CGFloat = 96,
        friendlyOrigin: CGPoint = CGPoint(x: 72, y: 96),
        tileHeight: CGFloat = 36
    ) {
        self.canvasSize = canvasSize
        self.laneWidth = laneWidth
        self.friendlyOrigin = friendlyOrigin
        self.tileHeight = tileHeight
    }
}

struct PlacementGrid {
    let configuration: BattleSceneConfiguration
    let fieldLength: Int

    func position(for lane: Lane, slot: Int, xTile: Int) -> CGPoint {
        let laneIndex = CGFloat(lane.index)
        let x = configuration.friendlyOrigin.x + laneIndex * configuration.laneWidth
        let y = configuration.friendlyOrigin.y + CGFloat(slot) * configuration.tileHeight + CGFloat(xTile) * configuration.tileHeight / 2.0
        return CGPoint(x: round(x), y: round(y))
    }

    func bandRect(for lane: Lane) -> CGRect {
        let laneIndex = CGFloat(lane.index)
        let x = configuration.friendlyOrigin.x + laneIndex * configuration.laneWidth - configuration.laneWidth / 2.0
        return CGRect(x: x, y: 0, width: configuration.laneWidth, height: configuration.canvasSize.height)
    }
}
