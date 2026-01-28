<a href=""><img width="1536" height="1024" alt="POPSLoader" src="https://github.com/user-attachments/assets/d7b54ca5-f088-4f82-8819-d8621a6b2fda" />
</a><br>
<a href="https://www.github.com/NathanNeurotic/Enceladus/releases">![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nathanneurotic/enceladus/total?style=plastic&logo=playstation%202&logoColor=red&logoSize=auto&label=Downloads&labelColor=gold&color=turquoise%20&link=https%3A%2F%2Fgithub.com%2FNathanNeurotic%2FEnceladus%2Freleases%2Ftag%2FMMCE)</a>

# POPSLoader

POPSLoader is an open-source launcher for POPStarter that is scripted in Lua and built on top of the Enceladus runtime. This repository packages the launcher (POPSLOADER.ELF), runtime Lua scripts, textures, and required modules into a single, portable bundle intended for PlayStation 2 environments such as MMCE and USB mass storage.

POPSLoader was created by [El_isra](https://www.github.com/israpps), and this repository is a fork of his work. Endless thanks to Isra for his contributions and open-source projects gifted to the community.

> **Project lineage**: This project is derived from the [Enceladus](https://github.com/DanielSant0s/Enceladus) Lua environment and retains its GPLv3 licensing.

## Documentation
- [AGENTS.md](AGENTS.md)
- [DEVELOPMENT.md](DEVELOPMENT.md)
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/RUNTIME_LAYOUT.md](docs/RUNTIME_LAYOUT.md)
- [docs/LAUNCH_PIPELINE.md](docs/LAUNCH_PIPELINE.md) (canonical launch behavior + device rules)
- [docs/DEBUGGING.md](docs/DEBUGGING.md)
- [docs/DOC_AUDIT.md](docs/DOC_AUDIT.md)

## Status / Roadmap
- No subfolder dependencies (assets load from ELF directory first).
- Legacy `POPSLDR/` layout kept as fallback.

## Usage
Place `POPSLOADER.ELF`, `POPSTARTER.ELF`, Lua scripts, images, and optional IRX modules in the same directory (no required subdirectories).  
- `system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`, `PATCH_5.BIN`  
- UI images (`*.png`) and optional external IRX modules (`*.irx`)  
Legacy folders (`POPSLDR/`, `IMG/`, `IRX/`) are fallback-only.  
Profiles can override the PopStarter path if needed.  
See [docs/RUNTIME_LAYOUT.md](docs/RUNTIME_LAYOUT.md) for layout details and compatibility notes.

## Launch behavior (canonical)
Launch behavior, device rules, and POPStarter handoff are documented in [docs/LAUNCH_PIPELINE.md](docs/LAUNCH_PIPELINE.md). This repo does **not** contain POPStarter’s argument parsing, so POPStarter’s argv index must be verified in POPStarter’s own sources or documentation.

### Device pages
- The SMB slot represents MMCE (no SMB networking support); `SMB.png` is reused as the icon.  
- MMCE auto-detects `mmce0:/` and `mmce1:/`, with module load order: `iomanX` → `fileXio` → `mmceman`.  
See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for implementation details.

### Controls
- Triangle: Exit to OSDSYS (with confirmation).

### Tips
- (USB Only) if you want POPStarter IGR to go back to POPSLoader automatically, copy `POPSLOADER.ELF` renamed as `BOOT.ELF` (legacy `POPSLDR/` layout is still supported if you use it)
- you can replace the POPStarter IGR textures with custom ones that looks like stock POPSLoader UI by pasting the `PATCH_5.BIN` found inside the `POPSLDR/` into the `POPS/` folder

## APP_DIR examples (expected)
These are derived from the startup path parsing logic and used for asset resolution order (APP_DIR first, legacy fallback second).  
- `mass:/POPSLOADER.ELF` → `APP_DIR = mass:/`  
- `mc0:/APPS/POPSLOADER.ELF` → `APP_DIR = mc0:/APPS/`  
- `mmce0:/APPS/POPSLOADER.ELF` → `APP_DIR = mmce0:/APPS/`  

## Thanks
- israpps (El_isra) for POPSLoader.
- Daniel Santos for Enceladus: https://github.com/DanielSant0s/Enceladus


# LICENSE
SInce this project is based on enceladus, it retains the **GNU General public license v3.0**
