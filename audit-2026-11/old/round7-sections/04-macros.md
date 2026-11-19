# Round 7 — Section 04: Header Macro Census (Launchstation @ 9fb0598a79f0)

Read-only. Pin verified held (`9fb0598 style(docs): complete neutral palette… (#386)`), `git status` clean at end.
Exemplar (NOT re-filed): **LAUNCHSTATION-119** — `GET_XPARAM_DB_SIZE()` ≡ 1 at `iop/xparam/include/xparam.h:36`
(`sizeof(*XPARAMS)/sizeof(XPARAMS[0])` — both operands are the size of one `xparam_t` element, so the
"count" is always 1; its sole call site `iop/xparam/src/xparam.c:55` loops over 1 of the 292-entry
`XPARAMS[]` in `iop/xparam/src/database_merged.c`). This section asks: are there siblings?

## Verdict up front

**No. Zero new candidates.** Every other arithmetic macro in first-party headers evaluates to what its
name promises, and every latent textbook flaw found (unparenthesised argument, double evaluation) is
provably **not triggered** by any real call site. The census below is the proof.

## Method & scope

`grep -rnE '^\s*#define[[:space:]]+[A-Za-z_][A-Za-z0-9_]*\('` over the tasked trees:
`include/*.h`, `src/*.h`, `iop/*/include/*.h`, `iop/*/src/*.h`, `iop/include_compat/*.h`,
`ee_libs/**/*.h`. Excluded per task: `include/qrcodegen.h` (vendored), `include/dash_font_data.h`
(pure data — contains no `#define (` anyway), libsmb2 (not in clone), PS2SDK headers (not in repo),
`tests/**` (test shims/stubs, not first-party product headers). Two `#define`s in
`ee_libs/iopreboot/SifIopRebootBuffer.c` are in a `.c` file, not a header — excluded, noted here for
completeness. A supplementary sweep of the remaining first-party header locations
(`iop/*/*.h`, `iop/*/*/*.h` — ds34bt, unfs4, oldlibs/ps2ftpd, ps2hdd_osd, smb2man/usmb2, smbman,
usbmass_bd) is Appendix B so no first-party header escapes the census.

**Census size: 236 `#define` lines** = 200 in the tasked scope (196 active + 4 commented-out) + 36 in Appendix B.
**Arithmetic macros hand-evaluated: 159** (145 tasked scope + 14 Appendix B), each checked against its call sites.
Conditional re-definitions of the same name (debug/consumer variants) are counted as separate lines, as written.

Verdict key: **OK** = evaluated, matches name/intent and call-site use · **not-arithmetic** = pass-through /
logging / token-pasting, no size/count/index/length math · **latent, not triggered** = textbook flaw present
but no real call site triggers it (explicitly *not* a candidate per task rules) · **exemplar** = -119 itself.

---

## Census — tasked scope (200 lines)

### include/cdvd_macro.h — 8 — all not-arithmetic
| Line | Macro | Body (essence) | Verdict |
|---|---|---|---|
| 5–8 | `LCDVD_FLUSHCACHE()`, `LCDVD_INIT()`, `LCDVD_STOP()`, `LCDVD_DISKREADY(x)` | aliases to `CDVD_*` (libcdvd branch) | not-arithmetic |
| 10–13 | same 4 names | aliases to `sceCd*` / empty (SDK branch) | not-arithmetic |

### include/launchelf.h — 9
| Line | Macro | Evaluation | Verdict |
|---|---|---|---|
| 97 | `WLE_DEG_TO_RADF(_deg)` | `((_deg) * 0.01745329251994329577f)` = degrees × π/180. Arg parenthesised, evaluated once. | OK (arithmetic) |
| 101 | `cosdgf(_deg)` | `cosf(WLE_DEG_TO_RADF(_deg))` — cosine in degrees, as named. | OK (arithmetic) |
| 105 | `sindgf(_deg)` | `sinf(WLE_DEG_TO_RADF(_deg))` — sine in degrees, as named. | OK (arithmetic) |
| 158/161/164 | `DPRINTF(format, args...)` ×3 | sio_printf / coloured printf / stripped — build-variant logging | not-arithmetic |
| 676 | `lang(id, name, value)` | `LANG_##name,` — X-macro enum generation over `lang.h` | not-arithmetic |
| 682 | `LNG(name)` | `Lang_String[LANG_##name].String` — index is a compile-time enum constant, no arithmetic | not-arithmetic |
| 683 | `LNG_DEF(name)` | same, over `Lang_Default[]` | not-arithmetic |

