# Codex audit — NathanNeurotic PS2 repositories

**-unfinished- checkpoint:** This is the earlier baseline report, preserved with its validation results. See [the resume index](Codex-RESUME-unfinished.md) and linked continuation findings for the later review. Earlier read-only statements describe source handling before the user authorized this report-only draft PR.

**164 unique findings across five repository reports and four canonical shared findings. This is a partial audit, not an exhaustive completion.** Source snapshots were acquired November 13, 2026; reports were consolidated November 14. Review capacity, an earlier usage interruption and automated filtering that stopped two reviewers left the exact unfinished scope listed below.

The repository working trees and GitHub state were kept read-only. Only reports, coverage inventories and disposable local evidence were written. No branch, tag, release, issue, pull request or workflow was changed or run.

READ means source evidence. Declared byte counts and host measurements are distinguished from INFERRED target savings. No PS2SDK build, real-console test, final ELF size, Windows GUI run or hardware latency measurement is claimed. Proposed line reductions remain INFERRED until implemented. Savings from different machines/builds are not added into a misleading total.

| Repository report | Default branch / immutable snapshot | Findings stored here | Tracked files |
| --- | --- | ---: | ---: |
| [RiptOPL](Codex-RiptOPL.md) | rebuild/main — `679d3d8626dd09a913e7081101418e337234fe7c` | 22 | 2,380 |
| [Launchstation](Codex-Launchstation.md) | master — `8cd3329a98c09a570bfbf60137717edd42324990` | 30 | 1,065 |
| [POPSLoader](Codex-POPSLoader.md) | master — `29272cddbf0122f14e76bc3bdd75e3b46aa870be` | 42 | 609 |
| [Simple-Media-System](Codex-Simple-Media-System.md) | master — `b9a5c882d6d632914faa4ff8dc080f1ecd51bfd7` | 29 | 1,012 |
| [PS2-Servers](Codex-PS2-Servers.md) | main — `5179b4bb1f488ef2eb91956c8792e2194dda2fca` | 37 | 596 |

Four additional shared findings are written once below. Shared controller findings POPSLOADER-017, -018, -041 and -042 are written once in the POPSLoader report, with affected Launchstation/RiptOPL copies cited there. Those occurrences are not extra findings.

## Top 25 by practical benefit

Order balances demonstrated data loss/corruption, everyday responsiveness, retained memory, and substantial deletion opportunities. Closely ranked items are not a numeric severity score; use each finding’s effort, risk and confidence before changing code.

| Rank | Finding | Main payoff / evidence |
| ---: | --- | --- |
| 1 | [CROSS-003](Codex-SUMMARY.md) | Source deletion after a failed destination close; host fault injection confirmed the RiptOPL path. |
| 2 | [LAUNCHSTATION-002](Codex-Launchstation.md:20) | Previous full text buffer leaked per insertion; duplicated splice machinery can be removed. |
| 3 | [LAUNCHSTATION-001](Codex-Launchstation.md:11) | Both row-table overrun and first-row negative index reproduced with host sanitizers. |
| 4 | [RIPTOPL-001](Codex-RiptOPL.md:11) | Malformed compressed data reaches an unbounded decoder; host invalid read reproduced. |
| 5 | [POPSLOADER-012](Codex-POPSLoader.md:11) | Malformed VCD metadata produces a huge memcpy; negative-size copy reproduced. |
| 6 | [POPSLOADER-001](Codex-POPSLoader.md:20) | Delete roughly 422 lines of unused BMP decoding and its reachable heap-overrun path. |
| 7 | [SMS-001](Codex-Simple-Media-System.md:15) | ASF zero-size crash and non-progress loop reproduced using the existing harness. |
| 8 | [POPSLOADER-017](Codex-POPSLoader.md:28) | Shared Bluetooth error path accepts pad index -1 in all affected copies. |
| 9 | [POPSLOADER-042](Codex-POPSLoader.md:37) | Shared USB descriptor walks lack returned-buffer/descriptor bounds. |
| 10 | [RIPTOPL-002](Codex-RiptOPL.md:20) | A malformed archive sidecar name causes an ASan-confirmed heap over-read. |
| 11 | [PS2SERVERS-019](Codex-PS2-Servers.md:30) | UDPBD packet ownership omits command ID/exact endpoint; delayed-packet corruption is INFERRED. |
| 12 | [PS2SERVERS-031](Codex-PS2-Servers.md:58) | Out-of-capacity UDPBD write acknowledged and temporary image growth reproduced. |
| 13 | [RIPTOPL-017](Codex-RiptOPL.md:29) | Saved cheat selection can overrun its normalized buffer; host sanitizers confirmed it. |
| 14 | [POPSLOADER-002](Codex-POPSLoader.md:64) | Synchronous SMB waits can last 30 seconds each and one retry is unbounded. |
| 15 | [PS2SERVERS-003](Codex-PS2-Servers.md:86) | Server Stop waits on the Tk thread for multi-second shutdown paths. |
| 16 | [RIPTOPL-006](Codex-RiptOPL.md:65) | File Manager performs device scans/copies/deletion in the dialog thread. |
| 17 | [SMS-003](Codex-Simple-Media-System.md:78) | Delete the incomplete apply-now network reset, roughly 71 lines, retaining next-launch settings. |
| 18 | [RIPTOPL-018](Codex-RiptOPL.md:74) | Source declares 768 KiB of optional audio storage plus 16 KiB of export scratch held while unused. |
| 19 | [PS2SERVERS-006](Codex-PS2-Servers.md:142) | Measured host index representation saves about 64 MiB per 4-GiB/2-KiB-block image reader. |
| 20 | [SMS-010](Codex-Simple-Media-System.md:104) | 602,112 fewer stack/optical bytes per CDDA scan from exact source arithmetic. |
| 21 | [POPSLOADER-003](Codex-POPSLoader.md:109) | Up to about 1.4 MiB less duplicate PNG pixel storage, an INFERRED capacity bound. |
| 22 | [CROSS-001](Codex-SUMMARY.md) | Remove backup retention and recopying: 8–64 MiB per old VMC, plus avoidable save/update writes. |
| 23 | [RIPTOPL-901](Codex-RiptOPL.md:119) | 31 duplicate configuration builds per integration push/PR are present in current CI matrices. |
| 24 | [LAUNCHSTATION-028](Codex-Launchstation.md:110) | Delete more than 442 lines of unreachable classic-shell code/build input. |
| 25 | [POPSLOADER-011](Codex-POPSLoader.md:46) | Untracked HDD recovery calls nil globals; reproduced against the real Lua chunk. |

## Quick wins — all 110 Low-risk / S-effort findings

These are implementation-risk/effort ratings, not a claim that each change is equally important. IDs link to the complete source evidence and simplest fix.

