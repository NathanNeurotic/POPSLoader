# AGENTS

Last updated: 2026-06-18 (post-BETA-12 release)

Operational guidance and entry point for AI agents (cloud or interactive) working in this repository. This file is self-contained: it absorbs the former `AGENTS_START_HERE.md` orientation content. For current code/hardware status, behavioral invariants, preservation contracts, and the canonical known-issues list, defer to **`STATE.md`** rather than restating them here.

## Start Here / Orientation

POPSLoader is a PS2 launcher for POPStarter built on Enceladus runtime pieces, with behavior primarily orchestrated by **embedded Lua** modules (`system.lua`, `ui.lua`, `images.lua`, `pops_profiles.lua`). The Lua is bin2c'd into the EE ELF at build time, so a *runtime* Lua error (nil global, type error, **load-order** error) is invisible to `luac -p` and to CI and only surfaces on real PS2 / PCSX2.

- Released line: **BETA-12** (2026-06-18; BETA-11 was 2026-06-15).
- Dev branch: **`BETA-12-PLAY`**.
- Testers: maintainer + Nuno (primary), CosmicScale (secondary), plus **provato** and **nuno6573**. Agents cannot run hardware tests — claims of hardware verification must cite a recorded result in `QA_REGRESSION_MATRIX.md`.

> **Historical note**: Earlier entry-point docs framed D-10 (HDD POPSTARTER + HDD game) as the single urgent unresolved objective. D-10 was resolved by the B2 PFS-unmount fix at commit `4ae6679` and is now a **preservation contract, not an open blocker** (see `STATE.md > Preservation Contracts`).

### Where to look first

| File | What's there |
|---|---|
| [STATE.md](STATE.md) | **Canonical.** Current code + hardware status, behavioral invariants, preservation contracts, the single known-issues list, hardware-verification table. Start here for ground truth. |
| [QA_REGRESSION_MATRIX.md](QA_REGRESSION_MATRIX.md) | Authoritative detailed hardware/CI run ledger with per-artifact history. |
| [ROADMAP.md](ROADMAP.md) | Prioritized backlog / open work. |
| [DECISIONS.md](DECISIONS.md) | Decision log with rationale and evidence. |
| [docs/archive/](docs/archive/) | Investigation artifacts: `U10_INVESTIGATION.md`, `LAUNCH_HYGIENE.md` (launch-path architecture, V2 mimicry, Layer A/B/C), `HDD_POPSTARTER_HANDOFF.md`. |

## Source-of-Truth Rule
- Prefer claims tied to current repository files, workflow definitions, and recorded hardware outcomes in `QA_REGRESSION_MATRIX.md`.
- If a hardware/runtime claim cannot be proven from code or a recorded run result, mark it `Unknown (verify on hardware)`.
- Separate repo-verified facts from hardware-reported results in task output.
- The 2026-06 HDD/PAL/BDMA features are repo-verified and **boot on PCSX2**; provato confirmed the **HDD is RW-writable on real hardware**, but the full flows are **not yet broadly hardware-confirmed**. Describe them as "implemented / boots on PCSX2 / HDD RW confirmed on hardware (provato) / full flow validating on hardware" — never "confirmed working on hardware", and do not keep calling the shipped HDD save/`.hide` features "a probe" or "read-only".

## Scope
- Allowed: task-focused edits to requested files; documentation, tests, and narrow fixes directly tied to the active task.
- Avoid touching unrelated Lua/C/C++ files unless required by task scope.
- Preserve boot/launch and storage detection pipelines unless the task explicitly targets them.

## Preservation Contracts & Known Issues
These are shared, volatile facts maintained in one place. **Do not restate or fork them here.**
- **Preservation contracts** (D-10 / D-14 / D-15 / DKWDRV-MC / BOOT.ELF-USB-booted / `EnsureBootPartitionWritable`): see **`STATE.md > Preservation Contracts`** and the **Reported Hardware Status** table. Write these as contracts hardware-confirmed in the BETA line, not as open failures.
- **Known issues** (open / in-testing / recently-resolved): see **`STATE.md > Known Issues`**. Notable status deltas already reflected there: **U-10 (BOOT.ELF from HDD-boot)** and **DKWDRV from a custom HDD path** are **RESOLVED** (were known-broken); Class-A **HOSDmenu / wLaunchELF** start failures are **resolved**. The old "HDD installs save to `mc0:` because `ps2hdd-osd.irx` can't write PFS / needs an IRX swap" claim is **OBSOLETE** — HDD installs now save on the HDD boot partition via the RW mount take-over (single-device parity; see `STATE.md > Settings`).

