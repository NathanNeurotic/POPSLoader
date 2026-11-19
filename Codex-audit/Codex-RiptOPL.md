# Codex — RiptOPL audit

**-unfinished- checkpoint:** This is the earlier baseline report, preserved with its validation results. See [the resume index](Codex-RESUME-unfinished.md) and linked continuation findings for the later review. Earlier read-only statements describe source handling before the user authorized this report-only draft PR.

Snapshot: `NathanNeurotic/RiptOPL`, default branch `rebuild/main`, commit `679d3d8626dd09a913e7081101418e337234fe7c`.

Unless explicitly described as measured or as a source-declared capacity/count, proposed reductions are INFERRED until implemented. READ denotes source evidence, not hardware verification.

**PARTIAL AUDIT — completed review pass; remaining scope is listed below.** This report does not claim that all 2,380 tracked files have been read. Findings below are source-backed; execution evidence is identified explicitly. Practical benefit orders data preservation and crashes before responsiveness, retained RAM, and source cleanup. Bytes or milliseconds not measured on PS2 are not presented as measurements. No repository source, build file, workflow, Git ref, or GitHub object was changed.

## Findings

### RIPTOPL-001 / Stop treating compressed image payloads as trusted LZ4 / Category 6

- **Location(s):** `RiptOPL/modules/isofs/zso.c:94-121`; `RiptOPL/modules/isofs/lz4.c:407-443,447-472,500-505`; `RiptOPL/modules/isofs/lz4.h:117-126`. The frontend includes the same reader at `RiptOPL/src/platform/zso.c:9`.
- **Problem:** The sector reader copies an image-controlled compressed block into scratch memory, calls `LZ4_decompress_fast`, and ignores its return value. The shipped GCC implementation permits a 64-KiB prefix outside the output buffer and has no input bound; malformed backreferences can read outside the allocation, and decoding errors are still reported as successfully read sectors.
- **Fix:** Replace the fast-only instantiation with the already present generic decoder's input-bounded, no-prefix mode, passing the actual compressed block length and the 2,048-byte output limit. Return failure unless exactly one sector was decoded; reject short raw blocks rather than returning partially uninitialized sectors.
- **Justification:** This replaces an unsafe decoder call with a bounded variant of the same existing implementation. No new compression library or wrapper is needed; image corruption can currently crash the loader or game.
- **Benefit:** **High reliability benefit:** an audit-only host harness invoking the actual shipped decoder with a malformed backreference produced an AddressSanitizer invalid read/SEGV at `lz4.c:472`. ELF-size and speed differences are unmeasured; the unsafe instantiation can be removed if no other caller remains.
- **Effort:** M. **Risk:** Med. **Confidence:** High (**READ**, host-reproduced; PS2 manifestation **INFERRED**).

### RIPTOPL-002 / Reject unterminated names in the TAR sidecar cache / Category 6

- **Location(s):** `RiptOPL/src/platform/tar.cpp:115-173,485-495,517-524,531-550,562-567`; name layout: `RiptOPL/include/tar.h:31-63`.
- **Problem:** Cache loading validates entry count and `rawSize`, but accepts filename fields containing no NUL. All four lookup loops then use unbounded string operations on those cached bytes.
- **Fix:** In the existing per-entry cache-validation loop, reject entries without a NUL inside their filename field and fall through to the existing archive parser.
- **Justification:** One bounded `memchr` beside the existing raw-size check fixes a reproduced heap overread; it needs no new error path or fallback.
- **Benefit:** **High reliability benefit:** a single 64-byte cached ART entry with 48 nonzero name bytes produced an ASan heap-buffer-overflow in `tarFindExact` at `tar.cpp:547` (read size 49). No PS2 timing or ELF measurement.
- **Effort:** S. **Risk:** Low. **Confidence:** High (**READ**, host-reproduced).

### RIPTOPL-017 / Reserve space for both pending whitespace and its next character / Category 6

