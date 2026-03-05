# RULES

These rules exist to prevent regressions and keep changes reviewable.

## Scope discipline
- Make changes as small and local as possible.
- One objective per PR whenever feasible.
- Avoid “drive-by refactors” mixed with feature work.
- Prefer deterministic, bounded logic (no unbounded scans, no infinite retries).

## Do-not-break list (non-negotiable)
- POPStarter launching flow must continue to work.
- BDMA mode detection/selection/persistence must not regress.
- MX4SIO vs USB separation rules must remain correct (mount driver identity remains authoritative).
- Settings must not “half apply” during adjustments; apply/persist only on confirm/leave Settings page.
- No added debug logging in release builds (unless explicitly requested).

## Persistence rules
- Settings load on boot if present.
- Settings save only when confirming/leaving Settings page (not while adjusting controls).
- UI labels must reflect persisted/runtime state (no “fat32 label while exFAT is active” situations).

## UI rules
- No layout jitter from dynamic string lengths (icons/arrows must not shift based on preceding text length).
- Keep PS2-safe performance: avoid heavy per-frame allocations and repeated filesystem scans.
- Any new UI toggle must not affect excluded pages unless specified.

## Performance and size
- Avoid new large embedded assets unless justified.
- Prefer reusing assets and caching where safe.
- Remove/avoid verbose logs and debug strings in production.

## Testing expectations (minimum)
- Verify on at least one real-hardware path for each affected backend:
  - USB
  - MX4SIO
  - MMCE
  - HDD (if applicable)
- Validate settings persistence across reboot.
- Validate “missing file” handling (missing POPSTARTER.ELF / DKWDRV.ELF) is graceful.

## PR hygiene
- Include: summary, diffstat, and a short test plan.
- Mention any behavior changes explicitly.
- If behavior is unchanged, say so explicitly.
