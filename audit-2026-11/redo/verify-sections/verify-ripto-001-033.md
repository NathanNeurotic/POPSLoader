# Adversarial verification — RE-RIPTOPL-001 … RE-RIPTOPL-033

- Subject: `~/workspace/Sable-audit-redo/Redo-RiptOPL.md`
- Clone: `~/workspace/audit-clones-2026-11-13/RiptOPL`, HEAD verified `2e347d5ac885cd0ff73e9ad4143781946396f492` before reading; read-only throughout; `git status --porcelain` empty at the end.
- Method: refute-first. Every cited file/function/line opened; mechanism re-derived (bounds, signedness, widths); guards searched in callers/siblings; fix checked against LESS-NOT-MORE; mechanism-duplicate scan against the rest of the report (closest neighbours checked: RE-RIPTOPL-039 SMB request assembly vs 001/002, RE-RIPTOPL-171 ReadAndX dead branch vs 002, RE-RIPTOPL-043 APA cache-after-free vs 007, RE-RIPTOPL-063 GPT alloc vs 010 — all distinct mechanisms, no duplicates in this range).

## Verdict table

| ID | Verdict | Evidence (file:line) |
|---|---|---|
| RE-RIPTOPL-001 | VERIFIED | smb.c:100-110 24-bit length; smb.c:257-261 unchecked RecvData into SMB_buf.smb; smb.h:894-895 4096+128 |
| RE-RIPTOPL-002 | VERIFIED | smb.c:1077-1092 padding/DataLength unchecked vs nbytes; hardened sibling smb.c:1164-1170 |
| RE-RIPTOPL-003 | VERIFIED | smb.c:403-404 memcpy KeyLength (u8, server) into smb.h:286 EncryptionKey[8] |
| RE-RIPTOPL-004 | VERIFIED | smb.c:692-718, 833-846, 1477-1482 offsets used as raw u8buff indices, no received-length check |
| RE-RIPTOPL-005 | VERIFIED | udprdma.c:185 hdr_size up to 60 (4-bit field, udprdma_packet.h:89); udprdma.c:191-196 dummy[32]/rx_hdr_buffer unchecked vs rx_hdr_size; send-side check udprdma.c:595 |
| RE-RIPTOPL-006 | WEAKENED | sysneutrino.cpp:961-990 pattern real, but allocation 512+pairs*32 covers fixed-format output; see reasoning |
| RE-RIPTOPL-007 | VERIFIED | journal.c:47-56 write-side num++ unbounded; journal.c:58-86 restore loops on s32 num (libapa.h:183-189, sectors[126]) and derefs apaCacheAlloc() result (cache.c:194-202 can return NULL) unchecked at journal.c:72-75 |
| RE-RIPTOPL-008 | VERIFIED | device-hdd.c:11-28 default sector_to_read=0; device-hdd.c:30-48 callers pass result straight to sceAtaDmaTransfer |
| RE-RIPTOPL-009 | VERIFIED | ps2cnf.cpp:18 deref before bound; ps2cnf.cpp:42-71 no end bound, NUL only on whitespace branch, dead else-if at 62-64 |
| RE-RIPTOPL-010 | VERIFIED | part_driver_gpt.c:68 stride from sizeof not partition_entry_size (gpt_types.h:36, field never read in the driver); part_driver_gpt.c:130/175 no first_lba<=last_lba check, sectorCount underflows |
| RE-RIPTOPL-011 | VERIFIED | zso.c:105-112 LZ4_decompress_fast with clamped-only block size; lz4.c:500-506 fast entry passes srcSize 0 to generic decoder |
| RE-RIPTOPL-012 | VERIFIED | ds34bt.c (pademu):1146,1179,1198,1206 — led_buf 0x4D+2=79, memset 0x30+2=50, full 79 sent; same at ds34bt/iop/ds34bt.c:1243; lengths ds34bt.h:224,228 |
| RE-RIPTOPL-013 | VERIFIED | ps2ips.c:591-592 memcpy optlen into optval[128]; ps2ips.c:402-407,435-440 s_offset=64-malign, memcpy malign bytes, no clamp |
| RE-RIPTOPL-014 | VERIFIED | udpfs_core.c:114-117 returns server result.result ignoring udprdma_recv length; udpfs_core.c:547-549 name_len checked only vs name_max, not vs ret |
| RE-RIPTOPL-015 | VERIFIED-DRIFT | Mechanism at scsi.c:136-155 and scsi.c:211-219, not the cited 169-187 / 244-264; see reasoning |
| RE-RIPTOPL-016 | VERIFIED | tar.cpp:75 parseOctal octal-only; tar.cpp:278 size read; grep: no chksum/checksum anywhere in tar.cpp |
| RE-RIPTOPL-017 | VERIFIED | tcp_in.c:120 IP-header check only; tcp_in.c:157-158 pbuf_header(-(hdrlen*4)) return ignored; pbuf.c:482-491 forward move passes lower-bound check and u16 len/tot_len underflows; lwipopts.h:371-400 CHECKSUM_CHECK_*=0 |
| RE-RIPTOPL-018 | VERIFIED | smap-ingame/main.c:45-70 chain copied into FrameBuffer with no tot_len check; main.h:4 MAX_FRAME_SIZE 1518 |
| RE-RIPTOPL-019 | VERIFIED | mmce_cmds.c:195-224 strcpy(ptr,&rdbuf[4]) from 255-byte packet; mmce_fs.c:1122-1124 caller passes buf, buflen ignored |
| RE-RIPTOPL-020 | VERIFIED | include/opl.h:56 master-pass define (value not reproduced); accepted at src/ui/guisettings.cpp:1659; per-user key separate |
| RE-RIPTOPL-021 | VERIFIED | hdd_fio.c:995-997 parts[*(u32*)argp] unchecked, argp not NULL-checked; hdd.h:16-24 parts[APA_MAXSUB+1]; contrast ioctl2Transfer check hdd_fio.c:274-277 |
| RE-RIPTOPL-022 | VERIFIED | sockets.c:81-98 table 11 entries (0..-10), macro compares signed err against unsigned sizeof so every negative err yields EIO; err.h:61 ERR_IF=-11 has no table entry |
| RE-RIPTOPL-023 | VERIFIED | guiwait.cpp:49-113 runWithMessage bounded (timeoutMs_); guiwait.cpp:115-141 runWithDialog spins while(*flag_) with no timeout |
| RE-RIPTOPL-024 | VERIFIED | selfupdate.cpp:265-340 SHA verified in RAM, in-place WRONLY\|CREAT\|TRUNC write, SU_OK set after close with no read-back/hash of on-device bytes |
| RE-RIPTOPL-025 | VERIFIED | md5 ship/POPS/POPSTARTER.ELF = bbc61fa490df65d9527fcea7c4118170 = DEBUG variant; MAIN = 4a39d44dfb477ea747f5ca5e39ee011e; all 167,700 B |
| RE-RIPTOPL-026 | VERIFIED | vmcrebuild.cpp:9 design comment (backup never deleted), :124, :173-200; vcdsupport.cpp:2206-2208 install veto on existing .bak (-3), :2269-2360 write path also vetoes on pre-existing .bak at entry |
| RE-RIPTOPL-027 | VERIFIED | fs_driver.c:1019-1030 STOP_UNIT calls stop_all_bd, STOP_ALL resolves one volume and calls stop_single_bd; EE caller bdmsupport.cpp:2180 uses STOP_ALL per-device |
| RE-RIPTOPL-028 | WEAKENED | hdd.cpp:438-446 private_4 index unchecked (holds); hdd.cpp:405-437 negative-nsub half does not hold as stated; see reasoning |
| RE-RIPTOPL-029 | VERIFIED-DRIFT | Unvalidated copies real at elfldr_noreset.cpp:233-238 and system.cpp:1642-1651 (cited 1359 is the function entry); validated contrast system.cpp:1308-1324 |
| RE-RIPTOPL-030 | VERIFIED | api_msg.c:408-437 do_bind udp_new()/tcp_new() used unchecked; api_msg.c:505-540 do_connect checks every allocation; lwipopts.h:65,70-72 MEMP_NUM_UDP_PCB 1, TCP_PCB 1-2 |
| RE-RIPTOPL-031 | VERIFIED | api_lib.c:422 netconn_recv reads pcb.tcp->state, api_lib.c:538 netconn_write tcp_sndbuf(pcb.tcp), neither checks pcb.tcp NULL; api_lib.c:261-281 netconn_peer/addr lack conn==NULL check (peer checks pcb, not conn); sockets.c:180-196 lwip_accept uses newconn and *addrlen/addr unchecked; documented NULL-pcb state sockets.c:950,1086,1290 |
| RE-RIPTOPL-032 | VERIFIED | ps2ip.c:558-569 frees old block before AllocSysMemory, returns NULL on failure; mem.c:109-121 propagates; pbuf.c:438-441 ignores mem_realloc return and keeps using chain |
| RE-RIPTOPL-033 | VERIFIED | ip_frag.c:61-81 loop for(;len;p=p->next) derefs p->len with no NULL check; ip_frag.c:153-170 len from IPH_LEN; ip.c:241 pbuf_realloc(p,IPH_LEN) and pbuf.c:410-413 realloc cannot grow |

