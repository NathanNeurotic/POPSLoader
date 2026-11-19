# FULL-VERIFICATION — Cross-repo (X-) findings, Phase 2 (2026-11-14)

Adversarial re-derivation of the cross-repo findings at the round-2 pins. Stance: refute-first; a finding survives only where the evidence proves it. Census and identity claims were RE-RUN (cmp/sha256 on the files at the pins, scripted re-counts, fork diffs, executed Python probes), not merely re-read. Category 5 content is structural only, as throughout the audit. Worker evidence trails: `verify2-sections/verify2-cross-{A,B,C,D}.md`.

**Pins (verified at start and end; clones clean, read-only held):** RiptOPL `2e347d5ac885`, Launchstation `9fb0598a79f0`, POPSLoader `29272cddbf01`, Simple-Media-System `e65ced39a27e`, PS2-Servers `c5f021c4d386`.

## Scope and exclusions

In scope: **51 findings** — X-01…X-57 minus six exclusions:

- **X-17, X-23** — CROSS-REF status (retired duplicates); skipped per brief.
- **X-18** — REVISED; its narrowed version was verified in phase 1 (Sable-VERIFY-OTHERS-CAT6.md). Excluded here.
- **X-49** — REVISED; census re-derived in phase 1 (union corrected to 9/10). Excluded here.
- **X-50** — verified in phase 1 (VERIFIED-DRIFT). Excluded here.
- **X-31** — verified in phase 1 (Sable-VERIFY-RiptOPL-CAT6.md). Excluded here.

Note on drift: several X-01…X-16 findings were filed at the *pass-1* pins; where a figure moved between the pass-1 and round-2 pins, the verdict is VERIFIED-DRIFT with the movement identified as pin drift, not auditor error.

## Verdict table (51 rows — totals below are counted from this table)