Call-site note: `cosdgf`/`sindgf`/`WLE_DEG_TO_RADF` have **no call sites anywhere in the tree**
(grep over all files) — dead compatibility helpers for newer PS2SDK toolchains, correct as written.

### iop/mmceman/include/module_debug.h — 2 · iop/mx4sio_bd/src/module_debug.h — 3 · iop/udpfs_smap/include/mprintf.h — 2 · iop/vmcman/src/mcman-internal.h — 7
All `DPRINTF` / `M_PRINTF` / `M_DEBUG` build-variant logging macros, plus vmcman's 3 `DPRINTF` variants and
4 `HAKAMA_SIGNALSEMA()`/`HAKAMA_WAITSEMA()` empty stubs (arcade-MCMAN wrappers, bodies commented out).
**All not-arithmetic.**

### iop/mmceman/include/sio2regs.h — 68 lines (66 active + 2 commented-out) — ALL arithmetic, ALL OK
### iop/mx4sio_bd/src/sio2regs.h — 68 lines (66 active + 2 commented-out) — ALL arithmetic, ALL OK

Two near-identical SIO2 register-field header copies (132 active macros). Every macro is one of two idioms,
hand-checked field-by-field and machine-cross-checked for mask/shift consistency (mask has no bits below
the shift; field mask contiguous — **zero anomalies in either copy**):

- **Pack:** `((((u32)(x)) << s) & M)` or `((((u32)(x)) & f) << s)` — `PCTRL0_ATT_LOW_PER` (<<0,&0xFF),
  `PCTRL0_ATT_MIN_HIGH_PER` (<<8,&0xFF00), `PCTRL0_BAUD0_DIV` (<<16,&0xFF0000), `PCTRL0_BAUD1_DIV`
  (<<24,&0xFF000000), `PCTRL1_ACK_TIMEOUT_AFTER`/`_PER` (<<0,&0xFFFF), `PCTRL1_WAIT_CYCLES_AFTER_ACK_LOW` /
  `PCTRL1_INTER_BYTE_PER` (<<16,&0xFF0000), `PCTRL1_UNK24`, `PCTRL1_IF_MODE_SPI_DIFF`, all `TR_CTRL_*`
  (PORT_NR &0x3<<0, PAUSE, UNK03, TX/RX_MODE_PIO_DMA, NORMAL_TR, SPECIAL_TR, **TX_DATA_SZ &0x1FF<<8**,
  UNK17, **RX_DATA_SZ &0x1FF<<18**, UNK27/28/29, BAUD_DIV <<30, WAIT_ACK_FOREVER <<31), all `CTRL_*`
  (TR_START … SLAVE_MODE_EN, incl. `CTRL_UNK2912` (&0x3FFFF)<<12 = bits 12–29, exactly as its name encodes).
- **Extract:** `((((u32)(x)) >> s) & M)` — all `STAT_*` (UNK0300, NEED_DMA_DATA_TX/RX, UNK0706, QUEUE_SLOT_PROC,
  TR_IDLE, ERR_TX/RX_FIFO_UOFLOW, ERR_ACK_MISSING), all `CONN_STAT_*` (CDC0–3, SAS0–3), all `FSTAT_*`
  (TX_SZ &0x1FF, RX_SZ >>16 &0x1FF, overflow/underflow bits), `GET_ISTAT_TR_COMP`, `GET_ISTAT_TR_ERR`.

