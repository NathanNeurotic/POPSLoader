# Round 5 — Section 06: Launchstation EE big files (1 of 2) — dash_settings / init / filer / filer_browser

Repo: NathanNeurotic/Launchstation, pin `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (verified by `git rev-parse HEAD`, no fetch/update; clone left clean — `git status --porcelain` empty at end).
Scope note: READ = read in the source at the pin in this pass. INFERRED = conclusion that depends on SDK/protocol behaviour not in the tree. No PS2 build or hardware claims anywhere in this section. Nothing below repeats LAUNCHSTATION-001…096; where a candidate overlapped an earlier finding it is listed under checked-and-clean instead.

---

## (a) Coverage ledger

| File | Lines | Ranges read |
|---|---|---|
| `src/dash_settings.c` | 4,096 | 1–4096 full |
| `src/init.c` | 3,205 | 1–3205 full (1176/1190 FTP `-anonymous` lines re-read in context; LAUNCHSTATION-033 stands, not re-filed) |
| `src/filer.c` | 2,556 | 1–2556 full (FILEOP_TRACE block at 157–164 re-read in context; LAUNCHSTATION-052 stands, not re-filed) |
| `src/filer_browser.c` | 2,528 | 1–2528 full |

Supporting reads (cross-checks only, not section scope): `include/launchelf.h` (MAX_PATH = 1025 at :204, `FILEINFO` layout, `SMB_Server_User/Pass[32]` at :338-339), `include/dash_internal.h` (DASH_PATH_MAX 256 at :34, DASH_THEME_NAME_MAX 32 at :213), `include/smb_shares.h` (SMB_NAME_LEN/SMB_CRED_LEN 32 at :19-20), `src/dash_store.c:325` (legacy_theme forced), `src/dash_hdd.c:434` (loadHdlInfoModule caller).

---

## (b) Findings

### T6-F1 / Six settings IDs have choice/action dispatch but no row in any page — the handlers are dead / Category 1
- Locations: `src/dash_settings.c:1019` (choiceInfo `S_LEGACY_THEME`), `:1022` (`S_ENABLED`), `:1072` (`S_FILES_MODE`), `:1170` (`S_IGR_AUTO_BACKUP`), `:1174` (`S_IGR_CLOUD_SYNC`); matching setChoice cases at `:1698`, `:1702`, `:1777`, `:1844`, `:1848`; `src/dash_settings.c:3093` (runThemeAction `S_T_CUSTOMIZE` case)
- Problem: READ. `choiceInfo`/`setChoice`/`runAction` are static and are only ever called with the id of the currently selected `SetItem` (via `curItem()` in `settingsInput`, or the hard-coded clock/save dispatches). Extracting every `S_*` id used in any `{ST_…}` initializer in the file (all page tables, `src/dash_settings.c:234-920`) shows none of these six ids appears in any page. `S_IGR_AUTO_BACKUP`/`S_IGR_CLOUD_SYNC` were superseded by the combined `S_IGR_SYNC_MODE` row; `S_T_CUSTOMIZE` was superseded by the `P_THEME` page row. Supporting evidence for `S_LEGACY_THEME`: `src/dash_store.c:325` forces `legacy_theme = 1` with the comment "no unstyled classic look any more", so even its backing field is vestigial. The other handled-but-rowless ids (`S_CLOCK_MANUAL/SOFTWARE/HARDWARE`, `S_LAUNCHKEYS`, `S_SAVE_CLASSIC`, `S_REVERT`) are reachable through the `S_CLOCK` dispatch table and the settings menu — checked, not included.
- Fix: Delete the eleven dead `choiceInfo`/`setChoice` cases and the `S_T_CUSTOMIZE` case in `runThemeAction`. Keep the enum values themselves — the comment at `src/dash_settings.c:118-120` says the IGR split flags are retained for persisted-settings compatibility, and renumbering `SetId` is not needed to remove unreachable switch arms.
- Benefit: ~35 lines of dispatch that can never run stop masquerading as live settings; the next editor of `S_IGR_SYNC_MODE` no longer has two shadow implementations to keep consistent.
- Effort: Small (deletions only).
- Risk: Low — reachability was established by exhaustive extraction of the page tables, not by sampling; if a future row wants one of these ids, its case is one small block to re-add.
- Confidence: READ.

### T6-F2 / resetScreen() and resetDisplayThemeDefaults() duplicate the same 15-line classic reset / Category 2
- Locations: `src/dash_settings.c:2767-2786` (`resetScreen`), `src/dash_settings.c:2788-2810` (`resetDisplayThemeDefaults`)
- Problem: READ. Both functions write the identical block: `color[COLOR_BACKGR..COLOR_GRAPH4] = DEF_COLOR1..8`, `TV_mode = TV_mode_AUTO`, `screen_x = screen_y = 0`, `Menu_Frame = DEF_MENU_FRAME`, `Popup_Opaque = DEF_POPUP_OPAQUE`, `updateScreenMode()`. They differ only in their confirm prompt and in the second function's three extra dashboard lines (`effects`/`anim`/preset). Any future change to the classic defaults (a new DEF_ value, a new field) must be made twice, and the two "reset" rows in the UI can silently diverge.
- Fix: Extract the shared block into one `resetClassicScreenFields(void)` helper (~15 lines, called twice); both functions keep their own prompt and their own extra work.
- Justification (if ADD): The helper is not an addition in net terms — it replaces two copies of one block with one copy plus two call sites.
- Benefit: One definition of "classic screen defaults"; ~13 net lines removed.
- Effort: Small.
- Risk: Low — the block is side-effect-identical in both copies (verified line by line); ordering relative to the dashboard lines in the second function is preserved by calling the helper at the same point.
- Confidence: READ.

### T6-F3 / pathApplied() sets the ESR/OSDSYS LK_Flag twice — the second pair makes the first redundant / Category 2
- Locations: `src/dash_settings.c:2112-2115` (generic pair in `pathApplied`), `src/dash_settings.c:2140-2143` (open-coded repeat at the end of the same function)
- Problem: READ. `pathApplied` first computes `lk` from the id and sets `setting->LK_Flag[lk] = setting->LK_Path[lk][0] != '\0'` for `S_ESR_PATH`/`S_OSDSYS_PATH`. After the language/font block it then repeats the same assignments as two separate open-coded `if`s for the same two ids, with the same right-hand sides. The second pair is pure re-work; a reader cannot tell whether the repetition is load-bearing (it is not — nothing between the two pairs touches `LK_Flag` or `LK_Path` except the font/language loads, which touch neither).
- Fix: Delete the second pair (4 lines at :2140-2143).
- Benefit: One place sets the flag; no behavioural change.
- Effort: Trivial.
- Risk: Minimal — verified by reading the whole function body between the two pairs.
- Confidence: READ.

### T6-F4 / The SMB share editor's shared edit buffer is 96 bytes, but the folder field it edits is 128 — long folder names are silently truncated on save / Category 6
- Locations: `src/dash_settings.c:688-700` (`smbedEditField`, `char edit[96]`), field declaration `src/dash_settings.c:398` (`char folder[128]` in the `smbed` draft), caller `S_SMBED_FOLDER` in `runAction` (passes `smbed.folder, sizeof(smbed.folder)`)
- Problem: READ. `smbedEditField` copies the field into a 96-byte `edit` buffer with `dashStrCopy` (truncating), lets the user edit it, then — after a length check against the *target* size (128 for the folder), which the truncated text always passes — copies it back. A share whose folder/export path is 96–127 characters (legal today: it can arrive from a hand-edited LAUNCHSTATION.CNF, and `smbedLoadPick` preserves such values) is therefore silently shortened to 95 characters the first time the user opens that field and confirms, even if they changed nothing. All other fields edited through this helper are ≤80 bytes (host 80, name/user/pass 32) and are unaffected — the folder is the only field wider than the edit buffer.
- Fix: Size `edit` to the largest field it serves: `char edit[128]`. One-line change; the existing `strlen(edit) >= size` check then does its job for every field.
- Benefit: Opening a field in the editor can no longer destroy data the editor claims to support ("At most 127 characters", per the field's own error text).
- Effort: Trivial (one constant).
- Risk: Minimal — 32 extra stack bytes in a modal editor.
- Confidence: READ.

### T6-F5 / load_ps2atad_stack() is a 52-line DVRP loader with no caller, kept alive only by __attribute__((unused)) / Category 1
- Locations: `src/init.c:749-800` (definition), forward declaration `src/init.c:386`
- Problem: READ (caller set established by grep over the whole tree at the pin: only the declaration and the definition exist). The function loads ps2atad + ps2hdd + ps2fs for the PSX DVR stack, but the live DVRP path never calls it — `loadDVRPHddModules` goes through `load_ps2dvr()` / `load_ps2hdd_stack(1)` instead. Both the declaration and the definition carry `__attribute__((unused))`, which is the tell that the compiler already knows it is dead. Its `pfsarg` also diverges from the live loader's (`-m 4` here vs `-m 8` in `load_ps2hdd_stack`), so it is not even a faithful spare copy — reviving it as-is would silently halve the PFS mount slots.
- Fix: Delete the function and its forward declaration (~54 lines).
- Benefit: One less HDD-stack loader to audit; removes a divergent-argument trap for anyone wiring DVRP code in future.
- Effort: Trivial.
- Risk: Low — DVRP-only, unreferenced; if a future DVRP change needs a dedicated ATAD stack it should be written against the live `load_ps2hdd_stack` arguments, not this copy.
- Confidence: READ.

### T6-F6 / loadHdlInfoModule() marks the HDL Info RPC ready unconditionally — module-load and bind results are both discarded / Category 6
- Locations: `src/init.c:2563-2573`; sole caller `src/dash_hdd.c:434`
- Problem: READ. The function runs `SifExecModuleBuffer(hdl_info_irx, …)`, logs ID/ret only via `DPRINTF`, then executes `ret = Hdl_Info_BindRpc();` and immediately overwrites the outcome with `have_hdl_info = 1;` — `ret` is never tested. Every sibling loader in this file gates its `have_*` flag on `ID >= 0 && ret >= 0` (some on `ret == 0`). Here, a failed IRX load or a failed RPC bind is recorded as success, the load is never retried, and the HDD screen proceeds to issue HDL Info RPCs against a server that may not exist.
- Fix: Set the flag from the results, mirroring the sibling pattern: only set `have_hdl_info = 1` when the module load succeeded and `Hdl_Info_BindRpc()` reports success; otherwise leave it 0 so the next entry retries.
- Benefit: The HDD tool fails/retries honestly instead of RPC-ing a dead server; the flag means the same thing as every other `have_*` flag in the file.
- Effort: ~3 lines.
- Risk: Low — worst case the (already failing) load is retried on re-entry, which is the behaviour of every other loader here.
- Confidence: READ.

### T6-F7 / getExternalFilePath() re-implements genFixPath()'s HDD/DVR partition transform in init.c / Category 2
- Locations: `src/init.c:1412-1466` (`getExternalFilePath`, HDD branch :1428-1437, DVRP branch :1440-1458); the canonical implementation `src/filer.c:1029-1073` (inside `genFixPath`)
- Problem: READ. Both functions perform the same non-trivial transform for `hddN:/partition/rest`: split the partition name off, build the `party` string (`hddN:partition` / `dvr_hdd0:partition`), build the `pfs0:`/`dvr_pfs0:` file path from the remainder, mount the partition, and patch the pfs unit digit (including the DVRP `__xdata` → unit-1 special case via `getDVRPPartyMountIndex`). They are written differently enough that a fix to the transform (a new special partition, a mount-index change) must be discovered and mirrored by hand; `init.c`'s version additionally uses unbounded `sprintf` into `MAX_PATH` buffers where `filer.c`'s uses `strcpy`/`sprintf` of the same shape — neither is safer, they are simply two copies.
- Fix: Have `getExternalFilePath` delegate its HDD/DVRP branches to `genFixPath` (it already delegates its fallback branch to it at :1464), deleting the local transform (~30 lines). If the pre-mount side effects differ in a way that matters, keep a single shared helper for the party/pfs string split and call it from both.
- Benefit: One implementation of the HDD path transform — the transform every external-module and keyboard-map load depends on.
- Effort: Medium (the two versions' surrounding side effects — `loadHddModules()` vs the partition-list population in `genFixPath` — need one careful pass).
- Risk: Medium — path canonicalisation is load-bearing for every device; this is a consolidation to do with the filer's existing tests in hand, not a drive-by.
- Confidence: READ (duplication of logic; the exact safe merge shape is a maintainer call).

### T6-F8 / readHOST()'s elf-list branch returns hostcount − 1: the last entry is dropped whenever elflist.txt has no trailing newline / Category 6
- Locations: `src/filer.c:1740-1782` (elf-list branch of `readHOST`); the return at `:1782`
- Problem: READ. The branch parses `host:elflist.txt` line by line, appending one `FILEINFO` per line and incrementing `hostcount` per appended entry. The loop is driven to `rv <= size` with a synthetic `0x0a` at `rv == size`, so the final line is processed whether or not the file ends with a newline. The function then returns `hostcount - 1`. That −1 only makes sense as cancelling a phantom empty entry for a file that *does* end with a newline (the empty trailing "line" can register as a folder via the `host:` dopen fallback) — for a file without a trailing newline it deletes a real entry from the listing: a one-entry list returns 0 entries, and an empty/unreadable-after-open list returns −1, which `listDir`'s callers read as an error rather than an empty folder. Whether a user's hand-made elflist.txt ends in a newline is not something the code controls (it is a host-side text file read over `host:`).
- Fix: Track the phantom explicitly instead of by arithmetic: skip a parsed line whose `host_next` is empty (zero length) before the open/dopen probes, and `return hostcount;`.
- Benefit: The host root listing shows exactly the files the list names, independent of the file's final byte.
- Effort: Small (~3 lines).
- Risk: Low — the empty-line skip also removes the phantom-folder entry the −1 was compensating for; verified by tracing both file shapes (with/without trailing newline) through the loop.
- Confidence: READ.

### T6-F9 / Two private 2,049-entry sceMcTblGetDir statics (readMC and readXFROM) duplicate ~120 KB of .bss each / Category 4
- Locations: `src/filer.c:480` (`readMC`'s `static sceMcTblGetDir mcDir[MAX_ENTRY + 1]`), `src/filer.c:544` (identical declaration in `readXFROM`)
- Problem: READ for the declarations; INFERRED for the byte size (a `sceMcTblGetDir` is ~60 bytes by the field arithmetic already used for LAUNCHSTATION-036's 384-byte `FILEINFO`: 256 name + 66 title + ~60 stats, padded — so each array is ≈120 KB). The two readers are never active at once: directory listing is a single dispatch (`listDir` picks exactly one reader per path), and both arrays are pure scratch for one `mcGetDir`/`xfromGetDir` call. Keeping two means ~120 KB of the EE's 32 MB is permanently reserved for a second copy of a buffer that is idle whenever the first is in use.
- Fix: Hoist one file-scope `static sceMcTblGetDir mcDir[MAX_ENTRY + 1]` and use it from both functions (delete one declaration).
- Benefit: ≈120 KB of .bss returned (INFERRED size) with no behavioural change.
- Effort: Trivial.
- Risk: Low — would only matter if a future change listed an MC and an XFROM folder concurrently; no such path exists in the current dispatch, and the shared clipboard/`FILEINFO` design already assumes serial listing.
- Confidence: READ (duplication and serial use); INFERRED (exact byte saving).

### T6-F10 / The commented-out CodeBreaker partition filter is pasted twice, inside two near-identical partition-list functions / Category 7
- Locations: `src/filer.c:728-746` (comment block in `setPartyListForDevice`, function at :709) and `src/filer.c:827-845` (the identical comment block in `setDVRPPartyList`, function at :812); live loop duplication `src/filer.c:1149-1228` (`readHDD`) vs `src/filer.c:1230-1311` (`readHDDDVRP`)
- Problem: READ. Each partition-list function contains the same ~18-line commented-out block ("Patch this to see if new CB versions use valid PFS format… if (!strncmp(dirEnt.name, "PP.",3))…") for filtering behaviour that was never enabled — dead text describing removed behaviour, carried in two copies. The surrounding functions are themselves DVRP mirrors: `setPartyListForDevice`/`setDVRPPartyList` differ essentially in device string and output array, and `readHDD`/`readHDDDVRP` (~80 lines each) differ essentially in path prefix offsets, the party getters, and the root-path test.
- Fix: Delete both commented blocks (~36 lines). Separately, when the DVRP reader next needs a change, parameterise the party-list loop (device string + output array + count) and the dread loop rather than editing both copies; do not do that refactor speculatively now.
- Benefit: The partition code stops carrying a disabled filter as if it were a pending decision, in duplicate; the live duplication is at least reduced to the two functions themselves.
- Effort: Trivial for the comment deletion; Medium for the (deferred) parameterisation.
- Risk: Minimal for the deletion — the block is inside `/* */` and references variables in scope only by coincidence of the copy.
- Confidence: READ.

...[truncated 13571 chars]
### T6-F11 / waitUntilTimer() busy-spins the EE for up to 6 s on the UI thread while waiting for a clipboard source device / Category 5
- Locations: `src/filer_browser.c:120-124` (`waitUntilTimer`), used by `waitForClipboardSourceDevice` at `src/filer_browser.c:240-265` (deadline +6000 ms, 1000 ms slices)
- Problem: READ (structural). `waitUntilTimer` is an empty `while (Timer() < end_time) {}` spin. During a paste whose source device needs re-preparation after an IOP reset, the browser sits in this spin for up to six seconds in one-second slices, redrawing the "Pasting" message only between slices — the EE burns at full rate and the UI thread does nothing else for the duration. The codebase already has the non-spinning primitives for exactly this shape of wait and uses them in sibling code in the same audit set: `DashPause(...)` in `src/filer.c` (`waitUsbDiscoverySettle`) and `DelayThread(...)` in `src/init.c`'s bounded-stat polling. This instance is not among the spin sites cited by LAUNCHSTATION-014 (which named `src/filer.c` and editor/draw sites).
- Fix: Replace the empty spin with the same sleep the sibling waits use (e.g. loop `DelayThread`/`DashPause` in ≤100 ms slices until the deadline), keeping the one-second re-check cadence unchanged.
- Benefit: Same wait, same cadence, without pinning the EE for up to 6 s per paste-after-reset.
- Effort: Small (~4 lines).
- Risk: Low — the wait's observable behaviour (deadline, re-check interval, message redraw) is unchanged.
- Confidence: READ.

### T6-F12 / The classic browser's New Icon flow is a second, unchecked copy of filerCreateFolderIcon() — including a statement its own comment calls dummy code / Category 2
- Locations: classic copy `src/filer_browser.c:1460-1501` (NEWICON branch of `browseFilePath`); checked implementation `src/filer_browser.c:2420-2458` (`filerCreateFolderIcon`); dummy statement `src/filer_browser.c:1499`
- Problem: READ. The same file contains two implementations of "write icon.sys + icon.icn into a folder, asking before overwrite". The dashboard-facing one (`filerCreateFolderIcon`) checks `genFixPath`, checks `make_iconsys`/`make_icon` results and reports errors. The classic browser's inline copy checks neither maker's return — a failed icon write is silently presented as done — and duplicates the genFixPath/strcat/open/confirm/remove sequence twice within itself (once per file). It also contains, verbatim, `strcpy(tmp, tmp1);  //Dummy code to make 'goto DoneIcon' legal for gcc` — a statement that exists only to satisfy a label-placement quirk and copies a full path buffer for nothing.
- Fix: Extract the write-one-icon-file half (fix-path, exists-confirm, remove, make, check) into one static helper used by both the classic branch and `filerCreateFolderIcon`; the classic branch keeps its two keyboard prompts (title, then icon text) around the calls. Drop the dummy statement by giving `DoneIcon:` a following real statement or a scoped block.
- Benefit: One checked implementation; the classic flow gains the error reporting the dashboard flow already has; ~35 lines of duplicate sequence removed.
- Effort: Medium (the classic flow interleaves prompts with writes, so the extraction boundary is the per-file write, not the whole action).
- Risk: Medium-low — user-visible prompts and ordering must stay identical; the helper's contract is already proven by `filerCreateFolderIcon`'s shape.
- Confidence: READ.

