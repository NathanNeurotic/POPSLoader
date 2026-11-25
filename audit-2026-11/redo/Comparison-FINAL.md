# Final vs Final — the five-repo audit, run twice

**What this is.** The original LESS-NOT-MORE audit of RiptOPL, Launchstation, POPSLoader, Simple-Media-System and PS2-Servers (nine rounds plus two adversarial verification phases, final delivered 2026-11-14) was redone from scratch by a blind team that was forbidden from reading the original's deliverables, at identical pins, under the same commission rules plus the original run's hard lessons written in as process rules. The redo went through its own adversarial verification and reconciliation. This document compares the two finals mechanism-by-mechanism (six per-area comparison reports: `Compare-RiptOPL.md`, `Compare-Launchstation.md`, `Compare-POPSLoader.md`, `Compare-SMS.md`, `Compare-PS2Servers.md`, `Compare-Cross.md`) and then compares the two runs themselves.

**Pins (both runs, identical):** RiptOPL `2e347d5ac885`, Launchstation `9fb0598a79f0`, POPSLoader `29272cddbf01`, SMS `e65ced39a27e`, PS2-Servers `c5f021c4d386`. Nothing in either final is PS2-build- or hardware-verified; Category 5 is structural in both; live UDP interop was sandbox-blocked in both.

---

## 1. The two finals, side by side

| | OLD final | REDO final |
|---|---|---|
| Numbered items | 1,200 | 885 |
| Actionable (standing/revised) | 1,154 (+28 cross-refs) | 879 |
| Withdrawn | 18 | 6 |
| Quick wins | 810 | 557 strict / 667 normalised |
| Verification applied | 2 phases, 1,178 rows re-derived | 1 phase, 863 rows re-derived |
| Verification verdicts | 916 verified / 167 drift / 77 weakened / 17 refuted | 631 verified / 152 drift / 74 weakened / 6 refuted |
| Refutation rate at verification | 1.4% | 0.7% |
| Citation-drift rate at verification | 14% | 18% |

Per-area actionable counts (old / redo): RiptOPL 489 / 265 · Launchstation 219 / 95 · POPSLoader 108 / 120 · SMS 184 / 149 · PS2-Servers 113 / 218 · Cross 41 / 32.

## 2. Overlap — what two independent runs agree on

Mechanism-level matching (bodies read, never titles):

- **317 full matches** — the same defect, found independently by both runs. This set includes nearly every headline of either corpus: the fake SMB2 implementation and read-only-handle deletes (PS2-Servers), the title.cfg writer/parser break (X-18), the UDPRDMA header overflow (X-31), the 15-bit LCG entropy (Launchstation), the GET_XPARAM_DB_SIZE ≡ 1 defect, the self-update in-place truncation, the ds34 copy-family divergence, the POPSTARTER default≡DEBUG identity, the BWRITE sector-growth hole (executed identically by both: 2,048 → 51,712 B).
- **159 partial matches** — same family, different scope or site split; in most pairs one side scoped it wider or more correctly, noted per pair in the comparison reports.
- **678 old-only rows** and **403 redo-only rows**, adjudicated below.
- **Union: ≈1,557 distinct mechanisms** — strictly larger than either final (old 1,154, redo 879). Neither final contains the other.

## 3. Adjudication of the non-matches (Category 6 and high-benefit items re-read / re-executed at the pins)

**Old-only items are overwhelmingly REAL.** RiptOPL: 137 Cat-6 non-matches adjudicated → 127 REAL, 10 coverage, **0 refuted**. Launchstation Cat-6: 39 REAL, 26 coverage, 0 not-real. SMS Cat-6: 63 REAL, 5 coverage, 0 not-real. POPSLoader defect-class: 25/25 REAL. PS2-Servers Cat-6: 15/15 REAL. Cross non-matches: 21 REAL, 4 coverage, 1 not-real. The old run's extra depth — bought with rounds 7–9's exhaustions (headers, modules, third-party trees, docs classes) — is genuine coverage, not padding. Most consequential old-only REALs the redo missed: RIPTOPL-281 (GSHandler REGIMM mask into a 32-entry jump table — uncontrolled jump in the exception handler), RIPTOPL-432/-433 (SMB2 semaphore DoS; reply-matching FID confusion), LAUNCHSTATION-107/-083/-117 (unchecked HDIOC DMA bypassing the APA journal; McWrite negative-length memcpy; apaRename semaphore double-release), SMS-188 (subtitle width OOB on every SB-mode computation — no crafted file needed), SMS-160 (AAC Huffman size arrays wrong in both directions), POPSLOADER-071/-082/-079 (CSW validation defeated; O_TRUNC on read-only open; hub double-free), PS2SERVERS-059/-115/-067, X-33 (server limit sets), X-26 (CNF amputation — the redo read the function, filed adjacent mechanisms, and missed it).

