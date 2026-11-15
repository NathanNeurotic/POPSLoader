# Sable Audit — Launchstation, ROUND 5, Section 07: EE src/ big files, second tranche

- **Auditor:** Sable (section agent T7)
- **Pin:** `master` @ `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` — clone `~/workspace/audit-clones-2026-11-13/Launchstation`, HEAD verified at start; not fetched/updated.
- **Mode:** READ ONLY. `git status --porcelain` empty at start and finish (re-verified before delivery).
- **Rule:** LESS, NOT MORE. Findings LAUNCHSTATION-001…096 not repeated; earlier findings touching these files stand (notably -003 legacy-net flag in `config.c`, -015 pervasive sprintf/strcpy incl. the config-*save* chain, -016 unchecked genRead/genWrite, -026 `get_CNF_string`, -036 the 2,048-entry `FILEINFO` allocations at `filer_actions.c:311,404`, -045/-046/-052 filer helper duplications, X-21 / filer partial-copy items in `filer_copy.c:1193-1196,1628-1717`). No secret-like values are printed anywhere below; the cloud OAuth secret's *location* was already reported in pass 1 and is not repeated.
- **New findings: 7 (T7-F1…T7-F7). REVISION-CANDIDATEs: 0.**

---

## (a) Coverage ledger

Every line read end-to-end at this pin, in this session (READ):

| File | Lines | Coverage |
|---|---|---|
| `src/main_exploit_installer.c` | 1–2519 / 2519 | Full. All payload selection, KELF key-offset, MC wipe/scan, space estimation, install and UI flows. |
| `src/filer_actions.c` | 1–2259 / 2259 | Full (round 2 had read targeted sections only). Conflict probes, timestamp editors/organisers (SAS), `getFileSize`, `delete`, `Rename`, `newdir`, `make_title_cfg`. |
| `src/icon.c` | 1–2055 / 2055 | Full. The file is *pure data*: `icon_folder[1024]` (:2–1027) and `icon_warning[1024]` (:1030–2055), no code, no includes. Consumers verified: `src/draw.c:211,221`, declarations `include/launchelf.h:469-470`. |
| `src/config.c` | 1–1782 / 1782 | Full. `get_CNF_string` re-read but not re-filed (-026 stands); `legacy_net_drivers` sites re-read but not re-filed (-003 stands). |
| `src/dash_tools.c` | 1–1735 / 1735 | Full. Tools table/dispatch, cloud link/sync, update checker (GitHub release JSON), MMCE status job, cloud history browser, USB diagnostics. |
| `src/filer_copy.c` | 1–1400 / 1721 | Full read of the previously unread remainder (round 2 read :1400–1721 plus targeted sections). Move manifest, `filerGetGameTitle`, PSU backup/restore folder path, `copy()` through the file-open section at :1400. Lines 1401–1721 were **not** re-read this round (prior-round coverage; see §e). |

Supporting reads outside the section (for bounds/type verification only): `include/launchelf.h` (SETTING layout :281–349, `FILEINFO` :562–565, `MAX_PATH 1025`, `MAX_NAME 256`, `MAX_ELF_TITLE 72`), `include/psu_types.h` (`psu_header`/`mcT_header`), `include/filer_shared.h:40` (`MAX_RECURSE 16`), `src/filer_fileops.c:797-805` (`genCmpFileExt`), caller gating in `src/filer_browser.c:448-450`, `src/dash_browser.c:2823`, `iop/vmcman/include/mcman.h:32` (`EntryName[32]`).

---

## (b) Findings

### T7-F1 / CNF load copies file-supplied values unbounded into fixed `SETTING` fields — the 64-byte `Misc*` fields overflow on a ~65-char line / Category 6

