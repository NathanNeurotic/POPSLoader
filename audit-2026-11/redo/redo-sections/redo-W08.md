# W08 — BDM / block-device modules (blind redo)

Pin verified: `git rev-parse HEAD` = `2e347d5ac885cd0ff73e9ad4143781946396f492`.
Scope read from code only: `modules/bdm/`, `modules/bdmassault/`, `modules/bdmevent/`, `modules/mx4sio_bd/`.
Census (command-run, `wc -l` over all files): bdm 27,211 lines / 35 files; bdmassault 5,704 / 43 files (incl. 9 binary `.irx.*` blobs); bdmevent 128 / 4; mx4sio_bd 3,011 / 20.

Note on what is *not* re-flagged: the local RiptOPL fixes documented in `modules/bdm/ORIGIN.txt` and `modules/bdm/bdmfs_fatfs/ORIGIN.txt` (cache refill result, 512-byte-sector refusal, partition bounds, GPT gap scan, frag-chain walker, VMC contiguous allocation) were read and are sound as far as static reading goes; the findings below are what remains around them.

---

### W08-001 — GPT driver reports success when its scratch allocation fails
- Category: 6 bugs/security
- Locations: `RiptOPL/modules/bdm/src/part_driver_gpt.c:38-42`
- Problem: READ. On `AllocSysMemory` failure `part_connect_gpt` returns `0`. In `bdm_try_mount` (`modules/bdm/src/bdm.c`) a `connect_bd` return of 0 means "mounted": the device is bound to the GPT filesystem, marked mounted, the mount callback fires, and no other filesystem (FatFs) is ever tried — yet zero partitions were created. Every other failure path in the same function returns `-1`. An IOP-memory-pressure moment therefore silently bricks the drive for the session instead of falling through.
- Fix: Return `-1` on allocation failure, like the read/signature failure paths in the same function.
- Benefit: One-line correctness fix; failed mounts stay retryable/fall-through-able.
- Effort: S · Risk: Low · Confidence: High (READ)

### W08-002 — GPT parser trusts header entry size and never checks first_lba ≤ last_lba
- Category: 6 bugs/security
- Locations: `RiptOPL/modules/bdm/src/part_driver_gpt.c:68`, `RiptOPL/modules/bdm/src/part_driver_gpt.c:130`, `RiptOPL/modules/bdm/src/part_driver_gpt.c:175`; field defined at `RiptOPL/modules/bdm/src/include/gpt_types.h:36`
- Problem: READ. (a) `entriesPerSector = bd->sectorSize / sizeof(gpt_partition_table_entry)` — the header's own `partition_entry_size` field is never read, so a disk formatted with a non-128-byte entry size (legal per UEFI) is walked at the wrong stride and every entry after the first is garbage. (b) The only sanity check is `first_lba < header.first_lba || last_lba > header.last_lba`; an entry with `first_lba > last_lba` (corrupt or crafted) passes, and `sectorCount = last_lba - first_lba + 1` underflows to a near-2^64 partition length. The RiptOPL `part_read`/`part_write` bounds then "protect" a partition that spans the whole address space — cross-partition writes become possible from a filesystem mounted on it.
- Fix: Reject entries with `first_lba > last_lba`; compute the stride from `partition_entry_size` after checking it is ≥ the struct size and divides the sector size, otherwise fail the mount. No new mechanism — two comparisons and using a field that already exists.
- Benefit: Closes a corrupt-disk → cross-partition-write path; makes non-128-byte-entry GPT disks parse correctly.
- Effort: S · Risk: Low · Confidence: High (READ)

