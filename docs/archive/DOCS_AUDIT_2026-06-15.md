# Documentation Accuracy Audit — 2026-06-15

Audited tree: `claude/docs-overhaul` (BETA-12-PLAY shipped state, worktree HEAD `cc74a3e` / `BETA-10-5-34`).

Scope: every Markdown doc under the repo root and `docs/`. Each technical claim below was checked against the actual source in this worktree, cited `path:line`. This synthesizes five upstream audit passes (root docs, launch/HDD-handoff docs, agent/process governance docs, BETA-12-PLAY handoff docs, and the docs-overhaul accuracy pass) into one report.

> ⚠️ **Correction (2026-06-15 re-verification).** Findings **1-6** (`README.md` /
> `ARCHITECTURE.md` / `COMPONENTS.md`) are **RETRACTED**: re-checking against the
> current files showed they describe already-resolved issues and their
> `path:line` citations point at unrelated content (the cited lines moved in
> `b285223` and this overhaul's refresh of those three files — e.g. the persisted-
> settings list is complete at `COMPONENTS.md:153-155`, and the Square cover-art
> toggle is documented in the current README). The three summary rows below are
> updated accordingly; the detailed 1-6 entries are kept for the audit trail but
> **must not be acted on.** The prioritized-list items that reference them (P1 #3,
> the P2 mmceman batch, P3 #8/#9/#10) are likewise superseded. **All other
> findings (7-29) and P0 were re-verified against source and stand.**

## How to read this

- **overall accuracy** — `accurate` (no content errors), `mostly-accurate` (a few stale/wrong lines in an otherwise-correct doc), `stale`/`obsolete` (the doc's main body no longer matches code).
- **recommendation** — `keep` (no changes), `update` (fix the listed lines), `archive` (mark historical; do not use as current guidance).
- Only doc-content errors are listed in the "stale/wrong/obsolete" section. Findings confirmed `correct` are summarized per-doc but not re-listed line-by-line.

---

## Per-doc summary

| Doc | Overall accuracy | Recommendation | Top issues |
|---|---|---|---|
| `README.md` | accurate (refreshed in overhaul) | done | Findings 1-2 RETRACTED — current README documents the shipped mmceman gate and the Square cover-art toggle |
| `ARCHITECTURE.md` | accurate (refreshed in overhaul) | done | Findings 3-4 RETRACTED — current ARCHITECTURE names the real elf.c entry points; the `ba8f0d0` CI wording is not in this file |
| `COMPONENTS.md` | accurate (refreshed in overhaul) | done | Findings 5-6 RETRACTED — current COMPONENTS lists all 9 settings keys (COMPONENTS:153-155); no CI conflation in this file |
| `HDD_POPSTARTER_HANDOFF.md` | mostly-accurate | archive | Self-labeled archived; several findings already resolved in source (findings 4/5, lines 94-103) + outdated "simplification target" planning text (lines 129-145) |
| `docs/LAUNCH_HYGIENE.md` | mostly-accurate | update | DKWDRV-on-HDD chain is WRONG for the actual call site (lines 100-112); mmceman "always at boot" table row + still-queued bullet are stale (lines 236, 248-250) |
| `docs/U10_INVESTIGATION.md` | accurate | keep | Only optional nit: per-color stage descriptions differ slightly from `loader.c:34-43` comments |
| `AGENTS.md` | mostly-accurate | update | Cycle-anchor date 2026-05-28 + "#471 DRAFT" framing predate merged #471/#475/#476/#477 (AGENTS.md:2,56) |
| `AGENTS_START_HERE.md` | mostly-accurate | update | PR #471 listed as open DRAFT but merged (lines 53-55); GUI-asset blocker phrasing likely stale (line 94) |
| `RULES.md` | mostly-accurate | update | Only the dated cycle-anchor is stale (RULES.md:1); all policy content correct |
| `CONTRIBUTING.md` | accurate | keep | Only the dated cycle-anchor trails HEAD (CONTRIBUTING.md:1); no content errors |
| `PROMPTS.md` | mostly-accurate | update | Post-release PR set lists "#471 DRAFT" and omits #475/#476/#477 (PROMPTS.md:113) |
| `ANTIGRAVITY_NEXT_TASK.md` | obsolete | archive | Already an archive stub; one stale PASS row (HOSDMenu, line 14) lacks the later Class-A caveat |
| `TRUTHSHEET.md` | accurate | keep | No errors; correctly carries U-10/HOSDmenu/wLE as FAIL |
| `DECISIONS.md` | accurate | keep | Only header date trails newest entry by one day (DECISIONS.md:1 vs :15) |
| `STATE.md` | mostly-accurate | update | **Internal contradiction**: "Unexpectedly resolved" U-10 PASS block (lines 121-122) contradicts U-10 FAIL at lines 84/113; stale tip pointer `81c886e` (line 99) |
| `ROADMAP.md` | mostly-accurate | keep | One stale line: PR #471 listed DRAFT but merged (lines 25,43) |
| `QA_REGRESSION_MATRIX.md` | accurate | keep | Only the header tip pointer `81c886e` is stale (header); ledger rows are current |
| `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md` | mostly-accurate | keep | One stale file-by-file row for GUI_OVERHAUL_PROMPT.md (line 54) describes fixes already applied |
| `docs/GUI_OVERHAUL_PROMPT.md` | mostly-accurate | keep | Branch name inconsistent within doc (line 64 vs 186) |
| `docs/HIGH_LEVEL_CODE_AUDIT.md` | stale | archive | Self-labeled historical, but body still asserts a fixed bug as live (§3.6/§4.3/§6/§7) + lists removed files + mislabels C-symbol names (§3.4) |

---

## Stale / wrong / obsolete claims (with fixes)

Grouped by doc. Each entry: the claim, why it is wrong, the source citation, and the fix. `status` mirrors the upstream audit verdict and was re-checked against source where load-bearing.

> **Findings 1-6 RETRACTED — do not act on them.** Re-verification (2026-06-15)
> found these README/ARCHITECTURE/COMPONENTS entries describe a pre-`b285223` /
> pre-overhaul state with citations that no longer match the current files; those
> three files were re-verified accurate. They are retained below only for the
> audit trail. Findings 7-29 stand.

### `README.md` — update (RETRACTED — see note above)

1. **STALE — Layer C lazy IRX listed as "Planned / PR #471 (DRAFT)" (README:173).**
   The mmceman conditional load is shipped in this tree: `src/main.cpp:460` gates the eager mmceman load on `boot_device_hint == "MMCE"` and defers otherwise (`src/main.cpp:486-495`), with the lazy path `EnsureMmceman` in `src/luasystem.cpp:141`. `cc74a3e` is the "Merge pull request #471" commit already in HEAD.
   **Fix:** Move the mmceman portion of "Layer C Lazy IRX Loading" out of "Planned" into shipped behavior, or drop the (DRAFT)/pending-verification wording. Keep `ds34bt`/`usbd` deferral as future work only if still unimplemented.

2. **STALE — Square documented only as keyboard "Delete character" (README:110).**
   In the game list, Square also toggles cover-art preview: `bin/POPSLDR/ui.lua:2153-2154` `if UI.Pad.Events.SQUARE then UI.CoverPreviewEnabled = not UI.CoverPreviewEnabled`. The controls table omits this — it is the primary Square action in the game-list scene.
   **Fix:** Add a row/note that Square toggles cover-art preview in the game list (the keyboard-delete role stays correct inside the on-screen keyboard).

### `ARCHITECTURE.md` — update

3. **WRONG — elf.c "owns LoadExecPS2 / ExecPS2 / ExecPS2-with-IOP-reboot" (ARCHITECTURE:57-60).**
   `LoadExecPS2` and `ExecPS2` are ps2sdk syscalls/wrappers that elf.c *calls* (`src/elf_loader/src/elf.c:560`, `:594`), not backends it owns. The real public entry points are `LoadELFFromFile` (`elf.c:565`), `LoadELFFromFileExecPS2` (`elf.c:570`), `LoadELFFromFileExecPS2RebootIOP` (`elf.c:599`), `LoadELFFromFileWithPartition` (`elf.c:467`), `LoadELFFromFileExecPS2RebootIOPWithPartition` (`elf.c:604`), plus the embedded-loader path `ExecuteViaEmbeddedLoader` (`elf.c:383`) / `ExecuteHddBackedViaEmbeddedLoader` (`elf.c:325`).
   **Fix:** Replace the three bullet names with the real elf.c entry points above.

4. **STALE — CI "pinned post-release at commit ba8f0d0" (ARCHITECTURE:64).**
   The workflow pins a Docker image *tag* (`ps2dev/ps2dev:v2.0.0`, `.github/workflows/compilation.yml:24`), not a git commit. `ba8f0d0` is the repo commit that *introduced* the pin; phrasing it as "pinned at commit ba8f0d0" conflates the container tag with a git SHA.
   **Fix:** Reword to "container image pinned to `ps2dev/ps2dev:v2.0.0` (pin introduced in commit `ba8f0d0`)". Same wording recurs in `COMPONENTS.md:42`.

### `COMPONENTS.md` — update

5. **STALE — persisted-settings list (COMPONENTS:54-62) omits 2 of 9 keys.**
   `EncodeSettings` (`bin/POPSLDR/system.lua:2593-2603`) writes 9 keys: `PROFILE`, `POPSTARTER_PATH`, `POPSTARTER_MODE`, `BDMA`, `DKWDRV_PATH`, `STRICT_HDD_PREEXEC_GATE`, `VIDEO_STANDARD`, `HIDE_TEXT`, `KEYBOARD_LAYOUT`. The doc list omits `POPSTARTER_MODE` (PROFILE_DEFAULT vs CUSTOM) and `STRICT_HDD_PREEXEC_GATE`.
   **Fix:** Add POPSTARTER selection mode and `STRICT_HDD_PREEXEC_GATE`, or note the list is illustrative not exhaustive.

6. **STALE — same CI tag-vs-SHA conflation (COMPONENTS:42).** See finding 4.
   **Fix:** "container image pinned to `ps2dev/ps2dev:v2.0.0` (pin added in commit `ba8f0d0`)".

### `HDD_POPSTARTER_HANDOFF.md` — archive

The doc self-labels archived/historical and flags findings 1-5 as having source changes in current BETA-12-PLAY. These are *acknowledged drift*, not false claims about current code. They are why the doc should be archived rather than kept as guidance.

7. **STALE — Finding 4 (lines 94-97): "System.loadELF leaks partition context into target argv."**
   Not true of current source. `lua_loadELF` (`src/luasystem.cpp:1008-1047`) copies at most ONE selector into `argv_static[0]` with `argv_static[1]=NULL` (`luasystem.cpp:1021-1024`); it never copies an arg range and has no partition-context detection, so it cannot leak a partition arg. The doc's own recommended fix (a distinct partition-aware binding) shipped as `lua_loadELFWithPartition` (`luasystem.cpp:1054-1100`), which passes partition out-of-band and only copies `args[4..argc]` (`luasystem.cpp:1075`).
   **Fix:** None beyond archiving; resolved in source, correctly marked historical.

8. **STALE — Finding 5 (lines 99-103): "ExecuteViaEmbeddedLoader still returns -7 when no target argv0 is supplied."**
   Resolved. `ExecuteViaEmbeddedLoader` returns -7 ONLY when `extra_argc > 0` AND argv0 invalid (`elf.c:429`); `argc == 0` is explicitly allowed through (`elf.c:422-431`, child synthesizes argv0). POPSTARTER-specific argv0 enforcement now lives in `ExecuteHddBackedViaEmbeddedLoader` (`elf.c:335-337`). This is exactly the doc's recommended fix.
   **Fix:** None; the recommended fix shipped.

9. **STALE — "Recommended Fix Order / Current simplification target" (lines 129-145).**
   Contradicts shipped behavior. The doc says the HDD-backed POPSTARTER path was "simplified again" to call `System.loadELF(path,0,selector)` and skip the gate/remount/embedded-loader-reboot, with the partition-aware route retained-but-not-default. In current source `popstarter_on_hdd` uses `reboot_iop=1` and the partition-aware API, routing HDD POPSTARTER through `ExecuteHddBackedViaEmbeddedLoader` (`elf.c:631-643`) and the BRAM child loader. The partition-aware route is the DEFAULT now. The "simplification" was an in-flight 2026-05-20 experiment that did not become the final BETA-12-PLAY state.
   **Fix:** Outdated planning text. Archive the doc so a reader does not conclude the partition-aware route is dormant.

(Findings 0/1/2/3 and findings 6/7 in this doc were re-verified as `correct`/historical: the `NormalizeHddPartitionLabelForMount` + `ResolveFallbackMountedPfsExecPath` recovery shipped at `system.lua:384-411` / `system.lua:1626-1639`; loader.c does use `snprintf`/`strncat` in `build_default_target_arg0` and `read_embedded_loader_metadata`; loader.c is the bin2c blob with a CI parity gate.)

### `docs/LAUNCH_HYGIENE.md` — update

10. **WRONG — DKWDRV-on-HDD result chain (lines 100-112).**
    The doc traces HDD-DKWDRV as `OpenDKWDRV -> System.loadELF(elf_path,0,elf_path) -> LoadELFFromFile -> LoadELFFromFileWithPartition -> DKWDRV special case -> ExecuteViaEmbeddedLoader`. But `OpenDKWDRV` calls `System.loadELF(elf_path, dkwdrv_reboot_iop, elf_path)` with THREE args (`bin/POPSLDR/ui.lua:1261`; for HDD paths `dkwdrv_reboot_iop = 0` at `ui.lua:1260`), i.e. `extra_args > 0`. In `lua_loadELF` with `rebootIOP == 0` AND `extra_args > 0`, control goes to `LoadELFFromFileExecPS2` (`src/luasystem.cpp:1030`), NOT the no-arg `LoadELFFromFile` branch (`luasystem.cpp:1042`). `LoadELFFromFileExecPS2` (`elf.c:570-596`) is a plain `SifLoadElf`+`ExecPS2` with NO DKWDRV special-case and never calls `ExecuteViaEmbeddedLoader`. The DKWDRV special-case the doc points to lives in `LoadELFFromFileWithPartition` (`elf.c:502-506`), which a selector-bearing call cannot reach.
    **Fix:** Correct the chain to reflect that `OpenDKWDRV`'s 3-arg call lands in `LoadELFFromFileExecPS2` (no embedded-loader route), or note that for the DKWDRV special-case to fire `OpenDKWDRV` would need a no-selector call. This is the arg-count-vs-routing gotcha the codebase map flags. Confirm on hardware which path HDD-DKWDRV actually exercises before rewriting. (Note: HDD-DKWDRV is already documented as known-broken-accepted, consistent with this dead route.)

11. **STALE — Layer C IRX table row "mmceman | Always at boot (if fileXio OK)" (line 236) + "Defer mmceman_irx unless boot device is MMCE" still-queued bullet (lines 248-250).**
    mmceman loads eagerly ONLY when `boot_device_hint == "MMCE"` (`src/main.cpp:460`, eager at `:464`, deferred at `:486-495`). It is NOT always loaded, and the deferral already shipped.
    **Fix:** Change the table row to "Lazy/conditional: eager only if `boot_device_hint==MMCE`, else `EnsureMmceman` on demand (`src/main.cpp:460-495`, `luasystem.cpp:141`)". Remove the "Defer mmceman_irx unless boot device is MMCE" bullet from the Still-queued list (line 249).

(Layer A teardown, the lazy IRX table for bdm/mx4sio/cdfs/HDD rows, the settings-sidecar RW-mount-vs-read-only reconciliation, and the U-10/known-broken status banner in this doc were all re-verified `correct`.)

### `AGENTS.md` — update

12. **STALE — dated 2026-05-28 / "#471 DRAFT" post-release framing (AGENTS.md:2,56).**
    PR #471 is merged (`cc74a3e`); PRs #475/#476/#477 merged after this date. The MX4SIO settings-save bug fixed by #476/#477 is not reflected. (AGENTS.md's *body* treating the conditional mmceman as shipped is now correct — `src/main.cpp:460`.)
    **Fix:** Refresh the date/cycle anchor and drop the "#471 DRAFT" framing; note the post-#477 MX4SIO settings-save fix.

### `AGENTS_START_HERE.md` — update

13. **STALE — PR #471 listed under "Open:" / "Awaiting hardware verification" (lines 53-55).**
    Merged (`cc74a3e`); conditional code in shipped source `src/main.cpp:460-495`. No longer an open draft.
    **Fix:** Move PR #471 to merged/shipped.

14. **STALE (low confidence) — "GUI overhaul blocked on mockup PNGs at C:\\Users\\natha\\Documents\\assets\\" (line 94).**
    Cannot confirm asset arrival from source. `docs/GUI_OVERHAUL_PROMPT.md` exists and the GUI work is queued; the specific path-blocker phrasing likely predates later work.
    **Fix:** Re-verify the GUI blocker state and update or remove the absolute-path blocker line.

### `RULES.md` — update

15. **STALE — dated 2026-05-28 cycle anchor (RULES.md:1).**
    Predates merged #475/#476/#477. Policy content is still valid; only the date/cycle anchor trails HEAD.
    **Fix:** Bump the date anchor; no content change required.

### `PROMPTS.md` — update

16. **STALE — post-release PR set "#470, #472, #473, #471 DRAFT" (PROMPTS.md:113).**
    #471 is merged (`cc74a3e`), not DRAFT; the set omits #475/#476/#477 merged after this template. The required-check guidance is structurally fine.
    **Fix:** Update the enumerated PR set (drop DRAFT on #471; add #475/#476/#477).

### `ANTIGRAVITY_NEXT_TASK.md` — archive

Already an archive stub (self-marked ARCHIVED at line 1). All forward-pointer files exist. Correct disposition is archive.

17. **STALE — "BOOT.ELF from ... HOSDMenu ...: PASS" (line 14).**
    `README.md:30` and STATE.md now document HOSDmenu -> POPSLoader as a Class-A black-screen (POPSLoader never reaches splash) — distinct from BOOT.ELF *exit*, but this archived note lists HOSDMenu under PASS without the later Class-A caveat. Archived status mitigates the risk.
    **Fix:** None required (archived); optionally annotate the HOSDMenu PASS row with the Class-A caveat.

### `STATE.md` — update

18. **STALE / INTERNAL CONTRADICTION — "Unexpectedly resolved 2026-05-28 PM: U-10 ... downgraded to PASS" (lines 121-122).**
    This is the one real internal contradiction in the doc set. STATE.md:121-122 asserts U-10 PASS, directly contradicting STATE.md:84 and STATE.md:113 (same file) which mark U-10 FAIL / known-broken. The PASS claim was reversed by the 2026-05-28 PM-late full sweep (`DECISIONS.md:27-31`, `QA_REGRESSION_MATRIX.md:191`). Source agrees U-10 is unfixed: the HDD-booted BOOT.ELF reboot path (`elf.c:604-701`) still does `SifIopReset` (`elf.c:675`) with no BOOT.ELF special-case, and the in-code comment (`elf.c:654-670`) describes the hang as a mitigation target, not a pass.
    **Fix:** Delete the "Unexpectedly resolved" block or rewrite it as "PASS claim walked back (see DECISIONS.md:27-31, QA matrix:191)".

19. **STALE — development tip pointer `81c886e` (STATE.md:99).**
    Worktree HEAD is `cc74a3e` (`BETA-10-5-34`), past `81c886e`; it includes #475/#476/#477 and the #471 merge. STATE.md's own body describes #476/#477/#471 work that lands after `81c886e`.
    **Fix:** Update the tip pointer to `cc74a3e` (or drop the hard SHA in favor of "current BETA-12-PLAY tip").

### `ROADMAP.md` — keep (one fix)

20. **STALE — PR #471 listed as DRAFT / open (ROADMAP.md:25,43).**
    `cc74a3e` is "Merge pull request #471"; the mmceman gate is present (`src/main.cpp:460-495`).
    **Fix:** Mark PR #471 merged. (ROADMAP is otherwise internally consistent — it does NOT carry the contradictory U-10 "resolved" block that STATE.md does.)

### `QA_REGRESSION_MATRIX.md` — keep (one fix)

21. **STALE — header tip pointer `81c886e`.**
    Same as finding 19; the worktree is at `cc74a3e`. The run-log rows below (lines 187-191) DO cover post-`81c886e` work, so only the header line is stale.
    **Fix:** Update the header tip to `cc74a3e`.

### `DECISIONS.md` — keep (cosmetic)

22. **STALE (cosmetic) — header "Last updated: 2026-05-28" trails newest body entry dated 2026-05-29 (DECISIONS.md:1 vs :15).**
    Content is accurate; header date lags newest entry by one day. (Note: DECISIONS cites `system.lua:3135/3146` for the #473 move; actual current lines are `3159/3170` — minor line drift, structural claim correct.)
    **Fix:** Bump header date to 2026-05-29; optionally refresh the #473 line numbers.

### `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md` — keep (one fix)

23. **STALE — file-by-file row for `docs/GUI_OVERHAUL_PROMPT.md` (line 54).**
    The row recommends "update target branch from master to BETA-12-PLAY" and "resolve Settings UI contradiction", but the GUI doc has no `master` reference (only BETA-12-PLAY at GUI doc lines 64, 190) and already resolves the Settings sub-page-vs-single-page contradiction (GUI doc lines 9, 115, 198). Both recommended fixes describe a state already reached.
    **Fix:** Update the row: the GUI doc already targets BETA-12-PLAY and resolves the Settings model; the remaining real nit is the branch-name inconsistency (`claude/gui-overhaul` vs `feat/gui-overhaul`).

### `docs/GUI_OVERHAUL_PROMPT.md` — keep (one fix)

24. **WRONG — inconsistent branch name within the doc (line 64 vs 186).**
    Line 64 suggests `claude/gui-overhaul-berion-mockups`; line 186 step 1 says `feat/gui-overhaul-berion-mockups`.
    **Fix:** Pick one branch name and use it in both Constraints and Workflow. (Minor secondary nit: line 18 "Documents/assets/" vs line 30 absolute "C:\\Users\\natha\\Documents\\assets\\" — same intent, optional to unify.)

### `docs/HIGH_LEVEL_CODE_AUDIT.md` — archive

Self-labels as a pre-BETA-10-5 snapshot at `dc7184c` with a 2026-05-28 historical banner (line 8). The banner is accurate; the problem is the body still asserts fixed/removed state as live.

25. **STALE — `LaunchBootElf` "reboot_iop dead-code bug" asserted live (§3.6 lines 228-236; §4.3 line 287; §6 line 309; §7 lines 320-321).**
    Current source `bin/POPSLDR/ui.lua:1362` is `local rc = System.loadELF(elf_path, reboot_iop)` with the computed value (`reboot_iop=1` when `hdd_loaded` at `ui.lua:1343-1344`). The doc's own §9 (lines 356-358) records this as fixed. The main body contradicts both live code and §9.
    **Fix:** Delete the §3.6/§4.3/§6/§7 reboot_iop-bug paragraphs or annotate them inline as superseded by §9.

26. **STALE — "stale/leftover files to remove" (§3.2 NOTE, §3.6 NOTEs, §5 table, §7 steps 2-3).**
    `src/elf_loader/src/elf.c.orig`, `bin/POPSLDR/ui.lua.backup-*`, and `bin/POPSLDR/uibeforeclauddesign.lua` no longer exist; only the audit doc mentions them.
    **Fix:** Drop the stale-file findings/table or fold into a "resolved" note.

27. **STALE — "BOOT.ELF ... reboot path never tested in isolation; only candidate issuing SifIopReset" (§4.3 lines 286-289).**
    Framed against the now-superseded "reboot_iop always 0" assumption. Current source routes `mc0:`/`mc1:` BOOT.ELF through `ExecuteViaEmbeddedLoader` unconditionally (`elf.c:485-489`); `ui.lua:1346-1361` documents PR #450/#451 reboot attempts tried and reverted as hardware-ineffective.
    **Fix:** Mark §4.3 historical; BOOT.ELF/U-10 status is tracked live in `docs/U10_INVESTIGATION.md` and the QA ledger.

28. **WRONG — C-symbol names in the binding table (§3.4 lines 168-169).**
    `luasystem.cpp` registration is `{"exitToBrowser", lua_exit}` (`luasystem.cpp:1462`) — the C function is `lua_exit`, not `lua_exitToBrowser`; and `{"setExecKeepPfsMask", lua_set_exec_keep_pfs_mask}` (`luasystem.cpp:1467`), not `lua_setExecKeepPfsMask`. The Lua-facing names are right; the internal C symbol names are mislabeled.
    **Fix:** Correct the C-symbol column (`lua_exit`, `lua_set_exec_keep_pfs_mask`) if refreshed; cosmetic in an archived doc.

29. **STALE — `LaunchEngine` line reference `system.lua:4244` (§9 lines 371-378).**
    The defensive unreachable single-arg branch logic is still accurate, but `LaunchEngine` is now at `system.lua:4445` and the `elseif` branch at `system.lua:4553`. The cited line 4244 no longer points at this code.
    **Fix:** Update the line reference (4244 -> 4445/4553); the logic note remains valid.

---

## Fix these first (prioritized)

**P0 — internal contradiction that can mislead a reader about release status**

1. **`STATE.md:121-122`** — delete/rewrite the "Unexpectedly resolved" U-10 PASS block; it contradicts STATE.md:84/113 and the authoritative walk-back (`DECISIONS.md:27-31`, `QA_REGRESSION_MATRIX.md:191`). Source confirms U-10 unfixed (`elf.c:654-675`). (Finding 18.)

**P1 — wrong technical routing/identifier claims a reader could act on**

2. **`docs/LAUNCH_HYGIENE.md:100-112`** — the HDD-DKWDRV chain is wrong for the actual call site (`ui.lua:1261` 3-arg -> `luasystem.cpp:1030` `LoadELFFromFileExecPS2`, no embedded-loader route). Highest-risk because it's an explicit step-by-step launch chain. (Finding 10.)
3. **`ARCHITECTURE.md:57-60`** — elf.c backend names are ps2sdk calls, not elf.c exports; replace with the real entry points. (Finding 3.)
4. **`docs/HIGH_LEVEL_CODE_AUDIT.md` §3.6/§4.3/§6/§7** — body asserts the already-fixed `LaunchBootElf` reboot_iop bug as live, contradicting its own §9 and `ui.lua:1362`. Apply the doc's own banner consistently or archive. (Finding 25.)
5. **`docs/HIGH_LEVEL_CODE_AUDIT.md` §3.4** — wrong C-symbol names (`lua_exit`/`lua_set_exec_keep_pfs_mask`). (Finding 28.)

**P2 — shipped-as-planned drift (features described as future that already shipped)**

6. **mmceman Layer C drift, four docs:** `README.md:173`, `docs/LAUNCH_HYGIENE.md:236` + `:248-250`, `ROADMAP.md:25,43`, `AGENTS_START_HERE.md:53-55`, `PROMPTS.md:113`, `AGENTS.md:2,56`. PR #471 is merged (`cc74a3e`) and the gate is in `src/main.cpp:460-495`. (Findings 1, 11, 13, 16, 12, 20.)

**P3 — stale pointers / dates / small omissions (low reader-harm, easy)**

7. Stale dev-tip `81c886e` -> `cc74a3e`: `STATE.md:99`, `QA_REGRESSION_MATRIX.md` header. (Findings 19, 21.)
8. CI "pinned at commit ba8f0d0" tag-vs-SHA wording: `ARCHITECTURE.md:64`, `COMPONENTS.md:42`. (Findings 4, 6.)
9. Persisted-settings list missing `POPSTARTER_MODE` + `STRICT_HDD_PREEXEC_GATE`: `COMPONENTS.md:54-62`. (Finding 5.)
10. Square cover-art toggle undocumented: `README.md:110`. (Finding 2.)
11. Branch-name inconsistency: `docs/GUI_OVERHAUL_PROMPT.md:64 vs 186`. (Finding 24.)
12. Stale follow-up-audit row for the GUI doc: `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:54`. (Finding 23.)
13. Cycle-anchor dates behind HEAD: `RULES.md:1`, `DECISIONS.md:1`, `CONTRIBUTING.md:1` (process content valid). (Findings 15, 22.)

**Archive (do not use as current guidance; no inline fixes required beyond banners)**

- `HDD_POPSTARTER_HANDOFF.md` — outdated "simplification target" planning text (lines 129-145) plus resolved findings 4/5. (Findings 7, 8, 9.)
- `docs/HIGH_LEVEL_CODE_AUDIT.md` — lists removed files and stale BOOT.ELF framing. (Findings 26, 27, 29.)
- `ANTIGRAVITY_NEXT_TASK.md` — already a stub; one stale HOSDMenu PASS row. (Finding 17.)

**No changes needed:** `TRUTHSHEET.md`, `docs/U10_INVESTIGATION.md`, `CONTRIBUTING.md` (content), `QA_REGRESSION_MATRIX.md` (ledger body).
