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

**Pending until workflow logs validate:** per-archive decompression and SHA-256 checks, comparison with the separate generated `pfsshell`/`RadHostClient` hashes, and any discovered anomalies. Do not mark them PASS without a real GitHub Actions run.
