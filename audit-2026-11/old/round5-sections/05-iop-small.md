# Round 5 — Section 05: Remaining small IOP modules

- **Repo / pin:** NathanNeurotic/Launchstation @ `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (READ, `git rev-parse HEAD`). Read-only; no fetch/update.
- **Scope note:** Does not repeat LAUNCHSTATION-001…096. `iop/ps2host/net_fio.c:95-480` and the `pko_*` caller set (Round 2) were not re-filed; `iop/smb2man/usmb2/usmb2.c:60-620,890-1085` (Round 2) were not re-read except as context for the remainder. No build or hardware claims. No secret-like values anywhere in scope.
- **Built verdicts** are from `ps2.yaml` target + `embed_irx` entries (READ) unless marked DS34-variant.

---

## 1. `iop/udpfs_smap` — UDPFS SMAP receive driver

- **Provenance:** `iop/udpfs_smap/ORIGIN.md` — Neutrino `iop/smap` @ `06188cce…`, AFL-3.0 (`LICENSE` retained); local deltas documented there: `xfer.c` odd-tail FIFO fix, `exports.tab` `_retonly`, `smap.c` two startup fixes (PHY-reset wait, DEV9 capability test — both present in the text read: `src/smap.c:516` capability test, `:138-147` nine-wait PHY loop). READ.
- **Built:** YES — target `udpfs_smap` (`ps2.yaml:28-34`), embedded (`ps2.yaml:644`). The precompiled namesake in `__precompiled` is **not** this build (see §11).
- **Coverage ledger:** `src/main.c` 1-26 (all), `src/smap.c` 1-639 (all), `src/xfer.c` 1-271 (all), `include/main.h` (41), `include/smap.h` (41), `include/xfer.h` (41), `include/mprintf.h` (20), `include/irx_imports.h` (16), `ORIGIN.md`, `LICENSE` (inventory). Still unread: `src/imports.lst`, `src/exports.tab` (build glue, inventory only).

### T5-F1 / `HandleRxIntr` never counts a packet, so the link-check traffic reset is dead / Category 3
- **Locations:** `iop/udpfs_smap/src/xfer.c:158,165,199` (`NumPacketsReceived` initialised 0, never incremented, returned); consumer `iop/udpfs_smap/src/smap.c:431,443-450` (`ResetCounterFlag = HandleRxIntr(...)`; `if (ResetCounterFlag) counter = 3;` else the 1 s link-check counter decrements and `CheckLinkStatus` runs).
- **Problem:** The return contract ("packets received this interrupt") is always 0, so received traffic never resets the idle counter: `InitPHY` can be re-entered via `CheckLinkStatus` (`smap.c:367-373`) after ~3 s regardless of traffic. That is the code as written (READ); whether it misbehaves on hardware is INFERRED — a link that still reads LINK in `CheckLinkStatus` costs only a PHY read, so impact may be nil, but the counter/reset mechanism is provably inert.
- **Fix:** Increment `NumPacketsReceived` once per processed BD in the loop at `xfer.c:169-197` (one line), or — LESS — delete the variable, the return plumbing and the `ResetCounterFlag` branch and document that link check is purely periodic.
- **Benefit:** Either the intended traffic-aware behaviour, or ~6 dead lines removed. **Effort:** trivial. **Risk:** low (increment variant changes link-check timing only). **Confidence:** READ (mechanism), INFERRED (impact).

### T5-F2 / `smap_transmit` retries a full/dead TX queue forever with no stop or timeout / Category 3
- **Locations:** `iop/udpfs_smap/src/xfer.c:249-271` (`while (1)` around `HandleTxReqs`, 100 µs delay, no iteration bound, no `NetDevStopFlag` test — contrast `smap.c` InitPHY loops, which all test `NetDevStopFlag`).
- **Problem:** If BDs never drain (link lost mid-transfer, EMAC stalled), the calling thread spins forever and the packet's owner never gets an error. READ as code; trigger frequency INFERRED.
- **Fix:** Bound the loop by the same 2 s budget the function already uses for init waits (`xfer.c:252-256`) and return non-zero on expiry — callers already distinguish `r >= 0` inside the loop; the function's `return 0` tail would need to become the error value.
- **Benefit:** A wedged TX path becomes a recoverable error instead of a hung loader thread. **Effort:** small. **Risk:** low-medium (a genuinely slow drain >2 s would now fail; 100 Mb/s TX FIFO drain is orders of magnitude faster). **Confidence:** READ.

- **Checked-and-clean:** `xfer.c:94-99` header pre-read clamped to `g_hdr_buf[64]`; `xfer.c:144-152` odd-tail fix present as ORIGIN.md claims (final word read once, only valid bytes stored); `xfer.c:106-141` DMA block-size selection respects `g_dma_max_block_size` tiers and PIO tail bounds (`i + 4 <= bytes`); `smap.c:568-580` EEPROM MAC checksum + all-zero rejection; `smap.c:463-499` SetupNetDev cleans up event flag/thread on each failure step; `CopyToFIFO` (`xfer.c:81-92`) PIO tail reads whole words past `length` into the TX FIFO — by-design padding read of ≤3 bytes past the caller's buffer, noted, not filed (inherited Sony-style FIFO feeding; destination is a hardware register, source over-read is the only exposure).

---

## 2. `iop/hdl_info` — HDLoader game-info RPC (2006, Polo)

- **Provenance:** Legacy HDLoader-era code (`main.c:31-32` "v 0.1 / 2006 Polo"); `ps2_hdd.h` header says "borrowed from ps2fdisk". No VENDORED/ORIGIN file. READ.
- **Built:** YES — target `hdl_info` (`ps2.yaml:81-90`), embedded (`ps2.yaml:678`), loaded on demand (`src/init.c:2567-2572`).
- **Coverage ledger:** `main.c` 1-94, `hdd.c` 1-198, `apa.c` 1-320, `hdl.c` 1-178 (all); headers `apa.h` (48), `hdd.h` (82), `hdl.h` (29), `main.h` (8), `ps2_hdd.h` (79), `irx_imports.h` (30). Still unread: `imports.lst`, `exports.tab` (glue).
- **APA duplication evidence (coordinator request):** `iop/hdl_info/apa.c` — 9,728 B, md5 `e71d6ec11a17db2b13f2dcae08c99615`; `iop/ps2hdd_osd/apa.c` — 15,657 B, md5 `37fcea9a1f0c11b37c10b862fe51a97e`; `diff` = 843 diff lines. **Verdict: not a copy.** The hdl_info file is a minimal read-mostly APA *table reader* (checksum, `apa_ptable_read_ex`, LE get/set helpers; its `apa_check`/`apa_setup_statistics` are commented out at `apa.c:91-135,201-275`); the ps2hdd_osd file is the full APA driver (cache, journal-adjacent helpers, error sectors). They share the on-disk format, the `apa_` prefix and little else. No LESS deletion is available here — do not merge them.

### T5-F3 / `hdl_ginfo_write` writes a sector back to disk without checking the read that filled it, and copies 128 bytes from a 65-byte name field / Category 6
- **Locations:** `iop/hdl_info/hdl.c:108-123` (read result assigned at :115 and overwritten at :120; `memset(buffer + 8, 0, PS2_PART_NAMEMAX)` + `memcpy(buffer + 8, ginfo->name, PS2_PART_NAMEMAX)` at :117-118); field sizes: `ginfo->name` is `char[65]` (`hdl.h`: `name[HDL_GAME_NAME_MAX + 1]`, 64+1), `PS2_PART_NAMEMAX` is 128 (`ps2_hdd.h`).
- **Problem:** (1) If the initial `hio->read` fails, `buffer[1024]` is uninitialised stack, the name patch is applied to garbage, and that garbage is **written to the game's header sector on disk** — a failed read becomes on-disk corruption. (2) The 128-byte `memcpy` over-reads 63 bytes past `ginfo->name` into whatever follows the struct (in `hdl_glist_write`'s array, the next game's entry) and writes those bytes into the sector past the name field. Both READ.
- **Fix:** Return the read result if non-zero / `bytes != 1024` before touching `buffer` (mirrors `hdl_ginfo_read`'s own check at :40); copy `strlen(ginfo->name)` bounded to the field, not `PS2_PART_NAMEMAX`.
- **Benefit:** Removes the only write-to-disk-on-error path in the module and a 63-byte struct over-read. **Effort:** trivial. **Risk:** low. **Confidence:** READ.

### T5-F4 / `hdl_ginfo_read` `strcpy`s disk-controlled strings into 65- and 13-byte fields, and sums `subs[]` for a disk-controlled `nsub` past the 64-entry array / Category 6
- **Locations:** `iop/hdl_info/hdl.c:43-49` (`for (i = 0; i < get_u32(&part->nsub); ++i) size += get_u32(&part->subs[i].length);` — `subs` is `subs[PS2_PART_MAXSUB]` = 64 entries, `ps2_hdd.h`); `hdl.c:48-49` (`strcpy(ginfo->name, buffer + 8)`, `strcpy(ginfo->startup, buffer + 0xac)`); destinations `hdl.h` (`name[65]`, `startup[13]`); source is a 1 KiB sector read from the game's own header area (`hdl.c:33-40`).
- **Problem:** A crafted/corrupt HDL game partition controls all three: `nsub` > 64 reads past the partition header struct while summing; a name in the sector with no NUL in the first 65+ bytes overflows `ginfo->name` in the heap-allocated games array; same for `startup` at 13 bytes. The partition header's APA checksum (`apa.c:160`) does not gate this sector — `hdl_ginfo_read`'s buffer is a different, unchecksummed area. READ (mechanism); exploitability beyond heap corruption on a hostile disk image is INFERRED.
- **Fix:** Clamp the loop to `PS2_PART_MAXSUB`; replace both `strcpy` with bounded copies + forced NUL (the adjacent `partition_name` copy at :46-47 already does exactly this pattern).
- **Benefit:** Hostile/corrupt HDD images stop being a heap-overflow vector in a module whose whole job is parsing HDD images. **Effort:** trivial. **Risk:** low. **Confidence:** READ.

### T5-F5 / Rename path: EE-supplied `NewName` is `strcpy`d with no termination guarantee, and the RPC handler never looks at `Size` / Category 6
- **Locations:** `iop/hdl_info/hdd.c:259,272-274` (`Packet->NewName` is `char[64]` in `Rpc_Packet_Send_Rename`, `hdd.h`; `strcpy(game->name, Packet->NewName)` into `char[65]`); dispatcher `iop/hdl_info/main.c:60-73` (`rpcCommandHandler` ignores `Size`, casts `Data` unconditionally for commands 4/5).
- **Problem:** The EE client (`src/hdl_rpc.c:74-76`, cross-reference only — outside this section) `strcpy`s into the same 64-byte field, so a ≥64-char new name arrives unterminated; the IOP `strcpy` then reads past the RPC buffer field and writes past `game->name`. The in-tree EE caller is the only client, so this needs a long name in the loader UI, not a network attacker — filed at that weight. READ.
- **Fix:** `strncpy` + force `game->name[64] = 0` (or reject `Size` smaller than the packet struct in `main.c` and bound the copy to 64).
- **Benefit:** One long game name stops corrupting the heap games list. **Effort:** trivial. **Risk:** low. **Confidence:** READ (IOP side), INFERRED (reachability via UI name-length limits, not checked in this section).

### T5-F6 / `hdl_glist_write` leaks the games array on every rename / Category 1
- **Locations:** `iop/hdl_info/hdl.c:141-166` (`tmp` malloc'd at :141, `tmplist` at :144; exit path frees only `tmplist` at :162; the `if (result != 0) free(tmp)` at :165-166 is unreachable on the success path and also skipped when the write loop breaks with `result == 0`).
- **Problem:** Every successful rename leaks `sizeof(hdl_game_info_t) * count` (~112 B × games) of IOP heap for the life of the module. Compare `hdl_glist_read` (:91-96), which does free both on its error path. READ.
- **Fix:** `free(tmp)` beside `free(tmplist)`. **Benefit:** LESS heap held forever. **Effort:** one line. **Risk:** none (array not referenced after return). **Confidence:** READ.

### T5-F7 / `apa_ptable_read_ex` end-of-disk test can wrap, and excludes a partition ending exactly at the disk end / Category 6
- **Locations:** `iop/hdl_info/apa.c:162-163` (`get_u32(&part.start) + get_u32(&part.length) < total_sectors`, 32-bit `u_long` arithmetic).
- **Problem:** `start + length` wraps modulo 2³², so a header claiming a huge length can pass the "behind end-of-HDD" test (the walk then follows `part.next` and reads headers at attacker-chosen sectors — bounded reads, but the table is then trusted by `hdl.c`); conversely `<` (not `<=`) rejects a legitimate final partition ending exactly at `total_sectors`. READ arithmetic; consequence INFERRED.
- **Fix:** `length <= total_sectors - start` after checking `start < total_sectors` (one expression, no addition to wrap).
- **Benefit:** The one bounds gate in the APA walk actually gates. **Effort:** trivial. **Risk:** low. **Confidence:** READ.

- **Checked-and-clean:** `main.c:23` RPC buffer is 4 KiB (`int[1024]`), ample for both packets + `GameInfo`; the shared-buffer layout (name at offset 0, reply `GameInfo` at +4) matches the EE client in `src/hdl_rpc.c:52-65` — intentional, not an overlap bug; `apa.c:177-178` the linked-list walk has the admittedly "quick-and-dirty" 10,000-partition cap (TODO comment :175-176) — a cycle costs allocations until `apa_part_add` fails with -2, noted, not filed; `hdd.c:195-214` probe string match is fully bounded; `main.c:42-49` `_start` returns 0 on success (not `MODULE_RESIDENT_END`) with an unreachable `return MODULE_RESIDENT_END` at :49 — legacy HDLoader convention, the module demonstrably stays resident via its RPC thread, noted as dead line only.

---

## 3. `iop/ps2ips_rpc` — ps2ip socket RPC server

- **Provenance:** `VENDORED.md` — ps2sdk `iop/tcpip/tcpips` @ `329e2bb4…`, AFL-2.0; ten enumerated local changes (DNS reply copy, StartThread cleanup, UDP overlap ordering, 64 B headroom, getsockopt/setsockopt init, zero-payload metadata clearing, wire-header types, DNS field rename, quoted include). All ten spot-verified present in the text (e.g. setsockopt length rejection at `ps2ips.c:526-529`, DNS checks at :544-551, `_start` cleanup at :688-691). READ.
- **Built:** YES — target `ps2ips_rpc` (`ps2.yaml:203-210`, `PS2IP_DNS` defined), embedded as `ps2ips_rpc:ps2ips` (`ps2.yaml:656`).
- **Coverage ledger:** `ps2ips.c` 1-694 (all), `ps2ip_rpc.h` 1-236 (all), `VENDORED.md`. Still unread: `imports.lst`, `irx_imports.h`, local `ps2.yaml` (glue/inventory).

### T5-F8 / `do_send`/`do_sendto` trust the EE-supplied `malign` count: negative buffer offset and length underflow / Category 6
- **Locations:** `iop/ps2ips_rpc/ps2ips.c:332-348` (`do_send`) and `:365-381` (`do_sendto`); field is `s32 malign` with a 64-byte inline `malign_buff[64]` (`ps2ip_rpc.h:99-101`).
- **Problem:** Nothing validates `malign`. With `malign > 64`: `s_offset = 64 - malign` goes negative and `memcpy(lwip_buffer + s_offset, malign_buff, malign)` writes **before** the static `lwip_buffer` and over-reads the 64-byte source; `sceSifGetOtherData(..., sendlen - malign, ...)` underflows when `malign > sendlen`. With `malign < 0` the same expressions invert. The legitimate EE client only ever sends a 0-63 alignment remainder (INFERRED from the design comment at `ps2ips.c:20-22`), so this is a malformed/buggy-client hole, not a network one — but the sibling `do_setsockopt` in the same file got exactly this validation as local change #6, which makes the omission here a proven-inconsistent posture. READ (arithmetic), INFERRED (client behaviour).
- **Fix:** Reject `malign < 0 || malign > 64 || malign > sendlen` with `ptr[0] = -1` at the top of both functions, mirroring :526-529.
- **Benefit:** Closes an IOP static-buffer under-write from one bad RPC packet. **Effort:** trivial. **Risk:** low (no conforming client sends such values). **Confidence:** READ.

### T5-F9 / `do_recv`/`do_recvfrom` never reject a negative EE-supplied `length` / Category 6
- **Locations:** `iop/ps2ips_rpc/ps2ips.c:136-153` and `:236-253` (`s_recv_pkt.length` is `s32`, `ps2ip_rpc.h:107`; `recvlen = MIN(BUFF_SIZE, length)` keeps a negative value; `srest = length` when `length <= 64`; `s_offset = 64 - srest` then exceeds the 64-byte headroom the buffer reserves, `lwip_buffer` being `BUFF_SIZE + 64` at :51).
- **Problem:** A negative length flows into `recv/recvfrom` as its length argument and shifts the receive offset past the reserved headroom; any positive return then computes `sbuffer`/`ebuffer` copies from offsets the 1088-byte buffer was not sized for. READ (data flow); the exact lwIP behaviour for a negative length is INFERRED (not read in this section).
- **Fix:** Early-return the zero-payload metadata path (local change #7 already built it: `memset(&rests,0,…)` + `send_rest`) with `ret = -1` when `length < 0`.
- **Benefit:** Same class as T5-F8, closed with the pattern the file already has. **Effort:** trivial. **Risk:** low. **Confidence:** READ / INFERRED (split as above).

- **Checked-and-clean:** `do_accept`/`do_getsockname`/`do_getpeername` initialise `addrlen`/`addr` before lwIP (change #6 verified); `do_getsockopt` (:492-509) caps its local copy at its 128-byte buffer (it copies a fixed 128 bytes out, including past `optlen` — stack residue to the EE client, noted, not filed: the buffer is a zero-initialised-by-compiler? no — it is uninitialised stack; weight is a same-console info leak to its own client, below filing threshold); `do_dns_getserver` (:565-573) dereferences `dns_getserver()`'s return unchecked — lwIP's contract for an out-of-range index was not read in this section, so this is recorded as a **question for the coordinator**, not a finding; `do_connect` reading the packet from `_rpc_buffer` while others use the parameter (:100) is consistent because the RPC layer always passes that buffer — noted, not filed.

---

## 4. `iop/ps2host` — PS2Link `host:` filesystem

- **Provenance:** PS2Link (Tord Lindstrom / adresd, 2003-2004 file headers). No VENDORED file. READ.
- **Built:** YES — target `ps2host` (`ps2.yaml:232-240`), embedded (`ps2.yaml:657`); comment in `ps2.yaml` says embedded but never loaded at boot.
- **Coverage ledger:** `net_fio.c` 481-773 (this round; 1-480 in Round 2 / earlier), `net_fsys.c` 1-439 (all; Round 2 had read 1-80 + greps), `ps2host.c` 1-35 (all), `hostlink.h` (279), `net_fio.h` (36). Still unread: `imports.lst`, `irx_imports.h` (glue).
- **Findings:** none filed in the remainder.
- **Checked-and-clean:** `net_fio.c:481-773` — every request builder `strncpy`s into `PKO_MAX_PATH` and forces `name[PKO_MAX_PATH - 1] = 0` (mkdir/rmdir/opendir/remove replies all checked); `pko_read_dir` copies the reply name with a bounded `memcpy` + forced NUL and translates every stat field with `ntohl`; `pko_file_serv` (the accept loop) retries socket creation 50×, disconnects the previous client on reconnect, and exits via `ExitDeleteThread`. One nit, not filed: the reconnect/disconnect tests use `pko_fileio_sock > 0`, so a legitimate socket descriptor 0 would never be disconnected on reconnect — a one-descriptor leak in a legacy edge, INFERRED (descriptor allocation order not read). `net_fsys.c:127-409` — all ops serialised on `fsys_sema`, the IOMAN `fioRemove`→`fioMkdir` quirk is carried by `remove_flag`/`remove_result` consistently across every op, rename-ioctl state (`lastopen_fd`/`renamed_fd`) is reset on open/dopen/close/dclose; `fsysInit` (:91-99) leaves a created-but-unstarted thread behind if `StartThread` fails — noted, not filed (no second init path exists to compound it).

---

## 5. `iop/ds34usb` + `iop/ds34bt` — DualShock 3/4 drivers (sibling drift audit)

- **Provenance:** No ORIGIN/VENDORED file in either directory; SMS-era homebrew driver family (both carry `smsutils.S`, `mips_mem*` helpers). READ (absence).
- **Built:** NOT in the default `ps2.yaml`. Built only in the DS34 variant: `scripts/configure_ds34.py` derives `.ps2-ds34.yaml` adding both IOP modules + EE libs + `DS34` define (READ: `docs/BUILDING.md:95-99`). Default ELF instead tries external `DS34USB.IRX`/`DS34BT.IRX` (`src/init.c:1719-1721`).
- **Coverage ledger:** `ds34usb/iop/ds34usb.c` 1-806 (all), `ds34usb/ee/libds34usb.c` 1-145 (all), `ds34usb/iop/ds34usb.h` (188); `ds34bt/iop/ds34bt.c` 1-1719 (all), `ds34bt/ee/libds34bt.c` 1-173 (all), `ds34bt/iop/ds34bt.h` (376). Still unread: both `smsutils.S`, both `imports.lst`/`irx_imports.h` (glue/inventory), EE headers `libds34usb.h`/`libds34bt.h` (declarations only, skimmed via use).

### T5-F10 / ds34bt DS4 LED/rumble report: buffer zeroed with the DS3 length, then sent at the DS4 length — 29 uninitialised stack bytes transmitted / Category 6
- **Locations:** `iop/ds34bt/iop/ds34bt.c:1208` (`u8 led_buf[PS4_11_REPORT_LEN + 2]` = 79 B), `:1243` (`mips_memset(led_buf, 0, PS3_01_REPORT_LEN + 2)` = 50 B, in the `type == DS4` branch), `:1263` (`size += PS4_11_REPORT_LEN` → `size` = 79), `:1273` (`HID_command(..., led_buf, size, pad)` → `mips_memcpy(&l2cap_cmd_buf[8], data, length)` at :1179). Lengths: `PS3_01_REPORT_LEN = 0x30`, `PS4_11_REPORT_LEN = 0x4D` (`iop/ds34bt/iop/ds34bt.h:247,251`).
- **Problem:** This is the exact bug class flagged for checking: the DS4 branch inherited the DS3 constant. Bytes 50-78 of the report — everything past the fields written at :1245-1260 (which end at index 13) — are uninitialised stack, sent to the controller in every DS4-over-Bluetooth LED/rumble update. The DS4 BT report's trailing bytes include its CRC field region, so a conforming controller may reject the report outright (INFERRED — CRC is computed by neither this function nor `HID_command`, READ); at minimum the driver transmits nondeterministic stack content. The USB sibling does not have the bug: `ds34usb.c:414` zeroes the whole `usb_buf` (`sizeof(usb_buf)`) before either branch.
- **Fix:** Change :1243 to `PS4_11_REPORT_LEN + 2` (one constant).
- **Benefit:** Deterministic, spec-shaped DS4 BT output reports; removes a stack-disclosure-to-peripheral. **Effort:** one token. **Risk:** low — zeroing more of a report whose unwritten fields are defined as zero/reserved. **Confidence:** READ.

### T5-F11 / `ds34bt_reset` waits forever for pads to leave RUNNING state / Category 3
- **Locations:** `iop/ds34bt/iop/ds34bt.c` reset function in the final third of the file (`while (1)` + `DelayThread(500)` polling `DS34BT_STATE_RUNNING`, no counter/timeout; followed by a fixed `DelayThread(1000000)`).
- **Problem:** If a pad never clears RUNNING (stuck HCI state, fake/clone pad that ignores disconnect), the RPC thread that services every DS34BT call hangs permanently; the loader's reset call (`src/init.c:2157`, cross-reference) never returns. The USB sibling's reset is a bounded loop over pads calling `usb_release` — no wait at all. READ.
- **Fix:** Add a retry bound (e.g. 2,000 polls ≈ the existing 1 s tail delay's order) and proceed regardless.
- **Benefit:** Reset degrades instead of deadlocking the DS34 RPC server. **Effort:** small. **Risk:** low. **Confidence:** READ.

### Sibling-drift verdict (ds34usb vs ds34bt)
| Area | Verdict | Evidence |
|---|---|---|
| LED/rumble report build | **Bug-for-bug family, one real divergence = T5-F10.** Both build DS3 from the same `output_01_report` table + same field offsets; USB zeroes the full buffer (`ds34usb.c:414`), BT zeroes per-branch and got the DS4 length wrong (`ds34bt.c:1243`). | READ |
| DS3 report parse | **Intentional variant.** BT adds pressure-emulation (`press_emu`, short-report `bytes == 21` trigger) that USB lacks; BT parses at `data[11]` (L2CAP/HID framing), USB at `data[2]`. Same field-for-field mapping to `data[0..17]` thereafter. | READ |
| DS4 report parse | **Drift, BT ahead.** BT guards touchpad-field access with `bytes > 63`; USB's `readReport` has no length parameter and dereferences the full `ds4report` unconditionally — mitigated in USB because the source is a fixed 64-byte transfer into a 96-byte static `usb_buf` (`ds34usb.h:14`, `ds34usb.c:62`), so it reads zeroes, not other memory. Not filed; if USB ever moves to variable-length transfers it becomes T5-F10's twin. | READ |
| RPC layer | **Bug-for-bug identical**, including the shared quirk that `GET_DATA` writes the 18-byte pad data over the request buffer starting at byte 0 (port byte included in what the EE lib copies out, `libds34usb.c:134` / `libds34bt.c:130`) and identical `port >= MAX_PADS` guards fed by a `u8` port (no negative-port exposure). BT adds commands 2/9/10 (charging, version, features) and a different bdaddr layout — intentional variant. | READ |
| Reset | **Drift = T5-F11** (BT polls unbounded; USB releases immediately). | READ |
| Report-length trust in parsers | Both parse structs out of fixed static buffers without a minimum-`bytes` check (BT `hid_readReport` reads `data[8]/data[9]` and full DS3/DS4 structs regardless of `bytes`; HCI event handler indexes `hci_buf` likewise). Exposure is stale-buffer data, not overflow — buffers are `MAX_BUFFER_SIZE(+32)` statics. Noted jointly, not filed. | READ |

- **Checked-and-clean (both):** every public entry (`set_rumble`, `set_led`, `get_data`, `get_status`, `get_bdaddr`, `set_bdaddr`) checks `port >= MAX_PADS` (MAX_PADS = 2, `ds34usb.c:20` / `ds34bt.c:346`) before indexing `ds34pad[]`; LED pattern tables are indexed only by `pad < MAX_PADS`; the targeted memset/memcpy+send audit found **no** other length pairing mismatch — USB DS3 sends `sizeof(output_01_report)` after copying exactly that, USB DS4 sends a fixed 32, BT DS3 sends `2 + sizeof(output_01_report)`, BT `hid_initDS34` sizes match their report lengths.

---

## 6. `iop/xparam` — Deckard XPARAM database

- **Provenance:** ps2sdk `iop/deckard/xparam`, homebrew DB (`ps2.yaml:385` comment); `database_merged.c:3-5` says it merges the ROMVER 2.50 database with SYSTEM.CNF `PARAM2` entries. No VENDORED file. READ.
- **Built:** YES — target `xparam` (`ps2.yaml:386-392`), embedded (`ps2.yaml:675`).
- **Coverage ledger:** `src/xparam.c` 1-63 (all), `include/xparam.h` 1-37 (all), `src/database_merged.c` 1-887 — **classified as data**: 292 entry rows (counted, READ) of `{name[12], param, value}` plus comments; structure, the `#ifndef SKIP_GAMES_PASSING_XPARAM_FROM_SYSTEM_CNF` tail block (:865-886) and all lookup-relevant code read; individual game rows not audited for factual correctness (that is game-compatibility data, not code). Still unread: `src/imports.lst`, `src/irx_imports.h` (glue).

