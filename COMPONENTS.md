Last updated: 2026-06-22 (BETA-13 rolling candidate; HEAD = BETA-13-PLAY @ 3d89631; BETA-12 is the public release at af983d7, and BETA-12-PLAY is now ARCHIVAL/frozen). Since the prior pass: nav auto-repeat and the right-stick description scroll were re-cut to FRAME-COUNTING (the wall clock reads microseconds on PS2, so the old "_ms" gates fired every frame); the analog-stick→d-pad fold is now gated on a live-negotiated analog mode (new `Pads.getMode()` C binding) plus hysteresis; an OPL-style overscan (CRT inset) render transform was added (`Screen.setOverscan`/`getOverscan` + `OVX`/`OVY`); the game-list cover box now layers `cover_default.png` + `cover_missing.png` and `MISSING.png` was removed (−62 KB ELF); and two new settings keys (BOOT_SOUND, OVERSCAN) bring EncodeSettings to 20 keys. Since 56a5ad5: the HDD (exFAT) / BDMA-ATA backend landed (df2eb9d/6fd2142/afa1c09 — internal SATA/IDE drive enumerates under `mass:` classified by the EXACT ioctl driver-name `ata`, carousel opt 3 = exFAT page scene GBDMHDD); launch-arg routing (3d89631) maps `-page`/`-mode=ata*`→EXFAT (opt 3) and `=hdd`/`apa`/`pfs*`→HDD (opt 4); the audit cleanup (2735229) removed dead symbols and SHIFTED line numbers across luasystem.cpp/ui.lua/system.lua; the timer sweep finished (9c3f64f/a8e61f3) and the `MIN_ACTION_MS` action debounce was removed (edge-trigger is the only gate); and the Layer C lazy-IRX effort is CLOSED (ds34bt/usbd deferral DECLINED, only mmceman shipped). For current Settings behavior, Known Issues, Preservation Contracts, Behavioral Invariants, and Hardware Status, see **`STATE.md`** (canonical) — this doc points there instead of restating them.

# COMPONENTS

## Purpose
Current technical map of POPSLoader source files, their responsibility, and key
entry points. POPSLoader is a PS1-game launcher built on the Enceladus runtime:
EE C/C++, an embedded Lua application (`bin/POPSLDR/*.lua` compiled into the EE
ELF via bin2c), embedded IOP IRX modules, and a BRAM child ELF-loader. Every
technical claim below cites `path:line` against this worktree.

