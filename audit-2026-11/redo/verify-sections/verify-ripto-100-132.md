# Verification — RE-RIPTOPL-100 through RE-RIPTOPL-132

- Report: `~/workspace/Sable-audit-redo/Redo-RiptOPL.md`
- Clone: `~/workspace/audit-clones-2026-11-13/RiptOPL`, HEAD verified `2e347d5ac885cd0ff73e9ad4143781946396f492` before and after; `git status --porcelain` empty (clone untouched).
- Method: refute-first. Every cited file/function/line opened; mechanisms re-derived; guards, callers, build inclusion and duplicate overlap checked.

## Verdict table

| ID | Verdict | One-line evidence (file:line) |
|---|---|---|
| RE-RIPTOPL-100 | VERIFIED-DRIFT | MINI iso pool real (`modules/usb/usbd-ra/src/usbd.c:50-55`), but slip is at `usbd.c:139`, not :130, and `setupIsocronTransfer` starts at `usbio.c:152`, not :143 |
| RE-RIPTOPL-101 | VERIFIED | Glob at `tools/build_edition.py:114,137`; 109 `.c` files counted; neither config defines server/cache/timing/net/debug modules (`third_party/mbedtls/riptopl_mbedtls_config.h`, `riptopl_mbedtls_slim_config.h`) |
| RE-RIPTOPL-102 | VERIFIED | Doubling realloc loop + 8 MiB cap at `src/gfx/textures.cpp:160,684-700`; exact-size `lseek` fast path at `textures.cpp:641` |
| RE-RIPTOPL-103 | VERIFIED-DRIFT | Header definitions real (`include/utf8.h:21-49`, includers `src/gfx/fntsys.cpp:12`, `src/gfx/textshape.cpp:12`) but the table is 400 entries, not 364 |
| RE-RIPTOPL-104 | VERIFIED | `crctab[0x400]` at `src/platform/system.cpp:465`, only indices 0–255 ever used/filled (:476-487), table rebuilt per call |
| RE-RIPTOPL-105 | VERIFIED | VLAs at `src/ui/gui.cpp:173` (`char tmp[maxLength]`) and `src/ui/diaeditors.cpp:215` (`char pre[maxLen]`) |
| RE-RIPTOPL-106 | VERIFIED | Two 4,096-byte static unions at `modules/pccf/pccf_pio_profile.inc:3`, used only inside `pio_profile` called from `modules/pccf/pccf_hw.c:295` |
| RE-RIPTOPL-107 | VERIFIED | Scripted recount exact: 137 files / 5,918,101 B total, 23 consumed / 1,752,047 B, remainder 4,166,054 B, Neutrino subtree 78 files / 603,340 B (`ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/version.txt` = `v1.8.0-61-g7be8de2`) |
| RE-RIPTOPL-108 | VERIFIED-DRIFT | File line counts exact (1425/1719/616/998) and `smsutils.S` md5 identical, but diff outputs are 785 and 834 lines, not 915 and 950 |
| RE-RIPTOPL-109 | VERIFIED | All `wc`/`diff` figures exact: MD4 175/182/240, DES 564/568 with 119-line diff, auth diff 113 lines (`modules/network/smbinit/`, `smbman-ra/`, `smb2man/usmb2/md4c.c`) |
| RE-RIPTOPL-110 | VERIFIED-DRIFT | Six launch copies real, but censuses are inflated and the BDM per-part loop is not the identical-comment loop shared by ETH/MMCE |
| RE-RIPTOPL-111 | VERIFIED | Five PS1 launch copies at the cited sites (e.g. `src/sources/hddsupport.cpp:2161,2237,2308,3223`); FAV proxy at `src/sources/favsupport.cpp:1290-1330` |
| RE-RIPTOPL-112 | VERIFIED | `diff -rq modules/bdmassault/ilink_bd_assault/src modules/ilink` shows divergence in `scsi.c`, `sbp2_driver.c`, `iLink.c`, `iLink_DMA.c`, `iLink_PHY.c` and more |
| RE-RIPTOPL-113 | VERIFIED | Bodies 93 vs 84 lines (`src/app/opl.cpp:1278-1370,1372-1455`); only differences are signature, spared-mode loop vs `deinitAllSupport` (`opl.cpp:607`), and `launchDiagMark(7)/(8)` |
| RE-RIPTOPL-114 | VERIFIED | `md5sum`: five protocol headers byte-identical ×3 editions; `mprintf.h` identical in 5 of 6 locations (differing copy is `smap_udpbd`); `udpfs_bd`/`udpfs_ioman` `main.c` md5-identical |
| RE-RIPTOPL-115 | VERIFIED | SMAP `diff` = exactly 25 lines (639 vs 641 lines); `udptty.c` 89 lines each, diff = 1 include; `parse_ip` bodies identical at `udpfs_ministack/src/main.c:18` / `smap_udpbd/src/main.c:19` |
| RE-RIPTOPL-116 | VERIFIED | Walker duplicated at `modules/iopcore/cdvdman/searchfile.c:25-240` and `modules/isofs/isofs.c:187-380`; `dirTocEntry` defined at `cdvdman/internal.h:96` and `isofs.c:19`; precedent `../../isofs/zso.o` in cdvdman `Makefile:1` |
| RE-RIPTOPL-117 | VERIFIED | `mmce_fs_remove/mkdir/rmdir` at `modules/mmce/mmceman/src/mmce_fs.c:409,468,527`, identical packet sequence differing only in command byte |
| RE-RIPTOPL-118 | WEAKENED | Two copies match the claimed pattern (`src/ui/dia.cpp:75-110`, `src/ui/guinotify.cpp:47-84`); the modal copy does not measure, clamp or draw a rect |
| RE-RIPTOPL-119 | VERIFIED | Overlay inset arithmetic copy-identical in `src/gfx/coverflow.cpp:337-345`, `src/gfx/psbbnflow.cpp:162-175`, `src/gfx/grid.cpp:320-330` |
| RE-RIPTOPL-120 | VERIFIED | Ring walk duplicated at `modules/iopcore/cdvdman/streaming.c:162-245` (`ReadSectorsEE`) and `:247-295` (`ReadSectors`) |
| RE-RIPTOPL-121 | VERIFIED | Helper sets at `ee_core/src/freeze_diag_screen.c:42-94` and `ee_core/src/freeze_diag_format.c:22-49,304-321`, including the same module-table lookup in `ln_where`/`put_where` |
| RE-RIPTOPL-122 | VERIFIED | Five converters at `ee_core/src/igs_api.c:79,94,109,124,139`, one body shape differing only in width/radix |
| RE-RIPTOPL-123 | WEAKENED | Three copies exact (`src/sources/ranet.cpp:1077-1078`, `ratls_ps2.cpp:161-162`, `nettime.cpp:117-118`), but the prescribed fix breaks non-RA builds |
| RE-RIPTOPL-124 | VERIFIED | First-66-line diffs vs `system.cpp`: sysdisc 2 changed lines, sysneutrino 4, sysvmc 8; dead `SYS_DISC_*` constants at `src/platform/sysvmc.cpp:15-23` (used only in `sysdisc.cpp:161,185,186`) |
| RE-RIPTOPL-125 | WEAKENED | Graduated 100 µs/1 ms poll + `#399` comment in only 3 of 4 (`smb.c:302-304`, `smb2.c:310`, `nfs.c:78`); the HTTP copy polls at a flat 1 ms |
| RE-RIPTOPL-126 | VERIFIED-DRIFT | Tables byte-identical and atad MDMA copy dead (`modules/hdd/atad/src/ps2atad.c:1485-1505`, Makefile defines no `ATA_MWDMA_MODES`), but atad does not include the "already-shared" header |
| RE-RIPTOPL-127 | VERIFIED | `crc32` bodies byte-identical in `tools/pc/iso2opl/src/iso2opl.c:48-76` and `tools/pc/opl2iso/src/opl2iso.c:43-66`, incl. `crctab[0x400]` globals; typedef blocks match at the three cited headers |
| RE-RIPTOPL-128 | WEAKENED | Three predicate copies exact (`src/sources/ranet.cpp:217-231`, `ratls_ps2.cpp:143-153`, `nettime.cpp:138-140`), but the prescribed fix breaks non-RA builds |
| RE-RIPTOPL-129 | VERIFIED | Divergence real: ETH records success on `mkdir == 0 \|\| errno == EEXIST` (`src/sources/ethsupport.cpp:1535`), BDM only on `mkdir == 0` (`src/sources/bdmsupport.cpp:2063`) |
| RE-RIPTOPL-130 | VERIFIED | `#include` lists of `guiwait.cpp`/`guigameid.cpp` (38 each) differ only in the final self-header; cited unused headers appear in `guigameid.cpp` only inside comments |
| RE-RIPTOPL-131 | VERIFIED | `guiDrawIconAndText`/`guiDrawIconAndLiteralText` at `src/gfx/uidraw.cpp:13-57` are the same body modulo `_l(textId)` vs literal |
| RE-RIPTOPL-132 | VERIFIED | `dsScan` (`src/ui/drivestatus.cpp:77-165`) and `fmScanDrives` (`src/ui/guifilemgr.cpp:174-248`) walk the same BDM/MMCE/MC/APA sequence with the same calls |

