# Round 7 — Section S1: SMB-family Python test files (`tests/`)

- **Repo / pin:** NathanNeurotic/PS2-Servers at `c5f021c4d386` (verified at start; `git status` clean at finish).
- **Scope:** test-suite defects only. The shipped servers were not re-audited; PS2SERVERS-001…069 stand as-is. Where a shipped file is cited, it is only to prove what a test does or does not exercise.
- **Method:** every assigned file read in full, in the assigned order; AST scans for assertion-less test methods, self-comparisons, `except`-swallowing, skip calls, assertions nested in loops/conditionals, exact duplicate method bodies (AST body-hash), and unused module-level imports/helpers; grep verification of every imported name / referenced attribute against the shipped tree; `unittest` loader count (imports only, `PYTHONDONTWRITEBYTECODE=1`); two direct-execution runs for S1-01.
- **Collection status (EXECUTED):** all 20 modules load and collect under `python -m unittest` at this pin — **289 tests total**. No test module errors at import in this environment.

---

## 1. Per-file ledger

| # | File | Lines | Read in full |
|---|------|------:|:--:|
| 1 | `tests/test_smb2_server.py` | 944 | Y |
| 2 | `tests/test_smb2_signed_sessions.py` | 358 | Y |
| 3 | `tests/test_smb2_libsmb2_compat.py` | 358 | Y |
| 4 | `tests/test_smb2_take_445.py` | 396 | Y |
| 5 | `tests/test_smb2_auth.py` | 277 | Y |
| 6 | `tests/test_smb2_signing.py` | 136 | Y |
| 7 | `tests/test_smb2_independent_client.py` | 199 | Y |
| 8 | `tests/test_smb2_wire.py` | 208 | Y |
| 9 | `tests/test_smb2_paths.py` | 249 | Y |
| 10 | `tests/test_smb2_share_name.py` | 61 | Y |
| 11 | `tests/test_smb2_banner.py` | 134 | Y |
| 12 | `tests/test_gui_smb2_start_needs_login.py` | 55 | Y |
| 13 | `tests/test_smb_wire_parity.py` | 186 | Y |
| 14 | `tests/test_smbv1_share_and_credentials.py` | 303 | Y |
| 15 | `tests/test_smbv1_compressed.py` | 264 | Y |
| 16 | `tests/test_smbv1_read_after_write.py` | 95 | Y |
| 17 | `tests/test_smbv1_write_semantics.py` | 164 | Y |
| 18 | `tests/test_smbv1_logon_required.py` | 166 | Y |
| 19 | `tests/test_smbv1_diagnostics.py` | 145 | Y |
| 20 | `tests/test_netinfo_and_smb.py` | 253 | Y |
| | **Total** | **4,951** | |

---

## 2. Candidate findings

### S1-01 / Mid-file `unittest.main()` orphans 28 tests when the file is run directly — both runs report green
- **Category:** Test-suite structure / silent skip
- **Locations:** `tests/test_smb2_server.py:616-617` (`if __name__ == "__main__": unittest.main()`), with 8 test classes / 23 tests defined *after* it at `:620-944` (`MalformedRequestBuffers` :620, `RenameSafety` :697, `ParentEntry` :736, `DomainHandling` :758, `SecurityBufferFraming` :808, `NeutrinoClientShape` :870, `ShareNameCollisions` :906, `BindHint` :915); `tests/test_smb2_paths.py:202-203`, with `WindowsDeviceNames` (5 tests) defined after it at `:206-249`.
- **Problem:** EXECUTED at this pin. `python tests/test_smb2_paths.py` runs **14 tests, OK**; `python -m unittest tests.test_smb2_paths` runs **19 tests, OK**. `python tests/test_smb2_server.py` runs **33 tests, OK**; the module form collects **56**. `unittest.main()` raises `SystemExit` during module execution, so every class below the guard is never even defined in a direct run — and the direct run still exits green, so nothing tells the runner a third of the file (including all of `MalformedRequestBuffers`, the negative-offset WRITE tests, and all of `WindowsDeviceNames`, the Win32 device-name refusals) never ran. The documented run lines in both docstrings use the `-m unittest` form, which is why this survives: it only bites the equally ordinary `python tests/<file>.py` invocation. The guard's position — exactly at a section break, with substantial classes appended after it in both files — reads as later classes appended past an existing guard.
- **Fix (in words):** Move the two-line guard to the end of each file (delete it from the middle; one guard per file, at EOF). No test body changes.
- **Benefit:** 28 tests (23 + 5) can no longer be silently skipped by invocation style; direct and module runs become identical.
- **Effort:** S. **Risk:** Low (the `-m unittest` form is unaffected; the direct form only gains tests). **Confidence:** READ + EXECUTED (both counts reproduced above).

