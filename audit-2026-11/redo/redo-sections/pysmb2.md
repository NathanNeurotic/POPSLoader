# Python SMB2 server — blind redo audit

- **Repo / pin:** PS2-Servers @ `c5f021c4d386` (clone `~/workspace/audit-clones-2026-11-13/PS2-Servers`, read-only)
- **Scope:** `smb2_server/` — `smb2_server.py`, `smb2_auth.py`, `smb2_crypto.py`, `smb2_paths.py`, `smb2_spnego.py`, `smb2_srvsvc.py`, `smb2_wire.py` (3,957 lines, counted by `wc -l`)
- **Method:** every file read in full. Handler bodies read line by line, not from docstrings. Suspected defects were executed against copies of the seven files under `/tmp/pysmb2test/` (the clone was never edited; no test ran in the clone). No finding rests on a secret value; no hardcoded credential was found in scope (passwords arrive only via `--user`, see PYSMB2-22).

## Verified clean (checked, no finding)

- **Crypto primitives are correct.** Executed: MD4 passes all four RFC 1320 vectors tested and `nt_hash("password")` matches the published NT-hash vector; AES-128 passes the FIPS-197 vector; pure-Python AES-CMAC passes RFC 4493 examples 1–2 and agrees with the OpenSSL native backend on the zero-key/empty case. Signature verification uses `hmac.compare_digest` (`smb2_crypto.py` `verify`), and the unknown-user path in `Authenticator.verify` does dummy proof work before failing (`smb2_auth.py:301-315`).
- **Path containment is sound.** `Share.resolve` (`smb2_paths.py:117-176`) refuses `..` outright, UNC paths, ADS separators, device names, trailing dot/space, and tests containment on the real path with `commonpath`. No traversal bypass found by reading.
- **`request_buffer` bounds-checking is sound** and is used by SESSION_SETUP, TREE_CONNECT, CREATE, WRITE, QUERY_DIRECTORY, SET_INFO and IOCTL (the one handler that does not use it for its FileId is PYSMB2-15).
- **KDF construction** (`smb2_crypto.py` `kdf`) was read against MS-SMB2 3.1.4.2: the double NUL between label and context is the label's own trailing NUL plus the SP800-108 separator, not a duplication bug. INFERRED — no published KDF test vector was available in the sandbox to execute against.

---

### PYSMB2-01 — Pre-authentication commands stay live after authentication and rewrite the session's security state (signing downgrade + negotiate-claims overwrite)
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:537-538 (`_UNSIGNED_OK` exempts NEGOTIATE and SESSION_SETUP from the signing-required check), smb2_server/smb2_server.py:540-563 (`_signature_check` returns None whenever `signing_key` is None), smb2_server/smb2_server.py:745-755 (`h_negotiate` unconditionally replaces `conn.dialect` and `conn.negotiate_claims`), smb2_server/smb2_server.py:840-867 (SESSION_SETUP NTLM NEGOTIATE branch sets `conn.signing_key = None`, `conn.signing_required = False` at 855-856 and never clears `conn.authenticated`)
- **Problem:** Nothing retires the pre-auth commands once a session exists. Executed proof (handler-level, /tmp copy): with `authenticated=True`, `signing_required=True` and a signing key set, an unsigned SESSION_SETUP carrying an NTLMSSP NEGOTIATE returned MORE_PROCESSING_REQUIRED, left `authenticated=True`, and cleared both `signing_key` and `signing_required` — after which an unsigned CREATE passed `_signature_check`. An on-path attacker (or a confused client) can therefore strip signing from a live, signing-required session without re-authenticating, then inject unsigned commands under the victim's identity; every file handle and tree survives. The same hole exists for SMB2 NEGOTIATE: executed proof shows an unsigned mid-session NEGOTIATE changed the live dialect 0x0302 → 0x0202 and overwrote `conn.negotiate_claims` — the stored claims `validate_negotiate_info` (smb2_server.py:1406-1431) compares the client's signed re-statement against, i.e. the anti-downgrade check can be re-based by the very party it exists to catch.
- **Fix:** In `h_negotiate` and in the NTLM-NEGOTIATE branch of `h_session_setup`, refuse (or fully tear down the session — close handles/trees, clear `authenticated`) when `conn.authenticated` is already true. A re-negotiation must never be a silent in-place mutation of a live session.
- **Benefit:** Closes a signing-downgrade / session-hijack path and restores FSCTL_VALIDATE_NEGOTIATE_INFO to comparing against claims the attacker cannot replace.
- **Effort:** M · **Risk:** Med · **Confidence:** High (EXECUTED)

