# Verification — RE-RIPTOPL-199 through RE-RIPTOPL-231

- Subject report: `~/workspace/Sable-audit-redo/Redo-RiptOPL.md`
- Clone: `~/workspace/audit-clones-2026-11-13/RiptOPL`, HEAD verified `2e347d5ac885cd0ff73e9ad4143781946396f492` (matches pin), `git status --porcelain` empty after work (read-only).
- Method: refute-first; every cited file/line opened, mechanisms re-derived, guards searched, duplicate overlap checked against same-file/same-subsystem findings elsewhere in the report (notably RE-RIPTOPL-159 FULL_LWIP vs 199/211, RE-RIPTOPL-194 vs 206, RE-RIPTOPL-218/219 vs 203 — all distinct mechanisms, no duplicates found in this range).

## Verdict table

| ID | Verdict | Evidence (file:line) |
|---|---|---|
| RE-RIPTOPL-199 | VERIFIED | `modules/network/SMSTCPIP/exports.tab:17-24,30` stubs; `ps2ip.c:268-271` empty `ps2ip_Stub`; real impls gated `#ifdef FULL_LWIP` (`ps2ip.c:97`, `sockets.c:630,1377`); `ps2ips.c:468-575` handlers dispatch to them |
| RE-RIPTOPL-200 | VERIFIED-DRIFT | `src/sources/hddsupport.cpp:59-62` TODO verbatim; machinery is ~295 lines, not ~260 (see reasoning) |
| RE-RIPTOPL-201 | VERIFIED | `modules/mmce/mmceman/src/mmce_fs.c:402-405` returns 0 unconditionally; registered `:1194`; sibling slots use `NOT_SUPPORTED_OP` (`:15-17` returns `-ENOTSUP`) |
| RE-RIPTOPL-202 | VERIFIED | `modules/network/SMSTCPIP/sockets.c:586-589` accepts SOCK_RAW; `LWIP_RAW` defined nowhere in tree (incl. `include/lwipopts.h`); no `raw.c`; `api_msg.c:297ff` RAW cases compiled out, `err` preset `ERR_OK`; `memp.c:75,89-91` + `opt.h:111-113` reserve 4 RAW PCBs; `raw.h` 75 lines, no implementation |
| RE-RIPTOPL-203 | VERIFIED-DRIFT | `src/core/config.cpp:1419-1495` five candidate locations exist, but the rung order/type split differs from the finding (see reasoning) |
| RE-RIPTOPL-204 | VERIFIED | `src/sources/favsupport.cpp:143-165` mode table, `:167-230` `favReadWoplFile`, `:240-270` import branch on any non-OFAV header; `favWriteFile` stamps OFAV |
| RE-RIPTOPL-205 | VERIFIED-DRIFT | `include/launchdiag.h:41` `#define LAUNCH_DIAG 0`; gated-site count and consumer list are off (see reasoning) |
| RE-RIPTOPL-206 | VERIFIED-DRIFT | `modules/network/httpclient/httpclient.c:130-133` unused enum; the Transfer-Encoding branch at `:160-165` is commented out, not live (see reasoning) |
| RE-RIPTOPL-207 | VERIFIED | `modules/hdd/xhdd/hdpro.c:8-11` stub returns 0; `xhdd.c:43-48` propagates it when `isHDPro`; `xhdd.h:2,4` prototypes have no definition in `modules/hdd/xhdd` (the same-named definition is in `modules/iopcore/cdvdman/hdpro_atad.c:742`) |
| RE-RIPTOPL-208 | VERIFIED | `modules/usb/usbd-ra/include/usbd.h:294-296` declarations + `:336-337` import slots 17/18 with "these aren't implemented" comment; `src/exports.tab` ends at slot 16 |
| RE-RIPTOPL-209 | VERIFIED | `modules/mmce/mmceman/src/mmce_sio2.c:278,381` honour `mmce_sio2_use_alarm`; `:211` (`tx_rx_pio`) and `:492,533,570` (`tx_mixed`) call `SetAlarm` unconditionally; setting at `mmce_fs.c:1157-1160` |
| RE-RIPTOPL-210 | VERIFIED | `third_party/PSUManager/README.md:12-16` claim; validator `.github/scripts/verify_psu_with_psumanager.cpp` exists but no workflow/runner references it (`tools/run_tests.sh` runs only `test_*.py`, HTTP tests, `tests/host/run.sh` — none mention PSU); vendored tests wired only under `BUILD_TESTING` in `src/core/CMakeLists.txt:9-13`; live validation is `inspect_psu` in `package_release_app.py:177` |
| RE-RIPTOPL-211 | VERIFIED | `modules/network/SMSTCPIP/ps2ip.c:273-278` `ps2ip_ShutDown` is only `return 1;`; export slot `exports.tab:4` |
| RE-RIPTOPL-212 | VERIFIED | `src/sources/supportbase.cpp:1969-2600` resolver family (632 lines); `sbResolveCustomLoaderPath` 2235-2488 = 254 lines; migrated/MC probes at 2489/2517/2539 |
| RE-RIPTOPL-213 | VERIFIED-DRIFT | `src/sources/bdmboot.cpp:254-471,472-485` two ladders exist as cited, but the full ladder sums to 24 s, not 22 s (see reasoning) |
| RE-RIPTOPL-214 | VERIFIED | `src/sources/vcdsupport.cpp:262-264` budget/memo/retry constants; memo list `:274-360`; `resolveRowId:413`; queue `requestRowId:536`/`resolveQueuedDisplayId:504`; `rowIdCached:593-620`; filename parser `vcdExtractGameId:61` |
| RE-RIPTOPL-215 | VERIFIED | `src/sources/mmcesupport.cpp:146` `sendGameID` (own poll loop), `:314` `waitCardReady`, `:373` `waitSwapDoneOn`, `:417` `waitSwapDone` (one-line forwarder), `:434` `waitBeforeHandoff`, `:451` `waitHistorySwitch`, `:500` `gameIdSettle`, `:605` `settleAfterSwitch`; composed chains at `:1412-1434,1658-1729` |
| RE-RIPTOPL-216 | VERIFIED | `src/gfx/themeviews.cpp:416,432,453` synth family, `THM_SYNTH_MAX_SLOTS 64` at `:376`; consumed `src/gfx/themes.cpp:1478-1491`; `thmViewChoose:168` already falls back to `defaultView` |
| RE-RIPTOPL-217 | VERIFIED | `src/platform/sysneutrino.cpp:303` `sysTomlTornTailCut`, `:382` UDPFS sync using `strstr(toml, "\"ip=")` at `:429`, `:522` lexer rewriter for SMB; restore-on-short-write at `:455-458` and `:742` |
| RE-RIPTOPL-218 | VERIFIED | `src/app/settingsio.cpp:743,853,938` load-side recovery cascade; `:2047` separate save-side cascade with different device order (boot → HDD → BDM → MMCE, then MC → MMCE → BDM → HDD) |
| RE-RIPTOPL-219 | VERIFIED | `src/core/config.cpp:1496-1699` `configWrite`: RAM snapshot (cap `:1496`, alloc `:1558`), MC single-open carve-out (`:1547ff`), read-back `memcmp` verify/rescue (`:1647`) |
| RE-RIPTOPL-220 | VERIFIED | `src/app/host.cpp` 292 lines; sole implementations `OplUi:26`, `OplApp:74`, `OplLibrary:98`, `OplLaunch:115`; interfaces only in `include/host.h:27,60,87,104`; bodies are one-line forwards |
| RE-RIPTOPL-221 | VERIFIED | `src/sources/achievements.cpp:144-145` `XERA_DOC_MAX`/`XERA_LIST_MAX`; JSON walker `:182-350`; parse/page `:352-445`; `malloc(XERA_DOC_MAX)` at `:427`; no other `src/sources/` file contains a JSON parser |
| RE-RIPTOPL-222 | VERIFIED | `src/sources/udpfssupport.cpp:62-63` 8-spelling table; `:459,492` `udpfsArtFolderHasFiles`/`udpfsDiscoverArtFolder`; `:1209` resolved index used in `image`; THM/LNG solved by `strcasecmp` root listing at `:382,419` |
| RE-RIPTOPL-223 | VERIFIED-DRIFT | `src/sources/supportbase.cpp:1741-1845` four attempts exist, but the case variation is extension-only in both tar and loose paths, not filename re-casing (see reasoning) |
| RE-RIPTOPL-224 | VERIFIED | `src/ui/libview.cpp` 365 lines; `retainedView:22`, `mixedView`+`mixedViewInitialized:31-32`, `pendingView`/`pendingViewValid`/`pendingViewUsesMixedRing:34-36`, `bdmSlotType:37` |
| RE-RIPTOPL-225 | VERIFIED-DRIFT | Wrapper blocks exist at all cited files, but `gui.cpp` holds 22 wrappers in the cited range, not 25 (see reasoning) |
| RE-RIPTOPL-226 | VERIFIED | `modules/pccf/pcdiag_cf.c:16-71`: pass/fail decided by candidate + COR checks before the loop; loop is 3 samples × 2 spaces × (10+5) reads with 500 ms + 2×100 ms waits feeding only `trace()`; production caller `pccf_hw.c:283` passes `quiet_trace` (`:56-59`), which discards everything |
| RE-RIPTOPL-227 | VERIFIED | `src/gfx/grid.cpp:504-510` count/index walk per draw; `src/gfx/psbbnflow.cpp:252-256` countRows walk; `src/ui/menusys.cpp:2584,2624,2660` `menuGridRow`/`menuGridPage`/`menuGridAtRowStart` each re-walk `submenu` |
| RE-RIPTOPL-228 | WEAKENED | `src/core/cheatconfig.cpp:99-104` 250 `configRemoveKey` calls (MAX_CODES=250, `include/cheatman.h:40`) — but save writes picks contiguously, so the claimed round-trip loss does not occur (see reasoning) |
| RE-RIPTOPL-229 | VERIFIED | `src/core/filemgr.cpp:225-250` `fmChildren` re-runs `fmList` from scratch on each ×4 growth to cap 65536; `fm_entry_t` is 144 bytes (`include/filemgr.h:10-15`: `name[128]`+`int`+`unsigned long long`) → 65536 × 144 = 9,437,184 B ≈ 9 MB as claimed |
| RE-RIPTOPL-230 | VERIFIED-DRIFT | `src/sources/favsupport.cpp:1747-1762` double `gatherPass` (count then fill) confirmed, but `kAllGamesModes` has 14 modes, not 15 (see reasoning) |
| RE-RIPTOPL-231 | VERIFIED-DRIFT | `modules/iopcore/cdvdman/cdvdman.c:982-998` retry wrapper (2500 × `DelayThread(2000)`, unconditional `return 1`) confirmed, but `cdvdman_writeSCmd` contains four unbounded register polls, not three (see reasoning) |

