# Launchstation remaining-scope findings

Snapshot `8cd3329a98c09a570bfbf60137717edd42324990`. Repository unchanged. READ means reviewed source; benefits marked INFERRED unless a source-declared or measured count. Canonical prior/shared findings are not repeated.


### LAUNCHSTATION-100 / Publish verified raw cloud cards without copying them again / Category 3,4,5

- **Location(s):** Launchstation/src/cloud_google.c:1038-1079; existing direct-promotion example Launchstation/src/cloud_google.c:1145-1175.
- **Problem:** A raw .mcd recovery downloads, hashes and validates the whole image, then copies it into a second temporary file and verifies that full copy before renaming it. The adjacent .psu recovery already publishes its validated download directly.
- **Fix:** For raw .mcd recovery, rename the completed verified download to the final new name using the existing .psu promotion path; retain conversion only for PCSX2 .ps2 input. Remove the raw-image copy/stage cleanup branch.
- **Justification:** Reuses an existing native rename mechanism and removes work; no new helper is needed unless sharing the two existing promotion bodies removes lines.
- **Benefit:** One full N-byte image write, its copy/verification reads and N bytes of temporary disk space avoided for each raw recovery (source-derived); N is typically 8–64 MiB, not EE RAM. Timing and ELF savings INFERRED/unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### LAUNCHSTATION-101 / Do not report cloud sync complete after a directory read error / Category 6

- **Location(s):** Launchstation/src/cloud_google.c:1485-1504,1575-1578,1631-1634.
- **Problem:** sync_tree ends its directory loop on both EOF and a negative fileXioDread result, then always returns success. An I/O failure can therefore skip remaining backups while the overall sync reports successful completion.
- **Fix:** Keep the existing Dread result and return the existing failure result when it is negative, after closing the directory.
- **Justification:** One local return-value check fixes false completion without retries or another traversal layer.
- **Benefit:** Incomplete cloud uploads no longer reported as successful; byte/timing change unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### LAUNCHSTATION-102 / Delete the identical custom-color preprocessor branch / Category 2,7

- **Location(s):** Launchstation/include/config_private.h:10-28.
- **Problem:** CUSTOM_COLORS and its else branch define all eight default colors to identical values. The conditional preserves a build choice that changes nothing.
- **Fix:** Keep one unconditional set of the eight constants and delete the duplicate branch and directives.
- **Benefit:** 11 physical lines removed; behavior and runtime storage unchanged. ELF-size change not claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.


### LAUNCHSTATION-103 / Check the partition-size index before reading its array / Category 6

- **Location(s):** Launchstation/ee_libs/hdd/libhdd.c:334-342,389-410; live caller Launchstation/src/dash_hdd.c:265-267,610-645.
- **Problem:** Exhausting the 128-MB allocation attempt decrements useIndex to -1 and evaluates sizesMB[useIndex] before checking it. An unrecognized or failed HDIOC_MAXSECTOR result also leaves maxIndex at 9 before an immediate sizesMB[9] access.
- **Fix:** Reject an unavailable/unrecognized maximum size and test index bounds before every table access; move the decrement/exhaustion check ahead of the lookup. Delete the unused expansion implementation instead of fixing its duplicate (LAUNCHSTATION-104).
- **Justification:** Local ordering and result checks remove concrete out-of-bounds reads without a new allocator or table.
- **Benefit:** Undefined EE memory reads removed on disk-full/driver-error paths; size/timing unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### LAUNCHSTATION-104 / Delete unused HDD library APIs and their obsolete accounting / Category 1,2,5,7

