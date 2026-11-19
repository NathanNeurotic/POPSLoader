# Round 8 — Section 08: RiptOPL test corpus, batch 08 (40 files, 6,793 lines)

Pin: 2e347d5ac885 (verified, clone untouched, `git status` clean).
Method: every file in batch-08.txt line-read in full, in batch order. Workflow wiring checked against
`.github/workflows/flavours.yml`, `.github/workflows/ps2build.yml` and `tools/run_tests.sh`.
Prior-finding axes RIPTOPL-286…291 respected: no re-files; see ledger notes and dissolved list.

## (a) Per-file ledger

| Path | Lines | Verdict |
|---|---|---|
| .github/scripts/test_neutrino_bsdfs.py | 209 | finding (Candidate 3) |
| .github/scripts/test_smb2_auth.py | 205 | clean |
| .github/scripts/test_smstcpip_connect_completion.py | 205 | clean |
| .github/scripts/test_smstcpip_full_lwip_safety.py | 199 | clean |
| .github/scripts/test_handoff_probe.py | 194 | clean |
| .github/scripts/test_smb2_menu_wait_bounds.py | 191 | clean |
| .github/scripts/test_caduceus_overlay.py | 190 | clean |
| .github/scripts/test_retrogem_ember.py | 187 | clean |
| .github/scripts/test_vmc_pfs_reserve.py | 186 | clean |
| .github/scripts/test_neutrino_ra.py | 184 | clean |
| .github/scripts/test_menu_allocation.py | 182 | clean |
| .github/scripts/test_riptoplite.py | 179 | clean |
| .github/scripts/test_ra_module_startup.py | 178 | clean (helper dupe noted in Candidate 4) |
| .github/scripts/test_ra_badge_rows.py | 175 | clean |
| .github/scripts/test_config_missing_open_once.py | 173 | finding (Candidate 4) |
| .github/scripts/test_hires_line_blend.py | 173 | finding (Candidate 4) |
| .github/scripts/test_ps1_scan_recovery.py | 171 | clean |
| .github/scripts/test_reset_failure_lifecycle.py | 171 | clean |
| .github/scripts/test_pops_pathmap.py | 169 | clean |
| .github/scripts/test_save_icon_set.py | 168 | clean |
| .github/scripts/test_hires_thread_priority.py | 164 | finding (Candidates 1, 2, 4) |
| .github/scripts/test_hdd_module_lifetime.py | 163 | clean |
| .github/scripts/test_bdm_ata_readiness.py | 162 | clean |
| .github/scripts/test_screen_pos_per_mode.py | 162 | finding (Candidate 5) |
| .github/scripts/test_libview_l3_rescan.py | 161 | clean |
| .github/scripts/test_bdm_private_allocation.py | 160 | clean |
| .github/scripts/test_cheat_load.py | 159 | clean |
| .github/scripts/test_smb_launch_name.py | 159 | finding (Candidate 5, guarded variant) |
| .github/scripts/test_ripps2_boot_video_mode.py | 158 | finding (Candidate 5) |
| .github/scripts/test_ilink_manager_recovery.py | 157 | clean (helper dupe noted in Candidate 4) |
| .github/scripts/test_ra_launch_resources.py | 157 | clean |
| .github/scripts/test_autorefresh_initial_population.py | 154 | clean |
| .github/scripts/test_game_count_refresh.py | 154 | finding (Candidate 5) |
| .github/scripts/test_iop_pad.py | 154 | clean (helper dupe noted in Candidate 4) |
| .github/scripts/test_vmode_safe_area.py | 154 | finding (Candidates 2, 4) |
| .github/scripts/test_ripps2_library_port.py | 150 | clean |
| .github/scripts/test_wiki_sync.py | 150 | clean (bs4 axis is RIPTOPL-290; no new evidence — dedicated venv at flavours.yml:351-356 is the mitigation R290 already cited) |
| .github/scripts/test_ulcfg_rebuild.py | 148 | clean |
| .github/scripts/test_release_notes.py | 146 | clean (normalize_release_notes axis is RIPTOPL-288; this file adds no evidence extending it) |
| .github/scripts/test_mcemu_slots.py | 132 | clean (helper dupe noted in Candidate 4) |

