# Verification W3 — RiptOPL Category 6, IOP modules/ findings (ROUND9-MODULES)

- **Clone:** `~/workspace/audit-clones-2026-11-13/RiptOPL`, pin verified at start and at end: `git rev-parse HEAD` = `2e347d5ac885cd0ff73e9ad4143781946396f492`; clone left git-clean (read-only throughout).
- **Scope:** RIPTOPL-400 … RIPTOPL-412 (all in `Sable-RiptOPL-ROUND9-MODULES.md`, IOP `modules/` code).
- **Method:** every cited path:line re-read at the pin; mechanisms re-derived from the code, including caller/upstream context (SMB reply path, BDM mount path, ps2ips' linked stack, HDPro's sibling driver, whole-tree greps for `LWIP_ARP` / `etharp_tmr`).

## Verdict table

| ID | Verdict | One-line evidence (path:line) |
|---|---|---|
| RIPTOPL-400 | VERIFIED | `modules/network/smbman-ra/smb.c:1477,1480,1482,1498` — `ParamOffset`/`DataOffset` (u16, `smb.h:343,345`) index the 4,224-byte `SMB_buf` (`smb.c:43`, `smb.h:894-895`) and `FileNameLen` (u32) feeds `getStringField` (`smb.c:336-352`) with no check against the length `GetSMBServerReply` returned |
| RIPTOPL-401 | VERIFIED | `modules/network/smbman-ra/smb.c:404` calls `getStringField(..., 0)`; the `inbytes == 0` non-Unicode branch is a plain `strcpy` at `smb.c:346-347` (Unicode branch loops to a NUL wchar via `utf16ToAscii`, `smb.c:340-341`); destination is `char PrimaryDomainServerName[64]` at `smb.h:285`, followed by `EncryptionKey[8]` at `smb.h:286` |
| RIPTOPL-402 | VERIFIED | `modules/isofs/zso.c:111` calls `LZ4_decompress_fast(ziso_tmp_buf, addr, 2048)` and discards the return; `lz4.c:505` (non-MSVC) instantiates the generic decoder with `endOnOutputSize` + `withPrefix`, so the `ref < dest` check at `lz4.c:442` is skipped and the input-length loops at `lz4.c:408-413,447-454` are unbounded; header warning at `lz4.h:117-126` |
| RIPTOPL-403 | VERIFIED-DRIFT | `modules/network/SMSTCPIP/sockets.c:180-183` — `lwip_accept()` passes `netconn_accept()`'s result straight to `netconn_peer()` with no NULL check; NULL is manufactured by `err_tcp` at `api_msg.c:203-208`; corrected locations for the two `api_lib.c` citations below |
| RIPTOPL-404 | VERIFIED | `modules/bdm/src/part_driver_gpt.c:84-94` — `entryCount = pGptHeader->partition_count` (u32, `gpt_types.h`) is clamped only inside the plausible-extent branch; the fallback keeps the raw count with `stopAtUnused = 1`, and the scan loop at `:98,117` reads one sector per `entriesPerSector` entries, continuing past every non-zero-GUID entry that fails the LBA check (`continue` at `:133`, check at `:130`) |
| RIPTOPL-405 | WEAKENED | `modules/iopcore/cdvdman/device-hdd.c:80` assigns to `static unsigned char NumParts` (`device-hdd.c:20`), not verbatim into an `int` — the 65-entry walk at `device-hdd.c:35` overflows only when the truncated value lands in 66–255 (see subsection) |
| RIPTOPL-406 | VERIFIED | `modules/hdd/apa/src/journal.c:47-56` — `apaJournalWrite` transfers to sector `(journalBuf.num << 1) + APA_SECTOR_APAL_HEADERS` and stores `sectors[journalBuf.num]` with no bound against the 126-entry array (`libapa.h:184-189`); `-n` is unbounded at `modules/hdd/apa/src/hdd.c:263-271` and `apaCacheFlushAllDirty` calls it once per dirty entry (`cache.c:111-126`) — latent exactly as the finding itself caveats (in-tree loader passes `-n 20`, `src/sources/hddsupport.cpp:939-945`) |
| RIPTOPL-407 | VERIFIED | `modules/usb/usbmass_bd/src/usb_mass.c:674-681` — `epCount = interface->bNumEndpoints` (device byte) and the walk advances `endpoint += endpoint->bLength` with no `bLength` minimum and no bound against `config->wTotalLength`, calling `usb_bulk_probeEndpoint` (`usb_mass.c:560-578`, opens pipes) on each landing point |
| RIPTOPL-408 | WEAKENED | The unchecked sinks are exactly as cited (`modules/usb/usbmass_bd/src/scsi.c:321,156,174,244,261`), but in-tree reachability is gated: the menu BDM refuses every `sectorSize != 512` before offering the device to any driver (`modules/bdm/src/bdm.c:169-180`) — see subsection |
| RIPTOPL-409 | VERIFIED | `modules/network/ps2ips/ps2ips.c:402-418,435-451` — `s_offset = 64 - pkt->malign`, `memcpy(lwip_buffer + s_offset, pkt->malign_buff, pkt->malign)` and `sceSifGetOtherData(..., sendlen - pkt->malign, ...)` with no range check on `malign`, `length`, or their relationship in either handler; buffer headroom design at `ps2ips.c:84` |
| RIPTOPL-410 | VERIFIED-DRIFT | Negative-length arithmetic inversion is real, but the finding's cited ranges are the wrong blocks: the `srest`/`s_offset`/`recvlen` code is at `ps2ips.c:167-186` (`do_recv`) and `ps2ips.c:296-315` (`do_recvfrom`), not `:183-207` / `:330-344`; in-tree stack behaviour checked and confirms a conditional overflow (see subsection) |
| RIPTOPL-411 | VERIFIED-DRIFT | `modules/iopcore/cdvdman/hdpro_atad.c:692-725` — chunk loop advances only on success (advance at `:721-724`), `continue` on any error at `:717,719`, comment at `:714`, semaphore taken at `:684` and released only at `:730`; the sibling retry cap the finding cites is at `atad.c:700-719`, not `:728-746` (see subsection) |
| RIPTOPL-412 | VERIFIED-DRIFT | Whole-tree grep: `LWIP_ARP` is never defined (only uses: `timers.c:103,117,122,124` guards and the never-expanded fallback at `include/lwip/opt.h:138`; no `-DLWIP_ARP` in `SMSTCPIP/Makefile`), and `etharp_tmr`'s only caller is inside the guard at `timers.c:110-116` — mechanism holds; several supporting line citations drifted (see subsection) |

