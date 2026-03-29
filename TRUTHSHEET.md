Last updated: 2026-03-29

# TRUTHSHEET

## Purpose
Non-negotiable behavioral invariants that changes must preserve unless an explicit migration is planned.

## Truths

### Truth 1: Boot/runtime Lua is embedded-only
- Scope: `src/luaplayer.cpp`, `etc/boot.lua`, `Makefile`.
- Rationale: deterministic startup and no dependency on external Lua script files.
- Verification: embedded searcher is installed, filesystem Lua loaders are disabled, and required runtime Lua blobs are embedded.

### Truth 2: Settings persistence is transactional
- Scope: `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua`.
- Rationale: avoid immediate writes while navigating and keep save/apply failure handling explicit.
- Verification: edits stage in drafts; `CommitSettingsChanges` runs on confirm/leave; persisted file is `mc0:/POPSTARTER/.pldrs`.

### Truth 3: USB vs MX4SIO identity comes from mount driver
- Scope: `bin/POPSLDR/system.lua`, `src/luasystem.cpp`.
- Rationale: root-name/path heuristics are insufficient across real device layouts.
- Verification: classification uses `System.getMassMountDriver`; `mx4`/`sdc` classify as MX4SIO.

### Truth 4: Startup backend auto-init is path-driven
- Scope: `bin/POPSLDR/system.lua`.
- Rationale: boot source alone is not enough; configured POPSTARTER/DKWDRV/profile paths can also require backend init before the first page visit.
- Verification: startup target collection uses boot paths plus configured executable/profile paths, then initializes USB/MMCE/MX4SIO/HDD as needed.

### Truth 5: Runtime device selection is not hard-locked
- Scope: `bin/POPSLDR/ui.lua`.
- Rationale: the old per-session device lock system was intentionally removed.
- Verification: `canEnterDevice()` always returns `true`, and `setDeviceLock()` is a no-op.

### Truth 6: Probe/retry loops are bounded
- Scope: `bin/POPSLDR/system.lua`, `bin/POPSLDR/ui.lua`.
- Rationale: prevent frame stalls/hangs and unpredictable behavior.
- Verification: backend probe loops and progress/report loops have finite attempt counts and fixed phases.

### Truth 7: Launch failure feedback must be explicit
- Scope: `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua`.
- Rationale: launcher must not fail silently on missing executables or returned launch handoffs.
- Verification: missing POPStarter/DKWDRV paths and launch return failures produce user-visible notifications/screens.

### Truth 8: Release package manifest is strict
- Scope: `.github/workflows/compilation.yml`.
- Rationale: prevent accidental release payload drift.
- Verification: CI enforces the exact expected ZIP set and rejects legacy `POPS/*.tm2` payload entries.

## Current Not-Implemented Truths
- `HDD (exFAT)` main-menu path is intentionally not implemented and must continue to report that status until feature work lands.
- `SMB (v1)` main-menu path is intentionally not implemented and must continue to report that status until feature work lands.

## Current Unresolved Hardware Markers
- `D-10`: HDD `POPSTARTER.ELF` on HDD sidecar/CWD is still reported to black-screen on hardware.
- `D-14`: non-HDD game + HDD-backed `POPSTARTER.ELF` is also still reported failing on hardware.
- `U-10`: `BOOT.ELF` after HDD page init is still a connected concern; the current conditional-reboot/cold-prep line remains `Unknown (verify on hardware)`.
- `U-06`: PAL/NTSC menu asset proportions still need hardware confirmation.

## Add-New-Truth Template
```markdown
Truth: <short invariant>
Scope: <components/files>
Rationale: <why this must remain true>
Verification: <test/check/manual steps>
Owner: <team/person>
Date added: YYYY-MM-DD
Related issue/decision: <id or link>
```
