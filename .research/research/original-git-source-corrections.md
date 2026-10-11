# Source-correction and generated-link audit — original POPStarter wiki

**Draft PR #578, research only; do not change the published wiki.** Comparison: AstroSnail-supplied original ShaolinAssassin Bitbucket wiki Git clone at final HEAD `960d675d278296a3a62143410b38aa8882d21a79`, versus POPSLoader's recovered Markdown pages on GitHub base commit `15ffb1c7c46e1643ab2869baf1b26718cf53a604`.

## C1 — [CONFIRMED CORRECTION MISSED] Light-gun example module order

The recovered `.research/wiki/ps1-special-devices.md`, based primarily on a June 2017 Wayback snapshot, says in step 6 to use **USBD.IRX first and USBD.IRX second** when experimenting with light-gun devices. That duplication contradicts the same recovered page's step 5, which mentions `USBGUN.IRX`.

The original wiki corrected this example on **2017-10-17 08:10:36 UTC** in commit **`f4210efed74840394474a502da259d733a03be22`**, authored in the wiki under ShaolinAssassin's name. The corrected step reads **USBD.IRX first and USBGUN.IRX second**. Original final file `ps1-special-devices.textile` preserves the correction, while our reconstructed Markdown **does not**.

Original credits: the tutorial is explicitly attributed to **AKuHAK**. Preserve that credit in any future correction. This is an example **for finding suitable IRX modules**, not a verified promise that a specific light gun works on every device or in USB mode. The original guidance explicitly says module order requires experimentation, and USB devices may fail in USB-mode POPS.

**Proposed later action (requires maintainer approval):** correct only the duplicated word in modernized guide text and annotate the original correction revision. Keep the full text of the old snapshot separately if maintaining a strict historical facsimile.

## C2 — [PRESERVATION WIN: DO NOT RESTORE SOURCE TYPO] USB launcher example

Original wiki commit **`eb75d91410491b8d693e70b6980c8f9c4036bfc2`**, dated **2017-10-27 10:48:05 UTC**, unexpectedly replaced the valid example **`XX.Some Game.elf`** with **`SB.GAME.ELF`** in a table describing **USB** launch mode. Original final HEAD still displays the wrong `SB.GAME.ELF` example. Other lines of the very same original page explicitly require the USB prefix `XX.`, whereas `SB.` belongs to **SMB** launch mode.

Our recovered `.research/wiki/usb-mode.md` **retains the correct example** `XX.Some Game.elf`. The recovered `smb-mode.md` correctly uses `SB.GAME.ELF` for SMB. Therefore this is **not a recovered documentation gap**. Instead it is a caution against blindly replacing the merged reconstruction with original Git HEAD.

## C3 — [CONFIRMED LINK-PROVENANCE DEFECT] 30 pseudo-commit URLs from non-commit values

Direct reads of all 63 recovered `.research/wiki/*.md` pages identify **30 URL occurrences** matching `https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/commits/<hex-like>`, spread across **9 pages** and only **18 distinct suffix strings**. No original wiki HEAD `.textile` page contains this explicit URL pattern. **None of the 18 suffixes resolves as a Git object in the original 2,140-commit wiki Git clone** (tested with `git cat-file -t` from the extracted original tree). This does not establish what happened on Bitbucket's unrelated non-wiki project backend or whether the archived HTML renderer inserted the links.

| Classification | URL occurrences | Distinct suffixes | Meaning of apparent link text |
|---|---:|---:|---|
| Release-date or tool-build labels | **13** | **7** | `20191110`, `20190605`, `20190104`, `20180924`, `20180922`, `20180921`, `20180920` |
| Numeric cheat code / configuration constants | **9** | **5** | `01000000`, `00000002`, `00000001`, `00507028`, `00000000` |
| Checksums incorrectly treated like commits | **3** | **3** | CRC32 `1ef0a3a7`, MD5 `355a892a8ce4e4a105469d4ef6f39a42`, MD5 `a625d0b3036823cdbf04a3c0e1648901` |
| Historic Pastebin/Pastie identifiers | **5** | **3** | `7937017` (2), `7749880` (2), `7667656` (1) |
| **Total** | **30** | **18** | not verified original wiki Git commits |

Affected recovered pages and occurrence counts:
- `apps-last-version.md`: 1
- `cheat-engine.md`: 1
- `chronology.md`: 2
- `pfsshell.md`: 1
- `popstarter-changelog.md`: 5
- `smb-mode.md`: 1
- `special-cheats.md`: 7
- `timeline.md`: 6
- `version.md`: 6

Examples verified directly from the recovered Markdown:
- `cheat-engine.md` links code arithmetic prefix `01000000` to `/commits/01000000` despite it being a **hexadecimal constant**.
- `chronology.md` links the POPS executable's **CRC32** and **MD5** to pseudo-commit URLs, rather than displaying unlinked checksum values.
- `smb-mode.md` links a `POPS_IOX.PAK` MD5 to a non-commit URL.
- `version.md` and `timeline.md` link release date strings such as `20190605` to pseudo-commit URLs.
- `popstarter-changelog.md` links original Pastie numeric IDs as supposed wiki commit IDs.

**Evidence strength:** These URL suffixes are *not* objects in the supplied **wiki Git** history and their surrounding text clearly describes dates, hash values, code words or Pastie IDs. This is sufficient to classify them as inappropriate **commit links** in our recovered document. The exact stage that created them (Bitbucket's HTML rendering, Wayback snapshots or Markdown conversion) is **not independently established**.

**Proposed later action:** replace confirmed pseudo-commit links with their original literal values while preserving hashes, dates, game codes and historical attribution, and separately check legitimate release and Pastie source URLs. Avoid global stripping of all hyperlinks or altering hexadecimal code data.

### Reproduction against original Git clone

`git -C /path/to/original/wiki cat-file -t 20190605`  (no such object)
`git -C /path/to/original/wiki cat-file -t a625d0b3036823cdbf04a3c0e1648901`  (no such object)

For page review, look for `popstarter-documentation-stuff/commits/` in all 63 recovered Markdown files. The original final wiki contains zero explicit URLs matching that pattern. The counts above describe the exact baseline; later edits must be recounted.

**Research-only:** no public-page correction, no module/payload upload, no attribution changes and no merge.


**2026-10-10 verification update:** `.research/build_site.py`, `rewrite_and_clean` (lines 170–172), **already strips `/commits/` anchors while retaining their literal text**. This includes code and checksum fields. The 30 pseudo-commit URLs remain in the recovered *Markdown source* but are not active links in the generated website, as confirmed by the public Cheat Engine page showing `add $01000000` unlinked. Audit priority is source portability/fidelity, not a demonstrably broken published link.
