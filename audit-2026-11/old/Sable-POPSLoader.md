# Sable Audit — POPSLoader

- **Auditor:** Sable
- **Repo:** NathanNeurotic/POPSLoader
- **Pin (READ, verified in clone 2026-11-13):** `master` @ `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (2026-11-12, "Docs: credit Ember and the translators on the site; RiptOPL links (#639)")
- **Clone:** `~/workspace/audit-clones-2026-11-13/POPSLoader` — 609 tracked files, 30,417,169 tracked bytes, `.git` pack 195.70 MiB
- **Method:** read-only. `git ls-files`/size/md5 inventories, grep sweeps, and direct reads of all EE/IOP C/C++ source, the three shipped Lua scripts, the root Makefile, all 10 workflows, and samples of the docs/research trees. No files in the repo were edited.
- **Headline shape of this repo:** the actual loader is small (~14 `.c`, 17 `.cpp`, 26 `.h`, 3 shipped Lua files). Most of the repository is not the loader: `.research/` alone is 312 of 609 tracked files and 21,197,583 of 30,417,169 tracked bytes (~70%). The biggest wins here are repo-composition wins, plus a real ELF-size win from byte-identical IRX modules embedded more than once.

Findings are sorted by benefit. Benefits marked *(est.)* are estimates derived from measured file sizes/counts, not from a rebuilt ELF (no PS2SDK build was run — see footer).

---

## POPSLOADER-001 / `.research/` preservation archive is 70% of the product repo
- **Category:** 7 (repo clutter) / 8 (redundant feature)
- **Location(s):** POPSLoader/.research/ (312 tracked files, 21,197,583 bytes); largest: POPSLoader/.research/downloads/popstarter-documentation-stuff-wiki-git-20240731.zip (2,102,657 B), POPSLoader/.research/wiki/ps1-codes-in-ps1-raw-format.md (1,608,488 B), POPSLoader/.research/downloads/POPStarter_HDD_Quickstarter_Pack_20200209.zip (1,113,737 B), POPSLoader/.research/downloads/POPStarter_HDD_Quickstarter_Pack_20171027.7z (865,736 B); 24 download archives totalling 7,829,387 B (zip+7z only); POPSLoader/.research/assets/ (124 files, 8,659,452 B)
- **Problem:** A historical POPStarter preservation archive, a docs-site generator, and one-shot audit tooling live inside the loader's own repo, so every clone, CI checkout and branch carries ~21 MB of archives, scanned game art and wiki dumps that the ELF build never reads. The `.gitignore` commentary shows this was a deliberate, argued choice (site must be rebuildable from tracked files) — but that argues for the *generator + text corpus* being tracked somewhere, not for the binary downloads and 8.7 MB of assets living in the product repo.
- **Fix:** Move `.research/downloads/`, `.research/assets/` and the wiki dumps to a separate preservation repo (or GitHub Release assets) and keep at most `build_site.py`/`audit_site.py` + the text corpus here, pointing at the archive by URL. Delete the moved copies from this repo.
- **Benefit:** ~15–21 MB of tracked tree removed *(est., depending on how much text corpus stays)*; proportionally faster clones/checkouts. No ELF/RAM effect.
- **Effort:** M. **Risk:** Med (docs-site rebuild must be re-verified against the new location — the repo's own notes describe a byte-for-byte rebuild check that can be re-run). **Confidence:** High (READ — sizes/counts measured).

## POPSLOADER-002 / Byte-identical IRX modules are embedded into the ELF two and three times
- **Category:** 2 (duplication) / 4 (size and memory)
- **Location(s):** POPSLoader/bin/POPSLDR/usbd.irx.ilink, POPSLoader/bin/POPSLDR/usbd.irx.mx4sio, POPSLoader/bin/POPSLDR/usbd.irx.usbexfat and POPSLoader/iop/embed/BDMASSAULT_MX4SIO/usbd.irx — all four md5 `a77650a0ad356077b990d21bde6affc4`, 48,500 B each; POPSLoader/bin/POPSLDR/usbhdfsd.irx.udpfs and POPSLoader/bin/POPSLDR/usbhdfsd.irx.usbexfat — both md5 `ad9640d487b6e53441d2b6bed90dff23`, 34,508 B each; POPSLoader/bin/POPSLDR/usbhdfsd.irx.mx4sio identical to POPSLoader/iop/embed/BDMASSAULT_MX4SIO/usbhdfsd.irx (14,993 B); embedding rules at POPSLoader/Makefile:224-… (one `bin2c` rule per suffix) and the extern/registry block at POPSLoader/src/embed_assets.cpp:70-95
- **Problem:** The build `bin2c`-embeds a separate copy of `usbd` for the iLink, MX4SIO and USB-exFAT backends even though the three binaries are byte-identical, and a second identical `usbhdfsd` for UDPFS and USB-exFAT. Identical bytes are shipped repeatedly inside POPSLOADER.ELF and resident in EE RAM.
- **Fix:** Embed one copy of each unique binary and point the ilink/mx4sio/usbexfat (resp. udpfs/usbexfat) asset keys at the same array in `embed_assets.cpp`. Keep the per-backend filenames on disk if the staging code needs them; remove only the duplicate embeds.
- **Justification (fix touches the asset table, adds nothing):** it deletes two `usbd` embeds (2 × 48,500 B) and one `usbhdfsd` embed (34,508 B) with zero new code — the registry already maps keys to `{data,size}` pairs, so aliasing is a table edit, not a new layer.
- **Benefit:** ~131,508 B off the embedded payload *(est. from measured file sizes; packed-ELF saving will be somewhat less after ps2-packer compression)* and the same off resident RAM when staged.
- **Effort:** S. **Risk:** Low (byte-identity is proven by md5; the load path consumes bytes, not filenames). **Confidence:** High (READ).

## POPSLOADER-003 / All seven UI languages are compiled into `system.lua` and parsed on every boot
- **Category:** 4 (size and memory) / 5 (performance)
- **Location(s):** POPSLoader/bin/POPSLDR/system.lua:2558-2561 (language registry: EN, FR, DE, PT, ES, IT, HU, SK) and the seven full translation tables that follow it (sampled at lines 2639, 2946, 3254, 3562, 3869, 4203, 4534 — the same ~300-line English-keyed table repeated per language); file totals 11,784 lines / 571,596 B and is embedded whole (minified) into the ELF per POPSLoader/Makefile:203-215
- **Problem:** Every user pays the parse time, embedded size and Lua-table RAM for seven languages to use one. The tables are keyed by the full English source string, so each long string (e.g. the multi-line About text) is stored eight times — once as a key in every language table plus once as the source. Translations also already exist in a second, data-only form for at least three languages (POPSLoader/docs/translations/brazilian-portuguese.tsv, hungarian.tsv, slovak.tsv, 410 lines each), so the Lua tables are a duplicated copy of that data.
- **Fix:** Ship the translation tables as separate per-language data files (the TSV form already exists) next to the ELF, load only the selected language at boot / on language change, and keep only English (the fallback) embedded. Delete the seven inline tables from `system.lua`.
- **Benefit:** roughly 2,200+ lines and on the order of 200 KB of `system.lua` source removed *(est. from table span/sampled density)*; embedded ELF and boot-parse/RAM cost drop by the six unused languages on any given console.
- **Effort:** M. **Risk:** Med (language switching and the English-fallback path at system.lua:4846-4864 must keep working; the host harness in tools/host_harness.py exercises this file and can gate it). **Confidence:** High (READ).

## POPSLOADER-004 / The whole POPStarter SMB IRX set is tracked twice, byte for byte
- **Category:** 2 (duplication)
- **Location(s):** POPSLoader/POPSTARTER/{SMSUTILS.irx, poweroff.irx, ps2dev9.irx, ps2ip.irx, ps2smap.irx, smbman.irx} vs POPSLoader/bin/POPSLDR/popsmb/ (same six filenames) — md5-identical pairs for all six (e.g. ps2ip.irx 109,497 B, md5 `525acea7f1d1e302bdb34e45c5363597` in both); combined size of both sets 365,308 B; also POPSLoader/POPSTARTER/{del.icn, list.icn, icon.sys-adjacent files} vs POPSLoader/bin/POPSLDR/{del.icn.bdma, list.icn.bdma} — md5-identical content under two names
- **Problem:** Two directory trees carry the same runtime binaries; an IRX update applied to one copy silently desynchronises the other, and the repo stores every byte twice.
- **Fix:** Keep one canonical copy. If both install layouts genuinely need the files on the memory card, generate/copy the second layout at packaging time (the release workflows already assemble packages) instead of tracking it.
- **Benefit:** ~182,654 B of tracked binaries removed *(est., one set)* plus the duplicate `.icn` copies; one place to update IRX.
- **Effort:** S. **Risk:** Med (must confirm which tree the release packaging and the on-card installer actually read — INFERRED that packaging can copy; verify before deleting). **Confidence:** High for the duplication (READ, md5); Med for the fix route (INFERRED).

## POPSLOADER-005 / Five copies of POPSTARTER.ELF tracked; the top-level copy is byte-identical to the DEBUG profile
- **Category:** 2 (duplication) / 7 (repo clutter)
- **Location(s):** POPSLoader/bin/POPSLDR/POPSTARTER.ELF and POPSLoader/bin/POPSLDR/PROFILES/{MAIN,DEBUG,USBDELAY,USBDELAY_DEBUG}/POPSTARTER.ELF — 167,700 B each, 838,500 B total; md5 of the top-level file and PROFILES/DEBUG are both `bbc61fa490df65d9527fcea7c4118170` (the other three profiles differ)
- **Problem:** Five near-identical closed binaries are versioned as files. One pair is an exact duplicate, and nothing in the tree explains why the default ELF is the DEBUG build rather than MAIN.
- **Fix:** Delete the duplicate top-level copy (or the DEBUG profile copy) and have packaging select/copy the chosen profile under the plain name. Separately, confirm in one line of docs which profile the plain name is supposed to be — if "plain = DEBUG" is accidental, that is a release-content bug, not just clutter.
- **Benefit:** 167,700 B tracked removed per duplicate eliminated; removes a real wrong-binary risk.
- **Effort:** S. **Risk:** Low for the byte-identical copy; Med for changing which profile is default (do not change it as part of the tidy-up). **Confidence:** High (READ, md5).

## POPSLOADER-006 / A 1.47 MB source tarball sits unreferenced inside `iop/embed/`
- **Category:** 7 (repo clutter) / 1 (dead file)
- **Location(s):** POPSLoader/iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz (1,466,084 B) alongside the two files actually used from that folder, POPSLoader/iop/embed/BDMASSAULT_MX4SIO/usbd.irx and usbhdfsd.irx
- **Problem:** The tarball is referenced by no Makefile, source file, workflow or script found by grep across the repo; it is a source archive of the adjacent IRX stored inside the build tree.
- **Fix:** Delete it from this repo (keep it with the preservation archive in POPSLOADER-001 if the source must be preserved).
- **Benefit:** 1,466,084 B tracked removed.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ — grep for the filename across Makefile/iop/src/.github returned no references).

## POPSLOADER-007 / UI images are shipped twice: as files in `bin/POPSLDR/IMG/` and embedded in the ELF
- **Category:** 2 (duplication) / 4 (size)
- **Location(s):** POPSLoader/bin/POPSLDR/IMG/ (67 PNG files, 330,675 B total) vs the `bin2c` embedding of the same PNGs at POPSLoader/Makefile:150-200 and registration at POPSLoader/src/embed_assets.cpp:11-130 (`asset_usb_png`, `asset_smb_png`, … `asset_cover_missing_png`)
- **Problem:** The same artwork exists as loose files in the shipped folder and as embedded arrays in the ELF. If the runtime loads from `embed:` (as the boot sound does, ui.lua:1868 `embed:boot.adp`), the loose copies are dead weight on the memory card; if it loads the loose files, the embeds are dead weight in the ELF. Both cannot be the live path for the same image.
- **Fix:** Pick the one path the code actually uses per asset, delete the other copy, and say which in the Makefile comment. Do this asset-by-asset from the `embed_assets.cpp` registry vs Lua file opens — do not bulk-delete.
- **Benefit:** up to ~330 KB removed from either the card payload or the ELF *(est., upper bound = full IMG folder; real figure depends on the per-asset split, INFERRED)*.
- **Effort:** M. **Risk:** Med (a wrong call shows up as a missing UI image — visually obvious, and the splash/icon set is small enough to check). **Confidence:** Med (READ for both copies existing; INFERRED for which path is live per asset — not traced for all 67).

## POPSLOADER-008 / Every settings save writes the file three times on a slow memory card
- **Category:** 5 (performance) / 3 (overengineering)
- **Location(s):** POPSLoader/bin/POPSLDR/system.lua:5233-5260 (`PromoteTmpToDest`: copy dest→`dest..".bak"`, then copy tmp→dest, then delete bak) called by `WriteAtomic` at POPSLoader/bin/POPSLDR/system.lua:5262-…
- **Problem:** `System.rename` is already copy-then-delete (per the code's own comment), so the "atomic" save performs three full copies of the settings/cache file — write tmp, copy to .bak, copy to dest — plus two deletes, on the slowest storage the PS2 has (8 MB memory cards). The safety rationale is documented in the comments (a doubly-failed save must not truncate the live file), and it is real; but the common case pays 3× write time and 3× card wear for a failure mode that needs two independent copy failures in one save.
- **Fix:** Keep the tmp-write + full-write-count check (that part catches the real truncation bug), and drop the .bak copy: promote tmp→dest directly and, only if that promotion fails, leave tmp in place and report the failure instead of restoring. If the maintainer keeps the .bak, restrict it to the small settings file and skip it for the larger game-cache writes.
- **Benefit:** ~2 of 3 file copies removed per save *(est.)* — save latency and card wear cut roughly proportionally on mc: targets.
- **Effort:** S. **Risk:** Med (changes a failure-recovery path that was added for a cited incident, Codex F1 2026-06-20 in the comments — maintainer decision, not a drive-by). **Confidence:** High (READ).

## POPSLOADER-009 / `graphics.cpp` PNG loader repeats the same row-buffer block three times, with a malloc per row
- **Category:** 2 (duplication) / 5 (performance)
- **Location(s):** POPSLoader/src/graphics.cpp:172-186 (CT32 path), POPSLoader/src/graphics.cpp:217-231 (palette/4-bit path), POPSLoader/src/graphics.cpp:267-281 (palette/8-bit path) — the identical `calloc(height, sizeof(png_bytep))` + per-row `malloc(row_bytes)` + `png_read_image` + free-every-row sequence, three copies
- **Problem:** Three copies of the same allocation/read/free logic (~15 lines each) must be fixed in triplicate, and decoding a cover does `height` separate heap allocations (fragmentation + slow on EE) where one contiguous block would do.
- **Fix:** Replace the three copies with one local helper that allocates a single block plus the row-pointer array, reads, and frees both. This is the rare justified shared helper: the logic really does appear 3× verbatim and sharing it removes code overall.
- **Justification (adds a helper):** concrete problem = triplicated allocation logic and per-row malloc fragmentation on a 32 MB machine; the helper is smaller than the three copies it replaces, so net code and net allocations both go down.
- **Benefit:** ~30 lines removed *(est.)*; allocations per PNG decode drop from `height + 1` to 2.
- **Effort:** S. **Risk:** Low (the existing `longjmp` cleanup already centralises freeing via `row_pointers`/`row_count`). **Confidence:** High (READ).

## POPSLOADER-010 / ds34 (DualShock 3/4) driver code exists in three near-copies
- **Category:** 2 (duplication)
- **Location(s):** POPSLoader/modules/ds34bt/iop/ds34bt.c (1,719 lines), POPSLoader/modules/ds34usb/iop/ds34usb.c (806 lines), POPSLoader/modules/pademu/ds34bt.c (1,521 lines), POPSLoader/modules/pademu/ds34usb.c (634 lines); `diff modules/pademu/ds34bt.c modules/ds34bt/iop/ds34bt.c` = 512 differing lines out of ~1,500; byte-identical supporting files across the bt/usb pair: POPSLoader/modules/ds34bt/iop/irx_imports.h = POPSLoader/modules/ds34usb/iop/irx_imports.h, POPSLoader/modules/ds34bt/iop/smsutils.S = POPSLoader/modules/ds34usb/iop/smsutils.S, and the two module Makefiles are identical
- **Problem:** The same DS3/DS4 protocol handling is maintained as a standalone BT module, a standalone USB module, and again inside pademu. Protocol fixes have three places to land and two places to be forgotten.
- **Fix:** Do not rewrite this speculatively. At minimum delete/link the byte-identical support files (imports header, smsutils.S, Makefile) to a single copy; record the pademu-vs-standalone divergence as a known duplicate and consolidate only when one of the copies next needs a real protocol fix.
- **Benefit:** ~4,680 lines under single-maintenance instead of triple *(count READ; consolidation saving INFERRED — a full merge was not scoped)*; immediate small win from the three identical support files.
- **Effort:** L for full consolidation, S for the identical files. **Risk:** High for a merge (IOP modules, hardware-timing sensitive, not verifiable without real pads/hardware); Low for the identical support files. **Confidence:** High (READ).

## POPSLOADER-011 / Generated bin2c output `src/elf_loader/loader.c` (855,821 B) is committed to git
- **Category:** 7 (repo clutter) / 1 (dead/generated code)
- **Location(s):** POPSLoader/src/elf_loader/loader.c (8,740 lines, 855,821 B, header: `unsigned int size_loader_elf = 139700; unsigned char loader_elf[] = {…}`) generated by the rule at POPSLoader/src/elf_loader/Makefile:30-33 (`bin2c src/loader/bin/loader.elf loader.c loader_elf`)
- **Problem:** A generated byte-array dump of a 139,700-byte ELF is the largest source file in the repo. The Makefile comment states the reason plainly: CI validates blob parity by re-running bin2c and `cmp`-ing against the committed file. That is a test of the generator, paid for with an 856 KB file in every checkout and an unreviewable diff whenever the child loader changes.
- **Fix:** Generate `loader.c` at build time (the rule already exists) and replace the parity `cmp` with a hash/size check on the built `loader.elf` recorded at release time. Delete the committed dump.
- **Benefit:** 855,821 B and 8,740 lines of generated text removed from the tracked tree; child-loader diffs become reviewable again.
- **Effort:** M. **Risk:** Med (the parity gate exists because a stale blob shipped once, per the surrounding comments — the replacement check must be in CI before the file is deleted). **Confidence:** High (READ, including the stated justification).

## POPSLOADER-012 / Ten workflows, 2,062 lines, including a one-shot retraction workflow that has done its job
- **Category:** 7 (build/CI clutter) / 8 (half-finished/redundant)
- **Location(s):** POPSLoader/.github/workflows/ — compilation.yml (253), docs-site.yml (165), ember-watch.yml (157), experimental-release.yml (501), official-release.yml (131), opencode.yml (32), research-network-driver-integrity.yml (114), retract-mislabeled-ember-beta.yml (40), rolling-release.yml (576), wiki-sync.yml (93); specifically POPSLoader/.github/workflows/retract-mislabeled-ember-beta.yml:1-40 (its own header: "This cleanup only retracts the accidental same-session 1.3.0-ember-beta.1 POPSLoader tag", and its script exits 0 printing "already removed" when the release is gone)
- **Problem:** Four separate release workflows (rolling 576 + experimental 501 + official 131 + compilation 253 lines) plus a docs-site, a wiki-sync and an ember-watch overlap heavily in build/package steps. Separately, the retraction workflow is a single-use cleanup that re-runs on every matching push forever, checking for a release that no longer exists.
- **Fix:** Delete `retract-mislabeled-ember-beta.yml` now (one-shot, self-describes as done when the tag is absent). For the release family, do not merge them speculatively — but the next time one is edited, extract nothing new; instead delete the duplicated setup/build steps by pointing experimental/official at the compilation workflow's artifact, which official-release.yml already claims to do ("publish the exact passing CI artifact").
- **Benefit:** 40 lines and one permanent no-op workflow removed immediately; up to ~1,000 lines of duplicated workflow YAML identified for the next edit *(est., INFERRED overlap — full YAML diff not performed)*.
- **Effort:** S (retraction) / M (release family). **Risk:** Low (retraction) / Med (release family). **Confidence:** High (READ) for the retraction workflow; Med (INFERRED) for the overlap size.

## POPSLOADER-013 / `opencode.yml` is an AI-comment-bot workflow in a repo already carrying heavy agent sprawl
- **Category:** 7 (CI clutter) / 8 (redundant feature)
- **Location(s):** POPSLoader/.github/workflows/opencode.yml:1-32 (triggers on issue/PR comments containing `/oc` or `/opencode`, runs with `id-token: write`)
- **Problem:** A third-party AI bot with write-token permissions is wired into issue and PR comments. It is not part of building, testing or releasing the loader, and it is an extra credentialed automation surface on a public repo.
- **Fix:** Delete the workflow if the maintainer is not actively using `/oc` in this repo (usage was not verified — no comment history was read). If it is used, keep it; this finding is "justify or delete", not a proven dead workflow.
- **Benefit:** 32 lines and one token-bearing automation removed.
- **Effort:** S. **Risk:** Low. **Confidence:** Med (READ for the workflow; INFERRED for non-use).

## POPSLOADER-014 / Stale branches and checkpoint/backup tags (list only, per brief)
- **Category:** 7 (repo clutter)
- **Location(s):** Remote branches (37): `BETA-3-restarts`, `BETA-8-5`, `BETA-9`, `BETA-12-PLAY`, `CHECKPOINT2`, `dev`, `experimental`, plus 14 `claude/project-thread-*` / `claude/popsloader-*` branches; Tags (37) including `backup/pre-hdd-cache-2026-06-19`, `checkpoint/2026-06-16-audit-fixes`, `checkpoint/BETA-12-PLAY-before-phase3-2026-06-18`, `checkpoint/master-before-beta12-2026-06-18`, `checkpoint/master-before-dkwdrv-merge-20260523-132143`, `checkpoint/master-before-real-dkwdrv-merge-20260523-132313`, plus floating `latest`, `release`, `rolling-release`, `experimental` tags alongside the numbered 1.0.0–1.4.4 and BETA-1…BETA-12 series
- **Problem:** Checkpoint/backup ref names are being used as an archive mechanism inside the live repo; four floating tags duplicate what GitHub Releases already express. Listed only — no deletion performed or directly recommended without the maintainer's call on each ref.
- **Fix:** Maintainer to confirm which checkpoint/backup refs are still load-bearing, delete the rest, and keep version tags only.
- **Benefit:** Ref-list noise removed; no size claim (deleting refs does not shrink the pack until GC).
- **Effort:** S. **Risk:** Med (a checkpoint tag may be someone's only recovery point — human decision per ref). **Confidence:** High (READ — `git branch -r` / `git tag` at the pin).

## POPSLOADER-015 / Docs sprawl at the root: 18 Markdown files, 4,896 lines, plus fossil audit reports in `docs/`
- **Category:** 7 (repo clutter) / 8 (stale docs)
- **Location(s):** Root: POPSLoader/{README, STATE, DECISIONS, ARCHITECTURE, COMPONENTS, CONTRIBUTING, ROADMAP, ROLLING_NOTES, TESTING, QA_REGRESSION_MATRIX, OFFICIAL_NOTES, EXPERIMENTAL_NOTES, AGENTS}.md plus RELEASE_1.3.0.md, RELEASE_1.3.1.md, RELEASE_1.4.0.md, RELEASE_1.4.4.md; POPSLoader/OFFICIAL_NOTES.md and POPSLoader/RELEASE_1.4.4.md are md5-identical (`b6fddc7922bd0c6c1dce14973bc066e3`); POPSLoader/docs/REPO_AUDIT_2026-07-07.md (128,247 B / 385 lines), POPSLoader/docs/AUDIT_CODEX_2026-06-20.md, POPSLoader/docs/HANDOFF_EXP33_2026-07-21.md — dated agent-audit/handoff artefacts kept in the shipped docs tree
- **Problem:** Release notes are duplicated verbatim under two names, per-release files for 1.3.x sit at the root next to living documents, and two prior AI audit reports (one 128 KB) are stored as if they were product documentation. A reader cannot tell which of STATE/ROLLING_NOTES/ROADMAP/DECISIONS is current without reading all four.
- **Fix:** Delete the duplicate of OFFICIAL_NOTES/RELEASE_1.4.4 (keep one name), move RELEASE_1.3.x/1.4.x notes to the GitHub Releases they describe, and move the dated AUDIT/HANDOFF files out of `docs/` (to the preservation archive or deletion — they are point-in-time artefacts, and this audit supersedes the two audit files).
- **Benefit:** ~150 KB and 5–7 root/doc files removed *(est.)*; one obvious "current state" document instead of four candidates.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ; md5 for the duplicate pair).

## POPSLOADER-016 / Sixteen one-shot audit scripts in `.research/tools/` (~2,100 lines) audit a finished recovery, not the product
- **Category:** 1 (leftover test/debug code) / 7
- **Location(s):** POPSLoader/.research/tools/audit_*.py (11 files: bitbucket snapshots, hosted patch members, legacy archive payloads, legacy pages, legacy tool overlap, network driver CRC overlap, original automated parity, original download links, original git history, original wiki zip, original WIP06 2017), compare_recovered_archive_candidates.py, inspect_network_modules_header.py, verify_network_driver_payloads.py, guard_site_deploy.py, audit_published_provenance.py — 31–210 lines each; one workflow still runs a subset: POPSLoader/.github/workflows/research-network-driver-integrity.yml (114 lines)
- **Problem:** These scripts verified a one-time historical-archive recovery. They are not tests of the loader, they do not run against new code, and one CI workflow exists largely to keep them alive. They read as permanent tooling but their questions ("does the 2018 Bitbucket snapshot match…") cannot change answer.
- **Fix:** Move the scripts with the archive (POPSLOADER-001) or delete them, keeping `verify_network_driver_payloads.py` + its workflow only if the maintainer wants the network-IRX byte check as a standing gate.
- **Benefit:** ~2,100 lines of Python and optionally one 114-line workflow removed from the product repo *(counts READ)*.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ — file inventory and purpose headers; INFERRED that the recovery questions are closed, based on the dated, past-tense audit docs).

## POPSLOADER-017 / `lua_dir` puts a 512-entry memory-card table on the EE stack
- **Category:** 6 (bug risk) / 4 (memory)
- **Location(s):** POPSLoader/src/luasystem.cpp:35 (`#define MAX_DIR_FILES 512`), POPSLoader/src/luasystem.cpp:721 (`sceMcTblGetDir mcEntries[MAX_DIR_FILES] __attribute__((aligned(64)));` — a stack array inside `lua_dir`), used at POPSLoader/src/luasystem.cpp:735
- **Problem:** A 512-entry `sceMcTblGetDir` array is allocated on the stack of a Lua C function. At ~64+ bytes per entry that is 32 KB+ of stack for a directory listing of a memory card — the device with the smallest, slowest directories in the system — in a program whose other threads are given stacks as small as 4,096 B (POPSLoader/src/luagraphics.cpp:26). It also caps/defines work for listings that realistically hold a handful of saves.
- **Fix:** Reduce the cap to a realistic MC directory size (e.g. 128) and/or move the array to a single static buffer (this code path is single-threaded through Lua). Keep the `mcGetDir` call and its count argument in sync with whichever size is chosen.
- **Benefit:** ~24 KB+ of worst-case stack removed *(est. from entry count reduction; exact entry size not measured)* and a stack-overflow class removed from the MC browser path.
- **Effort:** S. **Risk:** Low (a card with more entries than the new cap truncates the listing — pick the cap from the MC format's real limits). **Confidence:** High for the allocation (READ); Med for the overflow consequence (INFERRED — main-thread stack size not read).

## POPSLOADER-018 / Network waits block the calling (UI/Lua) thread for up to 30 s at a time
- **Category:** 5 (performance — UI freeze)
- **Location(s):** POPSLoader/src/luasystem.cpp:2096-2105 (`SmbWaitNetState`: `for (int i = 0; i < 30; i++) { if (check()) return 0; sleep(1); }`), with sibling 1-second sleeps at POPSLoader/src/luasystem.cpp:185, :1746, :1754 and POPSLoader/src/luaHDD.cpp:93
- **Problem:** A synchronous 30 × 1 s poll exposed to Lua means any SMB page entry that waits for link/DHCP freezes the interface for up to 30 s if it runs on the UI thread — the exact "UI must never freeze" failure mode. (The bounded ATA wait at luasystem.cpp:1940-1955 shows the codebase already knows the better pattern: 10 ms `usleep` polls with a caller-supplied bound.)
- **Fix:** Shorten the poll step (e.g. 100 ms × a bounded total the caller chooses) and, where the caller is a page entry, surface "waiting for network" through the existing page-state mechanism instead of sleeping in the binding. No new thread or framework needed — reuse the `WaitAtaAsyncBootBounded` shape already in this file.
- **Benefit:** Worst-case UI stall on SMB entry drops from ~30 s to the caller's bound *(est.)*.
- **Effort:** M. **Risk:** Med (network bring-up timing is hardware-sensitive; needs a real-hardware SMB check before being called fixed). **Confidence:** High for the blocking code (READ); Med for it running on the UI thread in all call paths (INFERRED — Lua bindings run on the Lua thread, which drives the UI in this architecture).

## POPSLOADER-019 / `elf.c` carries the launch-argument storage logic twice
- **Category:** 2 (duplication)
- **Location(s):** POPSLoader/src/elf_loader/src/elf.c:404 (`static char launch_arg_storage[2048]`, used ~448) and POPSLoader/src/elf_loader/src/elf.c:487 (a second `static char launch_arg_storage[2048]`, used ~545-557) in the 731-line file
- **Problem:** Two functions in the same file each declare their own 2 KB static arg-storage buffer and drive the same `store_arg` helper — 4 KB of BSS and two copies of the offset/bookkeeping logic for one job.
- **Fix:** Share one static buffer + offset pair between the two call sites (they are sequential phases of the same launch, per the surrounding code) or, if they must be independent, say why in one comment. Delete the second buffer if sharing is safe.
- **Benefit:** 2,048 B of BSS and one copy of the bookkeeping removed *(est.)*.
- **Effort:** S. **Risk:** Med (child-loader launch path — a mistake here is a boot failure; verify on hardware/emulator rig before shipping). **Confidence:** High for the duplication (READ); Med for safe sharing (INFERRED).

## POPSLOADER-020 / `sprintf` into a 16-byte heap buffer, via a pointer truncated to `int`, in the image thread
- **Category:** 6 (bug/security)
- **Location(s):** POPSLoader/src/luagraphics.cpp:276-280 (`char* buffer = (char*)malloc(16); … sprintf(buffer, "%i", (int)image); imgThreadData = (unsigned char*)buffer;`)
- **Problem:** An image pointer is cast to `int` (truncating on any 64-bit host build/harness and fragile even on EE), formatted with unbounded `sprintf` into a fixed 16-byte allocation. On EE today a 32-bit address formats to at most 11 chars, so it happens to fit — but the code is one change (negative values, wider type) away from a heap overflow, and the idiom is copied from an era before `snprintf` was used elsewhere in this codebase (it is: e.g. luasystem.cpp:626).
- **Fix:** Replace with `snprintf(buffer, 16, "%i", …)` — one word changed, no new anything. Separately, pass the pointer as a pointer-sized integer if the thread protocol allows.
- **Benefit:** Removes a latent heap-overflow; no size change.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## POPSLOADER-021 / Unchecked `getcwd` results in the Lua directory bindings
- **Category:** 6 (bug)
- **Location(s):** POPSLoader/src/luasystem.cpp:600 (`getcwd(path, 256);` result ignored in `lua_getCurrentDirectory`, buffer then pushed to Lua at :601) and POPSLoader/src/luasystem.cpp:681 (same pattern in `lua_dir`) — contrast with the same file at :645-650 and :688-695, where later code was fixed to check `getcwd`/length results and raise Lua errors
- **Problem:** If `getcwd` fails, `path` is uninitialised stack content and is pushed to Lua as the current directory / used as the listing base. The file's own later fixes show this class was treated as a real bug everywhere it was reviewed; these two sites were missed.
- **Fix:** Check the return exactly as the neighbouring fixed sites do and return a Lua error / nil on failure. No new helper — copy the existing pattern in the same file.
- **Benefit:** Removes an uninitialised-memory disclosure to Lua scripts and a garbage-path directory listing; ~4 lines added, justified as the simplest fix for a cited, in-file-precedented bug class.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

## POPSLOADER-022 / Translation data exists in three forms: inline Lua, TSV, and a binary XLSX of the TSV
- **Category:** 2 (duplication) / 7
- **Location(s):** POPSLoader/docs/translations/slovak.tsv (410 lines) and POPSLoader/docs/translations/slovak.xlsx (binary, 80 lines when dumped) — the XLSX is read by POPSLoader/tools/translation_handoff.py:202-212 as a second source next to the TSV at :176; plus the shipped form in POPSLoader/bin/POPSLDR/system.lua (see POPSLOADER-003)
- **Problem:** One language's strings live as a spreadsheet, a TSV export of it, and a hand-merged Lua table. Any correction must be made in up to three places, and `translation_handoff.py` (250 lines) plus its test exist largely to police the divergence between the copies.
- **Fix:** Keep the TSV as the single translator-facing source (it is diffable, unlike the XLSX), delete `slovak.xlsx`, and generate the Lua/embedded table from the TSV at build time if POPSLOADER-003 is not done first.
- **Benefit:** One binary file and one whole class of TSV↔XLSX divergence checks removed; the handoff tool shrinks accordingly *(est. ~50-80 lines)*.
- **Effort:** S. **Risk:** Low (confirm no translator works directly in the XLSX — if one does, keep the XLSX and delete the TSV instead; keep exactly one). **Confidence:** High (READ).

## POPSLOADER-023 / Defensive `pcall` + `type()==…` wrapping is the dominant idiom in the Lua UI (370 sites)
- **Category:** 3 (overengineering)
- **Location(s):** POPSLoader/bin/POPSLDR/system.lua (256 `pcall` occurrences), POPSLoader/bin/POPSLDR/ui.lua (114 `pcall` occurrences); representative pattern at POPSLoader/bin/POPSLDR/system.lua:2016-2028 and :6332-6333 (`if type(System) == "table" and type(System.initMX4SIO) == "function" then pcall(System.initMX4SIO) end` repeated for nearly every binding)
- **Problem:** Almost every call to the program's *own* C bindings is wrapped in a type-check plus a `pcall`, as if the bindings were untrusted plugins. These bindings are compiled into the same ELF and versioned with the scripts, so the checks guard against a mismatch that cannot occur in a shipped build — at the cost of hiding real errors (a failing `pcall` is usually discarded) and inflating both scripts.
- **Fix:** Do not mass-edit working code. Set the rule for new/edited code: call own bindings directly, reserve `pcall` for file/network/user-data boundaries (where several are genuinely needed, e.g. the save path), and strip the wrappers opportunistically only in functions already being touched for another reason.
- **Benefit:** Error-swallowing removed where stripped; script size/complexity trend reversed. No immediate byte claim (deliberately not a big-bang rewrite).
- **Effort:** L if done wholesale (not recommended) / S as a style rule. **Risk:** Med wholesale, Low as a rule. **Confidence:** High for the counts (READ); Med for "cannot occur" (INFERRED — a user could in principle pair an old ELF with new scripts from a card install, which is the one scenario the wrappers defend; the maintainer should confirm installs always update both together).

## POPSLOADER-024 / Root-level marketing/loose assets and a stray format diagram
- **Category:** 7 (repo clutter)
- **Location(s):** POPSLoader/banner.jpg (345,431 B), POPSLoader/imageformat.png (root, alongside no other code), plus POPSLoader/.research/assets/ button-prompt PNGs tracked under two names each (e.g. `2667142094-356screenshot1.gif` = `356screenshot1.gif`; `2984521000-Playstation-Button-Select.png` = `3405191067-Playstation-Button-Select.png`; at least 9 exact-duplicate pairs found by md5 across the repo, most in `.research/assets/`)
- **Problem:** Root assets duplicate what a README/social preview needs once, and the research asset dump contains the same images under both their original numeric-prefixed names and cleaned names.
- **Fix:** Delete the duplicate-named copies in `.research/assets/` (keep one name per md5), and move `banner.jpg`/`imageformat.png` under `docs/` or the site assets if they are used there — or delete if orphaned (usage not traced).
- **Benefit:** Small: ~9 duplicate image files plus root tidiness *(sizes READ individually in inventory; total duplicate-image bytes < 1 MB, est.)*.
- **Effort:** S. **Risk:** Low. **Confidence:** High for the duplicate pairs (READ, md5); Low for banner/imageformat orphan status (INFERRED — usage not traced, hence "move or delete after a grep").

## POPSLOADER-025 / Leftover upstream (OPL/Enceladus) TODO block in `fntsys.cpp` describes another project's UI
- **Category:** 1 (dead comments) / 8
- **Location(s):** POPSLoader/src/fntsys.cpp:544, :553, :560 (the same TODO sentence pasted at three sites: "this seems correct, but the rest of the OPL UI (i.e. spacers) doesn't seem to be correctly scaled") and the block TODO at POPSLoader/src/fntsys.cpp:568-575; file is inherited from OPL via Enceladus (Makefile header still brands the build "Enceladus project", POPSLoader/Makefile:22-27)
- **Problem:** Three copies of a TODO about a different project's UI, unresolved and unactionable in this codebase, signal (correctly) that this file was vendored and never audited for this loader. It is a marker for a wider, unscoped question — how much of `fntsys.cpp`'s 946 lines this loader's font paths actually use — which this audit did not fully trace (see footer).
- **Fix:** Delete the three repeated TODO comments and the stale block comment (keep the code). Note the fntsys usage-trace as a follow-up audit item rather than guessing deletions now.
- **Benefit:** ~15 comment lines removed; no code change.
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ).

