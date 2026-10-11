# 2017 Bitbucket download upload identifiers and expired S3 redirect evidence

**Research-only source-custody continuation on 2026-10-11, after PR #580 was merged.** No binary download, patch execution, screenshot substitution, site modification or release change.

## Newly extracted source records

A [saved Bitbucket Downloads HTML page](<https://archive.org/download/backup-popstarter-documentation-stuff-wiki-from-2017-and-2020/Backup%20POPStarter%20Documentation%20%26%20Stuff%20Wiki%20%282020-10%29.rar/ShaolinAssassin%20_%20POPStarter%20Documentation%20%26%20Stuff%20_%20Downloads%20%E2%80%94%20Bitbucket.htm>) from the [Internet Archive 2020-10 RAR backup](https://archive.org/details/backup-popstarter-documentation-stuff-wiki-from-2017-and-2020) contains original `<tr id="download-…">` rows, full `<time datetime>` values, names and upload sizes.

| Listed original file | Bitbucket download record ID | Precise original timestamp as stored in HTML (timezone unspecified) | Listed size | Attribution displayed by Bitbucket |
|---|---|---|---|---|
| `NOPAL_PATCH.7z` | `1660155` | `2017-10-26T12:12:54.201193` | **226 bytes** | ShaolinAssassin (listed uploader) |
| `FORCEPAL_PATCH.7z` | `1660154` | `2017-10-26T12:12:54.199410` | **234 bytes** | ShaolinAssassin (listed uploader) |
| `network_modules.7z` | `1663286` | `2017-10-27T16:10:07.826144` | **59.0 KB** | ShaolinAssassin (listed uploader) |

Unlike search-result snippets with dates only, these identifiers and timestamp fractions were read from the preserved **original HTML row fields**. They identify uploads and potential archival search targets; they do **not** authenticate the current similarly named repository files, nor prove who developed their contents.

## Redirect-derived Bitbucket storage object paths

Replaying Bitbucket's original download links via Wayback produced a redirect to **`bbuseruploads.s3.amazonaws.com`**, revealing a bucket path and individual object keys. Only the **non-signed stable object paths** are recorded below. **Do not retain or publish historical signed query strings, access identifiers, temporary security tokens or URL signatures.** Those credentials were already expired at the archived capture time and are not the recovered payloads.

Common bucket-relative prefix:

```text
26c8cc2f-7b34-40b9-973a-6a03630efa0a/downloads/
```

| Target | Storage object identifier | Stable object-relative suffix, no signed parameters | Wayback replay result |
|---|---|---|---|
| `NOPAL_PATCH.7z` | `80f4f1e5-d23a-42d2-a82e-afab9a7113e2` | `80f4f1e5-d23a-42d2-a82e-afab9a7113e2/NOPAL_PATCH.7z` | [2021-11-19 capture](https://web.archive.org/web/20211119220411id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/NOPAL_PATCH.7z) redirects to a now-expired presigned S3 request; raw replay returns **HTTP 403, XML `AccessDenied: Request has expired`**, **not a 7z payload**. |
| `network_modules.7z` | `d88fc1eb-9651-4b8c-90be-cdf80720136a` | `d88fc1eb-9651-4b8c-90be-cdf80720136a/network_modules.7z` | [2024-02-28 capture](https://web.archive.org/web/20240228100926id_/https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/network_modules.7z) redirects to a presigned S3 object URL. Raw replay ends in **HTTP 404 Wayback “not archived”** for the S3 target; **no package bytes**. |

Availability requests against each stable non-signed `https://bbuseruploads.s3.amazonaws.com/` path returned **no nearest available capture**. As always, this is an index spot check, not exhaustive CDX/WARC proof that no capture exists.

### Why this matters for authenticity

- The **original 2017 226-byte NOPAL** archive cannot be the currently hosted **188-byte `NOPAL_PATCH.7z`**. The hosted member's *Unhook IGR's ELF LDR* label and the [2020 developer PATCH_9 post](original-git-hosted-patch-archive-inspection.md) suggest a later IGR-purpose file has been stored under the older name; without the original 226 bytes, do not claim equivalence.
- The **2017 59.0 KB** network archive cannot be byte-identical to the **current 93,934-byte** `network_modules.7z`; the latter's 12 members and its six 2020 SMB ZIP-matching IRXs **have** been fully integrity verified, but that is different evidence.
- The **FORCEPAL** upload was recorded in the preserved HTML less than two milliseconds before the NOPAL upload. The existing hosted FORCEPAL also happens to be 234 bytes, but equal size and nearby dates **do not** prove byte identity.
- Historical S3 object keys and Bitbucket record numbers help avoid mixing artifacts with the same names across versions; no original archive hash or contents has been retrieved.

## Suggested next source paths

1. Search archive indexes for the exact **Bitbucket record IDs** `1660155` and `1663286`, separately from the stable S3 object IDs, including captures of redirected objects *without* expired query strings.
2. Check trustworthy uploader/developer source mirrors for explicitly dated `2017-10-26` and `2017-10-27` copies. Demand full archive SHA-256, size, decompression check and member hashes.
3. Keep proposed corrective public download descriptions on hold until the original 2017 NOPAL patch and current 188-byte candidate can be forensically compared. No rename, package replacement or function claim is authorized here.

**Recovery status unchanged: original 2017 archives not recovered.** This is new provenance evidence, not an archived binary recovery.
