# PS2-Servers — Blind Redo Audit: Python SMB1 server + UDPFS Core

- **Clone / pin:** `~/workspace/audit-clones-2026-11-13/PS2-Servers` @ `c5f021c4d38698860f56b03498adc261dbb8d8dd` (read-only; executions in `/tmp` copies only)
- **Scope note (filename):** the task named `smbv1_server/smbv1_server.py`. No file of that name exists at this pin (verified by `find` over the tree). The only SMB1 server file is `smbv1_server/smbserver_opl.py`, at exactly the task's stated 1,862 lines, and it is what scope (a) was audited against. Scope (b) is `udpfs_server/ps2servers_core.py` (690 lines).
- **Secrets:** no hardcoded secret-like value was found in either file. Credentials enter only via `--user NAME:PASSWORD` on the command line; no value is reproduced anywhere in this section.
- **Checked, no finding (for the record):** SMB1 read-only enforcement is present on every write path — `h_write_andx`, the create/truncate dispositions in `h_nt_create_andx`, and `h_create_directory` all refuse when `server.read_only` is set, and compressed images refuse create/truncate/write. `Share.resolve` containment (realpath + `commonpath`) is sound, including the sibling-prefix case. The SMB1 dispatch does gate non-pre-logon commands behind `_logon_required` when users are configured. No SMB1 delete/rename/set-info command is implemented, and unimplemented commands honestly return `STATUS_NOT_IMPLEMENTED`.

---

## SMB1 server — `smbv1_server/smbserver_opl.py`

### PYSMB1-01 — The `--smb-version 2/3` SMB2 handlers are stubs that claim success without doing any work
- **Category:** 8
- **Locations:** smbv1_server/smbserver_opl.py:537-637 (all `h2_*` handlers + `SMB2_HANDLERS`), smbv1_server/smbserver_opl.py:1435-1458 (SMB2 dispatch in `serve_conn`), smbv1_server/smbserver_opl.py:1724-1729 (the `main()` warning that admits this)
- **Problem:** Every SMB2 handler ignores the request body and fabricates a successful reply: `h2_session_setup` always succeeds as guest (no credential check, and the SMB2 dispatch branch never applies the SMB1 `_logon_required` gate), `h2_tree_connect` succeeds for any share name without consulting `server.shares`, `h2_create` returns one constant FileId and `FILE_OPENED` for any path, existing or not, `h2_read` always returns zero bytes with `STATUS_SUCCESS`, and `h2_write` returns `STATUS_SUCCESS` with a written count of 0 and writes nothing — including on a read-only server, where a real write would be refused (executed: `h2_write` on a `read_only=True` server returned status 0). `h2_negotiate` also embeds a fixed sequential-bytes server GUID. The command map is additionally misaligned with SMB2: 0x0012 (OPLOCK_BREAK) is mapped to the echo handler, while the real ECHO command (0x000D) and QUERY_DIRECTORY (0x000A) fall through to NOT_IMPLEMENTED, so the share can never be listed. `main()` prints an "INCOMPLETE" warning, but the flag remains a documented `--help` choice and any client that connects sees success-shaped replies and an empty share rather than an error.
- **Fix:** Either delete the SMB2 stub, the `SMB2_HANDLERS` dispatch branch, and the `--smb-version 2/3` choices (the repo already has a real SMB2 server in `smb2_server/`), or refuse at startup when `--smb-version != 1`. Do not keep handlers that return success for work not done.
- **Benefit:** Removes ~130 lines of fake protocol surface, an auth-bypassing dispatch branch, and a silent-data-loss trap (a client told a write succeeded when nothing was written).
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED — `h2_write`/`h2_read`/`h2_create` return values captured; dispatch and map read in full)

### PYSMB1-02 — Short or malformed parameter blocks raise `struct.error` out of the handlers and kill the connection, with no SMB error reply
- **Category:** 6
- **Locations:** smbv1_server/smbserver_opl.py:957-985 (`h_read_andx`), smbv1_server/smbserver_opl.py:1012-1035 (`h_write_andx`), smbv1_server/smbserver_opl.py:1114-1126 (`_trans2_parse`), smbv1_server/smbserver_opl.py:1258-1262 (`h_trans2_find_next2`), smbv1_server/smbserver_opl.py:1421-1510 (`serve_conn`: dispatch inside a `try` whose only handler is `except (ConnectionError, OSError)`)
- **Problem:** Several handlers unpack fixed offsets from `r.params` / `t_params` without checking the client-supplied WordCount first — unlike `h_session_setup` (wordcount guard) and `h_nt_create_andx` (`len(r.params) < 39` guard), which show the file already knows the pattern. `Req` itself silently truncates `params` when the declared WordCount overruns the message, so a short block reaches the handlers intact as a short buffer. Executed: `h_read_andx` with a 2-byte params block raises `struct.error`, and `_trans2_parse` with a 2-byte params block raises `struct.error`. `struct.error` is not an `OSError`, so it escapes `serve_conn`'s exception handler: the thread dies with a traceback, the session is dropped mid-stream, and the client gets no error response. One malformed packet from any client kills its own session (the server process survives, since each connection is a thread).
- **Fix:** Validate minimum params length once per handler that needs it (the guard style already used in `h_nt_create_andx`), returning `STATUS_ACCESS_DENIED`/an error status instead of raising; or catch `struct.error` alongside `OSError` in `serve_conn` and fail the request, not the connection. The per-handler guard is the smaller, more local change.
- **Benefit:** A buggy or hostile client gets an SMB error and keeps (or cleanly loses) its session by protocol, instead of an unexplained disconnect with a server-side traceback.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED for both cited handlers; the escape path is READ)

