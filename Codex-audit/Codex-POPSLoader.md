# Codex — POPSLoader audit

**-unfinished- checkpoint:** This is the earlier baseline report, preserved with its validation results. See [the resume index](Codex-RESUME-unfinished.md) and linked continuation findings for the later review. Earlier read-only statements describe source handling before the user authorized this report-only draft PR.

Snapshot: `NathanNeurotic/POPSLoader`, default branch `master`, commit `29272cddbf0122f14e76bc3bdd75e3b46aa870be`. Read-only source review; repository files and refs have not been changed. This report contains **42 findings**. The live native and embedded executable-Lua passes are complete apart from opaque key-initializer bytes; the exact remaining source/documentation gaps are listed below. This is **not an exhaustive-completion claim**.

Unless explicitly described as measured or as a source-declared capacity/count, proposed reductions are INFERRED until implemented. READ denotes source evidence, not hardware verification.

Benefits below distinguish source-declared storage from unmeasured linked/packed size and hardware timing. Priority order is corruption/crash prevention, responsiveness, RAM, then maintenance reductions. No PS2 hardware or PS2SDK is available here.

## Findings

### POPSLOADER-012 / Malformed VCD metadata turns a size into a huge memcpy / Category 6

- Location(s): `POPSLoader/src/retrogem.cpp:278-301`, `:340-345`, `:413-415`.
- Problem: The SYSTEM.CNF directory record supplies a 32-bit unsigned file size, which `rg_read_file` casts to signed `int` before bounding it to the small destination. A size of `0x80000000` becomes negative, selects a negative `len`, and converts that to a huge `memcpy` length.
- Fix: Bound the unsigned remaining size by the sector and destination-room limits before converting it to the copy-length type.
- Justification: A local type/order correction prevents a demonstrated malformed-image memory violation; no generalized parser framework is needed.
- Benefit: Prevents a launch-time crash/memory violation when inspecting a malformed VCD; negligible code-size change.
- Effort: S. Risk: Low. Confidence: High (READ; extracted production function reproduced `AddressSanitizer: negative-size-param`, size -2147483648, with only sector I/O mocked).

### POPSLOADER-001 / Delete the unused BMP decoder and its heap-overrun path / Category 6, 1, 4

- Location(s): `POPSLoader/src/graphics.cpp:428-849`, `:602-625`, `:630-632`, `:758-776`, `:878-884`; `POPSLoader/bin/POPSLDR/ui.lua:241-290`, `:296-307`.
- Problem: The 4-bit BMP path allocates a decoded texture of `TextureSize` bytes, but its nibble-swap loop accesses `FTexSize` bytes, where `FTexSize` is the entire remaining file. Extra trailing file bytes therefore make the loop overrun the texture allocation. The loader accepts BMP magic regardless of the `.png` filename.
- Fix: Delete `loadbmp` and the BMP magic-dispatch arm, keeping PNG as the artwork format. The UI cover/icon candidate builders use .png names, and no tracked runtime BMP assets have been identified.
- Benefit: Removes approximately 422 source lines plus a reachable heap-corruption path; linked/packed bytes not measured. Feature impact is loss of BMP contents disguised as PNG, outside the current PNG artwork naming contract.
- Effort: S. Risk: Med. Confidence: High (READ for overflow; INFERRED for feature-removal impact).

### POPSLOADER-017 / Bluetooth transfer errors index the pad array at minus one / Category 6

- Location(s): `POPSLoader/modules/ds34bt/iop/ds34bt.c:972-978`, `:1123-1125`, `:1128-1156`; `POPSLoader/modules/ds34bt/iop/ds34bt.h:77-79`; duplicate unbuilt fork `POPSLoader/modules/pademu/ds34bt.c:908-914`, `:1064-1095`, `POPSLoader/modules/pademu/ds34bt.h:63-65`. `Launchstation/iop/ds34bt/iop/ds34bt.c:972-978`, `:1123-1138`, `Launchstation/iop/ds34bt/iop/ds34bt.h:79`; `RiptOPL/modules/ds34bt/iop/ds34bt.c:972-978`, `:1123-1138`; `RiptOPL/modules/pademu/ds34bt.c:897-903`, `:1051-1066`.
- Problem: L2CAP_event_task returns its initial pad=-1 when resultCode is nonzero. Its callback checks only ret<MAX_PADS, accepts -1, and immediately reads ds34pad[-1].status, with additional reads/writes depending on the adjacent memory.
- Fix: Require a nonnegative pad as well as the existing upper bound before accessing the array.
- Justification: One missing lower-bound comparison fixes a concrete USB transfer-error memory access; no generalized validation layer is needed.
- Benefit: Prevents out-of-bounds IOP access in the listed shared copies after a failed Bluetooth bulk transfer; one condition added.
- Effort: S. Risk: Low. Confidence: High (READ).

### POPSLOADER-042 / Bound USB descriptor walks to the returned configuration / Category 6

- Location(s): `POPSLoader/modules/ds34usb/iop/ds34usb.c:126-154`; `POPSLoader/modules/ds34bt/iop/ds34bt.c:109-142`; duplicate unbuilt forks `POPSLoader/modules/pademu/ds34usb.c:119-147`, `POPSLoader/modules/pademu/ds34bt.c:108-137`. `Launchstation/iop/ds34usb/iop/ds34usb.c:126-154`; `Launchstation/iop/ds34bt/iop/ds34bt.c:109-142`; `RiptOPL/modules/ds34usb/iop/ds34usb.c:133-176`; `RiptOPL/modules/pademu/ds34usb.c:128-172`; `RiptOPL/modules/ds34bt/iop/ds34bt.c:109-142`; `RiptOPL/modules/pademu/ds34bt.c:109-138`. RiptOPL USB's negative-count guard is already present; descriptor-null/end checks remain missing.
- Problem: The drivers dereference device/config/endpoint lookup results without checking for a missing descriptor, then walk by endpoint->bLength with no configuration-end bound or descriptor-length check. DS4 unconditionally makes 21 iterations; a short/truncated configuration can therefore read beyond the descriptor data, and a zero-endpoint BT interface starts the decrement loop at -1.
- Fix: Reject missing descriptors and stop the existing walk at the configuration's total length; require enough bytes for each descriptor and a positive valid bLength before advancing. Preserve the real DS4 interface-count workaround within those bounds. Delete the unused forks instead of fixing them if applying POPSLOADER-022.
- Justification: These are concrete nullable/bounds-free dereferences of device-supplied descriptor data. Small local bounds replace blind iteration without introducing another USB parser layer.
- Benefit: Prevents IOP null/out-of-range reads or runaway walking on malformed/short USB descriptors; small code increase, no bytes/ms saving claimed.
- Effort: M. Risk: Med (DS4 descriptor compatibility). Confidence: High (READ for unchecked paths; physical-device failure occurrence INFERRED).