## Reasoning for non-VERIFIED verdicts

### RE-RIPTOPL-200 — VERIFIED-DRIFT
Mechanism and citations hold exactly: the TODO at `hddsupport.cpp:59-62` is verbatim, scan is called from `HddSource::update` (`:1884`), launch dispatches at `:2614`, reset at `:3247`, all gated on `gEnableDVR` + `SPD_CAPS_DVR` (`:82-100`). Figure correction: the "~260 lines" counts only the 52-310 block (259 lines). The launch leg `hddLaunchDvrIso` is a further ~35 lines (`:2470-2504`), plus publish/cleanup helpers and five hook points, so the subsystem the fix would delete is ~295+ lines. The finding understates its own case; the Benefit line ("removes ~260 lines") should read ~295.

### RE-RIPTOPL-203 — VERIFIED-DRIFT
Five candidate locations exist, but not in the stated order for one set, and not all for every set. In `configRead` (`config.cpp:1435-1490`) the actual sequence is: (1) current filename, (2) wOPL filename, (3) legacy filename in the same directory — OPL sets only, (4) carry-over directory with current name, then legacy name — OPL sets only. The carry-over-with-current-name rung the finding lists third exists separately for non-OPL global sets (guarded `type() != CONFIG_OPL`, third position for those sets) and is never taken by OPL sets. Corrected statement: an OPL config set can be read from five locations in the order current → wOPL → legacy → carry-over-current → carry-over-legacy. The redundancy claim and fix stand.

