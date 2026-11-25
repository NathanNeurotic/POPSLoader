# Verification — RE-RIPTOPL-034 through RE-RIPTOPL-066

- Subject: `~/workspace/Sable-audit-redo/Redo-RiptOPL.md`
- Clone: `~/workspace/audit-clones-2026-11-13/RiptOPL`, HEAD verified `2e347d5ac885cd0ff73e9ad4143781946396f492` before and after; `git status --porcelain` empty (clone untouched).
- Method: refute-first. Every cited file/line opened; mechanism re-derived; guards, callers, and sibling code searched.

## Verdict table

| ID | Verdict | One-line evidence (file:line) |
|---|---|---|
| RE-RIPTOPL-034 | VERIFIED | `modules/network/SMSTCPIP/sockets.c:231-232,300,307-308` deref `name` unchecked; `:566,573,575` ignore `netconn_connect`/`disconnect` returns; contrast checked `lwip_getsockopt` NULL guard in same file |
| RE-RIPTOPL-035 | WEAKENED | Failure path real (`sockets.c:387-390` returns 0, errno 0), but index half narrowed — see reasoning |
| RE-RIPTOPL-036 | VERIFIED | `modules/network/nbns/nbns.c:179` only checks `length >= 12`; `:198` copies address from fixed offset byte 58 (12+34+4+4+2+2) of the 576-byte static frame |
| RE-RIPTOPL-037 | WEAKENED | Part (b) real (`smb_fio.c:660-663`, `:361`), part (a) refuted — see reasoning |
| RE-RIPTOPL-038 | VERIFIED | `modules/iopcore/cdvdman/searchfile.c:217-218` `strlen(cdvdman_filepath) - 6` underflows for paths < 6 chars; buffer is the 256-byte static at `:175` filled from the game's search name at `:191` |
| RE-RIPTOPL-039 | VERIFIED | `modules/iopcore/cdvdman/smb.c:447-459` `setStringField`/`asciiToUtf16` unbounded; call sites `:604-623,695,783` accumulate into the 1024-byte `SMB_buf` (`smb.h:512-513`, `smb.c:77`); inputs are fixed fields (Username[36], PrimaryDomain[32] in `modules/iopcore/common/oplsmb.h:9,15`) so "fits today, unenforced" is accurate as scoped |
| RE-RIPTOPL-040 | VERIFIED | `modules/debug/ps2link/net_fio.c:402` `nbytes = ntohl(readrly->nbytes)`; `:408` receives `nbytes` into caller's `buf` with no comparison to requested `length` (only `length < 0` checked) |
| RE-RIPTOPL-041 | VERIFIED | `modules/bdm/bdmfs_fatfs/src/fs_driver.c:940-943` `fs_ioctl` fabricates `datalen=1024`; `fs_ioctl2` at `:861-866` requires `datalen == sizeof(vmc_alloc_request_t)` for VMC commands, so they can never succeed via `fs_ioctl` |
| RE-RIPTOPL-042 | VERIFIED | `modules/mmce/mmceman/src/mmce_fs.c:1103,1116,1153,1158` `args = *(u32*)arg` unchecked; contrast `:1137-1142` SET_CARD_CHANNEL validates `arg == NULL \|\| arglen < 5` |
| RE-RIPTOPL-043 | VERIFIED | `modules/hdd/apa/src/hdd_fio.c:510-512` `apaCacheFree(clink)` then `apaPassCmp(clink->header->fpwd…)`; `modules/hdd/apa/src/apa.c:508-518` frees then reads `clink->header->next`/`clink->device`; `apaCacheFree` relinks at `nused==0` (`modules/hdd/apa/src/cache.c:179-196`) |
| RE-RIPTOPL-044 | VERIFIED | `modules/usb/usbmass_bd/src/scsi.c:262` and `:281` store `last_lba` directly as `sectorCount` (struct field is named `last_lba` in-tree); READ CAPACITY returns the last addressable LBA, so count = value + 1 |
| RE-RIPTOPL-045 | VERIFIED | `src/ui/guinotify.cpp:108-115` `col_pos = strchr(gOPLPart, ':'); col_pos++;` unchecked; sibling branches at `:120,128,136` all NULL-check |
| RE-RIPTOPL-046 | VERIFIED | `src/platform/ioprp.cpp:8` `char fileName[10]`; `:43-58` `strcmp`/`strcpy` on the fixed-width ROMDIR field (note: the 1-byte `strcpy` spill lands in `extinfo_size`, reassigned on the next line — the over-read is the live half) |
| RE-RIPTOPL-047 | VERIFIED | `src/app/settingsio.cpp:1931,1936,1950,1952,1954,1956` six unchecked `sscanf("%d.%d.%d.%d")` (exact lines match); contrast `configReadRA` in same file requiring `== 4` plus 0–255 range checks |
| RE-RIPTOPL-048 | VERIFIED | `src/core/lang.cpp:550-556` `languages[langID - 1]` with no range check; finding honestly scopes caller reachability as unestablished (sole in-tree caller passes `lngGetGuiValue()`) |
| RE-RIPTOPL-049 | VERIFIED | `modules/network/SMSTCPIP/icmp.c:138-147` `q = pbuf_alloc(...)` written through with no NULL check; callers `ip.c:319`, `udp.c:380` exact |
| RE-RIPTOPL-050 | VERIFIED | `modules/network/SMSTCPIP/ps2ip.c:224` advances `u8LastMSG` before `memp_malloc` at `:228`; failure frees the pbuf and returns with the slot never queued; `InputCB` at `:189-193` reads ethertype with no length check and ignores `pbuf_header` result; Makefile default `INTERRUPT_CTX_INPKT ?= 1` |
| RE-RIPTOPL-051 | VERIFIED | Counted both tables: `modules/network/common/smstcpip.h` declares dechain=41/take=42/aton=43/ntoa=44; `modules/network/SMSTCPIP/exports.tab` slot 41 is `pbuf_take`, 42 is `etharp_lookup_mac` (INGAME_UDP only), table ends at 42 — all four header imports are wrong or nonexistent |
| RE-RIPTOPL-052 | WEAKENED | Missing `pbuf_free` else-branch real (`api_msg.c:89-106`), but the claimed arrival window is not established — see reasoning |
| RE-RIPTOPL-053 | VERIFIED | `modules/network/SMSTCPIP/tcp_in.c:1107-1108` clamps MSS only from above, 0 stored; `tcp_out.c:128-134` then computes `seglen = 0` and loops allocating segments until `TCP_SND_QUEUELEN`/pool exhaustion → `memerr` |
| RE-RIPTOPL-054 | VERIFIED | `modules/network/httpclient/httpclient.c:225` `memcpy(buffer, ptr, DataAvailable)` (≤256, `HTTP_WORK_BUFFER_SIZE` at `:128`) ignores caller's `*length`; sole caller passes the 512-byte `DmaBuffer` with `out_len` pre-clamped (`modules/network/httpclient/main.c:45-50`) — latent exactly as claimed |
| RE-RIPTOPL-055 | WEAKENED | Uninitialised/stale `from` read in the pinned branch is real (`raudp.c:897-899`), but it cannot steer the trust decision as claimed — see reasoning |
| RE-RIPTOPL-056 | REFUTED | Sole caller frees every persistent block on setup failure (`rapull.c:337-347`) — see reasoning |
| RE-RIPTOPL-057 | VERIFIED | `modules/iopcore/cdvdman/device-bdm.c:279,302` `g_bd->read/write` unconditional in the MCEMU exports; contrast `DeviceReadSectors` NULL check at `:229-230` |
| RE-RIPTOPL-058 | VERIFIED | `modules/iopcore/cdvdman/device-hdd.c:70-73` unbounded `while ((r = sceAtaDmaTransfer(...)) != 0) DelayThread(2000);` in `DeviceInit` |
| RE-RIPTOPL-059 | VERIFIED | `modules/iopcore/cdvdman/hdpro_atad.c:714-719` comment admits "retry indefinitely", `continue` advances neither LBA nor a retry counter while holding `ata_io_sema`; non-HDPro `atad.c:700` caps the equivalent loop at 3 retries |
| RE-RIPTOPL-060 | VERIFIED | `modules/debug/ps2link/net_fio.c:88-100` `pko_recv_bytes` treats only `len < 0` as error; `recv()` returning 0 leaves `left` unchanged forever |
| RE-RIPTOPL-061 | VERIFIED | `modules/debug/ps2link/excepHandler.c:55-70` lookup returns 0 on no match; `:80` `strlen(module_name)` on NULL; `:86` copies `BUFFER_SIZE` bytes starting one word into a `BUFFER_SIZE`-byte buffer (`:12-14`); `:92` name copy bounded only by name length |
| RE-RIPTOPL-062 | VERIFIED | `modules/debug/udptty-ingame/udptty.c:225-236` `udp_send` discards `lwip_sendto` result and returns 0; `:259-268` `tty_write` returns that 0 for every write |
| RE-RIPTOPL-063 | VERIFIED | `modules/bdm/src/part_driver_gpt.c:38-42` returns `0` on `AllocSysMemory` failure; `modules/bdm/src/bdm.c:184` treats `connect_bd(...) == 0` as mounted, so FatFs is never tried; other failure paths in the same function return `-1` |
| RE-RIPTOPL-064 | VERIFIED | `modules/bdm/bdmfs_fatfs/src/fs_driver.c:879-891` GET_LBA derefs `bd->sectorOffset` with no NULL check; neighbouring GET_DEVICE_NUMBER checks `bd == NULL → -ENXIO`, GET_DRIVERNAME already fixed the same way |
| RE-RIPTOPL-065 | VERIFIED | `modules/bdm/bdmfs_fatfs/src/fs_driver.c:137-146` guard is `index > MAX` where MAX = array count = `FF_VOLUMES` = 10 (`fatfs/include/ffconf.h:181`; array declared `:32`, macro `:34`), so index 10 and all negatives index the array out of bounds |
| RE-RIPTOPL-066 | VERIFIED | `modules/bdm/src/bdm.c:119-141` `bdm_disconnect_fs` only NULLs `g_mount[i].fs`, never calls `fs->disconnect_bd`; contrast `bdm_disconnect_bd` at `:83` which does; no in-tree caller exercises it today, as the finding itself states |

