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

## Boot from anywhere matrix (asset resolution expectations)

This matrix is for QA to validate current behavior with different launch vectors **without changing runtime behavior**.

### Resolution rules used by `System.resolveAsset("system.lua")`

`boot.lua` asks `System.resolveAsset("system.lua")` for the script path. The resolver checks in this order:

1. `APP_DIR/system.lua`
2. `APP_DIR/POPSLDR/system.lua` (legacy fallback)
3. Fail (`nil`) and boot.lua throws an error containing `current_bootpath`.

`APP_DIR` is derived from launch path (`argv[0]`) when available, otherwise from `boot_path`. `boot_path` is normalized from the launch source and set as current directory before Lua boot. `host:` and generic `device:` paths are normalized to include slash separators. (See cited sources for exact logic.)

### Launch vector matrix

| Launch vector | Expected `APP_DIR` (derived app root) | `system.lua` resolution order | Expected fallback behavior |
|---|---|---|---|
| `mass:/POPSLOADER.ELF` with flat assets | `mass:/` | 1) `mass:/system.lua` → 2) `mass:/POPSLDR/system.lua` | If flat file exists, it wins. If only legacy layout exists, fallback to `POPSLDR/`. If neither exists, Lua error with `current_bootpath` is expected. |
| `mass:/APPS/POPSLoader/POPSLOADER.ELF` | `mass:/APPS/POPSLoader/` | 1) `mass:/APPS/POPSLoader/system.lua` → 2) `mass:/APPS/POPSLoader/POPSLDR/system.lua` | Same behavior: flat-first, legacy fallback second, hard error if both missing. |
| `mc0:/.../POPSLOADER.ELF` | **TODO: verify exact normalized form in your launch environment**; expected intent is launch directory on `mc0:` | 1) `<mc0 launch dir>/system.lua` → 2) `<mc0 launch dir>/POPSLDR/system.lua` | Resolver behavior should match other devices because it keys off `APP_DIR`; **TODO: verify end-to-end direct `mc0:` boot path in your loader stack**. |
| `host:/.../POPSLOADER.ELF` (dev/debug) | Normalized `host:/.../` path (including slash normalization for `host:` and Windows-style drive fragments) | 1) `<host app dir>/system.lua` → 2) `<host app dir>/POPSLDR/system.lua` | Same flat-first fallback behavior; useful for rapid iteration in debug/dev setups. |

## QA capture points (before/after quick diff)

Capture these three values for each vector so regressions are obvious:

1. **`current_bootpath`**
   - Source: boot failure message in `boot.lua` includes `current_bootpath: ` + `System.currentDirectory()` when `system.lua` cannot be resolved.
2. **Derived app root (`APP_DIR`)**
   - Source: C debug output logs `app dir : ...` during startup.
3. **Final resolved `system.lua` path**
   - Source: `ResolveAssetPath: ...` debug print shows the winning path when resolution succeeds.

### Suggested capture checklist per vector

- Launch ELF from the target vector.
- Record startup logs containing:
  - `boot path : ...`
  - `app dir : ...`
  - `ResolveAssetPath: ...system.lua` (if success)
- If launch fails before script load, record full Lua error with `current_bootpath`.