| Finding | Change |
| --- | --- |
| [RIPTOPL-002](Codex-RiptOPL.md:20) | Reject unterminated names in the TAR sidecar cache |
| [RIPTOPL-017](Codex-RiptOPL.md:29) | Reserve space for both pending whitespace and its next character |
| [RIPTOPL-004](Codex-RiptOPL.md:38) | Unvalidated saved IP octets overflow the launch configuration |
| [RIPTOPL-019](Codex-RiptOPL.md:56) | Stop reading past icon assets to manufacture OSD padding |
| [RIPTOPL-008](Codex-RiptOPL.md:83) | Do not retain maximum-capacity scan arrays for tiny libraries |
| [RIPTOPL-007](Codex-RiptOPL.md:92) | Use the submenu tail already maintained by the GUI |
| [RIPTOPL-009](Codex-RiptOPL.md:101) | Read the TAR cache directly into its final allocation |
| [RIPTOPL-901](Codex-RiptOPL.md:119) | Remove overlapping CI build and test executions |
| [RIPTOPL-903](Codex-RiptOPL.md:127) | Keep one source copy of bundled binary payloads |
| [RIPTOPL-011](Codex-RiptOPL.md:153) | Eliminate the second allocation per deferred GUI operation |
| [RIPTOPL-013](Codex-RiptOPL.md:162) | Close the I/O print semaphore when its worker exits |
| [RIPTOPL-015](Codex-RiptOPL.md:171) | Consolidate identical TAR lookups and remove genuinely unused APIs/state |
| [RIPTOPL-902](Codex-RiptOPL.md:180) | Delete unused Makefile-era release scripts |
| [RIPTOPL-016](Codex-RiptOPL.md:188) | Correct the existing host-test inputs instead of trusting their passing result |
| [RIPTOPL-020](Codex-RiptOPL.md:196) | Correct the history eviction tie-break and delete stale commented code |
| [LAUNCHSTATION-004](Codex-Launchstation.md:38) | Bound the uLE path expansion |
| [LAUNCHSTATION-006](Codex-Launchstation.md:56) | Report editor save success only after write and close succeed |
| [LAUNCHSTATION-007](Codex-Launchstation.md:65) | Reject an incomplete classic-editor read |
| [LAUNCHSTATION-020](Codex-Launchstation.md:74) | Do not discard applications after an incomplete scan |
| [LAUNCHSTATION-009](Codex-Launchstation.md:83) | Do not consume a partial FTP receiver request as malformed |
| [LAUNCHSTATION-008](Codex-Launchstation.md:92) | Release interlaced-PNG scratch on the existing error path |
| [LAUNCHSTATION-028](Codex-Launchstation.md:110) | Delete the unreachable classic launch-key shell |
| [LAUNCHSTATION-022](Codex-Launchstation.md:146) | Remove the cosmetic latest-release draft cycle |
| [LAUNCHSTATION-024](Codex-Launchstation.md:154) | Delete unreferenced payload and sound files |
| [LAUNCHSTATION-013](Codex-Launchstation.md:162) | Delete the abandoned spinning-header icon path |
| [LAUNCHSTATION-015](Codex-Launchstation.md:179) | Use one PNG box-filter loop |
| [LAUNCHSTATION-016](Codex-Launchstation.md:187) | Remove the redundant artwork file-open probe |
| [LAUNCHSTATION-017](Codex-Launchstation.md:195) | Remove the classic editor's forced result stalls |
| [LAUNCHSTATION-018](Codex-Launchstation.md:203) | Delete dangling language-error previews |
| [LAUNCHSTATION-030](Codex-Launchstation.md:211) | Keep classic-editor return mode within its three valid values |
| [LAUNCHSTATION-021](Codex-Launchstation.md:220) | Use the GS unity tint for true-color artwork |
| [LAUNCHSTATION-023](Codex-Launchstation.md:229) | Read release metadata once per verification phase |
| [LAUNCHSTATION-025](Codex-Launchstation.md:238) | Run the same package test and fixture generation only once |
| [LAUNCHSTATION-029](Codex-Launchstation.md:246) | Remove invariant dashboard settings and their dead handlers |
| [LAUNCHSTATION-019](Codex-Launchstation.md:254) | Batch the duplicated CI package-manager work |
| [LAUNCHSTATION-014](Codex-Launchstation.md:262) | Delete two unused compatibility entry points |
| [POPSLOADER-012](Codex-POPSLoader.md:11) | Malformed VCD metadata turns a size into a huge memcpy |
| [POPSLOADER-017](Codex-POPSLoader.md:28) | Bluetooth transfer errors index the pad array at minus one |
| [POPSLOADER-011](Codex-POPSLoader.md:46) | Untracked PFS recovery calls nil globals instead of its local helpers |
| [POPSLOADER-016](Codex-POPSLoader.md:55) | Failed controller-module startup can leave boot in an infinite RPC bind |
| [POPSLOADER-036](Codex-POPSLoader.md:126) | Avoid replaying credits and fixed holds on every boot |
| [POPSLOADER-019](Codex-POPSLoader.md:134) | Delete the game-partition write diagnostic from normal settings saves |
| [POPSLOADER-020](Codex-POPSLoader.md:142) | Do one existence check instead of opening every missing path twice |
| [POPSLOADER-006](Codex-POPSLoader.md:158) | Delete the superseded asynchronous image loader |
| [POPSLOADER-007](Codex-POPSLoader.md:166) | Stop embedding the replaced plain ATA driver |
| [POPSLOADER-034](Codex-POPSLoader.md:174) | Remove an allocated font that is never drawn |
| [POPSLOADER-029](Codex-POPSLoader.md:182) | Retro GEM-only settings edit is silently discarded on Back |
| [POPSLOADER-030](Codex-POPSLoader.md:192) | BDMA staging reports success when its mode marker write failed |
| [POPSLOADER-038](Codex-POPSLoader.md:201) | Failed unhide is reported as success |
| [POPSLOADER-041](Codex-POPSLoader.md:228) | Release partially opened Bluetooth endpoints on connect failure |
| [POPSLOADER-018](Codex-POPSLoader.md:237) | Bound the DS3 battery-table index |
| [POPSLOADER-033](Codex-POPSLoader.md:262) | Remove unreachable placeholder UI and dead input diagnostics |
| [POPSLOADER-039](Codex-POPSLoader.md:270) | Delete the uncalled whole-heap memory diagnostic |
| [POPSLOADER-021](Codex-POPSLoader.md:278) | Stop tracking the regenerated child-loader byte array |
| [POPSLOADER-022](Codex-POPSLoader.md:287) | Delete unused alternate controller/ATA source trees and obsolete MX4SIO blobs |
| [POPSLOADER-013](Codex-POPSLoader.md:312) | Remove the second host-harness execution in each build container |
| [POPSLOADER-023](Codex-POPSLoader.md:320) | Make the release-kit checkout repeatable |
| [POPSLOADER-009](Codex-POPSLoader.md:329) | Kerning is permanently disabled by the previous-glyph update |
| [POPSLOADER-008](Codex-POPSLoader.md:338) | Delete the always-empty image fallback table |
| [POPSLOADER-024](Codex-POPSLoader.md:346) | Delete the spent mistaken-release retraction workflow |
| [POPSLOADER-010](Codex-POPSLoader.md:354) | Delete obsolete dummy-file and removed-API declarations |
| [POPSLOADER-040](Codex-POPSLoader.md:362) | Remove superseded current-state claims from the canonical status page |
| [SMS-001](Codex-Simple-Media-System.md:15) | Reject impossible ASF packet geometry before packet reading |
| [SMS-002](Codex-Simple-Media-System.md:24) | Reject negative ASF payload lengths before arithmetic |
| [SMS-004](Codex-Simple-Media-System.md:33) | Bound failed-save diagnostics to their destination buffer |
| [SMS-006](Codex-Simple-Media-System.md:51) | Terminate and initialize fixed-width CDDA metadata strings |
| [SMS-009](Codex-Simple-Media-System.md:86) | Return an error when an M3U item has no recognized format |
| [SMS-010](Codex-Simple-Media-System.md:104) | Read only the CDDA sectors that are actually searched |
| [SMS-013](Codex-Simple-Media-System.md:129) | Delete the replaced IPU icon assets and unused unpacker |
| [SMS-026](Codex-Simple-Media-System.md:155) | Delete the broken QPel control and command option |
| [SMS-027](Codex-Simple-Media-System.md:163) | Keep normalized FLAC output at a rate the player decodes |
| [SMS-008](Codex-Simple-Media-System.md:181) | Preserve the ASF reassembly buffer when realloc fails |
| [SMS-019](Codex-Simple-Media-System.md:190) | Bound history loading to the history format actually written |
| [SMS-020](Codex-Simple-Media-System.md:199) | Write the persisted config prefix rather than runtime pointers |
| [SMS-021](Codex-Simple-Media-System.md:225) | Delete the unused assembly round-rectangle implementation |
| [SMS-022](Codex-Simple-Media-System.md:233) | Compile release breadcrumbs out at their call sites |
| [SMS-023](Codex-Simple-Media-System.md:241) | Size the probe function array by entries |
| [SMS-024](Codex-Simple-Media-System.md:249) | Delete the unused XZ variable-length integer encoder |
| [SMS-025](Codex-Simple-Media-System.md:257) | Remove the unused packet-read remainder calculation |
| [PS2SERVERS-018](Codex-PS2-Servers.md:16) | Edge compressed header arithmetic can panic the whole server |
| [PS2SERVERS-019](Codex-PS2-Servers.md:30) | Edge UDPBD accepts write data from the wrong command |
| [PS2SERVERS-001](Codex-PS2-Servers.md:44) | HTTP appends a second response after a failed game body |
| [PS2SERVERS-031](Codex-PS2-Servers.md:58) | Reject out-of-range UDPBD image reads/writes as raw mode already does |
| [PS2SERVERS-004](Codex-PS2-Servers.md:100) | Remove credentials from the launch log |
| [PS2SERVERS-005](Codex-PS2-Servers.md:114) | Apply the HTTP root boundary to the legacy profile too |
| [PS2SERVERS-020](Codex-PS2-Servers.md:128) | Edge file browsing fails open when configuration is missing or unreadable |
| [PS2SERVERS-006](Codex-PS2-Servers.md:142) | Store compressed offset tables as uint32 arrays |
| [PS2SERVERS-021](Codex-PS2-Servers.md:156) | Honor zero compressed-cache size by deleting the default fallback |
| [PS2SERVERS-032](Codex-PS2-Servers.md:170) | Delete SMBv1 port walking that makes the GUI advertise the wrong port |
| [PS2SERVERS-033](Codex-PS2-Servers.md:184) | Avoid non-ASCII string comparison exceptions in SMBv1 login |
| [PS2SERVERS-022](Codex-PS2-Servers.md:198) | Stop reporting every established Edge UDPFS session as busy |
| [PS2SERVERS-023](Codex-PS2-Servers.md:212) | Treat a valid block-only Edge UDPFS server as ready |
| [PS2SERVERS-034](Codex-PS2-Servers.md:240) | Bound the pending GUI output queue as well as the terminal widget |
| [PS2SERVERS-007](Codex-PS2-Servers.md:268) | Delete the obsolete fake SMB2/3 implementation in the SMBv1 server |
| [PS2SERVERS-009](Codex-PS2-Servers.md:324) | Delete the second complete set of ttk style definitions |
| [PS2SERVERS-010](Codex-PS2-Servers.md:338) | Delete loaded tab artwork that status dots always supersede |
| [PS2SERVERS-011](Codex-PS2-Servers.md:352) | Ship the About logo at its rendered resolution |
| [PS2SERVERS-013](Codex-PS2-Servers.md:366) | Accept original OPL ZSO files when importing images |
| [PS2SERVERS-015](Codex-PS2-Servers.md:394) | Avoid repeated synchronous IP enumeration during Refresh/startup |
| [PS2SERVERS-025](Codex-PS2-Servers.md:408) | Remove an allocation/copy from every Edge UDPBD datagram |
| [PS2SERVERS-026](Codex-PS2-Servers.md:422) | Cap OpenWrt service-log snapshots at the existing requested limit |
| [PS2SERVERS-035](Codex-PS2-Servers.md:450) | Use mutable receive buffers instead of copying every prefix |
| [PS2SERVERS-037](Codex-PS2-Servers.md:464) | Reuse the existing SMB transaction response builder |
| [PS2SERVERS-027](Codex-PS2-Servers.md:478) | Delete unused ACK payload/state instead of maintaining it |
| [PS2SERVERS-028](Codex-PS2-Servers.md:492) | Delete redundant zeroing, sorting and TCP option calls |
| [PS2SERVERS-029](Codex-PS2-Servers.md:506) | Replace the handwritten integer formatter with the standard library |
| [PS2SERVERS-017](Codex-PS2-Servers.md:520) | Remove unused completeness/diagnostic helpers |
| [CROSS-002](Codex-SUMMARY.md) | Reject mismatched and incomplete NFS RPC replies |
| [CROSS-003](Codex-SUMMARY.md) | Do not delete the source after destination close fails |
| [CROSS-004](Codex-SUMMARY.md) | Cancel the USB controller alarm with its original argument |

