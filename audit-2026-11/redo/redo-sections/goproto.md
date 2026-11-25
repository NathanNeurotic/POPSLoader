# Go Edge Protocol Packages — Blind Redo Audit (GOPROTO)

Scope: `native/ps2servers-edge/internal/smb/`, `internal/udpfs/`, `internal/udpbd/`, `internal/compression/` — non-test `.go` source only, read in full at clone pin `c5f021c4d386`. Execution probes were run in a `/tmp` copy of the module with the shipped Go toolchain; the clone was never edited. No finding below depends on a UDP send (sandbox-blocked), so none is labelled BLOCKED-ENV.

---

### GOPROTO-01 — SMB WRITE_ANDX reports only the low 16 bits of the byte count it actually wrote
- **Category:** 6
- **Locations:** native/ps2servers-edge/internal/smb/handlers.go:499-507
- **Problem:** `writeAndX` builds its 12-byte reply with `CountLow = uint16(written & 0xFFFF)` at params[4:] and hard-zeros the field its own comment names `CountHigh` at params[8:]. A single WRITE_ANDX payload is bounded by the message, not by 64 KiB — `MaxMessage` is 128 KiB (internal/smb/wire.go) — so any write of 65,536+ bytes is under-reported by a multiple of 65,536. Executed probe: a 70,000-byte WRITE_ANDX landed all 70,000 bytes on disk, but the reply reported low=4464, high=0, i.e. 4,464 bytes written. A client that trusts the count (retry/resume logic, or a save verifier) is told a completed write mostly did not happen.
- **Fix:** Write `uint16(written >> 16)` into params[8:] instead of 0.
- **Benefit:** The reply count matches the bytes written for every write the server accepts, up to the full message size.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### GOPROTO-02 — SMB WRITE_ANDX assembles its data length in a plain `int`, the exact 32-bit wrap `readAndX` was fixed for
- **Category:** 6
- **Locations:** native/ps2servers-edge/internal/smb/handlers.go:479 (defect); native/ps2servers-edge/internal/smb/handlers.go:426-430 (the fixed sibling pattern)
- **Problem:** `writeAndX` computes `n := int(dlenLow) | int(dlenHigh)<<16`. `readAndX` carries a long comment (handlers.go:402-425) explaining that this expression is 32-bit on mipsle/mips/arm/386 — every small target this build exists for — so a high word ≥ 0x8000 sets the sign bit, makes the count negative, and the clamp misses it. `writeAndX` was left with the unfixed form: on a 32-bit build a declared length with `dlenHigh >= 0x8000` makes `n` negative, `req.slice` returns nil for `n <= 0` (internal/smb/server.go, `slice`), and the handler writes zero bytes and returns STATUS_SUCCESS with a zero count — a silent no-op write. The in-file fix (`uint32` assembly, then clamp, then narrow) was applied to one of the two handlers that need it.
- **Fix:** Assemble the length as `uint32(dlenLow) | uint32(dlenHigh)<<16` in `writeAndX`, exactly as `readAndX` does, before any narrowing to `int`.
- **Benefit:** Removes a silent-success zero-byte write on the 32-bit routers Edge targets, and makes the two AndX handlers consistent so the documented trap cannot be re-learned per handler.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOPROTO-03 — SMB WRITE_ANDX ignores the handle's access mode and re-opens the file by path for writing
- **Category:** 6
- **Locations:** native/ps2servers-edge/internal/smb/handlers.go:481-493 (write path); native/ps2servers-edge/internal/smb/handlers.go:224 (`openAndX` opens with `os.Open`, read-only); native/ps2servers-edge/internal/smb/handlers.go:359 (`ntCreateAndX` also stores an `os.Open` handle)
- **Problem:** Both open paths store a read-only `*os.File` in the handle and record no access mode. `writeAndX` never looks at that handle's mode (or at `of.fh` at all): it opens a brand-new `os.O_WRONLY` file from `of.path` and writes through it. So a handle the client opened read-only is silently writable, per-handle access simply does not exist in this server, and closing/evicting the stored `fh` has no effect on writability. Executed probe: the handle registered in the probe held a read-only `os.Open` file, and `writeAndX` still wrote 70,000 bytes to the file. The fresh open-per-write also means every WRITE_ANDX pays an open/close pair and bypasses any state on the original descriptor.
- **Fix:** Record the granted access on `openFile` at open time, refuse WRITE_ANDX on a handle not opened for writing, and write through the handle's own descriptor (opened with the right flags at OPEN/NT_CREATE time) instead of re-opening by path.
- **Justification:** This adds one field to an existing struct and deletes the per-write re-open; it adds no new mechanism, abstraction, or configuration.
- **Benefit:** Handle access means what the protocol says it means; a read handle cannot be used to modify a file, and the write path stops paying an extra open/close per request.
- **Effort:** M · **Risk:** Med · **Confidence:** High (EXECUTED)

