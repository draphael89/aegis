# Plan — meta-map-dag-generator

## Goal
Generate a deterministic Slay-the-Spire–style map DAG using `MapNodeWeights`, expose it from MetaKit, and refactor the SwiftUI run flow to use the generated graph.

## Overview
1. **MetaKit (data layer)**
   - Introduce data structures for the map graph (nodes, columns, edges).
   - Implement a deterministic generator that produces a DAG with branching paths using `MapNodeWeights` and `SeedFactory`-like mixing.
   - Provide a helper on `ContentCatalog` to build the graph for a run seed.
2. **RunViewModel (app layer)**
   - Replace the static `[battle, battle, boss]` array with the generated graph.
   - Track the active column and unlock reachable nodes; maintain selections, completion state, and edges.
   - Expose UI-friendly models (e.g., `RunNodeViewModel`) while storing the full graph for persistence.
3. **UI updates**
   - Update `MapColumnView` (or add a new view) to display nodes grouped by column with selectable options based on edges from the current node.
   - Ensure lock/completion indicators remain consistent.
4. **Testing**
   - Add MetaKit unit tests covering graph shape, connectivity, boss column constraint, and determinism (same seed -> same graph).
   - Add a lightweight RunViewModel test (SwiftUI-independent) verifying navigation unlocks the next column correctly.

## Detailed steps
### 1. MetaKit graph types
- Create `Packages/MetaKit/Sources/MetaKit/MapGraph.swift` (new file) with:
  ```swift
  public struct MapNode: Identifiable, Codable, Sendable {
      public let id: UUID
      public let column: Int
      public let kind: BattleNodeType
      public var outgoing: [UUID]
      public init(id: UUID = UUID(), column: Int, kind: BattleNodeType, outgoing: [UUID] = []) { ... }
  }

  public struct MapGraph: Codable, Sendable {
      public let nodes: [MapNode]
      public let columns: Int
      public func nodes(in column: Int) -> [MapNode] { ... }
      public func node(with id: UUID) -> MapNode? { ... }
  }
  ```

### 2. Deterministic RNG helper
- Inside MetaKit (so we don’t import CoreEngine RNG), add a lightweight RNG using `SeedFactory.mix` pattern or re-use `SeedFactory` by exposing it via MetaKit import if allowed. Otherwise implement a simple SplitMix64 inline.

### 3. Generator implementation
- Add `public static func generateMap(using weights: MapNodeWeights, seed: UInt64) -> MapGraph` to `MapDefinitions`.
- Algorithm:
  1. Initialize RNG with `seed`.
  2. For column 0:
     - Create 1 or 2 nodes (ensure at least 2 start options by duplicating if weights yield only 1).
  3. For columns 1 .. weights.totalColumns - 2:
     - Determine node count (e.g., 2-3) using deterministic RNG.
     - For each node select `BattleNodeType` using the column weights (normalize weights to cumulative distribution).
  4. Column `totalColumns - 1`: create a single `.boss` node.
  5. Edges: ensure every node in column `i` has 1-2 outgoing edges to column `i+1` nodes; ensure every node in column `i+1` has at least one incoming edge by adding edges where missing.
  6. Guarantee at least two distinct start-to-boss paths (if RNG yields identical edges, adjust by redirecting one edge).
  7. Return `MapGraph` with assembled nodes.

### 4. ContentCatalog extension
- Add `public func makeMapGraph(runSeed: UInt64) -> MapGraph` to `ContentCatalog` in `ContentModels.swift`, delegating to `MapDefinitions.generateMap`. This keeps app code simple.

### 5. RunViewModel refactor
- Store the generated `MapGraph` (`private let mapGraph: MapGraph`).
- Replace `nodes: [RunNode]` initialization with nodes derived from column 0 (start column). Keep `RunNode.Kind` mapping from `BattleNodeType`.
- Track current column index and available node IDs.
- When a node is selected:
  - Generate `RunNode` view models for the next column using outgoing edges.
  - Mark the chosen path so the graph can be serialized later.
- Add helper `private func mapKindToRunKind(_:) -> RunNode.Kind`.
- Update `resolvePendingEncounter` to mark completion in the graph and unlock nodes referenced by outgoing edges.

### 6. UI adjustments
- Update `MapColumnView` to render the current column’s nodes (list). For VS, a simple vertical list with “Select” buttons is sufficient—the branching is controlled by the data.
- Display upcoming choices after completing a node; optionally show column index for clarity (not required in VS).

### 7. Tests
- Create `Packages/MetaKit/Tests/MetaKitTests/MapGraphTests.swift` with test cases:
  - `testBossColumn`: final column only contains `.boss`.
  - `testConnectivity`: each node in columns 1..N has at least one inbound edge.
  - `testDeterminism`: same seed -> identical graph, different seed -> graph differs (hash nodes).
- Add a minimal `RunViewModel` test (if feasible) verifying that selecting a start node surfaces next-column nodes.

### 8. Documentation & tasks
- Update `todo.md` with granular tasks (type definitions, RNG, generator, catalog extension, RunViewModel refactor, UI tweaks, tests).
- Record any open questions/assumptions after implementation.

## Considerations
- Keep the generator deterministic and value-type only; do not retain mutable global state.
- Prefetch map graph at app init (RunViewModel init) so map persists for the entire run (important for save/load later).
- Ensure `MapGraph` and Run state remain Codable-ready to align with future persistence task.
- When mapping `BattleNodeType` to rewards/encounters, we can initially treat unknown kinds as `.battle` until reward/shop views are implemented.

## Dependencies / Follow-up
- Task 7 (persistence) will serialize the map; design graph types with Codable.
- Later tasks (reward/shop) will use node kind to branch into new screens.
