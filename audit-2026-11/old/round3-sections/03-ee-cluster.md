# Round 3 — Task 3 section: EE filer/MC/browser cluster, end-to-end (coordinator's own pass)

Pin: `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790`. All line numbers at the pin, READ this session unless marked INFERRED.

## Coverage ledger (Task 3)

| File | Lines | Read |
|---|---|---|
| src/filer_mount.c | 238 | 1–238 full (R3) |
| src/filer_device.c | 231 | 1–231 full (R3) |
| src/mc_ps1_card.c | 445 | 1–445 full (R3) |
| src/mc_card_view.c | 543 | 1–543 full (R3) |
| src/mc_card_write.c | 1,112 | 1–1,112 full (R3) |
| src/mc_card_export.c | 625 | 1–625 full (R3) |
| src/mc_save_export.c | 504 | 1–504 full (R3) |
| src/dash_browser.c | 3,616 | 1–280, 590–795, 1085–3616 (R3) + 280–590, 795–1085 (R2) = full |
| src/dash_card_tool.c | 2,903 | 1–227, 434–2903 (R3) + 227–434 (R2) = full |

## Findings (temp IDs T3-n)

### T3-1 / The card-image copy+verify engine is written five times in mc_card_export.c / Category 2
- **Location(s):** `src/mc_card_export.c:239-296` (`mcCardBackupActiveMmce`), `:298-351` (`mcCardBackupNoEccImpl`), `:377-441` (`mcCardExportActiveMmcePcsx2`), `:443-498` (`mcCardExportPcsx2`), `:556-610` (`mcCardImportPcsx2Impl`); the header validator twice in the same file: `source_info_fd` (`:173-203`) vs `pcsx2_source_info` (`:500-535`).
- **Problem:** Five implementations of one skeleton — validate header/geometry, chunked write pass with progress callbacks, chunked verify pass regenerating expected bytes and memcmp-ing the read-back, remove-dest-on-failure epilogue. They differ in exactly two dimensions: how the source is read (one held fd vs reopen-per-chunk — both comment their choice as an MMCE accommodation) and an optional per-page transform (identity, `convert_block` :364, `strip_pcsx2_block` :543). The file already demonstrates the factoring idiom twice (`mcCardBackupNoEccImpl`/`mcCardImportPcsx2Impl` with an `only_new` flag and thin public wrappers), so the pattern for the fix is in the same file. A change to the verify policy, progress accounting or failure cleanup must currently be made five times; the copies have already drifted in small ways (e.g. only the two `Impl` copies honour the `owned` rule for removal).
- **Fix:** One engine parameterised by a source reader (fd or path) and a transform callback (NULL = identity), with the five public functions reduced to wrappers — the shape the two `Impl` functions already have. Same for the header validator: one function returning raw and encoded sizes.
- **Benefit:** INFERRED ~200 of ~370 skeleton lines removed; one verify policy to audit for the code path that decides whether a user's only card backup is good.
- **Effort:** M. **Risk:** Med (all five are live backup paths; the host-testable surface is the mc_* layer — behaviour must stay byte-identical, which the verify passes themselves make checkable). **Confidence:** High (READ — all five read end to end).

