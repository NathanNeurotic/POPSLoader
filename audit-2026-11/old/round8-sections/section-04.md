# Round 8 — Section 04: RiptOPL test corpus, batch 04

- Repo: NathanNeurotic/RiptOPL, clone `~/workspace/audit-clones-2026-11-13/RiptOPL`, pin `2e347d5ac885cd0ff73e9ad4143781946396f492` (verified; `git status` clean before and after).
- Batch: 12 files, 6,799 lines total (batch file says ~6,800; `wc -l` sum is exactly 6,799). Every file line-read in full, in batch order (largest first).
- Workflow context read in full: `.github/workflows/flavours.yml`, `.github/workflows/ps2build.yml`, `tools/run_tests.sh`.
- Cross-batch note: `.github/scripts/test_vmc_rebuild.py` also appears in `batch-05.txt`; it is counted once here.

## (a) Per-file ledger

| Path | Lines | Verdict |
|---|---|---|
| .github/scripts/test_release_publication.py | 722 | finding |
| .github/scripts/test_smb2_logon_parity.py | 702 | finding |
| .github/scripts/test_smb_vmc_io_result.py | 702 | clean |
| .github/scripts/test_vmc_rebuild.py | 604 | finding |
| .github/scripts/test_ra_ps1.py | 593 | clean |
| .github/scripts/test_save_icons.py | 575 | finding |
| .github/scripts/test_bgm_source.py | 569 | clean |
| .github/scripts/test_bdm_scan_retry.py | 562 | finding |
| .github/scripts/test_apa_table_safety.py | 552 | finding |
| .github/scripts/test_ripps2_backend_port.py | 551 | finding |
| .github/scripts/test_vmc_write_result.py | 512 | clean |
| .github/scripts/test_igr_pad_lifetime.py | 155 | clean |

Notes on the clean files (READ): `test_smb_vmc_io_result.py` checks every harness build/run return code (`run()`, :647-657) and compares full expected-output vectors; `test_ra_ps1.py` runs every harness with `check=True` and cross-checks C MD5 output against independent `hashlib` expectations; `test_vmc_write_result.py` aggregates `FAILURES` from build/run results and exits 1 (:499-512); `test_igr_pad_lifetime.py` uses `check=True` for both sanitizer builds and runs, with no alternate-source argument passed by CI (flavours.yml:35). No batch file repeats the RIPTOPL-286…291 mechanisms; on the RIPTOPL-291 axis specifically, every compiler-using file in this batch fails (sys.exit / failures list / `check=True`) rather than skipping when a compiler or build fails.

## (b) Candidate findings (unnumbered)

### 1. APA raw-namespace scan never sees a C++ source — the policy it pins is unenforced where the code lives
- **Category:** 6 (bugs/security)
- **Locations:**
  - `.github/scripts/test_apa_table_safety.py:518-537` (`RAW_APA_LITERAL` :522, `RAW_APA_ALLOWED` :523, `check_raw_apa_namespace()` :526-537, the `rglob('*.[ch]')` at :528, the `fileXioFormat` check at :536-537)
  - Evidence in production sources at the pin: `src/app/autolaunch.cpp:91` (`"hdd0:%s"`), `src/app/settingsio.cpp:450` (`"hdd0:__common"`) — non-allowed `.cpp` files spelling the literal the scan claims to police