### PYSMB2-02 — CREATE, SET_INFO and CLOSE perform create / truncate / rename / delete without checking the handle's granted DesiredAccess
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:1023-1040 (CREATE creates a file or `os.makedirs` a directory, and truncates an existing file for OVERWRITE / OVERWRITE_IF / SUPERSEDE), smb2_server/smb2_server.py:1050-1053 (`can_write` is computed only *after* those effects; FILE_DELETE_ON_CLOSE is armed on any handle), smb2_server/smb2_server.py:1083-1088 (CLOSE executes the delete), smb2_server/smb2_server.py:1333-1335 (SET_INFO FileDispositionInformation arms delete-on-close with no `can_write` check), smb2_server/smb2_server.py:1340-1357 (SET_INFO rename with no `can_write` check)
- **Problem:** Destructive effects are gated only on the share being writable (`srv._writable`), never on the access the CREATE actually granted — while WRITE (smb2_server.py:1177) and the SET_INFO EOF-truncate (smb2_server.py:1328-1329) *do* check `h.can_write`, proving the intended rule exists and these paths missed it. Executed proofs: (1) CREATE with DesiredAccess = FILE_READ_DATA only and disposition FILE_OVERWRITE returned SUCCESS with `can_write=False` and the target file truncated to 0 bytes; (2) SET_INFO rename through a read-only handle returned SUCCESS and moved the file; (3) CREATE with FILE_DELETE_ON_CLOSE through a read-only handle deleted the file at CLOSE. `os.makedirs` at 1026 also creates every missing intermediate directory as a side effect. A client (or a bug in one) holding only a read handle can destroy, move or delete files it was never granted write access to.
- **Fix:** Compute `can_write` from DesiredAccess before any filesystem effect in `h_create`, and require it (or the specific DELETE access) for the create/truncate branches, for arming delete-on-close, and in the SET_INFO disposition and rename branches — the same check WRITE already makes.
- **Benefit:** DesiredAccess becomes a real boundary instead of an annotation two handlers honour and five effects ignore.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB2-03 — READ is never gated on DesiredAccess; there is no read-access concept at all
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:1130-1157 (`h_read` checks only pipe/directory, then reads), smb2_server/smb2_server.py:150-166 (`Handle` tracks `can_write` and nothing for read), smb2_server/smb2_wire.py:143-145 (only `ACCESS_WRITE_ANY` is defined; no read mask exists)
- **Problem:** Any successfully created handle can be read, including one opened with DesiredAccess = FILE_WRITE_DATA only, or with no data access at all. Executed proof: a handle created write-only returned the file's contents (`b'TOPSECRET-DATA'`) from `h_read` with STATUS_SUCCESS. Combined with PYSMB2-02, DesiredAccess is decorative in both directions.
- **Fix:** Record a `can_read` on the handle from the same CREATE access mask (FILE_READ_DATA | GENERIC_READ | MAXIMUM_ALLOWED | GENERIC_ALL) and check it in `h_read`'s file branch, mirroring the existing `can_write` check in `h_write`.
- **Benefit:** A write-only or attribute-only handle stops being a read channel for the file's contents.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB2-04 — SET_INFO FileBasicInformation returns SUCCESS while doing nothing — and validates nothing
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:1336-1339
- **Problem:** The handler returns STATUS_SUCCESS for FileBasicInformation without applying the timestamps, and without even checking the payload exists: executed proof shows a SET_INFO with a zero-length payload returns SUCCESS. The in-code comment frames this as an Explorer-compatibility trade-off, but on the wire it is indistinguishable from success — a client copying files (or a backup tool preserving timestamps) is told the times were set when they were silently discarded, so copies quietly carry wrong timestamps with no error anywhere.
- **Fix:** Either apply the times (`os.utime` from the payload's LastWriteTime/ChangeTime fields, after a length check) or answer STATUS_NOT_SUPPORTED so the client knows. Keeping the Explorer behaviour is a defensible choice; reporting success for an empty payload is not — at minimum validate the payload length like the rename branch does.
- **Benefit:** Removes a false-success from the protocol surface; timestamp-preserving copies either work or fail visibly.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB2-05 — No throttling of failed logons, and the NTLM challenge survives a failed AUTHENTICATE
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:871-905 (AUTHENTICATE path; failure raises and leaves connection state untouched), smb2_server/smb2_server.py:907-909 (`conn.challenge` is cleared only on success), smb2_auth.py:262-324 (`verify` keeps no attempt state)
- **Problem:** A failed SESSION_SETUP costs the attacker nothing: no delay, no per-connection or per-account failure counter, no teardown after repeated failures, and the same server challenge remains valid, so the client can retry AUTHENTICATE against it immediately, indefinitely. Grep-verified: no sleep, counter or lockout exists anywhere in the auth path (the only `time.sleep` calls in the file are in the Windows take-445 service choreography). Online password guessing against the one configured user is therefore limited only by round-trip time.
- **Fix:** Count consecutive failures per connection in `h_session_setup`; clear `conn.challenge` on any failed AUTHENTICATE (forcing a fresh NEGOTIATE round) and drop the connection after a small fixed number of failures.
- **Justification:** (only if fix ADDS) The counter is a few lines of per-connection state, not a new subsystem, and it is the only mechanism that makes online guessing expensive; NTLMv2's offline-guess weakness is documented in smb2_auth.py as unfixable from this side, which makes the online path the one worth closing.
- **Benefit:** Failed logons stop being a free, repeatable oracle against a single static challenge.
- **Effort:** M · **Risk:** Med · **Confidence:** Med (READ)

### PYSMB2-06 — LOGOFF does not retire the SessionId; the next session on the connection silently reuses it
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:927-934 (`h_logoff` clears handles, trees and `authenticated` only), smb2_server/smb2_server.py:863 and smb2_server/smb2_server.py:915 (a session id is minted only `if conn.session_id == 0`)
- **Problem:** After LOGOFF, `conn.session_id` keeps the logged-off session's value, so the next successful SESSION_SETUP on the same connection is assigned the *same* SessionId as the session that was just ended. SessionIds are how clients key per-session state (including signing state); reissuing one invites exactly the old/new session confusion the id exists to prevent. The signing key's survival past LOGOFF is commented as deliberate for signing the LOGOFF reply itself — but nothing clears the id afterwards either.
- **Fix:** Set `conn.session_id = 0` at the end of `h_logoff` (the reply's header is built from the value the dispatcher already captured for this message — verify against `_dispatch_all`'s use of `conn.session_id or hdr.session_id` when making the change, and if the reply needs the old id, clear it in `_dispatch_all` after the LOGOFF reply is packed instead).
- **Benefit:** Each session gets the unique id the protocol promises; no state keyed by SessionId can alias across a logoff boundary.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ)

