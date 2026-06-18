Last updated: 2026-06-18 (BETA-12 released; body content from the 2026-06 HDD-RW take-over / PAL-512 / BDMA-folder work + the `d4b04be` load-order boot fix + the `bdma_mode.txt` marker rename). Released line: **BETA-12** (2026-06-18; BETA-11 was 2026-06-15). Dev branch `BETA-12-PLAY` (tip moves per push; see `git log`).

# STATE

This is the **canonical status doc** for POPSLoader. Current runtime state, behavioral invariants, preservation contracts, known issues, and hardware-verification status all live **here**; the other docs (README, AGENTS, CONTRIBUTING, ROADMAP, ROLLING_NOTES) point here instead of duplicating, so this is the one place to keep current. `QA_REGRESSION_MATRIX.md` is the detailed run ledger.

## Project Identity
POPSLoader is a PS2 launcher for POPStarter built on Enceladus runtime pieces, with behavior primarily orchestrated by embedded Lua modules (`system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`). The Lua is bin2c'd into the EE ELF at build time — so a *runtime* Lua error (nil global, type error, **load-order** error) is invisible to `luac -p` and to CI, and only surfaces on real PS2 / PCSX2.

## Repo-Verified Runtime State

### Boot and runtime
- Boot/runtime uses embedded Lua scripts (`etc/boot.lua` → `system.lua` → `ui.lua`).
- `bin/POPSLDR/IMG/default.png` is optional for GitHub Actions artifact builds; if absent, `IMG.default` falls back to the required embedded `MISSING.png` asset.
- `_ps2sdk_memory_init()` in `src/main.cpp` performs an IOP reset before `main()` runs (`RESET_IOP=1` Makefile default); it also runs `SifExitRpc()`, fresh `SifInitRpc(0)`, and `fileXioExit()` first to detach any inherited RPC client from a parent that left `fileXio` loaded (e.g. wLaunchELF). Architecture/revert history: `docs/archive/LAUNCH_HYGIENE.md`.

### Settings (single-device parity)
- Settings persist at `PLDR.SETTINGS_PATH`, resolved at load time by `LoadSettingsNonFatal`: the **per-device sidecar** `APP_DIR_LOCAL/.pldrs` (the directory POPSLOADER.ELF lives in) is preferred for every device.
- **HDD installs now save settings ON THE HDD boot partition itself.** `PLDR.HDD.EnsureBootPartitionWritable` takes over the launcher's boot pfs mount — explicitly unmounts it, then remounts the **same partition read-write at the same pfs slot** ("own your mount", the OPL pattern) — so the `.pldrs` sidecar is written on-HDD. **There is no `mc0:` fallback for an HDD-cwd install.** Single-device parity with USB / MX4SIO / MMCE.
  - This **supersedes** the old PR #466 design ("HDD saves to `mc0:/POPSTARTER/.pldrs` because the bundled `ps2hdd-osd.irx` can't reliably write PFS"). That premise no longer holds.
  - STATUS: implemented, boots on PCSX2; provato confirmed the HDD is **RW-writable on real hardware**; the full settings flow is still validating on hardware (not yet broadly hardware-confirmed).
- `mc0:/POPSTARTER/.pldrs` remains only as a legacy fallback when no sidecar can be computed.
- Settings edits are staged and committed on Settings/Profile confirm/leave.
- Persisted settings — **14 keys** (`EncodeSettings`): `PROFILE`, `POPSTARTER_PATH`, `POPSTARTER_MODE`, `BDMA`, `DKWDRV_PATH`, `STRICT_HDD_PREEXEC_GATE`, `VIDEO_STANDARD`, `HIDE_TEXT`, `KEYBOARD_LAYOUT`, `BOOT_PAGE`, `MULTIDISC_COLLAPSE`, `GLOBAL_HIDE`, `POPSTARTER_MC_FOLDER`, `HIDDEN_DEVICES`.

### Per-game hide layer
- A `<name>.hide` sidecar next to the game's `.VCD` marks it hidden (read for free during the scan; tracked in `PLDR.HIDDEN`). **L3** toggles hide/show on the selected game; **R3** opens the per-device hidden list to unhide. *Settings → Game List → Hidden games:* **Hidden** filters them out; **Visible (manage)** shows them dimmed so you can toggle.
- In-app hide writes work on **every device page** — USB / MX4SIO / MMCE / Memory Card **and the internal HDD**. On HDD the `.hide` is written via the RW mount take-over (`EnsureBootPartitionWritable`); the "add the `.hide` file from a PC" message is now only a write-*failure* fallback, not the primary path.
- STATUS: implemented, boots on PCSX2, validating on hardware.