### T5-F12 / `GET_XPARAM_DB_SIZE()` always evaluates to 1 — the 292-entry database is searched over exactly one entry / Category 3
- **Locations:** `iop/xparam/include/xparam.h:36` (`#define GET_XPARAM_DB_SIZE() (sizeof(*XPARAMS) / sizeof(XPARAMS[0]))` — `*XPARAMS` is one element, so numerator == denominator); sole user `iop/xparam/src/xparam.c:55` (`for (i = 0; i < GET_XPARAM_DB_SIZE(); i++)` in `CheckGameID`).
- **Problem:** The lookup can only ever match `XPARAMS[0]` ("PAPX_905.17"). Every other game in `database_merged.c` (292 rows, including multi-row games whose consecutive entries the found-flag break logic at `xparam.c:61` was written for) silently gets no XPARAM — on Deckard (PSX-DESR) hardware, the compatibility parameter the module exists to set is simply never set. The intended expression is `sizeof(XPARAMS) / sizeof(XPARAMS[0])`. READ — pure preprocessor arithmetic, no hardware needed to prove.
- **Fix:** Drop the `*` in `xparam.h:36` (one character).
- **Benefit:** Restores the entire database's function; currently ~291/292 of the data file is dead weight in the ELF. **Effort:** one character + a host-side size assertion if wanted. **Risk:** low — behaviour changes only for game IDs that were supposed to match all along. **Confidence:** READ.

