Last updated: 2026-05-25

# ROADMAP

## Status Snapshot

- D-10, D-14, D-15 are hardware-PASS as of 2026-05-22 (B2 fix at commit `4ae6679`). The partition-aware HDD POPSTARTER route is the load-bearing fix to preserve through any new work.
- DKWDRV from MC is hardware-PASS as of 2026-05-25 (Nuno).
- DKWDRV from custom HDD path is **awaiting hardware** on PR #460 (commit `740fa87`, BETA-12-PLAY head). PR #460 completes the V2-mimicry that PR #452 (V4) missed: Lua `reboot_iop=0` + a new DKWDRV special-case route in `LoadELFFromFileWithPartition` mirroring the BOOT.ELF V2 contract.
- BOOT.ELF from USB-booted POPSLoader (L-07) was working in V2 (commit `d23520a`, 2026-05-23). PR #458 regressed it by adding an `is_boot_elf_target` IOP-reset branch in the child loader; PR #460 reverted that. Source-verified back at the V2 working route; hardware re-verification pending.
- BOOT.ELF from HDD-booted POPSLoader (U-10) is **still broken** and was never solved by V2 either. Pursued only after PR #460 hardware verdict settles.
- POPSLoader launched from wLaunchELF (CosmicScale 2026-05-25) fails on some wLE builds. PR #458's `_ps2sdk_memory_init` fileXio-teardown (Layer A) targets this. Hardware pending.
- Backend infrastructure added in PR #458/459/460: per-device settings sidecar (`PLDR.SETTINGS_PATH` resolves at load time with `APP_DIR_LOCAL/.pldrs` preferred and `mc0:/POPSTARTER/.pldrs` fallback), unified `ResolveBootContext` resolver feeding settings/UI/IRX decisions, NHDDL-style launch arg parsing (`-page=`, `-mode=`, `-game=`, `-debug`).
- `docs/LAUNCH_HYGIENE.md` documents the launch-path architecture and the V2 mimicry rationale.
- `HDD (exFAT)`, `SMB (v1)`, `ILINK` remain intentionally unimplemented menu entries.

## Immediate Priorities