Corpus-level negatives (READ, whole batch): no `skipUnless`/`skipTest`/compiler-absence guard anywhere
(no new RIPTOPL-291 instance — every compile step fails hard via `check=True` or a returncode branch);
no `-DNDEBUG`/`PYTHONOPTIMIZE` in the batch, `tools/run_tests.sh`, flavours.yml or ps2build.yml, so the
C `assert` harnesses are live; no swallowed exceptions around assertions; every `subprocess.run` either
uses `check=True` or branches on `returncode` to `sys.exit`/raise (test_mcemu_slots.py:87 uses
`check=False` but compares stdout exactly to the expected 4 lines, so a crash still fails the test).

## (b) Candidate findings (unnumbered)

### Candidate 1 — test_hires_thread_priority exercises only rows 6–11 as "the multi-pass ones"; the four appended multi-pass rows (16–19) get no coverage in the test at all

- **Category:** 8 (half-finished/redundant features — stale fixture, partial vacuous pass; hunt class 5)
- **Locations:**
  - `.github/scripts/test_hires_thread_priority.py:118-119` — comment "Rows 6..11 are the multi-pass ones (704x576i, 704x480i, 704x480p, 704x576p, 720p, 1080i)" and `for (int hires = 6; hires <= 11; hires++)`
  - `.github/scripts/test_hires_thread_priority.py:128-129` — the hires→hires and repeated-trip checks also use only rows 10, 11 and `6 + i % 6`
  - `.github/scripts/test_hires_thread_priority.py:142` — the only all-rows loop is restricted to `passes == 1`, so it also skips the appended multi-pass rows
  - Production table, READ: `src/gfx/renderman.cpp:52`ff — rows 16 (`{GS_MODE_NTSC, 16, 704, 480, 2, …640, 448}` "NTSC@60Hz HIRES, 448-line area", at :102), 17–19 (the three lineBlend twins with `passes = 2`, at :110-112) are multi-pass exactly like rows 6–11
  - Production mechanism, READ: `src/gfx/renderman.cpp:246` — `hires_ = (rm_mode_table[vmode_].passes > 1) ? 1 : 0;` — rows 16–19 take the same gsKit hires path, the same caller-priority bump to 2 and the same restore-on-exit code the test exists to pin
- **Problem:** The test's stated purpose (file docstring) is that leaving *a* multi-pass mode restores the entering thread's priority. Its row set is a hard-coded range frozen before the table's tail appends: 4 of the 10 multi-pass rows — the 448-line HIRES row and all three flicker-filtered (lineBlend) HIRES rows, i.e. precisely the newest modes — are never entered or left in any scenario (bump/restore, cross-thread, ReferThreadStatus-failure, or the dozen-trip loop). A regression in `Renderer::setMode`/`end` that mishandles those rows (e.g. keyed to the lineBlend or safe-area fields those rows uniquely carry) passes this suite silently. The table's own comments (`src/gfx/renderman.cpp:80-81,103-107`) say rows are only ever appended at the tail because `$VMode` is a stored index, so a fixed 6–11 range is guaranteed to drift again.
- **Fix in words:** Derive the exercised hires set from the extracted production table itself (every row with `passes > 1`) instead of the literal 6–11 range, in all three loops; delete or correct the "Rows 6..11" comment.
- **Justification if the fix adds anything:** Adds nothing net — a loop bound derived from data already extracted into the harness replaces three literal ranges.
- **Benefit:** All 10 current multi-pass rows, and any future appended row, get the priority-restore check the suite advertises; the silent-coverage-gap failure mode is removed, not just patched for today's rows.
- **Effort:** S
- **Risk:** Low — test-only change; newly covered rows run the identical production `setMode`/`end` bodies already compiled into the harness.
- **Confidence:** High, READ (row passes values, the `hires_` predicate, and every loop bound were read at the pin; the suite passing today is consistent with CI, the gap is structural, not a claimed current failure).

