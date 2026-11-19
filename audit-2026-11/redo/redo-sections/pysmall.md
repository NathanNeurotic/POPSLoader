# PS2-Servers — Blind Redo Audit: the three smaller Python servers (PYSMALL)

- **Repo / pin:** PS2-Servers @ `c5f021c4d38698860f56b03498adc261dbb8d8dd` (clone `~/workspace/audit-clones-2026-11-13/PS2-Servers`, read-only; all executions in `/tmp` copies)
- **Scope:** `udpbd_server/` (462 + 179 lines), `http_server/http_server.py` (1,237 lines), `nfs4_server/nfs4_server.py` (1,113 lines) — every in-scope `.py` read in full.
- **Method:** full reads; scripted AST census for dead symbols (none of consequence found — see note at end); grep-verification of every cited file/symbol; handler-level executions with fake sockets / crafted RPC records (no network). The repo's own `udpbd_server/selftest.py` could not run in this sandbox — its first UDP `sendto` fails with `PermissionError: [Errno 1] Operation not permitted`, which is the sandbox UDP block (**BLOCKED-ENV**), not a repo defect; UDPBD behaviour below was therefore executed by calling the handlers directly.
- **Cross-references read outside scope (for contrast only):** `launcher/raw_storage.py:14-110` (`RawDevice`), `launcher/virtual_exfat.py:60-70,228-233,319-320` (`VirtualExfat`), `launcher/session_stats.py:24,36-37` (`IDLE_SECONDS = 60.0`), `smb2_server/smb2_paths.py` (`Share`/`check_component` exist at lines 70/102/117/171; NFS imports them).

---

