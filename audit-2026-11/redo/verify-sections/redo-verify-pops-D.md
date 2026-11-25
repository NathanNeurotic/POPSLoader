# Adversarial Verification — Redo POPSLoader, Chunk D (IOP pademu / ds34 drivers)

- Subject: `~/workspace/Sable-audit-redo/Redo-POPSLoader.md`
- Clone (read-only): `~/workspace/audit-clones-2026-11-13/POPSLoader`
- Pin verified before work: `git rev-parse HEAD` = `29272cddbf0122f14e76bc3bdd75e3b46aa870be`, clean tree.
- Method: refute-first. Every cited file/line opened with surrounding context in all four ds34 copies where cited; types re-derived from the headers in-tree (`epCount`, `out_size`, `report->Power`, `mips_memcpy` prototype); every numeric/census claim re-derived with own shell commands (`wc -l`, `diff | wc -l`, `md5sum`, repo-wide `grep`).
- Findings assigned: RE-POPS-002, 003, 009, 010, 024, 025, 026, 035, 047, 053, 096.

---

### RE-POPS-002 — VERIFIED-DRIFT

USB descriptor walk trusts `bLength`/`bNumEndpoints` in all four copies — mechanism stands; the iteration count for `bNumEndpoints == 0` and the BT scope are corrected.

Evidence (all four copies read in full):

- Identical walk in `modules/pademu/ds34usb.c:121-147`, `modules/ds34usb/iop/ds34usb.c:128-154`, `modules/pademu/ds34bt.c:110-137`, `modules/ds34bt/iop/ds34bt.c:111-142`: `interface = (void*)config + config->bLength; epCount = interface->bNumEndpoints - 1; endpoint = UsbGetDeviceStaticDescriptor(..., USB_DT_ENDPOINT); do { ...; endpoint = (void*)endpoint + endpoint->bLength; } while (epCount--);` No NULL check on `device`/`config`/`endpoint` in any `*_connect`, no `bLength == 0` guard, no use of `config->wTotalLength` anywhere in the walk. Confirmed.
- DS4 hardcode confirmed, USB copies only: `epCount = 20; // ds4 v2 returns interface->bNumEndpoints as 0` (pademu `ds34usb.c:128`, standalone `:135`). `do/while(epCount--)` with `epCount = 20` executes the body for checked values 20,19,…,1,0 = **21 iterations** — redo's "walks 21 descriptors" is exact.
- `bLength == 0` confirmed as a stall: the pointer never advances and the same descriptor is re-examined for the remaining iterations. Minor wording correction: it does not literally "re-open" the same endpoint on later iterations — the `interruptEndp < 0` / `outEndp < 0` / `inEndp < 0` guards suppress a second `UsbOpenEndpoint*` for a direction already opened.

Corrected figure — the `bNumEndpoints == 0` count (redo: "~2^31 times"):

- `epCount` is a **signed `int`** in all four copies: `int pad, epCount;` (pademu USB `:93`, standalone USB `:100`), `int epCount;` (pademu BT `:87`, standalone BT `:88`). `bNumEndpoints` is a `u8` descriptor field (PS2SDK `usbd.h` `UsbInterfaceDescriptor`), so `0 - 1` promotes to `int -1`, not to a large unsigned value.
- `do {…} while (epCount--)`: checked values run −1, −2, …, −2,147,483,648 (INT_MIN), then — in wraparound machine arithmetic — 2,147,483,647 down to 1, then 0 stops it. That is **2^32 = 4,294,967,296 body executions**, not ~2^31. Formally, decrementing past INT_MIN is signed-overflow UB in C, so the strictly correct statement is "unbounded / UB, 2^32 iterations under two's-complement wrap; an IOP crash from the out-of-bounds walk will occur long before either count completes." The redo understates the count by a factor of 2 and omits the UB point; the severity conclusion is unchanged (in fact stronger).

Scope correction — BT copies are partially guarded by probe:

- USB probe (both copies, `usb_probe`) checks only `device == NULL` and VID/PID (DS3/DS4/DS4-Slim). It imposes **no** constraint on `bNumEndpoints`, `config`, or `wTotalLength`, so the zero-endpoint case is fully reachable in both USB copies through the normal probe→connect path.
- BT probe (both copies, `bt_probe`) **does** reject the device if `intf->bNumEndpoints < 3`, and also checks `config == NULL`, `bNumInterfaces < 1`, and a minimum `wTotalLength`. So for the two BT copies the specific `bNumEndpoints == 0` runaway is defeated **if** USBD only calls `bt_connect` after a successful `bt_probe` on the same descriptor set (the normal USBD contract, not re-verifiable from this repo alone). The BT copies remain exposed to the other two mechanisms redo cites: `endpoint->bLength == 0` stall and walking past `wTotalLength` with a legal `bNumEndpoints >= 3` but truncated/lying endpoint descriptors, plus unchecked NULL `device`/`config`/`endpoint` inside `bt_connect` itself.

