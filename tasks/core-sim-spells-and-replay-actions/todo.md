# TODO — core-sim-spells-and-replay-actions

- [x] Add SpellEffect/SpellArchetype/SpellTarget types and extend BattleState with spells hand + cast limit.
- [x] Extend ContentDatabase and ContentCatalog bridge to include spells.
- [x] Implement `BattleSimulation.cast`, spell effect helpers, rally cooldown adjustment, and replay action playback.
- [x] Provide `registerReplayActions` and consume actions at the start of each tick.
- [x] Add `SpellsTests` (heal clamp, fireball AoE) and new golden replay with actions (`baseline_casts.json`).
- [x] Update golden hashes (baseline + with casts).
- [x] `swift test --package-path Packages/CoreEngine`
- [x] `swift test --package-path Packages/MetaKit`
