# Sable — Full-Verification New Findings (2026-11-14)

**Findings filed by the full-verification phase (phase 2) itself.** While adversarially re-deriving the audit's standing findings, the six verification passes surfaced twelve defects the original nine rounds never filed. They are numbered here, in the audit's own sequence, and carry the same standing as any other finding: **STANDING**, unverified by any further pass. They have **NOT** been through a verification pass of their own.

**Pins (unchanged, round 2):** RiptOPL `2e347d5ac885` · Launchstation `9fb0598a79f0` · POPSLoader `29272cddbf01` · SMS `e65ced39a27e` · PS2-Servers `c5f021c4d386`.

---

### RIPTOPL-603 / smb_open stores an unterminated name with a full-size strncpy count / Category 6

- **Category:** 6
- **Locations:** `modules/network/smbman-ra/smb_fio.c:361` (`smb_open`); `SMB_NAME_MAX` defined at `smb_fio.c:69`, `FHANDLE.name` at `smb_fio.c:78`; the name is read at `smb_fio.c:697`.
- **Problem:** In `smb_open` (modules/network/smbman-ra/smb_fio.c:361): `strncpy(fh->name, path, SMB_NAME_MAX);` where `SMB_NAME_MAX` is 256 (smb_fio.c:69) and `FHANDLE.name` is `char name[SMB_NAME_MAX]` (:78) — the copy count equals the full field size, unlike the dopen site in RIPTOPL-040 (count 255), so a path of ≥256 chars (prepare_path can produce up to ~1,023) leaves fh->name with no NUL terminator anywhere in the field. Impact currently latent: fh->name is only read for directory handles (smb_fio.c:697, set by smb_dopen), not for open-file handles, so no live over-read was demonstrated. Distinct site not cited by RIPTOPL-040; same one-line pattern fix applies. (A similar count-equals-size copy exists at smb_fio.c:714, `strncpy(dirent->name, info->FileName, SMB_NAME_MAX)`, bounded in practice by getStringField termination in the SearchBuf.)
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ) for the missing terminator; INFERRED for any live consequence

*(Source: full verification of RiptOPL, Sable-VERIFY2-RIPTOPL.md §4 — was CANDIDATE-W1-1.)*

### RIPTOPL-604 / mmce_fs SET_GAMEID devctl case dereferences `arg` unchecked / Category 6

- **Category:** 6
- **Locations:** `modules/mmce/mmceman/src/mmce_fs.c:1126-1129`; callee `modules/mmce/mmceman/src/mmce_cmds.c:226`.
- **Problem:** `modules/mmce/mmceman/src/mmce_fs.c:1126-1129`: `case MMCE_CMD_SET_GAMEID: char *str = (char*)arg; res = mmce_cmd_set_gameid(str);` — no `arg == NULL` check and no arglen bound, in the same devctl switch RIPTOPL-057 covers for its four `*(u32*)arg` cases. A NULL/short argument reaches `mmce_cmd_set_gameid` (modules/mmce/mmceman/src/mmce_cmds.c:226) as a string pointer. Filed separately because RIPTOPL-057 as written scopes itself to the four u32 cases; it may be folded in as a fifth case at fix time.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

*(Source: full verification of RiptOPL, Sable-VERIFY2-RIPTOPL.md §4 — was CANDIDATE-W2-1.)*

### RIPTOPL-605 / tools/assets.py comment asserts the opposite of the RA anchor table it annotates / Category 7

- **Category:** 7
- **Locations:** `tools/assets.py:167-168`; the anchor table at `src/sources/ratls_ps2.cpp:208-212`.
- **Problem:** `tools/assets.py:167-168` comment states "RA's lookup needs every root", but the RA anchor table in `src/sources/ratls_ps2.cpp:208-212` uses only five of the seven roots (GTS×3 + ISRG×2); the Sectigo pair is updater-only. The comment is the likely origin of the RIPTOPL-600 embed condition. Doc-only defect at a distinct location from RIPTOPL-600 (which targets the condition, not this comment).
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

*(Source: full verification of RiptOPL, Sable-VERIFY2-RIPTOPL.md §4 — was CANDIDATE-W8-1.)*

### SMS-185 / IOP CDVD `TocEntryCopy` writes the string terminator at the disc-supplied filename length, past its 129-byte field / Category 6

