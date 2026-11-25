# Verification W6 — RiptOPL Round-9 Modules, Category 6 (RIPTOPL-442 … RIPTOPL-452)

- **Clone:** `~/workspace/audit-clones-2026-11-13/RiptOPL`, HEAD verified `2e347d5ac885cd0ff73e9ad4143781946396f492` at start and end; working tree git-clean throughout (read-only).
- **Source report:** `Sable-RiptOPL-ROUND9-MODULES.md`
- **Counts:** VERIFIED 8 · VERIFIED-DRIFT 2 · WEAKENED 0 · REFUTED 1

| ID | Verdict | One-line evidence (path:line) |
|---|---|---|
| RIPTOPL-442 | VERIFIED | `modules/bdm/bdmfs_fatfs/src/fs_driver.c:465` `return (ret == FR_OK) ? bw : 0;` and `:484` same for `br` — every FatFs error collapses to 0, exactly as cited |
| RIPTOPL-443 | REFUTED | Sentinel arithmetic is real (`modules/iopcore/common/cdvd_config.h:71` `u16 FIDs[]`), but the sole caller defeats the claimed second close: `modules/iopcore/cdvdman/device-smb.c:165` calls `smb_CloseAll()` only `if (smb_mount_state == 1)` and `:168` sets it to `-1` |
| RIPTOPL-444 | VERIFIED | `modules/network/smbman-ra/smb_fio.c:840-853` — SEEK_CUR/SEEK_SET test only `r > fh->filesize` / `fh->filesize < pos`; with `filesize`/`position` both `s64` (`:75-76`) a negative result is stored at `:862` |
| RIPTOPL-445 | VERIFIED | `modules/network/smbman-ra/smb_fio.c:660-663` `strncpy(fh->name, path, 255)` + `strlen` + two `strcat`s into `char name[256]` (`:69`, `:78`); `prepare_path` (`:297-326`) can return paths far longer than 255 |
| RIPTOPL-446 | VERIFIED | `modules/bdm/src/part_driver_gpt.c:68` strides by `sizeof(gpt_partition_table_entry)` (128, `gpt_types.h:46-54`); `partition_entry_size` (`gpt_types.h:36`) is read nowhere in `modules/`; FatFs rejects non-128 at `modules/bdm/bdmfs_fatfs/fatfs/ff.c:3332` |
| RIPTOPL-447 | VERIFIED | `modules/bdm/src/part_driver_gpt.c:23-50` has no `sectorOffset`/`parNr` filter (contrast `part_driver_mbr.c:48-49`); `modules/bdm/src/bdm.c:184` offers every unmounted device to every fs driver, and MBR/GPT are registered before FatFs (`part_driver.c:133-142`) |
| RIPTOPL-448 | VERIFIED | `modules/hdd/atad/src/ps2atad.c:1218` `ata_get_security_status(device, devinfo, NULL)`; helper `:1146-1150` → IDENTIFY (cmd-table type 2, `:139`) → PIO data-in writes 256 u16 to the buffer at `:694-700`, then dereferences it at `:1149`; export at `exports.tab:17` |
| RIPTOPL-449 | VERIFIED-DRIFT | Mechanism holds at `modules/iopcore/cdvdman/ncmd.c:156-158` exactly as cited, but the cited `maxlsn` line is wrong: it is at `ncmd.c:179`, not `:185` (`:185` is blank) |
| RIPTOPL-450 | VERIFIED | `modules/iopcore/cdvdman/ioops.c:369-371` `r = fh->position = fh->filesize - offset;` for SEEK_END, with only the upper clamp at `:376-377` and `unsigned int position` at `:13-14` |
| RIPTOPL-451 | VERIFIED-DRIFT | Mechanism holds at `modules/network/SMSTCPIP/tcp_out.c:530-568` (no `TCPH_FLAGS_SET`; `TCPH_HDRLEN_SET` at `include/lwip/tcp.h:204` preserves existing flags), but the cited allocator range is wrong: `ps2ip_mem_malloc`/`AllocSysMemory` are at `ps2ip.c:535-545` (`AllocSysMemory` call `:541`), not `ps2ip.c:524-533` |
| RIPTOPL-452 | VERIFIED | `modules/network/SMSTCPIP/api_lib.c:422` and `:538` dereference `conn->pcb.tcp` unguarded; `api_msg.c:190` (`err_tcp`) sets it NULL; in-tree guards exist at `sockets.c:950`, `:1086`, `:1290` and `api_lib.c:252` (`netconn_peer`) |

