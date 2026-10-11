# Original POPStarter wiki Git-history gap audit — investigation ledger

> **Research-only, no imports or replacements.** PR #578 is intentionally draft/unmerged. This is the **first systematic pass**, not a claim that all 2,140 historical revisions have been reconciled. Preservation/repair decisions are deferred to the maintainer.

## Source and comparison baseline

- Original source: the **unmodified AstroSnail-supplied `2.1 MB `wiki.zip`**, a Git clone of the original ShaolinAssassin Bitbucket documentation wiki.
- Source SHA-256: `d0c243d91e417988825ed92b440224ed46cbbf448d0b67528e0957c15c0d029a`.
- Source HEAD: `960d675d278296a3a62143410b38aa8882d21a79` (2024-07-31).
- Comparator: `master` commit `15ffb1c7c46e1643ab2869baf1b26718cf53a604`, `.research/wiki/*.md` (63 recovered pages), `.research/assets/` (124 tracked image files), its asset-recovery logs, research catalog, and download index.
- Git integrity and ZIP CRC checks passed in the initial preservation audit.
- This document does not republish historical git author emails, suspected credentials, proprietary Sony files, or unexamined binaries.

### Historical coverage census

| Measure | Observed |
|---|---:|
| Reachable commits | 2,140 |
| Commits from 2016 / 2017 / 2018 / 2020 / 2023 / 2024 | 1,558 / 548 / 1 / 19 / 6 / 8 |
| Distinct actual repository paths touched (including rename endpoints) | **164** |
| Git rename events | 88 |
| Git deletion events / distinct deleted path names | 21 / 20 |
| Files at source HEAD | 61 Textile pages |
| Present reconstructed wiki pages | 63 Markdown pages |
| Source HEAD pages with missing *basename* in recovered wiki | **0** |

**Critical interpretation:** 164 historical paths are **not** 164 separate documentation pages, and 20 deleted path names do **not** mean 20 pieces of missing information. Renames and superseded drafts account for many. Basename coverage is not content coverage.

## Confirmed preservation wins / false-positive exclusions

### [PRESERVED BY CONTENT] Deleted `poop.textile` compatibility list

Source: latest surviving `5e6e4709eb32:poop.textile`, an early compatibility-fix catalog. Parsed **433 distinct disc IDs**, in 462 title/ID/fix associations. All **433 / 433 IDs** occur in the currently recovered `.research/wiki/automated.md`. Specifically checked older mode-0x06 entries `SLPM-86667`, `SLPS-00548`, `SLPM-86033` and deleted-from-upstream-HEAD Metal Gear Solid entries `SLES-01370`, `SLES-01506`, `SLES-01507`, `SLES-01508`, `SLES-01734`, `SLPM-86111`, `SLUS-00594`: **all occur in recovered `automated.md`**.

This is a disc-ID coverage finding **only**. Title variants, per-revision fix rationale, fix-type equivalence, and deletion chronology have not been exhaustively reconciled. The original 2024 HEAD `automated.textile` has only 528 unique IDs and omitted some historical entries; this is an example where the merged Wayback reconstruction preserves more than upstream Git HEAD. **Do not replace `automated.md` with the old list or the original HEAD.**

### [PRESERVED BY NORMALIZED CODE DATA] Deleted `PS1 codes .textile`

Source: `b26b989e014e:PS1 codes .textile`. Compared the complete ordered sequence of address/value pairs (ignoring presentation prose/markup) with the currently recovered `.research/wiki/ps1-codes-in-ps2-raw-format.md`:

- **13,933** code-pair lines in each.
- **11,680** distinct pairs in each.
- Normalized ordered-sequence FNV-1a 64-bit fingerprint in both: `a473dd75655e66ad`.
- The original Git HEAD also has the same pair sequence.

Therefore **no missing PS2 RAW code-pair sequence** was found in this deleted historical file. This fingerprint is not a cryptographic proof of every surrounding heading, note, or provenance field; those need a separate editorial comparison.

### [PRESERVED BY OTHER PAGE] Deleted link and index stubs

- `11a. Tools.textile` and `11c. Threads (POPStarter around the web).textile`: original tools and multilingual forum links substantially appear in `.research/wiki/related-stuff.md` (checked A9VG, Metagames, Outerspace, AKuHAK, MemcardRex).
- `16/9.textile`: explanation of PlayStation widescreen/Eyefinity appears in `ps1-widescreen-codes.md`; **the images are not all recovered**, separately tracked below.
- `Guides.textile` and `TOC .textile`: mostly navigation pointers to surviving topic pages; do not restore as present-day duplicates.
- `Introduction to POPStarter.md` and `TOC.textile`: introductory/legal warning appears in `Home.md`.
- `Features.md`, `FAQs .md`, `11b. Tutorials.textile`, `TOC.md`: primarily empty, skeletal, or navigational drafts.
- `Home.md`: Bitbucket's unedited default wiki boilerplate, not POPStarter documentation.
- `IGR textures.md`: vandalized 11-byte placeholder; **do not reproduce it in the public documentation**.
- `sample.md`: unrelated historic Open PS2 Loader 0.9.3 beta sample, not a POPStarter documentation deficiency.
- `POC2/POPS-00001.textile`: partial/obsolete POC2 tutorial scaffold; the full preserved `poc2-pops-00001-era.md` must remain authoritative.
- `Toolboxcommands.textile`: early tool reference; existing `toolbox-commands.md` supplies a much larger reference. Still needs command-by-command historical cross-check.

## Candidate *actual gaps* / fidelity problems

### G1 — [CONFIRMED DISTINCT HISTORICAL DOCUMENT] Early wiki-change bulletin

Deleted `News.textile`, recovered at Git revision `1ee0214f63ba` (`2,172 bytes`, last active September 2016), records **15 dated bulletins** from April–July 2016 covering page creation, corrections, POPStarter OBT14, an early batcher release, compatibility-note changes, and historical site structure. It no longer exists as a page in the 61-file source HEAD or our 63-page archive. Exact markers (e.g. `[WIKI]`, `07/27/2016`, `News (wiki / POPStarter Project)`) were searched across **all 63 recovered wiki pages** without finding the original bulletin. Some events may have been preserved with different dates/formats in other documents, and no authoritative claim should rest on the old bulletin without cross-checking. **Candidate for a clearly dated archival changelog, not modern release documentation.**

### G2 — [PARTIAL / HISTORICAL ONLY] Superseded batcher behavior and warnings

Deleted `Batcher_outdated.textile`, latest surviving revision `e85288316021` (`2,135 bytes`), documented the original `POPStarter ELFs BATCHER` with launch-prefix generation and two cautions:

1. It **deleted existing generated launcher ELFs** before creating replacements.
2. It warned against periods in VCD filenames because generated launcher names could be truncated.

Our recovered `popstarter_batcher.md` covers **v0.2** and `popstarter-batcher.md` covers **v0.3.1**; these are **not identical applications/versions**. Do **not** transfer the old caveats to modern versions without evidence. Preserve as a version-scoped historical note if source tracing confirms distinct behavior. Screenshot URL `2685397097-Sans-titre-1.png` is not a tracked image asset.

### G3 — [SOURCE FIDELITY BUG, NO FIX IN THIS PR] Malformed hexadecimal command typography

The recovered `.research/wiki/automated.md` contains **292 lines** with `COMPATIBILITY_0×` (Unicode multiplication sign, U+00D7) where the original source has the hexadecimal prefix `0x` (ASCII `x`). Example: `$COMPATIBILITY_0×04` instead of `$COMPATIBILITY_0x04`. The rendered command can mislead copying, exact search, and compatibility-mode identification. The original ZIP independently corroborates the intended ASCII form. This needs a controlled source-conversion correction *after review*, not an unreviewed historical import.

### G4 — [34 UNMATCHED HISTORICAL IMAGE REFERENCES; ORIGINAL BYTES NOT IN ZIP]

Scanned image URLs **introduced in all 2,140 commits** via `git log --all -p --unified=0`. Found **155 distinct numeric Bitbucket image IDs** (filename-form count depends on URL decoding and markup cleanup). Cross-referenced by numeric ID against all **124** files in tracked `.research/assets/`: **34 IDs have no tracked match**. This is a historical-reference inventory, **not** proof that all 34 files survive at their URL or are absent from every external mirror.

| IDs currently unmatched | Historical example |
|---|---|
| `1094748012`, `1450475876`, `1720317623`, `2425094621`, `3811602128`, `4095826607`, `4249513129`, `446039127`, `471851278`, `65599370`, `727086931`, `997655191` | Widescreen before/after and game images (Tomb Raider II, Syphon Filter, Ape Escape, Team Buddies, Exhumed, Gran Turismo, MediEvil, Soul Reaver, Die Hard Trilogy 2, Metal Gear Solid, Ghost in the Shell, WipEout 3) |
| `270560112`, `3801833563`, `4286767539` | Widescreen/Eyefinity illustration references |
| `2685397097`, `777862948` | Historic batcher screenshots |
| `3844714277` | POPS2CUE screenshot |
| `2114982071`, `3117688129`, `3333649027` | IGR sample / texture images |
| `2084063178`, `2329291489`, `2348636821` | PS1 memory card import guide screenshots |
| `1391261396`, `1731981611`, `1510911193`, `2070562384`, `2165842753`, `2636724756`, `3346710006`, `4209628073`, `462913228`, `983441507` | POC2, PFSshell, news, smooth, history, scanline/other historical images |

Complete unmatched ID list (34):
`1094748012, 1391261396, 1450475876, 1510911193, 1720317623, 1731981611, 2070562384, 2084063178, 2114982071, 2165842753, 2329291489, 2348636821, 2425094621, 2636724756, 2685397097, 270560112, 3117688129, 3333649027, 3346710006, 3801833563, 3811602128, 3844714277, 4095826607, 4209628073, 4249513129, 4286767539, 446039127, 462913228, 471851278, 65599370, 727086931, 777862948, 983441507, 997655191`.

**Recovery-log cross-check:** `.research/_state/assets_done.tsv` already records failed fetches for **19 / 34** unmatched IDs. Two of those, `270560112` and `4286767539`, are logged with `FAIL:magic(b'\x89PNG')` even though the historical source URLs end in `.jpg`. This looks like a *file-format/extension mismatch*, potentially recoverable if real PNG payloads can be obtained and validated; do **not** equate a PNG signature with a recovered, authenticated image. Other failures recorded `<!DO` / `<?xm` HTML/XML-like responses.

The supplied wiki ZIP includes Git text and image **references** only. It does **not** contain those external image bytes. Some may be independently recoverable through archival URLs, original Bitbucket mirrors, or asset-source investigation; avoid false claims of a complete asset recovery.

### G5 — [INVENTORY REQUIRED] Historic download references and version variants

Diff-scanning all Git history found **83 raw download-basename forms** (80 after URL decoding, markup cleanup and source-host filtering) (URL-encoded variants and strings bearing markup artifacts included), far more than the current hosted download list. This number is **not a missing-binary count**. Candidates to triage include older BATCHER revisions, ToolBox variants, older USB/SMB/HDD Quickstarter packages, IGR language texture packs, a Linux CUE2POPS source archive, and old uLE_kHn packages.

Compare **individual content/sha/version**, archive mirrors, existing package internals and intentional safety exclusions before proposing to host any binary. Keep prohibited, copyrighted, flagged, or non-redistributable executables out. Store historical link metadata even when the binary is unavailable.

### G6 — [INCOMPLETE] Full revision-by-revision prose and technical-claim equivalence

The 61 source pages and 63 reconstructed wiki pages differ in markup, merge strategy, and snapshot years. File-name equivalence, disc ID matching and code sequence matching are not a substitute for a full semantic comparison. Need to examine:
- pre-2017 removed explanatory paragraphs and commands across renamed files;
- additions/eras absent from the selected Wayback snapshots;
- changed compatibility/fix definitions, host/device launch requirements, and caveats;
- exact per-game disc/version/fix **combination**, not merely disc-ID coverage;
- reference link changes, original provenance dates and which revision asserted each fact;
- newly discovered candidate images/download URLs and their original contexts.

Do **not** represent the present first pass as exhaustive.

## All 20 historical deleted paths (not automatically 20 gaps)

| Deleted Git path | Current classification | Next check |
|---|---|---|
| `11a. Tools.textile` | Substantially preserved in `related-stuff.md` | Old link targets/revisions |
| `11b. Tutorials.textile` | Empty stub / superseded | No import |
| `11c. Threads (POPStarter around the web).textile` | Substantially preserved in `related-stuff.md` | Historical URL changes |
| `16/9.textile` | Topic preserved, linked imagery partly missing | 3 image references / old presentation |
| `Batcher_outdated.textile` | Partial, version-specific history | Pre-v0.2 cautions and screenshot |
| `FAQs .md` | Stub | No import |
| `Features.md` | Navigation stub | No import |
| `Guides.textile` | Navigation, links to existing guides | Any old unique links |
| `Home.md` | Bitbucket default boilerplate | Exclude public wiki |
| `IGR textures.md` | Vandalized placeholder | Exclude public wiki |
| `Introduction to POPStarter.md` | Introductory text preserved in `Home.md` | None currently |
| `News.textile` | **Candidate missing dated wiki bulletin** | Dated provenance and event reconciliation |
| `POC2/POPS-00001.textile` | Obsolete scaffold, later better history exists | Historical notes only |
| `PS1 codes .textile` | **All 13,933 code pairs preserved** | Surrounding editorial context |
| `TOC .textile` | Navigation replaced | No import |
| `TOC.md` | Skeleton | No import |
| `TOC.textile` | Intro/nav already present | Any old author byline |
| `Toolboxcommands.textile` | Earlier reference, updated page exists | Old command semantics |
| `poop.textile` | **All 433 disc IDs preserved** | Version/fix pairing |
| `sample.md` | Unrelated OPL beta material | Exclude POPStarter pages |

## Reproducibility and candidate detail

A read-only, standard-library-only source scanner is now committed as [`../tools/audit_original_git_history.py`](../tools/audit_original_git_history.py). It checks all Git history for deleted names, rename-aware paths, historic image/download URLs and ordered code-pair hashes, with optional ZIP SHA-256 verification and a non-overwriting JSON report. It does not alter the wiki or fetch binaries. The 34 unmatched media reference records and previous recovery statuses are also individually enumerated in [`original-git-unmatched-images.tsv`](original-git-unmatched-images.tsv).

Example (run against a preserved, extracted archive, from repository root):

```sh
python3 .research/tools/audit_original_git_history.py \
  --git-dir /path/to/original/wiki \
  --wiki .research/wiki \
  --assets .research/assets \
  --asset-state .research/_state/assets_done.tsv \
  --downloads .research/downloads \
  --source-zip /path/to/original/wiki.zip \
  --out /tmp/popstarter-git-history-audit.json
```

The script is auxiliary research tooling. Its output must be reviewed for false positives before publishing historical claims.

## Reproducibility commands (from an extracted original `wiki/` working tree)

`git fsck --full --no-reflogs --strict`

`git rev-list --all --count`

`git log --all --name-status --find-renames`

`git log --all --diff-filter=D --name-only --pretty=format:`

`git show 1ee0214f63ba:News.textile`

`git show e85288316021:Batcher_outdated.textile`

`git show 5e6e4709eb32:poop.textile`

`git show b26b989e014e:"PS1 codes .textile"`

Original Git audit should be rerun against a **fresh, unchanged ZIP with verified SHA-256** and against the **exact branch SHA** used as the comparator. Never use `git gc`, rebase, force-push, or repack the upstream source as part of analysis.

## Preservation decision gate (not yet reached)

1. Finish high-value revision-diff and per-game fix-equivalence investigation.
2. Resolve the 34 image references against existing recovery logs and potential Wayback/image mirrors, without equating URL presence with binary preservation.
3. Map the 83 raw download-reference variants to confirmed unique artifacts versus intentionally excluded files.
4. Produce an issue-by-issue candidate catalog with exact revision and destination; mark each item as preserved/partial/missing/obsolete/unverified, and annotate factual confidence.
5. **Then** jointly decide whether to add an archival wiki-change log, corrected typography, individual asset references/assets, binary-link records, or historical version-specific sidebars.

**Policy for PR #578:** research findings only; no published-page overwrites, no new unscreened binary attachments, no release packaging changes, no merge.

### Git filename-census correction

The early 248-path figure was inflated by `git log --numstat`'s brace-notation (`{old => new}`) rename expressions. Counting concrete old/new paths with `git log --all --name-status --find-renames` yields **164 distinct actual paths**. Operations: **82 additions, 1,894 modifications, 21 deletions, 88 renames**. The 248 figure must not be used as a historical page count.


## Continuation: source-revision and artifact verification

### G7 — Confirmed missing historical Linux CUE2POPS instructions

The original `vcd.textile` at revision `51abeb7d6e` explicitly links a Linux-modified `cue2pops_src_linux.7z` source archive and explains compilation using GCC. It credits **SovietStriker** and an original AssemblerGames discussion (page 55, post 792589). The original history also links `cue2pops_src_linux.zip`. This note was removed in subsequent revisions and is absent from the present `.research/wiki/vcd.md`, `toolbox-commands.md`, `master-entries.md`, `sources.md`, `build_site.py`, and download manifest. Record as a historical source and contributor credit, **not** a currently supported binary or reproducibly buildable tool. No actual source archive is contained in the user-supplied Git ZIP.

### G8 — Confirmed missing 2016 USB Quickstarter package erratum

The 2016-10-29 `quickstart-usb.textile` revision cautioned that an earlier guide mixed stable/beta instructions and the earlier USB Quickstarter package lacked required `PFS_WRAP.BIN`, requiring a corrected download. Original commit `dcc7269d4c5` (2016-11-03) removed the dated erratum, noted CUE2POPS 2.3, and switched `POPStarter_Quickstarter_Pack_USB_20161002.7z` to `POPStarter_Quickstarter_Pack_USB_20161103.7z`. Commit `14f8edd518d` (2017-01-10) later removed old instructions. The recovered quickstart pages do not reproduce the 2016 erratum or the old filenames. Preserve the correction as *dated release/package history*, not as modern setup guidance.

### Fully preserved numeric corpus: original PS1 RAW cheat codes

Beyond the previously verified 13,933 PS2 RAW pairs, compared original `ps1-codes-in-ps1-raw-format.textile` against the recovered `.research/wiki/ps1-codes-in-ps1-raw-format.md`. Both contain **47,596 ordered hexadecimal address/value pairs** and **37,826 distinct pairs**, with identical order-sensitive FNV-1a 32-bit fingerprint `3510520a`. No PS1 RAW numeric cheat-code sequence gap was detected. Heading and editorial text equivalence has not been established; FNV is non-cryptographic.

### Stronger historical per-game category comparison

For source `5e6e4709eb32:poop.textile`, checked matching game-specific fix categories (rather than only disc ID presence) in recovered `automated.md`:

- **182/182** distinct historical mode 0x04 disc IDs have matching mode 0x04 annotations.
- **180/180** distinct historical LibCrypt-crack disc IDs have matching LibCrypt annotations.
- **90/90** distinct historic disc-ID associations across modes 0x01, 0x02, 0x03, 0x05, and 0x06 have matching mode annotations. Two mode-0x06 lines use the phrase "Compatibility Mode 0x06" rather than a same-line code token.
- Rare Crash Fix, VSync Fix, VMC disable, Boot/Load Fix and Metal Gear cutscene fix categories were also checked on their associated source disc IDs.

This verifies category coverage for these sets, **not** every unique disc revision, conflicting fix claim, game-version pairing or implementation detail. Mode comparisons normalize the recovered Markdown's malformed Unicode `0×` to `0x` *in analysis only*; the documented 292 source-fidelity mistakes remain unchanged.

### Historical download crosswalk completed

See [the 80-reference download crosswalk](original-git-download-crosswalk.md). It classifies the **80** source filename forms as: 17 exact hosted names, 45 without an exact hosted filename, 7 possible filename/container-format aliases requiring binary comparison, 3 probably present within hosted bundles requiring inspection, 4 intentional exclusions, and 4 invalid/truncated/unrelated forms. The site currently tracks **23** downloads overall; this is not a claim of 45 proven-missing binary files. Importantly `.research/_tmp/dl_manifest.tsv` reports some tracked downloads as "missing" and some deliberately excluded downloads as "recovered"; its status labels are stale and unsafe for completeness claims.

The original ZIP is a Git **documentation/history** archive. It does not contain referenced Bitbucket download binaries or missing screenshot image bytes. **Research only: no import, no binary upload, no main-branch changes, no merge.**


### Historical page-lineage classification

Tracking **88 Git rename events** across all 2,140 commits with rename-aware path union-find yields **164 distinct concrete path names** organized into **79 connected file-name lineages**: **60 lineages** lead to the **61 files at the original 2024 HEAD** (one rename-connected lineage includes two currently existing filenames), while **19 lineages** have no file remaining at HEAD. This is a stronger genealogy than naïvely subtracting 61 final pages from 164 historical paths. The 19 retired lineages include early News, Batcher, old 16:9, Toolboxcommands, guide/index stubs, POPS-00001, the old PS1 codes page, and unrelated/vandalized samples. Distinct retired lineages are not automatically missing facts; many are already represented by their successor topics.

### Original ZIP binary-safety scope (read-only object inspection)

The original Git history has exactly **1,982 Git blob objects** (about **17.25 MB uncompressed**), all decodable as UTF-8. No blob contains a NUL byte or begins with common ELF, PE/MZ, ZIP, RAR, 7z, PNG, GIF or JPEG file signatures. This confirms the original ZIP's **Git object payloads are textual documentation**, not the missing screenshot/download binaries. It does **not** constitute a professional malware scan or a guarantee about linked external files. The Git history preserves contributor names/emails and should be handled as historical provenance.

### Image gaps split by source age

The 34 unmatched historical Bitbucket numeric image IDs comprise **19 still referenced by original Git HEAD** and **15 referenced only by older or removed versions**. None of the 19 current original IDs was found in the recovered Markdown source pages or tracked gallery JSON. See [the priority-separated image record](original-git-image-priorities.md), including each original filename, source page and existing asset-recovery status. URLs ending `.jpg` for IDs `270560112` and `4286767539` yielded PNG-signature responses in old recovery logs; genuine retrieval and full-file verification remain outstanding. Historic references alone never establish recoverable image bytes.

### Additional fidelity issue — historically inherited command typo

Original `widescreen.textile` uses `$ULTRE_WIDESCREEN` in one explanatory bullet, whereas original `special-cheats.textile`, `proto.textile` and `popstarter-changelog.textile` use the documented `$ULTRA_WIDESCREEN` spelling. The Wayback-derived `.research/wiki/widescreen.md` faithfully repeats the **source typo**, while the recovered command reference and generator use the correct name. This should eventually receive a factual editorial annotation in the modern guidance without silently rewriting the credited original document. Separate from the **292 malformed `0×` hexadecimal spellings** in `automated.md`.

### Historical list removed in 2024 but preserved by recovery

Source commit `cad93a2da1e` (2024-07-22, contributor El_Patas) removed the former HDD/USB/SMB official Google Docs compatibility-list links and attribution to AlGollan84/Algol/Allan58 and krHACKen from `compatibility.textile` after promoting the newer ElOtroLado list. Our merged `.research/wiki/compatibility.md` **does** retain those older links and authorship with historical/obsolete labels, so this is a verified preservation win. It is a concrete reason **not** to overwrite our reconstruction with original Git HEAD.

**No additions to the published historical pages, compiled software, or binary download directory are made in this PR.**


## Continued chronology audit — further verified differences (October 2026)

The comparisons below use specific original Git revisions and checked the current recovered Markdown pages. They describe **historical documentation**, not requirements for today's POPStarter runtime. A compact evidence index is recorded in [`original-git-technical-changes.tsv`](original-git-technical-changes.tsv).

### G9 — [CONFIRMED, VERSION-SCOPED] Configuration offset `$412` changed meaning

In the first advanced configuration documentation (`fa60511de312`, 2016-04-11; expanded in `d071daa8`), offset `$412` was described as **"Skip most POPStarter functions (NOT FULLY IMPLEMENTED)"**, with `0x00` = disabled and `0x01`/`0x02` = level 1/2. The source expressly warned that the feature was unfinished. A subsequent revision (`34755b05e46`, 2016-04-12) replaced the description with **NOT USED**. On 2016-11-20 (`7211f94519a`) the configuration-table documentation changed `$412` to a **SetGsCrt hack**, with `0x00` disabled and `0x01` enabled to address some HDTV/interlaced-component issues.

Our recovered `.research/wiki/configuration-table.md` correctly describes the **later** SetGsCrt meaning, but the early experimental meaning and its withdrawal are absent from that page. Other current pages do mention SetGsCrt; the old option is not an alternative current mode. **Preserve only as a dated version-history footnote, if desired; never merge incompatible meanings into a single current setup instruction.**

### G10 — [CONFIRMED, HISTORICAL FILE-NAME TRANSITION] USB/SMB `POPS_IOP.PAK` → `POPS_IOX.PAK`

The original late-2016 USB and SMB setup instructions refer to `POPS_IOP.PAK`. Original Git commits `ac9c1c5` (USB, 2017-02-01 15:22 UTC) and `60b6676` (SMB, same date) replaced the referenced compressed emulator filename with `POPS_IOX.PAK`; follow-up commits `895809b` and `bb5d665` corrected additional notes (including mixed punctuation `POPS_IOP_PAK`).

The recovered `.research/wiki/usb-mode.md`, `smb-mode.md`, and `popstarter-changelog.md` refer to the later name `POPS_IOX.PAK`, with no `POPS_IOP.PAK` historical naming note. The original Git text proves a **documentation rename on that date**, but not whether any particular old package is byte-compatible. **This belongs to historical setup/version chronology, not a newly offered package download. A contemporaneous developer statement (below) suggests the original `POPS_IOP.PAK` name was an erroneous old wiki instruction, not a valid third file format.** No emulator payload is included.


### Primary-source corroboration of G8/G10 — original author clarification (2016-10-29)

A preserved [ASSEMblergames discussion, October 29 2016](https://www.assemblergames-archive.com/printthread.php?page=191&tid=38642) documents an actual user trying to use POPStarter **WIP05** (build 2015-06-03), following the original USB guide, and reporting a failed boot after **renaming a file from `POPS_IOX.PAK` to `POPS_IOP.PAK`**. In that same exchange, POPStarter developer **krHACKen** explained that:

- `POPS_IOX.PAK` belongs to the POPStarter beta version; the older WIP05 requires a different `POPS.PAK` format.
- Changing the PAK filename does **not** make it compatible with a different launcher version.
- WIP05 USB setup required `PFS_WRAP.BIN`; the beta did not require this particular file.
- A failure still could have been USB access-related, making this an explanation of **version rules**, not conclusive proof of that particular user's root cause.

The dated source explicitly supports the USB Quickstarter erratum (G8) and reveals the old `POPS_IOP.PAK` wiki spelling (G10) was **probably incorrect or misleading contemporaneous documentation**, **not demonstrated evidence of an independently distributed valid PAK variant**. The February 2017 replacement with `POPS_IOX.PAK` is therefore best documented as **source-correction history**, not as a software artifact rename. The reproduced forum thread includes developer and tester testimony, but no original binary checksums proving every version pairing.

**Preservation decision:** any old guide reprint should visibly mark the incorrect PAK naming as superseded and warn not to rename files across launcher revisions. Do **not** recreate a downloadable `POPS_IOP.PAK`, and do not publish a replacement Sony emulator package.

### G11 — [CONFIRMED HISTORICAL NOTE ABSENT] Old VCD guide: missing CUE sheets

The old `VCD.textile` (addition `058f6fc`, 2016-04-14) offered a link to `http://redump.org/cues/psx/` when a PS1 disc CUE sheet was absent, and cautioned that the named BIN and CUE entries must match, noting that the CUE describes CD tracks. On 2016-07-27, commit `a114f3a` **removed** that note; the final original `vcd.textile` and the directly inspected recovered `.research/wiki/vcd.md` do not contain it. A repository-wide exact-string search returned zero results, but that search has known false negatives, so **the absence assertion is limited to the directly checked recovered VCD page**.

This is a **missing historical troubleshooting reference**, not automatically valid recovery advice for every image. A generic CUE from a different dump may describe different tracks and must not be presented as an equivalent substitute without verification. Retain provenance and deletion date if represented in the archive.

### [PRESERVED; EXCLUDE FROM MISSING-CONTENT COUNT] PFSshell batch transfer and multi-disc limits

The older `pfsshell.textile` referenced `pfs-scripts.7z` and credited **ElPatas** and **deba5er** for the batch transfer method. The reconstructed `pfsshell.md` still documents the exact `pfs.bat hddX: __.POPS *.VCD` invocation and attribution. The historical script archive itself remains an unverified download-reference candidate, not a missing instruction.

The older four-disc limit, `DISCS.TXT` line count limit, and shared VMC method are also documented in the reconstructed `multi-disc.md`. **Do not add duplicate pages** for these removed source notes.

### Audit scope and future comparisons

These findings came from tracking paragraph-level deletions and dated redefinitions in the original Git history. They are **not** a claim that all changed prose across 2,140 commits has been completely reviewed or semantically validated. The remaining candidate work includes code/command edge cases, fine-grained per-game version associations, removed download provenance, and accurate image recovery. All changes remain **research-only** in draft PR #578.

### [PRESERVED — NOT A MISSING GAP] Early PPF patch-list descriptions

An early `POPStarter Configuration Table.textile` (`a711cae`, 2016-04-21) explains `NO_LC_CRACKS.PPF`, `DEBUG_AND_HALT.PPF`, `NO_VMC.PPF`, `ONLY_1ST_VMC.PPF`, `NO_PAL.PPF`, `FORCE_MODEX.PPF`, `DEFAULT_IGR_TEXTURES.PPF`, `LC_ONLY.PPF` and `NO_AUTO_PATCH.PPF`. These lines are absent from the later source HEAD but the named PPFs (including the five spot-checked rare names) **are present in our directly retrieved `.research/wiki/configuration-table.md`**. Do not count them as missing technical guidance, even if a Git-only deleted-line scan flags them.

**Verification warning:** GitHub repository-wide code-search calls returned `0` for literal `NO_LC_CRACKS.PPF` despite direct file retrieval finding that exact string in the recovered configuration page. Therefore repository-wide search **cannot establish absence** in this investigation. Future gap labels must cite direct recovered-page inspection or a complete verified local mirror.


## Additional source-history findings — early WIP05 PAL timing and obsolete disc-combining instructions

### G12 — [CONFIRMED HISTORICAL BUG REPORT ABSENT] PAL emulator clock / XA audio stutter

Original `18b64829c634f5730bbc56a847c02c4c162945eb:known-bugs.textile` (2016-09-26) contains a WIP05-sourced bug note: the emulator's PAL clock rate was inaccurate and its A/V self-resynchronization could produce stuttering in XA playback. This was **deleted** by `9fdfafd3d241df3893de96406de2aadf9fe7f4f6` on 2017-10-23, when the known-bugs page was reworked. Direct reads found no equivalent clock-rate/XA-stutter note in the recovered `known-bugs.md`, `popstarter-changelog.md`, `proto.md`, `chronology.md`, `history.md`, `version.md`, `Home.md`, or `multi-disc.md`. The original note explicitly applied to **WIP05 documentation**; the status or correction in subsequent builds is **unverified**. Do not describe it as an active bug in POPSLoader or current POPStarter without testing.

### G13 — [CONFIRMED REMOVED ARCHIVAL INVENTORY] Pre-swap-disc combining-kit catalogue

The original `7f51bf440d7116b41e55056ec672caa62e09efde:VCD.textile` (2016-09-22) retained a section explicitly marked **OBSOLETE** with **52 region-specific kit entries** (36 NTSC-U, 10 NTSC-J, 6 PAL-E), the old community kit links, an author warning of **possible virus** for the Chrono Cross kit, and an alternative method involving a save handoff to a PS1 emulator/console between discs. The entire section was deleted in `462bc5f099565b5b13fdf5a5e537c0b06c02aa22` five minutes later as documentation transitioned to the native POPStarter multi-disc implementation. The recovered pages checked do not contain that inventory or its item-specific warning. Full title-only record and cautious provenance: [`original-git-obsolete-multidisc-kits.md`](original-git-obsolete-multidisc-kits.md). **Historical metadata only**; no downloadable kits, and no claim that the flagged package actually contained malware. The new/native method supersedes the old workflow.

### F2 — [CONFIRMED DOCUMENT-QUALITY GAP] Hexadecimal-prefix corruption is wider than 292 lines

A complete scan of **all 63 recovered pages** finds **854** occurrences of `0×` followed by a hexadecimal digit across **10 pages**, not just the 292 affected compatibility-command lines previously identified in `automated.md`. The original wiki final revision has only **75** such occurrences (3 in `compatibility.textile`, 72 in `troubleshooting-games.textile`), showing both *inherited historical typos* and extensive *reconstruction/markup conversion errors*. The strongest comparison is `automated.md`: **630** invalid prefixes vs **zero** in original `automated.textile` (which uses the proper ASCII `0x`); and `configuration-table.md`: **72** invalid prefixes vs **zero** in the original source (75 ASCII `0x`). See [page-by-page fingerprint and method](original-git-hex-fidelity.md). Do **not** globally replace the legitimate multiplication sign in aspect ratios or historical direct quotations.

As with the rest of PR #578, these are evidence records only. No published documentation, emulator files, or downloads were modified.


## Further original-Git revision triage — release warnings, lost credits and reconstructed links

### G14 — [CONFIRMED ORIGINAL HISTORICAL WARNING ABSENT] WIP06 OBT14 USB IRX / POPS-folder issue

A home-page note introduced by Git commit `ca88fcf1bb6220fd66df6c02428779ee2cce6b64` (2016-07-27 08:31 UTC), and present at `10ec7c6f588f9feed6294f306117b7b4e4ac6c65:Home.textile`, warned about **reports** (not verified reproduction in this audit) of black screens and corrupted POPS-folder files after installing the **OBT14** release (2016-07-23). It advised reinstalling a damaged POPS folder and cautioned **not to use IRX modules in USB mode with that beta**. On 2016-09-19, `95e41b9093b380d713d1448c67ececd83e8b33cd` removed the whole note when promoting OBT15. No matching OBT14 black-screen/corruption/USB-IRX warning was found by **direct inspection** of recovered `Home.md`, `popstarter-changelog.md`, `version.md`, `history.md`, `known-bugs.md`, `usb-mode.md`, `quickstart-usb.md`, `troubleshooting-games.md`. The historical discussion cites ASSEMblergames pages 84–85; a forum report is **not** proof that every OBT14 setup has this bug, and there is no established current POPStarter or POPSLoader applicability. This is particularly important context if the old OBT14 release is preserved or linked.

### G15 — [CONFIRMED GROUP ATTRIBUTION LOST] Early homepage developer/tester acknowledgment

The original wiki homepage explicitly thanked **22 named or pseudonymous contributors** plus an unnamed anonymous contributor, bug reporters, and donors. This group acknowledgment was present at `4867d389338f485af7a514cd12373345e0503a0e:Home.textile` and was removed on 2016-04-12 by `e298fe8309fbda03baace442396e0efbe06a6e10`. The full collective credit text is absent from the recovered `Home.md`. Several names independently appear elsewhere in the recovered changelog/chronology, but the **original group acknowledgment itself is absent**, so do not classify every individual as completely uncredited without a full-site/name search. See [the attribution and release-warning evidence](original-git-2016-notes-and-credits.md). Preserve the contributor pseudonyms and original vague/anonymous attribution without inventing identities, GitHub accounts, roles, or personal details. The supplied ZIP Git history has author metadata but this is **not** equivalent to the manual thank-you list.

### F3 — [SUSPECTED AUTOMATIC LINKIFICATION IN RECOVERED SNAPSHOT, NOT ORIGINAL TEXT] Date/constant values promoted to Git-commit URLs

Across direct reads of all 63 reconstructed `.research/wiki/*.md` files, counted **30** links under `https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/commits/<hex-like>`, spanning nine recovered pages: `apps-last-version.md` (1), `cheat-engine.md` (1), `chronology.md` (2), `pfsshell.md` (1), `popstarter-changelog.md` (5), `smb-mode.md` (1), `special-cheats.md` (7), `timeline.md` (6), `version.md` (6). All 61 original wiki **HEAD Textile pages have zero occurrences of the corresponding explicit `popstarter-documentation-stuff/commits/` URLs**. Several reconstructed anchors surround release dates (e.g. `20190605`, `20190104`) or numeric code values (e.g. `00000002`, `00507028`), suggesting a Bitbucket/Web-archive HTML auto-linkification or Markdown-conversion artifact. These are **suspect links**; not all are proven dead, nor is it known which were auto-generated on Bitbucket before archiving versus during conversion. They should be validated individually and never be described as original authored source links without evidence.

### [PRESERVED — manually applied compatibility fixes not missing]

Deleted from 2017 original `compatibility.textile` at commit `15f0d8a`, the **manual Game Fixes/TROJAN catalogue** contains **45 game/fix rows and 40 distinct disc IDs**, including two separate Casper loading-fix IDs (`SLES-00045`, `SLUS-00162`). The complete 45-row section and all 40 IDs already appear in both recovered `compatibility.md` and `Game-Compatibility.md`. Casper is absent from the separate `automated.md` **by design**; an automated-only index check falsely suggests missing compatibility information. Keep manual vs automated fix classes separate. This source confirms preservation of the historical manual workaround description, *not* byte availability of the `Game_Fixes.7z` archive.

### [PRESERVED — gallery references AND actual image assets]

The historical `smooth.textile` gallery temporarily shrank dramatically in 2017 (`930678b`), but the later original Git HEAD restored its main comparison gallery. Our current recovered `smooth.md` has 16 comparison-game headings, and the site `_state/galleries.json` includes **46 original image references** for the page. All 46 corresponding files are tracked in `.research/assets/`. More broadly, all **98** references stored in **18 nonempty cached galleries** across the site match actual tracked image filenames (from the 124 image assets). Therefore there is **no current known missing gallery-cache image for those 98 references**. This does **not** disprove the separate 34 unmatched numeric image IDs in *all historical Git revisions*, or the 19 IDs still referenced at source HEAD but not in the recovered gallery cache. The inventories have different scopes and must never be directly subtracted.

**Scope reminder:** this is audit evidence only. No change to original historical documents, public wiki, credits, compatibility table, downloads, or binary assets is authorized by draft PR #578.


### C1 — Missed October 2017 light-gun documentation correction

Original wiki commit `f4210efed74840394474a502da259d733a03be22` corrected `ps1-special-devices.textile` step 6 from **USBD.IRX + USBD.IRX** to **USBD.IRX + USBGUN.IRX** as the first/second **example** modules. Our recovered `ps1-special-devices.md` still has the outdated duplicate `USBD.IRX` text (despite step 5 mentioning `USBGUN.IRX`). The original 2024 HEAD has the corrected wording. Tutorial attribution to **AKuHAK** must remain. This is a **high-confidence editorial source-fidelity correction for later approval**, not a tested assertion of particular light-gun hardware support.

### C2 — Reconstructed USB example more correct than original HEAD

Original commit `eb75d91410491b8d693e70b6980c8f9c4036bfc2` changed the **USB** table's example from `XX.Some Game.elf` to erroneous `SB.GAME.ELF`, contrary to the same page's explicit prefix `XX.`. The incorrect USB sample survived in the original HEAD. Our recovered `usb-mode.md` preserves correct `XX.Some Game.elf`, while `smb-mode.md` properly uses the SMB prefix `SB.`. **Do not replace the reconstructed page with the original HEAD.**

### C3 — Validated pseudo-commit link generation

The previously identified **30** `/commits/` links in nine recovered Markdown pages represent **18 distinct values** (seven date labels, five numeric code/config values, three checksums, three historical Pastie IDs). **None** resolves as a Git object in the supplied 2,140-commit wiki Git clone (tested by `git cat-file -t`), and the original wiki HEAD has no explicit URLs of that form. Forensic breakdown, examples and cautious provenance: [`original-git-source-corrections.md`](original-git-source-corrections.md). Exact origin of the spurious links in the archive/HTML conversion chain is not established. Treat as a reviewable fidelity issue, not 30 missing Git commits.

All three findings are research only; no site source or public documentation was changed.