- **Location(s):** Launchstation/ee_libs/hdd/libhdd.c:135-260,262-293,459-569; Launchstation/ee_libs/hdd/include/libhdd.h:41-65,74-78; Launchstation/ps2.yaml:423-427; live consumers Launchstation/src/dash_hdd.c:146-210,212-243,265-285.
- **Problem:** hddGetFilesystemList, hddGetInfo, hddRemoveFilesystem and hddExpandFilesystem have no EE callers; the dashboard implements its own listing/removal and does not expose expansion. Their cached total/free accounting also performs an initial directory traversal from the status checks even though the live dashboard immediately traverses the same disk itself.
- **Fix:** Delete those four unused EE APIs, associated declarations/types and unused total/free calculations. Retain the live status/format/create functions, and query/check only the maximum partition size where creation needs it.
- **Benefit:** 237 function-body lines removed before accounting/header cleanup (source count); another full HDD directory walk avoided on initial status. Source reduction beyond that and ELF/IOP effects INFERRED; no runtime-RAM estimate claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ plus complete tracked reference search.

### LAUNCHSTATION-105 / Publish HDL RPC initialization only after a real bind / Category 6

- **Location(s):** Launchstation/src/hdl_rpc.c:24-49,52-82; Launchstation/src/dash_hdd.c:419-436; Launchstation/src/init.c:2563-2573,2965-2999.
- **Problem:** Hdl_Info_BindRpc sets Hdl_Inited even when all bind attempts were exhausted with no server, and the flag is never cleared elsewhere in the tracked source. Later HDD Manager visits trust that stale flag after an IOP reset, while both RPC calls ignore transport failure and interpret their request buffer as a reply.
- **Fix:** Set Hdl_Inited only when client.server is bound, clear it with the existing IOP reset state, and fail an existing HDL operation when SifCallRpc fails. Delete hdlReady's process-lifetime tried latch so an explicit later R1 action can load the current IOP service.
- **Justification:** These are existing state/return checks and deletion of a stale latch, without retries or new RPC infrastructure.
- **Benefit:** False successful binding, stale-session use and bogus replies removed; no measured byte/time saving.
- **Effort:** S. **Risk:** Low. **Confidence:** READ for binder/reset/consumers and complete flag-reference search; actual stale-IOP failure occurrence INFERRED.

### LAUNCHSTATION-106 / Rename the selected HDL partition by its existing identifier / Category 6

- **Location(s):** Launchstation/src/dash_hdd.c:123-128,700-724; Launchstation/src/hdl_rpc.c:69-82; Launchstation/iop/hdl_info/hdd.c:173-184.
- **Problem:** Rename sends the old display title and the IOP changes the first game with that title, so duplicate game titles can rename another partition. The job's 40-byte field also truncates titles longer than 39 bytes before that lookup.
- **Fix:** Pass the selected partition name already available in p->name through the existing old-name field and compare game->partition_name on the IOP. Keep the existing job and packet sizes; use their current name fields as the partition identifier.
- **Justification:** Reuses the existing unambiguous APA identifier and existing fields; no larger buffers or lookup layer.
- **Benefit:** Wrong-game rename and long-title lookup failure fixed; no additional persistent memory or claimed size/timing saving.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### LAUNCHSTATION-107 / Release HDL list storage consistently on success and failure / Category 4,6

- **Location(s):** Launchstation/iop/hdl_info/hdl.c:75-96,141-166; Launchstation/iop/hdl_info/hdd.c:129-136,167-174.
- **Problem:** A failed hdl_ginfo_read frees *glist and its games allocation but leaves the caller's games pointer dangling, so the next metadata request frees it again. Successful hdl_glist_write instead frees its wrapper but leaks the complete temporary games allocation after every rename.
- **Fix:** Clear *glist when its failed construction is freed; free tmp on every hdl_glist_write exit after use, including success. Keep the existing two allocations and cleanup structure or remove the temporary full games list entirely as part of a simpler partition-name lookup.
- **Justification:** Two ownership corrections prevent an actual double free and repeated IOP leak; no ownership wrapper is needed.
- **Benefit:** One sizeof(hdl_game_info_t) × game-count allocation no longer leaked per successful rename; double free removed after a metadata read failure. IOP byte count depends on target structure layout; no host-size substitution claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### LAUNCHSTATION-108 / Respect the fixed HDL metadata field sizes / Category 6

