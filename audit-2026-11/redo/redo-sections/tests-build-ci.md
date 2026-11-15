# Launchstation — Blind Redo Audit: Tests, Build & CI

- Repo: `~/workspace/audit-clones-2026-11-13/Launchstation`
- Pin verified by command: `git rev-parse HEAD` = `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790`; working tree clean at start.
- Scope: Python test suites and test infrastructure (`tests/`, `.github/scripts/`), `scripts/` (cloud generator inventoried only, no secret values printed), `.github/workflows/`, `ps2.yaml` build graph, `loader/`, `ee_libs/`, build helpers, packaging/release flow.
- Method: read-only in the clone; all test/build experiments ran in a `/tmp` copy (`.git` excluded for the bulk run, included for the git-dependent re-runs). All counts below are by script or executed command, not estimates.

---

## Execution log (commands + results)

Environment: Python 3.12.3, gcc 13.3.0 (Ubuntu 24.04), numpy 1.26.4 present; `cryptography` and `libmbedtls-dev` absent locally (CI installs both — see below).

| # | Command | Result |
|---|---|---|
| 1 | `git rev-parse HEAD` in clone | `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (matches assigned pin) |
| 2 | Bulk run in `/tmp/ls-copy`: `python3 <each of tests/test_*.py>` + `python3 .github/scripts/test_ps2build_sdk_watch.py`, 120 s timeout each, exit code recorded | 214 suites: 208 PASS, 5 FAIL, 1 TIMEOUT on first pass (see re-runs) |
| 3 | Re-run `tests/test_mc_card_write.py` alone (after freeing `/tmp`) | PASS (110 s; the bulk-run TIMEOUT was a shared-`/tmp` disk-full artifact of this sandbox, 512 MB tmpfs — not a repo result) |
| 4 | Re-run `tests/test_build_identity.py`, `tests/test_release_notes.py` in a copy **with** `.git` | Both PASS (bulk-run failures were solely `fatal: not a git repository` from the `.git`-less copy) |
| 5 | Re-run `tests/test_mc_save_export.py` with `cryptography` installed in a venv | Past the import; then blocked at compile: `src/mc_save_export.c:11:10: fatal error: mbedtls/aes.h: No such file or directory` — environment block, matches CI step below |
| 6 | `tests/test_dash_card_tool.py` | Same environment block: `mbedtls/aes.h` missing. CI installs it at `.github/workflows/compile.yml:37` (`sudo apt-get install -y -qq libmbedtls-dev`) and `cryptography` at `compile.yml:35`; this VM's apt has no `libmbedtls-dev` package, so both suites are **environment-blocked locally, not failed** |
| 7 | `tests/test_copy_psu_listing.py` — 4 independent runs in the `/tmp` copy | **FAIL 4/4, deterministic**, same assertion every run (TEST-001) |
| 8 | CI-wiring diff by script: unique `tests/test_*.py` names in `.github/workflows/compile.yml` vs `ls tests/test_*.py` | 213 test files; 211 named in `compile.yml`; exactly 2 orphans (TEST-002); 0 names in CI without a file |
| 9 | `ps2.yaml` verification by script (PyYAML parse, 26 targets, 270 source entries) | All non-fetched source paths exist; only duplicate sources are the 5 `iop/vmcman/src/*.c` files shared by targets `mcman_physical`/`vmcman` (documented in the file's own comments); missing paths are only the fetched `.smbd-deps/libsmb2/*` (55 entries, produced by `scripts/fetch_libsmb2.sh`) and `.cloud-deps/`/`.jpeg-deps/` include dirs (produced by `scripts/build_cloud_tls.sh` / `scripts/build_jpeg.sh`). 12 on-disk production C/S files are unlisted — all explained except 3 (see TEST-005, TEST-010): 6 DS34 files + `src/pad_ds34.c` enter via the generated `.ps2-ds34.yaml` (`scripts/configure_ds34.py:35`, `docs/BUILDING.md:99`); `iop/smb2man/usmb2/usmb2.c` is `#include`d at `iop/smb2man/smb2man.c:199`; `iop/nfsman/unfs4/unfs4.c` is `#include`d at `iop/nfsman/nfsman.c:145` |
| 10 | Helper-duplication count by script: files matching `def function`/`def extract` in `tests/*.py` | 103 of 213 test files (TEST-004) |
| 11 | Live suites | **Not run**: `tests/smb2man_live/run.sh` (needs Samba + root), `tests/smbd_live/run.sh` (needs `smbclient` + network fetch of libsmb2), `tests/nfsman_live/run.sh` (needs root + kernel NFSv4 server). Environment-blocked in this sandbox; the first two are wired in CI (`compile.yml:40-48`), the third is not wired anywhere (TEST-006) |

**Test-run summary (final, after re-runs): 214 host suites attempted — 211 PASS, 1 deterministic FAIL (`test_copy_psu_listing.py`), 2 environment-blocked (`test_dash_card_tool.py`, `test_mc_save_export.py`, both missing `libmbedtls-dev` headers that CI installs). No PS2 build was attempted (no ps2build SDK in this VM); nothing here is hardware-verified.**

---

## Coverage ledger

**Read in full:** `.github/workflows/compile.yml` (all steps, incl. publish step to end of the test-relevant sections), `download-metrics.yml`, `neutrino-watch.yml`, `ps2build-sdk-watch.yml`, `docs-pages.yml`, `sync-wiki.yml`; `ps2.yaml` (parsed in full by script + target-by-target printout); `tests/test_cloud_relay.py`, `test_pccf.py`, `test_loader_linkfile.py`, `test_own_config_name.py`, `test_dashboard_pending_loops.py`, `test_mmce_protocol.py`, `test_ftp_session.py`, `test_copy_test_pack.py`, `test_boot_deferred_init.py`, `test_usb_stat_timeout.py`, `test_rolling_release_workflow.py`, `test_transition_latency.py`, `test_selector_centering.py`; `scripts/check_ds34_build.py`, `check_toolchain_purity.py`, `check_udpfs_smap.py`, `stale_code_audit.sh`, `fetch_libsmb2.sh`, `gen_cloud_client.py` (inventory + secret-handling shape only; no values printed or recorded); `iop/pccf/ps2.yaml`, `iop/ps2ips_rpc/ps2.yaml`; `.github/ps2build-sdk.env`; `ship/kit-externals.json` (head); `loader/loader.c` lines 1–120; `.gitignore`.

**Read in part / by targeted excerpt:** `tests/test_ftp_server.py`, `test_device_input.py`, `test_r3z_config_inventory.py`, `test_ps2ips_rpc.py`, `test_kit_package.py`, `test_timer_wrap.py`, `test_mmce_restore_txn_model.py`, `test_copy_psu_listing.py` (harness lines around 178–187, 512–585); `scripts/build_jpeg.sh`, `build_cloud_tls.sh` (version lines); `tests/smbd_live/run.sh`, `tests/nfsman_live/run.sh` (in full as shell, not executed).

**Script-scanned, not read line-by-line:** the remaining ~185 `tests/test_*.py` files (executed, plus assert-count / `read_text` / helper-definition / skip-pattern scans), `tests/*.c` host harnesses and `tests/mc_fixture.py` (inventoried, executed via their Python drivers), `.github/scripts/ps2build_sdk_watch.py` + its test (executed; read via workflow + excerpts), the remaining `scripts/*.py`/`*.sh` (inventoried with sizes and cross-reference counts; executed where tests or workflows call them).

**Not read:** `scripts/package_kit.py`, `package_apps.py`, `ps2build_sdk.sh`, `check_stack_realign.py`, `release_notes.py`, `download_metrics.py`, `sync_github_wiki.py`, `gen_sfx.py`, `gen_dash_font.py` bodies in full (all were executed indirectly through their tests/workflows above, except `ps2build_sdk.sh`); `loader/loader.c` lines 121–446; `ee_libs/hdd/libhdd.c`, `ee_libs/tcpips/ps2ipc.c`, `ee_libs/iopreboot/*.c` bodies (build-graph membership and test coverage verified by grep/script only); `tests/*_live/*.c` harness bodies; `docs-site/build.py`.

---

## Candidate findings (sorted by benefit)

### TEST-001 — `test_copy_psu_listing.py` fails deterministically at HEAD (host)
- **Category:** Failing test / possible production defect
- **Benefit:** High — this is the only red suite in an otherwise green 214-suite host run; it guards PSU paste/move behaviour over UDPFS.
- **Evidence:** `tests/test_copy_psu_listing.py:557` — embedded C harness assertion `!message[0] && !nclipFiles && !exists("mc0:/SAVEDIR") && udpfs_read_opens==2 && !strcmp(udpfs_last_read,"udpfs:/SAVEDIR.psu")` fails in the *cut/move* variant (the copy variant of the same check at `tests/test_copy_psu_listing.py:523-525` passes first). Executed 4/4 times in a `/tmp` copy: exit 1, `Assertion … failed` at line 557, with ≥144 MB free disk on the confirming run.
- **Evidence type:** Executed (local, gcc 13.3 / Ubuntu 24.04 — same family as CI's `ubuntu-latest`). **INFERRED:** whether the current GitHub CI run at this HEAD is also red was not checked and cannot be claimed from local evidence.
- **Recommendation (LESS NOT MORE):** No code change proposed here. First establish which conjunct fails (open-count vs last-read path vs leftover source) in the harness, then fix the one mechanism — production paste code or the harness expectation, whichever is wrong. Do not relax the assertion to make it pass.

### TEST-002 — Two test files are orphaned: never run by any workflow
- **Category:** Orphaned tests / coverage drift
- **Benefit:** High — both are real, executable tests (one compiles and runs production code), silently providing zero protection.
- **Evidence:** Script diff of `tests/test_*.py` (213 files) against unique names in `.github/workflows/compile.yml` (211): only `tests/test_boot_deferred_init.py` and `tests/test_usb_stat_timeout.py` are absent; neither name appears in any other workflow (grep over `.github/workflows/`). Both pass when run by hand in this audit (execution log #2). `test_usb_stat_timeout.py` is an executable host test of the bounded USB stat helper extracted from `src/init.c`; `test_boot_deferred_init.py` guards the #277 deferred boot init in `src/dash_main.c`. Root mechanism: the CI list is a hand-maintained enumeration of 211 invocations in one step (`compile.yml:51-265`), so a new test file is inert until someone also edits the workflow — these two are the proof it has already drifted twice.
- **Evidence type:** Script-verified + executed.
- **Recommendation:** Add the two invocations to the existing step (2 lines). Optionally, afterwards, replace the enumeration with a directory glob — only if that is a net deletion of maintenance, not a new framework.

### TEST-003 — All 211 tests run as one sequential step: first failure masks the rest
- **Category:** CI structure
- **Benefit:** High — a single early failure (e.g. TEST-001's suite sits mid-list) prevents every later test in the step from running and gives no per-test summary, so one red test hides all other regressions in the same run.
- **Evidence:** `.github/workflows/compile.yml:50-265` — one step, "Test Settings sessions, navigation and theme compatibility", containing 211 sequential `python3 tests/…` lines under the default `bash -e` step shell; the step name also no longer describes most of its contents. The only test invoked outside this step is `tests/test_app_packages.py` (in the packaging step, after the builds).
- **Evidence type:** Read in full.
- **Recommendation:** Split the existing lines into a few grouped steps by area (no new tooling), or make the one step run all lines and report failures at the end. Either is a rearrangement of existing lines, not an addition of infrastructure.

### TEST-004 — The same C-function brace-extractor helper is copy-pasted into 103 test files
- **Category:** Duplicated test helpers
- **Benefit:** Medium-high — 103 private reimplementations (variants named `function(...)` / `extract(...)` with differing signatures) of one brace-matching extractor. A bug or improvement must be made 103 times; the variants already differ in argument order and robustness, so tests do not all extract functions the same way.
- **Evidence:** Script count: 103 of 213 files under `tests/` define `def function` or `def extract`; examples read in full or excerpt: `tests/test_boot_deferred_init.py:9`, `tests/test_copy_pipeline.py:22`, `tests/test_cloud_recovery.py:19`, `tests/test_ps2ips_rpc.py` (its own `function(name, source=server)` variant), `tests/test_mmce_restore_txn_model.py` neighbours. There is no shared test helper module anywhere under `tests/` (directory listing: no `conftest.py`, no `helpers.py`, no `__init__.py`).
- **Evidence type:** Script-counted + sampled reads.
- **Recommendation:** One small shared helper module under `tests/` and delete the per-file copies as they are touched. Net deletion of ~100 duplicated bodies; do not rewrite all 103 files in one churn commit.

### TEST-005 — Two MMCEMAN driver sources (581 lines) are compiled by nothing
- **Category:** Dead code / repo clutter
- **Benefit:** Medium-high — uncompiled sources in a driver tree invite readers (and future audits) to treat them as live code, and they still get edited/checked as if they shipped.
- **Evidence:** `iop/mmceman/src/mmcedrv.c` (413 lines, defines its own `IRX_ID("mmcedrv", …)` at line 19) and `iop/mmceman/src/mmceigr.c` (168 lines) are absent from the `mmceman` target's source list (`ps2.yaml:153-162`, 6 sources, neither file among them), are not `#include`d by any compiled source (grep over `iop/mmceman/src/*.c`, `src/*.c`, `include/*.h`: no references outside the two files themselves and the `mmcedrv_config.h` enum / `module_debug.h` `MODNAME` string), and appear in no other `*.yaml`, `*.sh`, `*.md` or `*.txt` in the repo. They are 2 of only 3 unexplained unlisted production sources in the whole `ps2.yaml` census (execution log #9).
- **Evidence type:** Script census + grep. **INFERRED:** "dead" is inferred from total absence of build/reference paths; if they are kept as reference material, that is not stated anywhere in the tree.
- **Recommendation:** Delete both files, or move them under `research/` with a one-line note if they are reference material. Less code in the live driver tree either way.

### TEST-006 — `tests/nfsman_live/` is wired into no workflow and cannot run unattended
- **Category:** Orphaned tests
- **Benefit:** Medium — the NFS client (`iop/nfsman`, a shipped target in `ps2.yaml`) has exactly one live suite, and unlike its SMB siblings it never runs, so its coverage is illusory.
- **Evidence:** `tests/nfsman_live/run.sh` requires root and a running kernel NFSv4.0 server (`exportfs`, `/proc/fs/nfsd/versions` checks at the top of the script) or a pre-existing export passed as arguments. Grep over `.github/workflows/`, `docs/`, `README.md`: no reference to `nfsman_live` at all, while `tests/smb2man_live/run.sh` and `tests/smbd_live/run.sh` are CI steps at `.github/workflows/compile.yml:40-48`. The Python-side NFS coverage (`tests/test_nfs_shares.py`, parser/wiring only) does run in CI.
- **Evidence type:** Read + grep-verified.
- **Recommendation:** Either wire it where a root NFS server is available or delete/retire the harness and let `test_nfs_shares.py` be the stated coverage. Keeping an unrunnable suite as apparent coverage is the worst of the three options.

### TEST-007 — Action pinning is inconsistent: the `contents: write` build workflow uses mutable tags, the read-mostly metrics workflow pins SHAs for exactly that reason
- **Category:** CI structure / supply chain
- **Benefit:** Medium — the repo's own stated rule is applied in the low-privilege workflow and not in the high-privilege one.
- **Evidence:** `.github/workflows/download-metrics.yml:19-20` pins `actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4` with the comment "Pinned because this job holds contents: write." `compile.yml` holds top-level `contents: write` (`compile.yml:15-16`) yet uses `actions/checkout@v4` (`compile.yml:29`), `actions/cache/restore@v4` (`:285`), `actions/cache/save@v4` (`:301`), `actions/upload-artifact@v4` (`:513`, `:523`); `docs-pages.yml:24,46`, `sync-wiki.yml` and `ps2build-sdk-watch.yml:42,57,70` likewise use `@v4` tags, several in jobs that also push or publish.
- **Evidence type:** Read in full (all six workflows).
- **Recommendation:** Apply the repo's existing pinning practice to the workflows that write/publish; no new policy needed, just use the one already written down in `download-metrics.yml`.

### TEST-008 — `scripts/stale_code_audit.sh` cannot find what it claims to scan, and is run by nothing
- **Category:** Dead / broken tooling
- **Benefit:** Medium — a "stale code audit" whose legacy-name pattern is misspelled and whose probe files are wrong gives false assurance in both directions, and it is cited as a maintenance tool in `docs/architecture-maintenance.md:72,83`.
- **Evidence:** `scripts/stale_code_audit.sh:21` and the strict-mode check at `:37` search for `LNCHELF\.CNF` (missing the `A`) — a string that occurs nowhere, so the legacy-filename scan and the strict gate can never fire on the real name. Section 3 (`:27`) probes only `src/main.c` and `src/config.c` for `LAUNCHELF\.CNF`; the actual legacy filename literal lives at `src/main_boot.c:66` (`char legacy[] = "LAUNCHELF.CNF";`), which is never probed (the `config.c` hits are comments at `src/config.c:530,880`). No workflow references the script (grep over `.github/workflows/`); it also requires `rg`, which no CI step installs.
- **Evidence type:** Read in full + grep-verified locations.
- **Recommendation:** Fix the two-character typo and the probe list, or delete the script and its doc citation. A 41-line script does not need both a report mode and a strict mode that share the same broken pattern.

### TEST-009 — Two build targets are defined twice: root `ps2.yaml` and per-module `ps2.yaml` files must be kept in sync by hand
- **Category:** Duplicated build definitions
- **Benefit:** Medium-low — `pccf` and `ps2ips_rpc` each have two independent definitions; they agree today, but nothing except one test for one of them keeps them agreeing.
- **Evidence:** `iop/pccf/ps2.yaml` (whole file, 10 lines) redefines target `pccf` also defined in root `ps2.yaml`; `iop/ps2ips_rpc/ps2.yaml` (whole file) redefines `ps2ips_rpc` likewise. CI builds both forms (`compile.yml`: `ps2build build -c iop/pccf/ps2.yaml`, `ps2build build -c iop/ps2ips_rpc/ps2.yaml`, plus the root build). `tests/test_ps2ips_rpc.py` asserts both definitions for `ps2ips_rpc` (excerpt read: isolated-file assertions); no equivalent sync assertion was found for `pccf`.
- **Evidence type:** Read in full (both isolated files) + workflow read.
- **Recommendation:** Keep the isolated builds (they are a deliberate standalone-driver check) but add `pccf` to the same sync-assertion pattern `ps2ips_rpc` already has — one small addition that removes a whole drift class, instead of a third definition-tracking mechanism.

### TEST-010 — One CI-run test tests a research model that is explicitly not the shipped code
- **Category:** Tests of private/non-production reimplementations
- **Benefit:** Medium-low — CI time and a green tick are spent on a model whose own header says it is not implemented on device, while the real MMCE restore path is covered by other suites.
- **Evidence:** `tests/test_mmce_restore_txn_model.py:1-5` (docstring: "This tests a host-only model, not existing sd2psXtd firmware and not any PS2 restore operation"); it compiles `research/sd2psxtd/mmce_restore_txn_model.c`, whose header carries `#define MMCE_TXN_IMPLEMENTED_ON_DEVICE 0` (`research/sd2psxtd/mmce_restore_txn_model.h:13`); `docs/MMCE_RESTORE_PROTOCOL.md:8` likewise states no firmware transaction exists. The model file is also the third unexplained unlisted source in the `ps2.yaml` census (execution log #9). The test **is** in the CI list, unlike TEST-002's orphans.
- **Evidence type:** Read (test head, header line, doc line).
- **Recommendation:** Keep the model and its test if the protocol work is live, but stop counting it as product coverage; if the protocol work is dormant, move both out of the per-commit CI list into an on-demand run. No new test needed either way.

### TEST-011 — Dependency version strings are duplicated between build scripts and tests, so a version bump must edit test fixtures
- **Category:** Hard-coded versions / duplication
- **Benefit:** Low-medium — two single-source-of-truth violations of the same shape; each bump touches production script + test in lockstep or CI goes red for a non-regression.
- **Evidence:** Mbed TLS: `scripts/build_cloud_tls.sh:6` `version="3.6.7"`; the string `mbedtls-3.6.7` is hard-coded four times in `tests/test_cloud_tls_paths.py:30,47,54,64` as fixture paths/expected object paths. libjpeg-turbo: `scripts/build_jpeg.sh:14` `version="3.1.3"`; `tests/test_llvm_toolchain.py:37` asserts the literal `'version="3.1.3"'` in the script. (Contrast, checked clean: the ps2build SDK pins in `.github/ps2build-sdk.env` are single-sourced and machine-checked by `.github/scripts/test_ps2build_sdk_watch.py`, which runs at `compile.yml:245`.)
- **Evidence type:** Grep-verified lines, both scripts read at the cited lines.
- **Recommendation:** Have the two tests read the version from the script they already read, instead of restating it. Deletion of duplicated literals only.

### TEST-012 — Two suites can report PASS while a named sub-check did not run
- **Category:** Skip-to-pass patterns (partial)
- **Benefit:** Low — on the current CI platform both sub-checks do run, so this is latent: on any other platform/runner the suite stays green with less coverage and only a stdout note distinguishes it.
- **Evidence:** `tests/test_ftp_server.py:44-45` — on non-x86 hosts the freestanding 32-bit formatter check prints `SKIP: freestanding x86 check is unavailable for {target}` and the suite continues to an overall pass (the remaining FTP checks do still run and can fail). `tests/test_kit_package.py:163,205` (excerpts) — the .7z/Neutrino branches execute only `if py7zr is not None or shutil.which("7z")…`; with neither present those branches are silently absent from an otherwise passing run (CI installs `p7zip-full` only inside the later kit step at `compile.yml:462-484`, not before the test step).
- **Evidence type:** Read/excerpted.
- **Recommendation:** Make the two conditional branches assert their precondition on CI-shaped runners (x86_64 + a 7z tool are both guaranteed there), keeping the graceful path for developer machines. No new machinery.

### TEST-013 — `test_transition_latency.py` validates an audio asset through a Python reimplementation of a decoder that is not in this repo
- **Category:** Tests of private reimplementations
- **Benefit:** Low — the golden-hash check is strong for the asset, but the ADPCM decode it hashes is a fresh Python implementation (`tests/test_transition_latency.py:9-21`), not the audsrv/SDK decoder the PS2 actually uses; a shared misunderstanding of the format would pass here and fail on hardware. **INFERRED** risk only — no divergence was observed; the decoded-onset and hash assertions themselves are concrete and the test passes.
- **Evidence:** `tests/test_transition_latency.py` in full; production decoding is not in this repo (no ADPCM decoder source under `src/` was found by the scope scans; SFX generation is `scripts/gen_sfx.py`, playback is via audsrv).
- **Evidence type:** Read in full; inference labelled.
- **Recommendation:** None required. If the asset is ever regenerated, re-derive the golden hash from a hardware/audsrv decode once rather than extending the Python decoder.

---

## Checked-clean notes

- **ps2.yaml graph integrity:** verified by script (execution log #9) — no missing in-repo sources, no unexplained duplicates, fetched/generated inputs (`.smbd-deps/`, `.cloud-deps/`, `.jpeg-deps/`, DS34 generated yaml) are each produced by a named script that CI runs before the build. `loader/loader.c` is the sole source of the `loader` target with `linkfile: loader/linkfile`; `ee_libs/` sources are all referenced (`iopreboot` and `hdd_ee` ee_lib targets; `ee_libs/tcpips/ps2ipc.c` in the `wLaunchELF` target).
- **No vacuous whole suites found:** of 213 Python tests, every file contains executable assertions or a compiled harness whose exit code gates the result (script scan: only 5 files lack the literal word `assert`, and all 5 — e.g. `tests/test_pccf.py`, `tests/test_ftp_session.py` — gate on `subprocess.run(..., check=True)` of a compiled C harness). Negative-test `except AssertionError: return/pass` patterns sampled (`tests/test_r3z_config_inventory.py:18-22`, `tests/test_ps2ips_rpc.py:39-45`, `tests/test_kit_package.py:27-31`) are correctly inverted (they fail if the expected rejection does *not* happen).
- **Self-referential workflow guards are real:** many tests assert their own invocation appears in `compile.yml` (e.g. `tests/test_loader_linkfile.py`, `tests/test_ps2ips_rpc.py`, `tests/test_rolling_release_workflow.py`) — which is precisely why TEST-002's two orphans, which lack such an assertion, drifted silently.
- **Kit `continue-on-error` is deliberate and compensated, not a cannot-fail step:** `compile.yml:462-503` — the three kit steps continue on error by documented design (upstream Neutrino outage must not block app packages), the publish step only attaches the kit if the file exists, and the step summary reports the kit outcome explicitly. Not counted as a finding.
- **"Report native cloud size" step** (`compile.yml:405-433`) uses `|| true` only on size/listing reporting commands; it produces no gate and claims none. Not a finding.
- **Cloud generator secret handling (inventory only):** `scripts/gen_cloud_client.py` takes its two values solely from environment variables, validates their shape, writes them only into the generated, git-ignored `.cloud-deps/include/wle_cloud_client.h`, and prints only "embedded / NOT configured". The CI step that supplies them is `compile.yml` "Embed Launchstation Google Drive client". No secret values were read, printed, or recorded in this audit.
- **Release/publish flow gates are real:** the publish step in `compile.yml` re-checks every asset for non-emptiness, refuses to publish a superseded SHA, refuses to move the `latest` tag across non-ancestor history, and creates the numbered archive release before mutating the rolling one; `tests/test_rolling_release_workflow.py` (passing) asserts this ordering, including a `bash -n` syntax check of the embedded publish script.
- **Neutrino watch's `exit 0` paths** (`neutrino-watch.yml`) are all "nothing to do / defer" outcomes of a read-only comparison job whose only action is dispatching a build; each logs its reason. Not a cannot-fail gate.
- **Licences:** settled per assignment instructions; not re-examined. No finding in this section copies or recommends copying any external fork's builds or code.

---

*Counts: 13 candidate findings (TEST-001…TEST-013). Categories — Failing/partial/reimplementation tests: TEST-001, TEST-012, TEST-013 (3); Orphaned/unwired suites: TEST-002, TEST-006 (2); CI structure & pinning: TEST-003, TEST-007 (2); Duplication & hard-coded duplication: TEST-004, TEST-009, TEST-011 (3); Dead/broken/non-production tooling: TEST-005, TEST-008, TEST-010 (3).*
