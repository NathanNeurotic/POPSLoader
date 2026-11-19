# PS2-Servers — Blind Redo Audit: Launcher GUI / Library Layer + Leftovers (LNCHC)

- **Clone:** `~/workspace/audit-clones-2026-11-13/PS2-Servers` @ `c5f021c4d38698860f56b03498adc261dbb8d8dd` (verified with `git rev-parse HEAD`)
- **Method:** every in-scope file read fully from code only; all counts/censuses by script; every cited file/symbol grep-verified to exist. No file under `~/workspace/Sable-audit/` was read, listed, or grepped.
- **Scope totals (by script):** 26 files, 9,386 lines. `launcher/gui.py` alone is 3,786 lines / 188,891 bytes.
- **Asset census (by script):** `launcher/assets/` contains exactly 4 files, 639,109 bytes total — `theme/LOGO.png` (602,983 B), `theme/ICON_SMB.png` (12,166 B), `theme/ICON_UDPFS.png` (12,266 B), `theme/ICON_UDPBD.png` (11,694 B). **All 4 are referenced** (`launcher/theme_assets.py:11-16`, `launcher/asset_skin.py:11-15,27`, `launcher/gui.py:1523`, `launcher/tray_linux.py:71`, `build/build.py:244`, `.github/workflows/release.yml:284-287`). There are **no orphan assets**; the asset problem is size, not orphans (LNCHC-12).

---

### LNCHC-01 — GUI behaviour is assembled by stacked monkey-patches, including a custom import-hook finder in `launcher/__init__.py`
- **Category:** 3
- **Locations:** launcher/__init__.py:14-92; launcher/asset_skin.py:152-164; launcher/full_skin_controls.py:10-204; launcher/gui.py:439 (the `_build` being patched)
- **Problem:** Importing the `launcher` package installs a `sys.meta_path` finder + loader wrapper (`_GuiFinder`/`_GuiLoader`, __init__.py:58-92) whose only job is to intercept the future import of `launcher.gui` and replace `LauncherApp._build` with a wrapper that calls `asset_skin.install()` and `dependency_panel.add_panel()` *before* the original build. `asset_skin.install` then patches `ttk.Notebook.add` globally (asset_skin.py:42-56) and invokes `full_skin_controls.install`, which in turn replaces `ServerCard._build`, `ServerCard.reset_to_defaults/apply_page_settings/revert_to_defaults`, and `LauncherApp.apply_server_settings/revert_server_defaults` (full_skin_controls.py:10-204). The docstring in `__init__.py` itself concedes "The normal, boring implementation would be direct calls from the GUI build path." The result is that what the GUI actually does cannot be determined from `gui.py` alone, patch order is load-bearing (dependency panel and skin must run pre-build; tab icons post-build), every patcher needs its own `_ps2_*_patched` guard flag, and import tooling/freezers must tolerate a bespoke finder at position 0 of `meta_path` for the lifetime of the process.
- **Fix:** Delete the meta-path finder/loader from `__init__.py` entirely and make the two direct calls (`asset_skin.install(self, gui_module)` / `dependency_panel.add_panel(self, gui_module)`, or plain in-module equivalents) at the top of `LauncherApp._build` in gui.py; likewise call the `full_skin_controls` setup directly instead of via `asset_skin`. Keep the existing idempotence guards only where a genuine re-entry exists.
- **Benefit:** Removes ~78 lines of import machinery, one whole failure mode (finder interfering with other importers), and makes the build path readable in one file; no behaviour change intended.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### LNCHC-02 — Zero-caller symbols: `AVAST_GEN_PUBLIC_NOTE`, `theme_assets.photo()`, `LauncherApp.on_close()`, `LauncherApp._quit_from_tray()`, and a double wrapper in dependency_panel
- **Category:** 1
- **Locations:** launcher/release_metadata.py:73-79; launcher/theme_assets.py:68-76; launcher/gui.py:3562-3563; launcher/gui.py:3774-3775; launcher/dependency_panel.py:43-48
- **Problem:** Repo-wide grep (all files, excluding `.git`/`__pycache__`) returns exactly one hit for `AVAST_GEN_PUBLIC_NOTE` — its own definition; nothing in code, build scripts, tools, or tests references the Avast submission note. `theme_assets.photo()` (the `subsample=` variant) has zero callers: both real call sites use `photo_fit` (asset_skin.py:20, gui.py:1523). `LauncherApp.on_close()` has zero callers — window close is wired to `_on_window_close` — and `_quit_from_tray()` has zero callers — tray quit flows through `_tray_queue` → `_drain_tray` → `exit_app()`. In dependency_panel.py, `summarize_status_for_ui()` (43-44) is a one-line forward to `optional_deps.summarize_statuses()`, and `_status_bits()` (47-48) is a one-line forward to `summarize_status_for_ui()`: two indirection layers for a single call, used at dependency_panel.py:53,60.
- **Fix:** Delete all five: the Avast constant (move the text to the existing `ANTIVIRUS-NOTICE.md`/docs if it must be kept), `photo()`, `on_close()`, `_quit_from_tray()`, and both dependency-panel wrappers (call `optional_deps.summarize_statuses()` directly at the two use sites).
- **Benefit:** ~30 lines gone; removes the false impression that the Avast note is displayed somewhere and that `photo()` is a supported loader entry point.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — grep-verified zero external references)

