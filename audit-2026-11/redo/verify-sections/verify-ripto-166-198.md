# Adversarial verification — RE-RIPTOPL-166 … RE-RIPTOPL-198

- Subject report: `~/workspace/Sable-audit-redo/Redo-RiptOPL.md`
- Clone: `~/workspace/audit-clones-2026-11-13/RiptOPL`, HEAD verified before work: `2e347d5ac885cd0ff73e9ad4143781946396f492` (matches pin). Clone left clean (`git status --porcelain` empty).
- Method: refute-first. Every cited file/line opened; mechanisms re-derived; tree-wide greps run for every "never called / never defined / no caller" claim; censuses (191, 197) re-run by script and reproduced.

## Verdict table

| ID | Verdict | One-line evidence (file:line) |
|---|---|---|
| RE-RIPTOPL-166 | VERIFIED-DRIFT | ASYNC path is dead and bypasses the semaphore — `modules/usb/usbmass_bd/src/usb_mass.c:17,440-453,469,508-538` (cited ranges off) |
| RE-RIPTOPL-167 | VERIFIED-DRIFT | `ip_forward`/`ip_lookup` never compile — `modules/network/SMSTCPIP/ip.c:79-113,139-199`; declaration is at `include/lwip/ip.h:46`, not :57 |
| RE-RIPTOPL-168 | VERIFIED-DRIFT | Dead/broken helpers real — `tools/pc/ziso.py:44-47,369-400`; but README does reference the tool — `README.md:862,872,878` |
| RE-RIPTOPL-169 | VERIFIED-DRIFT | Whole-file dead, zero references — `tools/lang_decompiler.py:1-60`; representer at :4, not :5 |
| RE-RIPTOPL-170 | VERIFIED-DRIFT | Uncalled entry points + unclamped copy — `modules/network/smb2man/usmb2/usmb2.c:792,1031`; opendir/readdir are `#ifdef`-excluded at :743,820, not gc-stripped |
| RE-RIPTOPL-171 | VERIFIED | `modules/iopcore/cdvdman/smb.c:23` (`#define USE_CUSTOM_RECV 1`), dead `#else` at :997-1020 |
| RE-RIPTOPL-172 | VERIFIED | All 12 declarations exact, no definitions in any `.c` — `modules/network/SMSTCPIP/include/lwip/api.h:104-114,155`, `pbuf.h:108,114`, `sys.h:97`, `tcp.h:427,453`, `memp.h:59` |
| RE-RIPTOPL-173 | VERIFIED | No ACK, never posted, bypassed — `modules/network/SMSTCPIP/api_msg.c:664-689,820`, `api_lib.c:383-398` |
| RE-RIPTOPL-174 | VERIFIED | Dead, silently-dropping `#else` — `modules/network/SMSTCPIP/tcpip.c:137-156`, `include/lwip/opt.h:64-65` |
| RE-RIPTOPL-175 | VERIFIED-DRIFT | Both dead — `modules/network/smap_udpbd/src/xfer.c:80,12,56`; benefit overcounts lines (~19, not ~30) |
| RE-RIPTOPL-176 | VERIFIED | Write-only counter + zero heartbeat fields — `modules/network/raudp/raudp.c:771,875,924-925,1171,1174,1177` |
| RE-RIPTOPL-177 | VERIFIED | Write-only variable, hardcoded factor — `modules/iopcore/cdvdman/device-bdm.c:22,106,234,244` (tree census: exactly 2 occurrences) |
| RE-RIPTOPL-178 | VERIFIED | Phantom prototype + 153 defines, TRANS2 group unused — `modules/iopcore/cdvdman/smb.h:501,62-93` |
| RE-RIPTOPL-179 | VERIFIED-DRIFT | Dead `dummy_fs` + unused typedefs — `modules/iopcore/imgdrv/imgdrv.c:13-16,39-58` (cited struct range :39-95 overbroad) |
| RE-RIPTOPL-180 | VERIFIED | CRC16 compiled-but-off; CRC7 test names a nonexistent macro — `modules/mx4sio_bd/src/mx4sio.h:37,45-46`, `mx4sio.c:42-49`, `spi_sdcard_crc7.c:5-45`, `spi_sdcard_driver_config.h:22` |
| RE-RIPTOPL-181 | VERIFIED | Field occurs only in its struct — `modules/bdm/bdmfs_fatfs/src/include/fs_driver.h:11` |
| RE-RIPTOPL-182 | VERIFIED-DRIFT | Four never-defined axes confirmed tree-wide; Makefile defines only the 3 claimed flags — `modules/hdd/atad/Makefile`, `src/ps2atad.c:1458,1485,1361,1399` (two cited ranges off) |
| RE-RIPTOPL-183 | VERIFIED | Broken object-like macro, never used — `modules/ilink/iLinkman/src/include/iLink_internal.h:92` |
| RE-RIPTOPL-184 | VERIFIED | Dead and incomplete deinit — `modules/ilink/IEEE1394_bd/src/sbp2_driver.c:802-807`, `writeBuffer` at :20,93, decl `include/sbp2_disk.h:180` |
| RE-RIPTOPL-185 | VERIFIED-DRIFT | All cited `PORT_NR` blocks inert — `modules/mmce/mmceman/src/sio2man_hook.c:26-29,58-85,115-121,275-281`; one further guard at :44-46 uncited |
| RE-RIPTOPL-186 | VERIFIED | Unincluded formatter + undefined diagnostic entry — `modules/pccf/format.inc` (57 lines), `modules/pccf/pcdiag_ata.h:20-21` |
| RE-RIPTOPL-187 | VERIFIED-DRIFT | Retired trees + present-tense README — `third_party/ps2sdk-socket/UPSTREAM:4-6` vs `README.md:3-7`, `tools/build_edition.py:253-257`; byte figure overstates (11,487 B, not ~21 KB) |
| RE-RIPTOPL-188 | VERIFIED-DRIFT | File dead, contents duplicated inline — `tools/pc/xeRAbora.url:1-2`, `tools/package_edition.py:184`; prescribed dict fix would drop the RA-only gate at :183 |
| RE-RIPTOPL-189 | VERIFIED-DRIFT | All no-op/commented sites real — `src/sources/bdmlaunch.cpp:983,986`, `mmcesupport.cpp:1819`, `bdmsupport.cpp:2156-2157`, `supportbase.cpp:650-665`; autolaunch block is :1735-1741, not :1740-1747 |
| RE-RIPTOPL-190 | VERIFIED | Placeholder only occurs at its definition — `src/ui/menusys.cpp:51-55` |
| RE-RIPTOPL-191 | VERIFIED | Census reproduced exactly: 1,144 literals, same 8 malformed, 13 duplicated IDs — `src/core/vmc_groups.cpp:443-444,464-465,472-473,498,614,665-676` |
| RE-RIPTOPL-192 | VERIFIED | `initialize` returns 1 at every exit; unguarded index — `src/core/pad.cpp:209,235,248,256,296,1049-1052,1136-1146` vs guards at :1002,1036,1063 |
| RE-RIPTOPL-193 | VERIFIED | Stub writes only zeros; HUD displays them — `src/core/sfx.cpp:305-311`, `include/sound.h:28`, call at `src/ui/guioverlay.cpp:203` |
| RE-RIPTOPL-194 | WEAKENED | EE stub is dead but has zero EE callers, and its name/declaration are shared with a live IOP function — `src/platform/httpclient.cpp:157,61` vs `modules/network/common/httpstream.inc:105-112` |
| RE-RIPTOPL-195 | VERIFIED | Orphan comment, no declaration/implementation follows — `include/ioman.h:38-41` |
| RE-RIPTOPL-196 | VERIFIED | Sole occurrence in the whole tree is the declaration — `ee_core/include/padhook.h:25` |
| RE-RIPTOPL-197 | VERIFIED-DRIFT | Census, sizes and all 4 md5s reproduced exactly — `gfx/` (142 files, 443,330 B; 12 files = 29,792 B), `src/gfx/textures.cpp:260-266,299-301,243`; two citation ranges off |
| RE-RIPTOPL-198 | VERIFIED | `LWIP_ARP` defined nowhere; timer compiles out; `etharp_init` uncalled — `modules/network/SMSTCPIP/timers.c:103-125`, `etharp.c:191,209-229`, `include/lwip/opt.h:138` |

