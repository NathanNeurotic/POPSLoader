# W01 — Blind Redo Audit: RiptOPL `src/sources/`

- Clone pin verified before reading: `git rev-parse HEAD` = `2e347d5ac885cd0ff73e9ad4143781946396f492`.
- Scope: all 31 files in `src/sources/` (31,201 lines by `wc -l`). Read-only; no clone files were modified.
- Rule applied throughout: LESS, NOT MORE — every fix below removes, simplifies, or consolidates; anything that would add code says so and justifies it.
- Counts cited are from commands actually run in this session (`wc -l`, `grep -n`, and Python censuses over the scope), never estimates. Where a number is derived rather than measured it is labelled INFERRED.

---

### W01-001 — Neutrino / custom-loader path resolution is a ~630-line probing subsystem for "find one ELF"
- **Category:** 3 overengineering
- **Locations:** `RiptOPL/src/sources/supportbase.cpp:1969-2590` (the resolver family: `sbNeutrinoInstallComplete` 1969, `sbNeutrinoResolved` 1994, `sbNeutrinoProbeGameDevice` 2027, `sbResolveCustomLoaderPath` 2235-2488, `sbResolveMigratedApaNeutrino` 2489, `sbProbeNeutrinoMc` 2517, `sbResolveMigratedNeutrino` 2539, `sbResolveNeutrinoPath` 2551)
- **Problem:** Resolving one `neutrino.elf` / POPSTARTER path takes ~632 lines (measured: lines 1969-2600). `sbResolveCustomLoaderPath` alone is ~254 lines of per-alias branches (mc, mmce, smb, udpfs, udpbd/udpfsbd/udpfsd, pfs, hdd, rom, typed mass/BDM), each with slot/`?`-wildcard handling; on top of it sit a game-device probe (2 bases × case forms), an 8-candidate memory-card probe, and two "migrated install" resolvers (plain + APA variant) that re-probe the same locations under different spellings. Census: 51 references to the `sbResolveNeutrino*`/`sbNeutrino*` family across the scope. Every new device spelling historically grows another branch here instead of the search space shrinking.
- **Fix:** Cut the search space, not the code around it: keep (a) the user-entered full path used verbatim if the file exists, and (b) one probe of the active game device's prefix. Delete the migrated-install resolvers, the multi-spelling MC probe list, and the per-alias wildcard/slot guessing; a path that does not resolve then reports "not found" with the path the user can fix, which `vcdDescribePopstarterLookup`-style reporting already does for POPSTARTER.
- **Benefit:** Removes several hundred lines of the most branch-dense code in the scope and the whole class of "resolved to the wrong device's copy" behaviour; resolution becomes predictable enough to describe in one sentence.
- **Effort:** L · **Risk:** Med (a layout that only the deleted probing found will stop auto-resolving; the user-entered path remains as the explicit route) · **Confidence:** High — READ (all cited ranges opened; line counts measured).

