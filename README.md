# POPSLoader

Last updated: 2026-03-26

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
| HDD (PFS) menu path | Implemented in code | Fix implemented for D-10; pending hardware verification |
| Disc (`DKWDRV`) menu path | Implemented in code | Unknown (verify on hardware) |
| Exit to OSDSYS | Implemented in code | Reported PASS |
| Exit to `BOOT.ELF` | Implemented in code | Current source needs re-test after last reverted regression |
| `HDD (exFAT)` | Not implemented | Not implemented |
| `SMB (v1)` | Not implemented | Not implemented |

### Current known unresolved issue

The main unresolved hardware issue was:
- HDD `POPSTARTER.ELF` on HDD sidecar/CWD (`D-10`)
  - repro reported so far:
    - boot POPSLoader from HDD,
    - launch an HDD title,
    - POPSTARTER also resolves from HDD sidecar/CWD or configured HDD path,
    - result: black-screen hang.
  - Investigation identified hardware exceptions occurring in the embedded loader (`loader.c`) due to the usage of `snprintf` and `printf` on uninitialized libc/newlib structures. A fix has been implemented to replace `snprintf` with safe string primitives (`strncpy`) and stub out `printf` to prevent crashes. This is pending hardware verification.

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
- boot-device label across all boot sources (`U-11`)

### Reported hardware outcomes that matter right now
- `U-05` OSDSYS exit:
  - reported fixed.
- `D-10` HDD POPSTARTER on HDD:
  - Fix implemented (removed uninitialized libc dependencies in embedded loader). Pending hardware verification.
  - previous status: reported failing.
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
