# Configuration

## Build-Time Configuration (Makefile)

| Setting | Purpose | Default | Evidence |
| --- | --- | --- | --- |
| `RESET_IOP` | Enables IOP reset in `main.cpp` via `-DRESET_IOP`. | `1` | `Makefile`, `src/main.cpp` |
| `DEBUG` | Enables debug logging via `-DDEBUG`. | `0` | `Makefile`, `src/main.cpp` |
| `PS2LINK_IP` | IP used by `make run` and `make reset` (ps2client). | `192.168.1.10` | `Makefile` |
| `SIO2MAN_IRX` | Path to the required `sio2man.irx` variant. | `sio2man/sio2man/sio2man.irx` | `Makefile` |
| `EE_BIN` / `EE_BIN_PKD` | Output ELF names. | `bin/enceladus.elf` / `bin/POPSLOADER.ELF` | `Makefile` |

## Runtime Configuration (Lua)

### POPStarter profiles

`bin/pops_profiles.lua` defines POPStarter profile paths and the default profile:

- `DEFAULT_PROFILE` selects the active profile.
- `PLDR.PROFILES` lists POPStarter ELF paths (e.g., `POPSTARTER.ELF`, `POPSTARTER_DEBUG.ELF`).

### POPStarter launch behavior

`bin/system.lua` controls launch flags and the default POPS game path:

- `PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER` toggles IOP reset during POPStarter launch.
- `PLDR.POPSTARTER_PATH` defaults to `POPSTARTER.ELF` next to POPSLoader.
- `PLDR.GAMEPATH` defaults to the detected POPS root.

## Unknown / Requires Confirmation

- No dedicated external config file (INI/JSON) was found in-repo; if the launcher reads configuration from external storage, it is not evident in the audited files.

## Evidence

- `Makefile`
- `src/main.cpp`
- `bin/pops_profiles.lua`
- `bin/system.lua`