- **Locations:** `src/config.c:962` (`strcpy(setting->LK_Path[i], value)`); `src/config.c:973-1004` (`sprintf(setting->Misc, "%s/", value)` and fifteen `sprintf(setting->Misc_*, "%s%s", setting->Misc, value)`); `src/config.c:1040-1048,1058-1067` (`strcpy` into `usbkbd_file`, `kbdmap_file`, `CNF_Path`, `lang_file`, `font_file`, `popstarter_file`, `ember_dir`, `neutrino_file`). Field sizes: `include/launchelf.h:285-300` (`Misc` and every `Misc_*` are `char[64]`), `:281-307` (`CNF_Path`/`LK_Path`/path fields are `char[MAX_PATH]` = 1025). Downstream sink of the same unbounded `LK_Path`: `src/config.c:1674` (`strcat(c, setting->LK_Path[i])` into a `char[MAX_PATH]` display buffer already holding an 11-char prefix).
- **Problem:** `value` is a whole CNF line, NUL-terminated by the parser but otherwise length-unbounded: the streamed preload accepts up to 128 KB (`src/config.c:441,483-497`), so a single value can be orders of magnitude longer than its destination. `Misc = <65+ chars>` overruns `Misc[64]`; any `Misc_* = <value>` overruns its 64-byte field once the `Misc` prefix is prepended; `LK_<key>_E1 = <1026+ chars>` and each path key overrun their 1025-byte fields. `setting` is one heap struct, so the overrun corrupts the following `SETTING` fields and then heap metadata. This is the *load* side: LAUNCHSTATION-015 filed the config-*save* chain's `sprintf` arithmetic and the general pattern, but no earlier finding cites these load sinks or the 64-byte destinations. That the bound is known and expected in this very function is proven in-file: the SMB user/password branches *do* length-check before copying (`src/config.c:1050-1053`, `strlen(value) < sizeof(...)`), and `LK_Title`/`PathPad` *do* use bounded copies (`:1088-1089,1098-1099`) — the fields above are the unconverted remainder.
- **Fix:** Convert exactly the cited copies to the bounded pattern already used at :1088-1089 in the same function (`strncpy` + forced NUL for the `char[MAX_PATH]` fields; `snprintf(field, sizeof(field), …)` for the `Misc`/`Misc_*` `sprintf`s). Replacement only, no new machinery, no format change: over-long values truncate, as `LK_Title` values already do today.
- **Benefit:** A crafted or merely corrupted `LAUNCHELF.CNF` (a file users routinely download, share and hand-edit) can no longer write past `SETTING` while being loaded at startup.
- **Effort:** S. **Risk:** Low — a path longer than its field already cannot work today; truncation makes the failure visible instead of corrupting.
- **Confidence:** READ for every destination size, the unbounded source length, and the absent checks; INFERRED for what a given overrun corrupts on hardware (depends on heap layout).

### T7-F2 / `preloadCNFFd`'s seek path has no size cap — the 128 KB cap exists only in the fallback it bypasses / Category 6

- **Locations:** `src/config.c:435-463` (seek path: `genLseek(SEEK_END)` result used directly as the allocation/read size at :446-455, terminated at :461); contrast `src/config.c:441,469-503` (fallback stream: `CNF_MAX_SIZE = 128 * 1024`, and a payload past the cap is explicitly rejected at :498-503 as "suspiciously large").
- **Problem:** The file's own stated policy is that a CNF over 128 KB is rejected. That policy is enforced only when `SEEK_END`/`SEEK_SET` *fails*. On every normal local device the seek succeeds, so a CNF of any size is allocated whole (`memalign(64, CNF_size + 1)`) and read with a single `genRead` whose short return is silently accepted as the whole file (:455-461: any `rd > 0` terminates the buffer at `rd`). A multi-MB "CNF" on USB/HDD therefore either crowds out the 32 MB EE (allocation succeeds) or silently parses a truncated prefix (short read) — behaviour the fallback path was written to prevent, applied only on the path that cannot be reached normally.
- **Fix:** Apply the existing constant in the seek path: if `cnf_seek_size > CNF_MAX_SIZE`, fail (or fall through to the streamed path, which already rejects). One comparison against a constant the same function already defines; no new limit, no new machinery.
- **Justification (if ADD):** Not an addition — it extends an existing in-function check to the path that lacks it.
- **Benefit:** One consistent CNF size policy on all devices; no unbounded file-size-driven allocation at startup.
- **Effort:** XS. **Risk:** Low — a legitimate CNF is a few KB; the fallback already treats >128 KB as invalid.
- **Confidence:** READ (both paths read in full; the cap and its absence are textual).

