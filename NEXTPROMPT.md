Last updated: 2026-03-25

# NEXTPROMPT

Use the following prompt for the next agent working on the HDD-resident `POPSTARTER.ELF` black-screen issue in this repository.

All file references below are repository-relative within:

- Repo: `https://github.com/NathanNeurotic/POPSLoader`
- Branch: `BETA-9-RECOVERY-BACKUP-CHECKPOINT-PROFILES-PLAY`

Do not rewrite these references as local filesystem paths. Use the GitHub repo and repo-relative directories/files so the prompt is portable across cloud and local agent environments.

---

You are working in this repository:

- Repo: `https://github.com/NathanNeurotic/POPSLoader`
- Branch: `BETA-9-RECOVERY-BACKUP-CHECKPOINT-PROFILES-PLAY`

You must read and follow `AGENTS.md` in the repo root strictly before making any change.

## Core Objective

Resolve the still-unresolved black screen that happens only when `POPSTARTER.ELF` itself is HDD/PFS-resident and is launched as the POPSTARTER sidecar / cwd executable for HDD titles.

This is not a general POPSLoader launch failure.

This is not a USB/MMCE/MX4SIO problem.

This is not an HDD game-listing problem.

This is specifically the HDD-resident `POPSTARTER.ELF` launch problem.

The target behavior is:

- HDD title selected from the HDD (PFS) UI
- `POPSTARTER.ELF` itself also resident on HDD/PFS
- launch transfers successfully into POPSTARTER
- POPSTARTER output becomes visible
- no black screen before POPSTARTER output
- no return to POPSLoader with `exec did not transfer control`

## Non-Negotiable Rules

- Evidence-first.
- Minimal, bounded diffs.
- Preserve all currently working behavior.
- Do not break USB launches.
- Do not break MMCE launches.
- Do not break MX4SIO.
- Do not break HDD list/browse behavior.
- Do not broad-refactor storage detection, routing, or launch plumbing without new code evidence that it is required.
- Do not change the selector / `argv[0]` contract unless absolutely required and supported by genuinely new evidence.
- Do not add sleeps, delays, or unbounded retries.
- Do not claim the issue is fixed unless repository evidence supports the change and hardware has verified it.
- Hardware-only claims must be marked `Unknown (verify on hardware)` unless explicitly hardware-tested.
- User testing will be done through GitHub Actions workflow artifacts on GitHub.
- Do not ask the user to validate this locally outside the GitHub Actions artifact flow.
- Do not use repo history as proof that a path is known-good. Much of the history here is evidence of failed attempts.
- Do not cite local filesystem paths in your output. Use repo-relative paths and the GitHub repo reference.

## Important Scope Clarification

Preserve the systems that already work.

Repo-backed current/working constraints:

- `USB` launch behavior is treated as working and must not regress.
- `MMCE` launch behavior is treated as working and must not regress.
- `MX4SIO` must remain untouched and working.
- HDD title scanning/listing/browsing works and must not regress.

SMB note:

- Current repo docs such as `README.md` and `STATE.md` still describe the SMB menu flow as not implemented.
- Do not invent unsupported SMB runtime claims.
- Also do not damage any existing SMB-related codepaths while working on this HDD problem.

This task is exclusively about:

- HDD cwd / sidecar `POPSTARTER.ELF`
- HDD/PFS-resident `POPSTARTER.ELF`
- black screen before POPSTARTER output

If your proposed change meaningfully alters:

- USB handling,
- MMCE handling,
- MX4SIO handling,
- broad device policy,
- title scan logic,
- settings persistence,
- UI logic outside the launch path,

then your change is probably too broad unless you can prove it is required.

## Required Files To Read Before Any Change

Read these files first:

- `AGENTS.md`
- `FAILURES.md`
- `STATE.md`
- `ROADMAP.md`
- `QA_REGRESSION_MATRIX.md`
- `README.md`
- `PROMPTS.md`
- `bin/POPSLDR/system.lua`
- `src/luasystem.cpp`
- `src/elf_loader/include/elf-loader.h`
- `src/elf_loader/src/elf.c`
- `src/elf_loader/src/loader/src/loader.c`

Also inspect:

- `.github/workflows/compilation.yml`
- `src/elf_loader/src/loader/Makefile`

## Current Repo-Verified Launch Chain

Current repo-verified HDD launch chain on this branch:

1. `bin/POPSLDR/system.lua`
   - `PLDR.RunPOPStarterGame(...)` resolves the launch policy and POPSTARTER path.
   - `LaunchEngine(...)` prefers a mounted `pfs:/...` executable path when it can resolve one from a raw `hdd0:` path.
   - `LaunchEngine(...)` only includes `partition_hint` when the final executable path is still raw `hdd0:...`.
   - It then calls `System.loadELF(...)`.

2. `src/luasystem.cpp`
   - partition-aware raw HDD launches with a partition argument route to `LoadELFFromFileWithPartition(...)`
   - non-partitioned, argumented `pfs:/...` launches route to `LoadELFFromFile(...)`
   - other non-reboot argumented launches route to `LoadELFFromFileExecPS2(...)`
   - rebooting launches route to `LoadELFFromFileExecPS2RebootIOP(...)`

3. `src/elf_loader/src/elf.c`
   - partition-aware launches stage and `ExecPS2` into the embedded loader
   - direct launches use one of the direct loader mechanisms:
     - `LoadELFFromFile(...)` -> `LoadExecPS2(...)`
     - `LoadELFFromFileExecPS2(...)` -> `SifLoadElf(...)` + `ExecPS2(...)`
     - `LoadELFFromFileExecPS2RebootIOP(...)` -> `SifLoadElf(...)` + IOP reset + `ExecPS2(...)`

4. `src/elf_loader/src/loader/src/loader.c`
   - this is the embedded loader used by the partition-aware HDD path
   - it performs the later POPSTARTER handoff for that path

## Strong Repo-Local Evidence Already Established

- `bin/POPSLDR/POPSTARTER.ELF` has one `LOAD` segment and no `PT_MIPS_REGINFO`.
- Therefore any custom target-loader logic that depends on `PT_MIPS_REGINFO` for POPSTARTER `gp` is suspect.
- The contract in `src/elf_loader/include/elf-loader.h` for partition-aware loads still matters:
  - `filename = pfs:/...`
  - `partition = hdd0:PART:`

Durable HDD evidence already established from this branch:

- Commit `2172a2f` proved embedded-loader image copy completed:
  - `argc=3`
  - `partition=hdd0:+OPL:`
  - `path=pfs:/APPS/PS1_POPSLOADER/POPSTARTER.ELF`
- Commit `6c81233` proved `SifExitRpc()` and both `FlushCache()` calls completed before the final embedded-loader `ExecPS2`.
- Commit `9eaa040` proved that keeping SIF RPC alive before the partitioned embedded-loader `ExecPS2` moved the failure forward to a stable embedded-loader entry stage.
- Stable `embedded loader entry` is the last durable later-stage hardware observation from the diagnostic family.

## Latest Hardware Situation

Latest standard-artifact hardware result:

- Commit `d4a604e` still black-screened.

More recent standard-artifact failures that matter:

- `0a0b6e9` standard artifact: fast flash, then black screen
- `e55e119` standard artifact: black screen
- `26fc65d` standard artifact: black screen
- `59be355` standard artifact: black screen
- `d4a604e` standard artifact: black screen

Interpretation:

- The embedded-loader screen-backed diagnostic line is exhausted.
- The newer mounted-`pfs` direct-launch variants are also exhausted.
- The branch is no longer blocked on “maybe only the partition-aware embedded-loader path is bad.”
- At least on current repo evidence, both of these families still fail:
  - partition-aware embedded-loader handoff
  - mounted HDD `pfs:/...` direct-launch variants