- **Location(s):** Launchstation/iop/hdl_info/hdl.c:27-53,108-120; Launchstation/iop/hdl_info/hdl.h:4-15; Launchstation/iop/hdl_info/ps2_hdd.h:18-20.
- **Problem:** Sector strings are copied with unbounded strcpy into 65-byte game names and 13-byte startup names, and nsub indexes a 64-entry array with no upper bound. Every rename then memcpy-reads 128 bytes from the 65-byte game-name member, including following members and memory beyond the object.
- **Fix:** Validate nsub against PS2_PART_MAXSUB, read each string only within its actual destination/format field, and write the zero-padded disk name from at most the validated game-name length. Reject unterminated/oversized metadata instead of copying across fields.
- **Justification:** A few fixed-field bounds remove concrete IOP memory corruption and an unconditional rename over-read; no general parser layer is needed.
- **Benefit:** Heap overwrite, out-of-range subpartition reads and writing unrelated IOP bytes into the disk header removed. No size/timing measurement.
- **Effort:** S. **Risk:** Med. **Confidence:** READ.

### LAUNCHSTATION-109 / Stop HDL rename when its original header cannot be read / Category 6

- **Location(s):** Launchstation/iop/hdl_info/hdl.c:108-122; Launchstation/iop/hdl_info/hdd.c:178-184.
- **Problem:** hdl_ginfo_write ignores the original two-sector read result and byte count, edits its uninitialized/partial stack buffer and writes all 1,024 bytes back to disk. A read failure during rename can therefore overwrite the game's metadata with unrelated stack bytes.
- **Fix:** Return the existing error before modifying/writing unless the read succeeded with exactly 1,024 bytes; require the expected write size and the existing device flush to succeed before reporting rename success.
- **Justification:** Uses existing read/write/flush results at the actual destructive boundary; no retries, backup or transaction layer.
- **Benefit:** Prevents header corruption and false rename success on I/O failure; code-size impact unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### LAUNCHSTATION-110 / Bound every APA traversal hop, including non-game partitions / Category 5,6

- **Location(s):** Launchstation/iop/hdl_info/apa.c:139-179.
- **Problem:** The loop's only cycle guard counts stored HDL game partitions. A checksummed next-pointer cycle among PFS/system/subpartition headers never increments that count and can hold the IOP RPC and synchronous HDD Manager request forever.
- **Fix:** Count every traversed header against the existing traversal budget, and reject an out-of-capacity next/header range using subtraction-based bounds. Keep the current table and error return; do not reactivate the disabled historical checker.
- **Justification:** One traversal counter and local geometry checks fix a concrete non-progress path without a second parser or visited-set allocation.
- **Benefit:** Unbounded malformed-disk traversal removed; small added counter, no claimed runtime memory saving. Failure-trigger occurrence INFERRED; control-flow defect READ.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.


### LAUNCHSTATION-111 / Treat a failed embedded-module load as failure / Category 6,5

- **Location(s):** Launchstation/src/init.c:1533-1555,1715-1734,2108-2118; Launchstation/src/pad_ds34.c:444-450; Launchstation/iop/ds34usb/ee/libds34usb.c:22-35; Launchstation/iop/ds34bt/ee/libds34bt.c:25-38.
- **Problem:** loadExternalModule tests the module ID as a boolean, so a negative SifExecModuleBuffer error is returned as success and a valid zero ID as failure. DS34 startup then unconditionally enters RPC bind loops that wait forever for a service the failed module never registered; the keyboard similarly latches a failed module as available.
- **Fix:** Convert the embedded load's ID and resident result into a real success boolean. Pass the existing DS34 load result through to setupPad so only successfully started services are bound; bound a bind attempt as described by canonical POPSLOADER-016 instead of adding a retry system.
- **Justification:** Corrects existing result handling and reuses existing failure results; no new loader abstraction.
- **Benefit:** False module-load success removed and failed DS34 startup no longer strands boot in an unbounded wait. Byte/timing effect unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### LAUNCHSTATION-112 / Clear disconnected controllers in the DS34 poll / Category 6