### LNCHC-03 — `ps1_index.py` is a complete PS1 scanner with no consumer in the launcher
- **Category:** 8
- **Locations:** launcher/ps1_index.py:1-147 (whole file; scanner at 88-147)
- **Problem:** The module implements a finished, bounded scan of POPSTARTER `POPS/*.VCD` files and Ember `EMBER/games/<name>/` folders, with launchability validation (`ember_name_problem`, 52-61) and a deliberately PS2-safe descriptor type (`Ps1Game`, 34-47). Grep over `launcher/*.py` shows no import or use of `ps1_index`/`Ps1Game` anywhere outside the module itself — its only consumers are tests, and the project's own capability matrix describes it as "not shown in the Library tab yet". Meanwhile PS1/VCD handling that *is* shipped goes through a different path (`game_library.MEDIA_TYPES["POPS"]`, game_library.py:19-21), so the Ember/POPSTARTER knowledge exists only in dead-ended code that must still be maintained and tested.
- **Fix:** Either surface it in the existing LIBRARY tab (one list, reusing `LibraryPanel`) or delete the module and its tests until the feature is scheduled. Do not keep a third, invisible index.
- **Benefit:** Removes 147 lines of unmaintainable-in-practice code (or, if surfaced, removes the duplication of PS1 knowledge between it and `game_library`).
- **Effort:** S (delete) / M (surface) · **Risk:** Low · **Confidence:** High (READ — grep-verified no launcher consumer)

### LNCHC-04 — Two parallel library subsystems: two catalogue databases, two folder preferences, two importers, two backups, two UIs
- **Category:** 2
- **Locations:** launcher/game_library.py:58-85,132-193,227-375; launcher/library_catalog.py:105-176,467-642; launcher/library_gui.py:14-446; launcher/library_panel.py:58-561; launcher/gui.py:641-648,1416-1421
- **Problem:** The launcher ships two game libraries over the same games folders. (a) Databases: `game_library.Library` creates `<config>/library/achievement-catalog.sqlite3` (game_library.py:63) while `library_catalog.Catalog` creates `<config>/library/catalog.sqlite3` (library_catalog.py:105-106) — two SQLite catalogues in the same directory, with different `games` schemas. (b) Folder preference: `LibraryPanel` persists the games root to a private text file `library/games_root.txt` (library_panel.py:69,87-91,175-187), while `LibraryWindow` persists it in the shared config as `game_library_folder` (library_gui.py:27-28,133-143) — the two windows can silently point at different roots. (c) Import: `Catalog.import_image/import_images` (library_catalog.py:467-512, `copyfileobj` into an `xb` file) duplicates `Library.install/transfer` (game_library.py:299-375, temp file + validation + `publish_new`) with different safety rules and different supported kinds (CD/DVD only vs CD/DVD/POPS). (d) Backup: `Library.backup` (game_library.py:178-193) duplicates `Catalog.backup_sqlite` (library_catalog.py:619-642), and `Library.import_catalog`'s automatic pre-import backup duplicates it a third time in intent. (e) UI: the LIBRARY tab (`LibraryPanel`, gui.py:1416-1421) and the RetroAchievements "Manage game library…" window (`LibraryWindow`, gui.py:641-648) both offer browse/scan/list/import/backup/cover-repair/guide over overlapping data.
- **Fix:** Pick one catalogue as the catalogue: keep `library_catalog.Catalog` (it is the one the LIBRARY tab and the shared index use) and reduce `game_library.Library` to its genuinely distinct job — the RetroAchievements hash/compatibility store (`image_status`, `Compatibility`) — deleting its `games` table CRUD, `import_catalog`, `backup`, and cover-repair catalogue role; store the games root in one place (the shared config key) for both windows.
- **Benefit:** One schema, one root preference, one import path with one set of safety rules, one backup implementation; eliminates the whole class of "the two windows disagree" bugs.
- **Effort:** L · **Risk:** Med · **Confidence:** High (READ)