## Reasoning for non-VERIFIED verdicts

### RE-RIPTOPL-006 — WEAKENED
The C pattern is exactly as claimed (sysneutrino.cpp:974-978): `len += snprintf(text + len, size - len, ...)` with no return check, so *if* `len` ever passed `size`, `size - len` (int, negative) would convert to a huge `size_t` and the failure mode would be corruption, not truncation. What does not hold is reachability with any in-tree input, which the finding itself only rated Med/INFERRED:
- Buffer is sized for the output: `size = 512 + pairs * 32` (sysneutrino.cpp:963). Each pair emits a fixed-format line `    0x%08X, 0x%08X,\n` = 28 chars < the 32 budgeted per pair.
- `pairs` is bounded by the caller: supportbase.cpp:1853-1860 counts to at most `MAX_CHEATLIST / 2` over a NUL-terminated cheat list.
- The variable header inputs are bounded: `userCfg` is capped at 64 bytes and validated by `sysNeutrinoCfgNameSafe` (sysneutrino.cpp:995-1008); `startup` is the game's startup ID string from the game record, not an arbitrary-length path. The fixed header text plus these inputs fits well inside the 512-byte headroom.
- The cited twin `sysNeutrinoHandRA` (sysneutrino.cpp:1081/1111) writes into `text[1024]` from fixed module stanzas plus dotted-quad IPs — even tighter.
True scope: a latent unsafe idiom worth the one-line guard, but no shipping configuration was shown (and none was found in this pass) that actually truncates, so the claimed heap overwrite is not reachable as filed. Fix as prescribed is sane and LESS-compliant if applied as hardening, not as a live-bug fix.

