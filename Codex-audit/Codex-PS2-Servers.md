# Codex audit: PS2-Servers

**-unfinished- checkpoint:** This is the earlier baseline report, preserved with its validation results. See [the resume index](Codex-RESUME-unfinished.md) and linked continuation findings for the later review. Earlier read-only statements describe source handling before the user authorized this report-only draft PR.

**Partial audit pass: 37 findings; not an exhaustive review.** No repository files or GitHub state changed. The exact remaining scope is listed below so a continuation can target only unfinished files.

Unless explicitly described as measured or as a source-declared capacity/count, proposed reductions are INFERRED until implemented. READ denotes source evidence, not hardware verification.

Snapshot: `NathanNeurotic/PS2-Servers`, default branch `main`, commit `5179b4bb1f488ef2eb91956c8792e2194dda2fca`. Scope is this snapshot, including its vendored files; licences are excluded by request. Findings are ordered by practical benefit: correctness/data integrity and responsiveness, then memory/removal opportunities.

## Evidence and limits

- Existing test command: `PYTHONDONTWRITEBYTECODE=1 XDG_CONFIG_HOME=/tmp/codex-audit-work/ps2servers-config python3 -m unittest discover -s tests -t .`. Result: **1,544 tests, 93.537 s, 4 failures, 75 skips**. All four failures are Go cross-implementation tests: the host’s `/usr/bin/go` is a Go board-game executable and rejects `go run`. They do not establish a repository regression. Other tests completed without failure. No Windows/real PS2 validation was available.
- Read-only local reproductions: legacy HTTP indexes an outside-root ISO symlink while the path-aware profile refuses it; HTTP dispatch emits a second 500 after a simulated streaming 206 failure; temporary image-mode UDPBD write extended a 65,536-byte image to 66,048 bytes and acknowledged success; busy SMB port 65535 raised OverflowError; matching synthetic Unicode SMBv1 credential raised TypeError; Edge signed/unsigned overflow arithmetic checked independently; Python index object sizes measured without creating repository files.
- No packaged build, native Go suite, or PS2 throughput/ELF-size measurement was performed. Savings marked as estimates or INFERRED are not benchmark results.
- The source tree remained clean after test execution and all reproductions. Secret-like values are not reproduced.

## PS2SERVERS-018 / Edge compressed header arithmetic can panic the whole server / Category 6

- Location(s): PS2-Servers/native/ps2servers-edge/internal/compression/image.go:198-203,251-256,330-334

- Problem: Both compressed open and size probing calculate a ceiling division by adding block-1 to an int64 image size. A declared size of INT64_MAX and block size 2 overflows negative; the subsequent uint64 index-extent arithmetic wraps to four bytes, so a 28-byte CISO reaches a negative-length make and panics.

- Fix: Use overflow-free ceiling division in both existing calculations and reject invalid zero/impossible geometry before allocating.

- Justification: A tiny malformed header can terminate the process. Replacing the arithmetic and tightening its existing condition fixes it without a new parser or fallback.

- Benefit: Process-crash bug fixed. Arithmetic independently checked; Go execution unavailable (runtime panic consequence INFERRED from Go semantics).

- Effort: S. Risk: Low. Confidence: High (READ; runtime consequence INFERRED).

## PS2SERVERS-019 / Edge UDPBD accepts write data from the wrong command / Category 6

- Location(s): PS2-Servers/native/ps2servers-edge/internal/udpbd/server.go:440-486,501-519; PS2-Servers/udpbd_server/udpbd_server.py:238-273

- Problem: The Go write handshake saves a peer and byte region but drops its command ID. WRITE_RDMA checks only the peer IP (even accepting another port) and writes sequentially into that region, so delayed data from a prior command can land in a newer command’s sectors. The Python implementation already checks the full endpoint and command ID.

- Fix: Retain the handshake command ID and compare the exact endpoint plus ID before accepting each WRITE_RDMA; remove the same-IP fallback.

- Justification: Two small state/comparison changes fix a concrete stale-packet corruption path. The already working Python rule supplies the protocol precedent; no retry mechanism or abstraction is needed.

- Benefit: Disk-image corruption risk fixed; runtime bytes/ms unmeasured.

- Effort: S. Risk: Low. Confidence: High (READ; delayed-packet runtime sequence INFERRED).

## PS2SERVERS-001 / HTTP appends a second response after a failed game body / Category 6, 5

- Location(s): PS2-Servers/http_server/http_server.py:898-931,1006-1034,1043-1093

- Problem: The game response headers are already sent when opening/reading the image fails. The outer OSError handler then appends an HTTP 500 response; the PS2 driver reads a fixed byte count, so that header can be consumed as game data. An in-memory dispatch reproduction observed a 206 followed by a 500.

- Fix: Send an error response only before game headers are committed; after a streaming failure close the connection immediately.

- Justification: This fixes the concrete response-corruption path with a small local control-flow change; no retry or wrapper is needed.

- Benefit: Real protocol/data-integrity bug fixed; byte/ms saving not measured.

- Effort: S. Risk: Low. Confidence: High (READ + local reproduction).

## PS2SERVERS-031 / Reject out-of-range UDPBD image reads/writes as raw mode already does / Category 6

- Location(s): PS2-Servers/udpbd_server/udpbd_server.py:115-130,205-228,238-260,282-304; PS2-Servers/native/ps2servers-edge/internal/udpbd/server.go:370-384,440-450

- Problem: Python range validation is restricted to raw-device reads; ordinary image writes seek to any requested sector and acknowledge data even past the image capacity. A temporary 65,536-byte image grew to 66,048 bytes after an out-of-range one-sector write and returned success. Out-of-range image reads also generate padded traffic.

- Fix: Apply the existing capacity rule to regular image reads and write handshakes, before seeking or changing write state. Use the Go implementation’s existing in-range rule as the reference.

- Justification: Two small range checks fix demonstrated image extension and avoid serving fabricated out-of-range data. They need no new storage abstraction, retry or option.

- Benefit: Image corruption/extension bug fixed; avoids up to the declared sector-count worth of wasted read traffic.

- Effort: S. Risk: Low. Confidence: High (READ + local temporary-image reproduction).

## PS2SERVERS-002 / Bound compressed serving metadata before allocating or retrying / Category 6, 4, 5

- Location(s): PS2-Servers/udpfs_server/compressed_iso/cso.py:65-89,109-150; PS2-Servers/udpfs_server/compressed_iso/zso.py:77-107,127-171; PS2-Servers/udpfs_server/compressed_iso/chd.py:262-314; PS2-Servers/udpfs_server/udpfs_server.py:364-385; PS2-Servers/http_server/http_server.py:867-879; PS2-Servers/launcher/ra_compressed_hash.py:24-55,82-84

- Problem: The serving paths bypass the geometry/index bounds used by inspection. Header-controlled table sizes, block sizes and offset differences reach allocation/read operations, and an invalid LZ4 span is retried once per byte while copying successively shorter buffers. SMBv1 checks its block cap only after constructing the reader.

- Fix: Apply the existing physical-size, geometry and offset limits before allocating a serving reader, and restrict LZ4 padding retries to the actual alignment allowance. Reuse the already implemented bounded header/block logic where compatible; keep the inspection-only total decode budget out of long-running serving.

- Justification: Malformed shared images can exhaust RAM/CPU or silently yield padded corrupt data. Moving common structural validation into the existing readers removes divergent validation and replaces the unbounded retry loop; no new layer or option is needed.

- Benefit: Prevents header-controlled allocations and quadratic retry work; actual maximum saving depends on the malformed image (INFERRED).

- Effort: M. Risk: Med. Confidence: High (READ; runtime exhaustion not attempted).

## PS2SERVERS-003 / Stop waits synchronously on the Tk thread / Category 5

- Location(s): PS2-Servers/launcher/gui.py:258-270,2961-2974,2982-3011,3699-3711; PS2-Servers/launcher/process.py:132-171; PS2-Servers/launcher/full_skin_controls.py:178-180

- Problem: The Stop callback calls ServerProcess.stop directly. That method waits for up to 3 seconds of cooperative grace (20 seconds for take-445), then up to 5 seconds of termination grace and a reader join; updating idle tasks once does not keep the event loop responsive.

- Fix: Run the existing blocking process-stop operation on a worker and finish card/status updates on the Tk thread using the worker/queue pattern already present in this GUI. Disable the affected controls until completion.

- Justification: This fixes a source-proven UI freeze. A worker around the existing stop routine is smaller than another stop supervisor or polling state machine.

- Benefit: Removes potentially multi-second UI stalls; actual stop duration is workload-dependent, not benchmarked.

- Effort: M. Risk: Med. Confidence: High (READ).

## PS2SERVERS-004 / Remove credentials from the launch log / Category 6

- Location(s): PS2-Servers/launcher/gui.py:2603-2615; PS2-Servers/launcher/servers.py:149-152,190-195

- Problem: The launch command includes the SMB account credential and is copied verbatim into the shared terminal. A support-log copy or screenshot therefore includes a credential that the ordinary UI masks.

- Fix: Delete the full command-line log, or log only the server label and selected port. Keep the process arguments unchanged for this scoped fix.

- Justification: No addition required if the command log is deleted.

