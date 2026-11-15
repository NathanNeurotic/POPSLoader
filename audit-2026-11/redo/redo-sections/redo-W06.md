# W06 — Blind Redo Audit: RiptOPL `modules/network/` (remainder)

- Clone: `~/workspace/audit-clones-2026-11-13/RiptOPL`, HEAD verified `2e347d5ac885cd0ff73e9ad4143781946396f492` before starting.
- Scope: `smbman-ra/`, `smb2man/`, `smbinit/`, `nfsman/`, `nbns/`, `httpclient/`, `rapops/`, `rapull/`, `raudp/`, `smap-ingame/`, `smap_udpbd/`, and the udpfs family (`udpfs_bd/`, `udpfs_fhi/`, `udpfs_ioman/`, `udpfs_ministack/`, `udpfs_shared/`, `udpfs_smap/`).
- Method: files read in full unless the COVERAGE section says otherwise. All counts, diffs and md5 comparisons below come from commands actually run (`wc`, `diff`, `md5sum`, `grep -n`); nothing is estimated. READ = seen in the source; INFERRED = reasoned from what was read.

---

## W06-001 — SMB1 reply length is server-controlled and overflows the static SMB buffer

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/network/smbman-ra/smb.c:230`, `RiptOPL/modules/network/smbman-ra/smb.c:257-261`; buffer size at `RiptOPL/modules/network/smbman-ra/smb.h:894-895`
- **Problem:** In `GetSMBServerReply()`, the total packet size is taken from `nb_GetSessionMessageLength()`, a 24-bit field in the NetBIOS session header sent by the server (up to ~16 MB). On the `rhdrlen == 0` path the code then calls `RecvData(main_socket, (char *)&SMB_buf.smb, size, 3000)` with that size. `SMB_buf.smb` is `MAX_SMB_BUF + MAX_SMB_BUF_HDR` = 4096 + 128 = 4224 bytes. There is no check that the claimed length fits the buffer before the receive, so a malicious or broken SMB server (or anything that can answer on the share's port) writes past a static IOP buffer. READ.
- **Fix:** Clamp/reject the session-message length against the receive buffer size in `GetSMBServerReply()` before any `RecvData` into `SMB_buf`; fail the request on an oversized claim. This is a bound check on existing code, not a new mechanism.
- **Benefit:** Removes a remotely triggerable static-buffer overflow in the module that runs for every SMB game load.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W06-002 — Negotiate Protocol copies a server-controlled key length into an 8-byte field

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/network/smbman-ra/smb.c:403-404`; field at `RiptOPL/modules/network/smbman-ra/smb.h:286`
- **Problem:** `smb_NegotiateProtocol()` does `memcpy(server_specs.EncryptionKey, NPRsp->ByteField, NPRsp->KeyLength)`. `KeyLength` is a server-supplied byte (0–255); `EncryptionKey` is `u8[8]` inside the static `server_specs`. Any server claiming a longer key overflows the struct. The next line passes `&NPRsp->ByteField[NPRsp->KeyLength]` to `getStringField(..., 0)`, i.e. an unbounded string copy starting at a server-chosen offset, which can also read past the received packet. READ.
- **Fix:** Reject `KeyLength > 8` (the LM/NT challenge is defined as 8 bytes) before the copy, and bound the domain-name copy by the bytes actually received.
- **Benefit:** Closes a trivially triggered overflow at the very first exchange with any server.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W06-003 — SMB1 ReadAndX trusts the server's data length and padding; WriteAndX in the same file was already hardened

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/network/smbman-ra/smb.c:1077-1092`; hardened sibling for contrast at `RiptOPL/modules/network/smbman-ra/smb.c:1164-1170` (approx., the WriteAndX reply checks)
- **Problem:** `smb_ReadAndX()` computes `padding = RRsp->DataOffset - sizeof(ReadAndXResponse_t)` and receives that many bytes into `(RRsp + 1)` inside `SMB_buf` with no bound, then computes a 32-bit `DataLength` from the reply and receives exactly that into the caller's `readbuf` without ever comparing it to the caller's `nbytes`. A server can therefore overflow both the internal buffer (via padding) and the caller's buffer (via DataLength). The neighbouring `smb_WriteAndX()` already validates reply size, WordCount and `Count > nbytes` with an explanatory comment — the same discipline was never applied to the read path. READ.
- **Fix:** Apply the WriteAndX pattern to ReadAndX: reject negative/oversized padding, and clamp or reject `DataLength > nbytes`.
- **Benefit:** The read path is the hot path for game data; this is the same class of overflow as W06-001 on the most-used operation.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W06-004 — SMB1 transaction replies use server offsets as raw indices into the receive buffer

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/network/smbman-ra/smb.c:692`, `:696`, `:699-702` (NetShareEnum), `:833`, `:846` (QueryPathInformation), `:1477`, `:1482` (FindFirst/Next2)
- **Problem:** One mechanism in three operations: `ParamOffset`/`DataOffset` from the server's TRANSACTION response are used directly as byte indices into `SMB_buf.smb.u8buff[]` with no check against the number of bytes actually received. NetShareEnum additionally walks the data area with `strlen()` and a server-supplied u16 comment offset, and loops over a server-supplied `AvailableEntries` count. Out-of-range offsets give out-of-bounds reads of static memory and, in the FindFirst path, copies of attacker-influenced bytes into the caller's file-info struct. READ.
- **Fix:** Validate both offsets (and, for NetShareEnum, the entry count and per-entry string extents) against the received reply length before dereferencing; fail the call otherwise. One shared check at the point each response is unpacked — no new abstraction, the offsets are already handled per-function.
- **Benefit:** Removes OOB reads across share enumeration, stat and directory listing — all reachable by any SMB server the user connects to.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ)

