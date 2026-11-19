# HANDOFF PROMPT — Implement the Sable LESS-NOT-MORE Audit Fixes

*Built 2026-11-14 by Sable, at the close of the five-repo audit. Paste this prompt, together with the audit package (the zip this file ships in), into the implementing agent's session. Everything the agent needs is either in this prompt or in the package.*

---

## 1. Your mission

You are the implementing engineer for a completed, verified, read-only audit of five PlayStation 2 repositories owned by Nathan Thomas Evans (GitHub: NathanNeurotic):

- **RiptOPL** (Open-PS2-Loader fork) — EE/IOP C/C++, assembly, Python test corpus
- **Launchstation** (wLaunchELF-derived file manager/launcher) — EE/IOP C, libsmb2, docs
- **POPSLoader** — Lua, EE/IOP C, the BDMAssault source tarball
- **Simple-Media-System (SMS)** — EE/IOP C, vendored codec/network stacks
- **PS2-Servers** — Windows PC servers (Go + Python editions)

The audit produced **1,200 numbered findings**. Your job is to implement fixes for the findings marked STANDING (and REVISED, as narrowed), in the order given in §6, under the rules in §4–§5. You are not re-auditing. If you believe a finding is wrong, you do not silently skip it: you stop on that finding, present the defeating evidence, and let the owner decide — the audit's two verification phases have now adversarially re-derived every finding (Category 6 in phase 1, everything else in the full-verification phase), so the burden of proof is on the new evidence.

## 2. Source of truth (in the package, in this order)

1. **`Sable-MASTER-INDEX.md`** — the single worklist. §2 lists every finding with category, effort, risk, confidence, status. §3(a) is the quick-win list (810 items). §3(b) is the Category 6 (bugs/security) top tier plus the rounds 7–9 extension. **§4 is the revision ledger (147 entries) — it overrides the original finding text wherever they differ.** §5 records method notes, including the citation-drift corrections and the tarball category note.
2. **`Sable-SUMMARY.md`** — narrative record: per-round addenda, the Round 7 correction, and the VERIFICATION PHASE and FULL VERIFICATION addenda (verdict totals, withdrawals, reopenings). Read both verification addenda before starting; they change what several findings mean.
3. **Per-repo report files** (`Sable-<Repo>.md`, `Sable-<Repo>-ROUND<n>.md`, `Sable-CROSSREPO-ROUND<n>.md`) — the full finding bodies: locations, problem, fix in words, justification, benefit, effort/risk/confidence.
4. **`Sable-VERIFY-*.md`** (5 files) — the adversarial re-verification record. For any finding marked VERIFIED-DRIFT, the corrected line citations live here and supersede the report's. For WEAKENED findings, the narrowed conditions here (mirrored in index §4) define the actual defect.
5. **`Sable-VERIFICATION-NEW-FINDINGS.md`** — six findings filed during verification (RIPTOPL-602, SMS-183, SMS-184, POPSLOADER-108, PS2SERVERS-114, PS2SERVERS-115). Same standing as any report finding.
6. **`PINS.md` / `PINS-ROUND2.md`** — the audit baselines. **`PROGRESS.md`** — the audit's own completion record.

**Full verification:** every STANDING/REVISED finding in this package has now been adversarially re-derived at least once at the pins — Category 6 in the verification phase (records in `Sable-VERIFY-*.md`), everything else in the full-verification phase (records in **`Sable-VERIFY2-*.md`**, 6 files: 939 verdict rows — 751 VERIFIED, 122 VERIFIED-DRIFT, 51 WEAKENED, 14 REFUTED, 1 environment-blocked). The same rule applies to the VERIFY2 files: their corrected citations supersede the reports', and their narrowed conditions (mirrored in index §4) define the defect. Twelve further findings were filed during full verification, collected in **`Sable-VERIFY2-NEW-FINDINGS.md`** (RIPTOPL-603, RIPTOPL-604, RIPTOPL-605; SMS-185…188; PS2SERVERS-116, -117, -118; X-58, X-59) — same standing as any report finding. The 14 phase-2 refutations are withdrawn (§5); five of them (PS2SERVERS-104, -105, -109, -110, -111) rest on fabricated citations and are named as such in index §4 and the SUMMARY's FULL VERIFICATION addendum.

