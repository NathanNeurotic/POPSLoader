# Change rules (discipline + regression checklist)

## Snowball discipline (keep changes narrow)
- Prefer small, isolated diffs and avoid unrelated refactors unless necessary for the task.【F:agents.md†L15-L18】
- Do not invent behavior; when uncertain, mark **TODO: verify** and cite the file(s) to inspect next.【F:agents.md†L3-L13】
- Do not change prefix rules (HDD: none, SMB: `SB.`, MASS/MMCE/USB: `XX.`).【F:agents.md†L6-L9】
- Use existing logging patterns and avoid per-frame UI spam (throttle input/debug logs).【F:docs/DEBUGGING.md†L5-L12】

## Full-file output rule (response formatting)
- **UNKNOWN (not documented in repo):** The requirement to output full file contents for modified files is not present in repository docs.
  - Suggested verification command: `rg -n "full file|full-file|full content" -g "*.md"`

## Regression checklist (doc-only changes should still consider runtime behavior)
1. **Build parity with CI:** CI runs `make clean elfloader all package`; use this as the gold standard when validating build changes.【F:.github/workflows/compilation.yml†L32-L35】
2. **Runtime layout expectations:** Confirm any file moves or asset layout updates against `docs/RUNTIME_LAYOUT.md` before changing UI/asset resolution logic.【F:docs/RUNTIME_LAYOUT.md†L1-L31】
3. **Launch/debug logging:** If modifying launch behavior, ensure the minimal `LAUNCH:` log lines are still emitted per `docs/DEBUGGING.md`.【F:docs/DEBUGGING.md†L19-L55】

## UNKNOWNs (not found in repo)
- **Snowball discipline terminology:** The term "snowball discipline" is not defined in repo docs; interpret it using the existing change-discipline guidance above.
  - Suggested verification command: `rg -n "snowball" -g "*.md"`
