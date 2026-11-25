# -unfinished- audit checkpoint and resume index

This draft preserves the findings available on 2026-11-17. **The exhaustive audit is still in progress. Do not treat any unread file, unrun target build or unverified hardware path as passed.** No fixes are included.

The user initially required read-only review, then explicitly requested a draft PR containing all findings so far, marked `-unfinished-`, followed by continued review. This PR changes only `Codex-audit/`; all five audited source snapshots remain unchanged. It is hosted in RiptOPL as the common handoff for the five allowed repositories. The PR base may be newer than the immutable audited snapshots below.

Start with [the baseline summary](Codex-SUMMARY.md), which contains the first pass's top 25, quick wins, shared findings and validation results. Then read **all seven continuation finding files** linked below. The baseline counts/ranking/unread lists describe the earlier pass; the newer exact progress manifests supersede them. Final benefit ordering, ranking, cross-repo deduplication and report integration remain unfinished. CROSS-005 has already absorbed LAUNCHSTATION-022 and RIPTOPL-100 so this release finding appears once.

## Audited snapshots

| Repository | Branch | Audited commit |
| --- | --- | --- |
| RiptOPL | rebuild/main | `679d3d8626dd09a913e7081101418e337234fe7c` |
| Launchstation | master | `8cd3329a98c09a570bfbf60137717edd42324990` |
| POPSLoader | master | `29272cddbf0122f14e76bc3bdd75e3b46aa870be` |
| Simple-Media-System | master | `b9a5c882d6d632914faa4ff8dc080f1ecd51bfd7` |
| PS2-Servers | main | `5179b4bb1f488ef2eb91956c8792e2194dda2fca` |

## Preserved findings

| Earlier report | Additional findings |
| --- | --- |
| [RiptOPL](Codex-RiptOPL.md) | [Runtime/build/tools](continuation/ript_runtime-findings.md), [IOP/modules](continuation/ript_modules-findings.md), [Vendored code](continuation/ript_vendor-findings.md) |
| [Launchstation](Codex-Launchstation.md) | [Continuation](continuation/launch_remaining-findings.md) |
| [POPSLoader](Codex-POPSLoader.md) | [Root-owned continuation](continuation/root_remaining-findings.md) |
| [Simple-Media-System](Codex-Simple-Media-System.md) | [Continuation](continuation/sms_remaining-findings.md) |
| [PS2-Servers](Codex-PS2-Servers.md) | [Continuation](continuation/servers_remaining-findings.md) |

The earlier pass recorded 164 unique findings. The continuation files currently contain **160 additional finding IDs** (including explicit supplements that must be merged with their canonical earlier finding where indicated). Do not add raw heading counts to claim a final deduplicated total. Existing shared controller findings remain canonical in POPSLOADER-017, -018, -041 and -042, with all affected copies cited there. Cross-repository findings are canonical in the summary.

## Exact remaining review assignments

For each row, `*-scope.json` is the immutable assignment and `*-progress.json` records completed reads and the exact `remaining_paths`. Partial paths may also be present in the remaining list; the columns are not additive. Generated/literal structural review is explicitly distinguished from semantic code review. `coverage/` holds the baseline coverage manifests. These assignments cover source/header/build/workflow files plus the scripts/web/config extensions in `required-source-rule.json`; historical documents and binary/data assets still need their separately disclosed clutter/staleness/reference checks.

| Scope | Assigned files | Fully read in continuation | Structural reviews | Partial paths | Remaining-list files |
| --- | ---: | ---: | ---: | ---: | ---: |
| [launch_remaining](continuation/launch_remaining-progress.json) | 751 | 168 | 5 | 14 | 578 |
| [ript_modules](continuation/ript_modules-progress.json) | 596 | 196 | 1 | 1 | 399 |
| [ript_runtime](continuation/ript_runtime-progress.json) | 555 | 258 | 34 | 3 | 263 |
| [ript_vendor](continuation/ript_vendor-progress.json) | 290 | 214 | 2 | 1 | 74 |
| [root_remaining](continuation/root_remaining-progress.json) | 330 | 31 | 11 | 0 | 288 |
| [servers_remaining](continuation/servers_remaining-progress.json) | 457 | 209 | 0 | 2 | 248 |
| [sms_remaining](continuation/sms_remaining-progress.json) | 566 | 190 | 13 | 0 | 368 |

RiptOPL runtime, modules and vendor scopes are separate. The root scope contains all remaining POPSLoader items plus RiptOPL `.github` scripts/workflows. Do not assign overlapping reads to two reviewers. Read `remaining_paths` and `partial_paths` before resuming; a pending batch that was not acknowledged is not completed coverage.

## How to continue

1. Clone only the five repositories above and check out the listed commits. Consult their AGENTS/STATE guidance, subject to the user's stricter audit rules.
2. Continue each remaining file in the exact scope manifests, including comments, inactive code, build inputs, workflows and vendored implementations. Review generated tables structurally and record the limitation. Never display secrets or key material; keep those literals opaque.
3. Keep findings source-backed with exact read line numbers. Distinguish READ facts, host reproductions, declared capacities and INFERRED target savings. No PS2SDK build, real PS2 test, Windows GUI latency measurement or final ELF-size measurement has been performed.
4. Add only report/evidence changes on this draft branch; do not fix or rewrite audited source. The user's publication exception is for this audit handoff, not for applying recommendations or running workflows.
5. Merge supplements into their existing canonical finding, consolidate repeated problems once with all locations, sort the final per-repo reports by benefit, refresh the top 25/quick wins/work order, and replace old unread summaries from the reconciled ledgers.

The first pass's test results are preserved in the reports. Existing host suites were exercised, including 1,544 PS2-Servers tests (75 skipped; four environment failures because this host's `go` executable is not the Go compiler), Lua harness and targeted sanitizer/fault-injection repros. Do not reinterpret skipped/environmental checks as passes or rerun broad suites without a new reason. New documentation comparator/snippet evidence is in [root_research-js-evidence.json](continuation/root_research-js-evidence.json). Vendor build-closure/table records and SMS generated-structure records are also retained.

Local temporary harness binaries, downloaded dependencies and large raw terminal logs are not embedded in this PR. Findings retain source locations and methodology; regenerate the smallest necessary host reproduction when implementing a cited fix. No backup files are proposed or included. No licensing review or feature-stripped-build size comparison is part of this audit.


## Review correction pending

POPSLOADER-015 must be re-triaged before implementation: system.lua:8111–8118 and host_harness.py:1837–1839 explicitly prohibit replacing user-configured POPSTARTER addresses with a menu DHCP lease. The API has no Lua consumer, but that alone does not establish a handoff defect. Prefer investigating deletion of the unused getter/formatter at luasystem.cpp:2169–2209,2572 under the existing static configuration contract. Do not blindly apply the earlier lease-handoff recommendation. This qualification was discovered after the first draft snapshot.
