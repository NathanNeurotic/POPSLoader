# Sable — RiptOPL FULL-VERIFICATION phase 2 — Worker W8

- **Worker:** W8 (adversarial verification; findings survive only if the code at the pin proves them)
- **Repo / pin:** RiptOPL, `rebuild/main` @ `2e347d5ac885cd0ff73e9ad4143781946396f492`
- **Clone:** `~/workspace/audit-clones-2026-11-13/RiptOPL` — `git rev-parse HEAD` == pin at start **and** end; `git status --porcelain` empty at end. Read-only held; no edits.
- **Assigned:** 60 findings (RIPTOPL-426, 427, 453, 470–472, 474–499, 512, 514, 515, 517–530 from ROUND9-MODULES; RIPTOPL-500, 502, 503, 506–511 from ROUND9-THIRDPARTY-A; RIPTOPL-600, 601 from ROUND9-THIRDPARTY-B). Every one verified, no sampling.
- **Tallies (counted from the table below):** VERIFIED 53 · VERIFIED-DRIFT 5 · WEAKENED 2 · REFUTED 0

## Verdict table

| ID | VERDICT | Basis (path:lines / measurement) |
|---|---|---|
| RIPTOPL-426 | VERIFIED-DRIFT | Core holds: `api_lib.c:157` sem=NULL, unguarded waits `api_lib.c:539,563`, accept creates sem `api_msg.c:259`; corrected: `sys_arch.h:10` (not :11), `sys.h:80` (not :82), `TCP_SND_BUF (TCP_MSS*2)` at `include/lwipopts.h:174` (not :202) |
| RIPTOPL-427 | VERIFIED | `modules/iopcore/cdvdman/dev9.c:307-308` empty `while (dev9_chan->chcr & DMAC_CHCR_TR) {}` under `dma_lock_sem`, no timeout |
| RIPTOPL-453 | VERIFIED | `smap_udpbd/src/xfer.c:202-217` unbounded `while (HandleTxReqs(...) < 0) DelayThread(100);` then `return 0`; sibling `udpfs_smap/src/xfer.c:253-279` has 2 s init wait + `return -1` |
| RIPTOPL-470 | VERIFIED-DRIFT | 8 stub slots confirmed in `SMSTCPIP/exports.tab` (select/ioctl/getpeername/getsockname/getsockopt/setconfig/getconfig/netif_find), `FULL_LWIP ?= 0` Makefile:8; corrected: stub body `ps2ip.c:268-271` (not :274-277), ps2ips dispatchers at `ps2ips.c:468,475,482,515,526,542,558` (not :562-637) |
| RIPTOPL-471 | VERIFIED | `fs_driver.c:198-238` pool of 8, no typed `DelDrv` on disconnect; `fs_driver.c:1089` `InitFS` zeroes count without unregistering typed drivers |
| RIPTOPL-472 | VERIFIED | `sbp2_driver.c:18-19` MAX_DEVICES 5 vs `scsi.c:92-93` NUM_DEVICES 2, both copies (assault `scsi.c:80-81`); `scsi_connect` fail → `-3` at `sbp2_driver.c:267-268`; retry limit/back-off `sbp2_driver.c:370-380,571-585` |
| RIPTOPL-474 | VERIFIED | `mcemu_io.c:31` every port `dbufp = &mcdatabuf[0]`; single `mcemu_var.c:62` `u8 mcdatabuf[0x200]` "Same buffer for both cards" |
| RIPTOPL-475 | VERIFIED | `fs_driver.c:83-117` single global `_fs_lock` (16 `_fs_lock()` call sites, held across I/O); FatFs reentrant per-volume in `ffconf.h:295` / `ffsystem.c:37` |
| RIPTOPL-476 | VERIFIED | `apa/Makefile:8` `-DAPA_OSD_VER`; `apa-opt.h:31-38` passwords only in non-OSD branch; stub `password.c:25-35`, full DES `password.c:37-498`; executed via `hdd_fio.c:182,191` |
| RIPTOPL-477 | VERIFIED | `smb_ReadCD` and `smb_CloseAll` bodies extracted and byte-identical in `smb.c:1149,1154`, `smb2.c:1127,1132`, `nfs.c:336,341` |
| RIPTOPL-478 | VERIFIED | md5 `ioplib.c` both `14acaf5b…`, `ioplib.h` both `497aa355…`; `sio2man_hook.c` 318 vs 315 lines, diff = 3-line `#if 0` mx4sio block |
| RIPTOPL-479 | VERIFIED | `arp_add_entry` only at definition `smap_udpbd/src/ministack.c:120` + header `ministack.h:235`, zero callers; `handle_rx_arp` never calls it; no `arp_lookup` in this copy |
| RIPTOPL-480 | VERIFIED | `exports.tab` md5 `9c3ae0a9…` and `main.c` md5 `0ebbaea6…` identical in udpfs_bd/udpfs_ioman; `fhi_size/read/write/init` defined nowhere; no bd/ioman build defines `FEATURE_UDPFS_FHI` (only the fhi target, `ps2.yaml:272`) |
| RIPTOPL-481 | VERIFIED | `udprdma_inform` (`udpfs_shared/src/udprdma.c:533`) zero callers tree-wide; `udpfs_core_exit`/`udprdma_destroy` reachable only via `udpfs_ioman.c:164` |
| RIPTOPL-482 | VERIFIED-DRIFT | All items confirmed (loopif 113+39 lines not in Makefile, `LWIP_HAVE_LOOPIF 0`; dhcp.h 212 lines, no dhcp.c; raw.h + `memp.c` RAW pool, `LWIP_RAW` never defined; `do_accept` never posted; debug-only lookups); corrected: the "nine declarations" list actually names **11** symbols — all 11 verified undefined in any `.c` |
| RIPTOPL-483 | VERIFIED | Call census of `smb2man/*.c` (excl. vendored file) shows no `usmb2_negotiateprotocol/init_context/open/opendir/readdir/size`; `nfsman` never calls `unfs4_init_context` (`unfs4.c:884`); TINY_TCP blocks present, `USMB2_FEATURE_OPENDIR` undefined |
| RIPTOPL-484 | VERIFIED | `cdvdman/smb.h:501` `smb_SessionSetupTreeConnect` — repo-wide grep: declaration only, no definition/caller |
| RIPTOPL-485 | VERIFIED | `smbman-ra/smb.h` carries exactly 44 `SMB_OFFSET_*`/`SMB_TRANS2_*` defines, zero uses in `smbman-ra/*.c`; sampled unused `SMB_COM_*` values also zero-referenced |
| RIPTOPL-486 | VERIFIED | Five assault files total exactly 244 lines (74+32+30+73+35); assault `Makefile` pattern rules compile only `%.c` from wrapper `src/`; nested `iLinkman/src/imports.lst:1-4` still has `cdvdman_IMPORTS` (`I_sceCdRI/RM`); `_funcret` before table in nested `exports.tab:1` vs after in built `src/exports.tab:30` |
| RIPTOPL-487 | VERIFIED | `DeinitIEEE1394` defined `sbp2_driver.c:802` (assault :775), declared `src/include/sbp2_disk.h:180`, zero callers; phantom `PHTSendResponse`/`iLinkIntrRegister0Handler` at `iLink_internal.h:315,322` both copies; dead fields `sbp2_disk.h:144,157-159`; broken `PACKET_TCODE` macro `iLink_internal.h:92`; dead event bits `sbp2_disk.h:25,26,28` |
| RIPTOPL-488 | VERIFIED | Word-exact greps: every listed stub (9 IEEE1394_bd + 2 iLinkman + 3 assault + `I_memcpy` pccf) has zero call sites in its own module's `.c` files (assault's live call is `ClearEventFlag`, not the imported `iClearEventFlag`) |
| RIPTOPL-489 | VERIFIED | `xhdd/ata_identify.h` = 407 lines; sole consumer `xhdd.c:17,79` — only `UltraDMASupport` ever read |
| RIPTOPL-490 | VERIFIED | `fs_driver.c:305-309`: `MAX_FILES 128` FIL + `MAX_DIRS 16` DIR static pools; mount cap 10 volumes (original's byte estimate is INFERRED, as it states) |
| RIPTOPL-491 | VERIFIED | `pccf_ata.c:6` file-static `identify[512]` (attach-only) and `pccf_ata.c:230` function-static `verify[512]` (write-only path) both resident |
| RIPTOPL-492 | WEAKENED | Holds only as conditional source weight: `crc[512]` at `mx4sio.h:46` exists under `#ifdef CONFIG_USE_CRC16`, but that macro is **never enabled** — its only define is commented out (`mx4sio.h:37`) and no Makefile/ps2.yaml defines it, so no 1 KiB is reserved in the shipped build |
| RIPTOPL-493 | VERIFIED | `apa/Makefile:11` links `hdd_blkio.o`, `:8` defines `APA_USE_ATAD` only; all `hdd_blkio.c` content under `APA_USE_BDM`/`APA_USE_IOMANX`/`#ifndef APA_USE_ATAD` guards (:17,178,295,298,308) — empty TU in shipped build |
| RIPTOPL-494 | VERIFIED | `isofs/lz4.h` 248 lines declaring full API (incl. `LZ4_decompress_safe` :62); `lz4.c` 506 lines implements only `LZ4_decompress_generic` + `LZ4_decompress_fast` (:500) |
| RIPTOPL-495 | VERIFIED | `usbd-ra/include/usbd.h:294-296` declares `sceUsbdGetReportDescriptor`/`sceUsbdMultiIsochronousTransfer` ("these aren't implemented"); no matching exports in `usbd-ra/src/exports.tab` |
| RIPTOPL-496 | VERIFIED | `usbmass_bd/src/scsi.c:196-197` get_max_lun result used only by debug print; implementation `usb_mass.c:329-357`, assignment :847; CBW LUN hardcoded `usb_mass.c:482` `ucmd.cbw.lun = 0` |
| RIPTOPL-497 | VERIFIED | `tx_done_ev` only at `smap_udpbd/src/xfer.c:12,56` (create, never waited/read); `CopyFromFIFO` only at definition `xfer.c:80`, zero callers |
| RIPTOPL-498 | VERIFIED-DRIFT | Substance holds (single call site always passes 1; `!read` branches exist); corrected: definition `rapull.c:250` (not :406), `!read` branch at `rapull.c:~305` plus `read &&` guard :259 (not :459-474), sole call `rapull.c:353` (not :507-511) |
| RIPTOPL-499 | VERIFIED | `ra_disc_us` at `raudp.c:771` declaration, writes only :875,924-925 (with saturation guard); zero reads anywhere |
| RIPTOPL-512 | VERIFIED | `udpfs_ministack/Makefile` `IOP_OBJS` omits `ministack_xchg.o`; `src/main.c:12,69` declares/calls `mstack_xchg_init()`; `ps2.yaml:239` does list `ministack_xchg.c` |
| RIPTOPL-514 | VERIFIED | `cdvdfsv.c:184-185` both versions hardcoded `0x223`; `cdvdman.c:125` `CDVDMAN_MODULE_VERSION 0x225`, returned at :891 |
| RIPTOPL-515 | VERIFIED | `smb_fio.c:312-314`: `p2 = &path[strlen(path)]` points at NUL, scan never executes; copy loop `p <= p2` copies the NUL |
| RIPTOPL-517 | VERIFIED | `ff.c:26` `#include "module_debug.h"` + `ff.c:3521-3523` debug hook in `mount_volume`; `bdmfs_fatfs/ORIGIN.txt` local-changes list has exactly 5 items, none is this hook |
| RIPTOPL-518 | VERIFIED | `mount_status` only at `fs_driver.h:11`, never read/written; `MS_BASIC_DATA_PARTITION_GUID` + all GPT attr macros except `GPT_PART_ATTR_IGNORE` (`part_driver_gpt.c:153`) unused |
| RIPTOPL-519 | VERIFIED | `part_driver.c:46-90`: `part_read`/`part_write` share verbatim NULL check, bounds check and DEBUG block, differing only in forwarding call (and the comment sentence above the check) |
| RIPTOPL-520 | VERIFIED | `ffconf.h:87` `FF_CODE_PAGE 869`; `ff.c:597-599` compiles `ExCvt` from `TBL_CT869`, `ffunicode.c` compiles `uc869` |
| RIPTOPL-521 | VERIFIED | `xhdd.h:2,4` declares `ata_device_set_write_cache`/`hdproata_device_set_write_cache`; no definition/caller in `modules/hdd/` (the like-named definition is in cdvdman, as the finding states) |
| RIPTOPL-522 | VERIFIED | `time_us` chain complete and unread: field `pccf_ata.h:17`, definition `pccf_hw.c:194`, sole assignment `pccf_hw.c:294`, zero reads in `modules/pccf/` |
| RIPTOPL-523 | VERIFIED | `pcdiag_ata_observe` prototype `pcdiag_ata.h:20-21` + `PCDIAG_ATA_READ_LIMIT` :6 — repo-wide grep: no definition, no caller, no other reference |
| RIPTOPL-524 | VERIFIED | `modules/pccf/format.inc` = 57 lines; repo-wide grep for `format.inc`/`format_line` returns only the file itself; `pccf/Makefile:18` wildcard makes every object depend on it |
| RIPTOPL-525 | VERIFIED | Directory census: 9 `.irx.*` files, no `usbd.irx.mx4sio`; `PROVENANCE.md:24-25` dedupe sentence names it; re-vendor note says "eighth file"; ilink half true — md5 `a77650a0…` for both `usbd.irx.ilink` and `usbd.irx.usbexfat`, table sha256 recomputed and matching |
| RIPTOPL-526 | VERIFIED | `modules/debug/drvtif.irx` and `drvtif-ingame.irx` both 5,985 B, md5 `838e4e7adf1a3207b049fdcd0b84d046`; tifinet pair same size but different md5s (`f212f485…` / `6c52a13f…`) |
| RIPTOPL-527 | VERIFIED | `bdmevent/irx_imports.h` includes iomanX/stdio/sysclib/sysmem; `main.c` (88 lines) calls only `bdm_*`, `sceSif*` (+ loadcore macros); `imports.lst` correctly lists only bdm + sifcmd |
| RIPTOPL-528 | VERIFIED | `udpfs_fhi/ORIGIN.txt:19` "No write export" vs `exports.tab` slot [6] `DECLARE_EXPORT(udpfs_fhi_write)` and full implementation `udpfs_fhi.c:58-74` |
| RIPTOPL-529 | VERIFIED-DRIFT | All three limits are in-tree TODOs; corrected rapull locations: header TODOs `rapull.c:23-28` (not :179-185), scratchpad TODO `rapull.c:114` (not :268-273); rapops TODOs at `rapops.c:111-112,124-125` as cited |
| RIPTOPL-530 | WEAKENED | Two of three items hold (`JMP` macro `f2techioppatch/main.c:18` unused; `dummy_fs` `imgdrv.c:13-16` referenced only in commented block :73-81), but the atad claim is half wrong: only `ATA_C_STANDBY_IMMEDIATE` is duplicated in `atad.c:92` — `ATA_C_FLUSH_CACHE` appears **once** (the next entry is the distinct `ATA_C_FLUSH_CACHE_EXT`) |
| RIPTOPL-500 | VERIFIED | `test_korium_builtin_assets.py` exists; grep for `test_korium` over `.github/workflows/`, `tools/`, `Makefile` = zero; `flavours.yml` enumerated list + `test_ripps2_*`/`test_ilink_*` globs do not match it |
| RIPTOPL-502 | VERIFIED | `test_mbedtls_vendor.py` tree check = README/`3.6.7`/any-64-hex regex/LICENSE/two generated files/SPDX heads only; its sole `hashlib` use hashes the ca-roots DERs, never any `library/` or `include/` file; README:13 claims "byte-for-byte" |
| RIPTOPL-503 | VERIFIED | `orbit-neutrino/README.md:13-15` "One file is replaced"; `tools/package_edition.py:172-186` loop replaces both `IEEE1394_bd_mini.irx` and `iLinkman.irx` with digest checks; generated `RA-EDITION-NEUTRINO.txt` (:64-67) names both |
| RIPTOPL-506 | VERIFIED | `ps2sdk-socket/README.md:5-7` present-tense compat-archive claims vs `UPSTREAM:4-6` "retired… no fallback archive is linked", `docs/NATIVE-SDK-SOCKETS.md:10`, `build_edition.py` comment |
| RIPTOPL-507 | VERIFIED | `korium/README.md:8` "Korium and RetroAchievements builds"; `build_edition.py:19-35` theme=korium for korium/ra/lite/lite_ra, theme=incebtion for ra_incebtion; `assets.py` branches on `RIPTOPL_THEME` |
| RIPTOPL-508 | VERIFIED | `hkdf.c:9` guard, 161 lines; zero callers of `mbedtls_hkdf*` in any other `library/*.c` (whole-library grep); TLS 1.3 uses PSA (`ssl_tls13_keys.c`); `config_adjust_psa_from_legacy.h:121-130` define→`PSA_WANT_ALG_HKDF*` chain confirmed. Basis: grep + archive pull semantics (INFERRED, as in original — no PS2 link map in this VM) |
| RIPTOPL-509 | VERIFIED | `mps_reader.c` 538 lines, sole guard `MBEDTLS_SSL_PROTO_TLS1_3` (:10, defined in RA config); zero `mps_reader`/`mbedtls_mps_reader_*` references in any other library file or header. Basis: grep + pull semantics (INFERRED, as in original) |
| RIPTOPL-510 | VERIFIED | `ps2sdk-ppctty/irx_imports.h` (21 lines) present; staging `build_edition.py:253-257` copies only LICENSE/UPSTREAM, test `test_ps2build_configurations.py:107-108` asserts only those two; no build/include reference to the header |
| RIPTOPL-511 | VERIFIED | `library/Makefile` 410 + `library/CMakeLists.txt` 379 + `include/CMakeLists.txt` 22 = 811 lines; `library/Makefile:13-22` fatal-errors without `framework/exported.make` (no `framework/` vendored); zero references in `tools/`, `.github/`, `ps2.yaml` |
| RIPTOPL-600 | VERIFIED | DERs 574 B + 1,422 B = 1,996 B; `assets.py:166,170` RA alone admits every `*.der`; `build_edition.py` `update_channel` returns None for all lite + non-standard configs; Sectigo externs/anchors only under `#ifdef RIPTOPL_UPDATER` (`ratls_ps2.cpp:63-66,251-264`), RA anchors (:208-212) list only GTS×3 + ISRG×2; `ps2.yaml:641` globs `asm/*.c`. Certs re-parsed with openssl: subjects/dates/fingerprints match README, none expired. ELF retention INFERRED, as in original |
| RIPTOPL-601 | VERIFIED | `PSUManager/src/core/CMakeLists.txt:1-13` + `tests/PsuArchiveTests.cpp` 142 lines; no root CMakeLists, no `cmake` in any workflow, `PsuArchiveTests`/`psu-core-tests`/`BUILD_TESTING` zero references outside the vendored tree; sole consumer `verify_psu_with_psumanager.cpp:13` includes the header by relative path, bypassing CMake |

## Reasoning for non-VERIFIED verdicts

### VERIFIED-DRIFT (5)

- **RIPTOPL-426** — Mechanism fully re-derived: client conns get `SYS_SEM_NULL` at creation and no path creates their semaphore, while both write waits are unguarded and the close wait is guarded. Citation drift only: `SYS_SEM_NULL` is at `sys_arch.h:10` (finding: :11), the `WaitSema` macro at `sys.h:80` (finding: :82), and `TCP_SND_BUF` is defined at `include/lwipopts.h:174` as `TCP_MSS * 2` with `TCP_MSS 1460` at :171 — value 2,920 confirmed, line :202 wrong.
- **RIPTOPL-470** — All eight stub slots, the `FULL_LWIP ?= 0` gating, the import lists of smbman-ra/smb2man/nfsman/httpclient, and the ps2ips RPC dispatch all confirmed. Drift: the stub body is at `ps2ip.c:268-271`, not :274-277; the ps2ips dispatchers sit ~90 lines earlier than cited (`do_getconfig` :468, `do_setconfig` :475, `do_select` :482, `do_ioctlsocket` :515, `do_getsockname` :526, `do_getpeername` :542, `do_getsockopt` :558).
- **RIPTOPL-482** — Every component verified individually (loopif, dhcp.h, raw pool, do_accept, debug lookups). The one inaccuracy is internal: the finding says "nine header declarations" but lists eleven symbols (`tcp_rexmit_seg`, `tcpip_callback`, `memp_realloc`, `netbuf_alloc`, `netbuf_data`, `netbuf_chain`, `netbuf_next`, `netconn_err`, `pbuf_ref_chain`, `pbuf_dechain`, `sys_now`). All eleven were grep-verified to have zero definitions in any `.c` in the stack.
- **RIPTOPL-498** — The dead mode is real: `rp_frame_values(int read)` has exactly one call site and it passes `1`; the `read &&` window-loop guard and the `if (!read) addr = 0;` chain branch are the only consumers of the parameter. All cited lines are wrong by ~150: definition `rapull.c:250`, call `rapull.c:353`, `!read` branch in the node loop at ~:305.
- **RIPTOPL-529** — The rapops half is cited exactly (:111-112 DEV9 TODO, :124-125 event-buffer TODO, event address built as 0). The rapull half's lines have moved: the header TODOs are at `rapull.c:23-28` and the `rp_valid`/scratchpad TODO is at `rapull.c:114`, not :179-185 / :268-273. No claim about POPS behaviour is made, matching the original.

### WEAKENED (2)

- **RIPTOPL-492** — The finding's headline ("reserves a 1 KiB CRC table") does not hold for the shipped build. `grep -rn CONFIG_USE_CRC16` over the whole tree returns only: the `#ifdef` sites (`mx4sio.h:45`, `mx4sio.c:42`, `spi_sdcard_driver.c:463`) and a **commented-out** define at `mx4sio.h:37` (`// #define CONFIG_USE_CRC16`). No Makefile, `ps2.yaml`, or header enables it. Narrower truth: `crc[512]` is conditional source text that compiles to nothing in this build — a latent 1 KiB cost *if* CRC16 is ever enabled, not resident IOP RAM today. The finding's own INFERRED hedge ("enablement depends on build defines") resolves against it at the pin.
- **RIPTOPL-530** — The bundle holds only in part. Verified: the `JMP` macro (`f2techioppatch/main.c:18`) is defined and never used in the file, and `dummy_fs` (`imgdrv.c:13-16`) is live-referenced nowhere (its ops-table uses are inside the commented block at :73-81, and one live slot explicitly substitutes `NULL` with a `// dummy_fs` comment). Refuted in part: at `atad.c:92` the table reads `… {ATA_C_STANDBY_IMMEDIATE, 0x1}, {ATA_C_FLUSH_CACHE, 0x01}, {ATA_C_STANDBY_IMMEDIATE, 1}, {ATA_C_FLUSH_CACHE_EXT, 0x01}` — `ATA_C_STANDBY_IMMEDIATE` is duplicated (second entry unreachable, same type value 1), but `ATA_C_FLUSH_CACHE` occurs **once**; the finding apparently misread `FLUSH_CACHE_EXT` as a second `FLUSH_CACHE`. Narrower truth: one unreachable duplicate entry, not two.

### REFUTED (0)

None. No finding was defeated outright; the two WEAKENED verdicts above each retain a true core.

## Incidental candidates (new, not in the assigned set)

- **CANDIDATE-W8-1** — `tools/assets.py:167-168` comment states "RA's lookup needs every root", but the RA anchor table in `src/sources/ratls_ps2.cpp:208-212` uses only five of the seven roots (GTS×3 + ISRG×2); the Sectigo pair is updater-only. The comment asserts the opposite of the code it annotates and is the likely origin of the RIPTOPL-600 embed condition. Doc-only defect, distinct location from RIPTOPL-600's finding (which targets the condition, not this comment).
