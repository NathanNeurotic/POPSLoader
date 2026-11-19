# POPSLoader — Independent Redo Audit (LESS, NOT MORE)

**Repo:** NathanNeurotic/POPSLoader · **Pin:** `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (master), clone verified at this HEAD and tree-clean before and after the audit.
**Date:** 2026-11-14/15 · **Mode:** read-only in the clone; all extractions and test runs in `/tmp`. This is a **blind redo**: it was produced from the code alone, without consulting any prior audit of this repo.

## Method

Six parallel section passes (Lua, EE C/C++, IOP C, the BDMAssault tarball tree, tracked binaries/build/CI, docs-vs-code), followed by a coordinator consolidation: mechanism-level dedupe across sections, renumbering, and independent spot re-verification of the headline mechanisms (the duplicate-embed hashes, the POPSTARTER.ELF profile byte matrix and default≡DEBUG hash, the shipped `usbhdfsd.irx` identity strings, the ds34usb endpoint walk, the OSK layout normalizer, and the GPT scratch allocation were all re-checked directly against the tree after the section passes landed).

Process rules applied throughout: cite only files actually opened; every file:line verified against the pin; every census, count and byte total produced by script against the tree or the extracted tarball, never estimated; one mechanism = one finding with all locations listed; INFERRED claims labelled. Secret-like values are reported by location only. Licences are settled and not re-litigated.

**Scope census (scripted at the pin):** 639 tracked files, ~31 MB. Lua: `system.lua` 11,784 lines, `ui.lua` 7,599, `images.lua` 93, `etc/boot.lua` 181 (19,657 total). C/C++/headers ≈29,155 lines. 10 workflow files. 162 tracked Markdown files. 38 tracked binary files → 26 distinct by SHA-256. BDMAssault tarball (`iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz`): **md5 `09ff4b911ba131468a25d0ec9a4e2f27`**, sha256 `49c03644…` (full value in the tarball section working notes); extracted tree 119 files, ~62,216 lines of C/H across components `bdm/`, `bdmfs_fatfs/`, `libbdm/`, `usbd/`, `usbmass_bd/` plus the merged `__bdm_assault/` and `__usbd_bd_assault/` trees.

## Totals

**115 findings**, sorted by benefit (hostile-input memory safety first, then data integrity, then the large structural/size wins, then the long tail).

| Category | Count |
|---|---|
| 1 — Dead code | 17 |
| 2 — Duplication | 14 |
| 3 — Overengineering | 3 |
| 4 — Size / memory | 6 |
| 5 — Performance (structural only) | 3 |
| 6 — Bugs / security | 43 |
| 7 — Build / CI / repo clutter | 17 |
| 8 — Half-finished / redundant features | 12 |
| **Total** | **115** |

Consolidation note: the six section passes produced 116 findings. Two pairs described the same mechanism and were merged (the 83,008-byte duplicate embed, filed independently by the EE and binaries passes → RE-POPS-049; the `default.png` registration, filed by both the EE and Lua passes → RE-POPS-089, with the Lua pass's fallback limb kept as RE-POPS-088). Two further findings had one limb relocated to the finding that owns the mechanism (the `ata_bd_fast` tree limb → RE-POPS-057; the dead build rule limb → RE-POPS-058). Nothing else was dropped.

## Headline results

- **The BDMAssault block stack trusts device-supplied geometry everywhere.** The GPT/MBR parsers read a full device sector (up to 4,096 B on real hardware) into fixed 512-byte scratch (RE-POPS-001); the bd_cache hardcodes 512 in both directions (RE-POPS-004); the SCSI layer validates capacity with an off-by-one and no `sectorSize == 0` guard (RE-POPS-005); and the whole SCSI path is 32-bit inside a nominally 64-bit stack, so >2 TiB drives are silently mis-sized and their LBAs alias to the start of the disk (RE-POPS-016). The cache additionally marks blocks valid when the device read *failed*, serving stale or uninitialised data as success (RE-POPS-018).
- **The ds34 gamepad drivers walk device descriptors with no bounds discipline in all four copies** — a device reporting `bNumEndpoints == 0` drives `epCount` to −1 and a ~2³¹-iteration out-of-bounds walk (RE-POPS-002) — and the pademu SIO2 hook parses pad traffic with no size floor, a wrappable length, and an unchecked multitap slot byte used as an array index (RE-POPS-003). The entire `modules/pademu/` tree containing two of the copies is built by nothing (RE-POPS-047).
- **The default shipped `POPSTARTER.ELF` is byte-identical to the DEBUG profile**, and the four "profiles" are a single binary differing only at bytes 1040/1043 — a 2×2 patch matrix with neither byte documented (RE-POPS-040, INFERRED semantics). 23 of the 26 distinct tracked binaries have no source anywhere in the repo, and provenance pinning is inconsistent (RE-POPS-041).
- **The shipped `usbhdfsd.irx` in the BDMAssault embed folder is an MX4SIO v1.2 SIO2 driver with no source in the tarball**, while the tarball's own `usbd_bd_assault` product appears in neither shipped binary (RE-POPS-044). Inside the tarball, the merged trees are pure include-path transforms of the components — 37 file pairs diffed, zero fixes unique to the merged copies — and two copies of the FatFs Unicode tables alone are 3,918,786 B, 79.1% of the tarball (RE-POPS-045).
- **The docs describe a different product in several load-bearing places:** i.Link is called a stub/"NOT implemented" in seven places while shipping a full scene, dispatch and POPSTARTER launch path (RE-POPS-060), and the SMB documentation still presents defaults (port 1111, preset IPs, DHCP on, guest) that the code deliberately removed — TESTING.md sends testers to a dead port (RE-POPS-059).

---
### RE-POPS-001 — Partition parsers read a full device sector into a fixed 512-byte scratch buffer
- Category: 6
- Locations: tarball:bdm/src/part_driver_gpt.c:36,43-47,80; tarball:__bdm_assault/src/bdm/bdm_part_driver_gpt.c:36,43-47,80; tarball:bdm/src/part_driver_mbr.c:28,37; tarball:__bdm_assault/src/bdm/bdm_part_driver_mbr.c:28,37
- Problem: GPT allocates `512 * 2` bytes and uses the first and second 512-byte halves as header and entry-sector buffers, then calls `bd->read(bd, …, 1)`; MBR allocates `sizeof(master_boot_record)` (512 bytes) and reads 1 sector into it. A block-device `read` transfers `count × bd->sectorSize` bytes. `sectorSize` is device-supplied (see RE-POPS-005: SCSI sets it verbatim from READ CAPACITY). On a 1024/2048/4096-byte-sector device the GPT header read alone overruns its 512-byte half by up to 3,584 bytes of IOP heap, and the entry-sector read overruns the end of the allocation; MBR has the same overrun. GPT is internally inconsistent as well: `entriesPerSector` (line 69) is computed from the real `bd->sectorSize` while the buffer it indexes is sized for 512.
- Fix: Size both scratch allocations from `bd->sectorSize` (GPT: `2 × sectorSize`), and reject a device whose `sectorSize` is not a power of two in [512, 4096] before parsing.
- Benefit: Removes a device-triggerable heap overflow on the first code that touches an untrusted disk.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-002 — USB descriptor walk trusts `bLength`/`bNumEndpoints` from the device in all four copies
- Category: 6
- Locations: modules/pademu/ds34usb.c:121-147, modules/ds34usb/iop/ds34usb.c:128-154, modules/pademu/ds34bt.c:110-137, modules/ds34bt/iop/ds34bt.c:111-142
- Problem: Identical loop in every copy: `interface = (void*)config + config->bLength; epCount = interface->bNumEndpoints - 1; endpoint = UsbGetDeviceStaticDescriptor(..., USB_DT_ENDPOINT); do { ...; endpoint = (void*)endpoint + endpoint->bLength; } while (epCount--);` with no NULL check on `device`/`config`/`endpoint` in `*_connect` (only `*_probe` checks), no `bLength == 0` guard, and no bound against the config descriptor's `wTotalLength`. Three concrete failures: (1) a device reporting `bNumEndpoints == 0` for a DS3/BT interface makes `epCount = -1`, and `while (epCount--)` then iterates ~2^31 times, walking `endpoint` ever further out of bounds; (2) `bLength == 0` never advances the pointer, re-opening the same endpoint; (3) the DS4 branch hardcodes `epCount = 20` ("ds4 v2 returns bNumEndpoints as 0", ds34usb.c:128/135) and walks 21 descriptors regardless of how many the device actually sent. A malformed or clone device — exactly the fake-DS3/DS4 hardware this code exists to tolerate — controls all three values.
- Fix: In the single consolidated copy (RE-POPS-053): NULL-check `device`/`config`/`endpoint` in connect, iterate at most the real endpoint count, stop when `bLength == 0` or the walk passes `config + config->wTotalLength`, and drop the hardcoded 20 in favour of stopping at the descriptor end.
- Benefit: Removes an IOP crash / out-of-bounds walk triggered purely by device-supplied descriptors.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-003 — `pademu.c` SIO2 parsing reads past the transfer with no size floor, and the multitap slot becomes an unchecked array index
- Category: 6
- Locations: modules/pademu/pademu.c:228,236,314,323,369-415,475-493,505-530
- Problem: Four unchecked-length mechanisms in one file: (1) the second-command scans use `for (ctrl = 5; ctrl < td->in_size - 3; ctrl++)` — if `in_size < 3` the `u32` subtraction wraps and the scan reads far past `td->in`; the `cmd_size + 3 == td->in_size` not-found test also misses the `>` case. (2) `pademu_cmd` switches on `in[1]` and reads `in[3]`…`in[9]` (cases 0x43/0x44/0x46/0x4C/0x4D/0x4F) without ever checking the input length it was handed, and calls `PAD_GET_DATA(&out[3], out_size - 3, port)` — `out_size` is `u8`, so `out_size < 3` underflows to ~253 (see RE-POPS-024). (3) `pademu_mtap` stores the device/game-supplied byte `mtap_slot = td->in[2]` (pademu.c:527) with no range check; `pademu()` then uses it as `port = mtap_slot` (pademu.c:359-363), indexing `pad[4]` and, via `pademu_cmd`, `ds34pad[4]` — any slot byte ≥ 4 is an out-of-bounds read/write. (4) `pademu_mtap` itself switches on `td->in[1]` after only checking the transfer is multitap-addressed.
- Fix: Reject transfers with `in_size < 10` at the top of `pademu`/`pademu_cmd`/`pademu_mtap`, change the not-found tests to `>=`, and clamp/reject `mtap_slot >= MAX_SLOT` when it is stored. No new machinery — three comparisons in code that already branches on these values.
- Benefit: Closes game/transfer-controlled out-of-bounds access in the SIO2 hook, the highest-privilege parser in this scope.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-004 — Block cache hard-codes 512-byte sectors in its block geometry
- Category: 6
- Locations: tarball:libbdm/src/bd_cache.c:8,17,85-86,116-122
- Problem: The cache block is `SECTORS_PER_BLOCK × 512` bytes, offsets are computed as `(sector - cached_sector) * 512`, and the fill reads `SECTORS_PER_BLOCK` sectors into that block. All of it assumes `bd->sectorSize == 512`, but nothing in `bd_cache_create` checks `sectorSize`, and the value is device-supplied. With a 4096-byte-sector device the fill writes 8 × 4096 = 32 KiB into a 4 KiB cache slot (heap overflow), and with any non-512 size the offset arithmetic serves the wrong bytes even when it does not overflow. The cache is created for every whole device (`bdm.c:60`), so this is on the default path, not an opt-in.
- Fix: Either refuse to wrap devices with `sectorSize != 512` in `bd_cache_create` (return the raw `bd` / NULL so BDM uses it uncached), or size blocks and offsets from `bd->sectorSize`.
- Benefit: Removes a second device-triggerable heap overflow and silent data mis-serving for non-512-sector media.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-005 — SCSI capacity is off by one and the device-supplied block length is never validated
- Category: 6
- Locations: tarball:usbmass_bd/src/scsi.c:168-176; tarball:__usbd_bd_assault/src/usbmass_bd/usbmass_bd_scsi.c:168-176
- Problem: READ CAPACITY (10) returns the address of the **last** logical block, but the code stores it directly: `bd->sectorCount = getBI32(&rcd.last_lba)` — the device is thereafter one sector short, so the final sector of every USB disk is unreachable (and a 1-sector device reports 0). In the same three lines, `bd->sectorSize = getBI32(&rcd.block_length)` is accepted verbatim: a device returning 0 makes the very next statement divide by `bd->sectorSize` twice (`(1000*1000) / bd->sectorSize`) — a divide-by-zero trap — and any non-power-of-two or non-512 value flows onward into the partition parsers and cache of RE-POPS-001/-08 and into FatFs, which in this tree is configured `FF_MIN_SS == FF_MAX_SS == 512` so its variable-sector-size sanity check (ff.c:3387) is compiled out entirely.
- Fix: Store `sectorCount = last_lba + 1` (as u64, saturating), and reject the device in warmup unless `block_length` is a power of two in [512, 4096].
- Benefit: Full device capacity becomes addressable, and the single validation point closes the input that three other findings depend on.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-006 — GPT header fields are trusted unchecked: entry count, entry size, and a possible divide-by-zero
- Category: 6
- Locations: tarball:bdm/src/part_driver_gpt.c:57-73,80; tarball:__bdm_assault/src/bdm/bdm_part_driver_gpt.c:57-73,80; tarball:bdm/src/include/gpt_types.h:35-36
- Problem: After the 8-byte signature check, nothing else in the header is validated — the code's own TODO at lines 65-66 concedes revision, header size and both CRCs are unchecked. Three concrete consequences: (1) the scan loop is bounded only by the device-supplied `partition_count` (u32), so a corrupt header makes it issue one `bd->read` per sector far beyond the end of the disk/partition array until reads start failing; (2) `partition_entry_size` is ignored and entries are strided by `sizeof(gpt_partition_table_entry)` (128), so a table with any other legal entry size is parsed at wrong offsets; (3) `entriesPerSector = bd->sectorSize / sizeof(gpt_partition_table_entry)` is 0 when `sectorSize < 128`, and `i % entriesPerSector` / `i / entriesPerSector` then divide by zero.
- Fix: Validate before scanning: `header_size` in [92, sectorSize], `partition_entry_size == sizeof(gpt_partition_table_entry)` (or stride by it), `partition_count` capped so `partition_table_lba + ceil(count × entry_size / sectorSize)` stays inside the device, and `entriesPerSector > 0`.
- Benefit: A corrupt or hostile GPT can no longer drive unbounded reads, misaligned parsing, or a divide-by-zero trap in IOP code.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-007 — USB mass connect walks endpoint descriptors on device-supplied lengths with no NULL or bounds check
- Category: 6
- Locations: tarball:usbmass_bd/src/usb_mass.c:593-670; tarball:__usbd_bd_assault/src/usbmass_bd/usbmass_bd_usb_mass.c:593-670
- Problem: `usb_mass_connect` takes the first endpoint from `sceUsbdScanStaticDescriptor(devId, NULL, USB_DT_ENDPOINT)` and passes it straight to `usb_bulk_probeEndpoint`, which dereferences `endpoint->bmAttributes` — a NULL result (device with no endpoint descriptor in its static set) is a NULL dereference. It then steps `endpoint = (UsbEndpointDescriptor *)((char *)endpoint + endpoint->bLength)` for `interface->bNumEndpoints - 1` further steps, trusting the device-supplied `bLength` each time: `bLength == 0` re-probes the same descriptor repeatedly, and a small/large `bLength` walks outside the configuration descriptor block (whose total length, `config->wTotalLength`, `usb_mass_probe` checked but `connect` never uses). `connect` also re-derives the interface as `config + config->bLength` without re-checking any of the class/subclass/protocol/endpoint-count conditions `probe` validated.
- Fix: NULL-check the first endpoint, and bound each step: require `bLength >= sizeof(UsbEndpointDescriptor)` and the stepped pointer to remain within `config + config->wTotalLength`; bail via the existing not-enough-endpoints path otherwise.
- Benefit: A malformed or malicious USB device can no longer crash or misdirect the mass-storage connect path — the path every USB disk takes.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-008 — Static-descriptor search takes its first step on an unchecked descriptor length
- Category: 6
- Locations: tarball:usbd/src/hcd.c:195-213; tarball:__usbd_bd_assault/src/usbd/usbd_hcd.c:195-213
- Problem: `doGetDeviceStaticDescriptor(devId, data, type)` computes its starting point as `data + ((UsbDeviceDescriptor *)data)->bLength` when `data != NULL`, with no check that `data`'s `bLength` is sane or that the result stays inside the device's static descriptor block (`staticDeviceDescPtr .. staticDeviceDescEndPtr`). The subsequent `while` loop does bounds- and `bLength >= 2`-checks, but they guard a pointer that may already be out of bounds, and its first dereference reads the purported `bLength` there. Every hub/USB-mass descriptor lookup in the tree funnels through this function with descriptor pointers ultimately derived from device-supplied bytes.
- Fix: Validate the initial step against `staticDeviceDescEndPtr` (and `bLength >= 2`) before entering the loop, returning NULL on violation.
- Benefit: One guard at the choke point hardens every descriptor walk built on it (hub connect, mass probe/connect).
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-009 — BT HCI/L2CAP/HID handlers ignore the received byte count and parse stale buffer bytes
- Category: 6
- Locations: modules/pademu/ds34bt.c:499,763,908-1056,1211-1420, modules/ds34bt/iop/ds34bt.c:540,828,970-1160,1275-1490
- Problem: Same mechanism in both BT copies. `HCI_event_task(int result)` does not even receive the byte count (`hci_event_cb` discards `bytes`, ds34bt.c:763/828) and switches on `hci_buf[0]` reading up to `hci_buf[11]` plus a 19-byte `memcmp` at `hci_buf + 9` for the remote name; `HCI_EVENT_NUM_COMPLETED_PKT` loops `for (i = 0; i < hci_buf[2]; i++)` reading `hci_buf[3+i]`/`hci_buf[4+i]` with the device-supplied count unbounded against the 64-byte `hci_buf`. `L2CAP_event_task(result, bytes)` receives `bytes` but never bounds-checks it before reading `l2cap_buf[8]`…`l2cap_buf[19]` for every signalling command, and `hid_readReport(data, bytes, pad)` casts `&data[11]` to `ds3report`/`ds4report` (≈49/64 bytes) after checking only `data[8]`/`data[9]` — its one length use is the DS4 touchpad gate `bytes > 63`. A short or truncated USB/BT packet therefore parses whatever the previous packet left in the static buffers as buttons, handles and addresses.
- Fix: Thread `bytes` into `HCI_event_task`, and in both copies drop any packet shorter than the fixed header each branch reads (HCI: the branch's parameter length; L2CAP: 20 bytes for signalling, 11 + report size for HID input) before touching the buffer. One early return per handler.
- Benefit: Malformed/short packets stop being executed as controller state in both BT copies.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-010 — DS3 battery byte indexes the 6-entry `power_level[]` unchecked in all four copies
- Category: 6
- Locations: modules/pademu/ds34usb.c:44-45,303-304, modules/ds34usb/iop/ds34usb.c:45-46,298-299, modules/pademu/ds34bt.c:256-257,1275-1276, modules/ds34bt/iop/ds34bt.c:261-262,1332-1333
- Problem: `power_level[]` has 6 entries (indices 0-5). Every copy does `if (report->Power != 0xEE) oldled[0] = power_level[report->Power];` (standalone USB/BT add `PSButtonState &&` but the same index). `report->Power` is a full device-supplied `u8` in `struct ds3report` (ds34usb.h/ds34bt.h: "05=full … EE=charging" is a comment, not a check). Any value 6-0xED except 0xEE reads past the array into adjacent static data and uses it as an LED pattern; a clone/fake controller — explicitly supported by this code — supplies the byte.
- Fix: Clamp once per copy (once total after RE-POPS-053): only index when `report->Power <= 5`, otherwise fall back to the pad's normal LED pattern, as the surrounding code already does in the non-PS branch.
- Benefit: Removes a device-controlled out-of-bounds read present in all four driver copies.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-011 — Mount-info lookup accepts the one-past-the-end index (and negative indices)
- Category: 6
- Locations: tarball:bdmfs_fatfs/src/fs_driver.c:137-152; tarball:__bdm_assault/src/bdmfs/bdmfs_fs_driver.c:137-152
- Problem: `fatfs_fs_driver_get_mounted_bd_from_index` guards with `if (mount_info_index > FATFS_FS_DRIVER_MOUNT_INFO_MAX)` — with `FF_VOLUMES == 10` the valid indices are 0-9, so index 10 passes the guard and reads `fs_driver_mount_info[10]`, one element past the array. Negative indices are not checked at all and read before the array. The function is called with `fd->unit` (fs_devctl / GET_DRIVERNAME path), with FatFs's `pdrv`, and from `diskio.c` for every disk operation, so the out-of-bounds pointer it returns is dereferenced by callers that treat non-NULL as "mounted".
- Fix: Reject `mount_info_index < 0 || mount_info_index >= FATFS_FS_DRIVER_MOUNT_INFO_MAX`.
- Benefit: Removes an out-of-bounds read whose result gates device I/O, on the driver's most-called helper.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-012 — fs_ioctl2 / fragment-list paths dereference a possibly-NULL mounted block device
- Category: 6
- Locations: tarball:bdmfs_fatfs/src/fs_driver.c:624-653,681-714; tarball:__bdm_assault/src/bdmfs/bdmfs_fs_driver.c:624-653,681-714
- Problem: Three sites take the result of `fatfs_fs_driver_get_mounted_bd_from_index(...)` and dereference it without the NULL check that the neighbouring `USBMASS_IOCTL_GET_DEVICE_NUMBER` case (lines 716-733) correctly performs: (1) `USBMASS_IOCTL_GET_LBA` computes `clst2sect(...) + bd->sectorOffset` with `bd` unchecked; (2) `USBMASS_IOCTL_GET_DRIVERNAME` guards only its return-value expression with a ternary, then unconditionally executes `strncpy(rdata, mounted_bd->name, rdatalen)` whenever `rdata != NULL` — exactly the call shape a caller uses to actually get the name; (3) `get_frag_list` (backing GET_FRAGLIST and CHECK_CHAIN) dereferences `bd->sectorOffset` inside its loop with `bd` unchecked. An ioctl on a file whose volume has been unmounted (device yanked — the normal failure mode for removable USB) is a NULL dereference in IOP code.
- Fix: NULL-check `bd`/`mounted_bd` at all three sites and return `-ENXIO`, matching the GET_DEVICE_NUMBER case in the same switch.
- Benefit: The removable-media race stops being a crash; the fix is copyable from ten lines below two of the defects.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-013 — Partition read/write pass-through enforces no partition bounds at all
- Category: 6
- Locations: tarball:bdm/src/part_driver.c:52-80; tarball:__bdm_assault/src/bdm/bdm_part_driver.c:52-80
- Problem: `part_read`/`part_write` check only that `part` and `part->bd` are non-NULL, then forward `sector + bd->sectorOffset` with the caller's `count`. `bd->sectorCount` — the field that exists precisely to bound the partition — is never consulted, in either function. Any caller (or any corrupt FS metadata that makes FatFs request a sector past the partition end) reads or **writes** into the neighbouring partition or unpartitioned space. Combined with RE-POPS-014/-04, the partition abstraction provides no containment anywhere.
- Fix: Return -1 when `sector + count > bd->sectorCount` (with `count` widened before the addition) in both `part_read` and `part_write`.
- Benefit: One two-line check per direction converts cross-partition corruption from silent to impossible via this layer.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-014 — GPT partition size is off by one and an inverted range is accepted
- Category: 6
- Locations: tarball:bdm/src/part_driver_gpt.c:105,143; tarball:__bdm_assault/src/bdm/bdm_part_driver_gpt.c:105,143; tarball:bdm/src/include/gpt_types.h:51
- Problem: `gpt_types.h` documents `last_lba` as "Last LBA (inclusive)", but `sectorCount` is set to `last_lba - first_lba` instead of `last_lba - first_lba + 1`, so every GPT partition silently loses its final sector (a filesystem whose last sector holds backup metadata — e.g. the exFAT/FAT backup boot region at the end on some layouts, or simply the last cluster — is truncated). The bounds check at line 105 tests each LBA against the header range separately and never tests `last_lba >= first_lba`; an entry with `first_lba > last_lba` passes and `sectorCount` underflows to a near-2^64 value, handing the FS layer a partition that claims to cover the whole address space.
- Fix: Set `sectorCount = last_lba - first_lba + 1` and add `last_lba < first_lba` to the corrupt-entry rejection at line 105.
- Benefit: Partitions match the on-disk layout exactly, and a corrupt/malicious entry can no longer mint an unbounded partition.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-015 — MBR partitions are mounted with no bounds, type, or extended-partition handling
- Category: 6
- Locations: tarball:bdm/src/part_driver_mbr.c:64-91; tarball:__bdm_assault/src/bdm/bdm_part_driver_mbr.c:64-91
- Problem: Any of the four primary entries with `sector_count != 0` is mounted verbatim: `first_lba + sector_count` is never checked against `bd->sectorCount`, so a partition can claim space past the end of the device (later reads/writes are passed through, see RE-POPS-013); `partition_type == 0x00` (empty) with a non-zero count is mounted; and extended types (0x05/0x0F/0x85) are mounted as if they were data partitions instead of being followed to the logical partitions — the code's own TODO at line 72 ("Filter out unsupported partition types") is unimplemented. Only entry [0] is tested for the GPT-protective type 0xEE.
- Fix: Reject entries with type 0, reject/skip extended types (or follow the EBR chain), and require `(u64)first_lba + sector_count <= bd->sectorCount` before connecting.
- Benefit: The partition layer stops inventing filesystems out of table garbage and stops handing out-of-device ranges to the FS layer.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-016 — SCSI layer caps every drive at 2 TiB inside an otherwise 64-bit stack
- Category: 8
- Locations: tarball:usbmass_bd/src/scsi.c:101-118,173-175; tarball:__usbd_bd_assault/src/usbmass_bd/usbmass_bd_scsi.c:101-118,173-175
- Problem: The stack around this file is 64-bit end to end — BDM uses u64 sectors, GPT parsing is u64, FatFs is built with `FF_LBA64 1` + exFAT — but `scsi_cmd_rw_sector` issues READ(10)/WRITE(10) with a 32-bit LBA field and `scsi_warmup` reads capacity with READ CAPACITY(10)'s 32-bit result. The code's own comment (lines 109-110) states the consequence plainly: drives above 2 TiB are unsupported. Worse, nothing *enforces* the cap: on a >2 TiB drive the capacity value saturates/wraps at the 32-bit boundary (READ CAPACITY(10) returns 0xFFFFFFFF when the true value exceeds it), and that value is stored as the device size (compounding RE-POPS-005), so large drives are not cleanly rejected — they are silently mis-sized, and any LBA past 2 TiB issued by upper layers is truncated into the low field, i.e. aliased onto the start of the disk. For a project whose entire purpose is large exFAT USB drives for legacy launchers, this is the unfinished core feature, not an edge case.
- Fix: Move to READ/WRITE(16) and READ CAPACITY(16) (the BOT/SCSI plumbing already carries u64 LBAs and byte counts), or, as a minimum, detect the 0xFFFFFFFF saturation in warmup and refuse the device explicitly.
- Justification: The (16) commands add code, but they are the only way the advertised use case (multi-TiB exFAT) works at all; the minimal refusal variant adds ~3 lines.
- Benefit: >2 TiB drives either work or fail loudly, instead of being silently aliased onto their own first sectors — a write-corruption hazard today.
- Effort: M · Risk: Med · Confidence: High (READ)

---

### RE-POPS-017 — SCSI warmup failure is ignored, sense data is read uninitialised, and TEST UNIT READY can spin forever
- Category: 6
- Locations: tarball:usbmass_bd/src/scsi.c:127-176,272-285; tarball:__usbd_bd_assault/src/usbmass_bd/usbmass_bd_scsi.c:127-176,272-285
- Problem: Three linked defects in one flow. (1) `scsi_connect` calls `scsi_warmup(bd)` and discards its return value, then calls `bdm_connect_bd(bd)` unconditionally — a device whose INQUIRY or READ CAPACITY failed is published with whatever `sectorSize`/`sectorCount` a previous device left in the recycled `g_scsi_bd[]` slot (disconnect clears only `priv`). (2) In the TEST UNIT READY loop, `sense_data sd` is never initialised or cleared; when `scsi_cmd_request_sense` fails the code logs it and then still evaluates `sd.error_code`/`sd.sense_key` — stack garbage decides whether START STOP UNIT is sent. (3) The `while ((stat = scsi_cmd_test_unit_ready(bd)) != 0)` loop has no retry bound and no delay: a device that never becomes ready (or whose sense data never matches the one handled case) hangs the USB mass update thread forever, taking all later device handling with it.
- Fix: Make `scsi_connect` connect only when `scsi_warmup` returns 0 (and zero the slot's geometry on disconnect); `memset` the sense buffer per iteration and skip its evaluation when REQUEST SENSE fails; bound the ready loop (e.g. the same 16-retry discipline used elsewhere in the file) with a delay between attempts.
- Benefit: Failed devices stay unpublished instead of appearing with another device's geometry, and one bad device can no longer wedge USB storage permanently.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-018 — Block cache marks a block valid and serves it even when the device read failed
- Category: 6
- Locations: tarball:libbdm/src/bd_cache.c:115-123
- Problem: On a cache miss, `_read` calls `c->bd->read(c->bd, sector, c->cache[blkidx_best], SECTORS_PER_BLOCK)` and **ignores the return value**, unconditionally sets `c->sector[blkidx_best] = sector`, copies `count` sectors out of the buffer, and returns `count` (success). A failed or short read therefore returns stale previous contents (or uninitialised memory on first use) to FatFs as if it were the requested sector — metadata corruption is then interpreted as filesystem structure, and a later write-back can persist decisions made on garbage. This is the cache-correctness-on-failed-reads defect in its purest form: the error is not propagated at all.
- Fix: Capture the read result; on anything other than a full `SECTORS_PER_BLOCK` transfer, leave the slot invalidated (`sector = 0xffffffffffffffff`) and return the error/short count to the caller.
- Benefit: Device errors surface as errors instead of being laundered into plausible-looking filesystem data.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-019 — Fragment-list walk can loop forever on a cyclic FAT chain, holding the global FS lock
- Category: 6
- Locations: tarball:bdmfs_fatfs/src/fs_driver.c:624-653,656-665; tarball:__bdm_assault/src/bdmfs/bdmfs_fs_driver.c:624-653,656-665
- Problem: `get_frag_list` walks the file's cluster chain with a `do { … } while (iClusterCurrent < file->obj.fs->n_fatent)` loop whose only progress assumption is that `get_fat` eventually returns an end-of-chain or out-of-range value. A corrupt FAT (exactly what removable, possibly-dirty exFAT/FAT media provides) containing a cycle whose links are not `current + 1` — e.g. two clusters pointing at each other — makes `iClusterCurrent` oscillate below `n_fatent` forever, emitting a "fragment" per iteration. Both callers (`USBMASS_IOCTL_CHECK_CHAIN`, `USBMASS_IOCTL_GET_FRAGLIST`) run under `_fs_lock()`, so the hang is not confined to one ioctl: every filesystem operation on every volume blocks behind it permanently.
- Fix: Bound the walk by the maximum possible chain length (file size in clusters, or `n_fatent` iterations total) and bail with an error past it.
- Benefit: Corrupt media degrades to an ioctl error instead of a total, unrecoverable FS-driver hang.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-020 — Isochronous done-queue cleanup clears the wrong LUT slot
- Category: 6
- Locations: tarball:usbd/src/usbd.c:126-155; tarball:__usbd_bd_assault/src/usbd/usbd_usbd.c:126-155
- Problem: In `processDoneQueue_IsoTd`'s halted-endpoint sweep, each queued TD `curTd` is freed and its request looked up correctly (`hcIsoTdToIoReqLUT[curTd - hcIsoTdBuf]`), but the slot that is then cleared is `hcIsoTdToIoReqLUT[arg - hcIsoTdBuf]` — the already-processed TD's slot, cleared a second time — instead of `curTd`'s. Every swept isochronous request therefore leaves a stale LUT entry pointing at a freed/re-issued request, which a later done-queue pass will interpret as a live request for an unrelated TD. The generic-TD twin of this code (`processDoneQueue_GenTd`) clears the correct per-TD slot, confirming the intent.
- Fix: Clear `memPool.hcIsoTdToIoReqLUT[curTd - memPool.hcIsoTdBuf]` in the sweep.
- Benefit: Removes a stale-pointer source in the USB core's completion path (latent for mass storage, live for any isochronous client of this USBD).
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-021 — Font ids from Lua index the 16-entry fonts[] array with no bounds check in four fntsys entry points
- Category: 6
- Locations: src/fntsys.cpp:550-562, src/fntsys.cpp:602-606, src/fntsys.cpp:907-912, src/luagraphics.cpp:379-420
- Problem: `fntSetPixelSize`, `fntSetCharSize`, `fntRenderString` and `fntCalcDimensions` all do `&fonts[id]` / `fonts[fontid]` directly on the integer that `Font.ftSetPixelSize` / `ftSetCharSize` / `ftPrint` / `ftWidth` took from Lua via `luaL_checkinteger`, with no range validation. `fntRelease` (src/fntsys.cpp:281-283) does check `id > FNT_DEFAULT && id < FNT_MAX_COUNT`, proving the bound is known — the other four entry points just never got it. An out-of-range id is an out-of-bounds read in the render path and an out-of-bounds write in the two setters (both call `fntCacheFlush(&fonts[fontid])` first, which frees pointers through the wild slot).
- Fix: Add the same range check `fntRelease` already uses at the top of the four functions (return / return 0 on a bad id). No new abstraction — one guard, four sites.
- Benefit: Closes an out-of-bounds write reachable from the text-rendering bindings that every screen uses.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-022 — Lua handles are raw pointers cast through integers with no validation: NULL/wild dereference and double-free are one bad integer away
- Category: 6
- Locations: src/luagraphics.cpp:529-545, src/luagraphics.cpp:549-630, src/luagraphics.cpp:631-653, src/luagraphics.cpp:761-786, src/luagraphics.cpp:287-315, src/luasound.cpp:26-50, src/luatimer.cpp:33-122
- Problem: One mechanism across three files: C objects are handed to Lua as `(uint32_t)pointer` integers and taken back with `(GSTEXTURE*)luaL_checkinteger(...)` / `(GSFONT*)...` / `(audsrv_adpcm_t*)...` / `(Timer*)...`, then dereferenced immediately. Concretely: every `Graphics.draw*`/`getImageWidth`/`getImageHeight`/`setImageFilters` binding reads `source->Width`/`->Height`/`->Filter` with no NULL check, so a 0 or stale handle is a NULL/wild dereference; `Graphics.freeImage` frees Mem/Clut/struct with no liveness record, so a second call on the same integer is a double-free (the Lua side does call it from several cleanup paths); `Sound.playADPCM`/`freeADPCM` do the same for ADPCM handles. The Timer file looks like the exception but is not: its `TIMER_MAGIC` check itself dereferences the unchecked pointer first (`src->magic` at src/luatimer.cpp:38 and siblings), so a wild integer crashes inside the check that was meant to catch it.
- Fix: Validate before dereferencing with the cheapest mechanism that fits the existing style: reject 0 in every handle-taking binding, and for `freeImage`/`freeADPCM`/`Timer.destroy` clear-and-check via the one place that owns the handle (at minimum, NULL checks on every dereference site listed). No new handle-registry framework is proposed — the Lua is first-party, so this is crash-hardening, not a security boundary.
- Benefit: Turns a class of hard EE crashes (black screen, no error path) into Lua errors the existing error screen can show.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-023 — Both ELF-loading stages copy program segments to header-supplied addresses with no bounds validation
- Category: 6
- Locations: src/elf_loader/src/elf.c:460-468, src/elf_loader/src/loader/src/loader.c:195-270
- Problem: The parent stage (`ExecuteViaEmbeddedLoader`) checks only the 4-byte ELF magic, then iterates `boot_header->phnum` program headers and `memcpy`s each `filesz` to `vaddr` with no check on phnum/phentsize sanity, on `offset + filesz` against the blob size, or on the destination range — acceptable only because the blob is the project's own child loader, but the check that exists (magic) implies a validation that is not performed. The child stage (`load_elf_via_filexio`) does cap `phnum` at 16, but then reads each PT_LOAD's `filesz` bytes directly to the header-supplied `vaddr` from a file on pfs/hdd/mass storage, with no check that the segment does not overwrite the child loader itself in BRAM, the metadata page at 0x83C00, or lie outside RAM, and no check that `hdr.entry` is inside a loaded segment. A crafted or corrupted target ELF is arbitrary memory write by design of the format — the finding is that neither stage performs even the cheap structural checks (file-bounds, BRAM exclusion, entry-in-segment) that would catch corruption rather than malice. INFERRED severity: the target ELFs are user-supplied game launchers, so the realistic trigger is a truncated/corrupt file, not an attacker.
- Fix: Add the three structural checks in each stage (segment file-range within the blob/file size; destination outside the loader's own BRAM span and the metadata page; entry inside a PT_LOAD) and fail with the existing negative-code convention. No format or loader redesign.
- Benefit: A corrupt POPSTARTER.ELF fails with a diagnosable code instead of silently overwriting the loader and hanging the console.
- Effort: M · Risk: Med · Confidence: Med (INFERRED)

### RE-POPS-024 — `get_data` copies a caller-supplied `size` out of an 18-byte array, and the pademu copies never bounds-check `port`
- Category: 6
- Locations: modules/pademu/ds34usb.c:526,546, modules/pademu/ds34bt.c:1430,1436, modules/ds34usb/iop/ds34usb.c:530,553, modules/ds34bt/iop/ds34bt.c:1519,1529, modules/pademu/pademu.c:415
- Problem: All four `ds34*_get_data(dst, size, port)` implementations end in `mips_memcpy(dst, ds34pad[port].data, size)` where `data` is `u8[18]` (both headers) and `size` is unchecked. The pademu caller passes `out_size - 3` derived from the SIO2 transfer (pademu.c:415), so a large `out_size` over-reads `ds34pad[].data` and over-writes the SIO2 output buffer. The standalone RPC callers happen to pass the constant 18, so they are safe only by caller discipline. Compounding it, none of the pademu entry points (`get_data`/`set_rumble`/`set_mode`/`get_status`, ds34usb.c:515-600 and ds34bt.c:1422-1470) checks `port` at all, while every standalone entry point does (`port >= MAX_PADS`, e.g. ds34usb/iop/ds34usb.c:516,524,534) — and pademu's `port` can be the unchecked `mtap_slot` of RE-POPS-003.
- Fix: Clamp `size` to 18 inside `get_data` and add the same `port >= MAX_PADS` early return the standalone copies already have to the pademu entry points (free after consolidation, RE-POPS-053).
- Benefit: Removes a length-controlled over-copy and an index-controlled array access from the pademu path.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-025 — Pademu BT copy clears the DS4 LED buffer with the DS3 length and sends 29 uninitialised bytes (fix exists in the standalone copy)
- Category: 6
- Locations: modules/pademu/ds34bt.c:1149,1181,1206, modules/ds34bt/iop/ds34bt.c:1206,1243,1265, modules/pademu/ds34bt.h:227,231
- Problem: In pademu `hid_LEDRumble`, `led_buf` is `u8[PS4_11_REPORT_LEN + 2]` = 79 bytes, the DS4 branch sends `size = 2 + PS4_11_REPORT_LEN` = 79 bytes, but clears only `mips_memset(led_buf, 0, PS3_01_REPORT_LEN + 2)` = 50 bytes (ds34bt.c:1181). Bytes 50-78 are uninitialised stack sent to the controller in every DS4 BT rumble/LED packet. The standalone copy already contains the fix — `mips_memset(led_buf, 0, PS4_11_REPORT_LEN + 2)` at ds34bt/iop/ds34bt.c:1243 — proving this is a copy-sync miss, not a design choice.
- Fix: Change the one constant in the pademu copy to `PS4_11_REPORT_LEN + 2` (or delete the copy per RE-POPS-047/03, which makes the fix permanent).
- Benefit: Stops leaking 29 bytes of IOP stack to the device per DS4 BT output report.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-026 — Standalone USB copy lost the DS3 null-report guard the other three copies have
- Category: 6
- Locations: modules/ds34usb/iop/ds34usb.c:263-275, modules/pademu/ds34usb.c:269-270, modules/pademu/ds34bt.c:1219-1220, modules/ds34bt/iop/ds34bt.c:1284-1285
- Problem: Three of the four `readReport`/`hid_readReport` implementations drop the spurious all-zero-stick report an LED/rumble command provokes: `if (report->RightStickX == 0 && report->RightStickY == 0) return; // ledrumble cmd causes null report sometime`. The standalone USB copy — the one POPSLoader actually embeds — has no such guard (its DS3 branch at ds34usb/iop/ds34usb.c:272-275 goes straight to copying the report), so in the shipped module that known-bad report overwrites `ds34pad[pad].data[]` with a centred-stick/zero-pressure snapshot. This is the reverse sync miss to RE-POPS-025.
- Fix: Restore the same two-line guard at the top of the DS3 branch in `modules/ds34usb/iop/ds34usb.c` (or consolidate per RE-POPS-053).
- Benefit: The shipped USB driver gets the glitch suppression the other three copies already have.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-027 — Two Lua bindings trust a caller-supplied length over the actual string: loadImageEmbedded and IOP.loadModuleBuffer
- Category: 6
- Locations: src/luagraphics.cpp:810-826, src/luasystem.cpp:2608-2627
- Problem: Buffer/length handling where Lua values cross into C. (a) `Graphics.loadImageEmbedded(blob, size)` takes the data via `luaL_checkstring` and the length from a *separate* integer argument, never comparing it with the string's true length; a size larger than the blob makes the PNG reader walk past the Lua string into heap memory (the reader bounds against the supplied size, not the real one). The one real caller passes `string.len(blob)` correctly, so the hazard is the binding's contract, not current data. (b) `IOP.loadModuleBuffer(ptr, size, ...)` takes an IRX image via `luaL_checkstring` — a C-string API applied to binary data containing NUL bytes — plus an unchecked `int size` (negative values pass straight through) and an `arg_len` that is never checked against the args string's length, all fed to `SifExecModuleBuffer`. This binding also has no Lua caller (RE-POPS-048), so the cheapest correct fix is removal.
- Fix: For (a), take the length from `luaL_checklstring` and drop (or clamp to) the second argument. For (b), delete the binding with the RE-POPS-048 pass; if it is ever restored, it needs `luaL_checklstring` + a size equality check.
- Benefit: Closes the only two places in the EE core where a Lua integer, rather than the data itself, decides how many bytes C reads.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-028 — Graphics.threadLoadImage passes a Lua-owned string pointer straight to a worker thread, and its second argument is unreachable
- Category: 6
- Locations: src/luagraphics.cpp:20-26, src/luagraphics.cpp:265-285, src/luagraphics.cpp:489-512, src/luagraphics.cpp:788-808, src/luagraphics.cpp:838, src/luagraphics.cpp:852-853
- Problem: `lua_loadimgasync` stores the `luaL_checkstring` pointer itself as the thread argument; the string belongs to the Lua heap and can be collected or moved while `imgThread` is still reading it — a use-after-free the file's own cover-worker comment (src/luagraphics.cpp:36-44) already documents as the reason the newer cover loader copies its path. The result channel is the same vintage: the thread `sprintf`s the texture pointer into a 16-byte heap buffer returned later by `getLoadData`, with one global slot and no request association. Additionally the arity check `if (argc != 1) return luaL_error(...)` makes the following `if (argc == 2) asyncDelayed = ...` branch unreachable, so the delayed flag can never be set from Lua. The binding and both result bindings have no Lua caller (RE-POPS-048); the cover loader supersedes them.
- Fix: Delete `threadLoadImage`, `getLoadState`, `getLoadData`, `imgThread` and their globals/stack; the cover-load worker is the single async image path.
- Benefit: Removes a documented use-after-free and a whole superseded async mechanism (~90 lines) instead of leaving it armed for the next caller.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-029 — bd_cache_create dereferences unchecked allocations
- Category: 6
- Locations: tarball:libbdm/src/bd_cache.c:160-166,179-191
- Problem: `bd_cache_create` performs two `AllocSysMemory` calls and immediately writes through both results (`c->bd = bd`, `cbd->priv = c`, …) with no NULL check. Under IOP memory pressure (see RE-POPS-052: each cache is 128 KiB) allocation failure is a realistic event, and the failure mode is a wild-pointer write during device connect rather than a clean "no cache" fallback that `bdm_connect_bd` could otherwise tolerate (`cbd` is already allowed to be NULL there).
- Fix: Check both allocations; on failure free whichever succeeded and return NULL.
- Benefit: Memory exhaustion degrades to uncached I/O instead of crashing the IOP on device insertion.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-030 — atlas allocation results are never checked: OOM is a NULL dereference, not a failure return
- Category: 6
- Locations: src/atlas.cpp:12-25, src/atlas.cpp:84-110, src/atlas.cpp:165-183
- Problem: `allocNew` writes through its `malloc` result unconditionally; `allocPlace` creates two leaf allocations per placement and stores them unchecked; `atlasNew` writes through two unchecked allocations (`malloc` for the atlas, `memalign` for the surface) and then `memset`s the surface pointer. Any allocation failure in the glyph-atlas path — the path every rendered character takes — is an immediate NULL dereference instead of the graceful "no atlas free" return that `fntGlyphAtlasPlace` already implements for the placement-failure case.
- Fix: NULL-check the three allocation sites and propagate failure (`allocPlace` returns NULL, `atlasNew` frees and returns NULL), matching the failure handling the caller already has.
- Benefit: Font rendering degrades (missing glyphs) instead of crashing the EE when the heap is exhausted.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-031 — fntsys readFile ignores the read() result, so a short read hands FreeType an uninitialised tail
- Category: 6
- Locations: src/fntsys.cpp:123-152, src/fntsys.cpp:286-312
- Problem: `readFile` sizes the buffer from `lseek(SEEK_END)`, allocates it, then calls `read(fd, buffer, realSize)` and discards the return value, reporting `*size = realSize` regardless of how many bytes actually arrived. A short read (or a file that shrinks between the seek and the read) leaves the tail of the buffer uninitialised, and `fntLoadSlot` passes that buffer and the full claimed size to `FT_New_Memory_Face`. The same function casts a failed `lseek` (-1) through the allocation size path instead of rejecting it up front.
- Fix: Capture the `read` result; on a short or failed read (or `realSize <= 0`), free, close and return NULL — the caller already treats NULL as a clean load failure.
- Benefit: Font loading fails cleanly on I/O trouble instead of feeding heap garbage to the FreeType parser.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-032 — graphics loadFont branches on an uninitialised magic value when the file cannot be opened
- Category: 6
- Locations: src/graphics.cpp:932-950, src/luagraphics.cpp:287-315
- Problem: `loadFont` does `int file = open(path, O_RDONLY, 0777); read(file, &magic, 2); close(file);` with no check on any of the three calls. If `open` fails, `file` is -1, `read` fails, and `magic` — an uninitialised stack `uint16_t` — decides which `gsKit_init_font` branch (if any) runs on a nonexistent path; the result is then uploaded without a NULL check in the caller pattern (`lua_fontload` checks for NULL, but `printFontText`/`unloadFont` dereference `font`/`font->Texture` unchecked). This is the legacy gsKit-font subsystem whose Lua bindings (`Font.load/print/unload`) have no caller (RE-POPS-048) — the FreeType path is the live one.
- Fix: Prefer deletion with the RE-POPS-048/08 pass (bindings + `loadFont`/`printFontText`/`unloadFont` + the gsFontM trio `loadFontM`/`printFontMText`/`unloadFontM` at src/graphics.cpp:908-930, whose bindings are likewise uncalled). If any part is kept, `open`/`read` results must be checked and `magic` initialised before use.
- Benefit: Removes an uninitialised-read bug and a whole parallel font subsystem (three file formats, its own upload path) that duplicates what fntsys already does.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-033 — Pads.getPressure reads an uninitialised padButtonStatus when no pad read succeeds
- Category: 6
- Locations: src/luacontrols.cpp:148-213
- Problem: `lua_getpressure` declares `padButtonStatus pad;` uninitialised, calls `padRead` / `ds34bt_get_data` / `ds34usb_get_data` without checking any return value, and then switches over `pad.right_p` / `pad.left_p` / … — so with no controller in a stable state (or all three reads failing) the returned pressure is stack garbage. Its sibling bindings in the same file were already hardened for exactly this failure (zero-init + neutral 127 defaults + return-value gating in `lua_getleft`/`lua_getright`, src/luacontrols.cpp:82-146); this one function was missed.
- Fix: Give `lua_getpressure` the same treatment as its siblings: zero-initialise the struct, track whether any read succeeded, and return 0 pressure when none did.
- Benefit: Deterministic pressure values and parity inside one file; removes the last uninitialised-read in the pad bindings.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-034 — HDD partition index from Lua is turned into a device-name byte with `'0' + index` and no range check
- Category: 6
- Locations: src/luaHDD.cpp:42-50, src/luaHDD.cpp:56-64
- Problem: `UmountPart` does `PFS[3] = '0' + luaL_checkinteger(L, 1)` and `mnt()` does `PFS[3] = '0' + index` (guarded only by `index > 0`) on the fixed `"pfs0:"` template. Any Lua integer outside 0-9 writes an arbitrary byte into the device name (index 17 produces `pfsA:`, index -1 in `UmountPart` produces `pfs/:`), and the resulting malformed name is passed to `fileXioUmount` / `fileXioMount`. The valid domain is a single digit — the callers only ever address pfs0:-pfs3: (the exec path in elf.c caps slots at 3).
- Fix: Range-check the index (0-9, or 0-3 to match the rest of the tree) in both bindings and return a Lua error / failure for anything outside it.
- Benefit: A bad Lua argument becomes an error instead of a malformed device operation against an arbitrary driver name.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-035 — EE ds34 clients copy the RPC buffer to the caller even when the RPC failed
- Category: 6
- Locations: modules/ds34usb/ee/libds34usb.c:126-139, modules/ds34bt/ee/libds34bt.c:119-132
- Problem: Both EE `get_data` implementations compute `ret = (SifCallRpc(...) == 0)` and then unconditionally `memcpy(data, rpcbuf, 18)`. On RPC failure `rpcbuf` holds the previous call's pad data (it is a static, never cleared), so the caller receives stale buttons presented as a fresh sample alongside a failure return that the typical poll loop ignores. `ds34usb_get_bdaddr` (libds34usb.c:64-81) has the same shape in miniature: it copies all 6 address bytes out of `rpcbuf` regardless of the `ret &= rpcbuf[0]` result.
- Fix: Copy out only when the RPC succeeded (and, for `get_bdaddr`, when the IOP returned 1); otherwise leave the caller's buffer untouched.
- Benefit: Failed polls stop masquerading as live controller input on the EE side.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-036 — MBR parser leaks its allocation on the read-failure path
- Category: 6
- Locations: tarball:bdm/src/part_driver_mbr.c:37-43; tarball:__bdm_assault/src/bdm/bdm_part_driver_mbr.c:37-43
- Problem: If `bd->read(bd, 0, pMbrBlock, 1)` fails, the function returns without `FreeSysMemory(pMbrBlock)` — every other exit path in the same function frees it. `part_connect_mbr` is attempted for every newly connected block device (MBR is registered before GPT and FatFs in `part_init`/`bdm_try_mount`), so each unreadable or non-MBR device that fails at the read step leaks 512 bytes of IOP memory permanently; there is no recovery short of reboot.
- Fix: Free `pMbrBlock` before the return at line 42.
- Benefit: Removes a slow, per-device permanent IOP memory leak on a hot plug/unplug path.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-037 — FatFs re-entrancy grant ignores its own timeout
- Category: 6
- Locations: tarball:bdmfs_fatfs/src/ffsystem.c:146-168; tarball:bdmfs_fatfs/src/include/ffconf.h:279-280; tarball:__bdm_assault/src/bdmfs/bdmfs_ffsystem.c:146-168
- Problem: `ffconf.h` sets `FF_FS_REENTRANT 1` with `FF_FS_TIMEOUT 1000`, and the FatFs contract is that `ff_req_grant` returns 0 on timeout so the caller fails with `FR_TIMEOUT`. The IOP implementation calls `WaitSema(sobj)` — which waits indefinitely — and unconditionally returns 1. Any volume lock leaked or held by a stuck operation therefore hangs every subsequent FatFs call on that volume forever instead of surfacing a timeout, compounding RE-POPS-019's lock-hang surface.
- Fix: Use a timed wait (poll/`iWaitSema` with the timeout) and return 0 when it expires, per the sample contract in the same file's comments.
- Benefit: Restores the designed failure mode (an error) in place of an unbounded hang.
- Effort: S · Risk: Med · Confidence: High (READ)