### PYSMB2-07 — TREE_DISCONNECT, ECHO and LOGOFF answer SUCCESS with no session at all
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:974-976 (`h_tree_disconnect`: pops a tree id, returns SUCCESS, no `_require_session`/`_tree`), smb2_server/smb2_server.py:1363-1364 (`h_echo`: returns SUCCESS unconditionally), smb2_server/smb2_server.py:927-934 (`h_logoff`)
- **Problem:** Every other stateful handler enforces a session via `_require_session`/`_tree`; these three do not. Executed proof: on a fresh, never-authenticated connection all three return STATUS_SUCCESS — including TREE_DISCONNECT for tree id 99, a tree that never existed. The impact is state-machine laxness rather than data exposure (nothing is served), but a server that reports success for operations on nonexistent state masks client bugs and makes its own session accounting (the `--session-summary` counters key off these commands) unreliable.
- **Fix:** Have `h_tree_disconnect` go through `_require_session` and report STATUS_NETWORK_NAME_DELETED for an unknown tree id, like `_tree` does; leave ECHO's behaviour a deliberate, commented choice if unauthenticated keepalive is actually wanted.
- **Benefit:** Success starts meaning the named thing existed and the caller was entitled to act on it.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB2-08 — The bcrypt CMAC self-test compares against the wrong constant: it is the CMAC *L* block, not a CMAC
- **Category:** 6
- **Locations:** smb2_crypto.py:227-232
- **Problem:** `_bcrypt_cmac`'s sanity check expects `cmac(zero key, b"")` to equal `66e94bd4…2e`. Executed on the /tmp copy: that constant is `AES-128(zero key, zero block)` — the *L* subkey block from RFC 4493 §2.3 — while the actual CMAC of the empty message under the zero key is `4387c14b…f9` (pure-Python and OpenSSL backends agree). So the first clause of the check is false for every correct bcrypt backend, forever, and the backend is accepted only because the condition is an `and` whose second clause compares against the pure implementation. The test as written can never pass on its own terms; it survives by accident of its fallback, and a reader trusting the constant would "fix" a working backend into rejection.
- **Fix:** Replace the constant with the real zero-key empty-message CMAC (`4387c14b46ef7e176dceefa862d72ff9`), or drop the hardcoded clause and keep only the pure-implementation comparison the OpenSSL path already uses (`smb2_crypto.py` `_openssl_cmac`) — one self-test mechanism, not two divergent ones.
- **Benefit:** The Windows signing path's only startup correctness gate tests what it claims to test.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED for both values; the bcrypt branch itself is Windows-only and was READ, not run)

