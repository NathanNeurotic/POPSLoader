# Ember PS1 core in POPSLoader — development integration

**Status: in development, host and physical-PS2 verification required.**
This is adapted from [RiptOPL's Ember integration](https://github.com/NathanNeurotic/Open-PS2-Loader/blob/rebuild/main/docs/EMBER-INTEGRATION-PLAN.md) and [Gageformer's Ember](https://github.com/Gageformer/Ember).
Ember is a second PS1 emulator alongside POPStarter, *not* a VCD decoder.
POPSLoader never bundles a console BIOS.

## Device roots and library

The PS1 game page appends Ember titles from the **same current device**
as the VCD list. Ember root scanning handles USB (including multiple
independent drives), MX4SIO, MMCE, internal exFAT/ATA, network SMB and
UDPFS Files where their corresponding mounts exist. It does not reinterpret
a UDPFS source as USB. An APA/PFS HDD `__.EMBER` partition requires its own
persistent, writable PFS mount and safe keep-IOP handoff; **that partition
path is not yet implemented**. i.Link remains unavailable in POPSLoader's
device carousel. Do not claim device parity until both are addressed.

```text
<mounted-device-root>/
  POPS/
    Game.VCD
  ART/
    Game_COV.png             # VCD art by filename
    Game_ICO.png
    Ember Folder_COV.png     # Ember art by FOLDER name
    Ember Folder_ICO.png
  EMBER/
    ember.elf               # user-provided current Ember core
    bios.bin                # user-owned 512 KiB PlayStation BIOS
    settings.txt            # optional native global settings
    games/
      Ember Folder/
        disc.cue
        track.bin
        settings.txt        # optional native per-game overrides
        MC1.vmc MC2.vmc     # Ember writes its own virtual cards here
```

Only immediate child directories of `EMBER/games/` that contain a
top-level `.cue`, `.exe` or `.bin` image are listed. Direct loose images,
empty directories and invalid folder names are ignored because their VMC
path would not be reliable. Both cores can appear on one PS1 list;
entries are marked `[Ember]`.

## Launch behavior

An Ember game uses a keep-IOP handoff: `ember.elf` remains on the
current mounted root, `argv[0]` is its full filesystem path and
`argv[1]` is the **bare directory name**, with no slash, colon or
leading `..`. The game and emulator must be accessible from Ember's
inherited mounts. POPSTARTER's launch selector/IOP reset/BDMA are
**not used** for Ember games.

Launch checks for `ember.elf`, a 512 KiB `bios.bin`, and an image in
the game folder. Failed setting writes on a read-only network mount are
warned about; they do not block an otherwise launchable title.

## Native Beta 2 settings

| Key | Global settings | Per-game override |
| --- | --- | --- |
| `display` | 240, 480 (480i), 480p | Not supported |
| `timing` | auto, ntsc, pal | Default (inherit), auto, ntsc, pal |
| `dither` | on, off | Default (inherit), on, off |
| `shading` | 15, 24 (experimental) | Default (inherit), 15, 24 |
| `controller` | auto, analog, d2a | Default (inherit), auto, analog, d2a |

Settings > Ember PS1 Core contains the global rows.
**Unchanged** means POPSLoader will leave a hand-written native key alone;
**Default** removes a previously managed native key. An explicit value
manages only that key, preserving comments and unknown lines.

On an Ember game-list row, press **L2** to edit four per-game overrides.
Default removes the key so the Ember global value applies. Display
is intentionally global-only. Unlike POPSTARTER, Ember creates writable
memory cards beside each title inside `EMBER/games/<name>/`.

## Release gating

Host regression tests pin directory enumeration, per-device identity,
name-derived artwork, settings preservation, and keep-IOP argv.
Native PS2 build success **does not** establish console compatibility.
Hardware verification must include: one/two USB drives, MX4SIO,
MMCE, ATA exFAT, SMB, UDPFS Files, controller input after handoff,
CUE/BIN launching, virtual-card writes, per-game/global setting
persistence, and preserving prior POPSTARTER/UDPFS behavior.
APA/PFS and i.Link require implementation before full RiptOPL parity.

Credits: Gageformer for Ember, RiptOPL/Open-PS2-Loader and
contributors for the device scanning/settings model; RiptOPL's
source and third-party Ember licensing apply independently.
