# W10 — Blind Redo Audit: pademu / ds34bt / ds34usb / freepad / ilink / mmce / pccf

Clone pin verified at start: `2e347d5ac885cd0ff73e9ad4143781946396f492`.
Census (command-run): 105 files, 17,361 lines across the seven in-scope trees.
All line citations below were verified open before filing. Counts come from `wc -l`, `diff`, and `md5sum` output actually run.

---

## W10-001 — The ds34 pad drivers are maintained twice and have drifted in both directions

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/modules/pademu/ds34bt.c` (1,425 lines) vs `RiptOPL/modules/ds34bt/iop/ds34bt.c` (1,719 lines) — 915-line diff; `RiptOPL/modules/pademu/ds34usb.c` (616 lines) vs `RiptOPL/modules/ds34usb/iop/ds34usb.c` (998 lines) — 950-line diff; `RiptOPL/modules/ds34bt/iop/smsutils.S` and `RiptOPL/modules/ds34usb/iop/smsutils.S` are byte-identical (md5 `3612cf1bd66a11f0b9e53ac78a5940d7`)
- **Problem:** Two near-complete copies of each transport driver exist (one embedded in pademu, one standalone with RPC glue). They have drifted in *both* directions, so neither is a superset: the standalone copies have fixes pademu lacks (outEndp initialisation, `port >= MAX_PADS` guards, bounded EE bind loops), and pademu has guards the standalone copies lack (the `report->Power <= 0x05` bound of W10-004, the DS3 length check of W10-006, `rrum * 255` rumble scaling that both standalone copies drop). Every pad bug must currently be found and fixed twice, and W10-002/W10-004/W10-006 below are all instances of one copy being fixed and the other not.
- **Fix:** Keep one source per transport and compile it into both IRX flavours (ps2.yaml already assembles modules from explicit source lists); delete the second copy of each driver. Keep the standalone-only RPC/`_start` glue as the thin layer it is.
- **Benefit:** Removes roughly 2,600 lines of duplicate driver code and the entire class of one-copy-fixed bugs below.
- **Effort:** L · **Risk:** Med · **Confidence:** High (READ; diff/md5/wc output run this session)

## W10-002 — BT DS4 LED/rumble report: 50 bytes initialised, 79 bytes sent

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/pademu/ds34bt.c:1146,1179,1198,1206`; `RiptOPL/modules/ds34bt/iop/ds34bt.c:1208,1243,1263` (same function, `hid_LEDRumble`)
- **Problem:** `led_buf` is `PS4_11_REPORT_LEN + 2` = 79 bytes. The DS4 branch memsets only `PS3_01_REPORT_LEN + 2` = 50 bytes, sets fields up to index 13, then sends the full 79 bytes via `HID_command`. Bytes 50–78 are uninitialised stack memory transmitted to the pad on every DS4 LED/rumble update, in both copies of the driver.
- **Fix:** Memset the full `PS4_11_REPORT_LEN + 2` in the DS4 branch (one constant change per copy; one copy after W10-001).
- **Benefit:** Stops leaking IOP stack contents onto the wire and sending garbage report padding.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-003 — pademu USB: `outEndp` is never initialised, so the OUT endpoint is never opened on first connect

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/pademu/ds34usb.c:570-589` (`ds34usb_init`), `:164` and `:175` (`usb_connect`), `:212-217` (disconnect path)
- **Problem:** `ds34usb_init` sets `controlEndp = -1` and `interruptEndp = -1` for each pad but never sets `outEndp`. The pad array is a zero-initialised global, so `outEndp` starts at 0, which fails the `outEndp < 0` test in `usb_connect` — the OUT endpoint is never opened on first connect, and the `outEndp < 0` failure check at :175 also passes wrongly. Only the disconnect path (:217) ever writes −1, masking the bug after a reconnect. The standalone copy initialises it in `_start` (`modules/ds34usb/iop/ds34usb.c`, read this session) — direct proof of drift (W10-001).
- **Fix:** Set `outEndp = -1` in the same init loop.
- **Benefit:** First-connect LED/rumble output path works instead of silently using endpoint 0.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-004 — Standalone ds34 copies index `power_level[]` with an unvalidated device byte

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/ds34usb/iop/ds34usb.c:45-47` (table, 6 entries), `:337-338`; `RiptOPL/modules/ds34bt/iop/ds34bt.c:261` (table), `:1332-1333`
- **Problem:** Both standalone copies do `oldled[0] = power_level[report->Power]` guarded only by `report->Power != 0xEE`. `Power` is a byte supplied by the pad; any value 6–0xED (except 0xEE) reads out of bounds on the 6-entry table and writes the garbage byte to the LED state. The pademu copies of the same code guard with `report->Power <= 0x05`; the standalone copies lost that guard.
- **Fix:** Restore the `<= 0x05` bound in both standalone copies (or the single surviving copy after W10-001).
- **Benefit:** Removes a device-controlled out-of-bounds read.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-005 — Standalone ds34usb SET_LED RPC: EE sends 2 bytes, IOP reads 4

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/ds34usb/ee/libds34usb.c:120-129` (`ds34usb_set_led`); `RiptOPL/modules/ds34usb/iop/ds34usb.c:693-699` (`ds34usb_set_led` → `LED`)
- **Problem:** The EE side sends exactly 2 RPC bytes (port + a single `u8 led`). The IOP handler takes `u8 *led` and passes it to `LED`/`LEDRumble`, which read `led[0..3]`. Bytes 2–3 of the "array" are whatever stale data sits in the IOP RPC buffer. The BT pair does this correctly — its EE `set_led` sends 5 bytes (`modules/ds34bt/ee/libds34bt.c:113-125`).
- **Fix:** Make the USB EE function send the same 4 LED bytes the BT one does (port + 4), matching what the IOP side already expects.
- **Justification:** The fix widens an RPC payload by 3 bytes; it adds no new mechanism — it aligns the sender with the receiver's existing, already-written contract.
- **Benefit:** LED state stops depending on stale RPC buffer contents.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-006 — BT `hid_readReport` length validation is absent (standalone) or offset-blind (pademu)

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/ds34bt/iop/ds34bt.c:1276-1290` (`hid_readReport`); `RiptOPL/modules/pademu/ds34bt.c:1214,1220,1227,1271-1273`
- **Problem:** One mechanism, two severities. The standalone copy checks nothing: it reads `data[8]`/`data[9]` and casts `&data[11]` to a full report struct regardless of the received `bytes`. The pademu copy checks `bytes < 19` for DS3 but then derives `press_emu` from `bytes < sizeof(struct ds3report)`, ignoring the 11-byte header the report pointer is offset by, and its DS4 branch calls `translate_pad_ds4` with no length check at all. A short or malformed report from a pad is parsed as if complete.
- **Fix:** One minimum-length check per report type, sized as header + struct, at the top of each branch — the check the DS3 branch already half-implements.
- **Benefit:** Short transfers can no longer be parsed past the received data.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-007 — `get_data` memcpy size is never clamped to the 18-byte pad data union

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/pademu/ds34bt.c:1340`; `RiptOPL/modules/pademu/ds34usb.c:508`; caller `RiptOPL/modules/pademu/pademu.c:467`
- **Problem:** Both pademu transports implement `get_data` as `mips_memcpy(dst, ds34pad[port].data, size)` where `data` is an 18-byte union in the pad struct. The caller passes `out_size - 3` with no clamp against 18 anywhere in the chain, so the copy length is bounded only by the caller's buffer size, not by the source.
- **Fix:** Clamp `size` to `sizeof(ds34pad[port].data)` inside both `get_data` copies (one after W10-001).
- **Benefit:** Removes a source-side over-read whose length is controlled from outside the driver.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-008 — pademu USB `readReport` has no transfer length at all

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/pademu/ds34usb.c:226-241` (`usb_data_cb`), `:293` (`readReport(u8 *data, int pad_idx)`)
- **Problem:** `usb_data_cb` receives the transfer's `bytes` count but `readReport`'s signature has no length parameter — the information is structurally discarded. `readReport` then casts the buffer to ds3/ds4/guitar/shanwan report structs based only on the pad type. A short transfer is parsed at full struct size.
- **Fix:** Pass `bytes` through to `readReport` and reject reports shorter than the struct being cast to, mirroring the BT side's (fixed, per W10-006) checks.
- **Benefit:** Same short-transfer parsing hole as W10-006, closed on the USB transport.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-009 — `usb_config_set` passes a partly uninitialised `led[4]` to LEDRumble

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/pademu/ds34usb.c:247-281` (`usb_config_set`), `:440-443` (LEDRumble copying all four bytes into `oldled`); same shape in `RiptOPL/modules/ds34usb/iop/ds34usb.c` (`usb_config_set`)
- **Problem:** `led` is a stack array. The DS3 branch sets only `led[0]` and `led[3]`; the guitar/other branches set none of it; `LEDRumble(led, 0, 0, pad)` is then called unconditionally (except the ShanWan early return) and copies all four bytes into the pad's persistent `oldled` state.
- **Fix:** Zero-initialise `led[4]` at declaration in both copies.
- **Benefit:** LED state no longer seeded from stack garbage on connect.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-010 — One L2CAP buffer, three different transfer sizes

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/pademu/ds34bt.c:334` (buffer is `MAX_BUFFER_SIZE + 32` = 96), `:359` (first bulk transfer requests `MAX_BUFFER_SIZE` = 64), `:1088` (requeue in `l2cap_event_cb` requests `MAX_BUFFER_SIZE + 23` = 87)
- **Problem:** The allocation, the initial transfer, and the requeue each use a different size for the same buffer. The initial 64-byte request truncates anything longer until the first requeue, and the 87-byte requeue size matches neither of the other two numbers — there is no single constant a reader can trust.
- **Fix:** Request the buffer's actual size (`MAX_BUFFER_SIZE + 32`) in both transfer calls, or size the buffer to the protocol maximum actually used — one number, everywhere.
- **Benefit:** Transfer truncation behaviour stops depending on which request happened to be queued.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-011 — Standalone USB `set_bdaddr` transfers 24 bytes, writes 23

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/ds34usb/iop/ds34usb.c:802-830`
- **Problem:** The function fills `usb_buf[0]`, the 6 bdaddr bytes at [1..6], and the 16 link-key bytes at [7..22] — 23 bytes — with no memset, then issues a 24-byte transfer. Byte 23 is whatever the shared `usb_buf` held from a previous command.
- **Fix:** Memset `usb_buf` at function entry (as sibling command functions do) or transfer 23 bytes.
- **Benefit:** Stops sending a stale buffer byte as part of a pairing command.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-012 — Standalone USB driver shares one transfer buffer and one result code across both pads

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/ds34usb/iop/ds34usb.c:62` (`usb_buf[96]`), `:231-241` (`usb_data_cb` writing the single global result code), `:701-727` (`get_data`)
- **Problem:** `MAX_PADS` is 2, but there is one `usb_buf` and one global transfer-result variable shared by both pads and by the LED/rumble, DS3-init, and bdaddr command paths, which run under different semaphores. `get_data` additionally waits and polls on the same per-pad semaphore the completion callback signals. Interleaved operations on two pads can overwrite each other's buffer and result. (INFERRED: the interleaving itself is reasoned from the semaphore layout, not observed.)
- **Fix:** Make the transfer buffer and result per-pad members of the existing `ds34pad[]` struct — no new mechanism, just moving two globals into the struct that already exists per pad.
- **Justification:** This adds two fields to an existing struct; it is the smallest change that removes the sharing, and it removes the need for the cross-path semaphore care the current layout demands.
- **Benefit:** Two-pad use stops corrupting single-pad state.
- **Effort:** M · **Risk:** Med · **Confidence:** Med (READ for the sharing; INFERRED for the interleaving)