### Candidate 2 — NUM_RM_VMODES is hard-coded as 20 in two renderman tests while the third extracts it from the source

- **Category:** 2 (duplication — stale duplicated constant; hunt class 5)
- **Locations:**
  - `.github/scripts/test_vmode_safe_area.py:58` — `constexpr int NUM_RM_VMODES = 20;` (drives the all-rows loop at :80)
  - `.github/scripts/test_hires_thread_priority.py:65` — `constexpr int NUM_RM_VMODES = 20;` (drives the loop at :142)
  - `.github/scripts/test_hires_line_blend.py:45-46` — the sibling test extracts `constexpr int NUM_RM_VMODES` from `src/gfx/renderman.cpp` instead of restating it
  - Production, READ: `src/gfx/renderman.cpp:24` — `constexpr int NUM_RM_VMODES = 20;` (matches today)
- **Problem:** Both hard-coded copies are correct at the pin, but the constant is the loop bound for "check every mode" claims. When the table next grows by tail-append (its documented growth pattern), both tests will silently iterate a prefix of the table and still report "ok", while test_hires_line_blend — testing the same table in the same batch — keeps covering all rows. The inconsistency proves the extraction pattern was available and not applied.
- **Fix in words:** Extract the constant from `src/gfx/renderman.cpp` in both files, exactly as test_hires_line_blend.py:45 already does; delete the two literals.
- **Justification if the fix adds anything:** None — pure replacement of a literal with the extraction the sibling file already performs.
- **Benefit:** The "every mode" loops in both suites stay every-mode when the table grows; one less silent-prefix failure mode (complements Candidate 1, which fixes the row-range version of the same drift in the same file).
- **Effort:** S
- **Risk:** Low
- **Confidence:** High, READ for the duplication and today's match; INFERRED for the future under-coverage (it follows mechanically from the loop bounds).

### Candidate 3 — test_neutrino_bsdfs success message claims 28 preflight scenarios; the harness runs 30

- **Category:** 7 (build/CI/repo clutter — stale expected-output string; hunt class 5)
- **Locations:**
  - `.github/scripts/test_neutrino_bsdfs.py:100-131` — 30 `scenario(...)` call sites (counted, READ: lines 100–114, 116–125, 127–131)
  - `.github/scripts/test_neutrino_bsdfs.py:209` — `print('neutrino bsdfs: 28 preflight scenarios + 8 argv checks OK …')`
- **Problem:** The printed tally — the only human-facing summary of what the suite covered, and the line that lands in CI logs — understates the scenario count by 2 (the argv half, 8, is accurate: 6 `neutrinoEffectiveBsdfs` checks, 1 `neutrinoArgHasActiveFlag` check and the `appendArgTokens` ordering block). The count was not updated when the last `--b`-scope scenarios were added. Pass/fail is unaffected (the C harness returns `fails ? 1 : 0`), so this is a reporting-integrity defect only — but in a corpus whose other tallies check out exactly (test_handoff_probe.py "9 device scenarios" = 9 `run()` calls; test_cheat_load.py "15 device/tar scenarios" = 15 `scenario()` calls, both READ-verified), this is the one stale count.
- **Fix in words:** Drop the hard-coded numbers from the success line, or compute the scenario count in the harness and print that.
- **Justification if the fix adds anything:** None — removing a literal cannot drift again.
- **Benefit:** CI log summaries state the coverage that actually ran.
- **Effort:** S
- **Risk:** Low
- **Confidence:** High, READ (call sites enumerated line by line).

### Candidate 4 — The identical 12-line `function_text` extractor is duplicated verbatim in four batch files

