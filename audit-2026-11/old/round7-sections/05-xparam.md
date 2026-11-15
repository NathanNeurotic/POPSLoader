# Round 7 — Section 05: Launchstation xparam database data validation (292 rows)

- **Scope:** `iop/xparam/src/database_merged.c` (887 lines, 292 data rows) in Launchstation @ `9fb0598a79f0` (pin verified held; `git status` clean in all five clones at start and end). READ-ONLY throughout.
- **Not re-filed:** LAUNCHSTATION-119 (`GET_XPARAM_DB_SIZE()` ≡ 1) and LAUNCHSTATION-185 (`_start` arg handling) — excluded per tasking, referenced only where the matcher logic defines the data's structural rules.
- **Method:** full-file parse of all 292 rows (scripted), structural checks against the matcher in `iop/xparam/src/xparam.c`, then factual validation against in-repo ground truth found in the sibling clones — principally RiptOPL's `docs/xparam/xparam/` reference set (see §3). No external knowledge used; no PS2 game-database facts imported from memory.

---

## 1. Row semantics (from `xparam.c` + `xparam.h`, read first)

- Row type `xparam_t` (`iop/xparam/include/xparam.h:28-32`): `char name[12]` (game ID), `uint32_t param`, `uint32_t value`.
- `param` is an index into the Deckard XPARAM register set, enumerated at `xparam.h:6-25`: 18 params, `0x00 PARAM_MDEC_DELAY_CYCLE` … `0x11 PARAM_CACHE_FLASH_CHANNELS`. The code implies **no per-param value range** anywhere: values are written verbatim to the single hardware slot `*((uint32_t *)0xFFFE01A4)` after `param` is written to `0xFFFE01A0` (`xparam.c:13-14, 58-59`). Delay params take cycle counts; `PARAM_MIPS_DCACHE_ON` is a flag whose *default* is 1 (see RiptOPL corroboration, §3) so database value `0x0` means "cache OFF for this game" despite the name.
- Matcher (`CheckGameID`, `xparam.c:52-63`): exact `strcmp(XPARAMS[i].name, ID)` — case-sensitive, full-string. It sets a found-flag `f` and **breaks on the first non-match after a match** (`xparam.c:61`), i.e. the table's contract is: *all rows for one game ID must be consecutive*. (The loop bound itself is LAUNCHSTATION-119; not re-filed.)
- Caller side confirms the ID format the matcher receives: `src/init.c:1348-1356` `applyXPARAM(const char *gameID)` passes the disc ID string through unchanged; RiptOPL's twin implementation truncates titles to exactly 11 chars (`RiptOPL/src/core/xparam.cpp:187-189`), matching the 11-char ID + NUL that fits `name[12]`.
- File header (`database_merged.c:3-5`) claims the table "merges ROMVER 2.50 Database with entries for all the games passing custom XPARAM via the `PARAM2` entry on SYSTEM.CNF" — the 6-row tail block under `#ifndef SKIP_GAMES_PASSING_XPARAM_FROM_SYSTEM_CNF` (`database_merged.c:865-886`). This claim is *testable* against the RiptOPL reference set, and it holds exactly (§3).

## 2. Structural pass — full 292-row ledger

All checks scripted over the parsed table (row numbers below are 1-based data-row ordinals; file lines cited where it matters).

