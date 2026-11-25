## Baseline

- **Where:** full copy of `PS2-Servers @ c5f021c4d386` at `/tmp/ps2s` (working tree copied from the clone, `.git` excluded; clone never modified).
- **Command:** `cd /tmp/ps2s && timeout 1200 python3 -m unittest discover -s tests -v` (Python 3.12.3). `python3 -m pytest` was tried first and is unavailable in this sandbox (`No module named pytest`), so the unittest fallback specified in the task was used. Run took 230.100s, exit code 1.
- **Totals (exact, from the runner summary `Ran 1544 tests … FAILED (failures=3, errors=73, skipped=80)`):** total run **1544**, passed **1388**, failed **3**, errors **73**, skipped **80**.
- **Event vs. test accounting:** the 76 failure/error events come from **54 unique tests**. 22 events are secondary errors in `stop()`/teardown (a second `PermissionError` from the wake-up `sendto` in e.g. `tests/test_udpfs_handoff_retried_write.py:133` and the `test_udpfs_write_needs_writable_handle` harness) re-reporting tests that had already errored in their bodies — 19 in `test_udpfs_write_needs_writable_handle`, 3 in `test_udpfs_handoff_retried_write`.

### Per-failure classification (all 54 unique failing/erroring tests)

| Class | Unique tests | Evidence |
|---|---|---|
| **UDP-blocked environment (BLOCKED-ENV)** | **52** | Direct: 48 tests whose tracebacks end in `PermissionError: [Errno 1] Operation not permitted` raised at a UDP `sendto` — `test_ra_owned_service` 18, `test_udpfs_write_needs_writable_handle` 19, `test_router_status` 5, `test_udpfs_handoff_retried_write` 3, `test_ra_resolver_process` 2, `test_session_summary` 1 (e.g. `tests/test_ra_owned_service.py:252` `self.client.sendto(...)`; `udpfs_server/multiclient_selftest.py:117` `self.sock.sendto(...)`). Downstream: all 4 `test_status_client` failures — 3 FAILs (`test_reads_a_real_reply_over_the_wire`, `test_hex_string_port_is_parsed`, `test_silence_is_none_not_an_exception`) plus the `KeyError: 'state'` ERROR in `test_records_per_target_and_marks_silence_unknown`. Traced: `launcher/status_client.py:91-104` opens a `SOCK_DGRAM` socket, `sendto`s the query and catches `OSError`, returning `None`; the test's own server records `queries == 0` ("the query never arrived", `tests/test_status_client.py:103`), so the replies the assertions expect can never arrive with UDP sends blocked. |
| **Copy-environment (`.git` excluded from the /tmp copy)** | **1** | `test_attribution_policy.AttributionWorkflowTests.test_tag_with_no_new_commits_does_not_fail_validation` — ERROR at `tests/test_attribution_policy.py:22`: `git tag -a … HEAD` in the repo root exits 128 because the copy has no `.git`/`HEAD`. Not UDP, not a repo defect in a real checkout (see PYTESTA-01 for the separate design problem this exposes). The two `test_line_endings` skips ("git ls-files failed; not a checkout?", "init script not in HEAD") have the same cause. |
| **Genuine failure (not environment-explained)** | **1** | `test_nfs4_server.SocketTests.test_endless_empty_fragments_close_the_connection` — ERROR `TimeoutError` at `tests/test_nfs4_server.py:932` on a **TCP** `sock.recv(10)` that never sees the connection close. TCP loopback demonstrably works in this sandbox (the HTTP, SMB and cooperative-stop tests in the same run pass over real TCP sockets), and nothing in the trace touches UDP, so this is not traceable to the sandbox UDP block. Recorded as a genuine single failure in this environment; root cause (server behaviour vs. timing) not determined within this section's scope. |

