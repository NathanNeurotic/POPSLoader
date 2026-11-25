# Launchstation — Blind Redo Audit: EE Application Core

- Clone: `~/workspace/audit-clones-2026-11-13/Launchstation`, HEAD `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (verified with `git rev-parse HEAD`).
- Method: read-only in the clone. No builds were run (no PS2 toolchain result is claimed anywhere below). Counts are script-generated (`wc -l`, `grep -c`). Every `path:line` below was opened/read in this session. Rule applied throughout: LESS NOT MORE — deletion is the preferred fix; no speculative additions.
- Scope: EE application core — main/boot/init/config, filer, dashboard, actions, settings, display/graphics/fonts/input, HDD and memory-card browsing, plus related `include/` headers. Network/cloud/SMB/Neutrino/FTP deep dives are excluded by assignment; those files are listed as not-read in the ledger, and only their call sites inside core files are cited.

---

## (A) Coverage Ledger

### A.1 Files read in full (line counts by `wc -l`)

| File | Lines | Notes |
|---|---|---|
| `src/main.c` | 378 | Read in full. |
| `src/timer.c` | 11 | Read in full. |
| `include/launchelf.h` | 763 | Read in full (SETTING layout, MAX_* constants, prototypes). |

### A.2 Files read substantially (large contiguous sections covering every mechanism cited)

| File | Lines | Sections read |
|---|---|---|
| `src/config.c` | 1782 | Helpers 38–111, `get_CNF_string` 111–162, save-text builder 533–719, `initConfig` 793–883, `loadConfig` 883–1161, `config()` entry 1492–1530 |
| `src/dash_main.c` | 1533 | Launch/misc dispatch 380–520, launch path 600–680, `DashRun` 1331–1533 |
| `src/filer.c` | 2556 | Retry helper ~340–390, `readMC`/`readXFROM` 475–570, `setFileList` dispatch incl. ATA/MX4SIO retry blocks 1980–2180 |
| `src/filer_copy.c` | 1721 | Buffer declarations 764, path assembly 849–1125 |
| `src/filer_actions.c` | 2259 | Recursive size/delete allocation sites ~295–320, ~1975–2000 |
| `src/draw.c` | 402 | Font-dump block 330–402 (incl. commented-out function) |
| `src/gui.c` | 406 | `ynDialog` 1–95, `nonDialog` 95–120 |
| `src/editor_file.c` | 324 | 59–324 incl. all result-delay loops and `editorSaveAs` 256–324 |
| `src/main_startup.c` | 757 | `scanSystemCnf`/`readSystemCnf` 130–210, region init ~249 |
| `src/lang.c` | 642 | Language-buffer handling 63, 164–166, 480–529; Misc rebuild 415–435 |
| `src/icon.c` | 2055 | Structure verified: two 1024-byte arrays, one byte per line (2–1027, 1030–2055) |
| `src/dash_editor.c` | 1494 | Header/design comment 1–30 only (used for the shadowing finding) |
| `include/dash.h`, `include/main_menu.h` | 71 / 39 | Prototypes for `DashRun` / classic menu functions |

### A.3 Files scanned by script only (grep/`wc` counts, targeted lines opened where cited)

`src/main_menu.c` (348), `src/main_title.c` (753), `src/main_actions.c` (886), `src/main_info_screens.c` (394), `src/config_screen.c` (361), `src/config_advanced.c` (329), `src/config_startup.c` (364), `src/filer_browser.c` (2528), `src/editor.c` (688), `src/dash_font.c` (940), `src/font_uLE.c` (652), `src/dash_font_data.c` (9657), `src/dash_font_emotion_engine.c` (8036), `src/dash_font_emotion_engine_bold.c` (8804), `src/init.c` (3205), `src/pad.c` (456), `include/dash_internal.h` (1186), `include/config_private.h` (86), `include/filer_shared.h` (133). Findings below cite only lines actually opened from these files.

### A.4 Files in the wider `src/` tree NOT read, with reasons

- Network/cloud/SMB/Neutrino/FTP (out of scope by assignment; another section owns them): `src/cloud_google.c`, `src/cloud_http.c`, `src/smb_cnf.c`, `src/smb_shares.c`, `src/neutrino_gameid.c`, `src/neutrino_iso.c`, `src/neutrino_smb.c`, `src/ftp_session.c`, `src/dash_ftp.c`, `src/dash_smbd.c`, `src/dash_clock_sync.c` (NTP), `src/config_network.c`, `src/pc_game_receiver.c`, `src/remote_control.c`, `src/self_update.c`, `src/gui_neutrino.c`.
- Launch backends owned by other themes: `src/popstarter*.c` (5 files), `src/ember.c`, `src/ember_gameid.c`, `src/mmce_igr.c`, `src/kelf_signer.c`, `src/qrcodegen.c` (only its dashboard call site in `src/dash_tools.c` was checked).
- Remaining dashboard/HDD/MC files not opened in this pass (time-bounded pass; no finding below depends on them): `src/dash_apps.c`, `src/dash_art.c`, `src/dash_bg*.c` (3 files), `src/dash_browser.c`, `src/dash_card_tool.c`, `src/dash_devices.c`, `src/dash_exploit.c`, `src/dash_files.c`, `src/dash_gfx.c`, `src/dash_hdd.c`, `src/dash_home.c`, `src/dash_icons.c`, `src/dash_image.c`, `src/dash_info.c`, `src/dash_jpeg.c`, `src/dash_lib.c`, `src/dash_png.c`, `src/dash_ps1_card.c`, `src/dash_settings.c` (only its size/role verified), `src/dash_sound.c`, `src/dash_store.c`, `src/dash_theme.c`, `src/dash_themes.c`, `src/dash_tools.c`, `src/dash_ui.c`, `src/dash_widgets.c`, `src/dash_worker.c`, `src/hdd_header_injector.c`, `src/hdl_rpc.c`, `src/gui_colors.c`, `src/gui_hdd0_format.c`, `src/gui_sort.c`, `src/gui_texteditor.c`, `src/mc_*.c` (6 files), `src/mmce_backup.c`, `src/mmce_card_switch.c`, `src/mmce_save_versions.c`, `src/psu_functions.c`, `src/update_psu.c`, `src/main_console_info.c`, `src/main_exploit_installer.c` (only its `getFilePath` call sites checked), `src/main_fileops.c`, `src/main_gameid.c`, `src/main_gameid_table.c`, `src/main_history.c`, `src/main_modules.c`, `src/elf.c`, `src/makeicon.c`, `src/chkesr.c`, `src/pad_ds34.c`, `src/virtual_keyboard.c`, `src/editor_input.c`, `src/editor_menu.c`, `src/editor_rules.c`, `src/draw_gs.c`, `src/draw_text.c`, `src/embed_blobs.S`, and the remaining `include/*.h` not listed in A.1–A.3.

---

## (B) Candidate Findings (sorted by benefit)

### EECORE-001: CNF loader copies unbounded file values into fixed SETTING fields with strcpy/sprintf
- Category: 6 (bugs/security)
- Locations: `src/config.c:962` (`strcpy(setting->LK_Path[i], value)`), `src/config.c:975-1003` (the `Misc` / `Misc_*` family: `sprintf(setting->Misc, "%s/", value)` and fourteen `sprintf(setting->Misc_*, "%s%s", setting->Misc, value)`), `src/config.c:1040-1067` (`strcpy` into `usbkbd_file`, `kbdmap_file`, `CNF_Path`, `lang_file`, `font_file`, `popstarter_file`, `ember_dir`, `neutrino_file`); field sizes at `include/launchelf.h:285-300` (`Misc*` are `char[64]`) and `include/launchelf.h:302-308` (path fields are `char[MAX_PATH]`, MAX_PATH = 1025)
- Problem: `loadConfig()` parses a user-supplied LAUNCHELF.CNF with no length check on `value` before these copies. A CNF line whose value exceeds 64 bytes overflows a `Misc*` field into the adjacent SETTING members; a value longer than 1025 bytes overflows the heap-allocated SETTING (`malloc(sizeof(SETTING))`, `src/config.c:799`). The parser itself (`get_CNF_string`, `src/config.c:111-162`) imposes no line-length limit, and the file is loaded whole by `preloadCNF`. The file is exactly the kind of artifact users download, copy between cards, and receive inside theme/save packs. The same function already proves the correct pattern exists in-tree: the SMB credentials a few lines below are guarded (`value[0] && strlen(value) < sizeof(...)`, `src/config.c:1051-1053`), and `PathPad[]` entries are loaded with `strncpy` + explicit NUL (`src/config.c:1098-1099`) — the guard was applied to two field families and missed everywhere else.
- Fix in words: Reject or truncate at the single choke point — bound every `value` copy in `loadConfig` to the destination size (the SMB/PathPad treatment already used in the same function), and drop any entry that does not fit rather than partially writing it. No new mechanism; extend the existing guard.
- Justification if fix adds: Adds no code paths; it reuses the guard idiom already present twice in the same function.
- Benefit: High — removes a heap/struct overflow reachable from an untrusted text file at every boot and every config reload.
- Effort: Low
- Risk: Low (over-long legacy values would be dropped instead of corrupting memory)
- Confidence: READ

### EECORE-002: Classic main-menu loop in main() is unreachable — DashRun never returns
- Category: 1 (dead code)
- Locations: `src/main.c:302-377` (comment at 302: "The dashboard is the only shell; DashRun() does not return", followed by the full classic event loop), `src/dash_main.c:1331` and `src/dash_main.c:1396-1397` (`DashRun` body ends in `while (1)` with the comment "the dashboard is the only shell: it never returns"; its only return is the guard at 1338-1339 for `dash_active || ctx == NULL`), `src/main_menu.c:81` (`drawMainMenuScreen`), `src/main_menu.c:254` (`MainMenuHandlePad`), `src/main_menu.c:330` (`MainMenuHandleAutoLaunch`), `include/main_menu.h:34-36`
- Problem: The only callers of `drawMainMenuScreen`, `MainMenuHandlePad` and `MainMenuHandleAutoLaunch` in the tree are the post-`DashRun` lines in `main()` (`src/main.c:357`, `src/main.c:363-364`; verified by tree-wide grep). Since `DashRun` never returns on any normal path, that whole loop — disc-change detection, `DiscTypes` formatting with unbounded `sprintf(mainMsg + strlen(mainMsg), DiscTypes[...].name)` at `src/main.c:341-348`, timer updates and pad handling — is dead, along with the three `main_menu.c` functions that exist only to serve it. It still costs review, compile and audit surface, and it misleads every reader about which shell is live.
- Fix in words: Delete the post-`DashRun` loop from `main()` and the three menu functions (plus their header declarations) that have no other caller. Keep `MainMenuState_Init`/`BeginTimers` only if a live caller remains after the deletion; otherwise delete those too.
- Justification if fix adds: Pure deletion; nothing added.
- Benefit: High — removes ~60 lines in `main.c` plus ~270 lines of single-caller menu machinery and one latent unbounded-`sprintf` site with them.
- Effort: Low
- Risk: Low (the guard-return path of `DashRun` currently falls into this loop with an uninitialised dashboard; deleting the loop makes that failure explicit instead of silently entering the wrong shell)
- Confidence: READ

### EECORE-003: Config save-text builder can overrun its heap buffer — sprintf with %n into a size estimate
- Category: 6 (bugs/security)
- Locations: `src/config.c:533-548` (`configBuildSaveText`: `tmp = malloc(sizeof(SETTING) + sizeof(PathPad) + 8192 + smb_len)`), `src/config.c:548-712` (the whole builder is unbounded `sprintf(tmp + CNF_size, ...)` using `%n` to measure), esp. `src/config.c:693-700` (all 30 `PathPad` entries emitted) and `src/config.c:706-712`
- Problem: The allocation is an estimate, not a bound. Worst-case output is larger than the estimate: the 17 launch-key lines can each carry a 1024-char path plus key text, and the 30 `PathPad` lines can each carry another 1024-char path plus `PathPad[NN] = ` framing — together ≈ 48 KB of path text alone, against an allocation of `sizeof(SETTING)` (≈ 28 KB, which already counts those same path arrays once) + `sizeof(PathPad)` (≈ 30 KB) + 8192. Because every field can be simultaneously full — `loadConfig` (EECORE-001) and the classic config screen both allow it — the `%n`-measured `sprintf` chain can write past the malloc'd block while saving config. Even if today's field limits keep typical files small, nothing in the code enforces the estimate.
- Fix in words: Make the builder bounded: write with the remaining-space form of `snprintf` (the idiom already used by the save-path helpers in the same file, `src/config.c:38-101`) and fail the save if the text does not fit, instead of trusting the estimate. No new buffer, no new feature.
- Justification if fix adds: Replaces an unbounded writer with the bounded writer already used elsewhere in the same file; net mechanism count unchanged.
- Benefit: High — removes a heap overflow on the config-save path, triggered by data the loader itself accepts.
- Effort: Medium
- Risk: Low
- Confidence: READ
- Confidence note: overflow arithmetic is derived from the field sizes in `include/launchelf.h:259-300` and MAX_PATH = 1025; labelled READ because every input to the arithmetic was read, not because the overflow was executed

### EECORE-004: Unbounded sprintf/strcat path assembly in the copy/delete/MC-read path cluster
- Category: 6 (bugs/security)
- Locations: `src/filer_copy.c:764` (`char out[MAX_PATH], in[MAX_PATH]`), `src/filer_copy.c:849` (`sprintf(in, "%s%s", inPath, file.name)`), `src/filer_copy.c:873` (`sprintf(out, "%s%s", outPath, newfile.name)`), `src/filer_copy.c:1117-1120` (same pair repeated plus `strcat(out, "/")`), `src/filer_actions.c:1980` (`strcat(dir, "/")` immediately after a length-checked `snprintf` at 1972 — a `dir` of exactly `sizeof(dir)-1` chars passes the check and the `strcat` then writes past the end), `src/filer.c:494-495` in `readMC` (`strcpy(dir, &path[4]); strcat(dir, "*")` into `char dir[MAX_PATH]` at `src/filer.c:481`)
- Problem: One mechanism, five sites: a destination path and an entry name are concatenated with no bound into a MAX_PATH buffer. `genLimObjName(out, 0)` is called after the `sprintf` at `src/filer_copy.c:1118-1119` — it truncates the result, but the overflow has already happened during the `sprintf`. Directory trees copied from USB/HDD/MC are attacker- and accident-shaped input (deep nesting + 255-char names is normal on exFAT), so `inPath`/`outPath` near MAX_PATH plus a long name is a realistic paste, not a theory. Sibling code in the same files does this correctly with checked `snprintf` (e.g. `src/filer_actions.c:159-161`, `src/filer_actions.c:1972`), so the unbounded sites are the inconsistency.
- Fix in words: Convert these five concatenations to the checked-`snprintf` form already used in the same files, returning the existing `-ENAMETOOLONG`-style failure when the joined path does not fit; delete the now-redundant post-hoc `genLimObjName` truncation at the copy site if the checked join makes it unreachable.
- Justification if fix adds: No new mechanism — it extends the file's own existing checked-join idiom to the sites that missed it.
- Benefit: High — removes stack overflows on paste/delete/browse of deep or long-named trees.
- Effort: Low
- Risk: Low
- Confidence: READ

### EECORE-005: scanSystemCnf uses strncat as if it were a bounded copy — duplicate SYSTEM.CNF keys overflow
- Category: 6 (bugs/security)
- Locations: `src/main_startup.c:152-162` (`strncat(SystemCnf_BOOT, value, MAX_PATH - 1)`, `strncat(SystemCnf_BOOT2, value, MAX_PATH - 1)`, `strncat(SystemCnf_VER, value, 9)`, `strncat(SystemCnf_VMODE, value, 9)`), destinations at `src/main.c:67-70` (`SystemCnf_BOOT2[MAX_PATH]`, `SystemCnf_VER[10]`, `SystemCnf_VMODE[10]`), caller loop at `src/main_startup.c:178-183`
- Problem: `strncat(dst, src, n)` appends up to `n` more characters; it does not bound the total length. `readSystemCnf` zeroes the destinations once, then calls `scanSystemCnf` for every parsed line. A SYSTEM.CNF containing the same key twice (malformed homebrew discs, hand-edited images, dual-boot discs) appends twice: two `VER` lines can write up to 18 chars + NUL into a 10-byte global; two `BOOT` lines up to ~2048 into a 1025-byte global. The disc being read is untrusted input by definition.
- Fix in words: Replace the append with a bounded copy that only writes when the destination is still empty (first occurrence wins, matching how the results are consumed at `src/main_startup.c:185-193`), or ignore subsequent duplicates outright. Less code than the append form.
- Justification if fix adds: Pure replacement/deletion; nothing added.
- Benefit: Medium-High — removes a global-buffer overflow from crafted or malformed disc metadata.
- Effort: Low
- Risk: Low
- Confidence: READ

### EECORE-006: Classic dialog helpers strcpy unbounded caller text into fixed stack buffers
- Category: 6 (bugs/security)
- Locations: `src/gui.c:12-20` (`ynDialog`: `char msg[512]; strcpy(msg, message);`), `src/gui.c:95-111` (`nonDialog`: `char msg[80 * 30]; strcpy(msg, message);`)
- Problem: Both helpers copy an unbounded caller-supplied message into a fixed stack buffer before doing their own line-splitting. These are the fallback dialogs used whenever the dashboard override hooks are not installed (`src/gui.c:17-19`, `src/gui.c:102-105`) — i.e. during launch-time prompts, which is exactly when messages are built from file paths and device error text. Any caller message over 512 bytes (ynDialog) smashes the stack. No length contract is documented at either prototype in `include/launchelf.h:594-595`.
- Fix in words: Bound both copies to the buffer size and truncate the displayed message (the helpers already re-measure and re-wrap the text, so a truncated copy degrades gracefully). No new mechanism.
- Justification if fix adds: Two bounded copies replace two unbounded ones; nothing added.
- Benefit: Medium-High — removes a stack overflow in the two most-reused prompt primitives in the classic UI.
- Effort: Low
- Risk: Low
- Confidence: READ

### EECORE-007: Classic config screens and classic info/editor screens are shadowed by dashboard interception — a second, parallel settings/UI system is carried but not presented
- Category: 8 (half-finished features) / 2 (duplication)
- Locations: Interceptions: `src/dash_main.c:447-485` (`dashRunMisc` routes Misc_Configure → dashboard Settings, Misc_TextEditor → `dashOpenTextEditor`, Misc_ShowFont → `dashShowFontViewer`, Misc_About/BuildInfo/DebugInfo/HddManager/FileBrowser → native dashboard screens), `src/dash_main.c:389-390` (launch hook returns early for Misc_Configure/Misc_Exploit_Installer: "handled natively by dashRunMisc()"). Shadowed classic implementations: `src/config.c:1492` (`config()`, 290 lines to end of file) with `src/config_screen.c` (361), `src/config_advanced.c` (329), `src/config_startup.c` (364); `src/main_info_screens.c:285` (`ShowFont`), `src/main_actions.c:768-799` (classic Misc_* dispatch incl. `TextEditor(NULL)` and `config(...)` at 785)
- Problem: The dashboard is the only shell (EECORE-002), and every user-visible route to Configure/TextEditor/ShowFont/About/DebugInfo is intercepted and served natively before `ExecuteMainAction`'s classic dispatch can run. The repo therefore carries two complete implementations of the same settings surface — the classic `config()` screen family (~1050 lines across four files, editing the same `SETTING` that `src/dash_settings.c` (4096 lines) edits) — plus classic duplicates of the font viewer and info screens. That is the audit's largest single duplication: two systems to keep in sync on every settings change, and a standing risk that a fix lands in the presented UI while the shadowed one keeps the bug.
- Fix in words: Decide the classic screens' fate explicitly and act on it: either delete the shadowed classic screen implementations (keeping `loadConfig`/`saveConfigToPath`/`initConfig`, which are live) or name one concrete non-dashboard entry point that reaches them and record it next to the interception. What should not continue is the unrecorded middle state. This finding does not claim the classic *browser* (`getFilePath`) is dead — it has a live caller in the exploit installer (`src/main_exploit_installer.c:974`, `src/main_exploit_installer.c:1023`, grep-verified).
- Justification if fix adds: The recommended direction is deletion; the alternative is a comment recording reachability. Neither adds a mechanism.
- Benefit: Medium-High — up to ~1000 lines of parallel UI removed, or the duplication at least made a recorded decision instead of an accident.
- Effort: High (reachability must be proven per screen before deletion)
- Risk: Medium (a hidden entry point, e.g. a launch-key path that bypasses the hook, would lose its screen)
- Confidence: INFERRED
- Confidence note: interceptions and implementations are READ; the conclusion that no live route remains is an inference from the dashboard-only shell plus the two interception layers, not an executed reachability proof

### EECORE-008: First-open retry loop is copy-pasted three times in filer.c, each with its own empty busy-wait
- Category: 2 (duplication) / 5 (structural performance)
- Locations: `src/filer.c:340-382` (`readGENERICWithFirstOpenRetry`), `src/filer.c:1990-2025` (ATA branch of `setFileList`), `src/filer.c:2112-2170` (MX4SIO branch of `setFileList`)
- Problem: The same mechanism — poll `fileXioDopen` until a budget (750/2000 ms) expires, re-list on success, spin 100 ms in an empty `while (Timer() < backoff_start + 100) {}` between attempts — is implemented three times with slightly different extras (root detection, alternate path spellings). Three copies means three places to fix timing or RPC behaviour, and the copies have already drifted (only the MX4SIO copy probes alternate path forms; only the ATA copy distinguishes root budgets inline). The empty spin also burns the EE for up to 100 ms per iteration with no thread yield, in a codebase that has `DelayThread` available and uses it elsewhere (e.g. `src/filer.c` MC retry path).
- Fix in words: Keep the one existing helper (`readGENERICWithFirstOpenRetry` already parameterises budget and reader-specific behaviour is minimal) and call it from the ATA and MX4SIO branches, deleting the two inline copies. Keep the behaviour; delete the duplication.
- Justification if fix adds: Net deletion: one mechanism replaces three.
- Benefit: Medium — ~120 duplicated lines removed; one place to correct retry timing.
- Effort: Medium
- Risk: Medium (device-readiness quirks are hardware-timing sensitive; each branch's budget and break conditions must be preserved in the call)
- Confidence: READ

### EECORE-009: Every directory listing allocates ~900 KB of FILEINFO; recursive size/delete allocate another ~900 KB per level
- Category: 4 (size/memory)
- Locations: `include/launchelf.h:202` (`MAX_ENTRY = 2048`) and `include/launchelf.h:560-565` (`FILEINFO` = `char name[256]` + 66-byte title + `sceMcTblGetDir stats`), `src/filer_actions.c:310-311` ("each level lists on the heap: MAX_ENTRY entries are about 900 KB", `memalign(64, MAX_ENTRY * sizeof(FILEINFO))` in the recursive size walk), `src/filer_actions.c:1981-1984` (same allocation, `MAX_ENTRY + 1`, in recursive `delete`), `src/filer_browser.c:2007-2010` (same allocation for the classic browser listing), `src/filer_copy.c:915` (same allocation per copy level)
- Problem: The code's own comments price one listing at ~900 KB on a 32 MB console. Four call sites allocate a full MAX_ENTRY listing, and two of them (recursive size and recursive delete) allocate one per directory level, so a deep tree holds several megabytes of mostly-empty listing buffers at once — most directories hold tens of entries, not 2048. This is the dominant heap consumer of the filer and the first thing to fail (`-ENOMEM` returns are already plumbed at both recursive sites) when memory is fragmented by fonts, art and caches.
- Fix in words: Size the listing to the directory instead of to the constant: list once into a right-sized or grow-on-demand buffer using the existing `getDirComplete(..., &more)` continuation contract (`src/filer.c:2221-2238` already documents listing-in-chunks for oversize folders), so the common case costs kilobytes and only genuinely huge folders grow. No new user-visible behaviour.
- Justification if fix adds: It removes a fixed ~900 KB-per-level cost; any growth logic replaces, rather than supplements, the fixed allocation at these four sites.
- Benefit: Medium — megabytes of peak heap returned on deep copy/delete/size operations.
- Effort: High
- Risk: Medium (listing truncation semantics for >2048-entry folders must be preserved via the existing `more` contract)
- Confidence: READ
- Confidence note: the ~900 KB figure is the code's own comment at both recursive sites, not an external estimate

### EECORE-010: Two identical 2049-entry sceMcTblGetDir static buffers are kept in BSS for two readers that never run concurrently
- Category: 4 (size/memory) / 2 (duplication)
- Locations: `src/filer.c:480` (`readMC`: `static sceMcTblGetDir mcDir[MAX_ENTRY + 1] __attribute__((aligned(64)))`), `src/filer.c:544` (`readXFROM`: identical declaration)
- Problem: Directory listing is single-threaded through `setFileList`'s dispatch — `readMC` and `readXFROM` are alternative branches for one listing, never nested or concurrent. Each nevertheless owns a private permanent BSS array of 2049 MC directory entries (the same pattern the file's comments elsewhere call out as too big for the stack). One shared buffer serves both.
- Fix in words: Delete one array; declare the buffer once at file scope and use it from both readers.
- Justification if fix adds: Pure deletion of one duplicate buffer.
- Benefit: Medium-Low — one full 2049-entry table of permanent BSS returned.
- Effort: Low
- Risk: Low (requires the single-threaded-dispatch fact above, which is how `setFileList` is structured)
- Confidence: READ

### EECORE-011: SystemCnf_VMODE is parsed, stored and never read — write-only state
- Category: 1 (dead code)
- Locations: `src/main.c:70` (`char SystemCnf_VMODE[10]; //Arbitrary, same deal. As yet unused`), `src/main_startup.c:159-160` (populated in `scanSystemCnf`), `src/main_startup.c:176` (cleared in `readSystemCnf`), `include/launchelf.h:374` (extern declaration)
- Problem: Tree-wide grep shows writes only: declaration, clear, and the `strncat` in the parser. No reader exists. The variable, its parser branch and its header declaration are pure surface — and the parser branch is one of the four overflow-prone `strncat` sites in EECORE-005, so the dead state is not even harmless.
- Fix in words: Delete the variable, the `VMODE` branch in `scanSystemCnf`, and the extern. If VMODE handling is ever wanted, it starts from the parser, not from a stored-but-unread global.
- Justification if fix adds: Pure deletion.
- Benefit: Low-Medium — small, but removes a dead global and one overflow site.
- Effort: Low
- Risk: Low
- Confidence: READ

### EECORE-012: MainExecuteContext is assembled field-by-field three times in main.c
- Category: 2 (duplication)
- Locations: `src/main.c:255-266` (`Execute` builds the 11-field context), `src/main.c:305-316` (the `DashRun` call site rebuilds the identical 11 fields into a second context)
- Problem: The same eleven assignments from the same globals (`boot_argc`, `boot_argv`, `boot_path`, `mainMsg`, `CNF`, `default_ESR_path`, `default_OSDSYS_path`, `default_OSDSYS_path2`, `rough_region`, `ROMVER_data`) are written out twice, eleven lines apart in the same file. Any new context field must be added in both places, and the two copies can silently diverge — the exact failure mode a context struct exists to prevent.
- Fix in words: Build the context once in `main()` and pass that one instance to both consumers (`Execute`'s path is internal to this file). Delete the second assembly.
- Justification if fix adds: Net deletion of one copy; no new abstraction.
- Benefit: Low-Medium
- Effort: Low
- Risk: Low
- Confidence: READ

### EECORE-013: Text editor result messages are shown with five empty busy-wait spins of 1.5 s each
- Category: 5 (structural performance)
- Locations: `src/editor_file.c:59`, `src/editor_file.c:182`, `src/editor_file.c:208`, `src/editor_file.c:250`, `src/editor_file.c:319` (all `while (Timer() < WaitTime + 1500) ;  // print operation result during 1.5 sec.`)
- Problem: Each editor file operation (open/close/save/save-as flows) ends by spinning the EE in an empty loop for 1.5 seconds — no draw, no pad poll, no thread yield. Input during the spin is lost, and the pattern is copy-pasted at five sites so the duration and behaviour can drift. The dashboard editor (`src/dash_editor.c`) already exists as the native replacement for this UI, which makes polishing the spin a poor investment; the minimal correct change is at the five sites themselves.
- Fix in words: Replace the five empty spins with the single existing wait idiom that yields (or simply delete the delay at four sites and keep one shared helper for the save-result case). Do not build a new timing system for a shadowed UI (see EECORE-007).
- Justification if fix adds: Replacement/deletion only.
- Benefit: Low-Medium — removes up to 1.5 s of dead, input-swallowing spin per editor file operation.
- Effort: Low
- Risk: Low
- Confidence: READ

### EECORE-014: editorSaveAs appends the typed filename with strcpy at the end of a possibly-full path buffer
- Category: 6 (bugs/security)
- Locations: `src/editor_file.c:278-281` (commented-out `strcat` and `sprintf` variants kept in the source above the live `strcpy(&Path[Win][strlen(Path[Win])], tmp);`), buffer at `src/editor.c:38` (`char Path[10][MAX_PATH]`), input bound at `src/editor_file.c:277` (`keyboard(tmp, 36)`)
- Problem: The typed name is bounded (36 chars by the keyboard call), but `Path[Win]` comes from `getFilePath(Path[Win], DIR_CNF)` at `src/editor_file.c:269` and can legitimately be near MAX_PATH long for a deep directory. Appending up to 36 chars + NUL at `strlen(Path[Win])` then writes past the 1025-byte buffer. The two commented-out alternative lines kept directly above the live line document that this spot has been patched by trial before, without the bound ever being added.
- Fix in words: Check `strlen(Path[Win]) + strlen(tmp) < MAX_PATH` before the append and abort the save-as (the function's existing `abort:` path) if it does not fit; delete the two commented-out variants while there.
- Justification if fix adds: One length check at the existing abort path; the commented lines are deleted, not added to.
- Benefit: Low-Medium — removes a bounded-but-real stack/global overflow in Save-As on deep paths.
- Effort: Low
- Risk: Low
- Confidence: READ

### EECORE-015: WriteFont_C survives as a ~57-line commented-out function inside draw.c
- Category: 1 (dead code)
- Locations: `src/draw.c:343-399` (`/* int WriteFont_C(char *path_arg) { ... } */`, incl. its own unbounded `sprintf`/`strcat` body), `include/launchelf.h:507-508` (commented-out prototype with the note "Comment out WriteFont_C when not used (also requires patch in draw.c)")
- Problem: A complete font-dump utility is carried as a block comment in a production source file, with a matching commented prototype. It is not compiled, not tested, and contains the only `strcat(text, ...)` cluster in `draw.c` — every audit (human or automated) must re-derive that it is inert. The repo has `docs/` and `scripts/` homes for exactly this kind of maintainer tooling.
- Fix in words: Delete the commented function and the commented prototype. If the dump utility is still wanted, it belongs as a standalone script/doc artefact, not as a comment inside `draw.c`.
- Justification if fix adds: Pure deletion.
- Benefit: Low — ~59 lines of inert code and one recurring false-positive site removed.
- Effort: Low
- Risk: Low
- Confidence: READ

### EECORE-016: The sixteen Misc_* launch strings are rebuilt by three separate hand-written sprintf blocks
- Category: 2 (duplication)
- Locations: `src/config.c:801-816` (`initConfig`: sixteen `sprintf(setting->Misc_*, "%s/%s", ...)` lines), `src/config.c:975-1003` (`loadConfig`: the inverse, sixteen hand-written `else if` branches), `src/lang.c:419-434` (language reload: the same sixteen `sprintf` lines again)
- Problem: One mechanism — "Misc_X is `Misc/` + the localised name X" — is written out longhand three times (init, load, language-switch), 16 entries each. Adding or renaming a Misc entry means editing three blocks in two files in lockstep; the blocks have already diverged in detail (`initConfig` builds `Misc_Show_Build_Info` from `LNG()` where its neighbours use `LNG_DEF()`, `src/config.c:814`). This is also the field family at the centre of EECORE-001, so the triplication triples the overflow surface.
- Fix in words: Drive all three sites from the one name table the entries already imply (the `LNG_DEF` ids in order), so init, load and language reload share a single loop. The fix shrinks all three blocks; it does not add a fourth mechanism.
- Justification if fix adds: One shared loop replaces three hand-written blocks — net deletion of ~30 lines and two of the three copies.
- Benefit: Low-Medium
- Effort: Medium
- Risk: Medium (the load-side branches also handle the `Misc` prefix ordering constraint noted at `src/config.c:971-973`; the loop must preserve "Misc before its subprograms")
- Confidence: READ

### EECORE-017: icon.c stores 2048 bytes as 2055 one-byte-per-line C source
- Category: 7 (build/repo) / 4 (size/memory)
- Locations: `src/icon.c:2-1027` (`icon_folder[1024]`, one byte per line), `src/icon.c:1030-2055` (`icon_warning[1024]`, same format), consumers at `src/draw.c:211` and `src/draw.c:221`
- Problem: Two small textures cost a 2055-line source file — the largest non-generated, non-font file in the core by line count — purely because of representation. The compiled bytes are identical either way; the cost is repo noise, review surface and parse time on every build. The dashboard fonts in the same tree already solved this properly: they are generated by a script (`src/dash_font_data.c:1-5`, "GENERATED by scripts/gen_dash_font.py, do not edit") into packed rows.
- Fix in words: Regenerate `icon.c` in the same packed-row style the font generator already produces (multiple bytes per line), or move the two arrays to the existing embed path. Data unchanged; representation only.
- Justification if fix adds: No new tooling — it reuses the representation the tree's own generator already emits.
- Benefit: Low — ~1900 source lines removed from a core file.
- Effort: Low
- Risk: Low (byte-for-byte data must be preserved; verifiable by comparing the compiled arrays)
- Confidence: READ

### EECORE-018: Development scaffolding (autotest script player, theme tour) is compiled into production sources behind ifdefs
- Category: 3 (overengineering) / 8 (half-finished features)
- Locations: `src/pad.c:284-313` (`#ifdef DASH_AUTOTEST` scripted-input player, includes `dash_autotest.h`), `src/dash_main.c:1295-1296` (`#ifdef DASH_AUTOTEST` sample-library hook), `src/dash_main.c:1483` (`#ifdef DASH_THEME_TOUR` preset-cycling block inside `DashRun`, "development only: show every preset for five seconds")
- Problem: Two development-only features live permanently inside the two hottest core files (pad input and the dashboard main loop), each guarded by a build flag that no release configuration defines. They are never exercised by the shipped binary, so they rot silently and add conditional branches every reader of `readpad`/`DashRun` must reason past.
- Fix in words: Delete both blocks from the production sources; if either is still used for development, it belongs on a development branch, not behind an ifdef in the shipped tree. (If a maintainer actively uses one, recording that next to the flag is the minimum alternative.)
- Justification if fix adds: Pure deletion.
- Benefit: Low
- Effort: Low
- Risk: Low
- Confidence: INFERRED
- Confidence note: the blocks and their "development only" comments are READ; whether a maintainer still flips these flags outside this tree cannot be proven from the clone