> Scope note: this file documents what is actually present and wired in the
> BETA-13-PLAY rolling state (the active branch; BETA-12-PLAY is frozen). Where a
> component is on disk but unused (dead or
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
  This BETA-13-PLAY state has NO inter-module cold-dev9 settle delay here.
- `GetHDDStatus` via `HDIOC_STATUS` (luaHDD.cpp:93-96); on-demand mount
  `MountPart`/`mnt` (luaHDD.cpp:21-92) producing `pfs%d:/` mount points.

### `src/embed_assets.cpp` — runtime name -> embedded blob resolver
- `embedded_get()` (embed_assets.cpp:195) normalizes paths (strips `embed:/`,
  embed_assets.cpp:205; `./`, embed_assets.cpp:209; leading `/`,
  embed_assets.cpp:212) and resolves against the static `g_embedded_assets` table
  (embed_assets.cpp:93-181) via `embedded_find` (embed_assets.cpp:184). There is
  NO icon/`MISSING.png` fallback — a missing key returns 0 and the Lua caller
  decides. Each asset appears TWICE in the table: under its bare name and under a
  `POPSLDR/IMG/`-prefixed key (mirror tables at embed_assets.cpp:94-138 and
  141-181). `default.png` is an OPTIONAL legacy cover override, declared and added
  only inside `#ifdef HAVE_ASSET_DEFAULT_PNG` (extern embed_assets.cpp:56-59;
  entries embed_assets.cpp:117 & 164); the cover box does NOT depend on it. The new
  `cover_default.png` / `cover_missing.png` placeholders are MANDATORY embeds
  (extern embed_assets.cpp:60-63; entries embed_assets.cpp:119-120 & 166-167).

### Other EE runtime files
- `src/graphics.cpp` / `src/luagraphics.cpp` — gsKit 2D drawing + `Graphics.*`
  Lua bindings (`luaGraphics_init`, luagraphics.cpp). Image load/draw, the
  `Graphics.loadImageEmbedded` path used by `images.lua`. Also hosts the
  **overscan (CRT inset) transform** (graphics.cpp:1128-1166): `g_overscan`
  permille (graphics.cpp:1135), `set_overscan`/`get_overscan` (graphics.cpp:1155,
  1163; clamped 0..200), `recompute_overscan` (graphics.cpp:1140), and the
  `OVX()`/`OVY()` inline scalers (graphics.cpp:1165-1166) that every gsKit draw
  site routes through. The math is OPL `rmSetOverscan` exactly (margin =
  W*permille/2000 per edge, scale = 1 - permille/1000); at permille 0 the
  transform is the IDENTITY so the default render is unchanged, and
  `recompute_overscan` is re-run on a screen-dim change (graphics.cpp:1339).
- `src/fntsys.cpp` / `src/atlas.cpp` — TrueType font system and glyph atlas.
- `src/luaScreen.cpp` (`luaScreen_init`) — `Screen.*` flip/clear bindings, plus
  the overscan Lua surface `Screen.setOverscan(permille)` / `Screen.getOverscan()`
  (`lua_set_overscan` luaScreen.cpp:64 / `lua_get_overscan` luaScreen.cpp:71;
  registered luaScreen.cpp:162-163) wrapping graphics.cpp's `set_overscan`/
  `get_overscan`.
- `src/luacontrols.cpp` (`luaControls_init`) — pad input, registered under the
  global **`Pads`** (NOT `Controls`; `Pads_functions` luacontrols.cpp:273,
  `lua_setglobal "Pads"` luacontrols.cpp:289). `Pads.getMode()`
  (`lua_getmode` luacontrols.cpp:70; registered luacontrols.cpp:278) returns the
  LIVE negotiated controller mode via `padInfoMode(port,0,PAD_MODECURID,0)`
  (luacontrols.cpp:78) — high nibble 0x5 analog / 0x7 DualShock / 0x4 digital / 0
  no-data. The pre-existing `Pads.getType()` (`lua_gettype` luacontrols.cpp:9;
  registered luacontrols.cpp:277) reads `PAD_MODETABLE` (a capability-table entry,
  luacontrols.cpp:17) and is NOT the live mode — `ui.lua`'s stick-fold gate must
  use `getMode`. `getLeftStick`/`getRightStick` (`lua_getleft` luacontrols.cpp:82
  / `lua_getright` luacontrols.cpp:119) are hardened: zero-init + neutral (0,0)
  default, and they only report a non-neutral axis when a pad read actually
  returned data, so an unread/failed frame can't inject a phantom -127. The
  `PAD_ANALOG`/`PAD_DUALSHOCK` globals the gate compares against are exported here
  (luacontrols.cpp:343, 346).
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
  stub (OPT7, ui.lua:4397-4398) — see Feature Surface.

## 2. Embedded Lua application (`bin/POPSLDR/`)
All `bin/POPSLDR/*.lua` are bin2c'd into the EE ELF at build time; the on-card
copies are not read at runtime. Editing them requires a rebuild.

### `bin/POPSLDR/system.lua` — controller, device/launch engine, settings
- Owns device resolution, settings persistence, game-list building, the HDD
  cache, and the launch engine. `require`s pops_profiles/ui/images
  (system.lua:2433, 2526).
- Boot-device classification: `ResolveBootContext` (system.lua:1849) /
  `DetectBootDevice` (system.lua:1983), prefix rules under `ResolveBootContext`.
  `mass:/` is disambiguated via the BDM driver name (`classify_mass_boot`,
  system.lua:1866; `sdc`/`mx4` => MX4SIO).
- Launch-arg ingest: `NormalizeLaunchPage` (system.lua; `ata*`->EXFAT,
  `hdd*`/`apa*`/`pfs*`->HDD, bare `bdma`->no-op page value), `PLDR.LAUNCH_ARGS`,
  carousel page auto-nav `page_to_opt` (MMCE=1/MX4SIO=2/EXFAT=3/ATA=3/HDD=4/USB=5/SMB=7).
- Settings: `EncodeSettings` (system.lua:3072, **20 keys**: PROFILE,
  POPSTARTER_PATH, POPSTARTER_MODE, BDMA, DKWDRV_PATH, STRICT_HDD_PREEXEC_GATE,
  VIDEO_STANDARD, HIDE_TEXT, KEYBOARD_LAYOUT, BOOT_PAGE, MULTIDISC_COLLAPSE,
  GLOBAL_HIDE, POPSTARTER_MC_FOLDER, HIDDEN_DEVICES, SHOW_DETAILS, DETAILS_ALIGN,
  GAMELIST_CACHE, BOOT_SOUND, OVERSCAN, DESC_SCROLL_SPEED — BOOT_SOUND and OVERSCAN
  are new this cycle), `LoadSettingsNonFatal` (system.lua:3301),
  `SaveSettingsAtomic` (system.lua:3262) -> `WriteAtomic` (system.lua:2663),
  `CommitSettingsChanges` (transactional, system.lua:3540). Per-device sidecar
  `.pldrs` at APP_DIR for every device; **HDD installs now persist on the HDD
  boot partition** via the `PLDR.HDD.EnsureBootPartitionWritable` RW mount
  take-over (system.lua:2159) — no `mc0:` carve-out. `mc0:/POPSTARTER/.pldrs`
  remains only a legacy fallback. See `STATE.md > Settings (single-device parity)`.
- Game-list builders: `GetPS1GameLists` (system.lua:4529, MMCE/MX4SIO, bare
  basenames), `BuildMassGameListByType` (system.lua:4593, USB, `root|name`),
  `HDD.BuildGameList` (system.lua:4720, `partition|relpath`). HDD cache
  (`CreateCache` system.lua:4880 / `ReadCache` system.lua:4927) is gated on the
  `PLDR.GAMELIST_CACHE` setting (opt-in, default OFF; default set at
  system.lua:3319, runtime gate checks at system.lua:4522/5031/5078).
  `USECACHE` (system.lua:2048) is a dead legacy flag. The same `GAMELIST_CACHE`
  gate covers the USB/MMCE/MX4SIO list cache (`SaveGameListCache`
  system.lua:4816; there is no separate `ReadGameListCache` function — the HDD
  reader is `PLDR.HDD.ReadCache` system.lua:4927).
- Launch engine: `LaunchEngine` (system.lua:5436), `RunPOPStarterGame`
  (system.lua:5653), `BuildPopstarterLaunchCommand` (system.lua:5631, sets
  per-device `reboot_iop`). HDD pre-exec gate `ValidateHddPopstarterExecGate`
  (system.lua:1655). Keep-PFS-mask prep `PrepareForExternalELFLaunch`
  (local def system.lua:1120, PLDR wrapper system.lua:1793).
- Startup ordering at module end: `LoadSettingsNonFatal` ->
  `AutoInitStartupBackends` (system.lua:3920) -> `SurfaceLaunchArgsDebug` ->
  `AutoLaunchFromLaunchArgs` (system.lua:6139), then the single render loop
  (system.lua:6364-6376; dispatch body 6365-6375 per-scene `Play()` + `UI.flip()`).

### `bin/POPSLDR/ui.lua` — the entire UI table, no main loop
- Defines one `UI` table literal (ui.lua:446) and `return UI` (ui.lua:4991).
  Contains all scenes, the scene/transition state machine, notification queue,
  busy overlay, cover-art cache, path-editor keyboard, modals, and input layer.
  It has NO main loop — the loop lives at the bottom of system.lua.
- Scenes enum `UI.SCENES` (ui.lua:448-458): GUSBFAT=1, GSMB=3 (reused for MMCE
  and SMB), GMX4SIO=4, GHDD=5 (GAPAHDD aliases 5), GBDMHDD=6, MMAIN=8,
  MPROFILE=9, CREDITS=10.
- Main menu carousel `UI.MainMenu` (table ui.lua:3976, opts ui.lua:3978; the
  CONFIRM/Play dispatch is the MainMenu `Play` handler at ui.lua:3997, OPT switch
  ~4227-4404). Game list `UI.GameList` (table ui.lua:2324), launch trigger
  `LaunchSelectedGame` (ui.lua:2750). Settings page `UI.ProfileQuery` (table
  ui.lua:2976, `Play` ui.lua:2979). DKWDRV/BOOT.ELF/exit handoffs `OpenDKWDRV`
  (ui.lua:1371), `LaunchBootElf` (ui.lua:1592), `ConfirmExit`.
- Input layer `UI.Pad.Listen` (ui.lua:4440) — folds the LEFT ANALOG STICK into
  the d-pad bits and resolves nav. Both timing concerns here are now
  **FRAME-COUNTED, not wall-clock** (`Timer.getTime()` reads microseconds on PS2,
  so the old `_ms` gates fired every frame):
  - Nav auto-repeat `resolve_nav` (ui.lua:4583): `nav_fps` = 50 when SCR.Y>=512
    else 60 (ui.lua:4580); `NAV_DELAY_FRAMES = ceil(nav_fps*0.6)`,
    `NAV_RATE_FRAMES = ceil(nav_fps*0.2)` (ui.lua:4581-4582); a per-direction
    `UI.Pad.NavHoldFrames` counter (ui.lua:4430) ticks once per frame. Press fires
    immediately; only UP/DOWN repeat (~0.6 s delay then ~0.2 s, ~5/s) — LEFT/RIGHT
    stay edge-only (ui.lua:4607-4610).
  - Stick→d-pad fold (ui.lua:4469-4511) is GATED on `Pads.getMode()` reporting
    `PAD_ANALOG`/`PAD_DUALSHOCK` (ui.lua:4470-4475) plus a per-axis hysteresis
    latch (`StickV`/`StickH`, assert |v|>64, release <40; ui.lua:4479-4503). On a
    digital/non-analog pad the fold is skipped and any latch is dropped
    (ui.lua:4506-4511), so stale analog bytes can't inject a phantom PAD_UP/LEFT.
- Cover-art preview box (game-list render, ui.lua:2440-2591) layers two
  placeholder assets and NO longer draws a "Cover disabled" text label: no live
  cover → `IMG.cover_default` (ui.lua:2582-2583); preview ENABLED but the game has
  no cover → `cover_default` with `IMG.cover_missing` overlaid (ui.lua:2585-2586);
  a LIVE cover uses its own COVER_W inset (ui.lua:2573-2576). The default, the
  missing overlay, and `IMG.frame` all share the frame's aspect-corrected,
  right-anchored rect (`frame_x`/`draw_y`/`frame_w`/`frame_h`, ui.lua:2572-2590) so
  they register with the jewel-case window on both NTSC and PAL.
- Right-stick description scroll (ui.lua:2669-2700) is FRAME-COUNTED too via
  `UI.GameList.DescScrollFrames` (ui.lua:2334): step every `ceil(_secs*fps)`
  frames (ui.lua:2684-2687), with the "Description scroll speed" setting in
  SECONDS — slow 0.9 (default) / medium 0.3 / fast 0.15 (ui.lua:2680-2682).
- Cover-art LRU `CoverCache` (ui.lua:257-343), candidate builder
  `BuildCoverCandidates` (ui.lua:175): non-HDD = `base.png` beside the VCD
  (ui.lua:196-198), HDD = `hdd0:__common/POPS/ART/<basename>.png` (ui.lua:185).
- WRITE-GUARD GOTCHA: `__newindex` metatables on `UI.MainMenu` and `UI`
  (ui.lua:4957 & 4979) silently DROP writes to `UI.MainMenu.OPT` (unless
  `Carousel.allowOptWrite`, ui.lua:4960) and `UI.CURSCENE` (unless
  `Transition.allowSceneWrite`, ui.lua:4981). Build-info display reads
  `BUILD_INFO.txt` (`LoadBuildInfo`, ui.lua:4687).

### `bin/POPSLDR/pops_profiles.lua` — POPSTARTER.ELF location list
- `PLDR.PROFILES` (pops_profiles.lua:26-91) is a 16-entry ordered list of
  `{ELF=path, DESC=text}` POPSTARTER.ELF *locations* (not per-game configs).
  `DEFAULT_PROFILE = 1` seeds `PLDR.POPSTARTER_PATH` (pops_profiles.lua:8,
  93-94). The orthogonal PROFILE_DEFAULT vs CUSTOM mode (system.lua:667-712)
  decides whether the profile ELF or a typed override wins.

### `bin/POPSLDR/images.lua` — embedded UI glyph/chrome atlas
- `IMG_REGISTRATIONS` (images.lua:11-37): 25 `{key, filename}` pairs (device
  icons, backgrounds, splash layers, button/d-pad glyphs, `frame`, the optional
  legacy `default`, and the cover placeholders `cover_default` + `cover_missing`;
  the old `missing` key is GONE). `IMG_SOURCES` maps each key to its bare filename
  (images.lua:39-44); the `cover_default`/`cover_missing` covers are consumed by
  the ui.lua preview box via `IMG.cover_default`/`IMG.cover_missing`. Lazy `IMG`
  metatable (`__index`, images.lua:51) fetches each PNG by that filename through
  `System.getEmbeddedAsset` -> `Graphics.loadImageEmbedded` (images.lua:56-59) and
  caches it.
  `IMG_FALLBACKS` (images.lua:46) is now an EMPTY table — the old
  `default -> missing` fallback was removed with `MISSING.png`, so an unresolved
  key just returns nil (marked in `IMG_FAILED`). This is UI chrome, NOT per-game
  box art (game covers are `UI.CoverCache` in ui.lua).

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
  ps2dev9, ps2atad, ps2hdd-osd, ps2fs, mmceman, ata_bd) resolve from `$(PS2SDK)/iop/irx/`
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
  (`BIN2S = $(PS2SDK)/bin/bin2c`, Makefile:67; `EMBEDDED_RSC` Makefile:96-105),
  links the child-loader lib, strips, and runs `ps2-packer` to produce
  `bin/POPSLOADER.ELF` (Makefile:118-120). `make elfloader` (Makefile:257-262)
  force-regenerates the child loader. `RESET_IOP = 1` (Makefile:34) compiles in
  the pre-main IOP reset. `default.png` is the only OPTIONAL embed: it is added to
  `OPTIONAL_EMBEDDED_RSC` and defines `-DHAVE_ASSET_DEFAULT_PNG=1` ONLY when the
  file is present in the checkout (wildcard guard, Makefile:72-75); everything else
  (incl. the new `cover_default.png` / `cover_missing.png`, BIN2S rules
  Makefile:179-182) is mandatory.
