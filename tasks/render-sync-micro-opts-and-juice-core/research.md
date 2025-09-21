# Research — render-sync-micro-opts-and-juice-core

## Charter
- **Goal**: Reduce per-frame work in the SpriteKit scene and add essential cosmetic feedback (damage numbers, hitstop, pyre shake) without compromising determinism or pixel fidelity.

## Observations
- `BattleScene.syncNodes` reconfigured every unit each tick, rebuilding health bar paths even when HP was unchanged.
- No pooled damage/heal numbers; only a flash + hit effect when HP dropped.
- No hitstop timer or camera shake for kills/pyre hits; camera scale mode `.resizeFill` could cause non-integer scaling on devices with PixelScaler letterboxing.
- Existing `NodePool` already in place for units and hit spark; easy to extend for labels.
- Haptics are handled in the app layer; BattleRender focuses on visuals only.

## Constraints
- Maintain integer 360×640 canvas; rely on PixelScaler for letterboxing.
- Keep all new feedback deterministic (purely visual, random offset allowed as it doesn’t influence sim state).
- Respect `NodePool` reuse patterns; avoid per-frame allocations.

## Plan Summary
- Switch `scaleMode` to `.aspectFit`, keep camera rest position and intro sweep.
- Track last HP per unit so `UnitNode.updateHealth` only runs on change; spawn pooled damage numbers on delta.
- Introduce hitstop timer, camera shake event hooks (unit death, pyre damage).
- Add pyre HP tracking to trigger shake/hitstop and small feedback.