## Reasoning for non-VERIFIED verdicts

### RE-RIPTOPL-166 — VERIFIED-DRIFT
Mechanism holds in full. `ASYNC` is never defined: its only "definition" is commented out and no Makefile/ps2.yaml entry defines it (tree grep). The ASYNC half of `usb_queue_cmd` therefore never compiles, and it genuinely bypasses the two-drive fix: `WaitSema(usb_mass_cmd_sema)`/`SignalSema` sit under `#ifndef ASYNC` (`usb_mass.c:468-470,506`), while the ASYNC branch drives the shared static `ucmd` via `sceUsbdBulkTransfer` callbacks — exactly the race `ORIGIN.md` ("one command at a time across both drives", change 1) documents as fixed. The synchronous helpers (`perform_bulk_transfer` :117, `usb_bulk_reset` :218, `usb_bulk_command` :378) are likewise `#ifndef ASYNC`-guarded, so the prescribed fix (delete ASYNC branch + callback, drop the guards) is coherent and LESS-compliant. Benefit ~45 lines is accurate (≈14 lines callback + ≈31 lines queue `#else` + guards).
Citation corrections: `// #define ASYNC` is at **:17**, not :16. `scsi_cmd_callback` is at **:440-453** (guard `#else` at :438), not :445-458. The ASYNC half of `usb_queue_cmd` is at **:508-538**, not :525-556. The TODO about unhandled async errors is at :449 — inside `scsi_cmd_callback`, not inside the `usb_queue_cmd` range the finding attaches it to.