## Reasoning for non-VERIFIED verdicts

### RE-RIPTOPL-100 — VERIFIED-DRIFT
Mechanism holds: the MINI profile reserves `maxIsoTransfDesc = 0x40`, `maxTransDesc = 0x40`, `maxIoReqs = 0x100`; `initHcdStructs` allocates the IsoTD pool and the IsoTD→IoReq LUT from those counts (`modules/usb/usbd-ra/src/hcd.c:366-375,457-462`); no isochronous client exists in the tree (grep for isochronous users outside `usbd-ra` returns nothing; clients are `usbmass_bd` bulk and the hub driver). The halted-endpoint drain slip is real: inside the `curTd` loop the code clears the *original* TD's LUT slot. Corrections: (1) the MINI block is at `usbd.c:50-55` — line 38 is the *non*-MINI `maxIsoTransfDesc = 0x80`; (2) the slip is at `usbd.c:139`, not :130; (3) `setupIsocronTransfer` starts at `usbio.c:152`, not :143; (4) `processDoneQueue_IsoTd` starts at `usbd.c:97`, not :96. Scope note the finding misses: the main loader loads usbd with zero arguments (`src/platform/system.cpp:411`, `sysLoadModuleBuffer(&usbd_irx, size_usbd_irx, 0, NULL)`), so the full pool is paid there — but ee_core already shrinks it for the pad stack (`ee_core/src/iopmgr.c:223`: `itd=2\0ioreq=24`), which both confirms the fix mechanism works and narrows "fully provisioned" to the main load. Fix (use the existing `itd=`/`ioreq=` argument surface) is LESS-NOT-MORE compliant.

