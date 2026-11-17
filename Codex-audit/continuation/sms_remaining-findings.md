# Simple-Media-System remaining-scope audit

Read-only continuation at b9a5c882d6d632914faa4ff8dc080f1ecd51bfd7. Findings supplement SMS-001–029; no source changes.

## SMS-100 / Resolve module build paths from the checkout root / Category 7

- **Location(s):** Simple-Media-System/tools/build_udpfs.sh:33-35,43-46,68; Simple-Media-System/tools/build_ata_bd_dev9v11.sh:34-38.
- **Problem:** Both scripts walk above the checkout and append the old literal `SMS-v1` directory name. A normal clone named `Simple-Media-System` therefore mounts nonexistent source/output locations and cannot rebuild the embedded modules, despite the UDPFS script promising to run from anywhere.
- **Simplest fix:** Derive this checkout's root from `tools/..` and use its `iop`, `irx` and `tools` subpaths directly; retain an explicit source input only where the ATA build actually needs the separately supplied SDK tree.
- **Benefit:** Repairs reproducible module builds from normally named checkouts and deletes the repeated old directory assumption; byte/time savings INFERRED, unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-101 / Make the claimed libsd export gate an actual check / Categories 7, 8

- **Location(s):** Simple-Media-System/tools/build_libsd.sh:19-30,77-79; Simple-Media-System/tools/irx_imports.py:27-45,48-51,90-119.
- **Problem:** The build invokes an unsupported `--exports` argument, then falls back to a plain table dump. Neither invocation validates libsd's export version or required non-stub ordinals; the parser explicitly returns no ordinals for export tables, so the documented ABI gate always permits an incompatible successfully parsed module.
- **Simplest fix:** In the existing parser, decode the export table slots and support a direct assertion for the one libsd version/ordinal set needed here; replace the failed-command fallback with that assertion.
- **Justification:** This completes an existing advertised build assertion that guards known ordinal-sensitive audio imports; no new wrapper, retry or framework is needed.
- **Benefit:** Prevents publishing an embedded audio module that passes a print-only gate but cannot satisfy AUDSRV; failure consequence INFERRED from binding contract, no console run.
- **Effort:** M. **Risk:** Low. **Confidence:** READ.

## SMS-102 / Delete the abandoned alternate IOP image / Category 1

- **Location(s):** Simple-Media-System/include/s_iop_image.h:1-3820; Simple-Media-System/src/SMS_IOP.c:228,437.
- **Problem:** The 61,005-byte image has no live include or consumer; the only two references are commented-out experiments in the reset path.
- **Simplest fix:** Delete this header and its two obsolete commented references.
- **Benefit:** Measured 373,784 repository bytes and 3,820 source lines removed; no linked ELF or runtime RAM reduction claimed because the header is already unused.
- **Effort:** S. **Risk:** Low. **Confidence:** READ (full byte literal structure parsed; payload semantics not claimed).

## SMS-103 / Replace alignment repair by one aligned allocate-copy-free / Categories 3, 6

- **Location(s):** Simple-Media-System/src/SMS_EE.c:55-87; Simple-Media-System/src/SMS_GS_1.c:213-215,315-317,338-340; Simple-Media-System/src/SMS_GUIDesktop.c:835.
- **Problem:** SMS_ReallocWithAlign can perform two reallocations followed by a separate aligned allocation. It overwrites the only pointer before checking realloc failure, and its second realloc result is used by memcpy without a NULL check; low-memory growth can leak the old buffer or copy from NULL.
- **Simplest fix:** Keep the existing sufficiently-large early return; for growth allocate the final aligned block once, copy the old used capacity only after success, then free the old block. Update pointer/capacity only on success and use the existing caller failure boundary.
- **Justification:** This replaces the three-operation alignment repair with one existing allocator and removes branches; no allocator layer is added.
- **Benefit:** Up to two realloc calls removed per misaligned growth, with fewer copies and invalid failure paths; allocator timing and RAM change INFERRED, unmeasured.
- **Effort:** M. **Risk:** Med. **Confidence:** READ.

## SMS-104 / Return before decoding a rejected or unallocated VU image / Category 6

