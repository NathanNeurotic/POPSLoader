# S4 — Misc Python Tests (Round 7, PS2-Servers @ c5f021c4d386)

Scope: every remaining file in `tests/` not assigned to the SMB, transport, or RA sections.
Exclusions applied exactly as briefed (`test_smb*`, `test_netinfo_and_smb`, `test_udpfs*`,
`test_udpbd*`, `test_nfs4_server`, `test_http*`, `test_transfer_limits`, `test_raw_storage`,
`test_path_access`, `test_ra_*`, `test_retroachievements`, `test_achievement_*`,
`test_discord_presence`). Remainder = **56 files, 11,527 lines, all read line-by-line (READ)**.
Test-suite defects only; PS2SERVERS-001…069 stand untouched. Provisional IDs S4-01… only.

---

## 1. Per-file ledger

| File | Lines | Read |
|---|---|---|
| tests/__init__.py | 7 | Y |
| tests/library_fixtures.py | 105 | Y |
| tests/test_about_page.py | 152 | Y |
| tests/test_art_fetch.py | 216 | Y |
| tests/test_attribution_policy.py | 43 | Y |
| tests/test_autostart_and_firewall_options.py | 330 | Y |
| tests/test_caduceus_reference_wire.py | 60 | Y |
| tests/test_caduceus_setup.py | 91 | Y |
| tests/test_chd_cd_size.py | 55 | Y |
| tests/test_chd_cuebin.py | 454 | Y |
| tests/test_companion_fixtures.py | 176 | Y |
| tests/test_cooperative_stop.py | 386 | Y |
| tests/test_desktop_instance.py | 99 | Y |
| tests/test_directlink.py | 976 | Y |
| tests/test_directlink_unix.py | 408 | Y |
| tests/test_disc_identity.py | 344 | Y |
| tests/test_edge_flag_exposure.py | 296 | Y |
| tests/test_edge_manual.py | 113 | Y |
| tests/test_edge_service_modes.py | 424 | Y |
| tests/test_frozen_imports.py | 156 | Y |
| tests/test_game_library.py | 299 | Y |
| tests/test_gui_layout.py | 305 | Y |
| tests/test_gui_smb2_start_needs_login.py | 55 | Y |
| tests/test_library_catalog.py | 212 | Y |
| tests/test_library_identity.py | 248 | Y |
| tests/test_library_index.py | 241 | Y |
| tests/test_library_panel.py | 360 | Y |
| tests/test_library_preferences.py | 74 | Y |
| tests/test_library_recursive_scan.py | 203 | Y |
| tests/test_line_endings.py | 122 | Y |
| tests/test_linux_parity.py | 204 | Y |
| tests/test_opl_http_runner.py | 79 | Y |
| tests/test_orbit_reference_wire.py | 69 | Y |
| tests/test_packaging_data_files.py | 193 | Y |
| tests/test_portable_config.py | 93 | Y |
| tests/test_protocol_mode_selector.py | 236 | Y |
| tests/test_ps1_vcd.py | 163 | Y |
| tests/test_release_downloads.py | 223 | Y |
| tests/test_reset_settings.py | 223 | Y |
| tests/test_riptopl_profile.py | 129 | Y |
| tests/test_router_status.py | 316 | Y |
| tests/test_server_override_contract.py | 100 | Y |
| tests/test_session_cap.py | 196 | Y |
| tests/test_session_shutdown.py | 257 | Y |
| tests/test_session_summary.py | 477 | Y |
| tests/test_session_view.py | 117 | Y |
| tests/test_settings_feedback.py | 141 | Y |
| tests/test_setup_guide.py | 96 | Y |
| tests/test_status_client.py | 281 | Y |
| tests/test_status_dot.py | 84 | Y |
| tests/test_systemd_units.py | 256 | Y |
| tests/test_theme.py | 111 | Y |
| tests/test_tray_linux.py | 188 | Y |
| tests/test_verbose_default_and_log_stamps.py | 75 | Y |
| tests/test_verify_docs.py | 31 | Y |
| tests/test_version_consistency.py | 179 | Y |
| **Total** | **11,527** | **56/56** |

---

## 2. Candidate findings