### PYSMB2-09 — A malformed KEY_EXCH wrapped key silently falls back to the SessionBaseKey
- **Category:** 6
- **Locations:** smb2_spnego.py:330-341
- **Problem:** `exported_session_key` unwraps the client's session key only when NEGOTIATE_KEY_EXCH was negotiated *and* the wrapped key is exactly 16 bytes; otherwise it silently returns the SessionBaseKey. Executed proof: a Credentials with KEY_EXCH set and a 5-byte wrapped key returns the base key unchanged, with no error. If KEY_EXCH was negotiated, the client derived its signing key from the random key it sent — so server and client now hold different session keys and every signed request fails later as ACCESS_DENIED, far from the cause; if the client does not sign, the session proceeds on a key the client did not choose, with nothing logged.
- **Fix:** When KEY_EXCH is negotiated but the wrapped key is not 16 bytes, fail the session setup (raise AuthError / LOGON_FAILURE at the call site in `h_session_setup`, smb2_server.py:901) instead of substituting a different key.
- **Benefit:** A key-agreement failure fails at key agreement, with the right status, instead of surfacing as unexplained signature rejections.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB2-10 — A corrupt trailing segment in a compound request discards every reply, including successes already computed
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:429-434
- **Problem:** `_dispatch_all` accumulates replies in a local list and sends them only after the whole compound is walked. If `parse_header` fails on any segment after the first, the function simply `return`s — the accumulated replies are never sent. Executed proof: a compound of one valid ECHO request followed by 64 zero bytes produced **zero** bytes sent on the socket. The client, which did nothing wrong in its first request, sees a hang/timeout rather than its reply plus an error. (The same early return is also what a truncated final segment produces.)
- **Fix:** On a mid-compound parse failure, stop walking, append an error reply for the bad segment if a header boundary is known, and send whatever replies were accumulated instead of dropping them.
- **Benefit:** One bad segment costs one error reply, not the whole compound and a client-side timeout.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB2-11 — QUERY_DIRECTORY returns an entry larger than the client's OutputBufferLength
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:1258-1263
- **Problem:** The packing loop breaks on buffer exhaustion only `and entries` — i.e. the first entry is always emitted even when it alone exceeds the client's declared output length. Executed proof: with `out_len = 16`, the server returned STATUS_SUCCESS with OutputBufferLength = 96. A client that sized its buffer by its own request (libsmb2 and the PS2 browse drivers this server exists for work in fixed buffers) is handed more bytes than it agreed to receive.
- **Fix:** If the first entry does not fit, answer STATUS_INFO_LENGTH_MISMATCH (already defined and already used by `h_query_info`) instead of overrunning the declared length.
- **Benefit:** The server stays inside the buffer contract every other length in the protocol is checked against (`request_buffer`, MAX_READ/WRITE).
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB2-12 — QUERY_DIRECTORY's pattern filter is bypassed for "." and ".."
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:1204-1207 (`_listing_for` unconditionally keeps `names[:2]`)
- **Problem:** When a client asks for a filtered listing, the dot entries are kept regardless of the pattern. Executed proof: pattern `*.iso` returned entries `['.', '..', 'onlyfile.iso']`. Clients that trust the server-side filter (rather than re-filtering) show phantom entries for every filtered browse; a client computing "does this directory contain an .iso" from the raw listing gets a wrong answer shape. The dot entries themselves are deliberate (see the `_listing_for` docstring) — bypassing the client's filter for them is the defect, not their existence.
- **Fix:** Keep the dot entries only when the pattern matches them too (or when there is no filter), i.e. run all names through the same `fnmatch` test.
- **Benefit:** A filtered listing is filtered; unfiltered listings keep the dot entries some clients need.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB2-13 — A zero-length READ is answered STATUS_END_OF_FILE
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:1146-1153 (file branch), smb2_server/smb2_server.py:1137-1139 (pipe branch answers STATUS_PIPE_EMPTY for a zero-length read)
- **Problem:** `h_read` treats "no bytes came back" as EOF, but a request with Length = 0 legitimately returns no bytes at any offset. Executed proof: a zero-length READ on a handle positioned at offset 0 of a non-empty file raised STATUS_END_OF_FILE ("read past the end"). The comment at 1151-1152 justifies EOF for a zero-length *success*, but the conflation punishes a well-formed zero-length request with an error that tells the client the file ended. The pipe branch has the same shape: a zero-length pipe READ is PIPE_EMPTY rather than a successful empty read.
- **Fix:** Special-case `length == 0` before opening the file / reading the pipe and return STATUS_SUCCESS with an empty data buffer; keep END_OF_FILE for a non-zero read that hits the end.
- **Benefit:** Zero-length probes (a normal client pattern) stop looking like end-of-file.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB2-14 — NEGOTIATE silently accepts a dialect list shorter than DialectCount claims
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:748-757
- **Problem:** The dialect loop `break`s when the body runs out and negotiation proceeds with whatever prefix was present. Executed proof: a NEGOTIATE claiming DialectCount = 3 but carrying one dialect (2.1) was accepted with STATUS_SUCCESS and dialect 0x0210. A truncated or lying NEGOTIATE is malformed input; accepting a prefix of it means the negotiated dialect — and the `negotiate_claims` tuple stored for FSCTL validation at line 755 — are built from a message the server knows was incomplete, and the stored claims enshrine the truncated list as "what the client offered".
- **Fix:** If fewer than `dialect_count` dialects fit in the body, raise STATUS_INVALID_PARAMETER like every other short request in the file.
- **Benefit:** Malformed negotiation fails at negotiation, and the stored claims always describe a complete message.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB2-15 — FLUSH cannot fail: it is the only handle handler with no body-length check, and it swallows fsync errors
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:1102-1111 (contrast the length check every sibling makes before touching the FileId, e.g. `h_read` at smb2_server/smb2_server.py:1132-1133)
- **Problem:** Two ways FLUSH reports success without the work being known-good. (1) It slices `body[8:24]` and calls `handle_from` with no preceding length check; executed proof: an 8-byte body makes `h_flush` raise a bare `struct.error` ("unpack requires a buffer of 16 bytes"), which only the dispatcher's catch-all turns into STATUS_INVALID_PARAMETER — the handler's own contract (raise Smb2Error with a chosen status) is broken. (2) `fh.flush()` + `os.fsync()` failures are caught and discarded (`except OSError: pass`), so a client that issued FLUSH to learn its data is durable is told STATUS_SUCCESS even when the fsync failed.
- **Fix:** Add the same `len(body) < 24` check the other handlers open with, and let an fsync failure propagate as an OSError so `_dispatch` maps it to a real status (`_status_for_oserror`) instead of success.
- **Benefit:** FLUSH's success means the data was flushed; malformed FLUSHes fail with the handler's chosen status, not the catch-all's.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB2-16 — Receive framing has no size cap, and `_recv_exact` concatenates quadratically
- **Category:** 4
- **Locations:** smb2_wire.py:37-53 (`recv_msg`: 24-bit length trusted, up to 16,777,215 bytes), smb2_wire.py:27-34 (`_recv_exact`: `buf += chunk` in a loop)
- **Problem:** The server advertises MAX_TRANSACT / MAX_READ / MAX_WRITE of 1 MiB (`smb2_wire.py:204-206`) but the framing layer will buffer a message sixteen times that size from any unauthenticated peer — the length is read and honoured before any header, dialect or session check exists. Each connection thread can thus be made to allocate ~16 MiB on a peer's say-so, and `_recv_exact` builds that buffer by repeated `bytes` concatenation, which copies the accumulated prefix on every `recv` — O(n²) copying for large messages (a 1 MiB legitimate message arrives as many chunks).
- **Fix:** Cap the framed length in `recv_msg` (the advertised 1 MiB plus header/compound headroom is the natural bound; a peer exceeding it is not speaking this server's protocol) and accumulate `_recv_exact` into a list or `bytearray`, joining once.
- **Benefit:** Per-connection memory becomes bounded by a number the server itself advertised, and large legitimate transfers stop paying quadratic copy costs.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ)

