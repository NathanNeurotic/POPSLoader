# Repository Cleanup Plan

Last drafted: 2026-06-15
Drafted against: `BETA-12-PLAY` shipped state (docs-overhaul worktree)
Status: **PLAN ONLY — nothing in here has been executed.** No files moved, deleted, gitignored, or branches touched.

This plan proposes a tidier repository layout. It does four things: (1) reorganize the ~15 root-level `.md` files, (2) deal with the untracked/ignored clutter currently sitting in the working tree, (3) reconcile against what `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md` already marked archive/historical, and (4) suggest a branch-hygiene triage approach without prescribing specific deletions.

Evidence discipline matches the rest of the repo: every concrete claim cites `path:line`. This is a documentation/structure plan, so no hardware or build run is implied.

---

## 0. Scope and Guardrails

- This is structure-only. It does not edit doc *content*; content drift is the job of `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md`.
- The doc-audit allowlist in `PROMPTS.md:86-104` already names the root governance docs plus `docs/*.md` as the audited set; any reorganization should keep that allowlist meaningful (update it if files move).
- `AGENTS_START_HERE.md:13-22` is the live entry-point table and links to several of these files by path. Any move that changes a path must update those links in the same change, or future agents land on dead links.
- Do not delete historical failure notes outright. The audit's own rule is to move them into a clearly-marked archive section, not erase them (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:105`).

---

## 1. Root-Level Documentation Sprawl

### Current state

Fifteen `.md` files live at the repo root (all tracked):

| File | Size | Role today |
| --- | --- | --- |
| `README.md` | ~13 KB | Public-facing entry; release wording, highlights, known-broken (`README.md:1-30`). |
| `AGENTS.md` | ~4 KB | Agent policy. Audit: "Mostly policy-current" (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:58`). |
| `AGENTS_START_HERE.md` | ~8 KB | Live agent entry point + where-to-look table (`AGENTS_START_HERE.md:11-22`). |
| `RULES.md` | ~3 KB | Contribution rules. Audit: "Quick consistency pass only" (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:59`). |
| `CONTRIBUTING.md` | ~4 KB | Contributor guide (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:51`). |
| `PROMPTS.md` | ~4 KB | Reusable agent prompt templates (`PROMPTS.md:1-36`). |
| `ARCHITECTURE.md` | ~7 KB | System architecture overview (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:49`). |
| `COMPONENTS.md` | ~5 KB | Component/validation-hotspot map (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:50`). |
| `STATE.md` | ~19 KB | Current code + hardware status summary (`AGENTS_START_HERE.md:15`). |
| `ROADMAP.md` | ~10 KB | Prioritized backlog (`ROADMAP.md:1-14`). |
| `TRUTHSHEET.md` | ~9 KB | Behavioral invariants / preservation contracts (`AGENTS_START_HERE.md:17`). |
| `DECISIONS.md` | ~48 KB | Decision log with large D-10/D-14/D-15 history (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:44`). |
| `QA_REGRESSION_MATRIX.md` | ~58 KB | Authoritative hardware/CI ledger (`AGENTS_START_HERE.md:18`). |
| `HDD_POPSTARTER_HANDOFF.md` | ~18 KB | Historical D-10 handoff. Audit: "Leave historical content intact" (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:57`). |
| `ANTIGRAVITY_NEXT_TASK.md` | ~1.4 KB | One-off agent task note. Audit: "Mark archived/stale" (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:56`). |

Plus five already-organized docs under `docs/`: `DOCUMENTATION_FOLLOWUP_AUDIT.md`, `GUI_OVERHAUL_PROMPT.md`, `HIGH_LEVEL_CODE_AUDIT.md`, `LAUNCH_HYGIENE.md`, `U10_INVESTIGATION.md`.

The problem: root is doing three different jobs at once — landing page (README), live governance (AGENTS/STATE/ROADMAP/TRUTHSHEET/QA), and stale/historical handoffs (HDD_POPSTARTER_HANDOFF, ANTIGRAVITY_NEXT_TASK) — with no visual separation.

### Proposed structure

**Keep at root (the canonical, frequently-read set — 8 files):**