- **Skipped (80):** environment/feature gates stated by the tests themselves — no display / no graphical display (42 across the suite, incl. the GUI tests in this half), `libchdr is not available` (6), `smbprotocol is not installed` (6, missing-dependency environment), native achievement engine not built (6), no Go toolchain (4), pinned libchdr not built (3), Windows-only tests (named-pipe IPC, kernel mutex, PowerShell, onefile bootstrap; 6), no POSIX shell/git checkout (2, see above), no non-loopback IPv4 (1), remainder single platform gates. No skip in this half was caused by the UDP block.
- **In-scope (a–n) baseline result:** of the 54 unique failing tests, exactly **1** is in this section's half (`test_attribution_policy`, copy-environment above). All other in-scope tests passed or skipped on their stated display/libchdr gates. In-scope collection census (script): **516 tests** collected across the 36 in-scope `test_*.py` files.

---

# Findings — Python test suite, first half (a–n)

### PYTESTA-01 — The attribution test mutates, and depends on, the developer's real checkout
- **Category:** 7
- **Locations:** tests/test_attribution_policy.py:22-40
- **Problem:** The suite's only test of `.github/workflows/attribution-policy.yml` runs `git tag -a attribution-empty-range-<pid> HEAD` **in the repository under test** (`cwd=ROOT`), extracts the workflow's shell script, runs it, and deletes the tag in a `finally`. Three consequences, one of them EXECUTED in this baseline: (1) in any `.git`-less copy (source tarball, this audit's copy) the test errors with git exit 128 instead of skipping — it checks only for `bash`, never for a usable checkout; (2) a hard kill between create and delete leaves a stray `attribution-empty-range-*` tag in the user's real repo; (3) the test writes to the very repo it is auditing, so it cannot run in a read-only checkout. The PID-suffixed tag name mitigates parallel runs but none of the above.
- **Fix:** Build a throwaway repo in a temp directory (`git init`, one empty commit), copy or reference the workflow script against that repo's `HEAD`, and skip cleanly when `git rev-parse HEAD` fails in `ROOT`. The workflow script itself takes `BEFORE`/`AFTER` from the environment, so it does not need the real history.
- **Benefit:** The test runs in tarballs, read-only checkouts and sandboxes; running the suite can never leave tags behind in the user's repo.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ|EXECUTED — failed in the baseline run for exactly the `.git` reason)

### PYTESTA-02 — Eight test files silently run zero tests when executed directly
- **Category:** 7
- **Locations:** tests/test_achievement_loader.py:1-48 · tests/test_achievement_viewer.py:1-86 · tests/test_caduceus_reference_wire.py:1-60 · tests/test_caduceus_setup.py:1-91 · tests/test_desktop_instance.py:1-99 · tests/test_discord_presence.py:1-204 · tests/test_game_library.py:1-299 · tests/test_library_panel.py:1-360 (script census: these 8 of the 36 in-scope files contain no `unittest.main()`; the other 28 all end with the `if __name__ == "__main__": unittest.main()` guard at the final line)
- **Problem:** `python tests/test_game_library.py` (etc.) exits 0 having run nothing — no error, no output, no tests. Discovery and `python -m unittest tests.test_game_library` work, so CI is unaffected, but the direct-execution path — the one a developer reaches for when debugging a single file — reports success for a run that never happened. This is the same failure family `tests/__init__.py`'s docstring says already hid a failing test on main once ("CI silently runs whatever handful of modules are named by hand").
- **Fix:** Add the same two-line `__main__` guard the other 28 files already carry to these 8 files. No new mechanism; pure consistency with the suite's own convention.
- **Benefit:** A direct run can never again masquerade as a pass; the suite has one invocation convention instead of two.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — census by AST/script over all 36 files)

### PYTESTA-03 — The Edge flag-extraction helpers are copied verbatim between test files
- **Category:** 2
- **Locations:** tests/test_edge_manual.py:26-28 and :71-80 · tests/test_edge_service_modes.py:26-28 and :208-218 · (near-copy) tests/test_edge_flag_exposure.py:96-111, tests/test_edge_service_modes.py:224-236
- **Problem:** `_read()` is byte-identical in `test_edge_manual.py` and `test_edge_service_modes.py`, and `_flags_of()` (extract a Go function's `fs.*("name", …)` flag names from `main.go`) is AST-identical in both files — only the comments differ (script census: exact AST-dump match). A third variant of the same "slice one section/function out of a text file" logic exists as `_section()`/`_section_options()`/`_udpfs_flags()` across the same three files. These parsers are the load-bearing part of the Edge packaging guards: if the Go source layout changes (e.g. `fs.Var` gains a new shape), each copy must be found and fixed separately, and a copy that is missed degrades silently to "no flags found" in exactly the tests whose job is noticing missing flags.
- **Fix:** Move `_read`, `_flags_of` and the section slicer into one shared tests helper (e.g. alongside `tests/library_fixtures.py`) and import them in the three Edge files; delete the copies.
- **Benefit:** One parser to fix when `main.go` changes shape; the three Edge guard files stay focused on their distinct assertions.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ|EXECUTED — AST census run by script)

