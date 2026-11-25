# POPSLoader — Independent Blind Redo Audit — Lua Section

- Repo: NathanNeurotic/POPSLoader, clone `~/workspace/audit-clones-2026-11-13/POPSLoader`, pin `29272cddbf01` (master, verified with `git rev-parse`).
- Scope: all Lua — `bin/POPSLDR/system.lua` (11,784 lines), `bin/POPSLDR/ui.lua` (7,599), `bin/POPSLDR/images.lua` (93), `etc/boot.lua` (181). Lua-facing C bindings were grepped only to judge whether a Lua name is reachable from C; the C side was not audited.
- Method: full-text script censuses over all four files (function-definition inventory, per-name occurrence counts across Lua + `src/*.cpp`/`src/*.c`, duplicate-block detection, per-language i18n key-set comparison) plus paged manual reads. Every `file:line` below was re-verified against the file before writing. Counts are by script (`grep -c` / `wc` / Python), never estimated.
- Rule applied: LESS, NOT MORE — remove / simplify / consolidate / fix only.

---

### RE-POPS-LUA-01 — The "ABC" on-screen keyboard layout can never be selected: the system normalizer silently converts it to QWERTY
- Category: 6
- Locations: bin/POPSLDR/system.lua:2508, bin/POPSLDR/system.lua:2527-2546, bin/POPSLDR/system.lua:5904, bin/POPSLDR/system.lua:5967, bin/POPSLDR/system.lua:6015, bin/POPSLDR/system.lua:6451, bin/POPSLDR/ui.lua:2533, bin/POPSLDR/ui.lua:2570-2578, bin/POPSLDR/ui.lua:2610-2627, bin/POPSLDR/ui.lua:4691, bin/POPSLDR/ui.lua:4812-4817, bin/POPSLDR/ui.lua:5094-5097
- Problem: `PLDR.KEYBOARD_LAYOUT_ABC = "ABC"` is defined (system.lua:2508), the OSK offers ABC in `layout_order` (ui.lua:2533) with a complete row definition (ui.lua:2570-2578), and the Settings "Keyboard Layout" row cycles through it (ui.lua:4691, 5094-5097). But `NormalizeKeyboardLayout` (system.lua:2527-2546) has branches only for QWERTY/DVORAK/AZERTY/QWERTZ/ABNT and falls through to QWERTY for "ABC". Every path that touches the value normalizes it — encode (5904), snapshot (5967), apply (6015), load (6451), the settings commit (ui.lua:4548-4549), and the PathEditor's own `_NormalizeLayout` (ui.lua:2610-2612), which delegates to the system function whenever it exists, so the editor's own correct ABC-accepting fallback (ui.lua:2614-2619) is unreachable in the real load order. `_CurrentRows` (ui.lua:2621-2627) therefore always resolves "ABC" to the QWERTY rows. The comments even assert the opposite of the code: system.lua:2545 and 6241 say "ABC remains selectable / stays selectable", and ui.lua:4812-4814 claims Reset Defaults' `"ABC"` default works "via NormalizeKeyboardLayout's fall-through" — the fall-through returns QWERTY. Net effect: a user who picks ABC gets QWERTY in-session and on every reboot, with no error.
- Fix: Add the missing ABC branch to `NormalizeKeyboardLayout` in system.lua (one comparison against the already-defined `PLDR.KEYBOARD_LAYOUT_ABC`), so the one normalizer every consumer already routes through accepts the sixth layout it advertises. No new code paths; the ui.lua fallback copy then agrees instead of being dead.
- Benefit: A shipped, selectable setting starts working as labelled; removes a silent settings-loss bug on save/load and a false claim repeated in three comments.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-LUA-02 — Dead HDD readable-path resolver that is a near-verbatim subset of the live one
- Category: 1
- Locations: bin/POPSLDR/system.lua:944-972 (dead), bin/POPSLDR/system.lua:887-923 (live twin)
- Problem: Local `ResolveHddGamePartitionReadablePath(partition, relpath)` has zero callers anywhere in Lua or C (full-text occurrence count = 1, its own definition). Its body duplicates `ResolveHddPartitionReadablePath` almost line for line — same `ParseHddPartitionMount` guard, same recorded-prefix probe (`GetRecordedHddMountPrefix` + `BuildMountedReadablePath` + `ProbePathExists`), same mount-and-probe tail — differing only in which mount helper it calls. A duplicate-block scan flags the two bodies as the largest intra-file duplication in system.lua. Keeping a second, unexercised copy of mount logic invites the next fix to land in one copy only.
- Fix: Delete `ResolveHddGamePartitionReadablePath` (29 lines). If a game-partition-specific readable path is ever needed, call the live resolver, which already takes slot/hint parameters.
- Benefit: −29 lines of mount logic to maintain; one resolver to fix and to reason about for the D-10-class HDD paths.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-LUA-03 — Four defined-but-never-called functions, including one polluting the global namespace
- Category: 1
- Locations: bin/POPSLDR/system.lua:2153-2155, bin/POPSLDR/system.lua:4972-4976, bin/POPSLDR/system.lua:10364-10378, etc/boot.lua:179
- Problem: Full-text search across all Lua and `src/*.cpp`/`src/*.c` finds exactly one occurrence (the definition) for each of: `PLDR.GetBootKind()` (a one-line wrapper over `ResolveBootContext().kind`; the sibling `PLDR.GetBootContext` at 2149 is used, this one is not), `CYCLE_CLAMP(a, MIN, MAX)` (a **global**, unlike its used sibling `CLAMP` at 4966 which ui.lua genuinely calls), local `GetBootOccupiedPfsSlot()` (its helper `ExtractLaunchPfsSlot` is used in five other places; this wrapper is not), and `STOP()` in etc/boot.lua (a red-screen infinite loop defined at boot and never invoked from Lua or C).
- Fix: Delete all four definitions. Nothing else changes; no caller exists to update.
- Benefit: −~25 lines; one less boot-time global (`CYCLE_CLAMP`) that any future chunk can accidentally shadow or call expecting wrap-around semantics nobody tested.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-LUA-04 — Dead exported surface: unused PLDR/UI members, a load-time probe whose result nobody reads, and a self-described dead flag
- Category: 1
- Locations: bin/POPSLDR/system.lua:2202-2204, bin/POPSLDR/system.lua:2224, bin/POPSLDR/system.lua:4950-4957, bin/POPSLDR/system.lua:5615-5617, bin/POPSLDR/system.lua:5695, bin/POPSLDR/ui.lua:6851
- Problem: Each of these is written and never read (occurrence count = definition only, checked across Lua + C): (a) `PLDR.EnsureTrailingSlashNorm` (5615-5617), a public wrapper over the local `EnsureTrailingSlashNormRaw` that no file calls; (b) `PLDR.HDD_FS_VALUES = {"PFS","EXFAT","BOTH","DISABLED"}` (5695) — ui.lua ignores it and hard-codes its own identical list as `HDD_FS_SEQ` (ui.lua:5161); (c) `PLDR.MX4SIO.PREFIX_HINT` — `DetectMX4SIOPrefixHint()` (4950-4956) performs a `doesFileExist` probe for a `.boot_mx4sio` marker at every boot and stores the result at 4957 (default at 2224), and no code anywhere reads the field, so the probe is pure boot cost; (d) the export `UI.ResolveSelectedVcdPath = ResolveSelectedVcdPath` (ui.lua:6851) — the local is used internally (ui.lua:3783, 3950, 4289) but the `UI.` member is never referenced by system.lua or C; (e) `PLDR.HDD.USECACHE = false` (2204), whose own comment at 2202 states "USECACHE is a dead legacy flag now".
- Fix: Delete the five items (for (c), delete the probe function, its assignment, and the defaults entry together). Keep the locals/flags that are actually used (`EnsureTrailingSlashNormRaw`, `PLDR.NormalizeHddFs`, the local `ResolveSelectedVcdPath`).
- Benefit: Removes a per-boot file probe with no consumer, two divergent copies of the HDD-FS value list, and API surface that misleads future callers into thinking these are supported entry points.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-LUA-05 — ART_LOCATION: a removed setting still plumbed through ~10 live sites as inert cargo
- Category: 8
- Locations: bin/POPSLDR/system.lua:5913, bin/POPSLDR/system.lua:5975, bin/POPSLDR/system.lua:6038-6039, bin/POPSLDR/system.lua:6250, bin/POPSLDR/system.lua:6402, bin/POPSLDR/system.lua:6484-6485, bin/POPSLDR/system.lua:6587-6588, bin/POPSLDR/ui.lua:3175-3178, bin/POPSLDR/ui.lua:4495, bin/POPSLDR/ui.lua:4524, bin/POPSLDR/ui.lua:4580, bin/POPSLDR/ui.lua:5218-5221
- Problem: The Settings row for ART_LOCATION was removed (EXP35) and cover/details lookup is hard-locked to `<device-root>/ART/` — `BuildCoverCandidates` builds `artdir` from the device root and never consults ART_LOCATION (ui.lua:233-285). ui.lua:5218-5221 itself says the value "is kept inert in the settings file only so older sidecars still parse". Yet the value still flows end-to-end as if live: a UI draft is snapshotted on Settings entry (ui.lua:3175-3178), validated and committed (ui.lua:4495, 4524, 4580), encoded into every save (system.lua:5913), snapshotted (5975), applied (6038-6039), defaulted (6250), parsed on load (6402, 6484-6485), and merged in the settings-commit path (6587-6588). Every one of those sites must be understood and kept consistent for a value that changes nothing.
- Fix: Drop the value from the encode/snapshot/apply/commit/UI-draft plumbing; on load, simply ignore an `ART_LOCATION=` line if present (old sidecars still parse — unknown/absent keys are already the norm in this parser). Keep nothing but that tolerance.
- Benefit: ~10 touch-points and one draft/commit field removed; the settings pipeline gets shorter everywhere it is already hardest to verify, with zero behaviour change.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-LUA-06 — Twenty stale translation entries whose source strings no longer exist in the code
- Category: 1
- Locations: bin/POPSLDR/system.lua:2629, bin/POPSLDR/system.lua:2772, bin/POPSLDR/system.lua:2936, bin/POPSLDR/system.lua:3079, bin/POPSLDR/system.lua:3244, bin/POPSLDR/system.lua:3387, bin/POPSLDR/system.lua:3552, bin/POPSLDR/system.lua:3695, bin/POPSLDR/system.lua:3859, bin/POPSLDR/system.lua:4002, bin/POPSLDR/system.lua:4155, bin/POPSLDR/system.lua:4198, bin/POPSLDR/system.lua:4214, bin/POPSLDR/system.lua:4306, bin/POPSLDR/system.lua:4315, bin/POPSLDR/system.lua:4331-4332, bin/POPSLDR/system.lua:4358, bin/POPSLDR/system.lua:4377-4378
- Problem: `PLDR.L(s)` can only ever translate a string that exists somewhere in the Lua as a source string. A key-set comparison (every i18n key vs. every string occurrence outside the i18n block, both Lua files + boot.lua) shows these keys occur nowhere else: (a) the superseded SMB warning `"SMB modules are not installed\nGames will list but won't boot -- install them\nvia Settings > SMB modules first"` in six languages (FR 2772, DE 3079, PT 3387, ES 3695, IT 4002, HU 4358) — the live notification at ui.lua:3920 uses different wording, which has its own, separate entries; Slovak already dropped the stale key, proving the cleanup was done for one language only; (b) `"Cover/details folder"` in six languages (FR 2629, DE 2936, PT 3244, ES 3552, IT 3859, HU 4198) — the label of the ART_LOCATION row removed in EXP35 (see RE-POPS-LUA-05), surviving only inside a code comment; (c) eight Hungarian-only orphans whose English sources appear nowhere: `"ART (at root)"` (4155), `"Don't Save"` (4214), `"POPS (beside game)"` (4306), `"Profile defaults restored"` (4315), `"Save Settings"` (4331), `"Save your changes before leaving?"` (4332), `"X = Keep      O = Revert"` (4377), `"X = Select      O = Cancel"` (4378).
- Fix: Delete these 20 entries. No code changes; untranslatable-by-construction entries cannot be reached by `PLDR.L`.
- Benefit: −20 entries of translator-maintained text that can never render; the per-language key sets stop implying coverage that does not exist (notably SK 409 keys vs ~304-317 for the other six languages is partly this drift).
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-LUA-07 — The entire translation database is inlined in system.lua: 2,276 lines / 172,314 bytes parsed on every boot, including for English users
- Category: 4
- Locations: bin/POPSLDR/system.lua:2568-4843
- Problem: By script: the `PLDR.I18N` literal spans 2,276 lines and 172,314 bytes — 30% of system.lua's 568,668 bytes — holding 2,249 entries across seven languages (FR 304, DE 305, PT 305, ES 304, IT 305, HU 317, SK 409). It is part of the main chunk, bin2c-embedded into the ELF, and constructed as a table at every boot before any UI appears, even though `PLDR.L` (system.lua:4844-4854) returns the input untouched for the default `EN` and only ever reads the single active language's sub-table. An English user pays the full parse/table cost for seven languages they will never select; every language addition grows the main chunk, which the code itself notes is near Lua's 200-local cap (system.lua:5795, 5171).
- Fix: Move `PLDR.I18N` out of system.lua into one data chunk per language (or one chunk holding all seven), loaded lazily the first time `PLDR.L` is called with a non-EN language (and on language change), leaving system.lua with the lookup function only.
- Justification: This adds one lazy-load step, which is justified by a concrete problem: it removes 172 KB of dead-at-boot data from the critical chunk for the default language, and it is the only way to stop translation growth from pressuring the main chunk's local cap. Net win is structural (smaller boot chunk, pay-only-for-selected-language), not a new abstraction — the table, keys, and fallback semantics are unchanged.
- Benefit: system.lua shrinks by ~19% of its lines; boot no longer constructs 2,249 unused entries for EN users; translators edit a data file instead of the launch-critical chunk.
- Effort: M · Risk: Med · Confidence: Med (INFERRED — sizes and counts are script-measured and READ; the per-boot parse cost itself was not measured on hardware)