- **Location(s):** `RiptOPL/src/core/cheatconfig.cpp:18-39,53-59,62-85`; destination capacity `RiptOPL/include/cheatman.h:43`, saved value buffer `RiptOPL/src/core/cheatconfig.cpp:65`.
- **Problem:** The normalization loop reserves one output byte, but a pending space makes it emit two bytes before the terminator. A saved CFG selection containing 127 letters, one space and another letter fits the 256-byte saved buffer, but writes its final NUL one byte beyond the 129-byte normalized-name buffer.
- **Fix:** Account for the pending separator when checking remaining capacity, or stop before emitting it if the following character and terminator cannot both fit. Keep the existing normalizer.
- **Justification:** One local capacity condition fixes a reproduced stack write overflow. No new parser, wrapper or general validation system is needed.
- **Benefit:** **High reliability benefit:** the exact extracted function produced both UBSan insufficient-space and ASan stack-buffer-overflow reports for that input. PS2 corruption impact was not measured.
- **Effort:** S. **Risk:** Low. **Confidence:** High (**READ**, host-reproduced exact function).

### RIPTOPL-004 / Unvalidated saved IP octets overflow the launch configuration / Category 6

- **Location(s):** `RiptOPL/src/app/settingsio.cpp:1949-1956`; legacy equivalent: `RiptOPL/src/core/config.cpp:731-765`; sink: `RiptOPL/src/platform/system.cpp:1577-1582`; fixed destination: `RiptOPL/ee_core/include/coreconfig.h:43-45`.
- **Problem:** The settings readers accept arbitrary signed integers and ignore partial scans. Network-block launch then formats four such integers with unbounded `sprintf` into a 16-byte address field; four nine-digit octets already exceed it, corrupting adjacent core configuration.
- **Fix:** Parse each address into temporary octets and accept it only when all four are in 0–255; retain the existing address on invalid input. Use bounded formatting at the cited launch sink. The same parsing already occurs in multiple locations, so one small parser is appropriate only if it replaces those scans overall.
- **Justification:** The checks enforce the actual fixed-size IPv4 contract and stop a concrete write overflow from a user-editable configuration. No new option or network fallback is required.
- **Benefit:** **High reliability benefit** for malformed settings; source-proven overflow condition, no hardware exploit or timing claim.
- **Effort:** S. **Risk:** Low. **Confidence:** High (**READ**; malformed-file trigger **INFERRED**).

### RIPTOPL-005 / Preserve string types when rewriting libconfig files / Category 6

- **Location(s):** `RiptOPL/src/core/config.cpp:856-899,982-1030,1067-1078`.
- **Problem:** Parsing discards whether a value was quoted, and writing guesses type from the value's characters. Saving an app with `title = "1942";` changes it to `title = 1942;`; the same problem affects numeric-looking string arguments or card names. A libconfig consumer asking for a string receives an integer instead.
- **Fix:** Preserve the parsed string/scalar distinction and use it when writing, removing the content-based `cfgValueIsBareScalar` guess. Existing setters should state the type they already know (`setStr` versus `setInt`).
- **Justification:** A small stored type distinction fixes a reproduced cross-loader data-format bug and replaces the 19-line lexical guess. It is not a new parser framework.
- **Benefit:** **Medium correctness benefit:** an audit-only harness built from the actual `util.cpp`/`config.cpp` read the quoted title and wrote `title = 1942;`. Net ELF/RAM delta is unmeasured; the fix should remove the heuristic.
- **Effort:** M. **Risk:** Med. **Confidence:** High (**READ**, host-reproduced).

### RIPTOPL-019 / Stop reading past icon assets to manufacture OSD padding / Category 6

- **Location(s):** `RiptOPL/src/core/OSDHistory.cpp:25-31,44-60`; unchanged asset embedding `RiptOPL/tools/assets.py:64-70,122-125,184-187`; `RiptOPL/misc/icon_A.sys`, `RiptOPL/misc/icon_J.sys`, `RiptOPL/misc/icon_C.sys` (binary assets; byte lengths measured, no source lines).
- **Problem:** System-folder creation intentionally writes 1,776 bytes from a selected icon asset. All three tracked regional assets contain only 964 bytes and are passed unchanged to bin2c; the final 812 bytes come from memory beyond the asset instead of defined padding.
- **Fix:** Write the actual icon bytes and explicit zero padding up to the OSD-required 1,776-byte length. Do not reduce the required file length or preserve the out-of-bounds read.
- **Justification:** Defined padding fixes a concrete asset-boundary overread and makes generated files deterministic. It uses no new logging or file-replacement machinery; the required compatibility length remains the same.
- **Benefit:** **Medium reliability/privacy benefit:** **812 out-of-asset bytes per new system icon** are no longer copied to a memory card. The bytes' contents were deliberately not examined, and no actual secret exposure is asserted. The exact emitted C array layout has not been measured with the unavailable PS2 bin2c; the source asset boundary and unchanged embedding are **READ**.
- **Effort:** S. **Risk:** Low. **Confidence:** High (**READ**); exact neighboring-data manifestation **INFERRED**.

