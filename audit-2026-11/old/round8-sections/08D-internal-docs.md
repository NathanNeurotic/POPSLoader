# Round 8 — Section D: Launchstation internal docs claims audit

Repo: `~/workspace/audit-clones-2026-11-13/Launchstation`
Pin: `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (verified held before and after; `git status` clean throughout — read-only).
Method: every assigned doc read in full; load-bearing present-tense claims checked against code/tests at the pin; three test suites and one audit script actually executed; CA fingerprints recomputed from the shipped PEM; cited merge hashes checked for ancestry of the pin.
Exclusion: `docs/licenses/` (3 files: Emotion-Engine-LICENSE.txt, Material-Design-Icons-LICENSE.txt, Roboto-COPYRIGHT.txt) — licence texts, not claims; excluded per assignment.

## File census

| # | File | Lines | Class |
|---|------|------:|-------|
| 1 | docs/plans/2026-10-17-issue-triage.md | 56 | Handoff/triage with 2026-10-26 status banner |
| 2 | docs/plans/2026-10-17-storage-driver-lifecycle-172-175.md | 191 | Plan + implementation follow-up notes |
| 3 | docs/plans/2026-10-18-cloud-handoff.md | 54 | Superseded handoff snapshot |
| 4 | docs/plans/2026-10-18-dev9-transition-follow-up.md | 46 | Follow-up record |
| 5 | docs/plans/2026-10-18-tester-follow-up.md | 64 | Follow-up record |
| 6 | docs/plans/2026-10-19-zack-issues.md | 192 | Work checklist + validation record |
| 7 | docs/plans/2026-10-24-stable-issue-recovery.md | 45 | Recovery record (current copy contract) |
| 8 | docs/plans/2026-10-26-sd2cloud-parity-plan.md | 100 | Plan + 2026-10-28 implementation update |
| 9 | docs/plans/pc-card-cf-integration.md | 144 | Plan + implementation evidence checkpoints |
| 10 | docs/plans/wlaunchelf-r3z-oct17-parity.md | 65 | Historical parity audit |
| 11 | docs/follow-ups/move-manifest.md | 42 | Implementation/validation note |
| 12 | docs/superpowers/plans/2026-09-26-osdsys-dash.md | 1,087 | Agent task-list plan (checkboxes unmaintained) |
| 13 | docs/superpowers/plans/2026-11-04-hide-tabs.md | 164 | Agent task-list plan |
| 14 | docs/superpowers/specs/2026-09-26-osdsys-dash-design.md | 180 | Design spec |
| 15 | docs/superpowers/specs/2026-11-04-boot-defer-design.md | 41 | Design spec |
| 16 | docs/superpowers/specs/2026-11-04-hide-tabs-design.md | 35 | Design spec |
| 17 | docs/R3Z-10-PARITY-AUDIT.md | 80 | Pinned parity audit + status banner |
| 18 | docs/R3Z-11-GAME-ID-AUDIT.md | 82 | Pinned channel audit + status banner |
| 19 | docs/R3Z-CONFIG-PARITY.md | 89 | Config mapping (machine-checked) |
| 20 | docs/R3Z-REQUEST-VALIDATION.md | 150 | Validation record for PR #208 |
| 21 | docs/report-follow-up.md | 107 | Report disposition record |
| 22 | docs/TODO.txt | 8 | Annotated historical (2014) |
| 23 | docs/changes.txt | 1,027 | Annotated upstream changelog to wip7 (2014) + credits |
| 24 | docs/keyboard.txt | 66 | Legacy key map + 2026-10-26 verified annotation |
| 25 | docs/FileBrowser sort+display modes.txt | 63 | Legacy modes + 2026-10-26 annotation |
| 26 | docs/Multiple USB_mass drives and partitions.txt | 72 | Legacy note + 2026-10-26 annotation |
| 27 | docs/New resolutions.txt | 89 | Legacy note + 2026-10-26 "PARTLY CURRENT" annotation |
| 28 | USB-STABILITY-AUDIT-2026-10-08.md (root) | 322 | Historical audit + console-result log |
| 29 | storage_driver_fixes_plan.md (root) | 25 | Index into canonical storage plan |
| 30 | exploits/README.md | 34 | Payload inventory |
| 31 | res/README.md | 18 | Resource inventory |
| 32 | res/UPDATE-CA.md | 35 | Trust-bundle record |
| 33 | AGENTS.md | 15 | Attribution policy |
| 34 | CLAUDE.md | 15 | Attribution policy (byte-identical duplicate of AGENTS.md) |

Total: 34 files, 4,803 lines.

## Future-tense / non-claim-checkable share

Approximately 2,900 of 4,803 lines (~60%) are not present-tense claim-checkable:

- Pure task-list / plan / design material written before the work: osdsys-dash plan body (~1,060 of 1,087 lines), hide-tabs plan (164), hide-tabs + boot-defer + osdsys specs (~250), the implementation-sequence and test-matrix sections of the storage plan (~90), SD2Cloud ranked implementation order (~25), PC-CF work stages (~30), triage "Acceptance still needed" columns.
- Historical records whose claims are scoped to a named past SHA/date and are therefore history, not present-tense assertions about the pin: changes.txt legacy body (~1,000), TODO.txt legacy body, the pre-annotation legacy bodies of the three .txt notes (~180), USB audit console-result log (~250), cloud-handoff (54, self-labelled superseded snapshot).
- Hardware-acceptance checklists and "remaining acceptance" columns throughout (not claims at all — open questions).

The checkable remainder (~1,900 lines) is dominated by the 2026-10-26 status banners/annotations the maintainer added across the set, the R3Z audit trio, the follow-up validation records, and the two root READMEs. Those annotations are where every contradiction below lives: the set was carefully re-annotated on 2026-10-26, and the code moved afterwards (pin is 2026-11-13).

## Claim-group table

| Group | Doc(s) | Verdict |
|-------|--------|---------|
| G1 Move-manifest validation: "PSU backup/restore, complete listing … host suites pass" | move-manifest.md:26-30 | **CONTRADICTED** (C1) |
| G2 Move manifest status: "Implemented on the draft PR branch; not merged" | move-manifest.md:3 | **CONTRADICTED** (C2) |
| G3 Video modes: "Auto, NTSC, PAL, VGA, 480p and 576p (TV_mode = 0..5)" | New resolutions.txt:8-10 | **CONTRADICTED** (C3) |
| G4 File Browser sorts: six sort modes listed; "Name (default)"; "ELF files are NOT moved above other files" | FileBrowser sort+display modes.txt:6-13 | **CONTRADICTED** (C4) |
| G5 Transfer chunking: "Slow MC/VMC operations use 16 KiB chunks" | 2026-10-19-zack-issues.md #184 row | **CONTRADICTED** (C5) |
| G6 CA bundle contents: "Sectigo … Root R46 and ISRG Root X1" (two roots named) | res/README.md:9 | **CONTRADICTED** (C6, minor) |
| G7 MMCE ping budget: `MMCE_PING_ATTEMPTS = 2`, 200 ms timeout retained | storage plan status + follow-ups; storage_driver_fixes_plan.md | MATCH — `iop/mmceman/src/mmceman.c:21` `#define MMCE_PING_ATTEMPTS 2`; `iop/mmceman/src/mmce_cmds.c:26` uses `&timeout_200ms` |
| G8 Storage lifecycle in tree: pre-RPC frames (`startSync`), generation-aware audio shutdown, refused-reset guards, `load_ps2dev9()` returns/propagates failure, `setStartupDriverStatusQuiet` | storage plan banner; dev9 follow-up; tester follow-up | MATCH — `src/dash_devices.c:723` `startSync`; `src/init.c:2163` `resetRuntimeDeviceState`, `:2266` `switchStorageDriverStack` (returns int), `:487` `static int load_ps2dev9(void)` with propagated failures at `:630`/`:724`; `src/init.c:405` `setStartupDriverStatusQuiet` |
| G9 Merge/status banners: PRs #176/#177/#178/#179/#181/#183/#188/#190/#206/#208 merged at cited hashes | triage, cloud-handoff, dev9, zack, stable-recovery, R3Z-REQUEST-VALIDATION banners | MATCH — all ten cited hashes (`f29a28f ef02e7a f4b621f 82082b6 59bb620 8494c3f 593f16d 6906a53 b815d10 fa8f814`) verified ancestors of the pin via `git merge-base --is-ancestor` |
| G10 Copy contract: direct overwrite `genRemove(out)` then `genOpen(WRONLY\|TRUNC\|CREAT)`; LS-COPY/LS-OLD transaction removed | stable-issue-recovery.md; zack-issues banner | MATCH — `src/filer_copy.c:1382` `genRemove(out)`; `tests/test_copy_pipeline.py:19` asserts `LS-COPY-`/`LS-OLD-` tokens gone; suite executed at pin: PASS |
| G11 Nine language catalogs, IDs appended after 467, legacy IDs preserved | stable-issue-recovery.md localization contract | MATCH — `Lang/` holds exactly 9 LNG files; `tests/test_dashboard_languages.py:25-27`; suite executed at pin: PASS ("nine catalogs, legacy IDs…") |
| G12 Config parity: all 61 upstream key families mapped, editors reachable | R3Z-CONFIG-PARITY.md; R3Z-10 banner; R3Z-REQUEST-VALIDATION follow-up | MATCH — executed at pin: `python3 scripts/audit_r3z_settings.py` → "PASS: 61 upstream persisted key families mapped, controls reachable, report current"; `tests/test_r3z_config_inventory.py` → PASS |
| G13 MMCE Game ID: `ensureMmceGameIdControl()` (R3Z-12); Neutrino passes `-bsd=<backend>` not `-bs`; 15-poll bound; command numbers PING 0x1 / GET_STATUS 0x2 / SET_GAMEID 0x8 | R3Z-10 banner + table; R3Z-11 | MATCH — `src/init.c:2350` `ensureMmceGameIdControl`; `src/neutrino_iso.c:252` `"-bsd=%s\n…"`; `src/neutrino_gameid.c:17` `MMCE_SWITCH_POLLS 15`, `:14-16` command defines |
| G14 SD2Cloud foundations: MMCE command map GET_CARD 0x3 / SET_CARD 0x4 / GET_CHANNEL 0x5 / SET_CHANNEL 0x6 / SET_CARD_CHANNEL 0xa; #226 update (parser/writer, Card contents, `SET_CARD`/`SET_CHANNEL` switching, mmce_card_switch) in tree | sd2cloud-parity-plan.md | MATCH — `iop/mmceman/include/mmce_cmds.h:11-21` enum sequence yields exactly those values; `src/mc_card_view.c`, `src/mc_card_write.c`, `src/mmce_card_switch.c`, `src/dash_card_tool.c` all exist |
| G15 PC CARD CF: listed as "PC CARD CF", ROM 0100/0101/0110/0120 + JC gate, `loadPcCardCfModules()`, direct launch blocked, `tests/test_pccf*` | pc-card-cf-integration.md banner | MATCH — `src/dash_devices.c:410-419`; `src/init.c:249-250` ROMVER strncmp set; `src/dash_devices.c:614`, `src/filer.c:997` loader calls; test files present |
| G16 USB audit status: usbd-ra vendored/target, at most 4 probes 600 ms apart, Tools > USB unit diagnostics shipped | USB-STABILITY-AUDIT banner | MATCH — `ps2.yaml:46` target `usbd_ra` from `iop/usbd-ra/…`; `src/dash_devices.c:32-33` `DASH_USB_PROBE_ATTEMPTS 4` / `DASH_USB_PROBE_DELAY_US 600000`; `src/dash_tools.c:61` diagnostics entry |
| G17 Boot-defer design: identity + sound deferred to `fade_in > 0.95f` step in DashRun loop | superpowers/specs/2026-11-04-boot-defer-design.md | MATCH — `src/dash_main.c:1508-1515` runs `dashConsoleIdentityInit(); dashSoundInit(); dashBgmStart();` under exactly that threshold (plus worker/park guards the spec did not foresee) |
| G18 Hide-tabs design/plan: `tabs` theme key, `DASH_TABS_HIDDEN`, presets never hide | superpowers/specs+plans 2026-11-04-hide-tabs | MATCH — `include/dash_internal.h:187` `DASH_TABS_HIDDEN`; `src/dash_themes.c:131` `tabs_ids`, `:800` key-table entry |
| G19 OSDSYS plan/spec status: streaks/clouds backgrounds, Light Show preset, SFX subsystem, ELF-folder-first THEMES lookup in tree; BGM as loose `BGM.ADP` not embedded | superpowers osdsys plan/spec banners | MATCH — `src/dash_themes.c:114` bg ids include `"streaks", "clouds"`, `:461` lightshow preset; `res/sfx/*.adp` (8 files) present |
| G20 Keyboard annotation: USB keyboard OFF by default (`USBKBD_USED = 1` to enable) | keyboard.txt:5-9 | MATCH — `include/config_private.h:38` `DEF_USBKBD_USED = 0` |
| G21 Four visible tabs (Home, Files, Tools, Settings); Devices at top of Files | report-follow-up.md banner | MATCH — `src/dash_main.c:48` `visible_sections[] = {DASH_SEC_HOME, DASH_SEC_FILES, DASH_SEC_TOOLS, DASH_SEC_SETTINGS}` |
| G22 Browser layout: ten rows, 25 virtual px each, list y=100..350 of 448 canvas | R3Z-REQUEST-VALIDATION.md; R3Z-03 row | MATCH — `src/dash_browser.c:33-36` `FB_ROWS 10`, `FB_ROW_H 25.0f`, `FB_Y 100.0f` |
| G23 Exploit payload inventory: embed symbols, IOPRP.IMG/XSYSTEM2.XLF unreferenced | exploits/README.md | MATCH — `src/embed_blobs.S:53-70` defines exactly the tabulated symbols incl. `exploit_ioprp_img` from `IOPRP_LTS.IMG`; no build file references IOPRP.IMG/XSYSTEM2.XLF |
| G24 CA fingerprints (all three DER SHA-256) | res/UPDATE-CA.md | MATCH — recomputed from `res/WLE-UPDATE-CA.PEM`: R46 `7bb647a6…`, ISRG X1 `96bcec06…`, E46 `c90f26f0…` — all three identical to the doc |
| G25 music.sad: APCM header, ≤1 MiB, packaged as BGM.ADP, not embedded; packager refuses CA bundle with <2 certs | res/README.md | MATCH — file is 284,656 bytes; `scripts/package_apps.py:42` size/APCM check, `:40` `ca.count(cert_start) < 2` refusal |
| G26 File Browser annotation remainder: four Show modes; folders always first; Date-Time ascending = oldest first; choices session-only | FileBrowser sort+display modes.txt:6-13 | MATCH (except C4) — `src/dash_browser.c:2740` show_names (4); `fbCompare` (`:224-228`) dirs first; date compare (`:238-241`) ascending |
| G27 Multiple-USB annotation: MASS public name, usbN: internal / massN: alias, USB unit diagnostics, "Start devices automatically" | Multiple USB_mass….txt:5-16 | MATCH — `src/dash_lib.c:177` "MASS Storage"; `src/dash_tools.c:61`; `src/dash_settings.c:351` autostart page |
| G28 Issue-triage UI items: exit label "Leave"; MASS breadcrumb for usbN: paths; software clock checkpoint in DASHBOARD.CNF | 2026-10-17-issue-triage.md | MATCH (spot) — `src/dash_tools.c:1603` `action_label = "Leave"`; `src/dash_settings.c:2494-2533` software_clock persisted in dashCfg |
| G29 changes.txt / TODO.txt present-tense exposure | both | MATCH-by-annotation — both carry 2026-10-26 headers explicitly disclaiming currency; legacy bodies make no Launchstation claims. No contradiction filed |