- Benefit: Credential disclosure removed and one formatting/log operation per launch removed; no secret value is reproduced here.

- Effort: S. Risk: Low. Confidence: High (READ).

## PS2SERVERS-005 / Apply the HTTP root boundary to the legacy profile too / Category 6

- Location(s): PS2-Servers/http_server/http_server.py:319-342,389-392,439-499,501-510,543-560,867-879

- Problem: Only the path-aware profile calls the existing containment check. The default legacy profile indexes an .iso symlink outside the chosen games root; a temporary-file reproduction confirmed the legacy index accepts it while the path-aware index refuses it. A symlinked CD/DVD directory has the same boundary issue.

- Fix: Call the existing containment predicate for every indexed image before metadata/open work, regardless of catalogue profile. Reject an external games.csv symlink for the same reason.

- Justification: One existing check applied at the common entry point fixes the inconsistent declared-root boundary. It needs no new path abstraction.

- Benefit: Outside-root file exposure removed; negligible added work occurs during scans rather than each game read.

- Effort: S. Risk: Low. Confidence: High (READ + local reproduction).

## PS2SERVERS-020 / Edge file browsing fails open when configuration is missing or unreadable / Category 6

- Location(s): PS2-Servers/native/ps2servers-edge/internal/webui/webui.go:136-168,192-208; PS2-Servers/native/ps2servers-edge/internal/webui/api.go:24-26,351-354,383-418

- Problem: Without explicit BrowseAnywhere, a backend Load error or configuration with no roots still produces an empty root list. The API treats any empty list as permission to browse every absolute directory and defaults its first request to the filesystem root.

- Fix: Disable browsing when roots cannot be derived; reserve unrestricted browsing exclusively for the existing explicit BrowseAnywhere setting.

- Justification: This removes an error fallback that widens access. It can use the existing noBrowse control and does not need a new configuration option.

- Benefit: Restores configured directory boundary; listings expose names/sizes, not arbitrary file contents. No performance saving claimed.

- Effort: S. Risk: Low. Confidence: High (READ).

## PS2SERVERS-006 / Store compressed offset tables as uint32 arrays / Category 4

- Location(s): PS2-Servers/udpfs_server/compressed_iso/cso.py:79-89; PS2-Servers/udpfs_server/compressed_iso/zso.py:94-107; PS2-Servers/udpfs_server/compressed_iso/limits.py:47-56

- Problem: Serving materializes each 32-bit offset as a Python integer in a tuple and then a list. Inspection already demonstrates the compact array representation, so a multi-gigabyte disc needlessly consumes tens of megabytes per open reader.

- Fix: Use the existing array-of-uint32 representation and byte-order handling for serving indexes too; eliminate the intermediate unpack tuple/list.

- Justification: The same indexed data already uses this representation in inspection. A direct replacement reduces RAM without introducing an abstraction or dependency.

- Benefit: For 2,097,153 offsets (4 GiB / 2 KiB blocks + sentinel), a calculation from measured host container/integer sizes gives 75,497,564 bytes for list plus distinct 28-byte integers versus a measured 8,388,692-byte uint32 array: about 64 MiB retained saving per reader. Excludes transient tuple/input data and assumes typical distinct offsets.

- Effort: S. Risk: Low. Confidence: High (READ + host object-size measurement).

## PS2SERVERS-021 / Honor zero compressed-cache size by deleting the default fallback / Category 3, 4, 6

- Location(s): PS2-Servers/native/ps2servers-edge/internal/udpfs/blockdev.go:392-402; PS2-Servers/native/ps2servers-edge/cmd/ps2servers-edge/main.go:156; PS2-Servers/native/ps2servers-edge/internal/compression/image.go:75-95

- Problem: The CLI already defaults the cache to 32, and the image API defines zero as disabled. openImage converts an explicit zero back to 32, preventing the user from disabling the cache.

- Fix: Delete the zero-to-default block and pass cfg.CompressionCache directly to OpenCached.

- Justification: No addition required.

- Benefit: Four local lines removable; avoids retaining 32 decoded blocks per open image when zero was requested (64 KiB at 2 KiB blocks, subject to the existing per-image byte cap).

- Effort: S. Risk: Low. Confidence: High (READ).

## PS2SERVERS-032 / Delete SMBv1 port walking that makes the GUI advertise the wrong port / Category 3, 6

- Location(s): PS2-Servers/smbv1_server/smbserver_opl.py:1650-1671,1779-1789; PS2-Servers/launcher/gui.py:291-295,2627-2635; PS2-Servers/launcher/servers.py:137-138

- Problem: On a busy requested port, the server silently walks forward through 12 ports while the launcher still uses the configured port in its hint/status poller. The last ports also cross 65535; an in-memory busy-port reproduction raised OverflowError at requested port 65535.

- Fix: Bind exactly the requested port in normal mode and return the existing failure when it is unavailable. Delete the normal-mode port-walking loop; keep only the explicitly justified take-445 release wait.

- Justification: No addition required.

- Benefit: Wrong-port connection failures and port-overflow exception removed; up to 11 fallback bind attempts deleted.

- Effort: S. Risk: Low. Confidence: High (READ + local reproduction).

## PS2SERVERS-033 / Avoid non-ASCII string comparison exceptions in SMBv1 login / Category 6

- Location(s): PS2-Servers/smbv1_server/smbserver_opl.py:692-716,739-749,1730-1737

- Problem: The account configuration accepts Unicode passwords and the parser can obtain one from the Unicode field, but compare_digest receives strings. Python rejects non-ASCII str arguments; a synthetic matching Unicode login raised TypeError instead of returning a protocol result.

- Fix: Compare encoded byte strings, or reject unsupported non-ASCII credentials once when loading configuration if that is the intended protocol restriction. Do not silently discard credential characters.

- Justification: A single supported-representation change or explicit configuration validation fixes a demonstrated exception. No new authentication framework is needed.

- Benefit: Valid supported login restored or unsupported configuration rejected early; no material size saving claimed.

- Effort: S. Risk: Low. Confidence: High (READ + local synthetic-login reproduction).

## PS2SERVERS-022 / Stop reporting every established Edge UDPFS session as busy / Category 6, 5

- Location(s): PS2-Servers/native/ps2servers-edge/internal/udpfs/status.go:39-44,60-81; PS2-Servers/native/ps2servers-edge/internal/udpfs/negotiation.go:496-504; PS2-Servers/native/ps2servers-edge/internal/session/session.go:150-166

- Problem: Status uses Streaming as evidence that a transfer is active, but that flag becomes true on the first accepted payload and stays true until transport reset. A console that finishes a request and sits idle can therefore report Busy for the rest of its session.

- Fix: Derive Busy from existing outstanding transmit/write state instead of the sticky negotiation/handoff flag. Preserve the flag’s protocol meaning.

- Justification: This fixes false transfer warnings using state already present. Clearing the protocol flag would disturb handoff logic and is not the proposed fix.

- Benefit: Correct idle status and fewer false busy/stop warnings; runtime saving unmeasured.

- Effort: S. Risk: Low. Confidence: High (READ + whole-tree assignment search).

## PS2SERVERS-023 / Treat a valid block-only Edge UDPFS server as ready / Category 6

- Location(s): PS2-Servers/native/ps2servers-edge/internal/udpfs/status.go:46-57; PS2-Servers/native/ps2servers-edge/internal/udpfs/server.go:119,226-239; PS2-Servers/native/ps2servers-edge/internal/udpfs/blockdev.go:21-73

- Problem: The server supports block-device operation without a filesystem root, but serverState unconditionally returns Degraded whenever root is nil. A healthy block-only configuration is thus reported as a storage fault.

- Fix: Check the configured block-device backend when there is no filesystem root and return Ready when that existing backend is usable.

- Justification: A local branch using existing backend state fixes an advertised supported mode; no new status layer or option is needed.

- Benefit: Correct readiness report; no size or throughput saving claimed.

- Effort: S. Risk: Low. Confidence: High (READ).

## PS2SERVERS-024 / Remove ineffective dashboard configuration writes on systemd/generic hosts / Category 8, 3, 6

- Location(s): PS2-Servers/native/ps2servers-edge/internal/webui/config_json.go:14-53; PS2-Servers/native/ps2servers-edge/internal/webui/api.go:151-201; PS2-Servers/native/ps2servers-edge/internal/webui/assets/app.js:193-223; PS2-Servers/packaging/systemd/ps2servers-edge@.service:25-30; PS2-Servers/packaging/systemd/README.md:30-39

- Problem: The dashboard saves JSON and then says saved-and-applied after restart, but the shipped systemd unit reads its command arguments from per-instance environment files. Its JSON save does not affect the restarted service; the deployment guide explicitly confirms the disconnect.

- Fix: Make the JSON/generic dashboard configuration view read-only and remove or disable Save/Apply/Reset there. Keep the working UCI-backed writes on OpenWrt.

- Justification: Deleting unsupported mutations is smaller than adding another service-configuration translator and prevents a false success claim. A small backend capability distinction is only justified to preserve the existing working UCI path.

- Benefit: Removes ineffective writes and misleading controls; avoids unnecessary service restarts. Net LOC requires implementation.

- Effort: M. Risk: Med. Confidence: High (READ).