### T5-F13 / `xparam _start` argument handling: `argc == 3` does nothing, and the pair loop drops a trailing pair / Category 3
- **Locations:** `iop/xparam/src/xparam.c:30-45` (branches are `argc < 3` → `CheckGameID`, `3 < argc` → pair loop; `argc == 3` falls through both; loop advances `i1` by 2 but tests `i2 = i1 + 3 < argc`, so for odd `argc` ≥ 5 the final complete pair is never applied — e.g. `argc = 5` applies only argv[2..3]).
- **Problem:** A caller passing exactly one explicit param/value pair (`argc == 3`: name + pair) gets the dummy value from `SetDummyXparamValue` and nothing else; a caller passing two pairs (`argc = 5` counting the module name the same way this function counts) gets only the first. READ from the control flow; how the in-tree loader actually invokes xparam was not in this section's scope, so live impact is INFERRED.
- **Fix:** Change the second branch to `argc >= 3` and the loop condition to `i1 + 1 < argc` (pair = two argv slots).
- **Benefit:** The explicit-parameter path does what its shape promises. **Effort:** trivial. **Risk:** low. **Confidence:** READ (code), INFERRED (impact).

- **Checked-and-clean:** Non-Deckard IOP (`IOP_CPU_TYPE != IOP_TYPE_POWERPC`) correctly no-ops and still returns `MODULE_NO_RESIDENT_END` (:28,48); `CheckGameID`'s consecutive-entry break (:61) is correct logic for the grouped-by-game table layout — it is T5-F12, not this logic, that disables it; database rows are uniformly 12-char-max IDs fitting `name[12]` (spot-checked across the file; the longest IDs are 11 chars + NUL).

