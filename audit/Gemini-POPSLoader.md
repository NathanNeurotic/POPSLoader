# POPSLoader Audit (`NathanNeurotic/POPSLoader` @ `29272cdd`)

Target platform: PS2 EE (32 MB RAM), IOP (2 MB RAM), slow 8 MB memory cards, USB/HDD/MX4SIO/MMCE/i.Link/UDPFS/SMB.
Default branch audited: `master` (`29272cdd`).

---

## Host Verification Results (2026-11-13)

- `tools/host_harness.py`: **62/62 PASS**
- `tools/pad_harness.py`: **13/13 PASS**
- `tools/test_disc_layout.py`: **30/30 PASS**
- `tools/test_udpfs_config_runtime.py`: **26/26 scenarios PASS**
- `tools/docs_verify.py`: **PASS** (`rc=0`, notes printed for non-persisted keys mentioned in docs)
- `tools/test_translation_handoff.py`: **7/7 PASS** (`unittest`)
- `tools/test_udpfs_integration.py`: **FAIL** (`AssertionError` at line 93 on Windows `core.autocrlf` checkout of `docs/third_party/okeanos_udpfs/PATHMAP.INI.example`; see `POPSLOADER-026`)
- `tools/png_decoder_harness.py`: **ERROR** (`FileNotFoundError` calling `pkg-config` in this Windows environment; requires POSIX/MSYS toolchain with `libpng`)

---

## Cross-Repo Notes

- Shared multi-repo patterns and identical IOP driver code are lifted to `Gemini-SUMMARY.md` to avoid duplicate findings: `CROSS-001` (duplicated POPS/BDMAssault/Ember binaries and tightly coupled kit fetchers), `CROSS-002` (`POPSLoader/iop/ata_bd_fast` and forked PS2 IOP hardware/storage/IP driver trees), `CROSS-004` (`ds34bt`/`ds34usb` duplication and 4-repo `SifCallRpc` stale-buffer bug), `CROSS-005` & `CROSS-016` (duplicate precompiled `udpfs_*.irx` binaries and shared UDPFS IOP driver protocol bugs), `CROSS-007` (duplicated `.psu` packager in `tools/package_psu.py` and `PSUManager` check in `build_release_kit.sh`), `CROSS-008` (forked `loader.c` ELF loader), `CROSS-009` (duplicated controller pad PNG icons in `bin/POPSLDR/IMG/`), and `CROSS-012` (`ds34usb`, `ds34bt`, and `pademu` shared IOP driver bugs, including `CancelAlarm(..., NULL)` timer over-signaling, `ret = -1 < MAX_PADS` `ds34pad[-1]` read, `power_level[]` OOB index, and unsafe USB endpoint descriptor scans).

---

## Findings (Sorted by Benefit)

### POPSLOADER-001: Unaliased duplicate IRX blobs and doubled asset table in ELF
- **Category**: 4 (Size and memory), 2 (Duplication)
- **Location(s)**: `POPSLoader/Makefile:115-123,240-260`, `POPSLoader/src/embed_assets.cpp:116-230,271-285`
- **Problem**: `usbd.irx.ilink` (48,500 B) is byte-identical to `usbd.irx.usbexfat`, and `usbhdfsd.irx.udpfs` (34,508 B) is byte-identical to `usbhdfsd.irx.usbexfat`, yet both are assembled and linked as separate objects into `POPSLOADER.ELF` (unlike `usbd.irx.mx4sio`, which line 153 already aliases). Every embedded asset is also listed twice in `g_embedded_assets` (with and without `"POPSLDR/"`, doubling the table to 108 entries) even though `embedded_get` already normalizes paths.
- **Fix**: Remove the `asset_usbd_irx_ilink` and `asset_usbhdfsd_irx_udpfs` bin2s rules/objects from `Makefile` and alias those keys in `g_embedded_assets` to `asset_usbd_irx_usbexfat` and `asset_usbhdfsd_irx_usbexfat`. Strip an optional `"POPSLDR/"` prefix once in `embedded_get` and keep one table entry per asset.
- **Benefit**: **83,008 B** raw payload removed from `POPSLOADER.ELF` (~30-55 KB packed ELF reduction, INFERRED), plus 54 static struct entries removed.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-002: All 7 non-English localization tables compiled into EE RAM at boot
- **Category**: 4 (Size and memory), 5 (Performance)
- **Location(s)**: `POPSLoader/bin/POPSLDR/system.lua:2568-4848`
- **Problem**: `PLDR.I18N` defines all non-English translation tables inline inside `system.lua`, accounting for 172,313 B raw (30.1% of the 571,596 B LF script) and 162,489 B minified (40.4% of the 402,552 B minified script). Every console parses and interns all 7 unused language tables into EE Lua heap memory on every boot.
- **Fix**: Split non-English tables into per-language embedded Lua assets (`i18n_<lang>.lua`) or external language files and `require`/execute only the active `PLDR.LANGUAGE` table on boot or language switch.
- **Justification**: Adding per-language embedded chunks (without any generic loader framework) adds minimal glue (~10 lines) and avoids allocating ~162 KB of unused string/table data in the 32 MB EE RAM on English and single-language boots.
- **Benefit**: ~162 KB minified Lua source and runtime string/table heap freed on EE for the active single-language session (up to ~140-162 KB EE RAM, INFERRED); faster Lua parse at boot.
- **Effort**: M. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-003: Per-frame table and closure allocations in Settings and MainMenu render loops
- **Category**: 5 (Performance), 4 (Size and memory)
- **Location(s)**: `POPSLoader/bin/POPSLDR/ui.lua:4351-5899`, `POPSLoader/bin/POPSLDR/ui.lua:5920-6050`
- **Problem**: `UI.ProfileQuery.Play` allocates 5 `Color.new` userdata/tables, several local helper functions, and the entire Settings row descriptor table (`local items = {}` with closures at lines 4929+) on every rendered frame. `UI.MainMenu.Play` similarly allocates fresh `icon_map`, `icon_keys`, `visible_seq`, `pos_of` tables and `WrapIndex`, `ResolveIcon`, and `DrawIcon` closures every frame.
- **Fix**: Hoist invariant color constants, `icon_map`, helper functions (`TruncateMiddle`, `CycleIndex`, `WrapIndex`, `ResolveIcon`, `DrawIcon`), and reusable descriptor structures to module scope, rebuilding Settings/visible device lists only on scene entry or option change.
- **Benefit**: Eliminates dozens of short-lived table, closure, and userdata allocations per frame (~60x/s), cutting Lua GC pause hitches in the UI.
- **Effort**: M. **Risk**: Med. **Confidence**: High (READ).

