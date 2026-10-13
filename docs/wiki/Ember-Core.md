# Ember PS1 Core in POPSLoader

**Development status:** implemented on [PR #600](https://github.com/NathanNeurotic/POPSLoader/pull/600), not included in stable POPSLoader 1.2.3, and **not yet console-certified**.

Ember by [Gageformer](https://github.com/Gageformer/Ember) is a separate PS1 emulator; it is **not** POPStarter and it does not run POPStarter VCD images through the POPStarter launch path. POPSLoader discovers compatible Ember game folders on the selected storage device, labels their list rows `[Ember]`, and provides Ember's Beta 2 global and per-game settings.

## Installation and game layout

```text
<device-root>/EMBER/
  ember.elf                bundled, unmodified, with LICENSE-BETA.txt
  LICENSE-BETA.txt
  bios.bin                 user-supplied 512 KiB PS1 BIOS (NOT bundled)
  settings.txt             native Ember global options (optional)
  games/
    YourGame/
      disc.cue
      track.bin
      settings.txt         optional per-game options
      MC1.vmc              created by Ember
      MC2.vmc              created by Ember
```

Only immediate child game directories with supported disc/executable files count as library entries; the `ExampleGame.bin` shipped in the sample is **empty** and must not be treated as game media. Covers use the exact **game-folder name** with `_COV.png`, optional disc icons `_ICO.png`, in the selected device's `ART/` location.

Global settings are in **Settings → Ember PS1 Core**, and a game's four per-game overrides are edited with **L2** on its list row. Native options cover timing, dither, shading and controller; display is global-only. An override set to Default inherits the global value. Consult [technical integration](../EMBER_INTEGRATION.md) for exact allowed values and path handling.

## Device policy and limits

Host-tested scanning includes USB/multiple USB, MX4SIO, MMCE, internal exFAT, SMB and UDPFS, plus APA/PFS partition support. **This is not a statement of working console launches or safe save persistence.** Before making hardware claims, verify controller input through keep-IOP handoff, game launch and VMC writes, device identification and other regression paths on physical PS2 consoles.

**i.Link is deliberately deferred until RiptOPL demonstrates stable, tested i.Link support**. It is out of scope for Ember PR #600 and does not hold back the other supported-device work. The UI continues to show i.Link as unsupported/hidden.

## Licensing and upstream monitoring

The binary must remain **unmodified** and accompanied by `LICENSE-BETA.txt` and attribution to Gageformer with a link to their [official release page](https://github.com/Gageformer/Ember/releases). The licence does not permit commercial redistribution without permission. No BIOS or game image is included.

The weekly [Ember Watch workflow](../../.github/workflows/ember-watch.yml) compares the published Ember asset's SHA-256 against RiptOPL's verified bundled version, supports same-tag asset changes, and updates only POPSLoader's Ember revision pin on `dev`; the original POPS support-file revision remains fixed. Watch activation requires this workflow on the repository's default branch; it does not independently certify hardware compatibility.

[Full status and known issues](../../STATE.md) · [QA matrix](../../QA_REGRESSION_MATRIX.md)
