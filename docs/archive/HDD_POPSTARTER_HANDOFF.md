# HDD POPSTARTER Handoff Audit

> **STATUS 2026-05-25: RESOLVED.** D-10, D-14, and D-15 are all hardware-PASS as of 2026-05-22 (Nuno). The fix that resolved them is the B2 contract at commit `4ae6679` — unmounting the target PFS slot before `ExecPS2` on the HDD-POPSTARTER handoff. This contract is preserved through PRs #455-#460 and must be preserved by any future launch-path change.
>
> This document is archived. The historical analysis below is kept as a reference for the diagnostic trail; the contents do NOT describe current behavior. See `STATE.md`, `ROADMAP.md`, and `QA_REGRESSION_MATRIX.md` for the current ledger and `docs/LAUNCH_HYGIENE.md` for the current launch-path architecture.

---

Last updated: 2026-05-20 (historical content below this point)

Branch audited: `BETA-12-PLAY`

Purpose: source-backed handoff notes for the remaining HDD-backed `POPSTARTER.ELF` failure. This was intended for a fresh Codex session so the same failed attempts and misleading diagnoses were not repeated. The actual fix that closed D-10/D-14 was the B2 contract (PFS unmount before ExecPS2) at commit `4ae6679`, applied after this document was written.

## Bottom Line (historical 2026-05-20)

- Do not frame the active bug as "HDD games fail." Current hardware history says HDD games launch when `POPSTARTER.ELF` is on a non-HDD device (`D-15` pass).
- The active blocker is narrower: if `POPSTARTER.ELF` itself resolves from HDD, games fail regardless of whether the game is HDD (`D-10`) or non-HDD (`D-14`).
- Custom POPSTARTER paths are only implicated when the effective custom path is HDD-backed. There is no current source-backed reason to treat custom non-HDD POPSTARTER paths as broken.
- Current and recent code contain source-confirmed defects or drift points in the HDD-backed POPSTARTER handoff. Hardware test results should be interpreted through the exact artifact under test before drawing broader conclusions.
- No source change should claim `D-10` or `D-14` fixed until hardware proves it. Mark runtime outcomes as `Unknown (verify on hardware)` until retested.

## Current Evidence

Repo and hardware ledger:

- `QA_REGRESSION_MATRIX.md` records `D-10` as HDD boot / HDD game / HDD sidecar or CWD `POPSTARTER.ELF` failing with black screen.
- `QA_REGRESSION_MATRIX.md` records `D-14` as non-HDD game with HDD-resident configured/Profile `POPSTARTER.ELF` failing with black screen.
- `QA_REGRESSION_MATRIX.md` records `D-15` as passing after rollback/narrowing: USB boot plus USB sidecar/Profile 1 `POPSTARTER.ELF` can launch an HDD game.
- `QA_REGRESSION_MATRIX.md` also records a 2026-05-20 latest-artifact `D-15` regression: USB boot with USB sidecar/cwd `POPSTARTER.ELF`, then launching an HDD title, black-screened.
- A follow-up 2026-05-20 report narrowed that non-HDD regression to default/cwd sidecar resolution: explicit `mass:/POPS/POPSTARTER.ELF` launches, while default `POPSTARTER.ELF` can stop at `Cant find POPSTARTER ELF`.
- The historical `D-15` pass was the key separator because it showed the remaining issue was not HDD game discovery, HDD game mount, or the POPSTARTER selector in general. The 2026-05-20 `D-15` regression means that guardrail must be retested first on the next artifact.
- One 2026-03-29 artifact moved `D-10` to `rc=-1 (returned after 22618 ms)`, but later artifacts returned to black screen. Treat that as an unstable boundary, not as the current steady-state failure mode.
- A 2026-05-20 hardware screenshot from the latest `BETA-12-PLAY` artifact showed `D-10` returning to the launcher with `POPSTARTER HDD pre-exec gate failed: Cannot resolve HDD partition context`, `POP:pfs3:/POPS/POPSTARTER.ELF`, and `APP:hdd0:+OPL:pfs:/APPS/PS1_POPSLOADER/`.
- Source follow-up found that the failure popup itself had two argument-shifted `BlockLaunchFailure()` calls, so `Rt:` showed the gate mode and `Gate:` showed the context table pointer. Treat screenshots from before that correction as useful for the high-level failure, but not for detailed route/gate diagnostics.
- A later 2026-05-20 screenshot after readable diagnostics showed the next gate failure: `POPSTARTER is not accessible using exec path`, with configured/effective path `hdd0:__common:pfs:/POPS/POPSTARTER.ELF`, resolved POP path `pfs3:/POPS/POPSTARTER.ELF`, and exec path `pfs:/POPS/POPSTARTER.ELF`.

