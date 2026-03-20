Last updated: 2026-03-20

# RULES

## Scope Discipline
- Keep changes small and tied to one clear objective.
- Use the narrowest file set that can solve the task.
- Avoid mixing runtime logic, packaging policy, and broad refactors in one PR unless explicitly requested.

## CI Validation Rules
- Treat GitHub Actions CI as the authoritative build/package validator.
- Do not claim a build is correct solely because it worked locally.
- Keep build- and package-related docs synchronized with `Makefile` and `.github/workflows/compilation.yml`.

## Runtime Invariants (Do Not Break)
- Embedded-Lua boot chain must remain functional:
  - `src/main.cpp -> runScript("boot.lua") -> require("system")`.
- Settings persistence must remain transactional:
  - edits are staged in UI,
  - settings are persisted on Settings/Profile confirm or leave,
  - persisted fields currently include profile, POPStarter path, BDMA mode, DKWDRV path, and video standard.
- USB vs MX4SIO classification must remain mount-driver based (`mx4` and `sdc` semantics), not path-name guessing.
- Probe/retry behavior must stay bounded and deterministic.
- Launch failures for missing required executables must remain explicit to the user.

## Storage and Launch Rules
- Keep `mc?:/` alias resolution behavior (`mc0` then `mc1`) for executable path probes.
- Preserve backend-specific launch policy logic for USB, MMCE, MX4SIO, and HDD.
- Preserve current POPStarter resolution semantics unless intentionally changed:
  - app-local relative `POPSTARTER.ELF`,
  - HDD sidecar resolution when booted from HDD,
  - memory-card fallbacks.
- Do not silently change POPStarter selector or `argv` behavior without explicit migration notes.

## UI and Behavior Rules
- `Select` toggles auxiliary text only on supported scenes.
- `Square` toggles cover preview in game-list scenes.
- Current cover lookup is filesystem-based:
  - non-HDD backends use sidecar `<game>.png`,
  - HDD uses `hdd0:__common/POPS/ART/<title>.png`.
- Do not describe `GSMB` as implemented SMB support. It is currently MMCE list plumbing plus a legacy internal scene name.
- Do not claim device-lock enforcement unless code paths actually call `canEnterDevice` or `OpenDeviceLock`.

## Packaging Rules
- CI packaging contract must stay synchronized with docs.
- Current release manifest contract includes:
  - `PS1_POPSLOADER/*` launcher files,
  - `POPS/PATCH_5.BIN`.
- Legacy `POPS/*.tm2` entries are forbidden by CI.
- `BUILD_INFO.txt` is currently generated in the CI workspace but is not packaged into `POPSLOADER.zip` unless packaging logic is intentionally changed.

## Performance and Safety Rules
- No unbounded loops in per-frame UI or runtime paths.
- Avoid expensive repeated rescans unless explicitly required.
- Avoid new runtime logging unless requested.

## Validation Rules
- Behavior-impacting changes should reference matrix IDs from `QA_REGRESSION_MATRIX.md`.
- If hardware validation is not performed, mark it as `Unknown (verify on hardware)`.
