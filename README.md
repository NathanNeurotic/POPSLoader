# Enceladus (POPSLoader runtime)

Enceladus in this repo is a PlayStation 2 homebrew runtime plus the **POPSLoader** launcher: a Lua-driven UI that boots **POPStarter** and scans storage devices for PS1 `.VCD` content. The build produces a packed `POPSLOADER.ELF` alongside runtime Lua scripts and assets for deployment on PS2 hardware.

## Features

- Lua runtime that boots an embedded `boot.lua`, then chains into the packaged `system.lua` launcher logic.
- Loads embedded IOP modules for storage, input, audio, and USB support before running Lua.
- Scans `POPS/` folders on MMCE and USB mass devices to build game lists from `.VCD` files.
- POPStarter profile selection and configurable POPStarter ELF paths in Lua.

## Supported Targets

- PlayStation 2 (EE/IOP) homebrew builds via PS2SDK/ps2dev toolchains.

## How It Works (High Level)

1. The EE entry point (`src/main.cpp`) resets the IOP (optional), loads embedded IRX modules, and initializes pad, audio, and file I/O.
2. The embedded boot script (`etc/boot.lua`) establishes the base directory, detects a POPS device root, and loads the embedded `system.lua` launcher.
3. The launcher (`bin/system.lua`) scans for `.VCD` titles under `POPS/`, manages POPStarter profiles, and calls `System.loadELF` to launch POPStarter with game arguments.

## Quick Start (Build + Package)

> This repo requires a PS2SDK toolchain and the `sio2man` IRX variants directory (see `sio2man/*/sio2man.irx`).

```bash
make clean elfloader all SIO2MAN_IRX=sio2man/<variant>/sio2man.irx
make package
```

Artifacts are written to `bin/` and a `POPSLoader.7z` is created by `make package`.

## Run / Deploy / Use

Deployment expects the following runtime files to live together in the same folder on your target device:

```
POPSLoader/
├── POPSLOADER.ELF
├── POPSTARTER.ELF
├── *.lua
├── *.png
└── PATCH_5.BIN
```

The runtime discovers PS1 titles by scanning `POPS/` on supported devices. If no executable path is provided at boot, the runtime probes for a `POPS/` directory in this order: `mmce1:/`, `mmce0:/`, `mass0:/`, `mass1:/`, `mass2:/`, `mass3:/`, falling back to `mmce0:/` as a default.

## Configuration

- **Build flags (Makefile)**: `RESET_IOP`, `DEBUG`, `PS2LINK_IP`, `SIO2MAN_IRX`, and output names like `EE_BIN` / `EE_BIN_PKD`.
- **Launcher profiles (Lua)**: `bin/pops_profiles.lua` defines POPStarter profile paths and the default profile.
- **Runtime behavior (Lua)**: `bin/system.lua` contains POPStarter launch flags and game list handling.

## Artifact / Release Layout

- Local build outputs: `bin/enceladus.elf` (unpacked) and `bin/POPSLOADER.ELF` (packed).
- Packaging (`make package`) creates `bin/pkg/` with Lua/assets and emits a `POPSLoader.7z` archive.
- CI builds per `sio2man` variant and uploads `POPSLOADER_<variant>.ELF` plus a `POPSLoader_<variant>.7z` archive.

## Troubleshooting (Quick Notes)

- Build fails with “Missing sio2man.irx”: ensure `sio2man/<variant>/sio2man.irx` exists and pass `SIO2MAN_IRX=...`.
- Runtime cannot find `POPS/`: verify the device path uses the supported roots and the `POPS/` directory exists.
- Lua crash logs may appear as `lua_crashlog.txt` in the current directory when the Lua panic handler triggers.

## Deeper Documentation

- [docs/REPO_OVERVIEW.md](docs/REPO_OVERVIEW.md)
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/BUILD_AND_RELEASE.md](docs/BUILD_AND_RELEASE.md)
- [docs/CONFIGURATION.md](docs/CONFIGURATION.md)
- [docs/RUNTIME_BEHAVIOR.md](docs/RUNTIME_BEHAVIOR.md)
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)
- [docs/SECURITY_AND_SECRETS.md](docs/SECURITY_AND_SECRETS.md)
- [docs/GLOSSARY.md](docs/GLOSSARY.md)
- [docs/CHANGELOG_NOTES.md](docs/CHANGELOG_NOTES.md)

## Sources

- `Makefile`
- `src/main.cpp`
- `src/luaplayer.cpp`
- `src/luasystem.cpp`
- `etc/boot.lua`
- `bin/system.lua`
- `bin/pops_profiles.lua`
- `.github/workflows/compilation.yml`
- `bin/changelog`
