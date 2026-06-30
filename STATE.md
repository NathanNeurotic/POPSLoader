Last updated: 2026-06-21 (BETA-13 rolling candidate; body reflects the 2026-06-20/21 input/nav + cover-art + overscan + HDD-scan-slot session on top of the 2026-06 HDD-RW take-over / PAL-512 / BDMA-folder work). Released line: **BETA-12** (2026-06-18; BETA-11 was 2026-06-15). Active dev branch is now **`BETA-13-PLAY`** (created off `BETA-12-PLAY`; **`BETA-12-PLAY` is frozen/archival**); `rolling-release.yml` publishes from `BETA-13-PLAY`. BETA-13 is the in-progress rolling candidate — **not yet cut**. Tip moves per push; see `git log`.

# STATE

This is the **canonical status doc** for POPSLoader. Current runtime state, behavioral invariants, preservation contracts, known issues, and hardware-verification status all live **here**; the other docs (README, AGENTS, CONTRIBUTING, ROADMAP, ROLLING_NOTES) point here instead of duplicating, so this is the one place to keep current. `QA_REGRESSION_MATRIX.md` is the detailed run ledger.

## Project Identity
POPSLoader is a PS2 launcher for POPStarter built on Enceladus runtime pieces, with behavior primarily orchestrated by embedded Lua modules (`system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`). The Lua is bin2c'd into the EE ELF at build time — so a *runtime* Lua error (nil global, type error, **load-order** error) is invisible to `luac -p` and to CI, and only surfaces on real PS2 / PCSX2.

## Repo-Verified Runtime State

### Boot and runtime
- Boot/runtime uses embedded Lua scripts (`etc/boot.lua` → `system.lua` → `ui.lua`).
- `bin/POPSLDR/IMG/default.png` is an **optional legacy cover override** (Makefile `OPTIONAL_EMBEDDED_RSC`, gated on `$(wildcard …/default.png)`): when absent from the checkout it is simply not embedded, and there is **no fallback** — `IMG_FALLBACKS` is empty (`images.lua`). The game-list cover box uses the now-required embedded `cover_default.png` (+ `cover_missing.png` overlay), not `default.png`, for its no-cover / preview-off states. **`MISSING.png` has been removed** (no longer embedded, registered, or referenced anywhere — see Cover art).
- `_ps2sdk_memory_init()` in `src/main.cpp` performs an IOP reset before `main()` runs (`RESET_IOP=1` Makefile default); it also runs `SifExitRpc()`, fresh `SifInitRpc(0)`, and `fileXioExit()` first to detach any inherited RPC client from a parent that left `fileXio` loaded (e.g. wLaunchELF). Architecture/revert history: `docs/archive/LAUNCH_HYGIENE.md`.
- **`Timer.getTime()` returns MICROSECONDS on PS2, not milliseconds.** It is the raw `clock() - tick` delta (`src/luatimer.cpp` `lua_time`); `CLOCKS_PER_SEC` is `1e6` on the EE toolchain. The canonical Enceladus idiom for any per-frame rate-limit (nav auto-repeat, description scroll) is therefore **frame-counting** (one counter increment per vblank-paced frame), not reading the wall clock. `os.clock()` (stock Lua, returns **seconds**) is the only pre-converted Lua time source and is currently unused. With the µs-as-ms sweep complete (`9c3f64f` + `a8e61f3`), the remaining time-based UI sites are unit-correct or frame-paced: PathEditor key-flash + caret blink and the launch-watchdog label divide to real ms (`Timer.getTime()/1000`), the scene/boot fades and carousel slide advance a fixed step per vblank-paced frame, and the dead `MIN_ACTION_MS` action debounce was removed (rising-edge `pressed = GPAD & ~OLDPAD` is the real gate). Only cosmetic/inert sites (busy-overlay throttle, saving marquee, disabled debug log) intentionally remain on the raw clock. See Known Open Work #4.

### Settings (single-device parity)
- Settings persist at `PLDR.SETTINGS_PATH`, resolved at load time by `LoadSettingsNonFatal`: the **per-device sidecar** `APP_DIR_LOCAL/.pldrs` (the directory POPSLOADER.ELF lives in) is preferred for every device.
- **HDD installs now save settings ON THE HDD boot partition itself.** `PLDR.HDD.EnsureBootPartitionWritable` takes over the launcher's boot pfs mount — explicitly unmounts it, then remounts the **same partition read-write at the same pfs slot** ("own your mount", the OPL pattern) — so the `.pldrs` sidecar is written on-HDD. **There is no `mc0:` fallback for an HDD-cwd install.** Single-device parity with USB / MX4SIO / MMCE.
  - This **supersedes** the old PR #466 design ("HDD saves to `mc0:/POPSTARTER/.pldrs` because the bundled `ps2hdd-osd.irx` can't reliably write PFS"). That premise no longer holds.
  - STATUS: implemented, boots on PCSX2; provato confirmed the HDD is **RW-writable on real hardware**; the full settings flow is still validating on hardware (not yet broadly hardware-confirmed).
