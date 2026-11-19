# FULL-VERIFICATION — POPSLoader worker B (POPSLOADER-014…030)

- **Clone:** `~/workspace/audit-clones-2026-11-13/POPSLoader` — `git rev-parse HEAD` = `29272cddbf0122f14e76bc3bdd75e3b46aa870be` ✅ matches the pin. Read-only; nothing edited.
- **Stance:** adversarial — each finding had to survive re-derivation at the pin.
- **Batch:** POPSLOADER-014…025 from `Sable-POPSLoader.md`, POPSLOADER-026…030 from `Sable-POPSLoader-ROUND2.md`; POPSLOADER-016 verified in its narrowed form (MASTER-INDEX §4: R3 REV-016 + R4 REV-016b addendum).

## 1. Verdict table

| ID | Verdict | Evidence (one line) |
|---|---|---|
| POPSLOADER-014 | VERIFIED-DRIFT | All named branches and all 37 tags present at the pin; branch/claude counts drifted (see §2) |
| POPSLOADER-015 | VERIFIED-DRIFT | 4,896 total lines, md5 duplicate pair and docs/ audit files exact; root count is 17 MD files, not 18 (see §2) |
| POPSLOADER-016 | VERIFIED (narrowed) | Narrowed claim exact: 5 unwired scripts = 547 lines (79+111+104+185+68); 12 files CI-wired incl. `test_cursor_orbs.cjs` (see §2) |
| POPSLOADER-017 | VERIFIED | `src/luasystem.cpp:35` `#define MAX_DIR_FILES 512`; stack array `mcEntries[MAX_DIR_FILES]` at `:721`, used in `mcGetDir(..., MAX_DIR_FILES, mcEntries)` at `:735`; 4,096 B thread stack at `src/luagraphics.cpp:26` |
| POPSLOADER-018 | VERIFIED | `SmbWaitNetState` 30×`sleep(1)` loop at `src/luasystem.cpp:2095–2104`, called only from the Lua binding `lua_smb_netup` (`:2306`, calls at `:2332/:2334/:2347`); sibling `sleep(1)` at `:185`, `:1746`, `:1754`, `src/luaHDD.cpp:93`; bounded 10 ms poll contrast at `:1940–1955` |
| POPSLOADER-019 | VERIFIED | Two `static char launch_arg_storage[2048]` in `src/elf_loader/src/elf.c` — `:404` in `ExecuteViaEmbeddedLoader` (def `:397`) and `:487` in `LoadELFFromFileWithPartition` (def `:481`), both driving the shared `store_arg` at `:83`; file is 731 lines |
| POPSLOADER-020 | VERIFIED | `src/luagraphics.cpp:276` `malloc(16)`, `:278` `sprintf(buffer, "%i", (int)image)`, result published via `imgThreadData` at `:279`; `snprintf` precedent exists in `src/luasystem.cpp` (e.g. `:621`) |
| POPSLOADER-021 | VERIFIED | Unchecked `getcwd(path, 256)` at `src/luasystem.cpp:600` (pushed to Lua at `:601`) and `:681` in `lua_dir`; checked sites in the same file at `:629–630` and `:646–647` raise Lua errors |
| POPSLOADER-022 | VERIFIED | `docs/translations/slovak.tsv` = 410 lines; `slovak.xlsx` present (21,606 B); `tools/translation_handoff.py` (250 lines) reads TSV template at `:176` and XLSX as second source at `:202–212` (`read_xlsx` at `:207`) |
| POPSLOADER-023 | VERIFIED | `pcall` line counts exact: 256 lines in `bin/POPSLDR/system.lua` + 114 in `bin/POPSLDR/ui.lua` = 370 sites; representative `type(...)==...` + `pcall` pattern confirmed at `system.lua:2016–2028` and `:6332–6333` |
| POPSLOADER-024 | WEAKENED | Root files and both cited duplicate pairs exact, but only **6** exact-duplicate image pairs exist in `.research/assets/`, not "at least 9" (see §2) |
| POPSLOADER-025 | VERIFIED | Identical OPL-UI TODO at `src/fntsys.cpp:544`, `:553`, `:560`; block TODO at `:568–575`; file is 946 lines; Makefile header brands the build "Enceladus project" (`Makefile:25`, inside the cited `:22–27` block) |
| POPSLOADER-026 | VERIFIED-DRIFT | Diverged fallback is real but spans `bin/POPSLDR/ui.lua:4544–4605`, not 4550–4613 (see §2) |
| POPSLOADER-027 | VERIFIED | UDPFS arm at `bin/POPSLDR/system.lua:8040–8048`: `GetFileSizeSafe(path) ~= #expected or ReadWholeFile(path) ~= expected` per `BDMA_COPY_FILES` entry; `IsBdmaModeEquipped` def `:8022`, called from `MaybeApplyAdaptiveBdma` at `:8068` and directly at `:11072` |
| POPSLOADER-028 | VERIFIED | `PLDR.ProbeHddSettingsWrite` def `bin/POPSLDR/system.lua:980`; mount-RW + `pldrs_wtest.tmp` write/delete loop over `__.POPS*` partitions in its body; "(TEST)" call site at `bin/POPSLDR/ui.lua:4622–4637` on the save-success path, with success/failure toasts |
| POPSLOADER-029 | VERIFIED | All four functions at the cited lines — `PLDR.SaveGameListCache` `system.lua:9880`, `PLDR.LoadGameListCache` `:9899`, `PLDR.HDD.CreateCache` `:9944`, `PLDR.HDD.ReadCache` `:9991` — with near-identical PLDRGC1 `S `/`G `/`H ` serialise/parse loops read side by side |
| POPSLOADER-030 | VERIFIED | Rollback table at `system.lua:6675–6683` passes `profile = next_state.profile` (`:6676`) and `popstarter_mode = next_state.popstarter_mode` (`:6678`); `popstarter_mode` occurs exactly once in the file (grep count 1); neither field is produced by `SnapshotSettingsState` (`:5959`) or consumed anywhere in `ApplySettingsState` (`:5994+`, no `state.profile`/`state.popstarter_mode` reference) |