### T3-2 / ~0.4 MB of static .bss serves modal screens that are closed most of the time / Category 4
- **Location(s):** `src/mc_card_export.c:20-22` (`export_in` 65,536 B + `export_out` 67,584 B + `verify_out` 67,584 B = 200,704 B); `src/dash_card_tool.c:43-48` (`ct_cache` 16,384 B, `ct_saves[250]` ≈29,000 B, `ct_titles`/`ct_details` 24,000 B each, `ct_items[253]`, `ct_view` ≈2.3 KB — ≈100 KB), `:554` (`back` 4,096 B), `:988,1217,1404` (three function-static `sb[512]`+`root[1024]` pairs); `src/dash_browser.c:1388-1389` (compare buffers 2×16,384 B), and eight `static int idx/sv_idx/psu_idx[MAX_ENTRY]` arrays at `src/dash_browser.c:808,964,1040,1065,1158,2684,2781,3031` (8×8,192 B = 65,536 B).
- **Problem:** The card export/backup operations, the Card contents tool and the browser's MMCE-history compare each keep their full working set in static storage for the life of the process, although each is a modal screen/operation used occasionally. The browser itself shows the alternative in the same codebase: its 768 KB listing array is `malloc`'d on open and freed on close (`browserOpenState`/`browserCloseState`, `src/dash_browser.c:3412ff`). Totals are field arithmetic (INFERRED: `FILEINFO`/`McViewSave`/`DashMenuItem` sizes from their header definitions; EE pointers are 4 bytes).
- **Fix:** Allocate the export trio and the card-tool tables on operation/screen entry and free them on exit, exactly as the browser already does for `fb.files`/`fb.mark`; collapse the eight index arrays into one shared scratch array (no two of those operations can be live at once — they are all driven from the same modal menu flow). No behaviour change.
- **Benefit:** INFERRED ~400 KB of EE RAM returned to the heap whenever these screens are closed — the same order as LAUNCHSTATION-030's font arena, on the same 32 MB machine that also hosts -017's update sink.
- **Effort:** M. **Risk:** Low/Med (allocation failure paths must reuse the existing "Not enough memory" handling the browser open already has). **Confidence:** High for the locations and static storage (READ); Med for the byte total (INFERRED arithmetic).

### T3-3 / The dashboard browser sorts listings with an insertion sort that moves 384-byte structs / Category 5
- **Location(s):** `src/dash_browser.c:265-285` (`fbSortFiles`), called from the listing-completion path at `src/dash_browser.c:372`.
- **Problem:** Insertion sort is O(n²) in both comparisons and element moves, and each move is a whole-`FILEINFO` struct assignment (~384 B, INFERRED as in -036). At the tolerated maximum of `MAX_ENTRY` 2,048 entries that is ~2M struct assignments (~800 MB of memory traffic) in the worst case; a few-hundred-entry HDD folder is ~50k assignments. It runs on the worker thread, so the UI does not freeze (round 2 verified the worker design) — the cost is listing latency on exactly the large folders where the wait is already longest. The same codebase uses `qsort` for the card tool's lists (`src/dash_card_tool.c:1766,1776,2419`).
- **Fix:** Sort with `qsort` over the same array (the comparator inputs `fb_sort`/`fb_sort_desc` are already file-static state; the comparator needs only a signature adaptation), or sort a pointer array and reorder once. No new machinery — libc `qsort` is already linked by the card tool.
- **Benefit:** Worst-case sort work drops by roughly two orders of magnitude (INFERRED); large-folder listings complete noticeably sooner after the device read finishes.
- **Effort:** S. **Risk:** Low (sort stability: insertion sort is stable, `qsort` is not — the comparator already falls back to name comparison on ties, so visible order is unchanged for distinct names; identical name+size+date duplicates could swap, cosmetically only). **Confidence:** High (READ).

### T3-4 / MMCE active-card history prune re-enumerates the folder for every generation it deletes / Category 5
- **Location(s):** `src/dash_browser.c:1435-1456` (`activeHistoryPrune`), enumeration at `:1329-1355` (`activeHistoryScan`).
- **Problem:** The same shape round 2 filed for the card tool's safety copies (LAUNCHSTATION-039) exists independently in the browser's MMCE history: the prune loop calls the full folder enumeration once per deleted generation (up to the 256-iteration guard), each pass re-opening the folder and re-reading every dirent. With `mmce_backup_keep` generations to trim after a long history, that is one full directory scan per file removed, over MMCE/SD-class storage.
- **Fix:** Enumerate once, collecting every matching name (the scan already walks them all), sort the names (they are timestamped, so lexical order is age order — the code already relies on that for "oldest"), and delete the excess from the list. The re-scan loop goes away; no new state.
- **Benefit:** Pruning costs one directory enumeration instead of one per deleted generation.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## Revisions forced by Task 3 evidence