## CONTRADICTED — full detail

### C1. move-manifest.md claims the PSU/listing host suites pass; the CI-wired PSU listing suite fails deterministically at the pin

- Doc quote (docs/follow-ups/move-manifest.md:25-30): "Validation: - Existing copy pipeline, listing callers, PSU backup/restore, complete listing, short-I/O and Get Size host suites pass. - The new manifest suite passes with address/undefined-behavior sanitizers…"
- Code/test evidence: `tests/test_copy_psu_listing.py` — the PSU backup/restore + listing suite for exactly this feature area — is CI-wired (`.github/workflows/compile.yml:71`) and **fails deterministically at the pin** (reproduced by this audit): assertion failure at `tests/test_copy_psu_listing.py:557` in the Cut→PSU-backup Move-to-UDPFS case (`udpfs_read_opens==2` expectation), harness abort (SIGABRT). This is the already-filed **LAUNCHSTATION-187**; the underlying bug is not re-filed here — the false validation claim is the new docs finding.
- Nuance: the manifest suite itself (`tests/test_move_manifest.py`, compile.yml:69) was executed and **does** pass, peak manifest 262144 bytes as claimed. The falsehood is the blanket "PSU backup/restore, complete listing … suites pass" sentence in the same Validation block.
- Impact: a reader trusting the follow-up note believes the Move/PSU area is host-verified; CI at the pin is red on precisely that area.
- Fix judgement: LESS-not-more — correct the Validation block to name the failing suite and link LAUNCHSTATION-187; do not delete the (accurate) manifest-suite lines.

