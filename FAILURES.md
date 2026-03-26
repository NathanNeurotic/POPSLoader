Last updated: 2026-03-26 (attempt 5c: pre-memcpy IOP reset)

# FAILURES

## Active Unresolved Failure

### HDD-resident POPSTARTER black screen
- Status: **BLOCKED — embedded loader never executes**. Hardware-verified via diagnostic build (no GS color output).
- Scope:
  - USB/MMCE/SMB launches work.
  - HDD games list/browse behavior works.
  - Failure is specific to `POPSTARTER.ELF` being launched from HDD/PFS context.
- Symptom:
  - black screen before any POPSTARTER output, or
  - launch returns with `exec did not transfer control`.

## Confirmed Root Causes (Two-Layer)

### Layer 1 (PRIMARY): Embedded loader never starts
- **Hardware-verified**: the diagnostic build with `LOADER_ENABLE_DEBUG_COLORS=1` produces a **black screen** — no GS background color is visible.
- `SET_GS_BGCOLOUR(WHITE_BG)` is the very first statement in the embedded loader's `main()` (`loader.c` line 177). A black screen means `main()` is never reached.
- `ExecPS2((void *)boot_header->entry, 0, final_argc, launch_argv)` in `ExecuteViaEmbeddedLoaderWithPartition` (`elf.c` line 189) fails silently — control never transfers to the embedded loader in bram (0x84000).
- This invalidates ALL prior attempts that modified code INSIDE the embedded loader (fileXio fallback, pre-read buffer, etc.) — that code never ran.

### Layer 2 (SECONDARY): SifLoadElf cannot access PFS paths
- `SifLoadElf` → `rom0:LOADFILE` → `ioman` file I/O → no PFS support.
- `fileXioOpen` → `iomanX` file I/O → PFS IS supported.
- This is a real issue that must be addressed AFTER Layer 1 is resolved.
- Note: this also means `LoadELFFromFileExecPS2RebootIOP` (the bypass attempt) fails for PFS paths even from the main process.

## Candidate causes for ExecPS2-to-bram failure
These are hypotheses to investigate — none are confirmed yet.

1. **gp=0 passed to ExecPS2**: The second argument is `0` (no GP register value). If the embedded loader's CRT startup relies on a valid `$gp` before it can set its own, the program crashes immediately. The ps2sdk CRT (`crt0.s`) sets `$gp` from the `_gp` linker symbol, but ExecPS2's kernel code may overwrite `$gp` with the passed value (0) before CRT runs.

2. **bram (0x84000) is not a valid ExecPS2 target**: ExecPS2 may only support entry points in game memory (0x100000+). The PS2 kernel may reject or mishandle addresses below 0x100000. The embedded loader's linker script targets bram at 0x84000.

3. **Stale/corrupt embedded loader data**: The `loader_elf[]` array is generated at build time. If it's out of date or corrupt, the entry point or segment data may be wrong.

4. **FlushCache insufficient for bram execution**: After memcpy of loader segments to bram, `FlushCache(0)` + `FlushCache(2)` is called. If this doesn't properly make the code visible at 0x84000, the CPU fetches garbage instructions.

5. **SifExitRpc before ExecPS2 corrupts state**: `SifExitRpc()` is called right before `FlushCache` + `ExecPS2`. This may leave the system in a state where ExecPS2 cannot function.

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

## Failed attempts from this investigation (17 total, 4 in current session)

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

### PFS mount-slot mismatch fix (necessary but insufficient)
- Commit: `87f4197` `Fix PFS mount-slot mismatch in HDD POPSTARTER embedded loader handoff`
- What it fixed: `canonicalize_partition_loader_path` in `elf.c` stripped `pfs3:` → `pfs:`, causing SifLoadElf to target the wrong mount point.
- Result: hardware still black-screened.
- Conclusion: the slot-mismatch was a real code bug, but fixing it alone is not sufficient. **Now known**: the embedded loader never started, so this fix had no observable effect.

### Embedded-loader bypass via reboot_iop (hardware-verified failure)
- Commit: `c60ce3e` `Bypass embedded loader for HDD POPSTARTER`
- What it tried: set `reboot_iop = 1` for HDD, routing through `LoadELFFromFileExecPS2RebootIOP` which uses `SifLoadElf` in the main process context.
- Result: hardware still black-screened.
- Conclusion: `SifLoadElf` cannot open PFS paths **regardless of execution context**. This is because `rom0:LOADFILE` on the IOP uses `ioman`, and PFS (`ps2fs.irx`) registers only with `iomanX`. `mass:` works because BDM/FAT32 drivers register with both `ioman` and `iomanX`.

### fileXio fallback in embedded loader (hardware-verified failure)
- Commit: `6a01b96` `Add fileXio fallback in embedded loader for HDD POPSTARTER`
- Approach: when `SifLoadElf` fails in the embedded loader, fall back to `load_elf_via_filexio()`.
- Result: hardware still black-screened.
- Conclusion: **now known** — the embedded loader never started, so this fallback code never executed.

### Pre-read bram buffer (hardware-verified failure)
- Commit: `12e942e` `Pre-read HDD POPSTARTER ELF to bram buffer before embedded loader launch`
- Approach: read POPSTARTER ELF in main process, store in bram at `0xC0000`, have embedded loader parse from buffer.
- Result: hardware still black-screened.
- Conclusion: **now known** — the embedded loader never started, so the buffer parsing code never executed. The pre-read itself likely worked (main process `open/read` on PFS paths is proven), but the data was never used.

