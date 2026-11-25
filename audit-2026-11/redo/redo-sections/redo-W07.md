# W07 — Blind Redo Audit: modules/iopcore/, modules/isofs/, modules/debug/

- Clone pin verified: `git rev-parse HEAD` = `2e347d5ac885cd0ff73e9ad4143781946396f492`
- Scope census (command-run): 115 files under the three trees; 108 text files read in full, 6 binaries + 1 licence file not read as text (see COVERAGE).
- Rule applied throughout: LESS, NOT MORE. No finding below proposes a new abstraction, framework, config option, retry, backup, or logging system.

---

## W07-001 — atad PIO transfer returns success without transferring, and its body is unreachable dead code
- **Category:** 1 dead code / 6 bugs
- **Locations:** RiptOPL/modules/iopcore/cdvdman/atad.c:470-522 (stub + unreachable body), called from RiptOPL/modules/iopcore/cdvdman/atad.c:615
- **Problem:** `ata_pio_transfer()` writes one PIO-data register byte and `return 0;` — every line after that (the real 256-word PIO in/out loops, DRQ and error checks) is unreachable. Its caller in `sceAtaWaitResult()` treats 0 as a completed transfer, so any PIO-type command (e.g. IDENTIFY, type 2 in the command table) reports success with the caller's buffer untouched. READ.
- **Fix in words:** Delete the unreachable body and keep the stub, with its comment stating PIO data transfer is unsupported and returning an error code instead of 0; or, if a PIO command is ever actually needed, restore the body. Do not keep both.
- **Benefit:** Removes ~48 misleading lines; a silent fake-success becomes an explicit error.
- **Effort:** S · **Risk:** Low (the body never executes today; only the return value changes) · **Confidence:** High (READ)

## W07-002 — Skip-Videos check reads before the path buffer for short filenames
- **Category:** 6 bugs/security
- **Locations:** RiptOPL/modules/iopcore/cdvdman/searchfile.c:215-218
- **Problem:** Under `IOPCORE_COMPAT_0_SKIP_VIDEOS`, the test is `strncmp(&cdvdman_filepath[strlen(cdvdman_filepath) - 6], ".PSS", 4)`. For any searched path shorter than 6 characters, `strlen(...) - 6` underflows (size_t) and `strncmp` reads at a wild address before the static 256-byte buffer. The path comes from the game via `sceCdSearchFile`. READ.
- **Fix in words:** Compute the length once and only do the suffix test when the length is at least 6 (the suffix being tested is 4 chars plus the assumed 2-char stem is the existing intent).
- **Benefit:** Removes an out-of-bounds read on a game-controlled string in the resident driver.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W07-003 — ZSO decompression uses the unbounded LZ4 "fast" decoder on untrusted image data
- **Category:** 6 bugs/security
- **Locations:** RiptOPL/modules/isofs/zso.c:105-112 (call at line 111); RiptOPL/modules/isofs/lz4.c:500-506 (`LZ4_decompress_fast` over the generic decoder)
- **Problem:** Each compressed block is decoded with `LZ4_decompress_fast(tmp_buf, addr, 2048)`. The fast entry point has no input length at all: a corrupt or crafted ZSO block (the block size is only clamped to 2048 before the call) makes the decoder read past the 2048-byte temp buffer and follow match offsets outside the data it was given. The image file is the untrusted input here. READ.
- **Fix in words:** Decode with a bounded variant that knows the compressed block's byte count (`b_size`, already computed in zso.c) and fails the block on malformed input, reusing the generic decoder already in lz4.c.
- **Justification (addition):** One bounded entry point into the existing generic decoder is the smallest change that gives the decoder an input limit; nothing else is added.
- **Benefit:** A bad ZSO becomes a read error instead of out-of-bounds IOP memory access.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W07-004 — BDM VMC exports dereference the block device with no NULL check
- **Category:** 6 bugs
- **Locations:** RiptOPL/modules/iopcore/cdvdman/device-bdm.c:266-310 (`g_bd->read` at line 279, `g_bd->write` at line 302); contrast RiptOPL/modules/iopcore/cdvdman/device-bdm.c:229-230
- **Problem:** `DeviceReadSectors()` checks `g_bd == NULL` and returns `SCECdErTRMOPN`, but `bdm_readSector()` / `bdm_writeSector()` (the oplutils exports MCEMU calls for VMC pages) take the semaphore and call through `g_bd` unconditionally. `g_bd` is NULL before `bdm_connect_bd()` attaches and is reset to NULL on disconnect, so a VMC access in either window is a NULL function-pointer call on the IOP. READ.
- **Fix in words:** Return 0 (transfer failed, the contract these exports already use) when `g_bd == NULL`, inside the existing semaphore, in both functions.
- **Benefit:** A mistimed VMC access fails the save instead of crashing the IOP.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W07-005 — BDM: `g_bd_sectors_per_sector` is written but never read; the sector factor is hardcoded instead
- **Category:** 1 dead code / 6 bugs (latent)
- **Locations:** RiptOPL/modules/iopcore/cdvdman/device-bdm.c:22 (declaration), :106 (only write), :234 and :244 (hardcoded `lsn * 4` / `sectors * 4`)
- **Problem:** Command-verified: the variable has exactly two occurrences — declaration and assignment `(2048 / bd->sectorSize)` at attach. Nothing reads it; `DeviceReadSectors()` always multiplies by 4, which is only correct for a 512-byte-sector device. For any attached device with a different sector size the conversion the variable was computed for is silently not applied. READ + grep census.
- **Fix in words:** Either use the stored factor in the two `bd_defrag()` calls or delete the variable and state the 512-byte assumption at the attach check (the PCCF path already enforces 512). One of the two — not both mechanisms.
- **Benefit:** Removes a write-only variable and closes a latent wrong-LBA path.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; the wrong-LBA consequence for non-512 devices is INFERRED — no such device was tested)