- **Problem (READ):** The scan's own comment (:518-521) states only three files may spell the raw `hdd0:`/`hdd1:` APA namespace. But `Path.rglob('*.[ch]')` matches only names ending in a single `.c` or `.h`. Verified by running it at the pin: it matches 5 files under `src`, 21 under `ee_core/src`, 138 under `include`, and **zero `.cpp` files anywhere** — while the scanned tree holds 115 `.cpp` files (vs 26 `.c`). Three consequences: (1) a new or existing `.cpp` file spelling `"hdd0:…"` is never checked — non-allowed `.cpp` spellings already exist (cited above); (2) `RAW_APA_ALLOWED` is itself three `.cpp` paths, so the allowlist is never actually consulted for the files it names; (3) the `fileXioFormat(` ban in the same loop inherits the same blind spot. The check passes today and would pass with a raw-APA regression in any C++ file.
- **Fix in words:** Widen the scan to the suffixes the tree actually uses (`.c`, `.h`, `.cpp`, `.hpp`), then reconcile `RAW_APA_ALLOWED` with the legitimate `.cpp` spellings that surfaces (partition-name comparisons and mount sources), so the rule that remains is the intended one — no partition creation/deletion or format via the raw namespace outside its owners.
- **Justification if the fix adds anything:** Test-only change; the allowlist may grow entries. That is justified because the alternative is a security-policy check that is vacuous for the tree's main language.
- **Benefit:** The APA-namespace policy becomes enforced where new code is actually written; a future raw-APA regression in C++ turns CI red instead of passing silently.
- **Effort:** M (the glob fix is S; the allowlist reconciliation it forces is the real work)
- **Risk:** Med — a naïve glob widening turns CI red on existing spellings until the allowlist/rule is reconciled; that reconciliation needs a human decision on which spellings are legitimate.
- **Confidence:** High (READ — glob behaviour executed at the pin; counts and example spellings are from tool output)

### 2. Release-publication test ends with a self-referential assertion — the "remote unchanged" check cannot fail on values
- **Category:** 6 (bugs/security)
- **Locations:** `.github/scripts/test_release_publication.py:440-468` (`test_backup_without_recorded_digest_aborts_before_any_upload`; the final assertion is :468). Correct sibling form: `:335` (`test_torn_backup_aborts_before_any_upload`, comparing against an independently captured `original`)
- **Problem (READ):** Line 468 is `self.assertEqual(remote, {"stable.ELF": remote["stable.ELF"]})` — the expected value is read out of the dict being checked, so the value comparison is tautological; only a change in the key set can fail it. The test's stated promise is that a backup without a recorded digest aborts with the release untouched. The two preceding assertions (:466-467, no upload / no delete-asset call) do real work, but if `upload_verified` mutated the stored asset entry in place (size/digest) without an upload or delete call, this test would still pass. The sibling test at :335 captures `original` before the call and compares against it — :468 looks like that assertion copy-adapted incorrectly. This extends/revises round 7's corpus-level statement that no self-comparisons were found: that was a mechanism scan, and this instance is a dict-literal self-reference rather than a literal `x == x` pattern.
- **Fix in words:** Capture the expected remote dict before invoking `upload_verified` (as :335 does) and assert equality against that snapshot.
- **Justification if the fix adds anything:** Adds nothing; it replaces one assertion with the sibling test's existing pattern.
- **Benefit:** The fail-closed backup-verification test actually verifies the remote asset's contents are unchanged, not just its key set.
- **Effort:** S
- **Risk:** Low
- **Confidence:** High (READ)

### 3. Save-icons harness exit code is discarded — a post-print crash or non-zero exit passes
- **Category:** 6 (bugs/security)
- **Locations:** `.github/scripts/test_save_icons.py:357-359` (`run()` returns only `.stdout.strip()` from a `check=False` subprocess call); harness `main` returns 0 on every intended path (HARNESS string, `:343`), including the `ERR`/`NONE` outcomes
- **Problem (READ mechanism, INFERRED scenario):** Every other harness-running file in this batch checks the child return code; this one never reads it. Most call sites are compensated by exact stdout comparison, so a crash before printing still fails. The residual gap is a failure *after* the expected line is printed — e.g. a crash in `saveIconFreeModel`/`fclose` after `printf` in the harness's `model`/`card` modes, or any non-zero exit with correct stdout — which reports as a pass. Since the harness exits 0 on all intended paths (errors are reported in-band as `ERR`/`NONE`), checking the return code is strictly stronger at no cost.
- **Fix in words:** Make `run()` treat a non-zero harness return code as a test failure (append to `failures`), the way `test_smb_vmc_io_result.py`'s `run()` does.
- **Justification if the fix adds anything:** Adds nothing; one existing result field gets read.
- **Benefit:** Crashes in model/card cleanup stop masquerading as passes; the file matches the batch's own exit-code discipline.
- **Effort:** S
- **Risk:** Low
- **Confidence:** Med (mechanism READ; no actual post-print crash was observed — the masking scenario is INFERRED)

