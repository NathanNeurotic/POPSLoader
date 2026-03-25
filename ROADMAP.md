# POPSLoader Roadmap

Last updated: 2026-03-25

## Status Snapshot
Current branch has substantial stabilization work already landed (settings transaction flow, launch path hardening, backend classification, and packaging policy updates). The HDD POPSTARTER launch path is blocked by a confirmed ExecPS2-to-bram failure (embedded loader never starts). Remaining roadmap items are mostly feature-completion and hardware validation.

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

### 1) HDD POPSTARTER launch — ExecPS2-to-bram failure (BLOCKING)
- The embedded loader at bram (0x84000) never starts executing. Diagnostic build confirms no GS colors appear.
- Root cause: `ExecPS2((void *)entry, 0, argc, argv)` targeting bram fails silently.
- Must investigate: gp=0 CRT crash, bram address validity, loader ELF integrity, FlushCache sufficiency, SifExitRpc side effects.
- Secondary issue (PFS file I/O via iomanX) already has code in place but is untestable until the loader starts.
- See `FAILURES.md` for full details and 17 failed attempts.

### 2) Unimplemented menu features
- Implement `HDD (exFAT)` flow (currently `Not Implemented Yet`).
- Implement `SMB (v1)` flow (currently `Not Implemented Yet`).

### 3) ART system
- Define and implement artwork source-of-truth, fallback policy, and cache behavior.

### 4) Hardware validation depth
- Expand and record hardware coverage runs in `QA_REGRESSION_MATRIX.md`.
- Prioritize combined scenarios: large multi-root USB + MX4SIO + MMCE + HDD installations.

### 5) Release/process hardening
- Document per-launcher install layout details (OPL/FMCB variants) in README/docs.
- Keep package contract and docs synchronized when payload policy changes.

## Deferred / Future Ideas
- Additional UI themes/skins.
- Advanced artwork caching strategy.
- Extended network backend support after SMB baseline is stable.
