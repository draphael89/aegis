# Aegis

Native Swift iOS autobattler scaffold targeting a pixel-crisp, deterministic vertical slice.

## Foundation Checklist
- Core engine lives in `Packages/CoreEngine` as a 60 Hz integer-tick simulation with seeded RNG and golden replays.
- SpriteKit rendering in `Packages/BattleRender` treats the engine as truth: 3 hard lanes × 3 slots, virtual 360×640 canvas, nearest-neighbor textures, hitstop, haptics.
- SwiftUI meta loop in `iOSApp/` drives the Slay-the-Spire style map → prep → battle → reward flow with SwiftData/Codable persistence.
- Content is data-driven (JSON/Swift tables) with validators and perf/testing gates enforced in CI.

## Bootstrap
```bash
brew install xcodegen
./Scripts/gen.sh
open Aegis.xcodeproj
```

## Key Commands
- `swift test --package-path Packages/CoreEngine` – deterministic engine tests.
- `xcodebuild -scheme AegisApp -destination 'platform=iOS Simulator,name=iPhone 15' build` – CI-friendly build.
- `swift run --package-path Packages/CoreEngine` – add golden replay harnesses here.

## Feature Highlights
- SpriteKit battle scene ships with lane bands, intro camera sweep, spawn pops, and hit flashes while respecting the 60 Hz deterministic core.
- Haptics fire for placement and battle outcomes (wrapped in `Haptics.swift` for easy expansion).
- Content and rendering modules remain data-driven and test-covered (`swift test` in each package).

Follow [AGENTS.md](AGENTS.md) for long-running task structure, invariants, and acceptance criteria.
