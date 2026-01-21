# Agent Guidance (POPSLoader)

## Non-negotiables
- **DO NOT invent rules.** If a rule is not found in code or repo docs, mark it **TODO: verify** and cite where it should be verified.
- **Search first, quote exact code, then propose a diff.** Use precise file/line references when describing behavior.
- **Never change prefix rules:**
  - HDD: **no prefix**
  - SMB: `SB.`
  - MASS/MMCE/USB: `XX.`

## When confused
- Produce a **short decision table** (source → pops root → prefix → argv example) and cite code locations.
- If behavior is still unclear, add **TODO: verify** and list the file(s) to inspect next.

## Change discipline
- Prefer small, isolated diffs.
- Do not refactor unrelated code.
- Only add logs if they are throttled or change-detected (never per-frame).