### RIPTOPL-006 / File Manager performs slow device work on the dialog thread / Category 5

- **Location(s):** `RiptOPL/src/ui/guifilemgr.cpp:174-222,241-277,349-357,428-480,487-511,548-562,631-668`; full-tree pre-scan: `RiptOPL/src/core/filemgr.cpp:434-447`.
- **Problem:** Drive/folder enumeration, recursive copy/move/delete, and PSU conversion execute synchronously from the dialog input loop. Copy progress only redraws when the integer percentage changes; enumeration and the complete size pre-scan provide no controller polling, and a long individual I/O call prevents the dialog returning.
- **Fix:** Run these operations on the existing I/O worker using the already used deferred-I/O wait screen, and publish progress to that screen. Remove the blocking full-tree size pre-scan if showing bytes copied is sufficient; do not add another worker system.
- **Justification:** Reusing the existing worker removes long storage work from the UI path and addresses the user's explicit responsiveness requirement. Deleting the pre-scan also removes one whole directory traversal.
- **Benefit:** **High responsiveness benefit, unmeasured on PS2**; one complete pre-copy tree walk can be removed. Existing redraw calls do not make input responsive.
- **Effort:** M. **Risk:** Med. **Confidence:** High (**READ**; elapsed stall lengths **INFERRED**).

### RIPTOPL-018 / Allocate optional audio and export buffers only while they are used / Category 4

- **Location(s):** `RiptOPL/src/core/bgm.cpp:29-30,72,720-733,759-816,860-878`; default BGM off `RiptOPL/src/core/settings.cpp:170-175`; diagnostic export scratch `RiptOPL/src/core/diagsave.cpp:17-32,40-44`.
- **Problem:** Every normal build reserves a 192 × 4,096-byte PCM ring for background music even when music is off or no usable music file exists. Exporting DIAG.TXT also reserves a separate static 16-KiB copy buffer for the entire session even when no export occurs.
- **Fix:** Allocate the ring once before playback threads start and free it only in the existing teardown after both threads have stopped. Allocate the diagnostic snapshot only for the save and free it on that function's existing return paths. Keep the present ring capacity; there is no evidence here to reduce buffering while music is playing.
- **Justification:** A small allocation/free pair per feature removes large always-resident optional working memory. This is a concrete RAM win on the 32-MB EE, with no new configuration, abstraction or reduced functionality; failed allocation can use existing failed-start/save results.
- **Benefit:** **High RAM benefit:** **786,432 bytes** of permanently reserved PCM storage plus **16,384 bytes** of diagnostic scratch become reclaimable while those features are unused; these are exact declared array capacities, not an ELF-size measurement. During active playback the ring uses the same bytes as before, plus allocator metadata.
- **Effort:** M. **Risk:** Med (thread ownership must be preserved). **Confidence:** High (**READ**, exact capacity arithmetic).

### RIPTOPL-008 / Do not retain maximum-capacity scan arrays for tiny libraries / Category 4