### 1) Resolve DKWDRV-on-HDD on hardware
- Test PR #460 artifact: https://github.com/NathanNeurotic/POPSLoader/actions/runs/26416917597
- If DKWDRV-on-HDD PASSES, that closes the V4 saga (PR #452 reverted, PR #458 reverted, PR #460 completes the V2 mimicry).
- If FAILS, escalate to a diagnostic build: enable `LOADER_ENABLE_DEBUG_COLORS` in the child loader, ship to Nuno, identify the exact stage at which the black-screen happens. The hooks already exist in `src/elf_loader/src/loader/src/loader.c` lines 24-43; just need to define the macro at build time.
- Regression checks on the same artifact: D-10, D-15, DKWDRV-MC, BOOT.ELF from USB-booted POPSLoader.

### 2) wLaunchELF launch (CosmicScale)
- Same artifact as priority 1.
- PR #458 added `SifExitRpc() + SifInitRpc(0) + fileXioExit()` before `SifIopReset` in `_ps2sdk_memory_init`, per the documented ps2sdk #425 workaround.
- If still failing, the next angles are: pin a specific ps2dev/ps2dev image tag in CI to rule out toolchain drift, or investigate whether `SifIopReset(NULL, 0x80000000)` (verbose-mode flag) has a different IOP-reset path than `("", 0)`.

### 3) U-10 BOOT.ELF from HDD-booted POPSLoader
- Long-standing, predates this session.
- V2 didn't solve it. PR #458's attempts didn't solve it. Reverted.
- Investigation candidates: explicit `dev9Shutdown()` before exec (the network/HDD expansion module retains hardware state across `SifIopReset` — BOOT.ELF inheriting that may be the culprit), or routing through the child loader with a specifically-crafted IOP teardown.
- Worth a focused investigation PR (no code) before another fix attempt.

### 4) `PLDR.LAUNCH_ARGS` UI auto-navigation
- Infrastructure landed in PR #458. Parsing, normalization, and a `PLDR.LAUNCH_ARGS = {page, page_raw, game, debug}` table all work.
- Need to wire the consumer: `ui.lua` initial page selection should check `PLDR.LAUNCH_ARGS.page` and jump to the named carousel target on boot.
- Smallest risk: gate on `PLDR.LAUNCH_ARGS.page ~= nil` only; existing flows unchanged when no flag passed.

### 5) Display and UX verification
- Re-run `U-06` to confirm PAL/NTSC menu asset proportions on hardware.
- Re-run `U-08` / `U-09` on slower/large libraries to judge whether busy overlays communicate activity clearly enough.

### 6) Coverage and documentation
- `STATE.md`, `TRUTHSHEET.md`, `QA_REGRESSION_MATRIX.md`, `HDD_POPSTARTER_HANDOFF.md` were all updated to current reality on 2026-05-25 alongside this file (PR #461).
- Add concrete run logs for: D-13 device switching without runtime locks, S-09 keyboard layout persistence, U-11 boot-device label display.

## Secondary Work

### 1) Unimplemented menu paths
- `HDD (exFAT)`, `SMB (v1)`, `ILINK` — intentionally not implemented; surface "not supported" if entered.

### 2) Art/asset behavior
- Keep current cover behavior stable: sidecar PNG beside the selected `.VCD`, plus `hdd0:__common/POPS/ART/<title>.png` for HDD titles.
- Keep `default.png` optional in CI artifacts; missing default-cover builds fall back to embedded `MISSING.png`.

### 3) Install/build clarity
- Keep CI package layout and docs synchronized.
- Pin `ps2dev/ps2dev` image tag in `.github/workflows/compilation.yml` to a specific version instead of `:latest` (toolchain drift mitigation).
- Lua syntax check now covers `bin/POPSLDR/*.lua` plus `etc/boot.lua` (extended in PR #461, was previously only boot.lua).

### 4) Settings UI redesign
- 2026-05-19/20 OPL-style focused-list shipped (Settings page rewrite). Hardware verification deferred per the launch-path retest sequence.
- Berion-mockup-driven GUI overhaul is queued (see #5 below). The OPL focused list is intended to be replaced when that overhaul lands, so further iteration on the focused list is paused unless a specific bug appears.

### 5) Full GUI overhaul (Berion mockups)
- 2026-05-24: graphics-team mockups by Berion and the matching PNG asset set landed (`f8fec64`). Full implementation prompt and per-screen pixel specs live in `docs/GUI_OVERHAUL_PROMPT.md`.
- Scope: Context menu, Settings (per-category pages superseding the OPL focused-list), Joypad configuration, On-screen keyboard. Boot/splash and game list are out of scope.
- Prereq: hardware verification of DKWDRV-on-HDD + wLaunchELF + U-10 settles. The category-page Settings model in the prompt replaces the OPL focused-list, so coordinate retest sequencing.
- Mockup HTML/JSX wrapper from Berion's package is referenced by the prompt but not yet committed; either commit the mockup files or use a screenshot/hosted-mockup oracle before starting the Lua port.

### 6) Layer C full lazy IRX loading
- Precursor landed in PR #458: pre-IRX device classification (`detectBootDeviceHintFromArgv0` / `System.getBootDeviceHint`).
- Deferred (high risk for input/controllers): defer `mmceman` unless boot device is MMCE, `ds34bt` unless user has BT pads enabled, `usbd` unless boot device is USB/MX4SIO/DS3-4 USB.
- Tackle only after current launch-path PRs (#458/459/460) are hardware-confirmed.

## Deferred Ideas

- Additional themes/skins.
- Broader network/backend support after SMB and ILINK have defined baselines.
- More ambitious artwork cache policy after current launch/runtime issues are stable.
- First-run MC-to-sidecar settings migration: if user moves POPSLoader to a new device, optionally copy `mc0:/POPSTARTER/.pldrs` to the new sidecar on first save.
