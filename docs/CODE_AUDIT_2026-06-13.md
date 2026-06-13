<!-- Generated 2026-06-13 by a 7-lens multi-agent audit (41 agents, ~3.5M tokens) at branch BETA-12-PLAY tip 0e51ece. Every removal claim was adversarially verified against source (dynamic Lua dispatch, string-loaded IRX, embedded-asset keys, hardware-conditional paths). DOCUMENT-ONLY: nothing in the codebase was changed. -->

# POPSLoader Audit Report — Dead Code, Removable Features, Blobs & Optimizations

**Branch:** BETA-12-PLAY · **Tip:** 0e51ece · **Scope:** hand-written `src/*.cpp/.c/.h` (excluding generated `src/elf_loader/loader.c`), embedded Lua (`bin/POPSLDR/*.lua`, `etc/boot.lua`), build wiring (`Makefile`), and vendored blobs (`iop/embed/`). **Disposition:** DOCUMENT-ONLY — every item is a proposal; nothing changed.

---

## Executive Summary

The codebase carries a substantial layer of inherited Enceladus-framework machinery (a full 3D OBJ/lighting/camera renderer, an unused MD5 hasher, orphaned SMB/strUtils source files) plus several leftover Lua helpers and never-enabled feature flags. The single largest win by far is the **dead 3D pipeline** (~41 KB of EE source + the `-lmath3d` static lib), which is conclusively unreachable from this 2D launcher's embedded Lua. Beyond that, removals are mostly maintainability gains: ~250 lines of dead Lua, ~700 lines of orphaned C, ~12 KB of embedded icon PNGs, and ~1.55 MB of repo-only vendored blobs.

Two adversarial verdicts **refuted** removals that look dead but aren't (a documented public API, an in-progress cache feature) and downgraded two feature cuts to "maintainer-decision" (device-lock entanglement, DS34 hardware path). Those are preserved below in a **Do NOT remove** tier with the reference that saved them.

### Prioritized Top 10 (impact × confidence)

| # | Item | Category | Est. impact | Confidence |
|---|------|----------|-------------|------------|
| 1 | **3D pipeline (`render.cpp`+`calc_3d.cpp`+`gsKit3d_sup.cpp`+`luaRender.cpp` + `-lmath3d`)** | Removable feature | ~41 KB EE source + static lib out of ELF | high |
| 2 | **`md5.cpp` + `System.md5sum` binding** | Dead code | ~297-line `.cpp` + object out of ELF | high |
| 3 | **7 d-pad/shoulder icon PNGs (L1/R1/R2/left/right/up/down)** | Removable asset | ~12 KB embedded PNG out of ELF | high |
| 4 | **`BDMASSAULT_MX4SIO/` tarball + duplicate IRX** | Removable asset | ~1.5 MB repo size | high (policy call) |
| 5 | **Duplicate top-level `iop/embed/mx4sio_bd.irx`** | Removable asset | ~15 KB repo + footgun | high |
| 6 | **`bdmfs_vfat.irx` + `mx4sio_bd_mini.irx` (never embedded)** | Removable asset | ~44 KB repo | high |
| 7 | **Nonexistent System/_G init shims (always-false guards)** | Dead Lua | ~25 lines | high |
| 8 | **5 dead local fns in `system.lua` (HDD launch-prep)** | Dead Lua | ~70 lines | high |
| 9 | **`luaSMB.cpp` + `strUtils.c` orphan files** | Dead code | 2 misleading files (no ELF impact) | high |
| 10 | **`waitPadReady` unbounded busy-wait (hang-class)** | Optimization | removes main-thread hang risk | high |

### Rough total file-size reduction

- **ELF (binary):** ~41 KB (3D) + ~297-line `md5.o` + ~12 KB icon PNGs + several KB of trimmed bindings ≈ **50–60 KB+** of EE binary, plus the `-lmath3d` static-lib contribution. Meaningful for a packed PS2 ELF.
- **Repo (source tree):** ~1.5 MB (BDMAssault tarball) + ~15 KB (mx4sio dup) + ~44 KB (vfat + mini) ≈ **~1.6 MB**, none of it embedded today.
- **Maintainability:** ~400+ lines of dead/orphaned C/C++ + ~250 lines of dead/inert Lua removed; numerous magic-constant and copy-paste consolidations.

---

## (1) Removable Enceladus Features (file-size)

### Recommended (adversarially confirmed safe to remove)

#### 1.1 — 3D render pipeline (Render/Lights/Camera + `-lmath3d`) — TOP PRIORITY
- **WHAT:** The entire 3D subsystem — `src/luaRender.cpp:104-201` (Render/Lights/Camera bindings), `src/render.cpp`, `src/calc_3d.cpp`, `src/gsKit3d_sup.cpp` — is compiled and linked but never invoked. `luaRender_init` (called at `src/luaplayer.cpp:284`) registers globals `Render`/`Lights`/`Camera` (`luaRender.cpp:185/189/193`), yet no `.lua` reads `Render.`/`Lights.`/`Camera.`/`loadOBJ`/`drawOBJ`/`drawBbox`/`AMBIENT`/`DIRECTIONAL`.
- **WHY:** POPSLoader is a 2D launcher. The OBJ/lighting/camera renderer is inherited Enceladus code with no use case; it is the sole consumer of `-lmath3d` (Makefile:51).
- **CORRECTION PLAN:** (1) Remove the `luaRender_init` call at `luaplayer.cpp:284` + its decl at `luaplayer.h:58`. (2) Drop `calc_3d.o gsKit3d_sup.o` (Makefile:81) and `luaRender.o` (Makefile:84). (3) Delete `luaRender.cpp`/`render.cpp`/`calc_3d.cpp`/`gsKit3d_sup.cpp`/`render.h` (included only by the four 3D TUs — verified at `calc_3d.cpp:1`, `gsKit3d_sup.cpp:1`, `luaRender.cpp:7`, `render.cpp:8`; no 2D file includes it). (4) Drop `-lmath3d` (Makefile:51). (5) Remove the 3D externs at `graphics.h:122-136`. Note: for full cleanliness also remove `#include <math3d.h>` (`graphics.h:12`) and the VECTOR-using `model`/`vData` structs (`graphics.h:41-58`), though those are header-only typedefs so leaving them is compile-safe. Rebuild + confirm link.
- **RISK:** low (revised from medium). The dependency cluster is closed; the live 2D path uses gsKit 2D prims in `graphics.cpp` (no VECTOR/MATRIX/math3d references). Standard caveat: run the CI link as final proof.
- **IMPACT:** file-size — removes ~41 KB EE source (render.cpp 19 KB + calc_3d 9.4 KB + gsKit3d_sup 7.9 KB + luaRender 4.9 KB) and the `-lmath3d` contribution. Largest single win.

