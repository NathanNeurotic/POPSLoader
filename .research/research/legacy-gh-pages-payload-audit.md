# Legacy Pages-only archives — complete checksum + 7z member audit

**Investigation updated 2026-10-11.** Scope: the **17 exact preserved legacy sidecars** catalogued in [legacy-gh-pages-inventory.tsv](legacy-gh-pages-inventory.tsv) and existing `gh-pages/downloads/SHA256SUMS.txt`. The preservation decision is **retain existing bytes**, not to republish them as independently authenticated 2016/2017 Bitbucket originals or copy them into the current tracked Downloads generator.

## Evidence status before checking decompressed contents

The legacy source inventory pins **Git blob SHA-1 and size** for 17 retained Pages-only files (14 `.7z` archives, 2 text notices and 1 favicon). They have **no byte-identical blobs** in the generator's existing `.research/downloads/` paths as of this comparison. Source identity *within the current Pages repository* is therefore known, but many are not authenticated against the lost original download-host payload.

The pre-existing `downloads/SHA256SUMS.txt` covers all **14** preserved `.7z` files, plus **two generator-owned archives** (`pfsshell-0.2a.7z` and `RadHostClient_1.8a.7z`) and **one historical withheld entry**, `DISCS_POOPER.BAT.7z`. Since that withheld file has been removed from live Pages by PR #584, this checksum-list entry is **historical metadata, not an indication of available/safe downloads**. The checksum document predates the current publication policy; do **not** interpret it as a live 17-file download catalog.

## Historical name and provenance crosswalk

| Preserved archive | Original Bitbucket wiki Git-url catalog evidence | Further authentication status |
|---|---|---|
| `BATCHER_0.3.1.EXE.7z` | No **exact matching name** in the 80-row catalog; related `BATCHER_0.3.1.EXE` exists | Exact dated archive format and author not authenticated |
| `CUE2POPS_2.3.7z` | Cataloged **possible variant** of `CUE2POPS_2.3.zip`, originally indexed 2016-11-03 at 30.0 KB | Original 7z identity and decompressed member-byte equivalence to ZIP not verified |
| `Compatibility_Modes.7z` | Cataloged **possible variant** of `Compatibility_Modes.zip`, 2016-09-27 at 882 bytes | Equal rounded/exact size is not a full SHA identity; original payload unverified |
| `DEBUG_AND_HALT.7z` | No exact name in catalog; only a `DEBUG_AND_HALT.PPF` reference | Source/patch intent requires independent verification |
| `IGR_Behaviour_Modifiers.7z` | Exact name appears as historical reference, 2016-09-27, ~1.0 KB | Existing Pages archive SHA/CRC is not an original Bitbucket checksum |
| `IGR_sample_kit.7z` | Exact name appears as historical reference, 2016-09-27, ~62.9 KB | Existing Pages archive SHA/CRC is not an original Bitbucket checksum |
| `IGR_textures_-_English_pack.7z` | Exact, historical 2016-09-27 reference, 843.8 KB | Historical bytes and license not independently verified |
| `IGR_textures_-_French_pack.7z` | Exact, historical 2016-09-27 reference, 623.3 KB | Historical bytes and license not independently verified |
| `IGR_textures_-_German_Pack.7z` | Exact, historical 2016-09-27 reference, 117.0 KB | Historical bytes and license not independently verified |
| `IGR_textures_-_Polish_pack.7z` | Exact, historical 2016-09-27 reference, 459.9 KB | Historical bytes and license not independently verified |
| `IGR_textures_-_Portuguese_pack.7z` | Exact, historical 2016-09-27 reference, 216.9 KB | Historical bytes and license not independently verified |
| `IGR_textures_-_Spanish_pack.7z` | Exact, historical 2016-09-27 reference, 172.0 KB | Historical bytes and license not independently verified |
| `hddosd_sample_files.7z` | Exact, historical 2016-10-09 reference, 18.5 KB | Historical bytes and license not independently verified |
| `uLE_kHn_20191110_2.7z` | No exact name in 80-row source; a differently named `uLE_kHn_20191110.zip` is documented | Do not infer same-version byte equivalence |

## Automated testing and remaining limits

[Read-only archive verifier](../tools/audit_legacy_archive_payloads.py) checks each retained Pages-only file directly on an independently checked-out `gh-pages` tree during [Historical network archive byte verification](../../.github/workflows/research-network-driver-integrity.yml). It compares the immutable Git blob ID and stored size, SHA-256 against the historical public checksum listing, tests **all 14 7z compressed streams/CRCs** without executing or extracting a member to the working directory, limits decoded member sizes, inventories executable/nested filename **counts only**, and verifies the two generated ZIP/7z name references against the historical checksum list. The three retained non-archive sidecars are separately checked against the pinned Git object identity.

