# W14 — Build system, docs, assets (RiptOPL @ 2e347d5ac885cd0ff73e9ad4143781946396f492)

Scope: Makefile, ps2.yaml, modules/Rules.bin.make, format config, requirements/.gitattributes/.gitignore,
README + docs/ prose vs code, and the lng/ · misc/ · gfx/ · audio/ asset census.
All counts below come from scripts/commands run at the pin (recorded in COVERAGE).
The live build is ps2build: CI runs `tools/assets.py all` + `tools/build.py` / `build_edition.py`
against `ps2.yaml` (`.github/workflows/ps2build.yml`, `rolling-release.yml:122-136`). Several findings
are the same root cause — the legacy Makefile edition was never removed — filed as one mechanism each.

---

## W14-001 — The top-level Makefile is a dead second build system whose duplicated lists have already drifted from the live one, yet tests and a packaging script still read it as a data source

**Category:** 7 build/CI/repo clutter (with 1 dead code, 2 duplication)

**Locations:**
- `RiptOPL/Makefile:1197-1203` — the only EE compile rules are `$(EE_OBJS_DIR)%.o: $(EE_SRC_DIR)%.c` and the `asm/` equivalent. There is no `.cpp` rule, and `src/` is now six subdirectories of `.cpp` files.
- `RiptOPL/Makefile:136-141` (`FRONTEND_OBJS`, 53 objects) vs the tree: script count found 119 `src/**/*.cpp|*.c` files; 57 of them (e.g. `achievements`, `artload`, `autolaunch`, `coverflow`, `diaeditors`, `gamemanage`, `grid`, `psbbnflow`, `selfupdate`, `sfx`, `sysneutrino`, `themeviews`, `vmcrebuild`) are named nowhere in the Makefile.
- `RiptOPL/Makefile:156-168` (`PNG_ASSETS`, 108 real names) vs `RiptOPL/tools/assets.py:49-60` (104 base + 24 generated glyph names = 128): the Makefile list is missing 27 assets the live build embeds — `psbbn_bg`, `techwritescode`, `grid_devices` and all 24 `glyph_standard_*` / `glyph_white_*`. The code references those symbols: `src/gfx/textures.cpp:65,320,329` (`psbbn_bg_png`, `techwritescode_png`), `src/gfx/themes.cpp:1191-1192` (extern `glyph_<set>_<name>_png`).
- `RiptOPL/Makefile:189` (`MISC_OBJS`, 7 entries) vs `RiptOPL/tools/assets.py:68-78` (`MISC`, 9 entries): the Makefile never embeds `theme_grid.cfg` / `theme_psbbn_flow.cfg`, whose symbols the code requires — `src/gfx/themes.cpp:35-38,1346-1348`.
- `RiptOPL/Makefile:1213` — `INTERNAL_LANGUAGE_C = src/lang_internal.c`; the generated file actually lives at `src/core/lang_internal.c` (`tools/assets.py:117`, `ps2.yaml` riptopl sources, `.gitignore:72`). `src/lang_internal.c` does not exist.
- `RiptOPL/Makefile:142-152` (`IOP_OBJS`/`EECORE_OBJS`) vs `RiptOPL/ps2.yaml` riptopl target `embed_irx` (85 entries, script-counted): no Makefile object or rule covers `smb2man`, `nfsman`, `smb2_cdvdman`, `nfs_cdvdman`, `pccf_bd`/`pccf_game`/`pccf_cdvdman`, or `igrmbox`, all of which `ps2.yaml` defines as targets and embeds.
- Duplicated constants, already the drift surface above: version `Makefile:1-4` = `tools/assets.py:31`; `TRANSLATIONS` `Makefile:191-193` = `tools/assets.py:44-46`.
- Readers that keep the dead file load-bearing: `tools/lng_pack.sh:23-27` greps the version out of the Makefile; `.github/scripts/test_bdm_index.py:146`, `test_menu_crash_catcher.py:88`, `test_smb1_vmc_share.py:87` and `test_apa_table_safety.py:215-224` read the top-level Makefile as a spec.
- The repo itself says so: `docs/PS2BUILD-MIGRATION.md:75` ("the legacy Makefile cannot compile the converted C++ sources"), `:112` ("The Makefile can no longer build src/ (no .cpp rule)"), `:106` (open item: "Makefile removal"), and `README.md:893-895` ("The legacy Makefile … [is] not supported here").