### PYSMALL-01 — UDPBD file-backed BlockDevice has no extent bounds: out-of-range WRITE silently extends the image, out-of-range READ silently returns zeros
- **Category:** 6
- **Locations:** `udpbd_server/udpbd_server.py:118-130` (`BlockDevice.seek/read/write`), `udpbd_server/udpbd_server.py:205-222` (`_handle_read`: bounds check only under `is_raw`), `udpbd_server/udpbd_server.py:238-261` (`_handle_write`: no bounds check at all)
- **Problem:** `BlockDevice.seek` is a bare `self._f.seek(sector * SECTOR_SIZE)` with no comparison against `self.size`; `read` deliberately zero-pads past EOF ("past end of image — pad so packet sizing stays correct") and `write` writes wherever the seek landed. The only extent check in the server (`sector_nr + sector_count > sector_count()`, line 208-209) is gated on `getattr(self.bd, "is_raw", False)`, which the plain file device never sets — both raw backends set `is_raw = True` and enforce the same bound again in their own `seek` (`launcher/raw_storage.py:37-45`, `launcher/virtual_exfat.py:228-233`, read for contrast). So the file device — the default mode — is the only one of the three backends with no clamp. EXECUTED (fake socket, 4-sector image): a `CMD_WRITE` for sector 1000 count 2 was accepted (`_write_left = 1024`), and the following WRITE_RDMA grew the file from 2,048 to 513,024 bytes and replied success; a direct `seek(100)` + 512-byte write grew a 1,024-byte image to 51,712 bytes; a read at sector 500 of a 2-sector image returned 512 zero bytes. A buggy or hostile LAN client can therefore bloat/corrupt the served image with sparse writes at offsets up to ~2 TiB (32-bit sector × 512), and reads past the end fabricate a zero-filled disc instead of failing.
- **Fix:** In `_handle_read`/`_handle_write`, drop the `is_raw` gate and reject (or clamp-and-error) any request with `sector_nr + sector_count > self.bd.sector_count()` for every backend — the check already exists, it is just conditional on the wrong thing. Keep `BlockDevice.read`'s padding for short final reads within the image.
- **Benefit:** The default serving mode gets the same extent guarantee the raw and virtual modes already have; a malformed request can no longer resize the user's image file.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMALL-02 — UDPBD write state is one global slot: any client's INFO or READ silently aborts another client's in-flight write
- **Category:** 6
- **Locations:** `udpbd_server/udpbd_server.py:151-152` (`_write_left`/`_write_owner` on the single server object), `udpbd_server/udpbd_server.py:198` (`_handle_info` resets `_write_left`), `udpbd_server/udpbd_server.py:214` (`_handle_read` resets `_write_left`), `udpbd_server/udpbd_server.py:248-249` (`_handle_write` overwrites state/owner), `udpbd_server/udpbd_server.py:263-272` (RDMA side does check `_write_owner`)
- **Problem:** The RDMA handler carefully refuses packets from a different `(addr, cmdid)` owner, but the state it protects is global and is zeroed unconditionally by `_handle_info` and `_handle_read` from *any* address, and overwritten by any second client's `CMD_WRITE`. EXECUTED: client A opened a write (`_write_left = 1024`); an unrelated READ from a different address left `_write_left = 0` — A's subsequent RDMA packets are then dropped as "unsolicited" and A never receives a `CMD_WRITE_DONE`, so the console hangs or retries a save that was silently discarded. On a multi-console network (or one console rebooting into INFO while another writes), saves corrupt/hang without any error being logged.
- **Fix:** Only reset `_write_left` in `_handle_info`/`_handle_read` when the packet's address matches `_write_owner` (or there is no owner); a `CMD_WRITE` from a second address while a write is in flight should be refused/ignored rather than stealing the slot.
- **Benefit:** One console's discovery/read traffic can no longer destroy another console's in-flight VMC/save write.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMALL-03 — UDPBD `BlockDevice` constructor validates the target type but not its size: >2 TiB images break INFO packing, non-512-multiple sizes silently lose their tail
- **Category:** 6
- **Locations:** `udpbd_server/udpbd_server.py:82-116` (`__init__` + `sector_count`), `udpbd_server/udpbd_server.py:201-203` (INFO reply `struct.pack("<II", SECTOR_SIZE, self.bd.sector_count())`)
- **Problem:** `sector_count()` is `size // SECTOR_SIZE` with no upper bound and no alignment check. The INFO reply packs it as a uint32, so an image larger than 2 TiB − 512 B raises `struct.error` inside `_handle_info`; the run loop catches `struct.error` as a "bad packet" (verbose-only log) and sends no reply — the console simply never discovers the server, with nothing logged at default verbosity. The raw backend rejects exactly this case at construction ("fit UDPBD's 32-bit sector count (less than 2 TiB)", `launcher/raw_storage.py:30-33`, read for contrast); the file backend does not. Separately, a file whose size is not a multiple of 512 has its trailing bytes silently unservable (`size // 512` truncates) with no warning. Note PYSMALL-01 makes the >2 TiB case reachable at runtime too, by growing an image through out-of-range writes.
- **Fix:** In `BlockDevice.__init__`, after measuring `self.size`, raise `ValueError` if `sector_count()` exceeds `0xFFFFFFFF` and warn (or reject) when `size % SECTOR_SIZE != 0` — mirroring the validation the raw backend already performs.
- **Benefit:** An unservable image fails loudly at startup with the real reason instead of silently never answering discovery.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (INFERRED — the pack overflow follows from the cited lines; the constructor gap is READ)

