# Round 5 — Section 02: Launchstation — mmce_cmds.c remainder + ata_bd / usbmass_bd build glue (Task 2 remainders)

Repo: NathanNeurotic/Launchstation, pin `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (verified `git rev-parse HEAD`; no fetch/update; `git status --porcelain` empty at start and at end — READ ONLY honoured).
Scope note: READ = read/grepped in the source at the pin in this pass. INFERRED = conclusion depending on protocol/SDK-package behaviour not in the tree. No PS2 build was run; nothing here is a build or hardware claim. LESS NOT MORE governs every fix. Not repeated: LAUNCHSTATION-054 (SET_GAMEID strcpy), -055 (GET_GAMEID strcpy), -057 (mmce_fs.c devctl `*(u32*)arg` derefs — that switch is in `mmce_fs.c`, not this section's file), and every other finding ≤ -096.

---

## (a) Coverage ledger

| File | Lines | Coverage |
|---|---|---|
| `iop/mmceman/src/mmce_cmds.c` | 344 | **Read end to end, 1–344, this pass** — all 11 command functions |
| `iop/mmceman/include/mmce_cmds.h` | 63 | Read in full (prototypes/enums cross-check vs the .c) |
| `iop/mmceman/include/mmce_sio2.h` | 48 | Read in full (already read R4; re-used for the `tx_rx_pio(u8,u8,…)` signature) |
| `iop/ata_bd/include/atad.h` | 135 | **Read in full, this pass** |
| `iop/ata_bd/src/exports.tab` | 28 | **Read in full, this pass** |
| `iop/ata_bd/src/imports.lst` | 56 | **Read in full, this pass** |
| `iop/ata_bd/src/irx_imports.h` | 34 | **Read in full, this pass** |
| `iop/usbmass_bd/src/imports.lst` | 40 | **Read in full, this pass** |
| `iop/usbmass_bd/src/irx_imports.h` | 30 | **Read in full, this pass** |

Supporting greps only (not re-reads, per the brief): symbol-definition/call counts in `iop/ata_bd/src/ps2atad.c` (fully read R4), `iop/usbmass_bd/src/{main,usb_mass,scsi}.c` (fully read R4), caller sites in `iop/mmceman/src/mmce_fs.c` devctl switch (:1327–1406) and `iop/mmceman/src/mmceman.c` (:27–59), the in-tree SDK header copy `iop/usbd-ra/include/usbd_macro.h` (macro expansion of the USBD transfer helpers), and the `ps2.yaml` build stanzas for `ata_bd` (:395–407) and `usbmass_bd_fork` (:190–199).

Excluded by the brief, confirmed present but **not re-filed**: the two game-ID bodies `mmce_cmd_get_gameid` (`mmce_cmds.c:195–224`, LAUNCHSTATION-055) and `mmce_cmd_set_gameid` (`mmce_cmds.c:226–257`, LAUNCHSTATION-054).

---

## (b) Findings

### T2-F1 / Three command setters transmit uninitialised stack bytes to the card / Category 6
- **Locations:** `iop/mmceman/src/mmce_cmds.c:109,112–118,121` (`mmce_cmd_set_card`: `u8 wrbuf[0x8]`, assignments cover `[0]–[6]` only, transfer is `sizeof(wrbuf)` = 8 → `wrbuf[7]` sent uninitialised); `iop/mmceman/src/mmce_cmds.c:169,172–177,180` (`mmce_cmd_set_channel`: `wrbuf[0x7]`, assignments cover `[0]–[5]`, 7 sent → `wrbuf[6]` uninitialised); `iop/mmceman/src/mmce_cmds.c:290,293–295,298` (`mmce_cmd_reset`: `wrbuf[0x5]`, assignments cover `[0]–[2]`, 5 sent → `wrbuf[3]` and `wrbuf[4]` uninitialised). Transmit path: `mmce_sio2_tx_rx_pio` clocks out exactly `tx_size` bytes from the buffer (`iop/mmceman/src/mmce_sio2.c:212–214`, signature at `iop/mmceman/include/mmce_sio2.h:36`).
- **Problem:** READ. Three of the eleven commands send 1–2 stack-residue bytes to the MMCE firmware on every call. The file's own convention proves trailing bytes are meant to be defined values: `mmce_cmd_ping` explicitly zero-fills its padding (`mmce_cmds.c:20–23`), `mmce_cmd_set_card_channel` explicitly writes a `0xFF` termination byte (`mmce_cmds.c:328`), and every other function in the file assigns every byte it sends (see checked-clean). Two consequences: (1) IOP stack contents leak over SIO2 to an external device; (2) the wire packet is nondeterministic — if the firmware reads those positions at all, the current behaviour is already intermittently wrong, and no working firmware can be depending on a specific value there (it cannot know it). Whether real firmware ignores, checks, or acts on the trailing bytes is INFERRED (no protocol document in-tree); the transmission itself is READ.
- **Fix:** Zero-fill the three buffers before the field assignments (`memset(wrbuf, 0, sizeof(wrbuf));` — `sysclib.h` is already included at `mmce_cmds.c:2`), matching ping's zero-padding precedent. Do **not** shrink the transfer sizes: packet lengths are the protocol's, only their content is undefined. 3 added lines, 0 wire-format changes.
- **Justification (ADD):** The additions are the smallest change that makes the already-sent bytes deterministic; the alternative (per-index `= 0` assignments, ping-style) is 4 lines instead of 3 and easier to regress when a buffer is resized.
- **Benefit:** Deterministic packets; no stack residue leaves the IOP; the three functions join the file's own fully-initialised majority.
- **Effort:** 3 lines.
- **Risk:** Minimal. If the firmware ignores the trailing bytes, nothing changes; if it reads them, today it reads garbage, so a defined `0` cannot be a regression against any behaviour that currently works reliably. Maintainer should confirm the pad value against the protocol if a spec exists (in-file precedent for trailing padding is ping's `0`, not the `0xFF` reserved/header byte).
- **Confidence:** High that the bytes are sent uninitialised (READ); Medium on real-world impact (firmware's use of them is INFERRED).

### T2-F2 / `mmce_cmd_get_status`, `mmce_cmd_get_card` and `mmce_cmd_get_channel` are one function pasted three times / Category 2
- **Locations:** `iop/mmceman/src/mmce_cmds.c:47–74` (get_status), `iop/mmceman/src/mmce_cmds.c:76–103` (get_card), `iop/mmceman/src/mmce_cmds.c:136–163` (get_channel) — 28 lines each, byte-identical except the command enum at :55 / :84 / :144 and the function name (the bodies are otherwise character-for-character the same, including the reply decode `rdbuf[0x3] << 8 | rdbuf[0x4]`).
- **Problem:** READ. Three copies of the same send-a-3-byte-command / return-a-u16-reply logic. Any fix to the shared logic (reply validation, timeout choice, the T2-F1 class of buffer bug) must currently be made three times and can silently be made twice. The duplication is live code with three distinct devctl callers (`iop/mmceman/src/mmce_fs.c:1333,1337,1350`), so this is consolidation, not deletion of reachable behaviour. (The stale `//TODO:` at `mmce_cmds.c:46` above get_status — a fully implemented function with two callers — can go in the same edit.)
- **Fix:** One static helper, e.g. `static int mmce_cmd_get_u16(u8 cmd)` holding the single body, plus three one-line wrappers keeping the existing public names/signatures in `iop/mmceman/include/mmce_cmds.h:53,54,56` (callers unchanged). Net ≈ −50 lines. Do not generalise further into the setter boilerplate in the same change — the getters are the exact-duplicate, zero-risk core.
- **Benefit:** One place to fix/validate the u16-reply command shape; ~50 fewer lines in a 344-line file.
- **Effort:** Small, mechanical.
- **Risk:** Minimal — wrappers preserve every exported symbol and the devctl dispatch; the only behavioural surface is identical code executed once instead of thrice.
- **Confidence:** High (READ; the three bodies were compared line by line this pass).

