# Original 2017 POPStarter widescreen images: developer URL and Wayback payload-type audit

**Follow-up after merged PR #580 (2026-10-11).** This read-only audit establishes **exact primary-source developer image URLs**, not downloaded screenshots. No binary media, copyrighted emulator payloads, live wiki pages, or archive packages were added or modified.

## Source and method

On **2017-10-04**, POPStarter developer **krHACKen** published a [Metagames post #330](https://www.metagames-eu.com/forums/1776217-post330.html) comparing the POPS GTE widescreen hack with PS1 game-code patches and embedding **17 complete `<img src>` URLs**, one for the Ape Escape comparison and sixteen named games. The forum's HTML contains the **literal original URL paths** at `http://aybabtu.chez.com/POPS/WIDE_PRELIM/`, not merely screenshot headings or placeholders. All 17 were extracted from the developer post's actual image-tag source.

The [existing Bitbucket image-ID priority report](original-git-image-priorities.md) identifies **12** missing images from the final `widescreen.textile` page, including Ape Escape, and **five** already represented screenshots. Mapping these to the forum's game-subject filenames makes this a dated, **independent source URL crosswalk**, but **not proof that bytes served from the developer domain equaled bytes once uploaded to Bitbucket**.

For each of the 17 original developer URLs, the Internet Archive's `/wayback/available?url=<source URL>` lookup was checked. For each of its eight returned "closest" **HTTP 200** captures, the timestamp-specific **raw `id_` memento** was opened individually and the response's content type and rendered body were examined. **All eight** returned `text/html` titled **"Pages Persos Chez.com"**, showing a parked/error page, **not JPG/PNG content**. Nine URLs returned no closest capture. These are **availability-API and selected-memento results**, not a complete CDX/WARC exhaustive capture inventory.

## All 17 exact developer URLs and observed capture results

| 2017 developer image URL | Missing final wiki Bitbucket ID (or already represented) | Closest Wayback result inspected |
|---|---|---|
| [`APE_ESCAPE_COMP.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/APE_ESCAPE_COMP.JPG) | `1720317623` | [200, **HTML parking page** (capture 20250714)](https://web.archive.org/web/20250714024134id_/http://aybabtu.chez.com/POPS/WIDE_PRELIM/APE_ESCAPE_COMP.JPG) |
| [`007_TND_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/007_TND_WIDE.JPG) | already represented | [200, **HTML parking page** (capture 20250714)](https://web.archive.org/web/20250714024134id_/http://aybabtu.chez.com/POPS/WIDE_PRELIM/007_TND_WIDE.JPG) |
| [`APOCALYPSE_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/APOCALYPSE_WIDE.JPG) | already represented | [200, **HTML parking page** (capture 20250714)](https://web.archive.org/web/20250714024144id_/http://aybabtu.chez.com/POPS/WIDE_PRELIM/APOCALYPSE_WIDE.JPG) |
| [`COOL_BOARDERS_3_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/COOL_BOARDERS_3_WIDE.JPG) | already represented | [200, **HTML parking page** (capture 20250714)](https://web.archive.org/web/20250714024140id_/http://aybabtu.chez.com/POPS/WIDE_PRELIM/COOL_BOARDERS_3_WIDE.JPG) |
| [`CRASH_BANDICOOT_2_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/CRASH_BANDICOOT_2_WIDE.JPG) | already represented | No closest snapshot reported by availability API |
| [`DIE_HARD_TRILOGY_2_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/DIE_HARD_TRILOGY_2_WIDE.JPG) | `471851278` | No closest snapshot reported by availability API |
| [`DINO_CRISIS_2_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/DINO_CRISIS_2_WIDE.JPG) | already represented | [200, **HTML parking page** (capture 20240903)](https://web.archive.org/web/20240903063835id_/http://aybabtu.chez.com/POPS/WIDE_PRELIM/DINO_CRISIS_2_WIDE.JPG) |
| [`EXHUMED_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/EXHUMED_WIDE.JPG) | `3811602128` | No closest snapshot reported by availability API |
| [`GHOST_IN_THE_SHELL_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/GHOST_IN_THE_SHELL_WIDE.JPG) | `727086931` | [200, **HTML parking page** (capture 20240903)](https://web.archive.org/web/20240903063835id_/http://aybabtu.chez.com/POPS/WIDE_PRELIM/GHOST_IN_THE_SHELL_WIDE.JPG) |
| [`GRAN_TURISMO_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/GRAN_TURISMO_WIDE.JPG) | `4095826607` | No closest snapshot reported by availability API |
| [`MEDIEVIL_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/MEDIEVIL_WIDE.JPG) | `4249513129` | No closest snapshot reported by availability API |
| [`METAL_GEAR_SOLID_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/METAL_GEAR_SOLID_WIDE.JPG) | `65599370` | No closest snapshot reported by availability API |
| [`SOUL_REAVER_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/SOUL_REAVER_WIDE.JPG) | `446039127` | [200, **HTML parking page** (capture 20240903)](https://web.archive.org/web/20240903063835id_/http://aybabtu.chez.com/POPS/WIDE_PRELIM/SOUL_REAVER_WIDE.JPG) |
| [`SYPHON_FILTER_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/SYPHON_FILTER_WIDE.JPG) | `1450475876` | [200, **HTML parking page** (capture 20240903)](https://web.archive.org/web/20240903063835id_/http://aybabtu.chez.com/POPS/WIDE_PRELIM/SYPHON_FILTER_WIDE.JPG) |
| [`TEAM_BUDDIES_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/TEAM_BUDDIES_WIDE.JPG) | `2425094621` | No closest snapshot reported by availability API |
| [`TOMB_RAIDER_II_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/TOMB_RAIDER_II_WIDE.JPG) | `1094748012` | No closest snapshot reported by availability API |
| [`WIPEOUT_3_WIDE.JPG`](http://aybabtu.chez.com/POPS/WIDE_PRELIM/WIPEOUT_3_WIDE.JPG) | `997655191` | No closest snapshot reported by availability API |

## Quantitative outcome

- **17/17** original developer-image URL paths are now documented from a dated primary-source HTML post.
- **12/17** correspond to the wiki's **missing** widescreen source IDs; the other **5** have already represented screenshot IDs in the existing asset census.
- **8/17** reported an HTTP 200 nearest archived capture: **4** mapped to missing wiki images (Ape Escape, Ghost in the Shell, Soul Reaver, Syphon Filter), **4** to already represented images (007, Apocalypse, Cool Boarders 3, Dino Crisis 2).
- **All 8/8** HTTP 200 captures were opened and **all returned `text/html` Chez.com parking/error content**. They must **not** be counted as recovered JPEG bytes.
- **9/17** URLs had no nearest capture returned by the availability API (among them **eight** wiki-missing screenshots and the already represented Crash Bandicoot 2).
- **0** authentic 2017 developer screenshots recovered as raw images during this step. **19 final-HEAD / 34 all-history missing Bitbucket IDs remain unchanged**.

## Reproducibility and future investigation

1. Read the [exact 2017 HTML post](https://www.metagames-eu.com/forums/1776217-post330.html), not the text-only search snippet; extract `img[src]` values beginning `http://aybabtu.chez.com/POPS/WIDE_PRELIM/`.
2. Query Internet Archive's public availability API for each exact URL, keeping the timestamps and original hostnames.
3. Independently open any matching memento in **raw `id_` form** and require JPEG/PNG/GIF magic, image decoder success, dimensions, full SHA-256, and provenance before claiming successful image recovery. HTTP status code and `.JPG` in the URL are not sufficient.
4. Check alternate **older** CDX snapshots and original developer mirror inventories separately; these API checks cannot exclude captures not selected by the "closest" endpoint. Candidate images from elsewhere must not be renamed to the original filename without independent verification.
5. Preserve screenshot rights/attribution and editorial approval before any public asset or binary import.

**Boundary:** these URLs are now confirmed original developer links. Neither the current Chez.com parked pages nor generic game screenshots constitute the original archived POPStarter widescreen comparison media. No live docs were changed.