**Counts: VERIFIED 7 (400, 401, 402, 404, 406, 407, 409) · VERIFIED-DRIFT 4 (403, 410, 411, 412) · WEAKENED 2 (405, 408) · REFUTED 0.**

## Full reasoning — non-VERIFIED verdicts

### RIPTOPL-403 — VERIFIED-DRIFT (two of three `api_lib.c` citations are off; chain otherwise exact)

The mechanism chain re-derives completely:

- `lwip_accept()` at `sockets.c:164-215`: `newconn = netconn_accept(sock->conn)` at :180, then `netconn_peer(newconn, &naddr, &port)` at :183 with no NULL check; the first NULL guard in the function is the `alloc_socket()` check at :196-201, exactly as the finding's fix describes.
- `err_tcp()` is registered for every TCP PCB by `setup_tcp` (`api_msg.c:214-225`, `tcp_err(pcb, err_tcp)` at :224) and posts NULL to the accept mbox at `api_msg.c:203-208` (the `sys_mbox_post(conn->acceptmbox, NULL)` is at :207). The finding cited `api_msg.c:202-213` for this — the function actually spans :184-212; the cited range covers the post, so this citation stands.
- `netconn_accept()` returns whatever the mbox yields, NULL included, with no filtering.

The drift is confined to `api_lib.c`: the finding cites `netconn_peer()` at `api_lib.c:243-270` — it actually spans **:235-259** (`switch (conn->type)` at :238, so a NULL `conn` dereferences immediately, as claimed) — and `netconn_accept()` at `api_lib.c:395-408` — it actually spans **:384-398** (`sys_mbox_fetch` at :392). Mechanism, reachability, and fix unchanged.

### RIPTOPL-405 — WEAKENED (the count is truncated to `unsigned char` first; trigger set is narrower than "exceeds 65")

What holds, READ: `hdl_apa_header.num_partitions` is an `int` on disc (`modules/iopcore/cdvdman/atad.h:96`); `cdvdman_get_part_specs` loops `for (ps = cdvdman_partspecs, i = 0; i < NumParts; i++, ps++)` at `device-hdd.c:35` over the 65-entry × 12-byte static table (`HDL_NUM_PART_SPECS 65` defined at `atad.h:84`, `part_specs[65]` at `atad.h:97`); the `memcpy` at `device-hdd.c:75` copies only `sizeof(cdvdman_partspecs)`, so entries past 65 are adjacent BSS treated as partition offset/size and fed to ATA LBAs in `DeviceReadSectors` (`device-hdd.c:111-133`). No clamp exists anywhere in the file.

