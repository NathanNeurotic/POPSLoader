# Sable — POPSLoader ROUND 7 (scope extension into the round-4 residue)

**Repo:** NathanNeurotic/POPSLoader · **Pin:** `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (master) — live HEAD verified equal to the pin at round start and end (`git ls-remote` == local HEAD); **no pin move, no delta, no revalidations owed.** Read-only throughout: the BDMAssault tarball was extracted to `/tmp/bdma7` only, all analysis ran in `/tmp`, and the clone's `git status` was clean at start and end.

**Scope (user-directed extension past the round-4 exhaustion verdict):** (1) the BDMAssault tarball's contents audited as source + the shipped-binary provenance chain; (2) the generated bin2c `src/elf_loader/loader.c` — generator and invariant, not a line-read of the dump; (3) user-facing docs prose checked against code; (4) first-party assembly census + header macro pass. Nothing here repeats POPSLOADER-001…059.

**Result: 48 new findings (POPSLOADER-060…107), 2 revisions (REV-006 narrowed, POPSLOADER-011's premise corrected), 0 assembly findings, 0 macro findings.** (Tarball section: 37 findings, POPSLOADER-071…107 — of the originally claimed 26 (R7-T01…T26), only T01…T06 were ever written; the section was completed by a later repair pass, see the Section completion note inside it. The original pass's claim of "13 tarball candidates dissolved" referred to a list that was never written and is unrecoverable.)

---

## Revisions (evidence-forced)

### R7-REV-006 — REV-006 narrowed: the tarball pins ONE of the two binaries beside it, not both

Round 3's REV-006 stated: "The two `.irx` beside the tarball (`usbd.irx` 48,500 B, `usbhdfsd.irx` 14,993 B) are the binaries this source builds", with the binary↔source correspondence explicitly labelled INFERRED. Round 7 tested that inference at string level:

- **`usbd.irx` (md5 `a77650a0ad356077b990d21bde6affc4`) — correspondence CONFIRMED (string-level).** The binary contains `BDM_ASSAULT: starting Fatfs side`, which exists verbatim at `<tarball>!BDMAssault-mx4sio/__bdm_assault/src/bdmfs/bdmfs_main.c:32`, plus the BDM core and "FATFS driver" strings of the merged `__bdm_assault` build, whose Makefile produces `bdm_assault.irx` (`<tarball>!__bdm_assault/Makefile:2`). It contains **zero** occurrences of `USBD ASSAULT` — it is not the `__usbd_bd_assault` build. The archive README's install mapping (install `bdm_assault.irx` as POPStarter's `usbd.irx`) closes the chain: source → documented build → documented rename → shipped binary whose strings match the source. (Identity remains INFERRED in the strict sense — no PS2SDK in this VM, so no rebuild comparison is possible — but it is now string-corroborated, not merely folder-inferred.)
- **`usbhdfsd.irx` (md5 `48677ae01b05c84b6f299773baa7dea0`, = `bin/POPSLDR/usbhdfsd.irx.mx4sio`) — correspondence REFUTED.** The shipped binary is an **MX4SIO** block-device driver: its strings are `MX4SIO: MX4SIO v1.2`, `MX4SIO: card detection thread running`, `sio2man_hook_init`, etc. It contains zero USB/SCSI/mass-storage strings, and the tarball contains **zero** mx4sio/sio2 content anywhere in its 119 files (case-insensitive grep over the extracted tree: 0 files). The tarball's second merged build produces `usbd_bd_assault.irx` (`<tarball>!__usbd_bd_assault/Makefile:2`) — a USB mass-storage driver, a different binary from the one shipped under the `usbhdfsd.irx` name in this folder. The shipped MX4SIO driver's source is **not in the tarball and not anywhere else in the repo** (the sibling pin `iop/embed/PS2SDK_MX4SIO/` holds only a *different* MX4SIO binary, `mx4sio_bd.irx`, md5 `d63df3c91829a982fe6e6bf0f290881e`, 15,089 B — the one embedded into the ELF via `Makefile:99`).

**Revised disposition:** REV-006's fix (extract-or-archive, don't plain-delete) stands for the `usbd.irx` half — the tarball genuinely is that binary's only in-repo source pin. It does **not** extend provenance to `usbhdfsd.irx`: extracting the tarball restores nothing for that binary, whose source vintage is pinned nowhere in this repo (see POPSLOADER-069). Any future extraction should be described as pinning `bdm_assault` only.

### R7-REV-011 — POPSLOADER-011's stated rationale corrected: the CI parity check does not compare the committed dump

Pass 1 recorded the reason the 856 KB generated dump is committed: "CI validates blob parity by re-running bin2c and `cmp`-ing against the committed file." Round 7 read the three workflows (`compilation.yml:193-203`, `rolling-release.yml:195-205`, `experimental-release.yml:191-201`) and the build path they invoke (`compilation.yml:171-175` → `Makefile:358-359` → the `FORCE` rule at `src/elf_loader/Makefile:30-33`, which regenerates and `touch`es `loader.c`). Because CI rebuilds (and touches) the file *before* the verify step runs, the `-nt` gate at `compilation.yml:193` is normally skipped, and when the `cmp` does run it compares the just-regenerated file against a fresh bin2c of the same just-built ELF — **the committed blob is never compared against anything** (no `git diff`/`git show` of `loader.c` exists in any workflow). The finding's fix recommendation is unchanged; its premise ("kept because CI validates parity") is weaker than stated — the validation is ineffective for its stated purpose. Filed as the live defect POPSLOADER-066. That this is not theoretical is proven by history: five child-source commits (2026-05-25 ×3, 2026-06-04, 2026-06-15) landed with zero dump regenerations between `52f1c36` (2026-05-23) and `9c23cf0` (2026-07-14) — the committed dump was stale for ~7 weeks, *after* the parity fallback was introduced (`4cada12`, 2026-04-30).

---

## Task 1 evidence — ffunicode figure verdict + tarball inventory

**REV-006's "~79%" figure: VERIFIED as a share-of-tree figure, and clarified.** Measured from the actual bytes at this pin: `bdmfs_fatfs/src/ffunicode.c` = 1,959,389 B and `__bdm_assault/src/bdmfs/bdmfs_ffunicode.c` = 1,959,397 B; sum 3,918,786 B = **79.15%** of the 4,951,196 B extracted tree (119 files, 151 archive entries, tarball 1,466,084 B, md5 `09ff4b911ba131468a25d0ec9a4e2f27` — all matching round 3). The two copies differ by exactly one line — the `#include "ff.h"` vs `#include "include/ff.h"` at line 26 (4 diff lines; the 8-byte size delta is exactly the `include/` prefix). So the *redundant* content is one copy = **39.57%** of the extracted tree; "79%" is the combined share of the tree the duplicated table occupies. Both readings are now on record; the figure itself was correct.

**Generation census (complete):** component generation — `bdm/`, `bdmfs_fatfs/` (FatFs R0.14b, ChaN — vendored), `libbdm/` (bd_cache, bd_defrag — **component-generation only, no merged twin**), `usbd/`, `usbmass_bd/`; merged generations — `__bdm_assault/`, `__usbd_bd_assault/`. All 21 component↔merged file pairs were diffed this round: **7 pairs byte-identical, 14 differ only in `#include` paths and IRX-fusion glue** (`_start` renaming/chaining, banner, version). Correction to this round's own starting premise: the merged `bdmfs_ff*.c` copies carry **no local deltas** beyond the include line — there are no merged-only FatFs defects, and no fix exists in one generation that the other lacks. Every tarball defect below therefore exists identically in both generations (unless stated), and each fix must be applied twice or the merged generation regenerated from the component one.

**Editor's note on the appended tarball section:** its context paragraph repeats the archive README's deployment mapping (`usbd_bd_assault.irx` deployed as `usbhdfsd.irx`). Per R7-REV-006 above, the *shipped* `usbhdfsd.irx` in this repo is an MX4SIO driver, not that build; benefit lines in tarball findings that name the shipped `usbhdfsd.irx` should be read as "the `usbd_bd_assault` build, wherever deployed". The source defects themselves are unaffected.

## Task 2 verdicts — loader.c generator & invariant

- **Generator:** PS2SDK's `bin2c` (`BIN2C = $(PS2SDK)/bin/bin2c`, `src/elf_loader/Makefile:9`); rule at `src/elf_loader/Makefile:30-33` (strip in place + bin2c + touch, `FORCE`-driven via :13), driven from the top-level `Makefile:354-359`. Not an in-repo tool.
- **Invariant: HOLDS exactly.** Declared `size_loader_elf = 139700` (`src/elf_loader/loader.c:4`) vs **139,700 bytes actually counted** in the `loader_elf[]` array — exact match. The payload is a valid PS2 EE ELF (`\x7fELF`, ELFCLASS32, little-endian, `e_type=2` EXEC, `e_machine=8` EM_MIPS, entry `0x840f0`); its section table ends at 138,900 + 20×40 = exactly 139,700, so the array is a single complete ELF with no padding and no appended NUL (the trailing comma is bin2c syntax). Reconstructed payload SHA-256 `e7861872d22ac2160c6bce2eba01c7700971af3f0d14e9969d7f771263380dd4` — **recorded nowhere in the repo** (no checksum of `loader.elf` exists anywhere; contrast the pinned `ata_bd.irx` SHA-256 at `compilation.yml:95` in the same workflows).
- **Staleness verdict: NOT STALE at the pin (chronology); byte-parity INFERRED/unverified.** Last dump regeneration `9c23cf0483a2465e0b46421b81f43ffb85be7e99` (2026-07-14) postdates the last child-source change `edcd8230f17d4e96788e99a2205a77458ffd3198` (2026-06-15) and the last child Makefile/linkfile change (2026-03-29); the child source blob is identical at HEAD, at the regeneration commit, and at the last source commit. (Caution for future checks: default `git log` mis-dates the last source change to 2026-06-04 due to TREESAME merge simplification — `--full-history` is required.) No byte-compare against a built `loader.elf` is possible: the ELF is uncommitted (`.gitignore:19`), and no PS2SDK exists in this VM. Historical staleness *did* occur (~7 weeks, May–July 2026) — see R7-REV-011 / POPSLOADER-066.
- Full evidence: Annex B.

## Task 3 verdicts — docs vs code

**100 checkable claims extracted and settled: 78 MATCH, 10 UNVERIFIABLE, 12 contradicted (filed as POPSLOADER-060…065).** The MATCH set is broad and includes every README settings default, the launch-argument set, the Ember contract, the 29 settings keys, the 8 MiB PSU cap, and version 1.4.4 across all release docs (full grouped list with both-side citations in Annex A). The 10 UNVERIFIABLE claims are all claims about *external binaries* with no source in this repo (POPStarter VCD filename/path limits, UDPFS BIN/CUE limits inside the binary driver, PATHMAP.INI semantics, Ember-internal formats) plus two enumeration/anchor ambiguities — listed in Annex A, not filed, per the brief.

## Task 4 verdicts — assembly census + macro pass

- **Assembly census: 2 files, 0 first-party.** Both are the byte-identical vendored `smsutils.S` (sha256 `1a9b144f…`, 180 lines each): `modules/ds34bt/iop/smsutils.S` (consumed by `modules/ds34bt/iop/Makefile:2` → `ds34bt.irx`) and `modules/ds34usb/iop/smsutils.S` (→ `ds34usb.irx`); header credits PS2DEV / Eugene Plotnikov. Inspected anyway: no `$sp` use (no frame to imbalance), only caller-saved registers, no C-side magic count to disagree with. **No findings.** One observation, not filed: at `smsutils.S:128` the vendored `mips_memcpy` exit has no delay-slot NOP under `.set noreorder`, so `mips_memset`'s first instruction executes in the `jr $ra` delay slot (INFERRED, MIPS semantics) — unreachable in effect here because every prototype declares these functions `void` and all ~45 call sites discard the return; the file is byte-identical in 7 copies across 3 repos, so any fix is a cross-repo (X-series) decision, not a POPSLoader one.
- **Macro census: 26 headers, 24 function-like macro definitions (20 arithmetic), 30 candidates examined, 7 sizeof-division sites swept — NO macro computes a wrong size or count.** No header `#define` contains `sizeof` at all; there is no `MIN`/ALIGN/ROUND macro and no `GET_XPARAM_DB_SIZE`-class defect. Host-compiled checks: `MAX`/`CLAMP` (`luaplayer.h:42-43`) correct at their call sites, `A/B/G/R` (`graphics.h:61-64`) round-trip-verified, and all 7 sizeof-divisions are on true file-scope arrays — **no array-count idiom is applied to a pointer anywhere in the tree.** Full census: Annex C. One dead-macro defect *was* found by this pass and is filed as POPSLOADER-070 (it computes nothing wrong because it is never expanded — it is dead code referencing an undeclared variable).

---

## Findings POPSLOADER-060…070 (docs, loader, provenance, macros)

### POPSLOADER-060 — i.Link documented as "stub / NOT implemented" in three docs; the code implements the full page for Ember and POPSTARTER
- **Category:** 7 (docs drift) · **Locations:** `ARCHITECTURE.md:253` ("stub"), `COMPONENTS.md:474` ("NOT implemented"), `README.md:84,139,263` ("Ember only / POPSTARTER not implemented") vs code `src/system.lua:9166` (`InitILINKRoot`), `src/system.lua:10702` (ILINK POPSTARTER launch policy), `src/ui.lua:6425` (page handler, `OPT == 6`), `src/ui.lua:1067` (`GILINK = 11`).
- **Problem:** READ. Three user-facing docs tell users the i.Link page does nothing / is Ember-only; the shipped code implements the complete page including the POPSTARTER launch path. Users following the docs will not use a working feature (the docs elsewhere correctly note the page is hidden by default and hardware-untested — those claims MATCH and are not part of this finding).
- **Fix:** Correct the three doc statements to describe the implemented page (keeping the hidden-by-default / hardware-untested caveats, which are true).
- **Benefit:** Docs stop denying a shipped feature. **Effort:** S · **Risk:** Low · **Confidence:** High (READ, both sides).

### POPSLOADER-061 — ARCHITECTURE.md says BDMA_ADAPTIVE defaults off; the code defaults it on
- **Category:** 7 · **Locations:** `ARCHITECTURE.md:640` vs `src/system.lua:6236` (`PLDR.BDMA_ADAPTIVE = true`).
- **Problem:** READ. A default-value claim a user troubleshooting driver staging would act on is the opposite of the shipped default (other docs, e.g. EXPERIMENTAL_NOTES/ROLLING_NOTES, correctly describe Adaptive BDMA as "the default" — the architecture doc is the outlier).
- **Fix:** Change the one doc line to "default on". **Benefit:** Removes a wrong-default trap in the canonical architecture doc. **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

### POPSLOADER-062 — STATE.md's header says Slovak "awaits the contributor; SK is not yet in the picker"; SK shipped in 1.4.3/1.4.4 and is in the picker
- **Category:** 7 · **Locations:** `STATE.md:5-7` (top of the canonical status doc, under the 1.4.4 header) vs `src/system.lua:2559-2560` (SK in the language picker), dictionary at `src/system.lua:4431`.
- **Problem:** READ. The canonical doc's present-tense status contradicts the shipped code and the release notes for the very version the header names.
- **Fix:** Update the STATE.md header bullet to record SK as shipped. **Benefit:** The doc users are pointed to for current status stops being stale at its own headline. **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

### POPSLOADER-063 — Three docs still claim release 1.1.0 / rolling v1.1.1-dev in their headers; the code reports v1.4.4
- **Category:** 7 · **Locations:** `ARCHITECTURE.md:1`, `COMPONENTS.md:1`, `docs/PRESERVATION_CONTRACTS.md:3` vs `etc/boot.lua:1` and `bin/POPSLDR/title.cfg:7` (v1.4.4). Lowest priority of the doc findings: all three docs defer to STATE.md for status.
- **Problem:** READ. Stale version headers in three standing docs, three major versions behind the code.
- **Fix:** Bump the three header lines (or replace the version claim with a pointer to STATE.md, which cannot go stale the same way — the LESS option). **Benefit:** Removes version misinformation at the top of three docs. **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

### POPSLOADER-064 — README's Retro GEM Game ID row lists "On" as the only option; the code is an On/Off toggle
- **Category:** 7 · **Locations:** `README.md:149` vs `src/ui.lua:5250-5256` (toggle, default on).
- **Problem:** READ. By the settings table's own exhaustive convention, "On" alone tells users the option cannot be turned off; it can.
- **Fix:** List "On / Off" in the row. **Benefit:** One wrong settings-table row corrected. **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

### POPSLOADER-065 — ARCHITECTURE.md says CoverCache is a 3-entry LRU; the code sets max = 4
- **Category:** 7 · **Locations:** `ARCHITECTURE.md:329` vs `src/ui.lua:373` (`max = 4`).
- **Problem:** READ. A numeric limit in the architecture doc disagrees with the code by one entry.
- **Fix:** Change the doc number to 4. **Benefit:** Numeric accuracy in the internals doc. **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

### POPSLOADER-066 — The loader.c CI parity check never compares the committed dump (and history proves the dump went stale for ~7 weeks behind it)
- **Category:** 6/7 · **Locations:** `.github/workflows/compilation.yml:171-175,193-203`, `rolling-release.yml:195-205`, `experimental-release.yml:191-201`; build path `Makefile:358-359` → `src/elf_loader/Makefile:13,30-33` (`FORCE` rule regenerates + `touch`es `loader.c`).
- **Problem:** READ. The compile step regenerates `loader.c` before the verify step, so the `-nt` gate is normally skipped and any `cmp` compares two artifacts of the same build — never the committed blob (no workflow reads the committed `loader.c` from git). Evidence it bites: between regenerations `52f1c36` (2026-05-23) and `9c23cf0` (2026-07-14) five child-source commits landed (2026-05-25 ×3, 2026-06-04, 2026-06-15) with zero dump commits — the committed dump shipped stale for ~7 weeks, after the parity fallback was introduced (`4cada12`, 2026-04-30). Related gap: no checksum of `loader.elf` is recorded anywhere (contrast the pinned `ata_bd.irx` SHA-256 at `compilation.yml:95`).
- **Fix:** In the verify step, compare the *committed* blob (extract via `git show HEAD:src/elf_loader/loader.c`) against the fresh bin2c output, or record the payload SHA-256 at release time and check against it (the pattern the same workflows already use for `ata_bd.irx`). No new machinery.
- **Benefit:** The parity gate POPSLOADER-011's rationale rests on starts actually gating; the next 7-week staleness window becomes impossible to merge silently. **Effort:** S · **Risk:** Low · **Confidence:** High (READ — workflows, Makefiles, git history all read; at the current pin the dump is *not* stale, see Task 2 verdicts).

### POPSLOADER-067 — `src/elf_loader/Makefile:15-16` rule cannot build the child loader (dead rule, INFERRED)
- **Category:** 3/7 · **Locations:** `src/elf_loader/Makefile:15-16` (`$(MAKE) src/loader` with no `-C`).
- **Problem:** INFERRED. As written the rule invokes make in a non-existent/incorrect directory context and cannot produce `loader.elf`; it is harmless today only because the top-level driver (`Makefile:354-359`) builds the child first. A standalone `make -C src/elf_loader` on a clean checkout would fail at the bin2c recipe.
- **Fix:** Delete the two lines, or correct them to the `$(MAKE) -C src/loader` form the top-level driver effectively performs. **Benefit:** Removes a build path that cannot work. **Effort:** S · **Risk:** Low · **Confidence:** Medium (INFERRED — read from the Makefile text; not executed, no PS2SDK in this VM).

