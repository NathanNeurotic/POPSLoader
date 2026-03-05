Last updated: 2026-03-05

# PROMPTS

## Reusable Codex PR prompt template
```markdown
Goal:
- <single objective tied to POPSLoader behavior/docs/build>

Allowed files (allowlist):
- <explicit paths only>

Forbidden changes:
- No edits outside allowlist
- No behavior changes outside stated goal
- No unrelated refactors/format churn
- No debug/logging additions unless requested

Invariants to preserve:
- POPStarter launch pipeline remains intact
- MX4SIO vs USB separation uses mount-driver identity (no guessing)
- Settings persist only on confirm/leave Settings/Profile
- Logic remains bounded/deterministic (no unbounded retries)

Deliverables:
1) Summary of changes
2) `git diff --stat`
3) Full `git diff`
4) Test plan/results (including unrun items)
```

## POPSLoader-tailored examples

### 1) Bounded backend behavior change (MX4SIO quirk masking)
```markdown
Goal:
- Implement bounded MX4SIO first-entry masking: initialize backend, attempt detect/list, wait ~1s once, retry once, then stop.

Allowed files:
- bin/POPSLDR/system.lua
- bin/POPSLDR/ui.lua

Forbidden:
- No launch-policy rewrites
- No packaging/CI edits
- No unrelated UI redesign

Required checks:
- USB list still excludes MX4SIO roots
- MX4SIO list still depends on mount-driver identity
- Retry count and delay are deterministic/bounded
```

### 2) UI layout-only fix (settings alignment/icon stability)
```markdown
Goal:
- Fix Settings/Profile alignment so BDMA label/arrows stay visually stable regardless of text length.

Allowed files:
- bin/POPSLDR/ui.lua

Forbidden:
- No backend/storage logic edits
- No profile persistence logic changes

Required checks:
- Icon coordinates are deterministic
- No overlap at 4:3 safe area
- No additional per-frame allocations/scans
```

### 3) Packaging/CI edit (artifact contents)
```markdown
Goal:
- Change release artifact contents from POPS tm2 triplet to PATCH5.bin policy.

Allowed files:
- .github/workflows/compilation.yml
- README.md

Forbidden:
- No runtime Lua/C/C++ changes
- No gameplay/UI behavior changes

Required checks:
- Artifact verifier enforces new expected set
- Forbidden/legacy files are rejected explicitly
```

## Prompt hygiene rules
- Always specify an explicit allowlist of editable files.
- Explicitly forbid unrelated changes.
- Require summary + diffstat + full diff + test plan in output.
- Require bounded/deterministic logic for retries, polling, and classification.