### PYTESTA-04 — The shared ISO fixture lives inside a test module — and one consumer re-implements it anyway
- **Category:** 2
- **Locations:** tests/test_disc_identity.py:34-59 (`iso_fixture`) · tests/library_fixtures.py:31 · tests/test_library_identity.py:14 · tests/test_library_index.py:13 · tests/test_game_library.py:41,74 (imports) and :266-299 (inline re-implementation)
- **Problem:** `iso_fixture()` — the synthetic ISO9660 builder half the suite depends on — is defined in `test_disc_identity.py`, so `library_fixtures.py` and at least four other test files import a helper out of a sibling *test* module; renaming or splitting that test file breaks the fixture library for every consumer. Worse, `test_game_library.py` imports `iso_fixture` twice (lines 41, 74) and then, in `test_native_ps2_hash_matches_independent_boot_name_and_elf_digest` (266-299), hand-rolls a second private ISO9660 builder (`record()` plus manual PVD/directory assembly, ~30 lines) for a case the shared builder already covers — it accepts custom `boot` and `elf` arguments, which is all that test varies.
- **Fix:** Move `iso_fixture` (and its `record`/`both` helpers) into `tests/library_fixtures.py` or a `tests/fixtures` module, re-export it from `test_disc_identity` if its own tests want the local name, and rewrite the game-library hash test to call it with `boot=`/`elf=`. Delete the inline builder.
- **Benefit:** Fixture code has one home that is not itself a test file; one ISO builder to keep correct instead of two that can drift apart on exactly the byte layout the identity tests exist to pin.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ — all import sites grep-verified)

### PYTESTA-05 — test_library_preferences executes AST-extracted copies instead of the production methods
- **Category:** 6
- **Locations:** tests/test_library_preferences.py:17-33, :40-58, :60-68
- **Problem:** The file never instantiates `LibraryWindow` and never calls `save_preferences()` or `show_cover()` on a production object (grep-verified: the names occur only as AST search strings). Instead it parses `launcher/library_gui.py`, lifts the two method `FunctionDef`s out of the class, `exec`s them in a hand-built namespace containing only a fake `config`, and calls them with a `SimpleNamespace` fake `self`. Two failure modes follow: (1) false failures — the moment either method references any other module global, helper or import from `library_gui.py`, the extracted copy raises `NameError` for a harness reason, not a product reason; (2) unobservable behaviour — attribute wiring, the real `self`'s widget surface beyond the faked fields, and any interaction with the rest of the window are structurally outside what the test can see, while the test's name claims the preferences themselves were checked. The third test in the file (:60-68) is substring assertions over source text, which pin spelling, not behaviour. The suite already has the sounder pattern elsewhere — unbound production methods driven with a fake `self` (e.g. `LauncherLifecycleTests` in tests/test_directlink.py) — which keeps the real globals and the real function object.
- **Fix:** Call the real unbound methods (`LibraryWindow.save_preferences(fake_self)`) with the module imported normally, faking only the attributes/widgets the method touches; keep the AST only as the way to *find* nothing — it should not be the thing under test.
- **Benefit:** The test fails only when the production behaviour changes, survives internal refactors of `library_gui.py`, and actually exercises the shipped function objects.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ — production symbols' absence from the test verified by grep)

