Last updated: 2026-03-05

# COMPONENTS

## Purpose
Technical map of PS2-specific modules and where responsibilities live.

## Component Index
- [ ] `bin/POPSLDR/`: runtime scripts/assets/profile data used by launcher.
- [ ] `src/`: EE-side runtime (boot, Lua bridge, rendering, audio, input, launch helpers).
- [ ] `iop/bdm_query/`: IOP RPC module used to enumerate block-device backends.
- [ ] `iop/embed/`: embedded IRX payloads (BDM, MMCE, MX4SIO, FATFS/VFAT-related modules).
- [ ] `modules/ds34bt`, `modules/ds34usb`, `modules/pademu`: controller support modules.
- [ ] `EMBED/`: assets converted into embedded blobs at build time.

## Runtime Lua Layer (`bin/POPSLDR`)
- [ ] `system.lua`: backend detection, game list assembly, launch policy, POPStarter packing helpers.
- [ ] `ui.lua`: scene model, input handling, page transitions, user-facing flows.
- [ ] `images.lua`: image asset mapping.
- [ ] `pops_profiles.lua`: profile metadata and related config.

## EE Native Layer (`src`)
- [ ] `main.cpp`: startup sequence, IOP/runtime initialization, boot script execution.
- [ ] `luasystem.cpp`: Lua `System.*` APIs, BDM integration, mass backend helpers, MX4SIO init hooks.
- [ ] `system.cpp`, `render.cpp`, `graphics.cpp`, `sound.cpp`, `pad.cpp`: platform services exposed to Lua.
- [ ] `elf_loader/`: custom ELF loader library used in launch flow.

## IOP and Device Layer (`iop`)
- [ ] `iop/bdm_query`: exposes block-device backend metadata via RPC.
- [ ] `iop/embed/*.irx`: embedded runtime modules loaded as needed.
- [ ] MX4SIO path depends on embedded MX4SIO IRX and BDM/FATFS readiness.

## Build and Packaging Layer
- [ ] `Makefile`: compiles EE code, builds optional modules, embeds Lua/assets/IRX, packs final ELF.
- [ ] `.github/workflows/compilation.yml`: CI compile + release zip assembly + package validation.
- [ ] Release package structure is validated around `PS1_POPSLOADER/` and `POPS/` roots.

## Boundary Rules
- [ ] Keep Lua orchestration changes in Lua unless native API changes are required.
- [ ] Keep backend classification contract stable across Lua and native (`luasystem.cpp`) layers.
- [ ] Keep packaging contract stable unless migration steps are documented.
- [ ] Do not couple UI scene code directly to low-level IRX loading details.

## Change Entry Points
- [ ] UI behavior issues: start in `bin/POPSLDR/ui.lua`.
- [ ] Device classification/listing issues: start in `bin/POPSLDR/system.lua`, then `src/luasystem.cpp`.
- [ ] IRX load/order issues: inspect `src/main.cpp`, `src/luasystem.cpp`, and `iop/` modules.
- [ ] Build/package issues: inspect `Makefile` and `.github/workflows/compilation.yml`.
