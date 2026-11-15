# POPSLoader — Blind Redo Audit — IOP + PADEMU

- Repo: NathanNeurotic/POPSLoader, pin `29272cddbf01` (master), clone `~/workspace/audit-clones-2026-11-13/POPSLoader`
- Scope: `modules/pademu/`, `modules/ds34usb/`, `modules/ds34bt/`, `iop/ata_bd_fast/ps2atad.c`, `iop/bdm_query/bdm_query.c`, `modules/Rules.bin.make`, module Makefiles/imports/exports.
- Method: every in-scope C file read; copy census by `diff`/`wc`/`md5sum` script, never estimated. No file under `~/workspace/Sable-audit/` was read, listed, or opened.
- Rule applied: LESS, NOT MORE — remove / simplify / consolidate / fix only.

## Copy census (mandatory, script-derived)

| Pair | Lines (A / B) | `diff` output lines | md5 identical? | Verdict |
|---|---|---|---|---|
| `modules/pademu/ds34usb.c` vs `modules/ds34usb/iop/ds34usb.c` | 634 / 806 | 399 | No | Diverged: same driver core, different front-ends (see below) |
| `modules/pademu/ds34bt.c` vs `modules/ds34bt/iop/ds34bt.c` | 1521 / 1719 | 512 | No | Diverged: same HCI/L2CAP/HID core, different front-ends + features |
| `modules/pademu/ds34usb.h` vs `modules/ds34usb/iop/ds34usb.h` | 194 / 188 | 24 | No | Near-identical; struct field order + `analog_btn`/`btn_delay` only in pademu, prototypes differ |
| `modules/pademu/ds34bt.h` vs `modules/ds34bt/iop/ds34bt.h` | 360 / 376 | 59 | No | Near-identical; standalone adds `vid/pid/rev`, `hci_state`, `hci_information_t`, READ_VERSION/FEATURES |
| `modules/ds34usb/iop/smsutils.S` vs `modules/ds34bt/iop/smsutils.S` | 180 / 180 | 0 | **Yes** (`3612cf1bd66a11f0b9e53ac78a5940d7`) | Byte-identical duplicate |
| `modules/ds34usb/iop/irx_imports.h` vs `modules/ds34bt/iop/irx_imports.h` | 37 / 37 | 0 | Yes (diff-empty) | Byte-identical duplicate |
| `modules/ds34usb/iop/imports.lst` vs `modules/ds34bt/iop/imports.lst` | 33 / 34 | 10 | No | Same list except module-specific tail |
| `modules/ds34usb/ee/libds34usb.c` vs `modules/ds34bt/ee/libds34bt.c` | 148 / 173 | 222 | No | Parallel RPC clients, same shape, different command sets |

Divergence that matters (verified by diff, not inferred):

- `MAX_PADS`: pademu copies **4** (`modules/pademu/ds34usb.c:19`, `modules/pademu/ds34bt.c:341`); standalone copies **2** (`modules/ds34usb/iop/ds34usb.c:20`, `modules/ds34bt/iop/ds34bt.c:346`).
- Standalone-only: SIF RPC server + `_start` (`modules/ds34usb/iop/ds34usb.c:668-806`, `modules/ds34bt/iop/ds34bt.c:1600-1719`), `get/set_bdaddr`, `set_led`, HCI read-version/features (`modules/ds34bt/iop/ds34bt.c:492-518,558-580`), port-bounds checks.
- Pademu-only: `analog_btn`/`btn_delay` PS+Select/Share analog-toggle logic, `ds34*_set_mode`, `enable_fake` (pademu BT) vs inverted `disable_fake` (standalone BT), the DS3 null-report guard in the USB copy (RE-POPS-IOP-07), and the **unfixed** DS4 `memset` size in the BT copy (RE-POPS-IOP-06).
- DS4 rumble byte: pademu USB writes `rrum * 255` (`modules/pademu/ds34usb.c:471`), standalone USB writes `rrum` (`modules/ds34usb/iop/ds34usb.c:438`); pademu BT writes `rrum * 255` (`modules/pademu/ds34bt.c:1189`), standalone BT writes `rrum` (`modules/ds34bt/iop/ds34bt.c:1250`). This follows the different callers (pademu passes 0/1, the EE RPC passes a byte) — recorded as divergence, **not** counted as a defect. INFERRED.

## Findings

