# Round 2 — Topic 4: FILE COPY / MOVE — function-level diff (READ ONLY)

**Pins (READ, `git rev-parse HEAD` in `~/workspace/audit-clones-2026-11-13/`, 2026-11-14):**
RiptOPL `2e347d5ac885` · Launchstation `9fb0598a79f0` · Simple-Media-System (SMS) `e65ced39a27e` · POPSLoader `29272cddbf01`.
Labels: **READ** = seen in source at the cited `path:line` at the pin above. **INFERRED** = arithmetic / consequence drawn from READ code, not a code statement. No hardware was run; no throughput claim is made anywhere in this section.

**Premise corrections to the task brief (READ):**

1. RiptOPL's file manager calls **no** copy helper from `src/sources/supportbase.cpp` / `src/platform/util.cpp` — `src/core/filemgr.cpp` is self-contained POSIX (`open/read/write`, filemgr.cpp:32–40 includes). The second, independent copy loop in the same repo is `vcdSafeCopyFile` in `src/sources/vcdsupport.cpp` (BDMA/SMB module staging onto `mc?:/POPSTARTER/`), which is the real intra-repo duplicate. A third adjacent path, `src/core/vmcsaves.cpp` (PSU pack/unpack, used by the file manager's Paste-as-PSU branch, `src/ui/guifilemgr.cpp:448,452`), is **not** a streaming copy: it mallocs each whole save file (`vmcsaves.cpp:478,829` `f->data = malloc(f->size…)`) and moves VMC images in `0x10000` = 64 KB chunks (`vmcsaves.cpp:150,163`). Excluded from the volume count, flagged in §6.
2. POPSLoader has **no file-browser copy/paste at all** and no copy function in `bin/POPSLDR/ui.lua` (grep `copyFile|fileCopy|CopyFile` over `bin/POPSLDR/*.lua` + `src/*.cpp`: the only hits are in `system.lua` / `luasystem.cpp`). Its copies are single-file, internal staging operations (BDMA/SMB IRX equip, settings saves). The Lua implementation lives in `bin/POPSLDR/system.lua`; the C implementation is the `System.rename` engine in `src/luasystem.cpp`.
3. SMS pass-1 SMS-017 ("allocates 384 KB twice") **re-verified at `e65ced39a27e`, with a precision fix**: there are two allocation *sites* for the same 384 KB (`src/SMS_CopyTree.c:211` and `:314`), but they are alternatives, never both live for one file — see §4. The simultaneous-allocation problem is actually worse than pass 1 stated, for a different reason (source-side stream buffers, §4).

---

## 1. RiptOPL — two implementations, opposite temperaments

### 1a. File-manager copy — `src/core/filemgr.cpp` (636 lines, whole file)

| Aspect | Finding |
|---|---|
| Functions | `fmCopyFile` static, filemgr.cpp:315–372 (58 lines); `fmCopyTree` :390–413 (24); `fmCopyTo` :435–449 (15, allocates buffer + computes tree size); `fmCopy` :453–466 (14, public); `fmCopyThenDelete` :564–573 + `fmMove` :575–585 (23); `fmDeleteTree` :479–509 (cleanup engine, reused by copy-failure path) |
| **Buffer size** | **`FM_BUF (64 * 1024)` = 65,536 B — filemgr.cpp:46.** One heap allocation per top-level operation (`malloc(FM_BUF)`, :440), passed down the whole tree recursion — never per-file, never per-level. |
| Loop shape | `while ((r = read(in, buf, FM_BUF)) > 0)` (:339) with an inner partial-write loop `while (off < r && (w = write(...)) > 0) off += w;` (:341–342) — a short write is retried, not fatal. |
| Error mid-copy | Short/failed write → `ok=0` (:343–347); read error `r<0` → `ok=0` (:353–356). **Partial file is deleted**: `if (!ok) remove(dst);` (:369–370). At tree level, `fmCopy` deletes the entire partial destination tree on any failure (`fmDeleteTree(dst,…)`, :460–464), safe because `fmTarget` (:424–433) refused any pre-existing destination (`O_EXCL` open, :333, closes the race). |
| Verify | **Size re-read per file — the strongest cheap verify of the four repos.** After close, dest is reopened and `fmSeekEnd` compared against both bytes copied and source size (:359–368); mismatch → `FM_ERR_WRITE` + `remove(dst)`. Size only — no content/hash check (READ). |
| Cross-device move | Same-device (`fmSameDevice`, :511–520, compares device prefix before `:`) → rename first (`fmMove` :582, incl. mcserv rename for cards, `fmMcRename` :525–545). Otherwise copy+delete, source deleted **only** after the whole verified copy (`fmCopyThenDelete` :564–573). |
| Recursion | Self-recursion in `fmCopyTree`; depth cap `FM_DEPTH 16` (`include/filemgr.h:29`); per-level heap listing via `fmChildren` (:225–248, cap grows 64→×4), freed when the level returns (:411). Folder-into-itself refused (`fmUnder` :416–422 via `fmTarget`). |
| Progress / UI pump | Callback per chunk: `fmProgress(fmBaseName(src), fmDone, fmTotal)` (:350–351) → `fmProgressShow` in `src/ui/guifilemgr.cpp:349–358`, throttled to one redraw per percent (`guiRenderTextScreen`). **No cancel/pad check exists anywhere in the copy path (READ by absence)** — a long copy cannot be aborted. |
| Timestamps / attrs | **None.** No `chstat`, `mcSetFileInfo`, `utime` or mode copy anywhere in filemgr.cpp (READ by grep over the file). Dest is created `0666` (:333). A copied save folder loses its MC timestamps/attributes — cosmetic on most devices, visible in the PS2 browser for MC saves. |
| Pre-checks | `fmRoomFor` (:288–313): for `mass*:` destinations only — refuses >4 GB on non-exFAT FAT (`size > 0xFFFFFFFF`) and checks free clusters × cluster bytes via `fileXioDevctl(BDM_DEVCTL_VOLINFO)`. Other destinations: no free-space pre-check. |
| Defect (own) | **`close()` returns unchecked** (:357–358: `close(out); close(in);`). A flush-on-close failure escapes the write loop; the size re-read (:359–368) catches a *short* file but not a right-size/corrupt one. Contrast §1b in the same repo, which does check close. |

