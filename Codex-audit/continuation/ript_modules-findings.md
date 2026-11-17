# RiptOPL IOP modules continuation findings

Snapshot 679d3d8626dd09a913e7081101418e337234fe7c. Audit in progress; coverage is tracked separately.

### RIPTOPL-222 / Use the existing IDENTIFY buffer after ATA erase completion / Category 6

- Location(s): `RiptOPL/modules/hdd/atad/src/ps2atad.c:1146-1149,1199-1219`; exported ordinal `RiptOPL/modules/hdd/atad/src/exports.tab:17`; PIO write destination `RiptOPL/modules/hdd/atad/src/ps2atad.c:695-700`.
- Problem: The exported erase operation calls the security-status refresh with a null IDENTIFY buffer. That helper issues a PIO IDENTIFY read into the supplied pointer, then dereferences it, so the completion/error path can write a full sector to address zero.
- Simplest fix: Pass the driver's existing IDENTIFY scratch buffer to this refresh, as the other security operations do. No extra buffer or wrapper is needed.
- Benefit: Removes a concrete null DMA/PIO destination in the exported API (READ). No RiptOPL caller of erase was found, so this is an unused-export correctness defect, not a claimed normal loader failure; nothing was erased or executed during review.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-223 / Reserve a terminator in APA text-option buffers / Category 6

- Location(s): `RiptOPL/modules/hdd/apa/src/hdd_fio.c:119-137,146-225`.
- Problem: `fioInputBreaker` accepts a token exactly equal to its output capacity and copies no terminator. The two zeroed 32-byte text-option buffers are then fully overwritten and passed to `strcmp`/string diagnostics, causing an out-of-bounds read for a 32-byte size or filesystem token.
- Simplest fix: Reserve the final byte at these two text-option call sites, or delete that obsolete creation-only option parsing when applying RIPTOPL-218. Keep the fixed-width APA ID field's separate semantics.
- Justification: A local length adjustment fixes the concrete string-boundary defect without replacing the parser.
- Benefit: Bounded parsing of malformed legacy option strings (READ); no normal-loader occurrence, bytes, or timing measured.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-220 / Remove password encryption from the password-free APA build / Category 1, 3, 4, 5

- Location(s): `RiptOPL/modules/hdd/apa/src/apa-opt.h:31-38`; `RiptOPL/modules/hdd/apa/src/password.c:25-43,46-498` (literal cryptographic tables treated as opaque); `RiptOPL/modules/hdd/apa/src/hdd_fio.c:178-191,511-514,778-784`; build `RiptOPL/modules/hdd/apa/Makefile:8-11`, `RiptOPL/ps2.yaml:287-294`.
- Problem: The selected OSD build explicitly disables password checks, making `apaPassCmp` always succeed, but file-path parsing can still run the complete DES password-encryption implementation. The encrypted results are never used to authorize access in this build.
- Simplest fix: Remove the encryption calls and unnecessary comparison branches from this private OSD fork, then remove its unused DES implementation/build input. Preserve the existing partition-name parsing and password-free access behavior.
- Benefit: About 450 implementation lines and opaque constant tables become removable, plus needless DES work for password-bearing input paths (READ); final IRX bytes and timing unmeasured. This does not remove ATA drive unlocking, which uses a different live API.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-221 / Preserve the ATA drive's full capacity in its existing 64-bit BDM field / Category 6

- Location(s): `RiptOPL/modules/hdd/atad/src/ps2atad.c:1025-1060,1336-1355,1385-1408`; BDM consumer `RiptOPL/modules/bdm/src/part_driver_mbr.c:21-24`, `RiptOPL/modules/bdm/src/part_driver_gpt.c:129-175`.
- Problem: IDENTIFY capacities above 32 bits are reduced to `0xffffffff`, and that reduced count is copied into the already-64-bit BDM `sectorCount`. The request guard treats this saturation as permission to address the whole 48-bit namespace, so neither the advertised BDM size nor its large-drive limit represents the actual disk capacity.
- Simplest fix: Read the full IDENTIFY sector count into the existing BDM capacity field before overwriting the IDENTIFY buffer, and use that full count for this fork's sector-range checks. Keep the legacy SDK's 32-bit published fields saturated for ABI compatibility.
- Justification: Reusing the existing 64-bit capacity avoids new state/helpers and makes the already-supported large-drive path correct. Apply together with RIPTOPL-202 so partition validation does not reject valid partitions beyond a falsely advertised 2-TiB limit.
- Benefit: Correct device size and range bounds above 2 TiB (READ); hardware behavior is INFERRED and untested. No RAM or timing saving claimed.
- Effort: S. Risk: Med (large-drive compatibility). Confidence: READ.