## PS2SERVERS-034 / Bound the pending GUI output queue as well as the terminal widget / Category 4, 5

- Location(s): PS2-Servers/launcher/gui.py:967,3022-3040; PS2-Servers/launcher/process.py:85-105

- Problem: The terminal trims displayed lines and each tick drains only 500 records, but the producer queue has no limit. Verbose server output above roughly 3,333 lines/second, or any period when Tk is blocked, can accumulate arbitrarily many pending strings even though most will be deleted from the widget later.

- Fix: Give the existing pending-output queue a small fixed bound and retain only recent diagnostic lines on overflow without blocking the pipe-reading thread.

- Justification: A bounded queue fixes the demonstrated mismatch between bounded display and unbounded producer. Dropping old diagnostics is simpler than another spool/logging system and does not alter protocol traffic.

- Benefit: Bounds queued-log RAM; avoids formatting/rendering lines that would immediately be discarded. Peak saving depends on log volume.

- Effort: S. Risk: Low. Confidence: High (READ; sustained log-flood impact INFERRED).

## PS2SERVERS-036 / Cap idle accepted SMB/HTTP clients instead of unbounded thread creation / Category 6, 4

- Location(s): PS2-Servers/smbv1_server/smbserver_opl.py:1824-1845; PS2-Servers/smb2_server/smb2_server.py:337-362,385-397; PS2-Servers/http_server/http_server.py:1097-1105; PS2-Servers/nfs4_server/nfs4_server.py:54,438-460

- Problem: SMBv1 and SMB2 spawn a new daemon thread for every accepted connection with blocking receives and no connection cap; HTTP inherits the same unbounded thread-per-connection behavior. Idle peers can exhaust threads and descriptors even before a valid request. NFS and UDPFS already recognize and bound this resource.

- Fix: Use a small fixed admission bound at each existing accept/request boundary and release the slot on close. Refuse excess clients; do not add retry queues, thread pools or another configurable knob.

- Justification: This is a concrete unbounded-allocation path reachable on a socket. A fixed semaphore/admission count is the smallest bounded fix and preserves long-idle console connections.

- Benefit: Thread/descriptor use becomes bounded; no arbitrary per-thread RAM or throughput number claimed.

- Effort: M. Risk: Low. Confidence: High (READ; exhaustion under many peers INFERRED).

## PS2SERVERS-007 / Delete the obsolete fake SMB2/3 implementation in the SMBv1 server / Category 1, 8, 6

- Location(s): PS2-Servers/smbv1_server/smbserver_opl.py:421-422,455-463,508-637,652-666,1435-1454,1518-1524,1692-1694,1718-1728; PS2-Servers/launcher/servers.py:169-208

- Problem: A complete separate SMB2/3 server is the launcher target, but the SMBv1 server still contains old handlers that ignore CREATE paths, return empty READ data and acknowledge WRITE without writing. Those handlers are reachable even on the SMBv1 default because dispatch accepts SMB2 magic unconditionally.

- Fix: Delete the fake handlers, their parser/header/dispatch/counters and the incomplete CLI modes. Keep the real SMB2/3 server as the sole implementation.

- Justification: No addition required.

- Benefit: Roughly 180 source lines plus stub-specific tests/counters removable; prevents misleading successful operations. Packaged-byte saving not measured.

- Effort: S. Risk: Low. Confidence: High (READ).

## PS2SERVERS-008 / Replace GUI import interception and monkeypatch chains with direct calls / Category 3, 2

- Location(s): PS2-Servers/launcher/__init__.py:14-92; PS2-Servers/launcher/main.py:115-466; PS2-Servers/launcher/asset_skin.py:25-56,152-164; PS2-Servers/launcher/full_skin_controls.py:9-16,198-204; PS2-Servers/launcher/gui.py:439-550,950-1020,1307-1478,3042-3050

- Problem: Importing the launcher installs a process-wide meta_path finder/loader solely to intercept its own GUI. That hook then wraps build methods; main, asset_skin and full_skin_controls replace more methods/classes and need idempotence flags, captured originals and import-error fallbacks.

- Fix: Call the existing theme/panel/control code from LauncherApp and ServerCard at their actual construction points. Put the single intended log implementation directly in LauncherApp, then delete import finders/loaders and runtime replacement glue.

- Justification: The code already has one known GUI and concrete call sites. Direct calls remove interception code and state while preserving panels and behavior; no plugin mechanism or replacement abstraction is justified.

- Benefit: At least the 79-line import hook plus multiple wrapping/guard blocks removed (net line count requires implementation); fewer imports and startup hooks, milliseconds unmeasured.

- Effort: M. Risk: Med. Confidence: High (READ).

## PS2SERVERS-016 / Collapse the two game-library stacks into the existing catalogue UI / Category 2, 3

- Location(s): PS2-Servers/launcher/gui.py:641-648,1413-1417; PS2-Servers/launcher/library_gui.py:14-208,267-357; PS2-Servers/launcher/library_panel.py:58-187,386-507; PS2-Servers/launcher/game_library.py:59-224,226-375; PS2-Servers/launcher/library_index.py:109-190

- Problem: The general Library tab and achievements Library window independently implement browsing, imports, metadata editing, covers, backup and SQLite catalogues. A further adapter is needed to reconcile the two stores even though they address the same images.

- Fix: Keep one of the existing catalogue/storage implementations and expose achievement-specific matching/status in that existing UI. Remove the second scan/import/cover/window/database path after migrating the data that users actually have.

- Justification: The concrete duplication spans multiple working implementations, and consolidation deletes a stack rather than creating a new generic library framework. Migration is required to preserve users’ metadata.

- Benefit: Hundreds of overlapping source lines and a separate catalogue/window can be removed; precise net LOC and disk saving require a migration design.

- Effort: L. Risk: High. Confidence: Med (READ; final consolidation boundary INFERRED).

## PS2SERVERS-012 / Use the existing libchdr loader for dependency status / Category 2, 3

- Location(s): PS2-Servers/launcher/optional_deps.py:60-209; PS2-Servers/udpfs_server/compressed_iso/chd.py:25-176; PS2-Servers/launcher/dependency_panel.py:51-82

- Problem: The dependency UI has its own path discovery, PATH/DLL-directory mutation, candidate names and LoadLibrary loop, duplicating the decoder loader. It checks only that a DLL loads, whereas the actual decoder also declares required APIs, so the two can disagree about readiness.

- Fix: Use the actual compressed reader module availability/error result for the dependency panel; remove its independent native-loader copy. Keep any short display formatting.

- Justification: Two implementations already exist. Reusing the authoritative existing loader removes roughly a hundred lines and prevents a false-ready result; no new shared module is needed.

- Benefit: Approximately 120-150 duplicate loader lines removable; duplicate DLL probes and process PATH mutations avoided.

- Effort: M. Risk: Med. Confidence: High (READ).

## PS2SERVERS-009 / Delete the second complete set of ttk style definitions / Category 2, 3

- Location(s): PS2-Servers/launcher/main.py:154-327; PS2-Servers/launcher/asset_skin.py:59-149

- Problem: main applies a large style table and asset_skin immediately overwrites many of the same styles. Sharing palette constants stopped color drift but did not remove duplicate configuration calls or ownership.

- Fix: Keep the final effective values in one existing theme function and remove the overwritten definitions and palette-key remapping dictionary.

- Justification: No new helper is required: this consolidates two real implementations into one.

- Benefit: About 90 duplicated/remapping lines and dozens of Tk style calls removable; exact package/startup saving unmeasured.

- Effort: S. Risk: Low. Confidence: High (READ).

## PS2SERVERS-010 / Delete loaded tab artwork that status dots always supersede / Category 1, 4, 5

- Location(s): PS2-Servers/launcher/asset_skin.py:11-56,164; PS2-Servers/launcher/theme_assets.py:13-15; PS2-Servers/launcher/gui.py:650-668,1392-1409,1715-1740; PS2-Servers/build/build.py:241-244; PS2-Servers/launcher/assets/theme/ICON_SMB.png; PS2-Servers/launcher/assets/theme/ICON_UDPFS.png; PS2-Servers/launcher/assets/theme/ICON_UDPBD.png

- Problem: The skin eagerly loads three tab icons, but normal nb.add calls already supply a status-dot image, so setdefault never installs an icon. If status-image generation fails the fallback tab text includes a leading status glyph and no longer matches the icon lookup key. Later status updates also use the dots.

- Fix: Delete the unreachable tab-icon hook, its three registry entries and the three PNG files; retain the actual running/stopped status indicators.

- Justification: No addition required.

- Benefit: 36,126 tracked PNG bytes and roughly 45 hook lines removed; three image loads/subsamples avoided per startup. Archive compression and elapsed time unmeasured.

- Effort: S. Risk: Low. Confidence: High (READ + file-size measurement).

## PS2SERVERS-011 / Ship the About logo at its rendered resolution / Category 4, 5

- Location(s): PS2-Servers/launcher/assets/theme/LOGO.png; PS2-Servers/launcher/gui.py:1516-1530; PS2-Servers/launcher/theme_assets.py:78-92

- Problem: The PNG is 1229 by 1185 pixels (602,983 bytes), while photo_fit loads the whole image and then integer-subsamples it for the small About-panel bounds. The About tab is built eagerly during startup.

