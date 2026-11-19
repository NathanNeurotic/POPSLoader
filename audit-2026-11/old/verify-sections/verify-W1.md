# Verification W1 — RiptOPL Category 6, adversarial re-read

- **Clone:** `~/workspace/audit-clones-2026-11-13/RiptOPL`
- **Pin verified at start:** `git rev-parse HEAD` = `2e347d5ac885cd0ff73e9ad4143781946396f492`; clone left git-clean (read-only held).
- **Method:** every cited `path:line` re-read in the clone; mechanism re-derived including bounds, caller context, and writer/guard context elsewhere. Severity/effort claims ignored.
- **Counts:** VERIFIED 8 · VERIFIED-DRIFT 6 · WEAKENED 1 · REFUTED 1 · New candidates 0

| ID | Verdict | One-line evidence (path:line) |
|---|---|---|
| RIPTOPL-016 | WEAKENED | Config/GUI writers do terminate the sources (`src/core/config.cpp:401-406`, `src/ui/diaitems.cpp:121-123`); overflow survives only via the unterminating `memcpy` at `src/sources/ethsupport.cpp:1307` feeding `strcpy` at `src/sources/ethsupport.cpp:1444` |
| RIPTOPL-037 | VERIFIED-DRIFT | Overflow loop is at `modules/network/nbns/nbns.c:108` (not 110-122), call at `:191`, gate at `:179`, stale-address `memcpy` at `:198` exact |
| RIPTOPL-066 | VERIFIED | `modules/ds34bt/iop/ds34bt.c:1208,1243,1263` and `modules/pademu/ds34bt.c:1146,1179,1198` exact: 50-byte memset, 79-byte send |
| RIPTOPL-067 | VERIFIED-DRIFT | Unclamped `memcpy(optval, …, optlen)` at `modules/network/ps2ips/ps2ips.c:592` exact; destination `optval[128]` is at `:584`, not `:587` |
| RIPTOPL-145 | VERIFIED | `modules/network/smbman-ra/smb.c:257-261` passes server 24-bit length unclamped to `RecvData` into 4,224-byte `SMB_buf` (`smb.c:37-83`; `smb.h:894-895`) |
| RIPTOPL-146 | VERIFIED | `modules/network/smbman-ra/smb.c:1077-1089`: `padding` from u16 `DataOffset` (`smb.h:764`) and `DataLength` (`smb.h:763-765`) both reach `RecvData` with no comparison to `nbytes` |
| X-31 | VERIFIED-DRIFT | Unchecked copy at `modules/network/udpfs_shared/src/udprdma.c:185-199` exact; the 8-byte registered buffer is set at `udpfs_core.c:94`, not `:100-103` |
| RIPTOPL-281 | VERIFIED | `ee_core/src/gsm_engine.S:1063` `andi $k1,$k1,0x3F` into 32-entry `BD_t2` at `:119-127`; comment at `:1062` itself says range `0x00-0x1F` |
| RIPTOPL-282 | VERIFIED | `modules/iopcore/cdvdman/smsutils.S:127-131` (`1: jr $ra` / `mips_memset:` / `move $v0,$a0`), `.set noreorder` at `:19`; same layout `modules/network/SMSUTILS/SMSUTILS.S:137-141` |
| RIPTOPL-283 | VERIFIED | `ee_core/src/asm.S:22` `.set noreorder`; clobbers at `:259,261-262,268`, bypass tail-call at `:296-300`; returning type at `ee_core/src/syshook.c:41` |
| RIPTOPL-284 | VERIFIED | `ee_core/src/dve_reg.S:185-186` `jr $ra` / `move $v0,$zero`; dead `bnez $v0` loop at `:88-92` |
| RIPTOPL-344 | VERIFIED-DRIFT | Copy loop `src/platform/ps2cnf.cpp:54-65` and caller buffer `src/sources/supportbase.cpp:116` exact; the `CNFGetKey` call / success return are at `ps2cnf.cpp:115,119`, not `:123` |
| RIPTOPL-504 | VERIFIED-DRIFT | `tools/assets.py:150-158` iterates `manifest["files"]` only, no `namelist()` comparison anywhere in the file (cited as 166-173); test assert at `.github/scripts/test_korium_builtin_assets.py:38` exact |
| RIPTOPL-505 | VERIFIED-DRIFT | No cleanup of `theme_dir` anywhere in `tools/assets.py` (extraction `:147-158`, existence lookup `:175-179`); cited ranges 146-148 / 162-173 / 195-200 are all stale |
| RIPTOPL-513 | REFUTED | `modules/iopcore/cdvdman/hdpro_atad.c:678` takes `u32 lba` (shared prototype `atad.h:55`); its LCYL/HCYL at `:696-697` are correct for a 32-bit LBA and copying `atad.c:681-682` in is an identity transformation |
| RIPTOPL-516 | VERIFIED | `modules/network/SMSTCPIP/tcp.c:1074-1079` `iss = 6510; iss += tcp_ticks` (ticks ++ every 500 ms, `:554,568`); `modules/network/SMSTCPIP/ip.c:343,366-367` `static u16_t ip_id`, `++ip_id` per packet |

