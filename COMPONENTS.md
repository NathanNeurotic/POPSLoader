Last updated: 2026-03-06

# COMPONENTS

## Purpose
Current technical map of POPSLoader modules, ownership boundaries, and entry points.

## Top-Level Components

### Launcher runtime (`src/`)
- EE bootstrap and runtime services.
- Key files:
  - `src/main.cpp` (startup, IOP/EE init, Lua boot execution)
  - `src/luaplayer.cpp` (embedded Lua VM and loader policy)
  - `src/luasystem.cpp` (Lua `System.*` bindings)
  - `src/luaHDD.cpp` (Lua `HDD.*` bindings)
  - `src/embed_assets.cpp` (embedded asset lookup table)

### Lua app layer (`bin/POPSLDR/`)
- User-visible behavior, menu flow, device selection, launch orchestration.
- Key files:
  - `bin/POPSLDR/system.lua`
  - `bin/POPSLDR/ui.lua`
  - `bin/POPSLDR/images.lua`
  - `bin/POPSLDR/pops_profiles.lua`

### Boot script (`etc/`)
- `etc/boot.lua` initializes boot font and transfers control to Lua app layer.

### IOP modules and RPC (`iop/`)
- Embedded IRX payloads and backend query module source.
- Key paths:
  - `iop/embed/` (IRX payloads)
  - `iop/bdm_query/` (RPC module for BDM backend list)

### Controller modules (`modules/`)
- DS3/DS4 related support modules and pademu payloads.
- Key paths:
  - `modules/ds34bt`
  - `modules/ds34usb`
  - `modules/pademu`

### Build/package pipeline
- `Makefile` embeds assets/IRX and builds `bin/POPSLOADER.ELF`.
- `.github/workflows/compilation.yml` compiles and verifies release ZIP manifest.

## Runtime Functional Ownership

### Settings and BDMA management
- Owner: `bin/POPSLDR/system.lua` + settings scene in `bin/POPSLDR/ui.lua`.
- Persists settings in `mc0:/POPSTARTER/.pldrs`.
- Applies BDMA mode by copying/removing required files in `mc0:/POPSTARTER/`.

### Device discovery and classification
- Owner: `bin/POPSLDR/system.lua` using `System.*` APIs from `src/luasystem.cpp`.
- USB vs MX4SIO split is mount-driver based (`mx4`/`sdc` => MX4SIO).

### Launch handoff
- Owner: `bin/POPSLDR/system.lua` (`PLDR.RunPOPStarterGame`).
- Backend-specific launch policy and argv shaping, then `System.loadELF`.

### UI/UX and scene state
- Owner: `bin/POPSLDR/ui.lua`.
- Includes transition engine, settings editor, notifications/modals, cover preview cache, hide-text toggle.

## Current Feature Surface by Main Menu Option
- `MMCE`: implemented.
- `MX4SIO`: implemented (with bounded retries).
- `HDD (exFAT)`: not implemented (explicit notification).
- `HDD (PFS)`: implemented.
- `USB`: implemented.
- `SMB (v1)`: not implemented (explicit notification).
- `Disc (DKWDRV)`: implemented via modal launch path.

## Primary Change Entry Points
- Settings persistence/apply issues:
  - `bin/POPSLDR/system.lua`
  - `bin/POPSLDR/ui.lua`
- Device detection/classification issues:
  - `bin/POPSLDR/system.lua`
  - `src/luasystem.cpp`
  - `iop/bdm_query/bdm_query.c`
- Launch handoff/argv issues:
  - `bin/POPSLDR/system.lua`
  - `src/elf_loader/src/elf.c`
  - `src/luasystem.cpp`
- Packaging/release content issues:
  - `Makefile`
  - `.github/workflows/compilation.yml`
