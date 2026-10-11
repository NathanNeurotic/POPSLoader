# Original wiki missing images — priority by source revision

Research attachment for draft PR #578, no binary import. Source: AstroSnail's original Git clone, full commit history and last revision `960d675d278296a3a62143410b38aa8882d21a79`. Comparator: tracked POPSLoader `.research/assets/` (124 files) and recovered `.research/wiki/` and `.research/_state/galleries.json`.

**155 distinct historical Bitbucket image IDs** are referenced in Git history; **34 IDs** have no numeric-ID match among tracked recovered image assets. These 34 URLs do **not** mean 34 recoverable binaries: all original Git blobs are UTF-8 text (not images), and the previous recovery log includes 19 failures.

## Priority 1: still referenced at original Git HEAD (19 IDs)

These sources remain referenced in the original wiki's *final revision*. None of these 19 numeric IDs occurs in the corresponding recovered Markdown pages or in the tracked Wayback gallery cache, nor is there a filename with its numeric ID among recovered `.research/assets/`. This is a documented reference/gallery coverage gap. It is **not** proof the image can still be obtained online.

| Bitbucket image ID | Historical filename | Original source page | Previous recovery state |
|---|---|---|---|
| `1094748012` | `TOMB_RAIDER_II_WIDE.jpg` | `widescreen.textile` | FAIL:magic(b'<!DO') |
| `1450475876` | `SYPHON_FILTER_WIDE.jpg` | `widescreen.textile` | FAIL:magic(b'<?xm') |
| `1720317623` | `APE_ESCAPE_COMP.JPG` | `widescreen.textile` | FAIL:magic(b'<!DO') |
| `1731981611` | `2.png` | `POC2_POPS-00001.textile` | FAIL:magic(b'<!DO') |
| `2425094621` | `TEAM_BUDDIES_WIDE.jpg` | `widescreen.textile` | FAIL:magic(b'<!DO') |
| `2636724756` | `57067464.JPG` | `D2LS.textile` | FAIL:magic(b'<?xm') |
| `270560112` | `16h0lcg.jpg` | `16/9.md` | FAIL:magic(b'\x89PNG') |
| `3117688129` | `bez%C3%82%C2%A0tytu%C5%82u.png` | `IGR textures.textile` | FAIL:magic(b'<!DO') |
| `3801833563` | `2md7xs.jpg` | `16/9.md` | FAIL:magic(b'<!DO') |
| `3811602128` | `EXHUMED_WIDE.jpg` | `widescreen.textile` | FAIL:magic(b'<!DO') |
| `3844714277` | `POPS2CUE.JPG` | `Toolbox commands.textile` | FAIL:magic(b'<?xm') |
| `4095826607` | `GRAN_TURISMO_WIDE.jpg` | `widescreen.textile` | FAIL:magic(b'<!DO') |
| `4249513129` | `MEDIEVIL_WIDE.jpg` | `widescreen.textile` | FAIL:magic(b'<?xm') |
| `4286767539` | `2n0oweq.jpg` | `16/9.md` | FAIL:magic(b'\x89PNG') |
| `446039127` | `SOUL_REAVER_WIDE.jpg` | `widescreen.textile` | FAIL:magic(b'<?xm') |
| `471851278` | `DIE_HARD_TRILOGY_2_WIDE.jpg` | `widescreen.textile` | FAIL:magic(b'<!DO') |
| `65599370` | `METAL_GEAR_SOLID_WIDE.jpg` | `widescreen.textile` | FAIL:magic(b'<?xm') |
| `727086931` | `GHOST_IN_THE_SHELL_WIDE.jpg` | `widescreen.textile` | FAIL:magic(b'<!DO') |
| `997655191` | `WIPEOUT_3_WIDE.jpg` | `widescreen.textile` | FAIL:magic(b'<!DO') |

## Priority 2: only in earlier revisions or deleted pages (15 IDs)

These references are missing from tracked assets but do not occur in the original source HEAD. Recover them as *historical-version evidence* where worthwhile, not as required modern page assets.

| Bitbucket image ID | Historical filename | Original source page | Previous recovery state |
|---|---|---|---|
| `1391261396` | `2.png` | `POC2_POPS-00001.textile` | no logged source-ID result |
| `1510911193` | `pops05_zps81df52b9.jpg` | `Pfsshell.textile` | no logged source-ID result |
| `2070562384` | `new.gif` | `News.textile` | no logged source-ID result |
| `2084063178` | `01_bmp10.jpg` | `PS1 MC saves to VMC.md` | no logged source-ID result |
| `2114982071` | `IGR_sample.gif` | `IGR textures.textile` | no logged source-ID result |
| `2165842753` | `007_TND_WIDE%20` | `widescreen.textile` | no logged source-ID result |
| `2329291489` | `02_bmp10.jpg` | `PS1 MC saves to VMC.md` | no logged source-ID result |
| `2348636821` | `03_bmp10.jpg` | `PS1 MC saves to VMC.md` | no logged source-ID result |
| `2685397097` | `Sans-titre-1.png` | `Batcher.textile` | no logged source-ID result |
| `3333649027` | `result.png` | `IGR textures.textile` | no logged source-ID result |
| `3346710006` | `index.jpeg` | `History.textile` | no logged source-ID result |
| `4209628073` | `007_TND_WIDE%20` | `smooth.textile` | no logged source-ID result |
| `462913228` | `canvas.png` | `scan_lines_preview.md` | no logged source-ID result |
| `777862948` | `Sans-titre-1.png` | `popstarter-batcher.textile` | no logged source-ID result |
| `983441507` | `nocanvas.png` | `scan_lines_preview.md` | no logged source-ID result |

