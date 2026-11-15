# Round 8 — Section 10: RiptOPL test corpus, batch 10 (.github/scripts, smallest files)

Pin: 2e347d5ac885 (verified, clone untouched, `git status` clean). All 11 files line-read in full, in batch order. Line counts are the batch-file counts; total 468 lines.

Execution baseline (READ): all 11 files were run at the pin on this VM (gcc, g++ and cc all present) and every one exited 0. No file in the batch references a module, function or path that is absent at the pin — hunt class 3 (tests of deleted/renamed code) is a negative result for this batch, verified by execution plus targeted grep.

CI environment used for the skip analysis (READ): `.github/workflows/ps2build.yml:70-71` runs `tools/run_tests.sh -k`; `tools/run_tests.sh:9` invokes every suite as `python3 "$t"` with **no arguments**. `.github/workflows/flavours.yml` (ubuntu-24.04) names four batch files individually, also with no arguments — `test_pad_pattern_bounds.py` (:38), `test_logo_art_toggle.py` (:252), `test_about_credits_layout.py` (:264), `test_cnf_missing_equals.py` (:287). The other seven batch files run in CI only via the run_tests.sh sweep. No batch file contains a skip/skipUnless; the three batch files that need a compiler (pad/gcc, cnf/g++, ra_language/cc) fail closed on its absence (uncaught `FileNotFoundError` through `check=True` subprocesses → non-zero exit), which is distinct from the three skip-to-pass files already covered by RIPTOPL-291 — no new evidence on that axis.

## (a) Per-file ledger

| Path | Lines | Verdict |
|---|---|---|
| .github/scripts/test_smap_tx_base.py | 51 | clean |
| .github/scripts/test_pad_pattern_bounds.py | 50 | finding |
| .github/scripts/test_logo_art_toggle.py | 48 | clean |
| .github/scripts/test_audit_translations.py | 47 | finding |
| .github/scripts/test_cnf_missing_equals.py | 45 | finding |
| .github/scripts/test_korium_builtin_assets.py | 45 | clean |
| .github/scripts/test_about_credits_layout.py | 42 | finding |
| .github/scripts/test_ra_support_check.py | 42 | clean |
| .github/scripts/test_ra_language_isolation.py | 38 | clean |
| .github/scripts/test_sfx_oneshot_cut.py | 31 | finding |
| .github/scripts/test_menu_tab_sound_unlocked.py | 29 | clean |

## (b) Candidate findings (unnumbered)

### Candidate 1 — test_pad_pattern_bounds.py's only ASan-isolated overread case is gated on an argument no CI invocation ever passes
- **Category:** 6 (bugs/security — a vacuous branch inside an otherwise executed test)
- **Locations:** `RiptOPL/.github/scripts/test_pad_pattern_bounds.py:22-26` (the `if (argc>1)` heap case in the generated C program), `:40` (the unconditional PASS line), `:50` (the exe is run with `*sys.argv[2:]`), `:8` (`sys.argv[1]` is consumed as a source-path override); invocations at `RiptOPL/tools/run_tests.sh:9` (`python3 "$t"`, no arguments) and `RiptOPL/.github/workflows/flavours.yml:38` (no arguments).
- **Problem:** READ. The generated C program's heap case — a pattern search over a `malloc(sizeof(u32))` allocation, the only case in the file where a one-word overread crosses an allocation boundary and ASan's heap redzone can catch an overread whose extra word does not complete a match — runs only when the compiled exe receives an argument. Both sanctioned invocations pass none, so the exe's `argc` is 1 and the branch is skipped, while the program still prints "PASS: masked scan includes final/exact windows and rejects short/empty ranges without overread" (:40). The remaining short-range cases cannot substitute: `find_pattern_with_mask(data+1, 4, …)` at :31 reads `data[2]`, which is inside the 3-word stack array, so only a return-value mismatch is detectable there, and the `NULL,0` / 3-byte cases return before any read (production guard at `ee_core/src/util.c:114-115`). The gate is also nearly unreachable by hand: passing one extra argument makes the Python wrapper treat it as the source path (:8) and crash with `FileNotFoundError` (verified by running it); the heap case runs only with an explicit source path **and** a second dummy argument (verified: that invocation executes and passes). This is not RIPTOPL-291's compiler-absence mechanism — gcc is present in CI; the branch is dead because of argv plumbing.
- **Fix in words:** Drop the `argc>1` gate so the heap case always runs (or have the wrapper pass one fixed trigger argument to the exe at :50). Keep the `sys.argv[1]` source override for the Python side only.
- **Justification if the fix adds anything:** Adds nothing; removes a condition (or adds one constant argument at the existing call site).
- **Benefit:** The suite's only sanitizer proof against a non-matching overread actually executes in CI, and the PASS line stops claiming a check that did not run.
- **Effort:** S / **Risk:** Low / **Confidence:** High (gate, both invocations, and both manual invocation behaviours all READ/verified by running).