### LNCHC-05 — Three setup guides and two first-run mechanisms; the standalone LibraryPanel guide is unreachable in the shipped app
- **Category:** 2
- **Locations:** launcher/setup_guide.py:9-119; launcher/library_panel.py:16-30,82-85,509-561; launcher/library_gui.py:416-424; launcher/gui.py:1661-1694,3539-3541
- **Problem:** Setup guidance exists three times with three different texts: the six-step `setup_guide.STEPS`/`SetupGuide` window, the five-step `library_panel.GUIDE` with its own hand-rolled Previous/Next window (library_panel.py:513-561), and a third, unrelated prose summary hardcoded in `LibraryWindow.guide()` as a messagebox string (library_gui.py:416-424). Worse, the LibraryPanel guide window is dead in production: `LibraryPanel._guide()` delegates to `app._open_ps2_setup_guide` whenever that attribute exists (library_panel.py:513-519), and the panel's only instantiation is inside `LauncherApp` (gui.py:1416-1421), which always defines that method (gui.py:1685-1694) — so the 49-line standalone window and its `GUIDE` tuple can only execute in tests that pass a stub app. First-run state is likewise doubled: the panel tracks completion in a marker file `library/first_run_complete` (library_panel.py:70,509-512,548-556) while the app tracks it as `ps2_setup_guide_status` in the config (gui.py:1677-1682,3539-3541), and both layers independently decide to auto-show a guide on first run (library_panel.py:82-85 vs gui.py:1661-1675).
- **Fix:** Delete `library_panel.GUIDE`, the standalone guide window in `_guide()`, the `guide_marker`/`_show_first_run_guide` machinery, and `LibraryWindow.guide()`'s prose; every "Setup guide" button calls the one `SetupGuide`, and first-run state lives only in `ps2_setup_guide_status`.
- **Benefit:** ~90 lines and one entire guide text gone; users can no longer be shown two different "first run" guides with different step counts.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ)

### LNCHC-06 — Four separate games-folder scanners/indexers over the same trees
- **Category:** 2
- **Locations:** launcher/library_catalog.py:266-368 (`Catalog.scan_detailed`); launcher/game_library.py:227-286 (`Library.installed`); launcher/library_index.py:109-190 (`read_index`); launcher/ps1_index.py:88-147 (`scan`)
- **Problem:** The same question — "which game images are under this root?" — is answered by four independent implementations with four different contracts: `scan_detailed` walks the tree itself (bounded, link-rejecting, media inferred from a top-level CD/DVD ancestor); `Library.installed` walks only the top level of CD/DVD/POPS and optionally overlays an index snapshot; `read_index` does not walk at all but re-stats and re-validates every catalogue row; `ps1_index.scan` walks POPS/EMBER with its own link/case rules. Each has its own limits (100,000 / unbounded-with-cancel / 10,000 / 10,000), its own result type (`ScanResult` / list-of-dicts / `IndexSnapshot` / `(games, problems)`), and its own notion of media/kind/layout, so behaviour differs by which window the user opened (e.g. a nested image is UNKNOWN-media via one path, invisible via another, "nested path" via a third).
- **Fix:** Keep `scan_detailed` as the single tree walker that populates the catalogue, and `read_index` as the single read path out of it; make `Library.installed` a thin filter over `read_index` output (plus its POPS top-level case) instead of a walker, and fold `ps1_index` in or out per LNCHC-03.
- **Benefit:** One traversal/link/depth policy to audit for safety; scan results become identical regardless of entry point.
- **Effort:** L · **Risk:** Med · **Confidence:** High (READ)