## W06-005 — UDPRDMA receive ISR lets a peer claim an app-header up to 60 bytes into 32-byte (or smaller) buffers

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/network/udpfs_shared/src/udprdma.c:185`, `:191-196`; limit defined at `RiptOPL/modules/network/udpfs_bd/src/udprdma_packet.h:103` (identical copies in the fhi/ioman trees)
- **Problem:** In `_ist()`, the DATA case computes `hdr_size = data_hdr.hdr_word_count * 4`. `hdr_word_count` is a 4-bit field in the wire header, so `hdr_size` can be up to 60. `UDPRDMA_MAX_APP_HDR` is 32. Two consequences, both READ: (a) the discard path declares `uint8_t dummy[UDPRDMA_MAX_APP_HDR]` on the stack and calls `smap_fifo_read(0x30, dummy, hdr_size)` — up to 28 bytes past a stack buffer, in interrupt context; (b) the keep path calls `smap_fifo_read(0x30, s->rx_hdr_buffer, hdr_size)` without comparing against `s->rx_hdr_size`, the size the current receive armed (e.g. the 8-byte `udpfs_msg_result_reply_t`), so a peer can write up to 60 bytes into a much smaller caller buffer. The send side of the same file does check `app_hdr_size > UDPRDMA_MAX_APP_HDR` (udprdma.c:595); the receive side never does. The ministack exchange layer in the same family (`udpfs_ministack/src/ministack_xchg.c`) validates its wire lengths — this layer does not.
- **Fix:** In `_ist()`, reject (drop the packet) when `hdr_size > UDPRDMA_MAX_APP_HDR`, and when a header buffer is armed, also when `hdr_size > s->rx_hdr_size`. Two comparisons in the existing branch; nothing added.
- **Benefit:** Closes a peer-triggerable overflow in the interrupt handler of the UDPFS transport used by all three udpfs editions (the source is shared).
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W06-006 — UDPFS core returns the server's claimed byte counts without checking them against what arrived

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/network/udpfs_shared/src/udpfs_core.c:114-117` (`_recv_with_result`), `:547-549` (`udpfs_core_dread`)
- **Problem:** `_recv_with_result()` returns `result.result` — a server-supplied int32 — as the number of bytes read, ignoring the actual received length returned by the transport. `udpfs_core_read()` then advances the caller's buffer and totals by that claimed amount, so a server can make the client report (and its caller consume) more bytes than were ever DMA'd. Separately, `udpfs_core_dread()` checks `reply->name_len` only against the caller's `name_max`, not against the bytes actually received (`ret`), so a short reply yields stale bytes from the shared 312-byte `g_rx_buf` copied out as a filename (bounded, but fabricated data presented as a directory entry). READ for both code paths; the downstream impact of the over-claimed read count on EE-side callers is INFERRED.
- **Fix:** Treat the transport's received length as authoritative: fail or clamp when `result.result` exceeds it, and require `sizeof(reply) + name_len <= ret` in dread.
- **Benefit:** The protocol's own result field stops being a second, unchecked source of truth for buffer accounting.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ) / Med for downstream impact (INFERRED)

