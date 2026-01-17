# Architecture

## High-Level Components

1. **EE Runtime (C/C++)**
   - Initializes SIF/IOP, loads IRX modules, and launches the embedded Lua boot script.
   - Hosts Lua bindings for system, graphics, input, audio, and HDD.

2. **Embedded Boot & Launcher (Lua)**
   - `etc/boot.lua` determines the base directory and loads the embedded `system.lua`.
   - `bin/system.lua` implements POPSLoader UI logic, game list scanning, and POPStarter invocation.

3. **Embedded ELF Loader**
   - A custom ELF loader is built under `src/elf_loader/` and invoked by `load_elf` helpers in `src/system.cpp`.

## Boot Flow (Runtime Control)

1. **EE initialization** (`src/main.cpp`)
   - Optionally resets IOP.
   - Loads embedded IOP modules (iomanX, fileXio, sio2man, mmceman, mcman, mcserv, padman, usbd, ds34*, bdm, usbmass, cdfs, audsrv).
   - Initializes graphics, pads, and sets the working directory.

2. **Lua boot script** (`etc/boot.lua`)
   - Resolves the boot path and base directory.
   - Probes devices for a `POPS/` directory and records `BOOT_DEVICE_ROOT`.
   - Loads the embedded `system.lua`.

3. **Launcher loop** (`bin/system.lua`)
   - Builds game lists by scanning `POPS/` for `.VCD` files.
   - Lets the user select a title/profile.
   - Calls `System.loadELF` to launch POPStarter with arguments.

## Data & Asset Flow

- **Embedded resources**: `etc/boot.lua`, `bin/system.lua`, and assets from `EMBED/` are converted with `bin2c` and linked into the ELF by the Makefile.
- **Runtime assets**: Lua and PNG files are shipped alongside `POPSLOADER.ELF` and copied into `bin/pkg/` during packaging.

## Evidence

- `src/main.cpp`
- `src/luaplayer.cpp`
- `src/luasystem.cpp`
- `src/system.cpp`
- `src/elf_loader/Makefile`
- `etc/boot.lua`
- `bin/system.lua`
- `Makefile`
