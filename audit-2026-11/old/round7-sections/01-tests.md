# Round 7 — Section 01: Launchstation `tests/` (full remainder)

- **Repo / pin:** NathanNeurotic/Launchstation @ `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` — verified held (`git rev-parse HEAD` at start and end). **READ ONLY held:** no repo edits; one instrumented copy of a test was run from a transient file and deleted in the same command; `git status --porcelain` empty at end (a `tests/__pycache__` produced by executing the suite was removed).
- **Scope:** all 273 tracked files under `tests/`, 37,908 lines by `wc -l` (37,915 by splitlines; 7 files lack a trailing newline). Excluded per brief (already cited rounds 1–4, NOT re-audited): `test_self_update.py`, `test_app_packages.py`, `test_update_sidecar_transaction.py`, `test_browser_sort.py`, `test_classic_settings_persistence.py`, `test_navigation_wraparound.py`, `ftp/`, `smb2man_live/`, `smbd_live/` — 26 files. Remainder audited here: **247 files**.
- **Method:** (1) full inventory + per-file classification (ledger below); (2) AST scan of every `.py` for `subprocess.run/call` without `check=` and for tautological asserts; regex scans for `assertTrue(True)`, `try/except: pass`, skip markers, warn-only paths; (3) **executed the whole suite** — every `tests/test_*.py` run individually (4-way parallel, then serial re-runs of all failures with `TMPDIR` on disk): **209 of 213 pass**; (4) grep-verified every referenced source path exists at the pin; (5) spot-checked shim declarations against the real headers they mirror; (6) normalised-body hashing for duplicated tests; (7) diffed the test-file set against every workflow's invocations.
- **Headline:** the suite is far healthier than LAUNCHSTATION-009's pass-1 framing suggests — 166 of 213 Python tests compile and *execute* real production C on the host (most under ASan/UBSan), and only 40 of the remainder are pure source-scrapes. Three candidates survive; a long checked-clean list follows. No finding from LAUNCHSTATION-001…185 is repeated: the generic scrape pattern stays -009's; everything below is new, specific, and evidence-backed.

## Execution results (all `tests/test_*.py`, at pin, this VM)

| Result | Count | Detail |
|---|---:|---|
| PASS | 209 | includes both CI-orphaned tests (T7-2), run manually |
| FAIL (deterministic) | 1 | `test_copy_psu_listing.py` — T7-1 |
| Blocked by VM environment only | 2 | `test_mc_save_export.py` needs the `cryptography` pip package (CI installs it, `compile.yml:35`); `test_dash_card_tool.py` needs mbedtls headers (CI installs `libmbedtls-dev`, `compile.yml:37`). Neither is a repo defect. |
| Spurious (parallel-run artefact) | 1 | `test_mc_card_write.py` timed out / hit ENOSPC only when the suite ran 4-way against the 512 MB `/tmp` tmpfs (it materialises ~121 MB of card images); passes serially with adequate TMPDIR. Not a finding; noted so nobody re-chases it. |

## Candidates

### T7-1 / `test_copy_psu_listing.py` fails deterministically at the pin — the Cut→PSU-backup "Move" to a UDPFS destination dies at the delete-confirmed-entries stage with −EIO / Category 6 (suspected product bug, surfaced by the test)
- **Location:** `tests/test_copy_psu_listing.py:556-557` (embedded C harness scenario: `clip("mc0:/","SAVEDIR",…); browser_cut=1; paste("udpfs:/")` then `assert(!message[0] && !nclipFiles && !exists("mc0:/SAVEDIR") && udpfs_read_opens==2 && …)`). Product stage implicated: `src/filer_copy.c:245-252` (`filerCopyDiagStage("Deleting confirmed move entries")`; the loop re-stats each manifest entry and returns `-EIO` when `moveEntryMatches(entry, &stat, 1)` fails).
- **Evidence (READ, executed):** the test was run 5 times (parallel suite run, serial re-run, and three instrumented runs) and failed at the same assertion every time with `SIGABRT`. An instrumented copy (transient, deleted; repo untouched) printing the harness state at that point showed `message = "Deleting confirmed move entries (-5)\nThe device reported an I/O failure."` — i.e. the first sub-condition (`!message[0]`) already fails: the move's delete stage returned −EIO (−5) inside the harness's fake-FS run, so the source save was not deleted as a confirmed move requires. The four preceding stale/lost-`.ps~`/`.psu` Move sub-cases in the same scenario block (lines 533-554) pass; only the clean Move fails. The test **is** wired into CI (`compile.yml:71`), so either CI is red at this pin or the harness/product path is sensitive to a host difference this audit could not identify — no filesystem, timing, or sanitizer input plausibly explains an in-process fake-FS −EIO, which is why this is filed rather than dissolved.
- **Fix:** Diagnose first (that is the work): reproduce, then determine whether `moveEntryMatches(…, 1)` mismatches on a field the fake FS models differently from a real card, or whether the product's delete-stage re-stat genuinely diverges after a PSU-backup paste. Fix whichever side is wrong; do not relax the assertion — it encodes the move contract (source deleted only after a verified destination).
- **Effort:** M (diagnosis; fix unknown until diagnosed) · **Risk:** Low for the test itself; the underlying behaviour, if product-side, is a failed Move that leaves the source in place — annoying, not corrupting · **Confidence:** READ (failure, stage, message, 5/5 reproduction); INFERRED (which side — product vs harness — is at fault).

