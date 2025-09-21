# AGENTS.md — Long-Running Agentic Development Guide

## Purpose
This document standardises how agents (human or AI) execute multi-step, long-running development work in this codebase. It emphasises **determinism**, **clarity**, and **reuse of existing patterns** so that every large task converges to a high-quality, test-backed PR with minimal rework.

> **Core idea**: Each task lives under `tasks/<task-id>/`, leaving auditable breadcrumbs:
>
> - `research.md` → reconnaissance and findings
> - `plan.md` → implementation blueprint and acceptance criteria
> - `todo.md` (optional) → checklist generated from the plan
> - Optional companions: `decisions.md`, `notes.md`, `metrics.md`, `artifacts/`

---

## 0) Task Charter & Folder Layout

Create a folder for each task with a semantic slug:

```
tasks/<domain>-<feature>-<action>-<descriptor>
```

Examples: `tasks/core-sim-golden-replay-engine`, `tasks/render-integer-scaling-virtual-resolution`, `tasks/meta-map-dag-connectivity-guarantees`, `tasks/content-oracle-buffer-unit`.

**Required files (minimum)**

```
tasks/<task-id>/
  research.md   # What exists? What to reuse? Risks? Open questions (batched)
  plan.md       # Exact blueprint, API changes, test plan, perf gates, DoD
```

**Optional**

```
  todo.md       # Checklist auto-derived from plan; running status log
  decisions.md  # ADR-style record (why this, not that)
  notes.md      # Scratchpad for links, snippets, dead ends
  metrics.md    # Perf, determinism hashes, replay stats
  artifacts/    # Images, charts, logs, Instruments traces
```

---

## 1) Invariants & Guardrails (Project-Specific)

Agents **must** observe these constraints:

- **Deterministic Core** – 60 Hz integer ticks, seeded RNG, no floating-point time, golden replays must reproduce bit-for-bit outcomes.
- **Separation** – CoreEngine is pure Swift (no SpriteKit); SpriteKit is render-only.
- **Battlefield (VS)** – hard 3 lanes × 3 slots; micro offsets allowed; maximum 2 spells per battle.
- **Rendering** – virtual resolution 360×640, integer scaling, nearest-neighbour filtering; no pixel shimmer.
- **Performance budgets** (A14+ @ 60 fps) – sim ≤ 2 ms, draw ≤ 8 ms, FX/labels ≤ 3 ms; no per-tick allocations.
- **Tech limits** – no heavy pathfinding/physics in combat; no new engine frameworks without approval.
- **Content pipeline** – data-driven (JSON/Swift tables), validator tests, loot tables with rarity/floor gates.
- **Testing gates** – unit tests, SwiftUI snapshot tests, golden replay tests for determinism.

> If a task touches an invariant, document it under **“Invariants Touched”** in `plan.md` with explicit mitigation or an ADR proposal in `decisions.md`.

---

## 2) Task Lifecycle

### Phase A — Research → produce `research.md`

**Goals**
- Map relevant code & patterns, confirm reuse paths, surface risks and unknowns.
- Ask clarifying questions only when they materially change the plan; otherwise batch them at the end.

**Inputs**
- Task prompt / issue.
- Architecture, design, and style guides.

**Outputs**
- `research.md` capturing recon, reuse opportunities, constraints, risks, batched questions.

**Checklist**
- [ ] Inventory modules (CoreEngine / BattleRender / MetaKit / Persistence / Content).
- [ ] Identify existing types, render hooks, tests to reuse.
- [ ] Collect constraints (determinism, perf budgets, UX affordances).
- [ ] Note external references (official docs, standards) if needed.
- [ ] Draft batched clarifying questions (end of file).

### Phase B — Planning → produce `plan.md`

**Goals**
- Translate research into a testable, deterministic blueprint aligned with invariants.
- Provide enough detail that any engineer can implement without tribal knowledge.

**Outputs**
- `plan.md` describing solution, module changes, schemas/contracts, test/replay strategy, perf plan, Definition of Done, rollback.