### RE-RIPTOPL-103 — VERIFIED-DRIFT
Mechanism and fix hold: `include/utf8.h` defines the table and a non-inline `uint32_t static utf8Decode(...)` (reversed qualifiers confirmed) in the header; exactly two includers (`src/gfx/fntsys.cpp:12`, `src/gfx/textshape.cpp:12`). Correction: the table is **400 entries (400 bytes)**, not 364 — counted entry-by-entry (256 byte-class entries + 144 transition entries, `include/utf8.h:21-36`). The finding understates its own saving by 36 bytes per includer. Location range :21-49 covers table (:21-36) plus function (:38-49) correctly.

### RE-RIPTOPL-108 — VERIFIED-DRIFT
Duplication and bidirectional drift hold: file line counts are exact (pademu `ds34bt.c` 1425 vs standalone 1719; pademu `ds34usb.c` 616 vs standalone 998); both `smsutils.S` copies are md5-identical (`3612cf1bd66a11f0b9e53ac78a5940d7`); standalone-only `outEndp` initialisation confirmed (`modules/ds34usb/iop/ds34usb.c:168-169,221,958`) and the pademu-only `report->Power` bound confirmed (`modules/pademu/ds34bt.c:1240` vs unguarded use at `modules/ds34bt/iop/ds34bt.c:1333`). Corrections: the diffs measure **785 lines (bt) and 834 lines (usb)** of `diff` output, not 915 and 950. The "~2,600 lines removed" benefit is also loose: deleting the pademu copies removes 2,041 lines; deleting the standalone copies removes 2,717.