---

## 7. `iop/dev9_poweroff` (22 lines)

- **Provenance:** Local, self-documenting (`main.c:12-17` comment explains the APA slot-0 / ATAD slot-15 poweroff-callback stall it suppresses).
- **Built:** YES — target `dev9_poweroff` (`ps2.yaml:65-69`), embedded (`ps2.yaml:664`).
- **Coverage:** `main.c` 1-22 (all). Still unread: `imports.lst`, `irx_imports.h` (glue).
- **Findings:** none. **Checked-and-clean:** registers NULL handlers for exactly the two slots its comment names, returns `MODULE_NO_RESIDENT_END` (one-shot, nothing resident), ignores argc/argv explicitly.

## 8. `iop/AllowDVDV` (82 lines)

- **Provenance:** Legacy homebrew (static SecrMan boot-file tables; no provenance file). READ (absence).
- **Built:** YES — target `allowdvdv` (`ps2.yaml:73-79`), embedded (`ps2.yaml:679`).
- **Coverage:** `AllowDVDV.c` 1-82 (all). Still unread: `imports.lst`, `irx_imports.h` (glue).
- **Findings:** none filed. **Checked-and-clean:** all `memcpy` offsets/lengths into `buf[137]` verified by hand (32 @0, 11 @48, 8 @32, 49 @88 → ends exactly at 137, 16 @72); PS2-vs-PSX branch keyed on `rom0:PSXVER` open; source key tables zeroed after use (:67-71) and `buf` zeroed after `SecrDiskBootFile` (:75). Nit, not filed: `open(...) <= 0` treats descriptor 0 as failure — descriptor 0 is a plausible first IOP fd (INFERRED), worst case is selecting the PS2 table on a PSX, in a module that runs once at load.

