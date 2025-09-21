# Plan — meta-prep-energy-placements

## Summary
Build a SwiftUI prep experience that lets the player assemble a lineup using energy/stance choices and produces a `BattleSetup` fed into `BattleSimulation`.

## Definition of Done
- `RunViewModel` exposes a `PrepState` with available cards (hero + base units), remaining energy (default 10), current placements (per lane/slot), and stance selection.
- New SwiftUI `PrepView` displays the hand, energy counter, and lane grid; supports tap-to-place (drag optional) and stance picker per placement.
- Prep completion constructs a `BattleSetup` and launches `BattleContainerView`; `RunViewModel.prepareEncounter` becomes `startPrep(for:)` + `commitPrep()`.
- Existing battle flow updated: map → prep → battle. Cancel dismisses without launching.
- Engine unchanged (`BattleSetup` shape identical). Determinism preserved by storing placements explicitly.
- Unit tests/snapshot tests: optional; at minimum run `swift test` for CoreEngine/MetaKit to ensure no regressions.

## Implementation Steps
1. **RunViewModel additions**
   - Define `PrepCard` (id, archetypeKey, cost, role, stance options).
   - Add `PrepState` struct with `remainingEnergy`, `placements`, `selectedCard`, etc.
   - Add state machine: `@Published var prepState: PrepState?`. `startPrep(node:)` populates deck (hero + sample units). `commitPrep()` builds `BattleSetup` and returns `Encounter` while clearing prep state.

2. **SwiftUI PrepView**
   - Display energy label and hand (horizontal list of buttons). Tapping selects a card.
   - Provide lane grid (3 lanes × 3 slots). Tapping empty slot places selected card (deduct energy); tapping occupied slot allows stance change or removal (if not hero).
   - Ensure hero card auto-placed first or locked to ensure hero present.
   - Buttons for `Start Battle` (enabled when hero placed) and `Cancel`.

3. **Integrate flow**
   - In map view (where nodes are listed), navigating to prep instead of directly to battle: e.g., present `PrepView` sheet/modal; on commit call `prepareEncounter` with `BattleSetup`.
   - `BattleContainerView` expects an `Encounter`; update to use new entry point.

4. **Energy rules**
   - Hero cost 0; other units use `UnitArchetype.cost` from catalog. Stances optional default.
   - Prevent placement if energy insufficient; show disabled state.

5. **Testing/QC**
   - Run `swift test` for existing packages (no changes expected).
   - Manual QA: ensure placements appear in battle as chosen; energy label in battle matches remaining energy.

## Risks & Mitigations
- UI complexity: start with taps, add drag later. Keep layout simple for phone portrait (VStack + Grid).
- Ensure hero forced: auto-place hero at mid slot or prevent removal.
- Transition logic: handle cancel/dismiss gracefully.
