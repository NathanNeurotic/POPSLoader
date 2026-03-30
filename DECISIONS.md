Last updated: 2026-03-29

# DECISIONS

## Decision Log Format
Each entry records:
- Date (`YYYY-MM-DD`)
- Decision
- Rationale
- Implications
- Evidence

## Decision Log

### 2026-03-06 — Lua runtime is embedded-only at boot
- Decision: boot and required runtime Lua modules are loaded from embedded blobs, not loose filesystem Lua files.
- Rationale: deterministic startup and fewer layout-dependent failures.
- Implications: editing runtime Lua requires rebuilding the ELF.
- Evidence: `src/luaplayer.cpp`, `etc/boot.lua`, `Makefile`.

### 2026-03-06 — Settings persist as a transaction on Settings/Profile exit
- Decision: settings edits are staged in UI draft state and committed on confirm/leave.
- Rationale: avoid repeated writes while navigating and keep save/apply failure handling explicit.
- Implications: runtime/UI state sync must still happen if save/apply fails.
- Evidence: `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua`.

### 2026-03-26 — USB vs MX4SIO identity is authoritative by mount driver
- Decision: mounted mass roots are classified by driver identity, not by path spelling.
- Rationale: real hardware can expose both USB and MX4SIO through `mass*:/`.
- Implications: startup auto-init, boot-device labeling, and page list building must continue to use mount-driver queries.
- Evidence: `bin/POPSLDR/system.lua`, `src/luasystem.cpp`.

### 2026-03-26 — Runtime device locks are no longer enforced
- Decision: the old per-session device lock system is no longer an active runtime constraint.
- Rationale: device access should not be blocked by stale lock state.
- Implications: docs must not claim that switching devices requires restart; future changes must not silently reintroduce that gate.
- Evidence: `bin/POPSLDR/ui.lua` (`canEnterDevice`, `setDeviceLock`).

### 2026-03-26 — Startup backend initialization is path-driven
- Decision: startup backend auto-init considers boot paths and configured executable/profile paths, not just the page the user opens first.
- Rationale: a configured POPSTARTER/DKWDRV/profile path can require backend drivers before any device page is visited.
- Implications: startup docs and validation must cover boot source plus configured paths, and HDD startup targets must run the full HDD module-load path rather than only low-level exec initialization.
- Evidence: `bin/POPSLDR/system.lua` (`CollectStartupBackendTargets`, `AutoInitStartupBackends`).

### 2026-03-26 — PAL UI uses the same 640x448 raster layout as NTSC-authored UI assets
- Decision: PAL mode keeps the UI raster at `640x448` instead of stretching the authored layout vertically.
- Rationale: reduce PAL squish on menus and authored UI assets.
- Implications: final on-TV proportions still require hardware confirmation.
- Evidence: `bin/POPSLDR/system.lua`, `bin/POPSLDR/ui.lua`.

### 2026-03-26 — Release ZIP contract is strict and PATCH_5-based
- Decision: CI package includes exact `PS1_POPSLOADER/*` launcher files plus `POPS/PATCH_5.BIN`, now including `PS1_POPSLOADER/BUILD_INFO.txt`, and rejects legacy `POPS/*.tm2` payloads.
- Rationale: prevent release drift and ambiguous installation instructions.
- Implications: docs and workflow validation must stay synchronized, and GitHub-built hardware candidates now carry a visible build stamp while CI also checks for expected embedded runtime markers before packaging.
- Evidence: `.github/workflows/compilation.yml`.

### 2026-03-29 — `QA_REGRESSION_MATRIX.md` is the detailed run ledger
- Decision: keep per-artifact hardware/CI chronology in `QA_REGRESSION_MATRIX.md`, while `README.md`, `STATE.md`, and `ROADMAP.md` summarize the stable current state and constraints.
- Rationale: repeated experiment history had started drifting across the root docs and obscuring the actual current handoff state.
- Implications: root docs should point to the matrix for detailed chronology instead of carrying their own competing mini-ledgers.
- Evidence: repository documentation audit on 2026-03-29.