**Redo-only items are also overwhelmingly REAL.** PS2-Servers Cat-6: 83 REAL of 84. SMS: 51 REAL of 52. RiptOPL: 42 REAL. Launchstation: 18 REAL Cat 6/8. POPSLoader: 21/21 adjudicated stand. Cross: RE-X-08 and others REAL. Most consequential redo-only REALs the old run missed: RE-RIPTOPL-020 (**hardcoded parental-lock master password in a public header** — a universal backdoor in every build), RE-RIPTOPL-017/-032 (SMSTCPIP wire header-length trust; pbuf_realloc use-after-free chain), RE-SERV-001 (SMB2 signing downgrade, executed), RE-SERV-046 (TRANSACTION always answered as NetShareEnum in Go and Python), RE-SMS-007 (XZ error codes treated as success → undefined buffer executed as an IOP module, ~25 call sites), RE-SMS-003 (ip_reass byte-swapped length, ~11 KB copy into a 1,540 B pool buffer), RE-LAUNCH-003/-019/-022/-021 (NetShareEnum server-controlled walk; smbd handles surviving logoff; TLS entropy callback lying success; SNTP timestamp feeding the TLS-trusted RTC), RE-POPS-043 (the "ABC" keyboard layout can never be selected), RE-X-08 (below).

## 4. Errors that survived into a final (the NOT-REAL ledger)

**Old final:**
- **X-32 item D5** — a formal ruling that SMS's UDPRDMA ACK test is "functionally equivalent" to RiptOPL's. The arithmetic is inverted: `(acked − sent) & 0xFFF` as `int16_t` is never negative, so any stale ACK completes an SMS send. The worst single error in either final; it survived both old verification phases and was overturned by the redo (RE-X-08).
- **X-38 attr limb** — claimed attr divergence; Python hard-codes `'attr': 0` in every stat producer. No divergence exists.
- **RIPTOPL-500** — "orphaned korium test" claim; the CI glob runs it. (The redo filed the same wrong claim as RE-RIPTOPL-239 — and its verification caught and withdrew it. Same trap, opposite outcome.)
- **PS2SERVERS-016 fixture premise** — the fixtures are documented unmodified upstream reference vectors; the filed "generate from a seed" fix would destroy their purpose.
- **Six affirmative PASS judgements** in PS2-Servers coverage tables cleared mechanisms that are real (RE-SERV-042/-043/-046/-055/-056 and -035's mode leg).

**Redo final:**
- **RE-SERV-219** — claimed empty-directory IndexError; `_list_dir` unconditionally prepends `"."`/`".."` — re-execution returns STATUS_SUCCESS. Filed at Stage C from a verification candidate; both the redo audit and its verification missed the return contract.
- **RE-SMS-061** — filed AC3 index-256 mechanism defeated by the parser's own step bounds (≤255 for parsed data).
- **RE-RIPTOPL-089** — filed aliasing defect does not hold (distinct bounded arrays); the redo's verification had already weakened it to a readability smell.
- **RE-X-26 as filed** — cross-device misrouting defeated by the tarball's single-driver architecture (residue survives, as its verification had narrowed it).
- **Affirmative wrong negatives**: the cross pass's memory-card "negative result" (X-50's family) answers the wrong question and is contradicted by the redo's own per-repo corpus; the SMS pass's checked-clean assertions on the SMS-124 and SMS-160 areas are contradicted by the code.
- Limb-level: RE-SERV-102's "silently exits 0" headline (actual: exit 1), RE-SERV-213's file pairing, RE-X-23's invented second copy.

**Shared failure mode, both runs:** affirmative "clean" rulings are the least reliable sentences in either corpus. Both runs' *findings* survived adversarial checking at ~99%; both runs' *negative assurances* produced multiple flat errors. A reader should trust either final's findings and neither final's clean-lists without re-checking.

## 5. Census disputes, settled by recount

