# Blind Redo Audit — Launchstation IOP modules (all except `iop/smbd`)

- **Tree:** `~/workspace/audit-clones-2026-11-13/Launchstation`
- **HEAD (verified by `git rev-parse HEAD`):** `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790`
- **Method:** read-only source review. Every file:line below was read in this tree. Counts are by script (`find`/`wc`). One mechanism = one candidate, all locations listed. Items whose impact depends on behaviour not provable from this tree are labelled **INFERRED**. Licences of vendored code were treated as settled and not audited. No build or hardware run was performed; nothing here is PS2-build- or hardware-verified.
- **Scope note:** `iop/smbd` is excluded (assigned elsewhere). EE-side code was read only where an IOP sink's input contract required it.

---

## Coverage ledger

Totals are files / total lines under the module directory (script-counted, includes headers, `.lst`, docs). "Read" describes the depth actually achieved in this pass.

| Module | Files / lines | Coverage |
|---|---|---|
| `iop/smbman` | 17 / 5018 | **Deep.** `smb.c` reply parsers read end-to-end (Negotiate, SessionSetup, TreeConnect, NetShareEnum, QueryPathInformation, NTCreate, Read/WriteAndX, FindFirstNext2, Echo, GetSMBServerReply/RecvData); `smb_fio.c` devctl/open/read paths and NetShareEnum callers read. `auth.c`/`des.c`/`md4.c` skimmed (crypto, licences settled). |
| `iop/smb2man` (incl. `usmb2/`) | 24 / 5421 | **Deep.** `smb2man.c` glue (fixpath, parse_url, open/querydir/dread/stat/devctl), `usmb2/usmb2.c` (build_request, create, prw, rename, opendir/readdir), `usmb2/ntlm.c`, `usmb2/unicode.c` read. `smb2auth.c`, `md4c.c`/`md5.c`/`hmac-md5.c` skimmed (crypto). `usmb2/z80` tiny-TCP stack: not read — not compiled in the IOP build (see IOP-010). |
| `iop/vmcman` (+ `mcman_physical`, same sources) | 12 / 10049 | **Deep on parsing/geometry.** `src/main.c` superblock ingest, FAT walk, cluster cache, dir-entry walk read; `src/mciomanx_backing.c` read in full; `src/mcdev.c` unit mapping and mount path read; `src/mcman-internal.h` read. `ps1mc_fio.c`/`ps2mc_fio.c` skimmed (fixed-record PS1/PS2 file glue). |
| `iop/mmceman` | 20 / 4136 | **Deep.** `mmce_cmds.c` and `mmce_fs.c` command/fs paths read, incl. devctl dispatch; `mmce_restore_guard.h` name guard read; `sio2man_hook.c` diffed against the mx4sio copy. `mmce_sio2.c`/`mmceman.c` skimmed (transport/glue). |
| `iop/ps2ips_rpc` | 7 / 1263 | **Deep.** `ps2ips.c` read in full; `ps2ip_rpc.h` packet layouts read. |
| `iop/hdl_info` | 12 / 1137 | **Deep.** `hdl.c`, `apa.c`, `hdd.c`, `main.c`, headers read. |
| `iop/usbmass_bd` | 9 / 1750 | **Deep on SCSI layer.** `scsi.c` read (capacity, read/write, misalignment path); `usb_mass.c`/`main.c` skimmed (endpoint glue, `max_sectors` assignment). |
| `iop/nfsman` (incl. `unfs4/`) | 10 / 2910 | **Deep.** `nfsman.c` (parse_url, devctl, open/fh handling) and `unfs4/unfs4.c` (reassembly, get_fh, fits, put_path) read. |
| `iop/ps2host` | 7 / 1656 | **Partial-deep.** `net_fio.c` read/write segmentation and `net_fsys.c` path handling read; `hostlink.h` packet layouts read. |
| `iop/oldlibs/ps2ftpd` | 19 / 3916 | **Partial.** `FtpClient.c`, `FtpCommands.c`, `FileSystem.c` parsing/bounds read; `FtpServer.c` command loop skimmed. Loaded on demand only (per `ps2.yaml`). |
| `iop/ata_bd` | 5 / 1839 | **Partial-deep.** `ps2atad.c` IDENTIFY/geometry and sector-I/O chunking read. |
| `iop/ps2hdd_osd` | 17 / 4208 | **Partial.** `apa.c` header fill, `hdd_fio.c` devctl/ioctl2 and input breaker read; `journal.c`, `password.c` grep-skimmed only — **not deep-read** (time-boxed; fixed-size memcpy patterns only at grep level). |
| `iop/pccf` | 18 / 1322 | **Partial.** `pcdiag_cis.c` read in full (diagnostic CIS parser); `pccf_ata.c`/`pcdiag_cf.c` grep-skimmed — **not deep-read** (diagnostic, SCPH-10000 investigation code). |
| `iop/mx4sio_bd` | 19 / 3006 | **Skim.** `spi_sdcard_driver.c` init/CSD flow and bounce-buffer copies grep-checked; `mx4sio.c` DMA path skimmed. **Not deep-read** — fixed-`SECTOR_SIZE` copies only at grep level. |
| `iop/udpfs_smap` | 12 / 1379 | **Skim.** `xfer.c` RX/TX FIFO/DMA paths read; `main.c` is glue (no length-bearing copies); `smap.c` register driver **not read** (hardware register poking, no external-data parser). The UDPFS protocol parser itself lives on the EE/PC side, out of this scope. |
| `iop/ds34usb` | 7 / 1421 | **Partial.** IOP RPC dispatch and report parsing read (`ds34usb.c`). Only built in the optional DS34 variant (see checked-clean). EE lib skimmed. |
| `iop/ds34bt` | 7 / 2565 | **Skim.** HCI/L2CAP command construction grep-checked (callers pass fixed-size command buffers); full event-parser read **not done** (time-boxed; optional-variant module). |
| `iop/usbd-ra` | 18 / 4117 | **Skim.** Descriptor-fetch bounds in `hub.c`/`hcd.c` read at the length-handling sites; rest of this vendored USBD clone **not read** (mature upstream code, no local parser deltas found at grep level). |
| `iop/xparam` | 5 / 1012 | **Read.** `src/xparam.c` `_start`/database walk read. |
| `iop/AllowDVDV` | 3 / 103 | **Read.** Single `.c`; all copies are constant-length into a fixed buffer. |
| `iop/dev9_poweroff` | 3 / 35 | **Read.** Trivial handler-clearing module. |
| `iop/__precompiled`, `iop/__v10` | 5 / 640 | **Not read — binary IRX blobs, no source in tree.** Nothing auditable at source level. |
| `iop/include_compat` | 1 / 39 | **Read.** Single compat header. |
| EE memory-card code | — | **Not read.** Not needed: every mc sink confirmed IOP-side is driven by card/VMC data, not by EE parsing. |

