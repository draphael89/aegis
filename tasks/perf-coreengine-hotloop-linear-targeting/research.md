# Research — perf-coreengine-hotloop-linear-targeting

## Charter
- **Goal**: Remove per-tick allocations and `sorted` calls from the simulation hot loop while preserving deterministic behaviour.
- **Scope**: `BattleSimulation.acquireTargetsAndMove`, `selectTarget`, `frontUnit`, healer helper.
- **Success criteria**: Golden replays unchanged; `swift test` green; Instruments (manual) shows no dictionary copy/allocation per tick.

## Codebase Recon
- `BattleSimulation.acquireTargetsAndMove()` copies `state.units` into `updatedUnits` every tick, mutates, then assigns back — O(U) allocations.
- `selectTarget(for:)` builds `enemies` array and sorts lexicographically per unit per tick; `frontUnit(for:)` sorts to get the closest.
- Healer helper uses new `updatedUnits` map.
- `pendingAttacks` already reuses capacity (`removeAll(keepingCapacity: true)`).

## Constraints & Invariants
- Must keep deterministic order; rely on existing priority tuple (laneScore, stance bias, uuid string) to match behaviour.
- Integer math only; no randomness introduced.

## Risks
- Mutating dictionary while iterating could lead to stale references; we iterate using `state.orderedUnitIDs` and write back via `state.units[id] = unit`.
- Need to ensure healer updates allies in `state.units` in place.
- New helper functions must remain `Sendable` safe.

## Data to Collect
- After change, run Instruments (manual) to confirm zero allocations in `step` for smoke test (not automated yet).

## Batched Clarifying Questions
None — implementation local to engine.
