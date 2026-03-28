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
  - corrected-source hardware status is still `Unknown (verify on hardware)`.
- `D-16` first-entry USB backend discovery:
  - a 2026-03-27 hardware report said the first USB page entry reported no backend, but backing out and re-entering then worked.
  - current source now adds a bounded wait between failed USB root probes in `BuildUsbIdentityDeferred()`.
  - MX4SIO discovery code was not changed by this correction.
  - corrected-source hardware status is still `Unknown (verify on hardware)`.
- `D-10` HDD POPSTARTER on HDD:
  - reported failing on hardware.
  - repro: boot from HDD, launch HDD title with HDD `POPSTARTER.ELF` sidecar/CWD.
  - result: black-screen hang.
  - 2026-03-27 re-test of the current source still failed when booted from HDD with default/Profile 1/cwd/sidecar `POPSTARTER.ELF` on HDD and game device HDD.
  - current source also exposes an `R2` alternate HDD launch path for HDD-resident `POPSTARTER.ELF` that swaps only the selector contract to `hdd0:PART:pfs0:/GAME.ELF`.
  - current source now also tries to stage HDD-backed `POPSTARTER.ELF` to the first available non-HDD launch path before exec, with corrected direct-launch `reboot_iop` fallback if staging is unavailable.
- `D-14` HDD-backed POPSTARTER with non-HDD game:
  - reported failing on hardware.
  - repro: launch a non-HDD title while `POPSTARTER.ELF` itself is configured on HDD.
  - 2026-03-27 user hardware also black-screened when launching a USB game with Profile 2 pointing `POPSTARTER.ELF` to HDD.
  - current source uses the same staging-or-corrected-direct-launch path for this case.
- `D-15` HDD game with non-HDD sidecar POPSTARTER:
  - reported as a regression on hardware.
  - repro: boot from a non-HDD device with sidecar `POPSTARTER.ELF` on that same device, then launch an HDD title.
  - 2026-03-27 user hardware reported a black screen on the EE-side HDD direct-load attempt.
  - that direct-load workaround has now been reverted; reverted-source hardware status is still `Unknown (verify on hardware)`.
- `U-10` BOOT.ELF after HDD page init:
  - one prior artifact was reported good,
  - a later launch-backend experiment regressed it,
  - source has now been restored away from that experiment,
  - current hardware status on restored source is `Unknown (verify on hardware)`.
- `U-06` PAL asset aspect:
  - current code compensates for PAL UI layout,
  - hardware result is still `Unknown (verify on hardware)`.

## Known Open Work
- Re-verify `D-12` on current source, especially HDD boot/configured HDD-path startup cases.
- Re-verify `D-16` on current source and confirm MX4SIO behavior is unchanged.
- Resolve HDD-backed `POPSTARTER.ELF` handoff when POPSTARTER itself is on HDD, including non-HDD game launches.
- Re-confirm that HDD titles still launch correctly when POPSTARTER stays on the non-HDD boot device after reverting the failed HDD direct-load attempt.
- Re-verify `BOOT.ELF` after HDD page init on current source.
- Record concrete run logs in `QA_REGRESSION_MATRIX.md`.
- Implement HDD exFAT menu flow.
- Implement SMB menu flow.
- Decide whether a broader ART system is still needed beyond current sidecar/HDD-common cover support.

## Verification Status
- Code/build/package statements above are repository-verified.
- Hardware behavior is `Unknown (verify on hardware)` unless explicitly recorded as a reported result.