**Problem:** Two build definitions for one product. The Makefile one cannot compile the current tree at all (no C++ rule, flat `src/*.c` layout, wrong generated-file path), and where its lists overlap the live `tools/assets.py`/`ps2.yaml` lists they have silently diverged (27 embedded PNGs, 2 theme configs, whole IOP targets missing). Anyone who runs `make` gets a broken or wrong build; anyone who edits a list in one place desyncs the other; and because host tests and `lng_pack.sh` parse the Makefile, it cannot simply be ignored — its stale values are asserted as truth in CI.

**Fix in words:** Delete the top-level Makefile's build system. Move its last live data to the single owners that already hold copies — version numbers and the translation list already exist in `tools/assets.py:31,44-46` — point `tools/lng_pack.sh` at `tools/assets.py version-string` (which already exists) and re-point the four host tests listed above at `ps2.yaml`/`tools/assets.py`, as other tests already do (`.github/scripts/test_mbedtls_vendor.py:7` notes exactly this conversion for its own check). Then delete `Makefile`. The 45 module-level Makefiles and `modules/Rules.bin.make` (215 B, included by e.g. `modules/bdmevent/Makefile:7`, `modules/iopcore/cdvdman/Makefile:104`) are reachable only through the dead top-level build — except `modules/bdmassault/ilink_bd_assault/Makefile`, which `.github/workflows/flavours.yml:372-375` invokes directly — so delete the rest in the same pass after a grep confirms no workflow/test references each one.

**Benefit:** One build definition; the 27-asset / 2-config / 6-target drift class disappears; `make` stops being a trap that produces a plausible-looking broken ELF; ~52 KB Makefile plus the legacy module Makefiles leave the tree.

**Effort:** L · **Risk:** Med (tests and `lng_pack.sh` must be re-pointed first, or they break) · **Confidence:** High (READ — every list compared by script at the pin)

---

## W14-002 — The format gate never checks a single C++ file, and the local and CI format mechanisms disagree about what is excluded

**Category:** 7 build/CI/repo clutter

**Locations:**
- `RiptOPL/.github/workflows/check-format.yml:5-19` — trigger paths are only `**.h`, `**.c`, `.clang-format`, `.clang-format-ignore` and the workflow itself; a change touching only `.cpp` files never triggers the job.
- `RiptOPL/.github/workflows/check-format.yml:31-37` — the lint step sets `extensions: 'h,c'` and `exclude: './third_party'` only.
- Script counts at the pin: 130 `.cpp` files repo-wide outside `third_party` (115 under `src`/`include`/`ee_core`/`modules` alone) — i.e. the entire C++ edition this repo now is — versus 254 `.c` and 431 `.h`.
- `RiptOPL/.clang-format-ignore:1-20` — 20 vendored/do-not-reformat paths (`modules/network/smbman-ra`, `modules/usb/usbd-ra`, `modules/bdm/bdmfs_fatfs`, `modules/network/smb2man/usmb2`, `modules/network/nfsman/unfs4`, `tests/host`, …). The CI step does not pass this file or its contents as exclusions; the exclusion it does pass (`./third_party`) is a different, shorter list.
- `RiptOPL/Makefile:541-546` — the local `format`/`format-check` targets use a second mechanism entirely: `tools/download_cfla.sh` clones `third_party/clang-format-lint-action` at pinned commit `c3b2c943e924028b93a707a5b1b017976ab8d50c` and runs its `run-clang-format.py -r .`, while CI uses `DoozyX/clang-format-lint-action@v0.18.2` as an action.
- `RiptOPL/README.md:35` carries a "Format" badge for this workflow on a repo whose badge line 41 says "Written in C++".

**Problem:** The gate CI claims (and the README badges) does not cover the language the codebase is written in: a badly formatted `.cpp` change neither triggers nor is checked by the workflow. The two format paths that do exist diverge — the ignore file that protects vendored code from reformatting is honoured by the local script path (INFERRED: `run-clang-format.py` reads `.clang-format-ignore` from the working directory) but is not wired into the CI action's `exclude`, so CI and local runs can disagree in both directions.

**Fix in words:** Make the one CI job the only gate: add `cpp` (and `hpp` if any appear) to its trigger paths and `extensions`, and pass the `.clang-format-ignore` entries as the action's exclusions (or generate the exclude list from that file) so vendored paths are skipped in CI exactly as locally. Delete the Makefile `format`/`format-check`/`download_cfla` mechanism with W14-001 rather than maintaining a second one.

