# FULL-VERIFICATION Phase 2 — RiptOPL — Worker W1

- **Worker:** W1 (adversarial verification; stance: refute unless the code at the pin proves the finding)
- **Repo / clone:** `~/workspace/audit-clones-2026-11-13/RiptOPL` (read-only, no edits)
- **Pin:** `2e347d5ac885cd0ff73e9ad4143781946396f492` (rebuild/main)
- **HEAD verified:** `git rev-parse HEAD` = `2e347d5ac885cd0ff73e9ad4143781946396f492` at start and at end; `git status --porcelain` empty at end.
- **Findings assigned:** 49 — RIPTOPL-001–015, 017–036 (from `Sable-RiptOPL.md`) and RIPTOPL-038–051 (from `Sable-RiptOPL-ROUND2.md`). RIPTOPL-016 and RIPTOPL-037 were not assigned to W1.
- **Revised findings verified in their narrowed form, per instructions:** RIPTOPL-008 (REVISED R2), RIPTOPL-021 (REVISED R2), RIPTOPL-026 (REVISED R5), RIPTOPL-044 (REVISED R4).
- **Note on drift baseline:** pass-1 findings were filed at the older pin `677812185ac5…`; small count/line drift at the phase-2 pin is recorded as VERIFIED-DRIFT, not treated as refutation.

## Verdict table (49 rows)

