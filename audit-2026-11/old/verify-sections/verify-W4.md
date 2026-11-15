# Verification W4 — RiptOPL Category 6, ROUND9-MODULES (IOP modules/)

- **Clone:** `~/workspace/audit-clones-2026-11-13/RiptOPL`, pin verified at start and end: `2e347d5ac885cd0ff73e9ad4143781946396f492`, `git status` clean (read-only, nothing edited).
- **Source of findings:** `Sable-RiptOPL-ROUND9-MODULES.md`
- **Scope:** RIPTOPL-413, -414, -415, -416, -417, -418, -419, -420, -421, -422, -423, -424, -425, -428, -429 (15 findings)
- **Counts:** VERIFIED 7 · VERIFIED-DRIFT 4 · WEAKENED 4 · REFUTED 0

| ID | Verdict | One-line evidence (path:line) |
|---|---|---|
| RIPTOPL-413 | WEAKENED | Division traps hold at `modules/vmc/genvmc/genvmc.c:248-250,258`, but the `pagesize > 512` overflow claim does not follow for the first loop (see subsection) |
| RIPTOPL-414 | VERIFIED | Only length check is `>= sizeof(struct NbHeader)` (12) at `modules/network/nbns/nbns.c:179`; address copied from offset 54 at `nbns.c:198` |
| RIPTOPL-415 | WEAKENED | String half defeated by the sole EE producer, which terminates all four fields at `src/platform/httpclient.cpp:45-46,66-69,78-79`; `mtime[1]` OOB half stands at `modules/network/httpclient/httpclient.c:371` |
| RIPTOPL-416 | VERIFIED | `if (mount_info_index > FATFS_FS_DRIVER_MOUNT_INFO_MAX)` at `modules/bdm/bdmfs_fatfs/src/fs_driver.c:140`; array is `fs_driver_mount_info[FF_VOLUMES]` with `FF_VOLUMES 10` (`fs_driver.c:32`, `fatfs/include/ffconf.h:181`), so index 10 and negatives pass |
| RIPTOPL-417 | VERIFIED-DRIFT | Leak/drop/stale-size mechanism holds at `modules/ilink/iLinkman/src/iLink_crom.c:249-262`; corrected lines in subsection (assault `_start` caller, `BuildConfigurationROM` free) |
| RIPTOPL-418 | VERIFIED-DRIFT | Guard `if (UnitInList < nNodes)` with signed `int UnitInList` at `modules/ilink/iLinkman/src/iLink_crom.c:201,204`, both copies; `NodeData[63]` is at `iLink_intr.c:29`, not `:30` |
| RIPTOPL-419 | VERIFIED | Unchecked writes `dev9_intr_cbs[intr]` / `dev9_predma_cbs[ctrl]` / `dev9_postdma_cbs[ctrl]` at `modules/iopcore/cdvdman/dev9.c:173,179,185` (tables of 16/4/4 at `dev9.c:63,67`); power-off check `idx < 16` only at `dev9.c:412` |
| RIPTOPL-420 | VERIFIED | `_request`/`_send_recv` return the received byte count with no minimum-length check at `modules/network/udpfs_shared/src/udpfs_core.c:48-80`; callers check only `ret < 0` (open `:338-348`, lseek `:484-497`, getstat `:587-607`, `_path_op` `:148-153`); `udprdma_recv` returns `rx_received` on FIN at `udprdma.c:674-679` |
| RIPTOPL-421 | WEAKENED | Signed truncation holds at `modules/network/udpfs_shared/src/udpfs_core.c:738,783-788`, but the affected size bands in the finding are wrong and the cited consumer lines have drifted (see subsection) |
| RIPTOPL-422 | VERIFIED | Empty slot (`port_src == 0`, `handler == NULL`) matches a port-0 datagram at `modules/network/udpfs_ministack/src/ministack_udp.c:61-64` and `modules/network/smap_udpbd/src/ministack.c:220-223`; no earlier port filter in either RX path |
| RIPTOPL-423 | VERIFIED-DRIFT | Unchecked `udp_new()`/`tcp_new()` use in `do_bind` at `modules/network/SMSTCPIP/api_msg.c:420-437` vs. checked siblings at `:305-341,504-541`; `MEMP_NUM_UDP_PCB 1` is at `lwipopts.h:65`, not `:82` |
| RIPTOPL-424 | VERIFIED-DRIFT | Loop `for (; len; p = p->next)` with no NULL stop at `modules/network/SMSTCPIP/ip_frag.c:70-75`, called at `ip_frag.c:170`; `pbuf_realloc` cannot grow (`pbuf.c:403-413`, not `:320-375`) and its call is at `ip.c:241`, not `:219` |
| RIPTOPL-425 | WEAKENED | Unchecked `pbuf_alloc` deref holds for `icmp_dest_unreach` at `modules/network/SMSTCPIP/icmp.c:138-147`, but `icmp_time_exceeded` is compiled out (`#if IP_FORWARD`, `icmp.c:163`; `IP_FORWARD 0` at `lwipopts.h:230`) |
| RIPTOPL-428 | VERIFIED | Unbounded SDATAIN spins at `modules/iopcore/cdvdman/cdvdman.c:939-941,954-956,970-974` under `cdvdman_scmdsema` (taken `:931`, released `:976`); `cdvdman_sendSCmd` retries then `return 1` unconditionally at `cdvdman.c:982-997` |
| RIPTOPL-429 | VERIFIED | Allocation failure returns `0` at `modules/bdm/src/part_driver_gpt.c:38-42`; `bdm_try_mount` treats `0` as mounted and stops at `modules/bdm/src/bdm.c:184-189`; MBR twin returns `-1` (`part_driver_mbr.c:38,53-56`) and GPT's own other paths return `-1` (`part_driver_gpt.c:53,61,73,184`) |

