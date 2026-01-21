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
**Current layout** (see [docs/RUNTIME_LAYOUT.md](docs/RUNTIME_LAYOUT.md) for the upcoming layout change).
move the POPSLOADER.ELF and the `POPSLDR/` folder into a USB device or internal HDD

### Tips
- (USB Only) if you want POPStarter IGR to go back to POPSLoader automatically, pasthe the `POPSLDR/` folder into the USB root, and copy the `POPSLOADER.ELF` renamed as `BOOT.ELF`
- you can replace the POPStarter IGR textures with custom ones that looks like stock POPSLoader UI by pasting the `PATCH_5.BIN` found inside the `POPSLDR/` into the `POPS/` folder


# LICENSE
SInce this project is based on enceladus, it retains the **GNU General public license v3.0**
