# Ember PS1 core in POPSLoader — development integration

**Status: in development, host and physical-PS2 verification required.**
This is adapted from [RiptOPL's Ember integration](https://github.com/NathanNeurotic/Open-PS2-Loader/blob/rebuild/main/docs/EMBER-INTEGRATION-PLAN.md) and [Gageformer's Ember](https://github.com/Gageformer/Ember).
Ember is a second PS1 emulator alongside POPStarter, *not* a VCD decoder.
POPSLoader never bundles a console BIOS.

## Development release package (PR #600)

The new installable `PS1_POPSLOADER.zip` has `APPS/PS1_POPSLOADER/` with **exactly eight** files: `POPSLOADER.ELF`, `POPSTARTER.ELF`, `icon.sys`, `list.icn`, `copy.icn`, `del.icn`, `title.cfg`, and `APPINFO.PBT`. `POPS/` is populated from a pinned RiptOPL source revision, including its POPStarter versions and device modules; `EMBER/` is populated from a separately pinned RiptOPL Ember revision. The ZIP also carries `PS1_POPSLOADER.psu`.

The standalone `PS1_POPSLOADER.psu` is a PS2 memory-card save with save-directory **header** `PS1_POPSLOADER` and only the eight files immediately below that header. There is no nested folder in the PSU; its contents are verified byte-for-byte against `APPS/PS1_POPSLOADER/`. Import the PSU to a memory card, or copy the application directory manually; deploy `POPS/` and `EMBER/` to the storage-device root independently.

`EMBER/games/ExampleGame/ExampleGame.cue` and `ExampleGame.bin` illustrate the expected filenames. **ExampleGame.bin is intentionally empty and not playable.** Remove the example or replace it with your own legal disc image; do not mistake it for test media. Add your own BIOS and games separately. The Ember core is redistributed **unmodified** with `EMBER/LICENSE-BETA.txt` and its official-project link, under Gageformer's beta distribution conditions; no console BIOS is supplied.

The [Ember Watch](../.github/workflows/ember-watch.yml) compares the official `ember.elf` SHA-256 with RiptOPL's current verified copy (including same-tag hotfixes). After merging into the repository's default branch, its weekly schedule can advance **only the Ember source pin on `dev`**, leaving the tested POPS pin fixed and dispatching a rolling build when needed. A missing digest, unverified RiptOPL copy, invalid MIPS ELF or missing licence stops the update.

## Device roots and library

The PS1 game page appends Ember titles from the **same current device**
as the VCD list. Ember root scanning handles USB (including multiple
independent drives), MX4SIO, MMCE, internal exFAT/ATA, network SMB and
UDPFS Files where their corresponding mounts exist. It does not reinterpret
a UDPFS source as USB. APA/PFS HDD `__.EMBER` and `__.EMBER0` through
`__.EMBER9` partitions now have a separate scanner and a writable PFS
mount preserved across the keep-IOP handoff. This path is **host-tested
only**; real console write-through, controller recovery and VMC behavior
remain unverified. i.Link remains unavailable in POPSLoader's device
carousel. Do not claim full hardware parity.

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
    ember.elf               # bundled unmodified Gageformer Ember beta core; licence included
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
APA/PFS code is implemented but requires physical console verification.
i.Link still requires implementation. Neither is certified for parity.

Credits: Gageformer for Ember, RiptOPL/Open-PS2-Loader and
contributors for the device scanning/settings model; RiptOPL's
source and third-party Ember licensing apply independently.