- Fix: Pre-size the shipped PNG to the exact dimensions produced by the current subsampling and load that file directly. Preserve its visible design.

- Justification: No runtime addition is required; removing oversized source pixels lowers both decode work and peak RAM.

- Benefit: Original full RGBA surface is about 5.56 MiB before Tk overhead; most of that temporary decode surface is avoidable. Output PNG bytes/startup time require measurement after resizing.

- Effort: S. Risk: Low. Confidence: High (READ + PNG header/file-size measurement).

## PS2SERVERS-013 / Accept original OPL ZSO files when importing images / Category 6

- Location(s): PS2-Servers/launcher/game_library.py:298-305,350-363; PS2-Servers/udpfs_server/compressed_iso/zso.py:39-40,72-76

- Problem: The decoder accepts both ZISO and original ZSO magic, but the import/download validator accepts only ZISO for a .zso name. A valid OPL ZSO is copied completely and then rejected.

- Fix: Accept the two already supported magic values in the import validator, preferably by reusing the existing format fact rather than another conflicting constant.

- Justification: A small comparison change fixes a real supported-format rejection; no additional parsing layer is needed.

- Benefit: Valid import restored; avoids a full wasted copy for an original-format ZSO (bytes/time depend on image size).

- Effort: S. Risk: Low. Confidence: High (READ).

## PS2SERVERS-014 / Remove unconditional pre-import database snapshots / Category 3, 5

- Location(s): PS2-Servers/launcher/game_library.py:178-224; PS2-Servers/launcher/library_gui.py:295-306

- Problem: Every catalogue import creates a uniquely named full database copy before a transactional merge that only inserts missing records. Repeated imports, including no-op imports, accumulate snapshots indefinitely; a manual backup action already exists.

- Fix: Delete the automatic snapshot creation and its return/UI plumbing. Keep the existing SQLite transaction and explicit user-requested backup action.

- Justification: No addition required; rollback already handles failed merges. This recommendation intentionally removes automatic undo snapshots, so users who need one use the explicit existing action.

- Benefit: One full database copy and one persistent snapshot per import removed; disk bytes equal the current database size each time.

- Effort: S. Risk: Med. Confidence: High (READ).

## PS2SERVERS-015 / Avoid repeated synchronous IP enumeration during Refresh/startup / Category 5, 2

- Location(s): PS2-Servers/launcher/gui.py:1320-1327,1781-1785; PS2-Servers/launcher/netinfo.py:62-81,107-119,134-136,224-234

- Problem: Refresh calls ip_choices/all_ipv4/best_lan_ip in sequence on the Tk thread, repeating hostname lookup and, on POSIX, an external command with a 3-second timeout. Startup also fills the dropdown synchronously before mainloop.

- Fix: Take one address snapshot on the existing background-worker pattern and derive dropdown/best choice from that snapshot; update Tk once when it completes.

- Justification: This removes duplicate scans and fixes a concrete blocking path. Reuse the GUI worker mechanism; do not add another networking service or cache layer.

- Benefit: One or more repeated lookups/processes per Refresh eliminated; avoids up to seconds of external-command delay on the UI thread, actual machine timing unmeasured.

- Effort: S. Risk: Low. Confidence: High (READ).

## PS2SERVERS-025 / Remove an allocation/copy from every Edge UDPBD datagram / Category 5, 4

- Location(s): PS2-Servers/native/ps2servers-edge/internal/udpbd/server.go:291-325,440-519

- Problem: The receive loop clones buf[:n] before synchronous dispatch. The handlers consume the payload immediately, copy retained peer identity into strings and do not retain the packet slice.

- Fix: Pass buf[:n] directly to dispatch; keep ownership synchronous.

- Justification: No addition required.

- Benefit: One heap allocation and n-byte copy per incoming datagram eliminated; packets/second and ms not benchmarked.

- Effort: S. Risk: Low. Confidence: High (READ; packet-retention review scoped to these handlers).

## PS2SERVERS-026 / Cap OpenWrt service-log snapshots at the existing requested limit / Category 5, 4, 6

- Location(s): PS2-Servers/native/ps2servers-edge/internal/webui/service.go:67-100,173-176,208-212

- Problem: The OpenWrt ServiceLogs implementation ignores its lines argument and captures every matching logread line into memory. The systemd implementation already clamps its output, so the same dashboard has different resource behavior on the smaller target.

- Fix: Pass the existing clamped line limit to logread if its supported invocation permits it; otherwise retain only that many lines while reading, rather than capturing the full output and truncating afterward.

- Justification: This fixes an explicit resource bound that is currently ignored. Reusing the existing limit needs no new UI option or logging system.

- Benefit: Memory/response size bounded to the existing 500-line maximum; saving depends on router log volume.

- Effort: S. Risk: Low. Confidence: High (READ; exact deployed logread flag availability INFERRED).

## PS2SERVERS-030 / Delete the generated-password escape path for remote dashboards / Category 3, 6

- Location(s): PS2-Servers/native/ps2servers-edge/internal/webui/webui.go:56-58,98-107,180-190,271-274; PS2-Servers/native/ps2servers-edge/internal/logging/logging.go:22-25

- Problem: The insecure remote-bind path invents a password and exposes it only through an info log. With quiet logging it accepts the configuration but suppresses the only credential display, leaving the operator unable to log in. GeneratedPassword has no production caller.

- Fix: Require the already supported explicit password for non-loopback binds and delete the insecure auto-generation path, unused accessor and its output plumbing.

- Justification: No addition required; this removes a redundant credential mode instead of adding another output channel or exception to quiet logging.

- Benefit: Roughly 20-30 lines plus crypto-random/base64 imports removable; fixes the quiet-mode lockout.

- Effort: S. Risk: Med. Confidence: High (READ + reference search).

## PS2SERVERS-035 / Use mutable receive buffers instead of copying every prefix / Category 5, 2

- Location(s): PS2-Servers/smbv1_server/smbserver_opl.py:183-190; PS2-Servers/smb2_server/smb2_wire.py:27-34

- Problem: Both SMB framing implementations repeatedly append each recv fragment to immutable bytes. Fragmented large packets therefore recopy the complete accumulated prefix each iteration.

- Fix: Accumulate into a bytearray with extend (or recv_into a pre-sized buffer) and convert once at completion. Keep the existing framing contract.

- Justification: A direct container replacement removes repeated work; no helper or protocol abstraction is required.

- Benefit: Changes fragmented receive copying from quadratic to linear. A 16 MiB body received in 1 KiB chunks entails about 128 GiB of prefix copying in the current algorithm (calculated, INFERRED workload), versus about 16 MiB of accumulation plus final conversion.

- Effort: S. Risk: Low. Confidence: High (READ; workload calculation INFERRED).

## PS2SERVERS-037 / Reuse the existing SMB transaction response builder / Category 2

- Location(s): PS2-Servers/smbv1_server/smbserver_opl.py:1128-1153,1331-1362

- Problem: RAP NetShareEnum rebuilds the same alignment, offsets, 10-word header and padding that _build_trans2_reply already implements. The two envelopes are identical despite their different command dispatch.

- Fix: Return the existing builder’s result for RAP parameters/data and delete the repeated response-envelope construction.

- Justification: The identical envelope appears in two real call sites; reusing the already present function removes about 15 lines, with no new helper.

- Benefit: About 15 duplicated source lines removed; binary saving small/unmeasured.

- Effort: S. Risk: Low. Confidence: High (READ).

## PS2SERVERS-027 / Delete unused ACK payload/state instead of maintaining it / Category 1, 3

- Location(s): PS2-Servers/native/ps2servers-edge/internal/session/session.go:55-58,78,88,118-123,144,167-172; PS2-Servers/native/ps2servers-edge/internal/udpfs/transfer.go:46-64; PS2-Servers/native/ps2servers-edge/internal/udpfs/negotiation.go:27,114; PS2-Servers/native/ps2servers-edge/internal/udpfs/operations.go:586,643; PS2-Servers/native/ps2servers-edge/internal/udpfs/blockdev.go:303; PS2-Servers/native/ps2servers-edge/internal/compression/chd_cuebin_enabled.go:21

- Problem: Production code discards every AckEvent payload and reads the authoritative ACK state under the session lock. WriteTotalChunks is only assigned/reset, and cdBinCacheBytes is never referenced. A test reads the ACK flag, but that does not make it part of the production contract.

- Fix: Use chan struct{} for wakeups, delete the event fields/type and write-only fields/assignments/constant, and simplify the tests to the actual wakeup contract.

- Justification: No new abstraction is required; this removes unused state from existing structures.

- Benefit: Small per-session channel storage/field saving plus roughly a dozen definitions/assignments removed. Exact binary saving unmeasured.

- Effort: S. Risk: Low. Confidence: High (READ + repository-wide reference search).

## PS2SERVERS-028 / Delete redundant zeroing, sorting and TCP option calls / Category 1, 5

- Location(s): PS2-Servers/native/ps2servers-edge/internal/udpbd/server.go:77-85; PS2-Servers/native/ps2servers-edge/internal/smb/handlers.go:873-883; PS2-Servers/native/ps2servers-edge/internal/smb/server.go:286-292