### RIPTOPL-218 / Delete partition-table editors whose public operations are disabled / Category 1, 3, 7

- Location(s): `RiptOPL/modules/hdd/apa/src/hdd_fio.c:96-101,321-455,519-613,615-635,845-947,1028-1088`; helpers `RiptOPL/modules/hdd/apa/src/hdd.c:103-179`, `RiptOPL/modules/hdd/apa/src/apa.c:105-168,197-409`; refusal dispatch `RiptOPL/modules/hdd/apa/src/hdd_fio.c:487-495,974-980,1133-1136,1163-1166`.
- Problem: The private APA fork unconditionally refuses format, partition create/delete/rename, sub-partition edits, swap, and OSD-header updates, but retains their complete implementations and helper chains explicitly for diffability. These bodies include ignored errors and unchecked allocations even though no supported operation can use them.
- Simplest fix: Delete the code after unconditional refusal returns and the uncalled edit helpers/declarations; remove write-cache/journal-writer helpers only after their remaining call graph becomes empty. Keep the live partition reader, payload transfers, existing startup recovery, and table-write fence.
- Benefit: More than 600 source lines are direct deletion candidates (READ ranges; final net count INFERRED). Many static unreachable functions may already be compiler-eliminated, so no IRX/RAM saving is claimed without a build.
- Effort: M. Risk: Low. Confidence: READ.

### RIPTOPL-219 / Validate journal bounds and retain failed recovery records / Category 6

- Location(s): `RiptOPL/modules/hdd/apa/src/journal.c:58-85`; fixed journal layout `RiptOPL/modules/hdd/apa/src/libapa.h:183-189`; live startup `RiptOPL/modules/hdd/apa/src/hdd.c:324-335`; write-fence scope `RiptOPL/modules/hdd/apa/src/table_fence.h:84-91`.
- Problem: Startup replay trusts a disk-supplied signed record count to index the 126-element destination array, and dereferences an unchecked cache allocation. Failed journal reads or replay writes then fall through to `apaJournalReset`, erasing the recovery record and replacing the original failure with the reset result.
- Simplest fix: Reject counts outside zero through the fixed array capacity before replay, handle failed allocation, validate destinations against the existing device extent, and return the original replay/read error without resetting; reset only after every valid record was restored.
- Justification: Local bounds and error returns preserve the existing recovery operation without another journal, backup, retry, or validation framework.
- Benefit: Prevents out-of-array replay destinations and loss of the only recorded recovery state after transient I/O failure (READ control flow); physical-disk consequences are INFERRED. No new attack/test program or hardware write was performed.
- Effort: S. Risk: Med (recovery behavior). Confidence: READ.

### RIPTOPL-213 / End Bluetooth reset when the controller cannot acknowledge / Category 3, 5, 6

- Location(s): `RiptOPL/modules/ds34bt/iop/ds34bt.c:1534-1557`; `RiptOPL/modules/pademu/ds34bt.c:1403-1425`; menu callers `RiptOPL/src/app/opl.cpp:1342,1436,1963`, `RiptOPL/src/platform/system.cpp:295` (caller references checked).
- Problem: Reset waits forever for each running pad's status to clear; clearing depends on a later received controller packet and disconnect event. If that completion never arrives, the synchronous EE reset RPC and its launch/exit caller never return; the extra unconditional one-second delay also remains after all pads have stopped.
- Simplest fix: Give the existing disconnect wait one finite overall deadline, then close the current adapter connection through the existing disconnect path. Remove the fixed post-completion delay unless a specific compatibility requirement is demonstrated.
- Justification: A single bound fixes an actual unbounded state wait; no retry or alternate reset system is needed. Keep any hardware-required short delay only with evidence.
- Benefit: Eliminates an unbounded launch/exit stall (READ control flow; lost-event manifestation INFERRED). Removing the fixed delay saves one source-declared second per authorized reset; hardware benefit unmeasured.
- Effort: S. Risk: Med. Confidence: READ.

### RIPTOPL-214 / Initialize the complete Bluetooth DS4 output report / Category 6