### POPSLOADER-011 / Untracked PFS recovery calls nil globals instead of its local helpers / Category 6

- Location(s): `POPSLoader/bin/POPSLDR/system.lua:585-618`, `:621-679`, `:786`, `:884`, `:1260`, `:1930-1931`.
- Problem: Recovery closures are defined before the local `MountHddPartitionTracked` and `ProbePathExists` declarations, so Lua binds those references as globals. Recovering an untracked PFS slot with a partition candidate raises `attempt to call a nil value` instead of resolving the launch target.
- Fix: Move the helper declarations/definitions before these closures, or forward-declare the two locals and assign their definitions later. Do not add wrappers or another recovery path.
- Justification: Local declaration ordering fixes the demonstrated Lua lexical-binding error with no behavioral expansion.
- Benefit: Fixes HDD custom-path recovery; only a few declaration changes, no claimed byte/timing saving.
- Effort: S. Risk: Low. Confidence: High (READ; reproduced on the real unmodified Lua chunk).

### POPSLOADER-016 / Failed controller-module startup can leave boot in an infinite RPC bind / Category 6, 5

- Location(s): `POPSLoader/src/main.cpp:683-688`; `POPSLoader/modules/ds34usb/ee/libds34usb.c:22-35`; `POPSLoader/modules/ds34bt/ee/libds34bt.c:25-38`; `POPSLoader/modules/ds34usb/iop/ds34usb.c:779-805`; `POPSLoader/modules/ds34bt/iop/ds34bt.c:1689-1718`.
- Problem: Boot calls both RPC initializers after unchecked IRX loads, and both initializers loop until a server appears. The IOP entrypoints explicitly return nonresident on semaphore, USB registration, or thread creation failure, so those failures leave the EE waiting forever before graphics initialization.
- Fix: Check the existing module-load/start result and skip that controller bind when startup failed. Give the bind loop one short bounded deadline and return its existing failure result if the server never registers.
- Justification: These local checks address actual nonresident error returns that otherwise create an infinite boot loop; they require no retry layer or alternate controller system.
- Benefit: Eliminates an unbounded black-screen boot hang on module initialization failure; small code increase, timing/bytes not measured.
- Effort: S. Risk: Low. Confidence: High (READ; failure-path consequence INFERRED from RPC registration control flow).

### POPSLOADER-002 / SMB connection waits freeze the render thread and one retry is unbounded / Category 5, 6

- Location(s): `POPSLoader/src/luasystem.cpp:2093-2103`, `:2301-2353`; `POPSLoader/bin/POPSLDR/system.lua:9365-9387`; `POPSLoader/bin/POPSLDR/ui.lua:1398-1417`, `:7158-7166`.
- Problem: `RunBusyTask` calls its worker synchronously; `smbNetUp` then sleeps for link/DHCP in native C without returning to drawing or input. Its `do/while (SmbApplyLinkMode(mode) != 0)` can also repeat forever when link stays up but applying the selected mode keeps failing.
- Fix: Fail once on a link-mode application error instead of retrying indefinitely. Replace the native sleeping link/DHCP loops with one-step status polling from the existing UI frame loop, retaining one deadline; do not introduce another worker/framework.
- Justification: A per-frame status poll directly fixes the proven synchronous stall; it replaces the sleep loops and allows the existing renderer/input loop to run.
- Benefit: Removes an unbounded hang and individual stalls of up to 30 seconds per wait; total wall-clock connection time is not benchmarked on hardware.
- Effort: M. Risk: Med. Confidence: High (READ).

**Re-triage required:** Current source/tests intentionally preserve separately configured static POPSTARTER addresses. See the resume index correction before applying the earlier recommendation below.

### POPSLOADER-015 / Pass the DHCP lease to the existing POPSTARTER handoff / Category 6

- Location(s): `POPSLoader/src/luasystem.cpp:2176-2209`, `:2321-2348`, `:2572`; `POPSLoader/bin/POPSLDR/system.lua:8434-8440`, `:9365-9418`; `POPSLoader/bin/POPSLDR/ui.lua:3930`, `:7203`.
- Problem: The native DHCP path obtains an address and exposes smbGetIPConfig specifically for POPSTARTER, but no embedded Lua caller reads it. MissingPopstarterNetFields still requires PS2_IP/NETMASK/GATEWAY and the DAT writer uses the static settings, so DHCP with blank fields can browse but is blocked at launch; stale populated fields can also describe a different address from the lease.
- Fix: After successful DHCP bring-up, read the existing smbGetIPConfig result and use those three current addresses for POPSTARTER's existing validation/DAT handoff, without overwriting the user's saved static configuration.
- Justification: Reusing the already implemented lease getter fixes an explicit browse-versus-launch mismatch with a few field assignments; no new network stack, fallback, or configuration option.
- Benefit: Makes DHCP browsing sessions launchable with their actual address; a few lines added, no size/timing saving claimed.
- Effort: S. Risk: Med. Confidence: High (READ for missing consumer and control flow; hardware launch consequence INFERRED).

### POPSLOADER-014 / Truncate replacement files and remove the duplicate HDD cache serializer / Category 6, 2

- Location(s): `POPSLoader/src/luasystem.cpp:2694-2695`; `POPSLoader/bin/POPSLDR/system.lua:2289-2297`, `:9880-9926`, `:9944-10023`, especially `:9979-9982` and `:10013-10017`.
- Problem: FCREATE means O_CREAT|O_WRONLY without O_TRUNC. HDD.CreateCache overwrites an existing cache directly, so a shorter refreshed list leaves old G/H records at the tail and ReadCache brings removed games/hidden state back; the direct HDD replacement writer has the same trailing-byte defect. HDD cache encoding/decoding also duplicates the already existing generic cache format.
- Fix: Add O_TRUNC to the replacement-only FCREATE mode; all tracked callers create/replace files, with Touch opening only absent files. Have the HDD cache functions reuse the existing SaveGameListCache/LoadGameListCache helpers, retaining their HDD mount preparation and state assignment.
- Justification: One open flag fixes the real short-replacement corruption; the existing shared cache routines remove the duplicate format implementation instead of adding another helper.
- Benefit: Fixes stale cache entries and replacement-file tails; approximately 40–50 Lua lines removable by consolidating serialization (INFERRED), no measured ELF saving.
- Effort: M. Risk: Med. Confidence: High (READ; stale-tail consequence follows POSIX open semantics, hardware reproduction not run).

### POPSLOADER-004 / Font-cache allocation failure dereferences null / Category 6

