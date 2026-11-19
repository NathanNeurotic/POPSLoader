# Sable — POPSLoader Audit, ROUND 3

Repo: NathanNeurotic/POPSLoader, pin `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (master) — identical to pass 1 and round 2. Read-only; `git status` clean at start and end of this round. The BDMAssault tarball was extracted to `/tmp/bdma` only; all analysis scripts live in `/tmp`; the throwaway lupa venv at `/tmp/lupavenv` was reused.

Scope of this round: round 2's still-unread list, items 1–5 — the BDMAssault tarball internals, the pademu ds34 driver copies line-by-line, `.research/audit_site.py` + `.research/tools/`, the EE-side ds34 client libraries, and a proof-read of the `system.lua` i18n table bodies (2558–4843). Findings are numbered from POPSLOADER-048. Nothing here repeats POPSLOADER-001…047; where this round's evidence changes an earlier finding, it is listed under **Revisions** instead.

## Tests run this round (host-side; no PS2SDK in this VM, so no PS2 build — same limitation as rounds 1–2)

- `tools/test_disc_layout.py` — **PASS**, 30 disc-icon layout cases, exit 0.
- `tools/host_harness.py` — **62/62 PASS**, exit 0.
- Both re-run this round under `/tmp/lupavenv` (lupa 2.8); the repo was not touched. No hardware was used; no claim below is hardware-verified.

---

## Revisions to earlier findings (evidence-forced)

### REV-006 — POPSLOADER-006's fix changes: the tarball is a provenance pin, not plain clutter

Pass 1 said "delete it from this repo (keep it with the preservation archive if the source must be preserved)". Round 3 opened the archive. The evidence:

- The tarball (`iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz`, 1,466,084 B, md5 `09ff4b911ba131468a25d0ec9a4e2f27`) is a full snapshot of the upstream **BDMAssault** project by israpps (README.MD inside the archive: "the softwares found here were taken and modified from PS2SDK"; release link github.com/israpps/BDMAssault). 151 archive entries, 119 files, 4,951,196 B extracted.
- It is the **only copy of that source anywhere in this repo**: a tracked-file name sweep for its internal sources (`part_driver_gpt.c`, `bd_cache.c`, `ffunicode.c`, `usbd_hub.c`, `bdm_part_driver_gpt.c`, …) returns **0** hits outside the archive. Nothing else in the repo is a duplicate of its contents.
- The folder it sits in is a deliberate pin, in the repo's own words: `COMPONENTS.md` ("`iop/embed/` — … plus the `PS2SDK_MX4SIO` and `BDMASSAULT_MX4SIO` **source pins**"), and `.gitignore:118` force-tracks the folder's binaries (`!iop/embed/BDMASSAULT_MX4SIO/*.irx`) past the blanket binary rules. The two `.irx` beside the tarball (`usbd.irx` 48,500 B, `usbhdfsd.irx` 14,993 B) are the binaries this source builds — the same `usbd.irx` whose md5 (`a77650a0…`) POPSLOADER-002 found embedded in the ELF under three backend names. Deleting the tarball leaves shipped binaries whose exact source vintage is pinned nowhere.
- Vintage is not pedantry in this repo: `Makefile:346-352` documents that the sibling PS2SDK MX4SIO pin "predates the R3Z-era bdm core and its device registration never completes against it: that pairing was the MX4SIO page hanging at 42% since the EXP7 bdm swap" — BDM drivers "must be one vintage as a matched set". The pin exists because the wrong vintage is a hang bug.
- It is **not** the world's only copy (the upstream project is public), so the risk pass 1 understated is narrower than "lose the source forever": it is "lose the record of *which* source vintage produced the shipped binaries".

**Revised fix:** do not plain-delete. Extract the generation that actually builds the shipped IRXs (the merged `__bdm_assault/` + `__usbd_bd_assault/` trees — their Makefiles produce `bdm_assault.irx` / `usbd_bd_assault.irx`, the two binaries the archive's README.MD tells users to install as `usbd.irx` / `usbhdfsd.irx`) as tracked source next to the `.irx` files — or move the whole pin (binaries + extracted source) intact to the preservation archive of POPSLOADER-001 — and delete the `.tar.gz`. Either way the opaque double-storage goes; the provenance stays greppable. The archive's *other* generation is redundant even inside the archive (see the classification table below), so "extract everything as-is" is not the right move either.
**Confidence:** High (READ — archive contents, repo docs, gitignore, Makefile all read this round; the binary↔source correspondence is INFERRED from the folder's documented pin role and the archive README's install mapping, not from a rebuild — no PS2SDK here).

#### Tarball contents classification (all 119 files)

| Class | Contents | Evidence |
|---|---|---|
| Vendored — FatFs R0.14b (ChaN) | `bdmfs_fatfs/src/{ff.c, ffunicode.c, ffsystem.c}`, `bdmfs_fatfs/src/include/{ff.h, ffconf.h, diskio.h}`, `00history.txt`, `00readme.txt`; renamed copies of the same in `__bdm_assault/src/bdmfs/bdmfs_ff*.c` + `include/` | Header at `bdmfs_fatfs/src/ff.c:1-6` ("FatFs - Generic FAT Filesystem Module R0.14b / Copyright (C) 2021, ChaN"). Inventory only, per brief. |
| Vendored-derived — PS2SDK modules, modified | `bdm/` (bdm core + MBR/GPT partition drivers), `libbdm/` (bd_cache, bd_defrag), `usbd/` (hcd/hub/usbd/usbio/interface/mem/driver), `usbmass_bd/` (usb_mass, scsi) | Archive README.MD credits: "taken and modified from PS2SDK". |
| First-party (BDMAssault glue) | `__bdm_assault/`, `__usbd_bd_assault/` merged single-IRX builds; `global.make`; the start-chaining in `__usbd_bd_assault/src/usbd/usbd_usbd.c:334` (`extern int usbmass_bd_start(...)`) and `:409` (`return usbmass_bd_start(argc, argv)` vs the component copy's `return MODULE_RESIDENT_END`), `WELCOME_STR "USBD ASSAULT Start"` at `usbd_usbd.c:28` | Read directly from the extracted tree. |
| Repo-snapshot noise | `.github/workflows/CI.yml`, `.vscode/settings.json`, `.gitattributes`, `.gitignore`, `LICENSE` | File listing. |

Internal duplication (the archive stores its own code twice): the merged generation is the component generation renamed, with include paths gaining an `include/` prefix and the small glue deltas above. Measured diffs: `ff.c`↔`bdmfs_ff.c` 8 diff lines, `ffunicode.c`↔`bdmfs_ffunicode.c` 4, `hub.c`↔`usbd_hub.c` 0, `hcd.c`↔`usbd_hcd.c` 0, `part_driver_gpt.c`↔`bdm_part_driver_gpt.c` 12, `usb_mass.c`↔`usbmass_bd_usb_mass.c` 8. The two `ffunicode.c` copies alone are 1,959,397 + 1,959,389 B — **79% of the extracted tree is the same Unicode table twice**. One file is a pure stray: `__usbd_bd_assault/src/usbd/usbd_usbd_driver.c` is md5-identical to both `__usbd_bd_assault/src/usbd/usbd_driver.c` and `usbd/src/driver.c` (all `dc36d4598562704e77e5b1dec4f27d74`), and no Makefile target builds it (the `__usbd_bd_assault/Makefile` object list resolves `usbd_driver.o` to `usbd_driver.c` via its pattern rule).

### REV-016 — POPSLOADER-016 narrowed: 11 of the 16 `.research/tools/` scripts are living CI, not one-shots

Pass 1 described all sixteen as scripts that "verified a one-time historical-archive recovery" with "one workflow still run[ning] a subset". Read in full this round, the liveness map is:

- **Executed by `.github/workflows/research-network-driver-integrity.yml`:** `verify_network_driver_payloads.py` (workflow lines 41), `compare_recovered_archive_candidates.py` (47, 106, 110), `audit_hosted_patch_members.py` (64), `audit_bitbucket_download_snapshots.py` (74), `audit_legacy_archive_payloads.py` (99), `audit_legacy_tool_overlap.py` (103) — 6 scripts.
- **Executed by `.github/workflows/docs-site.yml`:** `guard_site_deploy.py` (lines 71, 146, 149, 154 — including the actual deploy `check`/`prune`/`record` steps), `audit_legacy_pages.py` (72, 73, 147, 148, 155), `audit_published_provenance.py` (101), `audit_original_wiki_zip.py` (104) — 4 scripts.
- **Shared infrastructure, not a script:** `inspect_network_modules_header.py` is imported as a library — `from inspect_network_modules_header import manifest` at `tools/verify_network_driver_payloads.py:19` (and by `audit_network_driver_crc_overlap.py`) — and is py-compiled + path-triggered by the integrity workflow (lines 7, 40).
- **Referenced by nothing executable:** `audit_network_driver_crc_overlap.py` (79 lines), `audit_original_automated_parity.py` (111), `audit_original_download_links.py` (104), `audit_original_git_history.py` (185), `audit_original_wip06_2017.py` (68) — **5 scripts, 547 lines**. Their only citations are the frozen `.research/research/*.md` reports they were written to produce (e.g. `original-git-gap-audit.md`, `original-git-exact-automated-parity.md`). These five are the true one-shot residue.

**Revised fix:** POPSLOADER-016's move/delete recommendation applies to the five unwired scripts only (547 lines, not ~2,100). The other eleven are standing gates for the site/research corpus and stay as long as that corpus stays; they leave with POPSLOADER-001's archive move, not before it.
**Confidence:** High (READ — both workflows and the import sites read this round).

### REV-034 — POPSLOADER-034 verified in the pademu copies, in context

Round 2 cited the pademu sites from grep. Read in context this round: `modules/pademu/ds34bt.c:1276` and `modules/pademu/ds34usb.c:304` both carry `power_level[report->Power]` guarded only by `report->Power != 0xEE`, inside the same restructured PS-button blocks as their standalone twins. **-034 exists in all four copies, bug-for-bug, exactly as stated.** No change to the finding; its fix count (four one-line guards) is confirmed.

### REV-010 / REV-033 — the pademu copies are a semantic fork, not drifting photocopies

Round 2's -033 framed the fix as "keep one source per driver and have both module Makefiles build from it, with the pademu glue as the only difference". The full line-by-line classification (POPSLOADER-049) shows the pademu copies have a genuinely different API surface and one pademu-only feature (the `analog_btn` pressure-mode toggle) woven through the report parsers themselves — the parsers are precisely where the two lines have semantically forked. -033's duplication verdict stands; its merge shape is understated. The realistic minimum is unchanged in spirit (one canonical parser core), but it is an L-effort refactor of two diverged APIs, not a build-glue change. Recorded so nobody schedules it as the latter.

---

## Findings

### POPSLOADER-048 — Pademu DS4 LED/rumble report is sent with 29 bytes of uninitialised stack

- Category: 6 (bugs/security)
- Locations: `modules/pademu/ds34bt.c:1181` (`mips_memset(led_buf, 0, PS3_01_REPORT_LEN + 2);` in the DS4 arm of `hid_LEDRumble`), `modules/pademu/ds34bt.c:1200` (`size += PS4_11_REPORT_LEN;`), buffer declared `modules/pademu/ds34bt.c:1147` (`u8 led_buf[PS4_11_REPORT_LEN + 2];`). Standalone twin for contrast: `modules/ds34bt/iop/ds34bt.c:1243` (`mips_memset(led_buf, 0, PS4_11_REPORT_LEN + 2);`). Constants: `modules/pademu/ds34bt.h:227` (`PS3_01_REPORT_LEN = 0x30`), `modules/pademu/ds34bt.h:231` (`PS4_11_REPORT_LEN = 0x4D`).
- Problem: In the pademu copy only, the DS4 output report zeroes 0x30+2 = 50 bytes of its 79-byte stack buffer — the DS3 report length constant substituted for the DS4 one — then sends `size` = 2 + 0x4D = 79 bytes via `HID_command`. The DS4 arm explicitly writes only offsets 0–13; bytes 50–78 of every DS4 LED/rumble report are whatever was on the IOP stack. The standalone copy zeroes the full `PS4_11_REPORT_LEN + 2` for the identical code. This is a copy-drift defect introduced on the pademu line; it does not exist in the standalone driver or in the pademu USB copy (USB builds its DS4 report in a shared static buffer).
- Fix: Change the memset length at `modules/pademu/ds34bt.c:1181` to `PS4_11_REPORT_LEN + 2`, matching the standalone copy. One constant.
- Benefit: Medium — every pademu-BT DS4 LED/rumble update stops leaking 29 stack bytes to the controller and sending undefined report tail bytes.
- Effort: S / Risk: Low / Confidence: High (READ both copies in full; constants read in the header)

### POPSLOADER-049 — Pademu ds34 divergence, fully classified: mostly intentional variant, one guard family lost

- Category: 2 (duplication)
- Locations: `modules/ds34bt/iop/ds34bt.c` (1,719 lines) vs `modules/pademu/ds34bt.c` (1,521; 513 diff lines per round 2 — re-derived this round from the full unified diff); `modules/ds34usb/iop/ds34usb.c` (806) vs `modules/pademu/ds34usb.c` (634; 399 diff lines)
- Problem / classification (every hunk of both diffs read and bucketed):
  - **Intentional variant — integration (the bulk of both diffs):** the pademu copies delete the IRX shell (`IRX_ID`, `_start`, the whole SIF RPC server block, ~90 lines per driver), and are instead linked into pademu and called directly (`ds34bt_init(u8 pads, u8 options)`, `ds34usb_init(u8 pads, u8 options)`; callers via the `PAD_*` macros at `modules/pademu/pademu.c:16-31`). APIs are reshaped for that caller: `get_data` returns the analog-mode flag and folds the LED/rumble flush into itself; `set_rumble` only records values under the semaphore; bdaddr get/set and `set_led` entry points are deleted (the USB copy's `link_key` table goes with them); a new `set_mode(mode, lock, port)` serves pademu's mode-lock. `MAX_PADS` rises 2 → 4 in both. BT additionally deletes the adapter-identity chain the RPC product needed — `hci_read_bdaddr` / `hci_read_local_version_information` / `hci_read_local_supported_features`, their event-chain branches, the `bt_bdaddr`/`bt_version`/`bt_features` stores, `bt_dev.vid/pid/rev` capture, and the `get_bdaddr`/`get_ver`/`get_feat` API — and registers the charging driver inside `ds34bt_init` instead of via a separate RPC. None of this is drift; it is what "in-process variant" means.
  - **Intentional variant — pademu-only feature:** the PS+Select / PS+Share `analog_btn` pressure-mode toggle with `btn_delay` debounce (`MAX_DELAY 10`), present in all four report-parser arms of both pademu files (e.g. `modules/pademu/ds34usb.c` DS3 arm around the `power_level` site, `modules/pademu/ds34bt.c:1264-1406` region), indexing `led_patterns[pad][analog_btn & 1]` / `rgbled_patterns[pad][analog_btn & 1]` where the standalone copies hard-code index `[1]`. Plus: USB DS3 arm early-returns on a zero right stick (`modules/pademu/ds34usb.c`, `readReport`: "ledrumble cmd causes null report sometime"); BT sends the L2CAP interrupt-channel request only for DS4 and seeds `btn_delay = 0xFF` on connect; BT pad init force-sets `DS34BT_STATE_USB_CONFIGURED`; BT `ds34bt_reset` adds a final `bt_disconnect(bt_dev.devId)`.
  - **Intentional variant — inverted default:** fake-DS3 detection. Standalone: `disable_fake = 0`, i.e. every connecting DS3 is presumed fake until its MAC matches `GenuineMacAddress`. Pademu: renamed `enable_fake = 0`, set from `options & 1` in `ds34bt_init` — the genuine-MAC check runs only when the caller opts in. A real behavioural divergence a maintainer should know is deliberate; flagged here so it is a decision on record, not an accident in waiting.
  - **Drift — shared, presumably deliberate:** DS4 rumble scaling `rrum` → `rrum * 255` in both pademu copies (USB `LEDRumble` DS4 arm; BT `hid_LEDRumble` at `modules/pademu/ds34bt.c:1187`); LEDRumble no longer caches `lrum/rrum` into the pad struct (pademu's `set_rumble` owns that now); USB drops the `DelayThread(20000)` after init LEDRumble.
  - **Drift — defensive guards lost:** the standalone copies guard their public entry points — `if (port >= MAX_PADS) return;` and, on BT, `if (!(bt_dev.status & DS34BT_STATE_USB_AUTHORIZED)) return;` (standalone `ds34bt_set_rumble` / `ds34bt_get_data` / `ds34bt_get_status`, standalone USB `ds34usb_set_rumble` / `ds34usb_get_data` / `ds34usb_get_status` / bdaddr pair). The pademu copies check **neither**: `modules/pademu/ds34bt.c` `ds34bt_set_rumble`/`ds34bt_get_data`/`ds34bt_get_status` and `modules/pademu/ds34usb.c` `ds34usb_set_rumble`/`ds34usb_get_data`/`ds34usb_get_status` index `ds34pad[port]` directly. Mitigation, stated plainly: the only caller is `pademu.c`, which itself indexes its own `pad[port]` unchecked throughout (e.g. `modules/pademu/pademu.c:375-411`) with ports derived from the SIO2 slot/multitap state — the module's contract is caller-bounded ports, so this is a convention-consistent loss of defence-in-depth, not a demonstrated overflow. It still means the driver copies cannot be lifted into any other caller safely, which is worth one line in each file header.
  - **Bug-for-bug copy:** POPSLOADER-034 (unchecked `power_level[report->Power]`) — see REV-034. POPSLOADER-041's descriptor-walk pattern is standalone-side (USB/BT connect); the pademu copies share the same `bt_connect` descriptor code minus the deleted vid/pid lines, so the missing-guard exposure is inherited identically — no separate pademu item.
  - **Copy-introduced defect:** POPSLOADER-048 (DS4 memset), found only in the pademu BT copy.
  - **Cosmetic:** brace-style reformatting (Allman → K&R on many `if`s) and comment tidy-ups account for a large share of the headline diff-line counts; the semantic divergence is much smaller than 513/399 lines suggest.
- Fix: No code change proposed beyond -048 and the -034 guards. Record the classification; if -033 is ever actioned, treat it as the L-effort API fork it is (REV-010/033). Optionally, one comment line at the top of each pademu copy naming the standalone twin and the caller-bounded-port contract.
- Benefit: Medium — the "two diverging copies" question is now answered hunk-by-hunk; future driver work can stop re-deriving which differences are safe to port.
- Effort: S (documentation) / Risk: Low / Confidence: High (READ — both unified diffs read in full, all cited sites verified in the files)

### POPSLOADER-050 — EE ds34 client libraries: 12 of 22 exported functions have no caller anywhere

- Category: 1 (dead code)
- Locations: `modules/ds34bt/ee/libds34bt.c` (173 lines, 12 exported functions) and `modules/ds34usb/ee/libds34usb.c` (148 lines, 10 exported functions); declarations in `modules/ds34bt/ee/libds34bt.h` / `modules/ds34usb/ee/libds34usb.h`
- Problem: Only `init`, `get_status`, `get_data`, `set_rumble` and `set_led` of each library are ever called (from `src/main.cpp:687-688` and `src/luacontrols.cpp:46-267`). The other twelve — `ds34bt_deinit`, `ds34bt_reinit_ports`, `ds34bt_init_charging`, `ds34bt_get_bdaddr`, `ds34bt_reset`, `ds34bt_get_version`, `ds34bt_get_features`, `ds34usb_deinit`, `ds34usb_reinit_ports`, `ds34usb_get_bdaddr`, `ds34usb_set_bdaddr`, `ds34usb_reset` (~120 of the 321 lines, by function span) — have zero callers in `src/`, `bin/POPSLDR/*.lua` or `etc/` (grep-verified per function). Each library builds as a **single-object** archive (`EE_OBJS = libds34bt.o` in `modules/ds34bt/ee/Makefile`; same shape for USB) and is linked into the ELF (`Makefile:54,82`), so the dead functions are pulled in whole with the used ones — this is ELF bytes, not just source noise. The dead set is exactly the bdaddr/version/features/charging family whose IOP-side RPC handlers (`DS34BT_GET_BDADDR`/`GET_VERSION`/`GET_FEATURES`, `DS34USB_GET_BDADDR`/`SET_BDADDR`) then also serve nobody from the EE side — the same machinery the pademu BT copy already deleted outright (POPSLOADER-049).
- Fix: Delete the twelve uncalled functions from the two EE libraries and their header declarations. Leave the IOP RPC handlers (other EE consumers are conceivable there); revisit them only if the standalone drivers are ever pruned.
- Benefit: Low-Medium — ~120 lines and their compiled size out of a linked object; the EE API surface becomes exactly what the loader uses.
- Effort: S / Risk: Low (zero in-repo callers, grep-verified; Risk would rise only if an out-of-repo consumer links these `.a` files, which nothing in the tree suggests) / Confidence: High (READ both libraries in full; caller sweep READ)

### POPSLOADER-051 — i18n tables carry 14 dead entries: a superseded toast key in six languages, eight Hungarian-only orphans

- Category: 1 (dead code)
- Locations: `bin/POPSLDR/system.lua` I18N block (2568–4843). Spot-verified pairs: DE at `system.lua:3078` (live key) vs `system.lua:3079` (stale key); PT at `system.lua:3386` vs `system.lua:3387`
- Problem: One toast was reworded — the live English key is `"SMB modules are not installed\nGames list but won't boot without them --\ninstall via Settings > SMB modules, then Save"`. Six languages (FR, DE, PT, ES, IT, HU) carry **both** the live key and its predecessor `"SMB modules are not installed\nGames will list but won't boot -- install them\nvia Settings > SMB modules first"`, whose translation can never fire (a table key only matches the exact runtime string). SK carries only the live key. The stale copies sit directly under the live ones (3078/3079, 3386/3387), so a translator editing the visible pair can fix the wrong one and change nothing. Hungarian carries eight further keys with no matching string anywhere in the three Lua scripts: `'Save your changes before leaving?'`, `"Don't Save"`, `'Save Settings'`, `'Profile defaults restored'` (the profile-preset system was removed 2026-07-13, per the repo's AGENTS.md — this key's feature no longer exists), `'ART (at root)'`, `'POPS (beside game)'`, and the two monolithic button hints `'X = Keep      O = Revert'` / `'X = Select      O = Cancel'` — hints are now composed by `UI.PadHintPair("Keep", "Revert")` / `UI.PadHintPair("Select", "Cancel")` at `bin/POPSLDR/ui.lua:7320` and `bin/POPSLDR/ui.lua:7062`, so the pre-composed strings can never be produced.
- Method (so this is reproducible, not vibes): the I18N block was extracted and evaluated with a real Lua runtime (lupa 2.8, `/tmp` script), then every key was searched — raw and Lua-escaped — against the full text of `system.lua` outside the block plus `ui.lua` and `images.lua`. A first pass with the escaping inverted produced ~41 false orphans per language; the corrected pass leaves exactly the 14 above.
- Fix: Delete the 14 dead entries (6 stale toast keys + 8 HU keys). Nothing else in the tables needs touching — see the evidence notes for the clean results.
- Benefit: Low-Medium — small size win inside POPSLOADER-003's tables, and the translator-trap pairs are gone.
- Effort: S / Risk: Low / Confidence: High (READ + script-verified; the two live/stale pairs and the PadHintPair call sites verified by direct read)

### POPSLOADER-052 — audit_site.py hard-codes page prose and magic numbers as publish-gate law

- Category: 7 (build/CI/repo clutter)
- Location: `.research/audit_site.py:124-160` — the catalogue-size floor (`len(history_rows) < 80`), the exact byte size for one package (`tracked_size.get('NOPAL_PATCH.7z', 226) != 226`), hard-coded inventory counts and phrases that `history.html`/`credits.html` must contain verbatim (`'The 15 original news bulletins'`, `'1094748012'`, `'3844714277'`, `'34 original screenshot/image references not recovered'`, …)
- Problem: The script is a **living** gate — `.github/workflows/docs-site.yml:80` runs it on every site build and its exit code is armed (final lines of the script). But a slice of its assertions are one-time recovery observations promoted to invariants, the same pattern as POPSLOADER-040 in `build_site.py`: the day a maintainer legitimately edits the history page's prose or the catalogue shrinks, the publish gate fails with a message about a missing phrase, not about a snapshot having been frozen into a check. (The link/anchor/policy machinery in the same file is genuinely behavioural and is *not* part of this finding.)
- Fix: Demote the prose-phrase and magic-number checks to printed warnings, like -040 proposes for `build_site.py`; keep the structural checks (dead links, dead anchors, withheld-download policy, search-index resolution) as hard failures.
- Benefit: Low — the docs gate stops breaking for non-reasons, in the second of the two site tools.
- Effort: S / Risk: Low / Confidence: High (READ in full)

---

## Evidence notes (checked and *not* flagged)

- **i18n format safety is clean.** All 2,248 entries across the seven tables (FR 304, ES 304, DE 305, PT 305, IT 305, HU 317, SK 409; 426 distinct English keys) were compared against their English source keys for format-specifier signature (count, conversion type, order; `%%` excluded): **zero mismatches**. The feared class — a translation whose `%s`/`%d` set differs from the template — does not exist in the data. It is also defended in code: `PLDR.LFmt` (`system.lua` immediately after the I18N block, ~4866-4876) formats through `pcall(string.format, …)` and falls back to the English template on error, with a comment explaining exactly this threat model. No finding; POPSLOADER-003's size point stands untouched.
- **No duplicate keys** inside any i18n table (raw-text pass; Lua would have silently overwritten them): 0 found.
- **Untranslated-but-shipped entries are modest and mostly legitimate:** values byte-identical to their English key number 3 (ES) to 18 (SK) per language, and the samples are dominated by strings that are the same in the target language (`DNS`, `Gateway`, `100M Full`, `Slot:`, model/brand terms). HU's handful of full-sentence identities (e.g. `'Report this code -- the card may be fine'`) read as untranslated residue — noted here, not numbered: they are a translation-coverage nit inside POPSLOADER-003's scope, not a code defect.
- **Fallback structure is sound:** `PLDR.L` returns the English source for any missing entry and for EN itself (EN has no table by design); partial coverage cannot blank a string. READ at `system.lua:4849-4860`.
- **EE↔IOP RPC protocol agreement (standalone path):** the EE libraries' command IDs and buffer layouts match the standalone IOP `rpc_sf` handlers (USB commands 1–8, bind `0x18E3878E`; BT commands 1–10, bind `0x18E3878F`), including the asymmetric bdaddr result placement (USB: flag at `rpcbuf[0]`, address at `[1..6]`; BT: address at `[0..5]`, flag at `[6]`). No mismatch found.
- **Tarball vs repo duplication:** none — see REV-006. The archive's internal two-generation duplication is upstream's own layout; it is reported as classification, and only becomes this repo's problem through the revised -006 fix shape.
- **`audit_site.py` itself is otherwise healthy:** no import-time side effects (contrast POPSLOADER-037), deterministic, and its gate is armed. `guard_site_deploy.py` is live deploy tooling (REV-016), not a one-shot.

## Coverage ledger — what was actually read this round

| Item | Coverage |
|---|---|
| `iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz` | Extracted to `/tmp/bdma`; all 119 files inventoried by path/size; Makefiles, README.MD, `global.make` presence, FatFs headers read; 8 cross-generation pairs diffed; 3-way md5 on the driver.c triple; repo-side duplication swept by filename + reference grep. Contents not line-audited (vendored/upstream code — classification was the assignment). |
| `modules/pademu/ds34bt.c` (1,521) / `modules/pademu/ds34usb.c` (634) | Full unified diffs against the standalone copies read hunk-by-hunk (654 + 513 diff lines); every divergence bucketed in POPSLOADER-049; cited sites verified in-file. |
| `.research/audit_site.py` (180) | READ IN FULL. |
| `.research/tools/*.py` (16 files, 2,055 lines) | Liveness established per file from both workflows' execute-lines + import graph; headers/docstrings of the five unwired scripts read; the eleven wired ones were not line-audited (they are gates, and REV-016 is a liveness correction, not a code review of them). |
| `modules/ds34bt/ee/libds34bt.c` (173) + `.h` (33), `modules/ds34usb/ee/libds34usb.c` (148) + `.h` (19), both ee Makefiles | READ IN FULL; caller sweep over `src/`, `bin/POPSLDR/*.lua`, `etc/` per exported function. |
| `system.lua` i18n bodies (2568–4843) | Evaluated programmatically with a real Lua runtime; 100% of entries specifier-checked and orphan-checked by script; spot pairs (3078/3079, 3386/3387) and the `PLDR.L`/`PLDR.LFmt` machinery read directly. Not a translation-*quality* proof-read (same boundary as round 2). |

## Still unread (the round-2 list, updated)

Round 2 left seven items; this round closed items 1–5 (pademu line-audit, BDMAssault contents, i18n proof pass, `.research` one-shots, EE ds34 libraries). What remains:

1. The eleven CI-wired `.research/tools/` scripts line-by-line (2,055 − 547 ≈ 1,508 lines). They are living gates; a code-quality pass on them is possible but ranks below everything else in the repo.
2. BDMAssault tarball contents line-by-line — deliberately not done: it is upstream/vendored code whose disposition is settled by revised POPSLOADER-006; if the pin is extracted per that fix, the extracted tree becomes tracked source and a future pass could audit it then.
3. Binary assets and IRX contents — not text-auditable; pass 1 covered sizes and hashes.
4. No PS2 build was run (no PS2SDK in this VM) and no hardware was touched — all runtime claims above rest on the host harness (62/62) and the disc-layout test (30/30), not on console behaviour.
