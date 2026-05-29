## AI Docs
Last updated: 2026-05-28 (post-BETA-10-5)

### Purpose
Operational guidance for AI agents working in this repository.

### Source-of-Truth Rule
- Prefer claims tied to current repository files, workflow definitions, and recorded hardware outcomes in `QA_REGRESSION_MATRIX.md`.
- If a hardware/runtime claim cannot be proven from code or a recorded run result, mark it as `Unknown (verify on hardware)`.
- Separate repo-verified facts from hardware-reported results in task output.

### Scope
- Allowed: task-focused edits to requested files.
- Allowed: documentation, tests, and narrow fixes directly tied to the active task.
- Avoid touching unrelated Lua/C/C++ files unless required by task scope.
- Preserve boot/launch and storage detection pipelines unless the task explicitly targets them.

### High-Risk Surfaces
Changes in these files can break core behavior and require extra care:
- `bin/POPSLDR/system.lua` (LaunchEngine, RunPOPStarterGame, ResolveBootContext, classify_mass_boot, AutoInitStartupBackends, EnsureMmceReadyOnce)
- `bin/POPSLDR/ui.lua` (LaunchSelectedGame, LaunchBootElf, OpenDKWDRV)
- `src/main.cpp` (detectBootDeviceHintFromArgv0, parseLaunchArgs, eager IRX load order, conditional mmceman)
- `src/luasystem.cpp` (lua_loadELF*, EnsureBDM*, EnsureMmceman, lua_mx4sio_init with mandatory EnsureUsbMass-first ordering, getMassMountDriver)
- `src/luaplayer.cpp`
- `src/elf_loader/src/elf.c` (LoadELFFromFile*, ExecuteViaEmbeddedLoader, ExecuteHddBackedViaEmbeddedLoader, LoadELFFromFileWithPartition)
- `src/elf_loader/src/loader/src/loader.c` (BRAM child loader; HDD partition-context branch must preserve B2 dynamic PFS unmount)
- `etc/boot.lua` (pfs1: boot mount normalization)
- `Makefile`
- `.github/workflows/compilation.yml`
- `.github/workflows/rolling-release.yml` (added post-release; publishes to canonical rolling-release tag)

### Change Discipline
- Keep diffs minimal and localized.
- One objective per branch/PR when feasible.
- No drive-by refactors or formatting churn.
- Do not rename or move files unless required.
- Prefer additive and reversible changes.

### Safety Rules
- Never run destructive commands (`rm -rf`, `git reset --hard`, force-push) without explicit instruction.
- Do not overwrite user-authored changes outside task scope.
- Pause and report if unexpected repository changes appear during work.
- Avoid adding new runtime logging unless explicitly requested.

### Testing Expectations
- Choose the smallest test plan that can prove the change.
- Docs-only changes: run lightweight sanity checks when available; otherwise note `not run`.
- Runtime/build changes: run targeted checks first, then broader checks only if risk requires.
- Hardware-only behavior should be tracked in `QA_REGRESSION_MATRIX.md` and marked if unverified.

### Documentation Expectations
When updating docs:
- Keep `README.md`, `STATE.md`, `ROADMAP.md`, `DECISIONS.md`, `TRUTHSHEET.md`, and `QA_REGRESSION_MATRIX.md` synchronized.
- Treat `QA_REGRESSION_MATRIX.md` as the detailed hardware/CI run ledger; other root docs should summarize the stable current state and constraints instead of duplicating every experiment.
- D-10 / D-14 / D-15 / DKWDRV-MC / BOOT.ELF-USB-booted are **preservation contracts** hardware-confirmed in BETA-10-5 — write them that way, not as open failures.
- Post-release PR work (#470, #472, #473, #471 DRAFT) is `Unknown (verify on hardware)` unless a tester result is recorded in `QA_REGRESSION_MATRIX.md`.
- BETA-10-5 changelog entries should not be retroactively edited; new work goes in `[Unreleased]` at the top of `bin/changelog`.
- Remove stale branch names, stale feature claims, and outdated decisions.
- Do not silently carry forward old "fixed" claims when the only evidence is a prior chat report.
- If a regression was reported on hardware, record that result explicitly.

### Communication Format
Use this report structure in task responses:
- Summary: what changed and why.
- Diffstat: file-level change summary.
- Diff: key hunks or full patch when requested.
- Test plan: what was run, what passed/failed, and what was not run.
