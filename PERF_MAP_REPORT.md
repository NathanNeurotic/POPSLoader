# PERF_MAP_REPORT — Phase 0 Structural Mapping (No Code Changes)

Scope: static mapping only (Lua + C/C++ bindings) for page switch, device switch, list build, selection change, and launch paths.

---

## 1) UI PAGE SWITCH PATH

### Entry points and control flow
- Main loop dispatches scene handlers every frame in `bin/POPSLDR/system.lua`:
  - `UI.MainMenu.Play()`
  - `UI.ProfileQuery.Play()`
  - `UI.GameList.Play()`
  - `UI.Credits.Play()`.
- Scene switch requests originate from `UI.SceneChange(SCENE)` → `UI.RequestScene(SCENE)` in `bin/POPSLDR/ui.lua`.
- `UI.RequestScene` starts or queues transition through `UI.Transition.Start` / `UI.Transition.Queue`.
- Transition execution happens in `UI.Transition.Update()` and at fade midpoint it performs:
  1. `UI.OnSceneExit(previous_scene, target)` (if present)
  2. write `UI.CURSCENE`
  3. `UI.OnSceneEnter(previous_scene, UI.CURSCENE)` (if present).

### Related functions in `bin/POPSLDR/ui.lua`
- Scene APIs:
  - `SceneChange`, `RequestScene`
  - `Transition.Queue`, `Transition.Start`, `Transition.Update`
- Hooks:
  - `UI.OnSceneExit(previous_scene, next_scene)` is defined and clears cover cache when leaving a game scene.
  - `UI.OnSceneEnter` is **UNKNOWN** in current static scan (referenced but no definition in `ui.lua` or `system.lua`).

### Filesystem operations on page switch
- No direct `System.listDirectory` call in transition code itself.
- Side effect on leaving game scenes: `UI.OnSceneExit` calls `UI.CoverCache:Clear()` (memory/image cleanup, not directory scan).

### List rebuild / sorting triggered by page switch
- Page switch itself does not rebuild game list automatically.
- In this codebase, list rebuilds are triggered in main-menu confirm paths before changing to game scenes (device-dependent), not by `OnSceneEnter`.

### Per-event vs per-frame
- `UI.MainMenu.Play`, `UI.GameList.Play`, etc. are per-frame.
- `UI.SceneChange` is event-driven (pad input), but transition alpha updates run per-frame while active.

---

## 2) DEVICE SWITCH PATH

### Trigger point
- Device switching is driven by `UI.MainMenu.Play()` confirm handler (`UI.Pad.Events.CONFIRM`) with options:
  - MMCE (opt 1)
  - MX4SIO (opt 2)
  - HDD/PFS (opt 4)
  - USB exFAT / FAT32 (opts 5/6).

### Code path by device
- **MMCE**:
  1. `PLDR.GetMMCESlots()` (lazy probe via `PLDR.DetectMMCESlot()`)
  2. `PLDR.CleanupGameList()`
  3. `PLDR.GetPS1GameLists(mmce_prefix.."POPS/", true)`
  4. `UI.SceneChange(UI.SCENES.GMMCE)`.
- **MX4SIO**:
  1. `PLDR.FindMassByDriver("sdc", 4)` preferred
  2. fallback `System.initMX4SIO(hint)`
  3. `PLDR.CleanupGameList()`
  4. `PLDR.GetPS1GameLists(<root>/POPS/, true)`
  5. `UI.SceneChange(UI.SCENES.GMX4SIO)`.
- **HDD/PFS**:
  1. `PLDR.LoadHDDModules()`
  2. optional `PLDR.CleanupGameList()` (skipped if returning from GHDD)
  3. `PLDR.HDD.CheckAvailableHddPopsParts()`
  4. `PLDR.HDD.BuildGameList()`
  5. `UI.SceneChange(UI.SCENES.GHDD)`.
- **USB exFAT/FAT32**:
  1. `PLDR.CleanupGameList()`
  2. `PLDR.GetPS1GameLists("mass"..PLDR.USB.MASSINDX..":/POPS/", true)`
  3. `UI.SceneChange` to USB scene.

### Detection and enumeration locations
- USB/MX4SIO backend detection at boot: `PLDR.DetectMassBackends()` (`FindMassByDriver` calls `System.getMassDriverName`).
- MMCE slot probe: `PLDR.DetectMMCESlot()` checks `doesFolderExist("mmce0:/")`, `doesFolderExist("mmce1:/")` once due to `MMCE.PROBED`.
- Directory enumeration for games:
  - non-HDD: `PLDR.GetPS1GameLists` → `System.listDirectory(PLDR.GAMEPATH)`
  - HDD: `AppendHddGameList` → `System.listDirectory(list_path)` while mounted partition(s).