---

## Full reasoning — non-VERIFIED verdicts

### RIPTOPL-443 — REFUTED (caller guard defeats the claimed consequence)

The finding's arithmetic is correct and was re-derived, not trusted:

- `FIDs` is declared `u16 FIDs[ISO_MAX_PARTS]` in the shared macro at `modules/iopcore/common/cdvd_config.h:71`, used by all three variants.
- All three `smb_CloseAll` bodies are identical and at the cited lines (`smb.c:1154-1165`, `smb2.c:1132-1143`, `nfs.c:341-352`): `fd` is a plain `int`, `fd = FIDs[i]` zero-extends, `FIDs[i] = -1` stores 65535, and on a hypothetical second call `fd = 65535` passes `fd >= 0`. In isolation, `smb_CloseAll` is indeed not idempotent. SMB2/NFS `smb_Close` would return `-EBADF` for 65535 (`smb2.c:957`, `nfs.c:286`); SMB1 `smb_Close` (`smb.c:823`, FID truncated to `u16` at `:840`) would send a CLOSE.

The claimed trigger, however, does not exist in-tree. The finding states a second `smb_CloseAll` happens because "DeviceUnmount runs at shutdown and again via DeviceDeinit for SMB". Re-reading the only caller chain:

- `smb_CloseAll` has exactly one caller: `DeviceUnmount` in `modules/iopcore/cdvdman/device-smb.c:163-169`.
- `DeviceUnmount` guards it: `:165` `if (smb_mount_state == 1) smb_CloseAll();`, then unconditionally `:168` `smb_mount_state = -1;`.
- `DeviceDeinit` (`device-smb.c:81-84`) does nothing but call that same guarded `DeviceUnmount`. The two entry points the finding cites — `oplShutdown` (`cdvdman.c:287`) and `_shutdown` → `DeviceDeinit` (`cdvdman.c:1230`) — therefore cannot both reach `smb_CloseAll`: whichever runs second sees `smb_mount_state == -1` and skips it.
- No path resets the state in a way that re-exposes the sentinel values: `smb_mount_state` returns to `1` only in `DeviceFSInit` (`device-smb.c:147`), which first re-opens the image files and overwrites `FIDs[]` via `smb_OpenAndX` (`device-smb.c:128`, `:140`); it returns to `0` only in `DeviceInit` (`:77`, fresh IOP init).

So the double-close-on-shutdown consequence — SMB1 CLOSE requests for FID 65535, repeated closes in SMB2/NFS — is defeated by a precondition in the sole caller. The u16/sentinel mismatch is a latent non-idempotence inside `smb_CloseAll` itself, but as filed (a live shutdown bug in all three copies) the finding is refuted.

### RIPTOPL-449 — VERIFIED-DRIFT (secondary citation off by 6 lines)

Mechanism re-derived from `modules/iopcore/cdvdman/ncmd.c:156-158`:

```c
u8 dual = 0;
if ((!(cdvdman_settings.common.flags & IOPCORE_COMPAT_EMU_DVDDL)) || (cdvdman_settings.common.layer1_start > 0))
    dual = 1;
```

