# Launchstation — Blind Redo Audit: Docs, Prose, Shipped Data/Config & Assets

- Clone: `~/workspace/audit-clones-2026-11-13/Launchstation`
- HEAD verified: `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (`git rev-parse HEAD`)
- Scope: README.md, CHANGELOG.md, CLAUDE.md / AGENTS.md (policy only, not flagged), docs/**, docs-site/**, storage_driver_fixes_plan.md, USB-STABILITY-AUDIT-2026-10-08.md, docs/LAUNCHELF.CNF and other shipped example configs, Lang/, res/, ship/, __Headers/, exploits/, root clutter. Code files were read only to verify a doc/config claim; both sides are cited.
- Licences: settled per instructions — no finding in this section concerns licence presence, absence or wording.
- Secret-like values: locations only, values never reproduced (see Asset Census §4).
- Method: every in-scope file hashed (SHA-256) by script; claim families counted by script where feasible; findings self-deduped, one mechanism = one candidate, grouped across pages unless the fix differs.

---

## 1. Claim-check ledger

A "claim" is one independently checkable statement (a path, a default, a count, a package member, a stated behaviour). Structural checks (file counts, ID sequences, hash equality, media durations) count once per family.

| Area | Checked | Match | Contradicted | Unverifiable |
|---|---:|---:|---:|---:|
| README.md | 26 | 23 | 1 | 2 |
| CHANGELOG.md (`## Rolling` only; dated sections are history) | 24 | 20 | 3 | 1 |
| docs/ (maintainer docs, wiki, plans' status banners) | 38 | 29 | 7 | 2 |
| docs-site/ (49 content pages + manifest) | 44 | 36 | 6 | 2 |
| Shipped configs/examples (LAUNCHELF.CNF, WLE-CLOUD.CNF.example, theme-example/theme.cfg, KIT-README.txt, kit-externals.json) | 20 | 17 | 2 | 1 |
| Lang/ + themes + structural asset claims | 24 | 23 | 0 | 1 |
| **Total** | **176** | **148** | **19** | **9** |

Unverifiable (not counted as defects): README download-metrics provenance and the externally-dated Neutrino build stamp (internally consistent across README.md:135, CHANGELOG.md:65, docs-site/content/neutrino.html:83, checked 2026-11-13 in the text, but not re-checkable from the clone); translation *quality* of Lang/ catalogues (structure verified, semantics not); hardware-behaviour statements the text itself marks NOT TESTED / pending validation.

Headline verified-true families (details in §5): 18 theme presets, 9 languages × 716 entries, 49/49 docs-site pages, 9-file app packages, visible 4-tab model, Type as default File Browser sort, no-backup updater design in 5 of 6 updater texts.

---

## 2. Asset census (by script, HEAD tree)

In-scope files: **277 files, 20,016,212 B**. Whole repo (non-`.git`): 1,074 files.

### 2.1 Size concentration

| Payload | Bytes |
|---|---:|
| docs-site/ total | 17,359,939 |
| docs-site/static/assets/ui/ alone | 16,709,988 (96% of the site; 83% of all in-scope bytes) |
| docs/ total | 590,964 |
| res/ total | 1,194,898 |
| Largest single file: docs-site/static/assets/ui/theme-highlights.gif | 4,885,148 |
| 2nd: docs-site/static/assets/ui/application-views.gif | 2,894,342 |

Only 10 files in the whole repo exceed 200,000 B; 5 are in scope (the two GIFs, theme-tour.mp4 1,095,595, theme-highlights.mp4 597,007, res/bgm.ogg 462,185) and 3 are generated font C files out of scope here except as DOC-014 evidence (src/dash_font_data.c 591,973; src/dash_font_emotion_engine_bold.c 555,019; src/dash_font_emotion_engine.c 492,279).

Media durations verified with ffprobe/Pillow and **matching** the text: theme-tour.mp4 54.0 s, theme-highlights.mp4 24.0 s, theme-highlights.gif 144 frames / 24,000 ms, application-views.mp4 12.45 s, application-views.gif 75 frames / 12,500 ms.

### 2.2 Duplicates by SHA-256 (in-scope)

Exactly 3 duplicate groups in scope, all explained (see §5):
`CLAUDE.md` = `AGENTS.md`; `docs/theme-example/background.png` = `docs-site/static/assets/wallpaper-example.png`; `res/memory-card/copy.icn` = `del.icn` = `list.icn`.
No other in-scope duplicates. Whole-repo duplicates outside scope are licence texts, IOP import headers/linkfiles and test stubs — not flagged.

### 2.3 Referenced / unreferenced

- docs-site UI images: 66/66 files under `docs-site/static/assets/ui/` are referenced from docs/, docs-site/content/ or README.md (script search) — none orphaned.
- docs-site manifest: 49 slugs = 49 content files, no orphan either way; script found **0 broken internal `.html` links** in docs-site/content/.
- Lang/: 9 `.LNG` files, each exactly 716 `lang(...)` entries, IDs 0–715 sequential, identical (id, key) sequences across all 9 (script-verified, mirroring tests/test_dashboard_languages.py); `Lang/DASHBOARD.inc` keys sorted and unique. Entries identical to English range from 99/716 (SPA) to 136/716 (FRE) — expected for proper nouns/format strings, not a defect. POR vs PTBR share 495/716 strings — **INFERRED** plausible for closely related locales; translation quality not audited.
- Unreferenced payloads that *are* findings: DOC-012 (res/bgm.ogg, exploits/IOPRP.IMG, exploits/XSYSTEM2.XLF).
- res/icons/*.png (17 files): unreferenced by name in code, but res/README.md:14 explicitly classifies them as reference artwork, not embedded/packaged — checked-clean, not a finding. res/icons/rocket-launch.svg *is* a source: src/dash_icons.c:169-170 cites it.

### 2.4 Generated artefacts

- Gated: res/sfx_ps2/*.adp (8 files) — generator scripts/gen_sfx.py with `--check`, plus tests/test_sfx_ps2.py comparing decoded output (SNR > 30) and wiring. Clean.
- Gated: docs/R3Z-CONFIG-PARITY.md — generated by scripts/audit_r3z_settings.py, CI-checked per docs/README.md. Clean (not re-run; no upstream checkout in clone).
- Ungated: the three generated font C files — DOC-014.
- docs/BUILDING.md claims to be generated, with no generator in tree — DOC-016.
- docs-site output itself is generated by docs-site/build.py from manifest+content and CI-built — clean.

### 2.5 Secret-like values — locations only

- Example password fields: docs-site/content/smb.html:45 and docs-site/content/smb.html:51 (presented as worked examples; no statement in the page that they are fictitious — see note in DOC-006 context, not a separate finding).
- Credential field (empty in the shipped template): res/WLE-CLOUD.CNF.example:12.
- Token/secret *handling* locations (no values in tree): scripts/gen_cloud_client.py (env-supplied client id/secret), src/cloud_google.c:200,238-239,483. WLE-CLOUD.TOK and PS2KEYS.dat are .gitignore-excluded and absent from the tree. No actual credential value was found in any in-scope file.

---

## 3. Coverage ledger

### Read in full
README.md (291 lines); CHANGELOG.md Rolling section (lines 1–116, all current claims) plus header; CLAUDE.md/AGENTS.md (15 lines, policy only); storage_driver_fixes_plan.md; docs/README.md; docs/BUILDING.md; docs/font-generation.md; docs/NATIVE_CLOUD.md; docs/ECOSYSTEM-COMPARISON.md; docs/themes.md; docs/dashboard.md (all sections, in chunks); docs/wiki/ all 6 files; docs/LAUNCHELF.CNF (464 lines); docs/theme-example/README.md + theme.cfg; res/README.md, res/UPDATE-CA.md, res/WLE-CLOUD.CNF.example, res/APPINFO.PBT; exploits/README.md; __Headers/README.MD + all 4 system.cnf + all 4 icon.sys; ship/KIT-README.txt, ship/shortcuts/*.url (5), ship/neutrino-ilink/README.txt; Lang/ENG.LNG head + script-verified structure of all 9 + DASHBOARD.inc head; docs-site/manifest.json, docs-site/build.py (head + render logic), docs-site/content/ — all 49 pages read or grep-verified, with full reads of configuration, languages, smb, nfs, building, credits, ecosystem, cloud, mmce-backup, igr, ui-captures, install, releases, settings, getting-started, network, privacy, developers, contributing pages; USB-STABILITY-AUDIT-2026-10-08.md (status banner + body sampled, historical by its own banner).

### Read by script / sampled, not line-by-line
CHANGELOG.md dated sections after line 116 (history by design; sampled); docs/changes.txt (1,027 lines, legacy — header + head read, remainder is pre-2014 uLE history, self-labelled); docs/plans/*.md and docs/superpowers/** (status banners + heads of all 17 files; the 1,087-line 2026-09-26 plan sampled — it carries an "implemented; historical" banner); docs/R3Z-*.md, DISPLAY_FEEDBACK, MMCE_* (heads/banners + grep; historical/policy per docs/README index); docs/*.txt legacy notes (heads + the 2026-10-26 annotation blocks); binary assets (PNG/ADP/ICN/ICO/ELF/IMG/XLF/KERNEL): hashed, sized and reference-checked, not decoded — except CA bundle subjects via openssl (3 certs: Sectigo R46, Sectigo E46, ISRG Root X1), GIF/MP4 durations via ffprobe/Pillow, and icon.sys structure via scripts/package_apps.py checks already in tree.

### Not read, with reason
docs/licenses/*.txt (3 files) and LICENSE, ship/neutrino-ilink/LICENSE, docs/THIRD_PARTY_CREDITS.md beyond grep for ps2build/SMB credits — licence material, explicitly settled/out of scope for findings. ps2.yaml read only for embed/target claims relevant to docs. Code files beyond the cited verification lines were not audited (other redo sections own code).

---

## 4. Candidate findings (sorted by benefit)

### DOC-001 — Updater menu path in README and both wiki guides points to a page that does not contain it
- **Category:** Doc-vs-code contradiction (user-facing wrong instruction) · **Benefit:** High — every user following the manual to update fails to find the control.
- **Evidence (doc):** README.md:104 "Open **Settings → Storage & devices → MMCE backups → Check for updates**"; identical path at docs/wiki/Current-Features.md:49 and docs/wiki/Releases-and-Recovery.md:53.
- **Evidence (code/other docs):** src/dash_settings.c:776 places `S_CHECK_UPDATES` ("Check for updates") in `system_items[]` (src/dash_settings.c:766), i.e. Settings → System; `mmce_backup_items[]` (src/dash_settings.c:366-385) contains no update row. The correct path is already used at docs/dashboard.md:199, docs-site/content/cloud.html:22, docs-site/content/install.html:30, docs-site/content/getting-started.html:22.
- **Mechanism:** The row moved (or was always in System) and three texts kept the MMCE-backups path; the other five texts were updated, so the corpus now contradicts itself.
- **Fix (LESS NOT MORE):** Replace the path with "Settings → System → Check for updates" in the 3 files. No new text.

### DOC-002 — CHANGELOG Rolling says the updater keeps a `.BAK` during the swap and downloads to disk when RAM is short; the updater makes no backup and is RAM-only
- **Category:** Doc-vs-code contradiction (safety-relevant) · **Benefit:** High — a user who believes a `.BAK` exists during the in-place overwrite will not keep their own known-good ELF.
- **Evidence (doc):** CHANGELOG.md:13 "The old ELF is kept as `.BAK` only during the swap and deleted once the new one is in place" and "When there is enough free memory the package is downloaded into RAM and unpacked from there, so no `.PACKAGE` file is written".
- **Evidence (code):** src/self_update.c:218-219 "Write the verified ELF over the running one… no second file, rename, delete or backup"; src/self_update.c:279-280 "Remove a .BAK left by an older build (none is made any more)"; install path refuses when the RAM buffer is unavailable — no `.PACKAGE`/disk fallback exists in src/self_update.c (grep: no PACKAGE path). README.md:104, docs-site/content/install.html:31 and docs/wiki/Releases-and-Recovery.md:59 all correctly state no backup/second copy is made.
- **Mechanism:** One Rolling bullet retained the superseded swap design while the code and every other updater text moved to direct overwrite.
- **Fix:** Delete the `.BAK`-during-swap clause and the conditional-RAM clause from CHANGELOG.md:13; replace with the no-backup wording already used in install.html:31.

### DOC-003 — Automatic IGR sync default stated as Off in two texts; code default is Local backup
- **Category:** Doc-vs-code contradiction (behaviour/privacy expectation) · **Benefit:** High — users are told no automatic backup runs by default when a local backup *does* run after OPL IGR returns.
- **Evidence (doc):** docs/NATIVE_CLOUD.md:95 "It is off by default"; docs-site/content/cloud.html:14 "It is off by default".
- **Evidence (code/other docs):** src/dash_store.c:263 `dashCfg.igr_auto_backup = 1;` with `igr_cloud_sync = 0` (src/dash_store.c:264), and the mode mapping at src/dash_settings.c:1163 (auto=1, cloud=0 → mode 1 = Local backup). Correctly stated at docs-site/content/mmce-backup.html:52 "(default)" on Local backup, docs-site/content/igr.html:26 "(default: Local backup)", and docs-site/content/configuration.html (Dash_IGRAutoBackup default 1).
- **Mechanism:** Two texts froze the pre-default-change value.
- **Fix:** Change "off by default" to "Local backup by default" in the 2 files. No new text.

### DOC-004 — CNF rename to LAUNCHSTATION.CNF not propagated through dashboard.md and the LAUNCHELF.CNF template header
- **Category:** Doc-vs-code contradiction (one mechanism, 6+ locations) · **Benefit:** High-medium — maintainer reference and the shipped template describe the wrong file as the live, writable config.
- **Evidence (doc):** docs/LAUNCHELF.CNF:17-21 "Launchstation loads it unchanged… This file is only rewritten (without comments) when a classic setting is saved in Settings, or a File Browser bookmark is added or removed"; docs/dashboard.md:46 bookmarks "(saved in LAUNCHELF.CNF…)"; docs/dashboard.md:357-364 dashboard files sit "Next to LAUNCHELF.CNF…" and "LAUNCHELF.CNF itself is never modified behind your back"; also docs/dashboard.md:211-213, :478.
- **Evidence (code):** src/main_boot.c:62-66 — the live file is `LAUNCHSTATION.CNF`; an old `LAUNCHELF.CNF` is imported **read-only** and "saves go to the same folder under our name". CHANGELOG.md (Rolling, #346 entry) states "Nothing writes `LAUNCHELF.CNF` any more." docs-site/content/configuration.html and docs/dashboard.md:199-area System row already use the new name elsewhere.
- **Mechanism:** The #346 rename updated the site/configuration pages but not the maintainer dashboard reference or the template's 2026-10-26 "verified against the source" header note (docs/LAUNCHELF.CNF:14-26), which now certifies a superseded claim.
- **Fix:** In docs/LAUNCHELF.CNF header, state the file is a legacy-format template, imported read-only, with saves written to LAUNCHSTATION.CNF (wording already exists in src/main_boot.c:62-66 — copy that, add nothing else). In docs/dashboard.md replace the 5 LAUNCHELF.CNF-as-live-file references with LAUNCHSTATION.CNF.

### DOC-005 — Shipped LAUNCHELF.CNF template contradicts itself on the Triangle launch key
- **Category:** Shipped example config internal contradiction · **Benefit:** Medium — a user who drops the template in as-is gets different behaviour from what its own comment promises.
- **Evidence:** docs/LAUNCHELF.CNF:80 comment "Circle starts the file browser… and Triangle shows About"; docs/LAUNCHELF.CNF:88 sets `LK_Triangle_E1 =` (empty). Code default (no CNF) does set Triangle to About: src/config.c:828 `strcpy(setting->LK_Path[SETTING_LK_TRIANGLE], setting->Misc_About_uLE);` — and docs-site/content/configuration.html's key table likewise gives "Circle = MISC/FileBrowser, Triangle = About" as the default. Loading the template overrides that default with empty.
- **Mechanism:** Template value line was emptied without updating the comment (or vice versa).
- **Fix:** Set line 88 to `LK_Triangle_E1 = MISC/About uLE` **or** delete the Triangle clause from the line-80 comment — one line either way.

### DOC-006 — SMB site page credits libsmb2 as the SMB2 driver; the shipped driver is source-built usmb2
- **Category:** Doc-vs-code contradiction (attribution/technical) · **Benefit:** Medium — wrong driver identity on the user-facing SMB page; the Credits page in the same site says the opposite.
- **Evidence (doc):** docs-site/content/smb.html:86 "using the SMB2 driver from [libsmb2]".
- **Evidence (code/other docs):** docs-site/content/credits.html:17 "smb: uses smb2man (iop/smb2man, source-built): Ronnie Sahlberg's usmb2… it replaced the prebuilt libsmb2 smb2man.irx"; CHANGELOG.md Rolling "smb: built from source, on RiptOPL's SMB2 driver" entry; docs-site/content/architecture.html:4 lists `smb2man (SMB2/SMB3, usmb2)`.
- **Mechanism:** Footer sentence survived the driver replacement.
- **Fix:** Replace "libsmb2" with "usmb2" in smb.html:86 (one word, matching credits.html:17). Note: the same page's worked examples at smb.html:45,51 use password-shaped example values with no "example only" marker — when editing this page, label them as examples (location-only note from §2.5, values not reproduced here).

### DOC-007 — CHANGELOG Rolling NFS entry gives the pre-split settings location for NFS shares
- **Category:** Doc-vs-code contradiction (Rolling = current summary) · **Benefit:** Medium — Rolling is republished as the release-page summary, so the stale path is the most visible NFS instruction in the repo.
- **Evidence (doc):** CHANGELOG.md:16 "(Settings > Network > SMB shares, Server type **NFS**, with User ID and Group ID rows)".
- **Evidence (code):** NFS shares have their own page — src/dash_settings.c:746 `{ST_PAGE, P_NFS, "NFS shares", …}` under Network, with a dedicated editor array (src/dash_settings.c:717, "The same editor, for NFS shares"); the SMB editor itself says at src/dash_settings.c:705 "NFS shares have their own page: Settings > Network > NFS shares." README.md:164 and docs-site/content/nfs.html:8 already give the correct location.
- **Mechanism:** Entry written against the combined editor, not updated when the page split.
- **Fix:** Replace the parenthetical in CHANGELOG.md:16 with "(Settings > Network > NFS shares, with User ID and Group ID rows)".

### DOC-008 — Documentation-site Ecosystem page is a full revision behind the Ecosystem markdown it mirrors
- **Category:** Cross-doc divergence (site stale vs Reference markdown) · **Benefit:** Medium — the published site understates shipped features and lists finished work as future work.
- **Evidence (site):** docs-site/content/ecosystem.html:7 table — "No 3D icons and no 'All saves' view", Card contents copies "one save at a time", and its closing list calls templates "later work that needs design decisions".
- **Evidence (markdown/code):** docs/ECOSYSTEM-COMPARISON.md:30-31 — "**All saves here...** lists the saves of every card image in a folder…" (#232), batch copy/move/delete of marked saves from All saves; the same file documents the folder-based Library and manually applied sets as in (#232). Feature exists in code: src/dash_browser.c:2808 `ADD(DI_MC, "All saves here...", …)`. docs/README.md classifies ECOSYSTEM-COMPARISON.md as Reference (current).
- **Mechanism:** The markdown was updated for #232; the site HTML twin was not regenerated/rewritten.
- **Fix:** Update the 3 stale cells + closing list item in ecosystem.html from ECOSYSTEM-COMPARISON.md:30-31 and its §"Suggested order" — replace, do not add a second comparison.

### DOC-009 — res/README.md resource inventory is wrong on sounds, missing on the PS2 sound set, and lists 2 CA roots for a 3-root bundle
- **Category:** Doc-vs-assets contradiction (one inventory, 3 defects) · **Benefit:** Medium — this is the only map of res/; packagers and builders rely on it.
- **Evidence:** (a) res/README.md:8 lists `boot` among `sfx/*.adp` "Embedded by src/embed_blobs.S" — src/embed_blobs.S:82-88 embeds only cursor/confirm/cancel/transition/message/bd_connect/bd_disconnect from res/sfx/ (7 files, no boot); the boot sound actually embedded is the PS2 set's, src/embed_blobs.S:96. The 143,984 B res/sfx/boot.adp is therefore an embedded-claim file that no build file embeds. (b) The table has **no row at all** for res/sfx_ps2/ (8 files, all embedded at src/embed_blobs.S:91-98 and gated by tests/test_sfx_ps2.py). (c) res/README.md:9 "Public roots…: Sectigo Public Server Authentication Root R46 and ISRG Root X1" (2 roots) — the bundle contains 3 certificates (openssl subject check) and res/UPDATE-CA.md's table lists all 3 including Sectigo E46, whose addition the same file says was required for GitHub verification.
- **Mechanism:** Inventory not updated when the PS2 sound theme was added, when classic boot was dropped from the embed list, or when E46 was added to the bundle.
- **Fix:** Correct row 8 (remove boot, or mark it not embedded), add one sfx_ps2 row, add E46 to row 9. Net: edit 2 rows, add 1.

### DOC-010 — dashboard.md calls the embedded interface sounds "Sony ADP samples"; the repo's own provenance statements say the opposite / unrecorded
- **Category:** Provenance contradiction · **Benefit:** Medium-low — a false provenance claim in the maintainer reference, in a repo that elsewhere is careful to say "original, not Sony".
- **Evidence (doc):** docs/dashboard.md:372 "They are Sony ADP samples embedded in the ELF".
- **Evidence (other docs/code):** docs/dashboard.md:380 itself says the PS2 set is "synthesized by scripts/gen_sfx.py (original tones, not Sony samples)"; scripts/gen_sfx.py:6 "Nothing is sampled from Sony firmware"; res/README.md final paragraph: "The origin and license of the audio and icon artwork are not recorded in this repository" (for the classic set).
- **Mechanism:** One blanket sentence claims a provenance the rest of the corpus either denies (PS2 set) or declares unrecorded (classic set).
- **Fix:** Replace the sentence at docs/dashboard.md:372 with the two-set description already at docs/dashboard.md:380. Delete, don't add.

### DOC-011 — Two animated GIFs duplicate their MP4s at 8–9× the size and dominate the published site and offline ZIP
- **Category:** Oversized / duplicated payload · **Benefit:** Medium — 7,779,490 B of GIF vs 934,378 B for the same content as MP4; the site total is 17,359,939 B and the offline documentation ZIP ships the same assets.
- **Evidence:** docs-site/static/assets/ui/theme-highlights.gif 4,885,148 B vs theme-highlights.mp4 597,007 B (same 24 s content, durations verified §2.1); application-views.gif 2,894,342 B vs application-views.mp4 337,371 B (same 12.5 s content). Both GIFs are offered only as secondary links beside an embedded MP4: docs-site/content/ui-captures.html:9 (highlights GIF as alternate link; tour video embedded) and the applications `<details>` block (MP4 embedded, GIF as link); README.md:66-70 likewise embeds the GIF under a `<details>` whose primary offer is the MP4 tour.
- **Mechanism:** GIF kept as a fallback after MP4 delivery was added; no size gate in docs-site/build.py.
- **Fix (LESS NOT MORE):** Delete both GIF files and their 3 link mentions; keep the MP4s and PNG posters. Net −7,779,490 B, −2 files. (If a GIF is ever re-added, gate it in build.py — not requested now.)

### DOC-012 — 491,822 B of payload files are referenced by no build, script, test or doc-as-used asset
- **Category:** Unreferenced binaries · **Benefit:** Medium-low — dead weight in every clone and in the repo-size badge the README advertises; the exploit files in particular invite mistaken editing.
- **Evidence:** res/bgm.ogg 462,185 B — res/README.md:15 itself: "Not referenced by any build script and not packaged" (the packaged BGM is res/music.sad, scripts/package_apps.py:37,44). exploits/IOPRP.IMG 15,741 B and exploits/XSYSTEM2.XLF 13,896 B — exploits/README.md:26-27 itself: "are in the directory but are not referenced by any current build file; only IOPRP_LTS.IMG is embedded" (embed list at src/embed_blobs.S:52-68 confirms). Total 462,185 + 15,741 + 13,896 = 491,822 B.
- **Mechanism:** Source/legacy material retained in shipped directories after its consumer was removed, with the READMEs documenting deadness instead of the files being removed.
- **Fix:** Delete the 3 files; delete the corresponding README sentences (res/README.md:15 row, exploits/README.md:26-27 note). If bgm.ogg must be kept as audio source, it belongs outside res/ — moving it is still a deletion from the shipped tree.

### DOC-013 — Plan/follow-up status layer is stale: a merged feature is labelled "not merged", and the newest plans carry no status at all and are absent from the docs index
- **Category:** Stale plan presented as current · **Benefit:** Medium-low — an agent or maintainer resuming from these files would redo or re-litigate finished work.
- **Evidence:** docs/follow-ups/move-manifest.md:3 "Implemented on the draft PR branch; not merged. NOT TESTED on hardware." — but the mechanism is in HEAD code (src/filer_copy.c:124 `#define MOVE_MANIFEST_LIMIT`, :143 `filerMoveBegin`) with a host suite at tests/test_move_manifest.py. Separately, docs/superpowers/plans/2026-11-04-hide-tabs.md and docs/superpowers/specs/2026-11-04-boot-defer-design.md / 2026-11-04-hide-tabs-design.md open with **no status banner**, unlike every Oct plan/spec which carries a dated 2026-10-26 status (e.g. docs/plans/2026-10-18-cloud-handoff.md:2); the hide-tabs feature is implemented (src/dash_themes.c:131 `tabs_ids[]`, DASH_TABS_HIDDEN in include/dash_internal.h:187). docs/README.md's index lists plans/superpowers only up to the 2026-09-26 items and never lists docs/follow-ups/ at all.
- **Mechanism:** The 2026-10-26 status-banner pass predates the November files and the move-manifest merge; the index was not extended.
- **Fix:** Add the standard one-line status banner to the 4 files (move-manifest: merged, hardware untested; Nov-4 trio: implemented) and add one index line for docs/follow-ups/ in docs/README.md. No new documents.

### DOC-014 — 1,639,271 B of generated font C has no source font in the repo and no regeneration/comparison gate
- **Category:** Generated artefact without source or check gate · **Benefit:** Medium-low — the artefacts cannot be reproduced or verified from the clone; a silent hand-edit or generator drift would be undetectable.
- **Evidence:** src/dash_font_data.c:2 "GENERATED by scripts/gen_dash_font.py, do not edit" (591,973 B), src/dash_font_emotion_engine.c:2 (492,279 B) and the bold twin (555,019 B) — total 1,639,271 B. docs/font-generation.md states "Original TTF files are not redistributed in this repository" and gives their SHA-256 hashes, i.e. the hashes cannot be checked against anything in tree. No workflow or test regenerates or compares them: grep finds gen_dash_font referenced in tests/test_font_weight.py:16 only to parse the generator's *code* for runtime font tests, and .github/workflows/compile.yml has no font-regeneration step. Contrast res/sfx_ps2/, which has both a `--check` mode and a content test (§2.4).
- **Mechanism:** Font pipeline kept the "do not edit" label but not the reproducibility gate its sibling audio pipeline has.
- **Fix (smallest):** Add a `--check`-style verification to scripts/gen_dash_font.py is **not** possible without the TTFs — so instead record, in docs/font-generation.md, the generated files' own SHA-256 hashes (3 lines) and check those in tests/test_maintained_documentation.py, so any drift is at least detected. Do not add new tooling.

### DOC-015 — architecture-maintenance.md overstates CI test coverage and its largest-files list is already wrong
- **Category:** Doc-vs-tree contradiction · **Benefit:** Low-medium — maintainers trusting "every test runs in CI" will assume two suites gate releases when they do not.
- **Evidence:** docs/architecture-maintenance.md:44 "Every `tests/test_*.py` script is listed there [compile.yml]". Script count: 213 test_*.py files, 211 named in .github/workflows/compile.yml; unlisted: tests/test_boot_deferred_init.py, tests/test_usb_stat_timeout.py. Same file §"Refactoring history": "The largest hand-written sources today are src/dash_settings.c, src/dash_browser.c, src/init.c, src/main_exploit_installer.c and src/filer_browser.c" — by line count src/dash_card_tool.c (2,903) exceeds both src/main_exploit_installer.c (2,519) and src/filer_browser.c (2,528) and is omitted (wc -l: dash_settings 4,096; dash_browser 3,616; init 3,205; dash_card_tool 2,903).
- **Mechanism:** Two November-era tests and one grown file postdate the note.
- **Fix:** Either list the 2 tests in compile.yml (preferred, one line each in the existing step) or soften the sentence to match BUILDING.md's accurate "CI runs an explicit list"; add dash_card_tool.c to the largest-files sentence.

### DOC-016 — BUILDING.md claims to be generated from building.html; no generator exists, and the three build-prerequisite lists disagree
- **Category:** False generation claim + cross-doc divergence · **Benefit:** Low — contributors editing the "source" HTML will expect the MD to follow; it will not.
- **Evidence:** docs/BUILDING.md:189 "This file is generated from `docs-site/content/building.html`; keep the two in sync." No generator: grep for BUILDING across scripts/*.py, docs-site/build.py and .github/workflows/compile.yml returns nothing that writes docs/BUILDING.md; tests/test_maintained_documentation.py only asserts shared substrings (ps2build_sdk.sh --llvm, ps2build.dev URL) in both files. The files differ in length and content (17,663 vs 14,746 chars; BUILDING.md §12 Claude Code session section has no full HTML counterpart). Prerequisite lists diverge further: README.md:196 requires GNU `timeout` and `setsid`, which appear in **neither** docs/BUILDING.md nor building.html (script check for both terms: absent in both), while BUILDING.md requires sha256sum/host gcc/NumPy, which README.md:196 omits.
- **Mechanism:** A manual-sync relationship was mislabelled as generation, and README's prerequisite list was written independently.
- **Fix:** Change BUILDING.md:189 to "kept in sync manually with" (one line), and add `timeout`/`setsid` to BUILDING.md's tool list (or delete them from README.md:196 if the installer no longer needs them — verify against scripts/ps2build_sdk.sh first). 

### DOC-017 — __Headers/ ships four APA header sample sets for other applications with a one-line, misspelled README and no usage or provenance note
- **Category:** Shipped sample data, undocumented · **Benefit:** Low — a user browsing the repo (or a device, via the HDD Manager's header-source picker) cannot tell these are samples, whose they are, or that injecting one overwrites a partition header.
- **Evidence:** __Headers/README.MD:1 is the entire documentation: "# APA INJECTON SAMPLES" [sic]. The tree holds PP.ULE (icon.sys title0 = uLaunchELF; system.cnf `BOOT2 = pfs:/EXECUTE.KELF`), PP.OPL (`BOOT2 = pfs:/OPL.KELF`), PP.GSM (`BOOT2 = pfs:/GSM.KELF`) and PP.FHDB.APPS (`BOOT2 = pfs:/EXEC.KELF`) — none is Launchstation itself, and nothing in the folder says so, nor that the consumer is src/hdd_header_injector.c (file specs at :71-72: icon.sys, list.ico) driven from src/dash_hdd.c:800 ("Write the APA header of hdd0:%s from %s__Headers/%s/? Required: system.cnf; PS2 titles also icon.sys and list.ico").
- **Mechanism:** Sample data carried over without the explanatory README its sibling folders (res/, exploits/, ship/) all have.
- **Fix:** Expand __Headers/README.MD to the 4–5 lines the other folders use: what the sets are, that they are third-party app samples (not Launchstation), and that the HDD Manager injects them. Fix the spelling in passing. No new files.

---

## 5. Checked-clean notes

- **Themes = 18, verified.** src/dash_themes.c:171-189 `presets[P_COUNT]` has exactly 18 entries (osd…discred); README.md:22,59,165, docs/themes.md:15-19, docs-site/content/themes.html:8 and docs/wiki/Current-Features.md all say 18. OSD Classic is the default in code and in every text.
- **Languages = 9 × 716, verified by script.** See §2.3. docs-site/content/languages.html's "0–715" and "468–715" ranges match max index 715 and the test_maintained_documentation.py assertions; Lang/DASHBOARD.inc is sorted/unique.
- **Visible tab model = 4, verified.** src/dash_main.c:48 `visible_sections[] = {HOME, FILES, TOOLS, SETTINGS}`; DASH_SEC_APPS/DEVICES are internal screens (src/dash_main.c:43-46), exactly as docs/wiki/Current-Features.md explains. README.md's L1/R1 and tab-table wording matches. (docs/dashboard.md's "four top-level tabs" is therefore also correct.)
- **File Browser sort/show defaults, verified.** src/dash_browser.c:83 `fb_sort = FB_SORT_TYPE`; show modes = 4. README.md, docs/dashboard.md, docs/wiki/Current-Features.md and the annotated header of "docs/FileBrowser sort+display modes.txt" (which correctly labels its own classic text as superseded, Name-default included) all agree with current code.
- **App package contents = 9 files, verified.** scripts/package_apps.py members (ELF, title.cfg, APPINFO.PBT, WLE-UPDATE-CA.PEM, BGM.ADP from res/music.sad, icon.sys/list.icn/copy.icn/del.icn) match README.md's download table, docs/BUILDING.md §8, ship/KIT-README.txt and docs-site/content/install.html. BOOT.ELF/BOOT2.ELF are byte-copies of the standard ELF in code (LOOSE_ELFS, package_apps.py) as documented. title.cfg generated by package_apps.py uses lowercase `title=`/`boot=` matching the OPL parser contract in src/dash_lib.c:283 and tests/test_opl_title_cfg.py.
- **Updater design (except DOC-001/DOC-002 locations), verified.** RAM download + 4 MiB reserve, SHA-256, PSU ELF location, missing-sidecar-only restore, free-space growth check: src/self_update.c matches docs-site/content/developers.html:20, settings.html:128, install.html:31 and docs/wiki/Releases-and-Recovery.md:59.
- **Configuration defaults sampled (18 keys), verified.** configuration.html's LAUNCHSTATION.CNF table (Init_Delay 1, Hide_Hdd 5, TV_mode 0, REBOOT_IOP_ELFLOAD 1, VirtualKeyboardLayout qwerty, USBKBD_USED 0, Menu_Hide_Paths 1, Menu_Show_Titles 1, PSU_* 0, FB_NoIcons 0, language english…) matches include/config_private.h:8-49 DEF_* values; DASHBOARD.CNF table (Dash_RecentCount 8, Dash_SoundVolume/BGMVolume 80, Dash_MMCEBackupKeep 10, Dash_IGRAutoBackup 1 / IGRCloudSync 0, Dash_Disabled_Tabs bit values 1/4/16/32 vs include/dash_internal.h:611 DASH_TAB_MASK and section indices) matches src/dash_store.c defaults.
- **LAUNCHELF.CNF template defaults (except DOC-005), verified.** Init_Delay = 1 (docs/LAUNCHELF.CNF vs DEF_INIT_DELAY = 1), USBKBD_USED = 0, REBOOT_IOP_ELFLOAD = 1, Hide_Hdd = 5, Screen_Offset_X/Y = 0 all match include/config_private.h; the template's own note correctly discloses that its GUI_Col_* values are old example defaults, not built-ins — not counted as a contradiction. Its list of no-longer-read keys matches configuration.html's legacy-keys paragraph.
- **CA bundle (except res/README row, DOC-009).** 3 certificates in res/WLE-UPDATE-CA.PEM; subjects match res/UPDATE-CA.md's 3-row table; package_apps.py enforces ≥2 certs and the PSU/ELF checks it claims.
- **docs-site structure, verified by script.** 49 manifest slugs = 49 content files; 0 broken internal .html links; all 66 UI assets referenced; capture manifest (build 974, revision 97318e…) matches README.md:59, docs/UI-CAPTURES.md and ui-captures.html:3 statements; media durations match their stated seconds (§2.1).
- **Duplicate assets are intentional.** memory-card copy/del/list.icn byte-identity is documented in src/embed_blobs.S ("copy.icn and del.icn are byte-identical to list.icn") and enforced by package_apps.py icon.sys reference checks; theme-example/background.png duplication is required for a standalone loadable theme folder; CLAUDE.md = AGENTS.md is a policy mirror (not flagged per instructions).
- **Historical/plans layer (except DOC-013).** storage_driver_fixes_plan.md and USB-STABILITY-AUDIT-2026-10-08.md both carry dated 2026-10-26 status banners correctly labelling themselves index/historical, naming superseded numbers and open hardware items; the same applies to all Oct-dated docs/plans/*, docs/superpowers 2026-09-26 pair, docs/changes.txt, docs/TODO.txt and the legacy docs/*.txt annotations. docs/README.md's Reference/Policy/Historical/Legacy classification matches the files' own banners for every file it lists.
- **Neutrino/kit statements internally consistent.** Kit Neutrino version stamp, SMB-backend absence, and "kit failure can leave an older kit attached" agree across README.md:135, CHANGELOG.md:65, docs-site/content/neutrino.html:83, ship/KIT-README.txt and scripts/package_kit.py's manifest SMB check. Ember/POPStarter user-supplied-file warnings (bios.bin 512 KB, POPS_IOX.PAK, IOPRP.IMG) agree across README, KIT-README and install pages.
- **No secret values in tree.** See §2.5. SMB server default login is a documented product default in code (src/config.c, SMB_Server_User/Pass defaults) and docs — a documented default, not a leaked credential, and not flagged.
- **ECOSYSTEM-COMPARISON.md numbering gap** (its "Suggested order" runs 1, 2, 4, 5, 6): cosmetic only, meaning unambiguous — noted here, not raised as a finding (LESS NOT MORE).

---

## 6. Totals

- Candidate findings: **17** (DOC-001 … DOC-017 — count taken from the `### DOC-` headings in §4).
- By category: Doc-vs-code contradiction 9 (DOC-001, 002, 003, 004, 005, 006, 007, 015, 016); Cross-doc divergence 2 (DOC-008, 010 — DOC-009 counted under Doc-vs-code/assets, making contradictions 10 in the ledger sense; see §4 category lines per finding); Stale status 1 (DOC-013) plus DOC-008 as stale-site; Payload/asset 3 (DOC-011, 012, 014); Shipped-sample documentation 1 (DOC-017).
- Claim-check totals: **176 checked — 148 match, 19 contradicted, 9 unverifiable.**
- Coverage: 277 in-scope files hashed; ~120 read in full, remainder script/sampled as itemised in §3; not-read items are licence texts only, for the stated reason.