## 2. Full reasoning for non-VERIFIED verdicts

### POPSLOADER-014 — VERIFIED-DRIFT (ref counts moved; every named ref exists)

The finding is a list-only clutter item, and the list itself checks out: every named branch is present (`origin/BETA-3-restarts`, `origin/BETA-8-5`, `origin/BETA-9`, `origin/BETA-12-PLAY`, `origin/CHECKPOINT2`, `origin/dev`, `origin/experimental`) and the tag list is **exactly 37**, including all six cited checkpoint/backup tags (`backup/pre-hdd-cache-2026-06-19`, `checkpoint/2026-06-16-audit-fixes`, `checkpoint/BETA-12-PLAY-before-phase3-2026-06-18`, `checkpoint/master-before-beta12-2026-06-18`, `checkpoint/master-before-dkwdrv-merge-20260523-132143`, `checkpoint/master-before-real-dkwdrv-merge-20260523-132313`) and the four floating tags (`latest`, `release`, `rolling-release`, `experimental`).

Corrected counts at verification time:

- Remote branches: `git branch -r` returns 39 lines including the `origin/HEAD -> origin/master` symref — **38 branch refs** (37 excluding `master` itself, which is presumably how pass 1 got "37").
- Claude branches: **20** `origin/claude/*` refs (13 `project-thread-*` incl. the two `y8k8m2-*` variants, 7 `popsloader-*`), not "14". The clone also carries branch families the finding does not list (`chore/`, `codex/`, `fix/`, `maintenance/`, `research/`, `style/` — the two `style/*-20261114` branches are dated the day after pass 1 was written, so part of the drift is refs created after the audit, which a commit pin cannot freeze).

Substance (checkpoint/backup refs used as an in-repo archive, floating tags duplicating Releases) is unchanged. No size claim was made and none is implied.

### POPSLOADER-015 — VERIFIED-DRIFT (root file count 17, not 18; all other measurements exact)

Verified exactly:

- Total root Markdown lines: `wc -l *.md` = **4,896 total** — matches the finding.
- Duplicate pair: `md5sum OFFICIAL_NOTES.md RELEASE_1.4.4.md` = `b6fddc7922bd0c6c1dce14973bc066e3` for both — matches the finding character for character (each 1,841 B).
- Fossil docs: `docs/REPO_AUDIT_2026-07-07.md` = 128,247 B / 385 lines; `docs/AUDIT_CODEX_2026-06-20.md` (22,799 B) and `docs/HANDOFF_EXP33_2026-07-21.md` (16,130 B) both present in `docs/`.

