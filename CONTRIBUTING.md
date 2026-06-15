Last updated: 2026-05-28 (post-BETA-10-5)

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
  - `TRUTHSHEET.md` (for preservation contracts and behavioral invariants)
- If behavior is only repo-verified and not hardware-verified, say so explicitly. Post-BETA-10-5 PR work is `Unknown (verify on hardware)` unless a tester result is recorded in `QA_REGRESSION_MATRIX.md`.
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
- **Preservation contracts** (hardware-confirmed in BETA-10-5; must continue to PASS on any new artifact):
  - `D-10` HDD POPSTARTER on HDD (B2 fix at `4ae6679`),
  - `D-14` HDD POPSTARTER with non-HDD game,
  - `D-15` non-HDD POPSTARTER with HDD game,
  - DKWDRV from MC,
  - BOOT.ELF from USB-booted POPSLoader (V2 route at `d23520a`).
- **Known broken accepted** (do not test as regression; documented workarounds apply):
  - DKWDRV from custom HDD path,
  - `U-10` BOOT.ELF from HDD-booted POPSLoader.
- The rolling-release workflow publishes to a single canonical URL. Pushing to your PR branch triggers a build that overwrites the asset (last-write-wins). Coordinate with the maintainer if testers are mid-cycle.

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