- **Location(s):** Launchstation/src/pad_ds34.c:60-100,158-172,180-245; already-correct ordinary-pad precedent Launchstation/src/pad.c:34-64,72-143.
- **Problem:** When a wired/USB/Bluetooth controller stops being ready, the polling thread leaves its previous nonzero ret and held-button mask untouched. Disconnecting while a button is held can therefore keep that button active and repeating indefinitely; the DS34 read path also replaces physical-button bits with an alternating stick-only mask, reintroducing the issue already fixed in ordinary pad.c.
- **Fix:** Publish zero status/held mask for an unavailable or failed controller sample, and keep one stable combined physical/stick mask using the existing ordinary-pad logic. Remove the alternating test_joy bookkeeping.
- **Justification:** Applies the existing corrected behavior to the alternate build; no new input framework or polling thread.
- **Benefit:** Stuck/retriggered input fixed in DS34 builds; unused alternating-state variable deleted. Runtime/ELF effect unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ; disconnect/hold trigger consequence INFERRED from state retention.

### LAUNCHSTATION-113 / Keep DS34 semaphore lifetime outside the polling tick / Category 4,5,6

- **Location(s):** Launchstation/src/pad_ds34.c:50-58,103-145,490-507; Launchstation/src/init.c:2146-2158.
- **Problem:** The 10-ms poll creates and destroys its alarm semaphore every iteration. Each polling restart additionally creates three control semaphores, but neither existing stop path deletes them, leaking three EE semaphore objects per restart.
- **Fix:** Create the alarm semaphore once for the polling thread and delete it on thread exit. After each existing stop wait has completed, delete its three control semaphores before creating the next polling session; check creation before starting the thread.
- **Justification:** Moves existing allocation/cleanup to its actual lifetime; a shared stop helper is warranted only if replacing both current stop blocks is a net deletion.
- **Benefit:** Approximately 100 CreateSema/DeleteSema pairs per second removed at the source-declared 10-ms poll rate; three semaphore objects no longer leaked per restart. Actual EE bytes/time unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ for lifecycle and declared cadence; hardware rate INFERRED.

### LAUNCHSTATION-114 / Use the existing path resolver for external keyboard inputs / Category 2,6

- **Location(s):** Launchstation/src/init.c:1412-1463,1477-1490,1533-1543; existing resolution Launchstation/src/filer.c:924-1048.
- **Problem:** The private HDD conversion always builds pfs0: and ignores mountParty's returned slot, so an external keyboard/keymap in another partition can be loaded from the wrong mounted partition. A malformed hddN:/partition path without a following slash also dereferences the null strchr result.
- **Fix:** Delete the private HDD/DVR path conversion and use the existing genFixPath result, which handles mount slots and root paths. Propagate its failure instead of opening the assumed pfs0 path.
- **Justification:** Reuses the existing resolver to replace duplicate path logic; no wrapper or new path format.
- **Benefit:** Wrong-file load/null dereference fixed and roughly 25–35 lines removed (INFERRED); size/time unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### LAUNCHSTATION-115 / Delete driver-stack choices that never switch anything / Category 1,3,7

- **Location(s):** Launchstation/src/init.c:301-308,376,386-387,748-802,2140,2286-2309,2329-2347,2536-2555,2663-2687,2719,3122-3123,3140-3142; Launchstation/ps2.yaml:684.
- **Problem:** load_ps2atad_stack has no caller, switchPsxHddDriverStack only prints debug text, and switchBlockStorageStack's reset branch is unreachable for its only HDD/ATA callers because those two modes explicitly coexist. The remaining block-mode bits duplicate the existing loaded-driver flags.
- **Fix:** Delete the unused ATA loader/import/embed entry and the no-op PSX switch function/calls. Remove the block-stack switcher/mode state, keeping direct checks of the existing HDD/ATA loaded flags.
- **Benefit:** At least 98 function-body lines removed (54 unused ATA block + 24 block switch + 20 PSX block, source-range count), plus mode-state/call/import cleanup. The unused SDK ATA blob can leave the embedded ELF only if presently retained; final ELF bytes unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ and repository-wide caller search.


### LAUNCHSTATION-116 / Delete the unused classic texture-icon loader and blobs / Category 1,4,7