### C2. move-manifest.md says "not merged"; the feature is merged and in the pinned tree

- Doc quote (docs/follow-ups/move-manifest.md:3): "Implemented on the draft PR branch; not merged. NOT TESTED on hardware."
- Code evidence: the manifest implementation is in the pinned tree — `src/filer_copy.c:135` `move_manifest` state, `:139-151` lifecycle; `tests/test_move_manifest.py` present and CI-wired (`compile.yml:69`); implementing commit `5c4083f` ("Delete Move sources only from a verified bounded manifest", 2026-11-02) verified ancestor of the pin.
- Impact: status line misstates the shipped state of a safety-relevant feature (source-deletion policy). The "NOT TESTED on hardware" half remains true and should stay.
- Fix judgement: one-line banner update ("merged 5c4083f; not hardware-tested"). Borderline staleness, filed as CONTRADICTED because it is a present-tense factual assertion about the tree, in a follow-up doc (not a dated plan).

### C3. New resolutions.txt "PARTLY CURRENT" header omits the 576i video mode and understates the TV_mode range

- Doc quote (docs/New resolutions.txt:8-10): "Video modes available now: Auto, NTSC, PAL, VGA, 480p and 576p (TV_mode = 0..5)."
- Code evidence: `include/launchelf.h:536-545` — `enum TV_mode { TV_mode_AUTO = 0, TV_mode_NTSC, TV_mode_PAL, TV_mode_VGA, TV_mode_480P, TV_mode_576P, TV_mode_576I, TV_mode_COUNT }` (0..6); `src/dash_settings.c:966` `tv_names[] = {"Auto", "NTSC", "PAL", "VGA", "480p", "576p", "576i"}`.
- Impact: anyone hand-editing LAUNCHELF.CNF from this note can conclude 576i does not exist / TV_mode=6 is invalid.
- Fix judgement: amend the header line to seven modes, 0..6. (The rest of the header — offset limits, 640×448 canvas, Settings > Appearance > Screen calibration — verified MATCH, G26-family.)