| ID | Verdict | One-line basis (path:lines or measurement) |
|---|---|---|
| RIPTOPL-001 | WEAKENED | Total exact (53,655,730 B tracked in docs/assets) but the two sets are different themes' footage, not duplicates — see reasoning |
| RIPTOPL-002 | VERIFIED | ship/Example = 137 tracked files, 5,918,101 B; `ship/POPS/PATCH_5.BIN` byte-identical to Example copy; package_release_app.py:4,24 consumes it |
| RIPTOPL-003 | VERIFIED-DRIFT | Makefile still unbuildable per flavours.yml, but 1,260 lines (not 1,251) and CI comment at flavours.yml:401 (not :399) |
| RIPTOPL-004 | VERIFIED-DRIFT | Branch sprawl worse: 277 remote branches (not 273), 227 `claude/*` (not 225), 5 tags — `git branch -r` in clone |
| RIPTOPL-005 | VERIFIED-DRIFT | Now 278 test_*.py (not 277); 266 use `read_text`, 692 read_text call sites, ~62,272 lines in .github/scripts/*.py |
| RIPTOPL-006 | VERIFIED | tools/build_edition.py:114,137 both append `"sources": ["third_party/mbedtls/library/*.c"]`; 109 library/*.c files, tree 7,658,231 B |
| RIPTOPL-007 | VERIFIED | build_edition.py:18 = 4 editions + 2 lite meta-editions; build_configuration.py CONFIGURATIONS = 15; lite_devices.py DEVICES = 8 devices × plain/RA |
| RIPTOPL-008 | VERIFIED | REVISED claim holds: udpfs_bd/fhi/ioman `src/udpfs_core.c` are 2-line `#include "../../udpfs_shared/src/udpfs_core.c"` shims (identical MD5); the headers (udpfs_core.h, udpfs_packet.h, udprdma.h, udprdma_packet.h, udprdma_seq.h, irx_imports.h) are MD5-identical in all three dirs |
| RIPTOPL-009 | VERIFIED-DRIFT | 12 workflows, 2,222 total lines (not 2,220); flavours.yml 495 lines (not 493); six scheduled (ember */6h, neutrino + orbit same cron `41 5 1,11,21 * *`, sdk weekly, docs-sync daily, wiki-publish daily) |
| RIPTOPL-010 | VERIFIED | 13 tracked POPSTARTER paths; 5 variants (MAIN, DEBUG, USBDELAY, USBDELAY_DEBUG, USBDELAY_LONGER_DEBUG — 3 debug) + default POPSTARTER.ELF, duplicated under ship/Example |
| RIPTOPL-011 | VERIFIED | tools/assets.py:46 PNG_ASSETS = 104 names + 24 glyph PNGs at :59 = 128 embedded; gfx/ = 142 files, 443,330 B; glyph sets consumed at src/gfx/themes.cpp:1185ff |
| RIPTOPL-012 | VERIFIED | modules/bdm/bdmfs_fatfs/fatfs/ffunicode.c = 15,593 lines / 1,959,402 B; ffconf.h:87 `FF_CODE_PAGE 869`; ps2.yaml:310 compiles ffunicode.c; ff.c:796,878 pass runtime CODEPAGE |
| RIPTOPL-013 | VERIFIED | src/sources/vcdsupport.cpp:2206,2287 `"%s.bak"`, :2326 "retain .bak"; include/vmcrebuild.h:5,12; src/sources/vmcrebuild.cpp:124,173 |
| RIPTOPL-014 | VERIFIED | sysneutrino.cpp:384,639 `static char toml[4096]` ×2; achievements.cpp:512 `doc[2048]`, :677 `response[1024]`; fntsys.cpp:744 `shaped[2048]`, :1219 `joined[2048]`; include/ranet.h:89 `rx_[2048]` |
| RIPTOPL-015 | VERIFIED | src/platform/util.cpp:873 `malloc(strlen(folder)+strlen(dirent->d_name)+2)` unchecked, :874 `sprintf(path,…)` immediately after; neighbouring allocations at :885ff/:913 are checked |
| RIPTOPL-017 | VERIFIED | src/core/OSDHistory.cpp:41,76,91,106 unbounded `sprintf` into `fullpath[64]`; :153 `sprintf` into `path[32]` — all five sites exact at pin |
| RIPTOPL-018 | VERIFIED | `strcpy(filename, game->startup);` at exactly the six cited sites: bdmlaunch.cpp:904, ethsupport.cpp:1504, hddsupport.cpp:2787, mmcesupport.cpp:1556, udpfssupport.cpp:977,1134 |
| RIPTOPL-019 | WEAKENED | Probe exists (supportbase.cpp:397) but fires only for non-ISO entries when folder browsing is on — see reasoning |
| RIPTOPL-020 | VERIFIED | config.cpp:82 dual-syntax (wOPL/libconfig) read; per-game key table at :918ff (function :961); relocation map comment :1256ff / function :1278ff; favsupport.cpp:162-163 32-byte wOPL favourites reader, :335 FAV_FILE_MAX using it |
| RIPTOPL-021 | VERIFIED | REVISED/driver claim holds: modules/ilink/iLinkman/src/iLink.c 365 lines vs modules/bdmassault/ilink_bd_assault/src/iLinkman/src/iLink.c 369 lines, `!!HACK!!` S100 at :351/:355, `diff` confirms divergence (include path, BD_iLink_start call, formatting); whole-tree expansion is RIPTOPL-047 |
| RIPTOPL-022 | VERIFIED | third_party/korium/assets.zip = 579,186 B; tools/assets.py:141ff opens zip, SHA-256-verifies per UPSTREAM.json, extracts to build/theme-assets/korium |
| RIPTOPL-023 | VERIFIED | AGENTS.md and CLAUDE.md MD5-identical (`f93ecc98…`), 15 lines each |
| RIPTOPL-024 | VERIFIED | audio/bgm.ogg = 324,182 B, Makefile comment (~:182) "intentionally NOT compiled… kept only as a reference/default track"; ship/Example copy = 369,632 B, different file |
| RIPTOPL-025 | VERIFIED-DRIFT | docs/ = 159 files but 71 Markdown (not 70) and ~64.4 MB tracked (not ~62 MB); cited checkpoint/plan files all present (MIGRATION-CHECKPOINT-2026-10-12.md = 63,589 B) plus community-report-evidence/ PNGs |
| RIPTOPL-026 | VERIFIED | REVISED remainder holds: publish_llvm.py:17-18 now imports publish_editions (`as common`) + publish_lite plumbing, but release-notes construction and SHA256SUMS parsing remain triplicated in the three verify() functions — publish_editions.py:195,325; publish_llvm.py:97,137; publish_lite.py:140,155 |
| RIPTOPL-027 | VERIFIED | tools/lite_devices.py:49-51 ALWAYS frozenset includes `"lwnbdsvr"`, `"ata_bd"` for every device; ps2.yaml:210 lwnbdsvr target; src/app/lwnbdctl.cpp exists |
| RIPTOPL-028 | VERIFIED | src/sources/httpsupport.cpp 924 lines, src/platform/httpcatalog.cpp 265, src/platform/httpclient.cpp 161 (=1,350); `http_cdvdman` target at ps2.yaml:447 |
| RIPTOPL-029 | WEAKENED | Plasma runs per frame, but it is a 32×32 texture refreshed 6 rows/frame, not a full-screen per-pixel effect — see reasoning |
| RIPTOPL-030 | VERIFIED | All eight line counts exact: guisettings.cpp 3,497; menusys.cpp 3,400; hddsupport.cpp 3,383; vcdsupport.cpp 3,259; supportbase.cpp 3,181; settingsio.cpp 2,611; dialogs.cpp 2,409; bdmsupport.cpp 2,408 |
| RIPTOPL-031 | WEAKENED | Two stub trees and duplicate names hold, but sdk_stub has 23 files of which 19 are the identical empty stub (not 20) — see reasoning |
| RIPTOPL-032 | WEAKENED | Four prebuilt .irx tracked with no source and no ps2.yaml rule, but the legacy Makefile does contain embedding rules for them — see reasoning |
| RIPTOPL-033 | VERIFIED-DRIFT | Language list duplicated at Makefile:191 and tools/assets.py:42, but it is 33 languages (not 35) and lng/fork/ holds 33 .yml files (not 35); assets.py:98ff downloads lng_src at build time |
| RIPTOPL-034 | VERIFIED | `#if 0` at modules/hdd/apa/src/cache.c:55, modules/mmce/mmceman/src/sio2man_hook.c:26, modules/usb/usbd-ra/src/usbd.c:200; FIXME config.cpp:17; HACK src/core/bgm.cpp:890; no-op `\|= 0 /* TODO! fake ilinkman ? */` at bdmlaunch.cpp:983 |
| RIPTOPL-035 | VERIFIED | README.md = 1,116 lines, CHANGELOG = 340 lines, ROLLING_RELEASE.md exists; GSM 1080p prose at README.md:443 duplicates docs/GSM.md |
| RIPTOPL-036 | VERIFIED | src/app/opl.cpp:1929 `char diagnostic[1536]`, :1951 `DelayThread(8000000);` (8 s), gated by `#ifdef __OPLDIAG`, after drawing for 2 frames |
| RIPTOPL-038 | VERIFIED | smbman-ra/smb.c:336-352 getStringField passes server `FileNameLen` (smb.c:1498) unbounded into strncpy + `out[inbytes]='\0'`; utf16ToAscii :288-318 likewise unbounded; :404 second call site with inbytes==0; SearchInfo_t flexible FileName at smb.h:310-314; 4,096-B SearchBuf at smb_fio.c:88,694 |
| RIPTOPL-039 | VERIFIED | mmce_cmds.c:195-225 get: `strcpy(ptr, &rdbuf[4])` from 255-B rdbuf, buflen never forwarded from mmce_fs.c devctl (:1123); :226ff set: `u8 len = strlen(ptr)+1` (mod-256 truncation) then `strcpy(&wrbuf[4], ptr)` into `u8 wrbuf[0xFF]` |
| RIPTOPL-040 | WEAKENED | Core dopen strcat overflow stands, but the unterminated/wild-scan mechanism is narrower than filed — see reasoning |
| RIPTOPL-041 | VERIFIED-DRIFT | Defect exact, citations moved: the `.PSS` suffix test is at modules/iopcore/cdvdman/searchfile.c:215-219 (not :231-235) — `&cdvdman_filepath[strlen(cdvdman_filepath)-6]` with no length ≥6 guard |
| RIPTOPL-042 | VERIFIED | hdd_fio.c:995-997 HIOCGETSIZE and :1015-1017 HIOCGETPARTSTART both `fileSlot->parts[*(u32 *)argp]` unchecked; APA_SUPPORT_IOCTL_GETPARTSTART=1 at apa-opt.h:13; parts[APA_MAXSUB+1] (APA_MAXSUB 64, atad.h:61) |
| RIPTOPL-043 | VERIFIED-DRIFT | Defect holds, citations moved: `_recv_with_result` at udpfs_shared/src/udpfs_core.c:89ff returns `result.result` unclamped to the requested size; caller `udpfs_core_read` at :387-430 (not :471-505) advances buffer/total by it |
| RIPTOPL-044 | VERIFIED | REVISED (core-side only): udpfs_core_dread (udpfs_shared/src/udpfs_core.c:506ff) checks `reply->name_len < name_max` but never against the received length returned by `_request` (ret ignored beyond <0) or g_rx_buf[312] at :35; copy source stays inside g_rx_buf, so stale-byte copy only, as filed. The udpfs_ioman.c:347 call site is cleared per R4 and was not counted against this verdict |
| RIPTOPL-045 | VERIFIED | modules/iopcore/cdvdman/streaming.c:234 `while (sceSifDmaStat(dmat_id) >= 0) {};` empty spin, directly below the sceSifSetDma loop (:215-232) rewritten to DelayThread(500)-yield with explanatory comment |
| RIPTOPL-046 | VERIFIED-DRIFT | Two SMB1 stacks hold (cdvdman/smb.c 1,177 lines; smbman-ra/smb.c 1,640 lines; asciiToUtf16 diff = comment spacing only), but my function inventory gives 35 definitions in each with 18 shared names (not 36 / 19) |
| RIPTOPL-047 | VERIFIED | modules/bdmassault/ = 3,955 C/H lines vs modules/ilink/ = 3,970; sbp2_driver.c diff = 68 lines, scsi.c diff = 187 lines; PROVENANCE.md documents the embedded-pair purpose |
| RIPTOPL-048 | VERIFIED-DRIFT | All six headers MD5-identical ×3 with exact line counts (udpfs_packet.h 262, udprdma.h 152, udpfs_core.h 81, udprdma_packet.h 135, udprdma_seq.h 14, irx_imports.h 18); mprintf.h is present in 6 dirs but the smap_udpbd copy is 22 lines / different MD5, the other five are the identical 23-line copy |
| RIPTOPL-049 | VERIFIED | mmce/mmceman/src/sio2man_hook.c 318 lines vs mx4sio_bd/src/sio2man_hook.c 315 lines, diff output = 5 lines (one 3-line `#if 0` block); ioplib.c MD5-identical, 101 lines each |
| RIPTOPL-050 | VERIFIED-DRIFT | Design holds, citations moved: whole-ELF RAM sink in src/ui/selfupdate.cpp — header comment :10-13, `SU_ELF_MAX = 8 MB` at :82 (not ~:90, real ELF ~2.3 MB stated there), malloc of Content-Length at :183 (not :187); file is 424 lines |
| RIPTOPL-051 | REFUTED | The `size <= 0` tests at mcemu.c:845,896 are not dead: on a u32 they are `size == 0` tests and they fire after `size -= csize` — see reasoning |

