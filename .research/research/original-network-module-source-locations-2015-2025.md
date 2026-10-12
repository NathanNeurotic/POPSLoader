# POPStarter network-module archives: dated primary-source URL crosswalk (2015–2025)

**2026-10-11; research follow-up on `master` after merged PR #580.** These are independently located developer/forum/hosting references. They do **not** supply downloaded archive bytes and do **not** authenticate a build against a historic original. This file records stable source names, source dates and retrieval limitations so researchers do not mistake similarly purposed archives for identical packages.

## New primary-source locator evidence

| Evidence / date | Package name | Source / direct URL | Metadata actually available | What remains unknown |
|---|---|---|---|---|
| **2015-10-23**, krHACKen Beta 8 SMB announcement; historic first forum post retained/updated in October 2017 | `POPStarter_Net_Modules_for_mc0.zip` | [krHACKen's original Metagames download hyperlink](https://aybabtu.chez.com/kHn/SOFTWARES/POPStarter_Net_Modules_for_mc0.zip), visible as link `POPStarter_Net_Modules_for_mc0.zip` in [his preserved thread post #1](https://www.metagames-eu.com/forums/playstation-2/popstarter-revision-13-a-134569.html) and [2015 Beta 8 announcement](https://www.metagames-eu.com/forums/playstation-2/popstarter-revision-13-a-20-134569.html). | Developer names the original separately distributed package for network drivers plus editable `IPCONFIG.DAT` / `SMBCONFIG.DAT`. The current endpoint returned a **502 error** in this investigation. | Authentic file bytes, archive size, exact member hashes, license, and whether the current endpoint has an archived capture. |
| **2016-09-21 02:02:38**, MediaFire upload metadata | `POPSTARTER.zip` | [MediaFire file ID `oa21igh1abw531b`](https://www.mediafire.com/file/oa21igh1abw531b/POPSTARTER.zip/file); developer-linked on [krHACKen's PSX-Place first post](https://www.psx-place.com/threads/popstarter.19139/) and [resource page](https://psx-place.com/resources/popstarter.683/). | MediaFire identifies it as a ZIP, **79.81 KB** display size, uploaded **2016-09-21 02:02:38**, with upload region Poland. The package is described by the forum as *network modules for the memory card*. The dynamic download redirect did **not** yield verified file bytes using the available retrieval client. | Exact size, member manifest, SHA-256, original author/upstream provenance, and whether its bytes match the 2015 ZIP or later attachment. |
| **PSX-Place first post started 2018-04-29**, but first post **last edited 2026-08-24**, so attachment introduction date is not established from this page alone | `POPSTARTER_MC-Network.zip` | [KrHACKen's PSX-Place thread first-post attachment list](https://www.psx-place.com/threads/popstarter.19139/#post-134186). | Attachment is visibly labeled **79.8 KB**. This agrees at the forum/display precision with the MediaFire 2016 archive's **79.81 KB**, but is **not** a byte fingerprint. | Whether the attachment was uploaded in 2018, added at a later edit, or is the same ZIP as the MediaFire link; exact bytes and member hashes. |
| **2025-01-25**, forum poster jolek stated they added network modules + BDM Assault | `POPSTARTER_MC-Network_BDM.7z` | [jolek's dated post #348](https://psx-place.com/threads/popstarter.19139/page-18) pointing to the [first-post attachment list](https://www.psx-place.com/threads/popstarter.19139/#post-134186). | Forum attachment displays **91.7 KB**. The *current hosted* `.research/downloads/network_modules.7z` is **93,934 B**, which rounds to **91.7 KiB**—only a display-size-level resemblance. The 2025 forum post explicitly dates the *addition* of the BDM attachment; no earlier introduction date is assumed. | Whether the forum attachment bytes and current repository 7z are identical; any relationship to the missing **2017-10-27** 59.0 KB original; actual forum attachment's SHA-256. |
| **2017-10-27**, Shaolin Assassin Bitbucket indexed upload | `network_modules.7z` | [Preserved Bitbucket download listing](https://archive.ph/PBG1V). | **59.0 KB** displayed, uploader Shaolin Assassin. The 93,934 B hosted namesake **cannot be the same archive bytes** as the indexed original. | Authentic 2017 original archive data, contents, version strings, and 2015/2016 source comparison. |
| **2020-02-09** historical Bitbucket-listed upload | `POPStarter_SMB_Quickstarter_Pack_20200209.zip` | [Preserved upload listing](https://archive.ph/PBG1V) and [hosted cross-package hash audit](original-git-network-quickstarter-overlap.md). | Existing repository ZIP SHA-256 `94b432f6665132cd6862ae7465a2dc66807084f0c71c686899abe1f453c405d8`; independently decompressed six network drivers **match current hosted network 7z member SHA-256 values 6/6**. | Their original driver source dates and relationship to the missing 2017 Bitbucket package. |

## Independent Wayback URL availability check (2026-10-11)

The Internet Archive availability API was queried for the complete original URLs, **not** for arbitrary filenames. Its most-recent/closest endpoint produced:

| Original URL tested | Closest snapshot in availability API | Direct raw-memento inspection |
|---|---|---|
| `https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/NOPAL_PATCH.7z` | No closest capture returned | **No archived 2017 patch verified** |
| `https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/network_modules.7z` | No closest capture returned | **No archived 2017 network package verified** |
| `https://aybabtu.chez.com/kHn/SOFTWARES/POPStarter_Net_Modules_for_mc0.zip` | [2025-12-28 HTTP 200](https://web.archive.org/web/20251228131325id_/http://aybabtu.chez.com/kHn/SOFTWARES/POPStarter_Net_Modules_for_mc0.zip) | **`text/html` / 'Pages Persos Chez.com' blocked-account parking document**, **not a ZIP**, when opened in raw `id_` form |

The archive lookup returns nearest *available* captures only; it is **not** an exhaustive CDX/WARC history query and the empty entries do not prove never archived. The 2025 HTTP 200 is a *false-positive for binary recovery*, just as the screenshot URLs' parked Chez.com HTTP 200 mementos were. No checksum or member manifest can be computed from a parking page. Preserve the 2015 ZIP path as historical evidence but **do not mark this 2025 capture as an archive copy**.

## Reproducible retrieval outcomes and safeguards

- The [original developer-linked 2015 ZIP endpoint](https://aybabtu.chez.com/kHn/SOFTWARES/POPStarter_Net_Modules_for_mc0.zip) was found by following the named link on krHACKen's preserved Metagames first post. The available retrieval client returned **502**, not ZIP bytes.
- The [2016 MediaFire item](https://www.mediafire.com/file/oa21igh1abw531b/POPSTARTER.zip/file) rendered dated upload metadata and displayed an ephemeral download link, but attempting to follow the link returned a **download-repair redirect/error** rather than a complete authenticated ZIP stream. Neither a checksum nor a member listing was calculated for this external candidate.
- The PSX-Place attachment listings are independently viewable, but the read-only retriever did not expose *attached archive contents* for hashing in this investigation. Do not infer identity from equal displayed KB counts, filename, or forum association.
- The [2025-01-25 announcement](https://psx-place.com/threads/popstarter.19139/page-18) establishes that `POPSTARTER_MC-Network_BDM.7z` is a **later posted BDM-specific package**, making it especially unsafe to label a same-size hosted 7z as the original 2017 `network_modules.7z` without comparing full bytes.

## Custody and classification

**Original-current archive-byte status: no new historical file recovered.** The present 93,934 B network 7z is still the one verified by [full 12-member CRC + 6/6 driver SHA-256 audit](original-git-network-quickstarter-overlap.md). The 2017 59.0 KB archive remains absent. `NOPAL_PATCH.7z` (2017 226 B) remains separately absent, per [patch conflict](original-git-hosted-patch-archive-inspection.md). None of these records permits distribution of Sony's copyrighted POPS emulator files; a future archive candidate must be inspected for excluded contents before any import.

**Future authentic-byte acceptance criteria** for each externally obtained package: preserved original URL/redirect chain and source dates, full byte length, SHA-256 of whole archive, validated file type, archive CRC/decompression test, complete member inventory with per-member hashes, absence of prohibited Sony emulator content, and separate matching comparisons against current repository blobs. Historical identity requires either an original source/checksum or equally credible dated chain of custody, not just package similarity.

**Next concrete candidates:** developer-linked 2015 ZIP; independently uploaded 2016 MediaFire ZIP; 2018–2026 first-post `POPSTARTER_MC-Network.zip`; explicitly added January 2025 BDM ZIP; original 2017 Bitbucket package. Preserve each as a separate source row until actual byte evidence allows a merge.

## Candidate comparison workflow — tested but does not imply a new download

A new [read-only forensic candidate comparator](../tools/compare_recovered_archive_candidates.py) accepts **local** ZIP/7z files and records a complete SHA-256 for each archive plus each uniquely named member. It validates the stored CRC and decompressed length of each file; it can compare two package manifests by case-insensitive basename. It rejects unsupported/oversized archives, suspicious member paths, duplicate basenames, and explicitly identified Sony POPS/BIOS member names **before unpacking any archive data**. It reports metadata/hash results only; it does not save or run contents.

Example comparison of two **already tracked and permitted** archives, not retrieved historical candidates:

```bash
python3 .research/tools/compare_recovered_archive_candidates.py \
  .research/downloads/network_modules.7z \
  .research/downloads/POPStarter_SMB_Quickstarter_Pack_20200209.zip \
  --expect-identified-matches 6
```

[Successful GitHub Actions run #38167061060](https://github.com/NathanNeurotic/POPSLoader/actions/runs/38167061060) reported **8 common member basenames: 6 exact SHA-256 matches** (`poweroff.irx`, `ps2dev9.irx`, `ps2ip.irx`, `ps2smap.irx`, `smbman.irx`, `smsutils.irx`) and **2 SHA-256 differences** (`ipconfig.dat`, `smbconfig.dat`). This is a second general-purpose method corroborating the dedicated current-driver payload verifier. No 2015/2016/2017 original was present in that test.

**Safeguard:** a file lacking a recognized excluded filename may still be proprietary or unsafe. Do not use this tool's acceptance alone as a permission to upload, distribute or mark an external candidate authentic. It identifies existing files and decompression integrity, not licensing or original authorship.