- **R3-R1 — LAUNCHSTATION-052 undercounts: the FILEOP_TRACE guard block has FOUR copies, not three.** Round 2 listed `src/filer_fileops.c:5-12`, `src/filer.c:157-164`, `src/filer_copy.c:23-30`. A fourth identical block sits at `src/filer_mount.c:6-13` (grep-verified this round: exactly those four files contain the `#ifndef FILEOP_TRACE` guard). The fix in -052 (define once in the shared header) is unchanged; the deletion count grows by one copy (~8 lines).
- **R3-R2 — LAUNCHSTATION-047's endian-helper census missed a sixth file.** `src/mc_card_export.c:163,168` define `read_le16`/`read_le32` — the same helpers as the other five mc_* files, under different names (which is presumably why the round-2 census, keyed on `rd16`/`rd32`, missed them). -047's fix (one shared header) should take these two as well; its "~45 lines" estimate grows by ~10.

## Checked in Task 3 and deliberately NOT flagged

- **mc_card_view.c (543 lines, full read)** — the hostile-image reader is bounded throughout: geometry cross-checked from three independent fields, FAT walks step-capped, chain reads length-checked, the fingerprint walk has depth and entry budgets. No finding; this is the standard the IOP parsers should be compared against.
- **mc_card_write.c (1,112 lines, full read)** — crash-safe write order with read-back verify, cross-link detection before delete, `.psu` import bounds-checked field by field. One candidate dissolved on reading: the format loop writes `BATCH` (32) clusters per iteration past `n` if `n % 32 != 0` — but the permitted sizes (1–64 MB, powers of two) make `n = size_mb × 1024`, always a multiple of 32. Not a bug today; it would become one only if a non-power-of-two size were ever admitted.
- **mc_ps1_card.c (445 lines, full read)** — chain walking is loop- and bounds-checked (`walkChain` seen-bitmask, cross-save sharing rejected in `chainOf`); the two `strcpy(out->name, …)` calls are safe by construction (source name passed `ps1NameOk`'s ≤20-char check into a 21-byte field).
- **mc_save_export.c (504 lines, full read)** — `.psv`/`.psx`/`.zip` builders validate counts and totals before allocating and before every `memcpy`; the zip writer rejects `..`/separator names. `mcPsvFileName`'s callers in the files read this round all pass 80-byte buffers (`src/dash_card_tool.c:619,749` and `ctAllExport`), comfortably above its ≤45-byte worst output. The AES keys in this file are the published PS3-era format constants the .psv/.mcx formats require — interoperability data, not a credential; not flagged and not reproduced.
- **filer_device.c (231 lines, full read)** — the transfer-stack gate logic is explicit and fail-closed where it matters (MX4SIO/mc1, UDPFS/SMB, UDPFS/host incompatibilities are refused, not worked around). No finding.
- **filer_mount.c (238 lines, full read)** — `strcpy(mountedParty[i], party)` writes into `char[MOUNT_LIMIT][MAX_NAME]` (`include/launchelf.h:568`); partition names reaching it come from the HDD partition layer, bounded below `MAX_NAME` (INFERRED — the producers were not all traced). The `#ifdef DVRP` mount code is live (`DVRP` is defined in the EE target, `ps2.yaml:620`), not dead code.
- **dash_browser.c remainders** — path construction is `snprintf`-checked throughout (`fullPath` returns truncation as failure and every caller honours it); `opConvertCard`'s `strcpy(dot, new_ext)` replaces an extension with an equal-length literal inside a `MAX_NAME` buffer — safe by construction, dissolved. `opBookmark`'s `strcat(dir, "/")` is bounded by the preceding `dashStrCopy(…, sizeof(dir) - 1)`, dissolved. The menu's eight static index arrays are counted in T3-2, not filed separately.
- **dash_card_tool.c remainders** — every mutating path runs the documented sequence (served-card refusal, safety copy, crash-safe write, reopen-and-verify); `ctLoadPsu` caps input at `CT_PSU_MAX` (8 MB + 512 KB) before allocating; name-generation loops are bounded (1–99 / 1–999) with `snprintf` truncation checked. No new Cat 6 candidate survived reading.
