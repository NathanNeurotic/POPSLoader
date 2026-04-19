Last updated: 2026-04-19

# ROADMAP

## Status Snapshot
- Core launcher functionality is present in code for MMCE, MX4SIO, HDD (PFS), USB, Disc (`DKWDRV`), settings persistence, cover preview, path editing, startup backend auto-init, and exit flows.
- The shared default/Profile 1 local POPSTARTER baseline was restored by rolling back to the `BETA-10-play-CHECKPOINT2` resolver behavior; user hardware confirmed that fix.
- Recorded hardware confirms `D-12` startup/Profile lookup is restored, `D-16` first-entry USB discovery is restored, and `D-15` non-HDD-POPSTARTER HDD-game launch is restored.
- The main stabilization blocker is still HDD-backed `POPSTARTER.ELF` execution when the launcher, sidecar/CWD, or configured POPSTARTER path lives on HDD (`D-10`, `D-14`).
- One 2026-03-29 artifact briefly moved `D-10` to a returned `rc=-1`, but later artifacts returned to black screen, so that was not a stable new boundary.
- Current repo line uses the partition-aware HDD reboot contract, separate exec-path reporting, profile-path normalization, and a post-load reset child-loader handoff for partition-aware HDD POPSTARTER loads while preserving the restored non-HDD POPSTARTER path.
- The later child-remount/cold-parent HDD POPSTARTER line still black-screened on hardware.
- Current repo line no longer keeps the selectorless stripped experiment. That selectorless line still black-screened on hardware, while the only recorded move away from a black screen happened before the selector was stripped.
- The latest stripped-line hardware popup returned `rc=-1`, but it also showed one more repo bug: probe/open used `pfs3:/.../POPSTARTER.ELF` while exec still used a rewritten `pfs:/.../POPSTARTER.ELF`.
- Current repo line now removes that stale exec-path rewrite from the stripped HDD-backed POPSTARTER experiment so probe/open and exec use the same resolved HDD ELF path, keeps reboot mode instead of non-reboot `LoadExecPS2`, and still uses the HDD embedded loader path.
- Repo comparison then showed the stripped HDD line was still hitting the child loader's newer `fileXio` direct-load shortcut for `pfsN:/...` because `exec_partition_context` had been cleared; current source now restores partition context only as loader metadata so the child uses the older partition-aware remount path again while still keeping the same visible exec path.
- Audit also found a Lua binding bug: the trailing reboot partition context was only recognized when `System.loadELF(...)` had at least four Lua arguments, so the HDD reboot path could not actually pass loader-only partition metadata in the three-argument form. Current source now accepts that form as well.
- Audit then found one more regression in the exact HDD child-loader path now in use: older child-loader source reloaded `SIO2MAN`, `MCMAN`, and `MCSERV` after HDD `SifIopReset(\"\")`, while later `HEAD` had drifted to jump straight to `ExecPS2`. Current source now restores that post-load reset child-loader handoff for partition-aware HDD POPSTARTER: mount `pfs0:`, load with mounted-path `SifLoadElf`, then run child-side `SifIopReset("")`/`SifIopSync()`, reinitialize RPC, reload `rom0:SIO2MAN`, `rom0:MCMAN`, and `rom0:MCSERV`, and jump via `ExecPS2`; hardware on this exact line is still `Unknown (verify on hardware)`.
- Latest user hardware report for current tip `0565ae5` still black-screened on `D-10`, so the mounted fileXio-first child-loader fallback did not resolve the blocker.
- Audit then found another remaining carry-over in parent-side launch prep: `PrepareForExternalELFLaunch(...)` still auto-kept the mounted `pfsN` slot whenever the exec path itself was on `pfsN:/...`. Current source now suppresses that implicit exec-slot keep specifically for HDD-backed POPSTARTER.
- The current hypothesis boundary is now narrower again: preserve the later loader/binding fixes, but give HDD-backed POPSTARTER back its selector-only `argv[0]` because the selectorless line did not improve hardware behavior.
- Current repo line also restores the generic reboot exec path in `src/elf_loader/src/elf.c` to the repo's older embedded-loader handoff style after the post-reset cleanup/module-reload contract from `src/system.cpp`.
- Treat slot preservation, launch CWD preservation, partition context, and other carried launch-state prep as non-goals for POPSTARTER itself. Current source now gives POPSTARTER only its selector in `argv[0]` while keeping loader-side partition metadata only as the minimum needed to load the HDD ELF.
- The latest EE-side HDD direct-load workaround was reverted after it did not fix `D-10` and coincided with a reported HDD-game regression when POPSTARTER stayed on the non-HDD boot device.
- `HDD (exFAT)` and `SMB (v1)` remain intentionally unimplemented menu entries.
- Detailed experiment chronology lives in `QA_REGRESSION_MATRIX.md` and `DECISIONS.md`.

## Immediate Priorities

### 1) HDD-backed POPSTARTER exec
- Reproduce and resolve `D-10`:
  - POPSLoader booted from HDD,
  - HDD game launched from HDD (PFS),
  - `POPSTARTER.ELF` resolved from HDD sidecar/CWD or configured HDD path,
  - current reported result: black-screen hang.
  - current iteration keeps selector-only `argv[0]` and loader partition metadata, and now uses mounted-path `SifLoadElf` followed by child-side IOP reset/module reload for the partition-aware HDD POPSTARTER child-loader load step.
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
