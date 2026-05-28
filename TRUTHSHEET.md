Last updated: 2026-05-28 (post-BETA-10-5; PR #470 LAUNCH_ARGS, PR #472 MX4SIO classification, PR #473 hotfix merged)

# TRUTHSHEET

## Purpose
Non-negotiable behavioral invariants that changes must preserve unless an explicit migration is planned.

## Truths

### Truth 1: Boot/runtime Lua is embedded-only
- Scope: `src/luaplayer.cpp`, `etc/boot.lua`, `Makefile`.
- Rationale: deterministic startup and no dependency on external Lua script files.
- Verification: embedded searcher is installed, filesystem Lua loaders are disabled, and required runtime Lua blobs are embedded.

### Truth 2: Settings persistence is transactional and per-device (with HDD exception)
- Scope: `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua`.
- Rationale: avoid immediate writes while navigating, keep save/apply failure handling explicit, and let a POPSLoader install carry its own settings (not always to Memory Card) — except where the underlying IRX driver makes that infeasible.
- Verification: edits stage in drafts; `CommitSettingsChanges` runs on confirm/leave; `PLDR.SETTINGS_PATH` is resolved at load time -- `APP_DIR_LOCAL/.pldrs` sidecar preferred for USB / MX4SIO / MMCE installs, with `mc0:/POPSTARTER/.pldrs` as fallback. Save writes go to whichever was loaded.
- **HDD installs deliberately fall back to `mc0:/POPSTARTER/.pldrs`** (PR #466, 2026-05-27). The bundled `ps2hdd-osd.irx` driver has documented read-write limitations confirmed on hardware (Nuno 2026-05-27 reproduced the failure on the boot.lua-normalized `pfs1:/...` path). HDD installs writing to MC is by design until an `ps2hdd-osd.irx` → `ps2hdd.irx` swap can be hardware-verified without regressing D-10 (branch `claude/hdd-rw-probe` exists; not landed).

### Truth 3: USB vs MX4SIO identity comes from ioctl driver name; mx4sio_bd loads conditionally
- Scope: `bin/POPSLDR/system.lua`, `src/luasystem.cpp`.
- Rationale: root-name/path heuristics are insufficient because `mass:/`, `mass0:/`, ..., `mass7:/`, `mx4sio:/`, and `usb:/` are all volatile — the same path can be either USB or MX4SIO depending on hotplug + IRX load order.
- Maintainer rule (2026-05-28): "If ioctl/devctl is ANYTHING OTHER THAN `sdc` or `mx4`, and it's a mass device, then it is USB. If a mass device is `sdc`/`mx4` on ioctl/devctl, then it must be MX4SIO." "mx4sio will need the usb drivers to activate before it with it. USB will never need MX4SIO drivers." "MX4SIO should only init on startup if it came from `mx4sio:/` or `mass` with `sdc` devctl."
- Verification: classification uses `System.getMassMountDriver`; `mx4`/`sdc` classify as MX4SIO. PR #472 + refinement commit `7b587fe`: `classify_mass_boot` loads `usbmass_bd` first, probes ioctl; if ioctl returns empty and the mass slot exists, loads `mx4sio_bd` and re-probes (with sleep for the double-ping). `AutoInitStartupBackends` only loads `mx4sio_bd` when an ambiguous mass slot exists or `mx4sio:/` is the boot prefix. Pure USB boots never load `mx4sio_bd`. C-layer `lua_mx4sio_init` calls `EnsureUsbMass()` first so the dependency order is unviolatable from Lua.

### Truth 4: Startup backend auto-init is path-driven
- Scope: `bin/POPSLDR/system.lua`.
- Rationale: boot source alone is not enough; configured POPSTARTER/DKWDRV/profile paths can also require backend init before the first page visit.
- Verification: startup target collection uses boot paths plus configured executable/profile paths, then initializes USB/MMCE/MX4SIO/HDD as needed.

### Truth 5: Runtime device selection is not hard-locked
- Scope: `bin/POPSLDR/ui.lua`.
- Rationale: the old per-session device lock system was intentionally removed.
- Verification: `canEnterDevice()` always returns `true`, and `setDeviceLock()` is a no-op.

### Truth 6: Probe/retry loops are bounded
- Scope: `bin/POPSLDR/system.lua`, `bin/POPSLDR/ui.lua`.
- Rationale: prevent frame stalls/hangs and unpredictable behavior.
- Verification: backend probe loops and progress/report loops have finite attempt counts and fixed phases.

### Truth 7: Launch failure feedback must be explicit
- Scope: `bin/POPSLDR/ui.lua`, `bin/POPSLDR/system.lua`.
- Rationale: launcher must not fail silently on missing executables or returned launch handoffs.
- Verification: missing POPStarter/DKWDRV paths and launch return failures produce user-visible notifications/screens.

### Truth 8: Release package manifest is strict
- Scope: `.github/workflows/compilation.yml`.
- Rationale: prevent accidental release payload drift.
- Verification: CI enforces the exact expected ZIP set and rejects legacy `POPS/*.tm2` payload entries.

## Current Not-Implemented Truths
- `HDD (exFAT)` main-menu path is intentionally not implemented and must continue to report that status until feature work lands.
- `SMB (v1)` main-menu path is intentionally not implemented and must continue to report that status until feature work lands.

## Current Hardware Status Markers

**Preservation contracts** (BETA-10-5 hardware-confirmed; must not regress):
- `D-10` (HDD POPSTARTER + HDD game): **PASS** as of 2026-05-22 hardware (B2 fix at commit `4ae6679`), reconfirmed 2026-05-28 on the BETA-10-5 release artifact (Nuno).
- `D-14` (HDD POPSTARTER + non-HDD game): **PASS** as of 2026-05-22 hardware. Same partition-aware route as D-10.
- `D-15` (non-HDD POPSTARTER + HDD game): **PASS** as of 2026-05-22 hardware.
- `DKWDRV from MC`: **PASS** as of 2026-05-25 hardware (Nuno), reconfirmed 2026-05-28.
- `BOOT.ELF from USB-booted POPSLoader` (L-07): **PASS** 2026-05-28 (Nuno on BETA-10-5 release artifact). V2 working route at `d23520a`.
- Settings save on HDD-installed POPSLoader → `mc0:/POPSTARTER/.pldrs`: **PASS** 2026-05-28 (Nuno). By design per PR #466.
- Settings save on USB and MC sidecars: **PASS** 2026-05-27 (Nuno). Per-device `APP_DIR/.pldrs`.

**Known-broken accepted for BETA-10-5** (documented workarounds):
- `DKWDRV from HDD custom path`: **FAIL** 2026-05-25 (Nuno on PR #460 artifact). Pragmatic acceptance per Nuno + maintainer 2026-05-27. Workaround: configure DKWDRV path to MC.
- `BOOT.ELF from HDD-booted POPSLoader` (U-10): **FAIL** 2026-05-27 (Nuno on PR #464 F4 artifact). Long-standing; PR #463 diagnostic colors localized the hang to `SifIopReset` itself. Workaround: Exit → OSDSYS or reboot.

**Other:**
- `POPSLoader from wLaunchELF`: **PASS** for common cases 2026-05-28; one latent failure mode (wLE → USB POPSLoader → BOOT.ELF) reported by Nuno 2026-05-27. Code analysis says it takes the same BOOT.ELF route as working autoboot/OSDSYS cases, so likely always-broken/latent rather than a regression. Not enumerated as known-broken pending a clearer repro.
- `U-06` (PAL/NTSC menu asset proportions): Unknown, still needs hardware confirmation.

**Post-release PR work** (CI-verified, hardware-unverified except where noted in `QA_REGRESSION_MATRIX.md`):
- PR #470 (LAUNCH_ARGS): `Unknown (verify on hardware)`.
- PR #472 (MX4SIO classification): `Unknown (verify on hardware)`. Maintainer's MX4SIO unit was the trigger for filing; hardware verification of the fix is the next step.
- PR #473 (HOTFIX): `Unknown (verify on hardware)`. Crash reproduced by Nathan's tester 2026-05-28; fix verification is the next rolling-release test cycle.
- PR #471 (Layer C mmceman defer): DRAFT, `Unknown (verify on hardware)`. Test plan must cover pad input survival on USB / HDD / MC boots.

## Add-New-Truth Template
```markdown
Truth: <short invariant>
Scope: <components/files>
Rationale: <why this must remain true>
Verification: <test/check/manual steps>
Owner: <team/person>
Date added: YYYY-MM-DD
Related issue/decision: <id or link>
```