### PYTESTA-06 — The netinfo detailed-format test asserts only the formatter's own constant strings
- **Category:** 6
- **Locations:** tests/test_netinfo_and_smb.py:20-22 (with :15-17)
- **Problem:** `test_detailed_ip_info_formatting` calls the real `netinfo.detailed_ip_info()` against whatever host runs the suite, then asserts exactly two substrings: the literal header line and `"Custom IP..."`. The second is a hard-coded sentence inside the formatter itself (`launcher/netinfo.py:215`, grep-verified), and the first is its fixed title — so the test can only fail if someone edits those literals, and it asserts nothing about any address, adapter or formatting of actual detected data (which is host-dependent and therefore silently unexamined). Its `"Custom IP..."` assertion also duplicates the intent of `test_ip_choices_contains_custom_option` directly above it (:15-17) without testing the same code path.
- **Fix:** Patch `netinfo.all_ipv4` (the formatter's input) to a fixed address set and assert those addresses appear in the output in the formatted form; drop the duplicated literal assertion or point it at `ip_choices()` only.
- **Benefit:** The test would catch a formatter that drops, mangles or mislabels real addresses — currently impossible for it to do — and stops depending on the runner's network configuration.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYTESTA-07 — A traversal test whose name promises the opposite of what it asserts
- **Category:** 6
- **Locations:** tests/test_http_path_aware.py:208-218
- **Problem:** `test_traversal_and_unknown_paths_resolve_to_nothing` loops over four names; for `"../DVD/Game.iso"` it asserts the lookup **succeeds** (`assertIsNotNone`), because `normpath` folds the `..` back inside the whitelist. The inline comment explains the whitelist logic honestly, but the test *name* — the thing a reader scanning a green run, or a future editor deciding what may be changed, actually sees — states that traversal resolves to nothing. A later change that made folded traversal return `None` would "fix" the code to match the name and break this test for the wrong-looking reason; a change that widened real traversal would still leave a test named as if traversal were refused.
- **Fix:** Split the folded-`..` case into its own test named for what is actually guaranteed (e.g. `test_dotdot_that_folds_back_inside_the_root_is_a_normal_lookup`), leaving the refusal test's name true of every case in it. Words only; no assertion changes.
- **Benefit:** The suite's names stay a trustworthy summary of the server's path-safety guarantees — important in a file whose other tests are the traversal defence.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYTESTA-08 — The hardlink backup test passes vacuously where hardlinks are unavailable
- **Category:** 6
- **Locations:** tests/test_game_library.py:185-198
- **Problem:** `test_backup_rejects_live_database_and_hardlink` wraps `linked.hardlink_to(...)` in `try/except OSError: return`. On any filesystem where hardlinks cannot be created, the test therefore *passes* having verified only the live-database rejection — the hardlink rejection, half its name and the more interesting aliasing case, is silently untested with no skip recorded. Sibling tests in the same suite use the honest form for the same situation (`except OSError: self.skipTest(...)`, e.g. the symlink tests in tests/test_library_index.py and tests/test_library_recursive_scan.py). In this baseline's Linux environment hardlinks work and the full test did run, so this is a portability hole, not a local failure.
- **Fix:** Replace the bare `return` with `self.skipTest("Host cannot create hardlinks")` (after asserting the live-database half, or in a separate test method for the hardlink half).
- **Benefit:** A green run never again claims hardlink protection on a machine that could not exercise it; the skip shows up in the count where a reviewer can see it.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ|EXECUTED — full test ran and passed in the baseline)

### PYTESTA-09 — The display-guard + full-app construction prologue is copy-pasted through the GUI tests
- **Category:** 2
- **Locations:** tests/test_autostart_and_firewall_options.py:46-64 and the same block repeated at :84, :106, :133, :205, :228, :258, :282, :306 (script census: 9 × `SkipTest("no display")`, 10 × `tk.Tk()` in this file) · same shape at tests/test_about_page.py:106-152 and throughout tests/test_library_panel.py (7 × `tk.Tk()`)
- **Problem:** Every GUI test in `test_autostart_and_firewall_options.py` repeats the same ~9-line prologue — import tkinter, catch `ImportError`, construct `tk.Tk()`, catch `TclError`, raise the same skip — and then constructs a complete `LauncherApp`. The copies have already drifted: two tests in the file probe the display with a throwaway `tk.Tk().destroy()` before using the `_app_with_fake_servers` helper, the others construct the root directly, and `test_about_page.py`'s version additionally juggles environment save/restore that the autostart file does in `setUp`. On a machine *with* a display this is also the slowest pattern in the half: nine full application constructions for nine option assertions.
- **Fix:** Extract one `_require_display()` / app-factory helper (the pattern `test_gui_layout.py` already uses at class level with `setUpClass`) and have each test call it; keep per-test app construction only where a test genuinely needs a fresh app, and say so there.
- **Benefit:** One place to fix when Tk/display handling changes; the drift between the copies stops growing; display-machine runs get faster if construction can be shared per class.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ|EXECUTED — repetition counted by script)

