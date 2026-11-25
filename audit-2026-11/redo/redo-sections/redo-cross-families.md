# REDO Audit — Cross-Repo Copy Families (CROSS pass)

Blind redo, derived only from the clones in `~/workspace/audit-clones-2026-11-13/`.
Pins verified: RiptOPL `2e347d5ac885`, Launchstation `9fb0598a79f0`, POPSLoader `29272cddbf01`,
Simple-Media-System (SMS) `e65ced39a27e`, PS2-Servers `c5f021c4d386`.
PS2-Servers contains **no** copy of any family below (its only hits were a Go test cache and a
Python `virtual_exfat.py` launcher helper — not a fork of any C family); it is omitted from the tables.
Hashes are `sha256[0:16]` (full sha256 computed by script; prefix shown for table width).
Line counts are file lines. `diff -w -B` (whitespace-insensitive) was used to separate real
divergence from clang-format churn. The POPSLoader BDMAssault tarball was extracted to `/tmp` only.

Category legend (this section): 1 = memory-safety / out-of-bounds, 2 = hang / livelock / DoS,
3 = on-disk / on-wire data corruption, 4 = logic correctness, 5 = missing input validation,
6 = resource leak / exhaustion, 7 = stale-copy divergence (fix exists in a sibling), 8 = duplication / maintenance.

---

## Family 1 — ds34 pademu (ds34usb / ds34bt, IOP standalone + in-game pademu)

Copies: **10 `.c` copies** of the two drivers (5 per transport counting pademu variants) across 3 repos,
plus 4 EE libs. Launchstation has **no** `modules/pademu` copy (standalone IOP only + EE glue `src/pad_ds34.c`).

| File | Repo / path | sha256[0:16] | Lines | State |
|---|---|---|---|---|
| ds34usb.c (IOP) | Launchstation `iop/ds34usb/iop/ds34usb.c` | `cb2cdab6da80fdee` | 806 | baseline |
| ds34usb.c (IOP) | POPSLoader `modules/ds34usb/iop/ds34usb.c` | `ceecbd12774cbc01` | 806 | **identical to Launch under `diff -w -B`** (whitespace only) |
| ds34usb.c (IOP) | RiptOPL `modules/ds34usb/iop/ds34usb.c` | `4b3d0344943a703e` | 998 | diverged: SHANWAN + DS5, epCount guard |
| ds34usb.c (pademu) | POPSLoader `modules/pademu/ds34usb.c` | `67b480fba530dd53` | 634 | baseline |
| ds34usb.c (pademu) | RiptOPL `modules/pademu/ds34usb.c` | `3b5599fd16df04ff` | 616 | diverged: guards + per-pad buffers |
| ds34bt.c (IOP) | Launchstation `iop/ds34bt/iop/ds34bt.c` | `7cee04a39b1af4b2` | 1719 | baseline |
| ds34bt.c (IOP) | POPSLoader `modules/ds34bt/iop/ds34bt.c` | `13149bc3983a6d6b` | 1719 | = Launch except 1 line (FAM-02 fix) |
| ds34bt.c (IOP) | RiptOPL `modules/ds34bt/iop/ds34bt.c` | `6e7ab5b2a4de9e06` | 1719 | = Launch except renames / field renames |
| ds34bt.c (pademu) | POPSLoader `modules/pademu/ds34bt.c` | `84978c67ee4c98db` | 1521 | baseline |
| ds34bt.c (pademu) | RiptOPL `modules/pademu/ds34bt.c` | `cdb0cb3711fe6168` | 1425 | diverged: report-size + power guards |
| pademu.c | POPSLoader `modules/pademu/pademu.c` | `3818e4c66279989c` | 536 | baseline |
| pademu.c | RiptOPL `modules/pademu/pademu.c` | `6b7e41d3852d80ff` | 589 | diverged: per-version SIO2 hooks |
| libds34bt.c (EE) | Launchstation `iop/ds34bt/ee/` = POPSLoader `modules/ds34bt/ee/` | `d228c30f40753f72` | 173 | **byte-identical pair** |
| libds34bt.c (EE) | RiptOPL `modules/ds34bt/ee/` / SMS `src/libds34bt.c` | `0733ab2791855819` / `f256a6102fc315a3` | 181 / 182 | both diverged |
| libds34usb.c (EE) | Launch / POPS / Ript / SMS | `0fb36b531222aa92` / `339b0045f5a3000a` / `7bbe47fb8b58578f` / `384a9ae2e3533b7a` | 145 / 148 / 153 / 154 | all four diverged |

Defect states (details in FAM-01…03): the battery index is fixed in **2 of 10** copies, the DS4 LED
memset length is fixed in **1 of 5** ds34bt copies, the USB endpoint-walk guard exists in **2 of 5**
ds34usb copies and **0 of 5** ds34bt copies. No copy checks `endpoint->bLength == 0` before
`endpoint = (char *)endpoint + endpoint->bLength`.

## Family 2 — APA / HDD (apa.c, cache.c, hdd_fio.c, hdd.c, ps2atad.c)

Copies: RiptOPL 1 full set; Launchstation **2** apa.c copies (full `ps2hdd_osd` + stripped `hdl_info`) + 1 atad; POPSLoader 1 atad variant only.

