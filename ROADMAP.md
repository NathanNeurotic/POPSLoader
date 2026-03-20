# POPSLoader Roadmap

Last updated: 2026-03-20

## Status Snapshot
Core stabilization work is already present in the repository: embedded-Lua boot, transactional settings, launch-path hardening, mount-driver based backend classification, bounded MX4SIO retries, and strict CI packaging checks. Remaining work is mostly feature completion, documentation/process cleanup, and hardware validation depth.

## Completed Milestones (Code-Landed)

### A) Settings and launch reliability
- Settings load on boot via `PLDR.LoadSettingsNonFatal()`.
- Settings commit flow is transactional on Settings/Profile exit.
- POPStarter and DKWDRV paths are editable from Settings.
- Video standard selection is persisted and applied at runtime.
- Missing POPStarter or DKWDRV paths block launch with explicit notifications.
- `mc?:/` alias expansion supports `mc0:/` then `mc1:/` fallback.

### B) Device and backend handling
- USB vs MX4SIO list split is mount-driver based (`sdc` or `mx4` means MX4SIO).
- MX4SIO initialization and list flow include bounded retries to mask first-entry timing issues.
- MMCE slot detection (`mmce0:/`, `mmce1:/`) is implemented.
- HDD (PFS) title scan covers `__.POPS`, `__.POPS0`, and `__.POPS1` through `__.POPS9`.

### C) UX and presentation
- Hide auxiliary text toggle (`Select`) is implemented for supported scenes.
- Cover preview toggle (`Square`) is implemented for game-list scenes.
- Sidecar PNG cover preview is implemented for non-HDD backends.
- HDD common-art lookup is implemented at `hdd0:__common/POPS/ART/<title>.png`.
- Credits scene can display optional build metadata when `BUILD_INFO.txt` is present.

### D) Packaging policy
- GitHub Actions CI is the canonical build/package validator.
- CI release packaging uses `POPS/PATCH_5.BIN`.
- CI validates exact ZIP manifest and rejects legacy `POPS/*.tm2` entries.

## Active Backlog

### 1) Unimplemented menu features
- Implement `HDD (exFAT)` flow.
- Implement `SMB (v1)` flow.

### 2) UI/runtime cleanup
- Decide whether to wire device-lock helpers into actual menu blocking or remove the dormant path.
- Decide whether to keep the legacy `GSMB` scene name or rename it when SMB work begins.

### 3) Build metadata and release packaging
- Decide whether `BUILD_INFO.txt` should remain optional workspace metadata or be shipped in packaged releases.
- Keep README, status docs, and workflow/package behavior synchronized.

### 4) Cover-art scope
- Decide whether to expand beyond current local PNG lookup and HDD common-art fallback.
- If artwork features expand, document cache and fallback policy explicitly.

### 5) Hardware validation depth
- Expand and record hardware coverage runs in `QA_REGRESSION_MATRIX.md`.
- Prioritize combined scenarios: large multi-root USB plus MX4SIO plus MMCE plus HDD installations.

## Deferred or Future Ideas
- Additional UI themes or skins.
- Advanced artwork caching strategy if artwork scope expands.
- Extended network backend support after a real SMB baseline exists.
