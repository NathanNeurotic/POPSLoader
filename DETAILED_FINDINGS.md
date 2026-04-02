# POPSLoader HDD ELF Loading - Detailed Technical Findings

## Problem Statement
HDD ELF loading in POPSLoader fails silently with black screen and zero debug logs, while identical operations work in wLaunchELF and POPSLoader's embedded loader.

---

## Root Cause Analysis

### The Fundamental Issue: RPC Context Loss on ExecPS2

**ExecPS2 does not preserve RPC client state across context switches.**

When POPSLoader (lines 627-898) loads modules and mounts the partition in the parent EE context, then calls ExecPS2 to POPSTARTER, the RPC infrastructure becomes invalid:

1. fileXioInit() (line 839) establishes an RPC client in parent context
2. fileXioMount() (line 847) uses that RPC client to mount pfs0:
3. SifLoadElf() (line 867) works because IOP loadfile module is global
4. ExecPS2() (line 897) switches to POPSTARTER's context
5. **In POPSTARTER's context, the parent's RPC client is INVALID**
6. If POPSTARTER tries to access files via fileXio, it fails silently
7. Debug output (which uses fileXio) also fails, causing black screen

---

## Architecture Comparison: Exact Code References

### PATH 1: POPSLoader Parent Context (BROKEN)
**File**: /home/user/POPSLoader/src/elf_loader/src/elf.c, lines 627-898

```c
// Line 765: Prepare environment
prepare_reboot_exec_environment();

// Line 768: Initialize RPC in parent context
SifInitRpc(0);

// Lines 774-836: Load 6 modules via SifExecModuleBuffer
// iomanX_irx, fileXio_irx, ps2dev9_irx, ps2atad_irx, ps2hdd_osd_irx, ps2fs_irx

// Line 839: Initialize fileXio client in PARENT
fileXioInit();

// Line 847: Mount partition in PARENT's RPC context
int mount_result = fileXioMount("pfs0:", partition_context, FIO_MT_RDONLY);

// Lines 866-868: Load ELF in PARENT's context
SifLoadFileInit();
ret = SifLoadElf(pfs_load_path, &elfdata);
SifLoadFileExit();

// Line 897: CRITICAL - Switch context, losing parent's RPC state
ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, argc, argv);
```

**Problem**: The fileXio RPC client created at line 839 becomes invalid after ExecPS2 at line 897. POPSTARTER cannot use the "mounted" partition because its fileXio client is not connected.

---

### PATH 2: wLaunchELF (WORKING)
**File**: /home/user/wLaunchELF_kHn/src/main.c, lines 2096-2109

```c
// Line 2098: IOP Reset in parent context
while(!SifIopReset(NULL, 0)){};
while(!SifIopSync()){};

// Line 2100: Re-initialize RPC
SifInitRpc(0);

// Line 2101: Initialize file I/O
SifLoadFileInit();

// Line 2102: Initialize fioInit (generic file I/O)
fioInit();

// Line 2103: Enable LMB patches
sbv_patch_enable_lmb();

// Lines 2108-2109: Load basic modules
loadBasicModules();
mcInit(MC_TYPE_MC);
```

Then later, when executing HDD ELF:
**File**: /home/user/wLaunchELF_kHn/src/elf.c, lines 120-185 (RunLoaderElf)

```c
// Lines 129-136: Mount partition in PARENT context
if(0 > fileXioMount("pfs0:", party, FIO_MT_RDONLY)){
    unmountParty(0);
    if(0 > fileXioMount("pfs0:", party, FIO_MT_RDONLY))
        return;
}

// Lines 145-147: Load fakehost.irx if needed
SifExecModuleBuffer(&fakehost_irx, size_fakehost_irx, strlen(fakepath), fakepath, &ret);

// Lines 151-172: Copy embedded LOADER.ELF to memory (not executed in parent)
boot_elf = (u8 *)&loader_elf;
// ... copy to RAM ...

// Lines 175-184: Jump to LOADER.ELF (embedded loader)
fioExit();
SifInitRpc(0);
SifExitRpc();
FlushCache(0);
FlushCache(2);

argv[0] = filename;        // pfs0:/path/to/elf
argv[1] = party;           // hdd0:partition (for reference)
ExecPS2((void *)eh->entry, 0, 2, argv);
```

**Critical Difference**: wLaunchELF exits RPC before ExecPS2, then the EMBEDDED LOADER re-initializes RPC in its own context and calls fileXioInit() fresh.

