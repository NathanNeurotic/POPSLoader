# Round 7 — §03 Build glue (Tasks 3) + Assembly (Task 4) — Launchstation

- **Repo / pin:** `NathanNeurotic/Launchstation` @ `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (verified held at start and end of this pass; `git status` clean).
- **Scope:** Task 3 — build glue (`imports.lst`, `exports.tab`, `irx_imports.h`) for the nine modules Round 5 inventoried but did not line-read: `udpfs_smap`, `hdl_info`, `ps2ips_rpc`, `ps2host`, `ds34usb`, `ds34bt`, `xparam`, `dev9_poweroff`, `AllowDVDV`. Task 4 — `iop/ds34bt/iop/smsutils.S`, `iop/ds34usb/iop/smsutils.S`, `src/embed_blobs.S`. The Round-5-cross-checked glue of `ata_bd`/`usbmass_bd`/`mmceman`/`vmcman` was **not** redone.
- **Method:** READ ONLY. Every `imports.lst` and `irx_imports.h` below was read in full. Every imported symbol was grepped per-symbol (word-boundary) over the module's C sources, then every apparent non-hit was re-grepped alias-aware (see Mechanics) over the whole module directory including headers before being called dead. Exports were checked for definitions. Build wiring was confirmed against `ps2.yaml` (`imports_lst:`/`exports_tab:` per target) — e.g. `ps2.yaml:32-33` (udpfs_smap), `ps2.yaml:89-90` (hdl_info), `ps2.yaml:207` (ps2ips_rpc), `ps2.yaml:392` (xparam), `ps2.yaml:69` (dev9_poweroff), `ps2.yaml:77` (AllowDVDV); DS34 targets are generated, with sources listed at `scripts/configure_ds34.py:23`.
- **Prior-findings guard:** nothing numbered LAUNCHSTATION-001…185 is refiled. Two overlaps are cross-referenced only: the `#if 0` cdvdman complex (LAUNCHSTATION-018) and the byte-identical `smsutils.S` pair (LAUNCHSTATION-021).

---

## 0. Mechanics — how the cross-checks resolve (read first)

1. **`irx_imports.h` carries no per-function entries in any of the nine modules.** All nine files are include-lists of SDK headers only (verified by full read of each). Therefore:
   - Task (c) *positional* order/slot consistency between `imports.lst` and `irx_imports.h` **cannot exist as a failure mode here** — there are no slots on the header side. The only order-bearing pair in scope is `exports.tab` vs the consumer-side `DECLARE_IMPORT` numbers, checked for `udpfs_smap` (§1.1) — it matches.
   - Task (d) *duplicate imports across the two files* likewise cannot occur literally. Within-file duplicates were also checked mechanically: **161 `I_*` entries across the nine `imports.lst` files, zero duplicates** (udpfs_smap 26, hdl_info 22, ps2ips_rpc 37, ps2host 27 incl. 2 inside `#if 0`, ds34usb 22, ds34bt 20, xparam 2, dev9_poweroff 1, AllowDVDV 4).
   - Slot numbers live in the SDK headers' `DECLARE_IMPORT(n, …)` macros, **not** in `imports.lst` order. In-repo proof: `iop/usbd-ra/include/usbd.h:323-337` assigns usbd slots 4–18 by macro; the ds34 `imports.lst` usbd sections list those functions in non-ascending slot order (Scan=6, OpenPipe=9, ClosePipe=10, OpenPipeAligned=12, SetPrivateData=7, TransferPipe=11, RegisterLdd=4 — `iop/ds34usb/iop/imports.lst:26-32`), and `iop/smbman/imports.lst:40-44` (outside scope, corroboration only) is likewise non-ascending (CreateSema=4, WaitSema=8, SignalSema=6, iSignalSema=7, DeleteSema=5 per `tests/pccf-stubs/thsemap.h:76-83`). **Conclusion (INFERRED from this in-repo evidence): `.lst` ordering is not slot assignment; no Cat-6 order candidate is filed anywhere in this section.**
2. **Alias layers that a naive grep misses** (each resolved against an in-repo authority):
   - `sifcmd`: code calls the short forms `SifInitRpc`/`SifSetRpcQueue`/`SifRegisterRpc`/`SifRpcLoop`; imports are `sceSif*`. Used in hdl_info, ps2host, ds34usb, ds34bt.
   - `ps2ip`: code calls unprefixed BSD names (`accept`, `bind`, `send`, …); imports are `lwip_*`. The header itself (`ps2ip.h`) is SDK-side, not in this repo, so the two non-obvious mappings — `disconnect()` → `lwip_close` and `ioctlsocket()` → `lwip_ioctl` — are labelled **INFERRED** (by elimination: both call sites are live dispatcher paths and no other import in the module can serve them).
   - `usbd`: code calls old-style `Usb*` names; mapping is defined in-repo at `iop/usbd-ra/include/usbd.h:299-318` (e.g. `UsbOpenEndpoint`→`sceUsbdOpenPipe` :310, `UsbRegisterDriver`→`sceUsbdRegisterLdd` :304) and `iop/usbd-ra/include/usbd_macro.h:128-152` for the transfer family.
   - `thsemap`: `CreateMutex()` is a `static inline` over `CreateSema` — in-repo authority `tests/pccf-stubs/thsemap.h:65-73`.
   - `stdio` in udpfs_smap: `printf` is referenced only through the `M_PRINTF`/`M_DEBUG` macros, `iop/udpfs_smap/include/mprintf.h:13-17`.
