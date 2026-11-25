# Redo Verification — POPSLoader Chunk H (docs-vs-code)

**Subject:** `Redo-POPSLoader.md` findings RE-POPS-059, 060, 073, 074, 107, 108, 109, 110, 111, 112, 113, 114, 115
**Clone / pin:** `~/workspace/audit-clones-2026-11-13/POPSLoader` at `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (verified `git rev-parse HEAD` = pin, tree clean)
**Method:** refute-first. Every cited doc passage opened at the cited lines; every cited code location opened; historical/dated framing checked against present-tense framing; self-contradiction findings checked on both sides; `wc -l` and `tools/docs_verify.py` re-run at the pin.

---

### RE-POPS-059 — WEAKENED

**Evidence (verified limbs):**
- `STATE.md:65` — verbatim: `SMB/network = PS2 IP 192.168.1.10, gateway/DNS 192.168.1.1, server 192.168.1.100, share games, user guest, port 1111 (DHCP stays ON). Reset Defaults targets these`. This sits under `## Experimental channel state (EXP32–EXP73) — current goal state` (STATE.md:42), not in an archive, and asserts in present tense what Reset Defaults targets.
- `TESTING.md:131` — `Port (default 1111 — set this to your server's actual SMB port; stock SMB servers listen on 445…)`; `TESTING.md:135` — `Port (default 1111)`. Both in the current tester checklist.
- `ROLLING_NOTES.md:130` — `Port — default 1111, set it to your server's real SMB port; stock servers listen on 445`, under `## 🆕 Currently testing`.
- `README.md:178` — table row `| User / Password | (guest) |`, while `README.md:175` in the same table correctly says `No defaults are supplied for any network field.` Internal contradiction confirmed.
- Code, `bin/POPSLDR/system.lua:5760-5768` block comment: `NO DEFAULT VALUES for anything POPSTARTER reads… Blank now means blank`; `system.lua:5771-5788` `PLDR.SMB_FIELDS`: `DHCP default = false`, `PS2_IP`/`NETMASK`/`GATEWAY`/`SERVER`/`PORT`/`SHARE`/`USER`/`PASS` all `default = ""`. No `1111` anywhere in the Lua/C code except that comment recounting the removed guess.

**Reasoning (why not full VERIFIED):** Two of the seven cited instances are historical-framed bug explanations, not present-tense statements of the current default, and the finding does not distinguish them:
- `STATE.md:237`'s DHCP clause — `SyncSmbDat deleted the IPCONFIG.DAT … whenever IP assignment was DHCP — the shipped default` — is past tense inside a `FIXED and HARDWARE-CONFIRMED` Known-Issues entry explaining why the old bug hit DHCP users. It describes the then-shipped default. (The same entry's closing sentence, `the SMB Port default 1111 is deliberate`, *is* present-tense and stale — that half of the limb stands.)
- `ROLLING_NOTES.md:177` — `older builds deleted the file that carries it whenever IP assignment was set to DHCP, which is the default` — explicitly scoped to "older builds"; the relative clause is at best ambiguous, not a clean current-default assertion.

**True scope:** the defect is real and tester-harming at STATE.md:65, TESTING.md:131, TESTING.md:135, ROLLING_NOTES.md:130, README.md:178, and the closing note of STATE.md:237. The DHCP-as-current-default limb rests only on STATE.md:65 (`DHCP stays ON`); the two narrative mentions (STATE.md:237 first half, ROLLING_NOTES.md:177) should not be counted as present-tense instances. Fix (delete/correct to blank/Static/445-on-blank) is LESS-sane: pure doc deletion/correction, no new machinery.

**Duplicate check (vs RE-POPS-074):** legitimate split — see RE-POPS-074 block.

---

### RE-POPS-060 — VERIFIED