## Reasoning for non-VERIFIED verdicts

### RE-RIPTOPL-035 — WEAKENED
Part (1) holds exactly: `sockets.c:387-390` — on `netconn_recv` returning NULL the function does `sock_set_errno(sock, 0); return 0;`. The in-tree caller makes the conflation live: `smb_RecvTimed` (`modules/iopcore/cdvdman/smb.c:288-292`) treats `result == 0` as orderly EOF and disconnects, so a stack error is indistinguishable from EOF there.
Part (2) is narrower than claimed. The only in-tree split-header caller passes a compile-time constant index of 49 (`smb.c:953`, `smb_RecvTimed(main_socket, &SMB_buf, 49, readbuf, nbytes)`), well inside the 63 bytes copied at `sockets.c:401`, and the header buffer is the 1024-byte `SMB_buf`, not a 63-byte allocation — so the read at `sockets.c:402` cannot be pushed out of range by any in-tree caller or by wire data (the index is a caller argument, not a packet field). The current code also already guards downstream use: `sockets.c:410-415` treats `avail_len < 63 || index > avail_len` by delivering the segment whole into the header. What survives is a latent API-contract defect (an arbitrary future caller passing `index >= 63` would read un-copied bytes of its own header buffer), not the wire-adjacent trust problem the headline implies. Fix direction (validate index before dereferencing it) remains sane.