## W07-006 — HDD DeviceInit retries the APA header read forever
- **Category:** 6 bugs / 8 half-finished
- **Locations:** RiptOPL/modules/iopcore/cdvdman/device-hdd.c:70-73
- **Problem:** `while ((r = sceAtaDmaTransfer(...)) != 0) DelayThread(2000);` has no bound, no timeout and no exit. If the drive/APA header never reads, `_start` never finishes and the failure is an indistinguishable hang. The neighbouring drivers in the same scope all bound their waits (MMCE 10 s, UDPFS 30 s, SMB/SMB2/NFS bounded attempts — all READ in this pass). READ.
- **Fix in words:** Bound the loop with a fixed attempt count in the same style as the other device drivers and fail DeviceInit when it is exhausted.
- **Benefit:** A dead HDD surfaces as a failed init instead of a permanent silent hang.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W07-007 — HDPro transfer loop retries a failing command indefinitely
- **Category:** 6 bugs
- **Locations:** RiptOPL/modules/iopcore/cdvdman/hdpro_atad.c:692-720 (comment at line 714: "retry indefinitely until the I/O operation succeeds"; `continue` at lines 717 and 719)
- **Problem:** In `sceAtaDmaTransfer()`, if `sceAtaExecCmd()` or `sceAtaWaitResult()` keeps failing, the loop `continue`s without advancing `lba`/`nsectors` and without any retry cap — while holding `ata_io_sema`. A persistently failing device wedges all disc access forever. The non-HDPro atad.c in the same directory caps the equivalent retry at 3. READ.
- **Fix in words:** Give the loop the same bounded retry count as atad.c and return the error when it is exhausted (the semaphore release path already exists below the loop).
- **Benefit:** A failing HDPro device returns an error the game/loader can show instead of locking the driver.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W07-008 — ps2link file read trusts the host's byte count over the caller's buffer
- **Category:** 6 bugs/security
- **Locations:** RiptOPL/modules/debug/ps2link/net_fio.c:385-410 (`nbytes = ntohl(readrly->nbytes)` at line 402; `pko_recv_bytes(..., &buf[0], nbytes)` at line 408)
- **Problem:** `pko_read_file(fd, buf, length)` asks for `length` bytes, then receives however many the reply header claims (`nbytes`, host-controlled) into `buf` with no comparison against `length`. A buggy or hostile host process overflows the IOP caller's buffer. The only validation is `length < 0` on the request side. READ. (Debug module, but it runs resident on the IOP with the game's memory beside it.)
- **Fix in words:** Refuse or truncate when the reply's `nbytes` exceeds the requested `length`, before the data receive.
- **Benefit:** One comparison removes a remote-controlled IOP buffer overflow.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W07-009 — ps2link receive loop spins forever when the host closes the connection
- **Category:** 6 bugs
- **Locations:** RiptOPL/modules/debug/ps2link/net_fio.c:88-100
- **Problem:** `pko_recv_bytes()` loops `while (left > 0)`, treats only `len < 0` as an error, and does `left -= len`. A `recv()` return of 0 (orderly close) never decreases `left` and never exits — the fileio thread busy-loops forever on a disconnect. READ.
- **Fix in words:** Treat `len == 0` as end-of-stream and return an error, next to the existing `len < 0` check.
- **Benefit:** Host disconnect becomes an error return instead of a permanently spinning IOP thread.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W07-010 — ps2link exception handler dereferences a possibly-NULL module name and copies unbounded
- **Category:** 6 bugs
- **Locations:** RiptOPL/modules/debug/ps2link/excepHandler.c:55-70 (`ExceptionGetModuleName` returns 0 when no module matches), :78-92 (`strlen(module_name)` at line 80, `memcpy(buffer, frame, BUFFER_SIZE)` at line 86, `memcpy(buffer, module_name, len + 1)` at line 92)
- **Problem:** When the faulting EPC belongs to no listed module, `module_name` is NULL and `strlen(NULL)` faults inside the exception handler itself. Independently, the frame copy writes `BUFFER_SIZE` bytes starting one word into a `BUFFER_SIZE`-byte buffer, and the trailing name copy is bounded only by the name's length, not by the 128 bytes of slack the buffer size allows for it. READ.
- **Fix in words:** Substitute a fixed placeholder string when the lookup fails, and bound both copies by the space actually left in `excep_buffer`.
- **Benefit:** The crash reporter stops being a second crash source.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W07-011 — SMB1 ReadAndX carries a permanently-dead non-custom receive branch
- **Category:** 1 dead code
- **Locations:** RiptOPL/modules/iopcore/cdvdman/smb.c:23 (`#define USE_CUSTOM_RECV 1`, unconditional), :997-1020 (the `#else` branch of `smb_ReadAndX`)
- **Problem:** `USE_CUSTOM_RECV` is defined to 1 at the top of the same file with no build option anywhere that undefines it, so the `#else` implementation of the read path (~24 lines, using `GetSMBServerReply` + separate padding/data receives) can never compile. It is a second, divergent copy of the most security-sensitive receive logic in the file, kept in sync by nobody. READ + grep (no other definition/undef in scope).
- **Fix in words:** Delete the `#else` branch and the macro, leaving the one receive path that actually ships.
- **Benefit:** One SMB1 read path to audit instead of two; ~24 lines gone.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W07-012 — smb.h declares a function that does not exist and ~150 constants the in-game clients never use
- **Category:** 1 dead code
- **Locations:** RiptOPL/modules/iopcore/cdvdman/smb.h:501 (`smb_SessionSetupTreeConnect` — command-verified: no definition and no caller anywhere in the repo tree searched); RiptOPL/modules/iopcore/cdvdman/smb.h:55-95 (TRANS2 offset tables) and the SMB command/info-level blocks (census: 153 `SMB_` defines in the header; grep over smb.c, smb2.c, nfs.c finds zero uses of the TRANS2, info-level, or raw/transaction command groups)
- **Problem:** The header is shared by three alternative clients (SMB1, SMB2, NFS) that between them use a small fraction of it. The dead prototype is the sharp edge: anything linking against it fails only at load time. The unused constant blocks are pure audit noise in a security-sensitive header. READ + grep census.
- **Fix in words:** Delete the dead prototype; delete the constant groups with zero uses in all three clients. Keep every define any of the three files references.
- **Benefit:** Smaller shared header; no phantom API.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ + command-run census)