- EMBED MECHANISM (adding/removing an embedded asset is THREE coordinated places,
  NOT an auto-glob, and they must be kept in sync MANUALLY — there is no
  machine-checked embed manifest): (a) `Makefile` — a `BIN2S` PNG rule plus the
  `.o` in `EMBEDDED_RSC`; (b) `src/embed_assets.cpp` — an `extern` declaration plus
  an `ASSET_ENTRY` in BOTH the bare-name and the `POPSLDR/IMG/`-prefixed mirror
  tables; (c) `bin/POPSLDR/images.lua` `IMG_REGISTRATIONS` (looked up by the bare
  filename). The `MISSING.png` removal (−62 KB ELF) touched all three plus the
  ui.lua draw path and was the reference example of this dance.
- `.github/workflows/compilation.yml` — CI on all branches/tags/PRs/dispatch:
  runs the now-LIVE embedded-Lua **syntax** gate (`apk add lua5.4` + `luac5.4 -p`
  on `bin/POPSLDR/*.lua` + `etc/boot.lua`, hard-fail on syntax error — it used to
  silently no-op because the pinned ps2dev image had no `luac`; catches SYNTAX
  only, so runtime nil-global / type / load-order errors stay invisible),
  generates `BUILD_INFO.txt`, runs `make clean elfloader all`, enforces
  embed-identity gates (three string markers in the ELF + loader.c parity), and
  packages the strict-verified `POPSLOADER.zip` install bundle as an artifact (no
  GitHub release). The redistributable `POPSTARTER.ELF` ships in `PS1_POPSLOADER/`
  next to `POPSLOADER.ELF` (compilation.yml:161) AND in `POPS/`
  (compilation.yml:171), both on the manifest's required-file list.
  See `STATE.md > CI / release`.
