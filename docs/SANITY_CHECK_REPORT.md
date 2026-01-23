# POPSLoader Sanity Check Report (Launch + POPStarter Handoff)

This report maps the current launch pipeline and documents the observed mismatch against expected POPStarter boot rules. It is **documentation-only** and does not change runtime behavior.

## 1) Relevant files/functions (launch & path building)

### Source mode selection
- `ResolveLaunchPolicy(gamelocation)` in `bin/POPSLDR/system.lua`
  - Picks a device policy based on `gamelocation` prefix (`mass`, `mmce`, `pfs`) or UI scene fallback (`GUSB`, `GSMB`, `GMMCE`, `GHDD`).
  - Returns a policy containing `mode` (e.g., `mass`, `pfs`) and a UI label.

### POPS root selection
- `PLDR.RunPOPStarterGame(gamelocation, game)` in `bin/POPSLDR/system.lua`
  - Computes `pops_root` based on `source_mode` and device page:
    - `pfs` → use normalized gamelocation.
    - `SMB` → `smb:/POPS/`.
    - Else → `mass:/POPS/` (USB/MMCE).

### Prefix injection / boot string construction
- `BuildPopstarterBootString(source_mode, pops_root, basename)` in `bin/POPSLDR/system.lua`
  - Prefixes VCD name: `pfs` → none, `smb` → `SB.`, else `XX.`.
  - Returns `pops_root + basename` and the prefix used.

### argv assembly (Lua)
- `PLDR.RunPOPStarterGame(...)` builds:
  - `argv = { bootparam, "--nr" }`
- `LaunchEngine(...)` passes the args into the ELF loader:
  - `System.loadELF(popstarter, reboot_iop, argv[1], argv[2])`

### argv assembly (C + loader)
- `lua_loadELF` in `src/luasystem.cpp` prints extra args and calls `LoadELFFromFile(elf, argc, argv)`.
- `LoadELFFromFileWithPartition` in `src/elf_loader/src/elf.c`:
  - Resolves POPStarter path.
  - Inserts POPStarter path as `argv[0]` and shifts extras (`bootparam`, `--nr`) to `argv[1]`, `argv[2]`.
  - Calls `ExecPS2` with the final argv list.

### Exec / handoff
- `ExecPS2` is called from `LoadELFFromFileWithPartition` in `src/elf_loader/src/elf.c` with the constructed argv list.

## 2) Current behavior vs expected behavior

### Expected behavior (requirements)
- HDD: **no prefix** and POPS root should be a `pfs` mount of `__.POPS` (e.g., `pfs0:/` or `pfs1:/`).
- SMB: prefix `SB.` and POPS root `smb:/POPS/`.
- MASS/MMCE/USB: prefix `XX.` and POPS root `mass:/POPS/`.
- POPStarter must receive the **full VCD boot string** (with correct prefix) in the argv list.

### Current behavior (from code)
- Prefix selection is tied to `source_mode` (`pfs` → none, `smb` → `SB.`, else `XX.`).
- POPS root selection uses a three-branch rule:
  - If `source_mode` matches `^pfs`, `pops_root = normalized_gamelocation`.
  - Else if `device_page == "SMB"`, `pops_root = "smb:/POPS/"`.
  - Else `pops_root = "mass:/POPS/"`.

### Reported mismatch (user observation)
- **Observation:** HDD mode produced `mass:/POPS/` and injected `XX.`.
- **Code path that can cause this:**
  - If `source_mode` is not `pfs` and device page is not `SMB`, the default branch sets `pops_root = "mass:/POPS/"` and `boot_source_mode = "mass"`, which yields the `XX.` prefix.
- **TODO: verify** the actual `gamelocation` value and the `device_page`/UI scene at the moment of the failing launch. The mismatch suggests the HDD launch path is not being recognized as `pfs` (or the UI scene fallback is not `GHDD`).

## 3) Recommended fix plan (next step, smallest diffs)

> **No code changes in this pass.** The following is a minimal fix plan for a follow-up PR.

1. **Instrument launch context** (if needed) to confirm `source_mode`, `device_page`, and `gamelocation` at handoff (already logged via `LaunchLog`).
2. **Ensure HDD launches are tagged as `pfs`** before `BuildPopstarterBootString`:
   - Verify that HDD `gamelocation` is always a `pfs*:/` path, or
   - Force `boot_source_mode = "pfs"` when UI scene is `GHDD` (if/when `gamelocation` is not `pfs`).
3. **Add a focused regression check**: log/validate `pops_root` and prefix for HDD selection.

These steps keep diffs minimal while ensuring HDD uses **no prefix** and a `pfs` POPS root.
