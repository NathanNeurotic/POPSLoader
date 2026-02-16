# Device detection map (signals, flags, call sites)

## Authoritative mass-device classification order
1. **Prefix check:** `System.classifyMassDevice(pathHint, appDirHint, allowRpcLoad)` short-circuits explicit prefixes (`mx4sio*` => `MX4SIO`, `mmce*` => `UNKNOWN` for this mass-classifier API).【F:src/luasystem.cpp†L377-L384】
2. **RPC metadata (optional):** when `allowRpcLoad=true`, classifier can load/bind `bdm_query` RPC and classify from BDM driver metadata (`name`, `devNr`, `parNr`).【F:src/luasystem.cpp†L48-L89】【F:src/luasystem.cpp†L391-L411】
3. **Marker fallback:** `.boot_mx4sio` / `.boot_usb` in app dir are used if RPC data is unavailable/incomplete.【F:src/luasystem.cpp†L413-L425】
4. **Final fallback:** return `UNKNOWN` without hard failure.【F:src/luasystem.cpp†L428-L429】

## USB root discovery + fallback policy
- **Primary goal:** USB content is resolved from potentially multiple `mass*:/POPS/` roots (not a single global root).【F:bin/POPSLDR/system.lua†L639-L757】
- **Classifier-assisted scan:** runtime iterates candidate `massN:/` roots and includes those classified as `USB` by `ClassifyMassDevice`.【F:bin/POPSLDR/system.lua†L647-L652】
- **RPC metadata enrichment:** when available, `System.bdmList()` contributes additional `massN:/` roots via metadata index values to improve coverage.【F:bin/POPSLDR/system.lua†L642-L666】
- **Fallback when classifier/RPC data is unavailable:** runtime probes known roots (`mass0:/`..`mass8:/`) for existing `POPS/` folders and merges any positives; partial results are valid and should still be shown in UI.【F:bin/POPSLDR/system.lua†L621-L637】【F:bin/POPSLDR/system.lua†L668-L757】

## Boot/device routing policy (current)
- Lua `ClassifyMassDevice()` calls `System.classifyMassDevice(pathHint, APP_DIR_LOCAL, false)` to keep boot and UI routing non-blocking and avoid module autoload during sensitive early runtime on hardware.【F:bin/POPSLDR/system.lua†L120-L129】
- `DetectBootDevice()` and `ResolveLaunchPolicy()` both use that single helper (plus explicit MMCE/HDD scene logic), so mass-family decisions share one source of truth while preserving compatibility fallback behavior.【F:bin/POPSLDR/system.lua†L131-L151】【F:bin/POPSLDR/system.lua†L1261-L1290】

## TODO: verify
- Verify whether enabling `allowRpcLoad=true` for boot-time classification is safe across all PS2 hardware/device combinations (potential startup stability impact). Confirm in `src/luasystem.cpp` RPC bind/load path and IRX/module init ordering in `src/main.cpp`.【F:src/luasystem.cpp†L48-L89】【F:src/main.cpp†L327-L379】
- **TODO: verify:** BDM classification contract details (`class`, `driver`, `port`, `index` and how they map to `massN:/`) are still provisional; confirm behavior at the producer/consumer boundaries in `src/luasystem.cpp` and `iop/bdm_query/bdm_query.c` before enforcing stricter matching logic.【F:src/luasystem.cpp†L186-L223】【F:src/luasystem.cpp†L359-L429】【F:iop/bdm_query/bdm_query.c†L45-L65】
- Verify exact BDM driver-name mapping contract for USB vs MX4SIO (`bdm_dev_info.name`) against `iop/bdm_query/bdm_query.c` + ps2sdk BDM headers before tightening matching rules.【F:iop/bdm_query/bdm_query.c†L54-L59】【F:src/luasystem.cpp†L282-L285】
- Verify `devNr`/`parNr` semantics (port/index mapping) across drivers/hardware; current metadata exposure is best-effort only.【F:iop/bdm_query/bdm_query.c†L57-L59】【F:src/luasystem.cpp†L406-L411】