### RE-POPS-LUA-08 — Settings screen rebuilds its entire item list — and ~100 fresh closures — on every rendered frame
- Category: 5
- Locations: bin/POPSLDR/ui.lua:4351, bin/POPSLDR/ui.lua:4383-4391, bin/POPSLDR/ui.lua:4407-4460, bin/POPSLDR/ui.lua:4929
- Problem: The Settings scene's `Play` function (starting ui.lua:4351) is a per-frame draw/input handler dispatched from the main loop. Inside it, every frame: five constant `Color.new(...)` values are re-created (4383-4391), roughly ten helper closures are redefined (`TruncateMiddle`, `CycleIndex`, `clear_settings_session`, `restore_settings_session`, `discard_settings_and_return`, `queue_exit`, …, 4407-4460), and the item list is rebuilt from scratch — `local items = {}` at 4929 followed by, by script count over the Play body (4351-5914), 37 `AddSection/AddSpacer/AddCycle/AddInfo/AddPath/AddAction` calls whose arguments include 101 `function(` closure literals (each cycle row passes four fresh anonymous functions for value/prev/next/dirty). None of this depends on frame-varying state except the values the getters read; the structure only changes when the user enters/leaves Settings.
- Fix: Build the items table and its row closures once when the Settings scene is entered (the existing `UI.SyncSettingsDraftFromRuntime` / scene-entry point already runs there), store it on `UI`, and let `Play` only read focus/dirty state and draw. Hoist the five constant colors next to the other file-level colors (ui.lua:120-121 shows the pattern already used for list colors).
- Benefit: Eliminates ~100+ closure allocations plus a 37-row table rebuild per frame for as long as Settings is open — the most allocation-dense screen in the UI — with no behaviour change.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-LUA-09 — The PLDRGC1 game-list cache format is implemented twice (parser ×2, builder ×2)
- Category: 2
- Locations: bin/POPSLDR/system.lua:9880-9897, bin/POPSLDR/system.lua:9899-9936, bin/POPSLDR/system.lua:9944-9990, bin/POPSLDR/system.lua:9991-10030
- Problem: `PLDR.LoadGameListCache` (per-device cache) and `PLDR.HDD.ReadCache` (HDD cache) contain the same ~25-line parse loop verbatim in structure: `PLDRGC1` magic check on the first line, `S ` signature check against `PLDR.GameListCacheSignature()`, `G `/`H ` record accumulation, `\r$` stripping, and the same `sig_ok`/`#games == 0` rejection — differing only in whether the result is returned or assigned to `PLDR.HDDCACHE`. The writers repeat the same header/signature/`G`/`H` line construction (`PLDR.SaveGameListCache` 9880-9897 vs `PLDR.HDD.CreateCache` 9944-9990). A format change (new record type, stricter magic) must currently be made in four places; the two parsers have already had parallel "Codex F5" size-cap fixes applied separately (9906, 10001), showing the drift cost is real.
- Fix: Extract the one parse loop into a single local `ParseGameListCache(data)` returning games/hidden or nil, and one line-builder local; have all four public functions call them and keep only their storage-specific parts (path, write mechanism, assignment).
- Benefit: One implementation of a file format that is read back across boots and versions; format fixes land once instead of being ported between twins.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-LUA-10 — StripVcdExtension is defined independently in both Lua files
- Category: 2
- Locations: bin/POPSLDR/system.lua:10181-10187, bin/POPSLDR/ui.lua:122-125
- Problem: The same operation — strip a trailing `.VCD` in any case with `string.gsub(s, "%.[Vv][Cc][Dd]$", "")` — exists as a local in system.lua (10181, nil/empty-guarded, used by `DeriveGameNameFromSelection`) and as a local in ui.lua (122, `tostring`-coercing, used for list display). ui.lua already depends on system.lua globals loaded before it (`JoinPath`, `CLAMP`), so the duplication is not a load-order necessity. Two copies of a filename-grammar rule is exactly how display names and launch names drift apart (the ui.lua comment block at 99-121 documents a past truncation bug in this very operation).
- Fix: Keep one implementation (the system.lua one, exposed the way `JoinPath` already is) and delete the ui.lua local, calling the shared one at its single ui.lua call site (3355).
- Benefit: One definition of the .VCD-strip grammar for both the launch path and the display path.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-LUA-11 — The scene-background image cascade is written out twice inside ui.lua
- Category: 2
- Locations: bin/POPSLDR/ui.lua:1793-1813, bin/POPSLDR/ui.lua:2052-2068
- Problem: `DrawTargetBackground(scene)` in the Welcome/splash scene implements the full cascade — main menu: `IMG.BGM` else `IMG.BKG`; credits/profile: `IMG.BG` else `IMG.BKG`; otherwise `IMG.BKG` — and `UI.BottomDraw.Play` then re-implements the identical cascade inline against `UI.CURSCENE` (2052-2068), statement for statement. Any change to background policy (a new scene class, a new fallback image) must be made in both, and the splash transition and the steady-state draw can silently disagree.
- Fix: Delete the inline copy in BottomDraw and call the existing cascade logic (hoisted to a file-level local or a `UI` member, since the current one is a closure inside the Welcome scene's `Play`).
- Benefit: One background policy for both the transition path and the per-frame path; −~16 duplicated lines.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-LUA-12 — Three clamp implementations, one of them a same-name shadow inside a single function
- Category: 2
- Locations: bin/POPSLDR/system.lua:4966-4970, bin/POPSLDR/ui.lua:14-18, bin/POPSLDR/ui.lua:19-23, bin/POPSLDR/ui.lua:1946-1950
- Problem: Clamping is implemented three times: the global `CLAMP` in system.lua (4966, genuinely used by ui.lua, e.g. 2858-2865, 3311-3312, 3679-3682), a file-local `Clamp` in ui.lua (19-23, used at 1382, 1436), and a file-local `Clamp01` in ui.lua (14-18) — which is then **shadowed by a second, identical `Clamp01` defined inside the splash `Play` function** (1946-1950), so that function alone uses its own private copy while the rest of the file uses the file-local one. Nothing distinguishes them semantically.
- Fix: Delete the nested `Clamp01` at 1946-1950 (the file-local at 14 is in scope there) and, opportunistically, route ui.lua's two `Clamp` call sites through the already-global `CLAMP` and delete the ui.lua local. Keep `Clamp01` (0..1 specialisation) as the only second form.
- Benefit: One less shadow that invites an edit to the wrong copy; the clamp vocabulary of the codebase drops from three spellings to two.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-LUA-13 — The ABNT keyboard layout is a selectable layout whose rows are byte-identical to QWERTY
- Category: 8
- Locations: bin/POPSLDR/ui.lua:2558-2569, bin/POPSLDR/ui.lua:2579-2587, bin/POPSLDR/system.lua:2513
- Problem: The ABNT layout table (ui.lua:2561-2569) and the QWERTY table (ui.lua:2579-2587) were compared by script: the seven row tables are identical apart from the layout name. The in-code comment (ui.lua:2558-2560, and system.lua:2513) explains why — ABNT's distinguishing keys (ç, accents) are non-ASCII and the OSK is single-char ASCII, so they are "intentionally absent". The result is a Settings choice that changes nothing at all when selected: same keys, same order, same symbols. It presents as a feature and behaves as a second name for QWERTY.
- Fix: Remove ABNT from `layout_order` (ui.lua:2533), the `layouts` table, and `NormalizeKeyboardLayout`'s accepted keys (system.lua:2540-2542) — or, if Brazilian users must keep a persisted `ABNT` value parsing, let the normalizer keep accepting it but map it to QWERTY explicitly instead of offering it in the UI. Do not keep a UI-selectable no-op.
- Benefit: One fewer layout to cycle through that does nothing; persisted-value handling stays honest (existing `ABNT` sidecars normalize instead of displaying a phantom layout).
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-LUA-14 — Game-list scene carries two permanently-empty scaffolding tables and an unreachable "Not implemented yet" branch, evaluated every frame
- Category: 8
- Locations: bin/POPSLDR/ui.lua:3254-3255, bin/POPSLDR/ui.lua:3266-3280
- Problem: Inside `UI.GameList.Play` (per-frame), the code builds `local titles = {}` (3254), looks up `titles[UI.CURSCENE]` (always nil), then builds `local placeholders = {}` (3266) and tests `placeholders[UI.CURSCENE]` (always nil) around a stub branch that prints "Not implemented yet" and adds a footer legend. The comments concede the state: "Table kept empty so a genuinely-new backend could still opt back into a title" and "No scenes are placeholders anymore… Keeping the (now-empty) table + guard so a genuinely-unimplemented future backend can still opt into the stub render." That is speculative scaffolding for a hypothetical future backend, running (and allocating two tables) on every game-list frame today.
- Fix: Delete both tables, both lookups, the title draw guarded by the always-nil `scene_title`, and the whole placeholder branch. A future backend can re-add a stub when it exists; version control keeps this version.
- Benefit: Removes dead branch + per-frame allocations from the hottest scene in the app, and removes a "Not implemented yet" string (and its translations) that no user can ever see.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-LUA-15 — images.lua: a fallback mechanism that can never fire, and a registration for an image that is never requested and usually not embedded
- Category: 1
- Locations: bin/POPSLDR/images.lua:36, bin/POPSLDR/images.lua:46, bin/POPSLDR/images.lua:63-72, Makefile:72-77
- Problem: (a) `IMG_FALLBACKS` (images.lua:46) is a file-local table that is only ever read, in the `__index` fallback branch (63-72); nothing in any Lua or C file ever writes a key into it, so the branch is dead machinery in the lazy image loader's hot path. (b) The registration `{"default", "default.png"}` (images.lua:36) is never requested — `IMG.default` / `IMG["default"]` occurs nowhere in Lua or C (the game list uses `IMG.cover_default`) — and its asset is optional by design: the Makefile (72-77) embeds `default.png` only if the file happens to exist in the checkout, and it does not exist in this tree (`bin/POPSLDR/IMG/` has no `default.png`). The registration therefore resolves to a permanent `IMG_FAILED` entry on first (never-occurring) use.
- Fix: Delete the `IMG_FALLBACKS` table and its branch in `__index`, and delete the `"default"` registration row. (If a fallback is ever actually needed, the AGENTS.md asset rule already requires coordinating Makefile + embed_assets.cpp + images.lua — re-add it then, populated.)
- Benefit: The image loader's `__index` becomes a straight source→load→cache path; one phantom asset disappears from the three-place asset coordination the repo documents as error-prone.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-LUA-16 — Three trailing-slash helpers where one mechanism suffices
- Category: 3
- Locations: bin/POPSLDR/system.lua:23-32, bin/POPSLDR/system.lua:167-171, bin/POPSLDR/system.lua:221-240
- Problem: system.lua maintains `EnsureTrailingSlash` (23-31, additionally exported as `_G.EnsureTrailingSlash` at 32), `EnsureTrailingSlashNormRaw` (167-171, normalize-then-slash), and `NormalizeDirPath` (221-231), which re-implements the slash guarantee inline (`gsub "/+$" → "/"`, then append if missing) instead of using either helper; `JoinPath` (232-240) builds on the third. The plain and "NormRaw" variants differ only in whether backslash/slash collapsing runs first — a distinction every caller must currently know by heart, across ~15 call sites scattered through the file (1548, 1784, 10292, 10533-10534, 11128, 11463, …). This is the kind of near-duplicate path helper family that produced the file's long history of subtly different path spellings.
- Fix: Consolidate on one helper: keep `EnsureTrailingSlashNormRaw` (the normalizing form is safe for every current plain-form call site, whose inputs are already device paths), rename/keep it as the single trailing-slash function, reimplement `NormalizeDirPath`'s tail in terms of it, and drop the `_G.EnsureTrailingSlash` export after moving its few call sites (1548, 1784, 10292, 10533-10534, 11128, 11463) to the survivor.
- Benefit: One slash rule for the whole chunk; path-spelling behaviour can be fixed in exactly one place instead of three.
- Effort: M · Risk: Med · Confidence: High (READ)

---

## FILES READ

- `bin/POPSLDR/system.lua` — 11,784 lines. Read in paged manual chunks covering the path/HDD-mount helpers, boot-context, defaults, settings encode/snapshot/apply/load/commit, SMB spec/parsers, startup backend init, game-list caches, launch-policy/selector builders and the main-program tail; the whole file was additionally processed line-by-line by script for the function inventory, occurrence counts, and duplicate-block detection cited above.
- `bin/POPSLDR/ui.lua` — 7,599 lines. Read in paged manual chunks covering the local helpers, CoverCache, footer/flip, splash, modal, PathEditor/OSK, game list, settings scene, main menu/carousel, credits, and the UI tail (network flows, SMB field helpers); whole file likewise script-processed for inventories and counts.
- `bin/POPSLDR/images.lua` — 93 lines, read in full verbatim.
- `etc/boot.lua` — 181 lines, read in full verbatim.
- `AGENTS.md` (repo root) — read in full (house rules / preservation contracts), used only to avoid mislabelling documented invariants.
- Grepped only (not audited, per scope): `src/luasystem.cpp`, `src/luagraphics.cpp`, `src/embed_assets.cpp`, `src/main.cpp`, `src/fntsys.cpp`, `Makefile` — searched for registered Lua names (`lua_register` / binding tables), embedded-asset entries for the IMG keys, and the `default.png` embed rule, solely to judge Lua-side deadness.

## FILES NOT READ / NOT FULLY READ

- `bin/POPSLDR/system.lua:2568-4843` (the `PLDR.I18N` tables): **not proofread translation-by-translation.** Every entry was processed by script — per-language key counts, key-set differences between languages, and key-vs-code occurrence checks (the basis of RE-POPS-LUA-06/07) — and individual entries were read wherever cited, but the linguistic correctness of the 2,249 translations was not assessed.
- All C/C++ sources (`src/*.cpp`, `src/*.c`, `iop/`, `modules/`): not read except for the targeted greps listed above; no C-side findings are made or implied.
- All other repository files (docs, `STATE.md`, workflows, POPSTARTER binaries, images under `bin/POPSLDR/IMG/` beyond the directory listing used for RE-POPS-LUA-15): not read; out of the assigned Lua scope.
- Nothing under `~/workspace/Sable-audit/` was read, listed, or opened (hard blind rule).