#### 1.2 — `System.md5sum` binding + entire `md5.cpp`
- **WHAT:** `lua_md5sum` (`src/luasystem.cpp:804-823`, registered `:1470`) is the only consumer of `md5.cpp` (297 lines). `System.md5sum` is never called by any embedded Lua; `md5.h` is included only by `luasystem.cpp:14` and `md5.cpp:35`.
- **WHY:** Dead Lua binding whose removal makes all of `md5.cpp` dead.
- **CORRECTION PLAN:** Remove `lua_md5sum` + its `System_functions` entry (`:1470`), delete `src/md5.cpp` + `src/include/md5.h`, drop `md5.o` from Makefile:81.
- **RISK:** low. Verified no runtime-loaded Lua reaches it (the only external `loadfile` is `hdd_gamecache.lua`, a plain `PLDR.HDDCACHE` string table). Build-after-removal is the standard confirmation.
- **IMPACT:** file-size + maintainability — ~297-line `md5.cpp` + its object out of the ELF.

#### 1.3 — `Pads.setLED` / `Pads.rumble` bindings (couple to DS34 decision)
- **WHAT:** Within the live `Pads` table, `lua_rumble` (`luacontrols.cpp:175-195`) and `lua_set_led` (`:207-229`, registered `:238-239`) have zero Lua callers. The UI's only pad call is `Pads.get()` (`ui.lua:3476`).
- **WHY:** Dead leaves. Mostly meaningful only for the DS34 path.
- **CORRECTION PLAN:** Optional; best handled with the DS34 decision (§Do-NOT-remove 5.4). Removing the two entries + bodies does not orphan the native `padSetActDirect`/`ds34*_set_rumble`/`set_led` (still called by the DS34 modules).
- **RISK:** low. **IMPACT:** negligible code size; API-surface trim.

> See also §2.1 (`luaSMB.cpp`) and §2.2 (`strUtils.c`) — orphan source files that also read as "removable features" but are categorized as dead code below.

---

## (2) Dead Code

### Recommended (confirmed safe to remove)

#### 2.1 — `src/luaSMB.cpp` is an orphan (never compiled, no callers)
- **WHAT:** Defines `smbServer_t`/`smbServer` + `smbLogon_Server(int)` but is absent from Makefile `LUA_LIBS`/`APP_CORE` (no `luaSMB.o`). No `luaL_Reg` table, no `luaSMB_init`; `luaplayer.cpp:277-286` init list never calls it.
- **WHY:** No object produced; `smbLogon_Server` referenced only inside `luaSMB.cpp`. The Makefile has no wildcard — only an on-demand `%.o:%.cpp` rule (Makefile:361), so an unlisted `.cpp` never compiles.
- **DISTINCT FROM:** the live SMB *device* path (`smb:/POPS/` virtual FS, `UI.SCENES.GSMB`, "SMB (v1)" option, `SMB.png` icon) which routes via fileXio/POPSTARTER and never calls `smbLogon_Server`.
- **CORRECTION PLAN:** Delete `src/luaSMB.cpp`. No Makefile change needed.
- **RISK:** low. **IMPACT:** maintainability — removes a misleading ~67-line file. Zero ELF impact.

#### 2.2 — `src/strUtils.c` is an orphan (commented out, declarations-only)
- **WHAT:** Wrapped in `#ifndef STRUTILS_H ... #endif`, contains only DECLARATIONS of `str_split()` (`:4`) and `getMountInfo()` (`:18`) — no bodies. Commented out in `Makefile:82` (`sound.o #strUtils.o`).
- **WHY:** Never compiled; both symbols defined nowhere and called nowhere. No `strUtils.h` exists; nothing `#include`s it.
- **CORRECTION PLAN:** Delete `src/strUtils.c` and drop the `#strUtils.o` comment from Makefile:82.
- **RISK:** low. **IMPACT:** maintainability — removes a confusing stub. Zero ELF impact.

#### 2.3 — `RotTransPersClipGsColN` (only call site commented out)
- **WHAT:** Large VU0-asm routine defined `calc_3d.cpp:39-140`, declared `render.h:15`; its ONLY reference is the commented call `render.cpp:546` (`//RotTransPersClipGsColN(...)`). Internal block `calc_3d.cpp:103-126` is also commented-out asm.
- **WHY:** Dead within the 3D module — the live draw path uses `calculate_normals/lights/colours` (`render.cpp:549-552`) instead. Not in any `luaL_Reg` table.
- **CORRECTION PLAN:** Remove from `calc_3d.cpp` + `render.h:15` + the commented call. **Subsumed by §1.1** if the whole 3D subsystem goes.
- **RISK:** low. **IMPACT:** ~100 lines of asm + dead comment.

#### 2.4 — Unused 3D primitives: `gsKit_prim_triangle_gouraud_3d_fog`, `_st_fog`, `draw_convert_rgbaq`
- **WHAT:** `gsKit3d_sup.cpp:122-162`, `:164-226`, `calc_3d.cpp:257-287` — defined + declared (`render.h:40/48/24`), called nowhere. `drawOBJ` uses the NON-fog/NON-alpha siblings (`draw_convert_rgbq` `render.cpp:559`, `gsKit_prim_triangle_gouraud_3d` `:569`, `..._st` `:575`).
- **WHY:** Redundant primitive variants never wired up; dead within already-dead 3D code.
- **CORRECTION PLAN:** Delete the three functions + their `render.h` decls. **Subsumed by §1.1.**
- **RISK:** low. **IMPACT:** ~110 lines.

#### 2.5 — `graphics.cpp`: `drawImageCentered`, `setVSync`, `gsKit_clear_screens`
- **WHAT:** `drawImageCentered` (`:906`, not even declared in `graphics.h`) has no caller. `setVSync` (`:1102`, decl `graphics.h:74`) is the sole writer of the static `vsync` flag but has zero callers — so `vsync` is permanently its init value (`true`). `gsKit_clear_screens` (`:816`, decl `graphics.h:76`) is never called (the live clearer is `clearScreen()` at `:828`, reached via `Screen.clear`).
- **WHY:** Defined functions with no reachable call site in `src/` or any `.lua`. Not wrapped by any binding.
- **CORRECTION PLAN:** Remove `drawImageCentered`; remove `setVSync` (and collapse `vsync` to a const) or expose it if a toggle is intended; remove `gsKit_clear_screens`. Note `setVSync`/`gsKit_clear_screens` are extern in public `graphics.h` so removal is a maintainer judgment (forward-facing API vs. dead); `drawImageCentered` has no such ambiguity.
- **RISK:** low. **IMPACT:** maintainability + small code size.