### Repeated scans assessment
- MMCE detection has one-shot probe behavior (no repeated slot scan once probed).
- Game directory scans do repeat whenever user re-enters device from main menu because `CleanupGameList` + `GetPS1GameLists(..., true)` is called each time.
- HDD partition availability scan is guarded by `PLDR.HDD.HAS_CHECKED`, but game list rebuild still occurs on HDD option confirm.

---

## 3) GAME LIST BUILD PATH

### All `System.listDirectory` call sites (relevant to game list)
- `PLDR.GetPS1GameLists(path, updating)` uses `System.listDirectory(PLDR.GAMEPATH)` for USB/MMCE/MX4SIO/SMB-style list construction.
- `AppendHddGameList(partition, list_path, rel_prefix)` uses `System.listDirectory(list_path)` for HDD partitions.
- `PLDR.HDD.BuildGameList()` calls `AppendHddGameList` for:
  - `pfsX:/`
  - `pfsX:/POPS/`
  - repeated across `__.POPS` and `__.POPS0..9` partitions if present.

### Construction / filtering / sorting
- Non-HDD (`GetPS1GameLists`):
  - loops directory entries
  - keeps files with `.vcd` extension (case-insensitive by `string.lower`)
  - appends to `PLDR.GAMES` when `updating=true`, else temporary list
  - always `table.sort(PLDR.GAMES)` when any game found.
- HDD (`AppendHddGameList` + `BuildGameList`):
  - loops directory entries
  - filters `.vcd`
  - encodes entries as `partition|relpath`
  - records map `PLDR.HDD.GAMEPARTS[encoded] = "hdd0:"..partition`.
  - No explicit `table.sort` in HDD build path in current scan.

### Rebuild on enter vs caching
- USB/MMCE/MX4SIO: rebuilt on device-entry confirm from main menu.
- HDD:
  - `PLDR.HDD.BuildGameList()` called on HDD main-menu entry.
  - Optional cache mechanism exists (`PLDR.HDDCACHE`, `PLDR.HDD.USECACHE`, `CreateCache/ReadCache`), but default in table is `USECACHE = false`; so caching is present structurally but likely inactive unless changed elsewhere.

### Obvious O(N) behavior
- O(N) directory pass in `GetPS1GameLists` for each scan.
- O(N) sort (`table.sort`) after scan for non-HDD lists.
- HDD path multiplies enumeration by number of mounted POPS partitions and by two paths per partition (`root` + `POPS/`), then O(total files) insertion.
- `PLDR.CleanupGameList()` loops from `0..#PLDR.GAMES` and nils entries, O(N).

---

## 4) SELECTION CHANGE PATH

### Cursor movement flow
- In `UI.GameList.Play()` (per-frame), after `Input_GetEvent()`:
  - `NAV_UP/DOWN/LEFT/RIGHT` update `UI.GameList.CURR`.
- Display loop renders visible rows (`for i = STARTUP, ammount`) each frame.

### Work tied to selection updates
- Cover/preview path executes in `UI.GameList.Play()` each frame when `SHOW_COVER` is true:
  - `UI.CoverCache:UpdateSelection(PLDR.GAMES[CURR], PLDR.GAMEPATH, UI.CURSCENE)`.
- `CoverCache:UpdateSelection`:
  - short-circuits if `last_key` unchanged.
  - builds candidate path list.
  - for HDD entries can mount partition (`HDD.MountPartition`) and unmount (`HDD.UMountPartition`) around cover lookup.
  - `GetOrLoad` checks file existence (`doesFileExist` / `System.openFile`) and loads image via `Graphics.loadImage` if needed.

### Synchronous loading assessment
- Cover path appears synchronous:
  - filesystem existence checks are inline.
  - image decode/load is inline.
  - HDD mount/unmount for cover candidates is inline.
- This work is triggered during frame render path, but cache key prevents repeats for unchanged selection.

### Rebuild/unnecessary state churn
- Game list itself is not rebuilt on cursor move.
- Render row loop is per-frame over visible range only (`MAXDRAW` window), not full list.
- Cover lookup work can still involve synchronous I/O on selection changes (and on first frame for a selection).

---

## 5) LAUNCH PATH (CRITICAL)

### Exact call path: select game → POPStarter handoff
1. `UI.GameList.Play()` confirm handler (`UI.Pad.Events.CONFIRM`) validates list and files.
2. Calls `PLDR.RunPOPStarterGame(launch_path, selected_game, UI.CURSCENE)`.
3. `PLDR.RunPOPStarterGame`:
   - resolves launch policy via `ResolveLaunchPolicy` (USB/MMCE/MX4SIO/HDD)
   - builds normalized paths, boot mode, and selector (`argv0_selector`)
   - for HDD parses `partition|relpath`, may init/mount through `PrepareHddLaunch` path (via `PLDR.LoadHDDModules`, mount selection map).
   - builds context structure.