### POPSLOADER-068 — COMPONENTS.md calls the loader.c dump a "~6.5 MB bin2c blob"; it is 855,821 B at the pin
- **Category:** 7 · **Locations:** `COMPONENTS.md:387-388` vs `src/elf_loader/loader.c` (855,821 B, 8,740 lines, at pin).
- **Problem:** READ. The component doc overstates the dump's size ~7.6× — the figure presumably dates from an older, larger child loader.
- **Fix:** Correct the number (or drop the size claim). **Benefit:** The doc that justifies keeping the generated file stops misdescribing it. **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

### POPSLOADER-069 — The shipped MX4SIO `usbhdfsd.irx` has no source anywhere in the repo; the pin beside it does not cover it
- **Category:** 7/8 · **Locations:** `iop/embed/BDMASSAULT_MX4SIO/usbhdfsd.irx` (14,993 B, md5 `48677ae01b05c84b6f299773baa7dea0`; strings self-identify as `MX4SIO v1.2`) beside `iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz` (zero mx4sio/sio2 content in 119 files); the only other MX4SIO artifact, `iop/embed/PS2SDK_MX4SIO/mx4sio_bd.irx`, is a *different* binary (15,089 B, md5 `d63df3c91829a982fe6e6bf0f290881e`) and also source-less in-repo.
- **Problem:** READ (binary identity from strings + hashes; absence from exhaustive greps of the extracted tarball and the tracked tree). Per R7-REV-006, the folder's documented source pin covers `usbd.irx` only. The MX4SIO variant's `usbhdfsd.irx` — the driver POPStarter actually loads from the staged folder for MX4SIO — has no source vintage recorded anywhere in the repo, in a repo whose own Makefile (`Makefile:346-352`, cited in REV-006) documents that BDM-driver vintage mismatches are hang bugs.
- **Fix:** Record the binary's provenance where the pin lives (upstream project + release tag + hash — a few lines in the folder's README), the same treatment the tarball gives `usbd.irx`. No code change.
- **Benefit:** The one shipped driver with no provenance record gains one; future vintage debugging stops starting from zero. **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

### POPSLOADER-070 — Dead `hci_event_flag_*` macros in both ds34 headers reference a variable declared nowhere and have zero call sites
- **Category:** 1 · **Locations:** `modules/ds34bt/iop/ds34bt.h:81-83` and `modules/pademu/ds34bt.h:67-69` (six definitions: `hci_event_flag_clear/set/check`); the companion `HCI_FLAG_*` enums at `ds34bt.h:140` region / `ds34bt.h` (pademu) `:122` region are likewise unused and have already diverged between the two copies.
- **Problem:** READ. Each macro expands to operations on `hci_event_flag`, a variable declared nowhere in the tree (exhaustive grep: the only occurrences of the name are these definitions and their enum comment). They have zero call sites — if any future code used one, it would fail to compile; today they are pure dead weight that *looks* like live API, in the driver family where copy drift has already shipped bugs (POPSLOADER-034, -048).
- **Fix:** Delete the six macro lines (and the unused, diverged `HCI_FLAG_*` enum values with them). Pure deletion.
- **Benefit:** Removes a fake API surface from both copies of a drift-prone header. **Effort:** S · **Risk:** Low · **Confidence:** High (READ — definitions, absence of the variable, and absence of call sites all grep-verified tree-wide).

---

## Findings POPSLOADER-071…107 — BDMAssault tarball contents (appended section, renumbered)

*The tarball section follows. As originally appended it carried only POPSLOADER-071…076 (internal IDs R7-T01…T06), with -076 truncated mid-finding; the claimed R7-T07…T26, the 21-pair diff table, and the 13 dissolved candidates were never written. A later repair pass completed -076 in place and re-derived the remainder from the tarball as POPSLOADER-077…107 in benefit order — see the Section completion note inside the section for exactly what was claimed, what was lost, and what this file now contains.*

# ROUND 7 — POPSLoader audit, Tarball section (BDMAssault)

Scope: `SourceCode-BDMAssault-mx4sio.tar.gz` (1,466,084 B, md5 `09ff4b911ba131468a25d0ec9a4e2f27`) extracted at `/tmp/bdma7/BDMAssault-mx4sio/` — first-party glue only. Vendored ChaN FatFs R0.14b bodies (`ff.c`, `ffunicode.c`, `ffsystem.c`) inventoried/classified only. Locations are cited as `tarball!BDMAssault-mx4sio/<path>:<lines>`. Every defect below exists **identically in both generations** unless stated otherwise: all 21 component↔merged file pairs were diffed (see the pair table at the end); 7 pairs are byte-identical and the other 14 differ only in `#include` paths and IRX-fusion glue (`_start` renaming/chaining, version bump, banner string). Consequently each Fix must be applied twice (once per generation) or — the LESS-NOT-MORE reading — the component generation should be treated as the single source and the merged generation regenerated from it. No PS2 build or hardware verification was possible or is claimed; all claims are source-level, marked READ (seen in the code as cited) or INFERRED (consequence derived from the cited code plus stated premises).

Context that raises the value of these findings (READ, from the clone, outside the tarball): the merged generation is the shipped product — `iop/embed/BDMASSAULT_MX4SIO/README.MD` in POPSLoader instructs that `bdm_assault.irx` is deployed as POPStarter's `usbd.irx` and `usbd_bd_assault.irx` as `usbhdfsd.irx`.

---

## POPSLOADER-071 — CSW validation is defeated by pre-filling the receive buffer with the expected signature, tag and success status

- **Category:** 2 (correctness/safety), 1
- **Locations:** `tarball!BDMAssault-mx4sio/usbmass_bd/src/usb_mass.c:253-286` (`usb_bulk_status`), `tarball!BDMAssault-mx4sio/usbmass_bd/src/usb_mass.c:296-317` (`usb_bulk_manage_status`); merged twin `tarball!BDMAssault-mx4sio/__usbd_bd_assault/src/usbmass_bd/usbmass_bd_usb_mass.c` at the same lines (READ, diff = include paths only).
- **Problem:** READ. Before issuing the 13-byte CSW bulk-IN transfer, `usb_bulk_status` writes `csw->signature = CSW_TAG`, `csw->tag = tag`, `csw->dataResidue = 0`, `csw->status = 0` into the very struct the device is about to fill. `usb_bulk_manage_status` then validates the reply with `csw.signature != CSW_TAG || csw.tag != tag || csw.status == 2` and returns `csw.status` as the command result. A device (or a stalled/short transfer that still completes with `USB_RC_OK`) that returns zero or only a few bytes therefore passes signature and tag validation on the strength of the driver's own pre-written values, and its pre-written `status = 0` is reported as *command succeeded*. The one check that could catch a short reply — `cb_data.returnSize != 13` — exists only inside `#ifdef DEBUG` (lines 276-282). INFERRED consequence: a failed SCSI WRITE can be reported up the stack as successful, i.e. silent data loss presented as a completed write, with a merely misbehaving (not even malicious) device.
- **Fix (in words):** Initialise the CSW struct to invalid sentinel values (signature/tag to something the device cannot be mistaken for, status to a failure value such as 1), and promote the `returnSize != 13` check out of `#ifdef DEBUG` so a short CSW is treated as an error and enters the existing reset-recovery path.
- **Benefit:** Removes a false-success path on the write path of every USB disk served by the shipped `usbhdfsd.irx` replacement.
- **Effort:** S · **Risk:** Low (stricter validation only; conforming devices return a full, valid CSW) · **Confidence:** High (READ; exploit precondition — short-but-OK transfer — is INFERRED but the validation defeat itself is unconditional).

## POPSLOADER-072 — Device-supplied SCSI block length is accepted unvalidated and divided by in the next statement

- **Category:** 2
- **Locations:** `tarball!BDMAssault-mx4sio/usbmass_bd/src/scsi.c:168-176`; merged twin `tarball!BDMAssault-mx4sio/__usbd_bd_assault/src/usbmass_bd/usbmass_bd_scsi.c:168-176` (READ, include-path diff only). Related acceptance point: `tarball!BDMAssault-mx4sio/usbmass_bd/src/scsi.c:118` (byte count `bd->sectorSize * sectorCount` handed to the transport).
- **Problem:** READ. `scsi_warmup` copies READ CAPACITY's `block_length` verbatim into `bd->sectorSize` and immediately evaluates `bd->sectorCount / ((1000 * 1000) / bd->sectorSize)` and `bd->sectorCount / ((1024 * 1024) / bd->sectorSize)` in the banner printf. A device reporting `block_length == 0` causes a division by zero in the inner term; a device reporting `block_length > 1000000` makes the inner term 0 and causes a division by zero in the outer term. No check for zero, power-of-two, or the 512-byte geometry the rest of the stack is built for (see POPSLOADER-073) exists anywhere between the device reply and these uses.
- **Fix (in words):** In `scsi_warmup`, reject the device (return -1 before `bdm_connect_bd` can see it — see POPSLOADER-076) unless `block_length` is a sane sector size; given POPSLOADER-073, the honest check for this stack is `== 512`.
- **Benefit:** One malformed or unusual USB device can no longer trap the IOP driver during enumeration.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ arithmetic; triggering device behaviour is ordinary device-supplied data, no racing required).

## POPSLOADER-073 — Three layers hard-assume 512-byte sectors while nothing enforces a 512-byte device

- **Category:** 2
- **Locations:** `tarball!BDMAssault-mx4sio/libbdm/src/bd_cache.c:8-17,85-86,116-122` (block geometry `8 * 512`, `count * 512` memcpy, 8-sector fill into a 4096-byte slot); `tarball!BDMAssault-mx4sio/bdm/src/part_driver_gpt.c:36,44` (scratch allocation is the constant `512 * 2`, entry area at `buffer + 512`); `tarball!BDMAssault-mx4sio/bdm/src/part_driver_mbr.c:180` (allocation is `sizeof(master_boot_record)` = 512 bytes); configuration evidence `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/include/ffconf.h:196-197` (`FF_MIN_SS`/`FF_MAX_SS` both 512). Merged twins at identical lines in `__bdm_assault/src/bdm/bdm_part_driver_gpt.c`, `__bdm_assault/src/bdm/bdm_part_driver_mbr.c`, `__bdm_assault/src/bdmfs/include/ffconf.h` (READ via full diff). `libbdm` has no merged copy; it is linked into the merged IRX via `__bdm_assault/Makefile:7` (`../libbdm/lib/libbdm.a`).
- **Problem:** READ. The FatFs configuration only supports 512-byte sectors, the block cache's slot size and all its byte arithmetic are the literal 512, and both partition parsers allocate exactly one (GPT: two) 512-byte units — yet the only place a sector size enters the system, `scsi_warmup` (POPSLOADER-072), passes the device's value through unchecked, and `bd->read(bd, …, 1)` semantics are "one sector of `bd->sectorSize` bytes". INFERRED consequence for a 4096-byte-block device (advanced-format USB enclosures exist): the cache fill writes 8 × 4096 bytes into a 4096-byte cache slot (heap corruption inside the 128 KiB cache struct), the GPT header read writes 4096 bytes into a 512-byte allocation, and the MBR read does the same into 512 bytes — before FatFs ever gets a chance to reject the geometry.
- **Fix (in words):** Enforce the assumption at the single entry point (the POPSLOADER-072 check: refuse non-512 `block_length` in `scsi_warmup`). No buffer needs to grow; the stack is 512-only by configuration already, it merely never says so to the device.
- **Benefit:** Converts latent heap corruption on 4Kn devices into a clean "device not supported" at connect time.
- **Effort:** S (the check) · **Risk:** Low (4Kn devices cannot work through a 512-only FatFs configuration anyway) · **Confidence:** High for the assumption sites (READ); the overflow consequence is INFERRED from the read-semantics contract visible at every `bd->read` call site.

## POPSLOADER-074 — GPT parser trusts the on-disk header: entry size ignored, inverted entries underflow the partition size, header bounds never checked against the device

- **Category:** 2, 1
- **Locations:** `tarball!BDMAssault-mx4sio/bdm/src/part_driver_gpt.c:65-69,73-80,104-105,142-143`; field definitions `tarball!BDMAssault-mx4sio/bdm/src/include/gpt_types.h:420-422,431-439`; merged twin `tarball!BDMAssault-mx4sio/__bdm_assault/src/bdm/bdm_part_driver_gpt.c` at identical lines (READ via diff).
- **Problem:** READ, four linked defects in `part_connect_gpt`. (a) The header's `partition_entry_size` field is never read; entry stride is assumed to be `sizeof(gpt_partition_table_entry)` (128) and entries-per-sector is computed as `bd->sectorSize / sizeof(...)` — a disk formatted with a different (spec-legal) entry size is parsed at the wrong stride, and a device with `sectorSize < 128` (including the 0 case admitted by POPSLOADER-072) makes `entriesPerSector` 0 and the loop's `i % entriesPerSector` a division by zero. (b) The only entry sanity check is `first_lba < header.first_lba || last_lba > header.last_lba`; an entry with `first_lba > last_lba` inside a wide header range passes, and `sectorCount = last_lba - first_lba` then underflows to a near-2⁶⁴ pseudo-device. (c) The header's own `first_lba`/`last_lba` are never checked against `bd->sectorCount`, so the check in (b) validates entries against attacker-chosen bounds. (d) `partition_table_lba` is used as a read address with no range check (a bad value is caught only by the underlying read failing). The file's own TODO at line 65-66 already notes header revision/size and CRCs are unchecked.
- **Fix (in words):** Validate before the loop: `partition_entry_size == sizeof(gpt_partition_table_entry)`, `entriesPerSector > 0`, header `last_lba < bd->sectorCount`; per entry require `first_lba <= last_lba`. Four comparisons, no new code paths.
- **Benefit:** A crafted GPT (a downloaded disk image is enough) can no longer mint a wrap-around partition device or trap the parser.
- **Effort:** S · **Risk:** Low · **Confidence:** High (all READ; the underflow is plain unsigned arithmetic on cited lines).

## POPSLOADER-075 — `get_frag_list` follows the on-disk FAT chain with no cycle bound, and two sibling ioctl cases dereference a possibly-NULL block device

- **Category:** 2, 5
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/fs_driver.c:624-653` (`get_frag_list`), `:681-692` (`USBMASS_IOCTL_GET_LBA`), `:695-702` (`USBMASS_IOCTL_GET_DRIVERNAME`); the correct pattern in the same switch at `:710-727` (`USBMASS_IOCTL_GET_DEVICE_NUMBER` checks `bd == NULL`); merged twin `tarball!BDMAssault-mx4sio/__bdm_assault/src/bdmfs/bdmfs_fs_driver.c` at identical lines (READ via diff).
- **Problem:** READ. `get_frag_list` walks the FAT with `do { iClusterNext = get_fat(...); … } while (iClusterCurrent < fs->n_fatent);`. A cyclic chain that stays inside the valid cluster range (e.g. a cluster whose FAT entry points at itself, or a two-cluster loop) never reaches `>= n_fatent` and never terminates: the fragment counter keeps incrementing (writes are guarded by `iMaxFragments`, the loop is not), so a crafted FAT on a mounted volume hangs the IOP filesystem thread for as long as the file is queried via `USBMASS_IOCTL_GET_FRAGLIST`/`CHECK_CHAIN` — the exact ioctls game loaders use to decide whether a game image is fragmented. Separately, `get_frag_list` uses `bd->sectorOffset` (line 642) and the `GET_LBA` case uses `bd->sectorOffset` (line 692) with no NULL check on `fatfs_fs_driver_get_mounted_bd_from_index(...)`, and `GET_DRIVERNAME` evaluates the NULL case correctly for its return value (line 697) but then still executes `strncpy(rdata, mounted_bd->name, rdatalen)` whenever `rdata != NULL` (lines 700-701). The `GET_DEVICE_NUMBER` case twenty lines below shows the intended pattern.
- **Fix (in words):** Bound the chain walk (e.g. stop after `n_fatent` steps or when the step count exceeds the file's cluster count) and return an error on cycle; add the same `bd == NULL → -ENXIO` guard the neighbouring case already has to `get_frag_list`, `GET_LBA`, and the `GET_DRIVERNAME` copy.
- **Benefit:** Removes an IOP hang and two NULL dereferences reachable from on-disk data plus an ordinary EE ioctl.
- **Effort:** S · **Risk:** Low · **Confidence:** High (loop condition and missing guards are READ; that a self-referential FAT entry is representable on disk is a property of the FAT format).

## POPSLOADER-076 — `scsi_connect` discards `scsi_warmup`'s result and connects the device with zero or stale geometry

- **Category:** 1, 2
- **Locations:** `tarball!BDMAssault-mx4sio/usbmass_bd/src/scsi.c:267-284` (call at line 279, connect at line 280); the failure returns it ignores at `tarball!BDMAssault-mx4sio/usbmass_bd/src/scsi.c:138-141,160-163,168-171`; merged twin `tarball!BDMAssault-mx4sio/__usbd_bd_assault/src/usbmass_bd/usbmass_bd_scsi.c` at identical lines (READ via diff — substitutions only).
- **Problem:** READ. `scsi_connect` sets `bd->priv`/`bd->name`, calls `scsi_warmup(bd)` at line 279 as a bare statement, and calls `bdm_connect_bd(bd)` at line 280 unconditionally. `scsi_warmup` returns -1 on three failure paths — INQUIRY failure (:137-141), START/STOP UNIT failure (:158-163), READ CAPACITY failure (:167-171) — and on every one it returns *before* the only assignments of `bd->sectorSize`/`bd->sectorCount` (:173-175). `g_scsi_bd` is a static array (`scsi.c:56`), so a first-time failure publishes a block device with `sectorSize == 0` and `sectorCount == 0`; and because `scsi_disconnect` clears only `bd->priv`, a slot reused after a previous device publishes that device's *stale* geometry instead. The zero case is not benign downstream: `part_connect_gpt` computes `entriesPerSector = bd->sectorSize / sizeof(gpt_partition_table_entry)` = 0 and then evaluates `i % entriesPerSector` (`part_driver_gpt.c:69,73`) — a division by zero on the BDM mount thread, reachable by nothing more exotic than a device that fails INQUIRY; `bd_cache_create` likewise copies the zero geometry into the cached device FatFs then sees. INFERRED: with stale geometry, mounts proceed against the wrong disk size and every transfer is translated with the previous disk's sector size.
- **Fix (in words):** Honour the return value: call `bdm_connect_bd(bd)` only when `scsi_warmup(bd)` returns 0; on failure clear `bd->priv` (the free-slot test `scsi_connect`'s own loop uses) so the slot stays reusable. This is also the change that makes POPSLOADER-072's warmup-side rejection effective — today even a correct warmup rejection cannot stop the connect.
- **Benefit:** A device that fails enumeration is no longer published to BDM/FatFs with zero or another disk's geometry; closes the easiest reachable path into the GPT parser's division by zero.
- **Effort:** S · **Risk:** Low (a device that cannot complete warmup could never have worked through the stack) · **Confidence:** High (the discarded return and the zero-geometry publication are READ; the GPT division by zero is READ arithmetic on the cited lines; stale-geometry runtime effects are INFERRED).

---

### Section completion note (round 7 repair)

The original round-7 tarball pass claimed 26 findings (internal IDs R7-T01…T26 → POPSLOADER-071…096) plus a 21-pair diff table and 13 dissolved candidates. Only T01…T06 were ever written into this file (as POPSLOADER-071…076), and -076's body was truncated mid-sentence; the remaining claimed content existed nowhere in the workspace or agent records (verified by exhaustive search before this pass). This repair pass therefore: (1) re-derived and completed POPSLOADER-076 from the tarball source, keeping its number and title; (2) re-audited the tarball remainder end-to-end and filed what the evidence supports as POPSLOADER-077…107 below — 31 findings, not the claimed 20, because the count follows the evidence, not the claim; (3) re-verified the cross-generation premise mechanically: all 21 component↔merged `.c` pairs were diffed in this pass and differ by 0–22 diff lines, every one a substitution ( `#include` paths, banner/version strings, `_start` renaming/chaining) — no defect-relevant local delta exists in any merged file, so every finding below cites component lines and applies identically to the merged twin named in its Locations. The original pass's pair table and its 13 dissolved candidates were inside the truncated block and are unrecoverable; the candidates examined and *not* filed in this pass are listed after POPSLOADER-107 instead. **Final tarball-section total: 37 findings, POPSLOADER-071…107.**

