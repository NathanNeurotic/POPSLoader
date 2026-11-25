# REDO Audit — W05: RiptOPL network stack (SMSTCPIP + SMSUTILS + ps2ips + common)

- **Clone:** `~/workspace/audit-clones-2026-11-13/RiptOPL`
- **HEAD verified:** `2e347d5ac885cd0ff73e9ad4143781946396f492` (git rev-parse, matches brief)
- **Scope:** `modules/network/SMSTCPIP/` (57 files), `modules/network/SMSUTILS/` (2 files), `modules/network/ps2ips/` (4 files), `modules/network/common/` (9 files) — 72 files total (census by `find`/`wc`, run this session)
- **Method:** every file read in full (licence preambles skimmed); every count below comes from a command actually run; READ = code seen at the cited lines, INFERRED = reasoned consequence.

---

## W05-001 — `err_to_errno` macro never consults its table: every socket error collapses to EIO

- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/sockets.c:81-98`
- **Problem:** The table at lines 81–93 maps err_t 0…−10 to distinct errnos (ENOMEM, ECONNRESET, EADDRINUSE, …). The macro at 95–98 tests `((err) < (sizeof(err_to_errno_table)/sizeof(int)))`. `sizeof` yields an unsigned type, so any negative `err` is converted to a huge unsigned value and the comparison is false for every error — the macro always returns EIO. Verified by host-compiling the exact macro text in /tmp: err 0 → 0, err −1…−11 → errno 5 (EIO) for all. Second defect in the same lines: `err_t` runs to ERR_IF = −11 (`include/lwip/err.h`), but the table has only 11 entries (0…−10), so even a corrected comparison would index one past the end for ERR_IF.
- **Fix:** Compare `-(err)` against the table length (or cast the size to a signed type) and add the missing ERR_IF entry.
- **Benefit:** Callers above the IOP (SMB/HTTP drivers, EE RPC) can finally distinguish ENOMEM / ECONNRESET / EADDRINUSE / EHOSTUNREACH instead of seeing EIO for everything; error-handling and retry decisions built on errno become meaningful.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; macro behaviour executed in a host test)

## W05-002 — EE RPC socket surface is wired end-to-end to an empty stub

- **Category:** 8 half-finished/redundant features
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/exports.tab:17-24,30`; `RiptOPL/modules/network/SMSTCPIP/ps2ip.c:268-271`; `RiptOPL/modules/network/ps2ips/ps2ips.c:468-480,482-513,515-525,526-556,558-575`; `RiptOPL/modules/network/common/smstcpip.h:56-57,109-121,147-150`
- **Problem:** Export slots for lwip_select (14), lwip_ioctl (15), lwip_getpeername (16), lwip_getsockname (17), lwip_getsockopt (18), ps2ip_setconfig (20), ps2ip_getconfig (21) and netif_find (27) are all `ps2ip_Stub` in every build — and `ps2ip_Stub` is an empty `void` function. Yet ps2ips implements and dispatches RPC handlers for exactly these operations (do_select, do_ioctlsocket, do_getsockname, do_getpeername, do_getsockopt, do_getconfig, do_setconfig), imports the symbols, and `common/smstcpip.h` declares matching imports for other IOP modules. Every EE-side select/ioctl/getsockopt/getsockname/getpeername/getconfig/setconfig call therefore lands on a no-op and the caller reads back whatever the return register happened to hold (INFERRED ABI consequence; the stub wiring itself is READ).
- **Fix:** Decide once: either export the real implementations (they exist, gated — see W05-003) or delete the ps2ips handlers, the ps2ips imports, and the `smstcpip.h` import declarations so the missing feature fails loudly at link time instead of silently at runtime. Deleting is the LESS option if nothing on the EE actually needs these calls.
- **Benefit:** Removes a silent-garbage result path from the EE↔IOP RPC surface; whichever way it is decided, behaviour becomes explicit.
- **Effort:** M · **Risk:** Med (EE callers, out of scope here, may unknowingly depend on the garbage return) · **Confidence:** High (READ)

## W05-003 — The FULL_LWIP subsystem (~627 gated lines) is dead and cannot link if enabled