- `.github/workflows/rolling-release.yml` — on push to **BETA-13-PLAY**
  (rolling-release.yml:6) and PR events: bundles the ELF + full git-tracked source
  and force-updates the `rolling-release` prerelease via the GitHub API. The
  redistributable `POPSTARTER.ELF` now ships at the ZIP ROOT next to
  `POPSLOADER.ELF` (rolling-release.yml:182) AND in `POPS/`
  (rolling-release.yml:192); `POPS/PATCH_5.BIN` and a `POPSTARTER/` pack folder
  also ship at the root (rolling-release.yml:173). (POPS engine binaries remain
  NON-redistributable — users supply their own.)
- `.github/workflows/opencode.yml` — `/oc` comment bot (DeepSeek). Not part of
  release packaging or runtime behavior.

## Current Feature Surface by Main Menu Option
Dispatch in the MainMenu `Play` handler (ui.lua:3997), OPT switch ~ui.lua:4227-4404.
- `MMCE` (OPT1): implemented.
- `MX4SIO` (OPT2): implemented.
- `HDD (PFS)` (OPT4): implemented (routes to scene GHDD=5).
- `USB` (OPT5): implemented.
- `Disc (DKWDRV)` (OPT8): implemented.
- `HDD (exFAT)` (OPT3): implemented — scans the exFAT internal drive as a `mass:`
  backend (BDMA `ata`) via `InitATAPopsRoot` + `GetPS1GameLists` -> scene GBDMHDD=6
  (ui.lua:4349). Classified by exact ioctl driver-name `ata`. Validating on hardware.
