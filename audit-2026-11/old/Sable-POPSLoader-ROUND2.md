# Sable — POPSLoader Audit, ROUND 2

Repo: NathanNeurotic/POPSLoader, pin `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (master) — identical to pass 1. Read-only; `git status` clean at start and end of this round.

Scope of this round: the pass-1 footer debts — `tools/host_harness.py` and `.research/build_site.py` read in full, `bin/POPSLDR/system.lua` and `bin/POPSLDR/ui.lua` read end-to-end, IOP driver sources line-audited, and `tools/test_disc_layout.py` actually run. Findings are numbered from POPSLOADER-026 and sorted by benefit. Nothing here repeats a pass-1 finding; where a round-2 item extends a pass-1 item, it says so.

## Tests run this round (host-side; no PS2SDK in this VM, so no PS2 build — same limitation as pass 1)

- `tools/test_disc_layout.py` — **PASS**, "PASS 30 disc-icon layout cases (NTSC, PAL, details lift, aspect and visibility)", exit 0. (Pass 1 could not run it: `lupa` missing. Satisfied this round via a throwaway venv at `/tmp/lupavenv` with lupa 2.8; the repo was not touched.)
- `tools/host_harness.py` — **62/62 PASS**, exit 0, same venv.

## pcall idiom — re-quantified, no new finding (extends POPSLOADER-023)

Pass 1 flagged the defensive pcall idiom qualitatively. Measured this round: **250 pcall sites in system.lua, 110 in ui.lua, 2 in images.lua (362 total)**. Honest cost/benefit: the per-call cost on the EE Lua VM is small, and most sites wrap IOP/file calls whose failure modes are real (unmounted partitions, missing files, half-initialised drivers) — the idiom is load-bearing, not cargo cult. The genuine cost is the one already visible in findings 026/030 below: pcall/xpcall wrappers make dead fallback branches and silently-nil data look safe. No new finding; 023 stands as written.

---

## Findings

### POPSLOADER-026 — Settings save carries a second, diverged copy of the whole commit sequence as a "fallback"

- Category: 2 (duplication)
- Location: `bin/POPSLDR/ui.lua:4550–4613` (inside `queue_exit`, ui.lua:4459)
- Problem: `queue_exit` calls `PLDR.CommitSettingsChanges({...})` when it is a function — which system.lua always defines before any save can run — and otherwise falls through to ~64 lines that re-implement the commit by hand: direct `PLDR.*` field assignments, normalisers, `SaveSettingsAtomic()`, `ApplyBdmaMode()`. The copy has already diverged: it has no SMB apply stage, no Ember/RetroGem/hide-text handling, and different failure semantics from the real path.
- Fix: Delete the fallback body; call `PLDR.CommitSettingsChanges` directly. If it is somehow absent, that is a load-order bug to surface, not a second implementation to maintain.
- Benefit: High — removes ~64 lines from the single most-edited flow in the app and ends the drift between two commit implementations.
- Effort: S / Risk: Low / Confidence: High (READ)

### POPSLOADER-027 — UDPFS "is it equipped" check re-reads and byte-compares whole IRX files from the memory card on every launch

- Category: 5 (performance)
- Location: `bin/POPSLDR/system.lua:8040–8050` (UDPFS arm of `PLDR.IsBdmaModeEquipped`, defined system.lua:8022); called on the launch path via `PLDR.MaybeApplyAdaptiveBdma` (system.lua:8068) and directly at system.lua:11072
- Problem: For target `UDPFS`, after the cheap existence pass, the function loops over every file in `BDMA_COPY_FILES`, fetches the embedded reference bytes and does `ReadWholeFile(path) ~= expected` — a full read + full byte-compare of each staged driver file from the memory card, on every launch that reaches the check. The size comparison (`GetFileSizeSafe(path) ~= #expected`) already runs first in the same expression, so the whole-file compare only adds discrimination against same-size corruption, at the cost of the slowest storage in the system on the launch path.
- Fix: Drop the whole-file compare and keep the existence + size test (the files are staged by this same code from embedded assets; a same-size silent corruption of an MC file is not a failure mode worth a per-launch full read). If byte-exactness is ever genuinely needed, verify once at staging time, not at every launch.
- Benefit: Medium-High — removes several full file reads from every UDPFS-mode launch.
- Effort: S / Risk: Low / Confidence: High (READ)

