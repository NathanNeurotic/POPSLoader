# AGENTS START HERE

## Purpose

This repository has one urgent unresolved objective:

- Resolve `D-10`: HDD-backed `POPSTARTER.ELF` still black-screens.

This file is a handoff for a cloud agent. It is intentionally informational only.
It describes the current situation, verified constraints, known symptoms, and what has already been tried without resolving `D-10`.

Detailed per-artifact chronology lives in `QA_REGRESSION_MATRIX.md` and `DECISIONS.md`.
This file is the summary handoff, not the full run ledger.

Do not treat any prior experiment as a presumed answer.

## Hard Constraints

- Do not break existing and working architecture or functionality.
- If a change must touch adjacent systems, verify no regression in working behavior.
- Preserve working launch flows unless the change is directly required for `D-10`.
- Evidence-first matters more than staying minimal for its own sake. Broader rewrites are allowed if they are justified by repository evidence and paired with regression discipline.
- Do not claim `D-10` is fixed without hardware evidence.

## Latitude

The next agent is not restricted to only new ideas.

It is acceptable to:

- retry earlier task classes if there is a concrete reason to believe the execution is now different, more complete, or no longer contaminated by another bug
- revisit earlier failed directions if later repo findings changed their meaning
- re-implement part of the loader/launch path more cleanly if that is the most defensible route to `D-10`
- replace a local subsystem if necessary, as long as working behavior is preserved or explicitly re-verified

The only hard rule is:

- do not solve `D-10` by casually regressing already-working paths

## Current Mission

Resolve only this:

- `D-10`: Boot from HDD, use HDD-backed `POPSTARTER.ELF`, launch an HDD game, and transfer successfully into POPSTARTER instead of black-screening.

## Build / Test Reality

- The user does not perform local builds.
- The user tests GitHub Actions artifacts only.
- Any runtime change must therefore be suitable for CI artifact production and hardware verification from that artifact.

## Current Verified State

From repository state and recorded hardware outcomes:

- `D-10` is still failing.
- `D-14` is also failing.
- `D-15` is restored and passes on hardware.
- `D-12` HDD startup/Profile lookup issue was later restored and passes on hardware.
- `D-16` USB first-entry backend discovery passes on hardware.
- `U-05` OSDSYS exit passes.
- `U-10` BOOT.ELF after HDD initialization is still a connected concern and has shown bad behavior after HDD runtime was initialized.
- Current working inference is that `U-10` may share the same underlying handoff/state-poisoning boundary as `D-10`, but that is not yet proven and must not be treated as an automatic dependency.

## Why `D-10` Is Narrow Now

The remaining failure is strongly isolated to HDD-backed `POPSTARTER.ELF`, not HDD games in general.

Evidence:

- `D-15` passes when POPSTARTER stays off-HDD and the game is on HDD.
- `D-14` fails when the game is not on HDD but `POPSTARTER.ELF` is on HDD.

That means the common failing factor is still:

- executing `POPSTARTER.ELF` from HDD/PFS

not:

- HDD game selector alone
- HDD game mounting alone
- generic HDD page/runtime readiness alone

## Exact `D-10` Symptom

`D-10` definition:

- Boot source: HDD
- POPSTARTER source: HDD sidecar / default / cwd / configured HDD path
- Game source: HDD

Observed hardware symptom:

- black screen

Historical note:

- One 2026-03-29 artifact briefly moved the failure from black screen to:
  - launcher regained control
  - `rc=-1 (returned after 22618 ms)`
- A later GitHub artifact returned to black screen again, so that boundary was not stable.

## Connected Symptoms

These are related and should be kept in mind while investigating `D-10`:

- `D-14`: non-HDD game + HDD-backed `POPSTARTER.ELF` also black-screens.
- `U-10`: `BOOT.ELF` can behave incorrectly after HDD runtime has been initialized, even though it is reached.
- `U-10` may share the same underlying handoff/state-poisoning boundary as `D-10`, but that remains an inference rather than a proven shared root cause.
- A past state bug allowed selected Profile 1/default to still launch another profile’s canonical HDD POPSTARTER path. Current source contains normalization for that, but `D-10` still failed afterward.

## Working Behavior That Must Be Preserved

These are existing constraints, not optional niceties:

- `D-15` must stay working:
  - non-HDD POPSTARTER
  - HDD game
  - no black screen
- `D-12` must stay working:
  - HDD boot
  - Profile/startup lookup still works without requiring HDD page entry first
- `D-16` must stay working:
  - USB first-entry backend discovery
- `U-05` must stay working:
  - Exit to OSDSYS
- Shared default/Profile 1 local sidecar behavior must not regress.

## High-Risk Surfaces

These files are directly involved in the failing path or can easily regress core behavior:

- `bin/POPSLDR/system.lua`
- `bin/POPSLDR/ui.lua`
- `src/luasystem.cpp`
- `src/elf_loader/include/elf-loader.h`
- `src/elf_loader/src/elf.c`
- `src/elf_loader/src/loader/src/loader.c`
- `Makefile`
- `.github/workflows/compilation.yml`

## Current Loader / Launch Shape

The active line of work has already moved the repo to a partition-aware HDD reboot contract:

- Lua resolves HDD-backed POPSTARTER and derives partition context.
- The parent loader uses a partition-aware reboot path.
- The child loader now remounts the HDD partition onto `pfs0:` from partition context before `SifLoadElf`.
- The embedded loader uses mounted `pfs0:/...` with `SifLoadElf` for partition-aware HDD launches.
- Direct iomanX-style `pfs:` / `hdd:` loads still retain a `fileXio` fallback path when no HDD partition context is present.

Current source also includes:

- popup support for showing probe path and exec path separately
- profile-path normalization so selected Profile 1/default does not silently keep another profile’s canonical HDD path
- the current temporary HDD-backed POPSTARTER experiment bypasses partition-aware handoff entirely and executes the resolved HDD ELF with no selector or extra args, so the artifact answers only whether the ELF starts at all
- BOOT.ELF now uses standard external-launch prep with conditional reboot after HDD init, because both later no-forced-reboot BOOT.ELF lines still froze after HDD page use on hardware

`D-10` still fails after those changes.

## What Has Been Tried And Has Not Resolved `D-10`

The following avenues have already been explored and did not resolve the HDD-backed POPSTARTER black screen:

- EE-side HDD direct-load workaround in `src/elf_loader/src/elf.c`
- Memory Card staging fallback for HDD-backed POPSTARTER
- stripped-handoff experiments in `bin/POPSLDR/system.lua`
- Lua-side CWD / selector / keep-slot variations
- HDD init-state sharing / short-circuit changes
- clearing loader-side automatic post-load exec-slot preserve
- forced `reboot_iop = 1`
- direct `hdd0:PART:pfsN:/POPSTARTER.ELF` preference
- mounted-`pfs0:` embedded-loader handoff
- source-context and exact-boot-mount reconstruction work
- broader partition-aware reboot-contract rewrite
- child-loader `fileXio` experiments
- parent-side embedded-loader jump contract restoration

Important nuance:

- One earlier direct-path experiment was contaminated by a malformed direct HDD alias builder that omitted the colon after `pfsN`. That specific direct-path result was not a clean control.

## Important Historical Inference Boundaries

These are evidence-backed conclusions from the repo and recorded runs:

- The remaining failure is not adequately explained by HDD game selection alone.
- The remaining failure is not adequately explained by USB/HDD backend discovery alone.
- The remaining failure is not adequately explained by Lua-side HDD pre-mount/CWD handling alone.
- The remaining failure is not adequately explained by simply choosing `pfs` vs `pfsN` path spelling alone.
- Do not assume POPSTARTER needs slot preservation, launch CWD, partition context, or other carried runtime state after exec. Current short-term repo goal is narrower: successfully launch HDD-backed `POPSTARTER.ELF` at all; restore selector/`argv[0]` behavior only after that boundary moves.

## Profile / Settings Caveat

Historically, selected profile state and stored `PLDR.POPSTARTER_PATH` could drift apart:

- the menu could say Profile 1/default
- but the effective POPSTARTER path could still be another profile’s canonical HDD path

Current source includes normalization intended to prevent that mismatch from silently surviving into launch/save/probe. `D-10` still failed afterward, but any new investigation should still treat effective POPSTARTER path authority as a real concern, not assume menu profile text alone proves the active path.

## Documentation / Evidence Discipline

When updating status after changes:

- keep `README.md`, `STATE.md`, `ROADMAP.md`, `DECISIONS.md`, and `QA_REGRESSION_MATRIX.md` synchronized
- keep `QA_REGRESSION_MATRIX.md` as the detailed run ledger and keep the other docs at summary level
- record hardware results explicitly
- mark anything not hardware-verified as `Unknown (verify on hardware)`

When making meaningful code changes during `D-10` work:

- update the documentation set in the same change, not later
- remove stale claims that no longer match the active source
- keep the recorded narrative accurate enough that another agent can resume from the repository alone

## Summary For The Next Agent

This is not a generic HDD-game bug anymore.

This is a narrow HDD-backed `POPSTARTER.ELF` execution problem with these constraints:

- preserve `D-15`
- preserve `D-12`
- preserve `D-16`
- preserve `U-05`
- do not regress shared Profile 1/default local sidecar behavior

The repo has already explored many launch-condition permutations.
The remaining work must be evidence-based and must respect the existing working architecture while resolving `D-10`.
