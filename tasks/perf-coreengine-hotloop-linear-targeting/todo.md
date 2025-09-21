# TODO — perf-coreengine-hotloop-linear-targeting

- [x] Remove per-tick dictionary copy in `acquireTargetsAndMove` and mutate state in place.
- [x] Replace `selectTarget` and `frontUnit` sorts with linear scans that preserve priority semantics.
- [x] Refactor healer helpers to operate directly on `state.units`.
- [x] Run `swift test --package-path Packages/CoreEngine` (goldens updated to new hash reflecting corrected cooldown handling).
- [ ] Capture Instruments snapshot (30–40 unit scenario) to confirm 0 allocations/tick and ≤2 ms sim. *(pending manual run)*