---

## Full reasoning — every non-VERIFIED verdict

### RIPTOPL-016 — WEAKENED

**As filed:** config-file user/share/password strings are `strcpy`'d into fixed cdvdman settings fields at `ethsupport.cpp:1192-1194, 1444-1446` (plus `smb_prefix` at `:1435`); the two non-Neutrino sites do not length-check and "rely on every writer of `gPCUserName`/`gPCPassword`/`gPCShareName` having clamped them, which a hand-edited or migrated config file does not guarantee."

**What the code actually shows:**

- Sources and destinations are the *same size*. Sources: `char gPCShareName[32]`, `gPCUserName[32]`, `gPCPassword[32]` (`include/opl.h:129-131`), `gETHPrefix[32]` (`include/opl.h:500`). Destinations: `smb_share[32]`, `smb_prefix[32]`, `smb_user[32]`, `smb_password[32]` (`modules/iopcore/common/cdvd_config.h:66-69`). A NUL-terminated source therefore always fits its destination exactly; `strcpy` alone is not an overflow here.
- The filed trigger is defeated. The config-file writer *does* clamp and terminate: `ConfigSet::getStrCopy` (`src/core/config.cpp:401-406`) does `strncpy(value, valref, length)` and forces `value[length-1] = '\0'`. That is the loader for all three SMB strings (`src/app/settingsio.cpp:1945-1947`, called with `sizeof(...)`) and, via the `strSetting` table (`src/core/settings.cpp:43-45,102,218`), for `gETHPrefix`. The GUI writer does the same: `diaGetString` (`src/ui/diaitems.cpp:113-123`) `strncpy`s and forces `value[length-1] = '\0'` (call sites `src/ui/guisettings.cpp:1010-1012, 1689`). A hand-edited or migrated config with an over-long value is truncated to 31 chars + NUL by these loaders — it cannot overflow the cited `strcpy`s.
- The Neutrino site (`ethsupport.cpp:1192-1194`) is, as the finding itself notes, length-checked first (`:1187-1191`, against `NEUTRINO_SMB_USER_MAX/PASS_MAX` 31 and `SHARE_MAX` 63, `include/system.h:61-63`; destinations 32/32/64 at `include/system.h:70-72`).

**The narrower condition under which the mechanism still holds:** one writer does *not* terminate. `ethsupport.cpp:1307`:

```cpp
memcpy(gPCShareName, game->name, sizeof(gPCShareName));
```