## Open Investigations
- HDD startup auto-init on HDD boot/configured paths:
  - a 2026-03-27 hardware report said booting from HDD did not auto-init the HDD driver stack.
  - current code had detected HDD startup targets correctly but only called `EnsureHddRuntimeReadyForExec()`, which stops at low-level `HDD.Initialize()`.
  - current source now routes HDD startup targets through `PLDR.LoadHDDModules()` so startup uses the same HDD status/partition/cache initialization path as the HDD page.
  - a later boot-time report showed that using the full HDD page path at startup also caused large HDD libraries to spend boot time scanning partitions and building the games list.
  - current source therefore keeps startup HDD auto-init limited to runtime readiness only; partition scanning and game-list building remain page-entry work.
  - optional HDD cache writing now reuses the page-built game list instead of rebuilding one during startup.
  - later 2026-03-28 hardware reports on that narrowed boot-time split source still said HDD-backed startup/Profile POPSTARTER could disappear after entering the USB page before the HDD page.
  - the raw boot `APP_DIR` fallback alone did not restore that case.
  - current source therefore also pre-resolves any HDD-backed startup/configured exec paths immediately after `PLDR.LoadHDDModules()` so HDD POPSTARTER/Profile paths are mounted and recorded without reintroducing HDD page work at boot.
  - current source also routes on-demand HDD path mounts through `PLDR.LoadHDDModules()` instead of only the lower-level `EnsureHddRuntimeReadyForExec()` gate, so later POPSTARTER/Profile resolution from USB or other pages uses the same runtime init path as HDD page entry.
  - repo inspection also showed the startup HDD warm-path list had been skipping Profile 1/default relative `POPSTARTER.ELF` because it only recorded explicit `hdd:` / `pfs:` paths, so current source now includes that default-relative case when boot source is HDD.
  - repo inspection of `etc/boot.lua` also showed HDD boot is established on a dedicated `pfs1:` mount before `system.lua` runs, so current source now carries that exact boot partition/slot metadata into `system.lua`, seeds the HDD mount tracker from it, and rebuilds HDD sidecar/partition context from mounted `pfs1:` candidates instead of assuming low-level HDD readiness alone preserves the boot-side path contract.
  - user later confirmed on 2026-03-28 that the exact-boot-mount/source-context source restored the USB-before-HDD-page startup/Profile repro on hardware, so the remaining blocker is no longer startup/Profile lookup.
- USB first-entry backend discovery:
  - a 2026-03-27 hardware report said the first USB page entry reported no backend, but backing out and re-entering then worked.
  - current code already had bounded retry loops for USB root discovery, but all retries happened back-to-back with no yield for the backend to become visible.
  - current source now adds a bounded wait only in `BuildUsbIdentityDeferred()`, leaving MX4SIO discovery logic unchanged.
  - user later confirmed the corrected source on hardware.