#### 2.6 — `pad.cpp` `readPad()` defined + declared but never called
- **WHAT:** `readPad(int,int)` (`pad.cpp:131-144`, decl `pad.h:8`) has no callers. Live input is `isButtonPressed()` (`pad.cpp:146`) and the Lua bindings reading via `padRead` (`luacontrols.cpp`).
- **CORRECTION PLAN:** Remove `readPad` from `pad.cpp` + `pad.h:8`.
- **RISK:** low. **IMPACT:** maintainability (small).

#### 2.7 — `fntsys.cpp`: `fntLoadDefault`, `fntFitString`, global `max()`
- **WHAT:** `fntLoadDefault` (`:392`, decl `fntsys.h:30`) and `fntFitString` (`:831`, decl `fntsys.h:45`) have no callers. Global `int max(int,int)` (`:113`) is never called (sibling `min` is used at `:613/:739`) and pollutes the global namespace. **Trap avoided:** the `"LoadBuiltinFont"` binding (`luagraphics.cpp:117/232`) calls `fntLoadbuff`, NOT `fntLoadDefault`.
- **WHY:** Unreferenced; `__RTL` branch (never compiled — `__RTL` undefined) doesn't call `max()` either.
- **CORRECTION PLAN:** Remove `fntLoadDefault`, `fntFitString`, and global `max()` (or make `max` static). Keep `min()`.
- **RISK:** low. **IMPACT:** maintainability + tiny code size; removes a namespace footgun.

#### 2.8 — Nonexistent System/_G init shims (permanently-false `type()` guards)
- **WHAT:** Blocks like `if type(System.initMMCE)=='function' then pcall(...) end` guarding functions never registered in `luasystem.cpp:1452-1503` nor defined in Lua: `System.initMMCE` (`system.lua:1123-1125`, `:3487-3490`), `System.initUSB` (`:3342/:3372/:3530`), `System.initUSBMass` (`:3339/:3369`), `System.getMassDriverName`/`getMassDriver` (`:3025-3036`), `_G.ensureMmceInit` (`:1120-1122`), `_G.ensureMx4sioInit` (`:3355/:3494/:3521/:3860`).
- **WHY:** Portability shims copied from another Enceladus launcher; `System`/`_G` have no metatable, so the names never resolve and the bodies never run. The real registered names are `ensureMmceman`/`ensureUsbMass`/`initMX4SIO`/`getMassMountDriver`/etc.
- **CORRECTION PLAN:** Delete the dead guarded arms, keeping each block's live first arm. `PLDR.GetMassDriverName` (`:3018-3039`) folds into `PLDR.GetMassMountDriver` (which already has the live `System.getMassMountDriver` path at `:3043`).
- **RISK:** low (no-op branches today). **IMPACT:** ~25 misleading lines removed; no runtime change.

#### 2.9 — Five dead local functions in `system.lua` (HDD launch-prep)
- **WHAT:** `local function`s whose name appears exactly once (the definition): `EnsureHddExecPathReady` (`:930`), `IsPfsExecPath` (`:1222`), `FindMatchingProfileForPopstarterPath` (`:633`), `SelectHddLaunchGameSlot` (`:4315`), `EnsureHDDReadyForLaunch` (`:4339`, ~31 lines).
- **WHY:** Orphaned after refactors; the live launch path uses `MountHddPartitionTracked`/`ValidateHddPopstarterExecGate`/`ResolveFallbackMountedPfsExecPath`. As `local`s they are invisible to C (`lua_getglobal`) and other files. (Contrast: `ResolveHddExecMountedPath`/`GetActiveHddGameSlot` show a 2nd occurrence = used.)
- **CORRECTION PLAN:** Delete the five definitions. `EnsureHDDReadyForLaunch`'s module-level locals (`HDD_SLOT_GAME` etc.) stay live elsewhere.
- **RISK:** low. **IMPACT:** ~70 lines out of the most complex file.

#### 2.10 — `pops_profiles.lua` `ResolveProfilePath` (+ cascade `JoinPathCompat`)
- **WHAT:** `local function ResolveProfilePath(rel)` (`:40-42`) is never called — `PLDR.PROFILES` (`:44-109`) and `PLDR.POPSTARTER_PATH` (`:112`) use device-path string literals. Its only caller would be removed code, so `JoinPathCompat` (`:24`, only call at `:41`) becomes orphaned too.
- **CORRECTION PLAN:** Remove `ResolveProfilePath`; then remove `JoinPathCompat`. **Keep `NormalizeDirPathCompat`** (still used for `APP_DIR_LOCAL` at `:38`).
- **RISK:** low. **IMPACT:** ~3 lines (+ ~13 if `JoinPathCompat` falls out).

#### 2.11 — Four unused `UI` methods: `canEnterDevice`, `UpdateVmode`, `GetRowPosition`, `Modal.OpenDeviceLock`
- **WHAT:** `ui.lua:399` `canEnterDevice` (stub `return true`), `:432` `UpdateVmode` (duplicates the inlined `Screen.setMode(...)` at `:3709-3718`), `:514` `GetRowPosition` (carousel bypasses it with inline x-math at `:3244`), `:1413` `Modal.OpenDeviceLock` (~18-line modal, never shown). Each name appears once (the def); other `canEnterDevice` hits are docs prose only.
- **WHY:** Remnants of a disabled device-lock feature and a superseded layout/video path.
- **CORRECTION PLAN:** Remove all four. `UpdateVmode`/`GetRowPosition` are pure removals. For `OpenDeviceLock`, see §5.3 (device-lock decision) — it is the only UI surface for that feature. Removing it does not orphan `device_lock_name` (still live at `ui.lua:3221`).
- **RISK:** low. **IMPACT:** ~30 lines.