### C4. FileBrowser sort+display annotation: wrong sort list, wrong default sort, and a false ELF-grouping claim

- Doc quote (docs/FileBrowser sort+display modes.txt:9-13): "Sort by: As stored, Name (default), Game title, Size, Date-Time, Kind, each Ascending or Descending. Folders are always first; ELF files are NOT moved above other files…"
- Code evidence, three parts:
  1. There are **seven** sort modes, not six: `src/dash_browser.c:74-81` enum ends `FB_SORT_KIND, FB_SORT_TYPE, FB_SORT_COUNT`; `:2741` `sort_names = {"As stored", "Name", "Game title", "Size", "Date-Time", "Kind", "Type"}`. "Type" is omitted from the doc.
  2. The default is **Type, not Name**: `src/dash_browser.c:83` `static int fb_sort = FB_SORT_TYPE;`.
  3. Under that default, ELFs **are** grouped above other files: `fbFileType()` (`src/dash_browser.c:208-218`) orders FOLDER < ELF < TEXT < OTHER and `fbCompare`'s `FB_SORT_TYPE` case (`:245-254`) sorts by that group first. The "NOT moved above" sentence is true only for the Name sort (`fbCompare` dir-check at `:224-228` plus name compare), which is not the default.
- Impact: the annotation is the doc a user/maintainer reads to learn current browser behaviour; all three errors are in the four-line "current" summary, while the legacy body below it (which the header correctly labels outdated) actually describes grouping behaviour closer to the shipped default.
- Fix judgement: rewrite the Sort-by bullet: seven modes, default Type, folders first, Type groups ELF above text/other files.

