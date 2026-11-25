# Round 8 — Section 02 — RiptOPL test corpus, batch 02

- Repo: NathanNeurotic/RiptOPL, clone `~/workspace/audit-clones-2026-11-13/RiptOPL`, pin `2e347d5ac885` (verified, not updated; `git status` clean before and after).
- Batch: 23 files, 6,798 lines, every file line-read in full in batch order (largest first).
- Verification run (READ): all 23 suites were executed once at the pin in this VM (host gcc/g++, Python ≥3.11 with tomllib, PyYAML present) — all 23 exit 0. Every "cannot fail / skip" claim below is therefore about a *conditional* environment, not the environment used for that run, and says which.
- CI truth used throughout (READ): `.github/workflows/flavours.yml:19` runs on `ubuntu-24.04` and `:25` installs `requirements.txt` (PyYAML==6.0.3); most batch files are named there explicitly, and the i.LINK files run via the `test_ilink_*.py` glob at `flavours.yml:103-107`. The remaining batch files (`test_ember_scan_missing_core.py`, `test_neutrino_cheats.py`, `test_neutrino_toml_repair.py`, `test_iso9660_records.py`, `test_zso_validation.py`, `test_media_lsn_count.py`) run via `tools/run_tests.sh` from `.github/workflows/ps2build.yml:71` (`tools/run_tests.sh:7` loops over every `.github/scripts/test_*.py`). Ubuntu 24.04 / ubuntu-latest ship Python 3.12 and a host gcc — so neither the tomllib guard nor any compiler-absence guard in this batch is triggered in current CI; they trigger on the developer-machine route (`tools/run_tests.sh` on an older/local toolchain), which is exactly the route RIPTOPL-291 was filed on.

## (a) Per-file ledger

| path | lines | verdict |
|---|---|---|
| .github/scripts/test_ember_scan_missing_core.py | 363 | finding — shared extractor candidate only |
| .github/scripts/test_neutrino_cheats.py | 363 | finding |
| .github/scripts/test_ilink_bd_assault_reset.py | 358 | finding |
| .github/scripts/test_app_launch_args.py | 353 | clean |
| .github/scripts/test_pad_repeat_clock.py | 353 | finding — shared extractor candidate only |
| .github/scripts/test_ilink_bd_reset.py | 342 | finding |
| .github/scripts/test_usbmass_two_drives.py | 337 | clean |
| .github/scripts/test_ilink_sbp2_completion.py | 330 | finding |
| .github/scripts/test_neutrino_toml_repair.py | 330 | finding — shared extractor candidate only |
| .github/scripts/test_menu_text_fit.py | 324 | finding |
| .github/scripts/test_config_save_integrity.py | 319 | finding — shared extractor candidate only |
| .github/scripts/test_stream_iop_deadlocks.py | 301 | clean |
| .github/scripts/test_ilink_discovery.py | 296 | finding — shared extractor candidate only |
| .github/scripts/test_art_queue_order.py | 282 | finding — shared extractor candidate only |
| .github/scripts/test_dia_text_room.py | 273 | finding — shared extractor candidate only |
| .github/scripts/test_iso_cache.py | 268 | finding — shared extractor candidate only |
| .github/scripts/test_pops_udpfs.py | 266 | finding |
| .github/scripts/test_smb2_negotiate_retry.py | 244 | clean |
| .github/scripts/test_theme_text_room.py | 242 | finding — shared extractor candidate only |
| .github/scripts/test_iso9660_records.py | 220 | finding — shared extractor candidate only (its compiler skip is RIPTOPL-291, not re-filed) |
| .github/scripts/test_vmc_preserve_existing.py | 220 | clean |
| .github/scripts/test_media_lsn_count.py | 215 | finding — shared extractor candidate only |
| .github/scripts/test_zso_validation.py | 199 | finding |

## (b) Candidate findings (unnumbered)

