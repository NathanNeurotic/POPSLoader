# AGENTS.md — POPSLoader Codex Work Contract

This document defines how contributors and AI agents (including Codex) must operate in this repository.

This project targets PlayStation 2 (PS2) homebrew and must remain safe for real hardware across MC/USB/MMCE/MX4SIO/HDD/PFS boot paths.

Performance (“speed”) is currently the highest priority, but boot safety and cross-device stability are non-negotiable.

---

# 1) Performance Contract (MANDATORY FOR AI WORK)

## Primary Objective

Reduce perceived and measured latency in:

- UI page transitions
- Device switching
- Game list building (USB/MMCE/MX4SIO/HDD)
- Game launch pipeline (select → handoff to POPStarter)

All improvements must be measurable.

---

## Non-Negotiables

- No speculative refactors.
- No architectural rewrites unless explicitly requested.
- No behavior changes without documentation.
- Preserve compatibility across all boot variants.
- Avoid allocations inside hot loops when practical.
- Avoid excessive filesystem operations during UI interaction.
- Prefer small, reviewable PRs over sweeping changes.

If you cannot measure improvement, you cannot claim improvement.

---

## Required Workflow (Strict Order)

Every optimization must follow this sequence:

1. Map  
   Identify exact call paths for:
   - page switch
   - device switch
   - list rebuild
   - selection change
   - launch pipeline

2. Measure  
   - Instrument only confirmed hot paths.
   - Instrumentation must be disabled by default.
   - Use low-overhead timers and buffered logging.

3. Fix  
   - Implement the smallest safe change.
   - No large refactors.

4. Verify  
   - Provide reproducible test steps.
   - Provide before/after timing deltas.
   - Explain rollback strategy.

Skipping steps is not allowed.

---

## Instrumentation Rules

- Must be disabled by default.
- Must add minimal runtime overhead.
- Must clearly label timing sections.
- Must report elapsed time in milliseconds.
- Must not introduce new dependencies.

---

## PS2 Platform Reality (Critical Context)

- I/O latency varies heavily by device.
- Filesystem enumeration is often extremely slow.
- USB devices may stall unpredictably.
- HDD/PFS environments behave differently than mass:/.
- Large allocations risk fragmentation.
- Blocking work during UI transitions creates the perception that “everything is slow.”

Any optimization must respect these constraints.

---

# 2) Project Architecture Overview

The project consists of two layers:

## Runtime (C/C++ — Enceladus)

Responsible for:
- Lua VM
- Graphics (gsKit)
- Audio
- Pad input
- System utilities
- IOP module loading
- Asset resolution

Key runtime files:
- src/main.cpp
- src/system.cpp
- src/luasystem.cpp
- src/luaHDD.cpp
- src/luaSMB.cpp
- src/graphics.cpp
- src/render.cpp
- src/sound.cpp
- src/pad.cpp

## App Layer (Lua + Assets)

Located in bin/POPSLDR/

Key files:
- system.lua — main app entry
- ui.lua — UI logic and routing
- pops_profiles.lua — POPStarter configuration logic
- IMG/images.lua — image registration
- *.irx.* — device-specific IRX files
- POPSTARTER.ELF — payload

When debugging, identify which layer is failing.

If you see a Lua error screen:
- Runtime is alive.

If you see a black screen before graphics:
- Failure occurred before or during runtime init.

---

# 3) Boot Flow (EE Side)

Primary entry: src/main.cpp

Conceptual flow:

1. Parse argv[0]
   - Determine boot_path
   - Determine app_dir

2. IOP init and module load

3. Initialize graphics and pad

4. chdir(boot_path)

5. Execute embedded etc/boot.lua

6. On Lua error → show error screen

If graphics never initialize:
- Look at early IOP init or blocking loops.

---

# 4) Asset Resolution Model

Implemented in src/system.cpp:
- ResolveAssetPath
- ResolveAssetPathTyped

Behavior:

- Absolute PS2 paths (contain “:”) are used as-is.
- Otherwise resolution attempts:
  - <app_dir><relative>
  - <app_dir>POPSLDR/<relative>
  - Typed fallbacks for IMG/IRX folders
- Fallback to current working directory paths.

For HDD/PFS boots, argv[0], boot_path, app_dir, and cwd are high-risk areas.

Never hardcode device roots.

---

# 5) POPStarter Constraints

POPStarter typically:
- Reboots the IOP
- Relies on argv[0]
- Discards launcher-loaded modules

Implications:
- Do not assume persistent mounts.
- Do not rely on preloaded IRX surviving.
- Launch path correctness is critical.

---

# 6) HDD / PFS Boot Considerations

Risks:
- Incorrect IOP reset order
- Skipping SIF initialization
- Loading USB stacks too early
- Deadlocks on certain launchers

Rules:
- Avoid mass:/ assumptions.
- Avoid blocking waits for USB when launched from HDD.
- Ensure initGraphics() is always reachable.
- Never fail silently before screen init.

---

# 7) Safe Change Rules

- Treat src/main.cpp as high risk.
- Prefer minimal changes.
- Never partially edit boot logic.
- Never hardcode device paths.
- Preserve dynamic resolution logic.

---

# 8) Build Variants

Makefile defines:
- VARIANT=mmce
- VARIANT=mx4sio
- VARIANT=hdd

Output:
- bin/POPSLOADER_<variant>.ELF

Common usage:
- make clean
- make VARIANT=mmce
- make VARIANT=mx4sio
- make VARIANT=hdd

---

# 9) Smoke Tests (Before and After Any Change)

Test boot from:
- mc0:
- mass0: (single and dual USB)
- mmce0: / mmce1:
- mx4sio:
- pfs0: (HDD partition launcher)

Confirm:
- UI appears
- Pages load
- Game lists populate
- POPStarter launches
- Return to UI works
- No black screen regressions

At minimum verify:
- No infinite loops before graphics init
- boot_path and app_dir normalize correctly
- No device-lock regressions

---

# 10) PR Requirements

Every PR must include:
- Files changed
- Why the change is safe
- How to test
- How to revert
- Measured results (if performance-related)
- Caching invalidation strategy (if applicable)

Large refactors without prior mapping and measurement are not allowed.

---

This document governs AI agent behavior and must be followed strictly.