### POPSLOADER-028: Per-frame `Color.new` and `WrapText`/`WrapTextPx` allocations in 5 additional active draw paths
- **Category**: 5 (Performance), 4 (Size and memory)
- **Location(s)**: `POPSLoader/bin/POPSLDR/ui.lua:1477-1507` (`Notif_queue.display`), `POPSLoader/bin/POPSLDR/ui.lua:1736-1783` (`UI.flip`), `POPSLoader/bin/POPSLDR/ui.lua:2468-2504` (`Modal.Draw`), `POPSLoader/bin/POPSLDR/ui.lua:2934-2992` (`PathEditor.Draw`), `POPSLoader/bin/POPSLDR/ui.lua:6083-6094` (`MainMenu.Play` carousel slot draw)
- **Problem**: Outside `POPSLOADER-003`, five active UI draw paths allocate short-lived `Color.new` userdata and word-wrap tables/strings on every frame: `PathEditor.Draw` creates 5 static colors plus up to 4 `Color.new` objects per OSK key inside its `r`/`c` loops (~150-250+ per frame when open, INFERRED); `Notif_queue.display` re-runs `WrapText` plus per-toast `Color.new`; `Modal.Draw` and `UI.flip` (`SavingActive` / `Transition`) re-run `WrapTextPx` and `Color.new`; and `MainMenu.Play` (`6083-6094`) allocates up to 7 fade-tint `Color.new` objects across slots `-3..3`.
- **Fix**: Hoist invariant `Color.new` values to module scope, index a small prebuilt alpha LUT for fades/carousel tints, wrap toast text once in `Notif_queue.add`, and memoize wrapped modal/saving lines keyed by text and box width.
- **Benefit**: Eliminates hundreds of per-frame userdata, table, and string allocations across active UI screens, cutting Lua GC pause stalls.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-004: BMP decoder rejects valid `ColorUsed == 0` palettes and misindexes non-4-byte-aligned rows
- **Category**: 6 (Bugs and security)
- **Location(s)**: `POPSLoader/src/graphics.cpp:496-498,537-539,618,670-764`
- **Problem**: In `loadBMP`, 4-bit and 8-bit palette reads check `if (fread(tex->Clut, bmp_clut*sizeof(u32), 1, File) <= 0)`, which always fails when `Bitmap.InfoHeader.ColorUsed == 0` (the standard BMP encoding for full 16/256-entry palettes). Later, line 618 computes the 4-byte padded `bmp_stride`, but the 24-bit, 16-bit, 8-bit, and 4-bit pixel copy loops index tightly by `tex->Width` (and `tex->Width / 2` for 4-bit), corrupting rows whose stride requires padding.
- **Fix**: Treat `ColorUsed == 0` as 16 (4-bit) or 256 (8-bit) and skip `fread` if 0; advance each row pointer by `bmp_stride` in bytes rather than `tex->Width`.
- **Benefit**: Fixes image corruption and load failures on valid user BMP cover/theme art without adding heap allocations.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-005: Unconditional `sleep(1)` in boot-time `EnsureUsbMass()`
- **Category**: 5 (Performance)
- **Location(s)**: `POPSLoader/src/luasystem.cpp:185`, `POPSLoader/src/main.cpp:658`
- **Problem**: `main()` calls `EnsureUsbMass()` unconditionally on every boot, which executes a hardcoded `sleep(1)` between loading `bdmfs_fatfs` and `usbmass_bd` even when booting from MC, HDD, SMB, MMCE, or UDPFS with no USB stick attached.
- **Fix**: Remove the blanket 1-second sleep from `EnsureUsbMass()` and defer the USB settle wait to actual USB mass device engagement/probe, or measure minimum needed `usleep` instead of blocking every boot by 1,000 ms.
- **Benefit**: Saves up to **1,000 ms** on every cold boot across non-USB and USB-less setups.
- **Effort**: S. **Risk**: Med (hardware timing sensitive for cold USB drives). **Confidence**: High (READ).