Fix assessment: sane and LESS-NOT-MORE — NULL checks in connect, iterate at most the real count, stop on `bLength == 0` or at `config + wTotalLength`, drop the hardcoded 20. No new machinery.

Duplicate flag: none as a mechanism duplicate; this flaw is one of the shared flaws RE-POPS-053 uses as consolidation evidence (dependency, not duplication).

---

### RE-POPS-003 — VERIFIED-DRIFT

`pademu.c` SIO2 parsing with no size floor and unchecked multitap slot — all four mechanisms present; the `out_size < 3` arithmetic in the redo is wrong, and the true consequence is worse than claimed.

Evidence (full `modules/pademu/pademu.c:202-536` read):

1. Second-command scans confirmed. Hook version `pademu_hookSio2man:228`: `for (ctrl = 5; ctrl < td->in_size - 3; ctrl++)` with `ctrl` declared `register u32` (`:204`) and `td->in_size` declared `u32` (`pademu.h:46`). If `in_size < 3`, `in_size - 3` wraps to ~2^32 and the scan reads `td->in[ctrl]`, `td->in[ctrl+1]`, `td->in[ctrl+2]` far past the transfer. Not-found test `:236` is `if (ctrl + 3 == td->in_size)` — equality only; on the wrapped path it never fires, and `:240` then writes `td->in[ctrl] = 0x00` at the runaway index.
   - Correction of detail: the second scan, in `pademu():314`, does **not** use `ctrl`. Its variable is `cmd_size`, declared `u8` (`:299`). The wrap still occurs in the comparison (promoted to `u32`), but the index itself is a `u8` that cycles 255→0, so that copy of the scan reads at most `td->in[0..257]` while potentially never terminating, rather than walking unboundedly far. Redo lumps both scans under the `ctrl` form; the mechanism is the same, the reach differs.
2. `pademu_cmd` (369-494) confirmed: `mips_memset(out, 0x00, out_size)`, unconditional writes to `out[0..2]`, `switch (in[1])` with reads of `in[3]` (0x43/0x46/0x4C), `in[3..4]` (0x44), `in[3..8]` (0x4D loop `in[3+i]`, i=0..5), `in[3..6]` (0x4F), and `in[pad[port].lrum/rrum]` in 0x42 — with no check anywhere that the transfer supplied that many bytes. Its length parameter is named `out_size` but every caller passes an `in_size`-derived value (`:359` `cmd_size = td->in_size`; `:346/:352` `td->in_size - cmd_size`), itself truncated to the `u8` parameter on the call.
   - **Corrected arithmetic (redo: "`out_size` is `u8`, so `out_size < 3` underflows to ~253"):** false as written. At `pademu.c:415`, `PAD_GET_DATA(&out[3], out_size - 3, port)`: `out_size` (`u8`) is integer-promoted to `int`, so `out_size - 3` is **−3, −2 or −1** (for `out_size` 0, 1, 2), and `ds34*_get_data(u8 *dst, int size, int port)` (both pademu headers) receives that negative `int`. Inside `get_data`, `mips_memcpy(dst, ds34pad[port].data, size)` passes it to a prototype of `void mips_memcpy(void *, const void *, unsigned)` (`sys_utils.h:23`, both standalone headers likewise), converting it to **4,294,967,293..4,294,967,295 bytes** — a catastrophic copy, not a ~253-byte one. Redo's ~253 would only occur if the subtraction were performed in `u8` arithmetic, which C promotion rules do not do here. Mechanism verified; magnitude corrected upward.
3. Multitap slot confirmed: `pademu_mtap:528` (redo prose says :527, which is the preceding `mips_memcpy` line — one-line citation slip) `mtap_slot = td->out[5] = td->in[2];` with no range check; `mtap_slot` is a file-static `u8` (any value 0-255). `pademu():361-363` then does `port = mtap_slot` when `mtap_inited`, and `pademu_cmd` indexes `pad[port]` (`pad` is `pad[MAX_PORTS]`, `MAX_PORTS 4`, `pademu.c:59,67`) and, via the `PAD_*` macros, `ds34pad[port]`. Any slot byte ≥ 4 is an out-of-bounds read/write. `MAX_SLOT 4` is defined at `:500` but never applied to the stored value. Confirmed.
4. `pademu_mtap` (502-536) confirmed: after only the `port1 != mtap_port` check it switches on `td->in[1]`, reads `td->in[2]` in case 0x21, and writes `td->out[5]`/`td->out[6]` plus a 6-byte `mips_memcpy(td->out, &mtap_data, …)`, with no `in_size`/`out_size` floor at all. Its only upstream gate is in the hook (`td->in[0] == 0x21 && mtap_enabled` and a `port_ctrl2` value), which itself reads `td->in[0]` unchecked.

