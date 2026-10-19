# POPSLoader Project Wiki

The maintained project guide for **POPSLoader**, alongside the preserved historical POPStarter reference. The [native GitHub Wiki](https://github.com/NathanNeurotic/POPSLoader/wiki) is synchronized from this repository's maintained Markdown and mirrored in the [GitHub Pages project section](https://nathanneurotic.github.io/POPSLoader/popsloader/project-wiki.html); the historical `.research/wiki/` pages are archival and remain unchanged.

**Release status (October 19, 2026):** official **[1.3.1](https://github.com/NathanNeurotic/POPSLoader/releases/tag/1.3.1)** includes controller-free boot handling, larger disc artwork, the Ember Beta-2 option and full ZIP/flat-PSU installation kits. Rolling and experimental are built from the same source at this cut. Ember and USB + UDPFS remain experimental and **not hardware-certified**. Do not infer hardware compatibility from green CI.

## Start here

- [Installation Guide](Installation-Guide.md) — prerequisites, device-root directories, launcher installation.
- [Release Formats](Release-Formats.md) — the eight-file `APPS/PS1_POPSLOADER/` directory, flat memory-card `.psu`, full ZIP, development and stable channels.
- [Ember Core](Ember-Core.md) — Ember versus POPStarter, configuration, game format, licensing, test status and i.Link policy.
- [Device Support](Device-Support.md) — storage devices, which features are implemented, and what still needs testing.
- [Technical Ember integration](../EMBER_INTEGRATION.md) — detailed settings, paths and launch contract.
- [UDPFS / BDM-UDPFS guide](../UDPFS_BDMA.md) — opt-in PS1 network support.
- [STATE.md](../../STATE.md) — authoritative changing status, regressions and hardware evidence.
- [QA_REGRESSION_MATRIX.md](../../QA_REGRESSION_MATRIX.md) — detailed test records.
- [POPSLoader release downloads](https://github.com/NathanNeurotic/POPSLoader/releases).

## Preserve the distinctions

**POPS** is Sony's PS1 emulation software and is not supplied. **POPStarter** is the original PS1 game launcher. **POPSLoader** is the modern front-end, which can browse VCD games for POPStarter and now includes a separate **Ember** PS1 emulator pathway on the rolling/development channel. The recovered POPStarter historical wiki is preservation material and should never be rewritten as if it documented the current POPSLoader project.

**Hardware testing is separate from CI.** Ember game launch, controller availability after handoff and VMC saves still require actual PS2 confirmation. i.Link is intentionally deferred until RiptOPL demonstrates working hardware support; it does not block other Ember work.
