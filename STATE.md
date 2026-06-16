Last updated: 2026-05-28 (post-BETA-10-5; PR #470 LAUNCH_ARGS, PR #472 MX4SIO classification, PR #473 hotfix all merged)

# STATE

## Project Identity
POPSLoader is a PS2 launcher for POPStarter built on Enceladus runtime pieces, with behavior primarily orchestrated by embedded Lua modules (`system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`).

`QA_REGRESSION_MATRIX.md` is the detailed run ledger. This file summarizes the stable current repo state and the latest materially relevant hardware outcomes.

## Repo-Verified Runtime State

### Boot and runtime
- Boot/runtime uses embedded Lua scripts (`etc/boot.lua` → `system.lua` → `ui.lua`).
- `bin/POPSLDR/IMG/default.png` is optional for GitHub Actions artifact builds; if it is absent, `IMG.default` falls back to the required embedded `MISSING.png` asset.
- `_ps2sdk_memory_init()` in `src/main.cpp` performs an IOP reset before `main()` runs (`RESET_IOP=1` Makefile default). As of PR #458 (2026-05-25), this also runs `SifExitRpc()`, fresh `SifInitRpc(0)`, and `fileXioExit()` before the reset to detach any inherited RPC client from a parent that left `fileXio` loaded (e.g. wLaunchELF) — see `docs/LAUNCH_HYGIENE.md`.

### Settings
- Settings persist at `PLDR.SETTINGS_PATH`, which is resolved at load time by `LoadSettingsNonFatal`:
  - **Sidecar preferred**: `APP_DIR_LOCAL/.pldrs` (the directory POPSLOADER.ELF lives in). HDD installs use `pfs1:/<install dir>/.pldrs` because `etc/boot.lua` mounts the boot partition `FIO_MT_RDWR` at `pfs1:` by default.
  - **Fallback**: `mc0:/POPSTARTER/.pldrs` (the legacy path). Used when no sidecar can be computed.
  - **HDD installs always use the MC fallback** (PR #466, 2026-05-27). The bundled `ps2hdd-osd.irx` driver has read-write limitations that we can't reliably work around without an IRX swap that risks regressing D-10. So HDD-installed POPSLoader saves settings to `mc0:/POPSTARTER/.pldrs` just like it did before the sidecar feature landed. No regression vs. legacy behavior; sidecar still works for USB / MX4SIO / MMCE installs.
  - **Save**: writes to whichever path was loaded from, so settings stay where they were found.
- Settings edits are staged and committed on Settings/Profile confirm/leave.
- Persisted settings include POPSTARTER path, DKWDRV path, video standard, hide-text mode, keyboard layout, BDMA mode.

### Boot-context resolution (PR #458 unification)
- Single canonical resolver `ResolveBootContext()` in `system.lua` combines:
  - The C-side argv[0] classification hint (`main.cpp` `detectBootDeviceHintFromArgv0()`, exposed via `System.getBootDeviceHint()`)
  - Lua-side prefix matching (existing `mass`/`mmce`/`mx4sio`/`pfs`/`hdd`/`smb`/`host` plus new `usb`/`ata`/`apa` for newer ps2sdk prefixes)
  - The mx4sio mass: fix (`classify_mass_boot` via BDM driver lookup + `.boot_mx4sio`/`.boot_usb` markers)
- `DetectBootDevice()`, `PLDR.GetBootContext()`, `PLDR.GetBootKind()`, `ComputeSettingsSidecarPath` all read from this one resolver. No more three-way duplicate detection.

### Launch arguments (NHDDL-style, PR #458)
- `parseLaunchArgs()` in `main.cpp` recognizes `-page=*`, `-mode=*` (NHDDL alias for `-page`), `-game=*`, `-debug`.
- `System.getLaunchArgs()` exposes parsed values to Lua.
- `PLDR.LAUNCH_ARGS = {page, page_raw, game, debug}` normalized in `system.lua`.
- `-page=` drives carousel auto-nav (PR #462).
- `-game=` triggers `PLDR.AutoLaunchFromLaunchArgs()` after `AutoInitStartupBackends`; requires `-page=` to be set so the target backend is brought up and the right scene is used. Supported pages: HDD (game format `PARTITION|relpath`), USB / MX4SIO / MMCE (game format `FILE.VCD`). On launch failure, falls through to the main menu with an error toast.
- `-debug` queues a boot-context toast (`PLDR.SurfaceLaunchArgsDebug()`) showing the resolved `kind`, `boot_path`, `sidecar_path`, `settings`, and parsed launch args. Useful for diagnosing how POPSLoader classified its environment without rebuilding with DPRINTF.

### Backend init / runtime
- Startup backend auto-init exists and uses boot path information, configured executable paths, and selected profile path.
- HDD startup targets run `PLDR.LoadHDDModules()` (same as HDD page entry).
- USB vs MX4SIO classification is via mount-driver identity. Per the post-release PR #472 refinement: `mass:/` boots stay USB-only unless explicit MX4SIO evidence is present (`mx4sio:/` prefix, `sdc`/`mx4` ioctl driver name, or `.boot_mx4sio` marker). `mx4sio_bd.irx` is only loaded when an ambiguous mass slot exists (mass_probe_needed) or a configured path requires it; `usbmass_bd.irx` is always loaded first because `mx4sio_bd` depends on it. The maintainer rule: "If ioctl/devctl is ANYTHING OTHER THAN `sdc` or `mx4`, and it's a mass device, then it is USB; if a mass device is `sdc`/`mx4` on ioctl/devctl, then it must be MX4SIO."
- Runtime device access is not gated by the old device-lock system; `canEnterDevice()` always returns true.

### Launch paths (current routing)
- **HDD POPSTARTER on HDD partition** (D-10): `LoadELFFromFileExecPS2RebootIOPWithPartition` → `ExecuteHddBackedViaEmbeddedLoader` → child loader `is_hdd_partition_context` branch (fileXioUmount + SifExitRpc/Cmd + ExecPS2, no IOP reset). Byte-identical to the 2026-05-22 B2 hardware-passing fix at commit `4ae6679`.
- **Non-HDD POPSTARTER + HDD game** (D-15): same `ExecuteHddBackedViaEmbeddedLoader` route with the boot partition's PFS slot preserved via keep_mask.
- **DKWDRV from MC** (Nuno 2026-05-25 + 2026-05-28 confirmed PASS): reboot variant direct path, IOP reset + reload `SIO2MAN/MCMAN/MCSERV` + ExecPS2 with synthesized argv0.
- **DKWDRV from HDD custom path** (**FIXED**, Nuno HW-confirmed 2026-06-04/06-06): routed through the POPSTARTER partition-aware path + a live pfs-slot scan (PRs #486/#487), so any custom HDD form resolves. Was long known-broken through BETA-10-5; resolved post-release.
- **BOOT.ELF from USB-booted POPSLoader** (V2 working route, Nuno 2026-05-28 confirmed PASS): non-reboot variant → BOOT.ELF special-case in `LoadELFFromFileWithPartition` → `ExecuteViaEmbeddedLoader` → child loader non-HDD branch (no IOP reset).
- **BOOT.ELF from HDD-booted POPSLoader** (U-10, **FIXED**, Nuno HW-confirmed 2026-05-31): launches with `reboot_iop=0` (no in-process IOP reset) via PR #479. Earlier diagnostic history (PR #463/#464) preserved in `docs/U10_INVESTIGATION.md`.

### Main menu feature status
- `MMCE`, `MX4SIO`, `HDD (PFS)`, `USB`, `Disc (DKWDRV)`: implemented in code.
- `HDD (exFAT)`, `SMB (v1)`, `ILINK`: not implemented.

### Exit handoff
- Exit modal exposes OSDSYS, Cancel, BOOT.ELF.
- BOOT.ELF lookup order: `mc0:/BOOT/BOOT.ELF`, `mc1:/BOOT/BOOT.ELF`.

### Cover art
- Sidecar PNG next to selected `.VCD`, or `hdd0:__common/POPS/ART/<title>.png` for HDD titles.

### CI/release
- Release packaging policy is `PS1_POPSLOADER/*` + `POPS/PATCH_5.BIN` with strict manifest validation.
- Build is gated on embedded build identity markers (`Exec path:`, `PrepareForColdExternalELFLaunch`, `BOOT.ELF launch failed`) being present in `bin/enceladus.elf`.
- Embedded loader blob staleness check runs when timestamp suggests `src/elf_loader/loader.c` is older than its source.
- CI image pinned to `ps2dev/ps2dev:v2.0.0` (post-release pin in `ba8f0d0`).
- Lua syntax check covers all bundled `bin/POPSLDR/*.lua` plus `etc/boot.lua` (extended in PR #461).
- `.github/workflows/rolling-release.yml` (added post-release) publishes a `POPSLOADER-rolling-release.zip` asset to the canonical `rolling-release` GitHub Release on every push to `BETA-12-PLAY` and on every pull-request event (including drafts). The tag floats; testers grab the latest asset. PRs that update `BETA-12-PLAY` and PRs that update PR head SHAs both overwrite the same asset (last-write-wins).

## Reported Hardware Status

| Case | Last result | Date | Notes |
|---|---|---|---|
| **D-10** HDD POPSTARTER + HDD game | **PASS** (preservation contract) | 2026-05-22, reconfirmed 2026-05-28 (Nuno on BETA-10-5 release artifact) | B2 fix at commit `4ae6679` (PFS unmount before ExecPS2). Must be preserved by any future launch-path change. |
| **D-14** HDD POPSTARTER + non-HDD game | **PASS** (preservation contract) | 2026-05-22 | Same partition-aware route as D-10. |
| **D-15** non-HDD POPSTARTER + HDD game | **PASS** (preservation contract) | 2026-05-22 | Keep-mask preserves boot partition's PFS slot across exec. |
| **DKWDRV from MC** | **PASS** (preservation contract) | 2026-05-25, reconfirmed 2026-05-28 (Nuno on BETA-10-5 release artifact) | Reboot variant direct path with argv0 synthesis. |
| **DKWDRV from HDD custom path** | **PASS** (resolved) | 2026-06-04/06-06 (Nuno) | Fixed by PRs #486/#487 (partition-aware route + live pfs-slot scan). Was known-broken through BETA-10-5. |
| **BOOT.ELF from USB-booted POPSLoader** (L-07) | **PASS** | 2026-05-28 (Nuno on BETA-10-5 release artifact) | V2 working route at `d23520a`. |
| **BOOT.ELF from HDD-launched POPSLoader** (U-10) | **PASS** (resolved) | 2026-05-31 (Nuno) | Fixed by PR #479 (`reboot_iop=0`, no in-process IOP reset). Was long known-broken; history in `docs/U10_INVESTIGATION.md`. |
| **HOSDmenu → POPSLoader** (Class A: POPSLoader fails to start) | **PASS** (resolved) | maintainer-confirmed 2026-06-15 | POPSLoader now starts under HOSDmenu (was Class A "never reaches splash"). Exact fix not pinned in this ledger (the UDNL cold-reboot #490 attempt was dropped for breaking HDD); reverify if it regresses. |
| **wLaunchELF → POPSLoader** (Class A: some wLE builds fail to start POPSLoader) | **PASS** (resolved) | maintainer-confirmed 2026-06-15 | POPSLoader now starts across wLE builds. PR #458 Layer A fixed the common cases; the remaining specific builds are confirmed resolved. |
| **POPSLoader launched from wLaunchELF** | **PASS** (common cases) | 2026-05-28 | PR #458 Layer A fileXio teardown in `_ps2sdk_memory_init` resolved the CosmicScale-reported failure for the common cases. One latent failure mode (wLE → USB POPSLoader → BOOT.ELF) reported by Nuno 2026-05-27; code analysis suggests this is the same BOOT.ELF route as the working autoboot/OSDSYS cases, so likely always-broken/latent rather than a regression. Not enumerated as known-broken pending a clearer repro. |
| **POPSLoader launched from PSBBN / Browser / HOSDMenu / OSDMenu** | **PASS** (preservation contract) | CosmicScale 2026-05-25 + Nuno 2026-05-28 | |
| **Settings save on HDD-installed POPSLoader → MC** | **PASS** (preservation contract) | 2026-05-28 (Nuno) | By design (PR #466 release prep). HDD installs fall back to `mc0:/POPSTARTER/.pldrs`; user-visible: settings still persist. |
| **Settings save on USB / MC-installed POPSLoader** | **PASS** | 2026-05-27 (Nuno) | Per-device sidecar at `APP_DIR/.pldrs` working. |
| **U-05** OSDSYS exit | Reported fixed (date unrecorded) | — | |
| **U-06** PAL asset aspect | Unknown (verify on hardware) | — | |
| **D-12** startup backend auto-init | PASS | 2026-03-28 | `PLDR.LoadHDDModules()` routing restored Profile/cwd HDD POPSTARTER resolution. |
| **D-13** device switching without runtime locks | Unknown | — | |
| **D-16** first-entry USB backend discovery | PASS | (after 2026-03-27 fix) | Bounded wait in `BuildUsbIdentityDeferred()`. |
| **U-11** boot-device label display | Unknown | — | Main menu can show the label; not formally verified. |
| **S-09** keyboard layout persistence | Unknown | — | |

### Post-release work (BETA-10-5 → BETA-12-PLAY current tip `81c886e`)

| PR | What landed | Hardware status |
|---|---|---|
| **#470** | `PLDR.LAUNCH_ARGS.game` auto-launch consumer (`PLDR.AutoLaunchFromLaunchArgs`) and `-debug` toast (`PLDR.SurfaceLaunchArgsDebug`). | Repo / CI verified. Indirect hardware PASS (Nuno 2026-05-28 PM): rolling-release boots and runs all tested flows. Explicit `-page=/-game=` launch was not directly tested but the consumer is no-op when those args are absent. |
| **#472** | MX4SIO evidence-based mass: classification: `mx4sio_bd` only loads on explicit MX4SIO evidence. Maintainer refinement commit `7b587fe` enforces "USB or unknown mass stays USB-only". C-layer `lua_mx4sio_init` now calls `EnsureUsbMass()` first so the dependency is unviolatable. | Repo / CI verified. **Hardware PASS** (Nuno 2026-05-28 PM): MX4SIO and USB working as intended on rolling-release. |
| **#473** | HOTFIX: move `local function ClassifyMassRootDriver` declaration above `ClassifyStartupMassTargets` so the closure captures it correctly. Fixes Lua forward-reference nil-call crash at boot reported on 2026-05-28 hardware. | Repo / CI verified. **Hardware PASS** (Nuno 2026-05-28 PM): rolling-release boots cleanly, no Enceladus error. |
| **#471 (DRAFT)** | Layer C: `mmceman.irx` lazy-loaded unless boot device is MMCE; `System.ensureMmceman` Lua binding. | Repo / CI verified. Indirect hardware PASS (Nuno 2026-05-28 PM): pad input survives, all tested flows work — implies the mmceman defer didn't break general boot. MMCE-specific device access from the deferred-load state not directly tested; recommend an MMCE test before promoting from DRAFT. |

## Known Broken (current)

As of 2026-06-15, the only open user-facing issue is:

- **"Failed to load HDD" from a non-HDD boot** (config-specific; Nuno 2026-06-14) — when POPSLoader is launched from a non-HDD device (USB / MC) via a launcher, a specific configuration faults while building the HDD game list (most setups list the HDD fine). POPSLoader itself starts normally. Workaround: boot POPSLoader from the HDD, or open the HDD page a few seconds after the menu. Under investigation; **instrument + isolate, do not assert a cause from source** — bare-reset hardware disproved the #490 theory.

**By-design fallback (confirmed working, not a bug):**
- **Settings save on HDD-installed POPSLoader writes to `mc0:/POPSTARTER/.pldrs`** by design (PR #466). The `ps2hdd-osd.irx` write limitation is the cause. User-visible: settings still persist; they live on MC instead of next to POPSLOADER.ELF. (The HDD-write probe on the gamelist test branch is testing whether this can change.)

**Resolved since BETA-10-5 (hardware-confirmed) — removed from known-broken 2026-06-15:**
- **U-10 BOOT.ELF-from-HDD-boot** — PR #479 (`reboot_iop=0`, no in-process IOP reset); Nuno 2026-05-31.
- **DKWDRV from a custom HDD path** — PRs #486/#487 (partition-aware route + live pfs-slot scan); Nuno 2026-06-04/06-06.
- **POPSLoader fails to start under HOSDmenu / some wLaunchELF builds** (Class A) — maintainer-confirmed 2026-06-15. Mechanism not pinned in this ledger (the UDNL cold-reboot #490 attempt was dropped for breaking HDD); reverify if it regresses.
- **MX4SIO-rooted settings save** — PR #477 (3-attempt retry on the boot.lua mass-slot scan); Nuno 2026-05-29.

Investigation artifacts archived: `docs/U10_INVESTIGATION.md` (U-10 hypotheses + diagnostic plan, kept in case of regression), `docs/LAUNCH_HYGIENE.md` (architecture + revert history), `HDD_POPSTARTER_HANDOFF.md` at repo root (D-10 historical notes, RESOLVED).

## Known Open Work

1. **Layer C full lazy IRX loading** — only the precursor (device hint) shipped. Aggressive deferrals (`mmceman` unless MMCE boot, `ds34bt` unless BT enabled, `usbd` unless USB family) queued for a separate PR. High reward for boot time; high risk to input/controller availability if done carelessly.
2. **Settings UI redesign (Berion mockup)** — Mockup PNGs still to land at `C:\Users\natha\Documents\assets\` for `docs/mockups/`. Hardware blockers (D-10/D-14/D-15/DKWDRV-MC/BOOT.ELF) are now settled per Nuno's BETA-10-5 hardware pass; this is ready to start once the visual oracle is committed.
3. **"Failed to load HDD" from a non-HDD / via-launcher boot** — the remaining open launch-adjacent issue (config-specific, Nuno 2026-06-14). Instrument + isolate; do not assert a cause from source. (U-10 and DKWDRV-HDD, formerly listed here, are now fixed — see Known Broken above.)
4. **HDD r/w driver swap probe** (`ps2hdd-osd.irx` → `ps2hdd.irx`) — branch `claude/hdd-rw-probe` exists with the 2-line change ready for hardware test. Would unlock HDD settings sidecar IF D-10 doesn't regress.
5. **HDD (exFAT), SMB (v1), ILINK** menu flows remain intentionally unimplemented.

(`PLDR.LAUNCH_ARGS.game` and `-debug` consumers wired in this branch — see Launch arguments section above. The first-run MC-to-sidecar settings migration is implemented in `LoadSettingsNonFatal` via the `migrate_to_sidecar` flag added in PR #462; it pins `PLDR.SETTINGS_PATH` to the sidecar location whenever settings load from the MC fallback but a non-HDD sidecar is computable.)

## Verification Status

- BETA-10-5 release tag is at commit `9a0ebe2` (tagged 2026-05-27). That release was hardware-confirmed clean by Nuno on 2026-05-28.
- `BETA-12-PLAY` development branch tip is currently `81c886e` (Merge PR #473 hotfix). Code/build/package statements above are repository-verified at that tip. Post-release PR work (`#470` LAUNCH_ARGS, `#472` MX4SIO, `#473` hotfix) has CI green but is not BETA-10-5 hardware evidence — it is `Unknown (verify on hardware)` unless a tester result is recorded in `QA_REGRESSION_MATRIX.md`.
- Hardware behavior is `Unknown (verify on hardware)` unless explicitly recorded in the table above with a date.
- See `QA_REGRESSION_MATRIX.md` for the full experiment chronology.