3. **Library-set consistency (`imports.lst` sections vs `irx_imports.h` includes)** is exact for udpfs_smap (8 libs), hdl_info (9), ps2ips_rpc (7), ps2host (10, including the `#if 0` cdvdman pair on both sides), xparam (sysclib + a macro-serving loadcore include, §1.7), dev9_poweroff (1), AllowDVDV (2, plus an in-source third — G7-5). The single exception is ds34usb/ds34bt (G7-4).

---

## 1. Task 3 — per-module glue ledger

### 1.1 udpfs_smap — CLEAN (26/26 imports used; 4/4 exports defined; slots match)

- Files: `iop/udpfs_smap/src/imports.lst` (49 lines), `iop/udpfs_smap/src/exports.tab`, `iop/udpfs_smap/include/irx_imports.h:7-14`.
- Imports → first caller (all in `iop/udpfs_smap/src/`): CreateThread `smap.c:483`; StartThread `smap.c:489`; DelayThread `smap.c:77` (×17); DeleteThread `smap.c:491`; SetAlarm `smap.c:410`; USec2SysClock `smap.c:409`; printf via `M_PRINTF` macro `include/mprintf.h:13-14`, expanded at e.g. `main.c:16`, `smap.c:83` (DEBUG-gated at `mprintf.h:16-17`, but the symbol is source-referenced, so the stub is not dead); bzero `smap.c:569`; CpuSuspendIntr `smap.c:624`; CpuResumeIntr `smap.c:629`; RegisterLibraryEntries `main.c:20`; CreateEventFlag `smap.c:473`; WaitEventFlag `smap.c:388`; SetEventFlag `smap.c:496`; iSetEventFlag `smap.c:362`; DeleteEventFlag `smap.c:485`; CreateSema `xfer.c:57`; SignalSema `xfer.c:261`; WaitSema `xfer.c:259`; dev9IntrEnable `smap.c:396`; dev9IntrDisable `smap.c:458`; dev9RegisterIntrCb `smap.c:609`; dev9RegisterPreDmaCb `xfer.c:59`; dev9RegisterPostDmaCb `xfer.c:60`; dev9DmaTransfer `xfer.c:71`; dev9GetEEPROM `smap.c:570`.
- Exports (`exports.tab:7-10`) → definitions: `SMAPGetMACAddress` `smap.c:616`; `smap_transmit` `xfer.c:249`; `smap_register_rx_callback` `xfer.c:94`; `smap_fifo_read` `xfer.c:106`. The four `_retonly` placeholders (`exports.tab:3-6`) put the real exports at slots 4–7, exactly matching the consumer-side declarations `iop/udpfs_smap/include/smap.h:36-39` (`DECLARE_IMPORT(4, SMAPGetMACAddress)` … `(7, smap_fifo_read)`). **The one true positional cross-check in scope passes.**
- Reverse check: no libc/SDK call in `main.c`/`smap.c`/`xfer.c` lacks an import (copy/set work is done with `bzero` + explicit loops; battery grep for memcpy/memset/strlen/strcmp/sprintf returned no hits in the module's sources).

### 1.2 hdl_info — CLEAN (22/22 imports used; 3/3 exports defined)

- Files: `iop/hdl_info/imports.lst` (48 lines), `iop/hdl_info/exports.tab`, `iop/hdl_info/irx_imports.h:20-28`.
- Imports → caller: ata_get_devinfo `hdd.c:110`; ata_device_sector_io `hdd.c:33`; ata_device_flush_cache `hdd.c:59`; dev9Shutdown `hdd.c:75`; sceSifInitRpc via `SifInitRpc` `main.c:54`; sceSifSetRpcQueue via `SifSetRpcQueue` `main.c:55`; sceSifRegisterRpc via `SifRegisterRpc` `main.c:56`; sceSifRpcLoop via `SifRpcLoop` `main.c:57`; printf `main.c:31` (also `hdd.c:179`); strcmp `hdd.c:140`; strcpy `hdd.c:141`; memset `apa.c:45`; memcpy `apa.c:72`; memcmp `apa.c:161`; AllocSysMemory `main.c:81`; FreeSysMemory `main.c:92`; GetThreadId `main.c:55`; CreateThread `main.c:42`; StartThread `main.c:44`; CpuSuspendIntr `main.c:80`; CpuResumeIntr `main.c:82`; PoweroffShutdown `hdd.c:76`.
- Exports (`exports.tab:2,4,7`) → definitions: `_start` `main.c:26`; `shutdown` `main.c:15`; `HdlRenameGame` `hdd.c:159`. All defined.
- Reverse check dissolved: the module's `malloc`/`free` calls need no import — they are defined locally at `main.c:75` / `main.c:87` over the imported `AllocSysMemory`/`FreeSysMemory`. The `read`/`write`/`close` grep hits are function-pointer/struct-field uses, not ioman calls.
- Cosmetic only (not filed): trailing spaces on `imports.lst:12-14` (`I_sceSifInitRpc␠` etc.).

### 1.3 ps2ips_rpc — 1 dead import (G7-2); otherwise consistent (36/37 used)

- Files: `iop/ps2ips_rpc/imports.lst` (60 lines), `iop/ps2ips_rpc/irx_imports.h:19-25`. No `exports.tab` — consistent: the module exports no library; it registers an RPC server (`ps2ips.c:660`).
- Imports → caller (all `iop/ps2ips_rpc/ps2ips.c` unless noted): CreateThread `:680`; DeleteThread `:689`; StartThread `:688`; GetThreadId `:659`; printf `:657` (live; also `:646,672,683` — the `:174,274,334,367` hits are commented out and were not counted); memcpy `:68`; memset `:61`; CpuSuspendIntr `:192`; CpuResumeIntr `:194`; **sceSifInitRpc — NO CALLER (G7-2)**; sceSifSetRpcQueue `:659`; sceSifRegisterRpc `:660`; sceSifRpcLoop `:661`; sceSifGetOtherData `:345`; sceSifDmaStat `:186`; sceSifSetDma `:193`; lwip_accept via `accept` `:65`; lwip_bind via `bind` `:80`; lwip_close via `disconnect` `:92` (INFERRED mapping, §0.2); lwip_connect via `connect` `:105`; lwip_getpeername via `getpeername` `:485`; lwip_getsockname via `getsockname` `:467`; lwip_getsockopt via `getsockopt` `:504`; lwip_setsockopt via `setsockopt` `:532`; lwip_listen via `listen` `:117`; lwip_recv via `recv` `:153`; lwip_recvfrom via `recvfrom` `:253`; lwip_send via `send` `:348`; lwip_sendto via `sendto` `:381`; lwip_socket via `socket` `:393`; lwip_select via `select` `:431`; lwip_ioctl via `ioctlsocket` `:452` (INFERRED mapping, §0.2); ps2ip_getconfig `:402`; ps2ip_setconfig `:409`.
- The three `#ifdef PS2IP_DNS` imports (`imports.lst:56-58`) are live, not conditional-dead: `ps2.yaml:208` sets `defines: [PS2IP_DNS]` for this target; callers are `gethostbyname` `ps2ips.c:544` (guard at `:536`), `dns_setserver` `:562`, `dns_getserver` `:571`.

### 1.4 ps2host — 1 dead import (G7-3); `#if 0` complex triple-consistent (25/25 live imports used)

- Files: `iop/ps2host/imports.lst` (58 lines), `iop/ps2host/irx_imports.h:16-27`. No `exports.tab` — consistent: ioman driver registered via `AddDrv` (`net_fsys.c:426`), no library exports.
- Imports → caller: printf `net_fio.c:49` (macro def `net_fio.c:34`); **puts — NO CALLER (G7-3)**; memset `net_fio.c:706`; memcpy `net_fio.c:325`; strncpy `net_fio.c:181`; CreateSema `net_fsys.c:423`; SignalSema `net_fsys.c:112`; WaitSema `net_fsys.c:109`; DeleteSema `net_fsys.c:113`; CreateThread `net_fsys.c:91`; StartThread `net_fsys.c:94`; DelayThread `net_fio.c:717`; ExitDeleteThread `net_fio.c:771` (the `net_fsys.c:111` hit is commented out and was not counted); AddDrv `net_fsys.c:426`; DelDrv `net_fsys.c:425`; lwip_send via `send` `net_fio.c:72`; lwip_socket via `socket` `net_fio.c:713`; lwip_listen via `listen` `net_fio.c:728`; lwip_recv via `recv` `net_fio.c:94`; lwip_close via `disconnect` `net_fio.c:47` (INFERRED mapping, §0.2; also `:59,724,732,759,766,769`); lwip_bind via `bind` `net_fio.c:720`; lwip_accept via `accept` `net_fio.c:745`; sceSifInitRpc via `SifInitRpc` `ps2host.c:31`; CpuEnableIntr `ps2host.c:26` (live — outside the `#if 0`); FlushDcache `ps2host.c:25` (live).
- `#if 0` consistency (cross-reference LAUNCHSTATION-018, not refiled): `sceCdInit`/`sceCdStop` sit inside `#if 0` in all three places at once — calls `ps2host.c:28-29` (guard `:27-30`), imports `imports.lst:53-58`, header `irx_imports.h:16-18`. The glue is internally consistent; removing the blocks is -018's already-filed fix.

### 1.5 ds34usb — 1 dead import (G7-1) + header superset (G7-4); 21/22 used

- Files: `iop/ds34usb/iop/imports.lst` (33 lines), `iop/ds34usb/iop/irx_imports.h:20-35`.
- Imports → caller (all `iop/ds34usb/iop/ds34usb.c`): sceSifInitRpc via `SifInitRpc` `:703`; sceSifSetRpcQueue via `SifSetRpcQueue` `:704`; sceSifRegisterRpc via `SifRegisterRpc` `:705`; sceSifRpcLoop via `SifRpcLoop` `:706`; CreateSema via the `CreateMutex` inline `:776-777` (authority `tests/pccf-stubs/thsemap.h:65-73` — a naive grep calls this dead; it is not); SignalSema `:164`; WaitSema `:479`; PollSema `:118`; iSignalSema `:467`; StartThread `:801`; CreateThread `:798`; DelayThread `:238`; GetThreadId `:704`; SetAlarm `:478`; CancelAlarm `:480`; sceUsbdScanStaticDescriptor via `UsbGetDeviceStaticDescriptor` `:86` (mapping `usbd-ra/include/usbd.h:306`); sceUsbdOpenPipe via `UsbOpenEndpoint` `:124` (`usbd.h:310`); sceUsbdClosePipe via `UsbCloseEndpoint` `:191` (`usbd.h:312`); sceUsbdOpenPipeAligned via `UsbOpenEndpointAligned` `:143` (`usbd.h:311`); **sceUsbdSetPrivateData — NO CALLER (G7-1)**; sceUsbdTransferPipe via the `sceUsbdControlTransfer` static inline (`usbd-ra/include/usbd_macro.h:21-31`), called as `UsbControlTransfer` `:263` (also `:433,575,589,628,638`) and via `UsbInterruptTransfer`→`sceUsbdInterruptTransfer` (`usbd_macro.h:39-40,131`) `:450` (also `:541`); sceUsbdRegisterLdd via `UsbRegisterDriver` `:785` (`usbd.h:304`).
- Dissolved reverse candidate: `UsbSetDeviceConfiguration` at `ds34usb.c:163` looks like a call with no import. It is a macro — `usbd_macro.h:135` maps it to `sceUsbdSetConfiguration`, which `usbd_macro.h:56-57` defines over `sceUsbdControlTransfer` → the imported `sceUsbdTransferPipe`. The usbd import table (`usbd.h:323-337`) contains no `SetConfiguration` entry at all. **Correctly absent from `imports.lst`; checked-clean.**
- Consistency notes: no sysclib section and none needed (copy/set via `mips_*`, §2; no memcmp/strcmp calls); no stdio import and `DPRINTF` is compiled out (`ds34usb.c:15`), with the printf variant commented at `:14`.

### 1.6 ds34bt — 1 dead import (G7-1) + header superset (G7-4); 19/20 used

- Files: `iop/ds34bt/iop/imports.lst` (34 lines), `iop/ds34bt/iop/irx_imports.h:20-35` (byte-identical to the ds34usb copy — `diff` clean).
- Imports → caller (all `iop/ds34bt/iop/ds34bt.c`): sceSifInitRpc via `SifInitRpc` `:1629`; sceSifSetRpcQueue via `SifSetRpcQueue` `:1630`; sceSifRegisterRpc via `SifRegisterRpc` `:1631`; sceSifRpcLoop via `SifRpcLoop` `:1632`; memcmp `:613` (also `:669,676`); CreateSema via `CreateMutex` inline `:1689` (same authority as §1.5); SignalSema `:180`; WaitSema `:1457`; PollSema `:377`; StartThread `:1714`; CreateThread `:1711`; DelayThread `:553`; GetThreadId `:1630`; sceUsbdScanStaticDescriptor via `UsbGetDeviceStaticDescriptor` `:52` (8× total); sceUsbdOpenPipe via `UsbOpenEndpoint` (3×); sceUsbdClosePipe via `UsbCloseEndpoint` (3×); sceUsbdOpenPipeAligned via `UsbOpenEndpointAligned` (2×); **sceUsbdSetPrivateData — NO CALLER (G7-1)**; sceUsbdTransferPipe via `UsbControlTransfer` (1×), `UsbInterruptTransfer` (2×) and `UsbBulkTransfer` (4× → `sceUsbdBulkTransfer` macro, `usbd_macro.h:36-37,130`); sceUsbdRegisterLdd via `UsbRegisterDriver` (2×, two `UsbDriver` structs at `ds34bt.c:26,34`).
- Dissolved reverse candidate: `UsbSetDeviceConfiguration` at `ds34bt.c:152` and `:224` — same macro dissolution as §1.5 (`usbd_macro.h:56-57,135`). Checked-clean.
- Consistency notes: no iSignalSema import and no iSignalSema call (the BT semaphore is only ever signalled from thread context — READ as call-site fact, no defect claimed); `DPRINTF` compiled out (`ds34bt.c:19`, printf variant commented `:18`); sysclib section contains exactly the one sysclib function the module calls (`memcmp`, `imports.lst:9`).

### 1.7 xparam — CLEAN (2/2 used)

- Files: `iop/xparam/src/imports.lst` (4 lines), `iop/xparam/src/irx_imports.h:11-14`. No `exports.tab` — consistent: one-shot `_start` module (`xparam.c:22`), registers no library.
- Imports → caller: strcmp `xparam.c:57`; strtol `xparam.c:38` (also `:41`).
- Dissolved candidate: `irx_imports.h:11` includes `loadcore.h` with no loadcore section in `imports.lst`. Not an import mismatch — xparam is the **only** one of the nine whose C includes `irx_imports.h` (`xparam.c:1`), and `loadcore.h` supplies the `IRX_ID` / `MODULE_NO_RESIDENT_END` macros the module uses at `xparam.c:11` and `xparam.c:48`. The include is load-bearing; checked-clean.

### 1.8 dev9_poweroff — CLEAN (1/1 used)

- Files: `iop/dev9_poweroff/imports.lst` (3 lines), `iop/dev9_poweroff/irx_imports.h:5` (dev9 only — exact library-set match).
- The single import `Dev9RegisterPowerOffHandler` (`imports.lst:2`) is called at `main.c:18` and `main.c:19` (clearing slots 0 and 15, per the comment at `main.c:13-16`). No other SDK calls exist in the 22-line module. No `exports.tab` — consistent.

### 1.9 AllowDVDV — 4/4 in `imports.lst` used, plus a split in-source import table (G7-5)

- Files: `iop/AllowDVDV/imports.lst` (9 lines), `iop/AllowDVDV/irx_imports.h:6-7` (ioman + sysclib — exact match for the `.lst`).
- Imports → caller (all `iop/AllowDVDV/AllowDVDV.c`): memset `:45`; memcpy `:47`; open `:50`; close `:57`.
- Third glue source: the module's actual payload call, `SecrDiskBootFile(buf)` at `AllowDVDV.c:73`, is served not by `imports.lst` but by an import table embedded in the C file itself — `AllowDVDV.c:80-82` (`DECLARE_IMPORT_TABLE(secrman, 1, 0)` / `DECLARE_IMPORT(13, SecrDiskBootFile)` / `END_IMPORT_TABLE`), with `<secrman.h>` included at `AllowDVDV.c:3`. Neither `imports.lst` nor `irx_imports.h` mentions secrman. See G7-5.

---

## 2. Task 3 candidates

### G7-1 / ds34usb + ds34bt import a USB private-data setter neither driver ever calls / Category 1/7
- **Locations:** `iop/ds34usb/iop/imports.lst:30` (`I_sceUsbdSetPrivateData`); `iop/ds34bt/iop/imports.lst:31` (`I_sceUsbdSetPrivateData`). No-caller side: `grep -rn "PrivateData" iop/ds34usb/ iop/ds34bt/` returns exactly those two lines — no `UsbSetDevicePrivateData` call (the old-style name, mapped at `iop/usbd-ra/include/usbd.h:308`), no `sceUsbdSetPrivateData` call, and no `UsbGetDevicePrivateData`/`sceUsbdGetPrivateData` call in either `ds34usb.c` or `ds34bt.c`. Both drivers keep their per-device state in their own static structs instead (e.g. `ds34usb.c:71` `UsbDriver usb_driver`, state in `ds34pad[]`).
- **Problem:** One dead import stub linked into each DS34 IRX (IOP RAM is the scarcest memory in the system), in both copies of a near-identical glue pair — the classic copy-drift shape: the stub survives because the file is duplicated, not because either module needs it.
- **Fix:** Delete the one line from each `imports.lst`. Nothing else references the symbol.
- **Effort:** S (two one-line deletions). **Risk:** Low (no caller exists in either module; the DS34 variant build is the only consumer). **Confidence:** High — READ (exhaustive grep over both module trees, alias-aware: both spellings checked).

### G7-2 / ps2ips_rpc imports `sceSifInitRpc` and never calls it / Category 1/7
- **Locations:** import `iop/ps2ips_rpc/imports.lst:24` (`I_sceSifInitRpc`). No-caller side: `grep -rn "InitRpc" iop/ps2ips_rpc/` returns only that line; the module's RPC thread (`iop/ps2ips_rpc/ps2ips.c:659-661`) calls the other three sifcmd imports (`sceSifSetRpcQueue`, `sceSifRegisterRpc`, `sceSifRpcLoop`) and `_start` (`ps2ips.c:665-695`) creates/starts the thread without any SIF init.
- **Problem:** One dead stub in the IRX. Contrast the siblings in this same pass, which all do call it: `iop/hdl_info/main.c:54`, `iop/ps2host/ps2host.c:31`, `iop/ds34usb/iop/ds34usb.c:703`, `iop/ds34bt/iop/ds34bt.c:1629` — ps2ips is the outlier, consistent with a vendored `imports.lst` (see `iop/ps2ips_rpc/VENDORED.md:6`) carried over untrimmed.
- **Fix:** Delete `imports.lst:24`.
- **Effort:** S. **Risk:** Low (EE-side SIF RPC is already initialised before this IRX is loaded — INFERRED from the module functioning with the call absent from its code today; the code-side absence itself is READ). **Confidence:** High — READ.

### G7-3 / ps2host imports `puts` and never calls it / Category 1/7
- **Locations:** import `iop/ps2host/imports.lst:4` (`I_puts`). No-caller side: `grep -rn "puts" iop/ps2host/` outside `imports.lst` returns nothing; all module logging goes through `printf`/`dbgprintf` (`iop/ps2host/net_fio.c:34,49`, `net_fsys.c:23,95`).
- **Problem:** One dead stub in the IRX; leftover from the PS2Link ancestor of the module (`ps2host.c:1-6` header).
- **Fix:** Delete `imports.lst:4`.
- **Effort:** S. **Risk:** Low. **Confidence:** High — READ.

### G7-4 / ds34usb + ds34bt `irx_imports.h` declare twelve libraries neither module imports / Category 7/1
- **Locations:** `iop/ds34usb/iop/irx_imports.h:20-35` and `iop/ds34bt/iop/irx_imports.h:20-35` (the two files are byte-identical — `diff` clean). Each includes 17 headers; the corresponding `imports.lst` files import only 4 library families (ds34usb: sifcmd, thsemap, thbase, usbd — `iop/ds34usb/iop/imports.lst:1-33`; ds34bt adds sysclib for `memcmp` — `iop/ds34bt/iop/imports.lst:8-10`). Headers with no imported library on either side: `dmacman.h`, `intrman.h`, `iomanX.h`, `libsd.h`, `loadcore.h`, `sifman.h`, `stdio.h`, `sysmem.h`, `thevent.h`, `thmsgbx.h`, `vblank.h` (both modules) plus `sysclib.h` (ds34usb only).
- **Problem:** Inert today — neither module's C includes this header at all (`ds34usb.c:1-10` and `ds34bt.c:1-11` include the SDK headers directly; `grep -rn "irx_imports.h" iop/ds34usb/ iop/ds34bt/` finds no C hit), and the build consumes `imports.lst` (`scripts/configure_ds34.py:23`) — but it is a standing trap for exactly the audit performed here: the header *claims* a dependency surface (DMA, libsd, vblank, message boxes) that the IRX does not have, in two duplicated copies. It is the untrimmed PS2SDK template both modules inherited.
- **Fix:** Trim both copies to the headers matching their `imports.lst` (or delete the files, since nothing includes them — LESS: deletion is smaller). Keep the two copies in sync if kept.
- **Effort:** S. **Risk:** Low (no includer exists in-tree; a future includer would fail loudly at compile time, not silently). **Confidence:** High on the facts — READ; the inertness verdict is INFERRED from the build wiring (`ps2.yaml` / `configure_ds34.py:23` name `imports.lst`, never this header).

### G7-5 / AllowDVDV's real import lives in the C file, invisible to its own glue files / Category 7/1
- **Locations:** `iop/AllowDVDV/AllowDVDV.c:80-82` (in-source `DECLARE_IMPORT_TABLE(secrman, 1, 0)` + `DECLARE_IMPORT(13, SecrDiskBootFile)`), serving the call at `AllowDVDV.c:73`; vs the module's declared glue `iop/AllowDVDV/imports.lst:1-9` and `iop/AllowDVDV/irx_imports.h:6-7`, neither of which mentions secrman, while `ps2.yaml:77` wires `imports_lst: iop/AllowDVDV/imports.lst` as the target's import source.
- **Problem:** The module's glue is split across two mechanisms: four imports via `imports.lst`, and its single most important import (the secrman call the module exists to make) via a hand-rolled table at the bottom of the C file. Any `imports.lst`-driven tooling, audit, or stub regeneration sees a module that imports only memset/memcpy/open/close. It works — the in-source table is a complete, valid import declaration (READ) — so this is a consistency/visibility defect, not a functional one.
- **Fix:** Move the secrman entry into `imports.lst` (`secrman_IMPORTS_start` / `I_SecrDiskBootFile` / `secrman_IMPORTS_end`) and add `<secrman.h>` to `irx_imports.h`; delete `AllowDVDV.c:80-82`. Net lines ≈ 0; one mechanism remains.
- **Effort:** S. **Risk:** Low (same library, same slot 13 declared either way; DS34-style variant builds do not touch this module). **Confidence:** High — READ.

---

## 3. Task 4a — `smsutils.S` (both copies)

- **Files:** `iop/ds34bt/iop/smsutils.S` and `iop/ds34usb/iop/smsutils.S`, 180 lines each. **The two copies are byte-identical** (md5 `3612cf1bd66a11f0b9e53ac78a5940d7` both; `diff` clean). That duplication is **already LAUNCHSTATION-021** — noted here for completeness, not refiled. Both copies are actually assembled: `scripts/configure_ds34.py:23` lists `iop/{name}/iop/smsutils.S` in both DS34 targets' sources.
- **Routine inventory (complete):** exactly two global routines, declared at `smsutils.S:23-24`:
  1. `mips_memcpy` — `smsutils.S:27-128`. Unaligned-capable memcpy: small-copy byte tail (label `2:` at :118), misaligned head via `lwr`/`lwl`/`swr` (:37-43), 16-byte unrolled unaligned loop (:50-65), 4-byte loop (:72-78), aligned fast path (:94-105, :112-117).
  2. `mips_memset` — `smsutils.S:130-179`. Byte-fill word-splat (`:135-139`), alignment head via `swr` (:140-146), 16-byte unrolled loop (:153-159), 4-byte (:166-169) and byte (:173-176) tails. The `_dummy:` label at `:178` is not a routine — it is a local name on the shared final `jr $ra` (:179).
  - No other `.globl` symbols exist in the file. The `#include "as_reg_compat.h"` at `:11` resolves outside the repo (SDK include path; `find` over the repo returns no such file) — INFERRED SDK-provided, same as the modules' other SDK headers.
- **C callers — every routine has callers in both modules:**
  - ds34usb (declarations `iop/ds34usb/iop/ds34usb.h:185-186`): `mips_memcpy` at `ds34usb.c:417,553`; `mips_memset` at `ds34usb.c:414,773,774`.
  - ds34bt (declarations `iop/ds34bt/iop/ds34bt.h:373-374`): `mips_memcpy` at `ds34bt.c:531,558,566,574,726,847,1179,1219,1490,1504,1514,1529` (12 sites); `mips_memset` at `ds34bt.c:802,808,809,1243` (4 sites).
  - This also closes the glue question from §1.5/§1.6: the ds34 modules deliberately use these local routines instead of sysclib copy/set imports — ds34usb has no sysclib section at all and ds34bt imports only `memcmp` (`iop/ds34bt/iop/imports.lst:9`, called at `ds34bt.c:613`), for which smsutils provides no equivalent. Consistent.
- **Constants/lengths vs C side:** the assembly embeds **no buffer lengths** — all lengths arrive in `$a2`. Its only numeric constants are internal algorithm cutoffs (memcpy small-copy threshold 12 at `smsutils.S:30`; memset threshold 16 at `:133`; 16-byte unroll granularity throughout), which have no C-side counterparts to disagree with. C prototypes (`void mips_memcpy(void *, const void *, unsigned)` / `void mips_memset(void *, int, unsigned)`, `ds34usb.h:185-186` ≡ `ds34bt.h:373-374`) match the assembly's register use (`$a0` dst, `$a1` src/val, `$a2` len). One benign mismatch, not filed: the assembly also returns the destination in `$v0` (`smsutils.S:28`, `:131`) where the C prototypes say `void` — callers ignore it; this is the stock SMS-utils ABI, identical in both copies.
  - The `mips_memset` call at `ds34bt.c:1243` passes `PS3_01_REPORT_LEN + 2` in the DS4 branch — that is LAUNCHSTATION-136's already-filed defect site; the assembly routine itself faithfully writes the length it is given. Cross-reference only.
- **Verdict: no A7 candidate from `smsutils.S`.** Dissolved during this pass: (i) identical-copies duplication → already LAUNCHSTATION-021; (ii) void-vs-`$v0` prototype mismatch → benign, see above; (iii) suspected dead routine → none, both routines are called in both modules.

## 4. Task 4b — `src/embed_blobs.S` — CLEAN (33/33 files exist; 33/33 symbol pairs referenced)

- **Mechanism:** `EMBED_FILE`/`EMBED_SLICE`/`EMBED_TAIL` macros at `src/embed_blobs.S:16-50` each emit `.global sym` + `.global size_<sym>` (a `.word sym_end - sym` at :26) around an `.incbin`. So every embed must satisfy two checks: the incbin path exists, and both `sym` and `size_<sym>` are referenced from EE C.
- **All 33 incbin paths exist in-repo** (verified by filesystem check this pass), including the three sliced XLF files at 13,896 B each — comfortably larger than the 128-byte header slice.
- **All 33 symbols and their `size_` partners are referenced from C.** Ledger (embed line → file → C reference, data symbol / size symbol):
  - `:53` `exploit_system_xlf_header` ← `exploits/SYSTEM.XLF` [0,128) → `src/main_exploit_installer.c:489` / `:490`
  - `:54` `exploit_xsystem_xlf_header` ← `exploits/XSYSTEM.XLF` [0,128) → `main_exploit_installer.c:495` / `:496`
  - `:55` `exploit_dtl_system_xlf_header` ← `exploits/DTL-SYSTEM.XLF` [0,128) → `main_exploit_installer.c:501` / `:502`
  - `:56` `exploit_xlf_body` ← `exploits/SYSTEM.XLF` [128, EOF) → `main_exploit_installer.c:491` / `:492`. Slice arithmetic checked: 128-byte header (`:53`) + tail from offset 128 (`:56`) partition the 13,896-byte file exactly — no gap, no overlap. (Only `SYSTEM.XLF` gets a body embed; the XSYSTEM/DTL bodies are not embedded — that is the installer's design, read in Round 5, not a glue defect.)
  - `:57` `exploit_osdsys_kernel` ← `exploits/OSDSYS.KERNEL` → `main_exploit_installer.c:507` / `:508`
  - `:58` `exploit_osd110_kernel` ← `exploits/OSD110.KERNEL` → `main_exploit_installer.c:511` / `:512`
  - `:59` `exploit_jpn_sys` ← `exploits/JPN.sys` → `main_exploit_installer.c:563` / `:564`
  - `:60` `exploit_usa_sys` ← `exploits/USA.sys` → `main_exploit_installer.c:567` / `:568`
  - `:61` `exploit_eur_sys` ← `exploits/EUR.sys` → `main_exploit_installer.c:571` / `:572`
  - `:62` `exploit_chn_sys` ← `exploits/CHN.sys` → `main_exploit_installer.c:575` / `:576`
  - `:63` `exploit_list_icn` ← `exploits/list.icn` → `main_exploit_installer.c:1622` / `:626`
  - `:68` `mc_icon_sys` ← `res/memory-card/icon.sys` → `src/config.c:427` / `:427` (extern decls `config.c:380-381`)
  - `:69` `mc_list_icn` ← `res/memory-card/list.icn` → `config.c:430` / `:430` (extern decls `config.c:382-383`)
  - `:70` `exploit_ioprp_img` ← `exploits/IOPRP_LTS.IMG` → `src/init.c:847` / `:847`
  - `:74` `udpfs_ministack_irx` ← `iop/__precompiled/udpfs_ministack.irx` → `init.c:1041` / `:1041`
  - `:75` `udpfs_ioman_irx` ← `iop/__precompiled/udpfs_ioman.irx` → `init.c:1050` / `:1050`
  - `:78` `ps2dev9_v10_irx` ← `iop/__v10/ps2dev9.irx` → `init.c:498` / `:499`
  - `:79` `ps2ip_v10_irx` ← `iop/__v10/ps2ip.irx` → `init.c:639` / `:639`
  - `:82-88` `sfx_cursor/confirm/cancel/transition/message/connect/disconnect_adp` ← `res/sfx/*.adp` (connect/disconnect from `bd_connect.adp`/`bd_disconnect.adp`) → `src/dash_sound.c:103-110`, extern decls `dash_sound.c:18-31`, each with its `size_` partner consumed in the same file.
  - `:91-98` `sfx2_cursor/confirm/cancel/transition/message/boot/bd_connect/bd_disconnect_adp` ← `res/sfx_ps2/*.adp` → `dash_sound.c:92-99`, extern decls `dash_sound.c:33-48`, each with its `size_` partner.
  - Declaration mechanics on the C side are consistent: exploit/init blobs via `IMPORT_BIN2C(sym)` (e.g. `main_exploit_installer.c:15-25`, `init.c:28-29,47-48,804`); config/dash blobs via explicit `extern` pairs. The `size_` declarations vary between `unsigned int` (`config.c:381,383`) and `int` (`dash_sound.c:19,21,…`) — both are 32-bit on the EE and match the `.word` the macros emit (`embed_blobs.S:26`); checked-clean, not a defect.
  - Negative space (already filed in earlier rounds, not refiled): `iop/__precompiled/udpfs_smap.irx` is correctly **absent** here (LAUNCHSTATION-019); `exploits/IOPRP.IMG` and `exploits/XSYSTEM2.XLF` are correctly absent (LAUNCHSTATION-020); `res/sfx/boot.adp` is absent while `res/sfx_ps2/boot.adp` is embedded as `sfx2_boot_adp` (LAUNCHSTATION-013).
- **Verdict: no A7 candidate from `embed_blobs.S`.**

---

## 5. Summary of this section

- **Candidates: 5 glue (G7-1…G7-5), 0 assembly (A7).** All five glue candidates are Category 1/7-family, Effort S, Risk Low, Confidence READ — four dead/stale glue items and one split-mechanism inconsistency. No Cat-6 (order/slot) candidate survives: the only positional pair in scope (udpfs_smap exports vs `smap.h` import numbers) matches slot-for-slot, and `imports.lst` order provably does not assign slots (§0.1).
- **Checked-clean:** udpfs_smap (full: imports, exports, slots), hdl_info (full: imports, exports, local malloc/free), xparam (full), dev9_poweroff (full), ps2host live imports + `#if 0` triple-consistency, ps2ips_rpc alias-resolved socket imports + live DNS trio, ds34 CreateSema-via-CreateMutex (both), ds34 SetDeviceConfiguration macro dissolution (both), `smsutils.S` routine/caller/constant checks (both copies), `embed_blobs.S` 33/33 existence + reference checks.
- **Residue honestly stated:** the `ps2ip.h` alias mappings for `disconnect`/`ioctlsocket` are INFERRED (§0.2) because that header is SDK-side and not in this repo; no PS2 build or link was run in this environment, so every "dead stub" claim is a source-level claim (no caller exists in the module), not a linked-binary observation.