## W10-013 — freepad "vendoring" exists only as a provenance note; the mechanism it describes does not exist

- **Category:** 7 (build/CI/repo clutter) / 8 (half-finished features)
- **Locations:** `RiptOPL/modules/freepad/PROVENANCE.md:3-6` (the only file in the directory); `RiptOPL/.gitignore:15` (`*.irx`); `RiptOPL/Makefile:1121`
- **Problem:** PROVENANCE.md states that a vendored `freepad.irx` (36,741 bytes, sha256 tabled in the file) is "installed over the container stock freepad" by `.github/scripts/install_coherent_freepad.sh`. That script does not exist anywhere in the tree (repo-wide search: the only hit is inside PROVENANCE.md itself), the binary itself is excluded by `.gitignore`, and the top-level Makefile builds padman from the PS2SDK's stock `freepad.irx`. The directory documents a supply-chain step that never happens.
- **Fix:** Delete `modules/freepad/` and its provenance note until the install mechanism actually exists; if the vendored binary is ever really wired in, the note can come back with it.
- **Benefit:** Removes a provenance claim a reader (or auditor) will trust and be misled by.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; absence verified by repo-wide search this session)

## W10-014 — Broken, unused `PACKET_TCODE` macro

- **Category:** 1 (dead code)
- **Locations:** `RiptOPL/modules/ilink/iLinkman/src/include/iLink_internal.h:92`
- **Problem:** `#define PACKET_TCODE (((x) >> 4) & 0xF)` is an object-like macro whose body references an undefined `x` — it cannot compile if ever used. A tree search shows it is never used.
- **Fix:** Delete the macro.
- **Benefit:** Removes a landmine that breaks the build the first time anyone reaches for it.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-015 — Exported iLink transaction-context accessors index the context array unchecked

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/ilink/iLinkman/src/iLink.c:209-212` (`iLinkTrFree`), `:330-360` (`iLinkGetNodeTrSpeed`/`iLinkSetNodeTrSpeed`); contrast `:219` and `:243` in the same file
- **Problem:** `iLinkTrRead` and `iLinkTrWrite` validate `trContext` against `MAX_CONCURRENT_TRANSACTIONS`; `iLinkTrFree` (which writes into `TransactionContexts[trContext]`) and the two speed accessors index the same array with no check. These are exported functions — any other IOP module can pass an arbitrary index and write outside the array.
- **Fix:** Apply the same bounds check the read/write functions already have. No new mechanism.
- **Benefit:** Closes an exported out-of-bounds write.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-016 — `GetBIOSVersion` parses an uninitialised buffer when the ROM open/read fails

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/ilink/iLinkman/src/iLink.c:61-72`
- **Problem:** The open and read results for `rom0:ROMVER` are unchecked; if either fails, `strtoul` runs over an uninitialised stack buffer and the module proceeds with a garbage BIOS version.
- **Fix:** Check both results and bail out with the existing failure path if either fails.
- **Benefit:** Module init no longer depends on stack garbage on a failed ROM read.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-017 — `InitializeConfigurationROM` silently drops and leaks every registered extra CROM unit

