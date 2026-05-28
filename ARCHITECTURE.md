Last updated: 2026-05-28 (post-BETA-10-5; PR #470 LAUNCH_ARGS, PR #472 MX4SIO classification, PR #473 hotfix merged)

# ARCHITECTURE

## Runtime Layers

### 1) EE bootstrap and module load
- Entry point: `src/main.cpp`.
- Responsibilities:
  - initialize EE runtime services (`_ps2sdk_memory_init` runs `SifExitRpc + SifInitRpc(0) + fileXioExit` before `SifIopReset` per PR #458 Layer A — survives launchers like wLaunchELF that leave `fileXio` loaded on the IOP),
  - parse NHDDL-style launch arguments early via `parseLaunchArgs()` so downstream code can act on `-page=` / `-mode=` / `-game=` / `-debug`,
  - capture pre-IRX boot device hint via `detectBootDeviceHintFromArgv0()` (exposed to Lua as `System.getBootDeviceHint()`),
  - load core IOP modules (mmceman is conditional on `boot_device_hint == "MMCE"` per PR #471 Layer C if merged; eager otherwise),
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
- `.github/workflows/compilation.yml` compiles in a `ps2dev/ps2dev:v2.0.0` container (pinned post-release at commit `ba8f0d0`) and packages:
  - `PS1_POPSLOADER/*`
  - `POPS/PATCH_5.BIN`
  - `PS1_POPSLOADER/BUILD_INFO.txt`
- Build is gated on embedded build identity markers (`Exec path:`, `PrepareForColdExternalELFLaunch`, `BOOT.ELF launch failed`) being present in `bin/enceladus.elf`.
- `.github/workflows/rolling-release.yml` (added post-release) publishes a `POPSLOADER-rolling-release.zip` asset to the canonical `rolling-release` GitHub Release on every push to `BETA-12-PLAY` and on every pull-request event (`opened`, `synchronize`, `reopened`, `ready_for_review`). The tag floats; testers grab the latest asset URL. Last-write-wins semantics.

### 6) Repository automation
- `.github/workflows/opencode.yml` runs comment-triggered AI assistance for issue and pull-request review comments.
- It is outside the runtime boot/launch path and does not define build/package validation gates.

### 7) Launch-path preservation contracts (hardware-confirmed in BETA-10-5)
- **HDD POPSTARTER + HDD game (D-10)**: `LoadELFFromFileExecPS2RebootIOPWithPartition` → `ExecuteHddBackedViaEmbeddedLoader` → child loader `is_hdd_partition_context` branch (dynamic `fileXioUmount` of target PFS slot, `SifExitRpc`/`SifExitCmd`, `FlushCache`, `ExecPS2` — no IOP reset). The B2 fix at commit `4ae6679` is load-bearing. Must not be changed without a hardware-verified replacement.
- **Non-HDD POPSTARTER + HDD game (D-15)**: Same partition-aware route with the boot partition's PFS slot preserved via `keep_mask`.
- **DKWDRV from MC**: Reboot variant direct path with argv0 synthesis. Reload `SIO2MAN`/`MCMAN`/`MCSERV` after IOP reset.
- **BOOT.ELF from USB-booted POPSLoader (L-07)**: V2 route at commit `d23520a` — non-reboot variant + BOOT.ELF special-case in `LoadELFFromFileWithPartition` → `ExecuteViaEmbeddedLoader` → child loader non-HDD branch (`SifExitRpc + FlushCache + ExecPS2`, no IOP reset).
- **MX4SIO `mass:/` classification**: Per PR #472 maintainer rule — only the ioctl driver name (`System.getMassMountDriver`) is authoritative. `sdc`/`mx4` → MX4SIO; anything else → USB. `mx4sio_bd` only loads on explicit MX4SIO evidence and after `usbmass_bd` (dependency enforced at the C layer).

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
- `HDD (exFAT)`, `SMB (v1)`, `ILINK` remain intentionally unimplemented stub menu entries.
- DKWDRV from a custom HDD path is **known broken accepted** in BETA-10-5. Workaround: use the default MC DKWDRV path.
- BOOT.ELF after HDD runtime initialization (`U-10`) is **known broken accepted** in BETA-10-5. Workaround: Exit → OSDSYS or reboot.
- PAL UI aspect compensation exists in code, but final display correctness still needs hardware confirmation.

(D-10 and D-14 are no longer open gaps — the B2 fix at commit `4ae6679` resolved D-10, and D-14 uses the same partition-aware route. Both are hardware-confirmed in BETA-10-5 and are now preservation contracts. See `STATE.md` and `TRUTHSHEET.md`.)