### RE-RIPTOPL-167 — VERIFIED-DRIFT
Mechanism holds. `IP_FORWARD` is 0 in both `include/lwip/opt.h:221-222` and `include/lwipopts.h:230`, and nothing defines it to 1; `ip_forward` (`ip.c:139-199`, 61 lines) and its call site (:262-265) compile out. `LWIP_DEBUG` is defined nowhere in the tree (grep for `#define LWIP_DEBUG` returns only `LWIP_DEBUGF`/`LWIP_DEBUG_TIMERNAMES`), so `ip_lookup` (`ip.c:79-113`, 35 lines) never compiles. Combined ≈96 lines vs the claimed ~95 — accurate. Deleting both is LESS-compliant.
Citation correction: the finding sends the reader to `ip.h:57` for the unconditional `ip_lookup` declaration; the declaration is at **`include/lwip/ip.h:46`** (line 57 is `#define IP_PROTO_ICMP`). The fix note (declaration must go or be guarded with the function) remains correct.

### RE-RIPTOPL-168 — VERIFIED-DRIFT
Core holds. `hexdump` (`tools/pc/ziso.py:44-47`) and `load_sector_table` (:369-400) have no call sites anywhere (grep: definitions only). The Python-3 defect is real: iterating `bytes` yields `int`s, and `ord(int)` raises `TypeError`. The "In future we will support NC" comment is at :370 verbatim, and neither function is wired into `parse_args`/`compress_zso`. `tools/pc/Makefile` builds only `iso2opl`, `opl2iso`, `genvmc` — confirmed. Deleting both functions and keeping the tool is the right, LESS-compliant fix.
Corrections: (1) The claim "no repo file references `ziso.py` (grep-verified)" is **false** — `README.md:862` documents it and :872/:878 give example invocations. The tool is documented and standalone-usable; only the two functions are dead. This does not change the fix (the finding already keeps the tool), but the grep claim must not be repeated. (2) Line counts: the two functions total ≈40 lines including separating blanks (4 + 32 code lines), not 47; cited ranges :44-50 and :369-405 overshoot both function ends.

