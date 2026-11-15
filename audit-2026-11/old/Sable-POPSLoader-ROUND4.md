# Sable — POPSLoader Audit, ROUND 4

Repo: NathanNeurotic/POPSLoader, pin `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (master) — verified three ways this round: local HEAD, `git ls-remote origin HEAD`, and `refs/heads/master` all identical to the pass-1 pin. The pin has not moved; no delta to record. Read-only throughout; `git status` clean at start and end. Scripts/venvs only under `/tmp` (the round-2/3 lupa venv had been cleaned from `/tmp` and was recreated there, lupa 2.8).

Scope of this round: the residue rounds 1–3 named — the eleven CI-wired `.research/tools/` scripts read line-by-line, a full `tools/` inventory with every not-yet-audited file read, the remaining `.research/` corpus classified file-by-file, the last unread text source in the repo (`iop/bdm_query/bdm_query.c`, `etc/boot.lua`, `etc/update_lua_globals.sh`, the elf_loader child `loader.c`, `src/ftmin.c`, `src/atlas.cpp`, and the five "unwired" research scripts whose headers only had been read), and the fntsys usage trace POPSLOADER-025 explicitly deferred. Findings are numbered from POPSLOADER-053. Nothing here repeats POPSLOADER-001…052; where this round's evidence extends or completes an earlier item, it says so.

## Tests run this round (host-side; no PS2SDK in this VM, so no PS2 build — same limitation as rounds 1–3)

This round read the files several gates cover, so the gates were re-run:

- `tools/test_disc_layout.py` — **PASS**, 30 cases, exit 0.
- `tools/host_harness.py` — **62/62 PASS**, exit 0.
- `tools/test_udpfs_config_runtime.py` — **PASS** (full scenario matrix incl. production-launch and restart-recovery scenarios), exit 0.
- `tools/test_udpfs_integration.py` — **PASS**, exit 0.
- `tools/docs_verify.py` — **OK**, no mismatches.
- `tools/test_translation_handoff.py` — **7/7 unittest OK**.
- `tools/sync_native_wiki.py --self-test` — **PASS**.
- `.research/tools/guard_site_deploy.py self-test` — **PASS**. `.research/tools/audit_legacy_pages.py self-test` — **PASS**.
- `py_compile` over all of `tools/*.py`, `.research/tools/*.py`, `.research/audit_site.py`, `.research/build_site.py` — all OK.
- No hardware was used; no claim below is hardware-verified.

---

## Revision (evidence-forced)

### REV-016 addendum — the CI-wired research-tool set is twelve files, not eleven

Round 3's liveness census counted Python files only. `.research/tools/test_cursor_orbs.cjs` (100 lines, Node) is executed by `.github/workflows/docs-site.yml:70` and was missed. The wired set is therefore: 6 scripts in `research-network-driver-integrity.yml`, 4 in `docs-site.yml`, 1 shared module (`inspect_network_modules_header.py`), **plus this `.cjs`** in `docs-site.yml`. Read in full this round: it is a genuine behavioural test — it executes the site's real cursor-orb preference code in a `vm` context against a mocked DOM across five scenarios (desktop default, touch default-off, toggle persistence, saved-override wins, media-change handling) — with two text-anchored extractions that are POPSLOADER-057 below. REV-016's conclusion is unchanged (the five unwired Python scripts remain the only dead residue, 547 lines); only the wired count was incomplete.

---

## Findings

### POPSLOADER-053 — fntsys.cpp carries ~232 dead lines: a never-compiled RTL render variant and two caller-less public functions

- Category: 1 (dead code)
- Locations: `src/fntsys.cpp:693–848` (the `#else` RTL variant: `isRTL` :694, `isWeak` :699, `fntRenderSubRTL` :704, second `fntRenderString` :733), `src/fntsys.cpp:390–410` (`fntLoadDefault`), `src/fntsys.cpp:851–905` (`fntFitString`); declarations at `src/include/fntsys.h:30` and `src/include/fntsys.h:45`
- Problem: This closes the usage trace POPSLOADER-025 deferred. (a) `fntRenderString` exists twice behind `#ifndef __RTL` (:601) / `#else` (:693). `__RTL` is defined nowhere in the repo — not in the Makefile, any source, or any workflow (grep-verified) — and the file's own header comment (`src/fntsys.cpp:16–19`) records that the RTL path "referenced an undefined MENU_ITEM_HEIGHT (a latent compile break)": the variant could not even be enabled without fixing it first. ~156 lines are carried for a configuration that does not exist and does not compile. (b) `fntLoadDefault` and `fntFitString` are exported in the header and have **zero callers** — not in `src/`, not internally in fntsys.cpp, not in the Lua (grep-verified per function; the live load paths are `fntLoadFile` and `fntLoadbuff`, both called from `src/luagraphics.cpp:327,355,370`). `fntUpdateAspectRatio`, the third zero-external-caller candidate, is called internally at :310,333,355 and is *not* part of this finding.
- Fix: Delete the `#else` branch and its three RTL-only helpers (keep the `#ifndef __RTL` body, dropping the conditional), and delete `fntLoadDefault` and `fntFitString` with their header declarations.
- Benefit: Medium — ~232 of the file's 946 lines (about a quarter) removed, including the only "second implementation" of the central string renderer; the vendored file's live surface becomes exactly what luagraphics calls.
- Effort: S / Risk: Low (nothing deleted is reachable: two functions uncalled, one variant uncompiled and uncompilable as-is) / Confidence: High (READ + caller sweep grep-verified)

### POPSLOADER-054 — The 7z listing parser exists in four copies across the research gates, already drifting

- Category: 2 (duplication)
- Locations: `.research/tools/compare_recovered_archive_candidates.py:47–65` (`seven_entries`), `.research/tools/audit_hosted_patch_members.py:18–42` (`list_7z_members`), `.research/tools/audit_legacy_archive_payloads.py:76–116` (`archive_members`), `.research/tools/audit_legacy_tool_overlap.py:33–57` (`seven_list`); same-pattern secondary sites: the 7z-executable discovery expression at `verify_network_driver_payloads.py:120`, `compare_recovered_archive_candidates.py:39–44`, `audit_hosted_patch_members.py:53`, `audit_legacy_archive_payloads.py:156–158`, `audit_legacy_tool_overlap.py:97`; the git-blob OID computation at `audit_legacy_archive_payloads.py:44–48` (`git_blob`), `audit_legacy_pages.py:14–15` (`oid`), `tools/test_udpfs_integration.py:23`
- Problem: Four gates each re-implement running `7z l -slt`, splitting the output on `----------`, building the same `fields` dict, and applying the same "0-byte, no-CRC entry that is a parent of a real member is a directory marker" filter — the filter's explanatory comment is near-identical in three of them. The copies have already drifted in what else they do inside the loop: the payloads copy adds path-safety rejection and an extension census, the overlap copy raises on oversized members inside the lister while the compare copy checks sizes later, and the hosted copy has no path-safety check at all. A parsing fix (e.g. for a future 7-Zip output change) has four places to land. The sharing mechanism already exists in the same directory: `verify_network_driver_payloads.py:19` imports `manifest` from `inspect_network_modules_header.py`, which is how the fifth tool avoided a fifth copy of the header parser.
- Fix: Move one `-slt` listing function, the executable finder, and the blob-OID helper into `inspect_network_modules_header.py` (the existing shared module) and have the four gates call it, keeping each gate's own post-listing policy (census, safety, size bounds) where it is.
- Justification (adds shared functions): same logic in 4–5 places, and sharing removes code overall — ~120 lines of parser collapse to one ~45-line helper plus call sites.
- Benefit: Medium — one parser to fix when 7-Zip's output format moves; the drift between the four copies stops here.
- Effort: M / Risk: Medium (four live CI gates change at once; two have self-tests, all are exercised by their workflows) / Confidence: High (READ all four in full)

### POPSLOADER-055 — test_udpfs_integration.py's wiring half is ~45 bare source-text assertions

- Category: 7 (build/CI/repo clutter)
- Location: `tools/test_udpfs_integration.py:29–73`
- Problem: This is the POPSLOADER-036 pattern in the repo's second host gate — a file rounds 1–3 had not read. Between the blob pins and the provenance cross-checks sit roughly 45 bare `assert '<exact string>' in <file text>` checks over `ui.lua`, `system.lua`, `src/luasystem.cpp`, `src/embed_assets.cpp` and the Makefile, including whitespace-exact C++ (`'snprintf(iparg,sizeof(iparg),"ip=%s",ip);'`) and a slice-and-exclude check built from two `ui.index("function …")` anchors. Any rename, reformat, or comment edit in those strings fails CI, and because the asserts are bare (no message argument anywhere in the file), the failure is an unadorned `AssertionError` with a line number. The file's other halves are *not* part of this finding: the IRX blob pins (:12–27, SHA-1 + length + ELF-header checks) and the PROVENANCE.json cross-verification (:77–117) check real bytes against real records.
- Fix: Where a wiring assertion guards behaviour, let the executed gates carry it — `tools/host_harness.py` and `tools/test_udpfs_config_runtime.py` already execute the real UDPFS config/launch flows end-to-end (both green this round). Delete the text assertions those executions subsume; keep the fingerprint and provenance halves untouched. If any text check is kept, give it a message.
- Benefit: Medium-Low — one less gate that breaks on cosmetic edits to the most-edited files in the repo.
- Effort: M / Risk: Low / Confidence: High (READ in full; gate run green this round)

### POPSLOADER-056 — audit_published_provenance.py is exact-prose-as-law, end to end

- Category: 7 (build/CI/repo clutter)
- Locations: `.research/tools/audit_published_provenance.py:1–31` (whole file); secondary: `.research/tools/audit_original_wiki_zip.py:29–33` and `:86–89` (exact rendered sentences and the `"AstroSnail"` attribution string as hard gates)
- Problem: The third instance of the pattern POPSLOADER-052 flagged in `audit_site.py` — this file is *nothing but* that pattern: seven phrases that must appear verbatim in the generated `downloads.html` (including byte counts baked into prose, `"188-byte"`, `"226 bytes"`, `"93,934-byte"`), three disproven phrases that must not appear, one exact sentence required in `compatibility.html`, and four filenames that must appear. The intent is sound — the gate exists so the site never re-publishes a disproven claim about the NOPAL patch — but the mechanism makes any legitimate rewording of the warning page fail the publish with "Missing public provenance warning", pointing at the phrase rather than at the fact that a snapshot was frozen into a check. The negative half (disproven phrases must stay absent) does not have this problem: absence checks survive any rewording of the warning itself.
- Fix: Keep the three "disproven claim must not appear" checks as hard failures; demote the positive exact-phrase and filename-presence checks to printed warnings, exactly as POPSLOADER-052 proposes for `audit_site.py`.
- Benefit: Low — the docs publish gate stops breaking when the warning text is legitimately edited, while the protection it was built for (never re-assert the false claim) is kept whole.
- Effort: S / Risk: Low / Confidence: High (READ in full)

### POPSLOADER-057 — Two more host gates extract the code they test by exact comment strings

- Category: 7 (build/CI/repo clutter)
- Locations: `tools/png_decoder_harness.py:122` (`source.index('//2D drawing functions')`, `source.index('GSTEXTURE* loadbmp(')`), `.research/tools/test_cursor_orbs.cjs:17–18` (`js.indexOf('/* Site-wide cursor orb preference.')`, `js.indexOf('/* ---- PS2 OSDSYS Cursor Orbs Canvas ---- */', start)`)
- Problem: The brittleness POPSLOADER-042 flagged in `test_disc_layout.py` exists in two more gates, in files that round had not read. Both harnesses are otherwise genuine execution tests (the PNG harness compiles the real decoder and runs it under ASan/UBSan; the orbs test runs the real preference code in a VM) — but the code under test is located by comment text, exact whitespace included on the C++ side. Rewording or reflowing either comment makes the gate die with a raw `ValueError`/`assert` failure that never mentions comments. For contrast, `tools/test_udpfs_config_runtime.py:8–10` anchors its extractions on function *names* (`local function ParseUdpfsIPv4(value)`), which is the robust end of the same spectrum and is not flagged.
- Fix: Anchor both extractions on the code tokens the slices actually need — the decoder's function definitions in `graphics.cpp`, the `ps2CursorOrbs` assignment in `app.js` — as -042 proposed for its file.
- Benefit: Low — two fewer misleading CI failures waiting on a comment edit.
- Effort: S / Risk: Low / Confidence: High (READ both in full; both gates currently pass)