- Problem: A freshly make-allocated byte slice is zeroed again after a short read; names copied from sorted os.ReadDir output are sorted again; accepted Go TCP sockets explicitly enable TCP_NODELAY despite the documented default. The source itself justifies the last one only against a hypothetical future default change.

- Fix: Delete the zeroing loop, second sort and explicit SetNoDelay block.

- Justification: No addition required.

- Benefit: A short-read suffix pass, one O(n log n) sort per SMB directory scan and one setsockopt per connection removed; about 12 lines deleted.

- Effort: S. Risk: Low. Confidence: High (READ; Go standard-library documented contracts).

## PS2SERVERS-029 / Replace the handwritten integer formatter with the standard library / Category 3, 1

- Location(s): PS2-Servers/native/ps2servers-edge/internal/smb/server.go:244-256

- Problem: The SMB package implements decimal integer conversion in a custom 8-byte buffer. Its current callers only need ordinary integer-to-text conversion.

- Fix: Use strconv.Itoa at the existing call sites and delete itoa.

- Justification: A standard-library call replaces 13 local lines without a new dependency. It also removes the formatter’s implicit nonnegative/eight-digit precondition.

- Benefit: 13 helper lines removable; binary size change is unmeasured and may be neutral because strconv is already linked elsewhere.

- Effort: S. Risk: Low. Confidence: High (READ).

## PS2SERVERS-017 / Remove unused completeness/diagnostic helpers / Category 1

- Location(s): PS2-Servers/smb2_server/smb2_auth.py:169-177,221-232; PS2-Servers/smb2_server/smb2_crypto.py:186-189

- Problem: lmv2_response and blob_timestamp have only tests as callers; native_cmac_name has no caller. The first helper explicitly says it exists for completeness although authentication never accepts it as proof.

- Fix: Delete the unused helpers, their tests and the timestamp-only constant if no longer referenced.

- Justification: No addition required.

- Benefit: 25 function-body/docstring lines plus timestamp constant/comment and tests removable; runtime size saving small and unmeasured.

- Effort: S. Risk: Low. Confidence: High (READ + repository reference search).

## Coverage and unfinished work

Tracked inventory: **596 files**: **49 fully read**, **28 partially read**, **519 not source-read** (including excluded licences and binary fixtures). Full reads below are source review, not merely searches or test execution. Large console outputs that were truncated are treated conservatively as partial unless their missing spans were read subsequently. The Edge child failed before a coverage/report handoff; included Edge findings were subsequently checked against the cited source by the parent reviewer. Unverified child coverage is not counted.

Fully read files:


- `AGENTS.md`

- `SECURITY.md`

- `launcher/__init__.py`

- `launcher/main.py`

- `launcher/optional_deps.py`

- `launcher/asset_skin.py`

- `launcher/full_skin_controls.py`

- `launcher/theme.py`

- `launcher/theme_assets.py`

- `launcher/config.py`

- `launcher/process.py`

- `launcher/serve.py`

- `launcher/netinfo.py`

- `launcher/dependency_panel.py`

- `launcher/single_instance.py`

- `launcher/path_access.py`

- `launcher/ra_set_client.py`

- `launcher/ra_http.py`

- `launcher/ra_compressed_hash.py`

- `launcher/library_index.py`

- `launcher/library_panel.py`

- `launcher/library_gui.py`

- `http_server/http_server.py`

- `nfs4_server/nfs4_server.py`

- `udpfs_server/compressed_iso/base.py`

- `udpfs_server/compressed_iso/cso.py`

- `udpfs_server/compressed_iso/zso.py`

- `udpfs_server/compressed_iso/limits.py`

- `udpfs_server/compressed_iso/chd.py`

- `build/build.py`

- `build/build_achievements.py`

- `.github/workflows/ci.yml`

- `requirements-build.txt`

- `docs/FULL-TEST-RUN.md`

- `native/ps2servers-edge/internal/logging/logging.go`

- `native/ps2servers-edge/internal/webui/webui.go`

- `native/ps2servers-edge/internal/webui/config_json.go`

- `native/ps2servers-edge/internal/udpfs/status.go`

- `packaging/systemd/ps2servers-edge@.service`

- `udpbd_server/udpbd_server.py`

- `smbv1_server/smbserver_opl.py`

- `smb2_server/smb2_paths.py`

- `launcher/game_library.py`

- `launcher/achievements.py`

- `launcher/ra_evaluator.py`

- `launcher/ra_watchlist.py`

- `launcher/ra_sets.py`

- `native/ra_watch_probe.c`

- `build/build_ra_evaluator.py`


Partially read files (cited spans and selected call paths; remaining spans unfinished):


- `launcher/ra_owned_service.py`

- `native/ps2servers-edge/internal/compression/image.go`

- `native/ps2servers-edge/internal/udpbd/server.go`

- `native/ps2servers-edge/internal/udpfs/server.go`

- `native/ps2servers-edge/internal/udpfs/blockdev.go`

- `native/ps2servers-edge/internal/udpfs/negotiation.go`

- `native/ps2servers-edge/internal/udpfs/transfer.go`

- `native/ps2servers-edge/internal/udpfs/operations.go`

- `native/ps2servers-edge/internal/session/session.go`

- `native/ps2servers-edge/internal/smb/server.go`

- `native/ps2servers-edge/internal/smb/handlers.go`

- `native/ps2servers-edge/internal/webui/api.go`

- `native/ps2servers-edge/internal/webui/service.go`

- `native/ps2servers-edge/internal/webui/assets/app.js`

- `native/ps2servers-edge/cmd/ps2servers-edge/main.go`

- `native/ps2servers-edge/internal/compression/chd_cuebin_enabled.go`

- `packaging/systemd/README.md`

- `launcher/gui.py`

- `launcher/servers.py`

- `launcher/app_icon.py`

- `launcher/session_stats.py`

- `smb2_server/smb2_server.py`

- `smb2_server/smb2_auth.py`

- `smb2_server/smb2_crypto.py`

- `smb2_server/smb2_spnego.py`

- `smb2_server/smb2_wire.py`

- `udpfs_server/udpfs_server.py`


Files not yet read (exact list; reason: review capacity consumed by the cited production paths; continuation required unless binary/licence):


- `.claude/settings.json`

- `.coderabbit.yaml`

- `.gitattributes`

- `.github/dependabot.yml`

- `.github/release-notes-common.md`

- `.github/scripts/check_ai_attribution.py`

- `.github/scripts/release-downloads.sh`

- `.github/workflows/attribution-policy.yml`

- `.github/workflows/edge-build.yml`

- `.github/workflows/edge.yml`

- `.github/workflows/release-on-main.yml`

- `.github/workflows/release.yml`

- `.github/workflows/udpfs-transport-replay.yml`

- `.gitignore`

- `ANTIVIRUS-NOTICE.md`

- `CLAUDE.md`

- `LICENSE` — licence excluded by request.

- `NOTICE.md` — licence excluded by request.

- `README.md`

- `Start-Launcher.bat`

- `THIRD_PARTY_NOTICES.md` — licence excluded by request.

- `build/achievements.nuitka-package.config.yml`

- `build/build_libchdr.py`

- `conformance/README.md`

- `conformance/fixtures/handshake_cases.json`

- `conformance/integration/http_probe.py`

- `conformance/integration/libsmb2/run.py`

- `conformance/integration/neutrino_nfs/probe.c`

- `conformance/integration/neutrino_nfs/run.py`

- `conformance/integration/neutrino_smb/probe.c.in`

- `conformance/integration/neutrino_smb/run.py`

- `conformance/integration/opl_http/csv.c.in`

- `conformance/integration/opl_http/range.c.in`

- `conformance/integration/opl_http/run.py`

- `conformance/integration/riptopl_http/catalog.c.in`

- `conformance/integration/riptopl_http/run.py`

- `conformance/integration/udpbd_probe.py`

- `conformance/integration/udpfs_parity.py`

- `conformance/integration/udpfs_probe.py`

- `conformance/ra_dependency/README.md`

- `conformance/ra_dependency/check_progress_dates.py`

- `conformance/ra_dependency/check_watchlist.py`

- `conformance/ra_dependency/progress_dates.c`

- `conformance/ra_dependency/watchlist-baseline.txt`

- `conformance/ra_dependency/watchlist.c`

- `conformance/ra_dependency/watchlist_owned.c`

- `docs/.nojekyll`

- `docs/COMPANION-CAPABILITY-MATRIX.md`

- `docs/EDGE-ARCHITECTURE.md`

- `docs/EDGE-WHICH-BUILD.md`

- `docs/EDGE.md`

- `docs/EDITIONS.md`

- `docs/HTTP.md`

- `docs/INSTRUCTIONS.md`

- `docs/ISSUE-249-HANDOFF.md`

- `docs/LIBRARY-INDEXING.md`

- `docs/NETWORK-TOOLS-ROADMAP.md`

- `docs/NFS.md`

- `docs/OPENWRT.md`

- `docs/PLAN-NBD-AND-PS2CLIENT.md`

- `docs/PROTOCOL-COMPATIBILITY.md`

- `docs/RA-ACCOUNT.md`

- `docs/RA-COMPATIBILITY-HANDOFF.md`

