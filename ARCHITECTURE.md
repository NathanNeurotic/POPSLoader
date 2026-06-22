Last updated: 2026-06-21 (BETA-13 session; frame-count nav + `Timer.getTime`-is-microseconds reality + layered `cover_default`/`cover_missing` art with `MISSING.png` dropped + OPL-style overscan render-inset + `Pads.getMode` binding). Active/rolling branch is now **`BETA-13-PLAY`** (`BETA-12-PLAY` is archival; public release is still BETA-12). For current Settings behavior, Known Issues, Preservation Contracts, Behavioral Invariants, and Hardware Status, see **`STATE.md`** (canonical) — this doc points there instead of restating them.

# ARCHITECTURE

POPSLoader is a PS1-game launcher for the PlayStation 2, built on the Enceladus
runtime. The shipped binary is a single packed EE ELF (`bin/POPSLOADER.ELF`)
that contains:

- EE-side C/C++ (boot, IRX bring-up, native bindings, ELF handoff),
- an embedded Lua application (the entire UI + launch logic, baked in via
  `bin2c`),
- embedded IOP IRX modules (storage/pad/audio drivers, loaded from memory),
- an embedded second-stage child ELF loader that runs from BIOS RAM (BRAM).

Nothing in the runtime is read from loose files beside the ELF: Lua scripts,
PNGs, and IRX modules are all compiled into the ELF as byte arrays and resolved
by name at runtime (`src/embed_assets.cpp`).

This document describes the system top-to-bottom: boot/IOP -> Lua VM ->
UI/scenes -> device backends -> game launch/handoff -> build/embed pipeline.
For the load-bearing hardware-regression contracts that must not be changed
without hardware re-verification, see `PRESERVATION_CONTRACTS.md`.

---

## Subsystem diagram

```
                          POWER-ON / parent launcher (wLaunchELF, PSBBN, OSDSYS, MC autoboot, NHDDL)
                                                |
                                                v
+----------------------------------------------------------------------------------------------+
| PHASE 0  (BEFORE main)   src/main.cpp:619 _ps2sdk_memory_init()  [compiled iff -DRESET_IOP]   |
|   SifExitRpc -> SifInitRpc(0) -> fileXioExit -> SifIopReset(loop) -> SifIopSync -> SifInitRpc |
|   Survives "polluted parents" that leave fileXio alive (ps2sdk #425).                          |
+----------------------------------------------------------------------------------------------+
                                                |
                                                v
+----------------------------------------------------------------------------------------------+
| PHASE 1  EE entry   src/main.cpp:439 main()                                                   |
|   parseLaunchArgs (-page/-mode/-game/-debug)  |  detectBootDeviceHintFromArgv0 (advisory)     |
|   SBV patches  |  IRX bring-up (SifExecModuleBuffer from bin2c'd buffers)  |  gsKit+pad init   |
|   runScript("boot.lua")                                                                        |
+----------------------------------------------------------------------------------------------+
                                                |
                       IRX stack (boot order, fixed)        Layer C (lazy, on demand)
              iomanX -> fileXio -> sio2man                  bdm -> bdmfs_fatfs -> usbmass_bd
              -> [mmceman iff hint==MMCE] -> mcman          mx4sio_bd  (needs usbmass first)
              -> mcserv -> initMC -> padman -> libsd         mmceman   (luasystem EnsureMmceman)
              -> usbd -> ds34usb -> ds34bt -> audsrv         dev9->atad->ps2hdd-osd->ps2fs (luaHDD)
                                                |
                                                v
+----------------------------------------------------------------------------------------------+
| LUA VM   src/luaplayer.cpp:254 runScript()                                                     |
|   custom embedded require() searcher; dofile/loadfile NIL'd; package.path/cpath cleared        |
|   bindings: System.* (luasystem.cpp), HDD.* (luaHDD.cpp), Graphics/Pad/etc.                    |
+----------------------------------------------------------------------------------------------+
                                                |
                                                v
+----------------------------------------------------------------------------------------------+
| EMBEDDED LUA APPLICATION                                                                       |
|   etc/boot.lua         mount HDD boot part -> pfs1: ; MX4SIO slot xlate ; fonts ; require()    |
|   pops_profiles.lua    PLDR.PROFILES (16 POPSTARTER.ELF location candidates)                   |
|   images.lua           IMG_REGISTRATIONS (UI glyph/icon atlas, lazy from embedded PNGs)        |
|   system.lua  <----- controller: device resolution, settings, game lists, LAUNCH ENGINE       |
|        |                  require()s ui + pops_profiles + images, owns the main loop           |
|        v                                                                                       |
|   ui.lua               one big UI table: scenes, transitions, modals, carousel, cover cache    |
+----------------------------------------------------------------------------------------------+
                                                |
                            game launch  (PLDR.RunPOPStarterGame -> LaunchEngine)
                                                v
+----------------------------------------------------------------------------------------------+
| ELF HANDOFF                                                                                    |
|   luasystem.cpp  System.loadELF / loadELFWithPartition / loadELFRebootIOP                      |
|   elf.c          THREE teardown contracts:                                                     |
|       (1) HDD-backed   -> ExecuteHddBackedViaEmbeddedLoader -> ExecuteViaEmbeddedLoader        |
|       (2) BOOT.ELF / DKWDRV-on-HDD (reboot_iop=0) -> embedded loader special-cases             |
|       (3) non-HDD       -> SifLoadElf -> unmount pfs -> SifIopReset -> reload MC IRX -> ExecPS2 |
|   loader.c       BRAM child: reads metadata @0x00083C00 'POPL' -> ExecPS2(final target)        |
+----------------------------------------------------------------------------------------------+
                                                |
                                                v
                          POPSTARTER.ELF / DKWDRV.ELF / game / mc?:/BOOT/BOOT.ELF
```

---

## Layer 1 — Boot and IOP bring-up (`src/main.cpp`)

Boot has two distinct phases, and the order is non-obvious: the IOP is reset
**before** `main()` runs.

