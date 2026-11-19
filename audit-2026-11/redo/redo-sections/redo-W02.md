# REDO Audit — W02: RiptOPL `src/ui/` + `src/gfx/`

- Pin verified: `git rev-parse HEAD` = `2e347d5ac885cd0ff73e9ad4143781946396f492`
- Scope census (command-run, `wc -l`): 44 files, 34,344 lines total — `src/ui/` 25 files / 19,604 lines, `src/gfx/` 19 files / 14,740 lines.
- Rule applied throughout: LESS, NOT MORE. No finding proposes a new abstraction, framework, config option, wrapper, fallback, retry, backup, or logging system unless explicitly justified.

---

## W02-001 — Partition notification dereferences a possibly-NULL `strchr` result
- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/src/ui/guinotify.cpp:108-115`
- **Problem:** READ. In `Notifications::show()`, the `showPart_` branch does `col_pos = strchr(gOPLPart, ':'); col_pos++;` with no NULL check, then passes `col_pos` to `snprintf("%s")`. Every sibling branch in the same function (lines 120, 128, 136) does check for NULL — this one does not. If `gOPLPart` ever contains no `':'`, this is a NULL+1 dereference / undefined behaviour on the render path.
- **Fix in words:** Add the same NULL guard the sibling branches already use; skip the partition notice when there is no colon.
- **Benefit:** Removes a crash-class defect on a per-frame render path for one line.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W02-002 — Deferred dialog wait is unbounded while the sibling message wait is bounded
- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/src/ui/guiwait.cpp:49-113` (`runWithMessage`), `RiptOPL/src/ui/guiwait.cpp:115-141` (`runWithDialog`)
- **Problem:** READ. `runWithMessage()` was carefully bounded: it checks the `ioPutRequest` result, supports `timeoutMs_`, sets `gLastDeferredTimedOut`, and documents why an unbounded wait freezes the GUI on wedged storage. `runWithDialog()` checks the put result but then spins `while (*flag_)` with no timeout at all — the exact failure mode the sibling function's comments describe, one class apart in the same file.
- **Fix in words:** Give `runWithDialog()` the same elapsed-time bound `runWithMessage()` already implements (reuse its limit computation; do not add a second timeout mechanism).
- **Justification (addition):** No new mechanism — it extends an existing in-file mechanism to the one caller that lacks it, closing a documented hang.
- **Benefit:** A wedged deferred IO behind a dialog wait degrades to the caller's failure path instead of a hard freeze.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W02-003 — Self-update overwrites the running ELF in place and never verifies what landed
- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/src/ui/selfupdate.cpp:265-340` (`suInstallWorker`)
- **Problem:** READ. The download is SHA-256-verified in RAM, then written over the booted ELF with `WRONLY|CREAT|TRUNC`. After `fileXioClose`, success is reported (`suInstalledRev = suRemoteRev; suResult = SU_OK`) with no re-read or hash of the bytes actually on the device. A short/corrupted write that returns positive counts (media error, card pulled behaviour, driver quirk) leaves a damaged ELF that is reported as a successful update — and the old ELF is already gone, by design (no second file, no rename). This is not a request for a backup (banned, and the file's header explains the space constraint); the missing step is verification of the write itself.
- **Fix in words:** After close, re-open the file read-only, stream it through the same SHA-256 context type already used, and only set `SU_OK` when the on-device hash matches `suSha`; otherwise report `SU_ERR_SWAP` at a new step number. Delete nothing, add no file.
- **Justification (addition):** Adds a read-back pass only; justified by a concrete problem — today a bad write is indistinguishable from a good one and the failure is unrecoverable.
- **Benefit:** A failed update is reported as failed while the user is still in a running ELF, instead of being discovered at next boot.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ; device behaviour of a bad write is INFERRED)

## W02-004 — ~37-line include block copy-pasted verbatim into split-out GUI files, most of it unused
- **Category:** 2 duplication
- **Locations:** `RiptOPL/src/ui/guiwait.cpp:10-47`, `RiptOPL/src/ui/guigameid.cpp:10-47`, `RiptOPL/src/ui/guimodal.cpp:9-47` (near-identical block also in `RiptOPL/src/ui/gui.cpp`)
- **Problem:** READ + command-verified: the include blocks of `guiwait.cpp` and `guigameid.cpp` differ only in their final self-header. `guigameid.cpp` (212 lines: a barcode drawer) includes `httpsupport.h` ("httpTestServer() — the Network page Test button"), `tar.h`, `cheatman.h`, `pggsm.h`, `libview.h`, `hddsupport.h`, `appsupport.h`, `ethsupport.h`, `netsupport.h`, `udpfssupport.h`, `mmcesupport.h` — a symbol search of the file body finds none of them used (only the words appear inside comments). `guiwait.cpp` carries the same block with the same unused entries. The comments on the includes even describe other files' use cases, proving the block was copied whole when `gui.cpp` was split.
- **Fix in words:** Trim each split file to the headers whose symbols it actually uses; delete the rest. No shared "kitchen-sink" header — that would preserve the coupling under a new name.
- **Benefit:** ~25 dead includes removed across the two worst files; faster, clearer builds; future splits stop inheriting phantom dependencies.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ + grep-verified non-use)

## W02-005 — Two near-identical icon+text draw functions in uidraw.cpp
- **Category:** 2 duplication
- **Locations:** `RiptOPL/src/gfx/uidraw.cpp:13-57`
- **Problem:** READ. `guiDrawIconAndText` and `guiDrawIconAndLiteralText` are the same ~22-line body — icon width computation, pixmap draw, fallback `y += 10`, advance — differing only in whether the caption comes from `_l(textId)` or a literal pointer.
- **Fix in words:** Delete one: keep the literal-text version and make the ID version a one-line call that passes `_l(textId)` (the ID version's callers keep their signatures; the duplicated body goes).
- **Benefit:** One body to fix when icon metrics change; ~20 lines removed.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W02-006 — Drive enumeration duplicated between Drive Status and the File Manager
- **Category:** 2 duplication
- **Locations:** `RiptOPL/src/ui/drivestatus.cpp:77-165` (`dsScan`), `RiptOPL/src/ui/guifilemgr.cpp:174-248` (`fmScanDrives`)
- **Problem:** READ both. Both functions walk the same device set in the same order with the same calls: `MAX_BDM_DEVICES` slots via `fileXioDopen`/`bdmReadDriverName`/`dsDriverLabel`, two `mmce%d:/` probes, two memory cards via `mcGetInfo`+`mcSync`, the APA HDD via `hddModulesAreLoaded`/`hddGetSpace` formatted with `dsSizeText`. The File Manager version already reuses `dsDriverLabel`/`dsSizeText` but re-implements the scan itself, so any new device type or probe fix must be made twice.
- **Fix in words:** Have one scan produce a small list of (root, label) pairs and let each screen format/consume it its own way; delete the second enumeration loop.
- **Justification (addition):** The shared helper is justified under the main rule: the same logic exists in 2 places and sharing removes code overall (one of two ~70-line scans is deleted).
- **Benefit:** One place to add/fix a device probe; the two screens can no longer disagree about what drives exist.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

## W02-007 — Three message/hint wrapping boxes re-implement the same wrap-and-draw
- **Category:** 2 duplication
- **Locations:** `RiptOPL/src/ui/dia.cpp:75-110` (`diaDrawHint`), `RiptOPL/src/ui/guinotify.cpp:47-84` (`Notifications::render`), `RiptOPL/src/ui/guimodal.cpp:90-122` (`guiDrawWrappedLines`/`guiDrawMsgText`)
- **Problem:** READ all three. Each independently: measures text with `fntCalcDimensions`, clamps a box to screen width minus margins, calls `fntWrapText` into a fixed stack buffer (384 / 512 / 512 bytes), computes box height from line count × `MENU_ITEM_HEIGHT`, and draws rect + string. The notification version's own comment says it wraps "the way the settings hint box does (diaDrawHint)" — i.e. the third copy was written knowing the first existed.
- **Fix in words:** Keep the modal one (it is the most general: returns last Y, centres lines) and make the hint/notification paths call it or its wrapping half; delete the other two box-computations.
- **Benefit:** Wrap/clip fixes (a recurring bug class in this codebase's comments) land once instead of three times; ~60 lines removed.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

## W02-008 — FNV-1a implemented twice, in adjacent art files
- **Category:** 2 duplication
- **Locations:** `RiptOPL/src/gfx/artworker.cpp:13-24` (`focusHashValue`), `RiptOPL/src/gfx/artindex.cpp:54-71` (`ArtIndex::hashName`)
- **Problem:** READ both. Same algorithm, same constants (2166136261u / 16777619u); the artindex version adds case-folding and a length parameter, the artworker version is the plain NUL-terminated special case of it.
- **Fix in words:** Delete `focusHashValue` and call the artindex hash (or one tiny shared static in a header both already include) with the plain-string arguments.
- **Benefit:** Small, but it is exactly the kind of twin that drifts (one gets a fix, the other does not).
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W02-009 — One-line C forwarding wrappers layered over every C++ class split
- **Category:** 3 overengineering
- **Locations:** `RiptOPL/src/ui/gui.cpp:470-492` (25 wrappers in this file alone, e.g. `guiLock`→`gGui.lock()`), plus the same tail block in `RiptOPL/src/ui/guiscreens.cpp:99-109`, `RiptOPL/src/ui/guinotify.cpp:205-218`, `RiptOPL/src/ui/guisplash.cpp:245-266`, `RiptOPL/src/ui/cfgtitle.cpp:269-274`, `RiptOPL/src/gfx/artindex.cpp:26-44`
- **Problem:** READ. Each "Split out of gui.cpp/texcache.cpp" refactor introduced a class (`Gui`, `ScreenManager`, `Notifications`, `BootSplash`, `CfgTitles`, `ArtIndex`) and then re-exported every method as a free C function that does nothing but forward. Callers use the free functions; the classes are never used directly outside their own file. The class layer therefore buys no encapsulation — it is a second API surface that must be kept in sync by hand (declaration in a header, method, wrapper) for every operation.
- **Fix in words:** Pick one surface per subsystem and delete the other: either call the global object's methods directly at call sites and delete the wrappers, or flatten the classes back to free functions and delete the class. Do it per-file as files are touched, not as a big-bang rewrite.
- **Benefit:** One declaration + one definition per operation instead of three; removes a whole class of "wrapper exists, method doesn't" (and vice-versa) drift.
- **Effort:** L (total; S per file) · **Risk:** Med · **Confidence:** High (READ)

## W02-010 — Multi-view theme fallback *synthesizes* whole theme views by copying config blocks
- **Category:** 3 overengineering
- **Locations:** `RiptOPL/src/gfx/themeviews.cpp:343-544` (fallback-view synthesis: `thmViewSynthesize`, `thmSynthCopyBlock`, `thmSynthFindTemplate`, family/presenter tables), consumed at `RiptOPL/src/gfx/themes.cpp:1478-1491`
- **Problem:** READ (themeviews.cpp in full). When a theme lacks the requested view, this machinery walks up to 64 slots × 6 families, finds template blocks in a second config set, and writes synthesized `<view>.<family><j>_*` keys back into the theme's own config — a config-rewriting engine (~200 lines plus its scan/parse/inherit layers above it) whose entire purpose is to avoid showing the theme's native view. The simpler behaviour — a theme draws the views it declares; an undeclared view falls back to the native/list view — needs none of it.
- **Fix in words:** Delete the synthesis section and let `thmViewChoose`'s existing default-view fallback be the only fallback. Themes that want a view declare it, as they already must for it to look right.
- **Benefit:** ~200+ lines and an entire config-mutation surface removed; theme loading stops writing keys the theme author never wrote, so theme bugs become reproducible from the theme file alone.
- **Effort:** M · **Risk:** Med · **Confidence:** Med (READ; the user-visible cost — auto-generated views disappear — is INFERRED from the code's stated purpose)

## W02-011 — libview: a two-ring, pending/commit state machine to remember which list a page shows
- **Category:** 3 overengineering
- **Locations:** `RiptOPL/src/ui/libview.cpp:1-365` (whole file)
- **Problem:** READ in full. Remembering "PS2 or PS1 list per page" is implemented as: two parallel rings (`retainedView`, `mixedView` + `mixedViewInitialized`), per-BDM-slot *and* per-BDM-type entries (`LIB_VIEW_ENTRIES`, `bdmSlotType`), a staged pending view with its own "uses mixed ring" flag (`pendingView`, `pendingViewValid`, `pendingViewUsesMixedRing`), dirty flags, and a one-char-per-mode config encoding with two keys. Each concept is individually defended in comments, but the total state space (which ring? staged or committed? slot or type entry?) is what a reader must hold to change anything here.
- **Fix in words:** Collapse to one stored position per mode (the BDM-type seeding can stay as an initial value copied into the slot entry at attach, which `libViewBdmAttach` already effectively does), and commit a staged view by simply assigning it — delete the second ring and the pending-uses-which-ring flag. If Mixed truly needs a distinct start position, that is one extra byte per mode, not a parallel ring with its own initialized flags.
- **Benefit:** Roughly a third of the file's state variables disappear; the L3 toggle path becomes assign-and-rebuild.
- **Effort:** L · **Risk:** Med · **Confidence:** Med (READ; simplification shape is INFERRED)

## W02-012 — Grid / PSBBN / Coverflow presenters each re-walk the whole game list per frame and per keypress
- **Category:** 5 performance (structural)
- **Locations:** `RiptOPL/src/gfx/grid.cpp:504-510` (draw: count/index walk), `RiptOPL/src/gfx/psbbnflow.cpp:252-256` (draw: countRows walk), `RiptOPL/src/ui/menusys.cpp` `menuGridRow`/`menuGridPage`/`menuGridAtRowStart` (each walks `submenu` head→current to recompute count+index), plus the wrap-walk window builders in `RiptOPL/src/gfx/coverflow.cpp` (drawCoverFlow) and `RiptOPL/src/gfx/psbbnflow.cpp` (tail builder)
- **Problem:** READ. The submenu is a singly-linked list with no stored count or index. Every Grid frame walks it once just to count; every grid keypress walks it again in menusys (up to three walks for one key: at-row-start check, row step, page step); PSBBN Flow walks it per frame for its `n/N` counter. Cost is O(list length) per frame/keypress on the GUI thread, growing with library size, for values that change only when the list is rebuilt or the cursor moves one step.
- **Fix in words:** Store count and current index where the list is already maintained (append/destroy/cursor move in menusys) and have the three presenters read them instead of recounting. No new subsystem — two integers on the existing menu item.
- **Justification (addition):** Two cached integers, justified by removing an unbounded per-frame walk in three presenters plus three navigation helpers.
- **Benefit:** Frame and navigation cost becomes O(1) in library size for all three views.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ — walks verified; per-frame call of the draw functions is from their `drawElem` registration, READ)

## W02-013 — Whole-file staging for art re-grows its buffer by doubling, re-copying on every cover
- **Category:** 4 size/memory (also 5, structural)
- **Locations:** `RiptOPL/src/gfx/textures.cpp:623-735` (`texStageExternalFileIntoMemory`), cap at `RiptOPL/src/gfx/textures.cpp:160` (`TEX_STAGE_MAX_SIZE` = 8 MiB)
- **Problem:** READ. The fallback arm starts at 64 KiB and `realloc`s at double size per growth step, so a large cover is copied repeatedly as it grows; the ceiling permits an 8 MiB transient allocation per art load on a 32 MiB machine, in a path the art worker runs cover after cover. The fast path (exact-size from `lseek`) already exists in the same function — the doubling loop is the device-cannot-report-size arm.
- **Fix in words:** In the loop arm, grow geometrically but in larger steps is *not* the fix; the net-win fix is to cap the staged size at the largest cover the caches actually accept (the decode side already rejects oversize images) instead of 8 MiB, and to read in the existing 32 KiB chunks directly appended without a realloc-copy when the next chunk would cross capacity by less than one chunk. If no smaller cap can be proven from the decode limits, at minimum state the cap from those limits rather than a round 8 MiB.
- **Benefit:** Bounds worst-case transient heap per cover and removes most realloc copies on the slow-device path.
- **Effort:** M · **Risk:** Med · **Confidence:** Med (READ; the "largest accepted cover" value is INFERRED — it must be taken from the decode path before applying)

## W02-014 — Stack VLAs sized by caller-supplied lengths in keyboard paths
- **Category:** 4 size/memory (also 6)
- **Locations:** `RiptOPL/src/ui/gui.cpp:173` (`char tmp[maxLength]` in `Gui::showKeyboard`), `RiptOPL/src/ui/diaeditors.cpp:215` (`char pre[maxLen]` inside `diaShowKeyb`'s render loop)
- **Problem:** READ both. Both allocate a variable-length array on the EE stack from a length parameter. Today's callers pass bounded sizes (dialog string sizes), so this is not a demonstrated overflow — it is an unbounded-by-construction pattern: any future caller with a file- or config-derived length risks silent stack exhaustion, and VLAs defeat static stack auditing of these threads.
- **Fix in words:** Replace both with fixed buffers at the existing maximum string size (`UI_STRING_SIZE` for the dialog system), truncating to that bound exactly as the surrounding `strncpy` code already does.
- **Benefit:** Stack use becomes auditable and constant; no behaviour change for any current caller.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; "current callers are bounded" is INFERRED from the dialog string types)

## W02-015 — Unbounded `sprintf` in PadEmu info formatting (safe today only by input clamping)
- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/src/ui/guigame.cpp:1158-1173` (`hex_to_str`, `ver_to_str`), callers at `RiptOPL/src/ui/guigame.cpp:1302-1307`, destination buffers at `RiptOPL/src/ui/guigame.cpp:1137-1142` (`vid_str[5]`, `hci_str[26]`, …)
- **Problem:** READ. `bdaddr_to_str` in the same block was converted to `snprintf(addstr, 18, …)`; its two neighbours still use raw `sprintf` into 5- and 26-byte statics. They fit today only because `ver_to_str` clamps `ma` to ≤ 9 and the version strings in `bt_ver_str[]` (lines 1072-1083, READ) are short — an invariant held in three different places, none of them at the write site.
- **Fix in words:** Convert both to `snprintf` with the destination size passed or `sizeof` the known statics at the call sites, matching `bdaddr_to_str` directly above them.
- **Benefit:** The invariant moves to the write site; adding a longer Bluetooth version string can no longer overflow a static.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W02-016 — Retired main-menu slot kept in the menu ID enum
- **Category:** 1 dead code / 8 half-finished
- **Locations:** `RiptOPL/src/ui/menusys.cpp:52-55` (`MENU_RETIRED_NETWORK_UPDATE`)
- **Problem:** READ. The enum keeps a placeholder for a removed Network Update item "to keep subsequent menu IDs stable". Menu IDs in this enum are internal dispatch values assigned in this same file; nothing in the read code persists them (config stores settings IDs, not these). The placeholder is dead weight that every reader must reason about.
- **Fix in words:** Delete the placeholder and renumber, after a grep confirming no persisted use of the numeric values (the check, not the renumber, is the work).
- **Benefit:** One less phantom menu item; enum matches the actual main menu.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ; "not persisted" is INFERRED — the grep is part of the fix)

