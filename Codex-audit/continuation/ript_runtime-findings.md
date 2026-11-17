# RiptOPL runtime/build/tool/test continuation findings

Read-only audit of immutable SHA 679d3d8626dd09a913e7081101418e337234fe7c. Findings continue existing report; no repository edits.

Release date-refresh duplication is recorded once as **CROSS-005** in [the summary](../Codex-SUMMARY.md). RIPTOPL-100 is retired into that finding.

### RIPTOPL-101 / Bound ISO system-file parsing before copying boot paths / Category 6

- **Location(s):** `RiptOPL/tools/pc/iso2opl/src/iso2opl.c:15-16,338-341,353-375,389,425-427`.
- **Problem:** The ISO supplies `SYSTEM.CNF`'s length, which is passed directly into a 65,536-byte buffer; the BOOT2 line is then copied without a bound into a 256-byte stack buffer. `GetGameID` additionally dereferences the result of `strstr(..., ";1")` without checking it, so even a short malformed BOOT2 line crashes the installer/SCAN operation.
- **Simplest fix:** Reject negative/oversized SYSTEM.CNF lengths, terminate the bytes actually read, check the boot-path length and expected prefix/suffix, and copy only after these local format checks pass.
- **Justification:** Local bounds and null-result checks enforce the existing format and reuse the existing parse-failure returns; no new parser or fallback.
- **Benefit:** **READ:** removes an image-controlled write overflow and null dereference; frequency and exploit impact are **INFERRED**. No runtime/ELF saving claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### RIPTOPL-102 / Distinguish a failed UL catalog open from a found game / Category 6

- **Location(s):** `RiptOPL/tools/pc/opl2iso/src/opl2iso.c:118-132,151-165,193-218`; `EXIT_FAILURE` definition `:17`.
- **Problem:** `findGame` returns 1 both when it finds a game and when `ul.cfg` cannot be opened. `exportGame` treats any nonzero result as success and reads uninitialized `grecord` fields, potentially continuing to format paths from uninitialized strings.
- **Simplest fix:** Return the function's existing not-found value (0) on catalog-open failure, or make the caller explicitly accept only a distinct found value. The first choice is a one-line correction.
- **Justification:** No added abstraction; aligns the failure return with the existing boolean caller.
- **Benefit:** Prevents an undefined-memory path when a user runs the exporter outside a UL library; actual crash probability is **INFERRED**.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### RIPTOPL-103 / Stop ISO conversion on read errors and final flush failures / Category 6

- **Location(s):** `RiptOPL/tools/pc/opl2iso/src/opl2iso.c:260-273`; `RiptOPL/tools/pc/iso2opl/src/iso2opl.c:185-193,300-315,585-602`.
- **Problem:** `opl2iso` loops on `!feof`; a read error sets `ferror` without EOF, so zero-byte reads can spin indefinitely. Both converters ignore destination `fclose` failures, allowing a buffered final write to fail while the installer adds the game to `ul.cfg` or reports success.
- **Simplest fix:** Loop on successful reads, inspect `ferror` after the read loop, and propagate failed destination closes through the existing conversion error returns before catalog append/success.
- **Justification:** Uses existing stdio status and existing error paths; no worker, retry or replacement-file system.
- **Benefit:** **READ:** eliminates an unbounded error loop and false-success path; disk-error frequency is **INFERRED**, no measured time saving.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### RIPTOPL-104 / Return after invalid genvmc argument counts / Category 6

- **Location(s):** `RiptOPL/tools/pc/genvmc/src/genvmc.c:397-413`.
- **Problem:** An invalid argument count only prints usage, then `strtol(argv[1], ...)` and the output-file call still execute. Running the documented utility without arguments therefore passes a null pointer to `strtol`; one argument leaves the filename absent.
- **Simplest fix:** Return `EXIT_FAILURE` from the existing invalid-count branch.
- **Benefit:** One local return prevents undefined behavior on ordinary command-line mistakes; no size/time claim.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### RIPTOPL-105 / Promote ISO sector offsets before multiplying / Category 6

