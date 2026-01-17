# Repository Overview

## Audit Summary (Evidence-Based)

- **Primary languages:** C/C++ for the runtime (`src/`), Lua for the launcher/UI (`bin/`, `etc/`).
- **Build system:** GNU Make with PS2SDK includes (root `Makefile`).
- **Primary runtime entrypoint:** `src/main.cpp` initializes IOP services and executes the embedded Lua boot script.
- **Primary launcher logic:** `bin/system.lua` implements POPSLoader behavior (game scanning, POPStarter launch).
- **Packaging:** `make package` emits `POPSLoader.7z` and a `bin/pkg/` staging directory.
- **CI:** GitHub Actions builds per `sio2man` variant in a `ps2dev/ps2dev` container and uploads ELF + 7z artifacts.

## Inventory & Entry Points

### Primary Languages
- **C/C++:** Core runtime, system helpers, Lua bindings, and ELF loader integration live under `src/`.
- **Lua:** Boot flow and UI/launcher logic live under `etc/` and `bin/`.
- **Make:** Build orchestration in the root `Makefile`.

### Entrypoints & Outputs
- **EE entrypoint:** `src/main.cpp` (built into `bin/enceladus.elf`).
- **Packed runtime:** `bin/POPSLOADER.ELF` created by `ps2-packer`.
- **Lua boot:** Embedded `etc/boot.lua` and `bin/system.lua` at build time.

## Top-Level Directory Guide

- `src/` — Runtime C/C++ (Lua bindings, ELF loader, system helpers).
- `bin/` — Runtime Lua scripts, UI assets, and packaging inputs.
- `etc/` — Boot script and helper tooling.
- `iop/` — Embedded IOP module assets.
- `modules/` — External modules (e.g., ds34usb/ds34bt).
- `sio2man/` — Required SIO2MAN IRX variants.

## How We Derived This (Deterministic Audit)

1. Read the root `Makefile` to map build outputs, packaging targets, and embedded resources.
2. Audited `src/main.cpp`, `src/system.cpp`, and `src/luaplayer.cpp` to confirm runtime entrypoints and Lua initialization.
3. Audited `etc/boot.lua` and `bin/system.lua` to confirm launcher behavior and device scanning.
4. Reviewed `.github/workflows/compilation.yml` for CI build and release behavior.

## Evidence

- `Makefile`
- `src/main.cpp`
- `src/system.cpp`
- `src/luaplayer.cpp`
- `etc/boot.lua`
- `bin/system.lua`
- `bin/pops_profiles.lua`
- `.github/workflows/compilation.yml`
