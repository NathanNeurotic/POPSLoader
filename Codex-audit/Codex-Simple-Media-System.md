# Codex audit: Simple-Media-System

**-unfinished- checkpoint:** This is the earlier baseline report, preserved with its validation results. See [the resume index](Codex-RESUME-unfinished.md) and linked continuation findings for the later review. Earlier read-only statements describe source handling before the user authorized this report-only draft PR.

**Status: PARTIAL audit pass; remaining scope is listed below.** Snapshot `b9a5c882d6d632914faa4ff8dc080f1ecd51bfd7` on `master`; read-only source review, 1,012 tracked files. Findings are ordered by real failure impact, then runtime/size benefit and smaller maintenance wins. Categories follow the user's 1–8 list. `READ` means direct source evidence, not hardware verification. No licence finding, secret material, patch, repository write, branch/tag mutation, workflow run, or publication was performed.

Unless explicitly described as measured or as a source-declared capacity/count, proposed reductions are INFERRED until implemented. READ denotes source evidence, not hardware verification.

## Evidence and limits

Eight existing host suites passed: `test_audio_formats.py`, `test_asf_parser.py`, `test_copy_file.py`, `test_playlist_playback.py`, `test_boot_config.py`, `test_browser_artwork.py`, `test_ipconfig.py`, and `test_skin_loading.py`. The playlist harness produced a host 64-bit pointer-cast warning; that does not establish an EE defect. Logs are in `/tmp/codex-audit-work/SMS-test_*.log`.

The existing ASF harness, with temporary input-only mutations, independently reproduced zero packet size (UBSan division by zero), INT_MIN fragment length (UBSan signed overflow), and huge packet size in broadcast mode (2-second timeout). Temporary harness files were automatically removed; only evidence logs remain outside the repository. Docker is callable but has no cached PS2 toolchain image; no native ELF build, final ELF size measurement or PS2 hardware run is claimed. Existing investigation documents were used only as leads; historical claimed builds/savings were not counted as measurements by this audit.

Additional converter verification: the emitted QPel option failed locally with FFmpeg exit 8; the existing normalization filter chain produced 192,000-Hz FLAC from a 44,100-Hz source, confirmed by FFprobe. These temporary outputs were outside the repository. No Qt/Windows close-lifecycle run was performed.

## SMS-001 / Reject impossible ASF packet geometry before packet reading / Category 6

- **Location(s):** Simple-Media-System/src/SMS_ContainerASF.c:177-192, 339-354, 368-392, 479-491
- **Problem:** The header accepts zero packet size, then the packet reader takes a modulo by that value. A broadcast ASF with a packet size at least 2^29 repeatedly seeks back and returns without progress; this freezes playback inside ReadPacket.
- **Fix:** Reject zero and >=2^29 maximum packet sizes in the existing header failure path.
- **Justification:** Two boundary comparisons prevent already reproduced failures and reuse existing cleanup; no new parser layer or recovery system.
- **Benefit:** Real division-by-zero and infinite loop fixed; 0 bytes saved claimed. Host UBSan reproduced zero; the large-size broadcast case exceeded a 2 s timeout.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-002 / Reject negative ASF payload lengths before arithmetic / Category 6

- **Location(s):** Simple-Media-System/src/SMS_ContainerASF.c:455-465, 524-555
- **Problem:** A 32-bit payload length is assigned to signed packet_frag_size and checked for negativity only after additions/subtraction. INT_MIN reaches packet_size_left subtraction and causes signed overflow; smaller negative values desynchronize the stream.
- **Fix:** Reject negative fragment lengths alongside the existing upper-bound check in asf_read_frame_header, before any size arithmetic.
- **Justification:** One early comparison replaces reliance on the too-late negative guard and prevents arithmetic on a demonstrated malformed field.
- **Benefit:** Real signed-overflow bug fixed; the existing sanitized harness reproduced INT_MIN overflow.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-004 / Bound failed-save diagnostics to their destination buffer / Category 6

- **Location(s):** Simple-Media-System/src/SMS_Config.c:64, 69, 940-945, 1082-1086
- **Problem:** A configuration path can occupy up to 127 characters, but failed CWD saves format that entire path into g_SaveDiag[64] using sprintf. An ordinary long installation path plus an open/write failure therefore overwrites adjacent global storage.
- **Fix:** Replace these sprintf calls with snprintf using sizeof(g_SaveDiag), or omit the path from the diagnostic.
- **Justification:** A bounded formatter is a direct replacement for the unsafe formatter; deleting the path is still smaller.
- **Benefit:** Real global-buffer overflow removed; no size or latency savings claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-005 / Validate persisted indices and strings before using them / Category 6

- **Location(s):** Simple-Media-System/src/SMS_Config.c:696-704, 727-731, 763-768; Simple-Media-System/include/SMS_Config.h:93-139; Simple-Media-System/src/SMS_GUI.c:674-675; Simple-Media-System/src/SMS_GUIMenuSMS.c:553-558, 936-941
- **Problem:** The binary config overwrites live settings before a full read succeeds, then validates only a few fields. A corrupt/truncated config can leave palette indices outside 1..16, charset outside its table, or unterminated language/MBF names; those values are used for array access/strlen.
- **Fix:** Read exactly the persisted prefix into temporary settings, reject short reads, then validate only externally loaded table indices and terminate fixed strings before committing them. Reuse current defaults for rejected data.
- **Justification:** A temporary persisted prefix (~896 bytes on EE) and minimal boundary checks directly prevent cited array/string accesses. No schema, wrapper, migration, or backup is needed.
- **Benefit:** Out-of-bounds reads and invalid settings after interrupted card writes avoided; exact RAM/code delta unmeasured.
- **Effort:** M. **Risk:** Med. **Confidence:** High (READ).

## SMS-006 / Terminate and initialize fixed-width CDDA metadata strings / Category 6

- **Location(s):** Simple-Media-System/src/SMS_FileContext.c:805-818, 846-847, 859-868, 1064-1069, 1140-1147
- **Problem:** _read_string reads a fixed number of on-disc bytes and calls strlen without adding a terminator or requiring a full read. If the string is empty, it leaves the output pointer untouched; directory/file nodes came from malloc, so later cleanup can free an uninitialized pointer.
- **Fix:** Set the output pointer to NULL on entry, reserve one extra byte locally, terminate at the actual returned byte count, and copy only that bounded string.
- **Justification:** A terminator and initialized result remove two concrete bugs in the existing reader; no new general string framework.
- **Benefit:** Disc-metadata stack over-read and invalid-free paths fixed.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-007 / Handle allocation failures at existing construction boundaries / Category 6