Call sites checked: composed with `|` into SIO2 control registers, e.g. `iop/mmceman/src/mmce_sio2.c:110-113`
(`PCTRL0_*` constants), `:207/:448/:460` `TR_CTRL_TX_DATA_SZ(tx_size|0|256|pio_size)` — argument evaluated
once, masked to the 9-bit hardware field exactly as intended; truncation above 511 is the register's own
field width, not a macro defect. Same pattern in `iop/mmceman/src/mmceigr.c:36,128-131`.
Divergence between copies is naming only (`ACK_TIMEOUT_AFTER` vs `_PER` + `INTER_BYTE_PER` vs
`WAIT_CYCLES_AFTER_ACK_LOW`); every shared field has identical shift/mask in both copies.
Commented-out pair in both files: `GET_TXFPNTS_HEAD(x)` / `SET_TXFPNTS_HEAD(x)` (mmceman :167-168,
mx4sio :139-140) — not compiled, not counted as active, noted so the line count reconciles.

One latent, not triggered: `STAT_ERR_QUEUE_SLOT(x, slot)` = `((((u32)(x)) >> (slot + 16)) & 1)` in both
copies — `slot` is not itself parenthesised inside the addition. **Zero call sites** in the tree.
Not a candidate.

### iop/mx4sio_bd/src/spi_sdcard_driver_config.h — 1 — latent, not triggered
`SPISD_ASSERT(cond)` = `while (!cond) {};` (:9-10). `cond` is unparenthesised, so a hypothetical
`SPISD_ASSERT(a == b)` would parse as `(!a) == b`. **Zero call sites** — the macro is defined and never
used anywhere under `iop/mx4sio_bd/`. Dead + untriggered: not a candidate.

### iop/usbd-ra/include/usbd_macro.h — 24 — all not-arithmetic
`sceUsbdIsochronousTransfer`, `sceUsbdBulkTransfer`, `sceUsbdInterruptTransfer`,
`sceUsbdClearDeviceFeature`, `sceUsbdSetDeviceFeature`, `sceUsbdGetConfiguration`, `sceUsbdSetConfiguration`,
`sceUsbdGetDescriptor`, `sceUsbdSetDeviceDescriptor`, `sceUsbdGetDeviceStatus`, `sceUsbdSetAddress`,
`sceUsbdClearInterfaceFeature`, `sceUsbdSetInterfaceFeature`, `sceUsbdGetInterface`, `sceUsbdSetInterface`,
`sceUsbdGetInterfaceDescriptor`, `sceUsbdSetInterfaceDescriptor`, `sceUsbdGetInterfaceStatus`,
`sceUsbdClearEndpointFeature`, `sceUsbdSetEndpointFeature`, `sceUsbdGetEndpointStatus`,
`sceUsbdGetEndpointDescriptor`, `sceUsbdSetEndpointDescriptor`, `sceUsbdSynchFrame`.
All are fully-parenthesised argument pass-throughs to `sceUsbdTransferPipe` / `sceUsbdControlTransfer`
with constant request fields (verified :33-125); no size/count arithmetic of their own — the `len`
argument is forwarded once, parenthesised.

### iop/usbd-ra/src/usbdpriv.h — 7
| Line | Macro | Evaluation | Verdict |
|---|---|---|---|
| 26/28 | `dbg_printf(a...)` ×2 | printf / `(void)0` variants | not-arithmetic |
| 31 | `READ_UINT16(a)` | `(((u8 *)a)[0] \| (((u8 *)a)[1] << 8))` — correct little-endian u16 decode | OK value; **latent, not triggered**: `a` evaluated twice — both call sites (`iop/usbd-ra/src/hub.c:418,423`) pass the side-effect-free `&desc->wTotalLength` |
| 277 | `BIT(x)` | `(((u32)1) << (x))` — correct; 20 call sites in usbd-ra, all constant/simple args | OK (arithmetic) |
| 288 | `ED_HALTED(a)` | `((u32)((a).tdHead) & 1)` — halted bit, as named | OK (arithmetic) |
| 289 | `ED_SKIPPED(a)` | `((u32)((a).hcArea) & HCED_SKIP)` | OK (arithmetic) |
| 291 | `TD_HCAREA(CC, T, DI, DP, R)` | `(((CC) << 12) \| ((T) << 8) \| ((DI) << 5) \| ((DP) << 3) \| ((R) << 2))` — field positions match the OHCI TD control layout it feeds (`<< 16` into `HcArea` at call sites) | OK value; **latent, not triggered**: args unparenthesised, but all 6 call sites (`iop/usbd-ra/src/usbio.c:103,114,116,128,130,239`) pass plain constants/enum names |

