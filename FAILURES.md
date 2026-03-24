Last updated: 2026-03-24

# FAILURES

## Active Unresolved Failure

### HDD-resident POPSTARTER black screen
- Status: code fix applied (PFS mount-slot mismatch), `Unknown (verify on hardware)`.
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

## New finding: PFS mount-slot mismatch (code fix applied)
- Root cause identified from repository code:
  - POPSTARTER partition is mounted on `pfs3:` (slot 3, via `HDD_SLOT_POPSTARTER` in `system.lua:199`).
  - `canonicalize_partition_loader_path` in `elf.c` stripped the slot number: `pfs3:/POPSTARTER.ELF` → `pfs:/POPSTARTER.ELF`.
  - The embedded loader called `SifLoadElf("pfs:/POPSTARTER.ELF")` targeting `pfs0:` (slot 0), which does NOT have the POPSTARTER partition mounted.
  - Therefore `SifLoadElf` failed → black screen.
- Why previous attempts did not address this:
  - `7a32ad2` and `120fc72` both used `pfs:/` (same slot-0 bug).
  - `ea03ba2` used raw `hdd0:` path (can't be opened by `SifLoadElf` without PFS mount).
  - `08fffab` used `fileXio` custom loader (failed due to missing `PT_MIPS_REGINFO`/gp=0).
  - None of them preserved the actual `pfs3:/` mount-point path for the embedded loader's `SifLoadElf` call.
- Fix: removed `canonicalize_partition_loader_path` call in `LoadELFFromFileWithPartition` so `resolved_path` (with correct `pfs3:/` prefix) is passed directly to the embedded loader.
- Status: `Unknown (verify on hardware)`.

## Diagnostic artifact (still available)
- The CI-built `POPSLOADER-HDD-DIAGNOSTIC` artifact with `LOADER_ENABLE_DEBUG_COLORS=1` remains available.
- If the above fix still black-screens, the diagnostic build should show MAGENTA (SifLoadElf failure) vs other colors.
- `src/elf_loader/src/loader/src/loader.c` GS color stages are still in place.