## POPSLOADER-077 — DevCtl STOP_UNIT stops every device and STOP_ALL stops only one: the two command bodies are swapped

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/fs_driver.c:781-790` (`fs_devctl`); merged twin `tarball!BDMAssault-mx4sio/__bdm_assault/src/bdmfs/bdmfs_fs_driver.c` at identical lines (READ via diff).
- **Problem:** READ. `case USBMASS_DEVCTL_STOP_UNIT:` calls `fatfs_fs_driver_stop_all_bd()` — unmount and `->stop()` *every* mounted BDM device; `case USBMASS_DEVCTL_STOP_ALL:` calls `fatfs_fs_driver_stop_single_bd(fd->unit)` — only the caller's unit. Names and bodies are exactly inverted.
- **Fix (in words):** Swap the two call targets so each command does what its name says.
- **Benefit:** An EE app stopping one unit no longer ejects every mounted volume, and a global stop no longer leaves the other units mounted and spinning.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — the inversion is literal in the cited lines).

## POPSLOADER-078 — USBD IsoTD halted-flush clears the wrong LUT slot, leaving a stale request pointer in the completed-TD's slot

- **Category:** 2 (correctness/safety)
- **Locations:** `tarball!BDMAssault-mx4sio/usbd/src/usbd.c:133-141` (flush loop; bad clear at :139), contrasted with the correct generic-TD path at `usbd.c:220-226` and the correct first-pass clear at `usbd.c:105-109`; merged twin `tarball!BDMAssault-mx4sio/__usbd_bd_assault/src/usbd/usbd_usbd.c` at identical lines (READ via diff — substitutions only).
- **Problem:** READ. In `processDoneQueue_IsoTd()`'s halted-ED flush loop, each remaining TD `curTd` is freed and its request looked up via `hcIsoTdToIoReqLUT[curTd - hcIsoTdBuf]` — but the slot cleared is `hcIsoTdToIoReqLUT[arg - hcIsoTdBuf]`, i.e. the slot of the *already-completed* TD `arg`, whose slot was already cleared at :109. `curTd`'s LUT entry is left pointing at a request that is then completed and returned to the IoRequest pool. A later LUT scan (e.g. `killEndpoint`, `hub.c:234-240`, or a later done-queue pass) can re-match that stale entry against the reused request slot — a spurious abort/free of an unrelated in-flight isochronous request.
- **Fix (in words):** Clear the `curTd`-indexed slot in the flush loop, exactly as the generic-TD path at :224 already does.
- **Benefit:** Removes a stale-pointer re-match in the USB host stack's completion path.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — both the wrong index and the correct twin pattern are cited).

## POPSLOADER-079 — Failed hub connect leaves a freed `UsbHub` reachable from the device, and unplug then double-frees it

- **Category:** 2 (correctness/safety)
- **Locations:** `tarball!BDMAssault-mx4sio/usbd/src/hub.c:698-709` (`hubDrvConnect`); callers that keep the driver bound regardless of the result at `tarball!BDMAssault-mx4sio/usbd/src/driver.c:62-65` (`probeDeviceTree`) and `driver.c:173-177` (`connectNewDevice`); second free via `hub.c:733` (`hubDrvDisconnect`); merged twins in `__usbd_bd_assault/src/usbd/` at identical lines (READ via diff).
- **Problem:** READ. `hubDrvConnect` stores the buffer first (`dev->privDataField = hubDevice`, :702) and, when `doOpenEndpoint()` fails, frees it (`freeHubBuffer(hubDevice)`, :707) *without clearing `privDataField`*, returning -9. Both callers ignore the connect result and leave the driver bound to the device. On unplug, `hubDrvDisconnect` calls `freeHubBuffer()` on the dangling pointer a second time; unlike `freeTd`/`freeIsoTd`/`freeIoRequest` (`mem.c`), `freeHubBuffer` has no free-list double-push scan, so the same `UsbHub` block (with its embedded control/status IoRequests and endpoints) lands on `hubBufferList` twice and can be handed to two hubs concurrently.
- **Fix (in words):** Set `dev->privDataField = NULL` before freeing on the connect-failure path (or free only after clearing the field).
- **Benefit:** Removes a double-free / double-allocation of hub state reachable from one failed endpoint open during hub enumeration.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — store, free, missing clear, and both result-ignoring callers are cited).

## POPSLOADER-080 — Partition read/write translate the sector by the partition offset but never clamp to the partition's own length

- **Category:** 2 (correctness/safety)
- **Locations:** `tarball!BDMAssault-mx4sio/bdm/src/part_driver.c:52-65` (`part_read`, forward at :64) and `:67-80` (`part_write`, forward at :79); the `sectorCount` they ignore is set at `part_driver_gpt.c:148` / `part_driver_mbr.c:89`; merged twin `tarball!BDMAssault-mx4sio/__bdm_assault/src/bdm/bdm_part_driver.c` at identical lines (READ via diff).
- **Problem:** READ. `part_read`/`part_write` check only that `part`/`part->bd` are non-NULL, then forward `sector + bd->sectorOffset` with the caller's `count` to the raw device. Nothing compares `sector + count` against the partition device's own `sectorCount`. The layer above is FatFs driven by on-disk BPB geometry, and `bd_defrag_read/write` (`libbdm/src/bd_defrag.c`) forwards fragment-derived ranges the same way — so a crafted filesystem image (or any upper-layer over-read) crosses silently into the neighbouring partition or the raw disk beyond it, for writes as well as reads. The partition pseudo-device is the one layer whose entire job is this boundary, and it does not enforce it.
- **Fix (in words):** In `part_read`/`part_write`, reject (or clip, matching the stack's existing return conventions) any request with `sector + count > bd->sectorCount`.
- **Benefit:** Restores the partition isolation boundary for both reads and writes on every MBR/GPT volume the stack mounts.
- **Effort:** S · **Risk:** Low (in-range requests are unaffected) · **Confidence:** High (READ — the absence of the check and the unchecked forward are cited; that upper layers can present out-of-range requests follows from the on-disk-geometry data flow already established in POPSLOADER-074/-075).

## POPSLOADER-081 — Block cache marks a block valid after a device read whose result it never checks

- **Category:** 2 (correctness/safety)
- **Locations:** `tarball!BDMAssault-mx4sio/libbdm/src/bd_cache.c:116-122` (fill at :116, validity assignment at :117). `libbdm` has no merged copy; it is linked into the merged IRX via `__bdm_assault/Makefile:7`.
- **Problem:** READ. On a cache miss, `_read` issues `c->bd->read(c->bd, sector, c->cache[blkidx_best], SECTORS_PER_BLOCK)` and discards the return value; the next statement sets `c->sector[blkidx_best] = sector`, marking the block as valid contents, and the caller's data is then memcpy'd out of the slot and returned as a successful read of `count` sectors. If the device read failed or was short (media error, disconnect mid-transfer, or a fill that runs past the end of the device — the fill always requests a full 8 sectors at the *requested* sector, including within 7 sectors of the device end), the slot serves whatever stale bytes a previous evicted block left there, labelled as this sector's data, for the life of the cache entry.
- **Fix (in words):** Check the fill's return; on failure leave the slot invalidated (`sector = 0xffffffffffffffff`, the file's own invalid marker) and return the error to the caller.
- **Benefit:** A failed device read can no longer be silently converted into wrong data presented as a successful read on every cached volume.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — discarded return and unconditional validity assignment are cited).

## POPSLOADER-082 — `fs_open` honours O_CREAT/O_TRUNC without write access: a read-only open can create or truncate a file to zero

- **Category:** 2 (correctness/safety)
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/fs_driver.c:305-315` (mode translation; `f_open` call at :316); merged twin `bdmfs_fs_driver.c` at identical lines (READ via diff).
- **Problem:** READ. The mode translation ORs `FA_OPEN_ALWAYS` from `O_CREAT` and `FA_CREATE_ALWAYS` from `O_TRUNC` unconditionally — including when the open carries no write flag (`O_RDONLY|O_CREAT`, `O_RDONLY|O_TRUNC`). In FatFs, `FA_CREATE_ALWAYS` truncates an existing file at open regardless of `FA_WRITE`. INFERRED only as to which EE callers pass those flag combinations; the driver-side behaviour is unconditional: an open that should be side-effect-free can create, or zero, the target file.
- **Fix (in words):** Gate the `FA_OPEN_ALWAYS`/`FA_CREATE_ALWAYS` translation on the open actually requesting write access.
- **Benefit:** Removes a data-loss path from read-only opens.
- **Effort:** S · **Risk:** Low · **Confidence:** High for the driver behaviour (READ); caller flag combinations INFERRED.

## POPSLOADER-083 — Mount-info index check admits `index == count` and negative indices, returning an out-of-bounds `block_device*`

- **Category:** 2 (correctness/safety)
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/fs_driver.c:138-146` (`fatfs_fs_driver_get_mounted_bd_from_index`); the bound it misuses is defined at `fs_driver.c:33-35` (array of `FF_VOLUMES` = 10, `include/ffconf.h:169`); dereferencing consumers include `fs_driver.c:182-185` (`stop_single_bd`) and all of `diskio.c`; merged twin at identical lines (READ via diff).
- **Problem:** READ. The guard is `if (mount_info_index > FATFS_FS_DRIVER_MOUNT_INFO_MAX) return NULL;` — but the macro is the array *count* (10), so index 10 passes and reads `fs_driver_mount_info[10]`, one element past the array; negative indices are not checked at all. Callers pass externally derived indices (`fd->unit` from an EE-supplied path/unit, `diskio.c`'s `pdrv`). INFERRED consequence at index 10 (e.g. a `mass10:` unit): adjacent `.bss` is returned as a `block_device*`; `fs_getstat`'s root check treats garbage-non-NULL as "mounted", and `stop_single_bd` calls `mounted_bd->stop(...)` through it — a wild call on the IOP.
- **Fix (in words):** Change the guard to `mount_info_index < 0 || mount_info_index >= FATFS_FS_DRIVER_MOUNT_INFO_MAX`.
- **Benefit:** One-character-class fix closing an out-of-bounds read whose result is dereferenced and called through.
- **Effort:** S · **Risk:** Low · **Confidence:** High for the check (READ); reachability of unit 10 INFERRED from the caller data flow.

## POPSLOADER-084 — `scsi_warmup`'s TEST UNIT READY loop has no retry bound, and reads an uninitialised sense buffer when REQUEST SENSE fails

- **Category:** 2 (correctness), 5
- **Locations:** `tarball!BDMAssault-mx4sio/usbmass_bd/src/scsi.c:147-165` (loop at :147, sense request at :150, sense use at :155); the file's own bounded-retry convention is `SCSI_MAX_RETRIES` (`scsi.c:13`, used at :192, :223); merged twin `usbmass_bd_scsi.c` at identical lines (READ via diff).
- **Problem:** READ. `while ((stat = scsi_cmd_test_unit_ready(bd)) != 0)` loops forever: no counter, no timeout, no escape except the one sense combination (key 0x02 / code 0x04 / qual 0x02) that issues START UNIT and loops again. A device that stays not-ready — an empty card reader, a drive erroring persistently — hangs the connect path (the `usb_mass_update` thread) permanently; every later device event queues behind it. Inside the loop, when `scsi_cmd_request_sense` itself fails, the code only prints and falls through to evaluate `sd.error_code`/`sd.sense_key` (:155) — `sd` is an uninitialised stack struct on that path, so the start-unit decision is made on garbage.
- **Fix (in words):** Bound the loop with the file's existing `SCSI_MAX_RETRIES` convention and return -1 when it expires (effective once POPSLOADER-076 is fixed); skip the sense evaluation when the sense request failed.
- **Benefit:** A not-ready device degrades to a failed connect instead of a permanent IOP-thread hang; the start-unit decision stops reading uninitialised stack.
- **Effort:** S · **Risk:** Low · **Confidence:** High (the unbounded loop and the missing failure branch are READ; that real devices can stay not-ready indefinitely is a property of the media, not an inference about this code).

## POPSLOADER-085 — `fs_lseek64` converts negative results to ~2⁶⁴ offsets with no clamp and no invalid-`whence` case

- **Category:** 2 (correctness/safety)
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/fs_driver.c:350-377`; merged twin at identical lines (READ via diff).
- **Problem:** READ arithmetic. `FSIZE_t off = offset` converts a negative `s64` offset to a huge unsigned value up front; `SEEK_CUR` (`off += file->fptr`) and `SEEK_END` (`off = objsize + offset`) wrap the same way when the true result is negative, there is no clamp, and there is no `default:` — an invalid `whence` is silently treated as `SEEK_SET`. The value goes to FatFs `f_lseek`: in read mode FatFs clips to file size (wrong position, benign), but in write mode it does not clip and its cluster-following loop stretches the chain toward the huge offset. INFERRED consequence: `lseek(fd, -N, SEEK_END/CUR)` past the start of a writable file attempts to allocate the volume and extend the file instead of failing with `-EINVAL`.
- **Fix (in words):** Compute in signed arithmetic, reject a negative result (and an unknown `whence`) with `-EINVAL` before calling `f_lseek`.
- **Benefit:** Removes a volume-filling metadata-corruption path from an ordinary negative seek.
- **Effort:** S · **Risk:** Low · **Confidence:** High for the arithmetic (READ); write-side damage INFERRED from `f_lseek`'s documented write-mode behaviour in the same tree.

## POPSLOADER-086 — `cancelTimerCallback` unlinks a timer without folding its remaining delta into its successor, so every later timer fires early

- **Category:** 2 (correctness/safety)
- **Locations:** `tarball!BDMAssault-mx4sio/usbd/src/hub.c:169-187` (`cancelTimerCallback`); the delta encoding it breaks is at `hub.c:190-213` (`addTimerCallback` inserts with `pos->delayCount -= delay`) and `usbd.c:267-268` (`handleTimerList` decrements only the head); a cancelling caller at `hub.c:374-375` (`flushPort`); merged twin at identical lines (READ via diff).
- **Problem:** READ. The timer list is delta-encoded: each node's `delayCount` is relative to its predecessor. `cancelTimerCallback` patches `next`/`prev` and clears the node, but never adds the cancelled node's remaining `delayCount` to its successor's — so every timer queued behind a cancelled one fires early by exactly the cancelled timer's remaining delta. INFERRED worst case: the `killEndpoint` quarantine timer (`hub.c:297`, 200 ticks — the delay that lets the OHCI stop referencing an endpoint) fires early after an unrelated cancellation, and endpoint/TD memory returns to the free pools while the host controller may still reference it.
- **Fix (in words):** On unlink, add the cancelled node's `delayCount` to its successor's `delayCount` (when a successor exists).
- **Benefit:** Restores the delta-list invariant; safety delays in the USB stack actually last as long as they were set for.
- **Effort:** S · **Risk:** Low · **Confidence:** High for the invariant break (READ — encoder, decrementer and unlinker all cited); the quarantine consequence INFERRED.

## POPSLOADER-087 — A failed `f_close` leaks the FIL/DIR pool slot forever: `fs_close` clears the handle unconditionally and FatFs only invalidates on success

- **Category:** 2 (correctness), 4
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/fs_driver.c:331-346` (`fs_close`) and `:492-507` (`fs_dclose`); FatFs success-only invalidation at `bdmfs_fatfs/src/ff.c:4163-4173` (`f_close`) and `ff.c:4608-4615` (`f_closedir`); pool reuse keyed on `obj.fs == NULL` at `fs_driver.c:243-262`; merged twins at identical lines (READ via diff).
- **Problem:** READ. `fs_close` calls `f_close()` and then sets `fd->privdata = NULL` whatever `f_close` returned. But `f_close` only clears `fp->obj.fs` inside its success path, after the `f_sync()` gate — a failed final flush (`FR_DISK_ERR`), or a close after the volume was disconnected (validation fails), leaves `obj.fs` set while the driver has thrown away the only handle that could retry. Pool-slot reuse is keyed solely on `obj.fs == NULL`, so the slot is busy forever. Slots leak monotonically (128 FIL / 16 DIR) until every open returns `-EMFILE` until module reload — triggered by ordinary device removal or one bad flush.
- **Fix (in words):** On close failure, force-invalidate the object (`obj.fs = NULL`, the same terminal state `f_open`'s error paths already leave) before clearing `privdata`, so the slot returns to the pool.
- **Benefit:** Removes a permanent, accumulating resource leak on the driver's most common error path.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — driver lines, FatFs invalidation site, and the reuse key all cited).

## POPSLOADER-088 — READ CAPACITY's `last_lba` is stored as the sector *count*: every device loses its last sector

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/usbmass_bd/src/scsi.c:173-175` (assignment at :175); the struct field is honestly named at `scsi.c:40-44` (`last_lba[4]`); merged twin at identical lines (READ via diff).
- **Problem:** READ. SCSI READ CAPACITY returns the address of the *last* logical block; the block count is `last_lba + 1`. `scsi_warmup` stores `getBI32(&rcd.last_lba)` directly into `bd->sectorCount`. Every consumer downstream — the banner print on the same lines, the GPT header bounds (POPSLOADER-074), FatFs `GET_SECTOR_COUNT` (`diskio.c:132`) — therefore sees a device one sector smaller than it is: the final sector is unreachable, including the GPT backup header that lives exactly at the last LBA.
- **Fix (in words):** Store `getBI32(&rcd.last_lba) + 1` (the field is `u32`-sourced; a device genuinely reporting `0xFFFFFFFF` last-LBA is the 2 TiB boundary this stack already documents it cannot address with 32-bit LBA commands, `scsi.c:113-115`).
- **Benefit:** Device geometry is correct everywhere it is consumed; the last sector (and the GPT backup header) becomes reachable.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — command semantics and the assignment are both in the cited lines).

## POPSLOADER-089 — MBR partition entries are trusted exactly as the GPT ones were: no bounds check against the device

- **Category:** 2 (correctness/safety)
- **Locations:** `tarball!BDMAssault-mx4sio/bdm/src/part_driver_mbr.c:62-92` (entry use at :88-89); merged twin `tarball!BDMAssault-mx4sio/__bdm_assault/src/bdm/bdm_part_driver_mbr.c` at identical lines (READ via diff).
- **Problem:** READ. `part_connect_mbr` checks the boot signature, skips the GPT-protective case, and then creates a pseudo-device from each entry's `first_lba`/`sector_count` with no validation at all: no `first_lba + sector_count <= bd->sectorCount`, no overlap check between the four entries. A crafted MBR (a downloaded disk image is enough) mints partitions that extend past the end of the device or over each other — the MBR sibling of the GPT defect filed as POPSLOADER-074(c), in the file -074 did not cover. (POPSLOADER-080's missing clamp is what would let resulting accesses actually leave the device's real bounds at the raw layer's discretion.)
- **Fix (in words):** Skip any entry whose `first_lba + sector_count` (computed in 64-bit) exceeds `bd->sectorCount`, mirroring the validation POPSLOADER-074 specifies for GPT.
- **Benefit:** Crafted MBRs can no longer mint out-of-device or overlapping partition devices.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — the only checks present are the two cited).

