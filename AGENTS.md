# iOS Autobattler — Best-of-Breed Developer Guide (SwiftUI + SpriteKit)

## TL;DR (Non-Negotiables)
- **Battlefield**: Hard 3 lanes × 3 slots (front/mid/back) for phone clarity. Micro offsets allowed. Soft-lane drift stays behind a flag for later.
- **Core Engine**: Pure Swift, 60 Hz integer ticks, seeded RNG, deterministic replays. No SpriteKit logic in the sim.
- **Stack**: SpriteKit for battle, SwiftUI for map/deck/shop, SwiftPM modules. SwiftData on iOS 17+, otherwise Codable.
- **Energy**: Start with 10. Hero deploy is free. Maximum 2 spell casts per battle.
- **Run Loop**: Slay-the-Spire DAG map, pick-1-of-3 rewards, shops, events, artifacts, boss.
- **Juice**: Hitstop on kills, 360×640 virtual canvas with nearest-neighbor scaling, particles, haptics, camera sweep.
- **Performance**: 60 fps on A14+, no per-tick allocations, object pools for nodes/FX.
- **Definition of Done**: Deterministic golden replays, two viable builds, stable 60 fps, crisp pixels, complete run loop.

## 1. Vision & Design Pillars
- **Player Promise**: "Every battle is a tight placement puzzle; every run is a mythic story of risk, loss, and clever synergy."
- **Pillars**: Small-screen clarity • Determinism • Parsimony • Juice • Data-driven content • Swift-native tooling.

## 2. Core Loop & Run Flow
1. Choose Hero (VS: Achilles).
2. Traverse 10–12 column DAG map (Battle / Elite / Event / Treasure / Shop → Boss).
3. Battle: pre-placement with 10 Energy; hero free; up to 2 spells; auto-resolve.
4. Rewards: pick 1 of 3 cards or gold; Treasure grants artifacts; Shops buy/remove.
5. Lose if Hero or Pyre dies. Heal to full between fights (VS), with Veteran permadeath (add fatigue later if desired).

## 3. Battlefield & Combat Rules
- Hard 3 lanes × 3 friendly slots; enemy mirrored.
- Drag cards to slots; stance options (Guard, Skirmish, Hunter) at placement.
- Micro offsets (±2–3 px) keep lines lively without pathfinding.
- One lane swap maneuver per battle for tactical spice.
- Pyres: 200 HP, slow ranged attack; victory on enemy wipeout + pyre destruction.

## 4. Vertical Slice Content Scope
- **Hero**: Achilles (200 HP, ATK 12, 60-tick attack interval, range 1, speed 2, passive +10 % attack speed to adjacent allies).
- **Units**: Spearman (melee), Archer (ranged), Healer (single-target). Veterans: Patroclus (melee variant with L2 perk choice; permadeath).
- **Spells**: Heal (25 HP single target, cost 2), Fireball (60 damage AoE, radius 1 tile, cost 3).
- **Traps**: Spikes (6 damage to first enemy entering lane, cost 1).
- **Artifacts**: Phalanx Crest (+3 armor front slot), Lyre of Apollo (heal 5 on ally kill to most wounded ally in lane).
- **Pyres**: 200 HP, 8 damage shot every 72 ticks, range to inner third of field.
- **Energy**: Start battles with 10, no mid-battle regen, hero free, 2 spells max.

## 5. Architecture (Swift-First)
- **Modules**: CoreEngine (pure Swift sim), BattleRender (SpriteKit projection), MetaKit (SwiftUI view models), plus iOS app target for UI/entry.
- **Separation**: CoreEngine has zero SpriteKit dependencies; SpriteKit scenes mirror CoreEngine state only.
- **Persistence**: SwiftData on iOS 17+, fall back to Codable JSON snapshots for broader support.
- **Build**: Use XcodeGen (`Scripts/gen.sh`) and SwiftPM packages. Treat project.yml as source of truth.

## 6. Determinism & RNG
- 60 Hz fixed timestep, integer ticks. No floating-point time math in CoreEngine.
- SplitMix64 RNG wrapper with deterministic per-encounter seeding.
- Golden replays: record {seed, placements, spell casts with tick}; re-sim and assert identical hashes.

## 7. Rendering & Pixel Pipeline
- Virtual canvas 360×640 with integer scaling/letterboxing to prevent shimmer.
- `texture.filteringMode = .nearest`; all positions snapped to integer pixels.
- Layering: terrain (0), lanes (5), units (10–20 ordered by y), particles (30), HUD (100+).
- Object pools for units, projectiles, damage numbers.
- Hitstop (60–120 ms) on kills, micro screen shake on pyre hits.
- Camera pre-roll: enemy → terrain → player base (~1.2 s).

