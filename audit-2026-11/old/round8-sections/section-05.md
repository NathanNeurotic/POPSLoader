# Round 8 — Section 05: RiptOPL test corpus, batch 05

- Repo: NathanNeurotic/RiptOPL, pin `2e347d5ac885` (verified, not updated). Clone `~/workspace/audit-clones-2026-11-13/RiptOPL`. Read-only; `git status` clean before and after.
- Batch: `round8-sections/batch-05.txt` — 16 files, 6,800 lines, every file line-read in full in batch order (largest first).
- Verification (READ/executed): all 16 files were also run at the pin in this VM; all exit 0. Every candidate below is therefore a *latent* defect — a check that passes today but would not catch the regression it names — not a currently-failing test. No candidate re-files a production bug; where a prior finding is relevant it is cross-referenced only.
- CI context (READ): files in this batch not named individually in `.github/workflows/flavours.yml` are still run by `tools/run_tests.sh` (the `for t in .github/scripts/test_*.py` loop), invoked at `.github/workflows/ps2build.yml:71`. Absence from `flavours.yml` alone is not a dead test for any file in this batch.

## (a) Per-file ledger

| Path | Lines | Verdict |
|---|---|---|
| .github/scripts/test_ra_xerabora_browser.py | 469 | clean |
| .github/scripts/test_ripps2_vmc_saves.py | 466 | clean |
| .github/scripts/test_dialog_gui_lock.py | 463 | finding — candidate 4 |
| .github/scripts/test_ps1_retrogem_metadata.py | 454 | finding — candidate 1 |
| .github/scripts/test_zso_read_errors.py | 454 | clean |
| .github/scripts/test_pad_mode_lock.py | 450 | finding — candidate 2 |
| .github/scripts/test_autolaunch_settings.py | 448 | clean |
| .github/scripts/test_igr_vmc_drain.py | 429 | clean |
| .github/scripts/test_pad_missed_read.py | 413 | finding — candidate 2 |
| .github/scripts/test_ripps2_all_games.py | 407 | clean |
| .github/scripts/test_ra_disc.py | 404 | clean |
| .github/scripts/test_ps2build_configurations.py | 398 | clean |
| .github/scripts/test_mc_folders.py | 397 | clean |
| .github/scripts/test_vmc_rebuild_fatfs.py | 397 | clean |
| .github/scripts/test_smbman_ra_write_count.py | 381 | clean |
| .github/scripts/test_usbd_pad_pool.py | 370 | finding — candidate 3 |