### LNCHC-07 — `Library.installed()` re-validates every path up to three times per call, and `Catalog.list_games()` stats every verified row on every listing
- **Category:** 5
- **Locations:** launcher/game_library.py:227-286; launcher/library_catalog.py:94-103 (`_scan_path`),178-218 (`list_games`/`_current_identity`)
- **Problem:** `_scan_path` is expensive by design: it `lstat`s every path component and then `resolve(strict=True)`s the whole path. `Library.installed()` calls it once for each media directory, once for *every file* in those directories, then — when an index is supplied — again for every result row while building its `available` dict, and again for every indexed game, even though `read_index` already performed the same `_scan_path` validation when it built the snapshot (library_index.py:157-158). A refresh of the RA library window therefore does 2–3 full containment resolutions per image on top of the index's own pass. Separately, `Catalog.list_games()` runs `_current_identity` on every returned row (up to the 10,000-row LIMIT), and for each row whose cached status is verified/conflict that does a fresh `Path.stat()` + fingerprint string build (library_catalog.py:206-218) — i.e. a filesystem stat per row on every search keystroke-driven refresh and panel reload, purely to detect staleness that the scan/inspect paths already check.
- **Fix:** In `installed()`, trust the snapshot `read_index` already validated in the same call chain (drop the second and third `_scan_path` rounds; keep the root-mismatch check, which is string comparison). In `list_games()`, only run the staleness stat for the page actually displayed, or mark staleness during scan/inspect instead of on read.
- **Benefit:** Library refresh goes from O(3×paths × components) resolutions + O(rows) stats to one validated pass; noticeable on large/network game folders, which are this app's normal case.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### LNCHC-08 — Two independent ISO9660 directory parsers (PS2 `disc_identity` vs PS1 `ps1_vcd`)
- **Category:** 2
- **Locations:** launcher/disc_identity.py:66-185 (`_IsoReader.root/find/extent/inspect`); launcher/ps1_vcd.py:20-152 (`VcdImage.root/extent/find/path_extent`)
- **Problem:** Both modules hand-roll the same ISO9660 work — locate the primary volume descriptor at sector 16, parse the root directory record, walk directory records matching a filename, extract LBA/size extents, then find SYSTEM.CNF and follow its BOOT/BOOT2 line — with divergent strictness: `disc_identity` verifies both-endian fields, rejects multi-extent/interleaved records, budgets reads/records, and detects ambiguous duplicates; `ps1_vcd` reads little-endian only, takes the first name match, splits on `;` instead of validating the version, and has different size limits (`MAX_DIRECTORY`/`MAX_BOOT` vs `MAX_DIRECTORY_BYTES`/`MAX_CNF_BYTES`). A parsing fix or a malformed-image lesson learned in one parser does not exist in the other. (The sector-mapping difference is real — VCD sectors are 2352-byte raw with a 0x100000 header — but that is a `read(offset,length)` adapter difference, not a reason to duplicate record walking.)
- **Fix:** Extract nothing new as a framework: move the directory-record walking (`root`/`find`/`extent` over a `read(offset,length)` callable) into `disc_identity`'s reader shape and have `VcdImage` supply only its raw-sector `read`; keep each module's own SYSTEM.CNF/BOOT semantics and limits as parameters already present at the call sites.
- **Justification:** The shared helper is justified only because the identical record-walking logic exists in exactly these 2 places and sharing it removes one full copy (~60 lines) overall.
- **Benefit:** One ISO9660 parser to harden; PS1 hashing inherits the duplicate/ambiguity and byte-order checks the PS2 inspector already has.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### LNCHC-09 — The PS2 disc-serial pattern is re-expressed five times, in five files, with five slightly different rules
- **Category:** 2
- **Locations:** launcher/art_fetch.py:32; launcher/disc_identity.py:21-22; launcher/game_library.py:163; launcher/library_catalog.py:30; launcher/ps1_index.py:30
- **Problem:** Grep for the serial pattern finds: `art_fetch._OPL_ID` (`^([A-Z]{4})_(\d{3})\.(\d{2})$`), `disc_identity.SERIAL` (unanchored fullmatch use), `disc_identity.FILENAME_SERIAL` (prefix with lookahead), an inline `re.fullmatch(r"[A-Z]{4}_\d{3}\.\d{2}", serial)` inside `Library.repair_cover` (game_library.py:163), `library_catalog.SERIAL_PREFIX` (prefix *stripper* with a trailing-separator requirement), and `ps1_index._PS1_NAME_ID` (dot optional). The PS1 variant legitimately differs, but the four PS2 expressions are the same concept — canonical `XXXX_NNN.NN` — re-derived per module, so they drift independently (e.g. `repair_cover` accepts only the `_` form while `filename_serial` accepts `_`/`-`; `SERIAL_PREFIX` requires a trailing separator the others do not). Each consumer then re-implements the `_`↔`-` conversion too (`serial_forms`, art_fetch.py:56-62; manual `.replace("-", "_")` at library_catalog.py:225 and art_fetch.py:158).
- **Fix:** Keep one canonical definition where it already lives (`disc_identity`: `SERIAL`/`FILENAME_SERIAL`/`filename_serial`) and import it in `art_fetch` and `game_library` instead of re-writing the pattern; leave `SERIAL_PREFIX` (a title-stripping operation, not a validation) and the PS1 pattern alone.
- **Benefit:** Serial acceptance becomes consistent across cover repair, art download, and identity inspection; ~3 pattern copies and the duplicate conversions gone.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — census by grep, quoted above)

