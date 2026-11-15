# Sable Audit — CROSS-REPO ROUND 9: Shipped Binaries vs Audited Source (2026-11-14)

**Scope:** the one class every previous round declared out of reach — the shipped binary
artefacts themselves. Rounds 1–8 sized and hashed binaries but never opened them. This
pass inventories **every** tracked executable artefact in four repos (extension census
`.irx/.elf/.exe/.o/.img/.bin/.xz` **plus** a `file(1)` scan of *every* tracked file, which
caught the mode-suffixed BDMAssault variants — `usbd.irx.ata` etc. — that no extension
census sees), identifies each from its own ELF structure / sections / strings, checks it
against its claimed or expected source, and hash-joins the whole set across repos.
PS2-Servers ships **zero** tracked binary artefacts (CI-built Go application — census
result, not an omission).

**Pins (verified at start; clones NOT updated by this agent; all five `git status` clean
at end — read-only held):**

| Repo | Branch | Pin == live HEAD |
|---|---|---|
| RiptOPL | rebuild/main | `2e347d5ac885cd0ff73e9ad4143781946396f492` |
| Launchstation | master | `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` |
| POPSLoader | master | `29272cddbf0122f14e76bc3bdd75e3b46aa870be` |
| Simple-Media-System | master | `e65ced39a27eee8d996e9257e21594d1cac1c93d` |
| PS2-Servers | main | `c5f021c4d38698860f56b03498adc261dbb8d8dd` |

