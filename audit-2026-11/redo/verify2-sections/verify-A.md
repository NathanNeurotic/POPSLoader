# Adversarial Verification — Batch A (RE-SERV-001 … RE-SERV-027)

- **Subject:** Blind redo audit of PS2-Servers, findings RE-SERV-001–027 in `Redo-PS2Servers.md` (Python SMB2 server + Python SMB1 server core).
- **Pin confirmation:** `git -C ~/workspace/audit-clones-2026-11-13/PS2-Servers rev-parse HEAD` → `c5f021c4d38698860f56b03498adc261dbb8d8dd` — matches the assigned pin exactly.
- **Date:** 2026-11-14 (America/Los_Angeles).
- **Method:** Refute-first. Every cited file/function/literal was grepped and opened at the cited lines in the pinned clone (read-only; clone never written). All executions ran on copies under `/tmp/vA/run/` driving the handlers directly. No finding in this batch required UDP, so no BLOCKED-ENV verdicts arose.
- **Duplicates:** No two findings in this range are the same mechanism. RE-SERV-002/003 are complementary halves of one design gap (write-side vs read-side DesiredAccess) but distinct mechanisms and distinct code paths. RE-SERV-015/025 and RE-SERV-017/025 are parallel instances of the same flaw families in two different servers (SMB2 `smb2_wire.py`/`smb2_server.py` vs SMB1 `smbserver_opl.py` — the SMB1 framing code is the code the SMB2 module says it lifted), not duplicates of each other.

---

### RE-SERV-001 — VERIFIED
- **Citations:** All exact. `_UNSIGNED_OK` at smb2_server.py:537-538; `_signature_check` returns `None` when `signing_key is None` at 552-553; `h_negotiate` overwrites `conn.dialect`/`conn.negotiate_claims` at 755/771 with no `authenticated` guard; SESSION_SETUP NTLM-NEGOTIATE branch sets `signing_key=None`, `signing_required=False` at 855-856 and never touches `conn.authenticated`. `validate_negotiate_info` at 1406-1429 compares against `conn.negotiate_claims` (1423).
- **Mechanism:** Re-derived from scratch; no defeating guard exists in either handler or in `_dispatch`/`_signature_check`.
- **Execution (mine):** With `authenticated=True`, `signing_required=True`, key set: unsigned SESSION_SETUP/NTLM NEGOTIATE → status `0xC0000016` (MORE_PROCESSING_REQUIRED), `authenticated=True` afterwards, `signing_key=None`, `signing_required=False`; a subsequent unsigned CREATE passed `_signature_check` (returned `None`). Unsigned mid-session NEGOTIATE offering only 0x0202 → SUCCESS, dialect `0x0302 → 0x0202`, `negotiate_claims` replaced with `(0, b'\x00'*16, 0, (514,))`. Matches the report's executed proof in every particular.
- **Fix:** Coherent and LESS-NOT-MORE compliant (a guard/teardown at two existing branches, no new abstraction).

### RE-SERV-002 — VERIFIED
- **Citations:** All exact. CREATE create/truncate effects at 1023-1040 precede the `can_write` assignment at 1050; DELETE_ON_CLOSE armed at 1051-1053; CLOSE delete at 1083-1088; SET_INFO disposition at 1333-1335 and rename at 1340-1357 have no `can_write` check, while WRITE (1177) and the EOF truncate (1328-1329) do.
- **Mechanism:** Confirmed by reading; the only gate on the destructive CREATE branches is `srv._writable(share)` (share-level, not handle-level).
- **Execution (mine):** (1) CREATE `DesiredAccess=FILE_READ_DATA` + `FILE_OVERWRITE` → SUCCESS, `can_write=False`, 100-byte file truncated to **0 bytes**. (2) SET_INFO rename through a read-only handle → SUCCESS, source gone, destination exists. (3) CREATE read-only + `FILE_DELETE_ON_CLOSE` → `delete_on_close=True`; CLOSE → SUCCESS, file deleted. (4) Bonus: SET_INFO FileDispositionInformation through a read-only handle → SUCCESS, `delete_on_close` armed. All three of the report's executed proofs reproduce exactly.
- **Fix:** Coherent; reuses the existing WRITE check at the points the report names.

