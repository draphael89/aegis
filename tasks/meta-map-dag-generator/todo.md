# TODO — meta-map-dag-generator

- [x] Add `MapNode` / `MapGraph` structs in `Packages/MetaKit/Sources/MetaKit/MapGraph.swift` (id, column, kind, outgoing edges).
- [x] Implement deterministic RNG helper for MetaKit map generation.
- [x] Extend `MapDefinitions` with `generateMap(using:seed:)` producing a branching DAG per plan.
- [x] Update `ContentCatalog` with `makeMapGraph(runSeed:)` helper.
- [x] Refactor `RunViewModel` to store the generated `MapGraph`, map it to `RunNode` view models, and drive column progression.
- [x] Adjust `MapColumnView` (or reuse) to render the current column’s selectable nodes (relying on `isLocked`).
- [x] Write MetaKit tests (`MapGraphTests`) covering boss column, connectivity, and determinism.
- [ ] (Optional) Add lightweight RunViewModel test verifying column advancement.
- [ ] Manual QA: start run, select different first-column nodes, ensure next column choices update and seeds remain consistent.
