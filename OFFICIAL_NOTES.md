# POPSLoader 1.4.6

This release updates the bundled Ember PS1 core to Gageformer's [Ember v0.8](https://github.com/Gageformer/Ember/releases/tag/v0.8). Nothing else changed from 1.4.5.

## Changes

- **Ember v0.8:** `EMBER/ember.elf` is the unmodified official v0.8 file (it was Beta-2). POPSLoader starts it the same way as before, with the same per-game options.
- **Ember licence:** the licence file is now `EMBER/LICENSE.txt` (Ember Licence 1.0). `LICENSE-BETA.txt` is no longer shipped; you can delete an old copy.

Everything from [1.4.5](https://github.com/NathanNeurotic/POPSLoader/releases/tag/1.4.5) is included. 1.4.5 can install this release from **Settings, About, Check for Updates**; that updates `POPSLOADER.ELF` only, so copy the `EMBER` folder from the ZIP to get the new core.

## Installation

Use `PS1_POPSLOADER-1.4.6.zip` for the complete kit, `PS1_POPSLOADER.psu` for the application only, or `POPSLOADER.ELF` alone. Setup notes: [UDPFS setup and limitations](https://github.com/NathanNeurotic/POPSLoader/blob/1.4.6/docs/UDPFS_BDMA.md).

## Validation and limits

Assets come from the exact passing master CI run, and the release check confirms the bundled `ember.elf` matches the digest of Gageformer's latest release. **Ember v0.8 has not been run through POPSLoader on a real PS2 or in an emulator.** Ember remains experimental; supply your own BIOS and games. All 1.4.5 limits still apply.
