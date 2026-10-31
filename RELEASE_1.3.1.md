# POPSLoader 1.3.1

This maintenance release includes the controller-free boot fix and larger disc artwork, with the existing Ember Beta-2 option and complete installation kit.

## Changes

- **Boot without a controller in port 1 (#603):** disconnected/error pads stop initialization immediately; transient readiness waits are bounded to one second. The port remains open for a controller connected later. The error-screen button poll also returns without waiting on unavailable input.
- **Readable disc artwork (#568):** matching `<gamefilename>_ICO.png` art now draws at approximately 45% of the case height (112-pixel cap), inside the preview panel and clear of game titles. Loading stays asynchronous.
- Includes the current black-fade launch/video transitions, Ember integration and complete installable ZIP / eight-file flat PSU package from the development channel.
- **Issues #603 and #568 remain open for their reporters to verify and close.**

## Downloads

- `PS1_POPSLOADER.zip`: device-root installation kit with `APPS/PS1_POPSLOADER/`, pinned `POPS/` and `EMBER/` trees, and the flat PSU.
- `PS1_POPSLOADER.psu`: the same eight app files directly under the `PS1_POPSLOADER` save header; POPS and EMBER support folders are installed separately from the ZIP.
- `POPSLOADER.ELF`: standalone executable.
- `BUILD-MANIFEST.txt` and `SHA256SUMS.txt`: exact source/CI provenance and asset checksums.

## Validation and limitations

Automated gates cover the real controller source, embedded Lua runtime, NTSC/PAL disc layout, PNG decoding, UDPFS configuration/integration and package contents. The official assets come from the exact passing master CI run.

**Physical-console verification of #603 and #568 is pending.** Ember game launch, controller behavior after handoff, writable VMC saves and UDPFS/storage compatibility still require recorded PS2 tests. Ember and USB + UDPFS remain experimental options within this official launcher release. i.Link for Ember remains deferred.

[Ember](https://github.com/Gageformer/Ember) is [Gageformer](https://github.com/Gageformer)'s existing, unmodified **Beta-2**, not a new emulator release. Its upstream license ships with the kit. Supply your own BIOS, games and proprietary Sony POPS components as needed; none are provided. `ExampleGame.bin` is an empty placement example.

[Installation guide](https://github.com/NathanNeurotic/POPSLoader/wiki/Installation-Guide) ? [Hardware QA matrix](https://github.com/NathanNeurotic/POPSLoader/blob/master/QA_REGRESSION_MATRIX.md) ? [Ember Beta-2](https://github.com/Gageformer/Ember/releases/tag/Beta-2)
