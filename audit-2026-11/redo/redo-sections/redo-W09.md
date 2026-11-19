# W09 — Blind Redo Audit: modules/hdd, modules/usb, modules/vmc, modules/mcemu

- Clone: `~/workspace/audit-clones-2026-11-13/RiptOPL`
- Pin verified: `git rev-parse HEAD` = `2e347d5ac885cd0ff73e9ad4143781946396f492`
- Method: every in-scope file opened and read from the code only; counts below come from scripts/commands run during the audit. No PS2SDK/hardware behaviour is claimed; performance items are structural only.
- Rule applied: LESS, NOT MORE — delete / simplify / fix, no new abstractions.

---

## W09-001 — The whole APA partition-editing subtree is retained dead code (~700 lines)

**Category:** 1 dead code / 8 half-finished (refused) features
**Locations:**
- RiptOPL/modules/hdd/apa/src/hdd_fio.c:340-461 (`hddFormat` body after its unconditional `return -EACCES` at :347)
- RiptOPL/modules/hdd/apa/src/hdd_fio.c:519-563 (`apaRemove`, called only from the dead tail of `hddRemove` at :630-636)
- RiptOPL/modules/hdd/apa/src/hdd_fio.c:565-613 (`apaRename`, called only from the dead tail of `hddReName` at :852-858)
- RiptOPL/modules/hdd/apa/src/hdd_fio.c:860-919 (`ioctl2AddSub`, declared `__attribute__((unused))` at :98)
- RiptOPL/modules/hdd/apa/src/hdd_fio.c:921-947 (`ioctl2DeleteLastSub`, `unused` at :99)
- RiptOPL/modules/hdd/apa/src/hdd_fio.c:1028-1066 (`devctlSwapTemp`, `unused` at :100)
- RiptOPL/modules/hdd/apa/src/hdd_fio.c:1068-1091 (`devctlSetOsdMBR`, `unused` at :101)
- RiptOPL/modules/hdd/apa/src/apa.c:105-134 (`apaFillHeader`), :136-168 (`apaInsertPartition`), :213-231 (`apaRemovePartition`), :233-253 (`apaMakeEmpty`), :255-305 (`apaDeleteFixPrev`), :308-361 (`apaDeleteFixNext`), :364-410 (`apaDelete`) — reachable only from the functions above
- RiptOPL/modules/hdd/apa/src/hdd.c:103-107 (`hddCheckPartitionMax`, only caller is dead `ioctl2AddSub`), :109-179 (`hddAddPartitionHere`, only callers are the dead format body and dead `ioctl2AddSub`)
- Knock-on: RiptOPL/modules/hdd/apa/src/cache.c:105-127 (`apaCacheFlushDirty`/`apaCacheFlushAllDirty`) and RiptOPL/modules/hdd/apa/src/journal.c:47-56 (`apaJournalWrite`) — a scripted grep of every `APA_CACHE_FLAG_DIRTY` setter shows all of them are inside the functions above, so in this build nothing ever marks a header dirty and the flush/journal-write path never runs (journal *restore* at startup is live and stays).

**Problem:** The fork deliberately refuses format / create / delete / rename / add-sub / delete-sub / swap-temp / set-osd-mbr with `-EACCES` (documented in `modules/hdd/apa/ORIGIN.txt` item 4), but keeps every refused body "for diffability". That is ~372 lines in hdd_fio.c (counted by script over the ranges above) plus ~255 lines in apa.c plus ~76 lines in hdd.c of compiled, reviewable, misleading code — including one latent defect that only exists because the dead code is kept: `apaRename` calls `SignalSema(fioSema)` on three exit paths (hdd_fio.c:573, 581, 595) although it never waits on that semaphore; its only caller held the semaphore, so if the refusal in `hddReName` is ever lifted the semaphore count is corrupted.
**Fix:** Delete the refused bodies and the functions only they call; leave the one-line `-EACCES` returns in the ops/devctl/ioctl2 dispatchers. Keep `apaJournalRestore`/`apaJournalReset`. The SDK pin in ORIGIN.txt is the diff reference — the bodies do not need to live in the tree to be diffed.
**Benefit:** ~700 fewer lines in the highest-risk driver in the tree; the partition-table write surface becomes exactly what the policy says it is; removes the semaphore-imbalance trap.
**Effort:** M · **Risk:** Med (re-vendor workflow documented in ORIGIN.txt gets simpler, not harder, but this is a deliberate fork policy reversal) · **Confidence:** High (READ — call graph verified by grep over all callers)

