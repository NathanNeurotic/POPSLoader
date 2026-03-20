# POPSLoader

Last updated: 2026-03-20

POPSLoader is a PlayStation 2 launcher for POPStarter built on top of Enceladus runtime components and driven primarily by embedded Lua modules.

This repository contains:
- the launcher (`POPSLOADER.ELF`),
- embedded runtime Lua scripts and assets,
- embedded IOP modules,
- packaging/build logic,
- repository-side status, rules, and regression documentation.

## CI-First Build Policy

Local PS2 SDK environments are not treated as authoritative in this project. Build and package validity are defined by GitHub Actions CI in `.github/workflows/compilation.yml`.

Current CI behavior:
- uses `ps2dev/ps2dev:latest`,
- validates `etc/boot.lua`,
- runs `make clean elfloader all`,
- assembles `POPSLOADER.zip`,
- verifies the exact ZIP contents.

If you attempt a local build anyway, use the same command as CI:

```sh
make clean elfloader all
```

Treat local success or failure as advisory only.

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

## Packaged Layout

The current CI release ZIP is expected to contain exactly:

```text
PS1_POPSLOADER/
  APPINFO.PBT
  POPSLOADER.ELF
  POPSTARTER.ELF
  copy.icn
  del.icn
  icon.sys
  list.icn
  title.cfg
POPS/
  PATCH_5.BIN
```

Notes:
- CI rejects extra or missing files in that ZIP layout.
- Legacy `POPS/*.tm2` payload entries are forbidden by CI.
- `BUILD_INFO.txt` is generated in the CI workspace before compile, but it is not currently included in `POPSLOADER.zip`.

## Runtime Behavior (Repo-Verified)

- Boot/runtime Lua is loaded from embedded assets, not filesystem Lua files.
- Settings are staged in UI and committed when leaving Settings/Profile.
- Settings file path is `mc0:/POPSTARTER/.pldrs`.
- Persisted settings currently include:
  - selected profile,
  - POPStarter path,
  - BDMA mode,
  - DKWDRV path,
  - video standard (`NTSC`/`PAL`).
- `mc?:/` alias resolution is supported for executable paths (`mc0:/` then `mc1:/`).
- USB vs MX4SIO list split is based on mount-driver identity (`System.getMassMountDriver`), not root-name guessing.
- Non-HDD cover art uses a sidecar PNG next to the selected `.VCD`.
- HDD cover art uses `hdd0:__common/POPS/ART/<title>.png`.
- HDD title scan checks `__.POPS`, `__.POPS0`, and `__.POPS1` through `__.POPS9`.
- `ui.lua` can display a build stamp from `BUILD_INFO.txt` if the file exists beside the app.

## Installation Notes

1. Keep the packaged `PS1_POPSLOADER/` and `POPS/` layout intact.
2. Place PS1 `.VCD` files in the backend-specific `POPS/` location used by the selected device flow.
3. Launch `POPSLOADER.ELF` with your preferred ELF launcher.

Backend notes:
- MMCE is supported through `mmce0:/` and `mmce1:/`.
- MX4SIO is supported through mount-driver classification on `mass*:/` roots.
- USB mass storage is supported through `mass:/` and related roots.
- Internal HDD support is currently the PFS path only.
- The `SMB (v1)` and `HDD (exFAT)` menu entries still report `Not Implemented Yet`.

## POPStarter and Asset Requirements

Typical POPStarter-side runtime files depend on the selected backend and setup.

Repository-visible requirements and references:
- CI packages `POPS/PATCH_5.BIN`.
- Current code contains optional dependency-check paths for:
  - `mass:/POPS/POPS_IOX.PAK` on USB,
  - `hdd0:__common/POPS/POPS.ELF` and `hdd0:__common/POPS/IOPRP252.IMG` on HDD.
- Those dependency checks are gated by `PLDR.CHECK_POPSTARTER_FILES`, which currently defaults to `false`.
- POPStarter executable resolution still matters regardless of that flag.

## Repository Structure

- `src/`: EE runtime, Lua bindings, rendering/audio/input, launch plumbing.
- `bin/POPSLDR/`: runtime Lua scripts, bundled assets, and packaged support files.
- `iop/`: embedded IOP modules and `bdm_query` RPC module source.
- `modules/`: controller-related modules (`ds34bt`, `ds34usb`, `pademu`).
- `EMBED/`: resources embedded into the ELF at build time.
- `etc/`: boot script and helper scripts.
- `QA_REGRESSION_MATRIX.md`: hardware validation checklist and pass/fail matrix.
- `.github/workflows/compilation.yml`: authoritative CI build and packaging pipeline.

## Known Limitations

- `HDD (exFAT)` is not implemented yet.
- `SMB (v1)` is not implemented yet.
- Device-lock metadata exists in UI state, but current menu flow does not enforce device switching restrictions.
- Broader artwork management is not implemented beyond current local PNG lookup.

## Credits

- El_isra for POPSLoader.
- Daniel Santos for Enceladus.
- Berion for graphics and design.
- nuno6573 for artwork-related contributions.
- Community testers and contributors who helped validate recent runtime behavior.

## License

This project is licensed under the GNU General Public License v3.0.