- Location(s): `POPSLoader/src/fntsys.cpp:192-223`, `:226-240`, `:428-459`; `POPSLoader/src/atlas.cpp:12-24`, `:84-109`, `:49-79`.
- Problem: New glyph pages, atlas nodes, atlas objects, and pixel buffers are dereferenced immediately after unchecked allocations. Browsing titles that populate a new Unicode page or atlas under EE heap pressure can therefore crash the UI instead of skipping the glyph.
- Fix: Check these allocations and use the existing null/failure returns; release any partially allocated atlas/node before returning. Propagate failure through `fntNewAtlas` and `fntGlyphAtlasPlace`.
- Justification: These are specific allocation-to-dereference paths in the live font renderer. A handful of local failure branches prevents null access without a new allocation abstraction or recovery subsystem.
- Benefit: Prevents low-memory UI crashes; small code increase, no claimed size saving.
- Effort: M. Risk: Low. Confidence: High (READ for defect; INFERRED for hardware trigger frequency).

### POPSLOADER-027 / Keep HDD cover/detail I/O off the render thread / Category 5

- Location(s): `POPSLoader/bin/POPSLDR/ui.lua:241-261,296-307,318-336,575-595,466-470,870,3742-3784`; `POPSLoader/bin/POPSLDR/system.lua:886-920`.
- Problem: GameList.Play invokes UpdateSelection directly; HDD cover and icon path resolution opens/probes files synchronously, and HDD details are synchronously opened/read again. Even removable cover misses perform a synchronous doesFileExist call after the worker already attempted the file. A slow or unavailable network/storage path therefore blocks input/rendering despite the resident art worker.
- Fix: Resolve the common HDD art mount once on entering the HDD list, build cover/icon/text paths without existence probes at selection time, and use the existing cover/text worker for HDD details too. Delete the post-worker existence re-probe; mark the failed path from the worker result instead (or use an already available worker error result). No new worker or fallback.
- Justification: This removes duplicate storage I/O and the standalone synchronous details reader by using the worker already used for removable media. The concrete render-thread call chain is cited; a new thread/framework is unnecessary.
- Benefit: Removes two synchronous image-resolution calls and one/two text resolutions plus an 8192-byte text read per HDD selection, and one post-worker existence probe per image miss; hardware ms unknown. Roughly30-60 lines removable INFERRED.
- Effort: M. Risk: Med. Confidence: High READ.

### POPSLOADER-003 / Decode PNG rows directly into their final texture buffer / Category 4, 5

- Location(s): `POPSLoader/src/graphics.cpp:169-193`, `:214-254`, `:264-306`; `:77-80`.
- Problem: Each color branch allocates the final texture and another full set of individually allocated image rows, then copies the rows into that texture. A large true-color cover temporarily consumes about twice its final pixel storage and makes one allocation per row.
- Fix: Point the libpng row-pointer array at the final texture rows, decode there, and perform the existing alpha/nibble conversion in place. Keep the existing interlace handling and byte-size checks.
- Benefit: Up to 1,474,560 bytes less temporary pixel storage at the existing true-color byte limit, plus up to 1,024 row allocations/copies avoided per decode (INFERRED upper bounds, not measured PS2 results). Removes allocation/free/copy loops in three branches.
- Effort: M. Risk: Med. Confidence: High (READ for duplicate storage; INFERRED for savings ceiling).

### POPSLOADER-028 / Missing settings file starts unrelated storage drivers and sleeps three seconds / Category 5, 3

- Location(s): `POPSLoader/bin/POPSLDR/system.lua:6297-6337,6859-6948,7065-7119`.
- Problem: On any mass-root boot with no sidecar settings file, LoadSettingsNonFatal performs three one-second sleeps. Its second and third passes unconditionally call initMX4SIO and initATAAsync, including a known USB boot with no configured need for either backend; the dedicated startup path uses actual boot/config paths to select backends, but runs later.
- Fix: Once the existing backend identity confirms that the boot root is mounted USB, return the normal missing-config/defaults result instead of sleeping or loading MX4SIO. Retain bounded settling for genuinely unresolved legacy mass roots; do not infer an absent device from an absent filename. The inert initATAAsync call is already covered by POPSLOADER-005.
- Justification: Using the existing mounted-device identity prevents real extra sleeps and unrelated driver loading for a known USB root; no new selection layer or fallback is needed. Preserve the documented legacy mass boot case rather than deleting its only resolution path.
- Benefit: Up to 3seconds of explicit sleeps avoided per normal missing-sidecar boot (wall-time not measured); two redundant MX4SIO initialization calls avoided; the ATA call is inert and counted under POPSLOADER-005. IOP bytes unknown.
- Effort: M. Risk: Med. Confidence: High READ for calls and sleeps; startup wall-time and driver residency INFERRED.

### POPSLOADER-036 / Avoid replaying credits and fixed holds on every boot / Category 5,8

- Location(s): `POPSLoader/bin/POPSLDR/ui.lua:1788,1943-2037,5493-5496`; `POPSLoader/bin/POPSLDR/system.lua:11689-11690,11762`.
- Problem: WelcomeDraw unconditionally renders a four-second splash hold plus a four-second credits hold and fades, without polling input. The show_boot_credits parameter is unused; the same credits remain available through Settings.
- Fix: Delete the automatic credits phase and fixed hold loops; retain necessary backend initialization and expose credits through the existing Settings action. No new skip option is needed.
- Benefit: Up to8seconds of fixed holds plus removed fade frames per boot INFERRED (depends Screen.flip refresh); around 20-40 lines removed. Hardware elapsed time not measured. This is an optional product tradeoff, not a crash fix.
- Effort: S. Risk:Low (presentation change). Confidence: High READ for waits/unconditional code, Med INFERRED for wall time.

### POPSLOADER-019 / Delete the game-partition write diagnostic from normal settings saves / Category 1, 5

- Location(s): `POPSLoader/bin/POPSLDR/ui.lua:4617-4633`; `POPSLoader/bin/POPSLDR/system.lua:980-1013`.
- Problem: Every successful Settings save with HDD loaded runs a TEST diagnostic unrelated to the settings file: it mounts game partitions, creates/writes/opens/deletes pldrs_wtest.tmp, and shows a diagnostic toast. It can try eleven partitions and runs synchronously in the save path.
- Fix: Delete ProbeHddSettingsWrite and its normal-save caller/toasts. Keep the real settings write result and existing game-marker error handling.
- Benefit: About 51 Lua/comment lines removed; at least one unnecessary create/write/delete cycle per successful probe and up to eleven mount/probe attempts avoided per save. Hardware ms unknown.
- Effort: S. Risk: Low. Confidence: High (READ).

### POPSLOADER-020 / Do one existence check instead of opening every missing path twice / Category 2, 5

- Location(s): `POPSLoader/bin/POPSLDR/system.lua:1260-1272`; `POPSLoader/src/luasystem.cpp:933-941`, `:1018-1029`.
- Problem: ProbePathExists first calls openFile and, after failure, calls doesFileExist. Both native APIs perform the same O_RDONLY open on the same path, so every miss repeats the storage directory walk without changing device state.
- Fix: Use the existing doesFileExist result once, preserving the local helper name and callers if useful. Delete the initial protected open/close branch.
- Benefit: One open attempt removed per missing candidate and approximately five Lua lines removed; storage ms not measured.
- Effort: S. Risk: Low. Confidence: High (READ).