- **Category:** 6 (bugs/security) / 4 (size/memory)
- **Locations:** `RiptOPL/modules/ilink/iLinkman/src/iLink_crom.c:249-263`; called from `RiptOPL/modules/ilink/iLinkman/src/iLink.c` (`iLinkSetNodeCapabilities`)
- **Problem:** `InitializeConfigurationROM` resets all 16 `ExtraCROMUnits[]` pointers to NULL without freeing them, and rebuilds the ROM without them. It is called not only at module start but also from `iLinkSetNodeCapabilities`, so any unit another module registered via `iLinkAddCROMUnit` is silently unregistered — and its allocation leaked — the first time node capabilities are set.
- **Fix:** Free the unit allocations before clearing the pointers, and do not reinitialise the unit table from the capabilities setter (rebuild the ROM only).
- **Benefit:** Removes a leak and a silent deregistration of other modules' CROM units.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-018 — Two hand-rolled malloc/free shims, one per ilink module

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/modules/ilink/IEEE1394_bd/src/sbp2_driver.c:809-828`; `RiptOPL/modules/ilink/iLinkman/src/iLink_internal.c:184-203`
- **Problem:** Both modules independently define `malloc`/`free` wrappers around `AllocSysMemory`/`FreeSysMemory` with interrupt suspend/resume — the same ~20 lines twice, free to drift.
- **Fix:** Keep one copy in a shared source file compiled into both IRXs (the build already compiles per-module source lists); delete the other.
- **Benefit:** ~20 lines removed and one less place for allocator behaviour to diverge.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ)

## W10-019 — `scsi_read` and `scsi_write` are copy-paste twins

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/modules/ilink/IEEE1394_bd/src/scsi.c:304-358`
- **Problem:** The two functions are line-for-line identical except for the write flag passed to `scsi_cmd_rw_sector` — including a duplicated 16-iteration retry loop.
- **Fix:** One static helper taking the flag; both public functions become one-line wrappers (or callers pass the flag directly).
- **Benefit:** ~27 lines removed; retry behaviour can only drift in one place now.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-020 — `DeinitIEEE1394` is dead and incomplete