### BDMA mode / POPSTARTER memory-card folder
- BDMA mode (mass-storage backend) keys: `FAT32` / `USBEXFAT` / `MX4SIO` / `MMCE`. The installed mode is recorded in a marker file in the POPSTARTER pack folder: **`bdma_mode.txt`** (plain-text mode key). Renamed 2026-06-17 from `.pldr_bdma_mode` for a clearer, shared name (mSAS reads the same file); the legacy `.pldr_bdma_mode` / `.pldr_bdma` names are still **read** for back-compat, and the current name is always written.
- **POPSTARTER Memory Card Folder toggle** (Settings, below Discard): disabling it **deletes `mc:/POPSTARTER`** (destructive-action confirm). **BDMA ⟺ folder interlock**: the folder cannot be disabled while BDMA mode is on, and BDMA cannot be enabled while the folder is off.

### Video standard
- Video Standard: **Auto** (default — matches the console region) / NTSC / PAL. On PAL the UI now renders **natively at 640×512** so it fills the screen (no letterbox); NTSC is 640×448. The display-change confirm prompt **auto-reverts** if not confirmed (like OPL); hold START during boot to skip past a bad video mode; the boot screen is centered. STATUS: PAL hardware validation pending.

### Boot-context resolution
- Single canonical resolver `ResolveBootContext()` in `system.lua` combines the C-side argv[0] classification hint (`main.cpp detectBootDeviceHintFromArgv0()`, via `System.getBootDeviceHint()`), Lua-side prefix matching (`mass`/`mmce`/`mx4sio`/`pfs`/`hdd`/`smb`/`host`/`usb`/`ata`/`apa`), and the mx4sio `mass:` fix (`classify_mass_boot` via BDM driver lookup + `.boot_mx4sio`/`.boot_usb` markers). `DetectBootDevice()`, `PLDR.GetBootContext()`, `PLDR.GetBootKind()`, `ComputeSettingsSidecarPath` all read this one resolver.

### Launch arguments (NHDDL-style)
- `parseLaunchArgs()` in `main.cpp` recognizes `-page=*`, `-mode=*` (NHDDL alias), `-game=*`, `-debug`; exposed via `System.getLaunchArgs()` and normalized into `PLDR.LAUNCH_ARGS = {page, page_raw, game, debug}`.
- `-page=` drives carousel auto-nav; `-game=` triggers `PLDR.AutoLaunchFromLaunchArgs()` (requires `-page=`; HDD game format `PARTITION|relpath`, USB/MX4SIO/MMCE format `FILE.VCD`; falls through to the menu with an error toast on failure); `-debug` queues a boot-context toast (`PLDR.SurfaceLaunchArgsDebug()`).

### Backend init / runtime
- Startup backend auto-init uses boot path, configured executable paths, and selected profile. HDD startup targets run `PLDR.LoadHDDModules()`.
- USB vs MX4SIO classification is by mount-driver identity: `mass:/` boots stay USB-only unless explicit MX4SIO evidence (`mx4sio:/` prefix, `sdc`/`mx4` ioctl, or `.boot_mx4sio`). `mx4sio_bd.irx` loads only on that evidence; `usbmass_bd.irx` always loads first (mx4sio depends on it). Runtime device access is not gated by the old device-lock system (`canEnterDevice()` always true).

