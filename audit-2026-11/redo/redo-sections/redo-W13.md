# REDO W13 — RiptOPL: second half of `.github/scripts/` + `tests/`

- Clone pin verified before any work: `git rev-parse HEAD` = `2e347d5ac885cd0ff73e9ad4143781946396f492` (matches the required pin). Clone was not modified; all test runs were executed in a copy at `/tmp/w13repo` (no `.git`).
- Scope boundary actually found in the tree: `find .github/scripts -name '*.py' | sort` returns **286** files, not 304 (62,272 lines total, which does match). The sorted second half is therefore files 144–286: **143 files, 33,302 lines**, from `.github/scripts/test_netblock_oplcore.py` to `.github/scripts/wiki_sync.py`. `tests/` is exactly 110 files, 5,999 lines, as assigned.
- Execution evidence (all in `/tmp/w13repo`, Python 3.12, host gcc/g++): all 141 test files in the second half were run individually (the 2 non-tests, `validate_site.py` and `wiki_sync.py`, are tools, not suites). **139 passed, 2 failed only because this VM has no `bs4`** (`test_site_sync.py`, `test_wiki_sync.py` — both are wired in CI with a venv that installs it, so this is a local-environment failure, not a CI failure), **1 exceeded my 90 s per-file cap** (`test_ps2build_sdk_watch.py`; the neighbouring `test_ps2build_configurations.py` alone took 59 s, so this is recorded as "slow, outcome not observed", not as a failure). `tests/host/run.sh` was also run in the copy and passed every host test. Total wall time for the 141 scripts was ~471 s in this VM.
- Important negative result: every one of the 57 unwired tests in W13-001 **passes today** when run by hand in this environment. The finding is not bit-rot that has already happened; it is that nothing in CI would notice when it does happen.

---

## W13-001 — 57 second-half test files (12,240 lines) are referenced by no workflow, and three `tests/` suites run only through them / through a runner no workflow invokes

**Category:** 7 (build/CI/repo clutter), with 8 (half-finished features) for the `tests/` suites
**Locations:**
- Unwired scripts (verified by script: every `.github/workflows/*.yml` was concatenated and each filename, plus the two glob patterns in use — `test_ripps2_*.py` and `test_ilink_*.py` — was matched against the second-half list; 57 test files matched nothing):
  `RiptOPL/.github/scripts/test_netblock_oplcore.py`, `test_neutrino_cheats.py`, `test_neutrino_pademu.py`, `test_neutrino_ra.py`, `test_neutrino_toml_repair.py`, `test_osd_defaults.py`, `test_pad_handoff.py`, `test_pccf.py`, `test_pfs_vmc_inode.py`, `test_ps1_retrogem_metadata.py`, `test_ps1_save_icons.py`, `test_ps2ips_dns.py`, `test_ps2ips_recv_tail.py`, `test_psbbn_flow.py`, `test_psu_timestamps.py`, `test_ra_badge_rows.py`, `test_ra_cards_setting.py`, `test_ra_chunk_integrity.py`, `test_ra_client_mode.py`, `test_ra_ingame_events.py`, `test_ra_language_isolation.py`, `test_ra_launch_resources.py`, `test_ra_menu_link.py`, `test_ra_module_startup.py`, `test_ra_ps1.py`, `test_ra_receive_frame.py`, `test_ra_runtime_budget.py`, `test_ra_support_check.py`, `test_ra_upstream_client.py`, `test_ra_xerabora_browser.py`, `test_ratls_host.py`, `test_retrogem_ember.py`, `test_save_icons.py`, `test_screen_pos_per_mode.py`, `test_selfupdate_host.py`, `test_sfx_oneshot_cut.py`, `test_smap_tx_base.py`, `test_smb2_menu_wait_bounds.py`, `test_smb_vmc_io_result.py`, `test_smbman_ra_write_count.py`, `test_theme_metadata.py`, `test_title_compat_defaults.py`, `test_udpbd_read_only.py`, `test_udpfs_files_oplcore.py`, `test_udpfs_languages.py`, `test_udpfs_network_hardening.py`, `test_udpfs_smap_fifo_tail.py`, `test_ulcfg_rebuild.py`, `test_vmc_contiguity.py`, `test_vmc_fatfs_images.py`, `test_vmc_pfs_reserve.py`, `test_vmc_rebuild.py`, `test_vmc_rebuild_fatfs.py`, `test_warning_gate.py`, `test_yaopl_ripps2_b125_ports.py`, `test_zso_probe_fd.py`, `test_zso_validation.py` (all under `RiptOPL/.github/scripts/`)
