# PS2-Servers — Python UDPFS server (blind redo audit)

- **Clone:** `~/workspace/audit-clones-2026-11-13/PS2-Servers` @ `c5f021c4d38698860f56b03498adc261dbb8d8dd` (verified via `git rev-parse HEAD`)
- **Method:** every in-scope file read in full from code only. Executions ran in `/tmp/pyudpfs/` copies of `udpfs_server/`, never in the clone. `multiclient_selftest.py` cannot run in this sandbox: its first loopback send fails with `PermissionError: [Errno 1] Operation not permitted` — that is **BLOCKED-ENV** (sandbox UDP `sendto` block), not a repo defect; all other probes are in-process handler calls, which need no UDP.
- **Context note:** `ps2servers_core.AutoUdpfsServer` subclasses `UdpfsServer` and overrides only six methods (per the docstring at `udpfs_server.py:1569-1585`), so every opcode-handler finding below also applies to the launcher-run server. `ps2servers_core.py` itself is another worker's scope and was not audited; it was grepped only for cross-references to symbols in this scope.

**Headline:** the transfer-size caps, path containment (`_resolve_path` / `_resolve_entry` / `_through_linked_folder`), `writable()` gate, and session caps are genuinely well built and well commented. The remaining holes are concentrated in (a) paths the caps don't reach — sector ranges, chunk headers, compressed-image headers — and (b) error paths that turn an `OSError` with `errno=None`, or a `None` path, into an unhandled exception and a silently unanswered request.

---

