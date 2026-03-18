Last updated: 2026-03-17

# TRUTHSHEET

## Purpose
Non-negotiable behavioral invariants that changes must preserve unless an explicit migration is planned.

## Truths

### Truth 1: Boot/runtime Lua is embedded-only
- Scope: `src/luaplayer.cpp`, `etc/boot.lua`, `Makefile`.
- Rationale: deterministic startup and no dependency on external Lua script files.
- Verification: confirm embedded searcher install + disabled filesystem loaders + embedded script table includes boot/runtime scripts.

### Truth 2: Settings persistence is transactional
- Scope: `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua`.
- Rationale: avoid per-navigation writes and keep save/apply failure handling explicit.
- Verification: edits stage in drafts; `CommitSettingsChanges` runs on confirm/leave; persisted file is `mc0:/POPSTARTER/.pldrs`.

### Truth 3: USB vs MX4SIO identity comes from mount driver
- Scope: `bin/POPSLDR/system.lua`, `src/luasystem.cpp`.
- Rationale: root-name/path heuristics are insufficient across real device layouts.
- Verification: classification uses `System.getMassMountDriver`; `mx4`/`sdc` classify as MX4SIO.

### Truth 4: Probe/retry loops are bounded
- Scope: `bin/POPSLDR/system.lua`, `bin/POPSLDR/ui.lua`.
- Rationale: prevent frame stalls/hangs and unpredictable behavior.
- Verification: MX4SIO and backend probe loops have finite attempt counts; no unbounded polling introduced.

### Truth 5: Launch failure feedback must be explicit
- Scope: `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua`.
- Rationale: launcher must not fail silently on missing executables or launch handoff issues.
- Verification: missing POPStarter/DKWDRV paths and launch return failures produce user-visible notifications/screens.

### Truth 6: Release package manifest is strict
- Scope: `.github/workflows/compilation.yml`.
- Rationale: prevent accidental release payload drift.
- Verification: CI enforces exact expected ZIP set and rejects legacy `POPS/*.tm2` payload entries.

### Truth 7: Cover art is path-source-dependent
- Scope: `bin/POPSLDR/ui.lua` (`BuildCoverCandidates`, `CoverCache`).
- Rationale: art source differs by backend; sidecar `.png` works for all mass/MMCE/MX4SIO paths, while HDD PFS requires looking up `hdd0:__common/POPS/ART/<title>.png`.
- Verification: non-HDD scenes use sidecar path (`<vcd-path>.png`); HDD (PFS) game-list scene (internal constant `UI.SCENES.GHDD`) uses `PLDR.ResolveHddPartitionReadablePath("hdd0:__common", "POPS/ART/...")`.

## Current Not-Implemented Truths
- `HDD (exFAT)` main-menu path is intentionally not implemented and must continue to report that status until feature work lands.
- `SMB (v1)` main-menu path is intentionally not implemented and must continue to report that status until feature work lands.

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