### Launch paths (current routing)
- **HDD POPSTARTER on HDD partition** (D-10): `LoadELFFromFileExecPS2RebootIOPWithPartition` → `ExecuteHddBackedViaEmbeddedLoader` → child loader `is_hdd_partition_context` branch (fileXioUmount + SifExitRpc/Cmd + ExecPS2, no IOP reset). Byte-identical to the 2026-05-22 B2 hardware-passing fix at commit `4ae6679`.
- **Non-HDD POPSTARTER + HDD game** (D-15): same route with the boot partition's PFS slot preserved via keep_mask.
- **DKWDRV from MC**: reboot variant direct path, IOP reset + reload `SIO2MAN/MCMAN/MCSERV` + ExecPS2 with synthesized argv0.
- **DKWDRV from HDD custom path** (FIXED, PRs #486/#487): partition-aware path + live pfs-slot scan.
- **BOOT.ELF from USB-booted POPSLoader** (V2 route at `d23520a`): non-reboot variant → BOOT.ELF special-case → `ExecuteViaEmbeddedLoader` non-HDD branch (no IOP reset).
- **BOOT.ELF from HDD-booted POPSLoader** (U-10, FIXED): launches with `reboot_iop=0` via PR #479.

### Main menu feature status
- Implemented: `MMCE`, `MX4SIO`, `HDD (PFS)`, `USB`, `Disc (DKWDRV)`. Not implemented: `HDD (exFAT)`, `SMB (v1)`, `ILINK`.
- **Carousel device visibility** (Settings → Carousel Devices): a Shown/Hidden toggle per carousel device lets the user hide entries they don't use (e.g. the not-implemented stubs). Persisted as `HIDDEN_DEVICES` (CSV of stable device keys; all shown by default; a guard keeps ≥1 visible). The carousel nav/render skip hidden entries with no gaps; `UI.MainMenu.OPT` stays the real opts index so the launch dispatch is unchanged (with nothing hidden, behavior is identical). STATUS: implemented, validating on PCSX2/hardware.

### Exit handoff
- Exit modal exposes OSDSYS, Cancel, BOOT.ELF. BOOT.ELF lookup order: `mc0:/BOOT/BOOT.ELF`, `mc1:/BOOT/BOOT.ELF`.

### Cover art
- Sidecar PNG next to the selected `.VCD`, or `hdd0:__common/POPS/ART/<title>.png` for HDD titles.

### CI / release
- Release packaging policy is `PS1_POPSLOADER/*` + `POPS/PATCH_5.BIN` with strict manifest validation; build is gated on embedded build-identity markers (`Exec path:`, `PrepareForColdExternalELFLaunch`, `BOOT.ELF launch failed`) in `bin/enceladus.elf`; embedded-loader blob staleness check; CI image pinned to `ps2dev/ps2dev:v2.0.0`.
- **The embedded-Lua syntax gate is now LIVE** (`luac5.4 -p` on `bin/POPSLDR/*.lua` + `etc/boot.lua`). It used to silently **skip** because the ps2dev image shipped no `luac`; the workflows now `apk add lua5.4` and hard-fail on a syntax error. It catches **SYNTAX only** — runtime nil-global / type / **load-order** errors stay invisible to CI (the `d4b04be` boot brick was exactly such a case).
- `rolling-release.yml` publishes both the bare `POPSLOADER.ELF` and the zip from one build to the floating `rolling-release` GitHub Release on every push to `BETA-12-PLAY` and on PR events.

## Behavioral Invariants (must preserve)
*(absorbed from the former TRUTHSHEET.md — invariants that changes must preserve unless an explicit migration is planned)*

1. **Boot/runtime Lua is embedded-only** (`src/luaplayer.cpp`, `etc/boot.lua`, `Makefile`): the embedded searcher is installed, filesystem Lua loaders are disabled, required Lua blobs are embedded.
2. **Settings persistence is transactional and per-device — including HDD.** Edits stage in drafts; `CommitSettingsChanges` runs on confirm/leave. `PLDR.SETTINGS_PATH` resolves to the per-device `APP_DIR_LOCAL/.pldrs` sidecar; **HDD installs persist on the HDD boot partition via the `EnsureBootPartitionWritable` RW take-over** (no `mc0:` fallback). (Supersedes the old HDD-to-MC exception.)
3. **USB vs MX4SIO identity comes from the ioctl driver name; `mx4sio_bd` loads conditionally.** Maintainer rule: if a mass device's ioctl/devctl is anything other than `sdc`/`mx4` it is USB; `sdc`/`mx4` means MX4SIO. `usbmass_bd` always loads before `mx4sio_bd`. Pure USB boots never load `mx4sio_bd`.
4. **Startup backend auto-init is path-driven** — boot source plus configured POPSTARTER/DKWDRV/profile paths drive which backends init before the first page visit.
5. **Runtime device selection is not hard-locked** — `canEnterDevice()` always returns true; `setDeviceLock()` is a no-op.
6. **Probe/retry loops are bounded** — finite attempt counts and fixed phases (no frame stalls/hangs).
7. **Launch failure feedback must be explicit** — missing POPStarter/DKWDRV paths and launch-return failures produce user-visible notifications/screens.
8. **Release package manifest is strict** — CI enforces the exact ZIP set and rejects legacy `POPS/*.tm2` entries.
9. **BDMA ⟺ POPSTARTER-MC-folder interlock** — BDMA can't be enabled while the POPSTARTER MC folder is off; the folder can't be disabled while BDMA is on.
10. **HDD `.hide` is in-app on every device** — the `<name>.hide` per-game marker is written/removed in-app (L3 toggle, R3 hidden-list) on all device pages including HDD via the RW mount take-over.

**Intentionally not implemented** (must keep reporting that status until feature work lands): `HDD (exFAT)`, `SMB (v1)`, `ILINK`.

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

## Known Issues *(canonical — the single list; README / AGENTS / ROLLING_NOTES point here)*

**Open:**
- **"Failed to load HDD" from a non-HDD boot** (config-specific; Nuno 2026-06-14) — when POPSLoader is launched from a non-HDD device (USB / MC) via a launcher, a specific configuration faults while building the HDD game list (most setups list the HDD fine). POPSLoader itself starts normally. Workaround: boot POPSLoader from the HDD, or open the HDD page a few seconds after the menu. **Instrument + isolate; do not assert a cause from source** — bare-reset hardware disproved the #490 theory. (Distinct from the fixed second-boot cache crash below.)

**In testing on hardware** (implemented + boots on PCSX2; **not yet broadly hardware-confirmed** — these are what the current rolling build asks testers to verify):
- HDD in-app `.hide` (L3 toggle / R3 hidden-list).
- HDD-resident settings save (boot-partition RW take-over; provato confirmed the HDD is RW-writable).
- PAL native 640×512 full-screen render + auto-revert display-change confirm.
- POPSTARTER Memory Card Folder toggle + the BDMA interlock.

**Recently resolved:**
- **"Failed to load HDD" on the second boot** (cache/`loadfile` crash) — fixed; the HDD list loads every boot, and a real error string now surfaces if it ever fails.
- **Load-order boot brick** — `PLDR.HDD` methods were defined before `PLDR.HDD` existed, which made the recent HDD-feature rolling builds un-bootable; **fixed `d4b04be` (2026-06-17)**. (Invisible to `luac -p`/CI; only fatal at runtime.)
- **U-10 BOOT.ELF-from-HDD-boot** — PR #479. **DKWDRV from a custom HDD path** — PRs #486/#487. **Class-A HOSDmenu / some-wLE start failures** — maintainer-confirmed 2026-06-15. **MX4SIO-rooted settings save** — PR #477.

Investigation artifacts archived under `docs/archive/`: `U10_INVESTIGATION.md`, `LAUNCH_HYGIENE.md`, `HDD_POPSTARTER_HANDOFF.md`.

## Known Open Work
1. **Settings UI redesign (Berion mockup)** — gated on the outstanding hardware verification (D-10/D-14/U-10 plus the new HDD/PAL features) settling, and on the mockup PNGs landing.
2. **"Failed to load HDD" from a non-HDD / via-launcher boot** — the remaining open launch-adjacent issue. Instrument + isolate.
3. **Layer C full lazy IRX loading** — only the device-hint precursor shipped; aggressive deferrals (`mmceman` unless MMCE, `ds34bt` unless BT, `usbd` unless USB) queued for a separate PR. High reward for boot time; high risk to input availability.
4. **`HDD (exFAT)`, `SMB (v1)`, `ILINK`** — intentionally unimplemented.

*(The old "`ps2hdd-osd.irx` → `ps2hdd.irx` driver swap probe" item is removed: HDD read-write was achieved instead via the `EnsureBootPartitionWritable` boot-partition remount take-over, and provato confirmed the HDD is RW-writable on hardware — the IRX swap is no longer the gating path.)*

## Verification Status
- **BETA-12** released 2026-06-18 (BETA-11 2026-06-15). `BETA-12-PLAY` is the active dev branch; its tip moves per push (see `git log`) — code/build statements above are repository-verified around the current tip.
- The 2026-06 HDD/PAL/BDMA features are repository-verified and **boot on PCSX2**; provato confirmed the **HDD is RW-writable on real hardware**; the full feature flows are **still validating on hardware** and are **not** broadly hardware-confirmed.
- Hardware behavior is `Unknown (verify on hardware)` unless explicitly recorded above (or in `QA_REGRESSION_MATRIX.md`) with a date.
- See `QA_REGRESSION_MATRIX.md` for the full experiment chronology and `DECISIONS.md` for the decision log.
