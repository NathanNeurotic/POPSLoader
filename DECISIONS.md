# DECISIONS

This file tracks project decisions so future changes don’t accidentally reverse them.

Format:
- Date: YYYY-MM-DD
- Decision:
- Rationale:
- Implications:

---

## 2026-03-05 — Settings persistence is commit-on-exit only
- Decision: Settings are applied/saved only when confirming or leaving the Settings page; not while adjusting controls.
- Rationale: Prevent partial/accidental persistence and mismatched runtime/UI states.
- Implications:
  - Any settings UI work must preserve this behavior.
  - UI labels must reflect persisted/runtime state on boot and after saving.

## 2026-03-05 — Mount-driver identity is authoritative for MX4SIO vs USB
- Decision: Classify mounted roots by querying the mount driver name from the mounted root; do not guess from slot indices.
- Rationale: Avoid false positives and regression from backend list scanning/heuristics.
- Implications:
  - Unknown/nil/empty driver identity excludes the mount from both pages.
  - “sdc” (case-insensitive) indicates MX4SIO.

## 2026-03-05 — Avoid debug/logging in production
- Decision: Do not add debug logging unless explicitly requested; prefer smaller footprint.
- Rationale: ELF size and runtime performance.
- Implications:
  - Remove legacy debug logs where safe during optimization passes.

## TODO decisions (fill once implemented)
- TODO: ART asset strategy (embedded vs shipped files)
- TODO: Packaging decision: PATCH5.bin replaces POPS/*.tm2 in release artifacts
- TODO: Network BDMA decisions (SMB/iLink/UDPBD behaviors and fallbacks)