## Specific retrieval risks

- The prior asset log reports a response starting with PNG magic for historical URLs `270560112-16h0lcg.jpg` and `4286767539-2n0oweq.jpg`, but recorded them as failures. They may represent genuine PNGs served under misleading `.jpg` names. Re-fetch and check full file format, dimensions, integrity and source authenticity before calling either recovered.
- Other failures began with HTML or XML bytes and are **not image content**, despite nominal image URLs.
- Never rename an arbitrary internet image to the original Bitbucket filename and treat it as verified. Record captured URL, retrieval timestamp, original content hash, file signature and confirmation that the subject matches the historical page.
- Do not silently substitute screenshots from different POPStarter versions. Keep original image references and historical date if asset cannot be recovered.

## Boundaries

**No binaries were added to this PR.** Its scope is research classification and provenance only. The historical Git ZIP itself contains the URL references but no PNG/JPEG/GIF media blobs. The 19 current references and 15 historical references require separate Wayback or verified-mirror recovery efforts if the maintainer decides those should be published.


## Original HEAD image-reference gaps — exact per-page accounting

Compared *final* original Git wiki `960d675d278296a3a62143410b38aa8882d21a79` image-ID URLs against the 124 tracked image filenames in `.research/assets/` and current `_state/galleries.json`. The previously known **19 unmatched IDs at original Git HEAD** resolve to exactly six pages:

| Original final-revision page | Unmatched original image IDs | Specific missing historical images |
|---|---:|---|
| `widescreen.textile` | **12** | `1720317623` Ape Escape comparison; `471851278` Die Hard Trilogy 2; `3811602128` Exhumed; `727086931` Ghost in the Shell; `4095826607` Gran Turismo; `4249513129` MediEvil; `65599370` Metal Gear Solid; `446039127` Soul Reaver; `1450475876` Syphon Filter; `2425094621` Team Buddies; `1094748012` Tomb Raider II; `997655191` Wipeout 3 |
| `ps1-widescreen-codes.textile` | **3** | `3801833563` 4:3 example, `4286767539` 16:9 example, `270560112` additional comparison |
| `igr-textures.textile` | **1** | `3117688129` accented filename/image reference |
| `poc2-pops-00001-era.textile` | **1** | `1731981611` numbered installation screenshot |
| `D2LS.textile` | **1** | `2636724756` D2LS illustration |
| `vcd.textile` | **1** | `3844714277` POPS2CUE screenshot |
| **TOTAL** | **19** | No image bytes contained in the original Git clone |

### High-impact widescreen gallery

The final original `widescreen.textile` contains **17** Bitbucket `images/<id>-<filename>` references. Our recovered `widescreen.md` retains the **16** per-game screenshot *headings* (007, Apocalypse, Cool Boarders 3, Crash Bandicoot 2, Die Hard Trilogy 2, Dino Crisis 2, Exhumed, Ghost in the Shell, Gran Turismo, MediEvil, Metal Gear Solid, Soul Reaver, Syphon Filter, Team Buddies, Tomb Raider II, Wipeout 3), but its gallery cache has only **five** source image entries. The other **12** source IDs listed above have no matching tracked asset. This is a visually meaningful preservation gap: absent screenshots under surviving game headings.

The existing **98/98 successfully backed gallery-cache entries** refers to a *different denominator*: every screenshot currently **listed in the recovered cache** is available, but the cache itself omits these original-head images. Both facts are true. Do not represent 98/98 as proof every original gallery image was recovered.

### Confidence and retrieval constraints

These are missing original **numeric image identifiers**, not yet confirmed 19 distinct unique missing picture bytes. Unmatched ID `1731981611` could duplicate a different recovered `2.png`, and identical subject matter may appear under alternate identifiers. Old recovery logs for `270560112-16h0lcg.jpg` and `4286767539-2n0oweq.jpg` reported a **PNG magic prefix** despite `.jpg` URL extensions; their complete bytes were never verified. Attempts to open timestamp-specific Wayback raw-asset URLs through the available web retrieval returned inaccessible, so **no actual image recovery is claimed**.

Any future recovery must verify source authenticity, full-file signatures, checksums, dimensions and screenshots' topic; mere filename/ID matching is insufficient. No images were added by this PR.
