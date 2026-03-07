<a href=""><img width="1536" height="1024" alt="POPSLoader" src="https://github.com/user-attachments/assets/d7b54ca5-f088-4f82-8819-d8621a6b2fda" />
</a><br>
<a href="https://www.github.com/NathanNeurotic/Enceladus/releases">![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nathanneurotic/enceladus/total?style=plastic&logo=playstation%202&logoColor=red&logoSize=auto&label=Downloads&labelColor=gold&color=turquoise%20&link=https%3A%2F%2Fgithub.com%2FNathanNeurotic%2FEnceladus%2Freleases%2Ftag%2FMMCE)</a>

# POPSLoader

Last updated: 2026-03-07

POPSLoader is an open-source PlayStation 2 launcher for POPStarter, built on Enceladus runtime components with a Lua-driven UI/runtime flow.
This repository contains the launcher (`POPSLOADER.ELF`), runtime Lua scripts, embedded assets, and required modules for PlayStation 2 environments.

## Project Lineage
- [POPSLoader](https://github.com/israpps/Enceladus/tree/popstarter) was created by [El_isra](https://github.com/israpps), and this repository is a forked continuation of that work.
- Derived from [Enceladus](https://github.com/DanielSant0s/Enceladus) by [DanielSant0s](https://github.com/DanielSant0s/).
- Maintains GPLv3 licensing lineage.

## What This Project Is
- A packaged PS2 launcher (`POPSLOADER.ELF`) for browsing and launching PS1 `.VCD` titles.
- A runtime composed of embedded Lua scripts/assets and embedded IOP modules.
- A build + CI pipeline that verifies release package contents strictly.

## Current Feature Status

| Main menu option | Status |
|---|---|
| MMCE | Implemented |
| MX4SIO | Implemented |
| HDD (PFS) | Implemented |
| USB | Implemented |
| Disc (DKWDRV) | Implemented |
| HDD (exFAT) | Not implemented |
| SMB (v1) | Not implemented |

## Runtime Behavior (Current)
- Boot/runtime Lua is loaded from embedded assets.
- Settings are staged in UI and committed on Settings/Profile confirm/leave.
- Settings file path: `mc0:/POPSTARTER/.pldrs`.
- Configurable executable paths:
  - POPStarter path
  - DKWDRV path
- `mc?:/` alias is supported for executable path resolution (`mc0:/` then `mc1:/`).
- USB vs MX4SIO list split is based on mount-driver identity (`System.getMassMountDriver`), not path-name guessing.
- Cover sidecar lookup uses selected `.VCD` path with `.png` suffix.

## Release Package Contract
Current release ZIP layout is:

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

Legacy `POPS/*.tm2` payload entries are intentionally excluded.

## Installation (Prebuilt)
1. Download the latest `POPSLOADER.zip` release.
2. Extract and keep the directory layout exactly as packaged (`PS1_POPSLOADER/` and `POPS/`).
3. Copy both directories to your target storage root.
4. Put your PS1 `.VCD` files into the active backend `POPS/` location.
5. Launch `PS1_POPSLOADER/POPSLOADER.ELF` from your preferred loader.

Notes:
- Exact launcher path conventions can vary by setup (for example OPL and FMCB workflows).

## Supported Devices and Backends
- MMCE (`mmce0:/`, `mmce1:/`): supported.
- MX4SIO: supported (detected via mass mount driver classification).
- USB mass (`mass:/`, `mass1:/...`): supported.
- Internal HDD (`hdd0:`, `pfs:`): supported (PFS path implemented).
- SMB menu entry: currently marked `Not Implemented Yet` in UI.
- Disc (DKWDRV) flow: implemented via menu modal and launch path check.

## Build From Source

### Recommended (CI-like)
Use `ps2dev/ps2dev` and run:

```sh
make clean elfloader all
```

### Local build prerequisites
- PS2 toolchain environment (`PS2DEV`, `PS2SDK`, gsKit/ports libs).
- `ps2-packer`, `make`, and standard build tools.

### Build outputs
- `bin/enceladus.elf` (intermediate)
- `bin/POPSLOADER.ELF` (packed launcher)

## Project Structure
- `src/`: EE runtime, Lua bindings, rendering/audio/input, launch plumbing.
- `bin/POPSLDR/`: runtime Lua scripts, bundled assets, POPStarter payload files.
- `iop/`: embedded IOP modules and `bdm_query` RPC module source.
- `modules/`: controller-related modules (`ds34bt`, `ds34usb`, `pademu`).
- `EMBED/`: resources embedded into the ELF at build time.
- `etc/`: boot script and helper scripts.
- `QA_REGRESSION_MATRIX.md`: hardware validation checklist and pass/fail matrix.
- `.github/workflows/compilation.yml`: CI build and packaging pipeline.

## How POPSLoader Works
1. `POPSLOADER.ELF` boots and initializes runtime/IOP services.
2. `etc/boot.lua` handles startup path setup, initializes fonts, then loads `system.lua`.
3. `bin/POPSLDR/system.lua` resolves assets, backend state, settings, and launch policy.
4. `bin/POPSLDR/ui.lua` renders scenes and dispatches device-specific game list loading.
5. Mass storage roots are classified by mount driver (USB vs MX4SIO) before list construction.
6. Launch requests resolve POPStarter path/device mode and then transfer execution.

## Known Limitations
- `HDD (exFAT)` and `SMB (v1)` menu entries are placeholders and currently return `Not Implemented Yet`.
- Hardware matrix coverage depends on manual validation runs.

## Credits
- [israpps (El_isra)](https://israpps.github.io/) for POPSLoader.
- [Daniel Santos](https://github.com/DanielSant0s/Enceladus) for Enceladus.
- [Berion](https://www.psx-place.com/members/berion.1431/) for graphics and design.
- [nuno6573](https://github.com/nuno6573/) for Cover Art System and supporting scripts.
- [Ripto / NathanNeurotic](https://github.com/NathanNeurotic) for project continuation, release work, and AI-assisted development persistence.
- [Hugopocked](https://ko-fi.com/hugopocked) for POPStarter fixes.
- [R3Z3N](https://github.com/saildot4k/) for [ps2store.com](https://www.ps2store.com/).
- [Codex](https://chatgpt.com/codex) for making this level of iteration possible.

## Extra Thanks To The Testers
- `@VizoR`
- `@bigol`
- `@nuno6573`
- `@P4NCHOL1NO`
- `@rorcarrot`
- `@UNDEAD`
- `@Berion`
- `@R3Z3N` (`ps2store.com`)
- `@Kamo`
- If I forgot to list you, please contact me.

## License
This project retains the **GNU General Public License v3.0**.