### PYSMB1-03 — A non-ASCII configured password makes every login attempt raise `TypeError` in `hmac.compare_digest`
- **Category:** 6
- **Locations:** smbv1_server/smbserver_opl.py:719-750 (`h_session_setup`, `compare_digest` at line 746), smbv1_server/smbserver_opl.py:1731-1747 (`--user` parsing in `main()`, which accepts any password string)
- **Problem:** The incoming password is decoded with `"ascii", "ignore"`, so it is always pure ASCII. The configured password is taken verbatim from `--user NAME:PASSWORD`, with no ASCII restriction. `hmac.compare_digest` on two `str` operands raises `TypeError` when either contains non-ASCII characters (executed: `hmac.compare_digest("abc", "päss")` → `TypeError: comparing strings with non-ASCII characters is not supported`). So a server configured with, e.g., a password containing an accented character does not get "wrong password → LOGON_FAILURE"; it gets an uncaught `TypeError` out of `h_session_setup`, which (per PYSMB1-02's dispatch) kills the connection thread on every single login attempt, with no hint that the configuration is the cause.
- **Fix:** Compare on bytes: encode both sides (e.g. UTF-8) before `compare_digest`, so any configured password either matches or fails as a normal logon failure.
- **Benefit:** Credential checking can never crash the session handler; misconfigurations degrade to ordinary logon failures.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED — the `TypeError` is reproduced; the asymmetry between the ASCII-forced wire password and the unrestricted configured password is READ)

### PYSMB1-04 — `CHECK_DIRECTORY` never succeeds for a spec-formed request because it does not strip the `0x04` BufferFormat byte its sibling handler strips
- **Category:** 6
- **Locations:** smbv1_server/smbserver_opl.py:1098-1110 (`h_check_directory`), smbv1_server/smbserver_opl.py:1070-1096 (`h_create_directory`, which documents and strips the same prefix)
- **Problem:** `h_create_directory`'s own comment states the command "carries BufferFormat=0x04 before the NUL-terminated share-relative directory name", and it strips that byte (`r.data[1:] if r.data[:1] == b"\x04"`); the project's write-semantics tests drive it with `b"\x04CFG\x00"`. `CHECK_DIRECTORY` has the same data format, but `h_check_directory` decodes the name starting at byte 0, so the resolved path begins with a literal `\x04` component and can never be a directory. Executed against an existing `DVD/` directory: a plain name returns `STATUS_SUCCESS`, the `0x04`-prefixed (spec-formed) name returns `STATUS_OBJECT_NAME_NOT_FOUND` (0xC0000034).
- **Fix:** Strip a leading `0x04` in `h_check_directory` exactly as `h_create_directory` does.
- **Benefit:** Directory-existence checks answer for the directory the client actually named, instead of always reporting "not found" to any client that follows the same format the create path already handles.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED — both request forms driven against the handler)

### PYSMB1-05 — FIND_FIRST2 / FIND_NEXT2 return exactly one directory entry per round trip
- **Category:** 5
- **Locations:** smbv1_server/smbserver_opl.py:1200-1256 (`h_trans2_find_first2`: `SearchCount` packed as 1, one `_dir_entry_104` record), smbv1_server/smbserver_opl.py:1258-1275 (`h_trans2_find_next2`: same, one record per call)
- **Problem:** A directory listing costs one SMB request/response per file, plus one per-entry `os.stat` inside `_dir_entry_104`. A games folder with a few hundred entries — the normal case for this server — needs hundreds of sequential round trips over a PS2 network link to enumerate, where the protocol and the negotiated 64 KiB buffer allow many level-0x104 records per response. The full entry list is already materialised in `_list_dir` and stored in `conn.searches`; only the reply construction limits it to one.
- **Fix:** Pack as many entries as fit in the response buffer per FIND_FIRST2/FIND_NEXT2 reply, set `SearchCount` and `EndOfSearch` accordingly, and advance the stored cursor by the number actually sent.
- **Benefit:** Directory listing time drops from O(entries) round trips to O(entries ÷ entries-per-buffer), the single most common operation this server performs.
- **Effort:** M · **Risk:** Med (reply layout is hardware-validated; wants a console re-test) · **Confidence:** High (READ — both handlers pack a count of 1 and a single record)