**Evidence:**
- Doc side, all verbatim at the cited lines: `ARCHITECTURE.md:253` `| 6 | i.Link | **stub** (ui.lua:4318) |`; `COMPONENTS.md:474` `i.Link (OPT6): NOT implemented (ui.lua:4462)`; `README.md:84` `i.Link is experimental (Ember only, untested on hardware)`; `README.md:139` `experimental: Ember games only`; `README.md:263` `It lists and launches **Ember** games only… POPSTARTER titles over i.Link are not implemented`; `QA_REGRESSION_MATRIX.md:44` `i.Link remains unimplemented`; `ROLLING_NOTES.md:149` `the not-yet-implemented **iLink** stub` (in the current "Currently testing" section, not the historical channel notes).
- Scene-list omissions confirmed on both sides: `ARCHITECTURE.md:219-221` enumerates `GUSBFAT=1, GSMB=3, GMX4SIO=4, GHDD=5, GBDMHDD=6, GSMBNET=7, MMAIN=8, MPROFILE=9, CREDITS=10` — no GILINK; `COMPONENTS.md:277-282` scenes enum likewise omits GILINK.
- Code side, all confirmed: `bin/POPSLDR/ui.lua:1067` `GILINK = 11`; `ui.lua:6425-6450` OPT 6 dispatch calls `PLDR.InitILINKRoot()`, `PLDR.GetPS1GameLists(ilink_root.."POPS/", …)` and `UI.SceneChange(UI.SCENES.GILINK)`, with the in-code comment at 6426-6427 stating Ember *plus* POPSTARTER VCDs via the staged `.ilink` pair; `bin/POPSLDR/system.lua:9166-9176` `PLDR.InitILINKRoot`; `system.lua:5161` `BDMA_SUFFIX.ILINK = ".ilink"`; `system.lua:10699-10702` ILINK launch policy for POPSTARTER (`BuildLaunchPolicy("ILINK", "mass", "ilink0", …)`); `system.lua:8862-8863` Ember root on the GILINK scene.
- Corroboration: `bin/changelog [1.4.2]` — `i.Link page for Ember games` + `POPSTARTER titles on the i.Link page, using RiptOPL's i.LINK driver pair`. README self-contradiction confirmed: STATE.md:149 / STATE.md:187 and the changelog formulation (Ember + POPSTARTER) coexist with the three Ember-only README passages.
- Fix (replace prose with the STATE formulation; add `GILINK = 11` to both enumerations) is LESS-sane.

---

### RE-POPS-073 — VERIFIED

**Evidence:**
- `ROLLING_NOTES.md:125` — verbatim: `your saved BDMA Mode decides there. Keep it on exFAT-USB if your USB drive is exFAT; anything else means FAT32. Default Off; nothing changes unless you turn it on.`
- `TESTING.md:162` — verbatim: `If it's FAT32: any other saved mode is fine — USB launches remove the drivers so POPStarter's built-in stack runs`.
- `ARCHITECTURE.md:640` — `BDMA_ADAPTIVE (per-launch BDMA variant staging, default off; see STATE.md)`.
- Code: `bin/POPSLDR/system.lua:6236` `PLDR.BDMA_ADAPTIVE = true` (comment block 6230-6235 explains the default was flipped because it "shipped false" and never ran); `system.lua:8004-8011` — `if device_page == "USB" then … return "USBEXFAT"`, with comment `AUTO (Adaptive) ALWAYS stages USBEXFAT for USB (maintainer directive 2026-07-25)… The old saved-preference gate is gone`.
- Current rule stated correctly where the finding says: `docs/LAUNCH_ARGUMENTS.md:15` `Adaptive BDMA is on by default (changed 2026-07-28)`; `README.md:161` `With Adaptive BDMA on, USB launches always stage the exFAT-USB pair… Default On — changed 2026-07-28`. STATE.md:109 likewise says default On since 2026-07-29 / EXP70.
- Fix (rewrite the three passages to the EXP70 rule) is LESS-sane.

---

### RE-POPS-074 — VERIFIED-DRIFT

**Evidence:**
- Doc side verbatim: `TESTING.md:131` lists `Games path (folder holding POPS)`, `Link mode` among the SMB rows to set; `TESTING.md:135` repeats `Link mode … Games path (folder holding POPS)` in the Settings-row checklist.
- Code side: `bin/POPSLDR/system.lua:5776` `LINKMODE … hidden = true`; block comment `system.lua:5766-5768`: `DNS / LINKMODE / PATH / ADDR_TYPE / NB_ADDR are hidden = true: POPSTARTER needs none of them… they are not user-facing configuration any more.` Both rows are therefore not rendered, and a tester cannot complete the checklist as written. Mechanism fully confirmed.

**Corrected figure:** the finding cites `system.lua:5776,5785` for `LINKMODE … hidden = true` / `PATH … hidden = true`. The second anchor is wrong: line 5785 is `{ key = "PORT", kind = "str", default = "" }`. `PATH` is at **`system.lua:5789`** — `{ key = "PATH", kind = "str", default = "", hidden = true }`. One anchor off by 4 lines; no effect on the claim.