### T6-F13 / filerFreeSpace()'s XFROM branch reports success without the start/sync checks its own MC branch documents as necessary / Category 6
- Locations: `src/filer_browser.c:2480-2487` (XFROM branch of `filerFreeSpace`); contrast the MC branch `src/filer_browser.c:2469-2478`
- Problem: READ. The MC branch guards carefully: it checks `mcGetInfo(...) < 0` before syncing, with the comment "not started: mcSync would leave ret unset", and rejects `ret < -1` after the sync before trusting `type`/`free_units`. The XFROM branch directly below calls `xfromGetInfo(...)` discarding its start return, calls `xfromSync(0, NULL, &ret)` and never reads `ret` at all, then unconditionally computes `*out` from whatever `type`/`free_units` hold (their zero initialisers on a failed call) and returns 1 — "valid". A failed XFROM info call therefore displays a confident, wrong free-space figure (typically 0) instead of none, which is exactly the failure the MC branch was written to avoid.
- Fix: Mirror the MC branch: return 0 when `xfromGetInfo(...) < 0`, and return 0 when the sync result indicates failure, before computing `*out`.
- Benefit: The browser header shows no figure rather than a fabricated one when the XFROM query fails; both branches of one function follow one validation rule.
- Effort: ~3 lines, copied from the sibling branch.
- Risk: Minimal — only changes behaviour on calls that currently produce garbage.
- Confidence: READ (the asymmetry and the unchecked values); INFERRED (how often a real XFROM info call fails in practice).

