# HDD POPSTARTER Black Screen Fix — Continuation Prompt

**Repository**: `https://github.com/NathanNeurotic/POPSLoader`
**Branch**: `claude/beta-recovery-checkpoint-22Ms7` (branched from `BETA-9-RECOVERY-BACKUP-CHECKPOINT-PROFILES-PLAY`)
**Last commit**: `2e4ebb9` `Bypass embedded loader entirely: direct ELF load from main process`

---

## Goal

Fix the black screen that occurs when launching `POPSTARTER.ELF` from the PS2's internal HDD (PFS filesystem). Every other launch path (USB, MMCE, MX4SIO, SMB) works correctly. The fix must **not** break any working launch path.

This is exclusively a **POPSTARTER.ELF launched from HDD** problem. HDD game listing/browsing works fine. The failure is in the handoff from POPSLoader to POPSTARTER.ELF when both POPSLoader and POPSTARTER.ELF reside on HDD partitions.

---

## Repository Structure (Key Files)

All paths are relative to the repo root `https://github.com/NathanNeurotic/POPSLoader`.

### Lua orchestration
- **`bin/POPSLDR/system.lua`** — Main orchestration. HDD launch routing at `PLDR.RunPOPStarterGame` (~line 3050). `LaunchEngine` (~line 2919) dispatches to `System.loadELF`. For HDD: `reboot_iop = 0` (line 3276) and `partition_hint` is set via `ResolveHddExecPartitionHint`. PFS slot constants at lines 196-199: `HDD_SLOT_BOOT=0`, `HDD_SLOT_GAME=1`, `HDD_SLOT_COMMON=2`, `HDD_SLOT_POPSTARTER=3`. `REBOOT_IOP_WHILE_LOADING_POPSTARTER = 0` (line 1002). `PrepareForExternalELFLaunch` (~line 608) unmounts PFS slots before launch.

### C dispatch layer
- **`src/luasystem.cpp`** — `lua_loadELF` (~line 949) dispatches based on `rebootIOP` and `partition`:
  ```cpp
  if (rebootIOP == 0 && partition != NULL && partition[0] != '\0') {
      rc = LoadELFFromFileWithPartition(elftoload, partition_buf, 1, argv_static);
  } else if (rebootIOP != 0) {
      rc = LoadELFFromFileExecPS2RebootIOP(elftoload, 1, argv_static);
  } else {
      rc = LoadELFFromFileExecPS2(elftoload, 1, argv_static);
  }
  ```
  For HDD: `rebootIOP=0` + non-empty `partition` → `LoadELFFromFileWithPartition`.
  For USB: `rebootIOP=0` + no partition → `LoadELFFromFileExecPS2` (works).

### ELF loader (THE CRITICAL FILE)
- **`src/elf_loader/src/elf.c`** — Contains all `LoadELFFromFile*` functions. `LoadELFFromFileWithPartition` (line ~310) is the HDD path. `LoadELFFromFileExecPS2` (line ~428) is the working USB path. `LoadELFFromFileExecPS2RebootIOP` (line ~379) is the working USB-with-IOP-reset path.

### Embedded loader (PROVEN BROKEN — DO NOT USE)
- **`src/elf_loader/src/loader/src/loader.c`** — Standalone ELF linked to bram (0x84000-0x100000). **Hardware-verified to never execute.** Diagnostic build with GS color stages shows black screen — `main()` is never reached. `ExecPS2` to bram fails silently. All code inside this file is dead for HDD paths.
- **`src/elf_loader/src/loader/linkfile`** — Linker script targeting bram.

### ELF header definitions
- **`src/elf_loader/src/elf.h`** — `elf_header_t` and `elf_pheader_t` struct definitions.
- **`src/elf_loader/include/elf-loader.h`** — Public API declarations.

### POPSTARTER binary
- **`bin/POPSLDR/POPSTARTER.ELF`** — The target ELF being launched. Key facts:
  - Entry: `0x100000`
  - One LOAD segment: offset `0x400`, vaddr `0x100000`, filesz `0x28B14` (~163KB), memsz `0x28C80`
  - **No `PT_MIPS_REGINFO`** → gp=0 for all paths
  - Machine: MIPS R3000 (32-bit ELF)

