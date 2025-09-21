# TODO — render-sync-micro-opts-and-juice-core

- [x] Switch `BattleScene` to `.aspectFit` and manage a camera rest position.
- [x] Add pooled damage/heal number nodes with capped active count.
- [x] Gate health bar updates behind HP changes only.
- [x] Introduce hitstop timer and camera shake events for unit deaths and pyre hits.
- [x] Track pyre HP deltas to trigger shake/hitstop feedback.
- [x] Reset hitstop/shake state per battle; integrate with intro sweep completion.
- [x] `swift test --package-path Packages/CoreEngine`
- [x] `swift test --package-path Packages/MetaKit`
- [ ] Manual visual QA on device/simulator (damage numbers, shake) — pending.