### RE-POPS-038 — fs_devctl dispatches STOP_UNIT to stop-all and STOP_ALL to stop-one
- Category: 6
- Locations: tarball:bdmfs_fatfs/src/fs_driver.c:767-797; tarball:__bdm_assault/src/bdmfs/bdmfs_fs_driver.c:767-797
- Problem: In `fs_devctl`, `case USBMASS_DEVCTL_STOP_UNIT:` calls `fatfs_fs_driver_stop_all_bd()` and `case USBMASS_DEVCTL_STOP_ALL:` calls `fatfs_fs_driver_stop_single_bd(fd->unit)` — the two handlers are transposed relative to their command names. A caller asking to stop one unit (e.g. before ejecting one drive) unmounts and stops **every** mounted device; a caller asking to stop all devices stops only its own unit and leaves the rest spinning/mounted. (The command constants come from the external `usbhdfsd-common.h`, not present in the tarball; the finding rests on the plain meaning of the names as used in this switch, which is also how the helper functions are named.)
- Fix: Swap the two bodies so STOP_UNIT stops `fd->unit` and STOP_ALL stops all.
- Benefit: Devctl callers get the stop scope they asked for; multi-device users stop losing unrelated mounts.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-039 — Callback thread reads the request after freeing it (GP-register build only)
- Category: 6
- Locations: tarball:usbd/src/driver.c:241-255; tarball:__usbd_bd_assault/src/usbd/usbd_driver.c:241-255; tarball:__usbd_bd_assault/src/usbd/usbd_usbd_driver.c:241-255
- Problem: `callbackThreadFunc` carefully copies the request (`memcpy(&reqCopy, req, …)`), frees the original (`freeIoRequest(req)` — returning it to a pool other threads allocate from), and then, under `#if USE_GP_REGISTER`, executes `SetGP(req->gpSeg)` — reading the **freed** request instead of `reqCopy.gpSeg`. `USE_GP_REGISTER` is not defined anywhere in the tarball (it would come from the PS2SDK build environment), so this is latent in the shipped configuration, but the copy exists precisely to make the post-free code safe and this one line defeats it.
- Fix: Use `reqCopy.gpSeg`.
- Benefit: Closes a use-after-free read that activates the moment the driver is built with GP-register support.
- Effort: S · Risk: Low · Confidence: Low (READ — conditional on a macro defined outside the tarball)