### C5. zack-issues #184 row claims 16 KiB chunks for slow MC/VMC operations; the shipped copy path uses 128 KiB for MC/VMC destinations

- Doc quote (docs/plans/2026-10-19-zack-issues.md, #184 row): "Slow MC/VMC operations use 16 KiB chunks; recursive deletion refreshes between entries…"
- Code evidence: `src/filer_copy.c:92-96` `copyBufferSize()` — writing to `mc`/`mass`/`vmc`/CF destinations uses `buffSize = 131072` (128 KiB); no 16384 chunk size exists in the copy path (grep over `src/filer*.c`, `src/dash_files.c` finds none), and the chunk comment at `src/filer_copy.c:78-80` states "a 128 KB chunk takes seconds on a memory card". Corroborating in-set evidence: docs/plans/2026-10-24-stable-issue-recovery.md states PR #206 removed "the dashboard-specific MC/VMC buffer cap" — i.e. the 16 KiB cap was deliberately removed, but the zack doc's banner marks only its #187 protocol as superseded, leaving the 16 KiB sentence standing as current work description.
- Impact: low user impact (performance behaviour, not data safety), but it is a present-tense mechanism claim in the doc that serves as the #184 record, and it inverts the actual responsiveness trade-off the current code documents.
- Fix judgement: strike/annotate the 16 KiB clause in the #184 row, cross-referencing the #206 buffer restoration.

### C6. res/README.md understates the updater CA bundle's contents (omits the E46 root)

- Doc quote (res/README.md:9): "`WLE-UPDATE-CA.PEM` … Public roots for GitHub HTTPS: Sectigo Public Server Authentication Root R46 and ISRG Root X1."
- Evidence: `grep -c "BEGIN CERTIFICATE" res/WLE-UPDATE-CA.PEM` = **3**; recomputed DER SHA-256 fingerprints identify them as R46, ISRG Root X1 **and Sectigo Public Server Authentication Root E46** — matching res/UPDATE-CA.md's three-row table exactly (G24). UPDATE-CA.md further records that the bundle *without* E46 failed live verification against api.github.com/github.com, so the omitted root is the load-bearing one.
- Impact: minor — a maintainer pruning the bundle from the README alone could remove the root that makes the updater verify at all.
- Fix judgement: add E46 to the README row (one clause).

## Unverifiable from source (at the pin)

- All hardware/console claims and tester reports: SCPH-30001R stall reports, console USB freeze narrative and per-candidate results (USB audit), PS2CF SCPH-10000 hardware test, RetroGem decode recognition, MMCE card-switch identity on real adapters, SD2PSX/MemCard PRO2/PicoMemcard behaviour (all docs themselves mostly label these unverified — no contradiction filed).
- External CI/GitHub facts: cloud-handoff CI run 39133999893 "all 97 workflow test scripts" at `e62dbfb`; pc-card Actions run 38838799371 at `cdcafb1`; zack-issues "All 104 Python host checks pass" at `54a7bc9` and "documentation generator builds 35 pages and 262 search entries"; CodeRabbit review states. SHA-scoped history; cannot be re-derived from the pinned tree.
- Live-network observations in res/UPDATE-CA.md (GitHub chain verification results, Sectigo URL provenance) — fingerprints verified (G24), the live checks themselves not reproducible offline.
- Upstream-side comparisons requiring the upstream checkout (R3Z audits' upstream rows, `06b06d0` inventory regeneration, PS2CF pinned import provenance) — Launchstation-side rows verified; upstream side taken on trust.
- Exact timing/latency figures stated as measurements (e.g. ~800 ms / ~2400 ms MMCE ping budgets are labelled theoretical in-doc and check arithmetically; tester one-minute clock offset explicitly not reproduced in-doc).
- report-follow-up.md's supplied source report (`wlaunchelf issues.txt`) is not in the repo; dispositions were checked against code, the report itself was not.

## Dead references

| Reference | Named in | State at pin |
|-----------|----------|--------------|
| `agent_delivery_assist/*.png`, `*.adp`, `bgm.ogg`, `osdbits-master/` | osdsys spec:28-38; osdsys plan:30,543,568-570 | Directory does not exist in the repo. The plan itself calls it "(untracked)"; the spec presents it as reference material without that caveat. Payloads did land (`res/sfx/*.adp`), the source folder is unrecoverable from the repo. |
| `.codex-worktrees/oct18-feedback` worktree; `.cloud-deps`, `.test-tmp` | cloud-handoff.md:50-54 | Local-machine paths, absent (expected for a handoff snapshot; the doc is banner-marked superseded). |
| `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua` (working local POPSLoader reference) | R3Z-REQUEST-VALIDATION.md:28-30 | External local checkout, not in this repo; the geometry claims drawn from it were verified against Launchstation code (G22-family) but the reference itself cannot be re-inspected from the repo. |
| `wlaunchelf issues.txt` | report-follow-up.md:13 | Supplied report file, not in repo. |
| Gemini's suggested branch `fix/zack-storage-driver-loading-and-audio` | storage plan:13 | Referenced only to forbid creating it — intentional, not dead. |
| All other in-repo cross-references checked (docs/MMCE_SD2PSXTD_FIRMWARE_AUDIT.md, docs/EMBER-RETROGEM.md, docs/dashboard.md, docs/themes.md, CHANGELOG.md, scripts/release_notes.py, scripts/copy_test_pack.py, scripts/audit_r3z_settings.py, tests/fixtures/r3z-06b06d0-config-keys.json, and every tests/test_*.py named in the follow-up docs) | various | Exist at pin. No broken in-repo doc links found in the set. |

## Internal inconsistencies (within the assigned set)

1. **Attribution policy vs handoff instruction (direct contradiction).** AGENTS.md:5 and CLAUDE.md:5 (identical files): "Do not add `Co-Authored-By` trailers for Claude, ChatGPT, Codex, OpenAI, or other AI models or tools to commits." docs/plans/2026-10-18-cloud-handoff.md:54: "Every commit must credit OpenAI, e.g. `Co-authored-by: OpenAI <noreply@openai.com>`." Both cannot be followed; the handoff is banner-marked superseded (2026-10-26) but never retracts this line. Coordinator note: AGENTS.md/CLAUDE.md being byte-identical duplicates is itself a drift risk, though not a falsehood.
2. **SD2Cloud plan body vs its own update banner.** Banner (2026-10-28) states PR #226 implemented guarded `SET_CARD`/`SET_CHANNEL` switching; Foundation 1 (body, "kept as written") still states "The app calls only PING, GET_STATUS and SET_GAMEID (`src/neutrino_gameid.c`)". The banner discloses the body is the original plan, so this is an acknowledged, not hidden, inconsistency — but a reader who stops at Foundation 1 gets a false picture of the shipped EE code (`src/mmce_card_switch.c` exists, G14).
3. **Test-count drift across the R3Z validation record.** R3Z-REQUEST-VALIDATION.md body quotes 16, then 27, then 35 focused scripts in successive dated sections; its banner acknowledges counts "were true when written". Not a contradiction — flagged so the coordinator does not mistake the layered counts for three competing claims. Same pattern in report-follow-up.md ("eight tests" body vs banner noting CI now runs the whole `tests/` set).
4. **move-manifest.md vs itself (see C1/C2).** The same 42-line note contains a merged-feature status line saying "not merged" and a validation block claiming suites pass that includes the deterministically failing PSU listing suite — the set's least reliable single document at the pin, despite its mechanism description (4 KiB → 256 KiB manifest, 262144-byte peak) verifying exactly.
5. **zack-issues vs stable-issue-recovery on chunking (see C5)** and on the copy contract generally: the stable-recovery doc correctly records the #206 removals; the zack doc's supersession banner covers only #187, so its #184 row silently lags the later doc.

## Cross-references to existing findings (not re-filed)

- **LAUNCHSTATION-187** — the underlying deterministic `test_copy_psu_listing.py` failure. Section D files only the false validation claim about it (C1).
- **LAUNCHSTATION-028** (stale docs, pass 1) — stands. Everything in C2–C6 postdates or escapes that finding: C3/C4 are falsehoods inside the 2026-10-26 "current" annotations themselves; C5/C6 are mechanism/inventory falsehoods in records presented as current. Pure plan staleness (superseded banners, dated SHA-scoped counts, unmaintained checkboxes in the superpowers plans) was **not** filed, per instructions.
- The copy-contract, language-catalog and config-parity groups (G10–G12) corroborate areas covered by earlier rounds' code findings; no new code findings are raised here.

## Summary counts

- Files audited: 34 (4,803 lines); `docs/licenses/` excluded (3 licence files).
- Future-tense / historical / non-checkable share: ~60% (~2,900 lines).
- Claim groups checked: 29 — MATCH 23, CONTRADICTED 6 (C1–C6), plus an unverifiable list of 6 categories.
- Executed at pin: `test_copy_psu_listing.py` (FAIL — LAUNCHSTATION-187), `test_move_manifest.py` (PASS), `test_copy_pipeline.py` (PASS), `tests/test_dashboard_languages.py` (PASS), `tests/test_r3z_config_inventory.py` (PASS), `scripts/audit_r3z_settings.py` (PASS).
- Dead references: 4 real (1 acknowledged-untracked asset folder, 2 local-machine paths, 1 supplied report file) + 1 intentional non-reference.
- Internal inconsistencies: 5 (1 direct policy contradiction, 1 banner-vs-body, 2 acknowledged count drifts, 1 cross-doc lag).