- **Location(s):** Simple-Media-System/src/SMS_List.c:17-21, 57-71, 319-325; Simple-Media-System/src/SMS_DirTree.c:46-61; Simple-Media-System/src/SMS_CopyTree.c:150-155, 252-255; Simple-Media-System/src/SMS_FileMapping.c:276-295; Simple-Media-System/src/SMS_ContainerAAC.c:197-215; Simple-Media-System/src/SMS_ContainerMP3.c:121-135; Simple-Media-System/src/SMS_ContainerASF.c:157-159, 206-212, 261
- **Problem:** Several retained constructors dereference malloc/calloc results immediately. Large directory/history/media activity on the 32 MB EE can turn allocation failure into a crash instead of the existing operation failure path.
- **Fix:** Check construction results before linking/dereferencing them and unwind through existing failure cleanup. For lists, preserve the current list and report failure to callers that currently dereference the returned node.
- **Justification:** Checks apply to cited allocations with immediate dereferences, particularly data-dependent directory/media construction. Keep each at the owning constructor; no allocation wrapper or blanket defensive layer.
- **Benefit:** Low-memory crashes fixed; exact code-size cost unmeasured.
- **Effort:** M. **Risk:** Med. **Confidence:** High (READ).

## SMS-028 / Do not destroy converter workers after an unsuccessful timed wait / Categories 5, 6

- **Location(s):** Simple-Media-System/tools/sms_converter/ui/main_window.py:213-265; Simple-Media-System/tools/sms_converter/worker.py:34-46; Simple-Media-System/tools/sms_converter/ffmpeg_utils.py:109-131.
- **Problem:** Closing waits five seconds for the encoder and two seconds per inspection, ignores wait results, then accepts destruction. FFprobe has no timeout or cancellation handle, so a QThread can still be running when its owner is destroyed; these waits also block the GUI serially.
- **Fix:** Complete shutdown from existing finished signals and keep the window alive until workers finish. Give the active inspection subprocess the direct cancellation already used for conversion; remove unchecked serial waits.
- **Justification:** This repairs the existing child-process lifetime handling without another framework, retry or logging system.
- **Benefit:** Removes unsafe teardown and up to two seconds of GUI-thread waiting per outstanding inspection. Delays are source bounds; the Qt destruction failure was not dynamically reproduced (INFERRED consequence).
- **Effort:** M. **Risk:** Med. **Confidence:** High (READ; runtime consequence INFERRED).

## SMS-003 / Delete the incomplete apply-now network reset / Category 8

- **Location(s):** Simple-Media-System/src/SMS_IOP.c:474-510, 527-530, 1776-1829; Simple-Media-System/src/SMS_GUIMenuSMS.c:1437-1453
- **Problem:** SMS_IOPNetSwitch resets the whole IOP, keeps the DEV9_IS flag, and calls starters that assume the DEV9 module still exists. Reset reloads base I/O and controller modules only; it also drops audio/storage/DS34 modules while their EE clients and browser state remain live.
- **Fix:** Delete the apply-now reset function and its menu prompt/call. Keep the selected preference for the next normal launch.
- **Benefit:** 54 function lines plus 17 menu lines removable, with invalid RPC/module state avoided. Runtime effect inferred from read control flow; no console run.
- **Effort:** S. **Risk:** Med. **Confidence:** High (READ; hardware impact INFERRED).

## SMS-009 / Return an error when an M3U item has no recognized format / Category 5

- **Location(s):** Simple-Media-System/src/SMS_ContainerM3U.c:135-171, 222-227; Simple-Media-System/src/SMS_Player.c:1405-1409
- **Problem:** When no subcontainer recognizes a later M3U item, _ReadFirstPacket returns zero and leaves itself installed. The player treats zero as retryable and probes that same unsupported item on every loop until a button interrupts it.
- **Fix:** Return a negative result for the exhausted-probe case so the existing EOF/error path ends it; optionally reuse the existing next-item path once if skipping is required.
- **Justification:** Changing the failure result uses the existing player contract; no retry policy or new playlist layer.
- **Benefit:** Repeated 7-format probing and a stalled playlist removed; ms unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-014 / Stop retaining failed-start residency flags and duplicate module loads / Category 6

- **Location(s):** Simple-Media-System/src/SMS_IOP.c:232-245, 641-647, 784-806, 823-845, 1303-1353
- **Problem:** USB flags are set even when module loading fails, and ATA/iLink starters have no already-loaded guard. ATA claims its bus even if ata_bd failed, so a failed start can block the alternate HDD path; repeated starts can load duplicate drivers.
- **Fix:** Use both the loader return and module return before setting residency/bus ownership. Add the same existing residency early-return used by USB/MX4SIO/MMCE to ATA and iLink. Require XZ_STREAM_END before loading decompressed IRX data.
- **Justification:** The checks and two early returns correct concrete flag/load order defects; they remove redundant work and reuse current flags rather than adding state.
- **Benefit:** Avoids false device state, duplicate IOP modules and repeated multi-second startup stalls; bytes/RAM depend on the module and are unmeasured.
- **Effort:** M. **Risk:** Med. **Confidence:** High (READ).

## SMS-010 / Read only the CDDA sectors that are actually searched / Category 4

- **Location(s):** Simple-Media-System/src/SMS_FileContext.c:320-334
- **Problem:** The PS2 signature scan reserves 2352*512 bytes on the stack and reads 512 sectors, but searches only the first 256. The second half is never inspected.
- **Fix:** Reduce the buffer and raw read from 512 sectors to 256, keeping the existing 256-sector search unchanged.
- **Benefit:** 602,112 bytes less peak stack and 602,112 fewer optical bytes read per scan (exact source arithmetic); elapsed time unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-011 / Decompress icons directly into their final backing allocation / Category 4

- **Location(s):** Simple-Media-System/src/SMS_GUIcons.c:1388-1443; Simple-Media-System/src/SMS_IconsRGBA.c:1747-1748
- **Problem:** GUI_LoadIcons allocates the 205,824-byte raw blob and a separate 242,688-byte final icon store, then copies all originals before freeing the raw blob. Only nine darkened twins need additional storage.
- **Fix:** Lay out originals contiguously in the final store, decompress directly there, point misc/device/original browser slots at their offsets, and append only the nine darkened copies. Delete the scratch allocation and copy loops for originals.
- **Justification:** Reorders an existing backing block, removes an allocation and copy loops, and adds no helper/abstraction. Preserve the current compressed blob and all icons.
- **Benefit:** 205,824 bytes less peak heap and 205,824 bytes fewer memcpy source data copied per load (exact layout arithmetic); time unmeasured.
- **Effort:** M. **Risk:** Med. **Confidence:** High (READ).

## SMS-012 / Remove embedded modules with no live consumer / Category 1