### RE-POPS-040 — The default shipped POPSTARTER.ELF is the DEBUG profile, not MAIN, and the 1–2 patch bytes that define all five profiles are documented nowhere in the repo
- Category: 6
- Locations: bin/POPSLDR/POPSTARTER.ELF:1040; bin/POPSLDR/PROFILES/MAIN/POPSTARTER.ELF:1040; bin/POPSLDR/PROFILES/USBDELAY/POPSTARTER.ELF:1043; tools/build_release_kit.sh:17-20
- Problem: Script-verified: all five POPSTARTER.ELF files are 167,700 B and differ from the MAIN profile at exactly two byte offsets — offset 1040 (0x00 in MAIN/USBDELAY, 0xFF in DEBUG/USBDELAY_DEBUG) and offset 1043 (2 in MAIN/DEBUG, 6 in USBDELAY/USBDELAY_DEBUG). So the profiles are one binary with two patch bytes, not four builds. The file every workflow and `tools/build_release_kit.sh` ships as *the* `POPSTARTER.ELF` is byte-identical to the DEBUG profile (0xFF at 1040), not to MAIN. No file in `src/`, `tools/`, the Makefile or the workflows names what either byte controls; the names DEBUG/USBDELAY are the only documentation. INFERRED (basis: profile names + the two-byte pattern): byte 1040 is a debug on/off flag and byte 1043 a USB-delay value, which would mean the default install ships with the debug flag on. That may be deliberate — but nothing in the repo says so, and if it is accidental, every release has shipped the debug variant as the default.
- Fix: Record, next to the profiles (or in the packaging script that ships them), what bytes 1040 and 1043 mean and which profile the top-level `POPSTARTER.ELF` is supposed to equal; if MAIN is the intended default, replace the top-level copy with the MAIN bytes and add a hash comparison to the kit verification so the default cannot silently become a different profile again.
- Justification: The hash comparison is an addition; it is justified because the current state — default file identical to a non-default profile, with no recorded intent — is exactly the failure it would catch, and the check is three lines in a script that already does sha256 pins.
- Benefit: The shipped default POPStarter variant becomes a recorded decision instead of an unverifiable accident; a wrong-profile copy is caught by CI rather than by a tester.
- Effort: S · Risk: Low · Confidence: Med (INFERRED — byte-difference facts are script-verified READ; the meaning of the bytes and whether DEBUG-as-default is wrong are INFERRED)

### RE-POPS-041 — 23 of 26 distinct binaries have no in-repo source, and most of them have no hash pin or provenance record either — a silent byte swap would pass CI
- Category: 6
- Locations: tools/test_udpfs_integration.py:17-23; tools/build_release_kit.sh:43-48; .github/workflows/compilation.yml:89-95; docs/third_party/okeanos_udpfs/PROVENANCE.json:1
- Problem: Provenance census (full table below; INFERRED, basis stated per row): only the BDMAssault core (`5ea4818b…`) and the usbmass_bd blob (`70a369e4…`) have corresponding source in this repo, inside `iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz`; `ata_bd.irx` is partial (vendored cousin source, pinned binary from elsewhere). The other 23 distinct binaries — the whole SMB pack, all four POPSTARTER.ELF variants, the ATA and MMCE BDMA pairs, the menu UDPFS trio — are opaque blobs. Pinning is inconsistent: the UDPFS pair has an exemplary `PROVENANCE.json` plus SHA-256 checks, the ilink pair is pinned in `tools/build_release_kit.sh:46-47`, `ata_bd.irx` is pinned in three workflows, and `tools/test_udpfs_integration.py:17-23` pins five blobs by git-blob SHA-1. Everything else embedded into the ELF (six popsmb IRX, the ATA/MMCE/usbexfat BDMA pairs) has no recorded expected hash anywhere: replace one with different bytes and every CI gate stays green.
- Fix: Extend the existing pin table — one file listing SHA-256, size, upstream origin and licence for every tracked binary, checked by the step that already exists in the lua-harness job — instead of the current three separate pinning mechanisms covering disjoint subsets.
- Justification: This adds a table and a check. It is justified by a concrete gap: these binaries run on the IOP with full hardware access, ship in every release, and for most of them the repo currently cannot distinguish "maintainer updated the driver" from "bytes changed".
- Benefit: Every shipped binary gets the UDPFS pair's standard of provenance; driver updates become deliberate, reviewable diffs.
- Effort: M · Risk: Low · Confidence: High (READ for the pin-coverage facts; INFERRED for the per-binary source census, basis in the inventory table)

### RE-POPS-042 — opencode workflow runs an unpinned third-party action (`@latest`) with an API-key secret in its environment
- Category: 6
- Locations: .github/workflows/opencode.yml:27-32
- Problem: `opencode.yml:29` uses `anomalyco/opencode/github@latest` — whatever that action's master holds at run time executes in a job holding `DEEPSEEK_API_KEY` (line 31) and an `id-token: write` permission (line 17). The repo itself demonstrates the correct pattern one directory over: rolling-release.yml pins its credential-holding third-party action to a full commit SHA with a comment explaining why (the MEGA action). This workflow is the exception.
- Fix: Pin the opencode action to a reviewed full commit SHA, as the MEGA action is pinned, and bump deliberately.
- Benefit: Closes the one supply-chain hole in an otherwise carefully pinned workflow set (ps2dev image pinned, checkout pinned by major, MEGA action SHA-pinned).
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-043 — The "ABC" on-screen keyboard layout can never be selected: the system normalizer silently converts it to QWERTY
- Category: 6
- Locations: bin/POPSLDR/system.lua:2508, bin/POPSLDR/system.lua:2527-2546, bin/POPSLDR/system.lua:5904, bin/POPSLDR/system.lua:5967, bin/POPSLDR/system.lua:6015, bin/POPSLDR/system.lua:6451, bin/POPSLDR/ui.lua:2533, bin/POPSLDR/ui.lua:2570-2578, bin/POPSLDR/ui.lua:2610-2627, bin/POPSLDR/ui.lua:4691, bin/POPSLDR/ui.lua:4812-4817, bin/POPSLDR/ui.lua:5094-5097
- Problem: `PLDR.KEYBOARD_LAYOUT_ABC = "ABC"` is defined (system.lua:2508), the OSK offers ABC in `layout_order` (ui.lua:2533) with a complete row definition (ui.lua:2570-2578), and the Settings "Keyboard Layout" row cycles through it (ui.lua:4691, 5094-5097). But `NormalizeKeyboardLayout` (system.lua:2527-2546) has branches only for QWERTY/DVORAK/AZERTY/QWERTZ/ABNT and falls through to QWERTY for "ABC". Every path that touches the value normalizes it — encode (5904), snapshot (5967), apply (6015), load (6451), the settings commit (ui.lua:4548-4549), and the PathEditor's own `_NormalizeLayout` (ui.lua:2610-2612), which delegates to the system function whenever it exists, so the editor's own correct ABC-accepting fallback (ui.lua:2614-2619) is unreachable in the real load order. `_CurrentRows` (ui.lua:2621-2627) therefore always resolves "ABC" to the QWERTY rows. The comments even assert the opposite of the code: system.lua:2545 and 6241 say "ABC remains selectable / stays selectable", and ui.lua:4812-4814 claims Reset Defaults' `"ABC"` default works "via NormalizeKeyboardLayout's fall-through" — the fall-through returns QWERTY. Net effect: a user who picks ABC gets QWERTY in-session and on every reboot, with no error.
- Fix: Add the missing ABC branch to `NormalizeKeyboardLayout` in system.lua (one comparison against the already-defined `PLDR.KEYBOARD_LAYOUT_ABC`), so the one normalizer every consumer already routes through accepts the sixth layout it advertises. No new code paths; the ui.lua fallback copy then agrees instead of being dead.
- Benefit: A shipped, selectable setting starts working as labelled; removes a silent settings-loss bug on save/load and a false claim repeated in three comments.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-044 — Shipped usbhdfsd.irx cannot be accounted for by the tarball, and the tarball's second driver is absent from the shipped set
- Category: 7
- Locations: iop/embed/BDMASSAULT_MX4SIO/usbhdfsd.irx (14,993 bytes, shipped); iop/embed/BDMASSAULT_MX4SIO/usbd.irx (48,500 bytes, shipped); tarball:README.MD:13-16; tarball:.github/workflows/CI.yml:38-41
- Problem: See the correspondence section below for the full evidence. In short: the tarball's own README and CI say the pair is `bdm_assault.irx` → shipped as `usbd.irx` and `usbd_bd_assault.irx` → shipped as `usbhdfsd.irx`. The first half holds (string-exact). The second does not: the shipped `usbhdfsd.irx` is an **MX4SIO v1.2** driver (strings `MX4SIO: …`, module name `mx4sio`, imports `sio2man`/`dmacman`/`modload`) — a driver for the SD-card SIO2 adapter, with **no source anywhere in the tarball** (no file mentions MX4SIO or SIO2) — while the tarball's actual `usbd_bd_assault` product (USB core + USB mass storage, strings such as `USBD ASSAULT Start` / `USBD ASSAULT: starting USBMASS Side`) appears in **neither** shipped binary. The shipped set is therefore half-provenance-free, and anyone rebuilding from the tarball cannot reproduce it. (Whether POPSLoader intentionally pairs BDM-Assault-for-USBD with an MX4SIO driver in the USBHDFSD slot is a packaging decision outside this tarball; the finding is that the tarball + README do not disclose it.)
- Fix: Ship the MX4SIO driver's source (or a provenance note naming its origin/version) alongside the binaries, and correct the README's pairing table to state what each shipped file actually is.
- Benefit: The shipped pair becomes reproducible and auditable; the next auditor does not have to reverse the pairing from strings.
- Effort: S · Risk: Low · Confidence: High (READ — binary identification is string-exact, see below)