- **Location(s):** Simple-Media-System/src/SMS_EE.c:946-963,967-977.
- **Problem:** SMS_LZMA2Decompress frees and clears the destination on a declared-size mismatch, then unconditionally decodes to UNCACHED_SEG(NULL); allocation failure takes the same path. SMS_InitVU's NULL check happens only after this invalid write, and decoder failure is otherwise ignored.
- **Simplest fix:** Reject the size mismatch before allocating; return NULL on failed allocation or decode, freeing the buffer through the existing owning function.
- **Justification:** Early returns repair the existing failure contract used by SMS_InitVU without adding recovery or another abstraction.
- **Benefit:** Prevents invalid memory writes and DMA submission of failed decompressions; no byte/time saving claimed. Allocation-failure consequence is source-derived, not hardware reproduced.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-105 / Reject a zero FLAC sample rate before duration division / Category 6

- **Location(s):** Simple-Media-System/src/SMS_ContainerFLAC.c:45-77,106-114.
- **Problem:** The FLAC creator passes an output block structure to _do_probe, which divides the declared sample count by the header sample rate before the later nonzero-rate acceptance check. A STREAMINFO block with a zero rate therefore causes division by zero during format detection.
- **Simplest fix:** Reject zero sample rate immediately after reading it, before calculating duration, using the existing probe failure path.
- **Justification:** One format-boundary check prevents arithmetic on an invalid field; no new parser layer or recovery.
- **Benefit:** Removes a direct malformed-media division-by-zero path; no size or speed savings claimed and no new malformed-input harness was created.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-106 / Apply the existing bounded audio wait to context setup / Categories 6, 8

- **Location(s):** Simple-Media-System/src/SMS_SPU.c:98-111,303-320.
- **Problem:** Most audio wrappers use _spu_wait to retire a nonresponsive RPC server, but SPU_InitContext still issues a synchronous RPC. If AUDSRV stops responding during this request, opening media can still wait forever despite the surrounding bounded-server work.
- **Simplest fix:** Send this request with the same existing completion semaphore/callback as the other audio RPCs and use _spu_wait; use its failure result before consuming the reply.
- **Justification:** Reuses the existing bounded wait and failure state for the one remaining synchronous audio operation; no new retry, timeout setting or wrapper.
- **Benefit:** Removes one unbounded playback-open wait; hardware failure behavior INFERRED from synchronous RPC contract, not console reproduced.
- **Effort:** S. **Risk:** Med. **Confidence:** READ.

## SMS-107 / Keep the IOP sound buffer alive until its RPC has finished / Category 6

- **Location(s):** Simple-Media-System/src/SMS_SPU.c:237-256.
- **Problem:** SPU_LoadData ignores _spu_wait's failure result and frees the IOP heap payload even when the server request remains pending. A delayed server can subsequently use that freed address, which may already have been reused by another IOP allocation.
- **Simplest fix:** Free the buffer only after confirmed completion. On the existing permanent-server-retirement path, leave this one boot sound allocation resident until IOP reset rather than freeing memory still owned by an in-flight request.
- **Justification:** A single conditional at the ownership boundary prevents a dangling remote pointer; no tracking layer, retry or fallback is added.
- **Benefit:** Prevents a remote use-after-free after the 3,000 ms timeout; retains at most this boot's 70,816-byte sound payload until reset on that failed-server path. Dynamic consequence INFERRED; no console run.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-108 / Reject AVI chunks that cannot fit or advance / Category 6

- **Location(s):** Simple-Media-System/src/SMS_ContainerAVI.c:203-216,388-426,585-589,633-637,653-657,684-697.
- **Problem:** Header and index scanning add untrusted 32-bit chunk lengths to the current position without checking overflow or remaining bytes. An unknown chunk length of 0xfffffff8 wraps the next seek back to its own header, so format detection loops forever; named chunks also subtract fixed field lengths without requiring the chunk to contain them.
- **Simplest fix:** Before processing each chunk, require its padded payload to fit the remaining file and require known chunk sizes to contain the fields actually consumed. Reject failed/nonforward skips through the existing error path.
- **Justification:** Direct bounds on existing chunk arithmetic prevent backward loops, oversized metadata allocations and short-structure reads; no new parser abstraction or recovery system.
- **Benefit:** Removes a source-proven nonprogress loop and rejects impossible metadata lengths before allocation; no timing/size reduction claimed for valid media.
- **Effort:** M. **Risk:** Low. **Confidence:** READ (arithmetic/control-flow evidence; no new malformed-input harness).

## SMS-109 / Restrict AVI superindexes to standard-index children / Category 6