## W06-007 — NBNS resolver validates only the header size, then reads the answer at a fixed offset

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/network/nbns/nbns.c:179`, `:191`, `:198`
- **Problem:** `nbnsReceiveThread()` accepts any datagram with `length >= sizeof(struct NbHeader)` (12 bytes), runs `decode_name()` on the name field without validating that the datagram actually contains a full 32-byte encoded name plus question trailer, and then copies the resolved address from the fixed offset `sizeof(NbHeader) + 34 + sizeof(NbQuestionTrailer) + 4 + 2 + 2` (byte 58, 4 bytes). A short crafted datagram — anything ≥12 bytes that passes the name-question match — makes the resolver copy stale bytes from the static receive frame and report them as the server's IP address. `decode_name()` itself stays inside the 576-byte frame; the defect is the missing total-length validation before the fixed-offset read. READ.
- **Fix:** Require the datagram length to cover the full expected answer layout (header + name + trailer + address) before decoding/copying; drop shorter packets.
- **Benefit:** Name resolution is how the client finds the SMB server; a spoofed short reply on the LAN currently steers it to an arbitrary address built from stale buffer contents.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W06-008 — httpclient's response reader copies without knowing the caller's buffer size

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/network/httpclient/httpclient.c:225`; mitigating caller at `RiptOPL/modules/network/httpclient/main.c:45-50`
- **Problem:** `HttpGetResponse()` does `memcpy(buffer, ptr, DataAvailable)` (up to 256 bytes per chunk) without checking against the caller's `*length`. Today the only in-tree caller passes a 512-byte `DmaBuffer` with `out_len` pre-clamped to 512, so the defect is latent rather than live — but the function's own contract doesn't enforce it, and the header lives in `modules/network/common/`, inviting other callers. READ.
- **Fix:** Pass the remaining capacity into the copy (the length is already an in/out parameter) and stop at the smaller of `DataAvailable` and remaining space.
- **Benefit:** Removes a latent overflow at an API boundary for the cost of one comparison.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ); live impact Low because of the single clamped caller (READ)

## W06-009 — smb_fio path handling can walk before the buffer and can leave stored names unterminated

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/network/smbman-ra/smb_fio.c:312-313` (`prepare_path`), `:660-663` (`smb_dopen`), `:361` (`smb_open`)
- **Problem:** Two local string defects. (a) `prepare_path()` sets `p2 = &path[strlen(path)]` and walks backwards while `*p2` is a slash; for an empty or all-slash path `p2` steps in front of the buffer before the loop condition saves it. (b) `smb_dopen()` does `strncpy(fh->name, path, 255)` into a 256-byte field — a path of ≥255 chars leaves `fh->name` unterminated — and immediately `strcat(fh->name, "\\")` and `strcat(fh->name, "*")`, reading/writing past the field; `smb_open()` has the same unterminated-`strncpy` pattern at line 361. Paths here come from the EE side, so this is robustness against malformed local input rather than a wire attack; severity INFERRED.
- **Fix:** Guard the backward walk with `p2 > path`, and bound the stored name so it is always NUL-terminated with room for the two appended characters (or reject over-long paths, as other drivers in this tree do).
- **Benefit:** Removes two memory-safety defects in the SMB file layer for a few comparisons.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ) for the code patterns; Med (INFERRED) for reachability with a ≥255-char path

## W06-010 — raudp discovery compares a sender address that may never have been filled in

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/network/raudp/raudp.c` (`ra_discover`, pinned/caduceus branch)
- **Problem:** In pinned mode the discovery loop inspects `from.sin_addr` after `lwip_recvfrom()` without first checking that the call returned ≥0; on a timeout/error return the `from` struct can hold whatever was there before, and the comparison decides whether a "pinned" server matched. INFERRED from the read of the loop; the surrounding code is otherwise carefully bounded.
- **Fix:** Only evaluate the sender when the receive returned a datagram.
- **Benefit:** The pin check — a trust decision — never runs on uninitialised data.
- **Effort:** S · **Risk:** Low · **Confidence:** Low (INFERRED)

