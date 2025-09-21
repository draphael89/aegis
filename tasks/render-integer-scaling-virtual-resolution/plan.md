# Plan — render-integer-scaling-virtual-resolution

## Summary
- **What we’re building**: An integer scaling pipeline for `BattleScene` that enforces a 360×640 virtual canvas with letterboxing and nearest-neighbour rendering.
- **Why now**: Ensures pixel art stays crisp and aligns with AGENTS invariants (virtual resolution, no shimmer).
- **Definition of Done**:
  - Scene computes an integer scale factor based on view size, applies letterboxing, and positions the camera accordingly.
  - `PlacementGrid` uses the sim’s `fieldLengthTiles` (no hardcoded 30) and returns integer-coherent coordinates.
  - All SpriteKit textures (units, bands, HUD) enforce `.nearest` filtering.
  - Manual check on iPhone SE + iPhone 14/15 sims shows no shimmer during intro sweep / movement.

## Assumptions & Trade-offs
- Game runs in portrait only for vSlice; letterboxing will add side bars on taller/narrower devices.
- We can compute scaling each time `didChangeSize` fires; no need for dynamic orientation support yet.

## Invariants Touched
- Strengthens rendering invariant; no invariants relaxed.

## Design Overview
```
SpriteView.size -> BattleScene.onViewResize()
        |-> PixelScaler (compute integer scale, viewport rect)
        |-> camera.setScale(scale); camera.position = viewport.center
        |-> black letterbox nodes added/updated
PlacementGrid uses config.fieldLengthTiles (passed from sim)
```

## Changes by Module

### BattleRender
- Add a `PixelScaler` helper (struct) that takes `viewSize` and returns `(scale, viewport)` targeting 360×640.
- Update `BattleScene` to:
  - Use `.resizeAspect` or `.resizeFill` replaced by manual scaling via camera.
  - Override `didChangeSize(_:)` to recalc scaling whenever the view bounds change.
  - Add/adjust letterbox nodes (SKSpriteNode) to fill unused areas.
  - Ensure `cameraNode.setScale(scale)` and `cameraNode.position` center within viewport.
  - Replace hardcoded `placementGrid = PlacementGrid(configuration: configuration, fieldLength: 30)` with value pulled from `BattleConfig.fieldLengthTiles` (exposed via initializer param or injection).
- Ensure spawn nodes (`UnitNode`, lane bands) set texture filtering mode to `.nearest` if not already.

### CoreEngine / Config
- Expose `BattleConfig.fieldLengthTiles` to `BattleScene` via the existing configuration (already part of `BattleConfig`). Ensure the render config uses the same `fieldLength` from the sim.

### Tests / Verification
- Optional: add a lightweight unit test to check `PixelScaler` returns expected scale factors for common device sizes (e.g., 375×812 → scale=2).
- Manual QA: run on iPhone SE and iPhone 14/15 simulators; observe intro sweep and idle units for shimmer.

## API / Schema Changes
- None beyond new helper functions/structs.

## Perf Considerations
- Scaling math runs only when size changes; no per-frame overhead.
- Letterbox nodes are static (two SKSpriteNodes updated on size change).

## Risks & Mitigation
- Event order: ensure camera sweep SKAction still works after `setScale` (reapply actions if needed).
- Need to coordinate with SwiftUI overlays to ensure they still align (SpriteView handles using view size, so integer scaling doesn’t affect overlay layout).

## Timeline & Dependencies
- Estimated 0.5 day including manual simulator checks.
- No dependencies on pending tasks.

## Open Questions
1. Should we add a debug overlay with current scale factor? (nice-to-have).