## Suggested order of work

1. Fix source-loss and memory-corruption paths first: CROSS-003, the editor/parser bounds, malformed compressed images, and the shared controller defects. Reuse the existing narrow host harnesses for the actual failing cases; no new testing framework is needed.
2. Delete proven dead code and recover idle/peak RAM: unreachable classic shell, old BMP/asynchronous loaders, unused embedded modules/icons/fonts, duplicate PNG storage, maximum-size scan allocations and optional static buffers.
3. Remove UI-thread device work and unbounded waits using the workers already present. Preserve their existing ownership and shutdown order; avoid adding another task/worker framework.
4. Repair protocol/data correctness: UDPBD ownership/capacity, HTTP framing/root handling, NFS reply validation, settings persistence and converter/player mismatches.
5. Remove duplicate CI builds/tests and source-tree payload copies. Preserve the three genuinely unique RiptOPL configuration builds; remove spent/unused workflow and packaging machinery.
6. Apply CROSS-001 as a focused storage change. Retire .BAK creation/retention while validating the existing device-native promotion behavior and preserving a completed staging file on failure. Its High risk rating reflects save/update interruption behavior; do not replace it with another backup/retry layer.
7. Continue only the unfinished source paths/ranges listed in the coverage manifests, then revisit the broader architectural consolidations rated M/L or Med/High risk.

## Verification results

- **RiptOPL:** existing complete host runner: 277 successful script/suite entries, zero failed entries, two documentation suites skipped for missing BeautifulSoup. This is not an individual assertion count. Separate targeted host checks reproduced the archive-cache, compressed-data, normalization and close-error defects.
- **Launchstation:** existing editor/memory-card/package/parser checks ran; two classic-editor indexing failures were reproduced with sanitizers. The memory-card viewer check included 150 input mutations. No physical-card behavior is claimed.
- **POPSLoader:** existing Lua host harness 62/62 passed; disc-layout 30 cases, pad harness 13 cases and translation handoff 7 cases passed. Further Lua/config/staging checks and focused reproductions are in the report. PNG harness could not compile without libpng development metadata.
- **Simple-Media-System:** eight existing host suites passed. Three additional malformed ASF inputs reproduced division by zero, signed overflow and a non-progress timeout. FFmpeg rejected the emitted QPel option; normalized FLAC’s 192,000-Hz output was independently observed.
- **PS2-Servers:** 1,544 tests run, 75 skipped, four failures caused by the host’s unrelated Go board-game executable rejecting go run. No native Go execution is claimed. Focused Python protocol/file-boundary cases and index memory sizes were checked.
- **Shared NFS:** mocked I/O around each unmodified library reproduced acceptance of wrong transaction/message types; RiptOPL additionally accepted a reply without GETFH. This was a protocol parser check, not a PS2/network deployment test.
- **Final source integrity:** all 5,662 tracked file hashes and all five HEAD commits match the initial snapshots. Working trees are clean; three ignored PS2-Servers test-build outputs were removed, leaving no generated outputs in the repository clones.

## Exact unfinished scope for continuation

All five repositories still have unfinished work in categories 1–8 across the paths below. Whole-file counts include tracked documentation/build files and do not imply every binary asset was source-reviewed. A recorded partial path may still contain large unread ranges.

