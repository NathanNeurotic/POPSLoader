# Round 8 — Section 07 — RiptOPL test corpus, batch 07

Pin: 2e347d5ac885 (verified, clone untouched, `git status` clean at end of read).
Method: every file in batch-07.txt line-read in full, in listed order. 28 files, 6,797 lines.
CI context (READ): `tools/run_tests.sh` runs every `.github/scripts/test_*.py` and is itself run by `.github/workflows/ps2build.yml:71` (`tools/run_tests.sh -k`); `.github/workflows/flavours.yml` additionally names many of these files individually. A file absent from flavours.yml is therefore not dead — it still runs via ps2build.

## (a) Per-file ledger

| path | lines | verdict |
|---|---|---|
| .github/scripts/test_smb_read_closed.py | 292 | clean |
| .github/scripts/test_smb1_transport_bounds.py | 284 | clean |
| .github/scripts/test_mmce_read_recovery.py | 277 | clean |
| .github/scripts/test_udpfs_library_launch.py | 276 | finding (C3) |
| .github/scripts/test_smstcpip_socket_lifetime.py | 274 | clean |
| .github/scripts/test_auto_vmc.py | 270 | clean |
| .github/scripts/test_udpbd_read_only.py | 268 | finding (C3) |
| .github/scripts/test_ps2ips_recv_tail.py | 265 | finding (C3) |
| .github/scripts/test_vmc_fatfs_images.py | 263 | finding (C2) |
| .github/scripts/test_legacy_parity_885_898.py | 258 | clean |
| .github/scripts/test_mx4sio_write_acceptance.py | 258 | finding (C1) |
| .github/scripts/test_ripps2_drive_status.py | 258 | finding (C3, C4) |
| .github/scripts/test_mx4sio_retry.py | 256 | finding (C1) |
| .github/scripts/test_vmc_past_2tb_ata.py | 254 | clean |
| .github/scripts/test_ra_runtime_budget.py | 245 | clean |
| .github/scripts/test_font_size.py | 240 | clean |
| .github/scripts/test_ra_sender.py | 238 | finding (C3) |
| .github/scripts/test_ingame_freeze_diag.py | 228 | finding (C3) |
| .github/scripts/test_bdm_cache.py | 227 | finding (C3) |
| .github/scripts/test_native_vmc_layout.py | 227 | clean |
| .github/scripts/test_pccf.py | 222 | clean |
| .github/scripts/test_ripps2_game_manage.py | 218 | finding (C3) |
| .github/scripts/test_ember_fatfs_images.py | 216 | finding (C2) |
| .github/scripts/test_font_flush_frame_lock.py | 213 | finding (C3) |
| .github/scripts/test_game_parental_lock.py | 212 | clean |
| .github/scripts/test_ps1_save_icons.py | 211 | finding (C3) |
| .github/scripts/test_site_sync.py | 211 | clean (bs4 axis: no new evidence beyond RIPTOPL-290; the suite does run for real in the dedicated flavours.yml `site-sync-host-tests` job, flavours.yml:344-351, in a venv with beautifulsoup4 installed — READ) |
| .github/scripts/test_ee_hook_context.py | 136 | clean |

## (b) Candidate findings

### C1 — test_mx4sio_retry.py runs the whole test_mx4sio_write_acceptance.py suite as its last step, so ps2build executes the acceptance suite twice
- Category: 2 (duplication) / 7 (build/CI)
- Locations: .github/scripts/test_mx4sio_retry.py:251; .github/scripts/test_mx4sio_write_acceptance.py:1-258 (whole file); tools/run_tests.sh (glob runs both files); .github/workflows/flavours.yml:53 (runs retry only)
- Problem: READ. test_mx4sio_retry.py:251 ends main() with `subprocess.run([sys.executable, .../test_mx4sio_write_acceptance.py], check=True, timeout=900)`. Under tools/run_tests.sh (ps2build) both files are top-level tests, so the acceptance suite — its ISR harness, two mutant rebuild-and-run cycles, and the card-info harness, each with its own compiles — executes twice per test run. Under flavours.yml the nested call is the acceptance suite's *only* coverage (flavours names retry at :53, never write_acceptance), so the coupling is load-bearing in one workflow and pure duplication in the other; neither file says so.
- Fix in words: Drop the nested invocation from test_mx4sio_retry.py and name test_mx4sio_write_acceptance.py explicitly in flavours.yml next to test_mx4sio_retry.py, so each suite runs exactly once in each workflow.
- Justification if the fix adds anything: Adds one workflow line; removes one subprocess call. Net less.
- Benefit: Halves acceptance-suite CI time under ps2build; coverage in flavours becomes visible instead of hidden inside another test.
- Effort: S / Risk: Low / Confidence: High (READ)