### T2-F3 / ata_bd imports `bdm_disconnect_bd` and never calls it / Category 1
- **Locations:** `iop/ata_bd/src/imports.lst:54` (`I_bdm_disconnect_bd`, inside the `#ifdef ATA_ENABLE_BDM` block :51–56 — a block the Launchstation build does enable, `ps2.yaml:405`).
- **Problem:** READ. Grep of the module's only source, `iop/ata_bd/src/ps2atad.c` (fully read R4; symbol-count grep this pass), finds `bdm_connect_bd` called once (`ps2atad.c:1381`) and `bdm_disconnect_bd` called zero times. There is no path that could call it: the BDM `stop` callback only issues a standby (`ps2atad.c:1575–1580`) and `_exit` returns `MODULE_RESIDENT_END` (`ps2atad.c:389`), so the module never unloads or disconnects a device. The import stub is dead weight in the shipped IRX.
- **Fix:** Delete `iop/ata_bd/src/imports.lst:54` (1 line). If an unload/disconnect path is ever added, the line returns with it.
- **Benefit:** One fewer import stub/table entry in a resident IOP module; the imports list again states exactly what the module uses.
- **Effort:** 1 line.
- **Risk:** Negligible — an unused IRX import has no runtime effect beyond its stub; no caller exists to break.
- **Confidence:** High (READ + grep-verified caller count of zero).