**Checklist**
- [ ] Solution overview (ASCII diagram if helpful).
- [ ] API / data changes with backward-compatibility notes.
- [ ] How CoreEngine stays deterministic (integer ticks, seed handling).
- [ ] SpriteKit projection changes (render-only) and pixel rules.
- [ ] SwiftUI/meta changes (state, persistence, navigation).
- [ ] Tests: unit, snapshot, golden replay (with seeds/hashes).
- [ ] Perf and memory plan; measurement method (Instruments, `os_signpost`).
- [ ] Definition of Done (clear, measurable).
- [ ] Risks & mitigations.
- [ ] Open questions (batched).

### Phase C — Implementation → derive optional `todo.md`

**Rules**
- Generate a checklist from the plan and execute sequentially.
- Proceed with planned assumptions; batch non-blockers instead of stopping.
- Keep determinism (replays) and perf checks running locally/CI.

**Deliverables**
- Code changes + tests.
- Updated content / validators when relevant.
- Updated docs (README/AGENTS if behaviour changes).
- Passing CI including golden replays.

---

## 3) Clarifying Questions Policy

- Ask at kickoff only when the answer materially affects scope, OS baseline, or acceptance criteria.
- Otherwise document assumptions in `plan.md` and list the questions under **Open Questions**.
- For hard blockers (e.g. invariant conflict), raise a single grouped message referencing the relevant sections of `research.md` / `plan.md`.

---

## 4) Git & PR Conventions

- Branch name: `feature/<task-id>`
- Commit style: Conventional commits (`feat:`, `fix:`, `chore:`, `test:`, `perf:`).
- PR title: `[<task-id>] <short description>`
- PR body: link `research.md`, `plan.md`, metrics/snapshots/replays.
- Golden replays: update only with explanation and before/after hashes.

---

## 5) Quality Gates (CI)

- ✅ Build success (Debug/Release).
- ✅ Unit tests (CoreEngine), SwiftUI snapshot tests.
- ✅ Golden replay suite passes (no drift).
- ✅ Perf smoke: scripted battle with 30–40 units sustains 60 fps on A14 (log traces).
- ✅ Lint/format (if configured) and content validator succeed.

---

## 6) Task Templates

### `tasks/<task-id>/research.md`

```markdown
# Research — <task-id>

## Charter
- **Goal**: <one-sentence outcome>
- **Scope**: <in/out of scope, crisp bullets>
- **Success criteria**: <measurable; tie to perf/determinism/UX>

## Codebase Recon
- **Relevant modules**: <CoreEngine | BattleRender | MetaKit | Persistence | Content>
- **Key types/entries**:
  - CoreEngine: <types, functions, files> (e.g., `BattleSimulation.step`, `RNG`, `UnitArchetype`)
  - BattleRender: <scene/nodes hooks> (e.g., `BattleScene.syncNodesToSim`)
  - Meta/UI: <views/state> (e.g., `RunViewModel`, `MapView`)
  - Content: <tables, validators>

## Existing Patterns to Reuse
- Determinism: <seed derivation, batch resolve pattern>
- Pixel pipeline: <virtual res, nearest-neighbour, integer positions>
- Testing: <golden replay harness, snapshot tests>
- Perf: <`os_signpost` wrappers, Instruments bookmarks>

## Constraints & Invariants (project)
- Deterministic Core (60 Hz ticks; integer math)
- Separation (CoreEngine logic vs SpriteKit view)
- Battlefield VS model (3 lanes × 3 slots)
- Rendering (360×640 virtual, integer scaling)
- Perf budgets (sim ≤ 2 ms; draw ≤ 8 ms; FX ≤ 3 ms; no per-tick allocs)
- Tech limits (no combat pathfinding/physics)

## External References (if relevant)
- <link + 1-sentence why; prefer official docs/specs>

## Risks & Edge Cases
- <e.g., changing attack intervals risks replay drift>
- <e.g., integer scaling interactions with camera zoom>

## Data to Collect (if any)
- <metrics or logs needed to inform the plan>

## Batched Clarifying Questions
1) <question> — impact: <high/medium/low>
2) ...
```

### `tasks/<task-id>/plan.md`

````markdown
# Plan — <task-id>

## Summary
- **What we’re building**: <clear outcome>
- **Why now**: <business/gameplay rationale>
- **Definition of Done**: <bullet list, measurable>

## Assumptions & Trade-offs
- <assumption> (fallback if wrong)
- <choice> vs <alternative> — we choose X because <reason>; consequences: <…>