No defeating guard found: neither `pademu_hookSio2man`, `pademu`, `pademu_cmd`, nor `pademu_mtap` checks `in_size` against any floor. (Note on scope, not a defeat: `td->in`/`td->out` are sio2man-owned allocations, so reads past `in_size` but inside the allocation return stale bytes; the runaway-scan and negative-copy cases above go far beyond any plausible allocation.)

Fix assessment: rejecting `in_size < 10` at the entry points is sane for `pademu_cmd` (highest index touched is `in[8]`/`out[8]`) and follows LESS-NOT-MORE; changing the not-found tests to `>=` and rejecting `mtap_slot >= MAX_SLOT` at store time are the right minimal forms. Caution worth recording: a blanket `< 10` floor applied to `pademu_mtap` should be checked against legitimate short multitap transfers before adoption — the mtap cases themselves only need `in_size >= 3` / `out_size >= 7`.

Duplicate flag: **partial mechanism overlap with RE-POPS-024** — the `pademu.c:415` `PAD_GET_DATA(..., out_size - 3, port)` call site is cited by both findings; 003 owns the caller-side size derivation/underflow, 024 owns the callee-side missing clamp in `get_data`. Not a full duplicate, but a fix in one place (clamp inside `get_data`) mitigates the large-`size` half of both.

---

### RE-POPS-009 — VERIFIED

BT HCI/L2CAP/HID handlers ignore the received byte count and parse stale buffer bytes — in both BT copies.

Evidence:

- `hci_buf` is `u8[MAX_BUFFER_SIZE]` with `MAX_BUFFER_SIZE 64` (`ds34bt.h:18`, both copies); `l2cap_buf` is `MAX_BUFFER_SIZE + 32`. Both are static, never cleared between packets.
- HCI: `hci_event_cb(int resultCode, int bytes, void *arg)` discards `bytes` and calls `HCI_event_task(resultCode)` — pademu `ds34bt.c:760-763`, standalone `ds34bt.c:824-828` (redo citations :763/:828 are the call lines). `HCI_event_task(int result)` switches on `hci_buf[0]` and, in real (non-debug) code, reads up to `hci_buf[11]`, does `memcmp(ds34pad[i].bdaddr, hci_buf + 5, 6)` / `memcmp(hci_buf + 3, …, 6)`, a 19-byte `memcmp(hci_buf + 9, "Wireless Controller", 19)` (bytes 9-27) in the remote-name branch, and `mips_memcpy(ds34pad[pad].bdaddr, hci_buf + 2, 6)` plus `hci_accept/reject_connection(hci_buf + 2)` in the connect-request branch — all with no knowledge of how many bytes actually arrived. A truncated packet therefore acts on the previous packet's residue as handles/addresses/device type. Confirmed.
- L2CAP: `L2CAP_event_task(int result, int bytes)` (pademu :908, standalone :972) receives `bytes` but a grep of the whole function body shows `bytes` is used **only** at the `hid_readReport(l2cap_buf, bytes, pad)` call (pademu :1056); every signalling branch first reads `l2cap_buf[8]` and fields at `[9]`, `[12]-[15]`, `[14]-[19]`-range for connection/config/disconnect handling and feeds them into response functions, with no `bytes` floor. Confirmed.
- HID: `hid_readReport(data, bytes, pad)` (pademu :1211, standalone ~:1275) checks only `data[8]`/`data[9]`, then casts `&data[11]` to `struct ds3report *` / `struct ds4report *` and reads the full report (pressure bytes, sticks, touchpad fields). Its only length uses are `bytes == 21` (pressure-emulation trigger) and the DS4 touchpad gate `bytes > 63` (pademu :1336). A short packet with matching header bytes parses stale `l2cap_buf` content as live buttons. Confirmed.

One sub-example does not survive scrutiny (recorded, does not change the verdict): the `HCI_EVENT_NUM_COMPLETED_PKT` loop `for (i = 0; i < hci_buf[2]; i++)` reading `hci_buf[3+i]`/`hci_buf[4+i]` — redo's unbounded-against-64-byte-buffer point is textually true, but the loop body consists solely of a `DPRINTF(...)`, and `DPRINTF(x...)` is defined as an empty macro in both BT copies, so those reads are discarded by the preprocessor and never execute in a build. The finding's other HCI branches (above) contain real reads and carry the mechanism on their own.

