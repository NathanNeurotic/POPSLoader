Last updated: 2026-03-20

# CONTRIBUTING

## Purpose
Practical contributor workflow for POPSLoader changes.

## Branch and PR Expectations
- Keep branches short-lived and task-focused.
- Prefer one objective per PR.
- If a change touches unrelated concerns such as runtime logic, packaging policy, and docs, split them when feasible.
- PR descriptions should include:
  - problem statement,
  - scope,
  - behavioral risk,
  - validation performed,
  - hardware coverage gaps, if any.

## Commit Discipline
- One logical task per commit.
- Use imperative commit messages.
- Keep diffs minimal and localized.
- Avoid unrelated formatting or speculative cleanup.

## CI-First Validation Policy
- GitHub Actions CI is the required build/package validation path for this repository.
- Local builds may still be useful for quick syntax or structure checks, but they are not authoritative because PS2 SDK environments are unreliable across machines.
- When you describe build confidence, anchor it to:
  - `.github/workflows/compilation.yml`,
  - `Makefile`,
  - the specific CI run or artifact if one exists.

## Development Guardrails
- Preserve these unless your task explicitly changes them:
  - embedded-Lua boot flow,
  - transactional settings save/apply behavior,
  - persisted settings schema (`PROFILE`, `POPSTARTER_PATH`, `BDMA`, `DKWDRV_PATH`, `VIDEO_STANDARD`),
  - mount-driver based USB/MX4SIO classification,
  - release package manifest contract.
- Do not add unbounded retries or poll loops in runtime paths.
- Avoid adding runtime logging unless requested.
- Do not describe internal legacy scene names as user-facing features. `GSMB` currently backs MMCE list flow, while the `SMB (v1)` menu entry remains unimplemented.

## Validation Expectations

### Docs-only changes
- Run lightweight sanity checks when available.
- If no doc tooling is available, note `not run`.
- Keep `STATE.md`, `ROADMAP.md`, `DECISIONS.md`, `RULES.md`, and `TRUTHSHEET.md` synchronized.

### Runtime/build changes
- Run targeted checks first for the touched path.
- For build or packaging claims, prioritize CI evidence over local command output.
- For storage, boot, or launch behavior, include manual verification steps even if they were not run locally.

### Hardware-sensitive behavior
- Use `QA_REGRESSION_MATRIX.md` IDs in test notes.
- Mark untested hardware scenarios explicitly as `Unknown (verify on hardware)`.

## Good Bug Reports
Include:
- expected behavior,
- actual behavior,
- repro steps,
- environment (console model, storage/backend, launch path, and layout),
- affected feature area (`USB`, `MMCE`, `MX4SIO`, `HDD`, `DKWDRV`, settings, launch, packaging).

## Review Checklist
- Scope is narrow and task-aligned.
- Core invariants are preserved or intentionally migrated.
- Failure paths remain explicit and user-visible.
- CI-facing build/package behavior still matches `Makefile` and workflow expectations.
- Validation is documented, including what was not run.
- Related docs are updated.