### GOPROTO-04 — UDPBD read-only writes fake success at the device layer and arm a real write handshake at the handler layer
- **Category:** 6
- **Locations:** native/ps2servers-edge/internal/udpbd/server.go:89-95 (`device.writeAt`); native/ps2servers-edge/internal/udpbd/server.go:452-469 (`handleWrite`); native/ps2servers-edge/internal/udpbd/server.go:501-533 (the only place failure is ever reported)
- **Problem:** Two stacked lies. (1) `device.writeAt` returns `nil` — success — when the device is read-only, having written nothing; any caller that trusts the error is deceived. (2) `handleWrite` logs "WRITE on a read-only image, ignoring" and then does not ignore it: the `if s.dev.readOnly` block (452-456) has no `return`, so the handler arms a full `writeState` and adds the full byte count to `totalWrite` (460-468). Every following WRITE_RDMA chunk is passed to the no-op `writeAt` and counted as consumed; failure (`WriteDone` result −1) is produced only if the sequence happens to run to completion (521-533). A client that aborts mid-sequence hears nothing at all. Executed probes confirmed both halves: `writeAt` on a read-only device returned `err=<nil>` with the file unchanged, and `handleWrite` on a read-only image left `write.left=1024, totalWrite=1024` for a 2-sector write. Contrast UDPFS's BWRITE path, which refuses a read-only device up front.
- **Fix:** Make `writeAt` return an error (e.g. `syscall.EACCES`, as UDPFS's block device already does) when read-only, and make `handleWrite` return immediately after its read-only warning without arming state or counting bytes.
- **Benefit:** A read-only image refuses writes at the handshake, the device primitive stops reporting success for work it did not do, and no counter claims bytes that were discarded.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### GOPROTO-05 — UDPBD: any peer's INFO, or any second WRITE, silently destroys another peer's in-flight write
- **Category:** 6
- **Locations:** native/ps2servers-edge/internal/udpbd/server.go:352-353 (`handleInfo` resets state); native/ps2servers-edge/internal/udpbd/server.go:460-467 (`handleWrite` overwrites state); native/ps2servers-edge/internal/udpbd/server.go:476-490 (victim's RDMA packets are then dropped silently)
- **Problem:** There is exactly one `writeState` for the server. `handleInfo` clears it unconditionally — `s.write = writeState{}` runs for an INFO from *any* peer, with no peer check, even though the struct comment says the peer is recorded precisely so a different console cannot land in the middle of a write. `handleWrite` likewise overwrites the state unconditionally. After either event, the first console's remaining WRITE_RDMA packets fail the `left <= 0 || !peerMatch` test and are dropped with only a Debug log; no `WriteDone` failure is ever sent to the victim, whose console is left believing a save is still in progress. `handleRead`'s state clear is peer-guarded (same peer only), which shows the intended discipline — INFO and WRITE simply don't apply it.
- **Fix:** Only reset the write state in `handleInfo`/`handleWrite` when it is idle or belongs to the requesting peer; if a different peer's write is displaced, send that peer a `WriteDone` failure before discarding its state.
- **Benefit:** One console's discovery broadcast or write attempt can no longer silently corrupt/strand another console's in-flight save.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOPROTO-06 — UDPBD `seen` peer map grows forever and the status reply reports it as the live session count
- **Category:** 4
- **Locations:** native/ps2servers-edge/internal/udpbd/server.go:350-351 (only insertion); native/ps2servers-edge/internal/udpbd/server.go:205-206,220 (reported as `Sessions`)
- **Problem:** Every distinct peer address string (`IP:port`) that ever sends an INFO is inserted into `s.seen` and nothing ever removes an entry — a script census of the file shows the map is written at 350-351 and read at 205-206/350 only. Consoles that reappear from a new source port accumulate permanently, so (a) the map is an unbounded, slow leak on a long-lived router process, driven by unauthenticated UDP source addresses, and (b) the router-status `Sessions` field is not a session count at all but a monotonically increasing count of every peer ever seen, which is exactly the number a launcher uses to decide whether the server is in use.
- **Fix:** Delete the `seen` map's role in `statusReply` (report an actual live-peer notion or 0/1 in-flight state), and keep `seen` — if it is kept at all for the first-contact log line — bounded or expiry-based like the other servers' session tables.
- **Benefit:** Status reports something true, and an unauthenticated packet source can no longer grow server memory without limit.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOPROTO-07 — UDPFS status "Busy" latches on for the life of a session after its first data packet
- **Category:** 6
- **Locations:** native/ps2servers-edge/internal/udpfs/status.go:61-82 (`anyTransferInFlight`); native/ps2servers-edge/internal/udpfs/negotiation.go:497 (`st.Streaming = true`); native/ps2servers-edge/internal/udpfs/server.go:190-191 (default `PeerTimeout` of one hour)
- **Problem:** `anyTransferInFlight` reports a transfer in flight when `st.Streaming || st.WriteActive`. `WriteActive` is a real in-flight signal; `Streaming` is not — within the udpfs package it is only ever set to `true` (negotiation.go:497, on the first accepted DATA packet) and is cleared only by a session reset/handoff or by session expiry, which by default takes an hour of idleness. The stated purpose of the Busy state (status.go:39-41) is to warn a launcher not to cut power mid-transfer; as implemented, the server reports Busy continuously from the first packet of a session until up to an hour after the last one, so the warning is permanently on and therefore meaningless — the failure mode the state exists to prevent (a user learning to ignore it) is built in.
- **Fix:** Base Busy on actual in-flight work only (`WriteActive` and an equivalent read/transfer-in-progress signal from the send-window path), not on the latched `Streaming` negotiation flag.
- **Benefit:** The router-status Busy state again means "a transfer is in flight now", which is the only version of it that protects a save.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### GOPROTO-08 — UDPFS re-parses every CHD's track table from disk on every directory listing, OPEN and GETSTAT of a virtual CD
- **Category:** 5
- **Locations:** native/ps2servers-edge/internal/udpfs/operations.go:282 (`prepareDirectory` → `ListVirtualCD`, called from every directory OPEN at operations.go:336); native/ps2servers-edge/internal/udpfs/operations.go:234-251 (`resolveVirtualCD` → `FindVirtualCD`, called from operations.go:344, 383, 781); native/ps2servers-edge/internal/compression/chd_cuebin.go:406-475 (`ListVirtualCD`); native/ps2servers-edge/internal/compression/chd_cuebin.go:476-539 (`FindVirtualCD`)
- **Problem:** There is no caching of CD track tables anywhere in the compression package (its only caches hold decompressed blocks/hunks). `ListVirtualCD` does a directory read and, for *every* `.chd` in the folder, a full `readCDTrackTable` (open, 124-byte header parse, metadata-chain walk, track parse, layout build) plus a second `layout()` — and `prepareDirectory` calls it on every directory OPEN, i.e. every time a console browses a folder. `FindVirtualCD` repeats the same directory scan and full parse for a single file, and it is invoked on the OPEN, write-OPEN and GETSTAT paths for every `.cue`/`.bin` name. On a share with dozens of CD CHDs, merely listing the folder re-reads and re-parses every CHD's metadata chain, every time, on the low-power routers Edge targets.
- **Fix:** Cache the parsed track table/layout per CHD path keyed by the file identity the code already checks (`os.SameFile` + size + modtime, as `VirtualCDFile.Open` does), and reuse it in both `ListVirtualCD` and `FindVirtualCD`.
- **Justification:** This adds one small cache, but it removes repeated disk reads and parses of the same immutable metadata on the browsing hot path — a concrete, measured-by-inspection cost with a net win on the target hardware; the invalidation key already exists in the code.
- **Benefit:** Directory browsing and virtual-CD opens stop scaling with total CHD metadata size per request; repeat listings become directory reads only.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### GOPROTO-09 — CSO/ZSO index-extent validation is duplicated verbatim between `openImage` and `SizeOf`
- **Category:** 2
- **Locations:** native/ps2servers-edge/internal/compression/image.go:198-202; native/ps2servers-edge/internal/compression/image.go:330-333
- **Problem:** The block-count computation and the `blocks > 1<<28 || headerSize+(blocks+1)*4 > fileSize` extent check, including the identical error string, exist in two copies. `parseHeader`'s own comment (image.go:238-241) says it was factored out "so that SizeOf and Open cannot drift apart on what counts as a valid image" — but only the 24-byte prologue half was factored; the index-extent half, which is the half that decides whether a corrupt header is rejected, was left duplicated. A future tightening (or loosening) applied to one copy silently re-creates exactly the probe-accepts-what-the-opener-rejects drift the comment warns about.
- **Fix:** Extract the block-count/extent check into one small function used by both `openImage` and `SizeOf`.
- **Benefit:** One definition of a valid image header; the stated anti-drift invariant becomes true for the whole header, not half of it. Net code shrinks.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOPROTO-10 — The CHDv5 header is parsed twice, by two parsers with different validation rules
- **Category:** 2
- **Locations:** native/ps2servers-edge/internal/compression/chd.go:31-95 (`parseCHDHeader`); native/ps2servers-edge/internal/compression/chd_cuebin.go:193-230 (`readCDTrackTableOpt` header half)
- **Problem:** Both functions open the same file, read the same 124-byte header, check the same magic/version/header-size fields, and decode the same logical-size/hunk/unit fields — then validate them differently (e.g. the track-table parser requires `logical % 2448 == 0` and `unit == 2448`; `parseCHDHeader` requires neither, and derives CD-ness from the unit and codec IDs instead). `parseCHDHeader` additionally calls `exactCDISOSize`, which re-opens the file and runs the second parser. Two parsers for one fixed header is a standing drift hazard in a format-validation path: a bounds fix (hunk ceiling, overflow check) made in one is not made in the other, and the two already disagree on what a valid header is.
- **Fix:** Parse the 124-byte header once into a shared raw-header struct; let each caller apply only its own additional constraints (CD geometry for the track table, codec/unit interpretation for the image opener) on top.
- **Benefit:** One place owns CHD header bounds/overflow validation; callers keep their differing semantics explicitly instead of by parser divergence. Net code shrinks.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### GOPROTO-11 — SMB FIND_FIRST2's EndOfSearch branch is dead: the entry list can never have length 1
- **Category:** 1
- **Locations:** native/ps2servers-edge/internal/smb/handlers.go:713-725
- **Problem:** `findFirst2` seeds `entries` with two entries, `"."` and `".."` (713-716), then computes `eos = 1` only `if len(entries) == 1` (722-725). The list always has at least two entries, so the branch is unreachable and `eos` is always 0 on the first reply — including for an empty directory, where the client must still issue a FIND_NEXT2 to learn the listing is finished. Dead condition plus a wasted round trip on every empty-folder browse.
- **Fix:** Delete the dead branch and set EndOfSearch from the real condition (cursor has reached the last entry, as `findNext2` already computes it).
- **Benefit:** Removes unreachable code and gives an empty listing a correct EndOfSearch on the first reply.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOPROTO-12 — SMB hand-rolls `itoa` instead of using `strconv.Itoa`
- **Category:** 2
- **Locations:** native/ps2servers-edge/internal/smb/server.go:244-256 (definition); native/ps2servers-edge/internal/smb/server.go:166 (sole caller)
- **Problem:** `itoa` is a 13-line reimplementation of `strconv.Itoa` with one caller, a narrower contract (it silently mishandles negative input, returning an empty string, where the stdlib does not), and an 8-byte buffer sized by hand for a value the caller has already range-checked. It is pure maintenance surface duplicating the standard library in a protocol package.
- **Fix:** Delete `itoa` and call `strconv.Itoa` at the single call site.
- **Benefit:** Less code, stdlib-correct behaviour for every input, one less bespoke helper to audit.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOPROTO-13 — SMB's FID/TID/SID allocators are three copies of one function
- **Category:** 2
- **Locations:** native/ps2servers-edge/internal/smb/server.go:425-447
- **Problem:** `allocFID`, `allocTID` and `allocSID` are byte-for-byte the same increment-and-wrap logic, differing only in the field they touch and the wrap value (0x1000 vs 0x0001). Any fix to the wrap behaviour (e.g. skipping IDs still in use — all three currently wrap onto live IDs without checking) has to be made three times, and the three can drift.
- **Fix:** Replace the three with one allocator helper parameterised by the counter and its wrap value, or a tiny allocator type used for all three counters.
- **Benefit:** One implementation of ID allocation for the connection; net code shrinks and wrap fixes land once.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOPROTO-14 — LZ4 block decoder's length accumulator is unbounded, defeating its own output checks on 32-bit targets
- **Category:** 6
- **Locations:** native/ps2servers-edge/internal/compression/lz4.go:13-29 (`readLen`); native/ps2servers-edge/internal/compression/lz4.go:37-40 (the checks it feeds); native/ps2servers-edge/internal/compression/image.go:420-460 (`decodeBlock`, the caller that bounds raw size to `blockSize*2 + 4096` with `blockSize` up to 16 MiB)
- **Problem:** `readLen` accumulates `n += v` for each 0xFF extension byte with no cap against `dstSize` or the remaining input. The decoder's safety argument is the post-hoc checks (`lit > dstSize-len(dst)` etc.), which assume `lit` is a sane positive number. On a 32-bit `int` — the MIPS/ARM routers this codebase repeatedly designs for — a crafted ZSO block consisting of a long run of 0xFF length bytes (the raw block may be up to ~32 MiB under `decodeBlock`'s bound, so ~8.6 billion can be accumulated) wraps `n` negative; a negative `lit` passes both checks at lz4.go:37 and reaches `src[i:i+lit]` at line 40 as a slice-bounds panic in the serving path. On 64-bit the same input is merely rejected, which is why the defect is invisible on a development machine.
- **Fix:** Bound the accumulation inside `readLen`: fail as soon as `n` exceeds the maximum legitimate length (`dstSize`, or the remaining input size), before it can overflow.
- **Benefit:** A malformed compressed image returns an error instead of panicking the server on 32-bit builds; the decoder's documented "malformed input cannot grow memory" guarantee extends to "cannot crash the process".
- **Effort:** S · **Risk:** Low · **Confidence:** Med (INFERRED — overflow depends on 32-bit `int`; the unbounded accumulation itself is READ)

### GOPROTO-15 — UDPFS plain file WRITE is never held to the length it declared, unlike the BWRITE path that was hardened for exactly this
- **Category:** 8
- **Locations:** native/ps2servers-edge/internal/udpfs/operations.go:547-595 (`handleWriteRequest` reserves `make([]byte, 0, size)` from the declared size but stores it nowhere); native/ps2servers-edge/internal/udpfs/operations.go:634-643 (declared-length enforcement exists only when `WriteExpectedLen > 0`); native/ps2servers-edge/internal/udpfs/operations.go:653-663 (`completeWrite` routes on `WriteIsBlock` and only the block branch checks the length); native/ps2servers-edge/internal/udpfs/blockdev.go:301, 344-409 (`WriteExpectedLen` is set, and exact-length-checked, only for BWRITE)
- **Problem:** The block-write path was deliberately hardened so the delivered byte count must equal the declared count exactly — `completeBlockWrite`'s comment calls writing a different quantity than was validated "the same defect as the overflow bug in inRange". The plain file WRITE path never got the same treatment: the declared size in WRITE_REQUEST is used only as a buffer capacity hint, completion is driven purely by the client's per-chunk `totalChunks` claim, and `completeWrite` flushes and reports success for whatever arrived. A sequence that declares one size and delivers another (truncated, or padded past the declaration up to the transfer cap) is written and synced as a successful save. The feature is half-finished: the invariant exists in one of the two write paths that share the same chunk machinery.
- **Fix:** Store the WRITE_REQUEST declared size as the expected length for file writes too (the state field already exists) and let the existing `WriteExpectedLen` enforcement and a completion length check cover both paths.
- **Benefit:** Both write paths enforce the same declared-vs-delivered invariant the codebase already decided is required; a short or over-long save cannot be reported as a clean write.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ)