The one wrong number is the headline count: the root holds **17** `.md` files, not 18 — `AGENTS, ARCHITECTURE, COMPONENTS, CONTRIBUTING, DECISIONS, EXPERIMENTAL_NOTES, OFFICIAL_NOTES, QA_REGRESSION_MATRIX, README, ROLLING_NOTES, ROADMAP, STATE, TESTING` (13) + `RELEASE_1.3.0/1.3.1/1.4.0/1.4.4` (4) = 17. The finding's own location list also enumerates exactly these 17, so the "18" is an arithmetic slip in the title, not a missing file. Fix and benefit are unaffected.

### POPSLOADER-016 — VERIFIED (narrowed) — the R3 REV-016 + R4 REV-016b version holds exactly; the original pass-1 version overstates

Original claim (all 16 scripts one-shot, ~2,100 lines, "one workflow still runs a subset") does **not** survive. The narrowed claim in the §4 ledger does, on every number:

- **The 5 unwired scripts are exactly the dead residue, exactly 547 lines:** `audit_network_driver_crc_overlap.py` 79 + `audit_original_automated_parity.py` 111 + `audit_original_download_links.py` 104 + `audit_original_git_history.py` 185 + `audit_original_wip06_2017.py` 68 = **547** (`wc -l`). A whole-tree grep for each name finds references **only** in the frozen `.research/research/*.md` reports they were written to produce (e.g. `original-git-gap-audit.md`, `original-git-exact-automated-parity.md`) and in each script's own docstring — no workflow, no import, no other executable reference.
- **The CI-wired set is 12 files, as the R4 addendum corrects (not 11):**
  - `research-network-driver-integrity.yml` executes 6: `verify_network_driver_payloads.py` (`:41`), `compare_recovered_archive_candidates.py` (`:47`, `:106`, `:110`), `audit_hosted_patch_members.py` (`:64`), `audit_bitbucket_download_snapshots.py` (`:74`), `audit_legacy_archive_payloads.py` (`:99`), `audit_legacy_tool_overlap.py` (`:103`).
  - `docs-site.yml` executes 4 Python scripts: `guard_site_deploy.py` (`:71`, `:146`, `:149`, `:154`), `audit_legacy_pages.py` (`:72–73`, `:147–148`, `:155`), `audit_published_provenance.py` (`:101`), `audit_original_wiki_zip.py` (`:104`).
  - Shared module: `inspect_network_modules_header.py`, imported at `.research/tools/verify_network_driver_payloads.py:19` (`from inspect_network_modules_header import manifest`; also imported by the unwired CRC script at its `:17`) and py-compiled/path-triggered by the integrity workflow (`:14`, `:40`). (REV-016's text cites the importer as `tools/verify_network_driver_payloads.py:19`; the file actually lives under `.research/tools/` — a path shorthand in the revision note, line and import exact.)
  - Plus the R4 catch: `test_cursor_orbs.cjs` (100 lines) executed at `docs-site.yml:70` (`node .research/tools/test_cursor_orbs.cjs`).
  - Total Python in `.research/tools/`: 16 files / 2,055 lines, of which 11 files are wired (2,055 − 547 = 1,508 lines) — matching REV-016's arithmetic.
- Revised fix scope (move/delete applies to the 5 unwired scripts / 547 lines only; the wired 12 leave only with the POPSLOADER-001 archive move) is therefore the correct disposition. Verdict recorded as **VERIFIED (narrowed)** per the batch instruction, not WEAKENED: no further narrowing is needed.

### POPSLOADER-024 — WEAKENED (duplicate-image count overstated: 6 pairs, not ≥9)

What survives, verified:

- Root assets: `banner.jpg` = **345,431 B** exactly as cited; `imageformat.png` present at root (93,021 B). A whole-tree grep for `banner.jpg` / `imageformat.png` (excluding the files themselves) returns **no references**, consistent with the finding's own "usage not traced" hedge.
- Both cited example pairs are byte-identical: `2667142094-356screenshot1.gif` = `356screenshot1.gif` (md5 `1dd27d7329acc88b1ce4fe3c560a2f0b`, 18,611 B) and `2984521000-Playstation-Button-Select.png` = `3405191067-Playstation-Button-Select.png` (md5 `f9402fd56124e6d8848375ca534e79f4`, 475 B).

What does not survive: "at least 9 exact-duplicate pairs found by md5". A full md5 census of all 124 files in `.research/assets/` (all extensions, case-insensitive) yields exactly **6 duplicate groups, each of exactly 2 files = 6 pairs**:

1. `1dd27d7…` — the `356screenshot1.gif` pair above
2. `f9402fd…` — the `Playstation-Button-Select.png` pair above
3. `415a1a9…` — `1165364186-Playstation-Button-L2.png` = `3667653909-Playstation-Button-L2.png` (867 B)
4. `826098c…` — `1258137434-pops05_zps81df52b9.jpg` = `pops05_zps81df52b9.jpg` (35,200 B)
5. `a7fd769…` — `1712503932-Playstation-Button-R2.png` = `2283666138-Playstation-Button-R2.png` (976 B)
6. `68de46d…` — `2651471562-Playstation-Button-T.png` = `3050099753-Playstation-Button-T.png` (1,423 B)

A repo-wide image-only census finds the same 6 groups and no others, so the extra pairs needed to reach 9 do not exist among images. (Repo-wide across *all* file types there are many more duplicate groups — IRX/ELF copies covered by other findings — but those are not this finding's asset claim.) **Narrower surviving claim:** 6 exact-duplicate image pairs in `.research/assets/` (6 redundant copies, 57,552 B total — the "< 1 MB" benefit estimate still holds), plus the two root-level loose assets as cited. The fix (delete one name per md5; move-or-delete the root files after a grep — the grep now returns nothing) is unchanged.

### POPSLOADER-026 — VERIFIED-DRIFT (fallback span is ui.lua:4544–4605, not 4550–4613)

The mechanism is exactly as filed. In `queue_exit` (`bin/POPSLDR/ui.lua:4459`), the xpcall body first tries the real path:

- `ui.lua:4509–4543` — `if type(PLDR.CommitSettingsChanges) == "function" then return PLDR.CommitSettingsChanges({ ... })` with the full option table (`smb`, `smb_modules`, `apply_smb`, `ember_global`, `hide_text`/`prev_hide_text`, `retrogem_gameid`, …). The callee is unconditionally defined at `bin/POPSLDR/system.lua:6567` (`function PLDR.CommitSettingsChanges(opts)`).

Corrected fallback span: the hand-rolled copy runs from **`ui.lua:4544`** (`PLDR.POPSTARTER_PATH = pop_path`, immediately after the Commit block's `end`) to **`ui.lua:4605`** (`return true, nil`; the xpcall closes at `:4606`). That is ~62 lines — the "~64 lines" size claim stands, but the cited bounds 4550–4613 are off at both ends (4550 lands mid-fallback inside the keyboard-layout normaliser branch; 4613 lands in the post-success dirty-flag clearing at `:4608+`).

Divergence confirmed by reading both paths: the fallback does direct `PLDR.*` assignments + normalisers, then `PLDR.SaveSettingsAtomic()` (`:4593`) and `PLDR.ApplyBdmaMode(mode_key)` (`:4597`) only — no SMB apply stage, no Ember/RetroGem/hide-text handling, and its failure returns are `save_failed` / `bdma_apply_failed` with no rollback, unlike the real path. Fix (delete the fallback, call `CommitSettingsChanges` directly) unchanged.

## 3. New findings

**None.** No genuinely new, previously unfiled defect was found while re-deriving this batch (checked against the headings of `Sable-POPSLoader.md` and `Sable-POPSLoader-ROUND2/3/4/7.md`). The reserved range POPSLOADER-113…116 is unused. (One cosmetic observation, deliberately not filed: the comment at `system.lua:8072` claims an already-correct card "pays nothing" for `IsBdmaModeEquipped`, which is the opposite of the per-launch whole-file compare POPSLOADER-027 files — a stale comment, not a defect.)