- **Location(s):** Launchstation/src/draw.c:15,206-227; Launchstation/src/icon.c:1-2055; Launchstation/include/launchelf.h:469-473,505; Launchstation/ps2.yaml:560.
- **Problem:** loadIcon has no tracked caller and TexIcon/icon_folder/icon_warning are referenced only by that unused path and their declarations. The abandoned loader even frees the two static arrays as if they were heap allocations.
- **Fix:** Delete loadIcon, TexIcon, the two declarations and src/icon.c/build entry. Keep the live dashboard icon atlas and font glyphs.
- **Benefit:** 2,055 literal-source lines plus the 22-line loader and unused declarations removed; 2,048 source-declared payload bytes can leave the ELF if retained today. No final ELF delta measured, and no active invalid-free trigger claimed because the loader is unused.
- **Effort:** S. **Risk:** Low. **Confidence:** READ for complete consumer/build/caller search; payload bytes structurally parsed.

### LAUNCHSTATION-117 / Replace the recursive first-pivot file sort / Category 4,5,6

- **Location(s):** Launchstation/src/gui_sort.c:12-13,74-95; Launchstation/src/filer.c:2460-2463; Launchstation/include/launchelf.h:204-205,560-565.
- **Problem:** sort chooses the first entry as pivot and recurses over the remaining N−1 entries for sorted/equal input. setFileList calls it even when file_sort=0, when every comparison returns zero: a maximum-size listing therefore approaches 2,047 stack frames, each holding two large FILEINFO copies, on the 128-KiB EE thread stack.
- **Fix:** Delete the custom quicksort and call the already-used libc qsort with cmpFile adapted to its comparator signature; skip sorting entirely when file_sort=0.
- **Justification:** Reuses a library routine already linked elsewhere and removes recursive application code; no extra arrays or sorting layer.
- **Benefit:** Worst-case linear recursion and quadratic comparisons removed; one complete sort avoided when disabled. Each recursive source frame declares two FILEINFO objects; exact compiled stack/ELF savings unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ; real-console stack overflow occurrence INFERRED from the source frame/depth bounds.

### LAUNCHSTATION-118 / Reject short external font files before publishing them / Category 6

- **Location(s):** Launchstation/src/draw_text.c:67-105.
- **Problem:** loadFont ignores both read counts and only enforces a maximum file size. A 100-byte file with the expected header passes, seeks beyond EOF, reads no glyph bytes and still returns success after partially clearing the active font buffer.
- **Fix:** Require the complete header, seek and complete glyph read to succeed; otherwise restore the existing built-in font and return failure through use_default.
- **Justification:** Small checks reuse the existing fallback; no second font buffer or recovery layer.
- **Benefit:** False-success/broken-font publication removed; byte/timing change unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### LAUNCHSTATION-119 / Release the inflated MCM payload when save setup fails / Category 4,6

- **Location(s):** Launchstation/src/mc_save_formats.c:216-255.
- **Problem:** mcSaveFromMcm owns the inflated raw payload after inflateAll succeeds, but returns through fail(out, r) without freeing it when startSave rejects the folder name or cannot allocate entries. Repeating such an import permanently consumes EE heap for each inflated payload.
- **Fix:** Free raw before the existing startSave failure return, matching the adjacent addFile failure path.
- **Benefit:** One complete inflated-payload leak removed per rejected setup; bytes depend on the supplied save and available EE heap. No runtime allocation measurement.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### LAUNCHSTATION-120 / Use exclusive creation for files promised to remain untouched / Category 6

- **Location(s):** Launchstation/src/dash_card_tool.c:2544-2545,2588-2599,552-558; Launchstation/src/cloud_google.c:1033-1038,1141-1145; Launchstation/src/dash_ftp.c:102-104.
- **Problem:** Saving a PSU set and opening cloud recovery download/staging files check that a name is free, then create with O_TRUNC. FTP can keep running after the FTP screen closes, so a file created at that name between the check and open is truncated despite the new-file/keep-existing promise.
- **Fix:** Pass fresh=1 to the existing ctWriteFileAs call for a new set member, and use O_EXCL instead of O_TRUNC for newly chosen recovery files. Return the existing failure result if the name was taken.
- **Justification:** Uses creation semantics and the existing writer; no lock, wrapper, retry or backup layer.
- **Benefit:** Existing-file truncation race removed at three creation sites; no timing or byte benefit claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ for the check/open mismatch and concurrent-server support; race occurrence INFERRED.

