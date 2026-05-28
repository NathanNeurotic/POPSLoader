Last updated: 2026-05-28 (post-BETA-10-5)

# ROADMAP

## Status Snapshot

- **BETA-10-5 shipped 2026-05-27** (tag at `9a0ebe2`). Nuno confirmed clean on hardware 2026-05-28.
- D-10, D-14, D-15 are hardware-PASS (B2 fix at commit `4ae6679`). The partition-aware HDD POPSTARTER route is the load-bearing fix to preserve through any new work.
- DKWDRV from MC is hardware-PASS (Nuno, 2026-05-25 and post-release).
- DKWDRV from custom HDD path is **known-broken accepted** in BETA-10-5. Workaround: use the default MC DKWDRV path. PR #460 V2-mimicry was the last attempt; pragmatic call per Nuno + maintainer 2026-05-27 is to ship and revisit later.
- BOOT.ELF from USB-booted POPSLoader (L-07) is working via the V2 route (`d23520a`).
- BOOT.ELF from HDD-booted POPSLoader (U-10) is **known-broken accepted** in BETA-10-5. Long-standing; V2 didn't solve it either. Workaround: Exit → OSDSYS or console reboot. Investigation notes preserved in `docs/U10_INVESTIGATION.md`.
- POPSLoader launched from wLaunchELF: works in the common flow (CosmicScale post-PR #458). One latent failure mode reported by Nuno 2026-05-27 (wLE → USB POPSLoader → BOOT.ELF) — code analysis says it takes the same route as the working autoboot/OSDSYS cases, so likely always-broken/latent rather than a regression; not enumerated as known-broken pending a clearer repro.
- Backend infrastructure (PR #458/459/460/462): per-device settings sidecar with first-run migration, unified `ResolveBootContext` resolver feeding settings/UI/IRX decisions, NHDDL-style launch arg parsing (`-page=`, `-mode=`, `-game=`, `-debug`) with carousel auto-nav, game auto-launch, and debug context surfacing all wired.
- `docs/LAUNCH_HYGIENE.md` documents the launch-path architecture and the V2 mimicry rationale.
- `HDD (exFAT)`, `SMB (v1)`, `ILINK` remain intentionally unimplemented menu entries.

## Immediate Priorities

### 1) Settings UI redesign (Berion mockup)
- Blocked on Berion's mockup PNGs landing at `C:\Users\natha\Documents\assets\` and being committed to `docs/mockups/`. Without the visual oracle, the Lua port is hard to start.
- Hardware blockers (D-10/D-14/D-15/DKWDRV-MC/BOOT.ELF) are now settled per BETA-10-5. Implementation can start the moment the mockups land.
- Scope: Context menu, Settings (per-category pages superseding the OPL focused-list), Joypad configuration, On-screen keyboard. Boot/splash and game list are out of scope.
- Full implementation prompt and per-screen pixel specs live in `docs/GUI_OVERHAUL_PROMPT.md`.

### 2) Layer C full lazy IRX loading
- Precursor (pre-IRX device classification hint) landed in PR #458.
- Deferred (high risk for input/controllers): defer `mmceman` unless boot device is MMCE, `ds34bt` unless user has BT pads enabled, `usbd` unless boot device is USB/MX4SIO/DS3-4 USB.
- Test plan MUST explicitly verify pad input survival across all deferred-load combinations. Expected gain per the audit in `docs/LAUNCH_HYGIENE.md`: 30-50% pre-Lua startup time reduction.

### 3) Display and UX verification
- Re-run `U-06` to confirm PAL/NTSC menu asset proportions on hardware.
- Re-run `U-08` / `U-09` on slower/large libraries to judge whether busy overlays communicate activity clearly enough.

### 4) Coverage and documentation
- Add concrete run logs for: D-13 device switching without runtime locks, S-09 keyboard layout persistence, U-11 boot-device label display.

## Pragmatically Accepted (not blocking)

- **U-10 BOOT.ELF from HDD-booted POPSLoader** — known-broken accepted. Investigation hypotheses in `docs/U10_INVESTIGATION.md`. If revisited: ship the diagnostic build (`LOADER_ENABLE_DEBUG_COLORS`) before another fix attempt. Branch `claude/diag-u10` exists.
- **DKWDRV from custom HDD path** — known-broken accepted. PR #460's V2 mimicry didn't fix it on hardware. If revisited: GS BGCOLOUR diagnostics don't work on this path (runs through too fast against POPSLoader's still-active framebuffer); need a different angle (Lua-side notification or explicit framebuffer clear before paint).
- **HDD r/w driver swap probe** (`ps2hdd-osd.irx` → `ps2hdd.irx`) — branch `claude/hdd-rw-probe` exists with the 2-line change. Would unlock HDD settings sidecar IF D-10 doesn't regress. Requires hardware test.
- **wLE → USB-POPSLoader → BOOT.ELF latent failure** (Nuno 2026-05-27) — code analysis says it takes the same route as working cases, so almost certainly always-broken/latent rather than a regression. Not enumerated as known-broken pending a clearer repro.

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