### Candidate 2 — test_about_credits_layout.py prints PASS for trimmed UI_BREAK rows and a kept row count, but never counts either
- **Category:** 6 (bugs/security — test claims a layout invariant it does not assert)
- **Locations:** `RiptOPL/.github/scripts/test_about_credits_layout.py:5-8` (docstring item 3: "Excess UI_BREAK rows are trimmed to prevent vertical overflow"), `:22-29` (the only assertions in the first half: financial-support absence and two QA name strings), `:31` (print claiming "trimmed spacing"), `:37-41` (the only UI_BREAK use in the file: `icyson` precedes the first UI_BREAK after `_STR_NET_UPDATE`), `:42` (print claiming "About keeps its row count").
- **Problem:** READ. Nothing in the file counts `UI_BREAK` entries, total `diaAbout` items, or dialog height. Re-adding excess `{UI_BREAK}` rows anywhere in `diaAbout` (production slice at `src/ui/dialogs.cpp:2091` to its terminator; 15 UI_BREAK entries at the pin, counted READ) — the exact regression docstring item 3 says the test guards, in a fixed non-scrolling dialog — leaves every assertion green while both PASS lines keep asserting the trimmed/kept-height outcome. The one structural check that does exist (:41) proves only that Network update and `icyson55` share a row; it is insensitive to rows added or removed anywhere else in the dialog. Incidental, same file: `import sys` at :10 is never used (AST-checked; the only unused import in the batch).
- **Fix in words:** Assert the exact UI_BREAK count (15 at the pin) and/or the exact diaAbout item count in the sliced array, and drop the unused `sys` import in the same pass.
- **Justification if the fix adds anything:** Adds one integer assertion; no new mechanism.
- **Benefit:** The vertical-overflow guard the file advertises becomes a guard that can fail.
- **Effort:** S / **Risk:** Low / **Confidence:** High (file read in full; production count READ).