## Failed Hypothesis Families You Must Not Repeat Without New Evidence

### 1) Selector / `argv[0]` contract reshaping

Failed commits:

- `45e1f05` `Use mounted HDD selector path for POPSTARTER argv0`
- `ac41f47` `Root HDD POPSTARTER argv0 at resolved sidecar path`
- `5016138` `Restore embedded HDD loader argv contract`

What this means:

- Do not propose another selector-shape rewrite unless you can point to a concrete new asymmetry not already covered by these changes.

### 2) HDD game-slot / sidecar-slot preservation rewrites

Failed commits:

- `757345b` `Prepare HDD game slot before POPSTARTER handoff`
- `0ed6441` `Preserve HDD POPSTARTER mount during launch handoff`

What this means:

- Do not assume mount preservation alone is the fix.

### 3) Embedded-loader reset / cleanup / wipe toggles

Failed commits:

- `35291c1` `Stop resetting IOP in HDD embedded POPSTARTER handoff`
- `70895e4` `Reset IOP before ExecPS2 in HDD embedded loader path`
- `e55e119` `Stop wiping EE user memory in HDD embedded loader`

What this means:

- Do not toggle reset policy again.
- Do not retry the `wipeUserMem()` theory.

### 4) Partition-aware HDD handoff rewrites

Failed commits:

- `38f7a9d` `Fix HDD POPSTARTER partition-aware embedded handoff`
- `a81d8a2` `Use SifLoadElf for partitioned HDD POPSTARTER handoff`
- `7a32ad2` `Normalize pfs path for partitioned HDD POPSTARTER handoff`
- `120fc72` `Restore upstream partitioned loader handoff contract`
- `ea03ba2` `Keep raw HDD POPSTARTER path through partition handoff`

What this means:

- Do not repeat partition/path normalization churn.
- Do not repeat raw-`hdd0:` vs `pfs:/...` contract churn inside the already-failed partition-aware family.

### 5) Custom `fileXio` target-loading path

Failed commits:

- `08fffab` `Load HDD POPSTARTER via fileXio in embedded loader`
- `cdbdbe7` `Fix embedded loader build after fileXio HDD handoff change`

What this means:

- Do not revive the custom `fileXio` target-loader theory without materially new evidence.

### 6) Diagnostic-halt micro-probes after embedded-loader entry

Failed commits:

- `6bddf69`
- `11f1dc6`
- `78e0ee6`
- diagnostic rerun at `0a0b6e9`

What this means:

- Do not keep moving the same screen-backed halt a few lines earlier.
- Do not add another micro-probe in that same post-entry family unless you have a materially different observability source.

### 7) Normal-build keepalive / build-normalization alone

Failed commit:

- `0a0b6e9` `Normalize HDD embedded-loader default build path`

What this means:

- The issue is not solved just by:
  - removing accidental default diagnostic halts from the plain build
  - promoting the partitioned `ExecPS2` SIF-RPC keepalive into the normal path

### 8) Mounted HDD `pfs` direct-launch bypass / direct-loader variants

Failed commits:

- `26fc65d` `Prefer mounted HDD POPSTARTER path for direct launch`
- `59be355` `Use non-reboot direct loader for mounted HDD POPSTARTER`
- `d4a604e` `Use LoadExecPS2 for mounted HDD pfs launches`

What this means:

- Do not propose another mounted-`pfs` direct-launch shuffle unless you can point to a specific new code asymmetry that these three commits did not already cover.
- The following have already failed:
  - bypassing the partition-aware embedded loader
  - keeping the mounted `pfs` path on the non-reboot direct loader
  - swapping the mounted `pfs` argumented launch mechanism from `SifLoadElf()+ExecPS2` to `LoadExecPS2`

## Current Stop Point

Current plateau:

- Embedded-loader entry is proven.
- Later screen-backed diagnostic stages are not durable on hardware.
- The standard non-diagnostic path still fails.
- The mounted HDD `pfs:/...` direct-launch path still fails.