**Justification (for the extension, not a new system):** this adds no new tool — it widens the existing job's file list to the files the project actually contains, which is the concrete bug.

**Benefit:** The format badge becomes true for the C++ tree; vendored files stop being a CI-vs-local disagreement source.

**Effort:** S · **Risk:** Low (first widened run may surface pre-existing `.cpp` formatting debt — that is the gate working, and can be landed as one format-only commit) · **Confidence:** High for the workflow contents and file counts (READ, script-counted); Med for the ignore-file behaviour of the two runners (INFERRED)

---

## W14-003 — Current user/contributor docs still teach the legacy Makefile build — commands, flags and variant names that no longer exist

**Category:** 7 build/CI/repo clutter (docs contradict code)

**Locations (doc line → code truth):**
- `RiptOPL/README.md:443` — "1080p GSM … is built directly into all standard builds (`make GSM1080P=1`)". There is no working `make` build (W14-001); in the live build `GSM_1080P` is an unconditional define in `ps2.yaml:609,644` with no `GSM1080P` variable to set.
- `RiptOPL/docs/GSM.md:211-216` — "Notes for builders: `GSM1080P` is the Makefile variable; it defaults to `1`, and … the `Makefile` adds `-DGSM_1080P` … and forwards `GSM1080P=1` on to `ee_core/Makefile`. … Building with `GSM1080P=0` drops both 1080p rows and shortens the list to 29 entries." The 31/29 counts themselves are correct (`src/core/gsm.cpp:106-151`: 29 rows + 2 under `#ifdef GSM_1080P`), but no supported builder offers the `GSM1080P=0` build described: `tools/build_configuration.py:7-10` lists 15 configurations, none of them a GSM-off one, and `ps2.yaml` defines `GSM_1080P` unconditionally.
- `RiptOPL/docs/LANGUAGES.md:27,76,88-99` — build flow headed "`make languages`", "The `TRANSLATIONS` list in the `Makefile` decides which `lang_<Language>.lng` files get built", and a "Building just the languages" section whose only command is `make languages`. CI actually runs `tools/assets.py all` (`.github/workflows/ps2build.yml`, "Assets" step), and `tools/assets.py:44-46,106-124` holds and uses its own `TRANSLATIONS` list.
- `RiptOPL/lng/README.md:24-26,42,67,82` and `RiptOPL/lng/fork/README.md:16` — translator instructions are `make download_lng` / `make languages` throughout.
- `RiptOPL/docs/IGR.md:110-117` — IGS is explained via Makefile `EXTRA_FEATURES`/`IGS` defaults, and the IGS-enabled release loaders are "the variants named `-extra1` … in `pademu0`/`pademu1` and optional `-ds5` flavours", buildable with "`make IGS=1` (or `EXTRA_FEATURES=1`)"; `:120,204` reuse `EXTRA_FEATURES`/`-extra1`. The real mechanism is the `extras` / `extras_ds5` configurations: `tools/build_configuration.py:37-40` adds `__RTL`+`IGS` for those names, `docs/BUILD-CONFIGURATIONS.md:13-14,50-51` lists the variant folders as `pademu0`, `ds5`, `extras`, `extras_ds5`, and `README.md`'s own IGR table already says `extras/` and `extras_ds5/`. No `-extra1` or `pademu1` variant exists.
- `RiptOPL/docs/AUTOLAUNCH-GLOBAL-SETTINGS.md:139` — diagnostic build recipe is "`make clean` followed by `make OPLDIAG=1 release`"; the live equivalent is the `diag` configuration (`tools/build_configuration.py`, `diag` adds `__OPLDIAG`; `docs/BUILD-CONFIGURATIONS.md:53`).
- `RiptOPL/docs/HTTP.md:168-169` — "Both IRX rules depend on it in the top-level Makefile, because make cannot see inside a sub-make and a stale IRX otherwise builds clean locally and fails CI." There are no IRX rules in the live build; `http_cdvdman` is a `ps2.yaml` target.

**Problem:** A user or contributor following the current (non-dated) documentation runs commands that cannot work, looks for release variants under names that are never published (`-extra1`, `pademu1`), and is told a `GSM1080P=0` build exists when the supported builder cannot produce one. Each doc was true for the legacy C edition and was not rewritten when the build moved.