| File | Repo / path | sha256[0:16] | Lines | State |
|---|---|---|---|---|
| apa.c | Launchstation `iop/hdl_info/apa.c` | `fa2f1bf3a24395bd` | 320 | stripped hdl variant |
| apa.c | Launchstation `iop/ps2hdd_osd/apa.c` | `3bbab327115b7890` | 522 | stock SDK behaviour (FAM-04) |
| apa.c | RiptOPL `modules/hdd/apa/src/apa.c` | `3ec57a7fbf51baad` | 525 | hardened (FAM-04) |
| cache.c | Launchstation `iop/ps2hdd_osd/cache.c` | `279e763b2b6522fc` | 218 | = Ript under `diff -w -B` except brace style |
| cache.c | RiptOPL `modules/hdd/apa/src/cache.c` | `25d7a95431d2ebd0` | 211 | (same) |
| hdd_fio.c | Launchstation `iop/ps2hdd_osd/hdd_fio.c` | `a62692aaf87c2bd8` | 1207 | stock (FAM-05) |
| hdd_fio.c | RiptOPL `modules/hdd/apa/src/hdd_fio.c` | `5c3dc81770aa5b12` | 1247 | hardened (FAM-05) |
| hdd.c | Launchstation `iop/ps2hdd_osd/hdd.c` / `iop/hdl_info/hdd.c` | `6e38ed82483fabe9` / `fee48fabc39da8f5` | 406 / 198 | diverged pair |
| hdd.c | RiptOPL `modules/hdd/apa/src/hdd.c` | `8fc6c5a24a4aad6e` | 384 | diverged |
| hdd_blkio.c | Launchstation `iop/ps2hdd_osd/` / RiptOPL `modules/hdd/apa/src/` | `129a5b9da7476def` / `2f1ea88a96c9f817` | 431 / 415 | diverged |
| ps2atad.c | Launchstation `iop/ata_bd/src/ps2atad.c` | `07b15b94282a3373` | 1581 | has `chunk` fix, no range guard |
| ps2atad.c | POPSLoader `iop/ata_bd_fast/ps2atad.c` | `21ae309432487df9` | 1593 | phantom-slave caps; **chunk regression (FAM-06)** |
| ps2atad.c | RiptOPL `modules/hdd/atad/src/ps2atad.c` | `8ee1d837d203d398` | 1646 | `chunk` fix + range/4Kn/APA-reserved guards (FAM-07) |

Launchstation-only siblings with no RiptOPL counterpart in this set: `ps2hdd_osd/journal.c`, `misc.c`, `password.c`, `free.c`.

## Family 3 — FAT implementations

Three unrelated implementations, not one fork: (a) ChaN FatFs under BDM (RiptOPL source + tarball source),
(b) SMS's own SMSUMS FAT12/16/32 (`ums_fat.c`, single copy), (c) binary-only IRXs in SMS/POPSLoader.

| File | Repo / path | sha256[0:16] | Lines | State |
|---|---|---|---|---|
| ff.c | RiptOPL `modules/bdm/bdmfs_fatfs/fatfs/ff.c` | `e4d0663816953882` | 7257 | newer FatFs, cluster-range checks at :1167/:1188/:1267/:1462 |
| ff.c | POPS tarball `bdmfs_fatfs/src/ff.c` (+ duplicate `__bdm_assault/src/bdmfs/bdmfs_ff.c` `fcac5adef7d7eded`) | `7f7546cb2e294afb` | 6985 | older FatFs, same range-check family |
| fs_driver.c | RiptOPL `modules/bdm/bdmfs_fatfs/src/fs_driver.c` | `787dd314c20489d2` | 1093 | volume resolved by driver name+unit (FAM-11) |
| fs_driver.c | POPS tarball `bdmfs_fatfs/src/fs_driver.c` (+ duplicate `fc056cc45e5e56c8`) | `af707f823ca3e729` | 849 | volume = `fd->unit` directly (FAM-11) |
| diskio.c | RiptOPL `.../fatfs/diskio.c` / tarball `bdmfs_fatfs/src/diskio.c` | `b75bdb25b1887cba` / `4ad4e7232f080d2c` | 170 / 169 | near-identical |
| ffunicode.c | RiptOPL / tarball | `6cd4dc4a664386eb` / `4e9d3ad404bcdee6` | 15593 / 15593 | same line count, bytes differ |
| ums_fat.c | SMS `iop/SMSUMS/src/ums_fat.c` | `2f6707a45473dc12` | 1140 | **only copy** (FAM-10) |
| ums_driver.c / ums_cache.c | SMS `iop/SMSUMS/src/` | `c6ba01696da619db` / `9980361e22f596b0` | 420 / 76 | only copies |
| bdmfs IRX (binary) | SMS `irx/bdmfs_fatfs.irx` / POPS `iop/embed/bdmfs_vfat.irx` | `1e1d9deac89e8b60` / `8536a93f3cd1ec9d` | 36877 B / 30013 B | no source in either repo; hashes unrelated |

## Family 4 — Memory-card parsers (vmcman IOP, EE mc code)

**No shared fork exists to diverge.** RiptOPL has no vmcman source at all (SDK mcman + its own
`genvmc` creator + `mcemu` in-game emulator + EE parsers); Launchstation carries the only vmcman
fork and its own new EE parsers. Both EE parser sets are independently cycle-bounded — this is
the **least** divergent family in defect state.

| File | Repo / path | sha256[0:16] | Lines | State |
|---|---|---|---|---|
| vmcman main.c | Launchstation `iop/vmcman/src/main.c` | `2f5ecb413aa6d565` | 4398 | only copy |
| mcdev.c / mcsio2.c | Launchstation `iop/vmcman/src/` | `cec330a4dc1ef642` / `e45f733f47d8d0f3` | 842 / 1354 | only copies |
| ps2mc_fio.c / ps1mc_fio.c | Launchstation `iop/vmcman/src/` | `35e646edc15c671a` / `2c89373b9a0a3ae2` | 1472 / 766 | only copies |
| genvmc.c | RiptOPL `modules/vmc/genvmc/genvmc.c` | `93568093f4feb246` | 947 | creator, not a parser fork |
| mcemu.c | RiptOPL `modules/mcemu/mcemu.c` | `890832cbe3704ca6` | 931 | in-game VMC, no chain walk of its own |
| sysvmc.cpp (EE) | RiptOPL `src/platform/sysvmc.cpp` | `86250e6ca036b925` | 285 | superblock validated :210-216 (magic, type, geometry, size equation) |
| saveicon.cpp (EE) | RiptOPL `src/gfx/saveicon.cpp` | `673d5fe130260a0e` | 1315 | chain walks step-bounded :413, :442 (`++steps > card->clusters`) |
| mc_card_view.c (EE) | Launchstation `src/mc_card_view.c` | `aaf89f35426f4404` | 543 | chain walks step-bounded :132 (`steps > alloc_usable`), geometry pinned :231-234 |
| mc_card_write.c (EE) | Launchstation `src/mc_card_write.c` | `c5dc5c081afb376d` | 1112 | chain walks step-bounded :675-676 |
| mcman.irx (binary) | SMS `irx/mcman.irx` | `caf1aa5c83a26520` | 72101 B | binary only |

No candidate is raised for this family: every EE parser that walks a FAT chain in either repo
carries an explicit step bound, and the single IOP vmcman has no sibling copy to be stale against.
(LESS-NOT-MORE: do not manufacture a finding here.)