---

## Evidence notes (things checked and *not* flagged)

- **No secret-like values found:** a grep sweep for AWS-key shapes, `password =`, `api_key` and private-key headers across the tree returned no files. The `.gitignore` (lines ~90-100) documents that Wayback snapshots containing credential-*shaped* archive.org boilerplate were deliberately kept untracked — that decision reads as considered, not as a leak.
- **No `.BAK`/backup files tracked, no `#if 0` blocks** found in src/modules/iop; TODO/FIXME count in native source is small (fntsys ×4 above, ps2atad.c:48 ×1).
- **Unsafe string functions are rare** (7 hits in native source): the bounded-`snprintf` fixes in luasystem.cpp are already done and commented; the remaining real items are POPSLOADER-020 and -021.
- **Build evidence:** `python3 -m py_compile` passes on tools/*.py, .research/build_site.py and audit_site.py. `tools/test_disc_layout.py` could not run in this sandbox (`ModuleNotFoundError: lupa`) — reported as not-run, not as a failure. No PS2 build was attempted: no PS2SDK toolchain in this VM, so **no ELF-size or on-hardware claim in this file is verified by a build** — all byte figures are source/file measurements.
- The embedded-Lua minifier (Makefile:203-215), the stripped child-loader rule (src/elf_loader/Makefile:14-29) and the lazy SMB stack loading (Makefile:101-110) are genuinely good size discipline and should be kept.

## Files not read / not fully read, and why

- **`.research/wiki/` bulk (ps1-codes-in-ps1/ps2-raw-format.md, ~2 MB of cheat-code dumps) and `.research/research/per-agent/*`:** inventoried by size/name and sampled; these are data corpora, not code, and the finding (POPSLOADER-001) does not depend on their content.
- **`src/elf_loader/loader.c` (8,740 lines):** generated bin2c output — identified as generated from its header and generating rule; not line-read, by design.
- **Binary files** (all `.irx`, `.ELF`, `.zip/.7z`, `PATCH_5.BIN`, `boot.adp`, `builtin_font.ttf`, images): identified, sized and md5-compared; contents not disassembled.
- **`modules/ds34bt/iop/ds34bt.c` / `modules/pademu/*.c` full line reads:** compared by diff/wc and sampled; a protocol-level audit of the DS3/DS4 handling was out of scope for the time available — POPSLOADER-010 is therefore a duplication finding, not a correctness verdict on those files.
- **`bin/POPSLDR/ui.lua` (7,599 lines) and `system.lua` (11,784 lines):** read in targeted sections (i18n, save path, boot device logic, sound) plus full grep sweeps; not read line-by-line end to end.
- **`tools/host_harness.py` (2,759 lines) and `.research/build_site.py` (2,377 lines):** headers/purpose and structure read; not fully line-read. Both may contain further one-shot/test-battery bloat — **Category 1/3 pass on these two files is unfinished.**
- **`iop/ata_bd_fast/ps2atad.c` (1,593 lines):** the wait-ladder section (:435-500) read in full; the rest sampled. A full ATA correctness pass is **unfinished**.
- **GitHub PR/issue state and workflow run history:** not read (ref lists were taken from the fresh clone only, per POPSLOADER-014).

## Unfinished categories

- Category 6 (bugs/security) is complete for EE Lua bindings and graphics, **partial** for IOP modules (ds34/pademu/ps2atad correctness not audited).
- Category 5 is **partial** for Lua: game-scan/refresh paths in system.lua/ui.lua were grep-located but not traced end-to-end for repeated-scan behaviour.
- All other categories are complete at the depth stated above.