### RE-RIPTOPL-205 — VERIFIED-DRIFT
Core claim holds: `LAUNCH_DIAG` is a literal `0` at `include/launchdiag.h:41`, not a build flag, and with it 0 every call compiles to an inline no-op (header `:73-89`). Two figure errors: (a) "3 use sites outside the header" — there are exactly two `#if LAUNCH_DIAG` sites, `elfldr/loader.c:151` and `src/platform/launchdiag.cpp:5`; (b) the consumer list (loader.c + launchdiag.cpp only) badly understates reach — the header is included by ~10 files with live call sites in `src/app/opl.cpp:1301-1432`, `src/platform/elfldr_noreset.cpp:140-244`, `src/sources/bdmlaunch.cpp:394-474`, `src/platform/sysneutrino.cpp:1393`, etc. The finding is weaker than reality, not wrong in direction.

### RE-RIPTOPL-206 — VERIFIED-DRIFT
No chunked decoding exists and bodies are read by `Content-Length` only (`httpclient.c:231-244`) — mechanism holds, and the file's own header comment (`:2`) admits it. But the finding presents the Transfer-Encoding handling at `:160` as live parser code: lines 160-165 sit inside a `/* … */` comment block, and the `TransferEncoding` variable itself is commented out (`:138` `// static char TransferEncoding;`). The only live residue is the unused `enum TRANFER_ENCODING` at `:130-133`. Corrected fix emphasis: delete the enum and the commented-out branch; the "fail explicitly on chunked" half is unaffected (a chunked response currently just yields `ContentLength = -1` handling, never a TE check).

