# POPSLoader — BDMAssault tarball audit (INDEPENDENT BLIND REDO)

- **Repo / pin:** NathanNeurotic/POPSLoader at `29272cddbf01`, read-only clone at `~/workspace/audit-clones-2026-11-13/POPSLoader`.
- **Subject:** `iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz`, md5 `09ff4b911ba131468a25d0ec9a4e2f27` (re-verified by `md5sum` in this run; the pre-extracted copy under `/tmp/redo-bdma/` had been cleaned, so the tree was re-extracted from the shipped tarball itself — same md5, 119 files).
- **Tree (scripted counts):** 119 files; 93 `.c`/`.h` files, 62,216 lines, 4,914,049 C/H bytes; 4,951,196 bytes total.
- **Rule applied:** LESS, NOT MORE. One mechanism = one finding; a defect present in both a component and its merged copy is one finding with both locations. All line numbers verified against the files as opened. All counts / diff sizes produced by script (`python3` + `difflib` / `md5sum` / `strings` / `readelf`), not estimated.
- **No disassembly was performed** on the shipped IRXs; binary work is `strings` / section structure / size only, per scope.

---

## Findings

### RE-POPS-BDM-01 — Partition parsers read a full device sector into a fixed 512-byte scratch buffer
- Category: 6
- Locations: tarball:bdm/src/part_driver_gpt.c:36,43-47,80; tarball:__bdm_assault/src/bdm/bdm_part_driver_gpt.c:36,43-47,80; tarball:bdm/src/part_driver_mbr.c:28,37; tarball:__bdm_assault/src/bdm/bdm_part_driver_mbr.c:28,37
- Problem: GPT allocates `512 * 2` bytes and uses the first and second 512-byte halves as header and entry-sector buffers, then calls `bd->read(bd, …, 1)`; MBR allocates `sizeof(master_boot_record)` (512 bytes) and reads 1 sector into it. A block-device `read` transfers `count × bd->sectorSize` bytes. `sectorSize` is device-supplied (see RE-POPS-BDM-11: SCSI sets it verbatim from READ CAPACITY). On a 1024/2048/4096-byte-sector device the GPT header read alone overruns its 512-byte half by up to 3,584 bytes of IOP heap, and the entry-sector read overruns the end of the allocation; MBR has the same overrun. GPT is internally inconsistent as well: `entriesPerSector` (line 69) is computed from the real `bd->sectorSize` while the buffer it indexes is sized for 512.
- Fix: Size both scratch allocations from `bd->sectorSize` (GPT: `2 × sectorSize`), and reject a device whose `sectorSize` is not a power of two in [512, 4096] before parsing.
- Benefit: Removes a device-triggerable heap overflow on the first code that touches an untrusted disk.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-02 — GPT partition size is off by one and an inverted range is accepted
- Category: 6
- Locations: tarball:bdm/src/part_driver_gpt.c:105,143; tarball:__bdm_assault/src/bdm/bdm_part_driver_gpt.c:105,143; tarball:bdm/src/include/gpt_types.h:51
- Problem: `gpt_types.h` documents `last_lba` as "Last LBA (inclusive)", but `sectorCount` is set to `last_lba - first_lba` instead of `last_lba - first_lba + 1`, so every GPT partition silently loses its final sector (a filesystem whose last sector holds backup metadata — e.g. the exFAT/FAT backup boot region at the end on some layouts, or simply the last cluster — is truncated). The bounds check at line 105 tests each LBA against the header range separately and never tests `last_lba >= first_lba`; an entry with `first_lba > last_lba` passes and `sectorCount` underflows to a near-2^64 value, handing the FS layer a partition that claims to cover the whole address space.
- Fix: Set `sectorCount = last_lba - first_lba + 1` and add `last_lba < first_lba` to the corrupt-entry rejection at line 105.
- Benefit: Partitions match the on-disk layout exactly, and a corrupt/malicious entry can no longer mint an unbounded partition.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-03 — GPT header fields are trusted unchecked: entry count, entry size, and a possible divide-by-zero
- Category: 6
- Locations: tarball:bdm/src/part_driver_gpt.c:57-73,80; tarball:__bdm_assault/src/bdm/bdm_part_driver_gpt.c:57-73,80; tarball:bdm/src/include/gpt_types.h:35-36
- Problem: After the 8-byte signature check, nothing else in the header is validated — the code's own TODO at lines 65-66 concedes revision, header size and both CRCs are unchecked. Three concrete consequences: (1) the scan loop is bounded only by the device-supplied `partition_count` (u32), so a corrupt header makes it issue one `bd->read` per sector far beyond the end of the disk/partition array until reads start failing; (2) `partition_entry_size` is ignored and entries are strided by `sizeof(gpt_partition_table_entry)` (128), so a table with any other legal entry size is parsed at wrong offsets; (3) `entriesPerSector = bd->sectorSize / sizeof(gpt_partition_table_entry)` is 0 when `sectorSize < 128`, and `i % entriesPerSector` / `i / entriesPerSector` then divide by zero.
- Fix: Validate before scanning: `header_size` in [92, sectorSize], `partition_entry_size == sizeof(gpt_partition_table_entry)` (or stride by it), `partition_count` capped so `partition_table_lba + ceil(count × entry_size / sectorSize)` stays inside the device, and `entriesPerSector > 0`.
- Benefit: A corrupt or hostile GPT can no longer drive unbounded reads, misaligned parsing, or a divide-by-zero trap in IOP code.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-04 — MBR partitions are mounted with no bounds, type, or extended-partition handling
- Category: 6
- Locations: tarball:bdm/src/part_driver_mbr.c:64-91; tarball:__bdm_assault/src/bdm/bdm_part_driver_mbr.c:64-91
- Problem: Any of the four primary entries with `sector_count != 0` is mounted verbatim: `first_lba + sector_count` is never checked against `bd->sectorCount`, so a partition can claim space past the end of the device (later reads/writes are passed through, see RE-POPS-BDM-06); `partition_type == 0x00` (empty) with a non-zero count is mounted; and extended types (0x05/0x0F/0x85) are mounted as if they were data partitions instead of being followed to the logical partitions — the code's own TODO at line 72 ("Filter out unsupported partition types") is unimplemented. Only entry [0] is tested for the GPT-protective type 0xEE.
- Fix: Reject entries with type 0, reject/skip extended types (or follow the EBR chain), and require `(u64)first_lba + sector_count <= bd->sectorCount` before connecting.
- Benefit: The partition layer stops inventing filesystems out of table garbage and stops handing out-of-device ranges to the FS layer.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-05 — MBR parser leaks its allocation on the read-failure path
- Category: 6
- Locations: tarball:bdm/src/part_driver_mbr.c:37-43; tarball:__bdm_assault/src/bdm/bdm_part_driver_mbr.c:37-43
- Problem: If `bd->read(bd, 0, pMbrBlock, 1)` fails, the function returns without `FreeSysMemory(pMbrBlock)` — every other exit path in the same function frees it. `part_connect_mbr` is attempted for every newly connected block device (MBR is registered before GPT and FatFs in `part_init`/`bdm_try_mount`), so each unreadable or non-MBR device that fails at the read step leaks 512 bytes of IOP memory permanently; there is no recovery short of reboot.
- Fix: Free `pMbrBlock` before the return at line 42.
- Benefit: Removes a slow, per-device permanent IOP memory leak on a hot plug/unplug path.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-06 — Partition read/write pass-through enforces no partition bounds at all
- Category: 6
- Locations: tarball:bdm/src/part_driver.c:52-80; tarball:__bdm_assault/src/bdm/bdm_part_driver.c:52-80
- Problem: `part_read`/`part_write` check only that `part` and `part->bd` are non-NULL, then forward `sector + bd->sectorOffset` with the caller's `count`. `bd->sectorCount` — the field that exists precisely to bound the partition — is never consulted, in either function. Any caller (or any corrupt FS metadata that makes FatFs request a sector past the partition end) reads or **writes** into the neighbouring partition or unpartitioned space. Combined with RE-POPS-BDM-02/-04, the partition abstraction provides no containment anywhere.
- Fix: Return -1 when `sector + count > bd->sectorCount` (with `count` widened before the addition) in both `part_read` and `part_write`.
- Benefit: One two-line check per direction converts cross-partition corruption from silent to impossible via this layer.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-07 — Block cache marks a block valid and serves it even when the device read failed
- Category: 6
- Locations: tarball:libbdm/src/bd_cache.c:115-123
- Problem: On a cache miss, `_read` calls `c->bd->read(c->bd, sector, c->cache[blkidx_best], SECTORS_PER_BLOCK)` and **ignores the return value**, unconditionally sets `c->sector[blkidx_best] = sector`, copies `count` sectors out of the buffer, and returns `count` (success). A failed or short read therefore returns stale previous contents (or uninitialised memory on first use) to FatFs as if it were the requested sector — metadata corruption is then interpreted as filesystem structure, and a later write-back can persist decisions made on garbage. This is the cache-correctness-on-failed-reads defect in its purest form: the error is not propagated at all.
- Fix: Capture the read result; on anything other than a full `SECTORS_PER_BLOCK` transfer, leave the slot invalidated (`sector = 0xffffffffffffffff`) and return the error/short count to the caller.
- Benefit: Device errors surface as errors instead of being laundered into plausible-looking filesystem data.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-08 — Block cache hard-codes 512-byte sectors in its block geometry
- Category: 6
- Locations: tarball:libbdm/src/bd_cache.c:8,17,85-86,116-122
- Problem: The cache block is `SECTORS_PER_BLOCK × 512` bytes, offsets are computed as `(sector - cached_sector) * 512`, and the fill reads `SECTORS_PER_BLOCK` sectors into that block. All of it assumes `bd->sectorSize == 512`, but nothing in `bd_cache_create` checks `sectorSize`, and the value is device-supplied. With a 4096-byte-sector device the fill writes 8 × 4096 = 32 KiB into a 4 KiB cache slot (heap overflow), and with any non-512 size the offset arithmetic serves the wrong bytes even when it does not overflow. The cache is created for every whole device (`bdm.c:60`), so this is on the default path, not an opt-in.
- Fix: Either refuse to wrap devices with `sectorSize != 512` in `bd_cache_create` (return the raw `bd` / NULL so BDM uses it uncached), or size blocks and offsets from `bd->sectorSize`.
- Benefit: Removes a second device-triggerable heap overflow and silent data mis-serving for non-512-sector media.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-09 — bd_cache_create dereferences unchecked allocations
- Category: 6
- Locations: tarball:libbdm/src/bd_cache.c:160-166,179-191
- Problem: `bd_cache_create` performs two `AllocSysMemory` calls and immediately writes through both results (`c->bd = bd`, `cbd->priv = c`, …) with no NULL check. Under IOP memory pressure (see RE-POPS-BDM-27: each cache is 128 KiB) allocation failure is a realistic event, and the failure mode is a wild-pointer write during device connect rather than a clean "no cache" fallback that `bdm_connect_bd` could otherwise tolerate (`cbd` is already allowed to be NULL there).
- Fix: Check both allocations; on failure free whichever succeeded and return NULL.
- Benefit: Memory exhaustion degrades to uncached I/O instead of crashing the IOP on device insertion.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-10 — SCSI warmup failure is ignored, sense data is read uninitialised, and TEST UNIT READY can spin forever
- Category: 6
- Locations: tarball:usbmass_bd/src/scsi.c:127-176,272-285; tarball:__usbd_bd_assault/src/usbmass_bd/usbmass_bd_scsi.c:127-176,272-285
- Problem: Three linked defects in one flow. (1) `scsi_connect` calls `scsi_warmup(bd)` and discards its return value, then calls `bdm_connect_bd(bd)` unconditionally — a device whose INQUIRY or READ CAPACITY failed is published with whatever `sectorSize`/`sectorCount` a previous device left in the recycled `g_scsi_bd[]` slot (disconnect clears only `priv`). (2) In the TEST UNIT READY loop, `sense_data sd` is never initialised or cleared; when `scsi_cmd_request_sense` fails the code logs it and then still evaluates `sd.error_code`/`sd.sense_key` — stack garbage decides whether START STOP UNIT is sent. (3) The `while ((stat = scsi_cmd_test_unit_ready(bd)) != 0)` loop has no retry bound and no delay: a device that never becomes ready (or whose sense data never matches the one handled case) hangs the USB mass update thread forever, taking all later device handling with it.
- Fix: Make `scsi_connect` connect only when `scsi_warmup` returns 0 (and zero the slot's geometry on disconnect); `memset` the sense buffer per iteration and skip its evaluation when REQUEST SENSE fails; bound the ready loop (e.g. the same 16-retry discipline used elsewhere in the file) with a delay between attempts.
- Benefit: Failed devices stay unpublished instead of appearing with another device's geometry, and one bad device can no longer wedge USB storage permanently.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-11 — SCSI capacity is off by one and the device-supplied block length is never validated
- Category: 6
- Locations: tarball:usbmass_bd/src/scsi.c:168-176; tarball:__usbd_bd_assault/src/usbmass_bd/usbmass_bd_scsi.c:168-176
- Problem: READ CAPACITY (10) returns the address of the **last** logical block, but the code stores it directly: `bd->sectorCount = getBI32(&rcd.last_lba)` — the device is thereafter one sector short, so the final sector of every USB disk is unreachable (and a 1-sector device reports 0). In the same three lines, `bd->sectorSize = getBI32(&rcd.block_length)` is accepted verbatim: a device returning 0 makes the very next statement divide by `bd->sectorSize` twice (`(1000*1000) / bd->sectorSize`) — a divide-by-zero trap — and any non-power-of-two or non-512 value flows onward into the partition parsers and cache of RE-POPS-BDM-01/-08 and into FatFs, which in this tree is configured `FF_MIN_SS == FF_MAX_SS == 512` so its variable-sector-size sanity check (ff.c:3387) is compiled out entirely.
- Fix: Store `sectorCount = last_lba + 1` (as u64, saturating), and reject the device in warmup unless `block_length` is a power of two in [512, 4096].
- Benefit: Full device capacity becomes addressable, and the single validation point closes the input that three other findings depend on.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-12 — Mount-info lookup accepts the one-past-the-end index (and negative indices)
- Category: 6
- Locations: tarball:bdmfs_fatfs/src/fs_driver.c:137-152; tarball:__bdm_assault/src/bdmfs/bdmfs_fs_driver.c:137-152
- Problem: `fatfs_fs_driver_get_mounted_bd_from_index` guards with `if (mount_info_index > FATFS_FS_DRIVER_MOUNT_INFO_MAX)` — with `FF_VOLUMES == 10` the valid indices are 0-9, so index 10 passes the guard and reads `fs_driver_mount_info[10]`, one element past the array. Negative indices are not checked at all and read before the array. The function is called with `fd->unit` (fs_devctl / GET_DRIVERNAME path), with FatFs's `pdrv`, and from `diskio.c` for every disk operation, so the out-of-bounds pointer it returns is dereferenced by callers that treat non-NULL as "mounted".
- Fix: Reject `mount_info_index < 0 || mount_info_index >= FATFS_FS_DRIVER_MOUNT_INFO_MAX`.
- Benefit: Removes an out-of-bounds read whose result gates device I/O, on the driver's most-called helper.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-13 — fs_ioctl2 / fragment-list paths dereference a possibly-NULL mounted block device
- Category: 6
- Locations: tarball:bdmfs_fatfs/src/fs_driver.c:624-653,681-714; tarball:__bdm_assault/src/bdmfs/bdmfs_fs_driver.c:624-653,681-714
- Problem: Three sites take the result of `fatfs_fs_driver_get_mounted_bd_from_index(...)` and dereference it without the NULL check that the neighbouring `USBMASS_IOCTL_GET_DEVICE_NUMBER` case (lines 716-733) correctly performs: (1) `USBMASS_IOCTL_GET_LBA` computes `clst2sect(...) + bd->sectorOffset` with `bd` unchecked; (2) `USBMASS_IOCTL_GET_DRIVERNAME` guards only its return-value expression with a ternary, then unconditionally executes `strncpy(rdata, mounted_bd->name, rdatalen)` whenever `rdata != NULL` — exactly the call shape a caller uses to actually get the name; (3) `get_frag_list` (backing GET_FRAGLIST and CHECK_CHAIN) dereferences `bd->sectorOffset` inside its loop with `bd` unchecked. An ioctl on a file whose volume has been unmounted (device yanked — the normal failure mode for removable USB) is a NULL dereference in IOP code.
- Fix: NULL-check `bd`/`mounted_bd` at all three sites and return `-ENXIO`, matching the GET_DEVICE_NUMBER case in the same switch.
- Benefit: The removable-media race stops being a crash; the fix is copyable from ten lines below two of the defects.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-14 — fs_devctl dispatches STOP_UNIT to stop-all and STOP_ALL to stop-one
- Category: 6
- Locations: tarball:bdmfs_fatfs/src/fs_driver.c:767-797; tarball:__bdm_assault/src/bdmfs/bdmfs_fs_driver.c:767-797
- Problem: In `fs_devctl`, `case USBMASS_DEVCTL_STOP_UNIT:` calls `fatfs_fs_driver_stop_all_bd()` and `case USBMASS_DEVCTL_STOP_ALL:` calls `fatfs_fs_driver_stop_single_bd(fd->unit)` — the two handlers are transposed relative to their command names. A caller asking to stop one unit (e.g. before ejecting one drive) unmounts and stops **every** mounted device; a caller asking to stop all devices stops only its own unit and leaves the rest spinning/mounted. (The command constants come from the external `usbhdfsd-common.h`, not present in the tarball; the finding rests on the plain meaning of the names as used in this switch, which is also how the helper functions are named.)
- Fix: Swap the two bodies so STOP_UNIT stops `fd->unit` and STOP_ALL stops all.
- Benefit: Devctl callers get the stop scope they asked for; multi-device users stop losing unrelated mounts.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-15 — Fragment-list walk can loop forever on a cyclic FAT chain, holding the global FS lock
- Category: 6
- Locations: tarball:bdmfs_fatfs/src/fs_driver.c:624-653,656-665; tarball:__bdm_assault/src/bdmfs/bdmfs_fs_driver.c:624-653,656-665
- Problem: `get_frag_list` walks the file's cluster chain with a `do { … } while (iClusterCurrent < file->obj.fs->n_fatent)` loop whose only progress assumption is that `get_fat` eventually returns an end-of-chain or out-of-range value. A corrupt FAT (exactly what removable, possibly-dirty exFAT/FAT media provides) containing a cycle whose links are not `current + 1` — e.g. two clusters pointing at each other — makes `iClusterCurrent` oscillate below `n_fatent` forever, emitting a "fragment" per iteration. Both callers (`USBMASS_IOCTL_CHECK_CHAIN`, `USBMASS_IOCTL_GET_FRAGLIST`) run under `_fs_lock()`, so the hang is not confined to one ioctl: every filesystem operation on every volume blocks behind it permanently.
- Fix: Bound the walk by the maximum possible chain length (file size in clusters, or `n_fatent` iterations total) and bail with an error past it.
- Benefit: Corrupt media degrades to an ioctl error instead of a total, unrecoverable FS-driver hang.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-16 — USB mass connect walks endpoint descriptors on device-supplied lengths with no NULL or bounds check
- Category: 6
- Locations: tarball:usbmass_bd/src/usb_mass.c:593-670; tarball:__usbd_bd_assault/src/usbmass_bd/usbmass_bd_usb_mass.c:593-670
- Problem: `usb_mass_connect` takes the first endpoint from `sceUsbdScanStaticDescriptor(devId, NULL, USB_DT_ENDPOINT)` and passes it straight to `usb_bulk_probeEndpoint`, which dereferences `endpoint->bmAttributes` — a NULL result (device with no endpoint descriptor in its static set) is a NULL dereference. It then steps `endpoint = (UsbEndpointDescriptor *)((char *)endpoint + endpoint->bLength)` for `interface->bNumEndpoints - 1` further steps, trusting the device-supplied `bLength` each time: `bLength == 0` re-probes the same descriptor repeatedly, and a small/large `bLength` walks outside the configuration descriptor block (whose total length, `config->wTotalLength`, `usb_mass_probe` checked but `connect` never uses). `connect` also re-derives the interface as `config + config->bLength` without re-checking any of the class/subclass/protocol/endpoint-count conditions `probe` validated.
- Fix: NULL-check the first endpoint, and bound each step: require `bLength >= sizeof(UsbEndpointDescriptor)` and the stepped pointer to remain within `config + config->wTotalLength`; bail via the existing not-enough-endpoints path otherwise.
- Benefit: A malformed or malicious USB device can no longer crash or misdirect the mass-storage connect path — the path every USB disk takes.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-17 — Isochronous done-queue cleanup clears the wrong LUT slot
- Category: 6
- Locations: tarball:usbd/src/usbd.c:126-155; tarball:__usbd_bd_assault/src/usbd/usbd_usbd.c:126-155
- Problem: In `processDoneQueue_IsoTd`'s halted-endpoint sweep, each queued TD `curTd` is freed and its request looked up correctly (`hcIsoTdToIoReqLUT[curTd - hcIsoTdBuf]`), but the slot that is then cleared is `hcIsoTdToIoReqLUT[arg - hcIsoTdBuf]` — the already-processed TD's slot, cleared a second time — instead of `curTd`'s. Every swept isochronous request therefore leaves a stale LUT entry pointing at a freed/re-issued request, which a later done-queue pass will interpret as a live request for an unrelated TD. The generic-TD twin of this code (`processDoneQueue_GenTd`) clears the correct per-TD slot, confirming the intent.
- Fix: Clear `memPool.hcIsoTdToIoReqLUT[curTd - memPool.hcIsoTdBuf]` in the sweep.
- Benefit: Removes a stale-pointer source in the USB core's completion path (latent for mass storage, live for any isochronous client of this USBD).
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-18 — Callback thread reads the request after freeing it (GP-register build only)
- Category: 6
- Locations: tarball:usbd/src/driver.c:241-255; tarball:__usbd_bd_assault/src/usbd/usbd_driver.c:241-255; tarball:__usbd_bd_assault/src/usbd/usbd_usbd_driver.c:241-255
- Problem: `callbackThreadFunc` carefully copies the request (`memcpy(&reqCopy, req, …)`), frees the original (`freeIoRequest(req)` — returning it to a pool other threads allocate from), and then, under `#if USE_GP_REGISTER`, executes `SetGP(req->gpSeg)` — reading the **freed** request instead of `reqCopy.gpSeg`. `USE_GP_REGISTER` is not defined anywhere in the tarball (it would come from the PS2SDK build environment), so this is latent in the shipped configuration, but the copy exists precisely to make the post-free code safe and this one line defeats it.
- Fix: Use `reqCopy.gpSeg`.
- Benefit: Closes a use-after-free read that activates the moment the driver is built with GP-register support.
- Effort: S · Risk: Low · Confidence: Low (READ — conditional on a macro defined outside the tarball)

### RE-POPS-BDM-19 — Static-descriptor search takes its first step on an unchecked descriptor length
- Category: 6
- Locations: tarball:usbd/src/hcd.c:195-213; tarball:__usbd_bd_assault/src/usbd/usbd_hcd.c:195-213
- Problem: `doGetDeviceStaticDescriptor(devId, data, type)` computes its starting point as `data + ((UsbDeviceDescriptor *)data)->bLength` when `data != NULL`, with no check that `data`'s `bLength` is sane or that the result stays inside the device's static descriptor block (`staticDeviceDescPtr .. staticDeviceDescEndPtr`). The subsequent `while` loop does bounds- and `bLength >= 2`-checks, but they guard a pointer that may already be out of bounds, and its first dereference reads the purported `bLength` there. Every hub/USB-mass descriptor lookup in the tree funnels through this function with descriptor pointers ultimately derived from device-supplied bytes.
- Fix: Validate the initial step against `staticDeviceDescEndPtr` (and `bLength >= 2`) before entering the loop, returning NULL on violation.
- Benefit: One guard at the choke point hardens every descriptor walk built on it (hub connect, mass probe/connect).
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-20 — FatFs re-entrancy grant ignores its own timeout
- Category: 6
- Locations: tarball:bdmfs_fatfs/src/ffsystem.c:146-168; tarball:bdmfs_fatfs/src/include/ffconf.h:279-280; tarball:__bdm_assault/src/bdmfs/bdmfs_ffsystem.c:146-168
- Problem: `ffconf.h` sets `FF_FS_REENTRANT 1` with `FF_FS_TIMEOUT 1000`, and the FatFs contract is that `ff_req_grant` returns 0 on timeout so the caller fails with `FR_TIMEOUT`. The IOP implementation calls `WaitSema(sobj)` — which waits indefinitely — and unconditionally returns 1. Any volume lock leaked or held by a stuck operation therefore hangs every subsequent FatFs call on that volume forever instead of surfacing a timeout, compounding RE-POPS-BDM-15's lock-hang surface.
- Fix: Use a timed wait (poll/`iWaitSema` with the timeout) and return 0 when it expires, per the sample contract in the same file's comments.
- Benefit: Restores the designed failure mode (an error) in place of an unbounded hang.
- Effort: S · Risk: Med · Confidence: High (READ)

### RE-POPS-BDM-21 — The entire merged-driver tree is a second, hand-maintained copy of every component (ffunicode alone is 79% of the tarball)
- Category: 2
- Locations: tarball:__bdm_assault/ (whole tree); tarball:__usbd_bd_assault/ (whole tree); tarball:bdmfs_fatfs/src/ffunicode.c:1-15593; tarball:__bdm_assault/src/bdmfs/bdmfs_ffunicode.c:1-15593
- Problem: Scripted totals: component + libbdm C/H = 2,469,099 bytes; merged C/H = 2,444,950 bytes — i.e. essentially the whole codebase exists twice, kept in sync by hand-renaming (`bdm_`, `bdmfs_`, `usbd_`, `usbmass_bd_` prefixes) and hand-editing include paths and `_start` symbols (see the diff table below: every merged file is its component with 0-6 substituted lines). The extreme case is vendored FatFs unicode data: `ffunicode.c` is 1,959,389 bytes and its merged copy 1,959,397 bytes — together 3,918,786 bytes, **79.1% of the tarball's 4,951,196 total bytes** (79.7% of its C/H bytes), for a file whose compiled content is already narrowed to one code page by `FF_CODE_PAGE 869` (ffconf.h:101; the per-page tables are `#if`-guarded, ffunicode.c:38). Every future fix — including every Cat-6 fix above — must be applied twice, in two differently-named files, with no script or CI step that verifies the copies still match (see RE-POPS-BDM-33).
- Fix: Generate the merged trees from the components at build time (copy + the three mechanical transforms the diff table shows: prefix rename, `include/` path prefix, `_start` chaining), and delete the checked-in merged copies; or, failing that, add a CI diff gate that fails when a merged file differs from its component by anything except the whitelisted transforms.
- Justification: The fix adds a small generator/gate, but it deletes ~2.44 MB of hand-maintained duplicate source and the entire class of component↔merged drift — a net deletion.
- Benefit: One source of truth per file; fixes land once; the tarball shrinks by roughly half.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-BDM-22 — Dead duplicate files inside __usbd_bd_assault that its Makefile never compiles
- Category: 1
- Locations: tarball:__usbd_bd_assault/src/usbd/usbd_usbd_driver.c:1-284; tarball:__usbd_bd_assault/src/usbd/irx_imports.h:1-31
- Problem: Scripted diff: `usbd_usbd_driver.c` is byte-identical to `usbd_driver.c` (both byte-identical to component `usbd/src/driver.c`, 6,965 bytes), and the nested `src/usbd/irx_imports.h` is byte-identical to component `usbd/src/irx_imports.h` (md5 `2f4308b0…`). The merged Makefile builds `usbd_driver.o` from `usbd_driver.c` via its `src/usbd/%.c` pattern and takes imports from `src/`; neither dead file is referenced by any object list, pattern, or include in the merged tree (its own `src/irx_imports.h`, a different merged file, is the live one). They are pure drift bait: a future edit to `usbd_usbd_driver.c` would compile into nothing while looking like the USBD driver.
- Fix: Delete both files.
- Benefit: Removes 7,745 bytes of misleading dead source from the tree that actually ships.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-23 — A complete second, never-compiled ASYNC implementation of usb_queue_cmd is carried in-line
- Category: 1
- Locations: tarball:usbmass_bd/src/usb_mass.c:17,380-410,476-540; tarball:__usbd_bd_assault/src/usbmass_bd/usbmass_bd_usb_mass.c:17,380-410,476-540
- Problem: `// #define ASYNC` (line 17) is commented out and nothing in any Makefile defines `ASYNC`, so the `#else` half of `usb_queue_cmd` — a full asynchronous CBW/data/CSW pipeline — plus its exclusive support code (`struct usbmass_cmd`, `scsi_cmd_callback`) is dead in every build this tree can produce. Conversely the live synchronous helpers (`usb_bulk_reset`, `usb_bulk_status`, `usb_bulk_manage_status`, `usb_bulk_command`, `usb_bulk_transfer`) are wrapped in `#ifndef ASYNC`, so the file permanently carries two implementations of the driver's core operation, only one of which is ever tested by being compiled.
- Fix: Delete the `ASYNC` branch, `scsi_cmd_callback`, and `struct usbmass_cmd`; unwrap the `#ifndef ASYNC` guards.
- Benefit: ~90 lines of uncompilable, untestable code stop shadowing the real transfer path in every future read or edit.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-24 — libbdm ships bd_defrag, which nothing in the package calls
- Category: 1
- Locations: tarball:libbdm/src/bd_defrag.c:1-102; tarball:libbdm/include/bd_defrag.h:1-31; tarball:libbdm/Makefile:14
- Problem: Scripted grep over all 119 tarball files: `bd_defrag_read`/`bd_defrag_write` appear only in their own definition, header, and the libbdm Makefile object list. No component, no merged driver, and no other library in the tarball calls them — the FatFs driver *produces* fragment lists via ioctl (fs_driver.c `get_frag_list`) but the consumer of such lists lives outside this package (in the host app's own drivers). Within BDMAssault as shipped, `bd_defrag.o` is compiled into `libbdm.a` on every build and can only ever be dead weight (a static archive member that no link here pulls).
- Fix: Drop `bd_defrag.o` from the libbdm build in this package (keep the source out of the tarball, or keep the file and remove it from `IOP_OBJS` with a note that external consumers build it themselves).
- Benefit: One less unmaintained 102-line module compiled on every CI run of a package that never uses it.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-25 — ffsystem.c carries dead sample code for four other operating systems
- Category: 1
- Locations: tarball:bdmfs_fatfs/src/ffsystem.c:15-201; tarball:__bdm_assault/src/bdmfs/bdmfs_ffsystem.c:15-201
- Problem: Of this 201-line file, the live IOP code is roughly 60 lines. The rest is ChaN's sample scaffolding: `ff_memalloc`/`ff_memfree` compiled only under `FF_USE_LFN == 3` while this tree sets `FF_USE_LFN 2` (ffconf.h:107), and, inside every sync-object function, an `#if 0` block quoting Win32, µITRON, µC/OS-II, FreeRTOS and CMSIS-RTOS variants. It is vendored-sample clutter that every reader must skip to find the four small semaphore wrappers that actually run.
- Fix: Trim the file to the IOP implementations (keeping the FatFs header comment and licence line).
- Benefit: The OS-glue file becomes readable at a glance; no behavioural change.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-26 — Cache eviction is a fixed-point weight/aging scheme where a trivial policy suffices
- Category: 3
- Locations: tarball:libbdm/src/bd_cache.c:10,79-122
- Problem: Eviction for a 32-entry, read-through, write-invalidate sector cache is implemented as per-block signed "weights" in 24.8 fixed point, bumped by `count × 256` on hit, decayed on every miss by `(8 × 256 / 32) + weight/32`, clamped at 0 only on the hit path, and scanned for a minimum whose initial sentinel is `0x7fffffff`. Nothing in the workload (sequential FAT/directory reads by one FS driver) needs hit-frequency weighting, the arithmetic's failure modes are non-obvious (weights drift negative between hits, making untouched blocks progressively *less* evictable the more misses occur elsewhere), and the whole scheme exists to choose a victim among 32 slots — a round-robin or simple LRU counter does the same job in a handful of obviously-correct lines.
- Fix: Replace weight/aging with a single rotating victim index (or a last-used counter per block) and delete `BLOCK_WEIGHT_FACTOR` and the aging loop.
- Justification: The replacement is strictly less code than what it removes; no addition is proposed.
- Benefit: ~40 lines of subtle arithmetic leave the I/O path; eviction behaviour becomes predictable and auditable.
- Effort: S · Risk: Med · Confidence: Med (READ)

### RE-POPS-BDM-27 — The block cache reserves 128 KiB of IOP RAM per whole device
- Category: 4
- Locations: tarball:libbdm/src/bd_cache.c:8-9,17; tarball:bdm/src/bdm.c:59-60
- Problem: `struct bd_cache` embeds `cache[32][8 × 512]` = 131,072 bytes, allocated per whole-device in `bdm_connect_bd` (`parNr == 0` → `bd_cache_create`). The IOP has 2 MiB total; this package's own USB stack supports 2 mass devices (`NUM_DEVICES 2` in both usbmass files), so the caches alone can claim 256 KiB — 12.5% of IOP RAM — before the USBD pools, FatFs structures (RE-POPS-BDM-29) and thread stacks are counted, and `bd_cache_create`'s unchecked allocations (RE-POPS-BDM-09) are what stand between that appetite and a crash. No measurement or comment in the tree justifies 32 blocks over, say, 8 (32 KiB), for a workload dominated by FAT and directory scans.
- Fix: Reduce `BLOCK_COUNT` to 8 unless a benchmark on real hardware shows otherwise, and note the per-device cost at the define.
- Benefit: Frees up to 192 KiB of IOP RAM across two devices — headroom the rest of this driver stack visibly needs.
- Effort: S · Risk: Med · Confidence: High (READ — sizes are arithmetic from the defines; the "no justification in tree" part is a full-text search result)

### RE-POPS-BDM-28 — USBD always builds its largest pool configuration; the MINI_DRIVER configuration is unreachable
- Category: 4
- Locations: tarball:usbd/src/usbd.c:33-68; tarball:usbd/src/driver.c:273-277; tarball:usbd/src/hcd.c:522-526
- Problem: `usbd.c` contains two `UsbdConfig` tables: the default (32 devices, 64 endpoints, 128+128 transfer descriptors, 256 I/O requests, 8 hubs × 8 ports) and a `MINI_DRIVER` table at roughly half those sizes, with matching halved thread stacks in driver.c/hcd.c. No Makefile in the tarball (component or merged) ever defines `MINI_DRIVER`, and in the merged tree the symbol survives only as the unrelated printf-suppression switch in `module_debug.h`. The shipped USBD therefore always allocates the full-size pools (sized in `initHcdStructs` from these numbers) to serve a package whose only client driver supports at most 2 mass-storage devices behind at most one hub layer.
- Fix: Either define `MINI_DRIVER` for the BDMAssault builds after a hardware smoke test, or delete the dead alternative table so the real footprint is the only thing a reader sees.
- Benefit: Up to ~half the USBD pool allocation (devices/endpoints/TDs/requests/descriptor buffers scale directly from these fields) if enabled; an honest tree if deleted.
- Effort: S · Risk: Med · Confidence: High (READ — "never defined" is a full-tree grep result)

### RE-POPS-BDM-29 — fs_driver statically reserves 128 FIL and 16 DIR objects regardless of need
- Category: 4
- Locations: tarball:bdmfs_fatfs/src/fs_driver.c:231-236; tarball:__bdm_assault/src/bdmfs/bdmfs_fs_driver.c:231-236
- Problem: `static FIL fil_structures[128]` and `static DIR dir_structures[16]` sit in BSS permanently. Even in the `FF_FS_TINY 1` configuration this tree uses, a `FIL` carries the shared-object header, cluster state and pointers (tens of bytes), so the file table alone is several KiB of IOP RAM reserved for a driver whose host applications (POPStarter-class loaders) hold a handful of files open at once — and whose own global lock serialises all access anyway. No comment or measurement supports 128.
- Fix: Size `MAX_FILES`/`MAX_DIRS` to a stated, realistic concurrent-open count (e.g. 16/4) and note the BSS cost at the define.
- Benefit: Several KiB of permanent IOP BSS returned for the lifetime of the module.
- Effort: S · Risk: Med · Confidence: Med (READ — counts are exact; per-object byte size is configuration-dependent and was not measured from a build)

### RE-POPS-BDM-30 — A failing sector is retried 16 times end-to-end with no delay, reset, or backoff
- Category: 5
- Locations: tarball:usbmass_bd/src/scsi.c:13,184-246; tarball:__usbd_bd_assault/src/usbmass_bd/usbmass_bd_scsi.c:13,184-246
- Problem: `scsi_read`/`scsi_write` wrap each chunk in `for (retries = SCSI_MAX_RETRIES; retries > 0; retries--)` — 16 immediate re-issues of the identical command. Each attempt already runs the full BOT exchange including `usb_bulk_manage_status`'s stall-clear and reset-recovery (usb_mass.c), so a genuinely failing sector (bad media, spun-down drive) costs 16 full command+recovery cycles back-to-back, with no `DelayThread`, no REQUEST SENSE inspection between attempts, and no unit reset — maximising both the latency of the inevitable `-EIO` (multiplied across every chunk of a large transfer) and the chance of keeping a marginal device in its error state. Structurally, retry policy lives at the wrong layer: the transport already recovered or it didn't.
- Fix: Cut the loop to a small number (2-3), inspect sense data between attempts, and add a short delay; let persistent failure return `-EIO` promptly.
- Benefit: Worst-case error latency on bad media drops by roughly the retry factor, and healthy transfers are unaffected.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-31 — Tarball CI builds only the merged drivers and libbdm; the five component modules are never compiled
- Category: 7
- Locations: tarball:.github/workflows/CI.yml:33-46
- Problem: The only CI in the tarball runs `make -C libbdm`, `make -C __bdm_assault/`, `make -C __usbd_bd_assault/` — `bdm/`, `bdmfs_fatfs/`, `usbd/`, and `usbmass_bd/` have Makefiles but no CI coverage, so a component that stops compiling is invisible, and (with RE-POPS-BDM-21) nothing detects component↔merged drift either. The workflow also pins nothing: `actions/checkout@v3`, `actions/upload-artifact@v3`, and `marvinpinto/action-automatic-releases@latest`, and it publishes a "latest" prerelease from every push to main.
- Fix: Add the four component builds to the CI matrix (they are cheap IOP cross-compiles in the same container) and pin actions to full versions/SHAs.
- Benefit: The components stop being write-only source, and drift between the two copies of everything becomes a CI failure instead of a surprise.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-32 — Merged USBD Makefile adds an include directory that does not exist
- Category: 7
- Locations: tarball:__usbd_bd_assault/Makefile:9
- Problem: `IOP_INCS += -Isrc/usbd/include` — verified by directory listing: `__usbd_bd_assault/src/usbd/` contains its headers directly and has **no** `include/` subdirectory (unlike `src/usbmass_bd/include/`, which exists). The flag is inert today only because the headers are found via the source directory itself; it is leftover from an assumed layout and will silently mask a future header move (files keep resolving from the old place, or fail confusingly elsewhere).
- Fix: Delete the `-Isrc/usbd/include` flag (or create the directory and actually move the headers — deletion is the LESS option).
- Benefit: The build description matches the tree; one less phantom path for the next editor to trust.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-33 — Shipped usbhdfsd.irx cannot be accounted for by the tarball, and the tarball's second driver is absent from the shipped set
- Category: 7
- Locations: iop/embed/BDMASSAULT_MX4SIO/usbhdfsd.irx (14,993 bytes, shipped); iop/embed/BDMASSAULT_MX4SIO/usbd.irx (48,500 bytes, shipped); tarball:README.MD:13-16; tarball:.github/workflows/CI.yml:38-41
- Problem: See the correspondence section below for the full evidence. In short: the tarball's own README and CI say the pair is `bdm_assault.irx` → shipped as `usbd.irx` and `usbd_bd_assault.irx` → shipped as `usbhdfsd.irx`. The first half holds (string-exact). The second does not: the shipped `usbhdfsd.irx` is an **MX4SIO v1.2** driver (strings `MX4SIO: …`, module name `mx4sio`, imports `sio2man`/`dmacman`/`modload`) — a driver for the SD-card SIO2 adapter, with **no source anywhere in the tarball** (no file mentions MX4SIO or SIO2) — while the tarball's actual `usbd_bd_assault` product (USB core + USB mass storage, strings such as `USBD ASSAULT Start` / `USBD ASSAULT: starting USBMASS Side`) appears in **neither** shipped binary. The shipped set is therefore half-provenance-free, and anyone rebuilding from the tarball cannot reproduce it. (Whether POPSLoader intentionally pairs BDM-Assault-for-USBD with an MX4SIO driver in the USBHDFSD slot is a packaging decision outside this tarball; the finding is that the tarball + README do not disclose it.)
- Fix: Ship the MX4SIO driver's source (or a provenance note naming its origin/version) alongside the binaries, and correct the README's pairing table to state what each shipped file actually is.
- Benefit: The shipped pair becomes reproducible and auditable; the next auditor does not have to reverse the pairing from strings.
- Effort: S · Risk: Low · Confidence: High (READ — binary identification is string-exact, see below)

### RE-POPS-BDM-34 — fs_ioctl2's RENAME command is an admitted TODO stub, and the ops table is padded with dummy slots
- Category: 8
- Locations: tarball:bdmfs_fatfs/src/fs_driver.c:668-674,795-830; tarball:__bdm_assault/src/bdmfs/bdmfs_fs_driver.c:668-674,795-830
- Problem: `USBMASS_IOCTL_RENAME` — a command in the `usbhdfsd-common` ioctl set that host code can legitimately issue — is implemented as `// TODO … ret = -ENOENT;`, reporting "no such file" for an operation that was never attempted, which callers cannot distinguish from a genuinely missing file. Around it, the `fs_functarray` ops table routes six slots (format, chstat, and four others) to `fs_dummy`, which returns -5, and registers `fs_remove` in both the remove and the rmdir slots. The driver presents a full iomanX interface while a visible fraction of it is placeholder.
- Fix: Implement RENAME via `f_rename` using the open file's volume (the two-path problem the TODO cites is solvable from `fd->unit` + the file's name via the existing mount-info table), or return a distinguishable `-ENOSYS`-style error; mark dummy ops slots as unsupported rather than -5.
- Benefit: Callers stop misreading "unimplemented" as "file not found" — a distinction that matters to any host doing rename-based save-file rotation.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-BDM-35 — SCSI layer caps every drive at 2 TiB inside an otherwise 64-bit stack
- Category: 8
- Locations: tarball:usbmass_bd/src/scsi.c:101-118,173-175; tarball:__usbd_bd_assault/src/usbmass_bd/usbmass_bd_scsi.c:101-118,173-175
- Problem: The stack around this file is 64-bit end to end — BDM uses u64 sectors, GPT parsing is u64, FatFs is built with `FF_LBA64 1` + exFAT — but `scsi_cmd_rw_sector` issues READ(10)/WRITE(10) with a 32-bit LBA field and `scsi_warmup` reads capacity with READ CAPACITY(10)'s 32-bit result. The code's own comment (lines 109-110) states the consequence plainly: drives above 2 TiB are unsupported. Worse, nothing *enforces* the cap: on a >2 TiB drive the capacity value saturates/wraps at the 32-bit boundary (READ CAPACITY(10) returns 0xFFFFFFFF when the true value exceeds it), and that value is stored as the device size (compounding RE-POPS-BDM-11), so large drives are not cleanly rejected — they are silently mis-sized, and any LBA past 2 TiB issued by upper layers is truncated into the low field, i.e. aliased onto the start of the disk. For a project whose entire purpose is large exFAT USB drives for legacy launchers, this is the unfinished core feature, not an edge case.
- Fix: Move to READ/WRITE(16) and READ CAPACITY(16) (the BOT/SCSI plumbing already carries u64 LBAs and byte counts), or, as a minimum, detect the 0xFFFFFFFF saturation in warmup and refuse the device explicitly.
- Justification: The (16) commands add code, but they are the only way the advertised use case (multi-TiB exFAT) works at all; the minimal refusal variant adds ~3 lines.
- Benefit: >2 TiB drives either work or fail loudly, instead of being silently aliased onto their own first sectors — a write-corruption hazard today.
- Effort: M · Risk: Med · Confidence: High (READ)

---

## Component ↔ merged relation (scripted diff, this run)

Method: every merged `.c`/`.h` was diffed with `difflib` against its presumed component source. "Delta" counts are unified-diff `+`/`-` line counts (a substituted line = 1+/1-). The merged trees are **not concatenations**: each merged file is a renamed 1:1 copy of exactly one component file (`bdm_`/`bdmfs_`/`usbd_`/`usbmass_bd_` prefix), and the merged Makefiles prefix object names the same way to avoid collisions (`main.o` × 4, etc.). The only functional delta in either merged tree is the `_start` chaining (below the table).

### __bdm_assault (from bdm/ + bdmfs_fatfs/ + libbdm.a)

| Component | Merged copy | Verdict | Diff |
|---|---|---|---|
| bdm/src/bdm.c (6,411 B) | src/bdm/bdm_bdm.c (6,419 B) | delta | +1/−1 (include path) |
| bdm/src/main.c (899 B) | src/bdm/bdm_main.c (1,013 B) | delta — functional | +4/−4: MAJOR_VER 1→2, `_start` returns `bdmfs_fatfs_start(argc, argv)` instead of `MODULE_RESIDENT_END` |
| bdm/src/part_driver.c (3,319 B) | src/bdm/bdm_part_driver.c (3,351 B) | delta | +4/−4 (include paths) |
| bdm/src/part_driver_gpt.c (6,814 B) | src/bdm/bdm_part_driver_gpt.c (6,838 B) | delta | +3/−3 (include paths) |
| bdm/src/part_driver_mbr.c (3,415 B) | src/bdm/bdm_part_driver_mbr.c (3,439 B) | delta | +3/−3 (include paths) |
| bdm/include/bdm.h | src/bdm/bdm.h | identical | 0 |
| bdm/src/include/gpt_types.h / mbr_types.h / part_driver.h / module_debug.h | src/bdm/include/ (same names) | identical | 0 (all four) |
| bdmfs_fatfs/src/diskio.c (5,109 B) | src/bdmfs/bdmfs_diskio.c (5,133 B) | delta | +3/−3 (include paths) |
| bdmfs_fatfs/src/ff.c (247,142 B) | src/bdmfs/bdmfs_ff.c (247,166 B) | delta | +3/−3 (include paths) |
| bdmfs_fatfs/src/ffsystem.c (5,369 B) | src/bdmfs/bdmfs_ffsystem.c (5,377 B) | delta | +1/−1 (include path) |
| bdmfs_fatfs/src/ffunicode.c (1,959,389 B) | src/bdmfs/bdmfs_ffunicode.c (1,959,397 B) | delta | +1/−1 (include path) |
| bdmfs_fatfs/src/fs_driver.c (21,748 B) | src/bdmfs/bdmfs_fs_driver.c (21,764 B) | delta | +2/−2 (include paths) |
| bdmfs_fatfs/src/main.c (1,255 B) | src/bdmfs/bdmfs_main.c (1,298 B) | delta — functional | +6/−6: `IRX_ID` commented out, `_start` renamed to `bdmfs_fatfs_start`, banner replaced with `BDM_ASSAULT: starting Fatfs side` |
| bdmfs_fatfs/src/include/diskio.h / ff.h / ffconf.h / fs_driver.h / module_debug.h | src/bdmfs/include/ (same names) | identical | 0 (all five) |
| bdm/src/exports.tab + bdmfs imports | src/exports.tab (434 B) | delta | comment line only vs bdm's tab; table body identical (bdm exports retained, FatFs has none) |
| bdm + bdmfs_fatfs imports.lst | src/imports.lst (878 B) | merged union | superset of both component lists (456 B + 634 B), per its own header comment |
| bdm + bdmfs_fatfs irx_imports.h | src/irx_imports.h (796 B) | merged union | differs from both components (714 B / 733 B) |

libbdm is **not** copied into either merged tree: both merged Makefiles link the component build (`../libbdm/lib/libbdm.a` for `__bdm_assault`; `__usbd_bd_assault` does not use libbdm).

### __usbd_bd_assault (from usbd/ + usbmass_bd/)

| Component | Merged copy | Verdict | Diff |
|---|---|---|---|
| usbd/src/driver.c (6,965 B) | src/usbd/usbd_driver.c (6,965 B) | identical | 0 |
| — (no second component) | src/usbd/usbd_usbd_driver.c (6,965 B) | **dead duplicate** of the row above | 0 vs driver.c; not referenced by the Makefile (RE-POPS-BDM-22) |
| usbd/src/hcd.c (16,815 B) | src/usbd/usbd_hcd.c | identical | 0 |
| usbd/src/hub.c (23,511 B) | src/usbd/usbd_hub.c | identical | 0 |
| usbd/src/interface.c (8,465 B) | src/usbd/usbd_interface.c | identical | 0 |
| usbd/src/mem.c (6,703 B) | src/usbd/usbd_mem.c | identical | 0 |
| usbd/src/usbd.c (11,221 B) | src/usbd/usbd_usbd.c (11,361 B) | delta — functional | +4/−4: banner `FreeUsbd v.0.1.2` → `USBD ASSAULT Start`; `_start` returns `usbmass_bd_start(argc, argv)` instead of `MODULE_RESIDENT_END` |
| usbd/src/usbio.c (9,412 B) | src/usbd/usbd_usbio.c | identical | 0 |
| usbd/src/driver.h / hcd.h / hub.h / mem.h / usbdpriv.h / usbio.h | src/usbd/ (same names) | identical | 0 (all six) |
| usbd/src/irx_imports.h (780 B) | src/usbd/irx_imports.h (780 B) | identical — **dead duplicate** | 0; the live merged imports header is src/irx_imports.h (RE-POPS-BDM-22) |
| usbmass_bd/src/main.c (801 B) | src/usbmass_bd/usbmass_bd_main.c (820 B) | delta — functional | +5/−5: `IRX_ID` commented out, `_start` renamed to `usbmass_bd_start`, banner → `USBD ASSAULT: starting USBMASS Side` |
| usbmass_bd/src/scsi.c (9,029 B) | src/usbmass_bd/usbmass_bd_scsi.c (9,045 B) | delta | +2/−2 (include paths) |
| usbmass_bd/src/usb_mass.c (25,909 B) | src/usbmass_bd/usbmass_bd_usb_mass.c (25,925 B) | delta | +2/−2 (include paths) |
| usbmass_bd/src/include/scsi.h / module_debug.h | src/usbmass_bd/include/ (same names) | identical | 0 (both) |
| usbd/src/exports.tab | src/exports.tab (775 B) | delta | comment line only; table body identical (usbd exports retained, usbmass_bd has none) |
| usbd + usbmass_bd imports.lst | src/imports.lst (765 B) | merged union | superset of both component lists (694 B + 595 B), incl. the added `bdm_IMPORTS` block the component usbmass did not need standalone |
| usbd + usbmass_bd irx_imports.h | src/irx_imports.h (797 B) | merged union | differs from both components |

**Summary:** 37 component↔merged file pairs script-diffed: 20 byte-identical, 17 with deltas; every delta is include-path substitution except the three `_start`-chaining/banner/version edits itemised above and the two merged-union imports files per tree. **No merged copy carries any bug fix, extra check, or behavioural change beyond start-up chaining** — every defect cited in this section exists identically in both copies. Two merged files have no component counterpart and no build reference (the dead duplicates of RE-POPS-BDM-22).

---

## Merged ↔ shipped relation (strings / structure only; no disassembly)

Shipped set in the repo: `iop/embed/BDMASSAULT_MX4SIO/usbd.irx` (48,500 B) and `usbhdfsd.irx` (14,993 B), both ELF32 MIPS IOP modules (`file`/`readelf`).

**`usbd.irx` ↔ `__bdm_assault` (`bdm_assault.irx`) — correspondence string-exact.**
- Strings present: `Block Device Manager (BDM) v%d.%d`, `BDM: %s%dp%d mounted to %s`, `Found MBR disk`, `Found GPT disk '%08x...'`, `EFI PART`, `EXFAT   ` / `FAT32   `, `FATFS driver`, and — decisively — `BDM_ASSAULT: starting Fatfs side`, the banner that exists **only** in the merged copy (`bdmfs_main.c` delta, see table), not in any component.
- Import library names embedded: `loadcore, stdio, sysclib, sysmem, thbase, thevent, cdvdman, intrman, ioman, thsemap` — exactly the merged `__bdm_assault/src/imports.lst` union (bdm + FatFs), including `cdvdman` (FatFs `get_fattime`) and `ioman` (fs_driver).
- No USBD/USB-mass strings (`USBD ASSAULT…`, `mass-stor`) are present. Verdict: shipped `usbd.irx` **is** the `__bdm_assault` product under the POPStarter filename, exactly as tarball README:13 and CI:39 prescribe. (INFERRED only in the trivial sense that a binary cannot be byte-matched to source without a rebuild; every identifying string and the import set match, and the merged-only banner is present.)

**`usbhdfsd.irx` ↔ nothing in the tarball — correspondence fails (RE-POPS-BDM-33).**
- Strings present: `MX4SIO: MX4SIO v1.2`, `MX4SIO: Starting module`, `MX4SIO: card detection thread running`, `MX4SIO: %lu %u-byte logical blocks: (%luMB / %luMiB)`, module name `mx4sio`; imports `dmacman, intrman, loadcore, stdio, sysclib, thbase, thevent, thsemap, sio2man, modload`. `.text` is 0x23ac bytes — far smaller than a USBD+mass link.
- No string from `__usbd_bd_assault` appears (`USBD ASSAULT Start`, `USBD ASSAULT: starting USBMASS Side`, `mass-stor`, `FreeUsbd` all absent), and no tarball file mentions MX4SIO or SIO2 at all (full-tree grep).
- Verdict: shipped `usbhdfsd.irx` is an **MX4SIO (SIO2 SD-card) block-device driver, v1.2**, presumably registering a BDM block device that the BDM/FatFs half in `usbd.irx` then mounts — a sensible pairing for MX4SIO support, but one the tarball neither contains source for nor documents. The tarball's `usbd_bd_assault.irx` product (USB core + USB mass) corresponds to **neither** shipped binary and is absent from the shipped set, despite tarball README:14 / CI:40 prescribing it as the `usbhdfsd.irx` occupant.

**Unaccounted-for summary:** 1 of 2 shipped binaries (`usbhdfsd.irx`, the MX4SIO driver) has no source, no provenance note, and no mention in the tarball; 1 of 2 tarball products (`usbd_bd_assault.irx`) has no shipped counterpart under any name in this directory.

---

## FILES READ

Read in full (line-numbered) in this run — component originals; merged copies of the same content were verified by scripted diff (table above) rather than re-read line by line, except where a merged delta itself is cited:

- tarball:bdm/src/bdm.c, bdm/src/main.c, bdm/src/part_driver.c, bdm/src/part_driver_gpt.c, bdm/src/part_driver_mbr.c, bdm/include/bdm.h, bdm/src/include/gpt_types.h, bdm/src/include/mbr_types.h, bdm/src/include/part_driver.h, bdm/src/exports.tab
- tarball:libbdm/src/bd_cache.c, libbdm/src/bd_defrag.c, libbdm/include/bd_cache.h, libbdm/include/bd_defrag.h
- tarball:bdmfs_fatfs/src/fs_driver.c, bdmfs_fatfs/src/diskio.c, bdmfs_fatfs/src/main.c, bdmfs_fatfs/src/ffsystem.c, bdmfs_fatfs/src/include/ffconf.h
- tarball:usbmass_bd/src/usb_mass.c, usbmass_bd/src/scsi.c, usbmass_bd/src/main.c
- tarball:usbd/src/usbd.c, usbd/src/interface.c, usbd/src/driver.c, usbd/src/hcd.c, usbd/src/hub.c, usbd/src/mem.c, usbd/src/usbio.c, usbd/src/usbdpriv.h, usbd/src/exports.tab
- tarball:README.MD, global.make, .github/workflows/CI.yml, all seven component/merged Makefiles, __bdm_assault/src/exports.tab, __bdm_assault/src/imports.lst, __usbd_bd_assault/src/exports.tab, __usbd_bd_assault/src/imports.lst
- Repo side: iop/embed/BDMASSAULT_MX4SIO/README.MD (repo copy, differs from tarball README by the added POPSLoader note), plus `strings`/`readelf`/`file` structure of both shipped IRXs (identification only, no disassembly).

## FILES NOT READ / SCANNED-ONLY (exact)

- **Structurally scanned only** (header/defines/first lines via script; not line-read; no finding cites their internals): tarball:bdmfs_fatfs/src/include/ff.h (430 lines), bdmfs_fatfs/src/include/diskio.h, bdmfs_fatfs/src/include/fs_driver.h, usbd/include/usbd.h (361 lines), usbd/include/usbd_macro.h, usbmass_bd/src/include/scsi.h, usbd/src/driver.h, usbd/src/hcd.h, usbd/src/hub.h, usbd/src/mem.h, usbd/src/usbio.h, all module_debug.h copies (byte-compared by md5, contents of three component variants read via script output), all irx_imports.h copies (byte-compared/sized by script), bdmfs_fatfs/src/imports.lst, usbd/src/imports.lst, usbmass_bd/src/imports.lst, bdm/src/imports.lst.
- **Vendored FatFs core — structurally scanned, not audited line-by-line:** tarball:bdmfs_fatfs/src/ff.c (6,986 lines; header, config interactions, and the `disk_ioctl` call sites at ff.c:3386-3387, 5676, 5901 grepped and read in context) and its merged copy tarball:__bdm_assault/src/bdmfs/bdmfs_ff.c (diff-verified: include paths only). Pure upstream ChaN code; the POPSLoader-side glue around it (diskio.c, fs_driver.c, ffsystem.c, ffconf.h) was read in full, above.
- **Vendored unicode data tables — scanned only:** tarball:bdmfs_fatfs/src/ffunicode.c (15,593 lines; header, code-page `#if` structure at line 38, and conversion-function tail inspected; the per-code-page WCHAR tables were not read) and its merged copy tarball:__bdm_assault/src/bdmfs/bdmfs_ffunicode.c (diff-verified: one include line).
- **Merged copies not independently line-read** (content established by scripted diff against the read component originals, per the table): all files under tarball:__bdm_assault/src/bdm/, __bdm_assault/src/bdmfs/, __usbd_bd_assault/src/usbd/, __usbd_bd_assault/src/usbmass_bd/ other than the delta hunks, exports/imports files, and Makefiles itemised as read above.
- **Non-code files scanned only:** tarball:bdmfs_fatfs/src/00readme.txt, bdmfs_fatfs/src/00history.txt (FatFs upstream changelog, 359 lines), LICENSE, .gitignore, .gitattributes, .vscode/settings.json.
- **Not present to read:** `usbhdfsd-common.h` and all PS2SDK headers (`bdm.h` consumers' side, `usbd.h` SDK side, etc.) are external to the tarball; claims depending on them are confined to what the tarball's own code shows, and the one finding touching an external header's constants (RE-POPS-BDM-14) says so in its text.
