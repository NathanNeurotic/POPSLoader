# Sable Audit — ROUND 3: CROSS-REPO — UDPFS census, UDPRDMA drift, memory-card write patterns

- **Auditor:** Sable (round 3, cross-repo agent)
- **Date:** 2026-11-14
- **Mode:** READ ONLY. No repo file edited; all five clones verified `git status` clean at the pins below, before and after.
- **Rule:** LESS, NOT MORE. New cross findings are X-31…; nothing from X-01…X-30 or any per-repo file is repeated — where a round-3 fact extends an earlier finding, the earlier ID is referenced, not re-filed.
- **Scope of this file:** (1) the unified UDPFS census — the one protocol implemented on both sides of the wire inside these repos; (2) memory-card write patterns across the four PS2 repos; (3) UDPRDMA session/reliability-layer duplication surfaced by the census.

## Round-3 pins (verified live at the start of this round; all five matched, all clean)

| Repo | HEAD |
|---|---|
| RiptOPL | `2e347d5ac885` rebuild/main |
| Launchstation | `9fb0598a79f0` master |
| POPSLoader | `29272cddbf01` master |
| Simple-Media-System | `e65ced39a27e` master |
| PS2-Servers | `c5f021c4d386` main |

## Where UDPFS actually lives (census preamble)

UDPFS (UDPRDMA transport, UDP port `0xF5F6`, service id `0xF5F5`) is one protocol family with **one upstream origin**: neutrino (rickgaiser → ps2max32). Every console-side copy in these repos descends from it, but they arrived by different routes and have drifted independently since:

| Consumer | What it carries | Source in repo? |
|---|---|---|
| RiptOPL | Full IOP source, vendored from rickgaiser/neutrino @ `06188cce` (`modules/network/udpfs_ioman/ORIGIN.txt`, `udpfs_bd/ORIGIN.txt`), canonical core in `modules/network/udpfs_shared/src/` with 2-line `#include` shims per variant (RIPTOPL-048 covers the header triplication) | Yes — 3 front-end variants built (ioman + bd + fhi) |
| Simple-Media-System | Full IOP source, vendored from ps2max32/neutrino (`iop/SMSUdpfs/ATTRIBUTION.md`), with SMS's own documented local modifications | Yes — only the ioman variant is built (`tools/build_udpfs.sh:54` passes `UDPFS_IOMAN=1`; top-level `Makefile:53` embeds only `udpfs_ioman_irx.o`) |
| Launchstation | `iop/udpfs_smap/` source-built from the *same* neutrino pin `06188cce` (`iop/udpfs_smap/ORIGIN.md`); `udpfs_ioman` + `udpfs_ministack` are precompiled IRXs (`iop/__precompiled/`) | Partial — smap only; the protocol core is a binary |
| POPSLoader | Precompiled neutrino-lineage trio `iop/embed/udpfs_ioman.irx` (11,633 B) + ministack + smap, hash-pinned by `tools/test_udpfs_integration.py:18` but with **no provenance statement anywhere in the repo** for what source/commit they were built from (grep, READ); plus a *second, unrelated-fork* driver for the POPStarter runtime: Okeanos86 "UDPFS Assault 1.0.1" binaries (`bin/POPSLDR/usbd.irx.udpfs`, `usbhdfsd.irx.udpfs`), sha256-pinned in `docs/third_party/okeanos_udpfs/PROVENANCE.json`, source in **none** of the five repos | No — binaries only, two different lineages |
| PS2-Servers | The server side, three editions (below) | Yes |

So the "four repos" framing is really: **two source-carrying clients, two binary-carrying clients, one three-edition server** — and only the source-carrying pieces can be wire-compared at all (see "What could not be compared").

---

# TASK 1 — The UDPFS census

## 1.1 Master table

Line counts are source lines at the pins. "Validation" columns summarise §1.3; C = the entry actually checks, — = no check, n/a = field not present on that side.

