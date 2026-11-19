# Blind Redo Audit — Launchstation `iop/smbd` + patched libsmb2 integration

- Repo pin: Launchstation HEAD `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (verified `git rev-parse HEAD` in the clone), read-only.
- libsmb2 pin: upstream `a52c1571a1ff223bde5bb3df9fec7af5ce3855d4` per `scripts/fetch_libsmb2.sh`, with the repo's two patches applied (`iop/smbd/libsmb2-session-key-leak.patch` → `lib/libsmb2.c`; `iop/smbd/libsmb2-raw-query-info.patch` → `lib/smb2-cmd-query-info.c`). The prepared tree was absent at audit start; it was rebuilt byte-identically by the repo's own fetch procedure (depth-1 fetch of the pinned commit + `git apply` of both patches; `git diff --stat` = exactly the two patched files). libsmb2 citations below use `libsmb2/...` paths into that tree and refer to pin+patches state.
- Method: LESS NOT MORE. One mechanism = one candidate, all locations listed. Counts by script where stated. `INFERRED` = mechanism read in code but runtime effect depends on code/hardware outside the read set. No secret values printed (credential *values* are not quoted; locations only). Licences settled (libsmb2 LGPL-2.1-or-later per its COPYING and the fetch script header; Launchstation's own `iop/smbd` glue carries no licence header of its own in the read files). No saildot4k code/builds consulted or suggested.

## Coverage ledger

### Repo files read in full
| File | Lines | Notes |
|---|---|---|
| `iop/smbd/smbd.c` | 340 | platform half: allocator, iomanX/MCMAN wrappers, devctl lifecycle, server thread |
| `iop/smbd/smbd_fs.c` | 1016 | all SMB request handlers, handle table, serve setup |
| `iop/smbd/smbd.h` | 61 | file-interface contract, limits |
| `iop/smbd/config.h` | 16 | libsmb2 build config for the IOP target (drives SMBD-001) |
| `iop/smbd/imports.lst`, `iop/smbd/irx_imports.h`, `iop/smbd/linkfile` | 84/16/155 | import surface matches the calls actually made; linkfile is the ps2sdk IOP linkfile with `--gc-sections` collection |
| `iop/smbd/libsmb2-session-key-leak.patch`, `iop/smbd/libsmb2-raw-query-info.patch` | 14/14 | both verified applied in the rebuilt tree |
| `include/smbd_devctl.h` | 11 | devctl contract |
| `scripts/fetch_libsmb2.sh` | full | pin + patch application; idempotence stamp is a hash of the patch files |
| `ps2.yaml` (smbd target, lines 294–359) | — | 55 sources by script: 2 own (`smbd.c`, `smbd_fs.c`) + 53 libsmb2 |
| `src/init.c` lines 2775–2845 | partial | EE caller of the devctls (START arg construction, status/stop) — integration surface only |
| `tests/smbd_live/host.c`, `tests/smbd_live/run.sh` | full | host stand-in + live-test script; used for the executed check below |

### libsmb2 files read (pin+patches tree)
| File | Extent |
|---|---|
| `lib/smb2-cmd-query-info.c` (PATCHED) | full, 833 lines |
| `lib/compat.c` | full, 786 lines (PS2/IOP block + `NEED_RANDOM`/`NEED_SRANDOM`/`NEED_*` shims are the compiled parts) |
| `lib/libsmb2.c` (PATCHED) | server-relevant ranges line-read: 150–330 (context close), 770–1180 (signing-key derivation / client session-setup verification), 4950–5992 (session retirement, server session-setup incl. the patched hunk, negotiate, `smb2_serve_port`); client-only API ranges 330–770 and 1180–4950 pattern-scanned for allocator/`close_context` use, **not** line-read |
| `lib/socket.c` | receive path + signing verification + PDU-cap ranges (lines ~160–430, 540–900, 1150–1210, 1420–1440) |
| `lib/init.c` | lines 320–450 (`smb2_random_bytes`, context init seeding) + `smb2_set_user` range |
| `lib/ntlmssp.c` | lines 990–1030 (server challenge), 1330–1577 (AUTHENTICATE verification, session-key export) |
| `lib/smb2-cmd-write.c` | request fixed/variable processing (lines 190–328) |
| `lib/smb2-cmd-create.c` | request fixed/variable processing (lines 330–589) |
| `lib/smb2-cmd-query-directory.c` | full, 596 lines |
| `lib/smb2-cmd-query-info.c` request processing | lines 740–833 (with the patched encode at 120–360) |
| `lib/smb2-cmd-set-info.c` | lines 300–422 (request fixed/variable) |
| `lib/smb2-cmd-read.c` | lines 240–340 (reply processing; server read *reply encode* is in the same file's earlier range, skimmed) |
| `lib/alloc.c` | full, 154 lines |
| `lib/unicode.c` | lines 1–160 (UTF-8 validation; UTF-16→UTF-8 converter used by create/query-dir/rename paths pattern-checked) |
| `include/libsmb2-private.h` | lines 345–380 (`smb2_recv_pdu_cap`, PDU size caps) |

### Not read (explicitly out of the bound)
- The remaining compiled libsmb2 translation units as whole files (crypto implementations `aes*.c`, `sha*.c`, `md4c.c`, `md5.c`, `hmac*.c`, `smb2-signing.c`, `smb3-seal.c` beyond the nonce line, `asn1-ber.c`, `spnego-wrapper.c` beyond its use in session setup, `pdu.c` beyond signing/queue ranges, `errors.c`, `timestamps.c`, `sync.c`, `smb2-share-enum.c`, the remaining `smb2-cmd-*.c` reply encoders, `smb2-data-*.c` encoders): these are upstream, unpatched, and only reachable through the decoders/encoders verified above; auditing all upstream libsmb2 was excluded by the task bound.
- `lib/krb5-wrapper.c` and `lib/aes_apple.c`: **not compiled** (correctly absent from `ps2.yaml`; no `HAVE_LIBKRB5` in `config.h`).
- `lib/ps2/` inside libsmb2 (its own old smb2man copy): not referenced by the smbd target; not read.
- EE code beyond the `src/init.c` range above; MCMAN/vmcman internals (effects depending on them are labelled INFERRED); PS2 hardware behaviour (nothing here is hardware-verified).

### Executed check (host, not hardware)
The host harness (`tests/smbd_live/host.c` + `smbd_fs.c` + pinned/patched libsmb2, built without sanitizers) was run: the server stayed alive >2 s idle, and SIGTERM → `smbd_stop()` returned 0 with 0 card descriptors open. This **refuted** a candidate serve-loop early-exit reading of `smb2_serve_port` and confirms the stop path on the host. It does not exercise the IOP, ps2ip, or MCMAN.

---

## Candidate findings (sorted by benefit)

### SMBD-001 — Predictable randomness for the NTLM server challenge, the SMB 3.1.1 pre-auth salt, and SMB3 seal nonces on the IOP
- **Category:** 6 (randomness/nonce quality)
- **Locations:**
  - `iop/smbd/config.h:1-16` — defines none of `HAVE_ARC4RANDOM_BUF` / `HAVE_GETRANDOM` / `HAVE_DEV_URANDOM`; defines `NEED_RANDOM`/`NEED_SRANDOM`.
  - `libsmb2/lib/init.c:342-411` — `smb2_random_bytes()` therefore always takes the `random() & 0xff` fallback on this target.
  - `libsmb2/lib/init.c:427` — the fallback is seeded once per context with `srandom(time(NULL) ^ getpid() ^ (uintptr_t)smb2)`; on the IOP `getpid()` is the constant 27 (`libsmb2/lib/compat.c`, `getpid_num()` in the `_IOP` block) and `time()` is seconds-since-boot from `GetSystemTime` (same file), so the seed is essentially boot-time XOR a heap address.
  - `libsmb2/lib/compat.c:509-532` — IOP `random()` is a single global LCG (`next = next * 1103515245 + 12345`, 15 bits returned per call), reseeded by every new client context.
  - Consumers: `libsmb2/lib/ntlmssp.c:1009` (NTLMv2 **server challenge**), `libsmb2/lib/init.c:440-443` (client challenge, salt, GUID), `libsmb2/lib/smb3-seal.c:155` (AES-CCM/GCM nonce for sealed PDUs).
- **Mechanism:** every value libsmb2 itself documents as needing unpredictability (the comment at `libsmb2/lib/init.c:327-340` says a predicted CCM nonce "breaks both the confidentiality and the integrity of the sealed traffic", and `libsmb2/lib/ntlmssp.c:1003-1008` says the challenge "has to be unpredictable") is, in the smbd build only, drawn from a 31-bit-state LCG whose seed is largely observable/guessable (boot seconds, constant pid, allocator address). One observed challenge or nonce exposes the LCG state and makes past/future values on that boot computable; a repeated CCM nonce under one session key is the catastrophic case.
- **Fix (LESS NOT MORE):** give `smb2_random_bytes` one real entropy input on the IOP before first use — e.g. seed/mix from the IOP's own timers plus the remote address/port and a monotonic counter is *not* sufficient alone; the honest minimal fix is to feed the LCG replacement with a hash of several hardware counters sampled at accept time, or drop SMB 3.x sealing/challenge reliance and document the limit. Any fix must stay inside `iop/smbd`'s platform layer (a strong `smb2_random_bytes` override or a `config.h`-selected source), not a libsmb2 fork edit beyond the existing patch mechanism.
- **Status:** verified in code for the IOP build configuration; not exercised on hardware.

### SMBD-002 — No authentication throttling anywhere, and the shipped login is the compiled-in default
- **Category:** 1 (auth/session handling)
- **Locations:**
  - `iop/smbd/smbd.c:28` — the module's built-in fallback login (user and password fields; values not printed here) is a short, publicly known pair, also used as the settings default (seen in `src/config.c` defaults via the integration read).
  - `libsmb2/lib/libsmb2.c:5179` bounds session-setup *legs* per attempt sequence, but `libsmb2/lib/libsmb2.c:5431` resets `session_setup_legs = 0` whenever a sequence completes — including a failed AUTHENTICATE — so attempts per connection are unbounded; neither `iop/smbd/smbd_fs.c` (`authorize_user`) nor `iop/smbd/smbd.c` adds any delay, counter, or lockout, and new connections are accepted indefinitely (see SMBD-004 note on the 2-client cap being the only brake).
- **Mechanism:** an unauthenticated LAN peer can guess passwords at wire speed, forever, against an account whose default password is known and which many users will never change (changing it is optional in Settings). NTLMv2 verification is sound (checked-clean below); the exposure is purely online guessing volume × a weak default.
- **Fix:** in `smbd_fs.c`/`smbd.c` only: count consecutive failed authorizations per server run and add a growing delay (or refuse further session setups until a stop/start) after a small threshold; surface the failure count through the existing STATUS devctl. No protocol change.
- **Status:** verified in code.

### SMBD-003 — 64-bit SMB file offsets are silently truncated to signed 32-bit before hitting the card
- **Category:** 2 (request parsing bounds)
- **Locations:** `iop/smbd/smbd.c:150-160` — both `smbd_pread` and `smbd_pwrite` do `iomanX_lseek(fd, (int)off, FIO_SEEK_SET)`; callers `iop/smbd/smbd_fs.c` `read_cmd` (~line 441) and `write_cmd` (~line 466) pass `req->offset` (uint64 from the wire) with no range check.
- **Mechanism:** a WRITE at offset 2³²+5 seeks to offset 5 and overwrites the start of the file; an offset with bit 31 set seeks negative (driver error at best). Memory-card files can never legitimately approach 2 GiB, so every offset above the card's size is either an error or an attack/buggy client — the code currently converts the dangerous ones into wrong-offset I/O instead of `STATUS_INVALID_PARAMETER`. This is data corruption reachable by any authenticated client (and the session is single-user, so "authenticated" is the only bar).
- **Fix:** reject `off > INT32_MAX` (or `off >=` card capacity) once, in `smbd_pread`/`smbd_pwrite`, returning `-EINVAL`; two lines, no new state.
- **Status:** verified in code.

### SMBD-004 — Handles are bound to a connection, not to a session or a tree: LOGOFF, session retirement, and TREE_DISCONNECT all leave every handle usable
- **Category:** 1 (auth/session handling) / 4 (handle lifecycle)
- **Locations:**
  - `iop/smbd/smbd_fs.c:284-289` — `logoff_cmd` is a no-op.
  - `iop/smbd/smbd_fs.c:323-330` — `tree_disconnect_cmd` is a no-op.
  - `iop/smbd/smbd_fs.c:159-175` — `lookup()` checks only `handles[i].owner != smb2` (the *context/connection*) and the generation; it never checks the request's session or tree.
  - `libsmb2/lib/libsmb2.c:4977-5005` — on a new session setup, `smb2_server_retire_session()` drops the old session's keys/auth and calls the (no-op) `logoff_cmd`; handles survive by design of the glue.
  - Only `create_cmd` and the FS-info branch consult `share_of_tree()`; `read_cmd`/`write_cmd`/`close_cmd`/`query_info_cmd`/`set_info_cmd` never verify that the request's tree matches `handles[i].share`.
- **Mechanism:** (a) after a client logs off — or a *second, different* logon session on the same connection retires the first (libsmb2's own comment at `libsmb2/lib/libsmb2.c:4963-4976` describes Windows doing exactly this) — all files the previous session opened remain readable/writable under the new session, including `delete_on_close` state; (b) a handle opened on `mc0` can be used in a request carrying `mc1`'s tree id (and vice versa), so the share binding exists only at CREATE time. Single-user server, so impact is session-confusion and spec violation rather than cross-user escalation — but LOGOFF that does not log anything off is a half-kept auth promise, and it also keeps the single shared card descriptor (see `card_fd` in `smbd_fs.c`) pinned after the user believes the session ended.
- **Fix:** release the context's handles in `logoff_cmd` (the loop already exists in `destruction_event`, `smbd_fs.c:272-282` — call the same helper), and record/check the tree's share in `lookup()` for the commands that carry one. Deletion-shaped fix: one shared release loop, one comparison.
- **Status:** verified in code.

### SMBD-005 — `SMBD_DEVCTL_START` parses the credential blob past its stated length, and reports success for credentials it did not take
- **Category:** 2 (request parsing bounds) / 1
- **Locations:** `iop/smbd/smbd.c:283-290` (devctl START), with the caller contract in `include/smbd_devctl.h` and construction in `src/init.c:2790-2793`.
- **Mechanism:** the handler checks `arglen > 2` and that the *last* byte is NUL, then takes the password from `(char *)arg + strlen(arg) + 1` without ever checking that a second NUL-terminated string actually lies inside `arglen`. A blob containing one string (or a first string ending exactly at `arglen-1` with the mandatory trailing NUL being that same terminator) makes `strncpy` read up to 31 bytes past the supplied buffer in IOP memory and install whatever it finds as the password. The in-tree caller always builds a well-formed blob, so today this is a latent trap for the next caller, not a live exploit. Separately, when the server is already running, the blob is silently ignored and `start()` returns 0 — the EE side records the *new* login as pending while the server keeps the old one (the EE comment at `src/init.c:2810` acknowledges the divergence), so the UI and the wire can disagree about the password indefinitely.
- **Fix:** validate `strlen(arg) + 1 < arglen` and a terminator for the second string within `arglen` before copying; return `-EBUSY` (or the existing running status) when START arrives while running instead of unconditional 0.
- **Status:** verified in code; in-tree caller is well-formed (checked).

### SMBD-006 — SET_INFO classes that report success without performing the operation
- **Category:** 8 (half-finished protocol features)
- **Locations:** `iop/smbd/smbd_fs.c:910-940` (`set_info_cmd`):
  - `SMB2_FILE_BASIC_INFORMATION` — returns 0; timestamps/attributes the client set are silently discarded (comment admits "kept as the card has them").
  - `SMB2_FILE_ALLOCATION_INFORMATION` — returns 0; nothing is allocated or truncated.
  - `SMB2_FILE_END_OF_FILE_INFORMATION` — returns 0 for any size ≥ current size without extending the file; a client that "pre-sizes" a file and then reads the gap gets END_OF_FILE where it was told zeros exist.
- **Mechanism:** three distinct client-visible lies with one shape: success status, no effect, no record. Tools that set timestamps after a copy (the common case for BASIC) silently produce wrong metadata; tools that grow-then-write-sparse corrupt their own bookkeeping. The honest behaviours already exist in the same function — unsupported classes return `SMB2_STATUS_NOT_SUPPORTED` at the bottom.
- **Fix (LESS NOT MORE):** return `SMB2_STATUS_NOT_SUPPORTED` for ALLOCATION and for END_OF_FILE growth, and either implement BASIC times via the existing stat path or return NOT_SUPPORTED for it too. Fewer promises, no new code paths of substance.
- **Status:** verified in code.

### SMBD-007 — LOCK succeeds without locking, and CREATE ignores share-access and oplock semantics while two clients may hold the same file
- **Category:** 8 (half-finished protocol features)
- **Locations:** `iop/smbd/smbd_fs.c:491-497` (`lock_cmd` returns 0 for every lock/unlock request), `iop/smbd/smbd_fs.c:340-410` (`create_cmd` never reads `req->share_access` or `req->requested_oplock_level`, always replies `oplock_level = 0` while granting `maximal_access = FILE_ALL_ACCESS` at tree connect, `smbd_fs.c:340-345` region).
- **Mechanism:** a client that takes an exclusive byte-range lock is told it holds one; the second allowed client (SMBD_MAX_CLIENTS = 2) can then write the same ranges through the shared single card descriptor. Nothing in the handle table records ranges or sharing intent. On a single-console LAN tool the realistic failure is two PCs copying to the same save folder "safely" under locks that do not exist.
- **Fix:** either track the (tiny) lock set per handle — more code — or, LESS: fail LOCK with `SMB2_STATUS_NOT_SUPPORTED` like IOCTL/CHANGE_NOTIFY already do, and deny a second CREATE whose share-access excludes an existing handle on the same path. The status-only half is a few lines.
- **Status:** verified in code.

### SMBD-008 — QUERY_DIRECTORY never validates the information class: unsupported classes return a successful empty listing, and FileId is always zero
- **Category:** 8 (half-finished protocol features) / 2
- **Locations:** `iop/smbd/smbd_fs.c:545-640` (`query_directory_cmd` fills `smb2_fileidbothdirectoryinformation` entries regardless of `req->file_information_class`; `ent[n].file_id` is never assigned, `ent[n].file_index = n` restarts per batch); `libsmb2/lib/smb2-cmd-query-directory.c:201-218` (`dir_entry_size()` returns 0 for any class outside its six) and the encoder at lines 239-300, which then computes a zero total output length and produces a *successful* reply with no entries.
- **Mechanism:** ask for any class outside the six encodable ones and the client is told "this folder is empty" instead of NOT_SUPPORTED — a data-hiding lie of the same family as SMBD-006, reachable by any client that prefers e.g. FileStreamInformation or a future class. Separately, every entry in the IdBoth/IdFull classes carries FileId 0, so clients that key on FileId (backup tools, some shells) see all files as the same file.
- **Fix:** whitelist the six classes at the top of `query_directory_cmd` (one comparison chain, mirroring `dir_entry_size`), return `SMB2_STATUS_INVALID_INFO_CLASS`-family status otherwise; fill `file_id` from the existing `file_number(path)` helper used by QUERY_INFO — which needs the entry's full path, so if that is judged too much code, at minimum do the whitelist half.
- **Status:** verified in code (encoder behaviour line-read).

### SMBD-009 — File-id validation uses only 4 of the 16 file-id bytes, and the generation counter wraps at 16 bits
- **Category:** 4 (file handle lifecycle)
- **Locations:** `iop/smbd/smbd_fs.c:159-175` (`lookup()` compares `id[0..3]` only: slot index + `gen`; bytes 4–15 are ignored), `iop/smbd/smbd_fs.c:397` (`h->gen = next_gen++`, `next_gen` is `uint16_t`, line 40), `iop/smbd/smbd_fs.c:405-409` (file_id construction zeroes the other 12 bytes).
- **Mechanism:** a stale file id becomes valid again after 65,536 CREATEs recycle the same slot with the same generation — and because the unused 12 bytes are always zero in issued ids and ignored in lookup, there is no extra entropy to save it. The all-`0xff` compound shortcut (`last_create`) is a single global across both clients; the owner check in `lookup()` is the only thing keeping client A's compound chain from resolving to client B's just-created handle (it does — checked — but the margin is one comparison). Impact is bounded by the single authenticated user, hence low benefit, but the fix is equally small.
- **Fix:** widen `gen` to 32 bits into file-id bytes 2–5 and compare them; or don't recycle a slot's generation space — simplest: make `next_gen` `uint32_t` and extend the existing comparison by two bytes.
- **Status:** verified in code.

### SMBD-010 — WRITE accepts lengths above the negotiated maximum the server itself advertised
- **Category:** 2 (request parsing bounds)
- **Locations:** `iop/smbd/smbd_fs.c:466-489` (`write_cmd` never compares `req->length` with `SMBD_MAX_IO`); contrast `read_cmd` at `smbd_fs.c:450-451`, which clamps to `SMBD_MAX_IO`; the advertised maxima are set at `smbd_fs.c:1000` (`max_write_size = SMBD_MAX_IO` = 65536, `smbd.h:27`).
- **Mechanism:** the libsmb2 decoder bounds `req->length` only against the received PDU (cap ≈ max + 64 KiB slack, `libsmb2/include/libsmb2-private.h:359-370`), so a client can push ~128 KiB writes at a server that negotiated 64 KiB, in one `iomanX_write` through `smbd_pwrite`. MCMAN-side behaviour for oversized single writes is outside the read set (INFERRED: short writes are handled via `rep->count`, so the likely outcome is inefficiency/protocol violation rather than corruption) — but the asymmetry with `read_cmd` shows the clamp was intended and missed on the write side.
- **Fix:** the same two-line clamp `read_cmd` already has.
- **Status:** verified in code; downstream effect INFERRED.

### SMBD-011 — Server identity is a compile-time constant and session ids restart from a fixed counter on every serve
- **Category:** 6 (randomness/nonce quality) / 8
- **Locations:** `iop/smbd/smbd_fs.c:998` (`memcpy(server.guid, "Launchstation-PS", 16)` — the same server GUID for every console and every boot); `libsmb2/lib/libsmb2.c:5807` (`server->session_counter = 0x1234` at every `smb2_serve_port` entry, so session ids are 0x1234, 0x1235, … after each start).
- **Mechanism:** SMB clients key server identity and session state on the GUID; two Launchstation consoles on one LAN are indistinguishable to a client's cache, and a restarted server reissues identical session ids — the exact conditions MS-SMB2's GUID/session-id uniqueness rules exist to prevent (stale client state applied to a fresh server). Signing keys differ per authentication, so this is confusion/staleness, not key compromise.
- **Fix:** derive the GUID once per serve from the console's own identity material available on the IOP (e.g. MAC address from the already-loaded network stack, mixed with boot time) instead of a string literal; no new subsystem.
- **Status:** verified in code; client-visible impact INFERRED (no Windows client test in the read set).

### SMBD-012 — CREATE does not enforce the card's 31-byte leaf limit that RENAME carefully enforces
- **Category:** 3 (path traversal / path handling)
- **Locations:** `iop/smbd/smbd_fs.c:340-410` (`create_cmd` → `make_path` checks total length `SMBD_PATH_MAX` only); contrast `iop/smbd/smbd_fs.c` `rename_handle` (~lines 855-860), which rejects a leaf longer than `SMBD_LEAF_MAX` (31, `smbd.h:25`) with NAME_TOO_LONG, and `iop/smbd/smbd.c:230-241` (`smbd_rename` `strcpy`s the leaf into `sceMcTblGetDir.EntryName` trusting that check).
- **Mechanism:** path *escape* is properly refused (checked-clean below), but a CREATE with a 40-byte leaf goes straight to `iomanX_open`; what MCMAN does with an over-long component — fail cleanly or truncate — is in the unread vmcman set, so the risk is INFERRED: if any card driver truncates, the client is told it created a name that does not exist under that name, and a later open of the *requested* name misses while the truncated one collides with other long names sharing a 31-byte prefix.
- **Fix:** apply the existing `SMBD_LEAF_MAX` per-component check inside `make_path` (it already walks component by component) so CREATE, RENAME, and every other verb share one rule; rename's duplicate check can then be deleted.
- **Status:** mechanism verified in the glue; card-driver consequence INFERRED.

### SMBD-013 — Dead vendored code in the compiled set: two empty-by-`#ifdef` translation units and two client-only libraries linked into a server IRX
- **Category:** 7 (dead vendored code in compiled set)
- **Locations:** `ps2.yaml:315-316,349,344` compiles `libsmb2/lib/quic.c` (342 lines; entire body under `#ifdef HAVE_LIBQUIC`, not defined in `iop/smbd/config.h` — an empty object), `libsmb2/lib/smbdirect.c` (1021 lines; body under `#ifdef HAVE_LIBRDMACM`, likewise undefined), `libsmb2/lib/sync.c` (1274 lines; the *client* synchronous API — the server path never calls it), and `libsmb2/lib/smb2-share-enum.c` (1005 lines; client share enumeration). Counts by `wc -l` on the pinned tree.
- **Mechanism:** `--gc-sections` (`ps2.yaml:358`) strips the unreferenced client code at link time, so the IRX-size cost is mostly contained — the real cost is build time on every build, four more upstream files whose warnings/patches must be reasoned about during libsmb2 pin bumps, and audit surface that looks reachable when it is not. This is the weakest finding here and is included because Category 7 asks exactly this question; the honest answer is "dead at compile time, stripped at link time".
- **Fix (LESS NOT MORE):** delete the four entries from the smbd target's source list in `ps2.yaml` (keep them in the fetched tree; the fetch script is unchanged). Verify with one build that the IRX still links — the serve path references none of them.
- **Status:** verified by reading the guards and the target definition; link-strip claim rests on the target's own `ldflags`, not on a performed build.

