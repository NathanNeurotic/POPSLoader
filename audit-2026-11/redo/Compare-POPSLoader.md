# OLD-vs-REDO Comparison — POPSLoader

**Pin (both corpora, clone read-only throughout):** `29272cddbf0122f14e76bc3bdd75e3b46aa870be`
**BDMAssault tarball:** `iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz`, md5 **`09ff4b911ba131468a25d0ec9a4e2f27`** (verified by the coordinator before extraction to `/tmp/bdma_adj/`).
**Clone state at completion:** HEAD at the pin, `git status --porcelain` empty.

## Method

- OLD actionable set: the 108 rows of `Sable-MASTER-INDEX.md` §2.3 (97 STANDING + 11 REVISED). REDO actionable set: the 120 rows of `Redo-MASTER-INDEX.md` (73 STANDING + 27 STANDING-DRIFT + 15 REVISED + 5 NEW: RE-POPS-116…120).
- Matching is mechanism-level, bodies read — titles were used only to triage; every tentative NONE was cross-checked by grepping the other corpus's full text for the mechanism's distinctive terms (function names, constants, file names), and every PARTIAL was decided from both bodies.
- **Category note:** the OLD tarball section (POPSLOADER-071…107) labels its driver defects "2 (correctness/safety)" in the bodies and Cat 2 in the index. Those are bug-class defects in substance and are the direct counterparts of REDO Category 6, so they were adjudicated as defect-class. OLD Category 6 proper (017, 020, 021, 030, 034, 038, 041, 048, 066, 108) was adjudicated the same way.
- Adjudication: every NONE/PARTIAL defect-class item and every high-benefit NONE was re-derived from code at the pin (clone, or the extracted tarball for tarball items) by six parallel workers with coordinator spot-checks (POPSLOADER-030, -091, -103 verified first-hand by the coordinator). Rulings: **REAL** (mechanism exists as claimed in the finding's final form), **NOT-REAL** (defeating evidence cited), **COVERAGE** (mechanism real, but it sits inside the missing side's own declared files-not-read / scope limits, so the absence is explained by declared scope rather than a miss).
- Non-defect NONEs are classified **COVERAGE** vs **UNEXPLAINED** using each side's own declarations: REDO's Appendix B in `Redo-POPSLoader.md` (notably: `.research/**` keyword-scanned + sample-read only; tarball merged copies established by 37-pair diff, not independent line-reads; `ps2atad.c` lines 801–1186 not read; `system.lua` I18N tables censused, not proofread) and OLD's exhaustion verdict + censuses (notably: tarball's own `CI.yml` inventoried as "File listing"; the merged generation established by diff against the components; `.research` read in full).

## Headline counts (counted from the tables in this file)

| Corpus | Actionable | MATCH | PARTIAL | NONE |
|---|---|---|---|---|
| OLD (POPSLOADER-001…108) | 108 | 39 | 10 | 59 |
| REDO (RE-POPS-001…120) | 120 | 38 | 13 | 69 |

Adjudication outcomes for the non-matching defect-class items:

| Side | Adjudicated | REAL | NOT-REAL (final form) | of which COVERAGE-explained |
|---|---|---|---|---|
| OLD-only / PARTIAL defect items | 26 | 26 | 0 | 1 (POPSLOADER-038) |
| REDO-only / PARTIAL defect items | 23 | 23 (as filed in final form) | 0 | — |

No finding in either **final** corpus was ruled NOT-REAL in its final (post-revision) form. The only NOT-REAL elements found anywhere are two **pre-revision** claims that each corpus's own verification had already superseded: RE-POPS-008's original end-pointer over-read claim and RE-POPS-041's original "no recorded hash anywhere" sub-claim (details in §5).

---

## 1. Mapping table — OLD → REDO

MATCH = same mechanism (scope deltas noted). PARTIAL = overlapping but non-identical scope/mechanism. NONE = no counterpart in the REDO final; disposition in §3/§4.