### Candidate 3 — test_sfx_oneshot_cut.py's coalesce assertion can be satisfied by the comment inside the captured branch alone
- **Category:** 6 (bugs/security — comment stands in for code in a presence check)
- **Locations:** `RiptOPL/.github/scripts/test_sfx_oneshot_cut.py:17` (branch capture regex), `:25-26` (bare-token check `'SFX_ONESHOT_COALESCE_MS' not in branch.group(1)`); production token sites at `RiptOPL/src/core/sfx.cpp:399` (`} else if (sfxIsUiOneShot(id)) { // see SFX_ONESHOT_COALESCE_MS` — the comment sits **after** the opening brace, so it is inside the captured group) and `RiptOPL/src/core/sfx.cpp:402` (the real comparison), definition at `src/core/sfx.cpp:79`.
- **Problem:** READ, verified by re-running the file's own extraction: the captured branch group contains the token twice — once in the :399 comment and once in the :402 comparison — and deleting the comparison line from the captured text leaves the token present, so the assertion at test :25-26 still passes. If the coalesce comparison were removed (or replaced by a literal) while the branch comment stayed, the test would keep printing "same-frame double raise coalesced" for code that no longer coalesces. The batch itself shows the correct pattern: `test_smap_tx_base.py:15-20` strips comments precisely so a commented copy cannot stand in for live code; this file does no stripping. The other assertion in the file (the exact `audsrv_ch_play_adpcm` call list at :22-24) is not affected.
- **Fix in words:** Strip comments from the extracted `play()` body before the branch checks (the smap file's approach), or assert the comparison expression (`< SFX_ONESHOT_COALESCE_MS)`) instead of the bare token.
- **Justification if the fix adds anything:** Adds nothing material; reuses an idiom already in the corpus or tightens one string.
- **Benefit:** The #575 double-raise coalesce guard can actually fail when the coalesce stops being code.
- **Effort:** S / **Risk:** Low / **Confidence:** High (extraction re-run and token locations READ).

### Candidate 4 — Neither ps2cnf host test exercises the ≥64-char BOOT2 value that RIPTOPL-158 flags, so the unterminated-string path has no regression test (cross-reference RIPTOPL-158; the production bug is not re-filed)
- **Category:** 6 (bugs/security — missing coverage for a known defect in disc-supplied parsing)
- **Locations:** `RiptOPL/.github/scripts/test_cnf_missing_equals.py:1` ("Execute the complete production SYSTEM.CNF file parser"), `:30-38` (the full case list; longest BOOT2 value is 21 chars, `cdrom0:\SLUS_200.62;1`); defect site per RIPTOPL-158 at `RiptOPL/src/platform/ps2cnf.cpp:54-65` (`CNFGetKey` loop capped at `i < CNF_PATH_LEN_MAX` with no terminator written on the cap exit) and `RiptOPL/include/ps2cnf.h:1` (`CNF_PATH_LEN_MAX 64`).
- **Problem:** READ. The batch file executes the real parser under ASan/UBSan with a strong harness (invalid cases must leave the 0xa7-filled output untouched, :21-25), but every case is far below the 64-char cap, so the one input class already established as defective — a BOOT2 value of 64+ printable chars, returned as success in an unterminated 64-byte buffer — is untested. The gap is corpus-wide for this parser, not just this file: the only other ps2cnf test, `tests/host/test_ps2cnf.cpp` (read in full), likewise has no case longer than 21 chars. A fix for RIPTOPL-158 could regress, or the cap behaviour change shape, with both suites green.
- **Fix in words:** Add a ≥64-char BOOT2 case (and a 63-char boundary case) to this file's case list, expecting the terminated/truncated result the RIPTOPL-158 fix defines. The new case will fail against the current parser — land it together with that fix, not alone.
- **Justification if the fix adds anything:** Adds test cases only, reusing the existing harness and its untouched-output assertion pattern.
- **Benefit:** The known crafted-CNF defect class gains the regression test both existing suites lack.
- **Effort:** S / **Risk:** Low / **Confidence:** High (case lists and parser loop READ; RIPTOPL-158 read in the Round 5 report).

### Candidate 5 — test_audit_translations.py exercises only one of the tool's two --strict error classes; the unknown-overlay-label error is untested by the tool's only test
- **Category:** 6 (bugs/security — coverage gap in a strict gate)
- **Locations:** `RiptOPL/.github/scripts/test_audit_translations.py:26-46` (all three scenarios mutate the same key, Swedish `SETTINGS_SAVED`, into a printf-token mismatch); the untested class at `RiptOPL/tools/audit_translations.py:70` (`overlay has unknown label` errors), documented as a --strict failure at `tools/audit_translations.py:8-9`.
- **Problem:** READ. This file is the sole test that exercises `tools/audit_translations.py` at all (repo grep over `.github/scripts/`, `tests/` and `tools/`: only this file and the tool itself reference it). Its three scenarios thoroughly cover the format-token error — fresh tree, post-merge `lng_src/` copy, divergent-community warning — but no scenario adds an overlay label the base does not have, so the tool's other --strict error (an overlay key absent from `lng/tmpl/_base.yml`, which would otherwise be silently dropped from the merged language) can break or be removed without any test failing.
- **Fix in words:** Add one scenario to the existing temp-tree flow: inject a bogus label into the Swedish overlay and assert `--strict` exits 1 naming it as an overlay error, before and after the `lng_src/` copy step, mirroring the format scenarios.
- **Justification if the fix adds anything:** Adds one scenario reusing the existing `strict()` helper and fixture tree; no new machinery.
- **Benefit:** Both documented --strict failure modes of the translation gate are pinned, not just the format one.
- **Effort:** S / **Risk:** Low / **Confidence:** High (test scenarios and tool error paths READ; sole-test status grep-verified).

## (c) Dissolved candidates

- **SMAP driver list incomplete / whole-file descriptor search (test_smap_tx_base.py):** dissolved — grep at the pin shows only the three listed files reference `SMAP_R_TXFIFO_WR_PTR` (live sites `smap-ingame/xfer.c:277`, `smap_udpbd/src/xfer.c:180`, `udpfs_smap/src/xfer.c:232`), and `BD_data_ptr` is function-local in all three, so the whole-file `->pointer` search has no second copy that could stand in.
- **SMAP `code_only` preserves string literals (test_smap_tx_base.py:20):** dissolved — the string alternative exists so comment markers inside literals are not stripped mid-token; no string in the three drivers contains the checked pattern (all matches are the live code sites above).
- **Logo-art language IDs not literally appended (test_logo_art_toggle.py:41-44):** dissolved — the load-bearing invariant is relative order, and it holds at the pin (`lng/tmpl/_base.yml:1466` AUTO_VMC_STILL_RUNNING < :1470 LOGOART < :1472 HINT_LOGOART); labels after HINT_LOGOART are later appends, not a violation of the toggle's own append.
- **RA language isolation lets XERA_ strings into the standard binary (test_ra_language_isolation.py:24,37):** dissolved — the production compiler excludes exactly the same three prefixes (`tools/lang_compiler.py:76`: `RA_`, `HINT_RA_`, `CAD_`), and the binary scan's spellings are precise: `Caduceus` and capital-X `Xerabora` occur only in excluded-prefix strings (enumerated over `_base.yml`), while retained XERA_ strings spell it `xeRAbora`, which the scan correctly does not claim.
- **cnf test duplicates tests/host/test_ps2cnf.cpp:** dissolved as a duplication finding — fixture overlap is partial only; the batch file uniquely asserts the 0xa7 output-untouched property on invalid/EOF inputs and supports a git-ref source, the host file uniquely asserts ENOENT, BOOT≠BOOT2, tab whitespace and no-trailing-newline; not a duplicated body (the shared coverage gap is filed as Candidate 4 instead).
- **Korium UPSTREAM.json checks only coverapp, not case_overlay (test_korium_builtin_assets.py:38):** dissolved — the case_overlay leg is covered twice elsewhere in the same file (textures `CASE_OVERLAY2 == "NULL"` at :31 and the assets.py filter naming both bitmaps at :37), and both names are in fact absent from UPSTREAM.json's files list (verified).
- **audit_translations step 3 lets a bad lng_src string pass as a warning (test_audit_translations.py:42-46):** dissolved — divergence from the overlay is the tool's documented community-translation rule (`tools/audit_translations.py:10-11,74`); the laundering case that must stay an error is the identical copy, which step 2 (:36-40) does catch.
- **Duplicated extraction/slicing helpers across the batch:** dissolved for this batch — `test_ra_support_check.py:15-17` (`body()`) is the only named extractor; the other files use one-off inline slices with different signatures and terminators, and no two batch files share a helper implementation to delete (the corpus-wide helper-duplication question belongs to the larger batches' sections).
- **ra_support whole-file `sbNeutrinoPrepareRA(` search (test_ra_support_check.py:27-28):** dissolved — both hits are the live launch-path calls (`src/sources/udpfssupport.cpp:1172`, `src/sources/bdmlaunch.cpp:469`); no other copy exists in either file to stand in for them.
- **menu_tab / logo / korium presence checks satisfiable by comments:** dissolved — for each asserted code string, the production sites are live code with no comment carrying the same string (menuNextH/menuPrevH bodies at `src/ui/menusys.cpp:1914,1937` read in full; Korium PLAYERS loop at `src/gfx/themes.cpp:1798-1801`; logo guards at `src/gfx/themeelems.cpp:961-962`); the sfx file (Candidate 3) is the batch's only comment-contaminated check.