### RE-RIPTOPL-037 — WEAKENED
Part (b) holds: `smb_dopen` (`smb_fio.c:660-663`) does `strncpy(fh->name, path, 255)` into the 256-byte field (`:69,78`), then `strlen(fh->name)` and two `strcat`s — a prepared path of ≥255 chars (prepared paths can run to `SMB_PATH_MAX` 1024, `:85`) leaves the field unterminated and the appends read/write past it. `smb_open` at `:361` has the same unterminated pattern with `strncpy(..., SMB_NAME_MAX)` = 256 into a 256-byte field.
Part (a) is refuted. At `smb_fio.c:312-313`, `p2 = &path[strlen(path)]` points at the NUL terminator; the loop condition `(*p2 == '\\' || *p2 == '/')` is false on the first test for **every** input — empty, all-slash, or normal — so `p2` never decrements at all and can never step in front of the buffer. The loop is dead, not dangerous (see Candidate 3 for the functional consequence). The finding's stated mechanism for (a) ("steps in front of the buffer before the loop condition saves it") inverts the actual evaluation order: the condition is tested before any decrement.

### RE-RIPTOPL-052 — WEAKENED
The code defect is real: `recv_udp` (`api_msg.c:89-106`) delivers only when `conn->recvmbox != SYS_MBOX_NULL` and has no else branch, so in that state the pbuf is neither delivered nor freed (contrast the `conn == NULL` and netbuf-alloc-failure paths in the same function, which do free).
The claimed arrival window, however, is not established. Every netconn entry point that can make a UDP PCB receivable creates the recvmbox **before** the PCB can match a packet: `netconn_bind` (`api_lib.c:293-294`), `netconn_connect` (`api_lib.c:322-323`), and `netconn_recv` (`api_lib.c:412`) all create it when NULL, and binding/connecting is what gives the PCB a local port/address for `udp_input` to match. Between `do_newconn` installing `recv_udp` (`api_msg.c:283+`) and any bind/connect, the PCB's local port is 0 and no ordinary datagram is delivered to it. The finding labels the window INFERRED; on re-derivation no concrete in-tree sequence reaches the NULL-mbox state with a deliverable datagram. The one-line fix is still correct hardening, but as a live leak the claim is unproven.

