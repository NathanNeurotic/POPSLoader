# POPSLoader

Last updated: 2026-03-27

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
  title.cfg
  icon.sys
  list.icn
  copy.icn
  del.icn
POPS/
  PATCH_5.BIN
```

That package contract is enforced by `.github/workflows/compilation.yml`.

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
| Exit to `BOOT.ELF` | Implemented in code | Current source needs re-test after last reverted regression |
| `HDD (exFAT)` | Not implemented | Not implemented |
| `SMB (v1)` | Not implemented | Not implemented |

### Current known unresolved issues

Reported hardware issues currently being tracked are:
- HDD-backed `POPSTARTER.ELF` handoff (`D-10`, `D-14`)
  - 2026-03-27 hardware re-test still black-screened with boot source HDD, default/Profile 1/cwd/sidecar `POPSTARTER.ELF` on HDD, and game device HDD.
  - 2026-03-27 hardware also black-screened when launching a USB game with Profile 2 pointing `POPSTARTER.ELF` to HDD, so the reported failure scope is broader than HDD game routing alone.
  - current source still exposes an HDD-list alternate launch on `R2` for HDD-resident `POPSTARTER.ELF`, changing only the selector contract to `hdd0:PART:pfs0:/GAME.ELF` for A/B testing.
  - several later HDD launch-path experiments in `bin/POPSLDR/system.lua` did not fix these failures and coincided with a `D-15` regression.
  - user later confirmed on 2026-03-28 that the narrowed source restored `D-15`, so the remaining blocker is again isolated to HDD-backed `POPSTARTER.ELF`.
  - current source now keeps the confirmed HDD startup auto-init and USB first-entry fixes, and strips the remaining Lua-side HDD game prep from HDD-backed `POPSTARTER.ELF` launches as well: no `EnsureHDDReadyForLaunch()`, no extra HDD slot keep request, and no forced launch CWD.
  - hardware result on this corrected current source is still `Unknown (verify on hardware)`.
- HDD game with non-HDD POPSTARTER (`D-15`)
  - this path had regressed on several 2026-03-27 and early 2026-03-28 experimental sources.
  - current source now removes Lua-side HDD game pre-mount/CWD preservation from this path and leaves only the normal selector handoff unless `POPSTARTER.ELF` itself is HDD/PFS-backed.
  - user later confirmed on 2026-03-28 that USB boot + USB Profile 1 sidecar/cwd `POPSTARTER.ELF` + HDD game now passes on hardware.

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

### Implemented but still needing hardware proof
- PAL/NTSC menu asset proportions (`U-06`)
- startup backend auto-init across all boot/configured path combinations (`D-12`)
  - current source includes a 2026-03-27 HDD-target correction so HDD boot/configured paths initialize the full HDD stack at startup.
- first-entry USB backend discovery (`D-16`)
  - current source includes a bounded retry wait in USB root discovery so the first page entry does not require backing out and re-entering.
- boot-device label across all boot sources (`U-11`)

### Reported hardware outcomes that matter right now
- `U-05` OSDSYS exit:
  - reported fixed.
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
  - reported failing.
  - 2026-03-27 re-test of the current source still failed with boot source HDD, POPSTARTER on HDD via default/Profile 1/cwd/sidecar, and game device HDD.
  - later 2026-03-27 experimental sources also black-screened after direct-load, Memory Card staging, and stripped-handoff changes.
  - user later confirmed on 2026-03-28 that the narrowed source restored `D-15`, so this remaining blocker is again isolated to HDD-backed `POPSTARTER.ELF`.
  - current source now strips the remaining Lua-side HDD game prep from HDD-backed `POPSTARTER.ELF` launches as well: no `EnsureHDDReadyForLaunch()`, no extra HDD slot keep request, and no forced launch CWD.
  - hardware result on this corrected current source is still `Unknown (verify on hardware)`.
- `D-14` HDD-backed POPSTARTER with non-HDD game:
  - reported failing.
  - 2026-03-27 user hardware also black-screened when launching a USB game with Profile 2 pointing `POPSTARTER.ELF` to HDD.
  - current source now uses the same stripped HDD-backed handoff as `D-10`: no `EnsureHDDReadyForLaunch()`, no extra HDD slot keep request, and no forced launch CWD.
  - hardware result on this corrected current source is still `Unknown (verify on hardware)`.
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
  - a later failed experiment regressed it,
  - current source has been restored away from that experiment,
  - current hardware status still needs re-test.

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
