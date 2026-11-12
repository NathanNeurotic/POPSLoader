# POPSLoader 1.4.3

A small release on top of 1.4.2: a new Slovak translation, long text that fits on screen in every language, finished Brazilian Portuguese and a slightly larger disc icon.

## Changes

- **Slovak (Slovenčina):** a new language, translated by [SVKghost](https://github.com/SVKghost) ([#605](https://github.com/NathanNeurotic/POPSLoader/issues/605)). Choose it in Settings.
- **Long text fits, in every language:** long settings labels and values, footer labels and menu rows that would run past their box now end in "...", and the selected settings row still scrolls to show the whole text. Busy and message boxes wrap by measured width instead of running off the edge.
- **Brazilian Portuguese:** the 36 runtime strings that were still in English are translated (network settings, SMB and MX4SIO errors, on-screen keyboard keys, dialog prompts).
- **Disc icon:** the optional disc artwork next to the game list is slightly larger (half the case height, capped at 120 px) ([#568](https://github.com/NathanNeurotic/POPSLoader/issues/568)).

## Installation

Use `PS1_POPSLOADER-1.4.3.zip` for the complete kit, `PS1_POPSLOADER.psu` for the application only, or `POPSLOADER.ELF` alone. Setup notes: [UDPFS setup and limitations](https://github.com/NathanNeurotic/POPSLoader/blob/1.4.3/docs/UDPFS_BDMA.md).

## Validation and limits

Assets come from the exact passing master CI run. Checked in an emulator (PCSX2) only: the Settings page in Slovak, the "..." labels, the scrolling selected row, the menu box and a two-line busy box. Not seen on screen: the Ember per-game menu and the on-screen keyboard footer. **Not verified on a real PS2.** UDPFS, i.Link and the drivers are unchanged from 1.4.2 and keep its limits: Okeanos' UDPFS Assault 1.0.1 and anything to do with i.Link are not confirmed on a real PS2. Ember is unchanged upstream Beta-2. Supply your own BIOS, games and proprietary Sony POPS components.
