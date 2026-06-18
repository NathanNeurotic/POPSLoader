Last updated: 2026-06-17 (post-BETA-11; HDD-RW take-over + PAL-512 + BDMA-folder + `bdma_mode.txt` rename + `d4b04be` load-order boot fix). For current Settings behavior, Known Issues, Preservation Contracts, Behavioral Invariants, and Hardware Status, see **`STATE.md`** (canonical) — this doc points there instead of restating them.

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
> external audit flagged for removal (the 3D pipeline, `md5`, SMB) are still
> present here and are documented as such.

## 1. EE bootstrap and runtime (`src/`)

### `src/main.cpp` — EE entry, pre-main IOP hygiene, IRX bring-up
- `_ps2sdk_memory_init()` (main.cpp:576) runs BEFORE `main()` inside newlib's
  memory-init hook. Gated on `-DRESET_IOP` (set in Makefile:34, applied
  Makefile:53-55). It performs `SifExitRpc -> SifInitRpc(0) -> fileXioExit ->
  while(!SifIopReset) -> while(!SifIopSync) -> SifInitRpc(0)` (main.cpp:615-620)
  to recover from "polluted parent" launchers (wLaunchELF off non-HDD devices)
  whose live fileXio modules would otherwise hang a plain `SifIopReset`
  (ps2sdk #425). Anyone reading `main()` top-down will miss this reset.
- `detectBootDeviceHintFromArgv0()` (main.cpp:134) derives an advisory pre-Lua
  boot-device hint from `argv[0]`. HDD variants `hdd/pfs/ata/apa` all map to
  `"HDD"` (main.cpp:155-160); both `mass` and `usb` map to `"USB"`
  (main.cpp:139-144) — the MX4SIO-vs-USB disambiguation happens later in Lua.
- `parseLaunchArgs()` (main.cpp:170) parses NHDDL-style args: `-page=`/`-mode=`
  (`-mode` is a pure alias, both write `launch_arg_page`, main.cpp:180-184),
  `-game=`, `-debug`.
- `main()` (main.cpp:396) parses launch args, installs SBV patches, then loads
  the embedded IRX stack via `SifExecModuleBuffer` (LOAD_IRX/LoadIrxChecked
  wrappers, main.cpp:345-367). Boot IRX order is fixed and partly conditional:
  iomanX (main.cpp:427) -> fileXio + fileXioInit (main.cpp:432-438, gated on
  iomanX) -> sio2man (main.cpp:445) -> mmceman ONLY if hint == MMCE
  (main.cpp:460-495) -> mcman/mcserv (main.cpp:502-503) -> initMC
  (main.cpp:504) -> padman (main.cpp:505) -> libsd (main.cpp:507) -> usbd
  (main.cpp:511) -> ds34usb/ds34bt (main.cpp:515-518) -> audsrv (main.cpp:520).
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
  bindings (luaplayer.cpp:278-285), then loads the requested embedded script
  buffer. A missing embedded asset is a hard FATAL, not a disk fallback
  (luaplayer.cpp:294-302).
- Registered binding modules (luaplayer.cpp:278-285): `luaGraphics_init`,
  `luaControls_init`, `luaScreen_init`, `luaTimer_init`, `luaSystem_init`,
  `luaSound_init`, `luaRender_init`, `luaHDD_init`. NOTE: `luaSMB_init` is NOT
  called here (see Orphaned/dormant code below).

### `src/luasystem.cpp` — the largest binding surface (System.*)
- Lazy IRX loaders (Layer C): `EnsureBDM`/`EnsureBDMFatFs`/`EnsureUsbMass`
  chain (luasystem.cpp:80-120), `EnsureMmceman` (luasystem.cpp:141).
- Mass-backend classification: `FetchBdmList`/`ClassifyMassBackend`
  (luasystem.cpp:184-217), driver-name lookup `GetMassMountDriverNameBySlot`
  (luasystem.cpp:312).
- MX4SIO init enforces USB mass first: `lua_mx4sio_init` calls `EnsureUsbMass()`
  before loading `mx4sio_bd.irx` (luasystem.cpp:1405-1429).
- External-ELF launch bindings: `lua_loadELF` (luasystem.cpp:1008),
  `lua_loadELFWithPartition` (luasystem.cpp:1054, requires `reboot_iop != 0` and
  an `hdd?:PART:` partition context, luasystem.cpp:1067-1072),
  `lua_loadELFRebootIOP` (luasystem.cpp:1102). Keep-PFS mask binding
  `lua_set_exec_keep_pfs_mask` (luasystem.cpp:979).
- Launch-arg binding `lua_getLaunchArgs` (luasystem.cpp:1327) and boot-hint
  binding `lua_getBootDeviceHint` (luasystem.cpp:1343).
- `System.md5sum` (`lua_md5sum`, luasystem.cpp:802, registered luasystem.cpp:1459)
  — uses `src/md5.cpp`; has NO embedded-Lua caller (live binding, no consumer).
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
- `Load_HDD_IRX` (luaHDD.cpp:99, exposed as `HDD.Initialize`) loads
  ps2dev9 -> ps2atad -> ps2hdd-osd -> ps2fs back-to-back (luaHDD.cpp:99-136),
  with HDD args `-o 4 -n 20` and PFS args `-m 4 -o 10 -n 40` (luaHDD.cpp:103-106).
  This BETA-12-PLAY state has NO inter-module cold-dev9 settle delay here.
- `GetHDDStatus` via `HDIOC_STATUS` (luaHDD.cpp:72-78); on-demand mount
  `MountPart`/`mnt` (luaHDD.cpp:21-70) producing `pfs%d:/` mount points.

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
- `src/md5.cpp` / `src/include/md5.h` — FreeBSD MD5 implementation. Runtime
  library used only by `System.md5sum` (luasystem.cpp:812-815). It is NOT a
  build-time asset-staleness or embed-integrity gate.
- `src/strUtils.c` — string helpers (note `strUtils.o` is commented out of the
  build, Makefile:76).

### 3D rendering pipeline (present, dormant — not removed)
These files are still on disk AND still compiled (Makefile:74-80), but no
embedded Lua app code calls the bindings they register — i.e. dead at the
application level, live as a registered binding surface. An external audit
recommended removing this pipeline; that removal has NOT been applied here.
- `src/render.cpp` / `src/include/render.h` — VU0 vector/matrix transform and
  clipping math (e.g. `clip_bounding_box`, calc_3d.cpp:3 references it).
- `src/calc_3d.cpp` — VU0 bounding-box clip / 3D calc inline assembly.
- `src/gsKit3d_sup.cpp` — gsKit 3D support helpers.
- `src/luaRender.cpp` (`luaRender_init`, luaRender.cpp:182) — registers the
  `Render`, `Lights`, and `Camera` Lua globals (luaRender.cpp:183-193) and is
  invoked at luaplayer.cpp:284. No `bin/POPSLDR/*.lua` references `Render.`,
  `Camera.`, or `Lights.` (grep of `bin/POPSLDR` returns no matches).

### Orphaned / dead-on-disk
- `src/luaSMB.cpp` — SMB (network share) client logon helpers. NOT in the
  Makefile object lists (Makefile:74-99), `luaSMB_init` is never called
  (luaplayer.cpp:278-285), and there are zero references to it anywhere in the
  tree. It is dead source on disk; SMB is not built into the shipped artifact.
  (SMB also appears as an unimplemented main-menu stub — see Feature Surface.)

## 2. Embedded Lua application (`bin/POPSLDR/`)
All `bin/POPSLDR/*.lua` are bin2c'd into the EE ELF at build time; the on-card
copies are not read at runtime. Editing them requires a rebuild.

### `bin/POPSLDR/system.lua` — controller, device/launch engine, settings
- Owns device resolution, settings persistence, game-list building, the HDD
  cache, and the launch engine. `require`s pops_profiles/ui/images
  (system.lua:2135-2136, 2201).
- Boot-device classification: `ResolveBootContext` (system.lua:1718) /
  `DetectBootDevice` (system.lua:1852), prefix rules at system.lua:1779-1800.
  `mass:/` is disambiguated via the BDM driver name (`classify_mass_boot`,
  system.lua:1735-1772; `sdc`/`mx4` => MX4SIO).
- Launch-arg ingest: `NormalizeLaunchPage` (system.lua:1967), `PLDR.LAUNCH_ARGS`
  (system.lua:1996), carousel page auto-nav `page_to_opt` (system.lua:2181-2199;
  maps MMCE/MX4SIO/HDD/USB/SMB only).
- Settings: `EncodeSettings` (system.lua:2906, **14 keys**: PROFILE,
  POPSTARTER_PATH, POPSTARTER_MODE, BDMA, DKWDRV_PATH, STRICT_HDD_PREEXEC_GATE,
  VIDEO_STANDARD, HIDE_TEXT, KEYBOARD_LAYOUT, BOOT_PAGE, MULTIDISC_COLLAPSE,
  GLOBAL_HIDE, POPSTARTER_MC_FOLDER, HIDDEN_DEVICES), `LoadSettingsNonFatal` (system.lua:2747),
  `SaveSettingsAtomic` (system.lua:2724) -> `WriteAtomic` (system.lua:2284),
  `CommitSettingsChanges` (transactional, system.lua:2874). Per-device sidecar
  `.pldrs` at APP_DIR for every device; **HDD installs now persist on the HDD
  boot partition** via the `PLDR.HDD.EnsureBootPartitionWritable` RW mount
  take-over (system.lua:2091) — no `mc0:` carve-out. `mc0:/POPSTARTER/.pldrs`
  remains only a legacy fallback. See `STATE.md > Settings (single-device parity)`.
- Game-list builders: `GetPS1GameLists` (system.lua:3740, MMCE/MX4SIO, bare
  basenames), `BuildMassGameListByType` (system.lua:3813, USB, `root|name`),
  `HDD.BuildGameList` (system.lua:3926, `partition|relpath`). HDD cache
  (`CreateCache` system.lua:3988 / `ReadCache` system.lua:4010) is gated behind
  `PLDR.HDD.USECACHE` which DEFAULTS FALSE (system.lua:1907) — dormant in the
  shipped state.
- Launch engine: `LaunchEngine` (system.lua:4445), `RunPOPStarterGame`
  (system.lua:4671), `BuildPopstarterLaunchCommand` (system.lua:4649, sets
  per-device `reboot_iop`). HDD pre-exec gate `ValidateHddPopstarterExecGate`
  (system.lua:1554). Keep-PFS-mask prep `PrepareForExternalELFLaunch`
  (system.lua:1017-1045).
- Startup ordering at module end: `LoadSettingsNonFatal` ->
  `AutoInitStartupBackends` (system.lua:3209) -> `SurfaceLaunchArgsDebug` ->
  `AutoLaunchFromLaunchArgs` (system.lua:5157), then the single render loop
  (system.lua:5254-5266 dispatching per-scene `Play()` + `UI.flip()`).

### `bin/POPSLDR/ui.lua` — the entire UI table, no main loop
- Defines one `UI` table literal (ui.lua:320) and `return UI` (ui.lua:3622).
  Contains all scenes, the scene/transition state machine, notification queue,
  busy overlay, cover-art cache, path-editor keyboard, modals, and input layer.
  It has NO main loop — the loop lives at the bottom of system.lua.
- Scenes enum `UI.SCENES` (ui.lua:322-332): GUSBFAT=1, GSMB=3 (reused for MMCE
  and SMB), GMX4SIO=4, GHDD=5 (GAPAHDD aliases 5), GBDMHDD=6, MMAIN=8,
  MPROFILE=9, CREDITS=10.
- Main menu carousel `UI.MainMenu` (opts ui.lua:2894, `Play` ui.lua:2913,
  CONFIRM dispatch ui.lua:3095-3245). Game list `UI.GameList.Play` (ui.lua:2029),
  launch trigger `LaunchSelectedGame` (ui.lua:2201). Settings page
  `UI.ProfileQuery.Play` (ui.lua:2283). DKWDRV/BOOT.ELF/exit handoffs
  `OpenDKWDRV` (ui.lua:1216), `LaunchBootElf` (ui.lua:1325), `ConfirmExit`.
- Cover-art LRU `CoverCache` (ui.lua:156-242), candidate builder
  `BuildCoverCandidates` (ui.lua:130): non-HDD = `base.png` beside the VCD,
  HDD = `hdd0:__common/POPS/ART/<basename>.png`.
- WRITE-GUARD GOTCHA: `__newindex` metatables on `UI.MainMenu` and `UI`
  (ui.lua:3576-3621) silently DROP writes to `UI.MainMenu.OPT` (unless
  `Carousel.allowOptWrite`) and `UI.CURSCENE` (unless
  `Transition.allowSceneWrite`). Build-info display reads `BUILD_INFO.txt`
  (`LoadBuildInfo`, ui.lua:3413-3432).

### `bin/POPSLDR/pops_profiles.lua` — POPSTARTER.ELF location list
- `PLDR.PROFILES` (pops_profiles.lua:44-109) is a 16-entry ordered list of
  `{ELF=path, DESC=text}` POPSTARTER.ELF *locations* (not per-game configs).
  `DEFAULT_PROFILE = 1` seeds `PLDR.POPSTARTER_PATH` (pops_profiles.lua:8-9,
  111-113). The orthogonal PROFILE_DEFAULT vs CUSTOM mode (system.lua:647-712)
  decides whether the profile ELF or a typed override wins.

### `bin/POPSLDR/images.lua` — embedded UI glyph/chrome atlas
- `IMG_REGISTRATIONS` (images.lua:11-43): 31 `{key, filename}` pairs (device
  icons, backgrounds, splash layers, button/d-pad glyphs, plus `missing` and
  `default`). Lazy `IMG` metatable (`__index`, images.lua:58) loads each PNG
  from an embedded blob via `System.getEmbeddedAsset` ->
  `Graphics.loadImageEmbedded` and caches it; only fallback is
  `default -> missing` (`IMG_FALLBACKS`, images.lua:52-54). This is UI chrome,
  NOT per-game box art (game covers are `UI.CoverCache` in ui.lua).

## 3. Boot script (`etc/`)
- `etc/boot.lua` (HDD-boot branch etc/boot.lua:33) mounts the HDD boot partition
  to `pfs1:` (warning "NEVER USE IT FOR ANYTHING ELSE", boot.lua:45), normalizes
  cwd to `pfs1:` (boot.lua:60-61), loads fonts, then `require("system")`
  (boot.lua:178). `System.sleep(2)` (boot.lua:44) is SECONDS, not ms (the binding
  calls C `sleep`, luasystem.cpp:823-829), so it is a full 2-second HDD settle.
  CI requires this file end with a `0x0A` newline.
- `etc/update_lua_globals.sh` — dev helper for syncing Lua globals.

## 4. External ELF-handoff layer (`src/elf_loader/`)
- `src/elf_loader/src/elf.c` — the EE-side parent loader. Central reboot/HDD
  routing fork `LoadELFFromFileExecPS2RebootIOPWithPartition` (elf.c:604): HDD
  partition AND filename both HDD-backed -> `ExecuteHddBackedViaEmbeddedLoader`
  (elf.c:631-634); resolved-path/partition HDD-backed -> same (elf.c:641-642);
  else direct `SifLoadElf -> unmount-pfs (keep-mask) -> SifIopReset -> reload
  rom0:SIO2MAN/MCMAN/MCSERV -> ExecPS2` (elf.c:645-700). BOOT.ELF and DKWDRV-HDD
  special-cases in `LoadELFFromFileWithPartition` (elf.c:467, BOOT.ELF mc-case
  elf.c:485, DKWDRV elf.c:502). `ExecuteViaEmbeddedLoader` (elf.c:383) writes
  BRAM metadata (magic `POPL`, addr `0x00083C00`) and `ExecPS2`s the child.
- `src/elf_loader/src/loader/src/loader.c` — the BRAM child loader. `main()
  (loader.c:275)` reads metadata at `0x00083C00` (loader.c:139-141) and branches
  three ways before `ExecPS2`: filexio-direct (loader.c:368-374); the
  HDD-partition-context branch for D-10 (loader.c:376-397 — unmounts the pfs
  prefix, then `SifExitRpc` + `SifExitCmd`); and the generic/empty-context branch
  for BOOT.ELF/DKWDRV (loader.c:399-422 — `SifExitRpc` only, INTENTIONALLY omits
  `SifExitCmd`; the comment marks that omission as the historical D-15-pass vs
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
  (Makefile:252-256).
- `iop/embed/` — pinned/in-tree IRX blobs bin2c'd into the ELF: `bdm.irx`,
  `bdmfs_fatfs.irx`, `bdmfs_vfat.irx`, `mmceman.irx`, `mx4sio_bd.irx`
  (+`mx4sio_bd_mini.irx`), plus the `PS2SDK_MX4SIO` and `BDMASSAULT_MX4SIO`
  source pins. The active `mx4sio_bd.irx` is pinned from
  `iop/embed/PS2SDK_MX4SIO` (Makefile:258-262). Other IRX (iomanX, fileXio,
  sio2man, mcman, mcserv, padman, libsd, usbd, audsrv, usbmass_bd, cdfs,
  ps2dev9, ps2atad, ps2hdd-osd, ps2fs) resolve from `$(PS2SDK)/iop/irx/`
  (Makefile:226-227, object list Makefile:82-87).

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
  (`BIN2S = $(PS2SDK)/bin/bin2c`, Makefile:61; `EMBEDDED_RSC` Makefile:89-99),
  links the child-loader lib, strips, and runs `ps2-packer` to produce
  `bin/POPSLOADER.ELF` (Makefile:112-114). `make elfloader` (Makefile:265-270)
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
Dispatch at ui.lua:3095-3245.
- `MMCE` (OPT1): implemented.
- `MX4SIO` (OPT2): implemented.
- `HDD (PFS)` (OPT4): implemented (routes to scene GHDD=5).
- `USB` (OPT5): implemented.
- `Disc (DKWDRV)` (OPT8): implemented.
- `HDD (exFAT)` (OPT3): NOT implemented — surfaces "isn't implemented yet"
  (ui.lua:3157).
- `i.Link` (OPT6): NOT implemented (ui.lua:3237).
- `SMB (v1)` (OPT7): NOT implemented (ui.lua:3239). The SMB C client
  (`src/luaSMB.cpp`) is also not built (see Orphaned/dead-on-disk).

## Preservation Contracts (hardware-load-bearing — do not regress)
- D-10 (HDD POPSTARTER + HDD game): the BRAM child-loader route via the
  HDD-partition-context branch (loader.c:376-397) — unmount the pfs prefix, then
  `SifExitRpc` + `SifExitCmd`. (The generic branch loader.c:399-422, which omits
  `SifExitCmd`, is the BOOT.ELF/DKWDRV path, not D-10.)
- D-15 (non-HDD POPSTARTER + HDD game): keep-PFS mask preserves the boot
  partition's `pfs1:` slot (elf.c keep-mask, system.lua:1017-1045).
- DKWDRV from HDD inherits the same embedded-loader path as POPSTARTER
  (elf.c:614-635); the V3 direct-reset route black-screened on hardware.
- BRAM metadata struct (`partition_context[128]`, `load_path[256]`, magic `POPL`)
  must stay byte-identical between writer (elf.c) and reader (loader.c).
- Settings sidecar (single-device parity): USB/MC/MMCE/MX4SIO **and HDD** all use
  the per-device `.pldrs` sidecar. HDD installs persist on the HDD boot partition
  via the `PLDR.HDD.EnsureBootPartitionWritable` RW mount take-over
  (system.lua:2091) — there is **no** `mc0:` HDD carve-out. That take-over is now
  load-bearing for HDD settings save and HDD in-app `.hide`; don't regress it.
  (Supersedes the old HDD-to-MC exception.) See `STATE.md > Preservation Contracts`
  and `STATE.md > Settings (single-device parity)`.

> Divergence note (per project memory): this BETA-12-PLAY worktree's
> `PLDR.LoadHDDModules` (system.lua:3955) and `Load_HDD_IRX` (luaHDD.cpp:99) have
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