### PYSMB1-06 — No bound tying accepted message size to the advertised buffer, no connection idle timeout, and unbounded thread-per-connection growth
- **Category:** 4
- **Locations:** smbv1_server/smbserver_opl.py:183-207 (`_recv_exact` / `recv_msg`: 24-bit NetBIOS length accepted as-is), smbv1_server/smbserver_opl.py:676-690 (`h_negotiate` advertises MaxBufferSize 65535), smbv1_server/smbserver_opl.py:1843-1862 (accept loop spawning an unbounded daemon thread per connection; accepted sockets are blocking with no timeout)
- **Problem:** `recv_msg` trusts the 24-bit length field, so a single "message" can make the server buffer up to ~16.7 MiB — roughly 256× the 64 KiB maximum buffer size the server itself negotiates — before any header validation happens. A connection that opens and then sends nothing (or trickles) holds its thread and file descriptor forever: there is no socket timeout or idle expiry on connection sockets, and the accept loop imposes no cap on concurrent connection threads. A handful of idle or slow clients therefore pins unbounded threads and up to ~16.7 MiB of buffer each, on a server whose legitimate traffic is ≤64 KiB messages from one console.
- **Fix:** Reject (drop the connection) when the NetBIOS length exceeds a bound tied to the negotiated maximum (e.g. 128 KiB of slack over MaxBufferSize), and give accepted sockets an idle timeout. No new configuration is needed; both can be constants.
- **Benefit:** Per-connection memory becomes bounded and proportional to real protocol traffic, and idle/dead connections release their thread and descriptors on their own.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — length handling, advertised maximum, and accept loop all read in full; no timeout or cap exists anywhere in the file)

### PYSMB1-07 — NEGOTIATE returns success with DialectIndex 0 when the client never offered NT LM 0.12
- **Category:** 6
- **Locations:** smbv1_server/smbserver_opl.py:640-695 (`h_negotiate`: `except ValueError: idx = 0`, then an unconditional success response)
- **Problem:** If the dialect list does not contain "NT LM 0.12" — including when it is empty or contains only unrelated dialects — the handler does not fail negotiation; it claims dialect index 0 (whatever the client happened to list first) and returns the full NT LM 0.12 response with `STATUS_SUCCESS`. Executed with a dialect list of only "PC NETWORK PROGRAM 1.0": the reply is success with DialectIndex 0. A client that cannot actually speak NT LM 0.12 is told negotiation succeeded and proceeds into a session the server cannot honour, failing later and less diagnosably.
- **Fix:** Return an error status (or a dialect index of 0xFFFF, "no dialect chosen") when "NT LM 0.12" is absent, instead of defaulting `idx` to 0.
- **Benefit:** Incompatible clients fail at negotiation, where the failure belongs, instead of mid-session.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMB1-08 — `SMB_COM_TRANSACTION` ignores the requested RAP function and always answers with a successful NetShareEnum
- **Category:** 8
- **Locations:** smbv1_server/smbserver_opl.py:1331-1362 (`h_transaction`: request setup/function word never read)
- **Problem:** The handler is documented as "RAP NetShareEnum — only used when OPL's Share field is empty", but it never inspects the transaction's function code or name. Any `SMB_COM_TRANSACTION` request — any RAP function, any pipe — receives the share-enumeration reply with `STATUS_SUCCESS`. A client asking for anything else is silently given share data in a format it did not request, instead of a not-implemented/unsupported answer.
- **Fix:** Check the RAP function code in the request and return `STATUS_NOT_IMPLEMENTED` for anything other than NetShareEnum.
- **Benefit:** Unsupported requests fail honestly; the one supported function keeps working unchanged.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — the request is never parsed in the handler)

