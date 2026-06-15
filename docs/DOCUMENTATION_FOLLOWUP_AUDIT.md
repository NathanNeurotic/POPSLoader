# Documentation Follow-up Audit

Last audited: 2026-05-28
Audited branch/tip: `BETA-12-PLAY` at `b0c0baf`

This is a handoff plan for a documentation-only follow-up job. It records drift found after BETA-10-5 and after the post-release PRs that landed on `BETA-12-PLAY`. It is not itself a replacement for `QA_REGRESSION_MATRIX.md`, and it must not be treated as hardware evidence.

## Current Ground Truth

- Release baseline: `BETA-10-5` / `v1.0.0-rev5` at `9a0ebe2`.
- Current development tip at audit time: `BETA-12-PLAY` at `b0c0baf`.
- GitHub Actions build path is canonical. The pinned CI image is `ps2dev/ps2dev:v2.0.0`.
- The rolling release workflow exists and was added after BETA-10-5.
- BETA-10-5 hardware results are recorded in `QA_REGRESSION_MATRIX.md`; do not restate them broadly without checking that ledger.
- Post-release PRs #470 and #472 are repo/CI-verified only unless a later hardware result is recorded in `QA_REGRESSION_MATRIX.md`.
- `PR #472` behavior to preserve in docs: USB or unknown `mass:/` boot stays USB-only; the MX4SIO stack loads only after explicit MX4SIO evidence (`mx4sio:/`, `sdc`/`mx4`, or `.boot_mx4sio`). Do not describe this as loading both mass backends before detection.

## Non-negotiable Documentation Rules

- Separate repo-verified source claims from hardware-reported results.
- Mark unverified runtime or hardware behavior as `Unknown (verify on hardware)`.
- Keep `QA_REGRESSION_MATRIX.md` as the detailed hardware and CI ledger.
- Keep root docs as stable summaries, not repeated experiment logs.
- Do not claim a hardware fix for PR #470, PR #471, or PR #472 unless a matching hardware row is added to `QA_REGRESSION_MATRIX.md`.
- Do not treat D-10, D-14, or D-15 as open blockers unless newer hardware evidence proves a regression.
- Do not retroactively edit the BETA-10-5 changelog as if post-release PRs shipped in that release. Add an `[Unreleased]` section if needed.

## Highest-risk Drift To Fix First

1. `AGENTS_START_HERE.md` still presents D-10/D-14 as urgent unresolved blockers. This is dangerous for future agents because those paths are preservation contracts now.
2. `DECISIONS.md` still contains large unresolved D-10/D-14/D-15 investigation text. That history should be archived or compacted, with current decisions moved to the top.
3. `STATE.md`, `TRUTHSHEET.md`, and `docs/LAUNCH_HYGIENE.md` conflict on HDD settings sidecars. Current rule: non-HDD installs use per-device sidecars; HDD installs intentionally fall back to `mc0:/POPSTARTER/.pldrs`.
4. `README.md` overstates BOOT.ELF/wLaunchELF status and still says the current public release is BETA 10 rather than BETA-10-5 / `v1.0.0-rev5`.
5. Several docs either omit the rolling release workflow or still imply local builds / `ps2dev/ps2dev:latest`.
6. MX4SIO documentation must reflect the PR #472 rule: infer boot source first, then load only the required backend stack. If MX4SIO is positively identified, load the MX4SIO stack and its USB dependency; otherwise stay USB-only.

## File-by-file Audit