### Direct ELF load from main process (attempt 5a — with IOP reset, LIKELY BROKEN)
- Approach: **completely bypass the embedded loader**. Read POPSTARTER ELF into bram buffer using `open/read` (fileXio-backed, works with PFS) from the main process, parse the ELF, `memcpy` LOAD segments to target addresses (0x100000+), then follow the exact same IOP reset + `ExecPS2` pattern as the working USB path (`LoadELFFromFileExecPS2RebootIOP`).
- Why this is different: eliminates BOTH broken layers at once:
  - No `ExecPS2` to bram (Layer 1) — we never launch the embedded loader.
  - No `SifLoadElf` for PFS (Layer 2) — we use `open/read` via fileXio instead.
- The file I/O happens entirely in the main process where it's proven to work.
- **Identified bug**: After `memcpy` writes POPSTARTER data to 0x100000-0x128C80 through the D-cache, SIF library globals (sifrpc, sifcmd, loadfile state) at 0x100000+ are corrupted in the D-cache. The subsequent `SifInitRpc`, `SifLoadFileInit`, `SifLoadModule` calls read POPSTARTER bytes as RPC state (undefined behavior) and write RPC data over POPSTARTER code, corrupting the loaded image. The final `FlushCache(0)` writes this corruption to physical RAM. This does NOT happen in the USB path because `SifLoadElf` loads via IOP DMA which bypasses the D-cache — SIF library state in D-cache remains valid.
- Status: `Superseded by attempt 5b`.

### Direct ELF load — minimal post-memcpy (attempt 5b — hardware-verified FAILURE)
- Approach: Same file read + ELF parse + memcpy as 5a, but after memcpy, execute ONLY kernel syscalls: `FlushCache(0)` (write D-cache to physical RAM), `FlushCache(2)` (invalidate I-cache), `ExecPS2` (jump to entry). No SIF library calls whatsoever.
- Rationale: After memcpy overwrites 0x100000+ through D-cache, ALL user-space library state in that range is corrupt. Only kernel syscalls (which trap to KSEG0/KSEG1) are safe.
- Result: **black screen** on hardware. Note: the "HDD Diag" build also showed black, but it only had `LOADER_ENABLE_DEBUG_COLORS` (embedded loader) — NOT `HDD_LAUNCH_DEBUG_COLORS` (main process). The diag result was irrelevant to this code path.
- **Why it failed**: Removing IOP reset entirely left the IOP with all HDD/PFS/APA modules from POPSLoader's session. POPSTARTER likely expects a clean IOP. The working USB-with-IOP-reset path (`LoadELFFromFileExecPS2RebootIOP`) does a full IOP reset + ROM module reload before ExecPS2.
- Status: `Failed — superseded by attempt 5c`.

### Direct ELF load — pre-memcpy IOP reset (attempt 5c — current)
- Approach: Same file read + ELF parse as 5a/5b, but reorder operations:
  1. `open/read` ELF to bram (0xC0000) — PFS modules still on IOP, file access works.
  2. Parse ELF headers from bram buffer.
  3. IOP reset + ROM module reload — SIF state at 0x100000+ still valid (not yet overwritten).
  4. `memcpy` LOAD segments from bram to 0x100000+ — all SIF calls done.
  5. `FlushCache(0)` + `FlushCache(2)` — kernel syscalls only.
  6. `ExecPS2` to entry point.
- Rationale: The IOP reset must happen AFTER reading (needs PFS) but BEFORE memcpy (needs valid SIF state). This satisfies all constraints simultaneously.
- Diagnostic build now has `HDD_LAUNCH_DEBUG_COLORS` in CI. Color stages: GREEN=file read, CYAN=pre-IOP-reset, YELLOW=IOP reset done, BLUE=segments copied, PURPLE=about to ExecPS2.
- Status: `Unknown (verify on hardware)`.

## Do not re-assume without new evidence (updated)
- Do not assume `SifLoadElf` can open PFS paths (it cannot — Layer 2 confirmed).
- Do not assume `fileXioInit()`/`fileXioOpen()` works inside the embedded loader context (untested — loader never started).
- Do not assume the embedded loader starts executing — **hardware-disproven** via diagnostic build.
- Do not assume code changes inside the embedded loader have any effect — the loader never runs.
- Do not assume `ExecPS2` to bram (0x84000) works — this is the primary failure point.
- Previous assumptions still apply (see above).

## Diagnostic results
- **Standard build**: black screen (no improvement across all 4 current-session attempts).
- **Diagnostic build** (`LOADER_ENABLE_DEBUG_COLORS=1`): **black screen** — no GS background color visible. Confirms embedded loader `main()` never reached.
- Color key reference:
  - BLACK (no color) = embedded loader never started — ExecPS2 to bram is broken **← OBSERVED**
  - WHITE = loader main() entered
  - CYAN = argc OK, about to SifInitRpc + wipeUserMem
  - GREEN = about to SifLoadElf
  - BLUE = SifLoadElf done, entering fallback chain
  - YELLOW = ELF loaded successfully via any method
  - MAGENTA = all load methods failed
  - ORANGE = IOP reset complete
  - BROWN = about to final FlushCache
  - PURPLE = about to ExecPS2 to POPSTARTER
