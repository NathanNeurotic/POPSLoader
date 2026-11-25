# Sable — FULL-VERIFICATION (Phase 2): POPSLoader

**Date:** 2026-11-14 · **Pin:** `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (master) — clone HEAD verified at start by every worker and re-verified at end by the coordinator; clone read-only throughout, git-clean at end.
**Stance:** adversarial. Every finding was re-derived from the code at the pin with the aim of refuting it; a finding survives only where the code proves it.
**Worker sections (full text, verbatim):** `verify2-sections/verify2-pops-A.md` (001–013), `verify2-pops-B.md` (014–030), `verify2-pops-C.md` (031–047), `verify2-pops-D.md` (049–065, 067–070).

## 1. Scope — derivation and exclusions

POPSLoader has 108 numbered findings (001–108), all STANDING or REVISED (there are no CROSS-REF or WITHDRAWN POPSLoader items). Phase 1 (`Sable-VERIFY-OTHERS-CAT6.md`) already re-derived 39 of them; this pass covers the remainder.

**In scope: 68 findings** — POPSLOADER-001…047, 049…065, 067…070 (63 STANDING + 5 REVISED: 006, 010, 011, 016, 033; REVISED items were verified against their §4-narrowed versions in `Sable-MASTER-INDEX.md`).

**Exclusions (40), explicitly:**
- Phase-1 verified (§3(b) Cat-6 members): POPSLOADER-048, POPSLOADER-066.
- Phase-1 verified (full BDMAssault tarball set): POPSLOADER-071, 072, 073, 074, 075, 076, 077, 078, 079, 080, 081, 082, 083, 084, 085, 086, 087, 088, 089, 090, 091, 092, 093, 094, 095, 096, 097, 098, 099, 100, 101, 102, 103, 104, 105, 106, 107.
- POPSLOADER-108 (verified at filing in phase 1).

**Tarball:** `/tmp/bdma7` no longer existed; the coordinator re-extracted the in-repo tarball (`iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz`, md5 `09ff4b911ba131468a25d0ec9a4e2f27` — matches the expected `09ff4b91…`; 119 files) to `/tmp/bdma7v2/` and byte-checked it before any worker relied on it.

## 2. Verdict totals — counted from §3's table in this file

**Counting method:** the 68 rows of §3 were extracted programmatically from the four worker section tables, sorted, and counted in the finished deliverable (script count over the table rows, reproduced at the end of this file's build). No worker's self-reported total was used.

| Verdict | Count |
|---|---|
| VERIFIED | 50 |
| VERIFIED (narrowed — REVISED items whose §4 version holds exactly) | 2 |
| VERIFIED-DRIFT | 10 |
| WEAKENED | 6 |
| REFUTED | 0 |
| **Total** | **68** |

**REFUTED: none.** Six findings survive only in narrower form (§4). Ten have citation-level drift with mechanisms intact. POPSLOADER-016 and -033 are counted separately above: their narrowed §4 versions hold exactly; their original texts overstate (reasoning in §4). POPSLOADER-067 was upgraded from INFERRED to executed during this pass (worker D ran the Makefile rule against a stub PS2SDK: the rule invokes a sub-make on a directory, reports "Nothing to be done", exits 0, and produces no loader.elf — full PS2SDK build not run).

**Coordinator spot-checks (personally re-derived, not worker-relayed):**
- **POPSLOADER-006 ffunicode figures:** recomputed from the extracted bytes — ffunicode.c 1,959,389 B + bdmfs_ffunicode.c 1,959,397 B = 3,918,786 B of a 4,951,196 B tree = **79.15%**; redundant copy **39.57%**. Exactly the filed figures.
- **POPSLOADER-041 (WEAKENED):** read both walks directly — `do { … endpoint += endpoint->bLength; } while (epCount--);` at ds34usb.c:138–154 and ds34bt.c:121–142: count-bounded, so a zero `bLength` stalls but terminates (the filed infinite-loop mechanism is refuted); `epCount = interface->bNumEndpoints - 1` (ds34usb.c:132 DS3 branch, ds34bt.c:117) underflows to −1 at `bNumEndpoints == 0`, and `while (epCount--)` then never evaluates 0 — the real non-termination path, exactly as worker C corrected it.
- **POPSLOADER-002 (WEAKENED):** read `src/embed_assets.cpp:149–153, 210` directly — the file's own comment states `usbd.irx.mx4sio` aliases the usbexfat blob "to save ~48KB in the ELF"; the claimed duplicate embed for that pair no longer exists.

## 3. Verdict table (68 rows, extracted from the worker sections)

| ID | Verdict | Evidence (one line; full trail in the section file) |
|---|---|---|
| POPSLOADER-001 | VERIFIED-DRIFT | Re-measured via `git ls-files`+`stat`: `.research/` = 312 files / 21,197,583 B of 609 files / 30,417,169 B total, assets 124 files / 8,659,452 B, largest files exact — but zip+7z archives are 22, not 24 (see § below) |
| POPSLOADER-002 | WEAKENED | md5s all exact (`usbd` ×3 `a77650a0…` 48,500 B; `usbhdfsd` udpfs=usbexfat `ad9640d4…` 34,508 B), but `usbd.irx.mx4sio` is already aliased, not embedded — `src/embed_assets.cpp:149-153,210` — remaining saving is 83,008 B, not 131,508 B (see § below) |
| POPSLOADER-003 | VERIFIED | `bin/POPSLDR/system.lua` 11,784 lines / 571,596 B; registry at :2558-2561, `PLDR.I18N` at :2568 with 7 tables FR :2569, DE :2876, PT :3184, ES :3492, IT :3799, HU :4107, SK :4432 (block 2,276 lines / 172,314 B measured), EN fallback `PLDR.L` at :4844-4855, minified embed `Makefile:203-215`; TSVs in `docs/translations/` are 410 lines each |
| POPSLOADER-004 | VERIFIED | `md5sum` all six pairs `POPSTARTER/*.irx` vs `bin/POPSLDR/popsmb/*.irx` identical (e.g. `ps2ip.irx` 109,497 B `525acea7…` in both); one set = 182,654 B, both = 365,308 B; `del.icn`/`list.icn` also md5-identical to `del.icn.bdma`/`list.icn.bdma` |
| POPSLOADER-005 | VERIFIED | Five `POPSTARTER.ELF` at 167,700 B each (838,500 B total); top-level and `PROFILES/DEBUG` both md5 `bbc61fa490df65d9527fcea7c4118170`, other three profiles all differ |
| POPSLOADER-006 | VERIFIED | Narrowed (REV-006/R7-REV-006) claim holds: tarball 1,466,084 B, md5 `09ff4b911ba131468a25d0ec9a4e2f27`, filename referenced by no Makefile/source/workflow (grep = 0); it pins the `bdm_assault`/`usbd.irx` half (`__bdm_assault/Makefile:2` builds `bdm_assault.irx`; `usbd.irx` strings show BDM), while shipped `usbhdfsd.irx` (14,993 B) strings are `MX4SIO v1.2`/`sio2man`/`mx4sio` with no MX4SIO source anywhere in the extracted tree. ffunicode recomputed from `/tmp/bdma7v2` bytes: 1,959,389 B + 1,959,397 B = 3,918,786 B = 79.15% of the 4,951,196 B extracted tree (119 files); redundant single copy = 39.57% — exactly the filed Round-3/Round-7 figures (copies differ only at line 26, `#include "ff.h"` vs `"include/ff.h"`) |
| POPSLOADER-007 | WEAKENED | Both copies exist, but only 25 of the 67 IMG PNGs are embedded: embedded subset = 243,578 B, the other 42 PNGs (87,097 B) are loose-only — the ~330,675 B upper bound overstates the duplication (see § below) |
| POPSLOADER-008 | VERIFIED | Re-read `bin/POPSLDR/system.lua:5234` `PromoteTmpToDest` (dest→`.bak` copy, tmp→dest copy, delete `.bak`, with the Codex F1 2026-06-20 rationale in comments) called by `WriteAtomic` at :5261 — write-tmp + two `System.rename` copies per save as filed (filed :5233-5260/:5262-… within one line) |
| POPSLOADER-009 | VERIFIED | `src/graphics.cpp`: `calloc(height, sizeof(png_bytep))` at :172, :217, :267 with per-row `malloc(row_bytes)` and `png_read_image` at :179, :224, :274 — three copies of the block inside the filed ranges :172-186/:217-231/:267-281 |
| POPSLOADER-010 | VERIFIED-DRIFT | Revised claim (pademu = semantic fork) holds: line counts exact (1,719/806/1,521/634 = 4,680), `MAX_PADS` 4 in `modules/pademu/ds34bt.c:341` vs 2 in `modules/ds34bt/iop/ds34bt.c:346`, diff output 512 lines; support files identical — but the two module Makefiles are NOT identical (see § below) |
| POPSLOADER-011 | VERIFIED | Revised rationale (R7-REV-011) holds: `src/elf_loader/loader.c` = 855,821 B / 8,740 lines, header `size_loader_elf = 139700`, generated by `src/elf_loader/Makefile:30-33`; CI cannot compare the committed dump — `compilation.yml` Compile step (`make clean elfloader all`) regenerates+`touch`es `loader.c` before the Verify step at :192-203, whose `-nt` gate/`cmp` therefore compares regenerated artefacts, and no workflow does `git show`/`git diff` on `loader.c` |
| POPSLOADER-012 | VERIFIED-DRIFT | All counts exact: 10 workflows, `wc -l` total 2,062, every per-file line count as filed; `retract-mislabeled-ember-beta.yml` is 40 lines and self-describes as one-shot — but its trigger is path-filtered to itself, not every push (see § below) |
| POPSLOADER-013 | VERIFIED | `.github/workflows/opencode.yml` = 32 lines, triggers on issue/PR comments containing `/oc` or `/opencode`, job permissions include `id-token: write`, runs `anomalyco/opencode/github@latest` — as filed; the finding itself hedges non-use as unverified |
| POPSLOADER-014 | VERIFIED-DRIFT | All named branches and all 37 tags present at the pin; branch/claude counts drifted (see §2) |
| POPSLOADER-015 | VERIFIED-DRIFT | 4,896 total lines, md5 duplicate pair and docs/ audit files exact; root count is 17 MD files, not 18 (see §2) |
| POPSLOADER-016 | VERIFIED (narrowed) | Narrowed claim exact: 5 unwired scripts = 547 lines (79+111+104+185+68); 12 files CI-wired incl. `test_cursor_orbs.cjs` (see §2) |
| POPSLOADER-017 | VERIFIED | `src/luasystem.cpp:35` `#define MAX_DIR_FILES 512`; stack array `mcEntries[MAX_DIR_FILES]` at `:721`, used in `mcGetDir(..., MAX_DIR_FILES, mcEntries)` at `:735`; 4,096 B thread stack at `src/luagraphics.cpp:26` |
| POPSLOADER-018 | VERIFIED | `SmbWaitNetState` 30×`sleep(1)` loop at `src/luasystem.cpp:2095–2104`, called only from the Lua binding `lua_smb_netup` (`:2306`, calls at `:2332/:2334/:2347`); sibling `sleep(1)` at `:185`, `:1746`, `:1754`, `src/luaHDD.cpp:93`; bounded 10 ms poll contrast at `:1940–1955` |
| POPSLOADER-019 | VERIFIED | Two `static char launch_arg_storage[2048]` in `src/elf_loader/src/elf.c` — `:404` in `ExecuteViaEmbeddedLoader` (def `:397`) and `:487` in `LoadELFFromFileWithPartition` (def `:481`), both driving the shared `store_arg` at `:83`; file is 731 lines |
| POPSLOADER-020 | VERIFIED | `src/luagraphics.cpp:276` `malloc(16)`, `:278` `sprintf(buffer, "%i", (int)image)`, result published via `imgThreadData` at `:279`; `snprintf` precedent exists in `src/luasystem.cpp` (e.g. `:621`) |
| POPSLOADER-021 | VERIFIED | Unchecked `getcwd(path, 256)` at `src/luasystem.cpp:600` (pushed to Lua at `:601`) and `:681` in `lua_dir`; checked sites in the same file at `:629–630` and `:646–647` raise Lua errors |
| POPSLOADER-022 | VERIFIED | `docs/translations/slovak.tsv` = 410 lines; `slovak.xlsx` present (21,606 B); `tools/translation_handoff.py` (250 lines) reads TSV template at `:176` and XLSX as second source at `:202–212` (`read_xlsx` at `:207`) |
| POPSLOADER-023 | VERIFIED | `pcall` line counts exact: 256 lines in `bin/POPSLDR/system.lua` + 114 in `bin/POPSLDR/ui.lua` = 370 sites; representative `type(...)==...` + `pcall` pattern confirmed at `system.lua:2016–2028` and `:6332–6333` |
| POPSLOADER-024 | WEAKENED | Root files and both cited duplicate pairs exact, but only **6** exact-duplicate image pairs exist in `.research/assets/`, not "at least 9" (see §2) |
| POPSLOADER-025 | VERIFIED | Identical OPL-UI TODO at `src/fntsys.cpp:544`, `:553`, `:560`; block TODO at `:568–575`; file is 946 lines; Makefile header brands the build "Enceladus project" (`Makefile:25`, inside the cited `:22–27` block) |
| POPSLOADER-026 | VERIFIED-DRIFT | Diverged fallback is real but spans `bin/POPSLDR/ui.lua:4544–4605`, not 4550–4613 (see §2) |
| POPSLOADER-027 | VERIFIED | UDPFS arm at `bin/POPSLDR/system.lua:8040–8048`: `GetFileSizeSafe(path) ~= #expected or ReadWholeFile(path) ~= expected` per `BDMA_COPY_FILES` entry; `IsBdmaModeEquipped` def `:8022`, called from `MaybeApplyAdaptiveBdma` at `:8068` and directly at `:11072` |
| POPSLOADER-028 | VERIFIED | `PLDR.ProbeHddSettingsWrite` def `bin/POPSLDR/system.lua:980`; mount-RW + `pldrs_wtest.tmp` write/delete loop over `__.POPS*` partitions in its body; "(TEST)" call site at `bin/POPSLDR/ui.lua:4622–4637` on the save-success path, with success/failure toasts |
| POPSLOADER-029 | VERIFIED | All four functions at the cited lines — `PLDR.SaveGameListCache` `system.lua:9880`, `PLDR.LoadGameListCache` `:9899`, `PLDR.HDD.CreateCache` `:9944`, `PLDR.HDD.ReadCache` `:9991` — with near-identical PLDRGC1 `S `/`G `/`H ` serialise/parse loops read side by side |
| POPSLOADER-030 | VERIFIED | Rollback table at `system.lua:6675–6683` passes `profile = next_state.profile` (`:6676`) and `popstarter_mode = next_state.popstarter_mode` (`:6678`); `popstarter_mode` occurs exactly once in the file (grep count 1); neither field is produced by `SnapshotSettingsState` (`:5959`) or consumed anywhere in `ApplySettingsState` (`:5994+`, no `state.profile`/`state.popstarter_mode` reference) |
| POPSLOADER-031 | VERIFIED | `system.lua:10843` `local use_minimal_hdd_popstarter_exec = false`; flag referenced only at 10844, 10859, 10873, 11155, 11278 — exactly the five cited branches, no other assignment anywhere. |
| POPSLOADER-032 | VERIFIED | Repo-wide `git grep` for all seven names returns only their definitions (system.lua:944, 4972, 5615, 10364, 11320; ui.lua:3223 `Reset = function`; images.lua:81); live twin `ResolveHddPartitionReadablePath` at system.lua:886, wrapped 1897, called in ui.lua. |
| POPSLOADER-033 | VERIFIED (narrowed) | Narrowed REV-033 holds: line counts 1719/1521 and 806/634 and diff counts 513 / 399 reproduce exactly; standalone copies carry `_start` + SifRpc server (ds34bt.c:1609-1632, 1675) while pademu copies have neither and are consumed only via the `PAD_*` macro layer in `modules/pademu/pademu.c:13-31` — a semantic fork, L-effort refactor, not build glue. |
| POPSLOADER-034 | VERIFIED | `power_level[report->Power]` at exactly ds34bt.c:1333, ds34usb.c:299, pademu/ds34bt.c:1276, pademu/ds34usb.c:304; sole guard `Power != 0xEE`; table is 6 entries (e.g. ds34bt.c:261-263); `u8 Power` (ds34bt.h:309); no clamp anywhere in any copy (only other write is the safe `report->Power = 0x05` press-emu assignment). |
| POPSLOADER-035 | VERIFIED | Non-DVRP probe loop `ps2atad.c:1241-1258` iterates `i < 2` with soft reset + select + probe per device; unconditional `devinfo[1].exists = 0;` at ps2atad.c:1286; DVRP path re-probes device 1 only after it (1288-1300); phantom-slave busy cap at ps2atad.c:491 (`delay > 100000`, comment "~4s instead of ~31s" at 443-450). |
| POPSLOADER-036 | WEAKENED | T42 text-assert block exact at host_harness.py:1776-1790 and 11 of 62 checks are pure source-text asserts, but the re-read count overstates: 25 `read_text` sites in total, only 15 of them re-reads of the two Lua sources already loaded at lines 23-24 (see §2). |
| POPSLOADER-037 | VERIFIED | `.research/build_site.py:12-13` top-level `if os.path.isdir(SITE): shutil.rmtree(SITE, ignore_errors=True)` plus top-level `makedirs`; corpus `print` at line 2375 sits before the `if __name__ == '__main__':` guard at 2376; script is live via `.github/workflows/docs-site.yml:64`. |
| POPSLOADER-038 | VERIFIED | `ps2atad.c:1183` `ata_get_security_status(device, devinfo, NULL);` in `sceAtaSecurityEraseUnit` (Export 12, comment at 1165, exports.tab:17); chain 1111-1114 → `ata_device_identify` (921-929) → PIO-in `ata_pio_transfer` type 2 writes 256 words through `cmd_state->buf16` (711-714); other two callers (1134, 1157) pass `param = ata_param` (1121, 1142); no in-repo caller of the export found by `git grep`. |
| POPSLOADER-039 | VERIFIED | `images.lua:46` `local IMG_FALLBACKS = {}`, read only at images.lua:64 inside `__index`; code-wide grep shows no write/population anywhere (remaining hits are docs recording it is now empty, e.g. COMPONENTS.md:353, DECISIONS.md:376 — the MISSING.png / default.png fallback removal). |
| POPSLOADER-040 | VERIFIED | `.research/build_site.py:903-904` `if len(records) != 34 or len(seen & from_head) != 19: raise ValueError(...)` inside `build_original_image_gap_index` (def at 876), which is called unconditionally in the history page build at line 1474; hard-coded prose counts present as cited ("all 63 wiki pages" line 1095; "2,140 commits" lines 966/971/1069). |
| POPSLOADER-041 | WEAKENED | Missing NULL checks and the DS4 `epCount = 20` / 21-iteration walk are real, but the claimed hang mechanism is wrong: the walk is count-bounded by `while (epCount--)` in both copies, so a zero `bLength` cannot loop forever (see §2 for the corrected, narrower claim and the real underflow hang). |
| POPSLOADER-042 | VERIFIED | `tools/test_disc_layout.py:12-13` are exactly `source.index("          -- An OPL-style _ICO.png")` and `source.index("          -- (EXP56:", start)` (anchors present at ui.lua:3591 and 3612); a missing anchor raises a bare `ValueError` from `str.index`; case count in the test loop is 3 × (2×3 + 4) = 30 as claimed. |
| POPSLOADER-043 | VERIFIED | `ui.lua:3266` `local placeholders = {}`, lookup at 3267, unreachable branch 3268-3288 rendering `PLDR.L("Not implemented yet")` at 3271, under the comment at 3263-3265 "No scenes are placeholders anymore"; no other write to `placeholders` exists. |
| POPSLOADER-044 | WEAKENED | Gutted block, discarded locals and the microsecond unit error all stand (ui.lua:6670-6699, flag default `false` at 1270), but the "counters only ever reset, never read" clause is imprecise: `NavEventCount` is incremented by live code and `DebugPadLast` is read by the block's own comparison (see §2). |
| POPSLOADER-045 | VERIFIED | `build_thread_study` (def .research/build_site.py:1984) calls `render_md(clean_research(raw), strip_prov=False)` twice on the same `raw`: line 1997 for the page body and line 2001 solely to strip tags for the search-index text. |
| POPSLOADER-046 | VERIFIED | First `SLUG_RE`/`slug` pair at .research/build_site.py:90-92, shadowed by an identical pair at 102-104 (bodies byte-identical: `SLUG_RE.sub('-', s.lower()).strip('-')`); the second definition is the one used by the `PAGE_SLUG` loop that follows. |
| POPSLOADER-047 | VERIFIED | `Clamp01` defined at ui.lua:14 (file-scope, used at ui.lua:25) and again, body-identical, as a nested local at ui.lua:1946 inside `WelcomeDraw.Play` (WelcomeDraw at ui.lua:1787), used at ui.lua:1971. |
| POPSLOADER-049 | VERIFIED | Diff sizes re-derived exactly (BT 513, USB 399 diff lines; 1719/1521 and 806/634 lines); standalone guards `port >= MAX_PADS` + BT authorized-check present at `modules/ds34bt/iop/ds34bt.c:1451-1524`, `modules/ds34usb/iop/ds34usb.c:516-661`, absent in pademu bodies `modules/pademu/ds34bt.c:1419-1470`, `modules/pademu/ds34usb.c:515-590` which index `ds34pad[port]` directly; `analog_btn` 15/16 hits pademu-only, `enable_fake`/`options & 1` at `modules/pademu/ds34bt.c:351,1478` vs `disable_fake` standalone `:359`, MAX_PADS 2→4, `rrum * 255` at `modules/pademu/ds34bt.c:1188` |
| POPSLOADER-050 | VERIFIED | Caller sweep over `src/`, `bin/POPSLDR/`, `etc/`: all 12 named dead functions return 0 callers; the 10 used ones hit (e.g. `ds34bt_init`/`ds34usb_init` at `src/main.cpp:687-688`); libs are 173+148=321 lines, single-object `EE_OBJS = libds34bt.o`/`libds34usb.o`, linked via `Makefile` EE_LIBS (`-lds34bt -lds34usb`) and `EXT_LIBS` at `Makefile:82` |
| POPSLOADER-051 | VERIFIED | Stale toast key present in exactly 6 languages directly under the live key (FR `system.lua:2772`, DE `:3079`, PT `:3387`, ES `:3695`, IT `:4002`, HU `:4358`); SK carries only the live key (`:4751`); 8 HU-only keys at `:4155,4214,4306,4315,4331,4332,4377,4378` have zero occurrences in `ui.lua`/`images.lua`/`src/`; live hints composed via `UI.PadHintPair("Keep","Revert")` `ui.lua:7320` and `("Select","Cancel")` `ui.lua:7062` |
| POPSLOADER-052 | VERIFIED | `.research/audit_site.py:99-100` catalogue floor `len(history_rows) < 80`, `:124-126` `tracked_size.get('NOPAL_PATCH.7z', 226) != 226`, verbatim-phrase gates `'The 15 original news bulletins'`, `'1094748012'`, `'3844714277'`, `'34 original screenshot/image references not recovered'` in the `:124-160` block; gate is live at `.github/workflows/docs-site.yml:80` |
| POPSLOADER-053 | VERIFIED | `src/fntsys.cpp` is 946 lines; `#else` at `:693`, `isRTL` `:694`, `fntRenderSubRTL` `:704`, second `fntRenderString` `:733`, block ends `:848` (156 lines); `__RTL` defined nowhere tree-wide and header comment `:17-18` records the undefined `MENU_ITEM_HEIGHT`; `fntLoadDefault` `:390-410` and `fntFitString` `:851-905` (ends `:905`) have zero callers outside `fntsys.cpp`; 156+21+55 = ~232 dead lines |
| POPSLOADER-054 | VERIFIED-DRIFT | Four 7z `-slt` parsers confirmed, but definition lines are `compare_recovered_archive_candidates.py:47`, `audit_hosted_patch_members.py:20`, `audit_legacy_archive_payloads.py:81`, `audit_legacy_tool_overlap.py:39` (not 18/76/33 for the last three); finder/blob secondary lines also shifted (see §2) |
| POPSLOADER-055 | VERIFIED-DRIFT | Wiring-assert pattern confirmed, but the cited range/count and the "no message anywhere in the file" sub-claim are wrong: 35 assert statements in `:29-73`, exactly 45 in `:29-90`, and blob/provenance asserts elsewhere in the same file do carry messages (see §2) |
| POPSLOADER-056 | VERIFIED-DRIFT | Primary claim exact — `audit_published_provenance.py` (31 lines) is 7 required phrases incl. `"188-byte"`, `"226 bytes"`, `"93,934-byte"`, 3 disproven phrases, 1 compatibility sentence, 4 filenames — but the secondary wiki-zip citations are wrong: exact checks are at `audit_original_wiki_zip.py:20-22,28-33,79-80`, not `:29-33` and `:86-89` (see §2) |
| POPSLOADER-057 | VERIFIED-DRIFT | Both comment-string extractions confirmed, but the PNG harness extraction is at `tools/png_decoder_harness.py:116`, not `:122`; the orbs extraction is exactly at `.research/tools/test_cursor_orbs.cjs:17-18`; contrast anchor `tools/test_udpfs_config_runtime.py:8-10` uses the function name (see §2) |
| POPSLOADER-058 | VERIFIED | `grep -n matches_by_hash .research/tools/audit_legacy_tool_overlap.py` returns exactly one hit, `:148` (`matches_by_hash = {d: f for f, (_, d, _) in originals.items()}`); the matching loop below works from `originals` directly |
| POPSLOADER-059 | VERIFIED | Files exist at exactly the claimed sizes — `fetch_fail.tsv` 204 B, `stubborn_done.tsv` 2,484 B, `agent6-FAILED.md` 36 B (sum 2,724 B, content `# agent 6 — FAILED (rate limited)`); repo-wide grep for all three filenames returns zero references; siblings are load-bearing (`build_site.py:552` reads `_state/galleries.json`, `:1076` reads `_state/assets_done.tsv`); per-agent series 00–05, 07 present, 06 only the stub |
| POPSLOADER-060 | VERIFIED | Docs: `ARCHITECTURE.md:253` "\ |
| POPSLOADER-061 | VERIFIED | Doc `ARCHITECTURE.md:640`: "`BDMA_ADAPTIVE` (per-launch BDMA variant staging, default off; see STATE.md)". Code `bin/POPSLDR/system.lua:6236`: `PLDR.BDMA_ADAPTIVE = true   -- per-launch BDMA variant staging (issue #509)`, with the maintainer rationale comment directly above |
| POPSLOADER-062 | VERIFIED | Doc `STATE.md:5-7`: "Slovak wording awaits the contributor; `SK` is not yet in the picker", directly under the 1.4.4 header (`STATE.md:1`). Code `bin/POPSLDR/system.lua:2559` `PLDR.LANGUAGE_ORDER = {"EN", "FR", "DE", "PT", "ES", "IT", "HU", "SK"}`, `:2560` `SK = "Slovenčina"`, SK dictionary at `:4431-4432`; `STATE.md:1` itself and `bin/changelog` [1.4.3]/[1.4.4] record SK as shipped |
| POPSLOADER-063 | VERIFIED | Docs: `ARCHITECTURE.md:1` and `COMPONENTS.md:1` "Release 1.1.0; rolling `v1.1.1-dev` / experimental `v1.1.1-dev-EXP73`", `docs/PRESERVATION_CONTRACTS.md:3` "Public release is **1.1.0** (2026-07-21); rolling is `1.1.1-dev`". Code: `etc/boot.lua:1` `POPSLDR_VER = "v1.4.4"`, `bin/POPSLDR/title.cfg:7` `Version=1.4.4`, `STATE.md:1` "Official release: 1.4.4"; all three doc headers defer to STATE.md, as the finding states |
| POPSLOADER-064 | VERIFIED | Doc `README.md:149`: Retro GEM Game ID row, Options cell "**On**" only (neighbouring rows list full sets, e.g. Cover art "**On** (default) · Off"). Code `bin/POPSLDR/ui.lua:5250-5256`: `AddCycle("Retro GEM Game ID", function() return UI.RetroGemGameId and "On" or "Off" end, …toggle…)`; default on at `system.lua:6258` `PLDR.RETROGEM_GAMEID = true` |
| POPSLOADER-065 | VERIFIED | Doc `ARCHITECTURE.md:329`: "`UI.CoverCache` (`ui.lua:257`, `max = 3`) is a 3-entry LRU of loaded box-art images". Code `bin/POPSLDR/ui.lua:372-373`: `local CoverCache = {` / `max = 4, -- bounded recent cover/icon textures` |
| POPSLOADER-067 | VERIFIED | `src/elf_loader/Makefile:15-16`: target `src/loader/bin/loader.elf:` with recipe `$(MAKE) src/loader` (no `-C`). Stub-PS2SDK execution in `/tmp` (copy of the folder, clone untouched): `make src/loader/bin/loader.elf` ran the recipe, sub-make reported "Nothing to be done for 'src/loader'", exited 0, and created no `src/loader/bin/` at all; `make -n loader.c` then proceeds to bin2c on the nonexistent ELF. Top-level driver does it correctly first at `Makefile:358` (`$(MAKE) -C src/elf_loader/src/loader/ … clean all`). The original INFERRED label is upgraded by this stub execution; a full PS2SDK build was not run |
| POPSLOADER-068 | VERIFIED | Doc `COMPONENTS.md:387-388`: "`src/elf_loader/loader.c` — committed ~6.5 MB bin2c blob of the built `loader.elf`". Measured at the pin: `stat` = 855,821 B, `wc -l` = 8,740 lines — exactly the finding's figures; the doc overstates by ~7.6× |
| POPSLOADER-069 | VERIFIED | Binary exists: `iop/embed/BDMASSAULT_MX4SIO/usbhdfsd.irx`, 14,993 B, md5 `48677ae01b05c84b6f299773baa7dea0`, strings self-identify `MX4SIO: MX4SIO v1.2` / `sio2man`; it is byte-identical to the shipped `bin/POPSLDR/usbhdfsd.irx.mx4sio` (same md5). Tarball beside it (md5 `09ff4b911ba131468a25d0ec9a4e2f27`, 119 files in the `/tmp/bdma7v2` extraction): zero files with `mx4sio`/`sio2`/`sio2man` content (`grep -rli` = 0) and zero such paths in the tar listing (only bdm/libbdm/usbd/usbmass_bd/bdmfs trees). Whole clone tree: the only MX4SIO artifacts are binaries (`mx4sio_bd.irx` 15,089 B md5 `d63df3c91829a982fe6e6bf0f290881e` — a different binary — and `mx4sio_bd_mini.irx`), no source. The folder's pin claim (`COMPONENTS.md:401` "source pins"; tarball README install mapping `usbd_bd_assault.irx` → `usbhdfsd.irx`) covers the USB BDMAssault build, not this SIO2/MX4SIO binary |
| POPSLOADER-070 | VERIFIED | Tree-wide grep for `hci_event_flag`: only the 6 macro definitions (`modules/ds34bt/iop/ds34bt.h:81-83`, `modules/pademu/ds34bt.h:67-69`, each expanding to operations on `hci_event_flag`) plus the two enum comments (`ds34bt.h:140`, pademu `ds34bt.h:122`); no declaration of `hci_event_flag` and zero call sites anywhere. Companion `HCI_FLAG_*` enums likewise occur only at their definitions and have diverged: standalone `:141-149` has 9 values (`0x0001…0x0100`, incl. `READ_VERSION`/`READ_FEATURES`), pademu `:123-129` has 7 (`0x01…0x40`) |
## 4. Reasoning for every non-VERIFIED verdict (verbatim from the worker sections)

### Worker A (001–013)

### POPSLOADER-001 — VERIFIED-DRIFT (archive count off by two; everything else exact)

The core claim re-measures exactly at the pin:

- `git ls-files .research | wc -l` = **312**; `git ls-files | wc -l` = **609**.
- Summed `stat` sizes: `.research/` = **21,197,583 B**; whole tree = **30,417,169 B** (69.7% — the filed "~70%").
- Largest files exact: `popstarter-documentation-stuff-wiki-git-20240731.zip` 2,102,657 B; `ps1-codes-in-ps1-raw-format.md` 1,608,488 B; `POPStarter_HDD_Quickstarter_Pack_20200209.zip` 1,113,737 B; `POPStarter_HDD_Quickstarter_Pack_20171027.7z` 865,736 B.
- `.research/assets/` = **124 files / 8,659,452 B**, exact.

The drift is one sub-figure:

> Filed: "24 download archives totalling 7,829,387 B (zip+7z only)"

`git ls-files .research/downloads` lists 24 entries in total, but two of them are text files (`CHEATS.TXT`, `SAMPLE_CHEATS.TXT`). The zip+7z subset is **22 files**, and those 22 alone sum to exactly the filed **7,829,387 B**. So the byte total is right and the count conflated the folder's total entry count (24) with its archive count (22). Corrected citation: *22 download archives (zip+7z) totalling 7,829,387 B, among 24 files in `.research/downloads/`.* The finding, its fix, and its benefit are unaffected.

### POPSLOADER-002 — WEAKENED (one of the three claimed duplicate embeds is already aliased away)

The byte-identity half is fully verified:

- `bin/POPSLDR/usbd.irx.ilink`, `usbd.irx.mx4sio`, `usbd.irx.usbexfat` and `iop/embed/BDMASSAULT_MX4SIO/usbd.irx` are all md5 `a77650a0ad356077b990d21bde6affc4`, 48,500 B each.
- `bin/POPSLDR/usbhdfsd.irx.udpfs` = `usbhdfsd.irx.usbexfat`, md5 `ad9640d487b6e53441d2b6bed90dff23`, 34,508 B each.
- `bin/POPSLDR/usbhdfsd.irx.mx4sio` = `iop/embed/BDMASSAULT_MX4SIO/usbhdfsd.irx`, 14,993 B, md5 `48677ae01b05c84b6f299773baa7dea0`.

But the embedding half overstates by one whole copy. The filed text says the build "embeds a separate copy of `usbd` for the iLink, MX4SIO and USB-exFAT backends" and claims a saving of "two `usbd` embeds (2 × 48,500 B) and one `usbhdfsd` embed (34,508 B)" = 131,508 B. At the pin the MX4SIO `usbd` embed no longer exists:

- `Makefile:115-119` (embedded-object list) contains `asset_usbhdfsd_irx_mx4sio.o` but **no** `asset_usbd_irx_mx4sio.o`; the `bin2s` rules at `Makefile:220-241` likewise have a rule for `asset_usbhdfsd_irx_mx4sio.c` (:224-225) and none for a MX4SIO `usbd`.
- `src/embed_assets.cpp:149-153`:

```cpp
// usbd.irx.mx4sio is BYTE-IDENTICAL to usbd.irx.usbexfat (the SD/BDM stack
// reuses the same usbd base), so this key aliases that one blob to save ~48KB
// in the ELF. If a future build needs a distinct mx4sio usbd.irx, restore a
// separate asset_usbd_irx_mx4sio (extern + Makefile rule + EMBEDDED_RSC entry).
ASSET_ENTRY("usbd.irx.mx4sio", asset_usbd_irx_usbexfat),
```

and the same alias at `src/embed_assets.cpp:210` for the `POPSLDR/` key. A tree-wide grep for `asset_usbd_irx_mx4sio` finds only that comment and a 2026-06-20 docs audit noting its absence.

**Narrower claim that survives:** exactly two duplicate embeds remain at the pin — `usbd.irx.ilink` (separate symbol `asset_usbd_irx_ilink`, `src/embed_assets.cpp:84-85,164`, rule `Makefile:234-235`) duplicating the usbexfat blob, and `usbhdfsd.irx.udpfs` vs `usbhdfsd.irx.usbexfat` (separate symbols :72-73/:82-83, entries :148/:161, rules `Makefile:222-223/:240-241`). Correct remaining saving = **48,500 + 34,508 = 83,008 B**, not 131,508 B. (The on-disk MX4SIO file still exists and is still staged by name; only its duplicate *embed* is already gone — the filed fix has, in effect, already been applied to one of its three targets.)

### POPSLOADER-007 — WEAKENED (duplication is real for 25 images, not for the 67-file folder)

Both copies exist as filed — `bin/POPSLDR/IMG/` = **67 PNG files / 330,675 B** exactly, and PNG `bin2s` rules + registry entries exist (`Makefile` rules from :150 onward; `src/embed_assets.cpp:12-63,116-143`). The runtime even prefers the embed: `src/graphics.cpp:868-874` (`load_image`) tries `embedded_get(path, …)` first and only falls back to `fopen` afterwards, while `src/system.cpp:137-143` separately resolves loose `IMG/` / `POPSLDR/IMG/` filesystem paths.

What the filed text overstates is the scope. Diffing the folder listing against the Makefile's embed rules:

- **25 PNGs are actually embedded**, totalling **243,578 B** (APAHDD, BDHDD, BG, BGM, BKG, DISC, ILINK, MMCE, MX4SIO, SMB, USB, circle, cover_default, cover_missing, cross, frame, select, splash_appname, splash_bg, splash_credits, splash_logo, square, start, triangle, plus the conditional `default.png` rule at `Makefile:72-77,194-195`, whose source file is absent at the pin and therefore not counted in the 243,578 B).
- **42 PNGs are loose-only**, totalling **87,097 B** — the L1/L2/L3/R1/R2/R3 set, the `arrow_*`, `icon_sub_*`, `osk_*`, `scroll_*`, checkbox/bar/joypad images, etc. No Makefile rule and no registry entry embeds them; for these there is no second copy to delete.

**Narrower claim that survives:** the shipped-twice duplication covers the 25 embedded images = **243,578 B** (the per-asset split the original finding explicitly left INFERRED), not "up to ~330 KB" for the folder as a whole. The fix direction (pick one live path per asset, delete the other) is unchanged, and for the embedded 25 the embed-first load order in `graphics.cpp` makes the loose copies the presumptive dead side, subject to the packaging check the original already required. 243,578 + 87,097 = 330,675 B reconciles exactly with the filed folder total.

### POPSLOADER-010 — VERIFIED-DRIFT (revised semantic-fork claim holds; the "identical Makefiles" sub-claim is false)

The revised version (REV-010: the pademu copies are a **semantic fork**, not drifting photocopies) is borne out, and the duplication census is exact:

- `wc -l`: `modules/ds34bt/iop/ds34bt.c` 1,719; `modules/ds34usb/iop/ds34usb.c` 806; `modules/pademu/ds34bt.c` 1,521; `modules/pademu/ds34usb.c` 634 — sum **4,680**, as filed.
- `diff modules/pademu/ds34bt.c modules/ds34bt/iop/ds34bt.c` produces **512 lines of diff output**, as filed; the divergences are semantic, e.g. `modules/pademu/ds34bt.c:341` `#define MAX_PADS 4` vs `modules/ds34bt/iop/ds34bt.c:346` `#define MAX_PADS 2` (same split in the USB pair: pademu 4 vs standalone 2), pademu's `#include "sys_utils.h"` vs the standalone's `IRX_ID("ds34bt", 1, 1)`, and standalone-only `bt_dev.vid/pid/rev` capture. The USB pair diffs by 399 output lines in the same pattern.
- Byte-identical support files verified by md5: `modules/ds34bt/iop/irx_imports.h` = `modules/ds34usb/iop/irx_imports.h` (`a9550ca345b8a86c1034074300718dcd`); `modules/ds34bt/iop/smsutils.S` = `modules/ds34usb/iop/smsutils.S` (`3612cf1bd66a11f0b9e53ac78a5940d7`).

The drift:

> Filed: "the two module Makefiles are identical"

`diff modules/ds34bt/iop/Makefile modules/ds34usb/iop/Makefile` is not empty:

```make
< IOP_BIN = ds34bt.irx
< IOP_OBJS = ds34bt.o smsutils.o imports.o
---
> IOP_BIN = ds34usb.irx
> IOP_OBJS = ds34usb.o smsutils.o imports.o
```

Corrected citation: the two Makefiles are **identical except for the two lines that must differ** (their own binary/object names, md5 `d99ec6faa1267cbf766fdd6f55b838b7` vs `094e26c009afca4f6e3e688621c1c3ef`). They cannot be replaced by a single literal copy without parameterising the module name, so that bullet of the "immediate small win" needs that one-word qualification. The main finding and the revised fork characterisation are unaffected.

### POPSLOADER-012 — VERIFIED-DRIFT (all counts exact; the retraction workflow's trigger is narrower than filed)

Every number re-measures exactly: 10 workflows, `wc -l` total **2,062**, and each per-file count as filed (compilation 253, docs-site 165, ember-watch 157, experimental-release 501, official-release 131, opencode 32, research-network-driver-integrity 114, retract-mislabeled-ember-beta 40, rolling-release 576, wiki-sync 93). The retraction workflow's own header at `.github/workflows/retract-mislabeled-ember-beta.yml:3-4` says "This cleanup only retracts the accidental same-session 1.3.0-ember-beta.1 POPSLoader tag", and its script prints "Mistaken prerelease already removed." and exits 0 when the release is absent — the one-shot, self-describing character is as filed. `official-release.yml:1-5` does claim to "publish the exact passing CI artifact", as filed.

The drift is in the problem sentence:

> Filed: the retraction workflow "re-runs on every matching push forever, checking for a release that no longer exists"

Its trigger at `.github/workflows/retract-mislabeled-ember-beta.yml:5-8` is:

```yaml
on:
  push:
    branches: [master]
    paths: ['.github/workflows/retract-mislabeled-ember-beta.yml']
```

It therefore runs only on a master push that touches **that workflow file itself** — it is dormant on ordinary pushes, not a recurring no-op on every push. Corrected wording: *a one-shot cleanup workflow that can only ever re-fire if its own file is edited on master.* The delete-it recommendation stands (arguably more cheaply: it is dead weight, not a recurring cost), but the "permanent no-op workflow" cost framing should not be repeated. Whether the target release still exists was not checked (no live GitHub state in scope); the workflow's own already-removed branch is the only evidence, as in the original.

---
### Worker B (014–030)

### POPSLOADER-014 — VERIFIED-DRIFT (ref counts moved; every named ref exists)

The finding is a list-only clutter item, and the list itself checks out: every named branch is present (`origin/BETA-3-restarts`, `origin/BETA-8-5`, `origin/BETA-9`, `origin/BETA-12-PLAY`, `origin/CHECKPOINT2`, `origin/dev`, `origin/experimental`) and the tag list is **exactly 37**, including all six cited checkpoint/backup tags (`backup/pre-hdd-cache-2026-06-19`, `checkpoint/2026-06-16-audit-fixes`, `checkpoint/BETA-12-PLAY-before-phase3-2026-06-18`, `checkpoint/master-before-beta12-2026-06-18`, `checkpoint/master-before-dkwdrv-merge-20260523-132143`, `checkpoint/master-before-real-dkwdrv-merge-20260523-132313`) and the four floating tags (`latest`, `release`, `rolling-release`, `experimental`).

Corrected counts at verification time:

- Remote branches: `git branch -r` returns 39 lines including the `origin/HEAD -> origin/master` symref — **38 branch refs** (37 excluding `master` itself, which is presumably how pass 1 got "37").
- Claude branches: **20** `origin/claude/*` refs (13 `project-thread-*` incl. the two `y8k8m2-*` variants, 7 `popsloader-*`), not "14". The clone also carries branch families the finding does not list (`chore/`, `codex/`, `fix/`, `maintenance/`, `research/`, `style/` — the two `style/*-20261114` branches are dated the day after pass 1 was written, so part of the drift is refs created after the audit, which a commit pin cannot freeze).

Substance (checkpoint/backup refs used as an in-repo archive, floating tags duplicating Releases) is unchanged. No size claim was made and none is implied.

### POPSLOADER-015 — VERIFIED-DRIFT (root file count 17, not 18; all other measurements exact)

Verified exactly:

- Total root Markdown lines: `wc -l *.md` = **4,896 total** — matches the finding.
- Duplicate pair: `md5sum OFFICIAL_NOTES.md RELEASE_1.4.4.md` = `b6fddc7922bd0c6c1dce14973bc066e3` for both — matches the finding character for character (each 1,841 B).
- Fossil docs: `docs/REPO_AUDIT_2026-07-07.md` = 128,247 B / 385 lines; `docs/AUDIT_CODEX_2026-06-20.md` (22,799 B) and `docs/HANDOFF_EXP33_2026-07-21.md` (16,130 B) both present in `docs/`.

The one wrong number is the headline count: the root holds **17** `.md` files, not 18 — `AGENTS, ARCHITECTURE, COMPONENTS, CONTRIBUTING, DECISIONS, EXPERIMENTAL_NOTES, OFFICIAL_NOTES, QA_REGRESSION_MATRIX, README, ROLLING_NOTES, ROADMAP, STATE, TESTING` (13) + `RELEASE_1.3.0/1.3.1/1.4.0/1.4.4` (4) = 17. The finding's own location list also enumerates exactly these 17, so the "18" is an arithmetic slip in the title, not a missing file. Fix and benefit are unaffected.

### POPSLOADER-016 — VERIFIED (narrowed) — the R3 REV-016 + R4 REV-016b version holds exactly; the original pass-1 version overstates

Original claim (all 16 scripts one-shot, ~2,100 lines, "one workflow still runs a subset") does **not** survive. The narrowed claim in the §4 ledger does, on every number:

- **The 5 unwired scripts are exactly the dead residue, exactly 547 lines:** `audit_network_driver_crc_overlap.py` 79 + `audit_original_automated_parity.py` 111 + `audit_original_download_links.py` 104 + `audit_original_git_history.py` 185 + `audit_original_wip06_2017.py` 68 = **547** (`wc -l`). A whole-tree grep for each name finds references **only** in the frozen `.research/research/*.md` reports they were written to produce (e.g. `original-git-gap-audit.md`, `original-git-exact-automated-parity.md`) and in each script's own docstring — no workflow, no import, no other executable reference.
- **The CI-wired set is 12 files, as the R4 addendum corrects (not 11):**
  - `research-network-driver-integrity.yml` executes 6: `verify_network_driver_payloads.py` (`:41`), `compare_recovered_archive_candidates.py` (`:47`, `:106`, `:110`), `audit_hosted_patch_members.py` (`:64`), `audit_bitbucket_download_snapshots.py` (`:74`), `audit_legacy_archive_payloads.py` (`:99`), `audit_legacy_tool_overlap.py` (`:103`).
  - `docs-site.yml` executes 4 Python scripts: `guard_site_deploy.py` (`:71`, `:146`, `:149`, `:154`), `audit_legacy_pages.py` (`:72–73`, `:147–148`, `:155`), `audit_published_provenance.py` (`:101`), `audit_original_wiki_zip.py` (`:104`).
  - Shared module: `inspect_network_modules_header.py`, imported at `.research/tools/verify_network_driver_payloads.py:19` (`from inspect_network_modules_header import manifest`; also imported by the unwired CRC script at its `:17`) and py-compiled/path-triggered by the integrity workflow (`:14`, `:40`). (REV-016's text cites the importer as `tools/verify_network_driver_payloads.py:19`; the file actually lives under `.research/tools/` — a path shorthand in the revision note, line and import exact.)
  - Plus the R4 catch: `test_cursor_orbs.cjs` (100 lines) executed at `docs-site.yml:70` (`node .research/tools/test_cursor_orbs.cjs`).
  - Total Python in `.research/tools/`: 16 files / 2,055 lines, of which 11 files are wired (2,055 − 547 = 1,508 lines) — matching REV-016's arithmetic.
- Revised fix scope (move/delete applies to the 5 unwired scripts / 547 lines only; the wired 12 leave only with the POPSLOADER-001 archive move) is therefore the correct disposition. Verdict recorded as **VERIFIED (narrowed)** per the batch instruction, not WEAKENED: no further narrowing is needed.

### POPSLOADER-024 — WEAKENED (duplicate-image count overstated: 6 pairs, not ≥9)

What survives, verified:

- Root assets: `banner.jpg` = **345,431 B** exactly as cited; `imageformat.png` present at root (93,021 B). A whole-tree grep for `banner.jpg` / `imageformat.png` (excluding the files themselves) returns **no references**, consistent with the finding's own "usage not traced" hedge.
- Both cited example pairs are byte-identical: `2667142094-356screenshot1.gif` = `356screenshot1.gif` (md5 `1dd27d7329acc88b1ce4fe3c560a2f0b`, 18,611 B) and `2984521000-Playstation-Button-Select.png` = `3405191067-Playstation-Button-Select.png` (md5 `f9402fd56124e6d8848375ca534e79f4`, 475 B).

What does not survive: "at least 9 exact-duplicate pairs found by md5". A full md5 census of all 124 files in `.research/assets/` (all extensions, case-insensitive) yields exactly **6 duplicate groups, each of exactly 2 files = 6 pairs**:

1. `1dd27d7…` — the `356screenshot1.gif` pair above
2. `f9402fd…` — the `Playstation-Button-Select.png` pair above
3. `415a1a9…` — `1165364186-Playstation-Button-L2.png` = `3667653909-Playstation-Button-L2.png` (867 B)
4. `826098c…` — `1258137434-pops05_zps81df52b9.jpg` = `pops05_zps81df52b9.jpg` (35,200 B)
5. `a7fd769…` — `1712503932-Playstation-Button-R2.png` = `2283666138-Playstation-Button-R2.png` (976 B)
6. `68de46d…` — `2651471562-Playstation-Button-T.png` = `3050099753-Playstation-Button-T.png` (1,423 B)

A repo-wide image-only census finds the same 6 groups and no others, so the extra pairs needed to reach 9 do not exist among images. (Repo-wide across *all* file types there are many more duplicate groups — IRX/ELF copies covered by other findings — but those are not this finding's asset claim.) **Narrower surviving claim:** 6 exact-duplicate image pairs in `.research/assets/` (6 redundant copies, 57,552 B total — the "< 1 MB" benefit estimate still holds), plus the two root-level loose assets as cited. The fix (delete one name per md5; move-or-delete the root files after a grep — the grep now returns nothing) is unchanged.

### POPSLOADER-026 — VERIFIED-DRIFT (fallback span is ui.lua:4544–4605, not 4550–4613)

The mechanism is exactly as filed. In `queue_exit` (`bin/POPSLDR/ui.lua:4459`), the xpcall body first tries the real path:

- `ui.lua:4509–4543` — `if type(PLDR.CommitSettingsChanges) == "function" then return PLDR.CommitSettingsChanges({ ... })` with the full option table (`smb`, `smb_modules`, `apply_smb`, `ember_global`, `hide_text`/`prev_hide_text`, `retrogem_gameid`, …). The callee is unconditionally defined at `bin/POPSLDR/system.lua:6567` (`function PLDR.CommitSettingsChanges(opts)`).

Corrected fallback span: the hand-rolled copy runs from **`ui.lua:4544`** (`PLDR.POPSTARTER_PATH = pop_path`, immediately after the Commit block's `end`) to **`ui.lua:4605`** (`return true, nil`; the xpcall closes at `:4606`). That is ~62 lines — the "~64 lines" size claim stands, but the cited bounds 4550–4613 are off at both ends (4550 lands mid-fallback inside the keyboard-layout normaliser branch; 4613 lands in the post-success dirty-flag clearing at `:4608+`).

Divergence confirmed by reading both paths: the fallback does direct `PLDR.*` assignments + normalisers, then `PLDR.SaveSettingsAtomic()` (`:4593`) and `PLDR.ApplyBdmaMode(mode_key)` (`:4597`) only — no SMB apply stage, no Ember/RetroGem/hide-text handling, and its failure returns are `save_failed` / `bdma_apply_failed` with no rollback, unlike the real path. Fix (delete the fallback, call `CommitSettingsChanges` directly) unchanged.
### Worker C (031–047)

### POPSLOADER-036 — WEAKENED

What survives, proven:

- The T42 example is exact. `tools/host_harness.py:1785-1786`: `elif _ui.count("UI.PendingHideDrop = entry") != 2:` fails the check, and 1788-1790 use `_ui.index("UI.PendingHideDrop ~= nil") > _ui.index("local ammount = #PLDR.GAMES")` — a string-position proxy for control flow.
- The text-only population is real and countable: the checks whose verdict is computed purely from substring / count / index assertions over re-read source text are T42, T43, T44, T46, T47, T48, T50, T51, T52, T53 and T55 — **11 of the 62 checks** (60 `check("T…")` calls plus the 2 boot-execution checks). 11/62 ≈ 18%, so "roughly a fifth" stands. (T45, T49 and T54 in the same region genuinely execute Lua — T45 via `E(...)` round-trips, T49 "driven for real", T54 drives the real join — so they are not part of the text-only set.)
- Numbering accretion is exact: there is no T4 (sequence runs T1, T2, T3, T5…), and T61/T62 sit at host_harness.py:366/406, before T7 at line 489.

What does not survive as written:

- "The same sources are also re-read from disk at least 25 times per run (`read_text` sites) instead of using the copies loaded at lines 23–24." Measured: there are **25 `read_text` call sites in total, including the initial loads at lines 23–24**. Per file: system.lua is read 10× in total (1 initial + 9 re-reads), ui.lua 7× (1 initial + 6 re-reads) — i.e. **15 re-reads of the two already-loaded Lua sources**, not ≥25. The remaining 8 sites are first reads of other files (main.cpp ×2, luasystem.cpp ×3, retrogem.cpp, Makefile, elf.c).

**Narrower surviving claim:** roughly a fifth of the harness (11 of 62 checks: T42–T44, T46–T48, T50–T53, T55) asserts source text rather than behaviour; the file contains 25 `read_text` sites in total, of which 15 re-read system.lua/ui.lua despite both being loaded once at lines 23–24; there is no T4 and T61/T62 precede T7. Fix and benefit unchanged.

### POPSLOADER-041 — WEAKENED

What survives, proven:

- No NULL checks in either connect path. `modules/ds34usb/iop/ds34usb.c:98` `usb_connect` fetches `device`/`config` and dereferences `config->bLength` at line 128 (`interface = (UsbInterfaceDescriptor *)((char *)config + config->bLength);`) and `endpoint->bmAttributes` in the walk, with no NULL test; `modules/ds34bt/iop/ds34bt.c:86` `bt_connect` does the same at line 111. Their own probes do check: ds34usb.c:87 `if (device == NULL)`, ds34bt.c:53-62 `device == NULL` / `config == NULL`.
- The DS4 hard-code is exact: ds34usb.c:135 `epCount = 20; // ds4 v2 returns interface->bNumEndpoints as 0`, and the do-while walk therefore runs 21 iterations regardless of the descriptor blob's real length.
- Cited ranges drift: usb_connect spans 98–~167 (walk at 138–154), bt_connect spans 86–~157 (walk at 121–142) — not 139–175 / 113–160 as filed, though both cited ranges land inside the functions.

What is refuted:

- "a zero `bLength` … loops forever on the IOP." Both walks are **count-bounded**, not length-bounded: ds34usb.c:152-154 and ds34bt.c:140-142 advance `endpoint = (UsbEndpointDescriptor *)((char *)endpoint + endpoint->bLength);` inside `do { … } while (epCount--);`. With `bLength == 0` the pointer simply stalls and the *same* descriptor is re-processed; the loop still terminates after `epCount + 1` iterations. Zero `bLength` cannot produce an infinite loop in either copy.

Corrected hang mechanism found in the same loop (folded in here, not filed separately — same location, same finding family): `epCount` is a signed `int` set to `interface->bNumEndpoints - 1` (ds34bt.c:117, ds34usb.c:132 for DS3). A device reporting `bNumEndpoints == 0` — a case the DS4 comment at ds34usb.c:135 itself documents as real — makes `epCount = -1`, and `while (epCount--)` then evaluates −1, −2, … (never 0), so the walk is effectively non-terminating while striding through memory by `bLength`. The BT copy and the DS3 branch have no equivalent of the DS4 hard-code guarding this.

**Narrower surviving claim:** both standalone connect callbacks (and, un-cited by the finding, both pademu copies at ds34bt.c:110/135-137 and ds34usb.c:121/145-147) dereference fetched device/config/endpoint descriptors with none of the NULL checks their probes perform, and walk the endpoint blob for a fixed count (21 for DS4) with no bound against the blob's actual length; a zero `bLength` stalls the walk on one descriptor for the remaining iterations rather than looping forever, while a zero `bNumEndpoints` underflows the signed `epCount` to −1 and makes the do-while effectively non-terminating in the BT and DS3 paths. Benefit (remove a hang/corruption-on-connect class for malformed/clone devices) stands; the proposed fix should add an `epCount < 0` / `bNumEndpoints == 0` guard alongside the NULL and `bLength == 0` checks.

### POPSLOADER-044 — WEAKENED

What survives, proven:

- The block is where cited: `bin/POPSLDR/ui.lua:6670-6699`, gated on `UI.InputConfig.DEBUG_INPUT_LOG`, whose default is `false` at ui.lua:1270 (the only other reference to the flag in the file).
- The logging body is gone: locals `up`/`down`/`cross`/`circle` at ui.lua:6677-6680 are computed from `UI.Pad.GPAD` and never used again in the block or anywhere else.
- The unit error is exact: both cadence tests compare `Timer.getTime()` deltas against `1000` (ui.lua:6676, 6689), and `Timer.getTime()` returns microseconds in this codebase (AGENTS.md:79: "`Timer.getTime()` returns MICROSECONDS, not milliseconds… returns raw `clock() - tick` ticks… `CLOCKS_PER_SEC == 1e6`"), so the "1-second" cadence fires every ~1 ms when the flag is on.

What does not survive as written:

- "maintains two timers whose counters are only ever reset, never read." `UI.Pad.DebugPadLast` **is** read — by the block's own comparison at ui.lua:6676. And `UI.Pad.NavEventCount` is not only reset: live code increments it in `emit_nav` at ui.lua:6596 (`UI.Pad.NavEventCount = (UI.Pad.NavEventCount or 0) + 1`, field declared at ui.lua:6496).

**Narrower surviving claim:** the debug block is gutted scaffolding — it computes and discards the four direction locals, and its two timer counters drive nothing: `DebugPadLast` is read only by the block's own (wrong-unit) comparison, and `NavEventCount`'s value is never consumed anywhere in the repo (incremented at ui.lua:6596, reset at 6686/6690, never tested or displayed). Deleting the block and the flag as proposed remains correct; a complete deletion should also drop the now-orphaned `NavEventCount` increment/field if the maintainer wants the counter gone entirely.
(Worker C's additional footnote on POPSLOADER-033 — `link_key` exists in only 3 of the 4 ds34 files, absent from `modules/pademu/ds34usb.c`, contrary to the original parenthetical; the narrowed verdict is unaffected — is recorded in §3 of `verify2-sections/verify2-pops-C.md`.)

### Worker D (049–065, 067–070)

### POPSLOADER-054 — VERIFIED-DRIFT (duplication of the 7z listing parser stands; several cited lines are off)

The core claim re-derives cleanly. All four gates implement the same parser — run `7z l -slt`, split on `----------`, build a `fields` dict from ` = ` lines, drop `Folder == '+'` entries, and apply the "0-byte, no-CRC entry that is a parent of a real member is a directory marker" filter:

- `compare_recovered_archive_candidates.py:47` `def seven_entries(exe, path):` — `p.stdout.split('----------', 1)[1].split('\n\n')`, `fields = dict(line.split(' = ', 1) …)`. Cited `:47-65` — correct.
- `audit_hosted_patch_members.py:20` `def list_7z_members(exe, archive):` — same split/fields shape, with the directory-marker comment verbatim in spirit: "Some p7zip/7zip builds omit the Folder field in -slt output for 7z directory entries. The archive may show a 0-byte path with no CRC that is a parent of a real member. Do not count it as a file." Cited as `:18-42`; the function actually starts at `:20`.
- `audit_legacy_archive_payloads.py:81` `def archive_members(archive: Path, executable: str) -> tuple[int, int, int]:` — same shape plus the path-safety rejection and size checks the finding describes as drift. Cited as `:76-116`; the function actually starts at `:81`.
- `audit_legacy_tool_overlap.py:39` `def seven_list(path, exe):` — same shape, raising on oversized members inside the lister (`length < 0 or length > EXTERNAL_MAX_BYTES`). Cited as `:33-57`; the function actually starts at `:39`.

Secondary sites, corrected: the 7z-executable discovery sits at `verify_network_driver_payloads.py:119` (cited 120), `compare_recovered_archive_candidates.py:41` (cited 39–44, in range), `audit_hosted_patch_members.py:52` (cited 53), `audit_legacy_archive_payloads.py:146` (cited 156–158 — wrong), `audit_legacy_tool_overlap.py:103` (cited 97 — wrong). The git-blob OID sites are exact: `audit_legacy_archive_payloads.py:44` `def git_blob`, `audit_legacy_pages.py:14` `def oid`, `tools/test_udpfs_integration.py:23` inline `sha1(b"blob " …)`. The sharing precedent is exact: `verify_network_driver_payloads.py:19` `from inspect_network_modules_header import manifest`. Nothing here weakens the finding; only the line citations drifted.

### POPSLOADER-055 — VERIFIED-DRIFT (text-assertion wiring half stands; count/range and the bare-assert parenthetical are wrong)

The pattern is real: `tools/test_udpfs_integration.py` reads `ui.lua`, `system.lua`, `src/luasystem.cpp`, `src/embed_assets.cpp` and the `Makefile` as text (`:29-33`) and asserts exact strings, including the whitespace-exact C++ at `:68`:

```python
assert 'snprintf(iparg,sizeof(iparg),"ip=%s",ip);' in cpp
```

and the slice-and-exclude check at `:46-47` built from two `ui.index("function …")` anchors. The blob-pin half (`:12-27`) and PROVENANCE.json half (`:77-117` in the original's numbering; provenance block actually runs to the end of the 117-line file) are byte checks, as the finding says.

Two sub-claims do not survive as written:

1. **Count/range.** An AST count of the file gives 35 assert *statements* with line numbers in the cited `:29-73` range (lines 35–47, 49–62, 64–71, 73), not ~45. The "~45" figure is exactly right for the wider wiring region `:29-90` (45 statements, adding the asset/make loop asserts at `:74-77` and the file-existence asserts at `:78,79,84,85,90`). Corrected citation: `tools/test_udpfs_integration.py:29-90`, 45 assert statements.
2. **"No message argument anywhere in the file."** False for the file as a whole. The blob asserts carry messages — `:22` `assert len(binary) == length, (path, len(binary), length)`, `:25` `assert binary[:4] == b"\x7fELF", f"not a valid ELF: {path}"` — as do `:97`, `:105` and `:116`. What is true, and what the finding's argument actually needs, is the narrower claim: **the wiring asserts in `:35-90` themselves are all bare** (no `msg` on any of them, AST-verified). The surviving claim is therefore: ~45 bare source-text assertions in the wiring half `:29-90`, whose failures are unadorned `AssertionError`s — while the file's other halves do use messages.

### POPSLOADER-056 — VERIFIED-DRIFT (primary file exact; secondary wiki-zip lines wrong, one attribution name wrong)

The primary claim is exact, whole-file. `.research/tools/audit_published_provenance.py` is 31 lines and nothing else: seven required phrases — `"Historical NOPAL patch name conflict"`, `"188-byte"`, `"226 bytes"`, `"IGR ELF-loader"`, `"archival copy"`, `"not a verified"`, `"93,934-byte"` — each failing with `Missing public provenance warning: {term}`; three disproven phrases that must not appear; one exact compatibility sentence, `"Do not apply the hosted file as a verified PAL workaround"`; the `href="downloads/NOPAL_PATCH.7z"` link check; and four required filenames (`POPStarter_USB_Quickstarter_Pack_20171027.7z`, `POPStarter_SMB_Quickstarter_Pack_20171027.7z`, `DISCS_POOPER.EXE`, `uLE_kHn_20160723.7z`).

The secondary citation does not survive. In `.research/tools/audit_original_wiki_zip.py` the exact-text gates are:

- `:20-22` — `EXPECTED_MODULE_LINE = ("For light gun, first .IRX might be USBD.IRX and second .IRX USBGUN.IRX;")`
- `:28-33` — the module-line presence check, the `"second .IRX USBD.IRX;"` regression check, and the attribution check — but the attribution string is `"AKuHAK"` (`:32`: `if "AKuHAK" not in source or "AKuHAK" not in rendered:`), not `"AstroSnail"` as the finding states.
- `:79-80` — `"AstroSnail"` does exist in the file, but as a downloads-page attribution check in the staged-archive branch (`if "AstroSnail" not in downloads: raise ValueError("Archive contributor attribution disappeared")`), not at the cited `:86-89` — lines 86–89 are the `except`/`SystemExit` tail of the `__main__` guard and contain no gates at all.

Corrected secondary citation: `.research/tools/audit_original_wiki_zip.py:20-22, 28-33, 79-80`. The pattern claim (exact prose as a hard gate, in a second file) stands.

### POPSLOADER-057 — VERIFIED-DRIFT (both comment-anchored extractions stand; PNG harness line is 116, not 122)

Both harnesses are genuine execution tests that locate the code under test by comment text:

- `tools/png_decoder_harness.py:116` (cited `:122` — line 122 is an unrelated `rgb = lambda …` inside the test-case builder):
  ```python
  decoder = source[source.index('//2D drawing functions'):source.index('GSTEXTURE* loadbmp(')]
  ```
  under the comment at `:115` "Compile production functions verbatim. No copied decoder implementation."
- `.research/tools/test_cursor_orbs.cjs:17-18` — exactly as cited:
  ```js
  const start = js.indexOf('/* Site-wide cursor orb preference.');
  const end = js.indexOf('/* ---- PS2 OSDSYS Cursor Orbs Canvas ---- */', start);
  ```

The contrast case also checks out: `tools/test_udpfs_config_runtime.py:8-10` anchors on the function name (`source.index("local function ParseUdpfsIPv4(value)")`). Only the PNG line number drifted; the brittleness claim is untouched.
## 5. New candidate findings

**None.** All four workers filed zero candidates; reserved ranges POPSLOADER-109…124 are unused. Two genuine observations were folded into the verdicts they belong to rather than filed separately: the `epCount = −1` underflow hang (into POPSLOADER-041's corrected mechanism, §4 worker C) and the missing `link_key` in `modules/pademu/ds34usb.c` (into POPSLOADER-033's footnote). One cosmetic stale comment at system.lua:8072 was noted by worker B and deliberately not filed.

## 6. Residue

Nothing in scope was left unverified: 68 of 68 findings carry a verdict with an evidence trail. Category 5 items were verified structurally only (no hardware timing exists in this environment), and POPSLOADER-067's execution used a stub PS2SDK (rule behaviour proven; a full toolchain build was not run) — both limits are recorded at the items themselves. Clone git-clean at end; read-only held.