- **Location(s):** HTTP arrays: `RiptOPL/src/sources/httpsupport.cpp:152-172,208-243,376-383`, limits `RiptOPL/include/httpsupport.h:14-19`, row layout `RiptOPL/include/supportbase.h:22-31`; art index: `RiptOPL/src/gfx/artindex.cpp:191-201,275-286`, capacities `RiptOPL/include/artindexint.h:29-44`.
- **Problem:** HTTP always retains space for 2,048 game rows plus 2,048 path rows, even for an empty or one-game catalog. Each art directory retains 4,096 filename hashes and 4,096 picture records plus at least 16 KiB of names, even if the directory contains very few pictures.
- **Fix:** Free empty results and trim successful arrays to the actual populated counts; keep the existing arrays and limits. Trim the names buffer to `namesUsed` too.
- **Justification:** A few local successful-scan reallocations remove unused retained capacity without changing the data model or adding a cache layer. Keep original pointers if a shrink fails.
- **Benefit:** **Medium RAM benefit:** HTTP's described 32-bit layouts total approximately 911,360 bytes at the fixed limit, versus approximately 445 bytes of row payload for one game (**INFERRED** from field sizes/alignment; no PS2 `sizeof` build). Three nearly empty art slots retain approximately 192 KiB of capacities before trimming (**INFERRED**, excluding allocator overhead). No claim that trimming lowers parse-time peak RAM.
- **Effort:** S. **Risk:** Low. **Confidence:** High (**READ**); numeric ABI totals **INFERRED**.

### RIPTOPL-007 / Use the submenu tail already maintained by the GUI / Category 5

- **Location(s):** `RiptOPL/src/ui/menusys.cpp:1677-1699`; caller and existing tail update: `RiptOPL/src/ui/gui.cpp:203-225`; whole-frame drain: `RiptOPL/src/ui/guiqueue.cpp:59-88`.
- **Problem:** Every appended game traverses the complete existing linked list to find its tail, even though the caller stores the tail in `menu->last` after every append. The GUI drains all append operations before returning to input, making construction quadratic on that thread.
- **Fix:** Append through the existing tail pointer and update it in the same operation; remove the traversal rather than introduce another index or container.
- **Justification:** The needed tail is already present. This removes repeated work and uses no additional RAM.
- **Benefit:** **Medium-to-high CPU benefit:** building 2,048 rows currently entails about 2.1 million link visits versus roughly 2,048 with a tail; these are arithmetic counts, **INFERRED**, not measured milliseconds. Several traversal lines disappear.
- **Effort:** S. **Risk:** Low. **Confidence:** High (**READ**).

### RIPTOPL-009 / Read the TAR cache directly into its final allocation / Category 4

- **Location(s):** `RiptOPL/src/platform/tar.cpp:121-173`.
- **Problem:** Cache loading allocates the entire sidecar, then a second entry array, then copies all entries. Both arrays coexist until the function returns, doubling the payload's contribution to peak RAM.
- **Fix:** Read the fixed header first, validate its count against the file length, allocate the final entry array once, and read entries straight into it; delete the whole-file buffer and `memcpy`.
- **Justification:** This changes an existing read to its final destination and removes an allocation and copy. The existing validation/error path can be retained.
- **Benefit:** **Medium peak-RAM benefit:** one sidecar-sized allocation and one complete payload copy removed; for 4,096 ART entries, approximately 256 KiB less peak payload RAM (**INFERRED example**, not a measured user archive).
- **Effort:** S. **Risk:** Low. **Confidence:** High (**READ**).

### RIPTOPL-010 / Build recursive file-operation listings once, without presentation sorting / Categories 4, 5

- **Location(s):** `RiptOPL/src/core/filemgr.cpp:198-246,249-274,389-411,478-496`.
- **Problem:** `fmChildren` allocates, rescans and sorts a directory at capacities 64, 256, 1,024, 4,096, 16,384 and 65,536 until all entries fit. The recursive size/copy/delete walks need enumeration, not sorted presentation; parent arrays remain allocated throughout child recursion.
- **Fix:** Enumerate each operation directory once with a growing array and skip sorting on these internal walks. If deleting the separate size pass in RIPTOPL-006 is accepted, remove that walk rather than optimize it too. Keep sorted `fmList` for the visible browser.
- **Justification:** It removes repeated storage round trips and sorting from destructive/background operations without adding an abstraction. The UI's existing ordering remains separate from internal traversal.
- **Benefit:** **Medium CPU/I/O benefit:** up to six opens/enumerations/sorts per directory become one. A maximum array holds about 9 MiB at a 144-byte entry stride (**INFERRED ABI**); do not claim all of that goes away unless the internal walk is changed to stream entries.
- **Effort:** M. **Risk:** Med. **Confidence:** High (**READ**); timing and ABI estimate **INFERRED**.

## RIPTOPL-901 / Remove overlapping CI build and test executions / Category 7

