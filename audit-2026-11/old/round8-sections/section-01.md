# Round 8 — Section 01: RiptOPL test corpus, batch 01 (.github/scripts, largest first)

Pin: 2e347d5ac885 (verified, clone untouched, `git status` clean). All 14 files line-read in full, in batch order. Line counts below are the batch-file counts; total 6,800 lines.

CI environment used for skip analysis (READ): `.github/workflows/flavours.yml` runs on `ubuntu-24.04` and explicitly runs test_install_ports.py (:31), test_ps2build_sdk_watch.py (:32), test_settings_back_keeps_edits.py (:161), test_smb1_reply_resync.py (:209), test_igr_menu_no_room.py (:244), test_sio2man_hooks.py (:254, plus the `test_ilink_*.py` glob at :101-106 which covers test_ilink_manager_safety.py), test_menu_sort.py (:308), test_ember_settings.py (:318) and test_udpfs_themes.py (:337). `.github/workflows/ps2build.yml:71` runs `tools/run_tests.sh -k`, which sweeps every `.github/scripts/test_*.py` — so the four batch files flavours.yml does not name (test_igr_polling.py, test_ratls_host.py, test_psbbn_flow.py, test_udpfs_files_oplcore.py) are still executed in CI. `tools/run_tests.sh` itself propagates failures (per-file FAIL count → `exit 1`).

## (a) Per-file ledger

| Path | Lines | Verdict |
|---|---|---|
| .github/scripts/test_ember_settings.py | 740 | finding (cross-file duplication candidate only) |
| .github/scripts/test_igr_polling.py | 719 | finding |
| .github/scripts/test_ps2build_sdk_watch.py | 596 | finding |
| .github/scripts/test_igr_menu_no_room.py | 572 | finding |
| .github/scripts/test_settings_back_keeps_edits.py | 546 | finding (cross-file duplication candidate only) |
| .github/scripts/test_install_ports.py | 477 | clean (compiler-absence skips at :405/:411 already covered by RIPTOPL-291; `cc`/`ar` are present on the ubuntu-24.04 CI image, so they do not trigger there — no new evidence on that axis) |
| .github/scripts/test_sio2man_hooks.py | 442 | finding (cross-file duplication candidate only) |
| .github/scripts/test_ratls_host.py | 429 | finding |
| .github/scripts/test_smb1_reply_resync.py | 425 | clean |
| .github/scripts/test_psbbn_flow.py | 420 | finding (cross-file duplication candidate only) |
| .github/scripts/test_ilink_manager_safety.py | 399 | finding (cross-file duplication candidate only) |
| .github/scripts/test_udpfs_files_oplcore.py | 392 | finding (cross-file duplication candidate only) |
| .github/scripts/test_menu_sort.py | 368 | finding (cross-file duplication candidate only) |
| .github/scripts/test_udpfs_themes.py | 275 | finding (cross-file duplication candidate only; this file is also the precedent that sharing is possible — it imports the shared `hostmap` module at :24-25) |

## (b) Candidate findings (unnumbered)

### Candidate 1 — The fork-filtering jq program in test_ps2build_sdk_watch.py is never executed when jq is absent, and the test reports as a skip/pass
- **Category:** 6 (bugs/security — the unexecuted code is the cross-repository PR filter)
- **Locations:** `RiptOPL/.github/scripts/test_ps2build_sdk_watch.py:582-583` (inside `test_the_pull_request_lookup_ignores_forks`, ~:575-596)
- **Problem:** READ. The test first string-matches the workflow's `gh pr list` lookup text, then — only if `shutil.which("jq")` finds a binary — actually runs the embedded jq program against fork/ours/empty PR lists and asserts it returns `"9"`, `""`, `""`. If jq is missing it calls `self.skipTest("jq is not installed")` mid-test, so the one set of assertions that executes the security-relevant filter (a fork PR from a same-named branch must not be taken for the watch's own proposal) never runs, while unittest reports the test as skipped and both CI runners (flavours.yml:32, run_tests.sh sweep) exit 0. Whether the GitHub ubuntu-24.04 image ships jq is INFERRED (it is present on this VM and is a standard runner tool, but no workflow line in this repo installs or proves it; the watch workflow itself uses `gh --jq`, which is gh's embedded jq, not the binary — ps2build-sdk-watch.yml:205). A runner-image change that dropped the jq binary would silently disarm exactly this check.
- **Fix in words:** Fail, don't skip, when jq is absent in CI — or vendor the three-case check so it does not depend on a host binary (e.g. assert the program's behaviour via the `gh --jq` path the workflow actually uses). Keep the string-match asserts as they are.
- **Justification if the fix adds anything:** Adds no production code; at most a hard failure in place of a skip.
- **Benefit:** The fork-PR confusion guard cannot silently stop being tested.
- **Effort:** S / **Risk:** Low / **Confidence:** High on the skip mechanism (READ), Med on CI-image jq presence (INFERRED).