- Location(s): `RiptOPL/modules/ds34bt/iop/ds34bt.c:1206-1273`; `RiptOPL/modules/pademu/ds34bt.c:1144-1206`; report constants `RiptOPL/modules/ds34bt/iop/ds34bt.h:243-248`, `RiptOPL/modules/pademu/ds34bt.h:223-228`.
- Problem: Both DS4 branches allocate and transmit 79 report bytes but clear only the DS3-sized 50-byte prefix. The final 29 transmitted bytes are uninitialized stack contents instead of defined reserved/report bytes.
- Simplest fix: Clear the existing report buffer using its actual size before populating it, retaining the established DS4 transfer length.
- Justification: Replacing the incorrect clear length fixes deterministic use of uninitialized output without an extra buffer or wrapper.
- Benefit: Removes 29 undefined bytes per DS4 output report (READ size arithmetic); controller effects and actual exposed contents were not examined or measured.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-215 / Preserve controller mode across USB rumble updates / Category 6

- Location(s): `RiptOPL/modules/pademu/ds34usb.c:479-525`; mode consumer `RiptOPL/modules/pademu/pademu.c:467-480`.
- Problem: `ds34usb_get_data` computes the analog-mode result, then overwrites it with the LED/rumble transfer's USB status whenever output changes. USB success is zero, so an analog controller is reported as digital to the SIO2 emulator on that poll; USB error codes can also become false mode values.
- Simplest fix: Return the existing `analog_btn & 1` after the output handling and keep USB submission status local to its existing error check.
- Benefit: Prevents output updates from changing emulated controller mode (READ); game-specific input effects are INFERRED. No new state, allocation, wrapper, or measured performance saving.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-216 / Reuse the pad translations already shipped by pademu / Category 2, 5

- Location(s): `RiptOPL/modules/pademu/ds34common.c:44-144`; existing callers `RiptOPL/modules/pademu/ds34usb.c:311-354`, `RiptOPL/modules/pademu/ds34bt.c:1209-1274`; copies `RiptOPL/modules/ds34usb/iop/ds34usb.c:309-427`, `RiptOPL/modules/ds34bt/iop/ds34bt.c:1287-1329,1342-1422`; build inputs `RiptOPL/modules/ds34usb/iop/Makefile:2`, `RiptOPL/modules/ds34bt/iop/Makefile:2`.
- Problem: The menu USB/BT drivers duplicate DS3/DS4 button, pressure, axis, and touchpad translation even though the in-game drivers already share ordinary translation functions. The duplicate DS4 implementations repeat a long switch and mutate input fields to emulate touchpad presses, while the existing function uses a bounded lookup and local output values.
- Simplest fix: Compile the existing translation source into the two menu IRXs and replace their DS3/DS4 translation bodies with the already-used function calls, retaining their LED/battery handling and the separate experimental DS5 body.
- Justification: No new helper is proposed: existing functions replace four translation copies, with substantial net source removal. Do not link unused guitar translation into these IRXs if the current linker retains unreferenced functions.
- Benefit: Roughly 200 duplicate translation lines become a handful of calls (INFERRED final net deletion); existing shared code remains. Final IRX size and speed must be measured after removal, and no shared runtime storage across separately loaded IRXs is claimed.
- Effort: M. Risk: Med (preserve report offsets and pressure-emulation flags). Confidence: READ.

### RIPTOPL-217 / Bound emulated pad slots and reply copies / Category 6

- Location(s): `RiptOPL/modules/pademu/pademu.c:348-418,421-467,553-583`; `RiptOPL/modules/pademu/ds34usb.c:479-508`; `RiptOPL/modules/pademu/ds34bt.c:1334-1345`; state layouts `RiptOPL/modules/pademu/ds34usb.h:37-43`, `RiptOPL/modules/pademu/ds34bt.h:41-48`.
- Problem: Multitap selection accepts an unchecked byte as `mtap_slot`, then uses it as the index into four-element pad arrays. Pad data copies also use `out_size - 3` without capping it to the actual 18-byte report; oversized or shorter-than-three-byte commands read beyond pad state or underflow the requested copy length.
- Simplest fix: Reject slots outside the existing four-slot limit, reject truncated commands before reading fields, and cap data copies to the existing 18-byte report while leaving the already-zeroed remainder alone.
- Justification: Local checks enforce existing array/protocol capacities and need no general validator or new buffers.
- Benefit: Removes source-proven out-of-range IOP accesses for unsupported SIO2 request shapes; occurrence in physical games is INFERRED and no separate privilege boundary is claimed.
- Effort: S. Risk: Med (respect command-specific minimum lengths). Confidence: READ.