---

## Negative results (hunted, not found in this half)

- **Duplicated test bodies:** AST census over all 36 files found **zero** exact-duplicate test-method bodies across files. (Duplicate *helpers* are PYTESTA-03.)
- **Orphaned tests:** no `unittest.main()` occurs mid-file in any in-scope file, no test methods sit after one, and the loader collects 516 tests from the 36 files — every in-scope test ran in the baseline except the stated display/libchdr skips.
- **Patching the thing under test into returning its expected value:** not found in the strong form. The mocks in this half target dependencies or use the fake-`self`/fake-socket pattern against real production methods (e.g. `test_directlink.py` `LauncherLifecycleTests`, `test_chd_cuebin.py`'s `_FakeLibchdr` standing in for the external libchdr, `test_library_identity.py` patching `inspect_disc` to *raise* in order to prove the cache path). The one structural exception — testing an extracted copy rather than the production object — is PYTESTA-05.
- **Vacuous/tautological assertions:** beyond PYTESTA-06/07/08, the hunted files' assertions bind to real return values, wire bytes or filesystem state; the deliberate "guard-the-guard" tests (e.g. `test_edge_flag_exposure.py` flag-extraction guard, `test_frozen_imports.py` hint-block guard) assert non-emptiness of the thing they parse and can fail.

## Files read

Full reads (38): tests/library_fixtures.py, tests/__init__.py, tests/test_about_page.py, tests/test_achievement_loader.py, tests/test_achievement_viewer.py, tests/test_art_fetch.py, tests/test_attribution_policy.py, tests/test_autostart_and_firewall_options.py, tests/test_caduceus_reference_wire.py, tests/test_caduceus_setup.py, tests/test_chd_cd_size.py, tests/test_chd_cuebin.py, tests/test_companion_fixtures.py, tests/test_cooperative_stop.py, tests/test_desktop_instance.py, tests/test_directlink.py, tests/test_directlink_unix.py, tests/test_disc_identity.py, tests/test_discord_presence.py, tests/test_edge_flag_exposure.py, tests/test_edge_manual.py, tests/test_edge_service_modes.py, tests/test_frozen_imports.py, tests/test_game_library.py, tests/test_gui_layout.py, tests/test_gui_smb2_start_needs_login.py, tests/test_http_direct_link.py, tests/test_http_path_aware.py, tests/test_http_server.py, tests/test_library_catalog.py, tests/test_library_identity.py, tests/test_library_index.py, tests/test_library_panel.py, tests/test_library_preferences.py, tests/test_library_recursive_scan.py, tests/test_line_endings.py, tests/test_linux_parity.py, tests/test_netinfo_and_smb.py.

Also read for baseline tracing / citation verification only: AGENTS.md (repo root), launcher/status_client.py (UDP query path, lines 91-104 via grep), launcher/netinfo.py (line 215 via grep), launcher/library_gui.py (`save_preferences` definition/wiring via grep), .github/workflows/attribution-policy.yml (existence/step name via grep), and the failing-test excerpts of tests/test_status_client.py (lines 60-110) needed to classify its baseline failures.

## Files not read (in scope)

None — every file in the assigned scope (tests/library_fixtures.py, tests/__init__.py, and all tests/test_*.py from test_about_page.py through test_netinfo_and_smb.py inclusive, 38 files, 8,934 lines) was read in full. All other test files (test_nfs4_server.py onward, o–z) belong to the second half and were not read, except the baseline-tracing excerpt of tests/test_status_client.py noted above.