| Repository / durable manifest | Whole-file reads | Recorded partial paths | Not fully read | Priority remaining components |
| --- | ---: | ---: | ---: | --- |
| [RiptOPL](coverage/Codex-RiptOPL-coverage.json) | 60 | 36 | 2,320 | Most remaining runtime/header code, ee_core, IOP/storage/network modules, vendored libraries, tests/tools and docs; current 12 workflows were read. |
| [Launchstation](coverage/Codex-Launchstation-coverage.json) | 56 | 16 | 1,009 | IOP drivers except recorded NFS/SMB reads; cloud/save writers/installers; remaining device/launch/render/settings code; tests/scripts and five other workflows. |
| [POPSLoader](coverage/Codex-POPSLoader-coverage.json) | 96 | 10 | 513 | Translation data system.lua:2581–4843 and unreviewed comments; listed research/tooling, unused alternative module code, generated payload data and historical prose. Live native and executable Lua logic were reviewed. |
| [Simple-Media-System](coverage/Codex-Simple-Media-System-coverage.json) | 34 | 22 | 978 | Remaining codecs/assembly, IOP drivers, headers, converter/tooling, docs/site generation and partial workflow spans. |
| [PS2-Servers](coverage/Codex-PS2-Servers-coverage.json) | 49 | 28 | 547 | Remaining Edge Go/web spans, SMB2/UDPFS and GUI spans, vendored native C, tests/conformance, release workflows and docs. |

For a continuation, retain the exact commit, review only `unfinished_paths`, skip `fully_read_paths`, and use `partial_paths`/`partial_notes` to avoid rereading certified spans. Continue all eight categories in those files. Reuse these IDs and canonical shared locations to avoid reporting the same root cause again. Licence review remains excluded. Branch/tag ancestry/activity checks are separately unfinished in category 7.

## Cross-repository findings

### CROSS-001 / Remove backup-based replacement and unnecessary whole-file recopying / Categories 2, 3, 4, 5

- **Location(s):** RiptOPL/src/ui/selfupdate.cpp:249-337,352-355,388-414; RiptOPL/src/sources/vmcrebuild.cpp:6-10,118-133,173-199; RiptOPL/src/sources/vcdsupport.cpp:2205-2208,2267-2334; POPSLoader/bin/POPSLDR/system.lua:5229-5290; POPSLoader/src/luasystem.cpp:824-876; POPSLoader/etc/update_lua_globals.sh:8,15-23; PS2-Servers/launcher/riptopl_profile.py:223-228. Existing simpler replacement reference: Launchstation/src/self_update.c:312-321,412-439.
- **Problem:** RiptOPL retains the previous ELF as `.BAK` on non-card devices and permanently retains a full 8/16/32/64-MiB VMC backup, which also makes the next VMC rebuild refuse to start. POPSLoader implements every rename as copy/delete and then compensates with a second backup/copy cycle: saving a new N-byte payload over an M-byte file writes **2N + M** bytes instead of N plus a native directory rename. RiptOPL's rename fallback can similarly recopy both staged and original ELFs after any rename failure.
- **Fix:** Remove `.BAK` creation, retention and rollback branches. Finish and validate the staged new file before replacing the original; use the existing device-native rename mechanisms, including the memory-card rename already implemented in RiptOPL/Launchstation. Where a device truly lacks rename, keep only the minimum checked promotion needed for that device rather than treating every rename error as permission to recopy. For VMC rebuilding, promote the verified rebuilt image without retaining another whole VMC afterward. Preserve and name the completed staging file if final promotion fails, as Launchstation already does. The two UDPFS configuration originals already fit in `oldData[2][256]`; delete their extra disk-backup writes and use the existing in-memory originals for the existing failure handling. Merge VS Code globals from the original settings into the already-used temporary output before replacement, without moving the original to `.bak`. Remove the desktop profile text that tells users to create `.bak` copies.
- **Justification:** This replaces existing copying and backup machinery; it adds no shared framework or retry policy. Any necessary native memory-card rename binding solves the demonstrated full-file recopy cost using an already-used PS2 mechanism. Device support and power-loss behavior must be verified before deleting the current file; native rename is not assumed to be atomic or overwrite-capable on every driver.
- **Benefit:** **Measured from source:** one old ELF's disk space; **8–64 MiB** retained per rebuilt VMC; **N + M bytes of avoidable writes per existing POPSLoader save** when native rename is supported. Saves the 16-KiB fallback allocation when that path is removed. Timing and final ELF-code savings are unmeasured. VMC sizes are disk space, not EE RAM.
- **Effort:** M. **Risk:** High (save/update promotion and interrupted-write behavior). **Confidence:** High (READ for present behavior; INFERRED device-dependent savings and proposed promotion behavior).

### CROSS-002 / Reject mismatched and incomplete NFS RPC replies / Category 6

- **Location(s):** Launchstation/iop/nfsman/unfs4/unfs4.c:489-550; Launchstation/iop/nfsman/nfsman.c:131-145,444-447; RiptOPL/modules/network/nfsman/unfs4/unfs4.c:455-463,472-550; RiptOPL/modules/network/nfsman/nfsman.c:131-145,445-448; RiptOPL/modules/iopcore/cdvdman/nfs.c:93-118,228-236,266-272.
- **Problem:** Both socket-based NFS clients accept RPC records without checking that the transaction ID matches the outstanding request or that the message is a REPLY. RiptOPL additionally accepts a header-only successful response as a completed GETFH lookup by reading the old request bytes still in its shared request/reply buffer; Launchstation's existing `fits` checks already reject that truncated case.
- **Fix:** Reject a reply whose transaction ID or message type does not match the outstanding request, using the existing failure return. Bring RiptOPL's GETFH range check up to the small check already present in Launchstation. Do not add retry logic or another parser layer.
- **Justification:** These are direct checks for reproduced protocol defects at the existing parsing boundary. A fake-I/O harness compiled each unmodified production library: request ID 124 plus a response with ID 999 and message type CALL returned successful mount in both; a 32-byte response with no GETFH returned success only in RiptOPL. No additional dependency or abstraction is needed.
- **Benefit:** Prevents interpreting an invalid or stale RPC record as a successful lookup/mount. No RAM, byte or timing saving claimed; a few validation instructions are added. This is protocol correctness; a hostile NFS server already controls the files it serves, so no new privilege boundary is claimed.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ and host reproduction; PS2 hardware not exercised).

### CROSS-003 / Do not delete the source after destination close fails / Category 6

- **Location(s):** RiptOPL/src/core/filemgr.cpp:314-370,528-537; POPSLoader/src/luasystem.cpp:824-853,865-876.
- **Problem:** Both copy/delete move implementations ignore the destination's `close` result, report the copy successful, then remove the source. A device can report a delayed write error at close; reopening and checking only the destination length in RiptOPL does not make that error disappear.
- **Fix:** Include destination-close failure in the existing copy failure result and leave the source in place. Use the existing error return; no backup, retry or new wrapper is needed.
- **Justification:** This is a small check for an actual data-loss path. A host fault injection against RiptOPL's production move code made the destination close return EIO; the current move still returned success, reported no error, and deleted the source. POPSLoader's identical control-flow error was read directly; its platform close was not fault-injected.
- **Benefit:** Prevents source deletion after an unsuccessful destination commit. No byte/time saving claimed; the change adds only the close-result handling required for correctness.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; RiptOPL host fault injection; actual PS2 storage failure behavior INFERRED).

### CROSS-004 / Cancel the USB controller alarm with its original argument / Category 6

- **Location(s):** POPSLoader/modules/ds34usb/iop/ds34usb.c:464-480; POPSLoader/modules/pademu/ds34usb.c:495-511 (unused alternative tree); Launchstation/iop/ds34usb/iop/ds34usb.c:464-480. Correct existing precedent: RiptOPL/modules/ds34usb/iop/ds34usb.c:632-648.
- **Problem:** The affected USB transfer waits schedule a timeout with the semaphore as its callback argument, then attempt cancellation with a null argument. PS2 alarm cancellation identifies the callback/argument pair, so a nonzero semaphore's timeout can remain queued after successful USB completion and later signal a semaphore used by another transfer.
- **Fix:** Pass the original semaphore argument to cancellation, as RiptOPL already does. Delete the unused alternative source with POPSLOADER-022 rather than maintaining another copy.
- **Benefit:** Prevents stale timeout callbacks from releasing a later transfer early (hardware effect INFERRED). One argument substitution per live copy; no new state, allocation, retry or wrapper. No timing or ELF saving measured.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ for the mismatch and corrected existing implementation; hardware timing consequence INFERRED, not reproduced on PS2).

