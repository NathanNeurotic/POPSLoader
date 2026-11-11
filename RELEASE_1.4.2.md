# POPSLoader 1.4.2

A maintenance release on top of 1.4.1: Okeanos' UDPFS Assault 1.0.1, an experimental i.Link page, completed translations and one confirm-prompt fix.

## Changes

- **UDPFS driver:** the embedded pair moves to [Okeanos](https://github.com/Okeanos86)' UDPFS Assault 1.0.1 (2026-11-08; `usbd.irx.udpfs` 61,949 B, `usbhdfsd.irx.udpfs` unchanged). It adds an optional `PATHMAP.INI` (GAMEID_DIR, DISCS_DIR, CHEATS_WS). The driver is about 20 KB larger on the IOP; whether POPSTARTER has room for it is not confirmed on a real PS2.
- **i.Link (experimental):** a new i.Link page lists Ember games and POPSTARTER VCDs, and BDMA Mode "i.Link (experimental)" stages RiptOPL's i.LINK driver pair. The page is hidden by default (Settings > Device List). It is not hardware tested, and i.LINK cannot run in PCSX2.
- **Confirm prompts:** Circle on "No" in the "Delete the POPSTARTER folder" prompt no longer also acts as Back and leaves Settings.
- **Translations:** 71 runtime strings completed in French, German, Spanish, Italian, Portuguese and Hungarian (Portuguese still has some English entries); the MX4SIO locate message is translated.
- **Kit:** the release kit pins the current i.LINK driver pair and fails the build on a checksum mismatch.

## Installation

Use `PS1_POPSLOADER-1.4.2.zip` for the complete kit, `PS1_POPSLOADER.psu` for the application only, or `POPSLOADER.ELF` alone. Setup notes: [UDPFS setup and limitations](https://github.com/NathanNeurotic/POPSLoader/blob/1.4.2/docs/UDPFS_BDMA.md).

## Validation and limits

Assets come from the exact passing master CI run. Checked in an emulator only: boot, staging of the new UDPFS driver to a throwaway memory card, and the Circle-on-No fix. **Not verified on a real PS2:** Okeanos' UDPFS 1.0.1 (a PS1 game over UDPFS, and POPSTARTER's memory fit), and anything to do with i.Link. Ember is unchanged upstream Beta-2. Supply your own BIOS, games and proprietary Sony POPS components.