### iop/xparam/include/xparam.h — 1
| Line | Macro | Verdict |
|---|---|---|
| 36 | `GET_XPARAM_DB_SIZE()` | **EXEMPLAR — LAUNCHSTATION-119, already filed. Not re-filed.** It is the *only* sizeof-ratio macro in the entire census: no other header uses the `sizeof(arr)/sizeof(arr[0])` idiom at all, in correct or broken form. |

---

## Appendix B — supplementary first-party headers outside the tasked globs (36 lines)

| File | Macros | Verdict |
|---|---|---|
| `iop/ds34bt/iop/ds34bt.h:77-83` | `pad_status_clear/set/check(flag, pad)`, `hci_event_flag_clear/set/check(flag)` — `ds34pad[pad].status &= ~flag` / `\|= flag` / `& flag` bit ops | OK (arithmetic) — index/mask forwarded once each |
| `iop/ds34bt/iop/ds34bt.h:223` | `l2cap_handle_ok(handle)` — `(((u16)(l2cap_buf[0] \| (l2cap_buf[1] << 8)) & 0x0FFF) == (u16)(handle & 0x0FFF))` — correct LE decode + 12-bit handle mask both sides | OK (arithmetic) |
| `iop/nfsman/unfs4/unfs4.h:177-212` | `unfs4_close`, `unfs4_pread`, `unfs4_pwrite`, `unfs4_closedir`, `unfs4_unlink`, `unfs4_rmdir` — aliases to `free`/`unfs4_prw` (opcodes 25/38)/`unfs4_remove`; count/offset forwarded once, parenthesised | not-arithmetic |
| `iop/oldlibs/ps2ftpd/src/FtpClient.h:47` | `FCOMMAND(a, b, c, d)` — `(((a) << 24) \| ((b) << 16) \| ((c) << 8) \| (d))` — correct 4-char tag packing, all args parenthesised, used once | OK (arithmetic) |
| `iop/oldlibs/ps2ftpd/src/FtpServer.h:38` | `FtpServer_ClientTraverse(server)` — multi-statement list-walk block, `(server)` parenthesised throughout | not-arithmetic |
| `iop/ps2hdd_osd/apa-opt.h:4` | `APA_PRINTF(format, ...)` — printf pass-through | not-arithmetic |
| `iop/ps2hdd_osd/libapa.h:191` | `journalCheckSum(header)` — cast + call alias to `apaCheckSum(..., 1)` | not-arithmetic |
| `iop/smb2man/ps2iop-compat.h:18-23` | `htole16/le16toh/htole32/le32toh/htole64/le64toh(x)` — identity `(x)`; correct because the IOP is little-endian, as the shim intends | OK (arithmetic, identity) |
| `iop/smb2man/usmb2/usmb2.h:98-120` | `usmb2_closedir` (×2 conditional dupes), `usmb2_close`, `usmb2_unlink`, `usmb2_rmdir` — aliases to `free`/`usmb2_delete` with constant flags 0x40/0x01 | not-arithmetic |
| `iop/smbman/debug.h:10,12` | `DPRINTF(args...)` ×2 | not-arithmetic |
| `iop/usbmass_bd/src/include/module_debug.h:10-33` | `M_PRINTF` ×2, `M_DEBUG` ×2 logging; `U64_2XU32(val)` (token-pasting declaration + `memcpy(..., sizeof(...))`, a statement macro, no value arithmetic); `DEBUG_U64_2XU32(val)` ×2 wrappers | not-arithmetic |