## W09-002 — APA journal restore trusts the on-disk entry count and a possibly-NULL cache entry

**Category:** 6 bugs/security
**Locations:**
- RiptOPL/modules/hdd/apa/src/journal.c:58-86 (`apaJournalRestore`, loop at :73)
- RiptOPL/modules/hdd/apa/src/libapa.h:183-189 (`apa_journal_t.sectors[126]`)
- RiptOPL/modules/hdd/apa/src/journal.c:47-56 (`apaJournalWrite`, same unbounded `num++` on the write side)

**Problem:** `apaJournalRestore` checks only `journalBuf.magic`, then loops `i < journalBuf.num` reading `journalBuf.sectors[i]` as the *destination LBA* for a 2-sector write. `num` is an `s32` read straight from disk and is never clamped to the 126-entry array: a corrupt or hostile journal header makes the loop read past the static `journalBuf` into adjacent BSS and write header data to whatever LBAs it finds there, at driver init, before any fence-relevant check (the table fence only accepts a valid `__mbr` at LBA 0; other LBAs pass). The same function also dereferences `apaCacheAlloc()`'s result without a NULL check (`clink->header` at :75). `apaJournalWrite` likewise increments `num` with no bound against `sectors[126]`.
**Fix:** In restore, reject/reset when `num < 0 || num > 126` before replaying, and return the journal reset if `apaCacheAlloc()` returns NULL. In write, refuse to append at 126 entries.
**Benefit:** A single corrupt sector in the journal area can no longer turn into arbitrary sector writes during boot.
**Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W09-003 — `HIOCGETSIZE` indexes the partition array with an unchecked EE-supplied index

**Category:** 6 bugs/security
**Locations:**
- RiptOPL/modules/hdd/apa/src/hdd_fio.c:995-997 (`case HIOCGETSIZE: rv = fileSlot->parts[*(u32 *)argp].length;`)
- RiptOPL/modules/hdd/apa/src/hdd.h:16-24 (`parts[APA_MAXSUB + 1]` = 65 entries)

**Problem:** The index comes directly from the ioctl2 argument with no comparison against `fileSlot->nsub` or the 65-entry array, and `argp` itself is never NULL-checked. An out-of-range index reads past the file slot (the slot array defaults to a single slot, `apaMaxOpen = 1` at hdd_fio.c:35) and returns adjacent IOP memory to the EE as a partition "length". The neighbouring `ioctl2Transfer` in the same file was already fixed by the fork to be bounds- and overflow-safe; this case was missed.
**Fix:** Reject `*(u32 *)argp > fileSlot->nsub` (and NULL `argp`) with `-EINVAL` before indexing — the same check shape `ioctl2Transfer` already uses.
**Benefit:** Closes an EE-triggerable out-of-bounds read / info return in the raw APA interface.
**Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W09-004 — mcemu (HDD): an unmapped VMC page silently maps to sector 0

**Category:** 6 bugs/security
**Locations:**
- RiptOPL/modules/mcemu/device-hdd.c:11-28 (`Mcpage_to_Apasector`)
- RiptOPL/modules/mcemu/device-hdd.c:30-48 (`DeviceWritePage` / `DeviceReadPage` pass the result straight to `sceAtaDmaTransfer`)

**Problem:** `Mcpage_to_Apasector` initialises `sector_to_read = 0` and returns 0 when the requested page falls outside all ten PFS block extents in `vmcSpec[mc_num].blocks[]` — e.g. a VMC image fragmented into more extents than the map holds, or a page past the mapped end. Sector 0 is the APA `__mbr` header sector. Neither caller can distinguish "page legitimately at sector 0" (impossible for a PFS file extent) from "unmapped", so a stray VMC write page is DMA-written over the partition-table header sector instead of failing.
**Fix:** Make the mapper report failure (e.g. return a sentinel the callers check, or check in the two callers for a page that matched no block) and have both device functions return 0 (failure) in that case.
**Benefit:** Removes a path by which virtual-memory-card I/O can overwrite LBA 0 of the game disk.
**Effort:** S · **Risk:** Low · **Confidence:** High (READ — the default-0 return and the unchecked callers are both in the code; the triggering fragmentation state is INFERRED)