### RIPTOPL-207 / Copy only the exception frame into the exception packet / Category 6

- Location(s): `RiptOPL/modules/debug/ps2link/excepHandler.c:12-14,55-95`; active debug build `RiptOPL/Makefile:305-319,1085-1089`.
- Problem: After advancing past the first word of `excep_buffer`, the handler copies `BUFFER_SIZE` bytes from a much smaller exception frame, overflowing the packet by four bytes and reading unrelated memory. It also calls `strlen` on a possibly missing module name and copies an unbounded module name into the reserved 128-byte suffix.
- Simplest fix: Copy `sizeof(*frame)`, treat a missing module as an empty name, and bound the existing name field to its reserved capacity before copying.
- Justification: Local sizes and a null check make the existing exception-report packet valid without a new diagnostic system.
- Benefit: Prevents the diagnostic handler from causing another IOP fault while reporting the first (READ bounds); console behavior is INFERRED. No runtime saving claimed.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-208 / Reserve the command word in the debug DMA packet / Category 6

- Location(s): `RiptOPL/modules/debug/ps2link/cmdHandler.c:39-41,136-154,240-305`; active debug build `RiptOPL/Makefile:305-319,1085-1089`.
- Problem: `pkoSendSifCmd` permits a 1,024-byte payload but copies it four bytes into a 1,024-byte array. It then transfers only the payload length despite adding the command word, losing the final four payload bytes even for ordinary requests.
- Simplest fix: Limit payload length to the array capacity minus the existing command word, and include that word in the DMA transfer size; reject oversize commands through the existing error return.
- Justification: Correcting two sizes fixes a concrete four-byte write overflow and packet truncation without a wrapper or extra buffer.
- Benefit: Correct debug command delivery and no out-of-bounds DMA-packet construction (READ). No measured byte/time saving.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-209 / Stop the debug host receive loop at socket EOF / Category 5, 6

- Location(s): `RiptOPL/modules/debug/ps2link/net_fio.c:86-101`; serializing caller `RiptOPL/modules/debug/ps2link/net_fsys.c:144-162,168-181`.
- Problem: The receive loop treats only negative `recv` results as errors. A peer closing mid-request produces zero forever, so the loop never advances and the held filesystem semaphore blocks subsequent host file operations.
- Simplest fix: Treat zero as a failed incomplete transfer and return the existing error result; close/reset the socket through the existing disconnect path.
- Justification: One terminal condition replaces an infinite loop; no timeout/retry layer is needed.
- Benefit: Prevents an unbounded IOP busy loop and blocked host filesystem after disconnect (READ; physical timing unmeasured).
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-210 / Bound debug host replies to the requested transfer / Category 6

- Location(s): `RiptOPL/modules/debug/ps2link/net_fio.c:107-159,363-413`; request/reply layouts `RiptOPL/modules/debug/ps2link/hostlink.h:79-121`.
- Problem: Reply acceptance checks only an upper packet length and accepts undersized replies containing stale fields. File reads then trust the peer's `nbytes` without requiring it to be nonnegative and no larger than the caller's requested length, allowing a response to overwrite that caller's buffer.
- Simplest fix: Require the exact fixed reply-header length and reject data lengths outside zero through the outstanding requested byte count before receiving the payload.
- Justification: Local checks enforce existing packet and caller-buffer sizes without a new protocol layer.
- Benefit: Prevents IOP overwrite and stale-reply interpretation in the debug host driver (READ); no attack or hardware reproduction performed.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-211 / Bound the debug module argument walk to its packet / Category 6

- Location(s): `RiptOPL/modules/debug/ps2link/cmdHandler.c:49-83`; `RiptOPL/modules/debug/ps2link/hostlink.h:201-207`.
- Problem: A packet's unsigned `argc` controls repeated unbounded `strlen` calls over a fixed 256-byte argument area; only its final byte is forced to NUL. Zero arguments underflows `argc - 1`, and excessive counts walk beyond the packet despite the outer packet-size check.
- Simplest fix: Reject zero or impossible argument counts and locate each terminator within the bytes remaining in the existing argument field before advancing.
- Justification: Bounded traversal repairs the current packet parser and uses its existing failure return.
- Benefit: Removes a source-proven IOP out-of-range read/runaway argument walk in debug builds; occurrence and timing are INFERRED.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-212 / Print RPC text with a fixed format and the received length / Category 6

