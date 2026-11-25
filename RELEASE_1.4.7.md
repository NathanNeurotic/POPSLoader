# POPSLoader 1.4.7

This release adds a time zone choice to **Settings, Date and Time**. Nothing else changed from 1.4.6.

## Changes

- **Time zone:** a new row at the top of Settings, Date and Time. **Console**, the default, follows the time zone and summer time set in the console's own System Configuration and shows which zone that is, for example `Console (UTC-05:00)`. You can pick any of 38 other zones instead.
- **Summer time:** adds one hour to a zone you picked. While Time zone is Console, summer time follows the console.
- **Save the time zone:** a change applies at once; this row keeps it for the next start.
- The console clock itself is never changed by the choice. If the time is hours off right after **Set from Internet**, the zone is wrong, not the sync.

Everything from [1.4.6](https://github.com/NathanNeurotic/POPSLoader/releases/tag/1.4.6) is included, with the same Ember v0.8 core. 1.4.5 and 1.4.6 can install this release from **Settings, About, Check for Updates**.

## Installation

Use `PS1_POPSLOADER-1.4.7.zip` for the complete kit, `PS1_POPSLOADER.psu` for the application only, or `POPSLOADER.ELF` alone. Setup notes: [UDPFS setup and limitations](https://github.com/NathanNeurotic/POPSLoader/blob/1.4.7/docs/UDPFS_BDMA.md).

## Validation and limits

Assets come from the exact passing master CI run, and the release check confirms the bundled `ember.elf` matches the digest of Gageformer's latest release. **The time zone rows have not been tested on a real PS2 or in an emulator.** Ember remains experimental; supply your own BIOS and games. All 1.4.6 limits still apply.
