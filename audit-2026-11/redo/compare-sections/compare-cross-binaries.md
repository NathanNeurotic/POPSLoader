# Comparison — Shipped Binaries / Provenance / Census Reconciliation (OLD vs REDO)

*Comparison worker section, OLD-vs-REDO cross-repo audit comparison. Every count below was re-derived by this worker's own scripts against the read-only clones (`git ls-files`, `sha256sum`, `cmp`-equivalent byte diff, `xz`/`lzma` decompression) — nothing was copied from either report without re-derivation. No audit report was edited; this file is the only write.*

## Pins, cleanliness, tarball

| Repo | Pin (HEAD, re-read by `git rev-parse`) | `git status --porcelain` |
|---|---|---|
| RiptOPL | `2e347d5ac885cd0ff73e9ad4143781946396f492` | clean (0 lines) |
| Launchstation | `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` | clean (0 lines) |
| POPSLoader | `29272cddbf0122f14e76bc3bdd75e3b46aa870be` | clean (0 lines) |
| Simple-Media-System | `e65ced39a27eee8d996e9257e21594d1cac1c93d` | clean (0 lines) |
| PS2-Servers | `c5f021c4d38698860f56b03498adc261dbb8d8dd` | clean (0 lines) |

BDMAssault tarball `POPSLoader/iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz`: **md5 `09ff4b911ba131468a25d0ec9a4e2f27` — confirmed** (matches the required value; no extraction was needed for this cluster's counts).

Definitions used throughout: *tracked* = `git ls-files`; *ELF-typed* = first four bytes `\x7fELF` (magic), unless a row says otherwise; byte offsets are 0-based (old's `cmp -l` numbering is 1-based, so its byte 1041 = offset 1040 here).

---

## (i) The four match rows

| Pair | Match? | Agreed final scope (this worker's re-derivation) |
|---|---|---|
| **X-54 vs RE-X-29** (SMS plain↔xz IRX duplication) | **MATCH** | Both finals land WEAKENED at the same scope: payload identity is exact, the build/CI consume only the `.xz` form, but the plain set is **not** unreferenced — it is the regeneration input set (`tools/compress_irx.py` reads `irx/*.irx`), so old's filed "nothing reads them" and redo's filed "dead weight / delete the other set" framings both fall. Agreed numbers in §1 below. |
| **X-55 vs RE-X-28** (POPSTARTER default is the DEBUG build) | **MATCH** | Both finals VERIFIED on identical byte facts: default/root ELF ≡ DEBUG in all 3 trees; all variants differ only inside the dword at file offset 0x410. Full census in §2 below. |
| **X-56 vs RE-X-31** (`drvtif-ingame.irx` ≡ `drvtif.irx`) | **MATCH** | Both finals VERIFIED: pair byte-identical; sibling `tifinet` pair genuinely distinct. Hashes in §3 below. |
| **X-59 vs RE-X-30** (BDMAssault provenance omits the `.udpfs` pair) | **MATCH** (on the surviving claim; the pair's *filed totals* disagreed and are ruled on in §4) | Both finals assert the same residue of the withdrawn X-57: RiptOPL ships the `.udpfs` pair while `modules/bdmassault/PROVENANCE.md` has no row for it (0 mentions of "udpfs", re-grepped), and the `usbhdfsd.irx.udpfs` ≡ `usbhdfsd.irx.usbexfat` dedupe is unstated there. RE-X-30 as filed carried family totals 47/11, which its own verify pass corrected to 45/9 — the old totals. Agreed family census in §4 below. |

### §1 — X-54 / RE-X-29 detail (SMS `irx/`)

Recount (tracked files under `Simple-Media-System/irx/`):

- Plain `.irx`: **19**. `.irx.xz`: **24**.
- Payload identity: decompressing every `.irx.xz` that has a plain sibling and comparing sha256 to the plain file gives **19/19 byte-identical**.
- The 5 `.xz` orphans (no plain sibling), exactly: **`bdmfs_vfat`, `ds34bt`, `ds34usb`, `libsd`, `smbman`** — matches the redo census exactly. No plain file lacks an `.xz` sibling.
- **What old's 286,561 B sums — settled:** sum of all 19 plain files = **323,438 B**. The excluded reference file `irx/bdmfs_fatfs.irx` is **36,877 B**. 323,438 − 36,877 = **286,561 B exactly**. So the figure is the total size of the **18 plain files other than `bdmfs_fatfs.irx`** (the pin-test reference copy X-54 explicitly excluded) — equivalently their payload sizes, since payloads are byte-identical. It is *not* the all-19 total and *not* any `.xz` stored size (the 19 paired `.xz` files total 123,224 B stored; all 24 total 170,940 B stored). Old's filed figure is exact under its stated exclusion; redo filed no byte total, so there is no numeric disagreement — the only disagreement was framing (dead vs regeneration inputs), and both verify passes converged on regeneration inputs.

### §2 — X-55 / RE-X-28 detail (POPSTARTER.ELF full census)

Every tracked file named exactly `POPSTARTER.ELF` in all five clones: **17 copies** (RiptOPL 12, POPSLoader 5, Launchstation / SMS / PS2-Servers 0), all **167,700 B**, in **5 distinct hashes**:

| sha256 | Variant (folder) | Copies |
|---|---|---|
| `3ec327085eccd62578a453e3deedf3ba35f19cd7d332aedaffdc7926c73876b8` | root/default **and** `DEBUG` (byte-identical) | **6** (POPSLoader root + DEBUG; RiptOPL `ship/POPS` root + DEBUG; RiptOPL Example-tree root + DEBUG) |
| `734c813e8e8ec2c6729ec5e15dd46ab696e90deeade8d0b2ca3ad03782781aa1` | `MAIN` | 3 (one per tree) |
| `613b16e1823a154d0e468e0a686aad02823fea9d876d91d86131382fa6d42d01` | `USBDELAY` | 3 |
| `9bab715aa17f39981af2ad68c107b74d79817336bde79afaf72f22e0f6812e0e` | `USBDELAY_DEBUG` | 3 |
| `bb697bea1d7ede1a8e4d211442d8bb762fff42372a94f03ccd61a960f4845a18` | `USBDELAY_LONGER_DEBUG` | 2 (RiptOPL's two trees only) |

Full path list (path | sha256-prefix): POPSLoader `bin/POPSLDR/POPSTARTER.ELF` `3ec32708…`; `bin/POPSLDR/PROFILES/DEBUG/POPSTARTER.ELF` `3ec32708…`; `…/PROFILES/MAIN/…` `734c813e…`; `…/PROFILES/USBDELAY/…` `613b16e1…`; `…/PROFILES/USBDELAY_DEBUG/…` `9bab715a…`. RiptOPL `ship/POPS/POPSTARTER.ELF` `3ec32708…`; `ship/POPS/POPSTARTER VERSIONS/{DEBUG,MAIN,USBDELAY,USBDELAY_DEBUG,USBDELAY_LONGER_DEBUG}/POPSTARTER.ELF` = `3ec32708… / 734c813e… / 613b16e1… / 9bab715a… / bb697bea…`; the Example tree (`ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/…`) repeats the same six paths with the same six hashes.

Pairwise byte diffs across the 5 distinct hashes (all 10 pairs computed): **every pair differs by 1 or 2 bytes, never more; every differing offset is 1040 and/or 1043 (0-based) — i.e. inside the single dword at file offset 0x410 (bytes 1040–1043), exactly as old's §3.2 states.** Offset 1040 carries `0xFF` in the DEBUG-named variants and `0x00` in MAIN/USBDELAY; offset 1043 carries `0x02 / 0x06 / 0x09` growing with the delay names. **MAIN vs DEBUG (root hash): exactly 1 differing byte, at offset 1040, MAIN `0x00` vs DEBUG `0xFF`** — confirming both old's matrix and redo-verify's "cmp count exactly 1 at offset 1040". Old's "17 copies" is **correct**.

### §3 — X-56 / RE-X-31 detail (RiptOPL `modules/debug/`)

- `drvtif.irx` and `drvtif-ingame.irx`: both 5,985 B, **sha256 `66ed2eb23a138c80f842cf1328dee6026753cfb5a9fbac2e1cc32133e2c2708b` — byte-identical pair confirmed** (redo's hash; old cited the same files by md5 `838e4e7adf…`, consistent with the round-9 inventory row).
- `tifinet.irx` sha256 `20bc15bf38675aa036cb1ab82ef30e86c6e2fbeae08e422af8e913dafbfb8ac7…` vs `tifinet-ingame.irx` `4590da5ee041ba82952d641d85b1eb829216fc3fd27e0b6a8ad3f3570f926dee…` (both 3,301 B): **genuinely distinct**, as both finals state.

### §4 — X-59 / RE-X-30 detail (BDMAssault `usbd.irx*` / `usbhdfsd.irx*` family)

Scope: tracked files whose basename starts `usbd.irx` or `usbhdfsd.irx` in POPSLoader + RiptOPL (the artefacts sections' own stated rule on both sides).

**Recount: 45 files / 9 distinct hashes — definitively.** Per repo: **POPSLoader 14 + RiptOPL 31**. Per side: **`usbd` 22 / `usbhdfsd` 23** (old's own verify2 correction; old round-9 §3.1's printed 21/24 split was wrong). Hash groups:

| sha256 (prefix) | Size (B) | Copies |
|---|---|---|
| `5ea4818ba1cf5207…` (usbd triple: `.usbexfat` ≡ `.mx4sio` ≡ `.ilink`, plus POPSLoader's plain embed `usbd.irx`) | 48,500 | **12** ✓ as both finals claim |
| `70a369e47745e7f9…` (`usbhdfsd.irx.udpfs` ≡ `usbhdfsd.irx.usbexfat`) | 34,508 | **6** ✓ as both finals claim |
| `61525fab3b340aae…` | 14,993 | 5 |
| `4e1d393658547471…` | 42,749 | 4 |
| `0fed25d9eecdd263…` | 11,841 | 4 |
| `1cc865cd09997bd7…` | 21,837 | 4 |
| `9cd849ea7f06d72f3…` | 27,769 | 4 |
| `9f7b77848935f0d8e…` | 19,733 | 4 |
| `d1d5502454fbc9ca…` (`usbd.irx.udpfs`, distinct binary, both repos) | 61,949 | 2 |

Group list matches redo-verify's independent recount hash-for-hash. The two named identities the task singled out are **both confirmed**: the usbd triple hash `5ea4818b…` has exactly 12 copies, and `usbhdfsd.irx.udpfs` ≡ `usbhdfsd.irx.usbexfat` at `70a369e4…` with exactly 6 copies.

**Ruling on 45/9 vs 47/11:** 45/9 is correct under the stated scope. The redo Stage-A / RE-X-30-as-filed figure 47/11 reproduces **only** by additionally counting SMS's unrelated `irx/usbd.irx` (sha256 `79d7e20f…`, 26,241 B) and `irx/usbd.irx.xz` *as stored* (sha256 `688b77a4…`, 10,476 B) — I verified 45+2 files and 9+2 distinct under exactly that addition. That addition is outside the stated scope and double-counts one payload in two encodings, so **47/11 is wrong; old's 45/9 (and redo-verify's correction to 45/9) is right**.

Provenance half: `RiptOPL/modules/bdmassault/PROVENANCE.md` contains **0** occurrences of "udpfs" (case-insensitive grep) and its table has **9 file rows covering 8 distinct binaries** (the `usbd.irx.ilink` row repeats the `5ea4818b…` hash) — redo-verify's correction of RE-X-30's "tables 8 variants" wording is the precise form; old's "9-row table, 9/9 hashes accurate, no udpfs row" is also accurate as worded.

---

## (ii) Agreed census table

| # | Metric (definition used) | Old claim | Redo claim | **My recount** | Ruling |
|---|---|---|---|---|---|
| a | Total tracked files, 5 clones (`git ls-files`) | — (no counterpart) | filed 5,663; verify 5,663 (2381/1065/609/1012/596) | **5,663** — RiptOPL 2,381 · Launchstation 1,065 · POPSLoader 609 · SMS 1,012 · PS2-Servers 596 | **Redo right**, filed and verified figures both reproduce exactly. |
| b1 | ELF-typed tracked files (ELF magic bytes) | — (old used a broader artefact definition, see b2) | filed **179** (112/40/19/8/0); verify recount **165** (101/38/19/7/0) | **165** — RiptOPL 101 · POPSLoader 38 · SMS 19 · Launchstation 7 · PS2-Servers 0; 9,373,297 B | **Redo-verify right; redo-as-filed 179 wrong** under every definition I tried (magic 165, extension-only 162, old artefact set 206). |
| b2 | Old round-9 binary inventory (extension census `.irx/.elf/.exe/.o/.img/.bin/.xz` **plus** `file`-scan catches: BDMAssault mode-suffixed files + the one `.kelf`) | **206 artefacts / 10,857,571 B** (RiptOPL 108, POPSLoader 39, Launchstation 9, SMS 50) | — (no counterpart) | **206 files / 10,857,571 B exactly**, per-repo 108/39/9/50/0, by reconstructing the set from its preamble definition and summing sizes from the clones; §5's own table rows also parse to 206 rows / 10,857,571 B | **Both right under different definitions:** the 206-set is a strict **superset** of the 165 ELF-magic files (all 165 are inside it) plus 41 non-ELF stored artefacts — 24 `.irx.xz`, 5 `.bin`, 4 `.img`, 1 `.exe`, 1 `.kelf`, 5 `.o` and 1 `.elf` lacking ELF magic (1,484,274 B). 206 ≠ an ELF count and 165 ≠ an artefact count; neither refutes the other. The tarball's *contents* are **not** in the 206 (no extraction is needed to reproduce it). |
| c1 | Cross-repo byte-identity groups, ELF content (sha256 groups over ELF-magic files, ≥1 file in ≥2 repos) | — | summary "22" (qualifier dropped); verify "22 as ELF-content groups" | **22** (of 25 multi-file ELF hash groups in total) | **Redo-verify right**; the Redo-Cross summary sentence is imprecise read literally, as its verify pass already notes. |
| c2 | Cross-repo byte-identity groups, all file types (sha256 groups over all tracked files, ≥1 file in ≥2 repos, empty files included) | — | verify: 177 | **177** (249 multi-file groups in total; excluding the empty-file hash group gives 176) | **Redo-verify right** under the include-empty-files definition, which is the natural `git ls-files` + sha256 reading. |
| d | ds34 driver copies (tracked `.c` files named exactly `ds34bt.c` / `ds34usb.c` in IOP + pademu locations) | 10 driver copies (agreed) | 10 driver copies + "4 EE libs" | **10** — 5× `ds34usb.c` + 5× `ds34bt.c` (RiptOPL IOP+pademu, Launchstation IOP, POPSLoader IOP+pademu; SMS none). EE libs: **8 tracked files** — `libds34bt.c` ×4 repos and `libds34usb.c` ×4 repos (RiptOPL, Launchstation, POPSLoader, SMS `src/`) | **Both right on the 10 drivers.** Redo's "4 EE libs" is correct only per lib-name (4 copies of each); as a total file count the correct value is **8**. Minor wording imprecision, no finding rests on it. |
| e1 | UDPFS headers in RiptOPL `modules/network/udpfs_{bd,fhi,ioman}/src/` (all `.h` files; `udpfs_shared/src/` holds 0 headers) | X-07 final: **6 headers ×3** | RE-X-12: **5 headers ×3** byte-identical | Each of the three `src/` dirs holds **6** `.h` files, and **all 6 are byte-identical ×3**: the 5 protocol headers (`udpfs_packet.h e51bb79a…`, `udprdma_packet.h 91f5d702…`, `udpfs_core.h f3db57ee…`, `udprdma.h 59d96928…`, `udprdma_seq.h 08bf73e0…` — prefixes match redo-verify) **plus `irx_imports.h` (`6722fe1e…`) ×3** | **Both right under different definitions.** The 6th header is **`irx_imports.h`** — generic IOP import boilerplate, not a UDPFS wire header. Old's 6×3 is the literal `src/*.h` count; redo's 5×3 is the protocol-header count its finding is about. |
| e2 | `mprintf.h` copies in RiptOPL | X-07 final: **×5** (round-9 modules pass: "×5 identical + 1 diverged (smap_udpbd)") | — (not in RE-X-12's scope) | **6 tracked copies total:** 5 byte-identical (sha256 `6294ac87…`) in `udpfs_{bd,fhi,ioman,ministack,smap}/include/` + 1 diverged copy (sha256 `1b6d2a1c…`) in `smap_udpbd/src/include/` | **Old right as an identical-copy count (×5 identical), incomplete as a total-copy count (6 exist).** No redo counterpart to disagree. |
| f | UDPFS IOP `udpfs_ioman.irx` identity (sha256 of tracked copies) | trio shared across Launchstation / POPSLoader / RiptOPL-Example; SMS distinct | SMS `6e7776fd…` vs shared `85faad56…` | Shared: **`85faad5631fa7b2e…`, 11,633 B**, identical at Launchstation `iop/__precompiled/`, POPSLoader `iop/embed/`, RiptOPL Example-tree `neutrino/modules/` — SMS `irx/udpfs_ioman.irx` = **`6e7776fd4a911e28…`, 11,393 B**, distinct. (Ministack agrees the same way: Launchstation ≡ POPSLoader `85406062…`, SMS `7b4d838e…` distinct.) | **Both sides right; confirmed by hash.** |
| g | Workflow census (`.github/workflows/*.{yml,yaml}`, lines by `wc -l` / newline count) | round-4: **41 files, 8,512 lines** | — (no counterpart; noted only) | **41 files, 8,512 lines** — files 12/6/10/6/7 and lines 2,222/1,314/2,062/828/2,086 for RiptOPL / Launchstation / POPSLoader / SMS / PS2-Servers | **Old right.** (Line-count convention matters: `splitlines` gives 8,513 because one file's last line is unterminated; the `wc -l` convention both the claim and this recount use gives 8,512.) |

## Every disagreement found, with the correct value

1. **Redo-as-filed ELF total 179 (112/40/19/8/0) — wrong.** Correct ELF-magic total: **165 (101/38/19/7/0)**. Redo-verify already corrected this; my recount independently lands on 165.
2. **Redo-as-filed / Stage-A BDMAssault family 47 files / 11 distinct — wrong** under its own stated scope. Correct: **45 files / 9 distinct** (POPSLoader 14 + RiptOPL 31). 47/11 arises only by adding SMS's `irx/usbd.irx` + `irx/usbd.irx.xz`-as-stored, which the scope excludes. Redo-verify already corrected this; old's total was right all along.
3. **Old round-9 §3.1 side split 21 `usbd` / 24 `usbhdfsd` — wrong.** Correct: **22 / 23** (old's own verify2 pass already corrected this; my recount confirms 22/23). Old's family total 45/9 was unaffected.
4. **Redo "4 EE libs" (ds34) — imprecise as a total.** Correct total: **8 EE-lib files** (4 copies of `libds34bt.c` + 4 of `libds34usb.c`). The 10-driver-copy census both sides state is exact.
5. **Not disagreements, despite appearances:** old 206 artefacts vs redo-verify 165 ELF files (different definitions, 206 ⊃ 165, both reproduce exactly); old 6 headers ×3 vs redo 5 headers ×3 (the 6th is `irx_imports.h`); old `mprintf.h ×5` (identical copies; 6 tracked in total).

*Method note: all figures above come from scripts run in this session against the clones at the pins in the header table (`git ls-files` + sha256 for every tracked file in all five repos, ELF-magic classification, `lzma` decompression of all 24 SMS `.xz` files, full pairwise byte-diff of the 5 distinct POPSTARTER hashes, and reconstruction of the old 206-set from its preamble definition). Nothing was PS2-build- or hardware-verified; all checks are host-side.*
