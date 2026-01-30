# Runtime layout (single source of truth)

This document describes how POPSLoader resolves runtime assets **today**, based on the current codebase. It is the authoritative layout reference; other docs should defer to this file.

## Flat layout (recommended)
Place these files **next to** `POPSLOADER.ELF` in the same directory (no required subfolders):
- `POPSLOADER.ELF`
- `POPSTARTER.ELF`
- Lua scripts (e.g., `system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`)
- UI images (`*.png`)
- External modules (`*.irx`)
- Profiles/configs if stored as external files

Legacy subfolders (`POPSLDR/`, `IMG/`, `IRX/`) are **fallback only** and should not be required for a correct install.

## Search order (explicit)
### Lua scripts and modules
`etc/boot.lua` sets the Lua search path so that assets are resolved in this order:
1. `APP_DIR/?.lua`
2. `APP_DIR/POPSLDR/?.lua` (legacy fallback)
3. `./?.lua`
4. `./POPSLDR/?.lua`
5. `mass:/POPSLDR/?.lua`
6. `mc0:/POPSLDR/?.lua`
7. `mc1:/POPSLDR/?.lua`

### Images and IRX modules
`System.resolveAssetType` (in `src/system.cpp`) attempts the flat layout first, then legacy folders:
- Images: `APP_DIR/`, `APP_DIR/IMG/`, `APP_DIR/POPSLDR/IMG/`, `APP_DIR/POPSLDR/`
- IRX: `APP_DIR/`, `APP_DIR/IRX/`, `APP_DIR/POPSLDR/IRX/`, `APP_DIR/POPSLDR/`

## Device support (path prefixes used in code)
POPSLoader uses these device prefixes in its runtime paths:
- Memory card: `mc0:/`, `mc1:/`
- USB mass storage: `mass:/` and `mass0:/`–`mass4:/` (the game list path is built as `mass{MASSINDX}:/`, default `MASSINDX = 0`)
- MMCE: `mmce0:/`, `mmce1:/`

## Not handled here
This document does **not** define POPStarter’s own `POPS/` folder expectations (e.g., `mass:/POPS/` or `pfs1:/POPS/`). Those remain POPStarter responsibilities and are validated elsewhere in the runtime.
