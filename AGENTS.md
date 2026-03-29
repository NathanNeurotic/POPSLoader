## AI Docs
Last updated: 2026-03-29

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
- `bin/POPSLDR/system.lua`
- `bin/POPSLDR/ui.lua`
- `src/main.cpp`
- `src/luasystem.cpp`
- `src/luaplayer.cpp`
- `src/elf_loader/src/elf.c`
- `Makefile`
- `.github/workflows/compilation.yml`

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
- Keep `README.md`, `STATE.md`, `ROADMAP.md`, `DECISIONS.md`, and `QA_REGRESSION_MATRIX.md` synchronized.
- Treat `QA_REGRESSION_MATRIX.md` as the detailed hardware/CI run ledger; other root docs should summarize the stable current state and constraints instead of duplicating every experiment.
- Remove stale branch names, stale feature claims, and outdated decisions.
- Do not silently carry forward old “fixed” claims when the only evidence is a prior chat report.
- If a regression was reported on hardware, record that result explicitly.

### Communication Format
Use this report structure in task responses:
- Summary: what changed and why.
- Diffstat: file-level change summary.
- Diff: key hunks or full patch when requested.
- Test plan: what was run, what passed/failed, and what was not run.