- `i.Link` (OPT6): NOT implemented (ui.lua:4462).
- `SMB (v1)` (OPT7): NOT implemented (ui.lua:4464). There is no SMB C client;
  the former `src/luaSMB.cpp` orphan was removed in commit f83dbbb (see
  Orphaned/dead-on-disk).

## Preservation Contracts (hardware-load-bearing — do not regress)
- D-10 (HDD POPSTARTER + HDD game): the BRAM child-loader route via the
  HDD-partition-context branch (loader.c:381-403, SifExitRpc+SifExitCmd at
  396-397) — unmount the pfs prefix, then `SifExitRpc` + `SifExitCmd`. (The
  generic branch loader.c:404-427, which omits `SifExitCmd`, is the
  BOOT.ELF/DKWDRV path, not D-10.)
- D-15 (non-HDD POPSTARTER + HDD game): keep-PFS mask preserves the boot
  partition's `pfs1:` slot (elf.c keep-mask, system.lua:1120).
- DKWDRV from HDD inherits the same embedded-loader path as POPSTARTER
  (elf.c:628-644); the V3 direct-reset route black-screened on hardware.
- BRAM metadata struct (`partition_context[128]`, `load_path[256]`, magic `POPL`)
  must stay byte-identical between writer (elf.c) and reader (loader.c).
- Settings sidecar (single-device parity): USB/MC/MMCE/MX4SIO **and HDD** all use
  the per-device `.pldrs` sidecar. HDD installs persist on the HDD boot partition
  via the `PLDR.HDD.EnsureBootPartitionWritable` RW mount take-over
  (system.lua:2159) — there is **no** `mc0:` HDD carve-out. That take-over is now
  load-bearing for HDD settings save and HDD in-app `.hide`; don't regress it.
  (Supersedes the old HDD-to-MC exception.) See `STATE.md > Preservation Contracts`
  and `STATE.md > Settings (single-device parity)`.

> Divergence note (per project memory): this BETA-13-PLAY worktree's
> `PLDR.LoadHDDModules` (system.lua:4754) and `Load_HDD_IRX` (luaHDD.cpp:120) have
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