### Additional canonical shared controller findings

| Canonical finding | Affected repositories |
| --- | --- |
| [POPSLOADER-017](Codex-POPSLoader.md:28) | POPSLoader, Launchstation, RiptOPL; exact affected and already-corrected exceptions are listed once in that finding. |
| [POPSLOADER-042](Codex-POPSLoader.md:37) | POPSLoader, Launchstation, RiptOPL; exact affected and already-corrected exceptions are listed once in that finding. |
| [POPSLOADER-041](Codex-POPSLoader.md:228) | POPSLoader, Launchstation, RiptOPL; exact affected and already-corrected exceptions are listed once in that finding. |
| [POPSLOADER-018](Codex-POPSLoader.md:237) | POPSLoader, Launchstation, RiptOPL; exact affected and already-corrected exceptions are listed once in that finding. |

### CROSS-005 / Delete the cosmetic release draft-and-republish cycle / Categories 3, 7

- **Location(s):** RiptOPL/tools/publish_editions.py:511-541,623-624; RiptOPL/tools/publish_llvm.py:218-219; Launchstation/.github/workflows/compile.yml:755-767.
- **Problem:** Both release systems temporarily turn an already published release into a draft solely to refresh its displayed publication date. This hides updater/download URLs during the transition; if subsequent publication fails, the release can remain hidden.
- **Fix:** Delete the cosmetic draft/date-refresh operation, its callers and compensating retry/republication branches. Keep ordinary updates to the release assets, title, notes and target.
- **Benefit:** About 31 RiptOPL function lines plus call sites and roughly 12 Launchstation shell/comment lines removable; avoids deliberately hiding an existing release. Outage probability/duration and CI savings are INFERRED, not measured.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ for transitions and locations; persistent-outage scenario INFERRED).

## Cross-repository duplication inventory

This inventory is separate from actionable findings. SHA-256 equality established **77 identical source/header/script groups** across the five snapshots; it does not prove that independent executables can share runtime storage. These source groups account for **515,814 repeated checkout bytes** beyond one copy per group, not ELF/RAM savings. Files were hashed in full; a hash match does not count as semantic source review. Licence/notice duplication is excluded from recommendations.

The smallest useful response is to apply a validated common fix to every affected copy, or remove a copy only where an existing build already supplies its replacement. No shared runtime layer, new vendoring framework or common configuration system is proposed. The file-promotion behavior is covered once by CROSS-001; NFS parser behavior once by CROSS-002.

<details>
<summary>All identical source groups and every location</summary>

