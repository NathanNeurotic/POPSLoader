# AGENTS.md — POPSLoader Codex Work Contract

This document defines how contributors and AI agents (including Codex) must operate in this repository.

This project targets PlayStation 2 (PS2) homebrew and must remain safe for real hardware across MC/USB/MMCE/MX4SIO/HDD/PFS boot paths.

Performance (“speed”) is currently the highest priority, but boot safety and cross-device stability are non-negotiable.

All performance work must be structural and conservative. The maintainer validates behavior on real PS2 hardware.

---

# 1) Performance Contract (MANDATORY FOR AI WORK)

## Primary Objective

Reduce perceived latency in:

- UI page transitions
- Device switching
- Game list building (USB/MMCE/MX4SIO/HDD)
- Game launch pipeline (select → POPStarter handoff)

Performance improvements must focus on eliminating unnecessary work and blocking operations.

Millisecond-level benchmarking is not required.

---

## Non-Negotiables

- No speculative refactors.
- No architectural rewrites unless explicitly requested.
- No behavior changes without documentation.
- Preserve compatibility across all boot variants.
- Avoid allocations inside hot loops when practical.
- Avoid excessive filesystem operations during UI interaction.
- Prefer small, reviewable PRs over sweeping changes.

If you cannot justify reduced work (fewer scans, fewer rebuilds, less blocking I/O), you cannot claim improvement.

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

2. Analyze  
   Determine what work is happening and what can be eliminated:
   - repeated directory scans (System.listDirectory)
   - O(N) loops on transitions
   - rebuilds triggered per page enter or per input
   - repeated sorting/filtering
   - synchronous cover/art loads in navigation paths
   - systems running that are not required for the current path

3. Fix  
   Implement the smallest safe change that reduces unnecessary work.

4. Verify  
   Provide reproducible steps for the maintainer to validate on real hardware.
   Describe what should feel faster and what behavior must remain identical.

Skipping steps is not allowed.

---

## Instrumentation Rules (Optional)

Instrumentation is allowed but must be:

- disabled by default
- low overhead
- used to count operations (e.g., number of directory scans)
- not required to produce millisecond deltas

No new dependencies.

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

# 2) Testing Responsibility Boundary

Codex and CI cannot validate on real PS2 hardware.

The maintainer validates on real hardware.

PRs must include:

- What changed
- Why it reduces unnecessary work
- How to test on hardware
- What should feel faster
- Rollback instructions

---

# 3) Project Architecture Overview

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

# 4) Boot Flow (EE Side)

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

# 5) POPStarter Constraints

POPStarter behavior is determined by its own naming/argv semantics (e.g., argv[0] when launched).

POPStarter itself is not modified by this project.

Implications for POPSLoader:

- The launch pipeline should do the minimum required preparation and hand off immediately.
- Do not add optional work (device scans, list rebuilds, art loads, cache writes) to the launch path.
- Do not assume mounts or loaded modules persist after handoff.
- Keep launch logic minimal and stable.

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
- Do not remove systems without producing an UNUSED_SYSTEMS_REPORT first.

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
- mass0:
- mmce0:
- mx4sio:
- pfs0:

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
- Why it reduces unnecessary work
- Hardware test instructions
- Rollback instructions
- Caching invalidation strategy (if applicable)

Large refactors without prior mapping and analysis are not allowed.

---

This document governs AI agent behavior and must be followed strictly.