### 4. Two suites have Python sections gated only by bare `assert` — they vanish, with their "ok" prints intact, under `python3 -O` / `PYTHONOPTIMIZE`
- **Category:** 6 (bugs/security)
- **Locations:**
  - `.github/scripts/test_ripps2_backend_port.py:155-176` (asserts at :155, :161, :166, :168, :174; unconditional `ok` prints at :162, :171, :176) and `:539-551` (asserts at :539, :540, :543, :549)
  - `.github/scripts/test_vmc_rebuild.py:594-604` (dialog-wiring asserts at :600-603)
  - Invocations: `.github/workflows/flavours.yml:65-68` and `tools/run_tests.sh:7-11` — neither passes `-O` nor sets `PYTHONOPTIMIZE` (grep over all workflows and `run_tests.sh` returns nothing; READ)
- **Problem (READ):** Nine Python `Assert` nodes in `test_ripps2_backend_port.py` are the *only* enforcement for the reset-hook calls, the FreeType registration/absence checks, the MMCE send-wait check, the launch-ordering checks, and the `fntNewLibrary` ordering check; the four asserts at `test_vmc_rebuild.py:600-603` are the only enforcement of the rebuild dialog wiring. Everything else in both files is fail-closed (`check=True` subprocesses, `str.index` raising). Today CI does not set the flag, so the checks run — this is latent, not current vacuity, and it is a different mechanism from RIPTOPL-291 (compiler absence in three other, named files). If either runner is ever invoked with optimisation on, those sections execute nothing and still print their `ok …` lines.
- **Fix in words:** Convert those Python-level asserts to the failures-list / explicit-raise pattern the sibling suites in this batch already use (`test_bgm_source.py`, `test_apa_table_safety.py`), keeping the same checks.
- **Justification if the fix adds anything:** Adds nothing; the assertions are replaced one-for-one with equivalent explicit checks.
- **Benefit:** These suites' pass/fail stops depending on an interpreter flag no workflow documents or pins.
- **Effort:** S
- **Risk:** Low
- **Confidence:** High on the mechanism (READ — assert inventory taken by AST, invocations grepped); INFERRED on likelihood (no current CI path sets the flag)

### 5. Dead test helpers: `strip_comments` and `function_body` in the SMB2 logon parity suite are defined and never called
- **Category:** 1 (dead code)
- **Locations:** `.github/scripts/test_smb2_logon_parity.py:62-95` (`strip_comments` :62-87, `function_body` :90-95)
- **Problem (READ):** Each name occurs exactly once in the file — its definition (verified by AST/name count). Nothing in the file calls them, and no other file imports them (the suite is a standalone script; same-named helpers in other test files are independent copies, e.g. `test_smb_launch_name.py:38`). They are leftovers of a source-scraping approach the suite no longer uses — it now compiles and runs both real clients against a fake server. 34 lines of unexecuted C-comment-stripping logic sit in the header of a 702-line suite, where a reader reasonably assumes they participate in the checks.
- **Fix in words:** Delete both functions.
- **Justification if the fix adds anything:** Adds nothing; pure deletion.
- **Benefit:** Less code to read and keep compiling in a suite whose value is its live protocol checks; removes a misleading impression that source text is being inspected.
- **Effort:** S
- **Risk:** Low
- **Confidence:** High (READ)

### 6. The nine-name BDM latch list is written twice in one file, so the text check and the executable check can drift apart
- **Category:** 2 (duplication)
- **Locations:** `.github/scripts/test_ripps2_backend_port.py:159-161` (latch tuple in the source-text loop) and `:178-179` (the same tuple re-declared as `latches` for the compiled reset harness)
- **Problem (READ):** The same nine latch names (`iUSBModLoaded` … `udpbdNicClaimed`) are enumerated twice, a few lines apart, for two halves of one check: "each latch is named in `bdmIopWasReset`" (text) and "each latch is actually cleared when it runs" (compiled). If a tenth latch is added to only the first list, the text half covers it and the executable half silently does not — the stronger check is exactly the one that would be skipped.
- **Fix in words:** Declare the tuple once, above both uses, and have both loops consume it.
- **Justification if the fix adds anything:** Adds nothing; one declaration replaces two.
- **Benefit:** The executable reset coverage can no longer silently lag the textual coverage when the latch set grows.
- **Effort:** S
- **Risk:** Low
- **Confidence:** High (READ)