## Family 5 — TCP/IP stacks (SMSTCPIP / lwIP, ps2ips RPC)

Two lwIP snapshots: RiptOPL's is the newer/flattened tree (68 files), SMS's is the older
`src/` tree (55 files). Launchstation carries **no** lwIP source — only the ps2ips RPC shim
(vendored, `iop/ps2ips_rpc/`) + EE `ee_libs/tcpips/ps2ipc.c` + a precompiled `iop/__v10/ps2ip.irx`
(`9489a007711bf2f9`, 118513 B). POPSLoader carries only a binary `ps2ip.irx` that is
**byte-identical to RiptOPL's shipped POPS copy** (`1bf99ca297dcca41`, 109497 B, both repos).

| File | RiptOPL `modules/network/SMSTCPIP/` | SMS `iop/SMSTCPIP/src/` | Whitespace-insensitive diff |
|---|---|---|---|
| pbuf.c | `436579a152c531f3`, 802 | `22e3c597f29600d1`, 540 | 555 lines — different lwIP vintage + pool locking |
| sockets.c | 1415 | 1292 | 509 lines |
| ps2ip.c | 570 | 463 | 423 lines |
| tcp.c / tcp_in.c | `0c48cfa4157c1a8f`, 1125 (tcp_in) | `8cf1d3f3542d610e`, 1204 (tcp_in) | 365 / 225 lines; Ript adds SYN-ACK `rto` reset (tcp_in.c:533-534), absent in SMS |
| ip_frag.c | `c25a0a220a255fcd`, 337 | `4e0616fe2f87ae4e`, 320 | bitmap size differs by one byte (FAM-09) |
| mem.c / memp.c | 390 / 270 | 235 / 169 | 344 / 203 lines |
| udp.c / ip.c / tcp_out.c | 786 / 404 / 570 | 803 / 391 / 579 | 67 / 76 / 79 lines |
| loopif.c | 113 | 121 | 3 lines (near-identical) |
| ps2ips.c (RPC) | RiptOPL `modules/network/ps2ips/ps2ips.c` `001d7f59dad17ebe`, 752 | Launchstation `iop/ps2ips_rpc/ps2ips.c` `7abba35532cd12bc`, 694 | **two-way fix split (FAM-08)** |

## Family 6 — BDM / block-device (bdm, fs_driver, usbmass_bd)

RiptOPL holds the only maintained BDM source tree. The POPSLoader tarball
(`iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz`, sha256[0:16] `49c03644b5cbf993`)
contains the same tree **three times** (`bdm/`+`bdmfs_fatfs/`+`libbdm/`, `__bdm_assault/`, `__usbd_bd_assault/`)
at an older, unhardened state. Launchstation holds no BDM core source, but its `usbmass_bd` is
**byte-identical to RiptOPL's**. POPSLoader proper adds only `iop/bdm_query/bdm_query.c` (`c4fbd766c95023db`, 101).

| File | RiptOPL | Tarball copy | State |
|---|---|---|---|
| bdm.c | `modules/bdm/src/bdm.c` `312dde173cd8819a`, 275 | `bdm/src/bdm.c` `560c304c9ccead5d`, 246 | tarball lacks sector-size refusal (FAM-12) |
| part_driver.c | `8ccff8df8d524ecf`, 143 | `fc096663c0f879cd`, 135 | diverged |
| part_driver_gpt.c | `dd5de434027a5bf6`, 185 | `415451cd64867220`, 153 | tarball: stop-at-first-unused, no count clamp (FAM-12) |
| part_driver_mbr.c | `09261538eea49e18`, 134 | `2db81a83986060fd`, 99 | tarball lacks `partitions_sanity_check_mbr` (FAM-12) |
| bd_cache.c | `modules/bdm/libbdm/src/bd_cache.c` `26d031cb18899ddb`, 269 | `libbdm/src/bd_cache.c` `50c18e18f536e984`, 202 | tarball: unchecked allocs, unbounded caches (FAM-12) |
| bd_defrag.c | `0c7d371ec8d180c2`, 101 | `0b6bdc116ae83f77`, 101 | diverged |
| usb_mass.c | RiptOPL `modules/usb/usbmass_bd/src/` = Launchstation `iop/usbmass_bd/src/` — **`9473ebf5685faded`, 901, byte-identical** | `usbmass_bd/src/usb_mass.c` `70a6ac88cd7583c6`, 860 | tarball older |
| scsi.c | RiptOPL = Launchstation — **`801e3afeca20b65c`, 440, byte-identical** | `usbmass_bd/src/scsi.c` `d51c4b339148eb29`, 321 | tarball: READ(10)-only + unbounded ready loop (FAM-13) |
| bdm.irx / usbmass_bd.irx (binary) | — | SMS `irx/` `2ada1262cfb96261` 8881 B / `9b3ca2607ecc792c` 10177 B | binary only, no source in SMS |

---

# Candidate findings

## FAM-01 — DS3 battery index `power_level[Power]` out-of-bounds in 8 of 10 ds34 copies
- **Category:** 1 (memory safety), 7 (stale-copy divergence)
- **Locations:**
  - UNFIXED: RiptOPL `modules/ds34usb/iop/ds34usb.c:338`; RiptOPL `modules/ds34bt/iop/ds34bt.c:1333`;
    Launchstation `iop/ds34usb/iop/ds34usb.c:299`; Launchstation `iop/ds34bt/iop/ds34bt.c:1333`;
    POPSLoader `modules/ds34usb/iop/ds34usb.c:299`; POPSLoader `modules/ds34bt/iop/ds34bt.c:1333`;
    POPSLoader `modules/pademu/ds34usb.c:304` (guard is only `Power != 0xEE`);
    POPSLoader `modules/pademu/ds34bt.c:1275-1276` (same).
  - FIXED: RiptOPL `modules/pademu/ds34usb.c:332-333` (`if (report->Power <= 0x05)`);
    RiptOPL `modules/pademu/ds34bt.c:1251-1252` (`if (reported_power <= 0x05)`).
  - Table (all copies): `power_level[] = {0x00,0x00,0x02,0x06,0x0E,0x1E}` — 6 entries, e.g. RiptOPL `modules/ds34usb/iop/ds34usb.c:45`.
    `Power` is a full `u8` in the DS3 report (`ds34usb.h:121`: "05=full … EE=charging").
