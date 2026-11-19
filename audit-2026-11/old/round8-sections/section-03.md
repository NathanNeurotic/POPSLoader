# Round 8 — Section 03 — RiptOPL test corpus, batch 03

- Repo: NathanNeurotic/RiptOPL, clone `~/workspace/audit-clones-2026-11-13/RiptOPL`, pin `2e347d5ac885cd0ff73e9ad4143781946396f492` (verified, not updated; `git status` clean at start and finish).
- Scope: every file in `batch-03.txt`, line-read IN FULL in listed order (largest first): 32 files, 4,554 lines. All are `.github/scripts/test_*.py`.
- CI environment baseline (READ): `.github/workflows/flavours.yml:19,115,267,276,292,321,342,364,406` — all jobs `runs-on: ubuntu-24.04`; `flavours.yml:25` installs only `requirements.txt` (= `PyYAML==6.0.3`, `requirements.txt:1`); `.github/workflows/ps2build.yml:71` runs `tools/run_tests.sh -k`, whose glob at `tools/run_tests.sh:7-9` runs every `.github/scripts/test_*.py` and counts only non-zero exits as failures. A test that prints "skip" and exits 0 is therefore a pass in both invoking jobs.
- Prior-findings handling: RIPTOPL-286…291 not re-filed. Where a batch file touches one of those exact mechanisms, only new/extending evidence is filed and labelled as such (candidates C3, C4). RIPTOPL-005's corpus characterisation not re-derived.

## (a) Per-file ledger

| path | lines | verdict |
|---|---|---|
| .github/scripts/test_ember_disc_selection.py | 209 | clean |
| .github/scripts/test_netblock_oplcore.py | 202 | clean |
| .github/scripts/test_udpfs_smap_fifo_tail.py | 202 | clean |
| .github/scripts/test_settings_fit.py | 196 | clean |
| .github/scripts/test_ripps2_art_port.py | 195 | finding (C2) |
| .github/scripts/test_net_protocol_pick.py | 177 | clean |
| .github/scripts/test_bdm_keep_page_on_reapply.py | 176 | clean |
| .github/scripts/test_date_time_setting.py | 169 | clean |
| .github/scripts/test_ilink_game_transport.py | 169 | clean |
| .github/scripts/test_bdm_index.py | 166 | finding (C3, extends RIPTOPL-291) |
| .github/scripts/test_ilink_scsi_geometry.py | 164 | clean |
| .github/scripts/test_mmceman_fork.py | 158 | finding (C5) |
| .github/scripts/test_neutrino_toml_sync.py | 152 | clean |
| .github/scripts/test_message_wrap.py | 149 | clean |
| .github/scripts/test_bdm_read_alignment.py | 148 | clean |
| .github/scripts/test_hdd_mini_autolaunch.py | 134 | clean |
| .github/scripts/test_pad_handoff.py | 133 | finding (C3, extends RIPTOPL-291) |
| .github/scripts/test_ilink_command_orb.py | 132 | clean |
| .github/scripts/test_ilink_manager_irq.py | 132 | clean |
| .github/scripts/test_menu_selection_snapshot.py | 128 | clean |
| .github/scripts/test_game_type_labels.py | 121 | finding (C1) |
| .github/scripts/test_mmce_sio2man_pack.py | 121 | clean |
| .github/scripts/test_confirm_button.py | 118 | clean |
| .github/scripts/test_issues_830_831.py | 116 | clean |
| .github/scripts/test_searchfile_init_bounds.py | 116 | clean |
| .github/scripts/test_neutrino_dvr_contract.py | 112 | clean |
| .github/scripts/test_lang_format_guard.py | 106 | clean |
| .github/scripts/test_osd_defaults.py | 105 | clean |
| .github/scripts/test_udpfs_languages.py | 99 | clean |
| .github/scripts/test_theme_metadata.py | 95 | clean |
| .github/scripts/test_cjk_font_fallback.py | 89 | clean |
| .github/scripts/test_release_editions.py | 65 | finding (C4; its compiler-skip axis at :40-42 is RIPTOPL-291 and is NOT re-filed) |