## 8. Map Generation (STS-Style DAG)
- 10–12 columns, 2–4 nodes per column, single boss node at top.
- Weighted node types by depth; ensure at least two distinct paths.
- Guarantee each node in column N+1 has ≥1 incoming edge.

## 9. Meta UI & State Management
- SwiftUI NavigationStack: Map → Battle Prep → SpriteKit Battle → Reward/Shop → Map.
- ViewModel (or TCA reducer) owns RunState, handles intents, snapshots run progress.
- Accessibility: large touch targets, color-blind friendly palette, minimal HUD clutter.

## 10. Performance Budgets & Instrumentation
- 60 fps target (16.67 ms frame): Sim ≤2 ms, Draw ≤8 ms, FX/labels ≤3 ms.
- No per-tick allocations; prefer `ContiguousArray`/`Deque` for hot paths.
- Use `os_signpost` to measure sim/render phases; profile with Instruments (Time Profiler, Game Performance, Allocations).

## 11. Testing & Quality Gates
- Unit tests (CoreEngine targeting, statuses, map connectivity).
- SwiftUI snapshot tests (map, reward, shop).
- Golden replay tests in CI.
- Perf smoke test: scripted battle with 30–40 units sustains 60 fps on A14+.
- Lint/content validator must pass.

## 12. Content Authoring Workflow
- JSON/Swift tables in `AutobattlerApp/Content/`; validate in unit tests.
- Effect DSL keeps spells/artifacts declarative.
- Definition of Ready: data present, art assets available, validator updates, loot table entries, documented balance rationale.

## 13. Task Discipline (Agents & Humans)
- Each major task lives under `tasks/<id>/` with `research.md`, `plan.md`, optional `todo.md`.
- Follow Context → Plan → Execute rhythm, respecting invariants above.

## 14. Vertical Slice Acceptance
- Full run (≈10–20 min) is winnable/loseable, with two viable builds.
- Golden replays produce identical hashes.
- Stable 60 fps on A14+, no pixel shimmer.
- Adding a new unit/spell/artifact requires data + art only (no engine rewrites).

## 15. Roadmap After VS
- Additional heroes (Odysseus, Atalanta, Medea).
- Lane terrain bonuses, hazards, elite variants.
- Soft-lane drift experiments behind flag.
- Ascension levels, daily seeds, Game Center leaderboards.
- iCloud sync for meta progression.

Stay disciplined on determinism, pixels, and performance—everything else builds on that foundation.

## 16. Agent Operations & Workflow Discipline

### 16.1 Golden Rules
1. **Anchor to invariants** – 60 Hz integer ticks, seeded RNG, SpriteKit as view, 360×640 integer scaling, perf budgets: sim ≤2 ms, draw ≤8 ms, FX ≤3 ms.
2. **Reuse before inventing** – cite file paths and existing types in research; prefer extension over reinvention.
3. **Decide once, document once** – capture assumptions, trade-offs, and mitigations in `plan.md` before coding.
4. **Batch questions** – move forward with explicit assumptions; list open questions at the end of the plan.
5. **Design for rollback** – guard risky changes behind flags or keep old paths alive until replays pass.
6. **Small code, big tests** – keep diffs tight, expand tests (unit, snapshot, replay) aggressively.
7. **Measure early** – add `os_signpost` scopes and short Instruments traces when touching hot paths.
8. **Diff-oriented output** – prefer unified diffs for targeted files; avoid drive-by formatting.
9. **Eliminate accidental complexity** – no per-tick allocations, no floating-point time, no SpriteKit physics/pathfinding in combat.
10. **Ship the feel** – hitstop, numbers, haptics, and clarity matter as much as correctness.

### 16.2 Task Folder Structure (`tasks/<task-id>/`)
- `research.md` – reconnaissance, reuse targets, risks, batched questions.
- `plan.md` – blueprint, API/schema changes, tests, perf plan, DoD.
- `todo.md` (optional) – checklist derived from plan for execution tracking.
- Optional: `decisions.md`, `notes.md`, `metrics.md`, `artifacts/` (for traces, screenshots).

### 16.3 Templates

