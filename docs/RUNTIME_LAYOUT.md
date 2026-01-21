# Runtime layout

## Current expected runtime folder structure (today)
From README and boot scripts:
- Place `POPSLOADER.ELF` and runtime assets in the same folder (no subfolder required).【F:README.md†L17-L21】
- `boot.lua` executes the resolved `system.lua` via `System.resolveAsset` and prefers APP_DIR paths first, with legacy `POPSLDR/` fallbacks preserved.【F:etc/boot.lua†L1-L81】【F:src/system.cpp†L80-L107】

Example layout (USB root, no subfolder):
```
/mass:/
  POPSLOADER.ELF
  system.lua
  ui.lua
  images.lua
  pops_profiles.lua
  PATCH_5.BIN
  USB.png
  SMB.png
  HDD.png
  PSL.png
  select.png
  start.png
  (optional) *.irx
```
(See packaged assets under `bin/POPSLDR/` in the repo; packaging flattens them beside the ELF.)【F:bin/POPSLDR/system.lua†L1-L11】【F:Makefile†L171-L179】

## Target layout (goal)
**Goal:** assets should load from the ELF directory first (no subfolder dependency). This is implemented in the resolver and must preserve legacy fallback behavior unless intentionally removed and documented. (See `AGENTS.md` for the explicit roadmap statement.)【F:AGENTS.md†L41-L50】【F:src/system.cpp†L80-L107】

## Compatibility strategy (fallback order)
When resolving Lua scripts/modules:
1. `APP_DIR/?.lua`
2. `APP_DIR/POPSLDR/?.lua` (legacy fallback)
3. `./?.lua`
4. `./POPSLDR/?.lua`
5. `mass:/POPSLDR/?.lua`
6. `mc0:/POPSLDR/?.lua`
7. `mc1:/POPSLDR/?.lua`【F:etc/boot.lua†L1-L11】

`boot.lua` resolves `system.lua` via `System.resolveAsset` before falling back to error handling.【F:etc/boot.lua†L72-L81】

## Runtime assets and search locations
| Asset type | Example(s) | Search / usage location | Evidence |
|---|---|---|---|
| Lua entrypoint | `system.lua` | `System.resolveAsset("system.lua")` (APP_DIR first, `POPSLDR/` fallback) | `etc/boot.lua` |【F:etc/boot.lua†L72-L81】【F:src/system.cpp†L80-L107】
| Lua modules | `ui.lua`, `images.lua`, `pops_profiles.lua` | `package.path` includes `APP_DIR/?.lua` plus legacy `POPSLDR/?.lua` locations | `etc/boot.lua` |【F:etc/boot.lua†L1-L11】
| POPStarter ELF | `mass:/POPS/POPSTARTER.ELF` | Used as `PLDR.POPSTARTER_PATH` when launching games | `bin/POPSLDR/system.lua` |【F:bin/POPSLDR/system.lua†L25-L27】
| POPStarter dependencies (USB/HDD) | `POPS_IOX.PAK`, `POPS.ELF`, `IOPRP252.IMG` | Checked under `mass:/POPS/` or `pfs1:/POPS/` if enabled | `bin/POPSLDR/system.lua` |【F:bin/POPSLDR/system.lua†L63-L74】
| Optional IGR textures | `PATCH_5.BIN` | Documented as replaceable in `POPS/` for POPStarter IGR | `bin/README.md` |【F:bin/README.md†L9-L10】

## TODOs / unknowns (verify in code)
- `mmce0:/` usage is not visible in the reviewed files. The module `mmceman.irx` is embedded, but no explicit device path references were found. **TODO: verify** in other Lua scripts or C/C++ modules.【F:iop/embed/mmceman.irx†L1-L1】