| Implementation | Side / location | Lines | Transport / session model | Path len | Read/write size | sector_count | Handle bounds |
|---|---|---|---|---|---|---|---|
| **RiptOPL client** | IOP client — `modules/network/udpfs_shared/src/udpfs_core.c` + `udprdma.c`; front-ends `udpfs_ioman/src/udpfs_ioman.c` (510), `udpfs_bd/src/udpfs_bd.c` (193), `udpfs_fhi/src/udpfs_fhi.c` (143) | core 791 + transport 738 (variant header copies: RIPTOPL-048) | One UDPRDMA socket (`UDPRDMA_MAX_SOCKETS=1` in builds), stop-and-wait: every DATA packet waits for its ACK (`udprdma.c:369-391` `_wait_ack`); RX cumulative ACK every 6 packets (`UDPRDMA_RX_ACK_WINDOW 6`, `udprdma.c:32`); Go-Back-N; discovery broadcast, 5 s (`udpfs_core.c:263`); request timeout 5 s (`:74`), read/bread 30 s (`:411,678`); reconnect watchdog in front-ends (`udpfs_ioman.c:91-104`) | C — client refuses >256 before sending (`udpfs_core.c:375-377` open, `:602-604` getstat, `:156-158` path-op) → `-ENAMETOOLONG` | C — self-chunks READ at 64 KiB (`:456`), BREAD at 128 sectors (`:690-692`); write chunks 1,392 B data (`MAX_PAYLOAD−8`, `:180`) | C — self-chunked, never exceeds 128 | C — local `handle < 0` → `-EBADF` at every entry; server handles otherwise trusted |
| **SMS client** | IOP client — `iop/SMSUdpfs/udpfs/src/udpfs_core.c` + `udprdma.c`; front-end `udpfs_ioman.c` (447) built; `udpfs_bd.c` (132) + `udpfs_fhi.c` (135) carried, never built | core 825 + transport 804 | Same lineage, same constants (ACK timeout 100 ms, retx 500 ms, discovery 2 s, retries 4 — `udprdma_packet.h:42-47`, identical values to RiptOPL's); same stop-and-wait model, send/wait inlined (`udprdma.c:578-647`); socket created once for module lifetime (its own comment, `udpfs_core.c:267-286`) | C — same checks, same lines modulo drift (core is a fork of the same file) | C — same self-chunking | C — same | C — same |
| **PS2-Servers Python standalone** | PC server — `udpfs_server/udpfs_server.py` | 3,643 | Single process; select/demux loop (`run:1048`); one `Session` (`:3193`) per `(IP, src port)`, each with a daemon worker thread + unbounded queue; TX window 8 (`SEND_WINDOW:273`), window-ACK timeout 0.1 s, ≤200 retries (`:274-275`); session reap after 3,600 s idle (`:240`); ≤256 sessions, LRU eviction at cap | — **no cap at all** (`_handle_open:1789` split-on-NUL decode) | C — per-request cap `max_transfer_bytes`, default **8 MiB** (floor 256 KiB), `:285-301` | — no 128 cap; bounded only by the 8 MiB byte cap ⇒ up to **16,384 sectors** | C — `handles.get()` → EBADF; ≤64 handles/session (`:228`) incl. handle 0 (⇒ 63 usable with a block device, INFERRED from `:3210` seeding) |
| **PS2-Servers Python Core** | PC server — `udpfs_server/ps2servers_core.py` | 690 | Subclass of standalone: exactly six overrides (`__init__:107`, `_get_or_create_session:185`, `_sendto:215`, `_handle_discovery:267`, `_handle_data:384`, `run:477`); **no opcode handler overridden** — all parsing/validation/caps inherited verbatim. Adds per-session auto profile negotiation (canonical INFORM + compatibility INFORM after 0.25 s fallback, `:226-267`) | — inherited (none) | C — inherited (8 MiB) | — inherited | C — inherited. One dispatcher-level *addition*: `_route_data_via:360` drops DATA packets whose declared payload exceeds the datagram (standalone silently truncates, `udpfs_server.py:1651`) |
| **PS2-Servers Go Edge** | PC server — `native/ps2servers-edge/internal/udpfs/` (+ `internal/protocol/packet.go`, `internal/session/session.go`, `internal/filesystem/root.go`) | 820 ops + 613 server + 522 negotiation + 409 blockdev + 261 pathops + 251 transfer ≈ 2,876 (+ shared pkgs) | Single process, goroutines: dispatch loop + one readLoop per socket + 5 s reaper + one `peerWorker` goroutine per peer (queue 256); sessions keyed `"IP:port"` (`getWorker:447`); TX window 8 / 100 ms / 200 quiet retries (`server.go:20-22`), quiet counter resets on any ACK progress (`transfer.go:68`); peer timeout 1 h; cap 256 **hard-coded, refuses** new peers (no eviction) | C — **1,024** bytes (`maxPathBytes server.go:24`, enforced `operations.go:166-176`) | C — `transferCap`: RAM/16, ≤8 MiB, floor 256 KiB (`memory/budget.go:103-114`) — **host-dependent** | — no 128 cap; byte cap only | C — handle map → EBADF; ≤64 file handles (handle 0 not in map, so 64 usable); **a failed OPEN still burns its handle number** (`operations.go:319-320` allocates before path checks) |

## 1.2 Verdict (a) — wire-format agreement

**The byte layouts agree. Completely.** This is a source-level claim (see "What could not be compared" for why it is not a runtime claim):

- **Opcodes:** identical values in all five source implementations — C `#define`s (`RiptOPL/modules/network/udpfs_ioman/src/udpfs_packet.h:29-60`), Python `MsgType` (`udpfs_server.py:193-215`), Go (`internal/protocol/packet.go:38-72`). OPEN `0x10` … BWRITE `0x2A`, no renumbering, no private opcodes in any edition.
- **Transport headers:** base header (type 4 bits | seq 12 bits, LE u16), DiscHeader (2× u16), DataHeader (ack 12 | flags 2 | hdr_word_count 4 | data_byte_count 14, LE u32) are bit-identical in C (`udprdma_packet.h:54-93`), Python (`udpfs_server.py:474-531`) and Go (`packet.go:76-121`).
- **Message structs:** every fixed layout matches field-for-field — OPEN_REQ 8 B + path, OPEN_REPLY 36 B, READ/WRITE_REQ 12 B, WRITE_DATA header 8 B (chunk fields at 2/4/6), LSEEK_REQ 16 B, DREAD_REPLY 48 B fixed + name, GETSTAT_REPLY 48 B, BREAD/BWRITE_REQ 16 B — in C (`udpfs_packet.h:67-262`), Python handlers (`_handle_open:1789`, `_send_open_reply:3045`, `_handle_read:1969`, `_handle_write_data:2083`, `_handle_lseek:2189`, `_send_dread_reply:3109`, `_send_getstat_reply:3142`, `_handle_bread:2483`) and Go (`operations.go:297,464,491,547,598,696,748,809`; `blockdev.go:118-130`).
- **Constants:** port `0xF5F6` / service `0xF5F5` everywhere (C `udprdma_packet.h:36-39`; Python `udpfs_server.py:176-177`; Go `packet.go:12-14`); sector size 512 everywhere; block device = handle 0 everywhere (C `udpfs_packet.h:14-15` comment + `udpfs_bd.c:20` both C trees; Python `BLOCK_DEVICE_HANDLE=0:357`, handles allocated from 1; Go `blockHandle=0 blockdev.go:19-21`, `NextHandle=1 session.go:145`).
- **The two C clients' headers are semantically identical to each other** — `udpfs_packet.h` and `udprdma_packet.h` in RiptOPL vs SMS differ only in brace placement and spacing (normalised diff, READ). RiptOPL's three internal copies of each header are byte-identical (md5, READ; the triplication itself is RIPTOPL-048).
- **The apparent 1400-vs-1408 payload mismatch is not a disagreement.** The C headers define both numbers at different layers: `UDPFS_MAX_PAYLOAD 1400` (application payload, `udpfs_packet.h:58`) and `UDPRDMA_MAX_PAYLOAD 1408` (transport payload, `udprdma_packet.h:100`). Python's `MAX_DATA_PAYLOAD=1408` (`udpfs_server.py:227`) and Go's `MaxPayload=1408` (`packet.go:14`) are the transport-layer number. Same layering, both sides.

**Three genuine divergences exist — all in interpretation or limits, none in layout:**

1. **DiscHeader bytes 2–3 mean two different things.** C: `reserved; /* Reserved (must be 0) */` (`udprdma_packet.h:70-76`). Python: the field is named `port` (`udpfs_server.py:493-505`) and the standalone server's INFORM *writes the real data-socket port there* (`_send_inform:2656`, `disc = DiscHeader(..., port = self.dsock.getsockname()[1])`). The C clients never read the field — on INFORM they take the peer port from the UDP source port (`RiptOPL/modules/network/udpfs_shared/src/udprdma.c:166`; SMS `udprdma.c:163` same). Core Py and Go split the difference: canonical INFORM sends port 0 from the data socket (Core `ps2servers_core.py:226-235`; Go `negotiation.go:195`), modulo/compat INFORM carries 0 + a name/shares trailer. Benign today — every path that works puts the INFORM on the data socket anyway — but the C comment is now simply wrong about the wire, and any future client that *trusts* the field against a C-lineage server (which sends 0) breaks. → X-37.
2. **Reply content, Go Edge:** OPEN_REPLY / DREAD_REPLY / GETSTAT_REPLY layouts and sizes match, but Go leaves ctime/mtime (bytes 20–35 of OPEN_REPLY; 24–47 of DREAD/GETSTAT) and the `attr` field **zero** (`operations.go:464,748,809`), where Python fills real values (`_send_open_reply:3045`, `_send_dread_reply:3109`, `_send_getstat_reply:3142`) and the C clients copy the times into `iox_stat_t` (RiptOPL `udpfs_core.c` dread/getstat). A client that displays dates or sorts by them sees 1980-epoch zeroes from Edge only. → X-38.
3. **Limits (posture, §1.3):** the C header's `MAX_READ` 64 KiB, `MAX_SECTOR_READ` 128 and `MAX_PATH` 256 are enforced by **neither** server edition as written — see the asymmetry table. No interop break results today because both C clients self-limit to exactly the header values; the caps bind only third-party/PC clients (PS2-Servers' own selftest reads 200,000 B in one READ, `udpfs_server.py:285-298` comment).

## 1.3 Verdict (b) — validation-posture asymmetries