### PYSMB2-17 — `send_msg` raises OverflowError for a reply over 16 MiB, killing the connection thread
- **Category:** 6
- **Locations:** smb2_wire.py:23-24 (`len(msg).to_bytes(3, "big")`), smb2_server/smb2_server.py:417-530 (`_dispatch_all` builds the compound reply `out` with no size bound), smb2_server/smb2_server.py:385-415 (`_serve_client` catches connection errors and OSError only)
- **Problem:** The 24-bit framing length overflows at 16,777,216 bytes. Executed proof: `send_msg` with a 16 MiB + 1 message raises `OverflowError: int too big to convert`. A single READ reply cannot reach that size (MAX_READ is 1 MiB), but a compound reply is the sum of its parts and is built with no bound, so a client chaining enough large READs in one compound makes the server compute a full reply and then die mid-send — and because OverflowError is not an OSError, it escapes `_serve_client`'s handlers entirely and kills the thread with a traceback instead of closing the connection cleanly.
- **Fix:** Check the length in `send_msg` and raise a defined error (or cap compound reply size in `_dispatch_all`); at minimum, make the failure an OSError subclass so the existing connection teardown handles it.
- **Benefit:** An oversized compound degrades to a dropped connection with a log line, not an unhandled thread death.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED for the OverflowError; thread death INFERRED from the `except` clauses read at 385-415)

