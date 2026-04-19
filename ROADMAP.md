Last updated: 2026-04-19

# ROADMAP

## Status Snapshot
- Core launcher functionality is present in code for MMCE, MX4SIO, HDD (PFS), USB, Disc (`DKWDRV`), settings persistence, cover preview, path editing, startup backend auto-init, and exit flows.
- The shared default/Profile 1 local POPSTARTER baseline was restored by rolling back to the `BETA-10-play-CHECKPOINT2` resolver behavior; user hardware confirmed that fix.
- Recorded hardware confirms `D-12` startup/Profile lookup is restored, `D-16` first-entry USB discovery is restored, and `D-15` non-HDD-POPSTARTER HDD-game launch is restored.
- The main stabilization blocker is still HDD-backed `POPSTARTER.ELF` execution when the launcher, sidecar/CWD, or configured POPSTARTER path lives on HDD (`D-10`, `D-14`).
- One 2026-03-29 artifact briefly moved `D-10` to a returned `rc=-1`, but later artifacts returned to black screen, so that was not a stable new boundary.
- Current repo line uses the partition-aware HDD reboot contract, separate exec-path reporting, profile-path normalization, and a no-reset-first child-loader handoff for partition-aware HDD POPSTARTER loads while preserving the restored non-HDD POPSTARTER path.
- The later child-remount/cold-parent HDD POPSTARTER line still black-screened on hardware.
- Current repo line no longer keeps the selectorless stripped experiment. That selectorless line still black-screened on hardware, while the only recorded move away from a black screen happened before the selector was stripped.
- The latest stripped-line hardware popup returned `rc=-1`, but it also showed one more repo bug: probe/open used `pfs3:/.../POPSTARTER.ELF` while exec still used a rewritten `pfs:/.../POPSTARTER.ELF`.
- Current repo line now removes that stale exec-path rewrite from the stripped HDD-backed POPSTARTER experiment so probe/open and exec use the same resolved HDD ELF path, keeps reboot mode instead of non-reboot `LoadExecPS2`, and still uses the HDD embedded loader path.
- Repo comparison then showed the stripped HDD line was still hitting the child loader's newer `fileXio` direct-load shortcut for `pfsN:/...` because `exec_partition_context` had been cleared; current source now restores partition context only as loader metadata so the child uses the older partition-aware remount path again while still keeping the same visible exec path.
- Audit also found a Lua binding bug: the trailing reboot partition context was only recognized when `System.loadELF(...)` had at least four Lua arguments, so the HDD reboot path could not actually pass loader-only partition metadata in the three-argument form. Current source now accepts that form as well.
- Audit then found one more regression in the exact HDD child-loader path now in use: older child-loader source reloaded `SIO2MAN`, `MCMAN`, and `MCSERV` after HDD `SifIopReset(\"\")`, while later `HEAD` had drifted to jump straight to `ExecPS2`. Current source now uses a no-reset-first child-loader handoff for partition-aware HDD POPSTARTER with bounded mounted-path load fallback (`fileXio` segment load first, mounted-path `SifLoadElf` fallback, then `SifExitRpc`/`ExecPS2` without child-side reset/module reload); hardware on this exact line is still `Unknown (verify on hardware)`.
- Latest user hardware report from the 2026-04-02 GitHub artifact (`cd76569`) still black-screened on `D-10`.
- Audit identified the mechanism behind the persistent black screen: `ExecuteViaEmbeddedLoader` called `SifExitCmd()` unconditionally before `ExecPS2(loader)`; on a non-reset IOP, `SifExitCmd()` sends a "terminate" to the IOP's SIF CMD handler; the loader's `SifInitRpc(0)` then hangs waiting for a response that never comes = black screen. Reference launchers (wLaunchELF) do not call `SifExitCmd` before their embedded loader on a non-reset IOP.
- Current repo line now conditionally skips `SifExitIopHeap`, `SifExitRpc`, and `SifExitCmd` in `ExecuteViaEmbeddedLoader` when `partition_context` is HDD-backed; non-HDD reboot paths retain the full teardown sequence. Hardware on this exact line is `Unknown (verify on hardware)`.
- `HDD (exFAT)` and `SMB (v1)` remain intentionally unimplemented menu entries.
- Detailed experiment chronology lives in `QA_REGRESSION_MATRIX.md` and `DECISIONS.md`.

## Immediate Priorities

### 1) HDD-backed POPSTARTER exec
- Reproduce and resolve `D-10`:
  - POPSLoader booted from HDD,
  - HDD game launched from HDD (PFS),
  - `POPSTARTER.ELF` resolved from HDD sidecar/CWD or configured HDD path,
  - current reported result: black-screen hang.
  - current no-reset-first iteration keeps selector-only `argv[0]` and loader partition metadata, removes the child-side post-load reset/module-reload stage, uses mounted-path fileXio-first with mounted-path `SifLoadElf` fallback for the partition-aware HDD POPSTARTER child-loader load step, and now skips `SifExitIopHeap`/`SifExitRpc`/`SifExitCmd` before `ExecPS2(loader)` when the IOP was not reset.
  - preserve `D-15`, `D-12`, `D-16`, `U-05`, and shared Profile 1/default sidecar behavior while iterating.
  - treat `D-14` as the paired non-HDD-game repro for the same HDD-backed POPSTARTER blocker.
  - use `QA_REGRESSION_MATRIX.md` for the full experiment chronology instead of rebuilding that ledger here.

### 2) External exit/launch re-validation
- Re-run `U-05` (`OSDSYS`) and `U-10` (`BOOT.ELF after HDD page init`) on current source after the BOOT.ELF standard-prep/conditional-reboot change for HDD-initialized sessions.
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

### 2) Art/asset behavior
- Keep current cover behavior stable:
  - sidecar PNG beside the selected `.VCD`,
  - HDD common art from `hdd0:__common/POPS/ART/<title>.png`.
- Decide whether a broader ART system still needs to exist beyond those current code paths.

### 3) Install/build clarity
- Keep CI package layout and docs synchronized.
- Keep GitHub-built hardware artifacts self-identifying: package `BUILD_INFO.txt` and fail CI when expected embedded runtime markers are missing or embedded-loader rebuild propagation does not reach final packaged ELF outputs.
- Keep README installation steps explicit enough for users who are not familiar with PS2 launcher layouts.

## Deferred Ideas
- Additional themes/skins.
- Broader network backend support after SMB has a defined baseline.
- More ambitious artwork cache policy after current launch/runtime issues are stable.