- **Location(s):** `RiptOPL/tools/pc/iso2opl/src/isofs.c:185-198`; existing correct file-read calculation `:981`.
- **Problem:** `isofs_ReadSect` multiplies the 32-bit unsigned `lsn` by 2,048 before assigning the result to a 64-bit offset. Directory sectors at or beyond LBA 2,097,152 wrap to the start of the image, so metadata in the second half of a dual-layer DVD can be read from the wrong location.
- **Simplest fix:** Cast `lsn` to `s64` before multiplication, matching the existing calculation in `isofs_Read`.
- **Benefit:** Correct offsets at and above 4 GiB; the wrap boundary is exact arithmetic, impact on particular games **INFERRED**. No added state/abstraction.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### RIPTOPL-106 / Treat UL checksum input as unsigned bytes / Category 6

- **Location(s):** `RiptOPL/tools/pc/iso2opl/src/iso2opl.c:65-68`; `RiptOPL/tools/pc/opl2iso/src/opl2iso.c:60-63`; table declarations `iso2opl.c:15`, `opl2iso.c:14`.
- **Problem:** A plain `char` is promoted to signed `int` before XOR/indexing the CRC table. On normal signed-char host builds, a UTF-8/extended character in a game name therefore forms a negative table index, causing an out-of-bounds read and a platform-dependent filename checksum.
- **Simplest fix:** Read each input character as `unsigned char` in both copies. The table is only ever indexed by a byte after this fix, so reduce its declared capacity from 1,024 to 256 entries.
- **Justification:** A local cast corrects the byte contract; reducing proven unused table capacity is direct deletion. A shared library is unnecessary for these standalone utilities.
- **Benefit:** **READ:** removes negative indexing; **measured declaration arithmetic:** 3,072 bytes of excess table payload per utility (assuming the declared 32-bit u32) can be removed. No host timing/ELF measurement.
- **Effort:** S. **Risk:** Low. **Confidence:** READ; host signed-char default is INFERRED.

### RIPTOPL-107 / Terminate ZSO padding removal when decoding cannot succeed / Category 6

- **Location(s):** `RiptOPL/tools/pc/ziso.py:62-71,175-182`.
- **Problem:** The decompressor retries after dropping one trailing byte on every LZ4 error, with no termination condition. Once malformed/truncated input shrinks to an empty byte string, every failure retries the same empty bytes forever, so the caller's error-reporting branch is unreachable.
- **Simplest fix:** Stop when the candidate bytes are exhausted and let the existing LZ4 exception reach the caller. Limit trimming to the possible alignment padding if retaining that format accommodation.
- **Justification:** A bound on the existing loop fixes an unbounded hang; no additional retries or fallback.
- **Benefit:** **READ:** finite failure on corrupt input; elapsed saving depends on the input and is **INFERRED**.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### RIPTOPL-108 / Reject ZSO conversions whose output is the source file / Category 6

- **Location(s):** `RiptOPL/tools/pc/ziso.py:86-99,130-133,217-220`.
- **Problem:** The shared opener first opens the source for reading and then opens the supplied output with `wb` without checking file identity. Reusing the input pathname, a symlink or a hardlink truncates the source image before either conversion reads it.
- **Simplest fix:** Check input/output file identity before opening the output and reject the same file. Preserve the existing direct conversion path; no backup files are needed.
- **Justification:** One precondition prevents concrete user-data destruction without adding replacement-file machinery.
- **Benefit:** Prevents full source-image loss from a mistaken output path; affected-image sizes and incidence are **INFERRED**.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### RIPTOPL-109 / Refuse or preserve a partial final ZSO block / Category 6

- **Location(s):** `RiptOPL/tools/pc/ziso.py:139-150,217-234,246-247,308-319,362-364`.
- **Problem:** Compression and decompression floor `total_bytes / block_size`; the compressor reports success after silently dropping any remainder, while the header retains the original byte length. The advertised 4/6/8-KiB block options can encounter this even on a valid 2-KiB-sector ISO.
- **Simplest fix:** If the format is intended to contain whole blocks only, reject nondivisible input before creating the output. Otherwise count and encode/decode the last partial block consistently; the rejection is the smaller compatible change until that support is established.
- **Justification:** Enforces the whole-block contract at one existing entry point; no new compression format or layer.
- **Benefit:** **READ:** prevents loss of between 1 and `block_size-1` trailing bytes; compatibility of partial-block readers is **INFERRED**.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### RIPTOPL-110 / Retire the inactive frontend Makefile build / Categories 1, 2, 7

