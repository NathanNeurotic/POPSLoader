Last updated: 2026-03-05

# RULES

## Purpose
Short, enforceable repository rules.

## Do
- [ ] Keep diffs minimal and task-scoped.
- [ ] Use bounded loops only.
- [ ] Preserve determinism in logic and outputs.
- [ ] Preserve boot/launch pipeline and device detection unless task explicitly targets them.
- [ ] Document assumptions with `TODO` instead of guessing project facts.

## Don't
- [ ] Do not run destructive commands without explicit instruction.
- [ ] Do not touch unrelated Lua/C/C++ files.
- [ ] Do not add logging unless explicitly requested.
- [ ] Do not introduce broad refactors without explicit approval.
- [ ] Do not mix unrelated changes in one commit.

## Bounded Logic Only
- [ ] Every loop must have a clear bound or termination condition.
- [ ] Retries must have explicit max attempts and exit behavior.
- [ ] Polling must use explicit limits and fail paths.

## Logging Policy
- [ ] Default: no new logs.
- [ ] If explicitly requested: keep logs minimal, scoped, and removable.
- [ ] Never log secrets, keys, or sensitive identifiers.

## Error Handling Expectations
- [ ] Fail fast with actionable error messages.
- [ ] Avoid silent failures and broad catch-all suppression.
- [ ] Preserve existing error contracts unless change is intentional and documented.

## Determinism Policy
- [ ] Avoid nondeterministic ordering where output matters.
- [ ] If randomness is required, seed and document behavior.
- [ ] Keep time/external-state dependencies explicit and bounded.
