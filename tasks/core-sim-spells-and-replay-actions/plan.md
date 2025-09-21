# Plan — core-sim-spells-and-replay-actions

## Summary
- **What we’re building**: A deterministic spell system (Heal, Fireball, Rally-ready), energy spend + 2-cast cap, and replay action playback.
- **Why**: Enables the limited-intervention pillar, lets replays cover mid-battle inputs, and unlocks future artifacts/passives.
- **Definition of Done**:
  - `ContentDatabase` stores spell archetypes/effects mapped from MetaKit definitions.
  - `BattleSimulation` exposes `cast(spellID:target:) -> Bool`, updates energy and applies effects (integer math, deterministic order). Rally modifies attack cooldown instead of damage.
  - Replay actions (`BattleReplay.Action.cast`) are executed automatically at the start of each tick before statuses.
  - Two new unit tests (Heal clamps to max HP, Fireball AoE deterministic) plus a golden replay with casts and pinned hash.
  - Existing tests/goldens (baseline/push) pass with updated hashes if necessary.

## Assumptions & Trade-offs
- For vSlice we keep spell roster minimal: Heal (single-unit target) and Fireball (lane point AoE). Rally support is wired but unused until content sets it.
- 2-cast limit per battle tracked via `BattleState` using a simple counter.
- Spell targeting uses `SpellTarget` enum (`unit`, `lanePoint`); replay lane/xTile supply the data for Fireball.
- UI integration is deferred; tests invoke `cast` directly.

## Changes by Module
- `Types.swift`
  - Add `SpellEffect`, `SpellArchetype`, `SpellTarget`, and extend `StatusEffect.rally` documentation.
- `BattleState.swift`
  - `ContentDatabase` gains `spells` map + initializer updates.
  - `BattleState` tracks `spellsHand` (simple array of spell IDs) and `castsRemaining` (default 2).
- `BattleSimulation`
  - Store `actionsByTick` when a replay is attached; add `registerReplay(_:)` helper.
  - On `step()`, apply actions for current tick before statuses.
  - Implement `cast(spellID:target:) -> Bool` that:
    1. Looks up archetype/effect
    2. Checks energy + castsRemaining + availability in hand
    3. Applies effect by mutating units/pyres deterministically
    4. Records energy/cast consumption
  - Refactor rally handling to adjust attack cooldown rather than damage (e.g. multiply cooldown by `(100 - boost)/100`).
- `BattleReplay`
  - `makeSimulation` invokes `registerReplay` and seeds action map.
- `MetaKit`
  - In `ContentCatalogFactory`, map `SpellDefinition` → new `SpellArchetype` + effect; update `ContentValidator` if required.

## Tests & Fixtures
- New unit test file `SpellsTests.swift` covering heal cap and deterministic fireball.
- Add replay fixture `baseline_casts.json` (or similar) with two cast actions; update `GoldenReplayTests` to include new fixture and expected hash.
- Existing golden hashes (baseline/push) may change due to rally semantics; capture new hashes after running tests.

## Verification Steps
1. `swift test --package-path Packages/CoreEngine`
2. `swift test --package-path Packages/MetaKit`
3. Update README/AGENTS if casting workflow requires notes.

## Follow-on (not in scope)
- UI spell buttons hooking into `cast`.
- Artifacts & hero aura leveraging the new hook.