### C2 — The FatFs disk-image fixture is duplicated almost verbatim between the VMC and Ember image tests
- Category: 2 (duplication)
- Locations: .github/scripts/test_vmc_fatfs_images.py:24-53,244-263; .github/scripts/test_ember_fatfs_images.py:52-77,195-216
- Problem: READ. Both files carry the same fixture: a 131,072-sector in-memory disk, disk_initialize/disk_status/disk_read/disk_write/disk_ioctl, get_fattime, the four ff_mutex stubs, copying ff.c/ffunicode.c and the FatFs headers into a temp build dir, writing the same module_debug.h stub, and flipping FF_USE_MKFS to 1 in the copied ffconf.h (vmc :252 asserts the substitution landed; ember :203 does not). A FatFs pin bump or fixture fix must be made twice, in two slightly divergent copies (even the get_fattime day differs: 18 vs 19).
- Fix in words: Move the shared diskio/mutex/build-dir setup into one small helper module under .github/scripts/ (the hostmap.py precedent shows tests already import siblings) and have both tests use it; keep each test's own production-code extraction and cases.
- Justification if the fix adds anything: Adds one shared helper file; removes ~50 duplicated lines across the two tests. Net less.
- Benefit: One place to update when the vendored FatFs or its config changes; the MKFS-substitution assertion then covers both suites.
- Effort: M / Risk: Low / Confidence: High (READ)