---

## 9. `iop/smb2man/usmb2` — remainder of `usmb2.c` + helper inventory

- **Provenance:** `usmb2/VENDORED.txt` — sahlberg/usmb2 @ `7171d08b…` (MIT), with `riptopl.patch` applied (documented change list) + one Launchstation change in `hmac-md5.c` (Latin-1 upper-casing for NTOWFv2, per `iop/smb2man/README.md`). Built: YES — target `smb2man` (`ps2.yaml:249-261`) compiles `usmb2.c` via `smb2man.c` plus the five helpers below; embedded (`ps2.yaml:659`). Git log for all five helpers: single import commit `7082163` (#314) — no later local edits in history. READ.
- **Coverage ledger:** `usmb2.c` 1-60 and 620-890 (this round; 60-620 + 890-1085 in Round 2 — full file now covered across rounds). Helpers = **inventory only**, per assignment: `ntlm.c` (263, NTLMv2, locally patched per VENDORED.txt — bounds hardening of CHALLENGE parsing is documented there and belongs to Round 2's read of the patch), `md4c.c` (240, RSA RFC 1320 MD4, pristine), `md5.c` (190, RSA MD5, pristine), `unicode.c` (204, UTF-8↔UTF-16, one documented local fix: unsigned-char `l1()`), `hmac-md5.c` (99, RFC 2104 HMAC-MD5 + the one Launchstation Latin-1 change above).

### T5-F14 / `usmb2_readdir` walks server-supplied directory-entry offsets with no bound against the directory buffer / Category 6
- **Locations:** `iop/smb2man/usmb2/usmb2.c` `usmb2_readdir` in the 620-890 remainder (QUERYDIR block): reply length `u32 = le32toh(*(uint32_t *)&usmb2->buf[4])` copied unbounded into `dh[16 + 4]`; chain walk `curr_de`/`next_de` read from `dh[16 + curr_de]` and advanced without any comparison to the buffer size; filename length at `dh[16 + curr_de + 0x3c]` trusted (`>> 1` chars converted in place, then `ptr[i] = 0`). Buffer: `dh` is allocated `16 + MAX_DIR_SIZE` = 272 bytes (`usmb2.c:69` `MAX_DIR_SIZE 256`; allocation in `usmb2_open`, same range).
- **Problem:** A malicious or broken SMB2 server controls the QUERYDIR reply length, the `NextEntryOffset` chain and each `FileNameLength`. None is checked against 272 bytes (or against `usmb2->reply_len`, which the RiptOPL patch *does* check for READ replies at the `usmb2_prw` tail of this same range — the pattern exists in-file and was not applied here). The result is heap over-copy on the reply store and out-of-bounds read/write (`ptr[i] = 0`) during name conversion. READ (absent checks in the function as written); the claim that `usmb2_build_request` does not pre-cap the reply to `MAX_DIR_SIZE` is INFERRED from the READ-reply hardening being necessary at all.
- **Fix:** Clamp the reply copy to `MAX_DIR_SIZE - 4` (the `OutputBufferLength` actually requested), and break the chain walk when `curr_de`/`next_de` or the filename field would pass the copied length — mirroring the READ-reply checks.
- **Benefit:** A hostile server stops owning IOP heap via directory listing, the most server-exposed operation in the driver. **Effort:** small. **Risk:** low (conforming servers stay within the requested output length). **Confidence:** READ / INFERRED (split as above).

- **Checked-and-clean in the remainder:** `usmb2_prw`'s READ tail (end of the 620-890 range) carries the RiptOPL DataLength-vs-requested and DataOffset-vs-frame checks exactly as VENDORED.txt describes; `usmb2_create`'s file-id copy is `calloc(1, size)` + 16-byte copy, bounded; TREE_CONNECT/CREATE name writes (`usmb2_put_name`, tree-connect UCS2 loop) write into the 1024-byte `usmb2->buf` with the documented 440-byte name ceiling — no in-function length assert exists, but VENDORED.txt states `usmb2_init_context` refuses over-long credentials and smb2man's front end owns path length; recorded as a dependency, not a finding (caller side was Round 2 scope).

---

## 10. Binary inventory — `iop/__precompiled/*.irx`, `iop/__v10/*.irx`

Inventory only; no disassembly, no findings. md5 + SHA-256 + size, READ from the filesystem at the pin.

| File | Bytes | md5 | SHA-256 | Embedded? |
|---|---|---|---|---|
| `iop/__precompiled/udpfs_ioman.irx` | 11,633 | `8fb9e379682975c3fa401dd81dab7ebb` | `85faad5631fa7b2e57548ea35fe752c368163ffc4074eb6c3e9742187501c242` | YES — `src/embed_blobs.S:75` |
| `iop/__precompiled/udpfs_ministack.irx` | 5,025 | `f6e6984f6ee6b556b6da2cf1d050fb68` | `854060627190264dd5cf647cf3468535a7ea3aa4f3544bf30f654bb25d8b8280` | YES — `src/embed_blobs.S:74` |
| `iop/__precompiled/udpfs_smap.irx` | 8,081 | `363132f37f177ef1201230c7f7107dbc` | `4b81d9bf0c176d3291258eb97f6188a2bb935a69ae4cba13546b51d603ee1a09` | **NO** — SHA-256 matches the "old upstream precompiled SMAP… retain only as a historical reference; neither build route should embed it" binary named in `iop/udpfs_smap/ORIGIN.md`; absent from `embed_blobs.S` (the source-built `udpfs_smap` target is embedded instead). Its retention is documented, so no LESS finding is filed; it remains 8 KB of repo weight whose only consumer is `scripts/check_udpfs_smap.py`'s negative control. |
| `iop/__v10/ps2dev9.irx` | 13,193 | `45e328626de1dc7904df8bcade55f799` | `962bedf3ab211424409026e16c21437ce9b41edad01d7bc505b5b9037f0b469e` | YES — `src/embed_blobs.S:78` (v1.0-PS2IP variant, `ps2.yaml:654`) |
| `iop/__v10/ps2ip.irx` | 118,513 | `18388bb243e4e3939bd8ae00e2c15b36` | `9489a007711bf2f93f9ec19b261c545a40064422890ea18f590b8aa391a04926` | YES — `src/embed_blobs.S:79` |

---

## Section summary

- **Findings:** T5-F1…T5-F14 (14). Headlines: T5-F12 (xparam database disabled by a one-character macro bug), T5-F10 (ds34bt DS4 report sends 29 uninitialised bytes — the flagged memset-length class, present here), T5-F3 (hdl_info writes uninitialised data to disk on read failure).
- **Clean / no-finding modules:** ps2host remainder, dev9_poweroff, AllowDVDV, usmb2 crypto/NTLM helpers (inventory).
- **Still unread (whole section):** only build glue (`imports.lst`/`exports.tab`/`irx_imports.h` per module), `ds34*` `smsutils.S`, and the xparam database's per-game factual correctness (data, out of code-audit scope).