### RE-RIPTOPL-110 — VERIFIED-DRIFT
The six-copy launch ritual and its drift are real (all six cited functions exist at the cited ranges; ETH and MMCE per-part loops are byte-identical including the "Sum the size of all parts… upstream OPL #1763" comment at `ethsupport.cpp:1449` / `mmcesupport.cpp:1480`). Corrections: (1) censuses are inflated — actual call sites (excluding definitions and comments) are `sbPrepare` **8** (not 11), `sbLoadCheats` **9** (not 10), `sbLoadImage` **8 calls** (9 only counting the definition), `CheckPS2Logo` **7 calls** (not 10), `mmceSendGameID` **14 calls / 25 total references** in `src/` (not 21); (2) the "per-part size loop is byte-for-byte the same logic in three files, each headed by the identical comment" claim fails for BDM: the loop at `bdmlaunch.cpp:811-859` is a fragment-list loop (`fileXioIoctl2`/`USBMASS_IOCTL_GET_FRAGLIST`) with the size summation folded in and no such comment — only ETH and MMCE share the identical loop+comment.

### RE-RIPTOPL-118 — WEAKENED
Two of the three copies match the claimed shape exactly: `diaDrawHint` (`src/ui/dia.cpp:75-110`, 384-byte wrap buffer) and `Notifications::render` (`src/ui/guinotify.cpp:47-84`, 512-byte buffer, comment explicitly citing `diaDrawHint`). The modal copy does not: `guiDrawMsgText` (`src/ui/guimodal.cpp:115-122`) wraps into 512 bytes at a fixed `gGuiScreenWidth - 120` width with no `fntCalcDimensions` measurement and no box clamp, and `guiDrawWrappedLines` (:90-113) draws no rect at all — it centres pre-wrapped lines using a separate 192-byte per-line buffer. So "each independently measures with `fntCalcDimensions`, clamps a box, and draws rect + string" is true of two copies, not three; the genuinely shared part is only the `fntWrapText` + `lines * MENU_ITEM_HEIGHT` pattern. True scope: one full duplicate pair plus a partial third; the ~60-line saving is overstated.

### RE-RIPTOPL-123 — WEAKENED
The duplication is exact: the `got > 64 && got % 64 > 48` peek/truncate pattern occurs at exactly the three cited sites and nowhere else (grep-verified), including the named-vs-magic flag divergence (`0x08 | 0x01` in the ratls/nettime copies). The prescribed fix is not sound as written: it says to delete the ratls and nettime copies and have both call ranet's implementation via `raNetTcpRecv`. But `ranet.cpp` is compiled **only in RA editions** (`tools/build_edition.py:95-98`, sources added under `if options["ra"]`), while `ratls_ps2.cpp` is also compiled in non-RA updater/slim builds (`tools/build_edition.py:137-142` adds it with the slim mbedTLS target) and `nettime.cpp` is in the base source list for every edition (`ps2.yaml:641`). That is precisely why the non-RA ratls branch carries its own copy under `#else` (`ratls_ps2.cpp:147-165`). Deleting those copies in favour of `raNetTcpRecv` would break the non-RA link. True scope: duplication real; the fix needs a shared home outside the RA-only file (e.g. the implementation moved to a always-compiled source), not a call into ranet.

