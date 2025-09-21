# Research — core-sim-spells-and-replay-actions

## Charter
- **Goal**: Bring Heal and Fireball online in the deterministic core, consume seeds/actions in `BattleReplay`, and enforce energy/cast limits so replays cover mid-battle inputs.
- **Scope**: CoreEngine (`Types`, `BattleState`, `BattleSimulation`, `BattleReplay`), MetaKit content mapping, new unit/golden tests.
- **Success**: Two-cast cap per battle with energy spend, spells applied deterministically, replay actions executed before each tick, all existing goldens passing plus a new "with actions" golden.

## Codebase Recon
- `BattleState.energyRemaining` exists but is never mutated; spells are not implemented.
- `ContentDatabase` only stores unit archetypes; `MetaKit` provides spell definitions (`SpellDefinition`, etc.) but they never reach the engine.
- `BattleReplay.Action.cast` exists (identifier, lane, xTile) yet `BattleReplay.makeSimulation` ignores actions entirely.
- `StatusEffect.rally` currently adds a damage boost in `modifiedDamage`; per design docs rally should affect attack speed (cooldown).
- No spell tests or golden fixtures include actions.

## Constraints & Invariants
- 60 Hz fixed step; no floating point time. Spell effects must be integer math, applied in a stable order (before movement and damage but after statuses). Replay application must not introduce additional randomness.
- Hydrate spells via content pipeline (MetaKit → ContentDatabase) without coupling UI.
- Limit to initial vSlice scope: Heal (single or small radius), Fireball (lane radius AoE). Rally can be stubbed but the effect plumbing should allow it later.

## Risks & Notes
- Need to define a small `SpellEffect` DSL inside CoreEngine that mirrors MetaKit while remaining `Sendable`.
- Replay actions should be executed before statuses or after? To keep determinism and match expectations, apply at the start of `step()` before statuses so healing/damage influences the current tick consistently.
- Update to rally semantics (attack-speed modifier) will change golden hashes; capture the new hash after implementation.
- UI currently lacks spell buttons—fine for now; tests will call `cast` directly.

## Dependencies
- None external; uses existing RNG and data structures.