## Invariants Touched
- <none> OR
- <determinism/perf/pixel scaling/etc.> — mitigation: <how we guarantee>

## Design Overview
```ascii
<optional diagram showing modules touched and data flow>
```

## Changes by Module

### CoreEngine (pure Swift)
- <model/logic changes>
- Determinism notes.

### BattleRender (SpriteKit)
- <scene/node updates>
- Rendering rules (integer positions, pooling).

### Meta/UI (SwiftUI)
- <view/state changes, navigation, persistence>

### Content
- <data additions, validators, loot table updates>

## API / Schema Changes
- <list signatures/JSON keys>

## Test Plan
- Unit tests: <cases>
- Golden replays: <seeds, expected hashes>
- Snapshot/UI: <screens/states>
- Perf checks: <script + budget + measurement method>

## Telemetry / Debug
- <`os_signpost`, logging, metrics to capture>

## Rollout / Migration / Rollback
- Rollout: <flag/step>
- Migration: <content/save adjustments>
- Rollback: <how to revert safely>

## Risks & Mitigations
- R1: <risk> → <mitigation/testing>
- ...

## Timeline & Dependencies
- <milestones, external blockers>

## Open Questions (Batched)
1. <question> — impact: <high/medium/low>
2. ...
````

### Optional `tasks/<task-id>/todo.md`

```markdown
# TODO — <task-id>

- [ ] Scaffold branch `feature/<task-id>`
- [ ] Update content tables + validator test
- [ ] CoreEngine: implement <feature>; unit tests pass
- [ ] BattleRender: render projection; integer positions tested
- [ ] Meta/UI: state & screens; snapshot tests updated
- [ ] Golden replays: new/updated seeds & expected hashes
- [ ] Perf run on A14: 60 fps sustained; attach trace in artifacts/
- [ ] Update docs (README/AGENTS) if behaviour changes
- [ ] Open PR with links to research.md / plan.md / metrics.md
```

---

## 7) Encouraged Agent Behaviours

- Front-load research; prefer reuse over invention. Cite file paths and symbols.
- Design once, implement many: centralise contracts in the plan, then execute.
- Batch questions; proceed with documented assumptions.
- Protect determinism: avoid new randomness/time sources; keep integer ticks.
- Instrument early: add `os_signpost` + short Instruments recipe for new hot paths.
- Close the loop: attach replay hashes, snapshots, perf notes to the PR.

---

## 8) Example Task IDs (seed backlog)

- `core-sim-status-burn-integer-durations`
- `render-damage-numbers-cap-and-pooling`
- `meta-map-shop-remove-service-pricing`
- `content-artifact-aegis-shard-impl`
- `perf-allocate-freeze-audit-battle-scene`
- `testing-golden-replay-regression-suite`

---

## 9) That’s it

Use this guide to drive a consistent **Research → Plan → Execute → Verify → Document** rhythm while safeguarding determinism, pixel clarity, and performance. Create your folder under `tasks/`, drop in `research.md` and `plan.md` using the templates above, and go.

---

## Appendix A – Project Foundation Reference (SwiftUI + SpriteKit)

The sections below summarise the current best-of-breed project blueprint so every agent shares the same architectural context.

### A1. TL;DR (Non-Negotiables)
- **Battlefield**: hard 3 lanes × 3 slots; micro offsets allowed; soft-lane drift behind a flag.
- **Core Engine**: pure Swift, 60 Hz integer ticks, seeded RNG, deterministic replays; no SpriteKit logic.
- **Stack**: SpriteKit for battle, SwiftUI for map/deck/shop, SwiftPM modules; SwiftData on iOS 17+, otherwise Codable.
- **Energy**: start battles with 10; hero deploy is free; max 2 spell casts per battle.
- **Run Loop**: Slay-the-Spire DAG map, pick-1-of-3 rewards, shops, events, artifacts, boss.
- **Juice**: hitstop on kills, 360×640 virtual canvas with nearest-neighbour scaling, particles, haptics, camera sweep.
- **Performance**: 60 fps on A14+, no per-tick allocations, object pools for nodes/FX.
- **Definition of Done**: deterministic golden replays, two viable builds, stable 60 fps, crisp pixels, full run loop.

