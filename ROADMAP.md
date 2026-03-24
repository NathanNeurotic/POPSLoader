# POPSLoader Roadmap

Last updated: 2026-03-24

## Status Snapshot
Current branch has substantial stabilization work already landed (settings transaction flow, launch path hardening, backend classification, and packaging policy updates). Remaining roadmap items are mostly feature-completion and hardware validation.

## Completed Milestones (Code-Landed)

### A) Settings and launch reliability
- Settings load on boot via `PLDR.LoadSettingsNonFatal()`.
- Settings commit flow is transactional on Settings/Profile exit.
- POPStarter and DKWDRV paths are editable from Settings.
- Missing POPStarter/DKWDRV paths block launch with explicit notifications.
- `mc?:/` alias expansion supports `mc0:/` then `mc1:/` fallback.

### B) Device/backend handling
- USB vs MX4SIO list split is mount-driver based (`sdc`/`mx4` => MX4SIO).
- MX4SIO initialization/list flow includes bounded retries to mask first-entry timing issues.
- MMCE slot detection (`mmce0:/`, `mmce1:/`) is implemented.

### C) UX and presentation
- Hide auxiliary text toggle (Select) is implemented for supported scenes.
- Cover sidecar preview (`.png` next to `.VCD`) with small cache is implemented.
- Settings page supports profile + path + BDMA mode editing with save/apply overlay.

### D) Packaging policy
- CI release packaging uses `POPS/PATCH_5.BIN`.
- CI validates exact ZIP manifest and rejects legacy `POPS/*.tm2` entries.

## Active Backlog

### 1) Unimplemented menu features
- Implement `HDD (exFAT)` flow (currently `Not Implemented Yet`).
- Implement `SMB (v1)` flow (currently `Not Implemented Yet`).

### 2) ART system
- Define and implement artwork source-of-truth, fallback policy, and cache behavior.

### 3) Hardware validation depth
- Resolve the still-unverified/failed `POPSTARTER.ELF on HDD` launch path before expanding broader HDD coverage. See `FAILURES.md`.
- Expand and record hardware coverage runs in `QA_REGRESSION_MATRIX.md`.
- Prioritize combined scenarios: large multi-root USB + MX4SIO + MMCE + HDD installations.

### 4) Release/process hardening
- Document per-launcher install layout details (OPL/FMCB variants) in README/docs.
- Keep package contract and docs synchronized when payload policy changes.

## Deferred / Future Ideas
- Additional UI themes/skins.
- Advanced artwork caching strategy.
- Extended network backend support after SMB baseline is stable.
