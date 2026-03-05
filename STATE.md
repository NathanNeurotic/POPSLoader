# STATE

This file is the current snapshot of “where the project stands” and what remains.

## Project
- Name: POPSLoader
- Purpose: PS2 homebrew launcher/manager for POPStarter/POPS workflows, including BDMA backends and device handling.

## Current guarantees (must remain true)
- Settings load on boot (when present) and UI labels reflect actual persisted/runtime state.
- Settings save only when confirming/leaving Settings page.
- MX4SIO vs USB classification uses mount-driver identity rules (do not guess).
- Unknown/empty driver identity is excluded from both MX4SIO and USB pages (never default unknown to USB).
- No debug logging in production builds unless explicitly requested.

## Known open work (high-level)
- ART system integration (port from other version).
- Editable POPStarter path/profile via on-screen keyboard.
- Editable DKWDRV path via on-screen keyboard.
- Global “Hide UI text” toggle (excluded: Splash/Credits/Settings/Gameslist text).
- MX4SIO first-entry quirk masking (one init, two mount attempts with ~1s delay).
- Packaging change: remove POPS/*.tm2 from artifacts and ship POPS/PATCH5.bin instead.
- Add BDMA modes: SMB, iLink, UDPBD (UDPBD is highest complexity).
- Strip debug/logging and reduce size; improve performance.
- Settings-save progress indicator.
- Add mc?:/ alias support (try mc0 then mc1).

## Release readiness checklist (rolling)
- [ ] No overlapping UI text; settings layout stable with long paths
- [ ] Settings persistence verified (change -> leave settings -> reboot -> labels correct)
- [ ] MX4SIO entry works with known double-entry quirk masked
- [ ] Backends validated on real hardware (USB/MX4SIO/MMCE/…)
- [ ] Artifact packaging matches expected files
- [ ] No debug logs, acceptable ELF/artifact size
