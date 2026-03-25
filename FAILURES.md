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

## Current stop point
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
- Hardware result from commit `3d52065`:
  - flashed text and then black screen again, even though the diagnostic build now loops forever after recording the embedded loader `SifLoadElf()` outcome
- Hardware conclusion from that run:
  - the diagnostic build did not present a stable post-`SifLoadElf()` halt on hardware
  - inference from repo behavior: the failure is before that post-`SifLoadElf()` halt point, or the visible flash was from an earlier stage such as the pre-embedded-loader marker in `src/elf_loader/src/elf.c`
- Hardware result from commit `5699aa8`:
  - same flash-then-black result, even though the diagnostic build now loops forever immediately before the embedded loader calls `SifLoadFileInit()` / `SifLoadElf()`
- Hardware conclusion from that run:
  - the embedded loader still did not present a stable pre-`SifLoadElf()` halt on hardware
  - inference from repo behavior: the failure is before that halt point, likely at the `ExecPS2` boundary into the embedded loader or before its first durable stage
- Hardware result from commit `9eaa040`:
  - stable white-border diagnostic screen:
    - `POPSLoader HDD diagnostic`
    - `embedded loader entry`
    - `argc=3 argv=0xa4e8c`
    - `argv0_ptr=0xa4ecc`
    - `argv1_ptr=0xa4ed7`
- Hardware conclusion from that run:
  - keeping SIF RPC alive across the partitioned embedded-loader `ExecPS2` boundary allowed stable entry into the embedded loader
  - the remaining failure is later than loader entry and earlier than the old pre-`SifLoadElf()` halt point
- Hardware result from commit `6bddf69`:
  - black screen again, with text flashing too quickly to read after the diagnostic artifact moved the halt to post-argument-copy
- Hardware conclusion from that run:
  - the embedded loader still did not present a stable post-argument-copy halt on hardware
  - inference from repo behavior: that artifact still grouped together primary path copy, forwarded selector dereference, and copied-string debug printing, so it did not isolate the first failing read tightly enough
- Hardware result from commit `11f1dc6`:
  - same flash-then-black result again, even though the diagnostic artifact now halted immediately after copying the partition/path strings and building `exec0`
- Hardware conclusion from that run:
  - the embedded loader still did not present a stable post-path-copy halt on hardware
  - inference from repo behavior: the remaining unresolved gap is now tighter, between the first `argv[0]` string read and the second `argv[1]` string read in `src/elf_loader/src/loader/src/loader.c`
- Hardware result from commit `78e0ee6`:
  - same flash-then-black result again, even though the diagnostic artifact now halted immediately after copying only `argv[0]` into `partition_prefix` and before dereferencing `argv[1]`
- Hardware conclusion from that run:
  - the embedded loader still did not present a stable post-`argv[0]` halt on hardware
  - inference from repo behavior: the current screen-backed diagnostic approach has reached a plateau after stable loader entry; narrower post-entry string-copy halts are no longer yielding durable new stage evidence
- Repo-verified implementation:
  - `.github/workflows/compilation.yml` now builds and uploads `POPSLOADER-HDD-DIAGNOSTIC` with `LOADER_ENABLE_DEBUG_COLORS=1`, without the older `src/elf_loader/src/elf.c` early-return probe defines.
  - `src/elf_loader/src/loader/Makefile` previously default-enabled every `LOADER_DIAG_HALT_*` define during plain builds because those flags were unset, but the make logic still treated any value other than literal `0` as enabled.
  - That meant the standard `make clean elfloader all` path still compiled the embedded loader with diagnostic halt sites active unless the workflow explicitly overrode them to `0`.
  - `src/elf_loader/src/loader/Makefile` now defaults those halt flags to `0`, so only the explicit diagnostic build keeps the halt variants active.
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
  - Commit `3d52065` now adds a diagnostic-only halt immediately after the embedded loader records the `SifLoadElf()` outcome.
  - Commit `5699aa8` now halts earlier, immediately before the embedded loader calls `SifLoadFileInit()` / `SifLoadElf()`.
  - Because that pre-`SifLoadElf()` halt still did not remain visible, the next diagnostic artifact kept SIF RPC alive across the partitioned embedded-loader `ExecPS2` boundary in `src/elf_loader/src/elf.c` while reusing the same pre-`SifLoadElf()` halt.
  - New repo-local evidence for that target:
    - the partition-aware handoff originally still called `SifExitRpc()` immediately before `ExecPS2` into the embedded loader in `src/elf_loader/src/elf.c`
    - older repo history contains commit `39ba2d2` (`Fix HDD black screen: remove SifExitRpc/SifExitCmd timing race before embedded loader ExecPS2`) for the non-partition embedded-loader path
    - inference: the partitioned path still has an `ExecPS2` cleanup asymmetry that has not been isolated by the documented failed selector/path/reset theories
  - Commit `9eaa040` now keeps SIF RPC alive across that partitioned embedded-loader `ExecPS2` boundary, and hardware now reaches a stable `embedded loader entry` stage.
  - `src/elf_loader/src/elf.c` now keeps SIF RPC alive unconditionally for the partition-aware embedded-loader handoff, so the standard `POPSLOADER` artifact no longer drops the only durable positive movement that was previously confined to the diagnostic build.
  - Hardware effect of that non-diagnostic keepalive/no-halt build is `Unknown (verify on hardware)`.
  - Commit `6bddf69` moved the diagnostic halt to after the embedded loader copied `argv[0]`, `argv[1]`, and the forwarded selector into local buffers, and also printed the copied strings for visibility.
  - Commit `11f1dc6` then moved the diagnostic halt earlier again, to after the embedded loader copied the partition/path strings and built `exec0`, but before it dereferenced the forwarded selector `argv[2]`.
  - Commit `78e0ee6` moved the diagnostic halt earlier still, to after the embedded loader copied `argv[0]` into `partition_prefix`, but before it dereferenced `argv[1]` for the target path.
  - Commits `6bddf69`, `11f1dc6`, and `78e0ee6` all produced the same practical hardware result: a brief flash followed by black screen, without a new durable post-entry stage.

## Guardrail For Future Work
- Do not continue making narrower screen-backed embedded-loader halt variants in `src/elf_loader/src/loader/src/loader.c` unless there is a materially different evidence source.
- Repo evidence now supports only these durable HDD findings:
  - embedded-loader image copy completed (`2172a2f`)
  - embedded-loader cleanup completed (`6c81233`)
  - keeping SIF RPC alive before the partitioned embedded-loader `ExecPS2` boundary allowed stable `embedded loader entry` (`9eaa040`)
  - later post-entry screen-backed halts at `6bddf69`, `11f1dc6`, and `78e0ee6` did not yield stable new observations
- Do not repeat:
  - selector-shape / `argv[0]` contract rewrites
  - slot-preservation rewrites
  - reset-policy toggles
  - partition/path normalization rewrites
  - custom `fileXio` target-loading path
  - finer-grained post-entry `argv` copy halts that only move the screen-backed stop a few lines earlier
- If HDD work resumes, require one of:
  - a genuinely new code asymmetry not already covered above, with file-level evidence
  - or a materially different observability method than the current `debug.h`/GS-color screen-backed diagnostic path