Fix assessment: sane — thread `bytes` into `HCI_event_task` and drop packets shorter than each branch's fixed header (L2CAP signalling 20 bytes, HID 11 + report size). One early return per handler, LESS-NOT-MORE compliant.

Duplicate flag: mechanism sibling of RE-POPS-010 (the unchecked `Power` index is read inside this same `hid_readReport`), but a distinct defect (missing length validation vs. missing range validation). See also Candidate C-1 below for the USB-transport analogue, which RE-POPS-009 does not cover.

---

### RE-POPS-010 — VERIFIED

DS3 battery byte indexes the 6-entry `power_level[]` unchecked in all four copies.

Evidence (every cited line opened):

- `static u8 power_level[] = {0x00, 0x00, 0x02, 0x06, 0x0E, 0x1E};` — 6 entries, indices 0-5 — at pademu USB `ds34usb.c:44-46`, standalone USB `:45-46` (array body :46-47), pademu BT `ds34bt.c:256-258`, standalone BT `:261-262`. Redo citations match.
- Index sites, all of the form `if (report->Power != 0xEE) oldled[0] = power_level[report->Power];`: pademu USB `:303-304`, standalone USB `:298-299`, pademu BT `:1275-1276`, standalone BT `:1332-1333`. Redo citations exact.
- Type check (as instructed): in `struct ds3report`, `Power` is a **full `u8`** — `u8 Power; // Battery status ? 05=full … EE=charging` (pademu `ds34usb.h:123`, standalone USB `ds34usb.h:121`, pademu BT `ds34bt.h:289`, standalone BT `ds34bt.h:309`). It is *not* the 4-bit `Power` field that exists in the separate DS4 report struct in the same headers, so no bitfield truncation rescues the index. Device-supplied, no masking anywhere on the path.
- No defeating guard: the BT copies' `report->Power = 0x05;` assignment (pademu BT :1249, standalone BT :1314) runs only in the `press_emu` sub-branch and only before the non-emulated pressure copy is skipped; the index site is reached with the raw device byte in the normal path. All four sites are additionally gated by `report->PSButtonState` (in the pademu copies as the outer `if`, in the standalone copies inline as `PSButtonState &&`) — redo's parenthetical attributes that gate only to the standalone copies; it exists in all four and does not bound the index in any of them.

Completeness note (understatement, not error): redo says "any value 6-0xED except 0xEE". The full out-of-bounds set is **6-255 except 0xEE** (249 values) — 0xEF-0xFF are equally out of bounds and equally unexcluded by the `!= 0xEE` test.

Fix assessment: sane — index only when `report->Power <= 5`, fall back to the normal LED pattern the surrounding `else` already uses. Minimal, LESS-NOT-MORE compliant.

---

### RE-POPS-024 — VERIFIED

`get_data` copies a caller-supplied `size` out of an 18-byte array in all four copies; the pademu copies never bounds-check `port`.

Evidence:

- `data` is `u8 data[18]` in all four device structs: pademu `ds34usb.h:31`, pademu `ds34bt.h:48`, standalone `ds34usb/iop/ds34usb.h:30`, standalone `ds34bt/iop/ds34bt.h:52`.
- All four implementations end in an unchecked `mips_memcpy(dst, ds34pad[port].data, size)`: pademu USB `ds34usb.c:546` (function :526), pademu BT `ds34bt.c:1436` (function :1430), standalone USB `ds34usb/iop/ds34usb.c:553` (function :530), standalone BT `ds34bt/iop/ds34bt.c:1529` (function :1519). Redo citations exact. `size` is an `int` parameter in all four; nothing clamps it to 18, and a negative `size` converts to a huge `unsigned` at the `mips_memcpy` prototype (see RE-POPS-003).
- Pademu caller confirmed: `pademu.c:415` passes `out_size - 3` derived from the SIO2 transfer (max 252 for a `u8` `out_size` of 255 — an over-read of up to 234 bytes past `ds34pad[].data` and a matching over-write at `&out[3]`).
- Standalone callers confirmed to be safe only by discipline: the RPC dispatchers pass the constant 18 — `ds34usb_get_data((char *)data, 18, *(u8 *)data)` (standalone USB :731) and `ds34bt_get_data((char *)data, 18, *(u8 *)data)` (standalone BT :1657).
- Port checks confirmed asymmetric exactly as claimed: **no** pademu entry point checks `port` — USB `set_rumble` (:515), `get_data` (:526), `set_mode` (:564), `get_status` (:580) and BT `set_rumble` (:1419), `get_data` (:1430), `set_mode` (:1444), `get_status` (:1456) all index `ds34pad[port]` / take `ds34pad[port].sema` directly (BT via the shared `bt_dev.hid_sema` plus `ds34pad[port]`). Standalone entry points do check: USB `set_rumble`/`set_led`/`get_data`/`get_bdaddr` all begin `if (port >= MAX_PADS) return;` (:514-535, :558), BT `set_rumble` (:1449), `set_led` (:1466), `get_data` (:1519) likewise, and BT `get_status` conditions on `port < MAX_PADS`. Since every reachable `port` source is a `u8` (RPC byte, `port1 & 0x03`, or `mtap_slot`), the `>=`-only standalone check is sufficient; the pademu path's exposure is precisely the unchecked `mtap_slot` of RE-POPS-003.