| File | Priority | Follow-up action |
| --- | --- | --- |
| `README.md` | High | Update release wording to BETA-10-5 / `v1.0.0-rev5`; narrow BOOT.ELF claims; mention CI as canonical build path; document non-HDD sidecars vs HDD MC fallback; refresh known issues and planned work. |
| `STATE.md` | High | Update branch tip and post-release status; fix HDD settings contradiction; add PR #472 MX4SIO behavior and hardware status; split release hardware evidence from current branch repo/CI evidence. |
| `ROADMAP.md` | High | Add PR #472 as merged and hardware-unverified; remove completed or duplicated items; update Layer C gating around PR #471 draft/hardware input; clarify GUI mockup blocker. |
| `DECISIONS.md` | High | Compact old D-10/D-14/D-15 investigation sections into historical notes; add current decisions for HDD settings fallback, LAUNCH_ARGS consumers, MX4SIO evidence-based classification, and rolling release automation. |
| `QA_REGRESSION_MATRIX.md` | High | Add current capstone rows for PR #470, rolling release workflow, and PR #472 CI status; keep hardware unknown where no tester result exists; distinguish `9a0ebe2` release hardware from `b0c0baf` branch state. |
| `TRUTHSHEET.md` | High | Fix HDD sidecar truth; add MX4SIO evidence-based mass classification truth; reconcile DKWDRV-HDD and BOOT.ELF statuses with QA ledger. |
| `AGENTS_START_HERE.md` | High | Replace stale urgent objective with current start-here summary: BETA-10-5 clean baseline, preservation contracts, current open work, and doc sync priorities. |
| `docs/LAUNCH_HYGIENE.md` | High | Update sidecar and LAUNCH_ARGS layers; tone down broad root-cause language; add PR #472 backend behavior; mark U-10 and DKWDRV custom HDD path as still unresolved unless QA says otherwise. |
| `ARCHITECTURE.md` | Medium | Refresh launch/module flow for launch args, boot hints, rolling release workflow, and B2 HDD handoff preservation contract; remove stale D-10/D-14 unresolved gap. |
| `COMPONENTS.md` | Medium | Update validation hotspots from active D-10/D-14 failures to preservation tests; include ILINK not implemented; mention rolling release workflow. |
| `CONTRIBUTING.md` | Medium | Refresh validation hotspots and CI expectations; ensure hardware-only claims route through QA matrix. |
| `PROMPTS.md` | Medium | Update allowed/audited doc list to include `docs/*.md`, `HDD_POPSTARTER_HANDOFF.md`, `bin/changelog`, and `.github/workflows/rolling-release.yml`. |
| `docs/U10_INVESTIGATION.md` | Medium | Keep as live investigation doc; add what was already tried and failed, especially F4/unconditional unmount if confirmed in QA; make clear this is U-10 only, not all BOOT.ELF routes. |
| `docs/GUI_OVERHAUL_PROMPT.md` | Medium | Remove duplicated PNG list; update target branch from `master` to `BETA-12-PLAY`; resolve Settings UI contradiction; update blockers now that D-10/D-14/D-15 are settled. |
| `docs/HIGH_LEVEL_CODE_AUDIT.md` | Medium | Either refresh or mark as historical. It references `ps2dev/ps2dev:latest` and stale D-10/D-14/BOOT.ELF issues. |
| `ANTIGRAVITY_NEXT_TASK.md` | Medium | Mark archived/stale and point to current state docs and `docs/U10_INVESTIGATION.md`. |
| `HDD_POPSTARTER_HANDOFF.md` | Low | Leave historical content intact; keep or strengthen archived/resolved banner so it is not used as current state. |
| `AGENTS.md` | Low | Mostly policy-current; optionally update last-reviewed date and mention rolling release/docs synchronization expectations. |
| `RULES.md` | Low | Quick consistency pass only; avoid policy churn unless it conflicts with current AGENTS guidance. |
| `bin/changelog` | Low | Add `[Unreleased]` or future-release notes for PR #470 and PR #472 if project convention allows. Do not modify BETA-10-5 entries to include post-release work. |
| `.github/workflows/compilation.yml` | Low | No code change expected; docs should reference its pinned image and artifact path. |
| `.github/workflows/rolling-release.yml` | Low | No code change expected; docs should reference this workflow as post-release automation. |
| `iop/embed/BDMASSAULT_MX4SIO/README.MD` | Low | Only update if MX4SIO driver behavior text conflicts with PR #472; otherwise leave driver-local docs alone. |

