# FULL-VERIFICATION — Cross-repo B (X-19, X-20, X-21, X-22, X-24, X-25, X-26, X-27, X-28, X-29, X-30)

Worker stance: adversarial — each finding re-derived from source at the pins; it survives only on evidence.
X-23 excluded per assignment (CROSS-REF).

## Pins verified before starting (2026-11-14, `git rev-parse HEAD`, all clean, no porcelain output)

| Clone | HEAD | Pin | Match |
|---|---|---|---|
| RiptOPL | `2e347d5ac885cd0ff73e9ad4143781946396f492` | 2e347d5ac885 | ✅ |
| Launchstation | `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` | 9fb0598a79f0 | ✅ |
| POPSLoader | `29272cddbf0122f14e76bc3bdd75e3b46aa870be` | 29272cddbf01 | ✅ |
| Simple-Media-System | `e65ced39a27eee8d996e9257e21594d1cac1c93d` | e65ced39a27e | ✅ |
| PS2-Servers | `c5f021c4d38698860f56b03498adc261dbb8d8dd` | c5f021c4d386 | ✅ |

---

## X-19 / One IOP module links two MD4s and two MD5s — **VERIFIED-DRIFT**

Corrections (core claim stands, and is in fact stronger than the finding states):

1. **Link membership is not merely INFERRED — it is proven by the in-tree build manifests the finding missed.** RiptOPL `ps2.yaml:166`: the `smb2man` IOP target's source list is `[smb2man.c, usmb2/ntlm.c, usmb2/md4c.c, usmb2/hmac-md5.c, usmb2/md5.c, usmb2/unicode.c, modules/iopcore/cdvdman/smb2auth.c]`. Launchstation `ps2.yaml:249-258`: the same seven sources (`iop/smb2man/smb2auth.c` in its layout). The finding's "no in-tree Makefile, link INFERRED" caveat is superseded — the build moved to `ps2.yaml`, which lists both crypto sets explicitly in both repos.
2. **GC-sections do not save it.** Both targets compile with `-ffunction-sections` and link `-Wl,--gc-sections`, but smb2auth's MD4/MD5 survive: `hash_block()` (`smb2auth.c:183-192`) dispatches all three kinds from the reachable `smb2auth_update()`, which the signing path uses (`smb2man.c:166-205` RiptOPL, `:157-205` Launchstation, always with `SMB2AUTH_SHA256`). So smb2man's own use of smb2auth is SHA-256-only; its MD4/MD5 blocks (`md4_block` :31-68, `md5_block` :82-121) are retained dead weight next to usmb2's live ones (`ntlm.c:213-249` calls `MD4Init/Update/Final` + `hmac_md5`). 2× MD4 + 2× MD5 in the one module, both repos — confirmed.
3. **"Byte-identical files on both sides" has one exception.** `md5sum`: `md4c.c` identical (`c3a91c69…`), `md5.c` identical (`0b8857f0…`), `smb2auth.c` identical (`262602b5…`) — but `hmac-md5.c` differs (`c2c5ba22…` vs `3fe6cf2f…`): a 2-line comment at :68-69 naming the repo ("RiptOPL:" vs "Launchstation:"). Code-identical, not byte-identical. Line counts exact as cited: md4c.c 240, md5.c 190, hmac-md5.c 99 (529 total).

## X-20 / Launchstation EE links mbedTLS SHA-256 and a hand-rolled SHA-256 — **VERIFIED-DRIFT**

Binary-level claim proven: Launchstation `ps2.yaml` EE target's single source list contains `src/cloud_http.c` (:503), `src/cloud_google.c` (:507), `src/mc_card_view.c` (:540), `src/mc_sha256.c` (:541), `src/mc_save_export.c` (:546), `src/mmce_save_versions.c` (:550), and its libs list (:642) includes `mbedtls, mbedx509, mbedcrypto`. FP implementation exact: `mc_sha256.c` 94 L + `mc_sha256.h` 24 L = 118 total; header (:2-4) states the documented reason verbatim ("linked in builds without the cloud TLS stack and runs on the host in tests"). mbedTLS SHA-256 call sites exact: `cloud_http.c:25,142,842-1267`, `cloud_google.c:18,1230-1262`. FP callers exact: `mc_card_view.c:441-489`, `mmce_save_versions.c:85-87,148-156,330-332`, `mc_save_export.c:85-87`.

