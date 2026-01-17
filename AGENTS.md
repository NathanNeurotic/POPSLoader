# AGENTS.md — Enceladus / POPSLoader AI Operating Manual

## What am I looking at?

This repository builds the **POPSLoader** launcher (Lua UI + assets) on top of the Enceladus PS2 runtime. The build produces a packed `POPSLOADER.ELF` and bundles Lua scripts, PNG assets, and patch data required to boot **POPStarter** on PlayStation 2 hardware.

## Golden Rules (AI Safety + Scope)

1. **Docs-only by default.** The user explicitly requested documentation-only updates for this task.
2. **Do not touch embedded/binary assets** unless explicitly asked (IRX, PNG, BIN, ELF, 7z). These are required runtime artifacts.
3. **Keep initialization/reset ordering explicit** if you ever touch IOP reset logic (see `src/system.cpp` / `src/main.cpp`).
4. **Never guess**: if a behavior is unclear, label it “Unknown / requires confirmation.”
5. **When documenting behavior, cite the code** (C/C++ in `src/`, Lua in `bin/` and `etc/`).

## Repo Map (Key Directories)

- `src/` — Core C/C++ runtime, Lua bindings, and ELF loader integration.
- `bin/` — Lua launcher scripts, runtime assets, and packaged runtime files.
- `etc/` — Boot-time Lua script (`boot.lua`) and helper tooling.
- `iop/` — Embedded IOP assets (e.g., mmceman IRX).
- `modules/` — Optional DS3/DS4 controller modules (ds34usb/ds34bt).
- `sio2man/` — Required SIO2MAN IRX variants used at build time.

## Primary Workflows (Commands)

### Build (local)
```bash
make clean elfloader all SIO2MAN_IRX=sio2man/<variant>/sio2man.irx
```

### Package (archive)
```bash
make package
```

### Build all SIO2MAN variants
```bash
make variants
```

### Run via ps2client (network boot)
```bash
make run
```

> These targets are defined in the repo `Makefile`.

## Decision Table: “If user asks X, look at Y”

| User request | Start with these files |
| --- | --- |
| Build problems or toolchain setup | `Makefile`, `.github/workflows/compilation.yml` |
| Runtime boot flow / device detection | `src/main.cpp`, `etc/boot.lua` |
| POPStarter launch behavior | `bin/system.lua`, `src/luasystem.cpp` |
| POPStarter profiles | `bin/pops_profiles.lua` |
| ELF loader internals | `src/system.cpp`, `src/elf_loader/` |
| HDD support / mounting | `src/luaHDD.cpp`, `bin/system.lua` |
| IOP module list / init order | `src/main.cpp`, `Makefile` |

## Known Pitfalls / Gotchas (Evidence-based)

- **SIO2MAN IRX is mandatory at build time.** The Makefile errors if `sio2man/<variant>/sio2man.irx` is missing.
- **Device probing order matters.** The runtime probes `mmce*` and `mass*` roots for a `POPS/` directory and falls back to `mmce0:/` when needed.
- **POPSLoader/POPStarter co-location.** The launcher assumes `POPSTARTER.ELF` lives next to the runtime scripts (see `BOOT_PATH` usage and POPStarter profile defaults).
- **IOP reset ordering.** `CleanUp()` can reset the IOP and reload core modules; if changes are made here, ensure file I/O services are reinitialized before any ELF load.

## Evidence Index (Authoritative Files)

Start here when answering questions or documenting behavior:

- `Makefile`
- `src/main.cpp`
- `src/system.cpp`
- `src/luasystem.cpp`
- `src/luaplayer.cpp`
- `src/luaHDD.cpp`
- `etc/boot.lua`
- `bin/system.lua`
- `bin/pops_profiles.lua`
- `.github/workflows/compilation.yml`