Fix assessment: sane — clamp `size` to 18 inside `get_data` (one place per copy, one place total after RE-POPS-053) and copy the standalone `port >= MAX_PADS` early return into the pademu entry points. LESS-NOT-MORE compliant.

Duplicate flag: partial overlap with RE-POPS-003 at the `pademu.c:415` call site (see 003 block). Distinct callee-side defect; not a full duplicate.

---

### RE-POPS-025 — VERIFIED

Pademu BT copy clears the DS4 LED buffer with the DS3 length and sends 29 uninitialised bytes; the fix exists in the standalone copy.

Evidence — arithmetic re-derived from the headers, as instructed:

- Constants (both BT headers, pademu `ds34bt.h:227,231` and standalone `ds34bt.h:247,251`): `PS3_01_REPORT_LEN = 0x30 = 48`; `PS4_11_REPORT_LEN = 0x4D = 77`.
- Pademu `hid_LEDRumble` (`ds34bt.c:1145-1208`): `u8 led_buf[PS4_11_REPORT_LEN + 2]` = **79 bytes** (:1147); `u8 size = 2`, DS4 branch does `size += PS4_11_REPORT_LEN` → **79 bytes sent** (:1200), via `HID_command(..., led_buf, size, pad)` (:1208), and `HID_command` (:1107-1122) copies all `length` bytes into `l2cap_cmd_buf` and bulk-transfers them. But the DS4 branch clears only `mips_memset(led_buf, 0, PS3_01_REPORT_LEN + 2)` = **50 bytes** (:1181).
- Uninitialised count: 79 − 50 = **29 bytes** (indices 50-78). The DS4 branch's own assignments touch only indices 0,1,2,4,7,8,9,10,11 and optionally 12,13 — all inside the cleared region — so nothing else initialises 50-78. Redo's "50 vs 79" and "29 uninitialised bytes" are exact.
- Standalone copy contains the correct form: `mips_memset(led_buf, 0, PS4_11_REPORT_LEN + 2)` at `modules/ds34bt/iop/ds34bt.c:1243`, in an otherwise near-identical function (:1206-1273). Copy-sync miss confirmed, not a design difference. (The two copies do differ elsewhere in this function — pademu multiplies `rrum * 255` at :1189-equivalent where standalone does not — which further supports the hand-sync-divergence framing of RE-POPS-053.)