### A2. Vision & Design Pillars
- Player promise: “Every battle is a tight placement puzzle; every run is a mythic story of risk, loss, and clever synergy.”
- Pillars: small-screen clarity • determinism • parsimony • juice • data-driven content • Swift-native tooling.

### A3. Core Loop & Run Flow
1. Choose hero (VS: Achilles).
2. Traverse 10–12 column DAG map (Battle / Elite / Event / Treasure / Shop → Boss).
3. Battle: pre-placement with 10 energy; hero free; up to 2 spells; auto-resolve.
4. Rewards: pick 1 of 3 cards or gold; Treasure grants artifacts; Shops buy/remove.
5. Lose if hero or pyre dies; heal to full between fights; veterans have permadeath (fatigue later if desired).

### A4. Battlefield & Combat Rules
- Hard 3 lanes × 3 friendly slots; enemy mirrored.
- Drag cards to slots; choose stance (Guard, Skirmish, Hunter).
- Micro offsets (±2–3 px) for visual life.
- One lane swap manoeuvre per battle.
- Pyres: 200 HP, slow ranged attack; win by destroying enemy units + pyre.

### A5. Vertical Slice Content Scope
- **Hero**: Achilles (200 HP, ATK 12, 60-tick interval, range 1, speed 2, +10 % attack speed aura).
- **Units**: Spearman (melee), Archer (ranged), Healer (single target).
- **Veteran**: Patroclus (melee variant with L2 perk choice; permadeath).
- **Spells**: Heal (25 HP, cost 2), Fireball (60 damage AoE, radius 1 tile, cost 3).
- **Trap**: Spikes (6 damage on entry, cost 1).
- **Artifacts**: Phalanx Crest (+3 armour front slot), Lyre of Apollo (heal 5 on ally kill in lane).
- **Pyres**: 200 HP, 8 damage shot every 72 ticks, inner-third range.
- **Energy**: start 10, no regen, hero free, 2 spells max.

### A6. Architecture (Swift-First)
- CoreEngine (pure Swift sim), BattleRender (SpriteKit projection), MetaKit (SwiftUI view models), iOS app target for UI/entry.
- Persistence: SwiftData on iOS 17+, otherwise Codable snapshots.
- Build: XcodeGen + SwiftPM; project.yml is source of truth.

### A7. Determinism & RNG
- Fixed 60 Hz tick, integer math.
- SplitMix64 RNG; per-encounter seeding via run seed + floor + node id.
- Golden replays: record {seed, placements, spell casts with tick}; assert identical hash.

### A8. Rendering & Pixel Pipeline
- Virtual canvas 360×640, integer scaling/letterboxing.
- `texture.filteringMode = .nearest`, integer positions.
- Layering: terrain 0, lanes 5, units 10–20 (Y-ordered), particles 30, HUD 100+.
- Pool nodes for units/projectiles/damage numbers.
- Hitstop 60–120 ms, micro shake on pyre hits; camera pre-roll enemy → field → base.

### A9. Map Generation (STS-Style DAG)
- 10–12 columns, 2–4 nodes per column, boss at top.
- Weighted node types by depth; guarantee ≥ 2 distinct paths and ≥ 1 incoming edge per node.

### A10. Meta UI & State
- SwiftUI NavigationStack: Map → Battle Prep → Battle → Reward/Shop → Map.
- ViewModel (or TCA reducer) owns RunState, handles intents, snapshots run progress.
- Accessibility: large touch targets, colour-blind palette, minimal HUD clutter.

### A11. Performance Budgets & Instrumentation
- 60 fps target; sim ≤ 2 ms, draw ≤ 8 ms, FX ≤ 3 ms.
- No per-tick allocations; prefer `ContiguousArray`/`Deque`.
- Use `os_signpost`, profile with Instruments (Time Profiler, Allocations, Game Performance).

### A12. Testing & Quality Gates
- Unit tests (targeting, statuses, map connectivity).
- SwiftUI snapshot tests.
- Golden replay tests.
- Perf smoke test (30–40 units @ 60 fps).
- Validators and lint.

### A13. Content Authoring Workflow
- JSON/Swift tables in `AutobattlerApp/Content/`; validate via unit tests.
- Effect DSL keeps spells/artifacts declarative.
- Definition of Ready: data present, art assets ready, validators updated, loot table entries documented.