## 3. Baseline — check before you touch anything

All findings are pinned to these heads (the "round-2 pins"; every round after round 2 ran at them, and they were re-verified unmoved seven times, last on 2026-11-14):

| Repo | Branch | Pin |
|---|---|---|
| RiptOPL | rebuild/main | `2e347d5ac885` |
| Launchstation | master | `9fb0598a79f0` |
| POPSLoader | master | `29272cddbf01` |
| Simple-Media-System | master | `e65ced39a27e` |
| PS2-Servers | main | `c5f021c4d386` |

**Freshness rule:** before working a repo, compare its live HEAD to the pin. If it matches, proceed. If it has moved, do NOT improvise: produce a delta note (which findings' cited files changed since the pin, per `git log`/`git diff` on those paths) and re-validate each affected finding's citation against the new head before implementing it, marking it REVALIDATED or STALE in your report. A finding whose mechanism no longer exists at the live head is reported, never forced.

## 4. THE MAIN RULE: LESS, NOT MORE

This governed the audit and it governs your fixes:

- Prefer **remove, simplify, consolidate, or fix** over adding anything. If the simplest correct fix is "delete it", delete it.
- **No** new abstraction layers, frameworks, configuration options, wrapper functions, fallback paths, retry logic, backup files (`.BAK` is banned), logging systems, or future-proofing — unless the finding's own Justification field argues a concrete problem and a net win, in which case implement exactly what the finding justifies and no more.
- A shared helper is allowed only when the same logic exists in 2+ places AND sharing removes code overall.
- Preserve existing architecture, semantics, and compatibility. Minimal, isolated, evidence-backed changes. No speculative modifications, no unrelated refactoring, no reformatting sweeps beyond what the touched lines need.
- Every finding already contains its fix in words. Implement that fix. If you find a materially better one that is also smaller, note the deviation and why in your report; never expand scope silently.

## 5. Status discipline — what you may work

Current totals: **1,200 numbered items = 1,054 STANDING / 100 REVISED / 28 CROSS-REF / 18 WITHDRAWN → 1,182 actionable-scope items (not withdrawn; 1,154 of them standing + revised).**

- **STANDING** — work it as filed.
- **REVISED** — work it **only as narrowed** by its index §4 ledger entry. The original text overstates several of these (e.g. SMS-115/-116's trigger, X-49's union figure — the true figure is 9/10, X-18's blast radius — only the Apps → Edit-metadata path is broken). The §4 entry is the finding.
- **CROSS-REF** — do NOT work it. It is a retired duplicate; the §4 entry names the canonical finding to work instead.
- **WITHDRAWN** — never work these; the defects do not exist as filed: LAUNCHSTATION-065, RIPTOPL-513 (its prescribed "fix" is an identity transformation), RIPTOPL-443 (the sole caller already guards it), SMS-015 (its proposed fix already exists in the code as `_tbl_fits`) — plus the full-verification phase's 14: RIPTOPL-051 (the `size <= 0` guard is a live `size == 0` exit), RIPTOPL-348 (a test-harness caller generates the calls), LAUNCHSTATION-100 (the function sits inside a never-defined `#ifdef` with zero callers), LAUNCHSTATION-127 (the escape helpers fail rather than truncate; truncation is arithmetically unreachable), LAUNCHSTATION-214 (the Deckard gate exists and is consumed; the README is correct), X-57 (POPSLoader's PROVENANCE.json records both .udpfs files — the residue is filed as X-59), SMS-013 (the allocation already sits inside the video branch), SMS-089 (the preflight walk returns before entropy data), SMS-123 (see below), and PS2SERVERS-104, -105, -109, -110, -111 (**fabricated citations** — the files and functions they cite do not exist at the pin).
- **Confidence labels:** READ = the auditor read the code; INFERRED = mechanism reasoned but not fully provable from source. For INFERRED items, resolve the inference during implementation if your environment allows (build, run, hardware); if it cannot be resolved, implement only the part that is READ-provable and flag the rest.
- **SMS-123 — closed, do not work it:** SMS-123 is WITHDRAWN. Its withdrawal rationale was falsified in verification phase 1, which reopened it; full verification then proved — by two independent script derivations — that the AAC Huffman segments tile exactly, so no reachable out-of-bounds read exists. SMS-160 stands alone; the bounds-pairing survives only as guidance if the reorder is ever done as defence-in-depth (§7).

## 6. Order of work

Work repo by repo, in this order inside each repo:

1. **Category 6 first** — index §3(b) (original top tier + rounds 7–9 extension). These are the memory-safety, protocol, and data-loss defects. Within Cat 6, the executed/host-reproducible ones first where a test can prove the fix.
2. **Quick wins** — index §3(a) (S-effort, Low-risk). Batch these tightly; they are the bulk (810).
3. **Everything else standing**, by the reports' benefit order (each report file is already sorted by benefit).
4. **Cross-repo (X-) findings** when you reach the repos they touch — several are single fixes spanning two repos (§7).

Suggested repo sequence: PS2-Servers (host-executable, fastest verified wins, incl. the SMB2 safety set) → Launchstation (LAUNCHSTATION-187 turns CI green) → RiptOPL → SMS → POPSLoader. The owner may reorder; the per-repo internal order above stands regardless.

## 7. Sequencing constraints and interlocks (do not split these)

- **SMS-160 (SMS-123 is withdrawn — the pairing is guidance only):** full verification proved SMS-123 has no reachable out-of-bounds read (the Huffman segments tile exactly), so there is no combined defect item; SMS-160 stands on its own. If anyone nevertheless reorders -123's check as defence-in-depth, it must be paired with SMS-160's corrected bounds: a reorder-only fix using the declared bounds would use wrong bounds (declared = actual + 1 for codebooks 1/2/4/6/10), and a `>=`-on-declared-count check would falsely reject codebook 11's valid offset 373.
- **SMS-170 + SMS-183 (one item):** fixing the missing guard inside `netconn_addr` alone relocates `lwip_getsockname`'s crash to its uninitialised-`naddr` deref. The caller-side return checks in SMS-183 must land with it.
- **X-18 (one fix, two repos):** Launchstation's Apps-path writer emits `title = %s` into title.cfg; RiptOPL's parser silently drops that form. Fix the writer (the second, correct writer at `filer_actions.c` `make_title_cfg()` is the model). Do not "fix" RiptOPL's parser to accept the broken form unless the owner directs it.
- **RIPTOPL-400 / -401:** note the verification phase's fix-sequencing remark (the -145 receive-path fix interacts) — read the VERIFY-RiptOPL close-out notes before ordering the smbman work.
- **RIPTOPL-431 / -436 / POPSLOADER-108:** same defect family (date conversion; READ CAPACITY +1; GPT sectorCount +1) in different codebases — fix each in its own repo; do not import code across repos.
- **STOP_UNIT/STOP_ALL swap exists twice** (POPSLOADER-077 in the tarball tree, RIPTOPL-430 in RiptOPL's own bdm) — fix both, independently.
- **BDMAssault tarball (POPSLoader):** per REV-006/R7-REV-006 it is a documented source pin for the bdm_assault half — extract-or-archive, never plain-delete. The shipped `usbhdfsd.irx` is disassembly-verified to be an MX4SIO v1.2 driver with no source anywhere (POPSLOADER-069) — flag any change touching it to the owner before acting.
- **Vendored trees (RiptOPL third_party):** mbedTLS is byte-identical to official 3.6.7, PSUManager core byte-identical to its pinned upstream, ps2sdk-socket byte-identical to ps2sdk — do not patch vendored bodies; the third-party findings are integration-level (build lists, asset admission, test enforcement). If a fix seems to require editing pristine vendored code, stop and report.
- **SMS-161:** the four missing DTS scale-factor values exist only in the DTS specification / reference-decoder tables. Obtain them from a cited spec/reference source and name that source in the commit; **never interpolate them** from the table's progression.

## 8. Repository working rules (the owner's standing rules)

- Work only on your own agent branches (e.g. `agent/fix-<finding-id>` or per-batch branches). **Never commit to `main`/`master`/`rebuild/main` or anyone else's branch. The owner personally handles all merges.**
- No merges, releases, tags, or destructive operations without the owner's explicit authorization.
- Engineering cycle per fix: clean baseline → isolate the fault → smallest viable fix → validate before proceeding. One finding per commit where practical; tight quick-win batches may share a commit only if every message lists every finding ID it closes.
- Commit messages cite finding IDs (e.g. `RIPTOPL-401: bound the negotiate domain copy (Sable audit)`).
- **Secrets:** the audit located secret-like values in exactly two places (Launchstation's cloud OAuth material via `scripts/gen_cloud_client.py`; PS2-Servers `smb2_server/smb2_server.py:44`). Never print, quote, commit, or log their values — refer to them by location only. If a fix touches those files, the owner reviews that diff personally.
- Licences are settled — do not flag, relicense, or "fix" them. Do not copy saildot4k's wLaunchELF/R3Z builds or code for size wins. OPL Lattice is not the owner's project; never attribute it to him.

## 9. Validation — a build is not proof

- **PS2 code (RiptOPL, Launchstation, POPSLoader, SMS):** a successful build is necessary, never sufficient. Nothing in the audit is hardware-verified, and your fixes are not "done" until they run on real PS2 hardware or the owner accepts them as build-tested-only. Label every result exactly: **hardware-verified / build-tested / untested**. Never present an emulator or build result as console-proven. (Exception: RIPPCSX2 — the owner's fork — is the accepted stand-in where he has designated it; stock PCSX2 is not a substitute for homebrew testing.)
- **Host code (PS2-Servers Go/Python; Launchstation and RiptOPL Python suites):** run the existing test suites before and after. Known baselines from the audit's execution passes: PS2-Servers Go suite fails exactly 99 tests on UDP-blocked sandboxes (all UDP-traced — on an unrestricted host they should run; treat any non-UDP failure as yours until proven otherwise); Python suite 1,544 tests with the same UDP caveat. Launchstation's `test_copy_psu_listing.py` fails deterministically (SIGABRT) until LAUNCHSTATION-187 is fixed — its passing is that fix's acceptance test.
- **Test findings are fixes to tests:** several findings (e.g. RIPTOPL-298, -302, PS2SERVERS-071…075) say a test is vacuous or asserts wrong behaviour. Fix the test to assert the true behaviour the finding documents — never weaken an assertion to make a suite green, and never delete a failing test without the finding saying so.
- **Format gates:** where a repo has a CI format/lint gate, run it with the CI-pinned tool version and show the result. A red gate is a failed fix.
- If a validation step cannot be run in your environment, say so explicitly in the report for that finding — before the owner merges, not after.

## 10. Reporting (per repo batch / PR)

For each finding you close, report:

```
Finding: <ID> — <title>
Status worked: STANDING / REVISED (as narrowed by §4 entry <n>)
Change: <files, one-line diff summary, net lines added/removed>
Validation: <what ran — build / suite / hardware — and its result, labelled per §9>
Deviations: <any departure from the finding's stated fix, and why> (or "none")
Residual: <anything left unverified or owner-decision-pending> (or "none")
```

Per batch, also report: findings attempted vs closed, any finding you stopped on (with the defeating evidence or the blocker), and the branch name. Do not report a batch as complete while any of its fixes is unvalidated without the §9 label saying so.

## 11. Stop conditions — halt and ask the owner

- A repo's live HEAD has moved off its pin and your delta note shows a finding's mechanism is gone or materially changed.
- A fix would add net code without the finding's own Justification covering it (violates §4).
- A fix touches the two secret-like locations (§8), the BDMAssault tarball's disposition, or `usbhdfsd.irx`.
- Validation requires real PS2 hardware you do not have: park the finding as "awaiting hardware", continue with independent work, and list it in the batch report — do not guess the result.
- Two findings' prescribed fixes conflict (the audit's consistency census found none unresolved, but if the code proves otherwise, surface it).

## 12. What "done" means

A repo is done when every STANDING and REVISED finding in it is either (a) implemented, validated, and reported per §10, (b) parked under a §11 stop condition with the blocker named, or (c) defeated by new evidence the owner has accepted. The audit's numbers to close against: RiptOPL 504 items (incl. RIPTOPL-602…605), Launchstation 223, POPSLoader 108 (incl. -108), SMS 188 (incl. -183…188), PS2-Servers 118 (incl. -114…118), cross-repo X-01…X-59 — 1,200 total, 1,182 in actionable scope, 810 of them quick wins.

The audit was read-only and stays that way: all changes from here are yours, on your branches, under the owner's merge authority.

— Sable, 2026-11-14
