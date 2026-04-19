# POPSLoader

Last updated: 2026-04-02

POPSLoader is a PlayStation 2 launcher for POPStarter, built on Enceladus runtime components and driven primarily by embedded Lua scripts.

This repository contains:
- the launcher (`POPSLOADER.ELF`),
- embedded runtime Lua and asset data,
- embedded IOP modules,
- the POPStarter packaging payload used by CI,
- documentation for current code state and validation status.

## What This Repository Builds

The CI workflow packages an exact ZIP layout:

```text
PS1_POPSLOADER/
  POPSLOADER.ELF
  POPSTARTER.ELF
  APPINFO.PBT
  BUILD_INFO.txt
  title.cfg
  icon.sys
  list.icn
  copy.icn
  del.icn
POPS/
  PATCH_5.BIN
```

That package contract is enforced by `.github/workflows/compilation.yml`.
Current CI also verifies that the built `enceladus.elf` still contains the expected embedded Lua runtime markers, and it now asserts embedded-loader rebuild propagation by touching `src/elf_loader/src/loader/src/loader.c`, running a clean rebuild, and requiring regenerated timestamps across `loader.elf` -> generated blob -> `libcustom-elf-loader.a` -> `enceladus.elf` -> `POPSLOADER.ELF`.

## Current Status At A Glance

### Repo status vs reported hardware status

| Area | Repository status | Reported hardware status |
|---|---|---|
| MMCE menu path | Implemented in code | Unknown (verify on hardware) |
| MX4SIO menu path | Implemented in code | Unknown (verify on hardware) |
| USB menu path | Implemented in code | Unknown (verify on hardware) |
| HDD (PFS) menu path | Implemented in code | Mixed; HDD POPSTARTER-on-HDD handoff still failing |
| Disc (`DKWDRV`) menu path | Implemented in code | Unknown (verify on hardware) |
| Exit to OSDSYS | Implemented in code | Reported PASS |
| Exit to `BOOT.ELF` | Implemented in code | Mixed; reached on hardware, but later reports said it misbehaved after HDD runtime init |
| `HDD (exFAT)` | Not implemented | Not implemented |
| `SMB (v1)` | Not implemented | Not implemented |

### Current known unresolved issues