### SMBD-014 — Failed thread start leaks the created thread
- **Category:** 5 (leaks)
- **Locations:** `iop/smbd/smbd.c:246-270` (`start()`): if `StartThread` fails after `CreateThread` succeeded, the function returns the error with `running = 0` but never deletes the created thread; the next START creates another.
- **Mechanism:** a small, bounded IOP resource leak on an error path that should be rare (thread creation succeeding while start fails) — included for completeness of the lifecycle audit; every other error path in the file was checked and cleans up (see checked-clean).
- **Fix:** `DeleteThread(id)` in that branch — one call, matching the module's own `ExitDeleteThread` lifecycle.
- **Status:** verified in code.

---

## Checked-clean notes (read and deliberately not findings)

- **Path traversal (Cat 3), the core question:** `make_path` (`smbd_fs.c:135-165`) splits on both separators, refuses `..` components and any component containing `:`, caps total length, and roots everything at the share's `mcX:` prefix; the live harness's `..\..\host.log` escape test exists in `tests/smbd_live/run.sh`. No escape found in the read set.
- **Request-decoder bounds (Cat 2), libsmb2 side:** the server-reachable decoders line-read (create, write, query-directory, query-info, set-info) all validate offsets/lengths against `smb2->spl` with 64-bit arithmetic, including the wrap cases; the receive path caps PDU size at negotiated max + 64 KiB slack (`libsmb2-private.h:359-370`, `socket.c:572-577`). WRITE's `length` cannot exceed received bytes (`smb2-cmd-write.c:293-300`). SET_INFO's variable part checks `iov->len < buffer_length` (`smb2-cmd-set-info.c`, variable processor); its ignored `buffer_offset` is a protocol nit, not a bounds hole, given that check.
- **Signing enforcement:** once negotiated, unsigned or wrongly-signed PDUs are dropped in `libsmb2/lib/socket.c` (~lines 1171-1210), and the check is deliberately *not* conditioned on the attacker-controlled SIGNED flag. `signing_enabled = 1`, `allow_anonymous = 0` in `smbd_serve` (`smbd_fs.c:995-1001`).
- **NTLM verification:** NTProof is recomputed and compared (`ntlmssp.c`, AUTHENTICATE processor); NTLMv1-shaped responses are rejected by the challenge-length check; an empty configured password fails *closed* (the anonymous branch requires `allow_anonymous`, which is 0). `authorize_user` is case-insensitive on the user name and hands libsmb2 the configured password — no user-enumeration oracle beyond the LOGON_FAILURE the protocol requires.
- **The repo's two patches:** the session-key patch frees the previous key before each re-fetch in the server session-setup callback (the repeated-leg leak it names is real in the unpatched flow and the fix is correctly placed); the raw query-info patch's passthrough branch copies at most `rep->output_buffer_length` bytes into a buffer allocated at that length + 1024 (`smb2-cmd-query-info.c:164-180`), and `smbd_fs.c` pre-refuses raw classes that exceed the client's output buffer — no overrun introduced.
- **Serve loop / lifecycle:** an initial candidate — that `smb2_serve_port` exits if no client connects within the first select window — was **executed and refuted** on the host harness (server alive after 2 s idle; clean stop, 0 leaked descriptors). STOP waits up to 3 s and reports `-EBUSY` honestly (`smbd.c:291-295`); shutdown destroys remaining contexts without `destruction_event`, but `smbd_serve` then calls `smbd_release_all()` and zeroes the client counter (`smbd_fs.c:1001-1005`), so handles do not survive a serve cycle.
- **Allocator (`smbd.c:34-80`):** the size-word scheme is internally consistent; `realloc` preserves the old block on allocation failure; every libsmb2 allocation family reachable from the server (PDU iovecs, `smb2_alloc_*`, UTF-16 conversions, `strdup` shim) goes through this same allocator on the IOP, so no cross-allocator free was found in the read set. `calloc`'s unchecked `n * size` multiplication is noted but every reachable size is bounded by the 128 KiB PDU cap, so it is not promoted to a finding.
- **Handle-table mechanics:** slot scan, generation assignment, the single-shared-`card_fd` owner switching, `delete_on_close` execution in `release()`, and `destruction_event` cleanup are internally consistent for a single-threaded serve loop; directory listings reopen and re-skip by `dir_pos` and stash one pending entry correctly (including the pattern-change nit being cosmetic only). QUERY_DIRECTORY's static buffers are safe because the serve loop is single-threaded.
- **Duplicated logic (Cat 7, second half):** the only true duplication found is by-design — `tests/smbd_live/host.c` re-implements the `smbd.h` platform interface in POSIX, and libsmb2's crypto/UTF-16 helpers also exist in the separate `smb2man` IRX's usmb2 copies, but those are different binaries, so there is no in-binary duplication worth a finding. `smbd_fs.c`'s local `le32`/`put_le32`/`put_le64` helpers duplicate libsmb2 getters in miniature; too small to act on under LESS NOT MORE.
- **Out-of-scope observation, not a finding:** the EE settings layer stores the server password in a plaintext config file (`src/config.c`, seen during the integration read). It belongs to the config/EE audit surface, not to `iop/smbd`; flagged here only so it is not lost.

## Category counts (primary category per finding)

| Category | Count | Findings |
|---|---|---|
| 1 Auth/session | 2 | SMBD-002, SMBD-004 |
| 2 Request parsing bounds | 3 | SMBD-003, SMBD-005, SMBD-010 |
| 3 Path traversal | 1 | SMBD-012 |
| 4 Handle lifecycle | 1 | SMBD-009 |
| 5 Leaks | 1 | SMBD-014 |
| 6 Randomness/nonce | 2 | SMBD-001, SMBD-011 |
| 7 Dead/duplicated code | 1 | SMBD-013 |
| 8 Half-finished features | 3 | SMBD-006, SMBD-007, SMBD-008 |
| **Total** | **14** | SMBD-001 … SMBD-014 |
