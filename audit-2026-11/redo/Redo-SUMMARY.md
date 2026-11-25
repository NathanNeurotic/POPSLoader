# Redo Audit — Summary (Stage C reconciliation)

## Method

A **blind redo** of the five-repo LESS-NOT-MORE audit, in three stages:

- **Stage A — blind audit.** Six workstreams (five repos + cross-repo) audited the clones at the pins below. No auditor had access to any prior audit: nothing under `~/workspace/Sable-audit/` was read, listed, or grepped at any stage of the redo. Output: six reports, **863 findings** (`Redo-RiptOPL.md`, `Redo-Launchstation.md`, `Redo-POPSLoader.md`, `Redo-SMS.md`, `Redo-PS2Servers.md`, `Redo-Cross.md`).
- **Stage B — adversarial verification.** Independent verifiers re-derived **every** finding at the pin, refute-first: every cited file/function/string grep-checked for existence, the mechanism re-derived from the code (callers, guards, types, arithmetic), executed claims re-executed, prescribed fixes checked for sanity and LESS-NOT-MORE compliance, and a mechanism-level duplicate scan run over each corpus. Output: six verify reports (`Redo-VERIFY-*.md`) with a verdict for all 863 findings and 94 candidate defects noticed along the way.
- **Stage C — reconciliation (this stage).** Statuses assigned in `Redo-MASTER-INDEX.md`; the 6 refuted findings withdrawn (note added in each redo report, defeating evidence in the index); the 94 candidates screened exactly once each — 22 numbered as new findings in `Redo-NEW-FINDINGS.md`, 57 recorded as fix-scope extensions in their parent findings' index rows, 15 rejected with reasons (index Appendix A). Finding bodies were not rewritten: for STANDING-DRIFT findings the verify reports' corrected values supersede the filed ones, and for REVISED findings the index row's narrowed scope supersedes the filed scope.

**Pins** (clones in `~/workspace/audit-clones-2026-11-13/`, read-only throughout; HEADs and clean status re-verified at the end of Stage C):

| Repo | Pin |
|---|---|
| RiptOPL (rebuild/main) | `2e347d5ac885cd0ff73e9ad4143781946396f492` |
| Launchstation (master) | `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` |
| POPSLoader (master) | `29272cddbf0122f14e76bc3bdd75e3b46aa870be` |
| Simple-Media-System (master) | `e65ced39a27eee8d996e9257e21594d1cac1c93d` |
| PS2-Servers (main) | `c5f021c4d38698860f56b03498adc261dbb8d8dd` |

Supporting trees: Launchstation's libsmb2 was audited/verified from its pinned upstream tree `a52c1571a1ff223bde5bb3df9fec7af5ce3855d4` plus the repo's 2 patches (it is not vendored in the clone). POPSLoader's BDMAssault tarball was extracted and md5-verified (`09ff4b911ba131468a25d0ec9a4e2f27`) for both audit and verification.

## Final counts by status

| Repo | STANDING | STANDING-DRIFT | REVISED | WITHDRAWN | New (Stage C) | Total numbered |
|---|---|---|---|---|---|---|
| RiptOPL | 192 | 47 | 23 | 3 | 3 (RE-RIPTOPL-266…268) | 268 |
| Launchstation | 48 | 33 | 10 | 1 | 4 (RE-LAUNCH-093…096) | 96 |
| POPSLoader | 73 | 27 | 15 | 0 | 5 (RE-POPS-116…120) | 120 |
| SMS | 110 | 20 | 13 | 1 | 6 (RE-SMS-145…150) | 150 |
| PS2-Servers | 191 | 16 | 8 | 1 | 3 (RE-SERV-217…219) | 219 |
| Cross-repo | 17 | 9 | 5 | 0 | 1 (RE-X-32) | 32 |
| **Total** | **631** | **152** | **74** | **6** | **22** | **885** |

Actionable findings (everything except WITHDRAWN): **879**. Withdrawn: RE-RIPTOPL-056, RE-RIPTOPL-093, RE-RIPTOPL-239, RE-LAUNCH-007, RE-SMS-001, RE-SERV-128 — each carries a WITHDRAWN note in its redo report and the defeating evidence in its index row. One further sub-claim refutation is recorded on RE-X-23's row (the finding itself stands as STANDING-DRIFT with reduced fix scope).

## Verification verdict table (Stage B, all 863 findings)