## W06-011 — rapull setup leaks earlier allocations when a later one fails

- **Category:** 6 (bugs/security) / 4 (size/memory)
- **Locations:** `RiptOPL/modules/network/rapull/rapull.c:130-140`, `:199`
- **Problem:** `rp_setup()` makes five `AllocSysMemory` calls in sequence; if a later one fails, the blocks already allocated are not freed before the failure propagates, leaking IOP memory for the life of the module. The rest of rapull is carefully bounded (READ). INFERRED impact is small (setup-time, few blocks), but the fix is mechanical.
- **Fix:** Free the blocks obtained so far on each failure exit (or allocate into locals and publish only on full success).
- **Benefit:** Failed initialisation leaves no residue in a memory-constrained IOP.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ pattern, INFERRED frequency)

## W06-012 — Three MD4s, two DESes and two LM/NTLM hash implementations for one SMB feature set

- **Category:** 2 (duplication)
- **Locations:** MD4: `RiptOPL/modules/network/smbinit/md4.c` (175 lines), `RiptOPL/modules/network/smbman-ra/md4.c` (182), `RiptOPL/modules/network/smb2man/usmb2/md4c.c` (240). DES: `RiptOPL/modules/network/smbinit/des.c` (564), `RiptOPL/modules/network/smbman-ra/des.c` (568; `diff` = 119 lines, almost all comments/const qualifiers). LM/NTLM: `RiptOPL/modules/network/smbinit/smbauth.c` vs `RiptOPL/modules/network/smbman-ra/auth.c` (`diff` = 113 lines; same `LM_Password_Hash`/`NTLM_Password_Hash`/`LM_Response`, differing in static-vs-exported linkage and a 512-byte static vs stack password buffer). Counts from `wc`/`diff` runs.
- **Problem:** The same cryptographic primitives are maintained in two or three divergent copies across modules that ship in the same product. They have already drifted (different buffer strategies in the two auth implementations), so a fix in one does not reach the others. The modules are separate IRXs, so runtime sharing is impossible — but the udpfs family in this same tree already demonstrates the source-level pattern: one real source under `udpfs_shared/src/`, with 2-line `#include` wrappers per edition.
- **Fix:** Keep one canonical copy of each primitive in a shared source location and have smbinit/smbman-ra compile that source (the udpfs wrapper pattern), deleting the duplicate files. usmb2's MD4 is part of a vendored upstream library; leave it, or apply the same treatment only if the vendoring rules in that folder allow — the smbinit↔smbman-ra pair alone removes one MD4, one DES and one auth implementation.
- **Justification:** The fix adds nothing; it deletes two-to-three copies and keeps one.
- **Benefit:** ~1,300 lines of duplicated crypto (by `wc`) collapse to one maintained copy per primitive; the static-vs-stack password-buffer divergence disappears.
- **Effort:** M · **Risk:** Med (touch two IRX builds; behaviour must stay identical) · **Confidence:** High (READ + measured diffs)

## W06-013 — udpfs editions still carry per-edition copies of headers that the shared core made unnecessary

- **Category:** 2 (duplication) / 7 (repo clutter)
- **Locations:** `RiptOPL/modules/network/udpfs_bd/src/`, `udpfs_fhi/src/`, `udpfs_ioman/src/` — `udpfs_core.h`, `udpfs_packet.h`, `udprdma.h`, `udprdma_packet.h`, `udprdma_seq.h`; `include/mprintf.h` in six places (bd/fhi/ioman/ministack/smap trees, plus a differing copy in smap_udpbd)
- **Problem:** The `.c` side of the udpfs family was already consolidated: each edition's `udpfs_core.c`/`udprdma.c` is a 2-line wrapper including `udpfs_shared/src/…`, and the three variant Makefiles compile the shared sources with distinct `FEATURE_UDPFS_*` flags (all three editions are live — the root Makefile embeds all three IRXs). The headers were not consolidated: `md5sum` shows the five protocol headers above are byte-identical across all three editions (3 copies each), and `mprintf.h` is byte-identical in five of its six locations. `udpfs_bd/src/main.c` and `udpfs_ioman/src/main.c` are also md5-identical, and that shared main still carries the FHI init branch that is compiled out in the bd/ioman builds. Every protocol change must currently be made (or forgotten) in three places.
- **Fix:** Move the five identical headers next to the shared sources they describe and point the three editions' include paths at them, deleting the per-edition copies; do the same for `mprintf.h`. Keep the per-edition `main.c` (it is genuinely the same file — one copy, referenced by both builds).
- **Justification:** Adds nothing; it is the unfinished half of a consolidation the tree already started.
- **Benefit:** One definition of the wire structs (`udpfs_packet.h`, `udprdma_packet.h`) instead of three that can silently diverge — for a wire protocol, the highest-value copy to eliminate.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ + md5sum-verified)

