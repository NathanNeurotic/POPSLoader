# Internet Archive saved Bitbucket wiki RARs — image-ID coverage audit (2026-10-11)

**Scope:** research-only, draft PR #580. Read-only inspection of **Internet Archive's archive member listings**, *not* complete downloads of the RAR bytes and not an integrity certification for each RAR member. No assets were imported, no publication content was changed, and no proprietary Sony content was inspected or redistributed.

## Primary-source package metadata

Archive.org item by HWNJ, originally identified in [PSX-Place February 2023 forum preservation post](https://www.psx-place.com/threads/popstarter.19139/page-12):
[Internet Archive item: backup-popstarter-documentation-stuff-wiki-from-2017-and-2020](https://archive.org/details/backup-popstarter-documentation-stuff-wiki-from-2017-and-2020).

The item exposes two historical RARs:

| IA filename | Internet Archive listed bytes | IA-provided MD5 | IA-provided SHA-1 | Listed direct archive entries |
|---|---:|---|---|---:|
| `Backup POPStarter Documentation & Stuff Wiki (2017-10).rar` | **25,735,078** | `c64f1bfab153189460fb29ece73efca3` | `5b3e27f48690940520661107244085b649150e11` | **378** |
| `Backup POPStarter Documentation & Stuff Wiki (2020-10).rar` | **73,550,116** | `d263493687fc1ba197472bad9af7a55a` | `7ca94c492498131f46fc3a11a1eec3b3ddafaa3a` | **1,172** |

The MD5/SHA-1 values and original package sizes above come **from the Internet Archive item metadata**, **not independently recomputed from downloaded RAR bytes**. The RAR direct-entry counts are from the online `view_archive.php` member listings, rather than archive extraction/CRC tests:

- [2017 RAR member directory](https://ia601600.us.archive.org/view_archive.php?archive=/7/items/backup-popstarter-documentation-stuff-wiki-from-2017-and-2020/Backup%20POPStarter%20Documentation%20%26%20Stuff%20Wiki%20%282017-10%29.rar)
- [2020 RAR member directory](https://ia601600.us.archive.org/view_archive.php?archive=/7/items/backup-popstarter-documentation-stuff-wiki-from-2017-and-2020/Backup%20POPStarter%20Documentation%20%26%20Stuff%20Wiki%20%282020-10%29.rar)

## Member filename census

Extracting the **displayed member-directory rows only** from the two online archive listings gives:

| Member extension | 2017 directory | 2020 directory |
|---|---:|---:|
| `.htm` | 32 | 173 |
| `.css` | 93 | 262 |
| `.js` | 241 | 484 |
| `.png` | 12 | 181 |
| `.jpg` | 0 | 18 |
| `.gif` | 0 | 46 |
| `.svg` | 0 | 8 |
| **TOTAL** | **378** | **1,172** |

The 2017 folder-save package mostly contains saved page HTML, CSS and JavaScript, with twelve generic PNG assets. The 2020 snapshot includes substantially more media *file entries*, but most are toolbar/Wayback/application graphics reused across many page-save folders; do not count raw extensions as unique original Bitbucket screenshots.

### Specific original numeric-ID comparison against repository assets

Filtering 2020 image file paths with a numeric Bitbucket-style basename prefix `<6–11 digit ID>-` and extensions JPG/JPEG/GIF/PNG produced **52 direct image filename occurrences representing 29 distinct numeric source IDs**. Comparing those 29 IDs to the numeric prefixes of **124 tracked `.research/assets/` files** on POPSLoader `master` (121 distinct numeric IDs) yielded:

- **29/29** archive image IDs **already represented** among the locally tracked IDs.
- **0 newly represented Bitbucket numeric image IDs** from these actual 2020 JPG/PNG/GIF entries.
- This is **a source-ID/filename presence check only**, not a SHA-256 comparison of actual image bytes, and does **not** prove the 2020 image bytes are otherwise identical to the recovered files.

The pre-existing final-HEAD **19 missing original numeric image IDs** and the **34 full-history unmatched IDs** are therefore **not reduced** by the verified 2020 image *filename* inventory. Other saved-HTML references remain subject to separate asset-byte retrieval.

## False positive trap: four missing numeric IDs appear only as Wayback HTML members

The 2020 RAR's saved page subdirectories contain **four members** whose **filename stems** mention historical missing Bitbucket image IDs but whose **actual extension is `.htm`**, not the historic image's JPG/PNG extension:

| Original missing image ID | File in 2020 RAR | Actual source inspected |
|---|---|---|
| `3117688129` | `igr-textures …_files/3117688129-beztytuu.htm` | Content starts with `<!DOCTYPE html><html lang="en"><head><title>Wayback Machine</title>` |
| `270560112` | `ps1-widescreen-codes …_files/270560112-16h0lcg.htm` | Same Wayback Machine HTML document opening, not PNG/JPG |
| `3801833563` | `ps1-widescreen-codes …_files/3801833563-2md7xs.htm` | Same Wayback Machine HTML document opening |
| `4286767539` | `ps1-widescreen-codes …_files/4286767539-2n0oweq.htm` | Same Wayback Machine HTML document opening |

All four members were opened through the Internet Archive **individual archive-member URLs** exposed by the 2020 RAR listing. The returned content is Wayback Machine HTML (roughly 94.7 KB per page), not an authentic image file. These entries must **not be renamed as .png/.jpg or counted as recovered screenshots**.

The old recovery log's occasional PNG magic for external attempted URLs of IDs `270560112` and `4286767539` is **separate and unresolved evidence**; it cannot be conflated with these distinct `.htm` files from the RAR. A URL that includes the correct numeric ID is not enough to establish artifact identity.

## Provenance/retrieval limitations and next steps

- Archive.org **metadata and online archive directories were accessible** through an independent read path. The original full RAR payloads (25.7 MB and 73.6 MB) were **not downloaded into the working environment**, so reported sizes/hash metadata are **host-supplied**, not newly computed; the listed member CRCs were not independently tested.
- A source ID matching a currently tracked PNG/JPEG identifies an **image record**, not necessarily identical bytes. A genuine recovered screenshot needs actual content signatures, dimensions, SHA-256 and source capture evidence.
- The archive directory names show that these are **saved web-page snapshots**, not a complete Bitbucket `/images/` or `/downloads/` binary export. This audit provides **negative evidence only for the listed archive members**, not for external Wayback captures or yet-undiscovered mirrors.
- If the maintainer later authorizes the 2017/2020 RARs for local full-byte auditing, download through a reputable original archive.org link, verify metadata cryptographic digests, scan every archived member and excluded proprietary content, compare image hashes against `.research/assets/`, and separately inspect the original text versions. Do not bulk-import RAR contents or use Wayback HTML placeholders as screenshots.

**Conclusion:** a significant historical backup source was successfully inventoried, yet the **current missing image-ID tally remains unchanged**. The four tempting filename matches are confirmed HTML wrappers, not restored images. This work also leaves the original 2017 226-byte NOPAL patch and 59.0 KB network ZIP/7z archive provenance issues **open**.
