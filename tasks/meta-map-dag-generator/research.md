# Research — meta-map-dag-generator

## Scope
Implement a seeded Slay-the-Spire style map DAG using the existing MetaKit weights and wire it into the SwiftUI run flow.

## Codebase reconnaissance
- `Packages/MetaKit/Sources/MetaKit/MapDefinitions.swift`
  - Provides `verticalSliceWeights()` returning `MapNodeWeights` for 10 columns.
  - `MapNodeWeights.Column` exposes `columnIndex` and weight dictionary keyed by `BattleNodeType`.
- `MapNodeWeights` struct (in `ContentModels.swift`)
  - Holds `[Column]` and `totalColumns` but no graph generator.
- `RunViewModel` (`iOSApp/Game/RunModels.swift`)
  - Currently initializes `nodes` with `[battle, battle, boss]` and unlocks sequentially.
  - No concept of columns, edges, or multiple reachable choices.
  - `Encounter` seed uses `SeedFactory.encounterSeed(runSeed, floorIndex, nodeID)` so run seed is already available.
  - Prep / battle flow already set; map selection should feed into this.
- `SeedFactory` (CoreEngine) provides deterministic mixing utilities; we can reuse it in the MetaKit generator or create a lightweight RNG.
- No existing tests for map generation. `MetaKitTests` only exercise content catalog + validator.

## Patterns
- Determinism: other systems use `SeedFactory.mix` and integer math; follow same approach.
- Data layering: MetaKit builds content data, CoreEngine consumes pure Swift structs → generator should live in MetaKit and return a data-only graph the app caches.
- "Node" presentation: RunViewModel currently uses simple `RunNode` with `kind`, `isLocked`, `isCompleted`. We'll need additional metadata (column index, outgoing edges) without breaking existing UI.

## External references
- Slay the Spire map generation discussions emphasize DAG with branching paths, at least two options per column, and boss-only final column. We'll mirror minimal version (single start column, multiple choices per step).

## Open questions / assumptions
- Acceptable to surface 2-3 choices per row in UI? For vertical slice, column-based selection (choose next node among unlocked column) is sufficient.
- Inventory persistence (Task 7) will use the same graph structure later → design generator so it can be serialized.

## Next steps
- Define `MapNode` (`id`, `kind`, `column`, `[UUID] edges`) and `MapGraph` (columns, adjacency).
- Generator algorithm:
  1. For column 0 create start nodes (likely 1 or 2 choices) using weights.
  2. For columns 1..N-2 sample kinds based on weights.
  3. For final column N-1 force `.boss`.
  4. Wire edges: ensure each node in col i+1 has ≥1 inbound; keep at least two distinct paths overall.
  5. Use deterministic RNG seeded via `SeedFactory.mix(runSeed, columnIndex)`.
- Tests: connectivity (every column >0 node has incoming edge), boss-only final column, reproducibility (same seed -> identical graph).
