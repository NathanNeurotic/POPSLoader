# Documentation Audit (Launch Behavior + Device Rules)

This report reconciles documentation against **current code behavior**. It is the canonical audit record and should be updated whenever launch logic changes.

## 1) Truth map (from current code)

**Source mode selection**
- `ResolveLaunchPolicy(gamelocation)` chooses the device policy based on `gamelocation` prefix (`mass`, `mmce`, `pfs`) or UI scene fallback.

**POPS root selection**
- In `PLDR.RunPOPStarterGame(...)`, `pops_root` is chosen as:
  - `pfs*:/` (normalized gamelocation) when `source_mode` is `pfs`.
  - `smb:/POPS/` when device page is `SMB/MMCE`.
  - `mass:/POPS/` otherwise.

**Prefix rules**
- `BuildPopstarterBootString(...)` sets prefixes as:
  - HDD (`pfs`) → **no prefix**
  - SMB (`smb`) → `SB.`
  - MASS/MMCE/USB → `XX.`

**ELF loader argv handoff**
- Lua passes the boot string as the first extra argument to `System.loadELF(...)`.
- The ELF loader injects the resolved POPStarter path as `argv[0]`, shifting extras to `argv[1]`, `argv[2]`.
- **POPStarter’s own argv parsing is not in this repo** and remains **TODO: verify**.

## 2) Documentation inventory and status

| File | Launch/device claims | Status | Action |
| --- | --- | --- | --- |
| `README.md` | Links to canonical launch pipeline + notes POPStarter arg parsing not in repo. | VERIFIED | Keep canonical references. |
| `docs/LAUNCH_PIPELINE.md` | Canonical device rules, POPS roots, argv handoff, TODO for POPStarter parsing. | VERIFIED | Canonical reference. |
| `docs/DEBUGGING.md` | Launch log checklist, argv logging references. | VERIFIED | Keep; no conflicting rules. |
| `docs/ARCHITECTURE.md` | Defers launch rules to `docs/LAUNCH_PIPELINE.md`. | VERIFIED | Updated to avoid conflicting launch rules. |
| `docs/RUNTIME_LAYOUT.md` | Runtime asset layout only; does not define POPStarter rules. | UNSPECIFIED | No change needed. |
| `docs/SANITY_CHECK_REPORT.md` | Reports current vs expected launch rules. | VERIFIED | Keep as audit context. |
| `docs/index.md` | Legacy Enceladus content (includes non-POPSLoader details). | STALE/CONTRADICTS | Deprecated banner added; refer to README/LAUNCH_PIPELINE. |
| `truth_sheet.md` | Legacy audit notes with outdated layout statements. | STALE/CONTRADICTS | Deprecated banner added; refer to canonical docs. |
| `DEVELOPMENT.md` | Build instructions only; no launch rules. | UNSPECIFIED | No change needed. |
| `CONTRIBUTING.md` | Contribution workflow; removed link to deprecated `docs/index.md`. | VERIFIED | Updated reference. |
| `bin/README.md` | Runtime asset placement; no launch rules. | UNSPECIFIED | No change needed. |
| `AGENTS.md` / `agents.md` | Contributor guidance; no launch rules. | UNSPECIFIED | No change needed. |

## 3) Canonical references

- Launch behavior, device rules, and POPStarter handoff: `docs/LAUNCH_PIPELINE.md`.
- Runtime asset layout: `docs/RUNTIME_LAYOUT.md`.
- Debug logging and launch issue triage: `docs/DEBUGGING.md`.