### S4-01 / ~52 GUI tests assert nothing in CI: the only CI test job is headless, and whole files skip there
- **Category:** Vacuous in CI (permanent, environment-gated skip)
- **Locations:** tests/test_gui_layout.py:38 (`raise unittest.SkipTest("no tkinter")` in `setUpClass`), tests/test_gui_layout.py:67 (`raise unittest.SkipTest("no display")` in `setUpClass`) — class-level, so all 12 tests in the file skip; tests/test_autostart_and_firewall_options.py:45-54 and the same guard in all 9 test methods; tests/test_settings_feedback.py:48-53 (in `_make_app`, all 8 tests); tests/test_library_panel.py:19,44,92,136 plus the `AchievementLibraryIndexTests.setUp` skip (~:237) — 11 of 13 tests; tests/test_reset_settings.py:76,81 (all 7 GUI-class tests; only the 2 pure config tests run); single GUI tests at tests/test_about_page.py:110,115, tests/test_session_view.py:85,89, tests/test_protocol_mode_selector.py:200,204, tests/test_riptopl_profile.py:109. CI side: .github/workflows/ci.yml:89-97 — the `python-checks` job is `ubuntu-latest` (headless), runs full discovery, and its own comment states "The GUI tests skip themselves where there is no display, so this is safe on a headless runner; see tests/test_gui_layout.py."
- **Problem:** READ (guards + workflow) / INFERRED (runner has no display — standard for `ubuntu-latest`, and the workflow comment itself asserts it). The skip is total for test_gui_layout.py (the briefed check: yes — `setUpClass` raises before any test body, so the file contributes zero assertions headless), test_autostart_and_firewall_options.py, and test_settings_feedback.py. Summed across the section, ≈52 test methods are collected, reported as "skipped", and gate nothing in the only job that runs discovery. No other CI job runs these modules with a display (the Windows jobs at ci.yml:39,50 name fixed module lists that include only test_library_panel from this set — and even there the panel tests skip only on `TclError`, which a Windows runner does not raise, so those do run; the rest have no such job).
- **Fix (LESS):** Do not add a virtual-display dependency for everything. Split each affected file the way test_session_view.py already does: pure-logic tests in a class with no Tk guard, widget tests in the guarded class. Where a test only needs widget *state* (autostart flags, settings flash text), drive it through the existing fake-self pattern used in tests/test_directlink.py `LauncherLifecycleTests`. Leave test_gui_layout.py guarded — it genuinely measures mapped-window geometry — but say so in one line at its guard.
- **Benefit:** The autostart/firewall, reset, and settings-feedback behaviours become CI-gated instead of developer-machine-only.
- **Effort:** M (per-file splits) / **Risk:** Low / **Confidence:** High on the guard mechanics (READ), Medium on the exact count (derived by counting guarded methods).

### S4-02 / test_chd_cd_size.py never runs in CI: libchdr is built *after* the test suite runs
- **Category:** Permanent unexplained skip (CI-dead file)
- **Locations:** tests/test_chd_cd_size.py:20 (`@unittest.skipUnless(LIBCHDR_AVAILABLE, …)` on the only test class, all 4 tests); udpfs_server/compressed_iso/chd.py:53-56,134-175 (loader searches for `libchdr.so.0`/`libchdr.so` etc.; no such file exists in the tree — READ via find); .github/workflows/ci.yml:97 (discovery) vs :143-144 ("Smoke build bundled libchdr" runs *after* discovery) and :146-152 (the post-build step names only test_ra_compressed_hash tests and `test_disc_identity…test_real_chd_identity…` — not this file).
- **Problem:** At discovery time the bundled libchdr has not been built yet, so `LIBCHDR_AVAILABLE` is False and the whole file skips; the later step that does build it never re-runs this module. The CD-track-table size logic (raw vs cooked CHD) is therefore gated by no CI job. INFERRED from workflow ordering + loader search paths, both READ.
- **Fix (LESS):** Add `tests.test_chd_cd_size` to the existing post-build unittest invocation at ci.yml:146-152. One line, no new job.
- **Benefit:** 4 real-decoder tests start gating.
- **Effort:** S / **Risk:** Low / **Confidence:** Medium-High (ordering is READ; assumes no libchdr preinstalled on the runner image, consistent with the workflow needing a smoke-build step at all).

