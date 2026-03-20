Last updated: 2026-03-20

# ARCHITECTURE

## Runtime Layers

### 1) EE bootstrap and module load
- Entry point: `src/main.cpp`.
- Boots EE runtime, initializes RPC and services, loads core IOP modules, initializes graphics/input/audio, then executes Lua boot.
- `runScript("boot.lua")` is called in a retry loop; Lua boot errors are shown on screen with a restart prompt.

### 2) Embedded Lua runtime
- Lua VM setup lives in `src/luaplayer.cpp`.
- Script loading is embedded-only:
  - embedded searcher is installed for `boot.lua`, `system.lua`, `ui.lua`, `images.lua`, and `pops_profiles.lua`,
  - filesystem script loaders (`dofile`, `loadfile`, `package.path`, `package.cpath`) are disabled.
- This keeps startup deterministic and independent of external Lua script files.

### 3) Lua app orchestration
- `etc/boot.lua` handles boot-path normalization for HDD launches, initializes fonts, and requires `system`.
- `bin/POPSLDR/system.lua` owns:
  - settings load/save,
  - video standard apply/persist logic,
  - backend detection and classification,
  - game list construction,
  - launch policy and POPStarter handoff,
  - BDMA apply/copy logic,
  - HDD path resolution helpers.
- `bin/POPSLDR/ui.lua` owns:
  - scenes and transitions,
  - settings editing,
  - notifications and modals,
  - cover cache and preview behavior,
  - optional build-info stamp loading,
  - credits and menu flow.
- `bin/POPSLDR/images.lua` lazy-loads embedded PNG assets.

### 4) Native Lua bindings and storage APIs
- `src/luasystem.cpp` provides `System.*` bindings for:
  - file operations,
  - directory listing,
  - ELF loading,
  - embedded asset access,
  - BDM backend refresh/query,
  - mount-driver lookup (`System.getMassMountDriver`),
  - backend initializers such as `ensureUsbMass`, `ensureCDFS`, and `initMX4SIO`.
- `src/luaHDD.cpp` provides `HDD.*` bindings for partition mount/status and HDD IRX initialization.

### 5) Build, assets, and packaging
- `Makefile` embeds runtime assets and IRX payloads into the final ELF via `bin2c`.
- `.github/workflows/compilation.yml` is the authoritative build and packaging workflow.
- CI currently:
  - generates `bin/POPSLDR/BUILD_INFO.txt`,
  - validates `etc/boot.lua`,
  - runs `make clean elfloader all`,
  - creates `POPSLOADER.zip`,
  - verifies the exact ZIP manifest.
- Current release package policy is:
  - `PS1_POPSLOADER/*` launcher set,
  - `POPS/PATCH_5.BIN`,
  - no legacy `POPS/*.tm2` entries.

## Core Data Flows

### Boot flow
1. `src/main.cpp` initializes EE and IOP state and calls `runScript("boot.lua")`.
2. `etc/boot.lua` normalizes HDD boot paths when needed, initializes fonts, and requires `system.lua`.
3. `bin/POPSLDR/system.lua` loads settings, initializes backend readiness, and enters the UI loop.

### Settings transaction flow
1. Settings and profile edits are staged in UI draft state.
2. On confirm or leave, UI calls `PLDR.CommitSettingsChanges(...)`.
3. Commit persists `.pldrs`, applies video standard immediately, and applies BDMA assets if needed.
4. Failure re-syncs runtime/UI state and shows a notification.

### Storage classification flow (USB vs MX4SIO)
1. Mounted `mass:/` through `mass9:/` roots are enumerated.
2. For mounted roots, mount-driver identity is queried through `System.getMassMountDriver`.
3. Driver names containing `mx4` or `sdc` classify as MX4SIO; others classify as USB.
4. Game lists are built from backend-specific root sets.

### Launch flow
1. UI selection calls `PLDR.RunPOPStarterGame(...)`.
2. Launch policy is resolved from scene and source path (`USB`, `MMCE`, `MX4SIO`, or `HDD`).
3. POPStarter path resolution applies `mc?:/` expansion, app-local sidecar checks, HDD sidecar checks, and memory-card fallbacks as needed.
4. Launch goes through `LaunchEngine -> System.loadELF` with guarded failure handling.

### Cover and build-info flow
1. Game-list selection resolves the currently highlighted `.VCD` path.
2. Non-HDD backends probe a sidecar `<game>.png`; HDD probes `hdd0:__common/POPS/ART/<title>.png`.
3. Credits scene reads optional `BUILD_INFO.txt` or `POPSLDR/BUILD_INFO.txt` from the filesystem if present.

## Architectural Constraints
- Retry and probe paths are bounded; no unbounded backend polling loops are part of the current design.
- Launch is blocked with explicit user feedback when key files are missing.
- Build/package correctness is judged by GitHub Actions CI, not local toolchains.
- `GSMB` is a legacy internal scene name currently reused for MMCE list flow; it does not imply working SMB support.
- UI stores device-lock metadata, but current menu flow does not wire that metadata into blocking behavior.

## Known Gaps (Code-Visible)
- Main-menu option `HDD (exFAT)` returns `Not Implemented Yet`.
- Main-menu option `SMB (v1)` returns `Not Implemented Yet`.
- Broader artwork management is not implemented beyond current local PNG lookup.
- CI generates `BUILD_INFO.txt`, but current release packaging does not ship it.