### W08-003 — USBMASS_IOCTL_GET_LBA dereferences a possibly-NULL block device
- Category: 6 bugs/security
- Locations: `RiptOPL/modules/bdm/bdmfs_fatfs/src/fs_driver.c:879-891`
- Problem: READ. `GET_LBA` fetches `bd` via `fatfs_fs_driver_get_mounted_bd_from_index(...)` and immediately reads `bd->sectorOffset` with no NULL check. The two neighbouring cases in the same switch prove the pattern is known: `GET_DEVICE_NUMBER` (same function, ~lines 913-935) checks `bd == NULL` and returns `-ENXIO`, and `GET_DRIVERNAME` was already fixed for exactly this NULL copy. A file still open on a volume whose device has disconnected reaches this case and faults the IOP instead of returning an error.
- Fix: Add the same `bd == NULL → -ENXIO` check `GET_DEVICE_NUMBER` already has.
- Benefit: Removes a known-pattern IOP fault on the disconnect race.
- Effort: S · Risk: Low · Confidence: High (READ)

### W08-004 — Mount-info index guard is off by one (and admits negatives)
- Category: 6 bugs/security
- Locations: `RiptOPL/modules/bdm/bdmfs_fatfs/src/fs_driver.c:137-146`
- Problem: READ. `fatfs_fs_driver_get_mounted_bd_from_index` guards with `mount_info_index > FATFS_FS_DRIVER_MOUNT_INFO_MAX` (10, = `FF_VOLUMES`), so index 10 — one past the last valid slot 9 — reads `fs_driver_mount_info[10]`, out of bounds. Negative indices are also passed through to the array. Every diskio/fs_driver lookup funnels through this one function, so this is the single place to fix it.
- Fix: Change the guard to `mount_info_index < 0 || mount_info_index >= FATFS_FS_DRIVER_MOUNT_INFO_MAX`.
- Benefit: One-line fix at the choke point for all volume lookups.
- Effort: S · Risk: Low · Confidence: High (READ; reachability of index 10 via a crafted `pdrv` is INFERRED)

### W08-005 — DEVCTL STOP_UNIT and STOP_ALL do the opposite of their names
- Category: 6 bugs/security
- Locations: `RiptOPL/modules/bdm/bdmfs_fatfs/src/fs_driver.c:1019-1030`
- Problem: READ (code); INFERRED (intended semantics, from the names and the EE caller). `USBMASS_DEVCTL_STOP_UNIT` calls `fatfs_fs_driver_stop_all_bd()` — it stops **every** mounted device. `USBMASS_DEVCTL_STOP_ALL` resolves only the addressed volume and calls `fatfs_fs_driver_stop_single_bd(vol)` — it stops **one**. The bodies are swapped relative to the names. The EE side (`src/sources/bdmsupport.cpp`, read for context) issues `STOP_ALL` against one device's path at terminal teardown to park that drive; today that happens to work only because the implementation is inverted. Anyone who "fixes" a caller to match the name, or calls `STOP_UNIT` expecting one drive parked, will spin down every BDM device — the exact failure the EE teardown comment warns about.
- Fix: Swap the two bodies so each name does what it says, and check the one EE call site still gets single-device behaviour by name.
- Benefit: Removes a live landmine at the IOP/EE contract boundary.
- Effort: S · Risk: Med (EE call-site semantics must be re-checked) · Confidence: High for the inversion (READ), Med for which side callers depend on (INFERRED)

### W08-006 — bdm_disconnect_fs never unmounts anything
- Category: 6 bugs/security
- Locations: `RiptOPL/modules/bdm/src/bdm.c:119-141`
- Problem: READ. `bdm_disconnect_fs` walks the mounts and simply sets `g_mount[i].fs = NULL`. It never calls `fs->disconnect_bd(...)` — contrast `bdm_disconnect_bd` (same file) which does call `fs->disconnect_bd`. If a filesystem module ever disconnects while devices are mounted, its volumes stay mounted inside the filesystem (FatFs keeps the volume, open FILs, and its mount-info slot pointing at the block device) while BDM believes nothing is mounted; a later re-connect double-mounts. INFERRED: today no in-tree caller may exercise this, which is precisely why the asymmetry has survived.
- Fix: In the loop, call `fs->disconnect_bd(g_mount[i].cbd ? cbd : bd)` before clearing the pointer — mirroring `bdm_disconnect_bd` — or, if filesystem disconnect is meant to be unsupported, delete `bdm_disconnect_fs`'s mount loop and the export rather than keeping a version that lies.
- Benefit: Disconnect ordering becomes symmetric; no stale FatFs volumes.
- Effort: S · Risk: Med · Confidence: High (READ)