- **Category:** 2 (duplication; hunt class 4/6)
- **Locations (all in this batch, identical normalised body per the round-8 dup census, READ-confirmed definitions):**
  - `.github/scripts/test_config_missing_open_once.py:31`
  - `.github/scripts/test_hires_line_blend.py:27`
  - `.github/scripts/test_hires_thread_priority.py:28`
  - `.github/scripts/test_vmode_safe_area.py:27`
  - Cross-batch instances of smaller `function()` extractor variants involving batch files (noted by name, per instructions): test_ra_module_startup.py:18 (8-line `function`, also in test_game_size_fallback.py, test_info_size_ps1.py, test_menu_crash_catcher.py, test_ps1_duplicates.py), test_mcemu_slots.py:29 (5-line `function`, also in test_mc_folders.py, test_neutrino_cheats.py, test_patch_zone_restore.py), test_iop_pad.py:24 (5-line `function`, also in test_accurate_read_rate.py), test_ilink_manager_recovery.py:23 (4-line `function`, also in test_ilink_manager_irq.py)
- **Problem:** Four copies of the same brace-matching extractor (~12 lines each, ~36 duplicated lines in this batch alone) must be fixed in four places when the extraction contract changes (e.g. a signature form the regex misses). The corpus already has the shared-module precedent these files could use — `hostmap.py`, imported by test_neutrino_bsdfs.py, test_cheat_load.py, test_neutrino_ra.py and test_bdm_private_allocation.py in this batch — so standalone-script structure is not a blocker. This is helper duplication only: no duplicated *test bodies* (C harness scenarios) were found within the batch.
- **Fix in words:** Move one `function_text` implementation into the shared test-helper module (alongside hostmap) and import it from the four files; leave the smaller per-file `function()` variants alone unless a second change touches them.
- **Justification if the fix adds anything:** The shared helper already exists in four copies; consolidating removes ~36 lines and adds only import lines.
- **Benefit:** One place to fix extraction bugs; the four renderman/config suites stop drifting apart in how they slice production functions.
- **Effort:** S
- **Risk:** Low — import path is the script's own directory in every runner (`tools/run_tests.sh` and flavours.yml both invoke the file by path).
- **Confidence:** High, READ (dup census identical-body hash group [ba7d871f7867] ×4, definitions sighted in all four files).

### Candidate 5 — Dead dual-layout (pre-C++ tree) fallbacks referencing files absent at the pin in four ported tests

- **Category:** 1 (dead code; hunt class 3)
- **Locations:**
  - `.github/scripts/test_screen_pos_per_mode.py:25-30` — `cpp = (root / 'src/app/opl.cpp').exists()` selects between the RiptOPL paths and `'src/opl.c'` (×3), `'src/gui.c'`, `'lng_tmpl/_base.yml'`
  - `.github/scripts/test_ripps2_boot_video_mode.py:22-23,37-45,126,129` — same `cpp` probe for `'src/opl.c'`, plus C-vs-C++ `CONFIG`/`ACCESS`/compiler ternaries that only the `.c` layout would take
  - `.github/scripts/test_game_count_refresh.py:15-16,28-31` — `SOURCE` falls back to `'src/themes.c'`, with a parallel C `CONFIG`/`LIST` variant and harness rewrites for it
  - `.github/scripts/test_smb_launch_name.py:107-108` — guarded variant: probes `'src/ethsupport.c'` as a second candidate (but fails loudly with an update instruction if neither path exists)
  - Absences verified at the pin (READ, `test -e`): `src/opl.c`, `src/gui.c`, `src/themes.c`, `src/ethsupport.c`, `lng_tmpl/_base.yml` — none exist; the C++ paths all exist
- **Problem:** These tests were ported from the RIPPS2 C tree and kept a runtime layout probe: at this pin the C branch can never be taken, and every path it would read is absent, so the fallback is dead weight that misstates the tree the test pins. It is not a vacuous pass — if `src/app/opl.cpp` disappeared, the probe would flip and the test would crash reading a nonexistent fallback instead of reporting the rename — but it is ~15 lines of unexecutable selection logic across four files that every future reader must reason through, in a corpus where the other 36 batch files simply name the RiptOPL path directly.
- **Fix in words:** Delete the `cpp`/existence probes and the C-layout variants; name the C++ paths directly, as the rest of the batch does. For test_smb_launch_name.py, keep the loud "update this check" failure for a missing ethsupport source.
- **Justification if the fix adds anything:** None — deletions only.
- **Benefit:** Four tests state the one tree they actually verify; a future rename fails with the real filename in the traceback instead of a phantom C path.
- **Effort:** S
- **Risk:** Low — the deleted branches are unreachable at the pin and their targets do not exist.
- **Confidence:** High, READ (probes, branch targets and absences all verified at the pin).

