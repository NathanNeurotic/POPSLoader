# Runtime Behavior

## Startup & Device Probing

1. The EE entrypoint (`src/main.cpp`) optionally resets the IOP and loads embedded IRX modules needed for file I/O, pads, USB, audio, and storage.
2. It probes device roots for a `POPS/` directory in this order: `mmce1:/`, `mmce0:/`, `mass0:/`, `mass1:/`, `mass2:/`, `mass3:/`. If none are found, it falls back to `mmce0:/`.
3. It sets the Lua boot path (`boot_path`) and runs the embedded Lua boot script (`etc/boot.lua`).

## Lua Boot Script Behavior (`etc/boot.lua`)

- Resolves a base directory from `System.GetArgv0()` and ensures the base directory is ready.
- Scans for `POPS/` across MMCE and mass devices; stores the result in `BOOT_DEVICE_ROOT`.
- Loads the embedded `system.lua` launcher and hands off to the UI.

## POPSLoader Launcher Behavior (`bin/system.lua`)

- Scans the selected `POPS/` directory for `.VCD` files and builds a game list.
- Supports MMCE, USB mass, and HDD-related behaviors (including POPS dependencies checks and caching).
- Launches POPStarter via `System.loadELF`, passing a boot parameter constructed from the selected game.

## HDD Support

- The Lua HDD binding loads PS2DEV9/ATAD/HDD/PS2FS IRX modules via `SifExecModuleBuffer` and exposes mount/unmount helpers.
- When booted from `hdd0:` paths, `etc/boot.lua` attempts to initialize HDD modules and mount partitions to resolve the boot path.

## Error Handling / Diagnostics

- The boot script halts with a fatal message if the base directory or `system.lua` cannot be resolved.
- Lua panics write a `lua_crashlog.txt` file to the current directory (if enabled) and display the error on-screen.

## Evidence

- `src/main.cpp`
- `src/system.cpp`
- `src/luaplayer.cpp`
- `src/luasystem.cpp`
- `src/luaHDD.cpp`
- `etc/boot.lua`
- `bin/system.lua`