### W08-007 — MBR sanity check is tautological and all-or-nothing
- Category: 6 bugs/security
- Locations: `RiptOPL/modules/bdm/src/part_driver_mbr.c:11-32` (check), `:85-120` (connect loop)
- Problem: READ. `valid++` runs unconditionally for all four entries, so `valid == 4` is always true and the function reduces to "at least one entry has a non-zero type and a plausible first LBA". Worse, it is all-or-nothing: one non-zero-type entry with `first_lba == 0` or `>= sectorCount` rejects the **whole disk**, even if the other entries are fine — while the connect loop that follows ignores `first_lba` validity entirely and keys only off `sector_count != 0` and `partition_type != 0`. Checker and consumer disagree about what "valid" means.
- Fix: Delete the separate sanity function; fold its one useful test (skip an entry whose `first_lba` is 0 or ≥ the device size) into the existing per-entry loop as a `continue`, so one bad entry costs one partition, not the disk. Net code removed.
- Benefit: Fewer false whole-disk rejections; one definition of a valid entry.
- Effort: S · Risk: Low · Confidence: High (READ)

### W08-008 — diskio GET_SECTOR_COUNT truncates a 64-bit sector count to 32 bits
- Category: 6 bugs/security
- Locations: `RiptOPL/modules/bdm/bdmfs_fatfs/fatfs/diskio.c:130-132`
- Problem: READ. `*(unsigned int *)buff = mounted_bd->sectorCount;` — `sectorCount` is `u64` in `struct block_device`, and this FatFs build has exFAT + 64-bit LBA enabled (`ffconf.h`: `FF_FS_EXFAT 1`). FatFs uses `GET_SECTOR_COUNT` to size/validate the volume; a partition over 2^32 sectors (2 TiB at 512 B) wraps to a small number, so the volume geometry FatFs believes is wrong for exactly the large drives GPT support exists for.
- Fix: Write the full `LBA_t` value (`*(LBA_t *)buff = mounted_bd->sectorCount;`).
- Benefit: Correct geometry for >2 TiB volumes; one line.
- Effort: S · Risk: Low · Confidence: High (READ)

### W08-009 — iLink SCSI layer silently wraps LBAs on drives over 2 TiB
- Category: 6 bugs/security
- Locations: `RiptOPL/modules/bdmassault/ilink_bd_assault/src/IEEE1394_bd/src/scsi.c:169-187` (READ/WRITE(10) CDB build), `:244-264` (READ CAPACITY(10) warmup)
- Problem: READ. The CDB builder masks the 64-bit LBA into 4 bytes (the code comment itself notes the 2 TiB limit), and warmup derives `sectorCount` from READ CAPACITY(10), whose `last_lba` saturates at `0xFFFFFFFF` on larger drives. Combined effect: a >2 TiB iLink drive is offered to BDM with a truncated/wrong geometry, and a request past the 2 TiB line wraps to a low LBA — a write lands on the wrong part of the disk instead of failing. Note BDM's own 512-byte-sector refusal does not catch this; the geometry is self-consistent, just wrong.
- Fix (LESS option): In warmup, refuse the device when `last_lba == 0xFFFFFFFF` (the saturation value), the same refuse-don't-mount pattern BDM already uses for unsupported sector sizes. READ CAPACITY(16) support is the *more* option and is not recommended here.
- Benefit: Converts silent data corruption into a clean "drive not offered".
- Effort: S · Risk: Low · Confidence: High (READ)

