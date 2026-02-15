# PERF_MAP_ADDENDUM — Phase 0 UNKNOWN Resolution and Call-Site Enumeration (No Code Changes)

This addendum resolves specific Phase 0 unknowns and enumerates required call sites.

---

## 1) Resolution of prior UNKNOWN items

### 1a) `UI.OnSceneEnter` definition status (repo-wide)

#### Search result
- Repo-wide search found **usage** of `UI.OnSceneEnter(...)` in transition code, but no function definition assignment (no `function UI.OnSceneEnter(...)` and no `UI.OnSceneEnter = function(...)`).
- The transition calls it conditionally (`if UI.OnSceneEnter ~= nil then ...`), which currently means no-op unless injected externally at runtime.

#### Where it is referenced
- `bin/POPSLDR/ui.lua` — inside `UI.Transition.Update()`:
  - `UI.OnSceneEnter(previous_scene, UI.CURSCENE)` at transition midpoint after writing `UI.CURSCENE`.

#### Behavioral conclusion
- **Definition status:** not defined in current repository source.
- **Effect on scene enter:** none by default from in-repo code.
- **Scans/list rebuild/I/O on scene enter:** none attributable to `UI.OnSceneEnter` in current static repo state, because no in-repo implementation exists.

---

### 1b) SMB registration/usability from runtime init

#### What exists
- `src/luaSMB.cpp` exists and contains SMB helper code (`smbLogon_Server`, SMB devctl use).

#### Runtime registration check
- Lua VM/library registration in `runScript(...)` (`src/luaplayer.cpp`) calls:
  - `luaGraphics_init`, `luaControls_init`, `luaScreen_init`, `luaTimer_init`, `luaSystem_init`, `luaSound_init`, `luaRender_init`, `luaHDD_init`.
- There is no `luaSMB_init(...)` call in this runtime init sequence.
- `src/include/luaplayer.h` declares `luaHDD_init` etc., but no `luaSMB_init` declaration.

#### Conclusion
- SMB Lua module appears **inert/dead from current runtime init path** (compiled source exists, but no observed registration/initialization hookup in active Lua boot path).
- Note: launch policy logic still includes SMB string branches in Lua (`source_mode == "smb"`), but that does not by itself prove active SMB module registration.

---

### 1c) Any runtime flip of `PLDR.HDD.USECACHE` to `true`

#### Static findings
- Default initialization sets `PLDR.HDD.USECACHE = false`.
- Additional references only read it in conditionals:
  - read in `PLDR.HDD.BuildGameList()` to optionally use `PLDR.HDDCACHE`
  - read in `PLDR.HDD.CreateCache()` early return guard.
- Repo-wide search found **no assignment** that sets `PLDR.HDD.USECACHE = true`.

#### Conclusion
- No in-repo runtime path was found that flips HDD cache usage on.

---

## 2) Enumerate call sites

### 2a) `PLDR.CleanupGameList()` call sites

All discovered call sites are in `bin/POPSLDR/ui.lua`, in `UI.MainMenu.Play()` under confirm handling (main menu option selection):

1. **MMCE path, no MMCE slots found**
   - Trigger: `UI.Pad.Events.CONFIRM` + option 1 + empty `PLDR.GetMMCESlots()`.
2. **MMCE path, MMCE present**
   - Trigger: `UI.Pad.Events.CONFIRM` + option 1 + valid MMCE prefix.
3. **MX4SIO path, IOCTL-detected mass backend (`sdc`)**
   - Trigger: `UI.Pad.Events.CONFIRM` + option 2 + `PLDR.FindMassByDriver("sdc", 4)` success.
4. **MX4SIO path, `System.initMX4SIO` fallback success**
   - Trigger: `UI.Pad.Events.CONFIRM` + option 2 + fallback init success.
5. **HDD/PFS path (conditional)**
   - Trigger: `UI.Pad.Events.CONFIRM` + option 4; called unless `UI.LASTSCENE == UI.SCENES.GHDD` (skip optimization branch logs “skipping cache cleanup”).
6. **USB exFAT path**
   - Trigger: `UI.Pad.Events.CONFIRM` + option 5.
7. **USB FAT32 path**
   - Trigger: `UI.Pad.Events.CONFIRM` + option 6.

No other file-level call sites were found.

---

### 2b) `PLDR.GetPS1GameLists(..., true/false)` call sites

#### Function definition behavior
- Signature: `PLDR.GetPS1GameLists(path, updating)`.
- Behavior split:
  - `updating == true`: appends to existing `PLDR.GAMES`
  - `updating == false`: builds temp list then assigns `PLDR.GAMES = RET`.

#### Actual call sites found
All discovered call sites are in `bin/POPSLDR/ui.lua`, in `UI.MainMenu.Play()` confirm handling, and **all pass `true`**:

1. `PLDR.GetPS1GameLists(mmce_prefix.."POPS/", true)`
   - Trigger: option 1 (MMCE) success path.
2. `PLDR.GetPS1GameLists("mass"..tostring(mx_mass)..":/POPS/", true)`
   - Trigger: option 2 (MX4SIO) when IOCTL mass backend detection succeeds.
3. `PLDR.GetPS1GameLists(game_root, true)`
   - Trigger: option 2 (MX4SIO) fallback path using `System.initMX4SIO` result.
4. `PLDR.GetPS1GameLists("mass"..PLDR.USB.MASSINDX..":/POPS/", true)`
   - Trigger: option 5 (USB exFAT).
5. `PLDR.GetPS1GameLists("mass"..PLDR.USB.MASSINDX..":/POPS/", true)`
   - Trigger: option 6 (USB FAT32).

#### `false` call-site status
- No call site passing `false` was found in current repository.

---

### 2c) `PLDR.HDD.BuildGameList()` call sites

1. **Main menu HDD entry path** (`bin/POPSLDR/ui.lua`, `UI.MainMenu.Play()`)
   - Trigger: `UI.Pad.Events.CONFIRM` + option 4 (HDD/PFS) after HDD checks.
2. **HDD cache generation path** (`bin/POPSLDR/system.lua`, `PLDR.HDD.CreateCache()`)
   - Trigger: only when `PLDR.HDD.CreateCache()` executes and `PLDR.HDD.USECACHE == true`; currently this path is gated off by default `USECACHE = false` and no discovered runtime flip to true.

---

## Evidence anchors (files searched)
- `bin/POPSLDR/ui.lua`
- `bin/POPSLDR/system.lua`
- `src/luaplayer.cpp`
- `src/include/luaplayer.h`
- `src/luaSMB.cpp`

No code changes made.