### POPSLOADER-028 — A self-described "TEST" HDD write probe runs, and toasts, on every production Settings save

- Category: 8 (half-finished/redundant feature)
- Location: definition `bin/POPSLDR/system.lua:980` (`PLDR.ProbeHddSettingsWrite`); call site `bin/POPSLDR/ui.lua:4622–4637`
- Problem: On every successful Settings save on an HDD boot, the UI calls a function the code itself labels "(TEST)" (ui.lua comment at the call site): it mount-RW-probes the `__.POPS*` game partitions, writes and deletes a `pldrs_wtest.tmp` file, and posts a success/failure toast. A diagnostic written to answer a one-time question ("does a game partition accept writes?") is now a permanent side effect — extra mounts and a file write on the user's game partitions, plus one of the most-seen toasts on an HDD rig — on every save, forever.
- Fix: Delete the call from the save path and delete the function. If the diagnostic is ever needed again, it belongs behind an explicit debug action, not in the save path.
- Benefit: Medium-High — removes partition mounts + a write from every HDD Settings save and a noisy toast with them.
- Effort: S / Risk: Low / Confidence: High (READ)

### POPSLOADER-029 — Two independent implementations of the same PLDRGC1 game-list cache format

- Category: 2 (duplication)
- Location: `bin/POPSLDR/system.lua:9880` (`PLDR.SaveGameListCache`) and `:9899` (`PLDR.LoadGameListCache`) vs `bin/POPSLDR/system.lua:9944` (`PLDR.HDD.CreateCache`) and `:9991` (`PLDR.HDD.ReadCache`)
- Problem: The generic game-list cache and the HDD game-list cache each carry their own serialise/parse implementation of the same PLDRGC1 format (game lines + H-lines for hidden entries), a few dozen lines apart. Format changes — or format bugs — have to be made twice, and the two parsers can silently drift apart while reading each other's files.
- Fix: One serialiser/parser for the format, called by both. This is the rare case that meets the sharing bar: same logic, two places, and merging removes code overall.
- Benefit: Medium — one format implementation to fix and to trust.
- Effort: M / Risk: Medium (cache files are user data on cards/HDD; the merged parser must accept what both writers emit today) / Confidence: High (READ)

### POPSLOADER-030 — Settings rollback passes two fields that no longer exist anywhere in the settings system

- Category: 6 (bugs/security)
- Location: `bin/POPSLDR/system.lua:6675–6683` (BDMA-failure rollback inside `PLDR.CommitSettingsChanges`)
- Problem: The rollback calls `ApplySettingsState({ profile = next_state.profile, …, popstarter_mode = next_state.popstarter_mode, … })`. Neither field is produced by `SnapshotSettingsState` (system.lua:5959) or consumed by `ApplySettingsState` (system.lua:5994) — `popstarter_mode` occurs exactly once in the whole file, on line 6678. They are leftovers of the removed profile-preset system, silently nil on every rollback. Today they are harmless dead data; the risk is that the rollback *looks* complete while two of its assignments do nothing, in the code path that runs when a BDMA apply has already failed once.
- Fix: Delete the `profile` and `popstarter_mode` entries from the rollback table.
- Benefit: Medium — the rollback table becomes exactly the set of fields that actually roll back.
- Effort: S / Risk: Low / Confidence: High (READ; field absence verified by grep over the whole file)

### POPSLOADER-031 — Permanently-false flag leaves five dead branches in the hottest launch function

- Category: 3 (overengineering)
- Location: `bin/POPSLDR/system.lua:10843` (`local use_minimal_hdd_popstarter_exec = false` in `RunPOPStarterGame`), with dead/constant-folded branches at system.lua:10844, 10859, 10873, 11155, 11278
- Problem: A local constant that can never be true gates five conditionals inside the per-device launch function — the highest-risk surface in the repo. Every reader of the launch path has to reason about a "minimal exec" mode that does not exist and cannot be enabled without editing source.
- Fix: Delete the flag and fold the five branches to their always-taken sides.
- Benefit: Medium — the launch function gets shorter and every remaining branch in it is real.
- Effort: S / Risk: Low / Confidence: High (READ)