- **Category:** 6
- **Locations:** `iop/SMSCDVD/SMSCDVD.c:1062-1095` (copy at :1087, terminator write at :1091, length source at :1085); field `iop/SMSCDVD/SMSCDVD.h:96`.
- **Problem:** the non-Joliet branch copies with `strncpy(apTocEntry->m_Filename, apIntTocEntry->m_Filename, 128)` but then unconditionally executes `apTocEntry->m_Filename[lFNameLen] = 0;`, where `lFNameLen = apIntTocEntry->m_FilenameLength` is an unsigned byte read straight from the disc's directory record — up to 255. `TocEntry.m_Filename` is `char[129]` in a 144-byte packed struct, so a crafted ISO9660 record with a filename-length byte of 130–255 writes a zero byte up to ~126 bytes past the field, into whatever follows the `TocEntry` on the caller's frame (callers include `FindPath`'s `localTocEntry` at SMSCDVD.c:746 and the search helpers at :537/:575, which run for ordinary directory scans — no name match required). The Joliet branch is safe by construction (`lFNameLen/2 ≤ 127` at :1077). Distinct from, and more directly disc-reachable than, SMS-049's append mechanism in the same file.
- **Confidence:** High (READ — sites re-opened by batch B during the SMS-049 derivation)

*(Source: full verification of SMS, Sable-VERIFY2-SMS.md §10 — found while re-deriving SMS-049.)*

### SMS-186 / AVI `_Load_idx1` publishes an unchecked `SMS_Realloc` result — the SMS-054 pattern in the function SMS-054 cited as the good example / Category 6

- **Category:** 6
- **Locations:** `src/SMS_ContainerAVI.c:169-176`; helper `src/SMS_EE.c:45-53`.
- **Problem:** `_Load_idx1` calls `SMS_Realloc(lpStm->m_pIdx, (unsigned int *)(&lpStm->m_IdxAllocSize), (lpStm->m_nIdx + 1) * sizeof(_AVIdxEntry))`, assigns the result straight to `lpStm->m_pIdx` at :174, and dereferences it at :176. Unlike MOV's `_add_idx_entry`, it passes the live `m_IdxAllocSize` field directly to `SMS_Realloc`, which enlarges `*apSize` before calling `realloc` (SMS_EE.c:49-51); on allocation failure the stream is left with `m_pIdx == NULL`, an already-inflated alloc size, and an immediate NULL write — on the ordinary `idx1` path (whose entry count *is* file-clamped at :134-136), needing only heap pressure rather than a lying count.
- **Confidence:** High (READ)

*(Source: full verification of SMS, Sable-VERIFY2-SMS.md §10.)*

### SMS-187 / `SMS_ListPushBack(...)->m_Param` unchecked dereferences at 14 further sites beyond SMS-068's filed list / Category 6

- **Category:** 6
- **Locations:** `src/SMS_Config.c:366`, `src/SMS_ContainerM3U.c:317,394,433`, `src/SMS_FileDir.c:311,340,392,437,453,519,593`, `src/SMS_GUIFileCtxMenu.c:394`, `src/SMS_GUISMBrowser.c:563,571`, `src/SMS_List.c:325`.
- **Problem:** SMS-068's site list (as revised, 12 sites) is complete for the files it enumerates, but the identical pattern — dereferencing `SMS_ListPushBack`'s documented NULL-on-failure return (`src/SMS_List.c:36-41`) with no NULL test — occurs at these 14 additional sites, each the same one-line NULL write on node-calloc failure. Recorded as unlisted-by-SMS-068; batch C did not exhaustively cross-check whether any other round mentions individual sites. The parent may merge this into SMS-068 as a site-list completion or file it standalone.
- **Confidence:** High (READ — grep-verified at the pin, pattern-identical)

*(Source: full verification of SMS, Sable-VERIFY2-SMS.md §10 — companion to SMS-068.)*

### SMS-188 / `_sb_string_width` iterates one element past the string end into the unchecked glyph-width helper / Category 6

- **Category:** 6
- **Locations:** `src/SMS_SubtitleContext.c:104,108,121`; helper `include/SMS_GS.h:1307-1309`.
- **Problem:** `_sb_string_width` loops `while (apStr <= lpEnd)` where `lpEnd = apStr + aLen`, while both renderers in the same file use `while (apStr < lpEnd)`. The extra iteration reads the byte at `lpEnd` — for NUL-terminated subtitle lines, `'\0'` — maps it through `lChr -= ' '` to `(unsigned char)(-32) = 224`, and passes it to `GSFont_CharWidth(lpHdr, 224)`, which reads `(apHdr+11)[aChr]` with no bound check against the 96-glyph ASCII header — the same unchecked-index family as SMS-059, reached here by the loop bound itself rather than a crafted byte, adding one garbage glyph width to every SB-mode width computation. (The MB twin at :190 also uses `<=`, but its terminator iteration resolves to glyph index 0 and is not claimed.)
- **Confidence:** High (READ)

*(Source: full verification of SMS, Sable-VERIFY2-SMS.md §10.)*

### PS2SERVERS-116 / HTTP server is not standalone either, and its launcher import is unconditional

- **Locations:** `http_server/http_server.py:47`.
- **Problem:** HTTP server is not standalone either, and its launcher import is unconditional: `http_server/http_server.py:47` executes `from launcher import session_stats` at import time. Executed: a copy of `http_server.py` outside the tree dies on `--help` with `ModuleNotFoundError: No module named 'launcher'` before argparse runs, whereas a standalone `smbserver_opl.py` prints help fine (SMB1/SMB2 touch `launcher.session_stats` only lazily, inside `main()`). Same layering family as PS2SERVERS-038, worse in kind: mode-gated there, unconditional here. Whether standalone redistribution of the HTTP server is a supported use is the owner's call.

*(Source: full verification of PS2-Servers, Sable-VERIFY2-PS2SERVERS.md §7 — filed during the PS2SERVERS-038 derivation. The source states no Category/Effort/Risk/Confidence fields for this candidate; none are inferred here.)*

### PS2SERVERS-117 / The achievements-engine CI step's fixed module list omits `tests.test_ra_credentials`

- **Locations:** `.github/workflows/ci.yml:38-39`; the discovery job at `ci.yml:97`.
- **Problem:** The achievements-engine step at ci.yml:38-39 is named "Exercise native discovery, credential protection and companion wire protocols", but its fixed module list omits `tests.test_ra_credentials` — the dedicated credential-store test module — which therefore receives CI coverage only incidentally via the Ubuntu discovery job (ci.yml:97). No failure results today (discovery does run it, on Linux, where its POSIX test is live), but the named job's list and the module's actual coverage have drifted apart.

*(Source: full verification of PS2-Servers, Sable-VERIFY2-PS2SERVERS.md §7 — filed during the PS2SERVERS-093 derivation. The source states no Category/Effort/Risk/Confidence fields for this candidate; none are inferred here.)*

### PS2SERVERS-118 / Blanket `# noqa: F401` at test_smb2_libsmb2_compat.py:26 hides the one genuinely dead import

- **Locations:** `tests/test_smb2_libsmb2_compat.py:26`.
- **Problem:** `tests/test_smb2_libsmb2_compat.py:26` carries a blanket `# noqa: F401` on an import whose names are in fact used in-file except `Client`; the blanket suppression is what lets the one genuinely dead name (PS2SERVERS-112) hide. Narrowing or dropping the suppression (all remaining names are used) would let a linter catch the next dead import at this site.

*(Source: full verification of PS2-Servers, Sable-VERIFY2-PS2SERVERS.md §7 — filed during the PS2SERVERS-112 derivation. The source states no Category/Effort/Risk/Confidence fields for this candidate; none are inferred here.)*

### X-58 / RiptOPL's PC-tool CRC-32 copies retain the signed-byte negative-index read the EE copy fixed / Category 6

- **Category:** 6
- **Locations:** RiptOPL `tools/pc/iso2opl/src/iso2opl.c:48-70` and `tools/pc/opl2iso/src/opl2iso.c:43-65`; the fixed sibling at RiptOPL EE `system.cpp:470-471` (comment + `unsigned char byte`).
- **Problem:** Both PC copies declare `int byte` and assign from a `const char *`; on signed-char platforms, bytes ≥ 0x80 sign-extend, making `crctab[byte ^ ((crc >> 24) & 0xFF)]` a negative, out-of-bounds index. The EE copy's own comment describes exactly this defect and its fix, which was never ported to either PC copy (surfaced by X-28's verification; distinct defect from X-28's duplication claim).
- **Fix:** Port the EE fix — make the byte variable unsigned in both PC copies (2 one-word changes).
- **Benefit:** Removes an out-of-bounds read on attacker-influenced input (image filenames/contents) in two shipped host tools.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — both PC sites and the EE comment/fix line-read during verification)