**Duplicate check (vs RE-POPS-059):** legitimate split, not a duplicate. The two findings share TESTING.md:131/135 but assert different, independently falsifiable claims on those lines: RE-POPS-059 is about the *values* presented as defaults (`Port (default 1111)`), RE-POPS-074 is about the *existence/rendering* of two rows (Games path, Link mode). Fixing one does not fix the other; the redo finding itself cross-references the split explicitly. Fix (delete the two rows from both passages) is LESS-sane — pure deletion.

---

### RE-POPS-107 — WEAKENED

**Evidence (verified core):**
- All quoted headers are really there: `ARCHITECTURE.md:1` `Release 1.1.0; rolling v1.1.1-dev / experimental v1.1.1-dev-EXP73`; `COMPONENTS.md:1` (same); `CONTRIBUTING.md:1` `rolling dev = v1.1.1-dev; released line 1.1.0`; `TESTING.md:3` `its version row reads v1.1.1-dev. Public release is 1.1.0 (2026-07-21)`; `DECISIONS.md:1` `Released line: 1.0.1`; `docs/PRESERVATION_CONTRACTS.md:3` `Public release is 1.1.0 (2026-07-21); rolling is 1.1.1-dev`.
- Code is unambiguously 1.4.4: `etc/boot.lua:1` `POPSLDR_VER = "v1.4.4"`; `bin/POPSLDR/title.cfg:7` `Version=1.4.4` (also line 4 `Title=POPSLoader 1.4.4`); `.github/workflows/official-release.yml` is the `POPSLoader 1.4.4 Release` workflow and greps both stamps. STATE.md:1 is current (`Official release: 1.4.4`).

**Reasoning (why WEAKENED, and a count correction):**
1. **Count drift in the finding itself:** the title/problem say "five docs", but the Locations list contains **six** — ARCHITECTURE, COMPONENTS, CONTRIBUTING, TESTING, DECISIONS, and PRESERVATION_CONTRACTS.
2. **Dated/historical framing narrows the harm for most of them.** ARCHITECTURE.md:1, COMPONENTS.md:1 and CONTRIBUTING.md:1 are all explicitly prefixed `Last updated: 2026-07-27` — they disclose their own snapshot date. PRESERVATION_CONTRACTS.md:3 is headed `Date: 2026-06-22, header re-synced 2026-07-27`. DECISIONS.md:1 goes further and disclaims the exact use the finding makes of it: `this log records the decisions, not the current-state snapshot… entries below that predate it are historical` — counting a dated decision log's `Released line: 1.0.1 (2026-07-13)` as a frozen current header is not sound.
3. **True scope:** the genuinely present-tense, tester-harming instance is **TESTING.md:3** — a current checklist instructing testers that a correct build's version row reads `v1.1.1-dev`, when no 1.4.4-stamped build displays that. The other five are stale-dated headers (worth the one-line update/deletion the fix proposes, and the fix's "delete the version and point at STATE.md" alternative is the LESS-correct half), but they are dated snapshots, not undated present claims.

---

### RE-POPS-108 — VERIFIED

**Evidence:**
- Re-ran the tool at the pin: `python3 tools/docs_verify.py` exits 0 and prints verbatim: `EncodeSettings writes 29 keys: POPSTARTER_PATH, BDMA, BDMA_ADAPTIVE, DKWDRV_PATH, STRICT_HDD_PREEXEC_GATE, VIDEO_STANDARD, HIDE_TEXT, KEYBOARD_LAYOUT, LANGUAGE, BOOT_PAGE, MULTIDISC_COLLAPSE, GLOBAL_HIDE, POPSTARTER_MC_FOLDER, HIDDEN_DEVICES, SHOW_DETAILS, DETAILS_ALIGN, ART_LOCATION, HDD_FS, COVER_ART, GAMELIST_CACHE, BOOT_SOUND, RETROGEM_GAMEID, OVERSCAN, SMB_MODULES, EMBER_DISPLAY, EMBER_TIMING, EMBER_DITHER, EMBER_SHADING, EMBER_CONTROLLER` — 29 keys, exactly as the finding reports.
- Code replication from `EncodeSettings` (`bin/POPSLDR/system.lua:5891ff`): `RETROGEM_GAMEID=` line sits between `BOOT_SOUND=` and `OVERSCAN=`; the five `EMBER_DISPLAY=`/`EMBER_TIMING=`/`EMBER_DITHER=`/`EMBER_SHADING=`/`EMBER_CONTROLLER=` lines follow `SMB_MODULES=`.
- Doc lists counted by hand at all three sites — each enumerates exactly **23** keys under a "29 keys" heading, ending at `SMB_MODULES`, with neither RETROGEM_GAMEID nor any EMBER_* key: `STATE.md:99`, `COMPONENTS.md:218-226`, `ARCHITECTURE.md:635-650`. 29 − 23 = 6 missing, exactly the two families named.
- Minor phrasing note (not a verdict change): the finding's parenthetical groups RETROGEM_GAMEID with the lines "immediately after SMB_MODULES="; in code only the five EMBER_* lines are after SMB_MODULES — RETROGEM_GAMEID is earlier in the list. The omission claim itself is exact. Fix (append the six keys to all three lists) is LESS-sane; inserting RETROGEM_GAMEID in code order (before OVERSCAN) would be tidier than appending, but completeness is what matters.

