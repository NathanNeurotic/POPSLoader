# Device detection map (signals, flags, call sites)

## Authoritative mass-device classification order
1. **IOCTL/RPC-first (authoritative):** `System.classifyMassDevice(pathHint, appDirHint)` calls the existing BDM RPC query path and classifies returned driver metadata to `USB`, `MX4SIO`, or `UNKNOWN`, including `port`/`index` when available.
2. **Prefix short-circuit:** explicit `mx4sio*:` prefixes classify as `MX4SIO`; `mmce*:` remains outside this mass-classifier path because MMCE uses separate slot detection.
3. **Marker fallback (non-blocking):** when RPC metadata is missing/ambiguous, `.boot_mx4sio` / `.boot_usb` markers in app dir are used to preserve existing behavior.
4. **Final fallback:** return `UNKNOWN` and continue safely (no boot/device-page hard failure).

## Boot-device detection (Lua, early runtime)
- `DetectBootDevice()` now uses a single classifier helper (`ClassifyMassDevice()` -> `System.classifyMassDevice`) for mass-family decisions.
- Boot locks (`UI.boot_device`, `UI.boot_locks`) are still applied the same way, with extra classifier metadata in logs.

## Launch/page routing detection use
- `ResolveLaunchPolicy()` now uses the same classifier for mass-family paths instead of separate hardcoded mass/mx4sio checks.
- MMCE and HDD routing remain explicit and unchanged.

## MMCE detection
- MMCE still relies on readiness globals and `PLDR.DetectMMCESlot()` probing (`mmce0:/`, `mmce1:/`), separate from the mass classifier.

## TODO: verify (low-level ID mapping)
- Verify exact BDM driver-name mapping (`bdm_dev_info.name`) used to classify USB vs MX4SIO against `iop/bdm_query/bdm_query.c` (`bd->name` copy) and ps2sdk BDM headers/contract.
- Verify whether `parNr` always maps to user-visible `massN:` index and `devNr` to physical port on all supported BDM drivers/hardware.