- **Location(s):** Simple-Media-System/src/SMS_ContainerAVI.c:226-252,274-301,684-690.
- **Problem:** A type-0 OpenDML superindex recursively invokes the same reader on arbitrary file offsets, and the child may be another superindex or the parent itself. There is no recursion limit or child-type check, so a self-reference exhausts the EE stack while opening the file; declared entry counts also run beyond the enclosing chunk/file.
- **Simplest fix:** Permit only standard type-1 indexes below the one superindex level and require each entry count to fit its enclosing index payload. Check child seek/read results using the current failure return.
- **Justification:** Enforces the existing two-level OpenDML format instead of introducing cycle sets or general traversal machinery.
- **Benefit:** Bounds recursion and metadata work to actual index bytes, avoiding stack exhaustion and unbounded reads; hardware impact INFERRED, not dynamically reproduced.
- **Effort:** M. **Risk:** Low. **Confidence:** READ.

## SMS-110 / Bound recursive MOV atom descent / Category 6

- **Location(s):** Simple-Media-System/src/SMS_ContainerMOV.c:179-184,196-212,630-635,811-847,851-905.
- **Problem:** The same dispatcher recursively accepts nested moov/trak/mdia/minf/stbl/wave atoms without any depth bound or parent-type restriction. A small file containing thousands of successively nested container headers can exhaust the EE stack before reaching the inner payload.
- **Simplest fix:** Add a fixed parser nesting bound at the existing recursive dispatcher, with a balanced increment/decrement and its current error return; choose it above the deepest supported ordinary atom path.
- **Justification:** One parser-local depth value directly bounds an existing recursive operation; no configurable limit, wrapper or recovery layer is warranted.
- **Benefit:** Prevents source-derived stack exhaustion from deeply nested media; no console reproduction or valid-file speed/size benefit claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-111 / Reject repeated owning MOV table atoms / Categories 4, 6

- **Location(s):** Simple-Media-System/src/SMS_ContainerMOV.c:460-464,483-497,536-548,558-580,598-625,639-653,667-683,150-162.
- **Problem:** Repeated stts/stsc/stsz/stco/ctts/stss or esds atoms overwrite their owning pointers with new allocations. Only the last pointer is freed, so one corrupt file can leak each preceding allocation and exhaust the 32 MB heap during a single open attempt.
- **Simplest fix:** Reject a second owning table/config atom for the same stream before replacing its pointer, using the existing parser error return.
- **Justification:** A per-reader already-present-pointer check is smaller than adding replacement ownership or a duplicate-table subsystem; normal MOV tables occur once per stream.
- **Benefit:** Eliminates repeat-atom heap leaks; retained bytes depend on input and are INFERRED, unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-112 / Initialize only the FLAC predictor history actually present / Category 6

- **Location(s):** Simple-Media-System/src/SMS_FLAC.c:168-190,281-289.
- **Problem:** decode_subframe_fixed computes four predictor-history values before switching on the predictor order. Orders 0–3 read negative decoded[] indices, including ordinary valid FLAC subframes with zero/short predictor histories.
- **Simplest fix:** Move predictor initialization into the corresponding switch cases and read only the order's available warm-up samples; order zero requires none.
- **Justification:** Rearranges the existing initialization without adding a helper or data structure.
- **Benefit:** Removes out-of-bounds reads on valid fixed-predictor frames; compiler/runtime effect not dynamically reproduced and no size saving claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-113 / Reject FLAC buffering geometry the decoder cannot handle / Category 6

- **Location(s):** Simple-Media-System/src/SMS_ContainerFLAC.c:56-77,114; Simple-Media-System/src/SMS_FLAC.c:381-404,488-504.
- **Problem:** STREAMINFO's maximum frame size is accepted as zero, meaning unknown in FLAC, but the decoder uses it as its exact input-buffer allocation and fill target. It then copies zero bytes and dereferences the missing/zero-sized bitstream buffer; maximum block geometry and allocation results are also published unchecked.
- **Simplest fix:** Reject unsupported zero/invalid frame and block geometry in the existing container acceptance boundary, and fail decoder initialization if either required allocation fails. Preserve the original pointer until successful reallocation.
- **Justification:** Explicitly refusing geometry the current fixed-buffer decoder cannot process is smaller than adding streaming frame discovery; minimal allocation checks repair the existing constructor contract.
- **Benefit:** Avoids a zero-sized bitstream dereference/nonprogress path and low-memory crashes; no new FLAC buffering architecture or measured size benefit claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-114 / Bound DXSB bitmap headers, scratch width and RLE input / Category 6