### POPSLOADER-006: Unused `ps2atad.o` embedded in ELF and dead `IMPORT_BIN2C` declarations
- **Category**: 1 (Dead code), 4 (Size and memory)
- **Location(s)**: `POPSLoader/Makefile:98`, `POPSLoader/src/luaHDD.cpp:170,172,178`
- **Problem**: `Makefile:98` links `ps2atad.o` into `IOP_MODULES`, and `luaHDD.cpp:170,172,178` declare `IMPORT_BIN2C(poweroff_irx)`, `IMPORT_BIN2C(ps2atad_irx)`, and `extern bool g_dev9_loaded`. Code uses `ata_bd_irx` exclusively (explicitly replacing plain `ps2atad`), leaving `ps2atad.o` embedded in `POPSLOADER.ELF` with zero callers.
- **Fix**: Remove `ps2atad.o` from `IOP_MODULES` in `Makefile` (unless `bin2s`/`EE_OBJS` chain needs a non-IRX dep; verified `ps2atad_irx` has zero references in `src/`) and delete lines 170, 172, and 178 from `luaHDD.cpp`.
- **Benefit**: Removes an entire unused IRX binary (~10 KB, INFERRED) from `POPSLOADER.ELF` and 3 dead declarations.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-007: Dormant `ata_async_thread` worker and 8 KB static BSS stack
- **Category**: 1 (Dead code), 4 (Size and memory)
- **Location(s)**: `POPSLoader/src/luasystem.cpp:1846-1950`, `POPSLoader/src/main.cpp:680-681`
- **Problem**: `KickAtaAsyncBoot`, `WaitAtaAsyncBootBounded`, `ata_async_thread`, `g_ata_async_stack[8192]`, and duplicate `extern void *_gp;` (lines 1846 and 1860) remain compiled into `luasystem.cpp` despite `main.cpp:680-681` stating they have no callers. `System.initATAStatus` (lines 1955-1960) always reads the never-modified `0` (`idle`) state for this dormant path.
- **Fix**: Delete `ata_async_thread`, `AtaAsyncModulesSemaInit`, `KickAtaAsyncBoot`, `WaitAtaAsyncBootBounded`, `g_ata_async_stack`, `g_ata_async_modules_sema`, and the duplicate `_gp` declaration; have `System.initATAStatus` return `g_ata_bd_loaded ? 2 : 0` (or remove dead cascade checks if unused).
- **Benefit**: **8,192 B** EE static BSS stack + ~90 lines of dead threading code removed from ELF.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-008: Dead, unsafe `Graphics.threadLoadImage` legacy worker and 4 KB static stack
- **Category**: 1 (Dead code), 4 (Size and memory), 6 (Bugs and security)
- **Location(s)**: `POPSLoader/src/luagraphics.cpp:20-29,265-284,489-512,788-808,838,852-853`
- **Problem**: `Graphics.threadLoadImage`, `getLoadState`, and `getLoadData` have zero callers in Lua (replaced by `coverLoadBegin`/`coverLoadPoll`), yet still compile `imgThread`, `imgThreadStack[4096]`, and globals. Furthermore, `lua_loadimgasync` rejects `argc != 1` (making `if (argc == 2)` at line 493 dead) and passes a raw `luaL_checkstring` pointer to a detached thread without copying it (use-after-GC bug if ever called).
- **Fix**: Delete `imgThread`, `lua_loadimgasync`, `lua_getloadstate`, `lua_getloaddata`, `imgThreadStack`, `asyncDelayed`, `imgThreadResult`, `imgThreadData`, `imgThreadSize`, and their `luagraphics` method table entries.
- **Benefit**: **4,096 B** EE static BSS stack + ~80 lines of buggy dead code removed.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-009: `POPSTARTER.ELF` and `POPSTARTER/` duplicate tracked binaries already stored in `bin/POPSLDR/`
- **Category**: 2 (Duplication), 7 (Build/CI/repo clutter)
- **Location(s)**: `POPSLoader/POPSTARTER/`, `POPSLoader/bin/POPSLDR/popsmb/`, `POPSLoader/bin/POPSLDR/*.bdma`, `POPSLoader/bin/POPSLDR/POPSTARTER.ELF`, `POPSLoader/bin/POPSLDR/PROFILES/DEBUG/POPSTARTER.ELF`, `POPSLoader/.github/workflows/rolling-release.yml:234`, `POPSLoader/.github/workflows/experimental-release.yml:230`
- **Problem**: All 9 payload files in `POPSTARTER/` (180,256 B total) are byte-identical to `bin/POPSLDR/popsmb/*` plus `bin/POPSLDR/{del.icn,list.icn,icon.sys}.bdma`. Likewise, `bin/POPSLDR/POPSTARTER.ELF` (167,700 B) is byte-identical to `bin/POPSLDR/PROFILES/DEBUG/POPSTARTER.ELF`.
- **Fix**: Remove the redundant `POPSTARTER/` directory and copy `popsmb/*` and `*.bdma` (stripping `.bdma`) from `bin/POPSLDR/` during release packaging; drop `bin/POPSLDR/POPSTARTER.ELF` if `PROFILES/` selects the default or alias it in packaging instead of committing two copies.
- **Benefit**: **347,956 B** (340 KB) duplicate binary files removed from git checkout (`180,256 B` + `167,700 B`), plus eliminates drift risk between two copies.
- **Effort**: S. **Risk**: Low (verify release packaging paths in CI workflows). **Confidence**: High (READ).

