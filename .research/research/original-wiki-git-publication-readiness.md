# Original wiki Git ZIP: verified staging and publication (2026-10-11)

The contributor-supplied original `wiki.zip` is preserved in the maintainer's file Library and was **uploaded byte-identically to `master`** as `.research/downloads/popstarter-documentation-stuff-wiki-git-20240731.zip` in [commit `c2c61bb`](https://github.com/NathanNeurotic/POPSLoader/commit/c2c61bb0ad6bec124018b7af5b4f20e576be6749). That upload changed **only** this ZIP. Online publication remains subject to the Docs Site workflow and verification of `gh-pages` after synchronizing `dev`.

The exact, unmodified historical Git ZIP has been independently recovered from the attached original in its Library and inspected in an isolated temporary directory:

- Recommended permanent filename: `popstarter-documentation-stuff-wiki-git-20240731.zip`
- Length: **2,102,657 bytes**
- SHA-256: `d0c243d91e417988825ed92b440224ed46cbbf448d0b67528e0957c15c0d029a`
- ZIP member CRC test: PASS; **183 entries** including directories and original `wiki/.git/` objects
- Source-controlled Git blob SHA-1: `044d315bcc55c5de7317af4d36b10222deeb86bf`, identical to the preserved original ZIP's computed Git blob identity
- Original Git wiki HEAD: `960d675d278296a3a62143410b38aa8882d21a79`
- Attribution: historical wiki contributors authored the source; **AstroSnail** recovered and supplied the ZIP; do not conflate uploader with original author.
- This is a Git-history preservation artifact, **not** a PS2 game image, launcher or Sony POPS emulator package.

## Publisher contract: no placeholder masquerading as a download

The source generator `.research/build_site.py` has a **conditional** archival source card and checks the supplied ZIP SHA-256 before publishing. While absent from the generator's checked-out branch, the `Downloads` page must say **not yet hosted**; when present and verified, it must expose the exact downloadable archive. Do not create an empty file, redirect an arbitrary GitHub link, or substitute a recompressed archive.

A new [build-time gate](../tools/audit_original_wiki_zip.py) checks the regenerated page against both states: without the ZIP it **rejects a fabricated download link** and requires a truthful missing-file notice; with the ZIP it enforces original byte count, SHA-256, ZIP CRC, Git/source member identity, generated copy byte identity, contributor attribution and a real link.

## Exact GitHub staging (completed) and public publication verification

The maintainer used GitHub's own file-upload interface to add the **exact original bytes** as `.research/downloads/popstarter-documentation-stuff-wiki-git-20240731.zip` to `master`, commit [`c2c61bb`](https://github.com/NathanNeurotic/POPSLoader/commit/c2c61bb0ad6bec124018b7af5b4f20e576be6749). Repository tree metadata confirms **2,102,657 bytes** and Git blob SHA-1 `044d315bcc55c5de7317af4d36b10222deeb86bf`, exactly matching the locally preserved original; ZIP CRC and SHA-256 checks passed independently.

The Docs Site workflow builds on PRs and publishes only on `dev` pushes. The remaining publication process is to synchronize the verified `master` contents to `dev`, let the existing SHA-256, ZIP/attribution and page-link build gates pass, and then verify that `gh-pages/downloads/` and the live Downloads page actually serve the exact ZIP. The generator is configured to include it as a separate archival source download and in the offline documentation bundle. Do not equate successful GitHub staging with confirmed public hosting until the deployment succeeds.

## Independently corrected published historical guide

The recovered 2017 Wayback text of `ps1-special-devices.md` had mistakenly duplicated `USBD.IRX` as the second light-gun driver in step 6. The original wiki Git source at final HEAD and revision `f4210efed74840394474a502da259d733a03be22` instead uses **`USBD.IRX` followed by `USBGUN.IRX`**. The reconstruction has now restored the one-word source correction without changing old archival snapshots. The tutorial's original **AKuHAK** credit and disclaimer about experimental module order were retained. This is an archival-text accuracy fix, **not hardware-proven light-gun compatibility**.