### RE-POPS-045 — The entire merged-driver tree is a second, hand-maintained copy of every component (ffunicode alone is 79% of the tarball)
- Category: 2
- Locations: tarball:__bdm_assault/ (whole tree); tarball:__usbd_bd_assault/ (whole tree); tarball:bdmfs_fatfs/src/ffunicode.c:1-15593; tarball:__bdm_assault/src/bdmfs/bdmfs_ffunicode.c:1-15593
- Problem: Scripted totals: component + libbdm C/H = 2,469,099 bytes; merged C/H = 2,444,950 bytes — i.e. essentially the whole codebase exists twice, kept in sync by hand-renaming (`bdm_`, `bdmfs_`, `usbd_`, `usbmass_bd_` prefixes) and hand-editing include paths and `_start` symbols (see the diff table below: every merged file is its component with 0-6 substituted lines). The extreme case is vendored FatFs unicode data: `ffunicode.c` is 1,959,389 bytes and its merged copy 1,959,397 bytes — together 3,918,786 bytes, **79.1% of the tarball's 4,951,196 total bytes** (79.7% of its C/H bytes), for a file whose compiled content is already narrowed to one code page by `FF_CODE_PAGE 869` (ffconf.h:101; the per-page tables are `#if`-guarded, ffunicode.c:38). Every future fix — including every Cat-6 fix above — must be applied twice, in two differently-named files, with no script or CI step that verifies the copies still match (see RE-POPS-044).
- Fix: Generate the merged trees from the components at build time (copy + the three mechanical transforms the diff table shows: prefix rename, `include/` path prefix, `_start` chaining), and delete the checked-in merged copies; or, failing that, add a CI diff gate that fails when a merged file differs from its component by anything except the whitelisted transforms.
- Justification: The fix adds a small generator/gate, but it deletes ~2.44 MB of hand-maintained duplicate source and the entire class of component↔merged drift — a net deletion.
- Benefit: One source of truth per file; fixes land once; the tarball shrinks by roughly half.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-046 — Every rolling and experimental release zip embeds a full copy of the entire tracked tree, including the 21 MB research archive
- Category: 4
- Locations: .github/workflows/rolling-release.yml:228; .github/workflows/experimental-release.yml:224
- Problem: Both bundle steps copy every path from `git ls-files` into a `source/` folder inside the release zip (rolling-release.yml:228, experimental-release.yml:224; only `POPSTARTER/` is excluded because it ships separately). Script-verified: the tracked tree is 30,417,169 B, of which `.research/` alone is 312 files / 21,197,583 B (70%) — historical POPStarter downloads, screenshots and the docs-site corpus. So each rolling/experimental zip carries the whole research archive plus the 1.4 MB BDMAssault tarball and every tracked binary a second time (they also ship at the zip root / in the kit), on top of the actual payload.
- Fix: Exclude `.research/` (and any other non-build-input trees) from the `source/` copy, or drop the `source/` copy and point the release notes at the tagged repository tree, which GitHub already serves as a source archive.
- Benefit: Roughly 21 MB off every rolling/experimental download; the "source" in the zip matches what a user needs to rebuild.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-047 — Whole `modules/pademu/` tree is built by nothing
- Category: 1
- Locations: modules/pademu/Makefile:1-25, modules/pademu/pademu.c:1-536, modules/pademu/ds34usb.c:1-634, modules/pademu/ds34bt.c:1-1521, Makefile:82-99,308-324
- Problem: The top-level Makefile builds and embeds only the standalone modules (`modules/ds34usb/iop/ds34usb.irx`, `modules/ds34bt/iop/ds34bt.irx`, EE libs at Makefile:82,308-324; `IOP_MODULES` at Makefile:97-99 lists `ds34bt.o ds34usb.o` from those IRXs). A scripted search of the top Makefile, `.github/`, `src/`, `bin/`, `etc/` for `pademu`/`usb_pademu`/`bt_pademu` returns zero hits. The 3,474 lines under `modules/pademu/` (pademu.c, two full driver copies, sys_utils, headers, exports/imports) therefore compile into no shipped artifact, yet they are the copies that still receive pademu-only edits (analog toggle, fake-DS3 option) — effort spent on dead code, and a trap for anyone fixing the live drivers in the wrong copy.
- Fix: Delete `modules/pademu/` if POPStarter-side pademu IRXs are no longer produced from this repo; if they are produced elsewhere/by hand, move the tree out of `modules/` and label it as that external build's source in one line. Do not keep it beside the live drivers unlabeled.
- Benefit: Removes 3,474 misleading lines and the wrong-copy fix trap; the live ds34 code becomes the only ds34 code.
- Effort: S · Risk: Med · Confidence: High (READ)

