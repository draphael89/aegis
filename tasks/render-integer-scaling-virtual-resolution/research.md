# Research — render-integer-scaling-virtual-resolution

## Charter
- **Goal**: Guarantee crisp pixels on every device by enforcing a 360×640 virtual canvas with integer scaling and letterboxing inside `BattleScene`.
- **Scope**: SpriteKit view/camera config, placement grid math, rounding checks. No art asset work.
- **Success criteria**: Scene renders at an integer scale factor on iPhone simulators (e.g., SE, 13/14/15). No shimmer during camera sweep or unit movement.

## Codebase Recon
- `BattleScene` (Packages/BattleRender/Sources/BattleRender/BattleScene.swift):
  - Scene initialized with `size: configuration.canvasSize` (360×640) but uses `scaleMode = .resizeFill` (causes non-integer scaling).
  - Camera node (`cameraNode`) exists; positioned at center; intro sweep uses `SKAction.move`.
  - Lane bands/energy label added directly to scene/camera.
- `SpriteView` (iOSApp/Game/BattleContainerView.swift): embeds the scene without custom `preferredFramesPerSecond` or scaling overrides.
- `PlacementGrid` (BattleSceneConfiguration.swift): computes positions using configuration but `fieldLength` is hard-coded to 30; the sim uses `BattleConfig.fieldLengthTiles` (also 30 today, but should align programmatically).
- No helper for integer scaling; textures set to `.nearest` manually when nodes created.

## Existing Patterns to Reuse
- `BattleSceneConfiguration` already expresses `canvasSize`, `laneWidth`, etc. We'll extend it with scaling math.
- `cameraNode` already in use; we can set its `setScale` and position.
- `PlacementGrid.position` rounds using `round()`; we can keep rounding but must ensure the base coordinate system is integer scaled.

## Constraints & Invariants
- Virtual canvas must remain 360×640 as per design guide.
- SpriteKit must use nearest neighbor filtering and integer pixel centers after scaling.
- Maintain existing intro camera sweep and lane layout.

## Risks & Edge Cases
- Need to handle cases where device < virtual size (rare; mostly iPad?). We can fall back to scale 1 with letterbox.
- Letterboxing requires background color fill to avoid shader artifacts.
- Must ensure HUD (SwiftUI overlays) still align with SpriteKit frame.

## Data / Checks
- Manual verification on iPhone SE (2nd gen) and iPhone 14/15 simulators (landscape?).
- Optionally snapshot test to ensure camera scale integer.

## Batched Clarifying Questions
1. Do we need to support landscape? (Currently portrait only) — Impact: low.
2. Should letterbox color be configurable? (Probably just black) — Impact: low.
