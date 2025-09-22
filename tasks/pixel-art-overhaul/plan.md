# Plan — pixel-art-overhaul

## Vision
Transform the current prototype UI into a polished, Greek-myth-inspired pixel art experience anchored by warm parchment UI, mythic motifs, and animated SpriteKit scenes.

## Pillars
1. **Greek Myth Pixel Diorama** – unify palette (indigo, bronze, parchment, laurel green); laurel and column motifs.
2. **Consistent Pixel Grid** – all sprites exported at 32x32 multiples, `.nearest` filtering, `isAntialiased = false`.
3. **Cinematic Layering** – parallax backgrounds, idle animations, particle effects.
4. **Readable UI** – custom pixel header font + clean body font, consistent spacing, explicit states.
5. **Immersive Map** – parchment map with branching nodes vs plain list.

## Deliverables by Screen
### Run Overview / Map
- Full-screen parchment background (SwiftUI `Canvas` or `Image`).
- Map columns with torch animation (simple SKEmitter or Lottie). Expand `MapGraph` data to render connectors.
- Node buttons styled as pixel coins with icons (battle, elite, event, shop). Selected node glows.
- Header: “Mount Olympus Expedition” with laurel banner + current relic count.

### Prep Screen
- Backdrop campfire scene at dusk (SpriteKit `SceneView` or static image).
- Card deck: pixel portraits, name banners, energy cost badges.
- Placement grid: stone pedestals with subtle glow; hero pedestal animated.
- Trap selector: `HStack` of trap icons with armed state (chain overlay) and energy deduction.
- Buttons re-themed (pill shaped bronze with highlight).

### Battle Scene
- Background: parallax (sky gradient, mountains, temple foreground). Each layer moves slower/faster.
- Unit animations using atlases. Idle/walk/attack/die loops; hooking to engine state.
- Spell HUD: icons w/ cost; color-coded states; new energy coin indicator.
- Maneuver button with directional arrow icon and once-per-battle cooldown overlay.
- Particle effects for fireball, heal, trap activation. Damage numbers use pixel font with drop shadow.
- Victory/defeat banners (animated laurel vs cracked bronze).

## Implementation Steps
1. **Art Direction & Assets**
   - Create `ART_GUIDE.md` with palette, fonts, references. 
   - Confirm source of pixel art (commission or curated pack). Export to `.atlas`.

2. **Project Setup**
   - Add `Assets.xcassets` groups: `Backgrounds`, `Units`, `Effects`, `UI`.
   - Update `UnitNode` to load textures, manage SKActions for animation states.
   - Introduce `BattleBackgroundLayer` struct to handle parallax sprites.

3. **SwiftUI Theme Layer**
   - Add `Theme.swift` with colors, fonts, corner radius constants.
   - Update Map UI: new `MapView` that draws parchment, connectors, nodes.
   - Redesign `PrepView` layout with background and card components.

4. **HUD & Overlay**
   - Battle overlay with icons, energy meter, spell buttons, maneuver button.
   - Add animation when casting (button highlight + particle spawn call).

5. **Animation Hooks**
   - Extend `BattleSimulation` to expose unit states for animation (attack/walk). (Keep deterministic).
   - Add `SpriteAnimator` to update textures per tick (using engine tick for determinism).

6. **Audio & Feedback** (optional but recommended)
   - Add ambient loop (campfire/battle). Integrate via `SKAudioNode`.
   - UI SFX (button tap, trap armed, victory).

7. **QA and Performance**
   - Ensure 60fps on device with all layers. Profile `BattleScene` for CPU.
   - Update snapshot tests or golden replays for new visuals (only UI changes). Document test plan in `tasks/pixel-art-overhaul/todo.md`.

## Tests & Validation
- Visual regression: take baseline screenshots, compare after refactor.
- Functional: `swift test` packages to ensure deterministic outputs unaffected.
- Manual QA on physical device for aliasing/perf.

## Timeline (High Level)
- Week 1: design doc, asset import, theme setup, map UI skeleton.
- Week 2: battle background + HUD integration, unit animations.
- Week 3: prep screen visuals, trap icons, particle SFX.
- Week 4: polish (victory screen, fonts, shader tweaks), QA.

## Notes
- Coordinate with art to ensure licensing.
- Keep TDD for new SpriteKit behavior (unit animation tests via deterministic tick).
- Document palette + fonts for future content team.