### RE-RIPTOPL-125 — WEAKENED
Three of the four transports implement the full graduated poll exactly as claimed — `smb.c:302-304` (`DelayThread(polls++ < 20 ? 100 : 1000)`), `smb2.c:287-325` (`waited_us` accounting), `nfs.c:70-95` — and those three carry the `#399` comment. The fourth does not: `RecvBounded` in `device-http.c:20-35` polls with a flat `DelayThread(1000)` — there is no 100 µs phase and no `#399` comment; it shares only the `MSG_DONTWAIT` poll + 10 s budget shape, with tick-subtraction accounting. True scope: the graduated-poll duplication is 3×, not 4×; the HTTP copy is a partial sibling, so a shared helper extracted from the three would not drop into the HTTP transport unchanged.

### RE-RIPTOPL-126 — VERIFIED-DRIFT
Duplication and divergence-in-reach hold: the timing values in `xatad.c:8-52` and `ps2atad.c:1486-1529` are byte-identical; atad's MDMA copy sits under `#ifdef ATA_MWDMA_MODES` (`ps2atad.c:1485-1505`) and the atad Makefile (`modules/hdd/atad/Makefile:7`) defines `ATA_USE_DEV9/GAMESTAR_WORKAROUND/ENABLE_BDM` but not `ATA_MWDMA_MODES`, so that copy is dead while xhdd's is live. Correction: the fix's premise that `opl-hdd-ioctl.h` is a header "both modules already use" is wrong for atad — the header lives at `modules/hdd/common/opl-hdd-ioctl.h` and is included only by the xhdd modules (`xatad.c:5`, `xhdd.c:8`, `hdpro.c:5`, via `-I../common` in `modules/hdd/xhdd/Makefile:4`); `ps2atad.c` does not include it and the atad Makefile has no `-I../common`. The fix therefore also needs an include-path change in atad, not just a move into an already-shared header.

### RE-RIPTOPL-128 — WEAKENED
The duplication is exact: `Ranet::nicBusy`/`nicReserved` (`ranet.cpp:217-231`), the non-RA `ratlsNicReserved` copy (`ratls_ps2.cpp:143-153`, with the admitting comment), and the inlined union at the top of `netTimeFetch` (`nettime.cpp:138-140`) spell out the same five-term predicate. The prescribed fix — "delete the ratls and nettime copies; both call the ranet predicate" — fails for the same build reason as RE-RIPTOPL-123: ranet is RA-only (`tools/build_edition.py:95-98`), while `nettime.cpp` builds in every edition (`ps2.yaml:641`) and `ratls_ps2.cpp` builds in non-RA updater editions; the RA branch of ratls already does call `raNetNicReserved()` (`ratls_ps2.cpp:140`). The copies exist in the `#else` branch because the canonical predicate is not linked there. True scope: duplication real; consolidation requires moving the predicate to an always-compiled source, not calling into ranet.

## Candidates (new defects noticed while verifying — not merged into verdicts)

1. **Third keyboard-path VLA, device-derived length** — `src/ui/menusys.cpp:306`: `char newName[nameLength]` where `nameLength` comes from `gsOf(support)->nameLength(support, row.id)` (:302, per-backend implementations in every `*support.cpp`), guarded only by `nameLength <= 0`. It then feeds `Gui::showKeyboard(newName, nameLength)` (:309), i.e. it is both another instance of the RE-RIPTOPL-105 pattern and a caller whose length is not a fixed dialog size.
2. **PC-tool `crctab[0x400]` oversize** — the same 4× oversized table as RE-RIPTOPL-104 exists in both PC tools: `tools/pc/iso2opl/src/iso2opl.c:15` and `tools/pc/opl2iso/src/opl2iso.c:14` (`u32 crctab[0x400]`, only indices 0–255 filled/used, rebuilt on every `crc32()` call). RE-RIPTOPL-127 covers these files' duplication but not the oversize/per-call rebuild.

## Tally

- VERIFIED: 24 (101, 102, 104, 105, 106, 107, 109, 111, 112, 113, 114, 115, 116, 117, 119, 120, 121, 122, 124, 127, 129, 130, 131, 132)
- VERIFIED-DRIFT: 5 (100, 103, 108, 110, 126)
- WEAKENED: 4 (118, 123, 125, 128)
- REFUTED: 0
- BLOCKED-ENV: 0

Total: 24 + 5 + 4 = 33 findings (RE-RIPTOPL-100…132).
