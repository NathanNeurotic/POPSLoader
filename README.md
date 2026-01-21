<a href="">!<img width="1536" height="1024" alt="POPSLOADER MMCE on Enceladus" src="https://github.com/user-attachments/assets/bc8ce695-17a6-445b-b09b-1d2b962f6b5d" /></a>
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

## Status / Roadmap
- No subfolder dependencies (assets load from ELF directory first).
- Legacy `POPSLDR/` layout kept as fallback.
- Treat mmce as USB (XX.) for POPSTARTER.

## Usage
Put `POPSLOADER.ELF` and runtime assets in the same folder (no subfolder required):  
- `system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`, `PATCH_5.BIN`  
- UI images (`*.png`) and optional external IRX modules (`*.irx`)  
Legacy `POPSLDR/` folder layout is still supported as a fallback.  
See [docs/RUNTIME_LAYOUT.md](docs/RUNTIME_LAYOUT.md) for layout details and compatibility notes.

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