Same field, checked on one side/edition, unchecked in another. (Per-opcode detail for the servers is in the appendix table; client rows are from the two C cores, which are near-identical except where §3 lists drift.)

| # | Field / check | Where checked | Where NOT checked | Consequence |
|---|---|---|---|---|
| B1 | Path length on OPEN/GETSTAT/path-ops | C clients refuse >256 pre-send (RiptOPL `udpfs_core.c:375,602,156`); Go refuses >1,024 (`operations.go:166-176`) | **Python (both editions): no cap at all** — OPEN (`:1789`), GETSTAT (`:2294`), MKDIR/REMOVE/RMDIR (`:2368,2399,2440`) accept any path the datagram holds | A non-C client can make the Python server walk arbitrarily long paths; the "256" in the shared header is honoured by nobody on the server side of the Python editions |
| B2 | READ size cap value | Python: 8 MiB fixed default; Go: RAM/16 ≤ 8 MiB | C header says 64 KiB (`UDPFS_MAX_READ`) — enforced by **neither** server | The same READ is legal/refused depending on server edition *and host RAM* (Go) — a limit that changes with the machine it runs on |
| B3 | Over-cap errno | — | Python answers `EINVAL` for over-cap READ/WRITE/BWRITE; Go answers `EINVAL` for READ but `EFBIG` for WRITE/BWRITE (`operations.go:547ff`, `blockdev.go:219ff`) | A client logging or branching on errno sees different failures for the identical request |
| B4 | sector_count ceiling | C clients self-chunk at 128 (both cores) | **Both server editions: no sector cap** — byte cap only ⇒ 16,384 sectors at defaults | A buggy/hostile client can demand 8 MiB per BREAD packet from any server; the 128 in the header is a client courtesy, not a protocol rule |
| B5 | Handle 0 (block device) scope | Go: valid **only** for BREAD/BWRITE (+ CLOSE no-op); READ/LSEEK/WRITE/DREAD on 0 → EBADF (`operations.go:517,696`) | Python: READ, LSEEK and WRITE all operate on handle 0 through the block device's **shared seek position** (only BREAD/BWRITE are positional) | A client bug (or the FHI pattern of mixing calls) silently corrupts position state against Python, fails cleanly against Go |
| B6 | BREAD/BWRITE range vs image size | Go refuses out-of-range (`blockdev.go:96` `inRange`, `:132,219`) | Python: **no range check** — BREAD past EOF returns short data as success; BWRITE past EOF **extends the image file** (`_handle_bread:2483`, `_handle_bwrite_req:2551`) | Same packet: error on Edge, silent image growth on Python |
| B7 | BWRITE completion semantics | Go requires assembled length == declared exactly, else EINVAL, and answers WRITE_DONE = byte count (`blockdev.go:329`) | Python **truncates** over-long assemblies to the declared size and answers WRITE_DONE **0** (`_complete_bwrite:2156`) — while Python's own file-write completion answers the byte count | A client verifying WRITE_DONE gets 0 / count / error for the same successful write depending on opcode and edition |
| B8 | Short WRITE_REQ / BWRITE_REQ (<12 / <16 B) | Go answers WRITE_DONE EINVAL (`operations.go:552`, `blockdev.go:219`) | Python **only ACKs — no result is ever sent** (`udpfs_server.py:2037,2551` region) | Against Python, a malformed client waits out its full 5 s timeout instead of failing fast |
| B9 | WRITE_DATA chunk disorder | Go aborts the whole write, WRITE_DONE EIO (`operations.go:618ff`) | Python drops the chunk and **keeps the partial buffer armed** (`:2110ff`); Python also completes a write whose `total_chunks==0`, Go never does (`:646`) | Retried writes interleave differently per edition; the armed-buffer case can absorb a later write's chunk 0 |
| B10 | DREAD entry-name length | Go truncates names to 255 B (`operations.go:750-752`) | Python: no cap on raw entry names (`_send_dread_reply:3109`; its >255 skip applies only to compressed-alias names) | A >255 B name from Python hits the C clients' `name_len < name_max` test (RiptOPL `udpfs_core.c:637`) and the entry surfaces with an **empty name**; from Go it surfaces truncated |
| B11 | DATA payload over-declaration | Core Py drops the packet pre-queue (`ps2servers_core.py:360`); Go drops it in `ParseDataPacket` (`packet.go:132`) | Standalone Py **silently truncates** (`udpfs_server.py:1651`) | The one place Core is stricter than its own parent class |
| B12 | Session cap at 256 | Python evicts the least-recently-active peer (`:881`) | Go hard-refuses the new peer (datagrams dropped, `server.go:455`) | Under a port-scan flood, Python sacrifices the longest-idle *console*; Go sacrifices whoever connects next |
| B13 | OPEN `mode` field (bytes 4–8) | Nobody: C clients send it; Python unpacks and discards it (`:1789`); Go never reads it (`operations.go:297`). Creation perms are host defaults in all editions (Go `0o644`, `operations.go:445`) | — | Not an asymmetry — a uniformly dead wire field; recorded so nobody "fixes" one side only |
| B14 | Single-writer exclusion | Go only: `reserveWriter` (`server.go:134-147`, from `operations.go:427`) → second writer `-EBUSY`; REMOVE shares it (`server.go:154`) | **Both Python editions: still absent at this pin** (no writer registry in `udpfs_server.py`; `_handle_open:1789` opens write handles unconditionally; Core inherits it) | State re-verified for this census; the finding itself is PS2SERVERS-013 and is **not** re-filed. The cross-repo fact is only that the fix pattern exists in exactly one of three editions of the same server |

## 1.4 Verdict (c) — LESS-NOT-MORE consolidation, per piece

