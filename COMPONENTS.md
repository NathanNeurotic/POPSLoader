Last updated: 2026-03-29

# COMPONENTS

## Purpose
Current technical map of POPSLoader modules, ownership boundaries, and entry points.

## Top-Level Components

### Launcher runtime (`src/`)
- EE bootstrap and runtime services.
- Key files:
  - `src/main.cpp`
  - `src/luaplayer.cpp`
  - `src/luasystem.cpp`
  - `src/luaHDD.cpp`
  - `src/elf_loader/src/elf.c`
  - `src/embed_assets.cpp`

### Lua app layer (`bin/POPSLDR/`)
- User-visible launcher behavior.
- Key files:
  - `bin/POPSLDR/system.lua`
  - `bin/POPSLDR/ui.lua`
  - `bin/POPSLDR/images.lua`
  - `bin/POPSLDR/pops_profiles.lua`

### Boot script (`etc/`)
- `etc/boot.lua` initializes the runtime font and transfers control to `system.lua`.

### IOP modules and RPC (`iop/`)
- Embedded IRX payloads and backend query helpers.
- Key paths:
  - `iop/embed/`
  - `iop/bdm_query/`

### Controller modules (`modules/`)
- DS3/DS4 support and pad-emulation payloads.

### Build/package pipeline
- `Makefile` builds and embeds the runtime.
- `.github/workflows/compilation.yml` packages the release ZIP and verifies its exact contents.

## Runtime Functional Ownership

### Settings and BDMA management
- Primary owner: `bin/POPSLDR/system.lua`
- UI owner: `bin/POPSLDR/ui.lua`
- Current persisted settings include:
  - selected profile,
  - POPSTARTER path,
  - DKWDRV path,
  - video standard,
  - hide-text mode,
  - keyboard layout,
  - BDMA mode.

### Device discovery and startup readiness
- Primary owner: `bin/POPSLDR/system.lua`
- Native support: `src/luasystem.cpp`, `src/luaHDD.cpp`
- Responsibilities:
  - USB vs MX4SIO classification,
  - MMCE slot detection,
  - HDD status/module load,
  - startup backend auto-init based on boot/configured paths.

### Launch and exit handoff
- Primary owner: `bin/POPSLDR/system.lua`
- UI entry points: `bin/POPSLDR/ui.lua`
- Native handoff: `src/luasystem.cpp`, `src/elf_loader/src/elf.c`
- Responsibilities:
  - POPSTARTER path resolution,
  - selector/argv shaping,
  - HDD mount-slot preservation,
  - `BOOT.ELF` and `DKWDRV.ELF` launch,
  - OSDSYS/browser exit.

### UI/UX and scene state
- Owner: `bin/POPSLDR/ui.lua`
- Includes:
  - main menu and device scenes,
  - settings page,
  - on-screen keyboard/path editor,
  - cover preview cache,
  - busy/progress overlays,
  - exit modal.

### Cover/art behavior
- Owner: `bin/POPSLDR/ui.lua`
- Current supported cover sources:
  - `<game>.png` beside the selected `.VCD`,
  - `hdd0:__common/POPS/ART/<title>.png` for HDD entries.

## Current Feature Surface by Main Menu Option
- `MMCE`: implemented in code.
- `MX4SIO`: implemented in code.
- `HDD (PFS)`: implemented in code.
- `USB`: implemented in code.
- `Disc (DKWDRV)`: implemented in code.
- `HDD (exFAT)`: not implemented.
- `SMB (v1)`: not implemented.

## Current Validation Hotspots
- HDD POPSTARTER when POPSTARTER itself resolves from HDD (`D-10`).
- HDD-backed POPSTARTER with non-HDD game (`D-14`).
- BOOT.ELF after HDD page initialization (`U-10`).
- Preserve the restored non-HDD POPSTARTER HDD-game path (`D-15`).
- PAL UI aspect verification (`U-06`).

## Primary Change Entry Points
- Settings persistence/apply issues:
  - `bin/POPSLDR/system.lua`
  - `bin/POPSLDR/ui.lua`
- Device detection/classification issues:
  - `bin/POPSLDR/system.lua`
  - `src/luasystem.cpp`
  - `iop/bdm_query/bdm_query.c`
- Launch handoff/argv/path issues:
  - `bin/POPSLDR/system.lua`
  - `src/luasystem.cpp`
  - `src/elf_loader/src/elf.c`
- Packaging/release issues:
  - `Makefile`
  - `.github/workflows/compilation.yml`