### T2-F4 / usbmass_bd imports `sceUsbdSetPrivateData` and never calls it / Category 1
- **Locations:** `iop/usbmass_bd/src/imports.lst:36` (`I_sceUsbdSetPrivateData`, usbd block :31–40).
- **Problem:** READ. No call to `sceUsbdSetPrivateData` (nor its `UsbSetDevicePrivateData` alias) exists anywhere in the module's three sources (`main.c`, `usb_mass.c`, `scsi.c` — fully read R4, symbol grep this pass). The driver deliberately tracks devices in its own array instead: `g_mass_device[i].scsi.priv = &g_mass_device[i]` (`iop/usbmass_bd/src/usb_mass.c:842`) with connect/disconnect keyed by `devId` (`usb_mass.c:632,726`), so the USBD private-data slot is never used by design, not by oversight. The import stub is dead weight in the shipped IRX.
- **Fix:** Delete `iop/usbmass_bd/src/imports.lst:36` (1 line).
- **Benefit:** One fewer import stub/table entry; the imports list again states exactly what the module uses.
- **Effort:** 1 line.
- **Risk:** Negligible — same reasoning as T2-F3.
- **Confidence:** High (READ + grep-verified caller count of zero).

---

## (c) Import/export cross-check tables

### ata_bd — exports (exports.tab vs ps2atad.c vs atad.h import slots)

Export table version and client import-table version **agree**: `DECLARE_EXPORT_TABLE(atad, 1, 3)` (`exports.tab:3`, comment :1) and `DECLARE_IMPORT_TABLE(atad, 1, 3)` (`atad.h:79`). `IRX_ID(MODNAME, 2, 7)` in `ps2atad.c:51` is the *driver* version, not the interface version — the RiptOPL clone's vendored copy carries the identical 2,7 / 1,3 pairing (READ, cross-repo grep), so there is **no version skew**; the apparent mismatch is upstream's standing convention and is dissolved, not filed.

| Slot | Export (exports.tab) | atad.h DECLARE_IMPORT | Defined in ps2atad.c |
|---|---|---|---|
| 0 | `_start` (:4) | — (system) | Yes (:263) |
| 1 | `_retonly` (:5) | — | Yes (`exports.tab:28`) |
| 2 | `_exit` (:6) | — | Yes (:389) |
| 3 | `_retonly` (:7) | — | Yes (same stub) |
| 4 | `sceAtaInit` (:9) | `I_sceAtaInit` 4 (`atad.h:82`) | Yes (:1388) |
| 5 | `sceAtaSoftReset` (:10) | 5 (:83) | Yes (:877) |
| 6 | `sceAtaExecCmd` (:11) | 6 (:84) | Yes (:533) |
| 7 | `sceAtaWaitResult` (:12) | 7 (:85) | Yes (:778) |
| 8 | `sceAtaGetError` (:13) | 8 (:86) | Yes (:424) |
| 9 | `sceAtaDmaTransfer` (:14) | 9 (:87) | Yes (:1036) |
| 10 | `sceAtaSecuritySetPassword` (:15) | 10 (:88) | Yes (:1122) |
| 11 | `sceAtaSecurityUnLock` (:16) | 11 (:89) | Yes (:1143) |
| 12 | `sceAtaSecurityEraseUnit` (:17) | 12 (:90) | Yes (:1169) |
| 13 | `sceAtaIdle` (:18) | 13 (:91) | Yes (:912) |
| 14 | `sceAtaGetSceId` (:19) | 14 (:92) | Yes (:943) |
| 15 | `sceAtaSmartReturnStatus` (:20) | 15 (:93) | Yes (:975) |
| 16 | `sceAtaSmartSaveAttr` (:21) | 16 (:94) | Yes (:964) |
| 17 | `sceAtaFlushCache` (:22) | 17 (:95) | Yes (:901) |
| 18 | `sceAtaIdleImmediate` (:23) | 18 (:96) | Yes (:1518) |
| 19 | `ata_device_sector_io64` (:24) | 19 (:97) | Yes (:1041) |
| 20 | `ata_set_command_type` (:25) | 20 (:98) | Yes (:515) |