---

## Candidate findings (sorted by benefit)

### IOP-001 — SMB1 NetShareEnum walks a share list using fully server-controlled offsets, count and string lengths

- **Category:** 1 (wire-controlled lengths) / 3 (parser)
- **Locations:** `iop/smbman/smb.c:736` (status read via server `ParamOffset`), `iop/smbman/smb.c:740` (`AvailableEntries` from server), `iop/smbman/smb.c:743` (`data` = receive buffer + server `DataOffset`), `iop/smbman/smb.c:746-763` (walk loop). Callers: `iop/smbman/smb_fio.c:1021`, `iop/smbman/smb_fio.c:1031`.
- **Mechanism:** After `GetSMBServerReply`, none of the response's `ParamOffset`, `DataOffset`, or entry count is checked against the received length `r`. The loop runs `AvailableEntries` times (signed 16-bit value read out of the reply), each iteration calling `strlen(p)` with no bound inside the 4096+128-byte `SMB_buf` (`iop/smbman/smb.h:900-901`), computing padding from that length, reading the share type at `p[strlen(p)+1+padding-2]`, and forming the comment pointer as `&data[*(u16 *)&p[strlen(p)+1+padding]]` — a server-supplied 16-bit offset — passed to `strncpy(..., 256)`. `p` then advances by `strlen(p)+1+padding+4`, still unbounded.
- **Evidence:** Code as read at the lines above. A malicious or broken SMB1 server (or a MITM on the plaintext session) can drive `p` and the comment pointer far past `SMB_buf`, reading arbitrary IOP memory into the share list returned to the EE and/or crashing the module. The sibling parser `smb_FindFirstNext2` in the same file *was* hardened with offset/length validation (`iop/smbman/smb.c:1530-1559`), so this is a leftover, not the file's house style.
- **Recommendation (LESS NOT MORE):** Validate once at the top, mirroring the FindFirstNext2 pattern already in the file: `ParamOffset`/`DataOffset` must be `< r`; clamp the entry count to what fits between `data` and the end of the received message; inside the loop, bound `strlen` by the remaining bytes (bail out if no NUL before the end) and require the comment offset to land inside the received data. No new buffers, no new API.

