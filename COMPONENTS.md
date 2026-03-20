Last updated: 2026-03-20

# COMPONENTS

## Purpose
Current technical map of POPSLoader modules, ownership boundaries, and entry points.

## Top-Level Components

### Launcher runtime (`src/`)
- EE bootstrap and runtime services.
- Key files:
  - `src/main.cpp` for startup, IOP/EE init, and Lua boot execution,
  - `src/luaplayer.cpp` for embedded Lua VM and loader policy,
  - `src/luasystem.cpp` for Lua `System.*` bindings,
  - `src/luaHDD.cpp` for Lua `HDD.*` bindings,
  - `src/embed_assets.cpp` for embedded asset lookup.

### Lua app layer (`bin/POPSLDR/`)
- User-visible behavior, menu flow, device selection, settings, cover preview, and launch orchestration.
- Key files:
  - `bin/POPSLDR/system.lua`,
  - `bin/POPSLDR/ui.lua`,
  - `bin/POPSLDR/images.lua`,
  - `bin/POPSLDR/pops_profiles.lua`.

### Boot script (`etc/`)
- `etc/boot.lua` handles boot-path normalization for HDD launches, loads fonts, and transfers control to the Lua app layer.

### IOP modules and RPC (`iop/`)
- Embedded IRX payloads and backend query module source.
- Key paths:
  - `iop/embed/`,
  - `iop/bdm_query/`.

### Controller modules (`modules/`)
- DS3/DS4 support modules and pademu payloads.
- Key paths:
  - `modules/ds34bt`,
  - `modules/ds34usb`,
  - `modules/pademu`.

### Build and package pipeline
- `Makefile` embeds assets and IRX files, builds `bin/enceladus.elf`, then packs `bin/POPSLOADER.ELF`.
- `.github/workflows/compilation.yml` is the authoritative CI build/package workflow.

## Runtime Functional Ownership

### Settings, BDMA, and video standard
- Owner: `bin/POPSLDR/system.lua` plus the settings scene in `bin/POPSLDR/ui.lua`.
- Persists settings in `mc0:/POPSTARTER/.pldrs`.
- Applies BDMA mode by copying or removing required files in `mc0:/POPSTARTER/`.
- Persists and applies video standard (`NTSC` or `PAL`).

### Device discovery and classification
- Owner: `bin/POPSLDR/system.lua` using `System.*` APIs from `src/luasystem.cpp`.
- USB vs MX4SIO split is mount-driver based (`mx4` or `sdc` means MX4SIO).
- MMCE list flow currently uses the internal `GSMB` scene identifier.

### Launch handoff and path resolution
- Owner: `bin/POPSLDR/system.lua` via `PLDR.RunPOPStarterGame`.
- Handles backend-specific launch policy, POPStarter path resolution, selector and `argv` shaping, then `System.loadELF`.

### UI, scene state, and presentation
- Owner: `bin/POPSLDR/ui.lua`.
- Includes transitions, settings editor, notifications and modals, optional build-info stamp loading, cover preview cache, hide-text toggle, and the Disc launch modal.

### Optional runtime metadata
- Owner: `bin/POPSLDR/ui.lua` plus workflow-generated file output.
- `BUILD_INFO.txt` is read at runtime if present.
- CI generates the file before compile, but current release packaging does not copy it into `POPSLOADER.zip`.

## Current Feature Surface by Main Menu Option
- `MMCE`: implemented.
- `MX4SIO`: implemented with bounded retries.
- `HDD (exFAT)`: not implemented and reports `Not Implemented Yet`.
- `HDD (PFS)`: implemented.
- `USB`: implemented.
- `SMB (v1)`: not implemented and reports `Not Implemented Yet`.
- `Disc (DKWDRV)`: implemented via modal launch path.

## Primary Change Entry Points
- Settings, BDMA, or video standard issues:
  - `bin/POPSLDR/system.lua`
  - `bin/POPSLDR/ui.lua`
- Device detection and classification issues:
  - `bin/POPSLDR/system.lua`
  - `src/luasystem.cpp`
  - `iop/bdm_query/bdm_query.c`
- Launch handoff, path resolution, or selector issues:
  - `bin/POPSLDR/system.lua`
  - `src/elf_loader/src/elf.c`
  - `src/luasystem.cpp`
- Cover art or Credits UI issues:
  - `bin/POPSLDR/ui.lua`
  - `bin/POPSLDR/system.lua`
- Packaging or release-content issues:
  - `Makefile`
  - `.github/workflows/compilation.yml`
