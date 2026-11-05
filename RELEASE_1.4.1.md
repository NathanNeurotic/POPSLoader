# POPSLoader 1.4.1

A maintenance release on top of 1.4.0: one launch fix for Adaptive BDMA and an updated UDPFS driver pair.

## Changes

- **Adaptive BDMA off (#616):** a launch on the device the chosen BDMA Mode serves now restages that mode when the memory card has lost it, instead of failing with "mass:/POPS/POPS.ELF not found". FAT32 (None) and other non-UDPFS launches write nothing; UDPFS launches still stage their own pair when it is missing.
- **UDPFS driver:** the embedded pair moves to Okeanos' UDPFS Assault TEST (2026-10-28 pre-release). Server `POPS/<game>.cue` / `.CUE` files are listed once as `<game>.VCD`, which the driver builds on the fly.
- **Credits and docs:** credit links and wiki updates merged since 1.4.0.

## Installation

Use `PS1_POPSLOADER.zip` for the complete kit, `PS1_POPSLOADER.psu` for the application only, or `POPSLOADER.ELF` alone. Setup notes: [UDPFS setup and limitations](https://github.com/NathanNeurotic/POPSLoader/blob/1.4.1/docs/UDPFS_BDMA.md).

## Validation and limits

Assets come from the exact passing master CI run. Hardware: NOT TESTED for both changes; physical-console UDPFS launch and VMC save/reload acceptance remain unverified. Ember is unchanged upstream Beta-2. Supply your own BIOS, games and proprietary Sony POPS components.
