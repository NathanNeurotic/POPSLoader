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

Deleted `News.textile`, recovered at Git revision `1ee0214f63ba` (`2,172 bytes`, last active September 2016), records **14 dated bulletins** from April–July 2016 covering page creation, corrections, POPStarter OBT14, an early batcher release, compatibility-note changes, and historical site structure. It no longer exists as a page in the 61-file source HEAD or our 63-page archive. Exact markers (e.g. `[WIKI]`, `07/27/2016`, `News (wiki / POPStarter Project)`) were searched across **all 63 recovered wiki pages** without finding the original bulletin. Some events may have been preserved with different dates/formats in other documents, and no authoritative claim should rest on the old bulletin without cross-checking. **Candidate for a clearly dated archival changelog, not modern release documentation.**

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
