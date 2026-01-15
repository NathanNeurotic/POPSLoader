# Repository Audit & Inventory (Initial Pass)

This document captures a lightweight inventory of key runtime components relevant to boot/ELF loading and IOP reset behavior.

## Entry points and boot flow
- `src/main.cpp` initializes SIF RPC, loads core IRX modules (including iomanX/fileXio), and brings up memory card, pad, and audio services before entering the main loop.

## System lifecycle helpers
- `src/system.cpp` provides IOP reset and teardown logic via `IOP_Reset` and `CleanUp`, and includes module-loading helpers like `load_modules` that reload IOP-side services after reset.

## Lua bindings and GUI entrypoints
- `src/luasystem.cpp` exposes system APIs to Lua, including `System.loadELF`, which prepares argv entries and triggers ELF loading.
- `bin/system.lua` invokes `System.loadELF` for POPStarter launch with a configurable reboot flag and extra arguments.

## ELF loading stack
- `src/elf_loader/src/elf.c` implements `LoadELFFromFile`, which validates the ELF, prepares argv, and executes the embedded loader.
- `src/elf_loader/src/loader/src/loader.c` handles the low-level SifLoadElf sequence and performs an IOP reset in its own flow before executing the final entrypoint.

## Notes for future audits
- Ensure any IOP reset path reinitializes all required I/O and RPC services prior to file access.
- Validate that Lua-level `System.loadELF` callers pass correct argv ordering and reboot flags.