- `docs/RA-EVALUATOR.md`

- `docs/RA-HOST-ACCEPTANCE.md`

- `docs/RA-OPL-COMPATIBILITY.md`

- `docs/RA-ORBIT-COMPATIBILITY.md`

- `docs/RA-OWNED-RUNTIME.md`

- `docs/RA-UPSTREAM-AUDIT.md`

- `docs/RETROACHIEVEMENTS-PARITY.md`

- `docs/RETROACHIEVEMENTS.md`

- `docs/ROUTER-STATUS.md`

- `docs/SMB.md`

- `docs/THIRD-PARTY.md`

- `docs/UDPFS-CORE-TROUBLESHOOTING.md`

- `docs/UDPFS-HANDOFF-DIAGNOSTICS.md`

- `docs/UDPFS-LEGACY-ACKS.md`

- `docs/antivirus-transparency.md`

- `docs/antivirus.html`

- `docs/assets/app.js`

- `docs/assets/favicon.png` — binary asset/fixture; inventory/header/size only, not source text.

- `docs/assets/favicon.svg`

- `docs/assets/hero-grid.svg`

- `docs/assets/ps2servers-banner.png` — binary asset/fixture; inventory/header/size only, not source text.

- `docs/assets/style.css`

- `docs/cli.html`

- `docs/compression.html`

- `docs/credits.html`

- `docs/data/search-index.json`

- `docs/dependency-panel.md`

- `docs/edge-builds.html`

- `docs/edge-manual.html`

- `docs/edge.html`

- `docs/editions.html`

- `docs/falsepositives.html`

- `docs/getting-started.html`

- `docs/http.html`

- `docs/index.html`

- `docs/nbd-ps2client.html`

- `docs/nfs.html`

- `docs/openwrt.html`

- `docs/optional-compression-dependencies.md`

- `docs/protocol-compatibility.html`

- `docs/releases.html`

- `docs/router-status.html`

- `docs/smb.html`

- `docs/styles.css`

- `docs/udpbd.html`

- `docs/udpfs-diagnostics.html`

- `docs/udpfs.html`

- `launcher/__main__.py`

- `launcher/achievement_loader.py`

- `launcher/achievement_viewer.py`

- `launcher/art_fetch.py`

- `launcher/assets/theme/ICON_SMB.png` — binary asset/fixture; inventory/header/size only, not source text.

- `launcher/assets/theme/ICON_UDPBD.png` — binary asset/fixture; inventory/header/size only, not source text.

- `launcher/assets/theme/ICON_UDPFS.png` — binary asset/fixture; inventory/header/size only, not source text.

- `launcher/assets/theme/LOGO.png` — binary asset/fixture; inventory/header/size only, not source text.

- `launcher/caduceus.py`

- `launcher/directlink.py`

- `launcher/disc_identity.py`

- `launcher/discord_presence.py`

- `launcher/elevate.py`

- `launcher/library_catalog.py`

- `launcher/posix_firewall.py`

- `launcher/ps1_index.py`

- `launcher/ps1_vcd.py`

- `launcher/ra_account.py`

- `launcher/ra_account_probe.py`

- `launcher/ra_account_worker.py`

- `launcher/ra_credentials.py`

- `launcher/ra_evaluated_receiver.py`

- `launcher/ra_notifications.py`

- `launcher/ra_overview.py`

- `launcher/ra_protocol.py`

- `launcher/ra_receiver.py`

- `launcher/ra_resolver_process.py`

- `launcher/ra_session.py`

- `launcher/ra_session_client.py`

- `launcher/ra_setup.py`

- `launcher/ra_sounds.py`

- `launcher/ra_submissions.py`

- `launcher/ra_web.py`

- `launcher/raw_storage.py`

- `launcher/release_metadata.py`

- `launcher/riptopl_export.py`

- `launcher/riptopl_profile.py`

- `launcher/session_view.py`

- `launcher/setup_guide.py`

- `launcher/status_client.py`

- `launcher/status_dot.py`

- `launcher/tray.py`

- `launcher/tray_linux.py`

- `launcher/virtual_exfat.py`

- `launcher/windows_setup.py`

- `native/ps2servers-edge/README.md`

- `native/ps2servers-edge/cmd/ps2servers-edge/main_test.go`

- `native/ps2servers-edge/go.mod`

- `native/ps2servers-edge/go.sum`

- `native/ps2servers-edge/internal/compression/cache_budget_test.go`

- `native/ps2servers-edge/internal/compression/chd.go`

- `native/ps2servers-edge/internal/compression/chd_cuebin.go`

- `native/ps2servers-edge/internal/compression/chd_cuebin_disabled.go`

- `native/ps2servers-edge/internal/compression/chd_cuebin_test.go`

- `native/ps2servers-edge/internal/compression/chd_disabled.go`

- `native/ps2servers-edge/internal/compression/chd_disabled_test.go`

- `native/ps2servers-edge/internal/compression/chd_enabled.go`

- `native/ps2servers-edge/internal/compression/chd_enabled_test.go`

- `native/ps2servers-edge/internal/compression/chd_libchdr.h`

- `native/ps2servers-edge/internal/compression/chd_test.go`

- `native/ps2servers-edge/internal/compression/corrupt_index_test.go`

- `native/ps2servers-edge/internal/compression/image_test.go`

- `native/ps2servers-edge/internal/compression/lz4.go`

- `native/ps2servers-edge/internal/compression/lz4_test.go`

- `native/ps2servers-edge/internal/compression/sizeof_test.go`

- `native/ps2servers-edge/internal/compression/testdata/README.md`

- `native/ps2servers-edge/internal/compression/testdata/test.iso` — binary asset/fixture; inventory/header/size only, not source text.

- `native/ps2servers-edge/internal/compression/testdata/test_cd.chd` — binary asset/fixture; inventory/header/size only, not source text.

- `native/ps2servers-edge/internal/compression/testdata/test_dvd.chd` — binary asset/fixture; inventory/header/size only, not source text.

- `native/ps2servers-edge/internal/filesystem/root.go`

- `native/ps2servers-edge/internal/filesystem/root_test.go`

- `native/ps2servers-edge/internal/memory/budget.go`

- `native/ps2servers-edge/internal/memory/budget_test.go`

- `native/ps2servers-edge/internal/protocol/packet.go`

- `native/ps2servers-edge/internal/protocol/packet_test.go`

- `native/ps2servers-edge/internal/protocol/status.go`

- `native/ps2servers-edge/internal/sessionstats/sessionstats.go`

- `native/ps2servers-edge/internal/sessionstats/sessionstats_test.go`

- `native/ps2servers-edge/internal/smb/integration_test.go`

- `native/ps2servers-edge/internal/smb/limits_test.go`

- `native/ps2servers-edge/internal/smb/session_summary_test.go`

- `native/ps2servers-edge/internal/smb/status_test.go`

- `native/ps2servers-edge/internal/smb/wire.go`

- `native/ps2servers-edge/internal/smb/wire_test.go`

- `native/ps2servers-edge/internal/smb/write_semantics_test.go`

- `native/ps2servers-edge/internal/statuslistener/listener.go`

- `native/ps2servers-edge/internal/udpbd/protocol.go`

- `native/ps2servers-edge/internal/udpbd/session_summary_test.go`

- `native/ps2servers-edge/internal/udpbd/udpbd_test.go`

- `native/ps2servers-edge/internal/udpfs/blockdev_test.go`

- `native/ps2servers-edge/internal/udpfs/blockonly_test.go`

- `native/ps2servers-edge/internal/udpfs/chd_operations_test.go`

- `native/ps2servers-edge/internal/udpfs/compression_operations_test.go`

- `native/ps2servers-edge/internal/udpfs/errno.go`

- `native/ps2servers-edge/internal/udpfs/errno_other.go`

- `native/ps2servers-edge/internal/udpfs/errno_test.go`

- `native/ps2servers-edge/internal/udpfs/errno_windows.go`

- `native/ps2servers-edge/internal/udpfs/fileid_bwrite_test.go`

- `native/ps2servers-edge/internal/udpfs/handoff_write_test.go`

- `native/ps2servers-edge/internal/udpfs/integration_test.go`

- `native/ps2servers-edge/internal/udpfs/metrics.go`

- `native/ps2servers-edge/internal/udpfs/negotiation_seq0_test.go`

- `native/ps2servers-edge/internal/udpfs/observability_test.go`

- `native/ps2servers-edge/internal/udpfs/pathops.go`

- `native/ps2servers-edge/internal/udpfs/pathops_test.go`

- `native/ps2servers-edge/internal/udpfs/rediscovery_test.go`

- `native/ps2servers-edge/internal/udpfs/server_test.go`

- `native/ps2servers-edge/internal/udpfs/session_summary_test.go`

- `native/ps2servers-edge/internal/udpfs/status_test.go`

- `native/ps2servers-edge/internal/udpfs/transfer_test.go`

- `native/ps2servers-edge/internal/udpfs/udpwrite_linux.go`

- `native/ps2servers-edge/internal/udpfs/udpwrite_other.go`

- `native/ps2servers-edge/internal/udpfs/udpwrite_test.go`

- `native/ps2servers-edge/internal/udpfs/write_test.go`