## W09-005 — APA cache entries are dereferenced after `apaCacheFree`

**Category:** 6 bugs
**Locations:**
- RiptOPL/modules/hdd/apa/src/hdd_fio.c:510-512 (`apaOpen`: `apaCacheFree(clink);` then `apaPassCmp(clink->header->fpwd, …)` / `clink->header->rpwd`)
- RiptOPL/modules/hdd/apa/src/apa.c:508-518 (`apaGetNextHeader`: frees `clink`, then reads `clink->header->next` and `clink->device` to fetch the next header)
- RiptOPL/modules/hdd/apa/src/apa.c:386-390 (`apaDelete`: frees `clink` inside the loop, then reads `clink->device` / `clink->header->prev` — this instance is inside the dead subtree of W09-001)

**Problem:** `apaCacheFree` (cache.c:179-196) drops the use count and, at zero, links the entry back onto the free list, from where `apaCacheAlloc`/`apaCacheGetHeader` hand it out again. Reading `header` fields after the free works today only because the header storage is a static pool and no allocation happens in between at the first two sites (INFERRED mitigation); it is one intervening allocation away from comparing passwords against, or following `next`/`device` from, a different partition's header.
**Fix:** Copy the two password fields (in `apaOpen`) and `next`/`device` (in `apaGetNextHeader`) into locals before freeing — a few lines moved, nothing added.
**Benefit:** Removes a use-after-release idiom from the partition-open and chain-walk paths every HDD launch goes through.
**Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W09-006 — `hdd_blkio.c` compiles to an empty object in this build (415 lines of other builds' code)

**Category:** 1 dead code / 7 build clutter
**Locations:**
- RiptOPL/modules/hdd/apa/src/hdd_blkio.c:1-415 (BDM filesystem-driver variant at :22-169 under `#ifdef APA_USE_BDM`; VHDD variant at :171-303 under `#ifdef APA_USE_IOMANX`; the generic `blkIo*` definitions at :305-415 under `#ifndef APA_USE_ATAD`)
- RiptOPL/modules/hdd/apa/Makefile (`IOP_CFLAGS += -DAPA_OSD_VER -DAPA_USE_DEV9 -DAPA_USE_ATAD`; `hdd_blkio.o` in `IOP_OBJS`)
- RiptOPL/modules/hdd/apa/src/hdd_blkio.h:14-63 (the ATAD build's `blkIo*` are static inlines routing to the table fence — the .c file contributes nothing)

**Problem:** This build defines `APA_USE_ATAD` and neither `APA_USE_BDM` nor `APA_USE_IOMANX`, so every function in hdd_blkio.c is preprocessed away, yet the file is still compiled and linked as an (empty) object and still has to be read, formatted and re-vendored as if it were live. Its BDM/VHDD mount code duplicates journal-restore/format-check logic that also lives in hdd.c's ATAD startup path.
**Fix:** Drop `hdd_blkio.o` from this Makefile's `IOP_OBJS` and delete the file from the vendored tree (it remains available at the SDK pin in ORIGIN.txt if another variant is ever built).
**Benefit:** 415 fewer lines carried in the APA module; one less place where mount/startup logic appears to live.
**Effort:** S · **Risk:** Med (touches the documented re-vendor set) · **Confidence:** High (READ — flags and guards verified)

## W09-007 — APA password DES (~460 lines) runs in a build where password comparison is compiled out

**Category:** 1 dead code / 3 overengineering
**Locations:**
- RiptOPL/modules/hdd/apa/src/password.c:39-498 (`apaEncryptPassword` + the full DES-ECB implementation)
- RiptOPL/modules/hdd/apa/src/password.c:25-36 (`apaPassCmp` returns 0 unconditionally when `APA_ENABLE_PASSWORDS` is undefined)
- RiptOPL/modules/hdd/apa/src/apa-opt.h:31-38 (the `APA_OSD_VER` branch used by this Makefile does **not** define `APA_ENABLE_PASSWORDS`; only the non-OSD branch at :36 does)
- RiptOPL/modules/hdd/apa/src/hdd_fio.c:175-195 (`fioGetInput` DES-encrypts both passwords on every partition open/getstat/remove parse)

**Problem:** In the OSD build that this repo actually ships, no password comparison can ever fail, yet every `hddOpen`/`hddGetStat` that carries passwords in its name string runs two full DES encryptions whose outputs are then "compared" by a no-op, and the ~460-line DES implementation is linked into the IRX solely to produce those values (its other producers are the dead format path of W09-001). On-disk headers written by other tools are unaffected: opening them never depended on the encrypted values matching in this build.
**Fix:** In the OSD configuration, make `apaEncryptPassword` a no-op alongside `apaPassCmp` and drop `password.o`'s DES body (keep the two entry points so callers and the re-vendor diff stay trivial).
**Benefit:** ~460 lines and a per-open DES computation removed from a memory-constrained IOP module.
**Effort:** S · **Risk:** Med (changes bytes written if a partition is ever created by another build variant from these sources — creation is already refused, W09-001) · **Confidence:** High (READ for the config and call sites; INFERRED that no out-of-tree consumer depends on the encrypted fields)

## W09-008 — xatad duplicates atad's DMA-mode tables, and the copies have already diverged in reach

**Category:** 2 duplication
**Locations:**
- RiptOPL/modules/hdd/xhdd/xatad.c:8-52 (`ata_multiword_dma_mode`, `ata_ultra_dma_mode` — same timing values as atad's)
- RiptOPL/modules/hdd/atad/src/ps2atad.c:1486-1529 (atad's `ata_multiword_dma_mode` / `ata_ultra_dma_mode`)
- RiptOPL/modules/hdd/atad/src/ps2atad.c:55-57, 996-1000 (atad's MDMA copy is compiled only under `ATA_MWDMA_MODES`, which the atad Makefile does not define — so atad's copy is dead while xhdd's MDMA branch is live)

**Problem:** Two modules that program the same SPEED-register DMA timing tables carry independent copies of the value tables. One copy is unreachable in its own module, so in practice only xhdd's tables are exercised — exactly the setup where a future timing fix lands in the wrong (dead) copy.
**Fix:** Delete atad's never-compiled MDMA function, and move the two small timing switches into the already-shared `modules/hdd/common/opl-hdd-ioctl.h` include path (or a sibling common header both modules already use) as static inlines, deleting xatad's duplicates.
**Justification (addition):** The shared inline replaces two copies with one — net code removed, no new abstraction beyond the header both modules already share.
**Benefit:** One source of truth for hardware timing values; ~44 lines removed.
**Effort:** M · **Risk:** Med (register-programming code; values must be copied verbatim) · **Confidence:** High (READ)

## W09-009 — xhdd: HDPro transfer-mode stub reports success for doing nothing; two header prototypes have no definition

**Category:** 8 half-finished feature / 6 bugs
**Locations:**
- RiptOPL/modules/hdd/xhdd/hdpro.c:8-11 (`hdproata_device_set_transfer_mode` returns 0 unconditionally, empty body)
- RiptOPL/modules/hdd/xhdd/xhdd.c:43-48 (devctl `ATA_DEVCTL_SET_TRANSFER_MODE` returns that 0 to the EE when `isHDPro`)
- RiptOPL/modules/hdd/xhdd/xhdd.h:2, 4 (`ata_device_set_write_cache`, `hdproata_device_set_write_cache` declared; neither is defined anywhere in modules/hdd/xhdd — the definitions with the first name live in the unrelated cdvdman module)

**Problem:** On an HDPro setup the EE is told the transfer mode was set when nothing was programmed — a silent no-op success is worse than an error, because the caller proceeds on a false assumption about the bus mode. The header also advertises two write-cache functions this module does not contain.
**Fix:** Return a negative "not supported" code from the HDPro stub (and let the devctl propagate it), and delete the two orphan prototypes from xhdd.h.
**Benefit:** Honest failure instead of silent misconfiguration on HDPro; header matches the module.
**Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W09-010 — xhdd: a 407-line Windows IDENTIFY-device struct (and 512-byte static) to read one 16-bit field

**Category:** 4 size/memory / 3 overengineering
**Locations:**
- RiptOPL/modules/hdd/xhdd/ata_identify.h:1-407 (full `IDENTIFY_DEVICE_DATA` bitfield transcription)
- RiptOPL/modules/hdd/xhdd/xhdd.c:17 (`static IDENTIFY_DEVICE_DATA deviceIdentifyData;`), :70-84 (the only field ever read is `UltraDMASupport`)

**Problem:** The devctl `ATA_DEVCTL_GET_HIGHEST_UDMA_MODE` fills the entire packed struct via `ata_device_identify` and then tests a single field. The 407-line header exists for that one read, and its packed bitfield layout is exactly the kind of thing that silently shifts if the header is ever edited.
**Fix:** Delete ata_identify.h; read the identify data into a plain `u16[256]` buffer and test the UDMA-support word directly (INFERRED: word 88 in the standard ATA IDENTIFY layout, which is where the struct places `UltraDMASupport`).
**Benefit:** 407 lines of header and the layout risk gone; the static buffer stays the same 512 bytes the hardware transfer already requires.
**Effort:** S · **Risk:** Low · **Confidence:** High (READ for the single-field use; the word index is INFERRED from the struct layout)

## W09-011 — usbmass_bd: the unselectable ASYNC implementation of `usb_queue_cmd` is carried alongside the live one

**Category:** 1 dead code
**Locations:**
- RiptOPL/modules/usb/usbmass_bd/src/usb_mass.c:16 (`// #define ASYNC` — commented out, and nothing in the Makefile defines it)
- RiptOPL/modules/usb/usbmass_bd/src/usb_mass.c:445-458 (`scsi_cmd_callback`, `#else` branch only)
- RiptOPL/modules/usb/usbmass_bd/src/usb_mass.c:525-556 (the ASYNC half of `usb_queue_cmd`, including its own TODO at :449 about unhandled errors)

**Problem:** Two complete command-submission strategies live in one function behind a macro that cannot be set from the build. The dead half bypasses the command semaphore that ORIGIN.md documents as the two-drive fix, so it is also a trap: anyone re-enabling it reintroduces the shared-`ucmd` race the fork just fixed.
**Fix:** Delete the `#else` (ASYNC) branch, `scsi_cmd_callback`, and the `ASYNC` guards; keep the synchronous path unconditional.
**Benefit:** ~45 lines removed and the two-drive serialisation can no longer be compiled away by flipping a define.
**Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W09-012 — usbmass_bd SCSI: READ CAPACITY's last-LBA is stored as the sector count (off by one, both variants)

**Category:** 6 bugs
**Locations:**
- RiptOPL/modules/usb/usbmass_bd/src/scsi.c:262-264 (`bd->sectorCount = getBI32(&rc10d.last_lba)`)
- RiptOPL/modules/usb/usbmass_bd/src/scsi.c:281-284 (same assignment from `rc16d.last_lba_*`)
- Contrast: RiptOPL/modules/hdd/atad/src/ps2atad.c (`g_ata_bd[i].sectorCount = devinfo[i].total_sectors…`, a true count from IDENTIFY)

**Problem:** READ CAPACITY (10) and (16) return the LBA of the *last* block, so the block count is that value + 1. Both assignments store it unincremented, so the BDM device for every USB drive reports one sector fewer than the drive has — inconsistent with the ATA BDM device in the same tree, which stores a true count. The practical loss is one 512-byte sector at the end of the volume (INFERRED impact: partition sizing/filesystem end-of-volume calculations inherit the short count).
**Fix:** Store `last_lba + 1` in both places (with the existing `0xffffffff` sentinel check for the 16-byte path kept before the increment).
**Benefit:** USB and ATA block devices report capacity the same way; the final sector of every USB volume becomes addressable.
**Effort:** S · **Risk:** Low · **Confidence:** Med (READ for the assignments; the READ CAPACITY semantics are INFERRED from the field name `last_lba` in the code's own struct)

## W09-013 — usbmass_bd SCSI: a failing sector is retried 16 times back-to-back, each retry through full USB reset recovery

**Category:** 5 performance (structural)
**Locations:**
- RiptOPL/modules/usb/usbmass_bd/src/scsi.c:14 (`SCSI_MAX_RETRIES 16`), :310-330 (`scsi_read` retry loop), :356-375 (`scsi_write` retry loop)
- RiptOPL/modules/usb/usbmass_bd/src/usb_mass.c:317-340 (`usb_bulk_manage_status` performs reset recovery on a failed status)

**Problem:** Neither retry loop has a delay, a reset of its own, or an early exit for permanent errors; each failed attempt already triggers bulk reset recovery inside the status path. A dead or removed drive therefore burns 16 full command+reset cycles per chunk before reporting `-EIO`, on the BDM caller's thread. (Structural observation only — no timing/hardware claim.)
**Fix:** Reduce the loops to a small number of attempts (e.g. 3) — the command layer below already does recovery per attempt; no new retry machinery.
**Benefit:** Failing USB I/O returns in a fraction of the attempts; less bus churn against a drive that is already erroring.
**Effort:** S · **Risk:** Low · **Confidence:** Med (READ for the loop structure; INFERRED that transient errors needing >3 attempts are rarer than the stall cost)

## W09-014 — usbd-ra (MINI_DRIVER): isochronous machinery is fully provisioned although no client in the tree can use it

**Category:** 4 size/memory / 1 dead code
**Locations:**
- RiptOPL/modules/usb/usbd-ra/src/usbd.c:38-55 (MINI config still reserves `maxIsoTransfDesc = 0x40`, `maxIoReqs = 0x100`, `maxTransDesc = 0x40`)
- RiptOPL/modules/usb/usbd-ra/src/hcd.c (initHcdStructs allocates the IsoTD pool and the IsoTD→IoReq LUT from those counts)
- RiptOPL/modules/usb/usbd-ra/src/usbio.c:143-207 (`setupIsocronTransfer`), RiptOPL/modules/usb/usbd-ra/src/usbd.c:96-176 (`processDoneQueue_IsoTd`)
- Evidence of disuse: a grep for isochronous-transfer users across `modules/` outside usbd-ra returns nothing; the only LDD in the tree is bulk mass storage (usbmass_bd) plus the built-in hub driver (interrupt endpoints)

**Problem:** The vendored stack is deliberately kept untouched (Makefile comment), but its *configuration* is this fork's own choice, and the MINI profile still pays IOP RAM for 64 isochronous transfer descriptors plus their LUT and the code paths that service them. The iso done-queue handler even contains an index slip consistent with never running: at usbd.c:130, inside the halted-endpoint drain loop over `curTd`, it clears `memPool.hcIsoTdToIoReqLUT[arg - memPool.hcIsoTdBuf]` (the original TD's slot) instead of `curTd`'s.
**Fix:** Shrink the isochronous pool through the driver's existing `_start` argument surface (`itd=`, and `ioreq=` if headroom allows) at the module's load site, rather than editing vendored sources; leave a nonzero token pool if the HCD struct layout requires one.
**Justification (addition):** No addition — this uses the configuration mechanism the vendored driver already exposes.
**Benefit:** IOP RAM returned to the loader/game; no vendored file changes, so the re-vendor story in the Makefile is untouched.
**Effort:** M · **Risk:** Med (pool sizes must be validated against the HCD allocation arithmetic in initHcdStructs) · **Confidence:** Med (READ for config and allocation; INFERRED that no out-of-tree LDD registers an isochronous endpoint against this IRX)

## W09-015 — atad ORIGIN.txt states a change the code does not contain

**Category:** 7 repo clutter / documentation drift
**Locations:**
- RiptOPL/modules/hdd/atad/ORIGIN.txt, local-change item 4 ("The `g_ata_bd[i].path` assignment is DROPPED…")
- RiptOPL/modules/hdd/atad/src/ps2atad.c:359 (`g_ata_bd[i].path = "ata";` — present, with its own comment)

**Problem:** The provenance file that the re-vendor procedure depends on says the `.path` assignment was dropped for ABI reasons, but the vendored source assigns it. A future re-vendor following ORIGIN.txt will either "re-drop" a field the current build relies on for `ata<k>:` naming, or waste the investigation re-deriving which document is wrong.
**Fix:** Correct ORIGIN.txt item 4 to describe what the code does (assignment kept, with the ps2sdk commit the comment cites), or — if the ABI concern in the note is the true one — remove the assignment and keep the note. One of the two, deliberately.
**Benefit:** The re-vendor checklist becomes trustworthy again for this module.
**Effort:** S · **Risk:** Low · **Confidence:** High (READ — both texts in hand)

## W09-016 — mcemu carries an orphan, near-duplicate `ioman_add.h` that nothing in mcemu includes

**Category:** 2 duplication / 1 dead code
**Locations:**
- RiptOPL/modules/mcemu/ioman_add.h:1-48
- RiptOPL/modules/iopcore/cdvdman/ioman_add.h (the other copy — a diff shows the two differ only by an added `#include <iox_stat.h>` and one `lseek` signature)

**Problem:** A grep for `ioman_add` across the tree finds exactly one includer — cdvdman's `internal.h`, which resolves to cdvdman's own copy. The mcemu copy is included by nothing, in a module that uses plain ioman (not iomanX extension ops), and it has already drifted from its sibling, so anyone who does include it gets a subtly different ops table.
**Fix:** Delete `modules/mcemu/ioman_add.h`.
**Benefit:** One less stale ABI header in the tree; no build impact.
**Effort:** S · **Risk:** Low · **Confidence:** High (READ — include search and diff both run)

## W09-017 — genvmc: the same `mc_writecluster` error translation is hand-copied at eight sites

**Category:** 2 duplication
**Locations:**
- RiptOPL/modules/vmc/genvmc/genvmc.c:267, 283 (`vmc_mccopy`), :378, 439, 488, 538, 554 (`vmc_mcformat`), :632 (`vmc_rebuild`) — each of the form `if (r == -2) r = -1000; else r = -<site-specific code>;` after a `mc_writecluster` call (grep-verified, 8 sites)

**Problem:** The abort-vs-error mapping for the one cluster-write primitive is re-expressed at every call site, with the site-specific error code as the only variation. Any change to the abort convention (or a ninth site added without it) silently diverges.
**Fix:** One tiny static helper in the same file that takes the raw result and the site's error code and returns the translated code; call sites become one line each. This is the "same logic in 2+ places, sharing removes code" case — eight copies collapse to one.
**Justification (addition):** The helper is smaller than the eight blocks it replaces; net lines decrease.
**Benefit:** Single place for the abort convention; each format/copy/rebuild site shrinks.
**Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W09-018 — ps2atad carries whole subsystems behind macros its Makefile never defines

**Category:** 1 dead code / 7 build clutter
**Locations:**
- RiptOPL/modules/hdd/atad/Makefile (defines only `ATA_USE_DEV9=1`, `ATA_GAMESTAR_WORKAROUND=1`, `ATA_ENABLE_BDM=1`)
- RiptOPL/modules/hdd/atad/src/ps2atad.c:29-31, 213-215 and the AIFDEV9 blocks throughout (incl. `aif_tune_drive` and the AIF interrupt callback) — `ATA_USE_AIFDEV9` never defined
- RiptOPL/modules/hdd/atad/src/ps2atad.c:1454-1485 (`ata_pio_mode`'s `ATA_ALL_PIO_MODES` table — never defined; the live path is the single-value `#else`), :1486+ (`ATA_MWDMA_MODES`, see W09-008), the `ATA_SCE_AUTH_HDD` block in `ata_init_devices`, and the `ATA_ENABLE_MAXUDMA` branch

**Problem:** Because the file is vendored, every reader (and every re-vendor diff) has to reason about four configuration axes this build can never take, including an entire second host-controller backend (AIFDEV9). The live DEV9 path is interleaved with the dead one at almost every function.
**Fix:** Leave the vendored file alone in this pass, but record the dead axes in ORIGIN.txt next to the other local-change notes so the re-vendor procedure strips them deliberately instead of re-reviewing them; strip them in the tree only if the fork accepts one more documented local change.
**Benefit:** Review and re-vendor effort stops being spent on unreachable backends; no behavioural change proposed blind.
**Effort:** S (documentation) · **Risk:** Low · **Confidence:** High (READ — Makefile flags vs. `#ifdef` census)

## W09-019 — usbd-ra public header declares two exports that do not exist

**Category:** 8 half-finished features
**Locations:**
- RiptOPL/modules/usb/usbd-ra/include/usbd.h:294-296, 336-337 (`sceUsbdGetReportDescriptor`, `sceUsbdMultiIsochronousTransfer` — declared, given import slots 17/18, with the header's own comment "these aren't implemented")
- RiptOPL/modules/usb/usbd-ra/src/exports.tab (export table ends at slot 16, `sceUsbdChangeThreadPriority`)

**Problem:** Any module that imports slots 17/18 against this IRX links against entries the driver never exports. The header documents the gap, but the import macros remain available for a future caller to trip over.
**Fix:** Remove the two declarations and their `I_` import macros from the vendored header as a documented local change (the Makefile already carries one such documented deviation policy), or leave exactly as-is if byte-level vendor purity is preferred over API honesty — but do not leave it unrecorded; add it to the Makefile's deviation note either way.
**Benefit:** The header's contract matches the export table.
**Effort:** S · **Risk:** Low · **Confidence:** High (READ)

---

## COVERAGE

### Files read (all line ranges verified open before citing)

**modules/hdd/apa/** — Makefile, ORIGIN.txt, src/apa-opt.h, src/apa.c, src/cache.c, src/free.c, src/hdd.c, src/hdd.h, src/hdd_blkio.c, src/hdd_blkio.h, src/hdd_fio.c, src/hdd_fio.h, src/imports.lst, src/irx_imports.h, src/journal.c, src/libapa.h, src/misc.c, src/password.c, src/table_fence.c, src/table_fence.h
**modules/hdd/atad/** — Makefile, ORIGIN.txt, src/exports.tab, src/imports.lst, src/irx_imports.h, src/ps2atad.c (all 1,646 lines, paged)
**modules/hdd/common/** — opl-hdd-ioctl.h
**modules/hdd/xhdd/** — Makefile, ata_identify.h, hdpro.c, imports.lst, irx_imports.h, xatad.c, xhdd.c, xhdd.h
**modules/usb/usbd-ra/** — Makefile, include/usbd.h, include/usbd_macro.h, src/driver.c, src/driver.h, src/exports.tab, src/hcd.c, src/hcd.h, src/hub.c, src/hub.h, src/imports.lst, src/interface.c, src/irx_imports.h, src/mem.c, src/mem.h, src/usbd.c, src/usbdpriv.h, src/usbio.c, src/usbio.h
**modules/usb/usbmass_bd/** — ORIGIN.md, src/imports.lst, src/irx_imports.h, src/include/module_debug.h, src/include/scsi.h, src/main.c, src/scsi.c, src/usb_mass.c
**modules/vmc/genvmc/** — Makefile, genvmc.c (all 947 lines), genvmc.h, imports.lst, irx_imports.h, vmc_alloc.h
**modules/mcemu/** — Makefile, device-bdm.c, device-hdd.c, device-mmce.c, device-smb.c, device.h, imports.lst, ioman_add.h, irx_imports.h, mcemu.c (all 931 lines, paged), mcemu.h, mcemu_io.c, mcemu_rpc.c, mcemu_sys.c, mcemu_utils.h, mcemu_var.c

Cross-checks run outside the scope folders (grep only, no findings filed against them): callers of xhdd devctl names, `ioman_add.h` includers, `VMC_ALLOC`/`BDM_DEVCTL_VOLINFO` users, isochronous-transfer users.

### Files NOT read

- RiptOPL/modules/hdd/apa/LICENSE (165 lines) and RiptOPL/modules/usb/usbmass_bd/LICENSE (167 lines) — licence texts; licences are settled and out of scope for findings, so they were not opened.
- No other in-scope file was skipped: every source, header, Makefile, imports/exports list and ORIGIN file in the four scope trees was opened.