**Not equivalent to** independent malware scanning, external original source recovery, chain-of-custody authentication, absence of dangerous archive payloads, or a rights review. Historical source evidence appears above. Archives with software executables or nested containers must not be promoted into the official curated downloads without separate review.

## Verified hardware-independent integrity results (GitHub Actions, 2026-10-11)

[GitHub Actions run #38178795652](https://github.com/NathanNeurotic/POPSLoader/actions/runs/38178795652), job `audit-published-legacy-archive-payloads`, checked out the **current published `gh-pages` files independently**. It passed **14/14 whole-archive SHA-256 comparisons**, **14/14 full 7-Zip decompression/CRC tests**, Git-blob identity checks on all 17 retained sidecars, the retained security notice/favicons, and both generator-owned archival references in historical `SHA256SUMS.txt`.

**Corrected member census:** **160 actual file members**, *excluding* **44 zero-byte folder-directory records** reported in the 7z listings. The first prototype incorrectly counted all **204** path records as files; the [corrected scanner](../tools/audit_legacy_archive_payloads.py) excludes both `Folder = +` records and implicit zero-byte directory entries. This was independently reconciled against the existing member-level hash comparison tool and rerun to PASS. Archive tests never executed any ELF/EXE/script.

| Archive | Real file members | Full SHA-256 + decompression/CRC | Executable or nested-extension members (name only) |
|---|---:|---|---:|
| `BATCHER_0.3.1.EXE.7z` | 1 | PASS | 1 |
| `CUE2POPS_2.3.7z` | 3 | PASS | 3 |
| `Compatibility_Modes.7z` | 8 | PASS | 0 |
| `DEBUG_AND_HALT.7z` | 1 | PASS | 0 |
| `IGR_Behaviour_Modifiers.7z` | 9 | PASS | 0 |
| `IGR_sample_kit.7z` | 11 | PASS | 0 |
| `IGR_textures_-_English_pack.7z` | 46 | PASS | 0 |
| `IGR_textures_-_French_pack.7z` | 30 | PASS | 0 |
| `IGR_textures_-_German_Pack.7z` | 5 | PASS | 0 |
| `IGR_textures_-_Polish_pack.7z` | 29 | PASS | 0 |
| `IGR_textures_-_Portuguese_pack.7z` | 7 | PASS | 0 |
| `IGR_textures_-_Spanish_pack.7z` | 6 | PASS | 0 |
| `hddosd_sample_files.7z` | 3 | PASS | 0 |
| `uLE_kHn_20191110_2.7z` | 1 | PASS | 1 |
| **Total** | **160** | **14/14 PASS** | **5 filename-flagged members** |

### Exactly two complete cross-container payload equivalences

The [same successful job](https://github.com/NathanNeurotic/POPSLoader/actions/runs/38178795652) used the strict `--require-same-member-set` condition to compare against existing `.research/downloads/` ZIPs. These are **member-name and decompressed-byte SHA-256 equal**, but the compressed **ZIP and 7z archives themselves have different bytes and containers**.

1. `gh-pages/downloads/CUE2POPS_2.3.7z` vs `.research/downloads/CUE2POPS_2.3.zip`: **3/3 identical member files**: `bulk_cue2pops.bat`, `cue2pops_2_3.exe`, `pops2cue.exe`; no candidate-only/reference-only files.
2. `gh-pages/downloads/Compatibility_Modes.7z` vs `.research/downloads/Compatibility_Modes.zip`: **8/8 identical member files**, `PATCH_1.BIN` through `PATCH_7.BIN` plus `README.TXT`; no candidate-only/reference-only files.

This **upgrades cross-format *content equivalence*** for exactly two preservation pairs. It does **not** authenticate either ZIP/7z against a 2016 Bitbucket original date, determine licensing/safety, or justify copying the legacy package into curated downloads.

### Primary-source provenance categories

- **9** legacy .7z names have an **exact name entry** in the original wiki-Git catalog: the six listed IGR texture language packs, IGR sample kit, IGR Behaviour Modifiers, and HDDOSD sample files.
- **2** have *possible ZIP/7z format-variant evidence* and now *confirmed cross-format decompressed contents*: CUE2POPS 2.3 and Compatibility Modes.
- **3** lack an exact `.7z` name in the canonical catalog: BATCHER `0.3.1.EXE.7z`, DEBUG_AND_HALT `.7z`, and `uLE_kHn_20191110_2.7z`. Related alternative filenames exist but cannot establish exact archive provenance.

**Policy:** leave 17 legacy-only sidecars preserved under their existing identities. Do not add, migrate, remove, or promote any legacy executable/archive into newly recommended/generated download packages based on these integrity results alone. The historical manifest's checksum for the *withheld* `DISCS_POOPER.BAT.7z` remains a historical record and is **not a public availability claim**.