### 1b. Module-staging copy — `vcdSafeCopyFile`, `src/sources/vcdsupport.cpp:1110–1178` (69 lines)

| Aspect | Finding |
|---|---|
| **Buffer size** | **`VCD_COPY_CHUNK (16 * 1024)` = 16,384 B — vcdsupport.cpp:1081** (heap, per call, `malloc` :1142). Smallest buffer of any implementation in this topic. |
| Loop shape | Same shape as §1a: `read` loop (:1155) + inner partial-write retry loop (:1157–1164, `w <= 0` → fail). |
| Error mid-copy | Any failure → **`unlink(dstPath)`** (:1175–1176, comment: "never leave a truncated module/config behind"). |
| Verify | **None.** No size re-read — counted writes + a **checked close** (`if (close(dfd) < 0) rc = -3;` :1171–1172) are the whole assurance. Direct divergence from §1a in the same repo: §1a verifies size but not close; §1b verifies close but not size. |
| Pre-check | MC-only free-space gate before opening dest: `vcdMcHasSpace` (:1099–1105) requires free ≥ size + `VCD_COPY_MARGIN (16*1024)` (:1080). Source size via `SEEK_END`, with an MMCE fallback to size 0 = gate passes (:1119–1134). |
| Move / recursion / progress / timestamps | Not applicable / none: flat single files, no tree, no progress callback (callers are settings-change handlers), no timestamp preservation. Dest opened `O_TRUNC` (:1147) — overwrites in place, unlike §1a's `O_EXCL` no-overwrite rule. |

---

## 2. Launchstation — one 967-line function that does everything

### `copy()` — `src/filer_copy.c:752–1718` (967 lines; folder + file + PSU backup + PSU restore in one frame)

Supporting pieces: `copyChunkIo`/`copyChunkRun` filer_copy.c:67–83 (17); `copyBufferSize` :90–117 (28); Move manifest :121–270 (150); `verifyUdpfsCopy` :718–735 (18); paste driver `subfunc_Paste` `src/filer_browser.c:2147–2277`; `delete()` `src/filer_actions.c:1944–2047`; `Rename()` filer_actions.c:2153–2187.