- Whole clusters inside that list: **15 of the RetroAchievements tests** (`test_ra_*` above; the wired RA tests are only `test_ra_disc.py`, `test_ra_mode6.py`, `test_ra_sender.py`), **7 VMC tests**, and the only drivers for three `tests/` suites:
- `RiptOPL/tests/pccf/test_ata_rw.c`, `RiptOPL/tests/pccf/test_bd.c`, `RiptOPL/tests/pccf/test_profile.c` (plus `RiptOPL/tests/pccf/stubs/*.h`) — compiled and run only by the unwired `test_pccf.py`.
- `RiptOPL/tests/ratls/host_main.c` (334 lines) — driven only by the unwired `test_ratls_host.py`. `RiptOPL/docs/CHECK-FOR-UPDATES.md:57` describes the TLS download as "Host-tested: … (`.github/scripts/test_ratls_host.py`)", i.e. the docs present it as running coverage.
- `RiptOPL/tests/smb2-live/browse.c` (258 lines), `RiptOPL/tests/smb2-live/keepalive.c` (407 lines), `RiptOPL/tests/smb2-live/readreply.c` (163 lines) — exercised only by `RiptOPL/tests/smb2-live/run.sh`, which no workflow invokes (workflows use only `tests/smb2-live/utf16.c` directly, `tests/smb2-live/launchname.c` via `test_smb_launch_name.py`, `tests/smb2-live/ingame.c` via `test_smb2_logon_parity.py`, and `tests/smb2-live/longname.c` via `tests/nfs-live/run.sh` for the NFS driver only). `run.sh:53-55` exits 2 before building anything if the PS2SDK `ps2smb.h`, `smbd`, or `timeout` is missing, and its header says it must be run as root — so even the no-server case, `readreply.c` (hand-built replies on a socketpair, `run.sh:233`), is gated behind a Samba install and an SDK checkout.

**Problem:** READ (workflow census by script; every listed file run by hand and passing in `/tmp/w13repo`). These are not stubs: several are among the largest and most thorough suites in the half (e.g. `test_smb_vmc_io_result.py` and `test_vmc_rebuild.py` at ~700/600 lines, `test_ra_ps1.py` at 593 lines, `test_ratls_host.py` driving real TLS 1.2/1.3 handshakes against local servers). Because the wired suites are enumerated file-by-file in `flavours.yml` (100+ individual `python3 .github/scripts/test_*.py` lines), any new test that nobody adds to that list is silently inert — which is evidently what happened 57 times. There is no run-all entry point for `.github/scripts` tests at all; the only glob loops in any workflow are the `test_ripps2_*.py` and `test_ilink_*.py` loops in `flavours.yml`.
**Fix in words:** Wire or delete, file by file. The cheapest wiring that cannot silently recur is one loop job in the style the repo already uses for `test_ripps2_*.py` (`for t in .github/scripts/test_*.py; do python3 "$t"; done`, minus an explicit, short exclusion list for suites with real external needs). Split `tests/smb2-live/readreply.c` (and `utf16.c`, already split) out of `run.sh` into the host CI steps, since it needs no server; leave the genuinely live Samba cases in `run.sh` but label it manual-only in its header instead of letting it read as the suite's runner. Any file the maintainer does not want in CI should be deleted rather than kept as a pass-by-inspection artefact.
**Benefit:** 12,240 lines of existing, currently-passing regression coverage start actually guarding the tree — in particular the RA launch/TLS surface and the VMC rebuild surface — and the "forgot to wire it" failure mode closes for future tests.
**Effort:** M (one loop job + exclusion list; the suites themselves already pass)
**Risk:** Med — a loop job will surface environment differences (e.g. suites needing `bs4`/`yaml`/a compiler) as red CI until the exclusion/install list is right; that is the point, but it is a visible transition.
**Confidence:** High — READ (census script + full manual run of every listed file).

---

## W13-002 — Skip-to-pass: behavioural sub-checks that exit 0 when their library/compiler is absent

