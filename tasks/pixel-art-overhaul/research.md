# Research — pixel-art-overhaul

## Current Visual State (Screenshots 7.46–7.47)
- **Run Overview**: default SF font, white cards, no thematic visuals.
- **Prep View**: system buttons, blank background, no sense of space or narrative.
- **Battle HUD** (not shown, inferred): minimal overlays, flat colors.
- Aesthetic lacks cohesion, palette, typography; no Greek myth tone.

## Repo Structure & Entry Points
- `iOSApp/Game/RunModels.swift`, `PrepView.swift`, `BattleContainerView.swift` for SwiftUI layers.
- `Packages/BattleRender/Sources/BattleRender/` for SpriteKit scene.
- `Assets.xcassets` currently unused for custom art.
- `Theme` not defined; using default SwiftUI colors.

## Engineering Constraints
- Pixel-perfect rendering (SpriteKit with `.nearest`, `isAntialiased = false`).
- Deterministic engine tick; must ensure animations/perf keep 60fps.
- Need to preserve existing tests (replay determinism, map). Visual update should be purely presentational.

## References / Goals
- Slay the Spire / Darkest Dungeon style map (branching path, parchment).
- Octopath Traveler / Sea of Stars for warm pixel backgrounds.
- Greek myth palette: indigo night (Pantone 2766C), bronze (#CD7F32), laurel green (#7AB46F), parchment (#F4E4C1).

## Asset Considerations
- Units currently color quads; need sprites (32x32). Animations: idle (4 frames), walk (4), attack (4), die (4).
- Background layers for battle (sky, mountain, temple, foreground). Parallax ratio 0.2/0.5/1.0.
- Icons for spells, traps, energy, maneuver.
- Pixel font (e.g., “Press Start 2P” or custom). Must include numeric glyphs (energy), colon, Greek letters if needed.

## Next Steps
1. Define art direction doc (palette, references, font choices). 
2. Source or commission sprite pack. Ensure licensing for distribution. 
3. Update SpriteKit pipeline to load textures from atlases. 
4. Rebuild SwiftUI screens with themed backgrounds, typography, icons.
