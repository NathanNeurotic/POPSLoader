# D-10 HDD POPSTARTER Boot Fix - Comprehensive Context for Claude Opus/Sonnet

## Problem Statement

**D-10 black screen hang when selected from POPSLOADER menu.**

- **Symptom**: Menu appears, user selects D-10 game, screen goes black, no output, never recovers
- **Working case**: D-10 boots fine when POPSTARTER is on USB/memory card
- **Root issue**: Loading POPSTARTER ELF from HDD partition hangs; basic system works fine otherwise
- **Critical observation**: "Not just POPSTARTER - I've tested replacing POPSTARTER with other ELFs and they all black screen"

## Architecture Overview

### How POPSLOADER Launches Games

1. **POPSLOADER menu** (Lua-based, runs as main ELF)
2. **User selects D-10** → RunPOPStarterGame() called (system.lua:3804)
3. **Determine boot type** → HDD policy detected (policy.name == "HDD")
4. **Resolve POPSTARTER location** → Determines if POPSTARTER is on USB or HDD
5. **Build launch context** → Creates exec_partition_context, exec_path, arguments
6. **Call System.loadELF()** → Lua binding to C function LoadELFFromFileExecPS2RebootIOPWithPartition
7. **Load + Execute POPSTARTER** → IOP reboot, HDD modules loaded, partition mounted, ELF loaded, ExecPS2 jump

### Key Code Points

**Lua side (system.lua)**:
- Line 3804: `RunPOPStarterGame(gamelocation, game, ui_scene, launch_options)`
- Line 3809: `popstarter_partition_context = ResolvePopstarterPartitionContext(...)`
- Line 3854: `popstarter_exec_path = BuildPartitionScopedExecPath(popstarter)` (normalizes to "pfs:/" path)
- Line 3699-3719: `System.loadELF(exec_path, reboot_iop, args, exec_partition_context)`

**C side (src/elf_loader/src/elf.c)**:
- Line 573: `LoadELFFromFileExecPS2RebootIOP(filename, argc, argv)` - wrapper calling:
- Line 578: `LoadELFFromFileExecPS2RebootIOPWithPartition(filename, partition=NULL, argc, argv)`
- This function is where HDD POPSTARTER loading happens

### Partition/PFS Architecture

**HDD paths have multiple formats:**
1. `hdd0:partition:pfs0:/path/file.elf` (explicit pfs slot)
2. `hdd0:/partition/path/file.elf` (slash-separated, no pfs slot)
3. `hdd0:partition/path/file.elf` (colon-slash mixed, no pfs slot)

**PFS slots (0-3)**: Different pfs0:, pfs1:, pfs2:, pfs3: mount points for different partitions

**Example**:
- POPSTARTER: `hdd0:__common:pfs0:/POPS/POPSTARTER.ELF`
- D-10 game: `hdd0:game:pfs1:/D10.ELF`
- These are on DIFFERENT partitions and DIFFERENT pfs slots

### Fixes Applied So Far