### EECORE-019: filer_copy recomputes strlen(out) on every character while counting path depth
- Category: 5 (structural performance)
- Locations: `src/filer_copy.c:1105-1108` (`for (i = 0; i <= strlen(out); i++) { if (out[i] == '/') ret++; }`)
- Problem: `strlen(out)` is evaluated on every iteration of a loop whose bound is that same length — O(n²) character scans of a path up to 1025 chars, on the HDD-`__common` folder path of every qualifying folder copy. Trivial in isolation, but it is the only `for (... strlen ...)` site in the core (script-verified) and the fix is smaller than the bug.
- Fix in words: Hoist the length into the loop's initialiser (or walk the string once with a pointer). One line changed, nothing added.
- Justification if fix adds: Nothing added.
- Benefit: Low
- Effort: Low
- Risk: Low
- Confidence: READ

---

## (C) Checked-Clean Notes

Mechanisms in scope that were tested/read and found sound — no finding raised:

1. **Timer wrap handling** — `src/timer.c:1-11` (read in full): `Timer()` derives milliseconds from the 64-bit bus clock (`GetTimerSystemTime() / (kBUSCLK / 1000)`), with the 32-bit `clock()` ~71.6-minute wrap explicitly documented as the reason. Sound.
2. **Dashboard poll throttling** — `src/dash_main.c:1396-1533` (`DashRun` loop): disc poll 1000 ms, device poll 250 ms, remote/receiver poll 500 ms, all wall-clock throttled and gated on `dashWorkerIoBusy()`/`dashIopParked()`, with comments recording that per-frame IOP polling was removed for causing stutter. Sound as structured.
3. **Bounded config helpers already in tree** — `src/config.c:38-101` (label/value/save-path formatters use `snprintf` with explicit length returns), `src/config.c:390` and `src/config.c:414` (icon-path joins check the `snprintf` result against the buffer size), `src/config.c:1051-1053` (SMB credential length guard), `src/config.c:1098-1099` (`PathPad` `strncpy` + NUL). These are the correct idioms; EECORE-001/003/004 are findings precisely because sibling sites do not follow them.
4. **Both Emotion Engine font faces are used** — `src/dash_font.c:380` selects `dash_emotion_engine_bold_faces` vs `dash_emotion_engine_faces` on `dashTheme.bold`; neither `src/dash_font_emotion_engine.c` nor `src/dash_font_emotion_engine_bold.c` is dead data.
5. **Recursive listing allocations fail closed** — `src/filer_actions.c:311-313` and `src/filer_actions.c:1984-1986`: both recursive `memalign` sites check for NULL and return `-ENOMEM` rather than dereferencing. (The finding at EECORE-009 is about the size, not about missing NULL checks.)
6. **IGR argument parsing in main** — `src/main.c:118-140` (`wleIgrRequested`): NULL-checked argv scan, prefix compared with an explicit length, no copies made. Sound.
7. **`get_CNF_string` termination behaviour** — `src/config.c:111-162`: every scan loop checks for `'\0'` before dereferencing further, and EOF returns `false` rather than running off the buffer. (The overflow risk in config loading is at the *destination* copies, EECORE-001, not in this parser.)
8. **Classic browser is not dead** — `getFilePath` (`src/filer_browser.c:2005`) has live non-classic-menu callers in the exploit installer (`src/main_exploit_installer.c:974`, `src/main_exploit_installer.c:1023`), so no deletion finding was raised against `filer_browser.c` despite the dashboard browser existing.