### PYSMB1-09 — QUERY_INFORMATION_DISK reports invented disk geometry and free space
- **Category:** 6
- **Locations:** smbv1_server/smbserver_opl.py:1064-1068 (`h_query_disk`: hard-coded `0xFFFF` total units and `0xFFFF` free units, with the comment "smbman just needs non-zero free space")
- **Problem:** Total and free space are constants (~2 GiB at the packed 64×512 scale) regardless of the actual volume. Any client that consults free space before creating or extending a file (a VMC image is the obvious case on this server) is told there is room even when the disk is full or nearly full, and only learns otherwise from a later write failure — or, on a large volume, is told the share is far smaller than it is.
- **Fix:** Fill the fields from `shutil.disk_usage` on the share root of the request's tree, scaled/clamped into the u16 fields as the current packing requires.
- **Benefit:** The one disk query the server answers stops being fabricated; clients making space decisions get real numbers.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYSMB1-10 — The Transaction response envelope is built twice, once for TRANS2 and once open-coded in the RAP handler
- **Category:** 2
- **Locations:** smbv1_server/smbserver_opl.py:1128-1154 (`_build_trans2_reply`), smbv1_server/smbserver_opl.py:1344-1362 (the same 10-word header, 4-byte alignment padding, and offset arithmetic repeated in `h_transaction`)
- **Problem:** The fixed 10-word transaction response header, the `base = 32 + 1 + 20 + 2` computation, and both alignment pads are duplicated almost line-for-line. Any correction to the envelope layout (offsets, alignment) has to be made in two places and can silently drift — in a file whose comments repeatedly stress that exact response sizes are what keep OPL from retrying forever.
- **Fix:** Have `h_transaction` call the existing `_build_trans2_reply`-shaped builder (generalised only by the params/data it already takes), deleting the open-coded copy.
- **Benefit:** One envelope implementation; ~18 duplicated lines removed and one place to fix wire-layout bugs.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — both constructions read in full)

### PYSMB1-11 — Compressed-image stem/extension matching is implemented twice, with subtly different rules
- **Category:** 2
- **Locations:** smbv1_server/smbserver_opl.py:303-336 (`Share.compressed_source`: listdir, stem match, first extension in `exts` order, re-resolve + containment check), smbv1_server/smbserver_opl.py:1156-1198 (`_list_dir`: listdir, stem match, best extension in `exts` order, real-`.iso`-wins rule)
- **Problem:** "Which `.chd`/`.cso` stands in for a given `.iso`, and in what preference order" is decided in two separate scans. They already differ in their surrounding rules (one re-checks containment of the real path, the other checks whether a real `.iso` name is taken), so a future format or ordering change made in one place leaves listing and opening disagreeing about which image a name refers to — the listing would advertise one file and the open would serve another, or none.
- **Fix:** Extract the shared scan (folder listing → stem → best extension in order) into one helper on `Share` that both call sites use, keeping each caller's own extra check (containment / real-iso-wins) at the call site.
- **Benefit:** Listing and opening can never disagree about image selection; the preference order lives in one place.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — both implementations read in full)

### PYSMB1-12 — Three copy-pasted ID allocators, and FID wrap-around silently overwrites a live open file, leaking its handle
- **Category:** 2
- **Locations:** smbv1_server/smbserver_opl.py:489-505 (`alloc_fid` / `alloc_tid` / `alloc_sid`, three identical two-line bodies; `cleanup` closes only what remains in `conn.files`)
- **Problem:** The three allocators are the same increment-and-wrap logic with different floors, triplicated. Worse, none of them checks for collision with an ID still in use: `alloc_fid` cycles through 0x1000–0xFFFF, and on wrap the caller does `conn.files[fid] = of`, overwriting the entry for a file that may still be open — the overwritten `OpenFile` is no longer in the dict, so `cleanup()` never closes it and its OS handle leaks for the life of the connection. The same unchecked pattern applies to tree and search IDs and their dicts.
- **Fix:** One small allocator helper parameterised by floor, used by all three; and on FID allocation, skip (or close) any ID still present in `conn.files` before reissuing it.
- **Benefit:** Removes the triplication and closes a slow handle leak on very long sessions (the leak needs ~61k opens without closes on one connection, so it is a correctness fix, not an urgent one).
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ for the allocator/dict mechanics; INFERRED for the wrap-around leak, which follows directly from them but was not executed through a full wrap)

### PYSMB1-13 — WRITE_ANDX re-opens the file from disk on every write, and the open file's cached size is never updated by writes
- **Category:** 5
- **Locations:** smbv1_server/smbserver_opl.py:1012-1045 (`h_write_andx`: `with open(of.path, "r+b") as w:` per request), smbv1_server/smbserver_opl.py:360-385 (`OpenFile.__init__` snapshots `self.size` once at open)
- **Problem:** Every WRITE_ANDX pays an open+close of the target path instead of writing through state already held for the FID, on the path VMC/config saves exercise repeatedly. Separately, because writes bypass the `OpenFile`, its `size` stays at whatever it was when the file was opened: after a write extends the file, `record_read`'s expected-length computation (which uses `of.size`) misjudges subsequent reads of the grown region, producing wrong short-read diagnostics for exactly the read-back-after-write pattern this server was already bitten by once.
- **Fix:** Keep a writable handle (or a lazily opened one) on `OpenFile` for files opened on a writable share and write through it, updating `of.size` to at least `offset + len(payload)` after each write.
- **Benefit:** Fewer syscalls per write on the save path, and read diagnostics that reflect the file as written.
- **Effort:** M · **Risk:** Med (touches the deliberately unbuffered read design; the read handle must stay unbuffered or be flushed coherently) · **Confidence:** High (READ — per-write open and one-time size snapshot are both explicit in the code)