## Reasoning for every non-VERIFIED verdict

### RIPTOPL-001 — WEAKENED
Re-measured: `git ls-files docs/assets` sums to exactly 53,655,730 bytes, and each tour does exist as both GIF and MP4. But the "four copies of the same footage" framing fails: the plain set and the `incebtion/` set are tours of two different editions/themes. Evidence: `docs/UI-CAPTURES.md:45,49` and `README.md:73-83` label the plain set "Korium" and the `incebtion/` set "IncebtIon"; the two capture-manifest.json files record `"edition": "Korium"` vs `"edition": "IncebtIon"`; MD5s and sizes differ materially (library-tour.gif 5,190,414 B vs 10,935,774 B). Narrower truth: the size cost is real, and GIF+MP4 duplication *within* each theme (2 formats × 2 themes) is real, but deleting the incebtion set would delete the second theme's documentation, not a duplicate. The recoverable saving is roughly one format per theme, not "~35–45 MB".

### RIPTOPL-003 — VERIFIED-DRIFT
Mechanism holds (flavours.yml still says the Makefile cannot build src/; tools/assets.py:2 "ps2build handles all code"; tools/lng_pack.sh still scrapes VERSION/SUBVERSION/PATCHLEVEL/EXTRAVERSION from Makefile lines 1–4; ps2.yaml/build_edition.py are the live definition). Corrected citations: Makefile is now **1,260 lines** (round-2 revalidation already noted this growth), and the CI statement is at **.github/workflows/flavours.yml:401**, not :399.

