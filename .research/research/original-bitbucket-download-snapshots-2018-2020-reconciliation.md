# Original Bitbucket Downloads: preserved August 2018 page reconciled with indexed 2020 snapshot

**Research-only / PR #580. No original binary download has been recovered by this comparison.**

## Primary archived webpage, not an inferred inventory

A **saved Bitbucket Downloads HTML page** was located inside HWNJ's [Internet Archive 2020-10 wiki RAR](https://archive.org/details/backup-popstarter-documentation-stuff-wiki-from-2017-and-2020), stored as:

`ShaolinAssassin _ POPStarter Documentation & Stuff _ Downloads — Bitbucket.htm` (**106,219 bytes** as listed by Internet Archive).

- [Open this individually preserved HTML member](https://archive.org/download/backup-popstarter-documentation-stuff-wiki-from-2017-and-2020/Backup%20POPStarter%20Documentation%20%26%20Stuff%20Wiki%20%282020-10%29.rar/ShaolinAssassin%20_%20POPStarter%20Documentation%20%26%20Stuff%20_%20Downloads%20%E2%80%94%20Bitbucket.htm)
- Its rendered source contains real Bitbucket HTML upload rows `<tr class="iterable-item" id="download-…">` and per-row `<time datetime="…">` metadata. The row hyperlinks reference a preserved **Wayback 2018-08-18 02:36:28** capture path. The **2020-10** label denotes the saved-page RAR, **not** the upload list's historical capture date.
- Exact mechanically transcribed 29-row identifier/date/link dataset: [`original-bitbucket-downloads-2018-preserved.tsv`](original-bitbucket-downloads-2018-preserved.tsv). The date field contains the original HTML's time attributes verbatim; **no timezone offset is encoded**. Archive row `download-N` IDs are native Bitbucket UI identifiers, not independently validated blob IDs or checksums.

The separate [indexed original Bitbucket Downloads snapshot](original-bitbucket-download-snapshot-2020.md) previously provided **28 distinct rows** visible in the search/indexed page, including five uploads dated 2020-02-09. That source was a **sample**, never asserted to be an exhaustive full-history list.

## Exact filename-set reconciliation

| Dataset | Distinct exact filenames |
|---|---:|
| Saved original Downloads HTML with 2018-08-18 Wayback link timestamp | **29** |
| Separate indexed Bitbucket upload listing through February 2020 | **28** |
| Intersection | **23** |
| Present only in 2018 listing | **6** |
| Present only in 2020 listing | **5** |
| **Union of observed upload filenames** | **34** |

The 2018-only names were already individually recognized among the **80 canonical original wiki Git-history referenced filename forms**, but lacked Bitbucket upload size/date evidence in the merged catalog. This pass enriches those **six existing** rows with original upload metadata; it does **not** create a new 35th+ row, change the wiki source-link denominator, or import files.

### Six upload records newly confirmed from saved Bitbucket HTML

| Bitbucket download ID | Original filename | Original displayed size | Original date/time in HTML |
|---|---|---:|---|
| `1662754` | `POPStarter_USB_Quickstarter_Pack_20171027.7z` | 512.7 KB | `2017-10-27T12:07:21.839854` |
| `1662753` | `POPStarter_SMB_Quickstarter_Pack_20171027.7z` | 250.3 KB | `2017-10-27T12:07:21.837541` |
| `1662752` | `POPStarter_HDD_Quickstarter_Pack_20171027.7z` | 845.4 KB | `2017-10-27T12:07:21.835592` |
| `1656347` | `POPStarter_r13_RIP_06.zip` | 342.3 KB | `2017-10-25T09:10:58.743373` |
| `1091103` | `DISCS_POOPER.EXE` | 165.4 KB | `2016-10-06T18:59:37.606793` |
| `1013107` | `uLE_kHn_20160723.7z` | 648.0 KB | `2016-07-27T10:53:18.972708` |

All six rows list **ShaolinAssassin** as the uploader in the HTML; uploader attribution is **not software authorship**. Original date/time is reported *without interpreting local timezones*.

The **five 2020-only displayed rows** are: `uLE_kHn_20191110.zip`, `POPStarter_r13_Beta_20190605.zip`, and 2020-02-09 USB/HDD/SMB Quickstarter ZIPs. The absence of a name in the other saved page does **not** establish that an older upload was deleted; lists represent different archived times, filtering, and possibly pagination.

## What the newly verified 2018 upload metadata implies for currently hosted packages

- POPSLoader currently tracks **`POPStarter_HDD_Quickstarter_Pack_20171027.7z` at 865,736 bytes**, consistent with the 2018 Bitbucket listing's rounded **845.4 KB**. It also tracks **`POPStarter_r13_RIP_06.zip` at 350,485 bytes**, consistent with **342.3 KB** displayed in 2018. **Matching basename + rounded display size does not authenticate either hosted archive as a byte-identical original**. Their current-file hashes are independently listed in [hosted 21-archive report](original-git-hosted-patch-census.md).
- The originally listed **2017 USB and SMB Quickstarter .7z packages**, 512.7 KB and 250.3 KB respectively, **are not hosted under those filenames** in the current `.research/downloads/` set. The *newer* February 2020 USB/SMB ZIP packages are different dated distributions, not authenticated substitutes.
- `DISCS_POOPER.EXE` remains **withheld** under the preexisting catalog exclusion policy; confirming upload metadata **does not authorize distribution**. `uLE_kHn_20160723.7z` is a historical reference, not a recovered executable/archive.
- The 2018 HTML independently repeats original **`NOPAL_PATCH.7z` 226 bytes** and **`network_modules.7z` 59.0 KB** with native download row IDs **1660155** and **1663286**, and precise original HTML dates. This strengthens the date/size/provenance **discrepancy evidence**; it does **not** recover their bytes.

## Coverage and next proof needed

The earlier 80-name catalog scan covers **historical links in original wiki Git commits**, whereas this 34-name union covers **observable upload rows on two independently saved/download-indexed Bitbucket listings**. They are different denominators, and can both be correct; the latter is not proof that Bitbucket never hosted other, older/unlisted uploads.

**No original file bytes newly recovered.** In particular, the authenticated 2017 NOPAL (226 bytes) and original 2017 network (59.0 KB) packages remain unavailable. No missing screenshot bytes, copyrighted POPS emulator binaries, retail game images, or withheld/disallowed binaries were introduced. This is a metadata-only audit supporting later authentic-byte comparisons.

## Reproducibility

```bash
python3 .research/tools/audit_bitbucket_download_snapshots.py \
  .research/research/original-bitbucket-downloads-2018-preserved.tsv \
  .research/research/original-bitbucket-download-snapshot-2020.tsv \
  .research/research/original-download-catalog.tsv \
  --strict-known-inventory
```

This compares exact filename sets, checks for duplicate names and metadata anomalies, validates the 34-name union, and checks that the six 2018-only names were enriched in the preserved catalog without changing its original 80 `wiki_git` entries. To authenticate a candidate source archive, use the separate [read-only extracted-member fingerprint comparator](../tools/compare_recovered_archive_candidates.py) *after* independently lawful acquisition and source/custody review.