## High-Risk Surfaces
Changes in these files can break core behavior and require extra care:
- `bin/POPSLDR/system.lua` (LaunchEngine, RunPOPStarterGame, ResolveBootContext, classify_mass_boot, AutoInitStartupBackends, EnsureMmceReadyOnce, and **`PLDR.HDD.EnsureBootPartitionWritable`** — the boot pfs-slot unmount→remount-RW "take over the mount" that is now load-bearing for HDD settings save and HDD in-app `.hide`; a launch-path or mount change must not break it. Note also the **load-order trap**: `PLDR.HDD` methods must be defined *after* `PLDR.HDD` exists — defining them early bricked recent HDD-feature rolling builds, fixed `d4b04be`.)
- `bin/POPSLDR/ui.lua` (LaunchSelectedGame, LaunchBootElf, OpenDKWDRV)
- `src/main.cpp` (detectBootDeviceHintFromArgv0, parseLaunchArgs, eager IRX load order, conditional mmceman)
- `src/luasystem.cpp` (lua_loadELF*, EnsureBDM*, EnsureMmceman, lua_mx4sio_init with mandatory EnsureUsbMass-first ordering, getMassMountDriver)
- `src/luaplayer.cpp`
- `src/elf_loader/src/elf.c` (LoadELFFromFile*, ExecuteViaEmbeddedLoader, ExecuteHddBackedViaEmbeddedLoader, LoadELFFromFileWithPartition)
- `src/elf_loader/src/loader/src/loader.c` (BRAM child loader; HDD partition-context branch must preserve B2 dynamic PFS unmount)
- `etc/boot.lua` (pfs1: boot mount normalization)
- `Makefile`
- `.github/workflows/compilation.yml`
- `.github/workflows/rolling-release.yml` (publishes the bare ELF + zip from one build to the canonical `rolling-release` tag on push to `BETA-12-PLAY` and on PR events)

## Change Discipline
- Keep diffs minimal and localized. One objective per branch/PR when feasible.
- No drive-by refactors or formatting churn.
- Do not rename or move files unless required.
- Prefer additive and reversible changes.

## Safety Rules
- Never run destructive commands (`rm -rf`, `git reset --hard`, force-push) without explicit instruction.
- Do not overwrite user-authored changes outside task scope.
- Pause and report if unexpected repository changes appear during work.
- Avoid adding new runtime logging unless explicitly requested.

## Build / Test Reality
- GitHub Actions is the canonical build path. The pinned CI image is `ps2dev/ps2dev:v2.0.0`.
- **The embedded-Lua syntax gate is now LIVE** (`luac5.4 -p` on `bin/POPSLDR/*.lua` + `etc/boot.lua`; the workflows `apk add lua5.4` and hard-fail on a syntax error). It used to silently skip because the ps2dev image shipped no `luac`. It catches **SYNTAX only** — runtime nil-global / type / **load-order** errors stay invisible to CI (the `d4b04be` boot brick was exactly such a case, so HDD features still need a full hardware retest even when CI is green).
- Rolling-release publishes the bare `POPSLOADER.ELF` and the zip from one build to the floating `rolling-release` GitHub Release; push-to-`BETA-12-PLAY` and PR events (including drafts) overwrite the same assets (last-write-wins).
- Hardware testing happens on real PS2 hardware via the maintainer and the testers. Agents cannot run hardware tests.

## Testing Expectations
- Choose the smallest test plan that can prove the change.
- Docs-only changes: run lightweight sanity checks when available; otherwise note `not run`.
- Runtime/build changes: run targeted checks first, then broader checks only if risk requires.
- Hardware-only behavior should be tracked in `QA_REGRESSION_MATRIX.md` and marked if unverified.

## Documentation / Evidence Discipline
When updating status after changes:
- **`STATE.md` is canonical** for runtime state, invariants, preservation contracts, the known-issues list, and hardware status; the other root docs (`README`, this file, `ROADMAP`, `DECISIONS`) point there instead of duplicating. Treat `QA_REGRESSION_MATRIX.md` as the detailed hardware/CI run ledger.
- Hardware pass/fail claims must have a matching `QA_REGRESSION_MATRIX.md` row with a date and result.
- In-flight / unreleased work is `Unknown (verify on hardware)` unless explicitly recorded. **Do not enumerate stale PR numbers here** — for the current in-flight/known-open work list, see `STATE.md > Known Open Work` (and `ROADMAP.md`).
- Released changelog entries should not be retroactively edited; new work goes in `[Unreleased]` at the top of `bin/changelog`.
- Remove stale branch names, stale feature claims, and outdated decisions.
- Do not silently carry forward old "fixed" claims when the only evidence is a prior chat report. If a regression was reported on hardware, record that result explicitly.

## Communication Format
Use this report structure in task responses:
- Summary: what changed and why.
- Diffstat: file-level change summary.
- Diff: key hunks or full patch when requested.
- Test plan: what was run, what passed/failed, and what was not run.

## Summary For The Next Agent
POPSLoader's stable backbone (HDD POPSTARTER paths, DKWDRV-MC, BOOT.ELF for USB- and HDD-booted, settings sidecar) is hardware-confirmed in the BETA line. The 2026-06 work — HDD-resident settings save + in-app `.hide` via the boot-partition RW take-over, PAL native 640×512, the BDMA `bdma_mode.txt` marker + POPSTARTER-MC-folder toggle/interlock — is implemented and boots on PCSX2, with HDD RW confirmed on hardware (provato) and the full flows still validating on hardware. Your job is most likely: drive doc/feature work, hardware-verify the in-flight HDD/PAL features, complete a queued PR, react to a tester report, or (once D-10/D-14/U-10 and the new features settle) the queued Settings UI redesign. Whatever it is: preserve the contracts in `STATE.md`, hardware-verify before claiming any new fix, and keep the docs pointed at `STATE.md` rather than re-duplicating the shared facts.
