# Original wiki Git ZIP: verified local source and public staging boundary (2026-10-11)

The contributor-supplied original `wiki.zip` is **available in the maintainer's file Library**; it is **not yet available via `gh-pages/downloads/` or `.research/downloads/`**.

The exact, unmodified historical Git ZIP has been independently recovered from the attached original in its Library and inspected in an isolated temporary directory:

- Recommended permanent filename: `popstarter-documentation-stuff-wiki-git-20240731.zip`
- Length: **2,102,657 bytes**
- SHA-256: `d0c243d91e417988825ed92b440224ed46cbbf448d0b67528e0957c15c0d029a`
- ZIP member CRC test: PASS; **183 entries** including directories and original `wiki/.git/` objects
- Original Git wiki HEAD: `960d675d278296a3a62143410b38aa8882d21a79`
- Attribution: historical wiki contributors authored the source; **AstroSnail** recovered and supplied the ZIP; do not conflate uploader with original author.
- This is a Git-history preservation artifact, **not** a PS2 game image, launcher or Sony POPS emulator package.

## Publisher contract: no placeholder masquerading as a download

The source generator `.research/build_site.py` already has a **conditional** archival source card and checks the supplied ZIP SHA-256 before publishing. The `Downloads` page correctly states **not yet hosted** while the archive is absent. Do not create an empty file, redirect an arbitrary GitHub link, swap a recompressed archive, or claim this historical ZIP is published while the original bytes are still missing from the repository.

A new [build-time gate](../tools/audit_original_wiki_zip.py) checks the regenerated page against both states: without the ZIP it **rejects a fabricated download link** and requires a truthful missing-file notice; with the ZIP it enforces original byte count, SHA-256, ZIP CRC, Git/source member identity, generated copy byte identity, contributor attribution and a real link.

## Exact staging step (still outstanding)

The authenticated GitHub code connector in this workflow supports text changes and encoded in-memory Git blobs, **not uploading a Library file reference directly as binary bytes**. Therefore the ZIP has **not been pushed to GitHub** in this research change. Stage the verified original as the following exact new repository file in `master` or a reviewed PR:

```text
.research/downloads/popstarter-documentation-stuff-wiki-git-20240731.zip
```

The site workflow builds on PRs and publishes only on a `dev` push; the existing `master`/ `dev` synchronization convention remains. Once staged with the **exact** verified bytes and merged, the generator will provide the credit-bearing original Git source ZIP as a separate download and include it in the generated offline documentation bundle. Re-run Docs Site, check the public `downloads.html` link and online SHA-256, and preserve the original authors' history. **Never claim this staging has already happened.**

## Independently corrected published historical guide

The recovered 2017 Wayback text of `ps1-special-devices.md` had mistakenly duplicated `USBD.IRX` as the second light-gun driver in step 6. The original wiki Git source at final HEAD and revision `f4210efed74840394474a502da259d733a03be22` instead uses **`USBD.IRX` followed by `USBGUN.IRX`**. The reconstruction has now restored the one-word source correction without changing old archival snapshots. The tutorial's original **AKuHAK** credit and disclaimer about experimental module order were retained. This is an archival-text accuracy fix, **not hardware-proven light-gun compatibility**.