- `native/ps2servers-edge/internal/webui/assets/.gitkeep`

- `native/ps2servers-edge/internal/webui/assets/index.html`

- `native/ps2servers-edge/internal/webui/assets/styles.css`

- `native/ps2servers-edge/internal/webui/config.go`

- `native/ps2servers-edge/internal/webui/config_uci.go`

- `native/ps2servers-edge/internal/webui/embed.go`

- `native/ps2servers-edge/internal/webui/logbuffer.go`

- `native/ps2servers-edge/internal/webui/schema.go`

- `native/ps2servers-edge/internal/webui/schema_test.go`

- `native/ps2servers-edge/internal/webui/webui_test.go`

- `packaging/docker/Dockerfile.edge`

- `packaging/docker/README.md`

- `packaging/openrc/README.md`

- `packaging/openrc/ps2servers-udpfs`

- `packaging/openrc/ps2servers-udpfs.confd`

- `packaging/openwrt/Makefile`

- `packaging/openwrt/README.md`

- `packaging/openwrt/files/ps2servers-edge.config`

- `packaging/openwrt/files/ps2servers-edge.init`

- `packaging/systemd/ps2servers-edge-smb.env`

- `packaging/systemd/ps2servers-edge-udpbd.env`

- `packaging/systemd/ps2servers-edge-udpfs.env`

- `packaging/systemd/ps2servers-edge-webui.env`

- `packaging/systemd/ps2servers-edge.env`

- `packaging/systemd/ps2servers-edge.service`

- `packaging/systemd/ps2servers-smbv1.env`

- `packaging/systemd/ps2servers-udpbd.env`

- `packaging/systemd/ps2servers-udpfs.env`

- `packaging/systemd/ps2servers@.service`

- `ps2servers.py`

- `ps2serversgithubbanner.png` — binary asset/fixture; inventory/header/size only, not source text.

- `smb2_server/smb2_srvsvc.py`

- `smbv1_server/README.md`

- `smbv1_server/Start-SMB-Server.bat`

- `smbv1_server/build_exe.ps1`

- `start-launcher.sh`

- `tests/__init__.py`

- `tests/fixtures/cd_chd/README.md`

- `tests/fixtures/cd_chd/synthetic-cd-1003.chd` — binary asset/fixture; inventory/header/size only, not source text.

- `tests/fixtures/cd_chd/synthetic-cd-cooked-1003.chd` — binary asset/fixture; inventory/header/size only, not source text.

- `tests/fixtures/ra_hash/README.md`

- `tests/fixtures/ra_hash/synthetic-dvd.chd` — binary asset/fixture; inventory/header/size only, not source text.

- `tests/fixtures/ra_hash/synthetic-identity.chd` — binary asset/fixture; inventory/header/size only, not source text.

- `tests/library_fixtures.py`

- `tests/test_about_page.py`

- `tests/test_achievement_loader.py`

- `tests/test_achievement_viewer.py`

- `tests/test_art_fetch.py`

- `tests/test_attribution_policy.py`

- `tests/test_autostart_and_firewall_options.py`

- `tests/test_caduceus_reference_wire.py`

- `tests/test_caduceus_setup.py`

- `tests/test_chd_cd_size.py`

- `tests/test_chd_cuebin.py`

- `tests/test_companion_fixtures.py`

- `tests/test_cooperative_stop.py`

- `tests/test_desktop_instance.py`

- `tests/test_directlink.py`

- `tests/test_directlink_unix.py`

- `tests/test_disc_identity.py`

- `tests/test_discord_presence.py`

- `tests/test_edge_flag_exposure.py`

- `tests/test_edge_manual.py`

- `tests/test_edge_service_modes.py`

- `tests/test_frozen_imports.py`

- `tests/test_game_library.py`

- `tests/test_gui_layout.py`

- `tests/test_gui_smb2_start_needs_login.py`

- `tests/test_http_direct_link.py`

- `tests/test_http_path_aware.py`

- `tests/test_http_server.py`

- `tests/test_library_catalog.py`

- `tests/test_library_identity.py`

- `tests/test_library_index.py`

- `tests/test_library_panel.py`

- `tests/test_library_preferences.py`

- `tests/test_library_recursive_scan.py`

- `tests/test_line_endings.py`

- `tests/test_linux_parity.py`

- `tests/test_netinfo_and_smb.py`

- `tests/test_nfs4_server.py`

- `tests/test_opl_http_runner.py`

- `tests/test_orbit_reference_wire.py`

- `tests/test_packaging_data_files.py`

- `tests/test_path_access.py`

- `tests/test_portable_config.py`

- `tests/test_protocol_mode_selector.py`

- `tests/test_ps1_vcd.py`

- `tests/test_ra_account.py`

- `tests/test_ra_account_worker.py`

- `tests/test_ra_compressed_hash.py`

- `tests/test_ra_credentials.py`

- `tests/test_ra_dependency.py`

- `tests/test_ra_evaluator.py`

- `tests/test_ra_notifications.py`

- `tests/test_ra_overview.py`

- `tests/test_ra_owned_service.py`

- `tests/test_ra_protocol.py`

- `tests/test_ra_receiver.py`

- `tests/test_ra_resolver_process.py`

- `tests/test_ra_session.py`

- `tests/test_ra_session_client.py`

- `tests/test_ra_sets.py`

- `tests/test_ra_sounds.py`

- `tests/test_ra_submissions.py`

- `tests/test_ra_supervisor.py`

- `tests/test_ra_watchlist.py`

- `tests/test_ra_web.py`

- `tests/test_raw_storage.py`

- `tests/test_release_downloads.py`

- `tests/test_reset_settings.py`

- `tests/test_retroachievements.py`

- `tests/test_riptopl_profile.py`

- `tests/test_router_status.py`

- `tests/test_server_override_contract.py`

- `tests/test_session_cap.py`

- `tests/test_session_shutdown.py`

- `tests/test_session_summary.py`

- `tests/test_session_view.py`

- `tests/test_settings_feedback.py`

- `tests/test_setup_guide.py`

- `tests/test_smb2_auth.py`

- `tests/test_smb2_banner.py`

- `tests/test_smb2_independent_client.py`

- `tests/test_smb2_libsmb2_compat.py`

- `tests/test_smb2_paths.py`

- `tests/test_smb2_server.py`

- `tests/test_smb2_share_name.py`

- `tests/test_smb2_signed_sessions.py`

- `tests/test_smb2_signing.py`

- `tests/test_smb2_take_445.py`

- `tests/test_smb2_wire.py`

- `tests/test_smb_wire_parity.py`

- `tests/test_smbv1_compressed.py`

- `tests/test_smbv1_diagnostics.py`

- `tests/test_smbv1_logon_required.py`

- `tests/test_smbv1_read_after_write.py`

- `tests/test_smbv1_share_and_credentials.py`

- `tests/test_smbv1_write_semantics.py`

- `tests/test_status_client.py`

- `tests/test_status_dot.py`

- `tests/test_systemd_units.py`

- `tests/test_theme.py`

- `tests/test_transfer_limits.py`

- `tests/test_tray_linux.py`

- `tests/test_udpbd_access.py`

- `tests/test_udpbd_storage_modes.py`

- `tests/test_udpfs_ack_progress.py`

- `tests/test_udpfs_bind_control.py`

- `tests/test_udpfs_config.py`

- `tests/test_udpfs_dread_skip_entry.py`

- `tests/test_udpfs_fallback_generation.py`

- `tests/test_udpfs_handoff_retried_write.py`

- `tests/test_udpfs_inform_telemetry.py`

- `tests/test_udpfs_live_discovery_handoff.py`

- `tests/test_udpfs_protocol_negotiation.py`

- `tests/test_udpfs_resent_request.py`

- `tests/test_udpfs_stall_report.py`

- `tests/test_udpfs_startup_diagnostics.py`

- `tests/test_udpfs_symlink_path_ops.py`

- `tests/test_udpfs_write_needs_writable_handle.py`

- `tests/test_verbose_default_and_log_stamps.py`

- `tests/test_verify_docs.py`

- `tests/test_version_consistency.py`

- `tools/build_docs_index.py`

- `tools/check_achievements_package.py`

- `tools/check_desktop_startup.py`

- `tools/check_release_compliance.py`

- `tools/remove-windows-firewall-rules.ps1`

- `tools/replay_neutrino_udpfs.py`

- `tools/verify_docs.py`

- `tools/version_source.py`

- `udpbd_server/SOURCE.md`

- `udpbd_server/selftest.py`

- `udpfs_server/compressed_iso/__init__.py`

- `udpfs_server/compressed_iso/chd_cuebin.py`

- `udpfs_server/compression_selftest.py`

- `udpfs_server/multiclient_selftest.py`

- `udpfs_server/pathguard_selftest.py`

- `udpfs_server/ps2servers_core.py`

- `udpfs_server/router_status.py`

- `vendor/retroachievements/README.md`

- `vendor/retroachievements/rcheevos/LICENSE` — licence excluded by request.

- `vendor/retroachievements/rcheevos/include/module.modulemap`

- `vendor/retroachievements/rcheevos/include/rc_api_editor.h`

- `vendor/retroachievements/rcheevos/include/rc_api_info.h`