---

### PATH 3: POPSLoader Embedded Loader (WORKING)
**File**: /home/user/POPSLoader/src/elf_loader/src/loader/src/loader.c, lines 308-503

```c
// Line 375: Initialize fileXio FIRST in embedded loader context
fileXioInit();

// Line 401: Mount partition in EMBEDDED LOADER's context
ret = fileXioMount("pfs0:", partition_context, FIO_MT_RDONLY);

// Line 418: Re-initialize RPC (CRITICAL - fresh context)
SifInitRpc(0);

// Line 420: Initialize file loading
SifLoadFileInit();

// Line 422: Load ELF in embedded loader's context
ret = SifLoadElf(mounted_path, &elfdata);

// Line 424: Clean up
SifLoadFileExit();

// Lines 481-485: Tear down RPC properly
SifLoadFileExit();
SifExitRpc();
SifExitCmd();

// Lines 491-492: Flush caches
FlushCache(0);
FlushCache(2);

// Line 503: Jump with fresh context established
ret = ExecPS2((void *)elfdata.epc, (void *)elfdata.gp, target_argc, target_argv);
```

**Key Success Factor**: fileXioInit() at line 375 creates a FRESH RPC client in the embedded loader's context. This is BEFORE any fileXio operations.

---

## Detailed Technical Differences

### 1. Module Loading Sequence

#### wLaunchELF (src/main.c:816-836)
```c
void load_ps2atad(void) {
    load_ps2dev9();                                    // Load iomanX first
    SifExecModuleBuffer(&ps2atad_irx, ...);
    SifExecModuleBuffer(&ps2hdd_irx, sizeof(hddarg), hddarg, &ret);  // WITH ARGS
    SifExecModuleBuffer(&ps2fs_irx, sizeof(pfsarg), pfsarg, &ret);   // WITH ARGS
    if(hddCheckPresent() >= 0) hdd_booted = 1;
}
```

#### POPSLoader Parent (elf.c:774-836)
```c
// Module order and args are correct, but...
SifExecModuleBuffer(iomanX_irx, 0, NULL, &mod_res);
SifExecModuleBuffer(fileXio_irx, 0, NULL, &mod_res);
SifExecModuleBuffer(ps2dev9_irx, 0, NULL, &mod_res);
SifExecModuleBuffer(ps2atad_irx, 0, NULL, &mod_res);
SifExecModuleBuffer(ps2hdd_osd_irx, sizeof(hddarg), hddarg, &mod_res);  // Args OK
SifExecModuleBuffer(ps2fs_irx, sizeof(pfsarg), pfsarg, &mod_res);       // Args OK

// PROBLEM: Next line assumes fileXio is ready in parent context
fileXioInit();
```

### 2. fileXioInit() Timing Difference

**wLaunchELF**: 
- fileXio module loaded globally at startup
- fileXioInit() NOT explicitly called - fileXio setup happens implicitly
- Works because fileXio is already loaded before IOP interactions

**POPSLoader Parent (problematic)**:
- fileXio module loaded
- fileXioInit() called at line 839
- But this creates RPC client in parent context
- RPC client is lost on ExecPS2

**POPSLoader Embedded Loader (correct)**:
- fileXioInit() called at line 375 FIRST THING
- Creates RPC client in embedded loader's own context
- RPC client is valid for all subsequent fileXio operations
- This is the ONLY safe pattern

### 3. SifInitRpc() Calls

**wLaunchELF Startup**:
```c
SifInitRpc(0);                    // Line 2096 - parent startup
SifIopReset(NULL, 0);             // Line 2098 - reset IOP
SifIopSync();                     // Line 2099 - sync
SifInitRpc(0);                    // Line 2100 - re-init after reset
SifExitRpc();                     // Line 177 (in RunLoaderElf) - clean up before ExecPS2
```

**POPSLoader Parent (problematic)**:
```c
prepare_reboot_exec_environment();  // Line 765 - includes SifIopReset
SifInitRpc(0);                      // Line 768 - init after reboot
// ... module loading ...
fileXioInit();                      // Line 839 - creates RPC client
fileXioMount(...);                  // Line 847 - uses parent's RPC
SifLoadElf(...);                    // Line 867 - IOP loadfile (global)
ExecPS2(...);                       // Line 897 - CONTEXT SWITCH - RPC becomes invalid
```