Therefore:

- Do not continue blindly mutating the same route-selection code.
- Do not continue blindly moving debug screens around.
- Do not keep toggling reboot / cleanup / wipe behavior.

The next useful step must be one of:

1. one genuinely new, code-backed asymmetry not already covered in `FAILURES.md`, or
2. one materially different observability method

If you cannot justify one of those two, stop and say so clearly.

## What A Valid Next Step Must Look Like

A valid next step must satisfy all of these:

- It is based on current repository code, not memory or guesswork.
- It is not already retired by a failed commit family above.
- It is narrow enough that regressions to USB/MMCE/MX4SIO/HDD list-browse are unlikely.
- It preserves selector contract unless the repo proves a new reason not to.
- It preserves working launch behavior outside the HDD-resident `POPSTARTER.ELF` problem.
- It can be validated through GitHub Actions artifacts plus user hardware testing.

Examples of valid justification:

- a new code asymmetry between the HDD failing path and a direct working path that is still present in current files and has not already been tested away
- a new observability method that is materially different from the exhausted `debug.h` / GS-color screen-flash approach

Examples of invalid justification:

- “maybe this other path normalization will help”
- “maybe another reset toggle will help”
- “maybe another selector shape will help”
- “maybe another earlier/later screen halt will help”
- “history suggests this used to work”

## Required Working Method

1. Read the required files listed above before changing anything.
2. Summarize the current live state in repo terms only.
3. Explicitly summarize:
   - the current repo-verified launch chain for HDD-resident `POPSTARTER.ELF`
   - which hypotheses have already failed
   - what new evidence, if any, justifies the next step
4. Identify exactly one new evidence-backed target, or explicitly state that no justified new target exists.
5. Explain why your target is not already covered by `FAILURES.md`.
6. Make only the smallest bounded diff, or make no code change.
7. Run the smallest available checks:
   - `git diff --check`
   - any targeted syntax or narrow sanity checks relevant to the touched files
8. Prefer changes that can be validated through GitHub Actions artifacts, since that is the actual test path.
9. Update docs only if the outcome changes what future agents need to know.
10. If you changed files, commit exactly one bounded change.

## Deliverables Format

Use this response structure:

- Summary: what changed and why.
- Diffstat: exact files changed.
- Diff: key hunks or exact description tied to code evidence.
- Test plan: what was run, what passed, what was not run.

Also include:

- If local PS2 toolchain/runtime validation was not run, say so plainly.
- If hardware is still unverified, say `Unknown (verify on hardware)`.

## Validation Constraints

- The user’s local non-PS2 environment is not sufficient to prove runtime behavior.
- Lack of a local PS2 toolchain is not a blocker for repo analysis.
- Do not ask the user to do non-artifact local validation.
- GitHub Actions workflow artifacts are the practical delivery mechanism for runtime testing.

## Success Criteria

Success is one of only two outcomes:

1. A genuinely new, evidence-backed minimal fix that is suitable for GitHub Actions artifact testing and does not regress working paths.
2. A disciplined stop that clearly states the branch has reached a plateau on currently-explored lines of inquiry, without repeating failed hypothesis families.

## Failure Conditions

You are failing the task if you do any of the following:

- repeat prior failed hypotheses without new evidence
- broad-refactor launch/detection systems
- break USB/MMCE/MX4SIO or HDD list/browse behavior
- claim a fix without hardware verification
- ignore `FAILURES.md`
- keep moving the same embedded-loader screen halt around again
- reshuffle mounted-`pfs` direct-launch routing again without a new asymmetry
- ask the user to rely on non-artifact local validation

## Final Reminder

This is an HDD-resident `POPSTARTER.ELF` problem only.

Do not let the branch drift into generic launch-plumbing churn.

Preserve what already works.

Require new evidence before every code change.

If there is no new evidence-backed target, say so instead of guessing.