| Repo | VERIFIED | VERIFIED-DRIFT | WEAKENED | REFUTED | BLOCKED-ENV |
|---|---|---|---|---|---|
| RiptOPL | 192 | 47 | 23 | 3 | 0 |
| Launchstation | 48 | 33 | 10 | 1 | 0 |
| POPSLoader | 73 | 27 | 15 | 0 | 0 |
| SMS | 110 | 20 | 13 | 1 | 0 |
| PS2-Servers | 191 | 16 | 8 | 1 | 0 |
| Cross-repo | 17 | 9 | 5 | 0 | 0 |
| **Total** | **631** | **152** | **74** | **6** | **0** |

Notes: no mechanism-level duplicates were found in any of the six corpora. Two findings carry BLOCKED-ENV *aspects* only (RE-SERV-068's 32-bit execution, RE-SERV-188's multiclient execution); their finding-level verdicts are VERIFIED and VERIFIED-DRIFT respectively, so BLOCKED-ENV is 0 at finding level. The POPSLoader verify report's closing-tally table omits RE-POPS-083 from its VERIFIED-DRIFT ID list (26 listed vs 27 claimed); its §1 master table marks RE-POPS-083 VERIFIED-DRIFT and the arithmetic (73+27+15=115) reconciles only with it included — Stage C followed §1.

## Candidate screening (Stage B candidates)