### RE-RIPTOPL-213 — VERIFIED-DRIFT
Structure holds exactly: 496-line file, `resolveWithBudget:254-471`, literal-slot resolver `:118-250`, fallback slot held and consumed last (`:375-408,449-460`), two ladders at `:472-485`. Arithmetic error: the full ladder's own numbers sum to 3000+10000+3000+8000 = **24,000 ms (24 s)**, not the "22 seconds" stated twice. (Structurally the budgets are per-tier escalations inside the scan — `budgetMs` assigned at `:361`, `+= mx4sioExtraBudgetMs` at `:434`, `+= expensiveExtraBudgetMs` at `:446` — so 24 s is the ladder total as the finding frames it, not a guaranteed single-call wait.)

### RE-RIPTOPL-223 — VERIFIED-DRIFT
Four attempts per launch exist, but the finding mis-describes what varies. The startup ID is never re-cased; only the extension is, in **both** paths: the tar probe tries `<file>.cht` then `<file>.CHT` (`supportbase.cpp:1766-1772`, inside the cited 1755-1790 range), and the loose path loops over `chtExt[] = {"cht", "CHT"}` (`:1801-1807`). So the stack is tar×2 + loose×2, not "tar, loose exact, lowercase, UPPERCASE" as four distinct filename spellings. The fix ("delete the two case-variant retries") is actually correct as written once read as deleting both `.CHT` retries; the Problem text's attempt enumeration should be corrected.