- **Problem:** The only excluded value is `0xEE` (charging). Any other device-supplied value
  `0x06–0xED` — a clone/fake DS3, a corrupt report — indexes up to 231 bytes past a 6-byte
  static array and the garbage byte is driven onto the controller LED via `oldled[0]`.
  Read-only OOB (no write), so impact is a wrong LED byte + UB, not memory corruption;
  stated plainly so it is not oversold. The fix already exists twice in-tree (RiptOPL pademu)
  and was never back-ported to the other eight copies, including RiptOPL's own IOP pair.
- **Fix in words:** In the eight unfixed copies, gate the index exactly as the pademu copies do
  (`Power <= 0x05`) before `power_level[Power]`; nothing else changes.
- **Benefit:** Removes the only attacker/device-controlled OOB read in the ds34 family; makes all 10 copies agree.
- **Effort:** Trivial (one condition × 8 files). **Risk:** None — values >5 currently read garbage.
- **Confidence:** High — table size, field width, guards and non-guards all read directly in every copy.

## FAM-02 — ds34bt DS4 LED report: `memset` length is the DS3 length in 4 of 5 copies (29 bytes of stack sent)
- **Category:** 1 / 3 (uninitialised data on the wire), 7
- **Locations:** Buffer declared `u8 led_buf[PS4_11_REPORT_LEN + 2]` (= 0x4D+2 = 79) in all copies
  (e.g. RiptOPL `modules/ds34bt/iop/ds34bt.c:1208`); DS4 branch then sends `size += PS4_11_REPORT_LEN`.
  - WRONG LENGTH `mips_memset(led_buf, 0, PS3_01_REPORT_LEN + 2)` (= 0x30+2 = 50):
    RiptOPL `modules/ds34bt/iop/ds34bt.c:1243`; Launchstation `iop/ds34bt/iop/ds34bt.c:1243`;
    RiptOPL `modules/pademu/ds34bt.c:1179`; POPSLoader `modules/pademu/ds34bt.c:1181`.
  - FIXED: POPSLoader `modules/ds34bt/iop/ds34bt.c:1243` (`PS4_11_REPORT_LEN + 2`) — the **only**
    differing line between the POPSLoader and Launchstation IOP copies (`diff -w -B`).
  - Length constants: `PS3_01_REPORT_LEN = 0x30`, `PS4_11_REPORT_LEN = 0x4D` (e.g. Launchstation `iop/ds34bt/iop/ds34bt.h:247,251`).
- **Problem:** In the DS4 branch only offsets 0–13 of `led_buf` are assigned after the memset;
  bytes 50–78 are sent to the controller (via `HID_command(..., led_buf, size, ...)`) holding
  whatever was on the IOP stack. Non-deterministic pad behaviour and a small stack-data leak
  to a USB/BT device, every LED/rumble update.
- **Fix in words:** Change the one memset length to `PS4_11_REPORT_LEN + 2` in the four copies,
  matching the POPSLoader IOP copy verbatim.
- **Benefit:** Deterministic, fully-zeroed DS4 output reports in every build that ships ds34bt.
- **Effort:** Trivial (1 token × 4 files). **Risk:** None — widens a memset within its own buffer.
- **Confidence:** High — buffer size, both constants, memset and send size read in all five copies.

## FAM-03 — ds34usb endpoint walk: `bNumEndpoints == 0` makes `epCount = -1` and the do-while never terminates; no `bLength == 0` check anywhere
- **Category:** 2 (hang), 5, 7
- **Locations:**
  - FIXED (USB only): RiptOPL `modules/ds34usb/iop/ds34usb.c:153-159` and RiptOPL `modules/pademu/ds34usb.c:151`
    (`if (epCount < 0) { usb_release(pad); return 1; }`, with explanatory comment).
  - UNFIXED: Launchstation `iop/ds34usb/iop/ds34usb.c:130-152` (`epCount = interface->bNumEndpoints - 1`,
    then `do { … endpoint = (char *)endpoint + endpoint->bLength; } while (epCount--);`);
    POPSLoader `modules/ds34usb/iop/ds34usb.c` (same, whitespace-identical);
    POPSLoader `modules/pademu/ds34usb.c:125-145` (same).
  - UNFIXED, all 5 ds34bt copies: e.g. Launchstation `iop/ds34bt/iop/ds34bt.c:117-140`,
    RiptOPL `modules/ds34bt/iop/ds34bt.c:117-140` — same `epCount = bNumEndpoints - 1` + `while (epCount--)`.
    Mitigation, stated for fairness: `bt_probe` rejects `bNumEndpoints < 3`
    (Launchstation `iop/ds34bt/iop/ds34bt.c:79`), so the BT connect path is not normally
    reachable with 0 endpoints; the USB probe checks only VID/PID
    (Launchstation `iop/ds34usb/iop/ds34usb.c:82-97`) and is fully exposed.
  - ALL 10 copies: the walk advances by `endpoint->bLength` with no `bLength == 0` (or `< sizeof(UsbEndpointDescriptor)`) check.
- **Problem:** With `epCount = -1`, `while (epCount--)` tests −1, −2, −3 … — never 0 — so the
  loop walks descriptor memory indefinitely, calling `UsbOpenEndpointAligned` on garbage,
  at connect time on the IOP. A DS3-class device (or clone) whose interface reports 0 endpoints
  hangs the driver. Separately, `bLength == 0` makes the walk re-read the same descriptor for
  the whole (finite) count — benign for USB's fixed count of 21, wrong data regardless.
- **Fix in words:** Copy RiptOPL's `epCount < 0` early-return into the three unfixed USB copies;
  add the same return to all five BT copies (defence in depth behind the probe check);
  in all ten walks, break if `endpoint->bLength == 0`. Deletions/guards only, no new code paths.
- **Benefit:** A malformed/clone controller can no longer wedge USB pad init in Launchstation or POPSLoader.
- **Effort:** Small. **Risk:** Low — the guard fires only where today the code loops forever.
- **Confidence:** High for USB (probe + connect read in full); Medium for BT impact (probe mitigation noted).