- **Category:** 1 dead code / 8 half-finished features
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/sockets.c:474-479,623-628,630-810,899-1185,1377-1415` (gates at 474, 623, 630, 899, 1377); `RiptOPL/modules/network/SMSTCPIP/ps2ip.c:97-152`; `RiptOPL/modules/network/SMSTCPIP/netif.c:110-161`; `RiptOPL/modules/network/SMSTCPIP/Makefile` (`FULL_LWIP?= 0`)
- **Problem:** Behind `#ifdef FULL_LWIP` (Makefile default 0) sit complete implementations of lwip_read, lwip_write, lwip_select, lwip_getpeername, lwip_getsockname, lwip_getsockopt, lwip_ioctl, ps2ip_getconfig/setconfig and netif_remove/netif_find. They are unreachable in practice for two independent reasons: (1) exports.tab stubs their slots unconditionally, even in a FULL_LWIP=1 build (W05-002); (2) the FULL_LWIP setconfig path calls dhcp_start/dhcp_stop, but there is no dhcp.c anywhere under `modules/network/` (`find` returned 0) — enabling the flag cannot link (INFERRED link failure; file absence is READ). Supporting detail: lwip_select's timeout path is also broken inside the gate — it compares the result of `sys_sem_wait_timeout` (a macro returning 0/1, `include/lwip/sys.h:81`) against `SYS_ARCH_TIMEOUT` (−418), so the timeout branch can never run. A comment block at `include/lwipopts.h:313-364` still claims getsockopt was exported; it was not.
- **Fix:** Delete the FULL_LWIP-gated blocks, the Makefile option, and the stale lwipopts.h comment. If the feature is ever wanted, it has to be finished as one piece (exports + DHCP), not resurrected from this gate.
- **Benefit:** ~627 lines of unmaintainable, untestable socket code leave the tree; nobody can flip a Makefile flag into a link failure.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ; link failure INFERRED from verified file absence)

## W05-004 — ARP entries never expire: `etharp_tmr` is never scheduled because `LWIP_ARP` is defined nowhere

- **Category:** 8 half-finished features / 6 bugs
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/timers.c:103-125`; `RiptOPL/modules/network/SMSTCPIP/etharp.c:191,209-229`; `RiptOPL/modules/network/SMSTCPIP/include/lwip/opt.h:138`
- **Problem:** `arp_timer()` and its scheduling inside `sys_timeouts_init()` are wrapped in `#if LWIP_ARP`. A grep for any definition of LWIP_ARP across SMSTCPIP (headers, lwipopts.h, Makefile) returns 0 hits, so both compile out and `etharp_tmr()` never runs: ARP entries never age, ARP_MAXAGE/ARP_MAXPENDING are dead constants, and a stale gateway/server MAC persists for the whole session (with ARP_TABLE_SIZE only 2–4, lwipopts.h). `sys_timeouts_init()` itself is left as an empty function. Separately, `etharp_init()` (etharp.c:191) has no caller anywhere in the tree (harmless today because the table is statically zero-initialised to ETHARP_STATE_EMPTY). The memp sizing comment at opt.h:138 — `(LWIP_TCP + LWIP_ARP)` timeouts — shows the ARP timer was expected to exist.
- **Fix:** Define LWIP_ARP to 1 in lwipopts.h (one line; restores the intended periodic aging), or, if permanent entries are actually desired, delete `etharp_tmr`/`arp_timer` and say so in the config. The one-line define is the smallest change that makes the shipped code do what it says.
- **Justification (fix adds a define):** It activates code already in the tree rather than adding a new mechanism; the alternative (deleting the timer) changes observable behaviour more.
- **Benefit:** ARP cache behaves as the code and comments describe; a changed router/server MAC is picked up without a reboot.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ + grep-verified absence)

## W05-005 — SOCK_RAW is accepted, then silently hollow

- **Category:** 8 half-finished features
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/sockets.c:586-589`; `RiptOPL/modules/network/SMSTCPIP/api_msg.c` (all `#if LWIP_RAW` cases, e.g. lines 297, 355, 412, 444, 496, 547, 598, 626, 669, 696, 739, 787); `RiptOPL/modules/network/SMSTCPIP/include/lwip/opt.h:111-113`; `RiptOPL/modules/network/SMSTCPIP/memp.c:62,75,89-91`; `RiptOPL/modules/network/SMSTCPIP/include/lwip/raw.h` (whole file, 75 lines)
- **Problem:** `lwip_socket` accepts SOCK_RAW and creates a NETCONN_RAW netconn, but LWIP_RAW is defined nowhere and there is no raw.c in the tree (`find` = 0), so no PCB is ever created for it: do_bind/do_send for RAW fall through their compiled-out cases and report success while doing nothing. Meanwhile the memp pool still reserves MEMP_NUM_RAW_PCB = 4 entries in every build, and raw.h ships a full API (raw_new/raw_bind/raw_send/…) with no implementation behind it.
- **Fix:** Reject SOCK_RAW in lwip_socket with a protocol-not-supported error, and delete the RAW memp pool entries and raw.h. (Actually implementing raw sockets is the MORE option and is not justified by any in-tree user.)
- **Benefit:** socket() stops returning a descriptor that can never work; a small permanent IOP memory saving from the dead pool.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ + grep/find verified)

