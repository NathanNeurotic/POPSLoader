# Device detection map (signals, flags, call sites)

## Boot-device detection (Lua, early runtime)
- **Boot path source:** `BOOT_PATH_RAW = System.currentDirectory()` in `system.lua` seeds boot device detection and APP_DIR normalization.【F:bin/POPSLDR/system.lua†L14-L77】
- **Prefix check + marker files:** `DetectBootDevice()` inspects the device prefix (`mmce`, `mx4sio`, `mass`) and uses marker files (`.boot_mx4sio`, `.boot_usb`) in `APP_DIR` to disambiguate USB vs MX4SIO for `mass:` boots.【F:bin/POPSLDR/system.lua†L119-L141】
- **Boot locks:** The result sets `UI.boot_device` and `UI.boot_locks` to prevent switching to incompatible device drivers in the same session.【F:bin/POPSLDR/system.lua†L261-L279】【F:bin/POPSLDR/ui.lua†L26-L41】

## MMCE detection
- **IOP init & readiness flags (C++):** `main.cpp` loads `mmceman` when `fileXio` is ready; on success, it defers probing by setting `mmce_slot0_ready = -1` and `mmce_slot1_ready = -1`, otherwise sets both to `0` (not ready).【F:src/main.cpp†L339-L368】
- **Lua globals:** `MMCE_SLOT0_READY` / `MMCE_SLOT1_READY` are exported to Lua in `luaSystem_init`.【F:src/luasystem.cpp†L1131-L1135】
- **Initial slot list:** `system.lua` consumes those globals to seed `PLDR.MMCE.SLOTS` and `PLDR.MMCE.PREFIX` before on-demand probing starts.【F:bin/POPSLDR/system.lua†L223-L235】
- **On-demand slot probe:** `PLDR.DetectMMCESlot()` checks for `mmce0:/` and `mmce1:/` directories, populates `PLDR.MMCE.SLOTS`, and selects `PLDR.MMCE.PREFIX`.【F:bin/POPSLDR/system.lua†L284-L305】
- **UI usage:** MMCE slot info is surfaced in the GSMB page and can be cycled with Triangle when multiple slots are present.【F:bin/POPSLDR/ui.lua†L244-L285】

## MX4SIO detection
- **Lua hint marker:** `DetectMX4SIOPrefixHint()` returns `mx4sio:/` when `.boot_mx4sio` exists in `APP_DIR`, and the hint is stored in `PLDR.MX4SIO.PREFIX_HINT`.【F:bin/POPSLDR/system.lua†L195-L216】
- **Lua API call:** UI triggers `System.initMX4SIO(hint)` when entering the MX4SIO page and updates `PLDR.MX4SIO.READY` / `PLDR.MX4SIO.ROOT` based on the result.【F:bin/POPSLDR/ui.lua†L410-L428】
- **C implementation:** `System.initMX4SIO` maps to `mx4sio_init_and_get_root`, which loads `mx4sio_bd.irx` and probes `mx4sio:/` or `mx4sio0:/` for a valid `POPS/` directory (the success condition).【F:src/luasystem.cpp†L125-L176】【F:src/luasystem.cpp†L976-L990】【F:src/luasystem.cpp†L1026-L1029】

## USB mass readiness
- **Preflight probe:** `main.cpp` loops on `stat("mass:/")` with retries to wait for USB readiness before booting Lua.【F:src/main.cpp†L396-L408】

## SMB networking
- **SMB Lua bindings exist** (`src/luaSMB.cpp`), but **the UI routes the "SMB" page to MMCE behavior** (GSMB scene). There is no explicit SMB device detection in the UI code path.
  - Evidence for GSMB → MMCE behavior: GSMB scenes call `PLDR.GetMMCESlots()` and use MMCE prefixes.【F:bin/POPSLDR/ui.lua†L244-L401】
  - SMB binding entrypoint: `src/luaSMB.cpp` defines SMB login logic and uses the `smb:` device path.【F:src/luaSMB.cpp†L1-L65】

## UNKNOWNs (not found in repo)
- **SMB device detection flow:** No UI-side logic explicitly detects SMB availability; if a separate SMB discovery path exists, it is UNKNOWN.
  - Suggested command: `rg -n "SMB|smb" bin/POPSLDR src`