### Documentation
- **`FAILURES.md`** — Complete failure history (17+ failed attempts documented).
- **`STATE.md`**, **`ROADMAP.md`**, **`QA_REGRESSION_MATRIX.md`** — Project status tracking.
- **`AGENTS.md`** — Operational rules for AI agents working in this repo.

---

## Confirmed Root Causes (Two-Layer Problem)

### Layer 1 (PRIMARY — NOW BYPASSED): Embedded loader never starts
- **Hardware-verified**: Diagnostic build with `LOADER_ENABLE_DEBUG_COLORS=1` shows **black screen**. `SET_GS_BGCOLOUR(WHITE_BG)` is the first line of `main()` in `loader.c`. No color = `main()` never reached.
- `ExecPS2((void *)boot_header->entry, 0, final_argc, launch_argv)` targeting bram (0x84000) fails silently.
- **Resolution**: The current code on branch bypasses the embedded loader entirely. `LoadELFFromFileWithPartition` now does direct ELF loading from the main process.

### Layer 2 (SECONDARY — NOW BYPASSED): SifLoadElf cannot access PFS paths
- `SifLoadElf` → `rom0:LOADFILE` → IOP `ioman` file I/O → **no PFS support**.
- `fileXioOpen` → IOP `iomanX` file I/O → **PFS IS supported**.
- `mass:` (USB) works because FAT32/BDM drivers register with BOTH `ioman` and `iomanX`.
- **Resolution**: The current code uses `open/read` (which goes through `fileXio` → `iomanX`) instead of `SifLoadElf`.

---

## Current Implementation (Attempt 5 — Pending Hardware Verification)

`LoadELFFromFileWithPartition` in `src/elf_loader/src/elf.c` now does:

1. **Read** the POPSTARTER ELF into a bram buffer at `0xC0000` using `open/read` (fileXio-backed, proven to work with PFS paths in the main process).
2. **Parse** ELF headers from the bram buffer — extract entry point, program headers, gp from `PT_MIPS_REGINFO` if present.
3. **Copy** LOAD segments from the bram buffer to their target virtual addresses (0x100000+) via `memcpy`. Zero BSS region (memsz - filesz).
4. **IOP reset sequence** — identical to the working USB path (`LoadELFFromFileExecPS2RebootIOP`):
   ```c
   FlushCache(0);
   while (!SifIopReset(NULL, 0)) {}
   while (!SifIopSync()) {}
   SifInitRpc(0);
   SifLoadFileInit();
   SifLoadModule("rom0:SIO2MAN", 0, NULL);
   SifLoadModule("rom0:MCMAN", 0, NULL);
   SifLoadModule("rom0:MCSERV", 0, NULL);
   SifLoadFileExit();
   SifExitRpc();
   FlushCache(0);
   FlushCache(2);
   ```
5. **ExecPS2** to POPSTARTER entry point at 0x100000 with gp=0.

### Why this should work
- The `open/read` to bram is safe — no overlap with code being executed.
- After `memcpy` of POPSTARTER segments to 0x100000+, our code continues from instruction cache (POPSLoader code was overwritten in physical memory but remains cached).
- `FlushCache(0)` writes back data cache (harmless — same POPSTARTER data). `FlushCache(2)` invalidates instruction cache so next fetch gets POPSTARTER code.
- The IOP reset + ROM module reload + FlushCache + ExecPS2 sequence is identical to the working USB path, which also overwrites 0x100000+ via `SifLoadElf` before executing the same sequence.

### Potential concerns with current implementation
1. **argv survival**: `argv_static` in `luasystem.cpp` is a static buffer at some address in 0x100000+. After `memcpy` writes POPSTARTER data over 0x100000+, the data cache has POPSTARTER data at those addresses. `FlushCache(0)` writes it back (it's the same data, no corruption). But the argv string content in the data cache is now POPSTARTER data, not the original selector string. If argv[0] address falls within 0x100000-0x128C80 (POPSTARTER's footprint), ExecPS2 may read garbage for argv. However, the USB path has the same issue (SifLoadElf also overwrites 0x100000+), and it works — suggesting argv strings survive (likely because they're at higher addresses in POPSLoader's larger BSS/data region, above 0x128C80).
2. **Instruction cache eviction**: The post-memcpy code (SifIopReset wrappers, etc.) must remain in the 16KB instruction cache. These are small functions, so this should be fine. The USB path has the same constraint.
3. **Data cache coherency for `memcpy` vs IOP DMA**: `SifLoadElf` (USB) loads via IOP DMA which writes directly to physical memory and may invalidate EE data cache lines. Our `memcpy` goes through the data cache. After `memcpy`, data cache has POPSTARTER data (dirty). `FlushCache(0)` writes it back (same data). This is functionally equivalent.

