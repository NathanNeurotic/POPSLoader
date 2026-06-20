Last updated: 2026-06-20 (BETA-12 released; HEAD = BETA-12-PLAY @ 2859c60). Since the prior post-BETA-11 update: dead md5/3D-render pipeline and SMB/strUtils helpers removed; four new game-list settings keys added (SHOW_DETAILS, DETAILS_ALIGN, GAMELIST_CACHE, DESC_SCROLL_SPEED) bringing EncodeSettings to 18 keys; opt-in cross-boot game-list cache re-enabled. For current Settings behavior, Known Issues, Preservation Contracts, Behavioral Invariants, and Hardware Status, see **`STATE.md`** (canonical) — this doc points there instead of restating them.

# COMPONENTS

## Purpose
Current technical map of POPSLoader source files, their responsibility, and key
entry points. POPSLoader is a PS1-game launcher built on the Enceladus runtime:
EE C/C++, an embedded Lua application (`bin/POPSLDR/*.lua` compiled into the EE
ELF via bin2c), embedded IOP IRX modules, and a BRAM child ELF-loader. Every
technical claim below cites `path:line` against this worktree.

> Scope note: this file documents what is actually present and wired in the
> shipped BETA-12-PLAY state. Where a component is on disk but unused (dead or
> dormant), that is called out explicitly rather than omitted. Several files an
> external audit flagged for removal — the 3D render pipeline (commit a56441c),
> `md5`, and the orphaned SMB / `strUtils` source (commit f83dbbb) — have since
> been removed from the tree and are documented as removed below. (The SMB
> main-menu entry remains as an unimplemented stub.)

## 1. EE bootstrap and runtime (`src/`)

