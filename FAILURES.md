# FAILURES

## Purpose

This file inventories only **confirmed failed fix attempts** for the remaining
`POPSTARTER.ELF on HDD` launch problem.

Inclusion rule:
- The attempt must be confirmed by at least one of:
  - current repository code/history,
  - explicit hardware results reported during this audit,
  - the pre-audit failed-direction list supplied by the user.

Exclusion rule:
- Do **not** include anything that cannot be stated accurately.
- Do **not** include instrumentation-only changes as failed fixes.
- Do **not** include changes that fixed some other regression. Example:
  restoring regular USB/default sidecar POPSTARTER lookup is not listed as a
  failed fix, because that change did work for non-HDD sidecar launch.

Important scope:
- Target bug: launches fail when `POPSTARTER.ELF` itself is on HDD.
- Non-target: generic HDD game listing failures, ART failures, or generic
  backend failures.

Some attempts below are no longer present in the current worktree because they
were reverted after failing. They are still listed here because the change and
the failure outcome were explicitly observed during this audit.

## Confirmed Pre-Audit Failed Directions

These were already reported as dead ends before this audit started. The exact
repository diff for each one is not recoverable from the current repo state, so
only the confirmed attempted scope is listed.

### 1. Raw-HDD-vs-mounted-PFS preference flips in isolation

Confirmed attempted scope:
- raw-first path preference
- mounted-first path preference
- generic sidecar/path-resolution churn

Confirmed result:
- did not fix HDD-resident POPSTARTER launch

### 2. Dedicated helper-slot / `pfs3` remount ideas

Confirmed attempted scope:
- dedicated helper-slot remounting
- `pfs3` remount ideas

Confirmed result:
- did not fix the launch problem
- some variants regressed earlier into `green`

### 3. Generic mount cleanup / preserve-vs-drop slot churn

Confirmed attempted scope:
- preserving boot slots
- preserving game slots
- dropping boot slots
- dropping game slots
- generic “unmount all PFS / cleanup before exec” ideas

Confirmed result:
- did not fix HDD-resident POPSTARTER launch

### 4. Generic reboot toggles in isolation

Confirmed attempted scope:
- forcing `reboot_iop` by itself
- disabling `reboot_iop` by itself
- swapping reset args alone
- generic pre-reset teardown experiments by themselves

Confirmed result:
- did not fix HDD-resident POPSTARTER launch

### 5. Partition-aware embedded-loader routing as a blind fix

Confirmed attempted scope:
- raw `hdd0:...:pfs:/...` splitting
- prefix routing
- loader-path churn by itself

Confirmed result:
- did not fix HDD-resident POPSTARTER launch

### 6. `cwd`-only fixes

Confirmed attempted scope:
- switching `cwd` to the HDD POPSTARTER directory before direct handoff
- switching `cwd` using the raw exec path
- switching `cwd` using a mounted `pfsN:/...` alias

Confirmed result:
- did not fix HDD-resident POPSTARTER launch

### 7. `argv[0]` / selector spoofing alone

Confirmed attempted scope:
- rooted selector beside HDD POPSTARTER
- mounted-alias `argv[0]` forms
- extra-arg forwarding alone
- synthetic selector path only

Confirmed result:
- did not fix HDD-resident POPSTARTER launch

### 8. Real selector alias execution

Confirmed attempted scope:
- creating `GAME.ELF` / `XX.GAME.ELF` beside HDD POPSTARTER
- executing that alias file itself

Confirmed result:
- regressed earlier to `green`
- user mapped that result to a `SifLoadElf()` hang

## Confirmed Failed Fixes During This Audit

### 9. Remove the HDD-local selector alias rewrite

Files touched:
- `bin/POPSLDR/system.lua`

Exact change attempted:
- Removed the `popstarter_on_hdd` block that replaced the normal selector
  `argv[0]` with an alias file created beside HDD POPSTARTER via
  `EnsureSelectorElfAlias(...)`.

Intent:
- Stop fabricating an HDD-local selector alias and keep the original backend
  selector form.

Confirmed result:
- hardware result after this build: `green frame black screen`

Conclusion:
- removing the HDD-local alias rewrite did not fix the launch problem

### 10. Normalize the actual launch target to the mounted HDD path

Files touched:
- `bin/POPSLDR/system.lua`

Exact change attempted:
- When `POPSTARTER.ELF` was on HDD, normalized the actual `System.loadELF(...)`
  target to `ResolveHddExecMountedPath(popstarter)` before launch.

Intent:
- Feed `SifLoadElf()` a mounted `pfsN:/...` path instead of the raw HDD form.

Confirmed result:
- hardware result after this build: `black screen, no green frame this time`

Conclusion:
- mounted-path normalization did not fix the launch problem

### 11. Restore full extra-argument forwarding and pass HDD-only launch args

Files touched:
- `src/luasystem.cpp`
- `bin/POPSLDR/system.lua`

