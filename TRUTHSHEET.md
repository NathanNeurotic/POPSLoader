Last updated: 2026-05-25

# TRUTHSHEET

## Purpose
Non-negotiable behavioral invariants that changes must preserve unless an explicit migration is planned.

## Truths

### Truth 1: Boot/runtime Lua is embedded-only
- Scope: `src/luaplayer.cpp`, `etc/boot.lua`, `Makefile`.
- Rationale: deterministic startup and no dependency on external Lua script files.
- Verification: embedded searcher is installed, filesystem Lua loaders are disabled, and required runtime Lua blobs are embedded.

### Truth 2: Settings persistence is transactional and per-device
- Scope: `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua`.
- Rationale: avoid immediate writes while navigating, keep save/apply failure handling explicit, and let a POPSLoader install carry its own settings (not always to Memory Card).
- Verification: edits stage in drafts; `CommitSettingsChanges` runs on confirm/leave; `PLDR.SETTINGS_PATH` is resolved at load time -- `APP_DIR_LOCAL/.pldrs` sidecar preferred (HDD installs land at `pfs1:/<install dir>/.pldrs` because `etc/boot.lua` mounts the boot partition RW by default), with `mc0:/POPSTARTER/.pldrs` as fallback. Save writes go to whichever was loaded.

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

## Current Hardware Status Markers
- `D-10` (HDD POPSTARTER + HDD game): **PASS** as of 2026-05-22 hardware (B2 fix at commit `4ae6679`). Must be preserved by any future launch-path change.
- `D-14` (HDD POPSTARTER + non-HDD game): **PASS** as of 2026-05-22 hardware. Same partition-aware route as D-10.
- `D-15` (non-HDD POPSTARTER + HDD game): **PASS** as of 2026-05-22 hardware.
- `DKWDRV from MC`: **PASS** as of 2026-05-25 hardware (Nuno).
- `DKWDRV from HDD custom path`: **Hardware pending** on PR #460 (V2-mimicry, commit `740fa87`); previous PR #458 attempt FAILED 2026-05-25.
- `BOOT.ELF from USB-booted POPSLoader` (L-07): V2 working route restored by PR #460. Hardware pending re-verification.
- `BOOT.ELF from HDD-booted POPSLoader` (U-10): **FAIL** 2026-05-25 (Nuno). Long-standing, not addressed by current PRs. Pursued only after PR #460 verdict settles.
- `POPSLoader from wLaunchELF`: **FAIL** on some wLE builds (CosmicScale 2026-05-25). PR #458's fileXio-teardown in `_ps2sdk_memory_init` targets this. Hardware pending.
- `U-06` (PAL/NTSC menu asset proportions): Unknown, still needs hardware confirmation.

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