### RE-POPS-IOP-01 — Whole `modules/pademu/` tree is built by nothing
- Category: 1
- Locations: modules/pademu/Makefile:1-25, modules/pademu/pademu.c:1-536, modules/pademu/ds34usb.c:1-634, modules/pademu/ds34bt.c:1-1521, Makefile:82-99,308-324
- Problem: The top-level Makefile builds and embeds only the standalone modules (`modules/ds34usb/iop/ds34usb.irx`, `modules/ds34bt/iop/ds34bt.irx`, EE libs at Makefile:82,308-324; `IOP_MODULES` at Makefile:97-99 lists `ds34bt.o ds34usb.o` from those IRXs). A scripted search of the top Makefile, `.github/`, `src/`, `bin/`, `etc/` for `pademu`/`usb_pademu`/`bt_pademu` returns zero hits. The 3,474 lines under `modules/pademu/` (pademu.c, two full driver copies, sys_utils, headers, exports/imports) therefore compile into no shipped artifact, yet they are the copies that still receive pademu-only edits (analog toggle, fake-DS3 option) — effort spent on dead code, and a trap for anyone fixing the live drivers in the wrong copy.
- Fix: Delete `modules/pademu/` if POPStarter-side pademu IRXs are no longer produced from this repo; if they are produced elsewhere/by hand, move the tree out of `modules/` and label it as that external build's source in one line. Do not keep it beside the live drivers unlabeled.
- Benefit: Removes 3,474 misleading lines and the wrong-copy fix trap; the live ds34 code becomes the only ds34 code.
- Effort: S · Risk: Med · Confidence: High (READ)

### RE-POPS-IOP-02 — Vendored `iop/ata_bd_fast/` is kept but explicitly unused; the pinned binary wins
- Category: 7
- Locations: iop/ata_bd_fast/ps2atad.c:1-1593, iop/ata_bd_fast/atad.h:1-132, iop/ata_bd_fast/Makefile:1-40, Makefile:332-344
- Problem: The root Makefile states it in its own comment (Makefile:332-340): the embedded `ata_bd.irx` is pinned to `iop/embed/ata_bd.irx` (SHA-256 checked in CI) and "The iop/ata_bd_fast vendored source and its build rule below are kept but unused." So 1,725 lines of vendored ATAD v2.7 — including POPSLoader's own phantom-slave probe cap (`ps2atad.c:444-494,1243-1300`) — sit in the tree, buildable via a rule nothing invokes, and will silently diverge from both the pinned binary and upstream PS2SDK ATAD (the file itself notes SDK 3.1.0 / ATAD 2.9 divergence at ps2atad.c:46-48). A reader cannot tell from the source tree alone that none of it ships.
- Fix: Delete `iop/ata_bd_fast/` and its dead build rule, keeping the pin comment pointing at `iop/embed/ata_bd.irx`; if the source must be retained for provenance, archive it outside the build tree with the pinned binary's origin in one line.
- Benefit: Removes 1,725 unused lines and a build rule that produces a binary CI would reject if it were ever wired in.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-IOP-03 — ds34 drivers exist as two hand-synced copies per transport; fixes land in one copy only
- Category: 2
- Locations: modules/pademu/ds34usb.c:1-634, modules/ds34usb/iop/ds34usb.c:1-806, modules/pademu/ds34bt.c:1-1521, modules/ds34bt/iop/ds34bt.c:1-1719, modules/ds34usb/iop/smsutils.S:1-180, modules/ds34bt/iop/smsutils.S:1-180
- Problem: Each transport's USB-descriptor walk, report parsing, LED/rumble and HCI/L2CAP state machine exists twice (399 and 512 diff lines respectively — census table above), plus byte-identical `smsutils.S` (same md5) and `irx_imports.h` in both standalone modules. The copies are already out of sync in both directions: the standalone BT copy has the correct DS4 `memset` size and the pademu copy does not (RE-POPS-IOP-06); the pademu USB copy has the DS3 null-report guard and the standalone USB copy does not (RE-POPS-IOP-07); `power_level` OOB and the descriptor-walk flaw exist in all four copies (RE-POPS-IOP-04, RE-POPS-IOP-05). Every future fix must currently be made up to four times.
- Fix: Consolidate to one source per transport: keep the standalone IOP files as the single implementation and, if pademu is retained at all (see RE-POPS-IOP-01), have pademu link/include that same file with its `MAX_PADS`/front-end differences behind the existing `USB`/`BT` defines instead of carrying a forked copy; keep one `smsutils.S`/`irx_imports.h` and reference it from both module Makefiles.
- Benefit: One place per bug; the two already-diverged fixes (IOP-06, IOP-07) stop being copy-dependent.
- Effort: L · Risk: Med · Confidence: High (READ)