#### 2.12 — `CheckPOPStarterDEPS` body unreachable (`CHECK_POPSTARTER_FILES` never enabled)
- **WHAT:** `system.lua:3793-3808` short-circuits at `if not PLDR.CHECK_POPSTARTER_FILES then return true,true,true end`. The flag is set `false` at `:1931` and never set `true` (not by defaults loop, not by the 9-key settings encode/decode at `:2663-2673`/`:2884-2892`, not by `hdd_gamecache.lua`, not by C). The dependency-probe body and the three `if not a/b/c` toasts at `ui.lua:3360-3362` are unreachable.
- **WHY:** Feature-flagged HDD `__common` dependency probe shipped disabled-by-default; never wired to a setting.
- **CORRECTION PLAN:** Maintainer choice — (a) remove the inert body + simplify the `ui.lua` call site (drop a/b/c handling), OR (b) expose a setting to flip the flag true (making the body + toasts live). Do not remove silently if the probe is wanted.
- **RISK:** low. **IMPACT:** ~15 lines of probe + ~5 lines of handling.

#### 2.13 — Redundant second POPSTARTER name guard (unreachable)
- **WHAT:** `RunPOPStarterGame` returns for `string.upper(game_name)=="POPSTARTER"` at `system.lua:4961`; a later guard at `:5002` re-tests the same predicate (`selector_prefix=="" and ...=="POPSTARTER"`). `game_name` is a plain string unchanged between `:4950` (decl) and `:5073` (next write), so the `:5002-5018` block can never fire.
- **WHY:** Defense-in-depth that became redundant once the earlier unconditional guard was added.
- **CORRECTION PLAN:** Remove the `:5002-5018` block. Low priority — defensible to keep as a never-taken safety net at zero runtime cost.
- **RISK:** low. **IMPACT:** ~17 lines.

---

## (3) Removable / Redundant Blobs & Assets

### Recommended (confirmed safe to remove)

#### 3.1 — `BDMASSAULT_MX4SIO/` source tarball + duplicate IRX (~1.5 MB)
- **WHAT:** `iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz` (1,466,084 B) + `usbd.irx` (48,500 B) + `usbhdfsd.irx` (14,993 B). The two IRX are byte-identical (md5 `a77650a0...` / `48677ae0...`) to `bin/POPSLDR/usbd.irx.mx4sio` and `usbhdfsd.irx.mx4sio`, which ARE the embed inputs (Makefile:212-215 → EMBEDDED_RSC:103 → `embed_assets.cpp:147-148,196-197`). `vpath %.irx iop/embed/` (Makefile:232) is non-recursive and never reaches the subdir.
- **WHY:** Provenance/reference material the build never reads. Only references tree-wide: `.gitignore:59` (force-tracks the `.irx`), a docs note, the dir's own `README.MD`.
- **CORRECTION PLAN:** **Keep `LICENSE` + `README.MD`** (license/provenance). Consider removing the tarball (recoverable from upstream releases) + the two duplicate `.irx`. This is a reproducibility *policy* call, not correctness.
- **RISK:** low. **IMPACT:** ~1.5 MB repo size; no ELF impact. Lowest-priority removal (loses in-repo upstream-source provenance).

#### 3.2 — Duplicate top-level `iop/embed/mx4sio_bd.irx` (~15 KB + footgun)
- **WHAT:** Byte-identical (md5 `d63df3c9...`, 15,089 B) to `iop/embed/PS2SDK_MX4SIO/mx4sio_bd.irx`. The build's explicit rule (Makefile:267, target `mx4sio_bd.c`) sources ONLY the `PS2SDK_MX4SIO/` copy; GNU Make's explicit rule overrides the generic `%.c:%.irx` vpath rule, so the top-level copy is never consumed.
- **WHY:** Same-name two-copies footgun — editing the top-level one would silently not affect the build.
- **CORRECTION PLAN:** Delete the top-level `iop/embed/mx4sio_bd.irx`; keep the `PS2SDK_MX4SIO/` copy. **Keep the vpath line** — `bdm.irx`/`bdmfs_fatfs.irx` (no explicit rule) depend on it via the generic rule (Makefile:236). Run a clean build to confirm.
- **RISK:** low. **IMPACT:** ~15 KB repo; eliminates an edit footgun.

#### 3.3 — `iop/embed/bdmfs_vfat.irx` (never embedded, ~30 KB)
- **WHAT:** 29,310 B vendored IRX not in `IOP_MODULES` (Makefile:88-93), no bin2c rule, no extern symbol, no `LoadIrx*` call, no Lua ref. The repo uses `bdmfs_fatfs.irx` instead. Tree-wide grep for `bdmfs_vfat`/`vfat` = nothing.
- **CORRECTION PLAN:** Delete the file. No Makefile change. Recoverable from `$PS2SDK/iop/irx/` if VFAT is ever wanted.
- **RISK:** low. **IMPACT:** ~30 KB repo; no ELF impact.

#### 3.4 — `iop/embed/mx4sio_bd_mini.irx` (never embedded, ~14 KB)
- **WHAT:** 14,233 B "mini" variant not in `IOP_MODULES`, no rule, no symbol/Lua ref. The build embeds the full `mx4sio_bd.irx`; `luasystem.cpp:1436` loads only `"mx4sio_bd.irx"`. Grep for `mx4sio_bd_mini`/`bd_mini` = zero.
- **CORRECTION PLAN:** Delete the file. Recoverable from `$PS2SDK/iop/irx/`.
- **RISK:** low. **IMPACT:** ~14 KB repo; no ELF impact.

#### 3.5 — 7 embedded icon PNGs: L1, R1, R2, left, right, up, down (~12 KB ELF)
- **WHAT:** Seven button/direction PNGs are bin2c'd into the ELF and registered in both `images.lua:32-34,39-42` (IMG table) and `embed_assets.cpp:128-130,137-140` (+ duplicate `POPSLDR/IMG/` entries `:177-179,186-189`), but no code path requests them. The IMG metatable only materializes on `IMG[key]` access; these keys are never accessed. Sizes: L1 1455, R1 1492, R2 1827, left 1764, right 1833, up 1778, down 1843 = **11,992 B**.
- **WHY:** Footer legend uses only `triangle/circle/cross/square/start/select` (`ui.lua:726-732`); device carousel uses `MMCE/MX4SIO/BDHDD/APAHDD/USB/SMB/ILINK/DISC` (`ui.lua:3107-3116`). Both dynamic `IMG[key]` sites are bounded and provably cannot emit these 7 keys. The literals `"L1"/"R1"/"R2"` at `ui.lua:3523-3525` are gamepad ACTION names (`emit_action`), not IMG keys.
- **CORRECTION PLAN:** (1) Remove the 7 rows from `images.lua:32-34,39-42`. (2) Drop `asset_l1/r1/r2_png.o` (Makefile:99) + `asset_left/right/up/down_png.o` (Makefile:101) from EMBEDDED_RSC + their bin2c rules (Makefile:173-178, 187-194). (3) Remove externs (`embed_assets.cpp:52-57,68-75`) + ASSET_ENTRY lines (`:128-130,137-140,177-179,186-189`). The loose disk PNGs under `bin/POPSLDR/IMG/` can stay (they ship in the package, no ELF cost). The `#ifdef HAVE_ASSET_DEFAULT_PNG` `default.png` rows in `$(OPTIONAL_EMBEDDED_RSC)` (Makefile:100) are untouched. Conservative alternative: keep as backlog if a controller-prompt/d-pad UI is planned.
- **RISK:** low. **IMPACT:** ~12 KB of embedded PNG out of the ELF + 14 ASSET_ENTRY slots.

