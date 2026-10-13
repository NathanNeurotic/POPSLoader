# POPSLoader 1.3.0 — Ember Beta-2 integration

POPSLoader 1.3.0 adds **Gageformer's already released Ember Beta-2 PS1 emulator** alongside the existing POPStarter/VCD launcher. Ember is bundled **unmodified**, with its upstream licence and attribution.

## Downloads

- **PS1_POPSLOADER.zip:** complete device-root install kit with the eight-file `APPS/PS1_POPSLOADER/` application, RiptOPL-matched `POPS/` files, and `EMBER/`.
- **PS1_POPSLOADER.psu:** the identical eight app files directly under the PS2 save's `PS1_POPSLOADER` header, **no nested folder**. Does not contain POPS or EMBER.
- **POPSLOADER.ELF:** standalone executable.
- **BUILD-MANIFEST.txt / SHA256SUMS.txt:** exact CI-built source and file checksums.

## What's new

- Separate Ember game listings, with global Ember Beta-2 settings and per-game overrides via **L2**.
- Ember game folders in `EMBER/games/<GameFolder>/`, with CUE/BIN image support.
- Storage-aware discovery for USB, MX4SIO, MMCE, exFAT HDD, APA/PFS, SMB and UDPFS, alongside POPStarter's VCD support.
- Complete POPS/Ember distribution kit, flat PSU packaging, independent PSUManager verification, and maintained [Wiki](https://github.com/NathanNeurotic/POPSLoader/wiki) and [documentation website](https://nathanneurotic.github.io/POPSLoader/popsloader.html).
- Includes the opt-in experimental USB + UDPFS PS1 VCD option from 1.2.3.

## Requirements and current limitations

Supply your own legally acquired PlayStation BIOS at `EMBER/bios.bin`, your own game images, and any proprietary Sony POPS files needed for POPStarter. **No BIOS, Sony POPS emulator components or commercial games are distributed.** The packaged `ExampleGame.bin` is deliberately empty and cannot be played.

**Real PS2 Ember game launch, controller behavior after the emulator handoff, writable VMC saves, and network/storage compatibility remain unverified by hardware testing.** The release passes automated builds and archive checks; those are not hardware compatibility certifications. This release is marked a prerelease pending console evidence. **i.Link remains deferred** until RiptOPL validates it on physical hardware.

Ember Beta-2 is by [Gageformer](https://github.com/Gageformer/Ember/releases/tag/Beta-2); the unmodified binary is shipped with `EMBER/LICENSE-BETA.txt`. This is the existing Ember Beta-2 release—not a new Ember beta.

Install instructions: [README](https://github.com/NathanNeurotic/POPSLoader/blob/dev/README.md) · [Wiki](https://github.com/NathanNeurotic/POPSLoader/wiki) · [QA matrix](https://github.com/NathanNeurotic/POPSLoader/blob/dev/QA_REGRESSION_MATRIX.md). Official stable 1.2.3 stays available for users who do not want Ember testing.