Fix assessment: sane — change the one constant in the pademu copy to `PS4_11_REPORT_LEN + 2`. (Redo's fix text cross-references "RE-POPS-047/03", an apparent garbled reference to RE-POPS-047/053; the one-constant fix stands on its own.)

---

### RE-POPS-026 — VERIFIED

Standalone USB copy lost the DS3 null-report guard the other three copies have.

Evidence — grep for the guard across all four copies returns exactly three hits:

- `modules/pademu/ds34usb.c:269-270`: `if (report->RightStickX == 0 && report->RightStickY == 0) return; // ledrumble cmd causes null report sometime`
- `modules/pademu/ds34bt.c:1219-1220`: same guard in `hid_readReport`.
- `modules/ds34bt/iop/ds34bt.c:1284-1285`: same guard in `hid_readReport`.
- `modules/ds34usb/iop/ds34usb.c`: **no hit**. Its `readReport` DS3 branch (:268-275, function at :263) goes from `report = (struct ds3report *)&data[2];` straight to `ds34pad[pad].data[0] = ~report->ButtonStateL;` and the full stick/pressure copy. Redo citations (:263-275 for the standalone branch) match.

No equivalent suppression elsewhere in the standalone USB copy: `get_data` checks only the transfer result code (`usb_resulCode`) before calling `readReport(usb_buf, port)`, and no caller filters an all-zero-stick report. The claim that this copy is "the one POPSLoader actually embeds" is corroborated under RE-POPS-047 (top-level Makefile builds/embeds only `modules/ds34usb/iop/ds34usb.irx`). This is the reverse-direction sync miss to RE-POPS-025, as claimed.

Fix assessment: sane — restore the same two-line guard at the top of the DS3 branch. (Note: stick value 0 is full deflection, not centre (~0x7F), so the guard's false-positive cost is a dropped extreme-corner report, exactly the trade-off the other three copies already accept.)

---

### RE-POPS-035 — VERIFIED

EE ds34 clients copy the RPC buffer to the caller even when the RPC failed — both EE libs.

Evidence (both files read in full):

- USB: `modules/ds34usb/ee/libds34usb.c:126-140` — `ret = (SifCallRpc(&ds34usb, DS34USB_GET_DATA, 0, rpcbuf, 1, rpcbuf, 18, NULL, NULL) == 0);` followed **unconditionally** by `memcpy(data, rpcbuf, 18);` (:137), then `return ret;`. BT: `modules/ds34bt/ee/libds34bt.c:119-133` — identical shape, `memcpy(data, rpcbuf, 18);` at :130. Redo citations (:126-139 / :119-132) match.
- `rpcbuf` is a static `u8 rpcbuf[64]` in both libs and is never cleared anywhere in either file (grep confirms no `memset`/clear of `rpcbuf`), so on RPC failure the caller receives the previous successful sample. One precision: `rpcbuf[0] = port;` is written immediately before the call in both `get_data`s, so byte 0 of the "stale" copy is in fact the port number, and bytes 1-17 are the stale sample — the masquerade is marginally worse than redo states, not better.
- `ds34usb_get_bdaddr` miniature confirmed: `libds34usb.c:66-83` (redo cites :64-81, two lines early at both ends) — `ret = (SifCallRpc(...) == 0); ret &= rpcbuf[0];` then an unconditional `for (i = 0; i < 6; i++) bdaddr[i] = rpcbuf[i + 1];`.
- The correct pattern exists in the same files, proving anomaly rather than house style: USB `ds34usb_get_status` (:53-64) returns `rpcbuf[0]` only inside the success `if`; BT `ds34bt_get_bdaddr` (:77-91), `ds34bt_get_version` (:143-157) and `ds34bt_get_features` (:159-173) all copy out only inside the `SifCallRpc(...) == 0` block. Redo correctly does **not** accuse the BT `get_bdaddr`.
- Caller behaviour (checked in `src/luacontrols.cpp`): mixed, as redo's "typical poll loop ignores" implies. `lua_getpressure` (:167-168) calls both `get_data`s ignoring the return entirely; the button/joystick readers (:46-58, :109-110, :138-139) do test the return before *using* the data — but the caller's buffer (`buttons.btns` / `pad.btns`) has already been overwritten with stale bytes by then, so the library-level defect stands regardless of caller discipline.

Fix assessment: sane — copy out only on RPC success (and, for USB `get_bdaddr`, only when the IOP returned 1); leave the caller's buffer untouched on failure. Matches the in-file correct pattern; LESS-NOT-MORE compliant.

---

### RE-POPS-047 — VERIFIED-DRIFT

Whole `modules/pademu/` tree is built by nothing — build claim verified; the line total is corrected.

Evidence — searches re-run independently:

- Top-level `Makefile`: `EXT_LIBS = modules/ds34usb/ee/libds34usb.a modules/ds34bt/ee/libds34bt.a` (:82); `IOP_MODULES` lists `ds34bt.o ds34usb.o` (:97-99 region); explicit rules build only `modules/ds34bt/iop/ds34bt.irx`, `modules/ds34usb/iop/ds34usb.irx` and the two EE libs (:308-324 region). No rule references `modules/pademu/`, `usb_pademu.irx`, or `bt_pademu.irx`, even though `modules/pademu/Makefile:1-25` defines exactly those two outputs (`IOP_BIN = usb_pademu.irx` / `bt_pademu.irx` under `USE_USB`/`USE_BT`).
- Repo-wide `grep -rni pademu` (excluding `.git`): 42 hits total, 39 of them inside `modules/pademu/` itself. The only three outside hits are documentation, none of them a build reference: `COMPONENTS.md:412` (a one-line listing of the tree), `.research/wiki/ds34.md:34` and `.research/wiki/proto.md:186` (research notes describing POPSTARTER's `MODULE_2.IRX = usb_pademu.irx / bt_pademu.irx` slot). A targeted grep over the top `Makefile`, `.github/`, `src/`, `bin/`, `etc/` for `pademu`/`usb_pademu`/`bt_pademu` returns **zero** hits — redo's scripted-search claim reproduces exactly for the scopes it names, and extending the search to the whole repo, all Makefiles/`*.mk`, workflows, and Lua finds no additional builder. No file named `*pademu*` exists anywhere outside `modules/pademu/`.

Corrected figure — tree size (redo: 3,474 lines):

- `wc -l` over all 12 files in `modules/pademu/`: **3,558 lines** total (Makefile 25, ds34bt.c 1521, ds34bt.h 360, ds34usb.c 634, ds34usb.h 194, exports.tab 10, imports.lst 49, irx_imports.h 40, pademu.c 536, pademu.h 60, sys_utils.c 94, sys_utils.h 35).
- Source-only subtotal (`.c` + `.h`): **3,434 lines**. Redo's 3,474 matches neither figure (84 below the all-files total, 40 above the source-only total) and is not reproducible from the pinned tree by either natural counting rule.

Minor framing note: redo's parenthetical that the pademu copies "still receive pademu-only edits (analog toggle, fake-DS3 option)" is loosely worded — both mechanisms also exist in the standalone copies in evolved form (standalone BT has the inverted `disable_fake` flag; standalone USB has the same `analog_btn` toggle). The trap redo identifies is nevertheless real: the pademu variants (`enable_fake` from `pad_options`, the SIO2-facing front end) exist only in this unbuilt tree, so an edit made here ships nowhere.

Fix assessment: sane as a decision-forcing recommendation (delete if POPSTARTER-side IRXs are no longer produced from this repo; otherwise move/label as an external build's source). Risk Med is fairly stated — the `.research` notes show the IRX names are a real POPSTARTER load slot, so deletion should follow the user's confirmation of where those IRXs are now built, which the fix text itself conditions on.

Duplicate/dependency flag: RE-POPS-053's consolidation fix is premised on this finding's retention decision, and RE-POPS-096's `GetExportEntry` half becomes moot if this tree is deleted (its macro half survives in the standalone BT header). Dependencies, not duplicates.

---

### RE-POPS-053 — VERIFIED

ds34 drivers exist as two hand-synced copies per transport; fixes land in one copy only.

Evidence — census re-derived with own commands:

- File sizes confirmed: pademu USB 634 lines vs standalone USB 806; pademu BT 1521 vs standalone BT 1719.
- Diff counts: `diff modules/pademu/ds34usb.c modules/ds34usb/iop/ds34usb.c | wc -l` = **399**; `diff modules/pademu/ds34bt.c modules/ds34bt/iop/ds34bt.c | wc -l` = **512**. Redo's "399 and 512 diff lines respectively" reproduces **exactly** under the plain-`diff`-output-lines metric. For the record, the changed-content lines alone (`grep -c '^[<>]'`) are 336 (USB) and 432 (BT) — redo's metric is the diff-output count, which is a defensible and now explicitly defined census.
- `smsutils.S` identity confirmed: `md5sum` of `modules/ds34usb/iop/smsutils.S` and `modules/ds34bt/iop/smsutils.S` are both `3612cf1bd66a11f0b9e53ac78a5940d7`; both are 180 lines (redo cites :1-180 for both — exact). `diff` of the two standalone `irx_imports.h` files is empty (byte-identical), as claimed. (The pademu tree has no `smsutils.S` of its own — it imports `mips_memcpy`/`mips_memset` via `sys_utils.h` under `USE_SMSUTILS` — which does not affect the claim as worded, since redo attributes the duplicate pair to the two standalone modules.)
- Divergence in both directions confirmed independently in this chunk: standalone BT has the correct DS4 `memset` size, pademu BT does not (RE-POPS-025, verified above); pademu USB has the DS3 null-report guard, standalone USB does not (RE-POPS-026, verified above); the descriptor-walk flaw (RE-POPS-002) and the `power_level` OOB (RE-POPS-010) exist in all four copies (both verified above). "Every future fix must currently be made up to four times" is accurate for the shared mechanisms.

Fix assessment: directionally sane (one source per transport, standalone files as the implementation, one shared `smsutils.S`/`irx_imports.h`), and the stated Effort L / Risk Med is honest — the pademu front end (SIO2 hook, no RPC server) and the standalone front end (RPC dispatch) differ structurally, so consolidation is a real refactor, not a deletion. It is correctly sequenced behind RE-POPS-047's keep/delete decision. LESS-NOT-MORE compliant as a *removal of duplication*, with the caveat that the `USB`/`BT`-define sharing mechanism it proposes must not grow a new abstraction layer.

---

### RE-POPS-096 — VERIFIED-DRIFT

Dead helpers and dead macros: `GetExportEntry` and the `hci_event_flag_*` family — deadness verified in full; the macro line citations are off by 2-3 lines.

Evidence:

- `GetExportEntry`: defined at `modules/pademu/sys_utils.c:56-67` (redo cites :56-68 — the closing brace/comment boundary, acceptable), prototyped at `modules/pademu/pademu.h:59` (exact). Repo-wide `grep -rn GetExportEntry` (excluding `.git`) returns **only** those two lines — no caller anywhere in the repo. The sibling claim also checks out: `GetExportTableSize` is used at `pademu.c:178` (`InstallSio2manHook(&lib[1], GetExportTableSize(&lib[1]) >= 61)`) and `HookExportEntry` at `pademu.c:146,163,165`, while `GetExportEntry` is used by neither `pademu.c` nor anything else.
- `hci_event_flag_*` macros: a repo-wide grep shows the three macros are defined in both BT headers and **never used** in any `.c` file; the identifier `hci_event_flag` itself appears nowhere as a declaration — only inside the macro bodies and in an enum comment (`/* HCI event flags for hci_event_flag */`). Any use of the macros would therefore fail to compile on an undeclared variable, exactly as claimed. The associated `HCI_FLAG_*` enum values are likewise referenced by no code outside the headers (grep excluding the headers returns nothing), supporting "exist only as unusable decoration copied between the two headers" (the two enums have themselves drifted: pademu uses `0x01`-style values with 7 entries, standalone uses `0x0001`-style with 9, including `HCI_FLAG_READ_VERSION`/`HCI_FLAG_READ_FEATURES`).

Corrected citations (redo → actual):

- Pademu header: redo `modules/pademu/ds34bt.h:69-71` → actual macros at **:67-69** (`hci_event_flag_clear` :67, `_set` :68, `_check` :69).
- Standalone header: redo `modules/ds34bt/iop/ds34bt.h:84-86` → actual macros at **:81-83** (`_clear` :81, `_set` :82, `_check` :83).

Fix assessment: sane pure removal (function + prototype, three macros × 2 headers). One incompleteness worth noting: the fix deletes the macros but leaves the now-purposeless `HCI_FLAG_*` enums in both headers — deleting them too would complete the stated benefit ("the headers stop advertising an API that cannot be called") at no extra risk, since they have zero references.

Dependency flag: the `GetExportEntry` half lives in the RE-POPS-047 tree and is moot if that tree is deleted; the macro half is in both BT headers, one of which (standalone) is live code.

---

## Closing tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 7 | RE-POPS-009, 010, 024, 025, 026, 035, 053 |
| VERIFIED-DRIFT | 4 | RE-POPS-002, 003, 047, 096 |
| WEAKENED | 0 | — |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — |
| **Total** | **11** | |

No finding in this chunk was refuted or materially weakened. All four drifts are numeric/citation corrections, and in two cases (002's iteration count, 003's negative-size copy) the corrected figures make the defect *worse* than the redo stated, not better. The only genuine scope reduction found anywhere is inside 002: the BT copies' `bNumEndpoints == 0` sub-case is pre-filtered by `bt_probe`'s `bNumEndpoints < 3` rejection under the normal USBD probe→connect contract.

## Candidates (new defects / extensions — not verdicts)

- **C-1 (sibling of RE-POPS-009, USB transport):** USB `readReport` has the same ignore-the-byte-count mechanism RE-POPS-009 documents for BT, in both USB copies. `usb_data_cb(int resultCode, int bytes, void *arg)` discards `bytes` (pademu `ds34usb.c:200-206`, standalone `:207-213`); `ds34*_get_data` checks only `usb_resulCode` and then calls `readReport(usb_buf, port)`, which casts `&data[2]` to `struct ds3report *` / DS4 report and reads the full report out of the static 64-byte `usb_buf` with no length validation. A short interrupt transfer parses stale `usb_buf` bytes as pad state. Not covered by any assigned finding (009 is BT-only).
- **C-2 (extension of RE-POPS-002):** `chrg_connect` in both BT copies (`modules/pademu/ds34bt.c:199-224`, `modules/ds34bt/iop/ds34bt.c:204-227`) dereferences `config->bConfigurationValue` from `UsbGetDeviceStaticDescriptor(..., USB_DT_CONFIG)` with no NULL check on `device` or `config`, although `chrg_probe` in the same files does check `device == NULL`. Same unchecked-descriptor family as 002, in a connect function 002 does not cite.
- **C-3 (minor, EE side, adjacent to RE-POPS-035):** `ds34usb_get_bdaddr`'s unconditional copy also runs when `SifCallRpc` itself failed, in which case `ret` becomes `0 & rpcbuf[0]` = 0 but the caller's `bdaddr` has still been overwritten with the send-buffer's contents (`rpcbuf[0]` was just set to `port`, bytes 1-6 are whatever previous RPC traffic left). Already counted inside 035's "in miniature" — flagged here only so a fix is not scoped to `get_data` alone.
