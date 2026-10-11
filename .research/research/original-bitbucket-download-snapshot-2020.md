# Original Bitbucket downloads listing: externally corroborated source inventory

**Preservation research for draft PR #578 — do not merge or automatically import binary files.** This is a new, independent artifact-level evidence source beyond the original `wiki.zip` Git revisions: a preserved <https://archive.ph/PBG1V> snapshot of **Shaolin Assassin / POPStarter Documentation & Stuff / Downloads**, indexed by web search.

**Source accessibility limitation:** the direct archived URL currently responds with HTTP 429 or is inaccessible from some clients. The **search-index cache exposes the 28 recent listing rows quoted below** (with displayed size, uploader and date). The visible excerpt is **not proven to contain the complete historical Downloads index**. Consequently **28 is a verified indexed sample, not the total number of original downloadable assets**. The ZIP supplied for this audit contains Git text and history, not these download payload bytes.

**Comparison:** POPSLoader `master` base Git tree at `15ffb1c7c46e1643ab2869baf1b26718cf53a604`, specifically the **23 tracked** `.research/downloads/` files, using exact filename and Git tree file size. We do not claim hash equality or content equivalence merely from filename/size.

## Reconciliation of 28 externally corroborated original upload rows

| Category | Count | Interpretation |
|---|---:|---|
| Same exact filename currently tracked in our downloads directory | **13** | Exact-name presence only; payload equality unverified |
| Original filename not currently hosted under that exact basename | **14** | Some have different archive formats, later versions or other sources; not proven missing content |
| Deliberately withheld from distribution | **1** | `Disc_Combining_Kits.7z`, 8.4 MB, existing exclusion policy |
| **Total** | **28** | Search-indexed snapshot rows; no binary retrieval |

The sample contains **five uploads by El_Patas on 2020-02-09** and **23 earlier rows uploaded by Shaolin Assassin**. Credit those uploaders as historical *Bitbucket-listed uploaders*, not necessarily software authors.

| Historical Bitbucket filename | Original displayed size | Uploaded by | Date | Our exact-name file size/status |
|---|---:|---|---|---|
| `uLE_kHn_20191110.zip` | 2.0 MB | El_Patas | 2020-02-09 | No exact-name tracked file |
| `POPStarter_r13_Beta_20190605.zip` | 338.9 KB | El_Patas | 2020-02-09 | 347,072 bytes |
| `POPStarter_SMB_Quickstarter_Pack_20200209.zip` | 273.6 KB | El_Patas | 2020-02-09 | 280,193 bytes |
| `POPStarter_HDD_Quickstarter_Pack_20200209.zip` | 1.1 MB | El_Patas | 2020-02-09 | 1,113,737 bytes |
| `POPStarter_USB_Quickstarter_Pack_20200209.zip` | 642.8 KB | El_Patas | 2020-02-09 | 658,260 bytes |
| `CHEATS.TXT` | 1.1 KB | Shaolin Assassin | 2017-10-27 | 1,052 bytes |
| `network_modules.7z` | 59.0 KB | Shaolin Assassin | 2017-10-27 | 93,934 bytes |
| `NOPAL_PATCH.7z` | 226 bytes | Shaolin Assassin | 2017-10-26 | 188 bytes |
| `FORCEPAL_PATCH.7z` | 234 bytes | Shaolin Assassin | 2017-10-26 | 234 bytes |
| `Disc_Combining_Kits.7z` | 8.4 MB | Shaolin Assassin | 2017-10-26 | **Withheld** |
| `DS3_modules_USB_20171017.7z` | 13.8 KB | Shaolin Assassin | 2017-10-17 | 14,089 bytes |
| `DS3_modules_BT_20171017.7z` | 17.7 KB | Shaolin Assassin | 2017-10-17 | 18,149 bytes |
| `BATCHER_0.3.1.EXE` | 23.5 KB | Shaolin Assassin | 2016-11-28 | No exact-name tracked file |
| `pfsshell-0.2a.7z` | 62.6 KB | Shaolin Assassin | 2016-11-03 | 64,085 bytes |
| `RadHostClient_1.8a.7z` | 333.0 KB | Shaolin Assassin | 2016-11-03 | 341,002 bytes |
| `CUE2POPS_2.3.7z` | 30.0 KB | Shaolin Assassin | 2016-11-03 | No exact-name tracked file |
| `hddosd_sample_files.7z` | 18.5 KB | Shaolin Assassin | 2016-10-09 | No exact-name tracked file |
| `IGR_textures_-_Spanish_pack.7z` | 172.0 KB | Shaolin Assassin | 2016-09-27 | No exact-name tracked file |
| `IGR_textures_-_Portuguese_pack.7z` | 216.9 KB | Shaolin Assassin | 2016-09-27 | No exact-name tracked file |
| `IGR_textures_-_Polish_pack.7z` | 459.9 KB | Shaolin Assassin | 2016-09-27 | No exact-name tracked file |
| `IGR_textures_-_French_pack.7z` | 623.3 KB | Shaolin Assassin | 2016-09-27 | No exact-name tracked file |
| `IGR_textures_-_Chinese_pack.7z` | 63.4 KB | Shaolin Assassin | 2016-09-27 | 64,941 bytes |
| `IGR_textures_-_English_pack.7z` | 843.8 KB | Shaolin Assassin | 2016-09-27 | No exact-name tracked file |
| `IGR_textures_-_German_Pack.7z` | 117.0 KB | Shaolin Assassin | 2016-09-27 | No exact-name tracked file |
| `IGR_Behaviour_Modifiers.7z` | 1.0 KB | Shaolin Assassin | 2016-09-27 | No exact-name tracked file |
| `Compatibility_Modes.7z` | 882 bytes | Shaolin Assassin | 2016-09-27 | No exact-name tracked file |
| `IGR_sample_kit.7z` | 62.9 KB | Shaolin Assassin | 2016-09-27 | No exact-name tracked file |
| `DEBUG_AND_HALT.PPF` | 73 bytes | Shaolin Assassin | 2016-09-24 | No exact-name tracked file |