### GOPROTO-16 — `compression.Open` is a production-dead wrapper kept alive only by tests
- **Category:** 1
- **Locations:** native/ps2servers-edge/internal/compression/image.go:137-138
- **Problem:** `Open` is a one-line wrapper over `OpenCached(path, DefaultCacheBlocks)`. A script census of the whole Edge module finds zero production callers: the only production open paths are `OpenCached` and `OpenRaw` (both called from internal/udpfs/blockdev.go:396,402), while `Open` is referenced exclusively from `*_test.go` files in its own package. In an `internal` package there are no external consumers to keep it for; it is an API surface that exists only so tests can call the shorter name.
- **Fix:** Delete `Open` and have the tests call `OpenCached(path, DefaultCacheBlocks)`.
- **Benefit:** One fewer entry point into the image opener; the production API is exactly the two calls production actually makes.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — census by script over the whole module)

### GOPROTO-17 — SMB TRANSACTION handler answers every transaction as a NetShareEnum, ignoring the request entirely
- **Category:** 6
- **Locations:** native/ps2servers-edge/internal/smb/handlers.go:840-871 (`transaction`); native/ps2servers-edge/internal/smb/server.go (dispatch routes `ComTransaction` here unconditionally)
- **Problem:** `transaction` never reads `r.params` or `r.data`: it does not look at the transaction name (`\PIPE\LANMAN` or anything else), the RAP function code, or the requested information level, and unconditionally returns a level-1 share enumeration in a TRANS2-shaped envelope. Any TRANSACTION a client sends — a different RAP call, a different pipe, a malformed one — receives a successful share list as its answer. Today OPL's share picker is the only known sender, which is why this works; but as a protocol handler it claims success for requests it has not identified, and any future or incidental transaction from a client will be silently mis-answered instead of refused with NOT_IMPLEMENTED, which is how the server treats every other unimplemented command.
- **Fix:** Parse the transaction name/function from the request and answer only the NetShareEnum call this handler implements; return `StatusNotImplemented` for anything else.
- **Benefit:** The handler stops returning successful, wrong-shaped data for unidentified requests; unknown transactions fail visibly instead of being mis-answered.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ)