Note on C6: it is a set-level duplication candidate over 23 of the batch's files (each individually works at the pin). Per-file verdicts above are therefore not changed by C6; the affected files are enumerated inside C6.

## (b) Candidate findings (unnumbered)

### C1 — test_game_type_labels.py's "functional harness" tests a private re-implementation, not the production code, with constants that contradict the production enums

- Category: 2 (duplication)
- Locations: `.github/scripts/test_game_type_labels.py:54-83` (harness-local `formatDisplayName()` definition), `:85-107` (its `main()`), `:109-119` (compile/run of that copy); production: `src/gfx/themeelems.cpp:2046-2057`, `include/libview.h:32-41`, `include/iosupport.h:10-21`
- Problem: Sections 1–5 of the file (`.github/scripts/test_game_type_labels.py:26-52`) are real string-presence checks on production sources. Section 6, the only compiled/behavioural part, extracts nothing: it defines its own `formatDisplayName()` at `:71-83` and asserts against that copy, so any change to the real labelling logic in `src/gfx/themeelems.cpp:2046-2057` — the `isFolder` branch at `:2043-2045` (folders get `"/"`, never a label; the copy has no folder case at all), the `libListRowView()` call, the buffer choice — passes this test unchanged. The copy's constants are also stale against production (READ): the harness sets `APP_MODE 4` (`:60`) and `LIB_VIEW_ALL = 0, LIB_VIEW_ISO, LIB_VIEW_PS1` = 0/1/2 (`:63-67`), while production has `APP_MODE` = 10 (tenth enumerator after `BDM_MODE`…`HDD_MODE`, `include/iosupport.h:10-21`) and `LIB_VIEW_ISO = 0, LIB_VIEW_PS1 = 1, LIB_VIEW_ELF = 2, LIB_VIEW_ALL = 3` (`include/libview.h:32-41`). Because the copy is self-contained, neither discrepancy can ever be caught by the test itself. This is the test-only duplication pattern of RIPTOPL-288, in a new file/mechanism.
- Fix in words: delete the private `formatDisplayName()` harness and either (a) extract and compile the real labelling branch from `drawItemsList` the way neighbouring suites extract production functions, with the real `include/libview.h` / `include/iosupport.h` enums, including a folder row and a `LIB_VIEW_PS1_ELF`/`LIB_VIEW_ELF` row; or (b) drop section 6 and keep only the (real) static checks, renamed so the file no longer claims a functional test.
- Justification if the fix adds anything: option (a) adds only the extraction/stub scaffolding every sibling suite already has; it replaces, not supplements, the copy.
- Benefit: the one behavioural check for an opt-in user-visible feature would fail when the feature's logic changes, instead of certifying a copy.
- Effort: M / Risk: Low / Confidence: High (READ — harness text, production branch and both production enums all read at the pin)

### C2 — test_ripps2_art_port.py's JPG-decoder suite is skipped in the CI that runs it: neither libjpeg headers nor Pillow is installed by any workflow

