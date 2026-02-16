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
`System.resolveAssetType` and runtime helpers attempt the flat layout first, then legacy folders:
- Images: `APP_DIR/`, `APP_DIR/IMG/`, `APP_DIR/POPSLDR/IMG/`, `APP_DIR/POPSLDR/`
- IRX: `APP_DIR/`, `APP_DIR/IRX/`, `APP_DIR/POPSLDR/IRX/`, `APP_DIR/POPSLDR/`

## Device support (path prefixes used in code)
POPSLoader uses these device prefixes in its runtime paths:
- Memory card: `mc0:/`, `mc1:/`
- USB mass storage: `mass:/` and indexed roots (`mass0:/`...`massN:/`) for multi-device scanning/launch
- MMCE: `mmce0:/`, `mmce1:/`

## USB runtime behavior (current)
- **Single USB UI page:** USB games are displayed in one scene/page (`GUSB`); FAT32/exFAT split UX should not be treated as current behavior in this branch.【F:bin/POPSLDR/ui.lua†L11-L15】【F:bin/POPSLDR/ui.lua†L1237-L1240】
- **Aggregated scan roots:** USB game discovery merges entries from multiple `mass*:/POPS/` roots returned by classifier + metadata + probing fallback paths.【F:bin/POPSLDR/system.lua†L639-L757】
- **Per-entry launch source:** Launch uses the selected game entry's stored source root (`source_root`) so POPStarter handoff is built from that specific root, not a single global mass index.【F:bin/POPSLDR/system.lua†L726-L757】【F:bin/POPSLDR/system.lua†L1548-L1619】
- **Fallback when classifier data is unavailable:** runtime probes known `massN:/POPS/` roots and keeps partial list results when only some roots respond; failures on one root do not block other roots from being listed/launchable.【F:bin/POPSLDR/system.lua†L621-L637】【F:bin/POPSLDR/system.lua†L668-L757】
- **TODO: verify:** BDM classification contract details are still provisional; confirm expected field semantics and mapping between `src/luasystem.cpp` and `iop/bdm_query/bdm_query.c` before tightening strict matching assumptions in docs or logic.【F:src/luasystem.cpp†L186-L223】【F:src/luasystem.cpp†L359-L429】【F:iop/bdm_query/bdm_query.c†L45-L65】

## Not handled here
This document does **not** define POPStarter’s own `POPS/` folder expectations (e.g., `mass:/POPS/` or `pfs1:/POPS/`). Those remain POPStarter responsibilities and are validated elsewhere in the runtime.
