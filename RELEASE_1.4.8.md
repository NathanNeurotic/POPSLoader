# POPSLoader 1.4.8

This release fixes UDPFS games not showing up, Ember launches from some devices, and BDMA drivers left on a card by an older POPSLoader.

## Changes

- **UDPFS:** the menu now keeps looking for the server after the network link comes up, so games appear without a restart. The page opens even when the server has not answered yet and says which problem it is: "UDPFS server unavailable" or "No .VCD games found".
- **Ember:** `ember.elf` now also loads from UDPFS, MMCE and when IOP memory is low (it is read through fileXio when the first load method fails, as RiptOPL does).
- **BDMA drivers:** a card staged by an older POPSLoader now gets the current drivers once. A small `POPSTARTER/bdma_stamp.txt` records which driver set is on the card; `bdma_mode.txt` is unchanged.

Everything from [1.4.7](https://github.com/NathanNeurotic/POPSLoader/releases/tag/1.4.7) is included, with the same Ember v0.8 core. 1.4.5 and later can install this release from **Settings, About, Check for Updates**.

## Installation

Use `PS1_POPSLOADER-1.4.8.zip` for the complete kit, `PS1_POPSLOADER.psu` for the application only, or `POPSLOADER.ELF` alone. Setup notes: [UDPFS setup and limitations](https://github.com/NathanNeurotic/POPSLoader/blob/1.4.8/docs/UDPFS_BDMA.md).

## Validation and limits

Assets come from the exact passing master CI run, and the release check confirms the bundled `ember.elf` matches the digest of Gageformer's latest release. **These changes have not been tested on a real PS2 or in an emulator.** Ember remains experimental; supply your own BIOS and games. All 1.4.7 limits still apply.