## POPSLOADER-090 — FatFs `FRESULT` codes are returned to iomanX callers as if they were errnos, throughout `fs_driver`

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/fs_driver.c:321, 345, 438, 458, 484, 506, 617, 764` (open/close/remove/mkdir/dopen/dclose/getstat/rename all `return -ret` on an `FRESULT`); merged twin at identical lines (READ via diff).
- **Problem:** READ mapping. `FRESULT` values (1–20) are not errnos: not-found returns `-FR_NO_FILE` (-4) or `-FR_NO_PATH` (-5) where callers test `-ENOENT` (-2); already-exists returns -8, not `-EEXIST`. INFERRED caller impact: EE-side existence checks, create-if-missing fallbacks and error reporting take the wrong branch even though the filesystem operation itself failed "correctly" — in a driver whose neighbouring functions do use real errnos (`-ENXIO`, `-EMFILE` appear in the same file), so the two namespaces are mixed within one ops table.
- **Fix (in words):** Translate `FRESULT` to the corresponding errno at the ops-table boundary (a small fixed mapping, applied where `-ret` is returned today).
- **Benefit:** Every caller-side error branch in every EE app using this driver starts meaning what it tests.
- **Effort:** S (one mapping, ~9 call sites) · **Risk:** Low · **Confidence:** High for the mapping (READ); per-caller impact INFERRED.

## POPSLOADER-091 — `fs_read`/`fs_write`/`fs_dread` map every FatFs error to 0, indistinguishable from EOF / nothing-written / end-of-listing

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/fs_driver.c:386-421` (read/write; collapses at :401, :420) and `:565-576` (`fs_dread`); merged twin at identical lines (READ via diff).
- **Problem:** READ. On any `FR != FR_OK` — disk error, invalid object, removed media — `fs_write` and `fs_read` return 0, and `fs_dread` maps any `f_readdir` error to 0. Zero is simultaneously the legitimate value for EOF, a zero-length write, and end of directory. Callers cannot distinguish media failure from end-of-file: silent truncation on read, silent data loss (or retry-forever loops) on write, premature end-of-listing on directory scans — in the driver game loaders use to verify game images.
- **Fix (in words):** Return a negative errno (e.g. `-EIO`) when the `FRESULT` is not `FR_OK`, reserving 0 for genuine EOF/empty results.
- **Benefit:** Media failures become visible to callers instead of masquerading as clean end-of-data.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

## POPSLOADER-092 — Filename prefixing for non-zero units uses an unbounded `alloca` on the IOP handler thread's stack

- **Category:** 2 (correctness/safety), 4
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/fs_driver.c:40-65` (the prefixing macro); used at `fs_driver.c:294, 431, 451, 469, 608, 751-752`; merged twin at identical lines (READ via diff).
- **Problem:** READ. For `unit != 0` the macro does `__builtin_alloca(3 + strlen(name) + 1)` and copies the EE-supplied path into it, with no length cap at any of the six call sites. A sufficiently long path from the EE side overflows the IOP handler thread's stack into adjacent IOP memory (IOP stacks are a few KiB; path length is not bounded by anything on this side of the RPC boundary).
- **Fix (in words):** Reject names longer than a fixed bound (the driver's own `FF_MAX_LFN` = 255 plus prefix is the natural cap) before the `alloca`, with `-ENAMETOOLONG`.
- **Benefit:** Removes a stack-overflow vector driven by an ordinary EE-supplied string.
- **Effort:** S · **Risk:** Low · **Confidence:** High for the missing bound (READ); the exact overflow depth INFERRED from IOP stack sizes.

## POPSLOADER-093 — USBD's HCD pool allocation is `memset` unconditionally: `AllocSysMemory` failure is a NULL-pointer crash at module load

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/usbd/src/hcd.c:378-382` (size computation :378, allocation :380, memset :381); merged twin `tarball!BDMAssault-mx4sio/__usbd_bd_assault/src/usbd/usbd_hcd.c` at identical lines (READ via diff).
- **Problem:** READ. `initHcdStructs` computes `memSize` (the whole stack pool: TD/ED/endpoint/device/IoRequest pools plus `maxDevices × maxStaticDescSize` of descriptor storage) and immediately `memset(AllocSysMemory(...), 0, memSize)` with no NULL check. Allocation failure under IOP memory pressure — the single most likely resource failure at load time on a 2 MiB IOP — is a NULL-pointer memset crash inside init instead of a clean init failure the module could report.
- **Fix (in words):** Check the allocation and return the file's existing init-failure result when it is NULL.
- **Benefit:** Load-time OOM degrades to a reportable failure instead of a crash.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

## POPSLOADER-094 — USBD init failure returns are ignored at every layer, so a dead host stack loads as resident success

- **Category:** 2 (correctness), 7
- **Locations:** `tarball!BDMAssault-mx4sio/usbd/src/hcd.c:361` (`initHardware()` called bare; its -1 return defined at `hcd.c:342-344`), `hcd.c:535-538` (`initHubDriver()` called bare; -1 at its allocation failure), `usbd/src/usbd.c:406` (`_start` ignores `hcdInit()`'s return; the failure value defined at `hcd.c:512-516`); merged twins at identical lines (READ via diff).
- **Problem:** READ. Three nested discards: if the OHCI reset never clears, `initHcdStructs` proceeds to program the controller and enable interrupts anyway; if hub-buffer allocation fails, `hcdInit` proceeds anyway; `_start` returns `MODULE_RESIDENT_END` regardless of `hcdInit`. A module whose host controller never left reset, whose interrupt handler was never registered, or whose hub driver was never initialised loads and reports success; every subsequent transfer silently hangs or never enumerates, with no diagnostic at the actual point of failure. (The mass-storage sibling in the same tarball checks its init results properly — `usbmass_bd/src/main.c` — so the convention exists in-tree.)
- **Fix (in words):** Propagate each failure: `initHcdStructs` aborts on `initHardware` failure, `hcdInit` aborts on `initHubDriver` failure, and `_start` returns `MODULE_NO_RESIDENT_END` when `hcdInit` fails.
- **Benefit:** A dead USB stack fails loudly at load instead of masquerading as a working one through every later symptom.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — all three discards and all three failure definitions cited).

## POPSLOADER-095 — `doUnregisterDriver` leaves the driver's `next`/`prev` set, permanently blocking its re-registration

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/usbd/src/driver.c:147-166` (`doUnregisterDriver`); the refusal it triggers at `driver.c:71-76` (`doRegisterDriver`: `if (drv->next || drv->prev) return USB_RC_BUSY;`) and `driver.c:98-101` (`doRegisterAutoLoader`); merged twin at identical lines (READ via diff).
- **Problem:** READ. Unregister unlinks `drv` by patching its neighbours but never sets `drv->next = drv->prev = NULL` before returning success. Any driver that had a neighbour in the list — i.e. any driver except a sole registrant — therefore fails the registration precondition forever after: an LDD that unregisters and re-registers in the same session (an IRX restarted without rebooting USBD) is refused with `USB_RC_BUSY`/`USB_RC_BADDRIVER` even though its unregistration reported success.
- **Fix (in words):** Clear `drv->next` and `drv->prev` at the end of a successful unregister.
- **Benefit:** Driver reload/re-register works after any unregister, not only for sole registrants.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — unlink, missing clear, and both refusal sites cited).

## POPSLOADER-096 — `disk_ioctl`'s GET_SECTOR_COUNT writes 4 bytes into FatFs' 8-byte LBA64 buffer (and GET_SECTOR_SIZE into a WORD buffer)

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/diskio.c:128-138` (writes at :132, :135); the contract: `FF_LBA64 == 1` (`bdmfs_fatfs/src/include/ffconf.h:206`) makes `GET_SECTOR_COUNT`'s buffer an `LBA_t*` (QWORD) and `sectorCount` itself is `u64` (`bdm/include/bdm.h`); merged twin `bdmfs_diskio.c` at identical lines (READ via diff).
- **Problem:** READ contract. `*(unsigned int *)buff = mounted_bd->sectorCount` truncates the u64 count to 32 bits *and* leaves the upper 4 bytes of the caller's 8-byte variable untouched — uninitialised stack in FatFs' own callers (`ff.c` `sz_drv`/`sz_vol`). `GET_SECTOR_SIZE` repeats the pattern with a 4-byte write against the `WORD` buffers FatFs uses. Latent in this build — the only in-tree callers are `f_mkfs`/`f_fdisk`, which the ops table does not expose, and the sector-size call sites compile out at `FF_MAX_SS == FF_MIN_SS` — but any in-IRX caller or config change inherits a garbage drive size. Distinct from the POPSLOADER-073 512-byte family: this is a type-width bug, independent of the sector-size value.
- **Fix (in words):** Write through the contract types: `*(LBA_t *)buff` for GET_SECTOR_COUNT, `*(WORD *)buff` for GET_SECTOR_SIZE.
- **Benefit:** The ioctl honours the FatFs LBA64 contract before a config change or new caller makes it live.
- **Effort:** S · **Risk:** Low · **Confidence:** High for the contract mismatch (READ); impact INFERRED/latent as stated.

## POPSLOADER-097 — FatFs glue `ff_req_grant` fabricates success: it ignores `WaitSema`'s result, can never time out, and `ff_del_syncobj` does the same for deletion

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/ffsystem.c:143-167` (`ff_req_grant`; IOP branch at :165-167), `:128-132` (`ff_del_syncobj`), `:170-196` (`ff_rel_grant`); the contract it violates is documented in its own header comment at `ffsystem.c:139-141`; merged twin `bdmfs_ffsystem.c` at identical lines (READ via diff).
- **Problem:** READ. The IOP branch of `ff_req_grant` is `WaitSema(sobj); return 1;` — the wait result is discarded and success is unconditional, with a plain blocking wait instead of the `FF_FS_TIMEOUT` the header says a 0 return exists to enforce. If the semaphore was deleted (volume unmounted under a waiter) the caller proceeds *without holding the volume lock*; if a holder ever dies, every later FatFs call hangs forever instead of failing with `FR_TIMEOUT`. `ff_del_syncobj` likewise returns 1 whenever `sobj >= 0` without checking `DeleteSema`, and `ff_rel_grant` discards `SignalSema`'s result. (`ff_cre_syncobj` checks its return — the convention exists in the same file.)
- **Fix (in words):** Return `WaitSema(sobj) == 0` (with a timed wait if the kernel API in use offers one), and propagate `DeleteSema`'s result in `ff_del_syncobj`.
- **Benefit:** FatFs volume locking stops claiming to hold a lock it may not hold; lock failures become `FR_TIMEOUT` instead of silent unsynchronised access or a permanent hang.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

## POPSLOADER-098 — The hub status-change chain abandons itself on any transfer error: one transient hub error permanently stops hot-plug detection

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/usbd/src/hub.c:148-167` (`hubGetHubStatusCallback` — no error branch), `:577-578` (`hubGetPortStatusCallback` error branch is a debug print only), `:594-604` (`hubSetPortPower` failure ends the power-up sequence); the only re-arm point is `getHubStatusChange()`, called from inside this same chain; merged twin at identical lines (READ via diff).
- **Problem:** READ structure, INFERRED permanence. The interrupt status endpoint is armed only by `getHubStatusChange()`, whose callers are all inside this callback chain. On `resultCode != USB_RC_OK`, `hubGetHubStatusCallback` does nothing at all — it neither continues the chain nor re-arms; the port-status and port-power callbacks have the same shape (in the power case, remaining ports are never powered at all). One transient error — a STALL/NORESPONSE from a flaky hub during any of these control transfers — therefore stops hot-plug detection for that hub for as long as it stays connected, with the hub otherwise fully functional.
- **Fix (in words):** On error in each of the three callbacks, re-arm via `getHubStatusChange()` (and in `hubSetPortPower`, continue to the next port) instead of ending the chain.
- **Benefit:** A single transient hub error degrades to a missed poll instead of permanently dead hot-plug/power sequencing.
- **Effort:** S · **Risk:** Low · **Confidence:** Medium (INFERRED — the missing error branches are READ; that no other path re-arms rests on the caller census of `getHubStatusChange` in the cited file).

## POPSLOADER-099 — `HubControlTransfer` silently drops a port reset issued while the hub control request is busy, wedging resets system-wide

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/usbd/src/hub.c:91-101` (`HubControlTransfer` busy drop); the state set before the drop at `hub.c:309-331` (`hubResetDevice`: `delayResets = 1`, `DEVICE_RESETPENDING`, `resetFlag = 1`, `hubStatusCounter`, :315-324); merged twin at identical lines (READ via diff).
- **Problem:** READ structure, INFERRED wedge. `HubControlTransfer` returns `void` and, when `controlIoReq.busyFlag` is set, drops the transfer with only a debug print — no queue, no retry, no error to the caller. `hubResetDevice` has already set the reset-pending state and `memPool.delayResets = 1` before issuing its PORT_RESET through this function, and relies on the completion callback to continue. A timer-driven reset colliding with any in-flight hub control transfer (status/port polling shares EP0) is lost with its callback never run: the port stays `DEVICE_RESETPENDING`, and because `delayResets` stays 1, every other device's reset is deferred behind it — enumeration stalls system-wide until the wedged port is physically disconnected.
- **Fix (in words):** Make the busy case retryable: have `HubControlTransfer` report the drop (return value) and let `hubResetDevice` re-issue from its existing delayed-reset path instead of assuming issuance.
- **Benefit:** A lost reset stops being a system-wide enumeration wedge.
- **Effort:** S · **Risk:** Low · **Confidence:** Medium (INFERRED — the drop and the pre-set state are READ; the wedge follows from the cited state machine, not from a runtime trace).

## POPSLOADER-100 — Module-argument integers in USBD accumulate with no overflow or range validation, then size the entire HCD pool layout

- **Category:** 2 (correctness/safety)
- **Locations:** `tarball!BDMAssault-mx4sio/usbd/src/usbd.c:295-333` (`ParseOptionInput`); consumers at `usbd/src/hcd.c:366-381` (pool sizing, `memSize` at :378) and `hcd.c:400-462` (pool layout loops, e.g. the `maxIsoTransfDesc - 1` loop at :458); merged twins at identical lines (READ via diff).
- **Problem:** READ parsing, INFERRED layout consequence. Each option value is built as `value = value*10 + digit` in an unbounded loop with only a one-sided digit test, and written straight into `usbConfig` (`dev=`, `ed=`, `gtd=`, `itd=`, `ioreq=`, `conf=`, `hub=`, `port=`, `thpri=`). Nothing validates the results anywhere. `initHcdStructs` then derives both the allocation size (`memSize = (u32)devDescBuf + maxDevices * maxStaticDescSize`, int multiplication) and every pool offset and loop count from the same fields independently — a long digit string wraps a field small/negative, or two plausible fields' product wraps `memSize`, so the allocation is smaller than the layout the init loops then write through: heap corruption at module load from configuration input alone. Zero counts are a degenerate case (`itd=0`/`gtd=0` still execute the unconditional tail writes into the neighbouring pool).
- **Fix (in words):** Clamp each parsed value to a sane per-field range at parse time and reject the argument on overflow.
- **Benefit:** Module-load configuration stops being a heap-corruption input.
- **Effort:** S · **Risk:** Low · **Confidence:** Medium (INFERRED — parser and sizing arithmetic READ; corruption follows from the two disagreeing derivations of the same fields).

## POPSLOADER-101 — `bd_cache_create` dereferences both `AllocSysMemory` results unchecked

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/libbdm/src/bd_cache.c:155-167` (allocations at :160, :162; first dereference at :166). Component generation only (linked into the merged IRX, `__bdm_assault/Makefile:7`).
- **Problem:** READ. The cache wraps every whole-device connection (`bdm_connect_bd` → `bd_cache_create`, `bdm/src/bdm.c:52`), and the private struct it allocates is the 128 KiB cache itself — the largest single allocation in the stack. Neither `AllocSysMemory` result is checked before `c->bd = bd` writes through `c` (and `cbd` is written through below). On a 2 MiB IOP under memory pressure, a failed allocation is a NULL-pointer write inside device connect instead of a fall back to the uncached device (a fallback `bdm_try_mount` already supports: it uses `cbd` only when non-NULL).
- **Fix (in words):** Return NULL when either allocation fails (freeing the other), letting the existing uncached path serve the device.
- **Benefit:** Device connect under memory pressure degrades to uncached operation instead of crashing.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

## POPSLOADER-102 — Stat timestamps report seconds ≥ 32 as 32 seconds early: the seconds recovery masks instead of multiplying

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/fs_driver.c:548` (`fileInfoToStat`, used by `fs_getstat`/`fs_dread` at :511-553); merged twin at identical lines (READ via diff).
- **Problem:** READ. FAT `ftime` bits 0–4 hold seconds/2 (0–29); correct recovery is `(ftime & 31) * 2` (0–58). The code computes `stime[1] = (ftime << 1) & 31;` — i.e. the correct value mod 32. Every file timestamp with seconds 32–58 is reported 32 seconds early; the adjacent minutes/hours/day/month/year conversions are all correct, and the line's own comment ("multiplied by 2") states the intent the mask defeats.
- **Fix (in words):** Change the expression to `(ftime & 31) * 2` (equivalently `(ftime << 1) & 63`).
- **Benefit:** File timestamps from `stat`/directory reads are right for half of every minute.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ arithmetic).

## POPSLOADER-103 — Unknown `ioctl2` commands return success having done nothing

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/fs_driver.c:729-741` (default arm at :729-731; reached from both `fs_ioctl2` and `fs_ioctl`); the file's own contrary convention at `fs_driver.c:792` (`fs_devctl` default returns `-ENXIO`); merged twin at identical lines (READ via diff).
- **Problem:** READ. `ret` is initialised to 0 and the switch's `default:` just breaks, so any unrecognised ioctl2 command returns 0 = success. A caller that checks the result is told an operation it requested was performed when nothing happened. (The named cases at :624-727 are POPSLOADER-075's territory and are not re-filed here.)
- **Fix (in words):** Return `-ENXIO` from the default arm, matching `fs_devctl` twenty lines below the switch's end.
- **Benefit:** Unsupported operations stop reporting success.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