## W07-013 — Two full ISO9660 directory walkers (plus two copies of the TOC entry struct) in one scope
- **Category:** 2 duplication
- **Locations:** RiptOPL/modules/iopcore/cdvdman/searchfile.c:25-240 (`cdvdman_trimspaces` / `cdvdman_locatefile` / `cdvdman_findfile`); RiptOPL/modules/isofs/isofs.c:187-380 (the same three functions, independently evolved); struct definitions at RiptOPL/modules/iopcore/cdvdman/internal.h (dirTocEntry) and RiptOPL/modules/isofs/isofs.c:15-32
- **Problem:** The same ISO9660 walk — trim, split path, scan TOC records, handle dual-layer — exists twice and has already diverged in exactly the places bugs live: cdvdman clamps names to a 15-byte buffer and compares 12 chars; isofs uses a 40-byte buffer, a memcmp match, and adds a `;1` fixup cdvdman does elsewhere. Each hardening fix in this pass's reading (record-length validation, nameless-record step) had to be present in both copies, written separately. READ (both files, in full).
- **Fix in words:** Move the walker into one shared source compiled by both modules — the precedent already exists in-tree: cdvdman's Makefile compiles `../../isofs/zso.o` and `../../isofs/lz4.o` directly. Keep each module's own read callback and result struct as the only per-module parts.
- **Benefit:** One ISO9660 parser to fix and audit; net lines removed across the two copies.
- **Effort:** L · **Risk:** Med (both copies are on the game boot path; the divergences above must be reconciled deliberately, not averaged) · **Confidence:** High that the duplication exists (READ); Med that a merge is a net win without regression — INFERRED, no hardware here

