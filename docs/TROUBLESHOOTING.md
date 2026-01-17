# Troubleshooting

## Build Issues

### “Missing sio2man.irx”

**Cause:** The Makefile requires `SIO2MAN_IRX` to point at an existing `sio2man/<variant>/sio2man.irx` file.

**Fix:** Populate the `sio2man/` directory with a variant and pass `SIO2MAN_IRX=...` in the build command.

### Missing `7z`

**Cause:** `make package` uses the `7z` command.

**Fix:** Install `p7zip` / `7z` and retry packaging.

## Runtime Issues

### POPS directory not found

**Cause:** The runtime probes for `POPS/` under `mmce*` and `mass*` roots and falls back to `mmce0:/` if none are found.

**Fix:** Ensure a `POPS/` directory exists at one of the supported device roots.

### Boot script fatal errors

**Cause:** `etc/boot.lua` halts if the base directory is not ready or `system.lua` fails to load.

**Fix:** Confirm the runtime scripts and assets are co-located with `POPSLOADER.ELF` and the device is mounted.

### Lua crash log

**Cause:** The Lua panic handler writes `lua_crashlog.txt` and prints diagnostics to screen.

**Fix:** Inspect `lua_crashlog.txt` next to the runtime files for stack details.

## Evidence

- `Makefile`
- `src/main.cpp`
- `src/luaplayer.cpp`
- `etc/boot.lua`
- `bin/system.lua`