### PYSMALL-04 — UDPBD read-only file device silently swallows an entire write transfer and only reports failure at the very end — unlike both other backends, which raise on the first write
- **Category:** 6
- **Locations:** `udpbd_server/udpbd_server.py:127-130` (`BlockDevice.write`: `if self.read_only: return`), `udpbd_server/udpbd_server.py:245-261` (`_handle_write` warns, then still seeks and arms `_write_left`), `udpbd_server/udpbd_server.py:285-304` (failure result `-1` only computed once `_write_left` reaches 0)
- **Problem:** On a read-only image the server accepts the `CMD_WRITE` handshake, receives and discards every WRITE_RDMA packet (`BlockDevice.write` is a silent no-op), and only after the client has sent the whole region does it reply `-1`. Both other backends behave differently: `RawDevice.write` raises `PermissionError(EROFS)` (`launcher/raw_storage.py:78-80`) and `VirtualExfat.write` raises the same (`launcher/virtual_exfat.py:319-320`), which `_handle_write_rdma`'s `OSError` path turns into an immediate `-1` reply and abort. The file backend's silent no-op also means any future caller of `BlockDevice.write` gets a false impression of success — the "signal failure instead of faking success" intent in the RDMA handler's own comment is undermined one layer down.
- **Fix:** Make `BlockDevice.write` raise `PermissionError(errno.EROFS, ...)` when `read_only`, exactly like the two other backends; the existing `OSError` handling in `_handle_write_rdma` then produces the prompt `-1` with no handler changes.
- **Benefit:** Read-only write attempts fail on the first packet instead of after a full transfer, and all three backends share one write-failure contract.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYSMALL-05 — UDPBD `_handle_read`'s `is_raw` extent pre-check duplicates the bound both raw backends already enforce in `seek`
- **Category:** 2
- **Locations:** `udpbd_server/udpbd_server.py:208-209` (pre-check), `udpbd_server/udpbd_server.py:219-222` (the `seek(sector_nr, sector_count)` call immediately after); other side: `launcher/raw_storage.py:37-45` (`RawDevice.seek` raises `EINVAL` when the request end exceeds the device), `launcher/virtual_exfat.py:228-233` (`VirtualExfat.seek` raises `EINVAL` when the request is out of bounds)
- **Problem:** For every device where `is_raw` is true, the identical capacity check runs twice — once in the handler and once inside `seek`, which is called with the same `sector_count` a few lines later and raises the same `EINVAL`. The write path (`udpbd_server/udpbd_server.py:250-255`) proves the pre-check is unnecessary: it has none and relies on `seek` raising, converting it to a `-1` reply. Two copies of one bound are how bounds drift apart (and the file device's missing bound in PYSMALL-01 is the other half of that drift).
- **Fix:** Delete the pre-check at lines 208-209; if PYSMALL-01's unconditional check is adopted in the handlers, it subsumes this for the file device too.
- **Benefit:** One implementation of the raw-device extent bound instead of two; ~3 lines removed.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYSMALL-06 — HTTP legacy-flat profile serves symlinks that escape the games folder; the containment check exists but is only applied in the path-aware profile
- **Category:** 6
- **Locations:** `http_server/http_server.py:319-343` (`_scan_dirs`: follows a symlinked `DVD`/`CD` directory via `os.path.isdir`), `http_server/http_server.py:439-499` (`_entry_for`: flat branch never checks containment; `os.path.getsize`/`os.path.isfile` follow symlinks), `http_server/http_server.py:389-392` (`_contained`, defined once), `http_server/http_server.py:501-511` (`_path_aware_entry`: the only caller of `_contained`)
- **Problem:** The class docstring claims the index whitelist means "there is no traversal surface", and the recursive walker carefully refuses symlinked directories — but the default flat profile has no equivalent guard for files or for the `DVD`/`CD` folders themselves. EXECUTED with `GameIndex` on a scratch tree: a symlink `DVD/SLUS_999.99.Escape.iso` pointing at a file outside the games folder was indexed, listed in `games.csv`, and returned by `lookup()` with the outside file's size; a `DVD` directory that was itself a symlink to an outside folder was likewise scanned and served. The path-aware profile on the same tree correctly skipped the escape ("links outside the games folder"). Anyone who can drop a symlink into the library (sync tools, archive extraction, another app's folder) silently publishes the target file to the LAN.
- **Fix:** Apply the existing `_contained(path)` check in `_entry_for` for both profiles (it is already written and tested by the path-aware path), and skip scan directories whose real path escapes the root in `_scan_dirs`.
- **Benefit:** The flat profile — the default every Docmine17 client uses — gets the escape protection the codebase already built for the other profile; no new mechanism.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMALL-07 — HTTP flat index: path lookup serves the duplicate copy that the scan explicitly suppressed and that `games.csv` does not list
- **Category:** 6
- **Locations:** `http_server/http_server.py:543-580` (`_rebuild_flat`: `path_entries[rel_path_key] = entry` at line 564 is assigned *before* the duplicate-name `continue` at lines 567-575), `http_server/http_server.py:763-784` (`lookup`: consults `_path_entries` first, ambiguity guard applies only to the basename fallback), contrast `http_server/http_server.py:607-670` (`_rebuild_path_aware` serves only rows the catalogue retained)
- **Problem:** When the same advertised name exists in the root and in `DVD/`, the scan logs "serving X, ignoring Y", the CSV lists only X, and a bare-name lookup correctly returns `None` (ambiguous) — but a path-qualified lookup (`DVD/<name>`) returns Y, the copy that was supposedly ignored and that no catalogue row advertises. EXECUTED: root copy 1,024 B listed in the CSV; `lookup("DVD/SLUS_333.33.Same.iso")` returned the suppressed 4,096 B DVD copy. Two different clients can therefore boot two different discs for the same catalogue entry depending on how the request path is formed, contradicting the log line and the flat profile's own duplicate policy (the path-aware profile documents the opposite rule: "Only what the list advertises is served").
- **Fix:** In `_rebuild_flat`, only record `path_entries` for entries that survive duplicate suppression (move the assignment below the `seen_names` check), so suppressed copies are unreachable by path as well as by name.
- **Benefit:** One duplicate policy, consistently enforced: what the log says is ignored is actually ignored.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYSMALL-08 — HTTP dispatcher sends a 500 response after a 206 header (and possibly partial body) is already on the wire
- **Category:** 6
- **Locations:** `http_server/http_server.py:898-931` (`_dispatch`: generic `except OSError` at line 928 calls `_send_short(500, ...)`), `http_server/http_server.py:1006-1034` (`_serve_game`: sends the 206 status and headers before the body), `http_server/http_server.py:1085-1090` (`_send_bytes` raises `OSError("short read …")` after setting `close_connection`)
- **Problem:** `_send_bytes`' short-read path is carefully designed around the file's own contract — drop the connection, because a short body desynchronises the driver's fixed-count reads. But the raised `OSError` propagates into `_dispatch`, whose handler unconditionally writes a complete second response (`_send_short(500)`) onto the same socket. Those 500-header bytes land exactly where the driver is counting game bytes: the "recoverable reconnect" the `_send_bytes` comment promises becomes silent data corruption of the current read, the precise failure mode the file header says this server exists to avoid. The same applies to any `OSError` raised by `_serve_game` after `end_headers()`.
- **Fix:** Track whether response headers have been sent (e.g. a flag set in `_serve_game`/`_serve_games_csv` after `end_headers()`); in `_dispatch`'s `OSError` branch, if they have, just set `close_connection = True` and return without `_send_short`.
- **Benefit:** A mid-stream file error degrades to a reconnect-and-retry, as designed, instead of injecting a second response into the game-data stream.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (INFERRED — control flow is READ from the cited lines; the handler was not executed end-to-end over a socket)