**94 candidates** were extracted from the six verify reports and each was classified exactly once (the PS2-Servers verify report's consolidated "9 candidates/hazards" is 8 candidates plus a fix hazard on RE-SERV-166, which is not a candidate and was excluded):

| Class | Count | Disposition |
|---|---|---|
| (a) NEW | 22 | Numbered and written in full in `Redo-NEW-FINDINGS.md` |
| (b) FIX-SCOPE EXTENSION | 57 | Recorded in the parent finding's row in `Redo-MASTER-INDEX.md`; no number of their own |
| (c) REJECTED | 15 | Listed with one-line reasons in the index, Appendix A |
| **Total** | **94** | |

Per repo — RiptOPL 21 (3/16/2), Launchstation 22 (4/14/4), POPSLoader 21 (5/12/4), SMS 16 (6/7/3), PS2-Servers 8 (3/4/1), Cross 6 (1/4/1), in NEW/EXTENSION/REJECTED order. One cross-repo candidate (Cross CAND-01) extends a per-repo finding (RE-SERV-030) and is recorded on that row.

## Quick wins

Quick win = final status STANDING, STANDING-DRIFT or REVISED, with **Effort S and Risk Low as filed**, counted from the master index:

| Repo | Quick wins (strict) |
|---|---|
| RiptOPL | 187 |
| Launchstation | 76 |
| POPSLoader | 82 |
| SMS | 12 |
| PS2-Servers | 154 |
| Cross-repo | 24 |
| **Total (863 originals)** | **535** |

Scale caveat: five workstreams filed Effort as S/M/L and Risk as Low/Med/High, but the SMS workstream used a word scale (Effort: Trivial/Small/Medium; Risk: Low/Negligible/Very low/None-phrases). Normalising SMS's own small-effort tier (Trivial, Small) and low-risk tier (Low, Negligible, Very low, and its "None"-phrased risks) to S/Low adds 110 SMS quick wins, for a normalised total of **645**. All 22 new findings are Effort S / Risk Low, adding 22 under either counting: **557 strict / 667 normalised** across the full 885-finding corpus.

## Files-not-read residue (carried from the redo reports)

Everything below was **not** line-read during Stage A; no finding cites it. Per-workstream detail is in each redo report's closing coverage section.

- **RiptOPL:** licence texts (settled by instruction, never opened); binaries hashed/sized by script, not disassembled (IOPRP.img, debug IRX set, bdmassault blobs, all `ship/` binaries); vendored bodies at integration level only (mbedTLS ~280 files, PSUManager core, `third_party/ps2sdk-socket`, FatFs `ff.c`/`ffunicode.c` at function-inventory level); partial reads of `src/gfx` (3 files), DES/MD4 copies and `smap.c` copies (diff-assessed); ~60 of ~70 `docs/*.md` covered by scripted path-existence extraction and targeted greps rather than line-reading (**the one real coverage gap**); the 286 `.github/scripts` suites were executed and script-censused but ~120 per half were not read end-to-end; `tests/smb2-live/` and `tests/nfs-live/` not run live (need Samba/SDK headers this VM lacks).
- **Launchstation:** most `src/dash_*.c`, `src/mc_*.c`, `src/mmce_*.c` bodies beyond cited ranges; `windows/cloud-relay/` unread; unpatched libsmb2 internals (crypto/asn1/spnego encoders, `lib/ps2/`, client-only middles of `libsmb2.c`) pattern-scanned only; precompiled IRX blobs not decoded; usmb2 Z80 stack unread (not in the IOP build); `ps2hdd_osd` journal/password, `pccf`, `ds34bt` full parser and `smap.c` skimmed or unread; several `scripts/*.py` bodies not read in full (executed indirectly); `loader/loader.c:121-446`; docs legacy/plans remainders sampled; live suites (`tests/*_live/`) not run (need Samba/root/kernel NFS).
- **POPSLoader:** generated `src/elf_loader/loader.c` hex payload (lines 81–8740; generator child source read in full); tarball `ff.c` and the `ffunicode.c` tables structurally scanned only; tarball merged-tree copies established by scripted 37-pair diff rather than independent line-reads; `bin/POPSLDR/system.lua` I18N tables (lines 2568–4843) script-censused, not proofread; `iop/ata_bd_fast/ps2atad.c:801-1186` not full-read; `.research/**` (115 files) keyword-scanned + sample-read; `docs/archive/**` (17 files) grep-swept; external dependencies (`usbhdfsd-common.h`, PS2SDK headers) not present in either tree.
- **SMS:** EE/IOP assembly structure-scanned only (`libmpeg_core.S`, `SMS_IPU_0.s`, DSP/GS/RC/Timer `.S`/`.s`, SMSTCPIP `inet.s`); `include/SMS_GS.h` body composition-sampled; `src/SMS_GS_1.c` and most of `src/SMS_GS_2.c` not line-audited; smbman-sms crypto/auth (`des.c`, `md4.c`, `auth.c`) and ~888 lines of USBD structure-only; vendored `xz*.h`/`lzma2.h`/`mbstring.h` bodies beyond guard/declaration checks; `tools/sms_converter`, `mpeg_color_probe`, `mpeg_motion_probe`, `libsd` bodies census-only; generated docs HTML, DocBook XML, `CHANGELOG.md` beyond head+census, and `docs/investigations/**/*.md` bodies not read.
- **PS2-Servers:** vendored rcheevos C library (`vendor/retroachievements/rcheevos/**`) at integration surface only; small C conformance probes' bodies and `conformance/fixtures/handshake_cases.json` not line-audited; conformance/integration runner bodies read for wiring only; `docs/*.html` beyond claims checks and most `docs/*.md` prose beyond defaults/claims spot-checks not proofread; binary fixtures/assets censused by script only; root meta files read as claims only. All in-scope Go and Python source and test files were read in full.
- **Cross-repo:** the Neutrino `-gc` compat-digit divergence was recorded but not filed (the reader is in no clone, so it fails the both-sides-traced rule); Launchstation `smbd` signing behaviour could not be traced in-repo (libsmb2 not vendored); memory-card parsers and 13 of 20 traced format pairs checked out clean and are recorded as negative results in `Redo-Cross.md`, not findings.

## Environment limits

- **No PS2 build exists in this VM** (no PS2SDK / ps2build toolchain): no finding in the redo corpus is build-verified on target, and **nothing is hardware-verified**. Category 5 (performance) findings are structural only.
- **The sandbox blocks UDP `sendto`:** live UDP interop is untestable here. PS2-Servers test failures traceable to the block were classified as environment limits, not repo defects (Go suite: all 99 failures UDP-traced; the UDPFS multiclient selftest was read but could not be executed). Host-side executions that were possible (Go/Python test suites, Python server handler probes, Edge binary builds, hash/decompression checks) were run in /tmp copies and are labelled EXECUTED in the reports.
- Executed PS2-Servers baselines, for reference: Go 246 top-level tests — 145 pass / 99 fail (all UDP-blocked) / 2 skip; Python `unittest discover` 1,544 run — 1,388 pass / 3 fail / 73 errors / 80 skip in the audit run (verifier's rerun: 1,389 pass / 72 errors; the one claimed genuine failure, `test_nfs4_server`, proved timing-fragile — see RE-SERV-218).

## Deliverables of the redo

`Redo-RiptOPL.md`, `Redo-Launchstation.md`, `Redo-POPSLoader.md`, `Redo-SMS.md`, `Redo-PS2Servers.md`, `Redo-Cross.md` (Stage A) · `Redo-VERIFY-RiptOPL.md`, `Redo-VERIFY-Launchstation.md`, `Redo-VERIFY-POPSLoader.md`, `Redo-VERIFY-SMS.md`, `Redo-VERIFY-PS2Servers.md`, `Redo-VERIFY-Cross.md` (Stage B) · `Redo-MASTER-INDEX.md`, `Redo-NEW-FINDINGS.md`, `Redo-SUMMARY.md` (Stage C). Section working files under `redo-sections/`, `verify-sections/`, `verify-launch-sections/`, `verify2-sections/`, `redo-verify-sections/`; Stage C extraction files and the index builder under `reconciliation/`.