| Group | Bytes per copy | Locations |
| --- | ---: | --- |
| S001 | 25,912 | `Launchstation/iop/smbman/des.c`<br>`RiptOPL/modules/network/smbman-ra/des.c`<br>`Simple-Media-System/iop/smbman-sms/src/des.c` |
| S002 | 33,689 | `Launchstation/iop/smb2man/usmb2/usmb2.c`<br>`RiptOPL/modules/network/smb2man/usmb2/usmb2.c` |
| S003 | 27,877 | `Launchstation/iop/usbmass_bd/src/usb_mass.c`<br>`RiptOPL/modules/usb/usbmass_bd/src/usb_mass.c` |
| S004 | 25,481 | `Launchstation/iop/mx4sio_bd/src/mx4sio.c`<br>`RiptOPL/modules/mx4sio_bd/src/mx4sio.c` |
| S005 | 25,205 | `RiptOPL/modules/network/udpfs_smap/src/smap.c`<br>`Simple-Media-System/iop/SMSUdpfs/smap/src/smap.c` |
| S006 | 23,511 | `Launchstation/iop/usbd-ra/src/hub.c`<br>`RiptOPL/modules/usb/usbd-ra/src/hub.c` |
| S007 | 3,655 | `Launchstation/iop/ds34bt/iop/smsutils.S`<br>`Launchstation/iop/ds34usb/iop/smsutils.S`<br>`POPSLoader/modules/ds34bt/iop/smsutils.S`<br>`POPSLoader/modules/ds34usb/iop/smsutils.S`<br>`RiptOPL/modules/ds34bt/iop/smsutils.S`<br>`RiptOPL/modules/ds34usb/iop/smsutils.S`<br>`RiptOPL/modules/iopcore/cdvdman/smsutils.S` |
| S008 | 21,834 | `Launchstation/iop/mx4sio_bd/src/spi_sdcard_driver.c`<br>`RiptOPL/modules/mx4sio_bd/src/spi_sdcard_driver.c` |
| S009 | 16,815 | `Launchstation/iop/usbd-ra/src/hcd.c`<br>`RiptOPL/modules/usb/usbd-ra/src/hcd.c` |
| S010 | 13,864 | `Launchstation/iop/usbmass_bd/src/scsi.c`<br>`RiptOPL/modules/usb/usbmass_bd/src/scsi.c` |
| S011 | 12,193 | `Launchstation/iop/smb2man/usmb2/ntlm.c`<br>`RiptOPL/modules/network/smb2man/usmb2/ntlm.c` |
| S012 | 11,878 | `Launchstation/iop/usbd-ra/include/usbd.h`<br>`RiptOPL/modules/usb/usbd-ra/include/usbd.h` |
| S013 | 11,221 | `Launchstation/iop/usbd-ra/src/usbd.c`<br>`RiptOPL/modules/usb/usbd-ra/src/usbd.c` |
| S014 | 4,875 | `Launchstation/iop/smbman/md4.c`<br>`RiptOPL/modules/network/smbman-ra/md4.c`<br>`Simple-Media-System/iop/smbman-sms/src/md4.c` |
| S015 | 9,716 | `Launchstation/iop/mx4sio_bd/src/sio2man_hook.c`<br>`RiptOPL/modules/mx4sio_bd/src/sio2man_hook.c` |
| S016 | 9,549 | `Launchstation/iop/smb2man/smb2auth.c`<br>`RiptOPL/modules/iopcore/cdvdman/smb2auth.c` |
| S017 | 9,412 | `Launchstation/iop/usbd-ra/src/usbio.c`<br>`RiptOPL/modules/usb/usbd-ra/src/usbio.c` |
| S018 | 9,143 | `Launchstation/iop/mx4sio_bd/src/sio2regs.h`<br>`RiptOPL/modules/mx4sio_bd/src/sio2regs.h` |
| S019 | 8,477 | `Launchstation/iop/usbd-ra/include/usbd_macro.h`<br>`RiptOPL/modules/usb/usbd-ra/include/usbd_macro.h` |
| S020 | 8,465 | `Launchstation/iop/usbd-ra/src/interface.c`<br>`RiptOPL/modules/usb/usbd-ra/src/interface.c` |
| S021 | 8,226 | `Launchstation/iop/usbd-ra/src/usbdpriv.h`<br>`RiptOPL/modules/usb/usbd-ra/src/usbdpriv.h` |
| S022 | 2,582 | `Launchstation/iop/mmceman/src/ioplib.c`<br>`Launchstation/iop/mx4sio_bd/src/ioplib.c`<br>`RiptOPL/modules/mmce/mmceman/src/ioplib.c`<br>`RiptOPL/modules/mx4sio_bd/src/ioplib.c` |
| S023 | 2,474 | `RiptOPL/modules/network/udpfs_bd/src/udpfs_core.h`<br>`RiptOPL/modules/network/udpfs_fhi/src/udpfs_core.h`<br>`RiptOPL/modules/network/udpfs_ioman/src/udpfs_core.h`<br>`Simple-Media-System/iop/SMSUdpfs/udpfs/src/udpfs_core.h` |
| S024 | 7,251 | `Launchstation/iop/smb2man/usmb2/unicode.c`<br>`RiptOPL/modules/network/smb2man/usmb2/unicode.c` |
| S025 | 6,965 | `Launchstation/iop/usbd-ra/src/driver.c`<br>`RiptOPL/modules/usb/usbd-ra/src/driver.c` |
| S026 | 6,849 | `Launchstation/iop/smb2man/usmb2/md4c.c`<br>`RiptOPL/modules/network/smb2man/usmb2/md4c.c` |
| S027 | 6,703 | `Launchstation/iop/usbd-ra/src/mem.c`<br>`RiptOPL/modules/usb/usbd-ra/src/mem.c` |
| S028 | 6,520 | `PS2-Servers/vendor/retroachievements/xerabora/protocol/ra_watch.h`<br>`RiptOPL/.github/scripts/fixtures/xerabora-alpha16/ra_watch.h` |
| S029 | 6,491 | `Launchstation/iop/ps2hdd_osd/libapa.h`<br>`RiptOPL/modules/hdd/apa/src/libapa.h` |
| S030 | 6,394 | `Launchstation/iop/smb2man/usmb2/md5.c`<br>`RiptOPL/modules/network/smb2man/usmb2/md5.c` |
| S031 | 5,532 | `PS2-Servers/vendor/retroachievements/xerabora/client/src/snapshot.c`<br>`RiptOPL/.github/scripts/fixtures/xerabora-alpha16/snapshot.c` |
| S032 | 5,391 | `Launchstation/iop/smb2man/usmb2/usmb2.h`<br>`RiptOPL/modules/network/smb2man/usmb2/usmb2.h` |
| S033 | 4,867 | `Launchstation/iop/mx4sio_bd/src/spi_sdcard_driver.h`<br>`RiptOPL/modules/mx4sio_bd/src/spi_sdcard_driver.h` |
| S034 | 905 | `Launchstation/iop/ds34bt/iop/irx_imports.h`<br>`Launchstation/iop/ds34usb/iop/irx_imports.h`<br>`POPSLoader/modules/ds34bt/iop/irx_imports.h`<br>`POPSLoader/modules/ds34usb/iop/irx_imports.h`<br>`RiptOPL/modules/ds34bt/iop/irx_imports.h`<br>`RiptOPL/modules/ds34usb/iop/irx_imports.h` |
| S035 | 1,435 | `Launchstation/iop/mmceman/include/ioplib.h`<br>`Launchstation/iop/mx4sio_bd/src/ioplib.h`<br>`RiptOPL/modules/mmce/mmceman/include/ioplib.h`<br>`RiptOPL/modules/mx4sio_bd/src/ioplib.h` |
| S036 | 2,012 | `Launchstation/iop/smbman/poll.c`<br>`RiptOPL/modules/network/smbman-ra/poll.c`<br>`Simple-Media-System/iop/smbman-sms/src/poll.c` |
| S037 | 3,392 | `PS2-Servers/vendor/retroachievements/rcheevos/src/rhash/md5.h`<br>`RiptOPL/include/md5.h` |
| S038 | 3,317 | `Launchstation/iop/ds34bt/ee/libds34bt.c`<br>`POPSLoader/modules/ds34bt/ee/libds34bt.c` |
| S039 | 3,166 | `Launchstation/iop/mx4sio_bd/src/spi_sdcard_crc7.c`<br>`RiptOPL/modules/mx4sio_bd/src/spi_sdcard_crc7.c` |
| S040 | 3,137 | `PS2-Servers/vendor/retroachievements/xerabora/protocol/ra_snap.h`<br>`RiptOPL/.github/scripts/fixtures/xerabora-alpha16/ra_snap.h` |
| S041 | 1,341 | `Launchstation/iop/smbman/smb_fio.h`<br>`RiptOPL/modules/network/smbman-ra/smb_fio.h`<br>`Simple-Media-System/iop/smbman-sms/src/smb_fio.h` |
| S042 | 2,644 | `Launchstation/iop/smbman/auth.c`<br>`RiptOPL/modules/network/smbman-ra/auth.c` |
| S043 | 1,017 | `Launchstation/iop/udpfs_smap/include/main.h`<br>`RiptOPL/modules/network/udpfs_smap/include/main.h`<br>`Simple-Media-System/iop/SMSUdpfs/smap/include/main.h` |
| S044 | 1,971 | `Launchstation/iop/mx4sio_bd/src/mx4sio.h`<br>`RiptOPL/modules/mx4sio_bd/src/mx4sio.h` |
| S045 | 821 | `Launchstation/iop/ata_bd/src/irx_imports.h`<br>`POPSLoader/iop/ata_bd_fast/irx_imports.h`<br>`RiptOPL/modules/hdd/atad/src/irx_imports.h` |
| S046 | 1,521 | `Launchstation/iop/udpfs_smap/include/smap.h`<br>`Simple-Media-System/iop/SMSUdpfs/smap/include/smap.h` |
| S047 | 1,509 | `Launchstation/iop/smb2man/usmb2/md4.h`<br>`RiptOPL/modules/network/smb2man/usmb2/md4.h` |
| S048 | 1,343 | `Launchstation/iop/smb2man/smb2auth.h`<br>`RiptOPL/modules/iopcore/cdvdman/smb2auth.h` |
| S049 | 1,323 | `RiptOPL/modules/network/udpfs_smap/include/xfer.h`<br>`Simple-Media-System/iop/SMSUdpfs/smap/include/xfer.h` |
| S050 | 653 | `Launchstation/iop/nfsman/irx_imports.h`<br>`Launchstation/iop/smb2man/irx_imports.h`<br>`RiptOPL/modules/network/nfsman/irx_imports.h` |
| S051 | 1,204 | `POPSLoader/modules/pademu/pademu.h`<br>`RiptOPL/modules/pademu/pademu.h` |
| S052 | 563 | `Launchstation/iop/udpfs_smap/src/main.c`<br>`RiptOPL/modules/network/udpfs_smap/src/main.c`<br>`Simple-Media-System/iop/SMSUdpfs/smap/src/main.c` |
| S053 | 1,108 | `Launchstation/iop/usbd-ra/src/mem.h`<br>`RiptOPL/modules/usb/usbd-ra/src/mem.h` |
| S054 | 1,094 | `Launchstation/iop/mmceman/include/sio2man_hook.h`<br>`RiptOPL/modules/mmce/mmceman/include/sio2man_hook.h` |
| S055 | 1,094 | `Launchstation/iop/mx4sio_bd/src/sio2man_hook.h`<br>`RiptOPL/modules/mx4sio_bd/src/sio2man_hook.h` |
| S056 | 1,070 | `Launchstation/iop/mmceman/include/mmce_sio2.h`<br>`RiptOPL/modules/mmce/mmceman/include/mmce_sio2.h` |
| S057 | 1,045 | `Launchstation/iop/mx4sio_bd/src/crc16.c`<br>`RiptOPL/modules/mx4sio_bd/src/crc16.c` |
| S058 | 965 | `Launchstation/iop/usbd-ra/src/driver.h`<br>`RiptOPL/modules/usb/usbd-ra/src/driver.h` |
| S059 | 962 | `Launchstation/iop/usbd-ra/src/usbio.h`<br>`RiptOPL/modules/usb/usbd-ra/src/usbio.h` |
| S060 | 952 | `Launchstation/iop/usbmass_bd/src/include/scsi.h`<br>`RiptOPL/modules/usb/usbmass_bd/src/include/scsi.h` |
| S061 | 952 | `POPSLoader/modules/pademu/irx_imports.h`<br>`RiptOPL/modules/pademu/irx_imports.h` |
| S062 | 903 | `Launchstation/iop/usbd-ra/src/hcd.h`<br>`RiptOPL/modules/usb/usbd-ra/src/hcd.h` |
| S063 | 814 | `Launchstation/iop/smb2man/usmb2/hmac-md5.h`<br>`RiptOPL/modules/network/smb2man/usmb2/hmac-md5.h` |
| S064 | 811 | `Launchstation/iop/smb2man/ps2iop-compat.h`<br>`RiptOPL/modules/network/smb2man/ps2iop-compat.h` |
| S065 | 801 | `Launchstation/iop/usbmass_bd/src/main.c`<br>`RiptOPL/modules/usb/usbmass_bd/src/main.c` |
| S066 | 789 | `Launchstation/tests/smb2man_live/inc/sysmem.h`<br>`RiptOPL/tests/smb2-live/inc-browse/sysmem.h` |
| S067 | 788 | `RiptOPL/modules/network/udpfs_ministack/src/ministack_eth.c`<br>`Simple-Media-System/iop/SMSUdpfs/ministack/src/ministack_eth.c` |
| S068 | 787 | `Launchstation/iop/mmceman/include/irx_imports.h`<br>`RiptOPL/modules/mmce/mmceman/include/irx_imports.h` |
| S069 | 780 | `Launchstation/iop/usbd-ra/src/irx_imports.h`<br>`RiptOPL/modules/usb/usbd-ra/src/irx_imports.h` |
| S070 | 765 | `Launchstation/iop/mx4sio_bd/src/irx_imports.h`<br>`RiptOPL/modules/mx4sio_bd/src/irx_imports.h` |
| S071 | 765 | `POPSLoader/modules/pademu/sys_utils.h`<br>`RiptOPL/modules/pademu/sys_utils.h` |
| S072 | 750 | `Launchstation/iop/usbmass_bd/src/include/module_debug.h`<br>`RiptOPL/modules/usb/usbmass_bd/src/include/module_debug.h` |
| S073 | 735 | `Launchstation/iop/usbmass_bd/src/irx_imports.h`<br>`RiptOPL/modules/usb/usbmass_bd/src/irx_imports.h` |
| S074 | 716 | `Launchstation/iop/ps2ips_rpc/irx_imports.h`<br>`RiptOPL/modules/network/ps2ips/irx_imports.h` |
| S075 | 715 | `Launchstation/iop/mx4sio_bd/src/spi_sdcard_driver_config.h`<br>`RiptOPL/modules/mx4sio_bd/src/spi_sdcard_driver_config.h` |
| S076 | 676 | `RiptOPL/modules/network/smbman-ra/smbman.c`<br>`Simple-Media-System/iop/smbman-sms/src/smbman.c` |
| S077 | 615 | `Launchstation/iop/smb2man/usmb2/md5.h`<br>`RiptOPL/modules/network/smb2man/usmb2/md5.h` |

