<a href=""><img width="1536" height="1024" alt="POPSLoader" src="https://github.com/user-attachments/assets/d7b54ca5-f088-4f82-8819-d8621a6b2fda" />
</a><br>
<a href="https://www.github.com/NathanNeurotic/Enceladus/releases">![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nathanneurotic/enceladus/total?style=plastic&logo=playstation%202&logoColor=red&logoSize=auto&label=Downloads&labelColor=gold&color=turquoise%20&link=https%3A%2F%2Fgithub.com%2FNathanNeurotic%2FEnceladus%2Freleases%2Ftag%2FMMCE)</a>

# POPSLoader

Last updated: 2026-03-05

POPSLoader is an open-source launcher for POPStarter scripted in Lua and built on top of the Enceladus runtime. This repository contains the launcher (`POPSLOADER.ELF`), runtime Lua scripts, embedded assets, and required modules for PlayStation 2 environments.

POPSLoader was created by [El_isra](https://www.github.com/israpps), and this repository is a fork of his work.

## Project Lineage
- Derived from [Enceladus](https://github.com/DanielSant0s/Enceladus).
- Keeps GPLv3 licensing lineage.

## Installation

### Prebuilt package
1. Download the latest release archive (`POPSLOADER.zip`) from the Releases page.
2. Extract and keep the packaged directory layout intact:
   - `PS1_POPSLOADER/`
   - `POPS/`
3. Copy both directories to the target storage root used by your PS2 setup.
4. Add your PS1 `.VCD` files under the selected device's `POPS/` directory.
5. Launch `POPSLOADER.ELF` with your preferred ELF launcher.

### Notes
- The CI release package expects `POPS/PATCH_5.BIN` and `PS1_POPSLOADER/POPSTARTER.ELF` to be present.
- TODO: Document exact per-launcher folder path expectations (OPL / FMCB variants).

## Supported Devices and Backends
- MMCE (`mmce0:/`, `mmce1:/`): supported.
- MX4SIO: supported (detected via mass mount driver classification).
- USB mass (`mass:/`, `mass1:/...`): supported.
- Internal HDD (`hdd0:`, `pfs:`): supported paths exist in code.
- SMB menu entry: currently marked `Not Implemented Yet` in UI.
- Disc (DKWDRV) flow: entry exists; TODO: document full validated workflow.

## Project Structure
- `src/`: EE runtime, Lua bindings, rendering/audio/input, launch plumbing.
- `bin/POPSLDR/`: runtime Lua scripts, bundled assets, POPStarter payload files.
- `iop/`: embedded IOP modules and `bdm_query` RPC module source.
- `modules/`: controller-related modules (`ds34bt`, `ds34usb`, `pademu`).
- `EMBED/`: images/fonts embedded into the ELF at build time.
- `etc/`: boot script and helper scripts.
- `.github/workflows/compilation.yml`: CI build and packaging pipeline.

## Build Instructions

### Recommended (same environment as CI)
Use the `ps2dev/ps2dev` container and run:

```sh
make clean elfloader all
```

### Local build prerequisites
- PS2 toolchain environment (`PS2DEV`, `PS2SDK`, gsKit/ports libs) installed.
- `ps2-packer`, `make`, and standard build tools available.

### Build outputs
- `bin/enceladus.elf` (intermediate)
- `bin/POPSLOADER.ELF` (packed launcher)

## How POPSLoader Works
1. `POPSLOADER.ELF` boots and initializes runtime/IOP services.
2. `etc/boot.lua` handles startup path setup, initializes fonts, then loads `system.lua`.
3. `bin/POPSLDR/system.lua` resolves assets, backend state, and launch policies.
4. `bin/POPSLDR/ui.lua` renders scenes and dispatches device-specific game list loading.
5. Mass storage roots are classified by mount driver (USB vs MX4SIO) before list construction.
6. Launch requests resolve POPStarter path/device mode and then transfer execution.

## Credits
- [israpps (El_isra)](https://www.github.com/israpps) for POPSLoader.
- [Daniel Santos](https://github.com/DanielSant0s/Enceladus) for Enceladus.

## License
This project retains the **GNU General Public License v3.0**.
