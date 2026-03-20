Last updated: 2026-03-20

# TRUTHSHEET

## Purpose
Non-negotiable behavioral invariants that changes must preserve unless an explicit migration is planned.

## Truths

### Truth 1: Boot/runtime Lua is embedded-only
- Scope: `src/luaplayer.cpp`, `etc/boot.lua`, `Makefile`.
- Rationale: deterministic startup and no dependency on external Lua script files.
- Verification: confirm embedded searcher install, disabled filesystem loaders, and the embedded script table for boot/runtime modules.

### Truth 2: Settings persistence is transactional and schema-backed
- Scope: `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua`, `bin/POPSLDR/pops_profiles.lua`.
- Rationale: avoid per-navigation writes and keep save/apply failure handling explicit.
- Verification: edits stage in drafts; `CommitSettingsChanges` runs on confirm or leave; persisted file is `mc0:/POPSTARTER/.pldrs`; schema currently includes profile, POPStarter path, BDMA mode, DKWDRV path, and video standard.

### Truth 3: USB vs MX4SIO identity comes from mount driver
- Scope: `bin/POPSLDR/system.lua`, `src/luasystem.cpp`.
- Rationale: root-name and path heuristics are insufficient across real device layouts.
- Verification: classification uses `System.getMassMountDriver`; `mx4` and `sdc` classify as MX4SIO.

### Truth 4: Probe and retry loops are bounded
- Scope: `bin/POPSLDR/system.lua`, `bin/POPSLDR/ui.lua`.
- Rationale: prevent frame stalls, hangs, and unpredictable timing behavior.
- Verification: USB and MX4SIO probe loops use finite attempt counts; no unbounded polling is introduced in current code paths.

### Truth 5: Launch failure feedback must be explicit
- Scope: `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua`.
- Rationale: the launcher must not fail silently on missing executables or failed launch handoff.
- Verification: missing POPStarter or DKWDRV paths produce notifications; guarded launch failure paths display user-visible error output.

### Truth 6: Build/package validation is CI-driven
- Scope: `.github/workflows/compilation.yml`, `Makefile`.
- Rationale: local PS2 SDK environments are unreliable, so build confidence must come from the workflow contract.
- Verification: CI runs `make clean elfloader all`, validates `etc/boot.lua`, assembles `POPSLOADER.zip`, and checks the manifest.

### Truth 7: Release package manifest is strict
- Scope: `.github/workflows/compilation.yml`.
- Rationale: prevent accidental release payload drift.
- Verification: CI enforces the exact expected ZIP set and rejects legacy `POPS/*.tm2` payload entries.

### Truth 8: Current cover art lookup is local-file based
- Scope: `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua`.
- Rationale: current runtime only knows how to load cover assets from nearby filesystem locations.
- Verification: non-HDD backends probe sidecar `<game>.png`; HDD probes `hdd0:__common/POPS/ART/<title>.png`.

## Current Code-Visible Limits
- `HDD (exFAT)` main-menu path is intentionally not implemented and currently reports `Not Implemented Yet`.
- `SMB (v1)` main-menu path is intentionally not implemented and currently reports `Not Implemented Yet`.
- `BUILD_INFO.txt` is optional runtime metadata. UI reads it if present, CI generates it during build, and current release packaging does not ship it.
- UI stores device-lock state, but current menu flow does not enforce switching restrictions through `canEnterDevice` or `OpenDeviceLock`.

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