## W05-006 — `do_bind` dereferences unchecked `udp_new()`/`tcp_new()` results

- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/api_msg.c:420-437` (do_bind), contrasted with `api_msg.c:505-540` (do_connect)
- **Problem:** do_bind's UDP branch calls `udp_new()` and immediately uses the result in udp_setflags/udp_recv/udp_bind; the TCP branch does the same with `tcp_new()` into setup_tcp. Neither checks for NULL. Exhaustion is realistic: MEMP_NUM_UDP_PCB is 1 in every build (`include/lwipopts.h:65`) and MEMP_NUM_TCP_PCB is 1–2. do_connect, in the same file, checks every allocation — the inconsistency is the local fact. A NULL return means a NULL dereference inside the tcpip thread (INFERRED crash consequence; unchecked use is READ).
- **Fix:** NULL-check both allocations in do_bind, set `conn->err = ERR_MEM` and ACK, mirroring do_connect's existing pattern — no new mechanism.
- **Benefit:** Pool exhaustion returns an error to the caller instead of taking down the stack thread.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W05-007 — Sequential API and `lwip_accept` dereference NULL conn/PCB states the socket layer itself documents

- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/api_lib.c:422` (netconn_recv), `api_lib.c:538` (netconn_write), `api_lib.c:261-281` (netconn_peer/netconn_addr); `RiptOPL/modules/network/SMSTCPIP/sockets.c:180-196` (lwip_accept); documented state at `sockets.c:949,1086,1288-1293`
- **Problem:** One mechanism, several sites: missing NULL checks on conn/PCB. netconn_recv reads `conn->pcb.tcp->state` and netconn_write calls `tcp_sndbuf(conn->pcb.tcp)` with no NULL check — yet sockets.c itself documents (and patched getsockopt/setsockopt/getsockname for) the state where a failed connect leaves `pcb.tcp == NULL` with the descriptor still open; recv/write were not patched. netconn_peer/netconn_addr lack the `conn == NULL` check their sibling functions have, and netconn_addr's RAW case dereferences `pcb.raw` unchecked. lwip_accept calls `netconn_peer(newconn, …)` without checking netconn_accept's return (api_lib.c:383-398 returns NULL for a NULL/failed conn), and dereferences `*addrlen` and memcpy's into `addr` unconditionally.
- **Fix:** Add the same NULL guards the sibling functions already use (return ERR_CONN / set EBADF-style errno), and check newconn in lwip_accept before netconn_peer.
- **Benefit:** A failed connect followed by a recv/write — a normal application error path — returns an error instead of dereferencing NULL inside the stack.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W05-008 — `pbuf_realloc` use-after-free chain through `ps2ip_mem_realloc`

- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/ps2ip.c:558-569`; `RiptOPL/modules/network/SMSTCPIP/mem.c:109-121`; `RiptOPL/modules/network/SMSTCPIP/pbuf.c:438-441`
- **Problem:** `ps2ip_mem_realloc` frees the old block first, then calls AllocSysMemory for the new size; if that fails it returns NULL with the original block already gone (the comment at ps2ip.c:556-557 admits the code assumes this cannot fail). `mem_realloc` propagates the NULL, and `pbuf_realloc` ignores the return value entirely and keeps adjusting and using the chain (`q->len` at pbuf.c:441) — a use-after-free on the allocation-failure path.
- **Fix:** Make ps2ip_mem_realloc allocate the new block before freeing the old one and return the old block on failure (the standard realloc contract); that single change fixes every caller, including pbuf_realloc's unchecked use.
- **Benefit:** Memory pressure degrades to an allocation error instead of corrupting a live pbuf chain.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; failure likelihood INFERRED)

## W05-009 — TCP header length from the wire is trusted; `pbuf_header` result ignored

- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/tcp_in.c:120,157-158,1090-1121`; `RiptOPL/modules/network/SMSTCPIP/pbuf.c:482-491`; `RiptOPL/modules/network/SMSTCPIP/include/lwipopts.h:371-400`
- **Problem:** tcp_input checks only that tot_len ≥ sizeof(struct tcp_hdr), then computes `hdrlen = TCPH_HDRLEN(tcphdr)` (up to 15 → 60 bytes) and calls `pbuf_header(p, -(hdrlen*4))` ignoring its return. A segment claiming hdrlen 60 with tot_len 20 passes the minimum check; pbuf_header's forward move does not fail on the lower bound, so the u16 len/tot_len accounting underflows, and tcp_parseopt then walks options bounded by the same untrusted hdrlen. In the in-game build all CHECKSUM_CHECK_* are 0 (lwipopts.h:371-400), so there is not even a checksum gate in front of this path there. (Impact chain INFERRED; the missing validation is READ.)
- **Fix:** Before pbuf_header, drop the segment unless `TCPH_HDRLEN(tcphdr)*4 <= p->tot_len` (and ≥ TCP_HLEN); honour pbuf_header's return.
- **Benefit:** A malformed or hostile segment from the LAN is dropped instead of corrupting pbuf length accounting inside the stack.
- **Effort:** S · **Risk:** Low · **Confidence:** High for the code facts (READ), Med for impact (INFERRED)

## W05-010 — `copy_from_pbuf` walks off the end of the pbuf chain

- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/ip_frag.c:61-81,153`; `RiptOPL/modules/network/SMSTCPIP/ip.c:241`; `RiptOPL/modules/network/SMSTCPIP/pbuf.c:410-413`
- **Problem:** copy_from_pbuf loops `for (; len; p = p->next)` dereferencing `p->len` with no NULL check. The length comes from the fragment's IPH_LEN, and ip_input's preceding `pbuf_realloc(p, ntohs(IPH_LEN))` cannot grow a chain (pbuf.c:410-413 returns the chain unchanged when new_len ≥ tot_len), so a fragment whose claimed length exceeds the received bytes reaches ip_reass with a shorter chain than the copy loop expects, and the loop dereferences NULL. (Trigger construction INFERRED; the unguarded walk and the no-grow realloc are READ.)
- **Fix:** Stop the walk at chain end (treat as a length error and drop the fragment).
- **Benefit:** A truncated/lying fragment is dropped instead of dereferencing NULL in the reassembly path.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ code, INFERRED trigger)

## W05-011 — `icmp_dest_unreach` uses an unchecked `pbuf_alloc` result

- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/icmp.c:138-147`; callers at `RiptOPL/modules/network/SMSTCPIP/ip.c:319` and `RiptOPL/modules/network/SMSTCPIP/udp.c:380`
- **Problem:** icmp_dest_unreach allocates `q = pbuf_alloc(PBUF_IP, 8 + IP_HLEN + 8, PBUF_RAM)` and immediately writes through `q->payload` and memcpys into it, with no NULL check. It is reachable from ip_input's default-protocol case and from udp_input's no-matching-PCB case — i.e. from ordinary inbound traffic. In the in-game build MEM_SIZE is 0x400, so RAM allocation failure is not exotic (likelihood INFERRED; the unchecked use is READ).
- **Fix:** NULL-check q and return (freeing nothing) on failure, as other pbuf_alloc call sites in the tree already do.
- **Benefit:** Memory pressure during inbound traffic returns no ICMP reply instead of a NULL dereference.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W05-012 — `ps2ip_input` interrupt path permanently loses queue slots on allocation failure

- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/ps2ip.c:189-242` (INTERRUPT_CTX_INPKT path, Makefile default on)
- **Problem:** In the interrupt-context input path, the `u8LastMSG` index is advanced (lines 223-224) before `memp_malloc` is attempted (line 228). On allocation failure the slot is never queued and nothing ever advances `u8FirstMSG` past it, so each failure permanently burns one queue slot and the first/last accounting drifts for the rest of the session. The full/empty checks and index updates are also done with no interrupt suspension. In the same path, InputCB (lines 189-193) reads the ethertype from `pInput->payload` with no minimum-length check and ignores `pbuf_header(pInput, -14)`'s return.
- **Fix:** Allocate first and only advance u8LastMSG on success; check the pbuf_header return and a minimum frame length before reading the ethertype.
- **Benefit:** Transient pool exhaustion costs one dropped packet, not a permanently shrinking input queue.
- **Effort:** S · **Risk:** Low · **Confidence:** High for the sequencing (READ); session-level impact INFERRED

## W05-013 — ps2ips RPC handlers trust EE-supplied length fields (`optlen`, `malign`)

- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/modules/network/ps2ips/ps2ips.c:591-592` (do_setsockopt); `RiptOPL/modules/network/ps2ips/ps2ips.c:402-407,435-440` (do_send/do_sendto)
- **Problem:** do_setsockopt copies `pkt->optlen` bytes from the RPC packet into a 128-byte stack buffer `optval[128]` with no clamp — an optlen above 128 overflows the RPC thread's stack. do_send/do_sendto compute `s_offset = 64 - pkt->malign` and memcpy `pkt->malign` bytes at `lwip_buffer + s_offset`; a malign above 64 makes the offset negative and the copy writes in front of lwip_buffer. Both fields come straight from the request packet. (The EE is the only sender, so exploitability is limited — INFERRED; the missing clamps are READ. This module's own RA-fix history shows packet-field bugs here were real and shipped.)
- **Fix:** Clamp optlen to sizeof(optval) and malign to 64 at the top of the handlers, rejecting larger values.
- **Benefit:** A malformed or version-mismatched EE client cannot corrupt IOP stack memory through the RPC layer.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W05-014 — `common/smstcpip.h` import ordinals disagree with SMSTCPIP's export table

- **Category:** 6 bugs / 8 half-finished features
- **Locations:** `RiptOPL/modules/network/common/smstcpip.h:37-42,127-130`; `RiptOPL/modules/network/SMSTCPIP/exports.tab:36-47`
- **Problem:** Counting both tables (export ordinals verified against the comments in exports.tab itself): `I_pbuf_dechain` is declared as import 41, but export slot 41 is pbuf_take; `I_pbuf_take` is declared as import 42, but slot 42 is etharp_lookup_mac — and only in INGAME_UDP builds; `I_inet_aton` (43) and `I_inet_ntoa` (44) have no export slots at all, since the table ends at 42. Any IOP module that uses these four imports from this header binds the wrong function or a nonexistent slot. (pbuf_dechain does not even exist in the stack — see W05-015.)
- **Fix:** Delete the four wrong import declarations from smstcpip.h. Nothing in the stack provides dechain/aton/ntoa as exports, so there is no correct ordinal to substitute; deletion is the LESS fix.
- **Benefit:** Removes a silent wrong-function binding trap for the next module that includes this header.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; both tables read and counted this session)

## W05-015 — Header declarations with no definition anywhere in the tree

- **Category:** 1 dead code
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/include/lwip/api.h:104-114,155` (netbuf_alloc, netbuf_free, netbuf_chain, netbuf_data, netbuf_next, netconn_err); `include/lwip/pbuf.h:108,114` (pbuf_ref_chain, pbuf_dechain); `include/lwip/sys.h:97` (sys_now); `include/lwip/tcp.h:427,453` (tcp_pcb_copy, tcp_rexmit_seg); `include/lwip/memp.h:59` (memp_realloc)
- **Problem:** Each of these is declared in a header and defined in no .c file in the tree (grep-verified: declaration sites only). netbuf_first is additionally declared at api.h:114 and then defined as a macro at api.h:121. Any future caller links against air.
- **Fix:** Delete the declarations.
- **Benefit:** Headers stop promising an API the stack does not have; the dechain declaration feeding W05-014 disappears at the source.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ + grep-verified)

## W05-016 — mem.c carries a full heap allocator that is dead in every build, plus a callerless `mem_reallocm`

- **Category:** 1 dead code
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/mem.c:123-377,379-390`; `RiptOPL/modules/network/SMSTCPIP/include/lwipopts.h:23`; `RiptOPL/modules/network/SMSTCPIP/include/arch/sys_arch.h:29-37`
- **Problem:** lwipopts.h sets MEM_LIBC_MALLOC 1 unconditionally, so the ~255-line lwIP heap allocator in mem.c (lines 123–377) compiles out of every build; all allocation routes through the mem_clib_* → ps2ip_mem_* wrappers. Separately, `mem_reallocm` (mem.c:379-390) has zero callers in the tree (grep-verified) and is wrong anyway: on the grow path it memcpys `newsize` bytes from the old, smaller block.
- **Fix:** Delete the dead allocator body and mem_reallocm; keep the libc-malloc wrapper functions that are actually used.
- **Benefit:** ~265 lines of never-compiled, subtly wrong allocator code leave the tree; mem.c becomes exactly the shim it is in practice.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ + grep-verified)

