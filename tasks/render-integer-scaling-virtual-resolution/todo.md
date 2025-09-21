# TODO — render-integer-scaling-virtual-resolution

- [x] Add `PixelScaler` helper to compute integer scale factors.
- [x] Wrap `SpriteView` in `GeometryReader` and enforce integer-sized frame with letterboxing.
- [x] Ensure `BattleScene` uses configuration field length and disables antialiasing on lane bands.
- [x] Add unit tests covering `PixelScaler` scale calculations.
- [x] Verify battle rendering with manual device checks (simulators) and ensure core tests stay green.