- **Location(s):** Simple-Media-System/src/SMS_DXSB.c:195-213,241-278,303-309; Simple-Media-System/include/SMS.h:120.
- **Problem:** _decode reads its fixed header before requiring enough packet bytes, accepts any 16-bit width for a fixed scratchpad row, and reads up to four RLE nibbles after checking only the first nibble. A short subtitle packet overreads the header/RLE; a wide but short bitmap can allocate successfully and then write beyond the EE scratchpad.
- **Simplest fix:** Reject packets shorter than the fixed header, reject dimensions that exceed the existing scratch-row/display capacity, and require every complete RLE code to fit the remaining input before expanding it. Return the current decode-failure result.
- **Justification:** Direct bounds on this decoder's existing buffer contract prevent concrete reads/writes outside buffers; no larger scratch allocation, fallback or generalized decoder layer.
- **Benefit:** Removes malformed embedded-subtitle memory corruption paths; byte/time savings unmeasured and no exploit program was created.
- **Effort:** M. **Risk:** Low. **Confidence:** READ.

## SMS-115 / Stop subtitle width scans at the supplied length / Category 6

- **Location(s):** Simple-Media-System/src/SMS_SubtitleContext.c:101-124,184-205,267-269.
- **Problem:** Both width readers loop through apStr == apStr + aLen, including one extra byte. The single-byte path measures the terminator as unsigned glyph index 224 in the ASCII font, so line wrapping/alignment includes a byte from outside the glyph-width table instead of the requested text.
- **Simplest fix:** Change both existing loop bounds to stop before lpEnd, matching their rendering counterparts.
- **Benefit:** Correct width/wrapping and one less glyph-table lookup per measurement; time/visual effect INFERRED, not hardware measured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-116 / Preserve the consumed UTF-8 BOM when restarting SRT parsing / Category 6

- **Location(s):** Simple-Media-System/src/SMS_SubtitleContext.c:520-544,555-579.
- **Problem:** _load_srt detects and consumes a UTF-8 BOM, validates the first serial, then seeks back to byte zero. The real loop cannot parse the BOM-prefixed serial and misaligns the first cue's serial/timestamp reads, dropping that cue.
- **Simplest fix:** Restart at the original subtitle position plus the consumed BOM length instead of zero.
- **Benefit:** Retains the first subtitle cue in BOM-prefixed SRT files; no hardware playback measurement or byte saving claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-117 / Bound subtitle reset after the last cue / Category 6

- **Location(s):** Simple-Media-System/src/SMS_SubtitleContext.c:870-892,917-920; Simple-Media-System/src/SMS_PlayerControl.c:774,816,1348.
- **Problem:** _display advances m_Idx to m_Cnt after the last cue, while _reset unconditionally writes m_pPackets[m_Idx]. Seeking after subtitles finish therefore writes one element beyond the packet allocation before resetting the cursor.
- **Simplest fix:** Mark the current packet dirty only when m_Idx is below m_Cnt, then reset the index as today.
- **Justification:** One owning-array bound prevents a reachable out-of-bounds write; no new state or reset layer.
- **Benefit:** Removes heap corruption when seeking after the final subtitle; consequence source-derived, no console reproduction.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-118 / Check the combined subtitle path before copying it / Category 6

- **Location(s):** Simple-Media-System/src/SMS_GUIMiniBrowser.c:64-78; Simple-Media-System/include/SMS_Sounds.h:23-25.
- **Problem:** The subtitle picker copies the up-to-1,023-byte current directory into lPath[1024], then appends a slash and filename without checking the combined size. A valid deeply nested directory and a subtitle filename can therefore overflow its stack even though ordinary browser navigation now has path checks.
- **Simplest fix:** Require directory plus optional slash plus selected filename and terminator to fit lPath before its existing copy/open sequence; return through the current failed-open behavior when it cannot fit.
- **Justification:** One combined-path bound closes this retained unsafe construction; no path wrapper or alternate allocation is needed.
- **Benefit:** Removes a reachable stack-buffer overflow while choosing external subtitles; no size/performance saving claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-119 / Treat an empty subtitle file as no subtitle context / Category 6