| Piece | Verdict | Arithmetic / reasoning |
|---|---|---|
| Wire constants + message structs (C side) | **Already shared in fact, not in form.** RiptOPL and SMS carry semantically identical `udpfs_packet.h`/`udprdma_packet.h`. Do not build a shared-headers package across repos (build systems differ: PS2SDK Makefiles vs SMS Rules.make); instead treat the header as a *spec*: the values in §1.2 are the contract, and each repo's copy is a transcription. Cost of formal sharing > cost of the drift it prevents — the drift that actually happened is in .c files, not headers (§3). | 0 lines saved by sharing; the win is naming the spec once (this census) |
| RiptOPL core (shared dir + shims) | **Keep as is.** The round-2 correction stands: one canonical `udpfs_core.c`/`udprdma.c` compiled by three variant Makefiles is the right shape. | — |
| SMS core (fork of the same files) | **Keep separate, but stop pretending it's a clean vendor.** SMS's `ATTRIBUTION.md` already lists local modifications; §3 shows the fork has since absorbed *security* fixes upstream's other fork lacks, and vice-versa. The consolidation that pays is not merging the trees (different dev9 ABI, different build) — it's a one-time **cross-port of the four drifted behaviours in §3**, each a few lines, in the direction noted there. After that the files differ only where the ABI forces it. | 4 small ports, ≈40 lines total, vs ~1,600 lines × 2 trees for a real merge |
| SMS's never-built `udpfs_bd.c` + `udpfs_fhi.c` (267 lines) | **Delete from SMS.** SMS builds IOMAN only (`tools/build_udpfs.sh:54`); the bd/fhi front-ends exist in its tree solely because the vendor was wholesale. RiptOPL builds all three because it uses all three (menu browse = ioman, BDM device = bd, in-game cdvdman = fhi, `RiptOPL/Makefile:143`). | −267 lines in SMS, zero behaviour change → X-36 |
| Python standalone vs Core | **Keep the subclass, it is the good pattern.** Core is 690 lines that override six methods and inherit the entire protocol — proof the protocol only needs to exist once per language. The remaining duplication is standalone's *global* `modulo_compat` mode vs Core's per-session negotiation (B-table, asymmetry 14 in appendix): standalone alone can't retire because Core's `main()` itself falls back to plain `UdpfsServer` for modulo mode (`ps2servers_core.py:591ff`). | No new consolidation available without a behaviour decision (which negotiation model is canonical) — a decision, not a refactor |
| Python vs Go servers | **Keep separate — but pick one as the protocol reference.** They are independent implementations in different languages for different hosts (desktop vs router/embedded); a shared implementation is not on the table. What *is* duplicated wastefully is the **limit set**: path cap, transfer cap, sector cap, errno choices and WRITE_DONE semantics are currently five independent decisions × 2 codebases (B2/B3/B7). One page of agreed numbers in the repo (the C header's, or a deliberate replacement set) and both editions transcribe it — the same spec treatment as the C headers. | 0 code lines; removes B1–B9 as a class |
| UDPBD | **Nothing to consolidate — it already isn't separate.** On every source implementation, UDPBD is a subset flag on UDPFS (BREAD/BWRITE + handle 0), not a second protocol: C `udpfs_packet.h:6-15`, Python `MsgType` comment `:192`, Go `blockdev.go`. (PS2SERVERS-005 covers the *server-app* edition count, a different axis.) | — |
| Launchstation / POPSLoader binary clients | **No consolidation available or needed.** They consume the same neutrino-lineage client as binaries. The only defect is documentary: POPSLoader pins hashes without provenance (which commit? whose build?) — one paragraph in `docs/third_party/` fixes it; Launchstation already does this properly (`iop/udpfs_smap/ORIGIN.md`). | 1 paragraph |

---

# TASK 3 — UDPRDMA: one reliability layer, two living forks

## 3.1 What is duplicated

The UDPRDMA session/reliability layer exists as source in exactly two places — `RiptOPL/modules/network/udpfs_shared/src/udprdma.c` (738 lines) and `Simple-Media-System/iop/SMSUdpfs/udpfs/src/udprdma.c` (804 lines) — both vendored from neutrino, plus binary copies inside Launchstation's and POPSLoader's precompiled IRXs (not comparable, §"What could not be compared"). The servers re-implement the same layer a third and fourth time (Python `udpfs_server.py` send/window machinery; Go `transfer.go`/`negotiation.go`).

**The shared skeleton is intact:** identical header constants (ACK coalescing 100 ms, retransmit 500 ms, discovery 2 s, max retries 4 — `udprdma_packet.h:42-47` both trees), identical RX ACK window (6, `udprdma.c:32` both), identical state machine shape (DISCOVERY→INFORM→DATA, Go-Back-N, cumulative ACK, one NACK per gap). The server editions independently match the same window parameters (window 8 on their TX side vs the clients' ACK-every-6 — compatible, since ACKs are cumulative).

## 3.2 Where the two C forks have drifted (each carries hardening the other lacks)

| # | Behaviour | RiptOPL fork | SMS fork |
|---|---|---|---|
| D1 | **Wire-controlled app-header size on RX** | **UNCLAMPED.** `_ist` computes `hdr_size = hdr_word_count * 4` (≤60 B) and, when a header buffer is registered, copies that many bytes into it with no comparison to the registered size: `udprdma.c:191-193` (`smap_fifo_read(0x30, s->rx_hdr_buffer, hdr_size)`). The registered buffers are 8 B (`udpfs_msg_result_reply_t` in `_recv_with_result`, `udpfs_core.c:103`) and 8 B (write-done). The drain path is no safer: `dummy[UDPRDMA_MAX_APP_HDR]` = 32 B < 60 B (`udprdma.c:196-198`). | **CLAMPED + drained.** Copies only `if (hdr_size <= s->rx_hdr_size)`, otherwise drains the FIFO in 32 B steps so following payload reads stay in sync: `udprdma.c:198-216`, with a comment (`:186-197`) naming exactly the RiptOPL-side failure ("smashed the ioman thread's stack from the SMAP RX thread"). |
| D2 | **Server-supplied read-result count** | Returns `result.result` as the byte count with no clamp to bytes actually received (`udpfs_core.c:117`). (The per-repo defect is RIPTOPL-043 — referenced, not re-filed.) | Clamps: `if (result.result > ret) return ret;` (`udpfs_core.c:132-135`), plus zero-initialises the result struct so a short/oversized app header can't leave garbage in it (`:91-98`). |
| D3 | **Duplicate-packet handling on RX** | A retransmitted copy of an already-received packet is answered with a fresh cumulative ACK every time (`udprdma.c:228-236`), with a comment explaining the resend-storm abort this prevents. | **Absent.** Any out-of-order/duplicate packet falls into the single-NACK branch (`udprdma.c:246-253`). If the ACK that ends a resend storm is itself lost, SMS's client NACKs (wrong signal — nothing is missing) and waits for the server's timeout resend. |
| D4 | **BREAD end-of-file** | `ret <= 0` is failure, and a short read's tail is **zero-filled** before returning success (`udpfs_core.c:680-688`). | Only `ret < 0` fails (`udpfs_core.c:714-717`): a 0 (EOF) result counts the whole chunk as read, and a short read leaves **stale buffer bytes** in the tail, returned to the caller as disc data. |
| D5 | **ACK-coverage test** | Named helper `udprdma_ack_covers()` (`udprdma_seq.h:8-11`): forward distance < 2048 completes a send; exactly 2048 is ambiguous and must not. Session reset initialises `tx_seq_nr_acked = 0xFFF` "must not cover seq 0" (`udprdma.c:397`). | Inline signed test at both send sites (`udprdma.c:613,682`): `diff >= 0 \|\| diff < -2048` on `(int16_t)((acked − sent) & 0xFFF)` — the second clause is unreachable (the masked value cast to int16_t cannot be < −2048), so the test reduces to the same [0, 2047] set as RiptOPL's. Discovery resets `tx_seq_nr_acked = 0` (`:526`). **Functionally equivalent today (READ)** — same algorithm, two expressions, one dead clause; recorded so a future editor doesn't "fix" one side into divergence. |
| D6 | **Socket lifetime** | Create-once because `udprdma_destroy` can't return the ministack `udp_bind` slot (pool of 4): comment at `udpfs_core.c:249-252`. | Create-once, same reason, independently written comment at `udpfs_core.c:267-286`. | 

D6 is the tell: both forks hit the same upstream trap and fixed it independently, in comments, in two repos — the exact failure mode of a vendored-fork family with no cross-port habit. D1–D4 are the current cost: **four behaviours, each correct in exactly one fork.**

## 3.3 Verdict — Task 3

- **Do not merge the two `udprdma.c` files.** They sit on different dev9 ABIs (SMS's v1.1 rebind is load-bearing, `SMSUdpfs/ATTRIBUTION.md` modification 1) and different build systems; a merged tree saves ~750 lines on paper and costs a permanent two-ABI conditional in practice.
- **Do cross-port the four drifted behaviours** (D1→RiptOPL, D2→RiptOPL, D3→SMS, D4→SMS): each already exists as working code in the sibling fork, so each port is a transcription, not a design. Net effect: both clients reach the same validation posture with ~40 changed lines total and zero new machinery. → X-31, X-32.
- The server-side UDPRDMA re-implementations (Python, Go) match the clients' window/timeout parameters where it matters (window 8 vs ACK-every-6, 100 ms window-ACK timeout, 200-retry ceilings — Python `udpfs_server.py:273-275`, Go `server.go:20-22`); their divergences are the §1.3 items, not transport ones.

---

# APPENDIX — server per-opcode validation (condensed from the full census)

Py-Core equals Py-standalone in every row except B11 (its dispatcher is stricter). Shared dispatchers do no path/size/handle validation in any edition; all checks are per-handler (Python `_handle_data:1641`; Go `server.go:514` + `operations.go:20`).

| Op | Python (standalone = Core) | Go Edge |
|---|---|---|
| OPEN | Path: split-on-NUL, **no length cap**; containment via `_resolve_path:1184` realpath+prefix (escape → EACCES); >64 handles → EMFILE (`_alloc_handle:1413`); mode field unpacked, unused | Path: `cString` ≤1,024 else ENAMETOOLONG (`operations.go:166-176,304`); containment via `root.go:Resolve:72` (EvalSymlinks + escape check; `..`/absolute/drive rejected at `:181`); >64 → EMFILE (`:315`); handle id burned on failed opens (`:319-320`); mode never read |
| READ | Size > 8 MiB cap → EINVAL, checked **before** handle (`:1990`); unknown/dir handle → EBADF; **handle 0 allowed** (shared-position bd read) | Size > transferCap → EINVAL (`:508`); unknown/no-Reader → EBADF (`:517`); **handle 0 → EBADF** |
| WRITE / WRITE_DATA | Declared and assembled sizes capped at 8 MiB → EINVAL (`:2031,2083`); read-only handle → EACCES (`fh.writable()`), incl. compressed wrappers; handle 0 writable if bd is `r+b` | Declared/assembled > cap → **EFBIG** (`:547,598`); no-Writer → EACCES; handle 0 → EBADF |
| CLOSE | len<8 → EINVAL; handle 0 → success, never freed (`:1423,1944`) | len<8 → EINVAL; handle 0 → success no-op; unknown → EBADF (`:473`). **Editions agree.** |
| LSEEK | No whence/offset validation; errors → EINVAL; handle 0 seeks the shared bd object (`:2189`) | No whence/offset validation; handle 0 → EBADF; dirs → EBADF (`:696`) |
| DREAD | Non-dir → EBADF (`:2222`); output names uncapped | Non-dir → EBADF (`:724`); output names truncated to 255 (`:750`) |
| GETSTAT | Empty path = block device if present (`:2306`); path via `_resolve_path` | Empty path = block device if present (`:779`); path via `root.Resolve` |
| MKDIR / REMOVE / RMDIR | Parent-resolved "entry" containment (`_resolve_entry:1214`); REMOVE/RMDIR refuse through-linked folders (`:1251`); RMDIR refuses the root itself (`:2458`); REMOVE has **no** open-writer check | Same shape via `root.Entry:109` / `RealFolders:139`; root refused (`pathops.go:182`); REMOVE **EBUSY if a peer holds it open for writing** (`server.go:154`) |
| BREAD | total = count×512 > cap → EINVAL; 2⁶³ overflow → EINVAL; **no zero-count check, no range check**; positional only via handle's shared position for files | count ≤ 0 → EINVAL (`blockdev.go:139`); total > cap → EINVAL; **handle 0 range-checked** (`inRange:96`); files positional `ReadAt` |
| BWRITE | Declared > cap → EINVAL; overflow → EINVAL; completion **truncates + WRITE_DONE 0** (`_complete_bwrite:2156`) | count ≤ 0 or total > cap → **EFBIG**; completion requires exact length, WRITE_DONE = count (`:329`) |

Containment overall is the one validation family where all three server editions are genuinely strong (realpath/EvalSymlinks + root-prefix or entry resolution, through-link refusals, root self-protection) — stronger, in fact, than the path-*length* posture beside it. Recorded as a positive so it isn't "harmonised" downward.

---

# TASK 2 — Memory-card write patterns across the four PS2 repos

One comparison table; known items are *referenced*, not re-filed (POPSLoader triple-write = POPSLOADER-008; RiptOPL editor/VMC `.bak` = RIPTOPL-013; SMS HistorySave gating = round-2 revision of SMS-028). New facts are the *patterns and asymmetries*, and two of them become findings (X-35, X-39, X-40).

| Repo / save path | Writes per logical save | Pattern | Backup left on card? | Change-gated? |
|---|---|---|---|---|
| **RiptOPL — main settings.** `saveConfig()` `src/app/settingsio.cpp:2555` → `configWriteMulti()` `src/core/config.cpp:1728` → `configWrite()` `src/core/config.cpp:1498` (sets at `config.cpp:28-34`) | **1 per changed set, 0–4 total** | Direct overwrite (`O_WRONLY\|O_CREAT\|O_TRUNC`, `config.cpp:1587`). On `mc:` the snapshot/verify/restore machinery is **explicitly skipped — single open only** (`config.cpp:1541-1553`, comment cites the #340 session: first card save succeeds, later saves fail EMFILE) | No `.bak`, no temp. Off-card only: RAM snapshot restored in place on failure | **Yes — value-level.** `ConfigSet::setStr` marks modified only when the value differs (`config.cpp:360-382`); unmodified set = no-write success (`:1519ff`) |
| **RiptOPL — per-launch `CONFIG_LAST`** (e.g. `src/sources/bdmlaunch.cpp:455`, `ethsupport.cpp:1226`, `hddsupport.cpp:2391`) | **0 in the common case** | Same writer | No | Yes — an untouched view position produces zero writes (`settingsio.cpp:2265-2270` + setStr gating) |
| **Launchstation — legacy CNF.** `saveConfigToPath()` `src/config.c:719` (Save action `config.c:1590-1601`) | **1** (`genOpen` TRUNC + one `genWrite`, `config.c:756-783`) | Direct overwrite, **no verify** | No | **No** — explicit Save writes unconditionally |
| **Launchstation — dashboard store.** `dashStoreSaveSettings()` `src/dash_store.c:683` → `dashStoreFlush():659` → `dashWriteFile():148`; classic CNF via `cfgSaveRun()` `src/dash_settings.c:2287` | **1 write + 1 full read-back verify** per file; one flush can cover `DASHBOARD.CNF` + `DASHAPPS.CNF` + `DASHLIB.CNF` (`dash_store.c:622-624`) | Direct overwrite + byte-compare read-back (`dash_store.c:148-176`). No temp/rename | No | **Mixed.** Dashboard Settings proper is text-gated (`refreshDirty()` memcmp + serialised-text compare, `dash_settings.c:2405-2430`; "Nothing to save" at `:2524ff`); the store layer only *coalesces* (flush after ≥700 ms pad idle, `dash_main.c:1481`) and many callers mark dirty unconditionally (`dash_apps.c:336,352,413,465` …) |
| **Launchstation — per-launch Recent.** `dashStorePushRecent()` `dash_store.c:~848-866` | **1 file rewrite per app launch** | Same store flush | No | **No** — no already-at-front / content check in the function (identical-content rewrite on relaunching the most-recent app: INFERRED from the absence of any comparison) |
| **Launchstation — IPCONFIG.DAT.** `configWriteNetworkSnapshot()` `src/config_network.c:13` | 1 (read old, TRUNC write preserving tail) | Direct overwrite, no verify | No | n/a (snapshot semantics) |
| **POPSLoader — main settings.** `PLDR.CommitSettingsChanges()` `bin/POPSLDR/system.lua:6567` → `SaveSettingsAtomic():6145` → `WriteAtomic():5261` | **3 content writes** (POPSLOADER-008; up to 6 on fallback paths, INFERRED) | Write `.tmp` → rename dest→`.bak` → rename `.tmp`→dest → delete `.bak`; `System.rename` is copy+delete, not atomic (`system.lua:5230-5233`) | No — `.bak`/`.tmp` transient, deleted on success (`:5257-5259`), `.bak` restored on promote failure | **No** — a pre-save snapshot is taken (`:6576`) but never equality-checked before saving (`:6655`) |
| **POPSLoader — per-device game-list cache.** `PLDR.SaveGameListCache()` `system.lua:9880` | **3 (WriteAtomic)** per rescan / page scan / hide-toggle (call sites `ui.lua:4169-4236, 4317-4318`, page entries) | Same triple-write | No | Opt-in flag only (`PLDR.GAMELIST_CACHE`, default off, `:9881`) — with the flag on, every listed event rewrites |
| **POPSLoader — HDD game-list cache.** `PLDR.HDD.CreateCache()` `system.lua:9944` | **1** (direct `openFile(FCREATE)` + write + close, `:9977-9987`; deletes own file on short write) | Direct overwrite | No | Same opt-in flag (`:9945`) |
| **POPSLoader — Ember profiles.** `PLDR.EmberRewriteSettings()` `system.lua:8944` → `WriteAtomic():8978` | 3 when changed, **0 when unchanged** | Triple-write, but content-gated: `if after == before then return` (`:~8975-8977`) | No | **Yes** — the only equality gate in POPSLoader's save family |
| **SMS — main config, both paths.** `SMS_SaveConfig()` `src/SMS_Config.c:878`: FS/CWD branch `:885`, native-mc branch `:978` | **1** (`fioOpen(O_WRONLY\|O_CREAT)` `:902`/`:1062`, one `fioWrite` of the fixed-size blob `:941`/`:1066`). First-ever save +2–4 for icons, existence-gated in both branches (`:~805-822`, `:1028-1058`) | Direct overwrite, **no `O_TRUNC`**, no verify, no temp (SMS-011's "duplicated save paths" = these two mutually exclusive branches of one function) | No | **No — no dirty check anywhere in the function.** And it is called as a side effect: unconditionally before every IOP network switch (`src/SMS_IOP.c:1786`) and as a gate before unrelated copy-to-MC operations (`src/SMS_GUIFileCtxMenu.c:212,235,309,334`), besides the explicit menu save (`SMS_GUIMenuSMS.c:1003-1007`) |
| **SMS — secondary.** `SMS_SaveSMBInfo()` `SMS_Config.c:388` | 1, with `O_TRUNC` | Direct | No | Only on SMB add/delete. (The fixed-size config blob is the *only* SMS save without `O_TRUNC` — History and IPCONFIG saves both use it, `SMS_History.c:163-170`, `SMS_GUIMenuSMS.c:2073-2078`; benign today only because the blob never changes size — INFERRED.) |

**Flush/sync, all four repos:** no post-write fsync/sync exists in any main save path — close is the flush everywhere. SMS's `MC_Sync` (`SMS_Config.c:~985`) and Launchstation's `mcSync` (`config.c:363-368`) run *before* writes (device info/mkdir), not after.

**The pattern verdict:** the family's centre of gravity is *one direct write, gated* — RiptOPL achieves it with value-level dirty bits and goes further on cards than anywhere else (deliberately stripping its own snapshot/verify on `mc:` for a documented EMFILE reason, `config.cpp:1541-1553`); Launchstation's dashboard achieves it with text-compare + read-back verify, while its legacy writer and its Recent-list path don't gate at all; POPSLoader pays 3× writes for atomicity on its *settings* (defensible) and on a *disposable cache* (not — X-39) while its one equality gate sits on Ember profiles; SMS alone never gates its main save and invokes it from unrelated operations (X-35). Nobody in the family uses temp+rename on the card except POPSLoader, and nobody leaves a `.bak` behind on success anywhere in this table (the `.bak` habit survives only in the already-filed editor/VMC paths, RIPTOPL-013).

---

# NEW CROSS FINDINGS (X-31…)

### X-31 / RiptOPL's UDPRDMA receive path copies a wire-controlled app header into an 8-byte stack buffer, unchecked — SMS's fork of the same file has the clamp
- **Category:** 6 (bug/security) — cross-repo validation asymmetry (§3 D1)
- **Locations:** RiptOPL `modules/network/udpfs_shared/src/udprdma.c:185-199` (esp. `:192-193`) + registered buffer at `modules/network/udpfs_shared/src/udpfs_core.c:100-103` (8-byte `udpfs_msg_result_reply_t`), write-done buffer 8 B at `udpfs_core.c:22`. SMS `iop/SMSUdpfs/udpfs/src/udprdma.c:186-216` (the clamp + drain + explanatory comment).
- **Problem:** `hdr_word_count` is a 4-bit wire field → `hdr_size` up to 60 bytes. RiptOPL's `_ist` feeds it unchecked to `smap_fifo_read(0x30, s->rx_hdr_buffer, hdr_size)` whenever a header buffer is registered and not yet filled; the registered buffers are 8 bytes. The no-buffer drain path reads into `dummy[32]`, also < 60. A server (buggy, version-skewed, or hostile on the LAN) sending a DATA packet with `hdr_word_count` ≥ 3 overruns the ioman thread's stack from the SMAP RX thread. SMS's fork checks `hdr_size <= s->rx_hdr_size` before copying and drains oversized headers in 32-byte steps — its comment at `:186-197` describes this exact overflow as the reason.
- **Fix:** transcribe SMS's clamp-and-drain block into RiptOPL's `_ist` (both branches: registered-buffer copy gated on `rx_hdr_size`, drain in `sizeof(dummy)` steps). No new machinery — the code exists, reviewed, in the sibling fork.
- **Benefit:** closes a remotely triggerable IOP stack overflow in the flagship client's network path.
- **Effort:** S · **Risk:** Low (receive-path only, behaviour identical for conforming servers) · **Confidence:** High (READ, both sides, full functions).

### X-32 / The two C UDPRDMA/UDPFS forks carry disjoint hardening — each is missing fixes the other already has
- **Category:** 2/6 (duplication drift with bug consequences) — §3 D2–D4 (D1 is X-31)
- **Locations:** (D2) SMS clamp `iop/SMSUdpfs/udpfs/src/udpfs_core.c:132-135` + zero-init `:91-98` vs RiptOPL unclamped return `modules/network/udpfs_shared/src/udpfs_core.c:117` (the RiptOPL-side defect itself is RIPTOPL-043, referenced not re-filed — the cross fact is that the fix already exists in-family). (D3) RiptOPL duplicate-packet cumulative-ACK `udprdma.c:228-236` vs SMS NACK-only branch `iop/SMSUdpfs/udpfs/src/udprdma.c:246-253`. (D4) RiptOPL BREAD EOF/short-read handling `udpfs_core.c:680-688` vs SMS `iop/SMSUdpfs/udpfs/src/udpfs_core.c:714-717` (EOF-0 counted as a full chunk; short-read tail left as stale buffer bytes returned as disc data).
- **Problem:** two vendored copies of one ~1,600-line protocol stack are being hardened independently; every fix lands in exactly one fork. D6 (§3) shows the same trap (bind-slot lifetime) was already solved twice, independently, in comments.
- **Fix:** one cross-port pass, four transcriptions (D1 in X-31; D2→RiptOPL; D3→SMS; D4→SMS), then both `ATTRIBUTION/ORIGIN` notes gain one line: "hardening cross-ported from <sibling>, <date>". Do **not** merge the trees (different dev9 ABI and build systems — §3.3).
- **Benefit:** both clients reach the same validation posture; the next fix has a named route to both.
- **Effort:** S–M · **Risk:** Low · **Confidence:** High (READ; full-file diff of both cores, 102 changed lines accounted for).

### X-33 / The three server editions honour three different limit sets — and the Python editions honour none of the header's
- **Category:** 6/3 (protocol posture / over-engineering by divergence) — §1.3 B1–B4
- **Locations:** C contract `RiptOPL/modules/network/udpfs_ioman/src/udpfs_packet.h:56-60` (path 256, read 64 KiB, sector-read 128). Python: no path cap (`udpfs_server/udpfs_server.py:1789,2294,2368`), transfer cap 8 MiB default (`:285-301`), no sector cap (`:2483,2551`). Go: path 1,024 (`native/ps2servers-edge/internal/udpfs/server.go:24`), transfer cap RAM/16 ≤ 8 MiB (`internal/memory/budget.go:103-114`), no sector cap (`internal/udpfs/blockdev.go:132,219`). Errno split: Python EINVAL vs Go EFBIG on over-cap WRITE/BWRITE.
- **Problem:** identical requests are legal or refused depending on edition and, for Go, on the host's RAM. The Python path posture is the outlier with teeth: any path length a datagram can carry is walked against the filesystem. None of this breaks the two C clients (they self-limit to the header values), which is exactly why it has drifted unnoticed — it binds only other clients, including PS2-Servers' own 200 KB-read selftest.
- **Fix:** one agreed limit table for the server app (the header's numbers, or a deliberate replacement set sized from the selftest's real 200 KB read), transcribed into both editions; align the over-cap errno. This is a decision plus two small edits per edition — not a shared library.
- **Benefit:** one protocol posture per protocol; the Python path walk gains a bound.
- **Effort:** S · **Risk:** Low (raise Python's caps from "none" only where a real client needs room) · **Confidence:** High (READ).

### X-34 / Identical UDPFS packets get different outcomes from the two server languages (handle 0, block range, write completion)
- **Category:** 6 (protocol correctness) — §1.3 B5–B9
- **Locations:** Python `udpfs_server/udpfs_server.py` — handle-0 READ/LSEEK/WRITE via shared seek position (`:1969,2189,2031`), no block range check (`:2483,2551`), BWRITE completion truncates + WRITE_DONE 0 (`:2156`), short WRITE_REQ/BWRITE_REQ silently ACK-only (`:2037,2551`), disorder keeps partial buffer armed (`:2110`). Go `native/ps2servers-edge/internal/udpfs/` — handle 0 BREAD/BWRITE-only (`operations.go:517,696`), `inRange` refusal (`blockdev.go:96`), completion requires exact length, WRITE_DONE = count (`blockdev.go:329`), short requests answered EINVAL (`operations.go:552`).
- **Problem:** BWRITE past the image end **extends the image file** against Python and errors against Go; a successful block write reports 0, the byte count, or an error depending on edition; a malformed short request costs a 5 s client timeout against Python and an instant EINVAL against Go. Clients cannot be written against "the protocol" — only against an edition.
- **Fix:** adopt Go's semantics in Python for these five points (they are the stricter, self-consistent set; Python's own file-write completion already returns the byte count Go returns). Per-point edits in the cited handlers; no new machinery.
- **Benefit:** one observable protocol; removes silent image growth.
- **Effort:** M · **Risk:** Med (behaviour change for any client unknowingly relying on truncation — none in these repos; both C clients send exact lengths) · **Confidence:** High (READ, handler-level both sides).

### X-35 / SMS is the only PS2 repo whose main config save is never change-gated — and it fires as a side effect of unrelated operations
- **Category:** 5/4 (performance / card wear) — Task 2 table
- **Locations:** SMS `src/SMS_Config.c:878` (no dirty check in the function; branches `:885`, `:978`); unconditional callers `src/SMS_IOP.c:1786` (before every IOP network switch), `src/SMS_GUIFileCtxMenu.c:212,235,309,334` (gate before copy-to-MC operations). Contrast: RiptOPL value-gating `src/core/config.cpp:360-382,1519ff`; Launchstation text-gating `src/dash_settings.c:2405-2430`; POPSLoader Ember equality gate `bin/POPSLDR/system.lua:~8975-8977`.
- **Problem:** every network switch and every copy-to-card first rewrites `SMS.cfg` whether or not a setting changed — a full config write (plus, on the mc branch, the surrounding MC calls) spent on a no-op, on the slowest, most wear-sensitive storage in the system. All three siblings gate the equivalent save by three different mechanisms; SMS has none.
- **Fix:** the smallest gate the codebase already proves elsewhere: compare the in-RAM `g_Config` against a saved-copy snapshot (SMS already snapshots config-sized structs for its TEMP diagnostic paths) and skip the write when identical — or, smaller still, only call `SMS_SaveConfig` from those side-effect sites when a "config dirty" flag set by the settings UI is raised. No new persistence machinery.
- **Justification (addition):** one flag/buffer vs a card write per network switch and per copy operation, forever.
- **Benefit:** removes the family's only unconditional-save side effect.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; caller list grep-verified).

### X-36 / SMS carries two UDPFS front-ends it never builds (bd + fhi, 267 lines)
- **Category:** 1/7 (dead code / repo clutter) — §1.4
- **Locations:** SMS `iop/SMSUdpfs/udpfs/src/udpfs_bd.c` (132), `udpfs_fhi.c` (135), variant arms in `iop/SMSUdpfs/udpfs/Makefile:8-22`. Build proof: `tools/build_udpfs.sh:54` builds `UDPFS_IOMAN=1` only; top-level `Makefile:53` embeds only `udpfs_ioman_irx.o`.
- **Problem:** the files exist solely because the neutrino vendor was wholesale. RiptOPL legitimately builds all three variants (it has three consumers); SMS has one. The dead variants also dilute §3's drift problem — a future cross-port editor must guess which SMS files are live.
- **Fix:** delete the two files and their Makefile arms from SMS (keep them in RiptOPL, where they are used). If a block-device SMS is ever wanted, the source remains one vendor away.
- **Benefit:** −267 lines and one ambiguity in SMS; zero behaviour change.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ, build files included).

### X-37 / DiscHeader bytes 2–3: "reserved, must be 0" in the C spec, a live data port in the Python server
- **Category:** 6/8 (protocol definition drift) — §1.2 divergence 1
- **Locations:** C `RiptOPL/modules/network/udpfs_ioman/src/udprdma_packet.h:70-76` (identical in SMS's copy); Python field def `udpfs_server/udpfs_server.py:493-505`, live use `:2656`; C clients ignore the field and use the UDP source port (RiptOPL `udprdma.c:166`; SMS `udprdma.c:163`); Core/Go canonical INFORM sends 0 from the data socket (`ps2servers_core.py:226-235`; Go `negotiation.go:195`).
- **Problem:** the family's written spec contradicts a shipped server's behaviour. Today every working path sends INFORM from the data socket, so the field is redundant — but a client written tomorrow from the C header's *other* natural reading (trust the advertised port) breaks against C-lineage servers that send 0, and a client written from the Python behaviour breaks the C header's "must be 0".
- **Fix:** correct the comment in the C headers (both repos, one line each: "data port; clients in this family use the packet's source port and ignore it") — documentation only, no code changes anywhere.
- **Benefit:** the spec stops lying; zero risk.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

### X-38 / Go Edge zeroes all timestamps and attrs in UDPFS replies the other editions fill
- **Category:** 6/8 (reply-content divergence) — §1.2 divergence 2
- **Locations:** Go `native/ps2servers-edge/internal/udpfs/operations.go:464` (OPEN_REPLY), `:748` (DREAD_REPLY), `:809` (GETSTAT_REPLY) — 48/36-byte buffers with time/attr fields left zero. Python fills real values (`udpfs_server.py:3045,3109,3142`). C clients consume the fields into `iox_stat_t` (RiptOPL `udpfs_core.c` dread/getstat paths).
- **Problem:** layouts agree, content doesn't: against Edge, every file on `udpfs:` reports epoch-zero dates and no attributes. Any client UI that shows or sorts by date (both C clients surface the fields) silently degrades for Edge users only.
- **Fix:** populate the fields from the same `os.FileInfo` the handlers already stat with (Python's `_ps2_time`-style conversion is the in-repo reference). No layout change.
- **Benefit:** reply parity across editions.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

### X-39 / POPSLoader pays triple-write atomicity for a disposable cache and a single direct write for the same-format HDD cache
- **Category:** 4/5 (card writes / consistency of judgement) — Task 2 table
- **Locations:** per-device cache `bin/POPSLDR/system.lua:9880` → `WriteAtomic():5261` (3 writes, on rescans, page scans, every hide toggle — `ui.lua:4169-4236,4317-4318`); HDD cache `system.lua:9944` → direct write `:9977-9987` (1 write). Same PLDRGC1 format and purpose (the pair is POPSLOADER-029's duplication — referenced, not re-filed; the *write-cost inversion* is the new fact).
- **Problem:** the regenerable data (a game-list cache, rebuildable by rescan) gets the family's most expensive write pattern, while its identical twin gets the cheapest. If the cache is worth atomicity, both are; if it isn't (it isn't — a torn cache is detected by its own format checks and rescanned), neither is.
- **Fix:** write the per-device cache the way `HDD.CreateCache` already writes — direct, with the short-write self-delete that function already has. Settings keep WriteAtomic.
- **Benefit:** 3× fewer writes on every rescan/page-scan/hide-toggle against cards and USB.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

### X-40 / Launchstation rewrites DASHAPPS.CNF on every app launch; RiptOPL's equivalent launch save writes nothing
- **Category:** 5 (card wear) — Task 2 table
- **Locations:** Launchstation `src/dash_store.c:~848-866` (`dashStorePushRecent` — no at-front/content check before `dashStoreSaveLists`); contrast RiptOPL's per-launch `saveConfig(CONFIG_LAST)` value-gated to zero writes (`src/app/settingsio.cpp:2265-2270`, `src/core/config.cpp:360-382`).
- **Problem:** launching the already-most-recent app — the single most common launch — rewrites the apps file with (in that case) identical content. INFERRED for the identical-content case: the function contains no comparison at all, so the write happens regardless; only the content-identity of that specific case is reasoned, not read from a trace.
- **Fix:** skip the save when the launched path is already the head of the Recent list (one comparison in `dashStorePushRecent`, the check RiptOPL's gating achieves by construction).
- **Benefit:** removes a per-launch card write in the most common case.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ for the missing check; INFERRED for content identity).

---

# What could not be compared, and why

- **Live wire interop was not run and wire agreement in §1.2 is a SOURCE-level claim.** This sandbox blocks UDP `sendto` (the same restriction recorded in rounds 1–2); no packet was exchanged between any two implementations during this census. PS2-Servers ships a differential host harness for exactly this (`conformance/integration/udpfs_parity.py` — drives udpfsd, Core and Edge with identical fixtures over real sockets); it could not run here, and it is a host test, not console acceptance. Layout agreement is proven; runtime agreement is not claimed.
- **Launchstation's and POPSLoader's UDPFS cores are binaries.** Their wire behaviour cannot be source-compared: Launchstation's `udpfs_ioman.irx`/`udpfs_ministack.irx` are precompiled (`iop/__precompiled/`; only its smap is source, pinned to the same neutrino commit `06188cce` as RiptOPL's vendor), and POPSLoader's embedded trio has hashes but no stated provenance. They are census-listed, not census-compared.
- **POPSLoader's POPStarter-runtime driver (Okeanos UDPFS Assault 1.0.1) has no source in any of the five repos** (`docs/third_party/okeanos_udpfs/PROVENANCE.json` pins release hashes only). Whether that fork's validation posture matches §1.3 cannot be determined from this audit's scope; its docs (`docs/UDPFS_BDMA.md`) assert it speaks to `udpfs_server.py` and `udpfsd`, which is a claim about the *server* side only.
- **pcm720/udpfsd (the external reference server)** is not one of the five repos and was not audited; where the Python code comments cite its behaviour (session timeout, handle caps) that is reported as the code's own rationale, not independently verified.
- **No PS2 build or hardware exists in this VM** (standing audit constraint): ELF-size and timing consequences of any fix here are structural, and nothing in this file is hardware-verified.
- **Category 5 magnitudes for Task 2** are write *counts* read from code (exact), not measured card timings; the INFERRED items are flagged inline (POPSLoader fallback-path write count, SMS no-TRUNC benignness, X-40's identical-content case).

## Files in this round's deliverable

- Sable-CROSSREPO-ROUND3.md (this file) — UDPFS master census + wire verdicts, UDPRDMA drift table, memory-card write-pattern table, findings X-31…X-40.