## W06-014 — Two ministacks, three SMAP drivers, and small helpers copied between the udpfs and udpbd stacks

- **Category:** 2 (duplication)
- **Locations:** SMAP driver: `RiptOPL/modules/network/udpfs_smap/src/smap.c`, `RiptOPL/modules/network/smap_udpbd/src/smap.c` (`diff` = 25 lines: udpbd/fhi init hooks and `g_dma_max_block_size` handling), `RiptOPL/modules/network/smap-ingame/smap.c` (651 lines, an older genuinely different variant — single-mode TX, no DNV handling). Ministack: `RiptOPL/modules/network/udpfs_ministack/src/` (split files, ~1,118 lines) vs `RiptOPL/modules/network/smap_udpbd/src/ministack.c` (275 lines, monolithic). Helpers: `parse_ip()` at `RiptOPL/modules/network/udpfs_ministack/src/main.c:18` and `RiptOPL/modules/network/smap_udpbd/src/main.c:19` (identical ~25 lines); `udptty.c` in `udpfs_ministack/src/` and `smap_udpbd/src/` (89 lines each, `diff` = 4 lines — one include).
- **Problem:** The UDPBD stack and the UDPFS stack each carry a full copy of the SMAP driver and of the mini IP/UDP stack. The copies have already needed cross-porting once: `smap_udpbd/src/ministack.c` contains a comment recording that its ARP free-slot bug was fixed by copying udpfs_ministack's logic. smap-ingame's driver is a real variant (different TX model for the lwIP stack) and is excluded from the merge suggestion; the udpbd↔udpfs_smap pair differs by only 25 lines in ~640.
- **Fix:** Merge the udpbd and udpfs_smap SMAP drivers into one source with the existing init-hook difference kept as the per-module glue (the udpfs editions already prove the one-source/multiple-IRX pattern), and likewise share `udptty.c` and `parse_ip()` instead of copying them. Leave smap-ingame's driver and the two ministack shapes alone unless a second cross-port is needed — the ministack merge is the weakest part of this finding.
- **Justification:** Adds nothing net; each shared file replaces two copies.
- **Benefit:** The next SMAP or ARP fix lands once instead of being hand-ported (or missed) across stacks.
- **Effort:** L · **Risk:** Med (two live stacks; needs hardware validation that this audit cannot do) · **Confidence:** High (READ + measured diffs)