- **Category:** 1 (dead code) / 8 (half-finished features)
- **Locations:** `RiptOPL/modules/ilink/IEEE1394_bd/src/sbp2_driver.c:802-807` (definition), `:20,93` (the `writeBuffer` it never frees); declaration `RiptOPL/modules/ilink/IEEE1394_bd/src/include/sbp2_disk.h:180`
- **Problem:** Nothing in `modules/ilink` calls `DeinitIEEE1394`. As written it also would not finish the job: it terminates the thread and deletes the event flag but never frees the heap `writeBuffer`, never deletes `sbp2_io_sema`, and never disables the bus. It reads as an unload path that was started and abandoned.
- **Fix:** Delete the function and its declaration. If module unload is ever actually required, it should be written complete at that point.
- **Benefit:** Removes a false promise of clean unload.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; caller search run this session)

## W10-021 — MMCE `get_gameid` does an unbounded `strcpy` from the card reply into the caller's buffer

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/mmce/mmceman/src/mmce_cmds.c:195-224`; caller `RiptOPL/modules/mmce/mmceman/src/mmce_fs.c:1122-1124` (devctl `MMCE_CMD_GET_GAMEID`)
- **Problem:** On a valid reply, `strcpy(ptr, &rdbuf[4])` copies from a 255-byte card-supplied packet into the devctl output buffer. No length is taken, checked, or passed — the devctl `buflen` is ignored by the caller — and nothing guarantees the card's string is NUL-terminated within the packet, so the copy can also read past `rdbuf`. The destination size is unknowable at this layer, which is exactly why the copy must be bounded there.
- **Fix:** Pass the devctl `buflen` down and copy with an explicit bound, treating an unterminated packet as an error.
- **Justification:** This adds a length parameter to one internal function; it is the minimum needed to bound a copy whose source is an external device.
- **Benefit:** A malformed or hostile card reply can no longer overrun an EE-supplied buffer.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

## W10-022 — mmce command functions transmit uninitialised trailing stack bytes

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/mmce/mmceman/src/mmce_cmds.c:109-121` (`set_card`: `wrbuf[7]` never written, 8 sent), `:169-180` (`set_channel`: `wrbuf[6]` never written, 7 sent), `:263-271` (`reset`: `wrbuf[3..4]` never written, 5 sent), `:232-244` (`set_gameid`: sends `len + 5`, one byte past the string it filled)
- **Problem:** Four functions in one file send stack buffers whose final byte(s) were never initialised. The file's own newer function shows the intended pattern — `set_card_channel` explicitly writes a `0xFF` termination byte (:301) — the older four were never brought in line.
- **Fix:** Zero each `wrbuf` at declaration (or write the termination byte, matching `set_card_channel`).
- **Benefit:** Card commands stop carrying stack garbage in their padding/termination bytes.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-023 — mmce_fs truncates every filename length into a `u8`

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/mmce/mmceman/src/mmce_fs.c:84` (open), `:420` (remove), `:479` (mkdir), `:538` (rmdir), `:604` (dopen), `:849` (getstat), `:964-965` (rename, both names)
- **Problem:** Every name-taking op computes `u8 len = strlen(name) + 1`. The SIO2 transfer API takes a `u8` size (`mmce_sio2.h`), so the protocol genuinely caps at 255 — but nothing rejects a longer name. A name of 256+ bytes wraps the length (a 300-byte name becomes 45), and the card receives a short, unterminated prefix of the path and acts on it.
- **Fix:** Return `-ENAMETOOLONG` when `strlen(name) + 1 > 255`, once per function at the point the length is computed.
- **Benefit:** Over-long paths fail loudly instead of silently operating on a truncated prefix.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-024 — mmce devctl dereferences `arg` unchecked in four cases — the fifth case in the same switch checks

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/mmce/mmceman/src/mmce_fs.c:1103` (SET_CARD), `:1116` (SET_CHANNEL), `:1153` (ACK_WAIT_CYCLES), `:1158` (SET_ALARMS); contrast `:1137-1142` (SET_CARD_CHANNEL)
- **Problem:** Four devctl cases do `args = *(u32*)arg` with no NULL or `arglen` check. `MMCE_CMD_SET_CARD_CHANNEL`, added later in the same switch, validates `arg == NULL || arglen < 5` first — proving the requirement was known and the older cases were left behind.
- **Fix:** Apply the same `arg`/`arglen` validation to the four older cases.
- **Benefit:** A devctl with a short or NULL argument can no longer fault the IOP.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-025 — mmce_fs remove/mkdir/rmdir are three copies of one function

