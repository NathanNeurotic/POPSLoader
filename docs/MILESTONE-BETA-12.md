# Milestone — BETA-12 core (HDD load + RW confirmed)

**Tag:** `BETA-12-milestone` · 2026-06-16
**Status:** internal milestone marker — **NOT a public release.** The rolling build
(`BETA-12-PLAY`) carries everything here *plus* the still-in-test video fix.

## What this milestone locks in (hardware-confirmed)
- **HDD "Failed to load HDD" — FIXED.** The on-disk game-list cache was read back with
  `loadfile`, which is nil in the embedded PS2 Lua, so the second boot after a cache was
  written crashed. Disabled the disk cache (`PLDR.HDD.USECACHE=false`) + hardened
  `ReadCache`. Tester provato: HDD list loads every boot, including Boot Page = HDD.
- **HDD read/write — CONFIRMED WRITABLE.** The HDD-write probe returned
  `__.POPS is WRITABLE` on hardware (provato), overturning the old "ps2hdd-osd can't
  write PFS" assumption. Unlocks HDD-resident settings + in-app HDD `.hide` (to be built,
  probe-gated with mc0: fallback).
- **Diagnostic:** `RunBusyTask` now surfaces the real thrown error + file:line (this is
  what made the loadfile bug visible). Plus the probe-gate (fires on any HDD-loaded
  session, not only an HDD boot) and a mount slot-leak guard.
- **Game-list features:** Boot Page (auto-enter a device on boot), multi-disc collapse,
  and the L2 hide-layer.
- **Release plumbing:** the rolling release publishes the bare `POPSLOADER.ELF` and the
  zip from one CI build, so they're byte-identical.

## Excluded from this milestone (still in test)
- **Video Standard fix + display safety nets** — honor the Video Standard setting, an
  **Auto** (console-region) default, live-mode force, **hold-START** boot recovery, and a
  **confirm/revert** prompt (15s auto-revert). Builds clean but is **not** hardware-confirmed
  yet (awaiting the PAL tester). It lives on `claude/video-standard-auto` and on the rolling
  build for testing, and folds into the next milestone once confirmed.

## Branch / commit map
- **Tagged commit:** the `BETA-12-PLAY` consolidated state with the two video commits
  (`af40f39` video fix, `4d0a264` safety net) reverted.
- **`BETA-12-PLAY`** (rolling/dev) = this milestone **+ the video fix**, unchanged, so the
  PAL tester keeps testing display on the one rolling build.
