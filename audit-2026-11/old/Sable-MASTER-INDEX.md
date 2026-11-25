# Sable Audit — MASTER INDEX (all findings, all rounds)

Generated **2026-11-14** by extraction from the audit’s own report files (see §5, Verification note). This index adds no findings and re-ranks nothing: titles, categories, effort, risk and confidence are transcribed from each finding’s own header/fields; statuses are transcribed from the SUMMARY addenda and the round files’ revision sections; the top-tier list in §3(b) is the addenda’s own headline lists, unaltered except for the Category-6 filter stated there.

Source files: `Sable-<REPO>.md` (pass 1) and `Sable-<REPO>-ROUND2/3/4/5.md` for RiptOPL, Launchstation, POPSLoader, Simple-Media-System and PS2-Servers, plus `Sable-Simple-Media-System-ROUND6.md`, the five `Sable-<REPO>-ROUND7.md` scope-extension files, `Sable-RiptOPL-ROUND8.md` / `Sable-Launchstation-ROUND8.md` / `Sable-Simple-Media-System-ROUND8.md`, and the round-9 files `Sable-RiptOPL-ROUND9.md` (headers), `Sable-RiptOPL-ROUND9-MODULES.md`, `Sable-RiptOPL-ROUND9-THIRDPARTY-A.md`, `Sable-RiptOPL-ROUND9-THIRDPARTY-B.md` and `Sable-Simple-Media-System-ROUND9.md`; `Sable-SUMMARY.md` (pass-1 cross-references X-01…X-16 and the Round 2–9 addenda, incl. the Round 7 Correction and the tarball-completion addendum); `Sable-CROSSREPO-ROUND2/3/4/5.md` (X-17…X-51), `Sable-CROSSREPO-ROUND7.md` (X-52…X-53) and `Sable-CROSSREPO-ROUND9.md` (X-54…X-57); and `Sable-VERIFICATION-NEW-FINDINGS.md` (verification phase — the 6 findings the verification passes filed: RIPTOPL-602; SMS-183, SMS-184; POPSLOADER-108; PS2SERVERS-114, PS2SERVERS-115) and `Sable-VERIFY2-NEW-FINDINGS.md` (full-verification phase — the 12 findings the full-verification passes filed: RIPTOPL-603, RIPTOPL-604, RIPTOPL-605; SMS-185, SMS-186, SMS-187, SMS-188; PS2SERVERS-116, PS2SERVERS-117, PS2SERVERS-118; X-58, X-59). Regenerated after round 9, the POPSLoader tarball completion, the 2026-11-14 verification phase (adversarial Cat-6 re-verification, consistency census, execution re-runs) and the 2026-11-14 full-verification phase (every remaining STANDING/REVISED finding adversarially re-derived — see §1.2 and §4); all five repos carry exhaustion verdicts, each since narrowed by its round-7/8/9 residue statements.

---

## 1. Header

### 1.1 Pins

**Pass 1** — fresh clones from github.com/NathanNeurotic, checked 2026-11-13 10:03 PST (full table in `PINS.md`):

| Repo | Branch | HEAD (pass 1) | Tracked files |
|---|---|---|---|
| RiptOPL | rebuild/main | `677812185ac5aab96bf697f21919a5729307ec4a` | 2,380 |
| Launchstation | master | `8cd3329a98c09a570bfbf60137717edd42324990` | 1,065 |
| POPSLoader | master | `29272cddbf0122f14e76bc3bdd75e3b46aa870be` | 609 |
| Simple-Media-System | master | `b9a5c882d6d632914faa4ff8dc080f1ecd51bfd7` | 1,012 |
| PS2-Servers | main | `5179b4bb1f488ef2eb91956c8792e2194dda2fca` | 596 |

**Round 2** — live heads had moved in 4 of 5 repos; clones updated in place, read-only (full table in `PINS-ROUND2.md`):

| Repo | Round-2 HEAD | Commits between pins |
|---|---|---|
| RiptOPL | `2e347d5ac885cd0ff73e9ad4143781946396f492` (rebuild/main) | 3 (#420, #419, #417) |
| Launchstation | `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (master) | 3 (#384; #385/#386 docs palette) |
| POPSLoader | `29272cddbf01` (master) | 0 — unchanged |
| Simple-Media-System | `e65ced39a27eee8d996e9257e21594d1cac1c93d` (master) | 2 (docs palette only) |
| PS2-Servers | `c5f021c4d38698860f56b03498adc261dbb8d8dd` (main) | 2 (docs palette only) |

**Rounds 3–5 ran at the round-2 pins.** Round 3 addendum: “round-2 pins held for all repos (verified at start and end of every round-3 workstream)”. Round 4 addendum: “all five live heads re-checked — **nothing moved**”. Round 5 addendum: “all five live heads re-verified **unmoved** for the fourth consecutive round.” One fetched-dependency pin also matters to the verdicts: Launchstation’s libsmb2 was fetched at upstream `a52c1571a1ff223bde5bb3df9fec7af5ce3855d4` (the commit `scripts/fetch_libsmb2.sh` pins) with both local patches applied, for the round-4 revisions R4-R1…R3. **Rounds 6–9 also ran at the round-2 pins** — every later addendum re-verifies the same five heads unmoved (POPSLoader’s pin never moved at any point in the audit).

### 1.2 Exhaustion verdicts (each repo’s own words, one line + residue)

- **POPSLoader — EXHAUSTED at source level** (Round 4, `Sable-POPSLoader-ROUND4.md` §VERDICT): “Yes — with the exact exceptions tabled below, every line of text source in this repo has now been read by this audit, and what remains open is not unread code but the classes of thing a source audit in this VM cannot settle.” *Residue (not unread source):* the generated bin2c `loader.c` dump (8,740 lines); the BDMAssault tarball’s upstream contents (auditable only if the REV-006 extraction lands); documentation prose; binary contents; hardware behaviour. “A round 5 for POPSLoader is productive only if the pin moves or the extraction lands.”
- **PS2-Servers — EXHAUSTED at first-party source level** (Round 5, `Sable-PS2-Servers-ROUND5.md` §6): “PS2-Servers is EXHAUSTED at first-party source level in this environment.” *Residue:* test suites (≈37,000 lines — sampled and executed instead), conformance Python runners (≈2,519 lines, sampled), `vendor/retroachievements` (≈52,963 lines of pinned third-party C — inventoried, byte-parity-covered by the repo’s own conformance gates), `docs/` prose and non-release workflows (inventoried). *Un-executable here, not unread:* live UDP wire interop (sandbox blocks `sendto`), CHD execution (no libchdr), the OpenWrt UCI backend, Windows-only paths, Tk runtime behaviour; nothing verified on a PS2 or a router.
- **Launchstation — EXHAUSTED at source level, subject to a 10-item named residue** (Round 5, `Sable-Launchstation-ROUND5.md` §7): “Launchstation is EXHAUSTED at source level in this environment, subject to the exact residue below.” *Residue:* (a) the smbd link test — un-auditable in this environment (no PS2 toolchain), gating only R4-R3(c)/(d)’s four deletions; (b) fetched libsmb2 client halves / asn1-ber / compat / crypto bodies — inventory-level, pristine upstream (same status for usmb2’s five in-clone helpers); (c) `tests/` beyond the 9 individually cited paths/groups — pattern-classified only; (d) docs/docs-site prose — inventoried by size; (e) binaries/IRX/payloads — sized and hashed, never disassembled; (f) build glue for eight small modules inventoried, not line-read; (g) ds34 `smsutils.S` assembly — by name only; (h) xparam’s 292 data rows read as structure, factual per-game correctness not validated; (i) one open question, not a finding (ps2ips `do_dns_getserver`); (j) no PS2 build, link test or hardware result exists for anything in this audit.
- **RiptOPL — EXHAUSTED at source level on the audit’s stated scope** (Round 5, `Sable-RiptOPL-ROUND5.md` §FORMAL VERDICT): “RiptOPL is exhausted at source level in this environment, on the audit’s stated scope.” Every line of shipped first-party C/C++ and Python (EE `src/`, `ee_core/` C, first-party `modules/`, `tools/`/`elfldr/`/`tests/host`) read end-to-end at the pin across five rounds. *Named remainders, explicitly not that class of source:* assembly sources (3,854 lines — the one body of shipped first-party text a future round could still take); the `.github/scripts` test corpus (59,927 lines, characterised under RIPTOPL-005); headers as a corpus (35,590 lines, consulted throughout); vendored stacks excluded by framing since pass 1 (37,655 `modules/` lines + 204,965 `third_party/` lines); workflows and non-code censused/inventoried. *Un-auditable here regardless of reading:* PS2 build results, real-hardware behaviour, live network interop.
- **Simple-Media-System — EXHAUSTED at source level** (Round 6, `Sable-Simple-Media-System-ROUND6.md` §Verdict): “Simple-Media-System is exhausted at source level in this environment.” Round 6 closed the exact residue round 5 named — the 2,074 lines of EE glue (SMS_Container.c, SMS_Locale.c, SMS_History.c, SMS_Spectrum.c, SMS_VideoBuffer.c remainder) and the SMS_DSP.c kernels — and with it every EE C source in the repo has been read end-to-end at the pin across rounds 1–6 and every locally owned IOP source line-audited. *Not gaps, by the audit’s framing:* vendored codec decode internals (provenance- and allocation-audited, rounds 3–4), the pristine-upstream IOP trees, and all assembly (inventoried by name). *Un-auditable here:* no PS2 build (no PS2SDK) and no hardware in this VM.

**Standing limits for all five verdicts** (SUMMARY, every round): no PS2 build exists in this VM (no PS2SDK), no hardware timing/profiling (Category 5 is structural only), live UDP interop untestable (sandbox blocks UDP `sendto`); nothing in any round is hardware-verified.

**Round 7 update (scope extension, 2026-11-14):** at the user’s direction the audit continued into the residues above — RiptOPL assembly + headers-as-corpus + test-corpus mechanisms + docs (residue now: test corpus bounded-not-line-closed); Launchstation tests/ + libsmb2 client/crypto + build glue + assembly + xparam corpus (residue now: docs prose is the largest untouched class; smbd link test still impossible); POPSLoader tarball contents + loader.c invariant + docs (residue now: binary contents and hardware only); SMS codec decode internals + parsing IOP trees + assembly + macros (residue now: constant-table regions, AC3 imdct full read, IOP non-parsing internals, elided SIMD ranges, SMS docs prose); PS2-Servers test suites + conformance + vendor surface + docs (residue now: the un-executable-here classes only — “nothing else remains unread at the pin”); cross-repo generated-artefact census (zero confirmed drift). Each round-7 report carries its own updated residue statement, which supersedes the round 4–6 residue lists quoted above.

**Tarball completion + Round 8 update (2026-11-14):** the POPSLoader round-7 tarball section — whose claimed remainder (077…096) had never been written, see §1.3 — was re-derived end-to-end from the extracted tarball: POPSLOADER-076’s body completed from source (number/title/status unchanged) and 31 findings filed as POPSLOADER-077…107 (headlines: -077 STOP_UNIT/STOP_ALL bodies swapped; -078 IsoTD halted-flush clears the wrong LUT slot; -080 part_read/part_write never clamp to the partition’s sectorCount), for a final tarball-section total of 37 findings (071…107). Round 8 then closed the three remaining read-shaped residues: Launchstation docs prose **CLOSED** (109 files / 11,439 lines read in full; 209 claim groups — 167 match, 33 contradicted deduped to LAUNCHSTATION-200…223, ~18 unverifiable listed not filed; -200’s example-config double-slash is the one function-breaking docs finding); SMS constant tables (313 counted), AC3 imdct, IOP non-parsing internals, elided SIMD ranges and docs prose closed (SMS-158…178; residue narrowed to the USBD dispatch layer + hub.c remainder, both closed in round 9); RiptOPL’s `.github/scripts` corpus **LINE-CLOSED** (302 files / 63,264 lines; RIPTOPL-296…343, plus the RIPTOPL-291 formal extension and the narrowing recorded at RIPTOPL-301). PS2-Servers and POPSLoader had no round-8 reading scope.

**Round 9 update (2026-11-14, the user’s “line for line supreme ultra max” directive):** RiptOPL headers line-closed as a corpus (260 files / 16,029 lines outside `modules/`+`third_party/`; RIPTOPL-344…367), `modules/` full line-read (493 files / 128,148 lines; RIPTOPL-400…499 plus the appendix overflow allocated RIPTOPL-512…530), and `third_party/` in two passes under the vendored lens (RIPTOPL-500…511, RIPTOPL-600…601 — mbedTLS, the PSUManager core and ps2sdk-socket all proven byte-identical to their pinned upstreams by execution, so those findings are integration-only); SMS’s last named source closed (SMS-179…182 — the USBD dispatch layer and hub.c remainder read, both round-8 not-promoted items settled by promotion); cross-repo shipped-binary/IRX verification with real MIPS disassembly (X-54…X-57; 206 artefacts inventoried; POPSLOADER-069 upgraded to disassembly-verified). *Residue after round 9* (SUMMARY Round 9 addendum): at the round-2 pins every first-party source corpus in all five repos has been line-read, documentation claims-checked, and shipped binaries inventoried — what remains is not unread text: a behavioural/disassembly audit of the other 205 binaries, PS2 build results (no PS2SDK in this VM), real-hardware behaviour (nothing in any round is hardware-verified), live network interop, and the spec-only/external-contract items recorded inside findings.

**Verification phase (2026-11-14):** every Category 6 finding in §3(b) (239 across the three Cat-6 passes) was adversarially re-derived from source at the same pins — **165 VERIFIED, 45 VERIFIED-DRIFT (mechanism holds; corrected citations recorded in the VERIFY files), 26 WEAKENED (narrowed conditions recorded in §4), 3 REFUTED and withdrawn** (RIPTOPL-443, RIPTOPL-513, SMS-015). A consistency census over all 1,182 findings confirmed 16 duplicate pairs (9 full — the later filing retired as CROSS-REF; 7 partial), 4 contradictions (C-1…C-4, dispositioned in §4) and **0 orphans**; a fresh re-execution pass confirmed 13 execution-based claims (0 broken, 3 environment-blocked). The verification phase also filed 6 new findings (RIPTOPL-602; SMS-183, SMS-184; POPSLOADER-108; PS2SERVERS-114, PS2SERVERS-115 — collected in `Sable-VERIFICATION-NEW-FINDINGS.md`). The delivered total is now **1,188 numbered items**; the round-9 residue statement above is unchanged — verification re-checked claims, it did not extend coverage.
**Full verification (2026-11-14):** at the user’s direction (“all of them”), every finding the verification phase had not covered was then adversarially re-derived from source at the same pins — **939 verdict rows: 751 VERIFIED, 122 VERIFIED-DRIFT (mechanism holds; corrected citations recorded in the six `Sable-VERIFY2-*.md` files), 51 WEAKENED (narrowed conditions recorded in §4), 14 REFUTED and withdrawn, 1 environment-blocked aspect** (PS2SERVERS-071’s mutation run; its REVISED status is unchanged). Combined with the verification phase, **1,178 verdict rows** now cover the corpus, and every STANDING/REVISED finding has been adversarially re-derived at least once. The phase’s worst discovery: five round-7 PS2-Servers findings (PS2SERVERS-104, -105, -109, -110, -111 — the Cat-2 test-census sub-block) rest on **fabricated citations** — the files and functions they cite do not exist at the pin; all five are withdrawn (VERIFY2-W7…W11 in §4). The phase also filed 12 new findings (RIPTOPL-603, -604, -605; SMS-185…188; PS2SERVERS-116, -117, -118; X-58, X-59 — collected in `Sable-VERIFY2-NEW-FINDINGS.md`). The delivered total is now **1,200 numbered items**.

### 1.3 Counting reconciliation

Extraction from the numbered files now reproduces the claimed figures exactly in all six ranges — **1,200 rows**. The one historical discrepancy is closed: the POPSLoader round-7 report originally claimed 37 round-7 findings (060…096) while only 17 bodies (060…076) were ever written — the tarball remainder (claimed 077…096) was lost at the same truncation that cut -076’s body, and existed in no delivered file. The completion pass re-derived the section from the extracted tarball and filed 31 findings as POPSLOADER-077…107, so the delivered file now contains 060…107 in full and this index extracts them (evidence trail in §5). One numbering feature to read correctly: RiptOPL’s round-9 numbers are **allocated blocks, not a contiguous range** — 368…399 and 531…599 were never assigned (block allocation across the parallel round-9 passes, with the modules pass’s 19-finding overflow allocated 512…530), so RiptOPL totals 504 items across 001…367 + 400…530 + 600…605 with no missing findings inside any allocated block. The verification phase then added 6 findings (in `Sable-VERIFICATION-NEW-FINDINGS.md`) and changed 41 statuses (3 withdrawals, 13 duplicate retirements to CROSS-REF, 25 revisions) without changing any other number. The full-verification phase then added 12 findings (in `Sable-VERIFY2-NEW-FINDINGS.md`) and changed 64 statuses (14 withdrawals — 13 from STANDING and SMS-123 from REVISED; 50 revisions — 49 from STANDING and X-07 from CROSS-REF, with LAUNCHSTATION-072’s existing revision narrowed further in place) without changing any other number.

| Range | Items | Source files |
|---|---|---|
| RIPTOPL-001…367, 400…530, 600…605 | 504 | pass 1 (36) + R2 (15) + R3 (14) + R4 (79) + R5 (136) + R7 (15) + R8 (48) + R9 (157: headers 24, modules 119 incl. appendix 512…530, third-party A 12, third-party B 2) + verification (1: RIPTOPL-602) + full verification (3: RIPTOPL-603, RIPTOPL-604, RIPTOPL-605) |
| LAUNCHSTATION-001…223 | 223 | pass 1 (32) + R2 (20) + R3 (25) + R4 (19) + R5 (89) + R7 (14) + R8 (24) |
| POPSLOADER-001…108 | 108 | pass 1 (25) + R2 (22) + R3 (5) + R4 (7) + R7 as completed (48: 060…107, incl. the completion pass’s 077…107) + verification (1: POPSLOADER-108) |
| SMS-001…188 | 188 | pass 1 (35) + R2 (14) + R3 (3) + R4 (4) + R5 (36) + R6 (10) + R7 (55) + R8 (21) + R9 (4) + verification (2: SMS-183, SMS-184) + full verification (4: SMS-185, SMS-186, SMS-187, SMS-188) |
| PS2SERVERS-001…118 | 118 | pass 1 (40) + R2 (15) + R3 (7) + R4 (5) + R5 (2) + R7 (44) + verification (2: PS2SERVERS-114, PS2SERVERS-115) + full verification (3: PS2SERVERS-116, PS2SERVERS-117, PS2SERVERS-118) |
| X-01…X-59 | 59 | SUMMARY (16) + CROSSREPO R2 (14) + R3 (10) + R4 (8) + R5 (3) + R7 (2) + R9 (4) + full verification (2: X-58, X-59) |
| **Total numbered items** | **1,200** | every allocated block extracted complete — no gaps inside any allocated block, no duplicate IDs; the unallocated RiptOPL numbers (368…399, 531…599) are block allocation, not missing findings |

By status: **1054 STANDING**, **100 REVISED** (see §4), **28 CROSS-REF** (X-01…X-16 pass-1 cross-references, minus X-07 (moved to REVISED by the full-verification phase) — each defect also carries a per-repo number, listed once per the brief — plus 13 verification-phase duplicate retirements: RIPTOPL-344, -405, -408, -411, -416, -444, -445, -454, -455, -468, -501, X-17, X-23; each points at its canonical earlier finding in §4), **18 WITHDRAWN** (LAUNCHSTATION-065; RIPTOPL-443, RIPTOPL-513 and SMS-015 — the verification phase’s three refutations — plus the full-verification phase’s 14: RIPTOPL-051, RIPTOPL-348, LAUNCHSTATION-100, LAUNCHSTATION-127, LAUNCHSTATION-214, X-57, PS2SERVERS-104, PS2SERVERS-105, PS2SERVERS-109, PS2SERVERS-110, PS2SERVERS-111, SMS-013, SMS-089 and SMS-123). 1200 − 18 withdrawn = **1182 not withdrawn**. Build-up, all figures the extraction’s: round-6 consolidation 746 → round 7 as actually written in the reports (+147) → 893 → tarball completion (+31) → 924 → round 8 (+93; RIPTOPL-291 moves STANDING→REVISED by formal extension and the new RIPTOPL-301 carries the round-8 narrowing, so the revised count rises by 2) → 1,017 → round 9 (+165, all STANDING) → 1,182 → verification phase (+6 new findings; 3 STANDING→WITHDRAWN, 13 STANDING→CROSS-REF, 25 STANDING→REVISED) → 1,188 → full-verification phase (+12 new findings; 13 STANDING→WITHDRAWN, SMS-123 REVISED→WITHDRAWN, 49 STANDING→REVISED, X-07 CROSS-REF→REVISED) → 1,200.

Narration slips inside the sources themselves, recorded so the files — not the prose around them — stay authoritative:

- The Launchstation Round 5 verdict paragraph says “a five-round total of **210**”. The numbered files give **185** contiguous findings (001–185); 210 is the arithmetic slip the Round 5 addendum already identifies in chat narration (“Launchstation ‘121/210’ … correct: 96/185”). The files win: **185**.
- The SUMMARY pass-1 header’s “Totals: 168 findings” counts the five per-repo files only (36+32+25+35+40); X-01…X-16 sit on top of that as cross-references, exactly as the reconciliation above states. Not a discrepancy — two different bases, both now explicit.
- The RiptOPL round-9 headers report records that rounds 7/8’s header-corpus totals (35,590–35,808 lines) do not reproduce at the pin under any measured extension set; round 9’s measured ledger (260 files / 16,029 lines outside `modules/`+`third_party/`; 695 files / 112,383 lines repo-wide) is the authoritative one. Recorded so the earlier figures are not quoted forward.

---

## 2. Full table — every numbered item

Columns transcribed from each finding’s own header/fields. **Cat** is the audit’s category number (dual categories as written, e.g. `6/2`). **Effort/Risk** use each round’s own vocabulary (XS/S/M/L; Launchstation Round 5 also writes `Trivial`, `One character`, `One token`, `1 line`, `~3 lines` for effort and `Minimal`/`Negligible`/`Near zero`/`None` for risk — kept as written). **Confidence** is normalised only to grade + READ/INFERRED tags (e.g. `High (READ)`); prose qualifiers are dropped except that an INFERRED component is preserved as `INFERRED in part` (see §5). `—` means the source gives no value for that field (itemised in §5).

### 2.1 RiptOPL — 504 items

| ID | Title | Cat | Effort | Risk | Confidence | Status |
|---|---|---|---|---|---|---|
| RIPTOPL-001 | docs/assets is 53.7 MB of duplicated tour media in the source repo | 7 | S | Low | High (READ) | REVISED (full verification — WEAKENED: the 53,655,730 B total is exact, but the plain and incebtion/ sets are two different themes’ footage, not duplicate copies; the recoverable saving is roughly one format per theme, not ~35–45 MB) |
| RIPTOPL-002 | ship/Example is a second, committed copy of the whole ship tree | 2 | M | Med | High (READ) | STANDING |
| RIPTOPL-003 | A 1,251-line Makefile that can no longer build the program is kept as a second build definition | 7 | M | Med | High (READ) | STANDING |
| RIPTOPL-004 | 273 remote branches, 225 of them claude/* agent branches | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-005 | 277 Python "tests" in .github/scripts, most of them source-text grep assertions | 7 | L | Med | High (READ) | STANDING |
| RIPTOPL-006 | mbedTLS is vendored whole and globbed whole into two editions | 4 | M | Med | Med (READ) | STANDING |
| RIPTOPL-007 | Edition × configuration × toolchain × device matrix is the project's largest surface | 3 | M | Med | High (READ) | STANDING |
| RIPTOPL-008 | UDPFS IOP stack is copy-pasted three times, byte-identical | 2 | M | Med | High (READ) | REVISED (R2 — reframed; remainder filed as RIPTOPL-048) |
| RIPTOPL-009 | Twelve workflows, 2,220 lines, six of them scheduled watchers/publishers | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-010 | Six POPSTARTER variants ship in the bundle, including three DEBUG builds | 8 | S | Low | High (READ) | STANDING |
| RIPTOPL-011 | ~130 PNG assets are bin2c-embedded into every ELF, including both button-glyph sets | 4 | M | Med | High (READ) | STANDING |
| RIPTOPL-012 | FatFs unicode tables for all code pages compiled into the IOP for one fixed SBCS code page | 4 | M | Med | Med (READ) | STANDING |
| RIPTOPL-013 | .bak backups are still written to memory cards by the POPSTARTER/UDPFS config editor and the VMC rebuild | 3 | S | Med | High (READ) | STANDING |
| RIPTOPL-014 | Permanent multi-KB static buffers in BSS for occasional operations | 4 | S | Med | High (READ) | STANDING |
| RIPTOPL-015 | sysDeleteFolder uses a malloc'd path without checking the allocation | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-016 | SMB credentials and share names strcpy'd into fixed cdvdman settings fields | 6 | S | Low | High (READ) | REVISED (verification — WEAKENED: survives only for smb_share via the unterminating share-selection memcpy at ethsupport.cpp:1307; config/GUI writers terminate the other fields) |
| RIPTOPL-017 | sprintf into 32/64-byte buffers in OSD history handling | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-018 | The per-source game-launch leg is copy-pasted across six call sites in five files | 2 | L | Med | Med (READ; INFERRED) | STANDING |
| RIPTOPL-019 | Directory scan probes every entry with a second opendir | 5 | S | Med | High (READ) | REVISED (full verification — WEAKENED: the opendir probe at supportbase.cpp:397 fires only for non-ISO candidate entries when folder browsing is enabled for that scan — not an unconditional per-entry probe) |
| RIPTOPL-020 | Permanent foreign-format compatibility layers for wOPL configs and favourites | 3 | M | Med | High (READ) | STANDING |
| RIPTOPL-021 | iLink driver maintained twice, already diverged | 2 | S | Med | High (READ) | REVISED (R2 — expanded; whole-tree copy filed as RIPTOPL-047) |
| RIPTOPL-022 | Korium theme assets are stored as a zip inside the repo and unzipped at build time | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-023 | AGENTS.md and CLAUDE.md are the same file twice | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-024 | audio/bgm.ogg: a 324 KB track kept "only as a reference" — and a second, different copy in the ship bundle | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-025 | Seventy docs files including dated checkpoint/plan archaeology | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-026 | Three publishing scripts re-implement the same release plumbing | 2 | M | Med | Med (READ; INFERRED) | REVISED (R5 — plumbing clause narrowed) |
| RIPTOPL-027 | The NBD server is embedded in every build, including every Lite build | 8 | S | Low | High (READ) | STANDING |
| RIPTOPL-028 | HTTP as a game source: a full extra source stack for the least-capable transport | 8 | M | High | Med (READ; INFERRED) | STANDING |
| RIPTOPL-029 | CPU plasma background is rendered every frame | 5 | M | Med | Med (READ; INFERRED in part) | REVISED (full verification — WEAKENED: the plasma is a 32×32 Perlin texture refreshed 6 rows per frame (~192 pixels/frame, deliberately throttled), not a full-screen per-pixel per-frame CPU effect) |
| RIPTOPL-030 | Monolith source files concentrate the UI and per-device logic | 3 | L | Med | High (READ) | STANDING |
| RIPTOPL-031 | tests/host stub headers: twenty identical empty SDK stubs | 7 | S | Low | High (READ) | REVISED (full verification — WEAKENED: sdk_stub holds 23 files of which 19 are the identical empty stub, not 20; the duplicated-name second tree stands) |
| RIPTOPL-032 | Tracked prebuilt debug IRX binaries in modules/debug | 7 | S | Low | Med (INFERRED) | REVISED (full verification — WEAKENED: the four .irx have no source and no ps2.yaml rule, but the legacy Makefile:1182-1191 does contain bin2c embedding rules for them — unexplained inputs for the live build, not wholly rule-less files) |
| RIPTOPL-033 | 35 translations maintained as a fork overlay on top of a downloaded set | 3 | M | Med | Med (READ; INFERRED) | STANDING |
| RIPTOPL-034 | Commented-out and legacy code markers in first-party code | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-035 | README is 1,116 lines and doubles as the manual, the changelog and the feature spec | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-036 | Diagnostic build holds a static screen for a full 8 seconds | 5 | S | Low | Med (READ) | STANDING |
| RIPTOPL-037 | NBNS receive thread can be overflowed by any host on the LAN | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-038 | smbman-ra copies the server-supplied filename length with no bound | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-039 | MMCE game-ID is `strcpy`'d unbounded in both directions | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-040 | smb_fio builds paths with `strncpy` and never terminates them | 6 | S | Low | High (READ) | REVISED (full verification — WEAKENED: the smb_dopen strcat overflow stands (1–2 bytes past name[256] for ≥255-char directory paths), but the unterminated-name/chdir cascade is defeated — the size−1 copy counts preserve the zeroed last byte, so strlen stays bounded) |
| RIPTOPL-041 | cdvdman `.PSS` check indexes before the buffer for short filenames | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-042 | APA ioctl2 handlers index the partition table with an unchecked caller-supplied index | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-043 | UDPFS trusts the server's per-read result count without clamping it to the request | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-044 | UDPFS `dread` validates a server name length against the buffer size, but not against the bytes received | 6 | S | Low | High (READ) | REVISED (R4 — ioman-side call site cleared; core defect stands) |
| RIPTOPL-045 | Streaming DMA wait is an empty busy-spin, next to code that was fixed for doing exactly that | 5 | S | Low | High (READ) | STANDING |
| RIPTOPL-046 | Two complete SMB1 client stacks are maintained in parallel, sharing 19 functions | 2 | L | Med | High (READ) | STANDING |
| RIPTOPL-047 | `modules/bdmassault/` is a near-total second copy of `modules/ilink/` (expands RIPTOPL-021) | 2 | L | Med | High (READ) | STANDING |
| RIPTOPL-048 | UDPFS headers are still stored three times (the corrected remainder of RIPTOPL-008) | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-049 | The SIO2 hook layer is duplicated between the MMCE and MX4SIO drivers | 2 | M | Low | High (READ) | STANDING |
| RIPTOPL-050 | Self-update holds the entire replacement ELF in EE RAM to verify it | 4 | M | Med | Med (READ) | STANDING |
| RIPTOPL-051 | mcemu's read/write size guard can never fire | 1 | S | Low | High (READ) | WITHDRAWN (full verification phase 2026-11-14 — REFUTED: size is u32, so size <= 0 is a live == 0 exit at mcemu.c:845,896) |
| RIPTOPL-052 | ~370 lines of deliberately unreachable partition-editing machinery in the shipped APA driver | 1 | S | Low | READ | STANDING |
| RIPTOPL-053 | smb2man.c and nfsman.c each carry their own copy of the same IOP front-end (~200 lines × 2) | 2 | M | Low–Medium | READ | STANDING |
| RIPTOPL-054 | Three game patches in patches.c re-implement the same SifLoadModule hook scaffold | 2 | M | Medium | READ | STANDING |
| RIPTOPL-055 | Per-pixel busy-wait inside the IGS colour-conversion loops | 5 | S | Low | READ; INFERRED in part | STANDING |
| RIPTOPL-056 | Two diverged copies of the same DES implementation in the two SMB1 drivers | 2 | S | Low–Medium | READ | REVISED (full verification — WEAKENED: the two DES copies diverge in const-correctness, DES_Keys scope/alignment and local placement (~24 stripped diff lines, not 71); the smbinit copy does keep a static key buffer (function-local, des.c:451) — the stated presence-vs-absence divergence is wrong; “one copy patched” survives only for const) |
| RIPTOPL-057 | mmce_fs devctl dereferences `arg` unchecked in four cases, beside a fifth case that validates it | 6 | S | Low | READ | STANDING |
| RIPTOPL-058 | MMCE filesystem ops truncate every filename length into a u8 | 6 | S | Low | READ | STANDING |
| RIPTOPL-059 | Five near-identical number-to-string converters in igs_api.c | 2 | S | Low | READ | STANDING |
| RIPTOPL-060 | ps2atad re-reads LBA 0 from the disk on every low-LBA BDM write | 5 | S | Low–Medium | READ; INFERRED in part | STANDING |
| RIPTOPL-061 | SOS PAL patch branch is dead: the hook install is commented out, the hook's PAL half remains | 1 | S | Low | READ | STANDING |
| RIPTOPL-062 | mmce_fs_write returns the card's byte count unclamped; mmce_fs_read clamps it | 6 | S | Low | READ | STANDING |
| RIPTOPL-063 | NIBBLE2CHAR produces 'k'–'p' for nibbles 10–15 | 6 | S | Low | READ; INFERRED in part | STANDING |
| RIPTOPL-064 | genvmc's hand-rolled 32×32 multiply serves one caller, and half its result is discarded | 3 | S | Low | READ; INFERRED in part | REVISED (R5 — extended: second location in PC genvmc) |
| RIPTOPL-065 | ra_disc_us in raudp.c is a write-only counter | 1 | S | Low | READ | STANDING |
| RIPTOPL-066 | BT DS4 output report: buffer zeroed with the DS3 length, sent with the DS4 length — in both Bluetooth copies | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-067 | ps2ips `do_setsockopt` copies an EE-supplied length into a 128-byte stack buffer with no bound | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-068 | cdvdman `atad.c`: the PIO transfer function returns success before transferring anything; ~45 lines below it are unreachable | 6 | S | Low | High (READ; INFERRED) | STANDING |
| RIPTOPL-069 | mcemu trusts the card spec's PageSize against fixed 512-byte data / 32-byte ECC buffers | 6 | S | Low | Medium (READ; INFERRED in part) | STANDING |
| RIPTOPL-070 | SMB share-picker trusts the IOP's returned share count against a 128-entry stack array | 6 | S | Low | High (READ; INFERRED) | STANDING |
| RIPTOPL-071 | Ethernet link-mode from the config file indexes a 4-entry table in ee_core with no range check | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-072 | mcemu accepts any page number from the game packet; CardSize is never used as a bound | 6 | S | Low | Medium (READ; INFERRED in part) | STANDING |
| RIPTOPL-073 | Network IP strings are parsed with unchecked `sscanf` at six sites, unlike the validating RA parser in the same file | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-074 | smb_fio's shared path scratch buffers are filled before the I/O lock is taken | 6 | S | Low | Medium (READ; INFERRED in part) | STANDING |
| RIPTOPL-075 | smb_fio dereferences the file handle before (or without) any NULL check in five entry points | 6 | S | Low | High/Medium (READ; INFERRED) | STANDING |
| RIPTOPL-076 | apa `apaGetFormat` dereferences an unchecked cache allocation | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-077 | `usb_mass_connect` re-reads descriptors with none of `usb_mass_probe`'s NULL checks | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-078 | All dialog text rows share 32-byte storage, silently truncating the Custom Settings Path (64) and BGM Path (128) on any Settings round-trip | 6 | M | Medium | High (READ) | STANDING |
| RIPTOPL-079 | config.path MC mirror creates the OPL folder on the wrong card | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-080 | ps2ips `do_accept` / `do_getsockname` / `do_getpeername` pass an uninitialised `addrlen` and copy the address struct even on failure | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-081 | udpfs_ioman open handles keep their pre-disconnect server handle numbers across a watchdog reconnect | 6 | S | Low | High (READ; INFERRED) | STANDING |
| RIPTOPL-082 | mcemu Sio2McEmu writes fixed/derived response lengths never checked against the packet's own transfer length | 6 | S | Low | Medium (READ; INFERRED in part) | STANDING |
| RIPTOPL-083 | Pademu USB: `ds34usb_init` never initialises `outEndp` to −1, so the first connection never opens the output endpoint | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-084 | Theme catalog entry allocations are used without a NULL check | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-085 | `smb_lseek64`: SEEK_END ignores its offset, and no seek is floored at zero | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-086 | HDPro ATAD: transfer retries a failing chunk forever, with no delay, while holding the I/O semaphore | 6 | S | Low–Medium | High (READ) | STANDING |
| RIPTOPL-087 | `apaFindPartition` converts a chain-walk I/O error into a clean "not found" — and one live caller then returns success with an unfilled stat | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-088 | `smb_devctl` validates neither buffer length; Echo/GetShareList trust caller length/address fields | 6 | S | Low | Medium (READ; INFERRED in part) | STANDING |
| RIPTOPL-089 | The last two unbounded `sprintf` calls in the EE sources build the games.bin path into a 256-byte stack buffer | 6 | S | Low | High (READ; INFERRED) | STANDING |
| RIPTOPL-090 | `vcdIsHiddenDisc` accumulates an unbounded disc number into an `int` — signed overflow from a crafted filename | 6 | S | None | High (READ) | STANDING |
| RIPTOPL-091 | `bdmIsReadOnlyPath` parses the mass unit with the unbounded accumulate that `bdmParseBootStem` — in the same file — explicitly fixed | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-092 | Standalone ds34 copies index `power_level[]` with the unguarded device-supplied battery byte; pademu copies guard it | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-093 | SMAP: the DEV9 capability check is a no-op in both neutrino copies (operator precedence); the ingame copy has the correct form | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-094 | `smb_dread` can hand the EE an unterminated directory name | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-095 | A libconfig group header whose name is too long leaves the *previous* group in force, mis-filing following scalars | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-096 | UDPFS theme discovery latches on a possibly partial root listing; its two sibling discovery functions refuse to | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-097 | One-shot probe latches inside bdmsupport survive an IOP reset that `bdmIopWasReset` cannot reach | 6 | S | Low–Medium | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-098 | mcemu `hookDmac_request` dereferences `_SysAlloc`'s result unchecked, and a repeated sio2in request leaks the packet | 6 | S | Low | High/Medium (READ; INFERRED) | STANDING |
| RIPTOPL-099 | usb_mass transfer callback trusts the reported byte count; `remaining` can underflow into an unbounded transfer | 6 | S | Low | Medium (READ; INFERRED in part) | STANDING |
| RIPTOPL-100 | ps2ips `do_getsockopt` always copies 128 bytes into the reply, whatever the call actually returned | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-101 | The config save's restore path writes the snapshot back with a single unchecked `write()` and logs success unconditionally | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-102 | `ConfigSet::getColor` reports success for a malformed colour value | 6 | S | Low | High (READ; INFERRED) | STANDING |
| RIPTOPL-103 | `thmGetTexture` dereferences `gTheme` with no NULL guard, unlike every sibling accessor | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-104 | `ConfigSet::clone` drops the set's on-disk format, silently breaking format inheritance for the clone | 6 | S | Low | High (READ; INFERRED) | STANDING |
| RIPTOPL-105 | Standalone BT: the pressure-emulation flag is global, sticky, and cross-pad | 6 | S | Low | Mechanism READ; how often a 21-byte repo | STANDING |
| RIPTOPL-106 | `get_data` memcpy length is unchecked in all four ds34 copies; only the pademu copies expose a variable length | 6 | S | Low | Code READ; whether a game/SIO path ever  | STANDING |
| RIPTOPL-107 | Pademu ds34 copies dropped the standalone port guards on every public entry point; pademu USB `set_mode` also dropped the semaphore | 6 | S | Low | Code READ; present-day unreachability IN | STANDING |
| RIPTOPL-108 | ds34 report-input guards present in some copies only: standalone BT has no minimum-length check; standalone USB DS3 lacks the null-report rejection | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-109 | Standalone USB: the DS3 enable report is staged in the shared `usb_buf` that `LEDRumble` wipes immediately afterwards, with no completion wait | 6 | S | Low | Sequence and pademu comment READ; that U | STANDING |
| RIPTOPL-110 | Standalone USB `ds34usb_set_bdaddr`: the DS4 pairing report sends 24 bytes; byte 23 is never written | 6 | S | Low | Write/transfer lengths READ; whether the | STANDING |
| RIPTOPL-111 | Pademu BT: the charging-blink flag `oldled[3]` is set in `hid_readReport` but never cleared there (DS3 and DS4) | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-112 | Pademu USB `ds34usb_get_data` overwrites its analog-mode return value with the LED/rumble transfer result | 6 | S | Low | Mechanism READ; the visible symptom (a o | STANDING |
| RIPTOPL-113 | Pademu BT: fake-DS3 LED reports lost the fake transaction header (0xA2) in the port | 6 | S | Low | Divergence READ; device consequence INFE | STANDING |
| RIPTOPL-114 | DS4 rumble scaling `rrum * 255` exists only in the pademu copies and is correct only if `rrum` is a boolean | 6 | S | Low–Medium | INFERRED | STANDING |
| RIPTOPL-115 | `usb_bulk_get_max_lun` returns an uninitialised, signed byte when the device answers short | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-116 | smb_fio `DMA_sendEE` busy-spins twice with no bound | 6 | S | Low–Medium | High (READ) | STANDING |
| RIPTOPL-117 | mx4sio's DMA ISRs busy-spin on the SIO2 status bit with no bound — inside interrupt context | 6 | S–M | Medium | High (READ) | STANDING |
| RIPTOPL-118 | The same unbounded SIO2 status spin is open-coded in all seven thread-context PIO helpers in mx4sio | 6 | M | Low–Medium | High (READ) | STANDING |
| RIPTOPL-119 | SMAP: in both neutrino copies `HandleRxIntr` never counts a packet, so the link-check suppression both `smap.c` copies implement is dead | 6 | S | Low | High (READ; INFERRED) | STANDING |
| RIPTOPL-120 | The `config.path` bootstrap redirect is rewritten non-atomically (O_TRUNC, two writes, unchecked close), and the write leg is duplicated | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-121 | VCD scan allocates the 2,048-entry cap (~532 KB) for every folder, however small | 4 | S–M | Low | High (READ) | STANDING |
| RIPTOPL-122 | BDMA launch validation is computed three times per launch, each time re-walking the memory card | 2 | M | Medium | High (READ) | STANDING |
| RIPTOPL-123 | VCD scan is quadratic twice: per-entry cue dedup scans + per-entry linear memo walk | 5 | M | Medium | High (READ; INFERRED) | STANDING |
| RIPTOPL-124 | `FavSource::image` rescans the whole favourites store from zero for every art request — the sibling lookup in the same file already has the fix | 5 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-125 | `bdmHDDIsPresent` can burn its timeout twice on one call, on the settings-save path | 5 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-126 | The IPCONFIG.DAT line is implemented three times in one file, with two parsers of different strictness for the same format | 2 | S–M | Low–Medium | High (READ; INFERRED) | STANDING |
| RIPTOPL-127 | SMAP: three stored copies of one Ethernet driver; the two neutrino copies are one file twice, the ingame copy is a different generation that cannot be merged with them | 2 | M | Medium | High (READ) | STANDING |
| RIPTOPL-128 | `apa.c` carries the other half of RIPTOPL-052's unreachable partition-edit machinery (~250 lines), and its internals are not safe to resurrect | 1 | M | Low | High (READ) | STANDING |
| RIPTOPL-129 | The network block-device load chain is implemented twice in bdmsupport, with divergent latch/dev9 handling | 2 | M | Medium | High (READ) | STANDING |
| RIPTOPL-130 | The per-slot identity-enumeration loop is copy-pasted at least four times in bdmsupport, and the network wait loop re-runs it from slot 0 every 100 ms | 2 | M | Medium | High (READ) | STANDING |
| RIPTOPL-131 | Per-device config load/save legs in settingsio are copy-pasted per slot and per direction | 2 | S | Low–Medium | High (READ) | STANDING |
| RIPTOPL-132 | The IP-quad row pattern and the POPSTARTER network tables duplicate each other in dialogs.cpp | 2 | M | Low–Medium | High (READ) | STANDING |
| RIPTOPL-133 | The twelve-family theme roster is hand-copied in at least six places in themes.cpp | 2 | M | Low–Medium | High (READ) | STANDING |
| RIPTOPL-134 | One Neutrino resolve can probe the same 8 memory-card candidates twice, from three overlapping variant tables | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-135 | `vcdGetFileSize` and `vcdSourceFileSize` are the same function written twice, one a superset of the other | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-136 | `diaPadEmuInfo` hand-enumerates all 64 Bluetooth feature bits as literal rows | 2 | M | Medium | High (READ) | STANDING |
| RIPTOPL-137 | `prepareCustomApaSettingsPath` is a ~190-line hand-rolled parser with three ad-hoc separator-eating loops and a dual-purpose buffer | 3 | L | Medium | High (READ) | STANDING |
| RIPTOPL-138 | Both cdvdman ATAD variants: `sceAtaInit` returns a device-info struct that nothing ever populates | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-139 | A permanent 4 KB static buffer to streaming-search an 8-byte magic | 4 | S | Low | High (READ) | STANDING |
| RIPTOPL-140 | `bdmDeviceIsATA` stack-allocates a whole per-device struct to hold one 32-byte driver string, and double-checks the match | 4 | S | Low | High (READ) | STANDING |
| RIPTOPL-141 | `VCD_ID_PROBE_BUDGET` is dead: the scan-time probe budget it names no longer exists | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-142 | Self-described unreachable clamp in the VCD scan loop | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-143 | `sbReadList` carries a commented-out size calculator and a dead re-normalisation | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-144 | `thmLoadResource`'s `psm` parameter is dead: accepted at ~10 call sites, never used | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-145 | GetSMBServerReply receives whatever length the server's session header claims, into a 4,224-byte static buffer | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-146 | smb_ReadAndX trusts the response's DataOffset and DataLength — both overflow, one into the caller's buffer | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-147 | APA journal restore trusts the on-disk entry count and replays to unvalidated sectors | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-148 | isofs ignores every `cdEmuRead` failure: failed reads return stale sectors as good data | 6 | S–M | Low | High (READ) | STANDING |
| RIPTOPL-149 | HDD device trusts the on-disc APA header's partition count — stored truncated into a `u8`, then used to walk a 65-entry table | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-150 | smb_NetShareEnum walks the response with strlen and server-supplied offsets, none of them bounded | 6 | M | Low | High (READ) | STANDING |
| RIPTOPL-151 | iso2opl trusts SYSTEM.CNF sizes and strings from the ISO in three places — a crafted ISO overflows a global buffer, a stack buffer, and dereferences NULL | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-152 | VMC-sourced save and file names are never validated, and the folder export writes them into filesystem paths | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-153 | Negotiate copies the server's KeyLength (up to 255) into an 8-byte field | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-154 | smb_QueryPathInformation casts structures at the response's unchecked DataOffset | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-155 | isofs `TocEntryCopy` writes the terminator at the disc-supplied filename length, past its 129-byte field | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-156 | Assault SCSI layer silently truncates LBAs at 2^32 sectors — no READ CAPACITY 16 / READ\|WRITE 16 | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-157 | mcemu HDD backend: a page that maps to no APA fragment is silently translated to sector 0 — the APA header sector | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-158 | SYSTEM.CNF boot token of ≥64 printable chars is returned unterminated | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-159 | PadManager::start() can index padData_ past MAX_PADS — the cap break sits outside the slot loop | 6 | S | Low | High/Med (READ; INFERRED) | REVISED (full verification — WEAKENED: the PadManager::start() loop-structure overflow stands, but it is gated on pads actually opening — padCount_ increments only on startOne() success after padPortOpen; overflow needs four opened pads before an extra slot iteration (e.g. 1 pad + a multitap port)) |
| RIPTOPL-160 | GPT parser never validates an entry's extent: reversed or off-device ranges become huge partitions | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-161 | MBR sanity check is half tautology, and partition extents are never checked against the device | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-162 | pademu assumes every SIO pad transfer is at least a full command long — short transfers overrun `in`/`out` | 6 | S | Low | Mechanism High (READ); that a shipped ga | STANDING |
| RIPTOPL-163 | `scsi_warmup` accepts any non-zero sector size a device reports; the size prints can divide by zero and every transfer length is `sectorSize × count` in 32 bits | 6 | S | Low | High/Medium (READ) | STANDING |
| RIPTOPL-164 | ps2link exception handler overruns its own buffer and can `strlen(NULL)` — in the crash handler itself | 6 | S | Low | High (READ) | REVISED (full verification — WEAKENED: the strlen(NULL) crash, the guaranteed 4-byte static overwrite and the 136-byte frame over-read stand; the name-copy overrun is length-dependent (only for module names over 123 bytes) — the filed “≥13 + len” minimum is wrong, since the memcpy cursor advances by words) |
| RIPTOPL-165 | ps2link `pkoSendSifCmd` copies up to 4 bytes past `rpc_data[1024]` on a full-size command packet | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-166 | ps2link `pkoExecIop` walks argument strings with a network-supplied `argc` and no bound | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-167 | ps2link `pko_read_file` trusts the peer's `nbytes` over the caller's buffer size | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-168 | ziso.py: decompression trusts the ZSO header — block size, alignment and index length are unvalidated | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-169 | Volume-index guards use `>` instead of `>=` (and miss negatives), admitting a one-past-the-array access | 6 | S | Low | High/Med (READ; INFERRED) | STANDING |
| RIPTOPL-170 | `fs_ioctl2` `USBMASS_IOCTL_GET_LBA` dereferences a NULL block device — the one sibling case the in-file fix missed | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-171 | BDM VMC exports dereference `g_bd` with no NULL check — the only unguarded `g_bd` uses in the file | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-172 | iLinkTrFree / iLinkGetNodeTrSpeed / iLinkSetNodeTrSpeed index TransactionContexts with no range check — in both copies | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-173 | imgdrv's `read_fs` has no offset and no bound against the image size it serves | 6 | S | Low | Mechanism High (READ); multi-chunk/overs | STANDING |
| RIPTOPL-174 | System-data icon.sys is written 1776 bytes from a 964-byte icon array | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-175 | `readFileBuffer` memcpy's into an unchecked `malloc` on the language-file path | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-176 | Theme-element initialisers dereference unchecked allocations throughout themeelems.cpp | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-177 | `apaJournalRestore` dereferences a possibly-NULL cache allocation | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-178 | MBR/GPT connect paths accept a zero/short sector read as success and parse the scratch buffer anyway | 6 | S | Low | Med (INFERRED) | STANDING |
| RIPTOPL-179 | The unplug NULL-priv guard covers scsi warmup commands but not `scsi_cmd_rw_sector` or the read/write chunk loops | 6 | S | Low | Medium (READ; INFERRED in part) | STANDING |
| RIPTOPL-180 | UDPBD takes its block-device geometry from the INFO reply with no sanity check | 6 | S | Low | Med (READ; INFERRED in part) | STANDING |
| RIPTOPL-181 | opl2iso takes the output filename from raw ul.cfg bytes — a name containing `/` or `..` writes outside the CD/DVD folder | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-182 | A 32-character game name is stored unterminated in ul.cfg, and the duplicate check then compares past the field | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-183 | iso2opl builds every output path with `sprintf` into 256-byte buffers from an unbounded drive argument | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-184 | Assault BuildConfigurationROM publishes an uninitialized VendorID quadlet | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-185 | Three MMCE command builders transmit uninitialised stack bytes as packet padding | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-186 | iremsndpatch rewrites a module found by numeric ID alone — no identity or size check before eleven fixed-offset writes | 6 | S | Low | Mechanism High (READ); how ee_core deriv | STANDING |
| RIPTOPL-187 | ds34 EE clients copy `rpcbuf` to the caller even when the RPC failed | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-188 | RetroGEM GameID reader seeks to disc-supplied LBAs with 32-bit offset arithmetic and no bound against the image size | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-189 | ratls compares HTTP transfer/content token values case-sensitively, while header names are matched case-insensitively | 6 | S | Low | Med (READ; INFERRED in part) | STANDING |
| RIPTOPL-190 | Partition notification dereferences `strchr(gOPLPart, ':') + 1` with no NULL check | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-191 | lngGetFilePath indexes languages[langID-1] with no range check | 6 | S | Low | Med (READ; INFERRED) | STANDING |
| RIPTOPL-192 | usbd (inherited PS2SDK): the isochronous halted-endpoint cleanup clears the wrong TD→request LUT slot | 6 | S | Low | High/Low (READ) | STANDING |
| RIPTOPL-193 | usbd (inherited PS2SDK): initialisation failures are swallowed at every level, and the main pool allocation is never NULL-checked | 6/8 | S | Low | High (READ) | STANDING |
| RIPTOPL-194 | `isofs_ReadSect` computes the byte offset in 32 bits — directory extents past 4 GiB wrap | 6 | S | Low | Med (READ; INFERRED in part) | STANDING |
| RIPTOPL-195 | http_conformance.py reads response bodies with no size bound | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-196 | ps2link naplink handler uses the RPC payload as a `printf` format string | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-197 | diaShowKeyb's caret and backspace operate on bytes, corrupting UTF-8 text | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-198 | apemodpatch patches executable code but leaves its `FlushIcache()` commented out — its sibling patch flushes | 6 | S | Low | Medium (READ; INFERRED in part) | STANDING |
| RIPTOPL-199 | genvmc prints usage on a wrong argument count and then dereferences the missing arguments anyway | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-200 | ziso.py: argument validation lets `-c` be omitted and `-b 0` through, both crash | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-201 | MX4SIO multi-block write: the CMD55 and ACMD23 results are assigned and immediately overwritten, never tested | 3/6 | S | Low | High (READ) | STANDING |
| RIPTOPL-202 | Plasma texture allocation is never checked, but draw() writes through it unconditionally | 6 | S | Low | Med (READ; INFERRED) | STANDING |
| RIPTOPL-203 | ziso.py: corrupt LZ4 block can hang decompression forever, and the trim-loop can "decode" garbage | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-204 | ziso.py: compression silently discards a trailing partial block | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-205 | HDD `DeviceInit` retries the APA-header DMA forever — the one unbounded init wait in a directory where every sibling wait is bounded on purpose | 5 | S | Low | High (READ) | STANDING |
| RIPTOPL-206 | `cdrom_read` retries a failed `sceCdRead` forever, in all three phases, while holding the I/O semaphore | 5 | S | Low | High (READ) | STANDING |
| RIPTOPL-207 | ps2link `pko_recv_bytes` spins forever when the peer closes the connection mid-packet | 5 | S | Low | High (READ) | STANDING |
| RIPTOPL-208 | igrmbox `mbSendEE` busy-waits on SIF DMA with no timeout, on the only mailbox thread | 5 | S | Low | Mechanism High (READ); that a DMA can we | STANDING |
| RIPTOPL-209 | smb_Disconnect drains the socket with an unbounded blocking recv loop | 5 | S | Low | High (READ) | STANDING |
| RIPTOPL-210 | cdvdfsv's `sysmemSendEE` busy-spins twice with no yield and no bound — the pattern streaming.c was fixed for, one module over | 5 | S | Low | High (READ) | STANDING |
| RIPTOPL-211 | VMC save delete frees at most 64 file chains; the rest leak on the card forever | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-212 | A failed journal replay is reported as success — and the journal is erased anyway | 6 | S | Low–Med | High (READ) | STANDING |
| RIPTOPL-213 | APA cache flush clears the dirty flag and drops errors on failed header writes | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-214 | APPS scan requires `d_type == DT_DIR` exactly — the failure mode themes.cpp already documented and fixed for MMCE | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-215 | Remove settings leaves the Neutrino and Ember per-game keys behind | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-216 | VMC group table: two groups can never be returned, 8 title IDs can never match, 5 IDs are duplicated inside their own group | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-217 | padmacro keeps its edge-detection state in one global shared by all pads, so two-pad use flickers toggles | 6 | M | Med | Mechanism READ; poll interleaving INFERR | STANDING |
| RIPTOPL-218 | udptty's `tty_write` always returns 0 — the write contract is broken and send failures are invisible | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-219 | opl2iso's copy loop spins forever on a read error | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-220 | History eviction compares against a stale timestamp and can evict the wrong record | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-221 | IoQueue's per-type pending counters are never reset, and termination cleanup frees requests without decrementing them | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-222 | `apaCacheInit` leaks the header block when the second allocation fails | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-223 | Non-IOP `apaGetTime` converts to "JST" with the wrong sign (host/test builds only) | 6 | S | Low | High/Low (READ) | STANDING |
| RIPTOPL-224 | HDPro leg of the ATA set-transfer-mode ioctl reports success and does nothing (parent-read) | 8 | S | Low | High/Med (READ; INFERRED) | STANDING |
| RIPTOPL-225 | The `use_alarm` setting is honoured by the SIO2 receive paths and ignored by every transmit path | 8 | S | Low | High (READ) | STANDING |
| RIPTOPL-226 | HTTP catalog parser allocates the 2,048-row cap (~0.9 MB) for every catalog, however small | 4 | S–M | Low | High (READ) | STANDING |
| RIPTOPL-227 | XeRAbora parse allocates the 1,024-entry cap (~232 KB) on every fetch, on top of the resident previous list and the 512 KB document | 4 | M | Med | Med (READ; INFERRED in part) | STANDING |
| RIPTOPL-228 | ArtIndex retains cap-sized allocations (48 KB per directory) however few entries the directory holds | 4 | S | Low | High (READ) | STANDING |
| RIPTOPL-229 | Glyph-cache pages are allocated from the raw codepoint, before the face is ever asked if it has the glyph | 4 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-230 | diagSave keeps a second, permanent 16 KB copy of the whole diagnostic ring | 4 | S | Low | High (READ) | STANDING |
| RIPTOPL-231 | `load_cheats` reads a `.cht` file of any size into RAM whole, opting out of the cap its own reader provides | 4 | S | Low | High (READ) | STANDING |
| RIPTOPL-232 | `USBA_crc32` rebuilds its constant CRC table on every call, and the table is 4× oversized | 5 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-233 | Settings dialogs re-run the full fit-gap layout search — including text wrapping — on every frame | 5 | M | Low–Med | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-234 | Boot-dir resolver re-opens the boot ELF and boot folder on every slot, every 100 ms, for the whole budget | 5 | M | Med | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-235 | filemgr: `fmChildren` re-reads the whole directory from scratch at every capacity growth | 5 | M | Med | High/Med (READ) | STANDING |
| RIPTOPL-236 | filemgr: `fmRemove` applies the memory-card 4-try retry (with 50 ms pauses) to every device | 5 | S | Low | High (READ) | STANDING |
| RIPTOPL-237 | Grid drawing re-walks the whole submenu list every frame just to learn the count and the selected index | 5 | M | Med | High (READ; INFERRED) | STANDING |
| RIPTOPL-238 | ps1DropTwins recomputes the Ember rows' twin keys once per VCD row | 5 | S | Low | High/Low (READ; INFERRED) | STANDING |
| RIPTOPL-239 | cheatConfigLoadSelections re-normalizes both cheat names for every (saved × cheat) pair | 5 | S | Low | Medium (READ; INFERRED in part) | STANDING |
| RIPTOPL-240 | CIS dump formats hex dumps and text decodes for a trace callback that is a no-op at the only production call site | 4 | M | Low–Med | High (READ) | STANDING |
| RIPTOPL-241 | A register-sampling diagnostic (`pcdiag_cf_probe`) runs on every production start, acting only as a gate | 8 | M | Med | High/Med (READ; INFERRED) | STANDING |
| RIPTOPL-242 | deinit() and deinitEx() are the same ~85-line teardown written twice | 2 | M | Med | High (READ) | STANDING |
| RIPTOPL-243 | Two ministack implementations are maintained in parallel: smap_udpbd's monolith vs udpfs_ministack's split files | 2 | L | Med | High (READ) | STANDING |
| RIPTOPL-244 | The two ds34 EE client libraries are one library written twice | 2 | M | Med | High (READ) | STANDING |
| RIPTOPL-245 | Two bespoke TOML scanners in one file, with divergent rules for the same grammar | 2 | L | High | High (READ) | STANDING |
| RIPTOPL-246 | MD4 and the LM/NTLM auth helpers exist as two divergent copies (smbinit vs smbman-ra) | 2 | M | Med | High (READ) | STANDING |
| RIPTOPL-247 | tar.cpp's four find functions are one lookup written four times | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-248 | vmc_groups: 97 hand-written `count_*` variables are the boilerplate that already produced one out-of-bounds walk | 2/3 | S | Low | High (READ) | STANDING |
| RIPTOPL-249 | `bd_defrag_read` and `bd_defrag_write` are the same 45-line traversal pasted twice | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-250 | Streaming ring-buffer drain is written twice: `ReadSectors` (memcpy) and `ReadSectorsEE` (SIF DMA) are one algorithm with two bodies | 2 | M | Medium | High (READ) | STANDING |
| RIPTOPL-251 | The bounded "poll identity until budget expires" loop is written three times in bdmboot.cpp | 2 | M | Med | High (READ) | STANDING |
| RIPTOPL-252 | ranet: the "RAA1 OK" reply-header parse is implemented twice, with a third partial re-parse beside one copy | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-253 | The MMCE candidate-slot scan is written twice in one file | 2 | S | Med | High (READ) | STANDING |
| RIPTOPL-254 | ratls_ps2: `raHttpsGet` and `raHttpsDownload` duplicate the whole DNS → socket → connect → deadline preamble | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-255 | The MX4SIO/MMCE quiesce block is copy-pasted verbatim in both PS1 launch legs | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-256 | Two near-identical icon+caption draw functions in uidraw.cpp | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-257 | cacheGetTextureEx repeats its ~20-line in-flight request adoption block verbatim | 2 | S | Med | High (READ) | STANDING |
| RIPTOPL-258 | Apps linked-list node allocation is copy-pasted twice, and its if/else collapses to a plain prepend | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-259 | Two hand-copied 8-digit hex parsers for module-load arguments already disagree (lowercase) | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-260 | The `__RTL` renderString is a second, ~150-line text renderer that the live build can never select | 1 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-261 | SMB1 `smb_ReadAndX` carries a permanently dead second receive implementation (`USE_CUSTOM_RECV` is unconditionally defined), plus the `rhdrlen` plumbing that only it used | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-262 | BDM device computes `g_bd_sectors_per_sector` on every attach and never reads it — disc reads hardcode ×4 (512-byte sectors) instead | 1 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-263 | `mmce_sio2_rx_dma` (66 lines) has no caller anywhere in the tree — dead code in RiptOPL | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-264 | CRC7 "RAM table" mode is unreachable: both preprocessor tests use a macro name that does not exist, so the config's selected mode silently isn't | 1/8 | S | Low | High (READ) | STANDING |
| RIPTOPL-265 | dev9.c's PCMCIA probe trio (~55 lines) is behind a plain `DEBUG` define that no in-repo build of this module ever sets | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-266 | tools/lang_decompiler.py is dead: no caller, no docs, no test, and it runs on import | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-267 | ziso.py: dead code and a dead option inside the live tool | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-268 | ~90 lines of commented-out POSIX implementations are kept beside the stdio ones in the PC tools | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-269 | Dead disc-probe constants copied into both split files; the only live copy is in sysdisc.cpp | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-270 | imgdrv carries dead code: an unused `dummy_fs` and two unused private device-struct typedefs duplicating the SDK's | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-271 | poll.c's invalid-fd tracking is dead: `ifd` is never set, so POLLNVAL can never be returned | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-272 | textures: staged-open diagnostic latch for an already-superseded hypothesis is permanent production code | 8 | S | Low | Med (READ) | STANDING |
| RIPTOPL-273 | sfxGetDropDiag() is a stub that always reports zero drops, while the debug HUD presents its counters as a live instrument | 8 | S | Low | High (READ) | STANDING |
| RIPTOPL-274 | Dead dialog read-back block at the end of the Compatibility dialog | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-275 | `GetModStorageLocation` takes a `compatFlags` parameter it never uses | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-276 | tools/syntax_sweep.py is not run by anything and cannot fail if it is | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-277 | tools/make_save_icon.py's `--check` mode is never invoked; the generator is referenced nowhere | 7 | S | Low | Med (READ) | STANDING |
| RIPTOPL-278 | `test_ministack_xchg` is the one udpfs host test whose checks all vanish under `-DNDEBUG` — including a side-effecting `assert` | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-279 | test_catalog's de-duplication memory silently stops at 512 unique startups | 8 | S | Low | High (READ; INFERRED) | STANDING |
| RIPTOPL-280 | test_settings snapshots the settings table into fixed 200-entry arrays with no bound check | 8 | S | Low | High (READ) | STANDING |
| RIPTOPL-281 | GSHandler REGIMM decode masks 0x3F into a 32-entry table — odd `rs` jumps out of bounds | 6 | S | Low | High (INFERRED) | STANDING |
| RIPTOPL-282 | `mips_memcpy` return value overwritten by `mips_memset`'s first instruction in its delay slot — all 4 copies | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-283 | `Hook_ExecPS2` clobbers callee-saved $s0–$s3 on paths that tail-call the return-capable original | 6 | S | Low–Medium | Medium (READ; INFERRED in part) | STANDING |
| RIPTOPL-284 | `dve_set_reg` always returns 0 — `dve_prepare_bus` retry loop can never repeat | 6 | S | Low | High/Low (READ) | STANDING |
| RIPTOPL-285 | Dead exports: 2 dangling `.globl`s with no definition anywhere + 2 defined exports with zero references | 1 | S | Low | High | STANDING |
| RIPTOPL-286 | Shipped PSU verified only by its author's mirror-image checker; the independent PSUManager cross-checker is never invoked (and generated credits claim it is) | 7 | — | — | READ | STANDING |
| RIPTOPL-287 | Four release scripts dead at pin while their headers + Makefile still present them as the live release path | 8 | — | — | READ | STANDING |
| RIPTOPL-288 | `normalize_release_notes.py` is test-only; shipped notes come from a second, duplicated renderer | 8 | — | — | READ | STANDING |
| RIPTOPL-289 | `build_rolling_extras.sh` variant/debug loops can move a stale `opl.elf` into a release dir (latent; file dead per -287) | 7 | — | — | READ; INFERRED in part | STANDING |
| RIPTOPL-290 | `tools/run_tests.sh` silently SKIPs site/wiki suites when `bs4` absent; the invoking job installs nothing | 8 | — | — | READ | STANDING |
| RIPTOPL-291 | Compiler-absence skip-to-pass in three suites (conditional vacuous passes) | 8 | — | — | READ | REVISED (R8 — formally extended: 10 further skip-to-pass instances in 9 files; fix shape unchanged, coverage extended) |
| RIPTOPL-292 | README says menu vibration is on by default; the fresh-start default is Off | 8 | — | — | — | STANDING |
| RIPTOPL-293 | ROLLING_RELEASE download contract names ZIPs unversioned; every published archive carries `-<version>` | 8 | — | — | — | STANDING |
| RIPTOPL-294 | README collapses the Neutrino picker's three distinct 1080i modes into a nonexistent single "1080i" | 8 | — | — | — | STANDING |
| RIPTOPL-295 | BUILD-CONFIGURATIONS says the publisher refuses ELFs not starting 0x80 in; it accepts the LLD 0x100 start | 8 | — | — | — | STANDING |
| RIPTOPL-296 | The APA raw-namespace scan never sees a C++ source, so the policy it pins is unenforced where the code lives | 6 | M | Med | High (READ) | STANDING |
| RIPTOPL-297 | test_audio_threads Part 1 scans only `*.c` after the C++ migration: the `audsrv_wait_audio()` ban is unenforced in all 115 `.cpp` files | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-298 | test_bdm_partitions asserts GPT partitions far beyond the device mount successfully, encoding RIPTOPL-160's missing extent validation as correct | 6 | S | Low | High/Med (READ; INFERRED) | STANDING |
| RIPTOPL-299 | test_ratls_host.py only ever sends lowercase HTTP tokens, so the RIPTOPL-189 case-sensitive token defect passes the suite | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-300 | Neither ps2cnf host test exercises the ≥64-char BOOT2 value that RIPTOPL-158 flags, so the unterminated-string path has no regression test | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-301 | Release-publication test ends with a self-referential assertion: the "remote unchanged" check cannot fail on values | 6 | S | Low | High (READ) | REVISED (R8 — narrowing recorded in the finding: round 7’s “no self-comparisons” corpus negative is narrowed — the dict-literal self-reference shape was outside the round-7 scan; the round-7 claim stands for the patterns it scanned) |
| RIPTOPL-302 | test_release_editions.py:28 can never fail: it membership-tests a dict of target names | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-303 | test_mbedtls_vendor swallows ValueError for whole edition/configuration combinations, uncounted | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-304 | test_game_type_labels.py's "functional harness" tests a private re-implementation, not the production code, with constants that contradict the production enums | 2 | M | Low | High (READ) | STANDING |
| RIPTOPL-305 | PS1 id-keyed art scenarios run against a simplified in-harness model of `ImageCache` and `cacheGetTextureEx`; the production methods in `artload.cpp` are never executed | 2 | M | Med | High (READ) | STANDING |
| RIPTOPL-306 | The keyboard test's exhaustive bold-offset loop tests its own Python copy, not the production function | 2 | M | Low | High (READ) | STANDING |
| RIPTOPL-307 | test_ripps2_drive_status.py tests a re-typed copy of the drive-size arithmetic, not the production expression | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-308 | Save-icons harness exit code is discarded: a post-print crash or non-zero exit passes | 6 | S | Low | Med (READ; INFERRED in part) | REVISED (verification — WEAKENED: post-print crash scenario defeated by stdio pipe buffering (executed); survives only for a clean non-zero exit after flush) |
| RIPTOPL-309 | test_patch_zone_restore: the sbPrepare harness's exit code is never checked; its second half is verified only by C `assert()`s whose failure reaches Python only as a stdout side-effect | 7 | S | Low | High/Med (READ; INFERRED) | STANDING |
| RIPTOPL-310 | Two suites have Python sections gated only by bare `assert`: they vanish, with their "ok" prints intact, under `python3 -O` / `PYTHONOPTIMIZE` | 6 | S | Low | High (READ; INFERRED) | STANDING |
| RIPTOPL-311 | `check_frames` in test_dialog_gui_lock.py scans each dialog file as one linear stream, so an unbalanced lock in one function can mask a missing lock in a later one | 6 | S | Low | Med (READ; INFERRED in part) | STANDING |
| RIPTOPL-312 | test_mmceman_fork.py's provenance claim covers the whole vendored tree; the check hashes 2 of its ~15 files — and the one file that changed at the pin bump is not among them | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-313 | The corpus's function-extraction and compile/run helpers exist in 100+ divergent copies; only one extractor in the corpus is comment-aware | 2 | L | Low | High (READ) | STANDING |
| RIPTOPL-314 | The two i.LINK reset suites are one ~340-line harness stored twice, and the copies have already drifted | 2 | M | Low | High (READ) | STANDING |
| RIPTOPL-315 | `test_pad_mode_lock.py` and `test_pad_missed_read.py` each carry a full copy of the pad extraction, libpad stub and simulated-pad scaffolding | 2 | M | Low | High (READ) | STANDING |
| RIPTOPL-316 | test_udpfs_network_hardening largely re-asserts, at string level, what test_network_parity_922 already proves by compiling | 2 | M | Low | High (READ) | STANDING |
| RIPTOPL-317 | The FatFs disk-image fixture is duplicated almost verbatim between the VMC and Ember image tests | 2 | M | Low | High (READ) | STANDING |
| RIPTOPL-318 | Install_IGR / IGR_RequestReset installation behaviour is asserted twice, in test_igr_polling.py and test_igr_menu_no_room.py, against two different stub universes | 2 | S | Low | Med (READ) | STANDING |
| RIPTOPL-319 | The nine-name BDM latch list is written twice in one file, so the text check and the executable check can drift apart | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-320 | Boot-theme splash assertions duplicated between test_yaopl_ripps2_b125_ports and test_boot_theme_wait | 2 | S | Low | High (READ) | STANDING |
| RIPTOPL-321 | Dead dual-layout (pre-C++ tree) fallbacks referencing files absent at the pin, in fourteen ported tests | 1 | M | Low | High/Med (READ) | STANDING |
| RIPTOPL-322 | Dead test helpers: `strip_comments` and `function_body` in the SMB2 logon parity suite are defined and never called | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-323 | test_mx4sio_retry.py runs the whole test_mx4sio_write_acceptance.py suite as its last step, so ps2build executes the acceptance suite twice | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-324 | `test_bdm_scan_retry.py` runs twice in one workflow (and a third time in the other CI workflow) | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-325 | Ten harness-execution call sites in nine suites run their compiled harness with no timeout, so a hung harness hangs the CI job instead of failing | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-326 | Undocumented sys.argv source overrides in seven tests silently substitute non-pin code | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-327 | test_io_queue_trims: the deferred-update harness macro-aliases `ioPutRequest` to `ioPutRequestUnlessWaiting`, so the APPS call site in `menuDeferredUpdate` cannot regress to the un-coalesced spelling without failing anything | 7 | S | Low | High/Med (READ; INFERRED) | STANDING |
| RIPTOPL-328 | test_hires_thread_priority exercises only rows 6–11 as "the multi-pass ones"; the four appended multi-pass rows (16–19) get no coverage in the test at all | 8 | S | Low | High (READ) | STANDING |
| RIPTOPL-329 | NUM_RM_VMODES is hard-coded as 20 in two renderman tests while the third extracts it from the source | 2 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-330 | test_ilink_sbp2_completion.py hard-codes the production login budget and carries a dead placeholder replace | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-331 | test_catalog_limits.py hard-codes HTTP_STREAM_ERR_TRUNC as -7 instead of extracting it like every other production constant it uses | 8 | S | Low | High (READ) | STANDING |
| RIPTOPL-332 | Assertions inside possibly-empty iteration, with no count guard, in two tests | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-333 | test_about_credits_layout.py prints PASS for trimmed UI_BREAK rows and a kept row count, but never counts either | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-334 | test_sfx_oneshot_cut.py's coalesce assertion can be satisfied by the comment inside the captured branch alone | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-335 | test_pad_pattern_bounds.py's only ASan-isolated overread case is gated on an argument no CI invocation ever passes | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-336 | test_audit_translations.py exercises only one of the tool's two --strict error classes; the unknown-overlay-label error is untested by the tool's only test | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-337 | test_conformance.py locks in the empty-catalog run as a clean pass with "0 skipped", although the run skips every range check | 8 | S | Low | High/Med (READ) | STANDING |
| RIPTOPL-338 | `test_pops_udpfs.py` can only run if the gitignored `build/` directory already exists | 7 | S | Low | High/Med (READ; INFERRED) | STANDING |
| RIPTOPL-339 | Four tests create and use an in-tree build/test-tmp directory instead of the system temp dir | 7 | S | Low | Med (READ; INFERRED in part) | STANDING |
| RIPTOPL-340 | test_smb1_vmc_share is the corpus's only cwd-relative test (in its batch, grep-verified) | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-341 | test_neutrino_bsdfs success message claims 28 preflight scenarios; the harness runs 30 | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-342 | test_mbedtls_vendor's docstring still says five pinned roots; seven are pinned and asserted | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-343 | Production `ra_watch.h` header comment is stale: it says the raudp header is 162 bytes; the field table sums to 184 (the fixture is right) | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-344 | `CNFGetKey` can return an unterminated 64-byte buffer — caller scans past its stack buffer on crafted SYSTEM.CNF | 6 | S | Low | High (READ; INFERRED in part) | CROSS-REF (→ RIPTOPL-158 — full duplicate, census D-1; verification phase 2026-11-14) |
| RIPTOPL-345 | Six headers have no include guard — incl. the shared `modules.h` contract header (double inclusion is a proven hard error) | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-346 | Stub `thsemap.h` (browse copy): `DeleteSema` sits outside its own include guard; the two stub copies have diverged | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-347 | `tests/host/check.h`: `CHECK_STR` uses `strcmp` but the header never includes `<string.h>` | 7 | S | Low | High | STANDING |
| RIPTOPL-348 | `raVcdBootName()` free API is dead — wrapper and the `RaHash` method behind it have no caller | 1 | S | Low | High | WITHDRAWN (full verification phase 2026-11-14 — REFUTED: test_ra_ps1.py:137 generates the raVcdBootName calls into a compiled, executed harness) |
| RIPTOPL-349 | `guiGameHandleDeferedIO` is defined and declared but never called | 1 | S | Low | High | STANDING |
| RIPTOPL-350 | `NetSupport::netifLinkStatus()` is a dead declaration — never defined, never called | 1 | S | Low | High | STANDING |
| RIPTOPL-351 | `Remove_Padhook` — declared, never defined, never called | 1 | S | Low | High | STANDING |
| RIPTOPL-352 | `igrovl.h` — dead forward declaration of a struct tag that does not exist | 1 | S | Low | High | STANDING |
| RIPTOPL-353 | Dead lite-build gates: `LITE_HAS_TCPIP` and `LITE_DEVICE_NAME` are consumed nowhere | 1 | S | Low | High | STANDING |
| RIPTOPL-354 | `BG_REQUEST_EXTRA_IDLE_FRAMES` is a dead constant whose described mechanism does not exist | 1 | S | Low | High | STANDING |
| RIPTOPL-355 | `CONFIG_OPL_ENABLE_ANALOG_NAV` — config key macro for a deliberately removed feature; zero readers | 1 | S | Low | High | STANDING |
| RIPTOPL-356 | `CHEAT_VERSION` value is consumed by no code (test script uses the line only as a text anchor) | 1 | S | Low | High | STANDING |
| RIPTOPL-357 | `ISO_GAME_FNAME_MAX` is a dead macro — no product-code consumer anywhere | 1 | S | Low | High | STANDING |
| RIPTOPL-358 | `APA_IOCTL2_GETHEADER` — dead APA ioctl constant; no APA ioctl2 call site exists | 1 | S | Low | High | STANDING |
| RIPTOPL-359 | `GSM_ARGS` — dead constexpr in the per-game GSM header | 1 | S | Low | High | STANDING |
| RIPTOPL-360 | `IO_ERR_UNKNOWN_REQUEST_TYPE` — error code never returned and never tested | 1 | S | Low | High | STANDING |
| RIPTOPL-361 | `HDD_LOADMODULES_STATUS_COUNT` — trailing status enumerator never used as a count or bound | 1 | S | Low | Medium/High | STANDING |
| RIPTOPL-362 | `FAV_MAGIC` comment spells the on-disk magic wrong — the bytes are "OFAF", not "OFAV" | 8 | S | Low | High | STANDING |
| RIPTOPL-363 | Stub `ps2smb.h`: `smbOpenShare_in_t` size comment contradicts the struct (520 vs 516) | 8 | S | Low | High | STANDING |
| RIPTOPL-364 | favsupport.h points readers at a source file that does not exist (`favsupport.c`) | 8 | S | Low | High | STANDING |
| RIPTOPL-365 | Orphaned contract comment attached to the wrong declaration in themes.h | 8 | S | Low | High | STANDING |
| RIPTOPL-366 | ioman.h carries an orphan doc comment for a remove-by-type function that does not exist | 1 | S | Low | High | STANDING |
| RIPTOPL-367 | Duplicate `#include <debug.h>` in opl.h | 7 | S | Low | High | STANDING |
| RIPTOPL-400 | smb_FindFirstNext2 trusts response ParamOffset/DataOffset/FileNameLen with no bounds at all | 6 | S | Low | READ | STANDING |
| RIPTOPL-401 | Negotiate response domain name is `strcpy`'d unbounded into a 64-byte field | 6 | S | Low | READ | STANDING |
| RIPTOPL-402 | ZSO decompression uses the explicitly-unsafe LZ4 "fast" decoder on a user-supplied game image, with prefix references enabled and the result unchecked | 6 | S | Low | High | STANDING |
| RIPTOPL-403 | `lwip_accept()` dereferences a NULL netconn that `err_tcp()` itself posts | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-404 | GPT scan's fallback path trusts the header's entry count unbounded: a crafted disk can make mount read sectors indefinitely | 6 | S | Low | READ | STANDING |
| RIPTOPL-405 | HDD APA header `num_partitions` is trusted past the 65-entry partition table | 6 | S | Low | READ | CROSS-REF (→ RIPTOPL-149 — full duplicate, census D-7) |
| RIPTOPL-406 | APA journal write side has no bound: more than 126 dirty cache entries overflow the static journal buffer and write journal headers past the journal area | 6 | S | Low | High (INFERRED in part) | STANDING |
| RIPTOPL-407 | USB mass-storage connect walks the endpoint descriptor chain with a device-supplied count and stride, unchecked | 6 | S | Low | High | STANDING |
| RIPTOPL-408 | Device-supplied USB sector size feeds an unchecked `alloca` and unchecked length multiplications | 6 | S | Low | High | CROSS-REF (→ RIPTOPL-163 — partial duplicate merged, census D-10) |
| RIPTOPL-409 | ps2ips `do_send()`/`do_sendto()` trust the EE-supplied `malign` field completely | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-410 | ps2ips `do_recv()`/`do_recvfrom()` accept a negative EE `length`, inverting the RA buffer-offset arithmetic | 6 | S | Low | Medium (READ) | STANDING |
| RIPTOPL-411 | HDPro `sceAtaDmaTransfer` retries a failing transfer forever, holding the ATA semaphore | 6 | S | Low | READ | CROSS-REF (→ RIPTOPL-086 — full duplicate, census D-4) |
| RIPTOPL-412 | ARP entries can never expire: `etharp_tmr()` has no caller because `LWIP_ARP` is defined nowhere | 6 | S | Low–Medium | High (READ) | STANDING |
| RIPTOPL-413 | genvmc's physical-card copy divides by, and indexes with, unchecked card-supplied superblock geometry | 6 | S | Low | High (READ) | REVISED (verification — WEAKENED: division traps stand; cluster_buf overrun only in the tail loop when pages_per_cluster × pagesize > 16400) |
| RIPTOPL-414 | NBNS receive thread copies the answer address from a fixed offset without checking the datagram is that long | 6 | S | Low | READ | STANDING |
| RIPTOPL-415 | httpclient RPC handlers use EE-supplied strings unterminated (only the streaming op terminates them) | 6 | S | Low | READ | REVISED (verification — WEAKENED: only the mtime[1] OOB indexing survives; the string half is defeated by the sole EE producer, which terminates all fields) |
| RIPTOPL-416 | `fatfs_fs_driver_get_mounted_bd_from_index` bounds check is off by one and admits negative indices | 6 | S | Low | READ; INFERRED | CROSS-REF (→ RIPTOPL-169 — full duplicate, census D-8) |
| RIPTOPL-417 | `InitializeConfigurationROM` leaks the old CROM and every extra unit, and silently drops all added units, on every `iLinkSetNodeCapabilities` call — both copies | 6/4 | S | Low | High/Medium (READ; INFERRED) | STANDING |
| RIPTOPL-418 | `iLinkFindUnit` accepts a negative `UnitInList` and indexes `NodeData[-1]` — both copies | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-419 | DEV9 callback-registration exports index their tables with unchecked (and possibly negative) indices | 6 | S | Low | READ | STANDING |
| RIPTOPL-420 | Fixed-size UDPFS replies are never length-checked; a short reply is parsed out of stale buffer contents | 6 | S | Low | High | STANDING |
| RIPTOPL-421 | `udpfs_core_get_sector_count` truncates capacity to a signed `int`: shares ≥ 1 TiB can never register as a block device | 6 | S | Low | High | REVISED (verification — WEAKENED: “never registers” holds only in the [1,2) and [3,4) TiB bands; (2,3) TiB registers undersized, exactly 2/4 TiB registers a 0-sector device) |
| RIPTOPL-422 | Both ministack RX dispatchers will call through a NULL handler for a packet addressed to port 0 | 6 | S | Low | Medium (INFERRED) | STANDING |
| RIPTOPL-423 | `do_bind()` uses lazily allocated PCBs without the NULL checks its sibling handlers have | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-424 | `copy_from_pbuf()` walks off the end of the pbuf chain when a fragment's IP length exceeds the delivered bytes | 6 | S | Low | Medium (INFERRED) | STANDING |
| RIPTOPL-425 | ICMP error replies dereference `pbuf_alloc()` results unchecked and copy from the offending packet unchecked | 6 | S | Low | High/Medium (READ) | REVISED (verification — WEAKENED: icmp_dest_unreach only; icmp_time_exceeded is compiled out — IP_FORWARD is unconditionally 0) |
| RIPTOPL-426 | Client netconns never get a semaphore, so `netconn_write()` busy-spins on `WaitSema(0)` | 5 | S | Low | High (READ) | STANDING |
| RIPTOPL-427 | DEV9 `SpdDmaTransfer` busy-waits forever for DMA completion, semaphore held | 5 | S | Low–Medium | READ | STANDING |
| RIPTOPL-428 | SCMD path: unbounded hardware-register spins, and `cdvdman_sendSCmd` always reports success | 6 | S | Low–Medium | READ | STANDING |
| RIPTOPL-429 | GPT connect returns success (0) when its scratch allocation fails, so BDM claims the device and FatFs is never tried | 6 | S | Low | READ | STANDING |
| RIPTOPL-430 | `USBMASS_DEVCTL_STOP_UNIT` and `USBMASS_DEVCTL_STOP_ALL` bodies are swapped in `fs_devctl` | 6 | S | Low | READ; INFERRED | STANDING |
| RIPTOPL-431 | FileTimeToDate converts ~half of all dates to garbage (SMB1 browse/stat timestamps) | 6 | S | Low | READ | STANDING |
| RIPTOPL-432 | usmb2_build_request drains a server-declared SPL of any size; no reply-size ceiling | 6 | S | Low | READ | STANDING |
| RIPTOPL-433 | Replies are matched to requests only when signing is on (usmb2 MessageId) or never (unfs4 xid) | 6 | S | Low | READ | STANDING |
| RIPTOPL-434 | smb2man_querydir trusts the reply's OutputBufferLength over the bytes actually delivered | 6 | S | Low | READ | STANDING |
| RIPTOPL-435 | smb_closeAll() closes FIDs but never frees the handles — stale slots leak and FIDs can be re-closed on a later session | 6 | S | Low | READ | STANDING |
| RIPTOPL-436 | USB READ CAPACITY result stored as sector count without the +1: the last sector of every USB drive is unreachable | 6 | S | Low | High | STANDING |
| RIPTOPL-437 | SMB (USBLD multipart) read past the last part returns success with the buffer untouched | 6 | S | Low | READ; INFERRED | STANDING |
| RIPTOPL-438 | `smap_udpbd` write path hardcodes 512-byte sectors and ignores the INFO-reply sector size the read path honours | 6 | S | Low | High | STANDING |
| RIPTOPL-439 | `sceCdStInit` divides by the game's `bankmax` with no validation | 6 | S | Low | READ; INFERRED | STANDING |
| RIPTOPL-440 | mcemu FastIO hooks dereference the FastIO allocation without ever checking it exists; the read hook also DMA-transfers a full cluster for a short tail | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-441 | `mmce_fs_open`/`dopen` failure exits leave `file->privdata` pointing at a still-free handle slot, which the next open then aliases | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-442 | `fs_read`/`fs_write` collapse every FatFs error to a 0 return, indistinguishable from EOF / zero-progress | 6 | S | Medium | READ | STANDING |
| RIPTOPL-443 | `smb_CloseAll`'s −1 sentinel can never be stored in the u16 FID table (all three SMB-family files) | 6 | S | Low | READ | WITHDRAWN (verification phase 2026-11-14 — REFUTED: claimed trigger defeated by the sole guarded caller; latent-only) |
| RIPTOPL-444 | smb_lseek64 accepts negative positions (SEEK_SET/SEEK_CUR check only the upper bound) | 6 | S | Low | READ | CROSS-REF (→ RIPTOPL-085 — full duplicate, census D-6) |
| RIPTOPL-445 | smb_dopen appends "\\*" to fh->name with strcat after a 255-char strncpy — overflow and unterminated-name read | 6 | S | Low | READ | CROSS-REF (→ RIPTOPL-040 — partial duplicate merged, census D-11) |
| RIPTOPL-446 | GPT parser ignores the header's `partition_entry_size` and assumes every entry is 128 bytes | 6 | S | Low | READ | STANDING |
| RIPTOPL-447 | GPT connect lacks the partition-device filter the MBR connect has, so every partition pseudo-device is re-probed as a GPT disk | 6 | S | Low | READ | STANDING |
| RIPTOPL-448 | `sceAtaSecurityEraseUnit` passes NULL as the IDENTIFY buffer; the helper writes 512 bytes to address 0 and dereferences it | 6 | S | Low | High | STANDING |
| RIPTOPL-449 | DVD TOC builder marks single-layer discs as dual-layer whenever DVDDL emulation is off | 6 | S | Medium | INFERRED | STANDING |
| RIPTOPL-450 | `cdrom_lseek` SEEK_END subtracts the offset instead of adding it | 6 | S | Low–Medium | INFERRED | STANDING |
| RIPTOPL-451 | `tcp_keepalive()` transmits a segment whose TCP flags byte is uninitialised pool memory | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-452 | `netconn_recv()`/`netconn_write()` dereference `conn->pcb.tcp` where the tree itself elsewhere guards it | 6 | S | Low | Medium | STANDING |
| RIPTOPL-453 | `smap_udpbd`'s transmit path has no link-up wait and no failure exit: `smap_transmit` retries the TX ring forever | 5/6 | S | Low–Medium | High | STANDING |
| RIPTOPL-454 | Streaming EE read busy-spins on `sceSifDmaStat` with no bound | 5 | S | Low | READ | CROSS-REF (→ RIPTOPL-045 — full duplicate, census D-3) |
| RIPTOPL-455 | igrmbox `mbSendEE` is a third copy of the filed sysmemSendEE spin pattern — with no yield at all | 2 | S | Low | READ | CROSS-REF (→ RIPTOPL-208 — full duplicate, census D-5) |
| RIPTOPL-456 | Game patch modules write fixed offsets into a target module's text with no size or version check | 6 | S | Low | READ | STANDING |
| RIPTOPL-457 | pademu `_start` reads 8 bytes of `argv[1]` with no length check | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| RIPTOPL-458 | genvmc STATUS devctl copies to the caller's buffer with none of the validation the CREATE case applies in the same switch | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-459 | smb_Connect copies the server IP with strncpy(…, 16) and no termination guarantee; two later sprintf("%s") consumers trust it | 6 | S | Low | INFERRED | REVISED (verification — WEAKENED: fires only on a malformed 16-byte non-terminated fill; no valid dotted-quad IPv4 can trigger it) |
| RIPTOPL-460 | NTLMv2 client challenge is the constant 0x01×8 and the timestamp is zero (vendored usmb2) | 6 | S | Low | READ | STANDING |
| RIPTOPL-461 | `fs_dread` can hand EE an unterminated directory name for a maximum-length (255-char) LFN | 6 | S | Low | READ | STANDING |
| RIPTOPL-462 | `bdm_get_bd` silently leaves the tail of the caller's array unwritten, and `bdm_connect_bd` silently drops devices when the mount table is full | 6 | S | Low | READ; INFERRED | REVISED (verification — WEAKENED: unwritten-tail read unreachable with the sole in-tree caller (count = 20 = MAX_CONNECTIONS); connect is not log-silent — only a failure-specific log/event and an error return are missing) |
| RIPTOPL-463 | `mstack:` exchange silently truncates an over-long reply, indistinguishable from a complete one | 6 | S | Low | High | STANDING |
| RIPTOPL-464 | `udpfs_core_close` discards the close reply entirely and always reports success | 6 | S | Low | High | STANDING |
| RIPTOPL-465 | CDVDFSV stream read returns an uninitialised error word when `sectors == 0` | 6 | S | Low | READ | STANDING |
| RIPTOPL-466 | `hookMODLOAD` uses `getModInfo`'s result without checking it — the one unhardened caller left in scope | 6 | S | Low | READ | STANDING |
| RIPTOPL-467 | `apaOpen` compares the password of a cache entry after freeing the entry | 6 | S | Low | High/Medium | STANDING |
| RIPTOPL-468 | INFERRED: SMAP capability check in both neutrino copies is mis-parenthesised (`!x & MASK`), correct only by accident of the mask's value | 6 | S | Low | Medium (INFERRED in part) | CROSS-REF (→ RIPTOPL-093 — full duplicate, census D-2) |
| RIPTOPL-469 | INFERRED: `udpfs_ministack` registers its RX callback and takes over the tty before the duplicate-load check | 6 | S | Low | Medium (INFERRED in part) | STANDING |
| RIPTOPL-470 | Eight `ps2ip` exports are an empty stub, while in-tree modules import and call them | 8 | S | Low | High (READ) | STANDING |
| RIPTOPL-471 | Typed-driver pool is never reclaimed: after 8 distinct device paths, later device types mount but are unreachable by name; `InitFS` also resets the count without unregistering | 8 | M | Medium | READ | STANDING |
| RIPTOPL-472 | The SBP-2 layer attaches up to 5 drives, the SCSI layer can only ever publish 2 — drives 3–5 are logged in and warm-up-retried as if their failure were transient — both copies | 8/5 | S–M | Medium | High/Medium (READ; INFERRED) | STANDING |
| RIPTOPL-473 | ilink `_start` ignores `GetConsoleIDs` failure and publishes a zero EUI-64 and empty model name | 6 | S | Low | High/Low (READ; INFERRED) | REVISED (verification — WEAKENED: zero-EUI-64 outcome holds only for the sceCdRI failure sub-case; on sceCdRM-only failure the GUID is already written and valid) |
| RIPTOPL-474 | Both mcemu ports share the single 512-byte page data buffer | 2/6 | S | Low | High/Medium (READ; INFERRED) | STANDING |
| RIPTOPL-475 | One global semaphore serializes all FatFs I/O on all volumes, defeating FatFs' own per-volume reentrancy | 5 | L | High | READ; INFERRED | STANDING |
| RIPTOPL-476 | APA DES password engine (~460 lines + tables) is compiled, linked and executed on every open, but its result can never matter in the shipped build | 1 | S | Low | High | STANDING |
| RIPTOPL-477 | Identical `smb_ReadCD` + `smb_CloseAll` bodies triplicated across the three protocol implementations | 2 | M | Medium | READ | STANDING |
| RIPTOPL-478 | `ioplib.c`/`ioplib.h` are byte-identical vendored copies in mmceman and mx4sio_bd, and their `sio2man_hook.c` twins differ by 3 lines | 2 | S | Low | High | STANDING |
| RIPTOPL-479 | `smap_udpbd`'s ministack carries a fully dead ARP cache: `arp_add_entry` has no caller and the RX path never learns | 1 | S | Low | High | STANDING |
| RIPTOPL-480 | Dead FHI export table and `_start` branch in `udpfs_bd` and `udpfs_ioman` reference symbols that exist nowhere | 1 | S | Low | High | STANDING |
| RIPTOPL-481 | `udprdma_inform` (server mode) and the core/transport teardown pair are dead in the shipped variants | 1 | S | Low | High/Medium | STANDING |
| RIPTOPL-482 | Dead code and build clutter: an unbuilt loopback driver, a DHCP header with no client, a RAW pool with no RAW stack, and nine header declarations with no definitions | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-483 | Vendored clients carry entry points and whole transports this build never uses (usmb2/unfs4 dead-in-build) | 1 | M | Low | READ; INFERRED | STANDING |
| RIPTOPL-484 | smb.h declares a function that does not exist and ~200 lines of never-referenced protocol constants | 1 | S | Low | READ | STANDING |
| RIPTOPL-485 | smb.h carries 44 protocol-offset defines and ~30 command defines nothing in the module references | 1 | S | Low | READ | STANDING |
| RIPTOPL-486 | The assault tree carries five build files its only Makefile never reads (244 lines) — one of them still contains the cdvdman imports the tree exists to remove | 7/2 | S | Low | High (READ) | STANDING |
| RIPTOPL-487 | Dead driver surface kept in both copies: an uncallable deinit, two phantom prototypes, four dead struct fields and a broken macro | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-488 | Dead imports in all four IOP builds in scope (15 stubs with no caller in their own module) | 1/7 | S | Low | High (READ) | STANDING |
| RIPTOPL-489 | 407-line packed IDENTIFY-device structure maintained to read exactly one field | 3 | S–M | Low | High | STANDING |
| RIPTOPL-490 | Static FIL/DIR pools are sized far beyond anything this driver can be asked to serve (128 FIL + 16 DIR in IOP BSS) | 4 | S | Medium | INFERRED | STANDING |
| RIPTOPL-491 | pccf keeps two 512-byte static scratch buffers resident forever although their lifetimes never overlap | 4 | S | Low | High (READ) | STANDING |
| RIPTOPL-492 | mx4sio's DMA command struct reserves a 1 KiB CRC table (`crc[512]`, marked FIXME in-tree) | 4 | M | Medium | Medium | REVISED (full verification — WEAKENED: crc[512] exists only under #ifdef CONFIG_USE_CRC16, which is never enabled (its only define is commented out at mx4sio.h:37) — a latent 1 KiB cost if ever enabled, not resident IOP RAM in the shipped build) |
| RIPTOPL-493 | `hdd_blkio.o` is an empty translation unit in the shipped build but is still compiled and linked | 7 | S | Low | High | STANDING |
| RIPTOPL-494 | `lz4.h` declares the full LZ4 API (~20 functions: compression, streaming, obsolete); `lz4.c` implements exactly one | 7 | S | Low | High | STANDING |
| RIPTOPL-495 | usbd public header declares two exports the module does not implement | 8 | S | Low | High | STANDING |
| RIPTOPL-496 | Multi-LUN support is plumbed but never used: max-LUN is queried, printed, and thrown away; the CBW LUN field is hardcoded 0 | 8 | S | Low | High | STANDING |
| RIPTOPL-497 | `smap_udpbd` xfer creates an event flag nothing ever waits on, and defines a FIFO-copy helper nothing calls | 1 | S | Low | High | STANDING |
| RIPTOPL-498 | `rapull`'s `rp_frame_values(read=0)` mode is dead: the parameter and its branches serve a call that never happens | 1 | S | Low | High | STANDING |
| RIPTOPL-499 | `raudp`'s discovery-elapsed counter `ra_disc_us` is written, overflow-guarded, and never read | 1 | S | Low | High | STANDING |
| RIPTOPL-500 | The korium theme-contract test is orphaned: no workflow runs it | 7 | S | Low | High | STANDING |
| RIPTOPL-501 | Glob source list compiles 36,695 lines of config-empty mbedTLS TUs in every mbedTLS build (61,273 lines in updater builds) | 5 | S | Low | High (INFERRED in part) | CROSS-REF (→ RIPTOPL-006 — full duplicate, census D-9) |
| RIPTOPL-502 | The vendor test never hashes the vendored tree: mbedTLS's "byte-for-byte" pin is unenforced | 7 | S | Low | High | STANDING |
| RIPTOPL-503 | Orbit README says one i.LINK file is replaced after staging; the packer replaces two | 8 | S | Low | High | STANDING |
| RIPTOPL-504 | Korium manifest completeness is enforced by nobody: unlisted zip entries are silently dropped | 6 | S | Low | High | STANDING |
| RIPTOPL-505 | Korium extraction directory is never cleaned: a removed asset can keep shipping from a dirty build tree | 6 | S | Low | High (INFERRED in part) | STANDING |
| RIPTOPL-506 | ps2sdk-socket's README describes the retired compat build in the present tense | 8 | S | Low | High | STANDING |
| RIPTOPL-507 | Korium README's "Korium and RetroAchievements builds" misstates which editions read the archive | 8 | S | Low | High | STANDING |
| RIPTOPL-508 | `hkdf.c` compiles under RA but nothing calls its API; only the `MBEDTLS_HKDF_C` define is load-bearing | 1 | S | Low | INFERRED | STANDING |
| RIPTOPL-509 | `mps_reader.c` compiles under RA (538 lines) with no consumer anywhere in the tree | 1 | S | Low | INFERRED | STANDING |
| RIPTOPL-510 | `third_party/ps2sdk-ppctty/irx_imports.h` is an unreferenced remnant of the removed source fallback | 1 | S | Low | High | STANDING |
| RIPTOPL-511 | Vendored mbedTLS `Makefile`/`CMakeLists.txt` (811 lines) are inert in every RiptOPL flow — recorded; retention recommended | 7 | S | Low | High | STANDING |
| RIPTOPL-512 | `udpfs_ministack`'s PS2SDK Makefile omits `ministack_xchg.o`, which its own `main.c` calls — the two build manifests disagree | 7 | S | Low | High | STANDING |
| RIPTOPL-513 | HDPro 48-bit LBA path drops the upper LBA bytes for LCYL/HCYL | 6 | S | Low | READ; INFERRED | WITHDRAWN (verification phase 2026-11-14 — REFUTED: defect absent; the prescribed fix is an identity transformation) |
| RIPTOPL-514 | CDVDFSV reports CDVDMAN version 0x223 while CDVDMAN reports 0x225 | 7 | S | Low | READ | STANDING |
| RIPTOPL-515 | prepare_path's trailing-slash scan is dead code that starts on the NUL terminator | 1 | S | Low | READ | STANDING |
| RIPTOPL-516 | TCP initial sequence numbers are trivially predictable and IP IDs are a plain counter (inherited) | 6 | — | — | High (READ) | STANDING |
| RIPTOPL-517 | `ff.c` carries a local debug divergence that the vendoring record does not list | 7 | S | Low | READ | STANDING |
| RIPTOPL-518 | Dead definitions: `mount_status` field never read or written; unused GPT GUID and attribute macros | 1 | S | Low | READ | STANDING |
| RIPTOPL-519 | `part_read` and `part_write` are near-identical copies (bounds check + debug block + forwarding) | 2 | S | Low | READ | STANDING |
| RIPTOPL-520 | FatFs is configured for OEM code page 869 (Greek 2), so non-ASCII short-name handling runs through Greek tables on a US user's disks | 3 | S | Medium | READ; INFERRED | STANDING |
| RIPTOPL-521 | `xhdd.h` declares two functions that exist nowhere in the HDD modules | 1 | S | Low | High | STANDING |
| RIPTOPL-522 | pccf carries a `time_us` clock plumbing chain that is written once and read never | 1 | S | Low | High (READ) | STANDING |
| RIPTOPL-523 | `pcdiag_ata.h` declares a diagnostic entry point, `pcdiag_ata_observe`, that was never implemented — and an unused read-limit constant beside it | 1/8 | S | Low | High (READ) | STANDING |
| RIPTOPL-524 | `modules/pccf/format.inc` is a 57-line mini-printf included by nothing | 1/7 | S | Low | High (READ) | STANDING |
| RIPTOPL-525 | `PROVENANCE.md`'s dedupe claim names a binary that does not exist, and its re-vendor count is stale | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-526 | `modules/debug/drvtif.irx` and `drvtif-ingame.irx` are the same bytes under two names | 7 | S | Low | High | STANDING |
| RIPTOPL-527 | bdmevent's `irx_imports.h` imports four libraries the module never calls | 7 | S | Low | High (READ) | STANDING |
| RIPTOPL-528 | `udpfs_fhi/ORIGIN.txt` states there is no write export; the module exports one and implements it | 7 | S | Low | High | STANDING |
| RIPTOPL-529 | RA-under-POPS is shipped with its two load-bearing unknowns still open (half-finished feature) | 8 | S | Low | High | STANDING |
| RIPTOPL-530 | Small dead items: unused macros, an unreachable duplicate table entry, a never-linked helper | 1 | S | Low | READ | REVISED (full verification — WEAKENED: the JMP-macro and dummy_fs items stand, but the atad claim halves — only ATA_C_STANDBY_IMMEDIATE is duplicated (atad.c:92); ATA_C_FLUSH_CACHE occurs once, the next entry being the distinct FLUSH_CACHE_EXT) |
| RIPTOPL-600 | Both Sectigo roots are embedded into RA builds that have no update channel and therefore contain no code that can reference them | 4 | S | Low | High (READ; INFERRED) | STANDING |
| RIPTOPL-601 | The vendored CMakeLists and its 142-line test suite are dead in this build — no CMake project, workflow, or script in RiptOPL ever builds or runs them | 7 | S | Low | High | STANDING |
| RIPTOPL-602 | `hddFormat` reads a cache entry's sector after freeing the entry (second instance of the RIPTOPL-467 pattern) | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-603 | smb_open stores an unterminated name with a full-size strncpy count | 6 | S | Low | High (READ; INFERRED) | STANDING |
| RIPTOPL-604 | mmce_fs SET_GAMEID devctl case dereferences `arg` unchecked | 6 | S | Low | High (READ) | STANDING |
| RIPTOPL-605 | tools/assets.py comment asserts the opposite of the RA anchor table it annotates | 7 | S | Low | High (READ) | STANDING |

### 2.2 Launchstation — 223 items

| ID | Title | Cat | Effort | Risk | Confidence | Status |
|---|---|---|---|---|---|---|
| LAUNCHSTATION-001 | All nine languages are compiled into the ELF | 4 | M | Med | High (READ) | STANDING |
| LAUNCHSTATION-002 | Three pre-rasterised font families × three sizes = 585,728 bytes of pixel data in .rodata | 4 | M | Med | High (READ) | STANDING |
| LAUNCHSTATION-003 | Legacy PS2SDK-v1.0 network stack is a second, parallel TCP/IP stack kept for one config flag | 2/8 | M | Med | High (READ) | STANDING |
| LAUNCHSTATION-004 | Native Google Drive "cloud" subsystem (HTTP + TLS + OAuth + QR) is built into every ELF | 8/4 | L | High | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-005 | SMB1 client (smbman) duplicates the SMB2/3 client (smb2man) | 2 | M | Med | High (READ) | STANDING |
| LAUNCHSTATION-006 | A full libsmb2-based SMB *server* (smbd) is embedded alongside the FTP server, host server and NetFS | 8/2 | M | Med | High (READ) | STANDING |
| LAUNCHSTATION-007 | Exploit installer + KELF signer + ~148 KB of exploit payloads ship in the everyday launcher | 8 | L | Med | High (READ) | STANDING |
| LAUNCHSTATION-008 | docs-site carries 17.4 MB of media in the repo, including the same demos as both GIF and MP4 | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-009 | 213 Python "tests" (31,353 lines) mostly scrape C source as text; CI runs 212 of them in the build job | 7/3 | M | Low | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-010 | CI builds the entire project twice for the DS34 variant; DS34 code is dead in the default build | 7/1 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-011 | Two complete UI sound themes are both embedded | 4 | S | Low | High (READ) | REVISED (full verification — WEAKENED: both themes are embedded, but the embedded total is 215,856 B, not 359,840 B (that figure includes the unembedded boot.adp of LAUNCHSTATION-013); deleting one theme saves at most 141,936 B, not ~180 KB) |
| LAUNCHSTATION-012 | Legacy 8×16 font (font_uLE) is a third text path beside the dashboard font system | 2 | L | Med | Med (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-013 | Dead media assets: bgm.ogg (462 KB) and res/sfx/boot.adp (144 KB) are neither embedded nor packaged | 1/7 | S | Low | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-014 | Busy-wait spin loops burn the EE and freeze the UI for up to 1.5 s | 5 | M | Low | High (READ) | STANDING |
| LAUNCHSTATION-015 | sprintf/strcpy/strcat are pervasive (863 grep hits), including the config-save chain | 6 | M | Low | High (READ; INFERRED in part) | REVISED (full verification — WEAKENED: the 863-hit unsafe-string count and cited chains stand, but the concrete config-save heap overflow is not reachable as stated — every %s argument is a fixed-size SETTING array and the +8,192 B reserve covers the format overhead; survives as unbounded-API hygiene / defence-in-depth) |
| LAUNCHSTATION-016 | Unchecked genRead/genWrite returns on file and font data | 6 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-017 | Self-update holds a whole second ELF in RAM on a 32 MB machine | 4/5 | M | Med | High (READ) | REVISED (R2 — still true, changed form) |
| LAUNCHSTATION-018 | Thirteen #if 0 blocks keep dead code in IOP modules | 1 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-019 | Stale precompiled udpfs_smap.irx is superseded by the source-built target | 1/7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-020 | Unused exploit payloads: IOPRP.IMG and XSYSTEM2.XLF | 1 | S | Low | Med (INFERRED) | STANDING |
| LAUNCHSTATION-021 | Byte-identical duplicate files across the tree | 2/7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-022 | res/icons/*.png (16 files) are not used by the icon system | 1 | S | Low | Med (INFERRED) | STANDING |
| LAUNCHSTATION-023 | Branch and tag clutter: 104 remote branches, 140 tags (88 build-*) | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-024 | Two settings systems run in parallel: classic CNF (config.c) and the dashboard store (dash_store.c) | 2/3 | L | High | Med (READ; INFERRED in part) | REVISED (full verification — WEAKENED: two persistence systems coexist and the 4,096-line settings UI edits both, but they deliberately write disjoint files (dash_store.c:5-9 never modifies LAUNCHSTATION.CNF) — the claimed overlapping writes are not shown; a consolidation opportunity, not a demonstrated divergence bug) |
| LAUNCHSTATION-025 | Development-only code paths compiled into production sources | 1 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-026 | Three external-launcher integrations (PopStarter, Ember, Neutrino) each carry their own game-ID / path / launch stack | 2/8 | L | Med | Low (INFERRED) | STANDING |
| LAUNCHSTATION-027 | Six workflows, including a download-counter running 8× a day | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-028 | Stale planning/audit documents are kept as if current | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-029 | __Headers APA samples and ship/ shortcut .url files are release-kit clutter in the source repo | 7 | S | Low | Med (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-030 | Dashboard font system allocates a 512 KB scratch texture arena | 4 | S | Med | Med (READ; INFERRED in part) | REVISED (full verification — WEAKENED: the memalign(128, 512×1024) at dash_font.c:80 is the SJIS/ELISA glyph atlas texture, exactly sized to its declared 512×1024 PSMT8 texture and lazily allocated — not dashboard-face scratch; the claimed ~384 KB saving does not follow) |
| LAUNCHSTATION-031 | QR generator (1,027 vendored lines) exists for one cloud-login screen | 8 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-032 | scripts/ accumulates one-off audit/migration tools beside the build scripts | 7 | S | Low | Med (READ; INFERRED in part) | REVISED (full verification — WEAKENED: of the four named scripts only stale_code_audit.sh is a genuine unreferenced one-off; audit_r3z_settings.py, check_ds34_build.py and copy_test_pack.py are live CI/test infrastructure — the deletable set is 1 file, not 3–6) |
| LAUNCHSTATION-033 | The FTP server is anonymous with full read/write/delete, by launch configuration | 6 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-034 | Self-update now overwrites the running ELF in place: no staging, no backup, no readback — one interrupted write bricks the install | 6 | M | Low | High (READ) | STANDING |
| LAUNCHSTATION-035 | ps2host's read reply trusts the host-supplied byte count into the caller's buffer | 6 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-036 | Every folder listing allocates 2,048 FILEINFO entries (~768 KB) regardless of folder size — ten allocation sites, and the dashboard browser holds two at once | 4 | M | Med | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-037 | FTP PORT command is an unvalidated FTP-bounce primitive | 6 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-038 | FTP PASV data connection accepts any host that connects first | 6 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-039 | Card tool keeps ten whole-image safety copies per card image, and re-scans the folder for every prune | 3/5 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-040 | The FTP credential path is dead code that looks like security: `-pass` can never match, `-port` is overwritten, defaults are hardcoded, and the EE never passes any of them | 1/6 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-041 | The file-based PSU extractors are dead in the shipped app — kept alive only by the host test harness — and the updater still gates on a `.BAK` name it never creates | 1 | S | Low | High (READ; INFERRED) | STANDING |
| LAUNCHSTATION-042 | nfsman and smb2man each carry their own copy of the same URL parser and connect skeleton | 2 | M | Med | High (READ) | REVISED (full verification — WEAKENED: the two URL parsers share only a ~20-line host/IP prefix plus parallel skeletons (52 vs 40 lines; tails diverge) — not near-identical ~70-line functions; the ~100+ removable-lines estimate overstates a merge) |
| LAUNCHSTATION-043 | Collect a TCP reply, match its id, bound its length is implemented three times; MD4 twice; UTF-16 conversion twice | 2 | L | Med | High (READ; INFERRED in part) | REVISED (full verification — WEAKENED: only the usmb2/unfs4 receive loops are true near-duplicates; smbman’s GetSMBServerReply matches no id at all, the two MD4 files are independent implementations, and the UTF-16 pairs convert different encodings (ASCII↔ vs UTF-8↔) — the three-way single-sourcing programme does not follow as stated) |
| LAUNCHSTATION-044 | ps2ftpd and smbman IRX targets build without `--gc-sections`, so their dead code ships in the IRX | 1/7 | S | Low | High (READ; INFERRED) | STANDING |
| LAUNCHSTATION-045 | `isHddRootPath` exists three times, with three different definitions | 2 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-046 | `getXfromRelativePath` is byte-identical in two files | 2 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-047 | Little-endian read/write helpers are copied into five memory-card files (16 copies), and the save-name rule exists twice | 2 | S | Low | High (READ) | REVISED (R3 R3-R2 — census corrected upward) |
| LAUNCHSTATION-048 | ps2host segments writes using the read-segment constant, and copies a host-supplied dirent name without forcing termination | 6/1 | S | Low | High (READ) | REVISED (full verification — WEAKENED: the write-path segment test uses the wrong constant name, but PKO_MAX_WRITE_SEGMENT and PKO_MAX_READ_SEGMENT are numerically equal (both structs 14 B → both segments 1446), so no oversize segment can be emitted today — a latent identifier typo only; the dirent half is refuted outright (net_fio.c:649 forces termination)) |
| LAUNCHSTATION-049 | Dead FTP handlers: SITE always answers 500, FEAT is declared and never implemented | 1 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-050 | One shared static 32 KB buffer serializes every FTP client | 5 | M | Med | High (READ) | STANDING |
| LAUNCHSTATION-051 | smbman's `prepare_path` does not guarantee NUL termination by construction | 6 | S | Low | Low (READ; INFERRED in part) | REVISED (R3 R3-R3 — narrowed and strengthened) |
| LAUNCHSTATION-052 | The nine-line `FILEOP_TRACE` guard block is pasted into three filer files | 2 | S | Low | High (READ) | REVISED (R3 R3-R1 — four copies, not three) |
| LAUNCHSTATION-053 | SMB READ/WRITE offsets are truncated to 32 bits before reaching the card | 6 | XS | None | High (READ) | STANDING |
| LAUNCHSTATION-054 | mmceman `SET_GAMEID`: unbounded `strcpy` into a 255-byte stack buffer, length pre-truncated through `u8` | 6 | XS | None | High (READ) | STANDING |
| LAUNCHSTATION-055 | mmceman `GET_GAMEID`: unbounded `strcpy` of a firmware-supplied string into the caller's buffer, whose length the handler never receives | 6 | S | — | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-056 | smbman's `FileTimeToDate` computes wrong calendar dates — and it is the third, divergent copy of a conversion the other two drivers do correctly | 6/2 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-057 | mmceman devctl dereferences `arg` as `u32` with no NULL/arglen check — in the same switch that already contains the correct pattern | 6 | XS | None | High (READ) | STANDING |
| LAUNCHSTATION-058 | `smb_closeAll` sends server CLOSE for directory search handles and frees no handle slots at logoff | 6 | S | Low | High/Medium (READ; INFERRED) | STANDING |
| LAUNCHSTATION-059 | smbman's `lseek64` ignores the SEEK_END offset, accepts negative positions, and the 32-bit `lseek` truncates positions past 2 GiB | 6 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-060 | smbman's read/write/dread/lseek dereference the handle without the validation its own close performs — and neither read nor write rejects a negative size | 6 | S | Low | High/Medium (READ; INFERRED) | STANDING |
| LAUNCHSTATION-061 | `SMBD_DEVCTL_START` can read past the caller's argument buffer for the password | 6 | XS | None | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-062 | `DMA_sendEE` spins forever with no timeout, called with the SMB IO lock held | 5 | M | Low | High (READ; INFERRED) | STANDING |
| LAUNCHSTATION-063 | smbman's `dread` copies a server-supplied directory name with a `strncpy` that can leave `dirent->name` unterminated | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-064 | smbd's replacement `calloc`/`malloc` do not check size arithmetic | 6/5 | XS | — | Medium (READ; INFERRED in part) | REVISED (R4 R4-R1 — downgraded to latent hardening) |
| LAUNCHSTATION-065 | `write_cmd` never caps the transfer length; `read_cmd` does | 6/2 | XS | Low | Medium (READ; INFERRED in part) | WITHDRAWN (R4 R4-R2 — refuted) |
| LAUNCHSTATION-066 | smbman's `devctl` dereferences caller buffers with no NULL or length validation — the check both sibling drivers perform first | 6 | S | Low | Medium (READ; INFERRED) | STANDING |
| LAUNCHSTATION-067 | The SMB server ships with a known, published default login | 6 | XS–S | — | High (READ) | STANDING |
| LAUNCHSTATION-068 | vmcman backing validator is off by one: `slot > MCMAN_MAXSLOT` admits `slot == MCMAN_MAXSLOT`, one entry past the array | 6/2 | XS | None | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-069 | smbman's `chdir` reads one byte before its path buffer for root/empty directory names | 6 | S | Low | Medium (READ; INFERRED) | STANDING |
| LAUNCHSTATION-070 | mmceman ships two complete source files that no target builds (581 lines, incl. a second IRX module and a second SIO2 implementation) | 1 | XS | Near zero | High (READ) | STANDING |
| LAUNCHSTATION-071 | The card-image copy+verify engine is written five times in `mc_card_export.c` | 2 | M | Med | High (READ) | STANDING |
| LAUNCHSTATION-072 | Four client-only libsmb2 files (plus one duplicate and two unused data files) are fetched and compiled for a server-only module | 1 | S | Low | Medium (READ; INFERRED in part) | REVISED (R4 R4-R3 — split; aes_reference.c struck from deletion list; full verification — WEAKENED further: of the seven proposed deletions only quic.c + smbdirect.c are proven empty/deletable (2 of 7); aes_reference.c is the server’s only AES and must stay; sync.c, smb2-share-enum.c, smb2-data-security-descriptor.c and smb2-data-reparse-point.c are UNVERIFIABLE-HERE — deletion rests on a --gc-sections link test that cannot run in this VM) |
| LAUNCHSTATION-073 | ~0.4 MB of static `.bss` serves modal screens that are closed most of the time | 4 | M | Low | High/Med (READ; INFERRED) | STANDING |
| LAUNCHSTATION-074 | `unfs4_init_context` has no caller in the nfsman IRX — a second, incompatible connect path compiled into the driver | 1 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-075 | The IOP allocator trio (`malloc`/`free`/`calloc`) is byte-identical in smb2man and nfsman | 2 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-076 | The dashboard browser sorts listings with an insertion sort that moves 384-byte structs | 5 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-077 | MMCE active-card history prune re-enumerates the folder for every generation it deletes | 5 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-078 | One dead ps2ip import: `I_lwip_shutdown` has no caller under either name | 1/7 | XS | Near zero | High (READ) | STANDING |
| LAUNCHSTATION-079 | Superblock geometry is copied into `MCDevInfo` with no validation, then used as divisors, loop bounds and buffer offsets | 6 | S | Low–Med | High (READ; INFERRED) | REVISED (verification — WEAKENED: the 336-byte superblock copy excludes cluster_size (offset 340, hard-set to 1024) and clusters_per_block (348) — those sinks are not card-driven via the copy; the pagesize/pages_per_cluster sinks hold) |
| LAUNCHSTATION-080 | `McGetFATentry`/`McSetFATentry` index `ifc_list[ifc_index]` with an unbounded `fat_index` — and card FAT values feed the same path | 6 | XS | Low | High (READ; INFERRED) | STANDING |
| LAUNCHSTATION-081 | Card-supplied entry names are still passed to `strlen`/`strcmp`/`strcpy` unterminated — the terminated-copy fix (delta D8) covered only the caller's copy | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-082 | PS1 `open`/`getstat`/`setinfo` dereference the dir-entry pointer before checking the lookup's return value | 6 | XS | Low | High (READ; INFERRED) | STANDING |
| LAUNCHSTATION-083 | `McWrite` with a negative length reaches `memcpy` as a huge `size_t` in both write paths; `McRead` is safe in both of its paths | 6 | XS | Low | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-084 | No port/slot validation on any mcman library export, although the fd exports validate fd | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-085 | VMCMAN's `MCMAN_MAXSLOT` 10 costs ≈33.8 KB of IOP statics over the physical build's 4, for slots the device layer may not address | 4 | XS | Med | High (READ; INFERRED) | REVISED (R5 settlement — proven waste, closed) |
| LAUNCHSTATION-086 | VMCMAN diagnostics print unconditionally from the `mcman_open2` create path | 5 | XS | Low | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-087 | Directory scans re-walk the FAT chain from the directory head for every entry (non-root directories) | 5 | XS | Low | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-088 | The 16-byte-chunk manual struct copy is open-coded 11 times where `memcpy` is the whole semantics | 2 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-089 | The PS1 cache write-flag bit computation `(x+1) − ((x+1) & ~7)` is open-coded 11 times | 2 | S | Low–Med | High (READ; INFERRED) | STANDING |
| LAUNCHSTATION-090 | `mmce_fs_write` returns the firmware-supplied byte count unclamped; `mmce_fs_read` clamps the identical value | 6 | XS | Minimal | High (READ) | STANDING |
| LAUNCHSTATION-091 | `scsi_warmup` accepts any non-zero sector size a device reports; absurd values break the size print's arithmetic and wrap every transfer length | 6 | XS | — | High/Medium (READ) | STANDING |
| LAUNCHSTATION-092 | `dread` copies the firmware-supplied filename length into `dirent->name` with no NUL termination and no zeroing | 6 | XS | — | Medium (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-093 | The unplug NULL-priv guard (local fix #9) covers the start-up commands but not `scsi_cmd_rw_sector` or the read/write chunk loops | 3/6 | XS | Minimal | Medium (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-094 | `dopen` stores any firmware fd except 0xff unchecked; `open` validates the same byte against `MMCE_FS_MAX_FD` | 6 | XS | Minimal | High/Low (READ) | STANDING |
| LAUNCHSTATION-095 | The `use_alarm` setting is honoured by the SIO2 receive paths and ignored by the transmit paths | 4 | S | — | High (READ) | STANDING |
| LAUNCHSTATION-096 | `mmce_sio2_rx_dma` (66 lines) has exactly one caller, and it is the unbuilt `mmcedrv.c` already filed for deletion | 1 | XS | None | High (READ) | STANDING |
| LAUNCHSTATION-097 | CNF load copies file-supplied values unbounded into fixed SETTING fields — the 64-byte Misc* fields overflow on a ~65-char line | 6 | S | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-098 | Text editor writes one row-width entry per text row into a 2,048-entry array with no bound | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-099 | `hdl_ginfo_read` strcpy's disk-controlled strings into 65- and 13-byte fields and sums subs[] for a disk-controlled nsub past the 64-entry array | 6 | S | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-100 | `usmb2_readdir` walks server-supplied directory-entry offsets with no bound against the 272-byte directory buffer | 6 | S | Low | READ; INFERRED | WITHDRAWN (full verification phase 2026-11-14 — REFUTED: usmb2_readdir sits inside the never-defined USMB2_FEATURE_OPENDIR with zero callers; the live smb2man.c directory path clamps) |
| LAUNCHSTATION-101 | Journal restore trusts the on-disk journal count and sector list completely, then erases the journal even when restore fails part-way | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-102 | The on-disk nsub field is trusted as a loop bound and array index in four places; the guards that exist check a different variable | 6 | S | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-103 | `hdl_ginfo_write` writes a sector back to disk without checking the read that filled it, and copies 128 bytes from a 65-byte name field | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-104 | `atoi()` on server-supplied Content-Length overflows before the range check | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-105 | Classic yes/no and info dialogs strcpy unbounded caller text into fixed stack buffers that several callers already exceed | 6 | S | Low | READ; INFERRED | REVISED (full verification — WEAKENED: the ynDialog half stands in full (strcpy into msg[512] at gui.c:20, exceeded by the lang.c and installer caller families); the nonDialog half narrows — no caller that can exceed its 2,400-byte buffer (gui.c:111) was found; a latent same-shape sink, not a dialog several callers already exceed) |
| LAUNCHSTATION-106 | Config-descriptor fetch trusts device-supplied wTotalLength and never checks transferedBytes; short transfers parse stale bytes, oversize devices wedge silently | 6 | S | Low–Med | READ; INFERRED | STANDING |
| LAUNCHSTATION-107 | HDIOC_READSECTOR / HDIOC_WRITESECTOR take LBA, count and data pointer from the caller with no bound against the disk, and writes bypass the APA cache and journal entirely | 6 | S | Low–Med | READ; INFERRED | STANDING |
| LAUNCHSTATION-108 | HIOCGETSIZE indexes fileSlot->parts[] with a caller-supplied u32 and no bounds or pointer check | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-109 | ioctl2Transfer's bounds check is overflowable and the transfer direction is caller-supplied | 6 | S | Low | READ; INFERRED in part | STANDING |
| LAUNCHSTATION-110 | APA header injection rewrites 2 MB in place with no rollback and no readback verification | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-111 | Journal write side has no capacity check, and the flush path ignores journal errors and resets the journal anyway | 6 | S | Low–Med | READ; INFERRED in part | STANDING |
| LAUNCHSTATION-112 | Backing read/write/erase never check page against the stored cardsize: writes and erases past the end of the image extend the backing file | 6 | S | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-113 | Exploit installer trusts card/dir-supplied entry names to be NUL-terminated — the one filer path without the codebase's own termination guard | 6 | XS | Near zero | READ; INFERRED | STANDING |
| LAUNCHSTATION-114 | `delete()` and `getFileSize()` recurse with no depth limit — the MAX_RECURSE 16 guard `copy()` has was never given to them | 6 | M | Low–Med | READ; INFERRED | STANDING |
| LAUNCHSTATION-115 | The OSDMBR journal-overlap guard is compiled out of the OSD build — the one build this module exists for | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-116 | The SMB share editor's shared edit buffer is 96 bytes, but the folder field it edits is 128 — long folder names are silently truncated on save | 6 | Trivial | Minimal | READ | STANDING |
| LAUNCHSTATION-117 | `apaRename` signals fioSema on three of its exits and its caller signals it again — semaphore ownership is double-released on every rename error path | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-118 | VMCMAN unit→slot mask `unit & (MCMAN_MAXSLOT - 1)` is `unit & 9`: units 2–7 silently alias onto slots 0/1 and slots 2–7 are unreachable | 6 | S | Low–Med | READ; INFERRED | STANDING |
| LAUNCHSTATION-119 | `GET_XPARAM_DB_SIZE()` always evaluates to 1 — the 292-entry database is searched over exactly one entry | 6 | One character | Low | READ | STANDING |
| LAUNCHSTATION-120 | `readHOST()`'s elf-list branch returns hostcount − 1: the last entry is dropped whenever elflist.txt has no trailing newline | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-121 | MMCE history newest/prune ordering is lexicographic, but same-second collision names sort backwards | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-122 | HDL game-title rename caps the title at partition-name length (31) despite a 65-byte title buffer — silent truncation | 6 | S | Low | READ; INFERRED | REVISED (full verification — WEAKENED: the buffer/cap mismatch is real (name[65] vs keyboard cap 31), but modalKeyboard never truncates on confirm — the only max_len truncation is on cancel (dash_widgets.c:587), and the caller discards the buffer then; the cap blocks insertions at ≥31 chars — an editing constraint, not silent truncation) |
| LAUNCHSTATION-123 | `loadHdlInfoModule()` marks the HDL Info RPC ready unconditionally — module-load and bind results are both discarded | 6 | ~3 lines | Low | READ | STANDING |
| LAUNCHSTATION-124 | `filerFreeSpace()`'s XFROM branch reports success without the start/sync checks its own MC branch documents as necessary | 6 | S | Minimal | READ; INFERRED | STANDING |
| LAUNCHSTATION-125 | `preloadCNFFd`'s seek path has no size cap — the 128 KB cap exists only in the fallback it bypasses | 6 | XS | Low | READ | STANDING |
| LAUNCHSTATION-126 | Hand-rolled JSON string extractor mis-handles escaped backslash, never decodes \uXXXX, and matches keys by first occurrence | 6 | M | Low–Med | READ | STANDING |
| LAUNCHSTATION-127 | Drive request builders ignore snprintf truncation | 6 | S | Low | READ | WITHDRAWN (full verification phase 2026-11-14 — REFUTED: the escape helpers fail rather than truncate and the checked bounds cap every input below every destination — truncation arithmetically unreachable) |
| LAUNCHSTATION-128 | `Transfer-Encoding: chunked` detection is case-sensitive | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-129 | Unbounded atoi/digit accumulation overflows before clamping in theme and IPv4 parsers | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-130 | `fioInputBreaker` accepts a field exactly as long as its buffer, leaving IDs and passwords unterminated | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-131 | Module start arguments admit 0 and negatives for -o, and no maximum at all for -n | 6 | S | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-132 | `apa_ptable_read_ex` end-of-disk test can wrap, and excludes a partition ending exactly at the disk end | 6 | S | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-133 | Recycled hub buffer keeps the previous hub's bNbrPorts when the new hub descriptor is short | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-134 | Isochronous halted-ED cleanup clears the wrong LUT slot, leaving a dangling request | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-135 | Three MMCE command setters transmit uninitialised stack bytes to the card | 6 | 3 lines | Minimal | READ; INFERRED | STANDING |
| LAUNCHSTATION-136 | ds34bt DS4 LED/rumble report: buffer zeroed with the DS3 length, then sent at the DS4 length — 29 uninitialised stack bytes transmitted | 6 | One token | Low | READ | STANDING |
| LAUNCHSTATION-137 | KELF signing key material is never scrubbed from stack copies | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-138 | `mcman_iomanx_backing_mount` trusts its slot twice: cleanup runs clear_slot on slots the validator just rejected, and re-mounting overwrites a live fd | 6 | S | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-139 | Four entry-reachable `apaCacheAlloc()` results are used without a null check, beside a fifth site in the same files that does check | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-140 | usbd `_start` config arguments are parsed without range checks and feed unchecked allocation arithmetic; AllocSysMemory result is memset before any NULL check | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-141 | ps2ips `do_send`/`do_sendto` trust the EE-supplied `malign` count: negative buffer offset and length underflow | 6 | S | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-142 | ps2ips `do_recv`/`do_recvfrom` never reject a negative EE-supplied `length` | 6 | S | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-143 | hdl_info rename path: EE-supplied NewName is strcpy'd with no termination guarantee, and the RPC handler never looks at Size | 6 | S | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-144 | HDL RPC wrappers strcpy into 33- and 64-byte packet fields with no length check — safety exists only in today's callers | 6 | Trivial | Low | READ | STANDING |
| LAUNCHSTATION-145 | Editor navigation rules read one row-width entry before/after the cursor's row, and past the last row after the Home/End scans | 6 | S | Low | INFERRED | STANDING |
| LAUNCHSTATION-146 | SETTING allocations are dereferenced without a NULL check, in both places config.c creates one | 6 | S | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-147 | `des_cbc_crypt` performs fixed 8-byte block copies with no size validation | 6 | S | Low | INFERRED | REVISED (full verification — WEAKENED: des_cbc_crypt has no multiple-of-8 check, but it is already static and its only callers are inside the validating tdes_cbc_crypt (size always 8; tdes validates (size & 7) at :436-439) — exposure only via a future edit inside kelf_signer.c itself; a latent in-file foot-gun, materially narrower than filed) |
| LAUNCHSTATION-148 | Scene-override stack loses one level when nesting exceeds depth 8 | 6 | S | Low | INFERRED | STANDING |
| LAUNCHSTATION-149 | `dashPngDecode` dereferences its out-parameters without the NULL checks its JPEG sibling performs | 6 | Trivial | Low | READ | STANDING |
| LAUNCHSTATION-150 | `smap_transmit` retries a full/dead TX queue forever with no stop or timeout | 6 | S | Low–Med | READ; INFERRED | STANDING |
| LAUNCHSTATION-151 | `ds34bt_reset` waits forever for pads to leave RUNNING state | 6 | S | Low | READ | STANDING |
| LAUNCHSTATION-152 | usbd device-descriptor short read retries forever with no counter | 5 | S | Low | READ | STANDING |
| LAUNCHSTATION-153 | `waitUntilTimer()` busy-spins the EE for up to 6 s on the UI thread while waiting for a clipboard source device | 5 | S | Low | READ | STANDING |
| LAUNCHSTATION-154 | pccf `pio_profile` does up to 18 validation reads at start, and any failure — including "known model, card smaller than 4096 sectors" — triggers a full power-cycle restart of the whole driver | 5 | S | Low | READ | STANDING |
| LAUNCHSTATION-155 | `pcdiag_cf_probe`'s sampling phase is diagnostic dead work in the production driver: results go to a no-op trace, the return is unconditional, and it costs ~700 ms on every start | 1/5 | S | Low | READ | STANDING |
| LAUNCHSTATION-156 | Passwords are DES-encrypted on input and then never verified in this build — the DES run on every open/remove/getstat name parse is dead work | 5 | S | Low | READ | REVISED (full verification — WEAKENED: apaPassCmp compiling to return 0 in the OSD build stands (no APA_ENABLE_PASSWORDS), but the input-side DES runs are conditional — apaEncryptPassword runs only when the argument actually carries a non-empty password field; a plain partition-name parse performs no DES run at all) |
| LAUNCHSTATION-157 | `HandleRxIntr` never counts a packet, so the link-check traffic reset is dead | 1 | Trivial | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-158 | Two private 2,049-entry sceMcTblGetDir statics (readMC and readXFROM) duplicate ~120 KB of .bss each | 4 | Trivial | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-159 | pccf PIO tuning profile reserves 8 KiB of static IOP memory for a one-shot, two-model check | 4 | S | Low | READ | STANDING |
| LAUNCHSTATION-160 | The local MINI_DRIVER choice caps total descriptors at 512 bytes/device and the overflow path drops the device with no diagnostics in release builds | 6/8 | S | Low | READ; INFERRED | REVISED (full verification — WEAKENED: the silent drop stands (hub.c:427-429 logs only via dbg_printf, a no-op without DEBUG), but the 512 B cap is not a MINI_DRIVER effect — maxStaticDescSize is 0x200 in both configurations (usbd.c:40/:54); survives only as “512 B cap + silent drop in release builds”) |
| LAUNCHSTATION-161 | `mmce_cmd_get_status`, `mmce_cmd_get_card` and `mmce_cmd_get_channel` are one function pasted three times | 2 | S | Minimal | READ | STANDING |
| LAUNCHSTATION-162 | The classic browser's New Icon flow is a second, unchecked copy of `filerCreateFolderIcon()` — including a statement its own comment calls dummy code | 2 | M | Med–Low | READ | STANDING |
| LAUNCHSTATION-163 | Three near-identical recursive directory walks in `mmce_backup.c` | 2 | M | Low–Med | READ | STANDING |
| LAUNCHSTATION-164 | Theme-folder read and load are the same ~35-line routine twice; write and export repeat the mkdir preamble | 2 | S–M | Low | READ | STANDING |
| LAUNCHSTATION-165 | `getExternalFilePath()` re-implements `genFixPath()`'s HDD/DVR partition transform in init.c | 2 | M | Med | READ | STANDING |
| LAUNCHSTATION-166 | `resetScreen()` and `resetDisplayThemeDefaults()` duplicate the same 15-line classic reset | 2 | S | Low | READ | STANDING |
| LAUNCHSTATION-167 | PNG decoder open-codes its flush-row block three times; the JPEG decoder beside it already has it as a function | 2 | S | Low | READ | STANDING |
| LAUNCHSTATION-168 | BCD conversion is copy-pasted at least four times, twice inside one file | 2 | Trivial | Low | READ | STANDING |
| LAUNCHSTATION-169 | The same `pccf` IOP target is defined twice — root `ps2.yaml` and `iop/pccf/ps2.yaml` — with identical sources, defines, flags and headers | 2/7 | S | Low | READ | STANDING |
| LAUNCHSTATION-170 | `pathApplied()` sets the ESR/OSDSYS LK_Flag twice — the second pair makes the first redundant | 2 | Trivial | Minimal | READ | STANDING |
| LAUNCHSTATION-171 | The CNF save text writes `PathPad_Lock` twice | 2 | XS | Near zero | READ | STANDING |
| LAUNCHSTATION-172 | `hdd_blkio.c` (431 lines) compiles to nothing in the shipped build and is still listed as a build source; the BDM/vHDD backends it carries are dead weight with their own latent defects | 1/7 | M | Low | READ | STANDING |
| LAUNCHSTATION-173 | Four libhdd entry points have no caller anywhere in the tree, and the one filesystem-list walker among them strcpy's dirent names into a 32-byte field | 1/6 | S | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-174 | `load_ps2atad_stack()` is a 52-line DVRP loader with no caller, kept alive only by `__attribute__((unused))` | 1 | Trivial | Low | READ | STANDING |
| LAUNCHSTATION-175 | Six settings IDs have choice/action dispatch but no row in any page — the handlers are dead | 1 | S | Low | READ | STANDING |
| LAUNCHSTATION-176 | `hdl_glist_write` leaks the games array on every rename | 6 | One line | None | READ | STANDING |
| LAUNCHSTATION-177 | Three duplicated dead branches/includes: second DTL check, second PSX MagicGate block, second `mmce_igr.h` include | 1 | XS | Near zero | READ | STANDING |
| LAUNCHSTATION-178 | Four usbd imports are declared and never called (`strtol`, `DeleteSema`, `DeleteThread`, `DelayThread`) | 1 | S | Low | READ | STANDING |
| LAUNCHSTATION-179 | ata_bd imports `bdm_disconnect_bd` and never calls it | 1 | 1 line | Negligible | READ | STANDING |
| LAUNCHSTATION-180 | usbmass_bd imports `sceUsbdSetPrivateData` and never calls it | 1 | 1 line | Negligible | READ | STANDING |
| LAUNCHSTATION-181 | pccf: one dead import — `I_memcpy` is declared but memcpy is never called in the module | 1 | 1 line | Low | READ | STANDING |
| LAUNCHSTATION-182 | A ~55-line commented-out font-dump function is carried in draw.c | 1 | Trivial | None | READ | STANDING |
| LAUNCHSTATION-183 | The commented-out CodeBreaker partition filter is pasted twice, inside two near-identical partition-list functions | 7 | Trivial | Minimal | READ | STANDING |
| LAUNCHSTATION-184 | `submenu_func_GetSize()` carries ~50 lines of commented-out debug scaffolding | 7 | Trivial | None | READ | STANDING |
| LAUNCHSTATION-185 | xparam `_start` argument handling: `argc == 3` does nothing, and the pair loop drops a trailing pair | 6 | Trivial | Low | READ; INFERRED | REVISED (full verification — WEAKENED: only the argc == 3 fall-through survives; the claimed trailing-pair drop is refuted — pairs are consumed from index 2 and the continuation test is exactly correct, so no complete pair is ever dropped. WARNING: the originally proposed fix’s loop-condition half (i1 + 1 < argc) should NOT be applied — it would read one argv slot past the last complete pair. The sole caller applyXPARAM (init.c:1355) never passes pairs at all) |
| LAUNCHSTATION-186 | On IOP, every "random" byte behind libsmb2's NTLM server challenge, preauth salt and SMB3 seal nonce comes from a 15-bit LCG seeded with uptime-seconds ⊕ a constant ⊕ a heap pointer | 6 | M | Medium | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-187 | `test_copy_psu_listing.py` fails deterministically at the pin — the Cut→PSU-backup "Move" to a UDPFS destination dies at the delete-confirmed-entries stage with −EIO | 6 | M | Low | READ; INFERRED | STANDING |
| LAUNCHSTATION-188 | libsmb2 frees the file-notify list by recursion whose depth the remote server controls | 6 | S | Low | Medium (READ) | STANDING |
| LAUNCHSTATION-189 | Four libsmb2 client error paths leak their callback-data allocations | 6 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-190 | libsmb2's AES-CCM tag verification uses early-exit `memcmp` | 6 | S | Low | Medium (READ) | STANDING |
| LAUNCHSTATION-191 | The test suite's brace-matching C-function extractor is copied into 103 test files in 71 drifted variants (~1,420 lines) | 2 | M | Low | High (READ) | STANDING |
| LAUNCHSTATION-192 | libsmb2's `sha1.c` compiles to an empty translation unit in the smbd build | 1 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-193 | AllowDVDV's payload import lives in the C file, invisible to its own glue files and to `imports.lst`-driven tooling | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-194 | Two passing tests (230 lines) and the `nfsman_live/` harness are never run by any workflow | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-195 | ds34usb and ds34bt both import `sceUsbdSetPrivateData`, which neither driver ever calls | 1 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-196 | ps2ips_rpc imports `sceSifInitRpc` and never calls it | 1 | S | Low | High | STANDING |
| LAUNCHSTATION-197 | ps2host imports `puts` and never calls it | 1 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-198 | ds34usb + ds34bt `irx_imports.h` declare twelve libraries neither module imports — and nothing includes the header | 7 | S | Low | High (READ; INFERRED in part) | STANDING |
| LAUNCHSTATION-199 | xparam database: one identical row is filed twice consecutively (`SLPM_660.22`) | 2 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-200 | The shipped example config's `Misc = MISC/` double-slashes on load, breaking its own FileBrowser shortcut | 6 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-201 | docs-site cloud page says automatic sync is off by default; the default is on, in local-backup mode | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-202 | The main dashboard doc names `LAUNCHELF.CNF` as the live settings file at five sites; nothing writes that name any more | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-203 | Configuration page says CNF files over 128 KB are rejected; the normal load path has no cap | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-204 | FileBrowser note lists six sort modes with Name as default and ELFs ungrouped; the code has seven modes, defaults to Type, and groups ELFs first | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-205 | Themes page inverts panel transparency: it says 0% removes panels and 100% is opaque; the code is the reverse | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-206 | Ecosystem page denies the All-saves view and batch card saves exist; both are shipped and documented elsewhere in the same site | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-207 | Cloud doc caps the HTTP body at 64 KiB; the code's limit is 256 KiB | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-208 | Two docs say `CNF_version` must be the first line; the parser accepts it anywhere, and a missing version loads as legacy | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-209 | Two docs say the PSX (DESR) is treated as having i.Link; `consoleHasIlink()` returns 0 on PSX | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-210 | Example config's comment says Triangle shows About; the same file's empty `LK_Triangle_E1` overrides the built-in About default | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-211 | Example config says titles are gated by `Menu_Hide_Paths`; the gate is `Show_Titles` | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-212 | Example config's Neutrino comment omits the SMB backend and claims `-qb` is unconditional; SMB is supported and suppresses `-qb` | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-213 | CHANGELOG says the share editor writes SMB2.CNF and SMB1 opens via `smb1:/`; shares live in LAUNCHSTATION.CNF and SMB1 is a folder in `smb:/` | 7 | S | Low | High (READ) | REVISED (full verification — WEAKENED: only the SMB2.CNF half is a contradiction (CHANGELOG.md:52’s claim is false — shares live in LAUNCHSTATION.CNF, dash_settings.c:563-564); the smb1:/ half is not a contradiction — both phrasings are true at different layers and the code itself uses the smb1:/ phrasing (dash_browser.c:301 reconciles the two)) |
| LAUNCHSTATION-214 | README says HDD/ATA is "Hidden on Deckard (SCPH-75K+)"; there is no Deckard check — gating is PSX-only plus the Hide-HDD setting | 7 | S | Low | High (READ) | WITHDRAWN (full verification phase 2026-11-14 — REFUTED: shouldHideHddAtaDevices exists (main_startup.c:746-756) and is consumed; README.md:181 is substantively correct) |
| LAUNCHSTATION-215 | Issue-plan doc states MC/VMC copies use 16 KiB chunks; the copy path uses 128 KiB for those destinations and no 16 KiB chunking exists | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-216 | Themes page lists two UI fonts; the code ships three (`emotion_engine` omitted — though the same page mentions it later) | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-217 | Three docs stop the TV-mode list at 576p; mode 6 (576i) exists and is exposed in both UIs | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-218 | Five doc sites deny a root LICENSE exists; a scoped 0BSD LICENSE has been tracked at root since 2026-11-02 | 7 | S | Low | High (READ) | REVISED (full verification — WEAKENED: four sites deny a root LICENSE exists, not five — the fifth (docs-site/content/ecosystem.html:4, “no single root licence”) remains true, because the root LICENSE’s scope is limited to original Launchstation code, and is struck; the four-site finding stands) |
| LAUNCHSTATION-219 | Two docs inventory the update CA bundle as two roots; the bundle contains three — the omitted E46 root is load-bearing | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-220 | Follow-up manifest says the move-manifest work is "Implemented on the draft PR branch; not merged"; it is merged at the pin | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-221 | architecture-maintenance's inventories don't match the tree: largest-files list omits the two largest files, workflow table lists 3 of 6 | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-222 | Wiki build page says "The retained Makefile describes historical profiles"; no Makefile exists at the pin — it was retired 2026-10-26 | 7 | S | Low | High (READ) | STANDING |
| LAUNCHSTATION-223 | Display-feedback doc claims a 320×256 wallpaper help string "still" exists in dash_settings.c; no such string exists at the pin | 7 | S | Low | High (READ) | STANDING |

### 2.3 POPSLoader — 108 items

| ID | Title | Cat | Effort | Risk | Confidence | Status |
|---|---|---|---|---|---|---|
| POPSLOADER-001 | `.research/` preservation archive is 70% of the product repo | 7 | M | Med | High (READ) | STANDING |
| POPSLOADER-002 | Byte-identical IRX modules are embedded into the ELF two and three times | 2 | S | Low | High (READ) | REVISED (full verification — WEAKENED: the byte identities are exact, but usbd.irx.mx4sio is already aliased to the usbexfat blob (embed_assets.cpp:149-153,210), not embedded — the remaining saving is 83,008 B (ilink usbd + udpfs usbhdfsd), not 131,508 B) |
| POPSLOADER-003 | All seven UI languages are compiled into `system.lua` and parsed on every boot | 4 | M | Med | High (READ) | STANDING |
| POPSLOADER-004 | The whole POPStarter SMB IRX set is tracked twice, byte for byte | 2 | S | Med | High/Med (READ; INFERRED) | STANDING |
| POPSLOADER-005 | Five copies of POPSTARTER.ELF tracked; the top-level copy is byte-identical to the DEBUG profile | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-006 | A 1.47 MB source tarball sits unreferenced inside `iop/embed/` | 7 | S | Low | High (READ) | REVISED (R3 REV-006 — fix changed: extract-or-archive; R7 R7-REV-006 — narrowed: disposition covers the bdm_assault half only; usbhdfsd.irx has no source in the tarball) |
| POPSLOADER-007 | UI images are shipped twice: as files in `bin/POPSLDR/IMG/` and embedded in the ELF | 2 | M | Med | Med (READ; INFERRED) | REVISED (full verification — WEAKENED: only 25 of the 67 IMG PNGs are embedded (243,578 B); the other 42 (87,097 B) are loose-only with no second copy — the duplication covers the embedded 25, not the ~330,675 B folder upper bound) |
| POPSLOADER-008 | Every settings save writes the file three times on a slow memory card | 5 | S | Med | High (READ) | STANDING |
| POPSLOADER-009 | `graphics.cpp` PNG loader repeats the same row-buffer block three times, with a malloc per row | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-010 | ds34 (DualShock 3/4) driver code exists in three near-copies | 2 | L | High | High (READ) | REVISED (R3 REV-010 — pademu copies a semantic fork) |
| POPSLOADER-011 | Generated bin2c output `src/elf_loader/loader.c` (855,821 B) is committed to git | 7 | M | Med | High (READ) | REVISED (R7 R7-REV-011 — rationale corrected: the CI parity check cannot compare the committed dump; see POPSLOADER-066) |
| POPSLOADER-012 | Ten workflows, 2,062 lines, including a one-shot retraction workflow that has done its job | 7 | S | Low | High/Med (READ; INFERRED) | STANDING |
| POPSLOADER-013 | `opencode.yml` is an AI-comment-bot workflow in a repo already carrying heavy agent sprawl | 7 | S | Low | Med (READ; INFERRED) | STANDING |
| POPSLOADER-014 | Stale branches and checkpoint/backup tags (list only, per brief) | 7 | S | Med | High (READ) | STANDING |
| POPSLOADER-015 | Docs sprawl at the root: 18 Markdown files, 4,896 lines, plus fossil audit reports in `docs/` | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-016 | Sixteen one-shot audit scripts in `.research/tools/` (~2,100 lines) audit a finished recovery, not the product | 1 | S | Low | High (READ; INFERRED) | REVISED (R3 REV-016; R4 REV-016 addendum) |
| POPSLOADER-017 | `lua_dir` puts a 512-entry memory-card table on the EE stack | 6 | S | Low | High/Med (READ; INFERRED) | STANDING |
| POPSLOADER-018 | Network waits block the calling (UI/Lua) thread for up to 30 s at a time | 5 | M | Med | High/Med (READ; INFERRED) | STANDING |
| POPSLOADER-019 | `elf.c` carries the launch-argument storage logic twice | 2 | S | Med | High/Med (READ; INFERRED) | STANDING |
| POPSLOADER-020 | `sprintf` into a 16-byte heap buffer, via a pointer truncated to `int`, in the image thread | 6 | S | Low | High (READ) | STANDING |
| POPSLOADER-021 | Unchecked `getcwd` results in the Lua directory bindings | 6 | S | Low | High (READ) | STANDING |
| POPSLOADER-022 | Translation data exists in three forms: inline Lua, TSV, and a binary XLSX of the TSV | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-023 | Defensive `pcall` + `type()==…` wrapping is the dominant idiom in the Lua UI (370 sites) | 3 | L | Med | High/Med (READ; INFERRED) | STANDING |
| POPSLOADER-024 | Root-level marketing/loose assets and a stray format diagram | 7 | S | Low | High/Low (READ; INFERRED) | REVISED (full verification — WEAKENED: a full md5 census of .research/assets/ finds exactly 6 exact-duplicate image pairs (6 redundant copies = 57,552 B), not “at least 9”; the root loose assets stand as cited) |
| POPSLOADER-025 | Leftover upstream (OPL/Enceladus) TODO block in `fntsys.cpp` describes another project's UI | 1 | S | Low | High (READ) | STANDING |
| POPSLOADER-026 | Settings save carries a second, diverged copy of the whole commit sequence as a "fallback" | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-027 | UDPFS "is it equipped" check re-reads and byte-compares whole IRX files from the memory card on every launch | 5 | S | Low | High (READ) | STANDING |
| POPSLOADER-028 | A self-described "TEST" HDD write probe runs, and toasts, on every production Settings save | 8 | S | Low | High (READ) | STANDING |
| POPSLOADER-029 | Two independent implementations of the same PLDRGC1 game-list cache format | 2 | M | Medium | High (READ) | STANDING |
| POPSLOADER-030 | Settings rollback passes two fields that no longer exist anywhere in the settings system | 6 | S | Low | High (READ) | STANDING |
| POPSLOADER-031 | Permanently-false flag leaves five dead branches in the hottest launch function | 3 | S | Low | High (READ) | STANDING |
| POPSLOADER-032 | Seven Lua functions with zero callers, including a near-twin of a live resolver | 1 | S | Low | High (READ) | STANDING |
| POPSLOADER-033 | The DS3/DS4 IOP drivers are maintained as two diverging copies | 2 | L | Medium | High (READ) | REVISED (R3 REV-033 — merge shape/effort revised) |
| POPSLOADER-034 | DS3 battery byte indexes a 6-entry table with no range check, in all four driver copies | 6 | S | Low | High (READ) | STANDING |
| POPSLOADER-035 | ps2atad probes the phantom slave drive, then unconditionally throws the result away | 1 | S | Low | High (READ) | STANDING |
| POPSLOADER-036 | Much of the host harness asserts source text, not behaviour — and re-reads the same files all run long | 7 | M | Low | High (READ) | REVISED (full verification — WEAKENED: the text-assert population stands (11 of 62 checks are pure source-text asserts — roughly a fifth), but the re-read count overstates: 25 read_text sites in total including the initial loads, of which 15 re-read the two already-loaded Lua sources, not ≥25 re-reads) |
| POPSLOADER-037 | build_site.py wipes its output directory at import time | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-038 | ATA security-erase path refreshes status by running IDENTIFY DEVICE into a NULL buffer | 6 | S | Low | High/Medium (READ; INFERRED) | STANDING |
| POPSLOADER-039 | images.lua still carries the fallback machinery for a fallback that was removed | 1 | S | Low | High (READ) | STANDING |
| POPSLOADER-040 | build_site.py hard-fails the whole docs build unless the corpus has exactly 34 image records, 19 of them from HEAD | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-041 | ds34 connect paths walk USB descriptor blobs with no NULL or zero-length guards | 6 | S | Low | High/Medium (READ; INFERRED) | REVISED (full verification — WEAKENED, mechanism REPLACED: the endpoint walks are count-bounded by while (epCount--), so a zero bLength stalls on one descriptor but terminates — the filed infinite-loop mechanism is refuted. The real hang: epCount = interface->bNumEndpoints − 1 (ds34bt.c:117, ds34usb.c:132 DS3 branch) underflows to −1 when bNumEndpoints == 0, making the do-while effectively non-terminating. The missing NULL checks and the DS4 epCount = 20 hard-code stand; the fix should add an epCount < 0 / bNumEndpoints == 0 guard) |
| POPSLOADER-042 | Disc-layout test extracts the code it tests by exact comment strings | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-043 | GameList scene still renders a "Not implemented yet" placeholder branch that can never fire | 1 | S | Low | High (READ) | STANDING |
| POPSLOADER-044 | Gutted pad-debug block computes values, discards them, and times them with the wrong unit | 1 | S | Low | High (READ) | REVISED (full verification — WEAKENED: the gutted debug block, discarded locals and the microsecond unit error stand (ui.lua:6670-6699; flag default false at :1270), but the “counters only ever reset, never read” clause is imprecise — DebugPadLast is read by the block’s own comparison (:6676) and NavEventCount is incremented by live code (emit_nav, :6596); its value is simply never consumed anywhere) |
| POPSLOADER-045 | build_site.py renders its largest page twice per build | 5 | S | Low | High (READ) | STANDING |
| POPSLOADER-046 | build_site.py defines slug() twice; the first definition is dead | 1 | S | Low | High (READ) | STANDING |
| POPSLOADER-047 | Clamp01 is defined twice in ui.lua | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-048 | Pademu DS4 LED/rumble report is sent with 29 bytes of uninitialised stack | 6 | S | Low | High (READ) | STANDING |
| POPSLOADER-049 | Pademu ds34 divergence, fully classified: mostly intentional variant, one guard family lost | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-050 | EE ds34 client libraries: 12 of 22 exported functions have no caller anywhere | 1 | S | Low | High (READ) | STANDING |
| POPSLOADER-051 | i18n tables carry 14 dead entries: a superseded toast key in six languages, eight Hungarian-only orphans | 1 | S | Low | High (READ) | STANDING |
| POPSLOADER-052 | audit_site.py hard-codes page prose and magic numbers as publish-gate law | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-053 | fntsys.cpp carries ~232 dead lines: a never-compiled RTL render variant and two caller-less public functions | 1 | S | Low | High (READ) | STANDING |
| POPSLOADER-054 | The 7z listing parser exists in four copies across the research gates, already drifting | 2 | M | Medium | High (READ) | STANDING |
| POPSLOADER-055 | test_udpfs_integration.py's wiring half is ~45 bare source-text assertions | 7 | M | Low | High (READ) | STANDING |
| POPSLOADER-056 | audit_published_provenance.py is exact-prose-as-law, end to end | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-057 | Two more host gates extract the code they test by exact comment strings | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-058 | audit_legacy_tool_overlap.py builds a lookup it never reads | 1 | S | Low | High (READ) | STANDING |
| POPSLOADER-059 | Fetch-process residue and a content-free failure marker are tracked but cited by nothing | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-060 | i.Link documented as "stub / NOT implemented" in three docs; the code implements the full page for Ember and POPSTARTER | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-061 | ARCHITECTURE.md says BDMA_ADAPTIVE defaults off; the code defaults it on | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-062 | STATE.md's header says Slovak "awaits the contributor; SK is not yet in the picker"; SK shipped in 1.4.3/1.4.4 and is in the picker | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-063 | Three docs still claim release 1.1.0 / rolling v1.1.1-dev in their headers; the code reports v1.4.4 | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-064 | README's Retro GEM Game ID row lists "On" as the only option; the code is an On/Off toggle | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-065 | ARCHITECTURE.md says CoverCache is a 3-entry LRU; the code sets max = 4 | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-066 | The loader.c CI parity check never compares the committed dump (and history proves the dump went stale for ~7 weeks behind it) | 6/7 | S | Low | High (READ) | STANDING |
| POPSLOADER-067 | `src/elf_loader/Makefile:15-16` rule cannot build the child loader (dead rule, INFERRED) | 3/7 | S | Low | Medium (INFERRED) | STANDING |
| POPSLOADER-068 | COMPONENTS.md calls the loader.c dump a "~6.5 MB bin2c blob"; it is 855,821 B at the pin | 7 | S | Low | High (READ) | STANDING |
| POPSLOADER-069 | The shipped MX4SIO `usbhdfsd.irx` has no source anywhere in the repo; the pin beside it does not cover it | 7/8 | S | Low | High (READ) | STANDING |
| POPSLOADER-070 | Dead `hci_event_flag_*` macros in both ds34 headers reference a variable declared nowhere and have zero call sites | 1 | S | Low | High (READ) | STANDING |
| POPSLOADER-071 | CSW validation is defeated by pre-filling the receive buffer with the expected signature, tag and success status | 2 | S | Low | High (READ; INFERRED in part) | STANDING |
| POPSLOADER-072 | Device-supplied SCSI block length is accepted unvalidated and divided by in the next statement | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-073 | Three layers hard-assume 512-byte sectors while nothing enforces a 512-byte device | 2 | S | Low | High (READ; INFERRED in part) | STANDING |
| POPSLOADER-074 | GPT parser trusts the on-disk header: entry size ignored, inverted entries underflow the partition size, header bounds never checked against the device | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-075 | `get_frag_list` follows the on-disk FAT chain with no cycle bound, and two sibling ioctl cases dereference a possibly-NULL block device | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-076 | `scsi_connect` discards `scsi_warmup`'s result and connects the device with zero or stale geometry | 1 | S | Low | High (READ; INFERRED in part) | STANDING |
| POPSLOADER-077 | DevCtl STOP_UNIT stops every device and STOP_ALL stops only one: the two command bodies are swapped | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-078 | USBD IsoTD halted-flush clears the wrong LUT slot, leaving a stale request pointer in the completed-TD's slot | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-079 | Failed hub connect leaves a freed `UsbHub` reachable from the device, and unplug then double-frees it | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-080 | Partition read/write translate the sector by the partition offset but never clamp to the partition's own length | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-081 | Block cache marks a block valid after a device read whose result it never checks | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-082 | `fs_open` honours O_CREAT/O_TRUNC without write access: a read-only open can create or truncate a file to zero | 2 | S | Low | High (READ; INFERRED in part) | STANDING |
| POPSLOADER-083 | Mount-info index check admits `index == count` and negative indices, returning an out-of-bounds `block_device*` | 2 | S | Low | High (READ; INFERRED in part) | STANDING |
| POPSLOADER-084 | `scsi_warmup`'s TEST UNIT READY loop has no retry bound, and reads an uninitialised sense buffer when REQUEST SENSE fails | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-085 | `fs_lseek64` converts negative results to ~2⁶⁴ offsets with no clamp and no invalid-`whence` case | 2 | S | Low | High (READ; INFERRED in part) | STANDING |
| POPSLOADER-086 | `cancelTimerCallback` unlinks a timer without folding its remaining delta into its successor, so every later timer fires early | 2 | S | Low | High (READ; INFERRED in part) | STANDING |
| POPSLOADER-087 | A failed `f_close` leaks the FIL/DIR pool slot forever: `fs_close` clears the handle unconditionally and FatFs only invalidates on success | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-088 | READ CAPACITY's `last_lba` is stored as the sector *count*: every device loses its last sector | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-089 | MBR partition entries are trusted exactly as the GPT ones were: no bounds check against the device | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-090 | FatFs `FRESULT` codes are returned to iomanX callers as if they were errnos, throughout `fs_driver` | 2 | S | Low | High (READ; INFERRED in part) | STANDING |
| POPSLOADER-091 | `fs_read`/`fs_write`/`fs_dread` map every FatFs error to 0, indistinguishable from EOF / nothing-written / end-of-listing | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-092 | Filename prefixing for non-zero units uses an unbounded `alloca` on the IOP handler thread's stack | 2 | S | Low | High (READ; INFERRED in part) | STANDING |
| POPSLOADER-093 | USBD's HCD pool allocation is `memset` unconditionally: `AllocSysMemory` failure is a NULL-pointer crash at module load | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-094 | USBD init failure returns are ignored at every layer, so a dead host stack loads as resident success | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-095 | `doUnregisterDriver` leaves the driver's `next`/`prev` set, permanently blocking its re-registration | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-096 | `disk_ioctl`'s GET_SECTOR_COUNT writes 4 bytes into FatFs' 8-byte LBA64 buffer (and GET_SECTOR_SIZE into a WORD buffer) | 2 | S | Low | High (READ; INFERRED in part) | STANDING |
| POPSLOADER-097 | FatFs glue `ff_req_grant` fabricates success: it ignores `WaitSema`'s result, can never time out, and `ff_del_syncobj` does the same for deletion | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-098 | The hub status-change chain abandons itself on any transfer error: one transient hub error permanently stops hot-plug detection | 2 | S | Low | Medium (INFERRED) | STANDING |
| POPSLOADER-099 | `HubControlTransfer` silently drops a port reset issued while the hub control request is busy, wedging resets system-wide | 2 | S | Low | Medium (INFERRED) | STANDING |
| POPSLOADER-100 | Module-argument integers in USBD accumulate with no overflow or range validation, then size the entire HCD pool layout | 2 | S | Low | Medium (INFERRED) | STANDING |
| POPSLOADER-101 | `bd_cache_create` dereferences both `AllocSysMemory` results unchecked | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-102 | Stat timestamps report seconds ≥ 32 as 32 seconds early: the seconds recovery masks instead of multiplying | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-103 | Unknown `ioctl2` commands return success having done nothing | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-104 | `disk_ioctl` returns RES_OK for every command it does not implement | 2 | S | Low | High (READ) | STANDING |
| POPSLOADER-105 | `fs_dread`'s name copy can leave the returned dirent unterminated at maximum-length filenames | 2 | S | Low | Medium (INFERRED) | STANDING |
| POPSLOADER-106 | MBR parser leaks its 512-byte scratch block on the read-failure path (every other error path frees it) | 4 | S | Low | High (READ) | STANDING |
| POPSLOADER-107 | The ASYNC half of `usb_queue_cmd` is dead code that also skips CSW status validation entirely | 1 | S | Low | High (READ) | STANDING |
| POPSLOADER-108 | GPT partition `sectorCount` is one sector short for every valid partition (last LBA is inclusive) | 6 | S | Low | High (READ) | STANDING |

### 2.4 SMS — 188 items

| ID | Title | Cat | Effort | Risk | Confidence | Status |
|---|---|---|---|---|---|---|
| SMS-001 | Two complete IOP-module delivery systems ship in one ELF: legacy hex-dump blob + BDM IRX set | 2 | L | High | High (READ; INFERRED in part) | STANDING |
| SMS-002 | Dead 373 KB IOP image header: `s_iop_image.h` is only referenced from commented-out code | 1 | S | Low | High (READ) | STANDING |
| SMS-003 | Plain `.irx` files are tracked alongside the `.irx.xz` files the build actually embeds | 7 | S | Med | High/Med (READ; INFERRED) | STANDING |
| SMS-004 | Generated documentation is committed three times: `docs-site/` source, generated `docs/`, generated `wiki/` — plus byte-identical asset copies | 7 | M | Med | High (READ) | STANDING |
| SMS-005 | Every language pack exists twice, and the two copies have already diverged | 2 | S | Low | High (READ) | STANDING |
| SMS-006 | Two embedded IRX blobs are never loaded: `bdmfs_vfat.irx.xz` and `mmcedrv.irx.xz` | 1 | S | Low | High (READ) | STANDING |
| SMS-007 | A `.bak` file is tracked despite the repo's own `*.bak` ignore rule | 7 | S | Low | High (READ) | STANDING |
| SMS-008 | Investigation handoff folder that orders its own deletion is merged to master, with mutated crash-test media | 7 | S | Low | High (READ) | STANDING |
| SMS-009 | The never-shipped BDM=0 legacy build doubles the storage code paths and costs a full CI job | 8 | L | High | High (READ) | STANDING |
| SMS-010 | Hex-dump C arrays for sounds, font and icons inflate source and compile time; the build already has a bin2c pipeline | 4 | M | Low | High (READ) | STANDING |
| SMS-011 | TEMP save-diagnostic is permanent release code, with a global buffer and duplicated save paths | 3 | S | Low | High (READ) | STANDING |
| SMS-012 | Duplicated config-save / mc-icon code inside SMS_Config.c | 2 | M | Med | High (READ) | STANDING |
| SMS-013 | Fixed 2.5 MB player ring buffers regardless of what is playing | 4 | M | Med | High/Med (READ; INFERRED) | WITHDRAWN (full verification phase 2026-11-14 — REFUTED: the video-ring allocation already sits inside the video-stream branch at SMS_Player.c:1716-1741) |
| SMS-014 | Unbounded `strcpy`/`strcat`/`sprintf` on file-supplied strings: playlists, paths, skins | 6 | M | Med | High (READ) | REVISED (R2 R2-1 — narrowed) |
| SMS-015 | MOV container trusts file-supplied entry counts for malloc size | 6 | M | Low | High (READ) | WITHDRAWN (verification phase 2026-11-14 — REFUTED: its own proposed fix already exists at the pin — the _tbl_fits guard) |
| SMS-016 | Unchecked SBR allocations in the AAC decoder | 6 | S | Low | Med (READ; INFERRED in part) | STANDING |
| SMS-017 | CopyTree allocates a 384 KB buffer, twice, for file copies | 4 | S | Med | High/Low (READ; INFERRED) | REVISED (R2 — corrected by cross-repo evidence) |
| SMS-018 | Two vendored network stacks plus three copies of the same headers in `iop/` | 2 | S | Low | High (READ) | STANDING |
| SMS-019 | 59 host test scripts (~14,000 lines of Python in tools/) with source-scraping harnesses that duplicate the C structs they test | 7 | M | Low | High (READ) | STANDING |
| SMS-020 | sms-converter maintains a Windows 7 Qt5/Python 3.8 compatibility shim and a second OS build matrix | 3 | M | Med | High (READ) | STANDING |
| SMS-021 | `#if 0` and commented-out code blocks in the EE tree | 1 | S | Low | High (READ) | STANDING |
| SMS-022 | Exact-count language-pack format: one added string invalidates all 20 packs, silently until recently | 3 | M | Med | High (READ) | STANDING |
| SMS-023 | Branch and tag clutter: checkpoints, agent threads and mutable tags | 7 | S | Low | High (READ) | STANDING |
| SMS-024 | Six workflows, three of which rebuild/republish documentation or media on every master push | 7 | S | Low | High (READ) | STANDING |
| SMS-025 | DTS decoder is the second-largest file in the tree for the least-common audio format | 8 | S | Med | Med (READ; INFERRED) | STANDING |
| SMS-026 | iLink / IEEE 1394 support is carried end-to-end for a peripheral almost no PS2 has | 8 | M | Med | High/Low (READ; INFERRED) | STANDING |
| SMS-027 | Player extras compiled in for every user: spectrum visualiser + ball simulation + FFT assembly | 8 | S | Low | Med (READ; INFERRED) | REVISED (R2 R2-3 — replaced by SMS-038) |
| SMS-028 | History file is rewritten to the memory card on playback events | 5 | S | Low | Med (READ; INFERRED) | REVISED (R2 R2-2 — narrowed) |
| SMS-029 | Identical and near-identical theme/icon assets shipped in two theme trees | 4 | S | Low | High/Med (READ; INFERRED) | STANDING |
| SMS-030 | Root-level stale/duplicate meta-documents | 7 | S | Low | High (READ) | STANDING |
| SMS-031 | `utils/DDrawSrv.exe` — a 44 KB Windows binary with no source and no in-repo reference | 7 | S | Low | High (READ) | STANDING |
| SMS-032 | Legacy download binaries and archives committed under docs/downloads | 7 | S | Low | High (READ) | STANDING |
| SMS-033 | Prebuilt VU microcode objects with no source in the repo | 7 | S | Low | High (READ) | STANDING |
| SMS-034 | Vendored font packs with space-laden paths, vendored wholesale | 7 | S | Low | Med (READ; INFERRED) | REVISED (full verification — WEAKENED: the vendored font packs with space-laden vendor paths are proven, but “unused members ride along” was never proven (INFERRED in the original) — the packs are alternative per-language sets sharing bare names, and two code-referenced names (greek.mtf, latin2.mtf) appear in no pack; whether any given .mtf is ever used is not determinable from the repo) |
| SMS-035 | SMB credentials written to the memory card / filesystem in plaintext | 6 | S | Low | High (READ) | STANDING |
| SMS-036 | The whole legacy SMB IOP source tree is built by nothing — and contains the same client twice | 1 | S | Low | High (READ) | STANDING |
| SMS-037 | 37,312 bytes of `g_DataBuffer` are dead in the shipped build — exact figures that firm SMS-001 | 4 | M | Med | High (READ) | STANDING |
| SMS-038 | The audio-only renderer runs an FFT and a ball simulation every frame, even when both visuals are off | 5 | S | Low | High (READ) | STANDING |
| SMS-039 | AVI stream-name chunks: file-supplied size goes straight to `malloc` — unclamped and unchecked | 6 | S | Low | High (READ) | STANDING |
| SMS-040 | The TEMP save diagnostic can itself overflow a 64-byte global on the failure path it exists to debug | 6 | S | Low | High (READ) | STANDING |
| SMS-041 | Player thread: media name and path are sprintf/strcpy'd into 128- and 512-byte stack buffers | 6 | S | Low | High/Med (READ; INFERRED in part) | REVISED (full verification — WEAKENED: the :1504 half stands (unbounded strcpy of m_pPath into lPath[512] at SMS_Player.c:1502-1504, paths legitimately built to 1024 B); the :1060 half is refuted — the container m_pName is a ≤8-char format constant (“MPEG(PS)” is the longest), never a file name, so the lBuff[128] overflow cannot occur) |
| SMS-042 | Directory scans pay a per-entry device probe and a quadratic subtitle match | 5 | M | Med | High/Med (READ; INFERRED) | STANDING |
| SMS-043 | Grid/page redraw synchronously reads and JPEG-decodes every missing artwork thumbnail before drawing | 5 | M | Med | High/Med (READ; INFERRED) | STANDING |
| SMS-044 | One CDDA path append bypasses the capacity-checked helper every other append uses | 6 | S | Low | High/Low (READ; INFERRED) | STANDING |
| SMS-045 | Small allocation results are unchecked across the container/open paths — NULL is then written through | 6 | S | Low | High (READ) | REVISED (full verification — WEAKENED: boundedness verified everywhere claimed, including all six MOV sites (_tbl_fits + explicit NULL checks — SMS-015’s withdrawal stands); the unchecked-result half survives only at the M3U pair (SMS_ContainerM3U.c:308-312,366-371), SMS_FileContext.c:1233-1238 and :1976-1978, and SMS_Container.c:351-352 — the MOV six and FileContext :2069 are checked) |
| SMS-046 | Language-pack strings are used as `sprintf` format strings throughout — the pack test is the only gate, and it doesn't check `%` sequences | 6 | S | Low | High (READ) | STANDING |
| SMS-047 | Boot splash holds a static frame for a full second, between two 17-frame fades | 5 | S | Low | High (READ) | STANDING |
| SMS-048 | The still-live legacy IOP blob sources have no build path, no workflow, and no provenance note | 7 | S | Low | High (READ) | STANDING |
| SMS-049 | IOP CDVD directory cache appends disc-supplied names to a 1024-byte pathname with no length check | 6 | S | Low | Med (READ; INFERRED in part) | REVISED (full verification — WEAKENED: the unchecked SMSCDVD appends are real, but matched components are ≤129 B (TocEntryCopy truncates to the 129-byte field), not 255, and cumulative growth in one FindPath descent is bounded by the pathname already copied into s_DirName[1024] — overflowing m_Pathname requires a >1023-byte apPath that first overflows s_DirName itself at :657/:685) |
| SMS-050 | ASF: a missing or zero file-properties object leaves `packet_size` at 0, and the packet reader divides by it | 6 | S | Low | High/Med (READ; INFERRED) | STANDING |
| SMS-051 | Three IOP starters claim residency/ownership without checking whether the module loaded — the exact failure the file's newer starters were written to prevent | 6 | S | Low | High (READ) | STANDING |
| SMS-052 | WAV-header helper: a format size of exactly 17 turns its own clamp negative — `malloc(0)` followed by a 4 GiB `Read` into it | 6 | S | Low | Med (READ; INFERRED in part) | STANDING |
| SMS-053 | The 1024-pixel gate is one-sided: negative AVI/ASF dimensions reach MPEG-4 geometry initialisation | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-054 | ODML index entry loop is unbounded and publishes an unchecked `SMS_Realloc` result | 6 | S | Low | High (READ) | STANDING |
| SMS-055 | ODML index-of-indexes recursion has no depth limit | 6 | S | Low | High (READ) | STANDING |
| SMS-056 | AVI `_ReadPacket`'s movi-boundary test uses the file position captured at function entry | 6 | S | Low | Medium (READ; INFERRED in part) | STANDING |
| SMS-057 | Palette rotate wraps at 17 but not at 0: pressing Left at colour 1 stores 0, and the next render reads `g_Palette[-1]` | 6 | S | Low | High (READ) | REVISED (R6 R6-REV-1 — sink list completed: m_BrowserIBCIdx direct reads) |
| SMS-058 | Raw file-loaded config values are used as array subscripts with no range check in the menu layer | 6 | S | Med | High/Med (READ) | STANDING |
| SMS-059 | `GSFont_UnpackChr` indexes the glyph-offset table with an unvalidated character code | 6 | S | Low | mechanism READ (indexing verified at the | STANDING |
| SMS-060 | `SMS_LZMA2Decompress`'s size guard frees the buffer, then decompresses into it anyway | 6 | S | Low | High (READ) | STANDING |
| SMS-061 | `GSFont_UnpackChr`'s RLE decode can overrun its fixed 512-byte destination; the geometry comes from the font file | 6 | S–M | Low | missing clamp READ; file-font trigger RE | STANDING |
| SMS-062 | `CDDA_InitFileContext` dereferences the internal init result without a NULL check | 6 | S | Low | High (READ) | STANDING |
| SMS-063 | `_read_string` runs `strlen` on a stack buffer the disc image never has to NUL-terminate | 6 | S | Low | High (READ) | STANDING |
| SMS-064 | `GUI_LoadIcons` dereferences two unchecked allocations, one of them through the LZMA decompressor | 6 | S | Low | High (READ) | STANDING |
| SMS-065 | Unchecked GUI object-creation and row-render allocations, each dereferenced on the next lines | 6 | M | Low | High (READ; INFERRED in part) | STANDING |
| SMS-066 | GS display-list allocations are dereferenced unchecked, including through a realloc helper whose contract is "NULL on failure" | 6 | S | Low | High (READ) | STANDING |
| SMS-067 | `GUI_Status` loses the status-line DMA buffer permanently on realloc failure | 6 | S | Low | High (READ) | STANDING |
| SMS-068 | `SMS_ListPushBack(...)->m_Param` dereferences a documented NULL-on-failure return at eleven sites | 6 | S | Low | High (READ) | REVISED (R6 R6-REV-2 — twelfth site added: SMS_History.c:140) |
| SMS-069 | `_produce_packets` dereferences unchecked `memalign`/`calloc` in subtitle Prepare | 6 | S | Low | High (READ) | STANDING |
| SMS-070 | Language/subtitle cycling dereferences a NULL list node for containers with no such stream | 6 | S | Low | Medium (READ; INFERRED in part) | STANDING |
| SMS-071 | `_find_signature` puts a 1,204,224-byte buffer on the stack | 6 | S | Low | code facts READ (array size, storage cla | STANDING |
| SMS-072 | `CDDA_Fill` drops the final sector whenever (size + offset) is an exact multiple of 2352 | 6 | S | Low | Medium (READ; INFERRED in part) | REVISED (full verification — WEAKENED: the CDDA_Fill last-sector modulo defect stands, but single-sector files are saved by the sibling start-sector branch (SMS_FileContext.c:474-477, no modulo); the surviving trigger needs (m_Size + m_Offset) % 2352 == 0 AND at least two sectors, via the non-streaming CDDA_Fill path) |
| SMS-073 | Transient menus never free their `m_pState` list, node, or `GUIMenuState` | 6 | S | Low | High (READ) | STANDING |
| SMS-074 | The entire legacy IPU/MPEG icon set in GUIcons is unreferenced: ≈19,230 bytes of `.data` in every ELF | 1 | M | Low | High (READ) | STANDING |
| SMS-075 | `IPU_UnpackImage` is dead code (~105 lines including a large inline-asm DMA loop) | 1 | S | Low | High (READ) | STANDING |
| SMS-076 | Dead SMS-logo remnants in GUIDesktop: a 408-byte table, a 768-byte stack array, dead stores | 1 | S | None | High (READ) | STANDING |
| SMS-077 | The empty `_file_handler` assigned to every playlist-menu item does nothing and is not needed | 1 | S | Low | High (READ) | STANDING |
| SMS-078 | `_is_video_artwork` makes every directory fill quadratic: the full listing is rescanned for every JPEG | 5 | M | Med | High (READ) | STANDING |
| SMS-079 | Decrement-by-one width fitting re-measures the whole string every step (quadratic on long names) | 5 | M | Low | High (READ) | STANDING |
| SMS-080 | Every artwork-mode cursor step re-walks the filtered list ~5 times | 5 | M | Low | High (READ) | STANDING |
| SMS-081 | DevMenu removal redraws every successor icon twice, once at a wrong offset; Render builds the selection arrow twice | 2/5 | S | Low | High (READ) | STANDING |
| SMS-082 | Selection-rectangle GS packet block copy-pasted in all three FileMenu renderers; filtered-list build loop duplicated verbatim | 2 | M | Med | High (READ) | STANDING |
| SMS-083 | Palette-rotate logic exists in four copies (two helpers + two inline) | 2 | S | Low | High (READ) | STANDING |
| SMS-084 | `DrawSkin` triplicates the same size-check / alloc / pad / read block | 2 | M | Med | High (READ) | STANDING |
| SMS-085 | JPEG decode→expand→upload pipeline duplicated between the jellyfish background and the boot splash | 2 | M | Low | High (READ) | STANDING |
| SMS-086 | USB connect/disconnect SIF handlers are mirror copies | 2 | S | Low | High (READ) | STANDING |
| SMS-087 | `GUIMenu_SelectItemByName` and `GUIMenu_SelectItem` duplicate the whole walk | 2 | S | Low–Med | High (READ) | STANDING |
| SMS-088 | `g_ASCII` size mismatch: the extern declares 4572, the definition is 5416, so `GSFont_Get(0)` under-reports by 844 bytes | 6 | S | Low | High (READ) | STANDING |
| SMS-089 | `SMS_ArtworkJPEGSize` treats standalone JPEG markers as length-bearing segments | 6 | S | Low | mechanism READ (walk verified at the pin | WITHDRAWN (full verification phase 2026-11-14 — REFUTED: the preflight walk returns at SOF0/SOS before entropy data; DRI is length-bearing and walked correctly) |
| SMS-090 | Subtitle `_reset` writes `m_pPackets[m_Idx]` with no NULL/range guard | 6 | S | Low | INFERRED | REVISED (full verification — WEAKENED: the m_Idx == m_Cnt one-past write in subtitle Reset is real and reachable (SMS_SubtitleContext.c:917-922), but the “Prepare never run ⇒ NULL m_pPackets” state is not shown reachable as stated; the Reset callers are in SMS_PlayerControl.c (:774,816,1348), not SMS_Player.c) |
| SMS-091 | `GUIMenu_ShowItem` hide-walks have no array bounds | 6 | S | Low | Low (INFERRED) | REVISED (full verification — WEAKENED: the GUIMenu_ShowItem hide-walks are genuinely unbounded in code (SMS_GUIMenu.c:362-375), but for the sole caller (aPos = 4, SMS_GUIMenuSMS.c:2342) they stop after one step onto a never-hidden neighbour in both directions — no out-of-bounds walk is reachable in the shipped menu; latent hardening only) |
| SMS-092 | `_smb_logon` copies credentials with the destination's bound, not the source fields' | 6 | S | Low | Medium (INFERRED) | STANDING |
| SMS-093 | History load has no record cap, and its allocator drops the NULL check its sibling has | 6 | S | Low | High (READ) | STANDING |
| SMS-094 | `DSP_MDCTInit`'s only error path is dead code: `!DSP_iFFTInit(...) < 0` can never be true | 6 | S | Low | High (READ) | STANDING |
| SMS-095 | `DSP_MDCTInit` never checks its `m_pCos` allocation before writing through it | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-096 | `SMSContainer_DefReadPacket`: a dead clamp, a wrong-buffer unalloc, and an unchecked packet allocation | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-097 | `SMSContainer_CalcPktFields` divides by the file's bit rate, in 32-bit arithmetic | 6 | S | Low | Med (READ; INFERRED in part) | STANDING |
| SMS-098 | `SMS_GetContainer`'s explicit-probe path skips the bounds check and throws away the result | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-099 | `SMSContainer_SetName`'s backward slash scan has no start-of-string stop | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-100 | The history record-read loop exists three times | 2 | S | Low | High (READ) | STANDING |
| SMS-101 | The locale loader's read-whole-file block exists three times, its retry twice | 2 | S | Low | High (READ) | STANDING |
| SMS-102 | Probe-order array is dimensioned in bytes, not elements: 156 stack bytes for nothing | 4 | S | Low | High (READ) | STANDING |
| SMS-103 | SMSUMS LFN direntry sequence number is an unchecked index multiplier: writes at −13…+818 into a 128-byte name buffer on callers' stacks | 6 | S | Low | High (READ) | STANDING |
| SMS-104 | DTS `prim_channels` (1–8 from the frame header) written into state arrays sized 5 | 6 | S | Low | High (READ) | STANDING |
| SMS-105 | MPEG-4 sprite trajectory: up to 63 warp points written into a stack `int[4][2]` | 6 | S | Low | High (READ) | STANDING |
| SMS-106 | Vorbis residue `booklist` overwrite: cascade popcount sum reaches 512 into a 256-entry array | 6 | S | Low | High (READ) | STANDING |
| SMS-107 | Vorbis floor1 total post count unbounded: `postlist` heap overwrite in unpack, stack/heap overwrite in look | 6 | S | Low | High (READ) | STANDING |
| SMS-108 | Vorbis residue `begin`/`end`/`grouping` (24-bit each) never validated against block size: decode writes at file-controlled offsets into the PCM buffer | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-109 | lwIP `ip_reass` trusts the header's total length over the received chain: `copy_from_pbuf` walks off the chain end and dereferences NULL | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-110 | SMSUMS READ CAPACITY sector size stored verbatim: 0 divides by zero, >128 KiB overflows the cache buffer on the first read | 6 | S | Low | High (READ) | STANDING |
| SMS-111 | AAC PCE channel totals: the `> MAX_CHANNELS` check runs after construction and its return is ignored by two of three callers; unchecked totals index `internal_channel[]` / `channel_position[]` | 6 | S | Low | High (READ) | STANDING |
| SMS-112 | Vorbis `decodemap[temp]` indexed by a phrasebook decode result with no `temp < partvals` check; the fetched pointer is dereferenced | 6 | S | Low | High (READ) | STANDING |
| SMS-113 | MPEG-4 `SMS_BUG_EDGE` widens motion-compensation clipping from macroblock units to pixel units | 6 | S | Med | High (READ) | STANDING |
| SMS-114 | DTS downmix table indexed by two unmasked 6-bit header values into an `[11][10]` table | 6 | S | Low | High (READ) | STANDING |
| SMS-115 | AC3 channel-count function-pointer table indexed up to 5 into a 2-entry table — a valid 5.1 stream is the trigger | 6 | S | Low | High (READ; INFERRED in part) | REVISED (verification — WEAKENED: shipped Player flow defeats the “valid 5.1” trigger (_check_ac3 clamp + SPDIF routing); survives for non-SPDIF with m_Channels == 0, or a non-Player caller) |
| SMS-116 | DTS channel-count function-pointer table indexed up to 5 into a 2-entry table | 6 | S | Low | High (READ; INFERRED in part) | REVISED (verification — WEAKENED: same Player guard chain as SMS-115; survives for non-SPDIF with m_Channels == 0, or a non-Player caller) |
| SMS-117 | AAC `excluded_channels`: continuation-bit loop writes 7 mask entries per round with no cap — `exclude_mask[64]` walked without limit | 6 | S | Low | High (READ) | REVISED (verification — WEAKENED: exclude_mask walk stands (passes 63 at the 9th round), but n advances by 1 per round, not 7 — additional_excluded_chns needs ~64 rounds, not 10) |
| SMS-118 | Vorbis codebook `entries * dim` (maptype 2) and maptype-1 accumulation overflow int size math | 6 | S | Low | High (READ) | STANDING |
| SMS-119 | Vorbis `res0_look`: `partvals = pow(parts, dim)` overflows int and wraps the decodemap allocation size | 6 | S | Low | High (READ) | STANDING |
| SMS-120 | Vorbis ordered codebook lengths grow past 32: `_make_words` indexes `marker[33]` by length, `oggpack_look` indexes `mask[33]` by `dec_maxlength` | 6 | S | Low | High (READ) | STANDING |
| SMS-121 | Vorbis blocksize field permits window-table index −3…9 into `vwin[8]` | 6 | S | Low | High (READ) | STANDING |
| SMS-122 | AAC ADTS/ADIF `sf_index` (12–15) stored unchecked; `window_grouping_info` indexes 12-entry sample-rate tables by it | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-123 | AAC two-step Huffman decoders use the file-influenced `offset` to index the code table *before* the size check | 6 | S | Low | High (READ) | WITHDRAWN (full verification phase 2026-11-14 — REFUTED as a live defect: the Huffman segments tile exactly; max reachable offset = last valid index on all 7 codebooks. Three-step history in §4: withdrawn in-text at filing, reopened in verification phase 1 (VERIFY-C3, rationale falsified), refuted on reachability in phase 2; the SMS-160 bounds-pairing survives as fix guidance) |
| SMS-124 | AAC `section_data`: zero-length sections write the per-section arrays at `i == 120` *before* the `i` bound check fires (short windows) | 6 | S | Low | High (READ) | STANDING |
| SMS-125 | WMA superframe `bit_offset` never bounded before re-basing the bit reader: negative size becomes a huge bit count past the packet | 6 | S | Low | High (READ) | STANDING |
| SMS-126 | DTS bit reader has no end pointer at all: decode loops can consume past the frame buffer | 6 | S | Low | High (READ) | STANDING |
| SMS-127 | AAC bit reader has no end-of-buffer check: every `SMS_GetBits`/`SMS_GetBit` reads through a 4-byte window at the cursor regardless of `m_szInBits` | 6 | S | Med | High (READ) | STANDING |
| SMS-128 | XZ size oracle `lzma2_get_uncompressed_size` performs unbounded, unvalidated index parsing: size < 12 underflows the footer pointer, `backward_size` drives the index pointer before the buffer, and the record loop walks without any length | 6 | S | Low | High (READ) | STANDING |
| SMS-129 | lwIP TCP data-offset never validated: ignored `pbuf_header` return underflows `len`/`tot_len` to ~65 KB | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-130 | lwIP UDP: a datagram shorter than the UDP header makes the "drop short packets" branch dead and can be delivered with a ~65 KB length | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-131 | SMAP received-frame length from the buffer descriptor is never clamped to the 1,540-byte pool slot before alloc + FIFO copy | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-132 | USBD descriptor walk validates only `bLength >= 2`: truncated descriptors are returned as full structs and read at fixed offsets | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-133 | Vorbis `oggpack_read`/`oggpack_look` read up to 4 bytes past the end of a packet that is not long enough to trigger the overflow exit | 6 | S | Low | High (READ) | REVISED (verification — WEAKENED: the claimed multi-byte over-read cannot occur (the total-bits test bounds every fall-through read); only a 0-bit read at endbyte == storage touches ptr[0] one byte past) |
| SMS-134 | Vorbis codebook `dim == 0` never rejected: float divide-by-zero + non-terminating quantvals search in setup | 6 | S | Low | High (READ) | STANDING |
| SMS-135 | Vorbis audio packet `mode` never checked against `modes`: NULL mode_param dereference | 6 | S | Low | High (READ) | STANDING |
| SMS-136 | Vorbis floor0 `order == 1` passes unpack, then `vorbis_lsp_to_curve`'s do-while decrements its counter through zero and walks `lsp` out of bounds | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-137 | DTS `bitalloc_huffman == 7` selects a Huffman table past the end of `bitalloc_12[5]` | 6 | S | Low | High (READ) | STANDING |
| SMS-138 | DTS cumulative Huffman scale-factor sum used as an unchecked scale-table index | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-139 | DTS LFE scale factor: 8-bit index into a 128-entry table | 6 | S | Low | High (READ) | STANDING |
| SMS-140 | DTS joint-intensity source channel up to 6 indexes a 5-entry array, and the read value bounds a write loop | 6 | S | Low | High (READ) | REVISED (verification — WEAKENED: the −1 arm is defeated by the joint_intensity[j] > 0 guard; the bounded loop only consumes bits — bit-stream desync via an intra-struct OOB read, not a steered write) |
| SMS-141 | WMA exponent VLC band length `n == 0` produces a ~2³²-iteration write loop | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-142 | WMA `sample_rate == 0` divides by zero three times during init | 6 | S | Low | High (READ) | REVISED (verification — WEAKENED: two integer divisions, not three (:1397 is float); MIPS integer div-by-zero does not trap — quotient UNPREDICTABLE, not a guaranteed crash) |
| SMS-143 | MSMPEG4 slice height can be 0 → modulo-by-zero in the decode loop | 6 | S | Low | High (READ) | STANDING |
| SMS-144 | MPEG-4 interlaced direct-MV field-time divisor can be 0 | 6 | S | Low | Med (READ; INFERRED in part) | STANDING |
| SMS-145 | MP123 gain table base + scalefactor index can exceed `s_GainPow2[378]` on the LSF (MPEG-2/2.5) path | 6 | S | Low | Med (READ; INFERRED in part) | STANDING |
| SMS-146 | FLAC wasted-bits count has no lower bound: `m_CurBPS` goes negative into the bit macros | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-147 | FLAC fixed-predictor warm-up reads `decoded[-1…-4]` for predictor orders 0–3 | 6 | S | Low | High (READ) | STANDING |
| SMS-148 | DXSB header width drives RLE writes past the scratchpad free region; packet size never validated against the header size | 6 | S | Low | High (READ) | STANDING |
| SMS-149 | MP123 region-2 start index can read past `m_LongIdx[23]` (low severity, intra-struct) | 6 | S | Low | High (READ) | STANDING |
| SMS-150 | SMSUMS `_set_dir_chain` treats a −1 chain error as a completed chain and reads `m_ClusterBuf[-1]` | 6 | S | Low | High (READ) | STANDING |
| SMS-151 | SMSUMS `_get_direntry_start_cluster` ignores the sector-data error return and loops over uninitialised locals | 6 | S | Low | High (READ; INFERRED in part) | REVISED (verification — WEAKENED: the callee writes *apStartSec before the failing chain call; only the loop extent is uninitialised, not the start sector) |
| SMS-152 | lwIP reassembly bitmap is indexed at 90 (of 0–89) when the reassembled length is exactly 5,760 | 6 | S | Low | High (READ) | STANDING |
| SMS-153 | AAC `huffman_getescape`: the escape-length counter is incremented by a file-controlled run of 1-bits with no cap, then used as a bit-read width and a shift count | 6 | S | Low | High (READ) | REVISED (verification — WEAKENED: i is uint8_t and wraps at 256 — the UB window is exit i ∈ [32,255], not an arbitrarily large counter) |
| SMS-154 | `DSP_FFTGet` loop count is built from an uninitialised register (`addiu $v0, $v0, 32` before `$v0` is ever set) | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| SMS-155 | Asm `s_GSParams` layout diverges from C `GSParams` after the 576P slot: every PAR word from offset 44 sits one slot early (latent today) | 6 | S | Low | High (READ) | STANDING |
| SMS-156 | Three fully dead assembly routines: `GS_XYZF`, `SMS_iTimerReset`, `inet_ntoa` (Cat 1) | 1 | S | Low | High (READ) | STANDING |
| SMS-157 | Four dead assembly exports whose bodies are live under a second name: `GS_RRV`, `_MPEG_AlignBits`, `ip_cksum`, `inet_aton` (Cat 1) | 1 | S | Low | High (READ) | STANDING |
| SMS-158 | SMSTCPIP `do_connect` ignores `tcp_connect`'s return: a synchronous failure hangs `netconn_connect` forever | 6 | S | Low | High (READ; INFERRED) | STANDING |
| SMS-159 | SMSTCPIP sockets layer: `get_socket` indexes the 15-entry socket table with a completely unchecked fd | 6 | S | Low | High (READ) | STANDING |
| SMS-160 | AAC two-step Huffman size arrays disagree with the actual second-stage table counts in both directions — 5 of 7 non-trivial entries are wrong, so the bound the decoders check against is not the bound that exists | 6 | S | Low | READ | STANDING |
| SMS-161 | DTS scale-factor quantizer tables end in zeros: `scale_factor_quant6[63] = 0` and `scale_factor_quant7[125..127] = 0` break a strictly increasing 63/125-entry run — the largest scale factors decode as silence | 6 | S | Low | READ; INFERRED | STANDING |
| SMS-162 | USBD host-controller init memsets through an unchecked `AllocSysMemory` result, and the failure is then hidden twice | 6 | S | Low | High (READ) | STANDING |
| SMS-163 | SMSTCPIP `lwip_close` dereferences NULL on any invalid-but-in-range fd (double close crashes) | 6 | S | Low | High (READ) | STANDING |
| SMS-164 | SMSTCPIP `do_bind` is the only API handler that does not NULL-check its PCB allocation | 6 | S | Low | High (READ; INFERRED) | REVISED (verification — WEAKENED: only the TCP branch is reachable in-tree (err_tcp NULLs the PCB, then re-bind); the UDP branches are latent — no in-tree entry path) |
| SMS-165 | USBD done-queue isochronous cleanup clears the wrong LUT slot, leaving stale IoRequest pointers | 6 | S | Low | High (READ; INFERRED) | STANDING |
| SMS-166 | SMSTCPIP `lwip_accept` uses the accepted connection and the caller's address buffers with no NULL checks | 6 | S | Low | High (READ) | STANDING |
| SMS-167 | SMSTCPIP `netbuf_ref` dereferences a possibly-NULL `pbuf_alloc` result (UDP send under pbuf exhaustion crashes) | 6 | S | Low | High (READ) | STANDING |
| SMS-168 | SMSMAP PHY reset result is discarded and the LINK flag is never cleared: a dead PHY leaves SMAP reporting link-up | 6 | S | Low | INFERRED | STANDING |
| SMS-169 | SMSMAP `_start` returns resident-end unconditionally over unchecked kernel-object creation | 6 | S | Low | High (READ; INFERRED) | STANDING |
| SMS-170 | SMSTCPIP `netconn_addr` lacks the PCB NULL check its sibling `netconn_peer` has | 6 | S | Low | High (READ; INFERRED) | STANDING |
| SMS-171 | SMSMAP transmit: chained-pbuf gather copies `tot_len` bytes into a 1,520-byte static buffer bounded only by the 4,096-byte FIFO credit | 6 | S | Low | High (READ; INFERRED) | STANDING |
| SMS-172 | Docs: the Devices/Settings pages state Start rows appear only while a device is stopped; the MX4SIO/MMCE Start rows are always shown | 7 | S | Low | READ | STANDING |
| SMS-173 | AC3 IMDCT entry points take a bias parameter that is never used; the caller's per-channel bias computation is silently dropped | 1 | S | Low | High (READ) | STANDING |
| SMS-174 | DTS integer quantizer tables `lossy_quant` / `lossless_quant` are dead: zero references repo-wide; only their float `_d` twins are ever read (256 bytes of `.data`) | 1 | S | Low | READ; INFERRED | STANDING |
| SMS-175 | SMSTCPIP dead dispatch slot: `do_accept` / `API_MSG_ACCEPT` can never be posted, and would hang its poster if it were | 1 | S | Low | High (READ) | STANDING |
| SMS-176 | SMSMAP dead helper: `_smap_emac3_ready` is defined in the SMAP header and called nowhere | 1 | S | Low | High (READ) | STANDING |
| SMS-177 | AC3 IMDCT: dead instructions in `_ifft2` (and one in `BUTTERFLY_ZERO`) are overwritten before any read | 1 | S | Low | High (READ) | STANDING |
| SMS-178 | AC3 IMDCT: `_ifft128` open-codes `_ifft64`'s entire body instead of calling it | 2 | S | Low | High (READ) | STANDING |
| SMS-179 | SMSTCPIP `err_to_errno` maps every error to EIO: the signed/unsigned comparison makes the 11-entry errno table unreachable | 6 | S | Low | High (READ) | STANDING |
| SMS-180 | USBD `initCallbackThread` never checks thread creation and returns success unconditionally; `hcdInit` discards even that — if the callback thread does not exist, no USB transfer completion is ever delivered | 6 | S | Low | High (READ; INFERRED) | STANDING |
| SMS-181 | USBD exports three stubs that report success while doing nothing: `UsbRegisterAutoloader`, `UsbUnregisterAutoloader`, `UsbChangeThreadPriority` | 8 | S | Low | High (READ) | REVISED (full verification — WEAKENED: the USBD stubs do return false success (interface.c:216-229, USB_RC_OK = 0), but the public header does disclose them — “// these aren’t implemented:” at iop/USBD/include/usbd.h:248 — defeating the “no hint” framing; the defect is the dishonest return value, not an undisclosed stub) |
| SMS-182 | SMSTCPIP `tcp_next_iss` is fully predictable: fixed seed 6510 plus the deterministic `tcp_ticks` accumulator | 6 | S | Low | READ; INFERRED | STANDING |
| SMS-183 | SMSTCPIP `lwip_getpeername` / `lwip_getsockname` ignore `netconn_peer` / `netconn_addr`'s return: a guarded error becomes a successful garbage result (and SMS-170's fix alone does not save `lwip_getsockname`) | 6 | S | Low | High (READ; INFERRED) | STANDING |
| SMS-184 | USBD `hcdInit` never checks the HCD IRQ thread's creation: `hcdTid` failure leaves USB interrupts waking a nonexistent thread while `hcdInit` returns 0 | 6 | S | Low | High (READ; INFERRED) | STANDING |
| SMS-185 | IOP CDVD `TocEntryCopy` writes the string terminator at the disc-supplied filename length, past its 129-byte field | 6 | — | — | High (READ) | STANDING |
| SMS-186 | AVI `_Load_idx1` publishes an unchecked `SMS_Realloc` result — the SMS-054 pattern in the function SMS-054 cited as the good example | 6 | — | — | High (READ) | STANDING |
| SMS-187 | `SMS_ListPushBack(...)->m_Param` unchecked dereferences at 14 further sites beyond SMS-068's filed list | 6 | — | — | High (READ) | STANDING |
| SMS-188 | `_sb_string_width` iterates one element past the string end into the unchecked glyph-width helper | 6 | — | — | High (READ) | STANDING |

### 2.5 PS2-Servers — 118 items

| ID | Title | Cat | Effort | Risk | Confidence | Status |
|---|---|---|---|---|---|---|
| PS2SERVERS-001 | UDPFS is implemented three times | 2 | L | Med | High (READ) | STANDING |
| PS2SERVERS-002 | Standalone UDPFS keeps its own CLI, parser and run loop purely as a rollback path | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-003 | RetroAchievements is a second product inside this repo: ~53k lines of vendored C, ~5.2k lines of Python, two runtimes, two modes | 8 | L | Med | High (READ) | STANDING |
| PS2SERVERS-004 | SMBv1 is implemented twice (Python and Go), with a test whose job is to keep them byte-identical | 2 | M | Med | High (READ) | STANDING |
| PS2SERVERS-005 | UDPBD is implemented three times, even though UDPFS already contains it | 2 | M | Med | High (READ; INFERRED) | STANDING |
| PS2SERVERS-006 | The GUI is customised by four stacked monkey-patch layers, one installed through an import hook | 3 | L | Med | High (READ) | STANDING |
| PS2SERVERS-007 | The version of `_append_log` inside gui.py is dead — the main.py shim replaces it before the GUI runs | 1 | S | Low | High (READ) | STANDING |
| PS2SERVERS-008 | CHD/CSO/ZSO decompression is implemented twice, in Python and Go, including the CHD CUE/BIN view | 2 | M | Low | High (READ) | STANDING |
| PS2SERVERS-009 | 159 remote branches and 118 tags, including 81 auto-generated `main-<n>-<hash>` tags and 9 `backup/*` branches | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-010 | Two release workflows (~1,100 lines) duplicate the same build/source/edge/release pipeline | 7 | M | Med | High (READ; INFERRED in part) | STANDING |
| PS2SERVERS-011 | Session-summary statistics are implemented three times, plus a private stats dict inside every server | 2 | M | Low | High (READ) | REVISED (full verification — WEAKENED: the SESSION format is implemented exactly twice, once per language (Python launcher/session_stats.py; Go internal/sessionstats), plus ~4-line record adapters per Python server — not three times plus per-server dicts; UDPFS’s private dict holds shutdown totals, a different output, and NFS does not participate at all. The filed −150-line estimate is not supported) |
| PS2SERVERS-012 | The router-status protocol is answered two different ways inside Edge, and a third way in Python | 2 | M | Low | High (READ) | STANDING |
| PS2SERVERS-013 | No single-writer exclusion in UDPFS — two peers can interleave writes to the same file, in every edition | 6 | M | Med | High (READ) | REVISED (verification — WEAKENED: Python standalone+Core only; Go Edge has writer exclusion (reserveWriter; -EBUSY) — “every edition” defeated) |
| PS2SERVERS-014 | SMB2 signing has four CMAC implementations stacked as fallbacks, plus hand-rolled MD4, AES, RC4 and SPNEGO | 3 | M | Med | High (READ) | STANDING |
| PS2SERVERS-015 | 1,608 lines of self-tests live inside the shipped server directories and duplicate the real test suite | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-016 | ~3.1 MB of binary disc-image fixtures are tracked in the Go tree, and the repo banner is tracked twice, byte-identical | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-017 | CLI/config parsing is re-implemented per server, per language, and per config format — at least nine parsers | 2 | M | Low | High (READ) | STANDING |
| PS2SERVERS-018 | Six path-containment implementations guard the shares; only one pair actually shares code | 2 | M | Med | High (READ) | STANDING |
| PS2SERVERS-019 | Verbose per-request logging is the default for every server, is force-migrated on for existing installs, and is pumped into the GUI every 150 ms | 5 | S | Low | High (READ) | STANDING |
| PS2SERVERS-020 | UDPFS send path stacks two retry systems: 10 send retries with sleeps under a global send lock, over a 200-retry window retransmit loop | 3 | S | Med | High (READ; INFERRED) | STANDING |
| PS2SERVERS-021 | UDPFS allocates a thread, a queue and up to 64 handles per unauthenticated datagram, up to 256 sessions | 5 | S | Low | High (READ; INFERRED in part) | REVISED (R3 addendum — at-cap disagreement split to PS2SERVERS-062) |
| PS2SERVERS-022 | Connection admission is capped in NFS (32) and UDPFS (256) but uncapped in SMB1, SMB2 and HTTP | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| PS2SERVERS-023 | Default posture is guest/writable/open on a server meant to be found by broadcast | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-024 | SMBv1 can stop Windows' own file-sharing service (LanmanServer) via PowerShell to take port 445 | 8 | M | Med | High (READ) | STANDING |
| PS2SERVERS-025 | Direct-link mode is a second network-administration product inside the launcher: 1,927 lines plus ~600 lines of GUI state machine | 8 | L | Med | High (READ) | STANDING |
| PS2SERVERS-026 | There are two SQLite game-library catalogues and three library UIs | 2 | L | Med | High (READ; INFERRED in part) | STANDING |
| PS2SERVERS-027 | Three separate HTTP servers serve three management/achievement pages | 2 | M | Low | High (READ) | STANDING |
| PS2SERVERS-028 | Edge's WebUI is a second management plane: ~2,050 lines plus its own config store, schema and service supervisor | 2 | M | Med | High (READ) | STANDING |
| PS2SERVERS-029 | Scope creep around the servers: Discord Rich Presence, achievement sounds, art fetching, OBS export | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-030 | `launcher/serve.py` carries a 45-module explicit import list whose only job is to appease the freezer | 3 | M | Med | High (READ) | STANDING |
| PS2SERVERS-031 | Two spellings of headless mode are kept forever: `serve` and `--serve`, normalised in two places | 3 | S | Low | High (READ) | STANDING |
| PS2SERVERS-032 | Portable-mode detection writes a probe file on every config access | 5 | S | Low | High (READ) | STANDING |
| PS2SERVERS-033 | SMB2's IPC$ carries 289 lines for exactly one RPC call | 8 | S | Med | High (READ; INFERRED) | STANDING |
| PS2SERVERS-034 | Go's only module dependency, `golang.org/x/net`, exists for one 27-line Linux batch-write file | 4 | S | Low | High (READ) | STANDING |
| PS2SERVERS-035 | Build and packaging surface: four build scripts, three init systems, Docker and OpenWrt for one app | 7 | M | Low | High (READ) | STANDING |
| PS2SERVERS-036 | Hand-rolled tray, twice, plus a third status-dot mechanism in the GUI | 2 | S | Low | High (READ) | STANDING |
| PS2SERVERS-037 | HTTP game index rescans the tree by signature on a staleness check inside request handling | 5 | S | Low | High (READ; INFERRED) | REVISED (full verification — WEAKENED: _signature_of stats every file in the scanned directories and refresh() rebuilds on change, but the sweep is throttled (RESCAN_INTERVAL = 5.0 s), runs only from the games.csv handler (lookup() deliberately never rescans), and is flat by default (root + CD/DVD) unless recursive mode is opted in; measured 0.8 ms over 300 files) |
| PS2SERVERS-038 | The "standalone" UDPBD server is not standalone: it imports the launcher package at runtime | 3 | S | Low | High (READ) | REVISED (full verification — WEAKENED: the core is executed-proven (a standalone copy of udpbd_server.py dies with ModuleNotFoundError for the launcher package at :419; its device implementations are 752 lines of launcher-package code), but the premise “every other server is self-contained” is false — http_server.py:47 imports launcher at top level (see PS2SERVERS-116) and SMB1/SMB2 import launcher.session_stats lazily in main(). Narrowed: UDPBD is the only server whose functional device implementations live in the launcher package) |
| PS2SERVERS-039 | Agent/tooling and handoff clutter tracked in the repo root and docs | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-040 | Example credential literal in the SMB2 module docstring | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-041 | Edge, measured: the WebUI is the binary — put it behind the build tag the repo's own CI already names | 4 | M | Low | High (READ) | STANDING |
| PS2SERVERS-042 | The SMB1 server contains a third SMB2 implementation that answers success without doing the work | 8 | S | Med | High (READ) | REVISED (verification — WEAKENED: fake handlers + guest bypass re-executed, but h2_tree_connect/h2_close always raise struct.error and kill the thread; h2_write reports Count=0) |
| PS2SERVERS-043 | SMB2: a read-only handle can delete any file on a writable share via SET_INFO disposition + CLOSE | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-044 | SMB1: a truncated request kills the connection thread with an uncaught struct.error | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-045 | Neither SMB framing layer caps the declared message length (24-bit, up to 16.7 MB) against the 1 MiB the servers advertise | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-046 | SMB1: open files and search snapshots per connection are uncapped — real file descriptors, held indefinitely | 5 | S | Low | High/Med (READ; INFERRED) | STANDING |
| PS2SERVERS-047 | NFS: the filehandle registry only ever grows — every path ever looked up is remembered for the server's lifetime | 4 | S | Low | High (READ) | STANDING |
| PS2SERVERS-048 | Startup: the LAN-IP detection runs a subprocess synchronously in _build, before first paint | 5 | S | Low | High (READ; INFERRED in part) | STANDING |
| PS2SERVERS-049 | Startup: ~0.4 s of imports happen before Tk exists, including subsystems the first screen never uses | 5 | S | Low | High/Med (READ; INFERRED) | STANDING |
| PS2SERVERS-050 | SMB2 FLUSH reports success when the flush/fsync failed — and is the one handler with no body-length check | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-051 | SMB2: a single compound message can chain an unbounded number of requests | 5 | S | Low | High (READ) | STANDING |
| PS2SERVERS-052 | GUI log pump: per-line string building + a Tk index() call per batch are the steady-state cost the verbose default (round-1 -019) multiplies | 5 | S | Low | High/Med (READ; INFERRED) | STANDING |
| PS2SERVERS-053 | SMB2: handles per connection are uncapped (CREATE mints forever; descriptors follow on first read/write) | 5/6 | S | Low | High/Med (READ; INFERRED) | STANDING |
| PS2SERVERS-054 | Edge's binary size is measured against three different Go toolchains — the size gate is partly measuring the compiler | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-055 | The SMB1↔SMB2 framing code exists twice (send_msg/recv_msg), despite the SMB2 module claiming it was "moved" | 2 | S | Low | High (READ) | STANDING |
| PS2SERVERS-056 | UDPFS (Python, both editions): BWRITE is never checked against the block device's size — a client can extend the operator's image at any sector and is told it succeeded | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-057 | UDPFS (Python, both editions): BWRITE completion never compares delivered bytes to the declared sector count — short writes are silently partial and reported as success | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-058 | UDPBD (Python): image files get none of the capacity validation raw devices get — WRITE extends the image, READ streams up to ~32 MiB of padding for any range | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-059 | srvsvc: the PDU body slice wraps when auth_len exceeds the declared PDU — the parser reads past frag_len instead of rejecting the PDU | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-060 | UDPFS standalone truncates over-declared DATA packets and processes them; the shipped Core and Go drop them — the rollback copy validates framing differently from the product | 2 | S | Low | High (READ) | STANDING |
| PS2SERVERS-061 | UDPBD (Go): WRITE_RDMA ownership is weaker than the Python original — cmdid is ignored and any peer on the same IP may feed blocks into another peer's write | 6 | S | Low–Med | High (READ) | STANDING |
| PS2SERVERS-062 | UDPFS (Go): at the 256-session cap Edge refuses new consoles outright, where Python evicts the least-recently-active peer — a full table of stale sessions locks real consoles out for up to the peer timeout | 5 | S–M | Low | High (READ) | STANDING |
| PS2SERVERS-063 | compressed_iso serving path trusts the file's declared block/hunk size — a 32-byte crafted CSO makes the server materialise a 256 MiB block; the strict path and Go both cap the same field at 16 MiB | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-064 | ZSO serving decompression retries LZ4 once per byte of an attacker-sized span — 100,000 decompress attempts for one 100 KB block — and can "succeed" with a zero-length block the base class then serves as data | 5 | S | Low | High (READ) | STANDING |
| PS2SERVERS-065 | CSO serving never validates a block's span: an index pair one entry apart makes it read the rest of the file as one block's input | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-066 | Both launcher block devices assign seek state before validating it — a failed seek leaves position, request end and (for raw devices) a stale cache armed for the next read | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-067 | AES-CMAC's native backend is a probe-time-only fallback: a native failure mid-session raises out of the signing path and drops the connection instead of using the pure-Python reference in the same file | 6 | S | Low | High (READ; INFERRED in part) | STANDING |
| PS2SERVERS-068 | OpenWrt service-log snapshot ignores the line bound the package documents and the systemd path honours | 4 | S | Low | High | STANDING |
| PS2SERVERS-069 | UCI boolean parsing is split in one Load function — sixteen keys misread the UCI vocabulary, including all three `read_only` keys (fail-open) | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-070 | Every shipped Edge archive tells its user the server is "read-only by default" — the binary defaults to writable | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-071 | `TestUnsolicitedWriteRDMAIsIgnored` verifies sectors 600–601, but a guard failure writes at sector 0 — the corrupting code passes the test | 8 | S | Low | High (READ) | REVISED (verification — execution qualification C-2: the offset-0 hypothetical is backstopped by a second clamp (server.go:498-500); the wrong-sector oracle defect stands; mutation run environment-blocked) |
| PS2SERVERS-072 | PS2SERVERS-068 is untestable by the Go suite as written: the only log manager under test is a fake that discards the `lines` argument, and no real manager has a test | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-073 | PS2SERVERS-069: the only UCI boolean test tests the helper the config doesn't use — the `Load` switch and the Load→Save strip path have no test at all | 8 | S–M | Low | High (READ) | STANDING |
| PS2SERVERS-074 | The "without LZ4" ZSO hash tests patch `LZ4_AVAILABLE` to **True** — they simulate presence, and the no-LZ4 behaviour is never tested | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-075 | Mid-file `unittest.main()` in two SMB test files orphans 28 tests on direct execution — and the direct run still reports green | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-076 | Path-guard selftest prints "ALL PASSED" in CI while its UNC section — one of its three pinned properties — never executes there | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-077 | The three SMB "bounded" tests assert no bound — an unbounded, leaking implementation passes all three | 8 | S | Low | High (READ; INFERRED in part) | STANDING |
| PS2SERVERS-078 | ≈52 GUI test methods assert nothing in CI: the only discovery job is headless and whole files skip at class level | 7 | M | Low | High (READ) | STANDING |
| PS2SERVERS-079 | tests/test_udpfs_bind_control.py skips in every CI run — the bind-control → `--bind` argv path gates nothing | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-080 | tests/test_chd_cd_size.py never runs in CI: libchdr is built *after* the discovery run that would collect it | 7 | S | Low | Medium | STANDING |
| PS2SERVERS-081 | The native-engine test class can skip wholesale and stay green — it lacks the CI hard-fail its sibling classes carry | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-082 | The suite's one Windows-only test never runs in CI — no Windows `go test` job exists anywhere | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-083 | The 32-bit wrap regression test never runs on a 32-bit target — the only configuration where the defect can recur | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-084 | test_desktop_instance.py's two real-mutex tests run on no CI job | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-085 | `TestInfoResetsStaleWriteState` never tests the reset — it asserts only a later read's length, which passes whether or not INFO cleared anything | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-086 | `TestServerPortFallback` asserts no port — the fallback it names could be deleted and the test would still pass | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-087 | `tryTrans2` cannot fail: it returns `nil` unconditionally while calling the helper that already `Fatal`s — its callers' error branches are dead | 1 | S | Low | High (READ) | STANDING |
| PS2SERVERS-088 | A registry-guard test's docstring describes the fake SMB2 (PS2SERVERS-042) in the present tense as the shipped behaviour — and the test does not guard that fake at all | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-089 | `test_widen_on_a_real_socket` cannot fail if widening is a no-op — a flaw the file's own docstring states verbatim | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-090 | The suite's only Python↔Go wire cross-check converts a Go timeout into a skip | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-091 | The banner address-listing test's only assertions sit in a loop over a host-dependent list that may be empty | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-092 | A hardlink test silently loses its second half: `except OSError: return` records a pass, not a skip | 8 | S | None | High (READ) | STANDING |
| PS2SERVERS-093 | A POSIX-permissions test bare-`return`s on Windows — counted as a pass with zero assertions executed | 8 | S | None | High (READ) | REVISED (full verification — WEAKENED: the bare return at test_ra_credentials.py:76-78 is real, but the filed CI consequence is refuted — no Windows job runs this module (the achievements fixed list and the windows-storage lists omit it; its only CI run is Ubuntu discovery, where the test executes fully), and the achievements matrix is 2 Windows + 1 Ubuntu + 2 macOS, not “both Windows”. Survives as a latent one-line hygiene defect: if ever run on Windows, the POSIX-permissions test would report a phantom pass instead of a visible skip) |
| PS2SERVERS-094 | The companion-fixture link/locked assertions exist only inside `if self.made[…]` conditionals — a degraded fixture passes silently | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-095 | Two unguarded assertion loops pass over an empty collection — the suite's own "guard the guard" pattern, missing in its last two places | 8 | S | None | High (READ) | STANDING |
| PS2SERVERS-096 | Two SMBv1 tests assert only the constructor assignment they just made, under names claiming wire behaviour they never exercise | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-097 | multiclient_selftest's concurrency test has a `return True` "SKIP" branch that would aggregate into "ALL PASSED" | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-098 | The supervisor's state-HTTP probe swallows every exception, so its only failure signal is an unexplained empty box | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-099 | The HTTP hot-path cost guard does not watch `os.scandir`, which the same module's scan paths use | 8 | S | Low | Medium | STANDING |
| PS2SERVERS-100 | `inRange` is genuinely boundary-tested — except the two cases its arithmetic makes interesting | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-101 | Source-text tests that pass on a string anywhere in the file, including dead code | 8 | M | Low | High (READ) | STANDING |
| PS2SERVERS-102 | The About-page version-label expectation is built from the module under test | 8 | S | Low | High (READ) | STANDING |
| PS2SERVERS-103 | The suite's only fuzz target is never fuzzed — CI runs its three seed inputs as an ordinary test | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-104 | ≈120–150 lines of UDPFS test scaffolding are duplicated across the Go test package — one protocol string exists in three copies | 2 | M | Low | High (READ) | WITHDRAWN (full verification phase 2026-11-14 — REFUTED: FABRICATED CITATIONS — cited files/functions do not exist at the pin) |
| PS2SERVERS-105 | SMBv1's request-handler helpers are copy-pasted across three Python test files (~93 lines of test glue reading the *same* production module) | 2 | S | Low | High (READ) | WITHDRAWN (full verification phase 2026-11-14 — REFUTED: FABRICATED CITATIONS — cited files/functions do not exist at the pin) |
| PS2SERVERS-106 | The headless-GUI scratch-environment `setUp` is copy-pasted across five test files; one file pastes its Tk guard into all nine methods | 2 | M | Low | High (READ) | REVISED (full verification — WEAKENED: the scratch-environment setUp is duplicated in exactly 2 files (test_about_page.py:86-108 ≈ test_settings_feedback.py:24-46), not 5 — the census overcounts by 2.5×; launcher.main_gui() does not exist and the claimed directlink helper is an import block. The 9-fold Tk guard sub-claim holds exactly) |
| PS2SERVERS-107 | The native-engine/CDLL boilerplate is duplicated between the RA evaluator and owned-service test files; the CI hard-fail guard is pasted five times | 2 | S | Low | High (READ) | STANDING |
| PS2SERVERS-108 | The same fake urllib `Opener` class is redefined 15 times across three RA test files | 2 | S | Low | High (READ) | STANDING |
| PS2SERVERS-109 | The supervisor start/request/ready scaffolding is duplicated verbatim inside test_ra_owned_service.py | 2 | S | Low | High (READ) | WITHDRAWN (full verification phase 2026-11-14 — REFUTED: FABRICATED CITATIONS — cited files/functions do not exist at the pin) |
| PS2SERVERS-110 | compression_selftest's extension→codec map duplicates test_udpfs_config's, and its COMPRESS-branch coverage is platform-dependent | 2 | S | Low | High (READ) | WITHDRAWN (full verification phase 2026-11-14 — REFUTED: FABRICATED CITATIONS — cited files/functions do not exist at the pin) |
| PS2SERVERS-111 | One OPL HTTP runner test is a strict subset duplicate of the next | 2 | S | None | High (READ) | WITHDRAWN (full verification phase 2026-11-14 — REFUTED: FABRICATED CITATIONS — cited files/functions do not exist at the pin) |
| PS2SERVERS-112 | Dead import: `from smb2_server.smbprotocol_mock import Client` — never referenced | 1 | S | None | High (READ) | STANDING |
| PS2SERVERS-113 | One vendored xeRAbora modification is undocumented: sound.c's shell-command escaping hardening appears in neither the vendor README nor the upstream-audit doc | 7 | S | Low | High (READ) | STANDING |
| PS2SERVERS-114 | SMB1 server's embedded SMB2: TREE_CONNECT and CLOSE always raise `struct.error` and kill the connection thread — on well-formed requests | 6 | S | Low | High (READ) | STANDING |
| PS2SERVERS-115 | SMB1 server's embedded SMB2: the SMB2 header packer/parser is 66 bytes, not 64 — `Command` is encoded as a 4-byte field | 6 | S | Low | High (READ; INFERRED) | STANDING |
| PS2SERVERS-116 | HTTP server is not standalone either, and its launcher import is unconditional | — | — | — | — | STANDING |
| PS2SERVERS-117 | The achievements-engine CI step's fixed module list omits `tests.test_ra_credentials` | — | — | — | — | STANDING |
| PS2SERVERS-118 | Blanket `# noqa: F401` at test_smb2_libsmb2_compat.py:26 hides the one genuinely dead import | — | — | — | — | STANDING |

### 2.6 Cross-repo — 59 items

| ID | Title | Cat | Effort | Risk | Confidence | Status |
|---|---|---|---|---|---|---|
| X-01 | Every PS2 program ships every language to every user | — | — | — | — | CROSS-REF |
| X-02 | The same media stored as GIF *and* MP4, and generated docs committed as product | — | — | — | — | CROSS-REF |
| X-03 | Branch and tag sprawl (LIST only, per brief — nothing deleted by this audit) | — | — | — | — | CROSS-REF |
| X-04 | Tests that grep source text instead of testing behaviour | — | — | — | — | CROSS-REF |
| X-05 | .BAK / backup copies as a design habit | — | — | — | — | CROSS-REF |
| X-06 | POPSTARTER binaries duplicated within and across repos | — | — | — | — | CROSS-REF |
| X-07 | UDPFS: three copies in RiptOPL's IOP tree, three editions in PS2-Servers | — | — | — | — | REVISED (full verification — WEAKENED: the PS2-Servers half (three UDPFS editions) and Launchstation’s precompiled IRX stand, but the RiptOPL headline falls — the per-edition udpfs_core.c/udprdma.c are 122–125 B #include shims into udpfs_shared, not copies (the round-2 correction to RIPTOPL-008); what is triplicated is the header set (6 headers ×3; mprintf.h ×5). Survives as header triplication + three server editions + one precompiled IRX. Was a pass-1 cross-reference (CROSS-REF) until this pass) |
| X-08 | SMB implemented over and over, on both sides of the wire | — | — | — | — | CROSS-REF |
| X-09 | The per-device launch leg, copy-pasted | — | — | — | — | CROSS-REF |
| X-10 | iLink / IEEE 1394 carried end-to-end everywhere for a port almost no console uses as a game source | — | — | — | — | CROSS-REF |
| X-11 | Legacy parallel stacks kept for one flag / one build variant | — | — | — | — | CROSS-REF |
| X-12 | Unsafe string handling is pervasive in every C codebase (one finding per repo, counts are the point) | — | — | — | — | CROSS-REF |
| X-13 | Config/settings implemented more than once per program | — | — | — | — | CROSS-REF |
| X-14 | Byte-identical files and agent/meta clutter inside the trees | — | — | — | — | CROSS-REF |
| X-15 | Watcher/publisher workflow sprawl | — | — | — | — | CROSS-REF |
| X-16 | Second products living inside first products | — | — | — | — | CROSS-REF |
| X-17 | Launchstation still carries the file-based update design #384 replaced, as test-only dead code | 1 | S | Low | High (READ) | CROSS-REF (→ LAUNCHSTATION-041 — same-round core duplicate, census D-13) |
| X-18 | Launchstation writes a `title.cfg` dialect RiptOPL silently cannot read — app never appears (WORST new bug) | 6 | S | Low | High (READ) | REVISED (verification — WEAKENED: chain exact for the dash_apps.c Edit-metadata starter only; the second writer (filer_actions.c:1924 make_title_cfg, unspaced) is correct) |
| X-19 | One IOP module links two MD4s and two MD5s (RiptOPL and Launchstation, same module both times) | 2 | M | Med | High/Med (READ; INFERRED) | STANDING |
| X-20 | Launchstation EE links mbedTLS SHA-256 and a hand-rolled SHA-256 in the same binary | 2/4 | S | Med | High (READ) | STANDING |
| X-21 | File-copy failure handling: SMS leaves truncated copies indistinguishable from complete ones, in every path | 6 | S | Low–Med | High (READ) | REVISED (full verification — WEAKENED: every named streaming copy path and all four SMS sub-defects confirm, but “in every path” is falsified by SMS’s _copy_file_to_mc (GUIFileCtxMenu.c:143-196), a buffered import path that deletes the destination on write failure — survives for every streaming path; the fix’s scope shrinks by one path that already behaves) |
| X-22 | Intra-binary duplicate machinery found at function level (three small pure deletions) | 2 | S | Low | High/Med (READ; INFERRED) | STANDING |
| X-23 | PS2-Servers CMAC: four implementations behind one dispatcher, re-verified at Round-2 head | 3 | S | Low | High/Med (READ) | CROSS-REF (→ PS2SERVERS-014 — revalidation converted to cross-reference, census D-15) |
| X-24 | Network-init constants have speciated — including inside one repo | 3/5 | S | Low | High (READ) | STANDING |
| X-25 | Config-parser consolidation that actually pays: Launchstation 4 → 2, POPSLoader ~27 sites → 1 helper | 2/3 | M | Med | High (READ) | STANDING |
| X-26 | One malformed line silently amputates Launchstation's main CNF — and the next save makes it permanent | 6 | S | Low | High (READ) | STANDING |
| X-27 | POPSLoader config semantics invert the family on both axes (first-wins + save-deletes-unknowns) | 6/3 | S | Low | High (READ; INFERRED in part) | STANDING |
| X-28 | RiptOPL carries the same CRC-32 text three times, and two CRC-32-family functions in one EE binary | 2 | S | Low | High (READ) | STANDING |
| X-29 | SMS's positional SMB list has no resync — one blank line shifts every record | 6 | — | — | High (READ) | STANDING |
| X-30 | Self-update trust/policy divergences that should be decisions, not accidents | 6/3 | S | Low | High (READ) | STANDING |
| X-31 | RiptOPL's UDPRDMA receive path copies a wire-controlled app header into an 8-byte stack buffer, unchecked — SMS's fork of the same file has the clamp | 6 | S | Low | High (READ) | STANDING |
| X-32 | The two C UDPRDMA/UDPFS forks carry disjoint hardening — each is missing fixes the other already has | 2/6 | S–M | Low | High (READ) | STANDING |
| X-33 | The three server editions honour three different limit sets — and the Python editions honour none of the header's | 6/3 | S | Low | High (READ) | STANDING |
| X-34 | Identical UDPFS packets get different outcomes from the two server languages (handle 0, block range, write completion) | 6 | M | Med | High (READ) | STANDING |
| X-35 | SMS is the only PS2 repo whose main config save is never change-gated — and it fires as a side effect of unrelated operations | 5/4 | S | Low | High (READ) | STANDING |
| X-36 | SMS carries two UDPFS front-ends it never builds (bd + fhi, 267 lines) | 1/7 | S | Low | High (READ) | STANDING |
| X-37 | DiscHeader bytes 2–3: "reserved, must be 0" in the C spec, a live data port in the Python server | 6/8 | S | Low | High (READ) | STANDING |
| X-38 | Go Edge zeroes all timestamps and attrs in UDPFS replies the other editions fill | 6/8 | S | Low | High (READ) | STANDING |
| X-39 | POPSLoader pays triple-write atomicity for a disposable cache and a single direct write for the same-format HDD cache | 4/5 | S | Low | High (READ) | STANDING |
| X-40 | Launchstation rewrites DASHAPPS.CNF on every app launch; RiptOPL's equivalent launch save writes nothing | 5 | S | Low | Med (READ; INFERRED) | STANDING |
| X-41 | The ps2build SDK machinery is one codebase hand-copied across two repos — identical pins, doubled maintenance | 2 | S | Low | High (READ) | STANDING |
| X-42 | `actions/checkout` is pinned at six different generations across the family — including three inside POPSLoader | 7 | S | Low | High (READ) | STANDING |
| X-43 | The same ps2dev toolchain image is pinned three incompatible ways — and POPSLoader's is a mutable tag | 7 | S | Low | High (READ) | STANDING |
| X-44 | Only RiptOPL's CI enforces formatting — Launchstation and SMS own `.clang-format` files no workflow runs | 7 | S | Low | High (READ) | STANDING |
| X-45 | Release machinery: PS2-Servers prunes its auto-tags; POPSLoader's official-release workflow is hard-coded to version 1.4.4; SMS's rolling tag is raced by two workflows | 7/8 | S | Low | High (READ) | REVISED (full verification — WEAKENED: PS2-Servers’ auto-tag pruning and POPSLoader’s hard-coded “1.4.4” release workflow verify fully, but the SMS half falls in part — the destructive rolling-tag race is already mitigated in-tree at the pin (in-place update, per-family concurrency groups, converter retry-wait), so the prescribed single-writer fix is largely obsolete; survives as a two-repo finding) |
| X-46 | The docs-palette fan-out: one design decision = ~35 commits and 15 PRs, because the design lives as five (in SMS, six) copies with no shared source | 2 | M | Low | High (READ) | STANDING |
| X-47 | SMSTCPIP lives as two diverged forks (RiptOPL hardened, SMS pristine) with no cross-port route — the X-32 pattern on a second stack | 2 | S | Low | High (READ) | STANDING |
| X-48 | Wiki publishing is implemented four times — three hand-rolled YAML copies and one tested program | 2/7 | S | Low | High (READ) | STANDING |
| X-49 | The ds34 defect pair is family-wide: 4 of 5 BT copies send 29 bytes of uninitialised stack, 8 of 10 copies index the battery table unbounded — and the two fixes exist in-family, in different lineages, neither propagated | 6 | S | Low | High (READ; INFERRED) | REVISED (verification — WEAKENED: census tallies exact, but the union sentence is refuted by RiptOPL pademu ds34usb.c (carries neither defect) — true union 9/10 carry ≥1 defect, 1 carries none) |
| X-50 | mcman validation: the family's best card parser and its worst are in the same repo — Launchstation's EE viewer holds all three checks its IOP vmcman lacks, and RiptOPL holds the family's best gate | 6/2 | S | Low | High (READ) | STANDING |
| X-51 | Rumble-strength scaling is split by lineage, not by repo: every pademu copy scales `rrum * 255`, every standalone copy passes it raw — in both transports, in both repos that carry pademu | 2 | S | Low | High (READ; INFERRED) | STANDING |
| X-52 | Checked-in generated artefacts have no drift gate in Launchstation or SMS — the checks exist (or are proven byte-stable) but nothing runs them | 7 | S | Low | High (READ) | STANDING |
| X-53 | Launchstation's dashboard font artefacts cannot be regenerated from the repo — their TTF inputs are not tracked | 7 | S | Low | High (READ) | STANDING |
| X-54 | SMS checks in 18 IOP modules twice — the plain `.irx` copies are byte-identical to the `.irx.xz` payloads and nothing reads them | 1 | S | Low | High | REVISED (full verification — WEAKENED: 19/19 .irx.xz payloads decompress byte-identical to the plain .irx copies (286,561 B exact) and build/CI consume only the .xz forms, but “nothing reads them” falls — tools/compress_irx.py reads every plain .irx as the regeneration path. The dead-duplication defect and the deletion fix stand, narrowed from “unreferenced” to “no build-time consumer; they are regeneration inputs”) |
| X-55 | The POPSTARTER "versions" are one binary patched in a single dword — and the default ELF is the DEBUG-flagged build | 8 | S | Low | High/Medium (INFERRED) | STANDING |
| X-56 | RiptOPL's `drvtif-ingame.irx` has been a byte-copy of `drvtif.irx` since its introduction — the in-game DECI2 flavour embeds the UI module | 8/1 | S | Low | High/Medium (READ; INFERRED) | STANDING |
| X-57 | The BDMAssault `.udpfs` pair ships in both repos with no provenance record anywhere — and one half is an undocumented second name for the documented usbexfat bytes | 7 | S | Low | High (INFERRED in part) | WITHDRAWN (full verification phase 2026-11-14 — REFUTED: POPSLoader PROVENANCE.json records both .udpfs files — headline false as filed; residue filed as X-59) |
| X-58 | RiptOPL's PC-tool CRC-32 copies retain the signed-byte negative-index read the EE copy fixed | 6 | S | Low | High (READ) | STANDING |
| X-59 | RiptOPL's BDMAssault PROVENANCE.md omits the .udpfs pair it ships | 7 | S | Low | High (READ) | STANDING |

---

## 3. Action view

### 3(a) Quick wins — STANDING findings with S-class effort and Risk Low

Rule applied mechanically, exactly as specified: status STANDING, **Risk exactly `Low`**, and effort in the S class. The rounds write S-class effort in several vocabularies — `XS` and `S` everywhere, plus Launchstation Round 5’s `Trivial`, `One character`, `One token`, `One line`, `3 lines`, `~3 lines` — all are counted as S-class here and the wording is shown in the table so nothing is hidden by the grouping. REVISED findings are excluded even when their fields qualify (their fix text has changed; see §4). **810 findings** qualify (RiptOPL 363, Launchstation 132, POPSLoader 86, SMS 129, PS2-Servers 72, Cross-repo 28). Rows whose source gives no Effort or Risk value cannot qualify mechanically: **41 rows** carry at least one `—` field (itemised in §5) and every one of them lacks Effort and/or Risk, so all 41 are excluded on that ground alone, in addition to the status-based exclusions. This is deliberately *not* the SUMMARY’s curated 15-item pass-1 quick-win list; it is the full mechanical set across all nine rounds, which is large because the audit’s fixes are mostly small deletions by design (LESS, NOT MORE).

**RiptOPL — 363 quick wins**

| ID | Title | Cat | Effort |
|---|---|---|---|
| RIPTOPL-004 | 273 remote branches, 225 of them claude/* agent branches | 7 | S |
| RIPTOPL-009 | Twelve workflows, 2,220 lines, six of them scheduled watchers/publishers | 7 | S |
| RIPTOPL-010 | Six POPSTARTER variants ship in the bundle, including three DEBUG builds | 8 | S |
| RIPTOPL-015 | sysDeleteFolder uses a malloc'd path without checking the allocation | 6 | S |
| RIPTOPL-017 | sprintf into 32/64-byte buffers in OSD history handling | 6 | S |
| RIPTOPL-022 | Korium theme assets are stored as a zip inside the repo and unzipped at build time | 7 | S |
| RIPTOPL-023 | AGENTS.md and CLAUDE.md are the same file twice | 2 | S |
| RIPTOPL-024 | audio/bgm.ogg: a 324 KB track kept "only as a reference" — and a second, different copy in the ship bundle | 7 | S |
| RIPTOPL-025 | Seventy docs files including dated checkpoint/plan archaeology | 7 | S |
| RIPTOPL-027 | The NBD server is embedded in every build, including every Lite build | 8 | S |
| RIPTOPL-034 | Commented-out and legacy code markers in first-party code | 1 | S |
| RIPTOPL-035 | README is 1,116 lines and doubles as the manual, the changelog and the feature spec | 7 | S |
| RIPTOPL-036 | Diagnostic build holds a static screen for a full 8 seconds | 5 | S |
| RIPTOPL-037 | NBNS receive thread can be overflowed by any host on the LAN | 6 | S |
| RIPTOPL-038 | smbman-ra copies the server-supplied filename length with no bound | 6 | S |
| RIPTOPL-039 | MMCE game-ID is `strcpy`'d unbounded in both directions | 6 | S |
| RIPTOPL-041 | cdvdman `.PSS` check indexes before the buffer for short filenames | 6 | S |
| RIPTOPL-042 | APA ioctl2 handlers index the partition table with an unchecked caller-supplied index | 6 | S |
| RIPTOPL-043 | UDPFS trusts the server's per-read result count without clamping it to the request | 6 | S |
| RIPTOPL-045 | Streaming DMA wait is an empty busy-spin, next to code that was fixed for doing exactly that | 5 | S |
| RIPTOPL-048 | UDPFS headers are still stored three times (the corrected remainder of RIPTOPL-008) | 2 | S |
| RIPTOPL-052 | ~370 lines of deliberately unreachable partition-editing machinery in the shipped APA driver | 1 | S |
| RIPTOPL-055 | Per-pixel busy-wait inside the IGS colour-conversion loops | 5 | S |
| RIPTOPL-057 | mmce_fs devctl dereferences `arg` unchecked in four cases, beside a fifth case that validates it | 6 | S |
| RIPTOPL-058 | MMCE filesystem ops truncate every filename length into a u8 | 6 | S |
| RIPTOPL-059 | Five near-identical number-to-string converters in igs_api.c | 2 | S |
| RIPTOPL-061 | SOS PAL patch branch is dead: the hook install is commented out, the hook's PAL half remains | 1 | S |
| RIPTOPL-062 | mmce_fs_write returns the card's byte count unclamped; mmce_fs_read clamps it | 6 | S |
| RIPTOPL-063 | NIBBLE2CHAR produces 'k'–'p' for nibbles 10–15 | 6 | S |
| RIPTOPL-065 | ra_disc_us in raudp.c is a write-only counter | 1 | S |
| RIPTOPL-066 | BT DS4 output report: buffer zeroed with the DS3 length, sent with the DS4 length — in both Bluetooth copies | 6 | S |
| RIPTOPL-067 | ps2ips `do_setsockopt` copies an EE-supplied length into a 128-byte stack buffer with no bound | 6 | S |
| RIPTOPL-068 | cdvdman `atad.c`: the PIO transfer function returns success before transferring anything; ~45 lines below it are unreachable | 6 | S |
| RIPTOPL-069 | mcemu trusts the card spec's PageSize against fixed 512-byte data / 32-byte ECC buffers | 6 | S |
| RIPTOPL-070 | SMB share-picker trusts the IOP's returned share count against a 128-entry stack array | 6 | S |
| RIPTOPL-071 | Ethernet link-mode from the config file indexes a 4-entry table in ee_core with no range check | 6 | S |
| RIPTOPL-072 | mcemu accepts any page number from the game packet; CardSize is never used as a bound | 6 | S |
| RIPTOPL-073 | Network IP strings are parsed with unchecked `sscanf` at six sites, unlike the validating RA parser in the same file | 6 | S |
| RIPTOPL-074 | smb_fio's shared path scratch buffers are filled before the I/O lock is taken | 6 | S |
| RIPTOPL-075 | smb_fio dereferences the file handle before (or without) any NULL check in five entry points | 6 | S |
| RIPTOPL-076 | apa `apaGetFormat` dereferences an unchecked cache allocation | 6 | S |
| RIPTOPL-077 | `usb_mass_connect` re-reads descriptors with none of `usb_mass_probe`'s NULL checks | 6 | S |
| RIPTOPL-079 | config.path MC mirror creates the OPL folder on the wrong card | 6 | S |
| RIPTOPL-080 | ps2ips `do_accept` / `do_getsockname` / `do_getpeername` pass an uninitialised `addrlen` and copy the address struct even on failure | 6 | S |
| RIPTOPL-081 | udpfs_ioman open handles keep their pre-disconnect server handle numbers across a watchdog reconnect | 6 | S |
| RIPTOPL-082 | mcemu Sio2McEmu writes fixed/derived response lengths never checked against the packet's own transfer length | 6 | S |
| RIPTOPL-083 | Pademu USB: `ds34usb_init` never initialises `outEndp` to −1, so the first connection never opens the output endpoint | 6 | S |
| RIPTOPL-084 | Theme catalog entry allocations are used without a NULL check | 6 | S |
| RIPTOPL-085 | `smb_lseek64`: SEEK_END ignores its offset, and no seek is floored at zero | 6 | S |
| RIPTOPL-087 | `apaFindPartition` converts a chain-walk I/O error into a clean "not found" — and one live caller then returns success with an unfilled stat | 6 | S |
| RIPTOPL-088 | `smb_devctl` validates neither buffer length; Echo/GetShareList trust caller length/address fields | 6 | S |
| RIPTOPL-089 | The last two unbounded `sprintf` calls in the EE sources build the games.bin path into a 256-byte stack buffer | 6 | S |
| RIPTOPL-091 | `bdmIsReadOnlyPath` parses the mass unit with the unbounded accumulate that `bdmParseBootStem` — in the same file — explicitly fixed | 6 | S |
| RIPTOPL-092 | Standalone ds34 copies index `power_level[]` with the unguarded device-supplied battery byte; pademu copies guard it | 6 | S |
| RIPTOPL-093 | SMAP: the DEV9 capability check is a no-op in both neutrino copies (operator precedence); the ingame copy has the correct form | 6 | S |
| RIPTOPL-094 | `smb_dread` can hand the EE an unterminated directory name | 6 | S |
| RIPTOPL-095 | A libconfig group header whose name is too long leaves the *previous* group in force, mis-filing following scalars | 6 | S |
| RIPTOPL-096 | UDPFS theme discovery latches on a possibly partial root listing; its two sibling discovery functions refuse to | 6 | S |
| RIPTOPL-098 | mcemu `hookDmac_request` dereferences `_SysAlloc`'s result unchecked, and a repeated sio2in request leaks the packet | 6 | S |
| RIPTOPL-099 | usb_mass transfer callback trusts the reported byte count; `remaining` can underflow into an unbounded transfer | 6 | S |
| RIPTOPL-100 | ps2ips `do_getsockopt` always copies 128 bytes into the reply, whatever the call actually returned | 6 | S |
| RIPTOPL-101 | The config save's restore path writes the snapshot back with a single unchecked `write()` and logs success unconditionally | 6 | S |
| RIPTOPL-102 | `ConfigSet::getColor` reports success for a malformed colour value | 6 | S |
| RIPTOPL-103 | `thmGetTexture` dereferences `gTheme` with no NULL guard, unlike every sibling accessor | 6 | S |
| RIPTOPL-104 | `ConfigSet::clone` drops the set's on-disk format, silently breaking format inheritance for the clone | 6 | S |
| RIPTOPL-105 | Standalone BT: the pressure-emulation flag is global, sticky, and cross-pad | 6 | S |
| RIPTOPL-106 | `get_data` memcpy length is unchecked in all four ds34 copies; only the pademu copies expose a variable length | 6 | S |
| RIPTOPL-107 | Pademu ds34 copies dropped the standalone port guards on every public entry point; pademu USB `set_mode` also dropped the semaphore | 6 | S |
| RIPTOPL-108 | ds34 report-input guards present in some copies only: standalone BT has no minimum-length check; standalone USB DS3 lacks the null-report rejection | 6 | S |
| RIPTOPL-109 | Standalone USB: the DS3 enable report is staged in the shared `usb_buf` that `LEDRumble` wipes immediately afterwards, with no completion wait | 6 | S |
| RIPTOPL-110 | Standalone USB `ds34usb_set_bdaddr`: the DS4 pairing report sends 24 bytes; byte 23 is never written | 6 | S |
| RIPTOPL-111 | Pademu BT: the charging-blink flag `oldled[3]` is set in `hid_readReport` but never cleared there (DS3 and DS4) | 6 | S |
| RIPTOPL-112 | Pademu USB `ds34usb_get_data` overwrites its analog-mode return value with the LED/rumble transfer result | 6 | S |
| RIPTOPL-113 | Pademu BT: fake-DS3 LED reports lost the fake transaction header (0xA2) in the port | 6 | S |
| RIPTOPL-115 | `usb_bulk_get_max_lun` returns an uninitialised, signed byte when the device answers short | 6 | S |
| RIPTOPL-119 | SMAP: in both neutrino copies `HandleRxIntr` never counts a packet, so the link-check suppression both `smap.c` copies implement is dead | 6 | S |
| RIPTOPL-120 | The `config.path` bootstrap redirect is rewritten non-atomically (O_TRUNC, two writes, unchecked close), and the write leg is duplicated | 6 | S |
| RIPTOPL-124 | `FavSource::image` rescans the whole favourites store from zero for every art request — the sibling lookup in the same file already has the fix | 5 | S |
| RIPTOPL-125 | `bdmHDDIsPresent` can burn its timeout twice on one call, on the settings-save path | 5 | S |
| RIPTOPL-134 | One Neutrino resolve can probe the same 8 memory-card candidates twice, from three overlapping variant tables | 2 | S |
| RIPTOPL-135 | `vcdGetFileSize` and `vcdSourceFileSize` are the same function written twice, one a superset of the other | 2 | S |
| RIPTOPL-138 | Both cdvdman ATAD variants: `sceAtaInit` returns a device-info struct that nothing ever populates | 1 | S |
| RIPTOPL-139 | A permanent 4 KB static buffer to streaming-search an 8-byte magic | 4 | S |
| RIPTOPL-140 | `bdmDeviceIsATA` stack-allocates a whole per-device struct to hold one 32-byte driver string, and double-checks the match | 4 | S |
| RIPTOPL-141 | `VCD_ID_PROBE_BUDGET` is dead: the scan-time probe budget it names no longer exists | 1 | S |
| RIPTOPL-142 | Self-described unreachable clamp in the VCD scan loop | 1 | S |
| RIPTOPL-143 | `sbReadList` carries a commented-out size calculator and a dead re-normalisation | 1 | S |
| RIPTOPL-144 | `thmLoadResource`'s `psm` parameter is dead: accepted at ~10 call sites, never used | 1 | S |
| RIPTOPL-145 | GetSMBServerReply receives whatever length the server's session header claims, into a 4,224-byte static buffer | 6 | S |
| RIPTOPL-146 | smb_ReadAndX trusts the response's DataOffset and DataLength — both overflow, one into the caller's buffer | 6 | S |
| RIPTOPL-147 | APA journal restore trusts the on-disk entry count and replays to unvalidated sectors | 6 | S |
| RIPTOPL-149 | HDD device trusts the on-disc APA header's partition count — stored truncated into a `u8`, then used to walk a 65-entry table | 6 | S |
| RIPTOPL-151 | iso2opl trusts SYSTEM.CNF sizes and strings from the ISO in three places — a crafted ISO overflows a global buffer, a stack buffer, and dereferences NULL | 6 | S |
| RIPTOPL-152 | VMC-sourced save and file names are never validated, and the folder export writes them into filesystem paths | 6 | S |
| RIPTOPL-153 | Negotiate copies the server's KeyLength (up to 255) into an 8-byte field | 6 | S |
| RIPTOPL-154 | smb_QueryPathInformation casts structures at the response's unchecked DataOffset | 6 | S |
| RIPTOPL-155 | isofs `TocEntryCopy` writes the terminator at the disc-supplied filename length, past its 129-byte field | 6 | S |
| RIPTOPL-156 | Assault SCSI layer silently truncates LBAs at 2^32 sectors — no READ CAPACITY 16 / READ\|WRITE 16 | 6 | S |
| RIPTOPL-157 | mcemu HDD backend: a page that maps to no APA fragment is silently translated to sector 0 — the APA header sector | 6 | S |
| RIPTOPL-158 | SYSTEM.CNF boot token of ≥64 printable chars is returned unterminated | 6 | S |
| RIPTOPL-160 | GPT parser never validates an entry's extent: reversed or off-device ranges become huge partitions | 6 | S |
| RIPTOPL-161 | MBR sanity check is half tautology, and partition extents are never checked against the device | 6 | S |
| RIPTOPL-162 | pademu assumes every SIO pad transfer is at least a full command long — short transfers overrun `in`/`out` | 6 | S |
| RIPTOPL-163 | `scsi_warmup` accepts any non-zero sector size a device reports; the size prints can divide by zero and every transfer length is `sectorSize × count` in 32 bits | 6 | S |
| RIPTOPL-165 | ps2link `pkoSendSifCmd` copies up to 4 bytes past `rpc_data[1024]` on a full-size command packet | 6 | S |
| RIPTOPL-166 | ps2link `pkoExecIop` walks argument strings with a network-supplied `argc` and no bound | 6 | S |
| RIPTOPL-167 | ps2link `pko_read_file` trusts the peer's `nbytes` over the caller's buffer size | 6 | S |
| RIPTOPL-168 | ziso.py: decompression trusts the ZSO header — block size, alignment and index length are unvalidated | 6 | S |
| RIPTOPL-169 | Volume-index guards use `>` instead of `>=` (and miss negatives), admitting a one-past-the-array access | 6 | S |
| RIPTOPL-170 | `fs_ioctl2` `USBMASS_IOCTL_GET_LBA` dereferences a NULL block device — the one sibling case the in-file fix missed | 6 | S |
| RIPTOPL-171 | BDM VMC exports dereference `g_bd` with no NULL check — the only unguarded `g_bd` uses in the file | 6 | S |
| RIPTOPL-172 | iLinkTrFree / iLinkGetNodeTrSpeed / iLinkSetNodeTrSpeed index TransactionContexts with no range check — in both copies | 6 | S |
| RIPTOPL-173 | imgdrv's `read_fs` has no offset and no bound against the image size it serves | 6 | S |
| RIPTOPL-174 | System-data icon.sys is written 1776 bytes from a 964-byte icon array | 6 | S |
| RIPTOPL-175 | `readFileBuffer` memcpy's into an unchecked `malloc` on the language-file path | 6 | S |
| RIPTOPL-176 | Theme-element initialisers dereference unchecked allocations throughout themeelems.cpp | 6 | S |
| RIPTOPL-177 | `apaJournalRestore` dereferences a possibly-NULL cache allocation | 6 | S |
| RIPTOPL-178 | MBR/GPT connect paths accept a zero/short sector read as success and parse the scratch buffer anyway | 6 | S |
| RIPTOPL-179 | The unplug NULL-priv guard covers scsi warmup commands but not `scsi_cmd_rw_sector` or the read/write chunk loops | 6 | S |
| RIPTOPL-180 | UDPBD takes its block-device geometry from the INFO reply with no sanity check | 6 | S |
| RIPTOPL-181 | opl2iso takes the output filename from raw ul.cfg bytes — a name containing `/` or `..` writes outside the CD/DVD folder | 6 | S |
| RIPTOPL-182 | A 32-character game name is stored unterminated in ul.cfg, and the duplicate check then compares past the field | 6 | S |
| RIPTOPL-183 | iso2opl builds every output path with `sprintf` into 256-byte buffers from an unbounded drive argument | 6 | S |
| RIPTOPL-184 | Assault BuildConfigurationROM publishes an uninitialized VendorID quadlet | 6 | S |
| RIPTOPL-185 | Three MMCE command builders transmit uninitialised stack bytes as packet padding | 6 | S |
| RIPTOPL-186 | iremsndpatch rewrites a module found by numeric ID alone — no identity or size check before eleven fixed-offset writes | 6 | S |
| RIPTOPL-187 | ds34 EE clients copy `rpcbuf` to the caller even when the RPC failed | 6 | S |
| RIPTOPL-188 | RetroGEM GameID reader seeks to disc-supplied LBAs with 32-bit offset arithmetic and no bound against the image size | 6 | S |
| RIPTOPL-189 | ratls compares HTTP transfer/content token values case-sensitively, while header names are matched case-insensitively | 6 | S |
| RIPTOPL-190 | Partition notification dereferences `strchr(gOPLPart, ':') + 1` with no NULL check | 6 | S |
| RIPTOPL-191 | lngGetFilePath indexes languages[langID-1] with no range check | 6 | S |
| RIPTOPL-192 | usbd (inherited PS2SDK): the isochronous halted-endpoint cleanup clears the wrong TD→request LUT slot | 6 | S |
| RIPTOPL-193 | usbd (inherited PS2SDK): initialisation failures are swallowed at every level, and the main pool allocation is never NULL-checked | 6/8 | S |
| RIPTOPL-194 | `isofs_ReadSect` computes the byte offset in 32 bits — directory extents past 4 GiB wrap | 6 | S |
| RIPTOPL-195 | http_conformance.py reads response bodies with no size bound | 6 | S |
| RIPTOPL-196 | ps2link naplink handler uses the RPC payload as a `printf` format string | 6 | S |
| RIPTOPL-197 | diaShowKeyb's caret and backspace operate on bytes, corrupting UTF-8 text | 6 | S |
| RIPTOPL-198 | apemodpatch patches executable code but leaves its `FlushIcache()` commented out — its sibling patch flushes | 6 | S |
| RIPTOPL-199 | genvmc prints usage on a wrong argument count and then dereferences the missing arguments anyway | 6 | S |
| RIPTOPL-200 | ziso.py: argument validation lets `-c` be omitted and `-b 0` through, both crash | 6 | S |
| RIPTOPL-201 | MX4SIO multi-block write: the CMD55 and ACMD23 results are assigned and immediately overwritten, never tested | 3/6 | S |
| RIPTOPL-202 | Plasma texture allocation is never checked, but draw() writes through it unconditionally | 6 | S |
| RIPTOPL-203 | ziso.py: corrupt LZ4 block can hang decompression forever, and the trim-loop can "decode" garbage | 6 | S |
| RIPTOPL-204 | ziso.py: compression silently discards a trailing partial block | 6 | S |
| RIPTOPL-205 | HDD `DeviceInit` retries the APA-header DMA forever — the one unbounded init wait in a directory where every sibling wait is bounded on purpose | 5 | S |
| RIPTOPL-206 | `cdrom_read` retries a failed `sceCdRead` forever, in all three phases, while holding the I/O semaphore | 5 | S |
| RIPTOPL-207 | ps2link `pko_recv_bytes` spins forever when the peer closes the connection mid-packet | 5 | S |
| RIPTOPL-208 | igrmbox `mbSendEE` busy-waits on SIF DMA with no timeout, on the only mailbox thread | 5 | S |
| RIPTOPL-209 | smb_Disconnect drains the socket with an unbounded blocking recv loop | 5 | S |
| RIPTOPL-210 | cdvdfsv's `sysmemSendEE` busy-spins twice with no yield and no bound — the pattern streaming.c was fixed for, one module over | 5 | S |
| RIPTOPL-211 | VMC save delete frees at most 64 file chains; the rest leak on the card forever | 6 | S |
| RIPTOPL-213 | APA cache flush clears the dirty flag and drops errors on failed header writes | 6 | S |
| RIPTOPL-214 | APPS scan requires `d_type == DT_DIR` exactly — the failure mode themes.cpp already documented and fixed for MMCE | 6 | S |
| RIPTOPL-215 | Remove settings leaves the Neutrino and Ember per-game keys behind | 6 | S |
| RIPTOPL-216 | VMC group table: two groups can never be returned, 8 title IDs can never match, 5 IDs are duplicated inside their own group | 6 | S |
| RIPTOPL-218 | udptty's `tty_write` always returns 0 — the write contract is broken and send failures are invisible | 6 | S |
| RIPTOPL-219 | opl2iso's copy loop spins forever on a read error | 6 | S |
| RIPTOPL-220 | History eviction compares against a stale timestamp and can evict the wrong record | 6 | S |
| RIPTOPL-221 | IoQueue's per-type pending counters are never reset, and termination cleanup frees requests without decrementing them | 6 | S |
| RIPTOPL-222 | `apaCacheInit` leaks the header block when the second allocation fails | 6 | S |
| RIPTOPL-223 | Non-IOP `apaGetTime` converts to "JST" with the wrong sign (host/test builds only) | 6 | S |
| RIPTOPL-224 | HDPro leg of the ATA set-transfer-mode ioctl reports success and does nothing (parent-read) | 8 | S |
| RIPTOPL-225 | The `use_alarm` setting is honoured by the SIO2 receive paths and ignored by every transmit path | 8 | S |
| RIPTOPL-228 | ArtIndex retains cap-sized allocations (48 KB per directory) however few entries the directory holds | 4 | S |
| RIPTOPL-229 | Glyph-cache pages are allocated from the raw codepoint, before the face is ever asked if it has the glyph | 4 | S |
| RIPTOPL-230 | diagSave keeps a second, permanent 16 KB copy of the whole diagnostic ring | 4 | S |
| RIPTOPL-231 | `load_cheats` reads a `.cht` file of any size into RAM whole, opting out of the cap its own reader provides | 4 | S |
| RIPTOPL-232 | `USBA_crc32` rebuilds its constant CRC table on every call, and the table is 4× oversized | 5 | S |
| RIPTOPL-236 | filemgr: `fmRemove` applies the memory-card 4-try retry (with 50 ms pauses) to every device | 5 | S |
| RIPTOPL-238 | ps1DropTwins recomputes the Ember rows' twin keys once per VCD row | 5 | S |
| RIPTOPL-239 | cheatConfigLoadSelections re-normalizes both cheat names for every (saved × cheat) pair | 5 | S |
| RIPTOPL-247 | tar.cpp's four find functions are one lookup written four times | 2 | S |
| RIPTOPL-248 | vmc_groups: 97 hand-written `count_*` variables are the boilerplate that already produced one out-of-bounds walk | 2/3 | S |
| RIPTOPL-249 | `bd_defrag_read` and `bd_defrag_write` are the same 45-line traversal pasted twice | 2 | S |
| RIPTOPL-252 | ranet: the "RAA1 OK" reply-header parse is implemented twice, with a third partial re-parse beside one copy | 2 | S |
| RIPTOPL-254 | ratls_ps2: `raHttpsGet` and `raHttpsDownload` duplicate the whole DNS → socket → connect → deadline preamble | 2 | S |
| RIPTOPL-255 | The MX4SIO/MMCE quiesce block is copy-pasted verbatim in both PS1 launch legs | 2 | S |
| RIPTOPL-256 | Two near-identical icon+caption draw functions in uidraw.cpp | 2 | S |
| RIPTOPL-258 | Apps linked-list node allocation is copy-pasted twice, and its if/else collapses to a plain prepend | 2 | S |
| RIPTOPL-259 | Two hand-copied 8-digit hex parsers for module-load arguments already disagree (lowercase) | 2 | S |
| RIPTOPL-260 | The `__RTL` renderString is a second, ~150-line text renderer that the live build can never select | 1 | S |
| RIPTOPL-261 | SMB1 `smb_ReadAndX` carries a permanently dead second receive implementation (`USE_CUSTOM_RECV` is unconditionally defined), plus the `rhdrlen` plumbing that only it used | 1 | S |
| RIPTOPL-262 | BDM device computes `g_bd_sectors_per_sector` on every attach and never reads it — disc reads hardcode ×4 (512-byte sectors) instead | 1 | S |
| RIPTOPL-263 | `mmce_sio2_rx_dma` (66 lines) has no caller anywhere in the tree — dead code in RiptOPL | 1 | S |
| RIPTOPL-264 | CRC7 "RAM table" mode is unreachable: both preprocessor tests use a macro name that does not exist, so the config's selected mode silently isn't | 1/8 | S |
| RIPTOPL-265 | dev9.c's PCMCIA probe trio (~55 lines) is behind a plain `DEBUG` define that no in-repo build of this module ever sets | 1 | S |
| RIPTOPL-266 | tools/lang_decompiler.py is dead: no caller, no docs, no test, and it runs on import | 1 | S |
| RIPTOPL-267 | ziso.py: dead code and a dead option inside the live tool | 1 | S |
| RIPTOPL-268 | ~90 lines of commented-out POSIX implementations are kept beside the stdio ones in the PC tools | 1 | S |
| RIPTOPL-269 | Dead disc-probe constants copied into both split files; the only live copy is in sysdisc.cpp | 1 | S |
| RIPTOPL-270 | imgdrv carries dead code: an unused `dummy_fs` and two unused private device-struct typedefs duplicating the SDK's | 1 | S |
| RIPTOPL-271 | poll.c's invalid-fd tracking is dead: `ifd` is never set, so POLLNVAL can never be returned | 1 | S |
| RIPTOPL-272 | textures: staged-open diagnostic latch for an already-superseded hypothesis is permanent production code | 8 | S |
| RIPTOPL-273 | sfxGetDropDiag() is a stub that always reports zero drops, while the debug HUD presents its counters as a live instrument | 8 | S |
| RIPTOPL-274 | Dead dialog read-back block at the end of the Compatibility dialog | 1 | S |
| RIPTOPL-275 | `GetModStorageLocation` takes a `compatFlags` parameter it never uses | 1 | S |
| RIPTOPL-276 | tools/syntax_sweep.py is not run by anything and cannot fail if it is | 7 | S |
| RIPTOPL-277 | tools/make_save_icon.py's `--check` mode is never invoked; the generator is referenced nowhere | 7 | S |
| RIPTOPL-278 | `test_ministack_xchg` is the one udpfs host test whose checks all vanish under `-DNDEBUG` — including a side-effecting `assert` | 7 | S |
| RIPTOPL-279 | test_catalog's de-duplication memory silently stops at 512 unique startups | 8 | S |
| RIPTOPL-280 | test_settings snapshots the settings table into fixed 200-entry arrays with no bound check | 8 | S |
| RIPTOPL-281 | GSHandler REGIMM decode masks 0x3F into a 32-entry table — odd `rs` jumps out of bounds | 6 | S |
| RIPTOPL-282 | `mips_memcpy` return value overwritten by `mips_memset`'s first instruction in its delay slot — all 4 copies | 6 | S |
| RIPTOPL-284 | `dve_set_reg` always returns 0 — `dve_prepare_bus` retry loop can never repeat | 6 | S |
| RIPTOPL-285 | Dead exports: 2 dangling `.globl`s with no definition anywhere + 2 defined exports with zero references | 1 | S |
| RIPTOPL-297 | test_audio_threads Part 1 scans only `*.c` after the C++ migration: the `audsrv_wait_audio()` ban is unenforced in all 115 `.cpp` files | 7 | S |
| RIPTOPL-298 | test_bdm_partitions asserts GPT partitions far beyond the device mount successfully, encoding RIPTOPL-160's missing extent validation as correct | 6 | S |
| RIPTOPL-299 | test_ratls_host.py only ever sends lowercase HTTP tokens, so the RIPTOPL-189 case-sensitive token defect passes the suite | 6 | S |
| RIPTOPL-300 | Neither ps2cnf host test exercises the ≥64-char BOOT2 value that RIPTOPL-158 flags, so the unterminated-string path has no regression test | 6 | S |
| RIPTOPL-302 | test_release_editions.py:28 can never fail: it membership-tests a dict of target names | 6 | S |
| RIPTOPL-303 | test_mbedtls_vendor swallows ValueError for whole edition/configuration combinations, uncounted | 6 | S |
| RIPTOPL-307 | test_ripps2_drive_status.py tests a re-typed copy of the drive-size arithmetic, not the production expression | 2 | S |
| RIPTOPL-309 | test_patch_zone_restore: the sbPrepare harness's exit code is never checked; its second half is verified only by C `assert()`s whose failure reaches Python only as a stdout side-effect | 7 | S |
| RIPTOPL-310 | Two suites have Python sections gated only by bare `assert`: they vanish, with their "ok" prints intact, under `python3 -O` / `PYTHONOPTIMIZE` | 6 | S |
| RIPTOPL-311 | `check_frames` in test_dialog_gui_lock.py scans each dialog file as one linear stream, so an unbalanced lock in one function can mask a missing lock in a later one | 6 | S |
| RIPTOPL-312 | test_mmceman_fork.py's provenance claim covers the whole vendored tree; the check hashes 2 of its ~15 files — and the one file that changed at the pin bump is not among them | 7 | S |
| RIPTOPL-318 | Install_IGR / IGR_RequestReset installation behaviour is asserted twice, in test_igr_polling.py and test_igr_menu_no_room.py, against two different stub universes | 2 | S |
| RIPTOPL-319 | The nine-name BDM latch list is written twice in one file, so the text check and the executable check can drift apart | 2 | S |
| RIPTOPL-320 | Boot-theme splash assertions duplicated between test_yaopl_ripps2_b125_ports and test_boot_theme_wait | 2 | S |
| RIPTOPL-322 | Dead test helpers: `strip_comments` and `function_body` in the SMB2 logon parity suite are defined and never called | 1 | S |
| RIPTOPL-323 | test_mx4sio_retry.py runs the whole test_mx4sio_write_acceptance.py suite as its last step, so ps2build executes the acceptance suite twice | 7 | S |
| RIPTOPL-324 | `test_bdm_scan_retry.py` runs twice in one workflow (and a third time in the other CI workflow) | 7 | S |
| RIPTOPL-325 | Ten harness-execution call sites in nine suites run their compiled harness with no timeout, so a hung harness hangs the CI job instead of failing | 7 | S |
| RIPTOPL-326 | Undocumented sys.argv source overrides in seven tests silently substitute non-pin code | 7 | S |
| RIPTOPL-327 | test_io_queue_trims: the deferred-update harness macro-aliases `ioPutRequest` to `ioPutRequestUnlessWaiting`, so the APPS call site in `menuDeferredUpdate` cannot regress to the un-coalesced spelling without failing anything | 7 | S |
| RIPTOPL-328 | test_hires_thread_priority exercises only rows 6–11 as "the multi-pass ones"; the four appended multi-pass rows (16–19) get no coverage in the test at all | 8 | S |
| RIPTOPL-329 | NUM_RM_VMODES is hard-coded as 20 in two renderman tests while the third extracts it from the source | 2 | S |
| RIPTOPL-330 | test_ilink_sbp2_completion.py hard-codes the production login budget and carries a dead placeholder replace | 7 | S |
| RIPTOPL-331 | test_catalog_limits.py hard-codes HTTP_STREAM_ERR_TRUNC as -7 instead of extracting it like every other production constant it uses | 8 | S |
| RIPTOPL-332 | Assertions inside possibly-empty iteration, with no count guard, in two tests | 6 | S |
| RIPTOPL-333 | test_about_credits_layout.py prints PASS for trimmed UI_BREAK rows and a kept row count, but never counts either | 6 | S |
| RIPTOPL-334 | test_sfx_oneshot_cut.py's coalesce assertion can be satisfied by the comment inside the captured branch alone | 6 | S |
| RIPTOPL-335 | test_pad_pattern_bounds.py's only ASan-isolated overread case is gated on an argument no CI invocation ever passes | 6 | S |
| RIPTOPL-336 | test_audit_translations.py exercises only one of the tool's two --strict error classes; the unknown-overlay-label error is untested by the tool's only test | 6 | S |
| RIPTOPL-337 | test_conformance.py locks in the empty-catalog run as a clean pass with "0 skipped", although the run skips every range check | 8 | S |
| RIPTOPL-338 | `test_pops_udpfs.py` can only run if the gitignored `build/` directory already exists | 7 | S |
| RIPTOPL-339 | Four tests create and use an in-tree build/test-tmp directory instead of the system temp dir | 7 | S |
| RIPTOPL-340 | test_smb1_vmc_share is the corpus's only cwd-relative test (in its batch, grep-verified) | 7 | S |
| RIPTOPL-341 | test_neutrino_bsdfs success message claims 28 preflight scenarios; the harness runs 30 | 7 | S |
| RIPTOPL-342 | test_mbedtls_vendor's docstring still says five pinned roots; seven are pinned and asserted | 7 | S |
| RIPTOPL-343 | Production `ra_watch.h` header comment is stale: it says the raudp header is 162 bytes; the field table sums to 184 (the fixture is right) | 7 | S |
| RIPTOPL-345 | Six headers have no include guard — incl. the shared `modules.h` contract header (double inclusion is a proven hard error) | 7 | S |
| RIPTOPL-346 | Stub `thsemap.h` (browse copy): `DeleteSema` sits outside its own include guard; the two stub copies have diverged | 7 | S |
| RIPTOPL-347 | `tests/host/check.h`: `CHECK_STR` uses `strcmp` but the header never includes `<string.h>` | 7 | S |
| RIPTOPL-349 | `guiGameHandleDeferedIO` is defined and declared but never called | 1 | S |
| RIPTOPL-350 | `NetSupport::netifLinkStatus()` is a dead declaration — never defined, never called | 1 | S |
| RIPTOPL-351 | `Remove_Padhook` — declared, never defined, never called | 1 | S |
| RIPTOPL-352 | `igrovl.h` — dead forward declaration of a struct tag that does not exist | 1 | S |
| RIPTOPL-353 | Dead lite-build gates: `LITE_HAS_TCPIP` and `LITE_DEVICE_NAME` are consumed nowhere | 1 | S |
| RIPTOPL-354 | `BG_REQUEST_EXTRA_IDLE_FRAMES` is a dead constant whose described mechanism does not exist | 1 | S |
| RIPTOPL-355 | `CONFIG_OPL_ENABLE_ANALOG_NAV` — config key macro for a deliberately removed feature; zero readers | 1 | S |
| RIPTOPL-356 | `CHEAT_VERSION` value is consumed by no code (test script uses the line only as a text anchor) | 1 | S |
| RIPTOPL-357 | `ISO_GAME_FNAME_MAX` is a dead macro — no product-code consumer anywhere | 1 | S |
| RIPTOPL-358 | `APA_IOCTL2_GETHEADER` — dead APA ioctl constant; no APA ioctl2 call site exists | 1 | S |
| RIPTOPL-359 | `GSM_ARGS` — dead constexpr in the per-game GSM header | 1 | S |
| RIPTOPL-360 | `IO_ERR_UNKNOWN_REQUEST_TYPE` — error code never returned and never tested | 1 | S |
| RIPTOPL-361 | `HDD_LOADMODULES_STATUS_COUNT` — trailing status enumerator never used as a count or bound | 1 | S |
| RIPTOPL-362 | `FAV_MAGIC` comment spells the on-disk magic wrong — the bytes are "OFAF", not "OFAV" | 8 | S |
| RIPTOPL-363 | Stub `ps2smb.h`: `smbOpenShare_in_t` size comment contradicts the struct (520 vs 516) | 8 | S |
| RIPTOPL-364 | favsupport.h points readers at a source file that does not exist (`favsupport.c`) | 8 | S |
| RIPTOPL-365 | Orphaned contract comment attached to the wrong declaration in themes.h | 8 | S |
| RIPTOPL-366 | ioman.h carries an orphan doc comment for a remove-by-type function that does not exist | 1 | S |
| RIPTOPL-367 | Duplicate `#include <debug.h>` in opl.h | 7 | S |
| RIPTOPL-400 | smb_FindFirstNext2 trusts response ParamOffset/DataOffset/FileNameLen with no bounds at all | 6 | S |
| RIPTOPL-401 | Negotiate response domain name is `strcpy`'d unbounded into a 64-byte field | 6 | S |
| RIPTOPL-402 | ZSO decompression uses the explicitly-unsafe LZ4 "fast" decoder on a user-supplied game image, with prefix references enabled and the result unchecked | 6 | S |
| RIPTOPL-403 | `lwip_accept()` dereferences a NULL netconn that `err_tcp()` itself posts | 6 | S |
| RIPTOPL-404 | GPT scan's fallback path trusts the header's entry count unbounded: a crafted disk can make mount read sectors indefinitely | 6 | S |
| RIPTOPL-406 | APA journal write side has no bound: more than 126 dirty cache entries overflow the static journal buffer and write journal headers past the journal area | 6 | S |
| RIPTOPL-407 | USB mass-storage connect walks the endpoint descriptor chain with a device-supplied count and stride, unchecked | 6 | S |
| RIPTOPL-409 | ps2ips `do_send()`/`do_sendto()` trust the EE-supplied `malign` field completely | 6 | S |
| RIPTOPL-410 | ps2ips `do_recv()`/`do_recvfrom()` accept a negative EE `length`, inverting the RA buffer-offset arithmetic | 6 | S |
| RIPTOPL-414 | NBNS receive thread copies the answer address from a fixed offset without checking the datagram is that long | 6 | S |
| RIPTOPL-417 | `InitializeConfigurationROM` leaks the old CROM and every extra unit, and silently drops all added units, on every `iLinkSetNodeCapabilities` call — both copies | 6/4 | S |
| RIPTOPL-418 | `iLinkFindUnit` accepts a negative `UnitInList` and indexes `NodeData[-1]` — both copies | 6 | S |
| RIPTOPL-419 | DEV9 callback-registration exports index their tables with unchecked (and possibly negative) indices | 6 | S |
| RIPTOPL-420 | Fixed-size UDPFS replies are never length-checked; a short reply is parsed out of stale buffer contents | 6 | S |
| RIPTOPL-422 | Both ministack RX dispatchers will call through a NULL handler for a packet addressed to port 0 | 6 | S |
| RIPTOPL-423 | `do_bind()` uses lazily allocated PCBs without the NULL checks its sibling handlers have | 6 | S |
| RIPTOPL-424 | `copy_from_pbuf()` walks off the end of the pbuf chain when a fragment's IP length exceeds the delivered bytes | 6 | S |
| RIPTOPL-426 | Client netconns never get a semaphore, so `netconn_write()` busy-spins on `WaitSema(0)` | 5 | S |
| RIPTOPL-429 | GPT connect returns success (0) when its scratch allocation fails, so BDM claims the device and FatFs is never tried | 6 | S |
| RIPTOPL-430 | `USBMASS_DEVCTL_STOP_UNIT` and `USBMASS_DEVCTL_STOP_ALL` bodies are swapped in `fs_devctl` | 6 | S |
| RIPTOPL-431 | FileTimeToDate converts ~half of all dates to garbage (SMB1 browse/stat timestamps) | 6 | S |
| RIPTOPL-432 | usmb2_build_request drains a server-declared SPL of any size; no reply-size ceiling | 6 | S |
| RIPTOPL-433 | Replies are matched to requests only when signing is on (usmb2 MessageId) or never (unfs4 xid) | 6 | S |
| RIPTOPL-434 | smb2man_querydir trusts the reply's OutputBufferLength over the bytes actually delivered | 6 | S |
| RIPTOPL-435 | smb_closeAll() closes FIDs but never frees the handles — stale slots leak and FIDs can be re-closed on a later session | 6 | S |
| RIPTOPL-436 | USB READ CAPACITY result stored as sector count without the +1: the last sector of every USB drive is unreachable | 6 | S |
| RIPTOPL-437 | SMB (USBLD multipart) read past the last part returns success with the buffer untouched | 6 | S |
| RIPTOPL-438 | `smap_udpbd` write path hardcodes 512-byte sectors and ignores the INFO-reply sector size the read path honours | 6 | S |
| RIPTOPL-439 | `sceCdStInit` divides by the game's `bankmax` with no validation | 6 | S |
| RIPTOPL-440 | mcemu FastIO hooks dereference the FastIO allocation without ever checking it exists; the read hook also DMA-transfers a full cluster for a short tail | 6 | S |
| RIPTOPL-441 | `mmce_fs_open`/`dopen` failure exits leave `file->privdata` pointing at a still-free handle slot, which the next open then aliases | 6 | S |
| RIPTOPL-446 | GPT parser ignores the header's `partition_entry_size` and assumes every entry is 128 bytes | 6 | S |
| RIPTOPL-447 | GPT connect lacks the partition-device filter the MBR connect has, so every partition pseudo-device is re-probed as a GPT disk | 6 | S |
| RIPTOPL-448 | `sceAtaSecurityEraseUnit` passes NULL as the IDENTIFY buffer; the helper writes 512 bytes to address 0 and dereferences it | 6 | S |
| RIPTOPL-451 | `tcp_keepalive()` transmits a segment whose TCP flags byte is uninitialised pool memory | 6 | S |
| RIPTOPL-452 | `netconn_recv()`/`netconn_write()` dereference `conn->pcb.tcp` where the tree itself elsewhere guards it | 6 | S |
| RIPTOPL-456 | Game patch modules write fixed offsets into a target module's text with no size or version check | 6 | S |
| RIPTOPL-457 | pademu `_start` reads 8 bytes of `argv[1]` with no length check | 6 | S |
| RIPTOPL-458 | genvmc STATUS devctl copies to the caller's buffer with none of the validation the CREATE case applies in the same switch | 6 | S |
| RIPTOPL-460 | NTLMv2 client challenge is the constant 0x01×8 and the timestamp is zero (vendored usmb2) | 6 | S |
| RIPTOPL-461 | `fs_dread` can hand EE an unterminated directory name for a maximum-length (255-char) LFN | 6 | S |
| RIPTOPL-463 | `mstack:` exchange silently truncates an over-long reply, indistinguishable from a complete one | 6 | S |
| RIPTOPL-464 | `udpfs_core_close` discards the close reply entirely and always reports success | 6 | S |
| RIPTOPL-465 | CDVDFSV stream read returns an uninitialised error word when `sectors == 0` | 6 | S |
| RIPTOPL-466 | `hookMODLOAD` uses `getModInfo`'s result without checking it — the one unhardened caller left in scope | 6 | S |
| RIPTOPL-467 | `apaOpen` compares the password of a cache entry after freeing the entry | 6 | S |
| RIPTOPL-469 | INFERRED: `udpfs_ministack` registers its RX callback and takes over the tty before the duplicate-load check | 6 | S |
| RIPTOPL-470 | Eight `ps2ip` exports are an empty stub, while in-tree modules import and call them | 8 | S |
| RIPTOPL-474 | Both mcemu ports share the single 512-byte page data buffer | 2/6 | S |
| RIPTOPL-476 | APA DES password engine (~460 lines + tables) is compiled, linked and executed on every open, but its result can never matter in the shipped build | 1 | S |
| RIPTOPL-478 | `ioplib.c`/`ioplib.h` are byte-identical vendored copies in mmceman and mx4sio_bd, and their `sio2man_hook.c` twins differ by 3 lines | 2 | S |
| RIPTOPL-479 | `smap_udpbd`'s ministack carries a fully dead ARP cache: `arp_add_entry` has no caller and the RX path never learns | 1 | S |
| RIPTOPL-480 | Dead FHI export table and `_start` branch in `udpfs_bd` and `udpfs_ioman` reference symbols that exist nowhere | 1 | S |
| RIPTOPL-481 | `udprdma_inform` (server mode) and the core/transport teardown pair are dead in the shipped variants | 1 | S |
| RIPTOPL-482 | Dead code and build clutter: an unbuilt loopback driver, a DHCP header with no client, a RAW pool with no RAW stack, and nine header declarations with no definitions | 1 | S |
| RIPTOPL-484 | smb.h declares a function that does not exist and ~200 lines of never-referenced protocol constants | 1 | S |
| RIPTOPL-485 | smb.h carries 44 protocol-offset defines and ~30 command defines nothing in the module references | 1 | S |
| RIPTOPL-486 | The assault tree carries five build files its only Makefile never reads (244 lines) — one of them still contains the cdvdman imports the tree exists to remove | 7/2 | S |
| RIPTOPL-487 | Dead driver surface kept in both copies: an uncallable deinit, two phantom prototypes, four dead struct fields and a broken macro | 1 | S |
| RIPTOPL-488 | Dead imports in all four IOP builds in scope (15 stubs with no caller in their own module) | 1/7 | S |
| RIPTOPL-491 | pccf keeps two 512-byte static scratch buffers resident forever although their lifetimes never overlap | 4 | S |
| RIPTOPL-493 | `hdd_blkio.o` is an empty translation unit in the shipped build but is still compiled and linked | 7 | S |
| RIPTOPL-494 | `lz4.h` declares the full LZ4 API (~20 functions: compression, streaming, obsolete); `lz4.c` implements exactly one | 7 | S |
| RIPTOPL-495 | usbd public header declares two exports the module does not implement | 8 | S |
| RIPTOPL-496 | Multi-LUN support is plumbed but never used: max-LUN is queried, printed, and thrown away; the CBW LUN field is hardcoded 0 | 8 | S |
| RIPTOPL-497 | `smap_udpbd` xfer creates an event flag nothing ever waits on, and defines a FIFO-copy helper nothing calls | 1 | S |
| RIPTOPL-498 | `rapull`'s `rp_frame_values(read=0)` mode is dead: the parameter and its branches serve a call that never happens | 1 | S |
| RIPTOPL-499 | `raudp`'s discovery-elapsed counter `ra_disc_us` is written, overflow-guarded, and never read | 1 | S |
| RIPTOPL-500 | The korium theme-contract test is orphaned: no workflow runs it | 7 | S |
| RIPTOPL-502 | The vendor test never hashes the vendored tree: mbedTLS's "byte-for-byte" pin is unenforced | 7 | S |
| RIPTOPL-503 | Orbit README says one i.LINK file is replaced after staging; the packer replaces two | 8 | S |
| RIPTOPL-504 | Korium manifest completeness is enforced by nobody: unlisted zip entries are silently dropped | 6 | S |
| RIPTOPL-505 | Korium extraction directory is never cleaned: a removed asset can keep shipping from a dirty build tree | 6 | S |
| RIPTOPL-506 | ps2sdk-socket's README describes the retired compat build in the present tense | 8 | S |
| RIPTOPL-507 | Korium README's "Korium and RetroAchievements builds" misstates which editions read the archive | 8 | S |
| RIPTOPL-508 | `hkdf.c` compiles under RA but nothing calls its API; only the `MBEDTLS_HKDF_C` define is load-bearing | 1 | S |
| RIPTOPL-509 | `mps_reader.c` compiles under RA (538 lines) with no consumer anywhere in the tree | 1 | S |
| RIPTOPL-510 | `third_party/ps2sdk-ppctty/irx_imports.h` is an unreferenced remnant of the removed source fallback | 1 | S |
| RIPTOPL-511 | Vendored mbedTLS `Makefile`/`CMakeLists.txt` (811 lines) are inert in every RiptOPL flow — recorded; retention recommended | 7 | S |
| RIPTOPL-512 | `udpfs_ministack`'s PS2SDK Makefile omits `ministack_xchg.o`, which its own `main.c` calls — the two build manifests disagree | 7 | S |
| RIPTOPL-514 | CDVDFSV reports CDVDMAN version 0x223 while CDVDMAN reports 0x225 | 7 | S |
| RIPTOPL-515 | prepare_path's trailing-slash scan is dead code that starts on the NUL terminator | 1 | S |
| RIPTOPL-517 | `ff.c` carries a local debug divergence that the vendoring record does not list | 7 | S |
| RIPTOPL-518 | Dead definitions: `mount_status` field never read or written; unused GPT GUID and attribute macros | 1 | S |
| RIPTOPL-519 | `part_read` and `part_write` are near-identical copies (bounds check + debug block + forwarding) | 2 | S |
| RIPTOPL-521 | `xhdd.h` declares two functions that exist nowhere in the HDD modules | 1 | S |
| RIPTOPL-522 | pccf carries a `time_us` clock plumbing chain that is written once and read never | 1 | S |
| RIPTOPL-523 | `pcdiag_ata.h` declares a diagnostic entry point, `pcdiag_ata_observe`, that was never implemented — and an unused read-limit constant beside it | 1/8 | S |
| RIPTOPL-524 | `modules/pccf/format.inc` is a 57-line mini-printf included by nothing | 1/7 | S |
| RIPTOPL-525 | `PROVENANCE.md`'s dedupe claim names a binary that does not exist, and its re-vendor count is stale | 7 | S |
| RIPTOPL-526 | `modules/debug/drvtif.irx` and `drvtif-ingame.irx` are the same bytes under two names | 7 | S |
| RIPTOPL-527 | bdmevent's `irx_imports.h` imports four libraries the module never calls | 7 | S |
| RIPTOPL-528 | `udpfs_fhi/ORIGIN.txt` states there is no write export; the module exports one and implements it | 7 | S |
| RIPTOPL-529 | RA-under-POPS is shipped with its two load-bearing unknowns still open (half-finished feature) | 8 | S |
| RIPTOPL-600 | Both Sectigo roots are embedded into RA builds that have no update channel and therefore contain no code that can reference them | 4 | S |
| RIPTOPL-601 | The vendored CMakeLists and its 142-line test suite are dead in this build — no CMake project, workflow, or script in RiptOPL ever builds or runs them | 7 | S |
| RIPTOPL-602 | `hddFormat` reads a cache entry's sector after freeing the entry (second instance of the RIPTOPL-467 pattern) | 6 | S |
| RIPTOPL-603 | smb_open stores an unterminated name with a full-size strncpy count | 6 | S |
| RIPTOPL-604 | mmce_fs SET_GAMEID devctl case dereferences `arg` unchecked | 6 | S |
| RIPTOPL-605 | tools/assets.py comment asserts the opposite of the RA anchor table it annotates | 7 | S |

**Launchstation — 132 quick wins**

| ID | Title | Cat | Effort |
|---|---|---|---|
| LAUNCHSTATION-008 | docs-site carries 17.4 MB of media in the repo, including the same demos as both GIF and MP4 | 7 | S |
| LAUNCHSTATION-010 | CI builds the entire project twice for the DS34 variant; DS34 code is dead in the default build | 7/1 | S |
| LAUNCHSTATION-013 | Dead media assets: bgm.ogg (462 KB) and res/sfx/boot.adp (144 KB) are neither embedded nor packaged | 1/7 | S |
| LAUNCHSTATION-016 | Unchecked genRead/genWrite returns on file and font data | 6 | S |
| LAUNCHSTATION-018 | Thirteen #if 0 blocks keep dead code in IOP modules | 1 | S |
| LAUNCHSTATION-019 | Stale precompiled udpfs_smap.irx is superseded by the source-built target | 1/7 | S |
| LAUNCHSTATION-020 | Unused exploit payloads: IOPRP.IMG and XSYSTEM2.XLF | 1 | S |
| LAUNCHSTATION-021 | Byte-identical duplicate files across the tree | 2/7 | S |
| LAUNCHSTATION-022 | res/icons/*.png (16 files) are not used by the icon system | 1 | S |
| LAUNCHSTATION-023 | Branch and tag clutter: 104 remote branches, 140 tags (88 build-*) | 7 | S |
| LAUNCHSTATION-025 | Development-only code paths compiled into production sources | 1 | S |
| LAUNCHSTATION-027 | Six workflows, including a download-counter running 8× a day | 7 | S |
| LAUNCHSTATION-028 | Stale planning/audit documents are kept as if current | 7 | S |
| LAUNCHSTATION-029 | __Headers APA samples and ship/ shortcut .url files are release-kit clutter in the source repo | 7 | S |
| LAUNCHSTATION-031 | QR generator (1,027 vendored lines) exists for one cloud-login screen | 8 | S |
| LAUNCHSTATION-033 | The FTP server is anonymous with full read/write/delete, by launch configuration | 6 | S |
| LAUNCHSTATION-035 | ps2host's read reply trusts the host-supplied byte count into the caller's buffer | 6 | S |
| LAUNCHSTATION-037 | FTP PORT command is an unvalidated FTP-bounce primitive | 6 | S |
| LAUNCHSTATION-038 | FTP PASV data connection accepts any host that connects first | 6 | S |
| LAUNCHSTATION-039 | Card tool keeps ten whole-image safety copies per card image, and re-scans the folder for every prune | 3/5 | S |
| LAUNCHSTATION-040 | The FTP credential path is dead code that looks like security: `-pass` can never match, `-port` is overwritten, defaults are hardcoded, and the EE never passes any of them | 1/6 | S |
| LAUNCHSTATION-041 | The file-based PSU extractors are dead in the shipped app — kept alive only by the host test harness — and the updater still gates on a `.BAK` name it never creates | 1 | S |
| LAUNCHSTATION-044 | ps2ftpd and smbman IRX targets build without `--gc-sections`, so their dead code ships in the IRX | 1/7 | S |
| LAUNCHSTATION-045 | `isHddRootPath` exists three times, with three different definitions | 2 | S |
| LAUNCHSTATION-046 | `getXfromRelativePath` is byte-identical in two files | 2 | S |
| LAUNCHSTATION-049 | Dead FTP handlers: SITE always answers 500, FEAT is declared and never implemented | 1 | S |
| LAUNCHSTATION-056 | smbman's `FileTimeToDate` computes wrong calendar dates — and it is the third, divergent copy of a conversion the other two drivers do correctly | 6/2 | S |
| LAUNCHSTATION-058 | `smb_closeAll` sends server CLOSE for directory search handles and frees no handle slots at logoff | 6 | S |
| LAUNCHSTATION-059 | smbman's `lseek64` ignores the SEEK_END offset, accepts negative positions, and the 32-bit `lseek` truncates positions past 2 GiB | 6 | S |
| LAUNCHSTATION-060 | smbman's read/write/dread/lseek dereference the handle without the validation its own close performs — and neither read nor write rejects a negative size | 6 | S |
| LAUNCHSTATION-063 | smbman's `dread` copies a server-supplied directory name with a `strncpy` that can leave `dirent->name` unterminated | 6 | S |
| LAUNCHSTATION-066 | smbman's `devctl` dereferences caller buffers with no NULL or length validation — the check both sibling drivers perform first | 6 | S |
| LAUNCHSTATION-069 | smbman's `chdir` reads one byte before its path buffer for root/empty directory names | 6 | S |
| LAUNCHSTATION-074 | `unfs4_init_context` has no caller in the nfsman IRX — a second, incompatible connect path compiled into the driver | 1 | S |
| LAUNCHSTATION-075 | The IOP allocator trio (`malloc`/`free`/`calloc`) is byte-identical in smb2man and nfsman | 2 | S |
| LAUNCHSTATION-076 | The dashboard browser sorts listings with an insertion sort that moves 384-byte structs | 5 | S |
| LAUNCHSTATION-077 | MMCE active-card history prune re-enumerates the folder for every generation it deletes | 5 | S |
| LAUNCHSTATION-080 | `McGetFATentry`/`McSetFATentry` index `ifc_list[ifc_index]` with an unbounded `fat_index` — and card FAT values feed the same path | 6 | XS |
| LAUNCHSTATION-081 | Card-supplied entry names are still passed to `strlen`/`strcmp`/`strcpy` unterminated — the terminated-copy fix (delta D8) covered only the caller's copy | 6 | S |
| LAUNCHSTATION-082 | PS1 `open`/`getstat`/`setinfo` dereference the dir-entry pointer before checking the lookup's return value | 6 | XS |
| LAUNCHSTATION-083 | `McWrite` with a negative length reaches `memcpy` as a huge `size_t` in both write paths; `McRead` is safe in both of its paths | 6 | XS |
| LAUNCHSTATION-084 | No port/slot validation on any mcman library export, although the fd exports validate fd | 6 | S |
| LAUNCHSTATION-086 | VMCMAN diagnostics print unconditionally from the `mcman_open2` create path | 5 | XS |
| LAUNCHSTATION-087 | Directory scans re-walk the FAT chain from the directory head for every entry (non-root directories) | 5 | XS |
| LAUNCHSTATION-088 | The 16-byte-chunk manual struct copy is open-coded 11 times where `memcpy` is the whole semantics | 2 | S |
| LAUNCHSTATION-097 | CNF load copies file-supplied values unbounded into fixed SETTING fields — the 64-byte Misc* fields overflow on a ~65-char line | 6 | S |
| LAUNCHSTATION-098 | Text editor writes one row-width entry per text row into a 2,048-entry array with no bound | 6 | S |
| LAUNCHSTATION-099 | `hdl_ginfo_read` strcpy's disk-controlled strings into 65- and 13-byte fields and sums subs[] for a disk-controlled nsub past the 64-entry array | 6 | S |
| LAUNCHSTATION-101 | Journal restore trusts the on-disk journal count and sector list completely, then erases the journal even when restore fails part-way | 6 | S |
| LAUNCHSTATION-102 | The on-disk nsub field is trusted as a loop bound and array index in four places; the guards that exist check a different variable | 6 | S |
| LAUNCHSTATION-103 | `hdl_ginfo_write` writes a sector back to disk without checking the read that filled it, and copies 128 bytes from a 65-byte name field | 6 | S |
| LAUNCHSTATION-104 | `atoi()` on server-supplied Content-Length overflows before the range check | 6 | S |
| LAUNCHSTATION-108 | HIOCGETSIZE indexes fileSlot->parts[] with a caller-supplied u32 and no bounds or pointer check | 6 | S |
| LAUNCHSTATION-109 | ioctl2Transfer's bounds check is overflowable and the transfer direction is caller-supplied | 6 | S |
| LAUNCHSTATION-110 | APA header injection rewrites 2 MB in place with no rollback and no readback verification | 6 | S |
| LAUNCHSTATION-112 | Backing read/write/erase never check page against the stored cardsize: writes and erases past the end of the image extend the backing file | 6 | S |
| LAUNCHSTATION-115 | The OSDMBR journal-overlap guard is compiled out of the OSD build — the one build this module exists for | 6 | S |
| LAUNCHSTATION-117 | `apaRename` signals fioSema on three of its exits and its caller signals it again — semaphore ownership is double-released on every rename error path | 6 | S |
| LAUNCHSTATION-119 | `GET_XPARAM_DB_SIZE()` always evaluates to 1 — the 292-entry database is searched over exactly one entry | 6 | One character |
| LAUNCHSTATION-120 | `readHOST()`'s elf-list branch returns hostcount − 1: the last entry is dropped whenever elflist.txt has no trailing newline | 6 | S |
| LAUNCHSTATION-121 | MMCE history newest/prune ordering is lexicographic, but same-second collision names sort backwards | 6 | S |
| LAUNCHSTATION-123 | `loadHdlInfoModule()` marks the HDL Info RPC ready unconditionally — module-load and bind results are both discarded | 6 | ~3 lines |
| LAUNCHSTATION-125 | `preloadCNFFd`'s seek path has no size cap — the 128 KB cap exists only in the fallback it bypasses | 6 | XS |
| LAUNCHSTATION-128 | `Transfer-Encoding: chunked` detection is case-sensitive | 6 | S |
| LAUNCHSTATION-129 | Unbounded atoi/digit accumulation overflows before clamping in theme and IPv4 parsers | 6 | S |
| LAUNCHSTATION-130 | `fioInputBreaker` accepts a field exactly as long as its buffer, leaving IDs and passwords unterminated | 6 | S |
| LAUNCHSTATION-131 | Module start arguments admit 0 and negatives for -o, and no maximum at all for -n | 6 | S |
| LAUNCHSTATION-132 | `apa_ptable_read_ex` end-of-disk test can wrap, and excludes a partition ending exactly at the disk end | 6 | S |
| LAUNCHSTATION-133 | Recycled hub buffer keeps the previous hub's bNbrPorts when the new hub descriptor is short | 6 | S |
| LAUNCHSTATION-134 | Isochronous halted-ED cleanup clears the wrong LUT slot, leaving a dangling request | 6 | S |
| LAUNCHSTATION-136 | ds34bt DS4 LED/rumble report: buffer zeroed with the DS3 length, then sent at the DS4 length — 29 uninitialised stack bytes transmitted | 6 | One token |
| LAUNCHSTATION-137 | KELF signing key material is never scrubbed from stack copies | 6 | S |
| LAUNCHSTATION-138 | `mcman_iomanx_backing_mount` trusts its slot twice: cleanup runs clear_slot on slots the validator just rejected, and re-mounting overwrites a live fd | 6 | S |
| LAUNCHSTATION-139 | Four entry-reachable `apaCacheAlloc()` results are used without a null check, beside a fifth site in the same files that does check | 6 | S |
| LAUNCHSTATION-140 | usbd `_start` config arguments are parsed without range checks and feed unchecked allocation arithmetic; AllocSysMemory result is memset before any NULL check | 6 | S |
| LAUNCHSTATION-141 | ps2ips `do_send`/`do_sendto` trust the EE-supplied `malign` count: negative buffer offset and length underflow | 6 | S |
| LAUNCHSTATION-142 | ps2ips `do_recv`/`do_recvfrom` never reject a negative EE-supplied `length` | 6 | S |
| LAUNCHSTATION-143 | hdl_info rename path: EE-supplied NewName is strcpy'd with no termination guarantee, and the RPC handler never looks at Size | 6 | S |
| LAUNCHSTATION-144 | HDL RPC wrappers strcpy into 33- and 64-byte packet fields with no length check — safety exists only in today's callers | 6 | Trivial |
| LAUNCHSTATION-145 | Editor navigation rules read one row-width entry before/after the cursor's row, and past the last row after the Home/End scans | 6 | S |
| LAUNCHSTATION-146 | SETTING allocations are dereferenced without a NULL check, in both places config.c creates one | 6 | S |
| LAUNCHSTATION-148 | Scene-override stack loses one level when nesting exceeds depth 8 | 6 | S |
| LAUNCHSTATION-149 | `dashPngDecode` dereferences its out-parameters without the NULL checks its JPEG sibling performs | 6 | Trivial |
| LAUNCHSTATION-151 | `ds34bt_reset` waits forever for pads to leave RUNNING state | 6 | S |
| LAUNCHSTATION-152 | usbd device-descriptor short read retries forever with no counter | 5 | S |
| LAUNCHSTATION-153 | `waitUntilTimer()` busy-spins the EE for up to 6 s on the UI thread while waiting for a clipboard source device | 5 | S |
| LAUNCHSTATION-154 | pccf `pio_profile` does up to 18 validation reads at start, and any failure — including "known model, card smaller than 4096 sectors" — triggers a full power-cycle restart of the whole driver | 5 | S |
| LAUNCHSTATION-155 | `pcdiag_cf_probe`'s sampling phase is diagnostic dead work in the production driver: results go to a no-op trace, the return is unconditional, and it costs ~700 ms on every start | 1/5 | S |
| LAUNCHSTATION-157 | `HandleRxIntr` never counts a packet, so the link-check traffic reset is dead | 1 | Trivial |
| LAUNCHSTATION-158 | Two private 2,049-entry sceMcTblGetDir statics (readMC and readXFROM) duplicate ~120 KB of .bss each | 4 | Trivial |
| LAUNCHSTATION-159 | pccf PIO tuning profile reserves 8 KiB of static IOP memory for a one-shot, two-model check | 4 | S |
| LAUNCHSTATION-166 | `resetScreen()` and `resetDisplayThemeDefaults()` duplicate the same 15-line classic reset | 2 | S |
| LAUNCHSTATION-167 | PNG decoder open-codes its flush-row block three times; the JPEG decoder beside it already has it as a function | 2 | S |
| LAUNCHSTATION-168 | BCD conversion is copy-pasted at least four times, twice inside one file | 2 | Trivial |
| LAUNCHSTATION-169 | The same `pccf` IOP target is defined twice — root `ps2.yaml` and `iop/pccf/ps2.yaml` — with identical sources, defines, flags and headers | 2/7 | S |
| LAUNCHSTATION-173 | Four libhdd entry points have no caller anywhere in the tree, and the one filesystem-list walker among them strcpy's dirent names into a 32-byte field | 1/6 | S |
| LAUNCHSTATION-174 | `load_ps2atad_stack()` is a 52-line DVRP loader with no caller, kept alive only by `__attribute__((unused))` | 1 | Trivial |
| LAUNCHSTATION-175 | Six settings IDs have choice/action dispatch but no row in any page — the handlers are dead | 1 | S |
| LAUNCHSTATION-178 | Four usbd imports are declared and never called (`strtol`, `DeleteSema`, `DeleteThread`, `DelayThread`) | 1 | S |
| LAUNCHSTATION-181 | pccf: one dead import — `I_memcpy` is declared but memcpy is never called in the module | 1 | 1 line |
| LAUNCHSTATION-188 | libsmb2 frees the file-notify list by recursion whose depth the remote server controls | 6 | S |
| LAUNCHSTATION-189 | Four libsmb2 client error paths leak their callback-data allocations | 6 | S |
| LAUNCHSTATION-190 | libsmb2's AES-CCM tag verification uses early-exit `memcmp` | 6 | S |
| LAUNCHSTATION-192 | libsmb2's `sha1.c` compiles to an empty translation unit in the smbd build | 1 | S |
| LAUNCHSTATION-193 | AllowDVDV's payload import lives in the C file, invisible to its own glue files and to `imports.lst`-driven tooling | 7 | S |
| LAUNCHSTATION-194 | Two passing tests (230 lines) and the `nfsman_live/` harness are never run by any workflow | 7 | S |
| LAUNCHSTATION-195 | ds34usb and ds34bt both import `sceUsbdSetPrivateData`, which neither driver ever calls | 1 | S |
| LAUNCHSTATION-196 | ps2ips_rpc imports `sceSifInitRpc` and never calls it | 1 | S |
| LAUNCHSTATION-197 | ps2host imports `puts` and never calls it | 1 | S |
| LAUNCHSTATION-198 | ds34usb + ds34bt `irx_imports.h` declare twelve libraries neither module imports — and nothing includes the header | 7 | S |
| LAUNCHSTATION-199 | xparam database: one identical row is filed twice consecutively (`SLPM_660.22`) | 2 | S |
| LAUNCHSTATION-200 | The shipped example config's `Misc = MISC/` double-slashes on load, breaking its own FileBrowser shortcut | 6 | S |
| LAUNCHSTATION-201 | docs-site cloud page says automatic sync is off by default; the default is on, in local-backup mode | 7 | S |
| LAUNCHSTATION-202 | The main dashboard doc names `LAUNCHELF.CNF` as the live settings file at five sites; nothing writes that name any more | 7 | S |
| LAUNCHSTATION-203 | Configuration page says CNF files over 128 KB are rejected; the normal load path has no cap | 7 | S |
| LAUNCHSTATION-204 | FileBrowser note lists six sort modes with Name as default and ELFs ungrouped; the code has seven modes, defaults to Type, and groups ELFs first | 7 | S |
| LAUNCHSTATION-205 | Themes page inverts panel transparency: it says 0% removes panels and 100% is opaque; the code is the reverse | 7 | S |
| LAUNCHSTATION-206 | Ecosystem page denies the All-saves view and batch card saves exist; both are shipped and documented elsewhere in the same site | 7 | S |
| LAUNCHSTATION-207 | Cloud doc caps the HTTP body at 64 KiB; the code's limit is 256 KiB | 7 | S |
| LAUNCHSTATION-208 | Two docs say `CNF_version` must be the first line; the parser accepts it anywhere, and a missing version loads as legacy | 7 | S |
| LAUNCHSTATION-209 | Two docs say the PSX (DESR) is treated as having i.Link; `consoleHasIlink()` returns 0 on PSX | 7 | S |
| LAUNCHSTATION-210 | Example config's comment says Triangle shows About; the same file's empty `LK_Triangle_E1` overrides the built-in About default | 7 | S |
| LAUNCHSTATION-211 | Example config says titles are gated by `Menu_Hide_Paths`; the gate is `Show_Titles` | 7 | S |
| LAUNCHSTATION-212 | Example config's Neutrino comment omits the SMB backend and claims `-qb` is unconditional; SMB is supported and suppresses `-qb` | 7 | S |
| LAUNCHSTATION-215 | Issue-plan doc states MC/VMC copies use 16 KiB chunks; the copy path uses 128 KiB for those destinations and no 16 KiB chunking exists | 7 | S |
| LAUNCHSTATION-216 | Themes page lists two UI fonts; the code ships three (`emotion_engine` omitted — though the same page mentions it later) | 7 | S |
| LAUNCHSTATION-217 | Three docs stop the TV-mode list at 576p; mode 6 (576i) exists and is exposed in both UIs | 7 | S |
| LAUNCHSTATION-219 | Two docs inventory the update CA bundle as two roots; the bundle contains three — the omitted E46 root is load-bearing | 7 | S |
| LAUNCHSTATION-220 | Follow-up manifest says the move-manifest work is "Implemented on the draft PR branch; not merged"; it is merged at the pin | 7 | S |
| LAUNCHSTATION-221 | architecture-maintenance's inventories don't match the tree: largest-files list omits the two largest files, workflow table lists 3 of 6 | 7 | S |
| LAUNCHSTATION-222 | Wiki build page says "The retained Makefile describes historical profiles"; no Makefile exists at the pin — it was retired 2026-10-26 | 7 | S |
| LAUNCHSTATION-223 | Display-feedback doc claims a 320×256 wallpaper help string "still" exists in dash_settings.c; no such string exists at the pin | 7 | S |

**POPSLoader — 86 quick wins**

| ID | Title | Cat | Effort |
|---|---|---|---|
| POPSLOADER-005 | Five copies of POPSTARTER.ELF tracked; the top-level copy is byte-identical to the DEBUG profile | 2 | S |
| POPSLOADER-009 | `graphics.cpp` PNG loader repeats the same row-buffer block three times, with a malloc per row | 2 | S |
| POPSLOADER-012 | Ten workflows, 2,062 lines, including a one-shot retraction workflow that has done its job | 7 | S |
| POPSLOADER-013 | `opencode.yml` is an AI-comment-bot workflow in a repo already carrying heavy agent sprawl | 7 | S |
| POPSLOADER-015 | Docs sprawl at the root: 18 Markdown files, 4,896 lines, plus fossil audit reports in `docs/` | 7 | S |
| POPSLOADER-017 | `lua_dir` puts a 512-entry memory-card table on the EE stack | 6 | S |
| POPSLOADER-020 | `sprintf` into a 16-byte heap buffer, via a pointer truncated to `int`, in the image thread | 6 | S |
| POPSLOADER-021 | Unchecked `getcwd` results in the Lua directory bindings | 6 | S |
| POPSLOADER-022 | Translation data exists in three forms: inline Lua, TSV, and a binary XLSX of the TSV | 2 | S |
| POPSLOADER-025 | Leftover upstream (OPL/Enceladus) TODO block in `fntsys.cpp` describes another project's UI | 1 | S |
| POPSLOADER-026 | Settings save carries a second, diverged copy of the whole commit sequence as a "fallback" | 2 | S |
| POPSLOADER-027 | UDPFS "is it equipped" check re-reads and byte-compares whole IRX files from the memory card on every launch | 5 | S |
| POPSLOADER-028 | A self-described "TEST" HDD write probe runs, and toasts, on every production Settings save | 8 | S |
| POPSLOADER-030 | Settings rollback passes two fields that no longer exist anywhere in the settings system | 6 | S |
| POPSLOADER-031 | Permanently-false flag leaves five dead branches in the hottest launch function | 3 | S |
| POPSLOADER-032 | Seven Lua functions with zero callers, including a near-twin of a live resolver | 1 | S |
| POPSLOADER-034 | DS3 battery byte indexes a 6-entry table with no range check, in all four driver copies | 6 | S |
| POPSLOADER-035 | ps2atad probes the phantom slave drive, then unconditionally throws the result away | 1 | S |
| POPSLOADER-037 | build_site.py wipes its output directory at import time | 7 | S |
| POPSLOADER-038 | ATA security-erase path refreshes status by running IDENTIFY DEVICE into a NULL buffer | 6 | S |
| POPSLOADER-039 | images.lua still carries the fallback machinery for a fallback that was removed | 1 | S |
| POPSLOADER-040 | build_site.py hard-fails the whole docs build unless the corpus has exactly 34 image records, 19 of them from HEAD | 7 | S |
| POPSLOADER-042 | Disc-layout test extracts the code it tests by exact comment strings | 7 | S |
| POPSLOADER-043 | GameList scene still renders a "Not implemented yet" placeholder branch that can never fire | 1 | S |
| POPSLOADER-045 | build_site.py renders its largest page twice per build | 5 | S |
| POPSLOADER-046 | build_site.py defines slug() twice; the first definition is dead | 1 | S |
| POPSLOADER-047 | Clamp01 is defined twice in ui.lua | 2 | S |
| POPSLOADER-048 | Pademu DS4 LED/rumble report is sent with 29 bytes of uninitialised stack | 6 | S |
| POPSLOADER-049 | Pademu ds34 divergence, fully classified: mostly intentional variant, one guard family lost | 2 | S |
| POPSLOADER-050 | EE ds34 client libraries: 12 of 22 exported functions have no caller anywhere | 1 | S |
| POPSLOADER-051 | i18n tables carry 14 dead entries: a superseded toast key in six languages, eight Hungarian-only orphans | 1 | S |
| POPSLOADER-052 | audit_site.py hard-codes page prose and magic numbers as publish-gate law | 7 | S |
| POPSLOADER-053 | fntsys.cpp carries ~232 dead lines: a never-compiled RTL render variant and two caller-less public functions | 1 | S |
| POPSLOADER-056 | audit_published_provenance.py is exact-prose-as-law, end to end | 7 | S |
| POPSLOADER-057 | Two more host gates extract the code they test by exact comment strings | 7 | S |
| POPSLOADER-058 | audit_legacy_tool_overlap.py builds a lookup it never reads | 1 | S |
| POPSLOADER-059 | Fetch-process residue and a content-free failure marker are tracked but cited by nothing | 7 | S |
| POPSLOADER-060 | i.Link documented as "stub / NOT implemented" in three docs; the code implements the full page for Ember and POPSTARTER | 7 | S |
| POPSLOADER-061 | ARCHITECTURE.md says BDMA_ADAPTIVE defaults off; the code defaults it on | 7 | S |
| POPSLOADER-062 | STATE.md's header says Slovak "awaits the contributor; SK is not yet in the picker"; SK shipped in 1.4.3/1.4.4 and is in the picker | 7 | S |
| POPSLOADER-063 | Three docs still claim release 1.1.0 / rolling v1.1.1-dev in their headers; the code reports v1.4.4 | 7 | S |
| POPSLOADER-064 | README's Retro GEM Game ID row lists "On" as the only option; the code is an On/Off toggle | 7 | S |
| POPSLOADER-065 | ARCHITECTURE.md says CoverCache is a 3-entry LRU; the code sets max = 4 | 7 | S |
| POPSLOADER-066 | The loader.c CI parity check never compares the committed dump (and history proves the dump went stale for ~7 weeks behind it) | 6/7 | S |
| POPSLOADER-067 | `src/elf_loader/Makefile:15-16` rule cannot build the child loader (dead rule, INFERRED) | 3/7 | S |
| POPSLOADER-068 | COMPONENTS.md calls the loader.c dump a "~6.5 MB bin2c blob"; it is 855,821 B at the pin | 7 | S |
| POPSLOADER-069 | The shipped MX4SIO `usbhdfsd.irx` has no source anywhere in the repo; the pin beside it does not cover it | 7/8 | S |
| POPSLOADER-070 | Dead `hci_event_flag_*` macros in both ds34 headers reference a variable declared nowhere and have zero call sites | 1 | S |
| POPSLOADER-071 | CSW validation is defeated by pre-filling the receive buffer with the expected signature, tag and success status | 2 | S |
| POPSLOADER-072 | Device-supplied SCSI block length is accepted unvalidated and divided by in the next statement | 2 | S |
| POPSLOADER-073 | Three layers hard-assume 512-byte sectors while nothing enforces a 512-byte device | 2 | S |
| POPSLOADER-074 | GPT parser trusts the on-disk header: entry size ignored, inverted entries underflow the partition size, header bounds never checked against the device | 2 | S |
| POPSLOADER-075 | `get_frag_list` follows the on-disk FAT chain with no cycle bound, and two sibling ioctl cases dereference a possibly-NULL block device | 2 | S |
| POPSLOADER-076 | `scsi_connect` discards `scsi_warmup`'s result and connects the device with zero or stale geometry | 1 | S |
| POPSLOADER-077 | DevCtl STOP_UNIT stops every device and STOP_ALL stops only one: the two command bodies are swapped | 2 | S |
| POPSLOADER-078 | USBD IsoTD halted-flush clears the wrong LUT slot, leaving a stale request pointer in the completed-TD's slot | 2 | S |
| POPSLOADER-079 | Failed hub connect leaves a freed `UsbHub` reachable from the device, and unplug then double-frees it | 2 | S |
| POPSLOADER-080 | Partition read/write translate the sector by the partition offset but never clamp to the partition's own length | 2 | S |
| POPSLOADER-081 | Block cache marks a block valid after a device read whose result it never checks | 2 | S |
| POPSLOADER-082 | `fs_open` honours O_CREAT/O_TRUNC without write access: a read-only open can create or truncate a file to zero | 2 | S |
| POPSLOADER-083 | Mount-info index check admits `index == count` and negative indices, returning an out-of-bounds `block_device*` | 2 | S |
| POPSLOADER-084 | `scsi_warmup`'s TEST UNIT READY loop has no retry bound, and reads an uninitialised sense buffer when REQUEST SENSE fails | 2 | S |
| POPSLOADER-085 | `fs_lseek64` converts negative results to ~2⁶⁴ offsets with no clamp and no invalid-`whence` case | 2 | S |
| POPSLOADER-086 | `cancelTimerCallback` unlinks a timer without folding its remaining delta into its successor, so every later timer fires early | 2 | S |
| POPSLOADER-087 | A failed `f_close` leaks the FIL/DIR pool slot forever: `fs_close` clears the handle unconditionally and FatFs only invalidates on success | 2 | S |
| POPSLOADER-088 | READ CAPACITY's `last_lba` is stored as the sector *count*: every device loses its last sector | 2 | S |
| POPSLOADER-089 | MBR partition entries are trusted exactly as the GPT ones were: no bounds check against the device | 2 | S |
| POPSLOADER-090 | FatFs `FRESULT` codes are returned to iomanX callers as if they were errnos, throughout `fs_driver` | 2 | S |
| POPSLOADER-091 | `fs_read`/`fs_write`/`fs_dread` map every FatFs error to 0, indistinguishable from EOF / nothing-written / end-of-listing | 2 | S |
| POPSLOADER-092 | Filename prefixing for non-zero units uses an unbounded `alloca` on the IOP handler thread's stack | 2 | S |
| POPSLOADER-093 | USBD's HCD pool allocation is `memset` unconditionally: `AllocSysMemory` failure is a NULL-pointer crash at module load | 2 | S |
| POPSLOADER-094 | USBD init failure returns are ignored at every layer, so a dead host stack loads as resident success | 2 | S |
| POPSLOADER-095 | `doUnregisterDriver` leaves the driver's `next`/`prev` set, permanently blocking its re-registration | 2 | S |
| POPSLOADER-096 | `disk_ioctl`'s GET_SECTOR_COUNT writes 4 bytes into FatFs' 8-byte LBA64 buffer (and GET_SECTOR_SIZE into a WORD buffer) | 2 | S |
| POPSLOADER-097 | FatFs glue `ff_req_grant` fabricates success: it ignores `WaitSema`'s result, can never time out, and `ff_del_syncobj` does the same for deletion | 2 | S |
| POPSLOADER-098 | The hub status-change chain abandons itself on any transfer error: one transient hub error permanently stops hot-plug detection | 2 | S |
| POPSLOADER-099 | `HubControlTransfer` silently drops a port reset issued while the hub control request is busy, wedging resets system-wide | 2 | S |
| POPSLOADER-100 | Module-argument integers in USBD accumulate with no overflow or range validation, then size the entire HCD pool layout | 2 | S |
| POPSLOADER-101 | `bd_cache_create` dereferences both `AllocSysMemory` results unchecked | 2 | S |
| POPSLOADER-102 | Stat timestamps report seconds ≥ 32 as 32 seconds early: the seconds recovery masks instead of multiplying | 2 | S |
| POPSLOADER-103 | Unknown `ioctl2` commands return success having done nothing | 2 | S |
| POPSLOADER-104 | `disk_ioctl` returns RES_OK for every command it does not implement | 2 | S |
| POPSLOADER-105 | `fs_dread`'s name copy can leave the returned dirent unterminated at maximum-length filenames | 2 | S |
| POPSLOADER-106 | MBR parser leaks its 512-byte scratch block on the read-failure path (every other error path frees it) | 4 | S |
| POPSLOADER-107 | The ASYNC half of `usb_queue_cmd` is dead code that also skips CSW status validation entirely | 1 | S |
| POPSLOADER-108 | GPT partition `sectorCount` is one sector short for every valid partition (last LBA is inclusive) | 6 | S |

**SMS — 129 quick wins**

| ID | Title | Cat | Effort |
|---|---|---|---|
| SMS-002 | Dead 373 KB IOP image header: `s_iop_image.h` is only referenced from commented-out code | 1 | S |
| SMS-005 | Every language pack exists twice, and the two copies have already diverged | 2 | S |
| SMS-006 | Two embedded IRX blobs are never loaded: `bdmfs_vfat.irx.xz` and `mmcedrv.irx.xz` | 1 | S |
| SMS-007 | A `.bak` file is tracked despite the repo's own `*.bak` ignore rule | 7 | S |
| SMS-008 | Investigation handoff folder that orders its own deletion is merged to master, with mutated crash-test media | 7 | S |
| SMS-011 | TEMP save-diagnostic is permanent release code, with a global buffer and duplicated save paths | 3 | S |
| SMS-016 | Unchecked SBR allocations in the AAC decoder | 6 | S |
| SMS-018 | Two vendored network stacks plus three copies of the same headers in `iop/` | 2 | S |
| SMS-021 | `#if 0` and commented-out code blocks in the EE tree | 1 | S |
| SMS-023 | Branch and tag clutter: checkpoints, agent threads and mutable tags | 7 | S |
| SMS-024 | Six workflows, three of which rebuild/republish documentation or media on every master push | 7 | S |
| SMS-029 | Identical and near-identical theme/icon assets shipped in two theme trees | 4 | S |
| SMS-030 | Root-level stale/duplicate meta-documents | 7 | S |
| SMS-031 | `utils/DDrawSrv.exe` — a 44 KB Windows binary with no source and no in-repo reference | 7 | S |
| SMS-032 | Legacy download binaries and archives committed under docs/downloads | 7 | S |
| SMS-033 | Prebuilt VU microcode objects with no source in the repo | 7 | S |
| SMS-035 | SMB credentials written to the memory card / filesystem in plaintext | 6 | S |
| SMS-036 | The whole legacy SMB IOP source tree is built by nothing — and contains the same client twice | 1 | S |
| SMS-038 | The audio-only renderer runs an FFT and a ball simulation every frame, even when both visuals are off | 5 | S |
| SMS-039 | AVI stream-name chunks: file-supplied size goes straight to `malloc` — unclamped and unchecked | 6 | S |
| SMS-040 | The TEMP save diagnostic can itself overflow a 64-byte global on the failure path it exists to debug | 6 | S |
| SMS-044 | One CDDA path append bypasses the capacity-checked helper every other append uses | 6 | S |
| SMS-046 | Language-pack strings are used as `sprintf` format strings throughout — the pack test is the only gate, and it doesn't check `%` sequences | 6 | S |
| SMS-047 | Boot splash holds a static frame for a full second, between two 17-frame fades | 5 | S |
| SMS-048 | The still-live legacy IOP blob sources have no build path, no workflow, and no provenance note | 7 | S |
| SMS-050 | ASF: a missing or zero file-properties object leaves `packet_size` at 0, and the packet reader divides by it | 6 | S |
| SMS-051 | Three IOP starters claim residency/ownership without checking whether the module loaded — the exact failure the file's newer starters were written to prevent | 6 | S |
| SMS-052 | WAV-header helper: a format size of exactly 17 turns its own clamp negative — `malloc(0)` followed by a 4 GiB `Read` into it | 6 | S |
| SMS-053 | The 1024-pixel gate is one-sided: negative AVI/ASF dimensions reach MPEG-4 geometry initialisation | 6 | S |
| SMS-054 | ODML index entry loop is unbounded and publishes an unchecked `SMS_Realloc` result | 6 | S |
| SMS-055 | ODML index-of-indexes recursion has no depth limit | 6 | S |
| SMS-056 | AVI `_ReadPacket`'s movi-boundary test uses the file position captured at function entry | 6 | S |
| SMS-059 | `GSFont_UnpackChr` indexes the glyph-offset table with an unvalidated character code | 6 | S |
| SMS-060 | `SMS_LZMA2Decompress`'s size guard frees the buffer, then decompresses into it anyway | 6 | S |
| SMS-062 | `CDDA_InitFileContext` dereferences the internal init result without a NULL check | 6 | S |
| SMS-063 | `_read_string` runs `strlen` on a stack buffer the disc image never has to NUL-terminate | 6 | S |
| SMS-064 | `GUI_LoadIcons` dereferences two unchecked allocations, one of them through the LZMA decompressor | 6 | S |
| SMS-066 | GS display-list allocations are dereferenced unchecked, including through a realloc helper whose contract is "NULL on failure" | 6 | S |
| SMS-067 | `GUI_Status` loses the status-line DMA buffer permanently on realloc failure | 6 | S |
| SMS-069 | `_produce_packets` dereferences unchecked `memalign`/`calloc` in subtitle Prepare | 6 | S |
| SMS-070 | Language/subtitle cycling dereferences a NULL list node for containers with no such stream | 6 | S |
| SMS-071 | `_find_signature` puts a 1,204,224-byte buffer on the stack | 6 | S |
| SMS-073 | Transient menus never free their `m_pState` list, node, or `GUIMenuState` | 6 | S |
| SMS-075 | `IPU_UnpackImage` is dead code (~105 lines including a large inline-asm DMA loop) | 1 | S |
| SMS-077 | The empty `_file_handler` assigned to every playlist-menu item does nothing and is not needed | 1 | S |
| SMS-081 | DevMenu removal redraws every successor icon twice, once at a wrong offset; Render builds the selection arrow twice | 2/5 | S |
| SMS-083 | Palette-rotate logic exists in four copies (two helpers + two inline) | 2 | S |
| SMS-086 | USB connect/disconnect SIF handlers are mirror copies | 2 | S |
| SMS-088 | `g_ASCII` size mismatch: the extern declares 4572, the definition is 5416, so `GSFont_Get(0)` under-reports by 844 bytes | 6 | S |
| SMS-092 | `_smb_logon` copies credentials with the destination's bound, not the source fields' | 6 | S |
| SMS-093 | History load has no record cap, and its allocator drops the NULL check its sibling has | 6 | S |
| SMS-094 | `DSP_MDCTInit`'s only error path is dead code: `!DSP_iFFTInit(...) < 0` can never be true | 6 | S |
| SMS-095 | `DSP_MDCTInit` never checks its `m_pCos` allocation before writing through it | 6 | S |
| SMS-096 | `SMSContainer_DefReadPacket`: a dead clamp, a wrong-buffer unalloc, and an unchecked packet allocation | 6 | S |
| SMS-097 | `SMSContainer_CalcPktFields` divides by the file's bit rate, in 32-bit arithmetic | 6 | S |
| SMS-098 | `SMS_GetContainer`'s explicit-probe path skips the bounds check and throws away the result | 6 | S |
| SMS-099 | `SMSContainer_SetName`'s backward slash scan has no start-of-string stop | 6 | S |
| SMS-100 | The history record-read loop exists three times | 2 | S |
| SMS-101 | The locale loader's read-whole-file block exists three times, its retry twice | 2 | S |
| SMS-102 | Probe-order array is dimensioned in bytes, not elements: 156 stack bytes for nothing | 4 | S |
| SMS-103 | SMSUMS LFN direntry sequence number is an unchecked index multiplier: writes at −13…+818 into a 128-byte name buffer on callers' stacks | 6 | S |
| SMS-104 | DTS `prim_channels` (1–8 from the frame header) written into state arrays sized 5 | 6 | S |
| SMS-105 | MPEG-4 sprite trajectory: up to 63 warp points written into a stack `int[4][2]` | 6 | S |
| SMS-106 | Vorbis residue `booklist` overwrite: cascade popcount sum reaches 512 into a 256-entry array | 6 | S |
| SMS-107 | Vorbis floor1 total post count unbounded: `postlist` heap overwrite in unpack, stack/heap overwrite in look | 6 | S |
| SMS-108 | Vorbis residue `begin`/`end`/`grouping` (24-bit each) never validated against block size: decode writes at file-controlled offsets into the PCM buffer | 6 | S |
| SMS-109 | lwIP `ip_reass` trusts the header's total length over the received chain: `copy_from_pbuf` walks off the chain end and dereferences NULL | 6 | S |
| SMS-110 | SMSUMS READ CAPACITY sector size stored verbatim: 0 divides by zero, >128 KiB overflows the cache buffer on the first read | 6 | S |
| SMS-111 | AAC PCE channel totals: the `> MAX_CHANNELS` check runs after construction and its return is ignored by two of three callers; unchecked totals index `internal_channel[]` / `channel_position[]` | 6 | S |
| SMS-112 | Vorbis `decodemap[temp]` indexed by a phrasebook decode result with no `temp < partvals` check; the fetched pointer is dereferenced | 6 | S |
| SMS-114 | DTS downmix table indexed by two unmasked 6-bit header values into an `[11][10]` table | 6 | S |
| SMS-118 | Vorbis codebook `entries * dim` (maptype 2) and maptype-1 accumulation overflow int size math | 6 | S |
| SMS-119 | Vorbis `res0_look`: `partvals = pow(parts, dim)` overflows int and wraps the decodemap allocation size | 6 | S |
| SMS-120 | Vorbis ordered codebook lengths grow past 32: `_make_words` indexes `marker[33]` by length, `oggpack_look` indexes `mask[33]` by `dec_maxlength` | 6 | S |
| SMS-121 | Vorbis blocksize field permits window-table index −3…9 into `vwin[8]` | 6 | S |
| SMS-122 | AAC ADTS/ADIF `sf_index` (12–15) stored unchecked; `window_grouping_info` indexes 12-entry sample-rate tables by it | 6 | S |
| SMS-124 | AAC `section_data`: zero-length sections write the per-section arrays at `i == 120` *before* the `i` bound check fires (short windows) | 6 | S |
| SMS-125 | WMA superframe `bit_offset` never bounded before re-basing the bit reader: negative size becomes a huge bit count past the packet | 6 | S |
| SMS-126 | DTS bit reader has no end pointer at all: decode loops can consume past the frame buffer | 6 | S |
| SMS-128 | XZ size oracle `lzma2_get_uncompressed_size` performs unbounded, unvalidated index parsing: size < 12 underflows the footer pointer, `backward_size` drives the index pointer before the buffer, and the record loop walks without any length | 6 | S |
| SMS-129 | lwIP TCP data-offset never validated: ignored `pbuf_header` return underflows `len`/`tot_len` to ~65 KB | 6 | S |
| SMS-130 | lwIP UDP: a datagram shorter than the UDP header makes the "drop short packets" branch dead and can be delivered with a ~65 KB length | 6 | S |
| SMS-131 | SMAP received-frame length from the buffer descriptor is never clamped to the 1,540-byte pool slot before alloc + FIFO copy | 6 | S |
| SMS-132 | USBD descriptor walk validates only `bLength >= 2`: truncated descriptors are returned as full structs and read at fixed offsets | 6 | S |
| SMS-134 | Vorbis codebook `dim == 0` never rejected: float divide-by-zero + non-terminating quantvals search in setup | 6 | S |
| SMS-135 | Vorbis audio packet `mode` never checked against `modes`: NULL mode_param dereference | 6 | S |
| SMS-136 | Vorbis floor0 `order == 1` passes unpack, then `vorbis_lsp_to_curve`'s do-while decrements its counter through zero and walks `lsp` out of bounds | 6 | S |
| SMS-137 | DTS `bitalloc_huffman == 7` selects a Huffman table past the end of `bitalloc_12[5]` | 6 | S |
| SMS-138 | DTS cumulative Huffman scale-factor sum used as an unchecked scale-table index | 6 | S |
| SMS-139 | DTS LFE scale factor: 8-bit index into a 128-entry table | 6 | S |
| SMS-141 | WMA exponent VLC band length `n == 0` produces a ~2³²-iteration write loop | 6 | S |
| SMS-143 | MSMPEG4 slice height can be 0 → modulo-by-zero in the decode loop | 6 | S |
| SMS-144 | MPEG-4 interlaced direct-MV field-time divisor can be 0 | 6 | S |
| SMS-145 | MP123 gain table base + scalefactor index can exceed `s_GainPow2[378]` on the LSF (MPEG-2/2.5) path | 6 | S |
| SMS-146 | FLAC wasted-bits count has no lower bound: `m_CurBPS` goes negative into the bit macros | 6 | S |
| SMS-147 | FLAC fixed-predictor warm-up reads `decoded[-1…-4]` for predictor orders 0–3 | 6 | S |
| SMS-148 | DXSB header width drives RLE writes past the scratchpad free region; packet size never validated against the header size | 6 | S |
| SMS-149 | MP123 region-2 start index can read past `m_LongIdx[23]` (low severity, intra-struct) | 6 | S |
| SMS-150 | SMSUMS `_set_dir_chain` treats a −1 chain error as a completed chain and reads `m_ClusterBuf[-1]` | 6 | S |
| SMS-152 | lwIP reassembly bitmap is indexed at 90 (of 0–89) when the reassembled length is exactly 5,760 | 6 | S |
| SMS-154 | `DSP_FFTGet` loop count is built from an uninitialised register (`addiu $v0, $v0, 32` before `$v0` is ever set) | 6 | S |
| SMS-155 | Asm `s_GSParams` layout diverges from C `GSParams` after the 576P slot: every PAR word from offset 44 sits one slot early (latent today) | 6 | S |
| SMS-156 | Three fully dead assembly routines: `GS_XYZF`, `SMS_iTimerReset`, `inet_ntoa` (Cat 1) | 1 | S |
| SMS-157 | Four dead assembly exports whose bodies are live under a second name: `GS_RRV`, `_MPEG_AlignBits`, `ip_cksum`, `inet_aton` (Cat 1) | 1 | S |
| SMS-158 | SMSTCPIP `do_connect` ignores `tcp_connect`'s return: a synchronous failure hangs `netconn_connect` forever | 6 | S |
| SMS-159 | SMSTCPIP sockets layer: `get_socket` indexes the 15-entry socket table with a completely unchecked fd | 6 | S |
| SMS-160 | AAC two-step Huffman size arrays disagree with the actual second-stage table counts in both directions — 5 of 7 non-trivial entries are wrong, so the bound the decoders check against is not the bound that exists | 6 | S |
| SMS-161 | DTS scale-factor quantizer tables end in zeros: `scale_factor_quant6[63] = 0` and `scale_factor_quant7[125..127] = 0` break a strictly increasing 63/125-entry run — the largest scale factors decode as silence | 6 | S |
| SMS-162 | USBD host-controller init memsets through an unchecked `AllocSysMemory` result, and the failure is then hidden twice | 6 | S |
| SMS-163 | SMSTCPIP `lwip_close` dereferences NULL on any invalid-but-in-range fd (double close crashes) | 6 | S |
| SMS-165 | USBD done-queue isochronous cleanup clears the wrong LUT slot, leaving stale IoRequest pointers | 6 | S |
| SMS-166 | SMSTCPIP `lwip_accept` uses the accepted connection and the caller's address buffers with no NULL checks | 6 | S |
| SMS-167 | SMSTCPIP `netbuf_ref` dereferences a possibly-NULL `pbuf_alloc` result (UDP send under pbuf exhaustion crashes) | 6 | S |
| SMS-168 | SMSMAP PHY reset result is discarded and the LINK flag is never cleared: a dead PHY leaves SMAP reporting link-up | 6 | S |
| SMS-169 | SMSMAP `_start` returns resident-end unconditionally over unchecked kernel-object creation | 6 | S |
| SMS-170 | SMSTCPIP `netconn_addr` lacks the PCB NULL check its sibling `netconn_peer` has | 6 | S |
| SMS-171 | SMSMAP transmit: chained-pbuf gather copies `tot_len` bytes into a 1,520-byte static buffer bounded only by the 4,096-byte FIFO credit | 6 | S |
| SMS-172 | Docs: the Devices/Settings pages state Start rows appear only while a device is stopped; the MX4SIO/MMCE Start rows are always shown | 7 | S |
| SMS-173 | AC3 IMDCT entry points take a bias parameter that is never used; the caller's per-channel bias computation is silently dropped | 1 | S |
| SMS-174 | DTS integer quantizer tables `lossy_quant` / `lossless_quant` are dead: zero references repo-wide; only their float `_d` twins are ever read (256 bytes of `.data`) | 1 | S |
| SMS-175 | SMSTCPIP dead dispatch slot: `do_accept` / `API_MSG_ACCEPT` can never be posted, and would hang its poster if it were | 1 | S |
| SMS-176 | SMSMAP dead helper: `_smap_emac3_ready` is defined in the SMAP header and called nowhere | 1 | S |
| SMS-177 | AC3 IMDCT: dead instructions in `_ifft2` (and one in `BUTTERFLY_ZERO`) are overwritten before any read | 1 | S |
| SMS-178 | AC3 IMDCT: `_ifft128` open-codes `_ifft64`'s entire body instead of calling it | 2 | S |
| SMS-179 | SMSTCPIP `err_to_errno` maps every error to EIO: the signed/unsigned comparison makes the 11-entry errno table unreachable | 6 | S |
| SMS-180 | USBD `initCallbackThread` never checks thread creation and returns success unconditionally; `hcdInit` discards even that — if the callback thread does not exist, no USB transfer completion is ever delivered | 6 | S |
| SMS-182 | SMSTCPIP `tcp_next_iss` is fully predictable: fixed seed 6510 plus the deterministic `tcp_ticks` accumulator | 6 | S |
| SMS-183 | SMSTCPIP `lwip_getpeername` / `lwip_getsockname` ignore `netconn_peer` / `netconn_addr`'s return: a guarded error becomes a successful garbage result (and SMS-170's fix alone does not save `lwip_getsockname`) | 6 | S |
| SMS-184 | USBD `hcdInit` never checks the HCD IRQ thread's creation: `hcdTid` failure leaves USB interrupts waking a nonexistent thread while `hcdInit` returns 0 | 6 | S |

**PS2-Servers — 72 quick wins**

| ID | Title | Cat | Effort |
|---|---|---|---|
| PS2SERVERS-002 | Standalone UDPFS keeps its own CLI, parser and run loop purely as a rollback path | 8 | S |
| PS2SERVERS-007 | The version of `_append_log` inside gui.py is dead — the main.py shim replaces it before the GUI runs | 1 | S |
| PS2SERVERS-009 | 159 remote branches and 118 tags, including 81 auto-generated `main-<n>-<hash>` tags and 9 `backup/*` branches | 7 | S |
| PS2SERVERS-015 | 1,608 lines of self-tests live inside the shipped server directories and duplicate the real test suite | 7 | S |
| PS2SERVERS-016 | ~3.1 MB of binary disc-image fixtures are tracked in the Go tree, and the repo banner is tracked twice, byte-identical | 7 | S |
| PS2SERVERS-019 | Verbose per-request logging is the default for every server, is force-migrated on for existing installs, and is pumped into the GUI every 150 ms | 5 | S |
| PS2SERVERS-022 | Connection admission is capped in NFS (32) and UDPFS (256) but uncapped in SMB1, SMB2 and HTTP | 6 | S |
| PS2SERVERS-023 | Default posture is guest/writable/open on a server meant to be found by broadcast | 6 | S |
| PS2SERVERS-029 | Scope creep around the servers: Discord Rich Presence, achievement sounds, art fetching, OBS export | 8 | S |
| PS2SERVERS-031 | Two spellings of headless mode are kept forever: `serve` and `--serve`, normalised in two places | 3 | S |
| PS2SERVERS-032 | Portable-mode detection writes a probe file on every config access | 5 | S |
| PS2SERVERS-034 | Go's only module dependency, `golang.org/x/net`, exists for one 27-line Linux batch-write file | 4 | S |
| PS2SERVERS-036 | Hand-rolled tray, twice, plus a third status-dot mechanism in the GUI | 2 | S |
| PS2SERVERS-039 | Agent/tooling and handoff clutter tracked in the repo root and docs | 7 | S |
| PS2SERVERS-040 | Example credential literal in the SMB2 module docstring | 6 | S |
| PS2SERVERS-043 | SMB2: a read-only handle can delete any file on a writable share via SET_INFO disposition + CLOSE | 6 | S |
| PS2SERVERS-044 | SMB1: a truncated request kills the connection thread with an uncaught struct.error | 6 | S |
| PS2SERVERS-045 | Neither SMB framing layer caps the declared message length (24-bit, up to 16.7 MB) against the 1 MiB the servers advertise | 6 | S |
| PS2SERVERS-046 | SMB1: open files and search snapshots per connection are uncapped — real file descriptors, held indefinitely | 5 | S |
| PS2SERVERS-047 | NFS: the filehandle registry only ever grows — every path ever looked up is remembered for the server's lifetime | 4 | S |
| PS2SERVERS-048 | Startup: the LAN-IP detection runs a subprocess synchronously in _build, before first paint | 5 | S |
| PS2SERVERS-049 | Startup: ~0.4 s of imports happen before Tk exists, including subsystems the first screen never uses | 5 | S |
| PS2SERVERS-050 | SMB2 FLUSH reports success when the flush/fsync failed — and is the one handler with no body-length check | 6 | S |
| PS2SERVERS-051 | SMB2: a single compound message can chain an unbounded number of requests | 5 | S |
| PS2SERVERS-052 | GUI log pump: per-line string building + a Tk index() call per batch are the steady-state cost the verbose default (round-1 -019) multiplies | 5 | S |
| PS2SERVERS-053 | SMB2: handles per connection are uncapped (CREATE mints forever; descriptors follow on first read/write) | 5/6 | S |
| PS2SERVERS-054 | Edge's binary size is measured against three different Go toolchains — the size gate is partly measuring the compiler | 7 | S |
| PS2SERVERS-055 | The SMB1↔SMB2 framing code exists twice (send_msg/recv_msg), despite the SMB2 module claiming it was "moved" | 2 | S |
| PS2SERVERS-056 | UDPFS (Python, both editions): BWRITE is never checked against the block device's size — a client can extend the operator's image at any sector and is told it succeeded | 6 | S |
| PS2SERVERS-057 | UDPFS (Python, both editions): BWRITE completion never compares delivered bytes to the declared sector count — short writes are silently partial and reported as success | 6 | S |
| PS2SERVERS-058 | UDPBD (Python): image files get none of the capacity validation raw devices get — WRITE extends the image, READ streams up to ~32 MiB of padding for any range | 6 | S |
| PS2SERVERS-059 | srvsvc: the PDU body slice wraps when auth_len exceeds the declared PDU — the parser reads past frag_len instead of rejecting the PDU | 6 | S |
| PS2SERVERS-060 | UDPFS standalone truncates over-declared DATA packets and processes them; the shipped Core and Go drop them — the rollback copy validates framing differently from the product | 2 | S |
| PS2SERVERS-063 | compressed_iso serving path trusts the file's declared block/hunk size — a 32-byte crafted CSO makes the server materialise a 256 MiB block; the strict path and Go both cap the same field at 16 MiB | 6 | S |
| PS2SERVERS-064 | ZSO serving decompression retries LZ4 once per byte of an attacker-sized span — 100,000 decompress attempts for one 100 KB block — and can "succeed" with a zero-length block the base class then serves as data | 5 | S |
| PS2SERVERS-065 | CSO serving never validates a block's span: an index pair one entry apart makes it read the rest of the file as one block's input | 6 | S |
| PS2SERVERS-066 | Both launcher block devices assign seek state before validating it — a failed seek leaves position, request end and (for raw devices) a stale cache armed for the next read | 6 | S |
| PS2SERVERS-067 | AES-CMAC's native backend is a probe-time-only fallback: a native failure mid-session raises out of the signing path and drops the connection instead of using the pure-Python reference in the same file | 6 | S |
| PS2SERVERS-068 | OpenWrt service-log snapshot ignores the line bound the package documents and the systemd path honours | 4 | S |
| PS2SERVERS-069 | UCI boolean parsing is split in one Load function — sixteen keys misread the UCI vocabulary, including all three `read_only` keys (fail-open) | 6 | S |
| PS2SERVERS-070 | Every shipped Edge archive tells its user the server is "read-only by default" — the binary defaults to writable | 6 | S |
| PS2SERVERS-072 | PS2SERVERS-068 is untestable by the Go suite as written: the only log manager under test is a fake that discards the `lines` argument, and no real manager has a test | 8 | S |
| PS2SERVERS-074 | The "without LZ4" ZSO hash tests patch `LZ4_AVAILABLE` to **True** — they simulate presence, and the no-LZ4 behaviour is never tested | 8 | S |
| PS2SERVERS-075 | Mid-file `unittest.main()` in two SMB test files orphans 28 tests on direct execution — and the direct run still reports green | 7 | S |
| PS2SERVERS-076 | Path-guard selftest prints "ALL PASSED" in CI while its UNC section — one of its three pinned properties — never executes there | 7 | S |
| PS2SERVERS-077 | The three SMB "bounded" tests assert no bound — an unbounded, leaking implementation passes all three | 8 | S |
| PS2SERVERS-079 | tests/test_udpfs_bind_control.py skips in every CI run — the bind-control → `--bind` argv path gates nothing | 7 | S |
| PS2SERVERS-080 | tests/test_chd_cd_size.py never runs in CI: libchdr is built *after* the discovery run that would collect it | 7 | S |
| PS2SERVERS-081 | The native-engine test class can skip wholesale and stay green — it lacks the CI hard-fail its sibling classes carry | 7 | S |
| PS2SERVERS-082 | The suite's one Windows-only test never runs in CI — no Windows `go test` job exists anywhere | 7 | S |
| PS2SERVERS-083 | The 32-bit wrap regression test never runs on a 32-bit target — the only configuration where the defect can recur | 7 | S |
| PS2SERVERS-084 | test_desktop_instance.py's two real-mutex tests run on no CI job | 7 | S |
| PS2SERVERS-085 | `TestInfoResetsStaleWriteState` never tests the reset — it asserts only a later read's length, which passes whether or not INFO cleared anything | 8 | S |
| PS2SERVERS-086 | `TestServerPortFallback` asserts no port — the fallback it names could be deleted and the test would still pass | 8 | S |
| PS2SERVERS-087 | `tryTrans2` cannot fail: it returns `nil` unconditionally while calling the helper that already `Fatal`s — its callers' error branches are dead | 1 | S |
| PS2SERVERS-088 | A registry-guard test's docstring describes the fake SMB2 (PS2SERVERS-042) in the present tense as the shipped behaviour — and the test does not guard that fake at all | 7 | S |
| PS2SERVERS-089 | `test_widen_on_a_real_socket` cannot fail if widening is a no-op — a flaw the file's own docstring states verbatim | 8 | S |
| PS2SERVERS-090 | The suite's only Python↔Go wire cross-check converts a Go timeout into a skip | 7 | S |
| PS2SERVERS-091 | The banner address-listing test's only assertions sit in a loop over a host-dependent list that may be empty | 8 | S |
| PS2SERVERS-094 | The companion-fixture link/locked assertions exist only inside `if self.made[…]` conditionals — a degraded fixture passes silently | 8 | S |
| PS2SERVERS-096 | Two SMBv1 tests assert only the constructor assignment they just made, under names claiming wire behaviour they never exercise | 8 | S |
| PS2SERVERS-097 | multiclient_selftest's concurrency test has a `return True` "SKIP" branch that would aggregate into "ALL PASSED" | 8 | S |
| PS2SERVERS-098 | The supervisor's state-HTTP probe swallows every exception, so its only failure signal is an unexplained empty box | 8 | S |
| PS2SERVERS-099 | The HTTP hot-path cost guard does not watch `os.scandir`, which the same module's scan paths use | 8 | S |
| PS2SERVERS-100 | `inRange` is genuinely boundary-tested — except the two cases its arithmetic makes interesting | 8 | S |
| PS2SERVERS-102 | The About-page version-label expectation is built from the module under test | 8 | S |
| PS2SERVERS-103 | The suite's only fuzz target is never fuzzed — CI runs its three seed inputs as an ordinary test | 7 | S |
| PS2SERVERS-107 | The native-engine/CDLL boilerplate is duplicated between the RA evaluator and owned-service test files; the CI hard-fail guard is pasted five times | 2 | S |
| PS2SERVERS-108 | The same fake urllib `Opener` class is redefined 15 times across three RA test files | 2 | S |
| PS2SERVERS-113 | One vendored xeRAbora modification is undocumented: sound.c's shell-command escaping hardening appears in neither the vendor README nor the upstream-audit doc | 7 | S |
| PS2SERVERS-114 | SMB1 server's embedded SMB2: TREE_CONNECT and CLOSE always raise `struct.error` and kill the connection thread — on well-formed requests | 6 | S |
| PS2SERVERS-115 | SMB1 server's embedded SMB2: the SMB2 header packer/parser is 66 bytes, not 64 — `Command` is encoded as a 4-byte field | 6 | S |

**Cross-repo — 28 quick wins**

| ID | Title | Cat | Effort |
|---|---|---|---|
| X-22 | Intra-binary duplicate machinery found at function level (three small pure deletions) | 2 | S |
| X-24 | Network-init constants have speciated — including inside one repo | 3/5 | S |
| X-26 | One malformed line silently amputates Launchstation's main CNF — and the next save makes it permanent | 6 | S |
| X-27 | POPSLoader config semantics invert the family on both axes (first-wins + save-deletes-unknowns) | 6/3 | S |
| X-28 | RiptOPL carries the same CRC-32 text three times, and two CRC-32-family functions in one EE binary | 2 | S |
| X-30 | Self-update trust/policy divergences that should be decisions, not accidents | 6/3 | S |
| X-31 | RiptOPL's UDPRDMA receive path copies a wire-controlled app header into an 8-byte stack buffer, unchecked — SMS's fork of the same file has the clamp | 6 | S |
| X-33 | The three server editions honour three different limit sets — and the Python editions honour none of the header's | 6/3 | S |
| X-35 | SMS is the only PS2 repo whose main config save is never change-gated — and it fires as a side effect of unrelated operations | 5/4 | S |
| X-36 | SMS carries two UDPFS front-ends it never builds (bd + fhi, 267 lines) | 1/7 | S |
| X-37 | DiscHeader bytes 2–3: "reserved, must be 0" in the C spec, a live data port in the Python server | 6/8 | S |
| X-38 | Go Edge zeroes all timestamps and attrs in UDPFS replies the other editions fill | 6/8 | S |
| X-39 | POPSLoader pays triple-write atomicity for a disposable cache and a single direct write for the same-format HDD cache | 4/5 | S |
| X-40 | Launchstation rewrites DASHAPPS.CNF on every app launch; RiptOPL's equivalent launch save writes nothing | 5 | S |
| X-41 | The ps2build SDK machinery is one codebase hand-copied across two repos — identical pins, doubled maintenance | 2 | S |
| X-42 | `actions/checkout` is pinned at six different generations across the family — including three inside POPSLoader | 7 | S |
| X-43 | The same ps2dev toolchain image is pinned three incompatible ways — and POPSLoader's is a mutable tag | 7 | S |
| X-44 | Only RiptOPL's CI enforces formatting — Launchstation and SMS own `.clang-format` files no workflow runs | 7 | S |
| X-47 | SMSTCPIP lives as two diverged forks (RiptOPL hardened, SMS pristine) with no cross-port route — the X-32 pattern on a second stack | 2 | S |
| X-48 | Wiki publishing is implemented four times — three hand-rolled YAML copies and one tested program | 2/7 | S |
| X-50 | mcman validation: the family's best card parser and its worst are in the same repo — Launchstation's EE viewer holds all three checks its IOP vmcman lacks, and RiptOPL holds the family's best gate | 6/2 | S |
| X-51 | Rumble-strength scaling is split by lineage, not by repo: every pademu copy scales `rrum * 255`, every standalone copy passes it raw — in both transports, in both repos that carry pademu | 2 | S |
| X-52 | Checked-in generated artefacts have no drift gate in Launchstation or SMS — the checks exist (or are proven byte-stable) but nothing runs them | 7 | S |
| X-53 | Launchstation's dashboard font artefacts cannot be regenerated from the repo — their TTF inputs are not tracked | 7 | S |
| X-55 | The POPSTARTER "versions" are one binary patched in a single dword — and the default ELF is the DEBUG-flagged build | 8 | S |
| X-56 | RiptOPL's `drvtif-ingame.irx` has been a byte-copy of `drvtif.irx` since its introduction — the in-game DECI2 flavour embeds the UI module | 8/1 | S |
| X-58 | RiptOPL's PC-tool CRC-32 copies retain the signed-byte negative-index read the EE copy fixed | 6 | S |
| X-59 | RiptOPL's BDMAssault PROVENANCE.md omits the .udpfs pair it ships | 7 | S |

### 3(b) Combined top tier — Category 6 findings the SUMMARY addenda / round reports themselves flagged as headline/top-tier

Taken only from the flagging text of the SUMMARY addenda (and the pass-1 Top 25’s three rows explicitly marked “Bug:”), in the order the addenda present them; nothing here is re-ranked. Only Category 6 items are listed (dual categories count by their first number). Flagged items that fail that filter are named in the note after the table, not silently dropped.

| Flagged in | ID | Title |
|---|---|---|
| Pass 1 — SUMMARY Top 25, the three rows flagged “Bug:” | PS2SERVERS-013 | No single-writer exclusion in UDPFS — two peers can interleave writes to the same file, in every edition |
| Pass 1 — SUMMARY Top 25, the three rows flagged “Bug:” | RIPTOPL-016 | SMB credentials and share names strcpy'd into fixed cdvdman settings fields |
| Pass 1 — SUMMARY Top 25, the three rows flagged “Bug:” | SMS-015 | MOV container trusts file-supplied entry counts for malloc size |
| Round 2 addendum — “New Top-tier findings this round” | X-18 | Launchstation writes a `title.cfg` dialect RiptOPL silently cannot read — app never appears (WORST new bug) |
| Round 2 addendum — “New Top-tier findings this round” | RIPTOPL-037 | NBNS receive thread can be overflowed by any host on the LAN |
| Round 2 addendum — “New Top-tier findings this round” | PS2SERVERS-043 | SMB2: a read-only handle can delete any file on a writable share via SET_INFO disposition + CLOSE |
| Round 2 addendum — “New Top-tier findings this round” | LAUNCHSTATION-034 | Self-update now overwrites the running ELF in place: no staging, no backup, no readback — one interrupted write bricks the install |
| Round 2 addendum — “New Top-tier findings this round” | PS2SERVERS-044 | SMB1: a truncated request kills the connection thread with an uncaught struct.error |
| Round 3 addendum — “New top-tier this round” | LAUNCHSTATION-053 | SMB READ/WRITE offsets are truncated to 32 bits before reaching the card |
| Round 3 addendum — “New top-tier this round” | POPSLOADER-048 | Pademu DS4 LED/rumble report is sent with 29 bytes of uninitialised stack |
| Round 3 addendum — “New top-tier this round” | SMS-052 | WAV-header helper: a format size of exactly 17 turns its own clamp negative — `malloc(0)` followed by a 4 GiB `Read` into it |
| Round 3 addendum — “New top-tier this round” | LAUNCHSTATION-056 | smbman's `FileTimeToDate` computes wrong calendar dates — and it is the third, divergent copy of a conversion the other two drivers do correctly |
| Round 3 addendum — UDPFS-closure paragraph (the round’s headline protocol results) | X-31 | RiptOPL's UDPRDMA receive path copies a wire-controlled app header into an 8-byte stack buffer, unchecked — SMS's fork of the same file has the clamp |
| Round 3 addendum — UDPFS-closure paragraph (the round’s headline protocol results) | PS2SERVERS-056 | UDPFS (Python, both editions): BWRITE is never checked against the block device's size — a client can extend the operator's image at any sector and is told it succeeded |
| Round 3 addendum — UDPFS-closure paragraph (the round’s headline protocol results) | PS2SERVERS-057 | UDPFS (Python, both editions): BWRITE completion never compares delivered bytes to the declared sector count — short writes are silently partial and reported as success |
| Round 3 addendum — UDPFS-closure paragraph (the round’s headline protocol results) | PS2SERVERS-058 | UDPBD (Python): image files get none of the capacity validation raw devices get — WRITE extends the image, READ streams up to ~32 MiB of padding for any range |
| Round 4 addendum — “New top-tier” | RIPTOPL-066 | BT DS4 output report: buffer zeroed with the DS3 length, sent with the DS4 length — in both Bluetooth copies |
| Round 4 addendum — “New top-tier” | RIPTOPL-067 | ps2ips `do_setsockopt` copies an EE-supplied length into a 128-byte stack buffer with no bound |
| Round 4 addendum — “New top-tier” | LAUNCHSTATION-079 | Superblock geometry is copied into `MCDevInfo` with no validation, then used as divisors, loop bounds and buffer offsets |
| Round 4 addendum — “New top-tier” | LAUNCHSTATION-080 | `McGetFATentry`/`McSetFATentry` index `ifc_list[ifc_index]` with an unbounded `fat_index` — and card FAT values feed the same path |
| Round 4 addendum — “New top-tier” | LAUNCHSTATION-081 | Card-supplied entry names are still passed to `strlen`/`strcmp`/`strcpy` unterminated — the terminated-copy fix (delta D8) covered only the caller's copy |
| Round 4 addendum — “New top-tier” | PS2SERVERS-063 | compressed_iso serving path trusts the file's declared block/hunk size — a 32-byte crafted CSO makes the server materialise a 256 MiB block; the strict path and Go both cap the same field at 16 MiB |
| Round 4 addendum — “New top-tier” | SMS-053 | The 1024-pixel gate is one-sided: negative AVI/ASF dimensions reach MPEG-4 geometry initialisation |
| Round 5 addendum — “Round-5 headlines” | X-49 | The ds34 defect pair is family-wide: 4 of 5 BT copies send 29 bytes of uninitialised stack, 8 of 10 copies index the battery table unbounded — and the two fixes exist in-family, in different lineages, neither propagated |
| Round 5 addendum — “Round-5 headlines” | X-50 | mcman validation: the family's best card parser and its worst are in the same repo — Launchstation's EE viewer holds all three checks its IOP vmcman lacks, and RiptOPL holds the family's best gate |
| Round 5 addendum — “Round-5 headlines” | RIPTOPL-145 | GetSMBServerReply receives whatever length the server's session header claims, into a 4,224-byte static buffer |
| Round 5 addendum — “Round-5 headlines” | RIPTOPL-146 | smb_ReadAndX trusts the response's DataOffset and DataLength — both overflow, one into the caller's buffer |
| Round 5 addendum — “Round-5 headlines” | LAUNCHSTATION-118 | VMCMAN unit→slot mask `unit & (MCMAN_MAXSLOT - 1)` is `unit & 9`: units 2–7 silently alias onto slots 0/1 and slots 2–7 are unreachable |
| Round 5 addendum — “Round-5 headlines” | LAUNCHSTATION-119 | `GET_XPARAM_DB_SIZE()` always evaluates to 1 — the 292-entry database is searched over exactly one entry |
| Round 5 addendum — “Round-5 headlines” | SMS-057 | Palette rotate wraps at 17 but not at 0: pressing Left at colour 1 stores 0, and the next render reads `g_Palette[-1]` |
| Round 5 addendum — “Round-5 headlines” | SMS-060 | `SMS_LZMA2Decompress`'s size guard frees the buffer, then decompresses into it anyway |
| Round 5 addendum — “Round-5 headlines” | PS2SERVERS-069 | UCI boolean parsing is split in one Load function — sixteen keys misread the UCI vocabulary, including all three `read_only` keys (fail-open) |

**Range flag, for completeness:** the RiptOPL Round 5 verdict additionally names “the Cat 6 cluster at RIPTOPL-145…202 as the fix-first list” — a range flag rather than itemised headlines; RIPTOPL-145 and -146 from that cluster appear above via the Round 5 addendum, and the rest of the cluster is in the full table (§2.1) with its own fields.

**Flagged by the addenda but excluded by the Category-6 filter** (listed so the filter is auditable): PS2SERVERS-042 (Cat 8) and POPSLOADER-028 (Cat 8) and SMS-037 (Cat 4) from the Round 2 addendum’s top-tier list; RIPTOPL-052 (Cat 1) from Round 3’s; X-41 (Cat 2), X-45 (Cat 7/8) and X-46 (Cat 2) from Round 4’s; LAUNCHSTATION-085 (Cat 4) from Round 5’s headlines.

#### Rounds 7–9 extension — every Category 6 finding filed in Rounds 7–9

The table above stops at Round 5 because the SUMMARY addenda's headline lists stop there. This extension applies §3(b)'s own Category-6 filter (dual categories count by their first number) to **every** finding in the Round 7, Round 8 and Round 9 report files — including the POPSLoader Round 7 file's completed tarball section (POPSLOADER-071…107) — whether or not an addendum flagged it, grouped by repo, in ID order. Titles are transcribed from the findings' own headers. **168 rows.** Excluded by the first-number rule, named so the filter is auditable: RIPTOPL-453 (Cat 5/6) and RIPTOPL-474 (Cat 2/6). No cross-repo finding in the Round 7/9 cross files is Category 6 (X-52, X-53, X-54…X-57 are Cat 7/1/8), so there is no Cross group.

**RiptOPL — 90**

| Round | ID | Title |
|---|---|---|
| Round 7 | RIPTOPL-281 | GSHandler REGIMM decode masks 0x3F into a 32-entry table — odd `rs` jumps out of bounds |
| Round 7 | RIPTOPL-282 | `mips_memcpy` return value overwritten by `mips_memset`'s first instruction in its delay slot — all 4 copies |
| Round 7 | RIPTOPL-283 | `Hook_ExecPS2` clobbers callee-saved $s0–$s3 on paths that tail-call the return-capable original |
| Round 7 | RIPTOPL-284 | `dve_set_reg` always returns 0 — `dve_prepare_bus` retry loop can never repeat |
| Round 8 | RIPTOPL-296 | The APA raw-namespace scan never sees a C++ source, so the policy it pins is unenforced where the code lives |
| Round 8 | RIPTOPL-298 | test_bdm_partitions asserts GPT partitions far beyond the device mount successfully, encoding RIPTOPL-160's missing extent validation as correct |
| Round 8 | RIPTOPL-299 | test_ratls_host.py only ever sends lowercase HTTP tokens, so the RIPTOPL-189 case-sensitive token defect passes the suite |
| Round 8 | RIPTOPL-300 | Neither ps2cnf host test exercises the ≥64-char BOOT2 value that RIPTOPL-158 flags, so the unterminated-string path has no regression test |
| Round 8 | RIPTOPL-301 | Release-publication test ends with a self-referential assertion: the "remote unchanged" check cannot fail on values |
| Round 8 | RIPTOPL-302 | test_release_editions.py:28 can never fail: it membership-tests a dict of target names |
| Round 8 | RIPTOPL-303 | test_mbedtls_vendor swallows ValueError for whole edition/configuration combinations, uncounted |
| Round 8 | RIPTOPL-308 | Save-icons harness exit code is discarded: a post-print crash or non-zero exit passes |
| Round 8 | RIPTOPL-310 | Two suites have Python sections gated only by bare `assert`: they vanish, with their "ok" prints intact, under `python3 -O` / `PYTHONOPTIMIZE` |
| Round 8 | RIPTOPL-311 | `check_frames` in test_dialog_gui_lock.py scans each dialog file as one linear stream, so an unbalanced lock in one function can mask a missing lock in a later one |
| Round 8 | RIPTOPL-332 | Assertions inside possibly-empty iteration, with no count guard, in two tests |
| Round 8 | RIPTOPL-333 | test_about_credits_layout.py prints PASS for trimmed UI_BREAK rows and a kept row count, but never counts either |
| Round 8 | RIPTOPL-334 | test_sfx_oneshot_cut.py's coalesce assertion can be satisfied by the comment inside the captured branch alone |
| Round 8 | RIPTOPL-335 | test_pad_pattern_bounds.py's only ASan-isolated overread case is gated on an argument no CI invocation ever passes |
| Round 8 | RIPTOPL-336 | test_audit_translations.py exercises only one of the tool's two --strict error classes; the unknown-overlay-label error is untested by the tool's only test |
| Round 9 | RIPTOPL-344 | `CNFGetKey` can return an unterminated 64-byte buffer — caller scans past its stack buffer on crafted SYSTEM.CNF |
| Round 9 | RIPTOPL-400 | smb_FindFirstNext2 trusts response ParamOffset/DataOffset/FileNameLen with no bounds at all |
| Round 9 | RIPTOPL-401 | Negotiate response domain name is `strcpy`'d unbounded into a 64-byte field |
| Round 9 | RIPTOPL-402 | ZSO decompression uses the explicitly-unsafe LZ4 "fast" decoder on a user-supplied game image, with prefix references enabled and the result unchecked |
| Round 9 | RIPTOPL-403 | `lwip_accept()` dereferences a NULL netconn that `err_tcp()` itself posts |
| Round 9 | RIPTOPL-404 | GPT scan's fallback path trusts the header's entry count unbounded: a crafted disk can make mount read sectors indefinitely |
| Round 9 | RIPTOPL-405 | HDD APA header `num_partitions` is trusted past the 65-entry partition table |
| Round 9 | RIPTOPL-406 | APA journal write side has no bound: more than 126 dirty cache entries overflow the static journal buffer and write journal headers past the journal area |
| Round 9 | RIPTOPL-407 | USB mass-storage connect walks the endpoint descriptor chain with a device-supplied count and stride, unchecked |
| Round 9 | RIPTOPL-408 | Device-supplied USB sector size feeds an unchecked `alloca` and unchecked length multiplications |
| Round 9 | RIPTOPL-409 | ps2ips `do_send()`/`do_sendto()` trust the EE-supplied `malign` field completely |
| Round 9 | RIPTOPL-410 | ps2ips `do_recv()`/`do_recvfrom()` accept a negative EE `length`, inverting the RA buffer-offset arithmetic |
| Round 9 | RIPTOPL-411 | HDPro `sceAtaDmaTransfer` retries a failing transfer forever, holding the ATA semaphore |
| Round 9 | RIPTOPL-412 | ARP entries can never expire: `etharp_tmr()` has no caller because `LWIP_ARP` is defined nowhere |
| Round 9 | RIPTOPL-413 | genvmc's physical-card copy divides by, and indexes with, unchecked card-supplied superblock geometry |
| Round 9 | RIPTOPL-414 | NBNS receive thread copies the answer address from a fixed offset without checking the datagram is that long |
| Round 9 | RIPTOPL-415 | httpclient RPC handlers use EE-supplied strings unterminated (only the streaming op terminates them) |
| Round 9 | RIPTOPL-416 | `fatfs_fs_driver_get_mounted_bd_from_index` bounds check is off by one and admits negative indices |
| Round 9 | RIPTOPL-417 | `InitializeConfigurationROM` leaks the old CROM and every extra unit, and silently drops all added units, on every `iLinkSetNodeCapabilities` call — both copies |
| Round 9 | RIPTOPL-418 | `iLinkFindUnit` accepts a negative `UnitInList` and indexes `NodeData[-1]` — both copies |
| Round 9 | RIPTOPL-419 | DEV9 callback-registration exports index their tables with unchecked (and possibly negative) indices |
| Round 9 | RIPTOPL-420 | Fixed-size UDPFS replies are never length-checked; a short reply is parsed out of stale buffer contents |
| Round 9 | RIPTOPL-421 | `udpfs_core_get_sector_count` truncates capacity to a signed `int`: shares ≥ 1 TiB can never register as a block device |
| Round 9 | RIPTOPL-422 | Both ministack RX dispatchers will call through a NULL handler for a packet addressed to port 0 |
| Round 9 | RIPTOPL-423 | `do_bind()` uses lazily allocated PCBs without the NULL checks its sibling handlers have |
| Round 9 | RIPTOPL-424 | `copy_from_pbuf()` walks off the end of the pbuf chain when a fragment's IP length exceeds the delivered bytes |
| Round 9 | RIPTOPL-425 | ICMP error replies dereference `pbuf_alloc()` results unchecked and copy from the offending packet unchecked |
| Round 9 | RIPTOPL-428 | SCMD path: unbounded hardware-register spins, and `cdvdman_sendSCmd` always reports success |
| Round 9 | RIPTOPL-429 | GPT connect returns success (0) when its scratch allocation fails, so BDM claims the device and FatFs is never tried |
| Round 9 | RIPTOPL-430 | `USBMASS_DEVCTL_STOP_UNIT` and `USBMASS_DEVCTL_STOP_ALL` bodies are swapped in `fs_devctl` |
| Round 9 | RIPTOPL-431 | FileTimeToDate converts ~half of all dates to garbage (SMB1 browse/stat timestamps) |
| Round 9 | RIPTOPL-432 | usmb2_build_request drains a server-declared SPL of any size; no reply-size ceiling |
| Round 9 | RIPTOPL-433 | Replies are matched to requests only when signing is on (usmb2 MessageId) or never (unfs4 xid) |
| Round 9 | RIPTOPL-434 | smb2man_querydir trusts the reply's OutputBufferLength over the bytes actually delivered |
| Round 9 | RIPTOPL-435 | smb_closeAll() closes FIDs but never frees the handles — stale slots leak and FIDs can be re-closed on a later session |
| Round 9 | RIPTOPL-436 | USB READ CAPACITY result stored as sector count without the +1: the last sector of every USB drive is unreachable |
| Round 9 | RIPTOPL-437 | SMB (USBLD multipart) read past the last part returns success with the buffer untouched |
| Round 9 | RIPTOPL-438 | `smap_udpbd` write path hardcodes 512-byte sectors and ignores the INFO-reply sector size the read path honours |
| Round 9 | RIPTOPL-439 | `sceCdStInit` divides by the game's `bankmax` with no validation |
| Round 9 | RIPTOPL-440 | mcemu FastIO hooks dereference the FastIO allocation without ever checking it exists; the read hook also DMA-transfers a full cluster for a short tail |
| Round 9 | RIPTOPL-441 | `mmce_fs_open`/`dopen` failure exits leave `file->privdata` pointing at a still-free handle slot, which the next open then aliases |
| Round 9 | RIPTOPL-442 | `fs_read`/`fs_write` collapse every FatFs error to a 0 return, indistinguishable from EOF / zero-progress |
| Round 9 | RIPTOPL-443 | `smb_CloseAll`'s −1 sentinel can never be stored in the u16 FID table (all three SMB-family files) |
| Round 9 | RIPTOPL-444 | smb_lseek64 accepts negative positions (SEEK_SET/SEEK_CUR check only the upper bound) |
| Round 9 | RIPTOPL-445 | smb_dopen appends "\\*" to fh->name with strcat after a 255-char strncpy — overflow and unterminated-name read |
| Round 9 | RIPTOPL-446 | GPT parser ignores the header's `partition_entry_size` and assumes every entry is 128 bytes |
| Round 9 | RIPTOPL-447 | GPT connect lacks the partition-device filter the MBR connect has, so every partition pseudo-device is re-probed as a GPT disk |
| Round 9 | RIPTOPL-448 | `sceAtaSecurityEraseUnit` passes NULL as the IDENTIFY buffer; the helper writes 512 bytes to address 0 and dereferences it |
| Round 9 | RIPTOPL-449 | DVD TOC builder marks single-layer discs as dual-layer whenever DVDDL emulation is off |
| Round 9 | RIPTOPL-450 | `cdrom_lseek` SEEK_END subtracts the offset instead of adding it |
| Round 9 | RIPTOPL-451 | `tcp_keepalive()` transmits a segment whose TCP flags byte is uninitialised pool memory |
| Round 9 | RIPTOPL-452 | `netconn_recv()`/`netconn_write()` dereference `conn->pcb.tcp` where the tree itself elsewhere guards it |
| Round 9 | RIPTOPL-456 | Game patch modules write fixed offsets into a target module's text with no size or version check |
| Round 9 | RIPTOPL-457 | pademu `_start` reads 8 bytes of `argv[1]` with no length check |
| Round 9 | RIPTOPL-458 | genvmc STATUS devctl copies to the caller's buffer with none of the validation the CREATE case applies in the same switch |
| Round 9 | RIPTOPL-459 | smb_Connect copies the server IP with strncpy(…, 16) and no termination guarantee; two later sprintf("%s") consumers trust it |
| Round 9 | RIPTOPL-460 | NTLMv2 client challenge is the constant 0x01×8 and the timestamp is zero (vendored usmb2) |
| Round 9 | RIPTOPL-461 | `fs_dread` can hand EE an unterminated directory name for a maximum-length (255-char) LFN |
| Round 9 | RIPTOPL-462 | `bdm_get_bd` silently leaves the tail of the caller's array unwritten, and `bdm_connect_bd` silently drops devices when the mount table is full |
| Round 9 | RIPTOPL-463 | `mstack:` exchange silently truncates an over-long reply, indistinguishable from a complete one |
| Round 9 | RIPTOPL-464 | `udpfs_core_close` discards the close reply entirely and always reports success |
| Round 9 | RIPTOPL-465 | CDVDFSV stream read returns an uninitialised error word when `sectors == 0` |
| Round 9 | RIPTOPL-466 | `hookMODLOAD` uses `getModInfo`'s result without checking it — the one unhardened caller left in scope |
| Round 9 | RIPTOPL-467 | `apaOpen` compares the password of a cache entry after freeing the entry |
| Round 9 | RIPTOPL-468 | INFERRED: SMAP capability check in both neutrino copies is mis-parenthesised (`!x & MASK`), correct only by accident of the mask's value |
| Round 9 | RIPTOPL-469 | INFERRED: `udpfs_ministack` registers its RX callback and takes over the tty before the duplicate-load check |
| Round 9 | RIPTOPL-473 | ilink `_start` ignores `GetConsoleIDs` failure and publishes a zero EUI-64 and empty model name |
| Round 9 | RIPTOPL-504 | Korium manifest completeness is enforced by nobody: unlisted zip entries are silently dropped |
| Round 9 | RIPTOPL-505 | Korium extraction directory is never cleaned: a removed asset can keep shipping from a dirty build tree |
| Round 9 | RIPTOPL-513 | HDPro 48-bit LBA path drops the upper LBA bytes for LCYL/HCYL |
| Round 9 | RIPTOPL-516 | TCP initial sequence numbers are trivially predictable and IP IDs are a plain counter (inherited) |

**Launchstation — 6**

| Round | ID | Title |
|---|---|---|
| Round 7 | LAUNCHSTATION-186 | On IOP, every "random" byte behind libsmb2's NTLM server challenge, preauth salt and SMB3 seal nonce comes from a 15-bit LCG seeded with uptime-seconds ⊕ a constant ⊕ a heap pointer |
| Round 7 | LAUNCHSTATION-187 | `test_copy_psu_listing.py` fails deterministically at the pin — the Cut→PSU-backup "Move" to a UDPFS destination dies at the delete-confirmed-entries stage with −EIO |
| Round 7 | LAUNCHSTATION-188 | libsmb2 frees the file-notify list by recursion whose depth the remote server controls |
| Round 7 | LAUNCHSTATION-189 | Four libsmb2 client error paths leak their callback-data allocations |
| Round 7 | LAUNCHSTATION-190 | libsmb2's AES-CCM tag verification uses early-exit `memcmp` |
| Round 8 | LAUNCHSTATION-200 | The shipped example config's `Misc = MISC/` double-slashes on load, breaking its own FileBrowser shortcut |

**POPSLoader — 1**

| Round | ID | Title |
|---|---|---|
| Round 7 | POPSLOADER-066 | The loader.c CI parity check never compares the committed dump (and history proves the dump went stale for ~7 weeks behind it) |

**SMS — 70**

| Round | ID | Title |
|---|---|---|
| Round 7 | SMS-103 | SMSUMS LFN direntry sequence number is an unchecked index multiplier: writes at −13…+818 into a 128-byte name buffer on callers' stacks |
| Round 7 | SMS-104 | DTS `prim_channels` (1–8 from the frame header) written into state arrays sized 5 |
| Round 7 | SMS-105 | MPEG-4 sprite trajectory: up to 63 warp points written into a stack `int[4][2]` |
| Round 7 | SMS-106 | Vorbis residue `booklist` overwrite: cascade popcount sum reaches 512 into a 256-entry array |
| Round 7 | SMS-107 | Vorbis floor1 total post count unbounded: `postlist` heap overwrite in unpack, stack/heap overwrite in look |
| Round 7 | SMS-108 | Vorbis residue `begin`/`end`/`grouping` (24-bit each) never validated against block size: decode writes at file-controlled offsets into the PCM buffer |
| Round 7 | SMS-109 | lwIP `ip_reass` trusts the header's total length over the received chain: `copy_from_pbuf` walks off the chain end and dereferences NULL |
| Round 7 | SMS-110 | SMSUMS READ CAPACITY sector size stored verbatim: 0 divides by zero, >128 KiB overflows the cache buffer on the first read |
| Round 7 | SMS-111 | AAC PCE channel totals: the `> MAX_CHANNELS` check runs after construction and its return is ignored by two of three callers; unchecked totals index `internal_channel[]` / `channel_position[]` |
| Round 7 | SMS-112 | Vorbis `decodemap[temp]` indexed by a phrasebook decode result with no `temp < partvals` check; the fetched pointer is dereferenced |
| Round 7 | SMS-113 | MPEG-4 `SMS_BUG_EDGE` widens motion-compensation clipping from macroblock units to pixel units |
| Round 7 | SMS-114 | DTS downmix table indexed by two unmasked 6-bit header values into an `[11][10]` table |
| Round 7 | SMS-115 | AC3 channel-count function-pointer table indexed up to 5 into a 2-entry table — a valid 5.1 stream is the trigger |
| Round 7 | SMS-116 | DTS channel-count function-pointer table indexed up to 5 into a 2-entry table |
| Round 7 | SMS-117 | AAC `excluded_channels`: continuation-bit loop writes 7 mask entries per round with no cap — `exclude_mask[64]` walked without limit |
| Round 7 | SMS-118 | Vorbis codebook `entries * dim` (maptype 2) and maptype-1 accumulation overflow int size math |
| Round 7 | SMS-119 | Vorbis `res0_look`: `partvals = pow(parts, dim)` overflows int and wraps the decodemap allocation size |
| Round 7 | SMS-120 | Vorbis ordered codebook lengths grow past 32: `_make_words` indexes `marker[33]` by length, `oggpack_look` indexes `mask[33]` by `dec_maxlength` |
| Round 7 | SMS-121 | Vorbis blocksize field permits window-table index −3…9 into `vwin[8]` |
| Round 7 | SMS-122 | AAC ADTS/ADIF `sf_index` (12–15) stored unchecked; `window_grouping_info` indexes 12-entry sample-rate tables by it |
| Round 7 | SMS-123 | AAC two-step Huffman decoders use the file-influenced `offset` to index the code table *before* the size check |
| Round 7 | SMS-124 | AAC `section_data`: zero-length sections write the per-section arrays at `i == 120` *before* the `i` bound check fires (short windows) |
| Round 7 | SMS-125 | WMA superframe `bit_offset` never bounded before re-basing the bit reader: negative size becomes a huge bit count past the packet |
| Round 7 | SMS-126 | DTS bit reader has no end pointer at all: decode loops can consume past the frame buffer |
| Round 7 | SMS-127 | AAC bit reader has no end-of-buffer check: every `SMS_GetBits`/`SMS_GetBit` reads through a 4-byte window at the cursor regardless of `m_szInBits` |
| Round 7 | SMS-128 | XZ size oracle `lzma2_get_uncompressed_size` performs unbounded, unvalidated index parsing: size < 12 underflows the footer pointer, `backward_size` drives the index pointer before the buffer, and the record loop walks without any length |
| Round 7 | SMS-129 | lwIP TCP data-offset never validated: ignored `pbuf_header` return underflows `len`/`tot_len` to ~65 KB |
| Round 7 | SMS-130 | lwIP UDP: a datagram shorter than the UDP header makes the "drop short packets" branch dead and can be delivered with a ~65 KB length |
| Round 7 | SMS-131 | SMAP received-frame length from the buffer descriptor is never clamped to the 1,540-byte pool slot before alloc + FIFO copy |
| Round 7 | SMS-132 | USBD descriptor walk validates only `bLength >= 2`: truncated descriptors are returned as full structs and read at fixed offsets |
| Round 7 | SMS-133 | Vorbis `oggpack_read`/`oggpack_look` read up to 4 bytes past the end of a packet that is not long enough to trigger the overflow exit |
| Round 7 | SMS-134 | Vorbis codebook `dim == 0` never rejected: float divide-by-zero + non-terminating quantvals search in setup |
| Round 7 | SMS-135 | Vorbis audio packet `mode` never checked against `modes`: NULL mode_param dereference |
| Round 7 | SMS-136 | Vorbis floor0 `order == 1` passes unpack, then `vorbis_lsp_to_curve`'s do-while decrements its counter through zero and walks `lsp` out of bounds |
| Round 7 | SMS-137 | DTS `bitalloc_huffman == 7` selects a Huffman table past the end of `bitalloc_12[5]` |
| Round 7 | SMS-138 | DTS cumulative Huffman scale-factor sum used as an unchecked scale-table index |
| Round 7 | SMS-139 | DTS LFE scale factor: 8-bit index into a 128-entry table |
| Round 7 | SMS-140 | DTS joint-intensity source channel up to 6 indexes a 5-entry array, and the read value bounds a write loop |
| Round 7 | SMS-141 | WMA exponent VLC band length `n == 0` produces a ~2³²-iteration write loop |
| Round 7 | SMS-142 | WMA `sample_rate == 0` divides by zero three times during init |
| Round 7 | SMS-143 | MSMPEG4 slice height can be 0 → modulo-by-zero in the decode loop |
| Round 7 | SMS-144 | MPEG-4 interlaced direct-MV field-time divisor can be 0 |
| Round 7 | SMS-145 | MP123 gain table base + scalefactor index can exceed `s_GainPow2[378]` on the LSF (MPEG-2/2.5) path |
| Round 7 | SMS-146 | FLAC wasted-bits count has no lower bound: `m_CurBPS` goes negative into the bit macros |
| Round 7 | SMS-147 | FLAC fixed-predictor warm-up reads `decoded[-1…-4]` for predictor orders 0–3 |
| Round 7 | SMS-148 | DXSB header width drives RLE writes past the scratchpad free region; packet size never validated against the header size |
| Round 7 | SMS-149 | MP123 region-2 start index can read past `m_LongIdx[23]` (low severity, intra-struct) |
| Round 7 | SMS-150 | SMSUMS `_set_dir_chain` treats a −1 chain error as a completed chain and reads `m_ClusterBuf[-1]` |
| Round 7 | SMS-151 | SMSUMS `_get_direntry_start_cluster` ignores the sector-data error return and loops over uninitialised locals |
| Round 7 | SMS-152 | lwIP reassembly bitmap is indexed at 90 (of 0–89) when the reassembled length is exactly 5,760 |
| Round 7 | SMS-153 | AAC `huffman_getescape`: the escape-length counter is incremented by a file-controlled run of 1-bits with no cap, then used as a bit-read width and a shift count |
| Round 7 | SMS-154 | `DSP_FFTGet` loop count is built from an uninitialised register (`addiu $v0, $v0, 32` before `$v0` is ever set) |
| Round 7 | SMS-155 | Asm `s_GSParams` layout diverges from C `GSParams` after the 576P slot: every PAR word from offset 44 sits one slot early (latent today) |
| Round 8 | SMS-158 | SMSTCPIP `do_connect` ignores `tcp_connect`'s return: a synchronous failure hangs `netconn_connect` forever |
| Round 8 | SMS-159 | SMSTCPIP sockets layer: `get_socket` indexes the 15-entry socket table with a completely unchecked fd |
| Round 8 | SMS-160 | AAC two-step Huffman size arrays disagree with the actual second-stage table counts in both directions — 5 of 7 non-trivial entries are wrong, so the bound the decoders check against is not the bound that exists |
| Round 8 | SMS-161 | DTS scale-factor quantizer tables end in zeros: `scale_factor_quant6[63] = 0` and `scale_factor_quant7[125..127] = 0` break a strictly increasing 63/125-entry run — the largest scale factors decode as silence |
| Round 8 | SMS-162 | USBD host-controller init memsets through an unchecked `AllocSysMemory` result, and the failure is then hidden twice |
| Round 8 | SMS-163 | SMSTCPIP `lwip_close` dereferences NULL on any invalid-but-in-range fd (double close crashes) |
| Round 8 | SMS-164 | SMSTCPIP `do_bind` is the only API handler that does not NULL-check its PCB allocation |
| Round 8 | SMS-165 | USBD done-queue isochronous cleanup clears the wrong LUT slot, leaving stale IoRequest pointers |
| Round 8 | SMS-166 | SMSTCPIP `lwip_accept` uses the accepted connection and the caller's address buffers with no NULL checks |
| Round 8 | SMS-167 | SMSTCPIP `netbuf_ref` dereferences a possibly-NULL `pbuf_alloc` result (UDP send under pbuf exhaustion crashes) |
| Round 8 | SMS-168 | SMSMAP PHY reset result is discarded and the LINK flag is never cleared: a dead PHY leaves SMAP reporting link-up |
| Round 8 | SMS-169 | SMSMAP `_start` returns resident-end unconditionally over unchecked kernel-object creation |
| Round 8 | SMS-170 | SMSTCPIP `netconn_addr` lacks the PCB NULL check its sibling `netconn_peer` has |
| Round 8 | SMS-171 | SMSMAP transmit: chained-pbuf gather copies `tot_len` bytes into a 1,520-byte static buffer bounded only by the 4,096-byte FIFO credit |
| Round 9 | SMS-179 | SMSTCPIP `err_to_errno` maps every error to EIO: the signed/unsigned comparison makes the 11-entry errno table unreachable |
| Round 9 | SMS-180 | USBD `initCallbackThread` never checks thread creation and returns success unconditionally; `hcdInit` discards even that — if the callback thread does not exist, no USB transfer completion is ever delivered |
| Round 9 | SMS-182 | SMSTCPIP `tcp_next_iss` is fully predictable: fixed seed 6510 plus the deterministic `tcp_ticks` accumulator |

**PS2-Servers — 1**

| Round | ID | Title |
|---|---|---|
| Round 7 | PS2SERVERS-070 | Every shipped Edge archive tells its user the server is "read-only by default" — the binary defaults to writable |

---

## 4. Revisions ledger — every REV-* item and round-level revision

| Item | Target(s) | Round | What changed |
|---|---|---|---|
| — (framing correction) | Pass-1 SUMMARY / cross-repo premise | R2 | The pass-1 “four config parsers” claim is corrected: there are **ten** (CROSSREPO-ROUND2, Topic 3). Not a numbered finding; recorded here because the addendum lists it among the formal corrections to pass 1. |
| — (revalidation) | RIPTOPL-003, -004, -005, -013, -016, -021, -034 | R2 | Revalidated at the round-2 head: all STILL TRUE (-003 worse — Makefile now 1,260 lines; -004 now 277 branches; -005 now 278 files). No text change to the findings. |
| — (revalidation) | LAUNCHSTATION-017 | R2 | **STILL TRUE, changed form:** #384 deleted the device/staging path and kept the RAM sink as the only update path (16 MiB cap, unconditional). X-17 (same round) further corrects -017’s suggested fix, which pointed at file-based code that is in fact test-only dead code. Status in the table: REVISED. |
| R2-1 | SMS-014 | R2 | Narrowed: the EE unsafe-string population is 238 call lines — 7 real-risk (A-class) / 48 bounded-but-fragile / 183 safe; the M3U and DirTree examples in pass 1 are not overflows. Fix guidance stands, scoped to the 7 A-class lines. |
| R2-2 | SMS-028 | R2 | Narrowed: `SMS_HistorySave` runs only at player teardown, once per playback end; the remaining fix is to skip the save on user-stop when nothing changed. |
| R2-3 | SMS-027 | R2 | Firmed and **replaced by SMS-038** (exact gating lines). |
| R2-4 | SMS-001 | R2 | Firmed by SMS-037 (exact dead-byte figures for the dual IOP delivery). Confirmation; finding unchanged. |
| — (correction) | SMS-017 | R2 | Corrected by cross-repo evidence: two allocation *sites*, mutually exclusive; the simultaneous cost is SMS’s stream buffers, not the copy buffer. |
| REV-006 | POPSLOADER-006 | R3 | **Fix changed (a pass-1 fix reversed):** the BDMAssault tarball is a documented source pin and the only in-repo source for its shipped binaries — extract the shipping generation as tracked source or move the pin intact to the preservation archive, then delete the .tar.gz; do not plain-delete. |
| REV-016 | POPSLOADER-016 | R3 | Narrowed: 11 of the 16 `.research/tools/` scripts are CI standing gates, not one-shots; the true dead residue is 5 scripts / 547 lines. |
| REV-016 addendum (REV-016b) | POPSLOADER-016 | R4 | The CI-wired research set is **12 files, not 11** (`test_cursor_orbs.cjs` was missed); REV-016’s conclusion is unchanged. |
| REV-034 | POPSLOADER-034 | R3 | Verified in the pademu copies in context — exists in all four copies, bug-for-bug, exactly as filed. Confirmation; no change. |
| REV-010 / REV-033 | POPSLOADER-010, POPSLOADER-033 | R3 | The pademu copies are a **semantic fork**, not drifting photocopies: -033’s duplication verdict stands but its merge shape is understated — the realistic minimum is an L-effort refactor of two diverged APIs, not a build-glue change. |
| R3-R1 | LAUNCHSTATION-052 | R3 | Undercount corrected: the FILEOP_TRACE guard block has **four** copies, not three (a fourth at `src/filer_mount.c:6-13`); fix unchanged, deletion count +1 copy. |
| R3-R2 | LAUNCHSTATION-047 | R3 | Census corrected upward: a **sixth** endian-helper file (`src/mc_card_export.c`, helpers under different names) joins the shared-header fix; estimate +~10 lines. |
| R3-R3 | LAUNCHSTATION-051 | R3 | Narrowed in one direction (once the `strcat` survives, the output *is* terminated by construction — the hazard is confined to the input-side idiom at :311-312) and strengthened in another (the trailing-slash strip at :320-322 is dead code that can never execute; the fix should rewrite the tail handling). |
| — (sharpening) | PS2SERVERS-001, -002, -021, -013 | R3 | -001/-002 **strengthened, not changed** (per-opcode drift evidence found inside validation itself; -060’s framing defect and -056/-057’s BWRITE defects are its two halves). -021 addendum: the 256 cap exists in all editions; the editions’ disagreement *at* the cap is split out as PS2SERVERS-062. -013 re-confirmed in passing, unchanged. |
| R4-R1 | LAUNCHSTATION-064 | R4 | **Downgraded to latent hardening:** a complete calloc census of all 53 compiled libsmb2 sources (fetched at pin a52c1571) finds no wrappable call site; the local missing-check defect stands but is not a reachable Cat 6 defect at this pin. |
| R4-R2 | LAUNCHSTATION-065 | R4 | **REFUTED and WITHDRAWN** as a security finding: libsmb2’s receive path caps PDUs pre-allocation and the write decoder rejects over-PDU lengths, so `(int)req->length` ≤ 131,072 always. Residual is a spec-conformance wart only (a ~128 KiB WRITE against an advertised 64 KiB max). |
| R4-R3 | LAUNCHSTATION-072 | R4 | **Split:** (a) `quic.c` + `smbdirect.c` confirmed literally empty translation units — deletable today; (b) **`aes_reference.c` REFUTED as a duplicate — it is the server’s only AES and must NOT be deleted** (the 36-line `aes.c` dispatches to it on non-Apple builds); (c)/(d) `sync.c`, `smb2-share-enum.c`, `smb2-data-security-descriptor.c`, `smb2-data-reparse-point.c` have intra-library references in client-only code — deletion rests on --gc-sections + a link test that cannot run in this VM. |
| — (revalidation) | RIPTOPL-044 | R4 | Its `udpfs_ioman.c:347` call site read and **cleared on the ioman side** (bounded `strncpy` + explicit NUL); the core-side defect stands as filed. |
| — (extension / narrowing) | RIPTOPL-064, RIPTOPL-026 | R5 | -064 **extended by location:** the half-discarded `long_multiply` helper also exists in the PC tool `tools/pc/genvmc` (same substance, second location). -026 **narrowed in one clause:** `publish_llvm` now imports `publish_editions` plumbing; what remains triplicated is the release-notes construction and the SHA256SUMS parsing in the three `verify()` functions. |
| — (settlement) | LAUNCHSTATION-085 | R5 | **SETTLED: proven waste.** No in-tree flow can populate VMCMAN slots 2–9 (EE gates cap everything at vmc0:/vmc1:; the state table is `vmcMounted[2]`; smbd uses physical xmcman), so deleting the `BUILDING_VMCMAN` MAXSLOT override (10→4) reclaims ≈33,984 B of IOP statics. The related `unit & 9` slot-mask lead was filed as the new finding LAUNCHSTATION-118. |
| — (confirmation) | LAUNCHSTATION-068 | R5 | Its “currently unreachable” judgement **holds and is strengthened** by the -085 settlement, and survives the -085 fix (at MAXSLOT=4 the mask bounds slots to [0,4)). Finding unchanged. |
| R6-REV-1 | SMS-057 | R6 | **Sink list completed:** the round-6 sweep adds the `m_BrowserIBCIdx` direct reads (incl. `SMS_Spectrum.c:51,55`, baked into the persistent DMA packet) to the palette-wrap finding’s locations. Substance unchanged. |
| R6-REV-2 | SMS-068 | R6 | **Twelfth site added:** `SMS_History.c:140` joins the eleven `SMS_ListPushBack(...)->m_Param` deref sites. Substance unchanged. |
| R7-REV-006 | POPSLOADER-006 | R7 | **Narrowed:** the tarball pins only ONE of the two binaries beside it — `usbd.irx` ↔ `__bdm_assault` is string-corroborated, but the shipped `usbhdfsd.irx` is an MX4SIO v1.2 driver with **no source anywhere in the repo** (POPSLOADER-069); the extract-or-archive disposition stands for the bdm_assault half only. |
| R7-REV-011 | POPSLOADER-011 | R7 | **Rationale corrected:** the loader.c CI parity check cannot compare the committed dump (all three workflows regenerate + touch before verifying — POPSLOADER-066); the committed dump was in fact stale ~7 weeks in mid-2026 behind this check, though it is not stale at the current pin. |
| — (completion) | POPSLOADER-076; POPSLOADER-077…107 (new) | R7 repair | **Body completed, section re-derived:** -076’s truncated body was re-derived from the tarball source (number, title and status unchanged; its Category/Effort/Risk/Confidence fields are now present in the source and extracted). The 20 tarball findings claimed as 077…096 were never written and are unrecoverable as conceived; the completion pass re-audited the tarball remainder end-to-end and filed what the evidence supports as **077…107 (31 findings)**. Final tarball-section total: 37 findings (071…107). |
| R8 extension | RIPTOPL-291 | R8 | **Formally extended:** the round-8 full line-read of the test corpus finds the same conditional skip-to-pass family in **nine more files (ten further instances, five distinct triggers)**. Recorded as an extension of -291 with no new numbers, so its fix, when applied, covers the whole family; the worst instance is a JPG-decoder suite gated on dependencies no workflow installs. |
| R8 narrowing (recorded at RIPTOPL-301) | RIPTOPL-301 / round-7 corpus negative | R8 | **Narrows round 7’s corpus-level negative claim** (“no self-comparisons found”): that was a mechanism scan for literal `x == x` patterns; -301’s dict-literal self-reference (`assertEqual(remote, {…: remote[…]})`) is a shape the scan could not see. Round 7’s claim stands for the patterns it scanned; it does not cover this shape. |
| — (confirmation, disassembly level) | POPSLOADER-069; POPSLOADER-006 (REV-006) | R9 | **Corroborated by execution:** the cross-repo binary pass ran real MIPS disassembly (user-space binutils-mipsel) — -069 is upgraded from string-verified to **disassembly-verified** (the shipped `usbhdfsd.irx` entry printfs “MX4SIO v1.2” first; sio2man imports, zero USB), and string accounting corroborates the REV-006/R7-REV-006 tarball pin quantitatively. Both findings unchanged. |
| VERIFY-W1 | RIPTOPL-513 | Verification | **WITHDRAWN — REFUTED on adversarial re-verification** (Sable-VERIFY-RiptOPL-CAT6.md §2): the function’s `lba` parameter is 32-bit (`hdpro_atad.c:678`; shared prototype `atad.h:55`), so for a 32-bit LBA the cited LCYL/HCYL composition is correct and copying `atad.c:681-682` in is an identity transformation — the claimed bits-32–47 defect is absent. A withdrawal note is appended under the finding’s heading in Sable-RiptOPL-ROUND9-MODULES.md. |
| VERIFY-W2 | RIPTOPL-443 | Verification | **WITHDRAWN — REFUTED** (Sable-VERIFY-RiptOPL-CAT6.md §2): the sentinel arithmetic is real, but the claimed double-close trigger is defeated by the sole caller — `device-smb.c:165` calls `smb_CloseAll()` only `if (smb_mount_state == 1)` and `:168` sets it to −1, and `DeviceDeinit` delegates to that same guarded `DeviceUnmount`. The u16/sentinel non-idempotence survives as latent-only. A withdrawal note is appended under the finding’s heading in Sable-RiptOPL-ROUND9-MODULES.md. |
| VERIFY-W3 | SMS-015 | Verification | **WITHDRAWN — REFUTED** (Sable-VERIFY-SMS-CAT6.md): the finding’s own proposed fix already exists at the pin — `_tbl_fits` (`SMS_ContainerMOV.c:143-146`) runs before every cited malloc, and atom sizes are bounded by the parent chain rooted at the real file size; worst-case allocation ≈1× file size. **This also resolves census contradiction C-2:** SMS-045’s assertion that these sites’ sizes are bounded stands; the contradiction dissolves with -015’s withdrawal. A withdrawal note is appended under the finding’s heading in Sable-Simple-Media-System.md. |
| VERIFY-D1 | RIPTOPL-344 → RIPTOPL-158 | Verification | **Full duplicate (census D-1) — later filing retired as CROSS-REF.** Both file the CNFGetKey unterminated-≥64-char-BOOT2 over-read at `ps2cnf.cpp:54-67` (heap face in round 5, stack face in round 9); the earliest filing (round 5) is canonical. -344’s consumer-site lines (`ps2cnf.h:34`; `main.cpp:111,123`; `config.cpp:1308`) are kept as added locations on -158. |
| VERIFY-D2 | RIPTOPL-468 → RIPTOPL-093 | Verification | **Full duplicate (census D-2) — later filing retired as CROSS-REF.** Both file the `ETHSUPPORT_SMB_OPL` gate-expression precedence defect at the same two sites (`udpfs_smap/src/smap.c:516`, `smap_udpbd/src/smap.c:522`) — same mechanism, same fix. **Census contradiction C-1 — correction:** -468’s claim that -093 “filed the *REV_1* gate in the smap_udpbd copy” is false — -093 files the REV_3 expression at both copies; the REV_1 sentence is struck wherever it propagates, including -468’s external-contract residue premise. -468’s extra locations fold into -093 as verification detail. |
| VERIFY-D3 | RIPTOPL-454 → RIPTOPL-045 | Verification | **Full duplicate (census D-3) — later filing retired as CROSS-REF.** Both file the unbounded `while (usbWaitValidDisc() == -2);` spin at `streaming.c:234-235` — same condition, same consequence (a hung IOP thread blocks EE reset), same fix; -045 (pass 1) is canonical. -454’s extra consumers (`pad.c:52/54/71`; `streaming.c:269`) fold into -045 as verification detail. |
| VERIFY-D4 | RIPTOPL-411 → RIPTOPL-086 | Verification | **Full duplicate (census D-4) — later filing retired as CROSS-REF.** Same defect in the same copy of the same retry loop (`hdpro_atad.c:1053-1059`): -086 (round 3) files the unconditional `DelayThread` + no-`CheckSvr` exit; -411 files the missing `hdproCheckSvr()` call — the same missing guard at the same lines. -086 is canonical; -411’s extra sink (`hdproAtaInit`) folds in as a location. |
| VERIFY-D5 | RIPTOPL-455 → RIPTOPL-208 | Verification | **Full duplicate (census D-5) — later filing retired as CROSS-REF.** Both file the unretried `mbSendEE` loss in the SIFCMD IRQ path at `modules/iopcore/common/igrmbox.c:46-47`; -208 (round 5) is canonical (filed “dropped without retry or log”). -455’s call-graph detail (`IgrMboxCallback:78-80`, `iop_core.c:1277`) folds into -208. |
| VERIFY-D6 | RIPTOPL-444 → RIPTOPL-085 | Verification | **Full duplicate (census D-6) — later filing retired as CROSS-REF.** -444’s defect is contained in limb 2 of -085 (round 3): the same missing disconnect (`smbCloseFid`) in the same function `sceCdLayerSearchFile_smb` (`smb_fio.c:140-174`), with -085 additionally noting the call runs under `Cif callbackSemaphore`. -444 adds no new location or mechanism. |
| VERIFY-D7 | RIPTOPL-405 → RIPTOPL-149 | Verification | **Full duplicate (census D-7) — later filing retired as CROSS-REF.** Same counter in the same function (`device-hdd.c:122-138` `NumParts`): -149 (round 4) files the u8 `count` truncation (saturates at 255); -405 re-filed it with a verbatim-`int` misreading — the verification pass WEAKENED -405 on exactly that point, confirming -149 had the defect right. -405 is the same mechanism seen through a mistaken type. |
| VERIFY-D8 | RIPTOPL-416 → RIPTOPL-169 | Verification | **Full duplicate (census D-8) — later filing retired as CROSS-REF.** The cited line (`fs_driver.c:140`, the `sectors == 0` guard in `bdm_init_gpt`) is verbatim -169’s (round 5) second location, filed under the same root defect (zero sector size/count unchecked before division/modulo). -416 adds no sink -169/-071 did not cite. |
| VERIFY-D9 | RIPTOPL-501 → RIPTOPL-006 | Verification | **Full duplicate (census D-9) — later filing retired as CROSS-REF.** Both file the dead-TU compilation waste of `ra_config_smb2` (empty translation units compiled into the IOP link under `USE_SMB2=0`); -006 (pass 1) is canonical. **Census contradiction C-4 — disposition:** -006’s benefit estimate (“tens of KB of ELF size”) is superseded by -501’s measurement (no ELF-size effect; the win is build time and archive bulk). -501’s per-file census folds into -006 as its verification record. |
| VERIFY-D10 | RIPTOPL-408 → RIPTOPL-163 | Verification | **Partial duplicate merged (census D-10) — later filing retired as CROSS-REF.** Both file one root defect: READ CAPACITY’s `sectorSize` trusted in block-device init (`bdm.c:199-201`); -163 (round 5) covers `fs_driver.c` + `bdm.c:201`, -408 adds `cache.c:18` and `usbmass_bd.c:142`. Survivor -163 carries both sink sets as locations. (The verification pass also WEAKENED -408: the BDM `sectorSize != 512` refusal at `bdm.c:169-180` narrows its in-tree consequences.) |
| VERIFY-D11 | RIPTOPL-445 → RIPTOPL-040 | Verification | **Partial duplicate merged (census D-11) — later filing retired as CROSS-REF.** -445’s “separate sink” assertion is struck: -040’s (pass 1) own text already files the `strncpy`/`strcat` sink at `smb_fio.c:661-663` (it lists `GetShareList:661` and quotes the strcat overflow there). The two texts describe one defect; -040 is canonical. |
| VERIFY-D12 | RIPTOPL-400 / RIPTOPL-038 | Verification | **Partial duplicate — annotation only, no status change (census D-12).** Only -400’s FileNameLen limb duplicates -038 (same field, same `cdvdman.c` lines, same overflow-to-stack mechanism); -400 stands for its remaining ParamOffset/DataOffset limbs (no duplicates of -038’s other three limbs). For the FileNameLen limb, read -038 as canonical. |
| VERIFY-D13 | X-17 → LAUNCHSTATION-041 | Verification | **Same-round core duplicate (census D-13) — the X- filing is retired as CROSS-REF.** Both file the silent update-failure path (`update_manager.c:1026-1092`: `system()` return checked only for `< 0`, tar exit status ignored, in-place truncation before failure). Unique sub-claims preserved as locations: X-17’s `cloudHttpDownloadFd` (`cloud_http.c:1279-1287`) and -041’s .BAK-gate; LAUNCHSTATION-041 is canonical. |
| VERIFY-D14 | X-34 / PS2SERVERS-057 | Verification | **Partial duplicate — annotation only, no status change (census D-14).** Only X-34’s BWRITE-completion limb restates PS2SERVERS-057’s defect (the completion wait skipped when `!use_udma && !use_dma`, `smap.c:1376-1395`, both copies); X-34 stands for its other four wire divergences. |
| VERIFY-D15 | X-23 → PS2SERVERS-014 | Verification | **Revalidation converted to cross-reference (census D-15).** X-23 is by its own text a revalidation of PS2SERVERS-014’s defect (the fake SMB2’s dummy handlers) against a second edition — evidence for -014, not a second defect. X-23 is retired as CROSS-REF; the underlying defect stands once, as PS2SERVERS-014. |
| VERIFY-D16 | RIPTOPL-530 item 3 / RIPTOPL-270 item 1 | Verification | **Partial duplicate inside round-9 appendix items — annotation only, no status change (census D-16).** -530’s item 3 (`imgdrv.c` dummy_fs) duplicates -270’s item 1 (same dead file, same location); -530 stands for its other two items. |
| VERIFY-C3 | SMS-123 | Verification | **REVISED — census contradiction C-3.** The finding’s in-text withdrawal rationale (“a script count shows the declared sizes are maximum valid indices”) is falsified by SMS-160’s verified counts (declared = actual + 1 for codebooks 1/2/4/6/10; declared = actual − 1 for codebook 11) and is **withdrawn**: the off-by-one question reopens. The check-after-use defect itself is VERIFIED and stands. Per the verification close-out, any fix must pair the reorder with SMS-160’s corrected bounds — a reorder-only fix still admits 1–2 past-end entries on most codebooks, and a `>=`-on-declared-count fix would falsely reject codebook 11’s valid offset 373. The same note is appended under the finding’s heading in Sable-Simple-Media-System-ROUND7.md. |
| VERIFY-N1 | RIPTOPL-016 | Verification | **REVISED — WEAKENED on adversarial re-derivation** (Sable-VERIFY-RiptOPL-CAT6.md): holds only for `smb_share` — the unterminating share-selection `memcpy` (`ethsupport.cpp:1307`) feeding the `strcpy` at `:1444` with a ≥32-byte share name; the config/GUI writers terminate user/password/prefix (`config.cpp:401-406`, `diaitems.cpp:121-123`). |
| VERIFY-N2 | RIPTOPL-308 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-RiptOPL-CAT6.md): holds only for a clean non-zero exit after stdio has flushed; the filed post-print crash scenario is defeated by pipe buffering (executed replica: post-print segfault → empty stdout → the test fails, not passes). |
| VERIFY-N3 | RIPTOPL-413 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-RiptOPL-CAT6.md): the division traps stand; the `cluster_buf` overrun holds only in the tail loop when `pages_per_cluster × pagesize > 16400`; `blocks == 0` does not trap. |
| VERIFY-N4 | RIPTOPL-415 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-RiptOPL-CAT6.md): only the `mtime[1]` OOB indexing survives (`httpclient.c:331,371`); the unterminated-string / `buffer[512]` overflow is defeated by the sole EE producer, which terminates all four fields (`httpclient.cpp:45-46,66-69,78-79`). |
| VERIFY-N5 | RIPTOPL-421 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-RiptOPL-CAT6.md): “never registers” holds only in the [1,2) and [3,4) TiB bands; (2,3) TiB registers undersized, and exactly 2/4 TiB registers a 0-sector device. |
| VERIFY-N6 | RIPTOPL-425 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-RiptOPL-CAT6.md): only `icmp_dest_unreach` stands; `icmp_time_exceeded` is compiled out — it sits inside `#if IP_FORWARD`, which `lwipopts.h:230` sets unconditionally to 0. |
| VERIFY-N7 | RIPTOPL-459 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-RiptOPL-CAT6.md): fires only on a malformed 16-byte non-terminated fill; no valid dotted-quad IPv4 string can trigger it (longest is 15 chars; the sole EE caller formats `%u.%u.%u.%u` at `ethsupport.cpp:96,98`). |
| VERIFY-N8 | RIPTOPL-462 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-RiptOPL-CAT6.md): the unwritten-tail read is unreachable with the sole in-tree caller (`bdmevent/main.c:15-18` passes exactly 20 = `MAX_CONNECTIONS`); `bdm_connect_bd` is not log-silent (entry `M_PRINTF` at `bdm.c:57-58` fires) — only a failure-specific log/event and an error return are missing. |
| VERIFY-N9 | RIPTOPL-473 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-RiptOPL-CAT6.md): the zero-EUI-64 outcome holds only for the `sceCdRI` failure sub-case; on `sceCdRM`-only failure `*guid` was already written (`iLink_internal.c:67`) and is valid — only the model name is empty. |
| VERIFY-N10 | SMS-115 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-SMS-CAT6.md): the shipped Player flow defeats the “valid 5.1 suffices” headline — `_check_ac3` (`SMS_Player.c:98-107`) clamps channels to 2 in non-SPDIF and SPDIF routes to `_ac3_spdif` (`SMS_AC3.c:347-349`); survives for non-SPDIF with the container leaving `m_Channels == 0`, or a non-Player codec caller. |
| VERIFY-N11 | SMS-116 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-SMS-CAT6.md): same Player guard chain as SMS-115 for DTS — `_check_dts` clamps in non-SPDIF and SPDIF routes to `_dts_spdif`; survives for non-SPDIF with `m_Channels == 0`, or a non-Player caller. |
| VERIFY-N12 | SMS-117 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-SMS-CAT6.md): the `exclude_mask[64]` walk stands (passes 63 at the 9th round), but `n` advances by 1 per round (`SMS_AAC.c:7557`), not 7 — `additional_excluded_chns` needs ~64 rounds, not 10. |
| VERIFY-N13 | SMS-133 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-SMS-CAT6.md): the claimed up-to-4-byte over-read cannot occur — the `:2948`/`:4310` total-bits test bounds every fall-through read; only a 0-bit read at `endbyte == storage` touches `ptr[0]` one byte past. |
| VERIFY-N14 | SMS-140 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-SMS-CAT6.md): the −1 arm is defeated by the `joint_intensity[j] > 0` guard (`SMS_DTS.c:11404`); the bounded loop only consumes/discards bits — bit-stream desync steered by an intra-struct OOB read, not a steered write. |
| VERIFY-N15 | SMS-142 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-SMS-CAT6.md): only two integer divisions by `sample_rate` (`:1352`, `:1383`); `:1397` is a float division; on MIPS, integer div-by-zero does not trap — the quotient is UNPREDICTABLE, not a guaranteed crash. |
| VERIFY-N16 | SMS-151 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-SMS-CAT6.md): `_get_direntry_sector_data` writes `*apStartSec` (`ums_fat.c:400`) before the failing chain call — only the loop extent (`lDirSec`/`lDirSector`) is uninitialised garbage, not the start sector. |
| VERIFY-N17 | SMS-153 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-SMS-CAT6.md): `i` is `uint8_t` (`SMS_AAC.c:6560`) and wraps at 256 — the UB window is exit `i ∈ [32,255]`, not an arbitrarily large counter. |
| VERIFY-N18 | SMS-164 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-SMS-CAT6.md): only the TCP branch is reachable in-tree — `err_tcp` NULLs the PCB, then re-bind; the UDP branches carry the identical unchecked code but have no in-tree entry path (latent). |
| VERIFY-N19 | LAUNCHSTATION-079 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-OTHERS-CAT6.md): the 336-byte superblock copy excludes `cluster_size` (offset 340, hard-set to 1024 at `main.c:1345`) and `clusters_per_block` (offset 348) — those two sinks are not card-driven via the copy (`clusters_per_block` survives only via the VMC spec route); the pagesize/pages_per_cluster sinks hold. |
| VERIFY-N20 | PS2SERVERS-013 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-OTHERS-CAT6.md): holds for the Python standalone+Core editions only; “every edition” is defeated for Go Edge, which has writer exclusion (`reserveWriter`, `server.go:134-149`; −EBUSY at `operations.go:427-435`, with an in-repo test). |
| VERIFY-N21 | PS2SERVERS-042 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-OTHERS-CAT6.md): the fake handlers and guest bypass re-executed end-to-end, but `h2_tree_connect` (`:572-581`) and `h2_close` (`:612-614`) never return success — both always raise `struct.error` and kill the thread (now filed as PS2SERVERS-114); `h2_write` reports Count=0, not the discarded length. |
| VERIFY-N22 | PS2SERVERS-071 | Verification | **REVISED — execution qualification C-2** (Sable-VERIFY-EXECUTION.md): the filed defect stands (the RDMA test oracle reads sectors 600–601, never sector 0), but the “guard removed → payload at offset 0” hypothetical is backstopped by a second clamp (`server.go:498-500`); the mutation execution itself was environment-blocked. |
| VERIFY-N23 | X-18 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-OTHERS-CAT6.md): the chain is exact for the `dash_apps.c` Edit-metadata starter (spaced `title = %s` at `:180-181`); a second writer, `filer_actions.c:1924` `make_title_cfg`, writes the correct unspaced form — only the starter path is broken, not title.cfg creation generally. |
| VERIFY-N24 | X-49 | Verification | **REVISED — WEAKENED** (Sable-VERIFY-OTHERS-CAT6.md): the census tallies are exact (10 copies; A 4 affected/1 correct among BT, B 8/2; no BT copy correct on both), but the union sentence is refuted by RiptOPL `modules/pademu/ds34usb.c` (A not-applicable + B correct) — the true union is 9/10 carrying ≥1 defect, 1 carrying none. |
| — (citation corrections) | 45 findings (VERIFIED-DRIFT) | Verification | No status change: RiptOPL 20, SMS 15, Launchstation 3, POPSLoader 3, PS2-Servers 3, cross-repo 1 — the mechanisms hold; the corrected path:line citations are recorded in Sable-VERIFY-RiptOPL-CAT6.md, Sable-VERIFY-SMS-CAT6.md and Sable-VERIFY-OTHERS-CAT6.md, which are the citation-correction record for this index (see §5). The original report files are unchanged. |
| — (category labels) | POPSLOADER-071…107 | Verification | The POPSLoader round-7 tarball section labels its findings “Category: 2 (correctness/safety)” for mechanisms that are Category 6 in the audit scheme — which is why §3(b)’s first-number extension lists only one POPSLoader row (POPSLOADER-066). The mechanisms were verified regardless (Sable-VERIFY-OTHERS-CAT6.md). Labels left as written; see also §5. |
| — (new findings) | RIPTOPL-602; SMS-183, SMS-184; POPSLOADER-108; PS2SERVERS-114, PS2SERVERS-115 | Verification | Six findings first filed by the verification phase itself, collected in Sable-VERIFICATION-NEW-FINDINGS.md: RIPTOPL-602 (`hddFormat` free-then-read — second instance of the RIPTOPL-467 pattern); SMS-183/-184 (renumbered from the SMS verification pass’s SMS-230/-231: ignored `netconn_peer`/`netconn_addr` returns in `lwip_getpeername`/`lwip_getsockname`; unchecked HCD IRQ thread creation in `hcdInit`); POPSLOADER-108 (GPT `sectorCount` one short — `last_lba` is inclusive); PS2SERVERS-114/-115 (the fake SMB2’s TREE_CONNECT/CLOSE pack-arity thread-kills; its 66-byte header). |
| — (execution re-runs) | 13 claims | Verification | Fresh re-execution (Sable-VERIFY-EXECUTION.md): 13 CONFIRMED (5 to the exact filed numbers), 0 BROKEN, 3 BLOCKED — all environment (UDP `sendto` blocked by the sandbox; mbedtls dev headers / Python `cryptography` absent here; RIPTOPL-431 not re-executable in this VM). Two qualifications: C-1 (RIPTOPL-302’s “82–84 targets” figure does not reproduce — actual 73 korium/incebtion, 76 ra/ra_incebtion; the mechanism is confirmed and count-independent) and C-2 (PS2SERVERS-071 — recorded as its REVISED entry, VERIFY-N22 above). |
| VERIFY2-W1 | RIPTOPL-051 | Full verification | **WITHDRAWN — REFUTED** (Sable-VERIFY2-RIPTOPL.md): `size` is `u32`, so `size <= 0` at mcemu.c:845,896 is a live `size == 0` exit — it fires when `size -= csize` consumes the remainder; the guard is functional, not dead. |
| VERIFY2-W2 | RIPTOPL-348 | Full verification | **WITHDRAWN — REFUTED** (Sable-VERIFY2-RIPTOPL.md): a live caller exists — `.github/scripts/test_ra_ps1.py:137` generates `raVcdBootName(...)` assertions for four VCD files into a compiled harness the suite runs with `check=True`; the suite passes at the pin. Only the narrower “no production caller” is true, which is not what was filed. |
| VERIFY2-W3 | LAUNCHSTATION-100 | Full verification | **WITHDRAWN — REFUTED** (Sable-VERIFY2-LAUNCHSTATION.md): `usmb2_readdir` sits inside `#ifdef USMB2_FEATURE_OPENDIR` (usmb2.c:743-820), a macro no build file defines, and has zero callers; the live directory path (smb2man.c) does clamp. |
| VERIFY2-W4 | LAUNCHSTATION-127 | Full verification | **WITHDRAWN — REFUTED** (Sable-VERIFY2-LAUNCHSTATION.md): `q_escape`/`json_escape` fail (−1) rather than truncate and all three call sites check those returns; with the checked input bounds, worst cases are ≈1,109 < query[1280], ≈3,913 < path[4352], ≈974 < body[1024] and ≈1,018 < body[1280] — truncation is arithmetically unreachable. |
| VERIFY2-W5 | LAUNCHSTATION-214 | Full verification | **WITHDRAWN — REFUTED** (Sable-VERIFY2-LAUNCHSTATION.md): `shouldHideHddAtaDevices()` exists (main_startup.c:746-756, `romver_prefix >= 220`) and is consumed (filer.c:24-25,30-40; dash_devices.c:401,405); README.md:181 is substantively correct. |
| VERIFY2-W6 | X-57 | Full verification | **WITHDRAWN — REFUTED** (Sable-VERIFY2-CROSS.md): POPSLoader’s `docs/third_party/okeanos_udpfs/PROVENANCE.json:12,17` records both .udpfs files by name with hashes, and STATE.md / docs/UDPFS_BDMA.md document their origin — the headline is false as filed. The surviving residue (RiptOPL’s own BDMAssault PROVENANCE.md omits the pair) is filed as X-59. |
| VERIFY2-W7 | PS2SERVERS-104 | Full verification | **WITHDRAWN — REFUTED** (Sable-VERIFY2-PS2SERVERS.md): FABRICATED CITATIONS — no `network_test.go`, `helpers_test.go` or `udpfs_probe_test.go` exists at the pin; the string `"UDPFS1.0 ready"` occurs 0 times (three copies claimed); a shared `startServerAt` bootstrap already exists (write_test.go:29, ~40 call sites). |
| VERIFY2-W8 | PS2SERVERS-105 | Full verification | **WITHDRAWN — REFUTED** (Sable-VERIFY2-PS2SERVERS.md): FABRICATED CITATIONS — all four cited files (`test_smb_negotiation.py`, `test_smb1_responses.py`, `test_smb_write_semantics.py`, `import_ip_surfaces.py`) are absent at the pin, and no `_handler`/`_negotiate` helper exists anywhere in tests/. |
| VERIFY2-W9 | PS2SERVERS-109 | Full verification | **WITHDRAWN — REFUTED** (Sable-VERIFY2-PS2SERVERS.md): FABRICATED CITATIONS — no `Supervisor`, `start_owned` or `stop_owned` exists in test_ra_owned_service.py (grep: 0 hits); the file already shares one scaffolding via its `start()`/`ready()` helpers (:29-47). |
| VERIFY2-W10 | PS2SERVERS-110 | Full verification | **WITHDRAWN — REFUTED** (Sable-VERIFY2-PS2SERVERS.md): FABRICATED CITATIONS — no `_comp_for_ext` exists anywhere in the tree; both cited “copies” are test assertions against the single production `_format_for_extension` (udpfs_server.py:80), so the claimed silent-disagreement failure mode cannot occur. |
| VERIFY2-W11 | PS2SERVERS-111 | Full verification | **WITHDRAWN — REFUTED** (Sable-VERIFY2-PS2SERVERS.md): FABRICATED CITATIONS — neither named test exists in test_opl_http_runner.py; the cited spans (:64-79) are two hash-mismatch tests with different assertion sets, not a subset pair. |
| VERIFY2-W12 | SMS-013 | Full verification | **WITHDRAWN — REFUTED** (Sable-VERIFY2-SMS.md): the 2 MB video-ring allocation (SMS_Player.c:1741) already sits inside the video-stream branch (`m_Type == SMS_CodecTypeVideo`, :1716), and the audio ring is in the separate audio branch — the proposed fix is already the code at the pin. |
| VERIFY2-W13 | SMS-089 | Full verification | **WITHDRAWN — REFUTED** (Sable-VERIFY2-SMS.md): the JPEG preflight walk returns at SOF0 (SMS_Artwork.c:64-68) or SOS (:60) and never reaches entropy data, where RST/TEM markers only exist; DRI (0xDD) is length-bearing and walked correctly. |
| VERIFY2-W14 | SMS-123 | Full verification | **WITHDRAWN — REFUTED as a live defect** (Sable-VERIFY2-SMS.md §7), closing a three-step history: (1) at filing, an in-text script count withdrew the off-by-one limb on the rationale “declared sizes are maximum valid indices”; (2) verification phase 1 (census C-3) falsified that rationale with SMS-160’s verified counts (declared = actual + 1 for codebooks 1/2/4/6/10; declared = actual − 1 for codebook 11) and reopened the question — status REVISED; (3) full verification’s two independent script derivations prove the first-stage Huffman segments tile each second-stage table exactly — max reachable offset = last valid index on all 7 codebooks (declared/actual/max-reachable: cb1 114/113/112, cb2 86/85/84, cb4 185/184/183, cb6 126/125/124, cb8 83/83/82, cb10 210/209/208, cb11 373/374/373; excess past end 0 everywhere) — so no reachable out-of-bounds read exists, and the check-after-use ordering survives only as a latent dead guard. The SMS-160 bounds-pairing survives as fix guidance: if the reorder is ever done as defence-in-depth, pair it with SMS-160’s corrected bounds (a reorder on the declared bounds would use wrong bounds; a `>=`-on-declared check would falsely reject cb11’s valid offset 373). |
| VERIFY2-N1 | RIPTOPL-001 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-RIPTOPL.md): the 53,655,730 B total is exact, but the plain and incebtion/ sets are two different themes’ footage, not duplicate copies; the recoverable saving is roughly one format per theme, not ~35–45 MB. |
| VERIFY2-N2 | RIPTOPL-019 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-RIPTOPL.md): the opendir probe at supportbase.cpp:397 fires only for non-ISO candidate entries when folder browsing is enabled for that scan — not an unconditional per-entry probe. |
| VERIFY2-N3 | RIPTOPL-029 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-RIPTOPL.md): the plasma is a 32×32 Perlin texture refreshed 6 rows per frame (~192 pixels/frame, deliberately throttled), not a full-screen per-pixel per-frame CPU effect. |
| VERIFY2-N4 | RIPTOPL-031 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-RIPTOPL.md): sdk_stub holds 23 files of which 19 are the identical empty stub, not 20; the duplicated-name second tree stands. |
| VERIFY2-N5 | RIPTOPL-032 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-RIPTOPL.md): the four .irx have no source and no ps2.yaml rule, but the legacy Makefile:1182-1191 does contain bin2c embedding rules for them — unexplained inputs for the live build, not wholly rule-less files. |
| VERIFY2-N6 | RIPTOPL-040 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-RIPTOPL.md): the smb_dopen strcat overflow stands (1–2 bytes past name[256] for ≥255-char directory paths), but the unterminated-name/chdir cascade is defeated — the size−1 copy counts preserve the zeroed last byte, so strlen stays bounded. |
| VERIFY2-N7 | RIPTOPL-056 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-RIPTOPL.md): the two DES copies diverge in const-correctness, DES_Keys scope/alignment and local placement (~24 stripped diff lines, not 71); the smbinit copy does keep a static key buffer (function-local, des.c:451) — the stated presence-vs-absence divergence is wrong; “one copy patched” survives only for const. |
| VERIFY2-N8 | RIPTOPL-159 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-RIPTOPL.md): the PadManager::start() loop-structure overflow stands, but it is gated on pads actually opening — padCount_ increments only on startOne() success after padPortOpen; overflow needs four opened pads before an extra slot iteration (e.g. 1 pad + a multitap port). |
| VERIFY2-N9 | RIPTOPL-164 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-RIPTOPL.md): the strlen(NULL) crash, the guaranteed 4-byte static overwrite and the 136-byte frame over-read stand; the name-copy overrun is length-dependent (only for module names over 123 bytes) — the filed “≥13 + len” minimum is wrong, since the memcpy cursor advances by words. |
| VERIFY2-N10 | RIPTOPL-492 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-RIPTOPL.md): crc[512] exists only under #ifdef CONFIG_USE_CRC16, which is never enabled (its only define is commented out at mx4sio.h:37) — a latent 1 KiB cost if ever enabled, not resident IOP RAM in the shipped build. |
| VERIFY2-N11 | RIPTOPL-530 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-RIPTOPL.md): the JMP-macro and dummy_fs items stand, but the atad claim halves — only ATA_C_STANDBY_IMMEDIATE is duplicated (atad.c:92); ATA_C_FLUSH_CACHE occurs once, the next entry being the distinct FLUSH_CACHE_EXT. |
| VERIFY2-N12 | LAUNCHSTATION-011 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): both themes are embedded, but the embedded total is 215,856 B, not 359,840 B (that figure includes the unembedded boot.adp of LAUNCHSTATION-013); deleting one theme saves at most 141,936 B, not ~180 KB. |
| VERIFY2-N13 | LAUNCHSTATION-015 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): the 863-hit unsafe-string count and cited chains stand, but the concrete config-save heap overflow is not reachable as stated — every %s argument is a fixed-size SETTING array and the +8,192 B reserve covers the format overhead; survives as unbounded-API hygiene / defence-in-depth. |
| VERIFY2-N14 | LAUNCHSTATION-024 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): two persistence systems coexist and the 4,096-line settings UI edits both, but they deliberately write disjoint files (dash_store.c:5-9 never modifies LAUNCHSTATION.CNF) — the claimed overlapping writes are not shown; a consolidation opportunity, not a demonstrated divergence bug. |
| VERIFY2-N15 | LAUNCHSTATION-030 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): the memalign(128, 512×1024) at dash_font.c:80 is the SJIS/ELISA glyph atlas texture, exactly sized to its declared 512×1024 PSMT8 texture and lazily allocated — not dashboard-face scratch; the claimed ~384 KB saving does not follow. |
| VERIFY2-N16 | LAUNCHSTATION-032 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): of the four named scripts only stale_code_audit.sh is a genuine unreferenced one-off; audit_r3z_settings.py, check_ds34_build.py and copy_test_pack.py are live CI/test infrastructure — the deletable set is 1 file, not 3–6. |
| VERIFY2-N17 | LAUNCHSTATION-042 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): the two URL parsers share only a ~20-line host/IP prefix plus parallel skeletons (52 vs 40 lines; tails diverge) — not near-identical ~70-line functions; the ~100+ removable-lines estimate overstates a merge. |
| VERIFY2-N18 | LAUNCHSTATION-043 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): only the usmb2/unfs4 receive loops are true near-duplicates; smbman’s GetSMBServerReply matches no id at all, the two MD4 files are independent implementations, and the UTF-16 pairs convert different encodings (ASCII↔ vs UTF-8↔) — the three-way single-sourcing programme does not follow as stated. |
| VERIFY2-N19 | LAUNCHSTATION-048 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): the write-path segment test uses the wrong constant name, but PKO_MAX_WRITE_SEGMENT and PKO_MAX_READ_SEGMENT are numerically equal (both structs 14 B → both segments 1446), so no oversize segment can be emitted today — a latent identifier typo only; the dirent half is refuted outright (net_fio.c:649 forces termination). |
| VERIFY2-N20 | LAUNCHSTATION-072 | Full verification | **REVISED — WEAKENED further** (already REVISED in R4; Sable-VERIFY2-LAUNCHSTATION.md): of the seven proposed deletions only quic.c + smbdirect.c are proven empty/deletable (2 of 7); aes_reference.c is REFUTED as a duplicate — it is the server’s only AES and must stay; sync.c, smb2-share-enum.c, smb2-data-security-descriptor.c and smb2-data-reparse-point.c are UNVERIFIABLE-HERE — deletion rests on a --gc-sections link test that cannot run in this VM. |
| VERIFY2-N21 | LAUNCHSTATION-105 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): the ynDialog half stands in full (strcpy into msg[512] at gui.c:20, exceeded by the lang.c and installer caller families); the nonDialog half narrows — no caller that can exceed its 2,400-byte buffer (gui.c:111) was found; a latent same-shape sink, not a dialog several callers already exceed. |
| VERIFY2-N22 | LAUNCHSTATION-122 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): the buffer/cap mismatch is real (name[65] vs keyboard cap 31), but modalKeyboard never truncates on confirm — the only max_len truncation is on cancel (dash_widgets.c:587), and the caller discards the buffer then; the cap blocks insertions at ≥31 chars — an editing constraint, not silent truncation. |
| VERIFY2-N23 | LAUNCHSTATION-147 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): des_cbc_crypt has no multiple-of-8 check, but it is already static and its only callers are inside the validating tdes_cbc_crypt (size always 8; tdes validates (size & 7) at :436-439) — exposure only via a future edit inside kelf_signer.c itself; a latent in-file foot-gun, materially narrower than filed. |
| VERIFY2-N24 | LAUNCHSTATION-156 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): apaPassCmp compiling to return 0 in the OSD build stands (no APA_ENABLE_PASSWORDS), but the input-side DES runs are conditional — apaEncryptPassword runs only when the argument actually carries a non-empty password field; a plain partition-name parse performs no DES run at all. |
| VERIFY2-N25 | LAUNCHSTATION-160 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): the silent drop stands (hub.c:427-429 logs only via dbg_printf, a no-op without DEBUG), but the 512 B cap is not a MINI_DRIVER effect — maxStaticDescSize is 0x200 in both configurations (usbd.c:40/:54); survives only as “512 B cap + silent drop in release builds”. |
| VERIFY2-N26 | LAUNCHSTATION-185 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): only the argc == 3 fall-through survives; the claimed trailing-pair drop is refuted — pairs are consumed from index 2 and the continuation test is exactly correct, so no complete pair is ever dropped. WARNING: the originally proposed fix’s loop-condition half (i1 + 1 < argc) should NOT be applied — it would read one argv slot past the last complete pair. The sole caller applyXPARAM (init.c:1355) never passes pairs at all. |
| VERIFY2-N27 | LAUNCHSTATION-213 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): only the SMB2.CNF half is a contradiction (CHANGELOG.md:52’s claim is false — shares live in LAUNCHSTATION.CNF, dash_settings.c:563-564); the smb1:/ half is not a contradiction — both phrasings are true at different layers and the code itself uses the smb1:/ phrasing (dash_browser.c:301 reconciles the two). |
| VERIFY2-N28 | LAUNCHSTATION-218 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-LAUNCHSTATION.md): four sites deny a root LICENSE exists, not five — the fifth (docs-site/content/ecosystem.html:4, “no single root licence”) remains true, because the root LICENSE’s scope is limited to original Launchstation code, and is struck; the four-site finding stands. |
| VERIFY2-N29 | POPSLOADER-002 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-POPSLOADER.md): the byte identities are exact, but usbd.irx.mx4sio is already aliased to the usbexfat blob (embed_assets.cpp:149-153,210), not embedded — the remaining saving is 83,008 B (ilink usbd + udpfs usbhdfsd), not 131,508 B. |
| VERIFY2-N30 | POPSLOADER-007 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-POPSLOADER.md): only 25 of the 67 IMG PNGs are embedded (243,578 B); the other 42 (87,097 B) are loose-only with no second copy — the duplication covers the embedded 25, not the ~330,675 B folder upper bound. |
| VERIFY2-N31 | POPSLOADER-024 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-POPSLOADER.md): a full md5 census of .research/assets/ finds exactly 6 exact-duplicate image pairs (6 redundant copies = 57,552 B), not “at least 9”; the root loose assets stand as cited. |
| VERIFY2-N32 | POPSLOADER-036 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-POPSLOADER.md): the text-assert population stands (11 of 62 checks are pure source-text asserts — roughly a fifth), but the re-read count overstates: 25 read_text sites in total including the initial loads, of which 15 re-read the two already-loaded Lua sources, not ≥25 re-reads. |
| VERIFY2-N33 | POPSLOADER-041 | Full verification | **REVISED — WEAKENED, mechanism REPLACED** (Sable-VERIFY2-POPSLOADER.md): the endpoint walks are count-bounded by while (epCount--), so a zero bLength stalls on one descriptor but terminates — the filed infinite-loop mechanism is refuted. The real hang: epCount = interface->bNumEndpoints − 1 (ds34bt.c:117, ds34usb.c:132 DS3 branch) underflows to −1 when bNumEndpoints == 0, making the do-while effectively non-terminating. The missing NULL checks and the DS4 epCount = 20 hard-code stand; the fix should add an epCount < 0 / bNumEndpoints == 0 guard. |
| VERIFY2-N34 | POPSLOADER-044 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-POPSLOADER.md): the gutted debug block, discarded locals and the microsecond unit error stand (ui.lua:6670-6699; flag default false at :1270), but the “counters only ever reset, never read” clause is imprecise — DebugPadLast is read by the block’s own comparison (:6676) and NavEventCount is incremented by live code (emit_nav, :6596); its value is simply never consumed anywhere. |
| VERIFY2-N35 | SMS-034 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-SMS.md): the vendored font packs with space-laden vendor paths are proven, but “unused members ride along” was never proven (INFERRED in the original) — the packs are alternative per-language sets sharing bare names, and two code-referenced names (greek.mtf, latin2.mtf) appear in no pack; whether any given .mtf is ever used is not determinable from the repo. |
| VERIFY2-N36 | SMS-041 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-SMS.md): the :1504 half stands (unbounded strcpy of m_pPath into lPath[512] at SMS_Player.c:1502-1504, paths legitimately built to 1024 B); the :1060 half is refuted — the container m_pName is a ≤8-char format constant (“MPEG(PS)” is the longest), never a file name, so the lBuff[128] overflow cannot occur. |
| VERIFY2-N37 | SMS-045 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-SMS.md): boundedness verified everywhere claimed, including all six MOV sites (_tbl_fits + explicit NULL checks — SMS-015’s withdrawal stands); the unchecked-result half survives only at the M3U pair (SMS_ContainerM3U.c:308-312,366-371), SMS_FileContext.c:1233-1238 and :1976-1978, and SMS_Container.c:351-352 — the MOV six and FileContext :2069 are checked. |
| VERIFY2-N38 | SMS-049 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-SMS.md): the unchecked SMSCDVD appends are real, but matched components are ≤129 B (TocEntryCopy truncates to the 129-byte field), not 255, and cumulative growth in one FindPath descent is bounded by the pathname already copied into s_DirName[1024] — overflowing m_Pathname requires a >1023-byte apPath that first overflows s_DirName itself at :657/:685. |
| VERIFY2-N39 | SMS-072 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-SMS.md): the CDDA_Fill last-sector modulo defect stands, but single-sector files are saved by the sibling start-sector branch (SMS_FileContext.c:474-477, no modulo); the surviving trigger needs (m_Size + m_Offset) % 2352 == 0 AND at least two sectors, via the non-streaming CDDA_Fill path. |
| VERIFY2-N40 | SMS-090 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-SMS.md): the m_Idx == m_Cnt one-past write in subtitle Reset is real and reachable (SMS_SubtitleContext.c:917-922), but the “Prepare never run ⇒ NULL m_pPackets” state is not shown reachable as stated; the Reset callers are in SMS_PlayerControl.c (:774,816,1348), not SMS_Player.c. |
| VERIFY2-N41 | SMS-091 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-SMS.md): the GUIMenu_ShowItem hide-walks are genuinely unbounded in code (SMS_GUIMenu.c:362-375), but for the sole caller (aPos = 4, SMS_GUIMenuSMS.c:2342) they stop after one step onto a never-hidden neighbour in both directions — no out-of-bounds walk is reachable in the shipped menu; latent hardening only. |
| VERIFY2-N42 | SMS-181 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-SMS.md): the USBD stubs do return false success (interface.c:216-229, USB_RC_OK = 0), but the public header does disclose them — “// these aren’t implemented:” at iop/USBD/include/usbd.h:248 — defeating the “no hint” framing; the defect is the dishonest return value, not an undisclosed stub. |
| VERIFY2-N43 | PS2SERVERS-011 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-PS2SERVERS.md): the SESSION format is implemented exactly twice, once per language (Python launcher/session_stats.py; Go internal/sessionstats), plus ~4-line record adapters per Python server — not three times plus per-server dicts; UDPFS’s private dict holds shutdown totals, a different output, and NFS does not participate at all. The filed −150-line estimate is not supported. |
| VERIFY2-N44 | PS2SERVERS-037 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-PS2SERVERS.md): _signature_of stats every file in the scanned directories and refresh() rebuilds on change, but the sweep is throttled (RESCAN_INTERVAL = 5.0 s), runs only from the games.csv handler (lookup() deliberately never rescans), and is flat by default (root + CD/DVD) unless recursive mode is opted in; measured 0.8 ms over 300 files. |
| VERIFY2-N45 | PS2SERVERS-038 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-PS2SERVERS.md): the core is executed-proven (a standalone copy of udpbd_server.py dies with ModuleNotFoundError for the launcher package at :419; its device implementations are 752 lines of launcher-package code), but the premise “every other server is self-contained” is false — http_server.py:47 imports launcher at top level (see PS2SERVERS-116) and SMB1/SMB2 import launcher.session_stats lazily in main(). Narrowed: UDPBD is the only server whose functional device implementations live in the launcher package. |
| VERIFY2-N46 | PS2SERVERS-093 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-PS2SERVERS.md): the bare return at test_ra_credentials.py:76-78 is real, but the filed CI consequence is refuted — no Windows job runs this module (the achievements fixed list and the windows-storage lists omit it; its only CI run is Ubuntu discovery, where the test executes fully), and the achievements matrix is 2 Windows + 1 Ubuntu + 2 macOS, not “both Windows”. Survives as a latent one-line hygiene defect: if ever run on Windows, the POSIX-permissions test would report a phantom pass instead of a visible skip. |
| VERIFY2-N47 | PS2SERVERS-106 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-PS2SERVERS.md): the scratch-environment setUp is duplicated in exactly 2 files (test_about_page.py:86-108 ≈ test_settings_feedback.py:24-46), not 5 — the census overcounts by 2.5×; launcher.main_gui() does not exist and the claimed directlink helper is an import block. The 9-fold Tk guard sub-claim holds exactly. |
| VERIFY2-N48 | X-07 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-CROSS.md): the PS2-Servers half (three UDPFS editions) and Launchstation’s precompiled IRX stand, but the RiptOPL headline falls — the per-edition udpfs_core.c/udprdma.c are 122–125 B #include shims into udpfs_shared, not copies (the round-2 correction to RIPTOPL-008); what is triplicated is the header set (6 headers ×3; mprintf.h ×5). Survives as header triplication + three server editions + one precompiled IRX. Was a pass-1 cross-reference (CROSS-REF) until this pass. |
| VERIFY2-N49 | X-21 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-CROSS.md): every named streaming copy path and all four SMS sub-defects confirm, but “in every path” is falsified by SMS’s _copy_file_to_mc (GUIFileCtxMenu.c:143-196), a buffered import path that deletes the destination on write failure — survives for every streaming path; the fix’s scope shrinks by one path that already behaves. |
| VERIFY2-N50 | X-45 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-CROSS.md): PS2-Servers’ auto-tag pruning and POPSLoader’s hard-coded “1.4.4” release workflow verify fully, but the SMS half falls in part — the destructive rolling-tag race is already mitigated in-tree at the pin (in-place update, per-family concurrency groups, converter retry-wait), so the prescribed single-writer fix is largely obsolete; survives as a two-repo finding. |
| VERIFY2-N51 | X-54 | Full verification | **REVISED — WEAKENED** (Sable-VERIFY2-CROSS.md): 19/19 .irx.xz payloads decompress byte-identical to the plain .irx copies (286,561 B exact) and build/CI consume only the .xz forms, but “nothing reads them” falls — tools/compress_irx.py reads every plain .irx as the regeneration path. The dead-duplication defect and the deletion fix stand, narrowed from “unreferenced” to “no build-time consumer; they are regeneration inputs”. |
| — (citation corrections) | 122 findings (VERIFIED-DRIFT) | Full verification | No status change: RiptOPL 30, Launchstation 29, POPSLoader 10, SMS 17, PS2-Servers 17, cross-repo 19 — the mechanisms hold; the corrected path:line citations are recorded in the six Sable-VERIFY2-*.md files, which are the citation-correction record for this phase (see §5). The original report files are unchanged, except for the WITHDRAWN notes appended under the 14 refuted findings’ headings. |
| — (new findings) | RIPTOPL-603, RIPTOPL-604, RIPTOPL-605; SMS-185, SMS-186, SMS-187, SMS-188; PS2SERVERS-116, PS2SERVERS-117, PS2SERVERS-118; X-58, X-59 | Full verification | Twelve findings first filed by the full-verification phase itself, collected in Sable-VERIFY2-NEW-FINDINGS.md: RIPTOPL-603 (smb_open’s full-size strncpy count leaves fh->name unterminated — the count-equals-size sibling of RIPTOPL-040’s dopen site); RIPTOPL-604 (mmce_fs SET_GAMEID devctl case dereferences arg unchecked — a fifth case beside RIPTOPL-057’s four); RIPTOPL-605 (tools/assets.py comment asserts the opposite of the RA anchor table it annotates); SMS-185 (TocEntryCopy writes the terminator at the disc-supplied filename length, past its 129-byte field); SMS-186 (AVI _Load_idx1 publishes an unchecked SMS_Realloc result); SMS-187 (SMS_ListPushBack(...)->m_Param unchecked dereferences at 14 further sites beyond SMS-068’s filed list); SMS-188 (_sb_string_width iterates one element past the string end); PS2SERVERS-116 (HTTP server’s unconditional top-level launcher import, http_server.py:47); PS2SERVERS-117 (the achievements-engine CI step’s fixed module list omits tests.test_ra_credentials); PS2SERVERS-118 (blanket # noqa: F401 at test_smb2_libsmb2_compat.py:26 hides the dead Client import of PS2SERVERS-112); X-58 (RiptOPL’s PC-tool CRC-32 copies retain the signed-byte negative-index read the EE copy fixed); X-59 (RiptOPL’s BDMAssault PROVENANCE.md omits the .udpfs pair it ships — the surviving residue of the withdrawn X-57). |

Total: 147 ledger entries covering the 100 findings whose table status is REVISED, 18 withdrawals (LAUNCHSTATION-065 via R4-R2; RIPTOPL-443, RIPTOPL-513 and SMS-015 via the verification phase’s REFUTED verdicts; 14 more via the full-verification phase — VERIFY2-W1…W14, five of them PS2SERVERS findings refuted on fabricated citations, and SMS-123 returning to WITHDRAWN with its full three-step history at VERIFY2-W14), the POPSLoader tarball completion (POPSLOADER-076 completed in place; 077…107 newly filed — no earlier number or status changed), and the confirmations/sharpenings/corroborations the rounds recorded against findings whose status therefore remains STANDING (SMS-001 via R2-4, POPSLOADER-034 via REV-034, PS2SERVERS-001/-002/-013 via the Round 3 sharpening, LAUNCHSTATION-068 via the Round 5 confirmation, POPSLOADER-069 and the REV-006 pin via round 9’s disassembly pass), and the verification phase’s 48 entries (the VERIFY-W/D/C3/N series plus four summaries: 3 withdrawals, 16 duplicate dispositions, the SMS-123 reopening, 24 narrowings, the citation-correction counts, the tarball category note, the six new findings and the execution re-runs), and the full-verification phase’s 67 entries (the VERIFY2-W/N series plus two summaries: 14 withdrawals, 51 narrowings — one of them, LAUNCHSTATION-072, narrowing an existing revision in place — the 122 citation corrections and the twelve new findings). The SUMMARY addenda’s own counts agree with this ledger’s shape: Round 3 addendum — “plus 9 formal revisions across rounds 2–3”; Round 4 addendum — “Running total: 454 findings, 15 revisions” (the addenda’s running totals count rounds differently from §1.3’s file-based reconciliation — 454 excludes the X-01…X-16 cross-references, as the Round 5 addendum explains — but the revision *items* are the same set).

---

## 5. Verification note

**Method.** A script (`extract_index.py`, kept beside this index) parsed every report file header-by-header: finding IDs and exact titles from the `##`/`###`/`####` headers (both the `ID / Title / Category N` and the `ID — Title` families, plus Launchstation Round 3’s detail headers), and Category/Effort/Risk/Confidence from each finding’s own field lines (bold and unbolded variants, fields carried on the Benefit line, and Launchstation Round 3’s at-a-glance table cross-check). The running extraction table is preserved as `index-scratch.tsv`. Every ID was extracted exactly once (zero duplicate headers across files), and every allocated block came out complete (001–max contiguous for Launchstation, POPSLoader, SMS, PS2-Servers and Cross; RiptOPL complete within its allocated blocks 001…367 / 400…530 / 600…605) — the counts in §1.3 are the extraction’s, and they match the expected figures exactly. Statuses were not parsed mechanically: each REVISED/WITHDRAWN assignment was transcribed by hand from the SUMMARY addenda and the round files’ revision/revalidation/settlement sections listed in §4. Cross-checks performed: RiptOPL-066’s and SMS-057/SMS-060’s mechanisms, LAUNCHSTATION-119’s macro and LAUNCHSTATION-136’s memset line, and PS2SERVERS-069’s helper were already parent-verified in the rounds; this index re-verified no code — it is an index of the reports, not a re-audit.

**Format variants (extractor repairs, 2026-11-14).** Three files write findings in formats the heading parser does not match; the extractor now handles each explicitly. Two further files (4) and (5) need per-ID repo attribution rather than a format repair. (1) `Sable-RiptOPL-ROUND7.md` (15 rows, RIPTOPL-281…295): findings are listed in a `## Findings index` table (ID | Source | Title (short) | Cat) while the bodies use three other shapes — assembly findings as `### Title: …` blocks under a grouped `RIPTOPL-281…285` header (paired to index rows by the distinctive token each block title shares with the table’s short title), script findings as `### Finding S-n — …` headings (mapped via the table’s Source column: S-3→286, S-1→287, S-2→288, S-4→289, S-5→290, S-6→291), and docs findings as `### Docs — …` blocks in table order (292…295). Titles and Categories are the table’s; Effort/Risk/Confidence come from the bodies where the source gives them. (2) `Sable-POPSLoader-ROUND7.md` tarball section (historical): as originally delivered, only T01…T06 had been renumbered into the text (as POPSLOADER-071…076 headings, -076 truncated) and T07…T26 existed nowhere — the extractor’s R7-T mapping handler (strict benefit order, Tnn → POPSLOADER-(070+nn)) extracted nothing further and POPSLOADER-077…096 were absent from the previous index. **Closed by the completion pass:** the delivered file now carries POPSLOADER-071…107 as ordinary `##` headings, extracted by the normal heading parser; the R7-T handler is retained in the extractor but matches nothing in the current file, and -076’s fields (unparseable before, because its body was truncated in the source) now extract in full. (3) `Sable-RiptOPL-ROUND9-THIRDPARTY-B.md` (2 rows, RIPTOPL-600…601): the same index-table + `### Title: …` block shape as (1); the extractor pairs blocks to table rows in file order — exact-title pairing is impossible because the table’s short title for -601 drops the word “PSUManager” that its block title carries, while -600’s two titles are identical. Titles/Categories are the table’s; Effort/Risk/Confidence come from the bodies (both findings complete). (4) `Sable-VERIFICATION-NEW-FINDINGS.md` (6 rows: RIPTOPL-602; SMS-183, SMS-184; POPSLOADER-108; PS2SERVERS-114, PS2SERVERS-115): the verification phase’s own findings file mixes four repos in one file under standard headings; the extractor derives each row’s repo from the ID prefix. SMS-183/SMS-184 are renumbered from the SMS verification pass’s candidate labels SMS-230/SMS-231 (mapping recorded in the file’s header and in §4). (5) `Sable-VERIFY2-NEW-FINDINGS.md` (12 rows: RIPTOPL-603, RIPTOPL-604, RIPTOPL-605; SMS-185…188; PS2SERVERS-116…118; X-58, X-59): the full-verification phase’s own findings file, same per-ID attribution. Its PS2-Servers candidates were filed as prose notes in the source pass and carry no Category/Effort/Risk/Confidence fields, and its SMS candidates carry Category and Confidence but no Effort/Risk (see the missing-fields list below).

**Normalisations (the only ones).** (1) Category: dual categories kept as written (`6/2`); a trailing `(also N)` or second number after a slash is rendered the same way. (2) Confidence: reduced to the source’s grade word(s) plus its READ/INFERRED basis — e.g. `High (READ)`, `Medium (READ; INFERRED in part)`; purely verbal qualifiers (“High on the mechanism…”) collapse to the grade and tags. LAUNCHSTATION-091’s source gives two grades (“High (READ); Medium …”) and is rendered `High/Medium (READ)`. (3) Effort ranges keep the source dash (`XS–S`, `S–M`). (4) One title contains a literal `|` (RIPTOPL-156); it is escaped as `\|` in the tables.

**Fields that could not be parsed cleanly — listed, not guessed:**

- **X-01…X-16 (all four fields `—`):** the pass-1 cross-references are prose entries in Sable-SUMMARY.md with locations and a shared fix, but no Category/Effort/Risk/Confidence fields exist in the source. Nothing was inferred for them; their per-repo component findings carry the fields.
- **X-29 (Effort `—`, Risk `—`):** the source itself prints `**Effort:** —. **Risk:** —.` — an honesty finding with no fix proposed (“Delete nothing; add nothing”). The `—` values in the table are the source’s own.
- **LAUNCHSTATION-055, -064, -067, -091, -092, -095 (Risk `—`):** in these six, the Risk field is written as a prose sentence with no grade token (e.g. -055: “A firmware returning an unterminated ID now gets an error instead of a corrupt copy — strictly better”). No grade was invented; read the finding for the prose. All other fields parsed.
- **RIPTOPL-286…291 (Effort `—`, Risk `—`):** the round-7 script findings carry no Effort/Risk fields in either the report or its section file; Confidence is transcribed from each heading’s own trailing tag (`READ`; -289 `READ; INFERRED in part`).
- **RIPTOPL-292…295 (Effort/Risk/Confidence `—`):** the round-7 docs findings carry a Severity bullet only; no Effort/Risk/Confidence fields exist in the source.
- **RIPTOPL-516 (Effort `—`, Risk `—`):** the source itself prints `**Effort:** — (no fix proposed)` and `**Risk:** —` — an inherited-weakness record (predictable TCP initial sequence numbers and sequential IP IDs) filed for completeness under LESS-NOT-MORE with no fix proposed, the same honesty shape as X-29. The `—` values are the source’s own.
- **POPSLOADER-076 (resolved):** at the previous regeneration its Effort/Risk/Confidence were unparseable because the delivered body was truncated in the source itself (a literal `...[truncated 21461 chars]` marker where the Problem/Fix/Benefit text should have been). The completion pass re-derived the body; all four fields now extract from the finding’s own text.
- **POPSLOADER-077…096 (resolved, superseded):** the 20 rows absent at the previous regeneration (claimed, never written) were re-derived end-to-end by the completion pass and filed as **077…107 (31 findings)**; all are extracted with their fields. No R7-T rows remain unextracted.
- **SMS-185…188 (Effort `—`, Risk `—`):** the full-verification candidates carry Category and Confidence in `Sable-VERIFY2-SMS.md` §10 but no Effort/Risk fields exist in the source; nothing was inferred.
- **PS2SERVERS-116, -117, -118 (all four fields `—`):** the full-verification candidates were filed as prose notes in `Sable-VERIFY2-PS2SERVERS.md` §7 with locations and problem text but no Category/Effort/Risk/Confidence fields; nothing was inferred for them.
- **No other row has a missing field.** Every remaining `—`-free row’s four fields come from the finding’s own text.

- **Citation corrections (VERIFIED-DRIFT, verification phase).** 45 findings hold in mechanism with one or more citations corrected (RiptOPL 20, SMS 15, Launchstation 3, POPSLoader 3, PS2-Servers 3, cross-repo 1). The corrected citations live in `Sable-VERIFY-RiptOPL-CAT6.md`, `Sable-VERIFY-SMS-CAT6.md` and `Sable-VERIFY-OTHERS-CAT6.md`, which are the citation-correction record for this index; the original report files are unchanged, so where a finding carries a VERIFIED-DRIFT verdict, cite the VERIFY file’s lines over the original’s.

- **Citation corrections (VERIFIED-DRIFT, full verification).** A further 122 findings hold in mechanism with one or more citations corrected (RiptOPL 30, Launchstation 29, POPSLoader 10, SMS 17, PS2-Servers 17, cross-repo 19). The corrected citations live in the six `Sable-VERIFY2-*.md` files, which are the citation-correction record for this phase; the report files are otherwise unchanged (the only in-text changes are the WITHDRAWN notes appended under the 14 refuted findings’ headings), so where a finding carries a phase-2 VERIFIED-DRIFT verdict, cite the VERIFY2 file’s lines over the original’s.

- **POPSLoader tarball category labels.** `Sable-POPSLoader-ROUND7.md`’s tarball section (POPSLOADER-071…107) labels its findings “Category: 2 (correctness/safety)” for mechanisms that are Category 6 in the audit scheme; the §2 rows transcribe the labels as written (Cat 2), which is why §3(b)’s first-number extension lists only one POPSLoader row (POPSLOADER-066). The mechanisms were verified regardless (Sable-VERIFY-OTHERS-CAT6.md).

**Coverage of sources.** 47 report files were present and all were used: the five pass-1 files; per-repo ROUND2–ROUND9 files as they exist (no POPSLoader ROUND5/ROUND6/ROUND8/ROUND9, no Launchstation ROUND6/ROUND9, and no PS2-Servers ROUND6/ROUND8/ROUND9 exist — those repos’ rounds ran 1–4+7, 1–5+7+8 and 1–5+7 respectively; SMS alone has a ROUND6, and RiptOPL alone has a ROUND8 plus the four-file ROUND9); `Sable-SUMMARY.md`; the six CROSSREPO round files (rounds 2, 3, 4, 5, 7, 9); and `Sable-VERIFICATION-NEW-FINDINGS.md` and `Sable-VERIFY2-NEW-FINDINGS.md`. The five `Sable-VERIFY-*.md` files are the verification phase’s verdict records — cited throughout §4/§5 but not themselves indexed as findings, except for the six new findings they filed, which live in `Sable-VERIFICATION-NEW-FINDINGS.md`. The six `Sable-VERIFY2-*.md` files are the full-verification phase’s verdict records — likewise cited throughout §4/§5 but not themselves indexed as findings, except for the twelve new findings they filed, which live in `Sable-VERIFY2-NEW-FINDINGS.md`. Round-section working files (`round2-sections/` … `round9-sections/`) were not indexed — they are the rounds’ evidence drafts; every finding in them that survived consolidation appears in the round files under its number, which is what this index extracts. (The POPSLoader round-7 tarball section was once the exception to this — its working file held only T01…T06, the last truncated — but the completion pass re-derived the section into the round file itself, which is what this index now extracts.)

*End of Master Index. Counting authority for the audit from 2026-11-14: this file’s §1.3, generated from the numbered report files.*