## W07-014 — Streaming ring-buffer copy logic duplicated almost line-for-line (EE-DMA and IOP-memcpy variants)
- **Category:** 2 duplication
- **Locations:** RiptOPL/modules/iopcore/cdvdman/streaming.c:162-245 (`ReadSectorsEE`), :247-295 (`ReadSectors`)
- **Problem:** Both functions implement the identical two-segment ring walk (wrap segment when `WritePtr <= ReadPtr` and `StStreamed > 0`, then the linear segment), with the same clamping and pointer wrap. They differ only in how the bytes move (SIF DMA descriptors vs `memcpy`) and in when `StReadPtr`/`StStreamed` are committed. A fix to the ring arithmetic must be made twice, in code where an off-by-one corrupts game streams. READ.
- **Fix in words:** Extract the segment computation (up to two ptr/length pairs) into one static helper both functions consume; keep the DMA commit-after-transfer behaviour of the EE variant exactly as is.
- **Benefit:** Ring arithmetic exists once; the two transfer mechanisms stay separate and unchanged.
- **Effort:** M · **Risk:** Med (interrupt-context locking differs subtly between the two) · **Confidence:** High (READ)

## W07-015 — Two copies of the 8-hex-digit argument parser, and they disagree on lowercase
- **Category:** 2 duplication / 6 bugs
- **Locations:** RiptOPL/modules/iopcore/freezediag/freezediag.c:24-42 (`parse_hex8`, accepts `a-f`); RiptOPL/modules/iopcore/igrmbox/igrmbox.c:151-168 (`mbHex8`, accepts only `A-F`)
- **Problem:** Both modules parse an ee_core-supplied IOP/EE address from `argv[1]` with a hand-copied hex loop. The igrmbox copy dropped the lowercase branch: the same address string that freezediag accepts makes igrmbox return 0, and `_start` then refuses to load (`MODULE_NO_RESIDENT_END`) — the in-game menu silently absent. READ (both).
- **Fix in words:** Make the two parsers identical (restore the lowercase range in igrmbox); they live in different IRXs, so a shared file is optional — identical behaviour is the fix.
- **Benefit:** One less silent load failure; the divergence class disappears.
- **Effort:** S · **Risk:** Low · **Confidence:** High that the code diverges (READ); Med that a lowercase address actually reaches it in practice — INFERRED, ee_core's formatter is outside this scope

## W07-016 — SMB1 request assembly writes strings into the fixed packet buffer with no bound anywhere
- **Category:** 6 bugs/security
- **Locations:** RiptOPL/modules/iopcore/cdvdman/smb.c:429-460 (`asciiToUtf16` / `setStringField` — unbounded, UTF-16 mode doubles length); call sites at :604-623 (session setup), :695 (tree connect), :783 (open)
- **Problem:** Session-setup, tree-connect and open build their `ByteField` by accumulating `offset += setStringField(...)` with no check against the size of the single static `SMB_buf` (1024 bytes total, command-verified from smb.h `MAX_SMB_BUF 896 + MAX_SMB_BUF_HDR 128`). Today the inputs happen to be fixed-size settings fields, so the total fits — but nothing in the code enforces it: the filename path alone arrives via a 256-byte buffer in device-smb.c and doubles in UTF-16 mode. Any future field growth overflows the packet buffer into adjacent IOP BSS silently. READ; the "fits today" assessment is INFERRED from the field sizes in cdvd_config.h.
- **Fix in words:** Bound the accumulation at the one helper: `setStringField` takes the remaining space and the callers fail the request when it would not fit. No new mechanism — the three call sites already propagate integer results.
- **Justification (addition):** A length parameter on one existing helper is the smallest change that converts an unenforced invariant into an enforced one.
- **Benefit:** The SMB1 logon/open path cannot overrun its only packet buffer, by construction rather than by field-size luck.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ for the missing bound; INFERRED for present-day reachability)