- **Category:** 2 (duplication)
- **Locations:** `RiptOPL/modules/mmce/mmceman/src/mmce_fs.c:409-466` (remove), `:468-525` (mkdir), `:527-584` (rmdir)
- **Problem:** Three ~58-line functions with identical packet sequences, differing only in the command byte (`MMCE_CMD_FS_REMOVE`/`MKDIR`/`RMDIR`) and log strings. open/dopen repeat the same skeleton a fourth and fifth time.
- **Fix:** One static helper taking the command byte, called by the three ops (and, if it stays a net win, open/dopen).
- **Benefit:** ~110 lines removed; the ENOENT/timeout doctrines documented elsewhere in this file only need maintaining once.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ)

## W10-026 — The mmce "set alarms" setting is honoured by only two of the five transfer paths

- **Category:** 8 (half-finished features)
- **Locations:** `RiptOPL/modules/mmce/mmceman/src/mmce_sio2.c:278,381` (checked in `rx_dma`/`rx_mixed`) vs `:211` (`tx_rx_pio`, always alarms) and `:492,533,570` (`tx_mixed` stages, always alarm); setting exposed via `RiptOPL/modules/mmce/mmceman/src/mmce_fs.c:1157-1160`
- **Problem:** `MMCE_SETTINGS_SET_ALARMS` toggles `mmce_sio2_use_alarm`, but `tx_rx_pio` — the path every command and every filesystem packet goes through — ignores the flag entirely, as do the DMA stages of `tx_mixed`. Turning alarms "off" changes behaviour only for bulk reads.
- **Fix:** Either honour the flag in `tx_rx_pio` and `tx_mixed` too, or delete the setting and its devctl case. LESS favours deleting a setting that cannot do what it says unless a user of the off state is known.
- **Benefit:** The devctl surface stops advertising a control that mostly does nothing.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-027 — sio2man_hook carries a permanently disabled mx4sio port-blocking feature