### S4-03 / test_desktop_instance.py's two real-mutex tests run on no CI job
- **Category:** Permanent platform-gated skip (CI-dead tests)
- **Locations:** tests/test_desktop_instance.py:31 and :74 (`@unittest.skipUnless(platform.system() == "Windows", "Windows kernel integration")`); .github/workflows/ci.yml:97 (discovery is ubuntu-only), :39 and :50 (the Windows jobs name fixed module lists; this module is in neither — READ via grep of .github/).
- **Problem:** The mocked WinDLL test (:56-72) runs everywhere and is sound, but the two tests that exercise a real kernel mutex across processes — the behaviour the module exists for — are skipped on Linux and never invoked on Windows. They can rot (or the child-process protocol can break) with every workflow green.
- **Fix (LESS):** Add `tests.test_desktop_instance` to the existing windows-storage job's unittest line (ci.yml:50). One line.
- **Benefit:** Real-mutex contention/release is gated where it can run.
- **Effort:** S / **Risk:** Low / **Confidence:** High (module lists READ).

### S4-04 / test_game_library.py: hardlink half of a test silently vanishes — `except OSError: return`
- **Category:** Vacuous branch (except→return, no skip recorded)
- **Locations:** tests/test_game_library.py:191-192 (`except OSError: return` in `test_backup_rejects_live_database_and_hardlink`, test body ~:184-193).
- **Problem:** READ. If `Path.hardlink_to` raises `OSError` (unsupported filesystem, cross-device, restricted sandbox), the test *passes* having run only the live-database assertion; the hardlink rejection — half the test's name — is neither run nor reported as skipped. Unlike the symlink cases in the same file (:107-108, :124-125), which correctly use `self.skipTest(...)`, this one is invisible in the output.
- **Fix (LESS):** Change `return` to `self.skipTest("Host cannot create hardlinks")` — one word, matching the file's own pattern.
- **Benefit:** A missing hardlink check becomes a visible skip instead of a silent pass.
- **Effort:** S / **Risk:** None / **Confidence:** High.

### S4-05 / test_companion_fixtures.py: the link/locked assertions only exist inside `if self.made[…]` conditionals
- **Category:** Assertions in conditionals that may not run
- **Locations:** tests/test_companion_fixtures.py:47-48 (expected-set construction), :59-64 (`test_links_out_of_the_root_and_locked_folders_are_not_indexed`: `if self.made["link"]:` guards the `skipped_links` assertion, `if self.made["locked"]:` guards both remaining assertions); fixture side: tests/library_fixtures.py:80-92 (`build()` returns `{"link": link_made, "locked": locked_made}`, both False on Windows / root / no symlink privilege).
- **Problem:** READ. On any host where the symlink or the chmod does not take effect, the test named for link/locked handling passes while asserting only the trivial "no Escaped path" half. No skip is recorded, so a platform where the fixture silently degrades looks identical to one where the behaviour was verified. (On the current Linux CI runner both flags are expected True, so this is a portability vacuity, not a CI vacuity today — INFERRED.)
- **Fix (LESS):** Replace each `if self.made[…]:` with `self.assertTrue(self.made[…], …)` at the top of that one test, or `skipTest` when False — same pattern as S4-04.
- **Benefit:** The fixture's degradation becomes loud instead of absorbed.
- **Effort:** S / **Risk:** Low / **Confidence:** High on mechanism (READ), Medium on impact.

### S4-06 / test_opl_http_runner.py: one hash-mismatch test is a strict subset duplicate of the next
- **Category:** Duplicated test body
- **Locations:** tests/test_opl_http_runner.py:64-71 (`test_a_hash_mismatch_still_fails_hard_and_is_not_a_skip`) and :73-79 (`test_changed_upstream_bytes_are_rejected_before_source_generation`).
- **Problem:** READ. Both patch `runner.urllib.request.urlopen` to return `io.BytesIO(b"unexpected source")`, call `runner.generate(...)` in a fresh temp dir, and assert `ValueError`. The second adds only the `"SHA256 mismatch"` regex and the empty-directory assertion — i.e. it strictly subsumes the first. The first test's name claims a distinct property ("is not a skip") that its body never checks (no exit-code / SKIP-output assertion, unlike :32-50 which does check that).
- **Fix (LESS):** Delete the first test; rename the second to carry both intents. Net −8 lines.
- **Benefit:** One fewer misleadingly-named test; the surviving one checks strictly more.
- **Effort:** S / **Risk:** Low / **Confidence:** High.