### POPSLOADER-010: Archival `.research/` corpus and source tarball committed on `master` and re-archived in release ZIPs
- **Category**: 7 (Build/CI/repo clutter), 4 (Size and memory)
- **Location(s)**: `POPSLoader/.research/` (312 files, 21,359,350 B), `POPSLoader/iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz` (1,466,084 B), `POPSLoader/.github/workflows/rolling-release.yml:215-260`, `POPSLoader/.github/workflows/experimental-release.yml:210-255`
- **Problem**: `master` tracks 21.36 MB of archival `.research/` notes/dumps and a 1.47 MB binary `.tar.gz`, and the rolling/experimental release workflows run `git ls-files` to pack the entire tree (including `.research/`, `.github/`, and the tarball) into every release ZIP's `source/` folder while also nesting `PS1_POPSLOADER.zip` inside the outer ZIP.
- **Fix**: Move `.research/` out of `master` (keep on an archive branch/tag if needed) and replace `SourceCode-BDMAssault-mx4sio.tar.gz` with a version/URL reference (or keep only if license distribution strictly requires source alongside binary; if kept, exclude from `POPSLDR` runtime/kit packaging). Exclude non-build files from `source/` or use GitHub's native source tarball.
- **Benefit**: Removes ~22.8 MB from working checkouts and cuts release ZIP download size by >20 MB.
- **Effort**: M. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-011: 45 unreferenced images (525.5 KB) and stale root docs committed in repo
- **Category**: 1 (Dead code), 7 (Build/CI/repo clutter)
- **Location(s)**: `POPSLoader/bin/POPSLDR/IMG/` (43 unused PNGs totaling 87,097 B, including `joypad.png` 46,643 B), `POPSLoader/banner.jpg` (345,431 B), `POPSLoader/imageformat.png` (93,021 B), `POPSLoader/bin/.pldrs` (0 B), `POPSLoader/OFFICIAL_NOTES.md` (identical SHA-256 to `RELEASE_1.4.4.md`, 1,859 B)
- **Problem**: 43 of 67 PNGs in `bin/POPSLDR/IMG/` (`arrow_*`, `bar_*`, `checkbox_*`, `down/left/right/up.png`, `icon_sub_*`, `joypad.png`, `L1..R3.png`, `osk_*`, `scroll_*`), plus `banner.jpg` and `imageformat.png` at repo root, have zero references in any source, Lua script, Makefile, or CI workflow (the 43 PNGs are only remnants of an earlier GUI). `OFFICIAL_NOTES.md` duplicates `RELEASE_1.4.4.md` byte-for-byte, and empty `bin/.pldrs` is checked in.
- **Fix**: Delete the 43 unused PNGs, `banner.jpg`, `imageformat.png`, empty `bin/.pldrs`, and duplicate `OFFICIAL_NOTES.md` (have `official-release.yml` reference `RELEASE_<tag>.md`).
- **Benefit**: **527,408 B** dead image/doc clutter and 48 unnecessary files removed from repo and release kits.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-012: Unchecked C buffer/bounds in `lua_sifloadmodulebuffer`, `luaHDD.cpp` slot formatting, `sound_loadadpcm`, and `loadFont`
- **Category**: 6 (Bugs and security)
- **Location(s)**: `POPSLoader/src/luasystem.cpp:2608-2625`, `POPSLoader/src/luaHDD.cpp:47,61-62`, `POPSLoader/src/sound.cpp:77-79`, `POPSLoader/src/graphics.cpp:932-936`, `POPSLoader/src/atlas.cpp:14,86,97,107`, `POPSLoader/src/fntsys.cpp:138-151`
- **Problem**:
  - `lua_sifloadmodulebuffer` takes `size` from Lua arg 2 without validating it against `luaL_checklstring`'s returned length and passes a potentially unaligned Lua string directly to `SifExecModuleBuffer`.
  - `UmountPart` (`PFS[3] = '0' + luaL_checkinteger`) and `mnt` (`PFS[3] = '0' + index`) do not range-check `0..9`, producing corrupted device names on invalid input.
  - `sound_loadadpcm` ignores the return value of `audsrv_load_adpcm` and returns an uninitialized/unloaded sample handle.
  - `loadFont` ignores `open()` `< 0` before calling `read(file, &magic, 2)` and `close(file)`, matching on stack garbage `magic`.
  - `fntsys.cpp:readFile` leaks `fd` when `malloc`/`memalign` returns `NULL` and does not guard `realSize <= 0`.
  - `atlas.cpp:allocNew` and `atlasNew` dereference `malloc`/`memalign` results without `NULL` checks.