- **Category:** 1 (dead code)
- **Locations:** `RiptOPL/modules/mmce/mmceman/src/sio2man_hook.c:26-29` (`PORT_NR` defined only inside `#if 0`), `:58-85`, `:115-121`, `:275-281` (all `#ifdef PORT_NR`)
- **Problem:** `PORT_NR` can never be defined — its only definition sits inside `#if 0` with the comment "Only needed for mx4sio" — so the transfer-filter function, its two hook wrappers, and the hook/unhook code for export 25 all compile out, permanently. It is leftover from the MX4SIO driver this file was taken from.
- **Fix:** Delete the `#if 0` block and every `PORT_NR`-guarded block (~35 lines).
- **Benefit:** The hook file shrinks to what mmceman actually does; nobody has to re-derive that the filter is inert.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-028 — `mmce_fs_ioctl` is registered but returns success for every command

- **Category:** 8 (half-finished features)
- **Locations:** `RiptOPL/modules/mmce/mmceman/src/mmce_fs.c:402-405`, registered at `:1194`
- **Problem:** The ops table wires `ioctl` to a stub that returns 0 unconditionally — every ioctl, known or not, reports success and does nothing. The same table handles genuinely unsupported ops honestly via `NOT_SUPPORTED_OP` (−ENOTSUP) everywhere else.
- **Fix:** Return `-ENOTSUP` from the stub (or point the slot at `NOT_SUPPORTED_OP` and delete the stub).
- **Benefit:** Callers stop believing ioctls took effect when nothing happened.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

