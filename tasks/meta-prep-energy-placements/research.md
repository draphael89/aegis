# Research — meta-prep-energy-placements

## Charter
- **Goal**: Replace `RunViewModel.defaultSetup` with a player-driven prep flow where units are chosen, placed, and energy is spent before each battle.

## Current state
- `RunViewModel` maintains a simple array of `RunNode`s and prepares encounters by injecting a static `BattleSetup` into `BattleContainerView`.
- No notion of deck/hand/placements in UI; energy is unused outside engine.
- `UnitPlacement` already carries stance, slot, lane, hero flag.

## Constraints
- Engine interface stays the same: prep returns a `BattleSetup` that feeds `BattleSimulation`.
- Keep prep determinism (the chosen placements become inputs to battle replays).
- Keep UX simple for vSlice: hero is free, limited set of unit cards, simple 3×3 grid per lane.

## Explorations needed
- How to surface archetypes + costs from `ContentCatalog` (use `catalog.units`).
- Represent prep deck/hand (struct with `UnitCard` view models).
- Interaction pattern: tap card → select lane/slot via popover or direct tap, fallback to `Picker` for stance.

## Risks
- Need to ensure hero must be placed and not removed.
- Need to handle energy updates and invalid placements gracefully (e.g., disable button when insufficient energy).