## W02-017 — Three carousel presenters duplicate the framed-cover (overlay) draw block
- **Category:** 2 duplication
- **Locations:** `RiptOPL/src/gfx/coverflow.cpp` (draw loop overlay branch), `RiptOPL/src/gfx/psbbnflow.cpp` (`drawCover` overlay branch), `RiptOPL/src/gfx/grid.cpp` (`drawCell` overlay branch)
- **Problem:** READ all three. Each presenter independently: resolves the per-item element via `thmGetElemForItem`, fetches the texture with default fallback, then — if `overlayTexture` exists — scales the four inset corners by `drawW/coverElem->width` etc. and calls `rmDrawOverlayPixmap`, plus the optional `overlayTexture2` pixmap. The inset-scaling arithmetic is copy-identical in all three (and a fourth variant exists in themeelems' `drawGameImage`).
- **Fix in words:** One shared draw helper for "cover texture inside its case overlay at (x, y, w, h)" used by the three presenters; each presenter keeps only its layout/animation maths, which is the part that actually differs.
- **Justification (addition):** Shared helper permitted by the main rule: the same logic exists in 3+ places and sharing deletes three copies of the inset arithmetic.
- **Benefit:** Overlay inset fixes (a historically fiddly, hardware-verified area) are made once; ~60 duplicated lines removed.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

## W02-018 — Debug art HUD builds a ~35-field formatted string every frame
- **Category:** 5 performance (structural) / 4 size
- **Locations:** `RiptOPL/src/ui/guioverlay.cpp` (`Overlays::drawArtHud`, the `artdbg[224]` snprintf and its ~60-line explanatory comment block)
- **Problem:** READ. When debug is enabled, every frame gathers ~15 diagnostic counters from five subsystems and formats a 224-byte, ~35-conversion snprintf, solely to draw one line. The comment block explaining the fields is longer than the code. This is debug-only, so the cost is bounded to debug use — but it sits in the always-compiled overlay path and its field list has accreted one incident at a time (each field's comment cites a different past bug).
- **Fix in words:** Format the HUD at a reduced cadence (e.g. every 15th frame — the values are human-read diagnostics) or split it into two shorter lines formatted on alternate frames. Do not add fields without removing one.
- **Benefit:** Debug builds stop paying a full multi-subsystem format on every frame; the HUD stays available for the diagnostics it exists for.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W02-019 — File Manager paste path uses aliased `strcpy` inside another call's argument
- **Category:** 6 bugs/security (fragility)
- **Locations:** `RiptOPL/src/ui/guifilemgr.cpp:446` (`fmDirSlash(parent, sizeof(parent), strcpy(target, parent))`), `RiptOPL/src/ui/guifilemgr.cpp:471` (`strcpy(fmClip[keep], fmClip[i])`)
- **Problem:** READ. Line 446 passes `strcpy(target, parent)` as the source argument to a function whose first argument is `parent` itself — correct only under a specific evaluation/aliasing reading, and unreadable enough that a future edit to `fmDirSlash` can silently break it. Line 471 uses unbounded `strcpy` between fixed `FM_PATH_LEN` clip slots (safe only because both slots share the constant — again an invariant held elsewhere).
- **Fix in words:** Split line 446 into two statements (copy, then slash) and use `snprintf(…, FM_PATH_LEN, …)` at line 471, matching the rest of the file's style.
- **Benefit:** Removes an aliasing trap and an unbounded copy for two lines of diff.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W02-020 — Boot-splash glow redraws the logo 13 times per frame
- **Category:** 5 performance (structural)
- **Locations:** `RiptOPL/src/ui/guisplash.cpp:36-62` (`BootSplash::drawLogo`)
- **Problem:** READ. The halo effect is 8 inner taps + 4 outer taps + the logo itself = 13 full-logo pixmap draws every frame for the whole boot splash, to produce a blur that a single pre-tinted, slightly larger draw cannot exactly match but that costs 13× the texture submission of the logo on the weakest part of the boot path. This is a judgement call, not a defect: the effect is deliberate and documented.
- **Fix in words:** If boot-frame cost matters, drop the 4 outer taps (weakest contribution, half alpha) and keep the 8 inner taps; otherwise delete nothing and close this as accepted cost.
- **Benefit:** ~30% fewer splash pixmap submissions if applied; zero if the effect is valued as-is.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ; visual impact is INFERRED — needs eyes on hardware)

---

## COVERAGE

### Files read in full (25)
- `src/ui/`: cfgtitle.cpp, diaitems.cpp, drivestatus.cpp, gui.cpp, guiboot.cpp, guiframe.cpp, guigameid.cpp, guimodal.cpp, guinotify.cpp, guioverlay.cpp, guiqueue.cpp, guiscreens.cpp, guisplash.cpp, guiwait.cpp, libview.cpp, menuitems.cpp, menuwatch.cpp, selfupdate.cpp, dia.cpp, diaeditors.cpp, guifilemgr.cpp
- `src/gfx/`: artindex.cpp, artqueue.cpp, artworker.cpp, atlas.cpp, coverflow.cpp, grid.cpp, plasma.cpp, psbbnflow.cpp, themeviews.cpp, uidraw.cpp

### Files read substantially (function map + targeted sections read and verified for every citation) (10)
- `src/ui/dialogs.cpp` — declarative UIItem tables; read from start through the Interface/Artwork/Colors/Launching sections and the full table-of-contents of remaining tables (no executable logic beyond initializers).
- `src/ui/guisettings.cpp` — function map plus targeted sections (name-list copy, network/game-view pickers, coverflow/audio/controller pages).
- `src/ui/guigame.cpp` — function map plus PadEmu section in full (the cited lines) and VMC/GSM/cheat section boundaries.
- `src/ui/menusys.cpp` — function map plus main-menu enum, render-main, and grid-navigation sections in full (the cited lines).
- `src/gfx/artload.cpp`, `src/gfx/texcache.cpp` — read in full apart from some comment blocks skipped on second pass.
- `src/gfx/themes.cpp` — function map plus `thmLoad` head and theme-catalog sections.
- `src/gfx/themeelems.cpp` — function map plus device-list parsing section.
- `src/gfx/textures.cpp` — header/externs plus the staging section in full (the cited lines).
- `src/gfx/renderman.cpp` — mode table and function map.

### Files NOT read in full (3) — with reason
- `src/gfx/fntsys.cpp` (1,324 lines) — function map and the `renderString`/`renderStringFit`/`fntWrapText` sections read; the FreeType glyph-cache internals were skimmed only. Reason: time; no finding is cited from the unread internals.
- `src/gfx/saveicon.cpp` (1,315 lines) — header/format documentation and function map read; the card-image FAT-walking internals were not read line-by-line. Reason: self-contained parser with its own host-test guard (`SAVEICON_HOST_TEST`); no finding cited from it.
- `src/gfx/textshape.cpp` (452 lines) — header and function map read; the Arabic-shaping/RTL tables were not audited line-by-line. Reason: data-table-driven shaping code; no finding cited from it.

No finding cites a line range that was not opened and verified in this session. Counts (44 files / 34,344 lines) are from `wc -l` output, not estimates.