## W10-029 — pccf ships a formatter that is never included and a diagnostic entry point that is never defined

- **Category:** 1 (dead code) / 7 (repo clutter)
- **Locations:** `RiptOPL/modules/pccf/format.inc` (whole file, 57 lines); `RiptOPL/modules/pccf/pcdiag_ata.h:20-21` (`pcdiag_ata_observe`)
- **Problem:** A repo-wide search finds `format.inc` referenced by nothing but the git index — no source includes it, so its `format_line` mini-printf is dead weight in every checkout. `pcdiag_ata_observe` is declared in the header but has no definition and no caller anywhere in the tree: a leftover of the diagnostic program the driver was adapted from.
- **Fix:** Delete `format.inc` and the `pcdiag_ata_observe` declaration.
- **Benefit:** Two fewer phantom surfaces for a reader to chase.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; searches run this session)

## W10-030 — `pcdiag_cf_probe`'s sampling loop produces only traces the production caller throws away

- **Category:** 3 (overengineering) / 5 (performance, structural)
- **Locations:** `RiptOPL/modules/pccf/pcdiag_cf.c:40-71`; production caller `RiptOPL/modules/pccf/pccf_hw.c:56-59,283` (passes `quiet_trace`)
- **Problem:** The probe's actual decision is complete before the loop: candidate check and COR check at the top determine pass/fail. The remaining loop — 3 samples × 2 spaces × (10 byte reads + 5 word reads), plus 500 ms + 200 ms of waits — feeds only `trace()` calls, never influences the return value, and in the production driver the trace callback is `quiet_trace`, which discards everything by design. Every card insertion pays ~700 ms and 90 register reads for output nobody receives.
- **Fix:** In the production path keep the candidate/COR validation and drop the sampling loop (the loop belongs in the separate diagnostic build the file header describes).
- **Benefit:** Removes ~700 ms of start-up latency per card and ~30 lines of inert diagnostic code from the shipped driver.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ)

## W10-031 — `pio_profile` permanently reserves 8 KiB of IOP RAM for a one-shot start-up check