### Candidate 1 — EXTENDS RIPTOPL-291: `test_zso_validation.py` passes with no host compiler, its whole compiled harness skipped
- Category: 8
- Locations: RiptOPL/.github/scripts/test_zso_validation.py:164-169 (`cc = shutil.which('gcc') or shutil.which('cc')`; `if cc is None: print('SKIP: no host C compiler'); return 1 if bad else 0`)
- Problem: RIPTOPL-291 filed this exact class for `test_iso9660_records.py`, `test_release_editions.py` and `test_install_ports.py` but did not list this file. Here, with no `gcc`/`cc`, `main()` returns 0 whenever the pure-Python `ziso_init()` call-site scan (lines 141-160) passes — while every compiled check in the file (refused align/block-size headers, sliced large reads, later-slice device failure, backwards/oversized corrupt index entries, lines 28-139) never runs, and `tools/run_tests.sh:9` tallies the exit-0 as "ok". Contrast inside the same batch: `test_stream_iop_deadlocks.py`, `test_smb2_negotiate_retry.py` and `test_usbmass_two_drives.py` all exit non-zero when no compiler exists (READ). Not triggered in current CI (ubuntu images carry gcc — see header), same conditional status as RIPTOPL-291 itself.
- Fix in words: Make a missing compiler a failure, like the three sibling suites above, instead of a printed SKIP with exit 0.
- Justification if the fix adds anything: Adds nothing; it removes a conditional vacuous pass.
- Benefit: The ZSO reader's only corrupt-index/header regression suite cannot silently evaporate on a compiler-less host.
- Effort: S / Risk: Low / Confidence: High (READ)

### Candidate 2 — `test_neutrino_cheats.py`: the TOML-parse assertions are silently skipped on Python < 3.11
- Category: 8
- Locations: RiptOPL/.github/scripts/test_neutrino_cheats.py:19-22 (`try: import tomllib / except ImportError: tomllib = None`, comment: "the TOML parse is skipped, every other check still runs"); :206-210 (`toml_of` returns `data=None` when tomllib is absent); :223 and :253 (both parse assertions guarded by `if data is not None and …`)
- Problem: On Python < 3.11 the two assertions that actually validate what Neutrino will read — that the written file parses and its `eecore.cheats` equals the code list with no stray `depends` (:223), and that a user `-cfg=` produces exactly the expected `depends` (:253) — are skipped with no failure, no printed notice in the output, and the suite still prints its full success line and exits 0. What remains is file-existence and one literal hex-format substring check. Not triggered in current CI (flavours/ps2build runners are Python 3.12 — see header); triggered by `tools/run_tests.sh` on any pre-3.11 developer host, the population `tools/run_tests.sh` exists for ("no PS2 toolchain needed", `tools/run_tests.sh:2`).
- Fix in words: Treat a missing tomllib as a failure of this suite (or vendor no parser — fail), rather than degrading the parse checks to no-ops; the file already hard-fails (`sys.exit`) for every other missing prerequisite it extracts.
- Justification if the fix adds anything: Adds nothing; removes a silent conditional pass.
- Benefit: A malformed-TOML regression in the cheat hand-over cannot pass unnoticed on older-Python hosts.
- Effort: S / Risk: Low / Confidence: High (READ; CI non-triggering also READ from the workflow pins above)