### Phase 0: pre-`main()` IOP hygiene
newlib calls `_ps2sdk_memory_init()` during EE process startup, before `main()`
(`src/main.cpp:619`). When built with `-DRESET_IOP` it performs a defensive IOP
reset: `SifExitRpc()` -> `SifInitRpc(0)` -> `fileXioExit()` ->
`while(!SifIopReset("",0)){}` -> `while(!SifIopSync()){}` -> `SifInitRpc(0)`
(`src/main.cpp:658-663`). This recovers from "polluted parent" launchers that
hand off with `fileXio` still loaded on the IOP — notably wLaunchELF, which only
resets the IOP for HDD targets. A live `fileXio` holds IOP threads/semaphores
that block a plain `SifIopReset` (ps2sdk #425), causing a silent hang ->
black screen. `RESET_IOP = 1` is set in the shipped build (`Makefile:34`), and
the flag is wired to the compiler at `Makefile:53-55`. Because this runs before
`main()`, a top-down read of `main()` misses the reset entirely.

### Phase 1: `main()` (`src/main.cpp:439`)
1. `parseLaunchArgs(argc, argv)` (`src/main.cpp:198`, called at `:450`) parses
   NHDDL-style args into static buffers. `-page=` and `-mode=` both write
   `launch_arg_page` (`-mode` is an alias); `-game=` -> `launch_arg_game`;
   `-debug` -> `launch_arg_debug` (`src/main.cpp:220-231`).
2. `detectBootDeviceHintFromArgv0()` (`src/main.cpp:134`) derives an **advisory**
   pre-Lua boot-device hint from `argv[0]`. All HDD-shaped prefixes
   (`hdd`/`pfs`/`ata`/`apa`) classify as `"HDD"` (`src/main.cpp:155-160`);
   `mass` and `usb` both map to `"USB"` (`src/main.cpp:139-144`). This hint is
   for pre-Lua/pre-IRX decisions only — the authoritative device is resolved
   later in Lua (see Layer 4). Exposed to Lua as `System.getBootDeviceHint()`
   (`src/luasystem.cpp:1227`).
3. SBV patches: `sbv_patch_disable_prefix_check()` + `sbv_patch_fileio()`
   (`src/main.cpp:463-464`).
4. IRX bring-up via `SifExecModuleBuffer` from bin2c'd buffers (no module
   reload from rom0/disk during normal boot). The fixed order is:
   `iomanX` -> `fileXio` (+`fileXioInit`) -> `sio2man` ->
   `[mmceman only if hint==MMCE]` -> `mcman` -> `mcserv` -> `initMC` ->
   `padman` -> `libsd` -> `usbd` -> `ds34usb` -> `ds34bt` (+inits) -> `audsrv`
   (`src/main.cpp:470-563`). Each stage degrades gracefully: `fileXio` is gated
   on `iomanX` (`if (ioman_ok)`, `src/main.cpp:474`), and the `mmceman` eager
   load is gated on the `MMCE` boot hint (`src/main.cpp:503`).
5. `mmceman.irx` is the **only** device-specific module eagerly loaded at boot,
   and only when `boot_device_hint == "MMCE"`
   (`src/main.cpp:503-520`), then `MarkMmcemanLoaded()` syncs the lazy tracker
   (`src/main.cpp:520`). Every other backend (BDM/USB/MX4SIO/HDD) defers to
   Layer C.
6. Set boot path / app dir (`src/main.cpp:565-570`), init gsKit graphics + pad,
   `chdir(boot_path)`, then enter the `runScript("boot.lua")` loop.

> MC is not MMCE. Standard PS2 memory cards (`mc0:`/`mc1:`) use the
> unconditionally-loaded `mcman`/`mcserv` stack (`src/main.cpp:545-546`).
> MMCE (third-party adapters exposing `mmce0:`/`mmce1:`) uses `mmceman.irx`,
> which is conditional/lazy. The argv0 classifier deliberately excludes `mcm`
> so `mcman` is not mistaken for an MC boot.

---

## Layer 2 — Embedded Lua VM (`src/luaplayer.cpp`)

`runScript()` (`src/luaplayer.cpp:254`) creates the Lua state, registers all
native bindings, installs the embedded asset machinery, and runs `boot.lua`.

- The runtime Lua assets are embedded as byte arrays
  (`src/luaplayer.cpp:35-41`): `boot.lua`, `system.lua`, `ui.lua`,
  `images.lua`, `pops_profiles.lua`.
- `InstallEmbeddedLuaSearcher` (`src/luaplayer.cpp:114`) makes `require()`
  resolve modules from the embedded table via `FindEmbeddedLua`.
- `DisableLuaFilesystemScriptLoaders` (`src/luaplayer.cpp:148`) NILs `dofile`
  and `loadfile` and clears `package.path`/`package.cpath`, so startup cannot
  fall back to loose files. A missing embedded asset is a hard FATAL, not a
  disk fallback.

This means **every `.lua` under `bin/POPSLDR/` is compiled into the ELF at
build time**; editing them requires a rebuild, and the on-card copies are never
read at runtime.

---

## Layer 3 — Boot script (`etc/boot.lua`)

`boot.lua` is the first Lua to run and sets up the environment before handing
control to the real application:

- If `argv[0]` starts with `hdd0:`, it brings up HDD: `HDD.Initialize`,
  `System.sleep(2)` (a full 2-second blocking stall — `System.sleep` takes
  **seconds**, not ms, despite its error string at `src/luasystem.cpp:774-776`),
  then mounts the boot partition to `pfs1:` and warns "NEVER USE IT FOR
  ANYTHING ELSE" (`etc/boot.lua:33-65`). It records `BOOT_HDD_MOUNT_SLOT=1` /
  `BOOT_HDD_MOUNT_PREFIX='pfs1:/'` and normalizes cwd to `pfs1:`
  (`etc/boot.lua:60-61`) because raw `pfs:` is not a real mount and breaks
  relative-path I/O and the `.pldrs` sidecar.
- Handles MX4SIO mass-slot translation, calling `System.ensureUsbMass` before
  `System.initMX4SIO` (`etc/boot.lua:87-92`).
- Loads fonts, then `require("system")` (`etc/boot.lua:178`) — which is the
  real application.

> `etc/boot.lua` **must** end with a `0x0A` newline or CI hard-fails (its runner
> is newline-sensitive). The `bin/POPSLDR/*.lua` files are exempt because they
> are embedded as raw bytes.

---

## Layer 4 — UI and scene system (`bin/POPSLDR/ui.lua` + the controller in `system.lua`)

The embedded Lua application is split into a controller (`system.lua`, ~6291
lines) and a view (`ui.lua`, ~4825 lines), plus two data modules
(`pops_profiles.lua`, `images.lua`).