- Category: 8 (half-finished/redundant features — conditional vacuous pass)
- Locations: `.github/scripts/test_ripps2_art_port.py:128-137` (probe + skip), `:138-195` (the skipped decoder suite); `.github/workflows/flavours.yml:25` (only pip install in the invoking job), `:63-68` (the `test_ripps2_*.py` loop that runs this file), `requirements.txt:1` (PyYAML only); `.github/workflows/ps2build.yml:71` + `tools/run_tests.sh:7-9` (second invoking path, installs no Python packages at all)
- Problem: The decoder half of the file — baseline/progressive/grayscale decode, size-box shrinking, non-JPG refusal, abort handling, `.github/scripts/test_ripps2_art_port.py:178-189` — runs only in the `else` at `:138`. It is skipped, with exit 0, when either the `jpeglib.h` syntax probe at `:130-131` fails or `from PIL import Image` fails at `:132-135`. No workflow installs either dependency (READ: repo-wide grep of `.github/workflows/*.yml`, `tools/*.sh` and both requirements files finds no Pillow/PIL/libjpeg install; the flavours job's sole install is `requirements.txt` = PyYAML at `flavours.yml:25`). On a stock ubuntu-24.04 environment — the `runs-on` of every flavours job, `flavours.yml:19` — neither a libjpeg development header nor Pillow is part of the base install, so the suite's CI execution is, in practice, the two earlier art-index/alias sections plus the printed line `skip JPG decode: host has no libjpeg headers or Pillow` at `:137`, reported as a pass by both runners (see header baseline). Unlike RIPTOPL-291's compiler skips, the missing pieces here are not guaranteed by any sibling CI step.
- Fix in words: install the two dependencies in the job that runs the RIPPS2 loop (pip Pillow + a libjpeg development package), or make the skip a failure when running under CI, in the same shape proposed for RIPTOPL-290/-291. Do not leave a print-only skip as the decoder's only CI state.
- Justification if the fix adds anything: adds two CI packages only; no new test code.
- Benefit: the JPG decoder — the riskiest, most platform-dependent code this file exists to cover — would actually execute in CI, or its absence would be visible as a failure instead of a pass.
- Effort: S / Risk: Low / Confidence: Med (mechanism and no-install facts READ at the pin; the base-image contents of the hosted ubuntu-24.04 runner are INFERRED from the stock image, not read from a live runner)

### C3 — EXTENDS RIPTOPL-291: two further compiler-absence skip-to-pass instances in this batch (test_pad_handoff.py, test_bdm_index.py); test_bdm_index.py additionally prints a success line claiming all 14 cases ran

- Category: 8 (half-finished/redundant features — conditional vacuous pass)
- Locations: `.github/scripts/test_pad_handoff.py:115-129`; `.github/scripts/test_bdm_index.py:119-128` and `:161`
- Problem: RIPTOPL-291 filed this mechanism for three suites; this batch contains two more instances, which extends its scope (labelled as such; the original three are not re-filed). (1) `test_pad_handoff.py:115`: `@unittest.skipUnless(shutil.which('cc'), 'no host C compiler')` guards `test_wait_pad_idle_timing`, the file's only compiled test — the other three tests (`:86-113`) are source-text checks — so with no `cc`, the timing behaviour of the real `waitPadIdle()` is untested and the suite still exits 0. (2) `test_bdm_index.py:119-128`: a hand-rolled equivalent — if neither `gcc` nor `cc` exists, all 14 draw cases in `CASES` (`:99-114`) are skipped with a printed `SKIP`, `failures` stays empty, and `main()` returns 0. Worse than the 291 instances, the success line at `:161` then prints `… %d cases …` with `len(CASES)` unconditionally, claiming the 14 cases ran when none did. Mitigation, as with 291 (READ): a compiler is present in the current CI images — sibling steps in the same workflow compile C with `cc` (`flavours.yml:196`, `flavours.yml:328`) — so both run today; the vacuity is conditional on a leaner runner or a local `tools/run_tests.sh` run.
- Fix in words: align both with the corpus's stricter pattern (no compiler → non-zero exit, cf. RIPTOPL-291), and make `test_bdm_index.py`'s final line report the number of cases actually executed.
- Justification if the fix adds anything: nothing added; two guards change polarity and one count becomes honest.
- Benefit: RIPTOPL-291's fix, when applied, would otherwise miss these two instances; the BdmIndex success line stops certifying cases that never ran.
- Effort: S / Risk: Low / Confidence: High (READ)

### C4 — NEW evidence in test_release_editions.py (not RIPTOPL-291's mechanism): the `ps2sdk_socket_compat` assertion at :28 can never fail — it membership-tests a dict of target names

- Category: 8 (half-finished/redundant features — vacuous assertion)
- Locations: `.github/scripts/test_release_editions.py:20` (`targets` dict construction), `:27-28` (the two `assertNotIn` lines); production data: `tools/build_edition.py` `definition()` output for all four editions (executed at the pin)
- Problem: Line 27 is a real check: `"ps2sdk_socket_compat"` not in the loader target's `libs`. Line 28 repeats the literal against `targets`, which line 20 built as `{t["name"]: t for t in config["targets"]}` — `assertNotIn` on a dict tests its keys, i.e. target names, not any target's `libs`. Verified by executing `tools/build_edition.definition()` for all four editions at the pin (READ/executed): 82–84 targets per edition, none named `ps2sdk_socket_compat`, and no target's `libs` currently contains it either. The assertion therefore fails only if a target is one day *named* `ps2sdk_socket_compat` — a different event from the one it sits beside (the parallel structure at `:23-24` and `:29` suggests the intended second operand was the core target's `libs`). As written it is dead: the ee-core (or any non-loader target) could link `ps2sdk_socket_compat` tomorrow and this test would still pass.
- Fix in words: point line 28 at the intended list — the core target's `libs`, or every target's `libs` in the loop the file already has at `:31` — and delete the dict-membership form.
- Justification if the fix adds anything: nothing added; one operand changes.
- Benefit: an edition-isolation rule the file claims to enforce ("only RA contains runtime" suite, docstring `:1`) becomes enforceable for the target it was written for.
- Effort: S / Risk: Low / Confidence: High (READ + executed against the production `build_edition` module at the pin)

