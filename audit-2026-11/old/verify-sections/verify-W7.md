# Verification W7 — RiptOPL Category 6, ROUND9-MODULES findings RIPTOPL-456…469, -473

- **Clone:** `~/workspace/audit-clones-2026-11-13/RiptOPL`
- **Pin verified at start:** `git rev-parse HEAD` = `2e347d5ac885cd0ff73e9ad4143781946396f492` (matches assigned pin `2e347d5ac885`); clone left git-clean (read-only throughout).
- **Method:** every cited `path:line` re-read in the clone; mechanism re-derived from the code as it stands, including buffer sizes, caller/guard context, and — for -467 — the literal free/compare order plus what `apaCacheFree` actually does; for -460 the NTLMv2 blob offsets were mapped byte-by-byte; for -468 the expression was evaluated under C precedence at both cited copies and the mask value checked against PS2SDK's `speedregs.h` (`SPD_CAPS_SMAP (1<<0)`, via the ps2sdk documentation mirror — the header itself is not in this tree). Severity/effort claims ignored.
- **Counts:** VERIFIED 11 · VERIFIED-DRIFT 0 · WEAKENED 4 · REFUTED 0 · New defect candidates 1

| ID | Verdict | One-line evidence (path:line) |
|---|---|---|
| RIPTOPL-456 | VERIFIED | All three patch modules guard only on `m != NULL` and dereference fixed offsets with no `text_size`/original-word check: `modules/iopcore/patches/apemodpatch/main.c:105-116` (up to `+0x3d1c`), `modules/iopcore/patches/f2techioppatch/main.c:49-50` (`+0x16bc`), `modules/iopcore/patches/iremsndpatch/main.c:87-108` (reads `+0xac0/+0xac4`, writes up to `+0x1ff8`) |
| RIPTOPL-457 | VERIFIED | Only guard is `argc > 1` before 4+4-byte copies at `modules/pademu/pademu.c:118,125` and `argv[1][3]` at `:138`; the sole in-tree caller passes exactly 8 bytes (`ee_core/src/iopmgr.c:458-461`), confirming the latent framing |
| RIPTOPL-458 | VERIFIED | CREATE validates at `modules/vmc/genvmc/genvmc.c:904`, STATUS at `:921-922` passes `buf` unchecked to `vmc_status`, which `memcpy`s `sizeof(statusVMCparam_t)` = 76 bytes (`genvmc.c:882-885`; size at `modules/vmc/genvmc/genvmc.h:36-42`) |
| RIPTOPL-459 | WEAKENED | Missing terminator is real (`modules/network/smbman-ra/smb.c:1618`, field `smb.h:278`), but no valid dotted-quad IPv4 string can trigger it — see reasoning below |
| RIPTOPL-460 | VERIFIED | Blob zeroed (28 bytes) at `modules/network/smb2man/usmb2/ntlm.c:232`, `0x0101` at `:234`, client challenge `memset(..., 1, 8)` at `:236` — blob layout puts the timestamp at blob+8 (`:240-243` region, zeroed) and the challenge at blob+16 (`+32` from the NTProofStr base) |
| RIPTOPL-461 | VERIFIED | `strncpy(buffer->name, fno.fname, 255)` at `modules/bdm/bdmfs_fatfs/src/fs_driver.c:650`; source `fname[FF_LFN_BUF + 1]` = 256 (`modules/bdm/bdmfs_fatfs/fatfs/include/ff.h:271`, `ffconf.h:148` `FF_LFN_BUF 255`), destination `iox_dirent_t.name[256]`, no terminator written |
| RIPTOPL-462 | WEAKENED | Loops as cited (`modules/bdm/src/bdm.c:143-152`, `:51-71`), but the only in-tree `bdm_get_bd` caller passes exactly `MAX_CONNECTIONS` and `bdm_connect_bd` is not log-silent — see reasoning below |
| RIPTOPL-463 | VERIFIED | Clamp instead of reject at `modules/network/udpfs_ministack/src/ministack_xchg.c:68-70`; clamped length returned as the reply length with no flag at `:116-120`; cap 1016 at `modules/network/udpfs_ministack/include/mstack_xchg.h:19,37` |
| RIPTOPL-464 | VERIFIED | `modules/network/udpfs_shared/src/udpfs_core.c:359-382`: `_request` return discarded at `:378-379`, reply (`udpfs_msg_close_reply_t`, with a `result` field at `modules/network/udpfs_ioman/src/udpfs_packet.h:100-106`) never inspected, unconditional `return 0`; neighbours check `msg_type` (e.g. `:343,489,528`); ioman frees the fd regardless at `modules/network/udpfs_ioman/src/udpfs_ioman.c:214-218` |
| RIPTOPL-465 | VERIFIED | `u32 err;` uninitialised at `modules/iopcore/cdvdfsv/ncmd.c:237`, written only inside the loop at `:241-243`, packed at `:246` — with `St->sectors == 0` the loop body never runs |
| RIPTOPL-466 | VERIFIED | `getModInfo("modload\0", &info)` return discarded at `modules/iopcore/cdvdman/ioplib_util.c:282`, then `info.exports[7..22]` read/written at `:285-317`; `getModInfo` returns 0 leaving `info` untouched at `:78-99`; every sibling caller checks (same file `:382-383`; `device-mmce.c:76`, `device-udpfs.c:82`, `device-smb.c:43`, `device-http.c:93`, `heapdiag.c:156`) |
| RIPTOPL-467 | VERIFIED | Literal order confirmed: `apaCacheFree(clink)` at `modules/hdd/apa/src/hdd_fio.c:510`, then `apaPassCmp(clink->header->fpwd/rpwd, …)` at `:511-512`; `apaCacheFree` only decrements `nused` and relinks (`modules/hdd/apa/src/cache.c:176-192`) — no deallocation, no intervening allocation, exactly the benign-today/latent-by-contract picture claimed; `APA_ENABLE_PASSWORDS` is 1 (`modules/hdd/apa/src/apa-opt.h:36`), so the comparator really dereferences |
| RIPTOPL-468 | WEAKENED | Mis-parenthesised expression confirmed at both copies (`modules/network/udpfs_smap/src/smap.c:516`, `modules/network/smap_udpbd/src/smap.c:522`; correct form `modules/network/smap-ingame/smap.c:541`), but the "correct only by accident of the mask's value" inference is unsound — see reasoning below |
| RIPTOPL-469 | VERIFIED | Ordering exact: RX callback at `modules/network/udpfs_ministack/src/main.c:49` (stores a pointer to this copy's `handle_rx_eth` in the resident SMAP driver, `modules/network/udpfs_smap/src/xfer.c:94-99`), `udptty_init()` at `main.c:61` (closes fds 0/1, re-registers tty: `modules/network/udpfs_ministack/src/udptty.c:75-88`), duplicate check only at `main.c:63-66`; the module's own resident-only comment for `mstack:` is at `main.c:68-69` |
| RIPTOPL-473 | WEAKENED | Result discarded and ROM built regardless (`modules/ilink/iLinkman/src/iLink.c:105-110`), but the zero-GUID outcome holds for only one of the two failure sub-cases — see reasoning below |

---

## Full reasoning — every non-VERIFIED verdict

### RIPTOPL-459 — WEAKENED

The IOP-side code is exactly as cited: `strncpy(server_specs.ServerIP, SMBServerIP, 16)` at `modules/network/smbman-ra/smb.c:1618`, destination `char ServerIP[16]` at `modules/network/smbman-ra/smb.h:278` (immediately followed by `MaxBufferSize`, so an over-read does run into it as claimed), and both consumers trust it as a C string — `sprintf(tree_str, "\\\\%s\\IPC$", specs->ServerIP)` into `tree_str[64]` at `modules/network/smbman-ra/smb_fio.c:962,973` and `sprintf(tree_str, "\\\\%s\\%s", specs->ServerIP, …)` into `tree_str[274]` at `smb_fio.c:1020,1030`. The comparison in the finding's fix also checks out: the smb2man LOGON handler does force termination (`strncpy(ip, logon->serverIP, sizeof(ip) - 1)` + `ip[sizeof(ip) - 1] = '\0'` at `modules/network/smb2man/smb2man.c:1578-1579`). No guard anywhere on the smbman-ra path terminates the field.

What narrows it: the trigger requires the source to occupy all 16 bytes with no NUL, and **no valid IPv4 dotted-quad can do that** — the longest, `255.255.255.255`, is 15 characters, so a conforming fill of `smbLogOn_in_t.serverIP[16]` (struct copy in-tree at `tests/smb2-live/inc-sdk/ps2smb.h`, `char serverIP[16]`) always leaves room for the terminator. The only in-tree EE caller confirms this bound: `sprintf(logon.serverIP, "%u.%u.%u.%u", …)` from four octets at `src/sources/ethsupport.cpp:96,98`. The defect therefore fires only if an EE caller fills all 16 bytes by `memcpy`/`strncpy` of a non-terminated, non-dotted-quad value — a malformed fill, not any representable server IP. (Note also that `smb_Connect` already dereferences the input as a C string for `inet_addr(SMBServerIP)` at `smb.c:1606`, before the copy.) Verdict: the missing-terminator mechanism holds, but only under that narrower, malformed-fill condition; as a hazard for any actual IP string it does not hold.

### RIPTOPL-462 — WEAKENED

Both loops are as cited: `bdm_get_bd` fills only `min(count, MAX_CONNECTIONS)` entries and returns no count (`modules/bdm/src/bdm.c:143-152`, `MAX_CONNECTIONS 20` at `:19`; exported at `modules/bdm/src/exports.tab:12`), and `bdm_connect_bd` exits its slot loop with no refusal path when full (`bdm.c:51-71`; exported at `exports.tab:8`).

Two narrowings. (1) The unwritten-tail read cannot occur with any in-tree caller: the sole in-tree consumer, `bdm_diag_fill_snapshot`, declares `struct block_device *devices[20]` and passes exactly 20 (`modules/bdmevent/main.c:15-18`), so every requested slot is written (empty slots are written as `NULL` from `g_mount[i].bd`). The finding's exposure rests entirely on a hypothetical external consumer passing `count > 20`, which the finding itself marked INFERRED. (2) `bdm_connect_bd` is not dropped "silently" in the log sense: the entry `M_PRINTF("connecting device %s%dp%d …")` at `bdm.c:57-58` fires for every connect attempt, including one that finds no slot. What is actually missing is narrower — no *failure/full-specific* log line, no mount event, and no error return (the function is `void`) — versus the sector-size refusal in `bdm_try_mount`, which logs its reason and notifies the callback. The API-contract defect stands; the "silent / uninitialised-read" framing holds only in those narrower conditions.

### RIPTOPL-468 — WEAKENED (inference unsound; defect real and in one respect broader)

The expression and the divergence are exactly as cited: `if (!SPD_REG16(SPD_R_REV_3) & SPD_CAPS_SMAP) return -1;` at `modules/network/udpfs_smap/src/smap.c:516` and `modules/network/smap_udpbd/src/smap.c:522`, versus the correct `if ((SPD_REG16(SPD_R_REV_3) & SPD_CAPS_SMAP) == 0)` at `modules/network/smap-ingame/smap.c:541`. Under C precedence this is `(!rev3) & SPD_CAPS_SMAP`: `!` binds tighter than `&`, and `!rev3` is 1 iff `rev3 == 0`, else 0.

The finding's inference — "it therefore behaves like the intended test only if `SPD_CAPS_SMAP` is exactly 1", i.e. correct-by-accident at the actual mask value — does **not** survive evaluation:

- The mask value is now resolvable: PS2SDK `speedregs.h` defines `SPD_CAPS_SMAP (1<<0)` = 1 (the header is not in this tree, as the finding said; value taken from the ps2sdk documentation mirror).
- Even at mask = 1 the expression is **not** equivalent to the intended test. Intended: fire iff `rev3 & 1 == 0` (any even `rev3`). Actual: fire iff `rev3 == 0`. Counterexample: `rev3 = 2` — a SPEED capability word with the ATA bit (`SPD_CAPS_ATA (1<<1)`, checked against this same register at `modules/hdd/atad/src/ps2atad.c:282`) set and the SMAP bit clear. Intended test returns -1; the mis-parenthesised test evaluates `(!2) & 1 = 0` and lets the SMAP driver proceed on SMAP-less hardware. Same for any nonzero even `rev3` (4, 6, …). So the check is not "correct by accident" today — it is already wrong for every `rev3 ∉ {0, 1}` with bit 0 clear; it coincides with the intended test only on `rev3 ∈ {0, 1, odd}`.
- The subsidiary claim "for any multi-bit … mask the check silently never fires" is also imprecise: for a multi-bit mask that includes bit 0 (e.g. 3), `(!rev3) & mask` is nonzero when `rev3 == 0`, so it does fire in that case. "Never fires" holds only for masks with bit 0 clear.

The headline defect — a mis-parenthesised capability gate in both neutrino copies, divergent from the third copy, fixable by the parenthesisation in the finding — is VERIFIED in substance. The verdict is WEAKENED because the INFERRED soundness claim the task asked me to assess (correct-by-accident conditional on the mask being 1) is refuted by the `rev3 = 2` counterexample at the mask's actual value.

### RIPTOPL-473 — WEAKENED

The core mechanism is exact: `_start` zeroes the state (`memset(ConsoleModelName, 0, …)` and `ConsoleGUID = 0` at `modules/ilink/iLinkman/src/iLink.c:105-106`), calls `GetConsoleIDs(&ConsoleGUID, ConsoleModelName)` discarding the result at `:107`, and proceeds to `InitializeConfigurationROM()` at `:110` regardless; the ROM consumers build the Node Unique ID / Bus Info from `ConsoleGUID` at `modules/ilink/iLinkman/src/iLink_crom.c:355-356,384-385` and copy `ConsoleModelName` at `:370`, and `iLinkGetLocalNodeEUI64` returns `ConsoleGUID` at `iLink.c:362-364`. `GetConsoleIDs` does return -1 on failure (`modules/ilink/iLinkman/src/iLink_internal.c:63-64,68-69`).

The narrowing is in *which* published values are wrong, by failure sub-case. `GetConsoleIDs` writes `*guid` at `iLink_internal.c:67` **before** the model-name read. So:

- `sceCdRI` failure (`iLink_internal.c:63`): GUID stays 0, model name stays empty — the finding's zero-EUI-64 + empty-model outcome holds in full.
- `sceCdRM`-only failure (`iLink_internal.c:68`): the GUID has already been written and is valid; only the model name is empty. The "publishes a zero EUI-64 … identical on every console that hits the failure" claim does not hold for this sub-case.

"Driver loads and publishes partial identity data despite an anticipated, reported failure" holds for both sub-cases; the duplicated zero-identity consequence holds only for the first.

---

## New defect candidates

### NEW-W7-1 — Second free-then-read of an APA cache entry, in the (live-compiled) format path

- **Locations:** `modules/hdd/apa/src/hdd_fio.c:435-438` (in `apaFormat`'s `APA_FORMAT_MAKE_PARTITIONS` / `APA_FORMAT_WIPE_COMMON_ONLY` block); both macros are defined in this build (`modules/hdd/apa/src/apa-opt.h:10,28`), so the branch is compiled, unlike a dead `#else`.
- **Mechanism:** `clink` is obtained from `apaFindPartition(f->unit, "__sysconf", &rv)` at `hdd_fio.c:433`, released with `apaCacheFree(clink)` at `:435`, and then dereferenced — `clink->sector` is passed to `hddAddPartitionHere(…, clink->sector, …)` at `:438`. This is the same by-contract use-after-free pattern as RIPTOPL-467 (which cited only the `apaOpen` instance at `hdd_fio.c:510-512`) at a second site. As with -467 it is benign today by the same reasoning: `apaCacheFree` only decrements `nused` and relinks the entry (`modules/hdd/apa/src/cache.c:176-192`), the memory is a static cache array, and no cache allocation intervenes between `:435` and the argument evaluation at `:438` (only `memset`/`strcpy` on `params.id`). Any future change that allocates a cache header in that window — or makes `apaCacheFree` actually release/reuse storage — silently turns the `__common` partition's start sector into whatever the reused entry holds, on a format path.
- **Fix in words:** Hoist `u32 sector = clink->sector;` above the `apaCacheFree(clink)` at `:435` and pass `sector` at `:438` — the same reorder RIPTOPL-467 prescribes for `apaOpen`.