### LNCHC-10 — Console artwork conversion is implemented twice, with different palette rules and different write paths
- **Category:** 2
- **Locations:** launcher/game_library.py:132-176 (`Library.repair_cover`); launcher/library_catalog.py:120-135 (`_artwork_palette_image`),545-578 (`Catalog.write_art`)
- **Problem:** Both code paths turn a downloaded/chosen image into the 8-bit palette PNG RiptOPL requires, and both even carry the same explanatory comment about FASTOCTREE/RGBA — but they disagree: `repair_cover` always converts to RGBA, thumbnails to 512×512, and quantizes with FASTOCTREE, while `_artwork_palette_image` uses FASTOCTREE only when real transparency is present and MEDIANCUT on RGB otherwise. They also write differently: `repair_cover` saves via a temp file + `os.replace` for the library cover but temp file + `publish_new` (hardlink) for the ART copy, while `write_art` writes with `xb` directly. The same source image therefore produces different console artwork depending on whether the user repaired it from the RA window or imported/repaired it from the LIBRARY tab, and size limits differ too (16 MB / 16 MP in `repair_cover`; 10,000 px / 50 MP in `write_art`).
- **Fix:** Make `repair_cover` call `Catalog.write_art`'s conversion (i.e. `_artwork_palette_image`) for both its outputs and keep only its download/size gate; delete its inline quantize block.
- **Benefit:** One palette policy, one set of image limits, one write protocol for all console artwork.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### LNCHC-11 — Two incompatible "has this file changed?" stamps for the same images
- **Category:** 2
- **Locations:** launcher/game_library.py:256,477; launcher/disc_identity.py:37-46; launcher/library_index.py:165-176
- **Problem:** Change detection for a game image is formatted two ways: `game_library` builds `"{size}:{mtime_ns}:{ctime_ns}"` inline in both `installed()` (256) and `Compatibility.check()` (477) and stores it in `image_status.stamp`, while `disc_identity.fingerprint()` builds `"{dev}:{ino}:{size}:{mtime_ns}[:{ctime_ns}]"` (ctime omitted on Windows, deliberately) and the catalogue/index store *that* in `disc_identity.fingerprint`. `library_index` then emits the game_library format again as `IndexedGame.stamp` (165-176). The two formats disagree on Windows ctime semantics — the exact platform subtlety `fingerprint()`'s comment says it exists to handle — so the RA cache and the identity cache invalidate on different events for the same file.
- **Fix:** Use `disc_identity.fingerprint()` in the two `game_library` sites and for `IndexedGame.stamp`; delete both inline format strings. (Existing stored stamps simply miss once and are rewritten.)
- **Benefit:** One invalidation rule, including the documented Windows ctime behaviour, for every cache that tracks an image.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### LNCHC-12 — `LOGO.png` is 603 KB at 1229×1185 for display slots of at most 256 px; downscaling is integer-only subsampling
- **Category:** 4
- **Locations:** launcher/assets/theme/LOGO.png (602,983 bytes, 1229×1185, measured by script); launcher/theme_assets.py:78-92; launcher/gui.py:1523-1524; launcher/tray_linux.py:71-76
- **Problem:** The logo is 94% of all shipped theme-asset bytes (603 KB of 639 KB). Its largest consumers are: the About tab at `max_width=150, max_height=150` (gui.py:1523-1524), the Linux tray resized to 64×64 (tray_linux.py:74), and the release workflow's AppImage icon resized to 256×256 (`.github/workflows/release.yml:284`). Nothing ever shows it above 256 px. The Tk loader makes this worse: `photo_fit` can only shrink by integer `subsample` (theme_assets.py:85-92), so the 1229-px source is decoded in full and subsampled by 9 for the About tab — full decode cost and memory for a 137-px result, every launch.
- **Fix:** Re-encode the shipped LOGO.png at 256×256 (the largest real consumer) — a data change, no code change; keep the ICON_*.png files as they are (203×100 for a 56×28 slot is proportionate).
- **Benefit:** ~590 KB off every download/AppImage and off the in-memory decoded image; no visible change at any display size in the app.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED — dimensions/sizes measured with PIL/`file`; display sizes READ)