- Location(s): `RiptOPL/modules/debug/ps2link/nprintf.c:22-34,38-51`.
- Problem: The NPM text RPC passes the received bytes directly as `printf`'s format string and ignores the supplied size. Ordinary debug text containing conversion characters can consume nonexistent arguments, and missing termination can read beyond the 512-byte RPC buffer.
- Simplest fix: Print with a fixed bounded string format, clamping the received length to the existing buffer capacity and rejecting negative sizes.
- Justification: One bounded formatting call replaces unsafe formatting; no logging framework is needed.
- Benefit: Correct printing of percent signs and bounded debug text reads (READ); no hardware exploit, size, or timing claim.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-206 / Use the filesystem adapter's existing lock once / Category 2, 3, 4, 5

- Location(s): `RiptOPL/modules/bdm/bdmfs_fatfs/src/fs_driver.c:65-99,268-300,340-391,395-409,843-936,974-1039`; `RiptOPL/modules/bdm/bdmfs_fatfs/fatfs/include/ffconf.h:295-306`; `RiptOPL/modules/bdm/bdmfs_fatfs/fatfs/ffsystem.c:67-69,113-121,190-192,223-225`; build `RiptOPL/ps2.yaml:308-314`.
- Problem: Every adapter operation that enters FatFs is already serialized by `_fs_lock_sema_id`, including mount/unmount. Enabling FatFs reentrancy adds another semaphore per mounted volume and another wait/signal pair per API call, without allowing concurrent operations through this adapter.
- Simplest fix: Disable `FF_FS_REENTRANT` for this private IRX and remove its now-empty OS-adapter compilation input; keep the existing outer lock that also protects the file/volume pools.
- Benefit: Up to ten redundant volume semaphores and repeated inner wait/signal calls removed (READ declared capacity and call graph). Resident bytes and timing are unmeasured; do not claim ten semaphores are present when fewer volumes are mounted.
- Effort: S. Risk: Med (all future FatFs call sites must retain the existing adapter lock). Confidence: READ.

### RIPTOPL-205 / Release adapter file and directory slots after failed closes / Category 4, 6

- Location(s): `RiptOPL/modules/bdm/bdmfs_fatfs/src/fs_driver.c:305-336,395-409,571-585`; `RiptOPL/modules/bdm/bdmfs_fatfs/fatfs/ff.c:4307-4333,4789-4810`.
- Problem: FatFs leaves `obj.fs` set when close fails, including after unplug invalidates the volume. The adapter nevertheless discards `fd->privdata`, while its free-slot search requires `obj.fs == NULL`, permanently losing those pool entries; sixteen failed directory closes exhaust all directory slots.
- Simplest fix: After attempting the final close, explicitly clear the owned FIL/DIR pool slot under the existing adapter lock while returning the original close error. Keep retryable synchronization before the final close where the caller actually retains ownership.
- Justification: A local slot reset reconciles ioman's final-close ownership with FatFs's retryable API; no new allocation or resource wrapper is needed.
- Benefit: Prevents exhaustion of the fixed 128-file/16-directory pools after failed closes (READ capacity and control flow); physical unplug behavior is INFERRED. No additional RAM or timing saving claimed.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-203 / Disable unused FatFs string-volume parsing that dereferences missing names / Category 1, 6

- Location(s): `RiptOPL/modules/bdm/bdmfs_fatfs/fatfs/include/ffconf.h:181-195`; `RiptOPL/modules/bdm/bdmfs_fatfs/fatfs/ff.c:481-485,3222-3261`; adapter `RiptOPL/modules/bdm/bdmfs_fatfs/src/fs_driver.c:40-60,147-174`.
- Problem: The configuration enables ten string-named volumes but initializes only one name, leaving nine null pointers. A nonnumeric volume prefix that does not match the first name advances to `VolumeStr[1]` and dereferences null; the adapter itself uses numeric prefixes and already registers the ioman device names separately.
- Simplest fix: Set `FF_STR_VOLUME_ID` to zero and remove `FF_VOLUME_STRS`; retain the existing numeric-volume mapping.
- Benefit: Removes an unnecessary parser branch/table and its IOP null-dereference path (READ); exact IRX bytes are unmeasured. Invalid-prefix occurrence through application file APIs is INFERRED.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-204 / Widen exFAT sector products before multiplying / Category 6