### RE-SERV-003 — VERIFIED-DRIFT
- **Citations:** `h_read` at 1130-1157 and `Handle` at 150-166 are exact (slots contain `can_write`, no read field). One citation is wrong: the report cites `smb2_wire.py:143-145` for `ACCESS_WRITE_ANY`, but that constant is defined at **smb2_wire.py:114-116** (`ACCESS_WRITE_ANY = 0x00000002 | 0x00000004 | 0x02000000 | 0x10000000 | 0x40000000` at line 116); lines 143-145 are `STATUS_MEDIA_WRITE_PROTECTED`/`STATUS_DISK_FULL`/`STATUS_CANNOT_DELETE`. Grep for `can_read` across `smb2_server/*.py`: zero hits — the substance ("no read mask/read concept exists") is true.
- **Mechanism:** `h_read` checks only pipe/directory, then `_open_file(h, writable=False)` and reads; nothing consults DesiredAccess.
- **Execution (mine):** Handle created with `DesiredAccess=FILE_WRITE_DATA` only → `h_read` returned SUCCESS with data `b'TOPSECRET-DATA'` — byte-identical to the report's proof.
- **Fix:** Coherent (mirror the existing `can_write` pattern); no new abstraction.

### RE-SERV-004 — VERIFIED
- **Citations:** Exact — smb2_server.py:1336-1339 returns `STATUS_SUCCESS` for `FILE_BASIC_INFORMATION` with the Explorer comment and no payload validation (contrast the rename branch's length checks at 1340-1348 and the EOF branch's `len(payload) >= 8` at 1326).
- **Mechanism:** No `os.utime` or any other effect anywhere in the branch.
- **Execution (mine):** Zero-length payload → SUCCESS (`0x00000000`). A well-formed 40-byte payload carrying a LastWriteTime of 116444736000000000 (Unix epoch as FILETIME) → SUCCESS and the file's `st_mtime_ns` was **unchanged**.
- **Fix:** Coherent; the minimal half (validate payload length) is pure LESS.

### RE-SERV-005 — VERIFIED
- **Citations:** Exact. AUTHENTICATE failure paths raise at 884/894-905 before `conn.challenge = None`, which appears only on the success path at 909; `Authenticator.verify` (smb2_auth.py:277-324) keeps no attempt state. Grep: no counter/lockout/delay in the auth path; the only `time.sleep` calls in smb2_server.py are at 1527/1563/1668, all inside the Windows take-445 service choreography, as the report states.
- **Mechanism:** A failed AUTHENTICATE leaves `conn.challenge`, `conn.ntlm_negotiate`, `conn.ntlm_challenge` untouched, so the same challenge can be retried immediately and indefinitely.
- **Execution (mine):** Drove a failed AUTHENTICATE (anonymous token against a password-configured server) with `conn.challenge = b'\x11'*8` preset: raised `Smb2Error` with status `0xC000006D` (LOGON_FAILURE); afterwards `challenge` was still `b'\x11'*8` and `authenticated=False`. (The report filed this as READ/Med; the challenge-survival half is now executed. The no-throttling half is grep-verified absence, as the report framed it.)
- **Fix:** Coherent; the per-connection counter is small state at an existing point, justified in the finding itself.

### RE-SERV-006 — VERIFIED
- **Citations:** Exact. `h_logoff` (927-933) clears handles/trees/`authenticated` only; session ids are minted only `if conn.session_id == 0` at 862-863 and 914-915.
- **Mechanism:** Nothing after `h_logoff` clears the id either; the signing-key comment at 931-932 explains the key's survival for the LOGOFF reply but the id has no such need — and the reply header is built as `conn.session_id or hdr.session_id` (line 486), so the fix's own caution is well-placed.
- **Execution (mine):** `session_id=0x1122334455667788` → `h_logoff` returned SUCCESS, `authenticated=False`, `session_id` still `0x1122334455667788`. (Report filed READ/Med; now executed.)
- **Fix:** Coherent, with the reply-header interaction correctly flagged in the finding itself.

### RE-SERV-007 — VERIFIED
- **Citations:** Exact. `h_tree_disconnect` (974-976) pops and returns SUCCESS; `h_echo` (1363-1364) returns SUCCESS unconditionally; `h_logoff` (927-934) — none calls `_require_session`/`_tree`, unlike every other stateful handler.
- **Mechanism:** Confirmed; no dispatcher-level session gate exists either (`_dispatch` goes straight to the handler table).
- **Execution (mine):** On a fresh, never-authenticated connection: TREE_DISCONNECT for tree id 99 → `0x00000000`, ECHO → `0x00000000`, LOGOFF → `0x00000000`. Matches the report's proof.
- **Fix:** Coherent; correctly leaves ECHO's unauthenticated behaviour as an explicit choice.