## (c) Dissolved candidates

- **17 batch files absent from flavours.yml** (test_smb2_menu_wait_bounds, test_caduceus_overlay, test_retrogem_ember, test_vmc_pfs_reserve, test_neutrino_ra, test_ra_module_startup, test_ra_badge_rows, test_hdd_module_lifetime, test_bdm_ata_readiness, test_screen_pos_per_mode, test_libview_l3_rescan, test_ripps2_boot_video_mode, test_ilink_manager_recovery, test_ra_launch_resources, test_ripps2_library_port, test_ulcfg_rebuild, test_mcemu_slots) — dissolved: not dead; all run via `tools/run_tests.sh -k` at ps2build.yml:71, as the round-7 ledger already established (READ re-confirmed).
- **test_wiki_sync.py bs4 skip-to-pass** — dissolved on this axis: it is RIPTOPL-290's exact mechanism, and flavours.yml:351-356's dedicated venv is the mitigation R290 already cited; no new evidence extends or revises it.
- **test_release_notes.py testing only normalize_release_notes.py** — dissolved on this axis: RIPTOPL-288's exact mechanism; the suite itself (real temp git history, bounded-history and repeat-normalization assertions, unittest exit codes) is sound and adds no new evidence.
- **Compiler-absence vacuity (RIPTOPL-291 axis)** — dissolved for this batch: grep READ shows no skip guard in any batch file; a missing compiler raises or fails the returncode check, i.e. the corpus's stricter pattern, not a skip.
- **Exit-code loss in harness runners** — dissolved: every flagged `subprocess.run` without `check=True` was read at its tail (test_hdd_module_lifetime.py:151-163, test_bdm_ata_readiness.py:156-162, test_ilink_manager_recovery.py:150-157, test_ulcfg_rebuild.py:143-148, test_mcemu_slots.py:83-90) and each branches on `returncode` or compares exact expected output.
- **Deleted-code references in docstrings** — dissolved: test_vmc_pfs_reserve.py's reference to test_pfs_vmc_inode.py, test_smb2_auth.py's references to test_smb2_logon_parity.py and tests/smb2-live/run.sh, and test_smb_launch_name.py's launchname.c/longname.c all exist at the pin (READ, `test -e`); extraction-based tests self-fail on a missing production symbol because `source.index(...)` raises.
- **Tests encoding a prior finding's bug as correct (hunt class 2)** — dissolved: prior ul.cfg findings (RIPTOPL-181/182) concern `tools/pc/opl2iso`, a different code path from the `sbRebuildULCfg`/`sbRename` span test_ulcfg_rebuild.py executes; no other prior RIPTOPL-001…295 finding's subject behaviour is asserted as correct by a batch test (checked by subject grep against the per-repo reports).
- **test_bdm_ata_readiness.py `-w` compile flag and `--baseline` mode** — dissolved: `-w` suppresses warnings only; assertions and return-code gates are intact, and `--baseline` is a documented manual pre-fix demonstration path, not a CI execution path.
- **test_smb2_menu_wait_bounds.py wall-clock assertions (250–3000 ms)** — dissolved: a load-dependent flake risk, but the assertions can and do fail; not a vacuous pass.
- **test_caduceus_overlay.py / test_smb2_menu_wait_bounds.py compiling without `-Werror`** — dissolved as a standalone claim: warnings are not a gate anywhere in the test corpus's own runners, and both files' runtime assertions are fully wired to exit codes.
- **test_iop_pad.py expected-output list comparison** — dissolved: a short harness output raises IndexError (nonzero exit); all 12 expected cases are prefix-checked in order.