- Location(s): `RiptOPL/modules/bdm/bdmfs_fatfs/fatfs/ff.c:3544-3585`, especially `:3563,3579`; correct existing conversion at `:1161-1168`; `RiptOPL/modules/bdm/bdmfs_fatfs/fatfs/include/ffconf.h:218,246`.
- Problem: Although 64-bit LBAs are enabled, exFAT mount computes `ncl * fs->csize` and `fs->csize * (bcl - 2)` in 32-bit arithmetic before adding the 64-bit base. A bitmap located beyond 2 TiB of 512-byte sectors wraps its sector offset, directing later allocation-bitmap access to another region; the same overflow weakens the volume-size check.
- Simplest fix: Cast a multiplication operand to the existing `LBA_t`/`QWORD` before each product, as `clst2sect` already does; check resulting extents against the volume.
- Justification: Operand widening fixes concrete large-volume arithmetic; no new 64-bit wrapper or alternate storage path is required.
- Benefit: Correct addressing for valid large exFAT layouts (READ arithmetic); resulting corruption on a physical disk is INFERRED and was not exercised. No size or speed saving claimed.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-200 / Preserve FatFs I/O errors instead of reporting EOF / Category 6

- Location(s): `RiptOPL/modules/bdm/bdmfs_fatfs/src/fs_driver.c:450-484,635-658`.
- Problem: The filesystem adapter converts every failed `f_read`, `f_write`, and `f_readdir` into zero, which callers interpret as EOF, a zero-byte write, or a completed directory listing. A failed directory enumeration can therefore look like an empty or successfully exhausted directory instead of returning its storage error.
- Simplest fix: Return a negative I/O error for a failed FatFs call and preserve zero for actual EOF; keep the existing successful byte/entry results.
- Justification: These local return-value changes repair the existing error contract without a new mapping layer, retry, or wrapper.
- Benefit: Reliability improvement is source-backed; prevented user-visible truncation or incomplete listings are INFERRED, with no measured runtime or ELF saving.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-202 / Validate complete partition extents before mounting them / Category 6

- Location(s): `RiptOPL/modules/bdm/src/part_driver_mbr.c:12-32,115-125`; `RiptOPL/modules/bdm/src/part_driver_gpt.c:129-175`; consumer `RiptOPL/modules/bdm/src/part_driver.c:49-87`.
- Problem: MBR validation checks only the starting LBA; GPT validation checks against header-provided limits but never requires last LBA to be at least first LBA or below the physical device size. Reversed GPT endpoints underflow the advertised unsigned sector count, and oversized MBR/GPT extents pass the partition wrapper's later checks because those checks trust this count.
- Simplest fix: Before registration, require a nonzero extent wholly inside the backing device, validate GPT header usable limits against that device, and reject reversed endpoints using subtraction-based bounds.
- Justification: A few local checks enforce the bounds the existing partition read/write code already relies on; no parser layer or fallback is needed.
- Benefit: Prevents constructing invalid writable block devices from corrupt partition metadata (READ); eventual device errors or unintended access are INFERRED. No timing or size benefit claimed.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-201 / Decode all five FAT timestamp second bits / Category 6

- Location(s): `RiptOPL/modules/bdm/bdmfs_fatfs/src/fs_driver.c:590-631`, especially `:627`.
- Problem: Timestamp conversion shifts the FAT seconds field and then masks with 31, discarding the bit representing seconds 32–58. Files modified late in a minute are reported with seconds 0–26 instead.
- Simplest fix: Mask the original five-bit field before multiplying by two.
- Benefit: Correct file timestamps; the 32-second error for encoded seconds 16–29 follows directly from the arithmetic. No performance or RAM benefit claimed.
- Effort: S. Risk: Low. Confidence: READ.


### RIPTOPL-224 / Stop treating a queued disc read as a completed successful read / Category 6