- **Location(s):** Simple-Media-System/src/SMS_SubtitleContext.c:400-405,555-565,702-724,752-759,924-999; Simple-Media-System/src/SMS_Player.c:181,993-1010.
- **Problem:** Parsers can finish successfully with zero cues and no nodes, and SubtitleContext_Init clears the node list without always resetting the old cue count. Prepare still allocates using a zero maximum packet size and unconditionally writes its packet header, or traverses NULL nodes with a stale count; the player checks only m_ErrorCode before retaining the context.
- **Simplest fix:** Clear m_Cnt at initialization, and map zero parsed cues or parsing failure to the existing subtitle-error/no-subtitle path before installing Prepare. Keep playback running without external subtitles.
- **Justification:** Repairs the existing constructor result contract and avoids building an empty render allocation; no empty-context wrapper or fallback system.
- **Benefit:** Prevents invalid DMA-buffer writes/NULL-node access from empty or incomplete subtitle files; source-derived, not hardware reproduced.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-120 / Keep the clock text alive between minute updates and format noon correctly / Category 6

- **Location(s):** Simple-Media-System/src/SMS_GUIClock.c:248-283.
- **Problem:** lBuf is a new uninitialized automatic array on every half-second loop iteration, but sprintf runs only when the minute changes; the other tick renders indeterminate bytes except for the colon. The 12-hour branch also labels noon as AM and displays midnight as hour zero.
- **Simplest fix:** Move the existing text buffer outside the loop; choose AM/PM using the original hour >=12 and display hour modulo 12 with zero mapped to 12.
- **Benefit:** Corrects retained clock text and noon/midnight display; no allocation, layer or measured byte/time saving claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ (automatic-object lifetime and formatting control flow; no console reproduction).

## SMS-121 / Delete the device marker's permanent no-op display list / Categories 1, 3

- **Location(s):** Simple-Media-System/src/SMS_GUIDevMenu.c:93-94,101-126,180,229-230,336-345,448-451.
- **Problem:** The old active-device rectangle survives as a separately allocated/submitted/freed list containing a permanent no-op; only the selected-device arrow is drawn. The code explicitly keeps the old allocation only because the render path still submits it.
- **Simplest fix:** Delete m_pActRect, its allocation/submission/free, and the unused active-item parameter from the arrow renderer; base the remaining initialization test on m_pSelRect.
- **Benefit:** Removes one heap/display-list allocation and one list submission per render, plus unused state/control code. Source payload is 16 bytes plus list headers/allocator overhead; final ELF and timing reductions INFERRED.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-122 / Remove the decoded HD background that the HD renderer never uses / Categories 1, 4, 5

- **Location(s):** Simple-Media-System/src/SMS_GUIDesktop.c:42-43,325-340,608-639; Simple-Media-System/Makefile:46.
- **Problem:** Desktop_Render unconditionally decodes/caches a background before taking the HD branch, but HD paints only a gradient and never uploads that image. The unused first HD decode also pins the mini background in the shared cache, so a later switch to SD reuses the wrong background.
- **Simplest fix:** Predecode the jellyfish only in the existing SD branch; remove the HD mini-image choice, externs and embedded build object once the sole consumer is gone.
- **Benefit:** Avoids the unused 256×256×4 = 262,144-byte HD cache and its JPEG decode/expansion; embedded JPEG bytes are separately measurable from images/main_bg_mini.jpg. ELF/latency reductions INFERRED, not built or timed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-123 / Share the two identical RGBA texture upload loops / Category 2

- **Location(s):** Simple-Media-System/src/SMS_GUIDesktop.c:386-417,503-531.
- **Problem:** The cached desktop image and transient splash separately calculate the same GS texture layout and upload RGBA rows in 32-row bands. Fixes to the GIF transfer limit or last-band handling must be duplicated.
- **Simplest fix:** Put only this common layout/upload sequence in one local function taking the existing pixel pointer and dimensions, and replace both copies with calls; leave image lifetime and fade behavior at their current owners.
- **Justification:** Two retained copies exist, and replacing roughly 50 upload/layout lines with one roughly 25-line body and two calls yields a concrete net deletion; no loader/cache abstraction is needed.
- **Benefit:** INFERRED reduction of roughly 20–25 source lines and duplicate upload logic; runtime/ELF savings unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-124 / Save resume history before destroying the container path / Categories 4, 6

