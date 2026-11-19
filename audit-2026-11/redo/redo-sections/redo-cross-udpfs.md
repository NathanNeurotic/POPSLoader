# REDO — Cross-repo: UDPFS / UDPRDMA / UDPBD wire & protocol parity

Independent blind redo. Derived only from the clones below; nothing under
`~/workspace/Sable-audit/` was read, listed, or grepped.
READ-ONLY in the clones; all scripts ran in `/tmp`.

Pins verified with `git rev-parse HEAD` before use:

| Clone | HEAD |
|---|---|
| RiptOPL | `2e347d5ac885cd0ff73e9ad4143781946396f492` |
| Launchstation | `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` |
| POPSLoader | `29272cddbf0122f14e76bc3bdd75e3b46aa870be` |
| Simple-Media-System | `e65ced39a27eee8d996e9257e21594d1cac1c93d` |
| PS2-Servers | `c5f021c4d38698860f56b03498adc261dbb8d8dd` |

Headline verdict: **the wire layouts are identical everywhere they overlap** —
same UDPRDMA framing, same UDPFS opcode numbers, same packed struct field
order/sizes, same standalone-UDPBD v2 framing — in C, Python, and Go. Every
divergence found is in **validation of wire-controlled values, error/EOF
semantics, reply-field population, or stale duplicate copies**, not in layout.
The recurring pattern is one-directional: one implementation already contains
the fix and its sibling does not (SMS hardened the client receive path;
RiptOPL hardened the client send/EOF path; PS2-Servers' current Python and Go
servers hardened the server path — while a pre-hardening Python server still
ships inside RiptOPL).

---

## (a) Implementation census

### UDPFS / UDPRDMA — PS2 (IOP) clients

