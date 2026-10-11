# Original Bitbucket downloads: 2018 saved HTML vs 2020 indexed listing

**Research-only inventory reconciliation dated 2026-10-11; source record preservation, not package recovery.** The [saved Bitbucket Downloads HTML captured through Wayback on 2018-08-18](<https://archive.org/download/backup-popstarter-documentation-stuff-wiki-from-2017-and-2020/Backup%20POPStarter%20Documentation%20%26%20Stuff%20Wiki%20%282020-10%29.rar/ShaolinAssassin%20_%20POPStarter%20Documentation%20%26%20Stuff%20_%20Downloads%20%E2%80%94%20Bitbucket.htm>) lives inside HWNJ's [2020-10 RAR historical wiki backup](https://archive.org/details/backup-popstarter-documentation-stuff-wiki-from-2017-and-2020). It contains **29 complete `<tr id="download-...">` records**, including uploader, displayed size, timestamp and historical download count. This is **one earlier capture**, not the entire lifetime download-history API.

Independent comparator: the [already documented later indexed Bitbucket listing](original-bitbucket-download-snapshot-2020.md) had **28 rows** from [archive.ph/PBG1V](https://archive.ph/PBG1V), including **five newer 2020 uploads** absent from the 2018 capture.

## Reconciled historical universe of independently seen upload filenames

| Measure | Count |
|---|---:|
| Distinct filenames in 2018 saved Bitbucket HTML | **29** |
| Distinct filenames in 2020 indexed sample | **28** |
| Filenames in both sources | **23** |
| Names unique to 2018 source | **6** |
| Names unique to 2020 indexed source | **5** |
| **Union of historically evidenced exact upload names** | **34** |

The **34** is a *two-list union*, not a complete multi-year download history. It supersedes any interpretation of **28** as the exhaustive list of original Bitbucket uploads. It does **not** replace the separately counted **80 unique download URLs found across wiki Git revision history**: historical *Git references* and uploads visible in two snapshots have different denominators. Nor does the union imply original package files survive in the tracked host.

### Six newly independently evidenced older upload rows

These were **absent from the later 28-row indexed listing** yet appear with original record IDs and precise HTML datetimes in the saved 2018 page:

| Earlier Bitbucket filename | Originally displayed size | Download record ID | HTML datetime (no timezone declared) | Exact-name status in current repository |
|---|---:|---|---|---|
| `POPStarter_USB_Quickstarter_Pack_20171027.7z` | 512.7 KB | `1662754` | `2017-10-27T12:07:21.839854` | Not tracked under exact name |
| `POPStarter_SMB_Quickstarter_Pack_20171027.7z` | 250.3 KB | `1662753` | `2017-10-27T12:07:21.837541` | Not tracked under exact name |
| `POPStarter_HDD_Quickstarter_Pack_20171027.7z` | 845.4 KB | `1662752` | `2017-10-27T12:07:21.835592` | Present, **865736 B** |
| `POPStarter_r13_RIP_06.zip` | 342.3 KB | `1656347` | `2017-10-25T09:10:58.743373` | Present, **350485 B** |
| `DISCS_POOPER.EXE` | 165.4 KB | `1091103` | `2016-10-06T18:59:37.606793` | Not tracked under exact name |
| `uLE_kHn_20160723.7z` | 648.0 KB | `1013107` | `2016-07-27T10:53:18.972708` | Not tracked under exact name |

**Important distinctions:** `POPStarter_HDD_Quickstarter_Pack_20171027.7z` and `POPStarter_r13_RIP_06.zip` are already hosted under those exact names, but **their historical byte identity has not been independently authenticated against the original Bitbucket objects**. The 2017 USB/SMB Quickstarter 7z archives, `DISCS_POOPER.EXE`, and `uLE_kHn_20160723.7z` are **not hosted under those exact names**. That does **not** prove the tools do not survive elsewhere or in different archive formats. Original DISCS_POOPER executable is uninspected and should **not** be published without safety, licensing and provenance review.

The five **2020-only** exact names in the later sample are `uLE_kHn_20191110.zip`, `POPStarter_r13_Beta_20190605.zip`, `POPStarter_SMB_Quickstarter_Pack_20200209.zip`, `POPStarter_HDD_Quickstarter_Pack_20200209.zip`, `POPStarter_USB_Quickstarter_Pack_20200209.zip`.

## All 29 saved 2018 Bitbucket download entries

`Original datetime` reproduces the HTML `<time datetime>` string exactly; **the timezone is not stated**. `Current hosted exact name` is derived from the actual **23 tracked `.research/downloads/` file paths on 2026-10-11**, not from historical search snippets. Matching a name/size is **not** a payload SHA-256 match. The original listing's historical download counters represent the saved page's **2018 snapshot**, not cumulative downloads now.

| Original file name | Bitbucket record | HTML original datetime | Displayed size | Current hosted exact name | Also in 2020 sample |
|---|---|---|---:|---|---|
| `CHEATS.TXT` | `1663577` | `2017-10-27T18:29:19.292563` | 1.1 KB | Yes (1052 B) | Yes |
| `network_modules.7z` | `1663286` | `2017-10-27T16:10:07.826144` | 59.0 KB | Yes (93934 B) | Yes |
| `POPStarter_USB_Quickstarter_Pack_20171027.7z` | `1662754` | `2017-10-27T12:07:21.839854` | 512.7 KB | No | **Only 2018 listing** |
| `POPStarter_SMB_Quickstarter_Pack_20171027.7z` | `1662753` | `2017-10-27T12:07:21.837541` | 250.3 KB | No | **Only 2018 listing** |
| `POPStarter_HDD_Quickstarter_Pack_20171027.7z` | `1662752` | `2017-10-27T12:07:21.835592` | 845.4 KB | Yes (865736 B) | **Only 2018 listing** |
| `NOPAL_PATCH.7z` | `1660155` | `2017-10-26T12:12:54.201193` | 226 bytes | Yes (188 B) | Yes |
| `FORCEPAL_PATCH.7z` | `1660154` | `2017-10-26T12:12:54.199410` | 234 bytes | Yes (234 B) | Yes |
| `Disc_Combining_Kits.7z` | `1659795` | `2017-10-26T08:46:56.569216` | 8.4 MB | No | Yes |
| `POPStarter_r13_RIP_06.zip` | `1656347` | `2017-10-25T09:10:58.743373` | 342.3 KB | Yes (350485 B) | **Only 2018 listing** |
| `DS3_modules_USB_20171017.7z` | `1640473` | `2017-10-17T19:21:21.182322` | 13.8 KB | Yes (14089 B) | Yes |
| `DS3_modules_BT_20171017.7z` | `1640472` | `2017-10-17T19:21:21.180277` | 17.7 KB | Yes (18149 B) | Yes |
| `BATCHER_0.3.1.EXE` | `1139744` | `2016-11-28T12:34:29.917229` | 23.5 KB | No | Yes |
| `pfsshell-0.2a.7z` | `1116713` | `2016-11-03T18:04:01.887285` | 62.6 KB | Yes (64085 B) | Yes |
| `RadHostClient_1.8a.7z` | `1116709` | `2016-11-03T17:55:59.700348` | 333.0 KB | Yes (341002 B) | Yes |
| `CUE2POPS_2.3.7z` | `1116236` | `2016-11-03T08:53:44.217166` | 30.0 KB | No | Yes |
| `hddosd_sample_files.7z` | `1093091` | `2016-10-09T20:48:02.482575` | 18.5 KB | No | Yes |
| `DISCS_POOPER.EXE` | `1091103` | `2016-10-06T18:59:37.606793` | 165.4 KB | No | **Only 2018 listing** |
| `IGR_textures_-_Spanish_pack.7z` | `1080701` | `2016-09-27T16:05:58.447269` | 172.0 KB | No | Yes |
| `IGR_textures_-_Portuguese_pack.7z` | `1080700` | `2016-09-27T16:05:58.446603` | 216.9 KB | No | Yes |
| `IGR_textures_-_Polish_pack.7z` | `1080699` | `2016-09-27T16:05:58.445918` | 459.9 KB | No | Yes |
| `IGR_textures_-_French_pack.7z` | `1080698` | `2016-09-27T16:05:58.445196` | 623.3 KB | No | Yes |
| `IGR_textures_-_Chinese_pack.7z` | `1080697` | `2016-09-27T16:05:58.443527` | 63.4 KB | Yes (64941 B) | Yes |
| `IGR_textures_-_English_pack.7z` | `1080648` | `2016-09-27T15:39:40.777652` | 843.8 KB | No | Yes |
| `IGR_textures_-_German_Pack.7z` | `1080647` | `2016-09-27T15:39:13.292085` | 117.0 KB | No | Yes |
| `IGR_Behaviour_Modifiers.7z` | `1080646` | `2016-09-27T15:38:49.918962` | 1.0 KB | No | Yes |
| `Compatibility_Modes.7z` | `1080645` | `2016-09-27T15:38:34.146241` | 882 bytes | No | Yes |
| `IGR_sample_kit.7z` | `1080367` | `2016-09-27T12:51:23.754503` | 62.9 KB | No | Yes |
| `DEBUG_AND_HALT.PPF` | `1077604` | `2016-09-24T13:44:18.778844` | 73 bytes | No | Yes |
| `uLE_kHn_20160723.7z` | `1013107` | `2016-07-27T10:53:18.972708` | 648.0 KB | No | **Only 2018 listing** |

Machine-readable raw record extraction: [`original-bitbucket-downloads-2018.tsv`](original-bitbucket-downloads-2018.tsv), including snapshot download counters. This sheet preserves **observed original text values** and current-host checks but contains no executable payload.

## Current recovery priorities changed by this source

1. **2017-10-27 SMB/USB Quickstarter 7z archives** are now independently evidenced with their own separate upload IDs/timestamps and original displayed sizes (**250.3 KB**, **512.7 KB**). Look for authenticated copies; do not substitute the later February 2020 ZIPs, which have different names/containers and no proven byte-equivalence.
2. **2016-10-06 DISCS_POOPER.EXE** (**165.4 KB**) and **2016-07-27 uLE_kHn_20160723.7z** (**648.0 KB**) are additional exact-name gaps. Classify as historical metadata-only until their provenance and redistribution safety are assessed. The 2016 package name is not the separate `uLE_kHn_20191110.zip` added in 2020.
3. Continue prioritizing **2017-10-26 NOPAL_PATCH.7z (226 B)** and **2017-10-27 network_modules.7z (59.0 KB)** because current same-name hosted packages differ demonstrably in archive byte lengths. [Original upload IDs/S3 storage-object research](original-bitbucket-download-object-provenance.md) identifies specific original objects but **no recoverable payload**.
4. Full archive-media restoration still requires actual authenticated file bytes, original-date attribution, per-member checksums, safety and copyright review; **none was imported or published** during this audit.

**Safety boundary:** no executable or archive file changed, no original media imported, no public site edited, no Sony engine/BIOS materials distributed.
