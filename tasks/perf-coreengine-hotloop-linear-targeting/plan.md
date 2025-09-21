# Plan — perf-coreengine-hotloop-linear-targeting

## Summary
- **What we’re building**: In-place state mutation and linear target selection in the battle sim hot loop.
- **Why**: Removes per-tick dictionary copies and O(U log U) sorting overhead; keeps sim ≤ 2 ms.
- **Definition of Done**:
  - `acquireTargetsAndMove` mutates `state.units` in place (no `updatedUnits` copy).
  - `selectTarget` and `frontUnit` become single-pass linear scans with equivalent priority ordering.
  - Healer helper updates units directly (no external map parameter).
  - `swift test --package-path Packages/CoreEngine` passes (golden hashes unchanged).

## Assumptions & Trade-offs
- Priority tuple ordering remains (laneScore, stanceBias, UUID string) to ensure identical behaviour.
- Accept a small cost of constructing `uuidString` per candidate (already incurred previously during sort comparison).

## Changes by Module
- `BattleSimulation.acquireTargetsAndMove`: remove `updatedUnits` map; mutate units via `state.units[unitID] = unit`.
- `BattleSimulation.healerAction`: refactor to mutate `state.units` directly.
- `selectTarget(for:)`: rewrite to linear iteration over `state.units.values`, capturing best candidate by tuple comparison.
- `selectHealTarget`: linear pass returning best wounded ally without building arrays.
- `frontUnit(for:)`: linear scan against `state.units` rather than `sorted`.
- Ensure helper functions are private extensions for readability.

## Tests & Verification
- `swift test --package-path Packages/CoreEngine` (includes golden replays) — ensures determinism preserved.
- Manual Instruments smoke (not automated) to confirm no per-tick allocations (tracked separately).

## Risks & Mitigations
- Mutation during iteration addressed by iterating over `state.orderedUnitIDs` (stable order) and writing back after local mutation.
- If priority tuple logic changes inadvertently, golden tests catch drift.