- **Location(s):** `RiptOPL/Makefile:136-138,199-200,385-418,1188-1189,1204-1208`; supported build `RiptOPL/ps2.yaml:638-652`; remaining version caller `RiptOPL/tools/lng_pack.sh:11-31`; explicit retirement documentation `RiptOPL/README.md:893-894`, workflow comment `.github/workflows/flavours.yml:399-400`.
- **Problem:** The 1,251-line root Makefile still advertises a complete frontend/release build, but its source rule resolves obsolete `src/<name>.c` paths while production is split across C++ subdirectories. It also omits current source units and embeds SDK storage drivers in places where the supported build uses fixed vendored copies; maintaining its duplicate lists no longer protects a usable build.
- **Simplest fix:** Remove the retired frontend/release rules and duplicate feature/asset/module declarations. Have the language packer ask existing `tools/assets.py version-string` for its version, and update tests that assert old Makefile text to inspect the production ps2build definition; retain a small convenience Makefile only if real callers need its non-build targets.
- **Justification:** Reuses existing build/version commands and deletes obsolete build logic. It does not propose a second build facade or build-system rewrite.
- **Benefit:** **READ:** nearly all of a 1,251-line duplicate frontend build can be deleted; exact net line count depends on which convenience targets remain. No ELF/RAM benefit claimed.
- **Effort:** M. **Risk:** Med (historical/manual callers and text-assertion tests). **Confidence:** READ for broken source paths and explicit retirement; external manual usage is INFERRED.

### RIPTOPL-111 / Check the language string-table allocation before filling it / Category 6

- **Location(s):** `RiptOPL/src/core/lang.cpp:163-170,177-195`; existing caller failure handling `:492-519`.
- **Problem:** `lngLoadFromFile` does not check its `calloc` result before passing `&newL[strId]` to the line reader and later dereferencing it. Memory pressure during a language switch can therefore crash instead of returning through the existing unsuccessful-load handling.
- **Simplest fix:** If `calloc` fails, close the already-open file buffer and return 0.
- **Justification:** A local allocation check uses the existing cleanup and caller failure path; no allocator wrapper or retry.
- **Benefit:** Prevents a null-pointer write on allocation failure; occurrence on 32-MB EE hardware is INFERRED. No speed/size gain claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### RIPTOPL-112 / Use byte lengths in the HTTP catalog reference / Category 7

- **Location(s):** `RiptOPL/tools/pc/http/catalog_reference.py:155-162,193-199,205-213,258-261`; production `RiptOPL/src/platform/httpcatalog.cpp:148-149,194-211`; comparison harness `RiptOPL/tools/pc/http/tests/compare_catalog.py:98-104`.
- **Problem:** The reference decodes UTF-8 and checks Python character counts, whereas production enforces byte capacities with `strlen`. A 100-character Japanese title is accepted by the reference despite exceeding the production 160-byte title field; invalid UTF-8 is also replaced in the reference but copied verbatim by production, contradicting the asserted shared contract.
- **Simplest fix:** Enforce each field's encoded byte length and document/align the invalid-byte policy in the existing reference; extend the existing shared fixtures with multibyte boundary input when implementing.
- **Justification:** Corrects the existing oracle and fixture coverage; no new parser/testing framework.
- **Benefit:** Prevents a passing PC conformance result from promising catalogs the console rejects. Boundary arithmetic is READ; affected user catalogs are INFERRED.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### RIPTOPL-113 / Reserve and write the SYSTEM.CNF boot-path terminator / Category 6

- **Location(s):** `RiptOPL/src/platform/ps2cnf.cpp:42-67,115-119`; 64-byte capacity `RiptOPL/include/ps2cnf.h:1`; consumer `RiptOPL/src/sources/supportbase.cpp:116-134`; masking test initialization `RiptOPL/tests/host/test_ps2cnf.cpp:18,25`.
- **Problem:** `CNFGetKey` can write all 64 destination bytes and return success without a NUL; it only terminates after whitespace. The production caller has exactly 64 bytes and immediately uses string searches, whereas the host test supplies 65 zeroed bytes, masking the overflow boundary.
- **Simplest fix:** Reserve one byte, always terminate the copied path, and reject an overlong token through the existing parse error. Make the existing test use the production capacity and include that boundary when fixing it.
- **Justification:** A local loop bound and terminator enforce the existing buffer contract; no new parser or wrapper.
- **Benefit:** Prevents out-of-bounds string reads for a 64-character BOOT2 token. The boundary is READ; crash frequency on malformed images is INFERRED.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