### RE-RIPTOPL-015 — VERIFIED-DRIFT
Mechanism holds, citations are off:
- The READ/WRITE(10) CDB build that masks the 64-bit LBA into 4 bytes (with the code's own 2 TiB comment) is `scsi_cmd_rw_sector` at scsi.c:136-155 (comData[2..5] at 148-151), not the cited :169-187 (those lines are inside `scsi_warmup`'s inquiry/ready loop).
- The READ CAPACITY(10) warmup derivation is at scsi.c:211-219: `bd->sectorCount = (u64)(u32)getBI32(&rcd.last_lba) + 1;` — not the cited :244-264 (those lines are `scsi_read`'s retry loop).
- With `last_lba == 0xFFFFFFFF` (saturation on >2 TiB drives) sectorCount becomes exactly 2^32 sectors, self-consistent but wrong, and any LBA past 2^32-1 wraps in the CDB — a write lands low instead of failing. BDM's sector-size refusal (scsi.c:221-225) does not catch it.
- Prescribed fix (refuse on the saturation value in warmup) is the LESS option and is sane. Corrected citations: scsi.c:136-155 and scsi.c:211-219.

### RE-RIPTOPL-028 — WEAKENED
Two halves, different fates:
- `hddGetFileBlockInfo` half HOLDS: hdd.cpp:446 `lba = subs[stat.private_4].start + stat.private_5;` indexes the caller's `subs` array (callers pass `parts[APA_MAXSUB+1]`, 65 entries — hddsupport.cpp:2561-2564) with a value taken from filesystem stat metadata, with no bounds check anywhere in the function (hdd.cpp:438-470). A crafted/foreign PFS stat with private_4 >= 65 reads out of bounds and uses the result as an LBA.
- `hddGetPartitionInfo` negative-`nsub` half DOES NOT HOLD as stated: the on-disk field is unsigned — `u32 nsub` in both libapa.h:75 and include/hdd.h:34. hdd.cpp:422 does `int nsub = header->nsub;`, so only a header value >= 2^31 converts to a negative int; in that case the copy loop `for (i = 0; i < nsub; i++)` (hdd.cpp:426) never executes and the function returns `nsub + 1`, still negative, which callers treat in the error/negative-count path — no caller loop inherits a negative count and walks with it. The real residual on this half is only that values in (APA_MAXSUB, 2^31) are already clamped (hdd.cpp:423-424) and values >= 2^31 return a bogus negative count instead of a clean error — a robustness nit, not the claimed out-of-bounds path.
True scope: one unchecked index (private_4) in hddGetFileBlockInfo; the prescribed bounds check for that index is sane and LESS-compliant. The nsub clamp-at-0 fix is harmless but defends a path that does not exist as described.

### RE-RIPTOPL-029 — VERIFIED-DRIFT
Mechanism and contrast hold; one citation points at the function entry rather than the copy:
- elfldr_noreset.cpp:233-238: PT_LOAD loop `memcpy(eph[i].vaddr, pdata, eph[i].filesz)` with no check of offset/filesz/vaddr against the blob — as cited.
- system.cpp: the `sysLaunchLoaderElf` copy is at system.cpp:1642-1651 (`pdata = boot_elf + eph[i].offset; memcpy(eph[i].vaddr, pdata, eph[i].filesz)`), not at the cited :1359, which is the function's entry line (the finding does name the function in its location, so the site is findable, but the line is ~290 lines off the copy).
- The validated contrast is real and in the same file: sysPlaceIgrOverlay at system.cpp:1308-1324 checks vaddr range and `offset + filesz > size_igrovl_irx` before copying.
- Prescribed fix (apply the same three comparisons in the two loops, no new helper) is LESS-compliant. Corrected citation: system.cpp:1642-1651.

## Candidates (new defects noticed while verifying — not merged into verdicts)

1. **do_bind RAW branch is also unchecked** — api_msg.c:414-416 (approx., in do_bind): `msg->conn->pcb.raw = raw_new(...); raw_recv(msg->conn->pcb.raw, ...)` with no NULL check, the same mechanism RE-RIPTOPL-030 files for UDP/TCP in the same switch. The 030 fix should cover this branch too.
2. **ps2ips do_send/do_sendto length underflow adjacent to RE-RIPTOPL-013** — ps2ips.c:415,448: `sceSifGetOtherData(..., sendlen - pkt->malign, 0)`; when a malformed `malign` exceeds `sendlen` (= MIN(BUFF_SIZE, pkt->length)) the length argument underflows independently of the malign_buff memcpy the finding files.
3. **ZSO block-pointer advance is unclamped, adjacent to RE-RIPTOPL-011** — zso.c:105-120: only the per-block copy length `r` is clamped to 2048; `c_buff += b_size` advances by the unclamped index-derived `b_size`, so a crafted index can steer later blocks' source reads well past the compressed data before the decoder is even reached.

## Tally

- VERIFIED: 29
- VERIFIED-DRIFT: 2 (RE-RIPTOPL-015, RE-RIPTOPL-029)
- WEAKENED: 2 (RE-RIPTOPL-006, RE-RIPTOPL-028)
- REFUTED: 0
- BLOCKED-ENV: 0
- Total: 33
