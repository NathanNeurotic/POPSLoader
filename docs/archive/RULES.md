Last updated: 2026-05-28 (post-BETA-10-5)

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
- **Preservation contracts** (hardware-confirmed in BETA-10-5; must not regress on any future artifact): `D-10`, `D-14`, `D-15` (B2 fix at `4ae6679`), DKWDRV from MC, BOOT.ELF from USB-booted POPSLoader (V2 route at `d23520a`), HDD-install settings save to `mc0:/POPSTARTER/.pldrs` (PR #466 by design).
- **Known broken accepted** (do not claim fixed without new hardware evidence): DKWDRV from custom HDD path (workaround: MC), `U-10` BOOT.ELF from HDD-booted POPSLoader (workaround: Exit → OSDSYS or reboot).
- USB vs MX4SIO classification is ioctl-driver-name based per maintainer rule: `sdc`/`mx4` → MX4SIO; anything else → USB. `mx4sio_bd` only loads on explicit MX4SIO evidence (mx4sio:/ prefix, sdc/mx4 ioctl, or `.boot_mx4sio` marker). `mx4sio_bd` requires `usbmass_bd` to be loaded first (enforced at C layer in `lua_mx4sio_init`).

## Packaging Rules
- CI packaging contract must stay synchronized with docs.
- Current release manifest contract includes:
  - `PS1_POPSLOADER/*` launcher files
  - `PS1_POPSLOADER/BUILD_INFO.txt` (so hardware can confirm exact GitHub-built artifact)
  - `POPS/PATCH_5.BIN`
- Legacy `POPS/*.tm2` entries are forbidden by CI.
- CI build is gated on embedded build identity markers (`Exec path:`, `PrepareForColdExternalELFLaunch`, `BOOT.ELF launch failed`) being present in `bin/enceladus.elf`.
- `ps2dev/ps2dev` container image is pinned to `v2.0.0` (post-release pin at commit `ba8f0d0`).
- Rolling-release workflow (`.github/workflows/rolling-release.yml`) publishes a single canonical `POPSLOADER-rolling-release.zip` asset on push-to-`BETA-12-PLAY` and on PR events (last-write-wins on the shared asset).

## Performance/Safety Rules
- No unbounded loops in per-frame UI/runtime paths.
- Avoid expensive repeated rescans unless explicitly required.
- Avoid new runtime logging unless requested.

## Validation Rules
- Behavior-impacting changes should reference matrix IDs from `QA_REGRESSION_MATRIX.md`.
- If hardware validation is not performed, mark as `Unknown (verify on hardware)`.
- When hardware reports contradict the intended code behavior, document the contradiction.
