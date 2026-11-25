# Round 8 — Section 09: RiptOPL test corpus, batch 09

- Repo: NathanNeurotic/RiptOPL, clone `~/workspace/audit-clones-2026-11-13/RiptOPL`, pin `2e347d5ac885` (verified, not updated; `git status` clean at start and end).
- Batch: `round8-sections/batch-09.txt` — 70 files, 6,784 lines, all under `.github/scripts/`. Every file line-read in full, in batch order (largest first).
- Running-environment facts used below (READ): `tools/run_tests.sh:7-9` runs every `.github/scripts/test_*.py` by exit code; `.github/workflows/ps2build.yml:70-71` runs `tools/run_tests.sh -k` in the host-tests step; `.github/workflows/flavours.yml:25` installs `requirements.txt` (sole content `PyYAML==6.0.3`) and names many batch files individually. No `continue-on-error` / `|| true` masks any batch test step in either workflow (flavours.yml:460-487 `|| true`/`continue-on-error` cover only the build-manifest diagnostic and the artifact upload).
- Prior-findings boundary honoured: nothing below re-files RIPTOPL-286…291 mechanisms or RIPTOPL-005's corpus characterisation. Where a batch file touches the RIPTOPL-286 PSU axis, see the dissolved list.

## (a) Per-file ledger

| path | lines | verdict |
|---|---|---|
| .github/scripts/test_smstcpip_recv_notification_order.py | 146 | clean |
| .github/scripts/test_dvr_scan_lifecycle.py | 144 | clean |
| .github/scripts/test_network_parity_922.py | 144 | finding |
| .github/scripts/test_neutrino_pademu.py | 142 | clean |
| .github/scripts/test_mbedtls_vendor.py | 140 | finding |
| .github/scripts/test_pr894_hardening.py | 131 | clean |
| .github/scripts/test_ra_client_mode.py | 131 | clean |
| .github/scripts/test_keyboard_keycaps.py | 130 | finding |
| .github/scripts/test_accurate_read_rate.py | 129 | clean |
| .github/scripts/test_orbit_neutrino_watch.py | 129 | clean |
| .github/scripts/test_ul_scan_integrity.py | 128 | finding |
| .github/scripts/test_cdvdman_own_stack.py | 127 | clean |
| .github/scripts/test_console_ilink_id.py | 127 | finding |
| .github/scripts/test_ds34usb_report_transfer.py | 126 | finding |
| .github/scripts/test_language_discovery.py | 126 | clean |
| .github/scripts/test_udpfs_serialization.py | 126 | finding |
| .github/scripts/test_io_menu_lifetime.py | 123 | clean |
| .github/scripts/test_vmc_contiguous_create.py | 123 | clean |
| .github/scripts/test_ps1_duplicates.py | 122 | finding |
| .github/scripts/test_ra_chunk_integrity.py | 121 | finding |
| .github/scripts/test_smb1_vmc_share.py | 119 | finding |
| .github/scripts/test_bdmfs_frag_walk.py | 117 | clean |
| .github/scripts/test_info_size_ps1.py | 114 | clean |
| .github/scripts/test_config_prefetch_generation.py | 112 | clean |
| .github/scripts/test_cheat_capacity.py | 109 | finding |
| .github/scripts/test_pfs_vmc_inode.py | 109 | clean |
| .github/scripts/test_foreground_settings_config.py | 108 | clean |
| .github/scripts/test_reset_arg_bounds.py | 108 | clean |
| .github/scripts/test_bdma_stale_pair.py | 107 | clean |
| .github/scripts/test_net_recv_poll.py | 106 | clean |
| .github/scripts/test_custom_font_load.py | 101 | clean |
| .github/scripts/test_boot_theme_wait.py | 96 | finding |
| .github/scripts/test_package_orbit_neutrino.py | 96 | clean |
| .github/scripts/test_menu_crash_catcher.py | 93 | finding |
| .github/scripts/test_ra_receive_frame.py | 92 | clean |
| .github/scripts/test_build_driver.py | 91 | finding |
| .github/scripts/test_game_size_fallback.py | 91 | finding |
| .github/scripts/test_config_null_allocation.py | 89 | clean |
| .github/scripts/test_pad_hook_cache.py | 89 | finding |
| .github/scripts/test_theme_render_queue.py | 88 | clean |
| .github/scripts/test_cache_allocation.py | 87 | clean |
| .github/scripts/test_mmce_igr_strings.py | 86 | finding |
| .github/scripts/test_vmc_contiguity.py | 85 | clean |
| .github/scripts/test_igr_usb_host_stop.py | 84 | clean |
| .github/scripts/test_language_switch.py | 82 | clean |
| .github/scripts/test_ps2_logo_validation.py | 80 | clean |
| .github/scripts/test_udpfs_network_hardening.py | 79 | finding |
| .github/scripts/test_disc_key_semaphore.py | 78 | finding |
| .github/scripts/test_genvmc_recovery.py | 78 | finding |
| .github/scripts/test_ripps2_text_port.py | 78 | clean |
| .github/scripts/test_bdm_transport_binding.py | 77 | clean |
| .github/scripts/test_ra_ingame_events.py | 75 | clean |
| .github/scripts/test_igr_power_button.py | 74 | clean |
| .github/scripts/test_language_page.py | 74 | clean |
| .github/scripts/test_font_fit_bounds.py | 73 | finding |
| .github/scripts/test_bdm_empty_literal_slot.py | 72 | clean |
| .github/scripts/test_smstcpip_socket_bounds.py | 72 | clean |
| .github/scripts/test_psu_timestamps.py | 69 | clean |
| .github/scripts/test_ra_upstream_client.py | 69 | clean |
| .github/scripts/test_yaopl_ripps2_b125_ports.py | 69 | finding |
| .github/scripts/test_title_compat_defaults.py | 66 | clean |
| .github/scripts/test_zso_probe_fd.py | 64 | finding |
| .github/scripts/test_history_filename_bounds.py | 63 | finding |
| .github/scripts/test_neutrino_args_editor.py | 61 | clean |
| .github/scripts/test_page_animation.py | 59 | finding |
| .github/scripts/test_ra_cards_setting.py | 59 | clean |
| .github/scripts/test_ps2ips_dns.py | 57 | clean |
| .github/scripts/test_autoload_discovery_settles.py | 55 | clean |
| .github/scripts/test_ra_mode6.py | 55 | clean |
| .github/scripts/test_udpfs_shared_transport.py | 54 | clean |

