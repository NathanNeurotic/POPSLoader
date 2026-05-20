Last updated: 2026-05-19

# ROADMAP

## Status Snapshot
- Core launcher functionality is present in code for MMCE, MX4SIO, HDD (PFS), USB, Disc (`DKWDRV`), settings persistence, cover preview, path editing, startup backend auto-init, and exit flows.
- The shared default/Profile 1 local POPSTARTER baseline was restored by rolling back to the `BETA-10-play-CHECKPOINT2` resolver behavior; user hardware confirmed that fix.
- Recorded hardware confirms `D-12` startup/Profile lookup is restored, `D-16` first-entry USB discovery is restored, and `D-15` non-HDD-POPSTARTER HDD-game launch is restored.
- The main stabilization blocker is still HDD-backed `POPSTARTER.ELF` execution when the launcher, sidecar/CWD, or configured POPSTARTER path lives on HDD (`D-10`, `D-14`).
- One 2026-03-29 artifact briefly moved `D-10` to a returned `rc=-1`, but later artifacts returned to black screen, so that was not a stable new boundary.
- Current repo line uses the partition-aware HDD reboot contract, cold external-launch prep, separate exec-path reporting, and profile-path normalization while preserving the restored non-HDD POPSTARTER path.
- The latest EE-side HDD direct-load workaround was reverted after it did not fix `D-10` and coincided with a reported HDD-game regression when POPSTARTER stayed on the non-HDD boot device.
- `HDD_POPSTARTER_HANDOFF.md` is the current source-audit handoff for this blocker. It separates source-confirmed defects from hardware-only unknowns and should be read before new `D-10` / `D-14` fix attempts.
- `HDD (exFAT)`, `SMB (v1)`, and `ILINK` remain intentionally unimplemented menu entries.
- Detailed experiment chronology lives in `QA_REGRESSION_MATRIX.md` and `DECISIONS.md`; `STATE.md` also summarizes the source-inferred Settings/Profile POPSTARTER path save/load integrity risk as `Unknown (verify on hardware)` without attributing `D-10`, `D-14`, or `U-10` to it.

## Immediate Priorities

### 1) HDD-backed POPSTARTER exec
- Reproduce and resolve `D-10`:
  - POPSLoader booted from HDD,
  - HDD game launched from HDD (PFS),
  - `POPSTARTER.ELF` resolved from HDD sidecar/CWD or configured HDD path,
  - current reported result: black-screen hang.
  - preserve `D-15`, `D-12`, `D-16`, `U-05`, and shared Profile 1/default sidecar behavior while iterating.
  - treat `D-14` as the paired non-HDD-game repro for the same HDD-backed POPSTARTER blocker.
  - fix source-confirmed handoff defects before broader experiments: stale Lua fallback context, plain-label fallback partition parsing, over-broad fallback gate skip, partition-context argv leakage, and embedded-loader contract drift.
  - use `QA_REGRESSION_MATRIX.md` for the full experiment chronology instead of rebuilding that ledger here.

### 2) External exit/launch re-validation
- Re-run `U-05` (`OSDSYS`) and `U-10` (`BOOT.ELF after HDD page init`) on current source after the BOOT.ELF-specific conditional-reboot/cold-prep change for HDD-initialized sessions.
- Treat `U-10` as potentially sharing the same underlying handoff/state-poisoning boundary as `D-10`, but do not assume a `D-10` fix automatically resolves `U-10` without hardware confirmation.
- Record exact run results in `QA_REGRESSION_MATRIX.md` instead of carrying them only in chat history.

### 3) Startup/page split re-validation
- Re-run HDD boot with a large HDD library on current source.
- Expected:
  - boot-time HDD auto-init should make the device runtime ready without building the HDD games list,
  - first HDD page entry should still perform partition scan and game-list build normally.

### 4) Display and UX verification
- Re-run `U-06` to confirm PAL/NTSC menu asset proportions on hardware.
- Re-run `U-08` and `U-09` on slower/large libraries to judge whether busy overlays communicate activity clearly enough.

### 5) Coverage and documentation
- Add concrete run logs for:
  - device switching without runtime locks (`D-13`),
  - keyboard layout persistence (`S-09`),
  - boot-device label display (`U-11`).
- Keep `README.md`, `STATE.md`, `DECISIONS.md`, and `QA_REGRESSION_MATRIX.md` synchronized.

## Secondary Work

### 1) Unimplemented menu paths
- Implement `HDD (exFAT)` flow.
- Implement `SMB (v1)` flow.
- Implement `ILINK` flow.

### 2) Art/asset behavior
- Keep current cover behavior stable:
  - sidecar PNG beside the selected `.VCD`,
  - HDD common art from `hdd0:__common/POPS/ART/<title>.png`.
- Keep `default.png` optional in CI artifacts; missing default-cover builds must fall back to embedded `MISSING.png`.
- Decide whether a broader ART system still needs to exist beyond those current code paths.

### 3) Install/build clarity
- Keep CI package layout and docs synchronized.
- Keep GitHub-built hardware artifacts self-identifying: package `BUILD_INFO.txt` and fail CI when expected embedded runtime markers are missing.
- Keep README installation steps explicit enough for users who are not familiar with PS2 launcher layouts.

## Deferred Ideas
- Additional themes/skins.
- Broader network/backend support after SMB and ILINK have defined baselines.
- More ambitious artwork cache policy after current launch/runtime issues are stable.