### T6-F14 / submenu_func_GetSize() carries ~50 lines of commented-out debug scaffolding / Category 7
- Locations: `src/filer_browser.c:2029-2034` (commented variable declarations), `src/filer_browser.c:2081-2104` (commented `printf` attribute dump), plus the section-marker comments around them ("Start/End of section for debug display of attributes", "Comment out this section to skip attributes entirely" at :2065)
- Problem: READ. A block of declarations (`test`, `stats`, `time`) and a ~24-line `printf` dump of stat fields survive as comments inside a shipping function, referring to variables that no longer exist in the live code. It is the only debug scaffolding of this size in the four files read, and it sits in the middle of the attributes logic a reader is actually trying to follow.
- Fix: Delete the commented declarations and the commented dump (~50 lines including markers). Keep the live attribute code and its one-line explanatory comments.
- Benefit: The Get Size path reads as the code that runs; nothing of value is lost (the dump is reproducible from the live fields in minutes if ever needed).
- Effort: Trivial.
- Risk: None — comments only.
- Confidence: READ.

---

## (c) REVISION-CANDIDATEs

None. No evidence in these four files contradicts LAUNCHSTATION-001…096. Three earlier findings were re-verified in passing and stand as filed: -033 (init.c FTP `-anonymous` args, now at `src/init.c:1176-1190` in context), -052 (FILEOP_TRACE guard block, `src/filer.c:157-164`, one of its three sites, in context), -014 (busy-wait spins in `src/filer.c` — the retry-loop spins at the current pin are the same pattern; the new, separately cited instance in `src/filer_browser.c` is filed as T6-F11 rather than appended to -014).