### S4-07 / Source-text tests that pass on a string anywhere in the file, including dead code
- **Category:** Snapshot-of-source (no behaviour executed)
- **Locations:** tests/test_library_preferences.py:59-67 (`test_main_launcher_preserves_preferences_on_save`: four `assertIn` substring checks over gui.py / library_gui.py source text, plus `ast.parse`); tests/test_setup_guide.py:33-39 (`test_gui_button_connected_once`: `source.count('text="PS2 setup guide…"') == 1` etc.) and :41-48 (`test_first_run_invitation_and_persistent_status`: eight `assertIn` source strings).
- **Problem:** READ. These assert that character sequences exist in a source file, not that any code path runs. A string left in an unreachable branch, a renamed-but-retained copy, or a literal in a docstring satisfies them; conversely they fail on a behaviour-preserving refactor that splits a literal across lines. Contrast within the same files: test_setup_guide.py's other tests extract methods by AST and `exec` them (real), and tests/test_status_client.py:206-281 checks `stop_all` by AST call-graph (real). The substring tests are the weak half of otherwise sound files.
- **Fix (LESS):** For the preferences case, extend the file's own existing AST-exec pattern (used at :16-57 for `save_preferences`) to the main launcher's save path instead of grepping it. For the setup-guide counts, drop the two pure-string tests and keep the AST/exec ones; the button-connection property is already implied by the exec'd `close` test plus compilation. Net deletion preferred.
- **Benefit:** Removes tests that certify text, not behaviour.
- **Effort:** M / **Risk:** Low / **Confidence:** High on mechanism (READ); Medium that every asserted string is currently live code.

