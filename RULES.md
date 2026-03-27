Last updated: 2026-03-26

# RULES

## Scope Discipline
- Keep changes small and tied to one clear objective.
- Use the narrowest file set that can solve the task.
- Avoid mixing runtime logic, packaging policy, and broad refactors in one PR unless explicitly requested.

## Runtime Invariants (Do Not Break)
- Embedded-Lua boot chain must remain functional:
  - `main.cpp -> runScript("boot.lua") -> require("system")`.
- Settings persistence must remain transactional:
  - edits are staged in UI,
  - persisted on Settings/Profile confirm/leave.
- USB vs MX4SIO classification must remain mount-driver based (`mx4`/`sdc` semantics), not path-name guessing.
- Probe/retry behavior must stay bounded and deterministic.
- Launch failures for missing required executables must remain explicit to the user.
- Runtime device access must not be blocked by the old device-lock system.

## Storage and Launch Rules
- Keep `mc?:/` alias resolution behavior (`mc0` then `mc1`) for executable path probes.
- Preserve backend-specific launch policy logic for USB/MMCE/MX4SIO/HDD.
- Do not silently change POPStarter selector/argv behavior without explicit migration notes.
- Do not claim `D-10` or `U-10` is fixed without new hardware evidence.

## Packaging Rules
- CI packaging contract must stay synchronized with docs.
- Current release manifest contract includes:
  - `PS1_POPSLOADER/*` launcher files
  - `POPS/PATCH_5.BIN`
- Legacy `POPS/*.tm2` entries are forbidden by CI.

## Performance/Safety Rules
- No unbounded loops in per-frame UI/runtime paths.
- Avoid expensive repeated rescans unless explicitly required.
- Avoid new runtime logging unless requested.

## Validation Rules
- Behavior-impacting changes should reference matrix IDs from `QA_REGRESSION_MATRIX.md`.
- If hardware validation is not performed, mark as `Unknown (verify on hardware)`.
- When hardware reports contradict the intended code behavior, document the contradiction.