| ID | Verdict | Basis (one line) |
|---|---|---|
| X-01 | VERIFIED-DRIFT | Language-pack pattern holds in all 4 repos; RiptOPL overlay is 33 yml not 35; SMS pack totals shrank between pins |
| X-02 | VERIFIED-DRIFT | Sizes exact (53,655,730 B / 21,197,583 B); "70 docs files" true only as the .md count (71 of 159 tracked) |
| X-03 | VERIFIED-DRIFT | Sprawl grew since pass 1: 632 branches / 318 tags re-counted (was 623/313) |
| X-04 | VERIFIED-DRIFT | RiptOPL 266 + PS2-Servers 1,608 reproduce; Launchstation "127 scrapers" undercounts (201/213 read_text) |
| X-05 | VERIFIED | .BAK/backup habit census reproduces |
| X-06 | VERIFIED | POPSTARTER duplication; default ELF md5-identical to DEBUG (`bbc61fa4…`) |
| X-07 | WEAKENED | RiptOPL headline falls: per-edition cores are 122–125 B #include shims, not copies; only headers triplicated |
| X-08 | VERIFIED | SMB implementation census reproduces |
| X-09 | VERIFIED | All six `strcpy(filename, game->startup)` sites at the exact claimed lines |
| X-10 | VERIFIED | iLink carried end-to-end as claimed |
| X-11 | VERIFIED-DRIFT | Flag lines exact; ps2ip.irx is 118,513 B not 118,183 B; SMS BDM 86 sites/17 files |
| X-12 | VERIFIED-DRIFT | Launchstation 863 exact; SMS corrected to 118/51/71 (strcpy/strcat/sprintf) on the finding's own scope |
| X-13 | VERIFIED | All nine PS2 config-parser entry points at exact claimed lines |
| X-14 | VERIFIED-DRIFT | All byte-identities reproduce except stub-header group: largest group is 19 files, not 20 |
| X-15 | VERIFIED-DRIFT | POPS/PS2 figures exact; RiptOPL 2,222 lines not 2,220; SMS docs workflows are path-filtered |
| X-16 | VERIFIED-DRIFT | Near-all exact; "three library UIs" is two — `library_index.py` is an index module |
| X-19 | VERIFIED-DRIFT | 2×MD4/2×MD5 link proven via ps2.yaml targets in both repos; `hmac-md5.c` differs by a 2-line comment |
| X-20 | VERIFIED-DRIFT | Double-SHA-256 in the single EE target proven; but mc_save_export's mbedTLS use is AES/HMAC-SHA1, not SHA-256 |
| X-21 | WEAKENED | All named streaming paths confirmed; "in every path" falsified by `_copy_file_to_mc`, which deletes on failure |
| X-22 | VERIFIED | Intra-binary duplicate machinery as filed |
| X-24 | VERIFIED-DRIFT | 100/20/30 s values + dead declaration exact; SMS's "1" is one unconditional call, not a literal |
| X-25 | VERIFIED-DRIFT | POPSLoader 27 exact; Launchstation end state is 4→3 parsers / 3→2 line parsers, not 4→2 |
| X-26 | VERIFIED-DRIFT | Truncation + save-permanence mechanism and both callers confirmed; citations off 1–2 lines |
| X-27 | VERIFIED | POPSLoader first-wins + save-deletes-unknowns, both axes |
| X-28 | VERIFIED-DRIFT | Both CRC-32 functions in the one EE target; "same text ×3" literal only for the two PC copies |
| X-29 | VERIFIED | SMS positional SMB list: blank line shifts all records, no resync |
| X-30 | VERIFIED | Self-update trust/policy divergences as filed |
| X-32 | VERIFIED | UDPRDMA/UDPFS forks carry disjoint hardening, item-by-item diff |
| X-33 | VERIFIED | Three editions, three limit sets; Python honours none of the header's (executed) |
| X-34 | VERIFIED | Identical packets, different outcomes per server language |
| X-35 | VERIFIED | SMS config save never change-gated; fires as a side effect |
| X-36 | VERIFIED | Two unbuilt UDPFS front-ends, 267 lines, unreferenced by build files |
| X-37 | VERIFIED-DRIFT | Core holds (C reserved vs Python live port, executed pack `f5f5f6f5`); Go canonical INFORM writes the real port, not 0 |
| X-38 | VERIFIED | Go Edge zeroes timestamps/attrs the other editions fill |
| X-39 | VERIFIED | Triple-write atomicity vs single write for the twin cache |
| X-40 | VERIFIED | Launchstation rewrites DASHAPPS.CNF per launch; RiptOPL writes nothing |
| X-41 | VERIFIED | ps2build hand-copy; changed-line counts reproduce exactly (4/10/87/144) |
| X-42 | VERIFIED | actions/checkout at six generations, per-repo counts exact |
| X-43 | VERIFIED | ps2dev image pinned three ways; POPSLoader's a mutable tag |
| X-44 | VERIFIED | Only RiptOPL CI enforces formatting; .clang-format md5s match |
| X-45 | WEAKENED | Pruning + hard-coded 1.4.4 verified; SMS rolling-tag race already mitigated in-tree at the pin |
| X-46 | VERIFIED-DRIFT | 15 PRs / copies / byte-identical pair all verified; PS2-Servers' wave-1 merge time corrected (09:04 PST) |
| X-47 | VERIFIED | SMSTCPIP forks diverged, diff counts to the line (19/19 files; 11,072 vs 9,642 lines) |
| X-48 | VERIFIED | Wiki publishing implemented four times as filed |
| X-51 | VERIFIED | Rumble census exact: 10 sites, 4 pademu scaled / 6 standalone raw |
| X-52 | VERIFIED-DRIFT | No drift gate anywhere (re-proven); SMS theme/icon PNG census is 35, not 39 |
| X-53 | VERIFIED-DRIFT | Sizes + zero tracked TTFs exact; generator usage line is gen_dash_font.py:13, not :14 |
| X-54 | WEAKENED | 19/19 payloads byte-identical (286,561 B), build/CI consume only .xz; "nothing reads them" falls — compress_irx.py reads the plain files |
| X-55 | VERIFIED | 17 POPSTARTER copies, diffs 0–2 B inside dword @0x410, DEBUG ≡ root in all 3 trees |
| X-56 | VERIFIED | drvtif pair identical at pin and at introduction commit 1f16be79; tifinet pair distinct |
| X-57 | REFUTED | Provenance records exist: POPSLoader PROVENANCE.json names both .udpfs files with hashes; headline defeated (coordinator spot-checked) |

## Totals (counted from the table above)