- HDD `POPSTARTER.ELF` when launcher/sidecar/CWD is on HDD:
  - current reported hardware result is still a black-screen hang.
  - path/mount/CWD mitigations plus the HDD-backed non-reboot `ExecPS2` cleanup are present in current code.
  - a 2026-03-27 hardware re-test of the current source still black-screened with boot source HDD, default/Profile 1/cwd/sidecar `POPSTARTER.ELF` on HDD, and game device HDD.
  - a second 2026-03-27 hardware report also black-screened while launching a USB game with Profile 2 pointing `POPSTARTER.ELF` to HDD, so the remaining failure is now treated as the HDD-backed POPSTARTER exec path itself rather than only HDD game routing.
  - a later 2026-03-27 hardware report also said booting from another device and launching an HDD title with sidecar `POPSTARTER.ELF` on that boot device black-screened, and the user identified it as a regression.
  - the EE-side HDD direct-load workaround in `src/elf_loader/src/elf.c` has therefore been reverted; it did not fix `D-10` and is no longer supported by hardware evidence.
  - later 2026-03-27 Memory Card staging, stripped-handoff, CWD/selector, and HDD-init-state experiments in `bin/POPSLDR/system.lua` did not fix `D-10` / `D-14` and coincided with repeated `D-15` failures.
  - user later confirmed on 2026-03-28 that USB boot + USB sidecar/cwd `POPSTARTER.ELF` + HDD game passes on the narrowed source, so the remaining blocker is again isolated to HDD-backed `POPSTARTER.ELF`.
  - a later 2026-03-28 re-test still black-screened on that narrowed Lua-side source with no visible positive change, so the next shared preservation step tested was the loader's automatic post-load exec-slot keep in `src/elf_loader/src/elf.c`.
  - that loader-side no-auto-exec-slot-preserve source still left non-HDD POPSTARTER HDD-game launches on the restored selector-only handoff, while `R2` could still request the explicit `hdd0:PART:pfs0:/GAME.ELF` selector.
  - a later 2026-03-28 re-test on that loader-side source still black-screened for `D-10` on both `X` and `R2`, and the user clarified the other same-day success result was another `D-15` run rather than `D-14`.
  - a later 2026-03-28 re-test on that forced-`reboot_iop = 1` source still black-screened for `D-10` and `D-14`, so reboot mode alone did not separate the remaining failure.
  - a later 2026-03-28 re-test on that direct-`hdd0:PART:pfsN:/POPSTARTER.ELF` preference source still black-screened for both `D-10` and `D-14`, so exec-path form alone did not separate the remaining failure.
  - follow-up repo inspection then found `BuildDirectHddExecPathFromMounted()` had been generating malformed direct aliases without the colon after `pfsN`, so that earlier direct-path experiment was not a clean control.
  - inspection of `wLaunchELF` and `PlayStation2-Basic-BootLoader-Extended` showed the common HDD ELF pattern is to mount the target partition explicitly and feed `SifLoadElf` a mounted `pfs0:/...` path rather than a direct `hdd0:` path.
  - a later 2026-03-28 re-test on that mounted-`pfs0:` embedded-loader source still black-screened for `D-10`.
  - broader comparison then showed current HEAD had drifted away from this repo's own March 24 partitioned-loader diagnostics by reintroducing `SifExitRpc()` immediately before the parent `ExecPS2` into the embedded loader.
  - this repo's earlier HDD diagnostics also recorded that the embedded-loader boundary only became stable once EE-side SIF teardown before `ExecPS2` was removed from the parent handoff.
  - comparison against `wLaunchELF` and `PlayStation2-Basic-BootLoader-Extended` also showed another remaining mismatch: this repo's embedded loader had no separate original HDD source-context argument, so it could only make reset decisions from the mounted `pfs0:/...` load target.
  - follow-up repo comparison then showed the remaining source-context gap was broader than the loader alone: Lua had usually already normalized HDD POPSTARTER to mounted `pfs1:` / `pfs3:` paths before the reboot loader saw it, so the loader was still not being given the original HDD path it needed to force the `pfs0:` remount pattern used by `wLaunchELF`.
  - broader comparison against `wLaunchELF` also showed the remaining ownership mismatch was not just reset policy: the parent/loader boundary there does not pre-unmount PFS state and the embedded loader calls `SifLoadElf` directly after `SifInitRpc(0)`, without `SifLoadFileInit/Exit`.
  - a later 2026-03-28 re-test on that exact-boot-mount/source-context source still black-screened for `D-10`, so full raw-source reconstruction alone was still not the missing link.
  - repo comparison against the local `ps2sdk` tree then showed the remaining drift was structural: the header still documented a partition-aware loader contract, but the live reboot path was still using a custom source-context channel instead of the same partition/load-path/argv split.
  - current source therefore keeps the restored non-HDD POPSTARTER path, seeds the exact boot `pfs1:` mount metadata from `etc/boot.lua` into Lua-side HDD mount tracking, and replaces that ad hoc reboot handoff with an explicit partition-aware contract across `bin/POPSLDR/system.lua`, `src/luasystem.cpp`, `src/elf_loader/src/elf.c`, and `src/elf_loader/src/loader/src/loader.c`.
  - on that contract, Lua passes exact HDD partition context separately from the mounted load path and normalizes the partition-aware exec filename back to generic `pfs:/...`.
  - a 2026-03-29 hardware result on the prior partition-aware source no longer black-screened, but the launcher regained control with `rc=-1 (returned after 22618 ms)`, which meant that specific artifact had moved the remaining failure past the old black-screen boundary and into the embedded-loader or target-`ExecPS2` handoff.
  - a later 2026-03-29 GitHub artifact re-test on that broader partition-aware/current-source line black-screened again, so the returned-rc boundary is not yet stable enough to treat as the new steady state.
  - repo history comparison then showed that this partition-aware reboot path had drifted away from the original parent-side embedded-loader jump contract in `src/elf_loader/src/elf.c`: it no longer performed the BRAM wipe or the original `SifInitRpc`/`SifLoadFileInit`/`SifLoadFileExit` and `SifExitIopHeap`/`SifExitRpc`/`SifExitCmd` sequence around that final `ExecPS2`.
  - repo history comparison also showed that earlier child-loader `fileXio` experiments had never been retested after the later parent-side jump-contract fixes, so they were not a clean control for the current boundary.
  - repo comparison also showed a later mismatch in the broader current line: the BOOT.ELF-specific cold external-launch helper had started pre-unmounting tracked HDD slots before the POPSTARTER parent-loader transfer, even though the earlier returned-`rc=-1` partition-aware artifact preceded that pre-unmount change and the recorded reference-loader comparison did not support pre-unmounting PFS state before the parent/loader boundary.
  - later repo audit also showed that POPSLoader's normal POPSTARTER launch path passes only the selector as target `argv[0]`, while the newer HDD child-loader path had started prepending a replacement executable path; that changed the HDD-backed POPSTARTER argv layout away from the working non-HDD path.
  - a later hardware failure popup also showed `POPSTARTER` resolving to the full mounted file path while the separate `Exec path` field had dropped the basename, which narrowed another repo-side risk: the partition-scoped exec path had been precomputed too early instead of being derived from the final resolved POPSTARTER path right before `System.loadELF(...)`.
  - repo audit also found that selected-profile state and stored canonical profile paths could drift apart, so a chosen Profile 1/default path could still launch another profile's canonical HDD POPSTARTER path without the user realizing it.
  - the repo then hit the clearest remaining slot-preservation boundary: even with POPSTARTER-specific post-load keep state cleared, the partition-aware child-loader path still depended on inheriting a live parent-side `pfs0:` mount, which kept the target HDD slot alive across the embedded-loader jump.
  - a later hardware re-test on that child-remount/cold-parent line still black-screened, so removing the inherited parent mount dependency was not sufficient on its own.
  - the user then explicitly narrowed the short-term objective further: stop carrying extra launch-state prep, and focus on getting the HDD-backed ELF to start.
  - current source still keeps the safer embedded-loader fix (`e2c4b8f`) that avoids `printf`/`snprintf` dependence in that environment, returns the actual embedded-loader `ExecPS2` result instead of collapsing it to `-1`, normalizes stale canonical profile-path state before launch/save, and still exposes the real exec filename separately from the probe/open path in the launcher popup.
  - the latest hardware popup on that stripped line returned `rc=-1`, but it also showed the source was still doing one unnecessary transformation: probing/opening `pfs3:/.../POPSTARTER.ELF` while separately trying to exec a rewritten `pfs:/.../POPSTARTER.ELF`.
  - current source now removes that stale exec-path rewrite from the stripped HDD-backed POPSTARTER experiment so probe/open and exec use the same resolved HDD ELF path, retries that exact stripped HDD ELF launch through reboot mode instead of the non-reboot `LoadExecPS2` path that returned `rc=-1`, and still uses the HDD embedded loader.
  - repo comparison then exposed the next real drift in that stripped line: with `exec_partition_context = nil`, the child loader falls into the newer `fileXio` direct-load shortcut for `pfsN:/...` and skips the older remount/reset path that existed before commit `47c1623`.
  - current source therefore restores partition context only as loader metadata for HDD-backed POPSTARTER so the child uses the remount/reset path again, while still keeping no launch CWD and the same visible resolved exec path.
  - audit also found a Lua binding bug in `src/luasystem.cpp`: the trailing reboot partition context was only parsed when `System.loadELF(...)` had at least four Lua arguments, so the new HDD reboot path could not actually pass loader-only partition metadata until current source widened that check to the three-argument form.
  - audit then exposed one more regression in the exact HDD child-loader path now in use: older child-loader source reloaded `SIO2MAN`, `MCMAN`, and `MCSERV` after HDD `SifIopReset("")`, while current HEAD had drifted to jump straight to `ExecPS2`. Current source restores that older child-loader reload before the final handoff.
  - audit then exposed another remaining carry-over in parent-side launch prep: `PrepareForExternalELFLaunch(...)` still auto-kept the mounted `pfsN` slot whenever the exec path itself was on `pfsN:/...`. Current source now suppresses that implicit exec-slot keep specifically for HDD-backed POPSTARTER, so the stripped line no longer preserves the mounted parent slot just because the executable was resolved there.
  - the latest hardware re-test on that stripped selectorless line still black-screened, while the only recorded move away from a black screen happened before the selector was stripped.
  - current working rule from repo evidence: POPSTARTER itself does not need slot preservation, launch CWD, partition context, or other carried runtime state after exec, but it does still want its selector in `argv[0]`. Current source therefore restores selector-only `argv[0]` for HDD-backed POPSTARTER while keeping partition context only as loader metadata so the HDD ELF can be loaded cleanly.
  - a later 2026-03-29 hardware re-test on replacing `snprintf` with safe strings and removing `SifExitCmd()` in the embedded loader still black-screened, confirming those hardware crash/hang mitigations alone did not solve `D-10`.
  - a later 2026-03-30 hardware re-test on the `wLaunchELF` PFS retention mimic (leaving `pfs0:` mounted and removing the child `SifIopReset`) finally stabilized execution and caused an OSDSYS fallback. This confirms the embedded loader ran but failed to load the ELF, directly isolating `SifLoadElf`'s documented failure to read from PFS.
  - a later 2026-03-30 hardware re-test forcing `fileXio` direct load on HDD/PFS paths still resulted in an OSDSYS fallback. This exposed a logic flaw in the parent (`elf.c`), where it generated a `keep_mask` of 0 for `pfs0:`, explicitly instructing the unmount loop to teardown the exact partition the embedded child loader relies on to read the target ELF.
  - a later 2026-03-30 hardware re-test preserving `pfs0:` in the parent loader still returned to OSDSYS. Memory notes and code review then confirmed `loader.c`'s `wipeUserMem` was clearing memory all the way to `GetMemorySize()`, destroying the top 1MB of memory where the EE RPC buffers reside, rendering `fileXio` unable to read the ELF.
  - current source still keeps the `R2` selector-path experiment for HDD game launches, but that remains secondary to restoring and preserving the non-HDD POPSTARTER baseline for HDD titles.