### `src/main.cpp` — EE entry, pre-main IOP hygiene, IRX bring-up
- `_ps2sdk_memory_init()` (main.cpp:619) runs BEFORE `main()` inside newlib's
  memory-init hook. Gated on `-DRESET_IOP` (set in Makefile:34, applied
  Makefile:59-61). It performs `SifExitRpc -> SifInitRpc(0) -> fileXioExit ->
  while(!SifIopReset) -> while(!SifIopSync) -> SifInitRpc(0)` (main.cpp:658-663)
  to recover from "polluted parent" launchers (wLaunchELF off non-HDD devices)
  whose live fileXio modules would otherwise hang a plain `SifIopReset`
  (ps2sdk #425). Anyone reading `main()` top-down will miss this reset.
- `detectBootDeviceHintFromArgv0()` (main.cpp:134) derives an advisory pre-Lua
  boot-device hint from `argv[0]`. HDD variants `hdd/pfs/ata/apa` all map to
  `"HDD"` (main.cpp:155-160); both `mass` and `usb` map to `"USB"`
  (main.cpp:139-144) — the MX4SIO-vs-USB disambiguation happens later in Lua.
- `parseLaunchArgs()` (main.cpp:198) parses NHDDL-style args: `-page=`/`-mode=`
  (`-mode` is a pure alias, both write `launch_arg_page`, main.cpp:220-226),
  `-game=`, `-debug`.
- `main()` (main.cpp:439) parses launch args, installs SBV patches, then loads
  the embedded IRX stack via `SifExecModuleBuffer` (LOAD_IRX/LoadIrxChecked
  wrappers, main.cpp:388-410). Boot IRX order is fixed and partly conditional:
  iomanX (main.cpp:470) -> fileXio + fileXioInit (main.cpp:475-477, gated on
  iomanX) -> sio2man (main.cpp:488) -> mmceman ONLY if hint == MMCE
  (main.cpp:504-538; LoadIrxChecked call at main.cpp:507) -> mcman/mcserv
  (main.cpp:545-546) -> initMC (main.cpp:547) -> padman (main.cpp:548) -> libsd
  (main.cpp:550) -> usbd (main.cpp:554) -> ds34usb/ds34bt (main.cpp:558-559) ->
  audsrv (main.cpp:563).
  Device-specific stacks (BDM/usbmass/mx4sio/cdfs/HDD) are NOT loaded here; they
  are lazy-loaded on demand from `luasystem.cpp` / `luaHDD.cpp`.
- After IRX bring-up `main()` sets boot path/app dir, inits gsKit + pad, then
  enters a loop running embedded `boot.lua` via `runScript`.

### `src/luaplayer.cpp` — Lua VM lifecycle and embedded asset wiring
- `g_embedded_lua_assets` (luaplayer.cpp:35-41) is the embedded script table:
  `boot.lua`, `system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`.
- `runScript()` (luaplayer.cpp:254) creates the Lua state, installs the embedded
  searcher (`InstallEmbeddedLuaSearcher`, luaplayer.cpp:272), disables on-disk
  script loaders (`DisableLuaFilesystemScriptLoaders`, luaplayer.cpp:273 — nils
  `dofile`/`loadfile`, clears `package.path`/`cpath`), registers all Lua module
  bindings (luaplayer.cpp:282-288), then loads the requested embedded script
  buffer. A missing embedded asset is a hard FATAL, not a disk fallback
  (luaplayer.cpp:294-302).
- Registered binding modules (luaplayer.cpp:282-288): `luaGraphics_init`,
  `luaControls_init`, `luaScreen_init`, `luaTimer_init`, `luaSystem_init`,
  `luaSound_init`, `luaHDD_init`. NOTE: `luaSMB_init` is NOT
  called here (see Orphaned/dormant code below).

### `src/luasystem.cpp` — the largest binding surface (System.*)
- Lazy IRX loaders (Layer C): `EnsureBDM`/`EnsureBDMFatFs`/`EnsureUsbMass`
  chain (luasystem.cpp:80-120), `EnsureMmceman` (luasystem.cpp:141).
- Mass-backend classification: `FetchBdmList`/`ClassifyMassBackend`
  (luasystem.cpp:184-217), driver-name lookup `GetMassMountDriverNameBySlot`
  (luasystem.cpp:312).
- MX4SIO init enforces USB mass first: `lua_mx4sio_init` (luasystem.cpp:1298)
  calls `EnsureUsbMass()` (luasystem.cpp:1316) before loading `mx4sio_bd.irx`
  (luasystem.cpp:1318).
- External-ELF launch bindings: `lua_loadELF` (luasystem.cpp:974),
  `lua_loadELFWithPartition` (luasystem.cpp:1020, requires `reboot_iop != 0` and
  an `hdd?:PART:` partition context, luasystem.cpp:1033-1037),
  `lua_loadELFRebootIOP` (luasystem.cpp:1068). Keep-PFS mask binding
  `lua_set_exec_keep_pfs_mask` (luasystem.cpp:945).
- Launch-arg binding `lua_getLaunchArgs` (luasystem.cpp:1211) and boot-hint
  binding `lua_getBootDeviceHint` (luasystem.cpp:1227).
- `lua_rename` (luasystem.cpp:753) is a non-atomic copy+delete, but the
  safe-promote fix has **landed in this worktree**: it calls the shared
  `copy_file_contents` (luasystem.cpp:714) and **only `remove()`s the source if
  the copy returned 0** (luasystem.cpp:760-762). `copy_file_contents` returns -1
  on an open/short-write/mid-stream-read error, so a failed copy no longer
  deletes the source. (There is no longer a separate `lua_movefile`; only
  `lua_rename` is registered, luasystem.cpp:1330. `copyFile` is historical — the
  comment at luasystem.cpp:713 notes the shared helper was "historically used by
  copyFile".) Not on the launch path.

### `src/luaHDD.cpp` — HDD (dev9) IRX stack and PFS mounting
- `Load_HDD_IRX` (luaHDD.cpp:120, exposed as `HDD.Initialize` at luaHDD.cpp:173)
  loads ps2dev9 -> ps2atad -> ps2hdd-osd -> ps2fs back-to-back (luaHDD.cpp:142-161),
  with HDD args `-o 4 -n 20` and PFS args `-m 4 -o 10 -n 40` (luaHDD.cpp:136-139).
  This BETA-12-PLAY state has NO inter-module cold-dev9 settle delay here.
- `GetHDDStatus` via `HDIOC_STATUS` (luaHDD.cpp:93-96); on-demand mount
  `MountPart`/`mnt` (luaHDD.cpp:21-92) producing `pfs%d:/` mount points.

### `src/embed_assets.cpp` — runtime name -> embedded blob resolver
- `embedded_get()` (embed_assets.cpp:225) normalizes paths (strips `embed:/`,
  `./`, leading `/`, embed_assets.cpp:234-244) and resolves against the static
  `g_embedded_assets` table (embed_assets.cpp:107-204). `default.png` is an
  optional embed gated on `HAVE_ASSET_DEFAULT_PNG`, falling back to `MISSING.png`.

### Other EE runtime files
- `src/graphics.cpp` / `src/luagraphics.cpp` — gsKit 2D drawing + `Graphics.*`
  Lua bindings (`luaGraphics_init`, luagraphics.cpp). Image load/draw, the
  `Graphics.loadImageEmbedded` path used by `images.lua`.
- `src/fntsys.cpp` / `src/atlas.cpp` — TrueType font system and glyph atlas.
- `src/luaScreen.cpp` (`luaScreen_init`) — `Screen.*` flip/clear bindings.
- `src/luacontrols.cpp` (`luaControls_init`) — `Controls.*` pad input.
- `src/pad.cpp` — low-level pad init/read.
- `src/sound.cpp` / `src/luasound.cpp` (`luaSound_init`) — audsrv-backed audio.
- `src/luatimer.cpp` (`luaTimer_init`) — `Timer.*` bindings.
- `src/system.cpp` — small EE system helpers.

### 3D rendering pipeline (removed)
The legacy 3D render pipeline (src/render.cpp, src/calc_3d.cpp,
src/gsKit3d_sup.cpp, src/luaRender.cpp and the Render/Lights/Camera Lua
bindings, plus the -lmath3d link) was dead at the application level and has been
removed from the tree (commit a56441c). These files are no longer on disk, no
longer in the Makefile object lists, and luaRender_init is no longer called
from luaplayer.cpp.

### Orphaned / dead-on-disk
- `src/luaSMB.cpp` (SMB network-share client logon helpers) was orphan source —
  never in the Makefile object lists and never initialized (`luaSMB_init` was
  uncalled) — and was DELETED in commit f83dbbb (2026-06-13). It no longer
  exists in the tree. The SMB (v1) main-menu entry remains as an unimplemented
  stub (OPT7, ui.lua:4320) — see Feature Surface.

## 2. Embedded Lua application (`bin/POPSLDR/`)
All `bin/POPSLDR/*.lua` are bin2c'd into the EE ELF at build time; the on-card
copies are not read at runtime. Editing them requires a rebuild.

### `bin/POPSLDR/system.lua` — controller, device/launch engine, settings
- Owns device resolution, settings persistence, game-list building, the HDD
  cache, and the launch engine. `require`s pops_profiles/ui/images
  (system.lua:2383, 2476).
- Boot-device classification: `ResolveBootContext` (system.lua:1819) /
  `DetectBootDevice` (system.lua:1953), prefix rules under `ResolveBootContext`.
  `mass:/` is disambiguated via the BDM driver name (`classify_mass_boot`,
  system.lua:1836; `sdc`/`mx4` => MX4SIO).
- Launch-arg ingest: `NormalizeLaunchPage` (system.lua:2154), `PLDR.LAUNCH_ARGS`
  (system.lua:2199), carousel page auto-nav `page_to_opt` (system.lua:2431;
  maps MMCE/MX4SIO/HDD/USB/SMB only).
- Settings: `EncodeSettings` (system.lua:3013, **18 keys**: PROFILE,
  POPSTARTER_PATH, POPSTARTER_MODE, BDMA, DKWDRV_PATH, STRICT_HDD_PREEXEC_GATE,
  VIDEO_STANDARD, HIDE_TEXT, KEYBOARD_LAYOUT, BOOT_PAGE, MULTIDISC_COLLAPSE,
  GLOBAL_HIDE, POPSTARTER_MC_FOLDER, HIDDEN_DEVICES, SHOW_DETAILS, DETAILS_ALIGN,
  GAMELIST_CACHE, DESC_SCROLL_SPEED), `LoadSettingsNonFatal` (system.lua:3235),
  `SaveSettingsAtomic` (system.lua:3196) -> `WriteAtomic` (system.lua:2604),
  `CommitSettingsChanges` (transactional, system.lua:3461). Per-device sidecar
  `.pldrs` at APP_DIR for every device; **HDD installs now persist on the HDD
  boot partition** via the `PLDR.HDD.EnsureBootPartitionWritable` RW mount
  take-over (system.lua:2125) — no `mc0:` carve-out. `mc0:/POPSTARTER/.pldrs`
  remains only a legacy fallback. See `STATE.md > Settings (single-device parity)`.
- Game-list builders: `GetPS1GameLists` (system.lua:4444, MMCE/MX4SIO, bare
  basenames), `BuildMassGameListByType` (system.lua:4508, USB, `root|name`),
  `HDD.BuildGameList` (system.lua:4635, `partition|relpath`). HDD cache
  (`CreateCache` system.lua:4795 / `ReadCache` system.lua:4842) is gated on the
  `PLDR.GAMELIST_CACHE` setting (opt-in, default OFF; system.lua:3253).
  `USECACHE` (system.lua:2018) is a dead legacy flag. The same `GAMELIST_CACHE`
  gate covers the USB/MMCE/MX4SIO list cache (`SaveGameListCache`
  system.lua:4731 / `ReadGameListCache` system.lua:4750).
- Launch engine: `LaunchEngine` (system.lua:5351), `RunPOPStarterGame`
  (system.lua:5568), `BuildPopstarterLaunchCommand` (system.lua:5546, sets
  per-device `reboot_iop`). HDD pre-exec gate `ValidateHddPopstarterExecGate`
  (system.lua:1625). Keep-PFS-mask prep `PrepareForExternalELFLaunch`
  (system.lua:1090).
- Startup ordering at module end: `LoadSettingsNonFatal` ->
  `AutoInitStartupBackends` (system.lua:3835) -> `SurfaceLaunchArgsDebug` ->
  `AutoLaunchFromLaunchArgs` (system.lua:6054), then the single render loop
  (system.lua:6279-6291; dispatch body 6280-6290 per-scene `Play()` + `UI.flip()`).

### `bin/POPSLDR/ui.lua` — the entire UI table, no main loop
- Defines one `UI` table literal (ui.lua:446) and `return UI` (ui.lua:4825).
  Contains all scenes, the scene/transition state machine, notification queue,
  busy overlay, cover-art cache, path-editor keyboard, modals, and input layer.
  It has NO main loop — the loop lives at the bottom of system.lua.
- Scenes enum `UI.SCENES` (ui.lua:448-458): GUSBFAT=1, GSMB=3 (reused for MMCE
  and SMB), GMX4SIO=4, GHDD=5 (GAPAHDD aliases 5), GBDMHDD=6, MMAIN=8,
  MPROFILE=9, CREDITS=10.
- Main menu carousel `UI.MainMenu` (table ui.lua:3898, opts ui.lua:3900; the
  CONFIRM/Play dispatch lives in the MainMenu Play handler from ~3898 onward).
  Game list `UI.GameList` (table ui.lua:2319), launch trigger
  `LaunchSelectedGame` (ui.lua:2747). Settings page `UI.ProfileQuery.Play`
  (ui.lua:2940). DKWDRV/BOOT.ELF/exit handoffs `OpenDKWDRV` (ui.lua:1370),
  `LaunchBootElf` (ui.lua:1591), `ConfirmExit`.
- Cover-art LRU `CoverCache` (ui.lua:257-343), candidate builder
  `BuildCoverCandidates` (ui.lua:175): non-HDD = `base.png` beside the VCD,
  HDD = `hdd0:__common/POPS/ART/<basename>.png`.
- WRITE-GUARD GOTCHA: `__newindex` metatables on `UI.MainMenu` and `UI`
  (ui.lua:4791 & 4813) silently DROP writes to `UI.MainMenu.OPT` (unless
  `Carousel.allowOptWrite`) and `UI.CURSCENE` (unless
  `Transition.allowSceneWrite`). Build-info display reads `BUILD_INFO.txt`
  (`LoadBuildInfo`, ui.lua:4521).

### `bin/POPSLDR/pops_profiles.lua` — POPSTARTER.ELF location list
- `PLDR.PROFILES` (pops_profiles.lua:26-91) is a 16-entry ordered list of
  `{ELF=path, DESC=text}` POPSTARTER.ELF *locations* (not per-game configs).
  `DEFAULT_PROFILE = 1` seeds `PLDR.POPSTARTER_PATH` (pops_profiles.lua:8,
  93-94). The orthogonal PROFILE_DEFAULT vs CUSTOM mode (system.lua:667-712)
  decides whether the profile ELF or a typed override wins.

### `bin/POPSLDR/images.lua` — embedded UI glyph/chrome atlas
- `IMG_REGISTRATIONS` (images.lua:11-36): 24 `{key, filename}` pairs (device
  icons, backgrounds, splash layers, button/d-pad glyphs, plus `missing` and
  `default`). Lazy `IMG` metatable (`__index`, images.lua:52) loads each PNG
  from an embedded blob via `System.getEmbeddedAsset` ->
  `Graphics.loadImageEmbedded` and caches it; only fallback is
  `default -> missing` (`IMG_FALLBACKS`, images.lua:45-47). This is UI chrome,
  NOT per-game box art (game covers are `UI.CoverCache` in ui.lua).

## 3. Boot script (`etc/`)
- `etc/boot.lua` (HDD-boot branch etc/boot.lua:37) mounts the HDD boot partition
  to `pfs1:` (warning "NEVER USE IT FOR ANYTHING ELSE", boot.lua:48), normalizes
  cwd to `pfs1:` (boot.lua:63-64), loads fonts, then `require("system")`
  (boot.lua:181). `System.sleep(2)` (boot.lua:47) is SECONDS, not ms (the binding
  calls C `sleep`, luasystem.cpp:774-780), so it is a full 2-second HDD settle.
  CI requires this file end with a `0x0A` newline.
- `etc/update_lua_globals.sh` — dev helper for syncing Lua globals.

## 4. External ELF-handoff layer (`src/elf_loader/`)
- `src/elf_loader/src/elf.c` — the EE-side parent loader. Central reboot/HDD
  routing fork `LoadELFFromFileExecPS2RebootIOPWithPartition` (elf.c:618): HDD
  partition AND filename both HDD-backed -> `ExecuteHddBackedViaEmbeddedLoader`
  (elf.c:648); resolved-path/partition HDD-backed -> same (elf.c:656); else
  direct `SifLoadElf` (elf.c:661) -> unmount-pfs (keep-mask) -> SifIopReset ->
  reload rom0:SIO2MAN/MCMAN/MCSERV -> ExecPS2. BOOT.ELF and DKWDRV-HDD
  special-cases in `LoadELFFromFileWithPartition` (elf.c:481, BOOT.ELF mc-case
  elf.c:499, DKWDRV elf.c:505/519). `ExecuteViaEmbeddedLoader` (elf.c:397) writes
  BRAM metadata (magic `POPL`, addr `0x00083C00`; defines elf.c:159-160) and
  `ExecPS2`s the child.
- `src/elf_loader/src/loader/src/loader.c` — the BRAM child loader. `main()`
  (loader.c:280) reads metadata at `0x00083C00` (loader.c:144-145) and branches
  three ways before `ExecPS2`: filexio-direct (loader.c:373-379); the
  HDD-partition-context branch for D-10 (loader.c:381-403 — unmounts the pfs
  prefix, then `SifExitRpc` + `SifExitCmd` at loader.c:396-397); and the
  generic/empty-context branch for BOOT.ELF/DKWDRV (loader.c:404-427 —
  `SifExitRpc` only at loader.c:404, INTENTIONALLY omits `SifExitCmd`, comment
  loader.c:405; the comment marks that omission as the historical D-15-pass vs
  D-10-fail difference). Do not add `SifExitCmd` to the generic branch.
- `src/elf_loader/loader.c` — committed ~6.5 MB bin2c blob of the built
  `loader.elf` (symbol `loader_elf`), regenerated by `make elfloader`.
- `src/elf_loader/Makefile` / `src/elf_loader/src/loader/Makefile` — the nested
  two-stage loader build (stage 1 builds `loader.elf` into BIOS memory; stage 2
  bin2c-embeds it and archives `libcustom-elf-loader.a`).

## 5. IOP modules (`iop/`)
- `iop/bdm_query/bdm_query.c` — in-tree IOP RPC helper (id `0xB0D10B00` defined
  bdm_query.c:11, registered bdm_query.c:76; handler bdm_query.c:36) enumerating
  live block devices via `bdm_get_bd()`; the EE side
  classifies each backend by driver-name substring. Built from source
  (Makefile:241-245).
- `iop/embed/` — pinned/in-tree IRX blobs bin2c'd into the ELF: `bdm.irx`,
  `bdmfs_fatfs.irx`, `bdmfs_vfat.irx`, `mx4sio_bd.irx`
  (+`mx4sio_bd_mini.irx`), plus the `PS2SDK_MX4SIO` and `BDMASSAULT_MX4SIO`
  source pins. The active `mx4sio_bd.irx` is pinned from
  `iop/embed/PS2SDK_MX4SIO` (Makefile:247-251). Other IRX (iomanX, fileXio,
  sio2man, mcman, mcserv, padman, libsd, usbd, audsrv, usbmass_bd, cdfs,
  ps2dev9, ps2atad, ps2hdd-osd, ps2fs, mmceman) resolve from `$(PS2SDK)/iop/irx/`
  (vpath Makefile:216, object list Makefile:88-93).

## 6. Controller modules (`modules/`)
- `modules/ds34usb/` and `modules/ds34bt/` — DS3/DS4 USB and Bluetooth support,
  built as EE static libs (`EXT_LIBS`, Makefile:72) and as IRX
  (`ds34usb.o`/`ds34bt.o`, Makefile:85).
- `modules/pademu/` — pad-emulation IOP module sources (ds34bt/ds34usb/pademu).
- `modules/Rules.bin.make` — shared module build rules.

## 7. On-card payload (`bin/POPSLDR/`, non-source)
- `POPSTARTER.ELF` (the PS1 emulator front-end launched per game), `PATCH_5.BIN`,
  `boot.adp`, `APPINFO.PBT`, `title.cfg`, MC icon set
  (`icon.sys`/`list.icn`/`copy.icn`/`del.icn` plus `.bdma` variants), the `IMG/`
  source PNGs, and device-variant IRX
  (`usbd.irx.{usbexfat,mx4sio,mmce}`, `usbhdfsd.irx.{usbexfat,mx4sio,mmce}`).

## 8. Build / package / CI
- `Makefile` — builds the EE ELF, bin2c-embeds all Lua/PNG/IRX assets
  (`BIN2S = $(PS2SDK)/bin/bin2c`, Makefile:67; `EMBEDDED_RSC` Makefile:95-104),
  links the child-loader lib, strips, and runs `ps2-packer` to produce
  `bin/POPSLOADER.ELF` (Makefile:117-119). `make elfloader` (Makefile:254-259)
  force-regenerates the child loader. `RESET_IOP = 1` (Makefile:34) compiles in
  the pre-main IOP reset. NOTE: the bin2c rules, the `EMBEDDED_RSC` object list,
  and `embed_assets.cpp`'s table must be kept in sync MANUALLY — there is no
  machine-checked embed manifest.
- `.github/workflows/compilation.yml` — CI on all branches/tags/PRs/dispatch:
  runs the now-LIVE embedded-Lua **syntax** gate (`apk add lua5.4` + `luac5.4 -p`
  on `bin/POPSLDR/*.lua` + `etc/boot.lua`, hard-fail on syntax error — it used to
  silently no-op because the pinned ps2dev image had no `luac`; catches SYNTAX
  only, so runtime nil-global / type / load-order errors stay invisible),
  generates `BUILD_INFO.txt`, runs `make clean elfloader all`, enforces
  embed-identity gates (three string markers in the ELF + loader.c parity), and
  packages `POPSLOADER.zip` as an artifact (no GitHub release).
  See `STATE.md > CI / release`.
- `.github/workflows/rolling-release.yml` — on push to BETA-12-PLAY and PR
  events: bundles the ELF + full git-tracked source and force-updates the
  `rolling-release` prerelease via the GitHub API.
- `.github/workflows/opencode.yml` — `/oc` comment bot (DeepSeek). Not part of
  release packaging or runtime behavior.

## Current Feature Surface by Main Menu Option
Dispatch in the MainMenu Play handler from ~ui.lua:3898 onward.
- `MMCE` (OPT1): implemented.
- `MX4SIO` (OPT2): implemented.
- `HDD (PFS)` (OPT4): implemented (routes to scene GHDD=5).
- `USB` (OPT5): implemented.
- `Disc (DKWDRV)` (OPT8): implemented.
- `HDD (exFAT)` (OPT3): NOT implemented — surfaces "isn't implemented yet"
  (toast at ui.lua:2369).
- `i.Link` (OPT6): NOT implemented (ui.lua:4318).
- `SMB (v1)` (OPT7): NOT implemented (ui.lua:4320). There is no SMB C client;
  the former `src/luaSMB.cpp` orphan was removed in commit f83dbbb (see
  Orphaned/dead-on-disk).

## Preservation Contracts (hardware-load-bearing — do not regress)
- D-10 (HDD POPSTARTER + HDD game): the BRAM child-loader route via the
  HDD-partition-context branch (loader.c:381-403, SifExitRpc+SifExitCmd at
  396-397) — unmount the pfs prefix, then `SifExitRpc` + `SifExitCmd`. (The
  generic branch loader.c:404-427, which omits `SifExitCmd`, is the
  BOOT.ELF/DKWDRV path, not D-10.)
- D-15 (non-HDD POPSTARTER + HDD game): keep-PFS mask preserves the boot
  partition's `pfs1:` slot (elf.c keep-mask, system.lua:1090).
- DKWDRV from HDD inherits the same embedded-loader path as POPSTARTER
  (elf.c:628-644); the V3 direct-reset route black-screened on hardware.
- BRAM metadata struct (`partition_context[128]`, `load_path[256]`, magic `POPL`)
  must stay byte-identical between writer (elf.c) and reader (loader.c).
- Settings sidecar (single-device parity): USB/MC/MMCE/MX4SIO **and HDD** all use
  the per-device `.pldrs` sidecar. HDD installs persist on the HDD boot partition
  via the `PLDR.HDD.EnsureBootPartitionWritable` RW mount take-over
  (system.lua:2125) — there is **no** `mc0:` HDD carve-out. That take-over is now
  load-bearing for HDD settings save and HDD in-app `.hide`; don't regress it.
  (Supersedes the old HDD-to-MC exception.) See `STATE.md > Preservation Contracts`
  and `STATE.md > Settings (single-device parity)`.

> Divergence note (per project memory): this BETA-12-PLAY worktree's
> `PLDR.LoadHDDModules` (system.lua:4669) and `Load_HDD_IRX` (luaHDD.cpp:120) have
> NO cold-dev9 settle between HDD IRX loads. The "fail to load HDD" cold-dev9
> settle fix lives on a separate rolling branch and is NOT merged here.

## Primary Change Entry Points
- Settings persistence/apply: `bin/POPSLDR/system.lua`, `bin/POPSLDR/ui.lua`.
- Device detection/classification: `bin/POPSLDR/system.lua`, `src/luasystem.cpp`,
  `iop/bdm_query/bdm_query.c`.
- Launch handoff/argv/path: `bin/POPSLDR/system.lua`, `src/luasystem.cpp`,
  `src/elf_loader/src/elf.c`, `src/elf_loader/src/loader/src/loader.c`.
- HDD bring-up/mount: `src/luaHDD.cpp`, `bin/POPSLDR/system.lua`.
- Embedded asset add/resolve: `Makefile` (bin2c rule + `EMBEDDED_RSC`),
  `src/embed_assets.cpp`, plus the consuming Lua table.
- Packaging/release: `Makefile`, `.github/workflows/compilation.yml`,
  `.github/workflows/rolling-release.yml`.
