# BOOT_HARDENING.md

## boot_dir derivation
- `boot_dir` is derived from `argv0` in `setLuaBootPath(...)`.
- If `argv0` ends with `.elf` (case-insensitive), `boot_dir` is set to the containing directory.
- Otherwise, `argv0` is treated as a directory-like path.
- Path separators are normalized (`\` → `/`) and `NormalizeDirPath(...)` enforces trailing `/` and device-path normalization.

## runtime gating rules
- Runtime boot classification is computed from `boot_path`/`argv0` prefixes/content:
  - `is_pfs_boot`: starts with `pfs` or contains `hdd0:`
  - `is_mass_boot`: starts with `mass`
  - `is_mmce_boot`: starts with `mmce`
  - `is_mx4sio_boot`: starts with `mx4sio`
- Safety behavior:
  - If `is_pfs_boot`, mass/USB stack is not initialized at boot.
  - Mass wait retry loop runs only when `is_mass_boot`.
  - No early MX4SIO backend load at boot; MX4SIO initialization remains runtime (`System.initMX4SIO`).
- `chdir(boot_dir)` is always attempted; on failure, diagnostics include `boot_dir`, `argv0`, and `errno`.

## entry script search order (flat-first)
1. `boot_dir .. "system.lua"`
2. `boot_dir .. "POPSLDR/system.lua"`
3. `"system.lua"` (relative)
4. `"POPSLDR/system.lua"` (relative)

If all attempts fail, the Lua error contains:
- `boot_dir`
- `cwd`
- `argv0`
- attempted paths list
- last loader error

## hardware validation checklist (YES/NO)
- boots to UI from USB/mass: NO
- boots to UI from HDD/PFS: NO
- entering MX4SIO page still works (init occurs there, not at boot): NO
- missing script produces error screen with attempted paths (not black screen): NO