### POPSLOADER-005 / Remove the dormant ATA worker and its synchronization scaffolding / Category 1, 3, 4

- Location(s): `POPSLoader/src/luasystem.cpp:1698-1721`, `:1759-1785`, `:1823-1982`; `POPSLoader/src/main.cpp:673-682`; `POPSLoader/bin/POPSLDR/system.lua:6330`.
- Problem: `KickAtaAsyncBoot` and `WaitAtaAsyncBootBounded` have no callers in tracked code, yet retain an 8,192-byte static stack, worker, semaphores, status state, and guards around the synchronous ATA path. Comments disagree about whether the worker is active; the native function table does not export `initATAAsync`.
- Fix: Delete the uncalled worker/join code and its stack, remove its status/locking guards where no concurrent ATA caller remains, and delete the inert Lua `initATAAsync` compatibility call. Preserve the currently used synchronous ATA module sequence.
- Benefit: Removes the declared 8,192-byte stack and roughly 150–200 source lines; actual linked/packed and BSS savings depend on linker garbage collection and are not measured.
- Effort: S. Risk: Med. Confidence: High (READ for definitions/call absence and current path).

### POPSLOADER-006 / Delete the superseded asynchronous image loader / Category 1, 3, 4

- Location(s): `POPSLoader/src/luagraphics.cpp:20-26`, `:42-46`, `:265-284`, `:489-512`, `:788-808`, `:838`, `:852-853`.
- Problem: `threadLoadImage`/`getLoadState`/`getLoadData` have no callers in the embedded Lua. They duplicate the resident cover worker and keep a 4,096-byte stack; unlike that worker they pass an unowned Lua string to a thread and expose an untagged global result.
- Fix: Delete this legacy API, worker, globals, stack, and registrations. Keep `coverLoadBegin`/`coverLoadPoll` and their text companion used by the UI.
- Benefit: Removes a declared 4,096-byte stack and about 80 lines, plus dormant unsafe code. Linked/packed savings not measured.
- Effort: S. Risk: Low. Confidence: High (READ).

### POPSLOADER-007 / Stop embedding the replaced plain ATA driver / Category 1, 4

- Location(s): `POPSLoader/Makefile:94-100`; `POPSLoader/src/luaHDD.cpp:170-174`, `:180-185`, `:217-229`; `POPSLoader/src/luasystem.cpp:1687-1696`, `:1725-1756`.
- Problem: `ps2atad.o` remains an explicit embedded IOP object although the HDD loader now calls `EnsureAtaBdm` and uses the BDM-enabled `ata_bd` instead. Its only current native mention is an unused extern declaration.
- Fix: Delete `ps2atad.o` from `IOP_MODULES` and its unused extern. Retain `ata_bd.o` for APA/PFS and exFAT.
- Benefit: One unreferenced embedded driver object removed; SDK blob bytes and final ELF savings cannot be measured without the pinned PS2SDK/link map.
- Effort: S. Risk: Low. Confidence: High (READ).

### POPSLOADER-034 / Remove an allocated font that is never drawn / Category 1,4

- Location(s): `POPSLoader/bin/POPSLDR/ui.lua:1200-1205,6835-6841`.
- Problem: UI.FONT.TITLE allocates a builtin font and sets its size, but no drawing path references it. The label font and existing LFONT/BFONT/SFONT supply the visible text.
- Fix: Delete TITLE/TITLE_SIZE and the unused font size-setting block.
- Benefit: One native font allocation and associated font/glyph state removed; RAM/ELF bytes not measured (binding corroborated atsrc/luagraphics.cpp354-357 calling fntLoadbuff; native font setup atsrc/fntsys.cpp314-343,374-393).
- Effort: S. Risk: Low. Confidence: High READ for no consumers; native allocation bytes unknown.

### POPSLOADER-029 / Retro GEM-only settings edit is silently discarded on Back / Category 6

- Location(s): `POPSLoader/bin/POPSLDR/ui.lua:3193-3194,5250-5255,5375-5402,5879-5884`.
- Problem: The Retro GEM toggle changes only RetroGemGameId and uses its snapshot for its dirty indicator, but HasUnsavedChanges omits that snapshot comparison. Changing only this field and pressing Back takes the no-edits discard path, so the edit is lost without the save prompt.
- Fix: Include the existing RetroGemGameId-versus-SettingsEntryRetroGemGameId comparison in HasUnsavedChanges.
- Justification: One comparison fixes a concrete lost-edit path using existing state; no new flags or test framework.
- Benefit: Actual persistence bug fixed; one condition added; size/time savings not claimed.
- Effort: S. Risk: Low. Confidence: High READ and host Lua reproduction.
- Evidence: `/tmp/codex-audit-work/POPSLoader-retrogem-dirty-repro.log`: unmodified predicate returns false with only Retro GEM changed, true when CoverArt is also changed.

### POPSLOADER-030 / BDMA staging reports success when its mode marker write failed / Category 6

- Location(s): `POPSLoader/bin/POPSLDR/system.lua:7770-7778,7844-7863,7909-7912,7965-7966,6116-6142`.
- Problem: FAT32 cleanup and normal BDMA staging ignore WriteBdmaModeMarker's boolean result and unconditionally return true; the fast/UDPFS branch correctly checks it. Failed marker writes leave a previous mode marker for ReconcileBdmaModeWithEffectiveState to read, so a reported-successful mode change can revert in the UI and be staged again.
- Fix: Return the marker writer's result from both unchecked branches instead of returning true.
- Justification: Reuses an existing failure signal and deletes the unconditional-success lines; no additional recovery or backup.
- Benefit: Fixes false success and repeated restaging/write risk; approximately2 lines net removed; bytes/ms unknown.
- Effort: S. Risk: Low. Confidence: High READ; host fragment reproduced: unmodified ApplyBdmaMode(FAT32) returns true when the markerwriter returns false.

### POPSLOADER-038 / Failed unhide is reported as success / Category 6

- Location(s): `POPSLoader/bin/POPSLDR/ui.lua:4288-4301`; `POPSLoader/bin/POPSLDR/system.lua:7780-7805,8667-8685`; `POPSLoader/src/luasystem.cpp:856-862`.
- Problem: Native removeFile ignores remove's error and returns no Lua values. SetGameHidden treats a successful pcall as successful removal, clears PLDR.HIDDEN and returns true even when the .hide file still exists on a read-only or failed device; the UI reports that the game is shown, but it becomes hidden again on the next scan.
- Fix: Reuse the existing DeleteIfExists helper in the unhide arm and return its failure, replacing the redundant existence/pcall block.
- Justification: The existing helper already verifies the file is gone, so reuse removes duplicated removal logic and fixes a concrete false-success path. No new check/helper is necessary.
- Benefit: Fixes incorrect UI state and persistence feedback; a few lines net removed, exact ELF bytes unknown.
- Effort: S. Risk: Low. Confidence: High READ.