### RE-RIPTOPL-225 — VERIFIED-DRIFT
The wrapper pattern is real at every cited site (`guiscreens.cpp:99-109`, `guinotify.cpp:205-218`, `guisplash.cpp:245-266`, `cfgtitle.cpp:269-274` — six one-liners, `artindex.cpp:26-44`). Count correction for the headline file: `gui.cpp:471-492` contains **22** forwarding wrappers (`guiInit`…`guiUpdateScreenScale`), not 25. No other claim in the finding depends on the count.

### RE-RIPTOPL-228 — WEAKENED
Save half verified: `cheatConfigSaveSelections` (`cheatconfig.cpp:99-104`) loops all `MAX_CODES` = 250 slots (`include/cheatman.h:40`) calling `configRemoveKey` per slot. Load half is real code — `cheatConfigLoadSelections` breaks at the first missing `$CheatSelNNN` (`:79-82`) — but the finding's causal claim fails: the save side does **not** produce a sparse set. After the removals it rewrites picks with its own contiguous counter (`:105-111`, `n++` per enabled pick, keys `%03d` from 000), so any file this code writes is gap-free and round-trips correctly. No other code in the tree removes individual `$CheatSel` keys (grep over `src/`+`include/` finds the prefix only in `cheatconfig.cpp` and `include/config.h:83`). True scope: the 250-walk save cost stands; the load drop-after-gap is a latent fragility reachable only via a hand-edited or foreign-written config file, not via the save/load round-trip the finding claims is broken.

### RE-RIPTOPL-230 — VERIFIED-DRIFT
Double traversal verified verbatim: `gatherAllGames` (`favsupport.cpp:1749-1755`) calls `gatherPass(NULL, 0, shelf)` to count, `calloc`s, then `gatherPass(rows, cap, shelf)` to fill. Count correction: `kAllGamesModes` (`:1584-1585`) lists **14** modes (HDD, BDM, BDM1-BDM7, MMCE, ETH, UDPFS, HTTP, APP), not 15. The doubling claim and fix are unaffected.

### RE-RIPTOPL-231 — VERIFIED-DRIFT
Wrapper claims verified exactly: `cdvdman_sendSCmd` (`cdvdman.c:982-998`) retries while `r == 0` with `DelayThread(2000)` and `++retryCount <= 2500` (~5 s), then falls through to unconditional `return 1`. Count correction: `cdvdman_writeSCmd` (`:926-979`) contains **four** unbounded, delay-free register polls, not three — the entry drain `do { (void)CDVDreg_SDATAOUT; } while (!(CDVDreg_SDATAIN & 0x40));` (`:939-943`), the cited `while (CDVDreg_SDATAIN & 0x80);` (`:954-956`), the output-read do-while (`:961-968`), and the flush do-while (`:971-975`) — all while holding `cdvdman_scmdsema` (taken `:931`, released `:976`). The finding understates the spin count.

## Candidates (new defects noticed while verifying — not merged into verdicts)

- **CAND-1 — `mmce_fs_ioctl2` has the same silent-success defect as RE-RIPTOPL-201, in the adjacent op slot.** `modules/mmce/mmceman/src/mmce_fs.c:1169-1183`: `res` initialises to 0, the `default:` case is empty, and every unknown `cmd` returns 0 (success) — only `MMCE_CMD_IOCTL_GET_FD` is handled. Registered as the `ioctl2` slot at `:1213`. RE-RIPTOPL-201 cites only the `ioctl` stub (`:402-405`, slot `:1194`), so this is a separate, uncovered instance of the same mechanism; the 201 fix should be extended to it or it should be filed separately.

## Tally

- VERIFIED: 23 (199, 201, 202, 204, 207, 208, 209, 210, 211, 212, 214, 215, 216, 217, 218, 219, 220, 221, 222, 224, 226, 227, 229)
- VERIFIED-DRIFT: 9 (200, 203, 205, 206, 213, 223, 225, 230, 231)
- WEAKENED: 1 (228)
- REFUTED: 0
- BLOCKED-ENV: 0
- Total: 33