### Control flow lives in `system.lua`, not `ui.lua`
`ui.lua` defines one giant `UI` table literal (`ui.lua:446` ... `return UI` at
`ui.lua:4825`) holding every scene, the transition state machine, the
notification queue, busy overlays, the cover cache, the path-editor keyboard,
modals, and input — but **no main loop**. The controller `system.lua` loads the
modules (`pops_profiles` -> `ui` -> `images`, `system.lua:2433-2526`), runs the
init sequence, and owns the single render loop at the very bottom of the file.
Device bring-up now runs inside `do_boot_init` under the welcome splash
(splash-first, commit `6b65b18`), while `LoadSettingsNonFatal` + the video-mode
apply happen pre-splash:

```
system.lua:6260  PLDR.AutoInitStartupBackends()        -- inside do_boot_init (runs UNDER the splash)
system.lua:6270  PLDR.AutoLaunchFromLaunchArgs()        -- gated by `if not boot_start_held` (6269)
system.lua:6272  PLDR.SurfaceLaunchArgsDebug()
system.lua:6333  PLDR.LoadSettingsNonFatal()            -- moved later: loads settings + applies video mode BEFORE the splash
system.lua:6354  UI.WelcomeDraw.Play(initial_scene, show_boot_credits, do_boot_init)  -- splash-first paint; do_boot_init runs under it
system.lua:6364  while true do  -- dispatch per-scene Play(), then UI.flip()
```

The loop maps `MMAIN -> UI.MainMenu.Play`, `MPROFILE -> UI.ProfileQuery.Play`,
any game scene (`UI.IsGameScene`) `-> UI.GameList.Play`, `CREDITS ->
UI.Credits.Play` (`system.lua:6364-6376`).

### Scenes
`UI.SCENES` is a numeric enum: `GUSBFAT=1`, `GSMB=3`, `GMX4SIO=4`, `GHDD=5`
(`GAPAHDD` aliases 5), `GBDMHDD=6`, `MMAIN=8`, `MPROFILE=9`, `CREDITS=10`.
`GSMB=3` is overloaded: it is the destination for the **MMCE** list as well as
conceptually "SMB". Scene changes go through `UI.SceneChange` ->
`UI.RequestScene` -> `UI.Transition.Start`, a two-phase out/in `EaseInOutCubic`
crossfade that swaps `UI.CURSCENE` at the midpoint.

### The metatable write-guard gotcha (confirmed)
Metatables are installed so that:
- writes to `UI.MainMenu.OPT` are **silently dropped** unless
  `Carousel.allowOptWrite` is true (`ui.lua:3588-3591`), and
- writes to `UI.CURSCENE` are **silently dropped** unless
  `UI.Transition.allowSceneWrite` is true (`ui.lua:3610-3612`).

The main loop itself respects this: it sets `allowSceneWrite = true` around its
own `UI.CURSCENE` assignment and clears it again (`system.lua:6186-6194`). Any
code outside the carousel/transition machinery that assigns these directly is a
no-op. Launch-arg page routing only works because it writes the `Carousel`
fields directly at module-init time (`system.lua:2479-2509`).

### Main menu and per-device entry
`UI.MainMenu.opts` is an 8-entry horizontal animated carousel (`ui.lua:3900`):
MMCE, MX4SIO, HDD (exFAT), HDD (PFS), USB, i.Link, SMB (v1), Disc (DKWDRV).
CONFIRM dispatches by OPT index inside the CONFIRM handler (`ui.lua:4148-4322`):

| OPT | Entry | Action |
|----|-------|--------|
| 1 | MMCE | `DetectMMCESlot` + `GetPS1GameLists` -> scene `GSMB` |
| 2 | MX4SIO | `InitMX4SIOPopsRoot` + `GetPS1GameLists` -> `GMX4SIO` |
| 3 | HDD (exFAT) | `InitATAPopsRoot` + `GetPS1GameLists` (BDMA `ata`) -> scene `GBDMHDD` (`ui.lua:4349`) — *implemented, validating on hardware* |
| 4 | HDD (PFS) | `LoadHDDModules` + deps + `BuildGameList` -> `GHDD` |
| 5 | USB | `ensureUsbMass` + `BuildMassGameListByType` -> `GUSBFAT` |
| 6 | i.Link | **stub** (`ui.lua:4318`) |
| 7 | SMB (v1) | **stub** (`ui.lua:4320`) |
| 8 | Disc (DKWDRV) | open DKWDRV modal |

`UI.RunBusyTask` (`ui.lua:715`) wraps every device-load worker in `pcall`
behind a saving/loading overlay; progress flows through
`MakeBusyProgressReporter` (`ui.lua:734`). The toast stack is `Notif_queue`
(MAX 2, severity colors, `ui.lua:772-841`).

### Input and navigation timing (frame-counted, NOT wall-clock)
All input flows through `UI.Pad.Listen` (`ui.lua:4440`), which reads the pad once
per vblank-paced frame, folds the d-pad bits, then resolves nav events.

**`Timer.getTime()` returns MICROSECONDS on the PS2.** The binding `lua_time`
(`src/luatimer.cpp:33`, registered as `getTime` at `:126`) returns raw
`clock() - tick` ticks with **no** division by `CLOCKS_PER_SEC`, and the EE
toolchain's `CLOCKS_PER_SEC` is `1e6`. The UI historically treated this value as
milliseconds, so every `_ms`-named gate ran ~1000× too fast. The canonical
Enceladus-ecosystem idiom is therefore **frame-counting** — the sibling launchers
(OSDMenu-Configurator, RETROLauncher) never read the wall clock for nav. Stock
Lua's `os.clock()` (seconds) is the only pre-converted time source and is
currently unused; a future `os.clock()` sweep is the proposed fix for the
remaining µs-as-ms gates (`UI.InputConfig.MIN_ACTION_MS = 220` at `ui.lua:622`,
the cover idle, and the transition/carousel timers — all parked, masked by a
per-frame `max_step` clamp so not visibly broken).

