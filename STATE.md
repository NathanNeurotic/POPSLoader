Last updated: 2026-05-27 (release-prep)

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
- Auto-navigation wiring not yet consumed by `ui.lua`; the infrastructure is in place but a downstream PR is needed to wire `-page=hdd` into the initial page selection.

### Backend init / runtime
- Startup backend auto-init exists and uses boot path information, configured executable paths, and selected profile path.
- HDD startup targets run `PLDR.LoadHDDModules()` (same as HDD page entry).
- USB vs MX4SIO classification is via mount-driver identity (`System.getMassMountDriver` -> `sdc`/`mx4` -> MX4SIO; else USB).
- Runtime device access is not gated by the old device-lock system; `canEnterDevice()` always returns true.

### Launch paths (current routing)
- **HDD POPSTARTER on HDD partition** (D-10): `LoadELFFromFileExecPS2RebootIOPWithPartition` → `ExecuteHddBackedViaEmbeddedLoader` → child loader `is_hdd_partition_context` branch (fileXioUmount + SifExitRpc/Cmd + ExecPS2, no IOP reset). Byte-identical to the 2026-05-22 B2 hardware-passing fix at commit `4ae6679`.
- **Non-HDD POPSTARTER + HDD game** (D-15): same `ExecuteHddBackedViaEmbeddedLoader` route with the boot partition's PFS slot preserved via keep_mask.
- **DKWDRV from MC** (Nuno 2026-05-25 confirmed PASS): reboot variant direct path, IOP reset + reload `SIO2MAN/MCMAN/MCSERV` + ExecPS2 with synthesized argv0.
- **DKWDRV from HDD** (PR #460, source-verified, hardware pending): non-reboot variant → new DKWDRV special-case in `LoadELFFromFileWithPartition` → `ExecuteViaEmbeddedLoader` → child loader's filexio-direct-load branch (`SifExitRpc + FlushCache + ExecPS2`, no IOP reset). Mirrors V2 BOOT.ELF contract exactly.
- **BOOT.ELF from USB-booted POPSLoader** (V2 working route): non-reboot variant → BOOT.ELF special-case in `LoadELFFromFileWithPartition` (line 485) → `ExecuteViaEmbeddedLoader` → child loader non-HDD branch (no IOP reset).
- **BOOT.ELF from HDD-booted POPSLoader** (U-10, **known broken**): reboot variant direct path with IOP reset. Has never worked; V2 didn't solve it either. Treated as separate problem.

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
- As of 2026-05-25, Lua syntax check covers all bundled `bin/POPSLDR/*.lua` plus `etc/boot.lua`; previously only `boot.lua` was validated.

## Reported Hardware Status

| Case | Last result | Date | Notes |
|---|---|---|---|
| **D-10** HDD POPSTARTER + HDD game | **PASS** | 2026-05-22 | B2 fix at commit `4ae6679` (PFS unmount before ExecPS2). Preserved through all subsequent PRs. |
| **D-14** HDD POPSTARTER + non-HDD game | **PASS** | 2026-05-22 | Same partition-aware route as D-10. |
| **D-15** non-HDD POPSTARTER + HDD game | **PASS** | 2026-05-22 | Keep-mask preserves boot partition's PFS slot across exec. |
| **DKWDRV from MC** | **PASS** | 2026-05-25 | Reboot variant direct path with argv0 synthesis. Confirmed by Nuno on PR #458 artifact. |
| **DKWDRV from HDD custom path** | **FAIL** | 2026-05-25 (PR #458) | Confirmed by Nuno. PR #460 ships V2-mimicry fix (non-reboot variant + new DKWDRV embedded-loader route). Hardware pending. |
| **BOOT.ELF from USB-booted POPSLoader** (L-07) | Source-verified | (V2 working state d23520a 2026-05-23) | PR #458 regressed this by adding an `is_boot_elf_target` IOP-reset branch in the child loader. PR #460 reverts that revert; expected back to V2-working behavior on next hardware test. |
| **BOOT.ELF from HDD-booted POPSLoader** (U-10) | **FAIL** | 2026-05-25 | Long-standing. V2 didn't solve this either. Not addressed by PR #460. Separate problem; pursued only after PR #460 hardware verdict. |
| **POPSLoader launched from wLaunchELF** | **FAIL** (CosmicScale 2026-05-25) | 2026-05-25 | Some wLaunchELF builds. PR #458's `_ps2sdk_memory_init` fileXio teardown (Layer A) targets this. Hardware pending. |
| **POPSLoader launched from PSBBN / Browser / HOSDMenu / OSDMenu** | **PASS** | (ongoing) | CosmicScale 2026-05-25 confirmed these work. |
| **U-05** OSDSYS exit | Reported fixed (date unrecorded) | — | |
| **U-06** PAL asset aspect | Unknown (verify on hardware) | — | |
| **D-12** startup backend auto-init | PASS | 2026-03-28 | `PLDR.LoadHDDModules()` routing restored Profile/cwd HDD POPSTARTER resolution. |
| **D-13** device switching without runtime locks | Unknown | — | |
| **D-16** first-entry USB backend discovery | PASS | (after 2026-03-27 fix) | Bounded wait in `BuildUsbIdentityDeferred()`. |
| **U-11** boot-device label display | Unknown | — | Main menu can show the label; not formally verified. |
| **S-09** keyboard layout persistence | Unknown | — | |

## Known Broken (Accepted for Release)

The following are known-broken edge cases that are NOT blocking release. They've been investigated repeatedly without a stable fix; pragmatic acceptance per Nuno + maintainer 2026-05-27.

- **DKWDRV-on-HDD-custom-path** — black-screens. Most users have DKWDRV on MC; the small subset with HDD installs typically don't keep DKWDRV on HDD. Workaround: configure DKWDRV path to MC.
- **U-10 BOOT.ELF-from-HDD-boot** — exits to BOOT.ELF black-screen when POPSLoader was booted from HDD. Long-standing (predates this session). USB-autoboot POPSLoader → BOOT.ELF still works. Workaround: use Exit → OSDSYS or reboot the console instead.

(2026-05-27: a wLE→USB-POPSLoader→BOOT.ELF case was reported by Nuno during the release-candidate hardware pass. Code analysis suggests this case takes the same BOOT.ELF route as the working autoboot/OSDSYS/Browser/HOSDMenu cases — so it was likely always-broken/latent rather than a regression introduced by recent PRs. Not reproducible from the most common launch contexts. If a user hits it, the U-10 workaround applies. Not enumerated above pending a clearer repro pattern.)
- **Settings save on HDD-installed POPSLoader writes to MC** — by design (see Settings section above). The `ps2hdd-osd.irx` write limitation is the underlying cause. User-visible: settings still persist; they just live on `mc0:/POPSTARTER/.pldrs` instead of next to POPSLOADER.ELF.

Investigation artifacts archived: `docs/U10_INVESTIGATION.md` (hypotheses + diagnostic plan), `docs/LAUNCH_HYGIENE.md` (architecture + revert history), `docs/HDD_POPSTARTER_HANDOFF.md` (D-10 historical notes).

## Known Open Work
2. **DKWDRV-on-HDD and wLaunchELF launch verdicts** — awaiting hardware testing of PR #460 artifact at https://github.com/NathanNeurotic/POPSLoader/actions/runs/26416917597 .
3. **`PLDR.LAUNCH_ARGS` UI auto-navigation** — infrastructure landed in PR #458; consumer not yet wired into `ui.lua` initial page selection.
4. **Layer C full lazy IRX loading** — only the precursor (device hint) shipped. Aggressive deferrals (`mmceman` unless MMCE boot, `ds34bt` unless BT enabled, `usbd` unless USB family) queued for a separate PR after current launch-path fixes settle.
5. **Settings sidecar first-run MC-to-sidecar migration** — currently we just save where we loaded from. Could optionally copy MC settings to per-device sidecar on first save when the user moves POPSLoader to a new device.
6. **Settings UI redesign (Berion mockup)** — gated on U-10 + DKWDRV-HDD + wLaunchELF hardware results settling. Mockup PNGs still to land at `C:\Users\natha\Documents\assets\` for `docs/mockups/`.
7. **HDD (exFAT), SMB (v1), ILINK** menu flows remain intentionally unimplemented.

## Verification Status

- Code/build/package statements above are repository-verified at commit `740fa87` (BETA-12-PLAY head after PR #460 merge).
- Hardware behavior is `Unknown (verify on hardware)` unless explicitly recorded in the table above with a date.
- See `QA_REGRESSION_MATRIX.md` for the full experiment chronology.
