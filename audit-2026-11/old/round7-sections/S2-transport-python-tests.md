# S2 — Round 7: UDPFS/UDPBD/NFS/HTTP/storage Python tests + CI-gating selftests

- **Repo / pin:** NathanNeurotic/PS2-Servers @ `c5f021c4d38698860f56b03498adc261dbb8d8dd` (verified held; `git status` clean at start and finish — read-only throughout).
- **Scope:** every line of the 27 files listed for this section. **8,142 lines read** (`wc -l` total, cross-checked per file below).
- **Method:** full line-by-line read of all 27 files; AST scan for tests with no assertion call, `except: pass`, skips, and duplicated test bodies; grep verification against shipped code for any suspected test of deleted/renamed code; CI wiring read in `.github/workflows/ci.yml` and `.github/workflows/edge.yml`.
- **Headline judgement:** this is a strong suite. Most tests drive real handlers / real loopback servers and assert on bytes, reply codes, and on-disk aftermath. The defects found are concentrated in *gating visibility* (two suites/sections that report pass without running in CI), one unfailable assertion, one cross-file duplication, and two latent blind spots. **No test in this section was found asserting the PS2SERVERS-056/-057/-058, -063/-064/-065, or -066 buggy behaviours as correct** (detail in §4).

---

## 1. Per-file ledger

Line counts are the file's actual `wc -l` at the pin. "Tests" = `test_*` functions found by AST (selftests use module-level `test_*` functions, not unittest classes).