Reported hardware issues currently being tracked are:
- HDD-backed `POPSTARTER.ELF` handoff (`D-10`, `D-14`)
  - latest recorded hardware outcomes still fail when `POPSTARTER.ELF` itself is HDD-backed.
  - `D-15` passing again isolates the remaining blocker to HDD-backed POPSTARTER execution, not HDD games in general.
  - one 2026-03-29 artifact briefly moved `D-10` from a black screen to `rc=-1 (returned after 22618 ms)`, but later artifacts returned to a black screen, so that boundary was not stable.
  - current repo line keeps the partition-aware HDD reboot contract, separate exec-path reporting, profile-path normalization, and a no-reset-first child-loader handoff for partition-aware HDD POPSTARTER loads.
  - a later hardware re-test on that child-remount/cold-parent line still black-screened.
  - the later stripped direct-HDD-ELF line moved `D-10` back to a returned `rc=-1`, but the popup also showed the launcher was still probing/opening `pfs3:/.../POPSTARTER.ELF` while separately trying to exec a rewritten `pfs:/.../POPSTARTER.ELF`.
  - current repo line now removes the stale exec-path rewrite from the stripped HDD-backed POPSTARTER experiment so probe/open and exec both use the same resolved HDD ELF path, retries that stripped HDD ELF attempt through `reboot_iop = 1`, and still lets the reboot path enter the HDD embedded loader.
  - repo comparison then exposed a larger drift in that stripped line: with `exec_partition_context = nil`, the child loader falls into the newer `fileXio` direct-load shortcut for `pfsN:/...` and skips the older partition-aware remount path.
  - current repo line now restores partition context only as loader metadata for HDD-backed POPSTARTER so the child uses the partition-aware remount path again, while still keeping no launch CWD and the same visible resolved exec path.
  - audit also found a Lua binding bug in `src/luasystem.cpp`: the trailing reboot partition context was only parsed when `System.loadELF(...)` received at least four Lua arguments, so the new HDD path could not actually deliver loader-only partition metadata in the three-argument reboot form. Current source now accepts that trailing partition context with three arguments as well.
  - audit then found one more regression in the exact HDD child-loader path now in use: older child-loader source reloaded `SIO2MAN`, `MCMAN`, and `MCSERV` after HDD `SifIopReset("")`, while later `HEAD` had drifted to jump straight to `ExecPS2`. Current source keeps the no-reset-first route, but now does a bounded child-loader fallback aligned to the `wLaunchELF` `pfs0:` pattern: mount `pfs0:`, try mounted-path fileXio segment load first, and fall back to mounted-path `SifLoadElf` if that copy fails; handoff remains `SifExitRpc`/`ExecPS2` with no child-side post-load reset/module-reload stage. Hardware on this exact line is still `Unknown (verify on hardware)`.
  - current source implements explicit `fileXioUmount("pfs0:")` and bypasses `SifExitRpc` right before ExecPS2, fixing the exact documented state issues for HDD-backed POPSTARTER. Hardware status is `Unknown (verify on hardware)`.
  - audit then found another remaining carry-over in parent-side launch prep: `PrepareForExternalELFLaunch(...)` still auto-kept the mounted `pfsN` slot whenever the exec path itself was on `pfsN:/...`. Current source now suppresses that implicit exec-slot keep specifically for HDD-backed POPSTARTER, so the stripped line no longer preserves the mounted parent slot just because the executable was resolved there.
  - the latest hardware re-test on that stripped selectorless line still black-screened, and the only recorded move away from a black screen happened before the selector was stripped. Current source therefore restores selector-only `argv[0]` for HDD-backed POPSTARTER while still avoiding slot/CWD preservation and keeping partition context only as loader metadata.
  - clarification: POPSTARTER itself is not believed to require slot preservation, launch CWD, partition context, or carried runtime state after exec. Current source again gives POPSTARTER only its selector in `argv[0]`; the loader still keeps partition metadata only so the HDD ELF can be loaded cleanly.
  - detailed per-artifact experiment chronology lives in `QA_REGRESSION_MATRIX.md` and `DECISIONS.md`.
- HDD game with non-HDD POPSTARTER (`D-15`)
  - user later confirmed on 2026-03-28 that USB boot + USB Profile 1 sidecar/cwd `POPSTARTER.ELF` + HDD game now passes on hardware.
- `BOOT.ELF` after HDD runtime (`U-10`)
  - BOOT.ELF is reached, but later reported hardware said it could still misbehave after HDD runtime had already been initialized.
  - current working inference is that `U-10` may share the same underlying handoff/state-poisoning boundary as `D-10`, but that is not yet proven and must not be treated as an automatic fix dependency.
  - the later BOOT.ELF cold-prep/no-forced-reboot line still froze after HDD page use on hardware, and the later restored-standard-prep/no-forced-reboot line also still froze.
  - current source therefore keeps the no-launch-CWD rollback, keeps standard external-launch prep, retries `reboot_iop = 1` for BOOT.ELF after HDD init, and now restores the generic reboot path in `src/elf_loader/src/elf.c` to the repo's older embedded-loader handoff style after the post-reset cleanup/module-reload contract from `src/system.cpp`; hardware on that exact line is still `Unknown (verify on hardware)`.

## Runtime Behavior (Current Code)

### Boot/runtime model
- Boot/runtime Lua is embedded into the ELF.
- Required runtime modules are:
  - `boot.lua`
  - `system.lua`
  - `ui.lua`
  - `images.lua`
  - `pops_profiles.lua`
- Filesystem Lua loaders are disabled at runtime.

### Settings behavior
- Settings are persisted at `mc0:/POPSTARTER/.pldrs`.
- Settings edits are staged in UI first, then committed on confirm/leave.
- Current persisted settings include:
  - POPSTARTER path,
  - DKWDRV path,
  - video standard,
  - hide-text mode,
  - keyboard layout,
  - BDMA mode.

### Startup backend behavior
- Startup backend auto-init is implemented.
- The launcher now decides which backends to initialize from:
  - boot path / argv0,
  - current app directory,
  - configured POPSTARTER path,
  - configured DKWDRV path,
  - selected profile path.