---

### RE-POPS-109 — VERIFIED

**Evidence:**
- Code: `bin/POPSLDR/ui.lua:241` `local function BuildCoverCandidates(…)`; `ui.lua:284-289` UDPFS branch verbatim:
  `if string.match(string.lower(dir), "^udpfs:/pops/") then … return { artdir..name.."_COV.png", dir..name.."_COV.png" }` — two candidates, the ART path plus beside-the-VCD in `udpfs:/POPS/`, with a comment stating the second probe is UDPFS-only by design. All other branches return a single candidate (or `{}`).
- Doc side, all verbatim with no UDPFS exception: `AGENTS.md:46` `it returns exactly ONE candidate (EXP71, maintainer directive)` (in the High-Risk Surfaces guidance to future agents — the riskiest instance, as the finding says); `STATE.md:64` `Cover art: ONE fixed folder per device`; `STATE.md:156` `exactly ONE folder is read — the always-on beside-the-.vcd fallback was removed`; `ARCHITECTURE.md:336-337` `BuildCoverCandidates returns a SINGLE candidate`; `TESTING.md:201` `exactly one path is read per device… art in the old POPS/ART or beside-the-.VCD spots no longer does` — on UDPFS beside-the-VCD art *is* read, so this instruction is directly false for that backend; `ROADMAP.md:78` (Secondary Work §2, the pre-"Ignore below" current summary) `the seeker returns exactly ONE candidate`.
- `README.md:150` and `README.md:244` state the exception correctly (`UDPFS also checks beside the VCD in udpfs:/POPS/`), confirming the finding's contrast.
- Fix (add the UDPFS exception clause to each statement) is LESS-sane: one clause per doc, no code change.

---

### RE-POPS-110 — VERIFIED

**Evidence:**
- `CONTRIBUTING.md:50-55` verbatim: `three top dirs only (PS1_POPSLOADER/, POPS/ and POPSTARTER VERSIONS/), no root files… PS1_POPSLOADER/: POPSLOADER.ELF, POPSTARTER.ELF, BUILD_INFO.txt, APPINFO.PBT, title.cfg, icon.sys, list.icn, copy.icn, del.icn`. `STATE.md:164` verbatim: `Release packaging policy is PS1_POPSLOADER/* + POPS/PATCH_5.BIN with strict manifest validation`.
- CI truth, `.github/workflows/compilation.yml` "Verify complete release package" step (lines 213-242): `expected = {"POPSLOADER.ELF", "POPSTARTER.ELF", "icon.sys", "list.icn", "copy.icn", "del.icn", "title.cfg", "APPINFO.PBT"}` asserted under **`APPS/PS1_POPSLOADER/`** — eight files, no BUILD_INFO.txt; additionally requires `EMBER/ember.elf`, `EMBER/LICENSE-BETA.txt`, ExampleGame `.cue`/`.bin`, `POPS/POPSTARTER.ELF`, `POPS/PATCH_5.BIN` (and the two `POPS/*.irx.ilink` files), and asserts the zip's `PS1_POPSLOADER.psu` at the zip root equals the built PSU.
- `tools/build_release_kit.sh` corroborates: `mkdir -p dist_root/APPS/PS1_POPSLOADER dist_root/POPS dist_root/EMBER/games/ExampleGame` (line 15); the zip is built from `APPS POPS EMBER` plus the root PSU (lines 86-87).
- Every element of the finding stands: app folder moved under `APPS/`, BUILD_INFO.txt is a phantom, `POPSTARTER VERSIONS/` is not in the formal kit, and the entire `EMBER/` tree plus the root PSU are absent from CONTRIBUTING's contract. Fix (rewrite the bullets from the compilation.yml verification block; reduce STATE.md:164 to a pointer) is LESS-sane.

