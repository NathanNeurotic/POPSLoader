Last updated: 2026-06-18 (post-BETA-12)

# ROADMAP

This is the **forward plan**. For current runtime state, the canonical Known-Issues list, the Preservation Contracts, the Behavioral Invariants, and the per-case Hardware Status, see **`STATE.md`** — those volatile/shared facts live there and are not re-enumerated here.

## Status Snapshot

- **BETA-12 shipped 2026-06-18** (BETA-11 2026-06-15). Dev branch `BETA-12-PLAY` (tip moves per push; see `git log`).
- The 2026-06 deliverables landed on `BETA-12-PLAY`: HDD-resident settings save + in-app HDD `.hide` (boot-partition RW take-over via `EnsureBootPartitionWritable`), PAL native 640×512 full-screen render + auto-revert display-change confirm, the `bdma_mode.txt` marker rename (legacy names still read), the POPSTARTER Memory Card Folder toggle + BDMA⟺folder interlock, the launch-args auto-launch consumer, and the live CI luac syntax gate. See **STATE.md > Repo-Verified Runtime State** for the detail.
- **Hardware status, preservation contracts, and known issues are tracked in STATE.md** — see **STATE.md > Reported Hardware Status**, **> Preservation Contracts**, and **> Known Issues**. In short: D-10/D-14/D-15, DKWDRV-from-MC, and BOOT.ELF-from-USB (L-07) remain hardware-PASS contracts; U-10 (BOOT.ELF from HDD-booted POPSLoader), DKWDRV-from-custom-HDD-path, and the Class-A HOSDmenu / some-wLE start failures are now **RESOLVED** (no longer known-broken); the 2026-06 HDD/PAL/BDMA features are **implemented / boot on PCSX2 / HDD RW confirmed on hardware (provato) / full flow validating on hardware**.
- **CAUTION — load-order regression risk.** A boot brick (PLDR.HDD methods defined before `PLDR.HDD` existed) made recent HDD-feature rolling builds un-bootable; fixed `d4b04be` (2026-06-17). Runtime nil-global / type / load-order errors are invisible to `luac -p` and CI — only the syntax gate is automated. Re-test HDD-feature builds on PCSX2/hardware before trusting a green CI.

**Infrastructure landed post-release:**
- `.github/workflows/rolling-release.yml` — automated rolling-release artifact publication on push to `BETA-12-PLAY` and on PR events.
- `docs/archive/DOCUMENTATION_FOLLOWUP_AUDIT.md` — handoff plan for the post-BETA-10-5 doc cleanup work (now completed; see "Documentation cleanup" under Secondary Work).

`HDD (exFAT)`, `SMB (v1)`, `ILINK` remain intentionally unimplemented menu entries.

## Immediate Priorities

### 1) Settings UI redesign (Berion mockup)
- Blocked on Berion's mockup PNGs landing at `C:\Users\natha\Documents\assets\` and being committed to `docs/mockups/`. Without the visual oracle, the Lua port is hard to start.
- The original launch-path hardware blockers (D-10/D-14/D-15/DKWDRV-MC/BOOT.ELF, and now U-10) are settled. **However**, the 2026-06 HDD-resident settings save, in-app HDD `.hide`, and PAL-512 features are still **validating on hardware** (boot on PCSX2; HDD RW confirmed on hardware by provato; full flows not yet broadly hardware-confirmed). Per the maintainer, don't kick off the redesign until those settle, so the redesign builds on a verified settings/persistence base. See **STATE.md > Reported Hardware Status**.
- Scope: Context menu, Settings (per-category pages superseding the OPL focused-list), Joypad configuration, On-screen keyboard. Boot/splash and game list are out of scope.
- Full implementation prompt and per-screen pixel specs live in `docs/archive/GUI_OVERHAUL_PROMPT.md`.

