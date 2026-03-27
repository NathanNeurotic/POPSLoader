Last updated: 2026-03-27

# STATE

## Project Identity
POPSLoader is a PS2 launcher for POPStarter built on Enceladus runtime pieces, with behavior primarily orchestrated by embedded Lua modules (`system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`).

## Repo-Verified Runtime State
- Boot/runtime uses embedded Lua scripts.
- Settings are persisted at `mc0:/POPSTARTER/.pldrs`.
- Settings edits are staged and committed on Settings/Profile confirm/leave.
- Persisted settings include:
  - POPSTARTER path,
  - DKWDRV path,
  - video standard,
  - hide-text mode,
  - keyboard layout,
  - BDMA mode.
- Startup backend auto-init exists and uses:
  - boot path information,
  - configured executable paths,
  - selected profile path.
- USB vs MX4SIO split is based on mount-driver identity, not path-prefix guessing.
- Runtime device access is not gated by the old device-lock system.
- Main menu can show a boot-device label.
- Exit modal exposes:
  - `OSDSYS`
  - `Cancel`
  - `BOOT.ELF`
- `BOOT.ELF` lookup order is:
  - `mc0:/BOOT/BOOT.ELF`
  - `mc1:/BOOT/BOOT.ELF`
- Current cover sources are:
  - sidecar PNG next to the selected `.VCD`,
  - `hdd0:__common/POPS/ART/<title>.png` for HDD titles.
- Release packaging policy in CI is `PS1_POPSLOADER/*` + `POPS/PATCH_5.BIN` with strict manifest validation.

## Main Menu Feature Status
- `MMCE`: implemented in code.
- `MX4SIO`: implemented in code.
- `HDD (PFS)`: implemented in code.
- `USB`: implemented in code.
- `Disc (DKWDRV)`: implemented in code.
- `HDD (exFAT)`: not implemented.
- `SMB (v1)`: not implemented.

## Reported Hardware Status
- `U-05` OSDSYS exit:
  - reported fixed on hardware.
- `D-10` HDD POPSTARTER on HDD:
  - fix applied: embedded loader now uses fileXio for pfs:/hdd: POPSTARTER paths; IOP is preserved for the load; argv0_selector uses the dynamically-mounted pfs prefix so POPSTARTER can remount after its own IOP reset.
  - POPSTARTER pfs slot is now explicitly preserved in `keep_hdd_slots` via `ResolveExecPathAndKeepSlot`.
  - `launch_cwd` no longer passes the game partition as CWD; it is nil, letting LaunchEngine use the POPSTARTER path directory.
  - awaits hardware re-test to confirm fix.
- Broader regression (USB boot + USB POPSTARTER sidecar/cwd/profile1 — `Cant find POPSTARTER ELF`):
  - Suspected cause: `launch_cwd = hdd_init.mount_prefix` (introduced in BETA-10-play HDD mitigation) set the pre-launch CWD to the game partition instead of nil, and `keep_hdd_slots` did not include the POPSTARTER's pfs slot.
  - Fix applied: `launch_cwd = nil`; `keep_hdd_slots` now includes both game and POPSTARTER pfs slots; `ResolveExecPathAndKeepSlot` resolves the POPSTARTER path and tracks its slot before any HDD-specific logic runs.
  - Awaits hardware re-test to confirm baseline restoration.
- `U-10` BOOT.ELF after HDD page init:
  - BOOT.ELF path is unaffected by D-10 changes (uses a separate code path).
  - current hardware status is `Unknown (verify on hardware)`.
- `U-06` PAL asset aspect:
  - current code compensates for PAL UI layout,
  - hardware result is still `Unknown (verify on hardware)`.

## Known Open Work
- Re-verify `D-10` HDD `POPSTARTER.ELF` handoff on hardware after this fix.
- Re-verify USB POPSTARTER baseline (USB boot + USB POPSTARTER sidecar/cwd/profile1) after `launch_cwd` and `keep_hdd_slots` fix.
- Re-verify `BOOT.ELF` after HDD page init on current source.
- Record concrete run logs in `QA_REGRESSION_MATRIX.md`.
- Implement HDD exFAT menu flow.
- Implement SMB menu flow.
- Decide whether a broader ART system is still needed beyond current sidecar/HDD-common cover support.

## Verification Status
- Code/build/package statements above are repository-verified.
- Hardware behavior is `Unknown (verify on hardware)` unless explicitly recorded as a reported result.