**Category:** 6 (bugs/security — test validity)
**Locations:**
- `RiptOPL/.github/scripts/test_zso_validation.py:166-169` — `cc = shutil.which('gcc') or shutil.which('cc'); if cc is None: print('SKIP: no host C compiler'); return 1 if bad else 0`. The entire compiled ZSO reader harness is skipped and the script returns 0 whenever the static call-site list is clean.
- `RiptOPL/.github/scripts/test_ripps2_art_port.py:131-138` — probes for `jpeglib.h` and `from PIL import Image`; on either failure it prints `skip JPG decode: host has no libjpeg headers or Pillow` and falls through to exit 0. **Observed live in this audit's run:** this VM has Pillow but no `jpeglib.h`, and the script's output was `… libjpeg linked | skip JPG decode: host has no …` with exit code 0 — the actual JPEG decoder (baseline/progressive/grayscale/downscale/non-JPG refusal, lines 139-195) did not run. The wiring job (`flavours.yml`, migration-parity job) installs only `requirements.txt` (PyYAML) — no libjpeg headers and no Pillow — so whether CI runs this half depends on whatever the runner image happens to preinstall (INFERRED for the GitHub image; READ for this VM and for the workflow's install steps).
- `RiptOPL/.github/scripts/test_ripps2_gui_port.py:192-196` — if `pkg-config --cflags/--libs freetype2` fails, `check_weight` prints `… the glyph check is SKIPPED` and returns; the script exits 0. (In this VM pkg-config succeeded and the glyph check did run — `weight ok` — so this gate is environment-dependent, exactly the problem.)
- `RiptOPL/.github/scripts/test_neutrino_cheats.py:19-21,207-210` — `try: import tomllib except ImportError: tomllib = None`, and `toml_of()` then returns `(body, None)`; every parsed-TOML assertion is guarded by `if data is not None`, so on Python < 3.11 the "written file parses as TOML and holds the codes" check silently degrades to a text check. Lower severity than the others (CI's Python is ≥ 3.11 and the raw-text checks still run), but the same pattern.

**Problem:** READ (all four sites opened; the art-port skip reproduced). A green run of these scripts does not mean the named behaviour was tested — it means it was tested *or* the host lacked a package. Nothing in the output distinguishes the two in CI logs unless someone reads the stdout of a passing job.
**Fix in words:** Make the environment part of the job, not of the test: install the needed package in the wiring workflow step (libjpeg headers + Pillow for the art port, FreeType for the gui port — both are one apt/pip line), and change each in-test gate from "print skip, exit 0" to a hard failure when the prerequisite is missing. Delete the `tomllib = None` fallback and require Python ≥ 3.11, which CI already has. If a check is genuinely meant to be optional, it should not share a script/exit code with mandatory checks — split it out and name it optional.
**Benefit:** A green tick regains a single meaning; the JPG decoder and the FreeType weight logic — both user-visible rendering paths — cannot silently lose their only host coverage when a runner image changes.
**Effort:** S
**Risk:** Low
**Confidence:** High — READ, with the art-port skip reproduced in this audit's own run.

---

## W13-003 — Deliberately weakened assertions in the wired host tests: one literally vacuous `CHECK`, one either-way `CHECK`, and a known data defect that is counted but never asserted

**Category:** 6 (bugs/security — test validity)
**Locations:**
- `RiptOPL/tests/host/test_config.cpp:56` — `CHECK(num(a, "$Foo", -5) != 0 || true); // non-numeric string: just must not crash`. The `|| true` makes the condition true by construction; the `CHECK` can never fail. The only real coverage is "did not crash", which the ASan/UBSan build already provides without a fake assertion.
- `RiptOPL/tests/host/test_config.cpp:131` — `CHECK(num(c, "compat") == 9 || num(c, "compat") == -999); // BOM only stripped on file reads; must not crash`. Passes whether BOM handling works (9) or the key is silently lost (-999, the caller's default). Either outcome is recorded as correct, so a BOM regression — or a BOM fix — is invisible.
- `RiptOPL/tests/host/test_vmc_groups.cpp:16-17,29-30,35-36` — the test counts duplicate title IDs across memory-card groups (`duplicates++`) and non-11-char IDs (`oddShape++`), under the comment `KNOWN DATA ISSUE (reported, not asserted): some titles are listed in more than one group, which makes the later group unreachable for them`. The counts are only `printf`d. **Measured in this audit's run of `tests/host/run.sh`:** `info: 97 groups, 1034 distinct titles, 12 duplicate entries, 8 odd-shaped ids` followed by `PASS: vmc_groups`. Twelve titles are unreachable in their later group *today*, and the suite that knows it reports PASS.

**Problem:** READ (all three sites opened; the vmc_groups numbers are the test's own output from a run in `/tmp/w13repo`). These are the only three "must not crash / not asserted" weakenings in the whole in-scope tree (verified by grep over both halves of the scope), which makes them cheap to fix and hard to justify keeping: they train readers to trust a PASS line that, at these three points, asserts nothing or asserts both outcomes.
**Fix in words:** For line 56, delete the `CHECK` and keep the bare call (the crash coverage is the sanitizer's). For line 131, pick the intended BOM behaviour and assert exactly that one value. For vmc_groups, either fix the 12 duplicate / 8 odd-shaped entries in the table in `src/core/vmc_groups.cpp` and then assert `duplicates == 0 && oddShape == 0`, or — if some duplicates are intentional — assert the exact known counts so any *new* duplicate fails. Do not keep a counter that is printed and ignored.
**Benefit:** Three PASS lines start meaning something; the vmc_groups data defect stops growing silently.
**Effort:** S (assertions) / M (if the table data itself is cleaned)
**Risk:** Low
**Confidence:** High — READ + measured run output.

---

## W13-004 — Seven second-half suites compile a *rewritten* copy of the production source: `hostmap.py` monkey-patches `Path.read_text` to map `host::` calls back to pre-refactor names

**Category:** 6 (bugs/security — test validity), with 3 (overengineering)
**Locations:**
- Mechanism: `RiptOPL/.github/scripts/hostmap.py:41-55` — at import time it replaces `pathlib.Path.read_text` process-wide; for any `.cpp` file under a `src` path (except `host.cpp`) it returns the text with every `host::ui()/app()/library()` call regex-rewritten to the old direct-call name (`guiMsgBox`, `deinit`, `libViewActive`, …), with two special cases that also *insert* a `_l(...)` wrapper (`missingFileId`, `warningId`, lines 34-39).
- Second-half importers (the patch is a no-op-looking `import hostmap  # noqa: F401`): `RiptOPL/.github/scripts/test_neutrino_argv_budget.py:12`, `test_neutrino_bsdfs.py:24`, `test_neutrino_cheats.py:25`, `test_neutrino_ra.py:14`, `test_neutrino_dvr_contract.py:9`, `test_ra_disc.py:7`, `test_udpfs_themes.py:24`.

**Problem:** READ (hostmap.py read in full; all seven import sites verified). The docstring is honest — "the extracted logic is unchanged" — but that is exactly the gap: what these harnesses compile is not the production function as written. The real `host::` dispatch layer (which object, which method, the `_l()` indirection for the two ID-based calls, argument order at the real call site) is edited out before compilation and replaced with mocks of the *old* API, so a defect introduced in the `host::` layer itself, or a new `host::` method that has no entry in `HOST_TO_OLD`, is invisible to these suites (a missing entry surfaces only as a compile error against the mock, if the extracted body happens to include the call). The patch is also process-global and keyed on path parts, so any other `.cpp` read in the same process — including reads a future edit adds for data, not code — is silently rewritten too.
**Fix in words:** Retire the translation instead of extending it: give the seven harnesses mocks named after the real interface (a tiny fake `host::ui()/app()/library()` returning recording stubs, in the shape `tests/host/host_env.h` already uses for the C++ host tests) and delete the `read_text` patch. That is a one-time mock rename per harness; afterwards the extracted code is byte-for-byte the production code. Justification for the (small) addition of a mock header: it *removes* a global monkey-patch and a 37-entry translation table, and it is the same pattern the repo's own C++ host tests already use — net less mechanism, not more.
**Benefit:** Seven suites start testing the code that ships, including its call sites; a whole class of "test passed on text that no longer exists in the tree" failures disappears.
**Effort:** M
**Risk:** Med — the harnesses' mocks need the real signatures, so the first conversion will surface any place the old-name mock had drifted from the real one (which is the point, but it is work).
**Confidence:** High — READ.

---

## W13-005 — Dead pre-C++-conversion layout branches: six suites still select between the old `src/*.c` tree and the current `src/**/*.cpp` tree at runtime

**Category:** 1 (dead code), with 8 (half-finished migration)
**Locations:**
- `RiptOPL/.github/scripts/test_pad_handoff.py:18-19,106-108` — `PAD = CPP if CPP.exists() else ROOT / 'src/pad.c'`, `UNLOAD = 'PadManager::unloadOne' if CPP.exists() else 'unloadPad'`, plus two more `CPP.exists()` ternaries in the assertions.
- `RiptOPL/.github/scripts/test_ps1_duplicates.py:13` and its `if CPP: … else: …` settings-wiring branch — the `else` reads `src/opl.c` / `lng_tmpl/_base.yml`.
- `RiptOPL/.github/scripts/test_screen_pos_per_mode.py:25-31` — `cpp = (root / 'src/app/opl.cpp').exists()` selecting among `src/app/opl.cpp`/`src/opl.c`, `src/core/settings.cpp`/`src/opl.c`, `src/app/settingsio.cpp`/`src/opl.c`, `src/ui/guisettings.cpp`/`src/gui.c`, `lng/tmpl/_base.yml`/`lng_tmpl/_base.yml`.
- `RiptOPL/.github/scripts/test_ripps2_boot_video_mode.py:22` plus the `CONFIG = … if cpp else …` / `ACCESS = 'cfg.name' if cpp else 'cfg.filename'` branches — the `else` harness is a different (C-struct) definition of `config_set_t`.
- `RiptOPL/.github/scripts/test_ripps2_vmc_saves.py:29,313-315,454` — `src/vmcsaves.c` if it exists else `src/core/vmcsaves.cpp`; compiler, `-x` flag and `-std` all branch on the suffix; `src/guigame.c` vs `src/ui/guigame.cpp` at line 454.
- `RiptOPL/.github/scripts/test_udpbd_read_only.py:18,25-44` — `src()` returns the first existing of each pair (`src/sources/bdmdevices.cpp` / `src/bdmsupport.c`, `src/ui/guigame.cpp` / `src/guigame.c`, …), so every call site carries a dead second path.
- `RiptOPL/.github/scripts/test_zso_validation.py:22,145-146` — `CPP = (ROOT / 'src/platform/util.cpp').exists()` selecting the call-site file list.

**Problem:** READ, and the dead side verified absent at the pin: `src/pad.c`, `src/opl.c`, `src/bdmsupport.c`, `src/guigame.c`, `src/menusys.c`, `src/supportbase.c`, `src/vmcsaves.c`, `src/cuesupport.c` and `lng_tmpl/_base.yml` do not exist in the tree; `src/core/pad.cpp`, `src/app/opl.cpp` and `src/platform/util.cpp` do. Every `else` branch is therefore unreachable, and has been since the C→C++ conversion these tests were ported across. The cost is not just clutter: in `test_udpbd_read_only.py` the fallback is *first-existing wins*, so if a current file is ever renamed, the suite silently starts reading a different file instead of failing at the missing path; in `test_ripps2_boot_video_mode.py` the dead branch carries a whole second harness prelude.
**Fix in words:** Delete the selection logic and name the current path unconditionally in all six files (and let a missing file fail loudly, which is what a regression test should do). No replacement mechanism.
**Benefit:** Six suites shrink, their failure messages point at the real file, and a rename can no longer be masked by a fallback.
**Effort:** S
**Risk:** Low
**Confidence:** High — READ + existence check at the pinned HEAD.

---

## W13-006 — The function-extraction / host-compile harness is re-implemented in 76 second-half files, with divergent semantics

**Category:** 2 (duplication)
**Locations:** (mechanism census by script over the second half)
- 76 of 143 files define their own top-level extractor (`def function(`, `function_text(`, `extract(`, `extract_function(`, `c_function(`, `driver_function(`, `function_body(`), e.g. `RiptOPL/.github/scripts/test_neutrino_args_editor.py:10-14`, `test_pccf.py:20-23`, `test_psbbn_flow.py:27-29`, `test_smb2_logon_parity.py:88-93`, `test_ra_chunk_integrity.py:11-13`. Extractor-shaped top-level definitions total **640 lines across 83 files** (AST-measured).
- The extractors do not agree: 28 second-half files slice at the first `"\n}"` (e.g. `test_sfx_oneshot_cut.py:14-15`, `test_ra_support_check.py:15-17`), others brace-count (`test_ps1_duplicates.py:19-27`, `test_pad_handoff.py:27-35`), others regex for the signature first (`test_neutrino_args_editor.py:11`). A function whose body contains a column-0 `}` in a string, a macro, or a raw literal is sliced differently depending on which suite extracts it.
- 33 second-half files also re-implement the same `failures = []` + `check()/append` + summary-exit scaffold.
- Worst pairwise duplication (line-set similarity, script-measured, lines > 25 chars): `RiptOPL/.github/scripts/test_pad_missed_read.py` ↔ `test_pad_mode_lock.py` share 84 long lines (51% of the smaller file — the whole libpad stub, extractor and compile driver are copied); `test_smb_vmc_io_result.py` ↔ `test_smbman_ra_write_count.py` share 78 long lines (38%).

**Problem:** READ (census + AST count by script; the named files opened). Each suite's extractor is a private dialect, so a fix to extraction (e.g. handling a new C++ construct) must be made dozens of times, and two suites can extract different text for the same production function and both pass. This is the one place in the scope where the LESS rule's sharing test is clearly met: the same logic exists in 76 places, and one shared implementation is strictly less code than 76 copies.
**Fix in words:** Extract exactly one shared helper module in `.github/scripts` (the directory already shares modules this way — `hostmap.py`, and the `tools/` imports in the release tests) providing `read_source`, `function_body` (brace-counting version only) and `compile_and_run`, and delete the per-file copies as each suite is touched. Do not build a framework: three functions, no configuration. Suites whose extractor intentionally differs (e.g. `--ref` handling in `test_pad_missed_read.py`) keep that difference locally on top of the shared primitive.
**Justification (addition):** One ~80-line module replacing ~640 lines of extractor definitions plus 33 scaffolds is a large net deletion; it is justified by the concrete, measured duplication above, not by future-proofing.
**Benefit:** One extraction semantics for the whole suite; a production function that defeats extraction fails everywhere consistently instead of passing in the suites with the weaker slicer.
**Effort:** L (mechanical, but 76 files)
**Risk:** Med — mass-editing test files can itself break suites; do it suite-by-suite with a run after each, which the current per-file runnability makes cheap.
**Confidence:** High — READ (counts are script/AST outputs, not estimates).

---

## W13-007 — Whitespace-exact source-text assertions are the *only* coverage for several behavioural claims

**Category:** 6 (bugs/security — test validity)
**Locations:**
- `RiptOPL/.github/scripts/test_ra_support_check.py` (whole file, 42 lines) — asserts substrings and index ordering inside `menuCheckSelectedGameSupportLocked`, `menuInitVcdMenu` and `Ranet::askPc`; compiles nothing. (Also unwired — W13-001.)
- `RiptOPL/.github/scripts/test_sfx_oneshot_cut.py:14-27` — slices `SoundEffects::play` by regex and asserts the branch text; compiles nothing.
- `RiptOPL/.github/scripts/test_smap_tx_base.py:28-51` — regex-checks that each SMAP driver's TX-descriptor assignment spells `+ SMAP_TX_BASE`; compiles nothing.
- `RiptOPL/.github/scripts/test_udpfs_network_hardening.py` (whole file, 79 lines) — DEV9 gating and the IP-conflict notice are checked purely as substring presence/ordering, including exact-whitespace strings such as `"sysShutdownDev9();\n        return;"`.
- `RiptOPL/.github/scripts/test_yaopl_ripps2_b125_ports.py` (whole file, 69 lines) — five unrelated ports checked as substring presence, several with embedded newlines/indentation.
- `RiptOPL/.github/scripts/test_title_compat_defaults.py:44-66` — the per-core *routing* half is exact-string matching (e.g. `'if (sourceMode == UDPFS_MODE || bdmSupportIsUDPBD(support) || bdmModeIsUDPBD(sourceMode))\n        return coreChoice != 0;'`); the data-table half of the same file (lines 15-32, parsing the real table and comparing every entry) is a genuine check and is not part of this finding.

**Problem:** READ (each file opened in full). These tests fail on a clang-format reflow, a variable rename, or an equivalent refactor, and pass on a semantic regression that keeps the spelled-out text (a condition moved to a helper, a guard made unreachable, a call added after the checked one). They are also the only coverage for their claims — there is no companion compiled harness for the RA support-check routing, the SMAP TX-base rule, or the DEV9 gating order. (Contrast, in the same half: `test_smb1_vmc_share.py` is also text-based but *mutation-checks itself* — it rewrites the guards and requires its own predicate to fail — and the majority of the half compiles the real function and runs it. The finding is only about the unguarded pure-text set above.)
**Fix in words:** For each listed claim, either (a) promote it to the compiled-harness pattern the neighbouring suites already use — extract the function and run the case — or (b) if the claim is genuinely just "this call exists in this file", keep one substring check per claim, stripped of embedded whitespace/newlines, and drop the ordering chains that duplicate what a compiled test should prove. Delete the exact-whitespace variants either way.
**Benefit:** Reformatting stops breaking tests, and semantic regressions stop passing them.
**Effort:** M
**Risk:** Low
**Confidence:** High — READ.

---

## W13-008 — The `udpfs-host-tests` CI job runs two PyYAML-importing suites but never installs PyYAML

**Category:** 7 (build/CI)
**Locations:**
- `RiptOPL/.github/scripts/test_udpfs_transport.py:8` — `import yaml` (top level; the suite cannot start without it).
- `RiptOPL/.github/scripts/test_udpfs_shared_transport.py:3` — `import yaml`.
- `RiptOPL/.github/workflows/flavours.yml:320-339` — the `udpfs-host-tests` job that runs both files has no `pip install` step at all (checkout, then the test commands). The jobs that do install it are different jobs: the migration job installs the repo-root `requirements.txt` (`PyYAML==6.0.3`), and the site/wiki job installs into throwaway venvs. Jobs do not share environments.
- Same exposure, currently dormant because the file is unwired (W13-001): `RiptOPL/.github/scripts/test_ra_language_isolation.py:9` — `import yaml`.

**Problem:** READ (workflow job read in full; imports verified). The suites pass in CI today only because the `ubuntu-24.04` runner image happens to ship a PyYAML the workflow never asked for (INFERRED — the workflow itself provides no other source for the module; locally, this VM's system Python has PyYAML 6.0.1 and both suites pass). If the runner image drops it, two networking suites go red for an unrelated reason — or, worse, someone "fixes" it by skipping them (the W13-002 pattern).
**Fix in words:** Add the same one line the migration job already uses (`python3 -m pip install -r requirements.txt`) to the `udpfs-host-tests` job. Nothing else.
**Benefit:** The job's dependencies are the ones it declares; a runner-image change cannot silently change what is tested.
**Effort:** S
**Risk:** Low
**Confidence:** High for the missing install step (READ); Med for the claim that the runner image is the current source of PyYAML (INFERRED).

---

## W13-009 — `test_config.cpp` pins a lossy libconfig round-trip as correct behaviour, labelled only "characterisation"

**Category:** 8 (half-finished/redundant features)
**Locations:**
- `RiptOPL/tests/host/test_config.cpp:2-4` — header: these are "Characterisation tests … These pin the behaviour the planned Settings/ConfigSet rewrite must keep".
- `RiptOPL/tests/host/test_config.cpp:102-107` — a wOPL/libconfig file containing `gsm : { x = 1; y = "two"; }` is read into flat keys `gsm_x`/`gsm_y`, and the test asserts the file is written back with `gsm_x = 1;` *flat*, commenting: "members of a group named gsm/cheat/pademu/padmacro/osd are read as `<group>_<key>`; an unknown member like gsm_x is written back flat, only the known per-game keys regroup."

**Problem:** INFERRED from READ code. The in-memory round-trip is lossless (the test re-reads the written file and gets the same keys), so this is not a proven data-loss bug. What is pinned is an on-disk *shape change*: a grouped libconfig section comes back ungrouped for any member that is not in the known per-game key list. If any external reader of these shared files (the header says the files are "shared with wOPL/OPL-Launcher") depends on the grouping, the rewrite silently changes the file it produces — and the test suite now *requires* that behaviour, so a future fix would have to fight the test. A characterisation pin is the right tool during a rewrite; kept indefinitely, it becomes the specification.
**Fix in words:** Decide, in the planned Settings/ConfigSet rewrite the header already names, whether flat write-back is the intended format. If yes, rename the comment from "CHARACTERISATION" to a statement of intended behaviour so future readers know it is a decision. If no, fix the writer to regroup and flip this one assertion. Do not add machinery either way.
**Benefit:** A pinned accident stops masquerading as a pinned decision (or vice versa).
**Effort:** S
**Risk:** Low
**Confidence:** Low — the code and comment are READ; whether the shape change harms any external reader is INFERRED and not verifiable from this scope (no wOPL/OPL-Launcher source in the clone).

---

## COVERAGE

### Method
- Every in-scope file was machine-read in full by census/analysis scripts (line counts, import census, workflow-reference census, extractor/AST census, skip-pattern and vacuous-pattern greps, line-similarity) — no count in this section comes from an estimate.
- Every file cited in a finding was additionally opened and read directly, and every cited line range was verified against the open file before filing.
- Every second-half test was executed (see the execution note at the top), and `tests/host/run.sh` was executed; both in `/tmp/w13repo`, never in the clone.

### `.github/scripts/` second half — 143 files, 33,302 lines
Sorted positions 144–286 of `find .github/scripts -name '*.py' | sort`, from `test_netblock_oplcore.py` to `wiki_sync.py`. All 143 were read (machine census) and all 141 tests among them were run; the 2 non-tests are `validate_site.py` (40 lines, a manual local check documented at `docs/MAINTAINING-DOCS.md:52` — read in full) and `wiki_sync.py` (700 lines, the production wiki builder — read in full; its test `test_wiki_sync.py` is wired in CI with a docs venv and failed locally only for the missing `bs4`).

Files read in full directly (in addition to the census and the run): `test_netblock_oplcore.py` (partial), `test_neutrino_args_editor.py`, `test_neutrino_cheats.py`, `test_orbit_neutrino_watch.py` (partial), `test_package_orbit_neutrino.py` (partial), `test_pad_handoff.py` (partial), `test_pad_missed_read.py` (partial), `test_pccf.py`, `test_ps1_duplicates.py`, `test_ps2build_configurations.py` (partial), `test_ps2build_sdk_watch.py` (partial), `test_psbbn_flow.py` (partial), `test_ra_chunk_integrity.py`, `test_ra_support_check.py`, `test_ra_upstream_client.py`, `test_ratls_host.py` (partial), `test_release_publication.py` (partial), `test_ripps2_art_port.py` (partial), `test_ripps2_boot_video_mode.py` (partial), `test_ripps2_gui_port.py` (partial), `test_screen_pos_per_mode.py` (partial), `test_selfupdate_host.py` (partial), `test_sfx_oneshot_cut.py`, `test_smap_tx_base.py`, `test_smb1_vmc_share.py`, `test_smb2_auth.py` (partial), `test_smb2_logon_parity.py` (partial), `test_title_compat_defaults.py`, `test_udpbd_read_only.py` (partial), `test_udpfs_network_hardening.py`, `test_udpfs_shared_transport.py`, `test_udpfs_transport.py`, `test_vcd_doc_ilink_hash.py`, `test_warning_gate.py`, `test_yaopl_ripps2_b125_ports.py`, `test_zso_validation.py` (partial), `validate_site.py`, `wiki_sync.py` (partial: lines 1–120 and 580–700 plus test list). The remaining second-half files were read by the census scripts and executed, but not opened line-by-line individually; they are listed here as a group rather than claimed as deep-read: all other `test_*.py` files in positions 144–286 not named above (the full sorted list is reproducible from the command at the top of this section).

Supporting files read outside the scope proper, only to establish wiring/coverage facts: `.github/workflows/flavours.yml` (all jobs), the workflow-name census over all `.github/workflows/*.yml`, `requirements.txt`, `.github/requirements-docs.txt`, `.github/scripts/hostmap.py` (first-half file; read because seven in-scope suites import it — W13-004), `docs/MAINTAINING-DOCS.md:30-75`, `docs/CHECK-FOR-UPDATES.md:57` (single line, via grep).

### `tests/` — 110 files, 5,999 lines
All 110 were read (machine census; every `.c`/`.cpp`/`.h`/`.inc`/`.py`/`.sh` file's content passed through the analysis scripts).
Read in full or in large part directly:
- `tests/host/`: `check.h`, `run.sh`, `host_env.h`, `lib_config_host.cpp`, `gen_settings_globals.py`, `test_atlas.cpp` (head), `test_bdmtyped.cpp` (head), `test_config.cpp`, `test_grid.cpp` (head), `test_igrmenu.cpp` (partial), `test_ps1art.cpp` (head), `test_ps2cnf.cpp` (head), `test_raii.cpp` (partial), `test_settings.cpp` (head), `test_tar.cpp` (head), `test_themeviews.cpp` (head), `test_vmc_groups.cpp`, `test_wallpaper.cpp` (head), plus the stub trees `stub/`, `stub/include/`, `sdk_stub/` (listed and sampled; most `sdk_stub/*.h` are 13-byte `#pragma once` files — verified by size and by reading `kernel.h`/`tamtypes.h`).
- `tests/pccf/`: `test_bd.c` (head), `test_ata_rw.c` / `test_profile.c` (census + executed via `test_pccf.py`), `stubs/*.h` (census).
- `tests/ratls/`: `host_main.c` (head + census; executed via `test_ratls_host.py`, which passed).
- `tests/smb2-live/`: `run.sh`, `longname.sh` (via grep/read of its case list), `browse.c` (head), `keepalive.c` (head), `readreply.c` (head), `longname.c` (head), `ingame.c` (head), `launchname.c` (census; executed via `test_smb_launch_name.py`), `utf16.c` (head; executed via the workflow-identical compile in the logon/launch suites), and the `inc-browse/`, `inc-device/`, `inc-ingame/`, `inc-sdk/` stub headers (listed, sized, and duplicate-checked).
- `tests/nfs-live/`: `run.sh`, `ingame.c` (head).

### In-scope files NOT read line-by-line, with reason
- The second-half `test_*.py` files not named in the "read in full" list above: read in full by script (every line passed the pattern/census analysis) and executed with results recorded, but not individually opened. Reason: 143 files / 33,302 lines; the audit's per-file questions (wired? compiles real code? skips? vacuous? duplicates an extractor?) are all answerable from the scripted census + run, and every file that any of those checks flagged *was* then opened directly. No file was neither censused nor run.
- `tests/host/settings_golden_defaults.inc` and `settings_golden_keys.inc` (108 lines each): censused and executed (via `test_settings.cpp`), not opened line-by-line; they are golden data tables, and no finding concerns their contents.
- `tests/smb2-live/run.sh`'s Samba configuration body (lines ~120–150): read partially; the gating lines (53–55), build lines and case list were read in full, which is what W13-001 cites.
- Not run, by design: `tests/smb2-live/run.sh` and `tests/nfs-live/run.sh` as live suites (they need Samba/root/a PS2-Servers checkout and an SDK `ps2smb.h` that this VM does not provide — `run.sh` would exit 2 at line 53–55; the NFS variant *is* wired in CI and was not reproduced locally for the same external-checkout reason). Their harnesses' host-only parts were covered through the Python suites named above.