### Candidate 2 — test_ratls_host.py only ever sends lowercase HTTP tokens, so the RIPTOPL-189 case-sensitive token defect passes the suite (cross-reference RIPTOPL-189; the production bug is not re-filed)
- **Category:** 6 (bugs/security — test encodes the defective behaviour's input space as the whole input space)
- **Locations:** `RiptOPL/.github/scripts/test_ratls_host.py:237` (download refusal fixture `Transfer-Encoding: chunked`), `:313-336` (all chunked GET fixtures), `:238` (`Content-Encoding: gzip` refusal fixture); production defect at `src/platform/ratls.c:159,171,430` per RIPTOPL-189 (Round 5 report, READ).
- **Problem:** READ. Every chunked fixture in the file uses the exact lowercase value `chunked`, and the only content-encoding fixture uses `gzip` (a value that must be refused either way). No fixture sends `Chunked`, `CHUNKED`, or `Content-Encoding: Identity`. RIPTOPL-189 already established that ratls compares these token values case-sensitively while HTTP tokens are case-insensitive, so a conformant server emitting `Chunked` is mis-framed by `raTlsRequest` — and this suite, the only host test for ratls.c, cannot catch it because its fixtures mirror the implementation's assumption.
- **Fix in words:** Add capitalised-token cases to the existing fixtures: a `Transfer-Encoding: Chunked` GET that must return the same de-chunked body as the lowercase case, and a download with `Content-Encoding: Identity` that must be accepted. (These cases will fail until RIPTOPL-189 is fixed — that is the point; land them with the fix.)
- **Justification if the fix adds anything:** Adds test cases only, reusing the existing Server/check harness.
- **Benefit:** The ratls host suite covers the token-casing input space the standard allows, closing the test-side hole that let RIPTOPL-189 ship.
- **Effort:** S / **Risk:** Low / **Confidence:** High (fixtures and RIPTOPL-189 both READ).

### Candidate 3 — Function-extraction and compile-and-run helpers are re-implemented in at least eleven batch files, with divergent failure semantics
- **Category:** 2 (duplication)
- **Locations:** Extraction helpers — `RiptOPL/.github/scripts/test_ember_settings.py:23` (`function_text`), `test_settings_back_keeps_edits.py:39` (`function_text`), `test_igr_polling.py:26` (`function_text`), `test_menu_sort.py:24` (`function_text`), `test_udpfs_files_oplcore.py:30` (`function`), `test_psbbn_flow.py:25` (`function`), `test_ilink_manager_safety.py:15` (`function`), `test_sio2man_hooks.py:19` (`extract_function`), `test_udpfs_themes.py:33` (`function_body`). Compile/run helpers — `test_ember_settings.py:50` (`compile_and_run`), `test_settings_back_keeps_edits.py:48` (`compile_and_run`), `test_igr_polling.py:688` (`build_and_run`), `test_igr_menu_no_room.py:523` (`build_and_run`), `test_psbbn_flow.py:30` (`run`), plus inline re-implementations in test_smb1_reply_resync.py, test_sio2man_hooks.py (`run_host_harness`), test_udpfs_files_oplcore.py and test_udpfs_themes.py.
- **Problem:** READ. Each file hand-rolls the same two operations — cut a function out of production source by signature, and compile+run a host harness collecting failures — but with different failure behaviour: some append to a failures list (ember/settings/menu_sort), some raise (psbbn/ilink `source.index`/`assert`), some brace-count (sio2man), some exit via `check=True` (psbbn/sio2man). A fix to the extraction logic (e.g. nested-brace or prototype handling) must currently be made eleven times, and the divergent semantics mean the same production rename fails loudly in one file and via a compile error in another. Sharing is demonstrably possible in this corpus: test_udpfs_themes.py:24-25 already imports the shared sibling module `hostmap` (`.github/scripts/hostmap.py`, verified present at the pin).
- **Fix in words:** Extract one shared helper module in .github/scripts (extraction + compile/run with the failures-list semantics) and have the batch files import it the way test_udpfs_themes.py imports hostmap; delete the per-file copies. Preserve each file's standalone runnability under both flavours.yml's per-file invocations and run_tests.sh.
- **Justification if the fix adds anything:** The shared module is smaller than the sum of the copies it replaces; net deletion.
- **Benefit:** One extraction/compile implementation to fix and audit; uniform fail-loud behaviour across the corpus.
- **Effort:** M / **Risk:** Med (touching many green tests; each file must be re-run after conversion) / **Confidence:** High (all definitions READ).

### Candidate 4 — Install_IGR / IGR_RequestReset installation behaviour is asserted twice, in test_igr_polling.py and test_igr_menu_no_room.py, against two different stub universes
- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/.github/scripts/test_igr_polling.py` MODE6_CHECKS (~:640-670) and RESET_CHECKS (~:105-140) plus the Install_IGR retry sequence in the harness main (~:400-440); `RiptOPL/.github/scripts/test_igr_menu_no_room.py` GATE_HARNESS Install_IGR tail checks (~:480-515 of the file).
- **Problem:** READ (overlap), INFERRED (drift risk). Both files compile padhook.c's Install_IGR and IGR_RequestReset and assert the same installation contract from different angles: a first install starts worker+handler with no pending request/PC mark, a pad reopen with the worker alive creates no second worker and keeps a pending request. The assertions are not textually identical — igr_polling stresses create/start failure retry, igr_menu_no_room stresses the PC-mark lifetime — but the shared core (install idempotence, request clearing on first install, preservation on reopen) is maintained in two harnesses with unrelated kernel stubs, so a deliberate change to Install_IGR semantics must be mirrored by hand in both.
- **Fix in words:** Keep the file-specific angles (retry in igr_polling, PC-mark/menu gate in igr_menu_no_room) but state the shared installation contract in only one of them and cross-reference it from the other, deleting the duplicated assertions.
- **Justification if the fix adds anything:** Adds nothing; deletes duplicated assertions.
- **Benefit:** One place to update when Install_IGR's contract changes; less chance the two files encode divergent contracts.
- **Effort:** S / **Risk:** Low / **Confidence:** Med (both harnesses READ; the boundary of what counts as "the same" assertion is a judgement call).

## (c) Dissolved candidates

- **skipUnless(bash) tests in test_ps2build_sdk_watch.py:434 and :503** — bash is always present on the ubuntu-24.04 CI image (and the workflows themselves run bash steps), so the condition is never true in CI; the tests do run. Dissolved (READ workflow + file).
- **Compiler-absence handling in test_smb1_reply_resync.py (`sys.exit('no C compiler')`)** — `sys.exit(str)` exits with code 1, which run_tests.sh and flavours both count as FAIL, not as a pass. Fail-loud, not a skip. Dissolved (READ).
- **test_ratls_host.py:38 module-level `assert CC and OPENSSL`** — a missing compiler/openssl raises at import and fails the file in the run_tests.sh sweep; it does not silently pass. (The file is not in flavours.yml, but ps2build.yml:71's sweep covers it.) Dissolved (READ).
- **Brace-count harness guards** (`test_ember_settings.py` `count('{') >= 3` gates, `test_settings_back_keeps_edits.py` `>= 3` / `>= 2` gates) — every guarded extraction goes through `function_text`, which appends a failure when a signature is not found, and each found function contributes at least its opening brace; a missing function therefore fails the file even when its harness is skipped. Redundant but not a cannot-fail path. Dissolved (READ).
- **Four batch files absent from flavours.yml** (test_igr_polling.py, test_ratls_host.py, test_psbbn_flow.py, test_udpfs_files_oplcore.py) — not a coverage gap: ps2build.yml:71 runs `tools/run_tests.sh -k`, which sweeps all `test_*.py` and exits 1 on any failure. Dissolved (READ).
- **test_igr_menu_no_room.py's Open-PS2-Loader LAYOUT branch (:36-42)** — dead in this clone, but the docstring (:3-4) states the script is shared with Open-PS2-Loader and selects its tree by file presence; intentional portability, not dead code to delete here. Dissolved (READ).
- **test_install_ports.py SymtabRepairTests skips (:405, :411)** — already filed as RIPTOPL-291; on the CI image cc/ar exist and produce ELF, so no new evidence extends it. Marked clean on that axis per instructions.
- **test_menu_sort.py's inline reference sort duplicating the comparison logic** — it is the deliberate pre-change oracle (docstring: the removed bubble sort kept as reference); making it call the production compare would destroy the test's purpose. Dissolved (READ).
- **test_ilink_manager_safety.py running the same five programs against both iLinkman copies** — the two production copies exist in the tree (modules/ilink and modules/bdmassault, verified) and per-copy verification is the test's stated purpose. Dissolved (READ).
- **test_ratls_host.py `get()`/`download()` not checking the host_main subprocess return code** — a crash yields no `rc=` line, so the regex `.group(1)` raises and the file fails loudly; a printed `rc=` is only emitted at the end of a completed operation. Dissolved (READ).
