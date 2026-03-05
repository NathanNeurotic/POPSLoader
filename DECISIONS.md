Last updated: 2026-03-05

# DECISIONS

## Decision log format
For each entry, record:
- **Date** (`YYYY-MM-DD`)
- **Decision**
- **Rationale**
- **Implications**

## Decision log

### 2026-03-05 — Settings persist on confirm/leave Settings/Profile
- **Decision:** Stage settings edits in UI state, then persist on Settings/Profile exit/confirm via `SaveSettingsAtomic()`.
- **Rationale:** Current UI flow marks changes dirty while navigating and commits in `queue_exit`, avoiding repeated writes during each adjustment.
- **Implications:** UI can be responsive during selection changes; persistence behavior must remain explicit and testable across restarts.

### 2026-03-05 — Mount-driver identity is authoritative for MX4SIO vs USB
- **Decision:** Classify mass roots by mount-driver identity (`getMassMountDriver`/driver classifier), with `sdc`/`mx4sio` indicating MX4SIO.
- **Rationale:** Current Lua/native pipeline already separates lists using driver identity; path-shape/device-name guessing is less reliable.
- **Implications:** Any future storage UI/backend changes must preserve this authority chain and avoid heuristic-only classification.

### 2026-03-05 — No debug/logging additions in production by default
- **Decision:** Keep production paths free of new debug/logging unless explicitly requested by task scope.
- **Rationale:** Project guidance prioritizes minimal noise and performance-sensitive PS2 runtime behavior.
- **Implications:** Diagnostics should be temporary, scoped, and removable; PRs adding logs require explicit justification.

## TODO Decisions (planned, not yet implemented)
- **ART asset strategy:** decide source of truth, cache policy, and fallback precedence.
- **Packaging policy:** finalize transition from `POPS/*.tm2` to `PATCH5.bin` in CI/release artifacts.
- **Network BDMA policy:** define SMB/iLink/UDPBD mode behavior, fallback order, and failure handling constraints.