`research.md`
```
# Research — <task-id>

## Charter
- **Goal**: <outcome>
- **Scope**: <in/out bullets>
- **Success criteria**: <measurable tie to determinism/perf/UX>

## Codebase Recon
- CoreEngine: <files/types>
- BattleRender: <files/types>
- Meta/UI: <files/types>
- Content/Persistence: <files/types>

## Existing Patterns to Reuse
- Determinism: <seed/tick patterns>
- Pixel pipeline: <virtual res helpers>
- Testing: <replay harness, snapshot utilities>
- Perf: <signposts, profiling scripts>

## Constraints & Invariants
- <list applicable invariants from §1–10>

## External References
- <link – reason>

## Risks & Edge Cases
- <bullet list>

## Data / Telemetry Needed
- <metrics to capture>

## Batched Clarifying Questions
1. <question> – impact: <high/medium/low>
2. ...
```

`plan.md`
```
# Plan — <task-id>

## Summary
- **What**: <concise outcome>
- **Why**: <player/tech rationale>
- **Definition of Done**: <bullets, measurable>

## Assumptions & Trade-offs
- A1: <assumption> → fallback if false.
- Trade-off: <choice> vs <alternative> — consequences.

## Invariants Touched
- <none> OR <determinism/pixel/perf/etc.> — mitigation.

## Design Overview
```ascii
<optional diagram>
```

### CoreEngine
- <model/logic changes>
- Determinism notes.

### BattleRender
- <scene/node updates>
- Rendering rules (integer positions, pooling).

### Meta/UI
- <SwiftUI screens/state/persistence>

### Content/Persistence
- <data additions, validators, migrations>

## API / Schema Changes
- <list signatures/JSON keys>

## Test Plan
- Unit: <cases>
- Golden replay: <seeds, expected hashes>
- Snapshot/UI: <screens/states>
- Perf: <script + budget + measurement method>

## Telemetry / Debug Hooks
- <signposts, metrics>

## Rollout / Migration / Rollback
- Rollout: <flag/step>
- Migration: <data updates>
- Rollback: <how to revert safely>

## Risks & Mitigations
- R1: <risk> → mitigation/testing.

## Timeline & Dependencies
- <milestones, blockers>

## Open Questions
1. <question> – impact: <high/medium/low>
```

### 16.4 Execution Loop
1. Generate `plan.md` (with assumptions, tests, DoD) before changing code.
2. Derive `todo.md` from plan and work sequentially; update with status.
3. Maintain determinism: every behavioral change should have a replay hash update with rationale.
4. Bench perf when touching sim/rendering; attach traces in `artifacts/`.
5. Update plan/research on completion with actual outcomes and measurements.

### 16.5 Self-Critique Checklist (pre-review)
- [ ] Integer ticks only; seeded RNG paths unchanged or documented.
- [ ] SpriteKit changes are projection-only; CoreEngine remains platform agnostic.
- [ ] No new per-tick allocations; hot loops use pre-sized containers.
- [ ] Tests cover new behavior (unit + replay or snapshot).
- [ ] Perf measured (or explicitly deferred with rationale and ticket).
- [ ] Docs updated (`plan.md`, `decisions.md` if contracts changed, README/AGENTS if guidelines shift).
- [ ] Diff scoped to plan; unrelated churn removed.

### 16.6 Sample GPT-5 Codex Prompt Snippet
```
Role: Senior Swift/SpriteKit engineer.
Invariants: deterministic CoreEngine (60 Hz integer ticks), SpriteKit as view, 360×640 integer pixels, perf budget (sim ≤2 ms, draw ≤8 ms, FX ≤3 ms).
Task: <one sentence>.
Files allowed: <whitelist>.

Deliver:
1. Unified diff for allowed files.
2. Updated/new tests (unit, replay, snapshot).
3. 3–5 line determinism/perf note (seed, hash, measurement plan).

Constraints: no per-tick allocations, no floating-point time, maintain existing style & naming. Return diff + tests + note only.
```

### 16.7 Quality Gates Recap (must pass before merge)
- Golden replays updated and hashed.
- Unit / snapshot tests green.
- Profiling evidence (when perf-affecting) stored under `tasks/<id>/artifacts/`.
- Documentation refreshed (README/AGENTS if guidance changes).
- Plan’s Definition of Done satisfied and checked off.

### 16.8 When to Escalate vs Proceed
- **Escalate immediately** if you must break core invariants, add dependencies, or change OS baselines.
- **Proceed with assumptions** when changes are local, guarded, and backed by tests/metrics; document assumptions in plan.
