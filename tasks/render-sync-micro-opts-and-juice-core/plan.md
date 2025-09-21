# Plan — render-sync-micro-opts-and-juice-core

## Summary
Deliver pooled damage/heal numbers, short hitstop + pyre shake feedback, and healthbar update gating while keeping the SpriteKit scene pixel-perfect and allocation-free.

## Definition of Done
- `BattleScene` uses `.aspectFit` (fixed 360×640 canvas) and maintains a `cameraRestPosition` for shake offsets.
- Existing nodes only reconfigure health when HP changes; damage/heal deltas spawn pooled SKLabelNode numbers capped at 16 active instances.
- Unit deaths and pyre damage trigger a brief hitstop timer (≤120 ms) and micro camera shake; hitstop pauses sim stepping without freezing render.
- Pyre HP changes tracked via `lastPlayerPyreHP` / `lastEnemyPyreHP`.
- New timers (`hitstopTimer`, `shakeTimer`) managed deterministically inside `update`.
- Tests (`swift test` for CoreEngine/MetaKit) stay green.

## Verification Checklist
- Manually spawn a battle in the simulator: confirm crisp pixels, damage numbers, brief freeze on kills, pyre shake.<
- Ensure Instruments later shows no per-frame allocations (captured in perf task).