---

### RE-POPS-111 — VERIFIED

**Evidence (all figures re-derived at the pin):**
- `wc -l`: `bin/POPSLDR/system.lua` = **11,784**, `bin/POPSLDR/ui.lua` = **7,599** — exactly the finding's corrected figures, against `ARCHITECTURE.md:191-192`'s `system.lua, ~8500 lines` / `ui.lua, ~6000 lines`.
- Doc anchors as cited: ARCHITECTURE Layer 4 control-flow block cites the main loop at `system.lua:6364-6376` and settings load at `system.lua:6333`; `COMPONENTS.md:226,228` cite `LoadSettingsNonFatal (system.lua:3650)`, `SaveSettingsAtomic (system.lua:3598)`; COMPONENTS also cites the render loop at `system.lua:6364-6376` and `return UI (ui.lua:4991)`; `docs/LAUNCH_ARGUMENTS.md:101,111` cite `system.lua:9368-9372` for the SMB auto-launch toast.
- Actual locations at the pin: `function PLDR.LoadSettingsNonFatal()` at **`system.lua:6222`**; `function PLDR.SaveSettingsAtomic()` at `system.lua:6145`; the main `while true do` render loop at **`system.lua:11772`**; the `Auto-launch page not supported` toast at **`system.lua:11431`**; `return UI` at **`ui.lua:7599`** (file end — so a `return UI` at :4991, which in reality lands inside a Settings function, cannot be the file end the doc describes).
- The cited anchors land in unrelated code, as claimed: `system.lua:6364` is inside the i18n translation tables; `system.lua:6333` is inside the body of LoadSettingsNonFatal, not a call site; `system.lua:9368-9372` is inside `PLDR.InitSMBPopsRoot`.
- Framing claims confirmed: `COMPONENTS.md:5-10` (Purpose) — `Every technical claim below cites path:line against this worktree`; `AGENTS.md:89` records the prior doc pass that `left ~15 wrong anchors`.
- Fix (regenerate or strip the Lua line anchors, keep symbol names, correct/delete the two counts) is LESS-sane — the strip variant is pure deletion and matches the PRESERVATION_CONTRACTS precedent the finding cites.

---

### RE-POPS-112 — VERIFIED

**Evidence:**
- `COMPONENTS.md:420` verbatim: `(usbd.irx.{usbexfat,mx4sio,mmce}, usbhdfsd.irx.{usbexfat,mx4sio,mmce})` — three suffixes each.
- Directory at the pin contains six of each: `usbd.irx.{ata,ilink,mmce,mx4sio,udpfs,usbexfat}` and `usbhdfsd.irx.{ata,ilink,mmce,mx4sio,udpfs,usbexfat}` (`ls bin/POPSLDR/`).
- `bin/POPSLDR/system.lua:5156-5163` `BDMA_SUFFIX` = USBEXFAT / MX4SIO / MMCE / ATA / ILINK / UDPFS — six variants, matching the directory. The omitted three (ATA, ILINK, UDPFS) are exactly those the finding names.
- Fix (extend both brace lists to six) is LESS-sane.

---

### RE-POPS-113 — VERIFIED