4. Calls `LaunchEngine(popstarter, argv, reboot_iop, context)`.
5. `LaunchEngine` performs validation/logging/fade and executes:
   - `System.loadELF(popstarter, reboot_iop, argv...)`.
6. Runtime binding `lua_loadELF` in `src/luasystem.cpp` dispatches to backend loader (`LoadELFFromFile` / `LoadELFFromFileFileIO`) with optional selector as argv0.

### Where argv / launch parameters are constructed
- `PLDR.RunPOPStarterGame` constructs:
  - `argv = { argv0_selector }`
  - `bootparam`, `bootparam_basename`, prefix behavior, device mode metadata.
- `LaunchEngine` passes `argv` into `System.loadELF` (packed/unpacked path).
- In C++ binding, only first extra arg is consumed as selector (`lua_loadELF`, `luaL_checkstring(L, 3)`, argc fixed to 1 when present).

### Where `System.loadELF` is called
- `LaunchEngine` (primary POPStarter handoff call).
- Also exists for modal utilities (`LaunchBootElf`, `LaunchDKWDRV`) in UI, but not game-launch path.

### Required vs optional vs unknown
- **REQUIRED (for handoff):**
  - resolve target ELF path (`ResolvePopstarterPath`)
  - derive selector/argv0 for POPStarter semantics
  - call `System.loadELF(...)`.
- **REQUIRED/likely safety checks:**
  - basic readability/open check (`TryOpenForLaunch`) before exec.
  - HDD mount prep when launching HDD entries.
- **OPTIONAL (not strictly handoff primitive):**
  - extensive `LaunchLog(...)` calls
  - repeated `ShowExecMarker(...)` UI marker draws
  - pre-exec `UI.CoverCache:Clear()` (cleanup convenience)
  - some bootparam existence fallback logic used for diagnostics/robustness.
- **UNKNOWN:**
  - whether all debug marker stages are mandated for field diagnostics across all variants.
  - whether all context metadata fields are consumed downstream beyond logging.

### Work that appears unnecessary before launch (structural observation only)
- Multiple `ShowExecMarker` calls and large logging volume occur in launch critical path before `System.loadELF`.
- Bootparam derivation and existence checks are computed even though final `loadELF` argv payload is selector-centric in this code path.
- This is an observation only; no change recommendation in Phase 0.

---

## 6) SYSTEM INVENTORY (STATIC)

### Major subsystems (Lua layer)
- `bin/POPSLDR/system.lua`:
  - device/path normalization, mass backend detect, game list management, launch engine, main loop.
- `bin/POPSLDR/ui.lua`:
  - scene routing, transitions, menu/input handling, game list rendering, cover cache.
- `bin/POPSLDR/pops_profiles.lua`:
  - POPStarter profile registry and default ELF selection.

### Major subsystems (C/C++ runtime)
- `src/main.cpp`:
  - EE boot entry, argv parse, IOP module init, graphics/pad init, `chdir(boot_path)`, execute embedded boot Lua string via `runScript` loop.
- `src/luaplayer.cpp`:
  - creates Lua VM, registers Lua-facing modules (`graphics`, `controls`, `screen`, `timer`, `system`, `sound`, `render`, `HDD`).
- `src/luasystem.cpp`:
  - Lua `System` table (`listDirectory`, `loadELF`, file ops, path/asset helpers, mass-driver query, MX4SIO init, etc.).
- `src/luaHDD.cpp`:
  - `HDD` Lua table (`MountPartition`, `UMountPartition`, `Initialize`, `GetHDDStatus`).
- `src/system.cpp`:
  - lower-level platform/system helpers (IOP reset, asset resolution helpers).

### Candidates that appear unused, legacy, or always-idle (static evidence)
- `src/luaSMB.cpp` appears present but no `luaSMB_init(...)` registration path found in `runScript` initialization sequence; SMB Lua API exposure is therefore **UNKNOWN/likely unused** from current entrypoint.
- Device lock subsystem in `ui.lua` appears effectively disabled by design:
  - `canEnterDevice` always returns `true`
  - `setDeviceLock` clears/ignores lock state
  - indicates legacy lock mechanism retained but idle.
- HDD cache subsystem exists (`PLDR.HDD.CreateCache/ReadCache/WipeCache`) but `PLDR.HDD.USECACHE` defaults false in current table initialization; this suggests cache path may be dormant unless enabled externally.

### Evidence method
- Static references and entrypoints were traced via:
  - Lua call-chain inspection in `system.lua`, `ui.lua`, `pops_profiles.lua`.
  - Runtime binding registration in `luaplayer.cpp` and `luasystem.cpp`.
  - boot-to-Lua entry in `main.cpp` (`runScript(bootString, true)`).

---

## Notes on uncertainty handling
- Any function/path not directly defined in scanned files is marked `UNKNOWN` instead of inferred.
- No optimization proposal or code modifications are included in this Phase 0 report.
