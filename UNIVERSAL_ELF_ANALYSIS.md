# UNIVERSAL_ELF_ANALYSIS.md

## 1) Build Variant Differences

### Variant selection in build system
- `Makefile` supports: `VARIANT ?= mmce` with documented values `mmce | mx4sio | hdd | hdd_diag`.
- Variant compile defines:
  - `VARIANT=mmce` → `-DBOOT_MMCE`
  - `VARIANT=mx4sio` → `-DBOOT_MX4SIO`
  - `VARIANT=hdd` → `-DBOOT_HDD`
  - `VARIANT=hdd_diag` → `-DBOOT_HDD -DBOOT_DIAG`

### Preprocessor flags involved (observed)
- `BOOT_MMCE` (set by Makefile; no direct guarded blocks found in scanned C/C++ files).
- `BOOT_MX4SIO`.
- `BOOT_HDD`.
- `BOOT_DIAG` (used in diagnostics/log exposure).
- Also present but not variant selectors: `RESET_IOP`, `DEBUG`, `POWERPC_UART`.

### Code blocks wrapped in `#ifdef/#if defined(BOOT_*)`
- `src/main.cpp`
  - `#if defined(BOOT_HDD)` around `EarlyVideoProbe_HDD()` behavior.
  - `#if defined(BOOT_HDD)` around HDD remount/canonicalization section after fileXio init.
  - `#if defined(BOOT_HDD)` controlling `init_mass_stack` suppression when booted from `pfs*/hdd0:`.
  - `#if defined(BOOT_MX4SIO)` for early `mx4sio_bd.irx` load.
- `src/bootdiag.cpp`
  - `#if defined(BOOT_DIAG)` for file logging and heartbeat rendering.
- `src/luasystem.cpp`
  - `#if defined(BOOT_DIAG)` exports Lua global `BOOT_DIAG` true/false.

### IOP modules included per variant (build-time embedding)
- Current `Makefile` `IOP_MODULES` list is common across variants; all listed modules are embedded in all variants.
- Therefore variant differences today are primarily **runtime behavior gates** (via `BOOT_HDD`/`BOOT_MX4SIO` blocks), not module embedding set differences.

---

## 2) Runtime Differences

### Device-specific initialization logic in `src/main.cpp`
- HDD-specific behavior (`BOOT_HDD`):
  - HDD early-video probe enabled.
  - HDD remount/canonicalization paths run after fileXio load.
  - If boot source is `pfs*/hdd0:`, mass stack init is skipped (`init_mass_stack=0`) to reduce deadlock risk before graphics.
- MX4SIO-specific behavior (`BOOT_MX4SIO`):
  - `mx4sio_bd.irx` loaded early at boot.
- MMCE handling:
  - `mmceman_irx` load attempted at boot (not behind `BOOT_MMCE`), probe deferred until MMCE page entry.

### Device-specific module loads
- Boot path (main.cpp):
  - Always attempted core: `iomanX`, `fileXio`, `sio2man`, `mmceman` (if fileXio ready), `mcman`, `mcserv`, `padman`, `libsd`, `audsrv`.
  - Mass/USB stack when `init_mass_stack==1`: `usbd`, `ds34usb`, `ds34bt`, `bdm`, `bdmfs_fatfs`, `usbmass_bd`, `cdfs`.
  - MX4SIO early-only path (`BOOT_MX4SIO`): `mx4sio_bd`.
- Lazy/on-demand path outside main boot:
  - HDD stack from `src/luaHDD.cpp` `HDD.Initialize()`: `ps2dev9`, `ps2atad`, `ps2hdd-osd`, `ps2fs`.
  - MX4SIO from `src/luasystem.cpp` `System.initMX4SIO(...)`: loads `mx4sio_bd` and probes roots.
  - BDM query RPC from `src/luasystem.cpp`: loads `bdm_query.irx` lazily via `EnsureBdmQueryRpc()` when BDM listing APIs are called.

### Early waits / blocking loops tied to specific devices
- HDD/PFS-related risk mitigations:
  - Conditional skip of mass stack init on HDD/PFS boot (BOOT_HDD + boot source check).
  - HDD remount retries around `fileXioMount` (`mount`, optional `umount`, retry).