### LAUNCHSTATION-121 / Keep left-moving drift clouds inside their wrapping interval / Category 6

- **Location(s):** Launchstation/src/dash_bg_ps2.c:795-818.
- **Problem:** Odd cloud indices pass a negative travel expression to fmodf, then calculate span-x. Once the travel exceeds their initial offset, fmodf remains negative and span-x lies beyond the right edge, so the left-moving clouds disappear instead of circulating through the scene.
- **Fix:** Take the modulo of the positive travel phase before reversing it for leftward movement, or normalize the existing remainder into [0, span) before reversal.
- **Benefit:** The existing left-moving clouds remain visible as intended; no extra primitives, state or allocation. Visual behavior inferred from the fully read coordinate equations, without a console capture.
- **Effort:** S. **Risk:** Low. **Confidence:** READ / visual outcome INFERRED.

### LAUNCHSTATION-122 / Validate the converted RTC year before reducing it to two digits / Category 6

- **Location(s):** Launchstation/src/dash_clock_sync.c:425-444; Launchstation/src/main_title.c:232-239,259-295.
- **Problem:** Manual clock entry validates the displayed year, then converts to the RTC's JST base and writes raw_y % 100 without checking the converted year. A valid local 2000-01-01 00:00 in a UTC+10 zone converts to 1999-12-31 23:00, but is written as year 99 and subsequently decoded as 2099; the upper boundary can similarly wrap into 2000.
- **Fix:** Reject converted raw_y values outside 2000–2099 before sceCdWriteClock, using the existing invalid-date result path.
- **Justification:** One boundary check prevents an incorrect hardware write; no new conversion helper or recovery mechanism.
- **Benefit:** Century-wrapping hardware clock writes prevented; no size/time measurement.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### LAUNCHSTATION-123 / Delete the unused title-token interpreter / Category 1,3,7

- **Location(s):** Launchstation/src/main_title.c:11,51-79,591-610,612-654,665-716; Launchstation/include/main_title.h:6-8; Launchstation/src/draw.c:52,97.
- **Problem:** menuTitleFormat has no tracked caller, while its format is a fixed compile-time string containing every supported token. The live separate clock/temperature formatters still query five token predicates and use character-by-character append helpers to implement a format users cannot change.
- **Fix:** Delete the unused menuTitleFormat function/declaration, fixed format string and token predicates; update the clock and temperature directly. Replace the live append sequences with bounded snprintf calls and delete their two now-unused append helpers.
- **Benefit:** Removes a 37-line unused formatter, 29 lines of token helpers and 20 lines of append helpers before the small live replacements/branch cleanup; final ELF and frame-time delta unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ and repository-wide caller search.

### LAUNCHSTATION-124 / Reset the history age tie-breaker when the usage minimum changes / Category 6

- **Location(s):** Launchstation/src/main_history.c:83-105,141-146.
- **Problem:** processHistoryList updates the minimum launch count without resetting its associated timestamp. If an earlier, more-used entry has an older timestamp, later entries tied for the actual minimum usage cannot replace the first minimum entry even when they are older, so a full history evicts the wrong record.
- **Fix:** Set leastUsedRecordTimestamp to the new entry's timestamp whenever a lower launch count becomes the minimum; retain the timestamp comparison only for equal counts.
- **Benefit:** Restores the existing least-used/oldest selection rule; no extra state, writes or allocation.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

Existing-finding evidence: LAUNCHSTATION-012 also applies to Launchstation/src/dash_ps1_card.c:28-30, which permanently reserves three PS1_CARD_SIZE buffers (3 × 131,072 = 393,216 bytes, 384 KiB). The complete 716-line consumer was read; operation-scoped allocation has the same idle-RAM tradeoff already described by 012, rather than a separate allocator layer. Exact final ELF delta is unmeasured.