| Aspect | Finding |
|---|---|
| **Buffer size** | **Device-dependent, `copyBufferSize` filer_copy.c:90–117.** Default **`COPY_BUFFER_FAST_DEFAULT 0x100000` = 1,048,576 B (1 MB)** (:32, :92); dest `mc`/`mass`/`vmc`/PC-CF → **131,072 (128 KB)** (:95); dest MX4SIO → 131,072 (:99); source `mc` → **262,144 (256 KB)** (:102); dest `host` → **393,216 (384 KB)** (:105); source `mass`/`host`/CF/MX4SIO → **524,288 (512 KB)** (:112); clamped to file size (:114–115). PSU-restore files reuse a buffer reserved by the folder level, sized by the same function (:1030–1031, :1412–1415). |
| Double buffering | When `buffSize == COPY_BUFFER_FAST_DEFAULT` (the 1 MB case), a **second** 1 MB buffer is attempted (`memalign(64, buffSize)` :1427–1429) and chunks alternate (`buffIndex ^= 1` :1591–1592). **Fast→fast copy therefore holds 2 MB of EE heap in copy buffers alone (INFERRED arithmetic from READ :1417 + :1428).** Allocation failure of `buff2` silently degrades to single-buffer (:1429–1435). |
| IOP-side buffer | A paste widens fileXio's IOP RW buffer from the SDK 16 KB to 128 KB for the duration (`setFileXioTransferWide(1)`, filer_browser.c:2188; `src/init.c:1282–1297`, sizes {128 KB, 64 KB, 16 KB} fallback ladder) and restores it after (:2235). The only IOP-RAM cost in this topic, and the only one that is explicitly borrowed-and-returned. |
| Loop shape | **Single-shot chunk semantics — the opposite of RiptOPL.** `copyChunkIo` (:67–76): one `genRead`, then one `genWrite` **only if `read == size` exactly** (:72). Caller demands `bytesRead == buffSize && bytesWritten == buffSize` (:1574); anything else is an error. No partial-write retry exists. This is safe only because the file branch pre-measures the source (`SEEK_END` :1342) and clamps `buffSize` to the remaining bytes each iteration (:1451–1452): a short transfer therefore always means error/shrink, never a legal EOF. |
| Error mid-copy (file) | Chunk error → `genClose(out_fd); genRemove(out);` (:1580–1586) — **partial file deleted**. User cancel (pad + `ynDialog`, :1542–1556) → same removal (:1547–1550). Buffer-alloc failure → same removal (:1420–1425). |
| Error mid-copy (folder) | **Partial tree is left.** A failing child breaks the loop (:1163–1171); the folder level then returns −1 at :1193–1196 with **no delete of the destination folder or already-copied siblings** (the only cleanup there is the PSU-backup discard, :1194–1195). `subfunc_Paste` likewise breaks on the first failed item (filer_browser.c:2209–2213), leaving earlier items in place. See FC-BUG-2. |
| Verify | General path: **none** — exact chunk equality is the assurance. Two exceptions (READ): (a) `udpfs:` destinations are size-re-read after close, `verifyUdpfsCopy` (:718–735, called :1633–1634), wrong size → `genRemove`; the comment (:712–717) explains the UDPFS stale-handle failure this defends against. (b) PSU-backup to `udpfs:` is verified the same way (:1220–1223). Folder completeness is verified on the *source* side: after copying children, the source folder is re-listed and a FNV-1a name-sum compared (:1176–1186, `listingSum` :326–338) — this protects Move, not the destination bytes. |
| Cross-device move | **Always copy+delete — there is no rename fast path in the paste path (READ).** `subfunc_Paste` calls `copy()` for cut items exactly as for copied items (filer_browser.c:2207–2208); deletion is deferred to `filerMoveFinish()` (filer_copy.c:226–270) after **all** items succeed (:2218–2229): every recorded source is re-statted and must match the manifest's size/mode/ctime/mtime (`moveEntryMatches` :214–224) before anything is removed, then entries are deleted in reverse (postorder) with a post-delete `genGetStat == -ENOENT` confirmation (:262–265). Same-device move of a 4 GB file pays a full 4 GB copy — RiptOPL (§1a) renames it. `Rename()` (filer_actions.c:2153–2187) is a separate sibling-only, no-replace operation and is never used by Move. |
| Recursion | `copy()` calls itself per child (:1133, :1164); cap `MAX_RECURSE 16` (`include/filer_shared.h:40`; enforced :797–798). **Each folder level heap-allocates a `MAX_ENTRY` listing** (:915, `memalign(64, MAX_ENTRY * sizeof(FILEINFO))`) held across its recursive calls and freed after (:1189); the file's own comment prices that listing at "about 900 KB" (:744–745). Worst-case live listings at depth 16 ≈ 14 MB (INFERRED arithmetic; real trees are shallower, but nothing in the code bounds the product). |
| Progress / UI pump | **Best of the four.** Per chunk the loop builds speed/ETA/remaining text (:1482–1531, `TRANSFER_ETA_UPDATE_MS 1000` :31) and, on the dashboard, hands the chunk I/O to a worker: `DashFileTransferChunk(copyChunkRun, &chunk)` (:1562–1563) → `src/dash_ui.c:1436–1450` submits the chunk and pumps `loadingDraw()` frames until it completes ("a 128 KB chunk takes seconds on a memory card, and the progress screen keeps animating meanwhile", filer_copy.c:78–79). Legacy fallback draws synchronously (`nonDialog`/`drawMsg` :1534–1540). Pad is polled per chunk for cancel (:1542–1556). UI does **not** freeze. |
| Timestamps / attrs | **Full preservation — the only repo that does it.** File branch: to `mc:` via `mcSetFileInfo` full table or attribute-only for host/udpfs sources (:1639–1659); to `vmc:`/xfrom via their equivalents (:1660–1667); to other devices via `fileXioChStat` with ctime+atime+mtime copied from the source entry (:1679–1690) — explicitly skipped for `host:`/`udpfs:`/`smb:`/`mmce:`/`mass:`/`mx4sio:`/`ata:`/CF destinations (:1669–1678). Folder branch repeats the same matrix for the folder itself (:1225–1275). MC folder/file attributes are normalized when the source is not card-like (`MC_ATTR_norm_file 0x8497` / `MC_ATTR_norm_folder 0x8427`, :1639–1643, :1226–1230). |
| Overwrite policy | File dest is **deleted before creation** (`genRemove(out)`, :1382, comment "Upstream: remove the old file…") then opened `O_TRUNC|O_CREAT` (:1383) — a paste silently replaces an existing file (folders ask via the name-conflict dialog, :1049–1089). Opposite of RiptOPL §1a's never-overwrite rule. |
| Close handling | `genClose` result **is** checked (:1621–1636) — but see FC-BUG-1: the failure path forgets to remove the file. |