- `mc0:/POPSTARTER/.pldrs` remains only as a legacy fallback when no sidecar can be computed.
- Settings edits are staged and committed on Settings/Profile confirm/leave.
- Persisted settings — **22 keys** (`EncodeSettings`, `system.lua`): `PROFILE`, `POPSTARTER_PATH`, `POPSTARTER_MODE`, `BDMA`, `DKWDRV_PATH`, `STRICT_HDD_PREEXEC_GATE`, `VIDEO_STANDARD`, `HIDE_TEXT`, `KEYBOARD_LAYOUT`, `BOOT_PAGE`, `MULTIDISC_COLLAPSE`, `GLOBAL_HIDE`, `POPSTARTER_MC_FOLDER`, `HIDDEN_DEVICES`, `SHOW_DETAILS`, `DETAILS_ALIGN`, `ART_LOCATION`, `HDD_FS`, `GAMELIST_CACHE`, `BOOT_SOUND`, `OVERSCAN`, `SMB_MODULES` — then the SMB connection block (`SMB_*`) is appended after these by `SmbAppendLines`. (`ART_LOCATION` is new this build; `HDD_FS` and `SMB_MODULES` are also persisted and were missing from the older 19-key count.)

### Per-game hide layer
- A `<name>.hide` sidecar next to the game's `.VCD` marks it hidden (read for free during the scan; tracked in `PLDR.HIDDEN`). **L3** toggles hide/show on the selected game. To unhide, set *Settings → Game List → Hidden games* to **Visible (manage)**, which shows hidden games dimmed so L3 can toggle them back (**Hidden** filters them out). **R3** is the in-list shortcut for that setting: on a device game list it flips `GLOBAL_HIDE` (persisted via `SaveSettingsAtomic`) and rebuilds the list in place (reusing the R1 refresh path) so the new filter applies immediately — revealing hidden games dimmed (then L3 unhides) or re-hiding them.
- In-app hide writes work on **every device page** — USB / MX4SIO / MMCE / Memory Card **and the internal HDD**. On HDD the `.hide` is written via the RW mount take-over (`EnsureBootPartitionWritable`); the "add the `.hide` file from a PC" message is now only a write-*failure* fallback, not the primary path.
- STATUS: implemented, boots on PCSX2, validating on hardware.

### BDMA mode / POPSTARTER memory-card folder
- BDMA mode (mass-storage backend) keys: `FAT32` / `USBEXFAT` / `MX4SIO` / `MMCE` / `ATA` (internal-HDD exFAT, alias `HDDEXFAT`). The installed mode is recorded in a marker file in the POPSTARTER pack folder: **`bdma_mode.txt`** (plain-text mode key). Renamed 2026-06-17 from `.pldr_bdma_mode` for a clearer, shared name (mSAS reads the same file); the legacy `.pldr_bdma_mode` / `.pldr_bdma` names are still **read** for back-compat, and the current name is always written.
- **POPSTARTER Memory Card Folder toggle** (Settings, below Discard): disabling it **deletes `mc:/POPSTARTER`** (destructive-action confirm). **BDMA ⟺ folder interlock**: the folder cannot be disabled while BDMA mode is on, and BDMA cannot be enabled while the folder is off.

### Video standard
- Video Standard: **Auto** (default — matches the console region) / NTSC / PAL. On PAL the UI now renders **natively at 640×512** so it fills the screen (no letterbox); NTSC is 640×448. The display-change confirm prompt **auto-reverts** if not confirmed (like OPL); hold START during boot to skip past a bad video mode; the boot screen is centered. STATUS: PAL hardware validation pending.

### Input / navigation (`UI.Pad.Listen` in `ui.lua`)
- **Nav auto-repeat is frame-counted, not wall-clock.** In `resolve_nav`: `nav_fps = (UI.SCR.Y >= 512) and 50 or 60`; `NAV_DELAY_FRAMES = ceil(nav_fps*0.6)` (~0.6 s); `NAV_RATE_FRAMES = ceil(nav_fps*0.2)` (~5/s). A per-direction `UI.Pad.NavHoldFrames` counter increments once per frame; a press fires immediately, held UP/DOWN repeat after the delay then at the rate, LEFT/RIGHT are edge-only. This replaced an earlier wall-clock scheme that read `Timer.getTime()` as ms (µs in reality) and flew (one click ≈ 5 lines). CONFIRMED on hardware (oldman63).
- **Analog-stick → d-pad fold is gated on real analog mode + per-axis hysteresis.** The left stick is folded into the d-pad direction bits (`UI.Pad.StickV`/`StickH` latches) **only** when `Pads.getMode()` reports `PAD_ANALOG` or `PAD_DUALSHOCK`; the latch asserts at `|v| > 64`, releases at `< 40`, so a deadzone-parked stick can't dither. When not analog this frame the latches are cleared. The new C binding `Pads.getMode()` (`src/luacontrols.cpp` `lua_getmode`) returns the **live negotiated** mode via `padInfoMode(port, 0, PAD_MODECURID, 0)`; the pre-existing `Pads.getType()` (`lua_gettype`, `PAD_MODETABLE`) reads a capability-table entry and is **not** usable for this gate. Mirrors OPL `src/pad.c`. WHY: an ungated fold injected a phantom −127 on a digital pad and broke up/down nav. CONFIRMED on hardware (oldman63).
- **Description right-stick scroll is frame-counted** (`UI.GameList.DescScrollFrames`): one step every `ceil(_secs * fps)` frames, fixed at the **Fast** pace (`_secs` **0.15 s**, ~7 lines/sec). The Fast/Medium/Slow speed setting was removed (provato: Fast is best); the frame-counting fix it shipped with stands.

