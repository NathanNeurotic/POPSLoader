# Architecture

This document reflects the current POPSLoader architecture as implemented in the codebase.

## Startup flow (EE entrypoint → Lua boot)
- Optional IOP reset is performed only when `RESET_IOP` is defined (`SifIopReset`/`SifIopSync`).【F:src/main.cpp†L262-L267】
- IOP module init order for MMCE support is: `iomanX` → `fileXio` (and `fileXioInit`) → `mmceman`; MMCE slots are probed after `mmceman` loads successfully.【F:src/main.cpp†L279-L313】
- `APP_DIR` is derived from the launch path (`argv[0]`) via `setAppDirFromPath`, with `boot_path` fallback when no argv is provided.【F:src/main.cpp†L363-L368】
- A USB readiness preflight probes `mass:/` (stat loop with retries).【F:src/main.cpp†L350-L361】
- The embedded Lua boot script (`etc/boot.lua`) sets `package.path` and loads the resolved `system.lua` (APP_DIR first, legacy `POPSLDR/` fallback).【F:etc/boot.lua†L1-L11】【F:etc/boot.lua†L72-L81】

## UI flow (scenes and device pages)
- The main menu defines three device slots (`USB`, `SMB`, `HDD`); the `SMB` slot is wired to the MMCE device page and uses MMCE slot discovery/selection rather than SMB networking.【F:bin/POPSLDR/ui.lua†L261-L307】
- MMCE slot detection is driven by `mmce0:/` and `mmce1:/` availability (populated into `PLDR.MMCE.SLOTS`).【F:bin/POPSLDR/system.lua†L116-L127】

## Launch pipeline reference
- POPStarter launch rules (device detection, prefix rules, argv handoff) are documented in `docs/LAUNCH_PIPELINE.md` and should be treated as canonical.

## Exit path (UI → OSDSYS)
- Triangle opens an exit confirmation modal; confirming calls `System.exitToBrowser()` to return to OSDSYS.【F:bin/POPSLDR/ui.lua†L94-L168】