*(Source: full verification of the cross-repo set, Sable-VERIFY2-CROSS.md — surfaced by X-28's verification.)*

### X-59 / RiptOPL's BDMAssault PROVENANCE.md omits the .udpfs pair it ships / Category 7

- **Category:** 7
- **Locations:** RiptOPL `modules/bdmassault/PROVENANCE.md` (the 9-row table, verified 9/9 accurate); the pair ships at RiptOPL `ship/POPS/` and is embedded via `src/sources/vcdsupport.cpp`; hashes already recorded in POPSLoader `docs/third_party/okeanos_udpfs/PROVENANCE.json:12,17`.
- **Problem:** The surviving residue of the refuted X-57: RiptOPL's own provenance document — otherwise complete and accurate — has no rows for `usbd.irx.udpfs` / `usbhdfsd.irx.udpfs`, and the `usbhdfsd.irx.udpfs` ≡ `usbhdfsd.irx.usbexfat` dedupe is nowhere stated in words in RiptOPL.
- **Fix:** Add the two rows (hashes from POPSLoader's PROVENANCE.json) plus one sentence stating the dedupe.
- **Benefit:** RiptOPL's provenance record becomes complete for the binaries it ships.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

*(Source: full verification of the cross-repo set, Sable-VERIFY2-CROSS.md — the surviving residue of the refuted X-57.)*