## W06-015 — smb2man and nfsman duplicate the same front-end plumbing

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/modules/network/smb2man/smb2man.c`, `RiptOPL/modules/network/nfsman/nfsman.c`
- **Problem:** The two network-filesystem front ends independently implement: a civil-date↔filetime conversion (`smb2man_pack_time` / `nfsman_pack_time` — same algorithm, one seeded from FILETIME and one from Unix seconds), bounded socket wait/read/write wrappers with the same poll-loop shape, and identical `malloc`/`free`/`calloc` shims over `AllocSysMemory`. READ in both files. They are separate IRXs loaded as alternatives, so this is source-level duplication only, and the value is lower than W06-012/013.
- **Fix:** Optional and lowest priority in this set: if either file is next touched for another reason, extract the date conversion and the socket wrappers into a shared source both compile (udpfs pattern). Otherwise leave alone — flagging for the record, not urging action.
- **Benefit:** One place for the date math both protocols depend on.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ)

## W06-016 — Dead code in smap_udpbd's transfer layer: an uncalled copy routine and a never-used event flag

- **Category:** 1 (dead code)
- **Locations:** `RiptOPL/modules/network/smap_udpbd/src/xfer.c:80` (`CopyFromFIFO`), `:12` and `:56` (`tx_done_ev`)
- **Problem:** `CopyFromFIFO` is defined and never called anywhere in the module (verified by grep: only the definition exists). `tx_done_ev` is created in `xfer_init()` and never waited on or signalled anywhere else (grep: only definition + creation). Both are leftovers of an earlier transfer design; udpfs_smap's xfer.c — the sibling implementation — gets by without equivalents in its live paths.
- **Fix:** Delete both. If `CopyFromFIFO` is wanted as a utility, it belongs with the copy routine that is actually used, not as a second copy.
- **Benefit:** ~30 dead lines and one useless IOP event flag removed from a shipped IRX.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ + grep-verified absence of callers)

## W06-017 — usmb2 entry points that this build never calls, one of them unsafe if ever enabled

- **Category:** 1 (dead code) / 8 (half-finished features)
- **Locations:** `RiptOPL/modules/network/smb2man/usmb2/usmb2.c` (`usmb2_open`, `usmb2_opendir`, `usmb2_readdir` with the copy at `:792`, `usmb2_size` at `:1031`, `usmb2_init_context`, `usmb2_negotiateprotocol`); build defines in `RiptOPL/ps2.yaml` (smb2man target)
- **Problem:** The smb2man build defines `USMB2_FEATURE_WRITE, NTLM, UNICODE, STAT, MKDIR, UNLINK, RENAME` — but **not** OPENDIR — and compiles with `-ffunction-sections` + `--gc-sections`. smb2man.c's actual call set is: build_request, close, create, mkdir, pread, pwrite, rename, rmdir, sessionsetup, stat, treeconnect, unlink (grep-verified). So the directory-reading and several other vendored entry points are stripped at link time and cost nothing at runtime — but they sit in the source as an attractive nuisance: `usmb2_readdir()` memcpy's a server-controlled length (`OutputBufferLength`-derived `u32`) into the caller's dirent buffer with no clamp, and `usmb2_size()` returns `le64toh(*(uint32_t *)&buf[16])` — a 32-bit read widened to 64. If anyone defines OPENDIR to "finish" directory support, the readdir hole goes live as-is. Directory listing in smb2man.c is in fact implemented separately (its querydir path clamps lengths against `SMB2MAN_DIRBUF`, READ).
- **Fix:** Delete the unused entry points from the vendored copy (the folder already carries RiptOPL patches and documents them), or at minimum delete `usmb2_readdir`/`usmb2_size`. Do not "complete" OPENDIR support on top of this code.
- **Benefit:** Removes a latent wire-controlled overflow that is one `#define` away from shipping, and shrinks a vendored file to what the product uses.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ + build flags verified in ps2.yaml)

## W06-018 — httpclient carries the scaffolding of chunked transfer encoding that was never implemented

- **Category:** 8 (half-finished features) / 1 (dead code)
- **Locations:** `RiptOPL/modules/network/httpclient/httpclient.c:130` (`enum TRANFER_ENCODING`), `:160` (Transfer-Encoding handling)
- **Problem:** The header parser recognises `Transfer-Encoding:` and there is an enum for encodings, but chunked decoding was never implemented — responses are read purely by `Content-Length`. The dead scaffolding suggests chunked support exists when it does not; a chunked-only server silently yields a wrong/empty body rather than an error. READ.
- **Fix:** Delete the unused enum and the inert header branch, and (the only functional change) fail explicitly when a response is chunked instead of misreading it. Implementing chunked decoding is the "more" option and is not recommended without a concrete server that needs it.
- **Benefit:** The code stops advertising a capability it doesn't have; failure becomes loud instead of silent.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W06-019 — raudp leftovers: a write-only diagnostic counter and heartbeat fields kept for a removed feature

- **Category:** 1 (dead code) / 8 (redundant features)
- **Locations:** `RiptOPL/modules/network/raudp/raudp.c:771`, `:875`, `:924-925` (`ra_disc_us`); heartbeat sender in the same file
- **Problem:** `ra_disc_us` is accumulated in two places and read only by its own overflow guard — a counter that produces nothing ("retained for bounded diagnostic accounting", but nothing ever reads the account). Separately, the heartbeat packet permanently sends three zero fields whose only purpose is keeping a client parser happy for a badge-upload feature that no longer exists. READ.
- **Fix:** Delete the counter and its increments. Keep the heartbeat's wire layout (external parser) but drop the explanatory dead fields only if the parser tolerates it — if not, keep the zeros and delete just the counter; the finding's actionable half is the counter.
- **Benefit:** Small, honest shrink of a timing-sensitive discovery loop.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W06-020 — smap_udpbd's transmit holds its semaphore across the whole retry sleep loop

