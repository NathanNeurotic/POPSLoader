# Adversarial Verification — POPSLoader Redo, Chunk F2 (ui.lua / images.lua / boot.lua + binding census)

- Subject: `~/workspace/Sable-audit-redo/Redo-POPSLoader.md`
- Clone (read-only, verified pin): `~/workspace/audit-clones-2026-11-13/POPSLoader` @ `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (`git rev-parse HEAD` matches; tree clean)
- Method: refute-first. Every cited file/line opened with surrounding context; census and table-identity claims re-derived with independent scripts; repo-wide greps hunted for defeating callers, aliases, dynamic dispatch, and writes into supposedly write-free tables.
- Assigned: RE-POPS-048, 064, 071, 072, 088, 089, 094, 095.

---

### RE-POPS-048 — VERIFIED-DRIFT

**Claim:** 143 active `luaL_Reg` entries; 91 referenced in shipped Lua; 52 unreferenced (50 names enumerated); no user script can reach them because `runScript` only executes embedded `boot.lua` and `DisableLuaFilesystemScriptLoaders` nils `dofile`/`loadfile` and empties `package.path`/`cpath`.

**What holds (mechanism VERIFIED):**
- Reachability lockdown is real. `src/main.cpp:721` is the only `runScript(` call site, with `"boot.lua"`. `src/luaplayer.cpp` `runScript` (from line 255) loads only via `FindEmbeddedLua`, whose table (lines 36–41) contains exactly `boot.lua`, `system.lua`, `ui.lua`, `images.lua`. `InstallEmbeddedLuaSearcher` replaces the searchers, and `DisableLuaFilesystemScriptLoaders` (luaplayer.cpp, in the cited 158–190 region) sets `dofile`/`loadfile` to nil and `package.path`/`cpath` to `""`. The four census Lua files are therefore the complete runnable set (`boot.lua` ends `require("system")`; system.lua:4978 `pcall(require, "ui")`, 5069 `require("images")`).
- The two judgement-call bindings check out exactly as described: `Pads.getType` has no Lua caller and is documented do-not-use-for-gating (`AGENTS.md:87`, `ARCHITECTURE.md:303`, `DECISIONS.md:118-120` — use `Pads.getMode` / `PAD_MODECURID`, not `getType` / `PAD_MODETABLE`); `System.getSio2Owner` has no Lua caller and is documented diagnostic-only / guard deleted in EXP32, binding surviving (`STATE.md:46,253`, `docs/HANDOFF_EXP33_2026-07-21.md:193` "getSio2Owner = DIAGNOSTIC-ONLY latch reader").
- Every one of the 50 enumerated unreferenced names was independently confirmed unreferenced (zero `Table.name` hits, zero bare `.name` hits in the four Lua files).

**Corrected figures (my census, script-rebuilt):**
- Method: parse every `static const luaL_Reg …[]` table in `src/lua*.cpp`, dropping `//`-commented entries (e.g. `Screen.getPixel`, `Graphics.getPixel/loadAnimatedImage/…`, `System.doesFileExist`); map each table to its `lua_setglobal` name (HDD, Screen, Color, Pads, Font, Graphics, Sound, System, IOP for `Sif_functions`, Timer); a reference counts as `Table.name`, `Table["name"]`, or a use through the one alias that exists in the Lua (`local S = System`, system.lua:7233).
- Per-table active counts: HDD 5, Screen 9, Color 5, Pads 9, Font 16, Graphics 24, Sound 6, System 64, IOP/Sif 2, Timer 8 = **148 total** (not 143).
- **Referenced: 94. Unreferenced: 54** (not 91 / 52).
- The 143 figure is exactly 148 − 5: the `HDD_functions` table in `src/luaHDD.cpp` (not among the finding's cited locations) was omitted from the census. All five HDD bindings are in fact referenced (`HDD.Initialize`, `HDD.MountPartition`, `HDD.UMountPartition`, `HDD.ListPartitions`, `HDD.GetHDDStatus`, e.g. system.lua:281, 794, 8816, 9805; boot.lua HDD branch), so omitting them cannot by itself produce 91/52 either — the original arithmetic is irreconcilable in a second place as well.
- The finding's own enumeration lists only **50** names, not 52. Four genuinely unreferenced bindings are missing from it, each confirmed with zero hits in all four Lua files:
  - `Screen.getOverscan` (luaScreen.cpp:163; only `setOverscan` is ever called)
  - `Font.load` (the gsFont loader; `Font.LoadBuiltinFont`, `fmLoad`, `ftLoadEmbedded` are used, `load` never is)
  - `System.smbGetIPConfig` (luasystem.cpp:2572; the string occurs only in C comments/error text, never in Lua)
  - `Timer.reset` (luatimer.cpp; Lua uses only `Timer.new` / `Timer.getTime`)
- Alias trap checked and handled: a naive `System.name` grep falsely flags `System.initATAModules` as dead — it is called as `S.initATAModules` at system.lua:7234/7248 via `local S = System` (7233), so it is **referenced** and correctly absent from the dead list.
- Scope note: the three `lua_register` globals in luasystem.cpp:2658-2660 (`doesFileExist`, `doesFolderExist`, `print_uart`) are not `luaL_Reg` entries and are rightly outside the census; the first two are heavily used (see Candidate 1 for the third).

**Fix sanity (LESS-NOT-MORE):** Direction stands and is if anything understated — the true dead set is 54 bindings, not 52. Deleting registrations plus newly-unreachable implementations in one pass remains the right shape; the parent should use the corrected 54-name list (the finding's 50 + the four above) rather than the printed one.

**Duplicate check:** none. Neighbours RE-POPS-084/032 concern implementations/subsystems, not the registration census.

---

### RE-POPS-064 — VERIFIED-DRIFT

**Claim:** Settings `Play` (ui.lua:4351) runs per frame; per frame it re-creates five constant `Color.new(...)` values (4383-4391), redefines ~10 helper closures (4407-4460), and rebuilds the item list from `local items = {}` (4929) via 37 `Add*` calls whose arguments include 101 `function(` literals (body counted over 4351-5914).

**What holds (mechanism VERIFIED):**
- Per-frame dispatch confirmed: system.lua's terminal `while true do` loop calls `UI.ProfileQuery.Play()` whenever `UI.CURSCENE == UI.SCENES.MPROFILE` (the Settings scene), followed by `UI.flip()`. The `Play = function()` at ui.lua:4351 is `ProfileQuery.Play` (table opened 4349) and draws the "Settings" title.
- Five constant colours confirmed exactly: `Color.new` at 4383, 4384, 4389, 4390, 4391 (`highlight_color`, `separator_color`, `section_color`, `section_line_color`, `readonly_color`) — none depends on frame state.
- `local items = {}` at 4929 confirmed, followed by the `AddSection/AddSpacer/AddCycle/AddInfo/AddPath/AddAction` builder definitions (4937-4981) and the full build; the build is unconditional code inside `Play`, so it re-executes every frame. Nothing caches `items` on `UI`.
- Helper closures are redefined per frame — in the cited 4407-4460 window there are six `local function`s (`TruncateMiddle` 4407, `CycleIndex` 4417, `clear_settings_session` 4425, `restore_settings_session` 4432, `discard_settings_and_return` 4448, `queue_exit` 4459, with a seventh nested `report_stage` just past the window), and 41 `local function` definitions across the whole `Play` body, so the "roughly ten helpers" characterisation is directionally right but the cited window itself holds six.

**Corrected figures (script-counted over the true body, 4351 to the end of `ProfileQuery` at 5900; the finding's 5914 end-point overshoots 14 lines into the `MainMenu` table header, which changes no count):**
- `function(` literals in the body: **102 total, 101 excluding the `Play = function()` line itself** — the finding's 101 is that body-wide number, not the number inside `Add*` arguments; from `local items = {}` (4929) onward the count is **97**.
- `Add*` **call sites: 39, not 37** — AddSection 10, AddCycle 21, AddInfo 3, AddPath 3, AddSpacer 1, AddAction 1 (plus the 6 builder definitions at 4937-4974, which a naive grep conflates, giving 45).
- Runtime rows inserted per frame are higher than either static number: the `AddCycle` call at 5333 sits in `for _, row in ipairs(ember_rows)` (5 rows) and the `AddCycle` at 5141 sits in the carousel-device loop (8 keys in `PLDR.CAROUSEL_DEVICE_KEYS`, system.lua:5656, minus the skipped EXFAT/PFS = 6 executions), so a normal frame inserts **≈48 items** (39 − 2 loop call sites + 5 + 6), each with its fresh getter/prev/next/dirty closures.

**Fix sanity (LESS-NOT-MORE):** Hoisting is sound in substance: row labels are literal strings, and every row's value/prev/next/dirty are closures over mutable `UI.*`/`PLDR.*` state, so a table built once at scene entry still reads live values; the only structural input is `PLDR.CAROUSEL_DEVICE_KEYS` (a load-time constant). The title/footer, which do re-translate per frame via `PLDR.L(...)`, are outside the item list and would stay per-frame. The drift is in the arithmetic only — the real per-frame cost is larger than claimed, so the finding understates its own case.

**Duplicate check:** none in this chunk.

---

### RE-POPS-071 — VERIFIED

Evidence:
- Script diff of the two tables in ui.lua: the ABNT block (2561-2569) and the QWERTY block (2579-2587) extract to byte-identical text (341 chars, 7 rows each: number row, three letter/symbol rows, symbol row, `{SPACE,DEL,CLR}`, `{BACK,DONE}`); my extraction compared the full row literals, not a visual scan.
- Selectability confirmed: `layout_order = {"QWERTY", "DVORAK", "ABC", "AZERTY", "QWERTZ", "ABNT"}` at ui.lua:2533, cycled by the Settings Keyboard Layout row; `NormalizeKeyboardLayout` in system.lua accepts ABNT at 2540-2542 (`if key == PLDR.KEYBOARD_LAYOUT_ABNT then return …ABNT`).
- No defeating differentiation anywhere: repo-wide grep for `ABNT` finds only system.lua:2513, system.lua:2540-2541, ui.lua:2533, ui.lua:2558-2561, and ui.lua:2614. The `SHIFT_MAP` (ui.lua:2605+) is a single global table shared by all layouts, so shift behaviour cannot distinguish ABNT either. The in-code comments match the finding verbatim in substance (ui.lua:2558-2560 and system.lua:2513: distinguishing keys are non-ASCII, OSK is single-char ASCII, "intentionally absent").
- Fix-sanity note (does not change the verdict): the fix lists layout_order, the layouts table, and system.lua's normalizer, but ui.lua:2614's fallback `_NormalizeLayout` also accepts `"ABNT"`. That fallback only runs when `PLDR.NormalizeKeyboardLayout` is absent (system.lua always defines it in the shipped load order), so leaving it would not resurrect the layout — but a complete removal should touch it too, and the finding's own alternative (normalizer maps persisted `ABNT` → QWERTY explicitly) remains the cleaner half of its fix.

### RE-POPS-072 — VERIFIED

Evidence:
- ui.lua:3254-3255 `local titles = {}` / `local scene_title = titles[UI.CURSCENE]` and 3266-3267 `local placeholders = {}` / `local placeholder_title = placeholders[UI.CURSCENE]`, inside `UI.GameList.Play` (table at 3213), which the system.lua main loop dispatches per frame for game scenes.
- Write-site hunt (the assigned test): repo-wide grep for `titles =`, `titles[`, `placeholders =`, `placeholders[` across all Lua and C returns exactly the two empty constructions and the two read lookups — no other assignment exists, and both tables are function-locals that are never returned, stored, or exposed, so no other file *can* write into them. Both lookups are therefore always nil; the `scene_title` draw (3262) and the whole placeholder branch (3268-3292, including the `PLDR.L("Not implemented yet")` print at 3271, the "This backend isn't implemented yet" notification, and the early `return`) are unreachable.
- The comments quoted in the finding are present as described (3253 "Table kept empty so a genuinely-new backend could still opt back into a title…", 3263-3265 "No scenes are placeholders anymore… Keeping the (now-empty) table + guard…").
- Minor benefit overstatement, not a defect in the finding's core: its Fix deletes only the branch, so the seven translation entries for `"Not implemented yet"` in system.lua (2732, 3039, 3347, 3655, 3962, 4296, 4691) would become stale entries rather than being removed by this fix as the Benefit line implies; they would belong to a translation-cleanup pass (cf. RE-POPS-092).

### RE-POPS-088 — VERIFIED

Evidence:
- images.lua:46 `local IMG_FALLBACKS = {}`; the only other occurrence in any Lua/C file is the read at images.lua:64 (`local fallback_key = IMG_FALLBACKS[key]`) inside the `__index` fallback block (64-70). Repo-wide grep for `IMG_FALLBACKS` otherwise returns only documentation (AGENTS.md:85, ARCHITECTURE.md:620, COMPONENTS.md:353, DECISIONS.md:376, QA_REGRESSION_MATRIX.md:148, STATE.md:87) — all of which independently describe it as now-empty since the MISSING.png removal.
- No defeating write exists: the table is file-local, never exported, never returned, and there is no `IMG_FALLBACKS[…] =` or bulk assignment anywhere; `IMG.ReleaseAll` (81-93) resets only `IMG_FAILED`. `fallback_key` is therefore always nil, the `fallback_key ~= nil` guard never passes, and the branch is dead on every failed load (which then memoises into `IMG_FAILED` at 71).
- Line anchors check: declaration 46 exact; the read/branch spans 63-72 as cited if the following `IMG_FAILED[key] = true` / `return nil` lines are included.

### RE-POPS-089 — VERIFIED-DRIFT

**Claim:** `bin/POPSLDR/IMG/default.png` is absent (67 files in the directory, none named default.png); Makefile/embed wiring embeds it only conditionally on `HAVE_ASSET_DEFAULT_PNG`; images.lua registers `{"default", "default.png"}` unconditionally; nothing ever requests `IMG.default`.

**What holds (all three limbs VERIFIED):**
- Directory listing of `bin/POPSLDR/IMG/`: **67 files**, no `default.png` (only `cover_default.png` / `cover_missing.png` match "default").
- Registration: images.lua:34 `{"default", "default.png"}` (the cited 34-36 spans it plus the two cover rows).
- No requester: grep for `IMG.default` and `IMG["default"]` across all Lua/C returns zero hits; the game list uses `IMG.cover_default` (ui.lua:3581-3582). The dynamic `IMG[key]` sites cannot produce `"default"` either — footer Draw keys are button-glyph names, and carousel `ResolveIcon` keys come from `icon_map`/opts (device names: MMCE/MX4SIO/HDD/USB/i.Link/SMB/DISC), checked at ui.lua:1619-1700 and 5934-6020. `IMG.ReleaseAll` only `rawget`s already-cached keys, so it never triggers a load of `default`.
- Conditional embed: src/embed_assets.cpp:56-58 `#ifdef HAVE_ASSET_DEFAULT_PNG` externs, and ASSET_ENTRY rows at 140 and 201, each inside its own `#ifdef` — all exactly as cited. With the file absent, `HAVE_ASSET_DEFAULT_PNG` is undefined and no blob exists, so in this build the registration could only resolve to failure *if* it were ever requested (in practice it never even gets that far — see drift note 2).

**Corrected figure:**
- The cited `Makefile:88-95` range is **not** conditional-embed wiring — those lines are `APP_CORE` (88), `LUA_LIBS` (90-92) and the start of `IOP_MODULES` (94-95). The finding flags the range as INFERRED; it inferred wrong. The actual wiring is Makefile **72-79** (comment + `OPTIONAL_EMBEDDED_RSC` + `ifneq ($(wildcard bin/POPSLDR/IMG/default.png),)` at 76 + `-DHAVE_ASSET_DEFAULT_PNG=1` at 78), plus the unconditional bin2c rule for the asset at Makefile **194-195** (the object only reaches the link via `OPTIONAL_EMBEDDED_RSC`).

**Two scope caveats for the parent (they qualify the fix/benefit, not the facts):**
1. The Benefit line claims the fix "removes a permanently-failing lookup from the cover path" — there is no lookup: nothing requests the key, so the registration costs nothing at runtime today beyond one `IMG_SOURCES` entry. The real saving is the phantom three-place coordination, which the finding also states.
2. The conditional wiring is not undocumented accident: STATE.md:87, DECISIONS.md:376 and QA_REGRESSION_MATRIX.md CI-08 all describe `default.png` as a deliberate *optional legacy cover override* gated on the file being dropped into the checkout. That documented intent is itself defeated by the missing requester (even a build *with* the file embedded would never display it, since no code reads `IMG.default`), so the dead-code conclusion stands — but deleting the wiring overrides a documented maintainer contract and should be confirmed as a policy call, exactly as the finding's own fix alternative ("keep the wiring only if the file is actually committed") allows.

**Duplicate check:** not a duplicate of RE-POPS-088 — the finding itself records that 089 is the split-out second limb (the never-requested registration) and 088 is the fallback-table mechanism; they share images.lua but describe different dead machinery with different fixes.

### RE-POPS-094 — VERIFIED

Evidence:
- `DrawTargetBackground(scene)`, a closure inside `WelcomeDraw.Play` (ui.lua:1793-1813), and the inline cascade in `UI.BottomDraw.Play` (ui.lua:2052-2068) were diffed by script after normalising whitespace and the parameter difference (`scene` vs `UI.CURSCENE`): the branch structure and every statement are identical — MMAIN: `IMG.BGM` else `IMG.BKG`; CREDITS/MPROFILE: `IMG.BG` else `IMG.BKG`; else `IMG.BKG` — each drawn with `Graphics.drawScaleImage(…, 0, 0, UI.SCR.X, UI.SCR.Y)`. Both also begin from `Screen.clear(UI.SCR.BGCOL)` (inside DrawTargetBackground at 1794; at the top of BottomDraw.Play at 2051).
- `DrawTargetBackground` has exactly one caller (ui.lua:1815, `DrawTargetScene`), and BottomDraw.Play runs every frame from the main loop, so both copies are live code paths (transition vs steady-state) that must be kept in sync by hand, as claimed.
- Fix sanity: the finding correctly notes the existing function is a closure inside WelcomeDraw's `Play`, so deduplication requires hoisting to a file-level local or a `UI` member rather than a direct call — that is the real (small) cost, and it is stated in the fix.

### RE-POPS-095 — VERIFIED

Evidence:
- All three implementations confirmed at the cited lines, bodies compared: system.lua:4966-4970 global `function CLAMP(a, MIN, MAX)` (if-below/if-above/return); ui.lua:14-18 file-local `Clamp01(t)` (clamp to 0..1); ui.lua:19-23 file-local `Clamp(v, lo, hi)` (same body shape as CLAMP); ui.lua:1946-1950 a second `local function Clamp01(value)` inside the splash (`WelcomeDraw`) `Play`/`StepFade` region — body identical to the file-local except the parameter name (`value` vs `t`).
- Usage claims confirmed: global `CLAMP` is genuinely used from ui.lua at 2858-2865, 3311-3312, 3679-3682 (and more, e.g. 3323, 3680-3681); file-local `Clamp` is used at exactly 1382 and 1436; the nested `Clamp01` is used at 1971, while the file-local `Clamp01` is used at line 25 (`EaseInOutCubic`). A repo-wide grep for clamp definitions in Lua returns only these (plus `CYCLE_CLAMP` in system.lua, which is a wrap-around, semantically distinct and correctly not counted).
- Fix sanity: deleting the nested copy is safe — the file-local `Clamp01` at line 14 is a file-scope local visible throughout ui.lua, including inside WelcomeDraw.Play, and nothing between line 14 and 1946 rebinds the name except the nested copy itself. Routing the two `Clamp` sites through the global is also safe on load order: system.lua defines `CLAMP` at 4966 and only `require`s ui.lua at 4978, so the global exists before any ui.lua call site can run. Both `Clamp` call sites in fact clamp to `0, 1` (1382, 1436), so they could equally go through `Clamp01` — a nit on the fix's routing choice, not on the finding.

---

## Closing tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 5 | RE-POPS-071, 072, 088, 094, 095 |
| VERIFIED-DRIFT | 3 | RE-POPS-048 (148/94/54, not 143/91/52; enumeration 50 names, 4 dead bindings omitted), RE-POPS-064 (39 Add* call sites / ≈48 rows per frame, not 37; 101 `function(` is body-wide, 97 from the items build), RE-POPS-089 (Makefile conditional wiring is 72-79 + rule 194-195, not 88-95) |
| WEAKENED | 0 | — |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — |

No finding in this chunk was refuted or weakened in its core mechanism; all three drifts are numeric/citation drift where the underlying defect is real (and for 048/064, larger than claimed).

## Candidates (new observations, not verdicts)

1. **CANDIDATE — `print_uart` is a fourth dead registration outside the luaL_Reg census.** luasystem.cpp:2660 registers the global `print_uart` via `lua_register`; grep of all four runnable Lua files finds zero uses (its siblings `doesFileExist`/`doesFolderExist` at 2658-2659 are heavily used). Same dead-surface family as RE-POPS-048 but outside its stated `luaL_Reg` scope.
2. **CANDIDATE — stale in-code comment in the 094 duplicate.** BottomDraw.Play's comment at ui.lua:2050 ("Main menu uses BGM.png; all other scenes use BKG.png") contradicts its own code directly below it, which gives CREDITS/MPROFILE the `IMG.BG` fallback — the comment describes neither copy of the cascade correctly and would mislead anyone applying the 094 dedup.
3. **CANDIDATE (fix-completeness, attached to RE-POPS-071)** — ui.lua:2614's fallback `_NormalizeLayout` independently accepts `"ABNT"` (and, divergently, `"ABC"`, which system.lua's `NormalizeKeyboardLayout` does *not* accept — the RE-POPS-043 divergence). It is unreachable in the shipped load order because `PLDR.NormalizeKeyboardLayout` always exists, but any future removal/normalizer change that touches only the sites named in 071/043 will leave this second normalizer inconsistent.