### POPSLOADER-032 — Seven Lua functions with zero callers, including a near-twin of a live resolver

- Category: 1 (dead code)
- Locations (definition sites; each verified by repo-wide grep — the name occurs nowhere else):
  - `bin/POPSLDR/system.lua:944` — `ResolveHddGamePartitionReadablePath` (local). Its near-twin `ResolveHddPartitionReadablePath` (system.lua:886, wrapped at 1897) is the live one; the dead copy invites editing the wrong function.
  - `bin/POPSLDR/system.lua:4972` — `CYCLE_CLAMP` (global). Its sibling `CLAMP` (system.lua:4966) is the one actually used.
  - `bin/POPSLDR/system.lua:5615–5617` — `PLDR.EnsureTrailingSlashNorm`, a one-line wrapper over `EnsureTrailingSlashNormRaw` with no callers.
  - `bin/POPSLDR/system.lua:10364` — `GetBootOccupiedPfsSlot` (local).
  - `bin/POPSLDR/system.lua:11320` — `Touch` (global).
  - `bin/POPSLDR/ui.lua:3223` — `GameList.Reset` (field of the `GameList` literal, ui.lua:3213); the resets it performs are duplicated inline in the literal and in `OnSceneEnter`.
  - `bin/POPSLDR/images.lua:81` — `IMG.ReleaseAll`.
- Problem: Dead entry points in bin2c'd Lua are invisible to the syntax gate and the host harness; they cost ELF size, load-order surface, and reader time — and the `ResolveHdd…` twin is an active trap in a preservation-contract area (HDD readable-path resolution).
- Fix: Delete all seven definitions.
- Benefit: Medium — small size win, real clarity win, one wrong-function trap removed.
- Effort: S / Risk: Low / Confidence: High (READ + grep-verified zero references)

### POPSLOADER-033 — The DS3/DS4 IOP drivers are maintained as two diverging copies

- Category: 2 (duplication)
- Locations: `modules/ds34bt/iop/ds34bt.c` (1,719 lines) vs `modules/pademu/ds34bt.c` (1,521 lines) — 513 diff lines; `modules/ds34usb/iop/ds34usb.c` (806 lines) vs `modules/pademu/ds34usb.c` (634 lines) — 399 diff lines
- Problem: The standalone IRXs (embedded in the ELF) and the pademu IRXs (built for POPStarter-side loading) each carry their own copy of the same DualShock 3/4 driver: the same report parsers, the same static tables (`output_01_report`, `led_patterns`, `power_level`, `rgbled_patterns`, `link_key` — present in all four files), the same RPC surface. The copies have already diverged by hundreds of lines, so there is no longer an obvious canonical version, and every driver fix (see POPSLOADER-034, which exists in four places) must be found and ported up to four times.
- Fix: Keep one source per driver and have both module Makefiles build from it, with the pademu-specific glue (the `PAD_*` macro layer in `modules/pademu/pademu.c`) as the only difference. If the link contexts genuinely forbid sharing, say so in a comment at the top of each copy naming the other copy — the current state doesn't even do that.
- Benefit: Medium — halves the surface for every future controller fix.
- Effort: L / Risk: Medium / Confidence: High (READ both standalone drivers in full; pademu copies diffed and grep-checked)

### POPSLOADER-034 — DS3 battery byte indexes a 6-entry table with no range check, in all four driver copies

- Category: 6 (bugs/security)
- Locations: `modules/ds34bt/iop/ds34bt.c:1333`, `modules/ds34usb/iop/ds34usb.c:299`, `modules/pademu/ds34bt.c:1276`, `modules/pademu/ds34usb.c:304` — all of the form `power_level[report->Power]`
- Problem: In the DS3 report parsers, `report->Power` is a full device-supplied byte (`u8 Power`, headers note `05=full … EE=charging`). The only guard before indexing the 6-entry `power_level[]` table is `Power != 0xEE`. Any other out-of-range value (0x06–0xED — exactly what a clone/fake pad, which this driver explicitly supports, might send) reads past the table into adjacent static data and puts a garbage byte in the LED pattern. Not a crash on IOP, but an unchecked device-controlled index in a parser of untrusted input.
- Fix: Only index when `Power <= 5` (treat anything else like the no-battery-display case). Four one-line guards, one per copy — or one, if POPSLOADER-033 lands first.
- Benefit: Medium — removes an untrusted-input index from the controller hot path.
- Effort: S / Risk: Low / Confidence: High (READ; field type and table size verified in the headers)