- **Location(s):** RiptOPL/.github/workflows/configurations.yml:23-42,91-100; RiptOPL/.github/workflows/rolling-release.yml:27-80,130-149; RiptOPL/.github/workflows/rolling-llvm.yml:30-66,111-138; RiptOPL/.github/workflows/ps2build.yml:18-21,68-74; RiptOPL/.github/workflows/flavours.yml:18-354,398-493; RiptOPL/tools/run_tests.sh:7-12.
- **Problem:** Of the 34 configuration builds scheduled on every integration push/PR, 31 have the exact same edition/configuration/compiler/device tuple already built by the GCC or LLVM rolling workflow. The generic GCC smoke build and compiler-independent host tests are also repeated across the smoke/compiler workflows and the manually enumerated host-test jobs.
- **Fix:** Delete the 31 duplicate configuration jobs, retaining only `ra/ingame_debug` for GCC and LLVM and `incebtion/extras_ds5` for LLVM. Keep one generic GCC smoke build and execute the existing host-test runner once; delete hand-enumerated invocations already covered by it while retaining genuinely additional integration probes.
- **Benefit:** **Measured:** 31 redundant configuration builds removed per integration push/PR, plus one redundant GCC smoke build if that duplicate is removed. At least one repeat of every compiler-independent host test disappears. Runner minutes and artifact bytes were not measured; no ELF/RAM change claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; matrix tuples enumerated with the existing YAML definitions, not historical CI-duration estimates).

## RIPTOPL-903 / Keep one source copy of bundled binary payloads / Categories 2, 7

- **Location(s):** RiptOPL/.github/scripts/package_release_app.py:24-37,225-260; RiptOPL/tools/package_edition.py:134-142,167-178; RiptOPL/.github/workflows/ember-watch.yml:130-135,154; RiptOPL/.github/workflows/flavours.yml:375-388; binary members under RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/ and their identical canonical copies under RiptOPL/ship/EMBER/, RiptOPL/ship/POPS/, and RiptOPL/modules/bdmassault/ (binary files have no source line numbers).
- **Problem:** The committed reference tree repeats bundled ELF/IRX/icon payloads already held elsewhere; the Ember watcher updates both trees and the driver job checks a third copy. Current packaging copies canonical `ship/POPS` and `ship/EMBER` trees and reads only a small set of unique example assets, so these repeated payloads are unnecessary packaging inputs.
- **Fix:** Remove the duplicate binary payload members from the reference tree, retaining the app/art templates and unique files the packager actually reads. Use the existing package command to produce a complete install kit, and remove the watcher/hash-job references to the deleted copies.
- **Benefit:** **Measured:** 27 repeated binary members, including one zero-byte placeholder, total **3,555,380 checkout bytes**. This is repository/source-archive reduction, not an ELF or installed-kit reduction; Git-history savings are not claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ for consumers; byte identity measured over tracked files). Exact duplicate-member inventory is available in the summary's duplication appendix.

### RIPTOPL-012 / Replace single-implementation host interfaces with ordinary functions / Category 3

- **Location(s):** `RiptOPL/include/host.h:26-131`; `RiptOPL/src/app/host.cpp:26-109,115-291`; test substitute `RiptOPL/tests/host/host_env.h:34-64`.
- **Problem:** Four virtual interfaces and four singleton implementation objects mostly forward calls to existing free functions. The executable has no runtime selection between host implementations; the tests already link a different implementation.
- **Fix:** Keep the useful dependency boundary as ordinary namespace function declarations and definitions, link test definitions in the host test, and delete the abstract/concrete class and accessor machinery. Keep actual launch-composition code; remove only virtual dispatch/forwarding scaffolding.
- **Justification:** Static functions preserve test substitution and module boundaries while deleting classes, vtables, singleton objects and indirect calls. No framework or new wrapper is proposed.
- **Benefit:** **Small-to-medium source/ELF simplification:** dozens of forwarding declarations/override/accessor lines and four vtables/objects removed; exact ELF and CPU gain unmeasured. The host boundary itself has a legitimate test purpose, so this is not a recommendation to reintroduce broad header coupling.
- **Effort:** M. **Risk:** Med. **Confidence:** High (**READ**); binary savings **INFERRED**.

### RIPTOPL-014 / Handle allocation failure in theme child constructors / Category 6