## Recommended Follow-up PR Shape

### PR 1: Current-state source-of-truth sync

Edit:

- `README.md`
- `STATE.md`
- `ROADMAP.md`
- `DECISIONS.md`
- `QA_REGRESSION_MATRIX.md`
- `TRUTHSHEET.md`

Goal:

- Make the main docs agree on BETA-10-5 release status, current `BETA-12-PLAY` tip, PR #470, PR #472, CI workflow state, known-broken items, and hardware evidence boundaries.

Required guardrails:

- Hardware pass/fail claims must have matching QA rows.
- PR #472 should be `Unknown (verify on hardware)` unless QA has a later tester result.
- D-10/D-14/D-15 should be written as preservation contracts, not open failures.

### PR 2: Agent/handoff cleanup

Edit:

- `AGENTS_START_HERE.md`
- `ANTIGRAVITY_NEXT_TASK.md`
- `docs/HIGH_LEVEL_CODE_AUDIT.md`
- `docs/LAUNCH_HYGIENE.md`
- `docs/U10_INVESTIGATION.md`

Goal:

- Remove stale handoff traps and archive old investigations without deleting useful context.
- Keep `docs/U10_INVESTIGATION.md` as the active diagnostic-first guide for U-10.

Required guardrails:

- Do not delete historical failure notes unless they are moved into a clearly marked archive section.
- Do not collapse U-10 into generic BOOT.ELF status.

### PR 3: Architecture/component/release polish

Edit:

- `ARCHITECTURE.md`
- `COMPONENTS.md`
- `CONTRIBUTING.md`
- `PROMPTS.md`
- `docs/GUI_OVERHAUL_PROMPT.md`
- `bin/changelog`

Goal:

- Refresh supporting docs after the source-of-truth docs are aligned.
- Add future-release notes without rewriting BETA-10-5 history.

Required guardrails:

- GUI overhaul docs should not start implementation until the mockup oracle requirement is resolved.
- Changelog should separate released BETA-10-5 work from post-release development.

## Suggested Search Checks For The Follow-up Job

Run these after editing and resolve or intentionally preserve every hit:

```powershell
rg -n "current public release is BETA 10|BETA 10 Highlights|ps2dev/ps2dev:latest|master" *.md docs bin .github
rg -n "D-10.*(unresolved|unknown|failing)|D-14.*(unresolved|unknown|failing)|D-15.*unknown" *.md docs
rg -n "sidecar|pfs1:|mc0:/POPSTARTER/.pldrs" README.md STATE.md ROADMAP.md DECISIONS.md TRUTHSHEET.md docs
rg -n "load both|BOTH mass|before ioctl|MX4SIO classification" *.md docs
rg -n "BOOT.ELF|wLaunchELF|wLE|U-10|DKWDRV" README.md STATE.md ROADMAP.md DECISIONS.md TRUTHSHEET.md docs QA_REGRESSION_MATRIX.md
```

Expected outcome:

- Any remaining stale wording is either corrected or explicitly marked historical.
- No current-state doc says MX4SIO detection works by loading both mass backends before identification.
- No current-state doc says HDD settings sidecars are active.

## Verification Plan For The Follow-up Job

- `git diff --check`
- Run the suggested `rg` checks above.
- Review `QA_REGRESSION_MATRIX.md` separately after edits and verify every hardware claim has a specific recorded result.
- No PS2 hardware test is required for docs-only edits, but hardware status must stay `Unknown (verify on hardware)` where no tester result exists.
- No full build is required for docs-only edits unless workflow files or packaging behavior are changed.

## Suggested Final Response Template

Use the repository's requested task format:

- Summary: state which docs were synced and which claims were deliberately left as hardware-unknown.
- Diffstat: list changed files by role.
- Diff: summarize important wording changes rather than pasting every doc hunk.
- Test plan: include `git diff --check`, `rg` stale-claim checks, and `not run: hardware/build` with reason.