Exact change attempted:
- `lua_loadELF()` stopped truncating `System.loadELF(path, reboot_iop, args...)`
  to a single extra argument.
- HDD-resident POPSTARTER launches passed:
  - `argv[0] = selector`
  - `argv[1] = resolved POPSTARTER path`
  - `argv[2] = bootparam` when present

Intent:
- Test whether the missing arguments were the remaining handoff bug.

Confirmed result:
- hardware result after this build: `black screen after the borders all flashed quickly`

Conclusion:
- correct extra-arg forwarding did not fix the launch problem

### 12. Normalize direct `ExecPS2()` target `argv[0]` to the real executable path

Files touched:
- `src/elf_loader/src/elf.c`

Exact change attempted:
- In the direct `LoadELFFromFileExecPS2()` branch, when the caller provided a
  selector plus the real ELF path, rewrote the target argv to:
  - `argv[0] = resolved executable path`
  - `argv[1] = selector`
  - remaining args unchanged

Intent:
- Make the direct handoff match the repo’s embedded-loader argv shape.

Confirmed result:
- hardware result after this build: `same result`

Conclusion:
- direct-path `argv[0]` normalization did not fix the launch problem

### 13. Always run the direct HDD cleanup by removing the preserve-runtime special case

Files touched:
- `src/elf_loader/src/elf.c`

Exact change attempted:
- Removed the condition that skipped `cleanup_hdd_exec_handoff()` when the
  selector differed from the resolved path.

Intent:
- Ensure HDD/PFS direct launches always performed the final cleanup before
  `ExecPS2()`.

Confirmed result:
- hardware result after this build: `yellow frame black screen`

Conclusion:
- forcing the direct HDD cleanup did not fix the launch problem

### 14. Remove the HDD direct pre-launch `cwd` switch

Files touched:
- `bin/POPSLDR/system.lua`

Exact change attempted:
- Deleted the direct-HDD pre-launch `System.currentDirectory(popstarter_dir)`
  change in `LaunchEngine()`.

Intent:
- Avoid unmounting the process current directory during the direct handoff.

Confirmed result:
- hardware result after this build: `green border black screen`

Conclusion:
- removing the HDD `cwd` switch did not fix the launch problem

### 15. Force the reboot path by making HDD `argv[0]` the real POPSTARTER path

Files touched:
- `bin/POPSLDR/system.lua`

Exact change attempted:
- For HDD-resident POPSTARTER, changed the argument layout so the first arg was
  the real POPSTARTER path instead of the selector.

Intent:
- Force `lua_loadELF()` onto `LoadELFFromFileExecPS2RebootIOP()` instead of the
  direct selector-overrides-path branch.

Confirmed result:
- hardware result after this build: `red frame black screen`

Conclusion:
- forcing the reboot path did not fix the launch problem

### 16. Remove the forced mounted-path override and launch the raw resolved HDD path as-is

Files touched:
- `bin/POPSLDR/system.lua`

Exact change attempted:
- Deleted the block in `RunPOPStarterGame()` that rewrote HDD POPSTARTER to a
  mounted path via `ResolveHddExecMountedPath(popstarter)`.

Intent:
- Launch the raw resolved HDD POPSTARTER path without converting it to a
  mounted alias.

Confirmed result:
- hardware result after this build: `orange frame black screen`

Conclusion:
- removing the mounted-path override did not fix the launch problem

### 17. Switch HDD arguments back to selector-first to avoid the reboot-path stall

Files touched:
- `bin/POPSLDR/system.lua`

Exact change attempted:
- Restored HDD launch args to selector-first ordering instead of
  `argv[0] = popstarter`.

Intent:
- Move back off the already-proven bad reboot/sync branch.

Confirmed result:
- hardware result after this build: `yellow frame black screen`

Conclusion:
- switching back to selector-first did not fix the launch problem

### 18. Force HDD-resident POPSTARTER to `reboot_iop = 0`

Files touched:
- `bin/POPSLDR/system.lua`

Exact change attempted:
- Changed the HDD override from `reboot_iop = 1` to `reboot_iop = 0`.

Intent:
- Make raw HDD selector launches eligible for the partition-aware
  `LoadELFFromFileWithPartition()` path instead of the reboot path.

Confirmed result:
- after subsequent non-HDD sidecar regression repair, HDD sidecar was still
  reported as `yellow border black screen`

Conclusion:
- forcing `reboot_iop = 0` for HDD-resident POPSTARTER did not fix the launch
  problem

### 19. Use the compat IOP reset helper in the embedded loader

Files touched:
- `src/elf_loader/src/loader/src/loader.c`

Exact change attempted:
- Replaced the embedded-loader `SifIopReset(IOP_RESET_ARGS, 0)` call with a
  local `SifIopResetCompatNoDmaStop(...)` helper matching the reboot-path
  compatibility reset sequence.