### RE-RIPTOPL-169 — VERIFIED-DRIFT
Mechanism holds. Tree-wide grep finds zero references to `lang_decompiler` (no Makefile, workflow, doc, or script). The file is exactly 60 lines, runs at import (no `__main__` guard, no arguments) and rewrites `lng_src/*.yml` from `lng/*.lng` as a side effect — the accident hazard is real. The live direction is confirmed at `tools/assets.py:103-118` (`lang()` invoking `tools/lang_compiler.py`). Deletion is LESS-compliant.
Citation correction (1-line shift only): `represent_str` in the decompiler starts at **:4** (body :4-14), cited as :5-15. The compiler copy is at `tools/lang_compiler.py:34-45`, inside the cited :30-40 window.

### RE-RIPTOPL-170 — VERIFIED-DRIFT
Mechanism holds. `ps2.yaml` smb2man target defines exactly the seven `USMB2_FEATURE_*` flags claimed, without OPENDIR, and builds with `-ffunction-sections` + `-Wl,--gc-sections` (`ps2.yaml:169-171`). `smb2man.c`'s call set is as claimed (grep: `usmb2_build_request/close/create/mkdir/pread/pwrite/rename/rmdir/sessionsetup/stat/treeconnect/unlink`; its directory path at `smb2man.c:1254` clamps against `SMB2MAN_DIRBUF`). No caller exists for `usmb2_open/opendir/readdir/size/init_context` (the only external hits are provenance notes; `ps2iop-compat.h:15` even comments "smb2man never calls usmb2_open()"). The hazards are real: `usmb2_readdir` at `usmb2.c:792` does `memcpy(&dh[16+4], &usmb2->buf[8], u32)` where `u32 = le32toh(*(uint32_t *)&usmb2->buf[4])` is reply-controlled, with no clamp against the 252-byte `OutputBufferLength` it requested (:780, `MAX_DIR_SIZE-4`) or the 272-byte directory handle `usmb2_create` allocates (:740); `usmb2_size` returns at :1031 `le64toh(*(uint32_t *)&buf[16])` — a 32-bit read passed through a 64-bit conversion (function defined at :1002, declared `int` in `usmb2.h:91`).
Correction: `usmb2_opendir`/`usmb2_readdir` are not "stripped at link time" — they sit inside `#ifdef USMB2_FEATURE_OPENDIR` (`usmb2.c:743-820`) and are excluded by the preprocessor. The gc-stripped set is `usmb2_open` (:717), `usmb2_size` (:1002), `usmb2_init_context` (:1034) and its internal callee `usmb2_negotiateprotocol` (:504). The conclusion is unchanged and arguably stronger: the readdir hole is exactly one `-D` away, as claimed.

### RE-RIPTOPL-175 — VERIFIED-DRIFT
Mechanism holds. In `smap_udpbd`, `CopyFromFIFO` (`src/xfer.c:80-93`) has no call site (module grep: definition only) and `tx_done_ev` (:12 declaration, :56 `CreateEventFlag`) is never waited on or signalled anywhere. The sibling claim checks out: `udpfs_smap/src/xfer.c` has only `CopyToFIFO` and no `tx_done_ev`. (The other sibling, `smap-ingame/xfer.c:81,204`, does use its own `CopyFromFIFO` — different module, not the one cited.) Deletion is LESS-compliant.
Figure correction: the removable block is ≈19 lines (14 for `CopyFromFIFO` + declaration/creation and its exclusive `event_info` setup), not "~30 dead lines".

### RE-RIPTOPL-179 — VERIFIED-DRIFT
Mechanism holds and is slightly stronger than claimed. `dummy_fs` (`imgdrv.c:13-16`) has no live reference — its name appears only in comments (:66, :70 beside `NULL` entries, and the commented-out ops block :72-82). The private typedefs `_iop_device_tm`/`_iop_device_ops_tm` (:39-58) truncate the ops table at `lseek` (:57) — and they are not merely duplicative, they are **entirely unused**: the file already declares its device with the real types, `iop_device_ops_t my_device_ops` (:62) and `iop_device_t my_device` (:85). The fix therefore reduces to pure deletion, which is even more LESS-compliant than the finding's "declare with the real types" wording.
Citation correction: the private struct definitions span **:39-58**, not :39-95 (the :59-95 span is the live ops table, device, and `_start`); the commented-out block is :72-82, cited as :73-81.

