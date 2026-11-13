# POPSLoader 1.4.4

A small follow-up to 1.4.3: a warning for disc icons that cannot be shown, and SVKghost's corrections to the Slovak translation.

## Changes

- **Disc icon warning:** when a game's disc icon (`_ICO.png`) is present but too large or unreadable (for example over 1024 px on a side, or over the loader's size budget, about 607x607 in full colour), POPSLoader now shows a one-time warning for that file instead of skipping it silently ([#568](https://github.com/NathanNeurotic/POPSLoader/issues/568)).
- **Slovak corrections:** [SVKghost](https://github.com/SVKghost)'s review of the Slovak translation: the credits, the START-at-boot notice, and shorter Ember Dithering, Backspace and Game list cache labels ([#605](https://github.com/NathanNeurotic/POPSLoader/issues/605)).

Everything from [1.4.3](https://github.com/NathanNeurotic/POPSLoader/releases/tag/1.4.3) is included: the Slovak translation, long text that fits in every language, finished Brazilian Portuguese and the slightly larger disc icon.

## Installation

Use `PS1_POPSLOADER-1.4.4.zip` for the complete kit, `PS1_POPSLOADER.psu` for the application only, or `POPSLOADER.ELF` alone. Setup notes: [UDPFS setup and limitations](https://github.com/NathanNeurotic/POPSLoader/blob/1.4.4/docs/UDPFS_BDMA.md).

## Validation and limits

Assets come from the exact passing master CI run. The two changes are host-tested only: neither the warning nor the new Slovak labels have been seen on screen in an emulator or on a PS2, and the label widths are estimates. **Not verified on a real PS2.** UDPFS, i.Link and the drivers are unchanged from 1.4.2 and keep its limits: Okeanos' UDPFS Assault 1.0.1 and anything to do with i.Link are not confirmed on a real PS2. Ember is unchanged upstream Beta-2. Supply your own BIOS, games and proprietary Sony POPS components.