---

## RIPTOPL-413 — WEAKENED

The division-by-zero core is exactly as cited and verified:

- `modules/vmc/genvmc/genvmc.c:248` — `pagesblock = (BLOCKKB * 1024) / mcdi->pagesize` with `pagesize` an `s16` superblock field (`genvmc.c:93`) copied from the card at `:244` after only the 28-byte magic check at `:245`. `pagesize == 0` traps.
- `genvmc.c:249` — `clustersblock = pagesblock / mcdi->pages_per_cluster`; `pages_per_cluster == 0` traps, and `clustersblock == 0` whenever `pagesblock < pages_per_cluster`.
- `genvmc.c:250,258` — `blocks = clusters_per_card / clustersblock` traps on `clustersblock == 0`; `*progress = i / (blocks / 99)` traps when `1 <= blocks <= 98` (the loop at `:257` runs, and `blocks / 99 == 0`).

The overflow sub-claim does **not** follow as stated. The finding says "`pagesize > 512` walks `cluster_buf` (16 KiB + 16) past its end." For the first loop (`genvmc.c:259-260`), `pagesblock = 16384 / pagesize` (integer division), so the highest written offset plus one page is `pagesblock * pagesize <= 16384` — inside `cluster_buf[(16 * 1024) + 16]` (`genvmc.c:125`) for any positive `pagesize`. E.g. `pagesize = 1024` gives offsets up to 15360 and a last page ending exactly at 16384. An overflow requires the **second** loop (`genvmc.c:274-276`), where the bound is `pages_per_cluster` rather than `pagesblock`: there the end offset is `pages_per_cluster * pagesize`, which exceeds the buffer only when `pages_per_cluster * pagesize > 16400` (e.g. `pagesize = 16384, pages_per_cluster = 2`), not for any `pagesize > 512`. Also narrowed: the progress division needs `blocks >= 1`; `blocks == 0` skips the loop entirely and does not trap.

**Precise surviving claim:** unchecked card-supplied geometry causes IOP division traps (`pagesize == 0`, `pages_per_cluster == 0`, `clustersblock == 0`, or `1 <= blocks <= 98`), and a `cluster_buf` overrun only in the tail loop when `pages_per_cluster * pagesize > 16400`.

## RIPTOPL-415 — WEAKENED

The mechanism is split; one half is defeated by the caller, the other is not.

**String half — defeated for the only producer in the tree.** The IOP handlers at `modules/network/httpclient/main.c:36` and `:44-60` indeed do not terminate `server`/`UserAgent`/`host`/`uri`, unlike the stream-begin handler at `main.c:74-75`. But the sole EE-side producer of these RPC structs terminates every field before the call: `src/platform/httpclient.cpp:45-46` (`server[HTTP_CLIENT_SERVER_NAME_MAX - 1] = '\0'`), `:66-69` (`UserAgent`, `host`), and `:78-79` (`uri`). No other in-tree code fills `HttpClientConnEstabArgs`/`HttpClientSendGetArgs`. With those maxima (uri 127, UserAgent 15, host 29 — `modules/network/common/httpclient.h:31-33,107-129`) the worst-case request built at `modules/network/httpclient/httpclient.c:362-372` is ~314 bytes, inside `char buffer[512]`. So the claimed stack overflow requires an EE program other than the one in this tree sending a hand-crafted RPC — not the "EE-supplied" path as it exists here.

**mtime half — stands.** Nothing in the chain validates the month byte: the EE wrapper copies `mtime[6]` verbatim (`src/platform/httpclient.cpp:71-73`), and the IOP sink indexes the 12-entry `months[]` with it unchecked at `modules/network/httpclient/httpclient.c:371` (`months[mtime[1]]`). `GetDayInWeek` (`httpclient.c:331`) also loops `month < mtime[1]` reading the 12-entry `daysInMonth[month]`, so any `mtime[1] > 11` is an out-of-bounds read there too.