### C5 — test_mmceman_fork.py's provenance claim covers the whole vendored tree; the check hashes 2 of its ~15 files — and the one file that changed at the pin bump is not among them

- Category: 7 (build/CI/repo clutter — verification claim exceeds the verification)
- Locations: `.github/scripts/test_mmceman_fork.py:3-4` (docstring claim), `:21-25` (the two-entry `PINNED` table), `:41-42` (the only two hash assertions); `modules/mmce/mmceman/ORIGIN.txt:3-5` (pin-bump delta is `src/sio2man_hook.c`) and `:27` ("test_mmceman_fork.py checks the tree against the commit"); vendored tree: `modules/mmce/mmceman/src/` (6 source files) + `modules/mmce/mmceman/include/` (8 headers)
- Problem: The docstring states the provenance half as: reversing `patches/` gives the pinned file "and the other vendored files are that commit's files unchanged" (`:3-4`), and `ORIGIN.txt:27` repeats that the test "checks the tree against the commit". The code checks exactly two files: `src/mmce_fs.c` after reverse-patching (`:41`) and `include/mmce_cmds.h` (`:42`). The other built vendored files — `src/mmceman.c`, `src/mmce_sio2.c`, `src/mmce_cmds.c`, `src/ioplib.c`, `src/sio2man_hook.c` and the remaining seven headers — carry no hash at all, so an edit to any of them passes CI while both documents claim tree-level provenance. The gap is pointed: per `ORIGIN.txt:3-5`, the *only* file that differs between the previous pin and the current pin `de28936f` is `src/sio2man_hook.c` — precisely a file this test does not hash (the `PINNED` comment at `:21` even notes the two hashed files are "unchanged since" the older pin). This is the claim-vs-check shape of RIPTOPL-286, in a new file/mechanism: not circular, but partial verification presented as whole-tree.
- Fix in words: either hash the remaining built files from the same pinned commit (one `PINNED` entry per file, generated once from upstream), or narrow both claims — docstring `:3-4` and `ORIGIN.txt:27` — to the two files actually checked. The first is preferred for `src/sio2man_hook.c` at minimum, since it is the pin's sole delta.
- Justification if the fix adds anything: the preferred fix adds hash constants (data, not code) for files already in the tree; no new harness.
- Benefit: a silent edit to the vendored driver — including the file the last pin bump exists to update — would fail CI, and the repo's provenance documents would no longer claim a check that does not run.
- Effort: S / Risk: Low / Confidence: High (READ — test, `ORIGIN.txt` and full tree listing all read at the pin)

### C6 — The batch re-implements the same C-function extractor 23 times, in three divergent semantics; only one copy is comment-aware