### POPSLOADER-031 / False/nil ternary defeats the HDD working-directory suppression / Category 6

- Location(s): `POPSLoader/bin/POPSLDR/system.lua:11186,10580-10588`.
- Problem: `popstarter_on_hdd and false or nil` evaluates to nil for both values of popstarter_on_hdd. LaunchEngine checks for an explicit false to skip SetLaunchWorkingDirectory; that branch is therefore never reached for this context.
- Fix: Assign the false sentinel with an explicit conditional when POPSTARTER is on HDD, or use a direct boolean field and a matching existing conditional.
- Justification: The actual control-flow error is language-defined; a small explicit conditional expresses the existing intended behavior. Hardware consequences of the extra HDD chdir are INFERRED and must be checked against D-10/D-14/D-15.
- Benefit: Removes an unintended HDD working-directory operation; exact hardware impact unknown.
- Effort: S. Risk: Med (HDD launch contracts). Confidence: High READ for wrong sentinel, Med INFERRED for launch failure consequences.

### POPSLOADER-037 / Reuse UTF-8-safe clipping instead of cutting byte sequences / Category 6, 2

- Location(s): `POPSLoader/bin/POPSLDR/ui.lua:149-170,1000-1021,3366-3369,5650-5674,2723-2782,3628-3636,4407-4415,7387-7393`.
- Problem: Selected-game and selected-settings marquees, path truncation and keyboard cursor/delete use byte offsets and can split a multibyte character. This conflicts with the newly shipped French/German/etc labels and UTF-8 filenames; the file already contains Utf8DropLast for safe clipping.
- Fix: For the smallest reduction, replace the marquee clipping path with the existing UTF-8-safe FitEllipsis and remove the byte-wise marquee implementation; if animation must remain, advance and clip only at UTF-8 boundaries using Lua's existing utf8 library. Apply the same boundary rule to edited paths, or explicitly constrain the editor to ASCII-only existing values if that is the real supported contract.
- Justification: A concrete invalid-UTF8 output can be produced by the existing marquee from a two-byte accented character. Existing safe clipping avoids another helper. Keyboard handling scope should not be widened without checking native path encoding.
- Benefit: Correct glyph/path handling; deleting marquee removes about 20-30 lines INFERRED and repeated width scans. Native filename encoding compatibility needs checking.
- Effort: M. Risk: Med. Confidence: High READ for byte splitting; native rendering/path consequences INFERRED.

### POPSLOADER-041 / Release partially opened Bluetooth endpoints on connect failure / Category 6, 4

- Location(s): `POPSLoader/modules/ds34bt/iop/ds34bt.c:101-146`, `:157-177`; duplicate unbuilt fork `POPSLoader/modules/pademu/ds34bt.c:100-141`. `Launchstation/iop/ds34bt/iop/ds34bt.c:107-146`, `:161-177`; `RiptOPL/modules/ds34bt/iop/ds34bt.c:107-146`, `:161-177`; `RiptOPL/modules/pademu/ds34bt.c:107-146`, `:157-174`.
- Problem: bt_connect can successfully open some interrupt/bulk endpoints and then return -1 because another endpoint is unavailable. Those handles are not closed, and bt_disconnect's authorized-state guard cannot clean this partial path because authorization is only set after the failure branch.
- Fix: Close each successfully opened data endpoint before this connect-failure return and reset its handle. Keep the current success path; if POPSLOADER-022 deletes the unused fork, only fix the live driver.
- Justification: A few local cleanup statements fix a specific IOP handle leak on an existing error branch; no resource wrapper or retry is needed.
- Benefit: Prevents retained IOP USB endpoint resources after rejected/failed adapter connections; resource bytes and failure frequency not measured.
- Effort: S. Risk: Low. Confidence: High (READ for missing close/control flow; exact IOP resource cost INFERRED).

### POPSLOADER-018 / Bound the DS3 battery-table index / Category 6

- Location(s): `POPSLoader/modules/ds34usb/iop/ds34usb.c:45-47`, `:298-301`; `POPSLoader/modules/ds34bt/iop/ds34bt.c:261-263`, `:1332-1335`; duplicate unbuilt forks `POPSLoader/modules/pademu/ds34usb.c:44-46`, `:295-305`, `POPSLoader/modules/pademu/ds34bt.c:256-258`, `:1267-1276`. `Launchstation/iop/ds34usb/iop/ds34usb.c:45-47`, `:298-301`; `Launchstation/iop/ds34bt/iop/ds34bt.c:261-263`, `:1332-1335`; `RiptOPL/modules/ds34usb/iop/ds34usb.c:337-340`; `RiptOPL/modules/ds34bt/iop/ds34bt.c:1332-1335`. RiptOPL pademu USB already bounds this index at `RiptOPL/modules/pademu/ds34usb.c:332-333` and is not an affected location.
- Problem: Both live drivers use an incoming byte directly as an index into a six-byte power_level array. Excluding only the charging sentinel does not bound other unexpected values; a malformed controller report with the PS button set reads outside the table.
- Fix: Index the table only when Power is below its existing element count; otherwise retain the existing normal LED pattern.
- Justification: A local bound on the actual untrusted report field prevents a proven out-of-range read, reusing the existing else behavior.
- Benefit: Removes the listed shared IOP out-of-range read paths; a comparison per report, no RAM/size saving claimed.
- Effort: S. Risk: Low. Confidence: High (READ for out-of-range access; malformed-report trigger frequency INFERRED).

### POPSLOADER-032 / Delete unused launch bookkeeping and disabled branches / Category 1, 3, 5

- Location(s): `POPSLoader/bin/POPSLDR/system.lua:10155-10166,10273-10296,10364-10377,10843-10847,10859-10861,10969-11033,11127-11136,11171-11178`.
- Problem: The bootparam-prefixed-path chain performs file existence probes and builds fields stored only in the context table; LaunchEngine and BlockLaunchFailure never read those fields. GetBootOccupiedPfsSlot has no calls, and use_minimal_hdd_popstarter_exec is fixed false but still guards dead branches and redundant conditions.
- Fix: Delete the unused context fields and their construction/probes/helpers, the uncalled slot helper, and constant-false branches; leave the actual argv0_selector and partition/keep-mask logic intact. In particular preserve the invalid-HDD-entry guard at10982-10999 and game-name derivation at11010-11023, which sit among obsolete assignments.
- Benefit: Around100-150 lines removed INFERRED, plus up to two existence probes per non-HDD launch. Native ELF bytes/ms not measured.
- Effort: M. Risk: Med (launch code). Confidence: High READ; verify exact final deletion span against field references.