- **Location(s):** Simple-Media-System/include/SMS_Data.h:17-24, 35-49; Simple-Media-System/src/SMS_Data.c:5480-6588, 12412-13642; Simple-Media-System/src/SMS_IOP.c:584-596, 636-688
- **Problem:** SMSSMB remains embedded although neither build mode loads it. Default BDM=1 also embeds legacy UMS/USBD inside g_DataBuffer while loading their separate modern compressed blobs.
- **Fix:** Delete the SMSSMB data block and collapse its offset link. Exclude only UMS/USBD blocks in BDM builds and collapse their offsets there. Preserve all live module offsets/alignment and the audio/synth workspace size.
- **Benefit:** 37,312 padded embedded bytes removable in BDM=1, 19,648 in BDM=0 (header-size arithmetic). Final ELF/packed delta not independently built.
- **Effort:** M. **Risk:** Med. **Confidence:** High (READ).

## SMS-013 / Delete the replaced IPU icon assets and unused unpacker / Category 1

- **Location(s):** Simple-Media-System/src/SMS_GUIcons.c:36-1368, 1388-1447; Simple-Media-System/src/SMS_IPU_1.c:220-324; Simple-Media-System/include/SMS_IPU.h:140; Simple-Media-System/src/SMS_PlayerBallSim.c:26, 57-63
- **Problem:** The active loader uses the RGBA blob, but 28 old icon arrays and six legacy lookup tables remain. IPU_UnpackImage has no caller, and the ball already uploads g_IconBallRGBA.
- **Fix:** Delete the old arrays/tables, unused unpacker/prototype/extern, and correct the obsolete ball comment. Keep IPU_LoadImage for desktop skins.
- **Benefit:** 19,230 declared image bytes +232 table bytes on EE, plus unused unpacker and ~1,438 source lines removable; actual linked savings unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-016 / Release old config-owned allocations on reload / Category 4

- **Location(s):** Simple-Media-System/src/SMS_Config.c:292-304, 319-320, 362-366, 674-675; Simple-Media-System/src/SMS_GS_2.c:494-506; Simple-Media-System/src/SMS_GUI.c:726, 766; Simple-Media-System/src/SMS_IOP.c:1569, 1591
- **Problem:** SMS_LoadConfig allocates new skin/MBF lists without disposing of the old ones on early retry/late reload. SMS_LoadSMBInfo destroys list nodes but does not free the SMBLoginInfo payloads; an oversized external font can also replace a prior heap font without freeing it.
- **Fix:** Clear/reuse existing lists instead of assigning new ones, free SMB payloads before node cleanup, and reuse an existing sufficiently large external-font buffer or free the replaced owned font.
- **Justification:** Use current ownership sites and list destroy calls; only minimal ownership knowledge for an external font is warranted by the cited replacement leak.
- **Benefit:** Eliminates repeated list/server/font leaks per reload; bytes vary with entries/fonts and are unmeasured.
- **Effort:** M. **Risk:** Med. **Confidence:** High (READ).

## SMS-015 / Replace the fixed device-start nop delays with bounded existing probes / Category 5

- **Location(s):** Simple-Media-System/src/SMS_IOP.c:649-659, 726-747, 795-804, 838-847, 1054-1071
- **Problem:** USB/MX4SIO/ATA/iLink initialization burns fixed nop loops even when a device is already ready; the synchronous menu caller cannot process input during them. iLink executes 12*0x1000000 iterations of four nops before any readiness check.
- **Fix:** Use the existing directory/readiness probes to exit as soon as ready, yielding between the bounded probes and checking cancel at that boundary. Retain only the discovery wait required by real hardware.
- **Justification:** Replacing existing waits with readiness/cancel checks directly addresses frozen UI and wasted CPU. Do not add retries after the existing maximum budget or another background layer.
- **Benefit:** Up to the full fixed settle budget avoided for already-ready devices; 0x14000000/0x30000000/0x18000000 nops in the cited five-/twelve-/six-pass loops (exact counts), ms unmeasured.
- **Effort:** M. **Risk:** Med. **Confidence:** High (READ).

## SMS-026 / Delete the broken QPel control and command option / Categories 6, 8

- **Location(s):** Simple-Media-System/tools/sms_converter/ffmpeg_utils.py:486-487; Simple-Media-System/tools/sms_converter/ui/advanced_settings.py:203-206,238,507,558,645.
- **Problem:** Selecting QPel emits an option FFmpeg does not accept. A local invocation using that exact option exited 8 with “Unrecognized option”; affected conversions fail before encoding.
- **Fix:** Delete the QPel checkbox, state/reset handling and emitted option. Presets already leave it off, and the UI advises against it for PS2 playback.
- **Benefit:** Real conversion failure fixed; roughly a dozen control/argument lines removed (INFERRED final count). No new setting or fallback.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ and local FFmpeg reproduction).

## SMS-027 / Keep normalized FLAC output at a rate the player decodes / Category 6

- **Location(s):** Simple-Media-System/tools/sms_converter/config.py:214-232; Simple-Media-System/tools/sms_converter/ffmpeg_utils.py:509-522; Simple-Media-System/src/SMS_FLAC.c:349-359.
- **Problem:** The FLAC preset leaves output rate unspecified. Adding normalization produced 192,000-Hz FLAC from a 44,100-Hz input locally; SMS rejects frame rate codes 1–3, including 192 kHz.
- **Fix:** When normalization is enabled with preserve-rate FLAC, explicitly reuse the already-probed source rate as output rate, or the existing selected rate. Do not add another preset or option.
- **Justification:** Reusing available metadata fixes the demonstrated converter/player mismatch with a small conditional, avoiding decoder changes.
- **Benefit:** Prevents unsupported normalized output. File-size/time deltas are unmeasured and INFERRED to depend on input and encoder.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; local FFmpeg/FFprobe confirmed 192,000 Hz; no PS2 playback test).

## SMS-029 / Inspect queued files with one active worker / Categories 3, 4, 5

- **Location(s):** Simple-Media-System/tools/sms_converter/ui/main_window.py:292-319; Simple-Media-System/tools/sms_converter/worker.py:34-46; Simple-Media-System/tools/sms_converter/ffmpeg_utils.py:109-128.
- **Problem:** A batch immediately starts one QThread and FFprobe process per file. Active processes and captured outputs grow with the whole batch despite an existing ordered queue.
- **Fix:** Start the next inspection when the current one finishes, with one active worker. Delete redundant per-file active/retired-worker bookkeeping; add no thread pool or scheduler.
- **Justification:** Reusing the queue/completion signal removes unbounded process fan-out and ownership code with a small next-item dispatch.
- **Benefit:** N simultaneous inspection threads/processes become one. RAM/time effects are workload-dependent and INFERRED; no throughput benchmark.
- **Effort:** M. **Risk:** Med. **Confidence:** High (READ for fan-out; resource effects INFERRED).

## SMS-008 / Preserve the ASF reassembly buffer when realloc fails / Category 4

