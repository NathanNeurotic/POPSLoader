# AGENTS START HERE

## Purpose

This file is the current entry point for agents (cloud or interactive) starting work on POPSLoader after the **BETA-10-5 release** (tag `9a0ebe2`, 2026-05-27, hardware-confirmed clean by Nuno 2026-05-28).

It is intentionally informational. It describes the current preservation contracts, the post-release work in flight, what is intentionally accepted as known-broken, and where the detailed evidence lives.

> **Historical note**: Earlier versions of this file framed D-10 (HDD POPSTARTER + HDD game) as the single urgent unresolved objective. D-10 was resolved by the B2 PFS-unmount fix at commit `4ae6679` and hardware-confirmed on 2026-05-22 and reconfirmed on 2026-05-28. **D-10 is now a preservation contract, not an open blocker.**

## Where to look first

| File | What's there |
|---|---|
| [STATE.md](../../STATE.md) | Current code and hardware status. Repo-verified runtime state. Reported hardware table. Post-release PR work. |
| [ROADMAP.md](../../ROADMAP.md) | Prioritized backlog. Immediate priorities, pragmatically-accepted-broken items, secondary work. |
| [STATE.md](../../STATE.md) | Non-negotiable behavioral invariants. Preservation contracts. (Replaces former TRUTHSHEET.md) |
| [QA_REGRESSION_MATRIX.md](../../QA_REGRESSION_MATRIX.md) | Authoritative hardware/CI ledger with per-artifact run history. |
| [DECISIONS.md](../../DECISIONS.md) | Decision log with rationale and evidence. Recent entries cover post-release PRs (#470/#472/#473/#471). |
| [LAUNCH_HYGIENE.md](LAUNCH_HYGIENE.md) | Launch-path architecture, V2 mimicry rationale, Layer A/B/C definitions. |
| [U10_INVESTIGATION.md](U10_INVESTIGATION.md) | Deep dive into the U-10 BOOT.ELF exit failure from HDD-booted POPSLoader. |
| [DOCUMENTATION_FOLLOWUP_AUDIT.md](DOCUMENTATION_FOLLOWUP_AUDIT.md) | Documentation audit and follow-up plan post BETA-10-5. |

## Hard Constraints (Preservation Contracts)

These are hardware-confirmed in BETA-10-5 and must not be broken by any new work:

- **D-10**: HDD POPSTARTER + HDD game. B2 fix at commit `4ae6679` (dynamic PFS unmount before ExecPS2 in child loader). PASS.
- **D-14**: HDD POPSTARTER + non-HDD game. Same partition-aware route as D-10. PASS.
- **D-15**: non-HDD POPSTARTER + HDD game. Keep-mask preserves boot partition PFS slot across exec. PASS.
- **DKWDRV from MC**: default Memory Card DKWDRV path through reboot variant + argv0 synthesis. PASS.
- **BOOT.ELF from USB-booted POPSLoader (L-07)**: V2 working route at commit `d23520a` — non-reboot variant + `ExecuteViaEmbeddedLoader` + child loader non-HDD branch (no IOP reset). PASS.
- **Settings sidecar**: non-HDD installs (USB / MX4SIO / MMCE) save settings to `APP_DIR/.pldrs`. HDD installs deliberately fall back to `mc0:/POPSTARTER/.pldrs` (PR #466).
- **MX4SIO mass: classification rule**: ioctl driver name is authoritative. `sdc`/`mx4` → MX4SIO; anything else → USB. `mx4sio_bd` only loads on explicit MX4SIO evidence (PR #472 + refinement `7b587fe`). `mx4sio_bd` depends on `usbmass_bd` loaded first (enforced at C layer).

## Known Broken (current)

- **"Failed to load HDD" from a non-HDD boot** (config-specific; Nuno 2026-06-14) — POPSLoader starts and most setups list the HDD fine, but a specific configuration still fails. Workaround: boot POPSLoader from the HDD, or open the HDD page a few seconds after the menu appears. Under investigation.

**Resolved since BETA-10-5 (hardware-confirmed) — removed from known-broken 2026-06-15:** DKWDRV from a custom HDD path (#486/#487), U-10 BOOT.ELF-from-HDD-boot (#479, `reboot_iop=0`), and HOSDmenu / specific wLaunchELF builds failing to launch POPSLoader (maintainer-confirmed 2026-06-15; mechanism not pinned). U-10 history preserved in [docs/U10_INVESTIGATION.md](U10_INVESTIGATION.md).

## Post-release work in flight

Merged to `BETA-12-PLAY` since BETA-10-5 (CI-verified, hardware status `Unknown (verify on hardware)` unless `QA_REGRESSION_MATRIX.md` says otherwise):

- **PR #470** — `PLDR.LAUNCH_ARGS.game` auto-launch consumer + `-debug` boot-context toast.
- **PR #472** — MX4SIO evidence-based mass: classification + maintainer refinement `7b587fe` + C-layer dependency enforcement.
- **PR #473** — HOTFIX for Lua forward-reference crash (`ClassifyMassRootDriver` declaration order).

Open:

- **PR #471 (DRAFT)** — Layer C: `mmceman.irx` lazy-loaded unless boot device is MMCE. Awaiting hardware verification (pad input survival on USB / HDD / MC boots is the critical regression check).

## Build / Test Reality

- GitHub Actions is the canonical build path. The pinned CI image is `ps2dev/ps2dev:v2.0.0`.
- Rolling-release artifact is published to a single canonical URL: https://github.com/NathanNeurotic/POPSLoader/releases/download/rolling-release/POPSLOADER-rolling-release.zip
- Both push-to-`BETA-12-PLAY` and PR events (including drafts) trigger the workflow and overwrite the same asset (last-write-wins).
- Hardware testing happens on real PS2 hardware via the maintainer and tester Nuno. CosmicScale is a secondary tester for specific use cases. Agents cannot run hardware tests — claims of hardware verification must cite a recorded result in `QA_REGRESSION_MATRIX.md`.

## High-Risk Surfaces

These files are involved in the load-bearing launch paths or can easily regress preservation contracts:

- `bin/POPSLDR/system.lua` (LaunchEngine, RunPOPStarterGame, ResolveBootContext, ClassifyStartupMassTargets, AutoInitStartupBackends)
- `bin/POPSLDR/ui.lua` (LaunchSelectedGame, LaunchBootElf, OpenDKWDRV)
- `src/luasystem.cpp` (lua_loadELF*, EnsureBDM*, EnsureMmceman, lua_mx4sio_init, getMassMountDriver)
- `src/elf_loader/src/elf.c` (LoadELFFromFile*, ExecuteViaEmbeddedLoader, ExecuteHddBackedViaEmbeddedLoader, LoadELFFromFileWithPartition)
- `src/elf_loader/src/loader/src/loader.c` (BRAM child loader main entry, fileXio direct load branch, HDD partition-context branch)
- `src/main.cpp` (detectBootDeviceHintFromArgv0, parseLaunchArgs, eager IRX loads, mmceman conditional load via PR #471)
- `Makefile`, `.github/workflows/compilation.yml`, `.github/workflows/rolling-release.yml`

## Documentation / Evidence Discipline

When updating status after changes:

- Keep `README.md`, `STATE.md`, `ROADMAP.md`, `DECISIONS.md`, `TRUTHSHEET.md`, and `QA_REGRESSION_MATRIX.md` synchronized.
- `QA_REGRESSION_MATRIX.md` is the authoritative detailed run ledger. Other docs summarize and link.
- Hardware pass/fail claims must have a matching `QA_REGRESSION_MATRIX.md` row with a date and result.
- Post-release PR work is `Unknown (verify on hardware)` unless explicitly recorded.
- D-10 / D-14 / D-15 should be written as preservation contracts, not open failures.
- Do not claim hardware fixes without an actual hardware result.

## Summary For The Next Agent

POPSLoader's stable backbone (HDD POPSTARTER paths, DKWDRV-MC, BOOT.ELF for USB-booted, settings sidecar) is hardware-confirmed in BETA-10-5. Post-release work is iterating on smaller concerns: NHDDL-style launch args, MX4SIO classification correctness, Layer C boot-time optimization. U-10 and DKWDRV-from-HDD-custom-path are pragmatically accepted with workarounds.

Your job is most likely either:

- Continue a post-release PR (currently PR #471 Layer C is the open DRAFT)
- Implement the Berion-mockup GUI overhaul (blocked on mockup PNGs landing at `C:\Users\natha\Documents\assets\`)
- Drive doc cleanup per `docs/DOCUMENTATION_FOLLOWUP_AUDIT.md`
- React to a tester report

Whatever it is: preserve the BETA-10-5 contracts above, hardware-verify before claiming any new fix, and keep the docs in sync.