- **Location(s):** `RiptOPL/src/gfx/themeelems.cpp:209-227,274-279,699-724,762-775,808-825`; theme discovery `RiptOPL/src/gfx/themes.cpp:1025-1051`.
- **Problem:** Several theme allocations are immediately dereferenced or copied into without checking. The top-level theme allocation is checked, but that does not protect its child text, alias, image or discovery allocations; constrained EE memory can still turn theme selection/discovery into a null-pointer crash.
- **Fix:** Check these specific allocations and stop/skip the affected element through existing free/failed-theme paths. Avoid a new allocator, retry loop or fallback theme framework.
- **Justification:** These checks protect actual allocation results that are immediately dereferenced on a 32-MB target. Existing `freeImageTexture` and failed theme-load handling provide the cleanup structure.
- **Benefit:** **Medium reliability benefit** under allocation failure; no claimed speed or ELF reduction. This needs more call-chain verification before implementation, because some constructors currently return void to their callers.
- **Effort:** M. **Risk:** Med. **Confidence:** High for dereferences (**READ**); frequency and precise hardware crash path **INFERRED**.

### RIPTOPL-011 / Eliminate the second allocation per deferred GUI operation / Categories 3, 4, 5

- **Location(s):** `RiptOPL/include/gui.h:22-57`; `RiptOPL/include/guiqueue.h:23-30`; `RiptOPL/src/ui/gui.cpp:420-432`; `RiptOPL/src/ui/guiqueue.cpp:29-56,63-80`.
- **Problem:** A GUI update is heap-allocated, then wrapped in a separately allocated node containing only the update pointer and next link. It is freed immediately after application; no caller retains the wrapper.
- **Fix:** Put the next link in `gui_update_t`, queue that object directly, and delete `Node`, its allocation-failure branch, and its separate free.
- **Justification:** One pointer added to an existing owned object replaces an entire allocation containing two pointers plus allocator metadata. This is a net removal of code, allocation churn and memory, not an additional layer.
- **Benefit:** **Small-to-medium benefit:** one allocation/free pair removed per game row; on a 32-bit EE the raw pointer payload falls by four bytes per pending update, plus allocator overhead saved (**INFERRED ABI**). Approximately 20 lines can disappear; no measured milliseconds.
- **Effort:** S. **Risk:** Low. **Confidence:** High (**READ**).

### RIPTOPL-013 / Close the I/O print semaphore when its worker exits / Categories 4, 6

- **Location(s):** `RiptOPL/src/platform/ioman.cpp:163-176,187-219`; semaphore member `RiptOPL/include/ioqueue.h:75-81`.
- **Problem:** Every worker start creates three semaphores, but exit deletes only `procSema_` and `endSema_`. The code explicitly supports restarting after a refused autolaunch, so the previous print semaphore is lost and recreated on that path.
- **Fix:** Delete the print semaphore in the existing worker-exit cleanup, after logging users are quiesced under the same lifecycle contract as the other worker semaphores.
- **Justification:** One missing resource release fixes an actual create/delete imbalance. No additional resource manager is needed.
- **Benefit:** **Small reliability/RAM benefit:** one EE kernel semaphore reclaimed per worker restart; kernel allocation size and eventual exhaustion frequency unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** High (**READ**; restart frequency **INFERRED**).

### RIPTOPL-015 / Consolidate identical TAR lookups and remove genuinely unused APIs/state / Categories 1, 2

- **Location(s):** duplicated filename lookup: `RiptOPL/src/platform/tar.cpp:476-495,535-550`; duplicated prefix lookup: `RiptOPL/src/platform/tar.cpp:513-525,559-568`; identical close/invalidate bodies `RiptOPL/src/platform/tar.cpp:457-461,606-610`; empty unused function `RiptOPL/src/platform/httpclient.cpp:157-161`; unread counter `RiptOPL/include/guiqueue.h:33`, `RiptOPL/src/ui/guiqueue.cpp:14,82`.
- **Problem:** Exact and generic TAR entry points duplicate the same indexed-search loops after their different state preparation. `tarClose` duplicates `tarInvalidate` and is used only by host tests; `HttpStreamEnd` has no callers or declaration; `completed_` is incremented but never read.
- **Fix:** Keep state preparation in the public functions, share each existing identical search body only where it removes net code, make tests use the retained invalidation operation, and delete the unused no-op function/counter.
- **Justification:** Each proposed internal search has two real copies already, so consolidation deletes code overall. Everything else here is deletion.
- **Benefit:** **Small cleanup:** roughly 30 duplicated search lines, a duplicate close body, five no-op function lines and the completed counter/updates removed. Section garbage collection already drops unused `HttpStreamEnd`; do not count its source deletion as a measured ELF saving.
- **Effort:** S. **Risk:** Low. **Confidence:** High (**READ**, repository reference search; external consumers not investigated).