### PYSMB2-18 — No resource limits: unbounded connection threads, no timeout on accepted sockets, unbounded handles and trees per connection
- **Category:** 4
- **Locations:** smb2_server/smb2_server.py:337-362 (`serve_forever` spawns a daemon thread per connection, no cap), smb2_server/smb2_server.py:385-404 (`_serve_client`: the accepted socket gets TCP_NODELAY at :390 and no timeout — the only `settimeout` in the server is on the *listening* socket at :342), smb2_server/smb2_server.py:245-251 (`add_handle` never refuses), smb2_server/smb2_server.py:949-972 (TREE_CONNECT allocates a tree per request, no cap)
- **Problem:** A peer can (a) open connections without limit, each costing a thread blocked forever in `recv_msg` even if it never sends a byte; (b) on one authenticated connection, CREATE handles and TREE_CONNECT trees without limit, growing `conn.handles` / `conn.trees` until the process runs out of memory or descriptors (handles hold no descriptor until first use, but each is an object plus, for directories, a listing snapshot). Nothing in the serving path — grep-verified — sets a client-socket timeout or counts connections, handles or trees. For a server whose deployment is "a PC on a LAN", one misbehaving or hostile client is a whole-process denial of service.
- **Fix:** Set a generous idle timeout on accepted sockets and a per-connection cap on handles/trees (refusing with the already-defined STATUS_INSUFFICIENT_SERVER_RESOURCES); a global connection cap can be a simple counter in `serve_forever`.
- **Justification:** (only if fix ADDS) These are three small checks at three existing allocation points, not a resource-management subsystem; each reuses a status the wire module already defines, and the alternative — documenting "one bad client kills the server" — leaves the stated LAN deployment one port-scan away from a hang.
- **Benefit:** Worst-case memory/thread usage becomes a function of configured caps, not of peer behaviour.
- **Effort:** M · **Risk:** Med · **Confidence:** Med (READ)

### PYSMB2-19 — Handles name paths, not files: lazy open-by-path serves whatever the path names at first use
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:1114-1127 (`_open_file` opens `h.path` on first READ/WRITE), smb2_server/smb2_server.py:1049-1053 (CREATE records the path and opens nothing), smb2_server/smb2_server.py:1069-1088 (CLOSE stats and deletes by path), smb2_server/smb2_server.py:1290-1293 (QUERY_INFO stats by path)
- **Problem:** A handle pins a pathname, not a file. Between CREATE and first use, anything that replaces the file at that path — another SMB client renaming over it, a local process, a sync tool — silently retargets the handle. Executed proof: a handle created on a file containing `ORIGINAL` returned `REPLACED!` from `h_read` after the file was swapped with `os.replace`, with no error and no new CREATE. The mirror cases follow from the same mechanism: a file deleted and recreated is read as the new file; QUERY_INFO and CLOSE's post-query attributes describe whatever is at the path *now*, not what was opened; delete-on-close can remove a file the handle's creator never opened. The `_open_file` docstring gives the reason for laziness (descriptor pressure from Explorer's attribute-only opens) — the defect is not laziness itself but that the CREATE-time `os.stat` (smb2_server.py:1042) is never compared against the file eventually opened.
- **Fix:** Keep the lazy open, but remember the CREATE-time identity (`st_dev`, `st_ino`) on the handle and verify it at first `_open_file`; on mismatch, fail with STATUS_FILE_CLOSED instead of serving the replacement. That keeps the descriptor saving and closes the retargeting.
- **Justification:** (only if fix ADDS) Two integers per handle and one comparison at the single lazy-open point — no new abstraction, and it converts a silent wrong-file serve into a clean error.
- **Benefit:** A handle means the file that was opened, across the whole multi-client lifetime of the share.
- **Effort:** M · **Risk:** Med · **Confidence:** High (EXECUTED)

### PYSMB2-20 — FileAccessInformation always reports full access (0x001F01FF)
- **Category:** 6
- **Locations:** smb2_wire.py:437-439
- **Problem:** `file_info` answers FILE_ACCESS_INFORMATION with the constant 0x001F01FF (FILE_ALL_ACCESS) for every file, in every share, through every handle — including on a read-only share and through a handle the same server would refuse a WRITE on (executed proof: queried with `read_only=True`, the mask returned is still 0x001F01FF). Clients use this class to decide what they may attempt; telling every client it has full access manufactures the very ACCESS_DENIED / MEDIA_WRITE_PROTECTED errors the access mask exists to prevent, and misleads any client that caches permissions from it.
- **Fix:** Derive the mask from the state the caller already passes in: when `read_only` is set, return the read/execute subset (the same 0x001200A9 shape `h_tree_connect` already uses for read-only shares at smb2_server.py:969) instead of full access.
- **Benefit:** The reported access agrees with the access the server will actually enforce.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB2-21 — Rename ignores the RootDirectory field, so a directory-relative rename lands at the share root
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:1340-1357
- **Problem:** FileRenameInformation carries a RootDirectory handle (payload bytes 8–15): when it is non-zero, the FileName is relative to that directory. The handler reads only ReplaceIfExists (byte 0) and FileNameLength (offset 16), never looks at bytes 8–15, and resolves the name against the share root (`h.share.resolve(target)`). A client performing a rename relative to an open directory handle therefore moves its file to the share root instead — and with ReplaceIfExists set, can overwrite an unrelated same-named file at the root. The raw target string is also stored verbatim as `h.rel` (line 1356), so a later QUERY_INFO reports the un-normalised name.
- **Fix:** If the RootDirectory field is non-zero, either resolve the name relative to that handle's directory (the handles table is right there) or refuse with STATUS_NOT_SUPPORTED; do not silently reinterpret the name against a different base. Store the share-relative result of the resolution as `h.rel`, not the raw client string.
- **Benefit:** A rename goes where the client addressed it, or fails honestly — never to a different directory by default.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ)