### W08-010 — MX4SIO: unknown CSD structure version is accepted with a zero/stale sector count
- Category: 6 bugs/security
- Locations: `RiptOPL/modules/mx4sio_bd/src/spi_sdcard_driver.c:369-391`
- Problem: READ. `spisd_get_card_info` sets `bd.sectorCount` only when `csd_structure == 0` (v1) or `== 1` (v2). Any other value falls through, the function still returns `SPISD_RESULT_OK`, and `sd_detect` (`modules/mx4sio_bd/src/mx4sio.c:611-646`) connects the device to BDM with `sectorCount` still 0 (first insert) or still holding the **previous card's** capacity (after a swap/recovery). BDM then partitions/mounts against a geometry that does not describe the card in the slot.
- Fix: Add the missing else: return `SPISD_RESULT_ERROR` when the CSD structure is neither 0 nor 1.
- Benefit: Bad/unknown cards are refused instead of mounted with phantom geometry.
- Effort: S · Risk: Low · Confidence: High (READ)

### W08-011 — MX4SIO recovery re-reads card geometry in place while BDM/FatFs stay mounted
- Category: 6 bugs/security
- Locations: `RiptOPL/modules/mx4sio_bd/src/mx4sio.c:611-646`, `RiptOPL/modules/mx4sio_bd/src/spi_sdcard_driver.c:393-411`
- Problem: READ. When CMD13 status is non-zero, `sd_detect` calls `spisd_recover()`, which re-initialises the card and re-runs `spisd_get_card_info()` — overwriting `bd.sectorCount` — **without** `bdm_disconnect_bd`/`bdm_connect_bd`. Only if recovery outright fails is the device disconnected. So after a successful "recovery" (including the case where the user swapped cards during the glitch), BDM's partition devices, the bd_cache contents, and the mounted FatFs volume all still describe the old card while the block device now describes a different one. Cached metadata from card A can be written back to card B.
- Fix: In `sd_detect`, disconnect from BDM before attempting recovery and reconnect after it succeeds — the connect/disconnect calls already exist in the same function for the other branches.
- Benefit: Cache/partition state can never outlive the card it describes.
- Effort: S · Risk: Med · Confidence: High (READ)

### W08-012 — MX4SIO CRC16 support is compiled in but permanently switched off; CRC7 mode selection is broken-but-lucky
- Category: 1 dead code / 8 half-finished
- Locations: `RiptOPL/modules/mx4sio_bd/Makefile` (`IOP_OBJS` includes `crc16.o`), `RiptOPL/modules/mx4sio_bd/src/mx4sio.h:37,45-46`, `RiptOPL/modules/mx4sio_bd/src/mx4sio.c:42-49`, `RiptOPL/modules/mx4sio_bd/src/spi_sdcard_driver.c:463-475`; `RiptOPL/modules/mx4sio_bd/src/spi_sdcard_driver_config.h:22`, `RiptOPL/modules/mx4sio_bd/src/spi_sdcard_crc7.c:5-45`
- Problem: READ. (a) `CONFIG_USE_CRC16` is commented out in `mx4sio.h`, so the only caller of `crc16()` is `#ifdef`'d away and the RX ISR explicitly discards the two CRC bytes — yet `crc16.c` is still compiled and linked into every mx4sio build, and `dma_command_t` carries a `crc[512]` "FIXME" field under the same dead flag. Read data is therefore never CRC-checked, and the dead object ships anyway. (b) The config selects `SD_CRC7_MODE_RAM_TABLE`, but `spi_sdcard_crc7.c:7` tests `SD_CRC7_MODE == CRC7_MODE_RAM_TABLE` — a macro name that does not exist (missing `SD_` prefix) — so the RAM-table branch (and `crc7_generate_table`, which nothing calls) is silently skipped and the ROM table is used. It works by accident; anyone "fixing" the config to match its comment breaks the build/selection.
- Fix: Pick one state per mechanism and delete the other: for CRC16, either enable it end-to-end or delete `crc16.c/.h`, the Makefile object, and the `#ifdef` blocks; for CRC7, set the config to `SD_CRC7_MODE_ROM_TABLE` (what actually runs) and delete the RAM-table branch and its generator.
- Benefit: Removes a dead object from every build and a config that lies about what is compiled.
- Effort: S · Risk: Low · Confidence: High (READ)

