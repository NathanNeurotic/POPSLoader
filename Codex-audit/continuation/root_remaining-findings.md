# Codex continuation findings — root-owned scope

## POPSLOADER-100 / Reuse one existing 7-Zip listing parser / Categories 2, 6

- **Location(s):** POPSLoader/.research/tools/audit_hosted_patch_members.py:20-42,67; POPSLoader/.research/tools/audit_legacy_archive_payloads.py:81-107; POPSLoader/.research/tools/audit_legacy_tool_overlap.py:39-63; POPSLoader/.research/tools/compare_recovered_archive_candidates.py:47-66.
- **Problem:** Four preservation tools independently parse the same `7z l -slt` records and infer omitted directory markers. Their copies have drifted: the hosted-patch census replaces two consecutive backslashes instead of a single separator in its directory test, whereas the other implementations normalize single separators.
- **Fix:** Reuse one of the existing listing functions in these sibling tools, normalize separators and strip trailing directory separators there, and keep each caller's existing size/member policy outside the shared parsing loop. Delete the duplicate parsing bodies; no additional module or parser abstraction is needed.
- **Justification:** Four copies of the same parsing/filtering logic are directly present, and reuse removes more code than the import/adaptation costs. The concrete normalization mismatch is fixed at the same time.
- **Benefit:** Approximately 40–70 net source lines removable (INFERRED until implemented); one consistent file census. This is desktop documentation tooling, with no PS2 ELF/RAM saving claimed.
- **Effort:** M. **Risk:** Low. **Confidence:** High (READ for duplication/mismatched literal; Windows-style-listing consequence INFERRED, not exercised).

## POPSLOADER-101 / Delete the unused archive hash reverse map / Category 1

- **Location(s):** POPSLoader/.research/tools/audit_legacy_tool_overlap.py:143-169, especially148.
- **Problem:** `matches_by_hash` is populated from the original payload digests but never read. Actual comparisons iterate `originals` and use its digests directly.
- **Fix:** Delete the unused dictionary assignment.
- **Benefit:** One line and one three-entry dictionary construction removed; tiny desktop-only saving, not benchmarked.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; complete file and reference search).

## POPSLOADER-102 / Reuse file contents and indexes already loaded by the audit tools / Categories 2, 5

- **Location(s):** POPSLoader/.research/audit_site.py:26-30,148-164; POPSLoader/tools/host_harness.py:23-24,1776,1815,1949-1950,1982-1983,2017-2020,2137-2138,2180,2217-2221,2241,2282,2412-2414.
- **Problem:** The site audit populates `ANCHORS`, then reopens those same pages for each of 136 catalogue entries. The host harness similarly retains `UI_SRC`/`SYS_SRC` but rereads them another six/nine times, also rereading already retained native source text.
- **Fix:** Use the existing normalized-path anchor set in the site audit. Use `UI_SRC`/`SYS_SRC` throughout the harness and reuse its already loaded native source variables at subsequent checks; delete the redundant file reads and aliases.
- **Benefit:** Up to 136 repeated generated-page reads/string scans per site audit removed. Harness source-size arithmetic gives 7,575,679 bytes of redundant source reads/decodes removable per run, including fifteen repeated Lua reads and three native-source reads. This is desktop-only; host timing/RSS savings unmeasured. No new cache or helper needed.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; catalogue count parsed).

## POPSLOADER-103 / Consider deleting the documentation cursor animation / Categories 3, 5, 8

- **Location(s):** POPSLoader/.research/_srcassets/app.js:149-502; POPSLoader/.research/_srcassets/style.css:1274-1283,1360-1371,1379; POPSLoader/.research/build_site.py:291.
- **Problem:** The documentation site carries a full-screen canvas renderer, particle/history state, duplicated mouse listeners and a persistent preference API solely for decorative cursor orbs. On ordinary desktop visits it starts an animation-frame loop that continues while the page is idle.
- **Fix:** If the ornament is expendable, delete its two JavaScript sections, canvas markup and orb-specific CSS. Retain the independent mobile header layout rules.
- **Benefit:** 354 JavaScript lines / 12,052 uncompressed source bytes removable, plus the canvas and related CSS; avoids that animation loop and canvas allocation. Browser CPU/RAM and compressed transfer savings unmeasured; no PS2 ELF saving. This is an optional presentation tradeoff, not a correctness defect.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; source byte count measured, performance benefit INFERRED).