**Fix in words:** In each location above, replace the Makefile command/flag/variant name with the live one — `python tools/build_edition.py <edition> --configuration <name>`, `tools/assets.py lang`, the `extras`/`extras_ds5`/`diag` configuration names — and delete the `GSM1080P=0` builder paragraph in `docs/GSM.md`, keeping the (correct) mode-count facts. No new documentation structure; this is substitution in place.

**Benefit:** Every build instruction in the current docs is runnable as written; variant names in docs match the ZIPs users actually download.

**Effort:** M · **Risk:** Low · **Confidence:** High (READ — both sides cited)

---

## W14-004 — The migration doc's status section and a workflow comment describe flavours/CI that have since landed, as if they were still missing

**Category:** 8 half-finished/redundant features (stale status docs)

**Locations:**
- `RiptOPL/docs/PS2BUILD-MIGRATION.md:103-106` — "`flavours.yml` builds the main flavour only; the … DIAG and RA are gone until `ps2.yaml` can express them", "`rolling-release.yml` still builds with `make` and will fail where it triggers; not ported", open items include "other flavours (RA, debug/DIAG, DUALSENSE …)".
- Contradicted by: `RiptOPL/.github/workflows/rolling-release.yml:122-136` (runs `tools/assets.py fetch`/`lang` then `tools/build_edition.py` per edition/configuration — no `make`); `RiptOPL/.github/workflows/configurations.yml:23-42` (17 edition/configuration matrix entries × 2 toolchains, including `ra` and `diag`-family configurations); `RiptOPL/docs/BUILD-CONFIGURATIONS.md:45-61` (15 configurations incl. `ds5`, `diag`, debug family).
- `RiptOPL/.github/workflows/flavours.yml:401-405` — comment in the live workflow itself: "The RA and DIAG flavours return when ps2.yaml can express them."
- Mitigation, stated for fairness: `docs/PS2BUILD-MIGRATION.md:3-7` carries a banner saying the planning sections "describe earlier migration choices … They are not the supported release build commands", and `docs/README.md:57-69` files it under "Migration and history". The sentences above are nonetheless phrased as present-tense status ("still builds", "will fail", "builds the main flavour only") inside the section a reader lands on for CI status.

**Problem:** Anyone assessing what CI covers from these texts concludes RA/DIAG/DS5 configurations and the rolling release do not exist or are broken, when all of them are live. The workflow comment repeats the stale claim at the exact place a maintainer would check it.

**Fix in words:** Delete the stale status sentences (`docs/PS2BUILD-MIGRATION.md:103-106` list entries for flavours and rolling-release, and the `flavours.yml:401-405` sentence) rather than rewriting the history — the dated plan below them can stay as history under its existing banner.

**Benefit:** CI-status claims match the workflows; no reader is sent to "port" a release pipeline that already runs.

**Effort:** S · **Risk:** Low · **Confidence:** High (READ)

---

## W14-005 — The language count is 31 in the README badge and the languages doc; the build builds 33

**Category:** 7 build/CI/repo clutter (docs contradict code)

**Locations:**
- `RiptOPL/README.md:40` — badge "Translations-31 languages".
- `RiptOPL/docs/LANGUAGES.md:69` — "the initial bulk fill of the 31 fork languages".
- Truth at the pin, script-counted: `tools/assets.py:44-46` `TRANSLATIONS` = 33 names; `Makefile:191-193` agrees at 33; `lng/fork/` contains 33 `<Language>.yml` overlay files (plus its `README.md`). English is generated separately (`tools/assets.py:110-111`), so the loader offers English + 33 translations.

**Problem:** Both public counts understate the shipped set by two, and they will keep drifting because the number is hand-typed in prose in two places while the authoritative list lives in code.

**Fix in words:** Change both numbers to 33 — or, better and smaller long-term, drop the number from the badge/doc sentence entirely ("Translations" without a count) so there is nothing left to drift. Do not add a generator for one badge.

**Benefit:** Public claims match the language pack the release actually builds.

**Effort:** S · **Risk:** Low · **Confidence:** High (READ, script-counted)

---

## W14-006 — Current reference docs cite source files at their pre-C++ flat paths, which do not exist

**Category:** 7 build/CI/repo clutter (docs contradict code)