**Evidence:**
- Doc side: `STATE.md:5-9` — `Translation follow-up (2026-10-27): … Slovak wording awaits the contributor; SK is not yet in the picker`. It sits above the `# STATE` heading at the very top of the canonical doc.
- Code side: `bin/POPSLDR/system.lua:2559` `PLDR.LANGUAGE_ORDER = {"EN", "FR", "DE", "PT", "ES", "IT", "HU", "SK"}`; `system.lua:2560` `LANGUAGE_NAMES` includes `SK = "Slovenčina"` — exact lines as cited.
- Corroboration: `bin/changelog [1.4.3]` — `New: Slovak (Slovenčina) translation by SVKghost (#605)` ([1.4.4] adds Slovak corrections); `docs/translations/README.md:9-11` — `it now ships as PLDR.I18N.SK and appears in the language picker as Slovenčina`; STATE.md's own line 1 — `1.4.3 added the Slovak translation by SVKghost`. Self-contradiction inside STATE.md confirmed (line 1 vs lines 5-9).
- Dated-framing check: the note *is* dated 2026-10-27, but it is not archived or marked superseded — it remains the top-of-file follow-up in the canonical current-status doc, and its content (a contribution still awaited) was falsified by the 1.4.3 shipment recorded in the same file's first line. The finding's own account of this (written before the workbook returned, never retired) is accurate, so the date does not refute it.
- Related limb spot-checked: STATE.md:61 and STATE.md:252 do say `all six languages`; with SK there are now seven non-English dictionaries / eight languages in LANGUAGE_ORDER. The finding files this only as an INFERRED ambiguity worth one word — correctly hedged.
- Fix (delete the stale paragraph; its QA-matrix pointer survives in QA_REGRESSION_MATRIX.md's dated 2026-10-27 section) is LESS-sane — pure deletion.

---

### RE-POPS-114 — VERIFIED

**Evidence:**
- Doc side: `STATE.md:98` verbatim — `The dropped bindings still work where they did (Square toggles cover art, START opens Settings) — only the legend clutter went`.
- Code side: `bin/POPSLDR/ui.lua:3738-3741` — `EXP42: Square no longer toggles cover art here… it now lives in Settings > Game List > "Cover art" (PLDR.COVER_ART)`; the second removal note at the Cover art setting (`ui.lua:5218-5226` region) repeats that EXP42 replaced the Square toggle with the persisted setting.
- Self-contradiction inside STATE.md confirmed on both sides: STATE.md:156 (Cover art section) — `COVER_ART … which replaced the Square toggle`; STATE.md:67 likewise — `Square is now unbound on the game lists`.
- Current behaviour stated correctly where the finding says: `TESTING.md:47` `Square no longer toggles cover art at all`; `README.md:244` (Troubleshooting) `Square is not bound in the game list`.
- Fix (delete "Square toggles cover art" from the sentence; START-opens-Settings remains true — TESTING.md:47 confirms START still opens Settings) is LESS-sane.

---

### RE-POPS-115 — VERIFIED

**Evidence:**
- Doc side: `STATE.md:150` verbatim — `Persisted as HIDDEN_DEVICES (CSV of stable device keys; all shown by default; a guard keeps ≥1 visible)`.
- Code side: `bin/POPSLDR/system.lua:6247` — `PLDR.HIDDEN_DEVICES = "ILINK"  -- EXP34: hide the i.Link page by default (maintainer)`.
- Self-contradiction inside STATE.md confirmed on both sides: STATE.md:65 (its own EXP34 factory-defaults bullet) — `HIDDEN_DEVICES = ILINK (the i.Link page ships Hidden)`.
- `README.md:139` states it correctly: `every other device defaults to Shown, i.Link ships Hidden` / `i.Link is Hidden by default`.
- Fix (change the parenthetical to "all shown by default except i.Link, which ships hidden") is LESS-sane — a six-word correction.

---

## Closing tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 10 | 060, 073, 108, 109, 110, 111, 112, 113, 114, 115 |
| VERIFIED-DRIFT | 1 | 074 (PATH anchor: cited 5785, actual **5789**) |
| WEAKENED | 2 | 059 (two of seven instances are historical-framed), 107 (six docs not five; five of six are dated snapshots / a self-disclaimed historical log — TESTING.md:3 is the live instance) |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — |
| **Total** | **13** | |

No finding in this chunk was refuted. Every headline mechanism — the SMB no-defaults code, the GILINK scene/dispatch/launch path, the Adaptive-BDMA USBEXFAT rule, the 29-key EncodeSettings output (re-run via `tools/docs_verify.py`), the UDPFS two-candidate cover branch, the APPS/EMBER/PSU packaging verification, and the re-derived line counts/anchors for 111 — reproduced exactly at the pin.

## Candidates (new defects, not verdicts)

- **CANDIDATE-H1 — "Ember only" survives in two code comments on the i.Link path itself (limb of RE-POPS-060's mechanism, in code rather than docs).** `bin/POPSLDR/ui.lua:1067` — `GILINK = 11, -- i.LINK (EXPERIMENTAL, Ember only, hardware-untested)` and `bin/POPSLDR/system.lua:9161` — `-- i.LINK (EXPERIMENTAL, hardware-UNTESTED; Ember only)` (the `InitILINKRoot` header). Both contradict the dispatch comment 20 lines into the OPT 6 handler (`ui.lua:6426-6427`: Ember *plus* POPSTARTER VCDs via the staged `.ilink` pair) and the ILINK POPSTARTER launch policy at `system.lua:10699-10702`. Same stale claim as RE-POPS-060, two further locations the redo finding did not list; a contributor reading the scene enum or the root-init header gets the Ember-only story from the code itself.
