# PS2-Servers — Python test suite, second half (n–z) — blind redo audit

- **Clone:** `~/workspace/audit-clones-2026-11-13/PS2-Servers` @ `c5f021c4d38698860f56b03498adc261dbb8d8dd` (HEAD verified by `git rev-parse`).
- **Scope:** every `tests/test_*.py` sorting from `test_nfs4_server.py` through `test_version_consistency.py` inclusive — **84 files, 18,433 lines** (counted by script), all read fully.
- **Canonical runner** (`.github/workflows/ci.yml:97`, `README.md:439`): `python -m unittest discover -s tests -t. -v`. Findings about direct-script execution are scoped to that mode explicitly.
- **Headline question — does the test drive production code or a fake?** For this half, mostly production: the SMB2/SMBv1/UDPFS protocol tests overwhelmingly run the real server over real loopback sockets or real handlers (see "Checked and cleared"). The defects below are concentrated in orphaned tests, skip/vacuity patterns, source-text tests, and a small set of fakes that mask the behaviour they claim to pin.

---

### PYTESTB-01 — Mid-file `unittest.main()` orphans 23 tests in test_smb2_server.py under direct execution
- **Category:** 7
- **Locations:** tests/test_smb2_server.py:616-617 (main block), with 8 test classes defined after it at lines 620, 697, 736, 758, 808, 870, 906, 915 (file is 944 lines)
- **Problem:** `if __name__ == "__main__": unittest.main()` sits mid-file. `unittest.main()` calls `sys.exit`, so running `python tests/test_smb2_server.py` — a natural way to run one file while debugging, and the style several sibling files document in their docstrings ("Run: python -m unittest …" is safe, bare-script is not distinguished) — silently never defines or runs MalformedRequestBuffers (4 tests), RenameSafety (3), ParentEntry (1), DomainHandling (3), SecurityBufferFraming (5), NeutrinoClientShape (3), ShareNameCollisions (1) and BindHint (3): 23 tests by AST count. Proven by execution in a /tmp copy: direct run reports "Ran 33 tests … OK", `python -m unittest tests.test_smb2_server` reports "Ran 56 tests … OK" — both green, so the loss is invisible. Under CI's `unittest discover` the classes *are* collected (the main block is name-guarded), so this is a direct-execution orphaning, not a CI gap — but a developer running the file directly gets a green result from 59% of it.
- **Fix:** Move the `if __name__ == "__main__": unittest.main()` block to the end of the file.
- **Benefit:** Direct execution runs the same 56 tests CI does; no silent partial-green.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYTESTB-02 — Same mid-file `unittest.main()` defect orphans 5 tests in test_smb2_paths.py
- **Category:** 7
- **Locations:** tests/test_smb2_paths.py:202-203 (main block), class WindowsDeviceNames at line 206 (file is 249 lines)
- **Problem:** Identical pattern to PYTESTB-01: the main block precedes the WindowsDeviceNames class (5 tests). Proven by execution in a /tmp copy: direct run "Ran 14 tests … OK" vs discover "Ran 19 tests … OK". The orphaned class covers Windows reserved device names — exactly the tests a developer on Windows would run directly.
- **Fix:** Move the main block to the end of the file.
- **Benefit:** Direct execution and discover agree on the test count.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYTESTB-03 — Cross-implementation encoder test converts a Go timeout into a skip
- **Category:** 6
- **Locations:** tests/test_router_status.py:177-178
- **Problem:** In `CrossImplementation.test_go_and_python_encoders_agree`, a `subprocess.TimeoutExpired` from `go run` (timeout=180s) is caught and turned into `self.skipTest("go run timed out")`. A hung or pathologically slow Go encoder — precisely the divergence this test exists to catch — is therefore reported as a skip, not a failure, and CI stays green. The same file correctly `self.fail()`s when `go run` exits non-zero (the encoders "were never compared"), and the sibling parity test in tests/test_smb_wire_parity.py:104 does the same; only the timeout path is downgraded. (The absence skips at lines 142/145 — no Go toolchain, no Edge source — are legitimate environment skips and are not part of this finding.)
- **Fix:** Let `TimeoutExpired` fail the test (or re-raise as a failure with the timeout noted), as the non-zero-exit path already does.
- **Benefit:** A wedged Go build can no longer masquerade as an environment skip in the one test that compares the two status encoders byte-for-byte.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYTESTB-04 — Banner address test asserts nothing when the host returns no addresses
- **Category:** 6
- **Locations:** tests/test_smb2_banner.py:125-131
- **Problem:** `LocalAddressListingTests.test_lists_only_real_ipv4_addresses` places every assertion inside `for ip in smb2_server._local_ipv4_addresses():`. If that function returns an empty list — e.g. a regression that makes it return nothing, or a sandboxed/container host with no non-loopback IPv4 — the test passes having asserted nothing. The failure mode it guards against (loopback or IPv6 leaking into the banner) and the failure mode "returns nothing at all" are indistinguishable to it.
- **Fix:** Capture the list first, assert it is non-empty, then run the per-address assertions.
- **Justification:** The fix adds one assertion; it is the only way to make the existing assertions reachable-by-construction rather than by host luck.
- **Benefit:** The test can actually fail on the hosts where it currently vacuously passes, including restricted CI sandboxes.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYTESTB-05 — systemd unit tests assert only inside loops over parsed content, with no non-emptiness guard
- **Category:** 6
- **Locations:** tests/test_systemd_units.py:119 (test_template_instance_keys_are_real_servers), tests/test_systemd_units.py:205 (test_readwritepaths_tolerates_a_missing_directory)
- **Problem:** Both tests derive their subjects by parsing the shipped unit files (template instances / `ReadWritePaths` entries) and assert only inside the resulting loops. If the parsing finds nothing — a renamed section, a changed directive spelling, a template that stops matching the extraction pattern — the loops run zero times and the tests pass. The tests therefore cannot distinguish "units are correct" from "my extraction stopped seeing the units".
- **Fix:** Assert each extracted collection is non-empty before looping (and, for the instance-keys test, pin the expected instance set size or names).
- **Justification:** Adds guard assertions only; no new machinery.
- **Benefit:** A parsing drift in the test itself stops being a silent pass over the repo's service definitions.
- **Effort:** S · **Risk:** Low · **Confidence:** Medium (READ)

