# Glossary

> Definitions are scoped to how terms are used in this repository. If a term’s broader meaning is not explicit in code, it is marked “Unknown / requires confirmation.”

- **POPSLoader**: The Lua-based launcher implemented by `bin/system.lua` and packaged as `POPSLOADER.ELF`.
- **POPStarter**: The ELF launched by POPSLoader; profile paths are defined in `bin/pops_profiles.lua`.
- **POPS**: Directory name (`POPS/`) scanned for `.VCD` games on supported devices.
- **VCD**: Game file extension (`*.VCD`) used by POPSLoader when building lists.
- **IRX**: IOP module binaries loaded at runtime (e.g., `iomanX_irx`, `fileXio_irx`, `sio2man_irx`).
- **EE**: Emotion Engine (PS2 main CPU); code in `src/main.cpp` runs on EE.
- **IOP**: I/O Processor; reset and module loading are handled in `src/main.cpp` and `src/system.cpp`.
- **MMCE**: Device prefix `mmce0:/` or `mmce1:/` probed for `POPS/` and used as default fallbacks.
- **USB mass**: Device prefixes `mass0:/` through `mass3:/` used for POPS scanning.
- **ELF loader**: Embedded loader built in `src/elf_loader/` and used by `load_elf` in `src/system.cpp`.

## Unknown / Requires Confirmation

- **PS1/PS2 disc formats**: The repo references disc types but does not define them beyond identifiers.

## Evidence

- `Makefile`
- `src/main.cpp`
- `src/system.cpp`
- `src/luasystem.cpp`
- `bin/system.lua`
- `bin/pops_profiles.lua`