- `README.md` — landing page, must stay at root for GitHub.
- `AGENTS.md`, `AGENTS_START_HERE.md` — agent entry points; tooling/agents look here by convention.
- `CONTRIBUTING.md` — GitHub renders this in the contribute UI; keep at root.
- `STATE.md`, `ROADMAP.md`, `TRUTHSHEET.md`, `QA_REGRESSION_MATRIX.md` — four of the six synchronized source-of-truth docs (`AGENTS_START_HERE.md:80` names six: these four plus `README.md` and `DECISIONS.md`, both kept at root separately). They are read and edited together constantly; splitting them off would break muscle memory and cross-links.

Rationale for keeping these eight: `AGENTS_START_HERE.md:13-22` and `:80` treat exactly this cluster as the day-to-day working set. Moving them creates churn for zero readability gain.

**Move to `docs/` (reference material, not daily-touch):**

- `ARCHITECTURE.md` → `docs/ARCHITECTURE.md`
- `COMPONENTS.md` → `docs/COMPONENTS.md`
- `PROMPTS.md` → `docs/PROMPTS.md`
- `RULES.md` → `docs/RULES.md`

These are stable reference docs read occasionally, not part of the synchronized status set. `docs/` already holds the comparable `LAUNCH_HYGIENE.md` (architecture-flavored) and `GUI_OVERHAUL_PROMPT.md` (prompt-flavored), so this groups like with like. Note the trade-off: `PROMPTS.md` is referenced by the audit allowlist (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:52`) and `RULES.md` is cross-checked against `AGENTS.md` (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:59`) — both moves require updating those references plus any `AGENTS_START_HERE.md` links.

**Archive (historical, keep but quarantine — propose a new `docs/archive/` directory):**

- `HDD_POPSTARTER_HANDOFF.md` → `docs/archive/HDD_POPSTARTER_HANDOFF.md`. It is explicitly historical; the audit says "Leave historical content intact; keep or strengthen archived/resolved banner so it is not used as current state" (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:57`). It documents D-10, which is now a preservation contract, not an open blocker (`AGENTS_START_HERE.md:9,28`).
- `ANTIGRAVITY_NEXT_TASK.md` → `docs/archive/ANTIGRAVITY_NEXT_TASK.md`. Audit: "Mark archived/stale and point to current state docs and `docs/U10_INVESTIGATION.md`" (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:56`).
- `docs/HIGH_LEVEL_CODE_AUDIT.md` → `docs/archive/HIGH_LEVEL_CODE_AUDIT.md` (or mark in place). Audit: "Either refresh or mark as historical. It references `ps2dev/ps2dev:latest` and stale D-10/D-14/BOOT.ELF issues" (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:55`). The live file now mentions `:latest` only historically (`docs/HIGH_LEVEL_CODE_AUDIT.md:256` records the workflow as pinned to `ps2dev/ps2dev:v2.0.0`), so the case for archiving is the staleness of its surrounding D-10/D-14/BOOT.ELF issues, not a live image contradiction.

Each archived file should gain a one-line banner at the top: "ARCHIVED / HISTORICAL — superseded by STATE.md + QA_REGRESSION_MATRIX.md; preserved for context." This satisfies the audit's no-silent-deletion rule (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:105`).

**Merge candidates (consider, do not force):**