### RE-RIPTOPL-055 — WEAKENED
The uninitialised-data read is real: in `ra_discover` (`modules/network/raudp/raudp.c:793+`), `from` is an uninitialised stack `sockaddr_in`; after the caduceus block, the pinned check at `:897-899` reads `from.sin_addr.s_addr` without first requiring `got > 0`, and this stack's `lwip_recvfrom` does not write `from` on its error/EWOULDBLOCK paths — so on a timeout the comparison runs on stale (previous iteration) or uninitialised bytes.
The security consequence is overstated. That comparison can only `continue` (skip); acceptance of a peer additionally requires `got >= 8`, the `"RAO1 OK "` prefix, a non-broadcast IP, and a successful ARP MAC resolution (`:902-915`), and the caduceus branch proper does check `got > 0` before using `from` (`:884-894`). A garbage `from` therefore causes at most a spurious skip of one poll iteration — it cannot cause a wrong server to be pinned or trusted. True scope: an uninitialised/stale read feeding a skip-only gate, worth the one-line `got > 0` guard, not a trust-decision bypass.

### RE-RIPTOPL-056 — REFUTED
The finding claims `rp_setup()`'s allocations leak "for the life of the module" when a later allocation fails because earlier blocks "are not freed before the failure propagates". The defeating evidence is the sole caller. `rp_setup` (`modules/network/rapull/rapull.c:130`) is called from exactly one site, `rp_thread` at `:337`, and that caller frees every persistent block on any setup failure:

```c
if (!rp_setup()) {
    if (rp_win)       FreeSysMemory(rp_win);
    if (rp_entry_off) FreeSysMemory(rp_entry_off);
    if (rp_node_val)  FreeSysMemory(rp_node_val);
    if (rp_stage)     FreeSysMemory(rp_stage);
    FreeSysMemory((void *)rp_list);
    ExitDeleteThread();
    return;
}
```

(`rapull.c:337-347`.) Inside `rp_setup` itself, the scratch `bits` block is freed on both the partial-allocation path (`:141-145`, which frees `bits` before returning 0 — contrary to the finding's "not freed" framing for that block) and the normal path (`:195`). The `rp_stage` failure at `:199-201` likewise returns 0 into the same caller cleanup. No allocation survives a failed setup; there is no lifetime leak. The prescribed fix (free-on-failure inside `rp_setup`) would duplicate cleanup the caller already performs.

## Candidates (new defects noticed while verifying — not merged into verdicts)

1. **Sibling unchecked `pbuf_alloc` in `icmp_time_exceeded`** — `modules/network/SMSTCPIP/icmp.c:170` repeats RE-RIPTOPL-049's pattern verbatim (`q = pbuf_alloc(...)` then writes through `q->payload` with no NULL check). It is gated by `#if IP_FORWARD`, which is off in this build, so it is currently dead — but it is a second copy of the same defect if forwarding is ever enabled.
2. **`recv_raw` shares `recv_udp`'s missing-free shape** — `modules/network/SMSTCPIP/api_msg.c` `recv_raw` (starting ~`:45`) likewise posts only when `conn->recvmbox != SYS_MBOX_NULL` with no else-`pbuf_free`. Same reachability caveat as RE-RIPTOPL-052 applies.
3. **`prepare_path`'s trailing-slash strip is dead code (functional, not memory-safety)** — `modules/network/smbman-ra/smb_fio.c:312-314`: because `p2` starts on the NUL terminator, trailing slashes/backslashes are never stripped, and the copy loop at `:318` copies through `p2` inclusive. Prepared paths therefore retain trailing separators the code intends to remove (the copy loop's own bound keeps this memory-safe). This is the corrected reading of RE-RIPTOPL-037(a).
4. **A fifth unchecked devctl `arg` use in mmce** — `modules/mmce/mmceman/src/mmce_fs.c` `MMCE_CMD_SET_GAMEID` case (~`:1129`) does `char *str = (char*)arg; mmce_cmd_set_gameid(str);` with no `arg == NULL`/`arglen` validation — the same family as RE-RIPTOPL-042's four counted cases, uncounted there (string argument rather than `*(u32*)arg`).

## Tally

- VERIFIED: 28
- VERIFIED-DRIFT: 0
- WEAKENED: 4 (RE-RIPTOPL-035, -037, -052, -055)
- REFUTED: 1 (RE-RIPTOPL-056)
- BLOCKED-ENV: 0
- Total: 33 (RE-RIPTOPL-034 … RE-RIPTOPL-066)

No finding in this range is a mechanism-level duplicate of another finding in the report: same-file neighbours were checked (RE-RIPTOPL-017/-022/-030/-031/-032/-033/-159/-165/-173 in SMSTCPIP, RE-RIPTOPL-001/-002/-014 in SMB, RE-RIPTOPL-010/-067/-068 in BDM/GPT) and each covers a distinct function/mechanism.