### POPSLOADER-058 — audit_legacy_tool_overlap.py builds a lookup it never reads

- Category: 1 (dead code)
- Location: `.research/tools/audit_legacy_tool_overlap.py:148` (`matches_by_hash = {d: f for f, (_, d, _) in originals.items()}`)
- Problem: The dict comprehension runs on every audit and is referenced nowhere else in the file (grep-verified: the name occurs exactly once). The actual matching below it works from `originals` directly. Harmless, but it reads like the index the matcher uses, and it isn't.
- Fix: Delete line 148.
- Benefit: Low — one misleading line out of a provenance tool whose readability is its audit value.
- Effort: S / Risk: Low / Confidence: High (READ + grep-verified single occurrence)

### POPSLOADER-059 — Fetch-process residue and a content-free failure marker are tracked but cited by nothing

- Category: 7 (repo clutter) / 1 (dead files)
- Locations: `.research/_state/fetch_fail.tsv` (204 B), `.research/_state/stubborn_done.tsv` (2,484 B), `.research/research/per-agent/agent6-FAILED.md` (36 B)
- Problem: A repo-wide grep finds **zero** references to the two TSVs — in code, workflows, build/audit scripts, and prose. They are the working state of the one-time Wayback fetch process (what failed, what was stubborn), kept after the process ended. Their siblings in the same directory are genuinely load-bearing and are *not* part of this finding: `_state/galleries.json` is the gallery cache `build_site.py:552` reads, and `_state/assets_done.tsv` is a build input at `build_site.py:1076`. `agent6-FAILED.md`'s entire content is `# agent 6 — FAILED (rate limited)` — the per-agent report series (00–05, 07) has a gap at 06 that already says everything this 36-byte stub says.
- Fix: Delete the two TSVs and the marker file.
- Benefit: Low — 2,724 B and the end of "is this an input?" ambiguity for the next reader of `_state/`.
- Effort: S / Risk: Low / Confidence: High (READ + repo-wide grep for both filenames returned no references)