| # | Implementation | Evidence (size / sha256[:12]) |
|---|---|---|
| C1 | RiptOPL shared client core — one real implementation, used by the `udpfs_bd`, `udpfs_fhi`, `udpfs_ioman` IRX variants. `modules/network/udpfs_shared/src/udpfs_core.c` (22,552 B, `767e7775a5ee`, 791 lines), `…/src/udprdma.c` (25,579 B, `e42ab6c4e4fb`, 738 lines). Per-variant dirs hold only 125 B shim `udpfs_core.c`/`udprdma.c` (`60fb5b8039b2` / `696de479970a`) that `#include` the shared files, plus byte-identical header copies (see UDPFS-10). | hashes above |
| C2 | SMS fork of the same client, single merged module (bd+fhi+ioman in one tree): `iop/SMSUdpfs/udpfs/src/udpfs_core.c` (24,927 B, `69c74fed51bf`, 825 lines), `…/src/udprdma.c` (30,212 B, `b7a3a02e347e`, 804 lines), `udpfs_packet.h` (10,141 B, `b5a12a1526a5`), `udprdma_packet.h` (4,278 B, `0eb022e59505`). Layout-identical to C1; behaviour diverges (UDPFS-01…06). | hashes above |
| C3 | Launchstation: **no UDPFS client source**. It ships the SMAP driver source (`iop/udpfs_smap/`, Neutrino-pinned, see T3) and precompiled IRXs: `iop/__precompiled/udpfs_ioman.irx` (11,633 B, `85faad5631fa`), `udpfs_ministack.irx` (5,025 B, `854060627190`), `udpfs_smap.irx`. No `udpfs_packet.h`/`udpfs_core.c` anywhere in the repo. | hashes above |
| C4 | POPSLoader: **no UDPFS client source** — the same precompiled binaries as C3: `iop/embed/udpfs_ioman.irx` (11,633 B, `85faad5631fa` — byte-identical to Launchstation's), `udpfs_ministack.irx` (`854060627190`), `udpfs_net_smap.irx` (8,081 B), plus `docs/UDPFS_BDMA.md`. SMS's own prebuilt `irx/udpfs_ioman.irx` differs (11,393 B, `6e7776fd4a91`), consistent with it being built from C2 source. | hashes above |
| — | EE sides (RiptOPL `src/sources/udpfssupport.cpp`, SMS `src/SMS_FileContext.c`, Launchstation `src/filer*.c`) contain **no wire code**: they talk to the IOP module through the normal file-I/O interface. The wire protocol exists only on the IOP side and the servers. | grep census |

### UDPFS servers

| # | Implementation | Evidence |
|---|---|---|
| S1 | PS2-Servers Python (current, "Desktop/Core"): `udpfs_server/udpfs_server.py` (161,088 B, `5f31f4cc204d`, 3,643 lines) + session/negotiation shim `udpfs_server/ps2servers_core.py` (31,195 B, `a814b9bc2a2d`, 690 lines) | hashes above |
| S2 | PS2-Servers Go ("Edge"): `native/ps2servers-edge/internal/protocol/packet.go` (4,561 B, `0e13d1927dff`), `internal/udpfs/operations.go` (25,208 B, `4f9a6153648c`), `…/blockdev.go` (14,938 B, `4889f8aa0ca7`), `…/server.go`, `…/negotiation.go`, `…/transfer.go` | hashes above |
| S3 | **Stale duplicate of S1's ancestor shipped inside RiptOPL**: `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/udpfs_server/udpfs_server.py` (70,304 B, `efe7aae51253`, 1,843 lines) — a full server copy, pre-dating every S1/S2 hardening (UDPFS-07). | hash above |

### Standalone UDPBD (v2, separate protocol from the UDPFS BREAD/BWRITE subset)

| # | Implementation | Evidence |
|---|---|---|
| B1 | RiptOPL IOP client: `modules/network/smap_udpbd/src/udpbd.h` (3,010 B, `3d0346f0d05e`), `…/src/udpbd.c` (15,470 B, `e2bf5d18607d`, 507 lines), `…/src/ministack.c`, `…/src/smap.c` | hashes above |
| B2 | PS2-Servers Python server: `udpbd_server/udpbd_server.py` (21,096 B, `5c32a87beefc`, 462 lines) | hash above |
| B3 | PS2-Servers Go server: `native/ps2servers-edge/internal/udpbd/protocol.go` (3,993 B, `9b7e154fb097`), `…/server.go` (15,961 B, `fa6bd77bcbaf`, 555 lines) | hashes above |
| — | No standalone-UDPBD code in Launchstation, POPSLoader, or SMS. Their "UDPBD" is only the UDPFS BREAD/BWRITE subset (C1/C2) plus Neutrino config files (e.g. RiptOPL `ship/neutrino/bsd-udpbd.toml`). SMS has no `smap_udpbd` equivalent. | find census |

### Transport underneath (SMAP RX FIFO — carries every UDPFS packet)

| # | Implementation | Evidence |
|---|---|---|
| T1 | RiptOPL `modules/network/udpfs_smap/src/xfer.c` (9,812 B, `236c36732cba`) — includes the odd-tail fix (UDPFS-04) | hash above |
| T2 | SMS `iop/SMSUdpfs/smap/src/xfer.c` (10,468 B, `02ca64058b45`) — `smap.c` is byte-identical to RiptOPL's (`6fdfcab6836e`, 25,205 B) but `xfer.c` is **not** (UDPFS-04) | hashes above |
| T3 | Launchstation `iop/udpfs_smap/src/xfer.c` (9,310 B, `1d0234fe4943`) — carries the same tail fix as T1 (its `ORIGIN.md` documents it); `smap.c` 25,207 B, `82e190cd1813` | hashes above |

---

## (b) Wire parity tables

### UDPRDMA framing (all implementations)

| Field | C (RiptOPL `udprdma_packet.h`, SMS identical modulo whitespace) | Python S1 (`udpfs_server.py:475–530`) | Go S2 (`protocol/packet.go`) | Verdict |
|---|---|---|---|---|
| Base header, 2 B LE | `packet_type:4` low, `seq_nr:12` | `val & 0xF`, `(val>>4) & 0xFFF` (:480–489) | `Header.Marshal/ParseHeader` masks `0xF`/`0x0FFF` | **Identical** |
| Packet types | DISCOVERY 0, INFORM 1, DATA 2 | same | same | Identical |
| Data flags | ACK `1<<0`, FIN `1<<1` | same | `FlagACK=1, FlagFIN=2` | Identical |
| Service / port | SVC `0xF5F5`, port `0xF5F6` | `0xF5F5` / `0xF5F6` (:178–179) | `ServiceUDPFS 0xF5F5`, `DefaultPort 0xF5F6` | Identical |
| Data header, 4 B LE | `seq_nr_ack:12, flags:2, hdr_word_count:4, data_byte_count:14` | same bit split (:516–530) | same bit split in `DataHeader.Marshal` | Identical |
| Max payload | `UDPRDMA_MAX_PAYLOAD 1408`; app header ≤ 32 B on send (`UDPRDMA_MAX_APP_HDR`) | `MAX_DATA_PAYLOAD 1408` (:227) | `MaxPayload 1408`; reply header rejected if > 60 B (`transfer.go:138`) | Identical on the wire; note C *receive* path allows `hdr_word_count` up to 15 ⇒ 60 B into buffers sized 8/32 B (UDPFS-01) |
| Discovery header, 4 B | `service_id:16` + field named **`reserved` — "must be 0"** | `DiscHeader(service_id, port)` — second field is the **data port** (:492–504, sent at :2655–2656) | `DiscoveryHeader{ServiceID, Port}` | **Layout identical, name/semantics divergent** (UDPFS-12) |
| Timeouts / retries (not wire, affects interop) | ACK coalesce 100 ms, retx 500 ms, discovery 2 s, `UDPRDMA_MAX_RETRIES 4` | window-ACK wait retries **200** (`MAX_WINDOW_RETRIES`, :275) | server-side equivalents internal | Client retry behaviour diverges between C1 and C2 (UDPFS-05/06) |

### UDPFS application messages (opcode = first payload byte)

Opcodes — **identical in all four sources** (C1 `udpfs_packet.h:29–52`,
C2 same, S1 `MsgType` :195–215, S2 `protocol/packet.go` MessageType consts):
OPEN `0x10`, OPEN_REPLY `0x11`, CLOSE `0x12`/`0x13`, READ `0x14`,
WRITE `0x16`, WRITE_DATA `0x17`, WRITE_DONE `0x18`, LSEEK `0x1A`/`0x1B`,
DREAD `0x1C`/`0x1D`, GETSTAT `0x1E`/`0x1F`, MKDIR `0x20`, REMOVE `0x22`,
RMDIR `0x24`, RESULT_REPLY `0x26`, BREAD `0x28`, BWRITE `0x2A`.
`0x15`, `0x19`, `0x21`, `0x23`, `0x25`, `0x27`, `0x29` unused everywhere.

Struct layouts — field-by-field identical (C packed structs vs Python
`struct.pack` formats vs Go fixed offsets):

| Message | Size | Layout (offsets) | C | Python S1 | Go S2 |
|---|---|---|---|---|---|
| OPEN_REQ | 8 + path | type, is_dir, flags u16, mode i32, path[] | ✓ | `<BBHi` (:1795) | `operations.go` open handler |
| OPEN_REPLY | 36 | type, res[3], handle i32 @4, mode @8, size @12, hisize @16, ctime[8] @20, mtime[8] @28 | ✓ | `<BBBBiIII` + ctime + mtime (:3056–3062) | 36 B buffer, same offsets (:464–472), **times left zero** (UDPFS-11) |
| CLOSE_REQ / REPLY | 8 | type, res[3], handle/result i32 @4 | ✓ | `<BBBBi` (:3070) | `result8` |
| READ_REQ / WRITE_REQ | 12 | type, res[3], handle @4, size u32 @8 | ✓ | `<BBBBiI` (:1975, :2038) | :492ff, :553ff |
| WRITE_DATA | 8 + data | type, res, chunk_nr u16 @2, chunk_size u16 @4, total_chunks u16 @6 | ✓ | `<BBHHH` (:2089) | `msg[2:4]/[4:6]/[6:8]` (:603–605) |
| WRITE_DONE | 8 | type, res[3], result i32 @4 | ✓ | `<BBBBi` (:3094) | `result8` (:689ff) |
| LSEEK_REQ | 16 | type, whence, res u16, handle @4, offset_lo @8, offset_hi @12 (both signed i32 in C) | ✓ | `<BBHiii` (:2195) | u32 lo/hi recombined (:703–705) |
| LSEEK_REPLY | 12 | type, res[3], position_lo @4, position_hi @8 | ✓ | `<BBBBii`/`<BBBBII` (:3101–3106) | u64 @4 (:718–721) |
| DREAD_REQ | 8 | type, res[3], handle @4 | ✓ | ✓ | :725ff |
| DREAD_REPLY | 48 + name | type, res, name_len u16 @2, result @4, mode @8, attr @12, size @16, hisize @20, ctime @24, atime @32, mtime @40, name[] | ✓ | `<BBHiIIII` + 24 B times (:3127–3135) | 48 B, same offsets, **attr + all times left zero** (:748–765) (UDPFS-11) |
| GETSTAT_REQ | 4 + path | type, res[3], path[] | ✓ | ✓ | :767ff |
| GETSTAT_REPLY | 48 | type, res[3], result @4, mode @8, attr @12, size @16, hisize @20, ctime @24, atime @32, mtime @40 | ✓ | `<BBBBiIIII` + times (:3150–3157) | 48 B, same offsets, **attr + times zero** (:809–816) (UDPFS-11) |
| MKDIR/REMOVE/RMDIR_REQ | 4 + path | type, res, mode u16 @2, path[] | ✓ | `<BBH` (:2374) | path-op handler |
| RESULT_REPLY | 8 | type, res[3], result i32 @4 | ✓ | `<BBBBi` (:3087) | `result8` |
| BREAD_REQ / BWRITE_REQ | 16 | type, res, sector_count u16 @2, handle i32 @4, sector_nr_lo @8, sector_nr_hi @12 | ✓ | `<BBHiII` (:2491, :2560) | `blockRequest` (:119–127) |

Limits:

| Limit | C clients C1/C2 | Python S1 (current) | Go S2 | Shipped S3 |
|---|---|---|---|---|
| Max path | 256 B incl. NUL | name ≤ 255 enforced in DREAD aliasing (:1756) | `maxPathBytes`, DREAD name truncated to 255 (:750) | 256 |
| Per-READ request | client chunks at `UDPFS_MAX_READ` 64 KiB | **no protocol cap** — bounded only by transfer cap (below) | same as S1 | **no cap at all** (UDPFS-07) |
| Transfer cap (READ size, WRITE declared, assembled WRITE_DATA, BREAD/BWRITE total) | n/a (server-side) | 8 MiB default, floor 256 KiB (`_clamp_max_transfer` :298–328; enforced :1983, :2051, :2114, :2508, :2585) | `transferCap` from `MaxTransferBytes` (enforced `operations.go:508,567,625`, `blockdev.go:157,189,246,281`) | **none** |
| Max handles / client | — | **64** (:228) | **64** (`server.go:25`) | **32** (:101) |
| Sector size | 512 fixed; handle 0 = block device | 512, or `--sector-size` for handle 0 only | 512 for file handles; configurable for the block image | 512 / configurable |
| BREAD chunking (client) | ≤ 128 sectors (64 KiB) per request, looped | — | — | — |
| WRITE chunking (client) | chunk data ≤ `UDPFS_MAX_PAYLOAD(1400) − 8` = 1,392 B | accepts inline first chunk after READ/WRITE header | same | same |

### Standalone UDPBD v2 (B1 client vs B2/B3 servers)

| Item | C B1 (`udpbd.h`) | Python B2 | Go B3 | Verdict |
|---|---|---|---|---|
| Ports | server `0xBDBD`, client `0xBDBE` | `0xBDBD` (:32) | `Port 0xBDBD` | Identical |
| Commands | INFO 0, INFO_REPLY 1, READ 2, READ_RDMA 3, WRITE 4, WRITE_RDMA 5, WRITE_DONE 6 | same | same (`protocol.go`) | Identical |
| Header, 2 B LE | `cmd:5, cmdid:3, cmdpkt:8` | `pack/unpack_header` (:57–65) | `packHeader`: `cmd&0x1F \| cmdid<<5 \| cmdpkt<<8` | Identical |
| INFO_REPLY | hdr + sector_size u32 + sector_count u32 (10 B) | `<II` (:200–201) | `le32(SectorSize)` + `le32(sectorCount)` (`server.go:364–366`) | Identical |
| RW_REQUEST | hdr + sector_nr u32 + sector_count u16 (8 B); note field order is nr-then-count, unlike UDPFS BREAD | `<HIH` from offset 0 (:207, :240) | `sectorRequest` reads nr @2, count @6 (`server.go:338–341`) | Identical |
| WRITE_DONE | hdr + result i32 (6 B); sent with `cmdpkt = (cmdid+1)&0xFF` | same (:257, :294, :302) | `sendWriteDone(cmdid, result)` (`server.go:537–540`) | Identical |
| RDMA packet | hdr + `block_type{block_shift:4, block_count:9, spare:19}` + data; `UDP_MAX_PAYLOAD 1472`, `RDMA_MAX_PAYLOAD 1466` | `RDMA_MAX_PAYLOAD = 1472−2−4` (:47) | `rdmaMaxPayload = 1472−2−4` | Identical |
| Block-size selection for READ | client receives any shift | table: 1440⇒shift 3, else 1024⇒7, 1280⇒6, 1408⇒5 (:173–186) | `blockShiftForSectors` — same thresholds/shifts | Identical |
| Max sectors per READ request | client chunks at `UDPBD_MAX_SECTOR_READ 32` (16 KiB, local change per `udpbd.h`) | no cap — range check only, and only for raw devices (UDPFS-09) | no cap — full range check | Server caps absent in both; client self-limits |
| RDMA receive validation (client) | rejects `size > RDMA_MAX_PAYLOAD` **and** `size > g_read_size` (remaining) before DMA (`udpbd.c:343–365`) | n/a | n/a | Client is the validating side; no server equivalent needed |

---

## (c) Candidate findings

### UDPFS-01 — RiptOPL UDPRDMA receive copies a wire-controlled app-header length into fixed buffers; SMS already clamps it
- Category: 6 bugs/security
- Locations: RiptOPL `modules/network/udpfs_shared/src/udprdma.c:185–199` (used by all three variants) / Simple-Media-System `iop/SMSUdpfs/udpfs/src/udprdma.c:186–214` / both repos' `udprdma_packet.h` (`hdr_word_count:4` ⇒ `hdr_size` up to 60)
- Problem: `hdr_size = hdr_word_count * 4` comes straight off the wire (up to 60 B). RiptOPL feeds it unchecked to `smap_fifo_read(0x30, s->rx_hdr_buffer, hdr_size)` where the caller's buffer is exactly `rx_hdr_size` bytes (8 B for `udpfs_msg_result_reply_t`), and to a `dummy[UDPRDMA_MAX_APP_HDR]` (32 B) stack array in the skip branch. A version-skewed, buggy, or hostile server overflows the IOP stack from the SMAP RX thread; `rx_hdr_size` exists in the socket struct and is never read on this path. SMS's fork already fixes exactly this: copy only when `hdr_size <= s->rx_hdr_size`, otherwise drain the FIFO in 32 B steps (draining is mandatory — leaving the bytes desyncs every following payload read).
- Fix in words: Port SMS's clamp-and-drain branch into the shared RiptOPL `udprdma.c` verbatim in behaviour: fill the caller's header buffer only when it fits, drain any remainder in bounded chunks.
- Benefit: Removes a remotely triggerable IOP stack overflow; restores client parity.
- Effort: S / Risk: Low (SMS code is the reference behaviour; well-behaved servers send ≤ 8 B headers, so no interop change) / Confidence: READ

### UDPFS-02 — RiptOPL read path returns a wire-controlled byte count from an uninitialised reply struct; SMS zero-inits and clamps
- Category: 6 bugs/security
- Locations: RiptOPL `modules/network/udpfs_shared/src/udpfs_core.c:89–117` (`_recv_with_result`) / Simple-Media-System `iop/SMSUdpfs/udpfs/src/udpfs_core.c:91–135`
- Problem: Two defects in one mechanism. (1) `udpfs_msg_result_reply_t result` is declared uninitialised; if the server's app header is undersized/oversized, parts of it are never written (see UDPFS-01's drain case) yet `result.msg_type`/`result.result` are read and trusted. (2) On success the function returns `result.result` unchecked: a server reporting more bytes than it DMA'd makes the caller hand the EE a count larger than the requested buffer, surfacing unwritten buffer bytes as file data. SMS fixes both: `= {0}` initialisation (zeros fail the msg_type check cleanly) and `if (result.result > ret) return ret;`.
- Fix in words: Zero-initialise the reply struct and clamp the returned logical count to the bytes actually received, as SMS does. Apply the same zero-init to the other stack reply structs in the same file that are read after a possibly-short header (SMS does this for its getstat reply too).
- Benefit: A misbehaving server degrades to a clean `-EIO` instead of bogus byte counts / leaked buffer contents.
- Effort: S / Risk: Low / Confidence: READ