---

## Files read

All paths relative to the clone root; every file below was read in full (7,530 lines total across 26 files, counted by script).

- native/ps2servers-edge/internal/smb/wire.go (263 lines)
- native/ps2servers-edge/internal/smb/server.go (745 lines)
- native/ps2servers-edge/internal/smb/handlers.go (902 lines)
- native/ps2servers-edge/internal/udpbd/protocol.go (104 lines)
- native/ps2servers-edge/internal/udpbd/server.go (555 lines)
- native/ps2servers-edge/internal/udpfs/server.go (613 lines)
- native/ps2servers-edge/internal/udpfs/operations.go (820 lines)
- native/ps2servers-edge/internal/udpfs/negotiation.go (522 lines)
- native/ps2servers-edge/internal/udpfs/transfer.go (251 lines)
- native/ps2servers-edge/internal/udpfs/pathops.go (261 lines)
- native/ps2servers-edge/internal/udpfs/blockdev.go (409 lines)
- native/ps2servers-edge/internal/udpfs/metrics.go (205 lines)
- native/ps2servers-edge/internal/udpfs/status.go (103 lines)
- native/ps2servers-edge/internal/udpfs/errno.go (91 lines)
- native/ps2servers-edge/internal/udpfs/errno_other.go (36 lines)
- native/ps2servers-edge/internal/udpfs/errno_windows.go (35 lines)
- native/ps2servers-edge/internal/udpfs/udpwrite_linux.go (27 lines)
- native/ps2servers-edge/internal/udpfs/udpwrite_other.go (11 lines)
- native/ps2servers-edge/internal/compression/image.go (489 lines)
- native/ps2servers-edge/internal/compression/chd.go (150 lines)
- native/ps2servers-edge/internal/compression/chd_cuebin.go (539 lines)
- native/ps2servers-edge/internal/compression/chd_cuebin_enabled.go (217 lines)
- native/ps2servers-edge/internal/compression/chd_cuebin_disabled.go (12 lines)
- native/ps2servers-edge/internal/compression/chd_enabled.go (87 lines)
- native/ps2servers-edge/internal/compression/chd_disabled.go (13 lines)
- native/ps2servers-edge/internal/compression/lz4.go (70 lines)

Supporting reads outside scope, used only to verify nil-safety/lifecycle claims made about in-scope code (not audited): internal/sessionstats/sessionstats.go (nil-receiver behaviour of `Stop`/`RunExpiry`), internal/statuslistener (nil-receiver `Close`), internal/session/session.go (`Streaming` reset site), internal/filesystem/root.go (`Open`/`Resolve` signatures for the execution probes).

Execution probes (in a /tmp copy, clone untouched): two tests in internal/udpbd confirming GOPROTO-04 (read-only `writeAt` returns nil; read-only `handleWrite` arms state), and one test in internal/smb confirming GOPROTO-01 and GOPROTO-03 (70,000-byte write reported as 4,464; write succeeded through a read-only handle).

## Files not read (in scope)

None. Every non-test `.go` file in the four in-scope directories was read in full. (Test files `*_test.go` and the non-Go file `internal/compression/chd_libchdr.h` were excluded by the scope definition; `chd_libchdr.h` is a C header for the cgo binding, not Go source.)