- **Location(s):** Simple-Media-System/src/SMS_Player.c:1499-1504,1538-1560; Simple-Media-System/include/SMS_Sounds.h:23-25.
- **Problem:** Player teardown copies the current media path into a 512-byte stack array even though the browser can construct paths up to 1,023 bytes. Stopping/finishing a file under a long valid path therefore overflows the stack during cleanup.
- **Simplest fix:** Perform the existing conditional history update while the container still owns its path, then destroy the container; delete the local path array and strcpy.
- **Justification:** Reordering the current ownership boundary removes the unsafe copy and a 512-byte temporary, without adding a path helper or allocation.
- **Benefit:** Removes a reachable teardown overflow and 512 bytes of per-call stack (source-declared size); elapsed time/linked code savings INFERRED.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-125 / Omit the audio-language row for silent video / Category 6

- **Location(s):** Simple-Media-System/src/SMS_PlayerControl.c:365-405,864-868; Simple-Media-System/src/SMS_PlayerMenu.c:103-108,269-280.
- **Problem:** Silent video leaves the audio-language list empty, but opening the player menu unconditionally dereferences PlayerControl_GetLang() in _update_lang. A valid video-only file can therefore crash when its playback menu is opened.
- **Simplest fix:** Skip the audio-language update and start the menu at its display row when no audio stream exists; retain the existing row for files with audio.
- **Justification:** Removes an inapplicable action using the existing audio-stream selection state; no placeholder/fallback row or new abstraction.
- **Benefit:** Prevents a user-triggered NULL dereference on silent videos; no console run or size/latency saving claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-126 / Bound the language-change OSD to its destination / Category 6

- **Location(s):** Simple-Media-System/src/SMS_PlayerControl.c:373-382,1439-1446; Simple-Media-System/src/SMS_ContainerAVI.c:623-637.
- **Problem:** An AVI stream's name is copied into the audio-language list without a short display-name limit, then sprintf appends that name to a 128-byte stack buffer when changing languages. A valid long stream name therefore overflows this OSD buffer.
- **Simplest fix:** Replace this sprintf with snprintf using sizeof(lBuf), then retain the existing strlen/render path.
- **Justification:** Direct bounded formatting replaces the unsafe operation; no metadata copy, wrapper or new truncation mechanism.
- **Benefit:** Removes a media-metadata stack overflow on audio-track changes; no byte/latency saving claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-127 / Initialize semaphore limits before creating playback queues / Category 6

- **Location(s):** Simple-Media-System/src/SMS_RingBuffer.c:21-46; Simple-Media-System/src/SMS_Player.c:292-307,966-978; Simple-Media-System/src/SMS_IPU.c:702-708.
- **Problem:** These constructors set only init_count on an uninitialized ee_sema_t, leaving max_count and creation attributes indeterminate. Queue notifications may accumulate multiple tokens, while pause/ack semaphores need a defined single-token capacity; unchecked creation failures then become invalid WaitSema/SignalSema calls.
- **Simplest fix:** Zero-initialize the existing parameter structs, set a capacity matching each semaphore's actual queue/token contract, and fail through existing construction cleanup if creation fails.
- **Justification:** Required kernel fields are initialized at their current owning constructors; no semaphore wrapper, retries or configurable policy.
- **Benefit:** Removes indeterminate kernel-call parameters and invalid-handle propagation; actual EE manifestation INFERRED, not hardware tested.
- **Effort:** M. **Risk:** Med. **Confidence:** READ.

## SMS-128 / Delete the removed logo's coordinate table and scratch packet / Category 1

- **Location(s):** Simple-Media-System/src/SMS_GUIDesktop.c:52-68,117,604,643-644.
- **Problem:** The removed animated watermark leaves all 51 coordinate pairs and a 96-u64 local packet declaration. The sole live table use reads the fixed final entry's Y value, which is four.
- **Simplest fix:** Use that fixed vertical offset in the existing version layout, and delete the obsolete table, scratch declaration and void cast.
- **Benefit:** 408 declared coordinate bytes and 17 table lines removable; the dead 768-byte local is likely compiler-eliminated already, so no stack saving is claimed for it. Linked savings INFERRED until built.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## SMS-129 — Bound AAC dynamic-range exclusion groups (category 6)
- **Read:** `Simple-Media-System/src/SMS_AAC.c:324–337`, `:7548–7560`, `:7563–7595`, `:7603–7612`.
- **Problem:** The dynamic-range extension accepts an unlimited chain of seven-channel exclusion groups and writes each group into a 64-byte mask. The tenth group writes beyond that mask before any enclosing packet-length check, so malformed audio corrupts decoder state.
- **Simplest fix:** Reject an additional exclusion group before its seven entries exceed the existing mask or the enclosing extension bytes; propagate the existing decode-error result.
- **Addition justification:** A local bound is necessary to stop a demonstrated out-of-bounds write; no new abstraction is needed.
- **Benefit:** Measured capacity 64 entries versus 70 entries after ten groups; crash/audio consequences INFERRED. **Effort S; risk Low; confidence READ.**

