# POPSLoader Launch Pipeline (Single Source of Truth)

This document describes **how POPSLoader constructs and hands off the POPStarter boot string**, based on the current codebase. It is the definitive reference for launch behavior. If behavior is unknown or outside this repo, it is explicitly marked as **TODO: verify**.

## 1) Terminology and invariants

**Boot path**
- The path POPSLoader was launched from (boot argv[0] if available, else fallback). Used to derive the app directory.

**App dir (APP_DIR)**
- The directory used for runtime assets (Lua scripts, images, IRX). Derived from the launch path.

**POPS root**
- The directory that POPStarter expects to contain VCDs (e.g., `mass:/POPS/`, `smb:/POPS/`, or a mounted `pfs` path).
- POPSLoader **must** build a fully qualified VCD path from this root and pass it to POPStarter.

**VCD basename**
- The filename portion of the VCD (e.g., `SLUS_012.34.VCD` or `XX.SLUS_012.34.VCD`).
- This is the `game` value passed to the launch pipeline.

**VCD full path / boot string**
- The concatenation of the POPS root and the normalized VCD basename (including any required prefix).
- This is the boot string passed to the ELF loader as an argument.

**Launch policy inputs**
- POPSLoader derives a launch policy from **two inputs**:
  1) `policy.mode` from `ResolveLaunchPolicy(gamelocation)`
  2) `device_page` (UI scene label)
- `policy.mode` is **not** an MMCE-specific mode. It is either:
  - `mass` (USB or MMCE), or
  - a `pfs*` prefix (HDD).
- The final POPS root + prefix used for the boot string are computed in `PLDR.RunPOPStarterGame` using **both** `policy.mode` and `device_page` (see step 4 below).

## 2) Device rules table (prefix + root + boot string)

> **Invariant:** POPSLoader constructs the **full VCD boot string** (including prefix when required) and passes it to the ELF loader as the first extra argument. **Do not assume which argv index POPStarter itself reads** until verified from POPStarter source/docs.

| Source mode | POPS root | Required prefix | Example boot string |
| --- | --- | --- | --- |
| HDD (`pfs`) | `pfs*:/` mount of the `__.POPS` partition (e.g., `pfs1:/`) | *(none)* | `pfs1:/SLUS_012.34.VCD` |
| SMB | `smb:/POPS/` | `SB.` | `smb:/POPS/SB.SLUS_012.34.VCD` |
| MASS/USB/MMCE | `mass:/POPS/` | `XX.` | `mass:/POPS/XX.SLUS_012.34.VCD` |

**Prefix rules**
- HDD: **no prefix**
- SMB: `SB.`
- MASS/MMCE/USB: `XX.`

These prefix rules are implemented in `BuildPopstarterBootString()`.

## 3) End-to-end launch sequence (current code)

1. **User selects a game** (VCD basename) from the UI list.
2. **Determine launch policy** via `ResolveLaunchPolicy()`:
   - Uses `gamelocation` prefix (`mass`, `mmce`, `pfs`) if available; otherwise falls back to the current UI scene.
   - Policy `mode` is `mass` (USB/MMCE) or `pfs*` (HDD).
3. **Normalize/translate the game path** using the selected launch policy:
   - `NormalizeIsraPath()` translates `isra:` paths into device-specific `mass:`/`pfs:` equivalents.
   - MMCE paths are translated to `mass:/` for POPStarter handoff.
4. **Compute `pops_root`**:
   - If `source_mode` matches `^pfs`, use the normalized `pfs*:/` gamelocation.
   - If UI device page is `SMB/MMCE`, force `pops_root = "smb:/POPS/"`.
   - Otherwise use `pops_root = "mass:/POPS/"`.
5. **Build the boot string** with `BuildPopstarterBootString(source_mode, pops_root, basename)`:
   - Applies the correct prefix and ensures `pops_root` is slash-terminated.
6. **Build argv list** (Lua side):
   - `argv[1] = boot string` (first extra arg)
   - `argv[2] = "--nr"`
7. **Exec POPStarter** via `System.loadELF(popstarter, reboot_iop, argv[1], argv[2])`.
   - The ELF loader inserts POPStarter’s path as `argv[0]` and shifts the extra args.

## 4) Argument list and POPStarter handoff (verified vs unknown)

### What POPSLoader passes to the ELF loader (verified)
POPSLoader’s Lua side passes the boot string and `--nr` as extra args to `System.loadELF()`. The loader then constructs the final `ExecPS2()` argv list as:

```
argv[0] = <resolved POPSTARTER path>
argv[1] = <boot string>     (full VCD path with prefix when required)
argv[2] = "--nr"            (optional)
```

This is verified by:
- `System.loadELF(popstarter, reboot_iop, argv[1], argv[2])` in Lua.
- `lua_loadELF` printing extra args as `argv[0]`, `argv[1]`, etc.
- `LoadELFFromFileWithPartition` inserting POPStarter path into `launch_argv[0]` and shifting extras.

### Where POPStarter parses argv (unknown in this repo)
**TODO: verify.** POPStarter argument parsing is **not** present in this repository. To confirm which argv index POPStarter reads for the VCD boot string, locate POPStarter’s source (or official docs) and cite the exact file/function/line.

## 5) Expected log lines (validation)

Use these log lines to validate end-to-end argument construction and handoff:

### From POPSLoader (Lua)
- `LAUNCH: vcd basename: ...`
- `LAUNCH: pops root: ...`
- `LAUNCH: bootparam: ...`
- `LAUNCH: bootparam prefix: ... prefix injected: ...`
- `LAUNCH: exec argv[0]: ...`
- `LAUNCH: exec argv[1]: ...`
- `LAUNCH RETURNED rc=...`

These are written to the on-device `launch.log` via `LaunchLog()`.

### From the ELF loader (C)
- `LAUNCH: popstarter path: ...`
- `LAUNCH: argv[0]: ...` (resolved POPStarter path)
- `LAUNCH: argv[1]: ...` (boot string)
- `LAUNCH: argv[2]: ...` (`--nr` if present)

These appear on the console/tty when loader debug output is visible.
