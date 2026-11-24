# POPSLoader 1.4.5

POPSLoader can now update itself and set the console clock, and devices that need BDMA drivers get them copied on every launch.

## Changes

- **Check for Updates** (Settings, About): asks GitHub for a newer build, downloads `POPSLOADER.ELF` over a verified secure connection, checks it against the release's `SHA256SUMS.txt`, then writes it straight over the running file. No second file and no backup copy is made. It needs the network adapter, a set console clock, and `POPSLOADER.ELF` on a memory card or a USB / MX4SIO / MMCE drive; a copy started from the internal HDD cannot update itself.
  - It works with a manual IP address and no name server saved (the gateway is used), and with no address saved (it asks the router).
  - A failure names the step that failed: name lookup, connect, or no answer.
  - A memory card without room for the new file is refused before anything is written.
  - Rolling builds follow the rolling build; official releases follow the latest release.
  - Because 1.4.4 has no updater, install 1.4.5 by hand once. Later versions can be installed from the menu.
- **Date and Time** (Settings): shows the console clock in local time, sets it by hand, or sets it from the Internet using the console's own time zone and daylight-saving setting.
- **UDPFS and the network adapter:** when UDPFS is holding the adapter, Check for Updates and Set from Internet offer to relaunch POPSLoader, which frees it.
- **BDMA drivers on devices that need them** ([#605](https://github.com/NathanNeurotic/POPSLoader/issues/605)): internal exFAT, MX4SIO, MMCE and i.Link launches now copy their own driver pair to the memory card even when Adaptive BDMA is off and a different mode is saved. A card that already holds the right pair is not written to, and an interrupted copy is redone on the next launch instead of being trusted.
- **Translations:** the updater and busy-screen messages can now be translated. The new strings are English in every language until translators fill them in.
- **Kit:** [Okeanos](https://github.com/Okeanos86)'s multi-disc and all-games folder lists ship as opt-in `DISCS_DIR` examples for UDPFS. Nothing changes until one is copied to `DISCS_DIR.TXT` and enabled in `PATHMAP.INI`.

Everything from [1.4.4](https://github.com/NathanNeurotic/POPSLoader/releases/tag/1.4.4) is included.

## Installation

Use `PS1_POPSLOADER-1.4.5.zip` for the complete kit, `PS1_POPSLOADER.psu` for the application only, or `POPSLOADER.ELF` alone. Setup notes: [UDPFS setup and limitations](https://github.com/NathanNeurotic/POPSLoader/blob/1.4.5/docs/UDPFS_BDMA.md).

## Validation and limits

Assets come from the exact passing master CI run. Everything new here is built and host-tested only. **Nothing in this release has been run on a real PS2 or in an emulator**: not the update download, the write over the running file, the clock setting, the relaunch, or the #605 driver copy (its reporter's retest is still pending). Keep the release ZIP at hand when you try the updater: if a write is interrupted, copy `POPSLOADER.ELF` to the device again. UDPFS, i.Link and the drivers are unchanged from 1.4.2 and keep its limits: Okeanos' UDPFS Assault 1.0.1 and anything to do with i.Link are not confirmed on a real PS2. Ember is unchanged upstream Beta-2. Supply your own BIOS, games and proprietary Sony POPS components.