### POPSLOADER-035 — ps2atad probes the phantom slave drive, then unconditionally throws the result away

- Category: 1 (dead code) / 5 (performance)
- Location: `iop/ata_bd_fast/ps2atad.c:1242–1262` (probe loop in `ata_init_devices`) and `iop/ata_bd_fast/ps2atad.c:1286` (`devinfo[1].exists = 0;`)
- Problem: The file's own comments establish that a retail PS2's internal ATA bus is master-only, and the maintainers already added a capped busy-ladder plus a long comment explaining why device 1 must be forced out (concurrent access to the single command state). But the non-DVRP probe loop still runs the full device-1 pass — a bus-wide soft reset, device select, and probe, each wait capped at ~4 s worst case — and line 1286 then discards whatever it found, unconditionally. (The DVRP path is separate and re-probes device 1 *after* the force-clear; it is not affected by this finding.)
- Fix: Run the non-DVRP probe loop for device 0 only. The force-clear at line 1286 stays as the belt-and-braces guard for the DVRP path.
- Benefit: Medium — removes a redundant bus reset and up to ~4 s of capped phantom-slave waits from every internal-HDD init, in the exact driver whose comments describe multi-minute exFAT-page stalls.
- Effort: S / Risk: Low / Confidence: High (READ)

### POPSLOADER-036 — Much of the host harness asserts source text, not behaviour — and re-reads the same files all run long

- Category: 7 (build/CI/repo clutter)
- Location: `tools/host_harness.py` — e.g. T42 at lines 1776–1790 (asserts `_ui.count("UI.PendingHideDrop = entry") != 2` fails the build, plus a string-`index()` ordering check as a proxy for control flow); the T43–T55 blocks re-read sources at lines 1815, 1949–1950, 1982–1983, 2017–2020, 2137–2138, 2180, 2217–2221, 2282, 2412–2414
- Problem: The harness is the project's only runtime-class CI gate, and it genuinely executes system.lua — but roughly a fifth of its 62 checks never execute anything: they assert substrings, exact occurrence counts, and string positions in system.lua / ui.lua / main.cpp / luasystem.cpp / elf.c / the Makefile. Any rename, reformat, or comment edit in those strings fails CI with no behaviour change, and trains exactly the "don't touch the launch path" fear the file exists to prevent. The same sources are also re-read from disk at least 25 times per run (`read_text` sites) instead of using the copies loaded at lines 23–24. Separately, the numbering tells on the accretion: there is no T4, and T61/T62 sit before T7 in the file.
- Fix: Where a text check guards real behaviour, convert it to an executed check (the harness already has the mocked environment); where it only guards wording, delete it. Load each source once. Leave the numbers alone — renumbering is churn.
- Benefit: Medium — CI that fails only when behaviour breaks, and a gate people keep trusting.
- Effort: M / Risk: Low / Confidence: High (READ in full; harness run green this round, 62/62)

### POPSLOADER-037 — build_site.py wipes its output directory at import time

- Category: 7 (build/CI/repo clutter)
- Location: `.research/build_site.py:13` (top-level `shutil.rmtree(SITE, ignore_errors=True)`), plus a top-level corpus `print` at the end of the module
- Problem: The destructive clean runs at module top level, not under `main()` or the `__main__` guard. Anything that imports the module — a test, `.research/audit_site.py`, an interactive session — deletes `.research/site` before a single line of the importer's code runs. The script is live (`.github/workflows/docs-site.yml` runs it), so the footgun sits in the publishing path of the public docs site.
- Fix: Move the `rmtree` (and the corpus print) into `main()`.
- Benefit: Medium — removes a delete-on-import footgun from a publishing tool.
- Effort: S / Risk: Low / Confidence: High (READ)

### POPSLOADER-038 — ATA security-erase path refreshes status by running IDENTIFY DEVICE into a NULL buffer