### POPSLOADER-035 / Delete the unreachable alternate settings commit implementation / Category 1, 2, 3

- Location(s): `POPSLoader/bin/POPSLDR/ui.lua:4508-4606,4471-4477`; `POPSLoader/bin/POPSLDR/system.lua:6567-6755,7807-7810,11762-11784`.
- Problem: queue_exit carries a second settings write/apply implementation for when CommitSettingsChanges is absent. The runtime embeds system.lua and ui.lua together; system.lua always defines CommitSettingsChanges and NextBdmaApplyToken before entering the UI loop, so this fallback cannot execute in the shipped application.
- Fix: Delete the missing-function alternate implementation and the token-generation fallback, and call the existing functions directly.
- Benefit: About65 lines removed INFERRED; no runtime speed claim for the unreachable branch.
- Effort: S. Risk: Med. Confidence: High READ for shipped embedded load order; external test mocks may need adjusting.

### POPSLOADER-033 / Remove unreachable placeholder UI and dead input diagnostics / Category 1, 3, 5

- Location(s): `POPSLoader/bin/POPSLDR/ui.lua:3254-3288,1269-1271,6492-6496,6568,6595-6607,6670-6693,1946-1950`.
- Problem: GameList.Play creates titles={} and placeholders={} each frame, so both corresponding branches are unreachable. The input debug block computes local values without emitting/using them; NavEventCount is only incremented/reset, released is unused, emit_action only forwards to emit, and WelcomeDraw shadows an identical Clamp01 helper.
- Fix: Delete the empty maps and branches, dead debug block/state/counter, unused released local and forwarding emit_action, and duplicate Clamp01; call the already existing functions directly.
- Benefit: Roughly70-90 lines removed INFERRED; two empty table allocations per list frame removed (100-120 allocations/second at50/60Hz INFERRED), fewer per-frame closures/counter writes. Actual ELF bytes unknown.
- Effort: S. Risk: Low. Confidence: High READ.

### POPSLOADER-039 / Delete the uncalled whole-heap memory diagnostic / Category 1, 4

- Location(s): `POPSLoader/src/system.cpp:183-254`; `POPSLoader/src/luasystem.cpp:887-895`, `:2532`; `POPSLoader/src/include/system.h:21`; `POPSLoader/src/include/luaplayer.h:47`; `POPSLoader/src/luaplayer.cpp:145-169`.
- Problem: getFreeMemory is registered in Lua but never used by the embedded application; its only native consumer is the binding. Its implementation repeatedly mallocs the largest blocks until the whole free heap is occupied just to count it, and filesystem Lua script loading is disabled.
- Fix: Delete the unused binding/registration, GetFreeSize/AllocateLargestFreeBlock, and their declarations.
- Benefit: Approximately 84 source/declaration lines plus an unused heap-exhausting diagnostic removed; final linked/packed bytes unmeasured. No running speed improvement is claimed for an uncalled API.
- Effort: S. Risk: Low. Confidence: High (READ implementation, all embedded executable Lua and no call references).

### POPSLOADER-021 / Stop tracking the regenerated child-loader byte array / Category 7

- Location(s): `POPSLoader/src/elf_loader/loader.c:1`; `POPSLoader/src/elf_loader/Makefile:30-35`; `POPSLoader/Makefile:354-359`.
- Problem: The repository tracks an 855,821-byte, 8,740-line generated C byte array, although the child-loader build unconditionally regenerates it with bin2c. This duplicates its real loader implementation and creates large irrelevant diffs.
- Fix: Delete the tracked generated array and ignore that build output; retain its existing generation rule and parity check against the freshly built loader.
- Justification: One ignore entry removes 855,821 tracked bytes; no runtime behavior or build-generation layer is added.
- Benefit: 855,821 tracked bytes and 8,740 generated lines removed (inventory measurement); no ELF/RAM reduction claimed.
- Effort: S. Risk: Low. Confidence: High (READ for generation rule and array identity; opaque array contents were not manually decoded).

### POPSLOADER-022 / Delete unused alternate controller/ATA source trees and obsolete MX4SIO blobs / Category 1, 7

- Location(s): `POPSLoader/Makefile:54-57`, `:82`, `:94-106`, `:308-324`, `:332-351`; `POPSLoader/modules/pademu/Makefile:1-25`; `POPSLoader/iop/ata_bd_fast/Makefile:1-40`; `POPSLoader/iop/embed/PS2SDK_MX4SIO/mx4sio_bd.irx`; `POPSLoader/iop/embed/mx4sio_bd_mini.irx`.
- Problem: The build uses the direct ds34usb/ds34bt libraries, not the second pademu controller fork; the Makefile expressly says ata_bd_fast is unused and selects the pinned ATA blob. Two old MX4SIO blobs are also unreferenced; the Makefile documents that the former pinned copy is incompatible with the current BDM set.
- Fix: Delete modules/pademu, iop/ata_bd_fast and its uninvoked rule, and the two unreferenced obsolete MX4SIO blobs. Keep the currently selected live drivers and pinned ATA binary.
- Benefit: 202,293 tracked bytes across twenty files removed (inventory measurement), including roughly 5,233 C/header lines. No runtime or ELF reduction claimed because these inputs are already unbuilt.
- Effort: S. Risk: Low. Confidence: High (READ build graph, explicit unused comments and repository reference search; alternative implementations not fully audited).

### POPSLOADER-025 / Publish rolling and experimental builds from the already passing CI artifact / Category 2, 7

- Location(s): `POPSLoader/.github/workflows/compilation.yml:3-13`, `:59-253`; `POPSLoader/.github/workflows/rolling-release.yml:3-13`, `:28-210`; `POPSLoader/.github/workflows/experimental-release.yml:12-16`, `:31-206`; `POPSLoader/.github/workflows/official-release.yml:6-10`, `:22-36`.
- Problem: CI builds every pushed branch/PR, while rolling separately rebuilds dev/PR commits and experimental separately rebuilds experimental commits with largely the same gates. The official publisher already downloads the successful CI artifact for the exact head SHA.
- Fix: Apply the existing exact-CI-artifact publication pattern to the two other channels, retaining their branch/event/channel conditions and channel-specific bundle naming. Remove their second compiler/harness/blob-parity runs.
- Justification: This reuses an existing workflow design to remove duplicate builds; it adds no reusable-workflow framework or wrapper.
- Benefit: One redundant PS2 container build plus host harness per overlapping event removed; roughly 150–180 build/check lines per release workflow are candidates (INFERRED), runner minutes unmeasured. This includes POPSLOADER-013's redundant Alpine step, so do not count that saving twice.
- Effort: M. Risk: Med. Confidence: High (READ triggers and existing artifact flow; final net line saving INFERRED).

### POPSLOADER-026 / Remove the redundant all-in-one release bundle / Category 2, 7