| # | Check | Result |
|---|-------|--------|
| 1 | Row count | **292 rows exactly** (286 main body + 6 tail), **222 distinct game IDs**, 222 contiguous ID blocks |
| 2 | Malformed IDs vs matcher expectation | **0.** Every ID is exactly 11 chars, pattern `^[A-Z]{4}_\d{3}\.\d{2}$`, fits `name[12]` with NUL. Prefix census: SLPM 92, SLPS 84, SLES 40, SLUS 35, SLKA 15, SCUS 8, SCAJ 6, SCPS 6, SCES 3, SCKA 2, PAPX 1 (sums to 292) |
| 3 | Duplicate game ID with **conflicting** value (same ID + same param, different value) | **0.** No `(ID, param)` pair anywhere carries two different values |
| 4 | Duplicate **identical** rows (same ID + param + value) | ** exactly 1 pair:** `SLPM_660.22 / PARAM_MIPS_DCACHE_ON / 0x0` at rows 161–162, `database_merged.c:489` and `:492` → candidate **X7-1** (§4) |
| 5 | Non-consecutive duplicate IDs (would be shadowed by the `xparam.c:61` break) | **0.** Every ID occupies exactly one contiguous block (222 IDs = 222 blocks); the grouping contract the matcher assumes is satisfied by the data as filed |
| 6 | Ordering | Main body is strictly ascending by ID with zero descending steps; the 6-row tail block is unordered relative to the body (SLPS_256.23, SLPS_255.32, SLPS_255.56, SLPM_661.41, SLPM_627.09, SLPM_663.87) but all six IDs are unique to the tail, so grouping/matching is unaffected |
| 7 | Param census vs the 18-param enum | Only **5 of 18** params used: `PARAM_MIPS_DCACHE_ON` 195, `PARAM_CPU_DELAY` 67, `PARAM_DMAC_CH10_INT_DELAY` 16, `PARAM_CACHE_FLASH_CHANNELS` 12, `PARAM_DMAC_CH10_INT_DELAY_DPC` 2. All param tokens are named enum constants — out-of-enum params are impossible as written. The 13 unused params are not a data defect: they are simply absent from Sony's source database (§3) and remain settable via the explicit-arg path |
| 8 | Out-of-range values by the code's own semantics | **None provable.** The code defines no value ranges. Delay/flag value distributions are internally regular: `PARAM_MIPS_DCACHE_ON` is `0x0` in all 195 rows; no delay param is ever `0x0`; `PARAM_CPU_DELAY` values cluster on round counts (0xbb8 ×12, 0x780 ×7, 0xfa0 ×7, 0xa28 ×5…) with a tail of title-specific odd counts (0x596, 0x60e, 0x618, 0x622, 0x668, 0x67c, 0x6e0) that recur consistently for the same titles |
| 9 | Rows-per-game distribution | 164 IDs × 1 row, 47 × 2, 10 × 3, 1 × 4 (`SLES_528.45` Gadget & the Gadgetinis: CPU_DELAY 0x2ee0, DMAC_CH10 0x2ee0, DMAC_CH10_DPC 0x2bf20, DCACHE 0x0) |
| 10 | Cross-region consistency (same normalised title, different IDs) | **27 multi-ID title groups; 0 with differing param sets.** E.g. Chaos Legion in 4 regions (SLES_515.53 / SLKA_250.26 / SLPM_652.49 / SLUS_206.95) is identically {CACHE 0x0, CPU_DELAY 0xfa0, DMAC_CH10 0x708} everywhere; Tekken 5, Orphen, Driving Emotion Type-S, Jimmy Neutron, Onimusha, Star Ocean 3 all likewise agree across regions |
| 11 | `UNKNOWN TITLE` comments | 23 rows / 20 distinct IDs carry no title comment — a documentation gap inherited verbatim from the source dump (§3 shows the same UNKNOWN markers at the same positions in the reference), **not** filed: the IDs themselves are validated by the reference, and inventing titles would require external data this task forbids |
| 12 | Checked anomaly, **not** a defect | `SLPS_250.79` (Madden NFL Super Bowl 2002) is the only `PARAM_CACHE_FLASH_CHANNELS` row with a non-zero value (`0x10`; the other 11 are `0x0`). It is **present identically in the source reference** (`xparam_0250_20100415.c:671`), and RiptOPL's defaults table gives this param a default of `0x0090` (`RiptOPL/src/core/xparam.cpp:157`), i.e. it is a channel mask/count, not a boolean — `0x10` is in-family. No candidate |

**Structural bottom line:** apart from the single duplicated row (X7-1), the table is structurally clean — no conflicts, no malformed IDs, no grouping violations, no provable out-of-range values.

## 3. In-repo ground truth — what exists, and the full-corpus comparison

