# POPSLoader
An open source Launcher for POPStarter scripted in lua.

Based on [Enceladus](https://github.com/DanielSant0s/Enceladus)

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
