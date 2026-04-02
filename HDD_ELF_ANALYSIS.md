# HDD ELF Loading Comparison: POPSLoader vs Reference Implementations

## Executive Summary
The POPSLoader HDD ELF loading path (lines 627-898 in elf.c) contains an **architectural mismatch** compared to wLaunchELF: it performs HDD module loading and mounting in the **parent EE context** but then immediately calls `ExecPS2` to jump to POPSTARTER, leaving the HDD partition mounted. This is fundamentally different from both wLaunchELF's approach and the POPSLoader's own embedded loader.

---

## CRITICAL ARCHITECTURAL DIFFERENCE

### wLaunchELF Approach (WORKING)
1. **Parent context**: Loads ALL HDD modules and mounts partition at pfs0:
   - load_filexio() via SifExecModuleBuffer (fileXio)
   - load_ps2atad() via SifExecModuleBuffer (ps2dev9, ps2atad, ps2hdd, ps2fs)
   - fileXioMount("pfs0:", partition, FIO_MT_RDONLY)

2. **Embedded Loader (LOADER.ELF)** receives:
   - argv[0] = hdd0:partition (the partition context)
   - argv[1] = pfs0:... (already mounted path)
   - The embedded loader uses SifLoadElf() on the already-mounted pfs0: path

3. **Execution Flow**:
   - Parent mounts pfs0: and checks ELF header via fileXioOpen
   - Parent calls RunLoaderElf which ExecPS2s to LOADER.ELF
   - LOADER.ELF receives pre-mounted partition and uses SifLoadElf() on pfs0:
   - LOADER.ELF jumps directly to target ELF with partition still mounted

### POPSLoader Parent ELF Loading (lines 627-898) - PROBLEMATIC
1. **Parent context**: 
   - Calls prepare_reboot_exec_environment() (IOP reboot)
   - Calls SifInitRpc(0)
   - Loads 6 HDD modules via SifExecModuleBuffer (iomanX, fileXio, ps2dev9, ps2atad, ps2hdd, ps2fs)
   - Calls fileXioInit()
   - Calls fileXioMount("pfs0:", partition_context, FIO_MT_RDONLY)
   - Calls SifLoadElf(pfs_load_path, &elfdata) - **DIRECTLY IN PARENT**
   - ExecPS2s directly to POPSTARTER

2. **Architectural Problem**:
   - Parent ELF never re-initializes RPC after loading modules
   - SifLoadElf() is called in parent, but no guarantee modules properly initialized
   - No fileXioInit() call visible before fileXioMount
   - ExecPS2 jump causes RPC/fileXio context to be lost

### POPSLoader Embedded Loader (loader.c) - WORKING
1. **Parent context**:
   - Calls prepare_reboot_exec_environment() (IOP reboot)
   - Calls SifInitRpc(0)
   - ExecPS2s to embedded loader with arguments

2. **Embedded Loader context**:
   - Calls fileXioInit() FIRST (line 375)
   - For HDD: calls fileXioMount("pfs0:", partition_context, FIO_MT_RDONLY)
   - Then calls SifInitRpc(0) again (line 418)
   - Then calls SifLoadFileInit() and SifLoadElf()
   - Cleans up RPC and jumps to POPSTARTER

---

## Module Loading Sequence Analysis

### wLaunchELF's load_ps2atad() (src/main.c:816-836)
```
load_ps2dev9()                           // iomanX first (dependency)
SifExecModuleBuffer(&ps2atad_irx, ...)
SifExecModuleBuffer(&ps2hdd_irx, args)  // WITH arguments
SifExecModuleBuffer(&ps2fs_irx, args)   // WITH arguments
```

**CRITICAL**: ps2hdd and ps2fs are loaded WITH ARGUMENTS in wLaunchELF.

### POPSLoader Parent (elf.c:774-836)
```
SifExecModuleBuffer(iomanX_irx, ...)
SifExecModuleBuffer(fileXio_irx, ...)
SifExecModuleBuffer(ps2dev9_irx, ...)
SifExecModuleBuffer(ps2atad_irx, ...)
SifExecModuleBuffer(ps2hdd_osd_irx, hddarg, ...)  // With arguments ✓
SifExecModuleBuffer(ps2fs_irx, pfsarg, ...)       // With arguments ✓
fileXioInit()                                     // Called AFTER loading
SifLoadElf(pfs_load_path, ...)                    // Directly in parent
ExecPS2(...)                                      // Jump away
```

### POPSLoader Embedded Loader (loader.c:375-425)
```
fileXioInit()                                     // FIRST
fileXioMount("pfs0:", partition_context, ...)
SifInitRpc(0)                                     // RE-INIT
SifLoadFileInit()
SifLoadElf(mounted_path, ...)
SifLoadFileExit()
SifExitRpc()
SifExitCmd()
ExecPS2(...)
```

---

## Key Findings

### 1. SifInitRpc() Timing
- **wLaunchELF Parent**: SifInitRpc(0) called once at startup
- **POPSLoader Parent (buggy path)**: SifInitRpc(0) called once after IOP reboot, then modules loaded, no re-init
- **POPSLoader Embedded (working)**: SifInitRpc(0) called in child after ExecPS2, allows fresh RPC state
- **wLaunchELF Embedded Loader**: Receives pre-mounted partition, assumes pfs0: already set up