What the finding gets wrong: it says the value is "an `int` read verbatim" and overflows "if it exceeds 65". The destination is `static unsigned char NumParts;` at **`device-hdd.c:20`** — a declaration the finding never cites. The assignment at :80 therefore truncates modulo 256 before the walk ever sees the value. Precise trigger set: the walk passes the table **iff `(unsigned char)num_partitions ∈ [66, 255]`** — i.e. raw values 66–255, 322–511, …, and negative values that map into that range (e.g. −1 → 255). Raw values the finding's wording claims as triggers but which do **not** overflow include 256, 512, 321 (= 65 after truncation), and any value ≡ 0–65 (mod 256). The defect is real and easily reached by a crafted header (66 alone suffices), so this is WEAKENED, not refuted — but the finding's arithmetic and its proposed clamp rationale ("reject `< 0`" on the raw int) misdescribe the actual variable. Minor drift in passing: the static array is at `device-hdd.c:22`, not :24.

Cross-reference for the parent's duplicate census: this is substantially a re-file of **RIPTOPL-149** (Round 5), which filed the same walk with the truncation framing stated correctly in its title ("stored truncated into a `u8`"). RIPTOPL-405 neither cites it nor improves on it; its one new claim (verbatim `int`) is the part that is wrong.

### RIPTOPL-408 — WEAKENED (sinks unchecked as cited, but the in-tree BDM layer refuses every non-512 sector size before any driver sees the device)

What holds, READ, end-to-end in `modules/usb/usbmass_bd/src/scsi.c`: `bd->sectorSize = getBI32(&rc10d.block_length)` at :244 is checked only `!= 0` (:246-249), and the READ CAPACITY(16) replacement at :261 is likewise only required non-zero (condition at :259). `scsi_write`'s misalignment path does `__builtin_alloca(sectorSize + 4)` at :321 and `memcpy(misalign_buffer, buffer, sectorSize)` at :334; `scsi_cmd_rw_sector` computes `bd->sectorSize * sectorCount` (unsigned 32-bit product) at :156 and :174. No range check exists in this file — and the sibling iLink driver in the same tree does have one (`modules/ilink/IEEE1394_bd/src/scsi.c:268` rejects `sectorSize == 0 || sectorSize > XFER_BLOCK_SIZE`, RC16 path at :285), so the omission is real, not a tree-wide convention.

What defeats the claimed consequences at this pin is the caller context the finding did not trace. The USB bd's only in-tree registration is `scsi_connect` → `scsi_warmup` → `bdm_connect_bd(bd)` at `scsi.c:397-398`; no other in-tree code calls this bd's `read`/`write` (`bdmevent` only reads fields via `bdm_get_bd`). On the menu side, `bdm_try_mount` at `modules/bdm/src/bdm.c:169-180` returns **before offering the device to any filesystem or partition driver** (the GPT/MBR drivers are registered as filesystems, `part_driver.c:133,140`) whenever `mount->bd->sectorSize != 512`, and `bd_cache_create` likewise returns NULL for non-512 at `modules/bdm/libbdm/src/bd_cache.c:210-211`. On the in-game side, cdvdman's `bdm_connect_bd` (`modules/iopcore/cdvdman/device-bdm.c:95-109`) attaches only the launch-matching device — and a game can only be launched from a device the menu enumerated, which required a successful (512-only) mount. For the one surviving value, 512, the sinks are harmless: `alloca(516)`, and with `max_sectors = 128` (`usb_mass.c:846`) the products are ≤ 65,536.

Narrowed conditions under which the finding still bites: only if `scsi_read`/`scsi_write` are ever invoked on a non-512 device — i.e. if the BDM refusal at `bdm.c:169` is relaxed (its own comment at `bdm.c:160-168` frames non-512 support as the thing being deferred, so 4K-sector support is the obvious future change that re-opens this), or if `usbmass_bd` is reused outside this BDM. As filed — a device "reporting a huge block length makes any misaligned-buffer write alloca that much stack" — the write cannot occur in-tree at the pin. Verdict WEAKENED; the proposed capacity-parse check remains the right place to fix it, because it removes the hazard at the layer that will outlive the BDM gate.