`game->name` is `char name[ISO_GAME_NAME_MAX + 1]` = 161 bytes (`include/supportbase.h:24`). Selecting a share whose name is ≥32 bytes copies 32 non-NUL bytes and leaves `gPCShareName` unterminated. A later launch then executes `strcpy(settings->smb_share, gPCShareName)` at `ethsupport.cpp:1444`, which reads past the 32-byte global and writes past `smb_share[32]`. (The same unterminated value is also `strcpy`'d earlier at `ethsupport.cpp:160`, `strcpy(openshare.ShareName, gPCShareName)` — same root cause, not a separate finding.)

So: the defect is real **only for `smb_share`, only after the share-selection `memcpy` at :1307 with a ≥32-byte name**. For `smb_user`, `smb_password`, and `smb_prefix` no unterminating writer exists in the tree, and the filed config-file trigger does not work for any of the seven copies.

### RIPTOPL-037 — VERIFIED-DRIFT

Mechanism re-derived and holds:

- `decode_name` is at `modules/network/nbns/nbns.c:101-115`; the loop is at `:108`: `for (…; i < name[0]; i += 2, pOut++, p += 2)`. `name[0]` is a packet-supplied byte; as a signed `char` its maximum positive value 127 gives 64 iterations, i.e. 64 bytes written into the caller's `char decoded_name[17]` (`nbns.c:172`) plus the terminating `*pOut = '\0'` at `:112` — ≈47 bytes past the buffer, exactly as filed. (If `char` were unsigned on this target the bound would be larger, not smaller.)
- The decode at `:191` runs *before* any name/transaction lookup (`lookupName` is at `:194`), gated only by opcode QUERY, R=1, RCODE 0, `ANCount == 1` (`:185-190`) and the sole length gate `length >= sizeof(struct NbHeader)` (12 bytes) at `:179`. So the overflow is triggerable by any LAN host without knowing the pending name or transaction ID, as filed. `decoded_name[result] = '\0'` at `:192` is a further out-of-bounds write on the same path.
- The second claim is exact: `memcpy(record->address, &frame[…], 4)` at `:198` reads `frame[58..61]` (12 + 34 + 4 + 4 + 2 + 2) with no `length >= 62` check; `frame` is a static 576-byte buffer (`:170`), so a short datagram installs stale bytes as the address. That sub-path additionally requires the `lookupName` match at `:194`.

**Drift:** the finding cites `decode_name` at `:110-122` — the function is at `:101-115` (loop `:108`). It cites the call site/gate as `:177-189` — the gate is at `:179` (inside the range) but the call is at `:191`. The `:198` citation is exact.

### RIPTOPL-067 — VERIFIED-DRIFT

Mechanism holds: `do_setsockopt` (`modules/network/ps2ips/ps2ips.c:577-596`) takes `optlen` unchecked from the RPC packet at `:591` and executes `memcpy(optval, ((setsockopt_pkt*)rpcBuffer)->buffer, optlen)` at `:592` into a 128-byte stack buffer, with the RPC `size` argument explicitly discarded (`(void)size;` at `:586`). No clamp exists in the function or its dispatcher (`rpcHandlerFunction`, `:637ff`). `optlen > 128` overwrites the RPC thread's stack; a negative `optlen` is equally unguarded (converted to a huge `size_t` by `memcpy`).

**Drift:** the destination `unsigned char optval[128]` is at `ps2ips.c:584`, not `:587` as filed (`:587` is blank; `:586` is the `(void)size;` line). The copy (`:592`) and `optlen` source (`:591`) citations are exact.

### X-31 — VERIFIED-DRIFT

Mechanism holds:

- `modules/network/udpfs_shared/src/udprdma.c:185` computes `hdr_size = data_hdr.hdr_word_count * 4`; `hdr_word_count` is a 4-bit wire field (`modules/network/udpfs_ioman/src/udprdma_packet.h:89`), so `hdr_size` ≤ 60.
- At `udprdma.c:192-193`, when a header buffer is registered and not yet filled, `smap_fifo_read(0x30, s->rx_hdr_buffer, hdr_size)` runs with no comparison against `s->rx_hdr_size` (which is stored at `:736` and, as the round-9 modules pass noted, never read).
- The principal registered buffer is 8 bytes: `_request` registers a stack `udpfs_msg_result_reply_t result` (1 + 3 + 4 = 8 bytes, `udpfs_packet.h`, "Generic result reply (8 bytes)") via `udprdma_set_rx_app_header(socket, &result, sizeof(result))`. A DATA packet with `hdr_word_count >= 3` therefore writes ≥12 bytes into an 8-byte stack object. Other `_request` replies (e.g. the 36-byte open reply) overflow at `hdr_word_count = 15` as well; only the 312-byte `g_rx_buf` users are safe by size.
- The no-buffer drain path is also as filed: `uint8_t dummy[UDPRDMA_MAX_APP_HDR]` at `udprdma.c:196-197`, where `UDPRDMA_MAX_APP_HDR` is 32 (`udprdma_packet.h:103`) — still < 60.

**Drift:** the finding cites the registered buffer at `udpfs_core.c:100-103`; those lines are inside `_request` *after* the send. The registration is at `modules/network/udpfs_shared/src/udpfs_core.c:94`, the 8-byte write-completion buffer definition is at `:23`, and the result-reply struct definition is in `modules/network/udpfs_ioman/src/udpfs_packet.h` (generic result reply). The `udprdma.c:185-199` citations are exact.

### RIPTOPL-344 — VERIFIED-DRIFT

Mechanism holds:

- `CNFGetKey` (`src/platform/ps2cnf.cpp:42-68`): the copy loop at `:54` runs `i < CNF_PATH_LEN_MAX && *line != '\0'` (64, `include/ps2cnf.h:1`); the terminating `*key = '\0'` is written *only* on the `isspace` break path (`:59-61`). A BOOT2 token of ≥64 consecutive graph characters exits the loop at `i == 64` having written exactly 64 bytes and no NUL, and the function returns normally.
- The sole caller buffer is exactly 64 bytes: `char ps2disc_boot[CNF_PATH_LEN_MAX] = ""` (`src/sources/supportbase.cpp:116`). `GetStartupExecName` then scans it for `':'` at `:127-132` (checking `'\0'` only inside the loop body, after dereferencing) and again for `';'`/`'\0'` at `:141-144`, plus `%s` logging at `:129,151` — all reading past the stack buffer on the unterminated path, as filed.

**Drift:** the finding cites `ps2cnfGetBootFile`'s call/return at `ps2cnf.cpp:70,123`. The function *starts* at `:70`, but the `CNFGetKey` call is at `:115` and the success `return 0` at `:119` (the file is 120 lines; there is no line 123). The `ps2cnf.h:1,3`, `ps2cnf.cpp:54-67`, and `supportbase.cpp:116,120-128` citations are substantively exact.

### RIPTOPL-504 — VERIFIED-DRIFT

Mechanism holds: `embed()` in `tools/assets.py` extracts Korium assets by iterating `manifest["files"].items()` only — a zip entry absent from the manifest is never read, extracted, or reported, and there is no `package.namelist()` comparison anywhere in `tools/assets.py` (grep-verified; the only `namelist()` use in the area is the cfg scan in the test file). The reverse direction does fail only via an uncaught `KeyError` from `package.read(name)`. I re-executed the set comparison at this pin: zip entries = manifest keys = 100, sets equal — so this is a latent gap, exactly as the finding itself states. The only completeness-adjacent assert is the single named-key check at `.github/scripts/test_korium_builtin_assets.py:38` (`"gfx/coverapp.png" not in …["files"]`), exact as cited. The README instruction "Update the archive and manifest together" is at `third_party/korium/README.md:10-11` in substance (the sentence spans the paragraph ending at the file's last lines).

**Drift:** the finding cites the `embed()` loop at `tools/assets.py:166-173`; the loop is at `:150-158` (inside the `zipfile.ZipFile` block opened at `:148`).

### RIPTOPL-505 — VERIFIED-DRIFT

Mechanism holds: nothing in `tools/assets.py` ever deletes from the Korium extraction directory — `theme_dir = Path(ROOT) / "build/theme-assets/korium"` (`:147`) is only ever written (`:157-158`) and read; there is no `rmtree`/unlink of it in the file (grep-verified). The neighbouring cleanup the finding points to does exist: stale `asm/*.c` files are deleted at the top of `embed()`. The stale-file outcome follows from both lookup shapes in the current code: PNG selection uses the themed file whenever it *exists* (`source = str(themed) if themed and themed.is_file() else …`, `:179`), and the two MISC cfg entries are redirected to `theme_dir` unconditionally (`:185-186`), where `bin2c` (`:122-125`) succeeds on a stale file and only `sys.exit`s when the file is *missing*. A file removed from a later manifest therefore keeps shipping from a reused local tree, as filed (the finding correctly labels the outcome INFERRED).

**Drift:** all three cited ranges are stale — asm cleanup cited as `:146-148`, actual `:134-136`; extraction cited as `:162-173`, actual `:147-158`; themed lookup cited as `:195-200`, actual `:173-180` (PNG) and `:184-187` (MISC).

### RIPTOPL-513 — REFUTED

**As filed:** in `sceAtaDmaTransfer`'s LBA48 branch, `hdpro_atad.c` computes `lcyl = (lba >> 8) & 0xff` and `hcyl = (lba >> 16) & 0xff` (the "28-bit forms") instead of `atad.c`'s packed forms, so "LBA bits 32-47 are silently dropped and sectors at or above 2^32 (2 TiB) alias onto low sectors"; fix = copy `atad.c`'s two lines in.

**Defeating evidence:**

1. The HDPro function's LBA parameter is 32 bits. `int sceAtaDmaTransfer(int device, void *buf, u32 lba, u32 nsectors, int dir)` — `modules/iopcore/cdvdman/hdpro_atad.c:678`, and the shared prototype is the same for both variants: `modules/iopcore/cdvdman/atad.h:55`. The code even says so at the cited site: `hdpro_atad.c:695` — `/* Variable lba is only 32 bits so no change for lcyl and hcyl. */` There are no bits 32-47 in the function to drop.
2. For a 32-bit `lba` the cited composition is *correct*, including the LBA48 double-write in `sceAtaExecCmd` (`hdpro_atad.c:482-498`), which writes `(lcyl >> 8)` / `(hcyl >> 8)` on the first pass and the low bytes on the second. With `lba < 2^32`, the true first-pass LCYL byte (LBA bits 32-39) and HCYL byte (bits 40-47) are both zero — which is exactly what `lcyl = (lba >> 8) & 0xff` and `hcyl = (lba >> 16) & 0xff` produce (high bytes zero, low bytes = bits 8-15 and 16-23). The one register that does carry high bits in range, `sector` (bits 24-31 in its high byte), *is* composed the packed way at `hdpro_atad.c:702`, matching `atad.c:680`.
3. The prescribed fix is an identity transformation. Substituting `atad.c:681-682` with a `u32 lba`: `((lba >> 24) & 0xff00)` is 0 (a 32-bit value shifted right 24 has only 8 bits, none in the `0xff00` field) and `((lba >> 32) & 0xff00)` is 0 (shift of a 32-bit value, in practice 0/UB-free in this codebase's usage yields no high bits) — both expressions reduce to exactly the current `lcyl`/`hcyl` values. Copying the lines in changes no register value.
4. The ≥2^32 aliasing the finding describes cannot be produced by these two lines: it would occur, if anywhere, at the `u32` parameter conversion shared by *both* variants (`atad.c:659-661` also takes `u32 lba` and casts to `u64` for its internal helper; the genuinely-`u64` entry, `ata_device_sector_io_internal` via `ata_bd_io_common` at `atad.c:766-768`, is a separate BDM path with no HDPro counterpart). That is an interface-width limitation of `sceAtaDmaTransfer` as declared in `atad.h:55`, not the cited LCYL/HCYL composition defect, and it is not what the finding claims or what its fix addresses.

The mechanism as filed — wrong LCYL/HCYL composition dropping bits 32-47 — is absent.

---

## New defect candidates

None. Re-reading the cited regions (and their immediate caller/writer context) surfaced no genuinely new, re-derived defect not already covered by an existing finding. Apparent extras encountered en route were either part of a filed mechanism (`nbns.c:192`'s extra out-of-bounds NUL write is inside RIPTOPL-037's decode path; `ethsupport.cpp:160`'s `strcpy` shares RIPTOPL-016's narrowed root cause) or already filed elsewhere in the audit (the `ps2ips.c:574` fixed-128 `do_getsockopt` copy is the getsockopt mirror finding in Sable-RiptOPL-ROUND4.md).
