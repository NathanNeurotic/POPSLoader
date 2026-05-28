Last updated: 2026-05-28 (post-BETA-10-5)

# ROADMAP

## Status Snapshot

- **BETA-10-5 shipped 2026-05-27** (tag at `9a0ebe2`). Nuno confirmed clean on hardware 2026-05-28.
- `BETA-12-PLAY` development tip is `81c886e` (Merge PR #473 hotfix).
- D-10, D-14, D-15 are hardware-PASS preservation contracts (B2 fix at commit `4ae6679`). The partition-aware HDD POPSTARTER route must be preserved through any new work.
- DKWDRV from MC is hardware-PASS (Nuno, 2026-05-25 and 2026-05-28 on the release artifact).
- BOOT.ELF from USB-booted POPSLoader (L-07) is hardware-PASS via the V2 route at `d23520a` (Nuno 2026-05-28).
- DKWDRV from custom HDD path is **known-broken accepted** in BETA-10-5. Workaround: use the default MC DKWDRV path. (Re-confirmed broken Nuno 2026-05-28 PM.)
- **MX4SIO-rooted POPSLoader settings save** is **broken with fix in flight** (PR #476). The `mx4sio:/` argv0 prefix isn't a writable fileXio mount; PR #476 translates cwd to the actual `mass*:/` slot via dynamic ioctl driver lookup (sdc/mx4), mirroring the HDD branch in `etc/boot.lua`.
- **BOOT.ELF from HDD-booted POPSLoader (U-10) is now PASS** per Nuno 2026-05-28 PM ("BOOT.ELF working across the board"). Previously known-broken-accepted in BETA-10-5; the resolution after PR #470/#472/#473 was unexpected since none of those PRs touch the U-10 path architecturally. Investigation notes preserved in `docs/U10_INVESTIGATION.md` for any regression revisit.
- POPSLoader launched from wLaunchELF: works in the common flow (CosmicScale post-PR #458). One latent failure mode (wLE → USB POPSLoader → BOOT.ELF) reported by Nuno 2026-05-27 — code analysis says it takes the same route as the working autoboot/OSDSYS cases, so likely always-broken/latent rather than a regression; not enumerated as known-broken pending a clearer repro.

**Post-release work merged to `BETA-12-PLAY` (CI-verified, hardware-unverified except where noted):**
- **PR #470** — `PLDR.LAUNCH_ARGS.game` auto-launch consumer + `-debug` boot-context toast.
- **PR #472** — MX4SIO evidence-based mass: classification; `mx4sio_bd` only loads on explicit MX4SIO evidence; C-layer enforces `EnsureUsbMass()` before `mx4sio_bd` (per maintainer rule "mx4sio needs usb drivers active first").
- **PR #473** — HOTFIX for Lua forward-reference crash (`ClassifyMassRootDriver` declaration order). Hardware confirmation pending in next rolling-release test cycle.

**Open work:**
- **PR #471 (DRAFT)** — Layer C: `mmceman.irx` lazy-loaded unless boot device is MMCE. Awaiting hardware regression test (pad input survival, MMCE access on first probe).

**Infrastructure landed post-release:**
- `.github/workflows/rolling-release.yml` — automated rolling-release artifact publication on push to `BETA-12-PLAY` and on PR events.
- `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md` — handoff plan for the post-BETA-10-5 doc cleanup work (this PR is part of it).

`HDD (exFAT)`, `SMB (v1)`, `ILINK` remain intentionally unimplemented menu entries.

## Immediate Priorities

### 1) Settings UI redesign (Berion mockup)
- Blocked on Berion's mockup PNGs landing at `C:\Users\natha\Documents\assets\` and being committed to `docs/mockups/`. Without the visual oracle, the Lua port is hard to start.
- Hardware blockers (D-10/D-14/D-15/DKWDRV-MC/BOOT.ELF) are now settled per BETA-10-5. Implementation can start the moment the mockups land.
- Scope: Context menu, Settings (per-category pages superseding the OPL focused-list), Joypad configuration, On-screen keyboard. Boot/splash and game list are out of scope.
- Full implementation prompt and per-screen pixel specs live in `docs/GUI_OVERHAUL_PROMPT.md`.

### 2) Layer C full lazy IRX loading
- Precursor (pre-IRX device classification hint) landed in PR #458.
- **`mmceman` deferral** — PR #471 (DRAFT). Awaiting hardware test. Verify: MMCE boots still load mmceman eagerly, USB/MC/MX4SIO/HDD boots defer it, pad input survives on all boot types, MMCE-page entry from a deferred state correctly lazy-loads.
- **`ds34bt` deferral** (Bluetooth pads) — queued. Needs a settings toggle ("Enable BT Pads", default off) or auto-detect, otherwise it breaks BT-pad-only users.
- **`usbd` deferral** — queued, HIGH RISK. `ds34usb` (USB DS3/4 pads, the most common pad type) depends on `usbd`. Without `usbd`, USB pads stop working. Cannot ship without a robust opt-in or careful boot-time decision.
- Expected gain per the audit in `docs/LAUNCH_HYGIENE.md`: 30-50% pre-Lua startup time reduction once all three deferrals land.

### 3) Display and UX verification
- Re-run `U-06` to confirm PAL/NTSC menu asset proportions on hardware.
- Re-run `U-08` / `U-09` on slower/large libraries to judge whether busy overlays communicate activity clearly enough.

### 4) Coverage and documentation
- Add concrete run logs for: D-13 device switching without runtime locks, S-09 keyboard layout persistence, U-11 boot-device label display.

## Pragmatically Accepted (not blocking)

- **U-10 BOOT.ELF from HDD-booted POPSLoader** — was known-broken accepted; **now PASS per Nuno 2026-05-28 PM**. Investigation hypotheses preserved in `docs/U10_INVESTIGATION.md` in case it regresses. Branch `claude/diag-u10` preserved.
- **DKWDRV from custom HDD path** — known-broken accepted (re-confirmed broken by Nuno 2026-05-28 PM). PR #460's V2 mimicry didn't fix it on hardware. If revisited: GS BGCOLOUR diagnostics don't work on this path (runs through too fast against POPSLoader's still-active framebuffer); need a different angle (Lua-side notification or explicit framebuffer clear before paint).
- **HDD r/w driver swap probe** (`ps2hdd-osd.irx` → `ps2hdd.irx`) — branch `claude/hdd-rw-probe` exists with the 2-line change. Would unlock HDD settings sidecar IF D-10 doesn't regress. Requires hardware test.
- ~~**wLE → USB-POPSLoader → BOOT.ELF latent failure** (Nuno 2026-05-27)~~ — covered by the 2026-05-28 PM "BOOT.ELF across the board" PASS. Removed from this list unless a new failure is reported.

## Secondary Work

### 1) Unimplemented menu paths
- `HDD (exFAT)`, `SMB (v1)`, `ILINK` — intentionally not implemented; surface "not supported" if entered.

### 2) Art/asset behavior
- Keep current cover behavior stable: sidecar PNG beside the selected `.VCD`, plus `hdd0:__common/POPS/ART/<title>.png` for HDD titles.
- Keep `default.png` optional in CI artifacts; missing default-cover builds fall back to embedded `MISSING.png`.

### 3) Install/build clarity
- Keep CI package layout and docs synchronized.
- `ps2dev/ps2dev` image is pinned to `v2.0.0` in `.github/workflows/compilation.yml` and `.github/workflows/rolling-release.yml` (post-release pin at commit `ba8f0d0`).
- Lua syntax check covers `bin/POPSLDR/*.lua` plus `etc/boot.lua` (extended in PR #461).
- Rolling release workflow publishes a single `POPSLOADER-rolling-release.zip` asset to the canonical `rolling-release` GitHub Release; both push-to-BETA-12-PLAY and PR events overwrite the same asset (last-write-wins).

### 4) Settings UI redesign
- 2026-05-19/20 OPL-style focused-list shipped (Settings page rewrite). Hardware verification deferred per the launch-path retest sequence.
- Berion-mockup-driven GUI overhaul is queued (see #5 below). The OPL focused list is intended to be replaced when that overhaul lands, so further iteration on the focused list is paused unless a specific bug appears.

### 5) Full GUI overhaul (Berion mockups)
- 2026-05-24: graphics-team mockups by Berion and the matching PNG asset set landed (`f8fec64`). Full implementation prompt and per-screen pixel specs live in `docs/GUI_OVERHAUL_PROMPT.md`.
- Scope: Context menu, Settings (per-category pages superseding the OPL focused-list), Joypad configuration, On-screen keyboard. Boot/splash and game list are out of scope.
- Prereq: hardware verification of DKWDRV-on-HDD + wLaunchELF + U-10 has settled (BETA-10-5 release + Nuno 2026-05-28 PM verification). The category-page Settings model in the prompt replaces the OPL focused-list, so coordinate retest sequencing.
- Mockup HTML/JSX wrapper from Berion's package is referenced by the prompt but not yet committed; either commit the mockup files or use a screenshot/hosted-mockup oracle before starting the Lua port.

### 6) Documentation cleanup (per `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md`)
- Three-PR plan: source-of-truth sync, agent/handoff cleanup, architecture/component/release polish.
- Out of scope: any change to runtime code or to CI/build/release workflows; doc-only edits.

## Deferred Ideas

- Additional themes/skins.
- Broader network/backend support after SMB and ILINK have defined baselines.
- More ambitious artwork cache policy after current launch/runtime issues are stable.
