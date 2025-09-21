# Research — testing-golden-replay-regression-suite

## Charter
- **Goal**: Add a golden replay harness so battles can be recorded and replayed with deterministic hashes.
- **Scope**: Deterministic seed derivation (run → node → encounter), minimal action log (placements + spell casts), record/load JSON replays, CI test coverage.
- **Success criteria**: Given the same replay inputs, `BattleSimulation` produces the same `battleHash()` and digest across runs; `swift test` fails on drift.

## Codebase Recon
- **CoreEngine**
  - RNG & tick loop: `Packages/CoreEngine/Sources/CoreEngine/RNG.swift`, `BattleSimulation.step()`.
  - Digest/hash support: `BattleSimulation.battleHash()` and `BattleState.digest()` in `BattleState.swift`.
  - `BattleReplay.swift` currently exists but only stores seed + setup; no action logging or replay logic.
  - `BattleState` tracks placements via `BattleSetup`; no spells/artifacts yet.
- **Meta/UI**
  - `RunViewModel.prepareEncounter(for:)` seeds encounters using `UInt64.random(in:)`, breaking determinism.
  - `RunViewModel` stores a simple `[RunNode]` without map seeding (future task).
  - `BattleContainerView` starts battles with `(setup, catalog, seed)` but doesn’t capture actions.
- **Testing**
  - `CoreEngineTests` cover deterministic hash check for identical seeds but no golden replay fixtures.

## Existing Patterns to Reuse
- 60 Hz integer tick loop in `BattleSimulation`.
- `battleHash()` for final equality check.
- Codable `BattleSetup` and `Pyre` structs for persistence.

## Constraints & Invariants
- Deterministic core (no wall clock, no random beyond seeded RNG).
- SpriteKit stays view-only; record/replay sits in CoreEngine + meta layers.
- Replay format should be compact and integer-friendly.

## Risks & Edge Cases
- Need to log user actions (spell casts once Task 2 lands) with tick timing to reproduce exactly.
- Hashes will change as mechanics change; must document how to update.

## Data to Collect
- Expected hashes for at least two canonical encounters (baseline battle, future elite/boss once content lands).
- Replay JSON fixtures and stored metadata (tick count, energy left) for debugging.

## Batched Clarifying Questions
1. Should run seeds persist across app launches (e.g. via SwiftData) or reset per session? — impact: medium
2. Are spell casts the only in-battle actions we need to log for vSlice? — impact: low