**51 findings: VERIFIED 27 · VERIFIED-DRIFT 19 · WEAKENED 4 · REFUTED 1.** Counting method: the table was built row-by-row from the four worker section files' own verdict lines (not from worker summary messages — one worker's summary undercounted its VERIFIED rows by one; the section file governs), then the totals were re-counted from this file's finished table.

## Reasoning for non-VERIFIED verdicts

### REFUTED

- **X-57** — The byte facts reproduce exactly: the `.udpfs` pair is present in both repos, the BDMAssault family is 45 files / 9 distinct binaries, and RiptOPL's `PROVENANCE.md` hashes verify 9/9 with no udpfs row. But the finding's headline — the pair "ships in both repos with no provenance record anywhere" — is defeated. POPSLoader's `docs/third_party/okeanos_udpfs/PROVENANCE.json` records both files by name (lines 12 and 17) with source names, exact sha256s, sizes, and the upstream release; `STATE.md` and `docs/UDPFS_BDMA.md` document their origin and history; RiptOPL records the pair in `docs/VCD.md`, its README, `vcdsupport.cpp:1706`, and a host test (coordinator independently spot-checked the PROVENANCE.json entries and STATE.md lines). Two secondary counts are also wrong (executed side split 22/23, not 21/24; `bin/POPSLDR` holds 12 variant files, not 24). The one surviving residue — RiptOPL's own `modules/bdmassault/PROVENANCE.md` omits the pair, and the usbhdfsd dedupe is nowhere stated in words — is filed below as candidate X-59. **Disposition for reconciliation: withdraw X-57 as filed; its residue lives on as X-59.**

### WEAKENED

- **X-07** — The PS2-Servers half stands (three UDPFS editions, independently implemented) and Launchstation's precompiled IRX stands. The RiptOPL headline falls: the per-edition `udpfs_core.c`/`udprdma.c` files are 122–125-byte `#include` shims into `udpfs_shared`, not byte-identical copies — this is the round-2 correction to RIPTOPL-008 (RIPTOPL-048) that the pass-1 finding predates. What is actually triplicated is the header set (6 headers md5-identical ×3; mprintf.h ×5). Go's UDPFS is also 3,384 non-test lines, not ~2,700. Survives as: header triplication + three server editions + one precompiled IRX.
- **X-21** — Every named streaming copy path and all four SMS sub-defects confirm exactly, including that truncated copies are indistinguishable from complete ones there. The title's "in every path" is falsified by one counterexample: SMS's `_copy_file_to_mc` (GUIFileCtxMenu.c:143-196), a buffered import path, deletes the destination on write failure. Survives as: every *streaming* path; the fix's scope shrinks by one path that already behaves.
- **X-45** — Two of three claims verify fully: PS2-Servers' auto-tag pruning, and POPSLoader's official-release workflow hard-coded to "1.4.4" (name, concurrency group, both greps). The SMS half falls in part: at the pin, the destructive delete/recreate rolling-tag race is already mitigated in-tree (in-place update, the player owns tag creation, per-family concurrency groups, converter retry-wait), so the prescribed single-writer fix is largely obsolete. Survives as a two-repo finding; the SMS prescription should be dropped or re-scoped.
- **X-54** — Every load-bearing fact is exact: 19/19 `.irx.xz` payloads decompress byte-identical to the plain `.irx` copies (sha256-verified), 286,561 B to the byte, and build/CI consume only the `.xz` forms. The absolute "no reference to any plain path / nothing reads them" falls: `tools/compress_irx.py` reads every `irx/*.irx` as the regeneration path, and docs/scripts reference plain paths as intermediates. No build/CI/test consumer exists, so the dead-duplication defect and the deletion fix stand — narrowed from "unreferenced" to "no build-time consumer; they are regeneration inputs".

### VERIFIED-DRIFT (corrected figures; mechanisms hold)

