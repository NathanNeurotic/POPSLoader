Last updated: 2026-03-05

# ARCHITECTURE

## Verified module boundaries
- **Boot/runtime entry**
  - `src/main.cpp`: initializes runtime/IOP services and executes `boot.lua`.
  - `etc/boot.lua`: boot-path handling, font init, then `require("system")`.
- **Lua orchestration and UI**
  - `bin/POPSLDR/system.lua`: backend init, storage classification, game discovery, launch policy, settings load/save, BDMA apply.
  - `bin/POPSLDR/ui.lua`: scene management, input handling, settings/profile interactions, labels and icon drawing.
  - `bin/POPSLDR/images.lua`: image asset loading/registry used by UI.
  - `bin/POPSLDR/pops_profiles.lua`: POPStarter profile definitions.
- **Native backend/system bindings**
  - `src/luasystem.cpp`: Lua `System.*` bindings, mass mount-driver query/classification support, module init wrappers.
  - `iop/bdm_query/bdm_query.c`: backend driver query RPC support used by mass backend detection.
- **Embedded assets/build packaging**
  - `src/embed_assets.cpp` + generated `src/assets/*.c`: embedded Lua/assets used at runtime.
  - `Makefile` and `.github/workflows/compilation.yml`: build and release artifact packaging.

## High-level data flows
1. **Boot -> load settings -> apply runtime defaults -> UI entry**
   - `main.cpp` runs `boot.lua`.
   - `boot.lua` requires `system.lua`.
   - `system.lua` executes `PLDR.LoadSettingsNonFatal()` before entering the UI loop.
2. **Settings edit -> adjust -> confirm/leave -> save -> reflected labels**
   - UI profile/settings scene stages changes in memory (`UI.ProfileDirty`, `UI.BdmaDirty`).
   - On exit/confirm, `queue_exit` writes settings with `PLDR.SaveSettingsAtomic()` and applies BDMA if changed.
   - Initial UI BDMA selector index is derived from loaded `PLDR.BDMA_MODE_KEY`.
3. **Device identity pipeline (USB vs MX4SIO)**
   - Lua asks `System.getMassMountDriver(root)` (or fallback driver query paths).
   - Classification uses mount-driver identity; `sdc` (`mx4sio` in native classifier) maps to MX4SIO.
   - USB lists and MX4SIO lists are built from separated root sets.

## Non-goals / guardrails
- No unbounded loops or retries in backend/device probing.
- Avoid debug/logging additions in production paths.
- Do not guess device identity when mount driver is unknown.

## Unknown (verify)
- Exact on-device timing behavior for MX4SIO first-entry masking with explicit ~1s delay is not fully codified in `system.lua`; current retry state machine exists but may not match target UX timing.
- ART pipeline integration boundaries are not implemented yet (verify when feature lands).
