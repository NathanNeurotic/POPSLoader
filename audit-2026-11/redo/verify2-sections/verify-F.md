# Verification Batch F — RE-SERV-101 … RE-SERV-126 + Python Baseline (PS2-Servers)

- **Pin confirmation:** `git -C ~/workspace/audit-clones-2026-11-13/PS2-Servers rev-parse HEAD` → `c5f021c4d38698860f56b03498adc261dbb8d8dd` — matches the required pin exactly.
- **Clone hygiene:** clone used read-only for all reading/grep; `git status --porcelain` clean at the end, no `attribution-*` tags present. All execution ran in a `.git`-less copy at `/tmp/ps2sF` (mirroring the original baseline's `/tmp/ps2s`, `.git` excluded).
- **Environment:** Python 3.12.3, sandbox blocks UDP `sendto` (`PermissionError: [Errno 1] Operation not permitted`) — UDP failures classified, not verdicted as code defects.
- **Method:** refute-first — every citation grep/read-checked in the clone, counts re-derived by AST/script, direct-execution claims actually executed, full baseline re-run.

---

## BASELINE-PY — VERIFIED-DRIFT

- **Claimed:** `cd /tmp/ps2s && timeout 1200 python3 -m unittest discover -s tests -v` → 1,544 run = 1,388 pass / 3 fail / 73 errors / 80 skip; 76 events from 54 unique tests; classification 52 UDP-blocked / 1 copy-environment (attribution, needs `.git`) / 1 genuine (`test_nfs4_server…test_endless_empty_fragments_close_the_connection`, TCP `recv` timeout).
- **My reproduction (identical invocation, /tmp/ps2sF):** `Ran 1544 tests in 223.583s — FAILED (failures=3, errors=72, skipped=80)`, exit 1. So: **1,544 run / 1,389 pass / 3 fail / 72 errors / 80 skip**; **75 failure/error events from 53 unique tests**.
- **Classification of my 53 unique failing tests — identical to the claim except for the one missing test:**
  - **UDP-blocked: 52** — 48 direct `PermissionError` at UDP `sendto` (`test_ra_owned_service` 18, `test_udpfs_write_needs_writable_handle` 19, `test_router_status` 5, `test_udpfs_handoff_retried_write` 3, `test_ra_resolver_process` 2, `test_session_summary` 1; the 22 secondary teardown/`stop()` events claimed are 22 in mine too: 19 + 3 across the two UDPFS handoff/write files, each test reporting twice) + 4 downstream `test_status_client` (3 FAIL + `KeyError: 'state'` ERROR; its own message "the query never arrived", `tests/test_status_client.py:103`, reproduced verbatim in my log).
  - **Copy-environment: 1** — `test_attribution_policy…test_tag_with_no_new_commits_does_not_fail_validation`, ERROR at `tests/test_attribution_policy.py:22`, `git tag -a attribution-empty-range-<pid> … HEAD` exit 128 in the `.git`-less copy. Reproduced exactly.
  - **Genuine: 0 in my run.**
- **The claimed genuine failure did NOT reproduce:** `test_nfs4_server.SocketTests.test_endless_empty_fragments_close_the_connection` was `ok` in my full discover run, and passed **5/5 isolated re-runs** (2.5–5.1 s each). It is therefore **not established as a deterministic genuine failure**. It is, however, genuinely non-UDP (pure TCP loopback, `socket.create_connection(..., timeout=5)`, `tests/test_nfs4_server.py:889-893`) and structurally timing-fragile — see CANDIDATE F-2: the server must consume `MAX_RECORD//4 + 1` = 264,193 empty fragments one `recv` at a time before it may close, racing a 5 s socket timeout, so a timeout under full-suite load (the original run) vs. a pass unloaded (mine) is the expected flake signature. Correct classification: **intermittent/timing, root cause plausibly load-dependent; "genuine single failure" overstates what one observation proves.**
- **Drift summary:** every total is off by exactly that one test (errors 73→72, passed 1,388→1,389, events 76→75, unique 54→53). Run count, failures, and skips match exactly; the UDP/copy-environment classification matches test-for-test.

---

### RE-SERV-101 — VERIFIED
- **Citations:** `tests/test_attribution_policy.py:22-40` read in full: checks only `shutil.which("bash")` (ll.14-15, skip), then `git tag -a attribution-empty-range-{os.getpid()} HEAD` with `cwd=ROOT` (l.22), extracts the workflow script, runs it, deletes the tag in `finally` (ll.36-40). Workflow `.github/workflows/attribution-policy.yml:54-64` takes `BEFORE`/`AFTER` from env — the fix's premise holds.
- **Mechanism:** Exactly as claimed: mutates the real checkout, no usable-checkout guard, stray-tag risk on hard kill, cannot run read-only.
- **Execution:** Errored in my baseline for exactly the claimed reason (git exit 128 at line 22 in the `.git`-less copy). Clone itself untouched (no tags, clean status) because discover was never run against it.
- **Fix:** Throwaway temp repo + skip on `git rev-parse HEAD` failure — sound, LESS-NOT-MORE compliant.

### RE-SERV-102 — WEAKENED
- **Citations / census (verified):** My AST/script census over the 36 in-scope (a–n) files confirms exactly the 8 named files lack `unittest.main()` (`test_achievement_loader`, `test_achievement_viewer`, `test_caduceus_reference_wire`, `test_caduceus_setup`, `test_desktop_instance`, `test_discord_presence`, `test_game_library`, `test_library_panel`) and the other 28 end with the `__main__` guard. (Suite-wide there are 31 such files among 120 `test_*.py`, but the finding's scope is the 36, and within that scope it is exact.)
- **Mechanism / Execution (the stated impact is wrong as written):** The claim "`python tests/test_game_library.py` (etc.) exits 0 having run nothing — no error, no output" is **false for the cited invocation**. Executed in /tmp/ps2sF, **all 8 files exit 1** with `ModuleNotFoundError: No module named 'launcher'` (none inserts the repo root on `sys.path`, and Python puts `tests/` — not the root — on the path for a script run). The silent-exit-0 behaviour occurs only with the root already importable: `PYTHONPATH=. python3 tests/test_game_library.py` → exit 0, no output (verified), as does any environment where the package is otherwise importable. Module invocation works (`python -m unittest tests.test_game_library` → Ran 17, OK).
- **True scope:** a real consistency defect (8 files cannot be run directly in any mode that reaches the test code, unlike the 28), but the headline failure mode — a masquerading green pass — requires `PYTHONPATH`/installed-root conditions the finding does not state; the plain direct run is a loud import crash, not a silent pass.
- **Fix sanity:** Adding the two-line guard alone does **not** make `python tests/<file>.py` work for these 8 — the import crash precedes it (siblings *with* the guard, e.g. `tests/test_art_fetch.py`, also crash direct from the root for the same reason; see CANDIDATE F-1). The fix also needs the `sys.path` prologue several sibling files carry, or the finding should be re-scoped to the `PYTHONPATH=.` case.

### RE-SERV-103 — VERIFIED
- **Citations:** `_read` at `test_edge_manual.py:26-28` and `test_edge_service_modes.py:26-28` — source text identical. `_flags_of` at `test_edge_manual.py:71-80` / `test_edge_service_modes.py:208-218` — my script: **AST dumps equal** (only comments differ, as claimed). Third slicer family present: `_section` (manual:81, flag_exposure:102), `_section_options` (modes:223), `_udpfs_flags` (flag_exposure:85).
- **Mechanism:** Duplicated Go-flag parsers are the load-bearing extraction for the Edge guards; silent-degradation mode (`_flags_of` returns `set()` when the func is not found) confirmed in source.
- **Execution:** AST census run by me (above); baseline: all Edge tests passed.
- **Fix:** Hoist to a shared tests helper — sound, deletion-positive.

### RE-SERV-104 — VERIFIED
- **Citations:** `iso_fixture` defined `tests/test_disc_identity.py:34-59` (accepts `boot=`/`elf=`/`cnf=`/`nested=` etc.). Consumers grep-verified: `tests/library_fixtures.py:31` (`from tests.test_disc_identity import iso_fixture`), `test_library_identity.py:14`, `test_library_index.py:13/14`, `test_game_library.py:41` and `:74` (two separate in-method imports).
- **Mechanism:** `test_game_library.py:266-299` (`test_native_ps2_hash_matches_independent_boot_name_and_elf_digest`) hand-rolls a second ISO9660 builder (`record()` + manual PVD/directory assembly) while varying only boot name and ELF bytes — both parameters of the shared builder. Read in full; claim exact.
- **Execution:** Baseline: all involved tests passed/skipped on stated gates.
- **Fix:** Move fixture to `library_fixtures.py`/fixtures module, re-export, rewrite the hash test to call it — sound.

### RE-SERV-105 — VERIFIED
- **Citations:** `tests/test_library_preferences.py:17-33, 40-58, 60-68` read in full. Grep: `save_preferences`/`show_cover` occur only as AST search strings (ll.21, 46) and as calls on the exec'd copies (ll.33, 58) — never on a production object; `LibraryWindow` is never instantiated/imported.
- **Mechanism:** Stronger than claimed for the second test: `show_cover` is exec'd in a context that is literally `{}` (l.51-53), `save_preferences` in a namespace containing only a fake `config`. Any new module-global reference in either method → harness `NameError`, exactly as claimed. Third test (ll.60-68) is `assertIn` substring pins over source text.
- **Execution:** Baseline: file's 3 tests passed.
- **Fix:** Call real unbound methods with a fake `self` (pattern exists in `test_directlink.py`) — sound.

### RE-SERV-106 — VERIFIED
- **Citations:** `tests/test_netinfo_and_smb.py:20-22` asserts only `"[network] Current IP Addresses and Network Adapters:"` and `"Custom IP..."`. Both are formatter literals: header at `launcher/netinfo.py:206`, the Custom IP sentence at `launcher/netinfo.py:215` (grep-verified). Nothing about any detected address is asserted.
- **Mechanism:** Can only fail on a literal edit; host network data is silently unexamined. Duplication of intent with `test_ip_choices_contains_custom_option` (ll.15-17) confirmed.
- **Execution:** Both tests passed in my targeted re-run.
- **Fix sanity (one correction):** The proposed "patch `netinfo.all_ipv4`" is not quite the formatter's input — `detailed_ip_info()` calls `get_all_adapters_info()`, which only *falls back* to `all_ipv4()` (netinfo.py:202) when its adapter probes yield nothing. Patch `get_all_adapters_info` (or both) for a deterministic test. Finding stands; fix target needs that adjustment.

### RE-SERV-107 — VERIFIED
- **Citations:** `tests/test_http_path_aware.py:208-218` read: for `"../DVD/Game.iso"` the test asserts `assertIsNotNone(entry)` (folded by `normpath` back inside the whitelist), with the honest inline comment at ll.213-214; the other three names assert `IsNone`. The name `test_traversal_and_unknown_paths_resolve_to_nothing` contradicts the first case exactly as claimed.
- **Mechanism / Fix:** Name-only defect; split + rename, no assertion changes — sound, zero-risk.

### RE-SERV-108 — VERIFIED
- **Citations:** `tests/test_game_library.py:185-198`: `try: linked.hardlink_to(...) except OSError: return` (ll.191-194) — bare return, no skip, after the live-database assertion. Sibling form confirmed: `test_library_index.py:120-121` and `test_library_recursive_scan.py:156` use `except OSError: self.skipTest(...)` for symlinks.
- **Mechanism / Execution:** Vacuous-pass hole is portability-only; in my baseline (Linux, hardlinks work) the full test ran and passed.
- **Fix:** `skipTest` (or split the test) — sound.

### RE-SERV-109 — VERIFIED
- **Citations / census (recounted):** `test_autostart_and_firewall_options.py`: **9 × `SkipTest("no display")`, 10 × `tk.Tk()`** — script counts match the claim exactly; prologue repetitions at ll.46-64, 84, 106, 133, 205, 228, 258, 282, 306 region, with the drift claimed (two tests probe via `tk.Tk().destroy()` at ll.198/219 before `_app_with_fake_servers` at l.162, others construct directly). `test_library_panel.py`: **7 × `tk.Tk()`** with the same try/`TclError`/skip shape (ll.18, 43, 91, 135, 171, 199, 237). `test_about_page.py:106-152` carries the same shape once, plus env save/restore in its `setUp` — as cited.
- **Mechanism:** Copy-pasted display guard + full `LauncherApp` construction per test; drift already present.
- **Execution:** In my baseline all 9 autostart tests skipped `no display`, library-panel tests skipped `No graphical display` — the prologue is the gate in every case.
- **Fix:** One `_require_display()`/app factory (class-level pattern already in `test_gui_layout.py`) — sound.

### RE-SERV-110 — VERIFIED
- **Citations:** `tests/test_smb2_server.py:616-617` main block mid-file (file 944 lines); classes after it at 620/697/736/758/808/870/906/915. My AST recount: **23 tests after the block** (MalformedRequestBuffers 4, RenameSafety 3, ParentEntry 1, DomainHandling 3, SecurityBufferFraming 5, NeutrinoClientShape 3, ShareNameCollisions 1, BindHint 3), **56 total**. Parallel: `tests/test_smb2_paths.py:202-203` main block, `WindowsDeviceNames` at 206 with **5 tests**, **19 total** (file 249 lines).
- **Execution (mine, /tmp copy):** `python3 tests/test_smb2_server.py` → **Ran 33 tests, OK**; `python -m unittest tests.test_smb2_server` → **Ran 56 tests, OK**. `python3 tests/test_smb2_paths.py` → **Ran 14, OK**; module → **Ran 19, OK**. Numbers identical to the claim; both direct runs green, loss invisible, exactly as claimed. (Note: these two files *do* run directly, unlike RE-SERV-102's files — they carry their own path setup.)
- **Fix:** Move the block to EOF in both files — sound, minimal.

### RE-SERV-111 — VERIFIED
- **Citations:** `tests/test_router_status.py:177-178`: `except subprocess.TimeoutExpired: self.skipTest("go run timed out")` (timeout=180 on the `go run`). Non-zero exit path directly below `self.fail(...)`s ("the two encoders were never compared"); absence skips at ll.142/145 are toolchain/source checks, as the finding exempts.
- **Mechanism:** A hung Go encoder is reported as an environment skip in the one byte-parity test — re-derived from source.
- **Execution:** In my baseline this test skipped `no Go toolchain on PATH` (legitimate path), so the timeout branch was not exercised — mechanism is READ-verified, consistent with the finding's own confidence basis.
- **Fix:** Fail on timeout — sound.

### RE-SERV-112 — VERIFIED
- **Citations:** `tests/test_smb2_banner.py:125-131`: every assertion is inside `for ip in smb2_server._local_ipv4_addresses():`; no non-emptiness guard anywhere in the test.
- **Mechanism / Execution:** On *this* host the test is non-vacuous — I executed `_local_ipv4_addresses()` → `['198.19.0.2']`, and the test passed in isolation — which confirms the claim's conditional form: vacuity strikes exactly when the function returns `[]` (regression or restricted host), indistinguishable from success.
- **Fix:** Capture + `assertTrue(list)` first — one assertion, sound.

### RE-SERV-113 — VERIFIED
- **Citations:** `tests/test_systemd_units.py:119` (`test_template_instance_keys_are_real_servers`, loop over `re.findall(r"ps2servers@([a-z0-9]+)", readme)` — note `_read` resolves inside `packaging/systemd/`, so the README is the systemd one) and `:205` (`test_readwritepaths_tolerates_a_missing_directory`, loop over `_directives(...).get("ReadWritePaths", [])`). Neither asserts non-emptiness.
- **Mechanism / Execution:** Both loops are currently non-empty — my recount: README regex yields 8 matches / 3 unique keys (`smbv1`, `udpbd`, `udpfs`); the unit carries one real entry `ReadWritePaths=-/srv/ps2`; both tests passed in isolation. So the vacuity is structural (parse drift → zero iterations → pass), exactly the Medium-confidence claim made, no more.
- **Fix:** Non-emptiness guard (+ pin the instance set) — sound, adds assertions only.

### RE-SERV-114 — VERIFIED
- **Citations:** `tests/test_smbv1_share_and_credentials.py:182-187`: constructs `SmbServer({"roms": Share("roms", d)}, …)`, asserts `"roms" in server.shares`. Production `smbv1_server/smbserver_opl.py:1518-1519`: `__init__` is literally `self.shares = shares` — the test reads back the constructor argument verbatim.
- **Mechanism:** No TREE_CONNECT is driven; the real name resolution (`shares.get(share_name) or .get(share_name.lower())`, smbserver_opl.py:783) is unobserved. A key-normalising regression passes this test.
- **Execution:** Test passed in my targeted re-run.
- **Fix:** Drive a real TREE_CONNECT (helpers exist in the same file) or delete — sound.

### RE-SERV-115 — VERIFIED
- **Citations:** `tests/test_setup_guide.py:36-54`: `test_gui_button_connected_once` counts `source.count('text="PS2 setup guide…"') == 1` and pins fragments; `test_first_run_invitation_and_persistent_status` pins literal lines incl. `self.root.after(1200, self._offer_ps2_setup_guide)`. `:90-92`: the close-callback test ends in three `assertIn` source pins (`self.close(completed=True)`, `command=self.close`, `WM_DELETE_WINDOW` protocol line) after an executed portion.
- **Mechanism:** Spelling pins: fail on behaviour-preserving refactors, pass on wiring breaks that keep the strings — re-derived from the test bodies.
- **Execution:** Baseline: file passed.
- **Fix:** Keep ≤1 smoke source check, move semantics to the guide state machine (other tests in the file already exercise it) — sound.

### RE-SERV-116 — VERIFIED
- **Citations:** `tests/test_status_client.py:206-272`, class `StopAllStaysUnconditional`: `ast.parse` of `launcher/gui.py`, `_method`/`_calls` walk `ast.Call` nodes collecting attribute/name strings, asserting `confirm_stop_while_busy`/`askyesno` absent from `stop_all`. Docstring discloses the headless rationale, as the finding credits.
- **Mechanism:** Syntactic only — a prompt via an unwatched helper name or `getattr` indirection passes; a rename of a watched helper fails it. The counter-example cited also checks out in substance: `test_verbose_default_and_log_stamps.py`'s `TerminalStamp` (l.58) does import `launcher.gui` and skip only on failure (ll.63-67), so "cannot be instantiated" is stronger than suite practice.
- **Execution:** Baseline: class passed.
- **Fix:** Relabel as source lint + add one behavioural test with prompt functions stubbed to raise, under the tkinter guard — sound; the addition is justified as the only behavioural observation.

### RE-SERV-117 — VERIFIED
- **Citations:** `tests/test_release_downloads.py:71-82`: body is `text = SCRIPT.read_text(...)` (`SCRIPT` = `.github/scripts/release-downloads.sh`, l.9) then `for label in (…16 labels…): self.assertIn(label, text)` — nothing else. (Finding calls the variable `script_text`; actual name is `text` — immaterial.)
- **Mechanism:** A no-op target whose label string remains in the script passes; the name `test_every_edge_target_has_a_purpose` overstates the guarantee, as claimed.
- **Fix:** Assert per-target artefact/block, or rename to what is checked — sound.

### RE-SERV-118 — VERIFIED
- **Citations:** `tests/test_ra_credentials.py:76-78`: `if os.name == "nt": return  # the platform roundtrip above exercises real DPAPI instead` — bare return at the head of `test_posix_insecure_permissions_are_rejected`, exactly as claimed, comment included.
- **Mechanism:** On Windows this reports as *passed* having run nothing; the stated mitigation (DPAPI roundtrip above it) is present in the file.
- **Execution:** On this Linux host the POSIX branch ran and passed in baseline.
- **Fix:** `skipTest(...)` — sound, one line.

### RE-SERV-119 — VERIFIED
- **Citations / census (mine):** `stalled` (`test_ra_account_worker.py:31`) vs `stuck` (`test_ra_resolver_process.py:15`): function **bodies AST-identical** (`while True: time.sleep(1)`; resolver copy adds a comment). `_request` (`test_smbv1_compressed.py:44` vs `test_smbv1_read_after_write.py:22`): **full AST dumps identical** (same md5), same `SimpleNamespace(tid=1, params, data, msg)` factory.
- **Mechanism:** The finding's negative census also reproduces: my AST hash over all `test_*.py` found **zero duplicated test-method bodies** — duplication is helper-layer only, as claimed.
- **Fix:** Hoist each pair to shared test support — sound.

### RE-SERV-120 — VERIFIED
- **Citations:** `tests/test_transfer_limits.py:109` `read_payload` and `:118` `write_req_payload`: my AST comparison — **bodies identical**, both `return struct.pack("<BBBBiI", 0, 0, 0, 0, handle, size)`. The neighbouring `bread_payload` (l.113) is genuinely different, so the pair is not a pattern artefact.
- **Fix:** Delete one name, call the other — sound, pure deletion.

### RE-SERV-121 — VERIFIED
- **Citations:** `tests/test_udpfs_config.py:360-382`, `LauncherModeLaunchTests.test_every_mode_builds_argv_from_defaults` (def at l.367): sole assertion `assertIsInstance(server.build_argv(values), list)` at l.382 inside `subTest(mode=key)` over the whole `servers.REGISTRY`; class docstring claims "must build an argv from its own field defaults".
- **Mechanism:** `[]`/nonsense lists pass; only exceptions and non-list returns fail. The NameError-crash case the docstring motivates *is* covered — the finding concedes this and scopes the gap correctly.
- **Execution:** Passed in my targeted re-run.
- **Fix:** Assert non-empty + supplied root/target present in argv — sound, assertions only.

### RE-SERV-122 — VERIFIED
- **Citations:** `tests/test_udpfs_config.py:272-279` `test_widen_on_a_real_socket`: only assertion `assertGreater(s.getsockopt(SO_RCVBUF), 0)` at l.276. The `_FakeSock` docstring at ll.232-234 states verbatim "a real socket always reports a positive buffer, which would let a no-op implementation pass" — quoted correctly.
- **Execution (demonstration):** In /tmp I created a real UDP socket and read `SO_RCVBUF` **before any widen call: 212992 > 0** — a no-op `_widen_recv_buffer` passes this test by construction. The surrounding fake-socket tests (ll.259-270) do pin widen/no-shrink/best-effort properly, as claimed.
- **Fix:** Assert post-call ≥ requested (or vs. pre-call baseline), or delete the test — sound; the baseline-comparison variant is the safer of the two offered.

### RE-SERV-123 — VERIFIED
- **Citations:** `tests/test_smb2_take_445.py:73` `FakeServices.run` (class at l.35): regexes `_GET`/`_STOP`/`_START` at ll.25-27 match production's command shapes (`smb2_server/smb2_server.py:1511-1599` issues exactly `(Get-Service %s …).Status`, `Start-Service %s …`, `Stop-Service -Name LanmanServer …`). Fall-through `return subprocess.CompletedProcess(args, 0, "", "")` is at **line 117** (finding says 118 — one-line drift, immaterial).
- **Mechanism:** Any unrecognised/respelled command silently succeeds with exit 0 and empty output; production command drift is absorbed by the double. Re-derived from the full `run` body (ll.73-117).
- **Execution:** Baseline: file passed (all commands matched, so the fall-through was not hit — consistent with a latent, not active, defect).
- **Fix:** Raise / non-zero with the unmatched command named — sound.

### RE-SERV-124 — VERIFIED
- **Citations (all grep-verified):** manual `time.monotonic = lambda: fake_now` / restore-by-hand in `test_udpfs_live_discovery_handoff.py` — first site ll.239-242, and *passim* is accurate (10 assignment/restore pairs: ll.239, 285, 324, 362, 387, 418, 437, 474, 513, 587); `patch.object(CORE.threading, "Thread")` + `patch.object(CORE.time, "sleep")` at `test_udpfs_fallback_generation.py:47,51`; `patch.object(UDPFS.os, "name", …)` / `patch.object(UDPFS.threading, "Thread", …)` at `test_udpfs_stall_report.py:59,117,189,203`; `patch.object(srv.os, "lstat", …)` at `test_udpfs_symlink_path_ops.py:374`.
- **Mechanism:** `CORE.threading`, `UDPFS.os`, `srv.os` are the process-wide stdlib module objects (the production modules `import threading/os/time` by reference), so patching their attributes patches them for every module in the single discover process. The finding correctly self-scopes this as fragility, not an observed leak: the manual sites restore in `finally` (verified ll.236-242) and the `patch.object` uses are context managers.
- **Execution:** Baseline completed with no cross-file contamination symptom — consistent with "fragility, not observed leak".
- **Fix sanity (one correction):** The minimum fix (convert manual `time.monotonic` assignments to `mock.patch.object` contexts) is sound. But the fix text's parenthetical — "`patch.object(CORE, "time", fake)` is not possible for module attributes" — is **wrong**: rebinding `CORE.time` replaces the entry in CORE's own module globals and affects exactly the lookups made through CORE, which is precisely the contained patch the finding wants; it is the standard technique and should be recommended, not ruled out.

### RE-SERV-125 — VERIFIED
- **Citations (all grep-verified):** five `importlib.util.spec_from_file_location` loads of `udpfs_server/ps2servers_core.py`, none registering in `sys.modules` (no `sys.modules` assignment in any of the five; each does `module_from_spec` + `exec_module`):
  - `test_udpfs_fallback_generation.py:18-19` → `ps2servers_core_fallback`
  - `test_udpfs_inform_telemetry.py:13-14` → `ps2servers_core_inform_telemetry`
  - `test_udpfs_startup_diagnostics.py:16-17` → `core_startup_diagnostics`
  - `test_udpfs_live_discovery_handoff.py:23-24` → `ps2servers_core_handoff`
  - `test_udpfs_protocol_negotiation.py:14-15` → `ps2servers_core` (same *name*, still a distinct module object — not the imported one)
- **Mechanism:** Five distinct module objects → distinct `AutoUdpfsServer`/`Session` classes and module state in one discover process, while other files import the module normally (`test_server_override_contract.py:34`, `test_udpfs_ack_progress.py:15`, `test_udpfs_config.py:26`, `test_router_status.py:217`). Class-identity/`isinstance` divergence follows as claimed (INFERRED portion correctly labelled).
- **Fix:** Import normally; reserve spec-loading for a genuinely-isolated case with a comment — sound. (Caution for whoever applies it: if any of the five relies on fresh module-level state per file, that reliance should be named before converting — the finding's Medium risk already covers this.)

### RE-SERV-126 — VERIFIED-DRIFT
- **Citations:** `smb2_server/smb2_server.py:76-128` is exactly 53 lines (my count); consumer `_open_share_warning_lines` at ll.131-147 (called at l.141) appends `"  Reachable on: " + ", ".join(ips)` then the `--bind` advice line, and its docstring concedes "an empty address list is fine, the --bind advice is the load-bearing half" — quoted fairly. The `fcntl` import/ioctl at ll.96-101 is the only `fcntl` use **in that file** (other repo files use it for unrelated purposes; the finding's "in the server" is accurate read as the SMB2 server file).
- **Correction to the title/mechanism:** the function does not "run three enumeration mechanisms" per call. They are **sequential conditional fallbacks**: the ioctl pass runs only `if not ips:` (l.94) and the TEST-NET UDP-connect probe only `if not ips:` again (l.110). On a host where `getaddrinfo(gethostname())` yields a non-loopback address — including this sandbox, where the function returns `['198.19.0.2']` — only the first pass executes. The cost claim should read "three mechanisms *maintained*, up to three run, and then only on hosts the earlier passes fail".
- **Mechanism (as corrected):** ~53 lines, a platform-guarded syscall path and a network-stack probe, maintained solely for a cosmetic banner line whose actionable half needs no enumeration — verified.
- **Fix sanity:** Keeping getaddrinfo + the `--bind` line and deleting the other two passes is LESS-NOT-MORE compliant, with one trade-off the finding underplays: the ioctl pass exists (per the function's own docstring) for POSIX hosts whose hostname resolves only to loopback — on such hosts the banner would lose its address list entirely. Since the list is explicitly best-effort/cosmetic, the trade is defensible, but it should be stated as a knowing trade, not "loses nothing".

---

## Tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 24 | 101, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125 |
| VERIFIED-DRIFT | 1 (+ baseline) | 126; BASELINE-PY assessed separately above |
| WEAKENED | 1 | 102 |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — (UDP block affected only baseline classification, which was reproduced and classified, not blocked) |

Total: 24 VERIFIED + 1 WEAKENED (102) + 1 VERIFIED-DRIFT (126) = 26 findings, plus BASELINE-PY VERIFIED-DRIFT. No finding was REFUTED outright; the only defeating evidence found was against 102's stated failure mode and the baseline's "genuine" NFS4 classification.

## CANDIDATES (new defects, with evidence — not in the redo report)

- **F-1 — Direct script execution is broken suite-wide by missing `sys.path` prologues, including in files that *do* have `unittest.main()`.** Evidence (executed in /tmp/ps2sF): `python3 tests/test_art_fetch.py` (has the `__main__` guard, no path prologue) → `ModuleNotFoundError: No module named 'launcher'`, same as all 8 RE-SERV-102 files. Only files that insert the root themselves (e.g. `test_smb2_server.py`, `test_netinfo_and_smb.py`) or import no first-party package (e.g. `test_attribution_policy.py`) actually run directly. So "add the main guard" cannot deliver the direct-execution convention RE-SERV-102 wants; the suite's real convention is `python -m unittest` from the root, and any direct-run fix must add the path prologue too.
- **F-2 — `test_nfs4_server…test_endless_empty_fragments_close_the_connection` is timing-fragile by construction.** Evidence: client socket timeout is 5 s (`tests/test_nfs4_server.py:890`, `create_connection(..., timeout=5)`); the test sends `p32(0) * (MAX_RECORD//4 + 1)` = 264,193 empty fragments (`MAX_RECORD = 1024*1024 + 8192`, `nfs4_server/nfs4_server.py:49-50`); the server consumes them one `_recv` per fragment and only closes after `total > MAX_RECORD` (`nfs4_server.py:505-517`). Observed: original baseline run → `TimeoutError` on `recv`; my full run → pass; 5/5 isolated runs → pass at 2.5–5.1 s each, i.e. operating near the timeout budget. A smaller fragment count over the cap, or a longer/assert-tolerant timeout, would make the close-condition test deterministic.