- When HDD is a startup target, auto-init now runs the same `PLDR.LoadHDDModules()` path used by the HDD page instead of only the lower-level exec helper.
- USB vs MX4SIO identity is determined from the mount-driver name, not from the path text.

### Device access behavior
- The old runtime device-lock gate is no longer active.
- Opening one backend page does not intentionally block opening another backend page through a session lock.

### Cover art behavior
- Standard cover lookup uses a sidecar PNG next to the selected `.VCD`.
- HDD entries can also load cover art from:
  - `hdd0:__common/POPS/ART/<title>.png`

### Path editor / keyboard behavior
- The on-screen keyboard supports:
  - `ABC`
  - `QWERTY`
  - `DVORAK`
- Keyboard layout is persisted in settings.
- The editor includes:
  - visible cursor movement,
  - backspace/delete support,
  - save/done behavior,
  - button-bar help specific to keyboard mode.

### Exit / external launch behavior
- Exit modal offers:
  - `OSDSYS`
  - `Cancel`
  - `BOOT.ELF`
- `BOOT.ELF` resolution order is:
  - `mc0:/BOOT/BOOT.ELF`
  - `mc1:/BOOT/BOOT.ELF`
- External launch prep uses tracked HDD/PFS unmount logic before handoff.

## Installation Notes

### Basic installation
1. Obtain a current `POPSLOADER.zip` build.
2. Extract it without changing the directory structure.
3. Copy:
   - `PS1_POPSLOADER/` to the device/location you want to boot from,
   - `POPS/` to the backend location expected by your chosen setup.
4. Place PS1 `.VCD` files in the backend `POPS/` location you actually intend to browse from.

### Cover art
- Sidecar cover rule:
  - `GAME.VCD` -> `GAME.png`
- HDD common art rule:
  - `hdd0:__common/POPS/ART/GAME.png`

### HDD (PFS) notes
- HDD scan code currently looks for POPS game partitions in the configured POPS partition set (`__.POPS`, `__.POPS1` ...).
- HDD dependency checks look for runtime files under `hdd0:__common/POPS/`.

## Build From Source

### Recommended environment
Use the same environment as CI:

```sh
make clean elfloader all
```

The workflow uses the `ps2dev/ps2dev` container and validates packaging after build.

### Local build prerequisites
- PS2 toolchain environment (`PS2DEV`, `PS2SDK`, gsKit/ports libs)
- `ps2-packer`
- `make`
- standard build tools

### Build outputs
- `bin/enceladus.elf`
- `bin/POPSLOADER.ELF`
- `POPSLOADER.zip` in CI packaging flow

## Known Limitations And Open Validation

### Not implemented
- `HDD (exFAT)` menu flow
- `SMB (v1)` menu flow

### Implemented but still needing current-source hardware proof
- PAL/NTSC menu asset proportions (`U-06`)
- `BOOT.ELF` after HDD page init (`U-10`)
- boot-device label across all boot sources (`U-11`)

### Reported hardware outcomes that matter right now
- `U-05` OSDSYS exit:
  - reported fixed.