Notes on clean files, briefly: `test_ra_xerabora_browser.py` and `test_zso_read_errors.py` compile real production functions and propagate every subprocess result (`check=True`, or `failed |= returncode != 0` at test_zso_read_errors.py's runner). `test_ripps2_vmc_saves.py` checks card writes against an independent in-test format reader, including an independently written PSU reader/writer — clean on the RIPTOPL-286 axis (see dissolved list). `test_autolaunch_settings.py`, `test_igr_vmc_drain.py`, `test_ripps2_all_games.py`, `test_ra_disc.py`, `test_ps2build_configurations.py`, `test_vmc_rebuild_fatfs.py` and `test_smbman_ra_write_count.py` all fail loud on missing production symbols (exception / `sys.exit` / unittest failure) and check subprocess exit codes. `test_mc_folders.py` is clean for the reason given in the dissolved list.

## (b) Candidate findings

### Candidate 1 — The RetroGEM art harness tests its own re-implementation of the image cache, not the production one

- **Title:** PS1 id-keyed art scenarios run against a simplified in-harness model of `ImageCache` and `cacheGetTextureEx`; the production methods in `artload.cpp` are never executed
- **Category:** 6 (bugs/security — a test that cannot catch the bug class it names)
- **Locations:**
  - `.github/scripts/test_ps1_retrogem_metadata.py:176-282` (ART_HARNESS: harness-defined `image_cache_t` at :192-231, harness `cacheAbsenceIsCurrent` at :232, harness `cacheGetTextureEx` at :235-281, described in its own comment as "texcache.cpp's contract")
  - `.github/scripts/test_ps1_retrogem_metadata.py:335` (the only production art code inserted is `cacheGetTextureIdOrName` from `src/gfx/texcache.cpp`, via `@ART@`)
  - `.github/scripts/test_ps1_retrogem_metadata.py:344` (the only direct check of `artload.cpp` is a string check for `slotKeyedOther`)
  - Production code not executed: `src/gfx/artload.cpp:215-217` (`slotKeyedOther`), `:220-227` (`holdsFallback`), `:229-233` (`markFallback`), `:235-252` (`residentByValue`), `:253-295` (`adoptFallback`); `src/gfx/texcache.cpp:226` (`cacheGetTextureEx`)
- **Problem (READ):** The harness copies diverge from production in exactly the details the scenarios claim to test. Production `adoptFallback` skips entries with `UID == 0` (`artload.cpp:267`), refuses a parked-absent entry whose `failEpoch != gArtW.failEpoch` (`artload.cpp:273`), distinguishes loading/resident/free by `qr`/`lastUsed`/`texture.Mem`, and refreshes `lastUsed`; the harness version (`test_ps1_retrogem_metadata.py:210-231`) uses a 4-state enum and parks any ABSENT fallback to `CACHE_ID_PS1_BOTH_ABSENT` unconditionally. Production `residentByValue` requires `qr == NULL && lastUsed != 0 && texture.Mem != NULL` (`artload.cpp:235-252`); the harness version returns any READY slot (`:203-209`). Production `slotKeyedOther` also guards `strlen(value) < sizeof(content_[i].key)` (`artload.cpp:217`); the harness version (`:193`) omits it. The harness `cacheGetTextureEx` has no eviction at all — it claims the first FREE slot and asserts `"cache exhausted"` if none (`:235-281`) — so the scenarios about parked memos being evicted on a full cache (`test_ps1_retrogem_metadata.py:300-321`) simulate eviction by manually `memset`-ing ABSENT slots in the test driver, not by any production eviction path. A regression in production `adoptFallback`, `residentByValue`, `holdsFallback`, `markFallback` or `cacheGetTextureEx` — the flicker/re-read defects the file's comments describe — passes this test unchanged. A repo-wide grep (READ) confirms no other test file mentions `adoptFallback`/`residentByValue`, so no other suite covers them either.
- **Fix in words:** Make the art harness execute the production code it now models: extract the five `ImageCache` methods from `src/gfx/artload.cpp` and `cacheGetTextureEx` from `src/gfx/texcache.cpp` into the harness (stubbing only the art queue, frame id and fail-epoch globals they read), and delete the harness re-implementations. Keep the existing scenarios, including the manual-eviction ones only if they are re-expressed through the real claim/evict path.
- **Justification if the fix adds anything:** It adds extraction/stub wiring, but removes ~90 lines of parallel model code; net test code should shrink, and the one remaining copy is the production one.
- **Benefit:** The id-vs-name fallback, parked-absence and eviction behaviour is verified against the code that ships; a divergence between model and production becomes impossible.
- **Effort:** M
- **Risk:** Med — harness surgery around `ImageCache`'s queue/epoch globals; the scenarios themselves are unchanged, which bounds the risk.
- **Confidence:** High (READ — harness and production texts compared line by line at the pin)

### Candidate 2 — The two pad tests duplicate one harness for the same production file

- **Title:** `test_pad_mode_lock.py` and `test_pad_missed_read.py` each carry a full copy of the pad extraction, libpad stub and simulated-pad scaffolding
- **Category:** 2 (duplication)
- **Locations:**
  - `.github/scripts/test_pad_mode_lock.py:40-47` (--ref handling), `:55-63` (`function_text`), `:65-91` (keyToPad/constants extraction and the identical 15-function + 3 optional lock-function extraction list), `:92-143` (LIBPAD stub), and the harness preamble/reset/frame scaffolding in its HARNESS block
  - `.github/scripts/test_pad_missed_read.py:40-47`, `:55-63`, `:65-91`, `:93-141` (the same pieces, in the same order)
- **Problem (READ):** Measured at the pin, the two files share 187 distinct identical lines. Both extract the same functions from the same production file (`src/core/pad.cpp`), against near-identical simulated-freepad stubs, with the same `PadManager` construction, tick and frame helpers; only the simulated pad behaviour and the scenario `main()` differ. Any change to `pad.cpp`'s function signatures, the `keyToPad` table, the libpad ABI stub or the --ref mechanism must be made twice, and the copies have already drifted in small ways (e.g. the LIBPAD stubs differ in the `PAD_MMODE_*` defines each carries). This is the batch's instance of the wider pattern — 11 of the 16 files in this batch define their own `function`/`function_text` extractor — but the pad pair is the concrete, same-subject duplication. A shared-module precedent already exists in the same directory: `hostmap.py`, imported by other tests in this batch.
- **Fix in words:** Extract the shared pad-test scaffolding (source reading/--ref, `function_text`, table/constants extraction, LIBPAD stub, harness preamble and frame helpers) into one helper module beside `hostmap.py`; leave each test with only its simulated-pad behaviour and its scenarios.
- **Justification if the fix adds anything:** One new small module, justified by deleting the second copy of ~190 lines; no new mechanism, the helper is the code both files already run.
- **Benefit:** One place to update when `pad.cpp` or the libpad stub changes; the two suites cannot silently drift into testing different extraction lists.
- **Effort:** M
- **Risk:** Low — both suites are host-only and deterministic; the scenarios and expectations are untouched.
- **Confidence:** High (READ — line-level comparison of the two files at the pin)

### Candidate 3 — Extends RIPTOPL-291: the raudp half of the USBD/lwIP test silently vanishes if the file moves

- **Title:** `test_usbd_pad_pool.py` guards its raudp MTU checks with an existence test, so a deleted/renamed `raudp.c` reports as a pass
- **Category:** 8 (half-finished/redundant features — conditional vacuous pass; new evidence extending the RIPTOPL-291 class to a fourth file and a different mechanism: file existence, not compiler absence)
- **Locations:**
  - `.github/scripts/test_usbd_pad_pool.py:90-98` (`if os.path.exists(raudp):` wrapping the `RA_PAYLOAD` + header vs MTU check at :92-94 and, nested inside it, the discovery-buffer check behind `if 'lwip_sendto' in src:` at :95-98)
  - Contrast in the same file: `.github/scripts/test_usbd_pad_pool.py:59-68` (`one()` calls `sys.exit` when a pattern does not match exactly once — the file's own fail-loud pattern for everything else)
- **Problem (READ):** `modules/network/raudp/raudp.c` exists at the pin, so the checks run today (verified by executing the test). But if the file is renamed, moved or deleted — precisely the event the check exists to catch the consequences of — the whole raudp section is skipped with no failure, no skip message, and the test still prints its final `OK: ... USBD pad pool parsed...` line. The nested `'lwip_sendto' in src` condition has the same shape for the discovery-buffer check: if raudp stops calling `lwip_sendto` under that name, that check drops out silently instead of failing on the missing pattern via `one()`.
- **Fix in words:** Drop the existence guard and read `raudp.c` unconditionally (a missing file then fails the test like any other missing production file in this corpus); drop the `'lwip_sendto'` pre-condition and let the existing `one()` extraction fail loud if the discovery buffer is gone.
- **Justification if the fix adds anything:** Nothing added; two conditions removed.
- **Benefit:** The RAUDP-vs-MTU invariant is actually enforced for the file's whole lifetime, not only while its path and an internal call name stay unchanged.
- **Effort:** S
- **Risk:** Low
- **Confidence:** High (READ — guard and fail-loud contrast are both in the cited lines; file presence at the pin verified)

### Candidate 4 — The dialog frame-lock scan carries lock state across function boundaries

- **Title:** `check_frames` in `test_dialog_gui_lock.py` scans each dialog file as one linear stream, so an unbalanced lock in one function can mask a missing lock in a later one
- **Category:** 6 (bugs/security — a test that can miss the defect it names)
- **Locations:**
  - `.github/scripts/test_dialog_gui_lock.py:143-166` (`check_frames`: `locked`/`frame` are two locals initialised once per file, updated by a single `CALL.finditer(src)` pass over the whole file, and only checked for balance at end-of-file, :165-166)
  - The per-function machinery the fix needs already exists in the same file: `function_body` at `.github/scripts/test_dialog_gui_lock.py:64-79`, used by the keyboard/deferred/swap checks
- **Problem (READ for the mechanism, INFERRED for the masking scenario):** The check's stated rule (file docstring, check 1) is per dialog loop: every `rmStartFrame()` preceded by `guiLock()`, `guiUnlock()` only after the matching `rmEndFrame()`. The implementation does not scope that rule to a function or a loop. Lock state left over from one function — e.g. a `guiLock()` whose `guiUnlock()` was deleted — remains set while the scan enters the next function, so that function's `rmStartFrame()` is judged "locked" by the previous function's lock, and a later function's own `guiUnlock()` clears the stale state without any failure being recorded; the end-of-file balance check only fires if the *file's* totals are unbalanced. The scan also runs on the raw file text, unlike the same file's other checks, which strip comments / blank literals before scanning (e.g. the caller scan in `check_keyboard`), so a call named in a comment would move the state machine.
- **Fix in words:** Run the same state machine per function body (using the file's existing `function_body`/`functions` helpers) on comment-stripped text, and require lock/frame balance at each function's end as well as the file's.
- **Justification if the fix adds anything:** Nothing new is added; it reuses helpers the file already defines for its other checks and deletes no scenario.
- **Benefit:** A missing `guiUnlock()` or a missing `guiLock()` is attributed to the function that lost it, and cannot be cancelled out by an unrelated function elsewhere in the file.
- **Effort:** S
- **Risk:** Low — the current sources pass the stricter scoping only if each dialog function is in fact self-balanced, which is the invariant the file's docstring already claims.
- **Confidence:** Med (mechanism READ from the cited lines; the concrete masking sequence is INFERRED — no masking instance exists at the pin, where the test passes)

## (c) Dissolved candidates

- **C/C++ layout fallbacks are skip-to-pass** (`test_dialog_gui_lock.py:50` `CPP = (root/'src/ui/dia.cpp').exists()`, `test_ripps2_vmc_saves.py:29,454` `src/vmcsaves.c` vs `src/core/vmcsaves.cpp`, `src/guigame.c` vs `src/ui/guigame.cpp`) — dissolved: if neither layout exists, `read_text` raises and the test exits non-zero; the fallback selects a layout, it does not skip a check.
- **`test_mc_folders.py:283` ignores the harness exit code (`check=False`)** — dissolved as a standalone finding: the harness `main` returns 0 by construction, and every line family it prints is asserted in Python (the 17-line `want_head`, the icon hex lines, the boot-dir lines, the install lines), so a crashed/truncated run fails on missing lines. The ignored code is redundant, not the oracle.
- **`test_igr_vmc_drain.py:352-360` counts variant flag sets (`seen.add`) even when `if region:` skips the per-variant preprocessor check** — dissolved: an empty `region` can only arise when the drain block or `oplShutdown` is missing, which independently appends failures earlier in the same file; the counting check is not the sole oracle.
- **CFG harness in `test_ps1_retrogem_metadata.py` and the FavSupport stubs in `test_ripps2_all_games.py` are the same model-not-production defect as candidate 1** — dissolved: in both, the stubs are the *environment* (config storage, disc readers, source lists) and the logic under test is extracted production code (the supportbase CFG-merge slice; the favsupport gather/display/toggle block). Candidate 1 is distinct because the stubs there *are* the logic under test.
- **`test_ripps2_vmc_saves.py` PSU checks are circular in the RIPTOPL-286 sense** — dissolved: its `read_psu`/`make_psu` are written in the test from the PSU format, independently of `vmcsaves.cpp`, and RIPTOPL-286 concerns the shipped `APP_RIPTOPL*.psu` release artefact, a different file.
- **`test_ripps2_vmc_saves.py` encodes RIPTOPL-152 (unvalidated VMC-sourced names) as correct** — dissolved: the test never asserts acceptance of a `/`/`..` card-sourced name; it exercises only well-formed card names and separately asserts the PSU leg *refuses* a `..` name. That is a coverage gap downstream of an already-filed production finding, not a test asserting the defective behaviour.
- **`test_ps2build_configurations.py:19-21` creates `build/test-tmp` in the tree at import** — dissolved: `/build/` is gitignored (`.gitignore:110`, verified with `git check-ignore`), and the directory is the shared convention of at least nine suites in the corpus.
- **`test_vmc_rebuild_fatfs.py` edits FatFs config/header text** — dissolved: the edits (`FF_USE_MKFS` enabled, `_WIN32`→`_MSC_VER`) are applied only to copies in a temporary directory, are commented as test-only, and the shipped `FF_USE_EXPAND 1` requirement is asserted before the copy is modified.
- **`test_ra_disc.py` patch-selection list is built from the function it tests** — dissolved: the case list is extracted from production `apply_patches`, its length is asserted (`== 16`), and the real function is then executed with per-mode hit expectations; deleting or re-gating a case fails the test.
- **Hard-coded expected-output tables (`test_smbman_ra_write_count.py` `WANT`, `test_mc_folders.py` `want_head`) are mirror-image oracles** — dissolved: the expected strings are authored in Python independently of the C harnesses they check, which is the correct direction for a regression oracle.