1. ✓ **HDD filename detection** (line 607-609): Now detects HDD-backed filename even if partition=NULL
2. ✓ **Multi-format partition extraction** (lines 628-658): Handles all 3 path formats (colon-sep, slash-v1, slash-v2)
3. ✓ **PFS slot detection** (lines 667-697): Extracts pfs slot from filename, defaults to pfs1 for slash-separated formats
4. ✓ **Dynamic mount point** (line 762): Mounts at detected pfs slot, not hardcoded pfs0:
5. ✓ **Error checking** (lines 720-757): SifLoadModule errors caught, mount errors handled
6. ✓ **Debug logging** (conditionally #ifdef DEBUG): Added dprintf() at critical points

**Latest commit**: cafb99a - Added debug logging and dual CI builds (Release + Debug artifacts)

## What the Debug Logs Will Reveal

When testing the Debug build, these outputs tell us:

```
DEBUG: HDD scenario detected
  → Code correctly detected HDD path (expected: YES for D-10)

DEBUG: partition_context='hdd0:__common:'
  → The partition where POPSTARTER is located

DEBUG: pfs_slot=0, mount_path='pfs0:', load_path='pfs0:/POPS/POPSTARTER.ELF'
  → Detected pfs slot and built load path

DEBUG: Attempting to mount 'hdd0:__common:' at 'pfs0:'
DEBUG: Mount successful
  → Partition mounted successfully

DEBUG: About to call SifLoadElf with path='pfs0:/POPS/POPSTARTER.ELF'
DEBUG: SifLoadElf returned ret=0, epc=0xXXXXXXXX, gp=0xYYYYYYYY
  → ELF loaded successfully, epc/gp are valid entry/global pointers

DEBUG: SifLoadElf successful, about to ExecPS2
  → About to jump to loaded ELF
```

**If logs STOP at any point, that's where the hang occurs.**

Example failure scenarios:
- Logs stop at "Attempting to mount" → Mount is hanging
- Logs show "SifLoadElf returned ret=-1" → Load failed
- Logs show "SifLoadElf returned ret=0, epc=0x0" → Load succeeded but entry point invalid
- Logs show "SifLoadElf successful, about to ExecPS2" then nothing → Jump succeeded but ELF hangs

## Potential Issues to Investigate

### 1. PFS Slot Mismatch
**Hypothesis**: POPSTARTER path specifies pfs0, game D-10 is at pfs1. Code mounts POPSTARTER's partition at pfs0, but maybe that's wrong?
- **Check**: Are POPSTARTER and game on same partition or different partitions?
- **Check**: Is pfs slot being extracted correctly from both paths?
- **Check**: Should we use pfs slot from partition_context instead of filename?

### 2. Partition Context Format
**Hypothesis**: partition_context is just `hdd0:__common:` but maybe needs pfs slot info?
- **Check**: What exactly is in exec_partition_context when passed to LoadELFFromFileExecPS2RebootIOPWithPartition?
- **Check**: Is the partition being mounted correctly given the partition_context format?

### 3. Path Mismatch
**Hypothesis**: extract_exec_relpath() is extracting wrong path for some edge case
- **Check**: What is actual relpath being extracted vs what's expected?
- **Check**: Does path building `pfs_slot:/relpath` produce correct mount point?

### 4. IOP/RPC State
**Hypothesis**: Something about IOP reboot or RPC initialization is silently failing
- **Check**: Are SifLoadModule() calls actually succeeding? (Added error checks but no logging)
- **Check**: Is fileXioMount() actually succeeding or silently failing?
- **Check**: Is SifLoadElf() being called with correct RPC state?

### 5. Module Loading Order
**Hypothesis**: HDD modules loaded in wrong order or a dependency is missing
- **Current order**: IOMANX → FILEXIO → PS2DEV9 → PS2ATAD → PS2HDD → PS2FS
- **Check**: Is this the correct order? Do all modules load successfully?

### 6. Partition Already Mounted
**Hypothesis**: Partition is already mounted at a different pfs slot, causing conflicts
- **Check**: Does unmount_pfs_slots_for_exec(1) properly clear existing mounts?
- **Check**: Is there an assumption about which pfs slots are free?

## Instructions for Next Steps

1. **Run CI** on the current branch (with debug logging)
2. **Download BOTH artifacts**:
   - `POPSLOADER-Release.zip` (for comparison)
   - `POPSLOADER-Debug.zip` (for testing)
3. **Test Debug build on hardware**
   - Extract files to USB/HDD as needed
   - Boot POPSLOADER, select D-10
   - Watch console output for debug logs
   - **Capture/document where logs stop**
4. **Analyze log output** to determine actual failure point
5. **Based on logs, investigate the corresponding section**:
   - If mount fails → investigate fileXioMount behavior
   - If SifLoadElf fails → investigate path/module state
   - If jump succeeds but hangs → investigate ELF itself or post-ExecPS2 state

## Authority & Constraints

**You have authority to:**
- Refactor code based on actual debug log findings
- Add more targeted logging if needed
- Change architecture if logs prove current approach is fundamentally wrong
- Modify both C and Lua code if necessary

**Constraints:**
- Don't remove working USB/memory card POPSTARTER boot support
- Don't break non-HDD game launching
- Commit changes with clear message explaining what debug logs revealed
- Provide TEXT summary when done (no tools/artifacts unless needed)

## Previous Attempts (What Failed)

- ❌ Embedded loader approach (hangs immediately)
- ❌ SifLoadElf without proper module loading (fails silently)
- ❌ Hardcoded pfs0: mounting (possible pfs slot mismatch)
- ❌ Static code analysis without runtime visibility (kept finding micro-bugs but core issue persisted)

## Success Criteria

**Fix is correct when:**
1. D-10 boots from HDD POPSTARTER without black screen
2. User can select and launch D-10
3. POPSTARTER loads and executes normally
4. Game access works (not just POPSTARTER launch)
5. Non-HDD paths still work (no regression)
6. Debug logs show clean execution through ExecPS2

---

**Current branch**: `claude/fix-d10-hBKBh`  
**Latest commit**: cafb99a (debug logging + dual CI builds)  
**Test method**: GitHub Actions artifacts only  

Use debug logs to find the real failure point.