**Precise surviving claim:** only the `mtime[1]` out-of-bounds indexing (httpclient.c:331,371) survives; the unterminated-string / `buffer[512]` overflow does not occur via the in-tree EE client.

## RIPTOPL-417 — VERIFIED-DRIFT

Mechanism re-derived and confirmed in both copies:

- `InitializeConfigurationROM` nulls every `ExtraCROMUnits[i]` without `free` and nulls `ConfigurationROM` without resetting `ConfigurationROMSize`: `modules/ilink/iLinkman/src/iLink_crom.c:253-256`, identical in the assault copy at the same lines. The units were `malloc`'d in `iLinkAddCROMUnit` (`iLink_crom.c:65-90`, both copies).
- It is called from `_start` and from the exported `iLinkSetNodeCapabilities`: main copy `modules/ilink/iLinkman/src/iLink.c:110,270`; assault copy `modules/bdmassault/ilink_bd_assault/src/iLinkman/src/iLink.c:274` — **drift: the assault `_start` call is at `:111`, not `:110` as cited.**
- `BuildConfigurationROM` returns early on `malloc` failure (`iLink_crom.c:295-296`, both copies), leaving `ConfigurationROM == NULL` with the old `ConfigurationROMSize`; the read handler then passes its size test and forms `NULL + offset` at `modules/ilink/iLinkman/src/iLink_intr.c:325-327` (assault twin at the same lines; `REQ_CHECK_MEM_BOUNDARIES` is defined in both `iLink_internal.h:15` copies, and the size test itself is outside the `#ifdef`).
- **Drift:** the replace-and-free in `BuildConfigurationROM` that the nulling defeats is at `iLink_crom.c:392-394` in the main copy (assault: `:395-397`), not `:388-391` as cited (those lines are the Bus Information Block header writes).

## RIPTOPL-418 — VERIFIED-DRIFT

Mechanism confirmed in both copies: `iLinkFindUnit(int UnitInList, …)` guards only with `if (UnitInList < nNodes)` and immediately reads `NodeData[UnitInList]` — `modules/ilink/iLinkman/src/iLink_crom.c:193,201,204`, textually identical in `modules/bdmassault/ilink_bd_assault/src/iLinkman/src/iLink_crom.c:193,201,204`. Any negative `UnitInList` satisfies the guard (signed `int` vs. signed `int nNodes`). It is export 23 in both `exports.tab`s (`DECLARE_EXPORT(iLinkFindUnit) /* 023 */`). The only in-tree callers pass loop indices (`modules/ilink/IEEE1394_bd/src/sbp2_driver.c:464`, assault twin `:438`), as the finding states.

**Drift:** the array declaration `unsigned int *TargetBuffer, NodeData[63];` is at `modules/ilink/iLinkman/src/iLink_intr.c:29` (assault twin also `:29`), not `:30` as cited.

## RIPTOPL-421 — WEAKENED

The truncation itself is exactly as cited: `int udpfs_core_get_sector_count(...)` at `modules/network/udpfs_shared/src/udpfs_core.c:738` computes `uint32_t sector_count = (uint32_t)(total_bytes >> 9)` at `:783-784` and returns it as a signed `int` at `:788`; the consumer treats any negative return as an error and retries (`modules/network/udpfs_bd/src/udpfs_bd.c:116-118`) and otherwise stores it (`udpfs_bd.c:126`).

But the finding's size bands are wrong, and its headline ("shares ≥ 1 TiB can never register") is false for half the range. Doing the arithmetic (512-byte sectors, so 1 TiB = 2³¹ sectors):

| Share size | `sector_count` (u32) | Returned `int` | Outcome |
|---|---|---|---|
| [1 TiB, 2 TiB) | [2³¹, 2³²) | negative | never registers — as claimed |
| exactly 2 TiB | 0 | 0 | passes the `ret < 0` check; registers a **0-sector** device |
| (2 TiB, 3 TiB) | (0, 2³¹) after wrap | small positive | registers with a wrong, too-small capacity |
| [3 TiB, 4 TiB) | [2³¹, 2³²) after wrap | negative | never registers |
| exactly 4 TiB | 0 | 0 | registers a 0-sector device |

So the "never registers" outcome holds only in the [odd, even) TiB bands ([1,2), [3,4), …); in the [even, odd) bands the device **does** register, silently undersized (or zero-sized at exact even-TiB multiples). The finding also misplaces the wrap band: it puts the small-positive wrap "between 2 TiB and 4 TiB", when in fact [3 TiB, 4 TiB) is negative and the small-positive band is (2 TiB, 3 TiB) (repeating every 2 TiB).

**Drift:** the consumer is not at `udpfs_bd.c:163-173` (those lines are the watchdog/init); `udpfs_bd_try_connect` is at `udpfs_bd.c:107-140`, with the error check at `:116-118` and the store at `:126`.