### 7. `test_bdm_scan_retry.py` runs twice in one workflow (and a third time in the other CI workflow)
- **Category:** 7 (build/CI/repo clutter)
- **Locations:** `.github/workflows/flavours.yml:57` (migration-parity-host-tests job) and `.github/workflows/flavours.yml:310` (bdm-host-tests job); third execution via `.github/workflows/ps2build.yml:70-71` running `tools/run_tests.sh -k`, whose glob (`tools/run_tests.sh:7`) includes the file
- **Problem (READ):** `test_bdm_scan_retry.py` is the only test file appearing twice in `flavours.yml` (verified by counting every `test_*.py` mention in the file: it is the sole count of 2). Both flavours jobs trigger on the same events, so every PR and `rebuild/main` push compiles and runs its two C++ harnesses twice within one workflow, plus once more in ps2build. The duplication buys nothing: the bdm-host-tests job is the suite's themed home and already runs it alongside the other BDM suites.
- **Fix in words:** Remove the line from the migration-parity list at flavours.yml:57, keeping the bdm-host-tests entry at :310.
- **Justification if the fix adds anything:** Adds nothing; one line removed, coverage unchanged (two executions remain across the two workflows).
- **Benefit:** One full compile-and-run of a 562-line suite saved per flavours run, and one less place to keep in sync when the suite moves.
- **Effort:** S
- **Risk:** Low
- **Confidence:** High (READ)

## (c) Dissolved candidates

- **Four batch files missing from flavours.yml are unrun** — dissolved: `test_smb_vmc_io_result.py`, `test_vmc_rebuild.py`, `test_ra_ps1.py` and `test_save_icons.py` have no flavours.yml entry, but ps2build.yml:70-71 runs `tools/run_tests.sh -k`, which globs all `.github/scripts/test_*.py` (run_tests.sh:7) and exits 1 if any fail (run_tests.sh:11). They run, in the SDK job.
- **SMB2 parity clients' exit code (`rc`) is recorded but never asserted** — dissolved: compensated in-band; `common_checks` rejects sanitizer/runtime-error text in client output (:546-556), and the NT-presence, `session setup 1` and `connect 0` output checks fail any run whose client died early.
- **`test_bgm_source.py` failure messages and docstring name `src/core/sound.c`, which does not exist** — dissolved as cosmetic only: the extraction correctly reads `src/core/bgm.cpp` (:47); the stale label misdirects a human reading a failure but weakens no check. Not filed.
- **Conditional assertions in `test_release_publication.py`'s notes test (tag/RA branches, :55-68)** — dissolved: the branches are data-driven over `publisher.EDITIONS` and each fires for at least one edition at the pin; they are not false in CI.
- **`smb_WriteAndX` CountHigh-ignored expectation (`test_smb_vmc_io_result.py`, `count-high-ignored`) encodes a bug** — dissolved: per-chunk requests are ≤ 65,535 bytes, so a compliant server's CountHigh is 0, and no prior finding (RIPTOPL-001…295) identifies the production handling as a defect.
- **`test_vmc_write_result.py`'s `export_ordinals` #ifdef-stack parser mishandles conditionals** — dissolved at the pin: the `oplutils` table block in `modules/iopcore/cdvdman/exports.tab` contains only `#ifdef`/`#endif` pairs — no `#else` or `#if defined(...)` — so the parser computes the asserted ordinals correctly.
- **`test_smb_vmc_io_result.py`'s SIGNAL-predecessor source scan can be bypassed via its `index-1` edge** — dissolved at the pin: no waiter function returns as its first post-WAIT statement, and every return in the extracted bodies at the pin is preceded by `SIGNALIOSEMA(smb_io_sema);`.
- **Fixture `assert`s inside `test_save_icons.py`'s `Card` builder are swallowed** — dissolved: an `AssertionError` there propagates out of the script and exits non-zero; fail-closed.