- **Fix**: Validate `size <= len` in `lua_sifloadmodulebuffer`, range-check PFS slot indices (`0..9`), check `audsrv_load_adpcm` return / `open() < 0` / allocation `NULL` returns, and close `fd` on OOM in `fntsys.cpp`.
- **Justification**: Each check prevents memory corruption, fd leaks, or crashes on malformed inputs or low EE RAM.
- **Benefit**: Eliminates 6 distinct C memory-safety / fd-leak / hardware-interface bugs (~20 lines added total).
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-013: `System.listDirectory` dead `path[4]` check, stack bloat, and unchecked `mcGetDir` return on `mc0:`/`mc1:`
- **Category**: 6 (Bugs and security), 1 (Dead code), 4 (Size and memory)
- **Location(s)**: `POPSLoader/src/luasystem.cpp:35,716-741`
- **Problem**: Line 716 enters the MC fast path only when `strcmp(path, "mc0:") == 0` or `strcmp(path, "mc1:") == 0` (so `path[4]` is always `'\0'`), making both `path[4] ? ...` branches at lines 731-732 unreachable dead code. It also allocates `sceMcTblGetDir mcEntries[512]` (~32 KB, INFERRED sizeof 64) on the EE stack without initializing `numRead` or checking `mcGetDir`/`mcSync` errors before looping `i < numRead`.
- **Fix**: Remove the dead ternary expressions (`mcPath` is simply `"/*"`), initialize `numRead = 0`, check `mcSync` / `mcGetDir` `< 0` error returns, and reuse or heap-allocate `mcEntries` with a check instead of putting 512 entries on the EE thread stack.
- **Justification**: Guarding `numRead < 0` prevents garbage iteration / Lua errors when no memory card is inserted.
- **Benefit**: Fixes potential UB on missing/failing MC + saves ~32 KB stack frame overhead.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-014: `System.rename` copies bytewise via `BUFSIZ`, ignores `remove()` error, and destroys data if `oldName == newName`
- **Category**: 6 (Bugs and security), 5 (Performance)
- **Location(s)**: `POPSLoader/src/luasystem.cpp:826-877`
- **Problem**: `lua_rename` always falls back to `copy_file_contents` (`open(dst, O_WRONLY | O_CREAT | O_TRUNC)`) + `remove(oldName)`, ignoring `remove`'s return value and opening `dst` with `O_TRUNC` while reading `src`, which silently erases the file if `oldName` and `newName` resolve to the same path. On PS2 drives (`mass:`/`mc:`/`pfs:`), it also copies entire files instead of calling `rename()` first when paths share a device.
- **Fix**: Reject `strcmp(oldName, newName) == 0` early, try POSIX `rename(oldName, newName)` first, and only copy-and-remove across devices if `rename` fails, checking `remove()`'s return code.
- **Justification**: Guarding equal paths and checking `remove()` prevents silent data loss and double-copy overhead.
- **Benefit**: Eliminates silent self-truncation data-loss bug and makes intra-device renames instantaneous.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-029: Unreachable Settings fallback strands `UI.PendingHideRebuild`, leaving stale hidden/collapsed rows on list return (+62 dead lines)
- **Category**: 6 (Bugs and security), 1 (Dead code)
- **Location(s)**: `POPSLoader/bin/POPSLDR/ui.lua:4092-4095,4508-4605,4608`, `POPSLoader/bin/POPSLDR/system.lua:6567,6652-6664,6752-6755`
- **Problem**: In `UI.ProfileQuery.Play`, `queue_exit` returns via `PLDR.CommitSettingsChanges` whenever it is defined (`system.lua:6567`), leaving lines `ui.lua:4544-4605` (62 lines of incomplete legacy commit logic) unreachable. However, `UI.PendingHideRebuild = true`, `PLDR._GLOBAL_HIDE_SAVED = nil`, and `UI.RevealHidden = false` (`ui.lua:4564-4576`) live only inside that unreachable block, so toggling `Hidden games` or `Multi-disc entries` and saving fails to trigger the rebuild at `ui.lua:4092-4095`.
- **Fix**: Delete `ui.lua:4544-4605` and set `UI.RevealHidden = false`, `PLDR._GLOBAL_HIDE_SAVED = nil`, and `UI.PendingHideRebuild = true` (when `global_hide_val` or `multidisc_collapse_val` changed) in the `if ok_run and result == true then` branch at `ui.lua:4608`.
- **Justification**: Restores missing state invalidation (3 lines) while deleting 62 dead lines for a net reduction.
- **Benefit**: Refreshes game lists immediately after visibility/collapse changes and removes 62 lines of dead code.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-030: `UI.RetroGemGameId` missing from `HasUnsavedChanges()`, silently discarding edits on `BACK`
- **Category**: 6 (Bugs and security)
- **Location(s)**: `POPSLoader/bin/POPSLDR/ui.lua:5250-5256,5375-5402,5879-5886`
- **Problem**: Settings provides a `"Retro GEM Game ID"` toggle backed by `UI.RetroGemGameId`, dirty-marked at line `5255` and saved at `4499,4528`, yet `HasUnsavedChanges()` (`5375-5402`) checks the other 11 settings while omitting `UI.RetroGemGameId`. Changing only `"Retro GEM Game ID"` and pressing `BACK` skips `OpenSettingsActionMenu` and discards the edit.
- **Fix**: Add `(UI.RetroGemGameId == true) ~= (UI.SettingsEntryRetroGemGameId == true)` to `HasUnsavedChanges()`.
- **Justification**: One-line condition fixes silent loss of user Retro GEM configuration changes on `BACK`.
- **Benefit**: Prevents silent Settings data loss without changing save/rollback flow.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-031: `PLDR.ApplyBdmaMode` ignores `WriteBdmaModeMarker` failures in non-fast paths and `ClassifyStartupMassTargets` leaks `"ata"` roots into USB startup init
- **Category**: 6 (Bugs and security), 5 (Performance)
- **Location(s)**: `POPSLoader/bin/POPSLDR/system.lua:7016-7045,7065-7080,7862-7863,7909-7911,7965-7966,8049`
- **Problem**: Unlike the fast-launch branch (`7909-7911`), non-fast paths in `PLDR.ApplyBdmaMode` (`7862-7863`, `7965-7966`) ignore `WriteBdmaModeMarker(selected)` failures and return `true`, desynchronizing effective `bdma_mode.txt` checks in `IsBdmaModeEquipped` (`8049`). Meanwhile `ClassifyStartupMassTargets` (`7035-7040`) treats every non-`"mx4sio"` mass root (including `"ata"` returned by `ClassifyMassRootDriver` at `7020-7022`) as `targets.usb = true`, running `EnsureUsbMassReadyOnce` unnecessarily on `ata` exFAT boots.
- **Fix**: Check `WriteBdmaModeMarker(selected)` at `system.lua:7862` and `7965` and return `false` on failure; change `ClassifyStartupMassTargets` to `elseif kind ~= "ata" then targets.usb = true end`.
- **Justification**: Prevents silent MC marker desync and avoids needless USB mass bring-up stalls on `ata`-backed exFAT boots.
- **Benefit**: Fixes BDMA state desync on MC write errors and avoids spurious USB startup probing.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-015: `lua_set` timer bug adds `val` instead of subtracting when running; `lua_destroy` leaves `TIMER_MAGIC` intact
- **Category**: 6 (Bugs and security)
- **Location(s)**: `POPSLoader/src/luatimer.cpp:25,96,112-121`
- **Problem**: When `src->isPlaying` is true, `lua_set` assigns `src->tick = clock() + val`, so subsequent `lua_time` (`clock() - src->tick`) returns negative elapsed time instead of `val` as expected when setting a running timer (`clock() - val`). Additionally, `lua_newT` does not NULL-check `malloc`, and `lua_destroy` frees `timer` without clearing `timer->magic`, weakening the `TIMER_MAGIC` use-after-free check.
- **Fix**: Set `src->tick = clock() - val` when playing, NULL-check `malloc`, and set `timer->magic = 0;` before `free(timer)`.
- **Justification**: `NULL`-checking `malloc` and clearing `TIMER_MAGIC` prevent OOM crashes and stale-handle use-after-free bugs.
- **Benefit**: Fixes negative elapsed timer values and catches double-free / stale-handle bugs.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-016: Leaked `Timer.new()` instances across launch and input-debug paths + dead `DEBUG_INPUT_LOG` block
- **Category**: 1 (Dead code), 4 (Size and memory), 6 (Bugs)
- **Location(s)**: `POPSLoader/bin/POPSLDR/system.lua:10593`, `POPSLoader/bin/POPSLDR/ui.lua:6499,6670-6693`
- **Problem**: `system.lua:10593` calls `LaunchState.fade_timer = Timer.new()` on every game launch failure/return without destroying any prior timer (`Timer.destroy`), leaking heap memory. In `ui.lua:6670-6693`, the `if UI.InputConfig.DEBUG_INPUT_LOG` block computes local booleans `up`, `down`, `cross`, `circle` and timer deltas that are never printed, logged, or returned.
- **Fix**: Delete the dead `UI.InputConfig.DEBUG_INPUT_LOG` timer/button block and unused `DebugPadTimer`/`NavEventTimer` fields, and reuse or destroy `LaunchState.fade_timer` (better: compute elapsed directly via a single clock call or reuse one timer).
- **Benefit**: Eliminates small native C heap leaks and 24+ lines of dead code.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-017: Massive CI workflow duplication, broken `lupa` install in Alpine/musl, and one-shot script left in `.github/workflows/`
- **Category**: 2 (Duplication), 7 (Build/CI/repo clutter)
- **Location(s)**: `POPSLoader/.github/workflows/compilation.yml:154-169`, `POPSLoader/.github/workflows/rolling-release.yml:1-576`, `POPSLoader/.github/workflows/experimental-release.yml:1-501`, `POPSLoader/.github/workflows/official-release.yml:1-131`, `POPSLoader/.github/workflows/retract-mislabeled-ember-beta.yml:1-40`
- **Problem**: `rolling-release.yml` (576 lines) and `experimental-release.yml` (501 lines) copy-paste ~450 lines of YAML, ELF build, release kit assembly, and Python validation scripts, while also duplicating checks in `compilation.yml` and `official-release.yml` (which hardcodes `1.4.4`). All three build workflows also attempt `pip install lupa` inside the Alpine/musl `ps2dev` container where it cannot install and self-skips despite already having a dedicated Ubuntu `lua-harness` job, and `retract-mislabeled-ember-beta.yml` is a one-off retired tag script still living in `.github/workflows/`.
- **Fix**: Extract shared release-packaging logic into a reusable workflow or Python/shell script in `tools/`, remove the useless `pip install lupa` block inside the `ps2dev` container, parameterize `official-release.yml` from tag name, and delete `retract-mislabeled-ember-beta.yml`.
- **Benefit**: Cuts **~600+ lines** of duplicated YAML/CI code and avoids confusing self-skipped checks in every build log.
- **Effort**: M. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-018: Overlapping Lua cache writers and game-list cache serializers in `system.lua`
- **Category**: 2 (Duplication)
- **Location(s)**: `POPSLoader/bin/POPSLDR/system.lua:5261-5291,5421-5509`, `POPSLoader/bin/POPSLDR/system.lua:9880-10041`
- **Problem**: Three near-identical 32 KB chunked write loops exist in `system.lua`: `WriteAtomic`, `WriteBytesDirectBounded`, and `WriteBytesAtomicBounded`. Likewise, `PLDR.SaveGameListCache`/`PLDR.LoadGameListCache` (used for SMB/USB/etc.) and `PLDR.HDD.CreateCache`/`PLDR.HDD.ReadCache` duplicate the exact same `PLDRGC1` / `S ` / `G ` / `H ` serialization and parsing code; `PLDR.HDD.WipeCache(CACHE)` also takes an unused `CACHE` argument.
- **Fix**: Unify the chunked writer behind a single helper (`WriteBytes(dest, data, atomic)`), route `PLDR.HDD.CreateCache`/`ReadCache` through `PLDR.SaveGameListCache`/`LoadGameListCache`, and drop the unused `CACHE` parameter.
- **Benefit**: Removes ~100 lines of duplicated I/O and parser code from `system.lua` (~3 KB script reduction).
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-019: Redundant path/string/clamp helpers across `system.lua` and `ui.lua`
- **Category**: 2 (Duplication)
- **Location(s)**: `POPSLoader/bin/POPSLDR/system.lua:23-43,136-171,221-230,4966-4976,5615-5617,10181-10187`, `POPSLoader/bin/POPSLDR/ui.lua:14-25,87-97,122-125,1946`
- **Problem**: `system.lua` defines seven overlapping path/slash normalizers (`EnsureTrailingSlash`, `NormalizeDeviceRoot`, `NormalizeHostPath`, `NormalizeFsPathRaw`, `EnsureTrailingSlashNormRaw`, `NormalizeDirPath`, and unused `PLDR.EnsureTrailingSlashNorm`). Both files also define duplicate clamping (`CLAMP` in `system.lua`, `Clamp`/`Clamp01` in `ui.lua` plus a shadowing `local function Clamp01` at `ui.lua:1946`) and duplicate `.VCD`/basename stripping (`StripVcdExtension` at both `system.lua:10181` and `ui.lua:122`, plus `BasenameWithoutExtension`).
- **Fix**: Consolidate path normalization in `system.lua` to one canonical helper, expose one `CLAMP` and `StripVcdExtension` for both `system.lua` and `ui.lua`, and remove the dead wrapper `PLDR.EnsureTrailingSlashNorm` and shadowed `Clamp01`.
- **Benefit**: Removes ~60 lines of duplicate Lua helpers and eliminates subtle path-normalization divergence bugs.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-020: Unused C/Lua functions and dead parameters across `system.lua`, `ui.lua`, `luaplayer.cpp`, `elf.c`
- **Category**: 1 (Dead code)
- **Location(s)**: `POPSLoader/bin/POPSLDR/system.lua:944-960,2153-2155,4972-4976,5615-5617,10364-10377,11320-11328`, `POPSLoader/bin/POPSLDR/ui.lua:1704`, `POPSLoader/src/luaplayer.cpp:255-257`, `POPSLoader/src/elf_loader/src/elf.c:109-112`
- **Problem**: Several functions have zero callers anywhere in the repo: `ResolveHddGamePartitionReadablePath`, `PLDR.GetBootKind`, `CYCLE_CLAMP`, `PLDR.EnsureTrailingSlashNorm`, `GetBootOccupiedPfsSlot`, and `Touch` (which also closes `FD` without checking `< 0`). `UI.flip(notif)`, `runScript(..., bool isStringBuffer)`, and `build_exec_keep_mask(const char *resolved_path)` accept unused parameters.
- **Fix**: Delete the dead Lua functions and unused C/Lua parameters.
- **Benefit**: Removes ~75 lines of dead code.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-032: Broken `order_with_start_r2` (`"HDD Alt"` / `"Start"`) footer legend wiring, invalid `triangle` lookup, and 35-line dead placeholder block in `GameList.Play`
- **Category**: 1 (Dead code), 6 (Bugs and security)
- **Location(s)**: `POPSLoader/bin/POPSLDR/ui.lua:1547-1618,3254-3288,4338-4346`
- **Problem**: `GameList.Play` (`4338-4346`) calls `UI.Footer.ResolveLegend` with `order_with_start_r2`, `start`, and `R2 = "HDD Alt"`, but `order_with_start_r2` (`1547`) only contains `{"confirm", "back"}`, `ResolveLegend` discards `r2_label` after hashing it, line `1599` indexes undefined `UI.Footer.labels.triangle`, and no active `R2` glyph is mapped (`POPSLOADER-011`). Just above, `GameList.Play` (`3254-3288`) declares permanently empty `titles = {}` and `placeholders = {}` tables and runs a 21-line dead `if placeholder_title ~= nil` branch on every Game List frame.
- **Fix**: Delete `ui.lua:3254-3288` and the dead `triangle` lookup (`1599`), and either wire `"start"` (and `"R2"` if desired on `GHDD`) through `order_with_start_r2` and `ResolveLegend` or drop the unused `R2` parameter/order and reuse `order_with_start`.
- **Benefit**: Removes ~40 lines of dead/misleading UI footer and placeholder logic and fixes broken footer hints.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-021: `elf_loader` double BRAM wipe, wasted arg buffer, stale `launch_argv` pointer, and forced 864 KB rebuild
- **Category**: 6 (Bugs and security), 4 (Size and memory), 7 (Build/CI/repo clutter)
- **Location(s)**: `POPSLoader/src/elf_loader/src/elf.c:420,497,545-573`, `POPSLoader/src/elf_loader/Makefile:30-33`, `POPSLoader/src/elf_loader/loader.c` (8,740 lines / 864,561 B)
- **Problem**: `RunLoaderElf` wipes BRAM at line 497 before calling `ExecuteViaEmbeddedLoader`, which wipes BRAM again at line 420. In the `LoadExecPS2` fallback (lines 545-563), `stored_filename` is written to `launch_arg_storage` even when `!use_default_argv0` (wasting arg buffer space), `argv[i] == NULL` skips clearing `launch_argv[i]` (leaving any stale pointer from a previous call), and lines 571-572 `DPRINTF` `launch_argv[1..2]` unconditionally before checking `new_argc`. In build clutter, `loader.c` (an 864 KB generated C array) is committed to git and unconditionally rebuilt via `FORCE`.
- **Fix**: Wipe BRAM once inside `ExecuteViaEmbeddedLoader`, store `stored_filename` only when `use_default_argv0` is true, zero `launch_argv` before filling and break/error on NULL `argv[i]`, guard debug `DPRINTF` by `new_argc`, and stop committing generated `loader.c` (build it into `obj/`/`asm/` cleanly when `loader.elf` changes).
- **Justification**: Zeroing `launch_argv` and guarding `DPRINTF` prevent stale argument pointers and out-of-bounds reads across ELF launches while removing `864 KB` of generated C clutter.
- **Benefit**: Fixes stale-argv and arg-buffer waste bugs + drops an 864 KB committed generated C file from git.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-022: Unused `modules/pademu/` duplicate of `ds34bt`/`ds34usb`, stale `iop/ata_bd_fast`, and unused `PS2SDK_MX4SIO` binary
- **Category**: 1 (Dead code), 2 (Duplication), 7 (Build/CI/repo clutter)
- **Location(s)**: `POPSLoader/modules/pademu/`, `POPSLoader/modules/ds34bt/`, `POPSLoader/modules/ds34usb/`, `POPSLoader/iop/ata_bd_fast/`, `POPSLoader/iop/embed/PS2SDK_MX4SIO/mx4sio_bd.irx`, `POPSLoader/Makefile:145-146,338-352,389-419`
- **Problem**: `modules/pademu/` contains a parallel copy of `ds34bt.c`/`ds34usb.c` (totaling ~248 KB across `modules/`) that is never referenced by `Makefile`. `iop/embed/PS2SDK_MX4SIO/mx4sio_bd.irx` (15,089 B) and `iop/ata_bd_fast/` are explicitly documented as unused in `Makefile:338-351`, and `Makefile` keeps unused rules for `EMBED/%.png` (none exist) and dummy VCD targets (`dummys`/`cleandummy`).
- **Fix**: Delete `modules/pademu/`, `iop/ata_bd_fast/`, `iop/embed/PS2SDK_MX4SIO/`, and the dead `Makefile` rules.
- **Benefit**: Removes unused C/IOP trees, 15 KB dead binary, and ~40 lines of dead `Makefile` rules.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-023: Duplicated PNG row-buffer alloc/cleanup blocks in `src/graphics.cpp`
- **Category**: 2 (Duplication)
- **Location(s)**: `POPSLoader/src/graphics.cpp:169-193,214-254,264-306`
- **Problem**: `loadPNG` repeats the same `row_pointers` allocation (`calloc`), per-row `malloc(row_bytes)`, `png_read_image`, and row-cleanup sequence three separate times across RGBA, 4-bit palette, and 8-bit palette branches.
- **Fix**: Extract the `row_pointers` allocation/read/free sequence once around the format conversion switch instead of repeating it per branch.
- **Benefit**: Removes ~35 lines of duplicated libpng setup/teardown code and prevents future divergence on error paths.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-024: `RunSmbConnectFlow` calls `PLDR.CleanupGameList()` twice back-to-back
- **Category**: 5 (Performance), 1 (Dead code)
- **Location(s)**: `POPSLoader/bin/POPSLDR/ui.lua:7164,7175`
- **Problem**: Inside `RunSmbConnectFlow`, `PLDR.CleanupGameList()` is called at line 7164, then called a second time immediately after `InitSMBPopsRoot` returns at line 7175 even though no game list was populated in between.
- **Fix**: Delete the redundant call at line 7175.
- **Benefit**: Minor simplification (~1 line + redundant cleanup pass).
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-025: Redundant `strlen(driver) == 3` after `strcmp(driver, "ata") == 0`
- **Category**: 3 (Overengineering)
- **Location(s)**: `POPSLoader/src/luasystem.cpp:313`
- **Problem**: Line 313 checks `if (strcmp(driver, "ata") == 0 && strlen(driver) == 3)`; once `strcmp(driver, "ata") == 0` succeeds, `strlen(driver)` is guaranteed to be `3`.
- **Fix**: Remove `&& strlen(driver) == 3`.
- **Benefit**: Removes a redundant scan on every BDM device probe.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-026: `.gitattributes` omits LF pinning on `PATHMAP.INI.example`, breaking `test_udpfs_integration.py` on Windows
- **Category**: 6 (Bugs), 7 (Build/CI/repo clutter)
- **Location(s)**: `POPSLoader/.gitattributes:1-6`, `POPSLoader/tools/test_udpfs_integration.py:91-94`
- **Problem**: `test_udpfs_integration.py` asserts an exact SHA-256 over `docs/third_party/okeanos_udpfs/PATHMAP.INI.example`, which fails on Windows checkouts under `.gitattributes` (`* text=auto`) because git converts its line endings to CRLF.
- **Fix**: Mark `docs/third_party/okeanos_udpfs/PATHMAP.INI.example` (or `*.example` / `*.INI.example`) as `text eol=lf` or `binary` in `.gitattributes`.
- **Benefit**: Fixes the failing host test (`test_udpfs_integration.py`) on Windows without altering the test assertion.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### POPSLOADER-027: Repo clutter from 34 stale GitHub branches and 19 non-release/checkpoint/beta tags
- **Category**: 7 (Build/CI/repo clutter)
- **Location(s)**: Remote git refs (`NathanNeurotic/POPSLoader` metadata snapshot)
- **Problem**: The remote repository retains 38 branches and 37 unique tags, including obsolete `BETA-*` branches (`BETA-3-restarts`, `BETA-8-5`, `BETA-9`, `BETA-12-PLAY`, `CHECKPOINT2`), 23 agent thread/fix/chore branches (`claude/popsloader-*`, `claude/project-thread-*`, `codex/*`, `fix/*`, `maintenance/*`, `chore/*`, `research/*`, `style/*`), one open PR branch (`claude/project-thread-a6r2dq`, PR #642), and 19 old checkpoint/backup/`BETA-*` tags.
- **Fix**: Delete merged/abandoned agent, beta, and checkpoint branches and archive/prune superseded `checkpoint/*`, `backup/*`, and old `BETA-*` tags (keeping `master`, `dev`, `experimental`, `gh-pages`, active PR #642 branch if still in review, and release/rolling tags).
- **Benefit**: Cleans up ~33 stale branches and ~19 obsolete tags.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

---

## Files Not Read (and Why)

1. `POPSLoader/src/elf_loader/loader.c` (8,740 lines, 864,561 B): Read lines 1-120 only; the remainder is an auto-generated C byte array embedding `src/elf_loader/src/loader/src/loader.c` (which was read in full).
2. `POPSLoader/bin/`, `POPSLoader/EMBED/`, `POPSLoader/iop/embed/`, `POPSLoader/POPSTARTER/` binary assets (`.irx`, `.png`, `.ttf`, `.adp`, `.ELF`, `.icn`, `.gz`): Binary payloads verified by file size, SHA-256 hash, `Makefile` / `embed_assets.cpp` / Lua references rather than disassembling IRX/ELF machine code.
3. `POPSLoader/modules/ds34bt/*.c` and `POPSLoader/modules/ds34usb/*.c` and `POPSLoader/modules/pademu/*.c`: Audited all 13 `ds34bt`/`ds34usb`/`pademu` C and header files (`ds34bt.c`, `ds34usb.c`, `sys_utils.c`, `sys_utils.h`, `ds34_common.h`, `pademu.c`, `pademu.h`, `ds34usb_pademu.c`, `ds34bt_pademu.c`, `bt_hid.c`, `bt_l2cap.c`, `bt_hci.c`, `bt_sdp.c` / Makefiles; see `CROSS-012` in `Gemini-SUMMARY.md` for findings). Only `modules/` subprojects without full line-by-line review are embedded binary `.irx` payloads in `bin/` / `EMBED/` / `iop/embed/`.
4. `POPSLoader/.research/` (312 files, 21.36 MB) and long-form archival documentation (`ARCHITECTURE.md`, `DECISIONS.md`, `EXPERIMENTAL_NOTES.md`, `QA_REGRESSION_MATRIX.md`, `STATE.md`, `TESTING.md`, `ROADMAP.md`, `CONTRIBUTING.md`, `AGENTS.md`, `COMPONENTS.md`, `docs/`): Verified via directory inventory and `tools/docs_verify.py` rather than full line-by-line prose review.
5. All `POPSLoader/tools/` Python, Lua, C, and shell files (`host_harness.py`, `pad_harness.py`, `embed_assets.cpp`, `docs_verify.py`, and all `tools/test_*.py` / `tools/*.py` / `tools/*.sh` scripts) were read in full and executed. Only the auto-generated mock data tables inside test fixture payloads beyond the assertions were skimmed during execution.