### RIPTOPL-004 — VERIFIED-DRIFT
Checked from the clone's refs (`git branch -r`): **277** remote branches (round-2 revalidation also counted 277), of which **227** match `claude/`, and **5** tags. The filed 273 / 225 were the pass-1 pin's counts. The claim (mass stale agent-branch sprawl) holds and has grown; only the numbers drifted. Caveat: this is the clone's ref state, not a fresh `git ls-remote`.

### RIPTOPL-005 — VERIFIED-DRIFT
Recounted: 278 `test_*.py` files (was 277; round 2 noted the +1 smb1 test), 286 Python files total in .github/scripts, 266 test files containing `read_text`, 692 `read_text` call sites, ~62,272 lines across .github/scripts/*.py. tools/run_tests.sh runs them serially. Mechanism and proportions hold; the headline count drifted by one file.

### RIPTOPL-009 — VERIFIED-DRIFT
12 workflow files confirmed; total is **2,222 lines** (filed 2,220) and flavours.yml is **495 lines** (filed 493). All six scheduled workflows and both Neutrino watchers on the identical cron (`41 5 1,11,21 * *` at neutrino-watch.yml:26 and orbit-neutrino-watch.yml:18) confirmed. Trivial numeric drift only.

### RIPTOPL-019 — WEAKENED
Read supportbase.cpp:373-410 at the pin. The probe at :397 (`DIR *probe = opendir(fullpath);`) is **not** executed for every entry: it sits inside `if (format <= 0 || NameLen > ISO_GAME_NAME_MAX)` (entry is not a launchable ISO) and inside `if (folderlist != NULL && dirent->d_name[0] != '.')`, with additional length guards. Narrower truth: one extra opendir per *non-ISO candidate entry, only when folder browsing is enabled for that scan* — still a per-entry round-trip on slow/network devices in that mode, but not the unconditional per-entry probe the finding describes, and the fix it proposes (restrict the probe) is already partly implemented via the folderlist gate.

### RIPTOPL-025 — VERIFIED-DRIFT
Inventory holds (159 files under docs/, all cited checkpoint/plan/handoff documents present, community-report-evidence/ holds multi-hundred-KB-to-MB PNGs plus an MP4). Corrections: **71** Markdown files (filed 70) and tracked docs total **64,415,619 B ≈ 64.4 MB** (filed ~62 MB); MIGRATION-CHECKPOINT-2026-10-12.md is 63,589 B (~64 KB as filed).

### RIPTOPL-029 — WEAKENED
Read src/gfx/plasma.cpp in full and include/plasma.h. The header comment (plasma.cpp:1-2) and code contradict the "full-screen per-pixel CPU effect per frame" framing: the plasma is a **32×32** Perlin texture (`kWidth = kHeight = 32`, plasma.h:10-11), and `draw()` (plasma.cpp:207ff) recomputes only **`kRowsPerFrame = 6` rows per frame** — with the in-code comment at :216 "it's kRowsPerFrame rows a frame to stop being a resource hog" — then stretches the texture over the screen. TODOs at :145/:151, the gui.cpp:85/136 (draw at :146) and themeelems.cpp:1302,1333,1724 call sites are as filed. Narrower truth: a bounded ~192-pixel-per-frame CPU cost plus a full-screen textured quad, deliberately throttled — the per-frame full-screen compute cost the benefit estimate rests on does not exist at this pin.

### RIPTOPL-031 — WEAKENED
Listed and hashed tests/host/sdk_stub/: **23 files**, of which **19** share the identical empty-stub MD5 (`b5ad224e…`, content `#pragma once`); the other four (delaythread.h, gsKit.h, hdd-ioctl.h, tamtypes.h) differ. The filed "twenty identical empty SDK stubs" overcounts by one. The rest holds: a second tree tests/host/stub/ exists with duplicated names (tamtypes.h is byte-identical in both trees; kernel.h and ioman.h also appear in both). Narrower truth: 19 identical stubs in a 23-file tree, duplicated-name second tree — the confusion claim stands, the count does not.

### RIPTOPL-032 — WEAKENED
The four binaries (drvtif.irx, drvtif-ingame.irx, tifinet.irx, tifinet-ingame.irx) are tracked in modules/debug/ with no adjacent source, and no ps2.yaml target or tools/*.py reference to them was found — that part holds. But the finding's "no build rule found in this pass" is defeated in part: the legacy **Makefile:1182-1191** contains explicit bin2c rules generating drvtif/tifinet (and ingame) .c files from exactly these .irx files, and Makefile:310,342 adds them to EE/IOP object lists. That Makefile is the dead build definition of RIPTOPL-003, so the binaries are still unexplained inputs for the *live* build — but they are documented build inputs of the legacy build, not wholly rule-less files. (modules/debug/ also now contains deci2.img, a ps2link/ source tree and udptty-ingame/, the latter built by ps2.yaml:130.)

### RIPTOPL-033 — VERIFIED-DRIFT
Duplication confirmed at Makefile:191 and tools/assets.py:42, and assets.py:98ff runs download_lng.sh then compiles each language plus the fork overlay. Counts corrected: the TRANSLATIONS string parses to **33** languages (not 35), and lng/fork/ contains **33** .yml files plus a README (not 35 YAML files).

### RIPTOPL-040 — WEAKENED
Re-derived all three sites in smb_fio.c. What stands: `smb_dopen` (:660-663) does `strncpy(fh->name, path, 255)` into `FHANDLE.name[256]` (smb_fio.c:69,78) then unconditional `strcat(fh->name, "\\")` and `strcat(fh->name, "*")`; prepare_path can legitimately return paths up to ~1,023 chars, so for a ≥255-char directory path the two appends write past name[256] (by up to 2 bytes: the `\` lands at index 255 and its NUL at 256, then `*` at 256 and its NUL at 257). What does **not** stand as filed: the "unterminated name / strlen reads past the field" mechanism. The copy count is 255, so name[255] is never written by the strncpy, and handle slots are zeroed — they are BSS globals and smb_close memsets the FHANDLE (smb_fio.c:390) — so name[255] remains '\0' and strlen is bounded at 255. Likewise `smb_chdir` (:822) copies with `sizeof(smb_curdir)-1` = 1,023, so smb_curdir[1023] is never written and stays '\0' from BSS; the claimed unterminated-curdir cascade into prepare_path (:303) therefore does not occur as described. Narrower truth: a real, path-length-triggered 1–2-byte strcat overflow in smb_dopen only; the chdir/prepare_path unterminated-string chain is defeated by the size-1 copy counts preserving the zeroed last byte.

### RIPTOPL-041 — VERIFIED-DRIFT
Whole-file read of searchfile.c: the defect is exactly as filed — under `IOPCORE_COMPAT_0_SKIP_VIDEOS`, `strncmp(&cdvdman_filepath[strlen(cdvdman_filepath) - 6], ".PSS", 4)` (and ".pss") with no prior length check, so a name shorter than 6 chars wraps the size_t subtraction and reads before the 256-byte static buffer (populated at :191-192). Corrected location: **searchfile.c:215-219**, not :231-235.

### RIPTOPL-043 — VERIFIED-DRIFT
Re-read udpfs_core.c in full: `_recv_with_result` returns `result.result` (server-supplied) after only a `<= 0` check, never clamping to the requested `size`; `udpfs_core_read` then does `total_read += ret; buffer += ret; size -= ret;`, so an over-reporting server desynchronises accounting exactly as filed (the DMA receive itself is bounded by the udprdma call with the requested size, as the finding states). Corrected locations: `_recv_with_result` at **udpfs_core.c:89-~125** (filed :96-139) and `udpfs_core_read` at **:387-430** (filed :471-505). A second caller exists at :678 (block read) with the same exposure.

### RIPTOPL-046 — VERIFIED-DRIFT
Function inventories compared mechanically: my regex inventory finds **35** function definitions in each smb.c (filed 36) with **18** shared names (filed 19) — GetSMBServerReply, OpenTCPSession, RecvData, SendData, asciiToUtf16, nb_GetSessionMessageLength, nb_SetSessionMessage, setStringField, smb_Close, smb_Disconnect, smb_NegotiateProtocol, smb_OpenAndX, smb_ReadAndX, smb_ReadFile, smb_SessionSetupAndX, smb_TreeConnectAndX, smb_WriteAndX, smb_WriteFile. The sampled asciiToUtf16 bodies diff only in comment spacing (`//NULL` vs `// NULL`), as filed. Duplication claim holds; counts off by one each (method-sensitive: prototypes/statics counting).

### RIPTOPL-048 — VERIFIED-DRIFT
All six named headers verified MD5-identical across udpfs_bd/udpfs_fhi/udpfs_ioman with the exact filed line counts, and udpfs_shared/ contains only the shared .c sources (no headers), confirming the headers were never unified. One correction: mprintf.h exists in six include dirs, but the modules/network/smap_udpbd copy is **22 lines with a different MD5**; only the other five (udpfs_bd, udpfs_fhi, udpfs_ioman, udpfs_ministack, udpfs_smap) are the identical 23-line copy.

### RIPTOPL-050 — VERIFIED-DRIFT
Read selfupdate.cpp (424 lines): the design comment at :10-13 states the download is held in RAM and must match SHA-256 before the in-place overwrite; the body sink mallocs the full Content-Length. Corrected citations: `SU_ELF_MAX = 8 * 1024 * 1024` with the "~2.3 MB" comment is at **:82** (filed ~:90), and the allocation is at **:183** (filed :187). The finding's own honest framing (deliberate trade, doing nothing defensible) is accurate.

### RIPTOPL-051 — REFUTED
Read MceRead (mcemu.c:834ff) and MceWrite (:886ff) in full. Both cited lines sit in the same pattern:

```c
u32 csize = (size < 16) ? size : 16;
...
size -= csize;
if (size <= 0)
    return 1;
```

`size` is a `u32` parameter, so `size <= 0` is not "always false" — for an unsigned value it is exactly the `size == 0` test, and it is reachable and functional: `csize` is clamped to `size`, so whenever the card-offset chunk consumes the remaining bytes (any remaining size ≤ 16 in this branch), `size` becomes 0 and the guard returns 1, correctly ending the transfer. The finding's own suggested alternative ("test for equality with zero, which is the only case the current code could ever have meant") is semantically what the current code already does. The compiler may warn about the comparison, but the guard is live, not dead. Defeating evidence: modules/mcemu/mcemu.c:845 and :896 in the context above.

## Incidental new defects (candidates — coordinator assigns numbers)

### CANDIDATE-W1-1 — smb_open stores an unterminated name with a full-size strncpy count (smb_fio.c:361)
In `smb_open` (modules/network/smbman-ra/smb_fio.c:361): `strncpy(fh->name, path, SMB_NAME_MAX);` where `SMB_NAME_MAX` is 256 (smb_fio.c:69) and `FHANDLE.name` is `char name[SMB_NAME_MAX]` (:78) — the copy count equals the full field size, unlike the dopen site in RIPTOPL-040 (count 255), so a path of ≥256 chars (prepare_path can produce up to ~1,023) leaves fh->name with no NUL terminator anywhere in the field. Impact is currently latent: grep shows fh->name is only *read* for directory handles (smb_fio.c:697, set by smb_dopen), not for open-file handles, so no live over-read was demonstrated. Filed because it is a distinct site not cited by RIPTOPL-040 and the same one-line pattern fix applies. (A similar count-equals-size copy exists at smb_fio.c:714, `strncpy(dirent->name, info->FileName, SMB_NAME_MAX)`, bounded in practice by the getStringField termination in the SearchBuf.)

---

*End of W1 report. Tallies from this file: VERIFIED 31, VERIFIED-DRIFT 11, WEAKENED 6, REFUTED 1 — total 49 rows. Candidates filed: 1 (CANDIDATE-W1-1).*