### RE-POPS-048 — 52 of 143 registered Lua bindings have no caller in any Lua that can run
- Category: 1
- Locations: src/luaScreen.cpp:157-232, src/luacontrols.cpp:277-282, src/luagraphics.cpp:468-484, src/luagraphics.cpp:830-853, src/luasystem.cpp:2522-2582, src/luasystem.cpp:2630, src/luatimer.cpp:127-132, src/luaplayer.cpp:158-190
- Problem: Scripted census: 143 active (non-commented) `luaL_Reg` entries across all binding files; 91 are referenced from the shipped Lua (`bin/POPSLDR/system.lua`, `ui.lua`, `images.lua`, `etc/boot.lua`) and 52 are not referenced anywhere in it — including `Screen.getFPS`; `Color.getR/getG/getB/getA`; `Pads.getType/getPressure/rumble/setLED/check`; `Font.ftLoad/ftSetPixelSize/ftUnload/ftEnd/print/unload/fmUnload`; `Graphics.drawPixel/drawLine/drawCircle/drawTriangle/drawQuad/threadLoadImage/drawRotateImage/drawPartialImage/drawImageExtended/getLoadState/getLoadData`; `System.seekFile/getFreeMemory/getMCInfo/loadELFRebootIOP/checkValidDisc/getDiscType/checkDiscTray/getAppDir/ensureBDM/ensureBDMFatFs/ensureDev9/ataReady/getSio2Owner/getMassBackendInfo/getMassRootByBackendName/findBDMByDriver`; `IOP.loadModuleBuffer`; `Timer.setTime/destroy/pause/resume/isPlaying`. These are not a public scripting API: `runScript` only ever executes the embedded `boot.lua`, and `DisableLuaFilesystemScriptLoaders` nils `dofile`/`loadfile` and empties `package.path`/`cpath`, so no user script can reach them. Each dead binding keeps its C implementation (and, for the Font/Graphics ones, whole subsystems — see RE-POPS-084, RE-POPS-032) linked into the ELF. Two judgement calls are noted, not hidden: `Pads.getType` and `System.getSio2Owner` are documented in repo docs as diagnostic/do-not-use-for-gating surfaces — they still have no runtime caller.
- Fix: Delete the 52 unreferenced registrations and the implementations that become unreachable with them, in one pass, keeping any binding the parent confirms is a deliberate external contract.
- Benefit: The largest single dead-code cut in the EE core; shrinks the Lua attack/bug surface (several of these bindings are the unsafe ones in RE-POPS-022/12/13) and the ELF.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-049 — Two embedded IRX blobs are byte-identical duplicates of the usbexfat blobs, embedded a second time instead of aliased (83,008 B)
- Category: 2
- Locations: Makefile:115-119, Makefile:220-241, src/embed_assets.cpp:80-87, src/embed_assets.cpp:148-164, src/embed_assets.cpp:209-219, bin/POPSLDR/usbd.irx.ilink (48,500 B), bin/POPSLDR/usbhdfsd.irx.udpfs (34,508 B)
- Problem: Hash-verified twice independently (MD5 and SHA-256 censuses): `usbd.irx.ilink` is byte-identical to `usbd.irx.usbexfat` (48,500 B) and `usbhdfsd.irx.udpfs` is byte-identical to `usbhdfsd.irx.usbexfat` (34,508 B), yet each gets its own bin2c object in `EMBEDDED_RSC`, its own extern pair, and its own table entries — 83,008 bytes of payload carried twice in every built POPSLOADER.ELF. The codebase already knows the correct pattern: `usbd.irx.mx4sio` is aliased to `asset_usbd_irx_usbexfat` with an explanatory comment (src/embed_assets.cpp:149-153) precisely because it is byte-identical; the ilink and udpfs pairs were simply never given the same treatment. (`usbd.irx.udpfs`, 61,949 B, and `usbhdfsd.irx.ilink`, 27,769 B, are distinct blobs and are not part of this finding.)
- Fix: Alias the two duplicate keys to the usbexfat symbols in `g_embedded_assets[]` exactly like the mx4sio alias, and drop `asset_usbd_irx_ilink.o` and `asset_usbhdfsd_irx_udpfs.o` (plus their bin2c/BIN2S rules and externs). Keep the on-disk files — only the second embedded copy goes.
- Benefit: −83,008 bytes in every shipped POPSLOADER.ELF with zero behaviour change; one less pair of blobs that can silently diverge on a future driver update.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-050 — The same binaries are tracked two to four times in git under different paths
- Category: 2
- Locations: POPSTARTER/SMSUTILS.irx:1; bin/POPSLDR/popsmb/SMSUTILS.irx:1; iop/embed/BDMASSAULT_MX4SIO/usbd.irx:1; bin/POPSLDR/POPSTARTER.ELF:1; bin/POPSLDR/PROFILES/DEBUG/POPSTARTER.ELF:1
- Problem: Script-verified byte-identical groups beyond RE-POPS-049: (a) all six SMB-pack IRX (182,654 B total) exist identically in `POPSTARTER/` and in `bin/POPSLDR/popsmb/` — the popsmb copies are embedded into the ELF by the Makefile while the root copies ship at the release-zip root; (b) the BDMAssault pair (63,493 B) exists identically in `iop/embed/BDMASSAULT_MX4SIO/` and as `bin/POPSLDR/usbd.irx.*` / `usbhdfsd.irx.mx4sio`; (c) `bin/POPSLDR/POPSTARTER.ELF` is byte-identical to `bin/POPSLDR/PROFILES/DEBUG/POPSTARTER.ELF` (167,700 B — see RE-POPS-040). Redundant tracked bytes across all groups: ~530 KB of the 1,778,343 tracked binary bytes. Each duplicate is an independent drift risk: nothing in CI compares `POPSTARTER/` against `popsmb/` (only the UDPFS pair and the ilink pair have hash pins — see RE-POPS-041).
- Fix: Keep one canonical copy per distinct binary and have the packaging steps (`tools/build_release_kit.sh`, the rolling/experimental bundle steps) copy from it, instead of tracking the second copy. Where a path is itself a user-facing install location (root `POPSTARTER/`), generate it at bundle time from the canonical popsmb set.
- Benefit: ~530 KB less tracked binary weight; a driver update lands in exactly one place and cannot silently diverge between the embedded copy and the shipped copy.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-051 — The generated bin2c blob `src/elf_loader/loader.c` (855,821 bytes) is committed and regenerated on every build
- Category: 7
- Locations: src/elf_loader/loader.c:1-5, src/elf_loader/Makefile:28-31
- Problem: The two files named `loader.c` are not two loaders. `src/elf_loader/src/loader/src/loader.c` (442 lines) is the child-loader source; `src/elf_loader/loader.c` (8,740 lines, 855,821 bytes, script-measured) is a generated hex dump of the compiled, stripped child (`size_loader_elf = 139700`). The elf_loader Makefile regenerates it under `FORCE` from `src/loader/bin/loader.elf` on every build, and its own comment says CI validates parity by re-running bin2c and `cmp`-ing against this file — i.e. the repo carries an 856 KB generated artifact purely as a checksum fixture, and every child-loader change produces an 8,740-line diff in it.
- Fix: Stop tracking the generated file (generate it into the build tree like the other bin2c outputs in the root Makefile's `asm/` directory) and have CI compare the freshly generated blob against the freshly built `loader.elf` instead of against a committed copy.
- Benefit: Removes 856 KB and one whole class of mega-diffs from the repo; eliminates the recurring trap of reading the hex dump as if it were the loader source.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-052 — The block cache reserves 128 KiB of IOP RAM per whole device
- Category: 4
- Locations: tarball:libbdm/src/bd_cache.c:8-9,17; tarball:bdm/src/bdm.c:59-60
- Problem: `struct bd_cache` embeds `cache[32][8 × 512]` = 131,072 bytes, allocated per whole-device in `bdm_connect_bd` (`parNr == 0` → `bd_cache_create`). The IOP has 2 MiB total; this package's own USB stack supports 2 mass devices (`NUM_DEVICES 2` in both usbmass files), so the caches alone can claim 256 KiB — 12.5% of IOP RAM — before the USBD pools, FatFs structures (RE-POPS-067) and thread stacks are counted, and `bd_cache_create`'s unchecked allocations (RE-POPS-029) are what stand between that appetite and a crash. No measurement or comment in the tree justifies 32 blocks over, say, 8 (32 KiB), for a workload dominated by FAT and directory scans.
- Fix: Reduce `BLOCK_COUNT` to 8 unless a benchmark on real hardware shows otherwise, and note the per-device cost at the define.
- Benefit: Frees up to 192 KiB of IOP RAM across two devices — headroom the rest of this driver stack visibly needs.
- Effort: S · Risk: Med · Confidence: High (READ — sizes are arithmetic from the defines; the "no justification in tree" part is a full-text search result)

### RE-POPS-053 — ds34 drivers exist as two hand-synced copies per transport; fixes land in one copy only
- Category: 2
- Locations: modules/pademu/ds34usb.c:1-634, modules/ds34usb/iop/ds34usb.c:1-806, modules/pademu/ds34bt.c:1-1521, modules/ds34bt/iop/ds34bt.c:1-1719, modules/ds34usb/iop/smsutils.S:1-180, modules/ds34bt/iop/smsutils.S:1-180
- Problem: Each transport's USB-descriptor walk, report parsing, LED/rumble and HCI/L2CAP state machine exists twice (399 and 512 diff lines respectively — census table above), plus byte-identical `smsutils.S` (same md5) and `irx_imports.h` in both standalone modules. The copies are already out of sync in both directions: the standalone BT copy has the correct DS4 `memset` size and the pademu copy does not (RE-POPS-025); the pademu USB copy has the DS3 null-report guard and the standalone USB copy does not (RE-POPS-026); `power_level` OOB and the descriptor-walk flaw exist in all four copies (RE-POPS-002, RE-POPS-010). Every future fix must currently be made up to four times.
- Fix: Consolidate to one source per transport: keep the standalone IOP files as the single implementation and, if pademu is retained at all (see RE-POPS-047), have pademu link/include that same file with its `MAX_PADS`/front-end differences behind the existing `USB`/`BT` defines instead of carrying a forked copy; keep one `smsutils.S`/`irx_imports.h` and reference it from both module Makefiles.
- Benefit: One place per bug; the two already-diverged fixes (RE-POPS-025, RE-POPS-026) stop being copy-dependent.
- Effort: L · Risk: Med · Confidence: High (READ)

### RE-POPS-054 — Embedded-asset table stores every asset twice: 100 entries for 49 unique blobs
- Category: 2
- Locations: src/embed_assets.cpp:114-243
- Problem: Scripted count: `g_embedded_assets[]` holds exactly 100 `ASSET_ENTRY` rows (50 bare keys + 50 `POPSLDR/`-prefixed keys) over only 49 unique symbols/blobs. Every asset addition or removal must be typed twice in this file, on top of the Makefile rule and the `images.lua` registration — and the lookup side already normalises bare names, `IMG/` prefixes and `POPSLDR/` prefixes into one canonical key in `embedded_get` (src/embed_assets.cpp:243-293), so the duplicated half of the table exists only to serve callers that pass the prefixed form verbatim.
- Fix: Keep only the canonical (prefixed) half of the table and let `embedded_get`'s existing normalisation map every caller form onto it; delete the 50 duplicated bare rows (the one mx4sio alias row collapses with them).
- Benefit: Halves the table, removes one of the three hand-coordinated places an asset edit can go wrong, and makes a missed duplicate entry (bare works, prefixed 404s, or vice versa) impossible.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-055 — The entire translation database is inlined in system.lua: 2,276 lines / 172,314 bytes parsed on every boot, including for English users
- Category: 4
- Locations: bin/POPSLDR/system.lua:2568-4843
- Problem: By script: the `PLDR.I18N` literal spans 2,276 lines and 172,314 bytes — 30% of system.lua's 568,668 bytes — holding 2,249 entries across seven languages (FR 304, DE 305, PT 305, ES 304, IT 305, HU 317, SK 409). It is part of the main chunk, bin2c-embedded into the ELF, and constructed as a table at every boot before any UI appears, even though `PLDR.L` (system.lua:4844-4854) returns the input untouched for the default `EN` and only ever reads the single active language's sub-table. An English user pays the full parse/table cost for seven languages they will never select; every language addition grows the main chunk, which the code itself notes is near Lua's 200-local cap (system.lua:5795, 5171).
- Fix: Move `PLDR.I18N` out of system.lua into one data chunk per language (or one chunk holding all seven), loaded lazily the first time `PLDR.L` is called with a non-EN language (and on language change), leaving system.lua with the lookup function only.
- Justification: This adds one lazy-load step, which is justified by a concrete problem: it removes 172 KB of dead-at-boot data from the critical chunk for the default language, and it is the only way to stop translation growth from pressuring the main chunk's local cap. Net win is structural (smaller boot chunk, pay-only-for-selected-language), not a new abstraction — the table, keys, and fallback semantics are unchanged.
- Benefit: system.lua shrinks by ~19% of its lines; boot no longer constructs 2,249 unused entries for EN users; translators edit a data file instead of the launch-critical chunk.
- Effort: M · Risk: Med · Confidence: Med (INFERRED — sizes and counts are script-measured and READ; the per-boot parse cost itself was not measured on hardware)

### RE-POPS-056 — Three iop/embed binaries are dead: nothing builds, embeds or loads them
- Category: 1
- Locations: iop/embed/bdmfs_vfat.irx (30,013 B), iop/embed/mx4sio_bd_mini.irx (13,897 B), iop/embed/PS2SDK_MX4SIO/mx4sio_bd.irx (15,089 B), Makefile:346-350
- Problem: The three binaries are requested by no `IOP_MODULES` entry, no explicit Makefile rule and no Lua/C++ loader reference (grep-verified across Makefile, `src/`, `bin/POPSLDR/*.lua`); the generic `vpath %.irx iop/embed/` rule cannot even reach the PS2SDK_MX4SIO copy because vpath is not recursive. The Makefile itself says the PS2SDK_MX4SIO copy was de-pinned and "left in place, untouched" (Makefile:346-350). Total dead weight: 58,999 B of binaries that a reader will reasonably assume ship. (The same section finding's fourth limb — the vendored `iop/ata_bd_fast/` source tree — is consolidated as RE-POPS-057.)
- Fix: Delete the three binaries (git history preserves them).
- Benefit: −59 KB of tracked binaries; "what produced this IRX" stops having a wrong-looking answer in the embed folder.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-057 — Vendored `iop/ata_bd_fast/` is kept but explicitly unused; the pinned binary wins
- Category: 7
- Locations: iop/ata_bd_fast/ps2atad.c:1-1593, iop/ata_bd_fast/atad.h:1-132, iop/ata_bd_fast/Makefile:1-40, Makefile:332-344
- Problem: The root Makefile states it in its own comment (Makefile:332-340): the embedded `ata_bd.irx` is pinned to `iop/embed/ata_bd.irx` (SHA-256 checked in CI) and "The iop/ata_bd_fast vendored source and its build rule below are kept but unused." So 1,725 lines of vendored ATAD v2.7 — including POPSLoader's own phantom-slave probe cap (`ps2atad.c:444-494,1243-1300`) — sit in the tree, buildable via a rule nothing invokes, and will silently diverge from both the pinned binary and upstream PS2SDK ATAD (the file itself notes SDK 3.1.0 / ATAD 2.9 divergence at ps2atad.c:46-48). A reader cannot tell from the source tree alone that none of it ships.
- Fix: Delete `iop/ata_bd_fast/` and its dead build rule, keeping the pin comment pointing at `iop/embed/ata_bd.irx`; if the source must be retained for provenance, archive it outside the build tree with the pinned binary's origin in one line.
- Benefit: Removes 1,725 unused lines and a build rule that produces a binary CI would reject if it were ever wired in.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-058 — The superseded ps2atad stack is still embedded into every ELF, and two IMPORT_BIN2C externs are unused
- Category: 7
- Locations: Makefile:98, src/luaHDD.cpp:166-174
- Problem: `IOP_MODULES` still bin2c-embeds `ps2atad.o`, but the only reference to the `ps2atad_irx` symbol in the EE sources is the unused `IMPORT_BIN2C(ps2atad_irx)` extern in luaHDD.cpp — `Load_HDD_IRX` deliberately no longer loads it, because ata_bd (the BDM-enabled atad) replaced it and loading both was the documented APA-boot freeze. The blob is therefore linked into every ELF and never executed. The same file declares `IMPORT_BIN2C(poweroff_irx)`, also never referenced in the file. (The related dead build rule for `iop/ata_bd_fast/` is covered by RE-POPS-057.)
- Fix: Remove `ps2atad.o` from `IOP_MODULES` and delete the two unused `IMPORT_BIN2C` lines.
- Benefit: One atad in the ELF — the one that actually loads.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-059 — SMB defaults that no longer exist (port 1111, preset LAN addresses, DHCP-by-default, guest) still presented as current
- Category: 6
- Locations: STATE.md:65 (`SMB/network = PS2 IP 192.168.1.10, gateway/DNS 192.168.1.1, server 192.168.1.100, share games, user guest, port 1111 (DHCP stays ON). Reset Defaults targets these`); STATE.md:237 (`SyncSmbDat deleted the IPCONFIG.DAT … whenever IP assignment was DHCP — the shipped default` and the closing note `the SMB Port default 1111 is deliberate`); TESTING.md:131 (`Port (default 1111 …)`); TESTING.md:135 (`Port (default 1111)`); ROLLING_NOTES.md:130 (`Port — default 1111`); ROLLING_NOTES.md:177 (`whenever IP assignment was set to DHCP, which is the default`); README.md:178 (User / Password default listed as `(guest)`) — vs code evidence: bin/POPSLDR/system.lua:5770-5785 (`PLDR.SMB_FIELDS`: `DHCP default = false`; `PS2_IP`/`NETMASK`/`GATEWAY`/`SERVER`/`PORT`/`SHARE`/`USER`/`PASS` all `default = ""`) and the block comment at bin/POPSLDR/system.lua:5760-5768 (`NO DEFAULT VALUES for anything POPSTARTER reads… Blank now means blank`)
- Problem: The no-defaults change removed every preset, but the canonical status doc's factory-defaults bullet and Known-Issues note, the tester checklist, the rolling notes, and README's SMB table still tell users/testers that fields come pre-filled — worst, TESTING instructs testers to treat 1111 as the port default, so a tester on a stock 445 server who "leaves the default" tests a dead port and files a phantom connect failure. README's own SMB prose (correctly) says "No defaults are supplied for any network field", contradicting its own table's `(guest)`.
- Fix: Delete/correct each instance to the shipped behaviour: every SMB field starts blank, DHCP defaults off (Static), blank Port means POPSTARTER uses 445, blank User/Password means no credentials. In STATE.md:65 remove the SMB values from the EXP34 factory-defaults bullet or mark that sub-bullet superseded by the no-defaults change.
- Benefit: Testers stop chasing a non-existent default; the canonical doc stops contradicting the code comment that exists precisely to prevent this misunderstanding.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-060 — i.Link documented as a stub / not implemented / Ember-only; it is implemented for Ember and POPSTARTER
- Category: 8
- Locations: ARCHITECTURE.md:253 (`| 6 | i.Link | **stub** (ui.lua:4318) |`); ARCHITECTURE.md Layer 4 scenes list (omits `GILINK` entirely); COMPONENTS.md:474 (`i.Link (OPT6): NOT implemented (ui.lua:4462)`); COMPONENTS.md scenes list (omits `GILINK`); README.md:84 (`i.Link is experimental (Ember only…)`); README.md:139 (`experimental: Ember games only`); README.md:263 (`It lists and launches **Ember** games only… POPSTARTER titles over i.Link are not implemented`); QA_REGRESSION_MATRIX.md:44 (`i.Link remains unimplemented`); ROLLING_NOTES.md:149 (`the not-yet-implemented **iLink** stub`) — vs code evidence: bin/POPSLDR/ui.lua:6425-6450 (OPT 6 dispatch: `PLDR.InitILINKRoot()`, `PLDR.GetPS1GameLists(ilink_root.."POPS/", …)`, `UI.SceneChange(UI.SCENES.GILINK)`); bin/POPSLDR/ui.lua:1067 (`GILINK = 11`); bin/POPSLDR/system.lua:9166-9176 (`PLDR.InitILINKRoot`); bin/POPSLDR/system.lua:5157-5165 (`BDMA_SUFFIX.ILINK = ".ilink"` — the staged RiptOPL i.LINK pair); bin/POPSLDR/system.lua:10699-10702 (ILINK launch policy for POPSTARTER); bin/POPSLDR/system.lua:8862-8863 (Ember root on the i.Link scene); bin/changelog [1.4.2] (i.Link page + POPSTARTER titles on it)
- Problem: Five current-facing docs still describe the pre-1.4.2 state. The page exists, has its own scene (11), lists and launches both Ember games and POPSTARTER VCDs via the staged `.ilink` BDMA pair, and shipped experimentally in 1.4.2. README contradicts itself: its storage table and 1.4.2 summary correctly say "Ember games and POPSTARTER titles" while three other README passages say Ember-only / not implemented. A user following these docs will not try POPSTARTER over i.Link, and a contributor following COMPONENTS/ARCHITECTURE may "clean up" a live dispatch.
- Fix: In each location, replace stub/not-implemented/Ember-only prose with the STATE.md formulation (experimental, hidden by default, hardware-untested; Ember + POPSTARTER via the `.ilink` pair); add `GILINK = 11` to both scene enumerations.
- Benefit: Docs stop denying a shipped feature; the internal README contradiction disappears.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-061 — fs_ioctl2's RENAME command is an admitted TODO stub, and the ops table is padded with dummy slots
- Category: 8
- Locations: tarball:bdmfs_fatfs/src/fs_driver.c:668-674,795-830; tarball:__bdm_assault/src/bdmfs/bdmfs_fs_driver.c:668-674,795-830
- Problem: `USBMASS_IOCTL_RENAME` — a command in the `usbhdfsd-common` ioctl set that host code can legitimately issue — is implemented as `// TODO … ret = -ENOENT;`, reporting "no such file" for an operation that was never attempted, which callers cannot distinguish from a genuinely missing file. Around it, the `fs_functarray` ops table routes six slots (format, chstat, and four others) to `fs_dummy`, which returns -5, and registers `fs_remove` in both the remove and the rmdir slots. The driver presents a full iomanX interface while a visible fraction of it is placeholder.
- Fix: Implement RENAME via `f_rename` using the open file's volume (the two-path problem the TODO cites is solvable from `fd->unit` + the file's name via the existing mount-info table), or return a distinguishable `-ENOSYS`-style error; mark dummy ops slots as unsupported rather than -5.
- Benefit: Callers stop misreading "unimplemented" as "file not found" — a distinction that matters to any host doing rename-based save-file rotation.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-062 — The `__RTL` renderer in fntsys.cpp is a half-finished second implementation that is never compiled and could not compile
- Category: 8
- Locations: src/fntsys.cpp:693-849
- Problem: `fntRenderString` exists twice: the live `#ifndef __RTL` version (src/fntsys.cpp:601-692) and an `#else` RTL version with `isRTL` / `isWeak` / `fntRenderSubRTL` (lines 693-849, ~157 lines). Nothing defines `__RTL` — no Makefile flag, no header, no build option (scripted grep over the repo build files) — and the dead branch calls `rmScaleX` / `rmScaleY` / `rmUnScaleX`, which are defined nowhere in the tree, so flipping the define on is an immediate compile break, not a feature toggle.
- Fix: Delete the `#else` branch and its three helper functions; keep the single live renderer. If RTL support is ever scheduled, it should be re-derived against the current renderer, not resurrected from this snapshot.
- Benefit: fntsys loses a quarter of its bulk and the next font bug gets fixed in exactly one place.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-063 — GetMassRootByBackendName defeats the BDM cache and re-binds the RPC on every single call
- Category: 5
- Locations: src/luasystem.cpp:321-360, src/luasystem.cpp:343-344, src/luasystem.cpp:521-526, src/luasystem.cpp:560-578
- Problem: Structural, not micro: a BDM device cache exists (`mass_backend_cache` + `EnsureMassBackendCache`), but `GetMassRootByBackendNameInternal` — the implementation behind `System.getMassRootByBackendName` — begins by forcing `mass_backend_cache_valid = false` and `bdm_rpc_bound = false`, then calls `FetchBdmList`, which re-runs `SifBindRpc` and a full RPC round-trip for the whole device list, on every lookup. `lua_refresh_mass_backends` also clears the bind flag without any unbind, so repeated refresh/lookup cycles accumulate bind attempts against the fixed-slot bdm_query server. Page-entry code that resolves several backends by name pays one full enumeration per name.
- Fix: Let the by-name lookup use the existing cache like `lua_get_mass_backend_info` does (invalidate only in `RefreshMassBackendCache`), and stop clearing `bdm_rpc_bound` outside an actual RPC failure.
- Benefit: Backend resolution becomes O(1) cached reads after the first enumeration instead of an IOP RPC + bind per call, on the storage-page paths that already have documented scan-latency history.
- Effort: S · Risk: Med · Confidence: High (READ)

### RE-POPS-064 — Settings screen rebuilds its entire item list — and ~100 fresh closures — on every rendered frame
- Category: 5
- Locations: bin/POPSLDR/ui.lua:4351, bin/POPSLDR/ui.lua:4383-4391, bin/POPSLDR/ui.lua:4407-4460, bin/POPSLDR/ui.lua:4929
- Problem: The Settings scene's `Play` function (starting ui.lua:4351) is a per-frame draw/input handler dispatched from the main loop. Inside it, every frame: five constant `Color.new(...)` values are re-created (4383-4391), roughly ten helper closures are redefined (`TruncateMiddle`, `CycleIndex`, `clear_settings_session`, `restore_settings_session`, `discard_settings_and_return`, `queue_exit`, …, 4407-4460), and the item list is rebuilt from scratch — `local items = {}` at 4929 followed by, by script count over the Play body (4351-5914), 37 `AddSection/AddSpacer/AddCycle/AddInfo/AddPath/AddAction` calls whose arguments include 101 `function(` closure literals (each cycle row passes four fresh anonymous functions for value/prev/next/dirty). None of this depends on frame-varying state except the values the getters read; the structure only changes when the user enters/leaves Settings.
- Fix: Build the items table and its row closures once when the Settings scene is entered (the existing `UI.SyncSettingsDraftFromRuntime` / scene-entry point already runs there), store it on `UI`, and let `Play` only read focus/dirty state and draw. Hoist the five constant colors next to the other file-level colors (ui.lua:120-121 shows the pattern already used for list colors).
- Benefit: Eliminates ~100+ closure allocations plus a 37-row table rebuild per frame for as long as Settings is open — the most allocation-dense screen in the UI — with no behaviour change.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-065 — A failing sector is retried 16 times end-to-end with no delay, reset, or backoff
- Category: 5
- Locations: tarball:usbmass_bd/src/scsi.c:13,184-246; tarball:__usbd_bd_assault/src/usbmass_bd/usbmass_bd_scsi.c:13,184-246
- Problem: `scsi_read`/`scsi_write` wrap each chunk in `for (retries = SCSI_MAX_RETRIES; retries > 0; retries--)` — 16 immediate re-issues of the identical command. Each attempt already runs the full BOT exchange including `usb_bulk_manage_status`'s stall-clear and reset-recovery (usb_mass.c), so a genuinely failing sector (bad media, spun-down drive) costs 16 full command+recovery cycles back-to-back, with no `DelayThread`, no REQUEST SENSE inspection between attempts, and no unit reset — maximising both the latency of the inevitable `-EIO` (multiplied across every chunk of a large transfer) and the chance of keeping a marginal device in its error state. Structurally, retry policy lives at the wrong layer: the transport already recovered or it didn't.
- Fix: Cut the loop to a small number (2-3), inspect sense data between attempts, and add a short delay; let persistent failure return `-EIO` promptly.
- Benefit: Worst-case error latency on bad media drops by roughly the retry factor, and healthy transfers are unaffected.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-066 — USBD always builds its largest pool configuration; the MINI_DRIVER configuration is unreachable
- Category: 4
- Locations: tarball:usbd/src/usbd.c:33-68; tarball:usbd/src/driver.c:273-277; tarball:usbd/src/hcd.c:522-526
- Problem: `usbd.c` contains two `UsbdConfig` tables: the default (32 devices, 64 endpoints, 128+128 transfer descriptors, 256 I/O requests, 8 hubs × 8 ports) and a `MINI_DRIVER` table at roughly half those sizes, with matching halved thread stacks in driver.c/hcd.c. No Makefile in the tarball (component or merged) ever defines `MINI_DRIVER`, and in the merged tree the symbol survives only as the unrelated printf-suppression switch in `module_debug.h`. The shipped USBD therefore always allocates the full-size pools (sized in `initHcdStructs` from these numbers) to serve a package whose only client driver supports at most 2 mass-storage devices behind at most one hub layer.
- Fix: Either define `MINI_DRIVER` for the BDMAssault builds after a hardware smoke test, or delete the dead alternative table so the real footprint is the only thing a reader sees.
- Benefit: Up to ~half the USBD pool allocation (devices/endpoints/TDs/requests/descriptor buffers scale directly from these fields) if enabled; an honest tree if deleted.
- Effort: S · Risk: Med · Confidence: High (READ — "never defined" is a full-tree grep result)

### RE-POPS-067 — fs_driver statically reserves 128 FIL and 16 DIR objects regardless of need
- Category: 4
- Locations: tarball:bdmfs_fatfs/src/fs_driver.c:231-236; tarball:__bdm_assault/src/bdmfs/bdmfs_fs_driver.c:231-236
- Problem: `static FIL fil_structures[128]` and `static DIR dir_structures[16]` sit in BSS permanently. Even in the `FF_FS_TINY 1` configuration this tree uses, a `FIL` carries the shared-object header, cluster state and pointers (tens of bytes), so the file table alone is several KiB of IOP RAM reserved for a driver whose host applications (POPStarter-class loaders) hold a handful of files open at once — and whose own global lock serialises all access anyway. No comment or measurement supports 128.
- Fix: Size `MAX_FILES`/`MAX_DIRS` to a stated, realistic concurrent-open count (e.g. 16/4) and note the BSS cost at the define.
- Benefit: Several KiB of permanent IOP BSS returned for the lifetime of the module.
- Effort: S · Risk: Med · Confidence: Med (READ — counts are exact; per-object byte size is configuration-dependent and was not measured from a build)

### RE-POPS-068 — HDD.ListPartitions reserves a 512-entry × 33-byte static table (16,896 bytes of BSS) for a transient enumeration
- Category: 4
- Locations: src/luaHDD.cpp:124-165
- Problem: `ListPartitions` snapshots partition names into `static char lp_names[512][33]` — 16,896 bytes of permanent BSS — to hold at most 512 APA partition names across a single call. The static is there for a real reason (the comment explains snapshotting before touching the Lua heap so a longjmp cannot strand a directory slot), but the cap is two orders of magnitude past any real drive's PFS partition count, and the memory is paid for the life of the process for a listing operation.
- Fix: Keep the snapshot design; cut the cap to a defensible bound (e.g. 64 entries, still far beyond real APA tables) or allocate the snapshot per call and free it after the table is built. Either keeps the longjmp-safety property.
- Benefit: ~14-16 KB of EE BSS returned permanently, in the memory space where the cover loader and font atlases compete.
- Effort: S · Risk: Low · Confidence: High (READ)

---

### RE-POPS-069 — `bdm_query` reports resident success when its only thread failed to start
- Category: 8
- Locations: iop/bdm_query/bdm_query.c:36-40,84-101
- Problem: `_start` creates the RPC thread, starts it only `if (thread_id >= 0)`, and then unconditionally `return MODULE_RESIDENT_END` (bdm_query.c:95-101). If `CreateThread` fails the module stays resident with no RPC server registered, and every EE-side `bdm_query` call binds to nothing / times out with no IOP-side trace of why. The RPC handler also explicitly discards its `size` argument (`(void)size`, bdm_query.c:38-40) — harmless for the single current command (it takes no payload), but it means a future command added EE-side would be parsed from the 64-byte `bdm_rpc_buffer` with no length ever available IOP-side.
- Fix: Return `MODULE_NO_RESIDENT_END` when `thread_id < 0`, matching the ds34 standalone `_start` functions in this same scope. Leave the handler's `(void)size` alone until a second command exists.
- Benefit: A failed start becomes a visible load failure instead of a silently dead helper.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-070 — ART_LOCATION: a removed setting still plumbed through ~10 live sites as inert cargo
- Category: 8
- Locations: bin/POPSLDR/system.lua:5913, bin/POPSLDR/system.lua:5975, bin/POPSLDR/system.lua:6038-6039, bin/POPSLDR/system.lua:6250, bin/POPSLDR/system.lua:6402, bin/POPSLDR/system.lua:6484-6485, bin/POPSLDR/system.lua:6587-6588, bin/POPSLDR/ui.lua:3175-3178, bin/POPSLDR/ui.lua:4495, bin/POPSLDR/ui.lua:4524, bin/POPSLDR/ui.lua:4580, bin/POPSLDR/ui.lua:5218-5221
- Problem: The Settings row for ART_LOCATION was removed (EXP35) and cover/details lookup is hard-locked to `<device-root>/ART/` — `BuildCoverCandidates` builds `artdir` from the device root and never consults ART_LOCATION (ui.lua:233-285). ui.lua:5218-5221 itself says the value "is kept inert in the settings file only so older sidecars still parse". Yet the value still flows end-to-end as if live: a UI draft is snapshotted on Settings entry (ui.lua:3175-3178), validated and committed (ui.lua:4495, 4524, 4580), encoded into every save (system.lua:5913), snapshotted (5975), applied (6038-6039), defaulted (6250), parsed on load (6402, 6484-6485), and merged in the settings-commit path (6587-6588). Every one of those sites must be understood and kept consistent for a value that changes nothing.
- Fix: Drop the value from the encode/snapshot/apply/commit/UI-draft plumbing; on load, simply ignore an `ART_LOCATION=` line if present (old sidecars still parse — unknown/absent keys are already the norm in this parser). Keep nothing but that tolerance.
- Benefit: ~10 touch-points and one draft/commit field removed; the settings pipeline gets shorter everywhere it is already hardest to verify, with zero behaviour change.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-071 — The ABNT keyboard layout is a selectable layout whose rows are byte-identical to QWERTY
- Category: 8
- Locations: bin/POPSLDR/ui.lua:2558-2569, bin/POPSLDR/ui.lua:2579-2587, bin/POPSLDR/system.lua:2513
- Problem: The ABNT layout table (ui.lua:2561-2569) and the QWERTY table (ui.lua:2579-2587) were compared by script: the seven row tables are identical apart from the layout name. The in-code comment (ui.lua:2558-2560, and system.lua:2513) explains why — ABNT's distinguishing keys (ç, accents) are non-ASCII and the OSK is single-char ASCII, so they are "intentionally absent". The result is a Settings choice that changes nothing at all when selected: same keys, same order, same symbols. It presents as a feature and behaves as a second name for QWERTY.
- Fix: Remove ABNT from `layout_order` (ui.lua:2533), the `layouts` table, and `NormalizeKeyboardLayout`'s accepted keys (system.lua:2540-2542) — or, if Brazilian users must keep a persisted `ABNT` value parsing, let the normalizer keep accepting it but map it to QWERTY explicitly instead of offering it in the UI. Do not keep a UI-selectable no-op.
- Benefit: One fewer layout to cycle through that does nothing; persisted-value handling stays honest (existing `ABNT` sidecars normalize instead of displaying a phantom layout).
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-072 — Game-list scene carries two permanently-empty scaffolding tables and an unreachable "Not implemented yet" branch, evaluated every frame
- Category: 8
- Locations: bin/POPSLDR/ui.lua:3254-3255, bin/POPSLDR/ui.lua:3266-3280
- Problem: Inside `UI.GameList.Play` (per-frame), the code builds `local titles = {}` (3254), looks up `titles[UI.CURSCENE]` (always nil), then builds `local placeholders = {}` (3266) and tests `placeholders[UI.CURSCENE]` (always nil) around a stub branch that prints "Not implemented yet" and adds a footer legend. The comments concede the state: "Table kept empty so a genuinely-new backend could still opt back into a title" and "No scenes are placeholders anymore… Keeping the (now-empty) table + guard so a genuinely-unimplemented future backend can still opt into the stub render." That is speculative scaffolding for a hypothetical future backend, running (and allocating two tables) on every game-list frame today.
- Fix: Delete both tables, both lookups, the title draw guarded by the always-nil `scene_title`, and the whole placeholder branch. A future backend can re-add a stub when it exists; version control keeps this version.
- Benefit: Removes dead branch + per-frame allocations from the hottest scene in the app, and removes a "Not implemented yet" string (and its translations) that no user can ever see.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-073 — Adaptive BDMA: tester/rolling docs keep the pre-EXP70 USB rule and the old Off default
- Category: 8
- Locations: ROLLING_NOTES.md:125 (`your saved BDMA Mode decides there. Keep it on exFAT-USB if your USB drive is exFAT; anything else means FAT32. Default Off`); TESTING.md:162 (`If it's FAT32: any other saved mode is fine — USB launches remove the drivers so POPStarter's built-in stack runs`); ARCHITECTURE.md:640 (`BDMA_ADAPTIVE (per-launch BDMA variant staging, default off`) — vs code evidence: bin/POPSLDR/system.lua:6236 (`PLDR.BDMA_ADAPTIVE = true` — default ON since 2026-07-28); bin/POPSLDR/system.lua:8004-8011 (`if device_page == "USB" then … return "USBEXFAT"` — under Adaptive, USB always stages the exFAT pair, which also reads FAT32); docs/LAUNCH_ARGUMENTS.md:15 and README.md:161 state the current rule correctly
- Problem: Under Adaptive (now the default), a FAT32 USB launch stages USBEXFAT — it does not remove the drivers or fall back to POPStarter's built-in stack, and the saved BDMA Mode no longer decides the USB variant. TESTING's checklist turns the correct behaviour into a tester-visible "bug", and ROLLING_NOTES tells users nothing changes unless they opt in when the default already changed underneath them.
- Fix: Rewrite the three passages to the EXP70 rule (Adaptive default On; USB → USBEXFAT unconditionally under Adaptive; FAT32/no-BDMA is manual-only with Adaptive Off and BDMA Mode = FAT32).
- Benefit: Tester verdicts on the current rolling build stop being scored against a removed contract.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-074 — TESTING.md SMB setup instructs testers to set two Settings rows that no longer exist (Games path, Link mode)
- Category: 8
- Locations: TESTING.md:131 (`… Port (default 1111 …), Games path (folder holding POPS), Link mode`); TESTING.md:135 (`below: IP assignment (DHCP/Static), PS2 IP / Netmask / Gateway / DNS, Link mode, Server IP, Port (default 1111), Share, User, Password, Games path (folder holding POPS)`) — vs code evidence: bin/POPSLDR/system.lua:5776,5785 (`LINKMODE … hidden = true`; `PATH … hidden = true`) and the block comment at bin/POPSLDR/system.lua:5766-5768 (`DNS / LINKMODE / PATH / ADDR_TYPE / NB_ADDR are hidden = true: POPSTARTER needs none of them, so neither should the user have to supply them… they are not user-facing configuration any more`)
- Problem: The tester checklist walks testers through an SMB section layout from before the field-hiding change. Two of the rows it tells them to set and verify are not rendered in the UI at all, so a tester following the checklist literally cannot complete it and may report missing rows as a regression.
- Fix: Remove Games path and Link mode from both TESTING.md passages (the Port-default half of these lines is covered by RE-POPS-059).
- Benefit: The SMB test script is executable as written.
- Effort: S · Risk: Low · Confidence: High (READ)

---

### RE-POPS-075 — Two workflows are single-use artifacts: the official-release workflow is hardcoded to 1.4.4, and the retract workflow can only ever fire on its own edit
- Category: 8
- Locations: .github/workflows/official-release.yml:1; .github/workflows/official-release.yml:47-49; .github/workflows/official-release.yml:96-105; .github/workflows/retract-mislabeled-ember-beta.yml:5-9
- Problem: `official-release.yml` hardcodes the version in its name (line 1), concurrency group (line 17), version greps (`POPSLDR_VER = "v1.4.4"`, `Version=1.4.4`, `RELEASE_1.4.4.md` at lines 47-49), asset names and manifest text (lines 96-105) — the next release requires rewriting the workflow itself, and a missed spot publishes a mismatched release or fails closed late. `retract-mislabeled-ember-beta.yml` triggers only on a push to master that changes its own file (lines 5-9); it already performed its one deletion (its step exits 0 when the release is absent), so it is now inert automation that still runs a contents:write job if anyone touches the file.
- Fix: Parameterise official-release.yml from the tag/version it is releasing (derive the version from `etc/boot.lua` as the rolling workflow already does) so a release is data, not a workflow edit; delete retract-mislabeled-ember-beta.yml — its work is done and git history preserves it.
- Benefit: One less per-release workflow rewrite (a classic place to ship a wrong-version release); one less write-permissioned workflow sitting in the repo.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-076 — The IRX load-and-check helper is duplicated verbatim in main.cpp and luasystem.cpp
- Category: 2
- Locations: src/main.cpp:459-478, src/luasystem.cpp:362-380
- Problem: `LoadIrxChecked` (main.cpp) and `LoadIrxCheckedBuffer` (luasystem.cpp) are the same function — same `SifExecModuleBuffer` call, same out-parameter handling, same `id < 0 || ret < 0` failure rule — differing only in the DPRINTF lines main.cpp adds. Every IRX-load policy change (return-code interpretation, logging, retry policy if one is ever justified) must currently be made twice, in the two files that between them load every module in the system.
- Fix: Keep one implementation (luasystem's, declared for main.cpp's use the way `EnsureUsbMass`/`EnsureDev9` already cross the same boundary) and delete the other.
- Benefit: One definition of "did this IRX load" for the whole EE core.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-077 — PNG and BMP decoders repeat the same row-buffer / CLUT / VRAM-upload blocks three times each
- Category: 2
- Locations: src/graphics.cpp:82-360 (decode_png_stream: CT32 branch from line 159, T4 branch from line 195, T8 branch within the same palette arm; row-pointer calloc/free blocks at lines 172, 217, 267), src/graphics.cpp:428-840 (loadbmp: per-depth CLUT, pixel-conversion and upload blocks)
- Problem: Inside `decode_png_stream`, the allocate-row-pointers → `png_read_image` → free-row-pointers sequence and the budget-check → memalign → CLUT-build sequence are copied per colour branch with only the PSM and CLUT size changing; inside `loadbmp` the same pattern repeats per bit depth, including three separate copies of the VRAM-alloc/upload/free tail that `decode_png_stream` also has. This is the file where the audit-sensitive fixes live (budget checks, longjmp cleanup, CLUT clamps are all documented inline as prior bug fixes) — triplication is how one branch ends up with a fix the others lack.
- Fix: Factor only the identical sequences (row-pointer lifecycle; texture VRAM upload tail) into file-local helpers used by all branches; leave the genuinely format-specific pixel conversion in place. No new abstraction leaves this file.
- Benefit: One place for the allocation/cleanup contract in the cover-art path; the next decoder fix applies to every format at once.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-078 — ResolveAssetPath and ResolveAssetPathTyped duplicate the same candidate-walk
- Category: 2
- Locations: src/system.cpp:80-168
- Problem: `ResolveAssetPath` hand-rolls the absolute-path shortcut and the `app_dir` / `app_dir + "POPSLDR/"` candidate walk; `ResolveAssetPathTyped` then re-implements the same shortcut and walk pattern twice more (IMG and IRX arms) around a small `ResolveAssetCandidate` helper that the generic function does not use, before falling back to `ResolveAssetPath` for the generic kind anyway. Three copies of "try candidate, stat it, copy it out" in 90 lines.
- Fix: Rewrite `ResolveAssetPath` as the typed function with `ASSET_GENERIC` (the fallback already exists) and delete the duplicate body, keeping both public names/signatures so the two Lua bindings are untouched.
- Benefit: One candidate-order definition for asset resolution; a future search-path change cannot land in only two of the three copies.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-079 — The PLDRGC1 game-list cache format is implemented twice (parser ×2, builder ×2)
- Category: 2
- Locations: bin/POPSLDR/system.lua:9880-9897, bin/POPSLDR/system.lua:9899-9936, bin/POPSLDR/system.lua:9944-9990, bin/POPSLDR/system.lua:9991-10030
- Problem: `PLDR.LoadGameListCache` (per-device cache) and `PLDR.HDD.ReadCache` (HDD cache) contain the same ~25-line parse loop verbatim in structure: `PLDRGC1` magic check on the first line, `S ` signature check against `PLDR.GameListCacheSignature()`, `G `/`H ` record accumulation, `\r$` stripping, and the same `sig_ok`/`#games == 0` rejection — differing only in whether the result is returned or assigned to `PLDR.HDDCACHE`. The writers repeat the same header/signature/`G`/`H` line construction (`PLDR.SaveGameListCache` 9880-9897 vs `PLDR.HDD.CreateCache` 9944-9990). A format change (new record type, stricter magic) must currently be made in four places; the two parsers have already had parallel "Codex F5" size-cap fixes applied separately (9906, 10001), showing the drift cost is real.
- Fix: Extract the one parse loop into a single local `ParseGameListCache(data)` returning games/hidden or nil, and one line-builder local; have all four public functions call them and keep only their storage-specific parts (path, write mechanism, assignment).
- Benefit: One implementation of a file format that is read back across boots and versions; format fixes land once instead of being ported between twins.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-080 — Dead HDD readable-path resolver that is a near-verbatim subset of the live one
- Category: 1
- Locations: bin/POPSLDR/system.lua:944-972 (dead), bin/POPSLDR/system.lua:887-923 (live twin)
- Problem: Local `ResolveHddGamePartitionReadablePath(partition, relpath)` has zero callers anywhere in Lua or C (full-text occurrence count = 1, its own definition). Its body duplicates `ResolveHddPartitionReadablePath` almost line for line — same `ParseHddPartitionMount` guard, same recorded-prefix probe (`GetRecordedHddMountPrefix` + `BuildMountedReadablePath` + `ProbePathExists`), same mount-and-probe tail — differing only in which mount helper it calls. A duplicate-block scan flags the two bodies as the largest intra-file duplication in system.lua. Keeping a second, unexercised copy of mount logic invites the next fix to land in one copy only.
- Fix: Delete `ResolveHddGamePartitionReadablePath` (29 lines). If a game-partition-specific readable path is ever needed, call the live resolver, which already takes slot/hint parameters.
- Benefit: −29 lines of mount logic to maintain; one resolver to fix and to reason about for the D-10-class HDD paths.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-081 — Three trailing-slash helpers where one mechanism suffices
- Category: 3
- Locations: bin/POPSLDR/system.lua:23-32, bin/POPSLDR/system.lua:167-171, bin/POPSLDR/system.lua:221-240
- Problem: system.lua maintains `EnsureTrailingSlash` (23-31, additionally exported as `_G.EnsureTrailingSlash` at 32), `EnsureTrailingSlashNormRaw` (167-171, normalize-then-slash), and `NormalizeDirPath` (221-231), which re-implements the slash guarantee inline (`gsub "/+$" → "/"`, then append if missing) instead of using either helper; `JoinPath` (232-240) builds on the third. The plain and "NormRaw" variants differ only in whether backslash/slash collapsing runs first — a distinction every caller must currently know by heart, across ~15 call sites scattered through the file (1548, 1784, 10292, 10533-10534, 11128, 11463, …). This is the kind of near-duplicate path helper family that produced the file's long history of subtly different path spellings.
- Fix: Consolidate on one helper: keep `EnsureTrailingSlashNormRaw` (the normalizing form is safe for every current plain-form call site, whose inputs are already device paths), rename/keep it as the single trailing-slash function, reimplement `NormalizeDirPath`'s tail in terms of it, and drop the `_G.EnsureTrailingSlash` export after moving its few call sites (1548, 1784, 10292, 10533-10534, 11128, 11463) to the survivor.
- Benefit: One slash rule for the whole chunk; path-spelling behaviour can be fixed in exactly one place instead of three.
- Effort: M · Risk: Med · Confidence: High (READ)

---

### RE-POPS-082 — DPRINTF is an unconditional no-op, so all EE diagnostic logging is dead in every build, including DEBUG builds
- Category: 3
- Locations: src/include/dprintf.h:4, src/main.cpp:459-478 (representative consumer whose comments describe DPRINTF as the DEBUG-gated channel), src/fntsys.cpp, src/graphics.cpp, src/luasystem.cpp, src/luaHDD.cpp, src/pad.cpp, src/sound.cpp, src/system.cpp, src/elf_loader/src/elf.c (163 lines matching `DPRINTF` across these EE sources by scripted grep)
- Problem: `#define DPRINTF(x...)` in `dprintf.h` is empty with no `#ifdef DEBUG` or any other condition — unlike `dbgprintf` in `luaplayer.h`, which is DEBUG-gated. Every DPRINTF call site in the EE core therefore compiles to nothing in release *and* debug builds, while comments throughout the tree (and the boot-profile design in main.cpp) describe DPRINTF as a live diagnostic channel that was deliberately bypassed in specific places because it "compiles to nothing in a release build". The mechanism misleads: effort keeps being spent routing around a logging system that is off everywhere, and the call sites themselves (string formatting arguments included) are pure dead weight in the source.
- Fix: Pick one truth and encode it: either gate the macro on `DEBUG` like `dbgprintf` so debug builds actually get the channel the comments promise, or delete the macro and its call sites. Do not add a new logging framework — the finding is that the existing switch is wired to nothing.
- Benefit: Either ~163 dead call sites go, or the diagnostic channel the codebase already writes to starts existing; the current state has the costs of both and the benefits of neither.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-083 — Cache eviction is a fixed-point weight/aging scheme where a trivial policy suffices
- Category: 3
- Locations: tarball:libbdm/src/bd_cache.c:10,79-122
- Problem: Eviction for a 32-entry, read-through, write-invalidate sector cache is implemented as per-block signed "weights" in 24.8 fixed point, bumped by `count × 256` on hit, decayed on every miss by `(8 × 256 / 32) + weight/32`, clamped at 0 only on the hit path, and scanned for a minimum whose initial sentinel is `0x7fffffff`. Nothing in the workload (sequential FAT/directory reads by one FS driver) needs hit-frequency weighting, the arithmetic's failure modes are non-obvious (weights drift negative between hits, making untouched blocks progressively *less* evictable the more misses occur elsewhere), and the whole scheme exists to choose a victim among 32 slots — a round-robin or simple LRU counter does the same job in a handful of obviously-correct lines.
- Fix: Replace weight/aging with a single rotating victim index (or a last-used counter per block) and delete `BLOCK_WEIGHT_FACTOR` and the aging loop.
- Justification: The replacement is strictly less code than what it removes; no addition is proposed.
- Benefit: ~40 lines of subtle arithmetic leave the I/O path; eviction behaviour becomes predictable and auditable.
- Effort: S · Risk: Med · Confidence: Med (READ)

### RE-POPS-084 — Dead C functions and dangling declarations left behind by removed subsystems
- Category: 1
- Locations: src/fntsys.cpp:390-412 (`fntLoadDefault`), src/fntsys.cpp:851-905 (`fntFitString`), src/graphics.cpp:890-900 (`gsKit_clear_screens`), src/graphics.cpp:1020-1045 (`drawImageCentered`, line range from full read), src/graphics.cpp:1093-1098 (`drawRectCentered`, line range from full read), src/include/system.h:19-20, src/include/luaplayer.h:51, src/include/luaplayer.h:61, src/main.cpp:532-534
- Problem: Scripted reference census over `src/` + shipped Lua: `fntLoadDefault` and `fntFitString` are defined and declared but called from nowhere (the Lua default-font path calls `fntLoadbuff` directly); `gsKit_clear_screens`, `drawImageCentered` and `drawRectCentered` have no caller and the two `*Centered` helpers are not even declared in `graphics.h`. The headers still promise things that do not exist: `system.h` declares `load_elf()` and the `load_elf_NoIOPReset` macro even though `system.cpp`'s own comment (src/system.cpp:168-181) records that `load_elf` was removed — any future caller compiles and fails only at link; `luaplayer.h` declares `stackDump()` and `luaC_collectgarbage()`, neither defined anywhere. `main.cpp`'s `#ifdef POWERPC_UART` block loads a `ppctty_irx` symbol that no IOP module list provides, so defining the flag breaks the link.
- Fix: Delete the five dead functions, the two dangling header declarations, the dead `load_elf` declaration + macro, and the `POWERPC_UART` block.
- Benefit: Headers become a truthful map of the link; removes ~150 lines including a font-slot copy/delete routine (`fntLoadDefault`) whose semaphore-free slot swap is a hazard if ever revived blind.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-085 — GetFreeSize / AllocateLargestFreeBlock: a dead chain whose algorithm repeatedly mallocs the largest block in the heap
- Category: 1
- Locations: src/system.cpp:183-254, src/luasystem.cpp:887-895, src/luasystem.cpp:2532, src/include/system.h:21, src/include/luaplayer.h:47
- Problem: `GetFreeSize()`'s only caller is the `System.getFreeMemory` binding, which the RE-POPS-048 census shows has no Lua caller — the chain is unreachable. The algorithm itself is the other reason to delete rather than keep it: `AllocateLargestFreeBlock` binary-searches by actually `malloc`-ing ever-larger blocks (starting from a half-address-space probe) and `GetFreeSize` repeats that in a loop, linking every largest block into a list before freeing them — maximum heap churn and fragmentation pressure on a 32 MB EE, in exchange for a number nothing displays.
- Fix: Delete `GetFreeSize`, `AllocateLargestFreeBlock`, the binding, and both header declarations.
- Benefit: Removes ~70 lines and the most heap-hostile utility in the EE core; if a free-memory readout is ever wanted, it should come back as a mallinfo-style query, not this probe.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-086 — The async ATA bring-up worker is dead: KickAtaAsyncBoot / WaitAtaAsyncBootBounded have no callers anywhere
- Category: 1
- Locations: src/luasystem.cpp:1864-1965 (state, stack, semaphores, `ata_async_thread`, `KickAtaAsyncBoot`, `WaitAtaAsyncBootBounded`), src/luasystem.cpp:1955-1965, src/main.cpp (boot sequence, full read: no call to either function), bin/POPSLDR/system.lua:6330
- Problem: Scripted caller census over `src/` and the shipped Lua: `KickAtaAsyncBoot` and `WaitAtaAsyncBootBounded` are defined and never called; no `initATAAsync` binding exists in any registration table, yet `system.lua` still probes for one (`type(System.initATAAsync) == "function"` — always false) and the comments in this block describe a boot-time kick and a bounded join in `main.cpp` that do not happen (main.cpp's own comment concedes the worker "stays dormant (no callers)"). The live ATA path is the synchronous `initATAModules`. The dead block costs an 8,192-byte static stack, two semaphores, a worker thread function and ~100 lines of misleading concurrency commentary around the most failure-sensitive launch path in the app.
- Fix: Delete the worker, its stack, its module semaphore and both entry points, keeping `lua_ata_init_status` reading a state that the synchronous path sets (or delete the status binding with it if nothing then writes the state). Remove the stale `initATAAsync` probe from the Lua boot path at the same time (Lua file, outside this section's edit scope — flagged for the parent).
- Benefit: One ATA bring-up mechanism instead of two, and no future maintainer can "fix" a hang by wiring up a worker whose race history (documented in the same comments) is exactly why it was abandoned.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-087 — embedded_get's bare-name fallback branch can never execute
- Category: 1
- Locations: src/embed_assets.cpp:282-285
- Problem: The fallback `if (asset == NULL && lookup_key != input && strchr(input, '/') == NULL) asset = embedded_find(input);` is unsatisfiable. `lookup_key` is reassigned away from `input` only in the three branches that all require a `/` in `input` (`POPSLDR/`, `IMG/`, or any string containing `/`); when `input` contains no `/`, `lookup_key` still equals `input`, so the second conjunct is false. In every reachable state at least one conjunct fails, and the second `embedded_find` is dead code that misleads readers into thinking a bare-name rescue exists.
- Fix: Delete the dead fallback (the first lookup already covers the bare-name case, because a slash-free input is looked up unchanged).
- Benefit: Removes a false safety net from the one function every embedded-asset consumer funnels through; the real lookup contract becomes readable at a glance.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-088 — images.lua's IMG_FALLBACKS mechanism can never fire
- Category: 1
- Locations: bin/POPSLDR/images.lua:46, bin/POPSLDR/images.lua:63-72
- Problem: `IMG_FALLBACKS` is a file-local table that is only ever read, in the `__index` fallback branch of the lazy image loader; nothing in any Lua or C file ever writes a key into it, so the branch is dead machinery in the loader's hot path. (The same section finding's second limb — the never-requested `default.png` registration — is consolidated as RE-POPS-089.)
- Fix: Delete the `IMG_FALLBACKS` table and its branch in `__index`. If a fallback is ever actually needed, the AGENTS.md asset rule already requires coordinating Makefile + embed_assets.cpp + images.lua — re-add it then, populated.
- Benefit: The image loader's `__index` becomes a straight source→load→cache path.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-089 — `default.png` is registered in Lua and embedded only conditionally, but the file is not in the repo and the registration is never requested
- Category: 8
- Locations: Makefile:72-77, Makefile:88-95 (conditional-embed wiring; range INFERRED from the full Makefile read), src/embed_assets.cpp:56-58, src/embed_assets.cpp:140, src/embed_assets.cpp:201, bin/POPSLDR/images.lua:34-36, bin/POPSLDR/IMG/ (directory listing: no default.png among its 67 files)
- Problem: `bin/POPSLDR/IMG/default.png` does not exist in this checkout, so `HAVE_ASSET_DEFAULT_PNG` is undefined and no `default.png` blob is embedded — yet `images.lua` unconditionally registers `{"default", "default.png"}` in `IMG_REGISTRATIONS`, and nothing anywhere requests it either (`IMG.default` / `IMG["default"]` occurs nowhere in Lua or C; the game list uses `IMG.cover_default`). The registration can only ever resolve through `System.getEmbeddedAsset` to failure and be memoised in `IMG_FAILED`. The optional-embed machinery (Makefile conditional, `#ifdef` externs, `#ifdef` table rows) exists solely to support a file that is not in the repo.
- Fix: Delete the `default` row from `IMG_REGISTRATIONS`; drop the conditional embed wiring with it, or keep the wiring only if the file is actually committed. If a legacy cover override is ever reintroduced, add the registration and the file together.
- Benefit: Removes a permanently-failing lookup from the cover path, a phantom asset from the three-place asset coordination the repo documents as error-prone, and a three-place conditional that no shipped build exercises.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-090 — Four defined-but-never-called functions, including one polluting the global namespace
- Category: 1
- Locations: bin/POPSLDR/system.lua:2153-2155, bin/POPSLDR/system.lua:4972-4976, bin/POPSLDR/system.lua:10364-10378, etc/boot.lua:179
- Problem: Full-text search across all Lua and `src/*.cpp`/`src/*.c` finds exactly one occurrence (the definition) for each of: `PLDR.GetBootKind()` (a one-line wrapper over `ResolveBootContext().kind`; the sibling `PLDR.GetBootContext` at 2149 is used, this one is not), `CYCLE_CLAMP(a, MIN, MAX)` (a **global**, unlike its used sibling `CLAMP` at 4966 which ui.lua genuinely calls), local `GetBootOccupiedPfsSlot()` (its helper `ExtractLaunchPfsSlot` is used in five other places; this wrapper is not), and `STOP()` in etc/boot.lua (a red-screen infinite loop defined at boot and never invoked from Lua or C).
- Fix: Delete all four definitions. Nothing else changes; no caller exists to update.
- Benefit: −~25 lines; one less boot-time global (`CYCLE_CLAMP`) that any future chunk can accidentally shadow or call expecting wrap-around semantics nobody tested.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-091 — Dead exported surface: unused PLDR/UI members, a load-time probe whose result nobody reads, and a self-described dead flag
- Category: 1
- Locations: bin/POPSLDR/system.lua:2202-2204, bin/POPSLDR/system.lua:2224, bin/POPSLDR/system.lua:4950-4957, bin/POPSLDR/system.lua:5615-5617, bin/POPSLDR/system.lua:5695, bin/POPSLDR/ui.lua:6851
- Problem: Each of these is written and never read (occurrence count = definition only, checked across Lua + C): (a) `PLDR.EnsureTrailingSlashNorm` (5615-5617), a public wrapper over the local `EnsureTrailingSlashNormRaw` that no file calls; (b) `PLDR.HDD_FS_VALUES = {"PFS","EXFAT","BOTH","DISABLED"}` (5695) — ui.lua ignores it and hard-codes its own identical list as `HDD_FS_SEQ` (ui.lua:5161); (c) `PLDR.MX4SIO.PREFIX_HINT` — `DetectMX4SIOPrefixHint()` (4950-4956) performs a `doesFileExist` probe for a `.boot_mx4sio` marker at every boot and stores the result at 4957 (default at 2224), and no code anywhere reads the field, so the probe is pure boot cost; (d) the export `UI.ResolveSelectedVcdPath = ResolveSelectedVcdPath` (ui.lua:6851) — the local is used internally (ui.lua:3783, 3950, 4289) but the `UI.` member is never referenced by system.lua or C; (e) `PLDR.HDD.USECACHE = false` (2204), whose own comment at 2202 states "USECACHE is a dead legacy flag now".
- Fix: Delete the five items (for (c), delete the probe function, its assignment, and the defaults entry together). Keep the locals/flags that are actually used (`EnsureTrailingSlashNormRaw`, `PLDR.NormalizeHddFs`, the local `ResolveSelectedVcdPath`).
- Benefit: Removes a per-boot file probe with no consumer, two divergent copies of the HDD-FS value list, and API surface that misleads future callers into thinking these are supported entry points.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-092 — Twenty stale translation entries whose source strings no longer exist in the code
- Category: 1
- Locations: bin/POPSLDR/system.lua:2629, bin/POPSLDR/system.lua:2772, bin/POPSLDR/system.lua:2936, bin/POPSLDR/system.lua:3079, bin/POPSLDR/system.lua:3244, bin/POPSLDR/system.lua:3387, bin/POPSLDR/system.lua:3552, bin/POPSLDR/system.lua:3695, bin/POPSLDR/system.lua:3859, bin/POPSLDR/system.lua:4002, bin/POPSLDR/system.lua:4155, bin/POPSLDR/system.lua:4198, bin/POPSLDR/system.lua:4214, bin/POPSLDR/system.lua:4306, bin/POPSLDR/system.lua:4315, bin/POPSLDR/system.lua:4331-4332, bin/POPSLDR/system.lua:4358, bin/POPSLDR/system.lua:4377-4378
- Problem: `PLDR.L(s)` can only ever translate a string that exists somewhere in the Lua as a source string. A key-set comparison (every i18n key vs. every string occurrence outside the i18n block, both Lua files + boot.lua) shows these keys occur nowhere else: (a) the superseded SMB warning `"SMB modules are not installed\nGames will list but won't boot -- install them\nvia Settings > SMB modules first"` in six languages (FR 2772, DE 3079, PT 3387, ES 3695, IT 4002, HU 4358) — the live notification at ui.lua:3920 uses different wording, which has its own, separate entries; Slovak already dropped the stale key, proving the cleanup was done for one language only; (b) `"Cover/details folder"` in six languages (FR 2629, DE 2936, PT 3244, ES 3552, IT 3859, HU 4198) — the label of the ART_LOCATION row removed in EXP35 (see RE-POPS-070), surviving only inside a code comment; (c) eight Hungarian-only orphans whose English sources appear nowhere: `"ART (at root)"` (4155), `"Don't Save"` (4214), `"POPS (beside game)"` (4306), `"Profile defaults restored"` (4315), `"Save Settings"` (4331), `"Save your changes before leaving?"` (4332), `"X = Keep      O = Revert"` (4377), `"X = Select      O = Cancel"` (4378).
- Fix: Delete these 20 entries. No code changes; untranslatable-by-construction entries cannot be reached by `PLDR.L`.
- Benefit: −20 entries of translator-maintained text that can never render; the per-language key sets stop implying coverage that does not exist (notably SK 409 keys vs ~304-317 for the other six languages is partly this drift).
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-093 — StripVcdExtension is defined independently in both Lua files
- Category: 2
- Locations: bin/POPSLDR/system.lua:10181-10187, bin/POPSLDR/ui.lua:122-125
- Problem: The same operation — strip a trailing `.VCD` in any case with `string.gsub(s, "%.[Vv][Cc][Dd]$", "")` — exists as a local in system.lua (10181, nil/empty-guarded, used by `DeriveGameNameFromSelection`) and as a local in ui.lua (122, `tostring`-coercing, used for list display). ui.lua already depends on system.lua globals loaded before it (`JoinPath`, `CLAMP`), so the duplication is not a load-order necessity. Two copies of a filename-grammar rule is exactly how display names and launch names drift apart (the ui.lua comment block at 99-121 documents a past truncation bug in this very operation).
- Fix: Keep one implementation (the system.lua one, exposed the way `JoinPath` already is) and delete the ui.lua local, calling the shared one at its single ui.lua call site (3355).
- Benefit: One definition of the .VCD-strip grammar for both the launch path and the display path.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-094 — The scene-background image cascade is written out twice inside ui.lua
- Category: 2
- Locations: bin/POPSLDR/ui.lua:1793-1813, bin/POPSLDR/ui.lua:2052-2068
- Problem: `DrawTargetBackground(scene)` in the Welcome/splash scene implements the full cascade — main menu: `IMG.BGM` else `IMG.BKG`; credits/profile: `IMG.BG` else `IMG.BKG`; otherwise `IMG.BKG` — and `UI.BottomDraw.Play` then re-implements the identical cascade inline against `UI.CURSCENE` (2052-2068), statement for statement. Any change to background policy (a new scene class, a new fallback image) must be made in both, and the splash transition and the steady-state draw can silently disagree.
- Fix: Delete the inline copy in BottomDraw and call the existing cascade logic (hoisted to a file-level local or a `UI` member, since the current one is a closure inside the Welcome scene's `Play`).
- Benefit: One background policy for both the transition path and the per-frame path; −~16 duplicated lines.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-095 — Three clamp implementations, one of them a same-name shadow inside a single function
- Category: 2
- Locations: bin/POPSLDR/system.lua:4966-4970, bin/POPSLDR/ui.lua:14-18, bin/POPSLDR/ui.lua:19-23, bin/POPSLDR/ui.lua:1946-1950
- Problem: Clamping is implemented three times: the global `CLAMP` in system.lua (4966, genuinely used by ui.lua, e.g. 2858-2865, 3311-3312, 3679-3682), a file-local `Clamp` in ui.lua (19-23, used at 1382, 1436), and a file-local `Clamp01` in ui.lua (14-18) — which is then **shadowed by a second, identical `Clamp01` defined inside the splash `Play` function** (1946-1950), so that function alone uses its own private copy while the rest of the file uses the file-local one. Nothing distinguishes them semantically.
- Fix: Delete the nested `Clamp01` at 1946-1950 (the file-local at 14 is in scope there) and, opportunistically, route ui.lua's two `Clamp` call sites through the already-global `CLAMP` and delete the ui.lua local. Keep `Clamp01` (0..1 specialisation) as the only second form.
- Benefit: One less shadow that invites an edit to the wrong copy; the clamp vocabulary of the codebase drops from three spellings to two.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-096 — Dead helpers and dead macros: `GetExportEntry` and the `hci_event_flag_*` family
- Category: 1
- Locations: modules/pademu/sys_utils.c:56-68, modules/pademu/pademu.h:59, modules/pademu/ds34bt.h:69-71, modules/ds34bt/iop/ds34bt.h:84-86
- Problem: `GetExportEntry` is defined and prototyped but a scripted search shows no caller anywhere in the repo outside its own definition (only `GetExportTableSize` and `HookExportEntry` are used, pademu.c:178). The `hci_event_flag_clear/set/check` macros in both BT headers expand to operations on a variable `hci_event_flag` that is declared nowhere — any use would not compile; they and the `HCI_FLAG_*` enum values exist only as unusable decoration copied between the two headers.
- Fix: Delete `GetExportEntry` (function + prototype) and the three `hci_event_flag_*` macros from both BT headers.
- Benefit: Small but pure removal; the headers stop advertising an API that cannot be called.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-097 — Dead duplicate files inside __usbd_bd_assault that its Makefile never compiles
- Category: 1
- Locations: tarball:__usbd_bd_assault/src/usbd/usbd_usbd_driver.c:1-284; tarball:__usbd_bd_assault/src/usbd/irx_imports.h:1-31
- Problem: Scripted diff: `usbd_usbd_driver.c` is byte-identical to `usbd_driver.c` (both byte-identical to component `usbd/src/driver.c`, 6,965 bytes), and the nested `src/usbd/irx_imports.h` is byte-identical to component `usbd/src/irx_imports.h` (md5 `2f4308b0…`). The merged Makefile builds `usbd_driver.o` from `usbd_driver.c` via its `src/usbd/%.c` pattern and takes imports from `src/`; neither dead file is referenced by any object list, pattern, or include in the merged tree (its own `src/irx_imports.h`, a different merged file, is the live one). They are pure drift bait: a future edit to `usbd_usbd_driver.c` would compile into nothing while looking like the USBD driver.
- Fix: Delete both files.
- Benefit: Removes 7,745 bytes of misleading dead source from the tree that actually ships.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-098 — A complete second, never-compiled ASYNC implementation of usb_queue_cmd is carried in-line
- Category: 1
- Locations: tarball:usbmass_bd/src/usb_mass.c:17,380-410,476-540; tarball:__usbd_bd_assault/src/usbmass_bd/usbmass_bd_usb_mass.c:17,380-410,476-540
- Problem: `// #define ASYNC` (line 17) is commented out and nothing in any Makefile defines `ASYNC`, so the `#else` half of `usb_queue_cmd` — a full asynchronous CBW/data/CSW pipeline — plus its exclusive support code (`struct usbmass_cmd`, `scsi_cmd_callback`) is dead in every build this tree can produce. Conversely the live synchronous helpers (`usb_bulk_reset`, `usb_bulk_status`, `usb_bulk_manage_status`, `usb_bulk_command`, `usb_bulk_transfer`) are wrapped in `#ifndef ASYNC`, so the file permanently carries two implementations of the driver's core operation, only one of which is ever tested by being compiled.
- Fix: Delete the `ASYNC` branch, `scsi_cmd_callback`, and `struct usbmass_cmd`; unwrap the `#ifndef ASYNC` guards.
- Benefit: ~90 lines of uncompilable, untestable code stop shadowing the real transfer path in every future read or edit.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-099 — libbdm ships bd_defrag, which nothing in the package calls
- Category: 1
- Locations: tarball:libbdm/src/bd_defrag.c:1-102; tarball:libbdm/include/bd_defrag.h:1-31; tarball:libbdm/Makefile:14
- Problem: Scripted grep over all 119 tarball files: `bd_defrag_read`/`bd_defrag_write` appear only in their own definition, header, and the libbdm Makefile object list. No component, no merged driver, and no other library in the tarball calls them — the FatFs driver *produces* fragment lists via ioctl (fs_driver.c `get_frag_list`) but the consumer of such lists lives outside this package (in the host app's own drivers). Within BDMAssault as shipped, `bd_defrag.o` is compiled into `libbdm.a` on every build and can only ever be dead weight (a static archive member that no link here pulls).
- Fix: Drop `bd_defrag.o` from the libbdm build in this package (keep the source out of the tarball, or keep the file and remove it from `IOP_OBJS` with a note that external consumers build it themselves).
- Benefit: One less unmaintained 102-line module compiled on every CI run of a package that never uses it.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-100 — ffsystem.c carries dead sample code for four other operating systems
- Category: 1
- Locations: tarball:bdmfs_fatfs/src/ffsystem.c:15-201; tarball:__bdm_assault/src/bdmfs/bdmfs_ffsystem.c:15-201
- Problem: Of this 201-line file, the live IOP code is roughly 60 lines. The rest is ChaN's sample scaffolding: `ff_memalloc`/`ff_memfree` compiled only under `FF_USE_LFN == 3` while this tree sets `FF_USE_LFN 2` (ffconf.h:107), and, inside every sync-object function, an `#if 0` block quoting Win32, µITRON, µC/OS-II, FreeRTOS and CMSIS-RTOS variants. It is vendored-sample clutter that every reader must skip to find the four small semaphore wrappers that actually run.
- Fix: Trim the file to the IOP implementations (keeping the FatFs header comment and licence line).
- Benefit: The OS-glue file becomes readable at a glance; no behavioural change.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-101 — Tarball CI builds only the merged drivers and libbdm; the five component modules are never compiled
- Category: 7
- Locations: tarball:.github/workflows/CI.yml:33-46
- Problem: The only CI in the tarball runs `make -C libbdm`, `make -C __bdm_assault/`, `make -C __usbd_bd_assault/` — `bdm/`, `bdmfs_fatfs/`, `usbd/`, and `usbmass_bd/` have Makefiles but no CI coverage, so a component that stops compiling is invisible, and (with RE-POPS-045) nothing detects component↔merged drift either. The workflow also pins nothing: `actions/checkout@v3`, `actions/upload-artifact@v3`, and `marvinpinto/action-automatic-releases@latest`, and it publishes a "latest" prerelease from every push to main.
- Fix: Add the four component builds to the CI matrix (they are cheap IOP cross-compiles in the same container) and pin actions to full versions/SHAs.
- Benefit: The components stop being write-only source, and drift between the two copies of everything becomes a CI failure instead of a surprise.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-102 — Merged USBD Makefile adds an include directory that does not exist
- Category: 7
- Locations: tarball:__usbd_bd_assault/Makefile:9
- Problem: `IOP_INCS += -Isrc/usbd/include` — verified by directory listing: `__usbd_bd_assault/src/usbd/` contains its headers directly and has **no** `include/` subdirectory (unlike `src/usbmass_bd/include/`, which exists). The flag is inert today only because the headers are found via the source directory itself; it is leftover from an assumed layout and will silently mask a future header move (files keep resolving from the old place, or fail confusingly elsewhere).
- Fix: Delete the `-Isrc/usbd/include` flag (or create the directory and actually move the headers — deletion is the LESS option).
- Benefit: The build description matches the tree; one less phantom path for the next editor to trust.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-103 — The build pipeline is triplicated across three workflows; the same gates and the same ~170-line publish script are maintained in three places
- Category: 2
- Locations: .github/workflows/compilation.yml:112-176; .github/workflows/rolling-release.yml:106-170; .github/workflows/experimental-release.yml:102-166; .github/workflows/rolling-release.yml:339-519; .github/workflows/experimental-release.yml:270-501
- Problem: The Lua-syntax gate (~55 lines, including its explanatory comment history), the in-container host-harness step, the embedded-build-identity step and the bundle step appear near-verbatim in compilation.yml, rolling-release.yml and experimental-release.yml; the GitHub-API publish logic (release upsert, asset replace, stale-zip cleanup) is a ~170-line inline Python program duplicated between rolling-release.yml and experimental-release.yml with only names/notes/tag changed. The comments show the cost: the luac-gate fix ("it used to silently skip…") had to be written identically into all three files, and RE-POPS-104 is what happens when one copy is not updated.
- Fix: Extract the shared gates into one reusable workflow (or composite action) called by all three, and the publish Python into one script under `tools/` parameterised by channel (tag, notes file, asset prefix) — the rolling and experimental copies already differ only in those parameters.
- Benefit: A gate fix lands once; the three channels cannot silently diverge in what they check before publishing.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-104 — The publishing channels run a weaker gate set than CI: docs_verify runs only in compilation.yml, and the experimental channel also skips the PNG decoder harness
- Category: 7
- Locations: .github/workflows/compilation.yml:49-55; .github/workflows/rolling-release.yml:28-57; .github/workflows/experimental-release.yml:31-53
- Problem: compilation.yml's lua-harness job runs `tools/png_decoder_harness.py`, the host/pad/disc/UDPFS-config harnesses, `tools/docs_verify.py` (line 52) and the translation tests. The rolling-release lua-harness job — the gate for the channel users actually download — omits `docs_verify.py`; the experimental-release lua-harness job omits both `docs_verify.py` and `png_decoder_harness.py`. A doc/source drift or a PNG-decoder regression therefore cannot fail the builds that publish, only the CI build that does not.
- Fix: Add the missing step(s) to the rolling and experimental harness jobs (one line each; both are stdlib/host tools that already run in the sibling job) — or, with RE-POPS-103 done, inherit the shared gate.
- Benefit: The publishing channels enforce the same claims CI enforces; `docs_verify`'s stated purpose (it "sat unwired and red for months" once already, per compilation.yml:49-51) is not defeated by wiring it to the non-publishing workflow only.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-105 — test_udpfs_integration.py is named an integration test but is mostly substring-presence assertions on source text
- Category: 7
- Locations: tools/test_udpfs_integration.py:35-79
- Problem: Judged against its name: the blob half is real (hash/size/ELF-header pins, PROVENANCE.json cross-check, and — when passed a kit zip — byte comparisons against the packaged files). But the "integration" half (lines 35-79) is ~45 `assert "literal string" in file_text` checks over ui.lua, system.lua, luasystem.cpp, embed_assets.cpp and the Makefile. Those pass if the string survives in a comment and fail on any rename/refactor that preserves behaviour, i.e. they test spelling, not integration. The genuinely behavioural UDPFS coverage already exists in `tools/test_udpfs_config_runtime.py`, which executes the real Lua — this file's name promises the same class of proof and does not deliver it.
- Fix: Rename the file to reflect what it pins (e.g. `test_udpfs_pins.py`) and move the handful of wiring literals that matter into the runtime harness as executable checks over time; do not add more substring asserts.
- Benefit: The next reader (and CI triage) can tell which gate proves behaviour and which proves bytes; refactors stop failing a "test" that never ran the code.
- Effort: M · Risk: Low · Confidence: High (READ)

---

### RE-POPS-106 — Byte-identical duplicates inside the research archive and the root docs
- Category: 2
- Locations: .research/assets/1165364186-Playstation-Button-L2.png:1; .research/assets/1258137434-pops05_zps81df52b9.jpg:1; OFFICIAL_NOTES.md:1; RELEASE_1.4.4.md:1
- Problem: Script-verified duplicate groups inside `.research/assets/`: six pairs where the same image is tracked under both a numeric-prefix name and a plain name (Playstation-Button-L2, -R2, -T ×2 files, -Select, `356screenshot1.gif`, `pops05_zps81df52b9.jpg`) — 57,552 redundant bytes. Separately, `OFFICIAL_NOTES.md` and `RELEASE_1.4.4.md` are byte-identical (1,841 B, same SHA-256), two root files that will drift apart at the next release edit.
- Fix: Delete one member of each duplicate pair (keep the name the site generator references) and delete `OFFICIAL_NOTES.md` or make it a one-line pointer to the release-notes file.
- Benefit: Small but free: −59 KB and one guaranteed future doc contradiction removed.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-107 — Release/version headers frozen at 1.1.0 / v1.1.1-dev in five docs
- Category: 7
- Locations: ARCHITECTURE.md:1 (`Release 1.1.0; rolling v1.1.1-dev / experimental v1.1.1-dev-EXP73`); COMPONENTS.md:1 (same); CONTRIBUTING.md:1 (`rolling dev = v1.1.1-dev; released line 1.1.0`); TESTING.md:3 (`its version row reads v1.1.1-dev. Public release is 1.1.0 (2026-07-21)`); DECISIONS.md:1 (`Released line: 1.0.1`); docs/PRESERVATION_CONTRACTS.md:3 (`Public release is 1.1.0 (2026-07-21); rolling is 1.1.1-dev`) — vs code evidence: etc/boot.lua:1 (`POPSLDR_VER = "v1.4.4"`); bin/POPSLDR/title.cfg:7 (`Version=1.4.4`); .github/workflows/official-release.yml:1,51-54 (1.4.4 release verification greps both stamps)
- Problem: Five entry-point docs announce a release line three minor versions behind the tree they sit in. TESTING.md is the worst case: it tells testers to identify their build by a version string (`v1.1.1-dev`) that no current build displays, so a tester on the real 1.4.4-stamped rolling build can conclude they have the wrong artifact.
- Fix: Update each header to the 1.4.4 line (or delete the version from headers that don't need it and point at STATE.md, which is current).
- Benefit: Build identification — the first thing a tester or contributor checks — matches the artifact CI actually produces.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-108 — "29 keys" settings lists enumerate only 23 keys (RETROGEM_GAMEID and the five EMBER_* keys missing)
- Category: 7
- Locations: STATE.md:99 (`Persisted settings — 29 keys (EncodeSettings…)` followed by a 23-key list ending at `SMB_MODULES`); COMPONENTS.md:218-226 (same 23-key list under a `29 keys` heading); ARCHITECTURE.md:635-650 (same list, ending at `SMB_MODULES`) — vs code evidence: bin/POPSLDR/system.lua EncodeSettings (the `RETROGEM_GAMEID=` line and the five `EMBER_DISPLAY=`/`EMBER_TIMING=`/`EMBER_DITHER=`/`EMBER_SHADING=`/`EMBER_CONTROLLER=` lines immediately after `SMB_MODULES=`); tools/docs_verify.py output at this pin (`EncodeSettings writes 29 keys: … SMB_MODULES, EMBER_DISPLAY, EMBER_TIMING, EMBER_DITHER, EMBER_SHADING, EMBER_CONTROLLER`, with `RETROGEM_GAMEID` in the same list)
- Problem: All three enumerations claim the count the code actually writes but list six fewer keys, omitting exactly the two newest families (Retro GEM and Ember). Anyone hand-editing or migrating a `.pldrs` sidecar from these lists will drop the Ember global options and the Retro GEM toggle on the next save round-trip they simulate.
- Fix: Append `RETROGEM_GAMEID` and the five `EMBER_*` keys to all three lists (STATE first, per the repo's own doc rule).
- Benefit: The persisted-format documentation becomes complete enough to migrate a settings file by hand.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-109 — "Cover art reads exactly ONE path per device" — UDPFS reads two
- Category: 7
- Locations: AGENTS.md High-Risk Surfaces (`BuildCoverCandidates — it returns exactly ONE candidate (EXP71…)`); STATE.md:64 (`Cover art: ONE fixed folder per device`); STATE.md:156 (`exactly ONE folder is read — the always-on beside-the-.vcd fallback was removed`); ARCHITECTURE.md Layer 4 cover paragraph (`BuildCoverCandidates returns a SINGLE candidate`); TESTING.md:201 (`exactly one path is read per device… art in the old POPS/ART or beside-the-.VCD spots no longer does`); ROADMAP.md Secondary Work §2 (`the seeker returns exactly ONE candidate`) — vs code evidence: bin/POPSLDR/ui.lua:241 (`BuildCoverCandidates`); bin/POPSLDR/ui.lua:284-289 (UDPFS branch: `return { artdir..name.."_COV.png", dir..name.."_COV.png" }` — the ART path plus beside-the-VCD in `udpfs:/POPS/`); README.md Settings/Cover art states the UDPFS exception correctly
- Problem: The EXP71 one-candidate contract is real for local devices, but the UDPFS branch deliberately kept a second, beside-the-VCD probe. Five docs state the contract without the exception, and TESTING.md goes further, instructing testers to treat beside-the-VCD art as not read — on UDPFS it is read, so a tester can file a false regression or "fix" working art placement. AGENTS.md's version is the riskiest: it instructs future agents that the function returns one candidate, inviting removal of the UDPFS probe as dead weight.
- Fix: Add the UDPFS exception clause (`udpfs:/POPS/` beside-the-VCD second candidate) to each statement of the one-path rule.
- Benefit: The load-bearing cover contract stays accurate for the one backend that differs; no agent removes the UDPFS probe on doc authority.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-110 — CONTRIBUTING.md packaging contract describes the pre-Ember ZIP (wrong top-level layout, phantom BUILD_INFO.txt, no EMBER/, no PSU)
- Category: 7
- Locations: CONTRIBUTING.md:50-55 (`three top dirs only (PS1_POPSLOADER/, POPS/ and POPSTARTER VERSIONS/), no root files… PS1_POPSLOADER/: POPSLOADER.ELF, POPSTARTER.ELF, BUILD_INFO.txt, APPINFO.PBT, title.cfg, icon.sys, list.icn, copy.icn, del.icn`); STATE.md:164 (`Release packaging policy is PS1_POPSLOADER/* + POPS/PATCH_5.BIN with strict manifest validation`) — vs code evidence: .github/workflows/compilation.yml "Verify complete release package" step (`expected = {"POPSLOADER.ELF", "POPSTARTER.ELF", "icon.sys", "list.icn", "copy.icn", "del.icn", "title.cfg", "APPINFO.PBT"}` asserted under `APPS/PS1_POPSLOADER/`; `EMBER/ember.elf`, `EMBER/LICENSE-BETA.txt`, ExampleGame `.cue`/`.bin`, `POPS/POPSTARTER.ELF`, `POPS/PATCH_5.BIN` all required; the ZIP also carries `PS1_POPSLOADER.psu` at its root); tools/build_release_kit.sh (`dist_root/APPS/PS1_POPSLOADER`, `dist_root/POPS`, `dist_root/EMBER/games/ExampleGame`)
- Problem: The contributor-facing packaging contract names a layout CI no longer produces or verifies: the app folder moved under `APPS/`, `BUILD_INFO.txt` is not in the verified eight-file set, `POPSTARTER VERSIONS/` is not part of the formal kit, and the entire `EMBER/` tree plus the flat PSU — the headline 1.4.x payload — are absent from the contract. A contributor "fixing" packaging to match CONTRIBUTING would break the strict CI verification.
- Fix: Rewrite the CONTRIBUTING packaging bullets from the compilation.yml verification block (APPS/PS1_POPSLOADER eight files, POPS/, EMBER/, root PSU) and reduce STATE.md:164 to a pointer to it.
- Benefit: The packaging contract a contributor reads is the one CI enforces.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-111 — Pervasive stale path:line anchors and line counts in ARCHITECTURE.md / COMPONENTS.md (and one in LAUNCH_ARGUMENTS.md)
- Category: 7
- Locations: ARCHITECTURE.md:191-192 (`system.lua, ~8500 lines` / `ui.lua, ~6000 lines`); ARCHITECTURE.md Layer 4 control-flow block (main loop cited at `system.lua:6364-6376`, settings load at `system.lua:6333`); COMPONENTS.md §2 (`LoadSettingsNonFatal (system.lua:3650)`, `SaveSettingsAtomic (system.lua:3598)`, render loop `system.lua:6364-6376`, `return UI (ui.lua:4991)`); docs/LAUNCH_ARGUMENTS.md (`system.lua:9368-9372` for the SMB auto-launch toast) — vs code evidence: `wc -l` at this pin: bin/POPSLDR/system.lua = 11,784 lines, bin/POPSLDR/ui.lua = 7,599 lines; bin/POPSLDR/system.lua:6222 (`function PLDR.LoadSettingsNonFatal()`); bin/POPSLDR/system.lua:11772 (the main `while true do` loop); bin/POPSLDR/system.lua:11431 (the `Auto-launch page not supported` toast); bin/POPSLDR/ui.lua runs to 7,599 lines so a `return UI` at :4991 cannot be the file end the doc describes
- Problem: Both structural docs present themselves as citation-grade maps ("Every technical claim below cites path:line against this worktree" — COMPONENTS.md Purpose), but the Lua files have grown ~40% since the anchors were written and the cited lines now land in unrelated code (the "main loop" anchor lands inside settings parsing). AGENTS.md itself records that a prior doc pass left ~15 wrong anchors this way. This is one mechanism — anchor rot in the two map docs — filed once with verified instances rather than per-anchor.
- Fix: Regenerate or strip the Lua line anchors in ARCHITECTURE.md/COMPONENTS.md (keep function/symbol names, which still resolve, and drop bare line numbers for the Lua files, as docs/PRESERVATION_CONTRACTS.md already does); correct the two line counts or delete them.
- Benefit: The maps stop sending readers to wrong code with false confidence — the failure mode this repo has already been burned by.
- Effort: L · Risk: Low · Confidence: High (READ)

### RE-POPS-112 — COMPONENTS.md on-card payload lists only three of the six BDMA IRX variants
- Category: 7
- Locations: COMPONENTS.md:420 (`device-variant IRX (usbd.irx.{usbexfat,mx4sio,mmce}, usbhdfsd.irx.{usbexfat,mx4sio,mmce})`) — vs code evidence: bin/POPSLDR/ directory at this pin contains `usbd.irx.` and `usbhdfsd.irx.` in six suffixes each: `ata`, `ilink`, `mmce`, `mx4sio`, `udpfs`, `usbexfat`; bin/POPSLDR/system.lua:5157-5165 (`BDMA_SUFFIX` = USBEXFAT/MX4SIO/MMCE/ATA/ILINK/UDPFS)
- Problem: The component map omits the ATA (internal exFAT HDD), i.Link, and UDPFS driver pairs — three of the six backends the staging machinery can install, including the current flagship UDPFS pair.
- Fix: Extend the brace list to all six suffixes for both files.
- Benefit: The payload inventory matches the staging table it documents.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-113 — STATE.md still says Slovak is not in the language picker
- Category: 7
- Locations: STATE.md:5-9 (`Translation follow-up (2026-10-27): … Slovak wording awaits the contributor; SK is not yet in the picker`) — vs code evidence: bin/POPSLDR/system.lua:2559-2560 (`PLDR.LANGUAGE_ORDER = {"EN", "FR", "DE", "PT", "ES", "IT", "HU", "SK"}`; `LANGUAGE_NAMES` includes `SK = "Slovenčina"`); bin/changelog [1.4.3] (Slovak translation added); docs/translations/README.md:9-11 (`it now ships as PLDR.I18N.SK and appears in the language picker as Slovenčina`); STATE.md's own line 1 (1.4.3 added the Slovak translation)
- Problem: The canonical doc's top-of-file follow-up note, written before SVKghost returned the workbook, was never retired after 1.4.3 shipped Slovak. It tells contributors the contribution is still awaited when the translation, its corrections (1.4.4), and the picker entry are all in the tree. (Related, not separately filed: STATE.md:61 and STATE.md:252 say translations ship in "all six languages" — defensible at the EXP73 date as the six non-English dictionaries then present, but the count is seven dictionaries / eight languages now; INFERRED ambiguity, worth one word while editing.)
- Fix: Delete the stale follow-up paragraph (its QA-matrix pointer is preserved in QA_REGRESSION_MATRIX.md's dated 2026-10-27 section) or replace it with the shipped status.
- Benefit: The canonical doc stops soliciting a contribution that already landed.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-114 — STATE.md says the dropped Square binding still toggles cover art
- Category: 7
- Locations: STATE.md:98 (`The dropped bindings still work where they did (Square toggles cover art, START opens Settings) — only the legend clutter went`) — vs code evidence: bin/POPSLDR/ui.lua:3738-3741 (`EXP42: Square no longer toggles cover art here… it now lives in Settings > Game List > "Cover art" (PLDR.COVER_ART)`); bin/POPSLDR/ui.lua:5218-5226 (same removal note at the Cover art setting); TESTING.md:47 and README.md Troubleshooting both state the current behaviour (`Square no longer toggles cover art at all` / `Square is not bound in the game list`)
- Problem: EXP42 removed the Square toggle and replaced it with the persisted COVER_ART setting; STATE.md's Settings section — the canonical one — still asserts the binding works. STATE.md contradicts itself too: its own Cover art section (STATE.md:156) says COVER_ART "replaced the Square toggle".
- Fix: Delete "Square toggles cover art" from the sentence (START opening Settings is still true and can stay).
- Benefit: One less phantom binding for testers to report as broken.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-115 — STATE.md says carousel devices are "all shown by default"; i.Link ships hidden
- Category: 7
- Locations: STATE.md:150 (`Persisted as HIDDEN_DEVICES (CSV of stable device keys; all shown by default; a guard keeps ≥1 visible)`) — vs code evidence: bin/POPSLDR/system.lua:6247 (`PLDR.HIDDEN_DEVICES = "ILINK"` — factory default hides the i.Link page); STATE.md:65 (its own EXP34 bullet: `HIDDEN_DEVICES = ILINK (the i.Link page ships Hidden)`); README.md:139 (correct: every other device defaults to Shown, i.Link ships Hidden)
- Problem: The canonical doc's Main-menu section states the opposite of its own defaults bullet and of the code: a fresh install's carousel omits i.Link by design.
- Fix: Change the parenthetical to "all shown by default except i.Link, which ships hidden".
- Benefit: Fresh-install carousel expectations match first boot.
- Effort: S · Risk: Low · Confidence: High (READ)

---

## Appendix A — Coverage and key evidence

**Read in full:** all four Lua files; all EE C/C++ under `src/` (incl. `fntsys`, `lua*` bindings, `embed_assets.cpp`, `elf_loader` child sources); all IOP C under `modules/` (pademu incl. both ds34usb and both ds34bt copies, bdm glue, ata glue, `iop/irx/` stubs, `iop/sound/`); the Makefile; all 10 workflows; all host tools and test scripts; the tarball's component trees (`bdm`, `bdmfs_fatfs` logic files, `libbdm`, `usbd` core, `usbmass_bd`); all docs prose listed in the docs pass (162 tracked `.md` files were censused; the claim-bearing set was read in full).

**BDMAssault component ↔ merged relation (scripted diff, 37 file pairs):** 20 pairs byte-identical; 17 pairs differ, and every delta is an include-path substitution (`../../` → `../bdm/`-style), except three `_start`/banner edits and the two `imports.lst` unions in the merged trees. **No merged copy carries any fix absent from its component** — the merged trees are a second copy of the same code, not a newer revision. The two `ffunicode.c` copies total 3,918,786 B of the tarball's 4,951,196 B (79.1%).

**Shipped-binary correspondence:** shipped `usbd.irx` (48,500 B) is the `__bdm_assault` product (string-exact identity, INFERRED byte-correspondence); shipped `usbhdfsd.irx` (14,993 B) is an MX4SIO v1.2 SIO2 driver with **no source anywhere in the tarball**; `usbd_bd_assault.irx` appears in neither shipped binary (RE-POPS-044). Tracked-binary census: 38 tracked binary files, 26 distinct by SHA-256, 1,778,343 tracked bytes; 23 of 26 distinct binaries have no in-repo source; 2 have tarball source (the BDM core and `usbmass_bd`, both INFERRED); 1 partial (`ata_bd.irx`).

**Host-side verification actually run (in `/tmp`, at the pin):** `host_harness` 62/62 PASS · `pad_harness` 13/13 PASS · `png_decoder_harness` 60/60 PASS · `test_disc_layout` 30 cases PASS · `test_udpfs_config_runtime` PASS · `test_udpfs_integration` PASS (see RE-POPS-105 for what its "integration" half actually asserts) · `test_translation_handoff` 7/7 PASS · `docs_verify.py` PASS · `lua_minify.py --check` PASS. No PS2 build was attempted and nothing here is hardware-verified; performance findings are structural only.

**Docs claim tally (docs pass):** 386 checkable present-tense claims enumerated — 339 MATCH code, 34 CONTRADICTED (consolidated into the 13 docs findings above), 13 UNVERIFIABLE-HERE (external program behaviour, screenshot contents, third-party tool facts — listed in the docs section working file, not filed as findings).

## Appendix B — Files not read

Stated plainly, per the audit's process rules:

- `src/elf_loader/loader.c` lines 81–8740 — the generated bin2c hex payload. Header, metadata and generator relationship read and verified; the payload bytes were sized and hashed by script, not read as source (it is data, regenerated from `src/elf_loader/src/loader/src/loader.c`, which was read in full).
- Tarball `ff.c` (6,986 lines) and its merged copy — structurally scanned only (vendored ChaN FatFs core; configuration and `disk_ioctl` sites grepped in context). No finding rests on unread `ff.c` internals.
- Tarball `ffunicode.c` Unicode tables (15,593 lines × 2 copies) — scanned only (header, code-page `#if` structure, conversion tail read). The duplication finding rests on scripted byte counts and diffs, not on reading the tables.
- Tarball merged-tree copies were not independently line-read; their relation to the read components was established by scripted diff of all 37 pairs, with every delta line read.
- Tarball headers scanned or byte-compared only: `ff.h`, `diskio.h`, `fs_driver.h`, `usbd.h`, `usbd_macro.h`, `scsi.h`, the `usbd` internal headers, and all `module_debug.h` / `irx_imports.h` copies (md5-compared). Tarball non-code files (`00readme.txt`, `00history.txt`, `LICENSE`, dotfiles, `.vscode/settings.json`) scanned only.
- `bin/POPSLDR/system.lua` lines 2568–4843 (the I18N string tables) were not proofread translation-by-translation; they were script-censused (2,249 entries: key sets, counts, occurrence checks) and individual entries were read wherever a finding cites one.
- `modules/ds34bt/iop/smsutils.S` was not opened individually — it is md5-identical (0-line diff) to the `ds34usb` copy, which was read.
- `iop/ata_bd_fast/ps2atad.c` lines 801–1186 were not read in full prose (lines 1–800 and 1187–1310 read, plus targeted greps). The finding that cites this tree (RE-POPS-057) rests on the Makefile's own statement and build wiring, not on those lines.
- `.research/**` (115 Markdown files) not full-read — it is a historical POPStarter research archive and documentation-site source, not POPSLoader documentation. It was keyword-scanned for present-tense POPSLoader claims (one hit, which MATCHES code) and three files were sample-read. Its embedded archive files (`.zip`/`.7z`) were inventoried by name and hash only, not extracted; the BDMAssault tarball was the one tasked extraction.
- `docs/archive/**` (17 files) grep-swept only — the folder self-marks as superseded archives; factual claims there were not audited.
- `docs/third_party/okeanos_udpfs/UPSTREAM-README.md` not read (vendored upstream attribution text).
- Non-text tracked assets (images under `bin/POPSLDR/IMG/`, `APPINFO.PBT`, `.icn` files, `PATCH_5.BIN`, `boot.adp`, fonts) were inventoried by hash/size only, not content-inspected, except where a finding cites a specific file's text (`title.cfg` was read).
- External dependencies not present in either tree (`usbhdfsd-common.h`, PS2SDK headers) could not be read; the one finding that depends on the former (RE-POPS-038) says so in its own text.

## Appendix C — Section-to-final ID mapping

The six section working files (`redo-sections/redo-pops-{lua,ee,iop,bdm,bin,doc}.md`) use per-section IDs; the table below maps them to the final numbering above. Merged findings list both source IDs.

| Section ID | New ID |
|---|---|
| RE-POPS-BDM-01 | RE-POPS-001 |
| RE-POPS-IOP-04 | RE-POPS-002 |
| RE-POPS-IOP-08 | RE-POPS-003 |
| RE-POPS-BDM-08 | RE-POPS-004 |
| RE-POPS-BDM-11 | RE-POPS-005 |
| RE-POPS-BDM-03 | RE-POPS-006 |
| RE-POPS-BDM-16 | RE-POPS-007 |
| RE-POPS-BDM-19 | RE-POPS-008 |
| RE-POPS-IOP-09 | RE-POPS-009 |
| RE-POPS-IOP-05 | RE-POPS-010 |
| RE-POPS-BDM-12 | RE-POPS-011 |
| RE-POPS-BDM-13 | RE-POPS-012 |
| RE-POPS-BDM-06 | RE-POPS-013 |
| RE-POPS-BDM-02 | RE-POPS-014 |
| RE-POPS-BDM-04 | RE-POPS-015 |
| RE-POPS-BDM-35 | RE-POPS-016 |
| RE-POPS-BDM-10 | RE-POPS-017 |
| RE-POPS-BDM-07 | RE-POPS-018 |
| RE-POPS-BDM-15 | RE-POPS-019 |
| RE-POPS-BDM-17 | RE-POPS-020 |
| RE-POPS-EE-14 | RE-POPS-021 |
| RE-POPS-EE-11 | RE-POPS-022 |
| RE-POPS-EE-25 | RE-POPS-023 |
| RE-POPS-IOP-10 | RE-POPS-024 |
| RE-POPS-IOP-06 | RE-POPS-025 |
| RE-POPS-IOP-07 | RE-POPS-026 |
| RE-POPS-EE-12 | RE-POPS-027 |
| RE-POPS-EE-13 | RE-POPS-028 |
| RE-POPS-BDM-09 | RE-POPS-029 |
| RE-POPS-EE-16 | RE-POPS-030 |
| RE-POPS-EE-18 | RE-POPS-031 |
| RE-POPS-EE-17 | RE-POPS-032 |
| RE-POPS-EE-15 | RE-POPS-033 |
| RE-POPS-EE-24 | RE-POPS-034 |
| RE-POPS-IOP-13 | RE-POPS-035 |
| RE-POPS-BDM-05 | RE-POPS-036 |
| RE-POPS-BDM-20 | RE-POPS-037 |
| RE-POPS-BDM-14 | RE-POPS-038 |
| RE-POPS-BDM-18 | RE-POPS-039 |
| RE-POPS-BIN-03 | RE-POPS-040 |
| RE-POPS-BIN-05 | RE-POPS-041 |
| RE-POPS-BIN-11 | RE-POPS-042 |
| RE-POPS-LUA-01 | RE-POPS-043 |
| RE-POPS-BDM-33 | RE-POPS-044 |
| RE-POPS-BDM-21 | RE-POPS-045 |
| RE-POPS-BIN-06 | RE-POPS-046 |
| RE-POPS-IOP-01 | RE-POPS-047 |
| RE-POPS-EE-07 | RE-POPS-048 |
| RE-POPS-BIN-01, RE-POPS-EE-01 | RE-POPS-049 |
| RE-POPS-BIN-02 | RE-POPS-050 |
| RE-POPS-EE-05 | RE-POPS-051 |
| RE-POPS-BDM-27 | RE-POPS-052 |
| RE-POPS-IOP-03 | RE-POPS-053 |
| RE-POPS-EE-02 | RE-POPS-054 |
| RE-POPS-LUA-07 | RE-POPS-055 |
| RE-POPS-BIN-04 | RE-POPS-056 |
| RE-POPS-IOP-02 | RE-POPS-057 |
| RE-POPS-EE-26 | RE-POPS-058 |
| RE-POPS-DOC-02 | RE-POPS-059 |
| RE-POPS-DOC-01 | RE-POPS-060 |
| RE-POPS-BDM-34 | RE-POPS-061 |
| RE-POPS-EE-10 | RE-POPS-062 |
| RE-POPS-EE-23 | RE-POPS-063 |
| RE-POPS-LUA-08 | RE-POPS-064 |
| RE-POPS-BDM-30 | RE-POPS-065 |
| RE-POPS-BDM-28 | RE-POPS-066 |
| RE-POPS-BDM-29 | RE-POPS-067 |
| RE-POPS-EE-27 | RE-POPS-068 |
| RE-POPS-IOP-12 | RE-POPS-069 |
| RE-POPS-LUA-05 | RE-POPS-070 |
| RE-POPS-LUA-13 | RE-POPS-071 |
| RE-POPS-LUA-14 | RE-POPS-072 |
| RE-POPS-DOC-03 | RE-POPS-073 |
| RE-POPS-DOC-13 | RE-POPS-074 |
| RE-POPS-BIN-09 | RE-POPS-075 |
| RE-POPS-EE-19 | RE-POPS-076 |
| RE-POPS-EE-20 | RE-POPS-077 |
| RE-POPS-EE-21 | RE-POPS-078 |
| RE-POPS-LUA-09 | RE-POPS-079 |
| RE-POPS-LUA-02 | RE-POPS-080 |
| RE-POPS-LUA-16 | RE-POPS-081 |
| RE-POPS-EE-22 | RE-POPS-082 |
| RE-POPS-BDM-26 | RE-POPS-083 |
| RE-POPS-EE-08 | RE-POPS-084 |
| RE-POPS-EE-09 | RE-POPS-085 |
| RE-POPS-EE-06 | RE-POPS-086 |
| RE-POPS-EE-03 | RE-POPS-087 |
| RE-POPS-LUA-15 | RE-POPS-088 |
| RE-POPS-EE-04 | RE-POPS-089 |
| RE-POPS-LUA-03 | RE-POPS-090 |
| RE-POPS-LUA-04 | RE-POPS-091 |
| RE-POPS-LUA-06 | RE-POPS-092 |
| RE-POPS-LUA-10 | RE-POPS-093 |
| RE-POPS-LUA-11 | RE-POPS-094 |
| RE-POPS-LUA-12 | RE-POPS-095 |
| RE-POPS-IOP-11 | RE-POPS-096 |
| RE-POPS-BDM-22 | RE-POPS-097 |
| RE-POPS-BDM-23 | RE-POPS-098 |
| RE-POPS-BDM-24 | RE-POPS-099 |
| RE-POPS-BDM-25 | RE-POPS-100 |
| RE-POPS-BDM-31 | RE-POPS-101 |
| RE-POPS-BDM-32 | RE-POPS-102 |
| RE-POPS-BIN-08 | RE-POPS-103 |
| RE-POPS-BIN-10 | RE-POPS-104 |
| RE-POPS-BIN-12 | RE-POPS-105 |
| RE-POPS-BIN-07 | RE-POPS-106 |
| RE-POPS-DOC-04 | RE-POPS-107 |
| RE-POPS-DOC-05 | RE-POPS-108 |
| RE-POPS-DOC-07 | RE-POPS-109 |
| RE-POPS-DOC-09 | RE-POPS-110 |
| RE-POPS-DOC-10 | RE-POPS-111 |
| RE-POPS-DOC-11 | RE-POPS-112 |
| RE-POPS-DOC-06 | RE-POPS-113 |
| RE-POPS-DOC-08 | RE-POPS-114 |
| RE-POPS-DOC-12 | RE-POPS-115 |