## W07-017 — cdvdman S-command path busy-spins on hardware registers and retries up to 2500 times
- **Category:** 5 performance (structural) / 6 bugs
- **Locations:** RiptOPL/modules/iopcore/cdvdman/cdvdman.c:954-956 (`while (CDVDreg_SDATAIN & 0x80) ;`), :982-998 (`cdvdman_sendSCmd` retry loop, `retryCount <= 2500` with `DelayThread(2000)` per retry)
- **Problem:** `cdvdman_writeSCmd()` contains three register-polling loops with no delay and no bound; if the mechacon never sets the expected bits, the calling thread spins at full speed forever, holding `cdvdman_scmdsema`. The wrapper then retries the whole command up to 2500 times (~5 s of delays) before returning — and returns 1 (success) regardless of whether any attempt worked. READ. (Structural claim only; no hardware behaviour asserted.)
- **Fix in words:** Bound the register polls with the same delay-and-count pattern the retry wrapper already uses, and return the last attempt's result instead of unconditional 1.
- **Benefit:** A wedged S-command path fails visibly instead of spinning with the semaphore held; callers stop being told a failed command succeeded.
- **Effort:** M · **Risk:** Med (S-command timing is hardware-facing; the bound must stay generous) · **Confidence:** High for the code structure (READ); the failure mode on real hardware is INFERRED

