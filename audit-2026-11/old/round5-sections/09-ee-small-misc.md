# ROUND 5 — Section 09: EE small/misc remainder + status sweep (Launchstation)

- Repo: NathanNeurotic/Launchstation, clone `~/workspace/audit-clones-2026-11-13/Launchstation`
- Pin: `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (verified, not fetched/updated)
- Method: READ ONLY. `git status --porcelain` empty at start and at end. No build, no hardware claims.
- Scope honoured: LAUNCHSTATION-001…096 not re-filed; `src/mc_save_formats.c:40-175` (Round-2 checked-clean caps) not re-audited; the Round-3 mc_* EE files (`mc_card_write/view/export`, `mc_save_export`, `mc_ps1_card`) not touched; `src/filer_fileops.c:5-12` trace block (-052) and `src/dash_apps.c:178-187` title.cfg template (X-18) not re-filed; `src/smb_shares.c:260-324` (Round-3 caller-clean for -066) excluded, remainder read; `src/editor_file.c:230-232,296-298` unchecked genWrite (pass 1) stands, not re-filed.
- Confidence labels: **READ** = seen in the source at the cited line in this round. **INFERRED** = conclusion depends on a caller, a format limit, or reachability not proven in this section.

---

## (a) Coverage ledger — Section A (every file read in full)

All files are `src/<name>`; line counts are `wc -l` at the pin. `src/mc_save_formats.c` was read for lines 176–954 only in this round (1–175 in earlier rounds).

| File | Lines | File | Lines |
|---|---|---|---|
| dash_font.c | 940 | dash_gfx.c | 938 |
| dash_lib.c | 937 | dash_devices.c | 921 |
| dash_icons.c | 915 | main_actions.c | 886 |
| dash_store.c | 870 | elf.c | 854 |
| dash_bg_ps2.c | 825 | dash_art.c | 815 |
| filer_fileops.c | 808 | mmce_igr.c | 804 |
| dash_apps.c | 775 | main_startup.c | 757 |
| main_title.c | 753 | dash_files.c | 732 |
| dash_ps1_card.c | 716 | editor_input.c | 705 |
| editor.c | 688 | smb_cnf.c | 657 |
| font_uLE.c | 652 | lang.c | 642 |
| dash_bg.c | 602 | dash_home.c | 565 |
| pad_ds34.c | 519 | gui_neutrino.c | 518 |
| dash_sound.c | 498 | smb_shares.c | 487 (260–324 excluded, prior round) |
| dash_clock_sync.c | 482 | mmce_save_versions.c | 475 |
| virtual_keyboard.c | 464 | pad.c | 456 |
| dash_info.c | 446 | makeicon.c | 426 |
| psu_functions.c | 423 | gui.c | 406 |
| dash_worker.c | 405 | draw.c | 402 |
| neutrino_iso.c | 401 | popstarter_path.c | 399 |
| main_info_screens.c | 394 | ember.c | 393 |
| main.c | 378 | config_startup.c | 364 |
| draw_text.c | 363 | config_network.c | 362 |
| config_screen.c | 361 | pc_game_receiver.c | 354 |
| mmce_card_switch.c | 348 | main_menu.c | 348 |
| dash_bg_geo.c | 333 | config_advanced.c | 329 |
| editor_file.c | 324 | dash_image.c | 313 |
| neutrino_gameid.c | 261 | popstarter_gameid.c | 259 |
| popstarter_vcd.c | 257 | main_console_info.c | 255 |
| main_gameid.c | 241 | dash_png.c | 241 |
| editor_menu.c | 229 | popstarter_elf.c | 217 |
| main_history.c | 208 | draw_gs.c | 206 |
| neutrino_smb.c | 187 | dash_jpeg.c | 183 |
| dash_exploit.c | 169 | ember_gameid.c | 165 |
| dash_theme.c | 148 | main_gameid_table.c | 136 |
| dash_ftp.c | 134 | editor_rules.c | 123 |
| popstarter.c | 112 | remote_control.c | 111 |
| main_boot.c | 97 | gui_sort.c | 95 |
| mc_sha256.c | 94 | ftp_session.c | 92 |
| main_fileops.c | 88 | gui_colors.c | 86 |
| hdl_rpc.c | 83 | dash_smbd.c | 83 |
| gui_hdd0_format.c | 75 | main_modules.c | 71 |
| chkesr.c | 60 | gui_texteditor.c | 26 |
| timer.c | 11 | mc_save_formats.c | 954 (176–954 this round) |

Section A total audited this round: 89 files, ≈36,600 lines (plus the data/vendored files in (c)).

---

## (b) Findings

### T9-F1 / Text editor writes one row-width entry per text row into a 2,048-entry array with no bound — a many-line file overruns it / Category 6

- **Locations:** `src/editor_rules.c:26` (`Editor_nRowsWidth[Editor_nRowsNum] = Editor_nCharRows; Editor_nRowsNum++;` inside the per-character loop of `editorApplyRules`); array declared `src/editor.c:11` / `include/editor_private.h:63` as `Editor_nRowsWidth[MAX_ENTRY]` with `MAX_ENTRY = 2048` (`include/launchelf.h:205`); editor accepts files up to 512 KiB (`src/editor_file.c`, `editorOpen`, size cap `512 * 1024`).
- **Problem:** Row count is a function of file content, not of the array. A 512 KiB file of two-byte lines (`"a\n"` repeated) yields ~262,000 rows; `editorApplyRules` writes past entry 2047 into whatever follows the array in BSS for the remaining ~260,000 rows, on any open/scroll/edit that recomputes rules. No clamp, no early-out, no dynamic sizing anywhere on this path (READ).
- **Fix:** Stop the row loop (or the write) at `MAX_ENTRY - 1` rows and treat the rest of the file as one trailing row — or refuse files whose row count exceeds the array with the existing load-error dialog. Deletion-shaped: one bound check at `src/editor_rules.c:26`.
- **Benefit:** Removes a content-triggered BSS corruption reachable by opening an ordinary (if line-dense) text file in the shipped editor.
- **Effort:** Small (one guard plus a decision on the tail-row behaviour; the render loop at `src/editor.c:528-529` already only reads `Rows_Num + Top_Height` entries).
- **Risk:** Low. Behaviour changes only for files that currently corrupt memory.
- **Confidence:** READ.

### T9-F2 / Editor navigation rules read one row-width entry before/after the cursor's row, and past the last row after the Home/End scans / Category 6

- **Locations:** `src/editor_rules.c:66-67` (`Editor_nRowsWidth[i + 1]`, PushRows-up branch); `src/editor_rules.c:89-92` (`Editor_nRowsWidth[i - 1]`, PushRows-down branch); `src/editor_rules.c:42,65,87` (`Editor_nRowsWidth[i]` after a scan loop that can exit with `i == Editor_nRowsNum`).
- **Problem:** In the PushRows-up branch the scan can leave `i` on the last row, making `i + 1 == Editor_nRowsNum` (one past the last valid entry; at the array limit from T9-F1, one past the array). In the PushRows-down branch the scan can leave `i == 0`, making `i - 1 == -1`. The Home/End scans post-decrement with `Editor_nRowsWidth[i]` where `i` can equal the row count when the cursor sits at the very end of the text. All are reads of adjacent BSS, feeding cursor arithmetic — wrong cursor positions at best (INFERRED reachability; the unguarded indexing itself is READ).
- **Fix:** Clamp `i` to `[0, Editor_nRowsNum - 1]` once after each scan loop, and guard the `i ± 1` reads with the same bound. No new code paths.
- **Benefit:** Cursor math stops depending on out-of-range BSS values at file start/end — the two positions every editing session visits.
- **Effort:** Small.
- **Risk:** Low.
- **Confidence:** INFERRED (indexing READ; exact reachability of each edge depends on cursor/scroll state combinations not executed here — no build/hardware in this audit).

### T9-F3 / Classic yes/no and info dialogs `strcpy` unbounded caller text into fixed stack buffers that several callers already exceed / Category 6

- **Locations:** `src/gui.c:20` (`ynDialog`: `strcpy(msg, message)` into `char msg[512]`); `src/gui.c:111` (`nonDialog`: same into `char msg[80 * 30]` = 2,400). Oversized callers: `src/lang.c:537,564,571` (error report built in `char tmp_s[4096]`, passed to `ynDialog`); `src/main_exploit_installer.c:1004,2487` (`ynDialog(msg)` where `msg` is `char[MAX_PATH + 96]` = 1,121 bytes with a full path interpolated by `snprintf`).
- **Problem:** The dialog is the sink for exactly the strings most likely to be long — error reports and path-bearing confirmations. A language-load failure report, or an exploit-installer overwrite confirmation for a near-`MAX_PATH` (1,025) path, is longer than 512 bytes by construction and overwrites `ynDialog`'s stack frame. `nonDialog` has the same shape with a larger, still fixed, ceiling (READ for the copies and buffer sizes; INFERRED for how often real inputs cross 512 bytes).
- **Fix:** Bound both copies to their buffers (`dashStrCopy`-style truncation already used across the dashboard) — the dialogs word-wrap and clip visually anyway, so truncation loses nothing on screen. One-line change at each site; no caller changes.
- **Benefit:** Closes a stack overwrite on the two most-called classic UI entry points, including an error path (`lang.c`) that fires precisely when something else already went wrong.
- **Effort:** Small.
- **Risk:** Low.
- **Confidence:** READ (mechanism); INFERRED (frequency).

### T9-F4 / HDL RPC wrappers `strcpy` into 33- and 64-byte packet fields with no length check — safety exists only in today's callers / Category 6 (latent)

- **Locations:** `src/hdl_rpc.c:60` (`strcpy(Packet->Partition_Name, PartName)`, field `char[32 + 1]` at `src/hdl_rpc.c:11` of the packet struct); `src/hdl_rpc.c:77-78` (`strcpy` into `OldName[64]` / `NewName[64]`).
- **Problem:** Neither wrapper validates its input. Current callers happen to be safe — partition names are capped by `MAX_PART_NAME = 32` (`include/launchelf.h:202`) and the rename flow caps the new title via `dashModalKeyboard(..., MAX_PART_NAME - 1)` in `src/dash_hdd.c` (`actRenameGame`) — but the RPC layer is the last code before a fixed DMA packet (`Rpc_Buffer[1024]`, `src/hdl_rpc.c:7`), and any future or alternate caller with a longer string corrupts the adjacent packet/RPC state silently (READ).
- **Fix:** Reject (return -1) when `strlen` meets/exceeds the field size, in the two wrappers only. No new abstraction.
- **Benefit:** The invariant moves to the one place that owns the field sizes; callers keep working unchanged.
- **Effort:** Trivial.
- **Risk:** Low.
- **Confidence:** READ.

### T9-F5 / Four libhdd entry points have no caller anywhere in the tree, and the one filesystem-list walker among them `strcpy`s dirent names into a 32-byte field / Category 1 + 6

- **Locations:** Dead (grep over `src/`, `iop/`, `loader/`, `include/`, `ps2.yaml`: zero call sites): `hddGetFilesystemList` (`ee_libs/hdd/libhdd.c:135`), `hddGetInfo` (`ee_libs/hdd/libhdd.c:253`), `hddRemoveFilesystem` (`ee_libs/hdd/libhdd.c:459`), `hddExpandFilesystem` (`ee_libs/hdd/libhdd.c:473`). Live libhdd entry points for contrast: `hddCheckFormatted`, `hddCheckPresent`, `hddFormat`, `hddMakeFilesystem`. Unsafe copy inside the dead walker: `ee_libs/hdd/libhdd.c:173,178,183` — `strcpy(hddFs[count].name, dirEnt.name…)` into `char name[32]` (`ee_libs/hdd/include/libhdd.h:44`), while the same function formats the sibling field with `%.34s` (`ee_libs/hdd/libhdd.c:167`), i.e. the code itself expects names longer than 31 characters.
- **Problem:** ~200 lines of uncalled HDD filesystem management ship in the EE link surface (LESS-NOT-MORE: they are maintained, security-relevant-looking code that does nothing), and if `hddGetFilesystemList` is ever revived as-is, a maximum-length partition name overruns `name[32]` (READ for the absence of callers and the copy; INFERRED for the exact maximum dirent length on a real APA disk).
- **Fix:** Delete the four uncalled functions and their `include/libhdd.h` declarations. If the project wants a filesystem list later, the dashboard's own HDD code already enumerates partitions.
- **Justification (if ADD):** n/a — pure deletion.
- **Benefit:** Smaller EE binary and audit surface; removes a latent overflow by removing its only container.
- **Effort:** Small (confirm no IOP-side or test reference — host tests do not reference libhdd by grep).
- **Risk:** Low.
- **Confidence:** READ (deadness, by whole-tree grep at the pin).

### T9-F6 / BCD conversion is copy-pasted at least four times, twice inside one file / Category 2

- **Locations:** `src/main_title.c:46` and `src/main_history.c:22` — byte-identical `bcdToInt` bodies (`((value >> 4) * 10) + (value & 0x0F)`); `src/dash_clock_sync.c:251,256` (`toBcd`/`fromBcd`) and again `src/dash_clock_sync.c` manual-clock section (`manualToBcd`/`manualFromBcd`, identical bodies, ~150 lines later in the same file).
- **Problem:** Four implementations of a two-line, spec-defined conversion (PS2 RTC BCD). The in-file duplication in `dash_clock_sync.c` is the telling part: the manual-entry half was written as if the SNTP half's helpers did not exist. Any fix to BCD edge handling (e.g. invalid nibbles from a corrupt RTC read) must currently be made four times, and the copies can drift.
- **Fix:** Delete the `manual*` pair and call the file-local `toBcd`/`fromBcd` in `dash_clock_sync.c`; leave the two cross-file `bcdToInt` copies or fold them into the existing clock helpers in `main_title.c` — the in-file half is the net win with zero linkage change.
- **Benefit:** −2 functions, one BCD definition per file at most.
- **Effort:** Trivial.
- **Risk:** Low (bodies verified identical, READ).
- **Confidence:** READ.

### T9-F7 / PNG decoder open-codes its flush-row block three times; the JPEG decoder beside it already has it as a function / Category 2

- **Locations:** `src/dash_png.c` — the accumulator-flush block appears at the interlaced path (~lines 120–128 of the file body), the streaming path, and the final flush (three near-identical copies, each: per-column divide by `acc_n`, alpha halving, `dst[cur_dy * dw + x] = …`, then two `memset`s); contrast `src/dash_jpeg.c:30-41` (`flushRow`, one function, called twice).
- **Problem:** The pixel-packing expression — including the GS alpha `(a + 1) >> 1` quirk — lives in three places in one file. A fix to alpha or channel order must be replicated perfectly or the interlaced and non-interlaced paths diverge visually.
- **Fix:** Extract the block as a static `flushRow`-equivalent in `dash_png.c` (mirroring the JPEG file's existing shape) and call it three times. Net lines decrease.
- **Benefit:** One definition of dashboard PNG pixel packing; the two decoders become structurally parallel.
- **Effort:** Small.
- **Risk:** Low.
- **Confidence:** READ.

### T9-F8 / `dashPngDecode` dereferences its out-parameters without the NULL checks its JPEG sibling performs / Category 6 (minor)

- **Locations:** `src/dash_png.c` (`dashPngDecode`): `*out = NULL;` as the first statement, and `*out_w`/`*out_h` written at the end, with no NULL test on any of the three; contrast `src/dash_jpeg.c:56-59` (`dashJpegDecode` returns -1 when `out`/`out_w`/`out_h` is NULL). Current in-tree caller `dashPngLoadFile` (same file) passes valid pointers (READ).
- **Problem:** Latent only: the public decode entry point crashes on a NULL out-parameter instead of failing, inconsistent with the sibling API it is documented alongside. Any future caller probing with a NULL sink hits a null deref on the EE.
- **Fix:** Add the same three-way NULL check the JPEG decoder already has (three lines, copied shape).
- **Benefit:** The two bounded image decoders present one contract.
- **Effort:** Trivial.
- **Risk:** Low.
- **Confidence:** READ.

### T9-F9 / A ~55-line commented-out font-dump function is carried in draw.c / Category 1

- **Locations:** `src/draw.c:343-399` — `WriteFont_C` in its entirety inside a `/* … */` block (header comment at :343-345 even says "Comment it out if not used").
- **Problem:** Dead, uncompilable-as-written legacy code (it uses unbounded `sprintf`/`strcat` throughout) kept in a live drawing file. It invites accidental resurrection — uncommenting it reintroduces exactly the string handling the rest of the tree has been eliminating — and it is the only place in `draw.c` a reader must skip.
- **Fix:** Delete the block. Font generation is already owned by `scripts/gen_dash_font.py` (see docs/font-generation.md), so nothing is lost.
- **Justification (if ADD):** n/a — pure deletion.
- **Benefit:** −55 lines; one less trap.
- **Effort:** Trivial.
- **Risk:** None (comment text).
- **Confidence:** READ.

---

## (c) Data / vendored classification (no line audit, per assignment)

| File | Lines | Classification |
|---|---|---|
| `src/dash_font_data.c` | 9,657 | **Pure data.** Generated Roboto glyph atlases; header states "GENERATED by scripts/gen_dash_font.py, do not edit" with Apache-2.0 Roboto notice. No executable logic beyond static array initialisers (READ, header + body sample). |
| `src/dash_font_emotion_engine.c` | 8,036 | **Pure data.** Same generator, Emotion Engine face (ps2.yaml:584). Static arrays only. |
| `src/dash_font_emotion_engine_bold.c` | 8,804 | **Pure data.** Same generator, bold face (ps2.yaml:585). Static arrays only. |
| `src/qrcodegen.c` | 1,027 | **Vendored.** Project Nayuki QR Code generator library (C), MIT, provenance and licence in the file header (lines 1–25, READ); pairs with `include/qrcodegen.h` (385 lines). Not project code; excluded from defect audit. |

Font-array total confirmed ≈26,497 lines as assigned.

---

## (d) Section B — status tables

### B1. `include/` — 66 headers (65 in `include/` + `include/snippets/readCD.h`)

Read-status key: **R5** = read fully this round; **Prior** = cited/read in Rounds 1–4 reports (grep of the four prior Launchstation reports for the header path); **Tabled** = inventoried only this round.

| Header | Lines | Status |
|---|---|---|
| main_history.h | 6 | R5 |
| lang.h | 7 | R5 |
| gui_texteditor.h | 8 | R5 |
| draw_private.h | 9 | R5 |
| gui_colors.h | 9 | R5 |
| gui_hdd0_format.h | 9 | R5 |
| gui_sort.h | 9 | R5 |
| main_info_screens.h | 9 | R5 |
| main_boot.h | 10 | R5 |
| main_modules.h | 10 | R5 |
| ftp_session.h | 12 | R5 |
| smbd_devctl.h | 12 | R5 |
| wle_igr_config.h | 13 | R5 |
| main_console_info.h | 14 | R5 |
| cdvd_macro.h | 16 | R5 |
| neutrino_gameid.h | 16 | Prior + R5 |
| pccf_control.h | 16 | R5 |
| neutrino_smb.h | 17 | R5 |
| filer_copy.h | 18 | R5 |
| filer_internal.h | 19 | R5 |
| hdd_header_injector.h | 20 | R5 |
| kelf_signer.h | 21 | R5 |
| main_gameid.h | 21 | R5 |
| list_scroll.h | 22 | R5 |
| main_title.h | 23 | R5 |
| mc_sha256.h | 24 | R5 |
| gui_neutrino.h | 26 | R5 |
| main_exploit_installer.h | 26 | R5 |
| dash_autotest.h | 27 | Prior + R5 |
| ftp_protocol.h | 29 | R5 |
| hdl_rpc.h | 29 | R5 |
| main_actions.h | 30 | R5 |
| self_update.h | 30 | Prior + R5 |
| main_startup.h | 31 | R5 |
| nfsman.h | 32 | Prior + R5 |
| psu_functions.h | 32 | R5 |
| dash_sound.h | 34 | R5 |
| smb2man.h | 37 | Prior + R5 |
| main_menu.h | 39 | R5 |
| dash_font_data.h | 41 | Prior + R5 |
| mmce_igr.h | 41 | R5 |
| psu_types.h | 42 | R5 |
| mmce_save_versions.h | 49 | R5 |
| snippets/readCD.h | 51 | R5 — a code snippet, not a declarations header: `#include`d by `src/filer.c:640` under a `LIBCDVD_LEGACY` guard (errors out if the macro is undefined, readCD.h:1-3). Its two `strcpy`s (:26 into `char[MAX_PATH]` from a MAX_PATH-bounded path; :37 into `FILEINFO.name[MAX_NAME]` from the CD TOC entry) belong to the already-audited filer.c section; no new finding filed here. |
| filer_actions.h | 52 | R5 |
| mc_card_export.h | 54 | R5 |
| mmce_card_switch.h | 54 | R5 |
| cloud_http.h | 56 | R5 |
| mmce_backup.h | 63 | R5 |
| dash_card_tool.h | 70 | R5 |
| dash.h | 71 | R5 |
| cloud_google.h | 83 | R5 |
| config_private.h | 86 | R5 |
| init.h | 88 | R5 |
| mc_card_view.h | 98 | R5 |
| mc_save_export.h | 99 | R5 |
| mc_save_formats.h | 99 | R5 |
| cloud_google_roots.h | 102 | Prior + R5 |
| editor_private.h | 112 | R5 |
| mc_card_write.h | 117 | R5 |
| mc_ps1_card.h | 128 | R5 |
| filer_shared.h | 133 | R5 |
| smb_shares.h | 144 | Prior + R5 |
| qrcodegen.h | 385 | Tabled — vendored Nayuki header, pairs with (c). |
| launchelf.h | 763 | Prior (core header, read across Rounds 1–4; not re-read line-by-line in R5) |
| dash_internal.h | 1,186 | Prior (core dashboard header, read across Rounds 1–4; not re-read line-by-line in R5) |