- `RULES.md` (~3 KB) is small and overlaps `AGENTS.md` policy; the audit pairs them and warns against policy churn (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:59`). Option: fold `RULES.md` into `AGENTS.md` as a "Rules" section instead of moving it to `docs/`. Flagged as optional because the audit explicitly says "avoid policy churn unless it conflicts with current AGENTS guidance" — only merge if a content pass confirms they don't conflict.
- No other merges proposed. `STATE`/`ROADMAP`/`TRUTHSHEET`/`QA` are deliberately separate concerns (current state vs. backlog vs. invariants vs. ledger) per `AGENTS_START_HERE.md:15-18`; merging them would defeat the synchronization discipline.

### Resulting layout (proposed)

```
/ (root)
  README.md
  AGENTS.md
  AGENTS_START_HERE.md
  CONTRIBUTING.md
  STATE.md
  ROADMAP.md
  TRUTHSHEET.md
  QA_REGRESSION_MATRIX.md
  DECISIONS.md            (see note below)
docs/
  ARCHITECTURE.md
  COMPONENTS.md
  PROMPTS.md
  RULES.md                (or merged into AGENTS.md)
  DOCUMENTATION_FOLLOWUP_AUDIT.md
  GUI_OVERHAUL_PROMPT.md
  LAUNCH_HYGIENE.md
  U10_INVESTIGATION.md
docs/archive/
  HDD_POPSTARTER_HANDOFF.md
  ANTIGRAVITY_NEXT_TASK.md
  HIGH_LEVEL_CODE_AUDIT.md
```

**`DECISIONS.md` note:** at ~48 KB it is the second-largest doc and the audit wants its old D-10/D-14/D-15 investigation sections "compact[ed] into historical notes" with current decisions moved to the top (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:44`). That is a *content* compaction (audit's job), not a *move*. Recommendation: keep `DECISIONS.md` at root (it is part of the synchronized set per `AGENTS_START_HERE.md:19,80`) and let the content audit split the historical tail. Do not move it as part of this structural pass.

---

## 2. Stray / Untracked Clutter

These files exist in the real repo working tree (`git status --porcelain --ignored`, run from the repo root) and are **not** tracked. They split into "should be gitignored" and "should be removed (or are already ignored build output)."

### 2a. AI-tool scratch artifacts — currently untracked, propose gitignore + remove

These are one-off outputs from audit/agent runs (DeepSeek, Antigravity, OpenCode) sitting at root and in `docs/`:

- `ANTIGRAVITY_AUDIT_PROMPT.md`
- `OPENCODE_AUDIT_PROMPT.md`
- `DEEPSEEK_CLEANUP_DIFFS.md`
- `DEEPSEEK_ELFLOADER_DEEPDIVE.md`
- `DEEPSEEK_REDTEAM_HDD_FIX.md`
- `docs/ANTIGRAVITY_AUDIT_FINDINGS.md`
- `docs/ANTIGRAVITY_BUNDLE_AUDIT_FINDINGS.md`
- `docs/DEEPSEEK_CLEANUP_SUMMARY.md`
- `docs/DEEPSEEK_ELFLOADER_FINDINGS.md`
- `docs/DEEPSEEK_REDTEAM_FINDINGS.md`

Recommendation:
1. **Decide first whether any finding is worth keeping.** Per the project memory rule, external-tool reports are reference, not fact, and the DeepSeek elfloader report is known to have hallucinated `elf.c.orig`. Anything genuinely actionable should be distilled into `DECISIONS.md` / `QA_REGRESSION_MATRIX.md` *before* the scratch file is removed; the raw `*FINDINGS.md` should not become permanent repo docs.
2. **Remove** the scratch `.md` files once distilled (they are untracked, so removal is just `rm`, no git history impact).
3. **Add a `.gitignore` rule** so future agent runs don't re-clutter, e.g. patterns for `*_AUDIT_PROMPT.md`, `*_FINDINGS.md`, `DEEPSEEK_*.md`, `OPENCODE_*.md`. Caution: do NOT add a bare `ANTIGRAVITY_*.md` pattern — it would shadow the tracked `ANTIGRAVITY_NEXT_TASK.md`; the ANTIGRAVITY scratch files (`ANTIGRAVITY_AUDIT_PROMPT.md`, `ANTIGRAVITY_*_FINDINGS.md`) are already caught by the `*_AUDIT_PROMPT.md` / `*_FINDINGS.md` patterns. With `ANTIGRAVITY_*.md` excluded, none of the tracked root docs match these patterns; still review before committing. The existing `.gitignore` already carves out a "Local AI/tool directories" block (`.gitignore:49-52`); this is the file-level analogue and belongs in the same section.

### 2b. Build output — already correct, no action

These are already ignored (`!!` in status) and correctly excluded by `.gitignore`:

- `bin/POPSLOADER.ELF`, `bin/enceladus.elf` (covered by `*.elf`, `.gitignore:19`)
- `asm/`, `obj/` (`.gitignore:36-37`)
- `iop/bdm_query/*.irx`, `*.notiopmod.elf`, `obj/` (covered by `*.irx`, `*.elf`, `obj/`)
- `modules/ds34*/...` build artifacts (`*.a`, `*.o`, `*.irx`)
- `src/elf_loader/libcustom-elf-loader.a`, `*.o`, `loader/bin/`
- `artifacts/` (`.gitignore:55`)

No change needed — the ignore rules are working.

### 2c. Items needing a deliberate decision

- **`bin/POPSLDR/BUILD_INFO.txt`** (untracked, NOT ignored). This is generated fresh in CI as a 7-char commit + UTC stamp and is intentionally not committed; the runtime reads it for the on-screen build stamp. A locally-generated copy is leaking into status. Recommendation: add `bin/POPSLDR/BUILD_INFO.txt` to `.gitignore` so local builds don't show it as untracked, while CI keeps generating it at package time.

- **`POPSLOADER.zip`** (untracked, NOT ignored). This is a built release bundle (the `compilation.yml` artifact). `.gitignore` already ignores `*.7z` (`.gitignore:41`) but not `*.zip`. Recommendation: gitignore `POPSLOADER.zip` (or `*.zip` if no `.zip` is ever meant to be tracked — verify there is no tracked `.zip` first) and remove the local copy. Release artifacts belong on the GitHub release, not the working tree.

- **`dist_root/`** (untracked dir, with `dist_root/PS1_POPSLOADER/*.ELF` already ignored via `*.elf`). This is a locally-assembled release staging directory mirroring the `compilation.yml` ZIP layout (`POPS/PATCH_5.BIN`, `PS1_POPSLOADER/{POPSLOADER.ELF,POPSTARTER.ELF,APPINFO.PBT,BUILD_INFO.txt,title.cfg,icon.sys,*.icn}`). Recommendation: gitignore the whole `dist_root/` directory and remove the local copy. It is regenerable build/packaging scratch, not source.

- **`src/elf_loader/src/elf.c.orig`** (ignored via `*.orig`, `.gitignore:47`). Already ignored, but worth a manual delete: it is a stale merge/patch backup, and the project memory notes a prior external audit *hallucinated* this file's existence. Keeping a real `.orig` around invites confusion. Low priority since it's already invisible to git.

### Proposed `.gitignore` additions (summary)

Add under a clearly-commented block (mirroring the existing `.gitignore:49-55` local-artifacts style):

```
# Local AI/tool scratch reports (distill into DECISIONS/QA before removing)
# NOTE: deliberately NO bare `ANTIGRAVITY_*.md` — it would shadow the tracked
# ANTIGRAVITY_NEXT_TASK.md. The ANTIGRAVITY scratch files end in
# _AUDIT_PROMPT.md / _FINDINGS.md and are already covered below.
*_AUDIT_PROMPT.md
*_FINDINGS.md
DEEPSEEK_*.md
OPENCODE_*.md

# Local build/packaging output
bin/POPSLDR/BUILD_INFO.txt
POPSLOADER.zip
dist_root/
```

Verify before committing: none of these patterns shadow a tracked file. The one real collision risk — a bare `ANTIGRAVITY_*.md` shadowing the tracked `ANTIGRAVITY_NEXT_TASK.md` — was removed above; the remaining patterns were checked against the tracked root docs and `docs/*.md` and do not collide.

---

## 3. What the Audit Marked Archive / Delete

`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md` (dated 2026-05-28, `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:3`) is the authoritative source for which docs are stale. It marks **nothing for hard deletion** — its discipline is "Do not delete historical failure notes unless they are moved into a clearly marked archive section" (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:105`). The relevant dispositions:

| File | Audit disposition | Citation | This plan's action |
| --- | --- | --- | --- |
| `ANTIGRAVITY_NEXT_TASK.md` | "Mark archived/stale" | `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:56` | Move to `docs/archive/` with banner. |
| `HDD_POPSTARTER_HANDOFF.md` | "Leave historical content intact; keep/strengthen archived banner" | `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:57` | Move to `docs/archive/` with banner. |
| `docs/HIGH_LEVEL_CODE_AUDIT.md` | "Either refresh or mark as historical" (stale `:latest`, D-10/D-14) | `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:55` | Move to `docs/archive/` (or refresh; archive is the lower-risk default). |
| `DECISIONS.md` | "Compact old D-10/D-14/D-15 investigation sections into historical notes" | `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:44` | Content compaction (audit's job) — keep file at root. |

Everything else in the audit's file-by-file table (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:39-63`) is "update/refresh," not archive — those are content jobs for the doc-sync PRs (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:65-128`), out of scope for this structural plan.

The untracked `docs/*FINDINGS.md` and root `*AUDIT_PROMPT.md` / `DEEPSEEK_*.md` files (Section 2a) post-date the audit and are not in its table at all; they are scratch and handled by gitignore + removal rather than archive.

---

## 4. Branch Hygiene (Approach, Not Commands)

The repository carries ~58 branch refs (`git branch -a | wc -l` = 58). Local breakdown:

- **`backup/*`** — 15 refs. Point-in-time safety snapshots, e.g. `backup/BETA-12-PLAY-before-dkwdrv-v3-20260524-010700`, `backup/master-before-beta12-force-20260522-180947`. Date-stamped, single-purpose.
- **`claude/*`** — 29 refs. Per-task feature/fix branches (e.g. `claude/code-quality`, `claude/launch-args-fix`, `claude/docs-overhaul`).
- **`opencode/*`** — 4 refs. Agent-run branches (`opencode/clever-otter`, etc.).
- **`archive/*`, `checkpoint/*`, `NUNO-CHECKPOINT-*`** — 3 refs. Explicit archive/checkpoint markers.
- Plus the live lines: `master`, `BETA-12-PLAY`, `deepseek-workspace-2026-06-14`, `potential-success-2026-06-14`, `audit/latest-2026-06-14`.

18 local branches already report as merged into `BETA-12-PLAY` (`git branch --merged BETA-12-PLAY | wc -l` = 18), which is a strong signal a large fraction are safe-to-retire candidates.

### Suggested triage approach (no deletions prescribed)

1. **Establish protected lines first.** `master`, `BETA-12-PLAY` (the rolling-release source per `AGENTS_START_HERE.md:60-61`), and whatever the current in-flight working branch is must never be in scope for cleanup. Confirm with the maintainer before touching anything.

2. **Triage by category, not by name:**
   - `backup/*` and `checkpoint/*` and `NUNO-CHECKPOINT-*`: these exist precisely so they can be discarded once their "before-X" change is confirmed good on hardware. Approach: for each, identify the change it predates, confirm that change is merged and hardware-verified in `QA_REGRESSION_MATRIX.md`, and only then propose retirement. The date stamp tells you how stale it is.
   - `claude/*` and `opencode/*`: cross-reference against merged status (`git branch --merged BETA-12-PLAY`) and against open PRs. A `claude/*` branch that is fully merged with a closed PR is a retirement candidate; one with an open/draft PR (e.g. anything tied to PR #471 Layer C, still DRAFT per `AGENTS_START_HERE.md:55`) must stay.
   - `archive/*`: by definition intended to persist; leave unless the maintainer says otherwise.

3. **Verify merged-ness with content, not just `--merged`.** A branch can contain useful unmerged commits even if its tip looks merged after a squash/force-push (the repo has force-push history — note `backup/master-before-beta12-force-*`). Before retiring any branch, confirm there are no orphan commits with `git log BETA-12-PLAY..<branch>`.

4. **Prefer archival tags over deletion for anything uncertain.** If a `backup/*` branch might still be needed, converting it to a lightweight tag (`git tag archive/<name> <branch>` then deleting the branch) keeps the commit reachable while removing it from the branch list. This preserves the safety-net intent without the clutter.

5. **Remote vs. local.** Several local branches have no `origin/*` counterpart and several remotes have no local (compare `git branch` vs `git branch -r`). Triage local and remote separately; deleting a local branch does not touch the remote and vice-versa. The maintainer should drive remote deletions since they affect collaborators and the rolling-release trigger.

6. **Cadence.** Adopt a periodic (e.g. post-release) sweep: when a `BETA-NN` line is hardware-confirmed and shipped, retire its `backup/*before*` snapshots and merged `claude/*` task branches in one reviewed batch, rather than letting them accumulate across releases.

Deliberately **not** listed here: specific branch names to delete. Branch deletion is destructive and depends on hardware-verification state that only the maintainer + `QA_REGRESSION_MATRIX.md` can confirm. This section is a method, not a kill-list.

---

## 5. Suggested Execution Order (when approved)

1. Distill any actionable content out of the untracked `*FINDINGS.md` (Section 2a) into `DECISIONS.md` / `QA_REGRESSION_MATRIX.md`.
2. Add the `.gitignore` block (Section 2 summary) and remove the now-ignored local scratch/build artifacts.
3. Create `docs/archive/`, move the three historical docs (Section 1 archive list), add banners.
4. Move the four reference docs to `docs/` (Section 1 move list).
5. Update cross-links: `AGENTS_START_HERE.md:13-22`, the `PROMPTS.md` allowlist (`docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:52` lists `docs/*.md`), and any README links to moved files.
6. Branch-hygiene triage (Section 4) — separate, maintainer-driven, after the doc moves settle.

Verification for the doc-move steps is non-runtime: `git diff --check`, a link-check pass (grep for the old root paths across `*.md`), and confirming no doc in the synchronized set lost a reference. No build or hardware test is required for structure-only changes (consistent with `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md:152-153`).