### S4-08 / The GUI scratch-environment setUp is copy-pasted across five files (and the Tk guard across nine methods in one)
- **Category:** Duplicated fixture blocks
- **Locations:** Scratch env + tray stub block: tests/test_about_page.py:85-104; tests/test_autostart_and_firewall_options.py:19-42; tests/test_reset_settings.py:20-39 *and again* :53-71 (two classes, same file, differing in whether `config.save` is stubbed); tests/test_settings_feedback.py:24-44; tests/test_gui_layout.py:40-71 (class-level variant). Tk/display guard block: repeated in every one of the 9 methods of tests/test_autostart_and_firewall_options.py (e.g. :45-54, :132-141, :309-318), while tests/test_reset_settings.py:73-92 and tests/test_settings_feedback.py:46-71 already solved the same problem once with a `_make_app()` helper.
- **Problem:** READ. Five near-identical copies of the APPDATA/XDG_CONFIG_HOME scratch + `tray.AVAILABLE = False` setup have already drifted (some stub `config.save`, some don't; teardown ordering differs), so a future isolation fix (e.g. also stubbing `config.save` everywhere) must be made five times and will be made in fewer. The autostart file additionally re-pastes the 10-line tkinter/display guard per method instead of using the helper pattern its sibling files use.
- **Fix (LESS):** One shared helper — a `gui_scratch()` context manager / `_make_app` in a single tests module (library_fixtures.py is the existing shared-fixture precedent) — and delete the per-file copies. Net large deletion.
- **Benefit:** One place owns test isolation from the user's real launcher.json.
- **Effort:** M / **Risk:** Low (mechanical; each file's suite re-run proves equivalence) / **Confidence:** High.

### S4-09 / test_about_page.py: the version-label expectation is built from the module under test
- **Category:** Self-referential (golden generated from code under test at test time)
- **Locations:** tests/test_about_page.py:49-52 and :79-81 (`"v" + release_metadata.DISPLAY_VERSION` used to construct the expected `version_label()` result; also :137 in the GUI test).
- **Problem:** READ. The commit half of the label is properly pinned (subprocess mocked to `deadbee`, bake faked to `abc1234`), but the version half of the expectation is `release_metadata.DISPLAY_VERSION` itself. If `DISPLAY_VERSION` were wrong, or `version_label()` merely echoed it in a wrong format in a way consistent with the concatenation, the test passes — it can only catch a label that *disagrees with itself*. This is the only place in the section meeting the strict golden-from-code definition; the section's other cross-checks (S4-sound list) use genuinely independent reads.
- **Fix (LESS):** Hardcode the expected display version string in these two tests (it changes exactly when a release bumps it, which is when a human is already editing release_metadata). Or assert against tools/version_source's independent read, as test_version_consistency.py:69-93 already does.
- **Benefit:** The label test gains an independent expectation for its version half.
- **Effort:** S / **Risk:** Low / **Confidence:** High on mechanism; Low severity (commit logic, the historically buggy half, is properly pinned).

### S4-10 / Unguarded assertion loops: an empty collection passes the test
- **Category:** Assertions in loops that may not run (no guard-the-guard)
- **Locations:** tests/test_about_page.py:25-29 (`for server in servers.REGISTRY.values(): self.assertIn(...)` — no assertion that the registry is non-empty); tests/test_linux_parity.py:157-164 (`test_no_other_field_is_windows_only`: asserts only inside `if f.windows_only:` — passes trivially if no field is flagged at all).
- **Problem:** READ. Both pass vacuously over an empty/flagless collection. The suite itself knows this failure mode and guards it elsewhere — tests/test_edge_flag_exposure.py:132-135 ("Guard the guard"), tests/test_frozen_imports.py:137-156, tests/test_edge_manual.py:95 — these two are the unguarded remainder in this section. Partial mitigation (READ): test_linux_parity.py:149-152 separately asserts take_445 *is* flagged, so S4-10's second location is backstopped; the about-page loop has no equivalent backstop for registry emptiness (a registry that lost a mode would shrink both sides of the comparison together — the loop compares REGISTRY against ABOUT_TEXT derived from nothing else).
- **Fix (LESS):** One `assertTrue(servers.REGISTRY)` line in the about-page test, copying the in-suite pattern. No change needed for the linux-parity location beyond noting the backstop.
- **Benefit:** Closes the last unguarded-loop holes in the section.
- **Effort:** S / **Risk:** None / **Confidence:** High on mechanism, Low on likelihood.

### S4-11 / test_router_status.py: a Go toolchain timeout is converted into a skip
- **Category:** Failure masked as skip
- **Locations:** tests/test_router_status.py:176-178 (`except subprocess.TimeoutExpired: self.skipTest("go run timed out")` in `test_go_and_python_encoders_agree`).
- **Problem:** READ. This is the section's only byte-for-byte Python↔Go wire cross-check. A regression that makes the Go side hang or compile extremely slowly — exactly the class of change this test exists to catch — reports as "skipped" and CI stays green, indistinguishable from the legitimate no-toolchain skip at :142 (which CI pre-empts by installing Go, ci.yml python-checks "Set up Go" step).
- **Fix (LESS):** `self.fail("go run timed out")` instead of `skipTest`. One word.
- **Benefit:** The cross-implementation contract cannot time out into a pass.
- **Effort:** S / **Risk:** Low (a genuinely slow runner would go red — which is the point; timeout is already a generous 180 s) / **Confidence:** High.

---

## 3. Checked-and-sound list (weak-but-real, no finding filed)

- **tests/test_gui_smb2_start_needs_login.py** — Looks GUI-gated but is not: `setUpClass` only imports `launcher.gui` and the tests drive `LauncherApp.start_server` on a `SimpleNamespace` fake self, so they run headless in CI. Correct pattern; cited as the model for S4-01's fix.
- **tests/test_caduceus_setup.py:44-91** — `ServerCard._use_shared_game_folder` is invoked on a `mock.Mock()` self (mocked-away subject, superficially). Sound because the *method* is the real unbound function, and :52-54 asserts the recorded `mock_calls` name set is a subset of the allowed three — an unexpected attribute call fails. Weak-but-real.
- **tests/test_tray_linux.py** — Fake `pystray` injected into `sys.modules` is disclosed in the module docstring (:1-13) and the assertions are about backend wiring (available/start/menu-marshal/stop), not rendering. The real-rendering gap is explicitly assigned to a Linux tester in the docstring.
- **tests/test_theme.py:82-111** — Sentinel-colour patching of `theme.PALETTE` proves `asset_skin` reads the live palette rather than a copy with today's values. Independent expectation, not a golden.
- **tests/test_version_consistency.py:69-93** — The display-version cross-check deliberately uses a *different* mechanism (naive regex) from the AST parser under test, with the reasoning stated in the docstring. Not self-golden. Its qualifier test (:155-179) explicitly refuses to skip the inapplicable direction — the anti-pattern to S4-10, done right.
- **tests/test_router_status.py:136-205 (except S4-11)** — Python vs Go encoders compared byte-for-byte from two independent implementations; LiveServer tests drive the real `_handle_discovery` over a real socket with nothing stubbed.
- **tests/test_session_summary.py Smbv1WiringTests (:343-385)** — SMB1 `HANDLERS` are stubbed, but the subject is `serve_conn`'s counting, and the stubs fix exactly the variable (per-command status) the counting branches on. Sound isolation, and handlers are restored via `addCleanup`.
- **tests/test_directlink.py LauncherLifecycleTests (:782-976)** — `object.__new__(LauncherApp)` fake-self pattern exercises real lifecycle methods; platform is *pinned* via mock (`is_windows → True`) rather than skipped off-Windows, with the reasoning commented at :851-857 and :890-891. Model pattern.
- **tests/test_opl_http_runner.py:32-62** — The skip-behaviour tests are not vacuous skips: the subject *is* the runner's skip/fail decision, and they assert exit code, SKIP-vs-PASS output, and that `exercise` was never called.
- **tests/test_line_endings.py vs tests/test_edge_service_modes.py init-script parse checks** — Apparent duplication (acknowledged at test_line_endings.py:88), but the inputs differ deliberately: committed git blob vs working-tree file, which is the whole point on Windows/autocrlf. Not a duplicate body.
- **tests/test_status_client.py:206-281 (StopAllStaysUnconditional)** — Source-level, but by AST call-graph (`_calls` walks `ast.Call` nodes), not substring: a renamed or commented-out prompt call does not satisfy it. Sound, and the docstring explains why a behavioural test is impossible headless.
- **tests/library_fixtures.py** — Every public helper (`build`, `stress`, `unlock`, `INSPECTED`, `MISNAMED`, `TOO_DEEP`, `COMPRESSED`, `TRUNCATED`, `VCD`, `EMBER_*`, `LOCKED`, `LINK`) is consumed by its sole consumer, tests/test_companion_fixtures.py (READ via grep: it is the only importer). Single-consumer, but nothing dead. Its docstring's "shared by the consumer tests" is generous phrasing, not a defect.
- **Dead-helper scan** — An AST scan of all 56 files found no unreferenced top-level helper functions (every helper is referenced at least once beyond its definition; TestCase classes excluded as discovery-loaded). No dead fixtures filed.
- **Tests of deleted/renamed code** — None found. Spot-verified by grep in the clone (READ): `LauncherApp._terminal_text` exists at launcher/gui.py:3052; `_apply_gui_review_fixes` at launcher/main.py:107; `LibraryWindow.save_preferences` at launcher/library_gui.py:118 and `show_cover` at :359 (both exec'd by test_library_preferences.py); `ServerCard._use_shared_game_folder` at launcher/gui.py:571; `LauncherApp.stop_all` / `stop_all_confirmed` / `_confirm_app_shutdown` at launcher/gui.py:2982 / 3015 / 3650.
- **Guard-the-guard pattern** — tests/test_edge_flag_exposure.py:132-135, tests/test_frozen_imports.py:137-156, tests/test_edge_service_modes.py:47-52, tests/test_edge_manual.py:95 and tests/test_packaging_data_files.py passim derive their expectations from the shipped sources (main.go, REGISTRY, build.py) rather than hardcoding them, and assert their own extraction is non-empty. This is the section's dominant style and it is sound.
- **Platform/optional-dependency skips that DO run in CI** — Pillow skips (test_art_fetch, test_library_catalog): CI installs Pillow (ci.yml "Install test dependencies"). LZ4 skips (test_disc_identity): CI installs lz4, and the real-CHD test is additionally named in the post-libchdr-build step (ci.yml:146-152). Go skip (test_router_status:142): CI installs Go. Symlink skips: Linux runner creates symlinks. All explained, all reachable — not permanent skips.
- **tests/test_chd_cuebin.py dread loop (:416-420)** — The bounded 20-iteration drain loop's `break` is backstopped by direct assertions on the server's internal `entries` list (:422-428), so a never-terminating listing still fails on the listed-names assertions. Weak-but-real.

---

*Clone state on completion: `git status` clean at c5f021c4d386. No files in the clone were written.*