## Supplements to existing canonical findings (do not count twice)

- **RIPTOPL-018 additional optional scratch:** `src/platform/sysneutrino.cpp:382-385,396-468,637-640,669-751` retains independent 4,096 + 4,116-byte UDP TOML and 4,096 + 4,608-byte SMB/NFS TOML buffers for the entire menu session. Their contents are only used by synchronous launch preflight. Allocate the required pair for that preflight and free on its existing exits (or reuse a single existing launch scratch area if one is actually available). Exact declared payload reclaimable outside preflight: **16,916 bytes**; this is READ arithmetic, not a measured ELF change. The added allocation is justified by a concrete 16.5-KiB retained-RAM reduction; no shared scratch manager is proposed. Effort M, risk Low/Med for cleanup paths.

- **RIPTOPL-106 additional table-capacity evidence:** production `src/platform/system.cpp:465-489` already uses an unsigned input byte, but still declares the CRC table as 1,024 entries while filling/indexing only 256. Its capacity can likewise fall by **3,072 bytes** of 32-bit payload. This supplements the table-capacity part only; the production byte-signedness defect is already fixed.

### RIPTOPL-114 / Allocate owned empty lines in the language-file reader / Category 6

- **Location(s):** `RiptOPL/src/platform/util.cpp:614-615,631-643,694-695`; language consumer `RiptOPL/src/core/lang.cpp:163-178,42-52`.
- **Problem:** With `allocResult=1`, a nonempty line is copied to a new allocation but an empty line returns a pointer inside the reader's own buffer. Language loading stores that borrowed pointer as an owned string, frees the reader buffer before validation, and later frees every stored entry; a blank translation line therefore introduces use-after-free and an invalid/double free during a normal language switch.
- **Simplest fix:** In allocated-result mode, allocate `lineSize+1` bytes for every returned line, including empty ones, and handle failure before copying.
- **Justification:** Removing the `lineSize` condition fixes the existing ownership contract; the required one-byte empty-string allocation replaces a dangling pointer. No new ownership wrapper or fallback.
- **Benefit:** Prevents heap misuse from an ordinary blank line in a user-provided language file; consequences on particular EE allocators are INFERRED.
- **Effort:** S. **Risk:** Low. **Confidence:** READ.

### RIPTOPL-115 / Do not treat a positive short read as the end of a config file / Category 6

- **Location(s):** `RiptOPL/src/platform/util.cpp:576-599`; configuration caller `RiptOPL/src/core/config.cpp:1115-1182,1485-1491` (fully reviewed caller always clears modified and returns success after the reader stops).
- **Problem:** The line reader closes the descriptor whenever a read returns fewer bytes than the requested capacity, although only a zero-byte read establishes EOF. A valid short read from a device/filesystem therefore drops all following settings or language entries; negative reads are also converted to the same successful end-of-file path.
- **Simplest fix:** Fill the existing buffer until it is full or a read returns zero, and preserve a read-error result so the existing callers can reject the incomplete load. Avoid adding timeout/retry policy; this is completion of the requested read.
- **Justification:** Corrects the existing POSIX read contract locally. Error propagation should reuse the current failed-load return paths.
- **Benefit:** Prevents partial configurations/languages being accepted as complete. Positive-short-read occurrence on each PS2 driver is INFERRED; the truncating branch is READ.
- **Effort:** M. **Risk:** Med (caller failure propagation must preserve existing config state). **Confidence:** READ for the branch; affected transport frequency INFERRED.

- **RIPTOPL-111 additional allocation:** `src/platform/util.cpp:631-633` copies into an unchecked per-line allocation. The RIPTOPL-114 ownership fix should check that same result, rather than adding a separate allocator layer.

### RIPTOPL-116 / Release BGM resources after the playback threads self-exit / Categories 4, 6

