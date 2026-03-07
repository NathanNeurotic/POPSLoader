Last updated: 2026-03-06

# PROMPTS

## Purpose
Reusable prompt templates for tasking agents against this repository with tight scope and verifiable outcomes.

## Base Task Template
```markdown
Goal:
- <single objective>

Allowed files (allowlist):
- <explicit paths>

Forbidden:
- No edits outside allowlist
- No unrelated refactors/format churn
- No behavior changes outside stated goal
- No new runtime logging unless requested

Repo invariants to preserve:
- Embedded-Lua boot path remains intact
- Settings commit on Settings/Profile exit remains transactional
- USB vs MX4SIO split remains mount-driver based
- Retry/probe logic remains bounded
- Release ZIP manifest contract remains valid unless goal is packaging migration

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
- Fix <specific runtime bug> without changing unrelated menu/device behavior.

Allowed files:
- bin/POPSLDR/system.lua
- bin/POPSLDR/ui.lua
- src/luasystem.cpp

Required checks:
- Settings persistence semantics are unchanged
- USB/MX4SIO classification still uses mount-driver identity
- Missing-file failures still produce explicit user notifications
- No unbounded loops introduced
```

### 2) Packaging/CI update
```markdown
Goal:
- Update release packaging policy and CI verification in lockstep.

Allowed files:
- .github/workflows/compilation.yml
- README.md
- ROADMAP.md

Required checks:
- ZIP root directories are still validated
- Expected file set is exact
- Forbidden legacy payloads are still rejected (or intentionally migrated)
```

### 3) Documentation audit/update
```markdown
Goal:
- Refresh repository docs to match current code and build behavior.

Allowed files:
- AGENTS.md
- ARCHITECTURE.md
- COMPONENTS.md
- CONTRIBUTING.md
- DECISIONS.md
- PROMPTS.md
- QA_REGRESSION_MATRIX.md
- ROADMAP.md
- RULES.md
- STATE.md
- TRUTHSHEET.md

Required checks:
- Every behavior claim is traceable to current repository files
- Unverified hardware claims are marked `Unknown (verify on hardware)`
- Implemented vs not-implemented menu options are accurately documented
```

## Prompt Hygiene Rules
- Always provide a strict file allowlist.
- Explicitly declare non-goals.
- Ask for bounded/deterministic behavior for probes/retries/loops.
- Require evidence-backed claims for docs and behavior summaries.
- Require explicit test reporting, including what was not run.