Ground truth for this data **does exist in-repo**, in RiptOPL (all paths under `~/workspace/audit-clones-2026-11-13/RiptOPL/`):

- `docs/xparam/xparam/xparam_0250_20100415.c` — a transcription of the ROMVER 0250 (2010-04-15) XPARAM database, header-noted "Total Entries: 286".
- `docs/xparam/xparam/xparam_0220_20050620.c` — the earlier 0220 database (272 entries).
- `docs/xparam/xparam/xparam_GamesList_0250_20100415.txt` / `..._20050620.txt` — per-ID title lists.
- `docs/xparam/xparam/xparamNotes.txt` (by krat0s) — provenance notes: the two BIOS XPARAM generations, what 0250 added, and the SYSTEM.CNF/PARAM2 "games from the disc" list.
- `src/core/xparam.cpp` + `include/xparam.h` — RiptOPL's *live* Deckard implementation, including the default-value table for all 18 params (`xparam.cpp:139-158`) and hard-coded handling of exactly the special cases (Tekken 5 CPU delay `0x780` as a string constant at `xparam.cpp:15`; the six disc-PARAM2 games at `xparam.cpp:27-50`, all "0x10 0 (DCACHE OFF)" per `xparam.cpp:218-219`).
- POPSLoader, PS2-Servers, Simple-Media-System: **no hits** for any sampled ID or for xparam data (grep across all three clones) — they hold no competing game database for this purpose.

**Full-corpus comparison (all 292 rows, not just the sample):**

1. Launchstation main body (rows 1–286) vs `xparam_0250_20100415.c` (286 rows): **sequence-identical in (ID, param, value) at every one of the 286 positions — zero diffs.** Set difference in both directions is empty once the tail is accounted for.
2. Launchstation tail (6 rows) vs the notes: all six IDs appear in `xparamNotes.txt:17-25`'s disc-PARAM2 list and in `CheckSpecialDiscXParamTitle` (`src/core/xparam.cpp:27-50`), all with the DCACHE-off semantics the tail rows encode. The file-header merge claim (`database_merged.c:3-5`) is therefore **exactly true**: 286 + 6 = 292.
3. Vs the 0220 database, Launchstation's differences are precisely the documented 0250 additions: `xparam.cpp:226-230` states 14 configs were added and "the previous ones were unchanged" — the set diff is exactly 14 (5 Tekken-5 `CPU_DELAY 0x780` rows for SCAJ_201.25/SCAJ_201.26/SCKA_200.49/SLPS_255.10/SLUS_210.59, the 2-row SCES_532.02 entry the notes call the previously-missing Australian Tekken 5, and 7 rows for the 6 new games incl. the doubled SLPM_660.22), plus the 6 disc-PARAM2 tail rows which are in *neither* BIOS database, as expected.
4. Honesty caveat: the RiptOPL reference is a sibling transcription of the *same* Sony source dump (independent in-repo copy, separately maintained, plus a live implementation written against it). Agreement therefore proves **transcription fidelity** of Launchstation's table to its claimed source — it is not independent hardware verification of Sony's original values, and nothing in this section should be read as such.

## 4. Factual spot-validation — 30-row sample