## POPSLOADER-104 — `disk_ioctl` returns RES_OK for every command it does not implement

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/diskio.c:113-143`; merged twin `bdmfs_diskio.c` at identical lines (READ via diff).
- **Problem:** READ. The switch handles only `CTRL_SYNC`, `GET_SECTOR_COUNT`, `GET_SECTOR_SIZE`, `GET_BLOCK_SIZE`; there is no `default`, and the function returns `RES_OK` unconditionally at the end — so `CTRL_TRIM` and any other FatFs control code is reported performed when nothing happened. The FatFs convention for an unsupported command is `RES_PARERR`.
- **Fix (in words):** Add a `default: return RES_PARERR;` (equivalently track whether a case handled the command).
- **Benefit:** Callers checking ioctl results stop being told unperformed operations succeeded — the diskio-layer sibling of POPSLOADER-103.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ).

## POPSLOADER-105 — `fs_dread`'s name copy can leave the returned dirent unterminated at maximum-length filenames

- **Category:** 2 (correctness)
- **Locations:** `tarball!BDMAssault-mx4sio/bdmfs_fatfs/src/fs_driver.c:571`; merged twin at identical lines (READ via diff).
- **Problem:** INFERRED. `strncpy(buffer->name, fno.fname, 255)` never writes byte 255. With `FF_MAX_LFN == 255`, a maximum-length long filename fills bytes 0–254 exactly, and the destination (iomanX `iox_dirent_t.name[256]`, a header outside the tarball) keeps whatever stale byte the EE-side buffer held at [255] — the returned name is not NUL-terminated. Shorter names are safe (strncpy zero-pads), which is why this survives casual testing.
- **Fix (in words):** Copy with a bound of 255 and explicitly write `buffer->name[255] = '\0'` (or copy `sizeof(buffer->name) - 1` and terminate).
- **Benefit:** Directory listings return terminated names at every legal filename length.
- **Effort:** S · **Risk:** Low · **Confidence:** Medium (INFERRED — the copy bound is READ; the destination size comes from an out-of-tarball header).

## POPSLOADER-106 — MBR parser leaks its 512-byte scratch block on the read-failure path (every other error path frees it)

- **Category:** 4 (memory), 2
- **Locations:** `tarball!BDMAssault-mx4sio/bdm/src/part_driver_mbr.c:37-43` (read at :37, bare return at :42); the freeing paths at :50-51, :58-59, :97 for contrast; merged twin `bdm_part_driver_mbr.c` at identical lines (READ via diff).
- **Problem:** READ. `pMbrBlock` is allocated at :31 and checked for NULL; if `bd->read` then fails, the function returns `rval` without `FreeSysMemory(pMbrBlock)` — the only one of the function's four error exits that does not free. `part_connect_mbr` runs on every whole-device connect attempt (it is BDM's first mount probe), so each failed-read device permanently leaks 512 B of IOP memory for the life of the module.
- **Fix (in words):** Free `pMbrBlock` before the read-failure return, as the signature and protective-MBR paths already do.
- **Benefit:** Removes a per-probe leak on the stack's most frequently executed error path.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — allocation, the one non-freeing exit, and the three freeing exits all cited).

## POPSLOADER-107 — The ASYNC half of `usb_queue_cmd` is dead code that also skips CSW status validation entirely

- **Category:** 1 (dead code), 8
- **Locations:** `tarball!BDMAssault-mx4sio/usbmass_bd/src/usb_mass.c:16` (`// #define ASYNC` — commented out), the `#else` branch of `usb_queue_cmd` and `scsi_cmd_callback` (both under `#ifdef ASYNC` regions of `usb_mass.c`, ~:460-565); merged twin `usbmass_bd_usb_mass.c` at corresponding lines (READ via diff).
- **Problem:** READ. `ASYNC` is never defined in the tree (the only define is commented out at :16), so the entire asynchronous implementation of `usb_queue_cmd` — plus its callback and the `usbmass_cmd` struct usage — is compiled out of every build: ~60 lines of dead code carrying a *second, divergent* implementation of the BOT exchange. The dead code is also worse than the live code: its completion path returns 0 whenever the transfers' USB result is OK and never reads the CSW status at all (the live path runs `usb_bulk_manage_status`), so if anyone ever enables the define, failed SCSI commands report success — the POPSLOADER-071 failure shape, without even the pre-fill subtlety.
- **Fix (in words):** Delete the ASYNC branch, `scsi_cmd_callback`, and the commented-out define (or, if async operation is ever actually wanted, implement it through the same status-validation path as the synchronous code — the deletion is the LESS option and matches the shipped configuration).
- **Benefit:** Removes a divergent dead implementation whose only reachable future is silently reintroducing a fixed bug class.
- **Effort:** S · **Risk:** Low (deletion of code no build compiles) · **Confidence:** High (READ — the commented define and the branch structure are cited; the CSW omission is READ in the dead path's own lines).

---

**Candidates examined in this pass and not filed** (kept brief; none is a dissolved candidate from the original pass, whose list is unrecoverable — see the completion note): USBD `callbackThreadFunc` GP-segment use-after-free read (`driver.c:242-256`) — real in the source but compiled only under `USE_GP_REGISTER`, which no tarball Makefile defines, so it is not reachable in this build; USBD `hubStatusCounter` wedge (`hub.c:120-142`) — INFERRED chain overlapping POPSLOADER-098/-099's hub-wedging theme, not filed separately to avoid double-counting one mechanism family; USBD `sceUsbdChangeThreadPriority` result overwrite (`interface.c:434-444`) — READ but trivial (misreported partial success in a cosmetic setter); `fs_driver` lock-primitive result discards (:90-125), `fs_lseek64` lock-discipline races (:356-377), and duplicate-mount absence in `connect_bd` (:197-215) — INFERRED chains requiring semaphore failure or concurrent EE behaviour not provable from this tree; `bd` callback pointers (`->stop`/`->flush`) dereferenced unchecked at `fs_driver.c:185`/`diskio.c` — both in-tarball providers populate all four, so the NULL case needs an out-of-tarball driver; `usb_mass_connect`'s unchecked descriptor rescans (`usb_mass.c`) — USBD calls connect only for devices its probe already validated; `bd_defrag` clip arithmetic — verified safe (clip value is bounded by the `u16` count it clips); `diskio` GET_BLOCK_SIZE returning 0 — FatFs treats 0 as "unknown" and falls back correctly; GPT mid-table read failure returning -1 after some partitions already connected — a partial-mount inconsistency noted under POPSLOADER-074's header-trust family, not a separate mechanism.
---

## Annex A — Docs-vs-code section (full: claim coverage, MATCH groups, UNVERIFIABLE list, findings 060–065 as filed)

# POPSLoader — Round 7, Section: Docs prose vs code (checkable claims only)

Pin: `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (= live HEAD, READ). `git status` clean before and after.
Scope read in full: `README.md`, `ARCHITECTURE.md`, `COMPONENTS.md`, `OFFICIAL_NOTES.md`,
`RELEASE_1.3.0.md`, `RELEASE_1.3.1.md`, `RELEASE_1.4.0.md`, `RELEASE_1.4.4.md`,
`docs/EMBER_INTEGRATION.md`, `docs/LAUNCH_ARGUMENTS.md`, `docs/UDPFS_BDMA.md`,
`docs/PRESERVATION_CONTRACTS.md`, `docs/wiki/{Device-Support,Ember-Core,Installation-Guide,Project-Wiki,Release-Formats}.md`,
`docs/translations/README.md`, and the top of `STATE.md` / `ROADMAP.md` (present-tense facts only).
Dated audit/handoff reports (`docs/AUDIT_CODEX_2026-06-20.md`, `docs/REPO_AUDIT_2026-07-07.md`,
`docs/HANDOFF_EXP33_2026-07-21.md`) and `docs/archive/**` were inventoried and skipped as dated/historical
snapshots, per the brief. Nothing below repeats POPSLOADER-001…059; the release-workflow `1.4.4`
hard-coding is X-45 and is not re-filed (the doc-side version claims checked against code are in scope and are below).

**Totals: 100 claims checked — 78 MATCH, 10 UNVERIFIABLE, 12 contradicted (in 6 findings, POPSLOADER-060…065).**

---

## Findings (contradictions only)

## POPSLOADER-060 / i.Link is documented as a stub / not implemented / Ember-only in three docs; the code implements the page for Ember *and* POPSTARTER

- **Category:** Docs vs code (behaviour / format support)
- **Locations:** Doc — `ARCHITECTURE.md:253` ("| 6 | i.Link | **stub** (`ui.lua:4318`) |"); `COMPONENTS.md:474` ("`i.Link` (OPT6): NOT implemented (ui.lua:4462)"); `README.md:263` ("It lists and launches **Ember** games only … POPSTARTER titles over i.Link are not implemented"), with the same Ember-only claim at `README.md:84` and `README.md:139`. Code — `bin/POPSLDR/ui.lua:6425` (`UI.MainMenu.OPT == 6` handler: loads drivers via `PLDR.InitILINKRoot()`, scans `ilink_root.."POPS/"` for POPSTARTER VCDs, changes to `UI.SCENES.GILINK`); `bin/POPSLDR/ui.lua:1067` (`GILINK = 11`); `bin/POPSLDR/system.lua:9166` (`PLDR.InitILINKRoot`); `bin/POPSLDR/system.lua:10702` (`BuildLaunchPolicy("ILINK", "mass", "ilink0", TranslateIlinkPathForPopStarter)` — the POPSTARTER launch policy for the page); `bin/POPSLDR/system.lua:5161` (staged `.ilink` BDMA pair).
- **Problem:** READ. A user reading the README's Known-Issues/planned section or either technical doc concludes i.Link does not exist or cannot launch POPSTARTER titles, and never enables it. The code at the pin has a complete page (Ember scan + POPSTARTER VCD scan/launch via the staged `.ilink` pair, hidden by default, hardware-untested) — which is exactly what the *other* parts of the same README (`README.md:66`), `STATE.md:1`, and `bin/changelog` [1.4.2] already say. The stub/not-implemented wording is pre-1.4.2 prose that survived the feature landing.
- **Fix in words:** In all three docs, replace stub / NOT implemented / Ember-only with the shipped description already used at `README.md:66`: experimental, hidden by default, hardware-untested, lists and launches Ember games and POPSTARTER titles via RiptOPL's i.LINK BDMA pair (unproven).
- **Benefit:** Removes the one place the user-facing docs deny a shipped (if experimental) feature; aligns README, ARCHITECTURE and COMPONENTS with STATE/changelog.
- **Effort:** S
- **Risk:** Low
- **Confidence:** High — READ both sides; the OPT==6 handler and the ILINK launch policy are live code, not dead branches (handler is in the MainMenu CONFIRM dispatch).

## POPSLOADER-061 / ARCHITECTURE says Adaptive BDMA defaults off; the code defaults it on

- **Category:** Docs vs code (default value)
- **Locations:** Doc — `ARCHITECTURE.md:640` ("`BDMA_ADAPTIVE` (per-launch BDMA variant staging, default off; see STATE.md)"). Code — `bin/POPSLDR/system.lua:6236` (`PLDR.BDMA_ADAPTIVE = true  -- per-launch BDMA variant staging (issue #509)`, in `LoadSettingsNonFatal`'s defaults, with the 2026-07-28 maintainer rationale comment directly above it).
- **Problem:** READ. This is a user-acting default: with Adaptive on, every launch stages a BDMA variant to the memory card unless the user opts out. A reader of ARCHITECTURE (or anyone debugging "why did my card's drivers change?") is told the opposite of the shipped behaviour. README (`README.md`, Adaptive BDMA bullet: "Default **On**") and STATE (T48) both have it right; ARCHITECTURE is the outlier.
- **Fix in words:** Change "default off" to "default on (since 2026-07-28)" in the `.pldrs` key list at `ARCHITECTURE.md:640`.
- **Benefit:** One-word correction of a wrong default in the architecture reference.
- **Effort:** S
- **Risk:** Low
- **Confidence:** High — READ both sides.

## POPSLOADER-062 / STATE's top-of-file translation note says Slovak is not in the picker and its wording still awaits the contributor; Slovak shipped in 1.4.3/1.4.4

- **Category:** Docs vs code (behaviour / shipped feature, present-tense at top of canonical doc)
- **Locations:** Doc — `STATE.md:5-7` ("Translation follow-up (2026-10-27): … Slovak wording awaits the contributor; `SK` is not yet in the picker."). Code — `bin/POPSLDR/system.lua:2559` (`PLDR.LANGUAGE_ORDER = {"EN", "FR", "DE", "PT", "ES", "IT", "HU", "SK"}`); `bin/POPSLDR/system.lua:2560` (`SK = "Slovenčina"` in `PLDR.LANGUAGE_NAMES`); `bin/POPSLDR/system.lua:4431-4432` (the `SK = {…}` dictionary). Corroborated in-repo by `docs/translations/README.md` ("it now ships as `PLDR.I18N.SK` and appears in the language picker as **Slovenčina**") and `bin/changelog` [1.4.3]/[1.4.4].
- **Problem:** READ. The note sits directly under STATE's 2026-11-12 "Official release: 1.4.4" header with no superseded marking, in the file every other doc names as canonical. A user or contributor reading it concludes Slovak is unavailable and the handoff is still pending, two releases after it shipped (and after SVKghost's corrections shipped in 1.4.4).
- **Fix in words:** Delete the follow-up note or replace it with a dated shipped note (Slovak added in 1.4.3, corrections in 1.4.4, in the picker as Slovenčina).
- **Benefit:** Canonical doc stops contradicting the shipped language list at its most-read position.
- **Effort:** S
- **Risk:** Low
- **Confidence:** High — READ both sides. (The note was true on its 2026-10-27 date; it is the un-marked present-tense placement at the top of the 1.4.4-era STATE that makes it a contradiction, not the original entry.)

## POPSLOADER-063 / Three technical docs still carry the 1.1.0 / v1.1.1-dev release identity; the code reports 1.4.4

- **Category:** Docs vs code (version numbers)
- **Locations:** Doc — `ARCHITECTURE.md:1` ("Release 1.1.0; rolling `v1.1.1-dev` / experimental `v1.1.1-dev-EXP73`"); `COMPONENTS.md:1` (same stamp); `docs/PRESERVATION_CONTRACTS.md:3` ("Public release is **1.1.0** (2026-07-21); rolling is `1.1.1-dev`, experimental `1.1.1-dev-EXP73`"). Code — `etc/boot.lua:1` (`POPSLDR_VER = "v1.4.4"`); `bin/POPSLDR/title.cfg:7` (`Version=1.4.4`); `STATE.md:1` ("Official release: 1.4.4").
- **Problem:** READ. Anyone identifying the current release from ARCHITECTURE, COMPONENTS or the preservation-contracts header is three minor versions low. Mitigation, stated for fairness: ARCHITECTURE/COMPONENTS line 1 and PRESERVATION_CONTRACTS line 3 each defer to STATE.md for current status, so this is stale-header drift, not a competing canonical claim — filed at the lowest priority of this section.
- **Fix in words:** Re-stamp the three headers to 1.4.4 (or drop the release stamp from the headers entirely and let STATE own it, per the repo's own single-source rule).
- **Benefit:** Version identification is correct from any entry doc.
- **Effort:** S
- **Risk:** Low
- **Confidence:** High — READ both sides.

## POPSLOADER-064 / README's Settings table lists Retro GEM Game ID as "On" only; the setting is an On/Off toggle

- **Category:** Docs vs code (default / options)
- **Locations:** Doc — `README.md:149` (Game List settings table, Options column: "**On**" — every neighbouring row lists its full option set with the default bolded, e.g. Cover art "**On** (default) · Off"). Code — `bin/POPSLDR/ui.lua:5250-5256` (the "Retro GEM Game ID" `AddCycle` row toggles `UI.RetroGemGameId` between On and Off); default on at `bin/POPSLDR/system.lua` (`PLDR.RETROGEM_GAMEID = true` in the settings defaults); also overridable per-boot via `-retrogem=0` (`src/main.cpp:248-254`, documented in `docs/LAUNCH_ARGUMENTS.md`).
- **Problem:** READ. By the table's own convention the row reads as "On is the only value", so a user who wants the optical ID emission off (e.g. it flashes sprites at every launch) is told, in effect, that there is no off switch. There is.
- **Fix in words:** Change the Options cell to "**On** (default) · Off".
- **Benefit:** Users can find the off switch for a launch-visible behaviour.
- **Effort:** S
- **Risk:** Low
- **Confidence:** Medium-High — READ both sides; the only inference is that the Options column is exhaustive, which is the convention of every other row in the same table.

## POPSLOADER-065 / ARCHITECTURE says the cover cache is a 3-entry LRU (`max = 3`); the code sets `max = 4`

- **Category:** Docs vs code (numeric limit, internal)
- **Locations:** Doc — `ARCHITECTURE.md:329` ("`UI.CoverCache` (`ui.lua:257`, `max = 3`) is a 3-entry LRU of loaded box-art images"). Code — `bin/POPSLDR/ui.lua:373` (`max = 4, -- bounded recent cover/icon textures` in `CoverCache`).
- **Problem:** READ. Small internal numeric drift of exactly the kind these two technical docs exist to prevent (both promise path:line-accurate claims). No user-facing effect; included because the brief counts numeric limits as checkable claims and both sides are exact.
- **Fix in words:** Change "max = 3 / 3-entry" to "max = 4 / 4-entry" (and refresh the stale `ui.lua:257` anchor while there).
- **Benefit:** Keeps the architecture doc's numeric claims trustworthy.
- **Effort:** S
- **Risk:** Low
- **Confidence:** High — READ both sides.

---

## MATCH — claims checked and confirmed against code at the pin (78)

Version / packaging (12):
1. [M] Current version is 1.4.4 — `etc/boot.lua:1` `POPSLDR_VER = "v1.4.4"`, `bin/POPSLDR/title.cfg:7` `Version=1.4.4` (README, STATE, ROADMAP, all RELEASE_*/wiki headers).
2. [M] App directory / PSU contains exactly eight files (POPSLOADER.ELF, POPSTARTER.ELF, icon.sys, list.icn, copy.icn, del.icn, title.cfg, APPINFO.PBT) — `tools/package_psu.py:16-17` `FILES = {…}` (8 entries, exact-set enforced in `read_app`).
3. [M] PSU header is `PS1_POPSLOADER` with no nested folder — `tools/package_psu.py:5,15`.
4. [M] PSU writer rejects data that would exceed an 8 MiB card image — `tools/package_psu.py:60-61` (`>= 8 * 1024 * 1024` raises).
5. [M] PSU verified byte-for-byte against `APPS/PS1_POPSLOADER/` in CI — `tools/package_psu.py` `verify()` + `.github/workflows/compilation.yml:217`.
6. [M] Rolling ZIP names end with the build version (`POPSLDR_VER` + commit count, e.g. `v1.4.0-928`) — `.github/workflows/rolling-release.yml` "End every ZIP name with the version" step.
7. [M] `ExampleGame.bin` is zero bytes / non-playable — asserted empty in `.github/workflows/official-release.yml` (ZIP check `not z.read("EMBER/games/ExampleGame/ExampleGame.bin")`).
8. [M] Sony POPS files (`POPS.ELF`, `POPS.PAK`, `POPS_IOX.PAK`, `IOPRP252.IMG`) and BIOS are not included — official-release ZIP check rejects any `/bios.bin`; POPS payload is the pinned support set (README/Installation-Guide).
9. [M] Slovak handoff covered 409 strings — `docs/translations/*.tsv` are 410 lines = header + 409 records.
10. [M] UDPFS driver is Okeanos Assault 1.0.1 since 1.4.2 — `bin/POPSLDR/usbd.irx.udpfs` is 61,949 B, matching `docs/third_party/okeanos_udpfs/PROVENANCE.json` (`size: 61949`) and the UDPFS_BDMA "51,029 B to 61,949 B" growth note for the 1.0.1 module.
11. [M] Build requires the pinned `ps2dev/ps2dev:v2.0.0` image — `.github/workflows/compilation.yml:68`, `.github/workflows/rolling-release.yml:63`.
12. [M] Local build is `make clean elfloader all` producing packed `bin/POPSLOADER.ELF` — `Makefile` `elfloader` target + ARCHITECTURE Layer 7 description.