- `vendor/retroachievements/rcheevos/include/rc_api_request.h`

- `vendor/retroachievements/rcheevos/include/rc_api_runtime.h`

- `vendor/retroachievements/rcheevos/include/rc_api_user.h`

- `vendor/retroachievements/rcheevos/include/rc_client.h`

- `vendor/retroachievements/rcheevos/include/rc_client_raintegration.h`

- `vendor/retroachievements/rcheevos/include/rc_consoles.h`

- `vendor/retroachievements/rcheevos/include/rc_error.h`

- `vendor/retroachievements/rcheevos/include/rc_export.h`

- `vendor/retroachievements/rcheevos/include/rc_hash.h`

- `vendor/retroachievements/rcheevos/include/rc_runtime.h`

- `vendor/retroachievements/rcheevos/include/rc_runtime_types.h`

- `vendor/retroachievements/rcheevos/include/rc_util.h`

- `vendor/retroachievements/rcheevos/include/rcheevos.h`

- `vendor/retroachievements/rcheevos/src/rapi/rc_api_common.c`

- `vendor/retroachievements/rcheevos/src/rapi/rc_api_common.h`

- `vendor/retroachievements/rcheevos/src/rapi/rc_api_editor.c`

- `vendor/retroachievements/rcheevos/src/rapi/rc_api_info.c`

- `vendor/retroachievements/rcheevos/src/rapi/rc_api_runtime.c`

- `vendor/retroachievements/rcheevos/src/rapi/rc_api_user.c`

- `vendor/retroachievements/rcheevos/src/rc_client.c`

- `vendor/retroachievements/rcheevos/src/rc_client_external.c`

- `vendor/retroachievements/rcheevos/src/rc_client_external.h`

- `vendor/retroachievements/rcheevos/src/rc_client_external_versions.h`

- `vendor/retroachievements/rcheevos/src/rc_client_internal.h`

- `vendor/retroachievements/rcheevos/src/rc_client_raintegration.c`

- `vendor/retroachievements/rcheevos/src/rc_client_raintegration_internal.h`

- `vendor/retroachievements/rcheevos/src/rc_client_types.natvis`

- `vendor/retroachievements/rcheevos/src/rc_compat.c`

- `vendor/retroachievements/rcheevos/src/rc_compat.h`

- `vendor/retroachievements/rcheevos/src/rc_libretro.c`

- `vendor/retroachievements/rcheevos/src/rc_libretro.h`

- `vendor/retroachievements/rcheevos/src/rc_util.c`

- `vendor/retroachievements/rcheevos/src/rc_version.c`

- `vendor/retroachievements/rcheevos/src/rc_version.h`

- `vendor/retroachievements/rcheevos/src/rcheevos/alloc.c`

- `vendor/retroachievements/rcheevos/src/rcheevos/condition.c`

- `vendor/retroachievements/rcheevos/src/rcheevos/condset.c`

- `vendor/retroachievements/rcheevos/src/rcheevos/consoleinfo.c`

- `vendor/retroachievements/rcheevos/src/rcheevos/format.c`

- `vendor/retroachievements/rcheevos/src/rcheevos/lboard.c`

- `vendor/retroachievements/rcheevos/src/rcheevos/memref.c`

- `vendor/retroachievements/rcheevos/src/rcheevos/operand.c`

- `vendor/retroachievements/rcheevos/src/rcheevos/rc_internal.h`

- `vendor/retroachievements/rcheevos/src/rcheevos/rc_runtime_types.natvis`

- `vendor/retroachievements/rcheevos/src/rcheevos/rc_validate.c`

- `vendor/retroachievements/rcheevos/src/rcheevos/rc_validate.h`

- `vendor/retroachievements/rcheevos/src/rcheevos/richpresence.c`

- `vendor/retroachievements/rcheevos/src/rcheevos/runtime.c`

- `vendor/retroachievements/rcheevos/src/rcheevos/runtime_progress.c`

- `vendor/retroachievements/rcheevos/src/rcheevos/trigger.c`

- `vendor/retroachievements/rcheevos/src/rcheevos/value.c`

- `vendor/retroachievements/rcheevos/src/rhash/aes.c`

- `vendor/retroachievements/rcheevos/src/rhash/aes.h`

- `vendor/retroachievements/rcheevos/src/rhash/cdreader.c`

- `vendor/retroachievements/rcheevos/src/rhash/hash.c`

- `vendor/retroachievements/rcheevos/src/rhash/hash_disc.c`

- `vendor/retroachievements/rcheevos/src/rhash/hash_encrypted.c`

- `vendor/retroachievements/rcheevos/src/rhash/hash_rom.c`

- `vendor/retroachievements/rcheevos/src/rhash/hash_zip.c`

- `vendor/retroachievements/rcheevos/src/rhash/md5.c`

- `vendor/retroachievements/rcheevos/src/rhash/md5.h`

- `vendor/retroachievements/rcheevos/src/rhash/rc_hash_internal.h`

- `vendor/retroachievements/sources.json`

- `vendor/retroachievements/xerabora/client/LICENSE` — licence excluded by request.

- `vendor/retroachievements/xerabora/client/Makefile`

- `vendor/retroachievements/xerabora/client/src/badge_data.c`

- `vendor/retroachievements/xerabora/client/src/badge_data.h`

- `vendor/retroachievements/xerabora/client/src/config.c`

- `vendor/retroachievements/xerabora/client/src/config.h`

- `vendor/retroachievements/xerabora/client/src/console.c`

- `vendor/retroachievements/xerabora/client/src/console.h`

- `vendor/retroachievements/xerabora/client/src/discord.c`

- `vendor/retroachievements/xerabora/client/src/discord.h`

- `vendor/retroachievements/xerabora/client/src/follow.c`

- `vendor/retroachievements/xerabora/client/src/follow.h`

- `vendor/retroachievements/xerabora/client/src/http.h`

- `vendor/retroachievements/xerabora/client/src/http_curl.c`

- `vendor/retroachievements/xerabora/client/src/http_winhttp.c`

- `vendor/retroachievements/xerabora/client/src/jsmn.h`

- `vendor/retroachievements/xerabora/client/src/log.c`

- `vendor/retroachievements/xerabora/client/src/log.h`

- `vendor/retroachievements/xerabora/client/src/main.c`

- `vendor/retroachievements/xerabora/client/src/platform.c`

- `vendor/retroachievements/xerabora/client/src/platform.h`

- `vendor/retroachievements/xerabora/client/src/protocol.h`

- `vendor/retroachievements/xerabora/client/src/ra.c`

- `vendor/retroachievements/xerabora/client/src/ra.h`

- `vendor/retroachievements/xerabora/client/src/raweb.c`

- `vendor/retroachievements/xerabora/client/src/raweb.h`

- `vendor/retroachievements/xerabora/client/src/snapshot.c`

- `vendor/retroachievements/xerabora/client/src/snapshot.h`

- `vendor/retroachievements/xerabora/client/src/sound.c`

- `vendor/retroachievements/xerabora/client/src/sound.h`

- `vendor/retroachievements/xerabora/client/src/sounds_data.c`

- `vendor/retroachievements/xerabora/client/src/sounds_data.h`

- `vendor/retroachievements/xerabora/client/src/ui.c`

- `vendor/retroachievements/xerabora/client/src/ui.h`

- `vendor/retroachievements/xerabora/client/src/ui_page.c`

- `vendor/retroachievements/xerabora/client/src/ui_page.h`

- `vendor/retroachievements/xerabora/client/src/version.h`

- `vendor/retroachievements/xerabora/client/src/watchlist.c`

- `vendor/retroachievements/xerabora/client/src/watchlist.h`

- `vendor/retroachievements/xerabora/client/src/webui.c`

- `vendor/retroachievements/xerabora/client/src/webui.h`

- `vendor/retroachievements/xerabora/client/ui/vendor/LICENSE.htm` — licence excluded by request.

- `vendor/retroachievements/xerabora/client/ui/vendor/LICENSE.preact` — licence excluded by request.

- `vendor/retroachievements/xerabora/client/ui/vendor/LICENSE.signals` — licence excluded by request.

- `vendor/retroachievements/xerabora/protocol/PROTOCOL.md`

- `vendor/retroachievements/xerabora/protocol/ra_snap.h`

- `vendor/retroachievements/xerabora/protocol/ra_watch.h`


**Unfinished categories:** all eight categories remain open across the unread/partial paths, especially RetroAchievements Python/native C, native Edge Go, tests/conformance, remaining build/workflows, docs and packaging. This checkpoint does not claim exhaustive coverage. See Codex-SUMMARY.md for branch/tag inventory and cross-repository deduplication. No report or command establishes actual PS2 console behavior.

## Durable continuation manifest

[Exact coverage and remaining paths](coverage/Codex-PS2-Servers-coverage.json): 49 whole-file reads; 28 paths with recorded partial evidence; 547 paths require further review or explicit binary/document exclusion. This is a tracked-file count, not a claim that binary assets can be source-audited.

## Shared file-promotion guidance

The manual .BAK recommendation in launcher/riptopl_profile.py is included once under **CROSS-001** in [Codex-SUMMARY.md](Codex-SUMMARY.md).