### PYSMB1-14 — `Share.resolve`'s comment promises a share-prefix strip the code does not perform
- **Category:** 7
- **Locations:** smbv1_server/smbserver_opl.py:280-301 (`resolve`: comment at line 297, "# Drop a leading \"share/\" if the client included it", immediately above code that does no such thing)
- **Problem:** The comment describes a normalisation step that does not exist: a client path of the form `\games\DVD\file.iso` on share `games` resolves to `<root>/games/DVD/file.iso` and misses, while the comment leads a reader to believe it resolves to `<root>/DVD/file.iso`. Either the behaviour was removed and the comment survived, or the comment describes intent that was never implemented — in a security-sensitive path function whose other comments are detailed and accurate, a false one is a trap for the next editor.
- **Fix:** Delete the stale comment, or implement the strip if a real client needs it (that is a behaviour change and wants a console test; deleting the comment does not).
- **Benefit:** The path-boundary function documents only what it actually does.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — comment and the full body of `resolve` read together)

---

## UDPFS Core — `udpfs_server/ps2servers_core.py`

What this module is (grep-verified): not a shared library in the import sense — nothing in the tree does `import ps2servers_core` at runtime except the test suite. It is the shipped UDPFS **entry point**: `launcher/servers.py` (registry entry for `udpfs`) points at this file, and it subclasses `udpfs_server.UdpfsServer` as `AutoUdpfsServer`, overriding six methods to replace the base server's global Modulo switch with per-session Standard/Modulo negotiation (`classify_profile` + discovery/DATA handoff state in `_handle_discovery`/`_handle_data`). That core idea earns its keep — it is the only place the auto-negotiation exists, and the launcher runs it, not the base file. The findings below are about what accreted around it.

### PYSMB1-15 — `classify_profile` contains an unreachable third branch that restates the first
- **Category:** 1
- **Locations:** udpfs_server/ps2servers_core.py:71-88 (`classify_profile`)
- **Problem:** The third test, `if first_data_sequence == modulo_sequence: return PROFILE_MODULO`, can only be reached when the first test (same condition, plus a side condition) and the second both failed. Brute-forced over the entire input space (all 4096×4096 discovery/first-data sequence pairs, executed): zero inputs reach the third branch with its condition true — when `first == (discovery+1) & 0xFFF` and the first branch's side condition fails, both sequences are 0, which would require the modulo sequence to be 0 rather than 1. The branch is dead, and its presence makes a 12-bit negotiation rule that hardware depends on look like it has a case it does not have.
- **Fix:** Delete the third branch; the first two tests plus the fall-through already cover the space (verified exhaustively).
- **Benefit:** The profile rule becomes exactly as large as the behaviour it implements; no reader has to re-derive which case the dead branch was meant to catch.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED — exhaustive over the full 2²⁴ input space)

### PYSMB1-16 — Two names are imported from `udpfs_server` and never used
- **Category:** 1
- **Locations:** udpfs_server/ps2servers_core.py:18-48 (import list; `MAX_SEND_RETRIES` at line 24, `_widen_send_buffer` at line 46)
- **Problem:** A word-count census of the file (scripted, not estimated) shows each of `MAX_SEND_RETRIES` and `_widen_send_buffer` occurs exactly once in `ps2servers_core.py` — on its own import line. Every other name in the 31-name import list occurs at least twice. Dead imports in a from-import of private helpers (`_widen_send_buffer` is underscore-private to the base module) misstate what Core actually depends on, in a file whose packaging history (noted in `build/build.py` and the packaging tests) already includes a breakage caused by this module's import surface being misunderstood.
- **Fix:** Remove the two names from the import list.
- **Benefit:** The dependency surface of the shipped entry point is exactly what it uses.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED — scripted occurrence census over the file)