Summary: 63 of 66 read fully in R5 (every header ≤150 lines, plus all others ≤144); 3 tabled (qrcodegen.h vendored; launchelf.h and dash_internal.h prior-round core headers). No header ≤150 lines remains never-read. No new header-only defects found in the R5-read set (declarations, enums and inline bounds only; the one code-bearing header, readCD.h, is noted above).

### B2. `ee_libs/`, `loader/`, `research/`, `windows/` — read fully

| File | Lines | Status / notes |
|---|---|---|
| ee_libs/hdd/libhdd.c | 569 | Read fully. See T9-F5 (four uncalled entry points; latent `strcpy` at :173,178,183). Remaining functions (`hddFormat`, `hddMakeFilesystem`, `hddCheckPresent/Formatted`, `hddUpdateInfo`) use bounded formatting (`snprintf` at :167) — checked-clean apart from T9-F5. |
| ee_libs/hdd/include/libhdd.h | 91 | Read fully (in B1 method; `name[32]` at :44 is the T9-F5 field). |
| ee_libs/iopreboot/SifIopRebootBuffer.c | 246 | Read fully. Vendored PS2SDK-derived IOP-reboot payload sender; DMA sizes rounded and heap-checked (`SifAllocIopHeap` NULL → -1). Checked-clean. |
| ee_libs/iopreboot/patch_romdrv_set_rom1_info.c | 57 | Read fully. Header documents provenance: vendored from ps2sdk `ee/sbv/src/patch_romdrv_set_rom1_info.c` (AFL-2.0), one documented change (private aligned buffer). Validates ROMDIR values before patching. Checked-clean. |
| ee_libs/tcpips/ps2ipc.c | 815 | Read fully. PS2SDK-derived IPC socket shim; `memcpy`s are fixed-size `sockaddr`/packet copies, with `*addrlen`/`copylen` clamping visible at :134,329,634,661,691. Checked-clean for this pass. Its consumer in scope, `src/dash_clock_sync.c`, validates SNTP replies thoroughly (see (e)). |
| ee_libs/tcpips/VENDORED.md | 35 | Inventory: provenance note for ps2ipc.c. |
| loader/loader.c | ~380 (10,748 bytes) | Read fully. Validates ELF magic/type/machine/entry alignment before loading (`loadELFImage`); `mem:` path parsed with strict 8-hex-digit fields (`parseHex8`/`parseMemPath`); linker-only stub design is documented in-file and guarded by a discard section. Checked-clean (program-header bounds are trusted because the only payloads are the embedded loader image and the app's own ELF — INFERRED trust, noted, not filed). |
| loader/linkfile | 3,486 bytes | Inventory: linker script for the loader (not audited as code). |
| research/sd2psxtd/mmce_restore_txn_model.c | 203 | Read fully. Host-side transaction model for MMCE restore: identity re-verified under fence before staging, ambiguous journal errors force recovery state, identity copied with measured `strlen` (`memcpy(..., n + 1)` at :89 after `valid_identity`). Checked-clean; research code, not shipped in the EE build. |
| research/sd2psxtd/mmce_restore_txn_model.h + README.md | — | Inventory. |
| windows/cloud-relay/Cloud Relay.ps1 | 209 | Read fully. rclone relay: validates the remote exists, probes the PS2 FTP endpoint before copying, copy-only with `--ignore-existing` (never deletes/replaces cloud files), `-DryRun` supported, explicit exit codes 2/3/4. It connects to the anonymous FTP server already filed as LAUNCHSTATION-033/-040 (the FTP password argument is hardcoded in the script — location only, value not printed, per audit rules); no new finding filed — the relay inherits that already-filed posture. |
| windows/cloud-relay/Cloud Relay.bat + README.md | — | Inventory. |

### B3. `igr/`, `exploits/`, `ship/` — inventory

| Path | Contents | Status |
|---|---|---|
| igr/wle_igr.c | 268 lines | Classified: standalone IGR trampoline ELF source (separate binary, patched config block; not part of the EE app audit scope). Contents listed; not line-audited in this section. |
| exploits/ | 13 binaries + README.md (1,899 B) | Inventory only. README documents each payload's embed symbol via `src/embed_blobs.S` and states authorship/licences are not documented in-repo. `IOPRP.IMG` and `XSYSTEM2.XLF` unreferenced — already filed as LAUNCHSTATION-020, not re-filed. Sizes: SYSTEM/XSYSTEM/DTL-SYSTEM.XLF 13,896 B each; IOPRP_LTS.IMG 18,652 B; IOPRP.IMG 15,741 B; OSDSYS.KERNEL 7,056 B; OSD110.KERNEL 6,992 B; JPN/USA/EUR/CHN.sys 964 B each; list.icn 37,882 B. |
| ship/ | KIT-README.txt (6,322 B), kit-externals.json (10,615 B), neutrino-ilink/ (2 IRX + LICENSE + README), shortcuts/ (5 .url files) | Inventory only: release-kit packaging material and third-party iLink IRX binaries; no code audited. |

### B4. `scripts/` — 24 files, invocation status (grep evidence: `ps2.yaml`, `.github/workflows/*.yml`)

| Script | Invoked by build/CI? | Evidence / status |
|---|---|---|
| build_cloud_tls.sh | Yes | compile.yml (`bash scripts/build_cloud_tls.sh`); also referenced in ps2.yaml comment :23 |
| build_jpeg.sh | Yes | compile.yml; ps2.yaml :639 comment |
| check_ds34_build.py | Yes | compile.yml |
| check_loader_layout.sh | Yes | compile.yml |
| check_stack_realign.py | Yes | compile.yml (×2) |
| check_toolchain_purity.py | Yes | compile.yml |
| check_udpfs_smap.py | Yes | compile.yml |
| configure_ds34.py | Yes | compile.yml |
| copy_test_pack.py | Yes | compile.yml (×2) |
| download_metrics.py | Yes | compile.yml + download-metrics.yml |
| fetch_libsmb2.sh | Yes | compile.yml; ps2.yaml :294 comment |
| gen_cloud_client.py | Yes | compile.yml |
| gen_githash.py | Yes | compile.yml (`--require-git`) |
| package_apps.py | Yes | compile.yml |
| package_kit.py | Yes | compile.yml (fetch + package) |
| ps2build_sdk.sh | Yes | compile.yml + ps2build-sdk-watch.yml |
| release_notes.py | Yes | compile.yml (×2) |
| sync_github_wiki.py | Yes | sync-wiki.yml (also a path trigger) |
| audit_r3z_settings.py | No — one-off/manual tool | Referenced by docs/R3Z-CONFIG-PARITY.md and docs/R3Z-10-PARITY-AUDIT.md as a manually run generator/checker; no workflow invocation found. |
| ee_toolchain.sh | No — sourced helper | Sourced by the dependency build scripts (docs/BUILDING.md:67); not invoked standalone by any workflow. |
| gen_dash_font.py | No — manual generator | docs/font-generation.md, docs/BUILDING.md:29; also parsed by tests/test_font_weight.py. Produces the (c) font data files. |
| gen_sfx.py | No — manual generator | CHANGELOG.md:104 documents regeneration command; produces res/sfx_ps2/. |
| prepare_psbbn_theme.py | No — manual tool | docs/BUILDING.md:29, docs/dashboard.md:529. |
| stale_code_audit.sh | No — manual tool | docs/architecture-maintenance.md:72,83 documents manual runs. (LAUNCHSTATION-032 not re-filed; this completes its status row only.) |

Summary: 18 of 24 invoked by ps2.yaml/workflows; 6 manual/one-off (1 sourced helper, 5 documented manual generators/tools). `scripts/__pycache__/` is a stray directory entry, not a script.

### B5. `tests/` — 273 files

Pattern-classified in Pass 1 (LAUNCHSTATION-009 family: host tests largely scrape C source as text). Status by grep of the four prior Launchstation reports for `tests/` citations:

| Test path | Status |
|---|---|
| tests/test_self_update.py | Individually cited/read in prior rounds (Rounds 2/4 rework discussion; string-presence assertions quoted) |
| tests/test_app_packages.py | Individually cited in prior rounds |
| tests/test_update_sidecar_transaction.py | Individually cited in prior rounds |
| tests/test_browser_sort.py | Cited in prior rounds |
| tests/test_classic_settings_persistence.py | Cited in prior rounds |
| tests/test_navigation_wraparound.py | Cited in prior rounds |
| tests/ftp/ (incl. test_server.c) | Cited as a group in prior rounds |
| tests/smb2man_live/ | Cited as a group in prior rounds |
| tests/smbd_live/ (incl. host.c) | Cited as a group in prior rounds |
| All remaining ~264 files (host harnesses `*_host.c`, `card-tool-shim/`, `ftp-ee/`, `pccf-stubs/`, `nfsman_live/`, fixtures, remaining `test_*.py`) | **Pattern-classified only** — not individually read or executed in Rounds 1–4, and not in R5 (status sweep only, per assignment). Note: several correspond to code read in R5 (e.g. tests/test_smb_shares.py compiles src/smb_cnf.c on the host per that file's header) — correspondence noted, execution not claimed. |

### B6. `docs/` + `docs-site/` — inventory only (prose)

| Tree | Files | Size | Status |
|---|---|---|---|
| docs/ | ~161 files (incl. wiki/, plans/, superpowers/, licenses/, follow-ups/, theme-example/) | 676 KB | Inventory only, per assignment. (Stale-documents finding is LAUNCHSTATION-028, prior round, not re-filed.) |
| docs-site/ | 17 MB total, mostly static media (LAUNCHSTATION-008, prior round) | — | Inventory only: build.py, manifest.json, content/ (46 HTML pages), static/. |

---

## (e) Checked-and-clean (dissolved candidates, with reason)

- **pc_game_receiver.c (whole file)** — Request parser validates folder as exactly `DVD`/`CD` before the `strcpy` into `folder[4]` (:70-73), rejects names ≥ MAX_NAME or containing `/`/`\` (:71), caps items at 32, bounds all destination paths with `snprintf`/`%.255s` (:250,260-261), and the resume loop re-opens, re-seeks and verifies written size before rename. No defect found.
- **remote_control.c** — One-shot command file; `EXECUTAR` path is copied with `snprintf` into the caller's buffer (:87); malformed jobs are consumed once and reported. Its power (launch an ELF named by a file dropped over FTP) is a consequence of the already-filed anonymous-FTP posture (-033), not a new defect in this file.
- **smb_cnf.c (whole file)** — Exemplary parser: `copyValue` refuses overflow instead of truncating (:74-82), URL splitters validate IPv4 (including the leading-zero octal trap, :161-163), ports, share lengths, duplicate names and cross-version rules; builders check every `snprintf` before advancing. One nit not filed: the BOM test at `smbConfigParse` reads `line[1]`/`line[2]` of a possibly 1–2-byte string — a ≤2-byte over-read of the caller's own NUL-terminated buffer with no effect on the result; dissolved as no-consequence.
- **neutrino_smb.c** — `neutrinoSmbResolve`/`neutrinoSmbConfig` re-validate IPv4, port (445 only), share ≤63, credentials ≤31 ASCII, and the config rewriter refuses unknown/duplicate/multiline arg shapes before any write. Clean.
- **dash_clock_sync.c** — SNTP client validates mode, stratum (incl. stratum-0 refusal), origin-timestamp echo of its nonce, era handling and a 2020–2100 acceptance window, and verifies the RTC write by read-back within 2 s. Clean apart from the duplication in T9-F6.
- **mmce_save_versions.c** — Publish is staged (`.PART`), hash-verified by read-back, rename-no-replace; prune never removes the fresh version; marker written only after a fully clean pass. Clean.
- **psu_functions.c** — Restore path validates entry names against traversal (`psu_restore_name_ok`: empty/`.`/`..`/separators rejected) and pre-checks every entry's size against the file size (`psu_restore_check_entries` :400-402) before data is consumed; backup publish is temp-file + settle-aside throughout. Clean.
- **dash_jpeg.c** — Dimension caps (8192), scale-down before allocation, all four allocations NULL-checked before use, longjmp error path frees everything. Clean.
- **mc_save_formats.c:176-954** — Parsers (MCM/PSV/CodeBreaker/etc.) count and bounds-check records before filling output (`raw_len - pos < 36`, `size > raw_len - pos - 36` rejected), inflate output capped by `MAX_INFLATE` and exact-size verified. Clean. (Lines 40–175 not re-read, per assignment.)
- **mc_sha256.c** — Standard FIPS 180-4 implementation; block scheduling, padding and length encoding verified line-by-line against the spec shape. Clean.
- **elf.c `checkELFheader`/`RunEmbeddedLoader`** — Path copies are into `MAX_PATH` buffers from MAX_PATH-bounded callers; embedded loader header is magic-checked and entry alignment-validated before phdr copy. The remaining `sprintf`s at :776-800 build `bootpath` from a partition name + filename into a MAX_PATH buffer — bounded by caller contract (INFERRED); dissolved.
- **main_title.c software-clock seeds** — All three seed buffers are the same 24 bytes (`include/dash_internal.h:579`, `src/main_title.c:419,478`) and the value is sscanf-validated as a timestamp before the `strcpy`s at :433,484,491. Clean.
- **pad.c vs pad_ds34.c** — Not duplication to merge: alternative implementations selected by the DS34 build flag (ps2.yaml lists `src/pad.c` in the default build; `configure_ds34.py`/`check_ds34_build.py` handle the variant). Dissolved as a Cat-2 candidate.
- **dash_smbd.c password display** — The SMB server screen prints the server login/password (`src/dash_smbd.c`, `smbFrame`) so the user can connect from a PC, on the same screen that warns "Use a network you trust." By-design UX for a user-set credential; dissolved (the underlying server posture is the already-filed SMB/FTP family, not this screen).
- **gui_hdd0_format.c `getHddParty`/`getHddDVRPParty`** — `strcpy`+`strcat` into `MAX_PATH` from a MAX_PATH path plus a `MAX_NAME` entry name can in theory exceed the buffer only if the incoming path is already within ~255 bytes of the limit; all observed callers pass browser paths that already include the entry name or are partition roots. Dissolved as INFERRED-unreachable; the bounded `snprintf` used for the outputs (:party/:dir) is the part that matters.
- **lang.c external-language loader** — Both parse passes validate `index < LANG_COUNT` (first pass :`index >= LANG_COUNT` → fatal; second pass re-parses the identical, already-validated buffer), allocation is sized from the first pass, and read-back length is checked exactly. Clean apart from its T9-F3 dialog call.
- **editor_file.c (remainder)** — Load caps size at 512 KiB, mallocs are NULL-checked, streamed fallback is bounded by the same cap; the pass-1 unchecked `genWrite` lines stand as already filed. The 512 KiB cap is what makes T9-F1 reachable, but the cap itself is not a defect.
- **ftp_session.c / dash_ftp.c** — RPC exchange refuses to reuse DMA state after a timeout, checks the protocol version on every reply, and the unresponsive-FTP path asks the user before resetting the IOP over open files. Clean.
- **dash_lib.c / dash_store.c cache & settings writers** — `snprintf` accounting is checked per record (`dashLibBuildCache` breaks at `len >= cap - 1`); scan add paths reject `>= DASH_PATH_MAX`; save jobs free buffer and job on every failure branch. Clean.
- **chkesr.c, timer.c, gui_texteditor.c, main_boot.c, main_modules.c, gui_colors.c, gui_sort.c, dash_theme.c, ember_gameid.c, main_gameid_table.c (data), dash_exploit.c, popstarter.c** — Read fully; no defect meeting the bar (gui_sort's title comparison is case-sensitive where its name comparison is not — a sort-order cosmetic, dissolved as no-consequence).

---

## (f) Still-unread (exact)

Within the assigned scope, nothing is unread:

- Section A: all 89 files read (mc_save_formats.c lines 176–954 this round; 1–175 in prior rounds).
- Data/vendored: classified per (c), not line-audited, as assigned.
- Section B: every header ≤150 lines read in R5; ee_libs (4 code files + header + VENDORED.md), loader/loader.c, research model, Cloud Relay.ps1 read in full, as assigned.
- Tabled by assignment (inventory/status only, deliberately not line-audited in R5): `include/qrcodegen.h` (385, vendored), `include/launchelf.h` (763) and `include/dash_internal.h` (1,186) — both read in prior rounds; `igr/wle_igr.c` (268, classified); `exploits/` binaries; `ship/`; `docs/` + `docs-site/` prose; `tests/` beyond the B5 citation table; `loader/linkfile`.

— End of Section 09 —
