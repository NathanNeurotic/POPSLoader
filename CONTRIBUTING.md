Last updated: 2026-03-17

# CONTRIBUTING

## Purpose
Practical contributor workflow for POPSLoader changes.

## Branch and PR Expectations
- Keep branches short-lived and task-focused.
- Prefer one objective per PR.
- If a change touches unrelated concerns (runtime + packaging + docs), split into separate PRs when feasible.
- PR description should include:
  - problem statement,
  - scope,
  - behavioral risk,
  - validation performed,
  - hardware coverage gaps (if any).

## Commit Discipline
- One logical task per commit.
- Use imperative commit messages.
- Keep diffs minimal and localized.
- Avoid unrelated formatting/refactors.

## Development Guardrails
- Preserve these unless your task explicitly changes them:
  - embedded-Lua boot flow,
  - settings transaction behavior,
  - mount-driver based USB/MX4SIO classification,
  - release package manifest contract.
- Do not add unbounded retries/poll loops in runtime paths.
- Avoid adding runtime logging unless requested.

## Validation Expectations

### Docs-only changes
- Run light sanity checks if available.
- If no doc tooling is available, note `not run`.

### Runtime/build changes
- Run targeted checks first (for touched path).
- Run broader build/package checks only when risk requires.
- For storage or launch behavior, include manual verification steps.

### Hardware-sensitive behavior
- Use `QA_REGRESSION_MATRIX.md` IDs in test notes.
- Mark untested hardware scenarios explicitly as `Unknown (verify on hardware)`.

## Good Bug Reports
Include:
- expected behavior,
- actual behavior,
- repro steps,
- environment (console model/storage/backend/layout),
- affected feature area (USB/MMCE/MX4SIO/HDD/DKWDRV/settings/launch).

## Review Checklist
- Scope is narrow and task-aligned.
- Core invariants are preserved or intentionally migrated.
- Failure paths remain explicit and user-visible.
- Validation is documented.
- Related docs are updated.