### C3 — Nine batch tests run their compiled harness with no timeout, so a hung harness hangs the CI job instead of failing
- Category: 7 (build/CI)
- Locations: .github/scripts/test_udpfs_library_launch.py:29-30; .github/scripts/test_udpbd_read_only.py:156-160; .github/scripts/test_ps2ips_recv_tail.py:260-264; .github/scripts/test_ra_sender.py:235-238; .github/scripts/test_ingame_freeze_diag.py:200,221; .github/scripts/test_bdm_cache.py:216-220; .github/scripts/test_ripps2_drive_status.py:40-41; .github/scripts/test_ripps2_game_manage.py:174-176; .github/scripts/test_font_flush_frame_lock.py:202-203; .github/scripts/test_ps1_save_icons.py:168,178
- Problem: READ. These subprocess.run calls that execute the compiled test binary (and in several files the compile too) pass no `timeout=`, unlike the rest of the batch (e.g. test_mmce_read_recovery.py timeout=60/120, test_mx4sio_retry.py timeout=30/120, test_vmc_fatfs_images.py timeout=90). The risk is concrete for test_ps1_save_icons.py, whose own cases include a corrupt/cyclic save chain that "must not cause an unbounded traversal": if the parser regressed to looping, the test would hang until the GitHub job timeout rather than failing. Same shape for test_ps2ips_recv_tail.py, which exercises receive loops.
- Fix in words: Add a bounded timeout (the batch's existing 10-90 s range) to the harness-execution subprocess.run calls in these files, matching their sibling tests.
- Justification if the fix adds anything: Adds one argument per call site; nothing new.
- Benefit: A hang regression becomes a fast, attributable test failure instead of a burned CI job.
- Effort: S / Risk: Low / Confidence: High (READ)

### C4 — test_ripps2_drive_status.py tests a re-typed copy of the drive-size arithmetic, not the production expression
- Category: 2 (duplication)
- Locations: .github/scripts/test_ripps2_drive_status.py:156-168,178-188; production copies at src/ui/drivestatus.cpp (dsSizeText call sites) and src/core/filemgr.cpp (fmRoomFor), as string-matched at :159-160
- Problem: READ. The free/total-KB and room-check expressions live as Python string literals (FREE_KB/TOTAL_KB/NO_ROOM, :156-158). The test asserts those exact strings appear in production (:159-160), then compiles *its own copies* as freeKb/totalKb/noRoom (:166-168) and runs all the 8 TB / no-wrap arithmetic assertions against the copies (:178-188). The production expressions themselves are never executed — unlike test_legacy_parity_885_898.py in this same batch, which extracts the actual condition text from guigame.cpp and compiles that. Any production refactor into an equivalent helper makes the string assert fail spuriously, and the two copies must be edited in lockstep forever.
- Fix in words: Extract the three expressions from drivestatus.cpp/filemgr.cpp at test time (the legacy-parity pattern) and compile those, deleting the Python-side literal copies; keep the presence assertions only if extraction still needs them.
- Justification if the fix adds anything: Adds nothing; replaces literal copies with extraction the corpus already uses elsewhere.
- Benefit: The arithmetic assertions bind to the code that ships; equivalent refactors stop failing the test.
- Effort: S / Risk: Low / Confidence: High (READ)

## (c) Dissolved candidates

- test_vmc_past_2tb_ata.py asserting the 28-bit wrap to sector 0 (:234-240) encodes a bug as correct — dissolved READ: the docstring (:15-17) and the Python-side assert on bdmNativeVmcLimit's `1ULL << 28` (:47-48) frame the wrap as the hardware truth the launch guard exists to stop; the test checks both the driver behaviour and the guard.
- test_udpbd_read_only.py asserting udpbd_write returns `count` on a server error answer — dissolved READ: deliberate, documented design (docstring + the g_errno timeout distinction checked in the same block); no prior finding identifies it as a defect.
- test_udpfs_library_launch.py pinned PROVENANCE.json hashes are stale — dissolved READ: recomputed all per-file SHA-256 at the pin; every entry matches, and the archive hash assertion is in the test itself.
- test_pccf.py references deleted tests/pccf/test_*.c — dissolved READ: test_bd.c, test_profile.c, test_ata_rw.c all exist at the pin; the fourth name (ownership) is generated in the temp dir by the test itself.
- test_ingame_freeze_diag.py references deleted ee_core/tests or tools modules — dissolved READ: ee_core/tests/test_freeze_diag_format.c, test_freeze_diag_screen.c, tools/build_edition.py and tools/build_configuration.py all exist; configurations.yml:39 builds the ingamediag configuration it asserts.
- test_font_flush_frame_lock.py's before-control can pass vacuously — dissolved READ: the control run must exit 3 with the "outside the GUI lock" message, and the `before == production` check (:210-212) fails the test if no FontFrameScope exists to strip.
- test_site_sync.py / test_wiki_sync.py bs4 skip in run_tests.sh — already RIPTOPL-290; no new evidence in this batch (the dedicated flavours job runs it with bs4 installed). Not re-filed.
- Compiler-name hardcoding (gcc/cc/c++/g++ literals, e.g. test_smb_read_closed.py:274, test_vmc_past_2tb_ata.py:251) as a compiler-absence skip — dissolved READ: absence raises/CalledProcessError and fails the run; it does not skip-and-pass. Distinct from RIPTOPL-291's three named skipTest files, none of which are in this batch.
- The per-file `function()`/extraction helpers duplicated across all 28 batch files, and the three files' shared `build/test-tmp` directory pattern (test_auto_vmc.py:19, test_udpfs_library_launch.py:23, test_legacy_parity_885_898.py:22; build/ is gitignored, .gitignore:110) — dissolved: corpus characterisation already covered by RIPTOPL-005; not re-derived per instructions.
- test_native_vmc_layout.py's `import hostmap` (line 2) silently rewriting production source — dissolved READ: hostmap.py's monkey-patch is documented, maps only host:: calls back to the mock names the harness defines, and an unmapped host:: call fails compilation loudly.
- Files absent from flavours.yml (udpbd_read_only, ps2ips_recv_tail, vmc_fatfs_images, mx4sio_write_acceptance, ra_runtime_budget, font_size, ingame_freeze_diag, pccf, ember_fatfs_images, ps1_save_icons) are dead — dissolved READ: tools/run_tests.sh's glob runs all of them under ps2build.yml:71, and the two ripps2 files run under flavours' test_ripps2_*.py glob (flavours.yml:65-67).
