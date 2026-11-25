# POPSLoader Installation Guide

## Which package?

Use the [official POPSLoader 1.4.7 release](https://github.com/NathanNeurotic/POPSLoader/releases/tag/1.4.7) for the current stable line. The older [1.2.3 release](https://github.com/NathanNeurotic/POPSLoader/releases/tag/1.2.3) uses the *legacy* `PS1_POPSLOADER/` root layout and does **not** include PR #600's Ember integration or its separate PSU.

The installation layout below, with POPSTARTER and Ember side by side ([PR #600](https://github.com/NathanNeurotic/POPSLoader/pull/600)), is the one every 1.4.x release uses. For the newest development build instead, download `PS1_POPSLOADER-<version>.zip` from the [rolling prerelease](https://github.com/NathanNeurotic/POPSLoader/releases/tag/rolling-release) (the ZIP name ends with the build version, for example `PS1_POPSLOADER-v1.4.5-1250.zip`) or [PS1_POPSLOADER.psu](https://github.com/NathanNeurotic/POPSLoader/releases/download/rolling-release/PS1_POPSLOADER.psu). Do not mistake successful build tests for hardware approval.

## ZIP deployment

Extract `PS1_POPSLOADER-<version>.zip` onto your storage device, retaining the directory names:

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
  LICENSE.txt
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

## Updating

From 1.4.5 on, **Settings → About → Check for Updates** can replace `POPSLOADER.ELF` over the network adapter. **This has not yet been tested on a PS2.** An official release follows the latest official release; a rolling build follows the newest rolling build.

- `POPSLOADER.ELF` must be on a memory card or a USB / MX4SIO / MMCE drive. A copy started from the internal HDD cannot update itself.
- The console clock must be set (**Settings → Date and Time**, by hand or with *Set from Internet*), and the network settings under **Settings → SMB / Network** must work. A blank PS2 address asks the router.
- The download is checked against the release's `SHA256SUMS.txt` before anything is written, then written straight over the running file. No backup copy is made, so keep the release ZIP: if the write is interrupted, copy `POPSLOADER.ELF` to the device again.
- When UDPFS is using the network adapter, POPSLoader offers to relaunch itself first.

Updating by hand is unchanged: replace `POPSLOADER.ELF` with the one from the release. Only the launcher is updated; `POPS/` and `EMBER/` on your storage device are left alone.

Read the [Ember Core](Ember-Core.md) page for settings, library scanning and current limitations. [STATE.md](../../STATE.md) remains authoritative for live compatibility.