### UDPFS-03 — SMS block read treats EOF/short reads as full success and leaves stale bytes in the caller's buffer; RiptOPL already handles both
- Category: 6 bugs/security
- Locations: Simple-Media-System `iop/SMSUdpfs/udpfs/src/udpfs_core.c:699–724` (`udpfs_core_bread`) / RiptOPL `modules/network/udpfs_shared/src/udpfs_core.c:664–695`
- Problem: SMS's loop only fails on `ret < 0`. On `ret == 0` (EOF) it still advances `sectors_left`/`sector`/`buffer` by the full chunk and ultimately returns the full requested `count`; on a short read (`0 < ret < chunk * sector_size`) the unwritten tail keeps whatever the caller's buffer previously held and is reported as disc/file data. RiptOPL treats `ret <= 0` as `-EIO` and `memset`-zeroes the short-read tail before advancing.
- Fix in words: Port RiptOPL's two behaviours into SMS's `udpfs_core_bread`: fail on zero-length result, zero-fill any short-read tail.
- Benefit: No stale-memory-as-sector-data and no false full-count success at end-of-file/image.
- Effort: S / Risk: Low / Confidence: READ

### UDPFS-04 — SMS's SMAP FIFO read still drops the last byte of odd-sized frames; RiptOPL and Launchstation both carry the fix
- Category: 6 bugs/security
- Locations: Simple-Media-System `iop/SMSUdpfs/smap/src/xfer.c:144–148` / RiptOPL `modules/network/udpfs_smap/src/xfer.c:144–156` / Launchstation `iop/udpfs_smap/src/xfer.c` (same fix; documented in Launchstation `iop/udpfs_smap/ORIGIN.md`)
- Problem: SMS's `smap_fifo_read` PIO tail stores u32 chunks then a single u16 for a trailing 2 bytes, and has no step for a trailing single byte (or the 3rd byte of a 3-byte tail). The FIFO pads frames to 4 bytes, so every odd-sized UDPFS transfer — e.g. the end of every odd-sized file — leaves its final byte as stale buffer content. This is transport-level, so it corrupts data below the protocol layer regardless of UDPFS-01…03. RiptOPL (and Launchstation, independently) read the final padded word once and store only the valid bytes.
- Fix in words: Replace SMS's u16-tail block with the read-final-word/store-valid-bytes loop the other two repos use.
- Benefit: Byte-exact file reads over UDPFS in SMS; removes a silent one-byte corruption.
- Effort: S / Risk: Low (both sibling implementations are the reference) / Confidence: READ