### 2. fileXioInit() Timing
- **wLaunchELF Parent**: Modules loaded first, fileXioInit() assumed to work because fileXio module loaded globally
- **POPSLoader Parent (buggy)**: fileXioInit() called AFTER module loading but BEFORE mount
- **POPSLoader Embedded (correct)**: fileXioInit() called FIRST before any fileXio operation
- **wLaunchELF Embedded Loader**: No fileXioInit() call - assumes parent initialized it

### 3. ELF Loading Context
- **wLaunchELF**: SifLoadElf() called on ALREADY-MOUNTED pfs0: path in embedded loader's fresh context
- **POPSLoader Parent (buggy)**: SifLoadElf() called in parent's RPC context, which might not be fully initialized
- **POPSLoader Embedded (correct)**: SifLoadElf() called in embedded loader's context with fresh fileXio initialization
- **CRITICAL**: ExecPS2 does NOT preserve parent's RPC state - each context must reinitialize

### 4. Mounting Strategy
- **wLaunchELF Parent**: Mounts pfs0:, passes mounted path to loader
- **POPSLoader Parent (buggy)**: Mounts pfs0: in parent, expects POPSTARTER to use it (but RPC lost after ExecPS2)
- **POPSLoader Embedded (correct)**: Receives partition name, mounts fresh in child context

### 5. Silent Failure Root Cause
**The parent-context HDD ELF loading is likely failing silently because:**
- SifLoadElf() is called in parent context after module loading
- But the fileXio RPC client state is not properly synchronized
- fileXioInit() creates an RPC client connection that gets lost on ExecPS2
- ExecPS2 switches contexts, and any RPC state from parent is invalidated
- POPSTARTER receives control with no valid fileXio RPC connection
- Result: Black screen, no debug output (because fileXio also used for logging)

---

## Module Argument Differences

### wLaunchELF (load_ps2atad, line 818-820)
```c
static char hddarg[] = "-o" "\0" "4" "\0" "-n" "\0" "127";
static char pfsarg[] = "-m" "\0" "4" "\0" "-o" "\0" "10" "\0" "-n" "\0" "40";
```

### POPSLoader Parent (elf.c:776-777)
```c
static const char hddarg[] = "-o\0" "4\0" "-n\0" "20";
static const char pfsarg[] = "-m\0" "4\0" "-o\0" "10\0" "-n\0" "40";
```

**DIFFERENCE**: 
- wLaunchELF: ps2hdd "-n 127" (127 partitions)
- POPSLoader: ps2hdd "-n 20" (20 partitions) 

This is minor but shows different tuning.

---

## Why The Embedded Loader Path Works

The embedded loader path works because:
1. Parent does IOP reboot and minimal setup
2. ExecPS2 to fresh context (child process)
3. Child inherits mounted pfs0: partition (from parent)
4. Child calls fileXioInit() to establish RPC client
5. Child's fileXio operations work because they're on fresh RPC state
6. Child can read ELF from mounted partition
7. Child jumps to target with fresh context

---

## Why The Parent-Context HDD Path Fails

The parent-context HDD path fails because:
1. Parent loads modules after IOP reboot
2. Parent calls fileXioInit() once
3. Parent mounts partition
4. Parent calls SifLoadElf() in parent's RPC context
5. **PROBLEM**: SifLoadElf is NOT a fileXio operation - it uses IOP's loadfile module
6. **BUT** the IOP's module state might not be properly synchronized
7. Even if SifLoadElf works, the parent calls ExecPS2
8. **CRITICAL**: ExecPS2 invalidates parent's RPC state
9. POPSTARTER gets control but has no valid fileXio connection
10. If POPSTARTER tries to access files, fileXio fails silently
11. Debug logging (which uses fileXio) also fails, causing black screen

---

## Comparison Table

| Aspect | wLaunchELF | POPSLoader Parent (buggy) | POPSLoader Embedded (working) |
|--------|-----------|--------------------------|------------------------------|
| IOP Reboot | Yes (startup) | Yes (in path 627-898) | Yes (in parent before ExecPS2) |
| Module Load Context | Parent | Parent | Parent loads, child receives |
| fileXioInit() | Implicit (fileXio loaded) | Line 839 | Line 375 (child) |
| Partition Mount | Parent (pfs0:) | Parent (pfs0:) | Child (fresh context) |
| ELF Load Context | Embedded loader | Parent | Embedded loader (child) |
| ELF Load Method | SifLoadElf | SifLoadElf | SifLoadElf or fileXio |
| SifInitRpc Location | Startup | After IOP reboot | Child context |
| RPC State at Jump | N/A (no jump) | Lost (parent→child) | Fresh (child context) |
| Jump Method | ExecPS2 | ExecPS2 | ExecPS2 |
| Mount State at Jump | N/A | Mounted (but lost RPC) | N/A |

---

## Recommendations

1. **Immediate Fix**: Do NOT use parent-context HDD ELF loading
   - Always use embedded loader path for HDD execution
   - OR adopt wLaunchELF's approach of mounting in parent ONLY if you use embedded loader

2. **Remove lines 627-898** from elf.c - this path cannot work as designed

3. **Verify Embedded Loader**:
   - Ensure fileXioInit() called FIRST (it is - line 375)
   - Ensure SifInitRpc(0) called in child context (it is - line 418)
   - Ensure partition context passed correctly (it is)

4. **Alternative if parent-context loading needed**:
   - Do NOT call ExecPS2 from parent after mounting
   - Load target ELF in parent context
   - Ensure target runs in parent's RPC context (no ExecPS2)
   - This would require POPSTARTER to be integrated, not launched

