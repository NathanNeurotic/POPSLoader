# POPSLoader

Last updated: 2026-03-07

POPSLoader is a PlayStation 2 launcher for POPStarter, built on Enceladus runtime components with a Lua-driven UI/runtime flow.

## What This Project Is
- A packaged PS2 launcher (`POPSLOADER.ELF`) for browsing and launching PS1 `.VCD` titles.
- A runtime composed of embedded Lua scripts/assets and embedded IOP modules.
- A build + CI pipeline that verifies release package contents strictly.

## Current Feature Status

| Main menu option | Status |
|---|---|
| MMCE | Implemented |
| MX4SIO | Implemented |
| HDD (PFS) | Implemented |
| USB | Implemented |
| Disc (DKWDRV) | Implemented |
| HDD (exFAT) | Not implemented |
| SMB (v1) | Not implemented |

## Runtime Behavior (Current)
- Boot/runtime Lua is loaded from embedded assets.
- Settings are staged in UI and committed on Settings/Profile confirm/leave.
- Settings file path: `mc0:/POPSTARTER/.pldrs`.
- Configurable executable paths:
  - POPStarter path
  - DKWDRV path
- `mc?:/` alias is supported for executable path resolution (`mc0:/` then `mc1:/`).
- USB vs MX4SIO list split is based on mount-driver identity (`System.getMassMountDriver`), not path-name guessing.
- Cover sidecar lookup uses selected `.VCD` path with `.png` suffix.

## Release Package Contract
Current release ZIP layout is:

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

Legacy `POPS/*.tm2` payload entries are intentionally excluded.

## Installation (Prebuilt)
1. Download the latest `POPSLOADER.zip` release.
2. Extract and keep the directory layout exactly as packaged (`PS1_POPSLOADER/` and `POPS/`).
3. Copy both directories to your target storage root.
4. Put your PS1 `.VCD` files into the active backend `POPS/` location.
5. Launch `PS1_POPSLOADER/POPSLOADER.ELF` from your preferred loader.

## Build From Source

### Recommended (CI-like)
Use `ps2dev/ps2dev` and run:

```sh
make clean elfloader all
```

### Prerequisites
- PS2 toolchain environment (`PS2DEV`, `PS2SDK`, gsKit/ports).
- `make`, `ps2-packer`, and standard build tools.

### Build outputs
- `bin/enceladus.elf` (intermediate)
- `bin/POPSLOADER.ELF` (packed launcher)

## Repository Layout
- `src/`: EE runtime, Lua bindings, launch plumbing.
- `bin/POPSLDR/`: Lua runtime scripts and embedded source assets.
- `iop/`: embedded IOP payload sources + `bdm_query` RPC module.
- `modules/`: controller modules (`ds34bt`, `ds34usb`, `pademu`).
- `EMBED/`: embedded font/resources used at build time.
- `etc/`: boot script.
- `.github/workflows/compilation.yml`: CI build/package verification.
- `QA_REGRESSION_MATRIX.md`: manual/CI regression checklist.

## Known Limitations
- `HDD (exFAT)` and `SMB (v1)` menu entries are placeholders and currently return `Not Implemented Yet`.
- Hardware matrix coverage depends on manual validation runs.

## Credits
- POPSLoader by [israpps (El_isra)](https://github.com/israpps).
- Enceladus lineage by [Daniel Santos](https://github.com/DanielSant0s/Enceladus).

## License
GPLv3.