## W05-017 — loopif is a complete dead module: file, header, and gated glue all ship but can never run

- **Category:** 1 dead code
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/loopif.c` (whole file, 113 lines); `RiptOPL/modules/network/SMSTCPIP/include/netif/loopif.h` (39 lines); `RiptOPL/modules/network/SMSTCPIP/ps2ip.c:279-294`; `RiptOPL/modules/network/SMSTCPIP/Makefile` (IOP_OBJS has no loopif.o)
- **Problem:** loopif.c is entirely wrapped in `#if LWIP_HAVE_LOOPIF`, which defaults to 0 (opt.h:337) and is set nowhere; the file is also absent from the Makefile object list. ps2ip.c's AddLoopIF/LoopIF glue is gated out by the same macro. The loopback interface can never exist in this tree.
- **Fix:** Delete loopif.c, loopif.h, and the gated AddLoopIF block in ps2ip.c.
- **Benefit:** ~150 lines of impossible code removed; one less phantom interface for readers to reason about.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W05-018 — `do_accept` is a registered no-op that never ACKs

- **Category:** 1 dead code
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/api_msg.c:664-689,813-820`; `RiptOPL/modules/network/SMSTCPIP/include/lwip/api_msg.h:55`; `RiptOPL/modules/network/SMSTCPIP/api_lib.c:383-398`
- **Problem:** do_accept's body only emits debug lines per netconn type and — unlike its neighbours (do_listen ends with TCPIP_APIMSG_ACK) — never ACKs the message. It is registered in the `__decode__` table for API_MSG_ACCEPT, but nothing in the tree ever posts API_MSG_ACCEPT (grep: no occurrence in any .c file); netconn_accept fetches the accept mbox directly and bypasses the message entirely. If anything ever did post it, the caller would wait on an ACK that never comes.
- **Fix:** Delete do_accept, its decode-table entry, and the API_MSG_ACCEPT enum value.
- **Benefit:** Removes a hang-in-waiting from the API message table; the accept path that actually exists stays untouched.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ + grep-verified)

## W05-019 — `recv_udp` leaks the pbuf when the connection has no receive mbox yet

- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/api_msg.c:89-106` (recv_udp), with setup at `api_msg.c` do_newconn (PCB + recv callback installed before any recvmbox exists; recvmbox is created later in netconn_bind/connect)
- **Problem:** recv_udp delivers the incoming pbuf to `conn->recvmbox` only if it is not SYS_MBOX_NULL; in the NULL case the pbuf is neither delivered nor freed — there is no else branch. The callback is installed at netconn creation, before bind/connect creates the recvmbox, so a datagram arriving in that window leaks one pbuf from a small pool each time. (Reachability window INFERRED; the missing free is READ.)
- **Fix:** Add the one-line else branch: `pbuf_free(p)`.
- **Justification (adds one line):** It is the smallest possible change and matches how every other drop path in the file treats an undeliverable pbuf.
- **Benefit:** Early datagrams cost a drop, not a permanent pbuf-pool leak.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ code, INFERRED reachability)

## W05-020 — Socket entry points dereference caller sockaddr pointers unchecked; `lwip_sendto` ignores connect/disconnect errors

- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/sockets.c:231-232` (lwip_bind), `sockets.c:300,307-308` (lwip_connect), `sockets.c:559-575` (lwip_sendto)
- **Problem:** lwip_bind dereferences `name` (family/port/addr) with no NULL, namelen, or family check; lwip_connect does the same. lwip_sendto dereferences `to` the same way and then ignores the return values of all three of its netconn_connect / netconn_disconnect calls (lines 566, 573, 575), so a failed temporary connect for an unconnected UDP socket still proceeds to send and reports the send result as if the connect had worked.
- **Fix:** NULL/length/family-check the sockaddr arguments (EINVAL-style errno, matching the checks getsockopt already does in this file) and propagate netconn_connect's error in lwip_sendto.
- **Benefit:** Bad arguments from any IOP caller return errors instead of dereferencing NULL inside the stack; UDP sendto stops reporting success on a failed connect.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W05-021 — `lwip_recvfrom`: error conflated with EOF, and the SMB header index is trusted

- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/sockets.c:352-402` (signature comment at 352; failure return at 383-390; header copy/index at 401-402); declaration context at `RiptOPL/modules/network/common/smstcpip.h:93-101`
- **Problem:** This tree's exported lwip_recvfrom is not the BSD function: it takes (header, index, payload, plen) for the SMB driver's split header/payload reads. Two local defects: (1) when netconn_recv fails/returns NULL, the function returns 0 with errno left at 0, so a caller cannot distinguish a stack error from an orderly EOF/empty datagram. (2) Line 402 computes `index = ((u8_t*)header)[index] + 4`, reading header[index] with a caller-supplied index that is never checked against the 63 bytes actually copied into the header buffer at line 401 — an out-of-range index reads beyond the copied header (READ code fact; how far a real caller can push it is INFERRED).
- **Fix:** Return −1 with the netconn error mapped through err_to_errno on the failure path, and clamp/validate index against the copied header length before dereferencing it.
- **Benefit:** The SMB receive path — the stack's main in-game workload — reports errors as errors and stops trusting a wire-adjacent index.
- **Effort:** S · **Risk:** Low · **Confidence:** High for (1) (READ), Med for (2) (READ code, INFERRED impact)