### IOP-002 — vmcman trusts card/VMC superblock geometry; cluster cache is filled past its 1024-byte entries

- **Category:** 3 (card format parser)
- **Locations:** `iop/vmcman/src/main.c:1391-1393` (superblock copy in `mcman_setdevinfos`), `iop/vmcman/src/main.c:3766-3773` (`McReadCluster` page loop), `iop/vmcman/src/mciomanx_backing.c:116-141` (VMC mount validation), cache sizing at `iop/vmcman/src/main.c:45` and `iop/vmcman/src/mcman-internal.h:110` (`MCMAN_CLUSTERSIZE 1024`).
- **Mechanism:** `mcman_setdevinfos` first derives sane geometry in `mcman_setdevspec` (`main.c:1341-1353`), then overwrites the first 0x150 bytes of `MCDevInfo` — including `pagesize`, `pages_per_cluster`, `blocksize`, `clusters_per_card`, `alloc_offset`, `ifc_list` region — with raw superblock bytes from the card or VMC image, checking only the magic string and a version nibble. `McReadCluster` then loops `for (i = 0; i < mcdi->pages_per_cluster; i++) McReadPage(..., mce->cl_data + i * mcdi->pagesize)`, where each `cl_data` entry is exactly 1024 bytes. A crafted card/VMC with e.g. `pagesize=512, pages_per_cluster=64` writes 32 KB per cluster read over the static cache and adjacent IOP statics. The VMC mount path does not close this: `mciomanx_backing.c` validates magic, card type and `pagesize ∈ {512,528}`, and a file-size equation, but never bounds `pages_per_cluster` or `blocksize`; its `total_pages = pages_per_cluster * clusters_per_card` (line 116) is also plain `int` arithmetic (**INFERRED:** overflow can make a wrong-sized image pass the size equation).
- **Evidence:** Lines as read above. Both physical cards (via `mcman_physical`, same sources, `ps2.yaml:119-131`) and VMC images (user-supplied files, e.g. downloaded/shared VMCs) reach this code.
- **Recommendation (LESS NOT MORE):** After the superblock copy, re-validate the handful of geometry fields the driver actually depends on — `pagesize ∈ {512,528}`, `pages_per_cluster * pagesize == MCMAN_CLUSTERSIZE` (the invariant `setdevspec` itself establishes), `clusters_per_block != 0` — and reject the card otherwise. One small check at the single ingest point covers every downstream loop; no per-callsite changes.

### IOP-003 — vmcman FAT walk indexes the 32-entry `ifc_list` with an unbounded card-derived index