## FAM-04 — Launchstation APA retains the SDK error-sector defects RiptOPL removed: NULL-deref, cache leak, and a write into the APA table sector
- **Category:** 1, 3, 6, 7
- **Locations:**
  - Launchstation `iop/ps2hdd_osd/apa.c:43-48` — `apaSetPartErrorSector`: `clink = apaCacheAlloc();`
    with **no NULL check**, then `apaSaveError(device, clink->header, …)` dereferences it.
  - Launchstation `iop/ps2hdd_osd/apa.c:35-41` — `apaSaveError` memsets and **writes** the buffer
    to LBA 6/7 (`APA_SECTOR_PART_ERROR`).
  - Launchstation `iop/ps2hdd_osd/apa.c:56-60` — `apaGetPartErrorSector`: on
    `blkIoDmaTransfer` failure it `return -EIO` **without `apaCacheFree(clink)`** (leak per failed read).
  - Launchstation `iop/ps2hdd_osd/apa.c:515-520` (chain walk in `apaGetNextHeader` region):
    on `start != prev` it **rewrites `prev`, marks dirty and flushes** — a partition-table write
    triggered by merely listing/opening partitions.
  - RiptOPL contrast: `modules/hdd/apa/src/apa.c:35-50` (error records no longer written at all;
    comment explains LBA 6/7 sit inside the APA table's physical sector on 512e drives, and the
    NULL-deref), `:61-64` (`apaCacheFree` on the failed-read path), `:519-523` (report, never repair).
  - The stripped Launchstation `iop/hdl_info/apa.c` (320 lines) contains the same `apaSaveError`/`apaSetPartErrorSector` pair.
- **Problem:** Three distinct stock defects survive only in Launchstation: a NULL deref exactly
  when the cache is exhausted (i.e. under memory pressure, during an error path), a cache-entry
  leak on every failed error-sector read, and error/repair writes into the partition-table
  sector issued from read paths — the class of write that can brick an APA disk's table if
  power drops mid-flush.
- **Fix in words:** Port RiptOPL's three changes, in its own minimal form: stop writing error
  records (log instead), free the cache entry on the read-failure return, and make the
  `prev`-mismatch path log-only. No new features; Launchstation's own format/create code is untouched by this fix.
- **Benefit:** Removes a crash, a leak, and an unrequested on-disk write from Launchstation's HDD stack in one aligned pass.
- **Effort:** Small. **Risk:** Low — RiptOPL already ships exactly this behaviour.
- **Confidence:** High — both versions read line-by-line; RiptOPL's comments name each defect.

## FAM-05 — Launchstation `hdd_fio.c`: u32 `sector + size` overflow and unbounded on-disk `nsub`
- **Category:** 1, 3, 5, 7
- **Locations:**
  - Launchstation `iop/ps2hdd_osd/hdd_fio.c:277` — `if (fileSlot->parts[arg->sub].length < arg->sector + arg->size)`
    (u32 sum wraps), transfer then addressed at `parts[sub].start + arg->sector` (:280-282).
    RiptOPL fixed form: `modules/hdd/apa/src/hdd_fio.c:286-289` (subtraction-form check, comment
    explains the wrap "addressed start + sector modulo 2^32 — anywhere on the disk").
  - Launchstation `iop/ps2hdd_osd/hdd_fio.c:721` — `for (int i = 0; i < clink->header->nsub; i++)`
    summing `subs[i].length` with `nsub` taken straight from disk; the open path copies
    `fileSlot->nsub = clink->header->nsub` (:473) likewise unbounded.
    RiptOPL fixed forms: `modules/hdd/apa/src/hdd_fio.c:496-503` (refuse `nsub > APA_MAXSUB` at open)
    and `:757` (loop clamped to `APA_MAXSUB`). `APA_MAXSUB` is 64 (the `subs` array size).
  - Also divergent by design (not counted as defects): RiptOPL refuses format / create / delete /
    rename / raw-LBA-write outright (`hdd_fio.c:344-348, 491-492, 626-630, 849-852, 1181-1184`);
    Launchstation keeps them live, which is correct for a file manager — the two checks above
    are the parts that are wrong in both programs' terms.
- **Problem:** A crafted ioctl2 read/write request whose `sector + size` wraps past 2^32 passes
  Launchstation's bounds check and transfers at a wrapped LBA inside (or outside) the partition;
  a corrupt partition header claiming `nsub > 64` makes stat/open walk past the 64-entry `subs`
  array into adjacent header fields.
- **Fix in words:** Adopt RiptOPL's subtraction-form range check at :277 and the
  `nsub > APA_MAXSUB` refusal + loop clamp, verbatim in spirit; keep Launchstation's write features.
- **Benefit:** Closes an arbitrary-sector transfer and an OOB header walk in the one repo that exposes HDD management to the user.
- **Effort:** Small. **Risk:** Low — only rejects values that are corrupt by construction.
- **Confidence:** High.

## FAM-06 — POPSLoader `ata_bd_fast`: LBA48 chunk counted in a `u16` — requests over 65536 sectors never advance
- **Category:** 2 (livelock), 4, 7
- **Locations:**
  - POPSLoader `iop/ata_bd_fast/ps2atad.c:1050` — `len = (u16)((nsectors > 65536) ? 65536 : nsectors);`
    (65536 truncates to **0**), then `:1081` `sceAtaExecCmd(buf, len, 0, len, …)`,
    `:1103` `buf += len * 512`, `:1105` `nsectors -= len` — with `len == 0` the `while (nsectors > 0)`
    loop re-issues the same transfer forever (the ATA count register's "0 means 65536" makes the
    transfer itself succeed, so nothing breaks the loop).
  - FIXED in both siblings by keeping a separate `u32 chunk`: Launchstation
    `iop/ata_bd/src/ps2atad.c:1052-1053, 1107-1109`; RiptOPL `modules/hdd/atad/src/ps2atad.c` (same `chunk` form).
  - POPSLoader's own additions in this file (phantom-slave wait caps, `devinfo[1].exists = 0`)
    are unrelated and unaffected.
- **Problem:** Any single ATA request larger than 65536 sectors (32 MiB) on an LBA48 drive
  livelocks the IOP transfer loop in POPSLoader's "fast" atad — precisely the large sequential
  transfers a loader issues. Below that size the file is byte-for-byte equivalent in behaviour
  to its siblings, which is why the regression hides.
- **Fix in words:** Introduce the siblings' `u32 chunk` variable: count progress in `chunk`,
  pass `(u16)chunk` only to the sector-count register — a 3-line change copied from Launchstation's copy.