## POPSLOADER-104 / Stop interpreting filename prefixes as hexadecimal sort keys / Category 6

- **Location(s):** POPSLoader/.research/_srcassets/app.js:96-108; POPSLoader/.research/build_site.py:871-873,918-920.
- **Problem:** Every sortable column uses `parseInt(...,16)`, which accepts an initial hexadecimal prefix of ordinary names. The actual comparator puts `BATCHER` after `CUE2POPS` (186 versus 12) despite ascending text order; historical-name and historic-filename columns both use this handler.
- **Fix:** Only perform numeric conversion when each entire value is a recognized numeric/hexadecimal literal; compare ordinary text directly. Keep the existing handler and avoid new table configuration.
- **Justification:** One bounded whole-value test fixes the demonstrated sort error without introducing a parser or another sorting layer.
- **Benefit:** Correct filename sorting; negligible code/size impact and no PS2 runtime effect.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; actual JavaScript comparator exercised under host Node).

## POPSLOADER-105 / Remove snippet highlighting that corrupts escaped text / Categories 3, 6

- **Location(s):** POPSLoader/.research/_srcassets/app.js:17,37-50,63-66.
- **Problem:** Search highlighting runs regular expressions over already escaped HTML, including its entities and markup inserted for earlier terms. For text `A&B`, searching `&` returns `A<mark>&</mark>amp;B`, and searching `amp` marks the encoding rather than source text.
- **Fix:** Delete the highlighting replacement loop and return the existing escaped snippet. Search scoring and the snippet's selected context remain available.
- **Benefit:** Five loop/body lines removed; correct escaped snippet text and fewer regular-expression passes per result. Small documentation-only presentation tradeoff; timing unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; actual snippet function exercised under host Node).

## POPSLOADER-106 / Hoist title normalization out of the search-term loop / Category 5

- **Location(s):** POPSLoader/.research/_srcassets/app.js:19-34,53-60.
- **Problem:** Each candidate title is lowercased again for every query term even though it is unchanged during scoring.
- **Fix:** Move the existing title-lowercasing assignment immediately before the term loop.
- **Benefit:** One title conversion per candidate rather than one per term; tiny browser-only CPU/allocation saving, unmeasured. No added lines or persistent state required.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## POPSLOADER-107 / Delete the overwritten duplicate slug function / Categories 1, 2

- **Location(s):** POPSLoader/.research/build_site.py:90-92,101-104.
- **Problem:** `SLUG_RE` and the identical `slug` function are defined twice, with no call between the definitions. The second definition replaces the first.
- **Fix:** Delete the second regex assignment/function definition and retain the earlier implementation.
- **Benefit:** Three redundant source lines and one redundant regex/function setup removed; negligible desktop build-time benefit.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## POPSLOADER-108 / Render the thread study once during its build / Categories 2, 5

- **Location(s):** POPSLoader/.research/build_site.py:1984-2002.
- **Problem:** The same 73,924-byte Markdown input is cleaned, parsed to HTML and link-rewritten twice: once for the page and once for search indexing.
- **Fix:** Store the first rendered HTML in a local variable and reuse it for the page and the existing plain-text conversion.
- **Justification:** This replaces two identical expensive expressions with one local result and two references; no shared helper or persistent cache is needed.
- **Benefit:** One complete Markdown conversion/link-rewrite pass removed per site build; build time unmeasured. One additional local reference, with no duplicate renderer result required.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; input bytes measured).

## POPSLOADER-109 / Delete contradictory advice from the hand-written FAQ / Categories 6, 7