- **X-01** — Pattern holds in all four repos (SMS: all 19 packs differ, re-run pair-by-pair). Corrections: RiptOPL's fork overlay is 33 `.yml` files, not 35 (35 is the full TRANSLATIONS list); SMS pack totals are 98,202 B / 128,914 B at this pin, not ~156 KB / ~180 KB (pin movement).
- **X-02** — Sizes exact (RiptOPL docs/assets 53,655,730 B; POPSLoader .research 21,197,583 B = 69.7% of the tracked tree). "70 docs files" is true only as the .md count (71); `docs/` holds 159 tracked files.
- **X-03** — Sprawl is real and grew between pins: re-counted 632 remote branches / 318 tags (filed 623/313); sub-counts corrected (claude/* 227, build-* tags 91, main-* tags 82; backup/* 9 exact).
- **X-04** — RiptOPL's 266 read_text files and PS2-Servers' 1,608 self-test lines reproduce exactly. Launchstation's "127 scrapers" does not reproduce by any method (201/213 files use read_text; the true population is larger than filed); SMS tools Python is 16,416 lines, not ~14,000.
- **X-11** — Launchstation flag lines exact (config.c:641, 858, 1018). Corrections: ps2ip.irx is 118,513 B, not 118,183 B; SMS BDM census is 86 sites / 17 files, not ~90 / 16.
- **X-12** — Launchstation's 863 unsafe calls reproduce exactly and all cited sites land. SMS's counts do not reproduce under any scope: corrected to 118 strcpy / 51 strcat / 71 sprintf on SMS-014's own stated scope (src/*.c), vs 176/62/87 filed. Also: the SUMMARY's "Go Edge already does EBUSY" fix note is unsupported — in Go's UDPFS, EBUSY is only an errno constant; no write-claim exists.
- **X-14** — Every byte-identity claim reproduces (AGENTS≡CLAUDE in both repos, bgm.ogg 324,182 B, PS2 banner md5-identical, SMS plain .irx 323,438 B beside the .xz set, tarball 1,466,084 B) except the stub-header group: the largest identical group is 19 files, not 20.
- **X-15** — POPSLoader (10 workflows / 2,062 lines) and PS2-Servers' 1,095-line release pair are exact. RiptOPL's total is 2,222 lines, not 2,220; SMS's docs/wiki workflows are path-filtered, so "3 of 6 rebuild on every master push" overstates two of the three.
- **X-16** — Nearly everything exact (RA 52,963 C lines / 5,201 Python lines, directlink 1,927, exploits 147,662 B, ffunicode 15,593 lines, mbedTLS glob sites). Exception: "three library UIs" is two (`library_gui.py`, `library_panel.py`); `library_index.py` is an index module, not a UI.
- **X-19** — The core stands and the link is now *proven*, not inferred: both repos' `ps2.yaml` smb2man targets list the usmb2 md4c/md5/hmac-md5/ntlm objects **and** smb2auth.c, and smb2auth's MD4/MD5 survive --gc-sections via its kind dispatcher. Sole correction: `hmac-md5.c` is not byte-identical across the repos (a 2-line repo-name comment differs).
- **X-20** — The binary-level double is proven via the single EE target in `ps2.yaml` (cloud_* + mc_* + mbedcrypto). Correction: mc_save_export.c's mbedTLS use is AES/HMAC-SHA1, not mbedTLS SHA-256 — no single file uses both SHA-256 implementations; the duplication is at binary level only, as the title says, but one supporting sentence overstates the file-level overlap.
- **X-24** — The 100 / 20 / 30-second values and the dead `SMS_StartNetwork` declaration are exact. Correction: SMS's "1" is not a literal constant — it is a single unconditional DEV9CTLSHUTDOWN call (SMS_IOP.c:1197, repeated at :1669).
- **X-25** — POPSLoader's "~27" is exact (27 extraction statements, 56 string.match calls) and the trim diff is exactly 1 line. Launchstation's arithmetic corrects: 3 line parsers (4 only counting positional getIpConfig); the achievable end state is 4→3 parsers / 3→2 line parsers, not 4→2.
- **X-26** — Mechanism, both callers (config.c:950, main_startup.c:180), save-permanence, and the dash_internal.h existence proof all confirm. Citations drift 1–2 lines (the abort is config.c:137-138, not 139-140).
- **X-28** — Both CRC-32-family functions are in the one EE target. Correction: "same text ×3" is literal only for the two PC copies (byte-identical); the EE copy has already drifted (unsigned-byte fix + `count <= 32` bound).
- **X-37** — Core holds: the C spec says DiscHeader bytes 2–3 are "reserved, must be 0", the Python server uses them as a live data port (executed: pack `f5f5f6f5`), and C clients ignore the field. Correction: Go's canonical INFORM (negotiation.go:195) writes the real data port; only its compatibility INFORM writes 0 — the finding's Go sub-detail is wrong.
- **X-46** — The fan-out verifies: 15 PRs, the stylesheet copies, SMS's byte-identical pair (md5 `17bb5910…`), gh-pages/dev landing branches, and the ≈35-commit count. Correction: PS2-Servers' wave-1 merge landed 2026-11-13 09:04 PST, not in the 05:56–05:57 wave with the other four.
- **X-52** — Core claim fully re-proven: zero generator references in any repo's `.github/`, `gen_sfx.py --check` exits 0, SMS icons/loading regenerate byte-identical. Correction: the supporting census says "39 tracked PNGs" for SMS theme/icons; the executed count is 35.
- **X-53** — Sizes (1,639,271 B total), zero tracked TTFs, and the doc pins (font-generation.md:37-38) are exact. Correction: the generator usage line is gen_dash_font.py:13, not :14.

### UNVERIFIABLE-HERE (one sub-claim, inside a VERIFIED verdict)

- **X-47** — The divergence itself is fully proven (diff counts to the line; 19/19 files differ). The characterisation "SMS's SMSTCPIP is pristine upstream" cannot be re-derived here: no upstream copy exists in the clones to compare against. The verdict stands on the divergence, which is the finding's load-bearing claim.

## New candidates (from verification)

### X-58 / RiptOPL's PC-tool CRC-32 copies retain the signed-byte negative-index read the EE copy fixed / Category 6
- **Locations:** RiptOPL `tools/pc/iso2opl/src/iso2opl.c:48-70` and `tools/pc/opl2iso/src/opl2iso.c:43-65`; the fixed sibling at RiptOPL EE `system.cpp:470-471` (comment + `unsigned char byte`).
- **Problem:** Both PC copies declare `int byte` and assign from a `const char *`; on signed-char platforms, bytes ≥ 0x80 sign-extend, making `crctab[byte ^ ((crc >> 24) & 0xFF)]` a negative, out-of-bounds index. The EE copy's own comment describes exactly this defect and its fix, which was never ported to either PC copy (surfaced by X-28's verification; distinct defect from X-28's duplication claim).
- **Fix:** Port the EE fix — make the byte variable unsigned in both PC copies (2 one-word changes).
- **Benefit:** Removes an out-of-bounds read on attacker-influenced input (image filenames/contents) in two shipped host tools.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — both PC sites and the EE comment/fix line-read during verification).

### X-59 / RiptOPL's BDMAssault PROVENANCE.md omits the .udpfs pair it ships / Category 7
- **Locations:** RiptOPL `modules/bdmassault/PROVENANCE.md` (the 9-row table, verified 9/9 accurate); the pair ships at RiptOPL `ship/POPS/` and is embedded via `src/sources/vcdsupport.cpp`; hashes already recorded in POPSLoader `docs/third_party/okeanos_udpfs/PROVENANCE.json:12,17`.
- **Problem:** The surviving residue of the refuted X-57: RiptOPL's own provenance document — otherwise complete and accurate — has no rows for `usbd.irx.udpfs` / `usbhdfsd.irx.udpfs`, and the `usbhdfsd.irx.udpfs` ≡ `usbhdfsd.irx.usbexfat` dedupe is nowhere stated in words in RiptOPL.
- **Fix:** Add the two rows (hashes from POPSLoader's PROVENANCE.json) plus one sentence stating the dedupe.
- **Benefit:** RiptOPL's provenance record becomes complete for the binaries it ships.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

Left unnumbered by design (recorded in the worker sections): SMS's second single-attempt DEV9 shutdown site (SMS_IOP.c:1669) folds into X-24's corrected scope rather than standing alone; Launchstation's escape-less `releaseJsonString` on the self-update ancestry path is adjacent to X-22's filed duplicate-parser scope and is noted in verify2-cross-B.md for the reconciliation pass to attach there if it wishes.

*Verification method note: four workers, adversarial briefs, section files in `verify2-sections/`; the coordinator personally spot-checked the sole REFUTED headline (X-57) against the clone before accepting it. Clones verified clean at the pins at the end of the pass.*
