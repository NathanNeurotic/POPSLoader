Last updated: 2026-03-17

# ARCHITECTURE

## Runtime Layers

### 1) EE bootstrap and module load
- Entry point: `src/main.cpp`.
- Boots EE runtime, initializes RPC/services, loads core IOP modules, initializes graphics/input/audio, then executes Lua boot.
- `runScript("boot.lua")` is called in a retry loop; script errors show an on-screen recovery prompt.

### 2) Embedded Lua runtime
- Lua VM setup: `src/luaplayer.cpp`.
- Script loader is embedded-only:
  - embedded searcher is installed (`boot.lua`, `system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`).
  - filesystem script loaders (`dofile`, `loadfile`, `package.path`, `package.cpath`) are disabled.
- This makes startup deterministic and independent of external Lua files.

### 3) Lua app orchestration
- `etc/boot.lua` initializes fonts, handles HDD PFS boot path resolution (mounts `pfs1:` when launched from an HDD PFS path), and requires `system.lua`.
- `bin/POPSLDR/system.lua` owns:
  - settings load/save,
  - backend detection/classification,
  - game list construction,
  - launch policy and POPStarter handoff,
  - BDMA apply/copy logic.
- `bin/POPSLDR/ui.lua` owns scenes, input, notifications, settings UI, overlays, and modals.
- `bin/POPSLDR/images.lua` lazy-loads embedded PNG assets.

### 4) Native Lua bindings and storage APIs
- `src/luasystem.cpp` provides `System.*` bindings:
  - file operations,
  - directory listing,
  - ELF loading,
  - embedded asset access,
  - BDM backend refresh/query,
  - mount-driver lookup (`System.getMassMountDriver`),
  - backend initializers (`ensureUsbMass`, `initMX4SIO`, etc.).
- `src/luaHDD.cpp` provides `HDD.*` bindings for partition mount/status and HDD IRX init.

### 5) Build/package and embedded asset pipeline
- `Makefile` embeds runtime assets and IRX payloads into the final ELF via `bin2c`.
- CI: `.github/workflows/compilation.yml` runs build + packaging and verifies exact ZIP contents.
- Release package policy is currently:
  - `PS1_POPSLOADER/*` launcher set
  - `POPS/PATCH_5.BIN`
  - no legacy `POPS/*.tm2` entries

## Core Data Flows

### Boot flow
1. `main.cpp` initializes EE/IOP and calls `runScript("boot.lua")`.
2. `boot.lua` handles HDD PFS launch path resolution (if applicable), initializes fonts, and requires `system.lua`.
3. `system.lua` loads settings (`PLDR.LoadSettingsNonFatal()`), initializes backend readiness, and enters UI loop.

### Settings transaction flow
1. Settings/Profile edits are staged in UI draft state.
2. On confirm/leave, UI calls `PLDR.CommitSettingsChanges(...)`.
3. Commit path persists `.pldrs` and (if needed) applies BDMA assets.
4. Failure path re-syncs runtime/UI state and shows notification.

### Storage classification flow (USB vs MX4SIO)
1. Mounted `mass:/..mass9:/` roots are enumerated.
2. For mounted roots, mount-driver identity is queried (`System.getMassMountDriver`).
3. Driver names containing `mx4` or `sdc` classify as MX4SIO; others as USB.
4. Game lists are built from backend-specific root sets.

### Launch flow
1. UI selection calls `PLDR.RunPOPStarterGame(...)`.
2. Launch policy is resolved from scene + path (USB/MMCE/MX4SIO/HDD).
3. POPStarter path is resolved (including `mc?:/` expansion when configured).
4. Launch goes through `LaunchEngine -> System.loadELF` with guarded failure handling.

## Architectural Constraints
- Retry/probe paths are bounded (no unbounded backend polling loops).
- Launch is blocked with explicit user feedback when key files are missing.
- Device-family lock prevents unsafe mid-session switching between already-loaded driver families.

## Known Gaps (Code-Visible)
- Main menu option `HDD (exFAT)` is present but returns `Not Implemented Yet` (`ui.lua`).
- Main menu option `SMB (v1)` is present but returns `Not Implemented Yet` (`ui.lua`).
- ART system is not implemented in current runtime Lua paths.
