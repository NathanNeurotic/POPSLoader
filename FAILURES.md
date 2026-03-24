Last updated: 2026-03-24

# FAILURES

## Active Unresolved Failure

### HDD-resident POPSTARTER black screen
- Status: embedded-loader bypass applied (`reboot_iop = 1` for HDD), `Unknown (verify on hardware)`.
- Scope:
  - USB/MMCE/SMB launches work.
  - HDD games list/browse behavior works.
  - Failure is specific to `POPSTARTER.ELF` being launched from HDD/PFS context.
- Symptom:
  - black screen before any POPSTARTER output, or
  - launch returns with `exec did not transfer control`.

## Repo-verified evidence
- HDD launch routing is handled by [bin/POPSLDR/system.lua](bin/POPSLDR/system.lua), [src/luasystem.cpp](src/luasystem.cpp), [src/elf_loader/src/elf.c](src/elf_loader/src/elf.c), and [src/elf_loader/src/loader/src/loader.c](src/elf_loader/src/loader/src/loader.c).
- The current in-repo [bin/POPSLDR/POPSTARTER.ELF](bin/POPSLDR/POPSTARTER.ELF) has one `LOAD` program header and no `PT_MIPS_REGINFO`:
  - `readelf -h -l bin/POPSLDR/POPSTARTER.ELF`
  - implication: any custom ELF loader that derives `gp` only from `PT_MIPS_REGINFO` is not trustworthy for this binary.
- Current branch keeps using HDD-specific launch complexity in:
  - path resolution and mount preservation in [bin/POPSLDR/system.lua](bin/POPSLDR/system.lua)
  - Lua-to-C launch dispatch in [src/luasystem.cpp](src/luasystem.cpp)
  - embedded handoff in [src/elf_loader/src/elf.c](src/elf_loader/src/elf.c)
  - embedded loader execution in [src/elf_loader/src/loader/src/loader.c](src/elf_loader/src/loader/src/loader.c)

## Failed attempts from this investigation

### `argv[0]` / selector-shape changes
- Commits:
  - `45e1f05` `Use mounted HDD selector path for POPSTARTER argv0`
  - `ac41f47` `Root HDD POPSTARTER argv0 at resolved sidecar path`
  - `5016138` `Restore embedded HDD loader argv contract`
- Result: hardware still black-screened.
- Conclusion: changing HDD selector shape alone has not solved the failure.

### HDD game-slot preparation / preservation
- Commits:
  - `757345b` `Prepare HDD game slot before POPSTARTER handoff`
  - `0ed6441` `Preserve HDD POPSTARTER mount during launch handoff`
- Result: hardware still black-screened.
- Conclusion: keeping game/sidecar PFS slots mounted is not sufficient by itself.

### Embedded-loader cleanup / reset variants
- Commits:
  - `35291c1` `Stop resetting IOP in HDD embedded POPSTARTER handoff`
  - `70895e4` `Reset IOP before ExecPS2 in HDD embedded loader path`
- Result: hardware still black-screened in both directions.
- Conclusion: this is not resolved simply by toggling IOP reset policy inside the current embedded-loader path.

### Partition-aware HDD handoff variants
- Commits:
  - `38f7a9d` `Fix HDD POPSTARTER partition-aware embedded handoff`
  - `a81d8a2` `Use SifLoadElf for partitioned HDD POPSTARTER handoff`
  - `7a32ad2` `Normalize pfs path for partitioned HDD POPSTARTER handoff`
  - `120fc72` `Restore upstream partitioned loader handoff contract`
  - `ea03ba2` `Keep raw HDD POPSTARTER path through partition handoff`
- Result: hardware still black-screened.
- Conclusion:
  - passing/reconstructing HDD partition context alone has not solved the failure
  - normalizing `pfsN:/...` to `pfs:/...` did not solve it
  - matching the upstream partitioned embedded-loader argv/load contract did not solve it
  - keeping raw `hdd0:...` POPSTARTER paths through Lua handoff did not solve it

### Custom `fileXio` ELF loading path
- Commits:
  - `08fffab` `Load HDD POPSTARTER via fileXio in embedded loader`
  - `cdbdbe7` `Fix embedded loader build after fileXio HDD handoff change`
- Result:
  - first attempt failed CI build until `cdbdbe7`
  - after build fix, hardware still black-screened
- Conclusion:
  - the custom `fileXio` loader path is not proven safe
  - because [bin/POPSLDR/POPSTARTER.ELF](bin/POPSLDR/POPSTARTER.ELF) has no `PT_MIPS_REGINFO`, that loader's `gp` derivation was specifically suspect

## Do not re-assume without new evidence
- Do not assume bare HDD `argv[0]` is the sole cause.
- Do not assume mounted-path HDD `argv[0]` is the sole cause.
- Do not assume preserving only the game slot fixes the handoff.
- Do not assume preserving the sidecar slot fixes the handoff.
- Do not assume “reset IOP” or “do not reset IOP” is enough on its own.
- Do not assume normalizing mounted `pfsN:/...` to `pfs:/...` fixes the failure.
- Do not assume matching the upstream partitioned embedded-loader contract fixes the failure.
- Do not assume keeping raw `hdd0:...` POPSTARTER paths through Lua fixes the failure.
- Do not treat repo history as proof of a solved path; many of those commits document failed or partial experiments.

### PFS mount-slot mismatch fix (necessary but insufficient)
- Commit: `87f4197` `Fix PFS mount-slot mismatch in HDD POPSTARTER embedded loader handoff`
- What it fixed: `canonicalize_partition_loader_path` in `elf.c` stripped `pfs3:` → `pfs:`, causing SifLoadElf to target the wrong mount point.
- Result: hardware still black-screened.
- Conclusion: the slot-mismatch was a real code bug, but fixing it alone is not sufficient. The embedded loader's execution environment is fundamentally unable to load POPSTARTER from PFS.

### Embedded-loader bypass (current attempt)
- Approach: set `reboot_iop = 1` for HDD policy in `system.lua`, routing through `LoadELFFromFileExecPS2RebootIOP` instead of the embedded loader.
- Rationale: ALL 14+ previous failures went through the embedded loader. This bypasses it entirely, loading POPSTARTER via `SifLoadElf` in the main process context where fileXio/iomanX/PFS are fully active.
- Status: `Unknown (verify on hardware)`.

## Do not re-assume without new evidence (updated)
- Do not assume any variant of the embedded loader path works for HDD POPSTARTER.
- Previous assumptions still apply (see above).

## Diagnostic artifact (still available)
- The CI-built `POPSLOADER-HDD-DIAGNOSTIC` artifact with `LOADER_ENABLE_DEBUG_COLORS=1` remains available.
- `src/elf_loader/src/loader/src/loader.c` GS color stages are still in place.