### T7-F3 / Exploit installer trusts card/dir-supplied entry names to be NUL-terminated — the one filer path without the codebase's own termination guard / Category 6

- **Locations:** `src/main_exploit_installer.c:1205-1214` (`wipe_mc_folder_contents`: `entries[i].EntryName` from `mcGetDir` passed to `strcmp` at :1209 and to `snprintf("%s/%s", …, name)` at :1213); `src/main_exploit_installer.c:1701-1723` (`estimate_existing_folder_kb`: `iox_dirent_t entry.name` from `fileXioDread` passed to `strcmp` at :1706 and `snprintf` at :1709). Name field width: `EntryName[32]` (`iop/vmcman/include/mcman.h:32`; the EE `sceMcTblGetDir` layout matches).
- **Problem:** A memory-card directory entry can occupy all 32 name bytes with no NUL, and a dirent name can fill its field the same way; neither consumer forces termination before treating the field as a C string, so `strcmp`/`%s` read past the field — past the end of the 8-entry stack scan array in the wipe loop's last slot. The codebase already treats exactly this input as untrusted elsewhere: `filerRenameCaseState` refuses any dirent whose name has no NUL in its field (`src/filer_actions.c:2103-2106`, `-EIO`), and LAUNCHSTATION-081 filed the same unterminated-name class inside mcman. These two EE-side consumers in the installer — one of which *deletes* by the name it read — were not covered by either.
- **Fix:** Force termination where the data lands, before any use: `entries[i].EntryName[sizeof(entries[i].EntryName) - 1] = '\0'` inside the wipe loop after each `mcGetDir`, and the `memchr` check (or forced NUL) on `entry.name` in `estimate_existing_folder_kb`, reusing the pattern at `filer_actions.c:2103`. Two one-line guards; nothing added structurally.
- **Benefit:** A crafted/corrupt card or directory can no longer make the installer read past its scan buffers — or delete a path assembled from bytes past a name field.
- **Effort:** XS. **Risk:** Near zero — a name that was correctly terminated is unchanged.
- **Confidence:** READ for both call sites, both absent guards, and the contrasting in-tree guard; INFERRED that the IOP/libmc layer can hand back a fully-filled, unterminated name field (consistent with -081's IOP-side evidence, not re-proven on the EE side here).

### T7-F4 / `delete()` and `getFileSize()` recurse with no depth limit — the guard `copy()` has (`MAX_RECURSE 16`) was never given to them / Category 6

- **Locations:** `src/filer_actions.c:1944-2047` (`delete`, recursive call at :1998; per-frame stack `char dir[MAX_PATH], hdddir[MAX_PATH]` at :1948 ≈ 2,050 bytes plus locals); `src/filer_actions.c:298-369` (`getFileSize`, recursive call at :324; per-frame `char dir[MAX_PATH]` at :303 plus `iox_stat_t`). Contrast `include/filer_shared.h:40` (`MAX_RECURSE 16`, "Maximum folder recursion for copy/PSU operations") enforced in `src/filer_copy.c:797-798`.
- **Problem:** Folder depth is bounded by nothing here except total path length: with 1–2-char folder names a `MAX_PATH` (1,025) path admits hundreds of levels, and each `delete` level carries ~2.1 KB of stack. The project's own comment puts the main stack at 128 KB (`src/filer_copy.c:744-745`), so a tree roughly 60 levels deep — easily produced by extracting a nested archive onto USB/HDD/host — can exhaust it mid-delete or mid-size-scan, i.e. during a destructive operation. `copy()` was explicitly protected against this shape; its two sibling traversals were not.
- **Fix:** Thread a depth counter through both functions exactly as `copy()` already takes `recurses`, failing with `-ELOOP` (the code already used for this at `src/main_exploit_installer.c:1694-1695`) past `MAX_RECURSE`. Internal wrappers keep the existing public signatures for the browser/dashboard callers.
- **Justification (if ADD):** The counter is an addition justified by a concrete crash: it reuses the existing constant, the existing parameter pattern and an existing error code; no new limit or policy is invented.
- **Benefit:** Delete/GetSize on a hostile or pathological tree fail cleanly instead of overflowing the stack halfway through a recursive delete.
- **Effort:** M (two functions plus their call sites). **Risk:** Low–Med — a legitimate tree deeper than 16 levels would now refuse; note `copy()` already imposes exactly that refusal on the same trees, so behaviour becomes consistent, not stricter than the status quo overall.
- **Confidence:** READ for the absent guard, both frame sizes, and the `MAX_RECURSE` precedent; INFERRED for the exact overflow depth on hardware (frame layout and stack size not measured here).

### T7-F5 / Three duplicated dead branches/includes: second DTL check, second PSX MagicGate block, second `mmce_igr.h` include / Category 1

- **Locations:** `src/main_exploit_installer.c:535-540` (in `get_psx_desr_payload`, the `dtl_signing_console` test at :539-540 repeats the test at :535-536 that already returned); `src/main_exploit_installer.c:2106-2116` (in `build_magicgate_result_message`, the second `if (console_is_PSX)` block at :2111-2116 is unreachable — the identical condition at :2106-2109 already returned, so the hard-coded OSDMenu message inside it can never display); `src/dash_tools.c:10,12` (`#include "mmce_igr.h"` twice, three lines apart).
- **Problem:** Dead duplicates that mislead maintenance: the MagicGate block in particular looks like the PSX failure path, but the live PSX path is the LNG string at :2107 — anyone editing the visible-but-dead text changes nothing on screen.
- **Fix:** Delete the second DTL test (3 lines), the unreachable PSX block (6 lines), and one duplicate include (1 line). Pure deletion, 10 lines.
- **Benefit:** The PSX MagicGate failure message has exactly one source; the payload selector reads as the three-way choice it is.
- **Effort:** XS. **Risk:** Near zero — all three are unreachable/redundant by construction (READ).
- **Confidence:** READ.

### T7-F6 / The CNF save text writes `PathPad_Lock` twice / Category 2

- **Locations:** `src/config.c:621` (inside the large settings block at :604-670) and `src/config.c:685-691` (the same key written again, alone, immediately after the launch-key-title loop).
- **Problem:** Every saved `LAUNCHELF.CNF` contains the key twice with the same value. Loading is idempotent (the second parse wins with the identical value), so this is not a correctness bug today — it is a duplicated writer for one setting, and the two copies can silently diverge the first time either block is edited.
- **Fix:** Delete the standalone second write at :685-691 (the block at :621 already emits the key in its settings group). Pure deletion, 7 lines.
- **Benefit:** One writer per key in the save format; saved files shrink by one line.
- **Effort:** XS. **Risk:** Near zero — the parser accepts the key once or twice identically.
- **Confidence:** READ.

### T7-F7 / `SETTING` allocations are dereferenced without a NULL check, in both places `config.c` creates one / Category 6

- **Locations:** `src/config.c:797-801` (`initConfig`: `setting = malloc(sizeof(SETTING))` at :799, first `sprintf(setting->Misc, …)` at :801); `src/config.c:1511-1513` (`config`: `setting = malloc(sizeof(SETTING))` at :1512, struct copy `*setting = *tmpsetting` at :1513).
- **Problem:** `SETTING` is a large struct (~25 KB: seventeen 1,025-byte paths plus titles, `include/launchelf.h:281-349`). On a 32 MB machine whose heap is routinely holding ~900 KB folder listings, either allocation can fail; both callers dereference the result unconditionally, turning an out-of-memory condition into a NULL write during startup config load or on entering the config screen — instead of the fallback-to-defaults behaviour a failed load otherwise gets (`loadConfig` returns -1 paths exist for every other failure in the same file).
- **Fix:** Check both results: in `initConfig`, return without a settings object only if callers tolerate it — otherwise keep the previous `setting` (it is freed at :797-798 before the allocation; allocate first, free on success, which also fixes the lose-the-old-settings-on-failure ordering). In `config()`, abort the screen (restoring `tmpsetting`) when the copy cannot be allocated. No new machinery.
- **Benefit:** Memory exhaustion during config load/edit degrades instead of crashing.
- **Effort:** S. **Risk:** Low.
- **Confidence:** READ for both absent checks and both immediate dereferences; INFERRED for how reachable allocation failure is in practice.

---

## (c) REVISION-CANDIDATEs

None. No earlier finding (LAUNCHSTATION-001…096, X-series) was contradicted by anything read in this section. In particular -003's `legacy_net_drivers` sites, -015's save-chain citations, -026's parser description, -036's `filer_actions.c:311,404` allocation citations and the `filer_copy.c:1193-1196,1628-1717` partial-copy items were all re-read in context and stand as filed; T7-F1 is the load-side remainder of the -015 pattern, filed separately because its destinations (64-byte fields) and trigger (a single CNF line) are materially worse than anything -015 cited.

---

## (d) Checked-and-clean (candidates examined and dissolved, with reasoning)

- **`src/icon.c` — no code, no finding.** Two fixed 1,024-byte texture arrays; consumers (`src/draw.c:211,221`) take them as fixed-size texture memory, so there are no file-supplied lengths to distrust. The arrays' size is a compile-time property, not data-driven.
- **`get_kelf_key_offset` (`src/main_exploit_installer.c:1132-1157`) — bounded as written.** Header-supplied `KELF_header_size` is rejected if `> size`; the flag-byte read at :1148 is preceded by `key_offset >= size` rejection (:1145-1146); the final check (:1152) rejects `key_offset < 0` and `key_offset + 32 > size` before any caller copies the 32-byte key (`bind_payload_to_memory_card` :1339-1347 also short-circuits the `key_before` compare on failure, so the uninitialised buffer is never read). Residual: whether `BIT_count * sizeof(SecrBitBlockData_t)` (:1144) can wrap `int` depends on `BIT_count`'s width in PS2SDK's `libsecr.h`, which is not in this repo — recorded as INFERRED-unverifiable here, not filed.
- **`make_title_cfg`'s `ELF_NAME[strlen(ELF_NAME) - 4]` (`src/filer_actions.c:1923`) — cannot underflow as gated.** Both callers reach it only when the menu built the entry from `genCmpFileExt(file->name, "ELF")` (`src/filer_browser.c:448-450`; `src/dash_browser.c:2823`), and `genCmpFileExt` (`src/filer_fileops.c:797-805`) requires a `.` followed by `ELF`, i.e. a name of at least 4 chars (`.ELF`). The subtraction the in-code comment apologises for is safe under that gate. (Its remaining `strcpy`/`strcat` path assembly is an instance of -015's already-filed pattern; no distinct mechanism.)
- **Negative `PathPad[…]` index in `loadConfig` (`src/config.c:1095-1100`) — unreachable.** `i = atoi(name + 8)` is only checked against `i < MAX_PATH_PAD`, so a negative index would write before `PathPad` — but a `-` can never appear in a parsed name: `get_CNF_string`'s name scan (`src/config.c:130-131`) stops at any char `< 'A'` that is not a digit, and `-` (0x2D) then fails the mandatory `=` test at :137-138, aborting the parse before any value is returned. Digit-only suffixes give `i >= 0`. Dissolved on the parser's grammar (READ).
- **PSU title insert in `filerGetGameTitle`/`joinIconSysTitleLines` (`src/filer_copy.c:534-558,659-676`) — buffer sized exactly for it.** `out` is always a `FILEINFO.title` (`unsigned char[66]`, `include/launchelf.h:563`); the read is capped at 64 bytes (:669), the NUL goes at ≤64 (:672), and the line-join `memmove` inserts one separator byte, reaching at most index 65 — the "optional separator and NUL" the field's own comment budgets for. `title_line_break` is file-supplied but rejected unless `< length` (:539), and the :553 look-ahead reads at most `title[length]`, the NUL just written.
- **PSU header walk in `filerGetGameTitle` (`src/filer_copy.c:610-626`) — file-supplied count/size cannot loop or seek forever.** Each iteration must first succeed at a full 512-byte header read or the function exits; seeks are by that header's own padded size, so progress through the file is monotonic and bounded by its length. `PSU_head.name` is force-terminated before `strcmp` (:618).
- **`releaseJsonString` / `releaseAssetDigest` (`src/dash_tools.c:715-790`) — the hand-rolled GitHub JSON parsing is length-safe.** Extracted strings are rejected unless `0 < n < out_size` (:740); the digest must additionally match the `sha256:` prefix and be exactly 71 chars (:773) before it is trusted for update verification, and the asset's digest is refused if it appears past the next asset's `name` (:771). Escaped quotes inside a value would truncate that value and fail these checks, not overflow anything. No finding.
- **`cloudBrowseHistory` depth stack (`src/dash_tools.c:1194-1195,1342-1351`) — bound enforced before the push.** `parent_ids[12]`/`parent_names[12]` are indexed by `depth` only after the `depth >= 12` refusal at :1342; pops are guarded by `depth == 0` at :1265.
- **`install_system_xlf_targets` / `install_custom_ps2_targets` return values (`src/main_exploit_installer.c:1565-1593,1887-1919`) — no uninitialised `ret`.** Both scan for a selected target first and return early when none exists; the write loop therefore executes at least once and assigns `ret` on every path through it. The non-custom early returns at :1990-2007 skip only the custom-payload cleanup, and `custom_payloads` is provably empty on that branch (`memset` at :1952, filled only under `use_custom`).
- **`newdir` / `delete` / `filerGetGameTitle` unbounded path assembly (`src/filer_actions.c:1208,2023,2198-2253`; `src/filer_copy.c:594-597,633-643,849,873`) — no NEW finding.** These `strcpy`/`strcat`/`sprintf` path joins can in principle exceed their `MAX_PATH` stack buffers when a near-maximal path meets a maximal name, but that is precisely LAUNCHSTATION-015's already-filed pattern with no distinct trigger or sink in these instances; their UI inputs are additionally length-capped at the callers (folder names to 36 chars: `src/dash_browser.c:1143` area, `src/filer_browser.c:1440` area). Not re-filed.
- **`dash_tools.c` update "same build" prefix test (`src/dash_tools.c:978-980`) — harmless if over-eager.** A short `GIT_HASH` prefix-matching `latest` only routes the user to the "download anyway?" confirm; the strict ancestry check it bypasses is re-run on the not-same path, and no install proceeds without an explicit confirm in either branch.
- **`configBuildSaveTargetsFrom`'s `override_dir[0]` dereference (`src/config.c:325`) — no NULL caller exists in-tree.** Both entry points pass `setting->CNF_Path` (`src/config.c:344`, :1344), a struct field address, never NULL (READ over the function's call sites in this file and its dashboard caller path).

---

## (e) Still unread

- `src/filer_copy.c:1401-1721` — not re-read this round by design (round 2 read it end-to-end; its partial-copy defects are already filed as X-21 / filer items and were excluded from this section's scope). Nothing else in the assigned set is unread: `main_exploit_installer.c`, `filer_actions.c`, `icon.c`, `config.c` and `dash_tools.c` were read in full, and `filer_copy.c:1-1400` completes that file's cumulative coverage across rounds.
- Out of scope and untouched: `src/kelf_signer.c` (the signer's internals behind the installer's calls), PS2SDK's `libsecr.h` (see the `BIT_count` residual in §d), and every other EE/IOP file.