- Category: 6 (bugs/security)
- Location: `iop/ata_bd_fast/ps2atad.c:1183` (`ata_get_security_status(device, devinfo, NULL);` at the end of `sceAtaSecurityEraseUnit`, ps2atad.c:1165)
- Problem: `ata_get_security_status` passes its `param` argument straight to `ata_device_identify`, which issues IDENTIFY DEVICE with that pointer as the data buffer. IDENTIFY is a PIO-in command, and the PIO path writes 256 words through `cmd_state->buf16`. Called with NULL, a successful erase-unit therefore ends by writing 512 bytes through a NULL pointer on the IOP. The other two callers pass the real `ata_param` buffer; only the erase path passes NULL. Reachability: this is an exported library function (export 12) — no in-repo caller was found, so the trigger is an external IRX consumer of the atad exports, which is why this is Medium-Low rather than High.
- Fix: Pass `ata_param` like the other callers (the status refresh only reads `param[ATA_ID_SECURITY_STATUS]`).
- Benefit: Medium-Low — removes a NULL-deref write from an exported driver's error-handling tail.
- Effort: S / Risk: Low / Confidence: High for the code path (READ); Medium for reachability (INFERRED — exports are the API surface)

### POPSLOADER-039 — images.lua still carries the fallback machinery for a fallback that was removed

- Category: 1 (dead code)
- Location: `bin/POPSLDR/images.lua:46` (`IMG_FALLBACKS = {}`), read at `bin/POPSLDR/images.lua:64` inside the `IMG` `__index` metamethod
- Problem: `IMG_FALLBACKS` is never populated anywhere in the repo (grep-verified), so the fallback branch in the `__index` metamethod — which runs on every image lookup miss — can only ever find nil. The repo's own AGENTS.md records that the `default.png` fallback hook was deliberately dropped when MISSING.png was removed; this table and its check are the leftover half of that removal.
- Fix: Delete `IMG_FALLBACKS` and the branch that reads it.
- Benefit: Low-Medium — one less misleading path in the asset system every image lookup flows through.
- Effort: S / Risk: Low / Confidence: High (READ + grep-verified never written)

### POPSLOADER-040 — build_site.py hard-fails the whole docs build unless the corpus has exactly 34 image records, 19 of them from HEAD

- Category: 7 (build/CI/repo clutter)
- Location: `.research/build_site.py:885–905` (`build_original_image_gap_index`: `if len(records) != 34 or len(seen & from_head) != 19: raise …`), with matching hard-coded counts in output text (e.g. "63 wiki pages" in the archive README string, "2,140 commits" in the credits data)
- Problem: A one-time inventory observation has been baked in as a build invariant. The day the corpus legitimately gains or loses an image, the publishing build for the whole site raises instead of building — and the failure message points at the inventory, not at the fact that a snapshot count was promoted to a law.
- Fix: Demote the check to a printed warning in the build log. The hard-coded counts in prose should be computed from the data they describe (several already are, on the home page stats row).
- Benefit: Low-Medium — the docs build stops breaking for non-reasons.
- Effort: S / Risk: Low / Confidence: High (READ)

### POPSLOADER-041 — ds34 connect paths walk USB descriptor blobs with no NULL or zero-length guards

- Category: 6 (bugs/security)
- Locations: `modules/ds34usb/iop/ds34usb.c:139–175` (`usb_connect`); same pattern at `modules/ds34bt/iop/ds34bt.c:113–160` (`bt_connect`)
- Problem: Both connect callbacks fetch the config/endpoint descriptors and immediately dereference them (`config->bLength`, `endpoint->bmAttributes`) with none of the NULL checks their own probe functions perform, then advance through the blob by `endpoint->bLength` — a zero `bLength` from a malformed or clone device loops forever on the IOP. The USB copy additionally hard-codes `epCount = 20` for DS4 (comment: "ds4 v2 returns interface->bNumEndpoints as 0") and walks 21 descriptors regardless of the blob's actual length. These drivers attach to arbitrary USB hardware, including the fake/clone devices the codebase explicitly supports.
- Fix: NULL-check the fetched descriptors as the probes already do, and stop the walk when `bLength == 0`. Keep the DS4 endpoint-count workaround, but bound the walk by it *and* the zero-length stop.
- Benefit: Low-Medium — removes a hang-on-connect class for malformed devices. (Inherited OPL-era pattern; flagged because this repo ships and maintains the code.)
- Effort: S / Risk: Low / Confidence: High for the missing checks (READ); Medium for real-world triggerability (INFERRED)