## Two confirmed archival size mismatches despite identical filenames

### D1. `NOPAL_PATCH.7z`: **226 bytes indexed vs 188 bytes hosted**

The preserved Bitbucket listing reports **226 bytes**, uploaded by Shaolin Assassin on **2017-10-26**. POPSLoader's tracked same-name object has exact Git tree size **188 bytes**. These cannot be identical byte streams. They might be different repackings, different content, different historical versions or a replacement from a later mirror; **do not describe the current file as an exact copy of the indexed 2017 upload without hashing both genuine originals**. The site's prior `assets_done.tsv` specifically reports the historical Bitbucket download URL as an unrecovered/invalid payload, `FAIL:magic(b'<?xm')`.

### D2. `network_modules.7z`: **59.0 KB indexed vs 93,934 bytes hosted**

The preserved Bitbucket listing reports **59.0 KB** (2017-10-27), whereas the tracked file is **93,934 bytes ≈ 91.7 KiB**. This difference greatly exceeds display rounding; these are not the same archived bytes. The prior downloader log also recorded the original Bitbucket asset URL as `FAIL:magic(b'<!DO')`. This is particularly worth auditing because the contents are network/IOP support files; the existing hosted archive may contain a **different module set or revision**. **No claim is made that the hosted version is defective, malicious or incompatible**. Version identification, internal file hashes and safe origin remain unverified.

### Cases where size evidence supports, but does not prove, historical identity

- `FORCEPAL_PATCH.7z`: both **234 bytes**; size alone cannot establish identical contents.
- `DS3_modules_USB_20171017.7z`: indexed **13.8 KB**, tracked **14,089 bytes (~13.76 KiB)**.
- `DS3_modules_BT_20171017.7z`: indexed **17.7 KB**, tracked **18,149 bytes (~17.72 KiB)**.
- `IGR_textures_-_Chinese_pack.7z`: indexed **63.4 KB**, tracked **64,941 bytes (~63.42 KiB)**.
- 2020 SMB/USB/HDD Quickstarter archives and beta release: tracked sizes agree with the displayed rounded values.

**Even a perfect exact-name-and-size match is not evidence of identical binary contents.**

### Alternate format and mirror-trap findings

- The original Bitbucket `CUE2POPS_2.3.7z` is listed as **30.0 KB**. The hosted `CUE2POPS_2.3.zip` is **32,674 bytes** (different archive container/name). Treat as a **candidate alternative packaging**, not a verified identical original package.
- The original `Compatibility_Modes.7z` was **882 bytes**. The hosted `Compatibility_Modes.zip` is **1,908 bytes**. Same caveat: different packaging and no decompressed payload checksum comparison yet.
- The original **English, French, German, Polish, Portuguese, Spanish** IGR language archives are each independently indexed, with **2016-09-27** upload attribution and size. The recovered site hosts only the historical `IGR_textures_-_Chinese_pack.7z` among those seven exact archive names.
- The mirror formerly noted in `_tmp/found_mirrors.tsv`, <https://github.com/CosmicScale/PSBBN-Definitive-Project/tree/main/scripts/assets/POPStarter>, currently contains **individual localized `IGR_BG.TM2`, `IGR_NO.TM2`, `IGR_YES.TM2` and PNG images** in language folders, **not the original named 2016 `.7z` archives**. Direct GitHub directory inspection verified `eng`, `fre`, `ger`, `por`, `spa` and other modern language folders. These may supply functional equivalents, but **cannot be used as evidence the original packages survive intact**. `pol` was not among the checked directory names.
- The original `Disc_Combining_Kits.7z` is **verified historical (8.4 MB)** but already excluded by policy; recording provenance is **not** a proposal to redistribute it. The same is true of other untrusted/excluded content.
- `BATCHER_0.3.1.EXE`, `hddosd_sample_files.7z`, `IGR_Behaviour_Modifiers.7z`, `IGR_sample_kit.7z`, and `DEBUG_AND_HALT.PPF` have independent upload date/size evidence in the listing, although the supplied Git archive provides URL *references only*.

## Preservation next steps — still research only

1. Recover authentic original package *bytes* from a verified dated source only when license and safety policies permit; compute SHA-256 and list internal member filenames, sizes and CRC/hash values.
2. For hosted files with same names but **proven different sizes**, record the current package's authenticated source, member list, version strings, and how it differs from the original listing. Do not replace blindly.
3. Compare alternate ZIP/7z packaging based on extracted payload SHA-256s and provenance, not filename similarities.
4. Classify known exclusions and copyrighted payload dependencies as **metadata-only preservation**, without hosting prohibited original Sony components.
5. Preserve original upload attribution and date separately from **tool authorship**, which cannot be inferred from uploader.

**No changes are authorized to `.research/downloads/`, published wiki files, releases, or executable code.**