### PYTESTB-06 — Share-name test is tautological: it reads back the dict it just passed in
- **Category:** 6
- **Locations:** tests/test_smbv1_share_and_credentials.py:182-187
- **Problem:** `TheShareNameIsHonoured.test_a_named_share_is_found` constructs `SmbServer({"roms": Share("roms", d)}, …)` and then asserts `"roms" in server.shares`. That reads back exactly the mapping handed to the constructor; it performs no tree-connect by name, so a server that stored shares under a normalised/other key — or that failed to resolve "roms" at connect time — would still pass. The class name claims the share *name* is honoured on the wire; the test observes only dict storage.
- **Fix:** Drive a real TREE_CONNECT for the name "roms" through the server (the file already has socket-level helpers in neighbouring classes) and assert the connect succeeds, or delete the test if constructor storage is covered elsewhere.
- **Benefit:** The named-share behaviour the class advertises becomes observable; today it is structurally unobservable.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYTESTB-07 — Setup-guide tests assert substrings of the GUI source instead of behaviour
- **Category:** 7
- **Locations:** tests/test_setup_guide.py:36-54 (test_gui_button_connected_once, test_first_run_invitation_and_persistent_status), tests/test_setup_guide.py:90-92 (test_close_callback_distinguishes_finish_from_dismissal)
- **Problem:** Several tests read `launcher/gui.py` / `launcher/setup_guide.py` as text and `assertIn` exact source fragments — e.g. counting that `text="PS2 setup guide…"` occurs once, and pinning literal lines such as `self.root.after(1200, self._offer_ps2_setup_guide)`. These fail on any behaviour-preserving refactor (renamed variable, reformatted call) and pass on behaviour-breaking changes that keep the strings (e.g. the callback wired but never invoked due to an early return elsewhere). They pin spelling, not the invitation/close semantics their names claim.
- **Fix:** Where the GUI cannot be instantiated headlessly, keep at most one smoke-level source check and move the semantic assertions to the guide's own state machine (the file's other tests already exercise `setup_guide.py` data directly); otherwise delete the substring pins.
- **Benefit:** Refactors stop breaking tests that were never measuring behaviour; real wiring regressions are caught by tests that execute the path.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ)

