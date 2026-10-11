# Post-merge audit: exhaustive original Bitbucket download filename coverage

Research continuation after **PR #578 was externally merged**. Original source: AstroSnail's immutable `wiki.zip` (SHA-256 `d0c243d91e417988825ed92b440224ed46cbbf448d0b67528e0957c15c0d029a`), original HEAD `960d675d278296a3a62143410b38aa8882d21a79`. Comparator: the canonical `.research/research/original-download-catalog.tsv` merged onto `master` by PR #578. This is an **inventory completeness check**, not a binary-recovery exercise.

## Full-history scan results

| Check | Result |
|---|---:|
| Original Git commits | 2,140 |
| Reachable distinct original Git blob objects read | **1,982** |
| Bitbucket `/downloads/` URL occurrences across those blobs | **1,078** |
| Raw distinct filename forms before removing Textile emphasis suffix `*` | **84** |
| Canonical distinct source filename forms (after URL decoding and Textile delimiter trimming) | **80** |
| Catalog `wiki_git` filename rows | **80** |
| Original filename forms absent from catalog | **0** |
| Catalog `wiki_git` names not represented in original source | **0** |
| Separate legacy-manifest-only records | **2** |
| Binary bytes recovered from this scan | **0** |

The independent original-source 80-name sorted sequence and the 80 catalog rows have the **same FNV-1a 64-bit fingerprint: `b956696fd18ee4ff`**. This is a compact cross-system set comparison (not a cryptographic integrity certificate). Source normalized sorted names also hash to SHA-256 `93d518b738244b58fb3ddb1c970bd2e1cf0d50ad55046a4e65470138dfb3252a`. The companion script performs the stronger **exact set-difference comparison** when both data sources are locally available.

**Why 84 becomes 80:** historical Textile hyperlinks sometimes append a formatting `*` immediately after the URL. There are 24 raw forms with this suffix; only four are duplicate-form pairs that collapse into already recorded filenames. Stripping the trailing Textile delimiter therefore reduces 84 raw unique strings to 80 canonical source forms, rather than identifying four newly missing archives.

The two catalog records **not** supported by these original-wiki download URLs are explicitly marked `legacy_manifest_only`:
- `POPStarter_r13_WIP_06_OBT_20161120.zip`
- `RadHostClient 1.8a.7z`

These are *not inferred missing wiki files* and their sources remain separately qualified. Catalog rows with `wiki_git+bitbucket_listing` count as Git-derived, not as extra rows.

## Reproduce

1. Extract the unchanged historical `wiki.zip` and verify it with `sha256sum`.
2. Run from POPSLoader's research directory:
   `python3 .research/tools/audit_original_download_links.py /path/to/extracted/wiki .research/research/original-download-catalog.tsv`
3. The utility reads **every reachable Git blob** using `git rev-list --objects --all` plus Git's batch object reader, extracts historical URL basenames, percent-decodes them, removes trailing Textile formatting delimiters, and compares exact filename sets with catalog `wiki_git` evidence rows.
4. It prints missing/unexpected names and exits nonzero if catalog coverage drifts. It never downloads, replaces, creates, runs or distributes any historical package.

**Validation:** syntax checked with `python -m py_compile`; positive test with a locally generated 80-row reference catalog plus the two separately labeled legacy entries returned `PASS`; deliberately removing `BATCHER_0.3.1.EXE` returned `DIFF` and listed it as missing. The **real** merged GitHub catalog was independently examined with its connector, and its exact 80-name sorted fingerprint matches the original source's fingerprint.

## What this result does *not* establish

- **80 references ≠ 80 recoverable archive binaries.** Some links are typos/invalid, variants, user-withheld or superseded content; original binaries were not embedded in the Git history.
- **Coverage ≠ byte equality.** The existing independently indexed 2020 Bitbucket listing reports at least two same-name size discrepancies against currently hosted archives: `NOPAL_PATCH.7z` (historically 226 B, tracked 188 B) and `network_modules.7z` (historically 59.0 KB, tracked 93,934 B). See [2020 external listing comparison](original-bitbucket-download-snapshot-2020.md). No replacement is justified without authenticated source bytes and internal member/CRC analysis.
- **Completeness is limited to URLs matching the historical `popstarter-documentation-stuff/downloads/` path in reachable blobs**, not every external forum attachment, defunct mirror, lost Bitbucket upload that was never linked in the wiki, or file version held only in the real Bitbucket listing.

**Disposition:** Close the previously open question of *missing filename forms within the historic wiki Git URL corpus*. Continue checking **original payload provenance and content**, with correct legal/release-policy gating; maintain intentional download exclusions. No binaries were added and no existing archive was touched.