### POPSLOADER-042 — Disc-layout test extracts the code it tests by exact comment strings

- Category: 7 (build/CI/repo clutter)
- Location: `tools/test_disc_layout.py:12–13`
- Problem: The test locates the ui.lua disc-icon block with `source.index("          -- An OPL-style _ICO.png")` and `source.index("          -- (EXP56:", start)` — exact comment text, including leading whitespace. Any edit to those comments makes the test die with a raw `ValueError` that says nothing about comments, and silently couples a comment's wording to CI. The test itself is good (it passed this round, 30 cases); only the extraction is brittle.
- Fix: Anchor on a code token that cannot be reworded casually (the function/variable the block defines), or lift the layout function into a form the test can load by name.
- Benefit: Low-Medium — one less misleading CI failure mode.
- Effort: S / Risk: Low / Confidence: High (READ; test run this round)

### POPSLOADER-043 — GameList scene still renders a "Not implemented yet" placeholder branch that can never fire

- Category: 1 (dead code)
- Location: `bin/POPSLDR/ui.lua:3263–3271` (in `GameList.Play`)
- Problem: The scene keeps an always-empty `placeholders = {}` table, looks the current scene up in it, and has a render branch for the hit — under a comment that already says "No scenes are placeholders anymore". With the table permanently empty, `placeholder_title` is always nil and the branch is unreachable; it's scaffolding for a hypothetical future backend, kept after the need passed.
- Fix: Delete the table, the lookup, and the branch.
- Benefit: Low — a few lines and one misleading branch out of the main list scene.
- Effort: S / Risk: Low / Confidence: High (READ)

### POPSLOADER-044 — Gutted pad-debug block computes values, discards them, and times them with the wrong unit

- Category: 1 (dead code)
- Location: `bin/POPSLDR/ui.lua:6670–6699` (behind `UI.InputConfig.DEBUG_INPUT_LOG`, default `false` at ui.lua:1270)
- Problem: The block's logging body is gone. What remains computes `up/down/cross/circle` locals (ui.lua:6677–6680) and discards them, and maintains two timers whose counters are only ever reset, never read. It also compares `Timer.getTime()` deltas against `1000` — and `Timer.getTime()` returns microseconds in this codebase (per the repo's own AGENTS.md gotchas), so even the surviving scaffolding runs its "1-second" cadence every millisecond when the flag is on.
- Fix: Delete the block and the `DEBUG_INPUT_LOG` flag. If pad debugging is needed again, it can come back as a logger that logs.
- Benefit: Low — dead scaffolding out of the per-frame pad path.
- Effort: S / Risk: Low / Confidence: High (READ)

### POPSLOADER-045 — build_site.py renders its largest page twice per build

- Category: 5 (performance)
- Location: `.research/build_site.py:1997` and `.research/build_site.py:2001` (`build_thread_study`)
- Problem: The thread-study page — the biggest markdown source in the corpus — is run through `clean_research` + `render_md` twice in a row: once for the page body and once to build the search-index text. The second render's output is only used after stripping its tags.
- Fix: Render once, reuse the result for both the page and the (tag-stripped) index text.
- Benefit: Low — a faster docs build; the pattern is worth more than the seconds if the corpus grows.
- Effort: S / Risk: Low / Confidence: High (READ)

### POPSLOADER-046 — build_site.py defines slug() twice; the first definition is dead

- Category: 1 (dead code)
- Location: `.research/build_site.py:90–91` (`SLUG_RE` + `def slug`), shadowed by the identical redefinition at `.research/build_site.py:102–103`
- Problem: The first `SLUG_RE`/`slug` pair is overwritten eleven lines later by a second, identical pair. Harmless today; a trap the first time someone edits the visible-first definition and nothing changes.
- Fix: Delete lines 90–91.
- Benefit: Low — pure trap removal. Quick win.
- Effort: S / Risk: Low / Confidence: High (READ)

### POPSLOADER-047 — Clamp01 is defined twice in ui.lua