### PYSMB2-22 — The account password is taken on the command line, where any local user can read it
- **Category:** 6
- **Locations:** smb2_server/smb2_server.py:1741-1742 (`--user NAME:PASSWORD`), smb2_server/smb2_server.py:1708-1724 (`build_authenticator` splits the spec), smb2_server/smb2_server.py:44 (the module docstring's own example shows `--user ripto:secret`)
- **Problem:** A password in argv is visible in the process list (`ps`, Task Manager's command-line column), in shell history, and in any launcher log that records how the server was started. The server is normally started by a GUI launcher on a shared family PC — exactly the setting where other local users/processes can see a process command line. This is the one place credentials exist outside the NTLM exchange, and it is the least protected.
- **Fix:** Accept users from a file (e.g. `--users-file` with `NAME:PASSWORD` lines, read once at startup) in addition to `--user`, and steer the launcher/docstring example to it; keep `--user` working for compatibility.
- **Justification:** (only if fix ADDS) One additional way to read the same `user_specs` list `build_authenticator` already consumes — no new config format or subsystem — and it removes the password from the one place it is broadcast to every local process.
- **Benefit:** The share password stops being world-readable on the host for the whole life of the server process.
- **Effort:** M · **Risk:** Low · **Confidence:** Med (READ)

### PYSMB2-23 — Dead code with zero callers anywhere in the repo
- **Category:** 1
- **Locations:** smb2_crypto.py:186-189 (`native_cmac_name`), smb2_wire.py:120 (`STATUS_PENDING`), smb2_wire.py:181 (`FILE_SUPERSEDED`), smb2_wire.py:200 (`GLOBAL_CAP_DFS`), smb2_srvsvc.py:28 (`PTYPE_BIND_NAK`)
- **Problem:** A repo-wide grep census (production code and tests) finds exactly one reference to each of these: its own definition. `native_cmac_name` even carries a "For logs" docstring, but no log call uses it — the one place that would want it (startup, to say which CMAC backend is in force) never calls it. The four constants are protocol values no code path emits or compares. Each is small; together they are the kind of inventory that makes a reader check whether a status or packet type is handled when it is not. (Checked and *not* dead, for contrast: `Share.relative`, `Share.resolve(must_exist=…)`, `blob_timestamp` and `lmv2_response` have no production callers either, but tests exercise them, so they are test surface, not dead code.)
- **Fix:** Delete the five definitions. If the CMAC backend name is worth having, call it in the startup banner instead of keeping it for a caller that does not exist.
- **Benefit:** Five fewer symbols a reader must chase to discover nothing uses them.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — grep census, counted not estimated)

### PYSMB2-24 — The session-id minting line is duplicated inside `h_session_setup`
- **Category:** 2
- **Locations:** smb2_server/smb2_server.py:863, smb2_server/smb2_server.py:915
- **Problem:** `conn.session_id = int.from_bytes(os.urandom(8), "little") or 1`, guarded by the same `if conn.session_id == 0`, appears verbatim in both the NTLM-NEGOTIATE branch and the AUTHENTICATE branch of the same function. It is the kind of line that gets fixed in one copy (e.g. as part of PYSMB2-06's logoff change) and not the other.
- **Fix:** Mint the id in one place — e.g. a tiny `Connection.ensure_session_id()` next to `add_handle`, or a single check after the branch dispatch in `h_session_setup` before the reply is built.
- **Benefit:** One definition of how a session gets its id; the two branches cannot drift.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYSMB2-25 — `_local_ipv4_addresses` runs three enumeration mechanisms to print one cosmetic warning line
- **Category:** 3
- **Locations:** smb2_server/smb2_server.py:76-128 (getaddrinfo pass, then a POSIX `fcntl` SIOCGIFADDR per-interface ioctl pass, then a UDP connect-to-TEST-NET probe), consumed at smb2_server/smb2_server.py:131-147
- **Problem:** ~53 lines and three fallback strategies exist solely to fill in "Reachable on: …" in the open-share warning. The code itself concedes the list is best-effort and that "the --bind advice is the load-bearing half" — the addresses change nothing the operator does; the actionable content is the second line, which needs no enumeration at all. The ioctl pass is also the only `fcntl` use in the server, with its own platform guards to maintain.
- **Fix:** Keep the getaddrinfo pass and the --bind advice; delete the ioctl enumeration and the connect probe. If the list comes back empty, the warning loses nothing it could act on.
- **Benefit:** Removes a platform-specific syscall path and a network-stack probe from startup, for a banner line.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ)

### PYSMB2-26 — No native CMAC backend is probed on macOS, so signed SMB3 there runs on the pure-Python AES
- **Category:** 5
- **Locations:** smb2_crypto.py:173-184 (`_native_cmac` probes win32 → bcrypt, linux → OpenSSL, nothing else), smb2_crypto.py:15-22 (module docstring: pure-Python AES is "under a megabyte per second, and an SMB 3.x signature covers every byte of every READ reply")
- **Problem:** On macOS the backend probe returns None by construction (the comment explains loading Apple's libcrypto aborts the process), so every signed SMB3 message is CMAC'd by the pure-Python AES at the throughput the docstring itself calls a crawl. Windows and Linux get OS crypto; macOS silently gets a ~100× slower signing path with no startup note saying so.
- **Fix:** Either probe a macOS-native route that does not load libcrypto (e.g. CommonCrypto via ctypes), or state the limitation where the operator will see it — the startup banner that already reports dialect and shares — so a slow macOS SMB3 server is a known property, not a mystery.
- **Justification:** (only if fix ADDS) The cost is quantified in the module's own docstring and falls on the server's stated purpose (copying games through Explorer); the banner-only variant adds one line and no mechanism at all.
- **Benefit:** Signed SMB3 on macOS is either fast or honestly labelled slow at startup.
- **Effort:** M · **Risk:** Low · **Confidence:** Med (READ)

### PYSMB2-27 — `check_component("")` raises IndexError instead of PathError
- **Category:** 6
- **Locations:** smb2_paths.py:70-102 (the crash is the `part[-1]` test at smb2_paths.py:97)
- **Problem:** The path guard's component check documents "Raises PathError" as its contract, but for an empty component it falls through every test and dies at `part[-1]` with `IndexError: string index out of range` — executed proof on the /tmp copy. Inside this scope the crash is unreachable (`Share.resolve` skips empty components at smb2_paths.py:148-150 before calling it), but the function exists precisely to be the reusable guard — its docstring says it is separated out so other servers (the NFS server's READDIR path) can call it per directory entry — and a guard that raises the wrong exception type defeats the caller's `except PathError` handling wherever it is reused without resolve's pre-filter.
- **Fix:** Reject an empty component at the top of `check_component` with the same PathError the other refusals use.
- **Benefit:** The guard's contract holds for every input, not just the inputs its current in-scope caller happens to pre-filter.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB2-28 — The srvsvc pipe does not reassemble a PDU split across WRITEs (or across RPC fragments)
- **Category:** 8
- **Locations:** smb2_srvsvc.py:134-137 (`SrvsvcPipe.write` hands each WRITE straight to `transact`), smb2_srvsvc.py:144-165 (`transact` requires one complete PDU per call: `frag_len > len(data)` is an error, and a REQUEST without FIRST+LAST fragment flags gets a fault)
- **Problem:** SMB pipe semantics let a client write a request in several WRITEs, and DCE/RPC lets it fragment one request across PDUs; this pipe implements neither — each WRITE must be a whole PDU, and each PDU must be a whole request. The comment at the fragment check frames a fragmented request as "a client this server does not understand", which is true of the clients tested (libsmb2, Explorer, smbclient all send small single writes), but it makes the one pipe the server has a partial implementation of its own transport: a conforming client that splits a bind or a request — legal on both layers — gets INVALID_PARAMETER / a fault instead of a share list.
- **Fix:** Buffer incoming bytes in `write` until a complete PDU (per its own frag_len) is present before calling `transact`; that covers the WRITE-split case with a few lines. Leave REQUEST-fragment reassembly unimplemented, but say so at the fault site as a known limit rather than a client error.
- **Benefit:** The pipe accepts the write patterns its transport permits, and its one real limit is documented where it triggers.
- **Effort:** M · **Risk:** Low · **Confidence:** Med (READ)

---

## Files read

All seven in-scope files, read in full (line counts by `wc -l`):

- `smb2_server/smb2_server.py` — 1,848 lines
- `smb2_server/smb2_wire.py` — 512 lines
- `smb2_server/smb2_crypto.py` — 431 lines
- `smb2_server/smb2_spnego.py` — 360 lines
- `smb2_server/smb2_auth.py` — 324 lines
- `smb2_server/smb2_srvsvc.py` — 289 lines
- `smb2_server/smb2_paths.py` — 193 lines

Also read (repo house rules, not audit scope): `AGENTS.md` at the repo root. Caller/test usage of in-scope symbols was checked by repo-wide grep (tests, `nfs4_server/`, `conformance/`) solely to avoid false dead-code claims; those files were not audited.

## Files not read (in scope)

- None. All seven in-scope source files were read completely.
- `smb2_server/__pycache__/*.pyc` (7 compiled caches) were not read; they are not source, are not tracked in git (`git ls-files smb2_server/` lists only the seven `.py` files), and no finding relies on them.