## (b) Candidate findings (unnumbered)

### The keyboard test's exhaustive bold-offset loop tests its own Python copy, not the production function

- Category: 6 (bugs/security — test cannot catch the regression it claims to exhaustively verify)
- Locations: RiptOPL/.github/scripts/test_keyboard_keycaps.py:63-83; production RiptOPL/src/ui/diaeditors.cpp:74-88
- Problem: READ. The production step is checked only by string-matching its `while` condition (test lines 63-65: the extracted `diaBoldStep` body must contain `while (step < 8 && scale(at + step) == scale(at))`). The exhaustive sweep that follows (lines 70-83, ~2.3M combinations of position/display/virtual size) runs `bold_offset()`, a Python function defined inside the test itself (lines 70-75) with its own `scale = lambda v: v * display // virtual`. Production `diaBoldStep` (diaeditors.cpp:74-80) is never extracted or executed, and the production scale functions (`rmScaleX`/`rmScaleY`, used at diaeditors.cpp:84) are never read. A production change to the step's initial value, increment, cap, or return value — or a renderman scale that is not `v * display // virtual` — leaves every assertion in this file green while the property the sweep "proves" no longer holds on the console. The corpus already contains the correct pattern: test_cdvdman_own_stack.py:116-120 mutates the production text and requires its checker to reject the mutant.
- Fix in words: Extract the real `diaBoldStep` (and the real `rmScaleX`/`rmScaleY` bodies) into the compiled-harness style the rest of the corpus uses and run the sweep against them; or, at minimum, add a mutation check in the cdvdman style (a `step`-starting-at-0 / return-`step+1` mutant must fail). Delete the Python reimplementation once the real function is under test.
- Justification if the fix adds anything: It adds an extraction harness of the kind ~50 sibling files already carry; net test code shrinks when the Python model is deleted.
- Benefit: The one exhaustive (million-case) check in the file starts covering the code that ships.
- Effort: M
- Risk: Low
- Confidence: High (READ — both sides read in full)