- **Benefit:** Removes a hard hang on >32 MiB transfers from POPSLoader's HDD path.
- **Effort:** Trivial. **Risk:** None — restores the other two copies' proven arithmetic.
- **Confidence:** High — all three copies' transfer loops read side by side.

## FAM-07 — Launchstation + POPSLoader atad: no LBA range check and no 4Kn refusal (RiptOPL-only guards)
- **Category:** 3, 5, 7
- **Locations:**
  - RiptOPL only: `modules/hdd/atad/src/ps2atad.c:1035-1060` (`ata_identify_logical_sector_size`,
    `ata_request_in_range`), enforced at `:1068-1077`; plus the BDM APA-reserved-area write
    refusal at `:1599-1627`. Neither Launchstation `iop/ata_bd/src/ps2atad.c` nor POPSLoader
    `iop/ata_bd_fast/ps2atad.c` contains any equivalent (full `diff -w -B` against both).
- **Problem:** On a non-LBA48 drive, a request at LBA ≥ 2^28 has its top bits silently dropped
  by the 28-bit taskfile in the Launchstation/POPSLoader drivers and lands at the start of the
  disk; a 4Kn (4096-byte logical sector) drive is treated as 512-byte throughout, so every
  transfer is mis-scaled 8×. Only corrupt metadata or a stray caller reaches these paths —
  but APA/PFS metadata is exactly what these drivers exist to serve.
- **Fix in words:** Port RiptOPL's two small static helpers and their single call-site check;
  do **not** port the APA-reserved BDM refusal to Launchstation (it is a file manager and
  legitimately writes there) — range + sector-size checks only.
- **Benefit:** Both other HDD stacks stop silently mis-addressing on oversized/corrupt requests.
- **Effort:** Small–medium. **Risk:** Low — refusal only for requests that cannot be represented.
- **Confidence:** High on the divergence; Medium on field frequency (needs corrupt metadata or a >2^28 non-LBA48 request).

## FAM-08 — ps2ips RPC: the two copies fixed opposite halves — each still carries the other's bugs
- **Category:** 1, 3, 6, 7 — **the clearest two-way divergence in the audit**
- **Locations:**
  - Fixed in RiptOPL only (`modules/network/ps2ips/ps2ips.c`): the 144-byte `rests_pkt` DMA into
    the EE's 128-byte `_intr_data[32]` buffer, which overwrites the first four EE socket
    function pointers (`:45-77` analysis, `RESTS_DMA_MAX 128`, `rests_fit()` at :69;
    DMA size capped at :253 and :381); peek-then-fit receive so TCP streams no longer lose
    up to 15 tail bytes (:183-193, :312-317); `do_recvfrom` request fields saved to locals
    before the reply's sockaddr copy can clobber them (:273-294).
    Launchstation still does `sifdma.size = sizeof(rests_pkt);` at `iop/ps2ips_rpc/ps2ips.c:208`
    and `:308`, with a plain single `recv`/`recvfrom`.
  - Fixed in Launchstation only (`iop/ps2ips_rpc/ps2ips.c`): `addrlen` initialised and `addr`
    zeroed in accept/getsockname/getpeername (:59-61, :461, :479) — RiptOPL passes an
    **uninitialised** `addrlen` to `accept`/`getsockname`/`getpeername`
    (`modules/network/ps2ips/ps2ips.c:92,96`, `:531,535`, `:547,551`);
    `setsockopt` `optlen` range-checked before `memcpy` (Launchstation :526-530) — RiptOPL
    copies `optlen` bytes from the RPC buffer into a fixed `optval` unchecked
    (`modules/network/ps2ips/ps2ips.c:591-592`);
    `gethostbyname` result NULL/`h_length` checked (Launchstation :544-546) — RiptOPL checks
    only `!= NULL` (:606). Launchstation also completes the recvfrom aliasing fix differently
    (sockaddr copied only after DMA completes, :314-317) but without the size cap.
  - SMS has no ps2ips copy; POPSLoader/RiptOPL ship the same binary ps2ip.irx (Family 5), whose
    source state cannot be assigned to either tree from the clones.
- **Problem:** Neither shipping copy is safe: Launchstation's IOP still DMAs 16 bytes over the
  EE's socket dispatch table on every receive with an unaligned tail (per RiptOPL's in-tree
  analysis: close() then silently skips the IOP call, lwIP sockets leak, and the UDP PCB pool
  exhausts after repeated operations); RiptOPL's IOP still feeds lwIP an uninitialised
  `addrlen` (a garbage value < 16 truncates the returned address) and an EE-controlled
  `optlen` into a stack `memcpy` in `setsockopt`.
- **Fix in words:** Merge the two fix sets — they touch disjoint functions. Take RiptOPL's
  rests-size/peek/locals changes and Launchstation's addrlen-init, optlen check and
  gethostbyname checks into **both** trees, then keep the trees identical for this file.
- **Benefit:** One file, two repos, four distinct memory-safety bugs closed; ends the split-brain for the socket RPC layer.
- **Effort:** Medium (one careful merge per repo). **Risk:** Medium — receive-path behaviour changes; needs a network smoke test on hardware.
- **Confidence:** High — every cited line read in both copies; the DMA overrun mechanism is documented in RiptOPL's own comments and matches Launchstation's uncapped `sifdma.size`.

## FAM-09 — SMS lwIP `ip_frag`: reassembly bitmap is one byte short — fragment ending exactly at `IP_REASS_BUFSIZE` writes out of bounds
- **Category:** 1, 7
- **Locations:**
  - SMS `iop/SMSTCPIP/src/ip_frag.c:89` — `static u8_t ip_reassbitmap[IP_REASS_BUFSIZE / (8 * 8)];`
    with `IP_REASS_BUFSIZE 5760` defined at :80 (→ 90 bytes), while the completeness/update
    logic indexes the byte containing offset+len at :164-170; the length guard at :151 admits
    `offset + len == IP_REASS_BUFSIZE` (index 90 — one past the array).
  - RiptOPL `modules/network/SMSTCPIP/ip_frag.c:97` — same array sized `… / (8 * 8) + 1`,
    with a comment stating exactly this: "a fragment may end exactly at IP_REASS_BUFSIZE, and
    the update and the completeness check below both touch the byte that end falls in".
