## AI Docs
Last updated: 2026-03-20

### Purpose
Operational guidance for AI agents working in this repository.

### Source-of-Truth Rule
- Prefer verified claims tied to repository code, build scripts, workflow files, and explicit user/project policy.
- If a claim cannot be proven from repository sources or task instructions, mark it as `Unknown (verify on hardware)`.
- For behavior claims, cite at least one concrete file path in task output.

### CI-First Validation
- GitHub Actions CI is the authoritative build/package validation path for this repository.
- Local PS2 SDK builds are best-effort only and must not be treated as proof that a change is valid.
- When discussing build compatibility, align claims with `Makefile` and `.github/workflows/compilation.yml`.
- Current CI contract includes:
  - `ps2dev/ps2dev:latest` container build environment,
  - `make clean elfloader all`,
  - `etc/boot.lua` newline/syntax validation,
  - release ZIP assembly for `PS1_POPSLOADER/*` plus `POPS/PATCH_5.BIN`,
  - exact manifest verification and rejection of legacy `POPS/*.tm2` entries.

### Scope
- Allowed: task-focused edits to requested files.
- Allowed: documentation, tests, and narrow fixes directly tied to the active task.
- Avoid touching unrelated Lua/C/C++ files unless required by task scope.
- Preserve boot/launch and storage detection pipelines unless the task explicitly targets them.

### High-Risk Surfaces
Changes in these files can break core behavior and require extra care:
- `bin/POPSLDR/system.lua`
- `bin/POPSLDR/ui.lua`
- `src/main.cpp`
- `src/luasystem.cpp`
- `src/luaplayer.cpp`
- `Makefile`
- `.github/workflows/compilation.yml`

### Current Repo-Specific Notes
- `VIDEO_STANDARD` is part of the persisted settings schema alongside profile, POPStarter path, BDMA mode, and DKWDRV path.
- `bin/POPSLDR/ui.lua` can display a build stamp from `BUILD_INFO.txt` or `POPSLDR/BUILD_INFO.txt` if the file exists.
- CI currently generates `bin/POPSLDR/BUILD_INFO.txt` before compile, but the release ZIP assembled in `.github/workflows/compilation.yml` does not copy that file into `POPSLOADER.zip`.
- Internal scene name `GSMB` is currently reused for the MMCE game list flow; the user-facing `SMB (v1)` main-menu option is still not implemented.
- UI state includes `boot_device`, `boot_locks`, and `device_lock`, but the current menu flow does not call `canEnterDevice` or `OpenDeviceLock` to block navigation.

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
- Build/package correctness should be described in CI terms, not local toolchain terms.
- Hardware-only behavior should be tracked in `QA_REGRESSION_MATRIX.md` and marked if unverified.

### Documentation Expectations
When updating docs:
- Remove stale claims that are not backed by current code or workflow.
- Keep status pages (`STATE.md`, `ROADMAP.md`, `DECISIONS.md`) consistent with each other.
- Keep invariant pages (`RULES.md`, `TRUTHSHEET.md`) aligned with actual runtime behavior.
- Do not document dormant helpers as active behavior unless code paths actually call them.
- Treat legacy internal names (`GSMB`, `GBDMHDD`, etc.) as implementation details unless the user-facing behavior matches.

### Communication Format
Use this report structure in task responses:
- Summary: what changed and why.
- Diffstat: file-level change summary.
- Diff: key hunks or full patch when requested.
- Test plan: what was run, what passed/failed, and what was not run.