### test_mbedtls_vendor swallows ValueError for whole edition/configuration combinations, uncounted

- Category: 6 (bugs/security — swallowed exception around the assertions)
- Locations: RiptOPL/.github/scripts/test_mbedtls_vendor.py:50-56 (assertions it gates: 59-92)
- Problem: READ. For every edition × configuration × toolchain combination, the test calls `build_edition.definition(...)` inside `try:` and does `except ValueError: continue` (lines 52-55), on the stated assumption that any ValueError is "a combination build_configuration.py refuses". Nothing records which combinations were exercised or which were refused, and no later assertion calls `definition()` again (the post-loop checks at lines 94-105 call only `update_channel()`). If `definition()` began raising ValueError for a combination that is valid today — e.g. an RA or llvm combination — every mbedTLS/ratls/updater wiring assertion for that combination (lines 59-92) would silently stop running and the file would still print PASS. The set of legitimately refused combinations is itself behaviour worth pinning and is currently pinned nowhere in the file.
- Fix in words: Pin the expected valid/refused combination set explicitly (or count exercised combinations and assert the count, and assert the known-valid RA/llvm/standard combinations were among them), so a new ValueError on a previously valid combination fails the test.
- Justification if the fix adds anything: Adds a small expected-set literal; removes an unbounded silent-skip.
- Benefit: A build-definition regression cannot masquerade as a legitimate refusal and strip TLS wiring coverage unnoticed.
- Effort: S
- Risk: Low
- Confidence: High (READ)

### Assertions inside possibly-empty iteration, with no count guard, in two tests

- Category: 6 (bugs/security — checks that report as pass when their subject disappears)
- Locations: RiptOPL/.github/scripts/test_mmce_igr_strings.py:71-75; RiptOPL/.github/scripts/test_ds34usb_report_transfer.py:109-111
- Problem: READ, both instances verified non-vacuous today but structurally unguarded. (1) test_mmce_igr_strings.py:71-75 runs the real lang-compiler pipeline for Russian/German/Japanese/Spanish only `if lang in words:` — `words` is built at lines 55-64 solely from overlay files that exist in `lng/fork/`. All four overlays exist at the pin (verified: `lng/fork/{Russian,German,Japanese,Spanish}.yml`), so the checks run today; but deleting or renaming one overlay removes its compiled-pipeline check silently — the per-file loop at 56-64 only iterates files present, and the final PASS line (81) merely prints a smaller overlay count. (2) test_ds34usb_report_transfer.py:109-111 asserts `data_result` gating for every `readReport(data_buf[port], port);` match found by `re.finditer` in `ds34usb_get_data`, with no assertion that any match exists. Verified the production body contains exactly two such calls today (modules/pademu/ds34usb.c:488,504, inside `ds34usb_get_data` at :479). If the call is renamed or restructured, the loop body never runs and that sub-check passes vacuously while the rest of the test stays green. The corpus knows the guard pattern: the same ds34 file asserts `checked > 10` after its CancelAlarm census (line 70), and test_yaopl_ripps2_b125_ports.py:28 asserts its findall result is non-empty before iterating.
- Fix in words: In (1), require the four named languages to be present (`assert lang in words` / record a failure when absent) before compiling them. In (2), materialise the finditer matches and assert the expected count (2) before the per-call assertions.
- Justification if the fix adds anything: One guard line each; nothing new is tested, the existing tests are made non-optional.
- Benefit: Deleting an overlay or renaming a call site fails the suite instead of quietly shrinking it.
- Effort: S
- Risk: Low
- Confidence: High (READ; present-day counts verified against production)

