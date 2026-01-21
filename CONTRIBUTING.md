# Contributing

## Branches and pull requests
Use the standard GitHub fork/branch workflow described in the project documentation:
1. Fork the project.
2. Create your feature branch (`git checkout -b feature/MyChange`).
3. Commit your changes.
4. Push the branch and open a PR.【F:docs/index.md†L123-L131】

## Style expectations (C/C++/Lua)
- Match the existing style in the file you are editing (indentation, brace placement, naming, and logging conventions). For C/C++, see the formatting and `DPRINTF` usage in `src/main.cpp`.【F:src/main.cpp†L108-L126】
- For Lua scripts, follow the conventions in `etc/boot.lua` and `bin/POPSLDR/system.lua` (indentation, function naming, and logging via `LOG`/`LOGF`).【F:etc/boot.lua†L2-L7】【F:bin/POPSLDR/system.lua†L1-L14】

## What to include in PR descriptions
Please include:
- The build command you ran (e.g., `make all`, `make package`, or `make clean elfloader all package`) and any relevant output or errors.【F:Makefile†L61-L146】【F:.github/workflows/compilation.yml†L23-L28】
- Any runtime checks you performed (device/emulator), including device type and logs. **TODO: verify preferred log format/location.**
- If your change affects runtime layout, note the old vs. new layout and any compatibility fallbacks you preserved.【F:README.md†L6-L10】【F:etc/boot.lua†L1-L1】

## How to run builds locally
- Standard build: `make all` (produces `bin/POPSLOADER.ELF`).【F:Makefile†L61-L69】
- Build with the ELF loader: `make elfloader` (builds `src/elf_loader/libcustom-elf-loader.a`).【F:Makefile†L107-L112】
- Package release archive: `make package` (creates `POPSLoader.7z`).【F:Makefile†L132-L135】