### Boot sound
- **Boot sound On/Off** setting (default **On**; `PLDR.BOOT_SOUND`, `system.lua`) gates the splash chime (`embed:boot.adp`, played in `ui.lua`'s `TryBootSound`). Plumbed through the full settings chain incl. `CommitSettingsChanges` (`next_boot_sound` → `next_state.boot_sound`) and persisted as the `BOOT_SOUND=` key. CONFIRMED saving + surviving reboot on hardware (oldman63).

### Overscan (CRT inset)
- OPL-style render-coordinate inset: `Screen.setOverscan(permille)` / `getOverscan()` (`src/luaScreen.cpp`) drive a C-core scale-toward-center transform (`OVX()`/`OVY()`, `set_overscan`/`get_overscan` in `src/graphics.cpp`) applied at the single `gsKit_prim_*` draw chokepoint; the math is identical to OPL `rmSetOverscan` and is the **identity at permille 0**, so it is inert by default. Exposed as the *Overscan (CRT inset)* live adjuster in Settings (±5 step, live preview, discard restores), persisted as `OVERSCAN=`. STATUS: not yet CRT/HW-eyeballed.

### Boot-context resolution
- Single canonical resolver `ResolveBootContext()` in `system.lua` combines the C-side argv[0] classification hint (`main.cpp detectBootDeviceHintFromArgv0()`, via `System.getBootDeviceHint()`), Lua-side prefix matching (`mass`/`mmce`/`mx4sio`/`pfs`/`hdd`/`smb`/`host`/`usb`/`ata`/`apa`), and the mx4sio `mass:` fix (`classify_mass_boot` via BDM driver lookup + `.boot_mx4sio`/`.boot_usb` markers). `DetectBootDevice()`, `PLDR.GetBootContext()`, `PLDR.GetBootKind()`, `ComputeSettingsSidecarPath` all read this one resolver.

### Launch arguments (NHDDL-style)
- `parseLaunchArgs()` in `main.cpp` recognizes `-page=*`, `-mode=*` (NHDDL alias), `-game=*`, `-debug`; exposed via `System.getLaunchArgs()` and normalized into `PLDR.LAUNCH_ARGS = {page, page_raw, game, debug}`.
- `-page=` (and `-mode=` alias) drives carousel auto-nav via `NormalizeLaunchPage`: `ata`/`ata0`/`ataN` → the exFAT page (opt 3, `GBDMHDD`); `hdd`/`hdd0`/`apa`/`apa0`/any `pfs` → the PFS page (opt 4); `mmce`→1, `mx4sio`→2, `usb`→5; bare `bdma` is a no-op page value. `-game=` triggers `PLDR.AutoLaunchFromLaunchArgs()` (requires `-page=`; HDD game format `PARTITION|relpath`, USB/MX4SIO/MMCE format `FILE.VCD`; falls through to the menu with an error toast on failure); `-debug` queues a boot-context toast (`PLDR.SurfaceLaunchArgsDebug()`).

### Backend init / runtime
- Startup backend auto-init uses boot path, configured executable paths, and selected profile. HDD startup targets run `PLDR.LoadHDDModules()`.
- USB vs MX4SIO classification is by mount-driver identity: `mass:/` boots stay USB-only unless explicit MX4SIO evidence (`mx4sio:/` prefix, `sdc`/`mx4` ioctl, or `.boot_mx4sio`). `mx4sio_bd.irx` loads only on that evidence; `usbmass_bd.irx` always loads first (mx4sio depends on it). Runtime device access is not gated by the old device-lock system (the `canEnterDevice`/`setDeviceLock` subsystem was removed).

### Launch paths (current routing)
- **HDD POPSTARTER on HDD partition** (D-10): `LoadELFFromFileExecPS2RebootIOPWithPartition` → `ExecuteHddBackedViaEmbeddedLoader` → child loader `is_hdd_partition_context` branch (fileXioUmount + SifExitRpc/Cmd + ExecPS2, no IOP reset). Byte-identical to the 2026-05-22 B2 hardware-passing fix at commit `4ae6679`.
- **Non-HDD POPSTARTER + HDD game** (D-15): same route with the boot partition's PFS slot preserved via keep_mask.
- **DKWDRV from MC**: reboot variant direct path, IOP reset + reload `SIO2MAN/MCMAN/MCSERV` + ExecPS2 with synthesized argv0.
- **DKWDRV from HDD custom path** (FIXED, PRs #486/#487): partition-aware path + live pfs-slot scan.
- **BOOT.ELF from USB-booted POPSLoader** (V2 route at `d23520a`): non-reboot variant → BOOT.ELF special-case → `ExecuteViaEmbeddedLoader` non-HDD branch (no IOP reset).
- **BOOT.ELF from HDD-booted POPSLoader** (U-10, FIXED): launches with `reboot_iop=0` via PR #479.
- **`POPSTARTER.ELF` resolved per device at launch** (`PLDR.ResolveLaunchPopstarterPath`, `system.lua`). REMOVABLE devices (USB / internal-exFAT-ATA / MX4SIO / MMCE), in order: **1.** an explicit user-configured **absolute custom path** (the "POPSTARTER Path" setting, or an absolute Profile selection) when it resolves; **2.** the game's own **`<device>:/POPS/POPSTARTER.ELF`** when it exists; **3.** **`POPSTARTER.ELF` in the launcher's own folder (cwd)**; **4.** the `mc0:`→`mc1:`/POPSTARTER + configured-default fallback net. The device and cwd steps are existence-gated, so a device with no `POPSTARTER.ELF` simply falls through — this lets a **per-device build** be used without forcing it (e.g. a USB-delay POPSTARTER dropped in the USB drive's `POPS/` folder serves USB games, a faster build elsewhere). INTERNAL-PFS HDD (APA), in order: **1.** custom; **2.** **`hdd0:__common/POPS/POPSTARTER.ELF`**; **3.** cwd / boot-sidecar; **4.** mc net — the `__common` step resolves through the **same partition machinery as the shipped `__common` profile** (D-10/D-15 partition-context + embedded-loader path), so HDD launch mechanics are preserved. This **supersedes** the earlier "prefer the device-local copy first" precedence (`ee4cba0`): an explicit custom path now wins, and Profiles act as presets (an absolute Profile selection *is* the step-1 custom path). Landed this session (`28e40bb` → `9f2477c` device-before-cwd flip → `26bb06c` APA `__common`); **not yet hardware-tested**.

### Main menu feature status
- Implemented: `MMCE`, `MX4SIO`, `HDD (PFS)`, `USB`, `Disc (DKWDRV)`, **`HDD (exFAT)`** (BDMA Mode `ATA`; scans/launches as a `mass:` device via `ata_bd.irx` + R3Z3N's ATA BDM Assault launch drivers — implemented `df2eb9d`, CI/Rolling green, **validating on hardware**), and **`SMB (v1)`** (network game browsing: scene `GSMBNET`, main-menu OPT==7; settings + an "SMB modules" install toggle + lazy connect/browse/launch via OPL's netman recipe; argv0 selector `smb:/POPS/SB.<name>.ELF`; disconnect-on-leave; blank-share `GETSHARELIST` picker; in-game `IPCONFIG.DAT`/`SMBCONFIG.DAT` backfilled on save — implemented this session, commits `ee4d454`/`121823d`/`0cf7f81`/`43033dc`/`68f9ed5`/`154c872`/`5d0e302`/`f5ac26c`/`1169dbc`, CI/Rolling green, **validating on hardware**; IP addressing only — NetBIOS deferred). Not implemented: `ILINK`.
- **Carousel device visibility** (Settings → Carousel Devices): a Shown/Hidden toggle per carousel device lets the user hide entries they don't use (e.g. the not-implemented stubs). Persisted as `HIDDEN_DEVICES` (CSV of stable device keys; all shown by default; a guard keeps ≥1 visible). The carousel nav/render skip hidden entries with no gaps; `UI.MainMenu.OPT` stays the real opts index so the launch dispatch is unchanged (with nothing hidden, behavior is identical). STATUS: implemented, validating on PCSX2/hardware.

### Exit handoff
- Exit modal exposes OSDSYS, Cancel, BOOT.ELF. BOOT.ELF lookup order: `mc0:/BOOT/BOOT.ELF`, `mc1:/BOOT/BOOT.ELF`.

### Cover art (game-list preview box, `ui.lua`)
- A live cover is a `<name>.png` sidecar; it draws into its own `COVER_W` inset. `BuildCoverCandidates` (`ui.lua:190`) builds the candidate list. On **removable** devices the lookup folder is **user-selectable** (*Settings → Game List → Cover/details folder*, key `ART_LOCATION`, default `pops_art`): **`POPS/ART`** tries `<device>:/POPS/ART/<game>.png` first; **`POPS`** uses the game's own `POPS/` folder beside the `.VCD`; **`ART`** tries a top-level `<device>:/ART/<game>.png`. The game's own `POPS/` folder is **always also appended** as a final fallback, so art beside the `.VCD` never stops showing. On **HDD/PFS** the path is fixed: `hdd0:__common/POPS/ART/<game>.png` (mounted from the `__common` partition). Within each folder the **disc-marker-stripped name is tried first** (so one art file serves every disc of a multi-disc game), then the exact per-disc `<full-name>.png`. The matching **`<name>.txt` details sidecar rides the same candidate list** (each `.png` → `.txt`). `CoverCache:GetOrLoad` (`ui.lua:344`) no longer pre-probes existence with `doesFileExist`/`open()`; it lets `Graphics.loadImage` (`fopen`) open the file directly, because a nested `open()` of `POPS/ART/<file>` can miss on some BDM filesystems where the loader's `fopen` reads it fine (the `.txt` sidecar still reads via `open()`, so a details file under `POPS/ART` is bound by that nested-open behavior).
- **Placeholder is a two-asset layer**, both embedded: `bin/POPSLDR/IMG/cover_default.png` (base) + `cover_missing.png` (overlay). Cover preview **disabled** (Square) → `cover_default.png` only (the old "Cover disabled" **text** label is gone). Preview **enabled** but the game has **no cover** → `cover_default.png` with `cover_missing.png` drawn on top. The default cover, the missing overlay, and `frame.png` all share the frame's aspect-corrected, right-anchored rect so they register with the jewel-case window on **both NTSC and PAL** (HW eyeball still pending).
- **`MISSING.png` is removed entirely** (ELF 1802052 → 1739428, ~−62 KB): dropped from the Makefile (`BIN2S` rule + `EMBEDDED_RSC`), `src/embed_assets.cpp` (extern + both bare-name and `POPSLDR/IMG/`-prefixed `ASSET_ENTRY`s + the `default.png`→MISSING fallback), and `images.lua` (registration + the `IMG_FALLBACKS` default). It was also the (never-hit, nil-safe) `ResolveIcon` icon fallback, dropped too. Any reference to `MISSING.png` as the cover placeholder is stale.

### Embedded-asset mechanism
- Adding or removing an embedded asset is **3 explicit coordinated places** (it is NOT auto-glob): (a) **Makefile** — a `BIN2S` rule plus the `.o` in `EMBEDDED_RSC` (or `OPTIONAL_EMBEDDED_RSC` for an optional one like `default.png`); (b) **`src/embed_assets.cpp`** — an `extern` plus an `ASSET_ENTRY` in **both** lookup tables (the bare-name table and the `POPSLDR/IMG/`-prefixed table); (c) **`bin/POPSLDR/images.lua`** `IMG_REGISTRATIONS` (looked up by the **bare** filename). `cover_default.png` / `cover_missing.png` were added this way; `MISSING.png` was removed from all three.

### CI / release
- Release packaging policy is `PS1_POPSLOADER/*` + `POPS/PATCH_5.BIN` with strict manifest validation; build is gated on embedded build-identity markers (`Exec path:`, `PrepareForColdExternalELFLaunch`, `BOOT.ELF launch failed`) in `bin/enceladus.elf`; embedded-loader blob staleness check; CI image pinned to `ps2dev/ps2dev:v2.0.0`.
- **The embedded-Lua syntax gate is now LIVE** (`luac5.4 -p` on `bin/POPSLDR/*.lua` + `etc/boot.lua`). It used to silently **skip** because the ps2dev image shipped no `luac`; the workflows now `apk add lua5.4` and hard-fail on a syntax error. It catches **SYNTAX only** — runtime nil-global / type / **load-order** errors stay invisible to CI (the `d4b04be` boot brick was exactly such a case).
- `rolling-release.yml` publishes both the bare `POPSLOADER.ELF` and the zip from one build to the floating `rolling-release` GitHub Release on every push to **`BETA-13-PLAY`** and on PR events.
- **`POPSTARTER.ELF` ships in both zips** (the redistributable POPStarter launcher; the POPS engine binaries are NOT redistributable). `rolling-release.yml` puts `POPSTARTER.ELF` at the zip **root** (next to `POPSLOADER.ELF`) and in `POPS/`; the formal `compilation.yml` install zip ships it in `PS1_POPSLOADER/` (next to `POPSLOADER.ELF`) and `POPS/`. `POPS/PATCH_5.BIN` and a `POPSTARTER/` SMB pack folder ship at the rolling-zip root.

## Behavioral Invariants (must preserve)
*(absorbed from the former TRUTHSHEET.md — invariants that changes must preserve unless an explicit migration is planned)*

1. **Boot/runtime Lua is embedded-only** (`src/luaplayer.cpp`, `etc/boot.lua`, `Makefile`): the embedded searcher is installed, filesystem Lua loaders are disabled, required Lua blobs are embedded.
2. **Settings persistence is transactional and per-device — including HDD.** Edits stage in drafts; `CommitSettingsChanges` runs on confirm/leave. `PLDR.SETTINGS_PATH` resolves to the per-device `APP_DIR_LOCAL/.pldrs` sidecar; **HDD installs persist on the HDD boot partition via the `EnsureBootPartitionWritable` RW take-over** (no `mc0:` fallback). (Supersedes the old HDD-to-MC exception.)
3. **USB vs MX4SIO identity comes from the ioctl driver name; `mx4sio_bd` loads conditionally.** Maintainer rule: if a mass device's ioctl/devctl is anything other than `sdc`/`mx4` it is USB; `sdc`/`mx4` means MX4SIO. `usbmass_bd` always loads before `mx4sio_bd`. Pure USB boots never load `mx4sio_bd`.
4. **Startup backend auto-init is path-driven** — boot source plus configured POPSTARTER/DKWDRV/profile paths drive which backends init before the first page visit.
5. **Runtime device selection is not hard-locked** — the old runtime device-lock subsystem (`canEnterDevice`/`setDeviceLock`) was removed (commits a3e04b8, cef61af); any device page can be entered at runtime.
6. **Probe/retry loops are bounded** — finite attempt counts and fixed phases (no frame stalls/hangs).
7. **Launch failure feedback must be explicit** — missing POPStarter/DKWDRV paths and launch-return failures produce user-visible notifications/screens.
8. **Release package manifest is strict** — CI enforces the exact ZIP set and rejects legacy `POPS/*.tm2` entries.
9. **BDMA ⟺ POPSTARTER-MC-folder interlock** — BDMA can't be enabled while the POPSTARTER MC folder is off; the folder can't be disabled while BDMA is on.
10. **HDD `.hide` is in-app on every device** — the `<name>.hide` per-game marker is written/removed in-app via the **L3** toggle on all device pages including HDD via the RW mount take-over.
11. **Per-frame UI timing is frame-counted, not wall-clock** — `Timer.getTime()` is **microseconds** on PS2, so nav auto-repeat and description scroll count frames (the canonical Enceladus idiom), not the clock. New time-based UI rate-limits must frame-count (or use `os.clock()` seconds), never treat `getTime()` as ms.
12. **The analog-stick → d-pad fold must stay gated on `Pads.getMode()` being analog/DualShock** — an ungated fold injects a phantom −127 on a digital pad and breaks up/down nav. `Pads.getMode()` (`PAD_MODECURID`, live mode) is the correct source; `Pads.getType()` (`PAD_MODETABLE`) is not.
13. **Embedded assets are wired in 3 explicit coordinated places** — Makefile (`BIN2S` + `EMBEDDED_RSC`), `src/embed_assets.cpp` (extern + `ASSET_ENTRY` in **both** lookup tables), `bin/POPSLDR/images.lua` (`IMG_REGISTRATIONS`, bare-filename key). Adding/removing an asset that touches fewer than all three is a build or runtime break.

**Intentionally not implemented** (must keep reporting that status until feature work lands): `ILINK`. (`HDD (exFAT)` is now **implemented** via BDMA Mode `ATA` — `df2eb9d`, CI/Rolling green, validating on hardware. `SMB (v1)` network game browsing is now **implemented** this session — settings/modules/lazy-connect/browse/launch via OPL's netman recipe, commits `ee4d454`/`121823d`/`0cf7f81`/`43033dc`/`68f9ed5`/`154c872`/`5d0e302`/`f5ac26c`/`1169dbc`, CI/Rolling green, validating on hardware.)

## Preservation Contracts (hardware-load-bearing — do NOT regress)
*See `docs/PRESERVATION_CONTRACTS.md` for the detailed code-level contract specs — exact `path:line` citations, what-breaks-it for each, and how to retest on hardware.*
- **D-10** HDD POPSTARTER + HDD game — B2 fix `4ae6679` (PFS unmount before ExecPS2).
- **D-14** HDD POPSTARTER + non-HDD game — same partition-aware route.
- **D-15** non-HDD POPSTARTER + HDD game — keep-mask preserves the boot partition's PFS slot.
- **DKWDRV from MC** — reboot variant direct path with argv0 synthesis.
- **BOOT.ELF from USB-booted POPSLoader** (L-07) — V2 route at `d23520a`.
- **`EnsureBootPartitionWritable`** (boot pfs-slot unmount→remount-RW take-over) — now load-bearing for HDD settings save and HDD in-app `.hide`; any launch-path / mount change must not break it.

## Reported Hardware Status

| Case | Last result | Date | Notes |
|---|---|---|---|
| **D-10** HDD POPSTARTER + HDD game | **PASS** (contract) | 2026-05-22, reconfirmed 2026-05-28 (Nuno) | B2 fix `4ae6679`. Must be preserved. |
| **D-14** HDD POPSTARTER + non-HDD game | **PASS** (contract) | 2026-05-22 | Same route as D-10. |
| **D-15** non-HDD POPSTARTER + HDD game | **PASS** (contract) | 2026-05-22 | Keep-mask. |
| **DKWDRV from MC** | **PASS** (contract) | 2026-05-25, reconfirmed 2026-05-28 (Nuno) | Reboot variant + argv0 synthesis. |
| **DKWDRV from HDD custom path** | **PASS** (resolved) | 2026-06-04/06-06 (Nuno) | PRs #486/#487. Was known-broken through BETA-10-5. |
| **BOOT.ELF from USB-booted POPSLoader** (L-07) | **PASS** | 2026-05-28 (Nuno) | V2 route `d23520a`. |
| **BOOT.ELF from HDD-launched POPSLoader** (U-10) | **PASS** (resolved) | 2026-05-31 (Nuno) | PR #479 (`reboot_iop=0`). |
| **HOSDmenu → POPSLoader** (Class A start) | **PASS** (resolved) | maintainer 2026-06-15 | Mechanism not pinned; reverify if it regresses. |
| **wLaunchELF → POPSLoader** (Class A start, some builds) | **PASS** (resolved) | maintainer 2026-06-15 | PR #458 Layer A + remaining builds confirmed. |
| **PSBBN / Browser / HOSDMenu / OSDMenu → POPSLoader** | **PASS** (contract) | CosmicScale 2026-05-25 + Nuno 2026-05-28 | |
| **Settings save on USB / MC-installed POPSLoader** | **PASS** | 2026-05-27 (Nuno) | Per-device `APP_DIR/.pldrs`. |
| **HDD is RW-writable on real hardware** | **PASS** | provato 2026-06 | Confirmed the boot-partition RW take-over works; full HDD settings/.hide flow still validating. |
| **HDD-resident settings save + in-app `.hide`** | Implemented / boots on PCSX2 | 2026-06-17 | Validating on hardware. Not yet broadly hardware-confirmed. |
| **PAL native 640×512 full-screen render** | Implemented / boots on PCSX2 | 2026-06-17 | PAL hardware validation pending. |
| **U-06** PAL/NTSC asset proportions | Targets the new PAL-512 render | — | Verify the full-screen fill + auto-revert confirm on PAL hardware. |
| **D-12** startup backend auto-init | PASS | 2026-03-28 | |
| **D-16** first-entry USB backend discovery | PASS | after 2026-03-27 | |
| **Up/down + analog-stick nav** (frame-counted repeat; analog fold gated) | **PASS** | 2026-06-20 (oldman63) | Lands on individual items; continuous scroll fine. |
| **Boot sound On/Off save** | **PASS** | 2026-06-20 (oldman63) | Saves and survives reboot. |
| **Overall latest rolling** | **PASS** ("everything working fantastically") | 2026-06-21 (Nuno6573) | General confirmation, not item-by-item. |
| **Overscan (CRT inset)** | Implemented / boots on PCSX2 | 2026-06-20 | Not yet CRT/HW-eyeballed. |
| **Cover-art layering** (`cover_default` + `cover_missing` overlay) | Implemented / boots on PCSX2 | 2026-06-20 | Eyeball that both register inside the jewel-case frame on NTSC + PAL. |
| **HDD scan steered off the boot pfs slot** (Proposal A) | Implemented / boots on PCSX2 | 2026-06-20 | `b159a43`. Wants a deliberate HW test that game partitions still mount/list off the boot slot. |

## Known Issues *(canonical — the single list; README / AGENTS / ROLLING_NOTES point here)*

**Open:**
- **"Failed to load HDD" from a non-HDD boot** (config-specific; Nuno 2026-06-14) — when POPSLoader is launched from a non-HDD device (USB / MC) via a launcher, a specific configuration faults while building the HDD game list (most setups list the HDD fine). POPSLoader itself starts normally. Workaround: boot POPSLoader from the HDD, or open the HDD page a few seconds after the menu. **Instrument + isolate; do not assert a cause from source** — bare-reset hardware disproved the #490 theory. (Distinct from the fixed second-boot cache crash below.)

**In testing on hardware** (implemented + boots on PCSX2; **not yet broadly hardware-confirmed** — these are what the current rolling build asks testers to verify):
- HDD in-app `.hide` (L3 toggle; unhide via *Settings → Game List → Hidden games*).
- **R3 reveal/hide** on a device game list — toggles + persists `GLOBAL_HIDE` and rebuilds the list in place (reuses the R1 refresh path).
- HDD-resident settings save (boot-partition RW take-over; provato confirmed the HDD is RW-writable).
- PAL native 640×512 full-screen render + auto-revert display-change confirm.
- POPSTARTER Memory Card Folder toggle + the BDMA interlock.
- **Overscan (CRT inset)** — eyeball the inset on a real CRT.
- **Cover-art layering** (`cover_default` + `cover_missing` overlay) — eyeball that both register inside the jewel-case frame on NTSC + PAL.
- **HDD scan steered off the boot pfs slot** (Proposal A, `b159a43`) — deliberate HW test that game partitions still mount/list off the boot slot.

**Recently resolved:**
- **Nav auto-repeat flew / all desc-scroll speeds felt the same** — `Timer.getTime()` is µs not ms, so wall-clock gates were sub-frame; nav auto-repeat and description scroll are now **frame-counted** (description scroll is fixed at the Fast pace; the Fast/Medium/Slow setting was later removed). Up/down + analog-stick nav and boot-sound save are **HW-confirmed** (oldman63, 2026-06-20).
- **Phantom analog input broke up/down nav** — the analog-stick → d-pad fold is now gated on `Pads.getMode()` being analog/DualShock with per-axis hysteresis. HW-confirmed (oldman63).
- **HDD settings save failed after a game scan** ("...may be read-only") — a game scan borrowed the boot pfs slot and a never-cleared RW flag stranded the save path; **fixed `8d1e67a`** (liveness-validate the boot RW mount via `doesFolderExist` on the save path) and **`b159a43`** (Proposal A: steer the scan to non-boot slots). The latter still wants a deliberate HW test.
- **`MISSING.png` cover placeholder replaced** by the `cover_default` + `cover_missing` layer; `MISSING.png` removed (~−62 KB ELF).
- **Codex BETA-13 audit** — 6 findings, all verified real and **fixed (`ec81de3`)**: `PromoteTmpToDest` now requires its backup before truncating dest; BMP pixel-size/stride validation; PNG dimension cap; stale `mc0:` probe cleanup; two `System.writeFile` full-byte-count checks; R3 no success-toast on a failed save. Report: `docs/AUDIT_CODEX_2026-06-20.md`.
- **"Failed to load HDD" on the second boot** (cache/`loadfile` crash) — fixed; the HDD list loads every boot, and a real error string now surfaces if it ever fails.
- **Load-order boot brick** — `PLDR.HDD` methods were defined before `PLDR.HDD` existed, which made the recent HDD-feature rolling builds un-bootable; **fixed `d4b04be` (2026-06-17)**. (Invisible to `luac -p`/CI; only fatal at runtime.)
- **U-10 BOOT.ELF-from-HDD-boot** — PR #479. **DKWDRV from a custom HDD path** — PRs #486/#487. **Class-A HOSDmenu / some-wLE start failures** — maintainer-confirmed 2026-06-15. **MX4SIO-rooted settings save** — PR #477.

Investigation artifacts archived under `docs/archive/`: `U10_INVESTIGATION.md`, `LAUNCH_HYGIENE.md`, `HDD_POPSTARTER_HANDOFF.md`.

## Known Open Work
1. **Settings UI redesign (Berion mockup)** — gated on the outstanding hardware verification (D-10/D-14/U-10 plus the new HDD/PAL features) settling, and on the mockup PNGs landing.
2. **"Failed to load HDD" from a non-HDD / via-launcher boot** — the remaining open launch-adjacent issue. Instrument + isolate.
3. **Layer C lazy IRX loading — CLOSED.** The safe win shipped: `mmceman` deferral (PR #471 — eager only on MMCE boots, lazy elsewhere + `System.reinitPad`). The further `ds34bt` / `usbd` deferrals are **DECLINED** (2026-06-22): `ds34usb` *and* `ds34bt` both hard-import `usbd`, and the only defer trigger (boot-device hint) classifies the boot *medium*, not pad transport — deferring would strand USB/BT controller input on every non-USB boot, unrecoverable without a reboot, for a likely-small boot-time gain. Keep them eager; do not re-propose.
4. **µs-as-ms timer sweep — DONE** (`9c3f64f` + `a8e61f3`). `Timer.getTime()` is microseconds (source-verified). Fixed: PathEditor key-flash + caret blink, launch-watchdog label; removed the dead action debounce (edge-triggering is the real gate); frame-paced the scene-fade / boot-fade / carousel preserving their current feel. Only cosmetic/inert sites (busy-overlay throttle, saving marquee, disabled debug log) intentionally remain.
5. **`ILINK`** — intentionally unimplemented. **`HDD (exFAT)`** is now implemented (BDMA Mode `ATA`, `df2eb9d`); validating on hardware. **`SMB (v1)`** network game browsing is now implemented this session (commits `ee4d454`/`121823d`/`0cf7f81`/`43033dc`/`68f9ed5`/`154c872`/`5d0e302`/`f5ac26c`/`1169dbc`, CI/Rolling green); validating on hardware.

*(The old "`ps2hdd-osd.irx` → `ps2hdd.irx` driver swap probe" item is removed: HDD read-write was achieved instead via the `EnsureBootPartitionWritable` boot-partition remount take-over, and provato confirmed the HDD is RW-writable on hardware — the IRX swap is no longer the gating path.)*

## Verification Status
- **BETA-12** is the public release (2026-06-18; BETA-11 2026-06-15). **`BETA-13-PLAY` is the active dev branch** and the rolling-publish source; **`BETA-12-PLAY` is frozen/archival**. BETA-13 is the in-progress rolling candidate (not yet cut). The branch tip moves per push (see `git log`) — code/build statements above are repository-verified around the current tip.
- The 2026-06 HDD/PAL/BDMA features are repository-verified and **boot on PCSX2**; provato confirmed the **HDD is RW-writable on real hardware**; the full feature flows are **still validating on hardware** and are **not** broadly hardware-confirmed.
- Hardware behavior is `Unknown (verify on hardware)` unless explicitly recorded above (or in `QA_REGRESSION_MATRIX.md`) with a date.
- See `QA_REGRESSION_MATRIX.md` for the full experiment chronology and `DECISIONS.md` for the decision log.
