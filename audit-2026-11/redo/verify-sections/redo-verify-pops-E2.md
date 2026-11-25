# Adversarial Verification — POPSLoader Redo, Chunk E2 (EE system/ELF/misc + bdm_query)

- Subject: `~/workspace/Sable-audit-redo/Redo-POPSLoader.md`
- Clone (read-only): `~/workspace/audit-clones-2026-11-13/POPSLoader` at pin `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (HEAD verified by `git rev-parse` before reading).
- Method: refute-first. Every cited file opened at the cited lines with surrounding context; dead-code/no-caller claims re-derived with independent repo-wide greps over `src/`, `bin/POPSLDR/*.lua`, `etc/`, `Makefile`; every numeric claim re-derived by command.
- Findings in chunk: RE-POPS-023, 033, 034, 054, 058, 063, 068, 069, 076, 078, 084, 085, 086, 087 (14).

---

### RE-POPS-023 — VERIFIED

Both stages re-read in full; the claimed missing checks are genuinely missing, and the INFERRED/Med severity framing is honest.

- Parent stage (`src/elf_loader/src/elf.c`, `ExecuteViaEmbeddedLoader`, def. line 397): the only ELF check before the copy loop is the 4-byte magic at line 413 (`*(u32*)boot_header->ident != ELF_MAGIC` → `-5`). The loop at lines 460–468 (cited 460-468, exact) iterates `boot_header->phnum` with no cap, never consults `phentsize`, never checks `offset + filesz` against any blob size (no blob size is even available/used), and `memcpy`s to the header-supplied `vaddr` plus a `memsz` BSS memset with no destination-range check. Defeating-evidence hunt: the function does perform other checks (argc cap `-2`, metadata magic/version/valid at 0x83C00, argv0 validity `-7`) — none of them touch phdr sanity, file range, or destination range, so none defeat the claim. The finding itself concedes this stage is acceptable-ish because the blob is the project's own embedded child loader (`loader_elf`); that concession is in the text, not hidden.
- Child stage (`src/elf_loader/src/loader/src/loader.c`, `load_elf_via_filexio`, lines 195–273): caps `phnum` at `LOADER_ELF_MAX_PHDRS` = 16 (line 233, as claimed), checks the magic and both read lengths (`-ENOEXEC`/`-EIO`), then `fileXioRead(fd, phdrs[i].vaddr, phdrs[i].filesz)` directly to the header-supplied `vaddr` (plus unchecked `memsz` memset). No check against the loader's own BRAM span (linkfile: BRAM ORIGIN 0x84000, LENGTH 496K — the loader's `MAIN_REGION`), no check against the metadata page (`EMBEDDED_LOADER_METADATA_ADDR` = 0x00083C00, defined identically in both files), no RAM-range check, and `hdr.entry` is returned via `*entry_out` and used as `elfdata.epc` with only a `!= 0` test in `main` — never checked to lie inside a loaded segment. All three claimed missing checks confirmed missing.
- Severity honesty: the finding is labelled INFERRED, Confidence Med, states the realistic trigger is a truncated/corrupt user-supplied launcher rather than an attacker, and scopes the parent stage as "acceptable only because the blob is the project's own child loader." That matches the code facts. No inflation found.
- Scope precision note (does not change the verdict): the child fileXio loader only runs when `should_use_filexio_direct_load()` is true — a `pfs`/`PFS`/`hdd`/`HDD`-prefixed `load_path` that is *not* an HDD partition context (loader.c:91-99, 344). Other paths (including `mass:`) go through PS2SDK `SifLoadElf`. The finding's phrase "a file on pfs/hdd/mass storage" overstates the direct loader's reach by one word; the no-validation mechanism is exactly as claimed wherever this loader does run.
- Fix sanity (LESS-NOT-MORE): three structural checks per stage with the existing negative-code convention; no redesign. Sound.

### RE-POPS-033 — VERIFIED

`src/luacontrols.cpp` read in full.

- `lua_getpressure` (lines 148–213, cited exactly) declares `padButtonStatus pad;` uninitialised, gates `padRead(port, 0, &pad)` only on `PAD_STATE_STABLE`/`PAD_STATE_FINDCTP1` and discards its return value, calls `ds34bt_get_data` / `ds34usb_get_data` discarding their returns, then switches over `pad.right_p` / `left_p` / … So on a non-stable pad, a disconnected pad, or all reads failing, the returned pressure is read from never-written stack memory. The `pressure = 255` initialiser does not save it: every named-button case overwrites from `pad.*_p`.
- Sibling contrast confirmed: `lua_getleft` (82–117) and `lua_getright` (119–146) both zero-initialise (`padButtonStatus buttons = {0}`), seed neutral 127 defaults, track a `have` flag from the read return values, and return (0,0) when no source produced data — with an in-code comment describing exactly this hardening. `lua_getpressure` was indeed missed.
- Fix sanity: mirror the siblings. Minimal and correct.

### RE-POPS-034 — VERIFIED

`src/luaHDD.cpp` lines 42–64 read directly.

- `UmountPart`: `PFS[3] = '0' + luaL_checkinteger(L, 1)` at line 47 on the fixed `"pfs0:"` template, with **no** guard at all; result passed to `fileXioUmount`. Index 17 → `'0'+17 = 'A'` → `pfsA:`; index −1 → `'/'` → `pfs/:` — both examples in the finding reproduce exactly.
- `mnt()`: `PFS[3] = '0' + index` at line 62, guarded only by `index > 0`; result passed to `fileXioMount`. Any index ≥ 10 writes a non-digit byte; large indices truncate through `char`.
- Valid-domain claim confirmed: the exec path in `src/elf_loader/src/elf.c` caps slots at 3 (`slot <= 3` loops/checks at lines 100, 189; keep-mask `& 0x0F`), and shipped Lua callers (`bin/POPSLDR/system.lua` mount/unmount wrappers) pass tracked slot values. No defeating range check exists in either binding or in `MountPart` (which forwards `indx` unchecked).
- Fix sanity: range-check 0–9 (or 0–3) in both bindings. Minimal, correct.

### RE-POPS-054 — WEAKENED

The duplication counts are exact; the lookup-normalisation claim that justifies the fix is false for bare names, and the fix as written would break live callers.

- Counts re-derived by script over `src/embed_assets.cpp`: the `g_embedded_assets[]` table contains exactly **100** `ASSET_ENTRY` rows in source text — 50 bare keys + 50 `POPSLDR/`-prefixed keys — over exactly **49** unique symbols. Distribution: 48 symbols appear twice; `asset_usbd_irx_usbexfat` appears 4× (the documented mx4sio alias, bare + prefixed). The finding's "100 entries / 49 unique blobs / 50 + 50" is correct as a source-text count.
- Count drift worth recording: two of the 100 rows (bare + prefixed `default.png` / `asset_default_png`) sit under `#ifdef HAVE_ASSET_DEFAULT_PNG`. That macro is defined by the Makefile (lines 75–79) only when `bin/POPSLDR/IMG/default.png` exists — and it does **not** exist in this checkout (consistent with RE-POPS-089). The compiled table in the shipped configuration is therefore **98 entries over 48 unique blobs**, not 100/49.
- The defeating evidence is in `embedded_get` itself (embed_assets.cpp:243–293): normalisation maps `IMG/…` → `POPSLDR/IMG/…` and any other slash-containing input → `POPSLDR/…`, and passes `POPSLDR/…` through — but a **slash-free bare name is looked up unchanged** (`lookup_key` still equals `input`). It never maps `USB.png` → `POPSLDR/IMG/USB.png` or `system.lua` → `POPSLDR/system.lua`. The finding's statement that "the lookup side already normalises bare names … into one canonical key" is therefore wrong for the bare form, and the duplicated half does **not** "exist only to serve callers that pass the prefixed form verbatim" — the bare half is load-bearing: `bin/POPSLDR/images.lua` registers sources as bare filenames (`{"USB", "USB.png"}`, etc.) and passes them verbatim to `System.getEmbeddedAsset`, i.e. into `embedded_get("USB.png")`, which can only hit the bare row.
- Consequence for the fix: "keep only the prefixed half and let `embedded_get`'s existing normalisation map every caller form onto it; delete the 50 bare rows" would 404 every bare-name lookup (all `images.lua` image loads). A correct fix must first *add* bare-name canonicalisation — and that is not a single rule, since bare image names canonicalise to `POPSLDR/IMG/<name>` while bare non-image names canonicalise to `POPSLDR/<name>` (a try-both fallback would be needed). The duplication is real and worth removing, but it is not the free deletion the finding describes.
- True scope: table duplication VERIFIED (100 source rows / 49 symbols; 98/48 as compiled in this checkout); normalisation justification REFUTED for bare names; fix UNSAFE as written.

### RE-POPS-058 — VERIFIED

- `Makefile:98`: `ps2atad.o` is in `IOP_MODULES`, and `EE_OBJS = $(APP_CORE) $(LUA_LIBS) $(IOP_MODULES) $(EMBEDDED_RSC)` (line 124), so the bin2c blob is linked into every ELF unconditionally.
- Repo-wide grep for `ps2atad_irx` / `size_ps2atad_irx` over `src/` + `Makefile`: the **only** EE-source reference is the unused `IMPORT_BIN2C(ps2atad_irx)` extern at `src/luaHDD.cpp:172`. `Load_HDD_IRX` (luaHDD.cpp:197+) never loads it: it calls `EnsureAtaBdm()` (ata_bd) and loads only `ps2hdd_osd_irx` and `ps2fs_irx`. The in-code comments (luaHDD.cpp:183–186, 218–222; mirrored in luasystem.cpp:1688+) document exactly the finding's rationale — ata_bd replaced plain ps2atad, and loading both was the APA-boot freeze. No other file references the symbol, so removing the `IOP_MODULES` entry cannot break another caller.
- Second limb confirmed: `IMPORT_BIN2C(poweroff_irx)` at luaHDD.cpp:170 is likewise never referenced in that file (grep over `src/` finds no use of the plain `poweroff_irx` symbol; the distinct `asset_smb_poweroff_irx` embed-table blob is a different symbol and is used — the finding correctly scopes its claim to the luaHDD extern).
- Fix sanity: delete one Makefile list entry + two extern lines. Clean LESS.

### RE-POPS-063 — WEAKENED

The cache-defeat mechanism is verbatim true; the claimed current cost ("page-entry code pays one full enumeration per name") has no payer at this pin.

- Mechanism re-derived from the whole flow in `src/luasystem.cpp`: `GetMassRootByBackendNameInternal` (def. line 337; cited range 321-360 covers it) begins at lines 343–344 with `mass_backend_cache_valid = false; bdm_rpc_bound = false;` — exactly as claimed — then calls `FetchBdmList(&list)` into a **local** list (it does not even repopulate the cache, so the cache is left invalid for the next caller too). `FetchBdmList` (277) → `EnsureBdmQueryRpc` (254): because `bdm_rpc_bound` was just cleared, every call re-runs `SifInitRpc(0)` + `SifBindRpc(&bdm_rpc_client, BDM_QUERY_RPC_ID, 0)` and then a full `SifCallRpc` device-list round-trip. Contrast confirmed: `lua_get_mass_backend_info` uses `EnsureMassBackendCache()` and serves from `mass_backend_cache` with no RPC. `lua_refresh_mass_backends` (521–526, cited exactly) also sets `bdm_rpc_bound = false` with no unbind before refreshing. Every line-level claim checks out.
- Defeating evidence on impact: repo-wide grep for `getMassRootByBackendName` / `BackendName` over `bin/`, `etc/`, `src/` finds **no Lua caller at all** — the binding is registered (`luasystem.cpp:2581`) but no shipped Lua invokes it at this pin. So no page-entry code currently "resolves several backends by name" or pays the per-name enumeration; the cost is latent in a registered-but-uncalled binding, not a live storage-page cost. (This also makes the binding a member of the RE-POPS-048 no-caller family — see Candidates.)
- Fix sanity: routing the by-name lookup through `EnsureMassBackendCache` like `lua_get_mass_backend_info` is straightforward (the cache holds the same `bdm_dev_list_t` the internal function scans, matching on `info->name` / `parId`) and remains the right fix *if* the binding is kept; if it is instead deleted as callerless, the defect dies with it. Either way the finding's structural diagnosis stands; only its present-tense cost framing is overstated.

### RE-POPS-068 — VERIFIED

- Numeric claim re-derived by command: `512 × 33 = 16,896` bytes. Source confirms the shape: `src/luaHDD.cpp:130-131` — `#define LP_MAX_PARTS 512` and `static char lp_names[LP_MAX_PARTS][33];` inside `ListPartitions` (cited range 124–165 covers the function). `static` → permanent BSS for the life of the process, as claimed.
- The stated reason for the static is present verbatim in the comment (snapshot before touching the Lua heap so a `longjmp` cannot strand a ps2hdd directory slot; names cap at 32 bytes + NUL = 33). The enumeration loop truncates with a log line at the cap. No defeating evidence: nothing else sizes or reuses this table.
- Fix sanity: cutting the cap (e.g. 64) keeps the snapshot/longjmp property and returns ~14.8 KB; per-call allocation also preserves the directory-slot property. LESS-sound either way.

### RE-POPS-069 — VERIFIED

- `iop/bdm_query/bdm_query.c` read in full (101 lines). `_start` (lines 84–101; cited 84-101 exact): builds the thread, `thread_id = CreateThread(&thread)` (95), starts it only `if (thread_id >= 0)` (96–98), then unconditionally `return MODULE_RESIDENT_END;` (100). A `CreateThread` failure therefore leaves a resident module with no RPC server registered — EE binds then fail/time out with no IOP-side trace. Exactly as claimed.
- Cited comparison verified against **both** ds34 standalone `_start` functions in scope: `modules/ds34bt/iop/ds34bt.c` `_start` ends `if (thid > 0) { StartThread; return MODULE_RESIDENT_END; } return MODULE_NO_RESIDENT_END;`, and `modules/ds34usb/iop/ds34usb.c` `_start` ends with the identical pattern. The finding's proposed fix ("return `MODULE_NO_RESIDENT_END` when `thread_id < 0`, matching the ds34 standalone `_start` functions") names a real, in-tree precedent. (Trivial nuance: ds34 tests `thid > 0` where bdm_query tests `>= 0`; irrelevant to the failure path.)
- Secondary limb confirmed and correctly scoped: the RPC handler (lines 36–40; cited 36-40) does `(void)buf; (void)size;` — the 64-byte figure is the IOP-side `bdm_rpc_buffer[64]` registered with `sceSifRegisterRpc` (line 33, 77), i.e. where a future command's payload would land with no length available. The finding explicitly recommends leaving `(void)size` alone until a second command exists — appropriately LESS.
- Fix sanity: one-line return-code change. Sound.

### RE-POPS-076 — VERIFIED

Side-by-side diff of the two bodies:

- `src/main.cpp:459-478` `LoadIrxChecked` and `src/luasystem.cpp:362-380` `LoadIrxCheckedBuffer` are line-for-line the same function: `id`/`ret` initialised to −1, `SifExecModuleBuffer(irx, size, 0, NULL, &ret)`, identical out-parameter handling, identical failure rule `id < 0 || ret < 0` → false, else true. The **only** differences are the name and the two `DPRINTF` lines main.cpp adds (one on failure, one on success) — precisely the finding's "differing only in the DPRINTF lines main.cpp adds." In luasystem's copy the `name` parameter is entirely unused (it exists only for main-style logging parity).
- Both load sites confirmed as the two module-loading centres (main.cpp boot loads; ~25 `LoadIrxCheckedBuffer` call sites in luasystem.cpp), so the "policy change must be made twice" consequence holds.
- Fix sanity: keeping one implementation and crossing the main↔luasystem boundary is precedented in-tree (`EnsureAtaBdm`, `EnsureDev9`, `g_dev9_loaded` already cross it). Note for the implementer: both copies are currently `static`, so the fix needs a header declaration + de-static, and dropping main.cpp's copy drops its two DPRINTF lines (no-ops in practice per RE-POPS-082). Still LESS-positive.

### RE-POPS-078 — VERIFIED

`src/system.cpp:80-166` read in full (cited 80-168).

- `ResolveAssetPath` (80–108) hand-rolls the `':'` absolute-path shortcut and the `app_dir` / `app_dir + "POPSLDR/"` candidate walk with inline `stat` + copy-out, twice, and does **not** use the `ResolveAssetCandidate` helper defined immediately below it (110–119).
- `ResolveAssetPathTyped` (121–166) re-implements the same `':'` shortcut, then repeats the walk pattern twice more — IMG arm (4 candidates via the helper) and IRX arm (4 candidates via the helper) — and falls back to `ResolveAssetPath` for `ASSET_GENERIC`. So the "try candidate, stat it, copy it out" pattern lives in three bodies across ~90 lines, as claimed; a search-path change can land in only some of them.
- Fix sanity: collapsing the generic function onto the typed one (whose generic fallback already exists) while keeping both public names/signatures is feasible and leaves the Lua bindings untouched. One implementation care point: the typed function's generic arm currently *calls* `ResolveAssetPath`, so the generic body must move into the typed function rather than the wrapper pointing at itself. Still a net deletion.

### RE-POPS-084 — VERIFIED-DRIFT

Every dead item re-derived with an independent repo-wide census over `src/` + `bin/POPSLDR/` + `etc/`; all substance holds. Two cited line ranges and one failure-stage word drifted.

- `fntLoadDefault` (fntsys.cpp:390) and `fntFitString` (fntsys.cpp:851): defined + declared (fntsys.h:30, :45), zero callers anywhere. The Lua default-font path indeed calls `fntLoadbuff` directly (luagraphics.cpp:355, 370). ✓
- `gsKit_clear_screens` (graphics.cpp:890): defined + declared (graphics.h:78), zero callers. ✓ `drawImageCentered` (graphics.cpp:1020) and `drawRectCentered` (graphics.cpp:1093): defined, zero callers, and neither is declared in `graphics.h` (grep of the header finds only `gsKit_clear_screens`). ✓
- Dangling declarations: `src/include/system.h:19-20` declares `load_elf()` + the `load_elf_NoIOPReset` macro while `src/system.cpp`'s own removal comment (lines 168–181) records `load_elf` was removed; no definition exists. `src/include/luaplayer.h:51` declares `luaC_collectgarbage()` and `:61` declares `stackDump()`; a whole-clone grep finds no definition of either, only those two declaration lines. ✓
- `POWERPC_UART` block: `src/main.cpp:532-534` (`#ifdef` / `LOAD_IRX_NARG(ppctty_irx)` / `#endif`), and no IOP module list provides a `ppctty` blob (no Makefile hit). ✓ in substance.
- Corrected figures: `drawImageCentered` actually spans **1020–1038** (cited 1020-1045); `drawRectCentered` actually spans **1093–1096** (cited 1093-1098). Also, defining `POWERPC_UART` breaks the build at **compile** time, not only at link: `ppctty_irx` / `size_ppctty_irx` have no extern declaration in main.cpp either, so the `LOAD_IRX` macro expansion references undeclared identifiers. The finding's "breaks the link" understates how early it breaks; the conclusion (the flag is unbuildable) is unchanged.
- Fix sanity: pure deletions of unreferenced functions/declarations + the dead `#ifdef` block. LESS-clean. The ~150-line estimate is in range (23 + 55 + 11 + 19 + 4 lines of function bodies plus headers/block).

### RE-POPS-085 — VERIFIED

- Dead chain re-derived independently: `GetFreeSize()` (`src/system.cpp:215-254`) has exactly one caller in the tree — the `System.getFreeMemory` binding `lua_getFreeMemory` (`src/luasystem.cpp:887-895`, registered at :2532). Repo-wide grep for `getFreeMemory` over `src/`, `bin/`, `etc/` finds no Lua caller (only the C definition + registration). The chain is unreachable from any shipped code path, consistent with the RE-POPS-048 census the finding cites. (Cross-reference, not a duplicate: RE-POPS-048 counts this binding among its callerless 52; RE-POPS-085 is the deletion + algorithm-hazard finding for the chain behind it.)
- Algorithm description verified in `AllocateLargestFreeBlock` (system.cpp:183-213): initial probe `s0 = ~(size_t)0 ^ (~(size_t)0 >> 1)` = 0x80000000 (the top-bit / half-address-space value), then repeated real `malloc` probes binary-searching the largest allocatable block; `GetFreeSize` loops that, linking each largest block into a list (`*(void**)p` chain) before freeing them all. "Maximum heap churn … in exchange for a number nothing displays" is a fair characterisation on a 32 MB EE.
- Declarations: `GetFreeSize` is declared in **both** `src/include/system.h:21` and `src/include/luaplayer.h:47` — the finding's "both header declarations" is exact. (`AllocateLargestFreeBlock` has no header declaration; the fix's deletion list matches reality.)
- Fix sanity: delete function + helper + binding + both declarations. LESS-clean; a future readout via mallinfo-style query is correctly left as a hypothetical, not built.

### RE-POPS-086 — VERIFIED-DRIFT

The deadness claim — the finding's core — survives a full independent census. Two supporting details drifted.

- Caller census (own grep, whole clone: `src/`, `bin/`, `etc/`, headers, Makefile): `KickAtaAsyncBoot` (luasystem.cpp:1900) and `WaitAtaAsyncBootBounded` (luasystem.cpp:1934) appear only at their definitions, their own header comments, and one Lua *comment* (system.lua:9767). No caller, no header declaration, no registration. No `initATAAsync` binding exists in any registration table (registrations are `initATA`, `initATAStatus`, `initATAModules` only, luasystem.cpp:2561-2564), yet `bin/POPSLDR/system.lua:6330` probes `type(System.initATAAsync) == "function"` — always false, as claimed. `src/main.cpp`'s boot comment (lines ~680-682) concedes verbatim that "The EXP68 bounded-join worker stays dormant (no callers)". The live path is the synchronous `lua_ata_init_modules` / `EnsureAtaBdm`. Dead: confirmed.
- Numeric claim re-derived: `static u8 g_ata_async_stack[8192]` at luasystem.cpp:1865 — the **8,192-byte stack is exact**. Block size ~100 lines (state/stack/sema/thread/Kick/Wait ≈ 1864–1950) is also fair.
- Correction 1 — semaphore count: the dead block owns exactly **one** dedicated semaphore, `g_ata_async_modules_sema` (1868). The finding's Problem says "two semaphores." The second semaphore the worker touches, `g_ata_bdm_sema` (1710), is **shared infrastructure** used by the synchronous path (`EnsureAtaBdm`, `lua_ata_init_modules`) and must survive any deletion. The finding's own Fix correctly says "its module semaphore" (singular) — the Problem's count is the drift.
- Correction 2 — the fix's status-state parenthetical: the synchronous path never writes `g_ata_async_state` (all writes are inside the worker/Kick/Wait: lines 1890, 1903, 1913, 1924). So "keeping `lua_ata_init_status` reading a state that the synchronous path sets" describes a write that does not exist. What actually keeps the binding truthful after deletion is that the state stays permanently 0 (idle / never-starting) — which is exactly what its live Lua callers need (system.lua:7193-7198 and 9775-9788 poll it as a STILL_STARTING cascade bound). Correct deletion set: worker thread fn + stack + `g_ata_async_modules_sema` + Kick + Wait + the stale Lua `initATAAsync` probe; keep the state variable + `lua_ata_init_status` binding.
- Fix sanity with those corrections: one bring-up mechanism remains, LESS-positive, Risk Med fairly labelled given the documented race history in the block's own comments.

### RE-POPS-087 — VERIFIED

Unsatisfiability proved by tracing `lookup_key` through every branch of `embedded_get` (`src/embed_assets.cpp:243-293`; fallback at 282–285, cited exactly).

Setup: `input` is `path_or_name` after stripping an `embed:/` prefix, leading `./` components, and leading `/` characters. `lookup_key` starts as `input` (same pointer). It is reassigned to the stack buffer `normalized` in exactly three branches:

1. `strncmp(input, "POPSLDR/", 8) == 0` — requires a `/` in `input`.
2. `strncmp(input, "IMG/", 4) == 0` — requires a `/` in `input`.
3. `strchr(input, '/') != NULL` — requires a `/` in `input` by construction.

Fallback condition: `asset == NULL && lookup_key != input && strchr(input, '/') == NULL`.

- Case A — `input` contains no `/`: no branch can fire, so `lookup_key == input` (pointer-equal), the second conjunct is false. (Note `!=` here is a *pointer* comparison, which only strengthens the result: reassignment is the only way the pointers can differ.)
- Case B — `input` contains a `/`: the third conjunct `strchr(input, '/') == NULL` is false, regardless of which branch fired.

In every reachable state at least one conjunct fails; the second `embedded_find(input)` can never execute. The prefix-stripping prologue does not open a loophole: it mutates `input` *before* `lookup_key` is initialised from it, and branch membership is evaluated on the stripped string. The finding's reasoning ("reassigned away from `input` only in the three branches that all require a `/`") is exactly right.

Fix sanity: deleting the fallback is safe — for a slash-free input the first lookup already searched `input` unchanged, so no behaviour is lost. Pure LESS.

---

## Tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 10 | RE-POPS-023, 033, 034, 058, 068, 069, 076, 078, 085, 087 |
| VERIFIED-DRIFT | 2 | RE-POPS-084, 086 |
| WEAKENED | 2 | RE-POPS-054, 063 |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — |
| **Total** | **14** | |

## Candidates (new defects / observations, not verdicts)

- **CANDIDATE E2-C1 — `System.getMassRootByBackendName` is a registered binding with zero callers.** `lua_get_mass_root_by_backend_name` is registered at `src/luasystem.cpp:2581`, but a repo-wide grep over `bin/`, `etc/`, and `src/` finds no Lua (or other) caller at pin `29272cdd`. It belongs to the RE-POPS-048 callerless-binding family; if that census is re-run, this binding should be counted, and RE-POPS-063's fix should be decided jointly with its keep-or-delete outcome (caching a binding nobody calls is optional; deleting it deletes the cache-defeat defect with it).
- No other new defects found in this chunk. Overlaps flagged inline: RE-POPS-085 ↔ RE-POPS-048 (the `getFreeMemory` binding is in 048's census; 085 is the chain-deletion finding — cross-reference, not a duplicate), RE-POPS-063 ↔ RE-POPS-048 (per C1), RE-POPS-054 ↔ RE-POPS-089 (the conditional `default.png` rows are why 054's compiled count is 98/48 rather than 100/49 in this checkout).
