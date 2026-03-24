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

## Next useful step
- The first CI-built `POPSLOADER-HDD-DIAGNOSTIC` artifact from commit `0327006` was still reported as a black screen on HDD boot + HDD game hardware.
- The follow-up screen-backed diagnostic artifact from commit `03c1a2b` was also still reported as a black screen on HDD boot + HDD game hardware.
- The return-code probe from commit `2172a2f` displayed:
  - `POPSLoader HDD diagnostic`
  - `diag return after loader copy`
  - `argc=3`
  - `partition=hdd0:+OPL:`
  - `path=pfs:/APPS/PS1_POPSLOADER/POPSTARTER.ELF`
- Hardware conclusion from that run:
  - embedded-loader image copy in `src/elf_loader/src/elf.c` completed
  - the unresolved failure is later than that point
- The return-code probe from commit `6c81233` displayed:
  - `POPSLoader HDD diagnostic`
  - `diag return after loader cleanup`
  - `argc=3`
  - `partition=hdd0:+OPL:`
  - `path=pfs:/APPS/PS1_POPSLOADER/POPSTARTER.ELF`
- Hardware conclusion from that run:
  - `SifExitRpc` and both `FlushCache` calls in `src/elf_loader/src/elf.c` completed
  - the unresolved failure is later than that cleanup point
- Hardware result from commit `c3cf306`:
  - still solid black screen on HDD boot + HDD game
  - user reported a very fast flash before the final black screen, but the stage text was not readable
- Hardware conclusion from that run:
  - `Unknown (verify on hardware)` whether the flash came from `src/elf_loader/src/elf.c` or from a later embedded-loader stage
  - the new embedded-loader `gp` handoff did not produce a stable visible success/failure marker on hardware
- Hardware result from commit `4d350a4`:
  - same outcome as commit `c3cf306`
  - text flashed briefly and then the console returned to a solid black screen
- Hardware conclusion from that run:
  - the added `SifInitRpc(0)` after `wipeUserMem()` did not produce a stable visible outcome
  - `Unknown (verify on hardware)` whether the flash was before or after the embedded loader's `SifLoadElf()` call
- Repo-verified implementation:
  - `.github/workflows/compilation.yml` now builds and uploads `POPSLOADER-HDD-DIAGNOSTIC` with `LOADER_ENABLE_DEBUG_COLORS=1`, without the older `src/elf_loader/src/elf.c` early-return probe defines.
  - The first diagnostic loader only wrote `GS_BGCOLOR` in `src/elf_loader/src/loader/src/loader.c`; it did not initialize a visible debug screen in that loader.
  - This follow-up diagnostic loader revision uses `debug.h` screen output in addition to GS color writes so the current stage remains visible if the handoff stalls inside the embedded loader.
  - Even that follow-up loader revision still dereferenced `argv[0]` and `argv[1]` before its first visible stage, and `src/elf_loader/src/elf.c` still had no screen-backed marker immediately before `ExecPS2` into the embedded loader.
  - This next diagnostic revision now places a visible marker before the embedded-loader `ExecPS2` in `src/elf_loader/src/elf.c`, and moves the first visible loader marker in `src/elf_loader/src/loader/src/loader.c` ahead of any `argv` string dereference.
  - The prior return-code probe returned `-803` from `src/elf_loader/src/elf.c` immediately after the embedded-loader image was copied into RAM and before `SifExitRpc` / final `ExecPS2`.
  - The later return-code probe returned `-804` from `src/elf_loader/src/elf.c` after `SifExitRpc` and both `FlushCache` calls, and before the final `ExecPS2`.
  - Those return probes are now retired; they remain documented only as hardware evidence that the failure is later than embedded-loader staging and later than the cleanup boundary.
  - `src/elf_loader/src/elf.c` still jumped into the embedded loader with `gp=0`, even though `src/elf_loader/src/loader/linkfile` defines `_gp` and the repo-generated `src/elf_loader/loader.c` blob carries a `.reginfo` section (`SHT_MIPS_REGINFO`) whose `ri_gp_value` is `0x0009d6f0`.
  - Commit `c3cf306` now derives the embedded loader's `gp` from that `.reginfo` metadata and passes it to `ExecPS2` instead of forcing zero.
  - `src/elf_loader/src/loader/src/loader.c` still called `SifInitRpc(0)` and then immediately wiped all EE user memory with `wipeUserMem()` before using `SifLoadFileInit()` / `SifLoadElf()`.
  - Inference from repo code: if `SifInitRpc(0)` establishes EE-side RPC state in wiped user memory, the embedded loader can corrupt its own later `SifLoadElf()` path even though the direct working launchers in `src/elf_loader/src/elf.c` initialize RPC immediately before `SifLoadFileInit()` and do not wipe memory between those calls.
  - Commit `4d350a4` now reinitializes SIF RPC after `wipeUserMem()` and before the embedded loader's `SifLoadFileInit()` / `SifLoadElf()` sequence.
  - The remaining issue is observability: the embedded loader's stage text still flashes too quickly to tell whether `SifLoadElf(target_path)` succeeded, failed, or hung.
  - The next diagnostic artifact now adds a diagnostic-only halt immediately after the embedded loader records the `SifLoadElf()` outcome, so hardware can distinguish:
    - stable yellow `SifLoadElf ok`
    - stable magenta `SifLoadElf failed`
    - or a black screen before that halt point
- Hardware goal:
  - distinguish failure before embedded loader,
  - during embedded-loader image staging in `src/elf_loader/src/elf.c`,
  - during `SifExitRpc` / cache cleanup after embedded-loader image staging,
  - at the final embedded-loader `ExecPS2` boundary itself,
  - at embedded-loader entry before `argv` string dereference,
  - during target ELF load,
  - during IOP reset/sync,
  - after reset/sync but before final `ExecPS2`,
  - or after final `ExecPS2`.
- Expected result for this artifact:
  - if the diagnostic build shows stable `SifLoadElf ok`, the remaining black screen is later than the target ELF load and later than the embedded loader's pre-load RPC setup
  - if the diagnostic build shows stable `SifLoadElf failed`, the failure is inside the target ELF load path itself
  - if it still black-screens before the halt point, the failure is earlier than the post-`SifLoadElf()` diagnostic halt
- Without that hardware observation, further launch-path edits are likely to repeat already-failed theories.