- **Problem:** A fragmented IP datagram whose final fragment ends exactly at 5760 bytes of
  payload causes a 1-byte read-modify-write past a static buffer in SMS's IOP network stack —
  remote-triggerable (any fragmented traffic), small but real memory corruption next to
  `ip_reassbuf` statics.
- **Fix in words:** Add the `+ 1` to the array size in SMS's copy, matching RiptOPL/upstream. One byte of BSS.
- **Benefit:** Closes a network-reachable OOB write in the only lwIP copy SMS ships.
- **Effort:** Trivial. **Risk:** None.
- **Confidence:** High — array size, guard condition and indexing all read; RiptOPL's comment independently confirms the mechanism.

## FAM-10 — SMS `ums_fat`: FAT chain walks never validate the cluster number; BPB FAT-size/count fields unvalidated
- **Category:** 5, 1, 8 (single-copy family — no sibling fix exists to copy)
- **Locations:** SMS `iop/SMSUMS/src/ums_fat.c`:
  - Chain walks `_get_cluster_chain12` :249-293, `_get_cluster_chain16` :295-324,
    `_get_cluster_chain32` :326-355: the next-cluster value from the FAT is used directly to
    compute the next FAT sector (`aCluster / lnIdx`) and stored; no check against the volume's
    data-cluster count (`_data_clusters` :230-232 exists but is only used for FAT-type detection).
    Walks are bounded by the caller's buffer (`aBufSize`), so a cyclic FAT terminates — but a
    corrupt entry pointing past the FAT makes `CacheRead` fetch an arbitrary device sector and
    interpret it as FAT, and `_cluster2sector1216/32` (:234-242) then maps it to an arbitrary data sector.
  - `FATFS_Init` (:1045-1105 region): sector/cluster sizes are whitelist-validated and the
    0xAA55 signature checked — good — but `m_nFATs`, `m_FATSize` (after the FAT32 fallback),
    and `m_RootSize` are not checked for zero; `m_FATSize == 0` collapses
    `m_RootDirStart == m_Start`, so directory reads start at the FAT/BPB area.
  - Contrast (the other FAT family): both FatFs copies validate every cluster
    (`clst < 2 || clst >= fs->n_fatent` — RiptOPL `ff.c:1188,1462`; tarball `ff.c:1145,1419`).
- **Problem:** A malformed or hostile USB stick — SMS's exact input — steers reads to arbitrary
  sectors and can present BPB/FAT bytes as directory entries. Read-only driver, so impact is
  wrong data / crash, not disk corruption; stated accordingly.
- **Fix in words:** In the three chain walks, stop the chain (treat as end/corrupt) when the
  next cluster is `< 2` or `>= _data_clusters() + 2`; in `FATFS_Init`, reject `m_nFATs == 0`
  or resolved `m_FATSize == 0`. ~6 lines, no new machinery.
- **Benefit:** SMS's USB browser stops trusting on-disk cluster numbers blindly, matching the standard the FatFs copies already meet.
- **Effort:** Small. **Risk:** Low — only rejects volumes no valid formatter produces.
- **Confidence:** Medium-High — walks and init read in full; CacheRead's own bounds were not audited (out of family scope), so the end-impact is bounded to "arbitrary sector read within the device".

## FAM-11 — Tarball `bdmfs_fatfs` fs_driver: volume index is the raw ioman unit — cross-device misrouting that RiptOPL's copy fixed
- **Category:** 4, 3, 7
- **Locations:**
  - Tarball `bdmfs_fatfs/src/fs_driver.c:43-50` (name built from `fd->unit`), `:598, :696, :787`
    (`fatfs_fs_driver_get_mounted_bd_from_index(fd->unit)` — the unit **is** the mount index).
  - RiptOPL `modules/bdm/bdmfs_fatfs/src/fs_driver.c`: `fs_driver_resolve_volume()` maps
    (driver name, unit) → mount index by matching `bd->path`, plus `fs_ensure_typed_driver()`
    registering per-path drivers (`mass`, `ata`, …) — absent from the tarball copy
    (1093 vs 849 lines).
- **Problem:** In the tarball stack, two block devices of different transports (e.g. USB `mass0`
  and MX4SIO/ATA) whose ioman units coincide resolve to whichever volume mounted first in
  global order: opens/reads for one device are served from the other's filesystem. This is
  the BDMAssault build POPSLoader embeds for MX4SIO — i.e. the multi-device case is its
  headline use case.
- **Fix in words:** Port RiptOPL's resolve-by-path mapping (and typed-driver registration) into
  the tarball tree, or stop embedding the tarball fs_driver and build POPSLoader's BDMAssault
  from the same BDM source as RiptOPL. LESS-NOT-MORE prefers the second: one fewer copy.
- **Benefit:** MX4SIO + USB multi-device setups stop cross-serving filesystems.
- **Effort:** Medium. **Risk:** Medium — mount-order behaviour changes; needs a two-device hardware test.
- **Confidence:** Medium-High — both indexing schemes read directly; the failure needs ≥2 BDM devices, which is the tarball's stated purpose.

