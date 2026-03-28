Last updated: 2026-03-27

# ROADMAP

## Status Snapshot
- Core launcher functionality is present in code for MMCE, MX4SIO, HDD (PFS), USB, Disc (`DKWDRV`), settings persistence, cover preview, path editing, startup backend auto-init, and exit flows.
- The shared default/Profile 1 local POPSTARTER baseline was restored by rolling back to the `BETA-10-play-CHECKPOINT2` resolver behavior; user hardware confirmed that fix.
- Current source includes a 2026-03-27 HDD startup auto-init correction so HDD boot/configured paths run the full HDD module-load path at startup.
- The main stabilization blocker is still HDD-backed `POPSTARTER.ELF` handoff when the launcher, sidecar/CWD, or configured POPSTARTER path lives on HDD. Reported hardware results still black-screen both HDD-game and USB-game repros.
- The latest EE-side HDD direct-load workaround was reverted after it did not fix `D-10` and coincided with a reported HDD-game regression when POPSTARTER stayed on the non-HDD boot device.
- `HDD (exFAT)` and `SMB (v1)` remain intentionally unimplemented menu entries.

## Immediate Priorities

### 1) HDD startup auto-init re-validation
- Re-run `D-12` on current source, especially:
  - booting from HDD,
  - cold boot with a configured HDD `POPSTARTER_PATH` or profile path,
  - launching without first opening the HDD page.
- Expected on current source: HDD startup targets auto-init through `PLDR.LoadHDDModules()` and the HDD driver stack is ready before manual HDD page entry.

### 2) HDD-backed POPSTARTER exec
- Reproduce and resolve `D-10`:
  - POPSLoader booted from HDD,
  - HDD game launched from HDD (PFS),
  - `POPSTARTER.ELF` resolved from HDD sidecar/CWD or configured HDD path,
  - current reported result: black-screen hang.
- 2026-03-27 re-test of the current source still black-screened with boot source HDD, `POPSTARTER.ELF` on HDD via default/Profile 1/cwd/sidecar, and game device HDD.
- 2026-03-27 user hardware also black-screened when launching a USB game with Profile 2 pointing `POPSTARTER.ELF` to HDD, so `D-14` now shows the remaining bug is the HDD-backed POPSTARTER exec path itself, not only HDD game routing.
- The latest EE-side `open/read` HDD direct-load attempt has been reverted after it still failed `D-10` and coincided with a reported `D-15` regression on HDD-game launch with non-HDD sidecar POPSTARTER.
- Next hardware step:
  - first re-run `D-15` on the reverted source to confirm HDD-game launch with non-HDD sidecar POPSTARTER is restored,
  - then re-run `D-14` with a USB game and HDD `POPSTARTER.ELF`,
  - then re-run `D-10` with boot source HDD and HDD `POPSTARTER.ELF`,
  - use `R2` only if the reverted-source HDD-game repro still differs from the USB-game repro.
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
