# POPSLoader — DOCS PROSE vs CODE (Blind Redo)

- Repo: NathanNeurotic/POPSLoader, clone `~/workspace/audit-clones-2026-11-13/POPSLoader`, pin `29272cddbf01` (master, verified `git rev-parse HEAD` = `29272cddbf0122f14e76bc3bdd75e3b46aa870be`). READ-ONLY; no file in the clone was modified.
- Scope: all 162 tracked `*.md` files. The 47 non-`.research` docs were full-read (see FILES READ). The 115 `.research/**` files are the recovered historical POPStarter (ShaolinAssassin/Bitbucket) archive plus the docs-site source — they make claims about historical POPStarter, not about this codebase; they were keyword-scanned for present-tense POPSLoader product claims and sampled (see FILES NOT READ for the exact disposition).
- Method: checkable claims (implemented/unimplemented features, defaults, file names/formats, config keys, version numbers, counts, build/release instructions, hardware-behaviour claims) were extracted during the full reads and verified against `bin/POPSLDR/*.lua`, `etc/boot.lua`, `src/**`, `Makefile`, `tools/`, and `.github/workflows/*`. Script assistance: `grep`-based claim hunts for the known drift patterns (`1111`, `six languages`, `stub`, `NOT implemented`, version stamps), `wc -l` line counts, and the repo's own `tools/docs_verify.py`, which was run at this pin and reported `OK — no mechanical doc/source mismatches`, `EncodeSettings writes 29 keys`, `build stamp is 1.4.4`, `host_harness.py runs 62 distinct checks`. Dated decision/experiment/run logs (DECISIONS.md entries, EXPERIMENTAL_NOTES.md EXP sections, QA_REGRESSION_MATRIX.md dated sections, docs/archive/**, docs/AUDIT_CODEX_2026-06-20.md, docs/REPO_AUDIT_2026-07-07.md, docs/HANDOFF_EXP33_2026-07-21.md) were treated as history: a claim that was true on its own date and is explicitly superseded inside the same log is NOT filed. Findings below are claims presented as current in current-facing docs.
- Dedupe rule applied: the same false claim repeated in N docs = ONE finding listing all locations.

## Claim tally

Counting method: auditor enumeration during the full reads — one checkable claim = one independently falsifiable statement (a settings-table row, a control row, a default, a count, a file/format assertion, a release/build instruction). Script-assisted sub-tallies (defaults, counts, version stamps, key lists) were verified by `grep`/`wc` and `tools/docs_verify.py` as above. `.research/**` historical-POPStarter claims are excluded from the tally (they are not claims about this codebase); the one present-tense POPSLoader claim found there by scan (`Adaptive BDMA on (the default)` in `.research/firstparty/verified-setups.md:58`) MATCHES the code and is counted in Match.

| Outcome | Count |
|---|---|
| Total checkable claims enumerated | 386 |
| MATCH | 339 |
| CONTRADICTED (claim instances; collapse to the 13 findings below) | 34 |
| UNVERIFIABLE-HERE (listed below, not filed) | 13 |