- **Category:** 4 (size/memory)
- **Locations:** `RiptOPL/modules/pccf/pccf_pio_profile.inc:3` (`profile_ref` + `profile_check`, 4,096 bytes each)
- **Problem:** Two static 4 KiB buffers exist solely so the start-up profile validation can compare two reads of the same sectors. They are used once during `pccf_hw_start` and then sit resident for the life of the module.
- **Fix:** Keep one 4 KiB buffer and compare the second read against a checksum of the first, halving the reservation; or validate in 512-byte chunks reusing the sector buffer the ATA layer already has.
- **Benefit:** 4 KiB of IOP memory returned permanently.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (READ — sizes are arithmetic from the declaration; the one-shot usage is read from `pio_profile` itself)

---

## COVERAGE

### Files read (all in-scope trees)

- **modules/pademu/** — Makefile, pademu.h, ds34bt.h, ds34usb.h, padmacro.h, sys_utils.h, exports.tab, imports.lst, irx_imports.h, pademu.c, ds34common.c, padmacro.c, sys_utils.c, ds34bt.c, ds34usb.c (all in full).
- **modules/ds34bt/** — ee/libds34bt.c, ee/libds34bt.h, iop/ds34bt.h, iop/ds34bt.c (in full via the complete diff against the pademu copy, plus direct reads of every cited range), iop/smsutils.S, all Makefiles, iop/imports.lst, iop/irx_imports.h.
- **modules/ds34usb/** — ee/libds34usb.c, ee/libds34usb.h, iop/ds34usb.h, iop/ds34usb.c (in full), all Makefiles, iop/imports.lst, iop/irx_imports.h; iop/smsutils.S verified byte-identical to the ds34bt copy by md5sum + diff.
- **modules/freepad/** — PROVENANCE.md (the only tracked file in the directory).
- **modules/ilink/** — iLinkman: ORIGIN.txt, README, Makefile, exports.tab, imports.lst, irx_imports.h, include/iLinkman.h, src/iLink.c, iLink_internal.c, iLink_PHY.c, iLink_DMA.c, iLink_TxRx.c, iLink_intr.c, iLink_crom.c, src/include/iLink_internal.h, iLink_CROM.h. IEEE1394_bd: ORIGIN.txt, Makefile, imports.lst, irx_imports.h, src/main.c, src/sbp2_driver.c, src/scsi.c, src/include/module_debug.h, sbp2_disk.h, scsi.h.
- **modules/mmce/** — mmceman/ORIGIN.txt, mmceman/Makefile-equivalent build entry (built via ps2.yaml `mmceman_fork`; no local Makefile exists), include/{ioplib.h, irx_imports.h, mmce_cmds.h, mmce_fs.h, mmce_sio2.h, module_debug.h, sio2man_hook.h, sio2regs.h}, src/{mmceman.c, mmce_fs.c, mmce_cmds.c, mmce_sio2.c, sio2man_hook.c, ioplib.c, imports.lst}, and all five patches under mmceman/patches/ (verified as the canonical delta representation used by `.github/scripts/test_mmceman_fork.py` — deliberately **not** flagged as clutter).
- **modules/pccf/** — README.md, Makefile, main.c, pccf_ata.c, pccf_ata.h, pccf_hw.c, pccf_mbr.h, pcclog.h, pcdiag_cf.c, pcdiag_cf.h, pcdiag_cis.c, pcdiag_cis.h, pcdiag_ata.h, format.inc, pccf_pio_bulk.inc, pccf_pio_profile.inc, imports.lst, irx_imports.h.
- **Out-of-scope dependency read (noted, not audited):** `RiptOPL/include/ds34common.h` (report struct layouts/sizes needed to judge the pad findings).

### Files NOT read

- `modules/mmce/mmceman/LICENSE` and `modules/pccf/PS2SDK_LICENSE.txt` — licence texts only; licences are settled and out of scope for findings per the task rules. No other in-scope file was left unread.