### LAUNCHSTATION-125 / Remove copied classic configuration branches and HDD-mode helpers / Category 2,3

- **Location(s):** Launchstation/src/config_advanced.c:27-49,107-182; Launchstation/src/config_startup.c:30-52,97-108; Launchstation/include/config_private.h.
- **Problem:** Both classic pages carry the same HDD-mode normalization, seven labels and display helper. Advanced settings also duplicates its entire boolean/return dispatch for Cross and Circle even though only the HDD increment direction differs; both pages duplicate identical Left and Right navigation branches.
- **Fix:** Keep one copy of the two existing HDD helpers and their private table in config.c, declared in config_private.h. Merge Left/Right conditions and the Advanced Cross/Circle dispatch, selecting an increment sign only for HDD mode.
- **Justification:** Two exact helper/table copies become one with two private declarations; the shared implementation and merged branches remove code without a generic menu abstraction.
- **Benefit:** One 23-line helper/table block, one roughly 29-line duplicated Advanced dispatch tail and two six-line navigation branches removed before small condition/declaration changes. Final source/ELF delta unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### LAUNCHSTATION-126 / Preserve network-file tails when the initial open fails / Category 6

- **Location(s):** Launchstation/src/config_network.c:11-56.
- **Problem:** configWriteNetworkSnapshot preserves the old tail only if its initial read-only open succeeds. Every negative open result is treated as a missing file, so a transient read/open failure on an existing IPCONFIG.DAT can be followed by a successful O_TRUNC open that destroys the un-read tail, contrary to the function's stated guarantee.
- **Fix:** Permit creation only for a confirmed missing file; return the existing failure result for every other read/open error before the truncating write.
- **Justification:** A narrow error check preserves the current writer and error UI; no staging file, backup or retry layer.
- **Benefit:** Existing configuration-tail loss on read-open failure prevented; no extra successful-path writes or byte/timing measurement.
- **Effort:** S. **Risk:** Low. **Confidence:** READ for the missing/error conflation; device-error occurrence INFERRED.

### LAUNCHSTATION-127 / Bound boot-argument formatting in the classic debug screen / Category 6

- **Location(s):** Launchstation/src/main_info_screens.c:215-217,248-252; Launchstation/src/main_boot.c:8-17.
- **Problem:** ShowDebugInfo formats each captured boot argument with sprintf into a 256-byte stack buffer. An executable path or other boot argument longer than the remaining line space overruns the buffer when this screen is opened; the nearby boot_path and LaunchElfDir formatting already applies bounds.
- **Fix:** Replace the argument sprintf with snprintf using sizeof(TextRow), as the adjacent bounded fields do.
- **Benefit:** Stack overwrite removed for long boot arguments; no extra allocation or formatting layer.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### LAUNCHSTATION-128 / Reuse the existing image-ID resolver for VCD files / Category 2,3,5

- **Location(s):** Launchstation/src/popstarter_gameid.c:102-123,190-226,240-259; Launchstation/src/popstarter_vcd.c:246-257; Launchstation/src/ember_gameid.c:113-116,153-161.
- **Problem:** The VCD resolver separately opens a file to parse SYSTEM.CNF and opens it again for the PVD timestamp, duplicating the sequence already implemented by buildPs1ImageGameID for the same sector reader. The second open is unnecessary when the first identity method fails.
- **Fix:** Open the VCD once, construct the existing PS1_IMAGE_READER with its one-MiB offset, call buildPs1ImageGameID with a null name fallback, and close it. Delete the two VCD-specific open/resolve wrappers; keep the existing HDD-partition/name fallback afterward.
- **Justification:** Reuses a resolver already called for CUE/BIN images and deletes two copies of its identity sequence; no new helper or reader layer.
- **Benefit:** Deletes 43 wrapper-body lines before a small direct call sequence; eliminates one file open/close on the timestamp-fallback path. Existing PVD rereads inside the resolver remain; runtime and ELF deltas unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.