**Sampling method:** systematic — every 10th data row starting at row 1 (rows 1, 11, 21, …, 291), yielding exactly 30 of 292 rows (~10.3%), spanning the main body (29 rows) and the tail block (1 row, #291). Each sampled row was checked for an exact (ID, param, value) match in `xparam_0250_20100415.c` (line cited), title corroboration in `xparam_GamesList_0250_20100415.txt` (line cited), and a grep of the ID across POPSLoader / PS2-Servers / Simple-Media-System (no hits for any sampled ID).

| # | Row | LS line | ID | Param | Value | Verdict | Ground truth |
|---|-----|---------|----|-------|-------|---------|--------------|
| 1 | 1 | 9 | PAPX_905.17 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:5`; GamesList:3 |
| 2 | 11 | 39 | SCKA_200.49 | CPU_DELAY | 0x780 | **CONFIRMED** | `xparam_0250…c:35`; GamesList:10; also `xparam.cpp` Tekken-5 set |
| 3 | 21 | 69 | SCUS_971.67 | CPU_DELAY | 0xe10 | **CONFIRMED** | `xparam_0250…c:65`; GamesList:18 |
| 4 | 31 | 99 | SLES_500.73 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:95`; GamesList:25 |
| 5 | 41 | 129 | SLES_513.55 | CPU_DELAY | 0xbb8 | **CONFIRMED** | `xparam_0250…c:125`; GamesList:33 |
| 6 | 51 | 159 | SLES_522.14 | CPU_DELAY | 0xaf0 | **CONFIRMED** | `xparam_0250…c:155`; GamesList:39 |
| 7 | 61 | 189 | SLES_528.11 | CPU_DELAY | 0x1388 | **CONFIRMED** | `xparam_0250…c:185`; GamesList:48 |
| 8 | 71 | 219 | SLKA_250.80 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:215`; GamesList:53 |
| 9 | 81 | 249 | SLKA_252.57 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:245`; GamesList:61 (ID present; title UNKNOWN in both) |
| 10 | 91 | 279 | SLPM_620.78 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:275`; GamesList:70 |
| 11 | 101 | 309 | SLPM_622.52 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:305`; GamesList:78 |
| 12 | 111 | 339 | SLPM_624.08 | DMAC_CH10_INT_DELAY | 0x600 | **CONFIRMED** | `xparam_0250…c:335`; GamesList:87 |
| 13 | 121 | 369 | SLPM_650.52 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:365`; GamesList:95 |
| 14 | 131 | 399 | SLPM_652.09 | CPU_DELAY | 0xaf0 | **CONFIRMED** | `xparam_0250…c:395`; GamesList:101 |
| 15 | 141 | 429 | SLPM_653.08 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:425`; GamesList:108; named as a 0250 addition in `xparamNotes.txt:8` and `xparam.cpp:74-75` |
| 16 | 151 | 459 | SLPM_654.38 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:455`; GamesList:113 |
| 17 | 161 | 489 | SLPM_660.22 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** (value) — but this is the duplicated row, see X7-1 | `xparam_0250…c:485` **and** `:488` (duplicated in the source too); GamesList:123 (listed once); `xparam.cpp:62-64` |
| 18 | 171 | 519 | SLPS_200.07 | CPU_DELAY | 0xa28 | **CONFIRMED** | `xparam_0250…c:515`; GamesList:130 |
| 19 | 181 | 549 | SLPS_200.80 | CPU_DELAY | 0xfa0 | **CONFIRMED** | `xparam_0250…c:545`; GamesList:137 |
| 20 | 191 | 579 | SLPS_201.56 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:575`; GamesList:145 (title UNKNOWN in both) |
| 21 | 201 | 609 | SLPS_202.79 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:605`; GamesList:154 |
| 22 | 211 | 639 | SLPS_250.08 | CPU_DELAY | 0xbb8 | **CONFIRMED** | `xparam_0250…c:635`; GamesList:163 |
| 23 | 221 | 669 | SLPS_250.72 | CPU_DELAY | 0xb60 | **CONFIRMED** | `xparam_0250…c:665`; GamesList:170 |
| 24 | 231 | 699 | SLPS_251.58 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:695`; GamesList:177 |
| 25 | 241 | 729 | SLPS_252.59 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:725`; GamesList:187 |
| 26 | 251 | 759 | SLPS_255.10 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:755`; GamesList:194 (its companion CPU_DELAY row is a documented 0250 addition, `xparam.cpp` Tekken-5 set) |
| 27 | 261 | 789 | SLUS_204.25 | CPU_DELAY | 0x2134 | **CONFIRMED** | `xparam_0250…c:785`; GamesList:201 |
| 28 | 271 | 819 | SLUS_206.05 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:815`; GamesList:208 |
| 29 | 281 | 849 | SLUS_209.20 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | `xparam_0250…c:845`; GamesList:214 |
| 30 | 291 | 882 | SLPM_627.09 | MIPS_DCACHE_ON | 0x0 | **CONFIRMED** | Tail/disc-PARAM2 row — not in the BIOS databases by design; corroborated by `xparamNotes.txt:23` and `src/core/xparam.cpp:45` + `:218-219` (all six disc games use DCACHE off) |

**Sample tally: 30 CONFIRMED / 0 CONTRADICTED / 0 NO IN-REPO GROUND TRUTH.**
This is stronger than the task's expected outcome because the sibling clone happens to carry the exact source database this file claims to merge; the same comparison extended to all 292 rows (§3) also produced zero contradictions. The one imperfection the sample surfaced is the duplicated SLPM_660.22 row (#17), filed below as a structural candidate — its *value* is confirmed; only its duplication is at issue.

## 5. Candidates

### X7-1 / Duplicate identical row `SLPM_660.22` — the same (ID, param, value) filed twice consecutively / Category 2 (duplication)
- **Locations:** `iop/xparam/src/database_merged.c:489` and `:492` — two consecutive rows `{"SLPM_660.22", PARAM_MIPS_DCACHE_ON, 0x0}` under two identical `// Kaidou - Touge no Densetsu (Japan)` comments (data rows 161–162 of 292). This is the **only** duplicate (ID, param) pair, the only duplicate identical triple, and the only repeated row in the entire table (§2, checks 3–4, scripted over all 292 rows).
- **Problem:** The second copy can never change behaviour: `CheckGameID` (`xparam.c:57-60`) writes the same param/value to the same hardware slots twice. It is provably dead data — one wasted `xparam_t` (20 bytes) plus its comment block — in a file whose governing principle is LESS NOT MORE. **Provenance, stated honestly:** the duplication is inherited verbatim from the source — the RiptOPL reference transcription has it at `xparam_0250_20100415.c:485` and `:488`, and RiptOPL's live code documents it knowingly ("This config was added twice in newer XPARAM", `RiptOPL/src/core/xparam.cpp:62-64`). So this is a faithful-copy wart, not a Launchstation transcription error; deleting one copy makes Launchstation's table diverge from the ROMVER 2.50 dump by exactly one redundant row while changing no runtime behaviour on any game.
- **Fix:** Delete one of the two rows (and one of the duplicated comment lines), reducing the table to 291 rows / 286→285 in the main body. Alternatively keep for byte-fidelity to the dump and close as documented-wontfix — but as a data-cleanliness candidate it is the only one the file supports.
- **Effort:** Trivial (one row + one comment). **Risk:** None/Low — the surviving row applies the identical param/value; the only risk is philosophical (divergence from the source dump's row count). **Confidence:** High (READ — scripted census of the whole table + both in-repo references read).

**No other candidates filed.** Specifically not filed, with reasons: conflicting values (none exist); malformed IDs (none exist); non-consecutive grouping violations (none exist); out-of-range values (the code defines no ranges, and the one sibling-relative outlier, Madden's `CACHE_FLASH_CHANNELS 0x10`, is present in the source reference and in-family for a param whose default is `0x90`); `UNKNOWN TITLE` comments (inherited verbatim, and resolving them would need the external data this task forbids); 13 unused enum params (a property of Sony's source data, not of the transcription).

## 6. Coverage / limits

- Read end-to-end: `iop/xparam/src/xparam.c` (63), `iop/xparam/include/xparam.h` (37), `iop/xparam/src/database_merged.c` (887, all 292 rows parsed and checked), caller `src/init.c:1348-1356`; RiptOPL ground-truth set in full (`xparam_0250…c`, `xparam_0220…c`, both GamesLists, `xparamNotes.txt`, `src/core/xparam.cpp`, `include/xparam.h`).
- Grepped, no ground truth found: sampled IDs and xparam data across POPSLoader, PS2-Servers, Simple-Media-System.
- Nothing here is hardware-verified; factual verdicts mean "agrees with the in-repo transcription of the claimed Sony source", per the §3 caveat.
- `git status` clean in all five clones at end of section.
