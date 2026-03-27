Last updated: 2026-03-27

# ROADMAP

## Status Snapshot
- Core launcher functionality is present in code for MMCE, MX4SIO, HDD (PFS), USB, Disc (`DKWDRV`), settings persistence, cover preview, path editing, startup backend auto-init, and exit flows.
- HDD `POPSTARTER.ELF` fix for `D-10` has been implemented: `LoadELFFromFileExecPS2` now routes pfs:/hdd: paths through the embedded loader, and the embedded loader uses fileXio to load the ELF without resetting IOP. Awaits hardware verification.
- `HDD (exFAT)` and `SMB (v1)` remain intentionally unimplemented menu entries.

## Immediate Priorities

### 1) HDD POPSTARTER on HDD — awaits hardware re-test
- `D-10` fix applied in this branch:
  - `LoadELFFromFileExecPS2` detects pfs:/hdd: paths and routes through `ExecuteViaEmbeddedLoader`.
  - `ExecuteViaEmbeddedLoader` no longer calls `SifExitIopHeap/SifExitRpc/SifExitCmd` (preserves HDD modules for the embedded loader).
  - Embedded loader uses `fileXio` to open and load the ELF for pfs:/hdd: target paths, without resetting IOP.
  - `argv0_selector` for HDD games now includes the full partition path (`hdd0:PARTITION:pfs0:/GAMENAME.ELF`) so POPSTARTER can remount the game partition after its own IOP reset.
- Hardware re-test needed: run D-10 repro and record result in `QA_REGRESSION_MATRIX.md`.

### 2) External exit/launch re-validation
- Re-run `U-05` (`OSDSYS`) and `U-10` (`BOOT.ELF after HDD page init`) on current source.
- Record exact run results in `QA_REGRESSION_MATRIX.md` instead of carrying them only in chat history.

### 3) Display and UX verification
- Re-run `U-06` to confirm PAL/NTSC menu asset proportions on hardware.
- Re-run `U-08` and `U-09` on slower/large libraries to judge whether busy overlays communicate activity clearly enough.

### 4) Coverage and documentation
- Add concrete run logs for:
  - startup backend auto-init (`D-12`),
  - device switching without runtime locks (`D-13`),
  - keyboard layout persistence (`S-09`),
  - boot-device label display (`U-11`).
- Keep `README.md`, `STATE.md`, `DECISIONS.md`, and `QA_REGRESSION_MATRIX.md` synchronized.

## Secondary Work

### 1) Unimplemented menu paths
- Implement `HDD (exFAT)` flow.
- Implement `SMB (v1)` flow.

### 2) Art/asset behavior
- Keep current cover behavior stable:
  - sidecar PNG beside the selected `.VCD`,
  - HDD common art from `hdd0:__common/POPS/ART/<title>.png`.
- Decide whether a broader ART system still needs to exist beyond those current code paths.

### 3) Install/build clarity
- Keep CI package layout and docs synchronized.
- Keep README installation steps explicit enough for users who are not familiar with PS2 launcher layouts.

## Deferred Ideas
- Additional themes/skins.
- Broader network backend support after SMB has a defined baseline.
- More ambitious artwork cache policy after current launch/runtime issues are stable.