## FAM-12 — Tarball BDM core is the unhardened snapshot: GPT/MBR parsers and block cache lack every RiptOPL guard
- **Category:** 1, 2, 5, 6, 7 (bundle of same-shaped "guard exists in sibling, absent here")
- **Locations (tarball path → defect → RiptOPL fixed location):**
  - `bdm/src/part_driver_gpt.c:69` `entriesPerSector = bd->sectorSize / sizeof(...)` with no
    `<= 0` check (divide-by-zero / `i % 0` trap if a device reports < 128-byte sectors — and
    this bdm has no sector-size refusal, next item); inner loop `:93`
    `for (x = 0; x < entriesPerSector; x++, i++)` has **no `i < partition_count` bound**, and
    scanning stops at the first unused entry.
    → RiptOPL `modules/bdm/src/part_driver_gpt.c:69-94` (zero check, bounded gap-tolerant scan
    clamped to `GPT_MAX_ARRAY_SECTORS 2048` and to the header's entry count).
  - `bdm/src/part_driver_mbr.c` (99 lines): no partition sanity check at all.
    → RiptOPL `modules/bdm/src/part_driver_mbr.c:12-34` (`partitions_sanity_check_mbr`:
    nonzero type with `first_lba == 0` or `>= sectorCount` rejects the disk as a VBR).
  - `bdm/src/bdm.c` (246 lines): `bdm_try_mount` offers **any** sector size to the partition/FAT
    drivers, whose buffers are 512 bytes.
    → RiptOPL `modules/bdm/src/bdm.c:160-181` (refuse `sectorSize != 512` before any driver sees
    the device, with callback notification; also fixes a divide-by-zero in the size print the
    tarball copy avoids only by not printing the size).
  - `libbdm/src/bd_cache.c:160-165` `bd_cache_create`: both `AllocSysMemory` results dereferenced
    unchecked (`c->bd = bd` at :165), and **every** connected device gets a 128 KiB cache.
    → RiptOPL `modules/bdm/libbdm/src/bd_cache.c:208-228` (NULL checks with cleanup,
    `sectorSize != 512` refusal, `CACHED_DEVICES_MAX 2` slot cap so cache allocations cannot
    starve later IOP drivers).
- **Problem:** The copy POPSLoader actually embeds for BDMAssault/MX4SIO traps or corrupts on
  exactly the inputs the maintained copy learned to refuse: GPT disks with entries after a gap
  (silently missing partitions), VBRs misread as MBR disks, non-512-byte-sector devices
  overflowing 512-byte probe buffers, and IOP memory exhaustion when several devices connect.
- **Fix in words:** Re-vendor the tarball's `bdm/`, `libbdm/` and GPT/MBR files from RiptOPL's
  `modules/bdm` tree (they are the same lineage), or drop the tarball copies and build from
  that tree. Do not hand-port guard-by-guard — that is how the copies diverged.
- **Benefit:** POPSLoader's embedded block layer reaches the maintained copy's robustness in one move; three in-tarball duplicates collapse to one source.
- **Effort:** Medium (re-vendor + build). **Risk:** Medium — mount behaviour for gap-GPT and VBR media changes (toward the maintained copy's tested behaviour).
- **Confidence:** High — every guard's presence/absence verified by full-file diff of each pair.

## FAM-13 — Tarball `usbmass_bd` scsi: READ/WRITE(10)-only (silent >2 TiB truncation) and an unbounded TEST UNIT READY loop
- **Category:** 3, 2, 7
- **Locations:**
  - Tarball `usbmass_bd/src/scsi.c` (321 lines): capacity via READ CAPACITY(10) only
    (`scsi_cmd_read_capacity` :94, opcode `0x25`); transfer path carries the in-source
    note that the 32-bit LBA "will only support up to 2TB drives" — requests past that wrap
    the LBA instead of failing.
  - Tarball `usbmass_bd/src/scsi.c:147` — `while ((stat = scsi_cmd_test_unit_ready(bd)) != 0)`
    with no try count, no delay, no NULL-priv (unplug) check: a drive that drops offline spins
    the loop at thread priority forever.
  - FIXED, byte-identical in both maintained copies: RiptOPL `modules/usb/usbmass_bd/src/scsi.c`
    = Launchstation `iop/usbmass_bd/src/scsi.c` (`801e3afeca20b65c`, 440 lines) —
    READ CAPACITY(16) + READ/WRITE(16) dispatch at :149-175, and the bounded ready loop at
    :209-234 (`SCSI_READY_TRIES 1000` × `SCSI_READY_DELAY_US 10000`, defined :18-19, plus
    `scsi == NULL` unplug checks).
- **Problem:** The embedded BDMAssault USB stack silently wraps LBAs on >2 TiB drives (reads
  and **writes** land at the start of the disk) and can spin forever on a drive that goes
  offline during start-up — while the fixed driver already exists, identical, in two repos.
- **Fix in words:** Replace the tarball's `usbmass_bd/src/scsi.c` (and check `usb_mass.c`,
  860 vs the maintained 901 lines) with the RiptOPL/Launchstation version; no new code.
- **Benefit:** >2 TiB USB drives stop being a silent-corruption hazard in the BDMAssault build; start-up hangs on flaky drives become a bounded ~10 s give-up.
- **Effort:** Small (file replacement + rebuild). **Risk:** Low — the replacement is already shipping in two repos.
- **Confidence:** High — hashes prove the two maintained copies identical; tarball loop and capacity path read directly.

---

## Summary of identical / diverged state per family

| Family | Copies censused | Identical groups | Defect-state verdict |
|---|---|---|---|
| ds34 pademu | 10 driver .c + 4 EE libs | Launch IOP usb ≡ POPS IOP usb (whitespace); Launch EE bt ≡ POPS EE bt (bytes) | **Worst divergence** — 3 different defects, each fixed in a different minority of copies (2/10, 1/5, 2/5) |
| APA/HDD | 3 apa.c, 2 cache.c, 2 hdd_fio.c, 3 ps2atad.c + siblings | cache.c pair equivalent | One-way: RiptOPL hardened, Launchstock stock, POPS atad has its own livelock (FAM-06) |
| FAT | 2 ff.c + 2 fs_driver + SMS ums set + 2 binary IRXs | none across repos | FatFs pair both validate clusters; SMS ums_fat validates neither clusters nor FAT geometry (FAM-10) |
| Memory card | 6 vmcman + 5 EE/genvmc/mcemu | n/a (no shared fork) | No divergence found; both EE parser sets independently step-bounded |
| TCP/IP | 2 lwIP trees (~60 files each) + 2 ps2ips + binaries | POPS ps2ip.irx ≡ RiptOPL shipped ps2ip.irx (bytes) | Two-way split in ps2ips (FAM-08); SMS lwIP one-byte bitmap bug (FAM-09) |
| BDM | RiptOPL tree vs 3 tarball duplicates + SMS binaries | RiptOPL usbmass ≡ Launchstation usbmass (bytes, both files) | Tarball is a uniformly unhardened snapshot (FAM-11/12/13) |

**Worst defect-state divergence: the ds34 family.** It is the only family where the *same*
defect is simultaneously fixed and unfixed inside the same repo (RiptOPL's pademu copies carry
the battery and endpoint guards its own IOP copies lack), where a second defect's only fix
lives in a third repo's copy (POPSLoader IOP ds34bt), and where no single copy contains all
three fixes — so no "copy the good file over" resolution exists; the fixes must be merged.
Runner-up: ps2ips (FAM-08), a clean two-way split with the same merge-only resolution.
