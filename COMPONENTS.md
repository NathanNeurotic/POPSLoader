Last updated: 2026-05-28 (post-BETA-10-5)

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
- `.github/workflows/compilation.yml` packages the release ZIP and verifies its exact contents (pinned to `ps2dev/ps2dev:v2.0.0` at commit `ba8f0d0`).
- `.github/workflows/rolling-release.yml` (added post-release) publishes a `POPSLOADER-rolling-release.zip` asset to the canonical `rolling-release` GitHub Release on push-to-BETA-12-PLAY and on PR events.

### Repository automation
- `.github/workflows/opencode.yml` handles comment-triggered AI assistance.
- It is not part of release packaging or runtime behavior.

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
- `HDD (exFAT)`: not implemented (intentionally surfaces "Not Implemented Yet").
- `SMB (v1)`: not implemented (intentionally surfaces "Not Implemented Yet").
- `ILINK`: not implemented (intentionally surfaces "Not Implemented Yet").

## Current Validation Hotspots (preservation tests, not active failures)

These are hardware-confirmed PASS in BETA-10-5 and must continue to pass on any future artifact:
- D-10 (HDD POPSTARTER + HDD game) — B2 fix at `4ae6679` is load-bearing.
- D-14 (HDD POPSTARTER + non-HDD game) — same partition-aware route as D-10.
- D-15 (non-HDD POPSTARTER + HDD game) — keep-mask preserves boot partition PFS slot.
- DKWDRV from MC — reboot variant direct path with argv0 synthesis.
- BOOT.ELF from USB-booted POPSLoader (L-07) — V2 route at `d23520a`.
- Settings save: USB / MC / MMCE / MX4SIO → per-device sidecar; HDD → mc0 fallback (PR #466 by design).

Hardware-unknown items still needing verification:
- U-06 (PAL UI aspect).
- D-13 (device switching without runtime locks).
- S-09 (keyboard layout persistence).
- U-11 (boot-device label display).

Pragmatically accepted (known-broken, do not test):
- DKWDRV from custom HDD path — workaround: use MC DKWDRV path.
- U-10 BOOT.ELF from HDD-booted POPSLoader — workaround: Exit → OSDSYS or reboot.

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
- Repository automation issues:
  - `.github/workflows/opencode.yml`