## RIPTOPL-423 — VERIFIED-DRIFT

Mechanism confirmed: `do_bind` lazily allocates with no NULL check — `udp_new()` then `udp_setflags()`/`udp_recv()` at `modules/network/SMSTCPIP/api_msg.c:420-422,425-427,430-431`, and `tcp_new()` then `setup_tcp(msg->conn)` at `:436-437` (`setup_tcp` dereferences `conn->pcb.tcp` at `api_msg.c:219-224`); the bind switch then dereferences the PCB again at `:455,460-461`. The sibling asymmetry is real for UDP/TCP: `do_newconn` checks at `:305-341` and `do_connect` at `:504-541`. `netconn_bind` posts the message without consulting `conn->err` (`api_lib.c:283-309`). One correction to the finding's contrast, which does not affect the verdict: the RAW cases are unchecked in **all three** handlers (`do_newconn` `:299-300`, `do_bind` `:414-415`, `do_connect` `:498-499`), so "checks every allocation" is true only of the UDP/TCP cases.

**Drift:** `MEMP_NUM_UDP_PCB 1` is at `modules/network/SMSTCPIP/include/lwipopts.h:65`, not `:82` as cited; `netconn_bind` starts at `api_lib.c:283`, not `:280`.

## RIPTOPL-424 — VERIFIED-DRIFT

Mechanism confirmed: `copy_from_pbuf` loops `for (; len; p = p->next)` dereferencing `p->len`/`p->payload` with no `p == NULL` stop (`modules/network/SMSTCPIP/ip_frag.c:61-81`, loop at `:70-75`), and `ip_reass` passes `len = ntohs(IPH_LEN(fraghdr)) - IPH_HL(fraghdr) * 4` at `ip_frag.c:153,170`. The only pre-check (`ip_frag.c:158`) bounds `offset + len` against the reassembly buffer, not against the delivered pbuf chain. `IP_REASSEMBLY` is 1 in both configurations (`lwipopts.h:252,256`).

**Drift (three citations):**
- `pbuf_realloc` is at `modules/network/SMSTCPIP/pbuf.c:403-451`, not `:320-375` (that range is inside `pbuf_alloc`). The load-bearing behaviour is at `pbuf.c:410-413`: `if (new_len >= p->tot_len) return;` — it cannot extend the chain, as claimed.
- The `pbuf_realloc(p, ntohs(IPH_LEN(iphdr)))` call in `ip_input` is at `modules/network/SMSTCPIP/ip.c:241`, not `:219` (`:219` is merely inside the same function).
- The `IP_REASSEMBLY` definitions are at `lwipopts.h:252` (in-game) and `:256` (otherwise), not the cited `:212-230` range (which is the ARP/IP-options block).

## RIPTOPL-425 — WEAKENED

Half the finding is live, half is dead code.

- **`icmp_dest_unreach` — stands.** `q = pbuf_alloc(PBUF_IP, 8 + IP_HLEN + 8, PBUF_RAM)` at `modules/network/SMSTCPIP/icmp.c:138` is dereferenced at `:143` (`idur = q->payload`, then `ICMPH_TYPE_SET`) with no NULL check, and `mips_memcpy(..., IP_HLEN + 8)` from `p->payload` follows at `:147`. It has live callers: `ip.c:319` and `udp.c:380`. In-game `PBUF_POOL_SIZE` is 8 (`lwipopts.h:138`, under `INGAME_DRIVER`; 25 otherwise at `:140`).
- **`icmp_time_exceeded` — not compiled.** The function at `icmp.c:164-197` sits inside `#if IP_FORWARD` (`icmp.c:163`), and `IP_FORWARD` is unconditionally `0` at `lwipopts.h:230` (no other definition in the tree; `opt.h:222` also defaults it to 0). Its only caller is likewise inside `#if IP_FORWARD` at `ip.c:139-199`. So the `:170-175` unchecked allocation exists only in source text, in no build from this `lwipopts.h`.

**Precise surviving claim:** the unchecked-`pbuf_alloc` NULL dereference (and unchecked `IP_HLEN + 8` copy) in `icmp_dest_unreach` only; the `icmp_time_exceeded` half is unreachable in every configuration this tree builds.

---

## New defect candidates

None. Re-reading the cited code and its immediate callers turned up no genuinely new defect outside the scope of the 15 findings. (Two observations that belong to existing findings rather than new ones: the RAW-PCB allocations are unchecked in all three SMSTCPIP handlers — noted under RIPTOPL-423 — and `udpfs_core_get_sector_count`'s short-reply exposure under RIPTOPL-420 runs through an uninitialised stack `reply` at `udpfs_core.c:741` rather than the shared `g_rx_buf`, since that function does not use `_request`.)
