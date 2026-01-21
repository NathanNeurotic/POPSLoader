# Runtime layout

## Current expected runtime folder structure (today)
From README and boot scripts:
- Place `POPSLOADER.ELF` and the `POPSLDR/` folder at the USB or HDD root.【F:README.md†L6-L7】
- `boot.lua` executes `POPSLDR/system.lua` from the current directory, and adds `POPSLDR/` search paths for `mass:/`, `mc0:/`, and `mc1:/`.【F:etc/boot.lua†L1-L1】【F:etc/boot.lua†L55-L60】

Example layout (USB root):
```
/mass:/
  POPSLOADER.ELF
  POPSLDR/
    system.lua
    ui.lua
    images.lua
    pops_profiles.lua
    PATCH_5.BIN
```
(See packaged assets under `bin/POPSLDR/` in the repo.)【F:bin/POPSLDR/system.lua†L1-L11】

## Target layout (goal)
**Goal:** assets should load from the ELF directory first (no subfolder dependency). This is an active refactor goal and must preserve legacy fallback behavior unless intentionally removed and documented. (See `AGENTS.md` for the explicit roadmap statement.)【F:AGENTS.md†L41-L50】

## Compatibility strategy (fallback order)
When resolving Lua scripts/modules:
1. `./POPSLDR/?.lua`
2. `./?.lua`
3. `mass:/POPSLDR/?.lua`
4. `mc0:/POPSLDR/?.lua`
5. `mc1:/POPSLDR/?.lua`【F:etc/boot.lua†L1-L1】

`boot.lua` expects `POPSLDR/system.lua` to be accessible in the current working directory and will error if it is missing.【F:etc/boot.lua†L55-L60】

## Runtime assets and search locations
| Asset type | Example(s) | Search / usage location | Evidence |
|---|---|---|---|
| Lua entrypoint | `POPSLDR/system.lua` | `dofile("POPSLDR/system.lua")` from current directory | `etc/boot.lua` |【F:etc/boot.lua†L55-L60】
| Lua modules (POPSLDR) | `ui.lua`, `images.lua`, `pops_profiles.lua` | `package.path` includes `mass:/POPSLDR/?.lua`, `mc0:/POPSLDR/?.lua`, `mc1:/POPSLDR/?.lua` | `etc/boot.lua` |【F:etc/boot.lua†L1-L1】
| POPStarter ELF | `mass:/POPS/POPSTARTER.ELF` | Used as `PLDR.POPSTARTER_PATH` when launching games | `bin/POPSLDR/system.lua` |【F:bin/POPSLDR/system.lua†L25-L27】
| POPStarter dependencies (USB/HDD) | `POPS_IOX.PAK`, `POPS.ELF`, `IOPRP252.IMG` | Checked under `mass:/POPS/` or `pfs1:/POPS/` if enabled | `bin/POPSLDR/system.lua` |【F:bin/POPSLDR/system.lua†L63-L74】
| Optional IGR textures | `PATCH_5.BIN` | Documented as replaceable in `POPS/` for POPStarter IGR | `bin/README.md` |【F:bin/README.md†L9-L10】

## TODOs / unknowns (verify in code)
- `mmce0:/` usage is not visible in the reviewed files. The module `mmceman.irx` is embedded, but no explicit device path references were found. **TODO: verify** in other Lua scripts or C/C++ modules.【F:iop/embed/mmceman.irx†L1-L1】