- Location(s): `RiptOPL/modules/iopcore/cdvdman/ioops.c:284-348,417-470`; `RiptOPL/modules/iopcore/cdvdman/searchfile.c:106-110`; `RiptOPL/modules/iopcore/cdvdfsv/ncmd.c:189-224,305-358`; completion result `RiptOPL/modules/iopcore/cdvdman/cdvdman.c:571-579,618-700`.
- Problem: The file, directory, search, and EE-copy adapters check whether `sceCdRead` was accepted, then ignore the device error after `sceCdSync`. They advance positions/counts and copy the scratch buffer even when the asynchronous read failed, returning stale data as a successful file read or parsing the previous directory sector.
- Simplest fix: Check the existing completion error immediately after each sync and stop before copying, parsing, or advancing a failed chunk. Return the existing negative file error or existing RPC failure/partial-count contract, preserving the first device error.
- Justification: Local completion checks use the error already supplied by CDVDMAN; no retry, buffer, helper, or error framework is needed.
- Benefit: Prevents acknowledged unread bytes and stale directory/EE data after real transport errors (READ control flow; hardware occurrence INFERRED). No timing or size saving measured.
- Effort: M. Risk: Med (preserve the existing partial-read API contracts). Confidence: READ.

### RIPTOPL-225 / Use the requested sector layout and its real scratch-buffer capacity / Category 6

- Location(s): `RiptOPL/modules/iopcore/cdvdfsv/ncmd.c:120-128,175-215`; fixed allocation `RiptOPL/modules/iopcore/cdvdman/ioops.c:20-21,629-632`; eight-sector limit `RiptOPL/modules/iopcore/common/cdvdman_opl.h:65-67`; existing conversion `RiptOPL/modules/iopcore/cdvdman/ncmd.c:27-49`, `RiptOPL/modules/iopcore/cdvdman/cdvdman.c:628-689`.
- Problem: The EE adapter computes copies using 2328/2340-byte sectors but calls `sceCdRead` with a null mode, which produces packed 2048-byte sectors. Its chunk limit also remains eight sectors regardless of layout, so an aligned eight-sector 2328-byte transfer copies 18624 bytes from a 16448-byte allocation, including 2176 bytes beyond it.
- Simplest fix: Pass the already-received mode to the existing sector conversion and derive each chunk's sector count from the fixed scratch-buffer byte capacity and requested sector size, retaining the extra sector needed by alignment correction. Do not add a new raw-sector implementation or enlarge every resident buffer.
- Justification: Reuses the conversion already present in CDVDMAN and corrects the local capacity calculation.
- Benefit: Correct sector spacing and bounded EE DMA reads for supported non-2048 patterns (READ); 2176-byte over-read is arithmetic from the declared sizes, not an executed exploit. No extra resident RAM required.
- Effort: S. Risk: Med (raw-pattern and unaligned-read compatibility). Confidence: READ.

### RIPTOPL-226 / Reject invalid HDL partition counts before publishing the disc map / Category 6

- Location(s): `RiptOPL/modules/iopcore/cdvdman/device-hdd.c:19-22,30-45,57-80,111-129`; on-disc layout `RiptOPL/modules/iopcore/cdvdman/atad.h:84-98`.
- Problem: The signed on-disc `num_partitions` is narrowed into an unsigned byte without validation, then used to walk the 65-element copied part-spec array. Counts such as 66 or -1 permit out-of-bounds part specifications and incorrect physical reads, while zero still leaves `CurrentPart` consulted by the read path.
- Simplest fix: Validate the signed count against one through `HDL_NUM_PART_SPECS` before assigning it, and reject zero-length/overflowing logical extents before making the map ready. Make a rejected header fail the existing ready/read checks using the existing zero-count state.
- Justification: A small local validation is required by the fixed on-disc array; no alternate parser, map, or backup is needed.
- Benefit: Bounded map traversal and deterministic failure for damaged HDL metadata (READ); physical-device effects INFERRED. No size/timing measurement.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-227 / End HDPro and HDL-header retries after persistent I/O failure / Category 3, 5, 6