### A14. Vertical Slice Acceptance
- Full run (~10–20 min) winnable/loseable with two viable builds.
- Golden replays identical.
- Stable 60 fps on A14+, crisp pixels.
- Adding content requires data + art only (no engine rewrite).

### A15. Roadmap After VS
- Additional heroes (Odysseus, Atalanta, Medea).
- Lane terrain bonuses, hazards, elite variants.
- Soft-lane drift experiments behind flag.
- Ascension levels, daily seeds, Game Center leaderboards.
- iCloud sync for meta progression.

---

## Appendix B – Advanced Operations & Meta-Cognition

> Use this section to drive recursive autonomy, GPT-5 Codex prompts, and continuous verification. It complements the main guide without replacing it.

### B1. Extended Golden Rules (reinforces §1)
1. Anchor to invariants (determinism, separation, pixel policy, perf budgets).
2. Reuse before inventing; cite paths in research.
3. Decide once, document once in the plan.
4. Batch questions; act under documented assumptions.
5. Design for rollback (flags, preserved replays).
6. Keep code diffs small, tests comprehensive.
7. Measure early (signposts, short traces).
8. Make review-friendly diffs.
9. Avoid accidental complexity (no timers, no combat physics/pathfinding).
10. Ship the feel (hitstop, haptics, numbers, clarity).

### B2. Recursive Loops
- **Task Loop**: Research → Plan → Implement → Verify → Document.
- **Commit Loop**: Propose → Change → Prove → Polish.
- **Debug Loop**: Reproduce → Isolate → Instrument → Fix → Re-prove.

### B3. GPT-5 Codex Prompt Pattern
```
Role: Senior Swift/SpriteKit engineer.
Invariants: deterministic CoreEngine (60 Hz integer ticks), SpriteKit render-only, 360×640 integer pixels, perf budget sim ≤2 ms / draw ≤8 ms / FX ≤3 ms.
Task: <one sentence>.
Files allowed: <whitelist>.
Deliver: unified diff(s), updated tests, 3–5 line determinism/perf note, schema update if needed.
Constraints: no per-tick allocs, no floating-point time, maintain style.
Self-check: determinism preserved? SpriteKit projection-only? Perf budget intact? Tests added?
```

### B4. Diff-Only Output Request
```
Return only:
1) Unified diff(s) for these files: <paths>.
2) New tests (paths + contents).
3) 5-line determinism/perf note (seed, hash, measurement plan).

Do not:
- Modify files not listed.
- Introduce new dependencies.
- Use floating-point time or SKActions for logic.
```

### B5. Self-Critique Checklist (pre-review)
- [ ] Integer ticks only; RNG seeding untouched or documented.
- [ ] SpriteKit changes are projection-only.
- [ ] No new per-tick allocations or hot-loop regressions.
- [ ] Tests cover behaviour (unit + replay or snapshot).
- [ ] Perf measured (or explicitly deferred with ticket).
- [ ] Docs updated (`plan.md`, `decisions.md`, README/AGENTS if needed).
- [ ] Diff scoped to the plan; no unrelated churn.

### B6. Quality Gates Recap
- Golden replays updated with hashes.
- Unit/snapshot tests green.
- Perf trace captured when budgets affected.
- Documentation refreshed; decisions recorded.
- DoD satisfied and checked off in the plan.

### B7. Escalate vs Proceed
- **Escalate immediately** for invariant breaks, new dependencies/OS baseline changes, or broad replay invalidation.
- **Proceed with assumptions** when guarded, local, and covered by tests/metrics; document assumptions in the plan.

### B8. Final Meta-Checklist
- [ ] Reused existing patterns and cited them.
- [ ] Plan crafted with measurable DoD.
- [ ] Integer ticks + seeded RNG preserved.
- [ ] SpriteKit remains projection-only.
- [ ] Added/updated tests (unit + replay or snapshot).
- [ ] Captured perf trace (or justified deferral).
- [ ] Diff is small, readable, and fully explained.
- [ ] Invariant changes documented with mitigations/flags.

Use this appendix as your inner voice when orchestrating complex, multi-step tasks. Keep efforts small, prove them with tests and measurements, and let the codebase evolve through auditable, deterministic steps.