Defaults & settings (20):
13. [M] Boot Page default Carousel; options Carousel/MX4SIO/USB/MMCE/HDD (PFS)/HDD (exFAT) — `system.lua:6243`, `NormalizeBootPage` (`system.lua:5739`).
14. [M] Internal HDD default Both (`HDD_FS = "BOTH"`) — `system.lua:6251`.
15. [M] Multi-disc default Show all discs; secondary-disc detection is bracketed `(Disc N)`/`(Disk N)`/`(CD N)`, N≥2, by filename — `system.lua:6244` (collapse false), `IsSecondaryDisc` (`system.lua:8626`).
16. [M] Hidden games default Visible (manage) (`GLOBAL_HIDE = false`); L3 writes/removes `<name>.hide` — `system.lua:6245` + hide-layer code.
17. [M] Game details default Off; alignment Left/Center/Right; sidecar is `<device>:/ART/<gamefilename>.txt` — `system.lua:6248`, `DETAILS_ALIGN = "left"`.
18. [M] Cover art default On; exactly one candidate `<device>:/ART/<gamefilename>_COV.png`, HDD `hdd0:__common/POPS/ART/…` — `system.lua:6252`, `BuildCoverCandidates` (ui.lua, EXP71 single candidate).
19. [M] Game list cache default Off — `system.lua:6253`.
20. [M] Video Standard default Auto; PAL renders 640×512, NTSC 640×448 — `system.lua:6239`; `ui.lua:910-912`; `src/luaplayer.cpp:195`.
21. [M] Overscan default Off (0), adjusted in steps of 5, UI clamp 0..100 — `system.lua:6260`; `ui.lua:5072-5077`.
22. [M] Boot sound default On — `system.lua:6259`.
23. [M] Adaptive BDMA default On (README/STATE/LAUNCH_ARGUMENTS) — `system.lua:6236`. (ARCHITECTURE's contrary claim is POPSLOADER-061.)
24. [M] Hide UI Text default On — `system.lua` defaults block (EXP56 default-on boolean, `UI.SetHideTextMode(true, …)`).
25. [M] Keyboard Layout default QWERTY; options QWERTY/DVORAK/ABC/AZERTY/QWERTZ/ABNT — `system.lua:6241` + `NormalizeKeyboardLayout`.
26. [M] i.Link Hidden by default, every other carousel device Shown; at least one device must stay Shown — `system.lua:6247` (`HIDDEN_DEVICES = "ILINK"`); `ui.lua:5128` ("At least one device must stay on the carousel"); `ui.lua:4840-4854` (default-hidden = ILINK only).
27. [M] POPSTARTER Path default Automatic (`""`); resolution order custom → device `<device>:/POPS/POPSTARTER.ELF` (PFS HDD: `hdd0:__common/POPS/POPSTARTER.ELF`) → cwd copy → `mc0:`/`mc1:` net; explicit-but-unresolvable path falls through silently — `PLDR.ResolveLaunchPopstarterPath` (`system.lua:1825ff`, ladder comment + code).
28. [M] Settings persist as a per-device `.pldrs` sidecar, HDD installs on the HDD boot partition with no `mc0:` fallback — `LoadSettingsNonFatal` sidecar resolution + `PLDR.HDD.EnsureBootPartitionWritable` (STATE/COMPONENTS/README agree).
29. [M] Persisted settings count is 29 keys before the appended SMB block — `EncodeSettings` (`system.lua`): 24 base lines + 5 `EMBER_*` lines = 29, then `SmbAppendLines`. (See UNVERIFIABLE note on the docs' name enumerations.)
30. [M] BDMA marker file is `bdma_mode.txt`, legacy `.pldr_bdma_mode` still read — `system.lua:5140`, `system.lua:6118-6119`.
31. [M] POPSTARTER MC folder toggle deletes `mc:/POPSTARTER` (both slots) and is interlocked with BDMA/Adaptive — `system.lua:5602-5607` (delete loops `mc0:`/`mc1:`) + interlock in settings commit.
32. [M] SMB defaults: Static (DHCP default false), Server/Port/Share/User/Pass all blank; blank port → POPSTARTER 445 and `:445` is written explicitly into SMBCONFIG.DAT — `PLDR.SMB_FIELDS` (`system.lua:5771-5785`, all `default = ""`, DHCP `false`); `system.lua:8145-8149, 8221`.

Behaviour / controls / launch (22):
33. [M] Cross/Circle confirm flips on Japanese-ROM consoles by reading `rom0:ROMVER` at boot — `system.lua:5219-5225` (byte 5 == `'J'` sets `PLDR.CONFIRM_CIRCLE`).
34. [M] L1 jumps to top of game list, press again to bounce to bottom — `ui.lua:3683-3688`.
35. [M] R2 launches "HDD Alt" mode on the HDD (PFS) list only — `ui.lua:4103, 4344` (GHDD-gated).
36. [M] R3 is a session-only hidden-games reveal; nothing persisted — STATE/README agree with the `PLDR._GLOBAL_HIDE_SAVED` transient implementation.
37. [M] R1 rescans in place; with cache enabled it rebuilds/overwrites the per-device `.gamecache` — `ui.lua` R1 arms ("FORCE path: a fresh live scan that then OVERWRITES the device's .gamecache").
38. [M] On an Ember row, L2 opens the per-game overrides — `ui.lua:4096-4100`.
39. [M] BOOT.ELF exit searches `mc0:/BOOT/BOOT.ELF` then `mc1:/BOOT/BOOT.ELF` — `ui.lua:2366-2367`; `src/elf_loader/src/elf.c:499`.
40. [M] At boot, every `.irx` in the ELF's own folder is loaded in directory order, `IRX/` subfolder as fallback when none — `system.lua:2157-2187` (`LoadIrxFromDir(APP_DIR_LOCAL)`, then `IRX`, then `POPSLDR/IRX`).
41. [M] On-screen keyboard: Circle with unsaved typing needs a second press within ~1.5 s to discard — `ui.lua:2822-2830` (`discard_until = _NowMs() + 1500`); R2 symbol-shift set and uppercase-on-open are as documented.
42. [M] Disc-icon warning thresholds: over 1024 px a side or over the size budget (~607×607 full colour) — `src/graphics.cpp:141-145`; `ui.lua:872-880`.
43. [M] Launch arguments `-page=`/`-mode=` (alias), `-game=`, `-bdma=`, `-retrogem=`, `-debug` are all parsed — `src/main.cpp:231-256`.
44. [M] `-page` values: exfat/ata/ataN→exFAT page, hdd/hdd0/pfs/apa/apa0→PFS page, usb/mass→USB, mc/memcard accepted-but-not-navigable, mmce, mx4sio/mx4/sdc, smb; bare `bdma` is a no-op — `NormalizeLaunchPage` (`system.lua:2360ff`).
45. [M] `-game=` on SMB is not wired and toasts "Auto-launch page not supported: SMB" — `system.lua:11431` (toast site; doc's behaviour claim correct, its line cite drifted — see UNVERIFIABLE).
46. [M] SMB modules pack is 6 IRX (`poweroff, ps2dev9, ps2ip, ps2smap, smbman, SMSUTILS`) + `SMBCONFIG.DAT`/`IPCONFIG.DAT` = 8 files; turning it off removes those 8 from both card slots — `system.lua:5174-5176`, `PLDR.RemoveSmbModules` (loops pack roots, deletes 6 IRX + 2 DAT per root).
47. [M] SMB browsing works without the pack; launching is blocked/warned when the pack is missing — `PLDR.AreSmbModulesStaged` / launch gate (`system.lua:8462ff`).
48. [M] SMB share layout `\\server\share\POPS\<Game>.VCD`; launch hands POPSTARTER an `SB.<name>.ELF` selector — SMB launch path in `system.lua` (selector construction) + COMPONENTS/ROADMAP agree.
49. [M] Network stack is lazy (nothing network at boot; SMB stack up only on SMB page entry) — `EnsureNet` in `src/luasystem.cpp` is called from SMB entry points only.
50. [M] UDPFS requires a static PS2 address (DHCP on → launch refused with that message) — `system.lua:9239-9240`.
51. [M] UDPFS server `.cue`/`.CUE` games are listed once as `<game>.VCD`, a real `.VCD` of the same name wins — `system.lua:9088-9113`.
52. [M] UDPFS runtime config files must be 1–120 bytes — `system.lua:9335` ("UDPFS config must contain 1-120 bytes").
53. [M] UDPFS config precedence is per-file `mc0:/SYS-CONF/` then `mc1:/SYS-CONF/`, existing files preserved, optional server `UDPFSCONFIG.DAT` copied only when absent from both cards — UDPFS config code in `system.lua` (MC0→MC1 per-file search) matches `docs/UDPFS_BDMA.md`.
54. [M] HDD game partitions are `__.POPS` / `__.POPS0`…`__.POPS9` — `system.lua:988-989, 2240-2250`.

Ember (10):
55. [M] Ember BIOS must be exactly 512 KiB at `EMBER/bios.bin` — launch check `bios_bytes ~= 512*1024` fails the launch (`system.lua`, `PLDR.EmberLaunch`).
56. [M] Ember launch checks `ember.elf` exists, BIOS size, and a game image; failed global-settings writes warn but do not block — `PLDR.EmberLaunch` (idem).
57. [M] Ember launch is a keep-IOP handoff with `argv[0]` = full `ember.elf` path and `argv[1]` = bare game-folder name — `System.loadELFKeepIOP(e.elf, e.elf, e.name)` in `PLDR.EmberLaunch`.
58. [M] Only immediate child folders of `EMBER/games/` containing a top-level `.cue`, `.exe` or `.bin` are listed — `EmberHasGameImage` (`system.lua:8786`: ext `.cue`/`.bin`/`.exe`) + `PLDR.EmberScanRoot`.
59. [M] APA/PFS Ember partitions are `__.EMBER` and `__.EMBER0`…`__.EMBER9` — `system.lua:8759, 8821` (`__.EMBER` or `^__%.EMBER%d$`).
60. [M] Ember native setting values: display 240/480/480p (global-only), timing auto/ntsc/pal, dither on/off, shading 15/24, controller auto/analog/d2a; per-game Default removes the key — `EMBER_PREFS` (`system.lua:8732-8736`); `EmberSetGameSetting` rejects `display` per-game (`system.lua:9014`).
61. [M] Ember folder-name validity cap exists in the scanner (names >170 chars ignored) — `EmberNameValid` (`system.lua:8740`). (No doc claims a number here; recorded as the limit a doc could cite.)
62. [M] Ember covers use the game-folder name + `_COV.png` / `_ICO.png` in the device `ART/` — `PLDR.EmberArtVcdPath` + cover candidate builder.
63. [M] Ember is a separate core, not the POPStarter/VCD path; rows are labelled `[Ember]` — Ember encode/marker + list code.
64. [M] Ember Watch compares the bundled `ember.elf` digest and can advance only the Ember pin — `.github/workflows/ember-watch.yml` + official-release digest check (Beta-2 tag asserted).

Architecture / internals (14):
65. [M] `Timer.getTime()` returns microseconds; nav/description scroll are frame-counted (NAV delay ≈0.6 s, rate ≈0.2 s, desc scroll fixed Fast 0.15 s) — `src/luatimer.cpp` `lua_time`; `ui.lua` `resolve_nav` (STATE/PRESERVATION/ARCHITECTURE agree).
66. [M] Analog-stick fold is gated on `Pads.getMode()` (live mode), not `getType()`; hysteresis assert |v|>64, release <40 — `ui.lua` stick fold; `src/luacontrols.cpp` `lua_getmode`.
67. [M] Overscan C clamp is 0..200 permille, identity at 0, OPL `rmSetOverscan` math — `src/graphics.cpp` `set_overscan` (PRESERVATION_CONTRACTS).
68. [M] BRAM loader metadata: magic `POPL` (`0x504F504C`), address `0x00083C00`, `partition_context[128]` + `load_path[256]`, identical in writer/reader — `src/elf_loader/src/elf.c:159-170` vs `src/elf_loader/src/loader/src/loader.c:144-155`.
69. [M] Keep-PFS mask is 4-bit (slots 0–3) — `src/elf_loader/src/elf.c:35-37` (`& 0x0F`).
70. [M] POPSTARTER `reboot_iop` default is 0, raised to 1 only when POPSTARTER itself is on HDD — `system.lua` `REBOOT_IOP_WHILE_LOADING_POPSTARTER = 0` + `BuildPopstarterLaunchCommand`.
71. [M] Boot IRX order iomanX→fileXio→sio2man→[mmceman iff MMCE hint]→mcman/mcserv→padman→libsd→usbd→ds34usb/ds34bt→audsrv — `src/main.cpp` bring-up sequence (ARCHITECTURE diagram / COMPONENTS).
72. [M] MX4SIO init loads USB mass before `mx4sio_bd.irx` — `src/luasystem.cpp` `lua_mx4sio_init`.
73. [M] HDD IRX args: `ps2hdd_osd` `-o 4 -n 20`, `ps2fs` `-m 4 -o 10 -n 40`; one `ata_bd` (ATA_ENABLE_BDM) serves APA/PFS + exFAT — `src/luaHDD.cpp` `Load_HDD_IRX`.
74. [M] `boot.lua` HDD branch mounts the boot partition to `pfs1:` and sleeps 2 s (seconds, not ms) — `etc/boot.lua:37-64`; `src/luasystem.cpp` sleep binding.
75. [M] Notification queue max is 2 — `ui.lua:1463` (`MAX = 2`).
76. [M] Cover `COVER_W` inset is 232 — `ui.lua:1223, 1262`.
77. [M] Embedded-asset wiring is three coordinated places (Makefile BIN2S+EMBEDDED_RSC, embed_assets.cpp extern+dual ASSET_ENTRY, images.lua registration); `IMG_FALLBACKS` is empty and `MISSING.png` is gone — `Makefile`, `src/embed_assets.cpp`, `bin/POPSLDR/images.lua:46`.
78. [M] Lua is embedded via bin2c and never read from loose on-card files; `dofile`/`loadfile` are nil'd — `src/luaplayer.cpp` `DisableLuaFilesystemScriptLoaders`.

---

## UNVERIFIABLE from code at the pin (10 — listed, not filed)

1. [U] POPStarter VCD filename limit "73 chars launches, 74 does not" and POPStarter's documented 89-char full-path limit (README Troubleshooting). POPStarter is an external binary; no length check exists in this repo's code. INFERRED: the doc's own framing (testing-derived, POPStarter-side) is consistent with that.
2. [U] UDPFS BIN/CUE upstream limits (track 1 MODE2/2352, no PREGAP/POSTGAP, INDEX 01 required, `.bin` sizes multiple of 2352, cue ≤16 KiB, ≤99 tracks, images <4 GiB, ~46 KB extra IOP RAM, ~10 s write-retry, no `rename`, no files ≥4 GiB) — `docs/UDPFS_BDMA.md`. Implemented inside the binary UDPFS driver (`usbd.irx.udpfs`); no driver source in the repo to settle them.
3. [U] `PATHMAP.INI` ≤512 bytes and the driver-side `GAMEID_DIR`/`DISCS_DIR`/`CHEATS_WS` folder semantics — `docs/UDPFS_BDMA.md`. Driver-binary behaviour; the POPSLoader-side half (loader neither creates nor edits the file) is READ-verified in code.
4. [U] Ember creating `MC1.vmc`/`MC2.vmc` in each game folder and any Ember-internal format support beyond the loader's `.cue`/`.exe`/`.bin` scan — `docs/wiki/Ember-Core.md`, Installation-Guide ("or other formats explicitly supported by the Ember version"). Ember is an external unmodified binary; only the loader-side scan/launch is in this repo.
5. [U] STATE's EXP34 "new factory defaults" bullet (SMB PS2 IP `192.168.1.10`, gateway `192.168.1.1`, server `192.168.1.100`, share `games`, user `guest`, port `1111`, DHCP on; `ART_LOCATION = art`). Outside the brief's top-of-STATE scope and framed as an EXP34-era record; the current code defaults are the opposite (all blank, DHCP off — MATCH item 32) and STATE's own later T43 bullet says "nothing is defaulted". Flagged here so a future doc pass can mark the bullet superseded; not filed under this section's scope rule.
6. [U] Settings-key enumerations in STATE/COMPONENTS/ARCHITECTURE name 23 keys while headlining "29 keys". The count 29 is correct only including `RETROGEM_GAMEID` + the five `EMBER_*` keys, which none of the three enumerations lists. Count = MATCH (item 29); enumeration completeness = ambiguous, not filed.
7. [U] "For best compatibility use 200x200 RGBA PNG covers" (README Troubleshooting). Advisory quality guidance; the decoder's actual checkable limits are 1024 px / size budget (MATCH item 42). No code requires 200×200.
8. [U] `docs/LAUNCH_ARGUMENTS.md` cites `system.lua:9368-9372` for the SMB auto-launch toast; the toast is at `system.lua:11431` at the pin. Behaviour claim is correct (MATCH item 45); this is line-anchor drift only.
9. [U] Prior-stable 1.2.3 described as the preserved POPStarter-only baseline and 1.3.0 as the first Ember Beta-2 release (README download table, RELEASE_1.3.0). Historical release-package claims; corroborated by in-repo release notes/changelog but not settleable from code at this pin.
10. [U] COMPONENTS/PRESERVATION path:line anchors generally. Both docs (and PRESERVATION explicitly) state the function/symbol is the unit of truth and line numbers drift; every function-level claim sampled matched, but a full anchor-by-anchor re-verification was out of this section's claim scope.

---

## Coverage notes

- READ in full: all scope files listed in the header. Code verification was by targeted full-function reads (`LoadSettingsNonFatal` defaults block, `PLDR.SMB_FIELDS`, `EncodeSettings`, `NormalizeLaunchPage`, `NormalizeBootPage`, `PLDR.ResolveLaunchPopstarterPath`, `PLDR.EmberLaunch`/`EmberScanRoot`/`EmberHasGameImage`, `PLDR.RemoveSmbModules`, `LoadIrxFromDir`, MainMenu OPT==6 handler, package_psu.py) plus greps for every numeric/default/version claim extracted from the docs.
- Not checked (out of scope): hardware-truth of any "hardware-confirmed / untested" status sentence (those are QA-ledger claims, not code-settleable); `.research/**` (preservation archive, not user-facing docs); `AGENTS.md`/`CONTRIBUTING.md`/`DECISIONS.md`/`TESTING.md`/`QA_REGRESSION_MATRIX.md` (not in the brief's doc list).
- No files in the repo were modified; `git status` remained clean throughout.

---

## Annex B — loader.c generator & invariant section (full evidence)

# ROUND 7 — POPSLoader: `bin2c` generator & the committed `loader.c` invariant

Repo: `~/workspace/audit-clones-2026-11-13/POPSLoader` at pin
`29272cddbf0122f14e76bc3bdd75e3b46aa870be` (READ: `git rev-parse HEAD` = pin; `git status` clean before and after).
Scope note: POPSLOADER-011 (pass 1) already filed the size/clutter finding for the committed dump.
This section does **not** repeat it; it audits the generator, the dump's internal consistency,
duplicate copies, git-history staleness, the CI parity check, and recorded hashes.
READ = observed in file/git output this run. INFERRED = reasoning from READ lines, labelled as such.

---

## 1. The exact generator

**Tool (READ):** PS2SDK's `bin2c`, not in-repo, not a system tool in this VM (`git ls-files | grep bin2c` = none; `$PS2SDK` unset here).

- `src/elf_loader/Makefile:9` — `BIN2C = $(PS2SDK)/bin/bin2c`
- Top-level `Makefile:70` — the same tool for all other embeds: `BIN2S = $(PS2SDK)/bin/bin2c`

**Generating rule (READ), `src/elf_loader/Makefile:30-33`:**

```make
loader.c: src/loader/bin/loader.elf src/loader/src/loader.c FORCE
	$(EE_STRIP) src/loader/bin/loader.elf
	$(BIN2C) src/loader/bin/loader.elf $@ loader_elf
	touch $@
```

- `src/elf_loader/Makefile:13` (`.PHONY: FORCE`) + the `FORCE` prerequisite at :30 mean this rule
  **always** re-runs on every `make -C src/elf_loader` — it strips `loader.elf` in place, re-runs
  `bin2c … loader_elf`, and `touch`es the output. The rationale comment is at :18-29 (strip rationale
  :18-26; "In place, NOT into a copy: CI … validates blob parity by running bin2c on THIS file and
  cmp'ing against loader.c" at :27-29 — see §4: that claim does not hold as written).
- Paths are relative to `src/elf_loader/`: `src/loader/bin/loader.elf` ≡ repo path
  `src/elf_loader/src/loader/bin/loader.elf`, the `EE_BIN` of the child build
  (`src/elf_loader/src/loader/Makefile:8-9`: `BINDIR = bin/`, `EE_BIN = $(BINDIR)loader.elf`;
  child flags at :13-22: `LOADER_ENABLE_DEBUG_COLORS ?= 0`, `EE_NEWLIB_NANO ?= 1`,
  `EE_COMPACT_EXECUTABLE ?= 1`, `EE_LINKFILE ?= linkfile`).

**Driver rule (READ), top-level `Makefile:354-359`:**

```make
elfloader: src/elf_loader/libcustom-elf-loader.a
src/elf_loader/libcustom-elf-loader.a: src/elf_loader
	@$(MAKE) cleanbin
	@$(MAKE) -C src/elf_loader/src/loader/ LOADER_ENABLE_DEBUG_COLORS=$(LOADER_ENABLE_DEBUG_COLORS) clean all
	@$(MAKE) -C src/elf_loader clean all
```

i.e. CI/local `make elfloader` builds the child ELF first, then the stage-2 make regenerates
`src/elf_loader/loader.c` unconditionally (FORCE). `LOADER_ENABLE_DEBUG_COLORS = 0` at top-level
`Makefile:42`, passed through at :358.

**CI regeneration/compare steps (READ):** no workflow regenerates `loader.c` as a separate step;
regeneration happens inside the compile step, and the only compare is the conditional block in the
"Verify embedded build identity" step, duplicated in three workflows:

- `.github/workflows/compilation.yml:171-175` compile (`make clean elfloader all`), compare at :193-203
- `.github/workflows/rolling-release.yml:166` compile (same command), compare at :195-205
- `.github/workflows/experimental-release.yml:162` compile (same command), compare at :191-201
- `.github/workflows/official-release.yml` — no `bin2c`/`loader.c` check at all (it republishes the CI artifact).

---

## 2. The dump against itself — CLEAN

File (READ): `src/elf_loader/loader.c`, 8,740 lines per pass 1 / 8,741 lines incl. final newline by `wc`-equivalent count this run, 855,821 B.

- Header, `src/elf_loader/loader.c:1-5` (READ):
  `#ifndef __loader_elf__` / `#define __loader_elf__` /
  `unsigned int size_loader_elf = 139700;` (:4) /
  `unsigned char loader_elf[] __attribute__((aligned(16))) = {` (:5)
- **Declared vs counted (READ, parsed this run): exactly 139,700 comma-separated hex tokens in the
  array = 139,700 bytes. Declared `size_loader_elf` = 139,700. MATCH.**
- Reconstructed payload hashes (READ, computed from the parsed bytes):
  SHA-256 `e7861872d22ac2160c6bce2eba01c7700971af3f0d14e9969d7f771263380dd4`,
  MD5 `7a17593e6d0a8eacc11d4bcbdf3f9b4d`.
- Structure (READ): exactly **one** array in the file; no second array, no alignment padding bytes
  inside the array — `aligned(16)` is a declaration attribute only (:5). The array body ends with a
  trailing comma before `};` (bin2c style) — that comma is syntax, **not** an extra byte; there is
  **no appended NUL terminator counted in the array**. Proof from the ELF itself: section-header
  table ends at `e_shoff 138900 + e_shnum 20 × e_shentsize 40 = 139,700` = exactly the counted size,
  so the array is a byte-exact whole ELF file with nothing before/after it.
- ELF header verdict (READ, from the reconstructed bytes): **valid PS2 EE ELF.**
  `\x7fELF` (bytes `0x7f,0x45,0x4c,0x46` at `loader.c:5` ff.), `EI_CLASS=1` (ELFCLASS32),
  `EI_DATA=1` (little-endian), `EI_VERSION=1`, `e_type=2` (EXEC), `e_machine=8` (EM_MIPS),
  `e_entry=0x000840f0`, `e_phoff=52`, `e_phnum=2` (one MIPS-specific phdr `p_type=0x70000003`,
  one `PT_LOAD`: offset 128, vaddr `0x84000`, filesz 126,216, memsz 173,500 — the BIOS-memory
  load address the `linkfile` stage-1 build targets), `e_shoff=138900`, `e_shnum=20`, `e_shstrndx=19`.
  This matches what a stripped PS2 EE executable should be, and matches the Makefile's stripped
  size claim (`src/elf_loader/Makefile:22`: "Stripped it is 139,700 bytes").
- Consumer note (READ): the declared size is not what bounds consumption.
  `src/elf_loader/src/elf.c:32` declares only `extern unsigned char loader_elf[];` and :406 takes
  `u8 *boot_elf = (u8 *)&loader_elf;` and parses the ELF header from the array; the only other
  `size_loader_elf` reference in the tree is commented out (`src/system.cpp:14`).

## 3. Is the embedded binary present anywhere else? — NO

(READ) `src/elf_loader/src/loader/bin/loader.elf` is **not committed**: `git ls-files` lists only
`src/elf_loader/{Makefile,loader.c,include/elf-loader.h,src/elf.c,src/elf.h,src/loader/Makefile,src/loader/linkfile,src/loader/src/loader.c}`
for the whole subtree, the on-disk child tree has no `bin/` directory in this checkout, and
`.gitignore:19` is `*.elf`. The only committed `.ELF` files in the repo are unrelated
`bin/POPSLDR/POPSTARTER.ELF` variants. No second embed of `loader_elf` exists
(`grep loader_elf` outside the generated file hits only the consumer at `src/elf_loader/src/elf.c:32,406`).
**Therefore no byte-compare against a committed `loader.elf` is possible — stated plainly: the
generated `.c` is the only committed copy of this binary in the repo.**

## 4. Staleness — historical window PROVEN; at HEAD, chronology is clean; CI would NOT catch a recurrence

### 4a. Timeline (READ, `git log --full-history` on HEAD; `--follow` alone is misleading here — see note)

| Artifact | Last content-changing commit | Date |
|---|---|---|
| Generated `src/elf_loader/loader.c` | `9c23cf0483a2465e0b46421b81f43ffb85be7e99` "perf(size): strip the embedded child ELF loader" | 2026-07-14T20:15:44-07:00 |
| Child source `src/elf_loader/src/loader/src/loader.c` | `edcd8230f17d4e96788e99a2205a77458ffd3198` "Beta 12 play (#492)" (blob `5453860…`) | 2026-06-15T15:02:28-07:00 |
| Child `Makefile` + `linkfile` | `56db5f7c9712a5ced27ff9d08e38e71fb0e060c0` | 2026-03-29T03:24:40-07:00 |
| `src/elf_loader/Makefile` (generator) | same `9c23cf0…` as the dump | 2026-07-14 |

Blob cross-check (READ): the child-source blob at HEAD, at `3cf2ab3…`, at `edcd823…`, and at both
`9c23cf0…` and its parent is the identical `5453860879b6caaa53fd938ffe4bd080227b71ad`; the generated
blob at HEAD = at `9c23cf0…` = `cba1884093eae38550e617de49df64640c38c21d`.
**No child-source, child-Makefile/linkfile, or generator change postdates the last regeneration.**

> History-reading note (READ): plain `git log -- <child source>` tops out at
> `3cf2ab35f5fdc67d1d8addd3b35766c75715b485` (2026-06-04) because TREESAME merge simplification
> hides the `edcd823…` line (merged 2026-06-18 by `af983d7…`); `--full-history` shows it. Both
> lines converge on the same child-source blob, so the verdict is unaffected — but an auditor
> using only the default log would mis-date the last source change by 11 days.

### 4b. FINDING — the committed dump WAS stale for ~7 weeks in 2026 (proven by history alone)

Between the previous regeneration `52f1c36773dda011fd1cb2862da0107821e2b238` (2026-05-23, which
changed child source **and** dump together) and `9c23cf0…` (2026-07-14), five child-source commits
landed with **no** accompanying `src/elf_loader/loader.c` commit (generated blob unchanged at
`a0fa34e217c49206fb59186ef69a2c93c93d87b4` throughout):

- `69ff75ca427af4996a4c312c61b3e17bad4c486d` 2026-05-25 — child `loader.c` +115 lines
- `3f23a2cbd1df54e7148573cbbb06169bf7ca679d` 2026-05-25 — child `loader.c` +19 lines
- `8b370f9a132b1c91e8f6e60eebe47b22c6a79d59` 2026-05-25 — child `loader.c` −134 lines
- `3cf2ab35f5fdc67d1d8addd3b35766c75715b485` 2026-06-04 — child `loader.c` 9 lines changed
- `edcd8230f17d4e96788e99a2205a77458ffd3198` 2026-06-15 — child `loader.c`: `DPRINTF` redefined to a
  no-op under `LOADER_ENABLE_DEBUG_COLORS` (that one alone is flag-gated and the flag defaults to 0 —
  `Makefile:42`, child `Makefile:13` — so it alone might not change the default binary; the
  May-25/Jun-04 routing/reset changes are unconditional code and would.)

So anyone who built the parent loader **without** running `make elfloader` first, or who read the
committed blob as the shipped loader, had a pre-May-25 child loader from 2026-05-25 to 2026-07-14.
`9c23cf0…` closed the window (its diff: `src/elf_loader/Makefile` +13, `src/elf_loader/loader.c`
57,454 lines changed — the strip regeneration). **At the current pin this is a past defect, not a
live one** — but it is the exact failure mode §4c shows is still unguarded.

### 4c. FINDING — the CI "parity check" cannot catch a stale committed `loader.c`

The block at `compilation.yml:193-203` (identical at `rolling-release.yml:195-205`,
`experimental-release.yml:191-201`) reads as a parity gate and is described as one at
`src/elf_loader/Makefile:27-29`, `ARCHITECTURE.md:757-759`, and `QA_REGRESSION_MATRIX.md:147`
(CI-07). It is not one, for two independent reasons, either of which is sufficient:

1. **The committed file is destroyed before the check runs.** The preceding step
   (`compilation.yml:171-175`) runs `make clean elfloader all`; `Makefile:358-359` rebuilds the
   child and re-makes `src/elf_loader`, whose `loader.c` rule has a `FORCE` prerequisite
   (`src/elf_loader/Makefile:13,30-33`) and therefore **overwrites the workspace `loader.c` with a
   fresh `bin2c` dump and `touch`es it**. No step preserves the committed version
   (no `git diff`/`git show HEAD:`/copy-aside for this file anywhere in the workflows — READ:
   `grep "git diff" .github/workflows/*.yml` hits only `docs-site.yml:158`, for the docs site).
2. **Even the conditional compare is self-referential.** The compare only runs
   `if [ ! src/elf_loader/loader.c -nt src/elf_loader/src/loader/src/loader.c ]`
   (`compilation.yml:193`). After step 1 the workspace `loader.c` was just `touch`ed during the
   build, so it *is* newer than the checked-out source and the block is skipped in the normal flow.
   If it ever did run, it `cmp`s the just-regenerated workspace `loader.c` against a fresh `bin2c`
   of the same just-built (and in-place stripped) `loader.elf` (`compilation.yml:196-197`) — a
   comparison of a file with its own regeneration, which can only fail on generator
   nondeterminism, never on committed-blob staleness. It also only ever timestamps the one source
   file, never the child `Makefile`, `linkfile`, or the top-level `LOADER_ENABLE_DEBUG_COLORS`
   flag (`Makefile:42`) that also determine the binary.

Empirical corroboration (READ): the parity fallback was introduced 2026-04-30 by
`4cada12ebfb73d0e1c6a639303a0ead016f81b0b` "Harden loader freshness CI check with content parity
fallback" — and the §4b stale window (2026-05-25 → 2026-07-14) happened *after* it, on this same
master lineage. A working gate would have had to be red or bypassed for every one of those five
commits. (CI run results themselves were not inspected — READ is the history + workflow text, not run logs.)

INFERRED fix shape (not filed as a recommendation per LESS-NOT-MORE; stated so the gap is
actionable): compare *before* building — e.g. snapshot `loader.c` at checkout, or after the build
run `git diff --exit-code -- src/elf_loader/loader.c`.

### 4d. At-HEAD staleness verdict

**Not stale, on chronological evidence (READ):** last regeneration 2026-07-14 (`9c23cf0…`) postdates
the last child-source change 2026-06-15 (`edcd823…`), the last child build-input change 2026-03-29
(`56db5f7…`), and no relevant input changed after it (blob identities in §4a).
**INFERRED, not proven:** that the committed bytes are exactly what `bin2c` would emit from a fresh
build of the current child source. That cannot be proven from this VM — there is no PS2SDK/`bin2c`
here and building is outside this read-only section — and, per §4c, CI as written does not prove it either.

## 5. Any recorded checksum/hash of `loader.elf`? — NO

(READ) No hash of `loader.elf` / of the reconstructed payload appears in any Makefile, workflow,
doc, or script searched (`grep -rn "sha256|md5|checksum"` filtered for loader, plus a direct search
for the payload's size `139700` and for the hashes computed in §2 outside the generated file: no hits).
Hashes that *do* exist in this repo are for other binaries, which makes the absence specific, not generic:

- `iop/embed/ata_bd.irx` SHA-256 pinned and `sha256sum -c`-checked: `compilation.yml:95`
  (duplicated `rolling-release.yml:90`, `experimental-release.yml:86`).
- Ember `ember.elf` SHA-256 compared in `ember-watch.yml:66,86-88` and `official-release.yml:59-86`.
- The unstripped→stripped equivalence claim in `src/elf_loader/Makefile:23-24` cites an MD5 of
  `objcopy -O binary` output as *having been proven* by the author, but records no digest value.

For reference, the current payload's digests (computed this run, recorded nowhere in-repo):
SHA-256 `e7861872d22ac2160c6bce2eba01c7700971af3f0d14e9969d7f771263380dd4` · MD5 `7a17593e6d0a8eacc11d4bcbdf3f9b4d`.

## 6. Minor observations

- **INFERRED dead rule:** `src/elf_loader/Makefile:15-16` —
  `src/loader/bin/loader.elf:` / `$(MAKE) src/loader`. With no `-C` and no file argument, a sub-make
  whose goal is the already-existing directory `src/loader` creates nothing; this rule cannot
  produce `loader.elf`. It is harmless only because the top-level driver (`Makefile:358`) builds the
  child first. A direct `make -C src/elf_loader` on a clean checkout would reach the `loader.c`
  recipe with no `loader.elf` to strip/`bin2c`. (Make-semantics inference from the READ lines; not
  executed — this section is read-only.)
- **Doc drift (READ):** `COMPONENTS.md:387-388` still calls the dump a "committed ~6.5 MB bin2c
  blob"; the file at this pin is 855,821 B (§2). Pre-strip-era wording left behind by `9c23cf0…`.

## Verdict summary

- Declared vs counted size: **139,700 = 139,700 — exact.**
- ELF header/structure: **clean** — valid 32-bit LE MIPS EXEC, entry `0x840f0`, ends exactly at byte 139,700, single array, no padding/NUL surplus.
- Duplicate binary in repo: **none** — `loader.elf` is gitignored (`*.elf`, `.gitignore:19`) and uncommitted; no byte-compare is possible.
- Staleness at pin: **not stale by commit chronology** (regen `9c23cf0…` 2026-07-14 > last source `edcd823…` 2026-06-15); byte-parity itself **unverified** (no toolchain in VM, and CI doesn't prove it).
- Staleness historically: **proven stale 2026-05-25 → 2026-07-14** (five source commits, zero dump commits).
- CI parity check: **ineffective for its stated purpose** — regeneration-before-check + timestamp gate + self-`cmp` (`compilation.yml:171-175,193-203` and duplicates).
- Recorded `loader.elf` hash: **absent** (other binaries in the same workflows are pinned; this one is not).

---

## Annex C — Assembly census + header macro pass (full census)

# ROUND 7 — POPSLoader: Assembly census + Header macro pass

- **Repo / pin:** `~/workspace/audit-clones-2026-11-13/POPSLoader` at `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (READ: `git rev-parse HEAD` = pin; `git status --porcelain` empty before and after this pass — READ ONLY throughout).
- **Scope:** (A) every tracked assembly file; (B) header function-like macros doing size/count arithmetic, plus a sweep for `sizeof(x)/sizeof(x[0])`-style array-count idioms applied to pointers.
- **Result: ZERO findings filed.** Nothing here repeats POPSLOADER-001…059. Two concrete anomalies found along the way are recorded as **Observations (not filed)** at the end, with the reason each falls outside this section's filing rule, so the parent can disposition them.

---

## PART A — Assembly census

### A.1 Census (command evidence)

Command (as specified): `git ls-files | grep -iE '\.(s|sx|asm)$'` → **2 hits**. A separate explicit check for capital `.S` returns the same 2 (the `-i` flag already covers it). A broader sweep for `.a`/`.inc` assembly-adjacent extensions adds nothing.

| # | Path | Lines | Build target consuming it (Makefile citation) | Provenance |
|---|------|-------|--------------------------------------------------|------------|
| 1 | `modules/ds34bt/iop/smsutils.S` | 180 | `modules/ds34bt/iop/Makefile:2` — `IOP_OBJS = ds34bt.o smsutils.o imports.o`, `IOP_BIN = ds34bt.irx` (`:1`) | **Vendored** (see A.2) |
| 2 | `modules/ds34usb/iop/smsutils.S` | 180 | `modules/ds34usb/iop/Makefile:2` — `IOP_OBJS = ds34usb.o smsutils.o imports.o`, `IOP_BIN = ds34usb.irx` (`:1`) | **Vendored** (see A.2) |

- **Assembly files found: n = 2. First-party: m = 0.** Total assembly lines: 360 (180 × 2).
- The two files are **byte-identical**: `sha256sum` both = `1a9b144fc3eb6b64485a4aba20dc383d12c87a8da6a16f1ec94815cbca6cf361` (READ). The byte-identical duplication itself is already on record in pass 1 (the supporting-files sentence in Sable-POPSLoader.md) and is **not** re-filed.
- The pademu module does **not** compile either `.S` file: `modules/pademu/Makefile:21` sets `-DUSE_SMSUTILS`, and `modules/pademu/sys_utils.h:21-29` *imports* `mips_memcpy`/`mips_memset` from the smsutils IRX (or aliases them to `memcpy`/`memset` at `sys_utils.h:31-32` when the flag is off). `POPSTARTER/SMSUTILS.irx` at repo root level is a prebuilt binary, not a source file, and is outside this census.

### A.2 Provenance (READ)

Both copies carry the same header at `smsutils.S:1-9`:

> `PS2DEV Open Source Project.` / `Highly optimized versions of memcpy/memset.` / `Pulled out 'sde' library from MIPS.` / `by Eugene Plotnikov`

That is a vendored PS2DEV/SMS-era utility, not POPSLoader first-party code. Per this section's brief, defect-filing applies to first-party assembly; **there is no first-party assembly to file against.**

### A.3 Inspection of the vendored file (census completeness; no filing)

The file defines exactly two leaf routines: `mips_memcpy` (`smsutils.S:27-128`) and `mips_memset` (`smsutils.S:130-180`). Checked against the defect classes named in the brief:

- **Stack imbalance — impossible as written (READ).** No instruction references `$sp` anywhere in the file (`grep '\$sp'` = 0 hits); neither routine creates a frame, saves registers, or calls another routine. There is no stack state to imbalance.
- **Register clobber vs ABI — clean (READ).** The complete register set used is `$v0, $v1, $a0-$a3, $t0-$t2, $ra` (token census of the file). Every one is caller-saved under the MIPS o32 ABI the IOP uses; no callee-saved register (`$s0-$s7`, `$fp`, `$gp`) is touched, so nothing needs restoring. Return-value register `$v0` is set from `$a0` at entry (`:28` memcpy, `:131` memset), matching the C prototypes' intent — subject to Observation OBS-A1 below.
- **Magic counts vs a C-side constant — no disagreement exists (READ).** The only numeric structure is internal chunking: 16-byte block loops (`:50-65`, `:94-105`, `:153-159`), 4-byte word loops, 1-byte tails, and small-size cut-offs (`sltiu $t2, $a2, 12` at `:30` for memcpy; `sltiu $t2, $a2, 16` at `:133` for memset). No C header defines a constant these are supposed to match; every caller passes its length explicitly (e.g. `modules/ds34bt/iop/ds34bt.c:531,558,566,574,847,1179`). The 12-vs-16 cut-off difference is a per-routine tuning choice inside one vendored file, not a cross-side contradiction.
- **Not assembly files, noted so the census is not misread as "no asm in the repo":** two inline-asm sites exist in C sources — `src/elf_loader/src/elf.c:389-393` and `src/elf_loader/src/loader/src/loader.c:75-79`. Both are the same `sq $0` memory-wipe idiom: four 16-byte stores at offsets 0/16/32/48 with loop step 64 (4 × 16 = 64, consistent, READ), operand passed through an `"r"` constraint so register allocation is the compiler's. No imbalance or clobber is possible in either. Not counted in the census (they are `.c` files), no finding.

### A.4 Part A verdict

**Assembly census: 2 files, 0 first-party, 360 lines, both vendored and byte-identical. Findings filed: 0** (one vendored anomaly → OBS-A1).

---

## PART B — Header macro pass

### B.1 Universe and candidate count (READ)

- Tracked headers in `src/**`, `iop/**`, `modules/**`: **26 files, 2,064 lines** (full list enumerated via `git ls-files | grep -E '\.h$'`; there are no `.hpp` files and no headers outside those trees).
- Function-like macro definitions in those headers (`grep -E '#define NAME\('`): **24 definitions**, broken down as:
  - `src/include/dprintf.h:4` — `DPRINTF(x...)` (1)
  - `src/include/graphics.h:61-64` — `A/B/G/R(color)` (4)
  - `src/include/luaplayer.h:37,39` — `dbgprintf(args...)` (2, `#ifdef DEBUG` pair), `:42` `MAX(a,b)`, `:43` `CLAMP(val,min,max)` (4)
  - `src/include/system.h:19` — `load_elf_NoIOPReset(ELF)` (1)
  - `modules/ds34bt/iop/ds34bt.h:77-79,81-83,223` — `pad_status_clear/set/check`, `hci_event_flag_clear/set/check`, `l2cap_handle_ok` (7)
  - `modules/pademu/ds34bt.h:63-65,67-69,203` — the same 7 macros, second copy (7)
- Of the 24, **20 are arithmetic** (shifts/masks/comparisons/bitwise ops) and were hand-expanded and, where trivially possible, host-compiled. The remaining 4 (`DPRINTF`, `dbgprintf` ×2, `load_elf_NoIOPReset`) contain no size/count arithmetic and were examined only for completeness.
- Additionally examined: **6 object-like arithmetic expressions** in the same two ds34 headers — `l2cap_control_channel` / `l2cap_interrupt_channel` / `l2cap_command_channel` at `modules/ds34bt/iop/ds34bt.h:224-226` and `modules/pademu/ds34bt.h:204-206` — because they are macros in function-macro clothing (no parameter list, but an evaluated expression over a global buffer).
- **Macro candidates examined: 30** (24 function-like definitions + 6 object-like channel expressions), plus **7 sizeof-division sites** in the pointer sweep (B.3).
- **The Launchstation model defect has no analogue here (READ):** `grep sizeof` over every `#define` in every header returns **zero hits** — no header macro computes a size or a count at all. There is no `MIN` macro, and no alignment/rounding macro (`ALIGN`, `ROUND_UP`, `DIV_ROUND…`) in any header (grep exit 1). The only size/count arithmetic macros in the whole tree live in a `.c` file (B.3, item 8).

### B.2 Checked-clean list (each macro expanded and verified; host gcc used where noted)

1. **`MAX(a, b)` — `src/include/luaplayer.h:42`** — `((a) > (b) ? (a) : (b))`. Host-compiled verbatim: `MAX(3,7)=7`, `MAX(9,2)=9`, `MAX(-1,-5)=-1` — computes what the name promises. **Call sites in native code: zero** (repo-wide grep returns only the definition; the `CLAMP` in `bin/POPSLDR/system.lua:4966` is an unrelated Lua function). Generic double-evaluation of the winning argument exists (host probe: 3 evaluations total across both probe args) but with no caller there is no site at which it can bite. Correct; currently unused in C/C++.
2. **`CLAMP(val, min, max)` — `src/include/luaplayer.h:43`** — `((val)>(max)?(max):((val)<(min)?(min):(val)))`. Host-compiled verbatim: `CLAMP(200,0,128)=128`, `CLAMP(-5,0,128)=0`, `CLAMP(64,0,128)=64` — correct at both bounds and in range. **Exactly one call site:** `src/luaScreen.cpp:176` — `a = CLAMP(luaL_checkinteger(L, 4), 0, 128);`, feeding the alpha byte packed at `src/luaScreen.cpp:177` (`… | (a << 24)`), with the un-clamped default `0x80` at `:175` sitting mid-range — the 0–128 bound matches the GS alpha convention the surrounding code uses (READ from the same function). Multi-evaluation is real — host probe with a counting function: `val` is evaluated **1×** when above max, **2×** when below min, **3×** when in range — but at the sole site the argument is `luaL_checkinteger(L, 4)`, a read of a fixed Lua stack slot that mutates nothing between the expansion's evaluations (INFERRED from the Lua C API contract), so every evaluation yields the same value and the result is correct. Ugly, not wrong. Not filed.
3. **`A(color)` / `B(color)` / `G(color)` / `R(color)` — `src/include/graphics.h:61-64`** — shifts 24/16/8/0 masked `& 0xFF`, cast to `u8`. Host-compiled round-trip against the packing the codebase actually uses, `src/luaScreen.cpp:177` (`r | (g << 8) | (b << 16) | (a << 24)`): packing `r=0x11,g=0x22,b=0x33,a=0x80` and extracting returns `R=0x11, G=0x22, B=0x33, A=0x80` — definition and in-repo packing agree byte-for-byte (the same low-byte-is-R convention is used open-coded at `src/luaScreen.cpp:188` and `:221`). **Call sites: zero** (grep returns only the four definitions). Correct; unused.
4. **`pad_status_clear/set/check(flag, pad)` — `modules/ds34bt/iop/ds34bt.h:77-79` and `modules/pademu/ds34bt.h:63-65`** — `ds34pad[pad].status &= ~flag` / `|= flag` / `(ds34pad[pad].status & flag)`. Each argument appears exactly once in each expansion. All call sites pass a literal `DS34BT_STATE_*` flag and a plain index variable (e.g. `modules/ds34bt/iop/ds34bt.c:622,710-712,740-742,1084-1107`; pademu twins at `modules/pademu/ds34bt.c:559,646-648,674-676`). Computes exactly the flag operation named. Correct in both copies.
5. **`l2cap_handle_ok(handle)` — `modules/ds34bt/iop/ds34bt.h:223` and `modules/pademu/ds34bt.h:203`** — `(((u16)(l2cap_buf[0] | (l2cap_buf[1] << 8)) & 0x0FFF) == (u16)(handle & 0x0FFF))`. Hand-expansion: little-endian 16-bit reconstruction from bytes 0–1, **both** sides masked to the 12-bit HCI handle field before comparison — the mask is symmetric, which is the detail that would make this wrong if absent on one side. Call sites pass a plain struct field: `modules/ds34bt/iop/ds34bt.c:980,989` (`ds34pad[pad].hci_handle`), `modules/pademu/ds34bt.c:916,925`. Correct in both copies.
6. **`l2cap_control_channel` / `l2cap_interrupt_channel` / `l2cap_command_channel` — `modules/ds34bt/iop/ds34bt.h:224-226` and `modules/pademu/ds34bt.h:204-206`** (object-like) — channel ID reconstructed little-endian from `l2cap_buf[6] | (l2cap_buf[7] << 8)` and compared against `0x0001` (control/PSM channel), `interrupt_dcid`, `control_dcid` respectively. Call sites `modules/ds34bt/iop/ds34bt.c:995,1116,1118` and `modules/pademu/ds34bt.c:931,1055,1057` use them as plain predicates in an if/else-if chain over mutually exclusive CIDs. Correct in both copies.
7. **Non-arithmetic remainder — `DPRINTF(x...)` (`src/include/dprintf.h:4`, empty), `dbgprintf(args...)` (`src/include/luaplayer.h:37,39`, `scr_printf` or empty), `load_elf_NoIOPReset(ELF)` (`src/include/system.h:19`, fixed-argument wrapper).** No size/count content; nothing to expand arithmetically. Listed so the 24-definition census is fully accounted for.
8. **Spot-check outside header scope (`.cpp`/`.c` arithmetic macros, read so the pass has no blind spot):** `ALLOC_FITS(alloc,width,height)` / `ALLOC_ISFREE(alloc)` at `src/atlas.cpp:42-46` — plain `>=` dimension comparisons, used consistently at `src/atlas.cpp:52-55`; `DEG2RAD(x)` at `src/graphics.cpp:15` — factor `0.01745329251` is π/180 to 11 significant figures, sole caller `src/graphics.cpp:1125`; `GLYPH_PAGE_OK(font,page)` at `src/fntsys.cpp:105` — bounds check `(page) <= cacheMaxPageID && glyphCache[page]`, caller `src/fntsys.cpp:480`. All compute what their names say. Correct.

### B.3 Array-count / `sizeof`-division sweep (the pointer bug hunt)

Repo-wide grep over all tracked `.c`/`.cpp`/`.h` for `sizeof X / sizeof …` patterns returns **exactly 7 sites**. Every one was traced to its declaration. **No site applies the idiom to a pointer or a function parameter** — the classic `sizeof(ptr)/sizeof(*ptr)` bug (which on a host build of the ps2atad element type would yield 4 instead of the true count; demonstrated in the host test for contrast) **does not occur in this tree.**

| # | Site | Operand declaration (READ) | Verdict |
|---|------|------------------------------|---------|
| 1 | `src/embed_assets.cpp:234` — `sizeof(g_embedded_assets) / sizeof(g_embedded_assets[0])` | `static const embedded_asset_t g_embedded_assets[]` at `src/embed_assets.cpp:116`, file scope | True array. Correct. |
| 2 | `src/luagraphics.cpp:345` — same idiom on `g_embedded_font_assets` | `static const embedded_font_asset_t g_embedded_font_assets[]` at `src/luagraphics.cpp:334` (2 entries, `:335-336`) | True array. Correct. |
| 3 | `src/luaplayer.cpp:48` — same idiom on `g_embedded_lua_assets` | `static const embedded_asset_t g_embedded_lua_assets[]` at `src/luaplayer.cpp:33` (4 entries, `:34-37`) | True array. Correct. |
| 4 | `src/retrogem.cpp:181` — `ps1_generic_game_ids_count = sizeof(ps1_generic_game_ids) / sizeof(ps1_generic_game_ids[0])` | `static const RG_PS1_GENERIC_GAME_ID ps1_generic_game_ids[]` at `src/retrogem.cpp:55`; count consumed by the loop at `:252` | True array. Correct. |
| 5 | `iop/ata_bd_fast/ps2atad.c:150` — `#define ATA_CMD_TABLE_SIZE (sizeof ata_cmd_table / sizeof(ata_cmd_info_t))` | `static const ata_cmd_info_t ata_cmd_table[]` at `ps2atad.c:93`, **56 entries** (counted); element type `ata_cmd_info_t` defined at `ps2atad.c:87-91` | Correct — host test of the verbatim macro shape reproduces 56. |
| 6 | `iop/ata_bd_fast/ps2atad.c:161` — `#define SEC_CTRL_CMD_TABLE_SIZE (sizeof sec_ctrl_cmd_table / sizeof(ata_cmd_info_t))` | `static const ata_cmd_info_t sec_ctrl_cmd_table[]` at `ps2atad.c:152`, **8 entries** | Correct — host test reproduces 8. |
| 7 | `iop/ata_bd_fast/ps2atad.c:173` — `#define SMART_CMD_TABLE_SIZE (sizeof smart_cmd_table / sizeof(ata_cmd_info_t))` | `static const ata_cmd_info_t smart_cmd_table[]` at `ps2atad.c:163`, **9 entries** | Correct — host test reproduces 9. |

Sites 5–7 deserve one explicit note because they are the closest structural relative of the model defect in this repo — a count macro whose operand *later becomes a pointer*: at `ps2atad.c:545` the consumer declares `const ata_cmd_info_t *cmd_table;` and at `:561-570` assigns `cmd_table = ata_cmd_table; cmd_table_size = ATA_CMD_TABLE_SIZE;` (and the sec/smart twins). The macro is expanded **at its definition site's translation-unit scope, against the arrays themselves**, never against `cmd_table` — so the sizes that reach the pointer's consumer are the true 56/8/9. Correct as written; it would only break if someone moved the macro's *use* to a context where only the pointer is visible, which no current code does (READ: the three macros have no other use sites).

### B.4 Part B verdict

**Macro census: 26 headers, 24 function-like definitions (20 arithmetic), 30 macro candidates examined including the 6 object-like channel expressions, 7 sizeof-division sites swept. No header macro computes a size or count; no macro computes a wrong value; no array-count idiom is applied to a pointer. Findings filed: 0.** All 30 candidates are on the checked-clean list in B.2/B.3, except the 6 dead macros in OBS-B1, which compute nothing at all.

---

## Observations (not filed — for parent disposition)

### OBS-A1 — Vendored `mips_memcpy` return register is clobbered by its own exit delay slot; no live consumer in this repo

- **Evidence (READ):** `modules/ds34bt/iop/smsutils.S:19` sets `.set noreorder` (and `:20-21` `noat`/`nomacro`), so the assembler will not insert delay-slot NOPs. `mips_memcpy` exits at `:127-128` (`1:` / `jr $ra`) with **no NOP after the jump** — the next assembled instruction in the stream is `mips_memset`'s first instruction, `move $v0, $a0` at `:131`. By contrast `mips_memset`'s own exit at `:179-180` does carry an explicit `nop` after its `jr $ra`.
- **Inference (INFERRED, MIPS delay-slot semantics; no MIPS assembler or hardware in this VM to disassemble a built IRX):** that `move` therefore executes in `jr $ra`'s delay slot on every `mips_memcpy` return. At that point `$a0` has been advanced by the copy loops (e.g. `:62-63`, `:102-103`, `:123-124`), so `$v0` returns **dst + len**, not the original dst that `:28` (`move $v0, $a0`) set up and that the standard `memcpy` contract promises.
- **Why it is not filed as a POPSLoader finding:** (1) the file is vendored (A.2) and this section's filing scope is first-party assembly; (2) **the defect is unreachable in this repo** — every prototype declares the functions `void`: `modules/ds34bt/iop/ds34bt.h:373-374`, `modules/ds34usb/iop/ds34usb.h:185-186`, `modules/pademu/sys_utils.h:23,26`; and every one of the ~45 call sites in `modules/**` is a bare statement discarding any value (grep-verified), so no caller can observe the wrong `$v0`; (3) the file is byte-identical in 7 copies across the three clones present in this VM (POPSLoader ×2, Launchstation ×2, RiptOPL ×3 — sha256 READ in A.1), so any fix is a cross-repo decision, not a POPSLoader one.
- **If the parent wants it:** the fix is one `nop` after `smsutils.S:128` in each copy (LESS: one added line per copy, or leave the vendored file untouched and note the `void` prototypes as the standing guard). Flagged as a cross-repo (X-series) lead only.

### OBS-B1 — `hci_event_flag_*` macros (×6, two headers) are dead and reference a variable that does not exist

- **Evidence (READ):** definitions at `modules/ds34bt/iop/ds34bt.h:81-83` and `modules/pademu/ds34bt.h:67-69` (`hci_event_flag_clear/set/check(flag)` → `hci_event_flag &= ~flag` etc.). Repo-wide grep for `hci_event_flag` returns **only** those 6 definitions plus the two header comments at `modules/ds34bt/iop/ds34bt.h:140` and `modules/pademu/ds34bt.h:122`: **zero call sites, and no declaration of a variable named `hci_event_flag` anywhere in the tree.** The companion `HCI_FLAG_*` enum values the macros existed to manipulate are likewise used nowhere outside the headers (`modules/ds34bt/iop/ds34bt.h:141-149`, 9 values; `modules/pademu/ds34bt.h:123-129`, 7 values — the two dead sets have even diverged from each other, which corroborates that neither is live).
- **Inference (INFERRED):** if any of the six macros were ever expanded, compilation would fail on the undeclared identifier `hci_event_flag`. Today they cost nothing at runtime because they are never expanded.
- **Why it is not filed under Part B's rule:** the filing rule for this section is macros that compute something *wrong*; these compute nothing (never expanded). The shape is a plain dead-code deletion (Cat 5 / LESS), adjacent to the ds34 duplication already covered by POPSLOADER-033/049, not a macro-arithmetic defect. **Candidate action for the parent:** delete the 6 macro lines (and optionally the 16 orphaned `HCI_FLAG_*` enum values) — pure removal, no behaviour change, no replacement needed.

---

## Totals for this section

| Metric | Count |
|---|---|
| Assembly files in tracked tree | **2** |
| — first-party | **0** |
| — vendored (byte-identical pair, 180 lines each) | 2 |
| Headers in scope | 26 (2,064 lines) |
| Function-like macro definitions in headers | 24 (20 arithmetic) |
| Macro candidates examined (incl. 6 object-like channel expressions) | **30** |
| `sizeof`-division sites swept for the pointer bug | 7 (0 on pointers) |
| **Findings filed** | **0** |
| Observations passed to parent (not filed) | 2 (OBS-A1 vendored delay slot; OBS-B1 dead `hci_event_flag_*` macros) |

---

## Updated residue statement (supersedes the round-4 residue for POPSLoader)

Round 7 closed three of the five residue classes named in the round-4 verdict:

- **BDMAssault tarball contents — AUDITED.** All 119 files inventoried and classified; all 21 cross-generation pairs diffed; the first-party glue (bdm, libbdm, usbd, usbmass_bd, bdmfs glue) defect-passed end-to-end (POPSLOADER-071…107; vendored FatFs R0.14b bodies remain inventory-only, as in every round — they are pristine upstream ChaN code, and this round verified the merged copies carry no local deltas). The provenance chain was tested: it **holds for `usbd.irx`** (string-corroborated) and **fails for `usbhdfsd.irx`** (POPSLOADER-069, R7-REV-006).
- **Generated bin2c `loader.c` — INVARIANT VERIFIED, not line-read (by design).** Declared size == counted size == ELF section-table end (139,700 B); not stale at the pin by git chronology; byte-parity with a fresh build remains INFERRED because no PS2SDK exists in this VM and the source ELF is uncommitted. The parity *check* that supposedly guards it is ineffective (POPSLOADER-066).
- **Documentation prose — CHECKED.** 100 checkable claims settled against code (78 MATCH / 10 UNVERIFIABLE-external / 12 contradicted in 6 findings). Prose that makes no checkable claim (history, plans, rationale) remains prose — it was never auditable and is not "residue" in any actionable sense.

What remains, plainly:

- **Binary contents.** The repo's shipped binaries (IRX/ELF payloads, the POPStarter.ELF and Ember binaries, the two source-less MX4SIO IRXs) were identified, hashed and string-profiled where a finding needed it, but never disassembled or behaviourally audited. That requires a disassembly/toolchain rig this VM does not have, and POPSLOADER-069 is the only concrete provenance gap the hash/string level exposed.
- **Hardware behaviour.** Nothing in any of the seven rounds is verified on a real PS2. Every finding is source-level (READ, or INFERRED and labelled); runtime consequences — IOP traps, hangs, corruption — are derived from the code, not observed on console. A build/hardware rig remains the only productive continuation for this repo besides a pin move.

**Round-7 totals:** 48 new findings (POPSLOADER-060…107) → POPSLoader cumulative **107 findings**; 2 revisions; assembly census 2 files / 0 first-party / 0 findings; macro census 30 candidates / 0 wrong computations. (Supersedes the totals originally printed here — 37 findings / cumulative 96 — which counted 20 tarball findings, R7-T07…T26, that were claimed but never written; the tarball section was completed by the repair pass recorded in its Section completion note, and its claimed dissolved-candidates list is unrecoverable.) Clone git-clean at end; read-only held.