</details>

<details>
<summary>Identical binary/asset groups across repositories (inventory, not removal instructions)</summary>

Binary files have no source line numbers. Equality and byte counts were measured; their runtime necessity was not established solely by this check. RiptOPL’s unused repeated example payload is the actionable subset in RIPTOPL-903.

| Group | Bytes per copy | Locations |
| --- | ---: | --- |
| B001 | 167,700 | `POPSLoader/bin/POPSLDR/POPSTARTER.ELF`<br>`POPSLoader/bin/POPSLDR/PROFILES/DEBUG/POPSTARTER.ELF`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/POPSTARTER VERSIONS/DEBUG/POPSTARTER.ELF`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/POPSTARTER.ELF`<br>`RiptOPL/ship/POPS/POPSTARTER VERSIONS/DEBUG/POPSTARTER.ELF`<br>`RiptOPL/ship/POPS/POPSTARTER.ELF` |
| B002 | 327,360 | `POPSLoader/bin/POPSLDR/PATCH_5.BIN`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/PATCH_5.BIN`<br>`RiptOPL/ship/POPS/PATCH_5.BIN` |
| B003 | 48,500 | `POPSLoader/bin/POPSLDR/usbd.irx.ilink`<br>`POPSLoader/bin/POPSLDR/usbd.irx.mx4sio`<br>`POPSLoader/bin/POPSLDR/usbd.irx.usbexfat`<br>`POPSLoader/iop/embed/BDMASSAULT_MX4SIO/usbd.irx`<br>`RiptOPL/modules/bdmassault/usbd.irx.ilink`<br>`RiptOPL/modules/bdmassault/usbd.irx.usbexfat`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbd.irx.mx4sio`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbd.irx.usbexfat`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/usbd.irx.ilink`<br>`RiptOPL/ship/POPS/usbd.irx.ilink`<br>`RiptOPL/ship/POPS/usbd.irx.mx4sio`<br>`RiptOPL/ship/POPS/usbd.irx.usbexfat` |
| B004 | 167,700 | `POPSLoader/bin/POPSLDR/PROFILES/MAIN/POPSTARTER.ELF`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/POPSTARTER VERSIONS/MAIN/POPSTARTER.ELF`<br>`RiptOPL/ship/POPS/POPSTARTER VERSIONS/MAIN/POPSTARTER.ELF` |
| B005 | 167,700 | `POPSLoader/bin/POPSLDR/PROFILES/USBDELAY/POPSTARTER.ELF`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/POPSTARTER VERSIONS/USBDELAY/POPSTARTER.ELF`<br>`RiptOPL/ship/POPS/POPSTARTER VERSIONS/USBDELAY/POPSTARTER.ELF` |
| B006 | 167,700 | `POPSLoader/bin/POPSLDR/PROFILES/USBDELAY_DEBUG/POPSTARTER.ELF`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/POPSTARTER VERSIONS/USBDELAY_DEBUG/POPSTARTER.ELF`<br>`RiptOPL/ship/POPS/POPSTARTER VERSIONS/USBDELAY_DEBUG/POPSTARTER.ELF` |
| B007 | 109,497 | `POPSLoader/POPSTARTER/ps2ip.irx`<br>`POPSLoader/bin/POPSLDR/popsmb/ps2ip.irx`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/ps2ip.irx`<br>`RiptOPL/ship/POPS/ps2ip.irx` |
| B008 | 61,740 | `POPSLoader/POPSTARTER/del.icn`<br>`POPSLoader/bin/POPSLDR/del.icn.bdma`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/del.icn`<br>`RiptOPL/ship/POPS/del.icn` |
| B009 | 34,508 | `POPSLoader/bin/POPSLDR/usbhdfsd.irx.udpfs`<br>`POPSLoader/bin/POPSLDR/usbhdfsd.irx.usbexfat`<br>`RiptOPL/modules/bdmassault/usbhdfsd.irx.usbexfat`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbhdfsd.irx.usbexfat`<br>`RiptOPL/ship/POPS/usbhdfsd.irx.udpfs`<br>`RiptOPL/ship/POPS/usbhdfsd.irx.usbexfat` |
| B010 | 46,540 | `POPSLoader/POPSTARTER/list.icn`<br>`POPSLoader/bin/POPSLDR/list.icn.bdma`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/list.icn`<br>`RiptOPL/ship/POPS/list.icn` |
| B011 | 44,329 | `POPSLoader/POPSTARTER/smbman.irx`<br>`POPSLoader/bin/POPSLDR/popsmb/smbman.irx`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/smbman.irx`<br>`RiptOPL/ship/POPS/smbman.irx` |
| B012 | 42,749 | `POPSLoader/bin/POPSLDR/usbd.irx.ata`<br>`RiptOPL/modules/bdmassault/usbd.irx.ata`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbd.irx.ata`<br>`RiptOPL/ship/POPS/usbd.irx.ata` |
| B013 | 27,769 | `POPSLoader/bin/POPSLDR/usbhdfsd.irx.ilink`<br>`RiptOPL/modules/bdmassault/usbhdfsd.irx.ilink`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/usbhdfsd.irx.ilink`<br>`RiptOPL/ship/POPS/usbhdfsd.irx.ilink` |
| B014 | 21,837 | `POPSLoader/bin/POPSLDR/usbhdfsd.irx.ata`<br>`RiptOPL/modules/bdmassault/usbhdfsd.irx.ata`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbhdfsd.irx.ata`<br>`RiptOPL/ship/POPS/usbhdfsd.irx.ata` |
| B015 | 61,949 | `POPSLoader/bin/POPSLDR/usbd.irx.udpfs`<br>`RiptOPL/ship/POPS/usbd.irx.udpfs` |
| B016 | 14,993 | `POPSLoader/bin/POPSLDR/usbhdfsd.irx.mx4sio`<br>`POPSLoader/iop/embed/BDMASSAULT_MX4SIO/usbhdfsd.irx`<br>`RiptOPL/modules/bdmassault/usbhdfsd.irx.mx4sio`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbhdfsd.irx.mx4sio`<br>`RiptOPL/ship/POPS/usbhdfsd.irx.mx4sio` |
| B017 | 19,733 | `POPSLoader/bin/POPSLDR/usbhdfsd.irx.mmce`<br>`RiptOPL/modules/bdmassault/usbhdfsd.irx.mmce`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbhdfsd.irx.mmce`<br>`RiptOPL/ship/POPS/usbhdfsd.irx.mmce` |
| B018 | 12,605 | `POPSLoader/POPSTARTER/ps2smap.irx`<br>`POPSLoader/bin/POPSLDR/popsmb/ps2smap.irx`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/ps2smap.irx`<br>`RiptOPL/ship/POPS/ps2smap.irx` |
| B019 | 11,841 | `POPSLoader/bin/POPSLDR/usbd.irx.mmce`<br>`RiptOPL/modules/bdmassault/usbd.irx.mmce`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbd.irx.mmce`<br>`RiptOPL/ship/POPS/usbd.irx.mmce` |
| B020 | 11,505 | `POPSLoader/POPSTARTER/ps2dev9.irx`<br>`POPSLoader/bin/POPSLDR/popsmb/ps2dev9.irx`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/ps2dev9.irx`<br>`RiptOPL/ship/POPS/ps2dev9.irx` |
| B021 | 11,633 | `Launchstation/iop/__precompiled/udpfs_ioman.irx`<br>`POPSLoader/iop/embed/udpfs_ioman.irx`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/udpfs_ioman.irx` |
| B022 | 8,081 | `Launchstation/iop/__precompiled/udpfs_smap.irx`<br>`POPSLoader/iop/embed/udpfs_net_smap.irx`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/smap.irx` |
| B023 | 3,413 | `POPSLoader/POPSTARTER/poweroff.irx`<br>`POPSLoader/bin/POPSLDR/popsmb/poweroff.irx`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/poweroff.irx`<br>`RiptOPL/ship/POPS/poweroff.irx` |
| B024 | 5,025 | `Launchstation/iop/__precompiled/udpfs_ministack.irx`<br>`POPSLoader/iop/embed/udpfs_ministack.irx`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/ministack.irx` |
| B025 | 2,063 | `Launchstation/res/icons/L3.png`<br>`POPSLoader/bin/POPSLDR/IMG/L3.png`<br>`RiptOPL/gfx/L3.png` |
| B026 | 1,305 | `POPSLoader/POPSTARTER/SMSUTILS.irx`<br>`POPSLoader/bin/POPSLDR/popsmb/SMSUTILS.irx`<br>`RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/SMSUTILS.irx`<br>`RiptOPL/ship/POPS/SMSUTILS.irx` |
| B027 | 1,492 | `Launchstation/res/icons/R1.png`<br>`POPSLoader/bin/POPSLDR/IMG/R1.png`<br>`RiptOPL/gfx/R1.png` |
| B028 | 1,455 | `Launchstation/res/icons/L1.png`<br>`POPSLoader/bin/POPSLDR/IMG/L1.png`<br>`RiptOPL/gfx/L1.png` |
| B029 | 2,019 | `Launchstation/res/icons/circle.png`<br>`POPSLoader/bin/POPSLDR/IMG/circle.png` |
| B030 | 2,013 | `Launchstation/res/icons/cross.png`<br>`POPSLoader/bin/POPSLDR/IMG/cross.png` |
| B031 | 2,010 | `Launchstation/res/icons/triangle.png`<br>`POPSLoader/bin/POPSLDR/IMG/triangle.png` |
| B032 | 1,999 | `Launchstation/res/icons/square.png`<br>`POPSLoader/bin/POPSLDR/IMG/square.png` |
| B033 | 1,924 | `Launchstation/res/icons/R3.png`<br>`POPSLoader/bin/POPSLDR/IMG/R3.png` |
| B034 | 1,843 | `Launchstation/res/icons/down.png`<br>`POPSLoader/bin/POPSLDR/IMG/down.png` |
| B035 | 1,833 | `Launchstation/res/icons/right.png`<br>`POPSLoader/bin/POPSLDR/IMG/right.png` |
| B036 | 1,827 | `Launchstation/res/icons/R2.png`<br>`POPSLoader/bin/POPSLDR/IMG/R2.png` |
| B037 | 1,778 | `Launchstation/res/icons/up.png`<br>`POPSLoader/bin/POPSLDR/IMG/up.png` |
| B038 | 1,764 | `Launchstation/res/icons/left.png`<br>`POPSLoader/bin/POPSLDR/IMG/left.png` |
| B039 | 1,692 | `Launchstation/res/icons/L2.png`<br>`POPSLoader/bin/POPSLDR/IMG/L2.png` |
| B040 | 649 | `Launchstation/res/icons/select.png`<br>`POPSLoader/bin/POPSLDR/IMG/select.png`<br>`RiptOPL/gfx/select.png` |
| B041 | 1,014 | `Launchstation/res/icons/start.png`<br>`POPSLoader/bin/POPSLDR/IMG/start.png` |