### RE-RIPTOPL-182 — VERIFIED-DRIFT
Mechanism holds. `modules/hdd/atad/Makefile` defines exactly `ATA_USE_DEV9=1`, `ATA_GAMESTAR_WORKAROUND=1`, `ATA_ENABLE_BDM=1` (in `IOP_CFLAGS`), and a tree-wide grep finds no definition of `ATA_USE_AIFDEV9`, `ATA_ALL_PIO_MODES`, `ATA_MWDMA_MODES`, `ATA_SCE_AUTH_HDD`, or `ATA_ENABLE_MAXUDMA` anywhere (no `#define`, no `-D`, no ps2.yaml entry). The dead axes are present as claimed: AIFDEV9 branches throughout (e.g. :33-35, :201-207 incl. the `aif_tune_drive` declaration, :1008-1010), the `ATA_ALL_PIO_MODES` table in `ata_pio_mode` (:1458-1478, live path is the single-value `#else` :1479-1482), `ata_multiword_dma_mode` under `ATA_MWDMA_MODES` (:1485+), `ATA_SCE_AUTH_HDD` at :1399, `ATA_ENABLE_MAXUDMA` at :1361. The file is vendored (pin in `ORIGIN.txt`) and the prescribed fix — document in `ORIGIN.txt`, don't strip blind — is the correct LESS/posture call.
Citation corrections: the include block cited as :29-31 is the DEV9 include at **:30-32** (AIFDEV9 include at :33-35); the range cited as :213-215 for AIFDEV9 is actually the `ata_pio_mode` declaration (:213) and the `ATA_MWDMA_MODES` declaration guard (:214-215).

### RE-RIPTOPL-185 — VERIFIED-DRIFT
Mechanism holds. `PORT_NR`'s only definition is inside `#if 0` with the "Only needed for mx4sio" comment (`sio2man_hook.c:26-29`), so every `#ifdef PORT_NR` block compiles out permanently: the transfer filter and its two wrappers (:58-85), the export-25 hook (:115-117) and relink (:119-121), and the unhook block (:275-281) — all cited ranges exact. Deletion is LESS-compliant.
Completeness correction: one further `PORT_NR`-guarded block is uncited — the `m_25_psio2_transfer` field inside `struct sio2man_hook_data` at **:44-46**. The fix's "every `PORT_NR`-guarded block" wording covers it, but the location list does not.

### RE-RIPTOPL-187 — VERIFIED-DRIFT
Mechanism holds. `third_party/ps2sdk-socket/UPSTREAM:4-6` says the fallback was "retired from build graphs… no fallback archive is linked"; no build file references `socket.c`/`fdman.h`; `tools/build_edition.py:253-257` copies only `LICENSE` and `UPSTREAM` from both trees into kits. `README.md`'s present-tense claim ("Its build compiles `socket`, `bind`, `recvfrom`, `sendto` and `setsockopt` into a separate archive") sits inside the cited :3-7 span and does contradict the `UPSTREAM`. `ps2sdk-ppctty/irx_imports.h` is exactly the cited 21 lines (:1-21), its `UPSTREAM:3-6` says "No bundled driver is built", and nothing includes it. Keeping `LICENSE`/`UPSTREAM` and deleting the three source files is LESS-compliant.
Figure correction: the three files total **11,487 bytes** (`socket.c` 10,018 + `fdman.h` 1,043 + `irx_imports.h` 426), not "~21 KB".