---

## Object-like size/count macros used in arithmetic — brief census, all checked clean

Every `*SIZE* / *COUNT* / *LEN* / *MAX* / *NUM*` object-like define in the tasked headers was listed;
the ones whose value is itself arithmetic (the rest are plain literals used as bounds/capacities, with no
provably wrong value) were hand-evaluated:

| Macro | Location | Evaluates to | Check |
|---|---|---|---|
| `CLOUD_HTTP_BODY_MAX (256 * 1024)` | `include/cloud_http.h:10` | 262144 | as named |
| `DASH_PNG_MAX_FILE (1536 * 1024)` | `include/dash_internal.h:513` | 1572864 | as named |
| `VKEY_LAYOUT_SIZE (VKEY_LAYOUT_COLS * VKEY_LAYOUT_ROWS)` | `include/launchelf.h:263` | 17 × 5 = **85** | used as `KEY_LEN`/index bound (`src/gui.c:170`, `src/virtual_keyboard.c:186`) — matches the 17×5 layout tables |
| `VKEY_EDITOR_SIZE (VKEY_EDITOR_COLS * VKEY_LAYOUT_ROWS)`, with `VKEY_EDITOR_COLS (VKEY_LAYOUT_COLS + 3)` | `include/launchelf.h:264-265` | 20 × 5 = **100** | bound in `src/editor.c:138`, `src/editor_input.c:38,122` — consistent |
| `IPCONF_MAX_LEN (3 * 16)` | `include/launchelf.h:354` | **48** | sizes `if_conf[]`/`netConfig[IPCONF_MAX_LEN + 64]` (`src/main.c:39,46`) — 3 dotted-quad fields' worth of text, as intended |
| `PS1_CARD_FILE_MAX (PS1_CARD_HEAD_MAX + PS1_CARD_SIZE)` | `include/mc_save_export.h:53` | 3904 + 131072 = **134976** | inclusive upper bound on accepted file size at `src/dash_ps1_card.c:59,104` — matches "largest header + full card" comment |
| `MMCE_SAVE_VERSION_MAX (8u * 1024u * 1024u + 512u * 1024u)` | `include/mmce_save_versions.h:15` | 8.5 MiB | as named; unsigned literals, no overflow |
| `XPARAM_PARAMS_AMMOUNT (PARAM_CACHE_FLASH_CHANNELS + 1)` | `iop/xparam/include/xparam.h:26` | 0x11 + 1 = **18** | exactly the number of `xparam_types_t` enumerators (0x00–0x11); unused elsewhere. (Spelling "AMMOUNT" is cosmetic — not filed.) |
| `PS1_CARD_SIZE 131072u` | `include/mc_ps1_card.h:41` | 128 KiB | correct PS1 card size |

No object-like macro has a provably wrong value. **Nothing filed from this census.**

## Checked-clean summary

- 132 active SIO2 field pack/extract macros (two copies): every shift/mask pair consistent, call sites sane.
- The only sizeof-ratio macro in the repo's first-party headers is the already-filed -119; **the defect class has no siblings**.
- No MIN/MAX-style macro, no alignment-roundup macro, and no other array-count idiom exists in first-party headers (the census is exhaustive — the categories simply do not occur).
- No arithmetic macro is ever invoked with `++`/`--` or any side-effecting argument at any call site.
- Three latent textbook flaws (`READ_UINT16` double evaluation, `TD_HCAREA` unparenthesised args,
  `STAT_ERR_QUEUE_SLOT` unparenthesised `slot`, plus dead `SPISD_ASSERT` precedence trap) — each verified
  untriggered at every real call site (or, for the last two, at zero call sites). Per task rules these are
  **not candidates**; they are recorded here only so the checked-clean claim is auditable.

## Candidates

**None (0).** No `M7-*` labels issued.