### W01-002 — The native PS2 launch sequence is re-implemented once per backend
- **Category:** 2 duplication
- **Locations:** `RiptOPL/src/sources/bdmlaunch.cpp:606-999` (`BdmLauncher::launch` tail / `bdmLaunchGame`), `RiptOPL/src/sources/ethsupport.cpp:1282-1520` (`EthSource::launch`), `RiptOPL/src/sources/mmcesupport.cpp:1292-1745` (`MmceSource::launch`), `RiptOPL/src/sources/hddsupport.cpp:2572-2850` (`HddSource::launch`), `RiptOPL/src/sources/udpfssupport.cpp:880-1035` (`udpfsLaunchOplCore`), `RiptOPL/src/sources/httpsupport.cpp:735-860` (`HttpSource::launch`)
- **Problem:** Every backend hand-copies the same ordered ritual: VMC slot loop writing into the mcemu IRX via `nativeVmcSlotWord`, `sbPrepare`, last-played save, cheats (`sbLoadCheats` + `sbCheatsMissingContinue`), `sbLoadImage`, per-part ISO size summation, layer-1 probing (`sbGetISO9660MaxLBA`/`sbProbeISO9660`), `mmceSendGameID`, deinit, `sysLaunchLoaderElf`. The per-part size loop is byte-for-byte the same logic in three files (bdmlaunch.cpp:811-859, ethsupport.cpp:1449-1481, mmcesupport.cpp:1480-1512, each headed by the identical "Sum the size of all parts… upstream OPL #1763" comment). Censuses: `sbPrepare` 11 call sites, `sbLoadCheats` 10, `sbLoadImage` 9, `CheckPS2Logo` 10, `mmceSendGameID` 21 references in scope. Each copy has already drifted in small ways (which steps run, in which order, what is closed on bail), so a fix to the ritual must be made six times.
- **Fix:** One shared launch-sequence helper in supportbase.cpp that takes the already-existing per-backend differences as data (prefix, separator, cdvdman IRX + settings pointer, launch mode string) and performs the common steps once; backends keep only what is genuinely device-specific (their VMC info struct, their settings fields, UDPFS's keep-handle leg). Delete the six copies, including the three duplicated size loops.
- **Justification (fix adds a helper):** The same logic already exists in 6 places and sharing removes far more code than the helper adds — this is the stated exception to the no-new-abstraction rule.
- **Benefit:** One place to fix launch-ordering bugs (the file comments record several that were exactly this: steps running before/after a card switch in one backend but not another); net deletion of several hundred lines.
- **Effort:** L · **Risk:** Med (launch paths are the product; each backend's bail-out cleanup must be preserved in the shared version) · **Confidence:** High — READ.

### W01-003 — The PS1 launch (POPSTARTER/VCD and Ember/Cue) is re-implemented once per backend
- **Category:** 2 duplication
- **Locations:** `RiptOPL/src/sources/bdmlaunch.cpp:58-257` (`BdmLauncher::launchCue`/`launchVcd`), `RiptOPL/src/sources/ethsupport.cpp:998-1160` (`EthSource::launchVcd`/`launchCue`), `RiptOPL/src/sources/mmcesupport.cpp:1187-1290` (`MmceSource::launchCue`/`launchVcd`), `RiptOPL/src/sources/udpfssupport.cpp:766-880` (`UdpfsSource::launchVcd`/`launchCue`), `RiptOPL/src/sources/hddsupport.cpp:2130-2360` (`hddDoLaunchEmber`/`hddDoLaunchVcd`, reached from `HddSource::launchVcd` 2308 and `launchCue` 3223)
- **Problem:** Five separate implementations of the same two hand-offs: reject empty/reserved name → resolve core ELF (POPSTARTER via `vcdResolvePopstarter`, Ember via `cueResolveEmber`/`cueResolveEmberBios`) → prepare (`cuePrepareLaunch`, `vcdConfirmPopsFiles`, BDMA equip for VCD) → RetroGEM barcode → deinit with the right exception → `sysLaunchPopstarter`/`sysLaunchEmber`. The shared primitives already exist in cuesupport.cpp/vcdsupport.cpp; what is duplicated is the sequencing, the dialogs, and the bail-out order — and those have visibly diverged (e.g. only MMCE/BDM quiesce art reads before the VCD leg; only UDPFS hard-gates on `vcdBdmaLaunchReady`; HDD needs its own pfs0: remount dance). Favourites then proxies into whichever copy a device owns (favsupport.cpp:1290-1330), so divergence is user-visible from the FAV tab too.
- **Fix:** One shared PS1 launch sequencer per core in vcdsupport.cpp/cuesupport.cpp, parameterised only by device root and the two genuinely device-specific steps (MMCE art quiesce, HDD pfs0: remount, UDPFS driver gate); delete the per-backend copies and keep thin per-device hooks only where a step truly differs.
- **Justification (fix adds a shared sequencer):** Same logic in 5 places; sharing removes code overall.
- **Benefit:** A PS1 launch fix (name validation, barcode, dialog order) lands once; the FAV tab stops inheriting five different behaviours for the same row.
- **Effort:** L · **Risk:** Med · **Confidence:** High — READ.

### W01-004 — The ps2ips 48-byte-tail peek/truncate receive workaround exists in three copies
- **Category:** 2 duplication
- **Locations:** `RiptOPL/src/sources/ranet.cpp:1072-1081` (`Ranet::tcpRecv`), `RiptOPL/src/sources/ratls_ps2.cpp:156-165` (non-RA `ratlsTcpRecv`), `RiptOPL/src/sources/nettime.cpp:117-125` (inlined inside `netTimeAsk`)
- **Problem:** The identical non-obvious arithmetic — peek, then `if (got > 64 && got % 64 > 48) got -= got % 64 - 48;`, then take — is written out three times (census: the `got % 64` pattern occurs at exactly these three sites). The ratls copy even carries the comment "Ranet::tcpRecv (ranet.cpp, RA only)" admitting it is a copy, and it hard-codes the lwIP flag values (`0x08 | 0x01`) where ranet uses named constants. If the ps2ips side-buffer size (RESTS_EBUF_MAX, 48) ever changes, three places must change in lockstep and nothing enforces it.
- **Fix:** Delete the ratls fallback copy and the nettime inline copy; both call the one implementation (ranet's, exported the way `raNetTcpRecv` already exports it for the RA build of ratls). No new helper is needed — one already exists and is already shared in one build flavour.
- **Benefit:** One definition of a workaround whose correctness depends on a constant owned by another module; removes ~15 duplicated lines and the named-vs-magic flag divergence.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ (all three bodies opened and compared).

### W01-005 — The "NIC is reserved by a UDP transport" predicate exists in three copies
- **Category:** 2 duplication
- **Locations:** `RiptOPL/src/sources/ranet.cpp:217-231` (`Ranet::nicBusy` + `Ranet::nicReserved`), `RiptOPL/src/sources/ratls_ps2.cpp:143-153` (`ratlsNicReserved`, non-RA branch), `RiptOPL/src/sources/nettime.cpp:138-140` (inlined at the top of `netTimeFetch`)
- **Problem:** The same policy — UDPBD/UDPFS module resident, or a UDP protocol selected in `gNetworkProtocol` — is spelled out three times, in two different shapes (ranet splits it into `nicBusy`/`nicReserved`; ratls and nettime inline the union). The three callers (RA networking, HTTPS, network time) must agree on this predicate or one of them will try to raise SMB on a NIC a UDP transport owns; agreement is currently maintained by hand-copying.
- **Fix:** Delete the ratls and nettime copies; both call the ranet predicate (it is already the canonical one — ratls's own comment calls its copy "Ranet::nicReserved (ranet.cpp, RA only)").
- **Benefit:** One policy definition for NIC ownership; removes two hand-maintained copies of a five-term condition.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ.

### W01-006 — `struct hostent` is defined twice because `<netdb.h>` only declares it
- **Category:** 2 duplication
- **Locations:** `RiptOPL/src/sources/ratls_ps2.cpp:39-48`, `RiptOPL/src/sources/nettime.cpp:30-38`
- **Problem:** Both files define lwIP's `hostent` layout locally, with near-identical explanatory comments ("<netdb.h> only declares struct hostent…", "…as in ratls_ps2.cpp"). Two definitions of an ABI layout for the same library struct can silently diverge; the second author already had to know the first file existed.
- **Fix:** Define it once in a header both files already include (or one small existing network header) and delete both local definitions.
- **Justification (fix touches a header):** Removes two definitions and adds one — net fewer definitions of an ABI-critical struct.
- **Benefit:** One ABI definition; ~10 lines deleted.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ.

### W01-007 — MMCE GameID card-switch waiting is six overlapping wait/settle mechanisms
- **Category:** 3 overengineering (with 2 duplication)
- **Locations:** `RiptOPL/src/sources/mmcesupport.cpp:146-353` (`MmceSupport::sendGameID`, with its own start-poll loop), `:314-353` (`waitCardReady`), `:373-415` (`waitSwapDoneOn`), `:417-423` (`waitSwapDone`), `:434-449` (`waitBeforeHandoff`), `:451-498` (`waitHistorySwitch`), `:500-520` (`gameIdSettle`), `:598-630` (`settleAfterSwitch`)
- **Problem:** One physical event — "the SD2PSX card is switching folders; wait until it answers again" — is waited out by at least six distinct functions, each with its own poll interval, silence bound, failure counter, START-press latch handling, and tri-state result convention (`sendGameID` returns 1/0/-1 with "truthy on purpose" semantics its callers must know). The constants alone fill a screen (MMCE_GAMEID_START_MS, …QUERY_FAILURES, …QUERY_SILENT, CARD_READY_MAX_S, CARD_READY_SILENT_MS, HISTORY_SWITCH_WINDOW_MS, GAMEID_WAIT_TICKS, ART_ABORT_WAIT_TICKS). Call sites must compose them correctly (`waitSwapDone` → `settleAfterSwitch` → `waitBeforeHandoff` → `settleAfterSwitch` again appears in the launch legs at 1412-1434 and 1658-1729), and the comments record multiple production hangs caused by composing them in the wrong order or missing one.
- **Fix:** Collapse to two primitives: one "wait until this device answers presence and is not busy, or START/timeout" poll, and one "wait until a directory open on this device succeeds" fs-settle. Rewrite the six entry points as thin calls to those two (or delete the ones whose callers can call the primitives directly — `waitSwapDone` is already a one-line forwarder). Keep the observed behaviours (silence = swapping, START skips) inside the two primitives, once.
- **Benefit:** The card-switch wait becomes auditable in one place; launch legs stop composing 3-4 waits by hand; removes an estimated third of this ~490-line region.
- **Effort:** L · **Risk:** Med (this code guards real, hardware-reported freezes; the consolidation must preserve the silence/START semantics exactly — structural judgement only, no hardware claim is made here) · **Confidence:** High — READ.

### W01-008 — HTTP catalog parsing pre-allocates for the maximum catalog and duplicate-checks in O(n²)
- **Category:** 4 size/memory (with 5 performance)
- **Locations:** `RiptOPL/src/sources/httpsupport.cpp:152-237` (`httpParseCatalog`); cap at `RiptOPL/include/httpsupport.h:19` (`HTTP_CATALOG_ROWS_MAX 2048`)
- **Problem:** Every catalog parse — including a 3-game home server — allocates both row arrays at the 2048-row cap up front (`malloc(sizeof(base_game_info_t) * HTTP_CATALOG_ROWS_MAX)` and the same for extras, lines 165-166) and only shrinks by freeing on error. INFERRED from the header field sizes (`include/supportbase.h:22-31`, `httpsupport.h:14-19`): roughly 0.9 MB for the pair at cap. Separately, each accepted row is duplicate-checked by a linear `strcmp` scan over all previously accepted rows (lines ~197-205), i.e. up to 2048×2047/2 ≈ 2.1 million comparisons at cap (derived arithmetically from the cap constant).
- **Fix:** Grow the two arrays as rows are accepted (the realloc-grow pattern already used in hddsupport.cpp's VCD list builder) instead of allocating the cap; the duplicate scan can stay — at realistic catalog sizes it is not the problem, and replacing it with a hash would be MORE, not less.
- **Benefit:** Memory use proportional to the actual catalog on a memory-constrained EE; removes the worst-case allocation from every refresh.
- **Effort:** S · **Risk:** Low · **Confidence:** High for the allocation and scan structure — READ; the ~0.9 MB figure is INFERRED from header field sizes, not a measured `sizeof`.

### W01-009 — Xerabora mode carries a hand-rolled JSON parser and maximum-size buffers for a paged list
- **Category:** 3 overengineering (with 4 size/memory)
- **Locations:** `RiptOPL/src/sources/achievements.cpp:137-150` (Xerabora block, `XERA_DOC_MAX = 512 * 1024`, `XERA_LIST_MAX = 1024`), `:182-350` (`jsonString`/`jsonSkip`/`jsonObject` and the member callbacks), `:352-445` (`achievementsParseXerabora` / `achievementsXeraboraPage`, `malloc(XERA_DOC_MAX)` at 427)
- **Problem:** This is the only JSON parser in the entire scope (census: `json` appears in no other `src/sources/` file) — ~170 lines of hand-written JSON tokenising maintained for one PC-side service's responses. Each fetch allocates a fixed 512 KiB document buffer and the parse allocates a fixed 1024-entry list, regardless of the actual set size, because the design parses the whole document into a cached list and serves pages from it.
- **Fix:** Parse the document streaming, page by page, the way the Caduceus path in the same file already consumes its TSV pages (`ACH_PAGE_SIZE` at a time), and delete the JSON object-walker plus the two fixed maximum allocations. If Xerabora mode itself is no longer used, the simpler fix is to delete the mode (lines 137-445 and its dispatch in `loadXerabora`) outright.
- **Benefit:** Removes the scope's only JSON parser and up to ~512 KiB + 1024 entries of per-fetch allocation; one RA list-consumption shape instead of two.
- **Effort:** M · **Risk:** Med (Xerabora page/filter behaviour must be preserved if the mode stays) · **Confidence:** High — READ.

### W01-010 — BDMA driver identity is a hand-maintained table of exact byte sizes that churns every driver rebuild
- **Category:** 7 build/repo clutter
- **Locations:** `RiptOPL/src/sources/vcdsupport.cpp:1699-1707` (`vcdBdmaPairSig`), used at `:1710-1716` (`vcdBdmaPairMatches`), `:1755-1765` (`vcdBdmaPairIsShipped`), and by the launch/equip validation at `:1768-1830`
- **Problem:** Whether the driver pair on a memory card / in a POPS folder is "this release's" is decided by comparing file sizes against seven hard-coded byte pairs. The table's own comment records three different historical sizes for the iLink driver alone (21609 → 27145 → 27769), i.e. every BDMAssault driver rebuild silently invalidates the table until someone hand-edits two numbers per affected mode — and until they do, launches re-equip (copy two modules onto the MC) or refuse a pair that is in fact current.
- **Fix:** Generate the table at build time from the actual shipped POPS/ driver files instead of maintaining it by hand in C++; the comparison logic stays exactly as is. (Deleting the size check entirely was considered and rejected here: the comments show a real stale-pair failure it guards against.)
- **Justification (fix adds a build step):** It replaces a recurring manual edit that has already been needed at least three times for one driver; no runtime code is added.
- **Benefit:** The signature can never drift from the drivers actually shipped; one recurring release-time edit disappears.
- **Effort:** M · **Risk:** Low · **Confidence:** High — READ.

### W01-011 — DESR/DVR support is a half-finished subsystem whose own header says it cannot claim to work
- **Category:** 8 half-finished features
- **Locations:** `RiptOPL/src/sources/hddsupport.cpp:52-310` (DVR state, driver bring-up, scan, publish, cleanup), `:1884` (scan called from `HddSource::update`), `:2470-2530` (`hddLaunchDvrIso`), `:2614` (dispatch from `HddSource::launch`), `:3247` (reset in `hddIopWasReset`)
- **Problem:** ~260 lines of scan/publish/launch machinery (plus hooks in update, launch, cleanup, shutdown, and IOP-reset) exist for PSX DESR DVR partitions, gated on a hardware capability bit and an enable flag, while the block comment at its head states the unresolved blocker verbatim: "TODO (DESR hardware gate): load DVRP modules after switching to PSX mode without destroying the GUI's other IOP clients… Do not claim general DESR boot compatibility before that initialization has been validated." On all non-DESR hardware the code is inert; on DESR hardware its core precondition is admittedly unvalidated, and its launches depend on an external Neutrino DVR build.
- **Fix:** Delete the DVR subsystem (scan, publish, launch leg, and its hooks) until the DVRP-initialisation question is settled and validated on DESR hardware; re-add it then as one finished piece. If it is in fact validated, the cheaper fix is to delete the stale TODO and say so — the current state (full machinery + "do not claim this works") is the worst option.
- **Benefit:** Removes ~260 lines and five hook points from the HDD backend that every HDD change must currently step around.
- **Effort:** M · **Risk:** Med (DESR users, if any, lose the read-only DVR list) · **Confidence:** High — READ (the half-finished status is the code's own comment, not an inference).

### W01-012 — A ~360-line asynchronous state machine exists to show a short disc ID in a caption
- **Category:** 3 overengineering
- **Locations:** `RiptOPL/src/sources/vcdsupport.cpp:262-620` (`VCD_ID_PROBE_BUDGET`/`VCD_ID_MEMO_MAX`/`VCD_ID_MAX_RETRIES` at 262-264, the `vcd_id_memo` linked list and `idMemoFind`/`noteScanDir`, `resolveRowId` 413, the one-slot DIntr/EIntr request queue `requestRowId`/`resolveQueuedDisplayId` 487-580, `rowIdCached` 585-620)
- **Problem:** To display `AAAA_NNN.NN` instead of a filename, the code maintains a 512-entry session memo with five states (UNREQUESTED/QUEUED/DEFERRED/RESOLVED/ABSENT), retry counters with frame-based backoff, a per-scan budget of 8 disc opens, a one-slot interrupt-guarded async request, and deferral rules based on whether art or BGM IO is busy — plus a canonicalisation step (`vcdCanonDisplayId`) so disc-read IDs render in the same shape as filename-parsed ones. The zero-IO filename parser (`vcdExtractGameId`) already exists in the same file and covers conventionally named libraries.
- **Fix:** Delete the disc-probing half: keep `vcdExtractGameId` filename parsing as the only display-ID source, and delete the memo, the async request slot, the retry/defer state machine, and `resolveRowId`'s device reads. Libraries whose filenames carry no ID then show the filename — the same fallback the code already uses when its budget runs out.
- **Benefit:** Removes ~360 lines, a linked-list allocation per scanned game, and all device IO from a cosmetic caption path.
- **Effort:** M · **Risk:** Med (a real, user-visible regression for badly named VCD libraries — the issue history in the comments shows at least one reporter with exactly that library; this is a deliberate trade the maintainer should make explicitly) · **Confidence:** High — READ.

### W01-013 — Boot-directory resolution is a 496-line file with two budget ladders and three transport tiers
- **Category:** 3 overengineering
- **Locations:** `RiptOPL/src/sources/bdmboot.cpp:254-471` (`BdmBoot::resolveWithBudget`), `:472-485` (`resolve` = 3000+10000+3000+8000 ms budgets; `resolveBootstrap` = 1500+5000+1500+3500 ms), `:118-250` (literal-slot resolver and identity reads)
- **Problem:** Finding the folder RiptOPL booted from takes a dedicated file with: a literal massN: resolver, a broader typed-alias resolver, a weak "fallback slot" held across the whole scan and consumed last, transport escalation tiers (silent loads first, then DEV9/ATA with spin-up waits), and two different budget ladders depending on whether the call is "full" or "bootstrap". The full ladder can spend 22 seconds of budgeted waiting (3000+10000+3000+8000 ms, from the call at 475-476) resolving a path that is, in the common case, simply argv[0]'s device.
- **Fix:** Resolve the literal slot named by the boot path, once, with one bounded budget; if that fails, fall back to the legacy discovery the code already retains, instead of escalating through every transport with per-tier budgets. Delete the second ladder and the fallback-slot mechanism.
- **Benefit:** Boot/config-load behaviour becomes explainable and testable; removes most of a 496-line file and a class of "boot hung for ~20 s on the splash" failure shapes (structural statement only — no hardware behaviour is claimed).
- **Effort:** L · **Risk:** Med (exotic boot layouts — typed aliases, bare `mass:` — lose their dedicated search and must use an explicit path) · **Confidence:** High — READ.

### W01-014 — The read-only-device CFG-folder helper is duplicated in BDM and ETH — and the copies already disagree
- **Category:** 2 duplication
- **Locations:** `RiptOPL/src/sources/bdmsupport.cpp:2045-2070` (inside `BdmSource::config`), `RiptOPL/src/sources/ethsupport.cpp:1520-1545` (`ethReadOnlyCfgDir`)
- **Problem:** Both build `"<config home>CFG/"`, keep a `static char madeCfgDir[256]` "already created" memo, strip the trailing slash, and `mkdir` once. They have already diverged: the ETH copy records success on `mkdir == 0 || errno == EEXIST` (ethsupport.cpp:1535), the BDM copy only on `mkdir == 0` (bdmsupport.cpp:~2063) — so on one backend a pre-existing folder created by something else is remembered, on the other it is retried on every selection. The ETH copy's comment even cites the BDM one as its model.
- **Fix:** One helper in supportbase.cpp next to `sbPopulateConfigIn` (which both already call with the resulting dir), with the EEXIST-accepting rule; delete both copies.
- **Justification (fix adds a shared helper):** Same logic in 2 places, already drifted; sharing removes code overall.
- **Benefit:** One mkdir/memo rule for read-only CFG homes; ~25 lines deleted.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ.

### W01-015 — UDPFS art lookup maintains an 8-spelling case-discovery subsystem for one folder name
- **Category:** 3 overengineering
- **Locations:** `RiptOPL/src/sources/udpfssupport.cpp:58-66` (`udpfsArtCaseNames[8]` = ART, ARt, ArT, Art, aRT, aRt, arT, art), `:460-580` (`udpfsArtFolderHasFiles`, `udpfsDiscoverArtFolder`), `:1204-1220` (`UdpfsSource::image` using the resolved index)
- **Problem:** Because a case-sensitive server distinguishes `ART` from `art`, the backend enumerates all 8 capitalisations, lists the root, opens candidates to see which are populated, arbitrates between an empty auto-created `ART` and a populated `art`, and invalidates the art-failure memo and art index when the answer lands — ~120 lines plus a per-session state flag, for the spelling of a three-letter folder. The same file already solves the identical problem for THM/LNG more simply (list the root, accept any case variant found, udpfssupport.cpp:380-460).
- **Fix:** Treat ART like THM/LNG in the same file: list the root once, take the first case-insensitive `ART` match that opens, and remember its spelling. Delete the 8-entry table, the populated-vs-empty arbitration, and `udpfsArtFolderHasFiles`.
- **Benefit:** One case-handling pattern in the file instead of two; ~80 lines removed; the pathological both-spellings-exist case degrades to "first match wins", as it already does for themes and languages.
- **Effort:** M · **Risk:** Low · **Confidence:** High — READ.

### W01-016 — All Games gathering walks every source's full list twice per rebuild
- **Category:** 5 performance (structural)
- **Locations:** `RiptOPL/src/sources/favsupport.cpp:1747-1762` (`FavSupport::gatherAllGames`), `:1621-1705` (`gatherPass`), `:1584-1586` (`kAllGamesModes`, 15 modes)
- **Problem:** `gatherAllGames` calls `gatherPass(NULL, 0, shelf)` to count, allocates, then calls `gatherPass(rows, cap, shelf)` to fill — so every rebuild performs the entire traversal twice: 15 modes × forced ISO and PS1 views × per-row `name()`/`favResolveStoredId` calls, including the ETH resolver path. The traversal is pure in-memory work over already-loaded lists, but it runs on the IO worker during a menu rebuild, doubled for no benefit beyond knowing the count first.
- **Fix:** Single pass into a realloc-grown array (the grow pattern already used in hddsupport.cpp's list builder), then publish. Delete the counting pass.
- **Benefit:** Halves the All Games rebuild work; ~5 lines net removed and one fewer full traversal of every source list.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ.

### W01-017 — Cheat loading stacks four fallback attempts per launch
- **Category:** 3 overengineering (fallback stacking)
- **Locations:** `RiptOPL/src/sources/supportbase.cpp:1741-1845` (`sbLoadCheats`); tar probe at 1755-1790, loose-file fallback after it, case retries described and implemented at 1796-1845
- **Problem:** One launch's cheat lookup tries, in order: a member of `CHT/cht.tar`, the loose `CHT/<id>.cht`, the same name in lowercase, and the same name in UPPERCASE — each attempt is a device open (and the tar attempt is an archive open + member scan) on whatever slow transport hosts the game, on the launch path, for a feature most games do not use (no `.cht` at all is, by the code's own comment at 1678, "the expected case"). Every attempt also has its own logging and its own "found but broken vs absent" distinction that the next attempt must not shadow.
- **Fix:** Keep the tar (it is the documented bulk format) and one loose-file lookup using the exact stored startup spelling; delete the two case-variant retries and tell users the file must match the game ID's case, as the ID itself is canonical uppercase per the comment at 1766.
- **Benefit:** Up to three fewer device round-trips on every cheat-enabled launch and a materially simpler absence/broken distinction; ~40 lines removed.
- **Effort:** S · **Risk:** Low (a user with a mis-cased loose `.cht` and no tar loses cheats until they rename the file) · **Confidence:** High — READ.

### W01-018 — `.bak` staging files can permanently block later writes and are never cleaned up
- **Category:** 6 bugs/security (robustness), with 8
- **Locations:** `RiptOPL/src/sources/vmcrebuild.cpp:9` (design comment), `:124` (`.new`/`.bak` siblings created), `:173-200` (rebuild completion); `RiptOPL/src/sources/vcdsupport.cpp:2206-2208` (`vcdInstallPopsUdpfsNet` refuses with -3 if a `.bak` exists), `:2269-2360` (`vcdWritePopsUdpfsNet` backup/rollback machinery)
- **Problem:** Two subsystems leave backup siblings behind as a permanent state. vmcrebuild's header states the backup is never deleted ("Nothing here ever deletes the card or its backup"), so every rebuilt VMC leaves a full-size `.bak` card image on the device forever. Worse, the POPSTARTER UDPFS network-config writer treats the mere existence of `<file>.bak` as "an interrupted editor save needs recovery" and returns -3 — so one interrupted write makes all future automatic config installs fail until a human deletes a file they have never heard of, on a memory card, from outside RiptOPL.
- **Fix:** For vmcrebuild: delete the `.bak` once the rebuilt card has been verified and swapped in (keep it only on the failure path). For the UDPFS net config: delete the whole backup/rollback layer — write each small config with the existing `vcdSafeWriteFile` + read-back verify (`vcdWritePopsUdpfsFile` already does exactly this) and drop the `.bak`-existence veto.
- **Benefit:** Rebuilt VMCs stop leaking a card-sized file per rebuild; network config writes can no longer be permanently wedged by a leftover backup; ~60 lines of rollback code removed.
- **Effort:** M · **Risk:** Med (the `.bak` is the recovery story for a genuinely interrupted write; the read-back verify remains) · **Confidence:** High — READ.

### W01-019 — Dead and no-op code: placeholder flag ORs, commented-out launch/teardown blocks, a commented-out size calculation
- **Category:** 1 dead code
- **Locations:** `RiptOPL/src/sources/bdmlaunch.cpp:983` (`settings->common.fakemodule_flags |= 0 /* TODO! fake ilinkman ? */;`) and `:986-987` (MX4SIO branch `|= 0;`), `RiptOPL/src/sources/mmcesupport.cpp:1740-1747` (commented-out `/* No autolaunch yet else { miniDeinit… } */` block), `RiptOPL/src/sources/bdmsupport.cpp:2156-2157` and `RiptOPL/src/sources/mmcesupport.cpp:1801-1802` (commented-out `if ((exception & UNMOUNT_EXCEPTION) == 0) …` stubs in both cleanUps), `RiptOPL/src/sources/mmcesupport.cpp:1819` (commented-out STOP_ALL devctl in shutdown, under a comment describing it as required), `RiptOPL/src/sources/supportbase.cpp:650-668` (TODO + commented-out UL size-calculation loop)
- **Problem:** Statements that do nothing (`|= 0`), an unresolved TODO sitting in a launch dispatch, and four blocks of commented-out code — two of them in teardown paths where a reader cannot tell whether the commented behaviour is missing by accident or by decision. The mmcesupport shutdown case is the sharpest: the comment says the STOP UNIT command is "required by some HDDs", the line that would do it is commented out, and the BDM backend implements the same thing live (bdmsupport.cpp shutdown, gated on `gDeinitTerminal`).
- **Fix:** Delete all of it. For the MMCE STOP_ALL line, make the decision explicit in the commit that removes it (either wire it like BDM's, gated the same way, or record in one line why MMCE must not send it) — do not leave it as a comment.
- **Benefit:** Launch dispatch and teardown read as decided code; ~35 lines removed; one latent "is this a bug?" question closed.
- **Effort:** S · **Risk:** Low · **Confidence:** High — READ.

### W01-020 — Favourites permanently carry a foreign-format import parser for other loaders' `favourites.bin`
- **Category:** 8 redundant features
- **Locations:** `RiptOPL/src/sources/favsupport.cpp:143-165` (`favMapWoplMode` mode-translation table), `:167-230` (`favReadWoplFile`), `:240-270` (import branch inside `favParseImage`)
- **Problem:** Because favourites.bin lives in a shared OPL config directory, RiptOPL permanently ships a read-only importer for uOPL/wOPL's header-less raw-struct format — including a mode-number translation table for a foreign enum, salvage/malformed rules, and a "recognised but not editable" state that the rest of the store must honour. This is migration code with no retirement condition: it runs on every load whose header is not OFAV (including a merely corrupt RiptOPL file, which then gets interpreted as a foreign list), forever.
- **Fix:** Make the import a one-time conversion: when a foreign file is imported and the store is next saved, it is already written as OFAV — so add the missing half: after a successful import, immediately rewrite the file in OFAV format (when the directory is writable) and delete the foreign parser once that conversion path has shipped for a release. Short of that, gate the import behind one explicit "import favourites from another loader" action instead of the every-load fallback.
- **Benefit:** Removes ~90 lines of foreign-format parsing and one ambiguous state (corrupt-native vs foreign) from every favourites load; the shared-directory behaviour users rely on is preserved by the conversion.
- **Effort:** M · **Risk:** Med (a user who actively shares one favourites.bin between RiptOPL and uOPL/wOPL in both directions would lose the return leg — the file already becomes OFAV on any RiptOPL save today, so that workflow is already one-way in practice) · **Confidence:** High — READ; the "already one-way in practice" clause is INFERRED from `favWriteFile` always stamping the OFAV format (favsupport.cpp:425-545).

---

## COVERAGE

All 31 files in scope were opened and read in full (paged reads where the reader capped output). Line counts are the `wc -l` values measured in this session; total 31,201.

| File | Lines | Read |
|---|---|---|
| achievements.cpp | 797 | yes, full |
| appscan.cpp | 248 | yes, full |
| appsupport.cpp | 1444 | yes, full |
| bdmboot.cpp | 496 | yes, full |
| bdmdevices.cpp | 582 | yes, full |
| bdmlaunch.cpp | 999 | yes, full (incl. 956-end) |
| bdmsupport.cpp | 2408 | yes, full (incl. 1249-end, 2255-end) |
| cuesupport.cpp | 1288 | yes, full |
| discsupport.cpp | 183 | yes, full |
| ethsupport.cpp | 1664 | yes, full (incl. 1260-end) |
| favsupport.cpp | 1833 | yes, full (incl. 1273-end) |
| folderbrowse.cpp | 130 | yes, full |
| gamemanage.cpp | 347 | yes, full |
| gamesource.cpp | 67 | yes, full |
| hddsupport.cpp | 3383 | yes, full (incl. 1176-end, 2330-end) |
| httpsupport.cpp | 924 | yes, full |
| mmcesupport.cpp | 1855 | yes, full (incl. 1003-end) |
| netsupport.cpp | 501 | yes, full |
| nettime.cpp | 158 | yes, full |
| rabadge.cpp | 220 | yes, full |
| rahash.cpp | 971 | yes, full |
| rahunt.cpp | 213 | yes, full |
| ranet.cpp | 1136 | yes, full |
| rapopslaunch.cpp | 129 | yes, full |
| ratls_ps2.cpp | 304 | yes, full |
| rawatch.cpp | 326 | yes, full |
| retrogem.cpp | 675 | yes, full |
| supportbase.cpp | 3181 | yes, full (3 chunks) |
| udpfssupport.cpp | 1280 | yes, full (incl. 1152-end) |
| vcdsupport.cpp | 3259 | yes, full (incl. 1201-end, 2437-end) |
| vmcrebuild.cpp | 200 | yes, full |

**Files in scope NOT read: none.**

Notes:
- `src/sources/` contains no headers; the 31 files above are the complete directory listing. A small number of `include/` headers (`supportbase.h`, `favsupport.h`, `httpsupport.h`, `vcdsupport.h`, `opl.h`) were consulted via grep only for struct field sizes and cap constants cited in W01-008/W01-009; no findings are filed against them.
- Deliberately not filed, after verification: the remaining `strcpy`/`sprintf` sites in scope (30 + 13 by census) were each checked in context and are length-guarded or provably bounded by fixed-size source fields (e.g. `strcpy(filename, game->startup)` into `char[32]` from a 13-byte field; the guarded `fullpath` copies in supportbase.cpp:396/423; `bdmFindPartition`'s `sprintf(target, …)` at bdmsupport.cpp:2371-2382, whose target is a documented 64-byte caller buffer and whose inputs are bounded) — no unbounded-copy finding is claimed. The favourites store's staged `.new` write (favsupport.cpp) was likewise checked and is cleaned up on success, so it is excluded from W01-018.
- No secret-like values were encountered or are reported. No licence findings (settled per instructions). Nothing in this section is based on the prior audit, which was not read, listed, or opened.