- **Location(s):** Simple-Media-System/src/SMS_ContainerASF.c:528-555, 637-642
- **Problem:** pkt.data is overwritten directly by realloc and pkt.alloc is updated before success. A failed larger allocation loses the old reassembly buffer permanently; continuing malformed objects can repeatedly leak it.
- **Fix:** Assign realloc to a temporary and commit pointer/capacity only on success; otherwise end the failed object using existing cleanup.
- **Justification:** One temporary pointer prevents a direct realloc ownership bug and avoids retries/backups.
- **Benefit:** Prevents loss of the previous buffer, up to the previously allocated media-object size per failure; exact run savings unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-019 / Bound history loading to the history format actually written / Category 6

- **Location(s):** Simple-Media-System/src/SMS_History.c:20, 41-50, 78-87, 97-105, 133-141
- **Problem:** History saving caps the list at 32, but all three loading branches read an unlimited number of untrusted length-prefixed records and ignore short path/PTS reads. A corrupt file can exhaust EE memory or create bogus resume records.
- **Fix:** Stop after 32 complete records, validate the declared record fits the remaining input, and discard an incomplete final record using the existing list cleanup.
- **Justification:** Two format constraints follow directly from HIST_SIZE and the existing wire record, preventing data-dependent allocations; no new cap option or parser layer.
- **Benefit:** Bounds retained history to 32 entries and avoids bogus records/low-memory failure; normal-file work unchanged.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-020 / Write the persisted config prefix rather than runtime pointers / Category 3

- **Location(s):** Simple-Media-System/include/SMS_Config.h:139-143; Simple-Media-System/src/SMS_Config.c:700, 730, 941-942, 1066-1068
- **Problem:** Loading consumes 4+892 persisted bytes, but saving writes sizeof(g_Config), including its three process-local list pointers. Those trailing addresses have no meaning across boots.
- **Fix:** Write the same persisted prefix the reader consumes, excluding the three list pointers.
- **Benefit:** 12 fewer bytes written per save on EE; no whole memory-card allocation-unit saving claimed. Removes meaningless persisted pointer values.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-017 / Use the existing icon writer for both save paths / Category 2

- **Location(s):** Simple-Media-System/src/SMS_Config.c:803-876, 989-1060
- **Problem:** Both the helper and the legacy inline branch build identical browser-icon structures and write them through fio. The comment justifying duplication as a libmc difference contradicts the actual fio calls in both branches.
- **Fix:** Call the existing _write_mc_icon with the appropriate directory from the fixed-card save and delete the inline copy plus duplicate static lighting/background data.
- **Justification:** The helper already exists and there are two copies of the same logic; consolidating removes code and data. Verify the fixed-card path spelling on hardware.
- **Benefit:** About 70 source lines and duplicate 176 bytes of static icon parameters removable; linked size unmeasured.
- **Effort:** S. **Risk:** Med. **Confidence:** High (READ).

## SMS-018 / Remove double-open asset probes / Category 5

- **Location(s):** Simple-Media-System/src/SMS_Config.c:259-274, 278-286, 433-435, 1121; Simple-Media-System/src/SMS_History.c:35-37; Simple-Media-System/src/SMS_Locale.c:830
- **Problem:** SMS_ConfigAssetPath opens/closes an asset merely to say it exists, after which callers immediately open it again. Every hit adds needless device RPC/card or network I/O and creates a change-between-opens window.
- **Fix:** Return the opened descriptor from the existing asset function and let callers consume it, retaining the already existing fallback only on open failure.
- **Justification:** Change one existing helper contract used in multiple places; no new helper or fallback. Net fewer calls and less duplicated open logic.
- **Benefit:** One open+close pair removed per successful asset lookup; exact latency unmeasured.
- **Effort:** M. **Risk:** Med. **Confidence:** High (READ).

## SMS-021 / Delete the unused assembly round-rectangle implementation / Category 1

- **Location(s):** Simple-Media-System/src/SMS_GS_0.S:37-42, 60-61, 827-1075; Simple-Media-System/include/SMS_GS.h:1274; Simple-Media-System/src/SMS_GS_1.c:620-717
- **Problem:** The C GS_RenderRoundRect implementation replaced the assembly path. Searches across tracked runtime/build/test sources find GS_RRV/GS_RenderRoundRect_asm only at their definitions/prototype and a comment; _gs_rrv is internal to the dead pair.
- **Fix:** Delete the two assembly functions, their private sine table, exports/prototype and obsolete replacement comment.
- **Benefit:** 249 assembly-function lines plus sine table/exports removable; linked text delta unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-022 / Compile release breadcrumbs out at their call sites / Category 1

- **Location(s):** Simple-Media-System/src/SMS_IOP.c:272-315, 348-510
- **Problem:** SMS_ExitCrumb has an empty release body, but CRUMB still emits external calls and string arguments. The nearby DIAG_CRUMB already avoids this by expanding to nothing outside SMS_DIAG.
- **Fix:** Make CRUMB use the same SMS_DIAG conditional as DIAG_CRUMB; retain the afExit gate only in diagnostics.
- **Benefit:** Release-only calls/string arguments eliminated; exact linked byte count unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-023 / Size the probe function array by entries / Category 4

- **Location(s):** Simple-Media-System/src/SMS_Container.c:45-60, 148-165
- **Problem:** lCC uses sizeof(s_CCreator) as an element count, allocating four times the needed number of function pointers on EE. Only sizeof(s_CCreator) bytes are populated and read.
- **Fix:** Divide by sizeof(s_CCreator[0]) in the array bound, matching the loop bounds already below it.
- **Benefit:** 156 bytes less per-call stack on EE: 13 entries*4 bytes needed versus 52 entries*4 currently.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-024 / Delete the unused XZ variable-length integer encoder / Category 1

- **Location(s):** Simple-Media-System/src/lzma2.c:9-26
- **Problem:** The XZ helper contains an exported encode function, but runtime/build/test source searches find no call. The application only decompresses its embedded XZ assets.
- **Fix:** Delete encode; retain the decoder used by the size reader.
- **Benefit:** 18 source lines removable; linked bytes unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## SMS-025 / Remove the unused packet-read remainder calculation / Category 1

- **Location(s):** Simple-Media-System/src/SMS_Container.c:319-322
- **Problem:** SMSContainer_DefReadPacket calculates/clamps lnRead, then ignores it and passes lPackSize. The unused local obscures whether short-packet handling is intentional.
- **Fix:** Delete the unused local/calculation if the current full-packet read contract is retained.
- **Benefit:** 2 source lines removed; compiler likely already eliminates their runtime work (INFERRED).
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## Coverage and unfinished work

**Partial audit.** 580 source/header/script/build/workflow/web-source paths were inventoried; 33 were fully read and 22 have recorded partial reads. Two reviewer interruptions and automated filtering prevented completing the whole repository. Running a test or hashing a file is not counted as source review.