### LNCHC-13 — `gui.py` embeds ~10 KB of About/manual prose that is mutated at runtime by another module
- **Category:** 4
- **Locations:** launcher/gui.py:126-221 (`ABOUT_TEXT`, 10,223 characters / 96 lines by script count); launcher/gui.py:1656 (sole display site)
- **Problem:** A full user manual — server descriptions, the port-445 service-pausing explanation, firewall policy, direct-link behaviour, troubleshooting, credits — lives as a triple-quoted literal inside the 3,786-line GUI module, is extended by two further `+=` appends in the same file (gui.py:208,210), and is then mutated *again* at import/startup time from outside the module (`launcher/main.py` appends its `ADMIN_ABOUT_TEXT`/`UNIX_ABOUT_TEXT` to `gui.ABOUT_TEXT`). The displayed text therefore exists in no single file, cannot be edited as documentation, and overlaps in content with the setup guides (LNCHC-05) and the server-card help strings. Tests must assert against prose substrings to keep it honest.
- **Fix:** Trim `ABOUT_TEXT` in place to what an About tab needs (what it is, the mode list in one line each, links/credits — the Links buttons already sit directly above it) and delete the duplicated firewall/direct-link/troubleshooting prose, which is already covered by the guides and card help; do not replace it with a new docs mechanism.
- **Benefit:** Several KB and ~60 lines out of the largest file in the launcher; one less runtime-mutated global; About stops drifting against the guides because it no longer restates them.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — size counted by script)