### test_udpfs_network_hardening largely re-asserts, at string level, what test_network_parity_922 already proves by compiling

- Category: 2 (duplication)
- Locations: RiptOPL/.github/scripts/test_udpfs_network_hardening.py:34-75; RiptOPL/.github/scripts/test_network_parity_922.py:59-143
- Problem: READ. The two files assert the same production facts twice. DEV9: hardening:36-38 (int result + header declaration) vs parity:88 plus the compiled DEV9 retry/refcount exercise at parity:59-87. UDPFS loader gate: hardening:42-44 vs parity:90-92 — the identical strings (`if (!sysInitDev9())` ordered before the SMAP IRX, and `sysShutdownDev9();\n        return;`). IP conflict: hardening:62-75 vs parity:134-143 plus the compiled notice lifecycle at parity:99-132 — same devctl value `0x55460001` in both modules, same `imports.lst` presence/absence checks, same `DECLARE_IMPORT(7, arp_ip_conflict)`, same `menuUpdateHook` call-site assertion. BDM chain: hardening:53-59 and parity:93-97 check DEV9-first ordering for overlapping (not identical) entry points — production carries both names (verified: `BdmSupport::ensureNetworkSourceModules` at bdmsupport.cpp:751 and the `bdmEnsureNetworkSourceModules` wrapper at :828). Genuinely unique to hardening: the `udpfsNicClaimed` retention checks (45-47), the `udpbdNicClaimed` partial-chain check (51-52), the ministack `exports.tab` DECLARE_EXPORT check (67-69), and the "notice shown once" `udpfsIpConflictWarned` check (74). Everything else in the 79-line file is a weaker, string-only second copy of a compiled test's assertions, so any production rename must be updated in two places and the two copies can drift into asserting different spellings of the same fact.
- Fix in words: Move hardening's four unique checks into test_network_parity_922.py and delete test_udpfs_network_hardening.py.
- Justification if the fix adds anything: Nothing added; a net deletion of roughly 60 duplicated lines against ~10 moved ones.
- Benefit: One home for the DEV9/IP-conflict contract; no drift between a compiled proof and its string-level shadow.
- Effort: M
- Risk: Low
- Confidence: High (READ — both files and both production entry points verified)

### Boot-theme splash assertions duplicated between test_yaopl_ripps2_b125_ports and test_boot_theme_wait

- Category: 2 (duplication)
- Locations: RiptOPL/.github/scripts/test_yaopl_ripps2_b125_ports.py:56-61; RiptOPL/.github/scripts/test_boot_theme_wait.py:29-55
- Problem: READ. Item 5 of the yaopl ports file re-asserts the subject of the dedicated boot-theme test: `THEME_HOLD_MAX_S 10` and `themeHoldMs() > 0` in guisplash.cpp (yaopl:57-58) and the bounded-hold clock expression (yaopl:61) are the same facts test_boot_theme_wait.py checks more strongly — it compiles the real `themeHoldMs()` (boot_theme_wait:29-31,57-91), regex-pins the full hold condition including `thmSavedThemePending()` (35-38), and pins the setting's default, clamp, and dialog wiring (39-55). Unique to the yaopl copy: the hold running `gGui.runFrameHook()` (yaopl:59-60) and the `thmSavedThemePending` built-in-name internals (yaopl:62-67). The duplicated lines (57-58,61) are pure string checks that must be maintained in both files whenever the splash code is reworded.
- Fix in words: Drop the duplicated splash assertions from the yaopl ports file, keeping its two unique checks (frame-hook line, `thmSavedThemePending` internals) — or move those two into test_boot_theme_wait.py and drop item 5 from the ports file entirely.
- Justification if the fix adds anything: Nothing added; small net deletion.
- Benefit: The boot-hold contract lives in the file that actually compiles the function it governs.
- Effort: S
- Risk: Low
- Confidence: High (READ)

### Dead C-layout fallback branches in nine ported tests reference files that do not exist at the pin