### PYSMALL-09 — HTTP per-connection cached handle is keyed by path only, so an index refresh / file replacement is served from the stale handle with the new entry's size
- **Category:** 6
- **Locations:** `http_server/http_server.py:867-881` (`_handle_for`: cache hit iff `_cached_path == entry.path`), `http_server/http_server.py:530-541` (`refresh` rebuilds entries under the lock, with no connection-cache invalidation), `http_server/http_server.py:1043-1057` (`_send_bytes` trusts `entry.size`-derived length against whatever handle the cache returned)
- **Problem:** A long-lived keep-alive connection (the normal case — the driver issues thousands of reads down one socket) caches the open handle for a path. If the underlying file is replaced or the index is rebuilt with a different entry for the same path (e.g. a `.chd` swapped for an `.iso` of the same advertised name, or the ISO re-dumped — the exact scenario `_signature_of`'s comment says people do), the next request pairs the *new* entry's `size`/`compressed` flag with the *old* open handle. For the raw path, `sendfile` against the old descriptor with the new length either short-sends (recovered by the manual loop only until the old file's EOF, then the PYSMALL-08 path) or, if the old file was larger, streams bytes from a disc image the catalogue no longer advertises.
- **Fix:** Key the cache on the entry object identity (or `(path, size, compressed)`) instead of the path alone, so a rebuilt entry forces a reopen; the reopen cost is paid once per refresh, not per request.
- **Benefit:** A replaced game can never be half-served from its predecessor's descriptor on an existing connection.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (INFERRED)

### PYSMALL-10 — NFS: WRITE and SETATTR need no OPEN and no valid stateid — OPEN's access checks are dead letter for the write path
- **Category:** 6
- **Locations:** `nfs4_server/nfs4_server.py:761-762` (`_op_read`: `r.fixed(16)  # stateid: any`), `nfs4_server/nfs4_server.py:941-959` (`_op_write`: stateid discarded, no open/access check, writes at any offset), `nfs4_server/nfs4_server.py:961-974` (`_op_setattr`: same, truncates/extends to any size), `nfs4_server/nfs4_server.py:880-890` (`_op_close`/`_op_open_confirm` fabricate a `seqid + 1` stateid without checking one exists), `nfs4_server/nfs4_server.py:892-939` (`_op_open`: the access-mode and GUARDED checks that are thereby bypassed)
- **Problem:** EXECUTED against `Nfs4Server(allow_writes=True)` with hand-built COMPOUND records: after only PUTROOTFH + LOOKUP + GETFH (no OPEN ever issued), a WRITE carrying an all-zero stateid overwrote the file's head (`PWNED` read back from disk), and a SETATTR with a fabricated stateid extended the file to 10 MiB. Filehandles are unguessable per run (random 8-byte prefix, `_Handles` at lines 261-284), and writes still require `--allow-writes`, whose no-authentication risk is honestly documented in the module header — so this is not an exposure escalation beyond the documented model. What it does break is the server's own internal contract: `_op_open`'s share-access and create-mode validation can never constrain a write, because the write operations never consult any open state. Any future tightening added to OPEN (read-only opens, per-file policy) would silently not apply.
- **Fix:** Either track issued stateids per connection (the `_Connection` object already exists and holds per-connection file state) and require WRITE/SETATTR to present one, or — the LESS option — delete the pretence: state in `_op_open`'s comment that opens are advisory and all authorisation is the `--allow-writes` gate plus a valid filehandle. Do not leave validated-looking checks that nothing enforces.
- **Benefit:** The write path's real authorisation rule becomes explicit and auditable instead of implied by checks that are never consulted.
- **Effort:** M · **Risk:** Med · **Confidence:** High (EXECUTED)

### PYSMALL-11 — NFS `_Handles` grows without bound for the life of the server; every neighbouring table has a cap, this one has none
- **Category:** 4
- **Locations:** `nfs4_server/nfs4_server.py:261-316` (`_Handles`: `paths`/`numbers` only ever shrink via `removed`/`renamed`), `nfs4_server/nfs4_server.py:276-284` (`handle()` allocates a new number per distinct path); contrast caps in the same file: `nfs4_server/nfs4_server.py:54` (`MAX_CONNECTIONS = 32`), `nfs4_server/nfs4_server.py:820-821` (dir cache cleared at 64), `nfs4_server/nfs4_server.py:868-869` (client table evicts at 256)
- **Problem:** Every distinct path a client ever GETFHs (or READs — see PYSMALL-15) permanently consumes an entry in both dicts until that path is removed or renamed *through this server*. EXECUTED: browsing 30 files via PUTROOTFH+LOOKUP+GETFH left 31 entries (30 files + root) that nothing will ever reclaim. A long-running server browsed by file managers over a large library accumulates one entry per file ever touched — small per entry, but unbounded by design in a codebase that demonstrably caps every comparable structure.
- **Fix:** Give `_Handles` the same treatment as the client table: cap the table (e.g. evict the oldest numbers past a limit; their handles become STALE, which clients already handle by re-looking-up), reusing the eviction pattern at lines 868-869 rather than inventing a new one.
- **Benefit:** Handle-table memory becomes a bounded constant like every other long-lived table in the server.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED — growth; the unbounded-by-design conclusion is READ)

### PYSMALL-12 — NFS: one global generation counter means any single write invalidates every connection's read handles and every cached directory listing
- **Category:** 5
- **Locations:** `nfs4_server/nfs4_server.py:683-687` (`_changed` bumps the single `self.generation`), `nfs4_server/nfs4_server.py:941-959` (`_op_write` calls `_changed()` with no path), `nfs4_server/nfs4_server.py:761-781` (`_op_read`: cached handle discarded whenever `cached[0] != self.generation`), `nfs4_server/nfs4_server.py:797-822` (`_listing`: cache valid only for the current generation)
- **Problem:** Correctness is preserved, but the invalidation granularity is the whole server: one client writing one file closes and reopens the cached read handles of *all* connections (up to 4 per connection) on their next read and drops all 64 directory-listing cache slots' validity. During mixed read/write workloads (e.g. a file manager copying into the share while a console streams from it) the caches the code deliberately built — with comments explaining the Windows rename and burst-read motivations — are effectively always cold.
- **Fix:** Key the generation per path/comps (a dict of counters, defaulting to 0) and have `_changed(comps)` bump only the affected path and its parent directory's listing; `_op_write` already knows its `comps`.
- **Benefit:** Read-handle and listing caches survive unrelated writes, which is the common case they were built for.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### PYSMALL-13 — NFS `_op_close` and `_op_open_confirm` are byte-identical bodies under two names
- **Category:** 2
- **Locations:** `nfs4_server/nfs4_server.py:880-884` (`_op_open_confirm`), `nfs4_server/nfs4_server.py:886-890` (`_op_close`)
- **Problem:** Both operations parse a stateid, bump its seqid by one, check a current filehandle exists, and return the result — the same five lines twice, registered as separate entries in the ops table (lines 365-379). Any change to the fabricated-stateid behaviour (see PYSMALL-10) must currently be made in two places, and the two copies can drift into subtly different state handling for two operations clients use in sequence.
- **Fix:** Extract the shared five lines into one private helper (e.g. `_seqid_reply(r, s)`) and have both op methods call it; the ops-table entries stay separate.
- **Benefit:** One implementation of stateid-seqid handling; ~5 lines removed.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYSMALL-14 — `_stop_on_sigterm` is duplicated between the HTTP and NFS entry points (and has already drifted)
- **Category:** 2
- **Locations:** `http_server/http_server.py:1220-1237`, `nfs4_server/nfs4_server.py:1101-1113`
- **Problem:** The executable code of the two copies is identical (verified by diff); only the HTTP copy has acquired a docstring the NFS copy lacks — the copies are already drifting in the small, which is how the behavioural notes in that docstring (SIGTERM semantics per platform) end up documented for one server and not the other. Both servers already reach outside their own directory for shared code (HTTP imports `launcher.session_stats` at line 47; NFS inserts `smb2_server` into `sys.path` at lines 40-43), so "standalone file" is not the reason for the duplication.
- **Fix:** Move the function into a module both already can import (the `launcher` package HTTP already depends on) and import it in both; keep the docstring with the single copy.
- **Benefit:** One SIGTERM-handling implementation and one place for its platform caveats; ~13 lines removed.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ, diff-verified)