### LNCHC-14 — Three competing application-icon sources: shipped LOGO, a 246-line procedural icon generator, and a tray fallback badge
- **Category:** 3
- **Locations:** launcher/app_icon.py:1-246; launcher/tray_linux.py:61-95; launcher/assets/theme/LOGO.png; launcher/gui.py:1523-1524
- **Problem:** `app_icon.py` exists, per its own docstring, "so the source tree does not need binary assets" — it rasterizes a "PS2" glyph icon pixel-by-pixel in pure Python (`_GLYPHS`, `_rgba_pixels`, `_draw_text`, `_ico_image`, `tk_photo` with per-pixel string building at 91-113) to produce the window/taskbar/EXE icon. But the tree *does* ship a binary logo (LOGO.png, used for the About tab and the Linux tray), and `tray_linux._icon_image` contains a *third* icon: a Pillow-drawn rounded-rectangle "PS2" badge used when LOGO.png is missing. The app therefore has three different visual identities depending on platform/surface, and maintains 246 lines of bitmap code — including a hand-built ICO encoder — to avoid using the asset it already ships.
- **Fix:** Pick one source: use LOGO.png for the Tk window icon and tray (both already have that code path), and keep only `write_ico`'s ICO container writing fed from the shipped image for the Windows/build consumers; delete the glyph rasterizer (`_GLYPHS`, `_rgba_pixels`, `_draw_square`, `_draw_text`, `tk_photo`'s pixel loop) and the tray fallback badge.
- **Benefit:** ~200 lines of pixel code gone; the icon the user sees is the same artwork on every surface.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### LNCHC-15 — The "shared index" is wrapped in two pass-through layers on top of `read_index`
- **Category:** 3
- **Locations:** launcher/library_index.py:109-190; launcher/library_catalog.py:451-454; launcher/game_library.py:288-296
- **Problem:** `read_index(database, root, …)` is the whole feature, yet callers reach it through two additional named layers: `Catalog.indexed_games()` is a 4-line method whose body is only `return read_index(self.path, …)`, and `Library.shared_index()` is a 9-line wrapper whose only added behaviour is translating one `FileNotFoundError` case into a friendlier `ValueError`. The three names (`read_index` / `indexed_games` / `shared_index`) for one operation force every reader to check whether the layers differ, and the panel, the RA window, and tests each picked a different layer to call.
- **Fix:** Delete `Catalog.indexed_games` (its one production caller, library_panel.py:326, can call `read_index(db.path, …)` directly) and inline `shared_index`'s single error translation at its two call sites in library_gui.py, or keep only `shared_index` and delete the Catalog method — one wrapper maximum.
- **Benefit:** One obvious entry point for the index; ~13 lines and one layer of indirection gone.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### LNCHC-16 — Dependency checks are never cached: every panel refresh re-probes lz4 and re-`LoadLibrary`s libchdr candidates; the PATH cache is process-stale
- **Category:** 5
- **Locations:** launcher/optional_deps.py:50-68,139-190; launcher/dependency_panel.py:51-69,71-83
- **Problem:** `check_libchdr()` walks all candidate directories, mutates `PATH`/DLL directories via `_prepare_native_dir`, and calls `ctypes.cdll.LoadLibrary` on candidates until one succeeds (optional_deps.py:165-190) — and it is re-run in full on every `check_all()`, which happens on panel creation (`refresh_status_async`), on every "Check" click (`refresh_status`), and again inside "Details" via a direct `check_libchdr()` call. Nothing memoizes a successful load, so the panel's lifetime cost is repeated native loads and repeated `PATH` prepends guarded only by module-level sets. Conversely, `_known_path_dirs()` caches the process `PATH` snapshot forever in `_PATH_DIRS` (optional_deps.py:50-68): if `PATH` changes after the first check, `_prepare_native_dir` decides prepends from the stale snapshot (INFERRED: can re-prepend a directory or skip a needed one).
- **Fix:** Memoize `check_all()`'s result in `optional_deps` after the first successful probe (invalidate only in `install_lz4`'s completion path, which already refreshes), and drop the `_PATH_DIRS` cache — read `os.environ["PATH"]` when preparing a directory.
- **Benefit:** One native probe per process instead of one per click/refresh; removes a stale-global correctness trap.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ for the uncached call chain; INFERRED for the stale-PATH consequence)

---

## Files read

All read fully from the clone (line counts by `wc -l`):

- launcher/gui.py (3,786)
- launcher/game_library.py (497)
- launcher/library_catalog.py (642)
- launcher/library_gui.py (446)
- launcher/library_index.py (190)
- launcher/library_panel.py (561)
- launcher/art_fetch.py (219)
- launcher/asset_skin.py (164)
- launcher/theme.py (40)
- launcher/theme_assets.py (92)
- launcher/full_skin_controls.py (204)
- launcher/app_icon.py (246)
- launcher/disc_identity.py (239)
- launcher/ps1_index.py (147)
- launcher/ps1_vcd.py (153)
- launcher/riptopl_export.py (109)
- launcher/riptopl_profile.py (234)
- launcher/setup_guide.py (119)
- launcher/tray.py (270)
- launcher/tray_linux.py (198)
- launcher/dependency_panel.py (132)
- launcher/optional_deps.py (312)
- launcher/release_metadata.py (79)
- launcher/session_view.py (177)
- launcher/__init__.py (92)
- ps2servers.py (38)
- launcher/assets/ — censused by script: 4 files, all referenced (see header); no orphan assets
- Supporting greps only (not full reads, not filed from): launcher/main.py (patching/ABOUT appends), build/build.py and .github/workflows/release.yml (asset consumers), docs/COMPANION-CAPABILITY-MATRIX.md (ps1_index status line)

## Files not read (in scope)

- None. Every file named in the scope was read fully.