- **Nav auto-repeat is frame-counted** (`resolve_nav`, `ui.lua:4583`). `nav_fps`
  is `50` when `UI.SCR.Y >= 512` (PAL) else `60`; `NAV_DELAY_FRAMES =
  ceil(nav_fps*0.6)` (~0.6 s) and `NAV_RATE_FRAMES = ceil(nav_fps*0.2)`
  (~0.2 s, ~5/s). A per-direction `UI.Pad.NavHoldFrames` counter increments once
  per frame; the press edge fires immediately, then held **UP/DOWN** repeat while
  **LEFT/RIGHT stay edge-only** (so holding never page-jumps the carousel)
  (`ui.lua:4607-4610`). This replaced an earlier wall-clock scheme whose ms-named
  delays were compared against a µs clock and cleared every frame, so a single
  press scrolled ~5 lines.
- **Description right-stick scroll is frame-counted too** (`ui.lua:2683-2696`):
  `step_frames = ceil(_secs * fps)`, with speeds expressed in **seconds** —
  slow `0.9`, medium `0.3`, fast `0.15` (`ui.lua:2680-2682`) — tracked by
  `UI.GameList.DescScrollFrames`. The "Description scroll speed" Fast/Med/Slow
  setting now actually changes the feel (it previously gated a sub-frame µs value
  and ignored the setting).