### PYTESTB-08 — Stop-all tests are AST inspections of gui.py, not executions of stop-all
- **Category:** 7
- **Locations:** tests/test_status_client.py:206-272 (class StopAllStaysUnconditional)
- **Problem:** These tests `ast.parse` `launcher/gui.py`, locate `LauncherApp.stop_all`, and walk its Call nodes to prove it never calls prompting functions. The docstring discloses why (the GUI "cannot be instantiated headlessly"), and the property guarded — stop-all must never block on a prompt — is real. But the check is syntactic: a prompt introduced via a helper whose name is not in the watched set, or via `getattr`/indirection, passes; conversely a comment-free rename of a watched helper fails it. Other in-scope tests do instantiate GUI pieces with a skip-on-no-display pattern (e.g. tests/test_verbose_default_and_log_stamps.py's TerminalStamp test imports `launcher.gui` and skips only if tkinter is absent), so "cannot be instantiated" is stronger than the suite's own practice elsewhere.
- **Fix:** Keep the AST check if desired, but label it as a source lint in the class name/docstring, and add one behavioural test that calls the stop path with the prompt functions stubbed to raise, under the same skip-if-no-tkinter guard used elsewhere.
- **Justification:** The added test is the only part that observes the claimed behaviour; the AST half alone cannot see indirect prompts.
- **Benefit:** The "unconditional" guarantee rests on execution, not on call-graph spelling.
- **Effort:** M · **Risk:** Low · **Confidence:** Medium (READ)

### PYTESTB-09 — "Every edge target has a purpose" test checks only that label strings exist
- **Category:** 7
- **Locations:** tests/test_release_downloads.py:71 (test_every_edge_target_has_a_purpose)
- **Problem:** The test body loops over the Edge target labels and performs only `assertIn(label, script_text)` against the build script text. It verifies that each label string appears somewhere in the script — not that the target has a purpose, a distinct output, or any effect. A target reduced to a no-op echo would still pass, and the test name overstates the guarantee to anyone reading a failure list.
- **Fix:** Either assert something about each target's block in the script (e.g. the artefact name it produces), or rename the test to what it checks (labels are referenced in the script).
- **Benefit:** The test's claim matches its evidence; release-target rot becomes detectable.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYTESTB-10 — POSIX permission test passes by bare `return` on Windows instead of skipping
- **Category:** 7
- **Locations:** tests/test_ra_credentials.py:76-78
- **Problem:** `test_posix_insecure_permissions_are_rejected` begins `if os.name == "nt": return` — a bare return, so on Windows the test reports as *passed*, not skipped, while having run nothing. Test counts and pass reports on Windows therefore overstate coverage by one, and a future reader cannot tell from results that the POSIX branch never ran. Mitigation, stated in the test's own comment: the platform roundtrip test above it does exercise real DPAPI on Windows, so the credential store is not untested there — the defect is the reporting, not total absence of coverage.
- **Fix:** Use `self.skipTest("POSIX permission bits do not apply on Windows")` instead of the bare return.
- **Benefit:** Windows runs report an honest skip; pass counts mean the test ran.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYTESTB-11 — Identical helper bodies duplicated across test files
- **Category:** 2
- **Locations:** tests/test_ra_account_worker.py:31 (`stalled`), tests/test_ra_resolver_process.py:15 (`stuck`); tests/test_smbv1_compressed.py:44 (`_request`), tests/test_smbv1_read_after_write.py:22 (`_request`)
- **Problem:** Census by AST body-hash across all 84 files found **zero** duplicated *test-method* bodies — but the helper layer duplicates: `stalled` and `stuck` are the same infinite-sleep job body under two names in two RetroAchievements test files, and the SMBv1 `_request` SimpleNamespace factory is copied verbatim into two files. Each copy can drift independently (e.g. a new field added to one `_request` only), producing file-dependent fake shapes for the same production request type.
- **Fix:** Hoist each pair into the shared test-support module the suite already uses for fixtures, and import it.
- **Benefit:** One definition per fake shape; drift between copies becomes impossible.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYTESTB-12 — Two identical payload builders under different names inside test_transfer_limits.py
- **Category:** 2
- **Locations:** tests/test_transfer_limits.py:109 (read_payload), tests/test_transfer_limits.py:118 (write_req_payload)
- **Problem:** `read_payload(handle, size)` and `write_req_payload(handle, size)` have byte-identical bodies — both return `struct.pack("<BBBBiI", 0, 0, 0, 0, handle, size)`. Two names for one wire shape invites the reader to believe READ and WRITE_REQ headers differ where the test itself says they don't, and a future edit to one (e.g. adding a flags byte) silently desynchronises the pair.
- **Fix:** Delete one and call the other from both places (or keep one name that says what the shape is).
- **Benefit:** Less code, and the read/write header equivalence the file relies on is stated once.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYTESTB-13 — Whole-registry launcher test asserts only that build_argv returns a list
- **Category:** 6
- **Locations:** tests/test_udpfs_config.py:360-382 (LauncherModeLaunchTests.test_every_mode_builds_argv_from_defaults)
- **Problem:** The class docstring claims "Every registered mode must build an argv from its own field defaults", guarding against a builder NameError presenting as a mode that refuses to start. The sole assertion is `assertIsInstance(server.build_argv(values), list)`. A builder that returns `[]`, or a list of nonsense, for every mode passes; only `None`/non-list returns and exceptions fail. The NameError regression is covered (an exception fails any test), but "builds an argv" is not — an empty argv launches nothing and would pass here while failing the sibling per-mode tests only for the modes those cover.
- **Fix:** Assert the returned list is non-empty, and for folder/file modes assert the supplied root/target value appears in it.
- **Justification:** Adds assertions to an existing test; no new scaffolding.
- **Benefit:** The registry-wide guard matches its stated claim, not just its crash case.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYTESTB-14 — Real-socket recv-buffer test's only assertion cannot fail
- **Category:** 6
- **Locations:** tests/test_udpfs_config.py:272-279 (test_widen_on_a_real_socket)
- **Problem:** The test calls `udpfs._widen_recv_buffer` on a real UDP socket and asserts only `getsockopt(SO_RCVBUF) > 0`. The file's own `_FakeSock` docstring (same file) states the problem plainly: "a real socket always reports a positive buffer, which would let a no-op implementation pass." The fake-socket tests around it do pin the widen/no-shrink/best-effort logic properly, so this real-socket test adds only the illusion of integration coverage: replace `_widen_recv_buffer` with a no-op and it still passes.
- **Fix:** Assert the resulting buffer is at least the requested `DATA_RECV_BUFFER_BYTES` (allowing for the kernel's doubling/clamping by comparing against a pre-call baseline: post-call value must exceed the pre-call value when the pre-call value was smaller), or delete the test and let the fake-socket tests carry the logic.
- **Benefit:** The one real-socket test in the class becomes capable of failing.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYTESTB-15 — FakeServices answers silent success to any PowerShell command it doesn't recognise
- **Category:** 6
- **Locations:** tests/test_smb2_take_445.py:73 (FakeServices.run), fall-through return at line 118
- **Problem:** `FakeServices.run` regex-matches production's PowerShell command strings for Get/Stop/Start-Service; any command matching none of the patterns falls through to `return subprocess.CompletedProcess(args, 0, "", "")` — exit 0, empty output. If production's take-445 code starts issuing a new or respelled command (a fourth verb, a renamed parameter the regexes miss), the fake reports success and the tests keep passing while the real service control would do something else entirely. The docstring discloses that service control is simulated; the silent-success default for *unrecognised* commands is the sharp edge.
- **Fix:** Make the fall-through raise AssertionError (or return a non-zero exit with stderr naming the unmatched command), so an unmatched command is loud in tests.
- **Benefit:** Production command drift breaks the test instead of being absorbed by the double.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYTESTB-16 — Tests patch shared stdlib module objects, so a missed restore leaks into the whole discover run
- **Category:** 7
- **Locations:** tests/test_udpfs_live_discovery_handoff.py:239-242 and passim (`time.monotonic = lambda: fake_now`, restored by hand in finally); tests/test_udpfs_fallback_generation.py:47,51 (`patch.object(CORE.threading, "Thread")`, `patch.object(CORE.time, "sleep")`); tests/test_udpfs_stall_report.py:59,117,189,203 (`patch.object(UDPFS.os, "name", …)`, `patch.object(UDPFS.threading, "Thread", …)`); tests/test_udpfs_symlink_path_ops.py:374 (`patch.object(srv.os, "lstat", …)`)
- **Problem:** `CORE.threading`, `UDPFS.os`, `srv.os` etc. are not private copies — they are the process-wide stdlib `threading`/`os`/`time` modules, imported by reference into the production modules. Patching their attributes patches them for every module in the single `unittest discover` process. The manual `time.monotonic` assignment in the handoff tests is restored in `finally`, and the `mock.patch.object` uses are context-scoped, so this is fragility rather than an observed leak — but any future edit that returns early inside one of these regions, or an exception in a restore path, leaves `Thread`, `os.name`, `os.lstat` or `monotonic` replaced for every subsequently-run test file, producing failures (or worse, passes) far from the cause.
- **Fix:** Where production code reads the attribute through its own module namespace, patch it there (e.g. `patch.object(CORE, "time", fake)` is not possible for module attributes — instead patch the specific attribute on the production module object when it holds its own reference); where it doesn't, prefer injecting the fake at the server-object level as these files already do for sockets. At minimum, convert the manual `time.monotonic` assignments to `mock.patch.object(time, "monotonic", …)` context managers so restoration is structural.
- **Benefit:** One test file's fakes can no longer contaminate the other 83 files in the shared discover process.
- **Effort:** M · **Risk:** Medium · **Confidence:** Medium (READ)

### PYTESTB-17 — Five test files each exec a private copy of ps2servers_core.py under a different module name
- **Category:** 7
- **Locations:** tests/test_udpfs_fallback_generation.py:18 (`ps2servers_core_fallback`), tests/test_udpfs_inform_telemetry.py:13 (`ps2servers_core_inform_telemetry`), tests/test_udpfs_startup_diagnostics.py:16 (`core_startup_diagnostics`), tests/test_udpfs_live_discovery_handoff.py:23 (`ps2servers_core_handoff`), tests/test_udpfs_protocol_negotiation.py:14 (`ps2servers_core`)
- **Problem:** Each file loads `udpfs_server/ps2servers_core.py` fresh via `importlib.util.spec_from_file_location` under its own module name, creating up to five distinct module objects — with distinct `AutoUdpfsServer`/`Session` classes and module-level state — inside one discover process, none of them the `ps2servers_core` that other test files (and the launcher path) import normally. Within each file the copy is self-consistent, so tests pass; but class identity, `isinstance` reasoning, and any cross-file patching silently operate on different classes, and a reader cannot tell from a failure which copy misbehaved. It also quintuples import side effects of the core module per run.
- **Fix:** Import `ps2servers_core` normally (the directory is already put on `sys.path` by these files) and reserve spec-loading for the one case that genuinely needs an isolated copy, with a comment saying why.
- **Benefit:** One core module, one class identity, across the UDPFS test files; failures point at the code production actually imports.
- **Effort:** M · **Risk:** Medium · **Confidence:** Medium (READ/INFERRED)

---

## Checked and cleared (verified non-findings)

- **test_session_cap.py vs production:** the tests target base `UdpfsServer._get_or_create_session`, and the shipped `AutoUdpfsServer._get_or_create_session` (`udpfs_server/ps2servers_core.py:185-186`) delegates via `super()` — the base cap logic *is* the shipped path.
- **test_protocol_mode_selector.py:** its hardcoded wire set `{"auto","standard","modulo"}` matches production (`udpfs_server/ps2servers_core.py:111` and the argparse `choices` at :548). Its LegacyKeySurvivesTheRealLoadPath class explicitly documents and repairs an earlier pass-for-wrong-reason pattern — good practice.
- **test_router_status.py's hardcoded `DEFAULT_FALLBACK_SECONDS = 0.25`** matches production (`udpfs_server/ps2servers_core.py:57`) — agreement, not drift (the comment in the test admits the duplication).
- **test_ps1_vcd.py's patch of `launcher.ps1_vcd.hash_vcd`** is effective, not vacuous: `launcher/game_library.py:382-384` imports `hash_vcd` from the module at call time inside `hash_image`, so the patched attribute is the one called.
- **Duplication census (AST body-hash, scripted):** zero exact-duplicate test-method bodies across the 84 files; duplication exists only at helper level (PYTESTB-11/12).
- **Strong real coverage, no finding:** test_nfs4_server.py (independent XDR encoding in the test, drives real `Nfs4Server.handle_record`; independence rationale stated at lines 11-12), test_smb2_server.py's collected classes (real sockets, own client), test_smbv1_logon_required.py (real `serve_conn` over socketpair), test_ra_owned_service.py / test_ra_resolver_process.py (real UDP loopback / real subprocess), test_theme.py (sentinel-palette patch proves a live read), test_udpfs_symlink_path_ops.py and test_udpfs_write_needs_writable_handle.py (real handlers / real receive loop, both server classes), test_smb2_independent_client.py (independent smbprotocol client; skips only when the library is absent). test_smb2_wire.py's docstring honestly discloses that its StructureSize pins are transcribed from the implementation rather than re-derived from the spec — a disclosed limitation, not hidden vacuity. test_smb2_signed_sessions.py's shared-`smb2_crypto` circularity is mitigated by published-vector known-answer tests in test_smb2_signing.py.

## Files read

All 84 in-scope files, read fully (tests/): test_nfs4_server.py, test_opl_http_runner.py, test_orbit_reference_wire.py, test_packaging_data_files.py, test_path_access.py, test_portable_config.py, test_protocol_mode_selector.py, test_ps1_vcd.py, test_ra_account.py, test_ra_account_worker.py, test_ra_compressed_hash.py, test_ra_credentials.py, test_ra_dependency.py, test_ra_evaluator.py, test_ra_notifications.py, test_ra_overview.py, test_ra_owned_service.py, test_ra_protocol.py, test_ra_receiver.py, test_ra_resolver_process.py, test_ra_session.py, test_ra_session_client.py, test_ra_sets.py, test_ra_sounds.py, test_ra_submissions.py, test_ra_supervisor.py, test_ra_watchlist.py, test_ra_web.py, test_raw_storage.py, test_release_downloads.py, test_reset_settings.py, test_retroachievements.py, test_riptopl_profile.py, test_router_status.py, test_server_override_contract.py, test_session_cap.py, test_session_shutdown.py, test_session_summary.py, test_session_view.py, test_settings_feedback.py, test_setup_guide.py, test_smb2_auth.py, test_smb2_banner.py, test_smb2_independent_client.py, test_smb2_libsmb2_compat.py, test_smb2_paths.py, test_smb2_server.py, test_smb2_share_name.py, test_smb2_signed_sessions.py, test_smb2_signing.py, test_smb2_take_445.py, test_smb2_wire.py, test_smb_wire_parity.py, test_smbv1_compressed.py, test_smbv1_diagnostics.py, test_smbv1_logon_required.py, test_smbv1_read_after_write.py, test_smbv1_share_and_credentials.py, test_smbv1_write_semantics.py, test_status_client.py, test_status_dot.py, test_systemd_units.py, test_theme.py, test_transfer_limits.py, test_tray_linux.py, test_udpbd_access.py, test_udpbd_storage_modes.py, test_udpfs_ack_progress.py, test_udpfs_bind_control.py, test_udpfs_config.py, test_udpfs_dread_skip_entry.py, test_udpfs_fallback_generation.py, test_udpfs_handoff_retried_write.py, test_udpfs_inform_telemetry.py, test_udpfs_live_discovery_handoff.py, test_udpfs_protocol_negotiation.py, test_udpfs_resent_request.py, test_udpfs_stall_report.py, test_udpfs_startup_diagnostics.py, test_udpfs_symlink_path_ops.py, test_udpfs_write_needs_writable_handle.py, test_verbose_default_and_log_stamps.py, test_verify_docs.py, test_version_consistency.py.

Production files read in part to adjudicate fake-vs-real questions: `udpfs_server/ps2servers_core.py` (session creation, protocol-mode choices, fallback constant), `launcher/game_library.py` (hash_image), `.github/workflows/ci.yml` and `README.md` (canonical test invocation).

## Files not read (in scope)

None — all 84 in-scope test files were read fully.