### W08-013 — bd_defrag read and write are the same function written twice
- Category: 2 duplication
- Locations: `RiptOPL/modules/bdm/libbdm/src/bd_defrag.c:1-101` (both functions, whole file)
- Problem: READ. `bd_defrag_read` and `bd_defrag_write` are line-for-line identical except for the `bd->read`/`bd->write` call and variable names — fragment search, clipping, advance, error paths all duplicated (~45 lines × 2). Any fix to the fragment walk (e.g. the bounds behaviour) has to be made twice, and the header already admits the duplication pressure with a `bd_defrag` backwards-compat alias.
- Fix: One static worker taking a write flag (or a function pointer), with the two public names as one-line wrappers. Net ≈ −40 lines, no new abstraction beyond the merge itself.
- Benefit: Single fragment-walk implementation to audit and fix.
- Effort: S · Risk: Low · Confidence: High (READ)

### W08-014 — Two near-identical iLink driver trees in one repo, already diverged
- Category: 2 duplication
- Locations: `RiptOPL/modules/bdmassault/ilink_bd_assault/src/` (whole tree) vs the parallel tree at `RiptOPL/modules/ilink/` (out of scope, compared only)
- Problem: READ via `diff -rq`: the bdmassault tree duplicates the SBP-2 driver, SCSI layer, and the whole iLinkman manager from `modules/ilink/`, and the copies have **already diverged** beyond include paths — e.g. `scsi.c` differs in struct definitions and static asserts, `sbp2_driver.c`, `iLink.c`, `iLink_DMA.c`, `iLink_PHY.c` all differ. Every iLink fix (and this driver's history is a long chain of subtle SBP-2 fixes, per `PROVENANCE.md`) must be ported by hand or one copy silently rots — the POPSTARTER copy is the one least likely to be exercised in normal testing.
- Fix: Generate the bdmassault variant from the `modules/ilink/` sources at build time with its documented deltas (static GUID/model, no cdvdman imports) applied as a small patch step, and delete the copied tree; if the build system cannot do that today, at minimum add a CI byte/semantic diff check that fails when the trees diverge outside an allowlist. Deleting the copy is the goal; the check is the fallback.
- Benefit: One iLink implementation; fixes stop needing double-porting.
- Effort: L · Risk: Med · Confidence: High that the duplication and divergence exist (READ/diff), Med on the generation approach (INFERRED)

### W08-015 — Byte-identical 48,500-byte IRX blob stored twice in bdmassault
- Category: 7 build/CI/repo clutter
- Locations: `RiptOPL/modules/bdmassault/usbd.irx.ilink`, `RiptOPL/modules/bdmassault/usbd.irx.usbexfat`
- Problem: READ via `sha256sum` run this session: both files hash identically (and `PROVENANCE.md`'s own dedupe note says the mx4sio usbd is the same bytes again — the embedded copy is already deduplicated at the ELF level, only the repo copies are not). The repo carries the same 48,500-byte binary under two names so the POPSTARTER paste step can pick by filename.
- Fix: Keep one canonical file and create the second name at package/paste time (the equip code already selects by device type), or document the pair as generated in the build that assembles `ship/POPS/`. Do not keep two checked-in copies that can drift independently — if only one is ever re-vendored, the hashes in `PROVENANCE.md` stop telling the truth about the other.
- Benefit: −48,500 repo bytes and one less silent-drift pair.
- Effort: S · Risk: Low · Confidence: High (READ)

### W08-016 — Block cache keys blocks by unaligned request sector, defeating its own geometry
- Category: 5 performance (structural)
- Locations: `RiptOPL/modules/bdm/libbdm/src/bd_cache.c:88-171`
- Problem: READ. On a miss, `_read` refills 8 sectors starting at the **requested** sector and publishes the slot under that unaligned start (`c->sector[blkidx_best] = sector`). `_contains`/`_overlaps` then only match requests fully inside that arbitrary window. Sequential-but-offset access patterns (e.g. reads at 1, 9, 17… vs 0, 8, 16…) populate overlapping duplicate blocks, evict each other, and halve (or worse) the effective 128 KiB cache — on the driver every FAT/exFAT device reads metadata through. This is a structural claim only; no hardware behaviour is asserted.
- Fix: Align the refill and the slot key down to an 8-sector boundary (`sector & ~7`) and serve the request from the offset inside the block — the offset arithmetic already exists in the hit path.
- Benefit: One canonical block per 8-sector window; cache hit rate stops depending on caller alignment.
- Effort: S · Risk: Med (touches the most safety-critical file in the set; the existing host test for this cache should be extended, not bypassed) · Confidence: High (READ)

### W08-017 — fs_ioctl fabricates a 1024-byte argument length for fs_ioctl2
- Category: 6 bugs/security / 8 half-finished
- Locations: `RiptOPL/modules/bdm/bdmfs_fatfs/src/fs_driver.c:940-943`, consumers at `:845-875`
- Problem: READ. The legacy `fs_ioctl` entry point calls `fs_ioctl2(fd, cmd, data, 1024, NULL, 0)` regardless of the caller's real buffer size. `fs_ioctl2` now trusts `datalen` for the VMC allocation commands (`datalen != sizeof(request)` → `-EINVAL`), so those commands can never succeed via `ioctl` — and for any future command that copies `datalen` bytes from `data`, the fabricated length is an over-read waiting to happen. A wrapper that lies about a length is worse than one that refuses.
- Fix: Make `fs_ioctl` return `-EINVAL`/`-ENXIO` for commands that need a sized buffer (or forward only the size-less commands it historically served), instead of inventing 1024.
- Benefit: Removes a fabricated-length contract at a trust boundary.
- Effort: S · Risk: Low · Confidence: High (READ)

### W08-018 — bdmevent re-derives "unsupported sector size" by hand instead of using BDM's refused state
- Category: 2 duplication / 3 overengineering
- Locations: `RiptOPL/modules/bdmevent/main.c:443-483`; state already owned at `RiptOPL/modules/bdm/src/bdm.c:11-17,154-180`
- Problem: READ. BDM already tracks exactly which devices it refused and why (`refused` flag, set in `bdm_try_mount` with the 0-vs-non-512 distinction spelled out). bdmevent ignores that and re-implements the classification in its snapshot: scan all 20 slots, re-test `parNr == 0 && sectorSize != 0 && sectorSize != 512`, and identify USB roots by spelling `device->name` out character-by-character as `'u','s','b','\0'`. Two implementations of one policy, in two modules, kept in sync only by comments that quote each other's reasoning at length. When the refusal policy changes in BDM, the EE-facing diagnostic (error 500) will silently disagree.
- Fix: Export the refused/unsupported count (or a per-device refused query) from BDM — it already has the flag and already exports `bdm_get_bd` to this module — and delete bdmevent's re-derivation, keeping only the USB-root counting that is genuinely bdmevent's own concern.
- Benefit: One owner for the refusal policy; the diagnostic cannot drift from the behaviour it explains.
- Effort: M · Risk: Low · Confidence: High (READ)

### W08-019 — Dead field: fatfs mount-info `mount_status` is declared and never used
- Category: 1 dead code
- Locations: `RiptOPL/modules/bdm/bdmfs_fatfs/src/include/fs_driver.h:11`
- Problem: READ via grep over the module: `mount_status` appears only in the struct definition — no read or write anywhere in `fs_driver.c` or elsewhere in the module. Mount state is actually carried by `mounted_bd != NULL`, so the field is a second, permanently-stale source of truth for anyone reading the struct.
- Fix: Delete the field.
- Benefit: One less misleading field in the central mount struct.
- Effort: S · Risk: Low · Confidence: High (READ)

---

## COVERAGE

Read in full (line-verified for every citation):
- bdm: `src/bdm.c`, `src/main.c`, `src/part_driver.c`, `src/part_driver_mbr.c`, `src/part_driver_gpt.c`, `src/include/gpt_types.h`, `src/include/mbr_types.h`, `src/include/part_driver.h`, `src/include/module_debug.h`, `src/exports.tab`, `src/imports.lst`, `src/irx_imports.h`, `Makefile`, `ORIGIN.txt`; `libbdm/src/bd_cache.c`, `libbdm/src/bd_defrag.c`, `libbdm/include/bd_cache.h`, `libbdm/include/bd_defrag.h`, `libbdm/Makefile`; `bdmfs_fatfs/src/fs_driver.c`, `bdmfs_fatfs/src/main.c`, `bdmfs_fatfs/src/include/fs_driver.h`, `bdmfs_fatfs/fatfs/diskio.c`, `bdmfs_fatfs/ORIGIN.txt`.
- bdmassault: `PROVENANCE.md`, `ilink_bd_assault/README.md`, `ilink_bd_assault/Makefile`, `ilink_bd_assault/include/bdm.h`, `ilink_bd_assault/src/IEEE1394_bd/src/main.c`, `.../src/scsi.c`, `.../src/sbp2_driver.c` (full skim + targeted reads), all 9 `.irx.*` blobs (hashed with `sha256sum`, not disassembled).
- bdmevent: `main.c`, `Makefile`, `imports.lst`, `irx_imports.h` — all 4 files.
- mx4sio_bd: `src/mx4sio.c`, `src/spi_sdcard_driver.c`, `src/spi_sdcard_driver.h`, `src/spi_sdcard_driver_config.h`, `src/mx4sio.h`, `src/sio2man_hook.c`, `src/ioplib.c`, `src/crc16.c`, `src/spi_sdcard_crc7.c`, `Makefile`, `ORIGIN.md`.

Read structurally / partially (not line-by-line):
- `modules/bdm/bdmfs_fatfs/fatfs/ff.c` (7,257 lines) and `ffunicode.c` (15,593 lines): vendored FatFs — read `ffconf.h` in full, ff.c function inventory, and the specific functions the local driver depends on (`get_fat`, `clst2sect`, lock/reentrancy sections). Not audited line-by-line: it is a pinned upstream snapshot whose local deltas are documented in `ORIGIN.txt`; a line audit of stock FatFs is out of the LESS-NOT-MORE scope. `ffsystem.c`, `ff.h`, `diskio.h` skimmed.
- `modules/bdmassault/ilink_bd_assault/src/iLinkman/src/*.c` (~2,300 lines): function-level inventory and targeted reads (hook/callback, CROM, internal state); the SBP-2/SCSI layer above it was read closely. Not line-audited: vendored manager, and the actionable duplication is filed as W08-014.
- Small headers/import lists in bdmassault and mx4sio_bd (`irx_imports.h`, `imports.lst`, `exports.tab`, `sio2regs.h`, `ioplib.h`, `sio2man_hook.h`, CRC headers): skimmed for declarations; no findings arose from them.
- Licence files (`LICENSE` in bdm, bdmassault, mx4sio_bd): not read — licences are settled per instructions.

Files NOT read: none in scope beyond the partial-read qualifications above. Binary `.irx.*` blobs were hashed and sized, not disassembled (no source exists in-tree for 8 of the 9; the ilink one's source is the tree covered by W08-014).