### Candidate 3 — The two i.LINK reset suites are one ~340-line harness stored twice, and the copies have already drifted
- Category: 2
- Locations: RiptOPL/.github/scripts/test_ilink_bd_reset.py:71-341 and RiptOPL/.github/scripts/test_ilink_bd_assault_reset.py:84-357 (STUBS, SCSI_HARNESS, LOGIN_HARNESS and `compile_and_run` in both)
- Problem: The two files differ essentially in the driver directory they point at, the `bdm.h` stub (one extra `char *path;`), the SCSI opcode spelling (SDK enum names vs a local raw-opcode enum), the `scsi_interface` initializer arity, and case ordering. Everything else — the simulated drive, the simulated clock, all LOGIN cases (1 s / 1.6 s / 4.5 s holds, 5 s budget, bus-reset abort, already-logged-in retry), all warm-up failure cases, the compile/run plumbing — is duplicated text. The drift the duplication invites is already visible (READ, from a diff of the two files at the pin): (i) the assault copy filters a failing harness's stdout to `FAIL ` lines and synthesises a crash line for exit codes outside 0/1, the ilink copy returns every stdout line; (ii) the ilink copy gates both harness runs on `if not failures:` (its :330), the assault copy runs the SCSI harness unconditionally even when login extraction already failed; (iii) the ilink copy hard-fails extraction if the budget defines/`sbp2ElapsedUs` are absent (its :66-70), the assault copy deliberately tolerates their absence so the behaviour checks themselves fail on pre-fix sources (its :71-77). Three different answers to "what does this harness do on old/broken sources", in two copies of the same harness. This is the test-side mirror of the production duplication in RIPTOPL-047; it is filed against the tests, not the drivers.
- Fix in words: Keep one harness module (the assault copy's optional-driver-argument shape already generalises: it takes the driver directory as `sys.argv[1]`) and make both suites thin invocations of it with their per-driver deltas (include path, mini-driver flag, opcode spelling, extraction strictness) as parameters.
- Justification if the fix adds anything: Adds one shared harness file only by moving existing code into it; net deletion is roughly one whole suite (~330 lines).
- Benefit: A harness fix (timeout, failure reporting, a new login case) lands once, and the two drivers are thereafter tested by provably the same simulated drive.
- Effort: M / Risk: Low (host tests only; both suites currently pass and must still pass) / Confidence: High (READ — full diff taken at the pin)

### Candidate 4 — `test_pops_udpfs.py` can only run if the gitignored `build/` directory already exists
- Category: 7
- Locations: RiptOPL/.github/scripts/test_pops_udpfs.py:171 (`tempfile.TemporaryDirectory(dir=ROOT / 'build')`); RiptOPL/.gitignore:110 (`/build/`)
- Problem: `build/` is gitignored and untracked (`git check-ignore` and an empty `git ls-files build` at the pin, READ), so a fresh checkout has no such directory and `TemporaryDirectory(dir=…)` raises `FileNotFoundError` before a single check runs — the suite fails for an environmental reason unrelated to anything it tests. In the current CI sequences the failure is masked (INFERRED: earlier steps in the same jobs create `build/` — `tools/assets.py all` in ps2build.yml, and prior steps in flavours.yml's migration job; in this audit clone `build/` exists only as a leftover of earlier runs, containing a `test-tmp` directory). It is the only file in this batch that anchors its scratch space inside the repo tree; every other batch file uses a default-location `TemporaryDirectory()`. Standalone execution — the way `tools/run_tests.sh` and a developer invoke it — is exactly the case that breaks.
- Fix in words: Drop the `dir=` argument (use the system temp location like the other 22 batch files), or create the directory before use if a repo-local temp is genuinely required.
- Justification if the fix adds anything: Adds nothing.
- Benefit: The suite runs identically standalone, in CI, and in a fresh clone; one spurious-failure mode gone.
- Effort: S / Risk: Low / Confidence: High for the mechanism (READ: code line + gitignore + untracked status); Med for the CI-masking explanation (INFERRED)

### Candidate 5 — `test_ilink_sbp2_completion.py` hard-codes the production login budget and carries a dead placeholder replace
- Category: 7
- Locations: RiptOPL/.github/scripts/test_ilink_sbp2_completion.py:311-313 (`.replace('@LOGIN_BUDGET@', '5000000')` followed by prepending `#define SBP2_LOGIN_BUDGET_US 5000000`); production value at RiptOPL/modules/ilink/IEEE1394_bd/src/sbp2_driver.c:142 and RiptOPL/modules/bdmassault/ilink_bd_assault/src/IEEE1394_bd/src/sbp2_driver.c:141 (`#define SBP2_LOGIN_BUDGET_US (5 * 1000 * 1000)`)
- Problem: Two defects in three lines (READ). (i) The `@LOGIN_BUDGET@` token occurs nowhere in the harness text — the only placeholders are `@STATE@` and `@FUNCTIONS@` (:36, :110) — so the replace at :312 is a no-op left behind by an earlier shape of the file. (ii) The budget the extracted `ieee1394_SendManagementORB` is then tested against is a hand-copied literal `5000000`, not the define extracted from the driver under test. It happens to equal the production value at this pin (verified above), so the suite passes — but if either driver's budget changes, this suite keeps certifying the old 5 s behaviour for both drivers, a stale fixture of exactly the kind this round hunts. The sibling suite shows the correct pattern: `test_ilink_bd_reset.py:66` extracts `SBP2_LOGIN_BUDGET_US` from the driver source itself.
- Fix in words: Delete the dead replace, and extract the `SBP2_LOGIN_BUDGET_US` define from each driver (as the sibling suite does) instead of prepending a literal.
- Justification if the fix adds anything: Adds nothing; net deletion plus reuse of an extraction the corpus already has.
- Benefit: A future budget change is tested at its new value instead of being silently certified at the old one.
- Effort: S / Risk: Low / Confidence: High (READ)

### Candidate 6 — `test_menu_text_fit.py` carries a complete dead Open-PS2-Loader configuration branch in this repo
- Category: 1
- Locations: RiptOPL/.github/scripts/test_menu_text_fit.py:35-56 (the `else:  # Open-PS2-Loader` LAYOUT dict at :45-56, selected when `src/ui/guinotify.cpp` is absent)
- Problem: The docstring (:4-5) says the script "finds which tree it is in". In this repo the RiptOPL branch is always taken: the else branch names paths that do not exist at the pin (verified absent: `src/gui.c`, `lng_tmpl/` — the RiptOPL tree has `src/ui/guinotify.cpp` and `lng/tmpl/`), a different render signature, different buffer regexes, C (not C++) compilers and a different cheat-screen signature — roughly a dozen configuration values plus the branch logic that exist only to serve a different repository's copy of this file. Any edit to the shared body below must be reasoned about against two layouts, one of which can never execute here and can never be caught by this repo's CI if it rots.
- Fix in words: Delete the else branch and the tree-detection conditional; keep the RiptOPL LAYOUT as a plain assignment. (If upstream OPL still needs its copy, it keeps its own — the two repos' files are already separate copies.)
- Justification if the fix adds anything: Adds nothing; pure deletion.
- Benefit: ~15 lines and one config dimension removed from a suite every RiptOPL contributor must read; no behaviour change in this repo.
- Effort: S / Risk: Low / Confidence: Med (READ that the branch is unreachable and its paths absent at this pin; INFERRED that no out-of-repo consumer runs this copy against an OPL tree)

### Candidate 7 — Seventeen batch files each re-implement the same C-function extractor, in at least three incompatible variants
- Category: 2
- Locations (representative, READ): naive `\n}` slicing — RiptOPL/.github/scripts/test_ember_scan_missing_core.py:36-44, test_neutrino_cheats.py (its `function()`), test_config_save_integrity.py, test_iso_cache.py, test_media_lsn_count.py; brace-counting string/char-aware — test_ilink_bd_reset.py, test_ilink_bd_assault_reset.py, test_neutrino_toml_repair.py, test_menu_text_fit.py, test_dia_text_room.py; signature-plus-`\n{` index form — test_ilink_discovery.py, test_ilink_sbp2_completion.py. Full set in this batch: ember_scan_missing_core, neutrino_cheats, ilink_bd_assault_reset, pad_repeat_clock, ilink_bd_reset, neutrino_toml_repair, menu_text_fit, config_save_integrity, ilink_discovery, art_queue_order, dia_text_room, iso_cache, pops_udpfs, theme_text_room, iso9660_records, media_lsn_count, ilink_sbp2_completion (17 files, ~15-30 lines each).
- Problem: Every source-scraping suite in the batch begins by re-solving "extract one function body from a .cpp file", and the copies disagree on the hard cases: the naive variant ends a function at the first line that is exactly `}` (wrong for a function containing a bare closing brace in a string or a nested block at column 0), the brace-counting variant handles strings/chars/comments, the index variant requires the brace on its own line. A fix or a newly hit edge case must be propagated by hand, and a suite's extraction reliability silently depends on which variant its author happened to copy. The corpus already has the shared-module precedent: `hostmap.py` sits beside the tests and is imported by exactly this kind of suite (`test_neutrino_cheats.py`, `test_app_launch_args.py`).
- Fix in words: Move the brace-counting extractor (the most correct existing variant) into a shared module beside `hostmap.py` and have the batch's suites import it, deleting their local copies; leave each suite's failure-reporting wrapper in place.
- Justification if the fix adds anything: The shared module is not new code — it is one of the existing copies, promoted; the other sixteen copies are deleted.
- Benefit: ~250-400 duplicated lines removed across the batch (more corpus-wide), and one extractor whose edge cases are fixed once.
- Effort: M / Risk: Low (import change per file; all suites are fast host tests that must still pass) / Confidence: High (READ)

## (c) Dissolved candidates

- test_iso9660_records.py compiler skip (`skipUnless(CC)` at :112): already RIPTOPL-291 verbatim; no new evidence in a full re-read, not re-filed. Its ASan→plain build fallback (:122-130) and test_zso_validation.py's identical fallback are documented "when available" behaviour, and a failure of the plain build still fails the suite — dissolved.
- Bare Python `assert` as the sole guard in places (test_config_save_integrity.py:316-319; the language-hint asserts in test_app_launch_args.py:23-28; the post-harness wiring asserts in test_pops_udpfs.py): these vanish under `python3 -O`/PYTHONOPTIMIZE, but no invocation at the pin uses either (grep of `.github/workflows/*.yml` and `tools/run_tests.sh` — negative, READ), so there is no actual vacuous-pass route today — dissolved as latent-only.
- test_stream_iop_deadlocks.py vs RIPTOPL-045 (the `sceSifDmaStat` busy-spin at streaming.c:234-235): the harness's fake `sceSifDmaStat` returns -1 unconditionally, so that spin is indeed unexercised — but the suite's three stated cases are real, non-vacuous, and do not assert the spin's behaviour as correct; a coverage gap next to a finding is not a test encoding the bug — dissolved (noted here so round 9 need not re-derive it).
- test_iso_cache.py's reference `oldModified` indexing `cache->games[i]` inside its `j` loop: it is the removed production code reproduced verbatim as the equivalence oracle, with a deliberate +64-entry slack pool (:171) keeping its known over-read defined; the suite's claim is "decides exactly when the old one did", which the bug is part of — dissolved.
- test_neutrino_cheats.py not checking the picks harness's returncode: a crash or partial run yields stdout that cannot equal the exact expected line list (:190-198), so the failure is still caught — dissolved.
- test_menu_text_fit.py's unguarded `import yaml` in the ps2build job (which has no pip-install step, unlike flavours.yml:25): PyYAML is present in this VM's interpreter and the suite passes; whether the GitHub ubuntu-latest image guarantees it could not be verified from anything at the pin — INFERRED risk only, dissolved rather than filed on a guess.
- test_ember_scan_missing_core.py gating its second (messages) harness on `if not failures:`: a first-harness failure already forces exit 1, so nothing is masked — dissolved.
- Cross-batch duplicate suspicion (by name/mechanism, noted for the parent, not filed): the torn-tail TOML cases are deliberately split between test_neutrino_toml_repair.py (batch 02) and test_neutrino_toml_sync.py (its docstring :5 explicitly defers torn tails to the repair file) — complementary, not duplicated; the `fntWrapText` extraction shared by test_dia_text_room.py and test_menu_text_fit.py is an instance of Candidate 7, not a separate duplication.
- No batch file was found testing a deleted/renamed production module or function (every extracted signature, path and fixture was verified present at the pin — including test_pops_udpfs.py's pinned BDMAssault 1.0.1 sizes/hashes, which match `ship/POPS/` and `src/sources/vcdsupport.cpp:1706`), and no batch test was found asserting as correct any behaviour a RIPTOPL-001…295 finding identifies as a defect (checked against RIPTOPL-045, -047, -239, -245 and the SMB2/ZSO/VMC areas the batch touches) — negative results, READ.
