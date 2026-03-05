Last updated: 2026-03-05

# PROMPTS

## Bug Fix (Minimal Diff)
```markdown
Goal:
- Fix: <bug summary>

Non-goals:
- No refactors, no feature additions, no formatting-only churn.

Allowed files:
- <explicit file paths or directories>

Constraints:
- Minimal diff only.
- Bounded loops only.
- Avoid touching unrelated Lua/C/C++ files.
- Do not add logging unless explicitly requested.
- Preserve boot/launch and device detection logic unless this bug is in those areas.

Deliverables:
- Summary, diffstat, key diff, test plan/results.

Test plan:
- Run targeted checks first: <TODO commands>
- Add manual verification steps for uncovered paths.
```

## Feature (Guardrails)
```markdown
Goal:
- Add: <feature summary>

Non-goals:
- No broad cleanup/refactor outside feature scope.

Allowed files:
- <explicit file paths or directories>

Constraints:
- Keep architecture boundaries intact.
- Bounded logic only.
- Backward compatibility unless explicitly approved.
- No logging additions unless requested.

Deliverables:
- Implementation, docs update, risk notes, test plan/results.

Test plan:
- New/updated targeted tests: <TODO commands>
- Regression checks for adjacent behavior.
```

## Refactor (Explicit Approval Required)
```markdown
Goal:
- Refactor: <scope>

Non-goals:
- No behavior changes.

Allowed files:
- <explicit file paths or directories>

Constraints:
- Proceed only with explicit refactor approval.
- Preserve public interfaces unless approved.
- Bounded loops only.
- Keep commit(s) small and reviewable.

Deliverables:
- Before/after rationale, migration notes (if any), test plan/results.

Test plan:
- Baseline + post-refactor parity checks: <TODO commands>
```

## Investigate + Propose Plan Only
```markdown
Goal:
- Investigate: <question/problem>

Non-goals:
- No code or config changes.

Allowed files:
- Read-only across relevant files.

Constraints:
- Gather evidence from repo only.
- Do not infer unknown project facts; mark TODO where uncertain.

Deliverables:
- Findings, likely root cause(s), ranked options, recommended plan.

Test plan:
- If implementation follows, propose targeted validation steps.
```