- Category: 2 (duplication)
- Locations (definition sites, READ): first-`\n}` slicing — `.github/scripts/test_ember_disc_selection.py:18`, `test_netblock_oplcore.py:27`, `test_settings_fit.py:26`, `test_net_protocol_pick.py:29`, `test_bdm_keep_page_on_reapply.py:30`, `test_date_time_setting.py:26`, `test_mmceman_fork.py:48`, `test_neutrino_toml_sync.py:17`, `test_message_wrap.py:21` (+ a second variant `body_of` at `:26`), `test_hdd_mini_autolaunch.py:15`, `test_confirm_button.py:27`, `test_neutrino_dvr_contract.py:15`, `test_osd_defaults.py:16`, `test_udpfs_languages.py:11`, `test_menu_selection_snapshot.py:14`; brace-counting — `test_ripps2_art_port.py:20`, `test_ilink_game_transport.py:30`, `test_bdm_index.py:23`, `test_pad_handoff.py:27`, `test_ilink_manager_irq.py:17`, `test_searchfile_init_bounds.py:23`; comment-aware brace-counting — `test_udpfs_smap_fifo_tail.py:30`. At least five more batch files slice functions inline with no helper at all (e.g. `test_bdm_read_alignment.py`, `test_ilink_command_orb.py`, `test_theme_metadata.py`, `test_lang_format_guard.py`, `test_cjk_font_fallback.py`). Only 4 of the 32 batch files import the existing shared module `hostmap.py`.
- Problem: Every behavioural suite in the batch stands or falls on extracting a production function correctly, yet the extraction logic — the corpus's single most load-bearing helper — exists in 23 near-copies with materially different failure modes. The 15 first-`\n}` copies silently truncate a function at the first line consisting of `}` at column 0 (a closing brace inside a multi-line string, a column-0 nested-struct close, an unindented `#if` block end); the 6 brace-counting copies handle that but miscount braces inside comments/strings; only `test_udpfs_smap_fifo_tail.py:30`'s copy skips `//` and `/* */` while counting. A truncation does not announce itself: the harness compiles the truncated body and the suite then passes or fails for a reason unrelated to the production change that triggered it. Because each copy is private, fixing the semantics in one file (as evidently happened for the FIFO suite) leaves the other 22 as they were.
- Fix in words: move the comment-aware extractor from `test_udpfs_smap_fifo_tail.py` into the already-shared `.github/scripts/hostmap.py` (or a sibling shared module imported the same way), and delete the 22 other local copies in this batch, converting call sites to the shared one; do the same for the inline slicers where their shape matches. Net deletion across the batch.
- Justification if the fix adds anything: the shared function already exists in-tree (in the FIFO suite); the change is relocation plus deletions, no new mechanism.
- Benefit: one extraction semantics to trust and to fix; a production function whose formatting trips the extractor fails (or passes) identically in every suite instead of suite-by-suite.
- Effort: L / Risk: Low / Confidence: High (READ — every definition site above was read in its file at the pin; behavioural divergence is READ from the three implementations' code)

## (c) Dissolved candidates

- Conditional guards `if <extracted> and …` / `if not failures:` before harnesses (`test_settings_fit.py:137,155,180,189`; `test_net_protocol_pick.py:125`; `test_bdm_keep_page_on_reapply.py:152,171`; `test_confirm_button.py:71`; `test_message_wrap.py:120`; `test_netblock_oplcore.py:76`) — dissolved: in each file the extractor (`function_text`/`function`) appends to `failures` when a function is not found, so the guard can only skip a harness after a failure that already forces `sys.exit(1)`; it cannot hide a missing/renamed function.
- `test_hdd_mini_autolaunch.py:25-29` (`resolver = … if signature in source else ""`, asserts under `if resolver:`) — dissolved: if `hddResolveAutoLaunchGame` were renamed/deleted, the selection slice extracted from `HddSource::launch` (`:20-23`) still calls it, so the harness fails compilation under `check=True` (`:132-134`); the conditional static asserts are redundant, not the sole coverage.
- Compiler-absence handling in `test_date_time_setting.py:75,156`, `test_searchfile_init_bounds.py:20,104-105`, `test_message_wrap.py:122-123`, `test_mmceman_fork.py:154-156` — dissolved: all fail loudly (`sys.exit('no C compiler')` = exit 1, a failure appended, or a `None` compiler flowing into a `check=True` subprocess); none is a skip-to-pass. (These are the corpus's stricter pattern, contrasting C3.)
- Assert-based C harnesses across the batch — dissolved at the pin: every compile line was read and none defines `NDEBUG` (including the `-O2` files `test_ilink_game_transport.py`, `test_ilink_scsi_geometry.py`, `test_ilink_command_orb.py`, `test_mmceman_fork.py`; `-O2` alone does not define `NDEBUG`), so the asserts are live in CI today. The latent flag-change risk is the pattern already filed in round 5 for a different suite; not re-filed.
- `test_bdm_index.py` case `('######', '5', '0', 'Index_5')` (a picture name with no built-in texture) — dissolved: the harness stub records the requested name by design; production's slot fallback is documented (`src/gfx/themeelems.cpp:1920-1923`, "by slot, as before", theme-supplied pictures), and existence of the built-in `Index_0`…`Index_4` / `Index<n>_<p>` pictures is checked separately in the same file (`:130-155`). No prior finding identifies the fallback as a defect, so this is not filed as bug-encoding.
- Stubbed helpers in `test_message_wrap.py` (`fntWrapText` stub, harness at `:51-84`) and `test_theme_metadata.py` (`fntFitString`/`thmCfgTextHidden` stubs) — dissolved: both stubs are disclosed in-file, the units under test are the extracted production callers, and the real `fntWrapText` is exercised by `test_dia_text_room.py` / `test_menu_text_fit.py` / `test_ripps2_text_port.py` and the real `thmCfgTextHidden` by `test_list_cfg_text.py` (all outside this batch; the metadata test states this itself).
- `test_release_editions.py:37` determinism assertion and `:35` source-existence exclusions — dissolved: `tools/build_edition.definition()` re-loads `ps2.yaml` and deep-copies targets on every call (`tools/build_edition.py:78-80`), so `:37` is a real isolation check, not a self-comparison; the `:35` exclusions match the build's own fetch/generation comments, and the `"*"` exclusion covers exactly one glob (`third_party/mbedtls/library/*.c`, `tools/build_edition.py:114,137`, verified).
- The three i.LINK suites (`test_ilink_scsi_geometry.py`, `test_ilink_command_orb.py`, `test_ilink_manager_irq.py`) each running both driver copies — dissolved as cross-file duplication: each file tests a different function, and running both copies is the correct response to the production duplication already filed as RIPTOPL-021/047; no test body is duplicated across the three files.
- `test_neutrino_toml_sync.py`'s `fake_open` truncate model (`:38`) and `test_date_time_setting.py`'s leap-second case (HTTP Date with seconds = 60 accepted) — dissolved: the first encodes the ps2sdk mcman contract documented in the file's own docstring with upstream references, the second is production parser behaviour; no prior finding (RIPTOPL-001…295, grepped for both subjects) identifies either as a defect, so neither is filed as bug-encoding.
- Exit-code handling, batch-wide — dissolved: every `subprocess.run` in the 32 files either uses `check=True` or branches on `returncode` into a failures list / return code that reaches `sys.exit` (spot-verified per file during the full read, including `test_netblock_oplcore.py:85-88`, `test_bdm_index.py:138-144`, `test_ilink_scsi_geometry.py:148-156`); no unchecked subprocess result and no `main()`-returns-0-on-failure path was found outside the skip mechanisms filed in C2/C3.
- Tests of deleted/renamed code, batch-wide — dissolved: every import, path and extraction target named by the 32 files was verified present at the pin during the read (extraction failures raise or record failures in all files, per the first two dissolved items); no file references a module, function or fixture that does not exist at `2e347d5a`.
