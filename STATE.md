Last updated: 2026-03-20

# STATE

## Project Identity
POPSLoader is a PS2 launcher for POPStarter built on Enceladus runtime pieces, with behavior primarily orchestrated by embedded Lua modules (`system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`).

## Current Runtime State (Repo-Verified)
- Boot and required runtime modules use embedded Lua blobs; filesystem Lua loaders are disabled.
- Settings are persisted at `mc0:/POPSTARTER/.pldrs`.
- Settings edits are staged in UI and committed on Settings or Profile exit.
- Persisted settings currently include:
  - selected POPStarter profile,
  - POPStarter path,
  - BDMA mode,
  - DKWDRV path,
  - video standard (`NTSC` or `PAL`).
- Configurable executable paths support `mc?:/` alias resolution (`mc0:/` then `mc1:/`).
- Implemented selectable BDMA modes are `FAT32`, `USBEXFAT`, `MX4SIO`, and `MMCE`.
- USB vs MX4SIO classification is based on mount-driver identity, not root-name heuristics.
- Cover preview is local-file based:
  - non-HDD backends use sidecar `<game>.png`,
  - HDD uses `hdd0:__common/POPS/ART/<title>.png`.
- `bin/POPSLDR/ui.lua` can display a build stamp from `BUILD_INFO.txt` when that file is present.
- CI currently generates `bin/POPSLDR/BUILD_INFO.txt` before compile, but the release ZIP does not currently package it.
- UI tracks `boot_device`, `boot_locks`, and `device_lock`, but current menu flow does not use those helpers to block device switching.
- Release packaging policy in CI is `PS1_POPSLOADER/*` plus `POPS/PATCH_5.BIN` with strict manifest validation.

## Main Menu Feature Status
- `MMCE`: implemented.
- `MX4SIO`: implemented.
- `HDD (PFS)`: implemented.
- `USB`: implemented.
- `Disc (DKWDRV)`: implemented.
- `HDD (exFAT)`: not implemented.
- `SMB (v1)`: not implemented.

## Internal Naming Notes
- Internal scene `GSMB` currently backs the MMCE game-list flow.
- The user-facing `SMB (v1)` main-menu option still reports `Not Implemented Yet`.

## Known Open Work
- Implement the `HDD (exFAT)` menu flow.
- Implement the `SMB (v1)` menu flow.
- Decide whether `BUILD_INFO.txt` should remain optional workspace metadata or be added to packaged releases.
- Either wire device-lock enforcement into menu flow or remove the dormant helper/modal path.
- Decide whether cover art should expand beyond current local PNG lookup.
- Expand documented hardware validation runs in `QA_REGRESSION_MATRIX.md`.

## Verification Status
- Code, build, and packaging statements above are repository-verified.
- Hardware behavior is `Unknown (verify on hardware)` unless recorded in `QA_REGRESSION_MATRIX.md` run logs.