Preserve these known-good or important flows while fixing:

- USB/MMCE/MX4SIO/SMB and other non-HDD POPSTARTER launch paths.
- MX4SIO behavior and mass-alias handling.
- `D-15`: HDD game with non-HDD `POPSTARTER.ELF`.
- `D-12`: HDD boot/startup/Profile lookup recovery.
- `D-16`: first-entry USB discovery.
- The normal POPSTARTER selector `argv[0]` contract unless source or hardware proves a change is required.

## Suspected Failure Path

Current `D-10` / `D-14` path in source:

1. `bin/POPSLDR/ui.lua` calls `PLDR.RunPOPStarterGame(...)`.
2. `bin/POPSLDR/system.lua` parses HDD game entries as `partition|relpath`. For normal HDD game list entries, the parsed partition label is a plain label such as `__.POPS`, while `PLDR.HDD.GAMEPARTS[entry]` stores `hdd0:__.POPS`.
3. `ResolvePopstarterPath()` can normalize an HDD `POPSTARTER.ELF` path to a mounted `pfsN:/...` path.
4. `ResolvePopstarterPartitionContext()` tries to derive the backing `hdd0:PART:` context. For HDD-backed launches this context is supposed to travel separately from the mounted load path.
5. `BuildPartitionScopedExecInfo()` normalizes mounted paths like `pfs1:/POPSTARTER.ELF` to generic `pfs:/POPSTARTER.ELF` when a partition context exists.
6. `LaunchEngine()` calls `System.loadELFWithPartition(exec_path, reboot_iop, partition_context, selector)` for partition-aware HDD POPSTARTER launches.
7. `src/luasystem.cpp` keeps the partition context out-of-band in `System.loadELFWithPartition()` and copies only explicit target args into the target argv array.
8. `src/elf_loader/src/elf.c` writes metadata for the embedded child loader, remounts the HDD partition as `pfs0:`, and passes caller target argv to the child loader.
9. `src/elf_loader/src/loader/src/loader.c` loads the target ELF and performs the final target `ExecPS2`.

The intended shape is sound: keep POPSTARTER's selector as target `argv[0]`, pass HDD partition/load-path metadata out of band, and remount deterministically before the child loader loads `POPSTARTER.ELF`. The current implementation has defects in that shape.

## Source-Confirmed Findings

Note: findings 1-5 below were the 2026-05-19 audit inputs and have source changes in current `BETA-12-PLAY`. They remain here because they explain why older hardware artifacts were not clean controls. Finding 6 is still deferred unless a child-loader rebuild/regeneration is intentionally taken on.

0. The 2026-05-20 artifact exposed an additional mounted-PFS recovery gap.
   - General recovery candidates still parsed only `hddN:`-prefixed partition names, so the plain `__.POPS` label from `ParseHddGameEntry()` did not participate in `BuildHddPartitionContext()` recovery.
   - The mounted-PFS fallback then tried only the selected game partition. That is too narrow when `POPSTARTER.ELF` was resolved from an already-mounted HDD source such as `pfs3:/POPS/POPSTARTER.ELF`.
   - Follow-up source change: `ParseHddPartitionMount()` now accepts the repo's own `hdd0:PART:` partition-context form, `NormalizeHddPartitionLabelForMount()` is used by the shared candidate builder for safe bare labels, and `ResolveFallbackMountedPfsExecPath()` first asks `BuildHddPartitionContext()` to recover the actual mounted POPSTARTER source partition before falling back to the selected HDD game partition.

0a. The pre-exec gate was probing the C-side generic exec path as if it were a real mounted path.
   - When partition context exists, `BuildPartitionScopedExecInfo()` intentionally normalizes a mounted POPSTARTER path like `pfs3:/POPS/POPSTARTER.ELF` to `pfs:/POPS/POPSTARTER.ELF` for the partition-aware C loader contract.
   - `ValidateHddPopstarterExecGate()` then called `doesFileExist()` on that generic `pfs:/...` path, which is not a real slot-bound mount path on hardware.
   - Follow-up source change: the gate now derives a real probe path from the recovered/recorded mounted prefix plus the exec relpath, while leaving the loader-facing `exec_path` unchanged.

1. Mounted-PFS fallback is currently unreliable and can invalidate tests.
   - `RunPOPStarterGame()` builds `context` before the mounted-PFS fallback block.
   - The fallback block later changes locals such as `popstarter_exec_path`, `popstarter_partition_context`, `popstarter_exec_info`, and slot variables.
   - `LaunchEngine()` consumes `context.exec_path`, `context.exec_partition_context`, slot fields, and diagnostics. Those context fields remain stale.
   - Result: diagnostics can claim a fallback path while the actual launch still uses the pre-fallback context.