## W05-022 — `ps2ip_ShutDown` is exported but does nothing

- **Category:** 8 half-finished features
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/ps2ip.c:273-278`; `RiptOPL/modules/network/SMSTCPIP/exports.tab:4`
- **Problem:** The module's shutdown export simply `return 1;` — no thread termination, no mbox/semaphore cleanup, no netif removal. Anything that unloads or restarts the stack believing this hook works leaks the whole stack state.
- **Fix:** Either implement the teardown or point the export slot at ps2ip_Stub (the slot must stay for ordinal stability) and delete the fake implementation, so the absence is honest.
- **Benefit:** No false contract at the module boundary; ~6 lines and one misleading symbol gone in the LESS variant.
- **Effort:** S (stub variant) · **Risk:** Low · **Confidence:** High (READ)

## W05-023 — Peer MSS of 0 is accepted and yields zero-length segments

- **Category:** 6 bugs/security
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/tcp_in.c:1104-1108` (tcp_parseopt); `RiptOPL/modules/network/SMSTCPIP/tcp_out.c:128-134` (tcp_enqueue)
- **Problem:** tcp_parseopt clamps the peer's MSS option only from above (`mss > TCP_MSS ? TCP_MSS : mss`). An MSS option value of 0 is stored as pcb->mss = 0, after which tcp_enqueue's segment-length computation produces 0-length segments until the TCP segment pool is exhausted and sends fail with ERR_MEM. (Chain INFERRED from the two read sites; no lower clamp exists at the parse site — READ.)
- **Fix:** Clamp the parsed MSS to a sane minimum (e.g. reject/clamp to at least the minimum the stack itself would send) at the parse site.
- **Benefit:** One malformed SYN option from a peer can no longer wedge the connection's send path.
- **Effort:** S · **Risk:** Low · **Confidence:** Low (mechanism READ, end-to-end effect INFERRED)

## W05-024 — Select event machinery runs on every netconn event in builds that have no select

- **Category:** 5 performance (structural) / 1 dead code
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/sockets.c:812-889` (event_callback)
- **Problem:** event_callback walks the select_cb_list and lazily creates the select semaphore on netconn events, but lwip_select exists only under FULL_LWIP (W05-003) and its export slot is stubbed (W05-002), so in every build that actually ships the list is always empty and the semaphore creation is pure overhead on the event path. (Structural observation only; no timing claimed.)
- **Fix:** Gate event_callback's list walk/semaphore creation on the same condition that provides lwip_select, or delete it together with W05-003.
- **Benefit:** The per-event callback becomes a no-op stub in shipped builds instead of list/semaphore bookkeeping for a feature that cannot be called.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ)

## W05-025 — The non-core-locking API path in tcpip.c is unreachable and silently drops calls

- **Category:** 1 dead code / 6 bugs
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/tcpip.c:137-156`; `RiptOPL/modules/network/SMSTCPIP/include/lwip/opt.h:64-65`
- **Problem:** LWIP_TCPIP_CORE_LOCKING defaults to 1 in opt.h and lwipopts.h does not override it, so tcpip_apimsg always takes the synchronous locked branch (lines 140-143). The `#else` branch — post the message to the tcpip thread — is dead in every configured build, and it is also wrong: if memp_malloc(MEMP_TCPIP_MSG) fails there, the API call is silently dropped with conn->err left stale, so a caller would block or read a previous error. (Branch deadness READ from config; drop behaviour READ from the branch body.)
- **Fix:** Delete the non-locking branch of tcpip_apimsg and state the core-locking requirement in lwipopts.h, or fix the drop — deleting is LESS and matches every build this tree produces.
- **Benefit:** One less silently-lossy path for a future config flip to fall into.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ)