- Location(s): `RiptOPL/modules/iopcore/cdvdman/hdpro_atad.c:678-732` (especially 714-719); `RiptOPL/modules/iopcore/cdvdman/device-hdd.c:70-73`.
- Problem: HDPro retries every failed command/completion forever while holding `ata_io_sema`; the HDL backend separately retries a failed header read forever during module start. A disconnected or permanently failing drive therefore prevents the game/IOP startup or every later device user from completing, despite the drivers already returning useful error codes.
- Simplest fix: Bound the existing command attempts, leave the loop on permanent failure, run the existing finish/unlock path, and return the original error. Bound header acquisition likewise and leave the existing partition-count state unready instead of publishing a failed header.
- Justification: Removing indefinite retry behavior needs no reconnect layer or new recovery state. Preserve any short compatibility retry only where its purpose is supported by hardware evidence.
- Benefit: Persistent errors terminate instead of hanging startup or monopolizing the device lock (READ); console time saved is unmeasured/INFERRED.
- Effort: S. Risk: Med (HDPro hardware compatibility). Confidence: READ.

### RIPTOPL-228 / Preserve SCMD failure instead of reporting success with unfilled output / Category 5, 6

- Location(s): `RiptOPL/modules/iopcore/cdvdman/cdvdman.c:926-997`; output consumers `RiptOPL/modules/iopcore/cdvdman/scmd.c:12-23,196-212,224-267`.
- Problem: After up to 2501 failed busy submissions, `cdvdman_sendSCmd` still returns success; several consumers then interpret or copy uninitialized stack reply bytes. Once submission starts, three hardware-status loops have no termination bound, so the nominal retry limit does not bound a stuck command.
- Simplest fix: Return the actual submission/completion result and stop consumers before reading failed replies; apply one bounded command deadline to the existing status loops and release the existing semaphore on failure. Remove the final unconditional success and unnecessary final delay on a failed command.
- Justification: Local result/deadline handling repairs the existing hardware operation without a wrapper, fallback, or additional retry system.
- Benefit: No fabricated successful RTC/identity/model replies and bounded lock retention for a stuck Mechacon (READ control flow; occurrence/timing INFERRED). No sensitive identity bytes were collected or reproduced.
- Effort: M. Risk: Med (hardware timing). Confidence: READ.

### RIPTOPL-229 / Continue directory enumeration past the first ISO sector / Category 6

- Location(s): `RiptOPL/modules/iopcore/cdvdman/ioops.c:417-470`; directory handle extent `RiptOPL/modules/iopcore/cdvdman/ioops.c:143-149`.
- Problem: Every `dread` rereads `fh->lsn`, treats `fh->position` as an offset into that first sector, and returns end-of-directory once the position passes its boundary or encounters sector padding. A valid ISO directory extending into a second sector therefore loses all later entries even though the handle already records its complete size.
- Simplest fix: Use the existing position to select `lsn + position / 2048` and its within-sector offset, skip padding to the next sector, and stop at the existing directory filesize. Keep the existing record-boundary checks and propagate read failures as in RIPTOPL-224.
- Justification: Correct the existing iterator; no index, directory cache, or second buffer is needed.
- Benefit: Complete enumeration of valid multi-sector directories (READ); affected-game frequency is unmeasured/INFERRED.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-230 / Bound the optional PSS suffix lookup for short paths / Category 6

- Location(s): `RiptOPL/modules/iopcore/cdvdman/searchfile.c:214-221`.
- Problem: With video skipping enabled, a successfully found path shorter than six bytes indexes `strlen(path) - 6` before the static path buffer. The suffix check therefore reads unrelated memory instead of a path suffix.
- Simplest fix: Require a length of at least six before comparing the existing suffix position, computing that length once.
- Benefit: Removes the before-buffer read in the optional path (READ); no timing/RAM benefit measured.
- Effort: S. Risk: Low. Confidence: READ.

### RIPTOPL-231 / Delete the unreachable PIO transfer body in the in-game ATA fork / Category 1, 7

- Location(s): `RiptOPL/modules/iopcore/cdvdman/atad.c:470-517`; duplicate command-table entry `RiptOPL/modules/iopcore/cdvdman/atad.c:91-93`.
- Problem: `ata_pio_transfer` clears the existing hardware register and immediately returns zero, leaving its entire legacy PIO implementation unreachable. The command table also repeats the same standby-immediate command entry.
- Simplest fix: Delete the code after that unconditional return and the duplicate table row; retain the intentional PIO stub and its current public behavior unless a separate supported need requires real PIO.
- Benefit: Roughly 40 dead implementation lines and one duplicate table entry removed (READ count, final net source deletion INFERRED). Compiler likely already removes the unreachable body, so no executable/RAM saving is claimed without measurement.
- Effort: S. Risk: Low. Confidence: READ.
