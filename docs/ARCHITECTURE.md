# Architecture

## High-level flow (UI → profile selection → POPStarter handoff)
- The Lua entrypoint is `etc/boot.lua`, embedded into the ELF at build time and executed at startup; it sets `package.path` and runs `POPSLDR/system.lua`.【F:Makefile†L71-L73】【F:etc/boot.lua†L1-L1】【F:etc/boot.lua†L55-L60】
- `bin/POPSLDR/system.lua` initializes UI state and executes a main loop that drives scenes (main menu, profile query, game list, credits).【F:bin/POPSLDR/system.lua†L277-L296】
- POPStarter handoff is performed by `PLDR.RunPOPStarterGame`, which builds a boot parameter and calls `System.loadELF(POPSLDR.POPSTARTER_PATH, ...)`.【F:bin/POPSLDR/system.lua†L262-L279】

## Key modules / files and responsibilities
- `src/main.cpp`: EE entrypoint; sets up IOP modules, device readiness, and boot path from argv, then executes embedded Lua boot script.【F:src/main.cpp†L65-L126】
- `etc/boot.lua`: boot script; sets Lua search paths, handles HDD boot path setup, and loads `POPSLDR/system.lua`.【F:etc/boot.lua†L1-L60】
- `bin/POPSLDR/system.lua`: core runtime logic for POPSLoader UI, game list handling, and POPStarter handoff (calls `System.loadELF`).【F:bin/POPSLDR/system.lua†L25-L31】【F:bin/POPSLDR/system.lua†L262-L296】
- `bin/POPSLDR/ui.lua`, `bin/POPSLDR/images.lua`, `bin/POPSLDR/pops_profiles.lua`: UI and profile data loaded via `require(...)` from `system.lua`.【F:bin/POPSLDR/system.lua†L55-L58】
- `src/luasystem.cpp`: provides Lua bindings such as `System.loadELF` for POPStarter handoff.【F:src/luasystem.cpp†L496-L526】【F:src/luasystem.cpp†L720-L735】

## Where Lua lives and how it’s invoked
- Lua boot code is embedded from `etc/boot.lua` into the ELF during the build (via `bin2c`).【F:Makefile†L71-L73】
- Runtime Lua scripts are expected under `POPSLDR/` (e.g., `POPSLDR/system.lua`) and are loaded using `dofile`/`require`.【F:etc/boot.lua†L55-L60】【F:bin/POPSLDR/system.lua†L55-L58】