## RIPTOPL-902 / Delete unused Makefile-era release scripts / Categories 1, 7

- **Location(s):** RiptOPL/.github/scripts/build_rolling_extras.sh:1-104; RiptOPL/.github/scripts/release_channel.sh:1-23; RiptOPL/.github/scripts/asset_version.sh:1-11; RiptOPL/.github/scripts/irx_manifest.sh:1-72; RiptOPL/.github/workflows/flavours.yml:398-403; RiptOPL/.github/workflows/rolling-release.yml:130-178.
- **Problem:** These four scripts describe the retired Makefile/container release pipeline and claim workflow callers that no longer exist. Full tracked-code reference searches found no executable call sites; current releases use `tools/build_edition.py` and `tools/package_edition.py`. The remaining Makefile mentions are comments.
- **Fix:** Delete the four scripts and their obsolete comment links. Preserve the current release tooling.
- **Benefit:** **Measured:** 210 script lines removed; fewer misleading entry points. No runtime ELF/RAM saving claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ for script/workflow contents; INFERRED that there is no external, untracked manual caller).

### RIPTOPL-016 / Correct the existing host-test inputs instead of trusting their passing result / Category 7

- **Location(s):** `RiptOPL/tests/host/stub/include/opl.h:22`; actual declarations `RiptOPL/include/opl.h:119-121`, definitions `RiptOPL/src/app/opl.cpp:162-164`; malformed BOM fixture `RiptOPL/tests/host/test_config.cpp:130`.
- **Problem:** The host stub declares network arrays as `unsigned char[4]`, although production uses `int[4]`; the actual parser's `%d` stores are therefore incorrectly typed in this harness. Separately, `"\xEF\xBB\xBFcompat=9\n"` consumes the following hexadecimal `c` as part of the `\x` escape, so the nominal BOM fixture is not the intended three-byte BOM followed by `compat`.
- **Fix:** Match stub and test-global array types to production, and split the BOM literal before `compat`. Correct these existing tests; do not add another test framework.
- **Benefit:** **Small but concrete validation benefit:** existing sanitizer tests model the real object widths and BOM input; warnings from the audit's host build directly identify both mismatches. No production size/time saving.
- **Effort:** S. **Risk:** Low. **Confidence:** High (**READ**, compiler warnings observed).

### RIPTOPL-020 / Correct the history eviction tie-break and delete stale commented code / Categories 1, 5, 6

- **Location(s):** `RiptOPL/src/core/OSDHistory.cpp:173-182,217-223`; historical commented implementation `RiptOPL/include/OSDHistory.h:3-81`.
- **Problem:** The eviction loop updates the lowest launch count without resetting that candidate's timestamp. For records `(count=5,date=1)`, `(count=1,date=100)`, `(count=1,date=50)`, the stale date 1 prevents selection of the older equal-count record. The same files retain a disabled RNG loop and a 79-line historical pseudocode implementation.
- **Fix:** Reset the timestamp when selecting a lower-count candidate, and delete the disabled/historical implementation blocks after retaining any needed format description beside `HistoryEntry`.
- **Justification:** One assignment fixes the cited comparison error; the remaining change is deletion. No new history index or policy is needed.
- **Benefit:** **Small correctness/source benefit:** the least-used/oldest selection matches its existing intent; roughly 80 commented lines can be removed. No ELF saving is claimed for comments.
- **Effort:** S. **Risk:** Low. **Confidence:** High (**READ**, deterministic comparison trace; no hardware test).

## Canonical findings owned by the summary

The former RIPTOPL-003 is consolidated as **CROSS-003** in Codex-SUMMARY.md, together with POPSLoader’s copy/delete implementation. It is counted once.


