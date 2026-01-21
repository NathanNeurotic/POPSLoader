# POPSLoader
An open source Launcher for POPStarter scripted in lua.

Based on [Enceladus](https://github.com/DanielSant0s/Enceladus)

## Usage
move the POPSLOADER.ELF and runtime assets into a USB device or internal HDD (flat layout)
  - system.lua, ui.lua, images.lua, pops_profiles.lua, PATCH_5.BIN
  - UI images (*.png) and optional external IRX modules (*.irx)
Legacy `POPSLDR/` folder layout is still supported as a fallback.

### Tips
- (USB Only) if you want POPStarter IGR to go back to POPSLoader automatically, copy the `POPSLOADER.ELF` renamed as `BOOT.ELF` (legacy `POPSLDR/` layout is still supported if you use it)
- you can replace the POPStarter IGR textures with custom ones that looks like stock POPSLoader UI by pasting the `PATCH_5.BIN` found inside the `POPSLDR/` into the `POPS/` folder


# LICENSE
SInce this project is based on enceladus, it retains the **GNU General public license v3.0**
