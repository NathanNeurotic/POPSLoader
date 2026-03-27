Last updated: 2026-03-27

# ROADMAP

## Status Snapshot
- Core launcher functionality is present in code for MMCE, MX4SIO, HDD (PFS), USB, Disc (`DKWDRV`), settings persistence, cover preview, path editing, startup backend auto-init, and exit flows.
- A broader shared POPSTARTER launch regression is now suspected from a 2026-03-27 USB sidecar/cwd/Profile 1 `Cant find POPSTARTER ELF` report.
- Current source contains a targeted settings/profile equivalence correction intended to restore the common default/Profile 1 sidecar baseline, but hardware re-validation is still pending.
- The main stabilization blocker is still HDD `POPSTARTER.ELF` when the launcher and/or sidecar/CWD are on HDD. Reported hardware result is still a black-screen hang.
- `HDD (exFAT)` and `SMB (v1)` remain intentionally unimplemented menu entries.

## Immediate Priorities

### 1) Shared POPSTARTER baseline re-validation
- Re-test default/Profile 1 local POPSTARTER launching after the current settings/profile correction:
  - boot from USB with USB sidecar/cwd/Profile 1,
  - confirm launch no longer stops at `Cant find POPSTARTER ELF`,
  - cross-check at least one launch each from USB, HDD, and MX4SIO/MMCE if available.
- Keep `OSDSYS` and `BOOT.ELF` behavior stable while verifying the shared baseline.

### 2) HDD POPSTARTER on HDD
- Reproduce and resolve `D-10`:
  - POPSLoader booted from HDD,
  - HDD game launched from HDD (PFS),
  - `POPSTARTER.ELF` resolved from HDD sidecar/CWD or configured HDD path,
  - current reported result: black-screen hang.
- 2026-03-27 re-test of the current source still black-screened with boot source HDD, `POPSTARTER.ELF` on HDD via default/Profile 1/cwd/sidecar, and game device HDD.
- Current source now exposes `R2` from the HDD list as an A/B experiment for HDD-resident `POPSTARTER.ELF`, swapping only the selector contract to `hdd0:PART:pfs0:/GAME.ELF`.
- Next hardware step: run the same repro twice on current source, once with `X` and once with `R2`, to separate current-branch handoff failure from POPSTARTER selector-path failure.
- Keep `BOOT.ELF` and OSDSYS behavior stable while iterating on this.

### 3) External exit/launch re-validation
- Re-run `U-05` (`OSDSYS`) and `U-10` (`BOOT.ELF after HDD page init`) on current source after the last reverted launch-backend experiment.
- Record exact run results in `QA_REGRESSION_MATRIX.md` instead of carrying them only in chat history.

### 4) Display and UX verification
- Re-run `U-06` to confirm PAL/NTSC menu asset proportions on hardware.
- Re-run `U-08` and `U-09` on slower/large libraries to judge whether busy overlays communicate activity clearly enough.

### 5) Coverage and documentation
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