- Category: 2 (duplication)
- Location: `bin/POPSLDR/ui.lua:14` (file-scope local) and `bin/POPSLDR/ui.lua:1946` (a second local inside `WelcomeDraw.Play`, used at ui.lua:1971)
- Problem: The same one-line clamp helper exists twice in one file, six screenfuls apart in maintenance terms. They are identical today; nothing enforces that they stay identical.
- Fix: Delete the nested copy at ui.lua:1946 and let the welcome animation use the file-scope one.
- Benefit: Low — one helper, one definition. Quick win.
- Effort: S / Risk: Low / Confidence: High (READ)

---

## Coverage ledger — what was actually read this round

| File | Coverage |
|---|---|
| `bin/POPSLDR/system.lua` (11,784 lines) | READ IN FULL, lines 1–11784. Exception: the i18n string-table bodies at 2801–4840 were structure-scanned, not proof-read line by line (pass 1 sampled them; POPSLOADER-003 already covers their size). |
| `bin/POPSLDR/ui.lua` (7,599 lines) | READ IN FULL, lines 1–7599. |
| `bin/POPSLDR/images.lua` (93 lines) | READ IN FULL. |
| `tools/host_harness.py` (2,759 lines) | READ IN FULL; also executed (62/62 PASS). |
| `tools/test_disc_layout.py` (56 lines) | READ IN FULL; also executed (PASS, 30 cases). |
| `.research/build_site.py` (2,377 lines) | READ IN FULL, lines 1–2377. |
| `modules/pademu/pademu.c` (536) / `modules/pademu/sys_utils.c` (94) | READ IN FULL. No findings: this is inherited OPL mcemu hook code; the one soft spot (`_start` reading `argv[1][0..3]` without a length check) matches the upstream original and IOP module-arg convention. |
| `modules/ds34usb/iop/ds34usb.c` (806) | READ IN FULL. |
| `modules/ds34bt/iop/ds34bt.c` (1,719) | READ IN FULL. |
| `iop/ata_bd_fast/ps2atad.c` (1,593) | READ IN FULL. |
| `modules/pademu/ds34bt.c` (1,521) / `modules/pademu/ds34usb.c` (634) | NOT read line-by-line — audited by full diff against the standalone copies (513 / 399 diff lines) plus targeted greps; their `power_level` sites are cited in POPSLOADER-034 from direct grep hits. |
| Repo `AGENTS.md` | READ IN FULL (house rules; several citations cross-checked against it). |

Automated assistance used: per-file function-definition and pcall counts; duplicated-block detection (normalised 6-line windows) over system.lua/ui.lua — its raw output (54 groups in system.lua, 23 in ui.lua) was used only where a pair could be verified by reading (e.g. the 886/944 resolver twins in POPSLOADER-032); unverified pairs are not reported.

## Still unread (shorter than pass 1's list)

Pass 1 left five open debts; this round closed four (tooling files, full Lua read, IOP line-audit for the standalone drivers + ps2atad + pademu core, and the un-runnable test — now run, green). What remains:

1. `modules/pademu/ds34bt.c` and `modules/pademu/ds34usb.c` line-by-line. Covered by diff + greps instead; the residual risk is pademu-only code paths that have no standalone counterpart.
2. BDMAssault sources — they exist only inside `iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz` (151 entries, including a vendored FatFs). Not line-audited: the code is tracked only as an archive that pass 1 (POPSLOADER-006) already found unreferenced, so auditing its contents ranks below the tracked tree. If the tar is kept, its contents become worth a pass.
3. `system.lua` i18n table bodies (2801–4840) proof-read — structure and size already covered by POPSLOADER-003; a translation-quality pass is a different job than this audit.
4. `.research/audit_site.py` (180 lines) and the one-shot scripts in `.research/tools/` — listed and sized, not read this round.
5. EE-side client libraries `modules/ds34bt/ee/` and `modules/ds34usb/ee/` — not read; they are thin RPC wrappers over the IOP sides audited here.
6. Binary assets and IRX contents — not text-auditable; pass 1 covered their sizes and hashes.
7. No PS2 build was run (no PS2SDK in this VM) and no hardware was touched — all runtime claims above rest on the host harness (62/62) and the disc-layout test (30/30), not on console behaviour.