## W05-026 — Feature-off protocol code retained: `ip_forward` and debug-only `ip_lookup`

- **Category:** 1 dead code
- **Locations:** `RiptOPL/modules/network/SMSTCPIP/ip.c:79-113` (ip_lookup, `#ifdef LWIP_DEBUG`), `RiptOPL/modules/network/SMSTCPIP/ip.c:139-199` (ip_forward, IP_FORWARD = 0)
- **Problem:** ip_forward (~60 lines) is compiled out by IP_FORWARD 0 in every build and nothing in the tree enables forwarding; ip_lookup exists only under LWIP_DEBUG, which is defined nowhere in the tree. Both are dead in this tree's copies regardless of their upstream status.
- **Fix:** Delete both functions (and the ip_lookup declaration use in ip.h if it becomes unreferenced — ip.h:57 declares ip_lookup unconditionally, so the declaration should go with it or be guarded consistently).
- **Benefit:** ~95 lines of never-compiled routing/debug code removed from the IP layer readers must audit.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

---

## COVERAGE

### Files read (72 of 72 in scope)

**SMSTCPIP — .c/.S/Makefile/tables (21):** Makefile, exports.tab, imports.lst, ps2ip.c, sockets.c, api_lib.c, api_msg.c, tcpip.c, memp.c, mem.c, pbuf.c, ip.c, ip_frag.c, icmp.c, ip_addr.c, timers.c, etharp.c, udp.c, tcp.c, tcp_in.c, tcp_out.c, netif.c, loopif.c, inet.S — read in full. (icmp.c/timers.c/netif.c licence preambles skimmed via `head`; all code read.)

**SMSTCPIP — headers (36):** include/lwipopts.h, include/ps2ip_internal.h, include/irx_imports.h, include/arch/cc.h, include/arch/sys_arch.h, include/lwip/{opt, memp, mem, api, api_msg, tcpip, sys, sockets, tcp, udp, ip, ip_addr, netif, pbuf, stats, snmp, dhcp, err, def, inet, arch, debug, icmp, ip_frag, raw, timers}.h, include/netif/{etharp, loopif}.h — read in full (api.h and sys.h read from line 32; their lines 1–31 are licence/include preambles).

**SMSUTILS (2):** Makefile, SMSUTILS.S — read in full. No findings: a minimal memcpy/memset IRX whose exports are used by the stack; nothing dead or unchecked found at this reading depth for hand assembly.

**ps2ips (4):** Makefile, imports.lst, irx_imports.h, ps2ips.c (752 lines) — read in full.

**common (9):** smstcpip.h, smstcpip-common.h, httpclient.h, httpstream.inc, ra_client.h, ra_snap.h, ra_watch.h, rapops_cfg.h, smap_tx.h — read in full. httpstream.inc and the ra_*.h headers are carefully written (bounds-checked parsers, validated watch lists); no findings filed from them. smstcpip-common.h duplicates lwIP type definitions for the IRX ABI boundary by design; its only divergence found (missing TCP_ACKNODELAY/TCP_EVENSEG constants vs tcp.h) is noted here rather than filed, as those options remain settable via the stack's own headers.

### Files NOT read

None. All 72 in-scope files were opened and read.

### Verification commands run (selection)

- `git rev-parse HEAD` → `2e347d5ac885cd0ff73e9ad4143781946396f492` ✓
- Host compile of the exact err_to_errno macro (in /tmp): err −1…−11 all → EIO (W05-001)
- `find modules/network -name dhcp.c -o -name raw.c` → 0 files (W05-003, W05-005)
- `grep -rn "define LWIP_ARP|DLWIP_ARP" SMSTCPIP/` → 0 hits (W05-004)
- `grep -rc FULL_LWIP` per file + gate line numbers (W05-003)
- `grep` for API_MSG_ACCEPT, memp_realloc, mem_reallocm, netbuf_alloc/data/err, pbuf_ref_chain/dechain, sys_now, tcp_pcb_copy, tcp_rexmit_seg, etharp_init callers → declarations/no-callers only (W05-015, W05-016, W05-018, W05-004)