Remaining work spans all eight categories: unread codecs/assembly, IOP network/storage drivers, headers, converter/tooling, documentation/site generators, and unresolved reference ancestry. Binary/media assets were inventoried, not reverse-engineered. Sensitive material was not printed.

Exact durable coverage will be available in `coverage/Codex-Simple-Media-System-coverage.json`.

<details><summary>Exact unfinished source paths and unread line ranges</summary>

```text
.github/workflows/sms-converter.yml — unread 171-327
docs-site/build.py — not read
docs-site/content/audio.html — not read
docs-site/content/building.html — not read
docs-site/content/cd-dvd.html — not read
docs-site/content/configuration.html — not read
docs-site/content/controls.html — not read
docs-site/content/converter.html — not read
docs-site/content/credits.html — not read
docs-site/content/developers.html — not read
docs-site/content/devices.html — not read
docs-site/content/getting-started.html — not read
docs-site/content/hdd.html — not read
docs-site/content/ilink.html — not read
docs-site/content/index.html — not read
docs-site/content/install.html — not read
docs-site/content/known-issues.html — not read
docs-site/content/languages.html — not read
docs-site/content/legacy-manual.html — not read
docs-site/content/mmce.html — not read
docs-site/content/mx4sio.html — not read
docs-site/content/network.html — not read
docs-site/content/pictures.html — not read
docs-site/content/releases.html — not read
docs-site/content/settings.html — not read
docs-site/content/smb.html — not read
docs-site/content/subtitles.html — not read
docs-site/content/themes.html — not read
docs-site/content/troubleshooting.html — not read
docs-site/content/usb.html — not read
docs-site/content/video.html — not read
docs-site/content/wiki.html — not read
docs-site/static/404.html — not read
docs-site/static/assets/app.js — not read
docs-site/static/assets/orbs.js — not read
docs-site/static/assets/sms.css — not read
docs-site/static/assets/style.css — not read
docs-site/sync_wiki.py — not read
docs/404.html — not read
docs/Makefile — not read
docs/assets/app.js — not read
docs/assets/orbs.js — not read
docs/assets/sms.css — not read
docs/assets/style.css — not read
docs/audio.html — not read
docs/building.html — not read
docs/cd-dvd.html — not read
docs/configuration.html — not read
docs/configure — not read
docs/controls.html — not read
docs/converter.html — not read
docs/credits.html — not read
docs/data/search-index.js — not read
docs/developers.html — not read
docs/devices.html — not read
docs/getting-started.html — not read
docs/hdd.html — not read
docs/ilink.html — not read
docs/index.html — not read
docs/install.html — not read
docs/investigations/2026-11-11-handoff/scripts/host-tests.sh — not read
docs/investigations/2026-11-11-handoff/scripts/ps2-build.sh — not read
docs/known-issues.html — not read
docs/languages.html — not read
docs/legacy-manual.html — not read
docs/mmce.html — not read
docs/mx4sio.html — not read
docs/network.html — not read
docs/pictures.html — not read
docs/releases.html — not read
docs/settings.html — not read
docs/smb.html — not read
docs/src/installation/requirements.xml — not read
docs/stylesheets/default.css — not read
docs/subtitles.html — not read
docs/themes.html — not read
docs/troubleshooting.html — not read
docs/usb.html — not read
docs/video.html — not read
docs/wiki.html — not read
include/SMS.h — not read
include/SMS_AAC.h — not read
include/SMS_AC3.h — not read
include/SMS_Artwork.h — not read
include/SMS_Bitio.h — not read
include/SMS_CDDA.h — not read
include/SMS_CDVD.h — not read
include/SMS_Codec.h — not read
include/SMS_Container.h — not read
include/SMS_ContainerAAC.h — not read
include/SMS_ContainerAC3.h — not read
include/SMS_ContainerASF.h — not read
include/SMS_ContainerAVI.h — not read
include/SMS_ContainerFLAC.h — not read
include/SMS_ContainerJPG.h — not read
include/SMS_ContainerM3U.h — not read
include/SMS_ContainerMOV.h — not read
include/SMS_ContainerMP3.h — not read
include/SMS_ContainerMPEG_PS.h — not read
include/SMS_ContainerOGG.h — not read
include/SMS_DMA.h — not read
include/SMS_DSP.h — not read
include/SMS_DTS.h — not read
include/SMS_DXSB.h — not read
include/SMS_DateTime.h — not read
include/SMS_DirTree.h — not read
include/SMS_EE.h — not read
include/SMS_FLAC.h — not read
include/SMS_FileDir.h — not read
include/SMS_FileMapping.h — not read
include/SMS_FourCC.h — not read
include/SMS_GS.h — unread 1-1273,1275-1298,1301-1314
include/SMS_GUI.h — not read
include/SMS_GUIClock.h — not read
include/SMS_GUIMenu.h — not read
include/SMS_GUIcons.h — not read
include/SMS_H263.h — not read
include/SMS_History.h — not read
include/SMS_INTC.h — not read
include/SMS_IOP.h — not read
include/SMS_IPU.h — unread 1-139,141-145
include/SMS_JPEG.h — not read
include/SMS_List.h — not read
include/SMS_Locale.h — not read
include/SMS_MC.h — not read
include/SMS_MP123.h — not read
include/SMS_MPEG.h — not read
include/SMS_MPEG12.h — not read
include/SMS_MPEG4.h — not read
include/SMS_MSMPEG4.h — not read
include/SMS_OGG.h — not read
include/SMS_OS.h — not read
include/SMS_PAD.h — not read
include/SMS_PCM.h — not read
include/SMS_PgInd.h — not read
include/SMS_Player.h — not read
include/SMS_PlayerBallSim.h — not read
include/SMS_PlayerControl.h — not read
include/SMS_PlayerMenu.h — not read
include/SMS_RC.h — not read
include/SMS_Rescale.h — not read
include/SMS_RingBuffer.h — not read
include/SMS_SIF.h — not read
include/SMS_SMB.h — not read
include/SMS_SPU.h — not read
include/SMS_Sounds.h — not read
include/SMS_Spectrum.h — not read
include/SMS_SubtitleContext.h — not read
include/SMS_Timer.h — not read
include/SMS_VIF.h — not read
include/SMS_VLC.h — not read
include/SMS_VSync.h — not read
include/SMS_VideoBuffer.h — not read
include/SMS_ioctl.h — not read
include/libds34bt.h — not read
include/libds34usb.h — not read
include/libmpeg.h — not read
include/libmpeg_internal.h — not read
include/lzma2.h — not read
include/mbstring.h — not read
include/s_iop_image.h — not read
include/xz.h — not read
include/xz_config.h — not read
include/xz_lzma2.h — not read
include/xz_private.h — not read
include/xz_stream.h — not read
iop/SMSCDVD/Makefile — not read
iop/SMSCDVD/SMSCDVD.c — not read
iop/SMSCDVD/SMSCDVD.h — not read
iop/SMSCDVD/SMSCDVD_UDFS.c — not read
iop/SMSCDVD/irx_imports.h — not read
iop/SMSDev9/Makefile — not read
iop/SMSDev9/include/dev9.h — not read
iop/SMSDev9/src/irx_imports.h — not read
iop/SMSDev9/src/ps2dev9.c — not read
iop/SMSMAP/Makefile — not read
iop/SMSMAP/irx_imports.h — not read
iop/SMSMAP/main.c — not read
iop/SMSMAP/smap.c — not read
iop/SMSMAP/smap.h — not read
iop/SMSMAP/smap_opt.s — not read
iop/SMSPWROFF/Makefile — not read
iop/SMSPWROFF/include/poweroff.h — not read
iop/SMSPWROFF/src/irx_imports.h — not read
iop/SMSPWROFF/src/poweroff.c — not read
iop/SMSSMB/Makefile — not read
iop/SMSSMB/src/SMSMB.c — not read
iop/SMSSMB/src/ps2smb.c — not read
iop/SMSSMB/src/smsutils.h — not read
iop/SMSTCPIP/Makefile — not read
iop/SMSTCPIP/include/arch/cc.h — not read
iop/SMSTCPIP/include/arch/sys_arch.h — not read
iop/SMSTCPIP/include/irx_imports.h — not read
iop/SMSTCPIP/include/lwip/api.h — not read
iop/SMSTCPIP/include/lwip/api_msg.h — not read
iop/SMSTCPIP/include/lwip/arch.h — not read
iop/SMSTCPIP/include/lwip/debug.h — not read
iop/SMSTCPIP/include/lwip/def.h — not read
iop/SMSTCPIP/include/lwip/dhcp.h — not read
iop/SMSTCPIP/include/lwip/err.h — not read
iop/SMSTCPIP/include/lwip/icmp.h — not read
iop/SMSTCPIP/include/lwip/inet.h — not read
iop/SMSTCPIP/include/lwip/ip.h — not read
iop/SMSTCPIP/include/lwip/ip_addr.h — not read
iop/SMSTCPIP/include/lwip/ip_frag.h — not read
iop/SMSTCPIP/include/lwip/mem.h — not read
iop/SMSTCPIP/include/lwip/memp.h — not read
iop/SMSTCPIP/include/lwip/netif.h — not read
iop/SMSTCPIP/include/lwip/opt.h — not read
iop/SMSTCPIP/include/lwip/pbuf.h — not read
iop/SMSTCPIP/include/lwip/raw.h — not read
iop/SMSTCPIP/include/lwip/snmp.h — not read
iop/SMSTCPIP/include/lwip/sockets.h — not read
iop/SMSTCPIP/include/lwip/stats.h — not read
iop/SMSTCPIP/include/lwip/sys.h — not read
iop/SMSTCPIP/include/lwip/tcp.h — not read
iop/SMSTCPIP/include/lwip/tcpip.h — not read
iop/SMSTCPIP/include/lwip/udp.h — not read
iop/SMSTCPIP/include/lwipopts.h — not read
iop/SMSTCPIP/include/netif/etharp.h — not read
iop/SMSTCPIP/include/netif/loopif.h — not read
iop/SMSTCPIP/include/ps2ip_internal.h — not read
iop/SMSTCPIP/src/api_lib.c — not read
iop/SMSTCPIP/src/api_msg.c — not read
iop/SMSTCPIP/src/etharp.c — not read
iop/SMSTCPIP/src/icmp.c — not read
iop/SMSTCPIP/src/inet.s — not read
iop/SMSTCPIP/src/ip.c — not read
iop/SMSTCPIP/src/ip_addr.c — not read
iop/SMSTCPIP/src/ip_frag.c — not read
iop/SMSTCPIP/src/loopif.c — not read
iop/SMSTCPIP/src/mem.c — not read
iop/SMSTCPIP/src/memp.c — not read
iop/SMSTCPIP/src/netif.c — not read
iop/SMSTCPIP/src/pbuf.c — not read
iop/SMSTCPIP/src/ps2ip.c — not read
iop/SMSTCPIP/src/sockets.c — not read
iop/SMSTCPIP/src/tcp.c — not read
iop/SMSTCPIP/src/tcp_in.c — not read
iop/SMSTCPIP/src/tcp_out.c — not read
iop/SMSTCPIP/src/tcpip.c — not read
iop/SMSTCPIP/src/udp.c — not read
iop/SMSUMS/Makefile — not read
iop/SMSUMS/include/smsutils.h — not read
iop/SMSUMS/include/ums.h — not read
iop/SMSUMS/include/ums_cache.h — not read
iop/SMSUMS/include/ums_driver.h — not read
iop/SMSUMS/include/ums_fat.h — not read
iop/SMSUMS/src/ums.c — not read
iop/SMSUMS/src/ums_cache.c — not read
iop/SMSUMS/src/ums_driver.c — not read
iop/SMSUMS/src/ums_fat.c — not read
iop/SMSUMS/src/ums_imports.c — not read
iop/SMSUdpfs/common/include/cdvdman_config.h — not read
iop/SMSUdpfs/common/include/eecore_config.h — not read
iop/SMSUdpfs/common/include/fakemod_config.h — not read
iop/SMSUdpfs/common/include/fhi.h — not read
iop/SMSUdpfs/common/include/fhi_bd_config.h — not read
iop/SMSUdpfs/common/include/fhi_fileid_config.h — not read
iop/SMSUdpfs/common/include/module_config.h — not read
iop/SMSUdpfs/common/mprintf.h — not read
iop/SMSUdpfs/ministack/Makefile — not read
iop/SMSUdpfs/ministack/include/main.h — not read
iop/SMSUdpfs/ministack/include/ministack_arp.h — not read
iop/SMSUdpfs/ministack/include/ministack_eth.h — not read
iop/SMSUdpfs/ministack/include/ministack_ip.h — not read
iop/SMSUdpfs/ministack/include/ministack_udp.h — not read
iop/SMSUdpfs/ministack/include/mprintf.h — not read
iop/SMSUdpfs/ministack/include/mstack.h — not read
iop/SMSUdpfs/ministack/include/stdint.h — not read
iop/SMSUdpfs/ministack/include/udptty.h — not read
iop/SMSUdpfs/ministack/src/irx_imports.h — not read
iop/SMSUdpfs/ministack/src/main.c — not read
iop/SMSUdpfs/ministack/src/ministack_arp.c — not read
iop/SMSUdpfs/ministack/src/ministack_eth.c — not read
iop/SMSUdpfs/ministack/src/ministack_ip.c — not read
iop/SMSUdpfs/ministack/src/ministack_udp.c — not read
iop/SMSUdpfs/ministack/src/udptty.c — not read
iop/SMSUdpfs/smap/Makefile — not read
iop/SMSUdpfs/smap/include/dev9.h — not read
iop/SMSUdpfs/smap/include/irx_imports.h — not read
iop/SMSUdpfs/smap/include/main.h — not read
iop/SMSUdpfs/smap/include/smap.h — not read
iop/SMSUdpfs/smap/include/stdint.h — not read
iop/SMSUdpfs/smap/include/xfer.h — not read
iop/SMSUdpfs/smap/src/main.c — not read
iop/SMSUdpfs/smap/src/smap.c — not read
iop/SMSUdpfs/smap/src/xfer.c — not read
iop/SMSUdpfs/udpfs/Makefile — not read
iop/SMSUdpfs/udpfs/include/main.h — not read
iop/SMSUdpfs/udpfs/include/stdint.h — not read
iop/SMSUdpfs/udpfs/src/irx_imports.h — not read
iop/SMSUdpfs/udpfs/src/main.c — not read
iop/SMSUdpfs/udpfs/src/udpfs_bd.c — not read
iop/SMSUdpfs/udpfs/src/udpfs_core.c — not read
iop/SMSUdpfs/udpfs/src/udpfs_core.h — not read
iop/SMSUdpfs/udpfs/src/udpfs_fhi.c — not read
iop/SMSUdpfs/udpfs/src/udpfs_ioman.c — not read
iop/SMSUdpfs/udpfs/src/udpfs_packet.h — not read
iop/SMSUdpfs/udpfs/src/udprdma.c — not read
iop/SMSUdpfs/udpfs/src/udprdma.h — not read
iop/SMSUdpfs/udpfs/src/udprdma_packet.h — not read
iop/USBD/Makefile — not read
iop/USBD/include/usbd.h — not read
iop/USBD/include/usbd_macro.h — not read
iop/USBD/src/driver.c — not read
iop/USBD/src/driver.h — not read
iop/USBD/src/hcd.c — not read
iop/USBD/src/hcd.h — not read
iop/USBD/src/hub.c — not read
iop/USBD/src/hub.h — not read
iop/USBD/src/interface.c — not read
iop/USBD/src/irx_imports.h — not read
iop/USBD/src/mem.c — not read
iop/USBD/src/mem.h — not read
iop/USBD/src/usbd.c — not read
iop/USBD/src/usbdpriv.h — not read
iop/USBD/src/usbio.c — not read
iop/USBD/src/usbio.h — not read
iop/smbman-sms/Makefile — not read
iop/smbman-sms/include/ps2smb.h — not read
iop/smbman-sms/prepare_module.py — not read
iop/smbman-sms/src/auth.c — not read
iop/smbman-sms/src/auth.h — not read
iop/smbman-sms/src/debug.h — not read
iop/smbman-sms/src/des.c — not read
iop/smbman-sms/src/des.h — not read
iop/smbman-sms/src/irx_imports.h — not read
iop/smbman-sms/src/md4.c — not read
iop/smbman-sms/src/md4.h — not read
iop/smbman-sms/src/poll.c — not read
iop/smbman-sms/src/poll.h — not read
iop/smbman-sms/src/smb.c — not read
iop/smbman-sms/src/smb.h — not read
iop/smbman-sms/src/smb_fio.c — not read
iop/smbman-sms/src/smb_fio.h — not read
iop/smbman-sms/src/smbman.c — not read
iop/smbman-sms/src/sms_cp1251.h — not read
iop/smbman-sms/src/sms_path.h — not read
iop/smbman-sms/tests/cp1251_bridge.c — not read
iop/smbman-sms/tests/smb_regressions.c — not read
iop/smbman-sms/tests/test_cp1251.py — not read
iop/smbman-sms/tests/test_smb_regressions.py — not read
src/About.c — not read
src/About_Data.s — not read
src/SMS_AAC.c — not read
src/SMS_AC3.c — not read
src/SMS_AC3_imdct.c — not read
src/SMS_BallRGBA.c — not read
src/SMS_CDDA.c — not read
src/SMS_CDVD.c — not read
src/SMS_Codec.c — not read
src/SMS_ConfigIcon.c — not read
src/SMS_ContainerAC3.c — not read
src/SMS_ContainerAVI.c — not read
src/SMS_ContainerFLAC.c — not read
src/SMS_ContainerJPG.c — not read
src/SMS_ContainerMOV.c — not read
src/SMS_ContainerMPEG_PS.c — not read
src/SMS_ContainerOGG.c — not read
src/SMS_DMA_0.s — not read
src/SMS_DSP.c — not read
src/SMS_DSP_FFT.S — not read
src/SMS_DSP_MMI.S — not read
src/SMS_DSP_QPel.S — not read
src/SMS_DTS.c — not read
src/SMS_DXSB.c — not read
src/SMS_Data.c — unread 1-19,21-5479,5481-6014,6016-12411,12413-13642,13644-16728
src/SMS_DateTime.c — not read
src/SMS_EE.c — not read
src/SMS_FLAC.c — unread 1-324,371-594
src/SMS_FileDir.c — not read
src/SMS_GSFont.c — unread 1-2184
src/SMS_GS_0.S — unread 1-27,66-826,1076-1180
src/SMS_GS_1.c — unread 1-607
src/SMS_GS_2.c — unread 1-469,526-590
src/SMS_GUI.c — unread 1-639,851-1054
src/SMS_GUIClock.c — not read
src/SMS_GUIDesktop.c — not read
src/SMS_GUIDevMenu.c — not read
src/SMS_GUIFileCtxMenu.c — not read
src/SMS_GUIFileMenu.c — unread 1-849,1161-1662
src/SMS_GUIMenu.c — not read
src/SMS_GUIMenuSMS.c — unread 1-1409,1466-3052
src/SMS_GUIMiniBrowser.c — not read
src/SMS_GUISMBrowser.c — unread 1-539,580-779,805-875
src/SMS_GUIcons.c — unread 1-13,43-1319
src/SMS_GUInfoPanel.c — not read
src/SMS_H263.c — not read
src/SMS_IPU.c — not read
src/SMS_IPU_0.s — not read
src/SMS_IconsRGBA.c — unread 1-1746
src/SMS_InverseCodePages.c — not read
src/SMS_JPEG.c — not read
src/SMS_JPEGData.c — not read
src/SMS_LoadingRGBA.c — not read
src/SMS_Locale.c — unread 1-829
src/SMS_MC.c — not read
src/SMS_MP123.c — not read
src/SMS_MP123Core.S — not read
src/SMS_MPEG.c — not read
src/SMS_MPEG12.c — not read
src/SMS_MPEG4.c — not read
src/SMS_MPEGInit.c — not read
src/SMS_MSMPEG4.c — not read
src/SMS_Menu.c — not read
src/SMS_OGG.c — not read
src/SMS_OS.c — not read
src/SMS_PAD.c — not read
src/SMS_PCM.c — not read
src/SMS_PgInd.c — not read
src/SMS_Player.c — unread 1-1099,1451-1899
src/SMS_PlayerControl.c — not read
src/SMS_PlayerMenu.c — not read
src/SMS_RC.c — not read
src/SMS_RC_0.s — not read
src/SMS_Rescale.c — not read
src/SMS_RingBuffer.c — not read
src/SMS_SIF.c — not read
src/SMS_SPU.c — not read
src/SMS_Sounds.c — not read
src/SMS_Spectrum.c — not read
src/SMS_SubtitleContext.c — not read
src/SMS_Timer.s — not read
src/SMS_Utils.S — not read
src/SMS_VLC.c — not read
src/SMS_VSync.c — not read
src/SMS_VideoBuffer.c — not read
src/SMS_WMA.c — not read
src/SMS_WMA.h — not read
src/libds34bt.c — not read
src/libds34usb.c — not read
src/libmpeg.c — not read
src/libmpeg_core.S — not read
src/mbstring.c — not read
src/xz_crc32.c — not read
src/xz_dec_lzma2.c — not read
src/xz_dec_stream.c — not read
tools/Dockerfile.ipu — not read
tools/bake_icons.sh — not read
tools/bake_icons_rgba.py — not read
tools/bake_loading_rgba.py — not read
tools/build-docs-search-index.mjs — not read
tools/build-smbman.sh — not read
tools/build_ata_bd_dev9v11.sh — not read
tools/build_bdmfs_fatfs.sh — not read
tools/build_libsd.sh — not read
tools/build_udpfs.sh — not read
tools/check_devmenu.py — not read
tools/compress_irx.py — not read
tools/fatfs_names_harness.c — not read
tools/gen-test-media.sh — not read
tools/irx_imports.py — not read
tools/libsd/freesd.c — not read
tools/libsd/voice.c — not read
tools/mpeg_color_probe/Makefile — not read
tools/mpeg_color_probe/compare.py — not read
tools/mpeg_color_probe/compare_series.py — not read
tools/mpeg_color_probe/generate_series.py — not read
tools/mpeg_color_probe/main.c — not read
tools/mpeg_color_probe/pool.c — not read
tools/mpeg_motion_probe/Makefile — not read
tools/mpeg_motion_probe/main.c — not read
tools/package_sas.py — not read
tools/ps2_kernel_shim.h — not read
tools/sms_converter/app.py — not read
tools/sms_converter/config.py — unread 1-211,238-359
tools/sms_converter/crash_log.py — not read
tools/sms_converter/ffmpeg_utils.py — unread 1-64,133-159,191-419,556-606
tools/sms_converter/main.py — not read
tools/sms_converter/qt_compat.py — not read
tools/sms_converter/requirements-win7.txt — not read
tools/sms_converter/test_converter.py — not read
tools/sms_converter/test_end_to_end.py — not read
tools/sms_converter/test_file_size.py — not read
tools/sms_converter/test_geometry.py — not read
tools/sms_converter/test_multitrack.py — not read
tools/sms_converter/ui/__init__.py — not read
tools/sms_converter/ui/advanced_settings.py — unread 1-192,242-651
tools/sms_converter/ui/details_dialog.py — not read
tools/sms_converter/ui/drop_zone.py — not read
tools/sms_converter/ui/main_window.py — unread 141-204,331-499
tools/sms_converter/ui/preset_selector.py — not read
tools/sms_converter/ui/queue_table.py — not read
tools/sms_converter/ui/setup_dialog.py — not read
tools/test_aac_sample_rate.py — not read
tools/test_artwork_poster.py — not read
tools/test_artwork_sidecar_filter.py — not read
tools/test_audio_formats.py — unread 91-270
tools/test_avi_parser.py — not read
tools/test_bdmfs_fatfs_module.py — not read
tools/test_boot_config.py — not read
tools/test_browser_artwork.py — not read
tools/test_browser_artwork_lifecycle.py — not read
tools/test_browser_open_allocation.py — not read
tools/test_browser_path_bounds.py — not read
tools/test_browser_reload.py — not read
tools/test_cdda_stream_failure.py — not read
tools/test_check_devmenu.py — not read
tools/test_container_probe.py — not read
tools/test_converter_publication.py — not read
tools/test_copy_file.py — not read
tools/test_ctxmenu_import.py — not read
tools/test_directory_path_bounds.py — not read
tools/test_display_limits.py — not read
tools/test_ee_helpers.py — not read
tools/test_file_skip.py — not read
tools/test_file_string.py — not read
tools/test_frame_buffer_allocation.py — not read
tools/test_io_diagnostics.py — not read
tools/test_ipconfig.py — not read
tools/test_jpeg_parser.py — not read
tools/test_jpeg_pipeline_failure.py — not read
tools/test_language_packs.py — not read
tools/test_m3u_probe.py — not read
tools/test_mov_index.py — not read
tools/test_mov_packets.py — not read
tools/test_mov_parser.py — not read
tools/test_mov_sample_sizes.py — not read
tools/test_mpeg12_frame_lifetime.py — not read
tools/test_mpeg4_init_allocation.py — not read
tools/test_mpeg_color_feed.py — not read
tools/test_mpeg_motion_vectors.py — not read
tools/test_mpeg_ps_probe.py — not read
tools/test_mpeg_skipped_motion.py — not read
tools/test_player_hardware_failure.py — not read
tools/test_player_pulldown.py — not read
tools/test_player_scrollbar_seek.py — not read
tools/test_player_video_drain.py — not read
tools/test_playlist_menu.py — not read
tools/test_poster_typography.py — not read
tools/test_rescale_allocation.py — not read
tools/test_rolling_release.py — not read
tools/test_sas_package.py — not read
tools/test_skin_loading.py — not read
tools/test_stio_device_reads.py — not read
tools/test_stio_refill.py — not read
tools/test_stio_stream_failure.py — not read
tools/test_stio_usb_readahead.py — not read
tools/test_stream_allocation.py — not read
tools/test_stream_rebuffer.py — not read
tools/test_utf8_display.py — not read
tools/tktagmedia-recommended-dragndrop-converter.bat — not read
utils/Loader/Makefile — not read
utils/Loader/loader.c — not read
vu/build.sh — not read
vu/clean.sh — not read
```

</details>

## Durable continuation manifest

[Exact coverage and remaining paths](coverage/Codex-Simple-Media-System-coverage.json): 34 whole-file reads; 22 paths with recorded partial evidence; 978 paths require further review or explicit binary/document exclusion. This is a tracked-file count, not a claim that binary assets can be source-audited.