**Analog-stick → d-pad fold is gated on real analog mode** (`ui.lua:4469-4511`).
The left stick is OR'd into the d-pad direction bits **only** when
`Pads.getMode()` reports `PAD_ANALOG` or `PAD_DUALSHOCK`, plus a per-axis
hysteresis latch (assert at `|v| > 64`, release below `40`) so a deadzone-parked
stick can't dither and edge-spam nav. `Pads.getMode()` (`lua_getmode`,
`src/luacontrols.cpp:70`) returns `padInfoMode(port, 0, PAD_MODECURID, 0)` — the
**live negotiated** mode. This is distinct from the pre-existing
`Pads.getType()` (`lua_gettype`, `src/luacontrols.cpp:9`), which reads
`PAD_MODETABLE` (a capability-table entry) and is unusable for the fold gate; the
fold mirrors OPL's `pad->buttons.mode >> 4` check (OPL `src/pad.c:201`). Without
the gate a digital pad's stale analog bytes (`getLeftStick` ≈ −127) injected a
phantom `PAD_UP|PAD_LEFT` every frame and broke up/down nav. `lua_getleft`/
`lua_getright` (`src/luacontrols.cpp:82`/`:119`) are also hardened (zero-init,
neutral `(0,0)` default, gated on `padRead`'s return) so an unread/failed frame
never yields garbage.

### Game lists
Three builders, with **non-uniform** entry encoding:
- `PLDR.GetPS1GameLists` (`system.lua:4529`) — bare `.vcd` basenames
  (MMCE/MX4SIO).
- `PLDR.BuildMassGameListByType` (`system.lua:4593`) — `"POPSroot|name"` (USB).
- `PLDR.HDD.BuildGameList` (`system.lua:4720`) — `"partition|relpath"`, mounting
  each `__.POPS`/`__.POPS0..9` partition read-only (`system.lua:4729-4742`).

`UI.GameList.Play` (`ui.lua:2029`) strips the `"X|"` prefix for display and
launches via `PLDR.RunPOPStarterGame` on CONFIRM. On `GHDD`, R2 selects an
"HDD Alt" (`full_hdd_pfs0`) mode that requires POPSTARTER itself to live on HDD
(`ui.lua:2261-2262`).

### HDD cache (opt-in)
The per-device game-list cache (USB/MMCE/MX4SIO and HDD) is an opt-in feature gated by `PLDR.GAMELIST_CACHE` (default false, `system.lua:3319`; persisted as the `GAMELIST_CACHE` setting key). `PLDR.HDD.USECACHE` (`system.lua:2048`) is a dead legacy flag. `PLDR.HDD.EnsureGameList` (`system.lua:5017`) orchestrates the always-on in-session memo (`LIST_BUILT`) plus, when `GAMELIST_CACHE` is on, a plain-text cache file `hdd_gamecache.txt` via `CreateCache`/`ReadCache`/`WipeCache` (`system.lua:4880/4927/4961`), read with a loadfile-free parser (the old `.lua` cache used `loadfile`, which is nil in the embedded runtime). When `GAMELIST_CACHE` is OFF, every device does a fresh live scan.

### Cover art (separate from the icon atlas)
`UI.CoverCache` (`ui.lua:257`, `max = 3`) is a 3-entry LRU of loaded box-art
images, refreshed after a navigation settles via `CoverCache:UpdateSelection`
(`ui.lua:326`). The refresh is gated by `UI.GameList.CoverIdleMs = 200`
(`ui.lua:2331`) compared against a `Timer.getTime` value — which is
**microseconds** (see Layer 4 › nav timing), so this "200 ms" idle is actually
~200 µs and effectively fires next frame; it is one of the parked µs-as-ms
timers awaiting an `os.clock()` sweep. Non-HDD covers are `base.png` beside the
VCD; HDD covers resolve `POPS/ART/<basename>.png` on the `hdd0:__common`
partition via `PLDR.ResolveHddPartitionReadablePath` (`BuildCoverCandidates`,
`ui.lua:175`). When a `<base>.png` cover loads it gets its own `COVER_W` inset
(`ui.lua:575`, value `232`).

**Layered placeholder (no `MISSING.png`).** When there is no live cover the box
draws two embedded assets instead of a single combined image (the old "Cover
disabled" text label is gone): `cover_default.png` is the base jewel-case, and
`cover_missing.png` is overlaid **only** when the preview is enabled but the game
has no art (`ui.lua:2577-2590`). The default art, the missing overlay, and the
decorative `frame.png` border all share the frame's aspect-corrected,
right-anchored rect so they register with the jewel-case window on both NTSC
(Y=448) and PAL (Y=512). `MISSING.png` was removed entirely (−62 KB ELF); its
bin2c rule, `EMBEDDED_RSC` entry, `embed_assets.cpp` externs/`ASSET_ENTRY`s, and
the `images.lua` registration are all gone, and there is no longer any
`default.png → MISSING.png` fallback. This cover machinery is **distinct** from
the UI chrome/glyph atlas in `images.lua`.

---

## Layer 5 — Native bindings (`src/luasystem.cpp`, `src/luaHDD.cpp`)

- `src/luasystem.cpp` provides the `System.*` bindings: file/dir I/O, cwd, ELF
  loading (three entry points, Layer 6), browser exit, embedded asset access,
  the BDM/USB/MMCE/MX4SIO lazy loaders, mount-driver queries, launch-args
  (`lua_getLaunchArgs`, `src/luasystem.cpp:1211`), and the keep-PFS-mask
  setter.
- `src/luaHDD.cpp` provides the `HDD.*` bindings (status + partition mount).

### Layer C lazy IRX loaders
Backends that are not eagerly loaded at boot are pulled in on demand:
- BDM chain: `EnsureBDM` -> `EnsureBDMFatFs` -> `EnsureUsbMass`
  (`src/luasystem.cpp:80-120`), each idempotent.
- MX4SIO: `lua_mx4sio_init` calls `EnsureUsbMass()` **before** loading
  `mx4sio_bd.irx` (`src/luasystem.cpp:1298-1330`) — maintainer rule
  (2026-05-28): MX4SIO needs the USB drivers first; USB never needs MX4SIO.
- MMCE: `EnsureMmceman` (`src/luasystem.cpp:142`) loads `mmceman.irx` on demand
  and `MarkMmcemanLoaded()` syncs the tracker.
- HDD: `Load_HDD_IRX` (`src/luaHDD.cpp:99`) loads `ps2dev9` -> `ps2atad` ->
  `ps2hdd_osd` (args `-o 4 -n 20`) -> `ps2fs` (args `-m 4 -o 10 -n 40`),
  strictly in sequence, aborting on any `id<0`/`ret==1`.

---

## Device backends and the dev9-vs-SIO2 bus model

The architectural reason the storage code is split across two files is the IOP
bus topology:

```
   IOP buses
   ---------
   dev9  (PC-card / expansion bus)          SIO2 + USB host (shared bus)
   --------------------------------         -----------------------------------------
   ps2dev9                                  sio2man
     -> ps2atad   (ATA disk)               padman  (pads)
       -> ps2hdd-osd (APA partitions)      mcman/mcserv (mc0:/mc1: standard memcards)
         -> ps2fs   (PFS -> pfsN:/)        mmceman      (mmce0:/mmce1: 3rd-party)
                                           bdm -> bdmfs_fatfs -> usbmass_bd  (USB mass)
                                                                -> mx4sio_bd (MX4SIO)
   ISOLATED in src/luaHDD.cpp,             WIRED via src/luasystem.cpp,
   loaded only when an HDD path is touched any backend on demand
```

- **HDD lives on dev9** and has its own isolated IRX file (`luaHDD.cpp`),
  loaded lazily. The boot sequence never touches the dev9/atad/hdd/fs stack.
- **Everything else shares the SIO2/USB host** and is wired through
  `luasystem.cpp`. Only `sio2man`, then `mcman`/`mcserv`/`padman` (MC always-on)
  plus `libsd`/`usbd`/`ds34*`/`audsrv` load at boot; the rest is Layer C.

### `mass:/` disambiguation (USB vs MX4SIO)
`mass:/` is ambiguous. It is resolved **not** by the argv0 hint (which maps any
`mass*` to "USB") but by a runtime BDM driver-name lookup. An in-tree IOP RPC
helper, `bdm_query` (RPC id `0xB0D10B00`, `iop/bdm_query/bdm_query.c:11-13`),
enumerates live block devices via `bdm_get_bd()`. The EE side (`FetchBdmList` +
`ClassifyMassBackend`, `src/luasystem.cpp:184-217`) classifies by driver-name
substring: `usb` -> USB, `sdc`/`mx4` -> MX4SIO, `mmce` -> MMCE. This lets the
launcher classify `mass:/` without speculatively loading `mx4sio_bd` just to
probe.

### Authoritative boot-device classification
The C hint is advisory; the authoritative classifier is Lua
`DetectBootDevice` / `ResolveBootContext` (`system.lua:1983` / `:1849`), with
precedence (`system.lua:1907-1929`): mmce > mx4sio > mass (classified via BDM
driver) > pfs|hdd > smb > host > usb > ata > apa, falling back to the C hint.

### HDD readiness and status
`HDD.GetHDDStatus` issues `fileXioDevctl("hdd0:", HDIOC_STATUS)`
(`src/luaHDD.cpp:72-78`): 0 = connected+formatted, 1 = not formatted, 2 = not
usable, 3 = not connected. `PLDR.LoadHDDModules` (`system.lua:4754`) maps these
to user notifications. Partitions mount on demand via
`MountHddPartitionTracked` (default `FIO_MT_RDONLY`, `system.lua:789-815`).

### Startup backend auto-init
`PLDR.AutoInitStartupBackends` (`system.lua:3920`, called at `:6260`) collects
configured-path targets, classifies them, and fires only the needed warm-ups:
`EnsureUsbMassReadyOnce`/`RefreshMassBackends` (USB), `InitMX4SIOPopsRoot`
(MX4SIO), `DetectMMCESlot` (MMCE), `LoadHDDModules` + `EnsureBootHddMountReady`
(HDD).

> **Divergence from MEMORY.md (intentional, do not "fix" here):** this
> BETA-13-PLAY state still has **no cold-dev9 settle** between the lazy HDD IRX
> loads. `Load_HDD_IRX` (`src/luaHDD.cpp:120-169`) and `PLDR.LoadHDDModules`
> (`system.lua:4754-4782`) load `dev9/atad/hdd/fs` back-to-back. The only
> HDD-related delay present is `System.sleep(2)` on the HDD-boot branch
> (`etc/boot.lua:47`). The "missing cold-dev9 settle" fix for "fail to load
> HDD" ships on a separate rolling branch and is **not** merged here.

---

## Layer 6 — Game launch and ELF handoff

Launch is a 3-stage chain:

```
Lua orchestration            C bindings + parent loader         BRAM child loader
(system.lua / ui.lua)   -->  (luasystem.cpp + elf.c)       -->  (loader.c, embedded loader_elf[])
```

### Lua dispatch
`PLDR.RunPOPStarterGame` (`system.lua:5653`) builds policy, partition context,
keep-slots, and `reboot_iop`, then calls `LaunchEngine` (`system.lua:5436`).
`BuildPopstarterLaunchCommand` (`system.lua:5631`) sets per-device `reboot_iop`:
default `0` (`PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER`, `system.lua:2032`);
POPSTARTER-on-HDD -> `1` (so the partition API + HDD routing fire); HDD game with
non-HDD POPSTARTER -> `0`; USB/MC/MMCE/MX4SIO POPSTARTER keep `0`.

`LaunchEngine` picks the C API: `use_partition_api = exec_partition_context
present AND reboot_iop != 0 AND System.loadELFWithPartition exists`
(`system.lua:5526`); otherwise plain `loadELF`. A `cold_external_launch` flag
(true when a partition context is present) routes prep through
`PrepareForColdExternalELFLaunch` (unmount ALL pfs, mask=0) instead of the
selective-keep `PrepareForExternalELFLaunch`.

### C bindings (`src/luasystem.cpp`)
Three launch bindings — `lua_loadELF` (`src/luasystem.cpp:974`) /
`lua_loadELFWithPartition` (`:1020`) / `lua_loadELFRebootIOP` (`:1068`):
- `System.loadELF` dispatches on `rebootIOP`.
- `System.loadELFWithPartition` **hard-requires** `reboot_iop != 0` and a
  `partition_context` shaped like `hdd?:PART:` (`src/luasystem.cpp:1067-1072`);
  the partition is passed out-of-band and must not be copied into target argv.
- All three call `ClearExecKeepPfsMask()` after the launch returns — i.e. only
  on failure, since a successful `ExecPS2` never returns. The keep-mask is
  effectively single-shot per successful launch.

### The three teardown contracts (`src/elf_loader/src/elf.c`)
`LoadELFFromFileExecPS2RebootIOPWithPartition` (`src/elf_loader/src/elf.c:618`)
is the central fork:

1. **HDD-backed** (partition is hdd/pfs AND filename is hdd/pfs, OR resolved
   path/partition is hdd/pfs) -> `ExecuteHddBackedViaEmbeddedLoader`
   (defined `elf.c:336`; dispatched at `elf.c:648`/`:656`). DKWDRV-on-HDD
   inherits this same path; the previous V3
   logic that excluded DKWDRV and used a direct
   `SifLoadElf -> SifIopReset -> ExecPS2` route black-screened on hardware
   (the documented regression, `elf.c:628-644`).
2. **BOOT.ELF / DKWDRV-on-HDD via `reboot_iop=0`** -> embedded-loader
   special-cases in `LoadELFFromFileWithPartition`: `mc?:/BOOT/BOOT.ELF`
   routes through `ExecuteViaEmbeddedLoader` (`elf.c:499-502`), and
   `is_dkwdrv_elf_path` does the same (`elf.c:516-519`).
3. **Non-HDD** (USB/MC/MMCE/MX4SIO POPSTARTER, MC DKWDRV) -> the direct path:
   `SifLoadElf` -> `unmount_pfs_slots_for_exec(build_exec_keep_mask(...))` ->
   `FlushCache` -> `SifIopReset` (loop) -> `SifIopSync` -> reload
   `rom0:SIO2MAN`/`MCMAN`/`MCSERV` -> `SifExitRpc` -> (DKWDRV argv0 synthesis,
   `elf.c:691-697`) -> `ExecPS2` (`elf.c:645-700`).

### The embedded loader handoff (`ExecuteViaEmbeddedLoader`, `elf.c:397`)
Validates the `loader_elf` ELF magic, wipes BRAM (0x84000-0x100000), writes the
`EmbeddedLoaderMetadata` struct to the fixed address `0x00083C00` with magic
`'POPL'` (`0x504F504C`) and version 1 (`elf.c:159-170`), copies the child's
`PT_LOAD` segments into BRAM, then tears down
(`SifExitIopHeap`/`SifExitRpc`/`SifExitCmd`/`FlushCache(0)`/`FlushCache(2)`) and
`ExecPS2`'s the child entry. The metadata carries `partition_context[128]` +
`load_path[256]`.

### The BRAM child loader (`src/elf_loader/src/loader/src/loader.c:280`)
Reads the metadata from `0x00083C00`, reconstructs/synthesizes target argv, then
branches **three ways** before `ExecPS2` (`loader.c:373-427`):
- **(a) filexio-direct-load** (non-hdd-context pfs/hdd `load_path`):
  `SifExitRpc` only, then `ExecPS2` (`loader.c:373-379`).
- **(b) hdd-partition-context**: unmount the pfs prefix, `SifExitRpc` +
  `SifExitCmd`, `ExecPS2` (`loader.c:381-403`; `SifExitRpc` :396,
  `SifExitCmd` :397, `ExecPS2` :401).
- **(c) generic**: `SifExitRpc` only and **intentionally NO `SifExitCmd`**
  (`loader.c:404-427`).

> The absence of `SifExitCmd` on branch (c) is the single remaining pre-ExecPS2
> difference between the hardware-pass and hardware-fail states. The comment at
> `loader.c:405-413` documents that an "align with reference loaders" change
> which added `SifExitCmd` here caused a black-screen regression. See
> `PRESERVATION_CONTRACTS.md`.

### Keep-PFS mask
A 4-bit mask (slots 0-3) controls which pfs mounts survive the pre-exec
unmount. `PrepareForExternalELFLaunch` (`system.lua:1120-1148`) computes the
keep set from the exec path's pfs slot plus the boot pfs slots and calls
`System.setExecKeepPfsMask`. The C side (`elf.c:33-45`, `:97-112`) masks
`&0x0F` and `unmount_pfs_slots_for_exec` preserves masked slots. HDD-booted
POPSLoader's `pfs1:` (`BOOT_HDD_MOUNT_SLOT=1`) is the slot that must survive
BOOT.ELF/exit; forgetting it (or using the cold-prep path that forces mask=0)
leaves `fileXio` holding the pfs1: RPC server thread and `SifIopReset` hangs.

### Pre-exec validation gate
`ValidateHddPopstarterExecGate` (`system.lua:1655-1725`) resolves and mounts the
target partition and probes that the exec-path file exists before allowing the
launch; failure routes to `BlockLaunchFailure` with a diagnostic screen. A
non-strict fallback (`ResolveFallbackMountedPfsExecPath`, `system.lua:1727`) can
reconstruct a partition-aware exec path from a bare `pfsN:/` path when the
partition context could not be derived.

### Auto-launch (NHDDL `-page`/`-game`)
`PLDR.AutoLaunchFromLaunchArgs` (`system.lua:6139`, called at `:6270`) requires
**both** `-page` and `-game`, maps the page to a scene + game-location root,
runs that backend's lazy init, then calls `PLDR.RunPOPStarterGame` (same engine).
On success `ExecPS2` never returns, short-circuiting the normal UI boot.

---

## Data and config layer

### POPS "profiles" (`bin/POPSLDR/pops_profiles.lua`)
A "profile" is **not** a per-game tuning record. `PLDR.PROFILES`
(`pops_profiles.lua:26-91`) is a 16-entry ordered list of candidate
`POPSTARTER.ELF` **locations** (`{ELF=path, DESC=text}`) across same-folder, HDD
pfs, USB mass, MX4SIO, MMCE, and MC layouts. `DEFAULT_PROFILE = 1`
(`pops_profiles.lua:8-9`) is the same-folder ELF and seeds
`PLDR.POPSTARTER_PATH`. An orthogonal selection mode (`PROFILE_DEFAULT` vs
`CUSTOM`, `system.lua:667-732`) decides whether the profile's ELF or a typed
override wins. In `PROFILE_DEFAULT` mode the persisted `POPSTARTER_PATH=` line is
intentionally empty (`system.lua:3077-3082`).

### Image atlas (`bin/POPSLDR/images.lua`)
`IMG_REGISTRATIONS` (`images.lua:11-36`) is 25 `{key, filename}` pairs (device
icons, backgrounds, splash layers, button/d-pad glyphs, the jewel-case `frame`,
plus `default`, `cover_default`, and `cover_missing`). The `missing` key was
removed alongside `MISSING.png`. The `IMG` table lazy-loads each PNG from an
**embedded** blob via `System.getEmbeddedAsset` -> `Graphics.loadImageEmbedded`,
caches it, and records permanent failures in `IMG_FAILED`
(`__index` at `images.lua:50-79`). `IMG_FALLBACKS` (`images.lua:46`) is now an
**empty table** — there are no key-to-key fallback edges anymore. This is the UI
chrome/glyph atlas, not per-game box art (covers are `UI.CoverCache`, Layer 4).

### Launch arguments
Parsed C-side (`parseLaunchArgs`, `src/main.cpp:198`), normalized in Lua: `NormalizeLaunchPage`
(`system.lua:2204-2247`) folds page kinds (ata/pfs/apa/hdd -> HDD, usb/mass ->
USB, mmce -> MMCE, mx4sio/mx4/sdc -> MX4SIO, etc.) into `PLDR.LAUNCH_ARGS`.
`-page` auto-navigates the carousel via `page_to_opt = {MMCE=1, MX4SIO=2,
HDD=4, USB=5, SMB=7}` (`system.lua:2481-2509`); HDD maps to the PFS page (4),
and unimplemented pages (BDMA/i.Link) are deliberately not routed.

### On-disk settings (`.pldrs`)
Plain KEY=VALUE text with **20 keys** (`EncodeSettings`, `system.lua:3072-3102`):
`PROFILE`, `POPSTARTER_PATH`, `POPSTARTER_MODE`, `BDMA`, `DKWDRV_PATH`,
`STRICT_HDD_PREEXEC_GATE`, `VIDEO_STANDARD`, `HIDE_TEXT`, `KEYBOARD_LAYOUT`,
`BOOT_PAGE`, `MULTIDISC_COLLAPSE`, `GLOBAL_HIDE`, `POPSTARTER_MC_FOLDER`,
`HIDDEN_DEVICES`, `SHOW_DETAILS`, `DETAILS_ALIGN`, `GAMELIST_CACHE`, `BOOT_SOUND`
(default on; gates the splash ADPCM chime), `OVERSCAN` (CRT inset permille,
default `0`; see the overscan note below), `DESC_SCROLL_SPEED`. STATE.md is
canonical for what each key means and its UI surface.
Location is the **per-device** sidecar `APP_DIR/.pldrs`, preferred for every
device — **including HDD installs**, which now persist on the HDD boot partition
itself via the `PLDR.HDD.EnsureBootPartitionWritable` RW mount take-over
(`system.lua:2159`): the launcher's boot pfs slot is unmounted and remounted
read-write in place ("own your mount", the OPL pattern), so the sidecar is
written on-HDD. There is **no `mc0:` fallback for an HDD-cwd install** —
single-device parity; `mc0:/POPSTARTER/.pldrs` remains only as a legacy fallback
when no per-device sidecar can be computed. (This supersedes the old PR #466
carve-out — "HDD saves to MC because the bundled `ps2hdd-osd.irx` can't reliably
write PFS"; see `STATE.md > Settings (single-device parity)` and
`STATE.md > Preservation Contracts`.)
`LoadSettingsNonFatal` (`system.lua:3301`) resolves the path and performs the
legacy MC->sidecar migration; `SaveSettingsAtomic` (`system.lua:3262`) writes via
`WriteAtomic` (tmp + rename, `system.lua:2663-2693`). Edits are staged as UI
drafts and committed transactionally by `PLDR.CommitSettingsChanges`
(`system.lua:3540`), which snapshots prior state and rolls back on save or
BDMA-apply failure.

### Overscan (OPL-style render-inset)
A single render-coordinate inset adapts OPL's `rmSetOverscan` to this UI at the
one graphics chokepoint. `src/graphics.cpp` keeps a `g_overscan` permille
(`graphics.cpp:1135`); `recompute_overscan` (`:1140`) derives a uniform
center-scaling transform exposed as the inline `OVX(x)`/`OVY(y)`
(`graphics.cpp:1165-1166`), and **every** `gsKit_prim_*` draw site is wrapped in
`OVX()`/`OVY()` so the whole UI scales toward screen center by the overscan
amount. The math is identical to OPL (`margin = W*permille/2000` per edge,
`scale = 1 - permille/1000`); at permille `0` the transform is the **identity**,
so the feature is inert by default. `set_overscan`/`get_overscan`
(`graphics.cpp:1155`/`:1163`) are bound to Lua as `Screen.setOverscan` /
`Screen.getOverscan` (`src/luaScreen.cpp:64`/`:71`, registered at `:162-163`).
The Settings entry "Overscan (CRT inset)" (`ui.lua:3632`) is a live ±5-step
adjuster (clamped 0..100) that previews immediately and discards on cancel;
ResetDefaults restores `0` (`ui.lua:3356-3358`); persistence is the `OVERSCAN`
`.pldrs` key.

---

## Layer 7 — Build / embed / CI pipeline

### Asset embedding
The top-level `Makefile` builds a single packed EE ELF inside the pinned
`ps2dev/ps2dev:v2.0.0` Docker toolchain. Every Lua/PNG/IRX/icon/ADP blob is
turned into a `.c` file by ps2sdk's `bin2c` (`BIN2S = $(PS2SDK)/bin/bin2c`,
`Makefile:67`), exposing `<symbol>[]` + `size_<symbol>`; those compile to `.o`
and link into the ELF (`EMBEDDED_RSC`, `Makefile:96-105`). The embedded IRX
object list is at `Makefile:89-94` (usbd, audsrv, bdm, bdmfs_fatfs, usbmass_bd,
cdfs, ds34bt, ds34usb, ps2dev9, ps2atad, ps2hdd-osd, ps2fs, mmceman, mx4sio_bd,
bdm_query). At runtime, `embed_assets.cpp::embedded_get` (`src/embed_assets.cpp:195`)
resolves blobs by normalizing the request (`embed:/` / `./` / leading-slash
stripping, `IMG/` -> `POPSLDR/IMG/`) and looking the key up in the single
`g_embedded_assets[]` table (`embed_assets.cpp:93`).

> **The embed table is NOT auto-globbed — adding/removing an embedded asset is
> 3 explicit, hand-coordinated places** (a 4th if you count the extern decl).
> Miss one and it silently fails to resolve (or fails to link):
> 1. **`Makefile`** — a `bin2c` rule producing `asset_<name>.c`, plus the matching
>    `asset_<name>.o` in `EMBEDDED_RSC` (`Makefile:96-105`).
> 2. **`src/embed_assets.cpp`** — an `extern` decl for the symbol, then an
>    `ASSET_ENTRY` in **both** halves of `g_embedded_assets[]`: the bare-name row
>    (e.g. `"frame.png"`) and the `POPSLDR/IMG/`-prefixed row (e.g.
>    `"POPSLDR/IMG/frame.png"`).
> 3. **`bin/POPSLDR/images.lua`** — an `IMG_REGISTRATIONS` `{key, filename}` pair;
>    the lookup uses the **bare** filename.
>
> This is exactly the path the `MISSING.png` removal (−62 KB ELF) and the
> `cover_default.png` / `cover_missing.png` additions exercised: each touched all
> three places. There is no machine-checked manifest tying them together.

### Two-stage child loader build
- **Stage 1** (`src/elf_loader/src/loader/Makefile`) builds a tiny standalone
  `bin/loader.elf` linked into BIOS memory via `linkfile`.
- **Stage 2** (`src/elf_loader/Makefile`) bin2c-embeds `loader.elf` into
  `loader.c` (symbol `loader_elf`) and archives it into
  `libcustom-elf-loader.a`, consumed by the main link (`Makefile:46`).
- `make elfloader` force-regenerates the whole chain
  (`cleanbin` + clean/all in both sub-makes). CI runs
  `make clean elfloader all`.

### Final packaging
`all` (`Makefile:115`) builds `bin/enceladus.elf` (`EE_BIN`), then the
`$(EE_BIN_PKD): $(EE_BIN)` rule strips it and runs `ps2-packer` to produce
`bin/POPSLOADER.ELF` (`Makefile:118-120`).

### CI/CD
Two build workflows duplicate most logic inline:
- `compilation.yml` — runs on all branches/tags/PRs/dispatch; runs the now-LIVE
  embedded-Lua syntax gate (`luac5.4 -p`, see below), builds, and packages
  `POPSLOADER.zip` as an artifact (no GitHub release).
- `rolling-release.yml` — runs on push to `BETA-13-PLAY` (the active rolling
  branch; repiped from `BETA-12-PLAY`) and PR events; bundles the ELF + full
  git-tracked source and force-updates a single `rolling-release` prerelease via
  the GitHub API.
- `opencode.yml` — an `/oc` comment bot (DeepSeek), outside the build/launch
  path.

Both build workflows enforce embed-identity gates:
- **String markers** — `Exec path:`, `PrepareForColdExternalELFLaunch`,
  `BOOT.ELF launch failed` must be grep-found in `bin/enceladus.elf`. They are
  guaranteed present by `__attribute__((used))` CI marker constants
  (`src/main.cpp:39-41`).
- **Loader staleness/parity** — `loader.c` must exist; if its timestamp is not
  newer than the loader source, CI re-runs bin2c on the freshly built
  `loader.elf` and `cmp -s` requires byte-for-byte equality.
- **Lua validation** — required `.lua` files must exist, `etc/boot.lua` must end
  with `0x0A`, and the embedded-Lua **syntax gate is now LIVE**: the workflows
  `apk add lua5.4` and run `luac5.4 -p` on `bin/POPSLDR/*.lua` + `etc/boot.lua`,
  hard-failing on a syntax error. It previously **silently no-op'd** because the
  pinned ps2dev image shipped no `luac`. It catches **SYNTAX only** — runtime
  nil-global / type / **load-order** errors stay invisible to CI (the `d4b04be`
  load-order boot brick was exactly such a case). See `STATE.md > CI / release`.

`BUILD_INFO.txt` is generated fresh in CI (7-char commit SHA + UTC stamp), not
committed; the runtime UI reads it (`ui.lua:3413-3465`) and shows the stamp on
screen so hardware testers can confirm the exact artifact.

---

## Preservation contracts

Several teardown details across `elf.c` and `loader.c` are load-bearing and each
maps to a specific hardware regression (D-10, D-15, U-10). Do not change them
without a hardware-verified replacement. The HDD boot-partition RW take-over
(`PLDR.HDD.EnsureBootPartitionWritable`, `system.lua:2159`) is also now
load-bearing — it owns the boot pfs slot for HDD settings save and HDD in-app
`.hide`, so any launch-path / mount change must not break it.

The authoritative list — including the "no `SifExitCmd` on the generic child
branch", the partition-aware HDD route, the keep-PFS-mask handling for `pfs1:`,
the BRAM metadata address/magic coupling, and the `EnsureBootPartitionWritable`
take-over — lives in **`PRESERVATION_CONTRACTS.md`**; see also
**`STATE.md > Preservation Contracts`** and **`STATE.md > Behavioral Invariants`**.
