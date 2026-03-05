Last updated: 2026-03-05

# RULES

## Scope discipline
- Keep changes small, local, and tied to one objective per PR whenever feasible.
- Prefer the narrowest file set that can solve the task.
- Do not mix behavior changes, refactors, and packaging edits in one PR unless explicitly requested.

## Do-not-break invariants (POPSLoader)
- POPStarter launching flow must stay intact (`RunPOPStarterGame` -> launch policy -> `LaunchEngine`).
- BDMA mode behavior must remain consistent: selectable modes, save/load, and apply path must agree.
- MX4SIO vs USB separation must use mount-driver identity as authority (`sdc`/`mx4sio` => MX4SIO), never UI guesswork.
- Settings edits in the Settings/Profile screen are staged while navigating; persistence happens on confirm/leave, not on every adjustment.
- No new debug/logging output in production unless explicitly requested.

## Persistence rules
- Settings are loaded during startup via `PLDR.LoadSettingsNonFatal()` before entering the main UI loop.
- Settings are saved through `PLDR.SaveSettingsAtomic()` when exiting Settings/Profile with pending changes.
- Settings file path is currently `mc0:/POPSTARTER/.pldrs`.
- UI labels and selectors must mirror runtime/persisted values (for example BDMA selector initializes from `PLDR.BDMA_MODE_KEY`).

## UI rules
- Keep icon placement deterministic; do not anchor icon X positions to variable label length.
- Preserve PS2 performance constraints: avoid heavy per-frame allocations, repeated full-device rescans, and unbounded retries in render/input loops.

## Testing expectations
- Minimum manual matrix for behavior-impacting changes:
  - USB game list path
  - MX4SIO game list path
  - MMCE game list path
  - HDD path (if touched)
- Always include a settings persistence check: change profile/BDMA, exit Settings, restart, verify loaded state and labels.
- If hardware paths cannot be tested locally, mark as `Unknown (verify on device)`.

## PR hygiene
- Every PR/task report should include:
  - Summary
  - Diffstat
  - Full diff
  - Test plan (what ran, what passed/failed, what was not run)