### RE-POPS-IOP-04 — USB descriptor walk trusts `bLength`/`bNumEndpoints` from the device in all four copies
- Category: 6
- Locations: modules/pademu/ds34usb.c:121-147, modules/ds34usb/iop/ds34usb.c:128-154, modules/pademu/ds34bt.c:110-137, modules/ds34bt/iop/ds34bt.c:111-142
- Problem: Identical loop in every copy: `interface = (void*)config + config->bLength; epCount = interface->bNumEndpoints - 1; endpoint = UsbGetDeviceStaticDescriptor(..., USB_DT_ENDPOINT); do { ...; endpoint = (void*)endpoint + endpoint->bLength; } while (epCount--);` with no NULL check on `device`/`config`/`endpoint` in `*_connect` (only `*_probe` checks), no `bLength == 0` guard, and no bound against the config descriptor's `wTotalLength`. Three concrete failures: (1) a device reporting `bNumEndpoints == 0` for a DS3/BT interface makes `epCount = -1`, and `while (epCount--)` then iterates ~2^31 times, walking `endpoint` ever further out of bounds; (2) `bLength == 0` never advances the pointer, re-opening the same endpoint; (3) the DS4 branch hardcodes `epCount = 20` ("ds4 v2 returns bNumEndpoints as 0", ds34usb.c:128/135) and walks 21 descriptors regardless of how many the device actually sent. A malformed or clone device — exactly the fake-DS3/DS4 hardware this code exists to tolerate — controls all three values.
- Fix: In the single consolidated copy (RE-POPS-IOP-03): NULL-check `device`/`config`/`endpoint` in connect, iterate at most the real endpoint count, stop when `bLength == 0` or the walk passes `config + config->wTotalLength`, and drop the hardcoded 20 in favour of stopping at the descriptor end.
- Benefit: Removes an IOP crash / out-of-bounds walk triggered purely by device-supplied descriptors.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-IOP-05 — DS3 battery byte indexes the 6-entry `power_level[]` unchecked in all four copies
- Category: 6
- Locations: modules/pademu/ds34usb.c:44-45,303-304, modules/ds34usb/iop/ds34usb.c:45-46,298-299, modules/pademu/ds34bt.c:256-257,1275-1276, modules/ds34bt/iop/ds34bt.c:261-262,1332-1333
- Problem: `power_level[]` has 6 entries (indices 0-5). Every copy does `if (report->Power != 0xEE) oldled[0] = power_level[report->Power];` (standalone USB/BT add `PSButtonState &&` but the same index). `report->Power` is a full device-supplied `u8` in `struct ds3report` (ds34usb.h/ds34bt.h: "05=full … EE=charging" is a comment, not a check). Any value 6-0xED except 0xEE reads past the array into adjacent static data and uses it as an LED pattern; a clone/fake controller — explicitly supported by this code — supplies the byte.
- Fix: Clamp once per copy (once total after RE-POPS-IOP-03): only index when `report->Power <= 5`, otherwise fall back to the pad's normal LED pattern, as the surrounding code already does in the non-PS branch.
- Benefit: Removes a device-controlled out-of-bounds read present in all four driver copies.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-IOP-06 — Pademu BT copy clears the DS4 LED buffer with the DS3 length and sends 29 uninitialised bytes (fix exists in the standalone copy)
- Category: 6
- Locations: modules/pademu/ds34bt.c:1149,1181,1206, modules/ds34bt/iop/ds34bt.c:1206,1243,1265, modules/pademu/ds34bt.h:227,231
- Problem: In pademu `hid_LEDRumble`, `led_buf` is `u8[PS4_11_REPORT_LEN + 2]` = 79 bytes, the DS4 branch sends `size = 2 + PS4_11_REPORT_LEN` = 79 bytes, but clears only `mips_memset(led_buf, 0, PS3_01_REPORT_LEN + 2)` = 50 bytes (ds34bt.c:1181). Bytes 50-78 are uninitialised stack sent to the controller in every DS4 BT rumble/LED packet. The standalone copy already contains the fix — `mips_memset(led_buf, 0, PS4_11_REPORT_LEN + 2)` at ds34bt/iop/ds34bt.c:1243 — proving this is a copy-sync miss, not a design choice.
- Fix: Change the one constant in the pademu copy to `PS4_11_REPORT_LEN + 2` (or delete the copy per RE-POPS-IOP-01/03, which makes the fix permanent).
- Benefit: Stops leaking 29 bytes of IOP stack to the device per DS4 BT output report.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-IOP-07 — Standalone USB copy lost the DS3 null-report guard the other three copies have
- Category: 6
- Locations: modules/ds34usb/iop/ds34usb.c:263-275, modules/pademu/ds34usb.c:269-270, modules/pademu/ds34bt.c:1219-1220, modules/ds34bt/iop/ds34bt.c:1284-1285
- Problem: Three of the four `readReport`/`hid_readReport` implementations drop the spurious all-zero-stick report an LED/rumble command provokes: `if (report->RightStickX == 0 && report->RightStickY == 0) return; // ledrumble cmd causes null report sometime`. The standalone USB copy — the one POPSLoader actually embeds — has no such guard (its DS3 branch at ds34usb/iop/ds34usb.c:272-275 goes straight to copying the report), so in the shipped module that known-bad report overwrites `ds34pad[pad].data[]` with a centred-stick/zero-pressure snapshot. This is the reverse sync miss to RE-POPS-IOP-06.
- Fix: Restore the same two-line guard at the top of the DS3 branch in `modules/ds34usb/iop/ds34usb.c` (or consolidate per RE-POPS-IOP-03).
- Benefit: The shipped USB driver gets the glitch suppression the other three copies already have.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-IOP-08 — `pademu.c` SIO2 parsing reads past the transfer with no size floor, and the multitap slot becomes an unchecked array index
- Category: 6
- Locations: modules/pademu/pademu.c:228,236,314,323,369-415,475-493,505-530
- Problem: Four unchecked-length mechanisms in one file: (1) the second-command scans use `for (ctrl = 5; ctrl < td->in_size - 3; ctrl++)` — if `in_size < 3` the `u32` subtraction wraps and the scan reads far past `td->in`; the `cmd_size + 3 == td->in_size` not-found test also misses the `>` case. (2) `pademu_cmd` switches on `in[1]` and reads `in[3]`…`in[9]` (cases 0x43/0x44/0x46/0x4C/0x4D/0x4F) without ever checking the input length it was handed, and calls `PAD_GET_DATA(&out[3], out_size - 3, port)` — `out_size` is `u8`, so `out_size < 3` underflows to ~253 (see RE-POPS-IOP-10). (3) `pademu_mtap` stores the device/game-supplied byte `mtap_slot = td->in[2]` (pademu.c:527) with no range check; `pademu()` then uses it as `port = mtap_slot` (pademu.c:359-363), indexing `pad[4]` and, via `pademu_cmd`, `ds34pad[4]` — any slot byte ≥ 4 is an out-of-bounds read/write. (4) `pademu_mtap` itself switches on `td->in[1]` after only checking the transfer is multitap-addressed.
- Fix: Reject transfers with `in_size < 10` at the top of `pademu`/`pademu_cmd`/`pademu_mtap`, change the not-found tests to `>=`, and clamp/reject `mtap_slot >= MAX_SLOT` when it is stored. No new machinery — three comparisons in code that already branches on these values.
- Benefit: Closes game/transfer-controlled out-of-bounds access in the SIO2 hook, the highest-privilege parser in this scope.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-IOP-09 — BT HCI/L2CAP/HID handlers ignore the received byte count and parse stale buffer bytes
- Category: 6
- Locations: modules/pademu/ds34bt.c:499,763,908-1056,1211-1420, modules/ds34bt/iop/ds34bt.c:540,828,970-1160,1275-1490
- Problem: Same mechanism in both BT copies. `HCI_event_task(int result)` does not even receive the byte count (`hci_event_cb` discards `bytes`, ds34bt.c:763/828) and switches on `hci_buf[0]` reading up to `hci_buf[11]` plus a 19-byte `memcmp` at `hci_buf + 9` for the remote name; `HCI_EVENT_NUM_COMPLETED_PKT` loops `for (i = 0; i < hci_buf[2]; i++)` reading `hci_buf[3+i]`/`hci_buf[4+i]` with the device-supplied count unbounded against the 64-byte `hci_buf`. `L2CAP_event_task(result, bytes)` receives `bytes` but never bounds-checks it before reading `l2cap_buf[8]`…`l2cap_buf[19]` for every signalling command, and `hid_readReport(data, bytes, pad)` casts `&data[11]` to `ds3report`/`ds4report` (≈49/64 bytes) after checking only `data[8]`/`data[9]` — its one length use is the DS4 touchpad gate `bytes > 63`. A short or truncated USB/BT packet therefore parses whatever the previous packet left in the static buffers as buttons, handles and addresses.
- Fix: Thread `bytes` into `HCI_event_task`, and in both copies drop any packet shorter than the fixed header each branch reads (HCI: the branch's parameter length; L2CAP: 20 bytes for signalling, 11 + report size for HID input) before touching the buffer. One early return per handler.
- Benefit: Malformed/short packets stop being executed as controller state in both BT copies.
- Effort: M · Risk: Low · Confidence: High (READ)

### RE-POPS-IOP-10 — `get_data` copies a caller-supplied `size` out of an 18-byte array, and the pademu copies never bounds-check `port`
- Category: 6
- Locations: modules/pademu/ds34usb.c:526,546, modules/pademu/ds34bt.c:1430,1436, modules/ds34usb/iop/ds34usb.c:530,553, modules/ds34bt/iop/ds34bt.c:1519,1529, modules/pademu/pademu.c:415
- Problem: All four `ds34*_get_data(dst, size, port)` implementations end in `mips_memcpy(dst, ds34pad[port].data, size)` where `data` is `u8[18]` (both headers) and `size` is unchecked. The pademu caller passes `out_size - 3` derived from the SIO2 transfer (pademu.c:415), so a large `out_size` over-reads `ds34pad[].data` and over-writes the SIO2 output buffer. The standalone RPC callers happen to pass the constant 18, so they are safe only by caller discipline. Compounding it, none of the pademu entry points (`get_data`/`set_rumble`/`set_mode`/`get_status`, ds34usb.c:515-600 and ds34bt.c:1422-1470) checks `port` at all, while every standalone entry point does (`port >= MAX_PADS`, e.g. ds34usb/iop/ds34usb.c:516,524,534) — and pademu's `port` can be the unchecked `mtap_slot` of RE-POPS-IOP-08.
- Fix: Clamp `size` to 18 inside `get_data` and add the same `port >= MAX_PADS` early return the standalone copies already have to the pademu entry points (free after consolidation, RE-POPS-IOP-03).
- Benefit: Removes a length-controlled over-copy and an index-controlled array access from the pademu path.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-IOP-11 — Dead helpers and dead macros: `GetExportEntry` and the `hci_event_flag_*` family
- Category: 1
- Locations: modules/pademu/sys_utils.c:56-68, modules/pademu/pademu.h:59, modules/pademu/ds34bt.h:69-71, modules/ds34bt/iop/ds34bt.h:84-86
- Problem: `GetExportEntry` is defined and prototyped but a scripted search shows no caller anywhere in the repo outside its own definition (only `GetExportTableSize` and `HookExportEntry` are used, pademu.c:178). The `hci_event_flag_clear/set/check` macros in both BT headers expand to operations on a variable `hci_event_flag` that is declared nowhere — any use would not compile; they and the `HCI_FLAG_*` enum values exist only as unusable decoration copied between the two headers.
- Fix: Delete `GetExportEntry` (function + prototype) and the three `hci_event_flag_*` macros from both BT headers.
- Benefit: Small but pure removal; the headers stop advertising an API that cannot be called.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-IOP-12 — `bdm_query` reports resident success when its only thread failed to start
- Category: 8
- Locations: iop/bdm_query/bdm_query.c:36-40,84-101
- Problem: `_start` creates the RPC thread, starts it only `if (thread_id >= 0)`, and then unconditionally `return MODULE_RESIDENT_END` (bdm_query.c:95-101). If `CreateThread` fails the module stays resident with no RPC server registered, and every EE-side `bdm_query` call binds to nothing / times out with no IOP-side trace of why. The RPC handler also explicitly discards its `size` argument (`(void)size`, bdm_query.c:38-40) — harmless for the single current command (it takes no payload), but it means a future command added EE-side would be parsed from the 64-byte `bdm_rpc_buffer` with no length ever available IOP-side.
- Fix: Return `MODULE_NO_RESIDENT_END` when `thread_id < 0`, matching the ds34 standalone `_start` functions in this same scope. Leave the handler's `(void)size` alone until a second command exists.
- Benefit: A failed start becomes a visible load failure instead of a silently dead helper.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-IOP-13 — EE ds34 clients copy the RPC buffer to the caller even when the RPC failed
- Category: 6
- Locations: modules/ds34usb/ee/libds34usb.c:126-139, modules/ds34bt/ee/libds34bt.c:119-132
- Problem: Both EE `get_data` implementations compute `ret = (SifCallRpc(...) == 0)` and then unconditionally `memcpy(data, rpcbuf, 18)`. On RPC failure `rpcbuf` holds the previous call's pad data (it is a static, never cleared), so the caller receives stale buttons presented as a fresh sample alongside a failure return that the typical poll loop ignores. `ds34usb_get_bdaddr` (libds34usb.c:64-81) has the same shape in miniature: it copies all 6 address bytes out of `rpcbuf` regardless of the `ret &= rpcbuf[0]` result.
- Fix: Copy out only when the RPC succeeded (and, for `get_bdaddr`, when the IOP returned 1); otherwise leave the caller's buffer untouched.
- Benefit: Failed polls stop masquerading as live controller input on the EE side.
- Effort: S · Risk: Low · Confidence: High (READ)

## FILES READ

- modules/pademu/pademu.c, modules/pademu/pademu.h, modules/pademu/ds34usb.c, modules/pademu/ds34usb.h, modules/pademu/ds34bt.c, modules/pademu/ds34bt.h, modules/pademu/sys_utils.c, modules/pademu/sys_utils.h, modules/pademu/Makefile, modules/pademu/exports.tab, modules/pademu/imports.lst, modules/pademu/irx_imports.h
- modules/ds34usb/iop/ds34usb.c, modules/ds34usb/iop/ds34usb.h, modules/ds34usb/iop/Makefile, modules/ds34usb/iop/imports.lst, modules/ds34usb/iop/irx_imports.h, modules/ds34usb/iop/smsutils.S (md5/wc only — identical to ds34bt copy), modules/ds34usb/ee/libds34usb.c, modules/ds34usb/ee/libds34usb.h, modules/ds34usb/ee/Makefile, modules/ds34usb/Makefile
- modules/ds34bt/iop/ds34bt.c, modules/ds34bt/iop/ds34bt.h, modules/ds34bt/iop/Makefile, modules/ds34bt/iop/imports.lst, modules/ds34bt/iop/irx_imports.h, modules/ds34bt/ee/libds34bt.c, modules/ds34bt/ee/libds34bt.h, modules/ds34bt/ee/Makefile, modules/ds34bt/Makefile
- iop/ata_bd_fast/ps2atad.c, iop/ata_bd_fast/atad.h (wc + Makefile comment context), iop/ata_bd_fast/Makefile, iop/ata_bd_fast/exports.tab, iop/ata_bd_fast/imports.lst, iop/ata_bd_fast/irx_imports.h
- iop/bdm_query/bdm_query.c, iop/bdm_query/Makefile, iop/bdm_query/imports.lst, iop/bdm_query/irx_imports.h (via imports listing)
- modules/Rules.bin.make
- Root Makefile (ds34/pademu/ata_bd rules only, lines 54-99, 308-344) and AGENTS.md — context for build wiring, not audited as scope.

## FILES NOT READ

- modules/ds34bt/iop/smsutils.S as a separate read — not opened individually; established byte-identical to modules/ds34usb/iop/smsutils.S by md5 (`3612cf1bd66a11f0b9e53ac78a5940d7` for both) and 0-line diff.
- iop/ata_bd_fast/ps2atad.c lines 801-1186 in full prose — the file was read at 1-800 plus the probe/init sections at 1187-1310 and targeted greps over the remainder; no finding cites the un-read middle except the whole-file dead-code finding (IOP-02), which rests on the root Makefile's own "kept but unused" statement.
- Everything outside the stated scope (EE application code in `src/`, Lua, other IOP modules, `.research/`) — not read, except the scripted absence searches and root-Makefile rules noted above.
- Nothing under `~/workspace/Sable-audit/` — not read, listed, or opened (blind rule).
