# Debugging POPSLoader Launch Issues

This document describes **how to capture meaningful logs** without creating per-frame spam, and how to reproduce and diagnose a black screen during POPStarter handoff.

## Minimal logging guidelines

- **Log on state changes** (e.g., launch phase transitions) rather than every frame.
- **Use existing logging helpers**:
  - Lua: `LOG(...)` / `LOGF(...)`
  - Launch tracing: `LaunchLog(...)` (writes to `launch.log` as well as console)
- **Avoid per-frame UI spam**. If you must log input activity, prefer throttled counters or `DEBUG_INPUT_LOG` guards.

## Where to enable debug logging

- **Lua launch tracing** is already always available via `LaunchLog(...)` and `LOG(...)`.
- **ELF loader logs** (`LAUNCH: ...`) are printed from the ELF loader itself and are visible on the console when the loader executes.
- **TODO: verify** whether any build flags or runtime toggles exist to enable/disable Lua log output globally.

## Reproducing black screen on handoff (log checklist)

When a black screen occurs after selecting a game, collect the following:

1. `launch.log` from the writable path (written by `LaunchLog(...)`).
2. Console output around the handoff, especially the loader’s `LAUNCH:` lines.

### Required log lines (minimum viable set)

From POPSLoader (Lua):
- `LAUNCH: boot source: ...`
- `LAUNCH: pops root: ...`
- `LAUNCH: vcd basename: ...`
- `LAUNCH: bootparam: ...`
- `LAUNCH: exec argv[0]: ...`
- `LAUNCH: exec argv[1]: ...`
- `LAUNCH RETURNED rc=...`

From ELF loader (C):
- `LAUNCH: popstarter path: ...`
- `LAUNCH: argv[0]: ...`
- `LAUNCH: argv[1]: ...`
- `LAUNCH: argv[2]: ...` (if present)
- `LAUNCH: RETURNED rc=...`

## What to check first (triage)

1. **Does argv[1] contain the full boot string?**
   - It must include the correct POPS root and required prefix.
2. **Does the prefix match the device rules?**
   - HDD: none
   - SMB: `SB.`
   - MASS/MMCE/USB: `XX.`
3. **Does the POPStarter ELF resolve successfully?**
   - `LAUNCH: popstarter path: ...` and `open rc` should show success.
4. **Does the launch phase stall before `LAUNCH_EXEC`?**
   - If so, note the last phase and review `launch.log`.