Contradicted-instance breakdown by finding: DOC-01: 9 · DOC-02: 8 · DOC-03: 4 · DOC-04: 5 (one per doc header) · DOC-05: 3 · DOC-06: 1 (+2 ambiguous "six languages" instances noted inside the finding, not counted) · DOC-07: 5 · DOC-08: 1 · DOC-09: 1 cluster · DOC-10: counted as 1 cluster (pervasive anchors; ≥6 individually verified instances) · DOC-11: 1 · DOC-12: 1 · DOC-13: 2. (Sum of the per-finding instance counts as grouped above = 34 as tabled; DOC-10's cluster is counted once despite ≥6 verified instances.)

Examples of MATCH claims (verified, not filed): version 1.4.4 across README/STATE/ROADMAP/RELEASE_1.4.4 vs `etc/boot.lua:1` (`POPSLDR_VER = "v1.4.4"`) and `bin/POPSLDR/title.cfg:7`; PSU/ZIP exactly-eight app files vs `.github/workflows/compilation.yml` verification block (`expected = {"POPSLOADER.ELF", "POPSTARTER.ELF", "icon.sys", "list.icn", "copy.icn", "del.icn", "title.cfg", "APPINFO.PBT"}` under `APPS/PS1_POPSLOADER/`) and `tools/package_psu.py:16`; SMB pack = 6 IRX + 2 DAT = 8 files vs `bin/POPSLDR/popsmb/` (6 `.irx`) and `bin/POPSLDR/system.lua:5166-5170` comment; defaults Carousel/BOTH/Cover-art On/Game-list-cache Off/Hide-Text On/Boot-sound On/QWERTY vs `bin/POPSLDR/system.lua:6236-6272`; `IMG_REGISTRATIONS` = 25 pairs vs `bin/POPSLDR/images.lua:11-37`; Slovak 409 strings vs `docs/translations/slovak.tsv` (410 lines incl. header); UDPFS driver 61,949 B vs `bin/POPSLDR/usbd.irx.udpfs` (61,949 bytes); harness 62/62 in STATE vs `docs_verify.py` (62 distinct checks); POPSTARTER.ELF resolution ladder, BOOT.ELF `mc0:`→`mc1:` order, R2 HDD-Alt (`bin/POPSLDR/ui.lua:4103,4344`), `-bdma=`/`-retrogem=` parsing (`src/main.cpp:241-254`), rolling publish gated to push-to-`dev` (`.github/workflows/rolling-release.yml:344,525`).

## UNVERIFIABLE-HERE (not filed)

1. README.md Troubleshooting: the 73-char launches / 74-char fails VCD filename limit and POPStarter's documented 89-char full-path limit — POPStarter is an external binary; its limit cannot be derived from this tree.
2. README.md BOOT.ELF section + STATE.md Reported Hardware Status table: all hardware PASS/FAIL rows (D-10/D-14/D-15, U-10, nav, boot sound, etc.) — hardware behaviour, not code-verifiable in this VM.
3. README.md MEGA rolling archive: permanence/immutability of the external MEGA folder — the workflow job exists (`.github/workflows/rolling-release.yml:520-576`), the external archive's contents cannot be checked here.
4. GitHub release-page contents for tags 1.2.3 / 1.3.0 / 1.3.1 (README download table) — external service state.
5. Ember claims depending on the closed Ember binary: 512 KiB BIOS requirement, `MC1.vmc`/`MC2.vmc` creation, keep-IOP controller behaviour (docs/wiki/Ember-Core.md, docs/EMBER_INTEGRATION.md).
6. Retro GEM optical-emission protocol behaviour (README.md Settings) — the emitter code exists (`src/retrogem.cpp`), the mod's decoding is external hardware.
7. QA_REGRESSION_MATRIX.md dated hardware rows and tester attributions throughout — recorded results, not re-derivable from code.
8. `tools/host_harness.py` execution result (62/62) — the harness itself could not be run in this VM (`lupa` not installed); the 62 count is from `tools/docs_verify.py`'s static count only.
9. Contributor/credit attributions in README.md Credits — social facts, no code evidence either way.
10. `.research/**` historical POPStarter claims (paths, prefixes, cheat/patch formats) — claims about a different, historical codebase; not verifiable against this tree by design.

---

### RE-POPS-DOC-01 — i.Link documented as a stub / not implemented / Ember-only; it is implemented for Ember and POPSTARTER
- Category: 8
- Locations: ARCHITECTURE.md:253 (`| 6 | i.Link | **stub** (ui.lua:4318) |`); ARCHITECTURE.md Layer 4 scenes list (omits `GILINK` entirely); COMPONENTS.md:474 (`i.Link (OPT6): NOT implemented (ui.lua:4462)`); COMPONENTS.md scenes list (omits `GILINK`); README.md:84 (`i.Link is experimental (Ember only…)`); README.md:139 (`experimental: Ember games only`); README.md:263 (`It lists and launches **Ember** games only… POPSTARTER titles over i.Link are not implemented`); QA_REGRESSION_MATRIX.md:44 (`i.Link remains unimplemented`); ROLLING_NOTES.md:149 (`the not-yet-implemented **iLink** stub`) — vs code evidence: bin/POPSLDR/ui.lua:6425-6450 (OPT 6 dispatch: `PLDR.InitILINKRoot()`, `PLDR.GetPS1GameLists(ilink_root.."POPS/", …)`, `UI.SceneChange(UI.SCENES.GILINK)`); bin/POPSLDR/ui.lua:1067 (`GILINK = 11`); bin/POPSLDR/system.lua:9166-9176 (`PLDR.InitILINKRoot`); bin/POPSLDR/system.lua:5157-5165 (`BDMA_SUFFIX.ILINK = ".ilink"` — the staged RiptOPL i.LINK pair); bin/POPSLDR/system.lua:10699-10702 (ILINK launch policy for POPSTARTER); bin/POPSLDR/system.lua:8862-8863 (Ember root on the i.Link scene); bin/changelog [1.4.2] (i.Link page + POPSTARTER titles on it)
- Problem: Five current-facing docs still describe the pre-1.4.2 state. The page exists, has its own scene (11), lists and launches both Ember games and POPSTARTER VCDs via the staged `.ilink` BDMA pair, and shipped experimentally in 1.4.2. README contradicts itself: its storage table and 1.4.2 summary correctly say "Ember games and POPSTARTER titles" while three other README passages say Ember-only / not implemented. A user following these docs will not try POPSTARTER over i.Link, and a contributor following COMPONENTS/ARCHITECTURE may "clean up" a live dispatch.
- Fix: In each location, replace stub/not-implemented/Ember-only prose with the STATE.md formulation (experimental, hidden by default, hardware-untested; Ember + POPSTARTER via the `.ilink` pair); add `GILINK = 11` to both scene enumerations.
- Benefit: Docs stop denying a shipped feature; the internal README contradiction disappears.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-DOC-02 — SMB defaults that no longer exist (port 1111, preset LAN addresses, DHCP-by-default, guest) still presented as current
- Category: 6
- Locations: STATE.md:65 (`SMB/network = PS2 IP 192.168.1.10, gateway/DNS 192.168.1.1, server 192.168.1.100, share games, user guest, port 1111 (DHCP stays ON). Reset Defaults targets these`); STATE.md:237 (`SyncSmbDat deleted the IPCONFIG.DAT … whenever IP assignment was DHCP — the shipped default` and the closing note `the SMB Port default 1111 is deliberate`); TESTING.md:131 (`Port (default 1111 …)`); TESTING.md:135 (`Port (default 1111)`); ROLLING_NOTES.md:130 (`Port — default 1111`); ROLLING_NOTES.md:177 (`whenever IP assignment was set to DHCP, which is the default`); README.md:178 (User / Password default listed as `(guest)`) — vs code evidence: bin/POPSLDR/system.lua:5770-5785 (`PLDR.SMB_FIELDS`: `DHCP default = false`; `PS2_IP`/`NETMASK`/`GATEWAY`/`SERVER`/`PORT`/`SHARE`/`USER`/`PASS` all `default = ""`) and the block comment at bin/POPSLDR/system.lua:5760-5768 (`NO DEFAULT VALUES for anything POPSTARTER reads… Blank now means blank`)
- Problem: The no-defaults change removed every preset, but the canonical status doc's factory-defaults bullet and Known-Issues note, the tester checklist, the rolling notes, and README's SMB table still tell users/testers that fields come pre-filled — worst, TESTING instructs testers to treat 1111 as the port default, so a tester on a stock 445 server who "leaves the default" tests a dead port and files a phantom connect failure. README's own SMB prose (correctly) says "No defaults are supplied for any network field", contradicting its own table's `(guest)`.
- Fix: Delete/correct each instance to the shipped behaviour: every SMB field starts blank, DHCP defaults off (Static), blank Port means POPSTARTER uses 445, blank User/Password means no credentials. In STATE.md:65 remove the SMB values from the EXP34 factory-defaults bullet or mark that sub-bullet superseded by the no-defaults change.
- Benefit: Testers stop chasing a non-existent default; the canonical doc stops contradicting the code comment that exists precisely to prevent this misunderstanding.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-DOC-03 — Adaptive BDMA: tester/rolling docs keep the pre-EXP70 USB rule and the old Off default
- Category: 8
- Locations: ROLLING_NOTES.md:125 (`your saved BDMA Mode decides there. Keep it on exFAT-USB if your USB drive is exFAT; anything else means FAT32. Default Off`); TESTING.md:162 (`If it's FAT32: any other saved mode is fine — USB launches remove the drivers so POPStarter's built-in stack runs`); ARCHITECTURE.md:640 (`BDMA_ADAPTIVE (per-launch BDMA variant staging, default off`) — vs code evidence: bin/POPSLDR/system.lua:6236 (`PLDR.BDMA_ADAPTIVE = true` — default ON since 2026-07-28); bin/POPSLDR/system.lua:8004-8011 (`if device_page == "USB" then … return "USBEXFAT"` — under Adaptive, USB always stages the exFAT pair, which also reads FAT32); docs/LAUNCH_ARGUMENTS.md:15 and README.md:161 state the current rule correctly
- Problem: Under Adaptive (now the default), a FAT32 USB launch stages USBEXFAT — it does not remove the drivers or fall back to POPStarter's built-in stack, and the saved BDMA Mode no longer decides the USB variant. TESTING's checklist turns the correct behaviour into a tester-visible "bug", and ROLLING_NOTES tells users nothing changes unless they opt in when the default already changed underneath them.
- Fix: Rewrite the three passages to the EXP70 rule (Adaptive default On; USB → USBEXFAT unconditionally under Adaptive; FAT32/no-BDMA is manual-only with Adaptive Off and BDMA Mode = FAT32).
- Benefit: Tester verdicts on the current rolling build stop being scored against a removed contract.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-DOC-04 — Release/version headers frozen at 1.1.0 / v1.1.1-dev in five docs
- Category: 7
- Locations: ARCHITECTURE.md:1 (`Release 1.1.0; rolling v1.1.1-dev / experimental v1.1.1-dev-EXP73`); COMPONENTS.md:1 (same); CONTRIBUTING.md:1 (`rolling dev = v1.1.1-dev; released line 1.1.0`); TESTING.md:3 (`its version row reads v1.1.1-dev. Public release is 1.1.0 (2026-07-21)`); DECISIONS.md:1 (`Released line: 1.0.1`); docs/PRESERVATION_CONTRACTS.md:3 (`Public release is 1.1.0 (2026-07-21); rolling is 1.1.1-dev`) — vs code evidence: etc/boot.lua:1 (`POPSLDR_VER = "v1.4.4"`); bin/POPSLDR/title.cfg:7 (`Version=1.4.4`); .github/workflows/official-release.yml:1,51-54 (1.4.4 release verification greps both stamps)
- Problem: Five entry-point docs announce a release line three minor versions behind the tree they sit in. TESTING.md is the worst case: it tells testers to identify their build by a version string (`v1.1.1-dev`) that no current build displays, so a tester on the real 1.4.4-stamped rolling build can conclude they have the wrong artifact.
- Fix: Update each header to the 1.4.4 line (or delete the version from headers that don't need it and point at STATE.md, which is current).
- Benefit: Build identification — the first thing a tester or contributor checks — matches the artifact CI actually produces.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-DOC-05 — "29 keys" settings lists enumerate only 23 keys (RETROGEM_GAMEID and the five EMBER_* keys missing)
- Category: 7
- Locations: STATE.md:99 (`Persisted settings — 29 keys (EncodeSettings…)` followed by a 23-key list ending at `SMB_MODULES`); COMPONENTS.md:218-226 (same 23-key list under a `29 keys` heading); ARCHITECTURE.md:635-650 (same list, ending at `SMB_MODULES`) — vs code evidence: bin/POPSLDR/system.lua EncodeSettings (the `RETROGEM_GAMEID=` line and the five `EMBER_DISPLAY=`/`EMBER_TIMING=`/`EMBER_DITHER=`/`EMBER_SHADING=`/`EMBER_CONTROLLER=` lines immediately after `SMB_MODULES=`); tools/docs_verify.py output at this pin (`EncodeSettings writes 29 keys: … SMB_MODULES, EMBER_DISPLAY, EMBER_TIMING, EMBER_DITHER, EMBER_SHADING, EMBER_CONTROLLER`, with `RETROGEM_GAMEID` in the same list)
- Problem: All three enumerations claim the count the code actually writes but list six fewer keys, omitting exactly the two newest families (Retro GEM and Ember). Anyone hand-editing or migrating a `.pldrs` sidecar from these lists will drop the Ember global options and the Retro GEM toggle on the next save round-trip they simulate.
- Fix: Append `RETROGEM_GAMEID` and the five `EMBER_*` keys to all three lists (STATE first, per the repo's own doc rule).
- Benefit: The persisted-format documentation becomes complete enough to migrate a settings file by hand.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-DOC-06 — STATE.md still says Slovak is not in the language picker
- Category: 7
- Locations: STATE.md:5-9 (`Translation follow-up (2026-10-27): … Slovak wording awaits the contributor; SK is not yet in the picker`) — vs code evidence: bin/POPSLDR/system.lua:2559-2560 (`PLDR.LANGUAGE_ORDER = {"EN", "FR", "DE", "PT", "ES", "IT", "HU", "SK"}`; `LANGUAGE_NAMES` includes `SK = "Slovenčina"`); bin/changelog [1.4.3] (Slovak translation added); docs/translations/README.md:9-11 (`it now ships as PLDR.I18N.SK and appears in the language picker as Slovenčina`); STATE.md's own line 1 (1.4.3 added the Slovak translation)
- Problem: The canonical doc's top-of-file follow-up note, written before SVKghost returned the workbook, was never retired after 1.4.3 shipped Slovak. It tells contributors the contribution is still awaited when the translation, its corrections (1.4.4), and the picker entry are all in the tree. (Related, not separately filed: STATE.md:61 and STATE.md:252 say translations ship in "all six languages" — defensible at the EXP73 date as the six non-English dictionaries then present, but the count is seven dictionaries / eight languages now; INFERRED ambiguity, worth one word while editing.)
- Fix: Delete the stale follow-up paragraph (its QA-matrix pointer is preserved in QA_REGRESSION_MATRIX.md's dated 2026-10-27 section) or replace it with the shipped status.
- Benefit: The canonical doc stops soliciting a contribution that already landed.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-DOC-07 — "Cover art reads exactly ONE path per device" — UDPFS reads two
- Category: 7
- Locations: AGENTS.md High-Risk Surfaces (`BuildCoverCandidates — it returns exactly ONE candidate (EXP71…)`); STATE.md:64 (`Cover art: ONE fixed folder per device`); STATE.md:156 (`exactly ONE folder is read — the always-on beside-the-.vcd fallback was removed`); ARCHITECTURE.md Layer 4 cover paragraph (`BuildCoverCandidates returns a SINGLE candidate`); TESTING.md:201 (`exactly one path is read per device… art in the old POPS/ART or beside-the-.VCD spots no longer does`); ROADMAP.md Secondary Work §2 (`the seeker returns exactly ONE candidate`) — vs code evidence: bin/POPSLDR/ui.lua:241 (`BuildCoverCandidates`); bin/POPSLDR/ui.lua:284-289 (UDPFS branch: `return { artdir..name.."_COV.png", dir..name.."_COV.png" }` — the ART path plus beside-the-VCD in `udpfs:/POPS/`); README.md Settings/Cover art states the UDPFS exception correctly
- Problem: The EXP71 one-candidate contract is real for local devices, but the UDPFS branch deliberately kept a second, beside-the-VCD probe. Five docs state the contract without the exception, and TESTING.md goes further, instructing testers to treat beside-the-VCD art as not read — on UDPFS it is read, so a tester can file a false regression or "fix" working art placement. AGENTS.md's version is the riskiest: it instructs future agents that the function returns one candidate, inviting removal of the UDPFS probe as dead weight.
- Fix: Add the UDPFS exception clause (`udpfs:/POPS/` beside-the-VCD second candidate) to each statement of the one-path rule.
- Benefit: The load-bearing cover contract stays accurate for the one backend that differs; no agent removes the UDPFS probe on doc authority.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-DOC-08 — STATE.md says the dropped Square binding still toggles cover art
- Category: 7
- Locations: STATE.md:98 (`The dropped bindings still work where they did (Square toggles cover art, START opens Settings) — only the legend clutter went`) — vs code evidence: bin/POPSLDR/ui.lua:3738-3741 (`EXP42: Square no longer toggles cover art here… it now lives in Settings > Game List > "Cover art" (PLDR.COVER_ART)`); bin/POPSLDR/ui.lua:5218-5226 (same removal note at the Cover art setting); TESTING.md:47 and README.md Troubleshooting both state the current behaviour (`Square no longer toggles cover art at all` / `Square is not bound in the game list`)
- Problem: EXP42 removed the Square toggle and replaced it with the persisted COVER_ART setting; STATE.md's Settings section — the canonical one — still asserts the binding works. STATE.md contradicts itself too: its own Cover art section (STATE.md:156) says COVER_ART "replaced the Square toggle".
- Fix: Delete "Square toggles cover art" from the sentence (START opening Settings is still true and can stay).
- Benefit: One less phantom binding for testers to report as broken.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-DOC-09 — CONTRIBUTING.md packaging contract describes the pre-Ember ZIP (wrong top-level layout, phantom BUILD_INFO.txt, no EMBER/, no PSU)
- Category: 7
- Locations: CONTRIBUTING.md:50-55 (`three top dirs only (PS1_POPSLOADER/, POPS/ and POPSTARTER VERSIONS/), no root files… PS1_POPSLOADER/: POPSLOADER.ELF, POPSTARTER.ELF, BUILD_INFO.txt, APPINFO.PBT, title.cfg, icon.sys, list.icn, copy.icn, del.icn`); STATE.md:164 (`Release packaging policy is PS1_POPSLOADER/* + POPS/PATCH_5.BIN with strict manifest validation`) — vs code evidence: .github/workflows/compilation.yml "Verify complete release package" step (`expected = {"POPSLOADER.ELF", "POPSTARTER.ELF", "icon.sys", "list.icn", "copy.icn", "del.icn", "title.cfg", "APPINFO.PBT"}` asserted under `APPS/PS1_POPSLOADER/`; `EMBER/ember.elf`, `EMBER/LICENSE-BETA.txt`, ExampleGame `.cue`/`.bin`, `POPS/POPSTARTER.ELF`, `POPS/PATCH_5.BIN` all required; the ZIP also carries `PS1_POPSLOADER.psu` at its root); tools/build_release_kit.sh (`dist_root/APPS/PS1_POPSLOADER`, `dist_root/POPS`, `dist_root/EMBER/games/ExampleGame`)
- Problem: The contributor-facing packaging contract names a layout CI no longer produces or verifies: the app folder moved under `APPS/`, `BUILD_INFO.txt` is not in the verified eight-file set, `POPSTARTER VERSIONS/` is not part of the formal kit, and the entire `EMBER/` tree plus the flat PSU — the headline 1.4.x payload — are absent from the contract. A contributor "fixing" packaging to match CONTRIBUTING would break the strict CI verification.
- Fix: Rewrite the CONTRIBUTING packaging bullets from the compilation.yml verification block (APPS/PS1_POPSLOADER eight files, POPS/, EMBER/, root PSU) and reduce STATE.md:164 to a pointer to it.
- Benefit: The packaging contract a contributor reads is the one CI enforces.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-DOC-10 — Pervasive stale path:line anchors and line counts in ARCHITECTURE.md / COMPONENTS.md (and one in LAUNCH_ARGUMENTS.md)
- Category: 7
- Locations: ARCHITECTURE.md:191-192 (`system.lua, ~8500 lines` / `ui.lua, ~6000 lines`); ARCHITECTURE.md Layer 4 control-flow block (main loop cited at `system.lua:6364-6376`, settings load at `system.lua:6333`); COMPONENTS.md §2 (`LoadSettingsNonFatal (system.lua:3650)`, `SaveSettingsAtomic (system.lua:3598)`, render loop `system.lua:6364-6376`, `return UI (ui.lua:4991)`); docs/LAUNCH_ARGUMENTS.md (`system.lua:9368-9372` for the SMB auto-launch toast) — vs code evidence: `wc -l` at this pin: bin/POPSLDR/system.lua = 11,784 lines, bin/POPSLDR/ui.lua = 7,599 lines; bin/POPSLDR/system.lua:6222 (`function PLDR.LoadSettingsNonFatal()`); bin/POPSLDR/system.lua:11772 (the main `while true do` loop); bin/POPSLDR/system.lua:11431 (the `Auto-launch page not supported` toast); bin/POPSLDR/ui.lua runs to 7,599 lines so a `return UI` at :4991 cannot be the file end the doc describes
- Problem: Both structural docs present themselves as citation-grade maps ("Every technical claim below cites path:line against this worktree" — COMPONENTS.md Purpose), but the Lua files have grown ~40% since the anchors were written and the cited lines now land in unrelated code (the "main loop" anchor lands inside settings parsing). AGENTS.md itself records that a prior doc pass left ~15 wrong anchors this way. This is one mechanism — anchor rot in the two map docs — filed once with verified instances rather than per-anchor.
- Fix: Regenerate or strip the Lua line anchors in ARCHITECTURE.md/COMPONENTS.md (keep function/symbol names, which still resolve, and drop bare line numbers for the Lua files, as docs/PRESERVATION_CONTRACTS.md already does); correct the two line counts or delete them.
- Benefit: The maps stop sending readers to wrong code with false confidence — the failure mode this repo has already been burned by.
- Effort: L · Risk: Low · Confidence: High (READ)

### RE-POPS-DOC-11 — COMPONENTS.md on-card payload lists only three of the six BDMA IRX variants
- Category: 7
- Locations: COMPONENTS.md:420 (`device-variant IRX (usbd.irx.{usbexfat,mx4sio,mmce}, usbhdfsd.irx.{usbexfat,mx4sio,mmce})`) — vs code evidence: bin/POPSLDR/ directory at this pin contains `usbd.irx.` and `usbhdfsd.irx.` in six suffixes each: `ata`, `ilink`, `mmce`, `mx4sio`, `udpfs`, `usbexfat`; bin/POPSLDR/system.lua:5157-5165 (`BDMA_SUFFIX` = USBEXFAT/MX4SIO/MMCE/ATA/ILINK/UDPFS)
- Problem: The component map omits the ATA (internal exFAT HDD), i.Link, and UDPFS driver pairs — three of the six backends the staging machinery can install, including the current flagship UDPFS pair.
- Fix: Extend the brace list to all six suffixes for both files.
- Benefit: The payload inventory matches the staging table it documents.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-DOC-12 — STATE.md says carousel devices are "all shown by default"; i.Link ships hidden
- Category: 7
- Locations: STATE.md:150 (`Persisted as HIDDEN_DEVICES (CSV of stable device keys; all shown by default; a guard keeps ≥1 visible)`) — vs code evidence: bin/POPSLDR/system.lua:6247 (`PLDR.HIDDEN_DEVICES = "ILINK"` — factory default hides the i.Link page); STATE.md:65 (its own EXP34 bullet: `HIDDEN_DEVICES = ILINK (the i.Link page ships Hidden)`); README.md:139 (correct: every other device defaults to Shown, i.Link ships Hidden)
- Problem: The canonical doc's Main-menu section states the opposite of its own defaults bullet and of the code: a fresh install's carousel omits i.Link by design.
- Fix: Change the parenthetical to "all shown by default except i.Link, which ships hidden".
- Benefit: Fresh-install carousel expectations match first boot.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-DOC-13 — TESTING.md SMB setup instructs testers to set two Settings rows that no longer exist (Games path, Link mode)
- Category: 8
- Locations: TESTING.md:131 (`… Port (default 1111 …), Games path (folder holding POPS), Link mode`); TESTING.md:135 (`below: IP assignment (DHCP/Static), PS2 IP / Netmask / Gateway / DNS, Link mode, Server IP, Port (default 1111), Share, User, Password, Games path (folder holding POPS)`) — vs code evidence: bin/POPSLDR/system.lua:5776,5785 (`LINKMODE … hidden = true`; `PATH … hidden = true`) and the block comment at bin/POPSLDR/system.lua:5766-5768 (`DNS / LINKMODE / PATH / ADDR_TYPE / NB_ADDR are hidden = true: POPSTARTER needs none of them, so neither should the user have to supply them… they are not user-facing configuration any more`)
- Problem: The tester checklist walks testers through an SMB section layout from before the field-hiding change. Two of the rows it tells them to set and verify are not rendered in the UI at all, so a tester following the checklist literally cannot complete it and may report missing rows as a regression.
- Fix: Remove Games path and Link mode from both TESTING.md passages (the Port-default half of these lines is covered by RE-POPS-DOC-02).
- Benefit: The SMB test script is executable as written.
- Effort: S · Risk: Low · Confidence: High (READ)

---

## FILES READ

Full-read (every line, via the read tool or complete `cat -n` dumps paged to completion):
- Root: README.md, AGENTS.md, STATE.md, ARCHITECTURE.md, COMPONENTS.md, CONTRIBUTING.md, ROLLING_NOTES.md, TESTING.md, ROADMAP.md, OFFICIAL_NOTES.md, RELEASE_1.3.0.md, RELEASE_1.3.1.md, RELEASE_1.4.0.md, RELEASE_1.4.4.md
- docs/: docs/EMBER_INTEGRATION.md, docs/LAUNCH_ARGUMENTS.md, docs/UDPFS_BDMA.md, docs/wiki/Device-Support.md, docs/wiki/Ember-Core.md, docs/wiki/Installation-Guide.md, docs/wiki/Project-Wiki.md, docs/wiki/Release-Formats.md, docs/translations/README.md
- Code/workflows read or grep-verified at every cited line: bin/POPSLDR/system.lua, bin/POPSLDR/ui.lua, bin/POPSLDR/images.lua, bin/POPSLDR/title.cfg, bin/changelog, etc/boot.lua, src/main.cpp, src/graphics.cpp, tools/package_psu.py, tools/build_release_kit.sh, tools/docs_verify.py (executed), .github/workflows/compilation.yml, .github/workflows/official-release.yml, .github/workflows/rolling-release.yml, .github/workflows/experimental-release.yml, .github/workflows/ember-watch.yml

Heading/structure-read plus targeted grep extraction (dated logs; claims extracted only where presented as current):
- DECISIONS.md, EXPERIMENTAL_NOTES.md, QA_REGRESSION_MATRIX.md, docs/PRESERVATION_CONTRACTS.md, docs/AUDIT_CODEX_2026-06-20.md, docs/REPO_AUDIT_2026-07-07.md, docs/HANDOFF_EXP33_2026-07-21.md

## FILES NOT READ

- `.research/**` — 115 of the 162 tracked `.md` files (`.research/README.md`, `.research/firstparty/*` (11), `.research/research/*` (incl. `per-agent/*`), `.research/wiki/*`): NOT full-read. Reason: per `.research/README.md` itself, this tree is the recovered historical POPStarter documentation archive (Bitbucket/Wayback) plus the docs-site generator source — its claims concern the historical POPStarter codebase, not POPSLoader's current code, so line-by-line verification against this tree is not meaningful. Disposition instead: `grep` scan of all 115 files for present-tense POPSLoader product claims (defaults, versions, feature state); the single hit (Adaptive BDMA default-On, `.research/firstparty/verified-setups.md:58`) MATCHES the code, and three files were sample-read (`.research/README.md`, `.research/wiki/Home.md`, `.research/wiki/version.md`) to confirm the archival character.
- `docs/archive/**` — 17 files (AGENTS_START_HERE, ANTIGRAVITY_NEXT_TASK, BETA13_CUT_CHECKLIST, DOCS_AUDIT_2026-06-15, DOCUMENTATION_FOLLOWUP_AUDIT, GUI_OVERHAUL_PROMPT, HDD_POPSTARTER_HANDOFF, HIGH_LEVEL_CODE_AUDIT, LAUNCH_HYGIENE, PROMPTS, RELEASE_BETA13, REPO_CLEANUP_PLAN, RULES, TRUTHSHEET, U10_INVESTIGATION, and peers): NOT full-read. Reason: self-marked archive/investigation artifacts superseded by STATE.md; they were included in the repo-wide drift-pattern `grep` sweep (their stale hits — e.g. TRUTHSHEET's "HDD (exFAT)/SMB not implemented" — are dated archive content, not current-facing claims, and were not filed).
- `docs/third_party/okeanos_udpfs/UPSTREAM-README.md` and `THIRD_PARTY_NOTICES.md`: NOT read. Reason: third-party upstream text shipped for attribution; it makes no claims about this codebase.
- Non-markdown sources were read only at the lines cited as evidence; a full audit of `src/**` C/C++ internals was out of this section's docs-vs-code scope.
