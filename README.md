## Requirements:
* <device>:/POPS/or hdd:/__common/POPS/ <a href="https://github.com/AnimMouse/POPS-binaries/releases/">IOPRP252.IMG , POPS.ELF, POPS.PAK, POPS_IOX.PAK</a>
* <device>:/POPS/ or hdd:/__.POPS/<a href="https://tinyurl.com/PS1PRESERVATION"><Title>.VCD</a> - <a href="https://web.archive.org/web/20250208180431/https://cdn.discordapp.com/attachments/1190221790925033542/1337432406419968101/POPS-VCD-Manager.7z?ex=67a8153d&is=67a6c3bd&hm=d72ab93151232edc0a6756989735a97bacd71bf16b8119bc1e8a96fe9880430b&">bin/cue converted for POPStarter</a>
* PS1_POPSLOADER/<content> or APPS/PS1_POPSLOADER/<content><br>
* <a href="https://www.github.com/NathanNeurotic/Enceladus/releases">![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/nathanneurotic/enceladus/total?style=plastic&logo=playstation%202&logoColor=yellow&logoSize=auto&label=Downloads&labelColor=navy&color=blue%20&link=https%3A%2F%2Fgithub.com%2FNathanNeurotic%2FEnceladus%2Freleases%2Ftag%2FMMCE)</a>
* <a href="https://youtu.be/CPQia4Nd88Y">Video Preview Here</a>

<a href=""><img width="1536" height="1024" alt="POPSLoader" src="https://github.com/user-attachments/assets/d7b54ca5-f088-4f82-8819-d8621a6b2fda" /></a><br>
<br>
# POPSLoader



POPSLoader is an open-source launcher for POPStarter that is scripted in Lua and built on top of the Enceladus runtime. This repository packages the launcher (POPSLOADER.ELF), runtime Lua scripts, textures, and required modules into a single, portable bundle intended for PlayStation 2 environments such as MMCE and USB mass storage.