## SMS-130 — Reject AAC escape magnitudes beyond the inverse-quantization table (category 6)
- **Read:** `Simple-Media-System/src/SMS_AAC.c:883–1912` (full literal structure), `:6559–6575`, `:6595–6599`, `:6739–6778`, `:6780–6835`.
- **Problem:** Escape decoding accepts unbounded unary lengths and stores the resulting magnitude in a signed 16-bit sample, while the vector inverse quantizer directly indexes an 8192-element table with the absolute sample value. A malformed escape can therefore read beyond that table; long unary sequences also drive invalid bit widths/shifts before packet bounds are checked.
- **Simplest fix:** Reject escape lengths/magnitudes beyond the supported 8191 maximum while decoding and return the existing spectral-data error before vector quantization.
- **Addition justification:** A local format bound protects the existing table and bit operations; no extra table or decoder layer is required.
- **Benefit:** Measured table capacity 8192 floats; prevents out-of-bounds indexed reads and invalid shifts. Runtime fault severity INFERRED. **Effort S; risk Low; confidence READ.**

## SMS-131 — Clear the complete complex SBR history on decode errors (category 6)
- **Read:** `Simple-Media-System/src/SMS_AAC.c:3619–3638`, `:3730–3735`, `:4725–4731`, `:8247–8249`.
- **Problem:** Error recovery clears each complex history matrix using `sizeof(float)` although each QMF entry contains two floats. Half of the history survives the reset and is subsequently reused by the synthesis path.
- **Simplest fix:** Size each clear from its actual matrix/entry type, matching initialization and normal history maintenance.
- **Addition justification:** None; replace the existing incorrect size expression.
- **Benefit:** Measured reset clears only half the intended matrix bytes today; audible recovery artifacts INFERRED. **Effort S; risk Low; confidence READ.**

## SMS-132 — Reject failed external-font decompression (category 6)
- **Read:** `Simple-Media-System/src/SMS_GS_2.c:553–579`, `Simple-Media-System/include/xz.h:209–217`, `Simple-Media-System/src/SMS_SubtitleContext.c:184–205`.
- **Problem:** The font loader publishes its allocated multibyte-font buffer even when decompression fails. XZ explicitly leaves failed single-call output undefined, yet subtitle width/rendering subsequently treat those bytes as font indexes and glyph metadata.
- **Simplest fix:** Require the existing decoder's successful end result; free and clear the new font buffer on failure before returning it.
- **Addition justification:** One existing-result check is necessary to prevent undefined decoder output from becoming active font data; no additional loading layer is needed.
- **Benefit:** Eliminates acceptance of corrupt compressed font bodies; crash/misrender consequences INFERRED. **Effort S; risk Low; confidence READ.**

## SMS-133 — Terminate and check the language-pack bytes before line splitting (category 6)
- **Read:** `Simple-Media-System/src/SMS_Locale.c:838–845`, `:871–891`, `:899–924`.
- **Problem:** Each language-pack read ignores its returned byte count and leaves the allocated extra byte uninitialized. When a short pack ends in a lone newline, the line splitter reads that extra byte and, if it happens to equal newline, advances beyond `lpEnd`, after which its inequality-only scan reads outside the allocation; short device reads also parse uninitialized bytes as translations.
- **Simplest fix:** Require the requested read count, terminate at the confirmed end, and stop line splitting when the next pointer reaches that end.
- **Addition justification:** Local result/end checks are required for the existing parser's buffer contract; no new loader or fallback is needed.
- **Benefit:** Removes parsing of unread heap bytes and the trailing-newline overrun path; device-failure frequency and visible consequences INFERRED. **Effort S; risk Low; confidence READ.**

