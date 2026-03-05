Last updated: 2026-03-05

# STATE

## What POPSLoader is
POPSLoader is a PS2 launcher for POPStarter built on the Enceladus runtime, with Lua-driven UI/flow (`bin/POPSLDR/system.lua`, `bin/POPSLDR/ui.lua`) and EE/IOP support in `src/` and `iop/`.

## Current guarantees (repo-verified)
- Startup loads `boot.lua`, which requires `system.lua`; `PLDR.LoadSettingsNonFatal()` runs before the main UI loop.
- Settings persistence file is `mc0:/POPSTARTER/.pldrs`.
- Settings/Profile edits are staged and persisted on Settings/Profile exit path (`queue_exit`) via `PLDR.SaveSettingsAtomic()`.
- BDMA selectable modes currently implemented in UI/settings: `FAT32`, `USBEXFAT`, `MX4SIO`, `MMCE`.
- MX4SIO vs USB list separation is based on mass mount driver identity (`System.getMassMountDriver` path, `sdc` detection for MX4SIO).

## Known open work (backlog)
- ART system integration.
- Editable POPStarter path/profile via OSK.
- Editable DKWDRV path via OSK.
- Hide UI text toggle with exclusions (Splash/Credits/Settings/Games list text).
- MX4SIO first-entry quirk masking target: init + two attempts + ~1s delay.
- Packaging change target: ship `PATCH5.bin` instead of `POPS/*.tm2` in CI artifact.
- Add BDMA modes: SMB, iLink, UDPBD.
- Remove remaining debug/logging and continue size/speed optimization.
- Settings save progress indicator UX improvements.
- `mc?:/` alias support (`mc0` then `mc1`).

## Release readiness checklist
- [ ] POPStarter launch flow validated on target hardware.
- [ ] Settings load/save verified across reboot.
- [ ] BDMA mode selection/apply/persist verified for all implemented modes.
- [ ] USB/MX4SIO separation validated via mount-driver identity.
- [ ] Manual matrix completed (USB, MX4SIO, MMCE, HDD as applicable).
- [ ] Packaging contents match release policy (current: tm2 set; target change tracked separately).