- Mass-device wait loop:
  - If boot root is `mass*`, loop up to 80 retries on `stat(wait_root)` before continuing.
- Global boot loops not device-specific but still blocking:
  - `SifIopReset`/`SifIopSync` loops under `RESET_IOP`.

---

## 3) IOP Module Inventory

### Embedded modules today (from Makefile IOP_MODULES + linked IRX blobs)
1. iomanX
2. fileXio
3. sio2man
4. mcman
5. mcserv
6. padman
7. libsd
8. usbd
9. audsrv
10. bdm
11. bdmfs_fatfs
12. usbmass_bd
13. cdfs
14. ds34bt
15. ds34usb
16. ps2dev9
17. ps2atad
18. ps2hdd-osd
19. ps2fs
20. mmceman
21. mx4sio_bd
22. bdm_query

### Classification
- **REQUIRED always (current runtime baseline):**
  - iomanX, fileXio, sio2man, mcman, mcserv, padman, libsd, audsrv.
- **REQUIRED only for USB/mass stack paths:**
  - usbd, bdm, bdmfs_fatfs, usbmass_bd.
- **REQUIRED only for HDD paths:**
  - ps2dev9, ps2atad, ps2hdd-osd, ps2fs.
- **REQUIRED only for MX4SIO paths:**
  - mx4sio_bd.
- **Likely peripheral/feature-specific (not strictly core launch path):**
  - cdfs (disc-related feature path), ds34usb, ds34bt, mmceman.
- **Possibly unused in normal UI flow unless explicit API used:**
  - bdm_query (loaded lazily only when BDM RPC APIs are invoked).

---

## 4) Boot Risk Assessment

### High-risk modules to load unnecessarily
- USB/mass stack (`usbd`, `bdm`, `bdmfs_fatfs`, `usbmass_bd`) on HDD/PFS boot contexts:
  - project comments and logic already identify deadlock/black-screen risk when over-initializing before graphics in HDD-launched contexts.
- HDD stack (`ps2dev9`, `ps2atad`, `ps2hdd-osd`, `ps2fs`) when not entering HDD path:
  - unnecessary for USB/MMCE/MX4SIO browsing and potentially adds blocking init cost.
- MX4SIO backend (`mx4sio_bd`) if not entering MX4SIO flow:
  - currently early-loaded only in BOOT_MX4SIO builds or via explicit runtime init.

### Safest locations for conditional loading
- Keep core minimal boot in `main.cpp` (graphics reachability first).
- Device-page entry handlers in Lua (`ui.lua`) and existing runtime APIs are safest trigger points:
  - MMCE page entry for MMCE-specific readiness checks.
  - MX4SIO page entry (`System.initMX4SIO`) for backend load/probe.
  - HDD page entry (`HDD.Initialize`) for HDD stack.
- Existing architecture already demonstrates this pattern for HDD and BDM query (lazy in runtime API).

---

## 5) Proposed Universal Strategy (Option A preparation)

### Converting compile-time variant behavior to runtime detection
- Keep a single binary embedding all needed IRX payloads.
- Replace compile-time variant branching intent with runtime decisions derived from:
  - parsed boot source (`boot_path`/`argv0`)
  - active page/device selection in UI
  - explicit device probes (already present for MMCE/MX4SIO/mass backend names).

### Lazy module-load approach
- Stage 1 (always-on minimal boot):
  - load only baseline modules required to reach graphics, input, Lua, filesystem basics.
- Stage 2 (on-demand per device/page):
  - load USB/mass stack only upon entering USB/mass-backed browsing paths.
  - load MX4SIO backend only upon entering MX4SIO path.
  - load HDD stack only upon entering HDD path.
- Stage 3 (auxiliary APIs):
  - keep optional RPC/helper IRX (e.g., bdm_query) lazy on first API use.

### Explicit universal policy target
- Do **not** initialize USB/MX4SIO/HDD stacks at startup unless required by current boot safety context.
- Do **not** load device-specific stacks unless entering that device path in UI or required to preserve boot from that device.
- Preserve the existing HDD safety principle: prioritize reaching `initGraphics()` without pre-graphics deadlock risk.

