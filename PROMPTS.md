Last updated: 2026-03-20

# PROMPTS

## Purpose
Reusable prompt templates for tasking agents against this repository with tight scope, CI-aware validation, and verifiable outcomes.

## Base Task Template
```markdown
Goal:
- <single objective>

Allowed files (allowlist):
- <explicit paths>

Forbidden:
- No edits outside allowlist
- No unrelated refactors or format churn
- No behavior changes outside the stated goal
- No new runtime logging unless requested

Validation policy:
- GitHub Actions CI is authoritative for build/package claims
- Local build results are advisory only
- Keep behavior and packaging claims aligned with `Makefile` and `.github/workflows/compilation.yml`

Repo invariants to preserve:
- Embedded-Lua boot path remains intact
- Settings commit on Settings/Profile exit remains transactional
- Persisted settings schema remains intentionally handled
- USB vs MX4SIO split remains mount-driver based
- Retry/probe logic remains bounded
- Release ZIP manifest contract remains valid unless the goal is a packaging migration

Deliverables:
1) Summary
2) Diffstat
3) Key diff hunks (or full diff if requested)
4) Test plan/results (include unrun items)
```

## Task-Specific Templates

### 1) Runtime behavior fix (storage, launch, settings)
```markdown
Goal:
- Fix <specific runtime bug> without changing unrelated menu or device behavior.

Allowed files:
- bin/POPSLDR/system.lua
- bin/POPSLDR/ui.lua
- src/luasystem.cpp
- src/luaHDD.cpp

Required checks:
- Settings persistence semantics are unchanged
- USB/MX4SIO classification still uses mount-driver identity
- Missing-file failures still produce explicit user notifications
- No unbounded loops are introduced
- Any build/package claims are stated in CI terms, not local-build terms
```

### 2) Packaging or CI update
```markdown
Goal:
- Update release packaging policy and CI verification in lockstep.

Allowed files:
- .github/workflows/compilation.yml
- Makefile
- README.md
- ROADMAP.md
- QA_REGRESSION_MATRIX.md

Required checks:
- ZIP root directories are still validated
- Expected file set is exact
- Forbidden legacy payloads are still rejected, or any migration is documented explicitly
- Docs match the resulting CI contract
```

### 3) Documentation audit/update
```markdown
Goal:
- Refresh repository docs to match current code, CI behavior, and known implementation limits.

Allowed files:
- AGENTS.md
- ARCHITECTURE.md
- COMPONENTS.md
- CONTRIBUTING.md
- DECISIONS.md
- PROMPTS.md
- QA_REGRESSION_MATRIX.md
- README.md
- ROADMAP.md
- RULES.md
- STATE.md
- TRUTHSHEET.md

Required checks:
- Every behavior claim is traceable to current repository files or explicit project policy
- CI-first validation policy is documented consistently
- Unverified hardware claims are marked `Unknown (verify on hardware)`
- Implemented vs not-implemented menu options are accurately documented
- Internal legacy names such as `GSMB` are not misdescribed as user-facing features
```

### 4) Status-page sync
```markdown
Goal:
- Update status/rules/decision docs so they agree with current repository behavior.

Allowed files:
- STATE.md
- ROADMAP.md
- DECISIONS.md
- RULES.md
- TRUTHSHEET.md

Required checks:
- No stale branch or time-window claims remain
- Open work matches actual code-visible gaps
- Dormant helper code is not documented as enforced runtime behavior
```

## Prompt Hygiene Rules
- Always provide a strict file allowlist.
- Explicitly declare non-goals.
- Ask for bounded and deterministic behavior for probes, retries, and loops.
- Require evidence-backed claims for docs and behavior summaries.
- Require explicit test reporting, including what was not run.
- For build/package work, require CI-compatible outcomes rather than local-environment assumptions.