### PYUDPFS-01 — GETSTAT on a symlink pointing outside the root raises TypeError and sends no reply
- **Category:** 6
- **Locations:** `udpfs_server/udpfs_server.py:2294-2356` (`_handle_getstat`; the fall-through `os.stat(resolved)` is at line 2356)
- **Problem:** `_handle_getstat` computes `real_file_exists = (resolved is not None and os.path.exists(resolved)) or real_entry_exists`, where `real_entry_exists` is `os.path.lexists()` of the `_resolve_entry()` path. For a symlink inside the root whose target is outside it, `_resolve_path()` returns `None` (containment correctly refuses the target) but `lexists()` on the link itself is `True`, so the handler skips the ENOENT/EACCES branch and calls `os.stat(None)`. That raises `TypeError`, which the `except OSError` around it does not catch; the session worker's generic catch logs it and the client is never answered — it waits out its own timeout. EXECUTED in-process: `GETSTAT /link.bin` (link → file in a temp dir outside the root) raised `TypeError: stat: path should be string, bytes, os.PathLike or integer, not NoneType`; `_resolve_path -> None`, `_resolve_entry -> <root>/link.bin`. A dangling symlink to an *inside* target works (stat raises `OSError`, answered), so only the outside-target case crashes. `_handle_open` does not have this bug — it refuses when `resolved is None` and no compressed/virtual alias resolved.
- **Fix:** in `_handle_getstat`, after the not-found branch, if `resolved is None` send `-errno.EACCES` and return (mirroring `_handle_open`'s existing guard).
- **Benefit:** an ordinary library layout (a link whose target share is unmounted or outside the served folder) stops hanging the console's stat call.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYUDPFS-02 — BREAD/BWRITE never validate the sector range against the device or file size; BWRITE past the end extends the host image and reports success
- **Category:** 6
- **Locations:** `udpfs_server/udpfs_server.py:2483-2549` (`_handle_bread`), `udpfs_server/udpfs_server.py:2551-2630` (`_handle_bwrite_req`), `udpfs_server/udpfs_server.py:2156-2187` (`_complete_bwrite`), `udpfs_server/udpfs_server.py:862-880` (`bd_read`/`bd_write`); `bd_sector_count` is computed at `udpfs_server/udpfs_server.py:807` but used only for the startup banner (line 1055) and the GETSTAT capacity reply (line 2307)
- **Problem:** both handlers cap the *byte count* (`max_transfer_bytes`) and refuse offsets past 2⁶³−1, but neither compares `sector_nr + sector_count` against `bd_sector_count` (handle 0) or the backing file's sector count (other handles). EXECUTED in-process against a 4-sector (2,048-byte) image: `BWRITE_REQ sector=100 count=1` plus one chunk returned `WRITE_DONE 0` and grew the host image file from 2,048 to 51,712 bytes via `pwrite` past EOF. Repeated out-of-range writes let any unauthenticated LAN peer grow/sparsify the image file arbitrarily (one ≤8 MiB write per request, unbounded count of requests) and write into space the console believes is a fixed-size device. BREAD past the end is the benign mirror: it silently returns a short/empty read instead of an error.
- **Fix:** in `_handle_bread` and `_handle_bwrite_req`, when `handle == BLOCK_DEVICE_HANDLE` refuse `sector_nr + sector_count > self.bd_sector_count` with `-errno.EINVAL`; for file handles, refuse a BWRITE range past the handle's current size in sectors the same way.
- **Benefit:** the block device the server advertises (its sector count is already computed and already told to clients via GETSTAT) becomes the actual bound; closes an unauthenticated disk-fill path.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYUDPFS-03 — WRITE_DATA trusts the chunk header: `chunk_size` is never checked against the datagram, `total_chunks` is re-read from every chunk, and BWRITE completion reports success for short data
- **Category:** 6
- **Locations:** `udpfs_server/udpfs_server.py:2083-2140` (`_handle_write_data`; slice at line 2090, buffer extend at 2122, `write_total_chunks` overwritten at 2123), `udpfs_server/udpfs_server.py:2031-2081` (`_handle_write_req`; declared `size` is checked against the cap only and never stored), `udpfs_server/udpfs_server.py:2156-2187` (`_complete_bwrite`)
- **Problem:** `chunk_data = payload[8:8 + chunk_size]` silently truncates when the datagram carries fewer bytes than `chunk_size` claims, and the truncated chunk still counts as received. Completion is decided by chunk *count* (`write_received_chunks >= total_chunks`, with `total_chunks` taken from the most recent chunk, so a sender can shrink or extend the transfer mid-write), never by byte count against the size declared in WRITE_REQ or the `sector_count × sector_size` declared in BWRITE_REQ. EXECUTED in-process: (a) a file WRITE whose single chunk claimed `chunk_size=8` but carried 3 bytes completed and wrote the 3 bytes with no error; (b) a BWRITE declaring 4 sectors (2,048 bytes) but delivering one 100-byte chunk returned `WRITE_DONE 0` (success), wrote 100 bytes, and credited `stats['bytes_written']` with the full 2,048 (`_complete_bwrite` adds `expected_size` unconditionally and always replies 0). A lost/truncated final datagram therefore corrupts a save or image silently instead of failing the write.
- **Fix:** in `_handle_write_data`, drop/refuse the chunk when `len(payload) - 8 < chunk_size`; latch `total_chunks` from the first chunk; at completion require `len(write_data)` to equal the declared size (WRITE_REQ) or `expected_size` (BWRITE) and answer `-errno.EIO` otherwise.
- **Benefit:** short or lying transfers fail loudly at WRITE_DONE instead of persisting truncated data as a successful write.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYUDPFS-04 — Block-device handle 0 is one shared file object with one shared cursor across all sessions for READ, LSEEK and file-WRITE
- **Category:** 6
- **Locations:** `udpfs_server/udpfs_server.py:3212-3213` (every `Session` inserts the *same* `server.bd_fh` FileHandle as handle 0), `udpfs_server/udpfs_server.py:1996` (`_handle_read`: `fh.obj.read(size)`), `udpfs_server/udpfs_server.py:2206` (`_handle_lseek`: `fh.obj.seek(offset, whence)`), `udpfs_server/udpfs_server.py:2144` (`_complete_write`: `fh.obj.write(data)`)
- **Problem:** BREAD/BWRITE on handle 0 correctly use the positional, lock-aware `bd_read`/`bd_write` (lines 862-880), but READ, LSEEK and WRITE_REQ-style writes on the same handle go through the shared object's own file position, which no lock guards and every session shares. EXECUTED in-process with two sessions on one 4-sector image: session B read 512 bytes (sector 0), session A then LSEEKed handle 0 to sector 3, and session B's next READ returned sector 3's bytes instead of sector 1's. On hosts without `pread`/`pwrite` the same cursor is also what the `bd_lock` fallback in `bd_read`/`bd_write` seeks, so an LSEEK can land between another session's seek and read there too. Two consoles using the block device through the file opcodes corrupt each other's stream position deterministically.
- **Fix:** special-case handle 0 in `_handle_read`/`_handle_lseek`/`_complete_write` the way BREAD/BWRITE already do — track a per-session cursor for handle 0 and serve it via `bd_read`/`bd_write` — or refuse file-opcode access to handle 0 with `-errno.EBADF` since the block opcodes cover it.
- **Benefit:** per-client isolation, the property the multi-client refactor exists for, stops leaking through the oldest handle in the table.
- **Effort:** M · **Risk:** Med · **Confidence:** High (EXECUTED)

### PYUDPFS-05 — No writer exclusion anywhere: two sessions can hold the same file open writable and interleave writes
- **Category:** 6
- **Locations:** `udpfs_server/udpfs_server.py:1923-1928` (`_handle_open` opens a fresh OS handle per session, no per-path registry), `udpfs_server/udpfs_server.py:784-786` (the only locks in the file are `sessions_lock`, `send_lock`, `bd_lock` — census by grep)
- **Problem:** read-only semantics are enforced (global `read_only` flag plus the per-handle `writable()` gate), and no file in scope *claims* single-writer semantics — but none is provided either. Any two consoles (or one console twice) can OPEN the same path `r+b`, and their writes land at independent cursors with no error to either; the same is true of handle 0 via PYUDPFS-04's file-WRITE path. For game saves and VMC images — the writable files this server exists to serve — that is silent interleave corruption with both clients told the writes succeeded. This is filed as a semantics gap, not a violated claim: if multi-writer is intended, it is currently indistinguishable from an accident.
- **Fix:** keep a server-level dict of paths with a writable handle open (populated in `_handle_open`, cleared on close/reap); refuse a second writable open of the same resolved path with `-errno.EBUSY`. Read opens stay unrestricted.
- **Justification:** the addition is one dict and one check on an existing path, and it is the only thing that makes the existing read-only/`writable()` story coherent for the multi-client server this file now is.
- **Benefit:** second writer gets an immediate, diagnosable refusal instead of both writers corrupting the file.
- **Effort:** M · **Risk:** Med · **Confidence:** Med (READ)

### PYUDPFS-06 — READ/BREAD on a handle that is not open for reading crashes the reply: `-e.errno` on an errno-None exception
- **Category:** 6
- **Locations:** `udpfs_server/udpfs_server.py:1969-2010` (`_handle_read` and its `except OSError` reply), `udpfs_server/udpfs_server.py:2483-2549` (`_handle_bread`, same pattern), `udpfs_server/udpfs_server.py:1469-1495` (`_flags_to_mode` returns `'wb'`/`'ab'` for O_WRONLY|O_TRUNC / O_APPEND), `udpfs_server/udpfs_server.py:554-590` (`FileHandle` has `writable()` but no readable counterpart)
- **Problem:** writes are pre-gated by `writable()` precisely because an `io.UnsupportedOperation` has `errno is None` (the class comment at lines 566-590 says so), but reads have no symmetric gate. EXECUTED in-process: OPEN a file with O_WRONLY|O_TRUNC (mode `'wb'`), then READ_REQ — `fh.obj.read()` raised `io.UnsupportedOperation`, the handler logged it and then itself raised `TypeError: bad operand type for unary -: 'NoneType'` computing `-e.errno` for the error reply. No reply is sent; the console waits out its timeout. The same `-e.errno` shape appears in `_handle_bread`'s except clause (an `'ab'`-mode handle BREAD hits it via seek+read).
- **Fix:** cheapest correct step: in the READ/BREAD except clauses send `-(e.errno or errno.EIO)`. Better, and symmetric with the existing write gate: add a `readable()` check next to `writable()` and refuse non-readable handles with `-errno.EACCES` before touching the object.
- **Benefit:** a mode-confused or hostile client gets an error reply instead of a hung request and a thread traceback.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYUDPFS-07 — Serving-path compressed wrappers trust header geometry without bounds; the limits module only protects the opt-in inspection path
- **Category:** 6
- **Locations:** `udpfs_server/compressed_iso/cso.py:54-89` (only validation is `block_size == 0`; offset table read of `(_num_blocks + 1) * 4` bytes at line 84), `udpfs_server/compressed_iso/zso.py:64-107` (`header_size`, `align`, version byte all taken from the file unchecked), `udpfs_server/compressed_iso/chd.py:262-314` (only `hunk_size == 0` checked; `ctypes.create_string_buffer(hunk_size)` at line 314), `udpfs_server/compressed_iso/base.py:134-168` (block cache evicts by block *count*, so cache memory is `cache_size × block_size` with `block_size` attacker-chosen), `udpfs_server/udpfs_server.py:364-387` (`open_compressed` never passes `strict`), `udpfs_server/compressed_iso/limits.py:12-15` (the `MAX_DISC`/`MAX_BLOCK`/`MAX_TABLE`/`MAX_DECODE` caps that exist but do not apply here)
- **Problem:** the server decompresses whatever images sit in the served library — files the user downloaded — triggered by unauthenticated console requests, yet the non-strict parse paths validate almost nothing the header claims. EXECUTED in-process: a 24-byte file containing only a CSO header claiming 64 GiB uncompressed with 2,048-byte blocks made `CsoFileWrapper` allocate **134.2 MB** (tracemalloc peak) reading its "offset table" before failing as truncated; the allocation scales linearly with the claimed size (a claim near 2⁶⁴ requests an exabyte-scale read and dies as `MemoryError`, which `_handle_open`'s `except (ImportError, ValueError, OSError, struct.error)` does not catch). ZSO has the same table construction; CHD turns a header `hunk_size` into a ctypes buffer; the base cache multiplies the same unchecked `block_size` by 32 entries. `limits.py` already contains the right ceilings, but they run only when `strict=True` — i.e. for launcher metadata inspection, not for the network serving path.
- **Fix:** enforce the numeric ceilings (uncompressed size, block/hunk size, table bytes — the `limits.py` constants) inside the non-strict `_parse_header` implementations as well. Do not import the inspection path wholesale: its format restrictions (version, sector alignment) are deliberately stricter than serving compatibility allows; only the resource ceilings transfer.
- **Benefit:** a crafted or corrupt image in the library costs a refused OPEN instead of a memory blow-up of the whole server process.
- **Effort:** M · **Risk:** Med · **Confidence:** High (EXECUTED for the CSO leg; READ for ZSO/CHD/cache legs)

### PYUDPFS-08 — ZSO decompression retries once per input byte: a garbage block costs one LZ4 attempt per byte of input
- **Category:** 6
- **Locations:** `udpfs_server/compressed_iso/zso.py:165-171` (retry loop slicing `compressed_data[:-1]`), contrast `udpfs_server/compressed_iso/limits.py:78-90` (`indexed_block` caps the same retry at the alignment padding, with a comment naming this exact hazard)
- **Problem:** the serving ZSO path handles trailing alignment padding by retrying `lz4.block.decompress` after removing one byte at a time, with no bound. EXECUTED in-process: a single 20,000-byte garbage block produced **19,990 LZ4 decompress attempts** in 0.48 s before failing. Cost grows ~quadratically with block size (attempts × shrinking input), and `block_size` itself is header-controlled (PYUDPFS-07), so one READ against a crafted .zso can pin a session worker — and with a large claimed block, the CPU — for minutes. The in-tree inspection path already fixed this exact problem ("Never retry once per byte of an attacker-controlled, potentially megabyte-sized span"); the fix was never carried to the path that serves the wire.
- **Fix:** bound the retry loop exactly as `indexed_block` does: at most `(1 << align) - 1` padding bytes (63 maximum in practice), then raise `ValueError`.
- **Benefit:** worst case per bad block drops from O(n²) decompression attempts to at most 64.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### PYUDPFS-09 — Compressed block offsets are never validated in the serving path, and short/corrupt blocks are silently fabricated into data
- **Category:** 6
- **Locations:** `udpfs_server/compressed_iso/cso.py:115-150` (`read_size = next_offset - offset` at line 124, unchecked; short deflate output zero-padded at lines 148-150), `udpfs_server/compressed_iso/zso.py:125-163` (same next-offset arithmetic; the uncompressed branch returns the raw read as-is however short), `udpfs_server/compressed_iso/base.py:53-97` (`read()` advances `self.pos += read_size` at line 95 even when the block slice at line 94 delivered fewer bytes)
- **Problem:** three integrity holes share one mechanism — nothing checks a block's on-disk span or decoded length outside strict mode. (1) Non-monotonic CSO/ZSO offset tables make `read_size`/`compressed_size` negative, and `file.read(negative)` reads to end-of-file, pulling the whole remainder of the image into memory for one block. (2) A compressed CSO block that inflates to less than `block_size` is zero-padded and served as if valid (padding is correct only for the final block), so corruption mid-image reads back as zeros instead of an error. (3) A short raw (uncompressed-flag) ZSO block returns short, and `base.read()` still advances the position by the full `read_size`, so the reply is short *and* the stream skips the missing bytes. The strict path (`limits.indexed_block`) validates every one of these — span inside the file, decoded length within `[expected, block_size]` — which is an admission of the invariant the serving path skips.
- **Fix:** in both wrappers' `_decompress_block`, refuse `read_size < 0` or a span past end-of-file, and raise `ValueError` when a non-final block decodes short instead of padding it; in `base.read()`, advance by the number of bytes actually appended.
- **Benefit:** corrupt images fail the read (EIO to the console, visible in the log) instead of silently serving zeros and gaps into a running game.
- **Effort:** M · **Risk:** Low · **Confidence:** Med (READ)

### PYUDPFS-10 — Compressed-header parsing is triplicated: the size probe, the three wrappers, and the limits module each parse the same headers, including the CD-CHD size correction twice
- **Category:** 2
- **Locations:** `udpfs_server/udpfs_server.py:390-479` (`get_compressed_info`, incl. the CD-frame correction at lines 425-440), `udpfs_server/compressed_iso/chd.py:262-303` (the same CD predicate and correction in `ChdFileWrapper._parse_header`), `udpfs_server/compressed_iso/cso.py:54-89` and `udpfs_server/compressed_iso/zso.py:64-107` (wrapper header parses duplicating the probe's magic/size extraction), `udpfs_server/compressed_iso/limits.py:19-116` (a third parse of the same CSO/ZSO/CHD headers for inspection)
- **Problem:** the CD-CHD correction in `get_compressed_info` carries a comment that it must use "the same predicate as the CHD wrapper … so the size reported here can never disagree with what the read path extracts" — i.e. the duplication is load-bearing and maintained by hand across two files, with a third implementation of the header rules in `limits.py`. The file's own history (comments at `udpfs_server.py:78-113`) records a previous listing bug caused by exactly this kind of drift between the stat path and the open path. Every future format tweak (a codec id, a header field) must currently be made in two or three places or the listing size and the served size diverge.
- **Fix:** make `get_compressed_info` obtain its answer from the wrapper layer — open the wrapper, read `uncompressed_size`, close — or extract one shared header-parse helper the probe and the wrappers both call; delete the duplicated CD correction from one side. (The probe is on listing/stat paths, so keep it allocation-light: parse header fields only, as today, but from one implementation.)
- **Benefit:** one place defines what a format's size is; the class of bug the file already shipped once cannot recur by drift.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### PYUDPFS-11 — `tx_start_seq` is write-only dead state
- **Category:** 1
- **Locations:** `udpfs_server/udpfs_server.py:845` (session-proxy property), `udpfs_server/udpfs_server.py:1690`, `udpfs_server/udpfs_server.py:2966`, `udpfs_server/udpfs_server.py:3001`, `udpfs_server/udpfs_server.py:3208` (`Session.__init__` field)
- **Problem:** grep census of the whole file: five writes, zero reads. Nothing ever consumes the value; it is bookkeeping maintained in the two hottest send paths (`_send_raw_data`, `_send_raw_data_with_header`) for no reader. (One more assignment exists in `ps2servers_core.py:151` — outside this scope, flagged for that worker; deleting the field here requires dropping that line too.)
- **Fix:** delete the property, the `Session` field, and the three assignments in this file.
- **Benefit:** less per-session state to reason about in the retransmit logic, where unused sequence fields are actively misleading.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ, grep-verified)

### PYUDPFS-12 — `_optimal_chunk_size` computes an "optimum" that is always 1408
- **Category:** 3
- **Locations:** `udpfs_server/udpfs_server.py:2746-2767` (definition), callers at `udpfs_server/udpfs_server.py:2968` and `udpfs_server/udpfs_server.py:3003`
- **Problem:** the candidate loop can never change its answer. `best` starts at chunk 1408 with `ceil(total/1408)` packets; the 1024- and 1280-byte candidates always need *more* packets, and the 1408 candidate ties on packets while its alignment (128) is not `>` the incumbent's 128. For every input, including 0, the method returns 1408 — which is already the named constant `MAX_DATA_PAYLOAD`. The loop, the `math.ceil` calls and the "DMA efficiency" framing are machinery around a constant. One external seam exists: `tests/test_session_summary.py:296` monkeypatches the method to force 1024-byte chunks (outside this scope; the fix must keep or relocate that seam).
- **Fix:** replace both call sites with `MAX_DATA_PAYLOAD` and delete the method, moving the test's patch point to the constant's consumer if the seam is still needed.
- **Benefit:** ~20 lines of misleading optimisation removed from the send path; chunk size becomes greppable as the protocol constant it is.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYUDPFS-13 — Router-status replies never set FLAG_UDPBD or FLAG_DECOMPRESSES, even when the server serves a block device / decompresses
- **Category:** 6
- **Locations:** `udpfs_server/udpfs_server.py:1563-1567` (`_status_flags`), `udpfs_server/router_status.py:66-70` (flag definitions)
- **Problem:** `_status_flags()` starts from `FLAG_UDPFS` and adds only `FLAG_READ_ONLY`. The protocol defines `FLAG_UDPBD` and `FLAG_DECOMPRESSES` and the server knows both facts (`self.bd_fh is not None`, `self.enable_compression` plus a non-empty `COMPRESSED_EXTENSIONS`), but never reports them, so a launcher/dashboard polling status cannot distinguish a file-only server from a block-device one — the distinction the flags exist to carry. `STATE_BUSY`/`STATE_DEGRADED` in the same module *are* computed from real state, so this reads as an unfinished corner rather than a protocol decision.
- **Fix:** set `FLAG_UDPBD` when `self.bd_fh is not None` and `FLAG_DECOMPRESSES` when compression is enabled and at least one format is available.
- **Benefit:** status consumers get the capability bits the protocol already reserves; no wire change.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYUDPFS-14 — MKDIR passes the wire `mode` to `os.mkdir` unsanitised
- **Category:** 6
- **Locations:** `udpfs_server/udpfs_server.py:2370-2392` (`_handle_mkdir`; `os.mkdir(resolved, mode if mode else 0o755)` at line 2392)
- **Problem:** `mode` is a raw uint16 from the request. It is passed to `os.mkdir` masked only by the process umask, so the special bits survive: an unauthenticated client can create setgid (0o2000) or sticky directories anywhere in the served root. Impact is small — the client can already create and delete plain directories — but it is the one place a wire field reaches a filesystem permission verbatim, and setgid directories change group-inheritance semantics for everything later written under them by the *host* user.
- **Fix:** `os.mkdir(resolved, (mode & 0o777) if mode else 0o755)`.
- **Benefit:** directory creation stays inside the permission model the console protocol actually has (plain rwx bits).
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYUDPFS-15 — LSEEK whence handling disagrees by handle type: the compressed wrapper silently accepts any whence
- **Category:** 6
- **Locations:** `udpfs_server/compressed_iso/base.py:99-127` (`CompressedFileWrapper.seek` has branches for whence 0/1/2 and no error case), contrasted with `udpfs_server/udpfs_server.py:2189-2230` (`_handle_lseek` maps `ValueError` from plain files to EINVAL) and `udpfs_server/compressed_iso/chd_cuebin.py:300-311, 371-385` (`MemoryFile.seek`/`ChdBinFile.seek` do raise on bad whence)
- **Problem:** the same LSEEK_REQ with `whence=3` (or 99) is EINVAL against a plain file, EINVAL against a virtual CUE/BIN view, but a silent success returning the clamped current position against a CSO/ZSO/CHD wrapper — the handler's `ValueError` arm can never fire for the wrapper because the wrapper never raises. A client probing SEEK_DATA/SEEK_HOLE-style behaviour, or simply sending a corrupt whence, gets three different protocols depending on which file it opened. The wrapper also clamps seeks past EOF to `uncompressed_size` where plain files report the true overshot position, a second, quieter divergence in the same method.
- **Fix:** raise `ValueError` in `CompressedFileWrapper.seek` for whence outside (0, 1, 2), letting the existing handler mapping answer EINVAL uniformly.
- **Benefit:** one LSEEK contract for every handle type; corrupt requests are visible as errors instead of plausible-looking positions.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### PYUDPFS-16 — Every directory listing and GETSTAT re-opens and re-parses every compressed image's header — and every CD CHD's whole track table
- **Category:** 5
- **Locations:** `udpfs_server/udpfs_server.py:1745-1790` (`_prepare_directory_entries` calls `_get_compressed_stat` per compressed entry), `udpfs_server/udpfs_server.py:1388-1405` (`_get_compressed_stat`), `udpfs_server/udpfs_server.py:390-479` (`get_compressed_info` opens the file and, for CD CHDs, calls `exact_cd_iso_size`), `udpfs_server/compressed_iso/chd.py:215-240` (`exact_cd_iso_size` opens the file again and walks the metadata chain via `read_track_table`)
- **Problem:** nothing is cached between calls. One DOPEN of a directory with N compressed games costs N file opens + header parses, and for each CD-format CHD two opens plus a full track-table parse — repeated identically on every listing refresh and every GETSTAT, which OPL issues constantly while browsing. On the low-power/router hosts this server targets, listing a large CHD library is the hot path, and it is currently O(directory) parses per refresh with zero reuse. (INFERRED from the call graph; no timing was executed.)
- **Fix:** memoise `get_compressed_info` results keyed by `(path, st_mtime_ns, st_size)` in a small dict on the server; the stat data needed for the key is already in hand at both call sites.
- **Justification:** the cache is justified only because the same immutable-file parse is repeated per listing; keying on mtime+size keeps it honest when a file is replaced, and it removes work rather than adding a subsystem.
- **Benefit:** repeat listings of an unchanged library become stat-only; first listing cost unchanged.
- **Effort:** M · **Risk:** Low · **Confidence:** Med (INFERRED)

### PYUDPFS-17 — Selftest blind spots: skipped sections still print ALL PASSED on POSIX, and no in-scope selftest exercises a single write opcode or hostile wire input
- **Category:** 7
- **Locations:** `udpfs_server/pathguard_selftest.py:190-192` (UNC section prints "skipped" and returns), `udpfs_server/pathguard_selftest.py:237` (unconditional `ALL UDPFS PATH-GUARD TESTS PASSED`), `udpfs_server/pathguard_selftest.py:155-185` (separator-root test uses `/` as the root on POSIX, where every absolute path is trivially "inside"), `udpfs_server/multiclient_selftest.py` (whole file), `udpfs_server/compression_selftest.py` (whole file)
- **Problem:** the three selftests are substantive — they assert exact bytes, sizes, errno values and gating behaviour, they run in CI, and other suites import them as fixture/client libraries; pathguard and compression were EXECUTED green in `/tmp` during this audit (multiclient is BLOCKED-ENV here, see header). Two blind spots remain. (1) On POSIX — the CI platform — the UNC-root and Windows-reinterpreted-name sections skip silently and the separator-root test degenerates (root `/` makes the containment assertions vacuous), yet the run still ends with ALL PASSED; the Windows-only containment cases are exactly the ones guarding the field-reported UNC regression the file's docstring leads with. (2) Coverage census by grep: **zero** mentions of `BWRITE`/`WRITE_REQ`/`WRITE_DATA` across all three selftests — the entire write path (WRITE_REQ/WRITE_DATA/BWRITE) has no selftest coverage, and none of the hostile-input cases behind PYUDPFS-01/02/03/06/07/08 (outside-symlink GETSTAT, out-of-range BWRITE, lying chunk header, write-only-handle READ, crafted compressed headers) is exercised anywhere in scope. Handler-level write tests do exist in the main `tests/` tree (another scope), so this is a gap in the *selftest* layer specifically — the layer a user is told to run standalone.
- **Fix:** print `SKIPPED` sections in the final summary (and don't count them toward ALL PASSED on POSIX); add handler-level cases to `multiclient_selftest.py`'s Driver-style harness or a small fourth section in `compression_selftest.py` for the six hostile cases above — they are all in-process and need no UDP.
- **Benefit:** a green selftest run means the same thing on every platform, and the write path gets the same regression net the read path already has.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ + EXECUTED for the green runs and the grep census)

---

## Files read

Full reads (every line):

- `udpfs_server/udpfs_server.py` (3,643 lines)
- `udpfs_server/compressed_iso/__init__.py` (12 lines)
- `udpfs_server/compressed_iso/base.py` (196 lines)
- `udpfs_server/compressed_iso/chd.py` (334 lines)
- `udpfs_server/compressed_iso/chd_cuebin.py` (567 lines)
- `udpfs_server/compressed_iso/cso.py` (152 lines)
- `udpfs_server/compressed_iso/limits.py` (116 lines)
- `udpfs_server/compressed_iso/zso.py` (173 lines)
- `udpfs_server/compression_selftest.py` (545 lines)
- `udpfs_server/multiclient_selftest.py` (643 lines)
- `udpfs_server/pathguard_selftest.py` (241 lines)
- `udpfs_server/router_status.py` (179 lines)
- `AGENTS.md` (repo root; house rules, read per runtime instruction — no audit content taken from it)

Grep-only cross-checks (not audited, other workers' scopes): `udpfs_server/ps2servers_core.py` (subclass relationship, one `tx_start_seq` assignment), `tests/` filenames and selected symbol greps (selftest-reuse and coverage censuses), `.github/workflows/ci.yml` / `edge.yml` (selftest invocations, via grep output only).

## Files not read (in scope)

- None. Every file named in the scope was read in full. `multiclient_selftest.py` was read in full but could not be *executed* in this sandbox (UDP `sendto` blocked — BLOCKED-ENV, `PermissionError: [Errno 1]`); `compression_selftest.py` and `pathguard_selftest.py` were executed green in a `/tmp` copy.
