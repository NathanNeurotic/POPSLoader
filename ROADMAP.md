Last updated: 2026-03-28

# ROADMAP

## Status Snapshot
- Core launcher functionality is present in code for MMCE, MX4SIO, HDD (PFS), USB, Disc (`DKWDRV`), settings persistence, cover preview, path editing, startup backend auto-init, and exit flows.
- The shared default/Profile 1 local POPSTARTER baseline was restored by rolling back to the `BETA-10-play-CHECKPOINT2` resolver behavior; user hardware confirmed that fix.
- Current source includes a 2026-03-27 HDD startup auto-init correction, and user hardware later confirmed that fix.
- Current source also includes a 2026-03-27 USB first-entry backend discovery correction, and user hardware later confirmed that fix; MX4SIO discovery code is unchanged.
- A later 2026-03-28 hardware re-test confirmed `D-15` now passes on the narrowed source, so the restored non-HDD POPSTARTER HDD-game path is back.
- A later 2026-03-28 re-test still black-screened on that narrowed Lua-side HDD-backed source with no visible positive change.
- A later 2026-03-28 re-test on that loader-side source still black-screened for `D-10` on both `X` and `R2`, and the user clarified the other same-day success result was another `D-15` run rather than `D-14`.
- A later 2026-03-28 re-test on that forced-`reboot_iop = 1` source still black-screened for `D-10` and `D-14`.
- A later 2026-03-28 re-test on that direct-`hdd0:PART:pfsN:/POPSTARTER.ELF` preference source still black-screened for both `D-10` and `D-14`.
- A later 2026-03-28 re-test on that mounted-`pfs0:` embedded-loader source still black-screened for `D-10`.
- Current source now keeps the narrowed Lua-side HDD-backed handoff, keeps the HDD-backed reboot loader path on mounted `pfs0:/...`, and additionally stops tearing down EE-side SIF state before `ExecPS2` into the embedded loader; `R2` can still request the full `hdd0:PART:pfs0:/GAME.ELF` selector.
- The main stabilization blocker is still HDD-backed `POPSTARTER.ELF` handoff when the launcher, sidecar/CWD, or configured POPSTARTER path lives on HDD. Reported hardware results still black-screen both HDD-game and USB-game repros.
- The latest EE-side HDD direct-load workaround was reverted after it did not fix `D-10` and coincided with a reported HDD-game regression when POPSTARTER stayed on the non-HDD boot device.
- `HDD (exFAT)` and `SMB (v1)` remain intentionally unimplemented menu entries.

## Immediate Priorities

### 1) HDD-backed POPSTARTER exec
- Reproduce and resolve `D-10`:
  - POPSLoader booted from HDD,
  - HDD game launched from HDD (PFS),
  - `POPSTARTER.ELF` resolved from HDD sidecar/CWD or configured HDD path,
  - current reported result: black-screen hang.
- 2026-03-27 re-test of the current source still black-screened with boot source HDD, `POPSTARTER.ELF` on HDD via default/Profile 1/cwd/sidecar, and game device HDD.
- 2026-03-27 user hardware also black-screened when launching a USB game with Profile 2 pointing `POPSTARTER.ELF` to HDD, so `D-14` now shows the remaining bug is the HDD-backed POPSTARTER exec path itself, not only HDD game routing.
- The latest EE-side `open/read` HDD direct-load attempt has been reverted after it still failed `D-10` and coincided with a reported `D-15` regression on HDD-game launch with non-HDD sidecar POPSTARTER.
- A later hardware run showed that Memory Card staging alone was not sufficient; the launch still black-screened on an HDD title.
- A later 2026-03-28 hardware re-test confirmed that the narrowed source restored `D-15`, so the remaining blocker is again isolated to HDD-backed `POPSTARTER.ELF`.
- A later 2026-03-28 re-test still black-screened on that narrowed Lua-side HDD-backed source with no visible positive change.
- A later 2026-03-28 re-test on that loader-side source still black-screened for `D-10` on both `X` and `R2`, while the other same-day success result was clarified as another `D-15` run rather than `D-14`.
- A later 2026-03-28 re-test on that forced-`reboot_iop = 1` source still black-screened for `D-10` and `D-14`.
- Current source now keeps the narrowed Lua-side HDD-backed handoff, routes HDD-backed reboot launches through an explicit mounted-`pfs0:` embedded-loader path in `src/elf_loader/src/elf.c`, removes EE-side SIF teardown before the embedded-loader `ExecPS2`, stops preserving boot PFS slots during launch prep for HDD-backed `POPSTARTER.ELF`, no longer unconditionally resets IOP inside the embedded loader before `ExecPS2`, fixes the malformed direct-HDD alias builder that had been omitting the colon after `pfsN`, and keeps the restored selector-only handoff for non-HDD POPSTARTER HDD-game launches.
- Next hardware step:
  - first re-run `D-10` with boot source HDD and HDD `POPSTARTER.ELF`,
  - then re-run `D-14` with a USB game and HDD `POPSTARTER.ELF`,
  - use `R2` only if the corrected-source HDD-game repro still differs from the USB-game repro.
- Keep `BOOT.ELF` and OSDSYS behavior stable while iterating on this.

### 2) External exit/launch re-validation
- Re-run `U-05` (`OSDSYS`) and `U-10` (`BOOT.ELF after HDD page init`) on current source after the last reverted launch-backend experiment.
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