### UDPFS-05 — SMS's send path accepts any ACK as covering the sent packet (stale-ACK check is arithmetically inert) and burns a retry on real stale ACKs; RiptOPL waits on the same timer
- Category: 6 bugs/security
- Locations: Simple-Media-System `iop/SMSUdpfs/udpfs/src/udprdma.c:612–618` (and the duplicated logic in `udprdma_send_ll`, :681–687) / RiptOPL `modules/network/udpfs_shared/src/udprdma.c:369–389` (`_wait_ack`) + `modules/network/udpfs_ioman/src/udprdma_seq.h:8–11` (`udprdma_ack_covers`, identical copy in the bd/fhi variants)
- Problem: SMS computes `diff = (int16_t)((tx_seq_nr_acked − sent_seq_nr) & 0xFFF)`; the masked value is 0…4095, which as `int16_t` is never negative, so `diff >= 0 || diff < −2048` is always true — **any** ACK, including one for an older packet, completes the send as if the current packet were acknowledged. Where the check was meant to fire, SMS also spends one of only 4 retries and retransmits, provoking duplicate windows at the server. RiptOPL instead keeps waiting on the same alarm until an ACK whose 12-bit forward distance from the sent sequence is < 2048 arrives, or the real timeout fires.
- Fix in words: Give SMS the same cumulative-ACK coverage test and wait-without-retry loop RiptOPL uses (forward-half-ring covers, exactly-2048 ambiguous and not covering), in both `udprdma_send` and `udprdma_send_ll`.
- Benefit: Sends complete only on a genuine acknowledgement; fewer spurious retransmits/disconnects on lossy links.
- Effort: M / Risk: Medium (timing-sensitive IOP code; needs on-hardware soak, like all UDPRDMA changes) / Confidence: READ (the always-true condition follows directly from the read code's arithmetic)

### UDPFS-06 — SMS ignores `SetAlarm` failure and can wait forever for an ACK/timeout that will never be signalled; RiptOPL fails the wait as a timeout
- Category: 6 bugs/security
- Locations: Simple-Media-System `iop/SMSUdpfs/udpfs/src/udprdma.c:602–603` (also :672, :730 — raw `SetAlarm(&clock, _timeout_cb, socket)` with the return value discarded) / RiptOPL `modules/network/udpfs_shared/src/udprdma.c:105–119` (`_arm_timeout`)
- Problem: Every SMS wait ends only on a packet flag or `EF_TIMEOUT`, and `EF_TIMEOUT` is raised only by the alarm. If `SetAlarm` fails (kernel heap exhausted, stale alarm still registered), the wait blocks indefinitely and UDPFS hangs for the session. RiptOPL wraps every arming in `_arm_timeout`, which on failure raises `EF_TIMEOUT` immediately so the caller's bounded retry loop still terminates the operation.
- Fix in words: Route SMS's three arming sites through an equivalent checked helper that signals the timeout flag when `SetAlarm` returns non-zero.
- Benefit: Removes an unbounded hang; failure degrades to the existing retry/disconnect path.
- Effort: S / Risk: Low / Confidence: READ

### UDPFS-07 — A pre-hardening copy of the UDPFS Python server ships inside RiptOPL with none of the current server's wire-value validation
- Category: 6 bugs/security (also 2 duplication)
- Locations: RiptOPL `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/udpfs_server/udpfs_server.py` — `MAX_HANDLES = 32` (:101), `MAX_WINDOW_RETRIES = 4` (:106), `_handle_read` with no size cap (:908–937), `_handle_write_data` with no assembled-size cap and no no-write-in-progress guard (:974–1001), `_handle_bread`/`_handle_bwrite_req` with no total-size or offset-overflow refusal (:1267–1343) / PS2-Servers `udpfs_server/udpfs_server.py` — `MAX_HANDLES = 64` (:228), `MAX_WINDOW_RETRIES = 200` (:275), caps at :1983, :2051, :2114, :2508, :2585, write-state reset at :2010–2029
- Problem: The shipped copy is the same protocol with the safety removed: a single unauthenticated READ datagram can request a 4 GiB allocation (`size` is a raw u32), WRITE_DATA chunks can grow the assembly buffer without limit, BREAD can request ~32 MiB in one allocation, oversized sector offsets go unanswered instead of refused, and chunks from a refused write can land in the previous write's buffer. Anyone who runs the server from the shipped Neutrino example — the copy a user is most likely to actually launch — gets the vulnerable version, while the fixed version lives in another repo.
- Fix in words: Replace the shipped copy with the current PS2-Servers Python server (or, if the example must stay frozen, delete the server from the example and point at the PS2-Servers copy). Do not hand-port the individual caps — that recreates the drift that caused this.
- Benefit: The copy users actually run gains the transfer caps, writable-handle checks, and write-state reset the current server already has.
- Effort: S / Risk: Low / Confidence: READ

### UDPFS-08 — Python and Go UDPFS servers disagree on BWRITE completion: Python silently truncates over-delivered data and reports 0, Go requires exact length and reports the byte count
- Category: 6 bugs/security
- Locations: PS2-Servers `udpfs_server/udpfs_server.py:2156–2187` (`_complete_bwrite`: writes `data[:expected_size]`, reports `_send_write_done(addr, 0)`) and `:2083–2132` (`_handle_write_data`: only the global transfer cap bounds assembly) / PS2-Servers `native/ps2servers-edge/internal/udpfs/blockdev.go:329–357` (`completeBlockWrite`: `len(buf) != expected` ⇒ `-EINVAL`, success reports `len(buf)`) and `internal/udpfs/operations.go:630–641` (per-chunk stop the moment a BWRITE exceeds its declared length)
- Problem: For the same wire sequence the two servers do different things with a length mismatch. Python accepts a BWRITE whose delivered bytes exceed the declared sector count, silently discards the excess, accepts a short delivery as a short write, and answers WRITE_DONE 0 either way — the client cannot tell a full write from a truncated one. Go refuses the write outright on any mismatch and additionally stops assembly per-chunk at the declared length, so a client declaring one sector cannot make the server buffer up to the full 8 MiB cap. The C client's write helper returns `done->result` to its caller (`udpfs_core.c:230–236` in both C clients), so the success value itself also differs by server (0 vs byte count) for identical requests.
- Fix in words: Make Python match Go: track the BWRITE declared length during chunk assembly, refuse (WRITE_DONE `-EINVAL`, buffer discarded) as soon as delivery exceeds it and on any final length mismatch, and report the byte count on success.
- Benefit: One BWRITE semantics across servers; silent truncation of block writes (VMC/HDD image writes) becomes a visible error.
- Effort: M / Risk: Low (well-behaved clients always deliver exactly the declared length) / Confidence: READ

### UDPFS-09 — Standalone UDPBD Python server range-checks READ only for raw devices and WRITE not at all; the Go server refuses out-of-range for both
- Category: 6 bugs/security
- Locations: PS2-Servers `udpbd_server/udpbd_server.py:205–236` (`_handle_read`: capacity check at :208 only when `bd.is_raw`; file-image reads past the end are zero-padded by design at :123) and `:238–261` (`_handle_write`: no capacity check before seeking/arming `_write_left`) / PS2-Servers `native/ps2servers-edge/internal/udpbd/server.go:370–385` (READ refused if `sectorNr+sectorCount > sectorCount()`) and `:440–451` (WRITE refused on the same test)
- Problem: Against the Python server, a WRITE request naming sectors past the end of a file image is armed anyway; the following WRITE_RDMA data is written at that offset, extending/growing the image file beyond its declared capacity — the exact quantity the INFO_REPLY advertises. READ behaviour also differs by backing type within the Python server itself (raw ⇒ error, file ⇒ padded stream), while Go uniformly refuses. The C client self-limits to 32 sectors per request but places no bound on the sector number it can be driven to request.
- Fix in words: Apply Go's refuse-out-of-range test in the Python server's `_handle_read` (for file images as well as raw devices) and `_handle_write`, answering/logging the refusal the way its existing raw-device read path does, instead of arming the write.
- Benefit: A disk image's advertised capacity becomes a real bound on both servers; no silent image growth from a stray or hostile request.
- Effort: S / Risk: Low / Confidence: READ

### UDPFS-10 — RiptOPL carries three byte-identical copies of every UDPFS wire header (plus the ACK helper); SMS proves one copy per module is enough
- Category: 2 duplication
- Locations: RiptOPL `modules/network/udpfs_bd/src/`, `modules/network/udpfs_fhi/src/`, `modules/network/udpfs_ioman/src/` — in each: `udpfs_packet.h` sha256 `e51bb79a944c`, `udprdma_packet.h` `91f5d702d1c2`, `udpfs_core.h` `f3db57ee74ce`, `udprdma.h` `59d9692887d1`, `udprdma_seq.h` `08bf73e0b819` / Simple-Media-System `iop/SMSUdpfs/udpfs/src/` (single copies of the same headers)
- Problem: The real code already lives once in `udpfs_shared/` (the per-variant `.c` files are 122–125 B `#include` shims), but the headers that *define the wire format* are triplicated. A future wire fix — e.g. UDPFS-01/02 landing in a header comment or a limit — must be made three times, and the three copies can silently drift apart while still compiling, producing IRX variants that speak different protocols. SMS's merged module shows the same three personalities build from a single header set.
- Fix in words: Delete two of the three header copies and point all three variant builds at one location (the shared directory the `.c` shims already use); keep exactly one copy of each header and of `udprdma_seq.h`.
- Benefit: One place defines the wire format; variant drift becomes impossible by construction.
- Effort: M / Risk: Medium (build-system change across three IRX variants; needs a full build of each variant to confirm include paths) / Confidence: READ

### UDPFS-11 — Go UDPFS server returns all-zero timestamps (and zero attr) in OPEN_REPLY / DREAD_REPLY / GETSTAT_REPLY; Python returns real times
- Category: 6 bugs/security (interop/semantics; low severity)
- Locations: PS2-Servers `native/ps2servers-edge/internal/udpfs/operations.go:464–472` (`sendOpen`: 36 B buffer, ctime/mtime never written), `:748–765` (`sendDRead`: attr @12 and all three times never written), `:809–816` (`sendGetStat`: same) / PS2-Servers `udpfs_server/udpfs_server.py:3056–3062`, `:3127–3135`, `:3150–3157` (all replies carry real ctime/atime/mtime)
- Problem: Layout is identical, so nothing fails loudly — but a client browsing the same share sees real file dates from the Python server and 00-00-0000 / zero dates from Edge, and any client logic comparing mtimes (sync, save-backup, "newer file" prompts) silently misbehaves against Edge. The Go reply builders allocate the full 36/48 B and simply never fill the time fields.
- Fix in words: Populate ctime/mtime (and atime where the struct has it) from the same `os.FileInfo` the Go handlers already stat, in PS2's 8-byte time format, matching what the Python builders emit; fill `attr` the same way Python does.
- Benefit: Identical client-visible metadata from both servers; removes a silent interop difference.
- Effort: S / Risk: Low / Confidence: READ

### UDPFS-12 — Discovery header's second field is documented as "reserved, must be 0" in C but is the data port in both servers; the C client ignores it and trusts the UDP source port instead
- Category: 7 build/CI/clutter (documentation/spec divergence with interop consequences)
- Locations: RiptOPL `modules/network/udpfs_ioman/src/udprdma_packet.h` (`udprdma_hdr_disc_t`: `service_id` + `reserved /* must be 0 */`; identical in SMS and in the bd/fhi copies) and `modules/network/udpfs_shared/src/udprdma.c:165` (on INFORM, `s->port = ntohs(disc_pkt->udp.port_src)` — source port, field never read; client sends the field as 0 at :266, :280) / PS2-Servers `udpfs_server/udpfs_server.py:492–504` (`DiscHeader.service_id, port`) + `:2655–2656` (INFORM carries `port = self.dsock.getsockname()[1]`) / PS2-Servers `native/ps2servers-edge/internal/protocol/packet.go` (`DiscoveryHeader{ServiceID, Port}`) + `internal/udpfs/negotiation.go:195` (INFORM marshals the data port)
- Problem: Three artefacts describe the same 2 bytes three ways. It works today only because servers set the field to the same value as their source port and clients ignore the field. Any future implementation written from the C header alone (field = 0, "reserved") breaks the servers' single-port / data-port negotiation, and any written from the Go/Python side (field = port) contradicts the only C documentation. The Python server's own modulo-compat path even sends `port=0` deliberately for one client family, which the C comment would call the only legal value.
- Fix in words: Rename the field to `port` in the C header with a comment stating it carries the server's data port in INFORM (0 = use the source port), matching the Python/Go definitions; no byte changes anywhere.
- Benefit: The spec-in-code stops lying; the next implementation written from any one source interoperates with the others.
- Effort: S / Risk: Low (comment/identifier only; the field name is internal to each build) / Confidence: READ

---

## Parity summary (for the parent report)

- **Layouts: identical.** UDPRDMA base/data/discovery headers, all 19 UDPFS
  message types and every packed struct, and standalone UDPBD v2 framing
  (header bitfields, RW request, INFO reply, RDMA block_type, block-shift
  table) match field-for-field across C (RiptOPL + SMS), Python, and Go.
- **Divergences are validation/semantics only**, 12 candidates above:
  2 client receive-path hardenings SMS has and RiptOPL lacks (UDPFS-01, 02);
  3 client hardenings RiptOPL has and SMS lacks (UDPFS-03, 04, 05, 06 — four
  items); 1 stale shipped server copy missing all current server validation
  (UDPFS-07); 2 Python↔Go server semantic splits (UDPFS-08 BWRITE completion,
  UDPFS-11 zero timestamps); 1 Python↔Go standalone-UDPBD split (UDPFS-09);
  1 triplicated wire-header set (UDPFS-10); 1 spec/documentation split on the
  discovery port field (UDPFS-12).
- Launchstation and POPSLoader contribute **no UDPFS wire source** — they ship
  the identical precompiled `udpfs_ioman.irx` (`85faad5631fa`), so their wire
  behaviour is whatever that binary was built from and cannot be audited from
  source in either repo.
