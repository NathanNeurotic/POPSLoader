Last updated: 2026-03-05

# TRUTHSHEET

## Purpose
Non-negotiable invariants that changes must preserve.

## Must never break
- [ ] POPSLoader must continue to boot, render UI, and reach device pages without startup regressions.
- [ ] POPStarter launch path resolution must remain functional for supported device modes.
- [ ] Device page game scans must remain bounded and deterministic.
- [ ] Boot/launch and device detection changes must be explicit and task-scoped.

## Identity / detection rules
- [ ] MX4SIO classification is based on mass mount driver identity containing `sdc` (`system.lua` mass backend classification).
- [ ] USB lists must exclude roots classified as MX4SIO, and MX4SIO lists must exclude non-MX4 roots.
- [ ] Device classification is recomputed from current mass-root state before building page lists.
- [ ] MMCE slot detection is limited to `mmce0:/` and `mmce1:/` probing.
- [ ] Boot device lock behavior must remain consistent with detected boot source and lock rules.

## Performance invariants
- [ ] Mass root probing remains bounded (`mass:/` through `mass9:/`; no unbounded scans).
- [ ] Retry/refresh paths must remain bounded (no infinite retry loops for backend detection).
- [ ] Game list construction should scan only relevant `POPS/` roots for the selected backend.
- [ ] Avoid adding expensive per-frame backend probing.

## Compatibility invariants
- [ ] Preserve path conventions used by existing launch policies (`mass:/`, `mmce*:/`, `mx4sio*:/`, `pfs:`).
- [ ] Preserve packaged file expectations used by CI release assembly.
- [ ] Keep Lua-facing `System.*` API behavior stable unless a documented migration is provided.
- [ ] Maintain deterministic behavior for identical storage layout and settings.

## Add New Truth Template
- [ ] Add entries with this template:

```markdown
Truth: <short invariant>
Scope: <components/files>
Rationale: <why this is non-negotiable>
Verification: <tests/checks/manual steps>
Owner: TODO
Date added: YYYY-MM-DD
Related ADR/Issue: TODO
```
