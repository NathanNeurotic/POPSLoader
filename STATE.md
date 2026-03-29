Last updated: 2026-03-29

# STATE

## Project Identity
POPSLoader is a PS2 launcher for POPStarter built on Enceladus runtime pieces, with behavior primarily orchestrated by embedded Lua modules (`system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`).

`QA_REGRESSION_MATRIX.md` is the detailed run ledger. This file summarizes the stable current repo state and the latest materially relevant hardware outcomes.

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
- HDD startup targets now run the same `PLDR.LoadHDDModules()` path used by the HDD page instead of only the lower-level exec helper.
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
- Current CI package also includes `PS1_POPSLOADER/BUILD_INFO.txt`, and the workflow fails if the built ELF is missing key embedded runtime markers or if the generated embedded-loader blob was not regenerated.

## Main Menu Feature Status
- `MMCE`: implemented in code.
- `MX4SIO`: implemented in code.
- `HDD (PFS)`: implemented in code (HDD POPSTARTER execution crash resolved in code).
- `USB`: implemented in code.
- `Disc (DKWDRV)`: implemented in code.
- `HDD (exFAT)`: not implemented.
- `SMB (v1)`: not implemented.

## Reported Hardware Status
- Shared default/Profile 1 local POPSTARTER baseline:
  - 2026-03-27 hardware report initially failed with `Cant find POPSTARTER ELF` when booted from USB with USB `POPSTARTER.ELF` sidecar/cwd/Profile 1.
  - comparison against `BETA-10-play-CHECKPOINT2` showed that branch's shared POPSTARTER resolution path worked without the later unverified common-path resolver/settings changes.
  - current source was rolled back to the checkpoint branch's shared resolver behavior for this path.
  - user confirmed that rolled-back source restored the shared baseline on hardware.
- `U-05` OSDSYS exit:
  - reported fixed on hardware.
- `D-12` startup backend auto-init:
  - a 2026-03-27 hardware report said booting from HDD did not auto-init the HDD driver stack.
  - current source now routes HDD startup targets through `PLDR.LoadHDDModules()` instead of only `EnsureHddRuntimeReadyForExec()`.
  - current source now keeps that startup HDD path limited to runtime readiness; it no longer scans HDD POPS partitions or builds the HDD game list during boot.
  - HDD page entry still performs the partition scan and game-list build, and optional HDD cache writing now reuses the page-built list instead of rebuilding at startup.
  - user previously confirmed the earlier HDD startup auto-init correction on hardware, but later 2026-03-28 reports on the narrowed boot-time split sources said HDD-backed startup/Profile POPSTARTER could still not be found after entering the USB page before the HDD page.
  - the raw boot `APP_DIR` fallback alone did not restore that case.
  - current source now also pre-resolves any HDD-backed startup/configured exec paths immediately after `PLDR.LoadHDDModules()` so HDD POPSTARTER/Profile paths are mounted and recorded without reintroducing HDD page work at boot.
  - current source also routes on-demand HDD path mounts through `PLDR.LoadHDDModules()` instead of only the lower-level `EnsureHddRuntimeReadyForExec()` gate, so HDD POPSTARTER/Profile probes from USB or other pages use the same runtime init path as HDD page entry.
  - current source also fixes the startup warm-path classification for Profile 1/default relative `POPSTARTER.ELF`, which had previously been skipped because only explicit `hdd:` / `pfs:` paths were being marked for HDD warm-up.
  - because `etc/boot.lua` establishes HDD boot on a dedicated `pfs1:` mount before `system.lua` runs, current source now also carries that exact boot partition/slot metadata into `system.lua`, seeds the HDD mount tracker from it, and rebuilds HDD sidecar/partition context from mounted `pfs1:` candidates instead of relying only on later rediscovery.
  - user later confirmed on 2026-03-28 that the exact-boot-mount/source-context source restored the USB-before-HDD-page startup/Profile repro on hardware.
  - latest recorded hardware on this line is therefore `PASS`; preserve that behavior through further `D-10` work.
- `D-16` first-entry USB backend discovery:
  - a 2026-03-27 hardware report said the first USB page entry reported no backend, but backing out and re-entering then worked.
  - current source now adds a bounded wait between failed USB root probes in `BuildUsbIdentityDeferred()`.
  - MX4SIO discovery code was not changed by this correction.
  - user later confirmed that corrected source fixed the first-entry USB issue on hardware.