POPSLoader was created by [El_isra](https://www.github.com/israpps), and this repository is a fork of his work. Endless thanks to Isra for his contributions and open-source projects gifted to the community.

> **Project lineage**: This project is derived from the [Enceladus](https://github.com/DanielSant0s/Enceladus) Lua environment and retains its GPLv3 licensing.

## Thanks
- israpps/[El_isra](https://www.github.com/israpps/Enceladus/tree/popstarter) for POPSLoader and BDMA Modules.
- [Daniel Santos](https://github.com/DanielSant0s) for [Enceladus](https://github.com/DanielSant0s/Enceladus).


# LICENSE
SInce this project is based on enceladus, it retains the **GNU General public license v3.0**


# ROAD MAP/GOALS/DREAMS/SEEKING
POPSLoader – Master TODO / Hardening List

Loading / Feedback
- Loading / progress bars for:
  - Boot
  - Page transitions
  - Saving settings
  - Game launch
- Distinguish “working” vs “stalled” visually
- Show activity during slow I/O (USB / MMCE / MX4SIO)
- Visible feedback during long POPS launches (no “looks frozen” state)
- Optional early pre-boot indicator (must NOT affect splash timing or audio)

Device Logic (CRITICAL)
- REMOVE entire page/device locking system
- No device may block another, ever
- Deterministic device probe order:
  1. Boot device
  2. Explicit known mounts
  3. Cached last-known root
  4. Fallback scan
  5. MX4SIO LAST and ONLY if unresolved
- MX4SIO must never shadow USB or MMCE
- Detect device presence without waking dormant buses
- Cache positive detections per session
- Never probe devices unnecessarily per frame

Path & Mount Resolution
- Single authoritative root-resolution path
- No hardcoded device paths anywhere
- Resolve once, reuse everywhere
- Relative asset paths must survive device switching
- Handle delayed mount readiness (retry w/ feedback)
- Cache resolved root, but always re-validate before use

Hotplug / Device Removal Handling (OPL-style)
- Detect device removal (USB / MMCE / MX4SIO / HDD where applicable)
- If device disappears:
  - Invalidate its mount/root immediately
  - Remove its game list from UI
  - Disable only that page’s actions
  - Show small “Device removed” notice
- If device is reinserted:
  - Re-detect and re-mount cleanly
  - Rebuild list once (no repeated rescans)
  - Restore UI state without scene jumps
- Abort active operations safely on removal:
  - Scan / save / launch → cancel + message
  - No black screens, no stuck loading bars
- Never keep stale file handles
- Lightweight, throttled “device present” heartbeat check

State Machine / Concurrency Safety
- Formalize busy states:
  - Scanning
  - Saving
  - Mounting
  - Launching
- Block only conflicting actions (not whole UI)
- Every busy state must have:
  - Enter/exit path
  - Cancel path
  - Timeout path
  - UI indicator

Performance & Stability
- Eliminate redundant directory scans
- Avoid repeated probes per frame/tick
- Chunk heavy I/O (N items per tick)
- Throttle expensive calls
- Soft timeouts for all device reads
- Zero black-screen failure modes
- Input must always remain responsive

Safe Cancel & Rollback
- Cancel must be safe everywhere:
  - Scan list
  - Save settings
  - Resolve root
  - Launch game
- No half-updated lists
- No partial state transitions
- UI and backend must re-sync cleanly after abort

Configuration & Persistence
- Atomic writes:
  - temp write → close → rename
- Keep last-known-good config backup
- Prevent partial writes
- Validate config on load
- Recover gracefully from corrupted configs

Cache Strategy (Lists & Art)
- Cache game lists per device root + generation
- Cache art lookups (avoid reloading every redraw)
- Invalidate caches on:
  - Device removal
  - Root change
  - Art toggle change
- Optional manual “Rescan” action (tester-friendly)

Assets & Footprint Reduction
- Remove unused images
- Remove unused sounds
- Remove debug assets
- Merge duplicate icons:
  - list.icn.bdm
  - del.icn.bdm
- Only icon.sys.<device> differs per BDMA backend
- Asset manifest to track required assets
- CI/build check for:
  - Missing referenced assets
  - Unused assets (report-only)

Code Cleanup / Debt Removal
- Remove debug-only code paths
- Remove dead / unreachable logic
- Remove legacy device guards
- Remove commented-out experiments
- Consolidate duplicated logic
- Assert “unused” truly means unreachable

UI / UX Integrity
- No UI freeze without feedback
- Navigation must always respond
- Cancel/back must always work
- Visual state must never desync from backend state
- Per-device status indicators:
  - Present
  - Scanning
  - Missing
  - Removed

Error Handling
- Clear, actionable error messages
- Fail soft, not hard
- Device failure ≠ app failure
- Per-device errors, not global failures
- Internal logging without user-facing spam

Recovery Behaviors
- If root resolution fails:
  - Retry with backoff + feedback
  - Then fall back to retry/select UI
- If list parsing fails:
  - Fail that device only
- If art fails:
  - Placeholder for that entry only

Memory & Resource Hygiene (PS2-specific)
- Free textures/art/audio when leaving pages
- No unbounded cache growth
- Avoid per-frame allocations
- No leaked handles or tables

Regression Safety
- Changes must be strictly additive or subtractive
- No new device-specific special cases
- Identical behavior across all backends unless impossible
- No silent behavior drift

Testing / Verification
- Boot from every device
- Hotplug devices during runtime
- Two-USB-device scenarios
- One confirmed game launch per device
- Stress-test slow media
- Verify MX4SIO last-probe behavior explicitly
- Confirm no regressions vs current working base

Release Readiness
- No debug output enabled
- Predictable cold-boot behavior
- Reduced size where safe
- Codebase readable and maintainable
- Safe for contributors to touch without fear