---

## Evidence notes (checked and *not* flagged)

- **The eleven wired research gates are, in the main, correct gates.** Their assertions match their docstrings, and several are models of the form: `guard_site_deploy.py` verifies a hash manifest of generated Pages files and ships a self-test that proves it catches manual drift (ran green this round); `audit_legacy_pages.py` does byte/OID verification against the legacy ledger with its own self-test (green); `verify_network_driver_payloads.py` recomputes every member CRC/size and cross-checks SHA-256 pairs between two independently sourced archives, and prints its own limitation ("Historical 2017 Bitbucket archive identity remains UNVERIFIED"). The hard-coded counts/hashes in the fingerprint tools (`inspect_network_modules_header.py`'s fixed archive layout, `audit_legacy_archive_payloads.py`'s expected 14/17/20, `audit_bitbucket_download_snapshots.py`'s opt-in `--strict-known-inventory` denominators) are the *purpose* of those tools — a pin verifier is supposed to fail when the pinned thing changes — and are not the -040/-052/-056 pattern, which is about prose and inventory observations frozen into *publishing* gates.
- **`tools/` is in good shape.** `lua_minify.py` proves its own token-stream equivalence and fails the build otherwise; `pad_harness.py` and `png_decoder_harness.py` compile and execute the real `pad.cpp`/`graphics.cpp` decoders against scripted inputs; `test_udpfs_config_runtime.py` executes the real production Lua across a failure-scenario matrix and AST-extracts the shared `MOCKS` from `host_harness.py` instead of duplicating them; `translation_handoff.py` + its unittest are a careful, adversarially-tested checker (formula cells rejected, Excel leading-space loss repaired, format-placeholder order enforced); `package_psu.py` builds then re-verifies its own archive byte-for-byte; `build_release_kit.sh` fails closed on every pinned payload. No findings in any of them beyond -055/-057.
- **The five unwired research scripts are honest one-shots** (read in full this round): each states its limits in its docstring (e.g. `audit_network_driver_crc_overlap.py`: "Matching stored CRC metadata strongly suggests identical driver bytes but does not prove collision-free SHA-256 equivalence" — and it is in fact superseded by `verify_network_driver_payloads.py`, which does the full recomputation). REV-016 already scopes their disposition; nothing new to flag inside them.
- **`audit_legacy_tool_overlap.py`'s ZIP/7z asymmetry is benign:** `zip_list` (:70–73) silently drops members over the size cap while `seven_list` raises on them. An over-cap member can never match the capped originals the tool compares against, so nothing can pass unexamined in practice. Noted here so it isn't re-derived; not a finding.
- **Newly read product source is clean:** `iop/bdm_query/bdm_query.c` (bounded RPC list builder, count capped by its fixed array), `etc/boot.lua` (boot-path normalisation, heavily commented with hardware-report provenance), `src/elf_loader/src/loader/src/loader.c` (bounded arg staging, phdr count capped), `src/ftmin.c` (a deliberate, measured size lever), `src/atlas.cpp` (vendored OPL texture atlas). No findings.
- **Duplicate sweep of `.research/`** (md5 over all 312 files): exactly 6 exact-duplicate pairs, all inside `.research/assets/` (e.g. `2667142094-356screenshot1.gif` = `356screenshot1.gif`, 57,552 B duplicated in total) — all already covered by POPSLOADER-024; no new pairs anywhere else in the corpus, including `downloads/` (the pfsshell/RadHostClient pairs are different containers of different builds, not duplicates).

## `.research/` corpus classification (312 files, inventoried this round)

| Part | Files | Bytes | Class | Evidence |
|---|---|---|---|---|
| `build_site.py` + `audit_site.py` | 2 | 182,592 | **Living** — the site generator and its gate | Run by `docs-site.yml`; R2/R3 audits |
| `_srcassets/` | 7 | 282,624 | **Living** — generator-owned CSS/JS/favicon source | `build_site.py:2153`; parity-checked by `test_cursor_orbs.cjs` |
| `wiki/` | 63 | 2,471,484 | **Living** — published historical wiki corpus | `build_site.py` WIKI input; audit gates |
| `downloads/` | 24 | 7,832,715 | **Living** — published downloads, fingerprint-pinned | CI payload gates (TASK 1) verify these bytes |
| `assets/` | 124 | 8,659,452 | **Living** — site image corpus (minus the 6 duplicate pairs already in POPSLOADER-024) | `build_site.py` ASSET input / `img_map` |
| `firstparty/` | 12 | 36,675 | **Living** — authored site pages | `build_site.py:235` FP loader |
| `ui/` | 9 | 847,640 | **Living** — release-build interface captures | Copied to `site/img/ui` at `build_site.py:2161–2163`; manifest read at :1630 |
| `research/entries.json`, `sections.md`, `ambiguities.md`, `thread-findings.md` | 4 | 273,562 | **Living** — generator inputs | `build_site.py:59,63,64,1985`; `entries.json` also `audit_site.py:149` |
| `research/legacy-gh-pages-inventory.tsv`, `research/original-download-catalog.tsv`, `research/original-git-unmatched-images.tsv`, `research/original-bitbucket-downloads-2018.tsv`, `research/original-bitbucket-download-snapshot-2020.tsv`, `research/original-git-technical-changes.tsv` | 6 | 25,864 | **Living data** — read by gates/generator | Ledger read by `audit_legacy_pages.py` + `audit_legacy_archive_payloads.py`; catalog by `build_site.py:744` + integrity workflow; unmatched-images by `build_site.py:882`; snapshot TSVs are the bitbucket gate's inputs |
| `_state/galleries.json`, `_state/assets_done.tsv` | 2 | 28,803 | **Living** — build cache + build input | `build_site.py:552`, `:1076`; README documents the cache contract |
| `research/*.md` reports (incl. `per-agent/` 00–05, 07 and `original-git-*`, `original-bitbucket-*`, `legacy-*` audits) | ~37 | ~660,000 | **Frozen artifacts** — the recovery project's evidence record; cited by each other and by `sources.md`, consumed by no executable | Their disposition is POPSLOADER-001's question, already asked; nothing in this round changes it |
| `research/master-entries.md` | 1 | 83,004 | **Frozen twin** — human-readable consolidation of the `entries.json` corpus (its own header says so); cited only by `original-git-gap-audit.md`, not loaded by the build | Both sides are snapshots of a finished recovery, so there is no live drift channel; classification only |
| `_tmp/dl_manifest.tsv`, `_tmp/found_mirrors.tsv` | 2 | 3,461 | **Frozen, self-labelled** — the repo's own crosswalk (`original-git-download-crosswalk.md:138`) calls `dl_manifest.tsv` "a stale retrieval/scrape ledger, not an authoritative inventory"; `found_mirrors.tsv` is cited as a historical note at `original-bitbucket-download-snapshot-2020.md:78` | Cited-as-evidence, with the staleness warning already written by the repo itself — not POPSLOADER-059, whose files have no citations at all |
| `_state/fetch_fail.tsv`, `_state/stubborn_done.tsv`, `research/per-agent/agent6-FAILED.md` | 3 | 2,724 | **Residue** — see POPSLOADER-059 | Zero references repo-wide |
| `tools/` (17 files) | 17 | 94,144 | **Living** — 12 CI-wired (REV-016 addendum), 5 unwired one-shots (REV-016) | TASK 1 |
| `README.md` | 1 | 4,600 | **Living** — the corpus's own rebuild/deploy contract | Read this round |

## Coverage ledger — what was read this round

| Item | Coverage |
|---|---|
| `.research/tools/` — the 11 CI-wired Python scripts (1,508 lines) + `test_cursor_orbs.cjs` (100) | READ IN FULL, line by line. |
| `.research/tools/` — the 5 unwired scripts (547 lines) | READ IN FULL (rounds 1–3 had read headers/docstrings only). |
| `tools/` — `build_release_kit.sh` (89), `docs_verify.py` (259), `lua_minify.py` (169), `package_psu.py` (102), `pad_harness.py` (131), `png_decoder_harness.py` (187), `sync_native_wiki.py` (158), `test_translation_handoff.py` (91), `test_udpfs_config_runtime.py` (319), `test_udpfs_integration.py` (117), `translation_handoff.py` (250) | READ IN FULL. With `host_harness.py` + `test_disc_layout.py` (round 2), **all 13 `tools/` files are now fully read**. |
| `iop/bdm_query/bdm_query.c` (101), `etc/boot.lua` (181), `etc/update_lua_globals.sh` (22), `src/elf_loader/src/loader/src/loader.c` (442), `src/ftmin.c` (90), `src/atlas.cpp` (183) | READ IN FULL — the last text source in the repo with no prior read status. |
| `src/fntsys.cpp` public-API caller trace | Every exported function's call sites swept repo-wide (closes POPSLOADER-025's deferred item → POPSLOADER-053). |
| `.research/` non-`tools/` corpus (295 files) | Inventoried file-by-file with sizes; classified by consumer evidence (workflow/build/grep citations), table above. Content is data/evidence documents, sampled across rounds 1–3, not line-read — see verdict. |
| `scripts/` directory | **Does not exist** — no directory or path containing "script" anywhere in the tracked tree (the brief's `tools/` and `scripts/` = this repo's `tools/` only). |