### 2) Layer C full lazy IRX loading
- Precursor (pre-IRX device classification hint) landed in PR #458.
- **`mmceman` deferral — SHIPPED** (PR #471, merged; commit `d10ec56`). MMCE boots load mmceman eagerly (`src/main.cpp:503-528`); USB/MC/MX4SIO/HDD boots defer it (`src/main.cpp:529-538`) and lazy-load on demand via `PLDR.EnsureMmceReadyOnce()` (`bin/POPSLDR/system.lua:1176` — `System.ensureMmceman` + `System.reinitPad`). MMCE pad-input behavior hardware-confirmed (FifthFox, commit `9f2d550`).
- **`ds34bt` deferral** (Bluetooth pads) — queued. Needs a settings toggle ("Enable BT Pads", default off) or auto-detect, otherwise it breaks BT-pad-only users.
- **`usbd` deferral** — queued, HIGH RISK. `ds34usb` (USB DS3/4 pads, the most common pad type) depends on `usbd`. Without `usbd`, USB pads stop working. Cannot ship without a robust opt-in or careful boot-time decision.
- Expected gain per the audit in `docs/archive/LAUNCH_HYGIENE.md`: 30-50% pre-Lua startup time reduction once all three deferrals land.

### 3) Display and UX verification
- `U-06` now targets the **new PAL native 640×512 full-screen render** (the menu fills the screen, no letterbox; NTSC is 640×448). On PAL hardware confirm the full-screen fill *and* the auto-revert display-change confirm prompt (reverts if the new mode isn't confirmed, like OPL). See **STATE.md > Reported Hardware Status** (`U-06` row).
- Re-run `U-08` / `U-09` on slower/large libraries to judge whether busy overlays communicate activity clearly enough.

### 4) Coverage and documentation
- Add concrete run logs for: D-13 device switching without runtime locks, S-09 keyboard layout persistence, U-11 boot-device label display.

## Resolved Since BETA-10-5 (no longer blocking)

The items previously parked here as "pragmatically accepted / known-broken" are now **resolved** — see **STATE.md > Known Issues** (Recently resolved) and **> Reported Hardware Status** for the canonical record:

- **U-10 BOOT.ELF from HDD-booted POPSLoader** — RESOLVED via PR #479 (`reboot_iop=0`). Investigation archived under `docs/archive/U10_INVESTIGATION.md`.
- **DKWDRV from custom HDD path** — RESOLVED via PRs #486/#487 (partition-aware path + live pfs-slot scan).
- **Class-A start failures (HOSDmenu / some wLaunchELF builds)** — RESOLVED (maintainer-confirmed 2026-06-15).
- **HDD read-write** — achieved via the `EnsureBootPartitionWritable` boot-partition remount take-over (the launcher owns its boot pfs slot and remounts it RW), **not** the old `ps2hdd-osd.irx` → `ps2hdd.irx` IRX-swap probe. provato confirmed the HDD is RW-writable on real hardware; the old swap-probe item is dropped. HDD-resident settings save + in-app HDD `.hide` now ship on this path (still validating the full flow on hardware).

## Secondary Work

### 1) Unimplemented menu paths
- `HDD (exFAT)`, `SMB (v1)`, `ILINK` — intentionally not implemented; surface "not supported" if entered.

### 2) Art/asset behavior
- Keep current cover behavior stable: sidecar PNG beside the selected `.VCD`, plus `hdd0:__common/POPS/ART/<title>.png` for HDD titles.
- Keep `default.png` optional in CI artifacts; missing default-cover builds fall back to embedded `MISSING.png`.

### 3) Install/build clarity
- Keep CI package layout and docs synchronized.
- `ps2dev/ps2dev` image is pinned to `v2.0.0` in `.github/workflows/compilation.yml` and `.github/workflows/rolling-release.yml` (post-release pin at commit `ba8f0d0`).
- The embedded-Lua syntax gate (`luac5.4 -p` on `bin/POPSLDR/*.lua` + `etc/boot.lua`) is now **LIVE** — it used to silently skip because the ps2dev image shipped no `luac`; the workflows now `apk add lua5.4` and hard-fail on a syntax error. It catches **SYNTAX only** — runtime nil-global / type / load-order errors stay invisible to CI (see the `d4b04be` load-order boot brick). See **STATE.md > CI / release**.
- Rolling release workflow publishes a single `POPSLOADER-rolling-release.zip` asset to the canonical `rolling-release` GitHub Release; both push-to-BETA-12-PLAY and PR events overwrite the same asset (last-write-wins).

### 4) Settings UI redesign
- 2026-05-19/20 OPL-style focused-list shipped (Settings page rewrite). Hardware verification deferred per the launch-path retest sequence.
- Berion-mockup-driven GUI overhaul is queued (see #5 below). The OPL focused list is intended to be replaced when that overhaul lands, so further iteration on the focused list is paused unless a specific bug appears.

### 5) Full GUI overhaul (Berion mockups)
- 2026-05-24: graphics-team mockups by Berion and the matching PNG asset set landed (`f8fec64`). Full implementation prompt and per-screen pixel specs live in `docs/archive/GUI_OVERHAUL_PROMPT.md`.
- Scope: Context menu, Settings (per-category pages superseding the OPL focused-list), Joypad configuration, On-screen keyboard. Boot/splash and game list are out of scope.
- Prereq: the launch-path hardware verification (DKWDRV-on-HDD, wLaunchELF, U-10) has now settled — all resolved (see **STATE.md > Known Issues**). The remaining gate is the 2026-06 HDD-resident settings save + in-app HDD `.hide` + PAL-512 features, which are still validating on hardware; the category-page Settings model in the prompt replaces the OPL focused-list, so coordinate retest sequencing once those settle.
- Mockup HTML/JSX wrapper from Berion's package is referenced by the prompt but not yet committed; either commit the mockup files or use a screenshot/hosted-mockup oracle before starting the Lua port.

### 6) Documentation cleanup (per `docs/archive/DOCUMENTATION_FOLLOWUP_AUDIT.md`) — DONE 2026-06-17
- **Completed 2026-06-17.** The doc set was consolidated: the volatile status facts were merged into the canonical `STATE.md` (including the former `TRUTHSHEET.md`), the obsolete/superseded docs were archived under `docs/archive/`, and the doc set was de-duplicated so each fact lives in exactly one place. The original three-PR plan (source-of-truth sync, agent/handoff cleanup, architecture/component/release polish) is folded into this consolidation.
- Was out of scope (and stayed so): any change to runtime code or to CI/build/release workflows; this was doc-only.

## Deferred Ideas

- Additional themes/skins.
- Broader network/backend support after SMB and ILINK have defined baselines.
- More ambitious artwork cache policy after current launch/runtime issues are stable.