- Location(s): `POPSLoader/.github/workflows/rolling-release.yml:211-299`; `POPSLoader/.github/workflows/experimental-release.yml:207-298`; `POPSLoader/tools/build_release_kit.sh:15-28`, `:77-87`.
- Problem: The legacy release bundle copies every tracked source/research asset, puts multiple POPSTARTER copies/profile folders at additional roots, then embeds another complete install ZIP and PSU. The same workflow already publishes the installable ZIP/PSU separately, while GitHub provides source archives.
- Fix: Delete the legacy all-in-one source bundle and its nested install copies; publish the existing installable ZIP/PSU and ELF once per channel. Keep the functional runtime payloads in that install kit.
- Benefit: Removes about 90 bundle-construction lines per channel plus redundant archive contents. The tracked .research tree alone copied into each source bundle is 21,197,583 uncompressed bytes (inventory measurement); actual compressed download/write savings were not measured. No feature-removal size comparison is intended.
- Effort: S. Risk: Med (download layout). Confidence: High (READ packaging flow; compressed-size benefit INFERRED).

### POPSLOADER-013 / Remove the second host-harness execution in each build container / Category 2, 7

- Location(s): `POPSLoader/.github/workflows/compilation.yml:21-57`, `:59-60`, `:154-169`; `POPSLoader/.github/workflows/rolling-release.yml:28-59`, `:142-160`; `POPSLoader/.github/workflows/experimental-release.yml:31-55`, `:138-156`.
- Problem: Every container build already depends on its Ubuntu host-harness job, but then repeats the same Lua execution and multiple pip-install fallbacks in Alpine. The comments explicitly state that the Alpine attempt commonly skips because a suitable wheel is unavailable.
- Fix: Delete the repeated in-container host-harness step in all three workflows; retain the existing required Ubuntu job and native compilation.
- Benefit: Approximately 50 workflow lines plus up to three redundant dependency-install attempts per build removed; runner-time saving is unmeasured.
- Effort: S. Risk: Low. Confidence: High (READ).

### POPSLOADER-023 / Make the release-kit checkout repeatable / Category 6, 7

- Location(s): `POPSLoader/tools/build_release_kit.sh:10-13`, `:23-34`, `:80-84`.
- Problem: The script always clones into /tmp/riptopl-kit and never removes it. A second invocation in the same environment fails at git clone because the destination already exists, before packaging starts.
- Fix: Use one mktemp directory for this invocation, substitute that path at the existing consumers, and remove it with a trap. Do not add a cache, backup, or retry.
- Justification: One owned temporary directory and cleanup fix a deterministic repeat-run failure and avoid deleting another invocation's checkout; this is the smallest isolated fix.
- Benefit: Repeatable local packaging and no retained checkout in /tmp; a few lines added, bytes/time not measured.
- Effort: S. Risk: Low. Confidence: High (READ; second-run consequence follows git clone destination rules).

### POPSLOADER-009 / Kerning is permanently disabled by the previous-glyph update / Category 6

- Location(s): `POPSLoader/src/fntsys.cpp:640-668`, `:777-804`, `:917-940`.
- Problem: `previous` starts at zero and is assigned only inside `if (use_kerning && previous)`. The first character therefore never sets it, so no later character can enter the kerning block; measured widths and rendered text omit all kerning.
- Fix: When kerning is enabled, obtain the current glyph index, apply the pair adjustment only if a previous index exists, then assign the current index to `previous` unconditionally.
- Justification: Moving the existing state update fixes the concrete first-glyph state error without a new layout layer.
- Benefit: Correct text spacing and width calculations; no claimed byte/time saving.
- Effort: S. Risk: Low. Confidence: High (READ).

### POPSLOADER-008 / Delete the always-empty image fallback table / Category 1, 3

- Location(s): `POPSLoader/bin/POPSLDR/images.lua:46`, `:63-70`.
- Problem: `IMG_FALLBACKS` is initialized empty, is local, and is never populated. Every failed image lookup executes an impossible fallback branch.
- Fix: Delete the table and its fallback lookup branch; keep the existing failure memoization and normal placeholder behavior.
- Benefit: Eight source lines and one table allocation removed; bytes and timing not measured.
- Effort: S. Risk: Low. Confidence: High (READ).

### POPSLOADER-024 / Delete the spent mistaken-release retraction workflow / Category 1, 7

- Location(s): `POPSLoader/.github/workflows/retract-mislabeled-ember-beta.yml:1-40`.
- Problem: This workflow exists only to retract one explicitly identified mistaken prerelease, then runs again if its own file changes. The read-only remote-ref inventory contains neither its target tag 1.3.0-ember-beta.1 nor the v-prefixed variant.
- Fix: Delete the one-off workflow. Do not delete any other tag, branch, release, or upstream Ember artifact.
- Benefit: Forty workflow lines removed and one obsolete write-capable automation deleted; no runtime benefit claimed.
- Effort: S. Risk: Low. Confidence: High (READ workflow and remote-ref absence; release-object absence was not independently queried).

### POPSLOADER-010 / Delete obsolete dummy-file and removed-API declarations / Category 1, 7

- Location(s): `POPSLoader/Makefile:389-418`; `POPSLoader/src/include/system.h:19-20`; `POPSLoader/src/system.cpp:169-181`; `POPSLoader/src/luaScreen.cpp:22-34`, `:158`.
- Problem: The Makefile still creates 25 empty fake VCDs and supplies a broad cleanup target, while the header advertises `load_elf` even though the implementation was deleted. A commented Vita framebuffer reader is unrelated to this PS2 application.
- Fix: Delete the dummy targets, removed API declaration/macro, and commented framebuffer code. Existing host fixtures already cover list logic without polluting the app directory.
- Benefit: About 47 source/build lines removed; no runtime savings claimed for comments or unused targets.
- Effort: S. Risk: Low. Confidence: High (READ).

### POPSLOADER-040 / Remove superseded current-state claims from the canonical status page / Category 7

- Location(s): `POPSLoader/STATE.md:5-8`, `:46-56`, `:253`, `:268-269`; `POPSLoader/bin/POPSLDR/system.lua:2559-2560`; `POPSLoader/src/main.cpp:673-682`.
- Problem: The canonical page still says Slovak is absent from the picker while the shipped order includes SK. Its current-state section and later resolved list also retain contradictory ATA-worker and MMCE/MX4SIO exclusion claims that the same page supersedes elsewhere and the current code does not implement.
- Fix: Delete the superseded present-tense claims and repeated experiment narrative from STATE; keep one current behavior description and the existing detailed QA/decision history. Remove the obsolete Slovak-pending sentence.
- Benefit: Fewer contradictory instructions for future edits and less repeated prose; no executable/RAM benefit claimed. Exact prose deletion depends on preserving the genuinely current statements.
- Effort: S. Risk: Low. Confidence: High (READ; current code and internal contradictions cited).