- `D-12` startup backend auto-init:
  - a 2026-03-27 hardware report said booting from HDD did not auto-init the HDD driver stack.
  - current source now routes HDD startup targets through `PLDR.LoadHDDModules()` instead of only `EnsureHddRuntimeReadyForExec()`.
  - current source also keeps startup HDD init limited to runtime readiness; it no longer scans HDD POPS partitions or builds the HDD game list during boot.
  - the HDD page still scans partitions and builds the games list on page entry, and if HDD cache is enabled it now writes that cache from the page-built list instead of rebuilding during startup.
  - user previously confirmed the earlier HDD startup auto-init correction on hardware, but later 2026-03-28 reports on the narrowed boot-time split sources said HDD-backed startup/Profile POPSTARTER could still not be found after entering the USB page before the HDD page.
  - the raw boot `APP_DIR` fallback alone did not restore that case.
  - current source now also pre-resolves any HDD-backed startup/configured exec paths immediately after `PLDR.LoadHDDModules()` so HDD POPSTARTER/Profile paths are mounted and recorded without reintroducing HDD page work at boot.
  - current source also routes on-demand HDD path mounts through `PLDR.LoadHDDModules()` instead of only the lower-level `EnsureHddRuntimeReadyForExec()` gate, so HDD POPSTARTER/Profile probes from USB or other pages use the same runtime init path as HDD page entry.
  - current source also fixes the startup warm-path classification for Profile 1/default relative `POPSTARTER.ELF`, which had previously been skipped because only explicit `hdd:` / `pfs:` paths were being marked for HDD warm-up.
  - because `etc/boot.lua` establishes HDD boot on a dedicated `pfs1:` mount before `system.lua` runs, current source now also carries that exact boot partition/slot metadata into `system.lua`, seeds the HDD mount tracker from it, and rebuilds HDD sidecar/partition context from mounted `pfs1:` candidates instead of relying only on later rediscovery.
  - user later confirmed on 2026-03-28 that the exact-boot-mount/source-context source restored the USB-before-HDD-page Profile 1 lookup repro on hardware.
  - latest recorded hardware on this line is therefore `PASS`; preserve that behavior through further `D-10` work.
- `D-16` first-entry USB backend discovery:
  - a 2026-03-27 hardware report said the first USB page entry reported no backend, but backing out and re-entering then worked.
  - current source now adds a bounded wait between failed USB root probes in `BuildUsbIdentityDeferred()`.
  - MX4SIO discovery code was not changed by this correction.
  - user later confirmed that corrected source fixed the first-entry USB issue on hardware.
- `D-10` HDD POPSTARTER on HDD:
  - reported failing.
  - latest recorded hardware outcomes still fail when `POPSTARTER.ELF` itself is HDD-backed.
  - `D-15` passing again isolates the remaining blocker to HDD-backed POPSTARTER execution.
  - one 2026-03-29 artifact briefly returned `rc=-1 (returned after 22618 ms)` instead of black-screening, but later artifacts returned to black screen, so that boundary is not treated as the stable current state.
  - current repo line keeps the partition-aware reboot contract, separate exec-path reporting, profile-path normalization, and a no-reset-first child-loader handoff for partition-aware HDD POPSTARTER loads.
  - latest user hardware report from the 2026-04-02 GitHub artifact (`cd76569`) still black-screened.
  - current source now keeps no-reset handoff but changes the partition-aware child-loader load order to match the bounded reference pattern: mount `pfs0:`, try mounted-path fileXio segment copy first, then fall back to mounted-path `SifLoadElf` if needed; exact-line hardware status is `Unknown (verify on hardware)`.
  - a later hardware re-test on that child-remount/cold-parent line still black-screened.
  - the later stripped direct-HDD-ELF line moved `D-10` back to a returned `rc=-1`, but the popup also showed the launcher was still probing/opening `pfs3:/.../POPSTARTER.ELF` while separately trying to exec a rewritten `pfs:/.../POPSTARTER.ELF`.
  - current repo line now removes that stale exec-path rewrite from the stripped HDD-backed POPSTARTER experiment, keeps the reboot/embedded-loader path plus loader-only partition metadata, and restores selector-only `argv[0]` because the selectorless stripped line still black-screened while the only recorded non-black-screen boundary preceded the strip.
  - clarification: POPSTARTER itself is not believed to require slot preservation, launch CWD, partition context, or carried runtime state after exec; current source again passes only the selector in `argv[0]` while keeping the loader-side state prep minimal.
  - see `QA_REGRESSION_MATRIX.md` and `DECISIONS.md` for the detailed experiment chronology.
- `D-14` HDD-backed POPSTARTER with non-HDD game:
  - reported failing.
  - 2026-03-27 user hardware also black-screened when launching a USB game with Profile 2 pointing `POPSTARTER.ELF` to HDD.
  - later recorded hardware still failed when `POPSTARTER.ELF` itself was on HDD, confirming the broader blocker is HDD-backed POPSTARTER execution rather than HDD game routing alone.
  - current repo line uses the same partition-aware HDD reboot contract as `D-10`, including no-reset child handoff with mounted-path fileXio-first and mounted-path `SifLoadElf` fallback; a current-line hardware re-test is still `Unknown (verify on hardware)`.