### RE-RIPTOPL-188 — VERIFIED-DRIFT
Mechanism holds. `tools/pc/xeRAbora.url:1-2` contains exactly the two lines that `tools/package_edition.py:184` writes inline (`[InternetShortcut]\nURL=https://github.com/hacan359/xerabora/releases/tag/v1.0.1\n`); the file is referenced nowhere (grep), while the other kit shortcuts are copied from `tools/pc/*.url` by the loop at :181-182 over the dict at :179-180 (4 same-name + the `udpfs-server.url` → `android-udpfs-server.url` rename = the "other five"). The bump-in-the-wrong-place hazard is real.
Fix correction (the prescribed fix as written is wrong): adding `"xeRAbora.url": "xeRAbora.url"` to the unconditional `shortcuts` dict would ship the file in **every** kit, whereas the inline write is gated on `if options["ra"]:` (:183) — and `package_release_app.py:332` requires `xeRAbora.url` specifically in RA packages. The correct LESS fix is to copy from the file **inside the existing RA gate**: `(kit / "xeRAbora.url")` written via `shutil.copyfile(ROOT / "tools/pc/xeRAbora.url", …)` under `if options["ra"]:`, deleting the inline `write_text`.

### RE-RIPTOPL-189 — VERIFIED-DRIFT
All claimed sites verified. `bdmlaunch.cpp:983` (`|= 0 /* TODO! fake ilinkman ? */`) and :986 (MX4SIO `|= 0;`) exact. The commented UNMOUNT_EXCEPTION stubs are exact at `bdmsupport.cpp:2156-2157` and `mmcesupport.cpp:1801-1802`. The MMCE shutdown line is exact at `mmcesupport.cpp:1819` (commented `fileXioDevctl("mass:", USBMASS_DEVCTL_STOP_ALL, …)` under the "required by some HDDs" comment at :1818), and the BDM counterpart is live and gated exactly as claimed (`bdmsupport.cpp:2179-2180`, `if (gDeinitTerminal)`). The `supportbase.cpp` TODO + commented UL size loop is at :650-665, inside the cited :650-668. Deletion plus an explicit STOP_ALL decision is LESS-compliant.
Citation correction: the commented-out autolaunch block in `mmcesupport.cpp` spans **:1735-1741**, not :1740-1747 (lines 1743-1746 after it are live code).

### RE-RIPTOPL-194 — WEAKENED
The guard half holds exactly: `HttpEstabConnection` guards on `HttpIsInitialized()` at `src/platform/httpclient.cpp:42-43`; `HttpSendGetRequest` (:61) has no such guard, and it is the only other `HttpIsInitialized` use in the file. Adding the same one-line guard is sane.
The `HttpStreamEnd` half is materially narrower and its fix is unsafe as worded:
1. The EE function at `src/platform/httpclient.cpp:157-161` is indeed an empty body whose comment states the symmetry rationale — but it has **zero EE callers**, not "a no-op every caller must still call". EE callers use `HttpStreamBegin`/`HttpStreamRead` (e.g. `src/sources/httpsupport.cpp:272,344`) and never call `End` (grep over `src/`: definition only).
2. The name is shared with a **live, non-empty IOP function** of the same name: `modules/network/common/httpstream.inc:105-112` clears the stream state (`live/socket/remaining/stageLen/stageOff`), called from `httpstream.inc:127`, `modules/network/httpclient/main.c:41`, and `modules/iopcore/cdvdman/device-http.c:53`. Both sides share the single declaration at `modules/network/common/httpclient.h:29` (the header the EE file includes). "Delete `HttpStreamEnd` and its call sites" applied without the EE/IOP distinction would delete the IOP teardown and its declaration.
True scope: delete only the EE stub definition in `src/platform/httpclient.cpp` (it has no call sites to remove, and the shared header declaration must stay for the IOP side), plus add the init guard to `HttpSendGetRequest`. That is a smaller, different fix than prescribed.