---

## PS2 Technical Context

### EE Memory Map
| Range | Name | Description |
|---|---|---|
| `0x00000000-0x0007FFFF` | Kernel | PS2 BIOS/kernel (512KB) |
| `0x00080000-0x000FFFFF` | bram | BIOS unused memory (512KB). Embedded loader targets 0x84000-0x100000. |
| `0x00100000-0x01FFFFFF` | Game memory | User programs (31MB). POPSLoader and POPSTARTER load here. |

### PFS Mount Slots
- `pfs0:` through `pfs3:` are distinct mount points on the IOP.
- `HDD_SLOT_POPSTARTER = 3` → POPSTARTER partition mounts on `pfs3:`.
- `ResolveHddReadablePath` in `system.lua` returns paths like `pfs3:/POPSTARTER.ELF`.

### Dual Filesystem APIs on IOP
- **`ioman`** (legacy): Used by `rom0:LOADFILE` (which `SifLoadElf` calls). Does NOT see PFS.
- **`iomanX`** (extended): Used by `fileXio`. DOES see PFS. Also sees `mass:` (USB).
- `mass:` registers with BOTH, which is why USB works via `SifLoadElf`.

### ELF Loading APIs (ps2sdk)
| Function | Mechanism | PFS? | IOP Reset? | Used by |
|---|---|---|---|---|
| `SifLoadElf` | rom0:LOADFILE (ioman) | NO | No | USB path (works) |
| `LoadExecPS2` | Kernel-level | NO | No | Non-partition path |
| `open/read` (fileXio) | iomanX | YES | No | HDD path (current fix) |

---

## What Has Already Failed (DO NOT REPEAT)

### 17+ failed attempts across two investigation sessions. Full details in `FAILURES.md`.

**Hypothesis families that are EXHAUSTED — do not retry without genuinely new evidence:**

1. **argv[0] / selector-shape changes** (3 attempts) — Changing the selector path format does not fix it.
2. **HDD game-slot preparation / preservation** (2 attempts) — Keeping PFS slots mounted does not fix it.
3. **Embedded-loader IOP reset toggling** (2 attempts) — Neither resetting nor not resetting IOP inside the embedded loader fixes it. **The embedded loader never starts anyway.**
4. **Partition-aware handoff variants** (5 attempts) — Normalizing paths, keeping raw paths, matching upstream contract — none fix it.
5. **Custom fileXio loading inside embedded loader** (2 attempts) — Dead code. Loader never executes.
6. **PFS mount-slot mismatch fix** (1 attempt) — Real bug (canonicalize stripped pfs3:→pfs:), fixed, but insufficient alone.
7. **Embedded-loader bypass via reboot_iop=1** (1 attempt) — Routes through `LoadELFFromFileExecPS2RebootIOP` which uses `SifLoadElf` → fails on PFS.
8. **fileXio fallback in embedded loader** (1 attempt) — Dead code. Loader never executes.
9. **Pre-read bram buffer for embedded loader** (1 attempt) — Buffer was pre-read correctly but loader never started to consume it.

### Key principle: The embedded loader at bram (0x84000) NEVER STARTS. Do not modify `loader.c` expecting it to have any effect on HDD POPSTARTER launches.

---

## Working Launch Paths (DO NOT BREAK)

### USB Path (reference implementation — works)
```
system.lua: reboot_iop=0, no partition
  → luasystem.cpp: LoadELFFromFileExecPS2("mass:/...", 1, argv)
    → elf.c: SifLoadElf("mass:/POPSTARTER.ELF") → succeeds (mass: on ioman)
    → ExecPS2 to 0x100000
```

