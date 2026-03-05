Last updated: 2026-03-05

# ARCHITECTURE

## Purpose
High-level map of POPSLoader structure, flow, and boundaries.

## Top-Level Components
- [ ] `src/` EE core runtime (`main.cpp`, rendering/audio/input, Lua host bindings).
- [ ] `bin/POPSLDR/` Lua orchestration and UI (`system.lua`, `ui.lua`, profiles, assets).
- [ ] `iop/embed/` embedded IRX modules loaded at runtime.
- [ ] `iop/bdm_query/` RPC module for querying block-device backend identity.
- [ ] `modules/` optional controller modules (`ds34bt`, `ds34usb`, `pademu`).
- [ ] `Makefile` + `.github/workflows/compilation.yml` build/embed/package pipeline.

## Data / Control Flow
- [ ] ELF startup (`src/main.cpp`) initializes IOP/runtime and executes boot Lua.
- [ ] Boot script (`etc/boot.lua`) normalizes boot context and requires `system.lua`.
- [ ] Runtime logic (`bin/POPSLDR/system.lua`) prepares devices, assets, and launch policies.
- [ ] UI logic (`bin/POPSLDR/ui.lua`) handles scene navigation and user actions.
- [ ] Device enumeration/classification uses mass roots + mount driver identity (`sdc` => MX4SIO path).
- [ ] Game discovery scans device `POPS/` folders for `.vcd` files.
- [ ] Launch path resolves POPStarter selector/device mode and transfers control.

## Key Boundaries
- [ ] Keep boot and launch pipeline behavior stable unless task explicitly targets startup/launch.
- [ ] Keep device detection/classification logic stable and isolated (Lua + `luasystem.cpp` + `bdm_query`).
- [ ] Keep UI scene code separate from low-level backend probing details.
- [ ] Keep embedded assets/IRX packaging changes isolated to build+asset paths.

## Where to Add New Features vs Fixes
- [ ] UI/UX features: `bin/POPSLDR/ui.lua` and related image/text assets.
- [ ] Device/backend behavior: `bin/POPSLDR/system.lua` plus `src/luasystem.cpp` if native hooks are required.
- [ ] Low-level module behavior: `iop/` and `src/` only when Lua-level changes are insufficient.
- [ ] Build/package changes: `Makefile` and CI workflow.
- [ ] Bug fixes should land closest to defect source; avoid cross-layer rewrites.

## Dependency Rules
- [ ] Lua UI/runtime may depend on exposed `System.*` APIs; avoid bypassing through ad hoc globals.
- [ ] EE core (`src/`) can embed/use Lua/assets and IRX blobs; embedded data must not depend on runtime state.
- [ ] IOP modules remain isolated and communicate through explicit RPC/IOCTL boundaries.
- [ ] Optional controller modules must not become hard runtime requirements for core boot/launch.
- [ ] Runtime behavior must remain deterministic for the same inputs/device state.