2. Mounted-PFS fallback likely fails for normal HDD game entries.
   - HDD game entries are encoded as `partition|relpath`; `ParseHddGameEntry()` returns the plain partition label.
   - `ResolveFallbackMountedPfsExecPath(exec_path, hdd_partition_label)` calls `ParseHddPartitionMount(hdd_partition_label)`.
   - `ParseHddPartitionMount()` requires an `hddN:` prefix. A plain label such as `__.POPS` returns nil.
   - Result: fallback reports `missing-target-or-partition` for normal HDD game entries unless some caller passes a prefixed partition.

3. The pre-exec gate is skipped too broadly.
   - If `use_pfs_exec_fallback_without_partition_context` is true, the current code skips `ValidateHddPopstarterExecGate()`.
   - This happens regardless of whether fallback reconstruction actually succeeded.
   - Result: a failed fallback can still bypass the gate and proceed to launch with stale or incomplete context.

4. `System.loadELF(..., args..., partition_context)` leaks partition context into target argv.
   - `src/luasystem.cpp` detects a final partition-context argument, but does not reduce the arg range before copying arguments into `argv_static`.
   - Current HDD POPSTARTER calls can therefore turn target argv into `[selector, hdd0:PART:]`.
   - Do not pass partition context through the legacy `System.loadELF(path, reboot_iop, selector)` API. The safer fix is a distinct partition-aware Lua API.

5. Generic embedded-loader default-argv contract is blocked.
   - `src/elf_loader/include/elf-loader.h` says partition-aware loads preserve caller args and synthesize `argv[0]` only when none are supplied.
   - The child loader has code to synthesize a default target argv0.
   - `ExecuteViaEmbeddedLoader()` still returns `-7` when no target argv0 is supplied, so the generic default path cannot run.
   - Keep the POPSTARTER-specific HDD guard in `ExecuteHddBackedViaEmbeddedLoader()`, but remove or relax the generic inner guard so the documented generic contract is real.

6. Documentation and source drift on child-loader `snprintf`.
   - Existing docs claimed the current source keeps a safer embedded-loader fix avoiding `printf`/`snprintf` dependence in the child-loader environment.
   - Current `src/elf_loader/src/loader/src/loader.c` uses `snprintf` and `strncat` in `build_default_target_arg0()` and `read_embedded_loader_metadata()`.
   - Treat that as source/doc drift and a likely risk, not as a completed fix.

7. Regeneration of the embedded loader blob is mandatory after child-loader edits.
   - `src/elf_loader/loader.c` is tracked.
   - `src/elf_loader/Makefile` regenerates it from `src/elf_loader/src/loader/bin/loader.elf` using `bin2c`.
   - CI checks that `src/elf_loader/loader.c` content matches the generated child loader.
   - Any edit to `src/elf_loader/src/loader/src/loader.c` must be followed by regenerating and committing `src/elf_loader/loader.c`.

## Bad or Incomplete Prior Attempts

Do not repeat these as if they were clean controls:

- EE-side direct HDD load was reverted after it did not fix `D-10` and coincided with a `D-15` regression.
- Memory Card staging, stripped handoff, CWD/selector-only experiments, and HDD init-state experiments did not fix `D-10` / `D-14`.
- Forced `reboot_iop = 1` did not separate the failure.
- Direct `hdd0:PART:pfsN:/POPSTARTER.ELF` experiments still failed, and a follow-up found that one direct-path helper had omitted the colon after `pfsN`, so that attempt was not a clean proof.
- Mounted `pfs0:` embedded-loader and exact boot-mount/source-context experiments still black-screened on recorded hardware.
- The one returned-rc artifact is useful evidence, but later artifacts black-screened again. Do not assume the returned-rc behavior is stable.

## Recommended Fix Order

As of the latest 2026-05-20 source, the earlier Lua fallback/API/parent-loader audit fixes remain in source, but the normal HDD-backed POPSTARTER path has been simplified again because hardware evidence suggested the partition-aware route may be over-engineered. Normal `X` now keeps the resolved executable path, clears Lua partition context, skips the Lua HDD pre-exec gate/remount fallback, skips the embedded-loader reboot path, calls `System.loadELF(path, 0, selector)`, and no longer runs HDD-only parent cleanup immediately before `ExecPS2`. Do not claim this as a hardware fix until a GitHub Actions artifact is tested.

Current simplification target:

- Preserve the POPSTARTER selector `argv[0]` contract.
- Preserve non-HDD POPSTARTER paths and `D-15`.
- For HDD-resident `POPSTARTER.ELF`, solve only the execution of that ELF from HDD first.
- Do not also manage the selected HDD game partition unless hardware proves POPSTARTER needs that help.

Previous partition-aware route retained in source but not default:

- `System.loadELFWithPartition(...)`
- generic `pfs:/...` exec-path rewriting
- Lua HDD pre-exec gate
- mounted-PFS fallback/remount reconstruction
- HDD embedded-loader reboot handoff
- parent-side direct-path HDD pre-`ExecPS2` PFS/SIF cleanup

1. Fix Lua fallback correctness first.
   - Normalize plain HDD partition labels before fallback. A helper should accept both `__.POPS` and `hdd0:__.POPS` and produce `hdd0:__.POPS`.
   - Move mounted-PFS fallback reconstruction before `context` is built, or explicitly rebuild every affected `context` field after fallback. Moving it before context construction is lower risk.
   - Track `fallback_succeeded`.
   - Only set `launch_route = "mounted-pfs-fallback"` and only skip `ValidateHddPopstarterExecGate()` when fallback actually succeeded.
   - If fallback fails in non-strict mode, leave the gate enabled so the failure becomes explicit instead of silently launching stale context.

2. Add an explicit partition-aware Lua binding instead of overloading `System.loadELF`.
   - Add `System.loadELFWithPartition(path, reboot_iop, partition_context, args...)`.
   - In that function, collect target args only from the explicit args range. The partition context must never be copied into target argv.
   - Update `LaunchEngine()` to call this binding when `context.exec_partition_context` exists.
   - Keep `System.loadELF(path, reboot_iop, selector)` behavior intact for USB/MMCE/MX4SIO/SMB/non-HDD and existing callers.

3. Repair embedded-loader contract drift.
   - Keep the HDD POPSTARTER-specific `argv[0]` guard in `ExecuteHddBackedViaEmbeddedLoader()`.
   - Remove or narrow the generic `has_valid_target_argv0()` failure inside `ExecuteViaEmbeddedLoader()` so documented default argv synthesis is reachable for generic partition-aware loads.
   - Replace child-loader `snprintf`/`strncat` usage with small bounded copy/append helpers if the earlier no-stdio child-loader constraint is still desired.
   - Regenerate `src/elf_loader/loader.c` after rebuilding the child loader.

4. Keep the test sequence narrow.
   - Start with build/CI-equivalent checks.
   - Hardware retest `D-15` first to confirm HDD games with non-HDD POPSTARTER still work.
   - Then retest `D-10` with normal `X`.
   - Only after normal `X` is understood, retest `D-10` `R2`.
   - Retest `D-14` to confirm HDD-resident POPSTARTER also works for non-HDD games.
   - Treat `U-10` as related but separate; do not claim it fixed from a `D-10` result.

## Suggested Verification

Source/build checks:

- `git diff --check`
- Lua syntax check for `bin/POPSLDR/system.lua` if `luac` or compatible `lua` is available.
- `make clean elfloader all`
- Confirm `src/elf_loader/loader.c` matches the rebuilt child loader after any child-loader change.

Hardware checks to record in `QA_REGRESSION_MATRIX.md`:

- `D-15`: USB/MMCE/MX4SIO or other non-HDD boot, non-HDD sidecar/Profile 1 `POPSTARTER.ELF`, HDD game.
- `L-08`: same non-HDD boot and sidecar/Profile 1 setup, confirming launch no longer stops at `Cant find POPSTARTER ELF` before the handoff.
- `D-10`: HDD boot, HDD sidecar/CWD/Profile/default `POPSTARTER.ELF`, HDD game, normal `X`.
- `D-10` alternate: same setup with `R2`, only after normal `X` is tested.
- `D-14`: USB/MMCE/MX4SIO game with Profile/custom path pointing `POPSTARTER.ELF` to HDD.
- `D-12`: HDD boot plus startup/Profile lookup sanity, especially USB page before HDD page.
- `U-10`: `BOOT.ELF` after HDD page/runtime init, as a separate result.

## Do Not Do

- Do not change the POPSTARTER selector `argv[0]` contract unless a source-backed or hardware-backed reason proves it is required.
- Do not broaden fixes into HDD game mount/discovery behavior; `D-15` says that path can work.
- Do not preserve old mounted `pfsN:` slots into the final HDD-backed POPSTARTER exec path unless the current fix specifically proves that is needed.
- Do not treat custom non-HDD POPSTARTER paths as broken without new evidence.
- Do not document hardware PASS for `D-10`, `D-14`, or `U-10` without actual hardware results.
