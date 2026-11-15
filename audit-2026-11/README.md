# Five-repo audit — both finals + comparison (reports only)

This folder contains the complete deliverables of two independent LESS-NOT-MORE audits of **NathanNeurotic/POPSLoader** at commit **29272cddbf01** (branch `master`), plus the mechanism-level comparison of the two finals. It is documentation only: **no code in this repository is changed by these files.** The accompanying pull request is a draft, opened at the owner's direction as a delivery vehicle; whether anything here is ever merged or implemented is the owner's decision.

## The two runs

- **Original audit** (`old/`) — nine rounds over 2026-11-13/14 plus two adversarial verification phases. Final: 1,200 numbered items across five repos, 1,182 actionable, 18 withdrawn. Start with `old/Sable-SUMMARY.md` and `old/Sable-MASTER-INDEX.md` (the index's §4 ledger overrides original finding text where they conflict). Implementation guide: `old/Sable-HANDOFF-PROMPT.md`.
- **Blind redo** (`redo/`) — a second team re-audited from the code alone, forbidden from reading the original's deliverables, then went through its own adversarial verification and reconciliation. Final: 885 numbered items, 879 actionable, 6 withdrawn. Start with `redo/Redo-SUMMARY.md` and `redo/Redo-MASTER-INDEX.md`.
- **Comparison** (`redo/Comparison-FINAL.md` and `redo/Compare-*.md`) — every finding in both finals matched mechanism-by-mechanism; non-matching Category 6 items were adjudicated against the code (REAL / NOT-REAL / COVERAGE). Union of the two finals: ≈1,557 distinct mechanisms. Neither final contains the other.

## This repo

Old final: 108 actionable findings. Redo final: 120 actionable. Independent overlap: 39 full matches + 10 partial (old-anchored). No finding in either final's final form was ruled not-real for this repo.

**Most consequential old-only finds:** POPSLOADER-071 (CSW validation defeated by a pre-filled receive buffer), POPSLOADER-082 (`fs_open` honours O_CREAT/O_TRUNC on a read-only open), POPSLOADER-079 (hub double-free on unplug), POPSLOADER-066 (CI parity check that never compares the committed dump).
**Most consequential redo-only finds:** RE-POPS-003 (pademu SIO2 parsing: no length floor, unchecked multitap slot index), RE-POPS-023 (both ELF loader stages copy segments to header-supplied addresses unvalidated), RE-POPS-009 (Bluetooth handlers ignore received byte counts), RE-POPS-043 (the "ABC" keyboard layout can never be selected — the normalizer maps it to QWERTY on every persistence path).

## Strike list — do not implement as filed

- None in final form. Two redo claims were narrowed by the redo's own verification before final (RE-POPS-008's over-read limb, RE-POPS-041's "no recorded hash" sub-claim) — read those two in their revised form in `redo/Redo-MASTER-INDEX.md`.

(Cross-repo strikes that affect every repo: old X-32 item D5's equivalence ruling is overturned by RE-X-08; old X-38's attr limb does not exist. Both finals' affirmative "this area is clean" lists should be treated as unverified — each run produced several wrong ones.)

## Layout

- `old/` — original audit: per-repo reports and round files, verification reports (`Sable-VERIFY-*`, `Sable-VERIFY2-*`), cross-repo reports, master index, summary, pins, handoff prompt, and section-level evidence.
- `redo/` — redo audit: per-repo reports (`Redo-*`), its verification reports (`Redo-VERIFY-*`), new findings from verification (`Redo-NEW-FINDINGS.md`), master index, summary, and the comparison reports (`Compare-*.md`, `Comparison-FINAL.md`) with their evidence sections.
- Shared/global files (indexes, summaries, cross-repo reports) are included in every repo's package because the cross findings and indexes span all five repositories.

## Archives (download links expire 2026-11-17 ~10:55 UTC; anyone with a link can download)

- Both finals + comparison, all five repos (699 files, 6,078,940 B, SHA-256 `52824c1ac885f9047003d2ada77d8d3c47ca5b61819fb1d7b7474033c3cbb862`): https://muse.ai/files/570121466194596/2866327167094404/ckbdv71m8bppkfs4su9uz67z/Sable-audit-BOTH-FINALS-2026-11-15.zip
- This repo's package: https://muse.ai/files/570121466194596/1622190858937558/x920890byqmv35c6dq0jjthl/Sable-audit-POPSLoader-both-finals-2026-11-15.zip
- Original final only (564 files, SHA-256 `2773df7c03bce277449a0acd293c63a50fe1177824ddcacc02f7885662d7388d`): https://muse.ai/files/570121466194596/1668795564645485/t1kdjzqeri3kpji8hi2aw4b5/Sable-audit-complete-2026-11-14.zip

## Limits

Nothing in either audit is PS2-build- or hardware-verified (no PS2SDK in the audit environment); performance findings are structural; live UDP interop was sandbox-blocked. Pins: RiptOPL `2e347d5ac885`, Launchstation `9fb0598a79f0`, POPSLoader `29272cddbf01`, Simple-Media-System `e65ced39a27e`, PS2-Servers `c5f021c4d386`.