Truth table: EMU_DVDDL clear + `layer1_start == 0` (ordinary single-layer disc) → `dual = 1`, so the TOC takes the dual-layer bytes at `:162` (`0x24`), `:167-168` (`0x41`/`0x95`) and `:174` (`0x21`). The contrast function is as cited: `sceCdReadDvdDualInfo` (`scmd.c:181-193`) derives `on_dual` from `layer1_start > 0` when EMU_DVDDL is clear (`:189`) and forces `on_dual = 1` under EMU_DVDDL (`:186`) — note the filed condition is also inverted for the EMU-on/`layer1_start == 0` case (TOC says single, DualInfo says dual), which strengthens rather than weakens the mechanism.

Drift: the finding cites "`maxlsn` at :185". The `maxlsn` computation is at `ncmd.c:179` (`u32 maxlsn = (layer1_start ? layer1_start : mediaLsnCount) + (0x30000 - 1);`); `:185` is a blank line after the `break` at `:184`. Primary location `:156-158` is exact. Corrected line: **ncmd.c:179**.

### RIPTOPL-451 — VERIFIED-DRIFT (allocator citation off by ~11 lines)

Mechanism re-derived:

- `tcp_keepalive` (`modules/network/SMSTCPIP/tcp_out.c:530-568`) sets src/dest/seqno/ackno/wnd/urgp (`:549-554`) and `TCPH_HDRLEN_SET(tcphdr, 5)` (`:555`), then checksums and sends (`:557-563`). No `TCPH_FLAGS_SET` anywhere in the function.
- `TCPH_HDRLEN_SET` (`include/lwip/tcp.h:204`) is `htons(((len) << 12) | TCPH_FLAGS(phdr))` — it explicitly preserves whatever flags bits are already in the word, so the flags byte goes on the wire uninitialised.
- All three cited sibling constructors do set flags, at the exact cited lines: `tcp_out.c:220` (`tcp_enqueue`), `:360` (`tcp_output` ACK path), `:485` (`tcp_rst`).
- The pbuf is `pbuf_alloc(PBUF_IP, TCP_HLEN, PBUF_RAM)` (`tcp_out.c:541`); the PBUF_RAM path (`pbuf.c:307-309`) uses `mem_malloc` with no zeroing, and with `MEM_LIBC_MALLOC 1` (`include/lwipopts.h:23`) that is unzeroed `AllocSysMemory` memory.
- Reachability holds: `tcp.c:627-637` calls `tcp_keepalive` for `SOF_KEEPALIVE` pcbs past the keepalive interval, and `SO_KEEPALIVE` is settable via `lwip_setsockopt` (`sockets.c:1307-1315`, `so_options |= optname`; `SO_KEEPALIVE` and `SOF_KEEPALIVE` are both `0x0008`).

Drift: the finding cites the allocator as "`AllocSysMemory` output (ps2ip.c:524-533)". Lines 524-533 of `ps2ip.c` are the end of `sys_arch_sem_wait` and `sys_sem_free`. The `MEM_LIBC_MALLOC` wrapper is `ps2ip_mem_malloc` at **`ps2ip.c:535-545`**, with the `AllocSysMemory(ALLOC_LAST, size, NULL)` call at **`:541`**. Primary location `tcp_out.c:530-570` is exact.

---

## New defect candidates

None. Two candidate-shaped observations were examined and rejected, and are recorded here only to show they were checked:

- `smb_lseek64`'s SEEK_END case (`smb_fio.c:854-856`) discards its offset entirely — not new: already filed as RIPTOPL-085 (Round 4), whose part (2) also substantially duplicates RIPTOPL-444's SET/CUR mechanism.
- `netconn_addr` (`api_lib.c:261-281`) dereferences `conn->pcb.tcp` (and udp/raw) with no NULL guard and no `conn == NULL` check — not filed as a candidate because its only in-tree caller, `lwip_getsockname`, guards `pcb.tcp == NULL` first (`sockets.c:949-953`, call at `:960`), and `err_tcp` NULLs only the TCP member of the union.
