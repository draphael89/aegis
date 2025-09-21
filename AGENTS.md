# Repository Guidelines

## Project Structure & Module Organization
- `Packages/CoreEngine`, `Packages/BattleRender`, `Packages/MetaKit`: Swift packages for deterministic game logic, SpriteKit rendering, and content definitions. Tests live alongside each package in `Packages/*/Tests` with golden replays under `Fixtures/Replays`.
- `iOSApp/`: SwiftUI shell (`App.swift`, `Game/` views) and support utilities (`Support/Haptics.swift`).
- `tasks/<task-id>/`: Research/plan/todo artifacts for long-running work—create a new folder per task.
- `Packages/CoreEngine/Tests/Fixtures`: Replay JSON used by golden tests—keep hashes in sync when editing.

## Task Management: Multi-step Context Engineering
0. **Tasks**
   - Operate on a task-by-task basis. Create `tasks/<task-id>/` (semantic slug, e.g., `tasks/meta-prep-energy-placements/`). Store all intermediate context there.

1. **Research**
   - Begin by clarifying scope if needed (ask follow-ups). Identify existing patterns/components in this repo; search external docs if relevant.
   - Document findings, links, and code references in `tasks/<task-id>/research.md`.

2. **Planning**
   - Read `research.md`, reuse proven patterns, and outline the implementation strategy in `plan.md`.
   - Include all required context (APIs, files, test expectations). Ask the user for clarifications only when necessary.

3. **Implementation**
   - Derive a TODO checklist from `plan.md` in `todo.md`, then execute it sequentially.
   - Work continuously; batch unresolved questions at the end. Update the checklist as items complete.

## Build, Test, and Development Commands
- `swift test --package-path Packages/CoreEngine`: Runs deterministic engine tests and golden replays.
- `swift test --package-path Packages/MetaKit`: Validates content catalogs and validators.
- Build/run the iOS app via Xcode (`Aegis.xcodeproj`), targeting iOS 17+. Use `Product ▸ Run` for simulator testing.

## Coding Style & Naming Conventions
- Swift 5.10/6 style with 4-space indentation. Prefer value types and deterministic ordering in CoreEngine (no random iteration). Use `camelCase` for variables/functions, `UpperCamelCase` for types and constants in `ContentIDs`.
- SpriteKit nodes should remain render-only; never mutate game state inside `BattleScene`.
- Task folders: `tasks/<domain>-<feature>-<action>/` with `research.md`, `plan.md`, `todo.md`.

## Testing Guidelines
- Use `swift test` before committing; update golden hashes in `GoldenReplayTests.swift` when deterministic behaviour changes.
- New replay fixtures belong under `Packages/CoreEngine/Tests/Fixtures/Replays` with descriptive names.
- Add unit tests for new mechanics (e.g., `SpellsTests.swift`) and snapshot or Instruments notes in task artifacts when relevant.

## Commit & Pull Request Guidelines
- Follow descriptive commit messages (imperative, summary-level, e.g., "Add spell casting system, prep flow, and render juice").
- PRs should include: purpose summary, key tests (`swift test ...`), screenshots/recordings for UI changes, and links to relevant task folders or issues.
- Keep diffs focused; update task `todo.md` with completion status before submitting.

## Architecture Notes
- Maintain the separation: CoreEngine → deterministic logic, MetaKit → data, BattleRender → projection, iOSApp → orchestration. Any new feature should respect this boundary.
- Persistent seeds and replay fixtures are the source of truth for debugging—capture them when introducing new behaviours.
