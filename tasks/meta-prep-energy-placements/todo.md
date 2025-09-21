# TODO — meta-prep-energy-placements

- [x] Add PrepSlot/PrepCard/PrepState models to RunViewModel.
- [x] Implement prep state machine (start, select card, place, cycle stance, remove, commit, cancel).
- [x] Auto-place hero and persist energy/placements.
- [x] Introduce PrepView SwiftUI screen with deck, energy HUD, grid interactions, and action buttons.
- [x] Update RootView flow: map → prep sheet → battle sheet.
- [x] Ensure RunViewModel commit builds BattleSetup with player placements and reused enemy setup.
- [x] `swift test --package-path Packages/CoreEngine`
- [ ] Manual UX QA (drag/tap, stance cycling, removal) — pending.