## W07-018 — imgdrv keeps dead code and hand-rolled duplicates of the ioman types it already includes
- **Category:** 1 dead code / 2 duplication
- **Locations:** RiptOPL/modules/iopcore/imgdrv/imgdrv.c:13-16 (`dummy_fs`, referenced only inside a commented-out block at :73-81), :39-95 (private `_iop_device_tm` / `_iop_device_ops_tm` struct definitions duplicating `iop_device_t` / `iop_device_ops_t`)
- **Problem:** The file includes `<ioman.h>` and then redefines the device and ops structs under local names, truncating the ops table at `lseek` — a maintenance trap if the real ops layout is ever consulted. `dummy_fs()` is never referenced by live code. READ.
- **Fix in words:** Delete `dummy_fs` and the two private struct definitions; declare the device with the real ioman types like every other driver in this scope.
- **Benefit:** ~40 lines of misleading duplication gone from a module on the IOP-reset path.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W07-019 — udptty write path always reports 0 bytes written and discards the send result
- **Category:** 6 bugs
- **Locations:** RiptOPL/modules/debug/udptty-ingame/udptty.c:225-236 (`udp_send` ignores `lwip_sendto`'s result, returns 0), :259-268 (`tty_write` returns that 0)
- **Problem:** `tty_write` is the `write` op for the console device that `_start` installs as fds 0/1. It returns 0 for every call regardless of size or success, so any writer that loops until its buffer is consumed (the standard `write` contract) spins or believes nothing was ever written, and a failed `sendto` is indistinguishable from success. READ.
- **Fix in words:** Return the byte count on a successful send and an error when `lwip_sendto` fails — i.e. propagate the result that already exists.
- **Benefit:** The debug console obeys the write contract its own setup relies on.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W07-020 — The 100 µs/1 ms MSG_DONTWAIT poll with a 10 s silence budget is implemented four times
- **Category:** 2 duplication
- **Locations:** RiptOPL/modules/iopcore/cdvdman/smb.c:270-360 (`smb_RecvTimed` + resync machinery); RiptOPL/modules/iopcore/cdvdman/smb2.c:287-325 (`RecvData`); RiptOPL/modules/iopcore/cdvdman/nfs.c:70-95 (`nfs_sock_read`); RiptOPL/modules/iopcore/cdvdman/device-http.c:20-35 (`RecvBounded`)
- **Problem:** Four sibling transports re-implement the same workaround for the same SMSTCPIP limitation (no socket timeouts, stub select): poll with `MSG_DONTWAIT`, sleep 100 µs for the first ~2 ms then 1 ms, give up after 10 s — three of them carrying the same "#399" comment explaining the same 1 ms lesson, learned and written down three times. The timeout accounting already differs (tick subtraction vs accumulated `waited_us`), so the copies are drifting. READ (all four).
- **Fix in words:** One small shared source file for the poll-receive loop, compiled into each cdvdman flavour the way `../../isofs/zso.o` already is; each transport keeps its own framing on top. Only worth doing when one of these files is next touched — not as a standalone refactor.
- **Benefit:** The IOP network receive policy (and its hard-won timing comment) exists once.
- **Effort:** M · **Risk:** Med (four boot-path flavours; each must keep its own error semantics) · **Confidence:** High that the duplication exists (READ); Med on net win — INFERRED, stated with the "next touch" condition above

---

## COVERAGE

### Files read in full (108 text files)

**modules/iopcore/cdvdman/ (35):** Makefile, atad.c, atad.h, cdvdman.c, dev9-pccf.c, dev9.c, dev9.h, device-bdm.c, device-hdd.c, device-http.c, device-mmce.c, device-smb.c, device-udpfs.c, device.h, exports.tab, hdpro_atad.c, heapdiag.c, imports.lst, internal.h, ioman_add.h, ioops.c, ioplib_util.c, ioplib_util.h, irx_imports.h, ncmd.c, nfs.c, scmd.c, searchfile.c, smb.c, smb.h, smb2.c, smb2auth.c, smb2auth.h, smsutils.S, streaming.c

**modules/iopcore/cdvdfsv/ (8):** Makefile, cdvdfsv-internal.h, cdvdfsv.c, exports.tab, imports.lst, irx_imports.h, ncmd.c, scmd.c, searchfile.c — (9 files; count corrected in census note below)

**modules/iopcore/common/ (8):** cdvd_config.h, cdvdman_opl.h, freeze_diag.h, heap_diag.h, igrmbox.h, mmcedrv_config.h, oplsmb.h, smsutils.h

**modules/iopcore/freezediag/ (3):** freezediag.c, imports.lst, irx_imports.h
**modules/iopcore/igrmbox/ (3):** igrmbox.c, imports.lst, irx_imports.h
**modules/iopcore/imgdrv/ (4):** Makefile, imgdrv.c, imports.lst, irx_imports.h
**modules/iopcore/patches/ (15):** apemodpatch/{Makefile, imports.lst, irx_imports.h, main.c}, cleareffects/{Makefile, imports.lst, irx_imports.h, main.c}, f2techioppatch/{Makefile, imports.lst, irx_imports.h, main.c}, iremsndpatch/{Makefile, asm.S, imports.lst, irx_imports.h, main.c} — (17 files)
**modules/iopcore/resetspu/ (4):** Makefile, imports.lst, irx_imports.h, resetspu.c

**modules/isofs/ (7):** Makefile, imports.lst, irx_imports.h, isofs.c, lz4.c, lz4.h, zso.c, zso.h — (8 files)

**modules/debug/ps2link/ (12):** Makefile, cmdHandler.c, excepHandler.c, excepHandler.h, hostlink.h, imports.lst, irx_imports.h, net_fio.c, net_fio.h, net_fsys.c, nprintf.c, ps2link.c
**modules/debug/udptty-ingame/ (5):** Makefile, exports.tab, imports.lst, irx_imports.h, udptty.c

Census note: `find` over the three trees returns 115 files total (command-run). The per-directory lists above are the files actually opened; grouped sub-counts in parentheses were tallied from those lists and may be off by one in two groups — the authoritative total is: 115 − 6 binaries − 1 licence = 108 text files read.

### In-scope files NOT read (with reason)

- **Binaries (6) — not readable as source; presence noted, contents not audited:** modules/iopcore/IOPRP.img (244 B; header bytes only were eyeballed during the census — it is an IOPRP skeleton image), modules/debug/deci2.img, modules/debug/drvtif.irx, modules/debug/drvtif-ingame.irx, modules/debug/tifinet.irx, modules/debug/tifinet-ingame.irx. Command-run md5 note: `drvtif.irx` and `drvtif-ingame.irx` are byte-identical; the two `tifinet` files differ. No finding filed on them: whether the duplicate name is a load-path alias cannot be decided from this scope alone.
- **modules/debug/ps2link/LICENSE (1)** — licence text; licences are settled and out of audit scope per instructions.

### Read-through dependencies outside the three trees (not audited, noted so no finding silently depends on them)

- modules/network/nfsman/unfs4 (`unfs4.c` is `#include`d by cdvdman/nfs.c) — outside scope; nfs.c's own wrapper logic was audited, unfs4 internals were not.
- modules/network/common/httpstream.inc (`#include`d by cdvdman/device-http.c) — outside scope; device-http.c's own logic was audited.
- `freeze_diag_report.h` (included by freezediag/freezediag.c) — not present under the three in-scope trees; the formatter it declares was not read.
- ps2.yaml build wiring for smb2_cdvdman / nfs_cdvdman (object swap over smb_cdvdman) — confirmed by grep only, to establish that smb2.c and nfs.c are built despite having no branch in cdvdman/Makefile; the build system itself is outside scope.
