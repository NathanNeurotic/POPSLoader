Last updated: 2026-03-20

# DECISIONS

## Decision Log Format
Each entry records:
- Date (`YYYY-MM-DD`)
- Decision
- Rationale
- Implications
- Evidence

## Decision Log

### 2026-03-20 — GitHub Actions CI is the authoritative build/package validator
- Decision: treat `.github/workflows/compilation.yml` as the required validation path for build and package correctness.
- Rationale: local PS2 SDK environments are unreliable, while the workflow defines the actual supported build contract.
- Implications: local build results are advisory; build/package claims should be phrased in CI terms.
- Evidence: `.github/workflows/compilation.yml`, `Makefile`.

### 2026-03-20 — Lua runtime is embedded-only at boot
- Decision: boot and required Lua modules are loaded from embedded blobs, not filesystem Lua files.
- Rationale: deterministic startup and reduced dependency on external script layout.
- Implications: changing boot/runtime Lua behavior requires updating embedded sources and rebuilding.
- Evidence: `src/luaplayer.cpp`, `etc/boot.lua`, `Makefile`.

### 2026-03-20 — Settings persist as a transaction on Settings/Profile exit
- Decision: settings edits are staged in UI draft state and committed on confirm or leave through commit flow.
- Rationale: avoids repeated writes while navigating options and preserves atomic save/apply semantics.
- Implications: per-button changes inside Settings should not write immediately to `.pldrs`; persisted schema changes must update both load and save paths.
- Evidence: `bin/POPSLDR/ui.lua` (`queue_exit`), `bin/POPSLDR/system.lua` (`CommitSettingsChanges`, `SaveSettingsAtomic`, `LoadSettingsNonFatal`).

### 2026-03-20 — Persisted settings schema includes video standard and DKWDRV path
- Decision: persisted settings are not limited to profile and POPStarter path; they also include BDMA mode, DKWDRV path, and video standard.
- Rationale: docs and tooling need to reflect the current serialized settings format.
- Implications: settings migrations must preserve these keys or document intentional changes.
- Evidence: `bin/POPSLDR/system.lua` (`EncodeSettings`, `LoadSettingsNonFatal`, `ApplyVideoStandardRuntime`).

### 2026-03-20 — Mount-driver identity is authoritative for USB vs MX4SIO split
- Decision: classify mounted mass roots by mount driver, where `mx4` or `sdc` means MX4SIO.
- Rationale: path-prefix heuristics alone are not reliable when devices expose `mass*:/` roots.
- Implications: list building and scene behavior must continue to consume classified roots, not guessed roots.
- Evidence: `bin/POPSLDR/system.lua` (`ClassifyMassRootDriver`, `BuildMassRootIdentity`), `src/luasystem.cpp` (`lua_get_mass_mount_driver`).

### 2026-03-20 — `mc?:/` path alias is supported for executable resolution
- Decision: configured paths using `mc?:/` are expanded to `mc0:/` then `mc1:/` during probe and launch checks.
- Rationale: improves compatibility across consoles and cards without requiring manual path rewrites.
- Implications: POPStarter and DKWDRV path validation must continue using alias-expansion helpers.
- Evidence: `bin/POPSLDR/system.lua` (`ExpandMcAlias`, `ResolveFirstExistingPath`, `ResolvePathWithEnsure`), `bin/POPSLDR/ui.lua` (DKWDRV launch modal).

### 2026-03-20 — Release ZIP contract is strict and PATCH_5-based
- Decision: CI package includes exact `PS1_POPSLOADER/*` launcher files plus `POPS/PATCH_5.BIN` and rejects legacy `POPS/*.tm2` entries.
- Rationale: avoid packaging drift and guarantee a predictable release payload.
- Implications: packaging changes require synchronized updates to workflow validation logic and docs.
- Evidence: `.github/workflows/compilation.yml`.

### 2026-03-20 — Credits build stamp is optional metadata, not a packaged release file
- Decision: UI supports a build stamp from `BUILD_INFO.txt` when present, but the current release ZIP does not ship that file.
- Rationale: this matches the current workflow and avoids overstating release contents.
- Implications: if release-visible build stamps are desired, packaging must be updated intentionally.
- Evidence: `bin/POPSLDR/ui.lua` (`LoadBuildInfo`), `.github/workflows/compilation.yml`.

### 2026-03-20 — Internal `GSMB` scene name does not imply implemented SMB support
- Decision: keep documentation explicit that `GSMB` is a legacy internal scene name currently reused for MMCE list flow.
- Rationale: current code would otherwise be easy to misread as working SMB support.
- Implications: docs should separate internal scene naming from user-facing feature status.
- Evidence: `bin/POPSLDR/ui.lua` (MMCE menu entry transitions to `UI.SCENES.GSMB`; SMB menu entry reports `Not Implemented Yet`).

## Pending Decisions
- Whether `BUILD_INFO.txt` should be packaged into release artifacts.
- Broader cover-art system design beyond current local PNG lookup.
- SMB feature implementation contract (launcher handoff, error UX, storage assumptions).
- HDD exFAT feature model and relationship to existing BDMA settings.