---

## VERDICT — is POPSLoader exhausted at source level?

**Yes — with the exact exceptions tabled below, every line of text source in this repo has now been read by this audit, and what remains open is not unread code but the classes of thing a source audit in this VM cannot settle.**

Per-area coverage across rounds 1–4:

| Area | Status |
|---|---|
| Shipped Lua (`system.lua` 11,784; `ui.lua` 7,599; `images.lua` 93; `etc/boot.lua` 181) | READ IN FULL (R2; boot.lua R4). i18n bodies additionally verified programmatically (R3: 2,248 entries, 0 format mismatches, 0 duplicate keys). |
| EE C/C++ (`src/`, incl. `elf_loader` parent + child) | READ (pass 1 all; R2 harness-targeted re-reads of `graphics.cpp`/`pad.cpp`; R4 child `loader.c`, `ftmin.c`, `atlas.cpp`, fntsys trace). Sole exception: the *generated* `src/elf_loader/loader.c` bin2c dump (8,740 lines) — identified as generated from its header and generating rule in pass 1 (POPSLOADER-011); reading generated output line-by-line would audit the generator's formatting, not the program. |
| IOP C (`ps2atad.c`, ds34 standalone ×2, pademu core, `bdm_query.c`) | READ IN FULL (R2, R4). Pademu ds34 copies: full-diff classification (R3), every hunk bucketed. |
| EE client libraries (`libds34bt.c`, `libds34usb.c` + headers) | READ IN FULL (R3). |
| Host tooling (`tools/`, 13 files) | READ IN FULL (R2 + R4). All gates re-run green in R4 (see test list). |
| Research tooling (`.research/tools/`, 17 files; `build_site.py`; `audit_site.py`) | READ IN FULL (R2, R3, R4). |
| Workflows (10) | READ (pass 1); wiring re-verified by grep in R3/R4. |
| Build system (root `Makefile`, module Makefiles, `elf_loader` Makefiles) | READ (pass 1 + targeted re-reads every round). |
| Documentation prose (root `*.md` ×18, `docs/` ×40) | Inventoried; the current-behaviour docs are mechanically cross-checked by `tools/docs_verify.py` (ran green R4) and the wiki sources by `sync_native_wiki.py`'s self-test. A line-by-line *prose* audit was never any round's scope and is the one text class not line-read — stated plainly rather than smoothed over. `docs/archive/` is frozen by its own directory name and charter. |
| `.research/` corpus (312 files) | Fully inventoried and classified (table above). The ~37 frozen research reports are evidence documents: sampled in pass 1, cited/consumed status established for every file in R4, but not line-read end-to-end — they are records *of* the audit subject's history, not code that runs. |
| BDMAssault tarball (151 entries) | Extracted, inventoried, classified (R3); **not line-audited** — upstream/vendored code whose disposition is settled by REV-006 (extract the shipping generation or archive the pin whole). If the maintainer extracts it per REV-006, the extracted tree becomes tracked first-party-held source and a future pass could audit it then. |
| Binaries (`.irx`, `.ELF`, `.ttf`, PNG/JPG/GIF art, `.zip`/`.7z` payloads, `PATCH`-class files) | Sized, hashed, and cross-compared across all four rounds; **not disassembled or content-audited** — not text-auditable, in this or any source audit. |
| Runtime/hardware behaviour | **Nothing in any round is hardware-verified.** No PS2SDK exists in this VM (no build was ever run) and no console was touched. Every runtime claim rests on the host gates listed above — which are unusually strong (real Lua execution, real C++ compilation under ASan/UBSan, 62/62 + 30/30 + full UDPFS scenario matrix, all green at the pin in R4) — but per this repo's own AGENTS.md rule, hardware remains the only truth for launch paths. |

So the honest one-sentence version: **at the pinned commit, POPSLoader's source has been read end-to-end and its gates all pass; the remaining unknowns are a generated file nobody should read, an upstream tarball whose disposition is already decided, documentation prose, binary contents, and hardware behaviour — and none of those five is "unread source" in any sense a fifth round could fix.** If a future round is wanted, its only productive shapes are (a) auditing the BDMAssault tree *after* a REV-006 extraction lands, or (b) re-auditing at a new pin after the code moves.
