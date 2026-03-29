Last updated: 2026-03-29

# ARCHITECTURE

## Runtime Layers

### 1) EE bootstrap and module load
- Entry point: `src/main.cpp`.
- Responsibilities:
  - initialize EE runtime services,
  - load core IOP modules,
  - initialize graphics/input/audio,
  - execute embedded Lua boot.
- Boot script execution is retried through an on-screen recovery flow if Lua startup fails.

### 2) Embedded Lua runtime
- Lua VM setup: `src/luaplayer.cpp`.
- Required runtime Lua is embedded:
  - `boot.lua`
  - `system.lua`
  - `ui.lua`
  - `images.lua`
  - `pops_profiles.lua`
- Filesystem Lua loaders are disabled, so startup does not depend on loose Lua files beside the ELF.

### 3) Lua orchestration layer
- `etc/boot.lua` initializes fonts and requires `system`.
- `bin/POPSLDR/system.lua` owns:
  - settings load/save/apply,
  - backend detection/classification,
  - startup backend auto-init,
  - HDD mount tracking,
  - game-list construction,
  - POPStarter launch policy,
  - external ELF teardown prep.
- `bin/POPSLDR/ui.lua` owns:
  - scenes and transitions,
  - notifications/modals,
  - settings UI,
  - path editor / keyboard,
  - busy overlays,
  - cover preview behavior,
  - exit modal behavior.

### 4) Native bindings and loaders
- `src/luasystem.cpp` provides `System.*` bindings for:
  - file and directory I/O,
  - current working directory,
  - ELF loading,
  - browser exit,
  - embedded asset access,
  - BDM/USB/MMCE/MX4SIO helpers,
  - mount-driver queries.
- `src/luaHDD.cpp` provides `HDD.*` bindings for HDD status and partition mount APIs.
- `src/elf_loader/src/elf.c` owns the low-level ELF handoff backends:
  - `LoadExecPS2`
  - `ExecPS2`
  - `ExecPS2` with IOP reboot

### 5) Build/package pipeline
- `Makefile` embeds assets and builds `bin/POPSLOADER.ELF`.
- `.github/workflows/compilation.yml` compiles in a `ps2dev/ps2dev` container and packages:
  - `PS1_POPSLOADER/*`
  - `POPS/PATCH_5.BIN`

## Core Data Flows

### Boot flow
1. `src/main.cpp` initializes runtime services and calls `runScript("boot.lua")`.
2. `etc/boot.lua` initializes fonts and requires `system.lua`.
3. `system.lua` loads settings, runs `PLDR.AutoInitStartupBackends()`, then enters the UI flow.

### Startup backend auto-init flow
1. Boot path inputs are collected from:
  - `BOOT_ARGV0_RAW`
  - `BOOT_PATH_RAW`
  - `APP_DIR_LOCAL`
  - configured `POPSTARTER_PATH`
  - configured `DKWDRV_PATH`
  - selected profile `ELF`
2. Mass roots are normalized and classified by mount-driver identity.
3. Required backends are initialized before the user first opens those pages.

### Settings transaction flow
1. UI edits stay in draft fields.
2. Leaving/confirming Settings calls `PLDR.CommitSettingsChanges(...)`.
3. Save/apply writes `.pldrs`, applies any BDMA changes, and re-syncs runtime/UI state.
4. Save/apply failures remain visible to the user.

### HDD list and cover flow
1. HDD partition discovery walks the configured POPS partition set.
2. Each partition is mounted temporarily into a tracked `pfsX:/` slot.
3. Game entries are encoded as `partition|file.vcd`.
4. Cover lookup uses:
  - sidecar PNG beside the selected `.VCD`,
  - or `hdd0:__common/POPS/ART/<title>.png` for HDD entries.

### External handoff flow
1. UI or launch logic prepares the target path and arguments.
2. `PrepareForExternalELFLaunch(...)` computes the PFS keep-mask and unmounts tracked slots not needed for the next handoff.
3. Control transfers through `System.loadELF(...)` or `System.exitToBrowser()`.

## Current Architectural Constraints
- Runtime device locks are not enforced anymore:
  - `canEnterDevice()` always returns `true`,
  - `setDeviceLock()` is a no-op.
- USB vs MX4SIO identity must remain driver-based, not path-name based.
- Probe/retry behavior must stay bounded.
- Launch failures must stay explicit to the user.

## Current Known Gaps
- `HDD (exFAT)` is still a stub menu entry.
- `SMB (v1)` is still a stub menu entry.
- HDD-backed `POPSTARTER.ELF` exec handoff is still unresolved on reported hardware (`D-10`, `D-14`).
- `BOOT.ELF` after HDD runtime initialization is still a connected concern on the current line (`U-10`).
- PAL UI aspect compensation exists in code, but final display correctness still needs hardware confirmation.
