# Agent Notes

## Scope
This file applies to the entire repository.

## Repository orientation
- Lua bindings live in `src/luasystem.cpp`.
- System/IOP lifecycle helpers live in `src/system.cpp` and declarations in `src/include/system.h`.
- The embedded ELF loader lives in `src/elf_loader/`.
- The launcher Lua scripts live in `bin/`.

## Guidance
- Prefer minimal, surgical changes and keep initialization/cleanup ordering explicit.
- If you change IOP reset behavior, verify that required file I/O services are reinitialized before invoking ELF loading.