### RIPTOPL-410 — VERIFIED-DRIFT (cited ranges point at the wrong blocks; the in-tree stack confirms a conditional, not unconditional, overflow)

The arithmetic inversion is READ and exact, at corrected locations:

- `do_recv`: `if (recv_pkt->length <= 64) srest = recv_pkt->length;` at `ps2ips.c:167-169`, `s_offset = 64 - srest` at :179, `recvlen = MIN(BUFF_SIZE, recv_pkt->length)` at :180, receive calls at :186-188. The finding cited `:183-207` — that range is the RA peek comment and the `rlen > 64` tail block, not the `srest` computation.
- `do_recvfrom`: the same computation at `ps2ips.c:296-309`, receive calls at :313-317. The finding cited `:330-344` — that range is the `abuffer`/`erest` block inside `if (rlen > 64)`.

With `length = -k` (k > 0): `srest = -k`, `s_offset = 64 + k`, `recvlen = -k`, and a negative length is passed to `recv`/`recvfrom`, as claimed. The finding left the stack's handling INFERRED; the in-tree stack ps2ips actually imports (`I_lwip_recv*`, `modules/network/ps2ips/imports.lst`) settles it, and it is narrower than "destination pushed outside the headroom ⇒ overflow":

- `lwip_recv` (`modules/network/SMSTCPIP/sockets.c:481-484`) forwards the `int len` to `lwip_recvfrom` (`sockets.c:353`), where a negative `plen` is never clamped (`plen > avail_len` at :418 is false for negative `plen`).
- The copy itself, `netbuf_copy_partial` (`api_lib.c:92-130`), takes `u16_t len` (:93), so −k arrives as 65536−k — but its loop (:102-122) is bounded by the pbuf chain, so the bytes actually written at `lwip_buffer + 64 + k` equal the received chain length, no more.
- Net effect: the 1,088-byte `lwip_buffer` (`ps2ips.c:84`) overflows **iff the received chain exceeds `1024 − k` bytes** (e.g. a ~1,460-byte datagram/segment with a small negative length overruns into the adjacent `rests` static at `ps2ips.c:85`); a short payload fits despite the inverted offset and the visible damage is instead the wrapped return accounting (`copylen` is `u16_t`, `sockets.c:358,422`). The missing lower bound and the fix are exactly as filed; only the unconditional-overflow framing and the line citations do not survive.

### RIPTOPL-411 — VERIFIED-DRIFT (HDPro mechanism exact; the sibling-driver citation points at the wrong function tail)

Re-derived in `modules/iopcore/cdvdman/hdpro_atad.c`: `sceAtaDmaTransfer` takes `ata_io_sema` at :684 (`WAITIOSEMA`), then `while (nsectors)` at :692 retries the same chunk — `continue` at :717 on `sceAtaExecCmd` failure and at :719 on `sceAtaWaitResult` failure, under the comment at :714 ("Unlike ATAD, retry indefinitely until the I/O operation succeeds") — and advances `buf`/`lba`/`nsectors` only at :721-724, after both calls succeed. The semaphore is released only at :730, after the loop (the `hdpro_io_start` failure path at :686-690 does release it — that is an entry failure, not a transfer error, and does not affect the claim). A persistent error therefore spins the same chunk forever, semaphore held, exactly as filed. The finding's cited range :690-722 covers the loop, comment, and both `continue`s (the loop actually ends at :725).

The drift is the supporting citation: the finding places atad.c's capped retry at `atad.c:728-746`. Those lines are the end of `sceAtaDmaTransfer`'s return, `sceAtaInit`, and the start of `ata_set_dir`. The actual sibling policy is at **`atad.c:700-719`**: `for (retries = 3; retries > 0; retries--)`, breaking on any result other than `ATA_RES_ERR_ICRC` (:717-718), inside the outer `while (res == 0 && nsectors > 0)` at :673. Substance of the comparison unchanged.

### RIPTOPL-412 — VERIFIED-DRIFT (grep claim fully confirmed; four supporting citations drifted)

The headline claim was tested the way the finding says it was derived, and it holds:

- Whole-tree grep for `LWIP_ARP`: the only hits are the guards at `modules/network/SMSTCPIP/timers.c:103,117,122,124` and `MEMP_NUM_SYS_TIMEOUT (LWIP_TCP + LWIP_ARP)` at `include/lwip/opt.h:138`. There is no `#define LWIP_ARP` in `opt.h`, in `include/lwipopts.h`, or anywhere else in the tree, and no `-DLWIP_ARP` in `SMSTCPIP/Makefile` (flags at Makefile:17-43 are `LWIP_NOASSERT`/`INGAME_UDP`/`INGAME_DRIVER`/`INTERRUPT_CTX_INPKT`/`FULL_LWIP`). The `opt.h:138` use never even expands: it sits inside `#ifndef MEMP_NUM_SYS_TIMEOUT` (:137), and `lwipopts.h` (included at `opt.h:36`) always defines that macro first.
- Whole-tree grep for `etharp_tmr`: definition at `etharp.c:209-229`, declaration at `include/netif/etharp.h:92`, and the sole call at `timers.c:114` inside `arp_timer` (:110-116), itself and its `sys_timeouts_init` registration (:122-124) both inside `#if LWIP_ARP` — i.e. compiled out, since an undefined macro in `#if` is 0. `etharp_tmr`'s body (ctime increment, STABLE expiry at `ARP_MAXAGE`, PENDING expiry at `ARP_MAXPENDING`, `etharp.c:214-228`) is dead, and `find_arp_entry` (`etharp.c:236-281`) can indeed only recycle EMPTY or STABLE entries, so a PENDING entry for a dead host wedges its slot permanently on a 2–4-entry table.

The drifted supporting citations (mechanism unaffected in each case):

- `ARP_MAXAGE`/`ARP_MAXPENDING` are defined at **`etharp.c:96-98`** (120 and 2, in 10-second units — the 20-minute / 20-second values in the finding are right); `etharp.c:105-108` is ARP message-type macros.
- `ARP_TABLE_SIZE` values are at **`lwipopts.h:198-214`** (4 for `INGAME_UDP`, 2 for other in-game, 3 otherwise); the finding cited `lwipopts.h:238-248`.
- `MEMP_NUM_SYS_TIMEOUT` is at **`lwipopts.h:87-94`** (2 for `INGAME_UDP` — commented "ARP for the PC client plus SMB" — and 1 otherwise, which is the build the finding's fix says to raise); the finding cited `lwipopts.h:121-125`, which is the `MEMP_NUM_TCPIP_MSG` comment block.
- `sys_timeout()`'s silent drop on an empty pool is at **`timers.c:145-149`** (`memp_malloc` NULL → assert + return); the finding cited `timers.c:170-174`, which is the timeout-list insertion loop.

## Cross-reference notes (not verdicts)

- **RIPTOPL-406 vs RIPTOPL-147:** RIPTOPL-406 presents itself as distinct from RIPTOPL-147 ("journal *restore*"), but RIPTOPL-147's body (Round 5) already covers the write side explicitly — "`apaJournalWrite` increments past 126 if more than 126 headers are ever flushed in one pass — today bounded only by the loader-controlled cache size" — and names the same fix. The mechanism in 406 is verified; the novelty claim is not.
- **RIPTOPL-400/401 vs RIPTOPL-145:** the receive path underneath both findings (`GetSMBServerReply` receiving the server-claimed session length into `SMB_buf` uncapped, `smb.c:226-267`) is already filed as RIPTOPL-145 (Round 5). It does not defeat 400/401 — a packet that fits the buffer can still carry the malicious offsets/domain string — but any fix round should sequence 145 first, since it bounds what 400/401's parsers can be fed.

## New defect candidates

None. Candidates encountered during re-derivation were checked and cleared:

- The uncapped session-length receive in `GetSMBServerReply` (`smb.c:257-263`) looked new from inside the Round-9 file; it is already RIPTOPL-145 (Round 5) — see cross-reference note above.
- `scsi_warmup`'s diagnostic prints divide by `(1000 * 1000) / bd->sectorSize` and `(1024 * 1024) / bd->sectorSize` (`modules/usb/usbmass_bd/src/scsi.c:253-254,266-267`), which are zero for a reported block length above ~1 MB — the same pattern `modules/bdm/src/bdm.c:55-58` says was fixed there for exactly such a device. Not filed: the sink is a log print only, and the effect of a zero divisor on this path (32-bit MIPS divide vs the 64-bit libgcc divide of `sectorCount`) could not be established from the code alone at this pin, so claiming a trap would be inventing the mechanism.
- `lwip_accept`'s `*addrlen` dereference at `sockets.c:191` with no NULL check on `addr`/`addrlen` is a distinct wart in RIPTOPL-403's function, but its only in-tree caller chain (ps2ips `do_accept`, `ps2ips.c:87-101`) always passes both pointers, so no reachable defect was established.