### RE-SERV-008 — VERIFIED
- **Citations:** Exact — smb2_spnego.py:330-341: unwrap only when `NEGOTIATE_KEY_EXCH` is set **and** `len(encrypted_session_key) == 16`; otherwise `return session_base_key` silently. Call site at smb2_server.py:901 as the fix cites.
- **Mechanism:** No error, log, or distinguishing return on the fallback path.
- **Execution (mine):** Credentials stub with KEY_EXCH set and a 5-byte wrapped key → `exported_session_key` returned the 16-byte base key **unchanged** (`out == base` is True). Matches the report's proof.
- **Fix:** Coherent (fail at the existing call site with the existing error type).

### RE-SERV-009 — VERIFIED
- **Citations:** Exact — smb2_server.py:429-434: `parse_header` failure at `offset > 0` falls through to a bare `return`; replies accumulated in the local `replies` list are sent only after the loop (494-495).
- **Mechanism:** No partial-send path exists anywhere in `_dispatch_all`.
- **Execution (mine):** Compound = one valid ECHO (NextCommand=72) + 64 zero bytes, driven through `_dispatch_all` with a recording fake socket: **0 `sendall` calls, 0 bytes sent**. Matches the report's proof exactly.
- **Fix:** Coherent (send what was accumulated; no new machinery).

### RE-SERV-010 — VERIFIED
- **Citations:** Exact — smb2_server.py:1258-1263: the break condition is `if total + len(padded) > out_len and entries:`, so the first entry is always emitted.
- **Mechanism:** No first-entry oversize check; `STATUS_INFO_LENGTH_MISMATCH` exists (wire:142) and is used by `h_query_info` (1305-1306) as the fix notes.
- **Execution (mine):** `out_len=16` → SUCCESS with OutputBufferLength **96** using info class 0x03 (FileBothDirectoryInformation) — the report's exact figure; 112 with class 0x25 and 72 with class 0x02 in my runs, i.e. the oversize is class-dependent but always > 16 with SUCCESS.
- **Fix:** Coherent; reuses an already-defined, already-used status.

### RE-SERV-011 — VERIFIED
- **Citations:** Exact — smb2_server.py:1204-1207: `keep = [n for n in names[:2]]` unconditionally, `fnmatch` applied only to `names[2:]`.
- **Mechanism:** The dot entries' existence is deliberate (docstring 1193-1197); only the filter bypass is the defect, as the report says.
- **Execution (mine):** `_listing_for(handle, "*.iso")` on a directory containing `onlyfile.iso` + `other.txt` returned `['.', '..', 'onlyfile.iso']` — identical to the report's proof.
- **Fix:** Coherent and minimal.

### RE-SERV-012 — VERIFIED
- **Citations:** Exact. File branch 1146-1153 raises `STATUS_END_OF_FILE` whenever `fh.read()` returns empty; pipe branch 1137-1139 raises `STATUS_PIPE_EMPTY` on empty data.
- **Mechanism:** Pipe half re-derived: `SrvsvcPipe.read(length)` (smb2_srvsvc.py:139-142) with `length=0` returns `(b'', …)`, and `h_read` raises PIPE_EMPTY on `not data` regardless — so a zero-length pipe READ is PIPE_EMPTY even when the pipe holds data.
- **Execution (mine):** Zero-length READ at offset 0 of a non-empty file raised `Smb2Error` status `0xC0000011` ("read past the end") — the report's exact result. (Pipe half verified by reading, as above.)
- **Fix:** Coherent (one `length == 0` special case before either branch).

### RE-SERV-013 — VERIFIED
- **Citations:** Exact — smb2_server.py:748-757: the dialect loop `break`s at 752-753 when the body runs out; claims are stored from the truncated list at 755.
- **Mechanism:** No count-vs-body validation anywhere in `h_negotiate` beyond the initial `len(body) < 36` check.
- **Execution (mine):** NEGOTIATE with `DialectCount=3` but one dialect (0x0210) in the body → SUCCESS, `conn.dialect=0x0210`, stored claims `(0, b'\x00'*16, 0, (528,))` — the truncated one-dialect tuple enshrined, exactly as the report describes.
- **Fix:** Coherent; same error style as every other short request in the file.