| OLD | REDO | Verdict | Note |
|---|---|---|---|
| POPSLOADER-001 | — | NONE | `.research/` is 70% of repo (Cat 7). §4: COVERAGE. |
| POPSLOADER-002 | RE-POPS-049 | MATCH | Byte-identical IRX embedded twice. OLD's revised saving (83,008 B; mx4sio already aliased) is exactly REDO's filed scope. |
| POPSLOADER-003 | RE-POPS-055 | MATCH | Translation DB inlined in system.lua, parsed every boot. |
| POPSLOADER-004 | RE-POPS-050 | PARTIAL | OLD = the six-file POPStarter SMB IRX set tracked twice, md5-paired. REDO-050 files the general phenomenon (binaries tracked 2–4×) with the SMSUTILS pair as cited instance; the six-file set as such is not enumerated. |
| POPSLOADER-005 | RE-POPS-040 | MATCH | Top-level POPSTARTER.ELF byte-identical to DEBUG profile; REDO adds the 2-byte patch matrix (its "documented nowhere" limb was narrowed by REDO's own verification — `.research/build_site.py` documents the bytes). Copy-count limb also inside RE-POPS-050's census. |
| POPSLOADER-006 | — | NONE | Tarball sits unreferenced in `iop/embed/` (Cat 7, revised: extract-or-archive). §4: UNEXPLAINED (adjacent: RE-POPS-044 covers the usbhdfsd half's accountability, not the tarball's presence/disposition). |
| POPSLOADER-007 | — | NONE | UI images shipped twice (IMG/ files + embedded); revised scope: 25 of 67 PNGs embedded. §4: UNEXPLAINED. (RE-POPS-054 is a different mechanism — dual key registration inside the asset table.) |
| POPSLOADER-008 | — | NONE | Settings save writes the file three times (Cat 5). §4: UNEXPLAINED. |
| POPSLOADER-009 | RE-POPS-077 | MATCH | graphics.cpp row-buffer blocks repeated 3×; REDO broader (BMP decoder + loadbmp included; one loadbmp limb narrowed by REDO verification). |
| POPSLOADER-010 | RE-POPS-053 | MATCH | ds34 code in multiple copies, fixes forgotten. Grouping delta: OLD pass-1 counts three homes (standalone BT, standalone USB, pademu); REDO counts two copies per transport. See also POPSLOADER-033. |
| POPSLOADER-011 | RE-POPS-051 | MATCH | Generated bin2c `loader.c` (855,821 B) committed to git. |
| POPSLOADER-012 | RE-POPS-075 | PARTIAL | OLD = ten-workflow sprawl incl. the one-shot retraction workflow. REDO-075 files two single-use workflows (retraction + official-release hardcoded to 1.4.4); OLD's aggregate sprawl claim not filed by REDO. |
| POPSLOADER-013 | RE-POPS-042 | PARTIAL | Same artefact (`opencode.yml`), overlapping but non-identical claims: OLD = AI comment-bot with write token as agent sprawl; REDO = unpinned `@latest` action with API-key secret (Cat 6 framing). |
| POPSLOADER-014 | — | NONE | Stale branches / checkpoint tags (list only). §4: UNEXPLAINED (git metadata; outside REDO's tree-based scope but not in its declared not-read list). |
| POPSLOADER-015 | — | NONE | Root docs sprawl (Cat 7). §4: UNEXPLAINED (REDO filed nine specific docs findings instead). |
| POPSLOADER-016 | — | NONE | `.research/tools/` one-shot scripts (Cat 1, revised). §4: COVERAGE. |
| POPSLOADER-017 | — | NONE | lua_dir 512-entry MC table on EE stack (Cat 6). §3: **REAL**. |
| POPSLOADER-018 | — | NONE | Network waits block UI thread up to 30 s (Cat 5). §4: UNEXPLAINED. |
| POPSLOADER-019 | — | NONE | `elf.c` launch-argument storage logic twice (Cat 2). §4: UNEXPLAINED. |
| POPSLOADER-020 | RE-POPS-028 | PARTIAL | Same function (`imgThread`/`lua_loadimgasync`, luagraphics.cpp), disjoint defects: OLD = `sprintf` into malloc(16) via `(int)image` (adjudicated §3: REAL, latent); REDO = Lua-string U (§3: REAL). |
| POPSLOADER-021 | — | NONE | Unchecked `getcwd` in Lua directory bindings (Cat 6). §3: **REAL**. |
| POPSLOADER-022 | RE-POPS-055 | PARTIAL | OLD = translation data in three forms (inline Lua + TSV + XLSX). REDO-055 covers only the inline-Lua form (as POPSLOADER-003's counterpart); the TSV/XLSX duplication limbs are unfiled by REDO. |
| POPSLOADER-023 | — | NONE | `pcall`+`type()` defensive idiom, 370 sites (Cat 3). §4: UNEXPLAINED. |
| POPSLOADER-024 | RE-POPS-106 | MATCH | Revised core identical: exactly 6 exact-duplicate image pairs in `.research/assets` = 57,552 B (both corpora). REDO adds the OFFICIAL_NOTES.md ≡ RELEASE_1.4.4.md pair; OLD's root loose-assets limb not in REDO. |
| POPSLOADER-025 | — | NONE | Leftover upstream TODO block in fntsys.cpp (Cat 1). §4: UNEXPLAINED. |
| POPSLOADER-026 | — | NONE | Settings save's second diverged commit-sequence copy (Cat 2). §4: UNEXPLAINED. |
| POPSLOADER-027 | — | NONE | UDPFS equipped-check re-reads/byte-compares whole IRXs per launch (Cat 5). §4: UNEXPLAINED. |
| POPSLOADER-028 | — | NONE | "TEST" HDD write probe runs/toasts on every Settings save (Cat 8). §4: UNEXPLAINED. |
| POPSLOADER-029 | RE-POPS-079 | MATCH | PLDRGC1 game-list cache format implemented twice — identical locations (system.lua:9880–10030). |
| POPSLOADER-030 | — | NONE | Settings rollback passes two nonexistent fields (Cat 6). §3: **REAL** (coordinator-verified). |
| POPSLOADER-031 | — | NONE | Permanently-false flag, five dead branches in RunPOPStarterGame (Cat 3). §4: UNEXPLAINED. |
| POPSLOADER-032 | RE-POPS-080 + RE-POPS-090 + RE-POPS-091 | PARTIAL | OLD = seven zero-caller Lua functions incl. the dead HDD readable-path resolver twin. REDO splits the dead Lua surface differently: -080 is the resolver twin exactly; -090/-091 file other dead sets. Neither grouping contains the other. |
| POPSLOADER-033 | RE-POPS-053 | MATCH | DS3/DS4 IOP drivers as two diverging copies (standalone vs pademu) — same mechanism as POPSLOADER-010 at a different grouping; both land on RE-POPS-053. |
| POPSLOADER-034 | RE-POPS-010 | MATCH | DS3 battery byte indexes 6-entry `power_level[]`, all four copies — exact. |
| POPSLOADER-035 | — | NONE | ps2atad probes phantom slave, discards result (Cat 1). §4: UNEXPLAINED (cited lines 1242–1262/1286 are inside REDO's declared read range 1187–1310). |
| POPSLOADER-036 | — | NONE | host_harness.py asserts source text, re-reads files (Cat 7). §4: UNEXPLAINED. (RE-POPS-105 is the same pattern in a different file — see POPSLOADER-055.) |
| POPSLOADER-037 | — | NONE | build_site.py wipes output dir at import (Cat 7). §4: COVERAGE (.research). |
| POPSLOADER-038 | — | NONE | ATA security-erase IDENTIFY into NULL buffer (Cat 6). §3: **REAL + COVERAGE** (line 1183 sits in REDO's declared unread band, ps2atad.c 801–1186). |
| POPSLOADER-039 | RE-POPS-088 | MATCH | images.lua IMG_FALLBACKS machinery can never fire — exact. |
| POPSLOADER-040 | — | NONE | build_site.py hard-fails unless exactly 34 image records (Cat 7). §4: COVERAGE (.research). |
| POPSLOADER-041 | RE-POPS-002 | MATCH | ds34 connect paths walk USB descriptor blobs trusting device lengths, no NULL/zero guards. REDO-002 spans all four copies; RE-POPS-117 (NEW) adds the `chrg_connect` limb of the same family. |
| POPSLOADER-042 | — | NONE | Disc-layout test extracts code by exact comment strings (Cat 7). §4: UNEXPLAINED. |
| POPSLOADER-043 | RE-POPS-072 | MATCH | GameList "Not implemented yet" placeholder branch can never fire — exact. |
| POPSLOADER-044 | — | NONE | Gutted pad-debug block in ui.lua (Cat 1). §4: UNEXPLAINED. |
| POPSLOADER-045 | — | NONE | build_site.py renders largest page twice (Cat 5). §4: COVERAGE (.research). |
| POPSLOADER-046 | — | NONE | build_site.py defines `slug()` twice (Cat 1). §4: COVERAGE (.research). |
| POPSLOADER-047 | RE-POPS-095 | MATCH | Clamp01 defined twice in ui.lua — REDO-095's three-clamp census includes OLD's exact pair (ui.lua:14 + :1946) plus a system.lua copy and a same-name shadow. |
| POPSLOADER-048 | RE-POPS-025 | MATCH | Pademu DS4 LED report: DS3-length memset sends 29 uninitialised bytes — exact mechanism, exact copies. |
| POPSLOADER-049 | RE-POPS-026 | PARTIAL | OLD = full hunk-by-hunk divergence classification; its "guard family lost" limb (standalone entry-point guards — `port >= MAX_PADS`, BT authorization — absent from pademu entry points) is captured only as a compounding note inside RE-POPS-024, and RE-POPS-026 files a different specific lost guard (DS3 null-report guard, standalone USB copy). The classification itself has no REDO counterpart. |
| POPSLOADER-050 | — | NONE | EE ds34 client libraries: 12 of 22 exported functions caller-less (Cat 1). §4: UNEXPLAINED (REDO read the same libraries and filed RE-POPS-035 from them). |
| POPSLOADER-051 | RE-POPS-092 | PARTIAL | Dead/stale i18n entries: OLD counts 14 (superseded toast key in 6 languages + 8 Hungarian orphans); REDO counts 20 (entries whose source strings no longer exist). Same mechanism, different census definitions; sets overlap without containment either way. |
| POPSLOADER-052 | — | NONE | audit_site.py hard-codes prose/magic numbers as publish-gate law (Cat 7). §4: COVERAGE (.research). |
| POPSLOADER-053 | RE-POPS-062 + RE-POPS-084 | MATCH | Split: REDO-062 = the never-compiled `__RTL` renderer; REDO-084 = the caller-less fntsys functions (fntLoadDefault, fntFitString) — plus graphics.cpp dead functions beyond OLD's fntsys-only scope. |
| POPSLOADER-054 | — | NONE | 7z listing parser in four copies across research gates (Cat 2). §4: COVERAGE (.research). |
| POPSLOADER-055 | RE-POPS-105 | MATCH | test_udpfs_integration.py wiring half = ~45 bare source-text assertions — exact. |
| POPSLOADER-056 | — | NONE | audit_published_provenance.py exact-prose-as-law (Cat 7). §4: COVERAGE (.research). |
| POPSLOADER-057 | — | NONE | Two more host gates extract code by exact comment strings (Cat 7). §4: UNEXPLAINED (primary artefact `tools/png_decoder_harness.py` was in REDO's read set; second artefact is in `.research/tools/`). |
| POPSLOADER-058 | — | NONE | audit_legacy_tool_overlap.py builds a lookup it never reads (Cat 1). §4: COVERAGE (.research). |
| POPSLOADER-059 | — | NONE | Fetch-process residue / content-free failure marker tracked (Cat 7). §4: COVERAGE (.research). |
| POPSLOADER-060 | RE-POPS-060 | MATCH | i.Link documented as stub/not-implemented; code implements it — exact, same three docs. |
| POPSLOADER-061 | RE-POPS-073 | PARTIAL | Same docs-drift family (docs say BDMA_ADAPTIVE off / old USB rule; code defaults it on), disjoint primary sites: OLD cites ARCHITECTURE.md:640; REDO-073 cites ROLLING_NOTES.md + TESTING.md and adds the FAT32-stages-USBEXFAT behaviour claim. |
| POPSLOADER-062 | RE-POPS-113 | MATCH | STATE.md Slovak-not-in-picker note is stale — exact. |
| POPSLOADER-063 | RE-POPS-107 | MATCH | Version headers frozen at 1.1.0/v1.1.1-dev vs code v1.4.4; REDO broader (five docs vs OLD's three; REDO verification narrowed the harmful instance to TESTING.md:3). |
| POPSLOADER-064 | — | NONE | README Retro GEM Game ID row lists "On" only; code is an On/Off toggle (Cat 7). §4: UNEXPLAINED. |
| POPSLOADER-065 | — | NONE | ARCHITECTURE CoverCache "3-entry LRU" vs code `max = 4` (Cat 7). §4: UNEXPLAINED. |
| POPSLOADER-066 | — | NONE | loader.c CI parity check never compares the committed dump (Cat 6/7). §3: **REAL**. (RE-POPS-051 is the different, matched mechanism of POPSLOADER-011.) |
| POPSLOADER-067 | — | NONE | `src/elf_loader/Makefile:15-16` dead rule (Cat 3/7, INFERRED). §4: UNEXPLAINED. |
| POPSLOADER-068 | — | NONE | COMPONENTS.md calls loader.c a "~6.5 MB blob"; it is 855,821 B (Cat 7). §4: UNEXPLAINED. |
| POPSLOADER-069 | RE-POPS-044 | MATCH | Shipped MX4SIO `usbhdfsd.irx` has no source anywhere; REDO-044 is the same accountability defect from the tarball side. The broader census form is RE-POPS-041 (PARTIAL, §2). |
| POPSLOADER-070 | RE-POPS-096 | MATCH | Dead `hci_event_flag_*` macros in both ds34 headers — exact; REDO adds `GetExportEntry` and the sys_utils.c limb. |
| POPSLOADER-071 | — | NONE | CSW validation defeated by pre-filled receive buffer (tarball usb_mass.c). §3: **REAL**. |
| POPSLOADER-072 | RE-POPS-005 | MATCH | Device-supplied SCSI block length unvalidated (scsi.c:168-176) — REDO-005 merges this with POPSLOADER-088. |
| POPSLOADER-073 | RE-POPS-001 + RE-POPS-004 | PARTIAL | OLD = umbrella claim (three layers hard-assume 512 B sectors; nothing enforces a 512 B device). REDO splits it into sharper consequences: -001 partition-parser scratch overrun on >512 B-sector devices, -004 bd_cache geometry. The FatFs-config limb and the umbrella "no enforcement point" framing are not filed as such by REDO. |
| POPSLOADER-074 | RE-POPS-006 + RE-POPS-014 | MATCH | Split: REDO-006 = GPT header trust (entry count/size, div-by-zero); REDO-014 = inverted-range acceptance (+ the sectorCount off-by-one of POPSLOADER-108). |
| POPSLOADER-075 | RE-POPS-019 + RE-POPS-012 | MATCH | Split: REDO-019 = `get_frag_list` cycle-bound limb; REDO-012 = possibly-NULL block-device deref in the sibling ioctl cases (same fs_driver.c:624-714 span). |
| POPSLOADER-076 | RE-POPS-017 | MATCH | `scsi_connect` discards `scsi_warmup`'s result — REDO-017 merges this with POPSLOADER-084. |
| POPSLOADER-077 | RE-POPS-038 | MATCH | DevCtl STOP_UNIT / STOP_ALL bodies swapped — exact, same lines. |
| POPSLOADER-078 | RE-POPS-020 | MATCH | IsoTD halted-flush clears the wrong LUT slot — exact. |
| POPSLOADER-079 | — | NONE | Failed hub connect leaves freed UsbHub reachable; unplug double-frees (tarball hub.c). §3: **REAL**. |
| POPSLOADER-080 | RE-POPS-013 | MATCH | part_read/part_write never clamp to the partition's sectorCount — identical locations (part_driver.c:52-80). |
| POPSLOADER-081 | RE-POPS-018 | MATCH | bd_cache marks a block valid after an unchecked device read — exact (bd_cache.c:115-123). |
| POPSLOADER-082 | — | NONE | `fs_open` honours O_CREAT/O_TRUNC without write access (tarball fs_driver.c). §3: **REAL**. |
| POPSLOADER-083 | RE-POPS-011 | MATCH | Mount-info index admits `index == count` and negatives — exact; REDO's own verification narrowed it to latent (no in-tree caller reaches a bad index). |
| POPSLOADER-084 | RE-POPS-017 | MATCH | scsi_warmup TUR loop unbounded + uninitialised sense buffer — merged into RE-POPS-017 with POPSLOADER-076. |
| POPSLOADER-085 | — | NONE | `fs_lseek64` converts negative results to ~2⁶⁴ offsets (tarball fs_driver.c). §3: **REAL**. |
| POPSLOADER-086 | — | NONE | `cancelTimerCallback` doesn't fold the cancelled timer's delta into its successor (tarball hub.c). §3: **REAL**. |
| POPSLOADER-087 | — | NONE | Failed `f_close` leaks the FIL/DIR pool slot forever (tarball fs_driver.c). §3: **REAL**. |
| POPSLOADER-088 | RE-POPS-005 | MATCH | READ CAPACITY `last_lba` stored as the sector count — merged into RE-POPS-005 with POPSLOADER-072. |
| POPSLOADER-089 | RE-POPS-015 | MATCH | MBR partition entries trusted with no bounds check against the device — exact. |
| POPSLOADER-090 | — | NONE | FatFs `FRESULT` codes returned to iomanX callers as errnos throughout fs_driver. §3: **REAL**. |
| POPSLOADER-091 | — | NONE | fs_read/fs_write/fs_dread map every FatFs error to 0. §3: **REAL** (also coordinator spot-checked). |
| POPSLOADER-092 | — | NONE | Filename prefixing uses unbounded `alloca` on the IOP handler stack. §3: **REAL**. |
| POPSLOADER-093 | — | NONE | USBD HCD pool `memset` unconditional; AllocSysMemory failure = NULL crash at load (tarball hcd.c). §3: **REAL**. |
| POPSLOADER-094 | — | NONE | USBD init failure returns ignored at every layer (tarball hcd.c/usbd.c). §3: **REAL**. |
| POPSLOADER-095 | — | NONE | `doUnregisterDriver` leaves next/prev set, blocking re-registration (tarball driver.c). §3: **REAL**. |
| POPSLOADER-096 | — | NONE | `disk_ioctl` GET_SECTOR_COUNT writes 4 B into the 8 B LBA64 buffer; GET_SECTOR_SIZE into a WORD buffer. §3: **REAL** (latent — no caller compiled at the pin). |
| POPSLOADER-097 | RE-POPS-037 | MATCH | `ff_req_grant` fabricates success / ignores its timeout — exact (ffsystem.c:143-168). |
| POPSLOADER-098 | — | NONE | Hub status-change chain abandons itself on any transfer error (tarball hub.c). §3: **REAL**. |
| POPSLOADER-099 | — | NONE | `HubControlTransfer` silently drops a port reset while busy (tarball hub.c). §3: **REAL**. |
| POPSLOADER-100 | — | NONE | USBD module-argument integers accumulate with no overflow/range validation, then size the HCD pool (tarball usbd.c). §3: **REAL**. |
| POPSLOADER-101 | RE-POPS-029 | MATCH | `bd_cache_create` dereferences both AllocSysMemory results unchecked — exact (bd_cache.c:155-167). |
| POPSLOADER-102 | — | NONE | Stat timestamps: seconds ≥ 32 reported 32 s early (mask instead of multiply). §3: **REAL**. |
| POPSLOADER-103 | — | NONE | Unknown ioctl2 commands return success having done nothing (fs_driver.c:729-741). §3: **REAL** (also coordinator spot-checked). RE-POPS-061 is a different limb of the same function (RENAME stub + dummy ops slots). |
| POPSLOADER-104 | — | NONE | `disk_ioctl` returns RES_OK for every unimplemented command. §3: **REAL**. |
| POPSLOADER-105 | — | NONE | `fs_dread` name copy can leave the dirent unterminated at max-length names. §3: **REAL** (conditional, as filed). |
| POPSLOADER-106 | RE-POPS-036 | MATCH | MBR parser leaks its 512 B scratch on the read-failure path — identical locations (part_driver_mbr.c:37-43). |
| POPSLOADER-107 | RE-POPS-098 | MATCH | ASYNC half of `usb_queue_cmd` is dead code that skips CSW validation — exact (REDO verification narrowed its ASYNC-exclusivity premise; mechanism stands). |
| POPSLOADER-108 | RE-POPS-014 | MATCH | GPT `sectorCount` one sector short (last LBA is inclusive) — RE-POPS-014's primary limb; its second limb (inverted range) comes from POPSLOADER-074. |

---

## 2. Mapping table — REDO → OLD

Details for MATCH/PARTIAL rows are in §1 (indexed by the OLD ID). NONE rows carry their disposition here (adjudication in §3, classification in §4).

| REDO | Verdict | OLD counterpart / disposition |
|---|---|---|
| RE-POPS-001 | PARTIAL | POPSLOADER-073 (split, with RE-POPS-004). |
| RE-POPS-002 | MATCH | POPSLOADER-041. |
| RE-POPS-003 | NONE | §3: **REAL** — pademu SIO2 parsing, no size floor; multitap slot unchecked index. |
| RE-POPS-004 | PARTIAL | POPSLOADER-073 (split, with RE-POPS-001). |
| RE-POPS-005 | MATCH | POPSLOADER-072 + POPSLOADER-088. |
| RE-POPS-006 | MATCH | POPSLOADER-074 (split, with RE-POPS-014). |
| RE-POPS-007 | NONE | §3: **REAL** — usb_mass_connect endpoint walk, no NULL/bounds checks. |
| RE-POPS-008 | NONE | §3: original claim **NOT-REAL**; narrowed claim (its final REVISED form) **REAL**. |
| RE-POPS-009 | NONE | §3: **REAL** — BT HCI/L2CAP/HID handlers ignore received byte counts. |
| RE-POPS-010 | MATCH | POPSLOADER-034. |
| RE-POPS-011 | MATCH | POPSLOADER-083. |
| RE-POPS-012 | MATCH | POPSLOADER-075 (split, with RE-POPS-019). |
| RE-POPS-013 | MATCH | POPSLOADER-080. |
| RE-POPS-014 | MATCH | POPSLOADER-108 + POPSLOADER-074 (split). |
| RE-POPS-015 | MATCH | POPSLOADER-089. |
| RE-POPS-016 | NONE | §3: **REAL** (high-benefit; Cat 8 as filed) — SCSI layer caps drives at 2 TiB inside a 64-bit stack. |
| RE-POPS-017 | MATCH | POPSLOADER-076 + POPSLOADER-084. |
| RE-POPS-018 | MATCH | POPSLOADER-081. |
| RE-POPS-019 | MATCH | POPSLOADER-075 (split, with RE-POPS-012). |
| RE-POPS-020 | MATCH | POPSLOADER-078. |
| RE-POPS-021 | NONE | §3: **REAL** — Lua font ids index 16-entry `fonts[]` unchecked (four fntsys entry points). |
| RE-POPS-022 | NONE | §3: **REAL** — Lua handles are raw pointers cast through integers (double-free/NULL deref). |
| RE-POPS-023 | NONE | §3: **REAL** — both ELF-loading stages copy segments to header-supplied addresses unchecked. |
| RE-POPS-024 | NONE | §3: **REAL** — `get_data` copies caller-supplied size out of an 18-byte array (all four copies). |
| RE-POPS-025 | MATCH | POPSLOADER-048. |
| RE-POPS-026 | PARTIAL | POPSLOADER-049 (different specific lost guard; see §1). |
| RE-POPS-027 | NONE | §3: **REAL** — loadImageEmbedded / IOP.loadModuleBuffer trust caller-supplied lengths. |
| RE-POPS-028 | PARTIAL | POPSLOADER-020 (same function, disjoint defect; §3: REAL). |
| RE-POPS-029 | MATCH | POPSLOADER-101. |
| RE-POPS-030 | NONE | §3: **REAL** — atlas allocations never checked; OOM is a NULL dereference. |
| RE-POPS-031 | NONE | §3: **REAL** — fntsys readFile ignores read() result (short-read limb; lseek limb overstated). |
| RE-POPS-032 | NONE | §3: **REAL** — loadFont branches on uninitialised magic when the file can't be opened. |
| RE-POPS-033 | NONE | §3: **REAL** — Pads.getPressure reads uninitialised padButtonStatus. |
| RE-POPS-034 | NONE | §3: **REAL** — HDD partition index becomes a device-name byte via `'0' + index`, unchecked. |
| RE-POPS-035 | NONE | §3: **REAL** — EE ds34 clients copy the RPC buffer to the caller even when the RPC failed. |
| RE-POPS-036 | MATCH | POPSLOADER-106. |
| RE-POPS-037 | MATCH | POPSLOADER-097. |
| RE-POPS-038 | MATCH | POPSLOADER-077. |
| RE-POPS-039 | NONE | §3: **REAL as filed** — callback thread reads the request after freeing it; conditional on a GP-register build (latent in the tarball's own build). |
| RE-POPS-040 | MATCH | POPSLOADER-005. |
| RE-POPS-041 | PARTIAL | Core census corroborated by POPSLOADER-069 (single-binary instance) and adjudicated §3: census **REAL** (26 distinct / 23 sourceless reproduced exactly); "no recorded hash anywhere" sub-claim **NOT-REAL** as originally written (already narrowed by REDO's own verification). OLD has no counterpart census. |
| RE-POPS-042 | PARTIAL | POPSLOADER-013. |
| RE-POPS-043 | NONE | §3: **REAL** — "ABC" keyboard layout can never be selected (normalizer maps it to QWERTY). |
| RE-POPS-044 | MATCH | POPSLOADER-069. |
| RE-POPS-045 | NONE | §4: UNEXPLAINED — merged-driver tree is a second hand-maintained copy of every component. (OLD documented the fact in its tarball census — "the archive stores its own code twice" — but filed no duplication finding for it.) |
| RE-POPS-046 | NONE | §4: UNEXPLAINED — release zips embed the full tracked tree incl. the 21 MB `.research/`. |
| RE-POPS-047 | NONE | §4: UNEXPLAINED — whole `modules/pademu/` tree is built by nothing. |
| RE-POPS-048 | NONE | §4: UNEXPLAINED — 52 of 143 registered Lua bindings have no caller (but see POPSLOADER-032/-050/-053: OLD filed three narrower dead-surface findings in the same territory, none of them this census). |
| RE-POPS-049 | MATCH | POPSLOADER-002. |
| RE-POPS-050 | PARTIAL | POPSLOADER-004 (+ a limb of POPSLOADER-005). |
| RE-POPS-051 | MATCH | POPSLOADER-011. |
| RE-POPS-052 | NONE | §4: UNEXPLAINED — bd_cache reserves 128 KiB of IOP RAM per whole device. |
| RE-POPS-053 | MATCH | POPSLOADER-010 + POPSLOADER-033. |
| RE-POPS-054 | NONE | §4: UNEXPLAINED — embedded-asset table stores every asset twice (100 rows / 49 unique blobs, dual key registration). Distinct from POPSLOADER-007 (files-vs-embed). |
| RE-POPS-055 | MATCH | POPSLOADER-003 (+ inline-Lua limb of POPSLOADER-022). |
| RE-POPS-056 | NONE | §4: UNEXPLAINED — three `iop/embed` binaries are dead (nothing builds, embeds or loads them). |
| RE-POPS-057 | NONE | §4: UNEXPLAINED — vendored `iop/ata_bd_fast/` kept but explicitly unused; the pinned binary wins. (OLD filed two defect findings *inside* this unused stack — POPSLOADER-035, -038 — without filing its disuse.) |
| RE-POPS-058 | NONE | §4: UNEXPLAINED — superseded ps2atad stack still embedded into every ELF; two IMPORT_BIN2C externs unused. |
| RE-POPS-059 | NONE | §3: **REAL** on the core claim — STATE.md presents removed SMB defaults as current (STATE:237 DHCP sub-claim is past-tense, as REDO's verification already narrowed). |
| RE-POPS-060 | MATCH | POPSLOADER-060. |
| RE-POPS-061 | NONE | §4: UNEXPLAINED — fs_ioctl2 RENAME is an admitted TODO stub; ops table padded with dummy slots. Distinct limb of the same function as POPSLOADER-103. |
| RE-POPS-062 | MATCH | POPSLOADER-053 (split, with RE-POPS-084). |
| RE-POPS-063 | NONE | §4: UNEXPLAINED — GetMassRootByBackendName defeats the BDM cache and re-binds RPC per call (REDO verification: no Lua caller at the pin — latent). |
| RE-POPS-064 | NONE | §4: UNEXPLAINED — Settings screen rebuilds its item list and ~100 closures per frame. |
| RE-POPS-065 | NONE | §4: UNEXPLAINED — failing sector retried 16× end-to-end with no delay/reset/backoff (scsi.c). |
| RE-POPS-066 | NONE | §4: UNEXPLAINED — USBD always builds its largest pool config; MINI_DRIVER unreachable. |
| RE-POPS-067 | NONE | §4: UNEXPLAINED — fs_driver statically reserves 128 FIL + 16 DIR objects. |
| RE-POPS-068 | NONE | §4: UNEXPLAINED — HDD.ListPartitions reserves a 512×33 B static table (16,896 B BSS). |
| RE-POPS-069 | NONE | §4: UNEXPLAINED — `bdm_query` reports resident success when its only thread failed to start. (OLD read `iop/bdm_query/bdm_query.c` in Round 4 and recorded it clean on its RPC-list-builder aspect.) |
| RE-POPS-070 | NONE | §4: UNEXPLAINED — ART_LOCATION: removed setting still plumbed through ~10 live sites. |
| RE-POPS-071 | NONE | §4: UNEXPLAINED — ABNT keyboard layout rows byte-identical to QWERTY. |
| RE-POPS-072 | MATCH | POPSLOADER-043. |
| RE-POPS-073 | PARTIAL | POPSLOADER-061. |
| RE-POPS-074 | NONE | §4: UNEXPLAINED — TESTING.md SMB setup instructs setting two Settings rows that no longer exist. |
| RE-POPS-075 | PARTIAL | POPSLOADER-012. |
| RE-POPS-076 | NONE | §4: UNEXPLAINED — IRX load-and-check helper duplicated verbatim in main.cpp and luasystem.cpp. |
| RE-POPS-077 | MATCH | POPSLOADER-009. |
| RE-POPS-078 | NONE | §4: UNEXPLAINED — ResolveAssetPath / ResolveAssetPathTyped duplicate the candidate-walk. |
| RE-POPS-079 | MATCH | POPSLOADER-029. |
| RE-POPS-080 | PARTIAL | POPSLOADER-032. |
| RE-POPS-081 | NONE | §4: UNEXPLAINED — three trailing-slash helpers where one mechanism suffices. |
| RE-POPS-082 | NONE | §4: UNEXPLAINED — DPRINTF is an unconditional no-op; all EE diagnostic logging dead. (OLD's macro census noted `DPRINTF(x...)` empty at dprintf.h:4 without filing it.) |
| RE-POPS-083 | NONE | §4: UNEXPLAINED — bd_cache eviction is a fixed-point weight/aging scheme where a trivial policy suffices (its eviction-failure claim was inverted by REDO verification; the complexity claim stands). |
| RE-POPS-084 | MATCH | POPSLOADER-053 (split, with RE-POPS-062). |
| RE-POPS-085 | NONE | §4: UNEXPLAINED — GetFreeSize / AllocateLargestFreeBlock dead chain. |
| RE-POPS-086 | NONE | §4: UNEXPLAINED — async ATA bring-up worker dead (KickAtaAsyncBoot / WaitAtaAsyncBootBounded caller-less). |
| RE-POPS-087 | NONE | §4: UNEXPLAINED — embedded_get's bare-name fallback branch can never execute. |
| RE-POPS-088 | MATCH | POPSLOADER-039. |
| RE-POPS-089 | NONE | §4: UNEXPLAINED — `default.png` registered/embedded only conditionally; the file is not in the repo. |
| RE-POPS-090 | PARTIAL | POPSLOADER-032. |
| RE-POPS-091 | PARTIAL | POPSLOADER-032 (one limb of RE-POPS-091 — the test-consumed `UI.ResolveSelectedVcdPath` — was refuted inside REDO's own verification; the dead-surface remainder stands). |
| RE-POPS-092 | PARTIAL | POPSLOADER-051. |
| RE-POPS-093 | NONE | §4: UNEXPLAINED — StripVcdExtension defined independently in both Lua files. |
| RE-POPS-094 | NONE | §4: UNEXPLAINED — scene-background image cascade written out twice in ui.lua. |
| RE-POPS-095 | MATCH | POPSLOADER-047. |
| RE-POPS-096 | MATCH | POPSLOADER-070. |
| RE-POPS-097 | NONE | §4: COVERAGE — dead duplicate files inside `__usbd_bd_assault` that its Makefile never compiles (OLD's declared tarball method for the merged generation was diff-against-components, not an independent read of merged build lists). |
| RE-POPS-098 | MATCH | POPSLOADER-107. |
| RE-POPS-099 | NONE | §4: UNEXPLAINED — libbdm ships `bd_defrag`, which nothing calls (OLD's tarball census lists bd_defrag as libbdm content; no dead-code finding was filed). |
| RE-POPS-100 | NONE | §4: UNEXPLAINED — ffsystem.c carries dead sample code for four other OSes (OLD read the same file for POPSLOADER-097's grant defect). |
| RE-POPS-101 | NONE | §4: COVERAGE — tarball CI builds only the merged drivers + libbdm; five component modules never compiled (OLD's census inventoried the tarball's CI.yml as "File listing" only). |
| RE-POPS-102 | NONE | §4: COVERAGE — merged USBD Makefile adds a nonexistent include directory (same merged-generation method limit as RE-POPS-097). |
| RE-POPS-103 | NONE | §4: UNEXPLAINED — build pipeline triplicated across three workflows (~170-line publish script ×2). |
| RE-POPS-104 | NONE | §4: UNEXPLAINED — publishing channels run a weaker gate set than CI (docs_verify only in compilation.yml). |
| RE-POPS-105 | MATCH | POPSLOADER-055. |
| RE-POPS-106 | MATCH | POPSLOADER-024. |
| RE-POPS-107 | MATCH | POPSLOADER-063. |
| RE-POPS-108 | NONE | §4: UNEXPLAINED — "29 keys" settings lists enumerate only 23 keys in three docs. |
| RE-POPS-109 | NONE | §4: UNEXPLAINED — "Cover art reads exactly ONE path per device" — UDPFS reads two. |
| RE-POPS-110 | NONE | §4: UNEXPLAINED — CONTRIBUTING.md packaging contract describes the pre-Ember ZIP. |
| RE-POPS-111 | NONE | §4: UNEXPLAINED — pervasive stale path:line anchors and line counts in ARCHITECTURE.md / COMPONENTS.md. (POPSLOADER-068 is one instance of the class, filed by OLD as its own finding.) |
| RE-POPS-112 | NONE | §4: UNEXPLAINED — COMPONENTS.md on-card payload lists only three of six BDMA IRX variants. |
| RE-POPS-113 | MATCH | POPSLOADER-062. |
| RE-POPS-114 | NONE | §4: UNEXPLAINED — STATE.md says the dropped Square binding still toggles cover art. |
| RE-POPS-115 | NONE | §4: UNEXPLAINED — STATE.md says carousel devices are "all shown by default"; i.Link ships hidden. |
| RE-POPS-116 | NONE | §3: **REAL** — `bdm_connect_bd` silently drops a device when all 20 mount slots are full. |
| RE-POPS-117 | NONE | §3: **REAL** — `chrg_connect` dereferences `config->bConfigurationValue` unchecked in both BT copies. |
| RE-POPS-118 | NONE | §4: UNEXPLAINED — three docs describe `PLDR.GetBootKind` as a consumed public API; it has no consumers. |
| RE-POPS-119 | NONE | §4: UNEXPLAINED — stale comment at ui.lua:2050 contradicts the cascade below it. |
| RE-POPS-120 | NONE | §4: UNEXPLAINED — COMPONENTS.md:400-405 presents three dead binaries as live and misstates the mx4sio_bd pin source. |

---

## 3. Adjudications — defect-class NONEs and PARTIALs, re-derived from code at the pin

### 3(a) OLD-only (and the one OLD PARTIAL defect) — 26 adjudicated, 26 REAL, 0 NOT-REAL

| ID | Ruling | Decisive evidence |
|---|---|---|
| POPSLOADER-017 | REAL | `src/luasystem.cpp:35` `#define MAX_DIR_FILES 512`; inside `lua_dir` (no `static`): `:721` `sceMcTblGetDir mcEntries[MAX_DIR_FILES] __attribute__((aligned(64)));`, consumed `:735`. Stack allocation verbatim; ~32 KB at the SDK's ~64 B/entry (struct size is SDK-side, as the finding's confidence split already states). |
| POPSLOADER-020 (PARTIAL defect) | REAL (latent) | `src/luagraphics.cpp:276-279`: `malloc(16)` → `sprintf(buffer, "%i", (int)image)` → stored as `imgThreadData`. Mechanism verbatim; on EE the 32-bit value formats to ≤11 chars + NUL, so no overflow occurs at the pin — the OLD text itself concedes this; the defect is the fragile idiom. Distinct from RE-POPS-028's argument-lifetime UAF in the same thread function (also REAL, §3(b)). |
| POPSLOADER-021 | REAL | `src/luasystem.cpp:600` (`lua_getCurrentDirectory`): `getcwd(path, 256);` result ignored, uninitialised `char path[256]` pushed; `:681` (`lua_dir`) same. In-file contrast: `:629` and `:646` check `getcwd` and raise. |
| POPSLOADER-030 | REAL | `bin/POPSLDR/system.lua:6675-6683`: rollback calls `ApplySettingsState({ profile = …, popstarter_mode = next_state.popstarter_mode, … })`. Coordinator-verified: `popstarter_mode` occurs exactly once in the file (line 6678); neither `SnapshotSettingsState` (:5959) nor `ApplySettingsState` (:5994) produces or consumes `profile`/`popstarter_mode` (grep of both bodies: zero hits). |
| POPSLOADER-038 | REAL + COVERAGE | `iop/ata_bd_fast/ps2atad.c:1182-1183`: `ata_get_security_status(device, devinfo, NULL)` at the unconditional `finish:` of `sceAtaSecurityEraseUnit`. Callee passes the buffer straight to `ata_device_identify` (`:1111-1114` → `:921-925`); IDENTIFY is a type-2 PIO-in command (`:139`) whose transfer loop writes 256 words through the stored buffer (`:709-715`) — 512 B written through NULL on a successful IDENTIFY (the normal post-erase path). All other callers pass the static `ata_param[256]` (`:84`). **Coverage:** the cited line 1183 lies inside REDO's declared unread band for this file (Appendix B: `ps2atad.c` lines 801–1186 not read) — the only adjudicated item on either side whose absence is fully explained by the other side's declared not-read list. |
| POPSLOADER-066 | REAL | All three workflows compile before verifying (`compilation.yml:171-175` `make clean elfloader all`; rolling `:166`; experimental `:162`). The build regenerates the committed file in place (`Makefile:356-359` → `src/elf_loader/Makefile:30-33`: bin2c + `touch $@`). The verify gate (`compilation.yml:193`) tests `loader.c -nt src/loader/src/loader.c` — false for the just-touched file, so the comparison normally skips; when `cmp` runs (`:196-197`) it compares the just-regenerated on-disk file against a fresh bin2c of the same just-built ELF. No workflow diffs the committed blob (no `git diff`/`git show HEAD:` for loader.c anywhere). |
| POPSLOADER-071 | REAL | `tarball:usbmass_bd/src/usb_mass.c:260-263`: the CSW struct **is** the receive buffer and is pre-filled with the expected values (`csw->signature = CSW_TAG; csw->tag = tag; csw->dataResidue = 0; csw->status = 0;`) before `sceUsbdBulkTransfer(…, csw, 13, …)` at `:265-270`. `usb_bulk_status` returns only `returnCode` (`:272-274`); the `returnSize != 13` check is `#ifdef DEBUG`-only and log-only (`:276-278`). `usb_bulk_manage_status` (`:311,316`) therefore validates a short-but-OK transfer against the driver's own pre-filled signature/tag and returns pre-filled `status = 0`. Scope as filed: an error-returning transfer is not laundered (retry + reset path at `:303-316`). |
| POPSLOADER-079 | REAL | `tarball:usbd/src/hub.c:702` stores `dev->privDataField = hubDevice;` **before** the endpoint open; the failure path (`:705-708`) frees the hub buffer and returns −9 without clearing the field. Both connect callers discard the result (`driver.c:63-64`, `:174-176`). `hubDrvDisconnect` (`hub.c:733`) frees through the stale field again, and `freeHubBuffer` (`hub.c:83-89`) has none of the already-free scans the sibling pool frees have — the block enters the free list twice. |
| POPSLOADER-082 | REAL | `tarball:bdmfs_fatfs/src/fs_driver.c:310-313`: `O_CREAT→FA_OPEN_ALWAYS` and `O_TRUNC→FA_CREATE_ALWAYS` OR'd unconditionally (write flags set separately at `:308-309`, never tested); `ff.c:3718-3725,3742`: `f_open` creates on `FA_CREATE_ALWAYS|FA_OPEN_ALWAYS` and truncates on `FA_CREATE_ALWAYS`, neither gated on `FA_WRITE`. A read-only open can create or truncate. |
| POPSLOADER-085 | REAL | `fs_driver.c:363`: `FSIZE_t off = offset;` — `FSIZE_t` is unsigned QWORD (`ff.h:72`), so a negative `s64` offset becomes ~2⁶⁴; `:367`/`:370` wrap identically into `f_lseek` (`:374`) with no negative check. `whence` switch (`:365-372`) has no `default:` — invalid whence silently behaves as SEEK_SET. |
| POPSLOADER-087 | REAL | `fs_driver.c:339-341`: `ret = f_close(fd->privdata); fd->privdata = NULL;` unconditional (same pattern `:500-502` for `f_closedir`). FatFs invalidates `obj.fs` only on success (`ff.c:4163-4173`, `:4608-4615`), and pool reuse keys solely on that field (`fs_driver.c:244`, `:258`) — a failed close permanently strands one of 128 FIL / 16 DIR slots. |
| POPSLOADER-090 | REAL | Raw `-ret` on an `FRESULT` at `fs_driver.c:321, 345, 438, 458, 484, 506, 617, 764` (open/close/remove/mkdir/dopen/dclose/getstat/rename). Namespace mismatch is in-tree: `ff.h:281-285` `FR_NO_FILE=4, FR_NO_PATH=5, FR_EXIST=8` ≠ the `ENOENT=2`/`EEXIST` callers test for; the same file uses real errnos elsewhere (`-EMFILE`, `-ENXIO`). |
| POPSLOADER-091 | REAL | `fs_driver.c:401` `fs_write` returns `(ret == FR_OK) ? bw : 0;`; `:420` `fs_read` the same with `br`; `fs_dread` (`:568-575`) returns 1 only on `FR_OK && fname[0]`, else 0 — every FatFs error is indistinguishable from EOF / nothing-written / end-of-listing. (Coordinator spot-checked `:386-421` directly.) |
| POPSLOADER-092 | REAL | Prefixing macro `fs_driver.c:41-61` (core `:48-53`): for `unit != 0`, `__builtin_alloca(3 + strlen(name) + 1)` + full `memcpy` of the EE-supplied name, no length cap at any of the 7 expansions (`:294, 431, 451, 469, 608, 751, 752` — worker counts 7 expansions across 6 functions; the finding said six sites). |
| POPSLOADER-093 | REAL | `tarball:usbd/src/hcd.c:380-381`: `u8 *memBuf = AllocSysMemory(ALLOC_FIRST, memSize, 0); memset(memBuf, 0, memSize);` — no NULL check before `memBuf` becomes the pool base (`:383+`). Allocation failure is a NULL memset inside `initHcdStructs` at module load. |
| POPSLOADER-094 | REAL | Three layers, each discarding failure: `hcd.c:361` calls `initHardware();` bare (its −1 at `:342-344`); `hcd.c:535,538` call `initHcdStructs();` / `initHubDriver();` bare in `hcdInit` (hub allocation failure returns −1, `hub.c:52-55`); `usbd.c:406` calls `hcdInit();` bare and `:409` returns `MODULE_RESIDENT_END` unconditionally. Worker found the scope slightly broader than filed (it also swallows `hcdInit`'s intr-handler failure return). |
| POPSLOADER-095 | REAL | `tarball:usbd/src/driver.c:147-166` (`doUnregisterDriver`) patches neighbours and disconnects but never clears `drv->next`/`drv->prev`; re-registration then refuses at `:73-74` (`USB_RC_BUSY`) and `:100-101` (`USB_RC_BADDRIVER`). Exact as filed (a sole registrant, both pointers already NULL, is the only escape). |
| POPSLOADER-096 | REAL (latent) | `ffconf.h:206` `FF_LBA64=1` makes `LBA_t` a QWORD (`ff.h:73-74`) and `bdm.h:36` `sectorCount` is `u64`, but `diskio.c:132` writes `*(unsigned int *)buff = mounted_bd->sectorCount;` — 4 bytes into the 8-byte buffer, upper half left stale; `:135` writes the same 4 bytes for GET_SECTOR_SIZE into FatFs' 2-byte `WORD` buffers (`ff.c:5680`, `:5816`) — a 2-byte over-write. Stronger latency than filed: at this pin no caller is even compiled (`FF_USE_MKFS=0`; `FF_MAX_SS == FF_MIN_SS == 512` compiles out the remaining site). |
| POPSLOADER-098 | REAL | `tarball:usbd/src/hub.c:148-167` (`hubGetHubStatusCallback`): the whole body sits inside `if (req->resultCode == USB_RC_OK)` with no else — on error it neither continues nor re-arms; same shape at the chain head (`:144-145`, debug print only), `hubGetPortStatusCallback` (`:577-578`), and `hubSetPortPower` (`:594`). `getHubStatusChange` is called only from inside this chain (`:142, 304, 602`), so one transient error permanently stops hot-plug detection for that hub. Permanence is structural/INFERRED, as the finding labels it. |
| POPSLOADER-099 | REAL | `hub.c:91-101`: `HubControlTransfer` drops the request when `controlIoReq.busyFlag` is set (debug print only; no queue/retry/return). `hubResetDevice` sets `delayResets = 1`, `DEVICE_RESETPENDING`, `resetFlag = 1` (`:315-317`) **before** issuing the PORT_RESET through that droppable function (`:326-328`); if dropped, the reset callback never runs and the global `delayResets` deflects every other device's reset (`:312-313`). Wedge persists until the device is flushed/killed (`checkDelayedResets`, `:349-354`) — consistent with the finding's "until physically disconnected" scope. |
| POPSLOADER-100 | REAL | `tarball:usbd/src/usbd.c:302-312` (`ParseOptionInput`): digit loop accumulates `value = (((value << 2) + value) << 1) + NewValue;` into a plain `int` with no overflow/range check (zero also accepted), written straight into `usbConfig` (`:316`). Consumers size and lay out the HCD pools independently from the same fields (`hcd.c:366-381`, `:400-462`); degenerate case verified: `maxTransfDesc == 0` skips the loop at `hcd.c:451` but the unconditional tail write at `:455` still executes into the neighbouring pool. Layout-corruption consequence INFERRED, as filed. |
| POPSLOADER-102 | REAL | `fs_driver.c:548`: `stime[1] = (ftime << 1) & 31;` — FAT `ftime` bits 0–4 hold seconds/2 (0–29), so correct recovery is `(ftime & 31) * 2` (0–58); `& 31` yields the value mod 32. Stored seconds 32–58 therefore report exactly 32 s early; the adjacent hour/minute conversions (`:546-547`) are correct. |
| POPSLOADER-103 | REAL | `fs_driver.c:660` `int ret = 0;`; the ioctl2 switch's `default:` (`:729-730`) just breaks; `:733-734` returns `ret` — unknown commands return 0/success having done nothing, reached from `fs_ioctl` too (`:738-741`). The file's own contrary convention: `fs_devctl`'s default returns `-ENXIO` (`:791-793`). (Coordinator spot-checked `:725-745` directly.) |
| POPSLOADER-104 | REAL | `tarball:bdmfs_fatfs/src/diskio.c:127-140`: switch handles only CTRL_SYNC / GET_SECTOR_COUNT / GET_SECTOR_SIZE / GET_BLOCK_SIZE, no `default:`; `:142` `return RES_OK;` is unconditional — every unimplemented command on a mounted drive (e.g. `CTRL_TRIM`) is reported performed. `RES_PARERR` exists (`diskio.h:22`) and is never returned here. |
| POPSLOADER-105 | REAL (conditional) | `fs_driver.c:571`: `strncpy(buffer->name, fno.fname, 255);` never writes index 255 and `fs_dread` never pre-zeroes or post-terminates the buffer; `fname` can hold a 255-char name (`ff.h:254`, `FF_LFN_BUF=255`), filling indices 0–254 exactly and leaving termination to the caller buffer's stale byte 255. Conditional as filed ("can"); the destination size comes from the out-of-tarball iomanX header. |

### 3(b) REDO-only (and REDO PARTIAL defects) — 23 adjudicated, 23 stand in final form

| ID | Ruling | Decisive evidence |
|---|---|---|
| RE-POPS-003 | REAL | `modules/pademu/pademu.c:228`: scan `for (ctrl = 5; ctrl < td->in_size - 3; ctrl++)` on a `u32 in_size` (`pademu.h:46`) with an equality-only not-found test (`:236`) — a short transfer wraps the bound. `pademu_cmd` (`:369`) receives **no input length at all** yet reads `in[1]`…`in[8]` (`:385-492`). Multitap: `:528` `mtap_slot = td->in[2];` unchecked against `MAX_SLOT 4`, then used as `port` indexing `pad[MAX_PORTS]` / `ds34pad[4]` (`:361-377`). Scope corrections from the worker: the `pademu()` copy's scan variable is `u8` (wraps at 255); at `:415` `out_size - 3` promotes to a huge unsigned count via the memcpy path (underflow limb stands, magnitude understated). |
| RE-POPS-007 | REAL | `tarball:usbmass_bd/src/usb_mass.c:648-665` (`usb_mass_connect`): no NULL check on `device`/`config` (its own `probe` checks both, `:582-597`); `interface` derived as `config + config->bLength` and dereferenced (`:655-658`); `endpoint` from `sceUsbdScanStaticDescriptor` passed unchecked to `usb_bulk_probeEndpoint`, which reads `endpoint->bmAttributes` immediately (`:546`); the stepping loop advances by device-supplied `endpoint->bLength` with no `bLength == 0` guard and no bound against `config->wTotalLength`. (Citation scope note: the filed span 593-670 covers the tail of `probe` plus `connect` at `:616-694`.) |
| RE-POPS-008 | Original claim NOT-REAL; narrowed claim REAL | Code: `tarball:usbd/src/hcd.c:185-205`. (a) The filed "read past the end pointer" is defeated by the loop condition `while (((u8 *)descBuf < (u8 *)dev->staticDeviceDescEndPtr) && (descBuf->bLength >= 2))` (`:200`) — `&&` short-circuits, so a first step landing at/past the end never dereferences and returns NULL. (b) The narrowed claim (REDO's own REVISED form) holds on both limbs: a bogus `data->bLength` (`:192-193`) lands the walk mid-descriptor and the loop interprets interior bytes as descriptors (callers chain this way, `hub.c:678-696`); and a walk landing on `EndPtr − 1` reads `bDescriptorType` at offset 1 — exactly 1 byte at `EndPtr` (`:201`). |
| RE-POPS-009 | REAL | Both BT copies. HCI handlers receive no length at all: `modules/pademu/ds34bt.c:499` `HCI_event_task(int result)`; the callback discards `bytes` (`:760-763`), then the handler switches on `hci_buf[0]`, reads to `hci_buf[11]`, and `memcmp(hci_buf + 9, "Wireless Controller", 19)` (`:613`) against the 64-byte `hci_buf` — plus a true OOB read: `for (i = 0; i < hci_buf[2]; i++)` indexing `hci_buf[3 + i]`/`[4 + i]` (`:569-570`) with a device-supplied count up to 255. L2CAP handlers receive `bytes` but use it only to forward to `hid_readReport`, parsing `l2cap_buf[8]`…`[19]` with no minimum-length check (`:908-1054`). HID parses the cast report struct before any length gate (`:1211-1217`). Standalone copy identical (`modules/ds34bt/iop/ds34bt.c:536, 824-827, 972, 1276-1282`). |
| RE-POPS-016 | REAL (scope corrections) | `tarball:usbmass_bd/src/scsi.c:101-118`: `scsi_cmd_rw_sector(…, u64 lba, …)` issues READ(10)/WRITE(10) and encodes only the low 32 bits of the LBA (`comData[2..5]`), dropping the high half with no range check — the code's own comment admits it (`:108-110`: "LBA from bdm is 64bit but SCSI commands being used are 32bit… up to 2TB drives"). Capacity comes from READ CAPACITY(10) (`:94-99`, `:173-175`). The surrounding stack is 64-bit as claimed (`bdm.h:35-39` u64 fields; `FF_LBA64 1`; GPT u64 LBAs). Corrections: `sectorCount` itself is a `u64` field — truncation is at the capacity source and the command encoding; capacity doesn't wrap, it saturates (0xFFFFFFFF stored literally → a >2 TiB drive silently mis-sized to ~2 TiB); LBA aliasing is unconditional inside `scsi_cmd_rw_sector` for any `lba ≥ 2³²` actually issued (reachable e.g. via GPT partition offsets passed through `part_driver.c:64,79` with no bound against the capped count). The `:175` last_lba off-by-one is the separate matched finding (RE-POPS-005). |
| RE-POPS-021 | REAL | `src/fntsys.cpp:91-94`: `FNT_MAX_COUNT 16`, `static font_t fonts[16]`. Unchecked Lua-supplied ids dereferenced at `:552,559-561` (`fntSetPixelSize`/`fntSetCharSize` — via `fntCacheFlush` at `:168-183` this is an OOB read/write/free, not just a read), `:606` (`fntRenderString`), `:912` (`fntCalcDimensions`); no negative-id check anywhere. The Lua bindings pass the raw integer straight through (`src/luagraphics.cpp:379-420`). The only bound in the file is in `fntRelease` (`:281-282`). |
| RE-POPS-022 | REAL (sound limb narrowed) | Handles are issued as integers (`src/luagraphics.cpp:529-545`) and taken back with immediate dereference and no validity check (`lua_drawimg`, `lua_width`/`lua_height`/`lua_filters`, `:549-653`); `lua_free` (`:761-786`) frees through the handle with no liveness record — a second call re-dereferences and re-frees (double-free reachable); handle 0 dereferences NULL. Timer bindings repeat the pattern, and the guard itself dereferences first (`src/luatimer.cpp:36-38`: cast, then `if (src->magic != TIMER_MAGIC)`). Sound limb narrowed: the callees NULL-check (`src/sound.cpp:132-135, 141-143`), so a 0 ADPCM handle is safe; a wild or repeated handle is not (`:144-145` frees again on a second call). |
| RE-POPS-023 | REAL | Parent stage: only an ELF magic check precedes the copy loop; `src/elf_loader/src/elf.c:465`: `memcpy(boot_pheader[i].vaddr, boot_elf + boot_pheader[i].offset, boot_pheader[i].filesz);` — iterating header-supplied `phnum` with no phentsize sanity, no `offset + filesz` check against the blob, no destination-range check, plus an unchecked BSS memset. Child stage caps `phnum` (≤16) but loads straight to the header-supplied address (`src/elf_loader/src/loader/src/loader.c:257`: `fileXioRead(fd, phdrs[i].vaddr, phdrs[i].filesz);`) and accepts `hdr.entry` unconditionally. |
| RE-POPS-024 | REAL | All four headers declare `u8 data[18]` (`modules/pademu/ds34usb.h:31`, `modules/pademu/ds34bt.h:48`, `modules/ds34usb/iop/ds34usb.h:30`, `modules/ds34bt/iop/ds34bt.h:52`); all four `get_data` implementations `mips_memcpy(dst, ds34pad[port].data, size)` with no `size` check (pademu USB `:546`, pademu BT `:1436`, standalone USB `:553`, standalone BT `:1529` — the standalone copies check `port` but not `size`). Reachable over-copy via pademu: `pademu.c:415` passes the SIO2-derived `out_size - 3` (up to ~252), over-reading `data[18]` and over-writing `&out[3]`. Second limb also REAL: pademu entry points lack the `port >= MAX_PADS` guard the standalone copies have — the same guard-loss observation POPSLOADER-049 recorded from the other direction. |
| RE-POPS-027 | REAL | (a) `src/luagraphics.cpp:810-826`: `luaL_checkinteger` length never compared to the string's true length before `loadEmbeddedPNG(ptr, siz, true)`; the reader bounds only against the supplied size (`src/graphics.cpp:383`, `:54`), so an oversized length reads past the Lua string. (b) `src/luasystem.cpp:2608-2627`: a C-string API is used on binary module data, negative `size` unchecked, `arg_len` never checked against `args`, all fed to `SifExecModuleBuffer`. |
| RE-POPS-028 (PARTIAL defect) | REAL | `src/luagraphics.cpp:489-512` (`lua_loadimgasync`): the `luaL_checkstring` pointer itself is stored and handed to `StartThread` (`:510`) with no copy; the worker reads it in `imgThread` (`:265-268`) — the Lua-owned string can be collected/moved mid-load. The file documents exactly this hazard in its cover-worker comment (`:36-44`). Second-argument defect verified: `:491` errors unless `argc == 1`, making the `argc == 2` branch at `:493` unreachable. Distinct mechanism from POPSLOADER-020 (the result-return channel in the same thread function). |
| RE-POPS-030 | REAL | No allocation in `src/atlas.cpp` is NULL-checked: `allocNew` (`:12-25`) writes through its `malloc` result immediately; `allocPlace` stores two unchecked `allocNew` results per placement; `atlasNew` writes through unchecked `malloc`/`memalign` and then `memset`s the surface pointer — a failed `memalign` is a NULL memset. OOM in the glyph-atlas path (every rendered character) is a NULL dereference, not the failure return the caller already implements for placement failure. |
| RE-POPS-031 | REAL (lseek limb overstated) | `src/fntsys.cpp:147` (`readFile`): `read(fd, buffer, realSize);` — return value discarded; `*size = realSize` reported regardless. Caller `fntLoadSlot` (`:286-312`) hands the buffer and the full claimed size to `FT_New_Memory_Face` — a short read leaves an uninitialised tail. The failed-lseek limb is not independently harmful (the existing `if (!buffer)` branch returns NULL cleanly). |
| RE-POPS-032 | REAL | `src/graphics.cpp:933-935` (`loadFont`): `int file = open(path, O_RDONLY, 0777); uint16_t magic; read(file, &magic, 2); close(file);` — none of the three calls checked; on open failure `read` fails and the uninitialised stack `magic` selects the font branch. Caller nuance as filed: `lua_fontload` NULL-checks the result, but `lua_print`/`lua_fontunload` cast an unchecked integer to `GSFONT*` and dereference through it (`src/luagraphics.cpp:296-315`). |
| RE-POPS-033 | REAL | `src/luacontrols.cpp:160` (`lua_getpressure`): `padButtonStatus pad;` uninitialised — in pointed contrast to its hardened siblings in the same file (`= {0}` initialisers, neutral defaults, a `have` flag). All read return values are discarded (`:166-168`) and the `switch` then reads the pressure fields; the ds34 writes in any case target only `&pad.btns`, not the pressure fields. |
| RE-POPS-034 | REAL | `src/luaHDD.cpp:47` (`UmountPart`): `PFS[3] = '0' + luaL_checkinteger(L, 1);` on the fixed `"pfs0:"` template with no range check in either direction (index 17 → `pfsA:`, −1 → `pfs/:`), passed to `fileXioUmount`. `mnt` (`:61-62`) guards only `index > 0`, so any index > 9 writes a non-digit byte into the name passed to `fileXioMount`. (A negative index in `mnt` is incidentally safe.) |
| RE-POPS-035 | REAL | `modules/ds34usb/ee/libds34usb.c:135-137`: `ret = (SifCallRpc(…) == 0); memcpy(data, rpcbuf, 18);` — the copy is unconditional, outside any `if (ret)`, out of a static never-cleared `rpcbuf[64]` (`:18`). BT client identical (`libds34bt.c:128-130`). Scope note: the USB `get_bdaddr` shares the shape (`:75-80`); the BT `get_bdaddr` does not (copies only inside the success branch, `libds34bt.c:84-88`). |
| RE-POPS-039 | REAL as filed (conditional) | `tarball:usbd/src/driver.c:243-250`: the request is copied (`memcpy(&reqCopy, req, …)`), the original freed back to the shared pool (`freeIoRequest(req)`), and then — under `#if USE_GP_REGISTER` — `SetGP(req->gpSeg)` reads the **freed original**, while every other post-free use correctly reads `reqCopy` (`:252`). Reachability: `USE_GP_REGISTER` is defined nowhere in the tarball (grep: uses only; no `#define`, no `-D` in the Makefiles), so the line is compiled out of the tarball's own build and activates only under an external PS2SDK configuration — exactly the finding's filed "GP-register build only / latent" framing. |
| RE-POPS-041 (PARTIAL) | Census REAL; one sub-claim NOT-REAL as written | Worker's independent script (`git ls-files`, ELF magic, SHA-256 dedupe): **38 tracked binary files, 1,778,343 bytes, 26 distinct** — the filed figures reproduce exactly. Per distinct hash: **23 sourceless, 2 with in-repo source, 1 partial** (`ata_bd.irx`, pinned to an external R3Z binary with the vendored source "kept but unused"). 18 of 26 distinct have no enforced pin in the named locations; 12 of 26 have no hash recorded anywhere. The filed "six popsmb IRX have no recorded expected hash anywhere" is false as written: all six SHA-256s are recorded descriptively in the tracked `.research/research/original-git-network-quickstarter-overlap.md:11-16` (no gate enforces them), and both usbexfat hashes are on record under their twins' names — the `.usbexfat` paths themselves remain ungated, so the silent-swap substance holds. This matches the narrowing REDO's own verification had already applied (final status REVISED). |
| RE-POPS-043 | REAL | `bin/POPSLDR/system.lua:2508` defines `KEYBOARD_LAYOUT_ABC = "ABC"` and `ui.lua:2533` offers it (`layout_order` includes "ABC", with a complete ABC row set at `ui.lua:2570-2578`), but `NormalizeKeyboardLayout` (`system.lua:2526-2546`) has branches only for QWERTY/DVORAK/AZERTY/QWERTZ/ABNT and then — under the comment "ABC remains selectable" — returns QWERTY. Every persistence path routes through it (`:5904, 5967, 6015, 6451`), and the editor's own ABC-accepting fallback is shadowed by the delegation (`ui.lua:2610-2615`). Selecting ABC always resolves to QWERTY. |
| RE-POPS-059 | REAL (core; one sub-claim past-tense) | `STATE.md:65` states present-tense "New factory defaults (EXP34…): SMB/network = PS2 IP 192.168.1.10, gateway/DNS 192.168.1.1, server 192.168.1.100, share games, user guest, port 1111 (DHCP stays ON). Reset Defaults targets these." The code defaults are the opposite: `bin/POPSLDR/system.lua:5760-5764` ("NO DEFAULT VALUES for anything POPSTARTER reads… Blank now means blank") and `:5771-5788` (`DHCP default = false`; IP/gateway/server/port/share/user/pass all `default = ""`). At `STATE.md:237` the closing note "the SMB Port default 1111 is deliberate" is present-tense and REAL; the DHCP clause in the same line is past-tense narration of the pre-fix state and should not count as current drift — the same narrowing REDO's verification applied. |
| RE-POPS-116 (NEW) | REAL | `tarball:bdm/src/bdm.c:50-66`: `void bdm_connect_bd(…)` scans `g_mount[20]` (`:18-19`) for a NULL slot; if none exists the loop exhausts and the function falls off the end — no mount, no event flag, no error branch, and the `void` signature (`bdm.h:60`) makes propagation impossible by construction; callers ignore the outcome (`scsi.c:279-280`). Corrections: the only log is the unconditional entry line (`:54`), printed identically on success; nothing is leaked inside `bdm_connect_bd` itself on the full path (the cache is allocated only after a free slot is found) — the dropped device's caller-side slot staying claimed is a caller consequence. |
| RE-POPS-117 (NEW) | REAL | Both BT copies: `modules/pademu/ds34bt.c:216-219` (standalone `modules/ds34bt/iop/ds34bt.c:221-224` identical) — `chrg_connect` takes `config` from `UsbGetDeviceStaticDescriptor` and immediately dereferences `config->bConfigurationValue` in `UsbSetDeviceConfiguration` with no NULL check. The NULL case is real: the same file's `bt_probe` explicitly anticipates NULL device/config returns (`:51-64`) and checks `bNumConfigurations < 1` (`:57`), while `chrg_probe` (`:181-196`) checks only the device descriptor and VID/PID — a matching device with no retrievable config passes probe and NULL-dereferences in connect. (The same unchecked pattern in `bt_connect` is outside this finding's scope and confirms no hidden guard exists.) |

---

## 4. Non-defect NONEs — COVERAGE vs UNEXPLAINED

Classification basis is each side's own declared scope (see Method). "UNEXPLAINED" means the artefact was inside the missing side's declared read set and no counterpart was filed; it is a statement about the comparison, not a re-adjudication of the finding (all of these stand in their own final corpus, most of them verified there).

### OLD-only → why REDO has no counterpart

**COVERAGE (11)** — every one sits in `.research/**`, which REDO's Appendix B declares keyword-scanned and sample-read only, not full-read:
POPSLOADER-001 (archive bulk), -016 (`.research/tools/` scripts), -037, -040, -045, -046 (build_site.py ×4), -052 (audit_site.py), -054 (research-gate parser copies), -056 (audit_published_provenance.py), -058 (`.research/tools/`), -059 (`.research/_state/` residue).

**UNEXPLAINED (23):**
POPSLOADER-006 (tarball presence/disposition — REDO extracted and read the tarball), -007 (IMG-vs-embed duplication — REDO read embed_assets.cpp and censused binaries), -008 (settings triple-write — REDO read system.lua in full), -014 (branches/tags — git metadata outside REDO's tree-based method, though absent from its declared not-read list), -015 (root docs sprawl — REDO read the docs and filed specifics instead), -018 (network waits — REDO read all EE C/C++), -019 (elf.c duplication — REDO read elf.c for RE-POPS-023), -023 (pcall idiom — REDO read all Lua in full), -025 (fntsys TODO block — REDO read fntsys.cpp in full), -026 (settings fallback copy — ui.lua read in full), -027 (UDPFS equipped check — system.lua read in full), -028 (TEST HDD probe — system.lua/ui.lua read), -031 (false flag in RunPOPStarterGame — system.lua read), -035 (ps2atad slave probe — cited lines are inside REDO's declared read range for the file, unlike -038), -036 (host_harness text assertions — REDO read all host tools and ran the harness), -042 (disc-layout comment extraction — REDO ran and read the tools), -044 (pad-debug block — ui.lua read in full), -050 (EE ds34 dead exports — REDO read the same libraries), -057 (host gates' comment extraction — primary artefact in `tools/`, REDO's read set), -064 (README Retro GEM row — REDO claims-checked the README), -065 (CoverCache doc claim — REDO read ARCHITECTURE.md and ui.lua), -067 (elf_loader Makefile rule — REDO read that Makefile for RE-POPS-051), -068 (COMPONENTS.md loader.c size claim — REDO read COMPONENTS.md).

### REDO-only → why OLD has no counterpart

**COVERAGE (3)** — all three turn on the merged generation's own build files, which OLD's declared tarball method established by diff against the components rather than by independent read:
RE-POPS-097 (dead files the merged Makefile never compiles), RE-POPS-101 (the tarball's own CI — OLD's census inventoried it as "File listing" only), RE-POPS-102 (merged Makefile's phantom include directory).

**UNEXPLAINED (45):**
RE-POPS-045 (merged-tree duplication — OLD's census states the fact verbatim, "the archive stores its own code twice", but no duplication finding was filed), -046 (release-zip tree embedding — OLD read all three workflows), -047 (pademu tree built by nothing — OLD read the module Makefiles and treated pademu as a live product), -048 (Lua-binding caller census — OLD filed narrower dead-surface findings only), -052 (bd_cache 128 KiB reservation — OLD read bd_cache.c for three findings), -054 (asset-table dual registration — OLD read embed_assets.cpp), -056 (three dead embed binaries — OLD inventoried `iop/embed/`), -057 (ata_bd_fast disuse — OLD filed two findings inside the stack), -058 (ps2atad stack still embedded + unused externs), -061 (fs_ioctl2 RENAME stub/dummy slots — OLD read fs_driver.c and filed a different limb of the same function), -063 (GetMassRootByBackendName — OLD read luasystem.cpp), -064 (Settings per-frame rebuild — ui.lua), -065 (scsi 16× retry — OLD read scsi.c for four findings), -066 (MINI_DRIVER unreachable — OLD read usbd.c), -067 (FIL/DIR static reserve — fs_driver.c), -068 (ListPartitions static table — luaHDD.cpp), -069 (bdm_query thread-start success — OLD read the file and recorded it clean on a different aspect), -070 (ART_LOCATION plumbing — system.lua), -071 (ABNT rows — OLD's docs pass listed the ABNT option claim as matching), -074 (TESTING.md SMB rows — OLD claims-checked TESTING.md), -076 (IRX helper duplication — main.cpp/luasystem.cpp), -078 (ResolveAssetPath duplication — system.cpp), -081 (trailing-slash helpers — system.lua), -082 (DPRINTF no-op — OLD's macro census noted the empty macro without filing it), -083 (bd_cache eviction complexity — bd_cache.c), -085 (GetFreeSize dead chain — system.cpp), -086 (async ATA worker dead — luasystem.cpp), -087 (embedded_get dead branch — embed_assets.cpp), -089 (default.png conditional registration — Makefile/embed_assets/images.lua), -093 (StripVcdExtension in both Lua files), -094 (background cascade written twice — ui.lua), -099 (bd_defrag caller-less — OLD's census lists it as libbdm content), -100 (ffsystem.c OS sample code — OLD read the same file for the grant defect), -103 (workflow triplication — OLD cited all three workflows), -104 (publishing-channel gate set), -108 ("29 keys" lists — OLD claims-checked all three docs), -109 (cover-art one-path claim), -110 (CONTRIBUTING packaging contract), -111 (anchor rot — OLD filed one instance of the class as POPSLOADER-068), -112 (COMPONENTS payload variants), -114 (STATE Square binding), -115 (STATE carousel default), -118 (GetBootKind docs), -119 (stale ui.lua comment), -120 (COMPONENTS dead-binaries-as-live).

---

## 5. Most consequential one-sided findings, and the NOT-REAL record

### Five most consequential OLD-only REAL findings (all §3(a))

1. **POPSLOADER-071 — CSW validation defeated by a pre-filled receive buffer** (tarball usb_mass.c). The status block a mass-storage transfer is validated against is written by the driver itself before the transfer; a short-but-successful transfer silently "validates" against the driver's own bytes. This is a protocol-integrity defect in the storage path every BDMA device depends on.
2. **POPSLOADER-082 — `fs_open` honours O_CREAT/O_TRUNC without write access** (tarball fs_driver.c). A read-only open can create or truncate a file — a data-loss defect reachable by any IOP client of the BDM filesystem.
3. **POPSLOADER-079 — failed hub connect leaves a freed UsbHub reachable; unplug double-frees it** (tarball hub.c). Device-arrival failure followed by removal corrupts the hub pool (double free-list insertion), in the USB stack every BDMA device hangs off.
4. **POPSLOADER-066 — the loader.c CI parity check never compares the committed dump.** The only automated guard on an 855 KB generated file embedded in every build is vacuous (compile-then-verify ordering + self-comparison); OLD's history check showed the committed dump had already been ~7 weeks stale once. A process defect with direct shipped-artefact consequences.
5. **POPSLOADER-092 — unbounded `alloca` filename prefixing on the IOP handler stack** (tarball fs_driver.c). EE-supplied filename length drives a stack allocation with no cap, in seven expansions across the filesystem handlers.
   Runners-up: POPSLOADER-091 (all FatFs errors collapse to 0 in fs_read/fs_write/fs_dread), POPSLOADER-090 (FRESULT codes returned as errnos across eight sites), POPSLOADER-100 (module-argument integers size the HCD pools with no validation).

### Five most consequential REDO-only REAL findings (all §3(b))

1. **RE-POPS-003 — pademu SIO2 parsing has no input-length floor, and the multitap slot byte is an unchecked array index.** Short transfers wrap the scan bound; `in[2]` indexes `pad[]`/`ds34pad[]` directly. Reachable from ordinary pad traffic in the module that sits between the controller and every game.
2. **RE-POPS-023 — both ELF-loading stages copy segments to header-supplied addresses with no bounds validation.** The parent loader checks only the ELF magic before `memcpy`ing to `p_vaddr`; the child stage reads segments straight to header addresses and trusts `hdr.entry`. The loader's core trust boundary, unguarded in both stages.
3. **RE-POPS-009 — Bluetooth HCI/L2CAP/HID handlers ignore received byte counts.** Handlers receive no length (HCI) or never gate on it (L2CAP/HID); includes a true out-of-bounds read (device-supplied `hci_buf[2]` count loop past the 64-byte buffer) beyond the filed stale-byte claim. In both BT copies.
4. **RE-POPS-043 — the "ABC" keyboard layout can never be selected.** Offered in the picker with complete rows, silently normalised to QWERTY on every persistence path — a user-facing feature that is entirely dead, invisible without tracing the normalizer.
5. **RE-POPS-022 — Lua handles are raw pointers cast through integers.** Image/timer handles dereference and free with no liveness record; a repeated `lua_free` double-frees, handle 0 dereferences NULL — all reachable from ordinary Lua scripts.
   Runners-up: RE-POPS-007 (usb_mass_connect endpoint walk with no NULL/bounds checks), RE-POPS-016 (SCSI layer silently caps drives at 2 TiB inside a 64-bit stack), RE-POPS-024 (`get_data` copies a caller-supplied size out of an 18-byte array, all four copies), RE-POPS-116 (device silently dropped when all 20 mount slots are full).

### NOT-REAL record

- **No finding in either final corpus was ruled NOT-REAL in its final form.** Every adjudicated one-sided defect finding (26 OLD, 23 REDO) stands as filed in its final (post-verification, post-revision) text.
- Two **pre-revision** claims are NOT-REAL, both already superseded inside the REDO's own verification before this comparison:
  - **RE-POPS-008's original claim** (HCD descriptor walk reads past the end pointer) — defeated by the short-circuit bound check at `hcd.c:200`. The narrowed claim that replaced it is REAL (§3(b)).
  - **RE-POPS-041's original sub-claim** ("six popsmb IRX have no recorded expected hash anywhere") — the six SHA-256s are recorded descriptively in a tracked `.research` note; no gate enforces them, so the silent-swap substance survives in the REVISED form.
- Latency notes (REAL but not live at the pin): POPSLOADER-020 (overflow unreachable on EE integer formatting — conceded in the OLD text itself), POPSLOADER-096 (no caller of the ioctl commands is compiled at the pin), RE-POPS-039 (the defective line compiles only under an external GP-register configuration), POPSLOADER-083/RE-POPS-011 (REDO's own verification narrowed it to latent).

### Cross-corpus notes

- **OLD internal overlap:** POPSLOADER-010 and POPSLOADER-033 are the same mechanism (ds34 code in diverging copies) filed at two groupings in different rounds; both match RE-POPS-053. POPSLOADER-003 and POPSLOADER-022 likewise share the inline-Lua limb. These are grouping artefacts of the OLD corpus, not duplicates of distinct defects.
- **Census agreement where both sides counted:** the six duplicate image pairs / 57,552 B (POPSLOADER-024 ↔ RE-POPS-106) agree exactly. REDO's binary census (38 tracked / 26 distinct / 23 sourceless) was reproduced exactly by the adjudication worker's independent script.
- **Where the corpora disagree in scope, not substance:** POPSLOADER-073 (umbrella 512 B-sector claim) vs RE-POPS-001/-004 (the same assumption split into sharper, file-local consequences) — REDO's split is the more actionable form; OLD's FatFs-config limb and "no enforcement point anywhere" framing remain unfiled by REDO.

---

## 6. Counts (from the tables above) and verification

**OLD final — 108 actionable:** 39 MATCH · 10 PARTIAL · 59 NONE.
- Of the 59 NONE: 25 defect-class → adjudicated 25 REAL (POPSLOADER-038 additionally COVERAGE-explained by REDO's declared unread band); 34 non-defect → 11 COVERAGE, 23 UNEXPLAINED.
- Plus the one PARTIAL defect (POPSLOADER-020) adjudicated REAL (latent).

**REDO final — 120 actionable:** 38 MATCH · 13 PARTIAL · 69 NONE.
- Of the 69 NONE: 21 adjudicated (20 defect-class + RE-POPS-016 high-benefit) → all stand in final form (RE-POPS-008's surviving narrowed claim REAL; its superseded original NOT-REAL); 48 non-defect → 3 COVERAGE, 45 UNEXPLAINED.
- Plus two PARTIAL defects adjudicated: RE-POPS-028 REAL; RE-POPS-041 census REAL with one superseded sub-claim NOT-REAL.

**Shared ground:** 39 OLD findings have a REDO counterpart (10 of them partial); equivalently 51 REDO findings have an OLD counterpart (38 match + 13 partial). 59 OLD findings and 69 REDO findings are one-sided — and on adjudication, essentially all of the one-sided *defect* findings on both sides are real. The two corpora are largely complementary rather than contradictory: OLD's one-sided strength is the tarball's filesystem/USBD internals (fs_driver.c, diskio.c, hub.c read line-by-line) and the `.research/` tree; REDO's is the EE-side C++ attack surface (ELF loader, Lua handle/font/atlas safety) and the pademu/BT input paths.

**Verification block**
- Clone: `~/workspace/audit-clones-2026-11-13/POPSLoader` at `29272cddbf0122f14e76bc3bdd75e3b46aa870be`; `git status --porcelain` empty at the start and end of this comparison (read-only throughout).
- BDMAssault tarball md5: **`09ff4b911ba131468a25d0ec9a4e2f27`** (coordinator-verified before extraction; workers read the extracted tree under `/tmp/bdma_adj/`).
- Evidence: six parallel adjudication workers re-read code at the pin (clone or extracted tarball); the coordinator additionally verified POPSLOADER-030, -091 and -103 first-hand. Line numbers cited are the pin's.