**Tooling statement (what actually ran):** the host `objdump` is x86-only, so MIPS
binutils was fetched user-space: `apt-get download binutils-mipsel-linux-gnu`
(2.42-2ubuntu1cross5), extracted to `/tmp/mipsbin`, run with
`LD_LIBRARY_PATH=/tmp/mipsbin/usr/lib/x86_64-linux-gnu`. **`mipsel-linux-gnu-readelf`
and `mipsel-linux-gnu-objdump` ran on the MIPS ELFs, including real disassembly**
(`objdump -d`/`-dr`) of the one contested binary (POPSLoader's `usbhdfsd.irx`, §2.1) and
structural reads (headers, sections, `.iopmod`, symtabs) of the rest. Capstone 5.0.7 was
installed into a venv (`/tmp/r9venv`) as a fallback and was not needed. Also run: host
`file`, `strings`, `sha256sum`/`md5sum`, `cmp -l` byte-diffs, `xz -dc` payload
comparisons, and `git log`/`git show` archaeology. Full disassembly of all 206 artefacts
was **not** performed and is not claimed: the pass is identification-level (structure +
strings + targeted disassembly) except where §2 says otherwise. Per-file `strings` and
`readelf` output is preserved in `round9-sections/strings/` and `round9-sections/readelf/`;
the contested binary's full disassembly is `round9-sections/usbhdfsd-objdump-dr.txt`.
**One licence limit:** `ship/EMBER/ember.elf` carries its owner's licence text in its own
strings ("Decompiling, disassembling or reconstructing this software … is not permitted
by the licence"). It was therefore identified (name/version/hash/strings header only) and
**not** disassembled or reconstructed; its inventory row is identification-level by the
owner's terms. The one KELF file is inventoried hash-only, per the audit's standing rule
on KELF material (no content analysis).

**Census totals:** **206 tracked binary artefacts, 10,857,571 B** — RiptOPL 108
(7,985,914 B), POPSLoader 39, Launchstation 9, SMS 50 — plus SMS's 24 `.irx.xz` payloads
analysed in decompressed form. New findings: **4 (X-54…X-57)**. Prior binary claims
re-tested: **POPSLOADER-069 verified at disassembly level (§2.1); the REV-006 tarball pin
corroborated quantitatively (§2.2); RiptOPL's PROVENANCE.md hash table verified 9/9 (§2.3).**

---

## 1. Headline results

1. **POPSLOADER-069 is now disassembly-verified, not just string-verified.** The shipped
   `usbhdfsd.irx`'s own entry point prints `MX4SIO: MX4SIO v1.2` as its first action; it
   imports `sio2man` and **no USB library at all** (§2.1). The misnamed driver is exactly
   what round 7 said it was.
2. **The POPSTARTER "versions" are one binary and a 4-byte config word.** All five/six
   shipped `POPSTARTER.ELF` variants in both repos differ *only* inside one dword at file
   offset 0x410 — and the default ELF every user runs is byte-identical to the folder
   named `DEBUG` (X-55, executed `cmp` matrix in §3.2).
3. **SMS checks in 18 IOP modules twice** — plain `.irx` files byte-identical to the
   `.irx.xz` payloads the build actually embeds, with no consumer anywhere in the repo:
   286,561 B of pure duplication (X-54, executed `xz -dc` comparison).
4. **RiptOPL's `drvtif-ingame.irx` has been a byte-copy of `drvtif.irx` since the commit
   that introduced it** — while its sibling pair (`tifinet`) is genuinely distinct
   (X-56, git archaeology).
5. **The BDMAssault variant family is 45 files but only 9 distinct binaries**, and its
   one provenance record lives *downstream* (RiptOPL) — the `.udpfs` pair is missing
   even there (X-57, matrix in §3.1).
6. **Everything else checked came back consistent:** the tarball↔`usbd.irx` pin, all five
   SMS VU microprogram objects vs their shipped C arrays, the udpfs trio's three-repo
   identity, SMS's 19 plain/xz pairs (as pairs — the finding is that the plain half
   shouldn't exist), and RiptOPL's documented dedupe claim.

---

## 2. Prior binary claims — re-tested with tooling

### 2.1 POPSLOADER-069 (shipped `usbhdfsd.irx` is an MX4SIO driver) — VERIFIED at disassembly level

Artefact: `POPSLoader/iop/embed/BDMASSAULT_MX4SIO/usbhdfsd.irx`, 14,993 B,
md5 `48677ae01b05c84b6f299773baa7dea0` (matches round 7). Structure (mips readelf):
ELF32, type `0xff80` (IRX), MIPS R3000, entry `0x2184`, `.text` 0x23ac B, `.rodata`
0x3c3 B, `.iopmod` 27 B, symtab stripped to the null entry.

Disassembly of the entry point (`objdump -d --start-address=0x2184`):

```
2184: addiu sp,sp,-32
218c: move  s0,a0
2190: lui   a0,0x0
2194: addiu a0,a0,10064        ; a0 = 0x2750
21a0: jal   0x22bc             ; printf-class import stub
```

`0x2750` is exactly the `.rodata` vaddr of the string `MX4SIO: MX4SIO v1.2` (file offset
10208, `.rodata` at file 0x243c / vaddr 0x23ac — arithmetic in the evidence). **The
module's init path prints its MX4SIO version banner before anything else** — the string
is live code, not stray data. The export-table magic `0x41e00000` follows the entry
function at 0x21d8. Imported libraries (strings, complete list): `dmacman`, `intrman`,
`loadcore`, `stdio`, `sysclib`, `thbase`, `thevent`, `thsemap`, `modload`, **`sio2man`**.
There is **no USB import and no USB/SCSI/mass-storage string anywhere in the binary**;
every printable string is MX4SIO card handling (`card detection thread running`,
`%lu %u-byte logical blocks`, `sio2man_hook_init returned %d`). The library name it
registers is `mx4sio`. Conclusion: round 7's string-level refutation of the tarball
correspondence is upheld at structure + disassembly level. The binary's source remains
absent from POPSLoader (and from the tarball's 119 files — 0 binaries, 0 mx4sio content,
re-confirmed this round). Nearest in-family source is a *cousin*, not a pin: RiptOPL's
`modules/mx4sio_bd` (ps2sdk `iop/sio/mx4sio_bd` at a named commit + PR #936 retry fixes,
per its `ORIGIN.md`), whose own doc states it "does not replace POPStarter's separate
BDM Assault binaries". The other two MX4SIO builds in the family (POPSLoader's
`PS2SDK_MX4SIO/mx4sio_bd.irx` 15,089 B and SMS's `irx/mx4sio_bd.irx` 12,033 B) carry the
identical `MX4SIO v1.2` string set — three distinct builds of one driver vintage.

### 2.2 REV-006 / R7-REV-006 (tarball pins the shipped `usbd.irx`) — CORROBORATED quantitatively

Artefact: `POPSLoader/iop/embed/BDMASSAULT_MX4SIO/usbd.irx`, 48,500 B — byte-identical
(sha256 `5ea4818b…`, §3.1) to the variant shipped as `usbd.irx.ilink` / `.mx4sio` /
`.usbexfat` in both repos. Its distinctive format strings were searched against the
extracted tarball sources (`/tmp/bdma7/BDMAssault-mx4sio`, 119 files, still present):
of 22 long format strings in the binary, **11 appear verbatim** in the tarball C sources
(incl. `BDM_ASSAULT: starting Fatfs side`, found *only* in
`__bdm_assault/src/bdmfs/bdmfs_main.c`; `Block Device Manager (BDM) v%d.%d` in
`bdm/src/main.c` and its `__bdm_assault` twin; the GPT/FAT partition strings in
`bdm/src/part_driver_gpt.c`). The remaining BDM-core lines (`BDM: %s%dp%d mounted to %s`,
`BDM: BDM event thread running`, …) are present with the `BDM: ` prefix supplied by the
`M_PRINTF` macro (`libbdm/src/include/module_debug.h:8`:
`#define M_PRINTF(format, args...) printf("BDM: " format, ##args)`) over the identical
format bodies at `bdm/src/bdm.c:157,174` — i.e. all 22 are accounted for. The binary is
the merged-generation BDM-Assault build (USB host + BDM + FatFs in one IRX, entry 0),
exactly as the folder's README mapping describes. The pin stands, at string level as
round 7 left it — a full rebuild-and-compare remains impossible without the PS2 toolchain
(§6).

### 2.3 RiptOPL `modules/bdmassault/PROVENANCE.md` sha256 table — VERIFIED 9/9 (executed)

All nine documented hashes were recomputed from the working tree at the pin: **9/9
MATCH** (usbexfat pair, mx4sio usbhdfsd, mmce pair, ata pair, ilink pair). The document's
dedupe claim (`usbd.irx.mx4sio` ≡ `usbd.irx.ilink` ≡ `usbd.irx.usbexfat`, "all are copies
of `bdm_assault.irx`") is likewise confirmed by the §3.1 matrix. This is the family's one
complete binary provenance record — which is what makes its single omission (X-57)
visible.

### 2.4 SMS VU microprogram objects vs their shipped C arrays — IDENTICAL (executed, suspect dissolved)

`vu/{CSC1,CSC2h,CSC2v,CSC4,IDCT}.o` are **not ELF files** (`file`: data; readelf rejects
the magic) — they are raw VU microprogram binaries, the canonical in-repo form (their
`.s` sources are absent). `vu/build.sh` xz-compresses each and `bin2c`s it as `s_<NAME>`;
arrays under exactly those names ship in `src/SMS_JPEGData.c` (all five) with a size
descriptor table (`SMS_JPEGData.c:317-321`). Test: parse each C array's bytes,
`xz -dc`, byte-compare with the `.o`. **Result: 5/5 identical** (CSC1 668→1,232 B;
CSC2h 1,100→2,128 B; CSC2v 900→1,632 B; CSC4 980→1,872 B; IDCT 928→2,016 B). No drift;
the dual representation is the documented build.sh workflow, and the `.o` is the source
form — not a finding.

### 2.5 Consistency results (hash-join, executed)

- **udpfs trio** (`udpfs_ioman` 11,633 / `ministack` 5,025 / `smap` 8,081): one binary
  each across Launchstation `iop/__precompiled/`, POPSLoader `iop/embed/`, and RiptOPL's
  Example-tree neutrino set — three repos, one Neutrino prebuilt, provenance stories
  consistent. SMS's trio (11,393 / 3,785 / 7,457) is distinct, matching its in-repo
  `iop/SMSUdpfs` fork.
- **POPStarter IOP set** (SMSUTILS 1,305 / poweroff 3,413 / ps2dev9 11,505 / ps2ip
  109,497 / ps2smap 12,605 / smbman 44,329 / PATCH_5.BIN 327,360): byte-identical across
  POPSLoader's three locations and RiptOPL's two ship trees.
- **SMS plain↔xz pairs:** all 19 plain `.irx` are byte-identical to their `.irx.xz`
  payloads (§2 method: decompress + sha256). The pairs are *consistent* — X-54 is about
  the plain half having no reason to exist, not about drift.
- **Launchstation `__v10` pair** (ps2dev9 13,193 / ps2ip 118,513) are genuinely different
  vintages from the POPStarter set's same-named modules — consistent with the directory's
  declared PS2SDK-v1.0 provenance and its `ps2.yaml` build role.

---

## 3. Matrices (executed)

### 3.1 BDMAssault variant family — 45 files, 9 distinct binaries

All files named `usbd.irx*` / `usbhdfsd.irx*` in RiptOPL (`modules/bdmassault/`,
`ship/POPS/`, Example `POPS/`) and POPSLoader (`bin/POPSLDR/`, `iop/embed/`), grouped by
md5 (prefix shown; full sha256 in §5):

**`usbd.irx` side — 4 distinct binaries / 21 files**

| Binary (md5) | Size | Shipped as |
|---|---|---|
| `a77650a0ad` | 48,500 | embed `usbd.irx` (POPSLoader); `.ilink`, `.mx4sio`, `.usbexfat` (both repos) |
| `4b080d785f` | 42,749 | `.ata` (both repos) |
| `bb108a7ce1` | 11,841 | `.mmce` (both repos) |
| `7fbeb97bc1` | 61,949 | `.udpfs` (POPSLoader + RiptOPL `ship/` only — X-57) |

**`usbhdfsd.irx` side — 5 distinct binaries / 24 files**

| Binary (md5) | Size | Shipped as |
|---|---|---|
| `48677ae01b` | 14,993 | embed `usbhdfsd.irx` (POPSLoader); `.mx4sio` (both repos) — MX4SIO v1.2, §2.1 |
| `4cd51002d6` | 21,837 | `.ata` (both repos) |
| `2ea2f721d8` | 27,769 | `.ilink` (both repos; RiptOPL holds its source, `ilink_bd_assault/`) |
| `1e5152f4cf` | 19,733 | `.mmce` (both repos) |
| `ad9640d487` | 34,508 | `.usbexfat` **and** `.udpfs` — one binary, two mode names (X-57) |

Mode-suffix asymmetries (READ): RiptOPL's `modules/bdmassault/` lacks the `.udpfs` pair
and `usbd.irx.mx4sio`; the Example tree lacks only `.udpfs`. The mode suffix is a
deployment slot (the pair is pasted to `mc?:/POPSTARTER/` under the plain names at
launch, per RiptOPL's PROVENANCE.md), not a build claim — the two cases where one binary
carries two mode names are recorded in X-57 because neither is documented as a dedupe.

### 3.2 POPSTARTER.ELF variant family — one binary, one config dword (executed `cmp -l`)

All copies are 167,700 B, sectionless EE EXEC (single LOAD segment, offset 0x400 ↔
vaddr 0x100000). Pairwise differing-byte counts across the distinct hashes: **0, 1, or 2
bytes — never more.** Every difference sits in one dword at file offset **0x410**
(vaddr 0x100410, image head):

| Variant | byte @0x410 | byte @0x413 | Copies |
|---|---|---|---|
| **root `POPSTARTER.ELF` (the default)** | `0xFF` | `0x02` | POPSLoader ×1, RiptOPL ×2 trees |
| `DEBUG` | `0xFF` | `0x02` | POPSLoader ×1, RiptOPL ×2 trees — **byte-identical to root** |
| `MAIN` | `0x00` | `0x02` | POPSLoader ×1, RiptOPL ×2 trees |
| `USBDELAY` | `0x00` | `0x06` | POPSLoader ×1, RiptOPL ×2 trees |
| `USBDELAY_DEBUG` | `0xFF` | `0x06` | POPSLoader ×1, RiptOPL ×2 trees |
| `USBDELAY_LONGER_DEBUG` | `0xFF` | `0x09` | RiptOPL only ×2 trees |

String sets are identical across all variants (2,055 strings each, zero diff). The
@0x410 byte separates exactly the `DEBUG`-named variants (0xFF) from the non-debug ones
(0x00), and @0x413 grows monotonically with the delay names (2 → 6 → 9) — READ as bytes;
the *meanings* (debug flag / delay value) are INFERRED from that perfect name
correlation. Filed as X-55.

---

## 4. Findings

### X-54 / SMS checks in 18 IOP modules twice — the plain `.irx` copies are byte-identical to the `.irx.xz` payloads and nothing reads them / Category 1 (dead duplication), repo: Simple-Media-System
- **Location(s):** Simple-Media-System/irx/{IEEE1394_bd, ata_bd, bdm, filexio, iLinkman, iomanx, mcman, mcserv, mmcedrv, mmceman, mx4sio_bd, padman, sio2man, udpfs_ioman, udpfs_ministack, udpfs_smap, usbd, usbmass_bd}.irx — 18 files, **286,561 B** total. The one plain copy with a justification is *excluded*: `irx/bdmfs_fatfs.irx`, the reference file for the repo's own SHA-256 pin + xz-equality test (tools/test_bdmfs_fatfs_module.py:12-15).
- **Problem:** EXECUTED: every plain `.irx` in `irx/` is byte-identical (sha256) to the decompressed payload of the `.irx.xz` beside it (19/19 pairs incl. bdmfs_fatfs). The build embeds **only** the `.xz` form (Makefile:94 `vpath %.irx.xz`, :97-100 bin2c of the `.xz` via `tools/compress_irx.py`); CI's ABI gate runs on `.xz` files (`.github/workflows/compilation.yml:124`); a full-tree grep finds **no reference** to any plain path (`irx/mcman.irx`, `irx/usbd.irx`, `irx/padman.irx` — zero hits outside the `.xz` forms, in code, scripts, workflows, tests, or docs). The repo's own convention says raw copies are intermediates, not artefacts: `tools/compress_irx.py:15` notes smbman deliberately keeps "no raw irx/smbman.irx here", and the libsd rebuild (`tools/build_libsd.sh`) produces a raw `irx/libsd.irx` transiently yet none is tracked — libsd, ds34bt, ds34usb, bdmfs_vfat and smbman exist *only* as `.xz`. The 18 tracked plain files are leftover intermediates that every module update must now regenerate in lockstep with the `.xz` (git history shows the pairs moving together, e.g. `4b3193b`, `d353453`) — two copies to keep in sync, one of which ships.
- **Fix:** Delete the 18 plain `.irx` files; keep `irx/bdmfs_fatfs.irx` (pin-test reference) and all `.irx.xz`. Anyone needing a raw module runs `xz -dc <name>.irx.xz` — the payloads are proven identical, so nothing is lost.
- **Benefit:** −286,561 B of tracked duplication and one whole synchronisation obligation removed from every future module update; the `irx/` directory then shows exactly what ships.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED — payload equality, Makefile rule, workflow and full-tree reference greps all cited; the bdmfs_fatfs exception is the repo's own test)

### X-55 / The POPSTARTER "versions" are one binary patched in a single dword — and the default ELF is the DEBUG-flagged build / Category 8 (redundant feature presentation) / 1, cross-repo: POPSLoader + RiptOPL
- **Location(s):** POPSLoader/bin/POPSLDR/POPSTARTER.ELF + bin/POPSLDR/PROFILES/{DEBUG, MAIN, USBDELAY, USBDELAY_DEBUG}/POPSTARTER.ELF; RiptOPL/ship/POPS/POPSTARTER.ELF + ship/POPS/POPSTARTER VERSIONS/{DEBUG, MAIN, USBDELAY, USBDELAY_DEBUG, USBDELAY_LONGER_DEBUG}/POPSTARTER.ELF; both duplicated again in RiptOPL's Example tree. Matrix: §3.2.
- **Problem:** EXECUTED (`cmp -l`, all pairs): the distinct variants differ by 1–2 bytes, all inside the dword at file offset 0x410. The folder named `DEBUG` is **byte-identical to the root `POPSTARTER.ELF`** in both repos (one sha256, 6 copies) — so (a) one 167,700 B copy per repo tree is pure redundancy, and (b) the ELF in the default slot carries the 0xFF byte that perfectly correlates with the DEBUG-named variants, while the debug-off build (`MAIN`, 0x00) exists only inside the versions folder. A user who "switches to the DEBUG build" changes nothing; a user who never opens the folder runs the debug-flagged build by default. Which direction upstream POPStarter intends cannot be settled from these repos (INFERRED: the layout is inherited from the upstream distribution both repos mirror) — but the identity, and its consequence, are facts of the shipped bytes.
- **Fix:** Drop the duplicate `DEBUG` copies (or replace the folder entry with a one-line note that DEBUG ≡ the root ELF). Separately, decide deliberately which flag byte the default slot should carry — if the default is meant to be the release build, the root file should be the `MAIN` bytes; either way the choice should be a decision, not an inheritance. No code involved.
- **Benefit:** −167,700 B per tree (×3 trees across the two repos) and a default artefact whose debug state is chosen rather than accidental; the versions folder then contains only genuinely different bytes.
- **Effort:** S · **Risk:** Low (deleting a byte-identical copy); Med for changing the default slot's flag byte — that half needs the maintainer's call on POPStarter's intent · **Confidence:** High on the byte facts (EXECUTED); Medium on the inherited-layout explanation (INFERRED)

### X-56 / RiptOPL's `drvtif-ingame.irx` has been a byte-copy of `drvtif.irx` since its introduction — the in-game DECI2 flavour embeds the UI module / Category 8 / 1, repo: RiptOPL
- **Location(s):** RiptOPL/modules/debug/drvtif.irx and RiptOPL/modules/debug/drvtif-ingame.irx (both 5,985 B, md5 `838e4e7adf…`); build wiring at Makefile:310 (`EE_OBJS += … drvtif_irx.o …`, UI flavour) and Makefile:342 (`IOP_OBJS += drvtif_ingame_irx.o …`, in-game flavour), externs at include/extern_irx.h:36,38.
- **Problem:** EXECUTED (sha256 + git archaeology): the pair is byte-identical at the pin, and was already byte-identical at the *only* commit that ever touched the `-ingame` file, `1f16be79` — whose message is about making DECI2 work differently in the two flavours. The sibling pair from the same directory behaves as the naming promises: `tifinet.irx` (md5 `f212f485…`) ≠ `tifinet-ingame.irx` (md5 `6c52a13f…`), at introduction and today. So one of two things is true: either a distinct in-game drvtif exists in Sony's DECI2 kit and this repo ships a placeholder copy (in-game debugging silently loads the UI variant), or drvtif is genuinely mode-independent — in which case one file, one bin2c rule and one extern are dead duplication carried in both debug flavours. No source exists anywhere to settle which (Sony debug modules, external by nature).
- **Fix:** Check the pair against the DECI2 SDK originals. If a distinct `-ingame` drvtif exists, vendor it (replacing the copy). If the originals are themselves identical, delete `drvtif-ingame.irx` and point both Makefile rules at the one file.
- **Benefit:** Either a real in-game debug variant where a copy now sits, or −5,985 B and one rule/extern pair removed with proof the dedupe is safe.
- **Effort:** S · **Risk:** Low for the check; Med for acting before the originals are consulted · **Confidence:** High on identity + history (EXECUTED/READ); Medium on which of the two explanations holds (INFERRED — the tifinet asymmetry is the evidence)

### X-57 / The BDMAssault `.udpfs` pair ships in both repos with no provenance record anywhere — and one half is an undocumented second name for the documented usbexfat bytes / Category 7, cross-repo: POPSLoader + RiptOPL
**Verification note (2026-11-14, full verification): WITHDRAWN — REFUTED on adversarial re-derivation: the headline is false as filed — POPSLoader's `docs/third_party/okeanos_udpfs/PROVENANCE.json:12,17` records both .udpfs files by name with hashes, and STATE.md / docs/UDPFS_BDMA.md document their origin; the surviving residue (RiptOPL's own BDMAssault PROVENANCE.md omits the pair) is filed as X-59; see Sable-VERIFY2-CROSS.md. Do not act on this finding as filed.**
- **Location(s):** POPSLoader/bin/POPSLDR/usbd.irx.udpfs (61,949 B, sha256 `d1d55024…`) + usbhdfsd.irx.udpfs (34,508 B, sha256 `70a369e4…`); RiptOPL/ship/POPS/usbd.irx.udpfs + usbhdfsd.irx.udpfs (byte-identical copies). Absent from: RiptOPL/modules/bdmassault/ (the modules tree has no `.udpfs` files) and from RiptOPL/modules/bdmassault/PROVENANCE.md's table (9 rows, verified accurate in §2.3 — no udpfs row).
- **Problem:** EXECUTED (hash matrix §3.1): the family's provenance situation is inverted. The canonical bytes live in POPSLoader, which records nothing about them in-repo (no provenance doc for the 24 bin/POPSLDR variant files; the embed pair's README covers deployment mapping only). The one real record was written *downstream* by RiptOPL, which vendored the bytes *from* POPSLoader — and even it omits the `.udpfs` pair entirely, although RiptOPL ships both files in `ship/POPS/`. The two halves fail differently: `usbd.irx.udpfs` is a **distinct binary found nowhere else** (61,949 B; strings mark it as the udpfs-mode merged build) with no source, hash, or origin recorded in either repo; `usbhdfsd.irx.udpfs` is **byte-identical to the documented `usbhdfsd.irx.usbexfat`** — a second deployment name for known bytes, undocumented as a dedupe (RiptOPL's doc carefully documents the *usbd* dedupe and its re-vendor procedure, then doesn't mention this one). If the udpfs usbd build ever needs re-vendoring or auditing, nothing in either repo says what it is.
- **Fix:** Extend RiptOPL's PROVENANCE.md table with the two udpfs rows (the usbd hash above; the usbhdfsd row noting identity with the usbexfat build) and record their origin the same way the ata pair's is recorded; mirror the two files into `modules/bdmassault/` if the set is meant to be complete there, or note why they are ship-only. In POPSLoader, the embed/bin variant set needs at minimum a pointer to that record. Words in one doc — no new machinery.
- **Benefit:** The last two undocumented binaries in an otherwise fully-pinned family get the same treatment the other nine already have; the re-vendor procedure in PROVENANCE.md becomes complete as written.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED — hashes, tree census, and the doc's full text all read; the pair's *origin* beyond "udpfs-mode BDMAssault build" is INFERRED from strings)

---

## 5. Complete binary inventory

206 tracked artefacts. "Source counterpart" names an in-repo source/build path where one
exists; external upstreams are named as provenance, with NONE meaning no source in that
repo. SMS `.irx.xz` payload hashes equal their plain twins' (X-54 evidence) and are not
repeated. The KELF row is hash-only by rule (see tooling statement).

### Inventory — RiptOPL (108 files, 7,985,914 B)

| Path | Size (B) | SHA-256 | Identified as | Source counterpart |
|---|---|---|---|---|
| `modules/bdmassault/usbd.irx.ata` | 42749 | `4e1d39365854747117a08f8a8d843937614590ea072cf2b70f6e4c2ebbf3c6ee` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `modules/bdmassault/usbd.irx.ilink` | 48500 | `5ea4818ba1cf5207f6d7cadb4c13b5afa88c37c260750c21155b079a8c18f369` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `modules/bdmassault/usbd.irx.mmce` | 11841 | `0fed25d9eecdd263d4617ad5c8eeb2c5307c799aa97962b62b40a0e63e3adac8` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `modules/bdmassault/usbd.irx.usbexfat` | 48500 | `5ea4818ba1cf5207f6d7cadb4c13b5afa88c37c260750c21155b079a8c18f369` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `modules/bdmassault/usbhdfsd.irx.ata` | 21837 | `1cc865cd09997bd708e9e102c0f0f1f17f352b7844b282fcfa6a00f38609db9c` | BDMAssault per-mode BDM driver build | documented in RiptOPL modules/bdmassault/PROVENANCE.md (mmce upstream source unpinned per that doc) |
| `modules/bdmassault/usbhdfsd.irx.ilink` | 27769 | `9cd849ea7f06d72f3ee6015032dfd91d6fcb1332e87d5acde306cb42b5d4313d` | i.Link BDM driver (IEEE1394/SBP-2) | in-repo source: modules/bdmassault/ilink_bd_assault (RiptOPL copy only) |
| `modules/bdmassault/usbhdfsd.irx.mmce` | 19733 | `9f7b77848935f0d8e9bd792b997910777352f8d480dc32d99a04e6e8653779ab` | BDMAssault per-mode BDM driver build | documented in RiptOPL modules/bdmassault/PROVENANCE.md (mmce upstream source unpinned per that doc) |
| `modules/bdmassault/usbhdfsd.irx.mx4sio` | 14993 | `61525fab3b340aaef467eb3a08ce16e35aca98fe742982a7a151c5c7e1ffa00a` | MX4SIO v1.2 BDM driver (POPSLOADER-069, verified §2.1) | NONE — POPSLOADER-069 |
| `modules/bdmassault/usbhdfsd.irx.usbexfat` | 34508 | `70a369e47745e7f995fa771edbbfed086727b759fba915a7070c0fbcf061dd34` | BDMAssault per-mode BDM driver build | documented in RiptOPL modules/bdmassault/PROVENANCE.md (mmce upstream source unpinned per that doc) |
| `modules/debug/deci2.img` | 73625 | `c2a1b66fd3dc4888e506907b105842ca855d5a28f53abb4cd6d2aa238e55cd81` | Sony DECI2 IOP boot image (ROMIMG build 20170610) | NONE — Sony debug, external |
| `modules/debug/drvtif-ingame.irx` | 5985 | `66ed2eb23a138c80f842cf1328dee6026753cfb5a9fbac2e1cc32133e2c2708b` | Sony DECI2 TIF driver IRX — pair byte-identical, see X-56 | NONE — Sony debug, external |
| `modules/debug/drvtif.irx` | 5985 | `66ed2eb23a138c80f842cf1328dee6026753cfb5a9fbac2e1cc32133e2c2708b` | Sony DECI2 TIF driver IRX — pair byte-identical, see X-56 | NONE — Sony debug, external |
| `modules/debug/tifinet-ingame.irx` | 3301 | `4590da5ee041ba82952d641d85b1eb829216fc3fd27e0b6a8ad3f3570f926dee` | Sony DECI2 network TIF IRX | NONE — Sony debug, external |
| `modules/debug/tifinet.irx` | 3301 | `20bc15bf38675aa036cb1ab82ef30e86c6e2fbeae08e422af8e913dafbfb8ac7` | Sony DECI2 network TIF IRX | NONE — Sony debug, external |
| `modules/iopcore/IOPRP.img` | 244 | `dac3efe01ec4522ce8ff6bbf691edc20b1932638d2209cedb552a5da198e825a` | ROMDIR-only IOP image stub (directory entries, zero-length payloads) | in-repo consumer: modules/iopcore |
| `ship/EMBER/ember.elf` | 1611956 | `94f8b2576010405e2f7b90c4a1adde073ddaebe2d0aec34e0bc2be7951d34295` | Ember 2 EE ELF, (c) 2026 Gageformer, beta licence — identification only, not disassembled | NONE — external Ember project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/APPS/APP_RIPTOPL/RIPTOPL.ELF` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 0-byte placeholder in the SAS example app folder | n/a — template slot for the user's own build |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/EMBER/ember.elf` | 1611956 | `94f8b2576010405e2f7b90c4a1adde073ddaebe2d0aec34e0bc2be7951d34295` | Ember 2 EE ELF, (c) 2026 Gageformer, beta licence — identification only, not disassembled | NONE — external Ember project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/PATCH_5.BIN` | 327360 | `55a60ea7e0da08d615e1dcd77c4a8da546603ee4d1a5ff5564259405c0b40d42` | IPS patch file (POPStarter) | NONE |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/POPSTARTER VERSIONS/DEBUG/POPSTARTER.ELF` | 167700 | `3ec327085eccd62578a453e3deedf3ba35f19cd7d332aedaffdc7926c73876b8` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project (family home: POPSLoader) |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/POPSTARTER VERSIONS/MAIN/POPSTARTER.ELF` | 167700 | `734c813e8e8ec2c6729ec5e15dd46ab696e90deeade8d0b2ca3ad03782781aa1` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project (family home: POPSLoader) |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/POPSTARTER VERSIONS/USBDELAY/POPSTARTER.ELF` | 167700 | `613b16e1823a154d0e468e0a686aad02823fea9d876d91d86131382fa6d42d01` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project (family home: POPSLoader) |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/POPSTARTER VERSIONS/USBDELAY_DEBUG/POPSTARTER.ELF` | 167700 | `9bab715aa17f39981af2ad68c107b74d79817336bde79afaf72f22e0f6812e0e` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project (family home: POPSLoader) |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/POPSTARTER VERSIONS/USBDELAY_LONGER_DEBUG/POPSTARTER.ELF` | 167700 | `bb697bea1d7ede1a8e4d211442d8bb762fff42372a94f03ccd61a960f4845a18` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project (family home: POPSLoader) |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/POPSTARTER.ELF` | 167700 | `3ec327085eccd62578a453e3deedf3ba35f19cd7d332aedaffdc7926c73876b8` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project (family home: POPSLoader) |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/POPSTARTER.KELF` | 167708 | `c91fb9a3707a299c072cfa00a650be59d3b3bf4f339aeca0cacdef2870f25892` | POPStarter KELF — hash-only row, contents not analysed (audit rule 3) | NONE |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/SMSUTILS.irx` | 1305 | `91daae46a300138218bfd6a876a1b5012594412b71c2eebf6eadfb70fde38e1b` | POPStarter IOP module set member (== POPSLoader copies) | NONE in RiptOPL — POPStarter distribution |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/TROJAN_7.BIN` | 836 | `0a491847423521d1894278c6d4664ba5b37f853d5356d14508964859d8ae1840` | POPStarter patch data | NONE |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/poweroff.irx` | 3413 | `573863a0f9b213b6f53f2eeaf074745b27b9c4d52dfddeaff8f0b112632cb504` | POPStarter IOP module set member (== POPSLoader copies) | NONE in RiptOPL — POPStarter distribution |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/ps2dev9.irx` | 11505 | `e2b83bb01a5904b3f4360e23fd7cfc07a2a11eaa413c1808961432dced80119c` | POPStarter IOP module set member (== POPSLoader copies) | NONE in RiptOPL — POPStarter distribution |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/ps2ip.irx` | 109497 | `1bf99ca297dcca410bccce14b8efa00f5efc536359e3e34be50edf0043c867b9` | POPStarter IOP module set member (== POPSLoader copies) | NONE in RiptOPL — POPStarter distribution |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/ps2smap.irx` | 12605 | `671fe9e3c5e0e735fb3ea3b81a8ea39898bd0fafbdacbf9ca7fa11fff391df8d` | POPStarter IOP module set member (== POPSLoader copies) | NONE in RiptOPL — POPStarter distribution |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/smbman.irx` | 44329 | `000296a2f03073dffd2f87a6f3eae249a1f83c2213ffb0ae25bad67b970ebed0` | POPStarter IOP module set member (== POPSLoader copies) | NONE in RiptOPL — POPStarter distribution |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbd.irx.ata` | 42749 | `4e1d39365854747117a08f8a8d843937614590ea072cf2b70f6e4c2ebbf3c6ee` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbd.irx.mmce` | 11841 | `0fed25d9eecdd263d4617ad5c8eeb2c5307c799aa97962b62b40a0e63e3adac8` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbd.irx.mx4sio` | 48500 | `5ea4818ba1cf5207f6d7cadb4c13b5afa88c37c260750c21155b079a8c18f369` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbd.irx.usbexfat` | 48500 | `5ea4818ba1cf5207f6d7cadb4c13b5afa88c37c260750c21155b079a8c18f369` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbhdfsd.irx.ata` | 21837 | `1cc865cd09997bd708e9e102c0f0f1f17f352b7844b282fcfa6a00f38609db9c` | BDMAssault per-mode BDM driver build | documented in RiptOPL modules/bdmassault/PROVENANCE.md (mmce upstream source unpinned per that doc) |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbhdfsd.irx.mmce` | 19733 | `9f7b77848935f0d8e9bd792b997910777352f8d480dc32d99a04e6e8653779ab` | BDMAssault per-mode BDM driver build | documented in RiptOPL modules/bdmassault/PROVENANCE.md (mmce upstream source unpinned per that doc) |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbhdfsd.irx.mx4sio` | 14993 | `61525fab3b340aaef467eb3a08ce16e35aca98fe742982a7a151c5c7e1ffa00a` | MX4SIO v1.2 BDM driver (POPSLOADER-069, verified §2.1) | NONE — POPSLOADER-069 |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/usbhdfsd.irx.usbexfat` | 34508 | `70a369e47745e7f995fa771edbbfed086727b759fba915a7070c0fbcf061dd34` | BDMAssault per-mode BDM driver build | documented in RiptOPL modules/bdmassault/PROVENANCE.md (mmce upstream source unpinned per that doc) |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/IEEE1394_bd_mini.irx` | 6953 | `3e8ff11f55d7b2b8a783e5c01f6f3327fd15a255dd5a2c9c9a057ca6a5fe99d6` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/ata_bd.irx` | 12613 | `1754a427b5ff332af47fe87e981588bbca1dddbaf0a48d7edb251b9c159d4733` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/atad_emu.irx` | 1769 | `255e14974916ac52b4e47ded08c9d4ac196040e02428b8b0ff7feac0943e527f` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/bdfs.irx` | 2961 | `2a9a4970680eeb6fa553e665669985815c0b466d60f88b9c99b42088edb873ac` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/bdm.irx` | 9345 | `dc3f4a074745568a30dc07450510e23dfafc6a4b2b1897ee0dde275f8b90ebf0` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/bdmfs_fatfs.irx` | 39845 | `a3161d83fd4716f7bcb5edf4fca92cd7210c32035913091a2a926a5f686a38f2` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/cdvdfsv.irx` | 8557 | `5cf2a670a33d946b8dd684ab7a04ba595b448fcd96042b8eae5d388eaf63b2a5` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/cdvdman_emu.irx` | 24365 | `d26ae5dcb9ac397c3efa21f0946f88bcbc188099bc949bc53d211135bcd681de` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/cdvdman_esr1.irx` | 3749 | `6ba277891b9804e898cbead17ac7e3ed590058e3a3db81987a3ceaf023a68dca` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/cdvdman_esr2.irx` | 4449 | `d8c12ad8a7c022f17304f6ccc2122877d55947f079eefcf7b95e95390cdfdb3e` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/dev9_hidden.irx` | 11065 | `3f2801f900cb13b6c88b4acac27a38cfb11823a13ed51a9249aadb7a76ca7b36` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/dev9_ns.irx` | 11273 | `5cdd4539464a2fe92d95d93692239c2bc80b9a99f0d7644d18ae66b756c68201` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/ee_core.elf` | 25568 | `3e547a15939702e99111ce6e6f7ee84629a52d5243d48bfca3f611aefef5abcf` | Neutrino EE ELF (loader/core) | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/eesync.irx` | 1137 | `c31b23ead73a77004b081973e1e8cab0bc617b1ab34471b02f38dcf937ed60e2` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/fakemod.irx` | 4065 | `4f584dcc47fb3973fbf2676b828cae7dfd401607c59f7c6c8254fac949722da8` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/fhi_bd.irx` | 4457 | `747c226beab121e980570034e29ae09177702ff97146ba07c836fc9675481fc5` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/fileXio.irx` | 6413 | `6109d36dd2098f89e9b734e4f52d443ebd0b21394194ce30e113994fdecac07e` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/hdlfs.irx` | 3617 | `5220d68059714f39d6f04e4de9d006102083997eb05f9f32f9c9f53f6eebd108` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/iLinkman.irx` | 13857 | `c31bed5555c2856347c476749747ef42c3c5d112f7a8661111d4c9905fd9f64f` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/imgdrv.irx` | 1177 | `801c7ebbd4e00783475474b174dc4393b18b2e33440fc770477de77422d0fff5` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/iomanX.irx` | 11865 | `9e58ceb35871880a20f283defaffee41c530c26ac471110927d16b41f3db3f32` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/mc_emu.irx` | 10389 | `cadf95092331d878403753a4cb58a0734f4f51233b47ab01bcd8090c94f4d77a` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/ministack.irx` | 5025 | `854060627190264dd5cf647cf3468535a7ea3aa4f3544bf30f654bb25d8b8280` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/mmcefhi.irx` | 13017 | `93be021b68edb2ffcb5a7fb9df985d10ddb4dd534e90815e88b226d868300fbf` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/mmceman.irx` | 19809 | `29732d6b1d069f7a2a5ceca4caea647219db30536ef0b4cb2de600ff96b4fcfd` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/mx4sio_bd_mini.irx` | 13849 | `b1903a3f09e6d1ef4a8362b743f69691048519bc61dea04c2fef8379f327bb8f` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/patch_freemem.irx` | 1969 | `1b25beeb412ec2e3d8ba969f59e9916d4d90ca45370d50a8b180ba91734fb6f3` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/patch_membo.irx` | 1641 | `5f573a4e06b9e564bf114ff6e9c2bbd33688974748649fa5d6b78f5540325d85` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/patch_rc_uya.irx` | 1449 | `69a575e6696bf16b746f233ce44ca3827351953c54fe8094f558c7b091ea8d8c` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/ps2hdd-bdm.irx` | 27269 | `2e83b26d45c6b9c80aef9954b44ba80a3b7e5ba09eff4a56fa416da52cdabdca` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/smap.irx` | 8081 | `4b81d9bf0c176d3291258eb97f6188a2bb935a69ae4cba13546b51d603ee1a09` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/udnl-t300.irx` | 7729 | `9fa81b08a24181eaa913e030da32c222f9ee415e7a5e0355c81ee3eace9a3461` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/udnl.irx` | 6249 | `cce12140564770055d68dca2efd70493ad30f6a5b51f2225e696dac7741038e6` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/udpbd.irx` | 4377 | `1b0d5cceb804e91a81d9a283f9337b3beaed2c81c6b9b8c6d106c2c23a8d90b8` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/udpfs_bd.irx` | 7897 | `04f3517f0b37a002482350d75aac04b41bc221737e7a4e46c6c8446d0ecf359e` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/udpfs_fhi.irx` | 7949 | `cca1ea131dda6aa6cfec7df8e1b0d7e1008df94c0372675ddc019281ef788f40` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/udpfs_ioman.irx` | 11633 | `85faad5631fa7b2e57548ea35fe752c368163ffc4074eb6c3e9742187501c242` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/usbd_mini.irx` | 23781 | `e2463f7bde271691579ef40b37eb3e211e65dbc2518b46227beec6729893a53c` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/modules/usbmass_bd_mini.irx` | 8225 | `765ee67c37a90a6c1e3642a298cdc212dd2fe1bf666ed996a836ea1d22f89722` | Neutrino IOP module | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/neutrino/neutrino.elf` | 74404 | `240517c0568edd8d267bb17d8fff0457abc7d8e61a9f2cd06eba31207de1c511` | Neutrino EE ELF (loader/core) | NONE — Neutrino project |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/usbd.irx.ilink` | 48500 | `5ea4818ba1cf5207f6d7cadb4c13b5afa88c37c260750c21155b079a8c18f369` | binary artefact (see §2/§3 notes) | NONE — external |
| `ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/usbhdfsd.irx.ilink` | 27769 | `9cd849ea7f06d72f3ee6015032dfd91d6fcb1332e87d5acde306cb42b5d4313d` | binary artefact (see §2/§3 notes) | NONE — external |
| `ship/POPS/PATCH_5.BIN` | 327360 | `55a60ea7e0da08d615e1dcd77c4a8da546603ee4d1a5ff5564259405c0b40d42` | IPS patch file (POPStarter) | NONE |
| `ship/POPS/POPSTARTER VERSIONS/DEBUG/POPSTARTER.ELF` | 167700 | `3ec327085eccd62578a453e3deedf3ba35f19cd7d332aedaffdc7926c73876b8` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project (family home: POPSLoader) |
| `ship/POPS/POPSTARTER VERSIONS/MAIN/POPSTARTER.ELF` | 167700 | `734c813e8e8ec2c6729ec5e15dd46ab696e90deeade8d0b2ca3ad03782781aa1` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project (family home: POPSLoader) |
| `ship/POPS/POPSTARTER VERSIONS/USBDELAY/POPSTARTER.ELF` | 167700 | `613b16e1823a154d0e468e0a686aad02823fea9d876d91d86131382fa6d42d01` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project (family home: POPSLoader) |
| `ship/POPS/POPSTARTER VERSIONS/USBDELAY_DEBUG/POPSTARTER.ELF` | 167700 | `9bab715aa17f39981af2ad68c107b74d79817336bde79afaf72f22e0f6812e0e` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project (family home: POPSLoader) |
| `ship/POPS/POPSTARTER VERSIONS/USBDELAY_LONGER_DEBUG/POPSTARTER.ELF` | 167700 | `bb697bea1d7ede1a8e4d211442d8bb762fff42372a94f03ccd61a960f4845a18` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project (family home: POPSLoader) |
| `ship/POPS/POPSTARTER.ELF` | 167700 | `3ec327085eccd62578a453e3deedf3ba35f19cd7d332aedaffdc7926c73876b8` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project (family home: POPSLoader) |
| `ship/POPS/SMSUTILS.irx` | 1305 | `91daae46a300138218bfd6a876a1b5012594412b71c2eebf6eadfb70fde38e1b` | POPStarter IOP module set member (== POPSLoader copies) | NONE in RiptOPL — POPStarter distribution |
| `ship/POPS/poweroff.irx` | 3413 | `573863a0f9b213b6f53f2eeaf074745b27b9c4d52dfddeaff8f0b112632cb504` | POPStarter IOP module set member (== POPSLoader copies) | NONE in RiptOPL — POPStarter distribution |
| `ship/POPS/ps2dev9.irx` | 11505 | `e2b83bb01a5904b3f4360e23fd7cfc07a2a11eaa413c1808961432dced80119c` | POPStarter IOP module set member (== POPSLoader copies) | NONE in RiptOPL — POPStarter distribution |
| `ship/POPS/ps2ip.irx` | 109497 | `1bf99ca297dcca410bccce14b8efa00f5efc536359e3e34be50edf0043c867b9` | POPStarter IOP module set member (== POPSLoader copies) | NONE in RiptOPL — POPStarter distribution |
| `ship/POPS/ps2smap.irx` | 12605 | `671fe9e3c5e0e735fb3ea3b81a8ea39898bd0fafbdacbf9ca7fa11fff391df8d` | POPStarter IOP module set member (== POPSLoader copies) | NONE in RiptOPL — POPStarter distribution |
| `ship/POPS/smbman.irx` | 44329 | `000296a2f03073dffd2f87a6f3eae249a1f83c2213ffb0ae25bad67b970ebed0` | POPStarter IOP module set member (== POPSLoader copies) | NONE in RiptOPL — POPStarter distribution |
| `ship/POPS/usbd.irx.ata` | 42749 | `4e1d39365854747117a08f8a8d843937614590ea072cf2b70f6e4c2ebbf3c6ee` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `ship/POPS/usbd.irx.ilink` | 48500 | `5ea4818ba1cf5207f6d7cadb4c13b5afa88c37c260750c21155b079a8c18f369` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `ship/POPS/usbd.irx.mmce` | 11841 | `0fed25d9eecdd263d4617ad5c8eeb2c5307c799aa97962b62b40a0e63e3adac8` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `ship/POPS/usbd.irx.mx4sio` | 48500 | `5ea4818ba1cf5207f6d7cadb4c13b5afa88c37c260750c21155b079a8c18f369` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `ship/POPS/usbd.irx.udpfs` | 61949 | `d1d5502454fbc9ca7c1fd039b65bbc143f8b87ffdfc0e275ce13dca4b191a738` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `ship/POPS/usbd.irx.usbexfat` | 48500 | `5ea4818ba1cf5207f6d7cadb4c13b5afa88c37c260750c21155b079a8c18f369` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | POPSLoader-checked-in bytes per modules/bdmassault/PROVENANCE.md; tarball family (REV-006) |
| `ship/POPS/usbhdfsd.irx.ata` | 21837 | `1cc865cd09997bd708e9e102c0f0f1f17f352b7844b282fcfa6a00f38609db9c` | BDMAssault per-mode BDM driver build | documented in RiptOPL modules/bdmassault/PROVENANCE.md (mmce upstream source unpinned per that doc) |
| `ship/POPS/usbhdfsd.irx.ilink` | 27769 | `9cd849ea7f06d72f3ee6015032dfd91d6fcb1332e87d5acde306cb42b5d4313d` | i.Link BDM driver (IEEE1394/SBP-2) | in-repo source: modules/bdmassault/ilink_bd_assault (RiptOPL copy only) |
| `ship/POPS/usbhdfsd.irx.mmce` | 19733 | `9f7b77848935f0d8e9bd792b997910777352f8d480dc32d99a04e6e8653779ab` | BDMAssault per-mode BDM driver build | documented in RiptOPL modules/bdmassault/PROVENANCE.md (mmce upstream source unpinned per that doc) |
| `ship/POPS/usbhdfsd.irx.mx4sio` | 14993 | `61525fab3b340aaef467eb3a08ce16e35aca98fe742982a7a151c5c7e1ffa00a` | MX4SIO v1.2 BDM driver (POPSLOADER-069, verified §2.1) | NONE — POPSLOADER-069 |
| `ship/POPS/usbhdfsd.irx.udpfs` | 34508 | `70a369e47745e7f995fa771edbbfed086727b759fba915a7070c0fbcf061dd34` | BDMAssault BDM driver — byte-identical to the documented .usbexfat build under a second, undocumented name (X-57) | NONE — undocumented in both repos (X-57) |
| `ship/POPS/usbhdfsd.irx.usbexfat` | 34508 | `70a369e47745e7f995fa771edbbfed086727b759fba915a7070c0fbcf061dd34` | BDMAssault per-mode BDM driver build | documented in RiptOPL modules/bdmassault/PROVENANCE.md (mmce upstream source unpinned per that doc) |

### Inventory — Launchstation (9 files, 217,128 B)

| Path | Size (B) | SHA-256 | Identified as | Source counterpart |
|---|---|---|---|---|
| `exploits/IOPRP.IMG` | 15741 | `7d814c36d9ef83cb1a28a5fa38f046474cfcc7b8429b20cf438c0a082ecbeb54` | custom IOP replacement image (ROMIMG; .IMG build 20180614, _LTS build 20230221) | NONE — Sony-derived, external build |
| `exploits/IOPRP_LTS.IMG` | 18652 | `f762474f2e5d533c70dc7539f4c013ae736e859b8fdee8128f4a1830f4434978` | custom IOP replacement image (ROMIMG; .IMG build 20180614, _LTS build 20230221) | NONE — Sony-derived, external build |
| `iop/__precompiled/udpfs_ioman.irx` | 11633 | `85faad5631fa7b2e57548ea35fe752c368163ffc4074eb6c3e9742187501c242` | udpfs IOP module, Neutrino prebuilt (== POPSLoader + RiptOPL copies) | NONE — Neutrino/udpfs prebuilt (iop/udpfs_smap holds source for the smap member only) |
| `iop/__precompiled/udpfs_ministack.irx` | 5025 | `854060627190264dd5cf647cf3468535a7ea3aa4f3544bf30f654bb25d8b8280` | udpfs IOP module, Neutrino prebuilt (== POPSLoader + RiptOPL copies) | NONE — Neutrino/udpfs prebuilt (iop/udpfs_smap holds source for the smap member only) |
| `iop/__precompiled/udpfs_smap.irx` | 8081 | `4b81d9bf0c176d3291258eb97f6188a2bb935a69ae4cba13546b51d603ee1a09` | udpfs IOP module, Neutrino prebuilt (== POPSLoader + RiptOPL copies) | NONE — Neutrino/udpfs prebuilt (iop/udpfs_smap holds source for the smap member only) |
| `iop/__v10/ps2dev9.irx` | 13193 | `962bedf3ab211424409026e16c21437ce9b41edad01d7bc505b5b9037f0b469e` | PS2SDK v1.0-era IOP module (build input per ps2.yaml) | NONE — PS2SDK |
| `iop/__v10/ps2ip.irx` | 118513 | `9489a007711bf2f93f9ec19b261c545a40064422890ea18f590b8aa391a04926` | PS2SDK v1.0-era IOP module (build input per ps2.yaml) | NONE — PS2SDK |
| `ship/neutrino-ilink/IEEE1394_bd_mini.irx` | 10577 | `958325d36a10cc6c4d33db60c9bee522085df9b5f88054eeae4b21f8245d9beb` | Neutrino i.Link IOP module (vintage differs from RiptOPL's copies) | NONE — Neutrino project |
| `ship/neutrino-ilink/iLinkman.irx` | 15713 | `1b0b27ea7f65b550dafac38a38c806f0e84227b244300701f41c69c8afb85ffc` | Neutrino i.Link IOP module (vintage differs from RiptOPL's copies) | NONE — Neutrino project |

### Inventory — POPSLoader (39 files, 2,105,703 B)

| Path | Size (B) | SHA-256 | Identified as | Source counterpart |
|---|---|---|---|---|
| `POPSTARTER/SMSUTILS.irx` | 1305 | `91daae46a300138218bfd6a876a1b5012594412b71c2eebf6eadfb70fde38e1b` | POPStarter IOP module set member | NONE — POPStarter distribution |
| `POPSTARTER/poweroff.irx` | 3413 | `573863a0f9b213b6f53f2eeaf074745b27b9c4d52dfddeaff8f0b112632cb504` | POPStarter IOP module set member | NONE — POPStarter distribution |
| `POPSTARTER/ps2dev9.irx` | 11505 | `e2b83bb01a5904b3f4360e23fd7cfc07a2a11eaa413c1808961432dced80119c` | POPStarter IOP module set member | NONE — POPStarter distribution |
| `POPSTARTER/ps2ip.irx` | 109497 | `1bf99ca297dcca410bccce14b8efa00f5efc536359e3e34be50edf0043c867b9` | POPStarter IOP module set member | NONE — POPStarter distribution |
| `POPSTARTER/ps2smap.irx` | 12605 | `671fe9e3c5e0e735fb3ea3b81a8ea39898bd0fafbdacbf9ca7fa11fff391df8d` | POPStarter IOP module set member | NONE — POPStarter distribution |
| `POPSTARTER/smbman.irx` | 44329 | `000296a2f03073dffd2f87a6f3eae249a1f83c2213ffb0ae25bad67b970ebed0` | POPStarter IOP module set member | NONE — POPStarter distribution |
| `bin/POPSLDR/PATCH_5.BIN` | 327360 | `55a60ea7e0da08d615e1dcd77c4a8da546603ee4d1a5ff5564259405c0b40d42` | IPS patch file (POPStarter) | NONE |
| `bin/POPSLDR/POPSTARTER.ELF` | 167700 | `3ec327085eccd62578a453e3deedf3ba35f19cd7d332aedaffdc7926c73876b8` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project |
| `bin/POPSLDR/PROFILES/DEBUG/POPSTARTER.ELF` | 167700 | `3ec327085eccd62578a453e3deedf3ba35f19cd7d332aedaffdc7926c73876b8` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project |
| `bin/POPSLDR/PROFILES/MAIN/POPSTARTER.ELF` | 167700 | `734c813e8e8ec2c6729ec5e15dd46ab696e90deeade8d0b2ca3ad03782781aa1` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project |
| `bin/POPSLDR/PROFILES/USBDELAY/POPSTARTER.ELF` | 167700 | `613b16e1823a154d0e468e0a686aad02823fea9d876d91d86131382fa6d42d01` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project |
| `bin/POPSLDR/PROFILES/USBDELAY_DEBUG/POPSTARTER.ELF` | 167700 | `9bab715aa17f39981af2ad68c107b74d79817336bde79afaf72f22e0f6812e0e` | POPStarter EE ELF — variant config word @0x410, see X-55 | NONE — POPStarter project |
| `bin/POPSLDR/popsmb/SMSUTILS.irx` | 1305 | `91daae46a300138218bfd6a876a1b5012594412b71c2eebf6eadfb70fde38e1b` | POPStarter IOP module set member | NONE — POPStarter distribution |
| `bin/POPSLDR/popsmb/poweroff.irx` | 3413 | `573863a0f9b213b6f53f2eeaf074745b27b9c4d52dfddeaff8f0b112632cb504` | POPStarter IOP module set member | NONE — POPStarter distribution |
| `bin/POPSLDR/popsmb/ps2dev9.irx` | 11505 | `e2b83bb01a5904b3f4360e23fd7cfc07a2a11eaa413c1808961432dced80119c` | POPStarter IOP module set member | NONE — POPStarter distribution |
| `bin/POPSLDR/popsmb/ps2ip.irx` | 109497 | `1bf99ca297dcca410bccce14b8efa00f5efc536359e3e34be50edf0043c867b9` | POPStarter IOP module set member | NONE — POPStarter distribution |
| `bin/POPSLDR/popsmb/ps2smap.irx` | 12605 | `671fe9e3c5e0e735fb3ea3b81a8ea39898bd0fafbdacbf9ca7fa11fff391df8d` | POPStarter IOP module set member | NONE — POPStarter distribution |
| `bin/POPSLDR/popsmb/smbman.irx` | 44329 | `000296a2f03073dffd2f87a6f3eae249a1f83c2213ffb0ae25bad67b970ebed0` | POPStarter IOP module set member | NONE — POPStarter distribution |
| `bin/POPSLDR/usbd.irx.ata` | 42749 | `4e1d39365854747117a08f8a8d843937614590ea072cf2b70f6e4c2ebbf3c6ee` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | tarball family (REV-006); mode names documented only in RiptOPL (X-57) |
| `bin/POPSLDR/usbd.irx.ilink` | 48500 | `5ea4818ba1cf5207f6d7cadb4c13b5afa88c37c260750c21155b079a8c18f369` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | tarball family (REV-006); mode names documented only in RiptOPL (X-57) |
| `bin/POPSLDR/usbd.irx.mmce` | 11841 | `0fed25d9eecdd263d4617ad5c8eeb2c5307c799aa97962b62b40a0e63e3adac8` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | tarball family (REV-006); mode names documented only in RiptOPL (X-57) |
| `bin/POPSLDR/usbd.irx.mx4sio` | 48500 | `5ea4818ba1cf5207f6d7cadb4c13b5afa88c37c260750c21155b079a8c18f369` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | tarball family (REV-006); mode names documented only in RiptOPL (X-57) |
| `bin/POPSLDR/usbd.irx.udpfs` | 61949 | `d1d5502454fbc9ca7c1fd039b65bbc143f8b87ffdfc0e275ce13dca4b191a738` | BDMAssault merged BDM build, udpfs mode — distinct binary, undocumented in both repos (X-57) | NONE — undocumented in both repos (X-57) |
| `bin/POPSLDR/usbd.irx.usbexfat` | 48500 | `5ea4818ba1cf5207f6d7cadb4c13b5afa88c37c260750c21155b079a8c18f369` | BDMAssault merged BDM build (bdm_assault) — variant matrix §3 | tarball family (REV-006); mode names documented only in RiptOPL (X-57) |
| `bin/POPSLDR/usbhdfsd.irx.ata` | 21837 | `1cc865cd09997bd708e9e102c0f0f1f17f352b7844b282fcfa6a00f38609db9c` | BDMAssault per-mode BDM driver build | NONE in POPSLoader — the family's only provenance record is downstream, in RiptOPL (X-57) |
| `bin/POPSLDR/usbhdfsd.irx.ilink` | 27769 | `9cd849ea7f06d72f3ee6015032dfd91d6fcb1332e87d5acde306cb42b5d4313d` | BDMAssault per-mode BDM driver build | NONE in POPSLoader — the family's only provenance record is downstream, in RiptOPL (X-57) |
| `bin/POPSLDR/usbhdfsd.irx.mmce` | 19733 | `9f7b77848935f0d8e9bd792b997910777352f8d480dc32d99a04e6e8653779ab` | BDMAssault per-mode BDM driver build | NONE in POPSLoader — the family's only provenance record is downstream, in RiptOPL (X-57) |
| `bin/POPSLDR/usbhdfsd.irx.mx4sio` | 14993 | `61525fab3b340aaef467eb3a08ce16e35aca98fe742982a7a151c5c7e1ffa00a` | MX4SIO v1.2 BDM driver (== embed copy) | NONE — POPSLOADER-069 |
| `bin/POPSLDR/usbhdfsd.irx.udpfs` | 34508 | `70a369e47745e7f995fa771edbbfed086727b759fba915a7070c0fbcf061dd34` | BDMAssault per-mode BDM driver build | NONE in POPSLoader — the family's only provenance record is downstream, in RiptOPL (X-57) |
| `bin/POPSLDR/usbhdfsd.irx.usbexfat` | 34508 | `70a369e47745e7f995fa771edbbfed086727b759fba915a7070c0fbcf061dd34` | BDMAssault per-mode BDM driver build | NONE in POPSLoader — the family's only provenance record is downstream, in RiptOPL (X-57) |
| `iop/embed/BDMASSAULT_MX4SIO/usbd.irx` | 48500 | `5ea4818ba1cf5207f6d7cadb4c13b5afa88c37c260750c21155b079a8c18f369` | BDMAssault merged BDM build (bdm_assault) — tarball pin verified §2.2 | in-repo tarball: iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz (REV-006) |
| `iop/embed/BDMASSAULT_MX4SIO/usbhdfsd.irx` | 14993 | `61525fab3b340aaef467eb3a08ce16e35aca98fe742982a7a151c5c7e1ffa00a` | MX4SIO v1.2 BDM driver — disassembly-verified §2.1 | NONE — POPSLOADER-069 |
| `iop/embed/PS2SDK_MX4SIO/mx4sio_bd.irx` | 15089 | `3185e57e0651ba60a37057670451e37735e6b3261ce97f95e4b0085991b63bf7` | MX4SIO v1.2 BDM driver, PS2SDK build | NONE in POPSLoader — ps2sdk upstream (forked source in RiptOPL modules/mx4sio_bd) |
| `iop/embed/ata_bd.irx` | 11917 | `16c5d9f00d64be5ea4848b53da89bb5f89a54004957bae47d01dee3c354742f4` | BDM ATA block-device IRX | in-repo source: iop/ata_bd_fast |
| `iop/embed/bdmfs_vfat.irx` | 30013 | `8536a93f3cd1ec9d1aa342861c6de817f55d4d28b43716bade3753ab3d494360` | BDM VFAT filesystem IRX | NONE — BDM/Neutrino family |
| `iop/embed/mx4sio_bd_mini.irx` | 13897 | `f7fd0c13ce008e3e016667207613ef71920190226d7511c34d6509de9de82292` | MX4SIO mini BDM driver | NONE — Neutrino family |
| `iop/embed/udpfs_ioman.irx` | 11633 | `85faad5631fa7b2e57548ea35fe752c368163ffc4074eb6c3e9742187501c242` | udpfs IOP module, Neutrino prebuilt (== Launchstation + RiptOPL copies) | NONE — Neutrino/udpfs prebuilt |
| `iop/embed/udpfs_ministack.irx` | 5025 | `854060627190264dd5cf647cf3468535a7ea3aa4f3544bf30f654bb25d8b8280` | udpfs IOP module, Neutrino prebuilt (== Launchstation + RiptOPL copies) | NONE — Neutrino/udpfs prebuilt |
| `iop/embed/udpfs_net_smap.irx` | 8081 | `4b81d9bf0c176d3291258eb97f6188a2bb935a69ae4cba13546b51d603ee1a09` | udpfs IOP module, Neutrino prebuilt (== Launchstation + RiptOPL copies) | NONE — Neutrino/udpfs prebuilt |

### Inventory — Simple-Media-System (50 files, 548,826 B)

| Path | Size (B) | SHA-256 | Identified as | Source counterpart |
|---|---|---|---|---|
| `docs/investigations/2026-11-11-handoff/samples/png512.bin` | 512 | `f7d9e0aa8e18d8c2140128b21ea2a55e04a0d4ae3a0aab7bc3c3587c963e754e` | PNG test sample (not a code artefact) | n/a — docs investigation sample |
| `irx/IEEE1394_bd.irx` | 8209 | `b509939ebf23f09538f49135b9e841d55b8b0ae4266192e44a01f436099f4a62` | IOP module 'IEEE1394_bd', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/IEEE1394_bd.irx.xz` | 3752 | `33e7882bed385428b5850e819338dc8644b0716b4e4dfa8a9654d20b6e86194d` | XZ-compressed IOP module 'IEEE1394_bd' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/ata_bd.irx` | 11741 | `0705df0542e3bb3bbc0bdf852936300eb1d0ac48cb53b1f098b74d4f6fe40bb9` | IOP module 'ata_bd', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/ata_bd.irx.xz` | 4808 | `e13676332bb5d4605ef137c55317803e5c80cde2c88e493b571545f8f7ca8bdb` | XZ-compressed IOP module 'ata_bd' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/bdm.irx` | 8881 | `2ada1262cfb962610949711c44e5f3556981fe93b2922903364ab940ee3170fe` | IOP module 'bdm', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/bdm.irx.xz` | 3900 | `0fa1c1119ef18dccedc0e5baa36db8c31df58c3cd117cc5389a700c31a4974d9` | XZ-compressed IOP module 'bdm' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/bdmfs_fatfs.irx` | 36877 | `1e1d9deac89e8b600ac20174fdf87f913ed23b87dd7a1f5fac3f229343086260` | IOP module 'bdmfs_fatfs', plain form — kept deliberately as the SHA-256 pin-test reference (tools/test_bdmfs_fatfs_module.py:12-15) | in-repo build: tools/build_bdmfs_fatfs.sh |
| `irx/bdmfs_fatfs.irx.xz` | 17160 | `2ea8ca1a540a59fdab41dc9a71cdfd4d5a1094b8e94ea3cf2627cd3adc7a568a` | XZ-compressed IOP module 'bdmfs_fatfs' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | in-repo build: tools/build_bdmfs_fatfs.sh |
| `irx/bdmfs_vfat.irx.xz` | 12540 | `3bdf663ffd2c64323a13ecf26f78230bba6558e72fd8cd93df6645fb434e70c5` | XZ-compressed IOP module 'bdmfs_vfat' — the embedded form (Makefile:99-100). no plain copy tracked (the module's only form) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/ds34bt.irx.xz` | 7372 | `5b79d98dcab8600032ee9423e585b333cf8201a95eac46cdb85866c17cfd32b8` | XZ-compressed IOP module 'ds34bt' — the embedded form (Makefile:99-100). no plain copy tracked (the module's only form) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/ds34usb.irx.xz` | 4652 | `3b9d161b8554184dc93cec4a4803aa86962bc07aacb5d077ea84afc3e5a9c2d7` | XZ-compressed IOP module 'ds34usb' — the embedded form (Makefile:99-100). no plain copy tracked (the module's only form) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/filexio.irx` | 9137 | `47ba1134a4fecd396d8303405a483ae70eae6350e92b72630e9367cbcbfd8047` | IOP module 'filexio', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/filexio.irx.xz` | 3024 | `933b7400526e65b5a1938119436a0c4077e14ab06c31373babc57914e68dc26f` | XZ-compressed IOP module 'filexio' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/iLinkman.irx` | 12841 | `d773b1f7a2896e239a2d7d0e27cf1dde9af8dc45f775dd21d05b946bea6434b6` | IOP module 'iLinkman', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/iLinkman.irx.xz` | 5240 | `ae7f1b30482695ae1a500ed8746fb78f771d59600746ab5b93578d430328cfd0` | XZ-compressed IOP module 'iLinkman' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/iomanx.irx` | 10937 | `c7efcdaf870d765cb0a6c126f72dc4c57533cbca3a44d208073cf3b30699822d` | IOP module 'iomanx', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/iomanx.irx.xz` | 3972 | `00a649eed8dad78be18c92bc9237dbaaf6d28241449012d550161c7775716929` | XZ-compressed IOP module 'iomanx' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/libsd.irx.xz` | 6564 | `c5a14175fed3460bbba81fdc8496fe22c9dd0f45d8440c5b3d3b3c724a6f22dd` | XZ-compressed IOP module 'libsd' — the embedded form (Makefile:99-100). no plain copy tracked (the module's only form) | in-repo build: tools/build_libsd.sh (patched PS2SDK sources) |
| `irx/mcman.irx` | 72101 | `caf1aa5c83a2652096d248c71d25fb6106bd72f46d7b4a31411873c37f370709` | IOP module 'mcman', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/mcman.irx.xz` | 26320 | `e8ef56e272bfe1da89315d3ac1a2ea350f317b3b7ec7d9c53708dead5f834770` | XZ-compressed IOP module 'mcman' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/mcserv.irx` | 8197 | `9f1b2ee6eb5f7c1f56ce225100824d85bc615eda3dac4f6be00b5f9f6d3c8924` | IOP module 'mcserv', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/mcserv.irx.xz` | 3136 | `68ae5b9677e59ba236b780734337ee6f307b4d4bc921d70cd254f4471d6efc46` | XZ-compressed IOP module 'mcserv' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/mmcedrv.irx` | 11337 | `d9e0d476e95e1b952ddd7d11d866b77cbec0e78d6c3ba9f739de1b510a8cd517` | IOP module 'mmcedrv', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/mmcedrv.irx.xz` | 3904 | `f8d70c30b42cd936cf8013a247439c1ac1c7a91349cb59cc5123e7d31006223a` | XZ-compressed IOP module 'mmcedrv' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/mmceman.irx` | 20096 | `89ac14ce8235a86249c3d5a45a15efccd61ce167187af41a5a5d02f7577484fa` | IOP module 'mmceman', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/mmceman.irx.xz` | 5716 | `444eb792ad9c4070ef6f6a7a2035eee8a1c6334c269682e4af52dd6ded5aab72` | XZ-compressed IOP module 'mmceman' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/mx4sio_bd.irx` | 12033 | `840fb57491db31913ed6368fe72646cfe42d926b3db1df54549e358468bea94f` | IOP module 'mx4sio_bd', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/mx4sio_bd.irx.xz` | 5488 | `960cf7bd5acdae640deff5c56669c69b134dd4603417eacf4bd203bffd13e526` | XZ-compressed IOP module 'mx4sio_bd' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/padman.irx` | 36757 | `1ca382e617528b179405edbcbb744c421019e9cb2bce9a7fe30f3d68c074f112` | IOP module 'padman', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/padman.irx.xz` | 10612 | `2892dffe3444f08b817cddebcda555862a54ee536ee28e0c25ef2ba58f47e960` | XZ-compressed IOP module 'padman' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/sio2man.irx` | 5241 | `44748d1c67b22132c026dd05bb06314bcbb5318a3f12835fd388f4e2b3126986` | IOP module 'sio2man', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/sio2man.irx.xz` | 1628 | `8e24e34d2b208c889d95d8b385a29f7811a1f09884f90697183b97704b5b158d` | XZ-compressed IOP module 'sio2man' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/smbman.irx.xz` | 16588 | `50158a43f6484ba86f05f0d1952e584779fe32beef8738fa61f67569cac88a2c` | XZ-compressed IOP module 'smbman' — the embedded form (Makefile:99-100). no plain copy tracked (the module's only form) | in-repo source: iop/smbman-sms |
| `irx/udpfs_ioman.irx` | 11393 | `6e7776fd4a911e28e810ed2a595adfdd8a27f4da305db6093b64a9a40216526f` | IOP module 'udpfs_ioman', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | in-repo source: iop/SMSUdpfs |
| `irx/udpfs_ioman.irx.xz` | 4512 | `062d5b8fcc957c3c15a4e6b676b1f95a0370abac01f7221989c024de97ad5344` | XZ-compressed IOP module 'udpfs_ioman' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | in-repo source: iop/SMSUdpfs |
| `irx/udpfs_ministack.irx` | 3785 | `7b4d838e3d10b8ecdec1bd116b3322b2df5580ab7ab8e8d57757ee764070869a` | IOP module 'udpfs_ministack', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | in-repo source: iop/SMSUdpfs |
| `irx/udpfs_ministack.irx.xz` | 1812 | `a8680d2bee315f2198a273a30786df0aedcc7dcb996c1362c9a7b808f82efa4c` | XZ-compressed IOP module 'udpfs_ministack' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | in-repo source: iop/SMSUdpfs |
| `irx/udpfs_smap.irx` | 7457 | `f1bb721536fd781bf63ba771f5bf210e4b5f87c9da1a5b4be7af335958168606` | IOP module 'udpfs_smap', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | in-repo source: iop/SMSUdpfs |
| `irx/udpfs_smap.irx.xz` | 3500 | `250007a7be259d1463c098979aed85ec750e9a4e20af521ff3d82bc70d6f0431` | XZ-compressed IOP module 'udpfs_smap' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | in-repo source: iop/SMSUdpfs |
| `irx/usbd.irx` | 26241 | `79d7e20f18801233fc0b8ccde42e784c263c0506c60343f5ea7ca83b02e05c05` | IOP module 'usbd', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | in-repo source: iop/USBD |
| `irx/usbd.irx.xz` | 10476 | `688b77a49c8e42ff65223cc6724d152e1d16707602216685f8bdfb1651e1b19f` | XZ-compressed IOP module 'usbd' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | in-repo source: iop/USBD |
| `irx/usbmass_bd.irx` | 10177 | `9b3ca2607ecc792c833a87ac0d03d6026e265dc2bb2f4e51df9dfe56aecaeea2` | IOP module 'usbmass_bd', plain form — byte-identical duplicate of the .xz payload, no consumer (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `irx/usbmass_bd.irx.xz` | 4264 | `aa5d9257d60a843580764c0368083eddc0186d092e533f7fd06a0357fc82bf43` | XZ-compressed IOP module 'usbmass_bd' — the embedded form (Makefile:99-100). payload byte-identical to the plain .irx beside it (X-54) | NONE — external (PS2SDK stock / BDM-Neutrino family / ds34 project / custom build) |
| `utils/DDrawSrv.exe` | 45056 | `91678c3204cb2c65bd9c189637dddc249def6195da25a0d5d5af8d509b52fa53` | PE32 GUI executable — DirectDraw server utility (imports DDRAW.dll) | NONE — legacy PC utility, no source in repo |
| `vu/CSC1.o` | 1232 | `f3531b59a5135251708eef2f85d66125bfdf1411d0820760a461365557a93ca3` | VU microprogram object (non-ELF binary; bytes == shipped C array, verified §2.4) | canonical in-repo form (vu/build.sh); .s sources absent |
| `vu/CSC2h.o` | 2128 | `2b4f88f2283ed79b45fa34b18a642a5d5e8cdc3906179b1e617c14d786b4d95e` | VU microprogram object (non-ELF binary; bytes == shipped C array, verified §2.4) | canonical in-repo form (vu/build.sh); .s sources absent |
| `vu/CSC2v.o` | 1632 | `dbd026ee374475ecb434a433c203f6135530730aec3c6234ff95b82c26f3f1f5` | VU microprogram object (non-ELF binary; bytes == shipped C array, verified §2.4) | canonical in-repo form (vu/build.sh); .s sources absent |
| `vu/CSC4.o` | 1872 | `ab91c9092689049601254985a309a0bf8a498a2f2401cac4093d639991c29497` | VU microprogram object (non-ELF binary; bytes == shipped C array, verified §2.4) | canonical in-repo form (vu/build.sh); .s sources absent |
| `vu/IDCT.o` | 2016 | `b969c66551f7531b054662dd00cdd08adf68e2d7af2ddf735d19ed3a16279c8c` | VU microprogram object (non-ELF binary; bytes == shipped C array, verified §2.4) | canonical in-repo form (vu/build.sh); .s sources absent |

## 6. What remains unverifiable, and round-9 totals

**Unverifiable in this environment (named, not waved at):**
- **No binary could be rebuild-compared.** Without a PS2 toolchain there is no
  "compile the source, diff the ELF" test for any artefact whose source *is* in-repo
  (SMS's `iop/` modules, POPSLoader's `iop/ata_bd_fast`, Launchstation's build-time
  modules, RiptOPL's `ilink_bd_assault`). Correspondence for those rests on strings,
  structure, hashes and history — stated per row in §5, never upgraded to "matches its
  source".
- **SMS's ds34 pair** (`ds34bt.irx.xz` payload 22,305 B; `ds34usb.irx.xz` payload
  12,169 B) ships with no source in SMS — the family's only ds34 copies that cannot be
  checked against the X-49 census defects (patched memset size / battery index) even in
  principle. The binaries are stripped; locating the census's memset immediate in
  unlabelled code would be guesswork, so no claim either way is made.
- **Behavioural content of every module** (does the code *do* what its strings say) is
  beyond an identification pass; only `usbhdfsd.irx` received function-level
  disassembly (§2.1), because a prior finding turned on its identity.
- **Launchstation's IOP image pair** (`exploits/IOPRP.IMG`, `IOPRP_LTS.IMG`) are
  Sony-derived ROMIMG containers (build stamps 20180614 / 20230221, the latter built on
  a named individual's Windows desktop per its own conffile string). Their embedded
  module sets were identified from ROMDIR/strings only; no in-repo build recipe exists
  or could exist for Sony images. Provenance fact, not a finding.
- **Ember** (`ember.elf`, 1,611,956 B ×2 copies): identification only, per its licence
  (§tooling). Whether its bytes correspond to any particular Ember build is unverifiable
  here by the owner's terms.
- **POPSTARTER patch data** (`PATCH_5.BIN` — an IPS patch by magic; `TROJAN_7.BIN`) is
  inventoried and hashed; *what the patches change* in the PS1 driver was not analysed
  (patch-application semantics against a BIOS image is a separate rig).
- The `usbd.irx.mmce` build (11,841 B, no informative strings) is identified only by its
  slot and RiptOPL's provenance row; its "exact upstream build source unpinned" caveat
  is RiptOPL's own and is carried into §5 unchanged.

**Round-9 cross-repo totals:**
- Census: **206 tracked binary artefacts / 10,857,571 B** across 4 repos (PS2-Servers:
  0), every one hashed (sha256) and identified from structure/strings; 24 SMS `.xz`
  payloads additionally analysed decompressed. The extension-only census would have
  missed 44 files (43 mode-suffixed BDMAssault variants + 1 KELF) — the `file(1)`
  full-tree scan is what caught them.
- Executed verifications: POPSLOADER-069 (disassembly), REV-006 pin (string accounting,
  22/22), PROVENANCE.md table (9/9 hashes), SMS VU objects (5/5 byte-identical),
  SMS plain↔xz pairs (19/19 identical), POPSTARTER variant matrix (all pairs ≤2
  differing bytes), BDMAssault variant matrix (45 files → 9 binaries), udpfs trio
  three-repo identity.
- Suspects raised and dissolved: SMS VU dual representation (§2.4); SMS plain/xz pairs
  *as drift* (consistent — the finding is duplication, X-54); RiptOPL's 0-byte
  `ship/Example/…/APPS/APP_RIPTOPL/RIPTOPL.ELF` (a SAS template slot — APPINFO.PBT is a
  fill-in script template; recorded in §5, not numbered).
- **New cross findings: 4 (X-54, X-55, X-56, X-57)** — count verified by grep against
  this file's headings before delivery (round-7 lesson).

*End of cross-repo round 9.*