### PYSMB1-17 — `main()`'s Modulo fast path bypasses `AutoUdpfsServer`, leaving Auto's own Modulo handling unreachable on the shipped path
- **Category:** 1
- **Locations:** udpfs_server/ps2servers_core.py:625-652 (`main()`: `protocol_mode == modulo` constructs a plain `UdpfsServer` and returns), udpfs_server/ps2servers_core.py:105-120 (`AutoUdpfsServer.__init__` Modulo kwargs handling), udpfs_server/ps2servers_core.py:305-335 (`_handle_discovery`'s dedicated Modulo branch, including its duplicate-discovery suppression via `sess._last_disc`, an attribute `_init_compat` never initialises)
- **Problem:** There are two complete Modulo implementations: the base server's (`modulo_compat=True`, used by `main()` whenever Modulo is forced — which is also what the launcher's "Enforce Modulo mode" checkbox produces) and Auto's (its `__init__` forcing plus the `_handle_discovery` Modulo branch with its own duplicate-probe logic). Because `main()` never constructs `AutoUdpfsServer` with `protocol_mode="modulo"`, the second implementation cannot execute on any shipped launch path — only a programmatic construction or a test can reach it. It still has to be read, reviewed, and kept consistent with the override contract the tests pin, and its uninitialised `_last_disc` attribute is a latent trap for anyone who does reach it.
- **Fix:** Pick one path: either route Modulo through `AutoUdpfsServer` like every other mode (deleting the `main()` special case) or delete Auto's Modulo branch and `__init__` forcing and let the base server own Modulo outright. The second is the smaller deletion.
- **Benefit:** One Modulo implementation to validate against hardware instead of two that can drift; the override surface the contract test pins shrinks.
- **Effort:** M · **Risk:** Med (Modulo behaviour is hardware-sensitive; whichever path survives needs a console check) · **Confidence:** High (READ — construction paths in `main()`, `__init__`, and the discovery branch all read; no other production construction of `AutoUdpfsServer` exists in the tree, grep-verified)

### PYSMB1-18 — Core's `run()` drops the base server's per-datagram `OSError` containment, so one failed INFORM send can kill the whole server loop
- **Category:** 6
- **Locations:** udpfs_server/ps2servers_core.py:477-521 (`run()`: handler calls sit outside any `OSError` guard; the loop's only exception handler is `except KeyboardInterrupt`), udpfs_server/ps2servers_core.py:195-220 (`_send_specific` deliberately re-raises `OSError` from INFORM sends), udpfs_server/udpfs_server.py:1048-1112 (base `run()`, where dispatch happens inside the recv `try` and `OSError` is caught per datagram)
- **Problem:** In the base server's loop, `_handle_discovery` is called inside the same `try` that guards `recvfrom`, so a send failure during discovery handling is swallowed per-datagram and the server keeps serving. Core's override restructured the loop: `recvfrom` gets its own narrow `try`, header parsing another, and then `_handle_discovery` / `_route_data_via` are called unguarded inside a loop whose only handler is for `KeyboardInterrupt`. But Core also made `_send_specific` re-raise `OSError` on INFORM send failure, and `_handle_discovery` sends INFORMs (`_canonical_inform`) on the normal path. One transient send error on a discovery reply therefore propagates out of `run()` and terminates the server, where the implementation it overrides would have logged nothing, dropped one datagram, and continued.
- **Fix:** Wrap the dispatch calls in `run()` with the same per-datagram `except OSError: continue` containment the base loop has.
- **Benefit:** A single failed UDP send costs one datagram, as in the base server, instead of the whole UDPFS server.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — both loops and the re-raise read in full; no execution claimed, since this sandbox blocks UDP `sendto` and any live failure here would be BLOCKED-ENV, not evidence)

### PYSMB1-19 — Environment integer/float parsing crashes at parser construction, while the neighbouring duration/size parsers were deliberately made never to raise
- **Category:** 6
- **Locations:** udpfs_server/ps2servers_core.py:529-543 (`--port`, `--sector-size`, `--compression-cache-size` defaults via `_env_int`), udpfs_server/ps2servers_core.py:566-567 (`--tx-delay-ms` default via `_env_float`), udpfs_server/udpfs_server.py:3297-3312 (`_env_int` / `_env_float` definitions: bare `int(v, 0)` / `float(v)`)
- **Problem:** Executed: with `PORT=oops` or `TX_DELAY_MS=oops` in the environment, merely calling `build_parser()` raises `ValueError` — the server dies with a traceback before argparse can produce a usage error. The same file's other environment parsers (`_env_duration`, `_env_max_transfer`, `_env_max_sessions`, imported and used lines away) were explicitly built and documented to never raise, because container/compose users set these variables and a traceback is the worst outcome — a standard the int/float path does not meet. `SECTOR_SIZE` and `COMPRESSION_CACHE_SIZE` behave identically.
- **Fix:** Give `_env_int`/`_env_float` the same warn-and-fall-back treatment at their definitions in `udpfs_server.py`, or validate the four affected values in `main()` via `parser.error` after parsing. Fixing the two helpers fixes both entry points at once.
- **Benefit:** A typo in an environment variable produces a warning or a clean usage error instead of a traceback, uniformly across the config surface.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED for `PORT` and `TX_DELAY_MS`; the other two variables share the identical helper, READ)

