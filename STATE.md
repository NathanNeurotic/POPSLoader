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
- **DKWDRV from HDD custom path** (**known broken accepted for BETA-10-5**): PR #460 V2-mimicry shipped, but Nuno's 2026-05-25 hardware test on that artifact still black-screened. Pragmatic acceptance per Nuno + maintainer 2026-05-27: most users keep DKWDRV on MC. Workaround: configure DKWDRV path to MC.
- **BOOT.ELF from USB-booted POPSLoader** (V2 working route, Nuno 2026-05-28 confirmed PASS): non-reboot variant → BOOT.ELF special-case in `LoadELFFromFileWithPartition` → `ExecuteViaEmbeddedLoader` → child loader non-HDD branch (no IOP reset).
- **BOOT.ELF from HDD-booted POPSLoader** (U-10, **known broken**): reboot variant direct path with IOP reset. Has never worked; V2 didn't solve it either. PR #463 diagnostic colors localized the hang to `SifIopReset` itself (last visible stage YELLOW; ORANGE post-reset never paints). PR #464 F4 unconditional unmount didn't fix it on hardware. Treated as separate problem with the hypothesis catalog preserved in `docs/U10_INVESTIGATION.md`.

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
| **DKWDRV from HDD custom path** | **FAIL — known broken accepted** | 2026-05-25 (last hardware test) | Pragmatically accepted for BETA-10-5 per Nuno + maintainer 2026-05-27. Workaround: configure DKWDRV path to MC. |
| **BOOT.ELF from USB-booted POPSLoader** (L-07) | **PASS** | 2026-05-28 (Nuno on BETA-10-5 release artifact) | V2 working route at `d23520a`. |
| **BOOT.ELF from HDD-launched POPSLoader** (U-10) | **FAIL — known broken accepted** | 2026-05-28 PM late (Nuno) | When POPSLoader has been successfully launched from HDD, Exit → BOOT.ELF black-screens. Other launch sources (MC, USB, MX4SIO, MMCE) → BOOT.ELF exit OK. Workaround: Exit → OSDSYS or reboot. Maintainer hypothesis: "maybe I need to reset IOP on boot before anything else" (aligns with H1 dev9Shutdown / H5 stale pfs1: mount in `docs/U10_INVESTIGATION.md`). |
| **HOSDmenu → POPSLoader** (Class A: POPSLoader fails to start) | **FAIL** | 2026-05-28 PM late (Nuno) | When HOSDmenu attempts to launch POPSLoader, black screen — POPSLoader never reaches its splash. Not the same as U-10: U-10 is about BOOT.ELF exit FROM a successfully-running HDD-launched POPSLoader; this is about POPSLoader itself never starting under HOSDmenu. Likely the same IOP-state-from-parent-launcher class PR #458 Layer A targeted (`fileXio` blocks `SifIopReset` per ps2sdk #425) but not fully resolved for HOSDmenu. Workaround: launch POPSLoader via a different launcher. |
| **wLaunchELF → POPSLoader** (Class A: some wLE builds fail to start POPSLoader) | **FAIL on some wLE builds** | 2026-05-28 PM late (Nuno) + CosmicScale 2026-05-25 | Some wLaunchELF builds black-screen when attempting to start POPSLoader (POPSLoader never reaches splash). PR #458 Layer A targeted this. Common wLE builds work; specific builds still fail. Workaround: use a different wLE build, or a different launcher. |
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

## Known Broken (Accepted for Release)

After Nuno's full 2026-05-28 PM hardware sweep on the post-PR-#477 rolling-release, the confirmed-broken edge cases are:

- **DKWDRV-on-HDD-custom-path** — black-screens. Most users have DKWDRV on MC; the small subset with HDD installs typically don't keep DKWDRV on HDD. Workaround: configure DKWDRV path to MC.
- **U-10 BOOT.ELF from HDD-launched POPSLoader** — when POPSLoader has been successfully launched from HDD (via any working launcher), Exit → BOOT.ELF black-screens. Long-standing. Other launch sources → BOOT.ELF still work. Workaround: Exit → OSDSYS or reboot. Maintainer hypothesis to investigate next: explicit IOP reset on boot before anything else (aligns with `docs/U10_INVESTIGATION.md` H1/H5).
- **POPSLoader fails to start under HOSDmenu** (Class A) — HOSDmenu → POPSLoader black-screens before the splash. Same IOP-state-from-parent-launcher class PR #458 Layer A targeted (`fileXio` blocks `SifIopReset` per ps2sdk #425) but Layer A didn't resolve it for HOSDmenu. Workaround: use a different launcher.
- **POPSLoader fails to start on some wLaunchELF builds** (Class A) — common wLE builds work (PR #458 Layer A's fix). Some specific builds still black-screen attempting to start POPSLoader. Workaround: use a different wLE build, or a different launcher.
- **MX4SIO-rooted POPSLoader settings save** was fixed by PR #477 (3-attempt retry on the boot.lua mass-slot scan with diagnostic trace) — hardware-confirmed by Nuno 2026-05-29 02:58Z. PR #476's single-shot scan wasn't enough on real hardware; PR #477 mirrors the existing `PLDR.InitMX4SIOPopsRoot` retry pattern.

**By-design fallback (confirmed working, not a bug):**
- **Settings save on HDD-installed POPSLoader writes to `mc0:/POPSTARTER/.pldrs`** by design (PR #466). The `ps2hdd-osd.irx` write limitation is the underlying cause. User-visible: settings still persist; they just live on MC instead of next to POPSLOADER.ELF.

**Unexpectedly resolved 2026-05-28 PM:**
- **U-10 BOOT.ELF-from-HDD-boot** — previously known-broken-accepted. Nuno reports BOOT.ELF exit working "across the board" including HDD-booted on the post-PR-#473 rolling-release. None of PR #470/#472/#473 architecturally touch the U-10 path, so the cause is not obvious. See the hardware status table above and `docs/U10_INVESTIGATION.md` for investigation notes (preserved in case it regresses).

(2026-05-27: a wLE→USB-POPSLoader→BOOT.ELF case was reported by Nuno during the release-candidate hardware pass. Code analysis suggested it took the same BOOT.ELF route as working cases, so likely always-broken/latent rather than a regression. The 2026-05-28 "BOOT.ELF across the board PASS" report covers this case too unless a new failure is reported.)

Investigation artifacts archived: `docs/U10_INVESTIGATION.md` (hypotheses + diagnostic plan, kept for revisit), `docs/LAUNCH_HYGIENE.md` (architecture + revert history), `HDD_POPSTARTER_HANDOFF.md` at repo root (D-10 historical notes, marked RESOLVED).

## Known Open Work

1. **Layer C full lazy IRX loading** — only the precursor (device hint) shipped. Aggressive deferrals (`mmceman` unless MMCE boot, `ds34bt` unless BT enabled, `usbd` unless USB family) queued for a separate PR. High reward for boot time; high risk to input/controller availability if done carelessly.
2. **Settings UI redesign (Berion mockup)** — Mockup PNGs still to land at `C:\Users\natha\Documents\assets\` for `docs/mockups/`. Hardware blockers (D-10/D-14/D-15/DKWDRV-MC/BOOT.ELF) are now settled per Nuno's BETA-10-5 hardware pass; this is ready to start once the visual oracle is committed.
3. **U-10 / DKWDRV-HDD proper fixes** — pragmatically accepted as known-broken in BETA-10-5. If revisited, see `docs/U10_INVESTIGATION.md` for the hypothesis catalog and diagnostic-first workflow.
4. **HDD r/w driver swap probe** (`ps2hdd-osd.irx` → `ps2hdd.irx`) — branch `claude/hdd-rw-probe` exists with the 2-line change ready for hardware test. Would unlock HDD settings sidecar IF D-10 doesn't regress.
5. **HDD (exFAT), SMB (v1), ILINK** menu flows remain intentionally unimplemented.

(`PLDR.LAUNCH_ARGS.game` and `-debug` consumers wired in this branch — see Launch arguments section above. The first-run MC-to-sidecar settings migration is implemented in `LoadSettingsNonFatal` via the `migrate_to_sidecar` flag added in PR #462; it pins `PLDR.SETTINGS_PATH` to the sidecar location whenever settings load from the MC fallback but a non-HDD sidecar is computable.)

## Verification Status

- BETA-10-5 release tag is at commit `9a0ebe2` (tagged 2026-05-27). That release was hardware-confirmed clean by Nuno on 2026-05-28.
- `BETA-12-PLAY` development branch tip is currently `81c886e` (Merge PR #473 hotfix). Code/build/package statements above are repository-verified at that tip. Post-release PR work (`#470` LAUNCH_ARGS, `#472` MX4SIO, `#473` hotfix) has CI green but is not BETA-10-5 hardware evidence — it is `Unknown (verify on hardware)` unless a tester result is recorded in `QA_REGRESSION_MATRIX.md`.
- Hardware behavior is `Unknown (verify on hardware)` unless explicitly recorded in the table above with a date.
- See `QA_REGRESSION_MATRIX.md` for the full experiment chronology.