### RE-SERV-014 — VERIFIED
- **Citations:** Exact — `h_flush` at 1102-1111 has no length check before `body[8:24]`/`handle_from`, and wraps flush+fsync in `except OSError: pass`. Contrast verified: `h_read` checks `len(body) < 48` at 1132-1133, as do CLOSE/CREATE/WRITE/QUERY_*/SET_INFO/IOCTL; FLUSH is the only FileId-taking handler without one.
- **Mechanism:** `handle_from` (265) does `struct.unpack("<QQ", raw_file_id)` — a short slice raises `struct.error`, which `_dispatch`'s generic `except Exception` (644-646) flattens to INVALID_PARAMETER, exactly the catch-all path the report describes.
- **Execution (mine):** (1) 8-byte FLUSH body raised `struct.error: unpack requires a buffer of 16 bytes` out of `h_flush` — the report's exact message. (2) A handle whose `fileno()`/fsync fails with OSError → `h_flush` returned SUCCESS (`0x00000000`).
- **Fix:** Coherent; both halves reuse existing patterns (`len` check; `_status_for_oserror` via the dispatcher's OSError mapping).

### RE-SERV-015 — VERIFIED-DRIFT
- **Citations:** Framing locations exact (`_recv_exact` smb2_wire.py:27-34 with `buf += chunk` at 33; `recv_msg` 37-54 trusts the 24-bit length, max 16,777,215). One line drift: the report cites the advertised 1 MiB maxima at "smb2_wire.py:204-206"; they are actually at **206-208** (`MAX_TRANSACT`/`MAX_READ`/`MAX_WRITE = 1 << 20`).
- **Mechanism:** No cap anywhere between `recv_msg` and dispatch; the length is honoured before any header/dialect/session check (`_serve_client` 391-397). The quadratic claim follows directly from repeated `bytes` concatenation at line 33.
- **Execution (mine):** `recv_msg` over a fake socket accepted and returned a **2,000,000-byte** frame — nearly 2× `MAX_TRANSACT` (1,048,576) — with no complaint. (Quadratic cost verified by reading; no timing run needed to establish the algorithm.)
- **Fix:** Coherent; the cap is tied to a number the server already advertises, and list/bytearray accumulation is a local change.

### RE-SERV-016 — VERIFIED
- **Citations:** Exact. `send_msg` at smb2_wire.py:23-24 (`len(msg).to_bytes(3, "big")`); `_dispatch_all` builds the compound reply `out` with no size bound (469-495); `_serve_client` (385-415) catches only `ConnectionResetError/ConnectionAbortedError/BrokenPipeError` and `OSError`.
- **Mechanism:** `OverflowError` is not an `OSError`, and the per-handler catch-all in `_dispatch` (644-646) does not cover `send_msg`, which is called from `_dispatch_all` after the handler loop — so the exception escapes `_serve_client` and kills the thread. (Thread death is inferred from the `except` clauses, exactly as the report itself labels it.)
- **Execution (mine):** `send_msg` with a 16 MiB + 1 message raised `OverflowError: int too big to convert` — the report's exact result.
- **Fix:** Coherent; the minimum variant (make the failure an OSError subclass) is pure LESS.

### RE-SERV-017 — VERIFIED
- **Citations:** Exact. `serve_forever` (337-362) spawns an unbounded daemon thread per accept (360-362); `_serve_client` sets only TCP_NODELAY on the accepted socket (390) — grep confirms the file's only `settimeout` is on the listening socket at 342; `add_handle` (245-251) never refuses; TREE_CONNECT allocates a tree per request (963-965, within the cited 949-972) with no cap.
- **Mechanism:** Grep-verified absence: no connection counter, no accepted-socket timeout, no handle/tree cap anywhere in the serving path. Handles do hold no descriptor until first use, as the report concedes.
- **Execution:** n/a — absence claim, established by full read + grep of the serving path (the report likewise files it READ/Med).
- **Fix:** Coherent; three small checks at three existing allocation points reusing the already-defined `STATUS_INSUFFICIENT_SERVER_RESOURCES` (wire:133 — note the wire constant is spelled `STATUS_INSUFF_SERVER_RESOURCES`). The additions carry the finding's own justification.

### RE-SERV-018 — VERIFIED
- **Citations:** Exact. CREATE records only the path and opens nothing (1049-1053, stat at 1042); `_open_file` opens `h.path` on first use (1114-1127); CLOSE stats/deletes by path (1077, 1083-1088); QUERY_INFO stats by path (1291).
- **Mechanism:** The CREATE-time `os.stat` result is used only for the CREATE reply; no identity (`st_dev`/`st_ino`) is stored on `Handle` (slots at 152-153 confirm none exists).
- **Execution (mine):** Handle created on a file containing `ORIGINAL`; after `os.replace` swapped in a file containing `REPLACED!`, `h_read` returned SUCCESS with data `b'REPLACED!'` — the report's exact proof, including the replacement string.
- **Fix:** Coherent and minimal (two integers + one comparison at the single lazy-open point); preserves the documented descriptor-saving rationale.

### RE-SERV-019 — VERIFIED
- **Citations:** Exact — smb2_wire.py:438-439: `FILE_ACCESS_INFORMATION` returns `struct.pack("<I", 0x001F01FF)` unconditionally; `file_info` receives `read_only` (422) and uses it for attributes but not for this class. The read-only tree-connect mask the fix cites is at smb2_server.py:969 (`0x001200A9`), as stated.
- **Mechanism:** No caller-dependent variation: `h_query_info` passes `read_only` in (1288, 1293) and it is ignored for this class.
- **Execution (mine):** `file_info(FILE_ACCESS_INFORMATION, st, read_only=True)` returned `0x001F01FF` — the report's exact result.
- **Fix:** Coherent; derives from state the caller already passes.

### RE-SERV-020 — VERIFIED
- **Citations:** Exact — smb2_server.py:1340-1357: the rename branch reads byte 0 (ReplaceIfExists) and the name length at offset 16, never bytes 8-15 (RootDirectory), resolves via `h.share.resolve(target)` (1350, share root), and stores the raw client string as `h.rel` (1356).
- **Mechanism:** No RootDirectory handling exists anywhere in the handler.
- **Execution (mine):** SET_INFO rename with a non-zero RootDirectory field and name `relname.iso` on a handle to `subdir/onlyfile.iso` → SUCCESS; the file landed at the **share root** (`relname.iso` exists at root, not in `subdir`), and `h.rel` was the raw `'relname.iso'`. Matches the report's READ claim in full.
- **Fix:** Coherent; the refuse-with-NOT_SUPPORTED variant is the LESS option and is offered as such.

### RE-SERV-021 — VERIFIED
- **Citations:** All exact. `--user NAME:PASSWORD` at smb2_server.py:1741-1742; `build_authenticator` splits the spec at 1708-1724 (split at 1713); the module docstring's own example shows `--user ripto:secret` at line 44.
- **Mechanism:** Argv visibility (process list / shell history / launcher logs) is a platform fact, not a code path; the code side — the password is taken verbatim from argv with no file alternative — is confirmed by reading `main()` in full: no `--users-file` or env alternative exists.
- **Execution:** n/a (READ claim, as filed).
- **Fix:** Coherent; the added `--users-file` feeds the same `user_specs` list `build_authenticator` already consumes, and the finding carries the required justification for an addition. Keeping `--user` working avoids breaking the launcher.

### RE-SERV-022 — WEAKENED
- **Citations:** Handler block at smbv1_server/smbserver_opl.py:537-637, SMB2 dispatch in `serve_conn` at 1435-1458, and the `main()` INCOMPLETE warning at 1724-1728 all exist as cited. The dispatch branch indeed never applies `_logon_required` — grep shows that gate is called only at line 1472, in the SMB1 path.
- **Mechanism — what verifies:** `h2_session_setup` succeeds as guest (SessionFlags `0x0001`) with no credential check; `h2_create` returns one constant FileId and CreateAction 1 (FILE_OPENED) for any path; `h2_read` returns 0 bytes with SUCCESS; `h2_write` returns SUCCESS with count 0 and writes nothing; `h2_negotiate` embeds the fixed sequential GUID `01 02 … 10` (line 545); the real ECHO command 0x000D is unmapped and 0x0012 (OPLOCK_BREAK) is mapped to `h2_echo`. All executed by me (below) except as noted.
- **Mechanism — what does NOT verify (narrowing evidence):** The report states "`h2_tree_connect` succeeds for any share name without consulting `server.shares`". It does not succeed at all: at smbserver_opl.py:573-581 it calls `struct.pack("<BBII", 16, 0x01, 0, 0x00000030, 0x000f001f)` — a 4-field format given **5 values** — and raises `struct.error: pack expected 4 items for packing (got 5)` on **every** call (executed by me). In `serve_conn` that exception escapes the `except (ConnectionError, OSError)` handler (1497), so an SMB2 TREE_CONNECT kills the connection thread instead of returning a fake success. The handler is still a stub that does no work and never consults `server.shares` — but its observable behaviour is a crash, not a success, so the finding's "every handler fabricates a successful reply" framing is true only of the other handlers. Second, smaller error: the report says QUERY_DIRECTORY is command 0x000A; in this codebase's own constants (smb2_wire.py:85-89) 0x000A is LOCK and QUERY_DIRECTORY is **0x000E**. 0x000E is indeed absent from `SMB2_HANDLERS`, so the "share can never be listed" conclusion stands, but the cited command value is wrong.
- **Execution (mine):** `h2_write` on a `read_only=True` server → status `0x00000000`, written count **0** (the report's exact executed claim). `h2_read` → SUCCESS, data length 0. `h2_create` → SUCCESS, CreateAction=1, FileId `01000000000000000100000000000000` (the constant). `h2_session_setup` with users configured → SUCCESS, SessionFlags `0x0001` (IS_GUEST), uid assigned. `h2_tree_connect` → `struct.error` (above), **not** SUCCESS.
- **Fix:** Unaffected and coherent — deleting the stub surface / refusing non-1 at startup remains the right LESS-NOT-MORE remedy; the tree-connect crash makes the stub *less* functional than the report believed, not more defensible.

### RE-SERV-023 — VERIFIED
- **Citations:** Exact. `h_read_andx` (957-985) and `h_write_andx` (1012-1035) unpack fixed offsets with no WordCount/length guard; `_trans2_parse` (1114-1126) likewise; `h_trans2_find_next2` unpacks `t_params` at 1259; `serve_conn`'s only handler is `except (ConnectionError, OSError)` at 1497. The contrast guards exist as claimed (`_parse_session_setup` wordcount guard at 702; `h_nt_create_andx` length guard). `Req` truncates silently exactly as described: `self.params = msg[33:33 + wc*2]` (line 245) — Python slicing shortens without error.
- **Mechanism:** `struct.error` is not an `OSError`, so it escapes `serve_conn` and kills the connection thread with no SMB error reply; the server process survives (thread-per-connection), as the report states.
- **Execution (mine):** With a 2-byte params block, **all four** raised `struct.error` (report executed two): `h_read_andx` ("requires a buffer of at least 6 bytes … at offset 4"), `h_write_andx` (same), `_trans2_parse` ("at least 20 bytes … at offset 18"), and `h_trans2_find_next2` with empty `t_params` ("at least 2 bytes … at offset 0"). `isinstance(e, OSError)` is False for each.
- **Fix:** Coherent; the per-handler guard matches the file's existing pattern and is the smaller change, as the report argues.

### RE-SERV-024 — VERIFIED
- **Citations:** Exact in substance. `h_session_setup` calls `hmac.compare_digest(password, expected)` at smbserver_opl.py:746; `--user` parsing in `main()` (1730-1737, within the cited 1731-1747) accepts any password string. One premise is slightly overbroad but widens rather than narrows the bug: the report says the incoming password "is always pure ASCII" — true of the ANSI path (line 713, `"ascii", "ignore"`), but the Unicode fallback at line 715 decodes UTF-16LE and can itself yield non-ASCII, which triggers the same `TypeError` from the other side.
- **Mechanism:** `hmac.compare_digest` on `str` operands raises `TypeError` if **either** side is non-ASCII; the configured side is unrestricted, so a non-ASCII configured password crashes every login attempt, and per RE-SERV-023's dispatch the exception kills the connection thread.
- **Execution (mine):** `hmac.compare_digest("abc", "päss")` → `TypeError: comparing strings with non-ASCII characters is not supported` (the report's exact message). End-to-end: `h_session_setup` with configured user `{"user": "päss"}` and a well-formed request for that account raised the same `TypeError` out of the handler — not a LOGON_FAILURE.
- **Fix:** Coherent and minimal (compare on encoded bytes).

### RE-SERV-025 — VERIFIED
- **Citations:** Exact in substance. `recv_msg`/`_recv_exact` at smbserver_opl.py:183-207 accept the 24-bit length as-is (identical framing code to RE-SERV-015's, in the SMB1 file); `h_negotiate` advertises MaxBufferSize 65535 at line 679 (within the cited 676-690); the accept loop spawns an unbounded daemon thread per connection at 1843-1845 and sets only TCP_NODELAY on accepted sockets (1843) — grep confirms the file's only `settimeout` is on the **listening** socket at 1828.
- **Mechanism:** 16,777,215 max frame ≈ 256× the advertised 65,535 — the report's arithmetic checks. No idle timeout and no thread cap exist anywhere in the file.
- **Execution:** n/a — READ claim as filed; the identical framing mechanism was executed against the SMB2 copy under RE-SERV-015 (2,000,000-byte frame accepted).
- **Fix:** Coherent; both bounds are constants tied to the negotiated maximum, no new configuration.

### RE-SERV-026 — VERIFIED
- **Citations:** Exact — smbserver_opl.py:1064-1068: `h_query_disk` packs `struct.pack("<HHHHH", 0xFFFF, 64, 512, 0xFFFF, 0)` with the comment "smbman just needs non-zero free space" at 1065. Grep confirms no `disk_usage` call exists in the file.
- **Mechanism:** Total and free units are constants independent of the volume: 0xFFFF × 64 × 512 = 2,147,450,880 bytes (~2 GiB), as the report states.
- **Execution:** n/a — READ claim as filed; the constants are on the face of the code.
- **Fix:** Coherent; `shutil.disk_usage` on the share root scaled into the existing u16 packing is a local change.

### RE-SERV-027 — VERIFIED
- **Citations:** Exact. `_env_bool` at udpfs_server.py:3297-3302 (`v.strip().lower() in ('1', 'true', 'yes', 'on')`, everything else False, no warning); the six `store_true` flags with `_env_bool` defaults at ps2servers_core.py:535-560 (`--read-only`/`RO` at 535-536, `--verbose` 537-538, `--single-port` 545-546, `--modulo-mode` 552, `--metrics` 558, `--session-summary` 559-562); the compression `--enable-compression`/`--no-compression` pair exists in the same parser at 540-541, as the report notes.
- **Mechanism:** `store_true` with an env-derived default has no CLI off-switch; grep of the built parser's option strings confirms no `--no-read-only` (or any negative counterpart for the six flags).
- **Execution (mine):** `_env_bool("RO")` with `RO=2` → `False` (with `RO=true` → `True` as control). End-to-end: `build_parser().parse_args([])` with `RO=2` → `read_only=False`; with `RO=1` → `read_only=True`. The report's executed claim reproduces exactly, through the real parser.
- **Fix:** Coherent; the warning-only half is the whole safety fix and adds nothing structural, exactly as scoped in the finding.

---

## Tally

| Verdict | Count | IDs |
|---|---|---|
| VERIFIED | 24 | 001, 002, 004, 005, 006, 007, 008, 009, 010, 011, 012, 013, 014, 016, 017, 018, 019, 020, 021, 023, 024, 025, 026, 027 |
| VERIFIED-DRIFT | 2 | 003, 015 |
| WEAKENED | 1 | 022 |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — |
| **Total** | **27** | |

## CANDIDATES (new defects found while verifying — separate from the verdicts)

- **CAND-A1 — `h2_tree_connect` in the SMB1 file's SMB2 stub crashes on every call (struct.pack arity bug).** `smbv1_server/smbserver_opl.py:573-581`: `struct.pack("<BBII", 16, 0x01, 0, 0x00000030, 0x000f001f)` passes 5 values to a 4-field format. Executed by me: raises `struct.error: pack expected 4 items for packing (got 5)` unconditionally. Because the SMB2 dispatch branch in `serve_conn` (1435-1454) sits under the same `except (ConnectionError, OSError)` handler (1497) identified in RE-SERV-023, the exception kills the connection thread — so with `--smb-version 2/3`, any SMB2 TREE_CONNECT drops the connection rather than returning even the stub's fake success. Distinct from RE-SERV-022 (which asserted this handler returns success) and from RE-SERV-023 (SMB1 parameter blocks); it is the same escape-path weakness manifesting inside the SMB2 stub itself.
