Last updated: 2026-03-05

# STATE

## Purpose
Current operational snapshot for humans and AI agents.

## Current Goal
- [ ] Finalize AI-oriented repo docs with concrete POPSLoader architecture, invariants, and usage guidance.

## Current PR Objective
- [ ] Replace placeholder docs with repo-grounded content (`README.md`, `ARCHITECTURE.md`, `TRUTHSHEET.md`, `STATE.md`).
- [ ] Add a technical component map (`COMPONENTS.md`) to complement high-level architecture docs.

## Known Regressions / Gaps
- [ ] SMB path in main menu is currently marked `Not Implemented Yet` in UI.
- [ ] One menu path (`UI.MainMenu.OPT == 3`) is currently marked `Not Implemented Yet`.
- [ ] TODO: Add validated reproduction details for any runtime regressions as they are confirmed.

## Current Constraints
- [ ] Minimal diffs only; no unrelated code or formatting churn.
- [ ] Avoid touching unrelated Lua/C/C++ files for docs-only tasks.
- [ ] Bounded loops only.
- [ ] Avoid adding logging unless explicitly requested.
- [ ] Preserve boot/launch pipeline and device detection logic unless explicitly in scope.

## How to Update This File
- [ ] Update `Last updated` every time this file changes.
- [ ] Keep entries short, factual, and tied to active work.
- [ ] Move durable architectural decisions to `DECISIONS.md`.
- [ ] Remove resolved items promptly to keep this snapshot current.