### PYSMALL-15 — NFS PUTFH resolves the handle number and throws it away; READ and READDIR then re-derive it through the mutating `handle()` on the hot path
- **Category:** 5
- **Locations:** `nfs4_server/nfs4_server.py:728-733` (`_op_putfh`: `self.handles.lookup(fh)[1]` — keeps comps, discards the number), `nfs4_server/nfs4_server.py:336-343` (`_Compound` stores only comps in `cfh`/`sfh`), `nfs4_server/nfs4_server.py:761-766` (`_op_read`: `self.handles.handle(comps)` then unpacks the number back out), `nfs4_server/nfs4_server.py:825-835` (`_op_readdir`: same re-derivation)
- **Problem:** Every READ and READDIR pays a locked dict lookup-or-*insert* (`handle()` takes `_Handles.lock` and mutates both dicts when the path is new) purely to recover a number the server already had when the client presented the filehandle. It also means pure read traffic can grow the handle table (compounding PYSMALL-11) for paths that were resolved from a handle the client supplied. The compound state object is the natural home for the number — it already exists to carry per-compound state.
- **Fix:** Store `(number, comps)` in `_Compound.cfh`/`sfh` at PUTFH/PUTROOTFH time and have READ/READDIR use the stored number; `handle()` then runs only in GETFH, where allocation is the point.
- **Benefit:** The streaming hot path stops taking a global lock and mutating shared tables per operation; handle allocation happens only where a handle is actually issued.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### PYSMALL-16 — NFS is the only server without the shared `--session-summary` feature
- **Category:** 8
- **Locations:** `nfs4_server/nfs4_server.py:1045-1064` (`build_parser`: no `--session-summary`), `nfs4_server/nfs4_server.py:1067-1099` (`main`: no `SessionStats` wiring, no stats object on `Nfs4Server`); present in scope at `http_server/http_server.py:1155-1159,1183` and `udpbd_server/udpbd_server.py:400-402,443-449` (both via the shared `launcher.session_stats.SessionStats`)
- **Problem:** The session-summary mechanism is shared infrastructure ("shared by every server" is the HTTP import's own comment) and is wired into the HTTP and UDPBD entry points in this scope — grep confirms zero occurrences of `session` in `nfs4_server.py`. An operator running the launcher's session view gets per-console lines for the other protocols and a silent gap for NFS, with nothing in the NFS docs surface (parser help) saying the omission is deliberate. This is a half-finished rollout of an existing feature, not a request for a new one.
- **Fix:** Either wire NFS the same way the other two in-scope servers do (construct `SessionStats("nfs")` under the same flag and record connection/read/write events at the points `_serve`/`_op_read`/`_op_write` already identify), or state the exclusion explicitly in the parser help/README so the gap reads as a decision. The wiring option reuses the existing shared class and adds no new abstraction.
- **Justification:** The fix completes an already-built, already-shared mechanism in the one server that lacks it; no new subsystem is introduced.
- **Benefit:** Uniform per-console session reporting across all servers the launcher runs.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ, grep-verified absence)