</details>

## Branch and tag inventory — list only

Read-only git ls-remote snapshots were captured with the source snapshots. Annotated tags and their peeled commit entries count as one tag. No ref was changed.

| Repository | Branches | Tags |
| --- | ---: | ---: |
| Launchstation | 103 | 140 |
| POPSLoader | 36 | 37 |
| PS2-Servers | 158 | 118 |
| RiptOPL | 272 | 5 |
| Simple-Media-System | 49 | 13 |

**Explicitly documented archival branch:** POPSLoader `BETA-12-PLAY` (POPSLoader/AGENTS.md:12 says archival/frozen). This is an inventory entry, not a deletion instruction.

**Archive/checkpoint-looking names — INFERRED candidates only:** their names suggest historical snapshots, but they are not proven merged, unused or safe to remove. Tip dates and ancestry were not established by the shallow default-branch audit. Active development branches and ordinary version tags are not called stale merely because there are many.

- **Launchstation:** tag `preview-codex-usb-before-pad`
- **POPSLoader:** branch `CHECKPOINT2`; tag `backup/pre-hdd-cache-2026-06-19`; tag `checkpoint/2026-06-16-audit-fixes`; tag `checkpoint/BETA-12-PLAY-before-phase3-2026-06-18`; tag `checkpoint/master-before-beta12-2026-06-18`; tag `checkpoint/master-before-dkwdrv-merge-20260523-132143`; tag `checkpoint/master-before-real-dkwdrv-merge-20260523-132313`
- **PS2-Servers:** branch `backup/edge-flag-exposure-139`; branch `backup/main-before-139`; branch `backup/main-before-140`; branch `backup/main-before-141`; branch `backup/main-before-142`; branch `backup/one-version-number-141`; branch `backup/pre-av-cleanup-2026-06-30`; branch `backup/protocol-mode-selector-142`; branch `backup/tagged-release-notes-140`
- **RiptOPL:** No additional archival intent established from the inspected names.
- **Simple-Media-System:** branch `checkpoint-2026-07-11-post-audit`; branch `checkpoint-2026-07-11-pre-compression`; branch `checkpoint-2026-07-12-full-stack`; branch `checkpoint-2026-07-12-post-irx-compression`; branch `checkpoint-2026-07-27-netmode-menu`; branch `pre-esds-checkpoint`; branch `pre-kimi-checkpoint`; tag `checkpoint-mx4sio-working`

POPSLoader’s spent retraction workflow names `1.3.0-ember-beta.1`; neither that tag nor its v-prefixed spelling was present in the ref snapshot. Removing the spent workflow is a repository cleanup opportunity; no release or tag deletion was performed.

Remaining category-7 work: branch-tip age/ancestry and activity checks are needed to certify any other stale ref. Historical branch source trees and tag snapshots were not audited.