- `CROSS-001`: unnecessary persistent backup files and copy/delete replacement fallbacks; RiptOPL updater locations `src/ui/selfupdate.cpp:249-337,339-415`, VMC rebuild `src/sources/vmcrebuild.cpp:118-199`, `include/vmcrebuild.h:4-14`. Full cross-repo problem/fix appears once in `Codex-SUMMARY.md`.

- `CROSS-002`: NFS compound-reply identity and required-operation validation, reviewed centrally; full common problem/fix appears once in `Codex-SUMMARY.md`.

## Verification and limits

- `sh tests/host/run.sh`: **13 suites passed** under its existing ASan/UBSan build. Compiler warnings include the stub-width and malformed BOM issues above. Log: `/tmp/codex-audit-work/RiptOPL-host-tests.log`.
- Existing `.github/scripts/test_file_manager.py`: **all checks passed**. Existing `.github/scripts/test_selfupdate_host.py`: **52 checks passed**.
- Audit-only cheat-name normalizer harness: **ASan stack-buffer-overflow and UBSan out-of-bounds store reproduced**. File-copy close-error injection: **source removed despite a reported destination close error**.
- Audit-only TAR cache harness: **ASan heap-buffer-overflow reproduced**. Audit-only LZ4 harness: **ASan invalid read/SEGV reproduced**. Audit-only configuration harness: **quoted numeric title rewritten as scalar reproduced**. These harnesses and generated binaries live only in `/tmp/codex-audit-work`; no tests were added to the repo.
- No PS2 compiler, SDK, real EE/IOP hardware, memory-card wear measurement, ELF link map or hardware timing validation was available. Source-derived sizes and complexity counts are explicitly inferred.
- `git status --short` remained empty after the tests and reproductions.

### Additional verification and coverage from the root reviewer


The root reviewer read all 12 current RiptOPL workflow definitions (2,220 lines), the complete scripts named above plus `hostmap.py`, `normalize_release_notes.py`, `package_release_app.py`, `validate_site.py`, `verify_psu_with_psumanager.cpp`, and complete `tools/run_tests.sh`, `tools/build.py`, `tools/package_edition.py`, and `.github/scripts/test_build_driver.py`. Other test scripts are **not** claimed read merely because they executed.

The existing `sh tools/run_tests.sh -k` was run in a disposable source copy outside the repository. It finished with **277 successful script/suite entries, zero failed entries, and two skipped documentation suites** (`test_site_sync.py`, `test_wiki_sync.py`, missing BeautifulSoup). The runner's final message was `all tests passed`; that includes its documented skips. This count is runner entries, not individual assertions. No PS2 toolchain or hardware build was available. The original repository remains clean.

## Coverage and files not read

This repository has **2,380 tracked files**. The durable manifest [Codex-RiptOPL-coverage.json](coverage/Codex-RiptOPL-coverage.json) lists every whole-file read, recorded partial span and unfinished path. Running a test, hashing a file or reading a search hit is not counted as a whole-file read.

All 12 current workflows and the explicitly listed packaging helpers were read, together with the recorded runtime files. **Most `src/`, `include/`, `ee_core/`, `modules/`, `third_party/`, tests, tools and documentation still require a continuation.** Binary/media files were inventoried, not reverse-engineered; sensitive material was not printed. The saved reviewer was stopped by automated filtering before completing its next pass.

**Unfinished categories: all eight**, across the unfinished paths in the manifest. The findings are source-backed opportunities in the reviewed scope; this is not an exhaustive completion or a claim of no further defects.

## Shared controller findings

The Bluetooth transfer-index defect, USB descriptor walk, endpoint cleanup and battery-table bounds are each listed once under **POPSLOADER-017, POPSLOADER-042, POPSLOADER-041 and POPSLOADER-018** in [Codex-POPSLoader.md](Codex-POPSLoader.md), with every affected copy in this repository cited there.

## Durable continuation manifest

[Exact coverage and remaining paths](coverage/Codex-RiptOPL-coverage.json): 60 whole-file reads; 36 paths with recorded partial evidence; 2320 paths require further review or explicit binary/document exclusion. This is a tracked-file count, not a claim that binary assets can be source-audited.