## SMS-134 — Remove the eightfold oversized desktop DMA array (category 4)
- **Read:** `Simple-Media-System/src/SMS_GUI.c:86`, `:153`, `:188`; `Simple-Media-System/src/SMS_EE.c:695–728`; `Simple-Media-System/include/SMS_GS.h:1153–1171`.
- **Problem:** The desktop array uses a byte-valued `sizeof(GSLoadImage) * 9` as a count of 64-bit elements. Its only writer and consumer require nine `GSLoadImage` records, so seven eighths of the static data allocation are unused.
- **Simplest fix:** Declare nine existing `GSLoadImage` objects, retaining the existing alignment and call sites.
- **Addition justification:** None; correct the existing declaration's element type/count.
- **Benefit:** Measured allocation ratio 8:1; saves `63 * sizeof(GSLoadImage)` bytes of static RAM and initialized ELF data (12,096 bytes when the target structure is 192 bytes). Target ELF byte delta not built: INFERRED. **Effort S; risk Low; confidence READ.**

## SMS-135 — Include the remainder in the final desktop copy strip (category 6)
- **Read:** `Simple-Media-System/src/SMS_EE.c:695–728`; `Simple-Media-System/src/SMS_GUI.c:153`.
- **Problem:** The desktop copy divides its height into nine equal strips and computes a remainder adjustment only after the final strip has already been initialized. That adjustment is both too late and tests the next strip endpoint, leaving the bottom `height % 9` rows uncopied whenever the height is not divisible by nine.
- **Simplest fix:** Set the final strip height from the remaining rows before calling the existing image-packet initializer; delete the ineffective post-initialization adjustment.
- **Addition justification:** None; move the existing remainder calculation to where its result is used.
- **Benefit:** Measured 3 omitted rows for a 480-row copy and 7 for 448 rows; visible stale-edge behavior INFERRED. **Effort S; risk Low; confidence READ.**

## SMS-136 — Keep remote-driver import matching inside the loaded bytes (category 6)
- **Read:** `Simple-Media-System/src/SMS_RC.c:58–80`, `:103–117`.
- **Problem:** The import-version scanner rounds the file size upward and checks only the current word against its end pointer; it can then inspect a second word and compare a name twelve bytes farther on without proving those bytes exist. Truncated or malformed external RMMAN modules can therefore cause heap overreads, and the loader also scans after unchecked allocation/read results.
- **Simplest fix:** Scan only positions where the complete import header and name fit inside the confirmed bytes read; reject failed allocation or incomplete reads before scanning/executing.
- **Addition justification:** Local bounds/result checks protect the existing loader; no new scanner or recovery layer is needed.
- **Benefit:** Eliminates overreads beyond the external module allocation; runtime crash frequency INFERRED. **Effort S; risk Low; confidence READ.**

## SMS-137 — Reuse bounded boot-asset path construction for RMMAN (category 6)
- **Read:** `Simple-Media-System/src/SMS_RC.c:84–95`; `Simple-Media-System/src/SMS_Config.c:72`, `:259–276`.
- **Problem:** The remote-driver loader copies the boot directory into a 128-byte stack array and appends a nine-character filename without a capacity check. A valid boot directory longer than 118 characters overflows that array.
- **Simplest fix:** Use the existing bounded `SMS_ConfigAssetPath` call to append the driver filename and add that candidate only when it fits.
- **Addition justification:** None; reuse the existing helper and delete the unchecked copy/append.
- **Benefit:** Measured 128-byte buffer and 10-byte filename including NUL; prevents a stack overwrite for long boot paths. **Effort S; risk Low; confidence READ.**

## SMS-138 — Clear cached controller buttons when a report read fails (category 6)
- **Read:** `Simple-Media-System/src/SMS_PAD.c:180–208`; `Simple-Media-System/src/libds34usb.c:132–145`; `Simple-Media-System/src/libds34bt.c:128–141`.
- **Problem:** A controller that still reports RUNNING but fails its data RPC leaves `s_ds34Mask` unchanged. The GUI then keeps seeing the previous buttons as pressed until a successful report or status change, so a failed read can repeat a navigation/action indefinitely.
- **Simplest fix:** Assign the cached mask from each successful report and clear it on the existing failed-read branch for either transport.
- **Addition justification:** A local failure assignment is required to prevent stale input; no retry or polling layer is needed.
- **Benefit:** Removes stale pressed-button state after failed reads; actual user-visible repeats INFERRED. **Effort S; risk Low; confidence READ.**
