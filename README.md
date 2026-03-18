<a href=""><img width="1536" height="1024" alt="POPSLoader" src="https://github.com/user-attachments/assets/d7b54ca5-f088-4f82-8819-d8621a6b2fda" />
</a><br>
<a href="https://www.github.com/NathanNeurotic/Enceladus/releases">![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nathanneurotic/enceladus/total?style=plastic&logo=playstation%202&logoColor=white&logoSize=auto&label=Downloads&labelColor=orange&color=gold%20&link=https%3A%2F%2Fgithub.com%2FNathanNeurotic%2FEnceladus%2Freleases%2Ftag%2FMMCE)</a>

# POPSLoader

Last updated: 2026-03-17

POPSLoader is an open-source PlayStation 2 launcher for POPStarter, scripted in Lua and built on top of Enceladus runtime components.

This repository contains:
- the launcher (`POPSLOADER.ELF`),
- embedded runtime Lua scripts/assets,
- embedded IOP modules,
- and packaging/build logic for release artifacts.

## Project Lineage
- [POPSLoader](https://github.com/israpps/Enceladus/tree/popstarter) was created by [El_isra](https://github.com/israpps), and this repository is a forked continuation of that work.
- Derived from [Enceladus](https://github.com/DanielSant0s/Enceladus) by [DanielSant0s](https://github.com/DanielSant0s/).
- Maintains GPLv3 licensing lineage.

## Current Feature Status

Menu options are listed in the order they appear in the main menu:

| Main menu option | Status |
|---|---|
| MMCE | Implemented |
| MX4SIO | Implemented |
| HDD (exFAT) | Not implemented |
| HDD (PFS) | Implemented |
| USB | Implemented |
| SMB (v1) | Not implemented |
| Disc (DKWDRV) | Implemented |

## Installation (Prebuilt)

1. Download the latest `POPSLOADER.zip` release.
2. Extract and keep the packaged layout intact.
3. Copy `PS1_POPSLOADER/` and `POPS/` to your target storage.
4. Add PS1 `.VCD` files to the selected backend `POPS/` location.
5. Launch `POPSLOADER.ELF` using your preferred ELF launcher.

Package layout:

```text
PS1_POPSLOADER/
  POPSLOADER.ELF
  POPSTARTER.ELF
  APPINFO.PBT
  title.cfg
  icon.sys
  list.icn
  copy.icn
  del.icn
POPS/
  PATCH_5.BIN
```

Notes:
- `PS1_POPSLOADER/` can be installed/launched from any device path supported by your loader setup.
- `POPS/` content location is backend-dependent and must match the active launch backend expectations.
- CI validates the package manifest above and excludes legacy `POPS/*.tm2` payload entries.

## Runtime Behavior (Current)
- Boot/runtime Lua is loaded from embedded assets.
- Settings are staged in UI and committed on Settings/Profile confirm/leave.
- Settings file path: `mc0:/POPSTARTER/.pldrs`.
- BDMA module directory: `mc0:/POPSTARTER/`.
- Configurable executable paths:
  - POPStarter path (default: sidecar `POPSTARTER.ELF` next to launcher)
  - DKWDRV path (default: `mc0:/PS1_DKWDRV/DKWDRV.ELF`)
- `mc?:/` alias is supported for executable path resolution (`mc0:/` then `mc1:/`).
- USB vs MX4SIO list split is based on mount-driver identity (`System.getMassMountDriver`), not path-name guessing.
- Cover art lookup:
  - For non-HDD game lists: sidecar `.png` next to the selected `.VCD` file.
  - For HDD (PFS) game lists: `hdd0:__common/POPS/ART/<title>.png`.
  - A small in-memory cover cache (max 3 entries) is maintained per session.

## Requirements

### POPStarter runtime assets
- For POPStarter runtime binaries/packages, see:
  - [AnimMouse POPS binaries](https://github.com/AnimMouse/POPS-binaries/releases/)
- Typical required files include (depending on setup):
  - `IOPRP252.IMG`
  - `POPS.ELF`
  - `POPS.PAK`
  - `POPS_IOX.PAK`

### Game images
- Place PS1 games as `.VCD` files in backend `POPS/` paths.
- If needed, convert BIN/CUE to POPStarter-compatible VCD:
  - [PS1 Preservation link](https://tinyurl.com/PS1PRESERVATION)
  - [Archived POPS-VCD-Manager](https://web.archive.org/web/20250208180431/https://cdn.discordapp.com/attachments/1190221790925033542/1337432406419968101/POPS-VCD-Manager.7z?ex=67a8153d&is=67a6c3bd&hm=d72ab93151232edc0a6756989735a97bacd71bf16b8119bc1e8a96fe9880430b&)

### Optional cover art
- For non-HDD backends: sidecar cover image path is the same folder/name as the selected VCD, with `.png` extension.
- For HDD (PFS) backend: cover art is looked up from `hdd0:__common/POPS/ART/<title>.png`.
- Recommended format: PNG, non-interlaced, truecolor/RGBA.

### HDD (PFS) path notes
- HDD title scan checks `__.POPS`, `__.POPS0` through `__.POPS9` partitions (11 total).
- HDD dependency checks in launcher currently reference `hdd0:__common/POPS/` files.

## Supported Devices and Backends
- MMCE (`mmce0:/`, `mmce1:/`): supported.
- MX4SIO: supported (detected via mass mount driver classification).
- USB mass (`mass:/`, `mass1:/...`): supported.
- Internal HDD (`hdd0:`, PFS via numbered `pfsN:` slots): supported (PFS flow implemented).
- SMB menu entry: currently marked `Not Implemented Yet` in UI.
- Disc (DKWDRV): implemented via menu modal and launch-path check.

## Project Structure
- `src/`: EE runtime, Lua bindings, rendering/audio/input, launch plumbing.
- `bin/POPSLDR/`: runtime Lua scripts, bundled assets, POPStarter payload files.
- `iop/`: embedded IOP modules and `bdm_query` RPC module source.
- `modules/`: controller-related modules (`ds34bt`, `ds34usb`, `pademu`).
- `EMBED/`: resources embedded into the ELF at build time.
- `etc/`: boot script and helper scripts.
- `QA_REGRESSION_MATRIX.md`: hardware validation checklist and pass/fail matrix.
- `.github/workflows/compilation.yml`: CI build and packaging pipeline.

## Build From Source

### Recommended (same environment as CI)
Use `ps2dev/ps2dev` and run:

```sh
make clean elfloader all
```

### Local build prerequisites
- PS2 toolchain environment (`PS2DEV`, `PS2SDK`, gsKit/ports libs).
- `ps2-packer`, `make`, and standard build tools.

### Build outputs
- `bin/enceladus.elf` (intermediate)
- `bin/POPSLOADER.ELF` (packed launcher)

## Known Limitations
- `HDD (exFAT)` menu path is not implemented yet.
- `SMB (v1)` menu path is not implemented yet.
- Current release focus is stability/correctness/hardening, not new backend expansion.

## Credits
- [israpps (El_isra)](https://israpps.github.io/) for POPSLoader.
- [Daniel Santos](https://github.com/DanielSant0s/Enceladus) for Enceladus.
- [Berion](https://www.psx-place.com/members/berion.1431/) for graphics and design.
- [nuno6573](https://github.com/nuno6573/) for Cover Art System and supporting scripts.
- [Ripto / NathanNeurotic](https://github.com/NathanNeurotic) for project continuation, release work, and AI-assisted development persistence.
- [Hugopocked](https://ko-fi.com/hugopocked) for POPStarter fixes.
- [R3Z3N](https://github.com/saildot4k/) for [ps2store.com](https://www.ps2store.com/).
- [Codex](https://chatgpt.com/codex) for enabling high-velocity development iteration.

## Extra Thanks To Testers
- `@VizoR`
- `@bigol`
- `@nuno6573`
- `@P4NCHOL1NO`
- `@rorcarrot`
- `@UNDEAD`
- `@Berion`
- `@R3Z3N` (`ps2store.com`)
- `@Kamo`
- If I missed you, please contact me: [https://tinyurl.com/PS2SPACE](https://tinyurl.com/PS2SPACE)

<a href=""><img width="640" height="480" alt="Splash Screen" src="https://github.com/user-attachments/assets/da476654-0f17-46fb-b309-4b37116ff21c" /></a>

[Video Preview](https://youtu.be/CPQia4Nd88Y)

## License
This project retains the **GNU General Public License v3.0**.
