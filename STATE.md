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

## Main Menu Feature Status
- `MMCE`: implemented in code.
- `MX4SIO`: implemented in code.
- `HDD (PFS)`: implemented in code.
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
  - user later confirmed that corrected source fixed HDD startup auto-init on hardware.
- `D-16` first-entry USB backend discovery:
  - a 2026-03-27 hardware report said the first USB page entry reported no backend, but backing out and re-entering then worked.
  - current source now adds a bounded wait between failed USB root probes in `BuildUsbIdentityDeferred()`.
  - MX4SIO discovery code was not changed by this correction.
  - user later confirmed that corrected source fixed the first-entry USB issue on hardware.
- `D-10` HDD POPSTARTER on HDD:
  - reported failing on hardware.
  - repro: boot from HDD, launch HDD title with HDD `POPSTARTER.ELF` sidecar/CWD.
  - result: black-screen hang.
  - 2026-03-27 re-test of the current source still failed when booted from HDD with default/Profile 1/cwd/sidecar `POPSTARTER.ELF` on HDD and game device HDD.
  - current source also exposes an `R2` alternate HDD launch path for HDD-resident `POPSTARTER.ELF` that swaps only the selector contract to `hdd0:PART:pfs0:/GAME.ELF`.
  - later 2026-03-27 experimental sources also black-screened after direct-load, Memory Card staging, and stripped-handoff changes.
  - user later confirmed on 2026-03-28 that the narrowed source restored `D-15`, so this remaining blocker is again isolated to HDD-backed `POPSTARTER.ELF`.
  - a later 2026-03-28 re-test still black-screened on the narrowed Lua-side HDD-backed source with no visible positive change.
  - a later 2026-03-28 re-test on the loader-side no-auto-exec-slot-preserve source still black-screened on both `X` and `R2`.
  - a later 2026-03-28 re-test on the forced-`reboot_iop = 1` source still black-screened on both `X` and `R2`.
  - a later 2026-03-28 re-test on the direct-`hdd0:PART:pfsN:/POPSTARTER.ELF` preference source still black-screened on `X`.
  - a later 2026-03-28 re-test on the mounted-`pfs0:` embedded-loader source still black-screened on `X`.
  - current source now keeps the narrowed Lua-side HDD-backed handoff, keeps the reboot loader path on mounted `pfs0:/...`, stops tearing down EE-side SIF state before `ExecPS2` into the embedded loader, and no longer preserves boot PFS slots during launch prep for HDD-backed `POPSTARTER.ELF`.
  - corrected-source hardware status is still `Unknown (verify on hardware)`.
- `D-14` HDD-backed POPSTARTER with non-HDD game:
  - reported failing on hardware.
  - repro: launch a non-HDD title while `POPSTARTER.ELF` itself is configured on HDD.
  - 2026-03-27 user hardware also black-screened when launching a USB game with Profile 2 pointing `POPSTARTER.ELF` to HDD.
  - the user later clarified that the other same-day 2026-03-28 success report referred to `D-15`, not this case.
  - a later 2026-03-28 re-test on the forced-`reboot_iop = 1` source still black-screened on `X`; `R2` produced no response in that non-HDD-game repro.
  - a later 2026-03-28 re-test on the direct-`hdd0:PART:pfsN:/POPSTARTER.ELF` preference source still black-screened on `X`.
  - current source now uses the same mounted-`pfs0:` embedded-loader handoff as `D-10` for HDD-backed POPSTARTER, stops tearing down EE-side SIF state before `ExecPS2` into the embedded loader, and no longer preserves boot PFS slots during launch prep for HDD-backed `POPSTARTER.ELF`.
  - corrected-source hardware status is still `Unknown (verify on hardware)`.
- `D-15` HDD game with non-HDD sidecar POPSTARTER:
  - reported as a regression on hardware.
  - repro: boot from a non-HDD device with sidecar `POPSTARTER.ELF` on that same device, then launch an HDD title.
  - 2026-03-27 user hardware reported a black screen on the EE-side HDD direct-load attempt.
  - a later 2026-03-27 hardware report also black-screened on the broader stripped-handoff HDD-game path.
  - current source now removes Lua-side HDD game pre-mount/CWD preservation from this path and passes only the normal selector handoff unless `POPSTARTER.ELF` itself is HDD/PFS-backed.
  - user later confirmed on 2026-03-28 that USB boot + USB sidecar/cwd `POPSTARTER.ELF` + HDD game passes on hardware.
- `U-10` BOOT.ELF after HDD page init:
  - one prior artifact was reported good,
  - a later launch-backend experiment regressed it,
  - source has now been restored away from that experiment,
  - current hardware status on restored source is `Unknown (verify on hardware)`.
- `U-06` PAL asset aspect:
  - current code compensates for PAL UI layout,
  - hardware result is still `Unknown (verify on hardware)`.

## Known Open Work
- Preserve the reported `D-12` HDD startup auto-init fix while iterating on HDD launch-path regressions.
- Preserve the reported `D-16` USB first-entry fix and confirm MX4SIO behavior remains unchanged on future retests.
- Resolve HDD-backed `POPSTARTER.ELF` handoff when POPSTARTER itself is on HDD, including non-HDD game launches.
- Preserve the restored `D-15` path where HDD titles launch correctly when POPSTARTER stays on the non-HDD boot device.
- Re-verify `BOOT.ELF` after HDD page init on current source.
- Record concrete run logs in `QA_REGRESSION_MATRIX.md`.
- Implement HDD exFAT menu flow.
- Implement SMB menu flow.
- Decide whether a broader ART system is still needed beyond current sidecar/HDD-common cover support.

## Verification Status
- Code/build/package statements above are repository-verified.
- Hardware behavior is `Unknown (verify on hardware)` unless explicitly recorded as a reported result.