- `D-15` HDD game with non-HDD sidecar POPSTARTER:
  - a later 2026-03-27 hardware report said booting from another device and launching an HDD game with sidecar `POPSTARTER.ELF` on that boot device also black-screened.
  - that was reported as a regression on the EE-side HDD direct-load attempt, which has now been reverted in source.
  - a later 2026-03-27 hardware report said the broader stripped-handoff HDD-game path also black-screened.
  - current source now removes Lua-side HDD game pre-mount/CWD preservation from this path and leaves only the normal selector handoff unless `POPSTARTER.ELF` itself is HDD/PFS-backed.
  - user later confirmed on 2026-03-28 that USB boot + USB sidecar/cwd `POPSTARTER.ELF` + HDD game passes on hardware.
- Shared default/Profile 1 local POPSTARTER baseline:
  - reported failing with `Cant find POPSTARTER ELF` on 2026-03-27 when booted from USB with USB sidecar/cwd/Profile 1.
  - current source was rolled back to `BETA-10-play-CHECKPOINT2` shared resolver behavior for this path after the later unverified common-path changes failed to restore launch.
  - user confirmed that rolled-back source fixed the baseline on hardware.
- `U-10` BOOT.ELF after HDD page init:
  - one prior artifact was reported good,
  - repo history shows the BOOT.ELF modal later changed from its older non-reboot direct `System.loadELF(elf_path, 0, elf_path)` path to a reboot-I/O path with launch-CWD setup.
  - a later 2026-03-29 hardware report said BOOT.ELF still behaved incorrectly once HDD had been initialized, which points more specifically at carried HDD runtime state than BOOT.ELF lookup.
  - current working inference is that `U-10` may share the same underlying handoff/state-poisoning boundary as `D-10`, but that is not yet proven and `U-10` still requires its own hardware re-check after any `D-10` change.
  - a later 2026-03-29 hardware report on that cold-prep/no-forced-reboot line still froze on `HDD boot -> default/Profile 1 sidecar/cwd POPSTARTER on HDD -> enter HDD page -> Exit -> BOOT.ELF`.
  - a later 2026-03-29 hardware report said the restored-standard-prep/no-forced-reboot line still froze as well.
  - current source therefore keeps the no-launch-CWD rollback, keeps standard external-launch prep, retries `reboot_iop = 1` for BOOT.ELF after HDD init, and now restores the generic reboot path in `src/elf_loader/src/elf.c` to the repo's older embedded-loader handoff style after the post-reset cleanup/module-reload contract from `src/system.cpp`.
  - current-source hardware status is still `Unknown (verify on hardware)`.

## Documentation Map

If you need details instead of a summary:
- `STATE.md`: current repo and hardware status in plain language
- `QA_REGRESSION_MATRIX.md`: test matrix and current reported validation status
- `ARCHITECTURE.md`: runtime/data-flow overview
- `COMPONENTS.md`: ownership map by file/component
- `DECISIONS.md`: explicit project decisions and open investigations
- `ROADMAP.md`: active priorities and deferred work
- `RULES.md`: hard constraints for changes
- `TRUTHSHEET.md`: invariants that should not drift silently

## Project Lineage
- Original POPSLoader lineage by [El_isra / israpps](https://github.com/israpps).
- Derived from [Enceladus](https://github.com/DanielSant0s/Enceladus) by [DanielSant0s](https://github.com/DanielSant0s/).

## Credits
- [israpps (El_isra)](https://israpps.github.io/) for POPSLoader.
- [Daniel Santos](https://github.com/DanielSant0s/Enceladus) for Enceladus.
- [Berion](https://www.psx-place.com/members/berion.1431/) for graphics/design work.
- [nuno6573](https://github.com/nuno6573/) for cover-art related work.
- [Hugopocked](https://ko-fi.com/hugopocked) for POPStarter fixes.
- [Ripto / NathanNeurotic](https://github.com/NathanNeurotic) for continuation and release work.

## License
This project retains the GNU General Public License v3.0.