Result: 17/17 named exports defined, slot numbers match name-for-name, no export lacks an implementation, no implemented public function lacks an export. Slots 19–20 have no in-tree external consumer (`ata_device_sector_io64` is used internally by the BDM read/write callbacks, `ps2atad.c:1554,1563`; `ata_set_command_type` has no in-tree caller at all) — **not filed**: they are the upstream atad ABI surface that `atad.h` advertises to out-of-tree importers, and removing a slot breaks that ABI for no in-tree gain.

### ata_bd — imports (imports.lst vs ps2atad.c usage; build defines ATA_ENABLE_BDM=1, ATA_USE_DEV9=1, ATA_GAMESTAR_WORKAROUND=1 — `ps2.yaml:404–406`)

| Import (imports.lst) | Used in ps2atad.c? |
|---|---|
| `RegisterLibraryEntries` (:2) | Yes (:378) |
| `DelayThread` (:6), `SetAlarm` (:7), `CancelAlarm` (:8), `USec2SysClock` (:9) | Yes (:… DelayThread ×5; SetAlarm :625; CancelAlarm :850; USec2SysClock :623) |
| `CreateEventFlag` (:13), `iSetEventFlag` (:14), `ClearEventFlag` (:15), `WaitEventFlag` (:16) | Yes (all ≥1) |
| `printf` (:20) | Yes (via the module's `M_PRINTF` wrapper) |
| `memcpy` (:24), `memset` (:25) | Yes |
| dev9 block (:30–37, `#ifdef ATA_USE_DEV9` — defined) | All 8 used (Spd* / Dev9* / dev9*Pre/PostDmaCb, ≥1 each) |
| aifdev9 block (:43–47, `#ifdef ATA_USE_AIFDEV9` — **not** defined in this build) | All 5 referenced only inside matching `#ifdef ATA_USE_AIFDEV9` code (:346–347 etc.) — import block and use sites are guarded identically, so nothing dangles in either build configuration |
| `bdm_connect_bd` (:53, BDM defined) | Yes (:1381) |
| `bdm_disconnect_bd` (:54, BDM defined) | **No — zero calls → T2-F3** |

Used-but-undeclared: **none found** — every external call in `ps2atad.c` is covered by the table above (grep sweep for thread/alarm/event/libc/dev9/aif/bdm names this pass). `irx_imports.h` mirrors the conditional structure exactly: `aifdev9.h`/`bdm.h`/`dev9.h` included under the same three `#ifdef`s (`irx_imports.h:18–26`), the five unconditional headers matching the five unconditional import blocks (:28–32).

### usbmass_bd — imports (imports.lst vs main.c + usb_mass.c + scsi.c; build defines: none, `ps2.yaml:190–199`)

| Import (imports.lst) | Used? |
|---|---|
| `bdm_connect_bd` (:2), `bdm_disconnect_bd` (:3) | Yes, both in `scsi.c` (connect/disconnect) |
| `printf` (:8, `#ifndef MINI_DRIVER` — MINI_DRIVER is defined only for the separate `usbd_ra` target, `ps2.yaml:59–61`, not for `usbmass_bd_fork`) | Yes — via `M_PRINTF`, which expands to `printf` when MINI_DRIVER is undefined (`iop/usbmass_bd/src/include/module_debug.h:9–10`); 34 M_PRINTF sites across the three sources |
| `memset` (:13), `memcpy` (:14) | Yes (memset ×4 in scsi.c; memcpy in usb_mass.c + scsi.c) |
| `CreateThread` (:18), `StartThread` (:19), `DeleteThread` (:20), `DelayThread` (:21) | Yes (init/update thread in usb_mass.c; DeleteThread on the StartThread failure path, `usb_mass.c:896`; DelayThread in both .c files) |
| `CreateSema` (:25), `SignalSema` (:26), `WaitSema` (:27), `DeleteSema` (:28) | Yes (all in usb_mass.c) |
| `sceUsbdScanStaticDescriptor` (:32) | Yes (usb_mass.c) |
| `sceUsbdOpenPipe` (:33), `sceUsbdOpenPipeAligned` (:34), `sceUsbdClosePipe` (:35) | Yes (usb_mass.c) |
| `sceUsbdSetPrivateData` (:36) | **No — zero calls in any source → T2-F4** |
| `sceUsbdTransferPipe` (:37) | Yes — **indirectly**: never named at a call site, but it is the expansion target of every transfer helper the module does call (next row) |
| `sceUsbdRegisterLdd` (:38), `sceUsbdGetDeviceLocation` (:39) | Yes (`usb_mass.c:874`; connect path) |

Called-but-not-in-imports.lst, resolved: `sceUsbdBulkTransfer` (usb_mass.c:123,270,391,511,519,528), `sceUsbdControlTransfer` (:227,339), `sceUsbdSetConfiguration` (:165), `sceUsbdSetInterface` (:183), `sceUsbdClearEndpointFeature` (:200) are **not imports** — they are the macro/static-inline helpers of `usbd_macro.h` (included at `usb_mass.c:12`), and every one of them expands to `sceUsbdTransferPipe` (in-tree SDK header copy at `iop/usbd-ra/include/usbd_macro.h:20–40`: BulkTransfer is a macro to TransferPipe :33–34; ControlTransfer is a static function returning TransferPipe :20–30; SetConfiguration/SetInterface/ClearEndpointFeature are macros over ControlTransfer). READ for the in-tree header copy and the include line; the build resolves `<usbd.h>`/`<usbd_macro.h>` from the SDK package (`ps2.yaml:199`), whose identity with the in-tree copy is INFERRED (same SDK lineage, standard header). No genuinely undeclared import was found; `__builtin_alloca` in `scsi.c:321` needs no import. `irx_imports.h:21–26` includes exactly the six libraries the imports list uses (bdm, stdio, sysclib, thbase, thsemap, usbd) — one cosmetic asymmetry, not filed: it includes `<stdio.h>` unconditionally while `imports.lst` guards `I_printf` with `#ifndef MINI_DRIVER`; harmless (declarations only) and moot in this build.

usbmass_bd has no `exports.tab` (not in the brief's file list; the module exports nothing — BDM/USBD registration is by callback struct, `usb_mass.c:867–874`) — nothing to cross-check on the export side.

### mmce_cmds — header/implementation/caller cross-check

All 11 prototypes in `iop/mmceman/include/mmce_cmds.h:52–62` match the definitions in `mmce_cmds.c` name-for-name and signature-for-signature (header ordering differs cosmetically). All 11 have at least one live caller — **no dead command function exists in the file**: the devctl switch in `iop/mmceman/src/mmce_fs.c:1328–1390` reaches ping, get_status, get_card, set_card, get_channel, set_channel, get_gameid (-055 path), set_gameid (-054 path), reset, unmount_bootcard and set_card_channel; `mmce_cmd_get_status` and `mmce_cmd_reset` are additionally called from the active-card discovery path (`mmce_fs.c:106,112`), and ping/reset from module init (`iop/mmceman/src/mmceman.c:35,50`).

---

## (d) Checked-and-clean list

- **Fully-initialised senders (the T2-F1 majority):** `mmce_cmd_ping` assigns all 7 wrbuf bytes (`mmce_cmds.c:17–23`); `mmce_cmd_get_status` / `get_card` / `get_channel` / `get_gameid` / `unmount_bootcard` assign all 3 (:54–56, :83–85, :143–145, :202–204, :265–267); `mmce_cmd_set_card_channel` assigns all 9 including its termination byte (:320–328). READ.
- **No reply field is used as a count, length or index inside mmce_cmds.c** (outside the excluded game-ID paths): the getters assemble `rdbuf[3..4]` (and ping `rdbuf[3..5]`) into a return *value* only. The one downstream indexing use, module init's product-ID decode, is bounds-checked by its caller (`id < 5` before `mmce_product_ids[id]`, `iop/mmceman/src/mmceman.c:39–42`). READ.
- **Reply validation posture is uniform:** every function checks `rdbuf[0x1] == MMCE_REPLY_CONST` before using any other reply byte, and every timeout (`res == -1`) returns before the reply buffer is read. `rdbuf[0]`/`rdbuf[2]` are never checked — **not filed**: without the firmware protocol document (not in-tree) it cannot be shown they carry a checkable value rather than echo/reserved; INFERRED either way.
- **Transfer sizes fit the `u8` parameters** of `mmce_sio2_tx_rx_pio` for every non-game-ID call (largest is 9, set_card_channel). The game-ID size arithmetic is LAUNCHSTATION-054/-055 territory, excluded. READ.
- **Ping's 200 ms timeout vs 1 s everywhere else** (`mmce_cmds.c:26` vs all other call sites): consistent with its probe role — its init caller retries it in a loop (`MMCE_PING_ATTEMPTS`, `mmceman.c:34–35`). Not an inconsistency worth filing. READ.
- **ata_bd version pairing is not skew** (see table note): export table 1.3 == import table 1.3; `IRX_ID 2,7` is the driver version and matches the vendored copy in the RiptOPL clone. Dissolved. READ.
- **ata_bd conditional glue is self-consistent:** every `#ifdef` block in `imports.lst` (DEV9 :28, AIFDEV9 :41, BDM :51) has its mirror in `irx_imports.h` and its use sites in `ps2atad.c` under the same guard; the build's define set (`ps2.yaml:404–406`) enables exactly DEV9+BDM. READ.
- **usbmass_bd printf import is live, not dead:** the literal string `printf` never appears at a call site, but `M_PRINTF` expands to it in this build's configuration (see table). A naive grep-only pass would mis-file this — dissolved with the macro evidence. READ.
- **Nits observed, deliberately not filed:** (1) ping's bit-range comment (`mmce_cmds.c:33–35`) says "bits 24-16 / 16-8 / 8-0" for an assembly that is bits 23–16 / 15–8 / 7–0 (:37) and that its caller decodes consistently with the code (`mmceman.c:39–47`) — comment-only, no behaviour; (2) the same uninitialised-tail pattern exists at `mmce_cmds.c:244` in `mmce_cmd_set_gameid` (sends `len + 5` bytes for `len + 4` bytes of content) — **not filed per this section's scope** (game-ID path, LAUNCHSTATION-054); noted so the -054 fix can absorb it: bounding `len` there does not by itself define that fifth byte.

## (e) Still-unread

- Nothing in this section's assigned file list remains unread: `mmce_cmds.c` was read end to end and all seven glue files in full.
- Deliberately out of scope and untouched this pass: `iop/vmcman/src/irx_imports.h` and `iop/vmcman/src/exports.tab` (the brief explicitly excluded them); `ps2atad.c` / `usb_mass.c` / `scsi.c` / `main.c` bodies (fully read in Round 4 — this pass used symbol greps only, per the brief); the SDK package's own `<usbd.h>`/`<usbd_macro.h>` as resolved at build time (not in this repo; the in-tree `iop/usbd-ra/include/` copies were used as the reference, flagged INFERRED where relied on); the MMCE firmware protocol document (not in-tree — the reason reply-byte and pad-value questions above stay at INFERRED weight).

---

## Section totals
- Lines read in full this pass: mmce_cmds.c 344 · atad.h 135 · ata exports.tab 28 · ata imports.lst 56 · ata irx_imports.h 34 · usbmass imports.lst 40 · usbmass irx_imports.h 30 · mmce_cmds.h 63 · supporting headers/stanzas ≈ 120. Total ≈ 850 lines, plus targeted greps across 5 already-read sources.
- Findings: 4 (T2-F1…T2-F4) — Cat 6 ×1, Cat 2 ×1, Cat 1 ×2.
- Clone state at end: pin unchanged, `git status --porcelain` empty.