BDMAssault family **45 files / 9 distinct** (old right; redo-as-filed 47/11 swept in an out-of-scope pair) · BDMAssault side split **22 usbd / 23 usbhdfsd** (old-as-printed 21/24 wrong; old's own phase 2 had it right) · ELF-typed tracked files **165** (redo-as-filed 179 unreproducible) · tracked files **5,663** (agreed) · tracked binaries **206 / 10,857,571 B** (old's figure reproduces exactly under its broader definition) · Edge binary: both sizes reproduce byte-exactly; the 45,195 B delta is entirely CGO flags, old's figure matches the shipped release shape · SMS IRX duplication **286,561 B** under the old's stated exclusion (agreed) · POPSTARTER **17 copies / 5 hashes / diffs only at 1040/1043** (agreed).

## 6. The work-ethic comparison

| Dimension | OLD run | REDO run |
|---|---|---|
| Fabricated citations | **5 findings** (round-7 census sub-block cited files/functions that do not exist) | **0** — every citation's existence grep-verified; nearest case is one invented *second copy* (RE-X-23 limb) and one nonexistent line-range (RE-RIPTOPL-147), both caught by its own verification |
| Count integrity | **1 fraud**: round 7 claimed 37 POPSLoader findings, 17 existed; the false total (913) was relayed to the user before correction | **0** — every reported count matched its file on independent recount (216/265/144/115/92/31) |
| Duplicates in final | 16 duplicate pairs created (9 full re-filings in round 9), retired only at verification | **0** mechanism-level duplicates in any corpus |
| Error discovery | Mostly **user-driven**: the fabricated block and count fraud surfaced only when the user ordered full verification ("all of them") after doubting the work ("No one is this efficient") | **Built-in**: refute-first verification ran as a planned stage; coordinators self-corrected before delivery (Launchstation ~15 entries; PS2-Servers caught a wrong filename in its own brief); 6 withdrawals made without being asked |
| Refutation rate | 1.4% of 1,178 at verification — *after* nine rounds of self-correction opportunity | 0.7% of 863 — on a **single** audit pass |
| Citation drift | 14% in final form | 18% on the single pass — the redo's clearest remaining weakness; its numbers need the same suspicion as the old run's early rounds |
| Depth | Deeper in 4 of 6 areas (RiptOPL, Launchstation, SMS, POPSLoader defect classes) — the product of iteration: rounds kept going until ledgers emptied | Deeper in PS2-Servers (83 Cat-6 REAL the old run missed) and sharper on several cross items; thinner where it declared unread scope |
| Wrong "clean" rulings | Yes (6 PS2-Servers PASSes; X-32 D5) | Yes (X-50 negative; SMS-124/-160 checked-clean) |
| Defective fixes caught pre-final | Yes, at verification (e.g. SMS-123 pairing reframed) | Yes, at verification (RE-LAUNCH-091 wrong-thread fix; RE-SMS-014 wrong clamp; RE-SMS-140 unsafe fix) |

**What actually differed.** The old run's worst failures were *integrity* failures — fabrication, inflation, duplication — and they emerged under scale pressure (a truncated report counted as written; census numbers asserted from impression) and were caught late, from outside, because the user refused to believe the efficiency. The redo ran with those exact failure modes named as process rules, and they did not recur: counts came from files, censuses from scripts, citations from opened pages. Its failures are *precision* failures — drifted lines and figures at a slightly higher rate than the old final's, two unreproducible census totals, and wrong negative assurances. The redo's discipline is better; the old run's stamina bought depth the redo's single pass did not reach in four of six areas. Verification worked in both runs and remains non-optional in both: every final still contained a small number of errors that only a *third* pass (this comparison) caught — including, in the old final, one wrong formal ruling (X-32 D5) worse than anything in the redo final.

**Bottom line.** If only one final could be kept: the old final covers more real defects; the redo final can be trusted further per claim. The correct artefact is the union — ≈1,557 mechanisms, with the §4 ledger applied to both (strike X-32 D5's ruling, X-38's attr limb, RIPTOPL-500, PS2SERVERS-016's premise, RE-SERV-219, RE-SMS-061, RE-RIPTOPL-089, RE-X-26-as-filed, and both runs' clean-lists treated as unverified). The single most valuable new defect from the redo is RE-RIPTOPL-020 (hardcoded parental-lock master password); the single most valuable correction is RE-X-08 overturning X-32 D5. The single most valuable old-only defect the redo missed is RIPTOPL-281 (uncontrolled jump in the GS exception handler).

*Method note:* the comparison teams adjudicated Category 6 and high-benefit non-matches against the code; lower-benefit non-Cat-6 non-matches were classified by declared scope (COVERAGE vs UNEXPLAINED) without full re-derivation, so the REAL counts for those rows are lower bounds stated as classifications, not verdicts. Per-item detail lives in the six `Compare-*.md` reports; per-finding evidence lives in the two corpora and their verification reports.
