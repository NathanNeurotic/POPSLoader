Last updated: 2026-03-26

# CONTRIBUTING

## Purpose
Practical contributor workflow for POPSLoader changes.

## Branch and PR Expectations
- Keep branches short-lived and task-focused.
- Prefer one objective per PR.
- If a change touches runtime behavior and docs, keep the code diff narrow but update the affected root docs in the same PR.
- PR descriptions should spell out:
  - the exact problem,
  - the exact scope,
  - regression risk,
  - checks run,
  - hardware coverage gaps.

## Commit Discipline
- One logical task per commit.
- Use imperative commit messages.
- Keep diffs minimal and localized.
- Avoid unrelated formatting/refactors.

## Development Guardrails
- Preserve these unless the task explicitly changes them:
  - embedded-Lua boot flow,
  - settings transaction behavior,
  - mount-driver based USB/MX4SIO classification,
  - current package manifest contract,
  - no runtime device-family lock gating.
- Do not add unbounded retries/poll loops in runtime paths.
- Avoid adding runtime logging unless requested.

## Documentation Sync Rules
- If runtime behavior changes, update the relevant root docs:
  - `README.md`
  - `STATE.md`
  - `ROADMAP.md`
  - `DECISIONS.md`
  - `QA_REGRESSION_MATRIX.md`
- If behavior is only repo-verified and not hardware-verified, say so explicitly.
- If hardware results contradict the intended code change, document the failure instead of assuming the next patch will fix it.

## Validation Expectations

### Docs-only changes
- Run light sanity checks if available.
- If no doc tooling is available, note `not run`.

### Runtime/build changes
- Run targeted checks first.
- Run broader build/package checks only when risk requires.
- For storage, launch, or exit behavior, document manual verification steps even when they were not run locally.

### Hardware-sensitive behavior
- Use `QA_REGRESSION_MATRIX.md` IDs in test notes.
- Mark untested hardware scenarios explicitly as `Unknown (verify on hardware)`.
- For current hot paths, prioritize:
  - `D-10` HDD POPSTARTER on HDD,
  - `U-05` OSDSYS after HDD init,
  - `U-10` BOOT.ELF after HDD page init.

## Good Bug Reports
Include:
- expected behavior,
- actual behavior,
- exact repro steps,
- console/storage/backend layout,
- whether the issue occurs only after another page/backend was initialized,
- whether the result came from a local build or a CI workflow artifact.

## Review Checklist
- Scope is narrow and task-aligned.
- Core invariants are preserved or intentionally migrated.
- Failure paths remain explicit and user-visible.
- Docs and matrix entries are updated.
- Repo-verified behavior and hardware-reported behavior are not conflated.