- **Category:** 3 (card format parser)
- **Locations:** `iop/vmcman/src/main.c:3872-3902` (`McSetFATentry`), `iop/vmcman/src/main.c:3905-3932` (`McGetFATentry`), same pattern inside the file-read path at `iop/vmcman/src/main.c:1728-1746`; array definition `iop/vmcman/src/mcman-internal.h:312` (`u32 ifc_list[32]`).
- **Mechanism:** `ifc_index = (fat_index / FATentries_per_cluster) / FATentries_per_cluster` is used directly as `mcdi->ifc_list[ifc_index]` with no upper-bound check. `fat_index` values come from FAT/dir traversal of card data (e.g. the cluster-chain walk feeding `McGetFATentry(..., clust, &clust)` at `main.c:3815`), and `FATentries_per_cluster` itself comes from the (IOP-002) superblock-controlled geometry, so a crafted card can shrink the divisor and push `ifc_index` well past 31 — reading (and, via `McSetFATentry`'s subsequent cluster write, acting on) out-of-bounds `MCDevInfo` memory as a cluster number.
- **Evidence:** Lines as read above; no bound exists in either function.
- **Recommendation (LESS NOT MORE):** One guard in each of the two exported functions (and the inline copy at 1728-1746): `if (ifc_index >= 32) return error;` before the first `McReadCluster`. Three lines total.

### IOP-004 — hdl_info copies game name/startup with `strcpy` from disk data and from the EE rename packet

- **Category:** 3 (file format parser) / 1 (RPC-supplied length)
- **Locations:** `iop/hdl_info/hdl.c:48` (`strcpy(ginfo->name, buffer + 8)`), `iop/hdl_info/hdl.c:49` (`strcpy(ginfo->startup, buffer + 0xac)`), `iop/hdl_info/hdd.c:180` (`strcpy(game->name, Packet->NewName)`), with the matching unbounded compare at `iop/hdl_info/hdd.c:177` (`strcmp(Packet->OldName, game->name)`). Destinations: `iop/hdl_info/hdl.h:9-10` (`name[65]`, `startup[13]`); packet field `iop/hdl_info/hdd.h:68` (`NewName[64]`); RPC buffer `iop/hdl_info/main.c:23` (4 KB).
- **Mechanism:** The HDLoader game header is read from disk into a 1024-byte stack buffer; neither the name field at offset 8 nor the startup field at offset 0xac is guaranteed NUL-terminated by the format as parsed here, and both are `strcpy`'d into 65- and 13-byte heap fields — a crafted/corrupt game partition overflows the game-list heap. The rename path repeats the pattern for EE-supplied data: if `NewName` (or `OldName`) is not NUL-terminated within its 64-byte packet field, `strcpy`/`strcmp` read on through the RPC buffer and write past `game->name`.
- **Evidence:** Lines as read above; note the same function does bound its other copy (`memcpy(ginfo->partition_name, part->id, PS2_PART_IDMAX)` + explicit NUL at `hdl.c:46-47`), so the `strcpy`s are the inconsistency.
- **Recommendation (LESS NOT MORE):** Replace the two disk-side `strcpy`s with bounded copies matching the existing `partition_name` pattern (copy at most dest-1, force NUL), and validate `NewName`/`OldName` termination once at the top of the rename handler. No format or API change.

### IOP-005 — mmceman copies the card-supplied game ID with `strcpy` into the caller's devctl buffer

- **Category:** 1 (device-controlled length) / 3 (parser)
- **Locations:** `iop/mmceman/src/mmce_cmds.c:195-224` (`mmce_cmd_get_gameid`; `strcpy` at line 216), caller `iop/mmceman/src/mmce_fs.c:1360-1362` (devctl `MMCE_CMD_GET_GAMEID` passes its `buf` straight through).
- **Mechanism:** The MMCE device returns a fixed 255-byte packet; the game ID is taken as a C string starting at `&rdbuf[0x4]` with no check that a NUL exists within the packet, and `strcpy`'d into whatever buffer the EE devctl caller supplied. A card (or clone/faulty unit) returning 251 non-NUL bytes makes `strcpy` read past the stack `rdbuf` and write unbounded into the destination.
- **Evidence:** Lines as read above. The fs layer's other name paths were explicitly guarded against this class (`mmce_fs_wire_name_ok`, `iop/mmceman/src/mmce_restore_guard.h`, enforced at every fs entry point) — the cmds layer was not.
- **Recommendation (LESS NOT MORE):** Bound the copy by the packet: find the length with a bounded scan over `rdbuf[0x4..0xFF]` (fail if none) and `memcpy` that many bytes + NUL. One function changed.

### IOP-006 — ps2ips_rpc trusts the EE packet's `malign` value in send/sendto; negative lengths pass through recv

- **Category:** 1 (RPC-controlled length) / 2 (integer misuse)
- **Locations:** `iop/ps2ips_rpc/ps2ips.c:336-345` (`do_send`), `iop/ps2ips_rpc/ps2ips.c:365-378` (`do_sendto`), packet layout `iop/ps2ips_rpc/ps2ip_rpc.h:99-102` (`malign_buff[64]`); same-family: `recvlen = MIN(BUFF_SIZE, recv_pkt->length)` at `iop/ps2ips_rpc/ps2ips.c:149` and `:249` with no lower bound.
- **Mechanism:** `s_offset = 64 - pkt->malign; memcpy(lwip_buffer + s_offset, pkt->malign_buff, pkt->malign);` — `malign` is an EE-supplied `int`, never checked against the 64-byte `malign_buff` or against `sendlen`. `malign > 64` writes before `lwip_buffer` (a 1088-byte static, `ps2ips.c:51`) and reads past the packet; negative `malign` turns the `memcpy` length into a huge `size_t`. `sendlen - pkt->malign` is then handed to `sceSifGetOtherData` unchecked, so `malign > sendlen` sends stale buffer contents. In recv/recvfrom, a negative `length` survives `MIN()` and reaches `recv()` and the alignment arithmetic.
- **Evidence:** Lines as read above. Threat model is a buggy/malicious EE client rather than the network, which caps severity — but this module is the network stack's RPC front door for every homebrew app, and the neighbouring `do_setsockopt` *was* fixed with exactly the missing check (`ps2ips.c:526-530` bounds `optlen` to its 128-byte buffer), proving the pattern is wanted here.
- **Recommendation (LESS NOT MORE):** At the top of `do_send`/`do_sendto`: reject `malign < 0 || malign > 64 || malign > pkt->length`; at the top of `do_recv`/`do_recvfrom`: reject `length < 0`. Four small guards, no restructuring.

### IOP-007 — usbmass_bd uses the device-reported block length for a stack `alloca` and unchecked transfer lengths

- **Category:** 1 (device-controlled length) / 2 (integer misuse)
- **Locations:** `iop/usbmass_bd/src/scsi.c:244-267` (READ CAPACITY 10/16 ingest; only `== 0` rejected), `iop/usbmass_bd/src/scsi.c:321` (`__builtin_alloca(sectorSize + 4)`), `iop/usbmass_bd/src/scsi.c:334` (`memcpy(misalign_buffer, buffer, sectorSize)`), transfer length `bd->sectorSize * sectorCount` at `iop/usbmass_bd/src/scsi.c:156` and `:174`.
- **Mechanism:** Any nonzero device-reported `block_length` becomes `bd->sectorSize`. On the misaligned-buffer write path, that value sizes a stack `alloca` on an IOP thread stack: a device reporting e.g. 64 KB blocks overflows the stack outright, and even a legitimate 4 KB-sector device spends 4 KB+ of stack whenever the EE buffer is misaligned. The same value multiplies transfer lengths in the READ/WRITE(10/16) commands with no sanity ceiling (512/1024/2048/4096 are the only block lengths the rest of the stack — FAT, APA, PFS — can actually use).
- **Evidence:** Lines as read above.
- **Recommendation (LESS NOT MORE):** At capacity ingest, reject `sectorSize` values that are not powers of two in [512, 4096] — the set every consumer already assumes. One check at the single ingest point; the `alloca` and multiplications become safe by construction.

### IOP-008 — SMB1 QueryPathInformation dereferences the server's `DataOffset` without validation

- **Category:** 1 (wire-controlled offset)
- **Locations:** `iop/smbman/smb.c:877` (`BasicFileInfo_t *` cast), `iop/smbman/smb.c:890` (`StandardFileInfo_t *` cast), in `smb_QueryPathInformation` (`iop/smbman/smb.c:811`).
- **Mechanism:** After the reply, `&SMB_buf.smb.u8buff[QPIRsp->smbTrans.DataOffset]` is cast to the info structs and ~40 bytes are read from it, with no check that `DataOffset` (a server-supplied 16-bit field, up to 65535) plus the struct size fits in the received message/`SMB_buf` (4224 bytes). A hostile server makes the IOP read out-of-bounds memory and report it to the EE as file metadata. Same root cause as IOP-001 but a different function and sink; the fix pattern (FindFirstNext2, `smb.c:1530-1559`) already exists in-file.
- **Evidence:** Lines as read above.
- **Recommendation (LESS NOT MORE):** One check before each cast (or once, before the `queryType` branch): `DataOffset` must be `<= r - sizeof(*struct)`, else `-EIO`.

### IOP-009 — hdl_info sums sub-partition lengths using the disk-controlled `nsub` past the 64-entry array

- **Category:** 3 (file format parser)
- **Locations:** `iop/hdl_info/hdl.c:43-44`, same pattern at `iop/hdl_info/apa.c:243` (with the count cross-check at `apa.c:257`); array bound `iop/hdl_info/ps2_hdd.h:20` (`PS2_PART_MAXSUB 64`) and `:76` (`subs[PS2_PART_MAXSUB]`).
- **Mechanism:** `for (i = 0; i < get_u32(&part->nsub); ++i) size += get_u32(&part->subs[i].length);` — `nsub` is a raw u32 from the on-disk APA header; nothing clamps it to 64, so a crafted partition header reads far past the header struct (into adjacent stack/heap) while totalling a game's size. Read-only overflow, but it also feeds the `total_size_in_kb` the EE displays and acts on.
- **Evidence:** Lines as read above.
- **Recommendation (LESS NOT MORE):** Clamp the loop to `PS2_PART_MAXSUB` (and treat `nsub > PS2_PART_MAXSUB` as a corrupt header) at both sites.

### IOP-010 — Vendored usmb2 contains an unhardened server-length `memcpy` in readdir, kept out of the IOP build only by a feature define

- **Category:** 8 (feature gate) / 6 (dead-but-armed code)
- **Locations:** `iop/smb2man/usmb2/usmb2.c:791-792` (`u32` = first 4 reply bytes; `memcpy(&dh[16+4], &usmb2->buf[8], u32)`), entry-chain parsing `usmb2.c:795-817`; destination sized at `usmb2.c:739-740` (`16 + MAX_DIR_SIZE`, `MAX_DIR_SIZE 256` at `usmb2.c:69`); gate: whole block inside `#ifdef USMB2_FEATURE_OPENDIR` (`usmb2.c:743-830`), and `ps2.yaml:265-271` defines only `WRITE/NTLM/UNICODE/STAT/MKDIR/UNLINK/RENAME` for smb2man.
- **Mechanism:** The QUERY_DIRECTORY reply's own length field is trusted as a `memcpy` length into a 272-byte heap allocation — a textbook server-controlled overflow — and the follow-on entry-chain walk (`next_de`, name length at `+0x3c`) is likewise unbounded. **Today this is not reachable:** `USMB2_FEATURE_OPENDIR` is not defined for the IOP build, and `smb2man.c` does its own (hardened) querydir, never calling `usmb2_opendir`/`usmb2_readdir`. The hazard is that the vendored copy carries local hardening patches for other paths (`usmb2/VENDORED.txt`, `riptopl.patch`) but not this one, so the first future feature flip or vendored-code reuse elsewhere lands a known-bad parser. (Related gate fact, verified: `USMB2_FEATURE_TINY_TCP` auto-enables only for Z80 targets, `usmb2.h:7-12`, so the tiny-TCP reassembly paths are likewise absent from the IOP build.)
- **Evidence:** Lines as read above.
- **Recommendation (LESS NOT MORE):** Patch the two lines at the vendoring level (clamp `u32` to `MAX_DIR_SIZE - 4` and to the validated reply length, both already available in the function) and note it in `VENDORED.txt` — cheaper than re-discovering it when OPENDIR is ever enabled. Deleting the OPENDIR block from the vendored copy is an equally valid, even smaller alternative.

### IOP-011 — mmceman set-game-ID narrows the length to `u8` and `strcpy`s into a 255-byte stack buffer

- **Category:** 2 (integer truncation) / 1
- **Locations:** `iop/mmceman/src/mmce_cmds.c:226-243` (`u8 len = strlen(ptr) + 1;` at line 231; `strcpy(&wrbuf[0x4], ptr)` into `u8 wrbuf[0xFF]`), caller `iop/mmceman/src/mmce_fs.c:1364-1367` (devctl passes the EE string through unchecked).
- **Mechanism:** An EE-supplied game-ID string of 251+ bytes overflows the stack `wrbuf`; at 255+ bytes the `u8 len` also wraps, so the transmitted length and the copied length disagree. EE-side callers are trusted local code, so this is robustness, not a remote hole — but the devctl is a public interface any homebrew can call.
- **Evidence:** Lines as read above.
- **Recommendation (LESS NOT MORE):** Reject `strlen(ptr) > 250` at the top of `mmce_cmd_set_gameid` (the wire format cannot express more anyway).

### IOP-012 — The SIO2 hook exists as two near-identical copies (mmceman, mx4sio_bd) already diverged in one behaviour

- **Category:** 5 (duplicated driver)
- **Locations:** `iop/mmceman/src/sio2man_hook.c` (320 lines) and `iop/mx4sio_bd/src/sio2man_hook.c` (315 lines); md5s differ; `diff` shows exactly one functional divergence: mmceman comments out `#define PORT_NR 3` with a rationale comment (both-slot access), mx4sio keeps the port filter.
- **Mechanism:** Both modules hook the same sio2man exports and implement the same transfer serialisation/locking. Any future locking or DMA fix must be made twice, in files that look interchangeable but are not; the one existing divergence is precisely the kind that gets silently lost when one copy is refreshed from the other.
- **Evidence:** `diff` output as read above; both are built (`ps2.yaml` mmceman sources and mx4sio_bd sources each list their own copy).
- **Recommendation (LESS NOT MORE):** Do not merge them (their one difference is deliberate and load-order-sensitive). Instead, add a one-line cross-reference comment at the top of each file naming the other copy and the intentional difference — the cheapest guard against the next silent divergence. (Contrast, checked clean: `mcman_physical`/`vmcman` share one source directory with different defines, `ps2.yaml:119-155` — the right pattern, already in use.)

### IOP-013 — hdl_info APA chain walk follows disk `next` pointers with only a 10,000-count hack against cycles

- **Category:** 3 (file format parser)
- **Locations:** `iop/hdl_info/apa.c:154-179` (walk loop; bounds check at `:162-163`; count cap and TODO comment at `:175-178`).
- **Mechanism:** The walk follows `part.next` from header to header. The in-code comment admits the missing visited check: a cyclic chain is stopped only after 10,000 iterations of sector reads. The guard that does exist, `get_u32(&part.start) + get_u32(&part.length) < total_sectors`, is 32-bit arithmetic — **INFERRED:** a `start`/`length` pair whose sum wraps below `total_sectors` passes the check, after which the walk trusts `next` from a header outside the real partition area (the magic+checksum gate at `:158-161` still limits which sectors are accepted as headers, which is why this stays low).
- **Evidence:** Lines as read above, including the author's own TODO.
- **Recommendation (LESS NOT MORE):** Track visited start sectors in the table being built (it already accumulates them via `apa_part_add`) and stop on a repeat; widen the start+length comparison to 64-bit. Both are local to this loop.

### IOP-014 — vmcman VMC-backing slot validation is off by one and admits negative slots (latent)

- **Category:** 3 (boundary check)
- **Locations:** `iop/vmcman/src/mciomanx_backing.c:46` (`if (slot > MCMAN_MAXSLOT)`), array `iop/vmcman/src/mciomanx_backing.c:26` (`mcman_vmc_cardinfo[MCMAN_MAXSLOT]`, `MCMAN_MAXSLOT 10` at `iop/vmcman/src/mcman-internal.h:106`).
- **Mechanism:** `slot == 10` passes validation and indexes one element past the array; negative slots pass too. **Currently unreachable as far as this tree shows:** the only callers derive the slot through `mcman_unit2card` (`iop/vmcman/src/mcdev.c:216-223`), which masks the unit into range — so this is a latent trap for the next caller, not a live bug (labelled accordingly).
- **Evidence:** Lines as read above.
- **Recommendation (LESS NOT MORE):** Change the one comparison to `if (slot < 0 || slot >= MCMAN_MAXSLOT)`. One line, at the validation function whose whole job is this check.

### IOP-015 — mmceman directory read stores the card-supplied filename without ensuring NUL termination

- **Category:** 3 (parser)
- **Locations:** `iop/mmceman/src/mmce_fs.c:1040-1043` (`filename_len = rdbuf[0x29]; ... mmce_sio2_tx_rx_pio(0, filename_len, NULL, dirent->name, ...)`).
- **Mechanism:** The card supplies the name length (u8, so ≤ 255, which fits the iomanX dirent name field) and that many bytes are received directly into `dirent->name`; no byte is forced to NUL afterwards. A card returning a full 255-byte name with no NUL leaves termination to whatever stale byte follows in the dirent, and EE consumers treat the field as a C string.
- **Evidence:** Lines as read above.
- **Recommendation (LESS NOT MORE):** After a successful receive, write `dirent->name[filename_len] = '\0'` (the field has room for exactly this case).

### IOP-016 — ps2ftpd keeps one static 32 KB transfer buffer for the whole server

- **Category:** 7 (large static buffer)
- **Locations:** `iop/oldlibs/ps2ftpd/src/FtpClient.c:88` (`static char buffer[32768]`).
- **Mechanism:** 32 KB of IOP RAM (of 2 MB total) is permanently reserved for a module that is loaded on demand, and the single buffer is shared across clients/transfers. The size is deliberate (comment cites round trips on slow devices such as MMCE), and the send path is properly bounded (see checked-clean), so this is a footprint/robustness observation, not a defect with a known trigger.
- **Evidence:** Line as read above.
- **Recommendation (LESS NOT MORE):** None required. If IOP RAM pressure ever forces a choice, this buffer is the largest single static in the audited IOP set and the first place to look; halving it costs round trips, so it is a trade-off to make knowingly, not a fix to apply blindly.

---

## Checked-clean notes (verified in this pass — no candidate)

- **smbman reply handling, other commands:** `GetSMBServerReply` never receives past `SMB_buf` (`smb.c:264-267`); `RecvData` loops to the full length (`smb.c:204-224`). NegotiateProtocol bounds KeyLength/ByteCount/domain by received bytes (`smb.c:409-438`, domain capped by the 64-byte field via `getStringField`). FindFirstNext2 validates offsets and name length before use (`smb.c:1530-1559`). ReadAndX validates DataOffset/padding/DataLength against the reply (`smb.c:1124-1139`, with an explanatory comment). SessionSetup/TreeConnect request building draws on fixed-size EE structs and the 64-byte domain field — totals fit `SMB_buf`.
- **usmb2 socket path:** `usmb2_build_request` (`usmb2/usmb2.c:326-480`) checks the SPL, caps interim replies, validates the READ DataOffset, bounds its drain loop by `sizeof(buf)`, and cross-checks the READ length (the local RiptOPL patch at `usmb2.c:866-869`). NTLM challenge parsing bounds every server offset/length against `reply_len`/`sec_len` before use (`usmb2/ntlm.c:55-125`).
- **smb2man glue:** `smb2man_fixpath` caps names at `SMB2MAN_NAME_MAX 440` and rejects invalid UTF-8 (`smb2man.c:386-394` and following); `smb2man_parse_url` bounds the share so the UNC fits 127 bytes (`smb2man.c:1449-1482`); querydir clamps OutputBufferLength to the 4096-byte dirbuf and dread clamps next/namelen. One fragility noted without a candidate: `utf8_to_utf16` (`usmb2/unicode.c`) has no output bound of its own and is safe only because the 440-byte input cap makes the arithmetic fit — true today at every call site checked.
- **nfsman/unfs4:** `nfsman_parse_url` fully bounded (`nfsman.c:1205-1256`); devctl rejects short args (`nfsman.c:1311`); unfs4 uses a consistent `fits()` discipline, caps file handles at `UNFS4_MAX_FH` in `get_fh`, and nfsman's FH copies are safe because the source FH is `get_fh`-validated and the destination is sized `4 + UNFS4_MAX_FH`.
- **mmceman fs layer:** `mmce_fs_wire_name_ok` rejects names ≥ 255 bytes before the u8 narrowing at every fs entry point checked (`mmce_fs.c:241, 632, 696, 760, 825, 1074, 1188`) — the EE→card direction is guarded; only the card→EE replies in IOP-005/IOP-015 were not.
- **ps2ftpd bounds:** `FtpClient_Send` is bounded with compile-time size assertions (`FtpClient.c:154-175`); `FileSystem_BuildPath`/`ClassifyPath` are bounded; the command line is capped by the 512-byte `m_CommandBuffer`, so the `strcpy` into the 32 KB buffer at `FtpClient.c:186` cannot overflow as reached.
- **ps2host segmentation constants:** `net_fio.c:308-310` tests `PKO_MAX_WRITE_SEGMENT` but assigns `PKO_MAX_READ_SEGMENT` in the write splitter — a wrong constant that is **currently harmless**: both structs are 14 bytes packed (`hostlink.h:120-134`), so both segment values are 1446, and `send_packet` is 4096 bytes (`net_fio.c:25-27`). Latent trap only if one struct changes; noted here so it is on record without inflating the candidate count.
- **ata_bd:** LBA48 total-sectors is deliberately clamped to `0xffffffff` (`ps2atad.c:1311-1315`) — the known 2 TB design context of this stack, not a truncation bug. Sector-I/O chunking read and found consistent.
- **pccf CIS parser:** `pcdiag_cis.c` is explicitly bounded (bus limit, tuple limit, per-tuple length checks, malformed flags) — a model parser; clean.
- **usbd-ra descriptor fetch:** `wTotalLength` is checked against `maxStaticDescSize` before fetching (`hub.c:429-433`), hub descriptor copy is clamped to the struct size (`hub.c:715-718`), and the descriptor walk requires `bLength >= 2` and stays under the end pointer (`hcd.c:193-203`). Clean at skim depth.
- **mx4sio_bd:** data copies are fixed `SECTOR_SIZE` bounce copies (`spi_sdcard_driver.c:606, 669`). Clean at skim depth.
- **udpfs_smap xfer:** header-read size is clamped to the 64-byte header buffer (`xfer.c:94-97`); RX callback receives a clamped `hdr_len` (`xfer.c:182-187`). Clean at skim depth.
- **DS34 modules:** the apparent "dead code" is an intentional optional variant — `scripts/configure_ds34.py` generates a separate build config adding the ds34 targets, the `DS34` define and `src/pad_ds34.c`, and `scripts/check_ds34_build.py` verifies the standard ELF excludes it. In the standard build the EE loads the IRXs externally (`src/init.c:1715-1730`). ds34usb's RPC dispatch passes only u8 ports, which its `port >= MAX_PADS` checks do bound. Not a candidate.
- **xparam:** `argc == 3` matches neither branch of `_start` (`xparam.c:30-45`) and a trailing unpaired argument is dropped — cosmetic dead case in a boot-time module that always returns `MODULE_NO_RESIDENT_END`; no out-of-bounds access found. Not a candidate.
- **AllowDVDV / dev9_poweroff:** constant-length copies and a two-line handler clearer, respectively. Clean.
- **ps2hdd_osd input breaker:** `fioInputBreaker` (`hdd_fio.c:107-126`) checks `maxout < len` before copying; the `len == maxout` case copies without room for a NUL, but consumers treat the fields as fixed-width (`memcpy(..., APA_IDMAX)`) — no candidate at the depth read.