| File | Lines | Tests | Verdict |
|---|---|---|---|
| tests/test_nfs4_server.py | 1057 | 66 | Sound. Independent XDR builders (header, :11-12), layout pinned at unfs4's fixed offsets, real socket tests. See checked-and-sound. |
| tests/test_udpfs_live_discovery_handoff.py | 596 | 12 | Sound. Real `_handle_discovery`/`_handle_data`; transport stubbed and disclosed (:6-7). `_handle_open` replaced by a recorder — dispatch is the subject, OPEN itself is covered over loopback in test_udpfs_write_needs_writable_handle.py. |
| tests/test_udpfs_write_needs_writable_handle.py | 477 | 19 | Sound. Real AutoUdpfsServer receive loop over loopback. Seven tests delegate assertions to `_assert_only_the_refusal` (:269-286) — not no-assert tests. |
| tests/test_udpfs_symlink_path_ops.py | 443 | 27 (mixin ×2 server classes) | Sound. Real handlers of both server classes, assertions on what is left on disk. |
| tests/test_udpfs_config.py | 386 | 43 | Mostly sound; **S2-03** (one unfailable test) and **S2-04** (duplicated alias tests) live here. Two no-assert tests are legitimate must-not-raise smokes (:280-283 closed socket; :305-315 uses `self.fail` inside the loop). |
| tests/test_udpfs_stall_report.py | 230 | 11 | Sound. ARP neighbour-table parsing is real; only the ping nudge socket and `subprocess.run` are faked. `_ImmediateThread` runs the probe inline, deterministically. |
| tests/test_udpfs_ack_progress.py | 138 | 7 | Sound. Real `_handle_data`/`_wait_for_ack`/`_handle_bread` against a synthetic session; rewind/prune asserted on session state. |
| tests/test_udpfs_bind_control.py | 63 | 2 | **S2-02** — both tests skip in every CI run (headless setUp). Sound when run on a display machine. |
| tests/test_udpfs_dread_skip_entry.py | 84 | 3 | Sound. Real `_handle_dread`; fake `_Entry.stat()` is the fault being injected, not the subject. `_list` loop is bounded (10 iterations, :61). |
| tests/test_udpfs_fallback_generation.py | 78 | 4 | Sound. Real `_schedule_fallback` closure captured via a `Thread` patch; thread never started, callback invoked directly — disclosed in the docstring (:3-4). |
| tests/test_udpfs_handoff_retried_write.py | 193 | 3 | Sound. Three tests delegate to `_retry_save_after` (:147-177), which asserts handle inequality, file contents, and the handoff event marker — not no-assert tests. Real loopback server + real multiclient client. |
| tests/test_udpfs_inform_telemetry.py | 88 | 4 | Sound. Fake `_Socket` records `sendto`; the packet bytes and log lines are asserted exactly (:51). |
| tests/test_udpfs_protocol_negotiation.py | 137 | 9 | Sound. Real `classify_profile` incl. shared conformance fixtures; discovery-lifecycle test asserts ten preserved session fields. Note: conditional asserts at :131-134 are inside `if sequence == 0 / else` over a fixed (0, 7, 4095) tuple — both branches execute. |
| tests/test_udpfs_resent_request.py | 180 | 6 | Sound. Real send/wait paths; a counting `_queue_get` wrapper turns an infinite re-read into an assertion failure (:71-75) instead of a hang. |
| tests/test_udpfs_startup_diagnostics.py | 74 | 4 | Sound. Real server construction and `run()` banner; only `_startup_version` is mocked. |
| tests/test_udpbd_storage_modes.py | 300 | 16 | Sound. Real RawDevice/VirtualExfat; Windows-only and fsck.exfat tests are skip-gated with reasons and both have a CI home (windows-storage job; exfatprogs installed in python-checks). Asserts inside the directory-checksum `while` loop (:225-230) are guarded by the entries actually present in the fixture tree. |
| tests/test_udpbd_access.py | 52 | 3 | Sound. `builtins.open` patch is the fault injection (permission denied); read-back, sector count, stderr text, and CLI exit code all asserted. |
| tests/test_transfer_limits.py | 411 | 18 | Sound. `_Recorder` removes sockets but keeps the real handlers (disclosed, :25-33); `_Blob`/`_WritableBlob` are the file objects the handlers act on. Includes the SMBv1 share-boundary class. See §4 for the BWRITE/device-size gap — absence, not encoding. |
| tests/test_raw_storage.py | 327 | 23 | Sound. Mock backends are the native-device seam; alignment, capacity, cache invalidation, and request-boundary behaviour asserted on recorded backend calls. Windows PowerShell tests skip on Linux but run in the windows-storage CI job. |
| tests/test_path_access.py | 91 | 8 | Sound. Real `check_path` on real temp files; patches used only to inject stat/open failures. `opener.assert_not_called()` pins the raw-device no-open rule (:84). |
| tests/test_http_server.py | 589 | 41 | Mostly sound; **S2-05** (hot-path guard's blind spot) lives here. Real socket, exact driver bytes, framing asserted on the second read. |
| tests/test_http_path_aware.py | 302 | 25 | Sound. `_parse_row` re-implements RiptOPL's C field splitter independently. See checked-and-sound for the traversal test whose name overstates its body. |
| tests/test_http_direct_link.py | 238 | 7 | Sound. Real DhcpResponder exchange; leased/announced addresses are read out of the ACK packet (:84-89), not assumed. Non-loopback test skips only when the host has no such address (:229). |
| udpbd_server/selftest.py | 179 | script | Sound — can fail. Every check is a bare `assert` on wire replies or on the image file's bytes; an assertion failure propagates out of `main()` and the process exits non-zero. See checked-and-sound for `_write`. |
| udpfs_server/compression_selftest.py | 545 | 12 | Can fail: `check()` (:172-177) raises `AssertionError`, which propagates out of `main()` → non-zero exit. **S2-04** duplication lives here. Header-only CHD/ZSO fixtures are disclosed (:21-23); CSO data round-trip is real. |
| udpfs_server/multiclient_selftest.py | 643 | 8 | Can fail: each test returns a bool, `main()` aggregates with `ok = test(...) and ok` (:621-636, test evaluated first so all run) and `sys.exit(main())` returns 1 on any failure. **S2-06** latent skip-pass branch. Exceptions in `test_baseline` propagate and fail the run rather than being swallowed. |
| udpfs_server/pathguard_selftest.py | 241 | 4 | Can fail on POSIX sections (`check()` raises, :46-51), but **S2-01**: the UNC section never executes on the CI platform and the suite still prints a full-pass banner. |

---

## 2. Candidate findings

### S2-01 / Path-guard selftest reports "ALL PASSED" in CI while its UNC section — one of its three pinned properties — never runs there

- **Category:** Vacuous-in-CI / permanent skip with a full-pass banner (selftest)
- **Locations:**
  - `udpfs_server/pathguard_selftest.py:189-192` — `test_unc_root()` returns after printing `[unc] skipped (Windows ntpath semantics only)` on any non-Windows host.
  - `udpfs_server/pathguard_selftest.py:231-237` — `main()` calls the four sections unconditionally in sequence and then prints `ALL UDPFS PATH-GUARD TESTS PASSED`, with no skipped/partial state.
  - `udpfs_server/pathguard_selftest.py:16-20` — the docstring pins UNC roots as a headline property: the guard once broke every request from a NAS/UNC root with EACCES.
  - `.github/workflows/ci.yml:130-141` (`python-checks`, `runs-on: ubuntu-latest` at :56) and `.github/workflows/edge.yml:71-75` (`runs-on: ubuntu-latest`) — the only CI executions of this selftest are on Linux.
- **Problem:** READ: in the gating environment the UNC regression class has zero execution, and the output is indistinguishable from a full pass — the banner says ALL, the exit code is 0. A regression that again eats the leading `\\` of a UNC root would ship green. This is exactly the failure the file's own docstring says the section exists to prevent.
- **Fix:** LESS NOT MORE, in order of preference: (1) add this one selftest to the existing `windows-storage` job in ci.yml (one `run:` line — the job already exists for platform-gated storage tests); and (2) have `test_unc_root()` return a skipped flag and `main()` print `PASSED (UNC section skipped on this platform)` instead of the unqualified banner, so a local POSIX run is also honest.
- **Benefit:** The NAS-root containment property actually gates; the pass banner means what it says on every platform.
- **Effort:** S
- **Risk:** Low — one CI step added to an existing Windows job; banner text change only.
- **Confidence:** High (READ — skip branch, banner, and both workflows' runner OS are all in the tree).

### S2-02 / tests/test_udpfs_bind_control.py — both tests skip in every CI run; the module gates nothing

- **Category:** Permanent skip in the gating environment
- **Locations:**
  - `tests/test_udpfs_bind_control.py:11-20` — `setUp()` calls `self.skipTest("no tkinter")` on ImportError and `self.skipTest("no display")` when `tk.Tk()` raises `TclError`, before either test body runs.
  - `.github/workflows/ci.yml:97` — the suite runs as `python -m unittest discover -s tests -t . -v` in the `python-checks` job on `ubuntu-latest` (:56); neither ci.yml nor edge.yml contains any `xvfb`, `DISPLAY`, or `python3-tk` step (grep-verified).
- **Problem:** READ (skip mechanism, workflow contents) + INFERRED (a headless Ubuntu runner has no display, so `tk.Tk()` raises and both tests skip on every CI run; unittest reports them as skipped and the job stays green). The property pinned — the visible "Use LAN IP" control reaching the `--bind` launch argv (:38-52) — therefore has no gating coverage at all; it only ever runs on a developer's display machine. The ci.yml comment near the discover step acknowledges GUI tests self-skip headless, which makes this invisible rather than decided.
- **Fix:** Add one CI step running just this module under a virtual display (`xvfb-run -a python -m unittest tests.test_udpfs_bind_control -v`) in the python-checks job. Do not move the assertions into the widget-free argv tests — the widget wiring is the subject.
- **Benefit:** A real launch-path regression (bind control silently not reaching argv) would fail CI instead of passing as two skips.
- **Effort:** S
- **Risk:** Low — additive step, scoped to one module.
- **Confidence:** High on the skip mechanism and on the absence of any virtual-display setup in the workflows (READ); Medium-High on "never runs in CI" (INFERRED from the headless runner).

### S2-03 / test_widen_on_a_real_socket cannot fail if widening is a no-op

- **Category:** Unfailable assertion
- **Locations:**
  - `tests/test_udpfs_config.py:276-282` — creates a fresh UDP socket, calls `udpfs._widen_recv_buffer(s, udpfs.DATA_RECV_BUFFER_BYTES)`, asserts `getsockopt(SO_RCVBUF) > 0`.
  - `tests/test_udpfs_config.py:232-234` — the file's own `_FakeSock` docstring states the defect: *"a real socket always reports a positive buffer, which would let a no-op implementation pass."*
- **Problem:** READ: a fresh UDP socket's `SO_RCVBUF` is a positive kernel default before `_widen_recv_buffer` does anything, so the assertion passes with widening deleted, widening to a wrong value, or widening silently failing. The test can only fail if the call raises. The neighbouring fake-socket tests (:254-274) already pin the real behaviour exactly via recorded `set_calls`, including the refused-option case.
- **Fix:** Delete `test_widen_on_a_real_socket` (the fake-socket cases are strictly stronger). If a real-socket smoke is wanted, keep only the must-not-raise form already present in `test_widen_tolerates_a_closed_socket` (:284-287) and name it as a smoke, with no value assertion.
- **Benefit:** One fewer test that certifies a property it cannot observe; the suite's green means the widen call was actually issued.
- **Effort:** S (deletion)
- **Risk:** Low — the deleted assertion is subsumed by :254-274.
- **Confidence:** High (READ, including the file's own statement of the flaw).

### S2-04 / Extension→codec mapping asserted verbatim in two CI-gated suites

- **Category:** Duplicated test bodies across files
- **Locations:**
  - `udpfs_server/compression_selftest.py:478-497` — `test_extension_alias_mapping()`: `.cso→cso`, `.ciso→cso`, `.zso→zso`, `.ziso→zso`, `.chd→chd`, `A.CISO→cso` (case-folded), `.iso→None`, each via `check(srv._format_for_extension(...))`.
  - `tests/test_udpfs_config.py:209-223` — `ExtensionAliasTests.test_aliases_map_to_the_same_codec`, `test_extension_match_is_case_insensitive`, and `test_plain_iso_is_not_compressed`: the same production function (`udpfs._format_for_extension`, same module object) with the same mappings, the same case-fold case, and the same `.iso→None` case (plus a bare `game→None`).
- **Problem:** READ: one production table is pinned twice, in two suites that both gate CI (unittest discover, and the compression selftest step in ci.yml:137-138). Any legitimate change to the mapping must be edited in both places, and if only one is edited the other fails for a non-regression reason — or, worse, a future editor "fixes" the stale copy instead of the code. The selftest's *other* builder test (`test_extension_gating_builder`, :450-475, library-availability gating of `_supported_compressed_extensions()`) is **not** duplicated and should stay.
- **Fix:** Delete `test_extension_alias_mapping()` from compression_selftest.py (and its call at :536); the unittest copy in test_udpfs_config.py has the finer-grained cases. Keep the selftest's gating-builder test.
- **Benefit:** One authoritative pin for the extension table; one less place for the two suites to drift apart.
- **Effort:** S (deletion)
- **Risk:** Low — coverage is fully preserved by the surviving copy.
- **Confidence:** High (READ — both bodies read line-by-line; same function, same expected values).

### S2-05 / HTTP hot-path cost guard does not watch os.scandir, which the same module's scan paths use

- **Category:** Guard blind spot (weak-but-claimed-strong test)
- **Locations:**
  - `tests/test_http_server.py:367-386` — `HotPathCostTests.test_lookup_touches_the_filesystem_not_at_all` replaces only `os.listdir` and `os.stat` with recording wrappers, calls `index.lookup(...)` 50 times, and asserts the recorder is empty, under a class docstring claiming the structural guarantee "Streaming must not pay for a directory walk per read" (:357-365).
  - `http_server/http_server.py:360` and `:415` — the module's own scan code walks directories with `os.scandir` (a third entry point the recorder never sees); `:328` uses `os.listdir`.
- **Problem:** READ (recorder's coverage; scandir use in the module) + INFERRED (no current violation — `GameIndex.lookup` at http_server.py:763 ff. is a pure dict lookup today): a rescan reintroduced into `lookup()` through the module's existing scandir-based scan helpers would touch the filesystem on every read while this test stays green, i.e. the guard does not cover the regression shape its own module would most naturally produce. It does cover the historical listdir/stat shape.
- **Fix:** Wrap `os.scandir` with the same recorder alongside listdir/stat in the one test (three lines, same try/finally restore).
- **Benefit:** The "not at all" in the test name becomes true for every directory-walk entry point the module uses.
- **Effort:** S
- **Risk:** Low — test-only widening of an existing recorder.
- **Confidence:** Medium (mechanism READ; that a future regression would take the scandir path is INFERRED).

### S2-06 / multiclient_selftest test_concurrency contains a return-True "SKIP" path that would be aggregated into "ALL PASSED"

- **Category:** Latent vacuous pass (currently unreachable from `main()`)
- **Locations:**
  - `udpfs_server/multiclient_selftest.py:509-512` — `names = list(files.keys())[:2]; if len(names) < 2: print("  SKIP: need >=2 files"); return True`.
  - `udpfs_server/multiclient_selftest.py:621-638` — `main()` folds each test's return into `ok` and prints `ALL UDPFS TESTS PASSED` / exits 0 when `ok` holds; its own call passes exactly two files (:622-624), so the branch is dead today.
- **Problem:** READ: the branch is a silent-pass trap for the next caller — anyone reusing `test_concurrency` with a one-file dict (or trimming main's fixture dict) gets a green "CONCURRENCY" section that tested no concurrency at all, in a CI-gating selftest. It is the only place in the four selftests where a non-run converts to a pass value instead of an exception/skip report.
- **Fix:** Delete the branch (main guarantees two files), or make it `return False`. Deletion is the LESS fix: the guard protects a call shape that does not exist.
- **Benefit:** Removes the one path by which this selftest can claim a pass for work it did not do.
- **Effort:** S (deletion)
- **Risk:** Low — branch is unreachable from the only in-tree caller.
- **Confidence:** High (READ).

---

## 3. Checked-and-sound list

Weak-looking but real tests, verified and **not** filed:

- **Selftests can fail (the headline check).** udpbd_server/selftest.py: bare `assert`s on wire replies and file bytes throughout (e.g. :40, :54, :73, :133); a failure raises out of `main()` → non-zero exit under both ci.yml:131-132 and direct runs. compression_selftest.py: `check()` raises `AssertionError` (:172-177) and `main()` does not catch it. pathguard_selftest.py: same `check()` pattern (:46-51) for its POSIX sections. multiclient_selftest.py: bool-returning tests, aggregated in `main()` (:621-638) with `sys.exit(main())`. None of the four is print-and-exit-0.
- **udpbd selftest `_write` (selftest.py:58-74)** asserts only the `CMD_WRITE_DONE` command byte, not its result field — but then reads the image file back and asserts byte equality with the written payload (:71-73), and `_write_error` (:117-137) does assert `result == -1` for the failure path. The success path is covered by the stronger check.
- **test_udpfs_write_needs_writable_handle.py** — the seven AST-flagged "no-assert" tests (:307-375) all delegate to `_assert_only_the_refusal` (:269-286), which asserts the exact reply list, file contents, position, and that the next write lands. Likewise test_udpfs_handoff_retried_write.py's three tests delegate to the asserting `_retry_save_after` (:147-177), and test_udpfs_config.py's `test_only_long_flags_are_emitted` (:305-315) fails via `self.fail` inside its loop over a non-empty argv.
- **Must-not-raise smokes with no assertion** — test_udpfs_config.py:280-283 (closed socket) and the `_NullSocket` helpers in test_udpfs_stall_report.py:30-41: in unittest, an unexpected exception *is* the failure, and each is paired with asserting neighbours covering the value behaviour. Legitimate.
- **Fake transports that do not replace the subject.** test_udpfs_live_discovery_handoff.py (docstring :6-7 says so): `_send_specific` is a recorder, `_handle_open` is a recorder, but `_handle_discovery`/`_handle_data`/`_handle_bread` under test are the real inherited handlers and the assertions are on real session-state transitions. test_transfer_limits.py `_Recorder` (:25-105): sockets removed, handlers real, replies recorded — disclosed in its docstring. test_udpfs_dread_skip_entry.py `_Entry`: the fake *is* the injected fault (a stat that raises), the DREAD handler is real. test_udpfs_stall_report.py: the subprocess neighbour-table output is mocked, the parsing and verdict logic are real; the socket fake replaces only the ARP-eliciting nudge.
- **Platform skips with reasons that do have a CI home.** test_raw_storage.py:264-276 and test_udpbd_storage_modes.py:120-130 (Windows-only) run in ci.yml's `windows-storage` job (:43-52). test_udpbd_storage_modes.py:276 (fsck.exfat) runs because python-checks installs exfatprogs. NFS/HTTP symlink and sparse-file skips (test_nfs4_server.py:465, :508-518, :832-857) are capability probes with reasons, on the gating Linux platform they execute.
- **Conditional-looking assertions that deterministically execute.** test_udpfs_protocol_negotiation.py:131-134 (branch per fixed sequence tuple); test_udpfs_symlink_path_ops.py mode test (:347-355, fixed two-case loop); test_nfs4_server.py ReaddirTests.walk asserts (:540-557, loop bounded by the server's own eof flag, with a paging test proving eof arrives); test_http_path_aware.py `test_names_that_cannot_be_opened_are_not_listed` analogue in test_nfs4_server.py:578-586 — fixture creation is try/except-guarded, but on the gating Linux platform the files are created and must be excluded, so the final `walk == names` assertion is load-bearing there.
- **test_http_path_aware.py:211-218** (`test_traversal_and_unknown_paths_resolve_to_nothing`): the first tuple entry, `"../DVD/Game.iso"`, is asserted `IsNotNone` — the opposite of the test's name — but the inline comment (:215-216) documents why: normpath folds the `..` and the remainder is still whitelist-checked, so the served entry never leaves the catalogue. Deliberate, explained, and the other three entries assert `IsNone`. Name overstates the body; behaviour pinned is sound. Not filed.
- **test_http_server.py HotPathCostTests historical shape:** the listdir/stat recorder does catch the exact regression the class docstring describes (a rescan inside `lookup()`); S2-05 is only about the scandir-shaped variant.
- **compression_selftest.py:340-364** monkeypatches `srv.os.path.exists` (the shared stdlib `os`) and the instance's `_resolve_path` to simulate a case-missing filesystem: intrusive, but restored in `finally` (:359-362), single-threaded, and the assertion afterwards is on the real `_resolve_compressed_sibling` result. Sound.
- **No dead helpers/fixtures found.** An AST sweep for defined-but-unreferenced functions across all 27 files returned only framework callbacks (setUp/tearDown, dunders, socket/file-object overrides such as `_Recorder._send_*`, `_Blob.writable/flush`) — every named helper is called. No test references a deleted or renamed production symbol: all handler/function names used (`_handle_bwrite_req`, `_resolve_entry`, `_format_for_extension`, `_clamp_peer_timeout`, `console_answers_arp`, etc.) were grep-verified present in the clone at the pin.
- **No exact-duplicate test bodies** were found by normalized-AST hashing across the 27 files; S2-04 is a semantic (same-function, same-values) duplication, not a byte-identical copy.

## 4. Known-bug encoding check (PS2SERVERS-056…-066) — negative result

Each cited shipped-code finding was checked against every test in this section that touches the same operation:

- **-056 (UDPFS BWRITE never checked against block-device size):** no test writes a BWRITE at/past a block device's end and expects success. The BWRITEs in test_udpfs_write_needs_writable_handle.py are to regular files or in-range image sectors; the past-the-end case it does pin (:335-353) is the 2⁶³ file-offset EINVAL, a different check. test_transfer_limits.py:257 refuses an oversized BWRITE on transfer-cap grounds only. *Coverage absence, not encoding — not filed, per this section's rules.*
- **-057 (BWRITE completion never compares delivered bytes to declared count):** no test delivers a short BWRITE and asserts WRITE_DONE 0. The chunk-accounting tests (test_transfer_limits.py:262-286; write file :376-414) assert the opposite shape — refusals and exact landings.
- **-058 (UDPBD image WRITE extends the file / READ pads past end):** udpbd_server/selftest.py writes and reads are all inside its 8192-sector image (:157-168); test_udpbd_access.py and test_raw_storage.py:69-76 assert out-of-bounds wire reads are refused without touching the device. No test asserts image growth or zero-padding as correct. (VirtualExfat's asserted zero padding, test_udpbd_storage_modes.py:232-246, is that device's defined layout, not UDPBD image mode.)
- **-063/-064/-065 (CSO/ZSO serving-path defects):** every CSO built in this section uses `block_size=2048` with a consistent index (compression_selftest.py:49-67 and all its callers; test_http_server.py:496, :537; test_http_path_aware.py:234), and ZSO appears only as a header fixture for listing/stat (compression_selftest.py:84-90). No test feeds a crafted declared block size, an attacker-sized ZSO span, or a widened index pair, and none asserts the resulting behaviour as correct. *No encoding; the crafted-input cases are simply absent from this section.*
- **-066 (launcher block-device seek state assigned before validation):** test_raw_storage.py:223-232 pins cache invalidation on a *successful* re-seek, and :311-327 pins request-boundary reads; no test in the section performs a *failed* seek and then asserts on the following read — so nothing encodes the stale-cache/fabricated-zero behaviour as correct. *Absence, not encoding.*

---

*End of S2. Clone left untouched: `git status --porcelain` empty on completion.*