- **Location(s):** POPSLoader/.research/build_site.py:1294-1295,1344-1353,1828-1831,1861-1863.
- **Problem:** The USB-detection FAQ recommends increasing `$USBDELAY_#` and immediately says that setting does not fix detection; the other two sections correctly direct detection changes to byte `$413`. The save-loss FAQ also presents an explicitly historical, unconfirmed early-era Slim report as a current condition, while the detailed section says its relevance to current releases is unknown.
- **Fix:** Delete the streaming-delay recommendation from the detection answer and remove the unqualified current save-loss claim, retaining links to the existing detailed explanations.
- **Benefit:** Two misleading recommendations removed; no new documentation system or runtime code. Reduces drift between duplicate descriptions.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ for contradictions; no claim that the historical hardware defect was reproduced).

## POPSLOADER-110 / Remove unused presentation fields from the site tables / Categories 1, 3

- **Location(s):** POPSLoader/.research/build_site.py:244-256,262,492,675-689,932-969,1040-1043,2082-2085.
- **Problem:** All eleven section emoji fields are empty but still carry an extra tuple element, unpacking variables and an all-empty `SEC_EM` dictionary. Each of the nine download groups also carries a destination string that its consumers discard as `_d`/`_dest`; actual file pills come from `DL_CARD_PILL`.
- **Fix:** Delete the empty section fields and `SEC_EM` plumbing, and remove the unused destination element from download groups and their unpacking sites.
- **Benefit:** Nine unused group strings, eleven empty fields, one dictionary and redundant interpolation/unpacking removed; small desktop-only source/data reduction, exact net bytes unmeasured.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; complete file and reference search).

## POPSLOADER-111 / Delete the archive-size placeholder and its post-build rewrite / Categories 3, 6

- **Location(s):** POPSLoader/.research/build_site.py:1093-1100,2195-2213,2358-2364.
- **Problem:** The documentation ZIP is created before `downloads.html` has `__ARCHIVE_SIZE__` replaced. Its embedded Downloads page therefore permanently contains the literal placeholder, while only the separate published page receives the replacement.
- **Fix:** Omit the parenthesized archive size from the link and delete the HTML reread/rewrite used to patch it. Keep the existing build summary's size if useful.
- **Benefit:** Three post-build file operations/assignment lines removed and correct link text in both copies; tiny desktop-only saving. No second ZIP build or size-fixing loop needed.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; archive construction order, not a full site build).

## POPSLOADER-112 / Delete overridden CSS declarations / Categories 1, 2

- **Location(s):** POPSLoader/.research/_srcassets/style.css:1027-1036,1082-1087,1333-1339,1350-1358.
- **Problem:** A later `.dl b` block repeats or overrides every declaration in its earlier block. A later `.callout .h` block likewise repeats/overrides all but the earlier color declaration.
- **Fix:** Delete the earlier `.dl b` block and retain only the necessary color declaration in the earlier `.callout .h` block, or consolidate each selector at its final occurrence without changing cascade order.
- **Benefit:** About 14 redundant declaration/block lines removed; very small stylesheet transfer/maintenance saving, no measured browser speedup or PS2 runtime effect.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; same specificity and cascade order).

## Supplement to POPSLOADER-040 — superseded comments in the runtime sources

Additional locations: POPSLoader/bin/POPSLDR/system.lua:2071-2097,5094-5098,6251,9184-9188; POPSLoader/bin/POPSLDR/ui.lua:6236-6243. These retain the old HDD-settings-to-memory-card model or describe a running ATA worker. The current HDD settings setup/write path is system.lua:5112-5127,6152-6161, while the dormant-worker implementation is already covered by POPSLOADER-005. Delete the false present-tense comments as part of those canonical cleanups; retain the actual current mount/launch contracts. This adds source-comment locations to POPSLOADER-040, not another finding. Benefit is fewer misleading source lines; the build minifier already strips comments, so no ELF/RAM saving is claimed.

## POPSLOADER-113 / Delete the empty final SMB harness guard / Categories 1, 7

- **Location(s):** POPSLoader/tools/host_harness.py:2461-2465.
- **Problem:** The last branch in the SMB handoff check claims to verify narrow scoping, but its only body is `pass`. It cannot change the test result for any source input.
- **Fix:** Delete the empty `else`/`if` block and its misleading comment. Keep the preceding checks that actually set a failure result.
- **Benefit:** Five dead source lines removed; no actual validation is lost and no new test machinery is needed. Tiny desktop-only cleanup, no measured runtime saving.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).