- `D-10` HDD POPSTARTER on HDD:
  - expected resolved on current code.
  - repro: boot from HDD, launch HDD title with HDD `POPSTARTER.ELF` sidecar/CWD.
  - result: previous attempts black-screened.
  - the core issue was isolated to the embedded loader (`src/elf_loader/src/loader/src/loader.c`) where `wipeUserMem` erroneously cleared the top 1MB of memory (destroying RPC/kernel structures), and `SifExitCmd()` was being executed immediately after an IOP reset (`SifIopReset`), causing a hardware hang.
  - current source now leaves the top 1MB of memory intact and safely exits SIF (without `SifExitCmd()`) after an IOP reset, matching the reference `wLaunchELF` behavior.
  - current source also exposes an `R2` alternate HDD launch path for HDD-resident `POPSTARTER.ELF` that swaps only the selector contract to `hdd0:PART:pfs0:/GAME.ELF`.
  - a 2026-03-29 run on previous partition-aware source without the `wipeUserMem`/`SifExitCmd` fix yielded `rc=-1`, showing that handoff was correctly reached before the embedded loader crashed.
  - current-source hardware result is `Unknown (verify on hardware)` but highly expected to pass.
- `D-14` HDD-backed POPSTARTER with non-HDD game:
  - expected resolved on current code.
  - repro: launch a non-HDD title while `POPSTARTER.ELF` itself is configured on HDD.
  - this relies on the same embedded loader boot path as `D-10`, which had the memory wipe and SIF exit crash. With the embedded loader fixed, this path should complete successfully.
  - current source uses the partition-aware HDD reboot contract; hardware result is `Unknown (verify on hardware)`.
- `D-15` HDD game with non-HDD sidecar POPSTARTER:
  - reported as a regression on hardware.
  - repro: boot from a non-HDD device with sidecar `POPSTARTER.ELF` on that same device, then launch an HDD title.
  - 2026-03-27 user hardware reported a black screen on the EE-side HDD direct-load attempt.
  - a later 2026-03-27 hardware report also black-screened on the broader stripped-handoff HDD-game path.
  - current source now removes Lua-side HDD game pre-mount/CWD preservation from this path and passes only the normal selector handoff unless `POPSTARTER.ELF` itself is HDD/PFS-backed.
  - user later confirmed on 2026-03-28 that USB boot + USB sidecar/cwd `POPSTARTER.ELF` + HDD game passes on hardware.
- `U-10` BOOT.ELF after HDD page init:
  - one prior artifact was reported good,
  - repo history shows the BOOT.ELF modal later moved from its older non-reboot direct `System.loadELF(elf_path, 0, elf_path)` path to a reboot-I/O path with launch-CWD setup.
  - a later 2026-03-29 hardware report said BOOT.ELF still behaved incorrectly after HDD runtime had been initialized.
  - current working inference is that `U-10` may share the same underlying handoff/state-poisoning boundary as `D-10`, but that remains unproven and `U-10` still requires separate hardware confirmation.
  - current source now keeps the no-launch-CWD rollback, re-enables `reboot_iop = 1` for BOOT.ELF only when HDD runtime has already been loaded, and uses a BOOT.ELF-specific cold external-launch prep that clears the exec keep mask and unmounts tracked HDD slots instead of preserving boot PFS state.
  - current-source hardware status on this conditional-reboot/cold-prep line is `Unknown (verify on hardware)`.
- `U-06` PAL asset aspect:
  - current code compensates for PAL UI layout,
  - hardware result is still `Unknown (verify on hardware)`.

## Known Open Work
- Preserve the reported `D-12` HDD startup auto-init fix while iterating on HDD launch-path regressions.
- Preserve the dedicated HDD boot `pfs1:` mount contract from `etc/boot.lua` while iterating on startup/Profile resolution.
- Preserve the reported `D-16` USB first-entry fix and confirm MX4SIO behavior remains unchanged on future retests.
- Validate the resolved HDD-backed `POPSTARTER.ELF` handoff when POPSTARTER itself is on HDD, including non-HDD game launches.
- Preserve the restored `D-15` path where HDD titles launch correctly when POPSTARTER stays on the non-HDD boot device.
- Re-verify `BOOT.ELF` after HDD page init on current source.
- Record concrete run logs in `QA_REGRESSION_MATRIX.md`.
- Implement HDD exFAT menu flow.
- Implement SMB menu flow.
- Decide whether a broader ART system is still needed beyond current sidecar/HDD-common cover support.

## Verification Status
- Code/build/package statements above are repository-verified.
- Hardware behavior is `Unknown (verify on hardware)` unless explicitly recorded as a reported result.
