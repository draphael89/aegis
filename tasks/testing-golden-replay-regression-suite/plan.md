# Plan — testing-golden-replay-regression-suite

## Summary
- **What we’re building**: Deterministic encounter seeding and a golden replay harness (record + replay) with CI tests.
- **Why now**: Locks determinism, enables regression detection, and supports future balance/perf tasks (aligns with AGENTS invariants).
- **Definition of Done**:
  - Run/encounter seeds derived deterministically (no random seeds).
  - Replays can be exported (JSON) including seed, setup, and action log.
  - `swift test` loads 2+ replay fixtures and asserts expected `battleHash()` values.
  - README/AGENTS updated with instructions to refresh golden hashes.

## Assumptions & Trade-offs
- For vSlice, only pre-battle placements (from setup) and spell casts need logging (no mid-battle unit deploys yet).
- Replays live under `Tests/Fixtures/Replays/` and are human-readable (JSON) for easy updates.

## Invariants Touched
- Determinism strengthened. No invariants relaxed.

## Design Overview
```
RunState
 ├─ runSeed (persisted)
 └─ encounterSeed = SeedFactory.mix(runSeed, floor, nodeID)
BattleReplay (CoreEngine)
 ├─ setup
 ├─ seed
 └─ actions [tick, action]
GoldenReplayTests
 └─ load fixture → run sim → compare battleHash()
```

## Changes by Module

### CoreEngine
- Extend `BattleReplay` with `actions: [Action]`, where `Action = .cast(spellID: String, target: SpellTarget, tick: Int)`.
- Add a `SeedFactory` helper (static functions) for deterministic seed derivation: `encounterSeed(runSeed: UInt64, floor: Int, nodeID: UUID)`.
- Update `BattleSimulation` to accept an optional action stream (applied during `step()` at matching ticks) and to emit actions via callback (for recording) once spell casting lands.
- Provide a `replay(_:)` function that returns `BattleOutcome` and `battleHash()`.

### Meta/UI
- `RunViewModel`:
  - Store `runSeed` when a new run starts (e.g. `UInt64.random` once, but persisted in `RunState`).
  - Replace `UInt64.random` encounter seeds with deterministic mix using `SeedFactory` (floor index + node id).
  - Provide a dev helper to dump replays (optional debug flag).

### Testing
- Create replay fixtures (initially two): `baseline.json`, `pyre_push.json`.
- Add `GoldenReplayTests` in `Packages/CoreEngine/Tests` that iterate fixtures, run replays, and assert final `battleHash()` + `BattleOutcome`.

## API / Schema Changes
- `BattleReplay.Action` enum and associated encoding.
- `SeedFactory` static utilities.
- `BattleSimulation(stepWithReplay:)` or equivalent to apply actions.

## Test Plan
- Unit: Replaying recorded fixture matches hash/outcome.
- Unit: Encounter seed derivation deterministic for same inputs.
- CI: `swift test` includes replay suite.

## Telemetry / Debug
- Add `#if DEBUG` export helper in `BattleContainerView` to write the last battle replay to `/tmp/aegis-replay.json` when running in dev.

## Rollout / Migration / Rollback
- Rollout: guard replay export behind debug until spells task is merged.
- Rollback: remove new test + revert `SeedFactory` if necessary.

## Risks & Mitigations
- Hash drift when mechanics change → update fixtures deliberately; document workflow.
- Spell-task dependency: ensure action format accommodates upcoming spells (SpellID + target data).

## Timeline & Dependencies
- Estimated 1 working day (including fixtures and docs).
- Dependent on Task 2 for richer actions, but current format can start with empty action arrays.

## Open Questions (Batched)
1. Should replays include RNG mix version so future changes can branch? (low)
2. Do we want CLI tooling to regenerate fixtures automatically? (low)
