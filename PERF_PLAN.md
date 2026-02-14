# PERF_PLAN.md — Structural Performance Plan

This document governs performance work in POPSLoader.

Performance improvements will be based on structural reasoning and operation reduction, not millisecond timing.

The maintainer performs real hardware testing. Codex does not.

---

# 1) Objective

Users report general slowness across:

- UI page switching
- Device switching
- Game list loading
- Launch pipeline

The goal is to reduce unnecessary work and blocking operations.

---

# 2) Performance Philosophy

We optimize by reducing:

- Filesystem enumeration calls
- O(N) loops triggered by UI transitions
- Full list rebuilds on every page enter
- Repeated sorting/filtering
- Synchronous image loading in navigation paths

We do NOT rely on timing precision.

We reason about structural work instead.

---

# 3) Phase 0 — Static Structural Mapping (No Code Changes)

Produce a detailed report mapping:

- Page switch call path
- Device switch call path
- Game list build path
- Selection change path
- Launch path

For each path identify:

- Lua functions involved
- C/C++ bindings invoked
- Calls to System.listDirectory
- Any O(N) loops
- Whether work is per-frame or per-event
- Existing caching mechanisms

Deliverable:
PERF_MAP_REPORT.md

No code changes.

---

# 4) Phase 1 — Operation Analysis

After mapping:

For each major path, determine:

- How many directory scans occur
- Whether scans repeat unnecessarily
- Whether list building repeats per navigation
- Whether sorting runs repeatedly
- Whether images are loaded synchronously

Focus on eliminating repeated work.

---

# 5) Phase 2 — Minimal Structural Fixes

Allowed optimizations:

- Cache directory listings with explicit invalidation
- Avoid rebuilding full lists when not needed
- Move expensive work from page-enter to lazy execution
- Ensure sorting happens once per dataset
- Ensure image loading only affects visible items

Each fix must:

- Be minimal
- Not change boot order
- Not modify device detection semantics
- Not introduce new dependencies

---

# 6) Caching Rules

If caching is introduced:

- Define invalidation triggers
- Do not create stale list scenarios
- Do not rely on timing-based invalidation
- Keep memory footprint reasonable

---

# 7) Forbidden Actions

- Architecture rewrites
- Boot flow modifications
- Changing IOP init order
- Hardcoding device paths
- Large refactors
- Guess-based micro-optimizations

---

# 8) Validation

The maintainer validates on real hardware.

Performance acceptance is based on:

- Perceived speed improvement
- Fewer visible stalls
- Faster page transitions
- Faster list population
- No regressions across devices

---

This document governs structural performance work.