Correction: the finding's "`src/mc_save_export.c` uses both (:11-12,53-78 mbedTLS; :81-88 FP)" is imprecise — mc_save_export's mbedTLS use at :37-78 is **AES (`mbedtls/aes.h`) and HMAC-SHA1 (`mbedtls_md_hmac(MBEDTLS_MD_SHA1)`)**, not mbedTLS SHA-256; its local `sha256()` helper at :81-88 is the FP `McSha256`. So no single file uses both SHA-256 implementations; the double is at binary level via cloud_* (mbedTLS SHA-256) + mc_* (FP SHA-256), which is what the headline claims. Verdict drift is for the file-level sub-claim only.

## X-21 / SMS leaves truncated copies indistinguishable, in every path — **WEAKENED**

What survives — every named streaming path and all four SMS sub-defects, re-read line by line:

- `SMS_CopyFile` (`SMS_CopyTree.c`, function at :298-387): read loop `if (lnRead <= 0) break;` (:340) — a read error (−1) is indistinguishable from EOF (0), `retVal` stays 0, the short file stays. No `fioRemove` of the destination anywhere in `SMS_CopyFile`/`SMS_CopyTree` (the only `fioRemove` in the file is `DeleteFileCB` :243, a different feature).
- Write error: `lfError = 1` (:344) → `retVal = 3` (:372). In `SMS_CopyTree` (:219-220) only `m_Error == 1` (→ "out of memory") and `== 3` (→ `error_1`, "not enough space") have message branches — so a generic write failure is reported as *not enough space*, and cancel code **2 matches no branch at all** (silent, no `GUI_Error`).
- Single-file caller ignores the return: `SMS_GUIFileCtxMenu.c:102` `SMS_CopyFile(lpPath, lpFileCtx, 0, NULL, NULL);` — exact.
- Counter-model exact: RiptOPL `filemgr.cpp:359-370` — on failure `remove(dst)`, plus size re-read before counting a copy good.
- POPSLoader sub-claim stands: `luasystem.cpp` `copy_file_contents` (in the :826-877 region) opens dest `O_TRUNC`, on write/read failure returns −1 **leaving the partial dest in place** (no unlink), closes unchecked; `lua_rename` deletes the source only on success (it checks `!= 0` first — the finding's "then deletes the source" is the success-path sequence, not a failure-path deletion).
- Launchstation sub-claim stands: `filer_copy.c` file-branch close failure (`genClose(out_fd)` < 0 → `ret < 0` → `goto copy_file_exit`) — the exit path closes fds and frees buffers but never removes `out`; folder-branch failure returns `copyDiagFail(-1)` leaving the partial tree (only a PSU-backup root image is discarded).

What falls — the title's universal "**in every path**": SMS has one more copy path the finding did not name, `_copy_file_to_mc` (`SMS_GUIFileCtxMenu.c:143-196`, used for lng/pal/SMS/SMB asset imports at :212,235,285,309,334), which reads the whole source into RAM, does a single `fioWrite(...) == lSize` check (:180), and **on failure deletes the destination**: `if (!retVal) { fioRemove(apDst); fioRmdir(apDst); }` (:183-186). It is a small buffered import helper, not a streaming file copy, so the defect class and the fix list are unaffected — but "every path" is falsified as written. The accurate statement is: *every streaming copy path* (SMS_CopyFile + SMS_CopyTree + its ignored-return caller) leaves truncated copies indistinguishable.

## X-22 / Intra-binary duplicate machinery (three pure deletions) — **VERIFIED**

- (a) `cloud_google.c:61-122` `json_string` is escape-aware (backslash switch :95-110; end-scan skips `\"`); `dash_tools.c:715-747` `releaseJsonString` (~32 L) uses plain `strchr(p, '"')` — no escape handling. Both are in the same EE binary: `ps2.yaml` EE defines include both `ETH` and `WLE_NATIVE_CLOUD` (:626, and ETH in the same defines block), which is exactly `releaseJsonString`'s compile guard (`dash_tools.c:714`), and both files are in the EE source list (:507, :599).
- (b) `filer_copy.c` attribute ladder written twice inside `copy()`: folder branch :1225-1275 ≈ file branch :1639-1690 — same mc/vmc/xfrom/host/udpfs/smb/mass/mx4sio/ata ladder and ChStat tail. The two copies have already drifted slightly (file copy adds an `mmce` skip branch and gates `mcSetFileInfo` on `mctype_PSx == 2`; folder copy does neither) — which is the finding's point, not a refutation.
- (c) POPSLoader `system.lua`: the 32,768-byte chunk loop appears in `WriteAtomic` (:5261, loop :5273), `WriteBytesDirectBounded` (:5421, loop :5439) and `WriteBytesAtomicBounded` (:5461, loop :5484) — three parameterisable copies in the cited :5261-5509 span, differing mainly in tmp-file promotion and the bounded-iteration guard.

## X-24 / Network-init constants have speciated — **VERIFIED-DRIFT**

Values re-extracted exactly: RiptOPL `system.cpp:277` `int retry = 100` (DDIOC_OFF loop :278); Launchstation `init.c:2585` `int retry = 100` with the comment at :2598-2604 explicitly citing RiptOPL's policy, and `init.c:577` `int retry = 20` on the pre-reset path (same devctl, :586) — the intra-repo 100/20 split is real and the 20 has no stated reason. Link wait: RiptOPL `netsupport.cpp:88` `if (retry_cycles >= 30) // 30s = 30*1000ms` (loop at :80; finding cited :82,88 — :82 is two lines into the loop body). No equivalent wait in the other two repos' init paths. SMS dead declaration exact: `include/SMS.h:308` `void SMS_StartNetwork(void*);` — `grep -rn SMS_StartNetwork src include` returns that one line and nothing else; no definition exists.

Correction: SMS's "**1**" is not a literal retry constant. `SMS_IOP.c:1197` is a single unconditional call — `if (lFD >= 0) fioIoctl(lFD, DEV9CTLSHUTDOWN, NULL);` — i.e. exactly one attempt, no loop and no retry variable (the same single-attempt pattern occurs again at `SMS_IOP.c:1669`). The speciation claim (100 vs 20 vs one-shot) is correct in effect; only the presentation of "1" as a constant value is drift.

## X-25 / Config-parser consolidation: Launchstation 4 → 2, POPSLoader ~27 sites — **VERIFIED-DRIFT**

Launchstation parsers re-read: `get_CNF_string` (`config.c:111-160`, aborting), `dashKvParse` (`dash_store.c:65-103`, lenient), `smbConfigParse` (`smb_cnf.c:345-438`, validator; malformed line `continue`s at "not KEY = value: skipped, the rest still counts"). Trim duplication exact: `diff` of `dash_store.c:53-63` vs `smb_cnf.c:60-70` = **1 line**, the signature (`char *dashTrim(char *s)` vs `static char *trim(char *s)`) — as claimed.

Corrected count: Launchstation has **4 config parsers only if the positional `getIpConfig` (`main_startup.c:55`, IPCONFIG.DAT NUL-split) is counted** — there are **3** key=value line parsers, not 4. And the proposed end state is not 2 parsers total: retiring `get_CNF_string` leaves `dashKvParse` + `smbConfigParse`-as-validator (**2 line-parser functions**) **plus** `getIpConfig`, which the finding's own topic verdict says to keep separate — i.e. 4 → 3 parsers, 3 → 2 line parsers. The finding's benefit line ("one parser + one trim function deleted") is the accurate version; the "4 → 2" headline overstates by one.

POPSLoader count re-derived: `grep -c 'string.match(data'` on `system.lua` = 29 lines, of which 1 is ROMVER (:5224, not config). The remaining **27 extraction statements** are: `SmbParse`'s table-loop statement (:5883, two-pattern `"\n"..k.."="` / `"^"..k.."="`), the Ember 5-key loop statement (:6381-6382), and 25 hand-unrolled statements in `LoadSettingsNonFatal` (:6388-6409 = 22, plus PROFILE :6427, RETROGEM_GAMEID :6437, SMB_MODULES :6532), covering 31 named keys + the SMB field table. "~27 sites" is exact at statement granularity (56 individual `string.match` calls). The finding's cited range `:6408-6460` covers only the tail of the unrolled block; the full span is :6376-6532.

## X-26 / One malformed line amputates Launchstation's main CNF — **VERIFIED-DRIFT**

Mechanism fully re-traced and confirmed; only line numbers drifted by 1-2:

- Abort: `config.c:137-138` `if (*tp != '=') return false;` (finding cited :139-140). Name scan `config.c:130-131` `while ((*tp >= 'A') || ((*tp >= '0') && (*tp <= '9')))` — a `.` or `-` or internal space ends the name early, the following char is not `=`, abort. Comment branch `config.c:123-128` (finding cited :124-129): any first char `< 'A'` — including a digit-led line — skips the line as a comment.
- Both callers loop on the return and treat `false` as EOF, exactly as cited: `config.c:950` (`loadConfig`, LAUNCHELF.CNF) and `main_startup.c:180` (`readSystemCnf`, SYSTEM.CNF) — `for (var_cnt = 0; get_CNF_string(&CNF_p, &name, &value); var_cnt++)`. Everything below the bad line is silently dropped on every boot.
- Permanence: writer `configBuildSaveText` (`config.c:533-718`) enumerates only the in-memory `setting` state, so the next save rewrites the file from the truncated state. (INFERRED in the original, and the writer code re-read here supports it: it emits known fields from `setting->…`, nothing from the original file text.)
- The in-repo existence proof is exact: `include/dash_internal.h:657-660` — "Tiny lenient "key = value" line reader shared by the dash modules. **Unlike get_CNF_string it skips malformed lines instead of stopping.**" The main config does not use it.

## X-27 / POPSLoader config semantics invert the family on both axes — **VERIFIED**

First-wins: every POPSLoader extraction is `string.match(data, "\nKEY=([^\n]*)") or string.match(data, "^KEY=([^\n]*)")` (`SmbParse` `system.lua:5883`; `LoadSettingsNonFatal` :6388-6532) — Lua `string.match` returns the first match, so a stale first duplicate governs. Save-deletes-unknowns: `EncodeSettings` (`system.lua:5891-5941`) builds the file from a fixed list of known keys (+ `SmbAppendLines`) and nothing else; a full rewrite therefore deletes every unknown/hand-added key and the corrected second duplicate. Family contrast re-verified: RiptOPL `ConfigSet::setStr` (`config.cpp:363-387`) finds the existing entry and overwrites it (last-wins), and its legacy writer (`config.cpp:1590-1598`) enumerates **all** stored entries, preserving unknowns on save; Launchstation's `get_CNF_string` dispatch loop (`config.c:950+`) assigns into `setting->…` fields on every occurrence (last-wins), as do the `dashKvParse`/`smbConfigParse` consumers. POPSLoader is the sole first-wins + delete-unknowns member, on both axes as claimed.

## X-28 / RiptOPL CRC-32 text ×3 + two CRC-32-family functions in one EE binary — **VERIFIED-DRIFT**

Binary claim verified: `USBA_crc32` (`src/platform/system.cpp:467-492`, poly `0x04C11DB7`, non-reflected; callers `ethsupport.cpp:1427`, `supportbase.cpp:656,1226,1473`) and `oggCrcDelta` (`src/core/bgm.cpp:361-376`, table at :359, same polynomial, delta-only contract; called at :395) are both in the single EE target's source list (`ps2.yaml:641` includes both `src/platform/system.cpp` and `src/core/bgm.cpp`).

Correction to "the same CRC-32 text three times": function texts extracted and diffed — the two PC copies are **byte-identical** (`iso2opl.c:48-70` `crc32` ≡ `opl2iso.c:43-65` `crc32`, diff empty), but the EE copy has **already drifted** from them in three places: `unsigned char byte` with the signedness/OOB comment (PC: `int byte`), the added loop bound `&& (count <= 32)`, and the return-type spelling. So the repo carries one function in three copies, two identical and one drifted — the drift the finding warns about has already happened on the EE copy, which strengthens the problem statement but falsifies "same text ×3" literally. Fix scope unchanged (~46 lines for the two PC copies; bgm's delta variant correctly left alone).

## X-29 / SMS positional SMB list has no resync — **VERIFIED**

`SMS_LoadSMBInfo` (`SMS_Config.c:314-379`) re-read: six unconditional `File_GetString` calls per record (:333-338 — IP, server name, client name, user, password, description), then port+share (:345-346) gated by the single `!FILE_EOF(lpFileCtx)` check (:344) — the cited 6-vs-8-by-one-EOF-check structure is exact. `File_GetString` returns an empty string for a blank line (first byte `\n` breaks with `i == 0`), and the parser consumes a fixed line count per record regardless, so one inserted blank line shifts every field of that record and — because framing is purely counted, with no key/marker to re-anchor on — every subsequent record stays shifted. No resync mechanism exists in the function; the only guards are per-record validation (IP/server/client non-empty, server name < 14 chars, :357-361, which silently drops some shifted records without reframing) and the all-digit port check (:349-355, which protects only the port field). Over-long field behaviour exact: `SMS_FileContext.c:2201-2202` — past `aMaxLen` the reader sets `lfTruncated` and keeps consuming to `\n` (silent truncate **and drain**), and `SMS_SaveSMBInfo` (:388-421) writes the in-memory (truncated) values back via `_smb_put_line`, making the truncation permanent on the next save.

## X-30 / Self-update trust/policy divergences — **VERIFIED**

All three divergences re-read at the cited sites:

1. **Redirect allowlist:** RiptOPL `platform/selfupdate.c:105-126` `suSplitUrl` — allowlist of exactly 3 hosts (`github.com`, `release-assets.githubusercontent.com`, `objects.githubusercontent.com`, :107), any other host/port/userinfo/IP rejected. Launchstation's updater path has none: `self_update.c:204` downloads via `cloudHttpDownloadMem`, whose loop (`cloud_http.c:1000-1006`) applies the `cloud_google_media_host` check **only when `bearer != NULL`**, and whose redirect handling (:1083-1110, accept at :1094) follows any `https://` Location (or same-host relative path) with no host allowlist.
2. **Free-space pre-check:** Launchstation `self_update.c:341-350` — `find_file_info(...) && filerFreeSpace(...) && free_bytes + old size < size + UPDATE_SPACE_MARGIN` refuses before touching the running ELF. RiptOPL has no such check: the full `suInstallWorker` (`ui/selfupdate.cpp:252-345`) was read end-to-end — it fetches to RAM, verifies SHA-256, then opens the booted ELF `WRONLY|CREAT|TRUNC` and writes; no free-space/cluster API is called anywhere in the file, while the comment directly above it (:249-250; finding cited :250-251) describes the fit requirement ("The new ELF has to fit in the free clusters plus the old ELF's own, with one to spare") as if it were implemented. Orphan comment confirmed.
3. **Version-proof:** RiptOPL compares integer revisions (`suRevision`, `platform/selfupdate.c:55`; `suRemoteRev > suRevision(OPL_VERSION)`, `ui/selfupdate.cpp:240`). Launchstation compares commit ancestry via GitHub's compare API with an explicit diverged-refusal (`dash_tools.c:814-887`: `UPDATE_RELATION_DIVERGED = 3` :816, `updateCommitRelation` :835-887, "Diverged is NOT an upgrade"). The finding's disposition (keep both, documented as deliberate — moving `latest` tag vs pinned channels) is consistent with the code as read.

---

## Unnumbered candidates (genuinely new, found during verification — not part of any verdict above)

1. **RiptOPL's PC-tool CRC-32 copies retain the signed-byte OOB index bug the EE copy fixed.** `tools/pc/iso2opl/src/iso2opl.c:48-70` and `tools/pc/opl2iso/src/opl2iso.c:43-65` declare `int byte` and assign `byte = string[count++]` from a `const char *` — on signed-char platforms bytes ≥ 0x80 sign-extend, making `crctab[byte ^ ((crc >> 24) & 0xFF)]` a negative (out-of-bounds) index. The EE copy's comment at `system.cpp:470-471` describes exactly this defect and its fix (`unsigned char byte`), which was never ported to either PC copy. Cross-copy drift with a memory-safety consequence, in the X-28 family but a distinct defect.
2. **SMS DEV9 shutdown is single-attempt in two places, not one.** Beyond the X-24 site (`SMS_IOP.c:1197`, poweroff thread), the boot path at `SMS_IOP.c:1669` also issues exactly one `DEV9CTLSHUTDOWN` with no retry — relevant if the X-24 intra-repo alignment is ever scoped.
3. **Launchstation's self-update ancestry check parses GitHub's JSON with the escape-less extractor.** `updateCommitRelation` (`dash_tools.c:864`) and the release fetch (:968) use `releaseJsonString` — the weaker X-22(a) copy — for the update-order decision, while the escape-aware `json_string` exists in the same binary. A status/target value containing an escaped quote would terminate extraction early on the security-relevant path. Low practical risk (GitHub's `status` values are fixed tokens), recorded for completeness.
