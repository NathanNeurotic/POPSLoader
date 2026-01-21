# Truth Sheet (audit, ground-truth only)

> **DEPRECATED**: This file is no longer maintained as canonical documentation. For current launch behavior and device rules, see `docs/LAUNCH_PIPELINE.md`. For runtime layout, see `docs/RUNTIME_LAYOUT.md`.

## What this project is
POPSLoader is an open-source launcher for POPStarter, scripted in Lua and based on the Enceladus project.【F:README.md†L1-L4】

## What it builds / outputs
- Main EE binary is built as `bin/enceladus.elf`, then stripped and packed into `bin/POPSLOADER.ELF`.【F:Makefile†L30-L33】【F:Makefile†L66-L69】
- `make package` creates `POPSLoader.7z` containing `POPSLOADER.ELF`, `bin/POPSLDR/*`, `bin/changelog`, plus `LICENSE` and `README.md`.【F:Makefile†L132-L135】
- CI uploads `POPSLoader.7z` as the `POPSLDR` artifact in GitHub Actions.【F:.github/workflows/compilation.yml†L29-L35】

## How it’s built (toolchain / make targets / env vars)
- Build uses PS2DEV/ps2sdk toolchain and libraries (e.g., `PS2SDK`, `PS2DEV`, `ps2-packer`, `bin2c`).【F:Makefile†L30-L48】【F:Makefile†L41-L49】
- Main targets: `all` (builds `bin/POPSLOADER.ELF`), `elfloader` (builds `src/elf_loader/libcustom-elf-loader.a`), `package`, `clean`, `rebuild`, `run`, `reset`.【F:Makefile†L61-L146】
- CI uses `ps2dev/ps2dev:latest` container and runs `make clean elfloader all package`.【F:.github/workflows/compilation.yml†L8-L28】

## Runtime file layout expectations (current)
- Usage docs instruct placing `POPSLOADER.ELF` and `POPSLDR/` folder on USB device or internal HDD.【F:README.md†L6-L7】
- Boot Lua prepends Lua module search paths for `POPSLDR/` on current dir, `mass:/`, and `mc0:/mc1:/`.【F:etc/boot.lua†L1-L1】
- On startup, `boot.lua` tries to execute `POPSLDR/system.lua` relative to current working directory; it errors if not found.【F:etc/boot.lua†L55-L60】
- Packaged `bin/POPSLDR/` contains `system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`, and `PATCH_5.BIN` (used for POPStarter UI texture replacement).【F:bin/POPSLDR/system.lua†L1-L11】【F:bin/README.md†L9-L10】

## Launching / boot path determination
- `main.cpp` derives `boot_path` from argv (supports `/`, `\`, or `:` delimiters), and patches `mass:/` paths by removing an extra slash (`mass:/X` -> `mass:X`).【F:src/main.cpp†L65-L96】
- `boot.lua` reads `System.GetArgv0()` and, if launched from `hdd0:`, parses mount data, initializes/mounts the HDD partition, and updates the current directory to the boot path.【F:etc/boot.lua†L32-L53】

## Key folders and what they contain
- `src/`: C/C++ source, including entrypoint `main.cpp` and Lua/graphics/pad subsystems.【F:src/main.cpp†L1-L22】
- `etc/`: build-time Lua boot script (`boot.lua`) embedded into the ELF via bin2c.【F:Makefile†L71-L73】【F:etc/boot.lua†L1-L60】
- `bin/`: packaged runtime assets and POPSLDR scripts (`bin/POPSLDR/*`), plus `bin/changelog`.【F:Makefile†L132-L135】【F:bin/POPSLDR/system.lua†L1-L11】
- `EMBED/`: PNG/TTF assets embedded into the binary at build time.【F:Makefile†L75-L79】
- `iop/embed/`: embedded IOP module(s) (e.g., `mmceman.irx`).【F:iop/embed/mmceman.irx†L1-L1】
- `modules/`: external modules such as `ds34bt` and `ds34usb` built as libs and IOP modules.【F:Makefile†L51-L60】【F:Makefile†L94-L106】
- `samples/`: sample Lua content (e.g., `fractal.lua`, `helloworld.lua`, etc.).【F:samples/fractal.lua†L1-L1】

## Gotchas / device-path rules (from code)
- `boot_path` normalization patches `mass:/` paths by shifting the slash (likely to handle `mass:/` formatting quirks).【F:src/main.cpp†L88-L96】
- Lua package path explicitly includes `mass:/POPSLDR/?.lua` and `mc0:/mc1:/POPSLDR/?.lua` for module discovery.【F:etc/boot.lua†L1-L1】
- HDD boot path handling in `boot.lua` expects `hdd0:` format and requires mounting partitions before setting the current directory.【F:etc/boot.lua†L32-L53】
- POPStarter paths used by default in `system.lua` point to `mass:/POPS/POPSTARTER.ELF` and dependencies under `mass:/POPS/` or HDD `pfs1:/POPS/` depending on device selection.【F:bin/POPSLDR/system.lua†L25-L27】【F:bin/POPSLDR/system.lua†L63-L74】

## Audit commands used (traceability)
- `ls`
- `find .. -name AGENTS.md -print`
- `sed -n '1,200p' README.md`
- `sed -n '1,200p' Makefile`
- `ls docs`
- `find src -maxdepth 2 -type f -print`
- `find .github -maxdepth 3 -type f -print`
- `sed -n '1,200p' docs/index.md`
- `sed -n '1,200p' docs/_config.yml`
- `sed -n '1,200p' .github/workflows/compilation.yml`
- `ls etc`
- `sed -n '1,220p' src/main.cpp`
- `sed -n '1,220p' src/system.cpp`
- `sed -n '1,200p' etc/boot.lua`
- `find bin -maxdepth 2 -type f -print`
- `sed -n '1,200p' bin/README.md`
- `sed -n '1,200p' bin/POPSLDR/system.lua`
- `ls iop`
- `ls iop/embed`
- `ls modules`
- `ls samples`
- `sed -n '1,200p' src/elf_loader/Makefile`
- `sed -n '1,200p' src/luasystem.cpp`
- `rg -n "GetArgv0" -S src etc`
- `sed -n '660,760p' src/luasystem.cpp`