### S1-02 / Banner address-listing test's only assertions sit in a loop over a host-dependent list that may be empty
- **Category:** Vacuous test (conditional execution)
- **Locations:** `tests/test_smb2_banner.py:125-132` (`LocalAddressListingTests.test_lists_only_real_ipv4_addresses`); the iterated function is `smb2_server/smb2_server.py:76` (`_local_ipv4_addresses`), whose empty result is a contemplated state — its caller handles an empty list at `smb2_server/smb2_server.py:141-145`, and the neighbouring test at `tests/test_smb2_banner.py:112-118` mocks the function returning `[]`.
- **Problem:** All three assertions (`assertNotIn ":"`, not-loopback, IPv4-regex) are inside `for ip in smb2_server._local_ipv4_addresses():`, with no assertion that the list is non-empty and no mock supplying known addresses (unlike `WarningLineTests` in the same file, which mocks it). On a host with no non-loopback IPv4 — a loopback-only container or offline VM — the body executes zero times and the test passes having checked nothing. On this VM the function returned one address (`198.19.0.2`, EXECUTED), so the test is live here and dead exactly in the minimal CI/container environments most likely to be loopback-only.
- **Fix (in words):** Bind the result to a name and assert it is non-empty before the loop (one line), or `skipTest` with an explicit "no non-loopback IPv4 on this host" reason so the skip is visible rather than silent.
- **Benefit:** The only test of the real (unmocked) address enumeration can no longer pass vacuously.
- **Effort:** S. **Risk:** Low. **Confidence:** READ for the structure; INFERRED for the empty-list environment (the function's own empty handling proves the state is possible; it did not occur on this VM).

### S1-03 / Two tests in `test_smbv1_share_and_credentials.py` assert only the constructor assignment they just made, under names claiming behaviour they never exercise
- **Category:** Vacuous test / tautology
- **Locations:** `tests/test_smbv1_share_and_credentials.py:61-63` (`test_a_server_with_no_users_accepts_anyone`: constructs `SmbServer({}, read_only=False)`, asserts `server.users == {}`) and `:182-187` (`TheShareNameIsHonoured.test_a_named_share_is_found`: constructs `SmbServer({"roms": Share("roms", d)}, …)`, asserts `"roms" in server.shares`). The constructor under test does exactly and only the asserted assignments: `smbv1_server/smbserver_opl.py:1518-1529` (`self.shares = shares` :1519; `self.users = {u.casefold(): p for … (users or {})}` :1529 — for the empty input used here, `{}` in, `{}` out).
- **Problem:** Neither test drives a handler, a session setup, or a tree connect. The first test's name claims guest *acceptance* — a wire behaviour — while its body can fail only if the constructor stops storing the dict it was handed. The second's class name claims the share name is *honoured* — a lookup behaviour — while its body can fail only the same way. Both behaviours that are actually load-bearing are already proven elsewhere in the same file by tests that do drive the code: guest acceptance/refusal at `:171-180` (`CredentialsAreActuallyChecked`, via `h_session_setup`) and custom share names reaching the server command line at `:67-70`. (Server-side share-name *lookup* over the wire is not covered anywhere in this section — deleting these two tests loses no real coverage, because neither ever provided any; adding a real TREE_CONNECT test for a custom name would be a separate, justified addition, not part of this deletion.)
- **Fix (in words):** Delete both test methods (9 lines total including the one-class wrapper at :182). Keep the driving tests at :67-70 and :171-180.
- **Benefit:** −9 lines; two green ticks that currently certify behaviours they never ran stop certifying them.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### S1-04 / Stale present-tense docstring in the registry guard test describes the fake SMB2 (PS2SERVERS-042) as the current offered modes — and the test does not guard that fake at all
- **Category:** Test documentation / misleading guard
- **Locations:** `tests/test_netinfo_and_smb.py:87-98` (docstring of `test_no_offered_mode_asks_for_a_dialect_that_cannot_serve_a_file`: "SMB2/SMB3 currently negotiate, authenticate and accept a tree connect, then serve nothing — READ returns zero bytes and QUERY_DIRECTORY is not implemented"); the test's own loop skips every dialect < 2 at `:102-105`.
- **Problem:** At this pin the statement is false of the offered modes: `smbv2`/`smbv3` run the real server (`launcher/servers.py:430-458`, `module_file=smb2_server/smb2_server.py`), whose `_HANDLERS` (`smb2_server/smb2_server.py:1432-1450`) contains both `CMD_QUERY_DIRECTORY` and a real `CMD_READ` — which is precisely why this test passes. The behaviour the docstring describes is the *fake* SMB2 inside the SMB1 file (PS2SERVERS-042: `SMB2_HANDLERS` at `smbv1_server/smbserver_opl.py:626-639` has no QUERY_DIRECTORY and its READ returns zero bytes) — and that implementation is never loaded by this test for any mode: the `smbv1` registry entry is skipped by the dialect < 2 `continue`, and the v2/v3 entries load the other file. A maintainer reading the docstring would believe both that the shipped SMB2 still serves nothing and that the 042 path is guarded by this test; neither is true.
- **Fix (in words):** Rewrite the docstring in the past tense, naming the stub era it was written against, and state the test's actual scope: it guards the handler table of whichever module an offered SMB≥2 registry mode loads — it does not exercise the SMB1 file's SMB2 diversion.
- **Benefit:** The guard's real scope becomes auditable; no future reader mistakes it for coverage of PS2SERVERS-042.
- **Effort:** S. **Risk:** Low (words only; no assertion changes). **Confidence:** READ.

### S1-05 / SMBv1 handler-driving helpers are re-implemented in three test files (one byte-identical, the rest near-identical)
- **Category:** Duplicated test code
- **Locations:** `_request` — byte-identical at `tests/test_smbv1_compressed.py:44-45` and `tests/test_smbv1_read_after_write.py:22-23`, variant at `tests/test_smbv1_write_semantics.py:31-33`. NT-CREATE request builders — `tests/test_smbv1_compressed.py:93-99` (`_create`), `tests/test_smbv1_read_after_write.py:26-33` (`_open`), `tests/test_smbv1_write_semantics.py:35-45` (`_ntcreate_request`): all build the same 48-byte params with NameLength at byte 5 and CreateDisposition at byte 35. READ_ANDX builders — `tests/test_smbv1_compressed.py:101-105` and `tests/test_smbv1_read_after_write.py:36-40`: same `"<BBHHIHHIHI"` pack and same reply slicing. WRITE_ANDX builders — `tests/test_smbv1_compressed.py:116-121`, `tests/test_smbv1_read_after_write.py:43-52`, `tests/test_smbv1_write_semantics.py:48-57`: same fid-at-4 / length-at-20 / data-offset-64-at-22 layout.
- **Problem:** ~93 lines of helper code across the three files encode the same three SMB1 request layouts three times, with small divergences (offset handling, return shape) that are easy to mistake for protocol differences. A layout correction — the kind these files exist to pin — must currently be made in three places and can silently be made in two. No *test method bodies* are duplicated (AST body-hash scan over all 20 files found no duplicated test methods); the duplication is purely at helper level.
- **Fix (in words):** Consolidate the three builders into one shared test helper parameterised by the server module — the parameterisation is mandatory, not optional: `test_smbv1_write_semantics.py:23-28` deliberately loads a *separate* module instance via `importlib`, and a shared helper bound to the common `smb` import would silently destroy that isolation (its `_ntcreate_request` already takes the module as an argument; follow that shape).
- **Benefit:** Est. −30 to −40 lines net (INFERRED) and one place to correct an SMB1 request layout.
- **Effort:** M. **Risk:** Med (only because of the module-isolation constraint above; a careless consolidation changes what write_semantics tests). **Confidence:** READ for the duplication locations; INFERRED for the saving.

### S1-06 / Dead import: `Client` imported into `test_smb2_libsmb2_compat.py` and never used there
- **Category:** Dead code (test file)
- **Locations:** `tests/test_smb2_libsmb2_compat.py:26-27` (`from tests.test_smb2_server import (READ_ONLY, Client, ServerFixture, wire)`).
- **Problem:** `Client` occurs exactly once in the file — in the import itself (grep-verified). The file's tests obtain clients exclusively through `ServerFixture.connected()`; nothing in the repo imports `Client` *from* this module (grep-verified), so it is not a re-export. The `# noqa: F401` on the line suppresses the lint that would have caught it. Its companions are all live: `READ_ONLY` at :206,214, `ServerFixture` as every class's base, `wire` throughout. (Contrast `READ_ONLY` at `tests/test_smb2_server.py:41`, which looks unused in its own file but is imported by `tests/test_smb2_signed_sessions.py:31` and this file — live, not a finding.)
- **Fix (in words):** Remove `Client, ` from the import.
- **Benefit:** −1 name; removes the false impression this file drives the raw `Client` directly.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

---

## 3. Checked and sound (no finding)

- **Collection / deleted-or-renamed code:** All 20 modules import and collect (289 tests, loader EXECUTED). Every imported name and referenced attribute spot-verified present at the pin, including: all `smb2_auth` names used (`Authenticator`, `md4`, `nt_hash`, `ntowfv2`, `ntlmv2_proof`, `parse_ntlmv2_response`, `session_base_key`, `server_challenge`, `lmv2_response`, `blob_timestamp`, `AuthError`); `smb2_spnego` privates used by the clients (`_tlv`, `trim`, `extract_ntlm`, `neg_token_resp`); all `smb2_srvsvc` constants/functions used by `test_smb2_libsmb2_compat.py`; `smb2_server.take_445` / `listen_after_take_445` / `_port_free` / `bind_hint` / `_open_share_warning_lines` / `_local_ipv4_addresses`; `launcher.gui._status_port` / `_needs_admin` / `opl_hint` / `console_config_block` / `LauncherApp.start_server`; `ps2servers._normalize_headless_alias`; the CHD fixture chain used by `test_smbv1_compressed.py:232-261` (`tests/test_ra_compressed_hash.py:19 fixture()` and both fixture directories exist). No test references a symbol absent from the shipped tree.
- **No vacuous-assertion patterns beyond S1-02/S1-03:** AST + grep scan of all 4,951 lines found no `assertTrue(True)`-class assertions, no value-compared-to-itself assertions, and no `except` that swallows `AssertionError` (the sole `except OSError: pass` is socket cleanup in the client helper, `tests/test_smb2_server.py:57-60`, not an assertion path). Test methods with no *local* assertion all delegate to helpers that assert substantively: `tests/test_smb2_libsmb2_compat.py:126-133` → `_related_stat_compound` (:135-161) and `tests/test_smb2_independent_client.py:163-171` → `exercise` (:140-161).
- **Loop/conditional assertions other than S1-02 are guarded:** `test_smb_wire_parity.py`'s `zip(...)` loops are preceded by `_run_go`'s exact line-count assertion (:91-113), so an empty comparison cannot pass; `test_smb2_libsmb2_compat.py:90-118` asserts on the parsed `names` dict after its loop (an empty result fails, not passes); `test_smb2_take_445.py:251-253`'s conditional `-Force` check is preceded by an exact `driver_stops()` equality assertion; `test_netinfo_and_smb.py:87-115`'s registry loop does execute at this pin (dialects 2 and 3 are produced by `launcher/servers.py` `_smbv2_argv`/`_smbv3_argv`).
- **All skips carry reasons and an external home:** `test_smb2_independent_client.py:55` (`skipUnless` smbprotocol; docstring states CI installs it), `test_smb2_signing.py:78` (`skipTest "cryptography not installed"`), `test_smb_wire_parity.py:66-69` (Go-toolchain skip that *fails* instead on CI), `test_smb2_paths.py:155` (symlink capability), `test_smbv1_compressed.py:190` (`skipIf` Windows symlinks) and `:234,248` (libchdr unavailable), `test_gui_smb2_start_needs_login.py:26-28` (`SkipTest "no tkinter"`). None is an unconditional or reason-less skip.
- **Mocked subjects are not mocked away:** in `test_smb2_take_445.py` the unit under test (`smb2.take_445`, `listen_after_take_445`, `Smb2Server.listen`) is real throughout — `FakeServices` fakes only the `subprocess.run` boundary and the tests assert the recorded command sequences; `Port445RetryTests` mocks only the socket/server collaborator of the real retry wrapper. In `test_smb2_banner.py:101-122` only `_local_ipv4_addresses` is mocked, for the real `_open_share_warning_lines`. In `test_gui_smb2_start_needs_login.py` only `messagebox`/`is_windows` are mocked, for the real `LauncherApp.start_server`. In `test_smbv1_diagnostics.py` only `activity`/`time.monotonic` are patched, with assertions on the real `Conn` counters.
- **No test encodes a known defect (PS2SERVERS-042/-043/-063/-064/-065/-069):** searched explicitly. For -042, no test in this section imports or calls the fake `SMB2_HANDLERS`/`h2_*` handlers; the one reference (`test_netinfo_and_smb.py`, see S1-04) asserts the opposite property. For -043, no test asserts that a read-only handle can delete: `ReadOnlyHandles` (`test_smb2_libsmb2_compat.py:203-224`) asserts write and resize are *refused* for a `READ_ONLY` handle, and every delete-on-close test (`test_smb2_server.py:461-470`, `test_smb2_independent_client.py:133-161`) uses a write/delete-access handle — the absence of a read-only-delete test is a coverage gap, not an assertion encoding the bug, so no finding is claimed for it. For -063/-065, `test_smbv1_compressed.py:211-218` asserts a 256 MiB-block CSO is *refused* and `:220-230` asserts inflation is capped at one block — the opposite of the serving-path defects (which live in a path these SMB1 tests do not drive). For -064, ZSO is asserted *not* served (`:183-188`). For -069, no file in this section touches UCI parsing at all.
- **Substantive suites confirmed while reading (weak-looking but real):** the published-vector pinning in `test_smb2_auth.py` (RFC 1320 / MS-NLMP vectors, not round-trips), the known-answer signing vectors in `test_smb2_signing.py`, the structure-size pins in `test_smb2_wire.py` (whose docstring honestly states their limit), the signed-session signature verification in `test_smb2_signed_sessions.py` (reply signatures are cryptographically verified, not merely flagged), and the byte-for-byte Go/Python parity checks in `test_smb_wire_parity.py`.