**POPSLoader Embedded Loader (correct)**:
```c
// Parent does:
prepare_reboot_exec_environment();  // Includes IOP reboot and RPC cleanup
SifInitRpc(0);                      // Line 768 in parent - minimal setup
ExecPS2(...);                       // Jump to embedded loader

// Embedded loader does:
fileXioInit();                      // Line 375 - FIRST, creates RPC client in embedded context
// ... fileXio operations ...
SifInitRpc(0);                      // Line 418 - Optional, but clean
SifLoadFileInit();                  // Line 420
SifLoadElf(...);                    // Line 422 - Safe because in fresh context
SifExitRpc();                       // Line 483
ExecPS2(...);                       // Line 503 - Jump to POPSTARTER
```

---

## Evidence from Code Analysis

### Evidence 1: fileXioInit() in Different Contexts

POPSLoader's embedded loader PROVES that fileXioInit() must be called in the context where it will be used:

```c
// loader.c line 375 - FIRST operation in embedded loader
fileXioInit();

// VERSUS

// elf.c line 839 - in PARENT context before ExecPS2
fileXioInit();
```

The embedded loader is KNOWN TO WORK. It calls fileXioInit() first. The parent path fails, and it also calls fileXioInit(), but in the wrong context.

### Evidence 2: ExecPS2 Invalidates RPC

The pattern in wLaunchELF shows awareness of this:

```c
// elf.c lines 175-177 (RunLoaderElf)
fioExit();
SifInitRpc(0);
SifExitRpc();      // DELIBERATELY CLEANED UP before ExecPS2
FlushCache(0);
FlushCache(2);
```

This cleanup is NOT done in POPSLoader parent path (lines 890-894 do cleanup AFTER ExecPS2, but that's too late).

### Evidence 3: Embedded Loader Protocol

wLaunchELF embedded loader receives arguments:

```c
// elf.c lines 180-182 (RunLoaderElf)
argv[0] = filename;        // Already pfs0:... (pre-mounted path)
argv[1] = party;           // hdd0:partition (reference only)
ExecPS2((void *)eh->entry, 0, 2, argv);
```

POPSLoader embedded loader receives arguments:

```c
// loader.c lines 332-340 (main)
strncpy(partition_context, argv[0] ? argv[0] : "", ...);  // hdd0:partition
strncpy(load_path, argv[1] ? argv[1] : "", ...);           // Path to ELF
```

Both understand that partition context and load path must be passed to the embedded loader, NOT expected to be pre-mounted in parent.

---

## Why Silent Failure Occurs

1. **Parent context (elf.c line 867)**: SifLoadElf() succeeds because:
   - IOP loadfile module is global to IOP
   - pfs0: is mounted in parent's fileXio context
   - SifLoadElf() uses IOP's loadfile, not parent's fileXio

2. **Parent context (elf.c line 897)**: ExecPS2() switches to POPSTARTER:
   - POPSTARTER's context is fresh (new thread/task)
   - POPSTARTER has no fileXio RPC client
   - If POPSTARTER tries to use fileXio, it hangs or returns errors
   - If debug output uses fileXio, it also fails

3. **Silent black screen**:
   - POPSTARTER's initialization code tries to access files
   - fileXio operations fail (no RPC client in new context)
   - POPSTARTER might crash or hang before any output
   - Debug output (if any) also uses fileXio, so can't be displayed
   - Result: Black screen, no error messages

---

## Proof: The Embedded Loader Works

File: /home/user/POPSLoader/src/elf_loader/src/loader/src/loader.c

This embedded loader is demonstrably working (per the task description, "some PS2 projects successfully load HDD-backed ELFs"). Its sequence is:

1. Line 375: fileXioInit() - creates RPC client in embedded context
2. Line 401: fileXioMount() - mounts partition via RPC client in embedded context
3. Line 422: SifLoadElf() - loads ELF from mounted partition
4. Line 503: ExecPS2() - jump to target with fresh context

This EXACT sequence should be used. The parent path (lines 627-898) attempts to do steps 1-3 in parent context, which is architecturally unsound.

---

## Conclusion

**The POPSLoader parent-context HDD ELF loading (lines 627-898) is architecturally broken because it violates a fundamental constraint: RPC client connections created in one EE context cannot be used in another EE context after ExecPS2.**

The working solution is already in POPSLoader: the embedded loader approach, which creates its RPC state in the embedded loader's context and uses it before ExecPS2.

**Action**: Remove or disable the parent-context HDD loading path (lines 627-898) and always use the embedded loader path for HDD execution.