---

## 3. POPSLoader — no browser copy; two small single-file engines

### 3a. C engine — `copy_file_contents`, `src/luasystem.cpp:826–854` (29 lines), exposed only through `System.rename` (`lua_rename` :865–877)

| Aspect | Finding |
|---|---|
| **Buffer size** | **`char buf[BUFSIZ]` — luasystem.cpp:828, used :839. Stack, not heap.** The numeric value is **not defined anywhere in the repo** (READ: grep `BUFSIZ` over the repo returns only :828/:839); it comes from `<stdio.h>` in the PS2SDK/newlib toolchain. INFERRED: newlib's default `BUFSIZ` is 1024 B — labelled inferred because no in-repo source pins it. Either way it is 16–64× smaller than RiptOPL's chunk and ~1000× smaller than Launchstation's fast path, and `System.rename` of a large file pays one syscall pair per `BUFSIZ`. |
| Loop shape | `while ((size = read(source, buf, BUFSIZ)) > 0)` (:839); **single** `write` per read; `wrote < size` → fail (:840–845). No partial-write retry (same single-shot family as Launchstation, without Launchstation's pre-measured-size justification). |
| Error mid-copy | **Partial file is left, and the previous destination is already destroyed.** Dest is opened `O_WRONLY|O_CREAT|O_TRUNC` (:833) before any byte succeeds; every failure path (:834–836, :841–845, :850–852) only closes and returns −1 — **no `unlink` anywhere in the function (READ)**. A failed `System.rename` therefore leaves a truncated file at the *new* name, and if that name already held a file, the original is gone. `lua_rename` (:872–874) at least does not delete the source on copy failure. |
| Verify / close | **None, and `close()` returns unchecked** (:848–849). No size re-read, no close check: a flush failure at close is reported to Lua as a successful rename, after which `remove(oldName)` (:874) deletes the only good copy. See FC-BUG-3. |
| Move semantics | `System.rename` **is** copy+delete, unconditionally (:872–874) — same-device, same-folder renames included. There is no native `rename(2)` attempt anywhere in the binding (READ). |

### 3b. Lua engine — `CopyExternalAtomicBounded`, `bin/POPSLDR/system.lua:5312–5410` (99 lines), with `PromoteTmpToDest` :5234–5259 (26) and siblings `WriteAtomic` :5261–5291, `WriteBytesDirectBounded` :5421–5459, `WriteBytesAtomicBounded` :5461–5509

| Aspect | Finding |
|---|---|
| **Buffer size** | **32,768 B (32 KB) chunks** — the read call `System.readFile, src_fd, 32768` (system.lua:5359); the same 32,768 literal chunks `WriteAtomic` (:5273), `WriteBytesDirectBounded` (:5439) and `WriteBytesAtomicBounded` (:5484). Each chunk transits C as a fresh heap allocation + Lua string (`lua_readfile` mallocs `size+1`, src/luasystem.cpp:953–964), so the 32 KB chunk costs at least two copies in EE RAM (INFERRED from READ luasystem.cpp:955–963). |
| Loop shape | Bounded loop: `MAX_ITERS 4096` (:5342), byte ceiling `expected + 65536` (:5343). Per chunk, `System.writeFile` result must be a number, `> 0`, and **exactly `chunk_len`** (:5369–5387) — a short write fails the copy rather than resuming (the C `lua_writefile` returns raw `write()` count, luasystem.cpp:978–980, and the Lua side treats anything partial as fatal). |
| Error mid-copy | **Partial is deleted**: copy goes to `dest..".tmp"` (:5313); any failure → `pcall(System.removeFile, tmp)` (:5401–5403), dest untouched. Promotion is `PromoteTmpToDest` (:5234–5259): existing dest is first renamed to `dest..".bak"` and the promotion is refused if the backup does not materialize (:5237–5249); on promotion failure dest is removed and the `.bak` restored (:5250–5256). Because promotion itself runs on §3a's copy+delete rename, a "rename" here is up to three full copies of the payload (INFERRED from READ :5239 comment, which says exactly this for memory cards). |
| Verify | **Counted-bytes equality**: after the loop, `copied_bytes < expected` → fail (:5397–5399), where `expected` is the caller-supplied size or `System.sizeFile` on the source (:5323–5331). **No destination re-read** — a write that returns full count but lands corrupt passes. Note the asymmetry with §3a: the Lua layer re-implements, above a C rename it does not trust, every protection (tmp file, backup, byte count, cleanup) that §3a lacks. |
| Recursion / move / progress / timestamps | No directory copy anywhere (flat module/config files only; callers :7959, :8314, :8548 stage fixed file lists). No cross-device "move" concept. **No progress or yield inside the copy (READ by absence, :5348–5392)** — staging runs synchronously inside settings/launch flows, so the UI freezes for the duration (INFERRED). No timestamp preservation. No destination free-space pre-check despite knowing `expected` (READ by absence). |

---

## 4. Simple-Media-System — copy-to-HDD only, 384 KB, partials left behind

### `SMS_CopyFile`, `src/SMS_CopyTree.c:298–387` (90 lines); `SMS_CopyTree`, :145–238 (94); callbacks `CalcSizeCB`/`MakeTreeCB`/`CopyFileCB`/`_make_path` :74–143

Callers (READ): single file — `src/SMS_GUIFileCtxMenu.c:102` (return value **ignored**); tree — `SMS_GUIFileCtxMenu.c:117`. Destination is **always the HDD working directory** `g_HDDWD` (SMS_CopyTree.c:171–184; SMS_GUIFileCtxMenu.c:92–99). There is no copy to MC/USB/SMB, no move, and no rename: "move" in SMS is a manual copy (this section) followed by a separate `SMS_DeleteTree` (:250–290).

| Aspect | Finding |
|---|---|
| **Buffer size** | **`BUF_SIZE (4096 * 96)` = 393,216 B (384 KB) — SMS_CopyTree.c:31.** Two allocation *sites*: tree path allocates once in `SMS_CopyTree` (`malloc(BUF_SIZE)` :211) and passes it down as `apBuf`; single-file path passes `NULL`, so `SMS_CopyFile` allocates its own (`malloc(BUF_SIZE)` :314, freed :369). **SMS-017 re-verified with correction: the two sites are mutually exclusive per copy — pass 1's "twice" is two sites, not two simultaneous buffers.** |
| Hidden second allocation | The *source* side quietly matches it: `SMS_CopyFile` calls `apFile->Stream(apFile, 0, 96)` (:333), and `STIO_Stream` turns 96 blocks into `File_AllocStreamBuffers(apCtx, 96*4096, 2)` (`src/SMS_FileContext.c:1875`), which memaligns **two buffers of 393,216 B each** (FileContext.c:603–625: `lAllocSize = aSize`, one allocation per buffer). **A single SMS copy therefore holds ≈ 384 KB (dest) + 2 × 384 KB (source stream) ≈ 1.125 MB of EE heap (INFERRED arithmetic from READ sites)** — before the DirTree itself. No comment anywhere ties 96 pages to a device requirement (READ by absence at :31). |
| Loop shape | `while (1)`: `lnRead = apFile->Read(apFile, lpBuf, BUF_SIZE)` (:338); `lnRead <= 0` breaks (:340) — **read error and EOF are the same exit (READ)**. Write is a single `fioWrite(lFD, lpBuf, lnRead)` (:342); `< 0` fails immediately; a short *positive* write is caught only after the progress/pad block by `fioSync(FIO_WAIT, &lnWrite); if (lnWrite != lnRead) goto error;` (:363–365). No partial-write resume. |
| Error mid-copy | **Partial file is never deleted — in any path.** `SMS_CopyFile` contains no `fioRemove` (READ over :298–387): write error → `retVal = 3` (:371–372), user cancel → `retVal = 2` (:357–361), read error → silently treated as EOF (above) — all fall through to `fioClose(lFD)` (:377) leaving the truncated destination in place, indistinguishable from a complete file except by size. Tree level: `CopyFileCB` stores the code in `apTree->m_Error` (:133–135) and the walk stops (`SMS_DirTreeWalk` bails on `m_Error`, `src/SMS_DirTree.c:175,222`), but already-copied siblings and the partial file stay; `SMS_CopyTree` maps `m_Error == 3` to the *not-enough-space* message (:219–233) whatever the real cause, and a cancel (`2`) matches neither the `==1` nor `==3` branch, so a cancelled tree copy exits with **no error shown at all** (READ :219–238). Single-file caller ignores the return entirely (SMS_GUIFileCtxMenu.c:102). See FC-BUG-4. |
| Verify | Per-chunk only: the `fioSync` count check (:363–365). **No post-copy size re-read** of the destination against the source (READ by absence) — combined with read-error-as-EOF, a truncated copy can return success (`retVal` stays 0). |
| Recursion shape | Not recursion inside the copy: `SMS_DirTreeScan` materializes the whole tree in memory first (:158), then `SMS_DirTreeWalk` (`src/SMS_DirTree.c:164–232`, self-recursive at :224) is run **three separate times** — `CalcSizeCB` (:189), `MakeTreeCB` (:206, creates all dirs via `fioMkdir`), `CopyFileCB` (:216). All destination directories are created before the first file byte moves. **No depth cap found** in SMS_CopyTree.c / SMS_DirTree.c (READ by absence); depth is bounded only by the scanned tree fitting in RAM. |
| Progress / UI pump | Per chunk: `GUI_Progress(status, percent, 1)` with forced update (:352–353; renderer `src/SMS_GUIDesktop.c:920`) plus a pad poll for Triangle/RC-stop cancel (:354–361). During scan, `DirCB` does `GS_VSync(); GUI_Status(…)` per directory (SMS_CopyTree.c:48–58). The GUI clock is suspended for the tree's file phase (`SMS_GUIClockSuspend/Resume` :215–217). UI does not freeze, but note the cancel check sits *before* the `fioSync` short-write check (:357 vs :363) — a cancel on the final chunk skips the write verification for that chunk (harmless only because the partial is kept anyway). |
| Timestamps / attrs | **None** (READ by absence in SMS_CopyFile/SMS_CopyTree). |
| Pre-check | Tree path only: PFS zone free space vs sector-rounded total size before creating anything (`SMS_IOCtl(PFS_IOCTL_GET_ZONE_FREE/GET_ZONE_SIZE)` :191–199, `lZoneFree > m_TotalSize` gate). Single-file `SMS_CopyFile` has no pre-check. This is the only HDD-space gate in the topic, and it exists because the destination device is fixed. |

---

## 5. Comparison table (all values READ at the pins unless marked INFERRED)

| Dimension | RiptOPL filemgr (§1a) | RiptOPL vcd (§1b) | Launchstation `copy()` | POPSLoader C rename (§3a) | POPSLoader Lua (§3b) | SMS (§4) |
|---|---|---|---|---|---|---|
| Location | `src/core/filemgr.cpp:315–372` | `src/sources/vcdsupport.cpp:1110–1178` | `src/filer_copy.c:752–1718` | `src/luasystem.cpp:826–854` | `bin/POPSLDR/system.lua:5312–5410` | `src/SMS_CopyTree.c:298–387` |
| **Copy buffer** | **65,536 B** (`FM_BUF`, filemgr.cpp:46) | **16,384 B** (`VCD_COPY_CHUNK`, vcdsupport.cpp:1081) | **131,072–1,048,576 B** by device (`copyBufferSize` filer_copy.c:90–117); ×2 buffers at 1 MB | **`BUFSIZ`, stack** (luasystem.cpp:828; value not in repo, INFERRED 1024) | **32,768 B** chunks (system.lua:5359) | **393,216 B** (`BUF_SIZE`, SMS_CopyTree.c:31) + 2×393,216 B source stream buffers |
| Buffer allocation | 1× heap per operation, shared by tree | 1× heap per file | 1–2× `memalign(64)` per file + 128 KB IOP fileXio widening during paste | stack | per-chunk heap in C binding | 1× heap per tree (or per file) |
| Partial-write handling | retry loop | retry loop | fail (single-shot, size pre-measured) | fail (single-shot) | fail (exact-count demanded) | fail via post-hoc `fioSync` count |
| Partial file on error | **deleted** (+ whole partial tree) | **deleted** (`unlink`) | file: **deleted**; folder tree: **left** | **left** (and prior dest already truncated) | **deleted** (`.tmp` removed; dest never touched) | **left** (all paths incl. cancel) |
| Post-copy verify | **dest size re-read vs source** | none (close checked) | none, except `udpfs:` size re-read | none (close unchecked) | counted bytes vs expected; no dest re-read | none (per-chunk sync count only) |
| Close checked | no | **yes** | yes (but see FC-BUG-1) | no | via `pcall(closeFile)` result ignored (READ :5394–5395) | `fioClose` result ignored (:377) |
| Same-device move | **rename** | n/a | full copy + manifest-verified delete | copy+delete (it *is* rename) | n/a (promotion = §3a rename) | no move exists |
| Cross-device move | copy, delete after verified copy | n/a | copy all items, delete after re-stat of every source | n/a | n/a | manual copy + separate delete |
| Recursion / depth cap | recursive, cap 16 | flat | recursive, cap 16, ~900 KB listing/level | flat | flat | pre-scanned tree, 3 walks, **no cap found** |
| Progress / cancel | per-chunk %, throttled redraw; **no cancel** | none | per-chunk speed/ETA, **worker-thread chunk I/O, UI animates, pad cancel** | none | none (UI frozen, INFERRED) | per-chunk `GUI_Progress` + pad cancel |
| Timestamps/attrs | none | none | **full matrix (MC/VMC/XFROM/ChStat)** | none | none | none |
| Overwrite policy | **never** (`O_EXCL`) | overwrite (`O_TRUNC`) | delete-then-create (file); ask (folder) | truncates dest | tmp + `.bak` promotion | overwrite (`O_TRUNC`, :307) |
| Free-space pre-check | `mass:` only (FAT 4 GB + clusters) | MC only (+16 KB margin) | none in `copy()` | none | none | tree→HDD only (PFS zones) |

---

## 6. Duplicated-code volume (counting method stated, arithmetic INFERRED from READ ranges)

**Narrow count** — the single-file loop function(s) only (open → loop → close → verify/cleanup):

| Repo | Components | Lines |
|---|---|---|
| RiptOPL | `fmCopyFile` 58 + `vcdSafeCopyFile` 69 | 127 |
| Launchstation | file branch of `copy()` (filer_copy.c:1302–1718) 417 + `copyChunkIo/Run` 17 | 434 |
| SMS | `SMS_CopyFile` 90 | 90 |
| POPSLoader | `copy_file_contents` 29 + `CopyExternalAtomicBounded` 99 | 128 |
| **Total narrow** | | **≈ 779 lines** |

**Full-subsystem count** — loop + tree recursion + move/delete glue + buffer policy + verify helpers:

| Repo | Components | Lines |
|---|---|---|
| RiptOPL | `fmCopyFile` 58 + `fmCopyTree` 24 + `fmCopyTo` 15 + `fmCopy` 14 + `fmCopyThenDelete`/`fmMove` 23 + `vcdSafeCopyFile` 69 | 203 |
| Launchstation | `copy()` 967 + `copyChunkIo/Run` 17 + `copyBufferSize` 28 + Move manifest 150 + `verifyUdpfsCopy` 18 | 1,180 |
| SMS | `SMS_CopyFile` 90 + `SMS_CopyTree` 94 + tree callbacks ≈ 62 | 246 |
| POPSLoader | `copy_file_contents` 29 + `lua_rename` 13 + `CopyExternalAtomicBounded` 99 + `PromoteTmpToDest` 26 | 167 |
| **Total full** | | **≈ 1,796 lines** |

That is **six independent read/write loop implementations across four repos** (two each in RiptOPL and POPSLoader), plus Launchstation's PSU pseudo-filesystem reusing the same `copy()` frame. Adjacent and excluded: RiptOPL `vmcsaves.cpp` PSU pack/unpack (whole-file RAM staging, §0.1) and SMS's `FileContext` streaming layer (`src/SMS_FileContext.c`), which is a *player* read path the copy borrows, not a copy implementation.

---

## 7. Divergences that are bugs

- **FC-BUG-1 (Launchstation) — close-failure leaves the file.** Chunk/cancel/alloc failures all `genRemove(out)` (filer_copy.c:1547–1550, :1580–1586, :1420–1425), but a `genClose` failure or PC-CF-offline failure sets `ret < 0` at :1628–1636 and exits via `copy_file_exit` (:1696–1717), which frees buffers and closes fds but **never removes `out`** (the `udpfs:` sub-case is saved only because `verifyUdpfsCopy` removes its own file, :733). A file whose final flush failed stays at the destination looking complete. One `genRemove` on the non-PSU exit path, gated on `ret < 0`, closes it.
- **FC-BUG-2 (Launchstation) — folder failure leaves a partial tree.** File-level cleanup (above) has no folder analogue: :1193–1196 returns the error with the destination folder and all already-copied children in place, and `subfunc_Paste` stops the batch (filer_browser.c:2209–2213) leaving earlier items copied. RiptOPL's `fmCopy` (:460–464) proves the alternative is cheap *when the destination is guaranteed new* — Launchstation cannot copy that trick verbatim because its file branch deliberately replaces existing files (:1382), so a rollback would need the Move-manifest treatment (record what was created) rather than a blind tree delete.
- **FC-BUG-3 (POPSLoader, C) — `System.rename` can destroy the only good copy.** `copy_file_contents` truncates the destination on open (luasystem.cpp:833), leaves partials on every failure (:841–852), never verifies size, and ignores both `close()` results (:848–849) before `lua_rename` deletes the source (:874). The Lua layer already knows this — `PromoteTmpToDest`'s header (system.lua:5229–5233) describes the failure mode and builds a `.bak` dance around it — but any present/future direct `System.rename` caller inherits the raw behaviour. The fix belongs in C (unlink-on-failure + checked close + size compare: ~10 lines, modelled on RiptOPL vcdsupport.cpp:1171–1176), after which part of the Lua scaffolding becomes redundant.
- **FC-BUG-4 (SMS) — truncated copies are indistinguishable from complete ones, and one failure class is silent.** No `fioRemove` on any error/cancel path in `SMS_CopyFile` (:298–387); read error ≡ EOF (:338–340) so a mid-stream device error returns *success* with a short file; tree cancel (`m_Error == 2`) matches no message branch in `SMS_CopyTree` (:219–238); write errors are reported to the user as "not enough space" (`== 3` branch); the single-file caller discards the result (SMS_GUIFileCtxMenu.c:102). Four small defects, one root: the function never treats its destination as untrusted until proven complete. RiptOPL §1a is the counter-model (delete-on-fail + size re-read) in 58 lines.
- **FC-BUG-5 (RiptOPL, minor) — the two in-repo copies each lack the other's check.** `fmCopyFile` verifies size but not `close()` (filemgr.cpp:357–358 vs :359–368); `vcdSafeCopyFile` verifies `close()` but not size (vcdsupport.cpp:1171–1172, no re-read). Either check alone misses a failure class the other catches. Unifying on *both* checks is a few lines in each.
- **Not bugs, recorded as divergences:** single-shot vs retry-loop write semantics (Launchstation/POPS-C fail on short write; RiptOPL retries) — each is internally consistent given Launchstation pre-measures size and RiptOPL does not trust it. Buffer sizes differ by 64× (16 KB vcd → 1 MB Launchstation fast path) with only Launchstation documenting a device rationale (filer_copy.c:85–89); SMS's 384 KB has no stated rationale at all (SMS_CopyTree.c:31). Same-device move: rename (RiptOPL) vs full copy (Launchstation, POPSLoader) — a performance divergence, not correctness.

---

## 8. LESS-NOT-MORE verdict

**Per repo — what could be deleted/consolidated:**

- **RiptOPL (203 lines, the leanest subsystem): keep both loops, merge their checklists.** `fmCopyFile` and `vcdSafeCopyFile` differ for real reasons (tree-shared buffer + `O_EXCL` + progress vs one-shot MC staging + space gate + `O_TRUNC`), so collapsing them into one function would grow a flag-soup worse than 127 lines. What *is* duplicated waste: the partial-write retry loop and the failure-cleanup idiom, twice, with divergent verify (FC-BUG-5). A single static `fmStreamCopy`-style core is *not* recommended across the two files (different translation units, different device layers — `fileXio`/POSIX vs MC-gated staging); instead, port the two missing checks (close-check into filemgr, size-re-read into vcd) and stop. Net: ~0 lines deleted, 2 failure classes closed. Honest keep-separate.
- **Launchstation (1,180 lines): the consolidation target is internal, not cross-repo.** `copy()`'s 967 lines carry four modes (normal / rename / PSU-backup / PSU-restore) in one frame with `PM_flag[]` arrays and two `goto` restarts; the folder-attribute matrix is written out **twice** (folder closure :1225–1275 ≈ file closure :1639–1690, same device ladder, same skip lists). Factoring that ladder into one `applyCopiedStats(out, in, &file, isDir)` deletes an estimated ~60–80 duplicated lines (INFERRED estimate) and removes the drift risk between the two copies. The Move manifest (150 lines) and the udpfs verify earn their keep — they are the only implementations of "delete source only if provably unchanged" and "don't trust udpfs close" in the ecosystem. Do **not** try to shrink `copyBufferSize`'s device table without hardware throughput data: it is the only buffer policy in the four repos with a stated per-device reason.
- **POPSLoader (167 lines): delete by fixing the bottom layer.** If `copy_file_contents` gained unlink-on-failure + checked close + size verify (FC-BUG-3), `PromoteTmpToDest`'s backup leg for the *promotion* step could shrink, but `WriteAtomic`'s tmp+promote pattern must stay (it protects against power loss mid-settings-save, a different threat). The three Lua `Write*Bounded` variants (:5261–5509) share the identical 32 KB chunk loop three times — one parameterized writer deletes an estimated ~50 lines (INFERRED estimate). There is no user-facing copy to consolidate; do not grow one.
- **SMS (246 lines): smallest fix list, no consolidation available or needed.** SMS has exactly one copy implementation — nothing to dedupe internally. The work is correctness, not volume: delete-destination-on-failure + distinguish read-error from EOF + surface the result at the single-file caller (FC-BUG-4), and re-justify or shrink `BUF_SIZE` (SMS_CopyTree.c:31) **with the stream-buffer multiplication in §4 counted** — at 64 KB the trio drops from ≈1.125 MB to ≈192 KB (INFERRED arithmetic). Whether 384 KB buys throughput on PFS/USB is a hardware measurement nobody has recorded; until it exists, the 384 KB is unproven cost, not proven speed.

**Cross-repo:** no shared copy library is realistic or desirable — the four sit on four different I/O stacks (RiptOPL POSIX+fileXio, Launchstation `gen*`+fileXio+mcserv, POPSLoader Lua-over-POSIX, SMS `fio*`+FileContext) and three different destination universes (any-device, any-device, HDD-only). The transferable asset is not code but the **checklist**, and the diff shows each repo holding a different subset: delete-partial (RiptOPL, POPS-Lua — missing in SMS, half-missing in Launchstation/POPS-C), size re-read (RiptOPL filemgr, Launchstation-udpfs-only), close check (Launchstation, RiptOPL-vcd), source-unchanged-before-delete (Launchstation only), timestamps (Launchstation only), free-space gate (SMS-tree, RiptOPL-partial). A one-page shared checklist in each repo's docs would have prevented FC-BUG-1…4; the code stays separate.

**Bottom line:** ≈1,796 lines of copy subsystem across four repos is not itself the waste — device layers genuinely differ. The waste is (a) Launchstation's duplicated attribute ladder (~60–80 lines), (b) POPSLoader's tripled Lua chunk loop (~50 lines), and (c) four repos re-discovering the same failure checklist independently, with SMS and POPSLoader-C still missing the delete-the-partial rule that RiptOPL states in one line: *"a cut-short copy is never left looking whole"* (`include/filemgr.h`, `fmCopy` comment).