### PYSMB1-20 — `PROTOCOL_MODE` from the environment is neither stripped nor alias-mapped, slips past argparse's `choices`, and detonates later as an uncaught `ValueError`
- **Category:** 6
- **Locations:** udpfs_server/ps2servers_core.py:548-550 (`default=os.environ.get("PROTOCOL_MODE", "auto").lower()` on a `choices=` argument), udpfs_server/ps2servers_core.py:105-112 (`AutoUdpfsServer.__init__` raises `ValueError` for anything outside auto/standard/modulo), udpfs_server/ps2servers_core.py:591-690 (`main()`: the construction is not guarded, so the `ValueError` escapes as a traceback)
- **Problem:** The launcher's config layer accepts a wide vocabulary for this setting forever — labels ("Standard"), wire values, any casing, and the retired word "Proper" → standard (`launcher/servers.py` `protocol_mode_value` and `_PROTOCOL_MODE_BY_NAME`, read for this cross-check) — specifically so old saved settings keep working. Core's parser accepts only the three exact wire words, lowercased but not stripped. Executed: `PROTOCOL_MODE=proper` passes `build_parser().parse_args()` untouched (argparse does not validate a default against `choices`), and constructing the server exactly as `main()` does then raises `ValueError: protocol_mode must be auto, standard, or modulo`, uncaught. A trailing space (`PROTOCOL_MODE="modulo "`) fails the same way. The env var is the documented configuration route for container/systemd users, i.e. precisely the users with no launcher normalising values for them.
- **Fix:** Normalise the env default the same way `__init__` normalises its argument (strip + lower) and reject an unrecognised value with `parser.error` in `main()` before construction — or map it through the same alias table the launcher uses. No new vocabulary needs inventing; the launcher's table already exists.
- **Benefit:** A legacy or slightly-off `PROTOCOL_MODE` produces either the mode the user meant or one clean error line, not a traceback at server construction.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED — parse and construction both reproduced)

### PYSMB1-21 — Boolean environment values outside a four-word vocabulary silently parse as False — including `RO`, so `RO=2` yields a writable server with no warning — and env-enabled booleans have no CLI off-switch
- **Category:** 6
- **Locations:** udpfs_server/ps2servers_core.py:535-560 (`--read-only`, `--verbose`, `--single-port`, `--modulo-mode`, `--metrics`, `--session-summary`, all `action="store_true"` with `_env_bool` defaults), udpfs_server/udpfs_server.py:3297-3302 (`_env_bool`: only `1/true/yes/on` are True; everything else, recognised or not, is False)
- **Problem:** Two asymmetries compound. First, vocabulary: `_env_bool` treats any unrecognised value as False without a warning. Executed: `RO=2` produces `read_only = False`. For most flags that is a cosmetic surprise; for `RO` it silently defeats a safety setting — an operator who set `RO=2`, `RO=enabled`, or `RO=t` believing the share is read-only gets a read-write server and no message saying so. Second, direction: because these are `store_true` flags whose defaults come from the environment, an env-enabled boolean cannot be turned off from the command line at all — there is no `--no-read-only` counterpart (compression, tellingly, did get an explicit `--enable/--no` pair in this same parser).
- **Fix:** Warn on any non-empty boolean env value that is in neither the true nor the false vocabulary (`0/false/no/off`/empty), so an unrecognised value is loud rather than silently False. That is the whole fix for the safety half; adding negative flags is optional and larger.
- **Benefit:** A misspelled read-only setting can no longer silently produce a writable share.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED for `RO=2`; the vocabulary and the absence of negative flags are READ)

### PYSMB1-22 — The entry-point surface (parser + validation + compression precedence + server construction) is duplicated between Core and the standalone server, and again inside Core's own `main()`
- **Category:** 2
- **Locations:** udpfs_server/ps2servers_core.py:523-579 (`build_parser`) and 591-690 (`main`), udpfs_server/udpfs_server.py:3441-3600 (the standalone parser and `main`, near-identical in structure, including the identical four-step compression-precedence block at 3563-3575 vs Core's 601-608), udpfs_server/ps2servers_core.py:625-682 (the two server constructions inside Core's `main` itself)
- **Problem:** Core was supposed to be the standalone server plus negotiation; instead its CLI surface is a second copy of it. The two parsers already differ in help text, in which validations run, and in options present, and every shared option (ports, timeouts, limits, compression) must be changed twice. The duplication repeats at smaller scale inside Core's `main()`: the Modulo and Auto construction blocks share 17 keyword arguments (counted by script over the AST) and differ only in the class, two forced flags, and Auto's two extra arguments — so a new server option has to be threaded into two call sites in this one function, plus a third in the standalone file.
- **Fix:** In Core's `main()`, build one `kwargs` dict and construct once (the Modulo case then differs by class + two entries, per PYSMB1-17's resolution). Across files, have one parser builder own the shared options, with Core adding its three extra arguments — or accept the standalone file as the frozen upstream copy its header says it is, and stop treating the two parsers as peers by removing the shared-option definitions from one side.
- **Benefit:** Each config option gains exactly one definition per shipped entry point; the 17-argument construction stops being a drift hazard.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ — both parsers/mains read; the 17 shared kwargs are script-counted)