### USB with IOP Reboot Path (works)
```
system.lua: reboot_iop=1 (for PFS exec paths)
  → luasystem.cpp: LoadELFFromFileExecPS2RebootIOP("mass:/...", 1, argv)
    → elf.c: SifLoadElf → FlushCache → IOP reset → ROM modules → ExecPS2
```

### HDD Path (BROKEN — being fixed)
```
system.lua: reboot_iop=0, partition="hdd0:__sysconf:"
  → luasystem.cpp: LoadELFFromFileWithPartition("pfs3:/POPSTARTER.ELF", "hdd0:__sysconf:", 1, argv)
    → elf.c: [CURRENT] direct load via open/read + memcpy + IOP reset + ExecPS2
```

---

## Rules for This Task

1. **Evidence-first**: Do not make changes without understanding WHY the current code fails. If the current attempt (direct load) fails on hardware, investigate before making the next change.
2. **Minimal diffs**: Only touch files necessary for the fix. Do not refactor unrelated code.
3. **Do not break working paths**: USB, MMCE, MX4SIO, SMB must continue working. The dispatch in `luasystem.cpp` routes HDD through `LoadELFFromFileWithPartition` and everything else through `LoadELFFromFileExecPS2` or `LoadELFFromFileExecPS2RebootIOP`. Changes to `LoadELFFromFileWithPartition` only affect HDD.
4. **Do not repeat failed hypotheses**: See the exhaustive list above. If proposing something that overlaps with a failed family, explain what genuinely new evidence supports retrying.
5. **Do not modify the embedded loader expecting it to help HDD**: `loader.c` code never executes for HDD. The embedded loader is dead for this path.
6. **Update `FAILURES.md`** with outcomes of any hardware-verified attempt.
7. **Update `QA_REGRESSION_MATRIX.md`** run log with test results.
8. **Follow `AGENTS.md`** operational rules: minimal diffs, cite file paths, mark unverified claims.

---

## What To Do Next

1. **If the current attempt (commit `2e4ebb9`, direct load) has NOT been hardware-tested yet**: Build, deploy, and test on hardware. The CI should produce artifacts. Report what happens.

2. **If the current attempt SUCCEEDS on hardware**: Update `FAILURES.md` to mark it resolved. Update `QA_REGRESSION_MATRIX.md` with the passing run. Update `STATE.md` and `ROADMAP.md`. Clean up dead code in `loader.c` if desired (optional, low priority).

3. **If the current attempt FAILS on hardware**: Investigate. Key questions:
   - Does the screen stay black, or does it briefly flash/change color?
   - Does the `BlockLaunchFailure` UI appear (meaning `loadELF` returned control)?
   - Add GS color diagnostic stages directly to `LoadELFFromFileWithPartition` in `elf.c` (since this code runs in the main process, not the broken embedded loader):
     ```c
     // After successful file read:
     *((volatile unsigned long long *)0x120000E0) = 0x00FF00; // GREEN = file read OK
     // After memcpy of segments:
     *((volatile unsigned long long *)0x120000E0) = 0x0000FF; // BLUE = segments loaded
     // After IOP reset:
     *((volatile unsigned long long *)0x120000E0) = 0xFFFF00; // YELLOW = IOP reset done
     // Before ExecPS2:
     *((volatile unsigned long long *)0x120000E0) = 0xFF00FF; // PURPLE = about to exec
     ```
   - The last color visible tells you exactly where the failure is.
   - Consider whether `argv[0]` data was corrupted by the `memcpy` (address overlap with POPSTARTER's load range).
   - Consider whether the instruction cache evicted critical code during the post-load sequence.
   - Consider whether `FlushCache(0)` after `memcpy` behaves differently than `FlushCache(0)` after `SifLoadElf` (cache coherency difference between CPU writes and IOP DMA writes).

---

## Summary

The HDD POPSTARTER launch has two confirmed broken layers: (1) ExecPS2 to bram never transfers control, and (2) SifLoadElf can't access PFS. The current code bypasses both by doing a direct file read + memcpy + IOP reset + ExecPS2 from the main process — mirroring the working USB path but using `open/read` (fileXio) instead of `SifLoadElf`. This is pending hardware verification. If it fails, add diagnostic GS colors to `LoadELFFromFileWithPartition` (in the main process, NOT the embedded loader) to identify exactly where execution stops.