## Cross-repository findings (listed once in the summary)

See `Codex-SUMMARY.md`: **CROSS-001** includes backup/copy-delete replacement at `bin/POPSLDR/system.lua:5229-5290` and `src/luasystem.cpp:824-876`; **CROSS-003** includes unchecked destination close before source removal at `src/luasystem.cpp:848-853,872-874`; **CROSS-004** is the shared controller alarm-cancellation argument mismatch, including `modules/ds34usb/iop/ds34usb.c:464-480` and its unused `modules/pademu/ds34usb.c:495-511` copy. These findings are intentionally not repeated here. Shared controller defects found in the other repos are canonicalized once under POPSLOADER-017, -018, -041 and -042 above, with every read location listed; other repo reports should point here.

## Validation and limits

- Existing `tools/host_harness.py`: **62/62 passed**, using `lupa` installed only under `/tmp/codex-audit-work/python-deps`; mock I/O does not establish PS2 hardware behavior.
- Existing `tools/test_disc_layout.py`: **30 cases passed**.
- Existing `tools/test_udpfs_config_runtime.py`: **26 real-Lua IPv4 scenarios plus configuration/staging scenarios passed**.
- Existing `tools/test_udpfs_integration.py`: source wiring/blob-integrity checks passed; no release ZIP supplied.
- Existing `tools/pad_harness.py`: **13 cases passed** with the host compiler. Existing `tools/test_translation_handoff.py`: **7 passed**.
- Existing `tools/docs_verify.py`: no mechanical doc/source mismatches. Existing `tools/sync_native_wiki.py --self-test`: passed link rewriting, idempotence, external page preservation and overwrite guard. These limited checks do not establish prose freshness.
- Existing `tools/png_decoder_harness.py`: blocked before compilation because pkg-config cannot find libpng; no decoder test result is claimed.
- Minimal reproductions against unmodified production Lua/functions demonstrated the nil-global PFS recovery, dropped Retro GEM edit, ignored BDMA-marker failure, ineffective HDD working-directory sentinel and invalid UTF-8 marquee output. Extracted `rg_read_file` under ASan demonstrated negative-size memcpy for a malformed VCD, with only sector I/O mocked.
- No PS2SDK build, ELF-size measurement, physical-console test, workflow run, publication, or source edit was performed. No hardware timing or RAM saving is claimed as measured.

## Exact coverage and remaining work

Inventory: **609 tracked files; 129 source/header/build/workflow/script files, 63,534 physical lines**, including the generated 8,740-line child-loader array and the two assembly files. **95 required files fully read; 8 partially read; 26 not fully read at all.** Every path has a durable per-file status in the accompanying audit coverage manifest. Search results and passing tests were not counted as full reads.

Completed: all live EE native implementation/headers; child-loader implementation/headers/build/linker input; all ten workflows; active BDM-query/controller module build/import/export/assembly files; root Makefile; boot/images Lua; and the tools listed as fully read in the manifest. The two identical controller assembly files were compared byte-for-byte and one complete body was read. Key-initializer bytes were treated as opaque and excluded.

The embedded `ui.lua:1-7599` executable logic and strings were read in full. The same is true of `system.lua:1-2580,4844-11784`; translation-table data `2581-4843` remains partial. Token-preserving comment-stripped numbered views were used, with original finding regions re-read; not every comment was read. `AGENTS.md` was read; canonical `STATE.md` current contracts were read but its long middle prose was not certified complete after output truncation.

Files not fully read and why:

- `.research/_srcassets/app.js` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/_srcassets/style.css` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/audit_site.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/build_site.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/firstparty/start-here.html` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/audit_bitbucket_download_snapshots.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/audit_hosted_patch_members.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/audit_legacy_archive_payloads.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/audit_legacy_pages.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/audit_legacy_tool_overlap.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/audit_network_driver_crc_overlap.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/audit_original_automated_parity.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/audit_original_download_links.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/audit_original_git_history.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/audit_original_wiki_zip.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/audit_original_wip06_2017.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/audit_published_provenance.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/compare_recovered_archive_candidates.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/guard_site_deploy.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/inspect_network_modules_header.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `.research/tools/verify_network_driver_payloads.py` — research-site implementation/tooling; runtime review prioritized, all eight audit categories still open here.
- `iop/ata_bd_fast/ps2atad.c` — unused alternative driver implementation/header; build graph read, implementation audit unfinished.
- `modules/pademu/ds34usb.h` — unused alternative driver implementation/header; build graph read, implementation audit unfinished.
- `modules/pademu/pademu.c` — unused alternative driver implementation/header; build graph read, implementation audit unfinished.
- `src/elf_loader/loader.c` — generated byte array; generator/build rules read, payload not manually decoded.
- `tools/test_udpfs_config_runtime.py` — 319-line test implementation executed successfully but not read end-to-end.

Partial files/ranges beyond the Lua coverage above:

- `modules/ds34bt/iop/ds34bt.c` — read 1-272, 277-1719; key-initializer bytes273-276 deliberately withheld; all non-key logic read.
- `modules/ds34usb/iop/ds34usb.c` — read 1-56, 61-806; opaque key-initializer bytes57-60 excluded from semantic audit; all non-key logic read.
- `modules/pademu/ds34bt.c` — read 95-145, 256-258, 908-952, 1058-1103, 1255-1284; rest of unused alternative implementation not read; key-initializer bytes excluded.
- `modules/pademu/ds34usb.c` — read 44-46, 106-153, 295-305, 490-516; rest of unused alternative implementation not read.
- `modules/pademu/ds34bt.h` — read 63-65; other header declarations not read.
- `tools/host_harness.py` — read 1-242; 243-2759 not read; running the harness is not counted as reading it.
- `STATE.md` — read 1-60, 186-295; 61-185 not certified as fully read; some portions were read.

Packaged ELF/IRX/archives/images/font/audio payloads were inventoried, not manually decoded. Most historical Markdown, translation handoff/data files, research JSON/HTML payloads and noncode configuration metadata were not comprehensively read or checked for staleness. Exact non-fully-read tracked paths are retained in the coverage manifest; the report makes no dead-asset or stale-document claim about those unreviewed files. No licence review was performed, as requested.

Unfinished: categories **1–6 and 8** across the explicitly unread code/catalog/test areas; category **7** across historical docs/research assets/config metadata, plus exact binary-size/IOP-RAM accounting. No additional live native or executable-Lua body gap remains beyond the opaque initializer/comment exclusions above. Branch/tag inventory belongs to the summary reviewer and is listing-only.

## Durable continuation manifest

[Exact coverage and remaining paths](coverage/Codex-POPSLoader-coverage.json): 96 whole-file reads; 10 paths with recorded partial evidence; 513 paths require further review or explicit binary/document exclusion. This is a tracked-file count, not a claim that binary assets can be source-audited.