---

## Notes on categories with no findings

- **Category 1 (dead code), 3 (overengineering), 7 (build/CI/clutter):** a scripted AST census of all top-level functions, classes, methods, and constants in the three servers found no symbol with zero references (framework-invoked methods such as `do_GET`/`do_HEAD` and the NFS ops-table handlers account for the apparent single-mention cases). No tracked `__pycache__` or other clutter exists in the three directories (`git ls-files` shows exactly the 5 expected files), and `udpbd_server/selftest.py` is wired into CI (`.github/workflows/ci.yml:131-132`). NFS's large NFS4ERR constant block is wire vocabulary referenced through the errno/status maps, not dead code. Nothing honest to file in these categories.
- **Checked and deliberately not filed:** HTTP `_parse_range` rejecting suffix ranges and `end >= total` with 416 (documented, driver-motivated, `http_server.py:985-1004`); NFS record-mark accounting in `_read_record` (the `MAX_RECORD` check at `nfs4_server.py:498-520` runs *before* the fragment allocation, so a hostile fragment length cannot force a large allocation); UDPBD WRITE_RDMA's truncation and `_write_left` clamping (`udpbd_server.py:277-285` — correct as written); NFS READDIR cookie/budget handling (`nfs4_server.py:825-855` — `TOOSMALL` behaviour verified by reading); the global `fs_lock` serialising COMPOUNDs (documented correctness tradeoff, `nfs4_server.py:356-360`).

## Files read

- `udpbd_server/udpbd_server.py` (462 lines, full)
- `udpbd_server/selftest.py` (179 lines, full)
- `udpbd_server/SOURCE.md` (full)
- `http_server/http_server.py` (1,237 lines, full)
- `nfs4_server/nfs4_server.py` (1,113 lines, full)
- `AGENTS.md` (repo root, full — house rules)
- Cross-reference excerpts only (not audited): `launcher/raw_storage.py:1-130`, `launcher/virtual_exfat.py:55-80,220-340`, `launcher/session_stats.py` (grep: `IDLE_SECONDS`, `SessionStats`), `smb2_server/smb2_paths.py` (grep: `Share`, `resolve`, `_inside`, `check_component` locations), `.github/workflows/ci.yml:131-141` (grep)

## Files not read (in scope)

- None. All in-scope `.py` files (`udpbd_server/udpbd_server.py`, `udpbd_server/selftest.py`, `http_server/http_server.py`, `nfs4_server/nfs4_server.py`) were read in full. The only other in-scope file, `udpbd_server/SOURCE.md`, was also read. (`__pycache__/*.pyc` binaries under the three directories are untracked build artifacts, not source, and were not read.)
