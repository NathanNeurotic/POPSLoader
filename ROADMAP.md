# POPSLoader Roadmap

This document outlines the remaining development milestones for POPSLoader.

The project is currently in a stabilization and feature-completion phase.

---

# Milestone 1 — Core Stability

Focus: resolve remaining hardware quirks and configuration reliability.

## Tasks

- MX4SIO first-entry fix
  - init → mount attempt → 1s wait → second mount attempt

- Settings load correctly on boot
  - BDMA mode labels reflect actual runtime configuration

- Support `mc?:/` path alias
  - auto check `mc0:/`
  - fallback to `mc1:/`

- Graceful failure when required executables missing
  - POPSTARTER.ELF
  - DKWDRV.ELF

---

# Milestone 2 — Configuration Improvements

Focus: making settings flexible and user editable.

## Tasks

- Editable POPStarter Path/Profile
  - L1 opens on-screen keyboard

- Editable DKWDRV Path
  - R1 opens on-screen keyboard

- Settings save progress indicator
  - Visual progress bar during save

---

# Milestone 3 — UI Improvements

Focus: improving usability and presentation.

## Tasks

- Implement ART system
  - Port from previous version
  - Ensure fallback when artwork missing

- Global Hide UI toggle
  - `[select.png] Hide UI`
  - Icons remain visible
  - Text hidden except on:
    - Splash
    - Credits
    - Settings
    - Games list

- Finalize Settings page layout
  - Correct block grouping
  - Proper arrow alignment
  - Prevent text overlap

---

# Milestone 4 — Network / Backend Expansion

Focus: expanding supported BDMA backends.

## Tasks

- SMB BDMA mode

- iLink BDMA mode

- UDPBD BDMA mode

UDPBD is expected to be the most complex backend due to network handling requirements.

---

# Milestone 5 — Packaging and Distribution

Focus: release optimization and artifact cleanup.

## Tasks

- Replace distributed assets
  - Remove `POPS/*.tm2`
  - Package `POPS/PATCH5.bin`

- Update GitHub Actions release workflow

---

# Milestone 6 — Performance Optimization

Focus: reducing footprint and improving runtime performance.

## Tasks

- Remove debug/logging output
- Reduce executable size
- Optimize settings save routines
- Reduce redundant filesystem scans

---

# Milestone 7 — Testing and Validation

Focus: ensuring stability across supported hardware configurations.

## Test Matrix

- USB
- MX4SIO
- MMCE
- HDD

## Additional coverage

- All BDMA modes
- mc0 / mc1 detection
- Settings persistence
- ART asset loading
- POPStarter launch reliability

---

# Long-Term Ideas

These items are not required for the current release but may be considered later.

- Expanded artwork caching
- Network asset streaming
- Additional UI themes
