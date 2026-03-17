Last updated: 2026-03-17

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
- Decision: boot and required Lua modules are loaded from embedded blobs, not filesystem Lua files.
- Rationale: deterministic startup and reduced dependency on external script layout.
- Implications: changing boot/runtime Lua behavior requires updating embedded sources and rebuild.
- Evidence: `src/luaplayer.cpp`, `etc/boot.lua`, `Makefile`.

### 2026-03-06 — Settings persist as a transaction on Settings/Profile exit
- Decision: settings edits are staged in UI draft state and committed on confirm/leave through commit flow.
- Rationale: avoids repeated writes while navigating options; preserves atomic save/apply semantics.
- Implications: per-button changes inside Settings should not write immediately to `.pldrs`.
- Evidence: `bin/POPSLDR/ui.lua` (`queue_exit`), `bin/POPSLDR/system.lua` (`CommitSettingsChanges`, `SaveSettingsAtomic`).

### 2026-03-06 — Mount-driver identity is authoritative for USB vs MX4SIO split
- Decision: classify mounted mass roots by mount-driver (`getMassMountDriver`) where `mx4`/`sdc` means MX4SIO.
- Rationale: path-prefix heuristics alone are not reliable when devices expose `mass*:/` roots.
- Implications: list building and scene behavior must continue to consume classified roots, not guessed roots.
- Evidence: `bin/POPSLDR/system.lua` (`ClassifyMassRootDriver`, `BuildMassRootIdentity`), `src/luasystem.cpp` (`lua_get_mass_mount_driver`).

### 2026-03-06 — `mc?:/` path alias is supported for executable resolution
- Decision: configured paths using `mc?:/` are expanded to `mc0:/` then `mc1:/` during probe/launch checks.
- Rationale: improves compatibility across consoles/cards without requiring manual path rewrites.
- Implications: POPStarter and DKWDRV path validation must continue using alias-expansion helpers.
- Evidence: `bin/POPSLDR/system.lua` (`ExpandMcAlias`, `ResolveFirstExistingPath`, `ResolvePathWithEnsure`), `bin/POPSLDR/ui.lua` (DKWDRV launch modal).

### 2026-03-06 — Release ZIP contract is strict and PATCH_5-based
- Decision: CI package includes exact `PS1_POPSLOADER/*` launcher files plus `POPS/PATCH_5.BIN` and rejects legacy `POPS/*.tm2` entries.
- Rationale: avoid packaging drift and guarantee predictable release payload.
- Implications: packaging changes require synchronized updates to workflow validation logic.
- Evidence: `.github/workflows/compilation.yml`.

### 2026-03-06 — Device-family lock is enforced per session
- Decision: once a device family is selected/locked in session (or constrained by boot source), incompatible family transitions are blocked with UI feedback.
- Rationale: prevents unstable runtime state from mixing already-loaded driver paths in one session.
- Implications: cross-family switching requires restart.
- Evidence: `bin/POPSLDR/ui.lua` (`DEVLOCK`, `canEnterDevice`, lock modal), `bin/POPSLDR/system.lua` (`DetectBootDevice` lock setup).

## Pending Decisions
- ART system design (source of truth, cache policy, fallback policy).
- SMB feature implementation contract (launcher handoff, error UX, storage assumptions).
- HDD exFAT feature model and relationship to existing BDMA settings.