- Category: 1 (dead code)
- Locations: RiptOPL/.github/scripts/test_console_ilink_id.py:8,10; RiptOPL/.github/scripts/test_ps1_duplicates.py:13,105-111; RiptOPL/.github/scripts/test_cheat_capacity.py:13-14 (knock-on branches at 103,106); RiptOPL/.github/scripts/test_menu_crash_catcher.py:13-14,62,87-91; RiptOPL/.github/scripts/test_game_size_fallback.py:13-16; RiptOPL/.github/scripts/test_mmce_igr_strings.py:17-20; RiptOPL/.github/scripts/test_font_fit_bounds.py:8,70; RiptOPL/.github/scripts/test_history_filename_bounds.py:12; RiptOPL/.github/scripts/test_disc_key_semaphore.py:75
- Problem: READ, absence verified at the pin for every alternative path: `src/guigame.c`, `src/supportbase.c`, `src/cuesupport.c`, `src/cheatman.c`, `src/menuwatch.c`, `src/opl.c`, `src/gui.c`, `src/fntsys.c`, `src/themes.c`, `src/OSDHistory.c`, `src/system.c`, `lng_tmpl/` and `lng_fork/` do not exist in this repository; only the C++ layout does. Each listed test therefore carries a branch that can never execute here — an `exists()` ternary, a `CPP` flag with an `else:` body (ps1_duplicates:108-111, menu_crash_catcher:87-91), a candidate-path list whose first entry is never taken (game_size_fallback:13-16), or a compiler/file naming switch (cheat_capacity:103,106). The branches are inert today, but they misstate what the suite supports: a reader reasonably concludes both layouts are covered, and if the `.cpp` file were ever removed the tests would not test a fallback — they would die on a missing `.c` file with an error pointing at the wrong layout. (Counter-consideration, stated for the parent: these files were ported from the upstream C codebase's tests, and the dual layout may be deliberate if the same file is ever copied back upstream; within this repo at this pin it is dead weight.)
- Fix in words: In each file, read the C++ path directly and delete the C-layout alternative and its knock-on branches.
- Justification if the fix adds anything: Nothing added; deletions only.
- Benefit: The suite states one layout — the one that exists — and future renames fail at the real path.
- Effort: M
- Risk: Low
- Confidence: High (READ; every alternative path checked with `test -e` at the pin)

### Undocumented sys.argv source overrides in six tests silently substitute non-pin code

- Category: 7 (build/CI/repo clutter — hidden test-mode switches)
- Locations: RiptOPL/.github/scripts/test_ra_chunk_integrity.py:8; RiptOPL/.github/scripts/test_pad_hook_cache.py:15; RiptOPL/.github/scripts/test_genvmc_recovery.py:8; RiptOPL/.github/scripts/test_page_animation.py:9; RiptOPL/.github/scripts/test_zso_probe_fd.py:9-10; RiptOPL/.github/scripts/test_font_fit_bounds.py:9-10; RiptOPL/.github/scripts/test_history_filename_bounds.py:13-14
- Problem: READ. Any first command-line argument silently replaces the production source under test: a file path in ra_chunk_integrity, pad_hook_cache, genvmc_recovery and page_animation (`Path(sys.argv[1]) if len(sys.argv) > 1`), and a git ref fed to `git show` in zso_probe_fd, font_fit_bounds and history_filename_bounds. None of these seven files mentions the override in its docstring. The corpus shows the documented form of the same mechanism: test_ul_scan_integrity.py:6,17 requires the literal `--baseline` flag plus exactly one path argument, and test_cheat_capacity.py:3,17-18 documents its optional git ref. As written, a wrapper, a future `run_tests.sh` change, or a maintainer's stray argument makes the suite report PASS for code that is not at the pin, with nothing in the output saying so. One extra wart in the same lines: zso_probe_fd.py:10 runs `git show` without `cwd=root` (font_fit_bounds and history_filename_bounds both pass `cwd=root`), so its ref resolves in whatever repository the caller's working directory belongs to.
- Fix in words: Gate each override behind an explicit named flag in the ul_scan form (`--baseline <arg>`, exact arity), document it in the docstring, and give zso_probe_fd's `git show` the same `cwd=root` the other two already pass.
- Justification if the fix adds anything: A flag check per file; the baseline-comparison ability is kept, only made visible and opt-in.
- Benefit: A green run always means the pinned tree was tested, unless the output's invocation visibly says otherwise.
- Effort: S
- Risk: Low
- Confidence: High (READ)

### test_smb1_vmc_share is the batch's only cwd-relative test

- Category: 7 (build/CI/repo clutter — invocation fragility)
- Locations: RiptOPL/.github/scripts/test_smb1_vmc_share.py:25-27,30,37,87
- Problem: READ. Its `read()` helper (lines 25-27) opens the path it is given bare — `open(path, ...)` with no repo-root anchor — and the call sites pass `modules/iopcore/cdvdman/smb.c` (30), `modules/network/smbman-ra/smb.c` (37) and `Makefile` (87). Every other file in the batch anchors reads at `Path(__file__).resolve().parents[2]` (or an equivalent absolute ROOT). The test passes in CI only because both invoking routes happen to set the working directory to the repo root (flavours.yml runs it from the checkout root; tools/run_tests.sh:4 `cd`s to the repo root). Invoked by absolute path from any other directory — the natural way to run one test while debugging — it dies with FileNotFoundError on a healthy tree, reporting a failure that is not in the code under test.
- Fix in words: Anchor `read()` at the same parents[2] ROOT the rest of the corpus uses.
- Justification if the fix adds anything: Nothing added; one helper changes.
- Benefit: The test's result depends on the tree, not on the caller's shell directory.
- Effort: S
- Risk: Low
- Confidence: High (READ; verified unique in the batch by grep)

### Four tests create and use an in-tree build/test-tmp directory instead of the system temp dir

- Category: 7 (build/CI/repo clutter)
- Locations: RiptOPL/.github/scripts/test_network_parity_922.py:22-24; RiptOPL/.github/scripts/test_ul_scan_integrity.py:119-121; RiptOPL/.github/scripts/test_udpfs_serialization.py:117-119; RiptOPL/.github/scripts/test_build_driver.py:13-14,22,81
- Problem: READ. These four point `tempfile.TemporaryDirectory(dir=...)` at `ROOT / "build/test-tmp"`, creating that directory inside the checkout (the `mkdir(parents=True, exist_ok=True)` calls leave the empty parent behind after every run). test_build_driver.py:13-14 does the `mkdir` at import time, so merely collecting or importing the module writes into the tree. The other 66 files in the batch use the plain system-temp `TemporaryDirectory()`. Mitigating fact, READ: `build/` is gitignored (.gitignore:110 `/build/`, confirmed with `git check-ignore`), so the directory never dirties `git status`. Remaining costs: the four tests fail on a read-only or non-writable checkout where their 66 siblings pass, and an in-tree scratch dir is one `.gitignore` edit away from becoming committed clutter.
- Fix in words: Drop the `dir=` argument (and test_build_driver's import-time mkdir) and use the system temp dir like the rest of the batch — or, if a noexec `/tmp` on some runner is the unstated reason for the in-tree choice, write that reason in one comment in each file so the divergence is a decision, not an accident.
- Justification if the fix adds anything: Nothing added.
- Benefit: Tests become read-only with respect to the checkout; one temp-dir convention for the whole corpus.
- Effort: S
- Risk: Low
- Confidence: Med (mechanism READ; the read-only-checkout consequence is INFERRED, and a deliberate noexec-/tmp rationale cannot be excluded from the files alone)

### test_mbedtls_vendor's docstring still says five pinned roots; seven are pinned and asserted

- Category: 7 (build/CI/repo clutter — stale fixture text in a security-sensitive test)
- Locations: RiptOPL/.github/scripts/test_mbedtls_vendor.py:5-6 (against 20-28, 113-122, 140)
- Problem: READ. The docstring states the test operates on the basis that "only five pinned roots are trusted". The file itself pins seven roots (PINNED, lines 20-28), asserts the on-disk set equals those seven (line 118), hashes each against the CA-roots README (lines 120-122), its own later comment says "Seven pinned roots" (line 113), and its PASS line says "seven pinned roots" (line 140). The docstring is the only place still carrying the old count — in the one test whose entire subject is which TLS roots the RA/update builds trust, a reader who trusts the header miscounts the trust set by two.
- Fix in words: Correct the docstring count to seven (or drop the number and let PINNED speak).
- Justification if the fix adds anything: Nothing added; one word.
- Benefit: The trust-root count is consistent everywhere it is stated.
- Effort: S
- Risk: Low
- Confidence: High (READ)

## (c) Dissolved candidates

- **"33 batch files are never run in CI because flavours.yml doesn't name them"** — dissolved: flavours.yml is not the only runner; ps2build.yml:70-71 runs `tools/run_tests.sh -k`, and run_tests.sh:7 globs `.github/scripts/test_*.py`, so every batch file executes in CI (twice, across the gcc/llvm matrix).
- **RIPTOPL-286 axis in test_psu_timestamps.py** — no new candidate, per instructions: the `build_psu` → `inspect_psu` round-trip (lines 60,64-65) is the already-filed circular mechanism. Noted as extending context only: this file also carries the independent check RIPTOPL-286 calls for — external SAS golden timestamps (lines 13-22) and byte-level record assertions against a hand-packed expected date (lines 45,56-59) that do not go through the packager's own inspector.
- **Compiler-absence skip-to-pass (extends RIPTOPL-291?)** — dissolved for this batch: no batch file skips on a missing compiler; all either use `check=True`, test the return code explicitly (test_smstcpip_recv_notification_order.py:144-145, test_smstcpip_socket_bounds.py:70-71, test_net_recv_poll.py:104-106), or accumulate failures and `sys.exit(1)`. RIPTOPL-291's three named files are not in this batch.
- **test_ra_mode6's non-RETROACHIEVEMENTS run executes no assertions** — dissolved: the file runs both define sets in one invocation (lines 52-55); the RA run asserts the full lifecycle, and the non-RA run is a compile-only absence check that can still fail — the extracted handlers block is itself `#ifdef`-guarded, so RA code leaking outside the guard breaks the non-RA compile against the RA-only stubs (lines 17-33). Its PASS line (45) is printed by both runs, which is a wording wart, not a vacuous suite.
- **Conditional-branch tests that only exercise one define/argument** — dissolved for test_io_menu_lifetime.py (both RETROACHIEVEMENTS define sets run, lines 115-118), test_bdm_transport_binding.py (both USE_BDM_ATA sets run, lines 74-77), and test_autoload_discovery_settles.py (binary run with and without the `ready` argument, lines 54-55): in each file the driver itself executes every branch.
- **PyYAML availability for test_build_driver.py / test_udpfs_shared_transport.py in ps2build.yml** — dissolved as a test finding: ps2build.yml installs no requirements file before run_tests.sh, but the same job's mandatory Build step runs tools/build.py, which itself imports yaml, so the job cannot be green at all without PyYAML on the runner; flavours.yml:25 installs it explicitly for the host-test job. Not a silent-pass or test-specific gap.
- **The duplicated `function()`/extractor helper across ~50 batch files** — dissolved as already characterised: that is the corpus-wide pattern covered by RIPTOPL-005's round-1 characterisation, which the task instructed not to re-derive.
- **test_package_orbit_neutrino's hard-coded pin (lines 89-92) and "Neutrino v1.8.0" label assertion (line 53)** — dissolved: both match production at the pin (tools/package_edition.py:66 hard-codes the same v1.8.0 string into the staged label; the pin file third_party/orbit-neutrino/release.json carries exactly the asserted repository/tag/sha256). The hard-coding is the review gate working as designed, not a stale fixture.
- **test_mbedtls_vendor's `except ValueError: continue` being a legitimate-refusal filter** — partially dissolved, partially filed above: refusing invalid combinations is legitimate, but the absence of any record of which combinations were refused is the filed defect; the dissolution covers only the intent, not the missing accounting.