### RE-RIPTOPL-197 — VERIFIED-DRIFT
Every quantitative claim reproduced by script: `gfx/` = 142 files, 443,330 bytes; default embed = 128 PNGs (104 base in `PNG_ASSETS` + 24 generated glyphs), plus `ra_mark` only under `RIPTOPL_RA=1` and `apps_case` only for the Korium theme, leaving exactly the claimed 14 unembedded-in-default, of which the 12 named files are used by no flavour. All 12 sizes exact (device set 6,185 B; duplicate copies 23,607 B; total 29,792 B). All four md5s match exactly: logo4=logo3 `84eb33a7d0daa1321fd2a07185dc6508`, logo5=logo2 `ca7048eb7168928716e42ee648c05572`, logo6=logo1 `1651f8d83156fabefe580ab610a96636`, no_Rating=Rating_0 `dd241f101796a79a67cd957ea6f6a17d`. The texture table does what is claimed: `DEVICE_1…DEVICE_ALL` and `no_Device` map to `NULL` (`textures.cpp:260-266,242`), `LOGO4/5/6` share `&logo3_png/&logo2_png/&logo1_png` (:299-301) and `NO_RATING_PICTURE` shares `&Rating_0_png` (:243), with comments recording the sharing. Deleting the 12 files while keeping the names/mappings is LESS-compliant and does not affect disk-theme override (themes carry their own PNGs).
Citation corrections: the device-icon comment is at `textures.cpp:258-259` and the `no_Device` comment at :241, not ":269-277". In `tools/assets.py`, `PNG_ASSETS` starts at :46 (cited :49-60) and the flavour additions are at :163-165 (cited :166-171, which is the RA trust-anchor loop).

## Candidates (new defects noticed while verifying — not merged into any verdict)

1. **Same broken CRC7 macro test in the header (extends RE-RIPTOPL-180):** `modules/mx4sio_bd/src/spi_sdcard_crc7.h:10` also tests `SD_CRC7_MODE == CRC7_MODE_RAM_TABLE` (nonexistent macro), so the `crc7_generate_table` extern declaration is compiled out by the same accident as the definition at `spi_sdcard_crc7.c:7`. Finding 180 cites only the `.c`.
2. **Second copy of the broken `PACKET_TCODE` macro (extends RE-RIPTOPL-183):** identical line at `modules/bdmassault/ilink_bd_assault/src/iLinkman/src/include/iLink_internal.h:92`. Deleting only the `modules/ilink` copy leaves the landmine in the assault tree.
3. **Second dead copy of `DeinitIEEE1394` (extends RE-RIPTOPL-184):** definition at `modules/bdmassault/ilink_bd_assault/src/IEEE1394_bd/src/sbp2_driver.c:775`, declaration at its `sbp2_disk.h:180`; likewise uncalled.
4. **Fix-completeness for RE-RIPTOPL-171:** `.github/scripts/test_smb_read_closed.py:64-65` hard-exits if `USE_CUSTOM_RECV` is no longer defined ("update this check"). Deleting the macro as prescribed must update that host test in the same change, or CI goes red.
5. **Guard gap is wider than RE-RIPTOPL-194 states:** in `src/platform/httpclient.cpp`, `HttpStreamBegin` (:95) and `HttpStreamRead` (:128) also lack the `HttpIsInitialized()` guard that `HttpEstabConnection` has — the inconsistency is file-wide, not specific to `HttpSendGetRequest`.
6. **Cross-reference note for RE-RIPTOPL-172:** `pbuf_dechain` is additionally declared as an IOP import at `modules/network/common/smstcpip.h:39-40` (`DECLARE_IMPORT(41, pbuf_dechain)`), i.e. the phantom declaration exists on both sides of the EE/IOP boundary; finding 172 covers only the lwIP header copy.

## Tally

**VERIFIED: 19 · VERIFIED-DRIFT: 13 · WEAKENED: 1 · REFUTED: 0 · BLOCKED-ENV: 0** (33 findings: RE-RIPTOPL-166 … RE-RIPTOPL-198)

No mechanism-level duplicates were found within the range or against bordering/same-file findings (checked RE-RIPTOPL-055 vs 176, RE-RIPTOPL-057 vs 177, RE-RIPTOPL-115/120/234 vs 175, RE-RIPTOPL-159/165 vs 167/172/173/174/198, RE-RIPTOPL-186 vs 226, RE-RIPTOPL-232 vs 166 — all distinct mechanisms).