### PYSMB1-23 — DATA header parsing and payload-size computation are duplicated between `_route_data_via` and `_handle_data` (and parsed a third time by the base handler)
- **Category:** 2
- **Locations:** udpfs_server/ps2servers_core.py:360-383 (`_route_data_via`), udpfs_server/ps2servers_core.py:384-400 (`_handle_data`'s identical preamble)
- **Problem:** Both methods unpack `Header`, unpack the same `<I` data header, extract `header_words`/`data_bytes` with the same shifts, compute `payload_size` the same way, and apply the same oversize check — one to decide whether to queue the packet, the other to decide how to classify it, after which `super()._handle_data` parses it all again. The shifts and masks are protocol constants; a correction to the payload-size rule (or a bug in it) currently has three homes, two of them in this file.
- **Fix:** Parse once in `_route_data_via` and carry the parsed header/payload size in the queued item alongside the ingress it already carries, so `_handle_data` consumes the parse instead of repeating it. (The third parse, inside the base class, is the base file's business and is not required for this fix to pay off.)
- **Benefit:** One payload-size rule in Core; the queue item already exists as the place to carry per-packet facts.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — both preambles read side by side)

### PYSMB1-24 — A thread is spawned for every fallback timer, one per discovery, although at most one can ever act
- **Category:** 5
- **Locations:** udpfs_server/ps2servers_core.py:242-265 (`_schedule_fallback`: one daemon `threading.Thread` per call, sleeping `fallback_interval`), udpfs_server/ps2servers_core.py:340-358 (`_handle_discovery` calls it on every non-streaming auto-mode discovery)
- **Problem:** Consoles broadcast discovery repeatedly while looking for a server, and every such packet in auto mode starts a new thread that sleeps 0.25 s and then, in all but the latest generation, checks the guards and exits having done nothing. The generation/profile/first-data guards make the waste safe but not free: thread creation churn proportional to discovery broadcast rate, for a timer that has exactly one useful firing per handshake.
- **Fix:** Keep a single pending timer per session (cancel/replace on re-schedule, or record a deadline the receive loop checks during its existing 1-second `select` wakeup — the loop already wakes every second for the idle sweep).
- **Benefit:** No per-packet thread creation on the discovery path; the fallback mechanism's cost stops scaling with broadcast rate.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ for the spawn-per-call structure; INFERRED for the broadcast-rate cost, which depends on client behaviour the file's own comments describe)

### PYSMB1-25 — The session-stats attachment snippet is copy-pasted between Core and the SMB1 server instead of shared
- **Category:** 2
- **Locations:** udpfs_server/ps2servers_core.py:581-588 (`_attach_session_stats`), smbv1_server/smbserver_opl.py:1748-1754 (the same repo-root computation, `sys.path` insertion, lazy import, and construction, inlined in `main()`)
- **Problem:** Both shipped entry points attach `launcher.session_stats.SessionStats` with the identical dance — compute the repo root from `__file__`, append it to `sys.path` if the `launcher` package is there, import, construct with the server's key — written out twice, in the only two files in this audit's scope. (A third server, the standalone UDPFS `main`, does the same again.) If the launcher package moves or the attach contract changes, each copy drifts independently and the failure mode is a server that silently never emits SESSION lines.
- **Fix:** One tiny helper in one of the existing modules (Core's `_attach_session_stats` already has the right shape) imported by the other entry point, parameterised only by the stats key.
- **Benefit:** The attach contract lives in one place; both servers gain or lose the behaviour together.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — both copies read in full)

---

## Files read

- `smbv1_server/smbserver_opl.py` — read in full (1,862 lines, three passes over the whole file).
- `udpfs_server/ps2servers_core.py` — read in full (690 lines).
- `AGENTS.md` (repo root) — read in full (house rules; no effect on findings).
- Partial, for cross-checks cited in findings only: `udpfs_server/udpfs_server.py` (base `run()` loop, `_env_bool`/`_env_int`/`_env_float` definitions, standalone parser/`main` ranges), `launcher/servers.py` (UDPFS registry entry, `_udpfs_argv`, `protocol_mode_value` / `_PROTOCOL_MODE_BY_NAME`), `tests/test_smbv1_write_semantics.py` (the `0x04`-prefixed create-directory request form), `tests/test_udpfs_config.py` (config-surface expectations).

## Files not read (in scope)

- None for scope items (a) and (b): both in-scope files were read fully. (The task's literal path `smbv1_server/smbv1_server.py` does not exist at this pin — see the scope note at the top; `smbv1_server/smbserver_opl.py` was audited in its place.)
- Not read, and not needed for any finding: the rest of `smbv1_server/` (`README.md`, `Start-SMB-Server.bat`, `build_exe.ps1`) and the rest of `udpfs_server/` beyond the cross-check ranges listed above (`udpfs_server.py` in full, `router_status.py`, the `compressed_iso/` package, the `*_selftest.py` files).
