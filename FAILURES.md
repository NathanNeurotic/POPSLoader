Last updated: 2026-03-24

# FAILURES

## Active Unresolved Failure

### HDD-resident POPSTARTER black screen
- Status: hardware-verified failure, still unresolved.
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
- Result: hardware still black-screened.
- Conclusion: passing/reconstructing HDD partition context alone has not solved the failure.

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
- Do not treat repo history as proof of a solved path; many of those commits document failed or partial experiments.

## Next useful step
- Produce a diagnostic build that makes handoff stage visible on hardware.
- Goal:
  - distinguish failure before embedded loader,
  - during target ELF load,
  - during IOP reset/sync,
  - or after final `ExecPS2`.
- Without that, further launch-path edits are likely to repeat already-failed theories.
