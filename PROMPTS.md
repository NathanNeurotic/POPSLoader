# PROMPTS

This file stores “known-good” prompt patterns for AI-assisted contributions (Codex) to minimize regressions.

## General PR prompt template
Use this when asking Codex to implement a bounded change.

### Template
- Repo/branch: <fill in>
- Objective: <one sentence>
- Files allowed to change: <explicit list>
- Forbidden changes: logging, unrelated refactors, UI layout changes, etc.
- Behavioral invariants: <do-not-break list>
- Deliverables: diffstat, diff, test plan

## Examples (fill/extend over time)

### Example: Bounded backend behavior fix
- Objective: Mask MX4SIO first-entry quirk by performing exactly two mount attempts after one init, with ~1s delay between attempts.
- Files allowed: <explicit list>
- Constraints:
  - No new retry systems elsewhere
  - No identity rule changes
  - No added logging
  - Deterministic/bounded behavior only
- Deliverables: diffstat, diff, test plan

### Example: UI layout fix
- Objective: Fix Settings page alignment and prevent icon shift due to variable string lengths.
- Constraints:
  - No behavioral changes to backend logic
  - No new assets unless required
  - Keep layout deterministic
- Deliverables: before/after screenshots if possible + diff

## Prompt hygiene rules
- Always specify the file allowlist.
- Always specify “no unrelated changes.”
- Require full diffs and minimal commits.
- Require a test plan appropriate for PS2 hardware constraints.
