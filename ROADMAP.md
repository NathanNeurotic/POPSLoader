# POPSLoader Roadmap

Last updated: 2026-03-25

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
- Treat the current HDD diagnostic line as exhausted for now:
  - commit `9eaa040` established stable `embedded loader entry`
  - commits `6bddf69`, `11f1dc6`, and `78e0ee6` all collapsed to the same flash-then-black result when the halt moved deeper into post-entry string-copy code
  - later standard artifacts `0a0b6e9`, `e55e119`, `26fc65d`, `59be355`, and `d4a604e` also still black-screened, including the mounted-`pfs` direct-launch and `LoadExecPS2` variants
- Do not spend more cycles on narrower screen-backed embedded-loader halt variants, mounted-`pfs` bypass reshuffles, or direct-loader mechanism swaps unless future work brings a materially different evidence source or a new code asymmetry that is not already covered in `FAILURES.md`.
- Expand and record hardware coverage runs in `QA_REGRESSION_MATRIX.md`.
- Prioritize combined scenarios: large multi-root USB + MX4SIO + MMCE + HDD installations.

### 4) Release/process hardening
- Document per-launcher install layout details (OPL/FMCB variants) in README/docs.
- Keep package contract and docs synchronized when payload policy changes.

## Deferred / Future Ideas
- Additional UI themes/skins.
- Advanced artwork caching strategy.
- Extended network backend support after SMB baseline is stable.
