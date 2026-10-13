# POPSLoader Installation Guide

## Which package?

Use the [official POPSLoader 1.2.3 release](https://github.com/NathanNeurotic/POPSLoader/releases/tag/1.2.3) for the currently released stable line. Its ZIP uses the *legacy* `PS1_POPSLOADER/` root layout; it does **not** include PR #600's new Ember integration or its separate PSU.

The updated installation layout below is available now in the **rolling Ember development package**, merged through [PR #600](https://github.com/NathanNeurotic/POPSLoader/pull/600). Download [PS1_POPSLOADER.zip](https://github.com/NathanNeurotic/POPSLoader/releases/download/rolling-release/PS1_POPSLOADER.zip) or [PS1_POPSLOADER.psu](https://github.com/NathanNeurotic/POPSLoader/releases/download/rolling-release/PS1_POPSLOADER.psu) from the rolling prerelease. Do not mistake successful build tests for hardware approval.

## Development ZIP deployment

Extract `PS1_POPSLOADER.zip` onto your storage device, retaining the directory names:

```text
APPS/
  PS1_POPSLOADER/
    POPSLOADER.ELF
    POPSTARTER.ELF
    icon.sys
    list.icn
    copy.icn
    del.icn
    title.cfg
    APPINFO.PBT
POPS/                   RiptOPL-matched POPStarter files and device support
EMBER/
  ember.elf
  LICENSE-BETA.txt
  games/
    ExampleGame/
      ExampleGame.cue
      ExampleGame.bin
PS1_POPSLOADER.psu       alternative installation of the APPS application only
```

Copy `APPS/PS1_POPSLOADER/` to the application location used by your launcher; alternatively import `PS1_POPSLOADER.psu` with a PS2 PSU-capable save manager. You do **not** copy the PSU as a directory, and **it contains no nested folder**: its PS2 save header is named `PS1_POPSLOADER`, with eight direct file entries. The ELF inside is `POPSLOADER.ELF`.

Place the `POPS/` and `EMBER/` trees at the supported device root, not inside the memory-card application save. The package includes homebrew and config assets, not proprietary Sony `POPS.ELF`, `POPS.PAK`, `POPS_IOX.PAK`, `IOPRP252.IMG`, PlayStation BIOS, or commercial disc images. Supply anything required from your own legally acquired sources.

## Game formats

POPS/POPStarter uses `POPS/<game>.VCD`. Ember uses `EMBER/games/<GameFolder>/<disc>.cue` and matching `.bin` track(s), or other formats explicitly supported by the Ember version. The provided `ExampleGame.bin` is **zero bytes** and is not a playable demonstration game; replace or delete the example folder. Ember also requires your own **512 KiB `EMBER/bios.bin`**, which is not redistributed.

Read the [Ember Core](Ember-Core.md) page for settings, library scanning and current limitations. [STATE.md](../../STATE.md) remains authoritative for live compatibility.
