## AI Docs
Last updated: 2026-03-17

### Purpose
Operational guidance for AI agents working in this repository.

### Source-of-Truth Rule
- Prefer verified claims tied to repository code, build scripts, and workflow files.
- If a claim cannot be proven from repository sources, mark it as `Unknown (verify on hardware)`.
- For behavior claims, cite at least one concrete file path in task output.

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
- Remove stale claims that are not backed by current code.
- Keep status pages (`STATE.md`, `ROADMAP.md`, `DECISIONS.md`) consistent with each other.
- Keep invariant pages (`RULES.md`, `TRUTHSHEET.md`) aligned with actual runtime behavior.

### Communication Format
Use this report structure in task responses:
- Summary: what changed and why.
- Diffstat: file-level change summary.
- Diff: key hunks or full patch when requested.
- Test plan: what was run, what passed/failed, and what was not run.