Intent:
- Remove the reset-path mismatch between the embedded loader and the reboot
  loader.

Confirmed result:
- hardware result after this build: `yellow border black screen`

Conclusion:
- the compat-reset embedded-loader change did not fix the launch problem

### 20. Force HDD-page launches to ignore custom paths and always use a common POPSTARTER path

Files touched:
- `bin/POPSLDR/system.lua`
- `bin/POPSLDR/ui.lua`

Exact change attempted:
- Added an HDD-page-specific POPSTARTER resolver.
- HDD page launches ignored the configured/custom POPSTARTER path and instead
  forced `hdd0:__common/POPS/POPSTARTER.ELF`.
- Updated the UI preflight to use that same HDD-specific rule.

Intent:
- Stop depending on sidecar/custom-path semantics for HDD page launches.

Confirmed result:
- hardware result after this build: still `yellow border`
- the raw slash form also later produced:
  `Cant find POPSTARTER ELF`
  `hdd0:__common/POPS/POPSTARTER.ELF`

Conclusion:
- forcing the HDD page to a raw common POPSTARTER path did not fix the launch
  problem

### 21. Make HDD `argv[0]` handling match the other devices

Files touched:
- `bin/POPSLDR/system.lua`

Exact change attempted:
- Removed the HDD-only extra args and made HDD launches pass only
  `{argv0_selector}`, matching the non-HDD argument shape apart from the HDD
  selector naming convention.

Intent:
- Eliminate one more HDD-only handoff difference.

Confirmed result:
- no successful HDD launch was reported from this build
- the next observed failure remained on the forced HDD common-path policy
- the exact isolated stage for this attempt is not recoverable from the current
  repo state or the recorded hardware notes

Conclusion:
- matching the non-HDD `argv[0]` shape did not fix the launch problem

### 22. Correct the forced common POPSTARTER path to the embedded HDD syntax

Files touched:
- `bin/POPSLDR/system.lua`
- `bin/POPSLDR/ui.lua`

Exact change attempted:
- Changed the forced common POPSTARTER path from:
  `hdd0:__common/POPS/POPSTARTER.ELF`
- to:
  `hdd0:__common:pfs:/POPS/POPSTARTER.ELF`
- Kept the HDD-page UI preflight bypass for that path.

Intent:
- Match the repo’s partition-aware HDD exec syntax.

Confirmed result:
- hardware result after this build was not success
- the explicit failure screen later reported:
  - `LAUNCH RETURNED`
  - `rc=Launch timeout: exec did not transfer control`
  - `Device: HDD`
  - `POPSTARTER: hdd0:__common:pfs:/POPS/POPSTARTER.ELF`

Conclusion:
- correcting the common-path syntax to the embedded HDD form did not fix the
  launch problem

### 23. Resolve the forced common POPSTARTER path through the same helper used for HDD ART

Files touched:
- `bin/POPSLDR/system.lua`

Exact change attempted:
- Changed `ResolveHddPagePopstarterPath()` so it first tried:
  `ResolveHddPartitionReadablePath("hdd0:__common", "POPS/POPSTARTER.ELF", nil, HDD_SLOT_COMMON)`
- and only then fell back to the raw embedded common-path constant.

Intent:
- Reuse the repo’s known-good `__common` ART path resolution semantics instead
  of a hardcoded exec path alone.

Confirmed result:
- hardware result after this build: `yellow border black screen`

Conclusion:
- ART-style common-path resolution did not fix the launch problem

### 24. Remove the direct HDD-only `fileXioUmount()` / `fileXioExit()` cleanup

Files touched:
- `src/elf_loader/src/elf.c`

Exact change attempted:
- Reduced `cleanup_hdd_exec_handoff()` to:
  - `SifExitIopHeap()`
  - `SifExitRpc()`
  - `SifExitCmd()`
  - `FlushCache(0)`
  - `FlushCache(2)`
- Removed the direct HDD-only:
  - `fileXioUmount(...)`
  - `fileXioExit()`

Intent:
- Stop doing extra HDD-only cleanup that the working non-HDD direct path does
  not do.

Confirmed result:
- the initial `green` report for this build was later retracted
- corrected hardware result for this build was: `black screen`

Conclusion:
- removing the direct HDD `fileXio` cleanup did not fix the launch problem

## Notes For Future Work

What this file does **not** prove:
- It does not prove POPSTARTER itself is the failing component.
- It does not prove the remaining failure is after `ExecPS2()`.
- It does not prove raw HDD semantics or mounted `pfsN:/...` semantics are
  correct.

What this file **does** prove:
- multiple distinct HDD path, `argv`, `cwd`, reboot, cleanup, and common-path
  strategies were tried and explicitly failed
- the work was not limited to a single path-policy guess
- future prompts should not retry these exact attempts unless a new source-level
  reason makes a materially different variant worth testing