#### 3.6 — Stray empty untracked dir `iop/embed;C/`
- **WHAT:** Empty, untracked directory named `embed;C` next to `iop/embed/` — almost certainly a mis-quoted-shell artifact (stray `;C` appended to a path). Not in `git ls-files`/`git status`.
- **CORRECTION PLAN:** `rmdir 'iop/embed;C'`. Worktree-local cleanup, no git action.
- **RISK:** low. **IMPACT:** cleanliness only.

---

## (4) Optimizations

> All confirmed by analysis (`needs_verify=false`). Ordered by blast radius × confidence.

#### 4.1 — `waitPadReady` unbounded busy-wait (hang-class) — HIGH PRIORITY
- **WHAT:** `pad.cpp:15-37` loops `while((state != PAD_STATE_STABLE) && (state != PAD_STATE_FINDCTP1))` with no iteration cap, no sleep, and no `PAD_STATE_DISCONN` exit. Called from `initializePad()` (`:50,100,103,106,118,126`) and `pad_reinit()` (`:223`) — the latter runs on the MAIN thread mid-session via the MMCE lazy-load pad-rebuild. `readPad:136-138` and `isButtonPressed:153` have the same shape (though `isButtonPressed` *does* include the DISCONN guard — the intended pattern).
- **WHY:** A controller unplugged during a mid-session `pad_reinit` hard-spins forever on the main thread, freezing the UI; even normally it is a 100%-CPU busy-poll. (Maintainer task #17.)
- **CORRECTION PLAN:** Add a bounded retry (iteration cap or wall-clock timer), break on `PAD_STATE_DISCONN`, yield between polls (short delay/vsync). Return a status so `initializePad`/`pad_reinit` fail gracefully. Verify timeout on hardware.
- **RISK:** medium (changes pad-init timing on real hardware). **IMPACT:** removes a 100%-CPU spin and a potential main-thread hang on controller loss.

#### 4.2 — Game-list row labels re-parsed every frame
- **WHAT:** The visible-row loop (`ui.lua:2210-2225`, up to ~18 rows) runs per-row-per-frame: `string.match(display_name,"^[^|]+|(.+)$")` (`:2214`), a basename `string.match(...,"([^/]+)$")` (`:2216`), and `StripVcdExtension` (a `gsub`, `:2219`). `PLDR.GAMES[i]` is immutable while browsing.
- **CORRECTION PLAN:** Build a parallel `PLDR.GAME_LABELS` array with precomputed display labels when `PLDR.GAMES` is populated (HDD scan / `GetPS1GameLists`); index it directly in the draw loop. Keep raw `PLDR.GAMES` for launch-path resolution; invalidate both on rescan.
- **RISK:** low. **IMPACT:** ~50 transient string allocations/frame removed on the primary browsing screen.

#### 4.3 — Marquee scroller re-measures focused row O(n²)/frame
- **WHAT:** `FitFromLeft` (`ui.lua:92-100`) trims one byte at a time calling `Font.ftWidth` (= `fntCalcDimensions`, which walks every glyph — `fntsys.cpp:902`) after each trim, plus a `string.sub` allocation per iteration. For a 60-char title that's O(n²) glyph walks + dozens of substring allocs per frame, only for the focused overflowing row (`MarqueeLabel:101-114`, called from `ui.lua:2222`).
- **CORRECTION PLAN:** Precompute per-character cumulative advance widths once when the selection changes (cache keyed by `GameList.CURR`+label); binary-search/index the prefix-sum array to find fit length in O(log n). Avoids the O(n²) `ftWidth` calls and per-iteration `string.sub`.
- **RISK:** low. **IMPACT:** turns O(n²)/frame into O(n) once-per-selection on a game-list hot path. (Confidence: medium.)

#### 4.4 — Settings scene rebuilds item model + closures every frame
- **WHAT:** `UI.Settings.Play()` (`ui.lua:2737-2847`, dispatched per-frame from `system.lua:5342-5353`) allocates a fresh `items={}` and inserts ~20 rows + dozens of closures (`AddCycle`/`AddPath`/`AddAction` each capture closures, e.g. `:2825-2831`). Identical between frames except on dirty/draft change.
- **CORRECTION PLAN:** Build the `items[]` model + per-row closures once on scene-enter (or on draft mutation), cache on `UI.SettingsItemsCache`; `Play()` runs only the draw+input pass against the cache. `value()`/`dirty()` getters stay as closures (they read live state) — only their *construction* moves out of the per-frame path. Invalidate on enter + draft mutation.
- **RISK:** low. **IMPACT:** ~20 tables + ~30 closures/frame removed (secondary screen).

#### 4.5 — Input layer allocates a fresh queue + 4 closures every frame
- **WHAT:** `UI.Pad.Listen()` (`ui.lua:3482,3498-3526`, via `Input_GetEvent` `:3757`) reassigns `UI.Pad.Queue={}` and defines `emit`/`emit_nav`/`emit_action`/`resolve_nav` every call, in EVERY scene.
- **CORRECTION PLAN:** Hoist the four closures to module scope (or `UI.Pad` methods), passing `now`/`pressed` explicitly; preallocate `UI.Pad.Queue` and clear in place (or track a count). If `Queue` has no external consumer, drop it and use the already-preallocated `UI.Pad.Events` flags.
- **RISK:** low. **IMPACT:** 1 table + 4 closures/frame removed on the universal input path.

#### 4.6 — MainMenu rebuilds `icon_map`/`icon_keys` every frame
- **WHAT:** `ui.lua:3107-3122` (per-frame from `system.lua:5344`) allocates an 8-entry `icon_map` literal + builds `icon_keys` by looping `UI.MainMenu.opts` (fixed literal `:3084`). Pure function of static data.
- **CORRECTION PLAN:** Move `icon_map` to a file-local constant; precompute `icon_keys` once (lazily cache on `UI.MainMenu`). Reuse each frame.
- **RISK:** low. **IMPACT:** 2 tables + 8-iter loop/frame removed on a primary screen.

#### 4.7 — Redundant per-frame `Screen.clear` before opaque full-screen background
- **WHAT:** `UI.BottomDraw.Play()` (`ui.lua:1216-1234`) does `Screen.clear(UI.SCR.BGCOL)` (`:1216`, full-screen `gsKit_clear` `graphics.cpp:830`) then immediately draws an opaque full-screen `Graphics.drawScaleImage(IMG.BGM/BG/BKG, 0,0, SCR.X, SCR.Y)` — 100% overdraw when the background covers the framebuffer.
- **CORRECTION PLAN:** Only `Screen.clear` when no full-screen opaque background will be drawn (relevant `IMG.*` is nil); keep the clear strictly as the nil-image fallback.
- **RISK:** low. **IMPACT:** saves one full-screen fill/frame on every scene. Small (PS2 GS fillrate is high) but free + universal. (Confidence: medium.)

#### 4.8 — Commented-out scaffolding blocks left in source
- **WHAT:** `sound.cpp:14-72` (`/* fillbuffer + a full main() WAV-player reading host:song_22k.wav */`); `luaScreen.cpp:22-34` + `:142` (commented `lua_getP`/`getPixel` referencing `vita2d_get_current_fb()` — a Vita API); `luagraphics.cpp:588,596-598,604` (commented `luaL_Reg` entries for undefined `lua_gpixel`/`lua_loadanimg`/etc.).
- **CORRECTION PLAN:** Delete the commented blocks. The vita2d reference confirms foreign porting scaffolding.
- **RISK:** low. **IMPACT:** ~70 lines of misleading dead comments.

#### 4.9 — Empty no-op `if/else` husks
- **WHAT:** `system.lua:2169-2170` (`if PREFIX_HINT~=nil then end`), `:2220-2222` (`if boot_name~=nil then else end`), `:2574-2575` (`if not ok then end` in `EnsureDirectory`) — bodies (likely DPRINTF) stripped.
- **CORRECTION PLAN:** Delete the three empty blocks (+ the now-unused `err` capture at `:2573` if it falls out). Behavior unchanged.
- **RISK:** low. **IMPACT:** cosmetic, ~6 lines.

#### 4.10 — `DEBUG_INPUT_LOG` block gated by a hardcoded-false flag
- **WHAT:** `ui.lua:522` `DEBUG_INPUT_LOG=false`; the gated debug-pad dump at `:3549-~3575` (Timer + per-button reads + toast) never executes. Only other occurrence is the read at `:3549`.
- **CORRECTION PLAN:** Keep if you want a build-time input-debug switch (document it). Otherwise remove the block + flag + `UI.Pad.DebugPad*` fields.
- **RISK:** low. **IMPACT:** ~25 dormant lines; no perf impact (branch skipped). (Confidence: low — legitimate dormant debug aid.)

---

## (5) Better-Code Opportunities

> Refactors/correctness clarity; no behavior change unless noted.

#### 5.1 — Consolidate `lua_movefile`/`lua_rename`/`lua_copyfile` copy loop
- **WHAT:** `luasystem.cpp:713-795` — three bindings repeat the same open/read/write/close loop (`while ((size = read(source,buf,BUFSIZ)) > 0) write(dest,buf,size)` at `:728,:762,:787`). `lua_movefile` also calls `luaL_checkstring(L,1)` twice (`:715,:717`). None check `open()` returns.
- **PLAN:** Extract `static int copy_file_contents(const char *src, const char *dst)`; move variants then `remove(src)`. Drop the redundant first `luaL_checkstring`. (Note: `System.moveFile` itself is also a confirmed-removable dead duplicate of `System.rename` — see below.)
- **RISK:** low. **IMPACT:** ~24 duplicated lines + one redundant arg fetch.

> **Bonus confirmed removal (folds into 5.1):** `System.moveFile` (`lua_movefile`, `luasystem.cpp:713-738`, registered `:1464`) is byte-for-byte identical to `System.rename` (`:749-772`, registered `:1469`) and has ZERO Lua callers, while `System.rename` has 3 (`system.lua:2379,2503,2559`). Remove `lua_movefile` + its registration; keep `lua_rename`. **RISK:** low.

#### 5.2 — Unify the two `LoadIrxChecked` helpers
- **WHAT:** `main.cpp:393-410` (`LoadIrxChecked`, DPRINTFs) and `luasystem.cpp:264-279` (`LoadIrxCheckedBuffer`, silent) wrap `SifExecModuleBuffer` with identical `id<0||ret<0` logic.
- **PLAN:** Hoist one shared helper (`irx_util.cpp/.h` or `system.h`) with an optional verbose flag; both TUs call it.
- **RISK:** low. **IMPACT:** single source of truth for the IRX-load contract.

#### 5.3 — `main()` mixes checked IRX loads with unchecked `LOAD_IRX_NARG`
- **WHAT:** `main.cpp` checks `iomanX/fileXio/mmceman` (`LoadIrxChecked`, e.g. `:470`) but loads `mcman/mcserv/padman/libsd/usbd/audsrv` via `LOAD_IRX_NARG` (`:545-550`) and `ds34*` via `LOAD_IRX`, all unchecked.
- **PLAN:** Either route all boot-time loads through the shared checked helper (preferred) or add a comment documenting why those are intentionally non-fatal. Do not change boot order.
- **RISK:** low. **IMPACT:** consistency/robustness clarity.

#### 5.4 — `read_pad_all` helper for the 3-source pad read
- **WHAT:** `luacontrols.cpp:35-57,74-78,96-100,123-127,189-192` — five bindings repeat `padRead` + `ds34bt_get_data` + `ds34usb_get_data`.
- **PLAN:** Extract `static void read_pad_all(int port, padButtonStatus *out)`; the joystick/pressure/button bindings call it.
- **RISK:** low. **IMPACT:** consolidates input-merge logic.

#### 5.5 — `audsrv`/`adpcm` lazy-init guards duplicated 5×
- **WHAT:** `sound.cpp:75-83,85-99,101-114,116-127,189-199` repeat `if(!audsrv_started){audsrv_init();...}` (and 3× the adpcm guard).
- **PLAN:** Add `static void ensure_audsrv(void)` + `static void ensure_adpcm(void)`; replace inline guards.
- **RISK:** low. **IMPACT:** maintainability.

#### 5.6 — VRAM-alloc/upload/free tail duplicated across PNG/BMP/JPEG loaders
- **WHAT:** `graphics.cpp:229-256` (png), `591-629` (bmp), `742-783` (jpeg) repeat the alloc/CLUT/upload/free tail; `loadbmp` also repeats `if(tex->Mem){free;NULL}...` cleanup ~5× (`:472-475,501-504,534-537,548-551`).
- **PLAN:** Extract `static GSTEXTURE* finalize_texture(GSTEXTURE*)` and `static void free_texture_partial(GSTEXTURE*)`; call from all three.
- **RISK:** medium (loaders differ subtly in CLUT handling — refactor carefully). **IMPACT:** reduced leak-risk surface.

#### 5.7 — `HasSystemFn` helper for 39× repeated guard idiom
- **WHAT:** `if type(System)=="table" and type(System.<fn>)=="function" then` appears 39× (33 in `system.lua`, 5 in `ui.lua`, 1 in `boot.lua`). `System` is always a table (created in `luaSystem_init`), so the first half is effectively dead.
- **PLAN:** Add `local function HasSystemFn(name) return type(System)=="table" and type(System[name])=="function" end`; replace inline guards with `if HasSystemFn("ensureMmceman") then`.
- **RISK:** low. **IMPACT:** collapses 39 guards to one helper; reduces copy-paste typo risk.

#### 5.8 — `TIMER_MAGIC` constant for `0x4C544D52` ('LTMR') repeated 8×
- **WHAT:** `luatimer.cpp:24,35,50,64,78,91,103,114`.
- **PLAN:** `#define TIMER_MAGIC 0x4C544D52u /* 'LTMR' */`; replace literals. Optionally factor the magic-check into a helper.
- **RISK:** low. **IMPACT:** single source of truth.

#### 5.9 — Named constant for default gsKit color `0x80808080` (8×)
- **WHAT:** `luagraphics.cpp:67,170,214,298,319,341,363,386` each default `Color color = 0x80808080;`.
- **PLAN:** `static const Color GS_DEFAULT_COLOR = 0x80808080; /* neutral 50% white */`.
- **RISK:** low. **IMPACT:** readability.

#### 5.10 — `BMP_PALETTE_OFFSET` for hardcoded `54` (2×)
- **WHAT:** `graphics.cpp:371,406` `fseek(File, 54, SEEK_SET)` (= 14-byte file header + 40-byte info header).
- **PLAN:** `#define BMP_PALETTE_OFFSET 54` (or compute from the struct sizes).
- **RISK:** low. **IMPACT:** readability.

#### 5.11 — `lua_checkValidDisc` switch fall-through (latent bug, currently uncalled)
- **WHAT:** `luasystem.cpp:1149-1178` — `result = 1` cases lack `break` and fall straight into the `result = 0` group, so the function always returns 0. Masked today because `System.checkValidDisc`/`getDiscType`/`checkDiscTray` have zero Lua callers (see §below).
- **PLAN:** Add `break;` after each result group. Verify against disc hardware before relying on it. (Lower priority — dead today, but the fix is unambiguous.)
- **RISK:** low. **IMPACT:** latent correctness; no behavior change today.

> **Related confirmed removals (low-priority API trim):** Several `System.*` bindings have zero Lua callers — `getMCInfo` (`:865`), `checkValidDisc` (`:1149`), `getDiscType` (`:1193`), `checkDiscTray` (`:1180`), `getFreeMemory` (`:833` → `GetFreeSize` `system.cpp:213`), `findBDMByDriver` (`:400`), `threadCopyFile` (`:1252`). Also unused: the `Pads` stick/pressure/type bindings (`getLeftStick`/`getRightStick`/`getPressure`/`getType`, `luacontrols.cpp`) and the gsFont family `Font.load`/`print`/`unload`/`ftLoad`/`ftUnload`/`ftEnd`/`ftSetPixelSize`/`fmUnload` (`luagraphics.cpp`) + their C backers `loadFont`/`printFontText`/`unloadFont`. The Screen API `getFPS`/`getFreeVRAM`/`getMode` (`luaScreen.cpp:44-60,82-134`) → `FPSCounter`/`getFreeVRAM` are likewise unused. **All are API-surface attrition, not broken code** — proven unused in-tree, but possibly callable by external/add-on `.lua` (none in repo). Keep if preserving the Enceladus API; trim only when minimizing binding surface. **Do NOT** remove the ds34* handling inside `lua_getpad`, `loadFontM`/`printFontMText` (`fmLoad`/`fmPrint` used at `boot.lua:162-163`), or `Screen.clear`/`flip`/`setMode`.

#### 5.12 — `MENU_ITEM_HEIGHT` undefined in `__RTL` branch (latent compile break)
- **WHAT:** `fntsys.cpp:790` (`#else`/`__RTL` path) uses `y += rmScaleY(MENU_ITEM_HEIGHT);` but `MENU_ITEM_HEIGHT` is defined nowhere (repo-wide grep = only this line). The active branch hardcodes `19` (`:664`).
- **PLAN:** `#define FNTSYS_LINE_ADVANCE 19`; use in both branches so the `__RTL` build compiles and both paths agree.
- **RISK:** low. **IMPACT:** latent compile break under `__RTL` fixed + removes magic 19; no default-build change.

#### 5.13 — `waitPadReady` DISCONN/timeout guard inconsistency
- **WHAT:** `pad.cpp:23` waits with no DISCONN/counter, while `isButtonPressed` (`:153`) DOES include `&& (ret != PAD_STATE_DISCONN)`. (Same root cause as §4.1.)
- **PLAN:** Add DISCONN check + bounded retry; return a failure status; callers react. Verify timeout on hardware. (Maintainer task #17.)
- **RISK:** medium (pad-init timing). **IMPACT:** robustness.

#### 5.14 — FreeType render state in file-scope globals
- **WHAT:** `fntsys.cpp:91-96` holds `quad/codepoint/state/glyph/use_kerning/glyph_index/previous/delta` as file-scope mutable globals used by `fntRenderString`, while `fntCalcDimensions` (`:887`) shadows them with its own locals (`:895-899`) — hinting the globals are vestigial.
- **PLAN:** Move them into `fntRenderString` as locals (mirroring `fntCalcDimensions`). Inherited OPL code — verify rendering unchanged. Scoping only, no removal.
- **RISK:** medium (touched by the RTL variant too). **IMPACT:** reentrancy/maintainability.

#### 5.15 — Non-static global `max()`/`min()` collide with `MAX` macro
- **WHAT:** `fntsys.cpp:113-122` defines external-linkage `int max/min`; `luaplayer.h:40` separately defines `MAX(a,b)`. Lowercase external `max`/`min` risk clashes with `<algorithm>`/`MAX`. (Overlaps §2.7 which removes the unused `max` entirely.)
- **PLAN:** Mark `max`/`min` `static` (used only in this file) or replace with the `MAX` macro / a local `MIN`.
- **RISK:** low. **IMPACT:** removes external-linkage namespace pollution.

#### 5.16 — Document (don't remove) the UI metatable write-guards
- **WHAT:** `ui.lua:3766-3811` `__newindex` guards silently drop writes to `UI.MainMenu.OPT` (unless `Carousel.allowOptWrite`) and `UI.CURSCENE` (unless `Transition.allowSceneWrite`). A normal-looking assignment elsewhere no-ops with no error/log — a known footgun (per project memory `project-launch-args`).
- **PLAN:** **Do NOT remove** (intentional guard). Optionally, in DEBUG builds emit a `dprintf` when a guarded write is dropped, so the footgun surfaces in development without changing release behavior.
- **RISK:** low. **IMPACT:** debuggability; release behavior unchanged.

---

## Do NOT Remove — Verified Still Used (refuted by adversarial pass)

These look removable but were proven live or contractually protected. Documenting them prevents a future "this is dead, delete it" mistake.

#### N.1 — Public PLDR/global wrappers: `GetBootKind`, `EnsureTrailingSlashNorm`, `Touch`
- **VERDICT:** NOT safe to remove. `PLDR.GetBootKind` (`system.lua:1894`) has **zero code callers but is a DOCUMENTED public API** — `docs/LAUNCH_HYGIENE.md:150-151` ("`PLDR.GetBootContext()` / `PLDR.GetBootKind()` are public APIs for any downstream consumer"), recorded in `DECISIONS.md:107` and `STATE.md:31`. Removing it violates a documented contract. (`Touch` `:5206` and `EnsureTrailingSlashNorm` `:2619` — distinct from the heavily-used `EnsureTrailingSlashNormRaw` — have weaker justification; a narrower claim limited to those two would be defensible, but the bundled claim including the documented `GetBootKind` is not.)
- **SAVED BY:** `docs/LAUNCH_HYGIENE.md:150`, `DECISIONS.md:107`.

#### N.2 — HDD game-list cache (`USECACHE`/`HDDCACHE`/`CreateCache`/`ReadCache`/`WipeCache`)
- **VERDICT:** NOT safe to remove. The code is genuinely inert (`USECACHE` defaults false at `system.lua:1937`, never set true; `ReadCache`/`WipeCache` uncalled; the `:3998` read branch never fires) — but this is **in-progress planned work**: maintainer task #12 ("Perf: cache/index game lists for fast HDD APA scans"). The removal plan itself says "Do NOT remove silently if the cache work is still planned."
- **CORRECT DISPOSITION:** Document-as-disabled, or finish wiring it (set `USECACHE` true, call `ReadCache` on load + `WipeCache` on refresh). **SAVED BY:** maintainer task #12 / project roadmap.

#### N.3 — Device-lock subsystem (`setDeviceLock`/`canEnterDevice`/`OpenDeviceLock`/`boot_locks`)
- **VERDICT:** NOT safe to remove as a bundle. The *enforcement* is inert (`setDeviceLock` body is `return target`, no field write; `boot_locks` never read; `canEnterDevice`/`OpenDeviceLock` uncalled), BUT **`setDeviceLock` IS invoked at 3 live hardware-conditional sites the dead-code framing omits**: `ui.lua:3319` (`DEVLOCK.MMCE`, OPT==1), `:3342` (`DEVLOCK.MX4SIO`, OPT==2), `:3422` (`DEVLOCK.USB`, OPT==5). Deleting the `setDeviceLock` definition without removing those callers = `attempt to call a nil value` crash on device-list open. `canEnterDevice`/`OpenDeviceLock`/`boot_locks` ARE individually dead (see §2.11) — but the *whole-subsystem* removal as worded is unsafe.
- **CORRECT DISPOSITION:** Maintainer decision — implement enforcement OR remove with call-site cleanup. Keep `DEVLOCK` enum + `device_lock_name` + `boot_device` (used for labeling at `ui.lua:3220-3221`). **SAVED BY:** the 3 `UI.setDeviceLock(...)` call sites. **Revised risk: medium.**

#### N.4 — DS3/DS4 USB+BT pad emulation (`-lds34bt`/`-lds34usb` + `modules/ds34*`)
- **VERDICT:** NOT safe to remove without maintainer sign-off + hardware test. This is **LIVE every-boot code**, not dead — `main.cpp:557-561` unconditionally loads+inits both modules, and `Pads.get()` (`ui.lua:3476`, the UI's only input source → `lua_getpad`) ORs in DS34 data gated on `ds34*_get_status & STATE_RUNNING`. It sits on a **hardware-conditional path**: a user with a DS3/DS4 adapter would lose all controller input if removed. Source analysis cannot prove no such user exists — exactly the "hardware is the only truth" category.
- **CORRECT DISPOSITION:** Decision required. If confirmed native-pad-only, removal is mechanically clean (would compile; native pads survive) but discards a working feature — rebuild + hardware-test pad input first. **SAVED BY:** `main.cpp:557-561` + `ui.lua:3476` live path + hardware-conditional usage. **Revised risk: medium.**

---

### Notes on cross-references
- §1.1 (3D pipeline removal) **subsumes** §2.3 and §2.4 — if the whole subsystem goes, those isolated functions go with it.
- §4.1 and §5.13 are the same `waitPadReady` issue from optimization vs. consistency angles.
- §2.7 and §5.15 overlap on `fntsys.cpp` `max()` — §2.7 removes the unused `max` outright; §5.15 addresses the `min`/`MAX`-macro collision if `max` is kept.
- §5.1's `copy_file_contents` extraction pairs with the confirmed `System.moveFile` dead-duplicate removal.

All file:line references above are at branch tip 0e51ece. Every "Recommended" item carries an adversarial `safe_to_remove=true` verdict; "Do NOT remove" items carry `safe_to_remove=false` with the saving reference cited inline.