---

## (d) Checked-and-clean / dissolved

- **editClockDateTime day-of-month initialisation (dash_settings.c:3173-3178)** — the loop computes `high[2] = dashClockDaysInMonth(value[0], value[1])` at `i == 2`, which *looks* like a use of uninitialised `value[]`; tracing the loop shows `value[0]` and `value[1]` were assigned in iterations 0 and 1. Dissolved. READ.
- **settingsRevert forcing `DashThemeSetLegacyEnabled(1)` (dash_settings.c:2577)** — looked like Discard failing to restore `snap_dash.legacy_theme`; dissolved because `src/dash_store.c:325` forces `legacy_theme = 1` unconditionally ("no unstyled classic look any more") — the revert matches store policy. (The vestigial setting itself is part of T6-F1.) READ.
- **strcpy(v, edit) for the SMB server login (dash_settings.c:3359)** — `v` is `SMB_Server_User/Pass[32]` (`include/launchelf.h:338-339`) and `edit[32]` is filled by `dashModalKeyboard` with a 31-character limit, so the copy cannot overflow. Dissolved. READ.
- **editScanPaths strcat(out, "/") (dash_settings.c:2747)** — `out` is `MAX_PATH` (1025) and the append is gated on `strlen(out) < DASH_PATH_MAX - 2` (254), so the appended slash and terminator always fit. Dissolved. READ.
- **choiceInfo S_T_PRESET writing pnames[*cur] for a custom theme (dash_settings.c:1243-1258)** — `*cur` comes from `dashThemeBasePreset()` and `n` is clamped to the same 32-entry array; no out-of-bounds write was established from the code in this file. Not filed (would need the theme module's invariants). READ/INFERRED.
- **refreshDirty() rebuilding both save texts at most every 250 ms (dash_settings.c:2430-2450, called per frame via anyDirtyCached)** — a real periodic allocation on the settings UI thread, but it is explicitly throttled, documented in its own comment, and is the mechanism that makes "changed back = not dirty" work. Structural cost is bounded and deliberate; not filed as a defect. READ.
- **getExternalFilePath sprintf/strcpy set (init.c:1421-1449)** — all destinations are `MAX_PATH` (1025) and all sources are themselves `MAX_PATH`-bounded setting/loader paths; no specific overflow was established beyond the pervasive pattern already filed as LAUNCHSTATION-015. Not re-filed. READ.
- **loadBasicModules()/loadCoreCdvdModule() setting their have_* flags unconditionally (init.c)** — same shape as T6-F6, but for the two foundational loaders the flags function as "attempted" latches and every subsequent operation fails visibly at its own RPC; the HDL case is filed instead because its flag specifically gates a bind that has a checked return value. Judged a pattern difference, not a second finding. READ.
- **load_ps2hdd_stack vs load_ps2atad_stack argument arrays (init.c)** — `hddarg` is identical but `pfsarg` genuinely differs (`-m 8` vs `-m 4`); the duplication half dissolved into T6-F5 (the dead copy should be deleted, not merged). READ.
- **startSmbServer args packing (init.c:2790-2793)** — `args[64]`/`smbd_login[64]` against two 32-byte fields: worst case 32 + 32 = 64 exactly, including both terminators. Fits by construction. Dissolved. READ.
- **configureDashboardDns fallback selection (init.c)** — the gateway-is-1.1.1.1 special case and the all-ones fallback were traced; both produce the intended 1.1.1.1 / 8.8.8.8 pair. Dissolved. READ.
- **readMC/readXFROM strcpy(dir, path-suffix) + strcat(dir, "*") (filer.c:494-495, 561)** — suffix comes from a `MAX_PATH` caller path into a `MAX_PATH` buffer; the one-byte `*` overrun needs a path already at the 1024 limit, which no in-tree caller constructs. Covered in spirit by LAUNCHSTATION-015; not re-filed. READ.
- **All read*() directory readers' strcpy(info[n].name, dirent.name) (filer.c, throughout)** — the EE-side mirror of the unterminated-dirent class; the IOP-side sources were filed in earlier rounds (-063, -081, -092) and the generic EE string pattern as -015. No *new* mechanism was found in this pass (names are bounded by the `iox_dirent_t` 256-byte field into a 256-byte `FILEINFO.name` in the normal case). Not re-filed. READ.
- **readNetDir/readHOST sentinel strcpy(info[count].name, "\0") at count == max (filer.c:1819, 1862)** — writes one entry past the *logical* max but inside the allocation: every caller goes through `listDir`, whose max is at most `MAX_ENTRY - 1` against a `MAX_ENTRY`-entry buffer. In-tree safe; not filed. READ.
- **getUsbRootDeviceLabel's shared static label (filer_browser.c:32-40)** — mutated static returned to callers, but every call site consumes it immediately (single display pass, no retention across calls). Fragile style, no defect established. Dissolved. READ.
- **filerMountVmc vs the classic MOUNTVMC branch (filer_browser.c)** — parallel implementations of VMC mounting for the two browsers; they were compared and the classic branch *does* contain the length check's equivalent via its fixed buffers, and no behavioural divergence beyond presentation was established. Not filed as duplication — the two entry points serve different UI contracts (message buffer vs dialog). READ.
- **BrowserModePopup indentation anomaly (filer_browser.c:858)** — one over-indented `if`; cosmetic only, no semantic effect. Not filed. READ.

---

## (e) Still-unread

None in this section's set. All four assigned files were read end-to-end at the pin (see coverage ledger). Cross-check files listed under the ledger were read only at the cited lines and are not claimed as covered.