### T7-2 / Three test assets are never run by any workflow — two passing Python tests (230 lines) and the `nfsman_live` harness are orphaned / Category 7
- **Locations:** `tests/test_boot_deferred_init.py` (49 lines, pure source-scrape), `tests/test_usb_stat_timeout.py` (181 lines, compile+execute harness over the bounded USB-stat helper extracted from `src/init.c`), `tests/nfsman_live/` (`drive.c` 275 + `run.sh` 52 lines).
- **Evidence (READ):** regex census of all six files in `.github/workflows/` finds 211 of 213 `tests/test_*.py` invoked (212 `python3 tests/test_…` invocations in `compile.yml` alone, plus the two live-harness steps at `compile.yml:40-48`); these two are in **no** workflow. Both were run manually at the pin for this section and **pass** — they are live tests that CI simply never executes, so a regression in deferred boot init (#277) or in USB stat timeout/recovery would ship undetected. `nfsman_live` is likewise absent from every workflow while its siblings `smb2man_live` and `smbd_live` are CI steps (`compile.yml:40-48`, run under `sudo`); caveat: `nfsman_live/run.sh` documents manual use and exits 2 loudly when its prerequisites (root, `nfs-kernel-server`, NFSv4.0) are missing, so its exclusion may be deliberate — but nothing in the repo says so, and the smb harnesses prove the CI pattern exists.
- **Fix:** Add the two `python3 tests/…` lines to `compile.yml` beside their neighbours (2 lines). For `nfsman_live`, either add a `sudo sh tests/nfsman_live/run.sh` step mirroring `smb2man_live`, or write one sentence in `run.sh`/docs that it is manual-only by decision.
- **Effort:** S · **Risk:** Low (both Python tests verified passing at the pin before proposing they gate CI) · **Confidence:** READ (workflow census + manual runs).

### T7-3 / The brace-matching C-function extractor is copied into 103 test files in 71 drifted variants (~1,420 lines) — the test suite's own LESS-NOT-MORE duplication / Category 2
- **Locations:** `def function(`/`def function_body(`/`def extract…` definitions in 103 distinct `tests/test_*.py` files (e.g. the identical 8-line body at `tests/test_cursor_sound_ticks.py:26-33` and `tests/test_device_input.py:23-30`; the regex-headed variant at `tests/test_ps2ips_rpc.py:53-62`). Measured by extraction: 103 copies, ≈1,420 lines in total, **71 distinct normalised variants** — the largest identical clusters are only 8, 7, and 6 files; the remaining ~50 files each carry a one-off variant (different signature handling, quoting, return decoration).
- **Problem:** Every production-function host test depends on this extractor to cut a function body out of a `.c` file by counting braces. It is the suite's single most-replicated mechanism and it exists only as copies: a fix to one copy (e.g. braces inside string literals or comments, which none of the variants handle) lands in one test and silently not in the other 102. The suite already proves the shared-module pattern works here: `tests/mc_fixture.py` (141 lines) is imported by six card tests via `sys.path.insert(0, str(Path(__file__).parent))` (e.g. `tests/test_mc_card_view.py:11-12`).
- **Fix:** Add one `tests/hostutil.py` with the extractor (and the equally common `read()`/`root` preamble), then mechanically replace each copy with an import — deletions dominate (~1,300 net lines removed). Do it file-by-file, running each test after its swap; the 71 variants collapse to the union of behaviours actually used, which the per-file runs verify.
- **Effort:** M · **Risk:** Low (each swap is gated by that test's own run; no production code touched) · **Confidence:** READ (counts and variant census measured by script over the pin tree; the mc_fixture precedent read directly).

## Checked-clean (dissolved candidates, with reasoning)

1. **The five zero-`assert` Python files are not vacuous.** `test_cursor_sound_ticks.py`, `test_ftp_session.py`, `test_pccf.py`, `test_smb_cnf_edit.py`, `test_usbmass_two_drives.py` contain no Python `assert` because the assertions live in the C harness they compile, and every compile/run uses `subprocess.run(…, check=True)` — a harness failure raises and fails the test (verified by reading all five in full; e.g. `test_smb_cnf_edit.py`'s embedded C runs ~40 `check()` cases and returns `fails != 0`). Same pattern, verified by AST scan, for the whole compile+execute class: the only `subprocess.run` calls without `check=True` in the tree are deliberate negative tests whose `.returncode` is asserted on the next line(s) — `test_mc_card_export.py:172-173` (truncated images must exit non-zero), `test_build_identity.py:39,56`, `test_release_notes.py:63,168`, `test_udpfs_smap_startup.py:83` (compares `(returncode == 0) != expected`, including two "inherited defect reproduced" cases that must fail), and the `run()` helpers in the mc_* wrappers, which assert `out.returncode == 0` with stderr context.
2. **No tautological assertions exist.** Full-tree regex/AST scan found zero instances of `assert True`, `assertTrue(True)`, `assert 1`, or `… or True`. `test_selector_centering.py`'s single textual `assert` is a loop assertion over 10 extracted layout rows with a ±1 px numeric bound — it can and does fail on real values.
3. **Every `try/except: pass` is the correct negative-test idiom.** All three occurrences (`test_download_metrics.py:31-36`, `test_ftp_network.py:89-94`, `test_ps2ips_rpc.py:39-42`, plus the same shape in `test_r3z_config_inventory.py:20-22`) are `try: … except X: pass / else: raise AssertionError(…)` — the pass is unreachable unless the expected rejection happened. No swallowed failure exists in the tree by this pattern.
4. **No test references dead code.** Every literal `src/`, `include/`, `iop/`, `scripts/`, `tests/` path asserted or opened by any test exists at the pin (script census, zero misses), and the execution results corroborate it: an extractor `function()` call on a missing signature raises `ValueError`/`AssertionError`, so a dead reference in any of the 211 CI-run tests would be a failing test — only T7-1 fails, for a different, identified reason. Absence-style assertions (`"X" not in source`, e.g. the #384 machinery checks) were spot-read and are paired with presence/behaviour checks in the same files.
5. **No skipped-by-default tests inside files.** There is no `unittest`/`pytest` usage in the suite at all (every test is a script whose exit code is the verdict, matching `compile.yml`'s per-file invocation), hence no `@skip` markers; the single `SKIP` string in the tree, `test_ftp_server.py:44`, skips only the `-m32` freestanding sub-check on non-x86 hosts and prints it — the file's main compile+execute checks run unconditionally on every platform. Missing host compilers raise `SystemExit("…required")` (a failure, not a skip) uniformly.
6. **Pure source-scrape remainder: 40 files, 2,096 lines — census only, no new candidate.** These files (ledger type `python-source-scrape`, excluding the DONE-group members) assert string presence/ordering in production sources and execute nothing. That is exactly LAUNCHSTATION-009's already-filed pattern; filing it again would repeat 001…185. What round 7 adds is the proportion: they are now the minority — 166 compile+execute harnesses and 7 script-exec tests against 40 pure scrapes — and each scrape file was read and carries multiple concrete, fail-able assertions (median ~20 per file); none was found asserting a string that the same file itself writes into the source, and none counts without asserting the count.
7. **No duplicated test bodies.** Normalised-body hashing (docstring-stripped, whitespace-collapsed) over all 213 `test_*.py` files found zero duplicate bodies. The near-name pair `test_r3z_four_browser_modes.py` (84 lines) vs `test_native_four_browser_modes.py` (34 lines) was diffed directly: different subjects (classic File Browser mode predicates vs native Files tab predicates), different mechanisms. The real duplication in the suite is infrastructural, not behavioural — that is T7-3.
8. **`*_host.c` printer harnesses are not assert-free voids.** The eight `tests/*_host.c` files contain no C `assert` because they are structured-output drivers: they print the production code's view (`open=`, `save|…` records) and the Python wrappers assert on the parsed output exhaustively (read in full for `mc_card_view_host.c` + `test_mc_card_view.py`, including a 150-case mutation-fuzz loop asserting `returncode == 0` under ASan/UBSan). `dash_card_tool_host.c` additionally `abort()`s on invariant violations (two files open at once, dialog script mismatch). The pccf C tests (`test_cf.c`, `test_cis.c`, `test_pccf_*.c`, driven by `test_pccf.py`/`test_pccf_fs.py`/`test_pccf_owner.py`) are assert-dense (25-61 asserts each).
9. **Shims/stubs have not drifted in anything they declare (spot-checked).** `tests/card-tool-shim/dash_internal.h` prototypes match the real headers verbatim for every spot-checked declaration (`genOpen` = `include/launchelf.h:606`, `genRenameNoReplace` = `include/launchelf.h:625`, `dashStrCopy` = `include/dash_internal.h:663`, `MAX_NAME = 256` = `include/launchelf.h:201`, `MAX_PATH 1025`). `tests/card-tool-shim/mc_card_export.h` is an intentional subset (1 of 7 functions, 2 of 6 result codes) — it declares only what `dash_card_tool_host.c` links, its one prototype and both enum values match `include/mc_card_export.h` exactly, and any future use of an omitted declaration fails at compile time, not silently. `tests/pccf-stubs/tamtypes.h`/`sysclib.h` are 1-line redirects to the local `types.h`/`<string.h>` by design. Full-line audit of all 33 shim/stub headers against their SDK counterparts is not possible from this repo (the real PS2SDK headers are external), and is stated as a limit, not a pass.
10. **Both fixtures are live.** `tests/fixtures/transcend_ts4gcf133.cis` is opened by `tests/test_cf.c:104`; `tests/fixtures/r3z-06b06d0-config-keys.json` is loaded by `scripts/audit_r3z_settings.py:99`, exercised through `tests/test_r3z_config_inventory.py`. `tests/mc_fixture.py` is a shared fixture builder (see T7-3), not a test. `tests/pccf_ata_card.h` (140 lines) is the ATA fixture header included by `tests/test_pccf_ata.c`.
11. **`nfsman_live/drive.c` itself is sound** (read in full): it `#include`s the real `iop/nfsman/nfsman.c`, drives its iomanX ops through a `CHECK` macro that also asserts the driver lock is released after every op, and runs under ASan/UBSan per its `run.sh`. Its only defect is the CI orphaning filed in T7-2.
12. **Dependence on DONE-group files:** several remainder tests reuse DONE-group infrastructure without re-auditing it — `test_ftp_server.py` compiles against `tests/ftp/startup.h`/`platform.h` and `tests/pccf-stubs/`; `nfsman_live` builds against `tests/smb2man_live/inc/` headers. No remainder test was found to *duplicate* a DONE-group test's assertions.

## Ledger — every tracked file in `tests/` (273 files, 37,908 lines by `wc -l`)

Types: `python compile+execute harness` (compiles production C and runs it, or executes a production script with assertions) · `python-source-scrape` (asserts over source text only) · `C host harness` · `live-harness` (needs a live server/service) · `shim-stub` · `fixture`. Status `DONE (rounds 1–4)` = the brief's excluded set, not re-audited; all other rows were read or classified this round, and every `test_*.py` among them was also executed (see Execution results).

| File | Lines | Type | Status |
|---|---:|---|---|
| `tests/card-tool-shim/dash_internal.h` | 58 | shim-stub | read/classified R7 |
| `tests/card-tool-shim/filer_shared.h` | 11 | shim-stub | read/classified R7 |
| `tests/card-tool-shim/launchelf.h` | 2 | shim-stub | read/classified R7 |
| `tests/card-tool-shim/libcdvd.h` | 8 | shim-stub | read/classified R7 |
| `tests/card-tool-shim/mc_card_export.h` | 7 | shim-stub | read/classified R7 |
| `tests/dash_card_tool_host.c` | 538 | C host harness | read/classified R7 |
| `tests/fixtures/r3z-06b06d0-config-keys.json` | 66 | fixture | read/classified R7 |
| `tests/fixtures/transcend_ts4gcf133.cis` | 8 | fixture | read/classified R7 |
| `tests/ftp-ee/delaythread.h` | 4 | shim-stub | read/classified R7 |
| `tests/ftp-ee/init.h` | 4 | shim-stub | read/classified R7 |
| `tests/ftp-ee/launchelf.h` | 5 | shim-stub | read/classified R7 |
| `tests/ftp-ee/sifrpc.h` | 13 | shim-stub | read/classified R7 |
| `tests/ftp-ee/test_session.c` | 240 | C host harness | read/classified R7 |
| `tests/ftp/loadcore.h` | 7 | shim-stub | DONE (rounds 1–4) |
| `tests/ftp/platform.h` | 61 | shim-stub | DONE (rounds 1–4) |
| `tests/ftp/sifrpc.h` | 14 | shim-stub | DONE (rounds 1–4) |
| `tests/ftp/startup.h` | 18 | shim-stub | DONE (rounds 1–4) |
| `tests/ftp/test_server.c` | 1131 | live-harness | DONE (rounds 1–4) |
| `tests/mc_card_view_host.c` | 51 | C host harness | read/classified R7 |
| `tests/mc_card_write_host.c` | 212 | C host harness | read/classified R7 |
| `tests/mc_fingerprint_host.c` | 71 | C host harness | read/classified R7 |
| `tests/mc_fixture.py` | 141 | fixture | read/classified R7 |
| `tests/mc_ps1_card_host.c` | 126 | C host harness | read/classified R7 |
| `tests/mc_save_export_host.c` | 170 | C host harness | read/classified R7 |
| `tests/mc_save_formats_host.c` | 133 | C host harness | read/classified R7 |
| `tests/mmce_save_versions_host.c` | 125 | C host harness | read/classified R7 |
| `tests/nfsman_live/drive.c` | 275 | live-harness | read/classified R7 |
| `tests/nfsman_live/run.sh` | 52 | live-harness | read/classified R7 |
| `tests/pccf-stubs/bdm.h` | 11 | shim-stub | read/classified R7 |
| `tests/pccf-stubs/dev9regs.h` | 46 | shim-stub | read/classified R7 |
| `tests/pccf-stubs/io_common.h` | 66 | shim-stub | read/classified R7 |
| `tests/pccf-stubs/iomanX.h` | 398 | shim-stub | read/classified R7 |
| `tests/pccf-stubs/iox_stat.h` | 143 | shim-stub | read/classified R7 |
| `tests/pccf-stubs/irx.h` | 4 | shim-stub | read/classified R7 |
| `tests/pccf-stubs/loadcore.h` | 13 | shim-stub | read/classified R7 |
| `tests/pccf-stubs/sysclib.h` | 1 | shim-stub | read/classified R7 |
| `tests/pccf-stubs/tamtypes.h` | 1 | shim-stub | read/classified R7 |
| `tests/pccf-stubs/thbase.h` | 5 | shim-stub | read/classified R7 |
| `tests/pccf-stubs/thsemap.h` | 87 | shim-stub | read/classified R7 |
| `tests/pccf-stubs/types.h` | 5 | shim-stub | read/classified R7 |
| `tests/pccf_ata_card.h` | 140 | fixture | read/classified R7 |
| `tests/smb2man_live/drive.c` | 350 | live-harness | DONE (rounds 1–4) |
| `tests/smb2man_live/inc/intrman.h` | 10 | shim-stub | DONE (rounds 1–4) |
| `tests/smb2man_live/inc/iomanX.h` | 76 | shim-stub | DONE (rounds 1–4) |
| `tests/smb2man_live/inc/loadcore.h` | 3 | shim-stub | DONE (rounds 1–4) |
| `tests/smb2man_live/inc/sysclib.h` | 1 | shim-stub | DONE (rounds 1–4) |
| `tests/smb2man_live/inc/sysmem.h` | 23 | shim-stub | DONE (rounds 1–4) |
| `tests/smb2man_live/inc/tamtypes.h` | 13 | shim-stub | DONE (rounds 1–4) |
| `tests/smb2man_live/inc/thbase.h` | 9 | shim-stub | DONE (rounds 1–4) |
| `tests/smb2man_live/inc/thsemap.h` | 29 | shim-stub | DONE (rounds 1–4) |
| `tests/smb2man_live/run.sh` | 179 | live-harness | DONE (rounds 1–4) |
| `tests/smbd_live/client.c` | 238 | live-harness | DONE (rounds 1–4) |
| `tests/smbd_live/host.c` | 234 | live-harness | DONE (rounds 1–4) |
| `tests/smbd_live/run.sh` | 194 | live-harness | DONE (rounds 1–4) |
| `tests/test_app_packages.py` | 186 | python compile+execute harness | DONE (rounds 1–4) |
| `tests/test_background_only_hotkeys.py` | 119 | python compile+execute harness | read/classified R7 |
| `tests/test_bgm_sidecar.py` | 260 | python compile+execute harness | read/classified R7 |
| `tests/test_bookmark_routes.py` | 70 | python compile+execute harness | read/classified R7 |
| `tests/test_boot_deferred_init.py` | 49 | python-source-scrape | read/classified R7 |
| `tests/test_browser_sort.py` | 150 | python compile+execute harness | DONE (rounds 1–4) |
| `tests/test_build_identity.py` | 59 | python compile+execute harness | read/classified R7 |
| `tests/test_carousel_culling.py` | 62 | python compile+execute harness | read/classified R7 |
| `tests/test_cdvd_scmd_buffers.py` | 58 | python-source-scrape | read/classified R7 |
| `tests/test_cf.c` | 157 | C host harness | read/classified R7 |
| `tests/test_cis.c` | 125 | C host harness | read/classified R7 |
| `tests/test_classic_settings_persistence.py` | 97 | python compile+execute harness | DONE (rounds 1–4) |
| `tests/test_clock_field_editor.py` | 90 | python compile+execute harness | read/classified R7 |
| `tests/test_clock_save_action.py` | 79 | python compile+execute harness | read/classified R7 |
| `tests/test_clock_sync.py` | 253 | python compile+execute harness | read/classified R7 |
| `tests/test_cloud_history_browser.py` | 137 | python compile+execute harness | read/classified R7 |
| `tests/test_cloud_link_screen.py` | 70 | python compile+execute harness | read/classified R7 |
| `tests/test_cloud_menu.py` | 164 | python compile+execute harness | read/classified R7 |
| `tests/test_cloud_recovery.py` | 275 | python compile+execute harness | read/classified R7 |
| `tests/test_cloud_relay.py` | 26 | python-source-scrape | read/classified R7 |
| `tests/test_cloud_tls_paths.py` | 67 | python compile+execute harness | read/classified R7 |
| `tests/test_cloud_upload_ledger.py` | 190 | python compile+execute harness | read/classified R7 |
| `tests/test_console_region.py` | 45 | python compile+execute harness | read/classified R7 |
| `tests/test_copy_pipeline.py` | 481 | python compile+execute harness | read/classified R7 |
| `tests/test_copy_psu_listing.py` | 784 | python compile+execute harness | read/classified R7 |
| `tests/test_copy_short_io.py` | 104 | python compile+execute harness | read/classified R7 |
| `tests/test_copy_test_pack.py` | 23 | python-source-scrape | read/classified R7 |
| `tests/test_cursor_sound_ticks.py` | 85 | python compile+execute harness | read/classified R7 |
| `tests/test_dash_card_tool.py` | 1421 | python compile+execute harness | read/classified R7 |
| `tests/test_dash_ftp.py` | 193 | python compile+execute harness | read/classified R7 |
| `tests/test_dash_pause.py` | 70 | python compile+execute harness | read/classified R7 |
| `tests/test_dashboard_console_summary.py` | 50 | python-source-scrape | read/classified R7 |
| `tests/test_dashboard_languages.py` | 124 | python compile+execute harness | read/classified R7 |
| `tests/test_dashboard_pending_loops.py` | 20 | python-source-scrape | read/classified R7 |
| `tests/test_dashboard_present_buffers.py` | 133 | python compile+execute harness | read/classified R7 |
| `tests/test_dev9_transition.py` | 166 | python compile+execute harness | read/classified R7 |
| `tests/test_device_autostart_safe_mode.py` | 52 | python-source-scrape | read/classified R7 |
| `tests/test_device_input.py` | 483 | python compile+execute harness | read/classified R7 |
| `tests/test_display_feedback.py` | 133 | python compile+execute harness | read/classified R7 |
| `tests/test_download_metrics.py` | 200 | python-source-scrape | read/classified R7 |
| `tests/test_editor_keyboard.py` | 804 | python compile+execute harness | read/classified R7 |
| `tests/test_elisa_font_load.py` | 43 | python compile+execute harness | read/classified R7 |
| `tests/test_ember_gameid.py` | 132 | python compile+execute harness | read/classified R7 |
| `tests/test_ember_iop_handoff.py` | 79 | python-source-scrape | read/classified R7 |
| `tests/test_ember_launch.py` | 87 | python-source-scrape | read/classified R7 |
| `tests/test_ember_paths.py` | 104 | python compile+execute harness | read/classified R7 |
| `tests/test_ember_retrogem_handoff.py` | 61 | python compile+execute harness | read/classified R7 |
| `tests/test_ember_two_usb_handoff.py` | 149 | python compile+execute harness | read/classified R7 |
| `tests/test_exploit_folder_warning.py` | 181 | python compile+execute harness | read/classified R7 |
| `tests/test_feedback_35_82.py` | 46 | python-source-scrape | read/classified R7 |
| `tests/test_file_browser_heap.py` | 83 | python compile+execute harness | read/classified R7 |
| `tests/test_file_operation_overlay.py` | 201 | python compile+execute harness | read/classified R7 |
| `tests/test_file_stat_errors.py` | 142 | python compile+execute harness | read/classified R7 |
| `tests/test_files_tab_lifecycle.py` | 159 | python compile+execute harness | read/classified R7 |
| `tests/test_font_weight.py` | 228 | python compile+execute harness | read/classified R7 |
| `tests/test_ftp_network.py` | 118 | python compile+execute harness | read/classified R7 |
| `tests/test_ftp_server.py` | 65 | python compile+execute harness | read/classified R7 |
| `tests/test_ftp_session.py` | 30 | python compile+execute harness | read/classified R7 |
| `tests/test_gage_alignment.py` | 54 | python-source-scrape | read/classified R7 |
| `tests/test_get_size.py` | 260 | python compile+execute harness | read/classified R7 |
| `tests/test_hdd_manager_browse.py` | 85 | python compile+execute harness | read/classified R7 |
| `tests/test_hex_editor.py` | 320 | python compile+execute harness | read/classified R7 |
| `tests/test_hidden_apps.py` | 74 | python compile+execute harness | read/classified R7 |
| `tests/test_hint_bar_fit.py` | 76 | python compile+execute harness | read/classified R7 |
| `tests/test_hint_clearance.py` | 34 | python-source-scrape | read/classified R7 |
| `tests/test_hint_order.py` | 98 | python compile+execute harness | read/classified R7 |
| `tests/test_home_focus.py` | 135 | python compile+execute harness | read/classified R7 |
| `tests/test_http_body_cap.py` | 120 | python compile+execute harness | read/classified R7 |
| `tests/test_https_tls.py` | 252 | python compile+execute harness | read/classified R7 |
| `tests/test_igr_return_policy.py` | 49 | python-source-scrape | read/classified R7 |
| `tests/test_ilink_browser.py` | 44 | python-source-scrape | read/classified R7 |
| `tests/test_kit_package.py` | 306 | python compile+execute harness | read/classified R7 |
| `tests/test_launch_driver_messages.py` | 361 | python compile+execute harness | read/classified R7 |
| `tests/test_launch_iop_override.py` | 265 | python compile+execute harness | read/classified R7 |
| `tests/test_launch_options.py` | 93 | python compile+execute harness | read/classified R7 |
| `tests/test_listing_callers.py` | 455 | python compile+execute harness | read/classified R7 |
| `tests/test_listing_complete.py` | 389 | python compile+execute harness | read/classified R7 |
| `tests/test_llvm_toolchain.py` | 69 | python-source-scrape | read/classified R7 |
| `tests/test_loader_linkfile.py` | 24 | python-source-scrape | read/classified R7 |
| `tests/test_maintained_documentation.py` | 48 | python-source-scrape | read/classified R7 |
| `tests/test_mc1_mx4sio_handoff.py` | 183 | python compile+execute harness | read/classified R7 |
| `tests/test_mc_card_export.py` | 174 | python compile+execute harness | read/classified R7 |
| `tests/test_mc_card_view.py` | 136 | python compile+execute harness | read/classified R7 |
| `tests/test_mc_card_write.py` | 465 | python compile+execute harness | read/classified R7 |
| `tests/test_mc_fingerprint.py` | 179 | python compile+execute harness | read/classified R7 |
| `tests/test_mc_folder_icon.py` | 140 | python compile+execute harness | read/classified R7 |
| `tests/test_mc_poll_usb_barrier.py` | 81 | python compile+execute harness | read/classified R7 |
| `tests/test_mc_ps1_card.py` | 315 | python compile+execute harness | read/classified R7 |
| `tests/test_mc_save_export.py` | 259 | python compile+execute harness | read/classified R7 |
| `tests/test_mc_save_formats.py` | 512 | python compile+execute harness | read/classified R7 |
| `tests/test_misc_settings_dispatch.py` | 38 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_backup.py` | 59 | python-source-scrape | read/classified R7 |
| `tests/test_mmce_bus_restore.py` | 59 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_dread_returns.py` | 95 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_exclusive_new_files.py` | 104 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_fingerprint_backup.py` | 198 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_fs_restore_guard.py` | 88 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_handle_release.py` | 142 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_native_import.py` | 114 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_presence_probe.py` | 58 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_protocol.py` | 18 | python-source-scrape | read/classified R7 |
| `tests/test_mmce_publish.py` | 233 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_recovery.py` | 113 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_rename_fallback.py` | 112 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_restore_txn_model.py` | 235 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_save_versions.py` | 214 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_selectable_install.py` | 167 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_status_failures.py` | 115 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_targeted_safety.py` | 158 | python compile+execute harness | read/classified R7 |
| `tests/test_mmce_upstream_contract.py` | 80 | python-source-scrape | read/classified R7 |
| `tests/test_modal_animation.py` | 308 | python compile+execute harness | read/classified R7 |
| `tests/test_move_manifest.py` | 82 | python compile+execute harness | read/classified R7 |
| `tests/test_native_cloud.py` | 182 | python-source-scrape | read/classified R7 |
| `tests/test_native_four_browser_modes.py` | 34 | python compile+execute harness | read/classified R7 |
| `tests/test_navigation_wraparound.py` | 73 | python-source-scrape | DONE (rounds 1–4) |
| `tests/test_nested_scissor.py` | 104 | python compile+execute harness | read/classified R7 |
| `tests/test_network_load_result.py` | 171 | python compile+execute harness | read/classified R7 |
| `tests/test_neutrino_cancel_feedback.py` | 67 | python compile+execute harness | read/classified R7 |
| `tests/test_neutrino_iso.py` | 66 | python-source-scrape | read/classified R7 |
| `tests/test_neutrino_menu_audio.py` | 188 | python compile+execute harness | read/classified R7 |
| `tests/test_neutrino_profiles.py` | 141 | python compile+execute harness | read/classified R7 |
| `tests/test_neutrino_smb.py` | 138 | python compile+execute harness | read/classified R7 |
| `tests/test_new_folder_save_icons.py` | 78 | python compile+execute harness | read/classified R7 |
| `tests/test_nfs_shares.py` | 187 | python compile+execute harness | read/classified R7 |
| `tests/test_opl_title_cfg.py` | 115 | python compile+execute harness | read/classified R7 |
| `tests/test_orb_seamless.py` | 86 | python compile+execute harness | read/classified R7 |
| `tests/test_own_config_name.py` | 29 | python-source-scrape | read/classified R7 |
| `tests/test_pad_icon_order.py` | 47 | python-source-scrape | read/classified R7 |
| `tests/test_panel_transparency.py` | 36 | python compile+execute harness | read/classified R7 |
| `tests/test_pccf.py` | 29 | python compile+execute harness | read/classified R7 |
| `tests/test_pccf_ata.c` | 97 | C host harness | read/classified R7 |
| `tests/test_pccf_fs.py` | 279 | python compile+execute harness | read/classified R7 |
| `tests/test_pccf_hw.c` | 194 | C host harness | read/classified R7 |
| `tests/test_pccf_module.c` | 84 | C host harness | read/classified R7 |
| `tests/test_pccf_owner.py` | 115 | python compile+execute harness | read/classified R7 |
| `tests/test_pccf_rw.c` | 86 | C host harness | read/classified R7 |
| `tests/test_physical_hold_input.py` | 48 | python compile+execute harness | read/classified R7 |
| `tests/test_png_viewer.py` | 52 | python-source-scrape | read/classified R7 |
| `tests/test_popstarter_retrogem.py` | 62 | python compile+execute harness | read/classified R7 |
| `tests/test_portable_filename.py` | 74 | python compile+execute harness | read/classified R7 |
| `tests/test_poweroff_init.py` | 45 | python compile+execute harness | read/classified R7 |
| `tests/test_poweroff_shutdown.py` | 64 | python-source-scrape | read/classified R7 |
| `tests/test_project_branding.py` | 51 | python-source-scrape | read/classified R7 |
| `tests/test_ps1_card_rediscovery.py` | 149 | python compile+execute harness | read/classified R7 |
| `tests/test_ps2browser_card_update.py` | 87 | python compile+execute harness | read/classified R7 |
| `tests/test_ps2ips_rpc.py` | 566 | python compile+execute harness | read/classified R7 |
| `tests/test_psu_extract_to_mc.py` | 59 | python-source-scrape | read/classified R7 |
| `tests/test_r3z_browser_contract.py` | 91 | python compile+execute harness | read/classified R7 |
| `tests/test_r3z_browser_wins.py` | 111 | python compile+execute harness | read/classified R7 |
| `tests/test_r3z_config_inventory.py` | 57 | python compile+execute harness | read/classified R7 |
| `tests/test_r3z_four_browser_modes.py` | 84 | python compile+execute harness | read/classified R7 |
| `tests/test_r3z_loader_disable.py` | 59 | python-source-scrape | read/classified R7 |
| `tests/test_r3z_neutrino_gameid.py` | 216 | python compile+execute harness | read/classified R7 |
| `tests/test_r3z_neutrino_options.py` | 158 | python compile+execute harness | read/classified R7 |
| `tests/test_r3z_oct15_backport.py` | 140 | python compile+execute harness | read/classified R7 |
| `tests/test_r3z_video_switch.py` | 97 | python compile+execute harness | read/classified R7 |
| `tests/test_recent_skips_game_images.py` | 50 | python compile+execute harness | read/classified R7 |
| `tests/test_release_notes.py` | 173 | python compile+execute harness | read/classified R7 |
| `tests/test_rename_devices.py` | 510 | python compile+execute harness | read/classified R7 |
| `tests/test_rolling_release_workflow.py` | 112 | python compile+execute harness | read/classified R7 |
| `tests/test_root_mc_poll.py` | 144 | python compile+execute harness | read/classified R7 |
| `tests/test_scene_override_nesting.py` | 34 | python-source-scrape | read/classified R7 |
| `tests/test_sd2cloud_parity.py` | 57 | python-source-scrape | read/classified R7 |
| `tests/test_selector_centering.py` | 47 | python-source-scrape | read/classified R7 |
| `tests/test_self_update.py` | 63 | python-source-scrape | DONE (rounds 1–4) |
| `tests/test_settings_navigation.py` | 247 | python compile+execute harness | read/classified R7 |
| `tests/test_settings_save_prompt.py` | 214 | python compile+execute harness | read/classified R7 |
| `tests/test_sfx_ps2.py` | 52 | python-source-scrape | read/classified R7 |
| `tests/test_sjis_dashboard_titles.py` | 149 | python compile+execute harness | read/classified R7 |
| `tests/test_smb_browser_failure.py` | 65 | python compile+execute harness | read/classified R7 |
| `tests/test_smb_cnf_edit.py` | 203 | python compile+execute harness | read/classified R7 |
| `tests/test_smb_connect_state.py` | 157 | python compile+execute harness | read/classified R7 |
| `tests/test_smb_explicit_port.py` | 73 | python compile+execute harness | read/classified R7 |
| `tests/test_smb_settings_row.py` | 89 | python-source-scrape | read/classified R7 |
| `tests/test_smb_shares.py` | 333 | python compile+execute harness | read/classified R7 |
| `tests/test_software_clock.py` | 193 | python compile+execute harness | read/classified R7 |
| `tests/test_sound_recovery.py` | 127 | python compile+execute harness | read/classified R7 |
| `tests/test_stack_realign_check.py` | 350 | python compile+execute harness | read/classified R7 |
| `tests/test_startup_status.py` | 119 | python compile+execute harness | read/classified R7 |
| `tests/test_storage_probe_frames.py` | 41 | python compile+execute harness | read/classified R7 |
| `tests/test_system_clock_menu.py` | 42 | python-source-scrape | read/classified R7 |
| `tests/test_temperature.py` | 161 | python compile+execute harness | read/classified R7 |
| `tests/test_theme_motion.py` | 81 | python compile+execute harness | read/classified R7 |
| `tests/test_tile_styles.py` | 199 | python compile+execute harness | read/classified R7 |
| `tests/test_timer_wrap.py` | 53 | python compile+execute harness | read/classified R7 |
| `tests/test_transfer_progress.py` | 84 | python compile+execute harness | read/classified R7 |
| `tests/test_transfer_stack_preflight.py` | 181 | python compile+execute harness | read/classified R7 |
| `tests/test_transition_latency.py` | 32 | python-source-scrape | read/classified R7 |
| `tests/test_udpfs_directory_errors.py` | 93 | python compile+execute harness | read/classified R7 |
| `tests/test_udpfs_retry.py` | 36 | python-source-scrape | read/classified R7 |
| `tests/test_udpfs_smap_fifo_tail.py` | 218 | python compile+execute harness | read/classified R7 |
| `tests/test_udpfs_smap_startup.py` | 96 | python compile+execute harness | read/classified R7 |
| `tests/test_unified_dashboard_navigation.py` | 152 | python compile+execute harness | read/classified R7 |
| `tests/test_update_ancestry.py` | 176 | python compile+execute harness | read/classified R7 |
| `tests/test_update_ram_sink.py` | 142 | python compile+execute harness | read/classified R7 |
| `tests/test_update_sas_timestamps.py` | 183 | python compile+execute harness | read/classified R7 |
| `tests/test_update_sidecar_transaction.py` | 262 | python compile+execute harness | DONE (rounds 1–4) |
| `tests/test_usb_boot_paths.py` | 89 | python compile+execute harness | read/classified R7 |
| `tests/test_usb_browse_cache.py` | 212 | python compile+execute harness | read/classified R7 |
| `tests/test_usb_iop_pad_handoff.py` | 86 | python compile+execute harness | read/classified R7 |
| `tests/test_usb_probe_status.py` | 102 | python compile+execute harness | read/classified R7 |
| `tests/test_usb_shared_namespace.py` | 98 | python compile+execute harness | read/classified R7 |
| `tests/test_usb_stat_timeout.py` | 181 | python compile+execute harness | read/classified R7 |
| `tests/test_usb_storage_lifecycle.py` | 156 | python compile+execute harness | read/classified R7 |
| `tests/test_usb_unit_diagnostics.py` | 167 | python compile+execute harness | read/classified R7 |
| `tests/test_usb_wait_text.py` | 90 | python compile+execute harness | read/classified R7 |
| `tests/test_usbmass_two_drives.py` | 337 | python compile+execute harness | read/classified R7 |
| `tests/test_video_sound_preview.py` | 75 | python compile+execute harness | read/classified R7 |
| `tests/test_vmc_rename.py` | 137 | python compile+execute harness | read/classified R7 |
| `tests/test_wallpaper_docs.py` | 41 | python-source-scrape | read/classified R7 |
| `tests/test_wiki_capture_media.py` | 23 | python-source-scrape | read/classified R7 |
| `tests/test_wle_igr.py` | 51 | python-source-scrape | read/classified R7 |
| `tests/test_worker_queue.py` | 81 | python compile+execute harness | read/classified R7 |
| `tests/test_zack_feedback.py` | 68 | python-source-scrape | read/classified R7 |
| `tests/test_zack_launch_sizing.py` | 75 | python-source-scrape | read/classified R7 |
| `tests/test_zack_oct_2026.py` | 65 | python-source-scrape | read/classified R7 |
| `tests/test_zack_quickwins.py` | 105 | python compile+execute harness | read/classified R7 |
| `tests/test_zack_round3.py` | 78 | python-source-scrape | read/classified R7 |
| `tests/test_zack_storage_drivers.py` | 212 | python compile+execute harness | read/classified R7 |
