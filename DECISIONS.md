Last updated: 2026-03-26

# DECISIONS

## Decision Log Format
Each entry records:
- Date (`YYYY-MM-DD`)
- Decision
- Rationale
- Implications
- Evidence

## Decision Log

### 2026-03-06 — Lua runtime is embedded-only at boot
- Decision: boot and required runtime Lua modules are loaded from embedded blobs, not loose filesystem Lua files.
- Rationale: deterministic startup and fewer layout-dependent failures.
- Implications: editing runtime Lua requires rebuilding the ELF.
- Evidence: `src/luaplayer.cpp`, `etc/boot.lua`, `Makefile`.

### 2026-03-06 — Settings persist as a transaction on Settings/Profile exit
- Decision: settings edits are staged in UI draft state and committed on confirm/leave.
- Rationale: avoid repeated writes while navigating and keep save/apply failure handling explicit.
- Implications: runtime/UI state sync must still happen if save/apply fails.
- Evidence: `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua`.

### 2026-03-26 — USB vs MX4SIO identity is authoritative by mount driver
- Decision: mounted mass roots are classified by driver identity, not by path spelling.
- Rationale: real hardware can expose both USB and MX4SIO through `mass*:/`.
- Implications: startup auto-init, boot-device labeling, and page list building must continue to use mount-driver queries.
- Evidence: `bin/POPSLDR/system.lua`, `src/luasystem.cpp`.

### 2026-03-26 — Runtime device locks are no longer enforced
- Decision: the old per-session device lock system is no longer an active runtime constraint.
- Rationale: device access should not be blocked by stale lock state.
- Implications: docs must not claim that switching devices requires restart; future changes must not silently reintroduce that gate.
- Evidence: `bin/POPSLDR/ui.lua` (`canEnterDevice`, `setDeviceLock`).

### 2026-03-26 — Startup backend initialization is path-driven
- Decision: startup backend auto-init considers boot paths and configured executable/profile paths, not just the page the user opens first.
- Rationale: a configured POPSTARTER/DKWDRV/profile path can require backend drivers before any device page is visited.
- Implications: startup docs and validation must cover boot source plus configured paths.
- Evidence: `bin/POPSLDR/system.lua` (`CollectStartupBackendTargets`, `AutoInitStartupBackends`).

### 2026-03-26 — PAL UI uses the same 640x448 raster layout as NTSC-authored UI assets
- Decision: PAL mode keeps the UI raster at `640x448` instead of stretching the authored layout vertically.
- Rationale: reduce PAL squish on menus and authored UI assets.
- Implications: final on-TV proportions still require hardware confirmation.
- Evidence: `bin/POPSLDR/system.lua`, `bin/POPSLDR/ui.lua`.

### 2026-03-26 — Release ZIP contract is strict and PATCH_5-based
- Decision: CI package includes exact `PS1_POPSLOADER/*` launcher files plus `POPS/PATCH_5.BIN`, and rejects legacy `POPS/*.tm2` payloads.
- Rationale: prevent release drift and ambiguous installation instructions.
- Implications: docs and workflow validation must stay synchronized.
- Evidence: `.github/workflows/compilation.yml`.

## Open Investigations
- HDD `POPSTARTER.ELF` when launcher/sidecar/CWD is on HDD:
  - current status: A fix has been implemented to resolve libc-related exceptions within the embedded loader (`loader.c`).
  - previous reported hardware result was a black-screen hang. Hardware verification of the fix is required.
- `BOOT.ELF` after HDD page init:
  - the last failed backend experiment was reverted in source,
  - current hardware status on that restored source is still `Unknown (verify on hardware)`.
- PAL asset proportions:
  - code compensates for PAL layout,
  - final display result still needs hardware confirmation.
