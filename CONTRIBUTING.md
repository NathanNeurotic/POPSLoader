Last updated: 2026-03-05

# CONTRIBUTING

## Purpose
Contributor workflow for humans and AI agents.

## Branch and PR Expectations
- [ ] One branch per task.
- [ ] Prefer short-lived branches with focused scope.
- [ ] TODO: Confirm branch naming convention (suggestion: `codex/<topic>` for AI work).
- [ ] PR must state problem, scope, risks, and validation.
- [ ] Keep PRs reviewable; split oversized work.

## Commit Discipline
- [ ] One logical task per commit.
- [ ] Use clear, imperative commit messages.
- [ ] Keep diffs minimal; no unrelated formatting churn.
- [ ] Avoid touching unrelated Lua/C/C++ files.

## Code Style Expectations
- [ ] Follow existing local style in touched files.
- [ ] Preserve naming and structure conventions already in use.
- [ ] Do not introduce unbounded loops.
- [ ] Avoid adding logging unless explicitly requested.
- [ ] TODO: Link canonical style guide if available.

## Good Bug Reports
- [ ] Include expected vs actual behavior.
- [ ] Include minimal reproducible steps.
- [ ] Include environment details (OS/device/runtime/version).
- [ ] Include logs/traces only when relevant and sanitized.
- [ ] Include suspected scope/impact.

## Review Checklist
- [ ] Scope is task-focused and minimal.
- [ ] Boot/launch and device detection are unchanged unless intended.
- [ ] Error handling remains clear and deterministic.
- [ ] Tests or manual validation are documented.
- [ ] Docs are updated when behavior changes.