- **Location(s):** `RiptOPL/src/core/sound.cpp:46-54`; `RiptOPL/src/core/bgm.cpp:218-225,252-288,700-704,720-733,750-756,844-878`; existing ownership flag `RiptOPL/include/bgmplayer.h:40`.
- **Problem:** Audio shutdown calls `bgmStop` only while playing/running flags are set. A decode failure makes both threads exit and clears all those flags, but leaves `live_` set and the decoder/source, two semaphores and two dormant thread handles allocated; `audsrv_quit` then runs without releasing them.
- **Simplest fix:** Make `BgmPlayer::stop` return immediately when `live_` is clear, and call it unconditionally from audio shutdown so its existing teardown releases self-exited instances too.
- **Justification:** Reuses the ownership flag and teardown already present; no lifecycle wrapper, extra worker or retry.
- **Benefit:** Reclaims the leaked decoder/file and four kernel resources after a failed or self-stopped track; their byte size and failure frequency are INFERRED.
- **Effort:** S. **Risk:** Low/Med (retain existing waits for running threads). **Confidence:** READ.

- **RIPTOPL-018 additional diagnostic scratch:** `src/core/diagsave.cpp:17-22,32,40-44` retains another **16,384-byte** static array solely to snapshot the diagnostic ring while exporting DIAG.TXT. Allocate this snapshot for the existing export operation and free it on both existing exits; handle allocation failure with the function’s existing failure result. The allocation is justified by reclaiming exactly 16 KiB for the rest of the menu session (READ declaration arithmetic; no built-ELF size claim). Effort S, risk Low.

### RIPTOPL-117 / Correct malformed VMC dictionary IDs and delete unreachable duplicate rows / Categories 1, 6

- **Location(s):** `RiptOPL/src/core/vmc_groups.cpp:443-444,464-465,472-473,498,614,1143-1153,1271-1276,1423-1424,1439,1458-1473`; default-name consumers `RiptOPL/src/ui/guigame.cpp:493-495,529-530,697-702`; existing audit test `RiptOPL/tests/host/test_vmc_groups.cpp:15-17,26-36`.
- **Problem:** Eight title strings have malformed canonical ID spelling, so exact lookup misses the corresponding normal IDs and creates a separate default VMC instead of the intended shared one. Twelve duplicate title rows include two entirely unreachable later groups; the existing test merely prints these known inconsistencies and still passes.
- **Simplest fix:** Verify and correct the malformed literals against the intended game IDs; remove redundant duplicate rows and the two wholly shadowed group declarations/entries while preserving the existing first-match mapping. Make the existing dictionary audit reject malformed IDs and duplicate mappings after cleanup.
- **Justification:** Edits/deletes static data and strengthens its existing audit; no alternate lookup, normalization fallback, or new dictionary framework. Do not guess a replacement for the ambiguous `SLES-5350` entry.
- **Benefit:** READ inspection and complete table parsing identify **8 malformed strings, 12 redundant title rows and 2 wholly unreachable groups** among 1,046 title rows. Actual affected game ownership and final linked-byte savings are INFERRED.
- **Effort:** S/M (verify intended IDs). **Risk:** Low when first-match mappings are retained. **Confidence:** READ for malformed data and unreachable rows; intended replacement IDs require verification.

### RIPTOPL-118 / Validate VMC entry names before exporting them to filesystem paths / Category 6

- **Location(s):** `RiptOPL/src/core/vmcsaves.cpp:453,469,726-744,766-770,793-799,818-824,1128-1148`.
- **Problem:** VMC loading copies its directory/file entry names without validating them, and folder export concatenates those names into `mkdir` and truncating `open` paths. A damaged or supplied VMC can therefore give an entry a slash or `../` component and make an ordinary export create/write outside the selected save folder; the PSU importer already rejects precisely these names.
- **Simplest fix:** Reuse the existing `vsNameOk` check for the save name and each file name in `vsLoadVmc` before accepting the entry, returning the existing name error. Place the existing check where both loaders can use it.
- **Justification:** Reuses the validator and error code already used by the PSU input path; no path abstraction, normalization fallback or additional copy layer.
- **Benefit:** Prevents malformed VMC metadata from redirecting filesystem export writes. Control flow is READ; occurrence and damage on individual devices are INFERRED. No exploit program was run.
- **Effort:** S. **Risk:** Low (valid memory-card names already satisfy the existing check). **Confidence:** READ.

- **CROSS-003 additional close-error locations:** `src/core/vmcsaves.cpp:186-195,622-628,739-750,1197-1207` ignores the image/export descriptor close status after in-place card edits or folder-file writes, unlike its PSU writer at `:891-892`. Propagate the existing write-failure result when final close fails; this supplements the canonical ignored-close finding and should not be counted separately.
