<a href=""><img width="1536" height="1024" alt="POPSLoader" src="https://github.com/user-attachments/assets/d7b54ca5-f088-4f82-8819-d8621a6b2fda" />
</a><br>
<a href="https://www.github.com/NathanNeurotic/Enceladus/releases">![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nathanneurotic/enceladus/total?style=plastic&logo=playstation%202&logoColor=red&logoSize=auto&label=Downloads&labelColor=gold&color=turquoise%20&link=https%3A%2F%2Fgithub.com%2FNathanNeurotic%2FEnceladus%2Freleases%2Ftag%2FMMCE)</a>

# POPSLoader

POPSLoader is an open-source launcher for POPStarter that is scripted in Lua and built on top of the Enceladus runtime. This repository packages the launcher (POPSLOADER.ELF), runtime Lua scripts, textures, and required modules into a single, portable bundle intended for PlayStation 2 environments such as MMCE and USB mass storage.

POPSLoader was created by [El_isra](https://www.github.com/israpps), and this repository is a fork of his work. Endless thanks to Isra for his contributions and open-source projects gifted to the community.

> **Project lineage**: This project is derived from the [Enceladus](https://github.com/DanielSant0s/Enceladus) Lua environment and retains its GPLv3 licensing.

## Installation & Usage

**Recommended Layout (Flat)**
Place `POPSLOADER.ELF`, `POPSTARTER.ELF`, and all runtime assets (scripts, images, IRX modules) in the **same directory** on your device (USB, MMCE, or HDD). No subfolders are required.

Example contents of your folder:
- `POPSLOADER.ELF`
- `POPSTARTER.ELF` (Rename your POPStarter binary to this)
- `system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`
- `PATCH_5.BIN` (Optional, for IGR texture replacement)
- `*.png` (UI images)
- `*.irx` (External modules)

*Legacy folders (`POPSLDR/`, `IMG/`, `IRX/`) are supported as a fallback but are not required.*

### Features
- **Broad Device Support**: USB Mass Storage, MMCE (multimedia card emulator), HDD (internal hard drive), and MX4SIO.
- **MMCE Support**: Native detection of `mmce0:/` and `mmce1:/`. The SMB slot in the UI is reused for MMCE.
- **Flat Architecture**: Simplifies installation by keeping everything in one folder.

### Controls
- **Triangle**: Exit to OSDSYS (with confirmation).
- **Cross/Circle**: Select/Confirm (depending on region settings).

### Tips
- **USB Users**: To have POPStarter IGR (In-Game Reset) return automatically to POPSLoader, rename `POPSLOADER.ELF` to `BOOT.ELF`.
- **Custom UI**: You can replace POPStarter IGR textures with POPSLoader-themed ones by placing `PATCH_5.BIN` (found in the release) into your `POPS/` folder.

## Documentation
For developers and advanced users:
- [AGENTS.md](AGENTS.md) - Agent guidance and repository map.
- [DEVELOPMENT.md](DEVELOPMENT.md) - Build instructions and developer notes.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - Internal architecture and flow.
- [docs/RUNTIME_LAYOUT.md](docs/RUNTIME_LAYOUT.md) - Detailed asset resolution rules.
- [docs/LAUNCH_PIPELINE.md](docs/LAUNCH_PIPELINE.md) - Canonical launch behavior and argument passing.

## Thanks
- israpps (El_isra) for POPSLoader.
- Daniel Santos for Enceladus: https://github.com/DanielSant0s/Enceladus

# LICENSE
Since this project is based on Enceladus, it retains the **GNU General Public License v3.0**.
