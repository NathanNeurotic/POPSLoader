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