- `BOOT.ELF` after HDD page init:
  - repo history shows the BOOT.ELF modal originally used a simpler non-reboot `System.loadELF(elf_path, 0, elf_path)` path without launch-CWD setup, and later source changed it to `reboot_iop = 1` plus launch-CWD.
  - a later 2026-03-29 hardware report said BOOT.ELF still behaved incorrectly once HDD runtime had been initialized, which points more narrowly at carried HDD/IOP state than BOOT.ELF lookup itself.
  - current working inference is that this `U-10` failure may share the same underlying handoff/state-poisoning boundary as `D-10`, but that remains an inference rather than a proven shared root cause.
  - a later 2026-03-29 hardware report on that cold-prep/no-forced-reboot line still froze on `HDD boot -> default/Profile 1 sidecar/cwd POPSTARTER on HDD -> enter HDD page -> Exit -> BOOT.ELF`, so removing forced reboot alone did not isolate the failure.
  - a later 2026-03-29 hardware report said the restored-standard-prep/no-forced-reboot line still froze as well, so prep selection alone also did not isolate the failure.
  - current source therefore keeps the no-launch-CWD rollback and standard external-launch prep, retries `reboot_iop = 1` after HDD init, and restores the generic reboot path in `src/elf_loader/src/elf.c` to the repo's older embedded-loader handoff style after the post-reset cleanup/module-reload contract from `src/system.cpp`.
  - current hardware status on that standard-prep/conditional-reboot source is still `Unknown (verify on hardware)`.
- PAL asset proportions:
  - code compensates for PAL layout,
  - final display result still needs hardware confirmation.
