# ARCHITECTURE

This document describes the intended high-level architecture. It should not be treated as a perfect description of current code if the implementation differs.

## High-level components (conceptual)
- UI layer
  - Renders menus/pages
  - Handles input
  - Shows user-facing labels, icons, and notifications
- System/Backend layer
  - Device/backends initialization (USB/MX4SIO/MMCE/HDD/etc.)
  - BDMA mode selection and initialization
  - Filesystem probing and mount identity queries
- Settings layer
  - Loads settings on boot
  - Applies settings to runtime
  - Saves settings only on confirm/leave Settings page
- Packaging/Assets
  - Embedded or shipped assets (icons/artwork/binaries)
  - Release artifacts layout controlled by CI workflow

## Data flows (conceptual)
### Boot
1. Initialize core system modules
2. Load settings (if present)
3. Apply settings to runtime
4. Enter UI main flow

### Settings edit
1. User changes selection (no immediate persistence)
2. User confirms/leaves Settings page
3. Save settings atomically
4. Update UI labels/state

### Device identity (conceptual rule)
- Classify mounted roots by querying the mount driver name from the mounted root itself (not by guessing slot index).
- If driver contains “sdc” (case-insensitive) => MX4SIO
- If driver is known and not “sdc” => USB
- If driver unknown/nil/empty => exclude from both pages

## Non-goals
- No unbounded scanning/retry loops.
- No adding debug logging in production without explicit request.
- No “smart guessing” for backend identity when driver identity is unknown.

## Unknowns / Verify
- TODO: Confirm exact module/file boundaries in this repo (e.g., which files own UI vs system vs settings).
- TODO: Confirm settings storage format and filenames (document here once verified).
- TODO: Confirm final asset strategy post-ART integration (what stays embedded vs shipped).