**Locations (doc line → actual file, verified to exist):**
- `RiptOPL/docs/APA-SAFETY.md:43,47,49,50` — cites `src/hddsupport.c` (four times) and `src/hdd.c`; actual: `src/sources/hddsupport.cpp`, `src/platform/hdd.cpp`. This is the current APA-safety reference, linked from `README.md` and `docs/README.md` — the doc a user follows before touching a disk whose table may be corrupt.
- `RiptOPL/docs/GSM.md:223-224` — cites `src/guigame.c` and `src/dialogs.c`; actual: `src/ui/guigame.cpp`, `src/ui/dialogs.cpp`.
- `RiptOPL/docs/HTTP.md:161` — cites `src/httpcatalog.c`; actual: `src/platform/httpcatalog.cpp`.
- `RiptOPL/docs/HTTP.md:164` — the host-test command is printed as `sh tools/tools/pc/http/tests/run.sh` (doubled `tools/`); the real script is `tools/pc/http/tests/run.sh` (verified present, with `compare_catalog.py` beside it — the same doc's `:161` names that file at its correct path).
- `RiptOPL/docs/RETROACHIEVEMENTS.md:520` — cites `src/md5.c`; actual: `src/platform/md5.c` (the file `.clang-format-ignore:6` and the Makefile's own vendoring comments already know by its new path).
- `RiptOPL/docs/LANGUAGES.md:29-30` — the generated English fallback is placed at `src/lang_internal.c` and described as the enum "every `.c` file uses"; actual generated path is `src/core/lang_internal.c` (`tools/assets.py:117`), and the consumers are `.cpp`.

**Problem:** One mechanism, repeated: when `src/*.c` was split into `src/{app,core,gfx,platform,sources,ui}/*.cpp`, the current reference docs were not re-pointed. Every one of these citations fails as a path a reader can open, and in `docs/HTTP.md:164` as a command a reader can run. (The same flat paths appear throughout the dated plan/handoff docs — e.g. `docs/EMBER-INTEGRATION-PLAN.md`, `docs/COMMUNITY_REPORTS_HANDOFF_2026-10-02.md` — but `docs/README.md:65-69` explicitly labels those as dated baselines, so they are not filed here.)

**Fix in words:** Substitute the actual paths above in the six current-doc locations; no other text changes.

**Benefit:** Citations in the safety, GSM, HTTP, RA and language references resolve to real files; the HTTP test command runs as printed.

**Effort:** S · **Risk:** Low · **Confidence:** High (READ — existence of every actual path verified by script)

---

## W14-007 — Twelve gfx/ files (29,792 bytes) are never embedded in any flavour: seven device icons the code deliberately dropped, and four byte-identical duplicates whose blobs the code already shares

**Category:** 1 dead code / 4 size (asset census, script + md5)

**Locations:**
- Census (script, at pin): `gfx/` = 142 files, 443,330 bytes. `tools/assets.py:49-60,166-171` embeds 128 PNGs in the default build (104 base + 24 glyphs), plus `ra_mark` only for the RA flavour and `apps_case` only for the Korium theme — leaving 14 files unembedded in the default build, of which those two are flavour-used and the 12 below are used by no flavour.
- `RiptOPL/gfx/Device_1.png` (582 B), `Device_2.png` (742 B), `Device_3.png` (886 B), `Device_4.png` (899 B), `Device_5.png` (600 B), `Device_6.png` (784 B), `Device_all.png` (1,016 B), `no_Device.png` (676 B) — `src/gfx/textures.cpp:260-266` maps `DEVICE_1`…`DEVICE_ALL` to `NULL` data, and the comment at `src/gfx/textures.cpp:269-277` states the device-indicator icons were "removed from the embedded themes' info page, so no longer embedded (dropped from PNG_ASSETS)" and the `no_Device` fallback was "dropped with the device indicator; not embedded". The names survive only so a disk theme can override by filename — a theme ships its own PNGs; it does not read this repo folder.
- Byte-identical duplicates (md5, script): `gfx/logo4.png` = `gfx/logo3.png` (8,569 B, md5 `84eb33a7d0daa1321fd2a07185dc6508`), `gfx/logo5.png` = `gfx/logo2.png` (7,161 B, `ca7048eb7168928716e42ee648c05572`), `gfx/logo6.png` = `gfx/logo1.png` (6,545 B, `1651f8d83156fabefe580ab610a96636`), `gfx/no_Rating.png` = `gfx/Rating_0.png` (1,332 B, `dd241f101796a79a67cd957ea6f6a17d`). The code already exploits exactly this: `src/gfx/textures.cpp` maps `LOGO4/5/6` to `&logo3_png`/`&logo2_png`/`&logo1_png` and `NO_RATING_PICTURE` to `&Rating_0_png`, with comments saying the files are byte-identical and the blob is shared.

**Problem:** 12 source files totalling 29,792 bytes (6,185 B device icons + 23,607 B duplicate copies) sit in the asset folder that every contributor treats as "what gets embedded", while the build embeds none of them and the code comments already record the decision to drop/share them. They are pure repo weight and a standing invitation to edit a file that changes nothing.

**Fix in words:** Delete the 12 files. Keep the texture-table names and the shared-blob mappings in `src/gfx/textures.cpp` exactly as they are (disk-theme override by filename is unaffected — those themes carry their own files).

**Benefit:** `gfx/` becomes an exact list of what a build can embed; 29,792 bytes and four duplicate-maintenance traps removed.

**Effort:** S · **Risk:** Low · **Confidence:** High (READ — embed list, texture table and md5s all script-verified)

---

## W14-008 — audio/bgm.ogg (324,182 bytes) is an orphan: not embedded, not packaged, and not the BGM file the packages actually ship

**Category:** 1 dead code / 4 size

**Locations:**
- `RiptOPL/audio/bgm.ogg` — 324,182 bytes, the largest file in `audio/` (census: `audio/` = 9 files, 533,398 bytes; the other 8 are the `.adp` effects).
- Not embedded: `tools/assets.py:62,182-183` embeds only the eight `.adp` names; `Makefile:178-183` says the same for the legacy build ("intentionally NOT compiled into the ELF … kept in the repo only as a reference/default track").
- Not the shipped track: the release app template's BGM is `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/APPS/APP_RIPTOPL/bgm.ogg`, consumed by `.github/scripts/package_release_app.py:24-30,235-236` — and its md5 (`af3e8d4b117d57161cfdcaa4fdb9b370`) differs from `audio/bgm.ogg` (`a639ef8b7b69c10c6868f8fef3129fba`), so the repo file is not even the source of the packaged one.
- Runtime never reads a repo path: `src/core/bgm.cpp:620-638` loads BGM from, in order, the active disk theme's `sound/bgm.ogg`, a configured BGM path, and the built-in themes' data-home `bgm.ogg` — the last of which is the packaged file above, not this one. A repo-wide grep for `audio/` consumers found only the `.adp` embed rules and the Makefile comment.

**Problem:** A 324 KB media file with no consumer: the build skips it on purpose, the packager ships a different file under the same name, and the loader's three BGM sources are all on-device paths. It survives only as a "reference" copy that does not match the reference it supposedly provides.

**Fix in words:** Delete `audio/bgm.ogg`. If a reference track is genuinely wanted, the packaged `ship/Example/…/bgm.ogg` already is one, in the place the packager reads.

**Benefit:** 324,182 bytes — 61% of `audio/` — removed, and one of two different files named `bgm.ogg` stops masquerading as the shipped default.

**Effort:** S · **Risk:** Low · **Confidence:** Med (READ for embed/packager/runtime paths and both md5s; INFERRED that no out-of-repo consumer exists — the "no consumer" claim rests on the repo-wide grep reported above)

---

## COVERAGE

**Pin verified:** `git rev-parse HEAD` = `2e347d5ac885cd0ff73e9ad4143781946396f492` before any work. Clone treated read-only; all scratch in `/tmp/w14/`. Nothing under `~/workspace/Sable-audit/` was read, listed, or grepped.

**Files read fully:**
- Build: `Makefile` (1,260 lines), `ps2.yaml` (670 lines, parsed with PyYAML and every target's sources/imports/exports/linkfile/include_dirs existence-checked by script), `modules/Rules.bin.make`, `.clang-format`, `.clang-format-ignore`, `requirements.txt` (one line: `PyYAML==6.0.3` — consistent with the build tools' imports; the `bs4`/`markdown_it` imports in `.github/scripts/site_sync.py`/`wiki_sync.py` are pinned inline by `docs-sync.yml:184`/`flavours.yml:350`, so no finding), `.gitattributes` (spot-verified with `git check-attr`: `ship/POPS/** binary` applies; `docs/ps2sdk-patches/` exists with its 2 patches), `.gitignore`.
- Live-build counterparts read to judge the Makefile against: `tools/assets.py` (full), `tools/build_configuration.py` (full), `.github/workflows/check-format.yml`, `ps2build.yml`, `configurations.yml` (matrix), `rolling-release.yml` and `flavours.yml` (relevant sections).
- Docs read fully: `README.md` (1,116 lines), `docs/README.md`, `docs/LANGUAGES.md`, `docs/BUILD-CONFIGURATIONS.md`, `lng/README.md`.
- Docs read in the sections cited: `docs/GSM.md` (builder/file sections), `docs/HTTP.md` (notes section), `docs/APA-SAFETY.md` (guarantee table), `docs/IGR.md` (IGS section), `docs/AUTOLAUNCH-GLOBAL-SETTINGS.md` (diagnostic section), `docs/PS2BUILD-MIGRATION.md` (status + open-items sections), `docs/RETROACHIEVEMENTS.md` (credits line), `lng/fork/README.md`.
- Code read for cross-checks: `src/gfx/textures.cpp` (texture table), `src/gfx/themes.cpp` (glyph externs, embedded theme configs), `src/core/gsm.cpp` (mode table), `src/core/bgm.cpp` (BGM load order), `src/core/OSDHistory.cpp` (icon variants).

**Asset census (all by script at the pin):**
- `lng/`: 36 files, 1,918,064 B — `lng/README.md` (3,079 B), `lng/tmpl/_base.yml` (113,245 B, 1,164 `label:` entries, 2,711 lines), `lng/fork/`: 34 files, 1,801,740 B = 33 language `.yml` + `README.md`; no md5 duplicates among the 33.
- `misc/`: 9 files, 28,044 B — all 9 are embedded by `tools/assets.py:68-78` and all distinct by md5 (the four `icon*.sys` are same-size but different content, selected per region in `src/core/OSDHistory.cpp:47-55`). No finding.
- `gfx/`: 142 files, 443,330 B — embed analysis and md5 duplicates in W14-007. Flavour-only files correctly kept out of that finding: `ra_mark.png` (RA flavour, `tools/assets.py:166-167`), `apps_case.png` (Korium, `tools/assets.py:163`).
- `audio/`: 9 files, 533,398 B — 8 `.adp` embedded, `bgm.ogg` orphaned (W14-008).
- `ps2.yaml` reference check: every local target source/import/export/linkfile/include path exists except the documented generated/downloaded inputs — `modules/network/lwNBD/**` (fetched by `tools/download_lwNBD.sh`, git-ignored, noted in the file's own comment) and `src/core/lang_internal.c` + `asm/` (generated by `tools/assets.py lang`/`embed`). No finding.
- `docs/` total: 159 files, 64,415,619 B, of which 70 `.md` files are 1,045,127 B and 71 are media under `docs/assets/`; every `docs/assets/` file is referenced by basename from some doc/script (script-checked), and the only md5 duplicates there are two 206/209-byte manifest JSON pairs. No asset finding in `docs/assets/`.

**In-scope files NOT read in full (with reason):**
- The remaining ~60 `docs/*.md` files (of 70): not read line-by-line. They were covered by (a) a script extracting every back-quoted repo path from all `docs/*.md` + `README.md` + `ROLLING_RELEASE.md` and testing existence — the current-doc failures are W14-006, and the remaining failures are all inside the dated plan/handoff/audit files that `docs/README.md:65-69` explicitly labels as historical baselines, so they were not filed; and (b) targeted greps for `make`/Makefile, version and count claims. Individual behavioural claims inside those 60 files (per-game, per-protocol details) were not each re-derived against code — that is the one real coverage gap in this section.
- `ROLLING_RELEASE.md`: read via targeted greps (channel/build commands) only, not in full.
- `CHANGELOG`, `docs/OLD_DETAILED_CHANGELOG`, `CREDITS`: out of scope as prose (historical records, not claims about the current tree); sizes noted only.
- `ship/` (182 files, 9,637,271 B): outside the assigned asset scope (lng/misc/gfx/audio). Census run opportunistically only: its `ship/Example/` tree is a deliberate, workflow-maintained mirror of `ship/POPS` + `ship/EMBER` (see `ember-watch.yml:130,154`, `.github/scripts/test_bdma_shipped_pairs.py`), so the many exact duplicates there were not filed.
- Binary/media contents of `gfx/`, `audio/`, `docs/assets/`: censused by size/md5 and embed/reference checks, not inspected visually.
- Hardware/PS2SDK behaviour: none claimed anywhere in this section, per scope.