- **Category:** 5 (performance, structural only)
- **Locations:** `RiptOPL/modules/network/smap_udpbd/src/xfer.c:201-211`
- **Problem:** `smap_transmit()` takes `tx_sema` at entry and holds it across its `DelayThread(100)` retry loop, so one stalled transmit serialises every other sender for the full retry duration. The sibling implementation in `udpfs_smap/src/xfer.c` releases and re-acquires per attempt. This is a structural observation about lock scope in code READ in both files; no hardware behaviour is claimed.
- **Fix:** Match the sibling: drop the semaphore around the sleep and re-acquire for each transmit attempt.
- **Benefit:** A single slow frame stops blocking unrelated transmits in the udpbd stack.
- **Effort:** S · **Risk:** Med (concurrency change in a driver; needs on-hardware validation) · **Confidence:** Med (READ, structural)

## W06-021 — smap-ingame's low-level output copies a pbuf chain into a fixed frame buffer without a total-length check

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/network/smap-ingame/main.c:45-70`; buffer size at `RiptOPL/modules/network/smap-ingame/main.h:4`
- **Problem:** `SMapLowLevelOutput()` walks the lwIP pbuf chain `mips_memcpy`ing each segment into a static `FrameBuffer[MAX_FRAME_SIZE]` (1518 bytes) and only afterwards assigns `TotalLength = pOutput->tot_len`; the chain's total is never checked against 1518 first. In practice lwIP builds chains for a single frame, so tot_len should stay within the MTU — which is why this is INFERRED and low — but the function itself enforces nothing, and a chained/oversized pbuf (e.g. from a future lwIP option) overflows a static buffer.
- **Fix:** Check `pOutput->tot_len > MAX_FRAME_SIZE` once at entry and return `ERR_MEM`.
- **Benefit:** One comparison removes a static-buffer overflow at the network egress.
- **Effort:** S · **Risk:** Low · **Confidence:** Low (INFERRED)

---

## COVERAGE

### Read in full (via the file reader, every line)

- `nbns/nbns.c`, `nbns/main.c`
- `httpclient/httpclient.c`, `httpclient/main.c`
- `rapops/rapops.c`, `rapull/rapull.c`, `raudp/raudp.c`
- `smbinit/main.c`, `smbinit/smbauth.c`, `smbinit/md4.c`
- `smbman-ra/smb.c` (~1,650 lines, two reads), `smbman-ra/smb.h`, `smbman-ra/smb_fio.c`, `smbman-ra/smbman.c`, `smbman-ra/poll.c`, `smbman-ra/auth.c`, `smbman-ra/auth.h`, `smbman-ra/debug.h`
- `smb2man/smb2man.c` (two reads), `smb2man/usmb2/usmb2.c`, `smb2man/usmb2/usmb2.h`, `smb2man/usmb2/ntlm.c`, `smb2man/usmb2/unicode.c`, `smb2man/usmb2/hmac-md5.c`, `smb2man/ps2iop-compat.h`
- `nfsman/nfsman.c`, `nfsman/unfs4/unfs4.c`, `nfsman/unfs4/unfs4.h`, `nfsman/README.md`, `nfsman/unfs4/VENDORED.txt`
- `udpfs_shared/src/udpfs_core.c`, `udpfs_shared/src/udprdma.c`
- `udpfs_ministack/src/ministack_udp.c`, `ministack_ip.c`, `ministack_eth.c`, `ministack_arp.c`, `ministack_xchg.c`, `udptty.c`, `main.c`
- `udpfs_ioman/src/udpfs_ioman.c`, `udpfs_bd/src/udpfs_bd.c`, `udpfs_fhi/src/udpfs_fhi.c`, plus `main.c` of udpfs_bd, udpfs_ioman, udpfs_fhi, udpfs_smap, smap_udpbd
- `udpfs_smap/src/smap.c`, `udpfs_smap/src/xfer.c`
- `smap_udpbd/src/ministack.c`, `smap_udpbd/src/udpbd.c`, `smap_udpbd/src/udpbd.h`, `smap_udpbd/src/xfer.c`
- `smap-ingame/xfer.c`, `smap-ingame/main.c`, `smap-ingame/main.h`
- `udpfs_bd/src/udpfs_packet.h`, `udpfs_bd/src/udpfs_core.h`, `udpfs_bd/src/udprdma_seq.h`
- Root `ps2.yaml` build sections for smb2man/nfsman/smbman-ra/nbns (via grep/sed)

### Compared by command (diff / md5sum / wc), conclusions drawn from the tool output

- All udpfs edition trees: per-file `md5sum` census (identical headers, wrappers, main.c identity), `wc -l` per directory (smbman-ra 4763, smb2man 4210, smbinit 938, nfsman 2625, nbns 456, httpclient 571, rapops 167, rapull 420, raudp 1327, smap-ingame 1268, smap_udpbd 2285, udpfs family 7912 combined).
- `smbinit/des.c` vs `smbman-ra/des.c`, `smbinit/md4.c` vs `smbman-ra/md4.c`, `smbinit/smbauth.c` vs `smbman-ra/auth.c` (diffs: 119 / small / 113 lines).
- `udpfs_smap/src/smap.c` vs `smap_udpbd/src/smap.c` (25 diff lines) and vs `smap-ingame/smap.c` (large diff — read directly instead, see below).
- `udpfs_ministack/src/udptty.c` vs `smap_udpbd/src/udptty.c` (4 diff lines).

### In-scope files NOT read in full, with reason

- `smbinit/des.c` and `smbman-ra/des.c`, `smbman-ra/md4.c`: standard DES/MD4 bodies; assessed via full `diff` against their sibling copies (the duplication finding needs the diff, not a line-by-line read of a textbook cipher). No line-level claims are made about their internals.
- `smb2man/usmb2/md4c.c`, `smb2man/usmb2/md5.c`: vendored RFC reference implementations; head + targeted grep only. No findings rest on their internals.
- `smap-ingame/smap.c` (651 lines): read via structured diff against `udpfs_smap/src/smap.c` plus targeted greps (interrupt masks, REV check, link-check timer). It is a genuinely different older variant; no line-level finding cites it (W06-021 cites smap-ingame/main.c, read in full).
- `smap_udpbd/src/smap.c`: read via full diff against `udpfs_smap/src/smap.c` (25 differing lines, all inspected) rather than a separate full read.
- `smap_udpbd/src/udptty.c`: assessed via diff (4 lines) against the udpfs_ministack copy, which was read in full.
- `udpfs_shared/tests/` (982 lines across 4 host tests) and `udpfs_ioman/tests/test_ack_sequence.c`: headers/first sections read; they are host-side test harnesses, not shipped IRX code, and no finding depends on their bodies.
- Remaining headers (`udpfs_*/include/*.h` beyond those listed, `smap_udpbd` headers, `smbman-ra/smb_fio.h`, `des.h`, `md4.h`), `exports.tab`, `imports.lst`, `irx_imports.h`, per-directory Makefiles, READMEs/ORIGIN notes: skimmed via `wc`/targeted grep where relevant (e.g. Makefile source lists, the smbman-ra Makefile header comment); these are declarations/build glue with no length/offset logic, and no finding cites them.
- `modules/network/common/httpclient.h` and `include/nbns.h`: outside the assigned scope (common/include), read only as context for W06-007/W06-008; no findings filed against them.

### Judged clean / careful after reading (no finding)

- `smb2man/smb2man.c` front end: bounded copies throughout, generation-tagged handles; its querydir path clamps server lengths.
- `smb2man/usmb2/ntlm.c`: carries explicit RiptOPL bounds checks.
- `nfsman` + `unfs4`: reply parsing bounds-checked (the vendored pin is literally an upstream bounds-fix commit); readdir/getattr/prw all validate against received length.
- `smap_udpbd/src/udpbd.c`: RDMA sizes checked against remaining read size; the write-done error-as-success behaviour is deliberate and commented.
- `udpfs_ministack/src/ministack_xchg.c`: validates UDP/IP lengths — the in-tree contrast for W06-005.
- `rapull/rapull.c` (beyond W06-011) and `rapops/rapops.c`: bounded parsing throughout.
- `smbman-ra/smb.c` WriteAndX path: already hardened — cited as the model for W06-003, not as a finding.
