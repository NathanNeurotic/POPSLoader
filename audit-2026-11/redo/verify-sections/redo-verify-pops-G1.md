# Redo Verification — POPSLoader Chunk G1 (tracked binaries & provenance)

**Subject:** `Redo-POPSLoader.md` findings RE-POPS-040, 041, 044, 049, 050, 056
**Clone:** `~/workspace/audit-clones-2026-11-13/POPSLoader`, HEAD re-checked = `29272cddbf0122f14e76bc3bdd75e3b46aa870be`, tree clean (`git status --porcelain` empty before and after).
**Method:** refute-first. Every hash/size below is from my own `sha256sum`/`md5sum`/`cmp`/Python census over the clone's tracked files; tarball extracted fresh to `/tmp/bdma-verify/BDMAssault-mx4sio/` (119 files, matching the report).

## My own binary census (basis for all six findings)

Definition that reproduces the report exactly: tracked files matching `*.irx`, `*.ELF`, or `*.irx.*` (the BDMAssault `.tar.gz` is *not* in this set).

- **38 tracked binary files, 26 distinct by SHA-256, 1,778,343 total bytes** — all three figures reproduce the report *exactly*.
- Full redundant-byte census (sum of `(copies−1) × size` over all duplicate groups): **545,355 B = 532.6 KiB**.
- Tarball: sha256 `49c03644b5cbf99355c07d3abc2f5eca332ce627cfce4c568a1d1c833c40e218`, md5 `09ff4b911ba131468a25d0ec9a4e2f27`, 1,466,084 B — matches the report's md5 and `49c03644…` prefix.
- Distinct hashes (short) in my census: SMB pack `91daae46, 573863a0, e2b83bb0, 1bf99ca2, 671fe9e3, 000296a2`; POPSTARTER `3ec32708` (default+DEBUG), `734c813e` (MAIN), `613b16e1` (USBDELAY), `9bab715a` (USBDELAY_DEBUG); BDMA `4e1d3936, 5ea4818b (×4), 0fed25d9, d1d55024, 1cc865cd, 9cd849ea, 9f7b7784, 61525fab (×2), 70a369e4 (×2)`; embed `3185e57e, 16c5d9f0, 8536a93f, f7fd0c13, 85faad56, 85406062, 4b81d9bf`.

---

### RE-POPS-040 — WEAKENED

**Byte facts: fully verified, exact.** My own Python byte-diff of all five files (each 167,700 B):

```
default vs MAIN: [(1040, 0x00, 0xFF)]
DEBUG   vs MAIN: [(1040, 0x00, 0xFF)]
USBDELAY vs MAIN: [(1043, 0x02, 0x06)]
USBDELAY_DEBUG vs MAIN: [(1040, 0x00, 0xFF), (1043, 0x02, 0x06)]
cmp bin/POPSLDR/POPSTARTER.ELF bin/POPSLDR/PROFILES/DEBUG/POPSTARTER.ELF → identical
sha256 default = sha256 DEBUG = 3ec327085eccd62578a453e3deedf3ba35f19cd7d332aedaffdc7926c73876b8
```

Offsets are 0-based 1040/1043 as claimed; values (1040: 0x00 MAIN/USBDELAY, 0xFF DEBUG/USBDELAY_DEBUG; 1043: 2 vs 6) match exactly. `tools/build_release_kit.sh:17-21` does ship the top-level `bin/POPSLDR/POPSTARTER.ELF`, as do the rolling/experimental workflows. No file in `src/`, `tools/`, the Makefile or the workflows names either byte's meaning (my grep: only hit is an unrelated timestamp string in `src/retrogem.cpp`), and no record anywhere states whether default≡DEBUG is deliberate — that limb stands.

**Why WEAKENED — the headline "documented nowhere in the repo" is false, and the "INFERRED" semantics are in fact documented in-repo.** The tracked research/docs-site source `.research/build_site.py` documents both bytes by their hex offsets ($410 = 1040, $413 = 1043):

- `build_site.py` config page: "POPStarter r13 stores a 32-byte configuration table at file offset `$410` inside POPSTARTER.ELF/.KELF. Each byte is one setting."
- `build_site.py` (~line 1447): "`$410` is the 'Display of the debug texts/pages' byte … `00` … prints nothing. `FF` prints in realtime" — i.e. byte 1040 is the debug-text flag, exactly as the report *inferred*.
- `build_site.py:465,1294-1295,1829,1863`: `$USBDELAY_#` / "config byte `$413`" is the USB-delay byte — byte 1043, as inferred.

**True scope:** the bytes are undocumented in every *shipped/packaging* location (nothing in `src/`, `tools/`, Makefile, workflows, the shipped docs, or next to `bin/POPSLDR/PROFILES/`), and which profile the default should equal is recorded nowhere. The semantics are documented only inside the `.research/` POPStarter archive. The core defect (default install silently carries the debug-text byte at 0xFF, intent unrecorded) stands; the finding's title and its INFERRED label overstate the gap.

**Fix / LESS-NOT-MORE:** the proposed hash comparison is a justified small addition — `build_release_kit.sh` already performs sha256 pins (lines 46-47) — and recording the intent next to the profiles is documentation, not machinery. Sound.

---

### RE-POPS-041 — WEAKENED

**Headline census: verified.** 26 distinct binaries (my census above). Source inventory, re-derived:

- `5ea4818b` (usbd group) ↔ tarball `__bdm_assault/` source: strings include `BDM_ASSAULT: starting Fatfs side` — correspondence holds (INFERRED, as labelled).
- `70a369e4` (usbhdfsd.udpfs/.usbexfat) ↔ tarball `__usbd_bd_assault/` source: strings `USBD ASSAULT Start`, `usbmass_bd: USBD ASSAULT: starting USBMASS Side` — holds.
- `ata_bd.irx` (`16c5d9f0`): partial only — Makefile:332-340 states the binary is pinned from R3Z v4.70 and the vendored `iop/ata_bd_fast/` source is a kept-but-unused cousin. Holds.
- All other 23 distinct: no source in the repo and none in the tarball (tarball top level is only `bdm, bdmfs_fatfs, libbdm, usbd, usbmass_bd, __bdm_assault, __usbd_bd_assault`; `find` for udpfs/smb/popstarter files in the extracted tree = 0 hits; no POPSTARTER/SMB source is tracked outside `.research` archives). **23 of 26 stands.**

**Pin locations: verified.** `tools/test_udpfs_integration.py` BLOBS dict pins exactly the five claimed blobs by git-blob SHA-1 (my recomputation of each blob SHA-1 matches the dict) plus SHA-256 cross-checks against `docs/third_party/okeanos_udpfs/PROVENANCE.json` (which pins `d1d55024` and `70a369e4` — my hashes match its records); `tools/build_release_kit.sh:46-47` pins the ilink pair (`9cd849ea`, `5ea4818b` — both match my hashes); `ata_bd.irx` is sha256-pinned in exactly three workflows (compilation, experimental-release, rolling-release, all `16c5d9f0…`). The `lua-harness` job the fix would extend exists and runs this test (`compilation.yml:21,57`).

**Why WEAKENED — two "no hash anywhere" sub-claims are literally false; the true scope is narrower:**

1. "six popsmb IRX … has no recorded expected hash anywhere" — all six SHA-256s *are* recorded in the tracked research note `.research/research/original-git-network-quickstarter-overlap.md` (full table, e.g. `smbman.irx 000296a2… MATCH`, `smsutils.irx 91daae46… MATCH`). That is a descriptive overlap record, **not** a pin: nothing in CI compares against it, so a byte swap still passes every gate. Substance holds; "anywhere" does not.
2. "the … usbexfat BDMA pairs [have] no recorded expected hash" — both usbexfat blobs' hashes are recorded under their identical twins' names: `usbd.irx.usbexfat` = `5ea4818b`, pinned at `build_release_kit.sh:47` as `usbd.irx.ilink`; `usbhdfsd.irx.usbexfat` = `70a369e4`, recorded in `PROVENANCE.json` as `usbhdfsd.irx.udpfs`. The usbexfat *paths* themselves are checked nowhere, so swapping only the usbexfat copy still passes CI — but the hash values are on record.

My full pin-coverage table (distinct hash → enforced pin): pinned = `d1d55024, 70a369e4, 5ea4818b, 9cd849ea, 16c5d9f0` (SHA-256) + `85faad56, 85406062, 4b81d9bf` (git-blob SHA-1 in the test only); **18 of 26 distinct binaries have no enforced pin at all**, including all four POPSTARTER variants, both ATA pair members (`4e1d3936, 1cc865cd`), both MMCE pair members (`0fed25d9, 9f7b7784`), `61525fab`, `3185e57e`, `8536a93f`, `f7fd0c13`. "Most have no pin" and "a silent byte swap would pass CI" both stand.

**Fix / LESS-NOT-MORE:** one pin table + a check inside the existing lua-harness step is a consolidation of the existing four mechanisms (PROVENANCE+test, kit script, three workflow pins, blob-SHA-1 dict), justified by a concrete gap (IOP-privileged blobs, 18/26 unpinned). Justified addition; not over-engineering.

---

### RE-POPS-044 — WEAKENED

**Core mechanism: verified string-exact with my own `strings` runs.**

- `iop/embed/BDMASSAULT_MX4SIO/usbhdfsd.irx` (14,993 B, sha256 `61525fab…`): strings include `MX4SIO: MX4SIO v1.2`, `MX4SIO: %lu %u-byte logical blocks…`, module name `mx4sio`, imports `sio2man`, `dmacman`, `modload`. It is an MX4SIO SIO2 SD driver, not a USB mass driver.
- Tarball tree search (my extraction): `grep -ri mx4sio` = **0 hits**, `grep -ri sio2` = **0 hits** across all 119 files. No MX4SIO/SIO2 source exists in the tarball. Holds.
- `iop/embed/BDMASSAULT_MX4SIO/usbd.irx` (48,500 B, `5ea4818b…`): strings `Block Device Manager (BDM)…`, `BDM_ASSAULT: starting Fatfs side` — the `bdm_assault` product, matching the README/CI pairing for the usbd slot. First half holds.
- Tarball README pairing is at `README.MD:11-12` (POPStarter section; the report cites 13-16, which is the FreeMcBoot section stating the same pairing) and CI copy lines are `.github/workflows/CI.yml:39-40` (inside the cited 38-41). Minor anchor drift only.

**Why WEAKENED — "the tarball's `usbd_bd_assault` product appears in neither shipped binary" is true only inside the embed pair.** Scoped to the finding's locations (`iop/embed/BDMASSAULT_MX4SIO/usbd.irx` + `usbhdfsd.irx`) it is exact: neither contains the USBD-Assault strings. Repo-wide it is false: the `usbd_bd_assault` product **is shipped** as `bin/POPSLDR/usbhdfsd.irx.udpfs` and `bin/POPSLDR/usbhdfsd.irx.usbexfat` (`70a369e4`), whose strings are verbatim `USBD ASSAULT Start` / `usbmass_bd: USBD ASSAULT: starting USBMASS Side`, and `PROVENANCE.json` records its source as `usbd_bd_assault.irx`. The unscoped Appendix restatement ("appears in neither shipped binary") inherits the same overreach.

**True scope:** the *BDMAssault embed folder's* pair is half-provenance-free — its `usbhdfsd.irx` slot holds an MX4SIO v1.2 driver the tarball cannot account for, and rebuilding that folder from the tarball cannot reproduce it. The `usbd_bd_assault` driver itself is present and provenance-recorded elsewhere in the shipped set. Fix (ship MX4SIO source or a provenance note; correct the pairing table) is deletion-free documentation and stands.

---

### RE-POPS-049 — VERIFIED

My own MD5 + SHA-256 + `cmp` runs:

```
a77650a0ad356077b990d21bde6affc4  usbd.irx.ilink = usbd.irx.usbexfat = usbd.irx.mx4sio (MD5)
ad9640d487b6e53441d2b6bed90dff23  usbhdfsd.irx.udpfs = usbhdfsd.irx.usbexfat (MD5)
sha256 usbd pair  = 5ea4818ba1cf5207f6d7cadb4c13b5afa88c37c260750c21155b079a8c18f369 (48,500 B)
sha256 usbhdfsd pair = 70a369e47745e7f995fa771edbbfed086727b759fba915a7070c0fbcf061dd34 (34,508 B)
cmp: both pairs IDENTICAL. 48,500 + 34,508 = 83,008 B exactly.
```

Both duplicates are separately embedded: separate extern pairs (`src/embed_assets.cpp:80-87`), separate `EMBEDDED_RSC` objects (`asset_usbd_irx_ilink.o`, `asset_usbhdfsd_irx_udpfs.o` in the Makefile list at lines 115-119) with separate BIN2S rules (Makefile:220-241 block), and separate table entries (embed_assets.cpp:160-165 and the prefixed duplicates at 214-219). The claimed precedent exists verbatim: `usbd.irx.mx4sio` is aliased to `asset_usbd_irx_usbexfat` with the byte-identical comment at `src/embed_assets.cpp:149-153`. The excluded blobs are indeed distinct (`usbd.irx.udpfs` 61,949 B `d1d55024`; `usbhdfsd.irx.ilink` 27,769 B `9cd849ea`). Every figure and location checks out. Fix is a pure deletion/alias — LESS-compliant.

---

### RE-POPS-050 — VERIFIED

All groups re-derived from my census (hashes in the census block above):

- (a) SMB pack: six files × 2 paths (`POPSTARTER/` ≡ `bin/POPSLDR/popsmb/`), one-copy-set total **182,654 B** — exact (1,305+3,413+11,505+109,497+12,605+44,329). Popsmb copies are the Makefile embed inputs; `POPSTARTER/` ships at the release-zip root (`rolling-release.yml:234`: "POPSTARTER/ ships at the ZIP ROOT").
- (b) BDMAssault pair: 48,500 + 14,993 = **63,493 B** — exact. (Multiplicity is actually higher than the text suggests: the `5ea4818b` usbd blob exists at *four* tracked paths — ilink, mx4sio, usbexfat, embed — not two.)
- (c) `bin/POPSLDR/POPSTARTER.ELF` ≡ `PROFILES/DEBUG/POPSTARTER.ELF`, 167,700 B — exact (see RE-POPS-040).
- Total: my full redundant-byte census is **545,355 B = 532.6 KiB**, so "~530 KB of the 1,778,343 tracked binary bytes" is accurate (KiB reading; 545,355 B decimal-KB would be ~545 KB). The 1,778,343 denominator reproduces exactly.
- No CI step compares `POPSTARTER/` against `popsmb/` (my grep over workflows/tools/Makefile for cmp/sha256 on those paths: no hits) — drift-risk claim holds.

Note (not a defect): groups (b) and the RE-POPS-049 pairs overlap in tracked bytes — RE-POPS-049 measures the *second embed inside the ELF*, RE-POPS-050 the *second tracked copy in git*; the two findings' byte totals must not be summed.

---

### RE-POPS-056 — VERIFIED

Sizes from my own `stat`: `bdmfs_vfat.irx` 30,013 B, `mx4sio_bd_mini.irx` 13,897 B, `PS2SDK_MX4SIO/mx4sio_bd.irx` 15,089 B; total **58,999 B** — exact.

Deadness re-derived with whole-repo greps (Makefile, `src/`, workflows, `tools/`, Lua, `etc/`, `modules/`, `iop/`):

- `bdmfs_vfat`: **zero** hits in any build/code file; no `bdmfs_vfat.o` in `IOP_MODULES` (the list carries `bdmfs_fatfs.o`), no extern symbol `bdmfs_vfat_irx` anywhere.
- `mx4sio_bd_mini`: **zero** hits in any build/code file; no `mx4sio_bd_mini.o`/extern anywhere. (The similarly named `IEEE1394_bd_mini.o` in `IOP_MODULES` is a different, SDK-resolved module.)
- `PS2SDK_MX4SIO/mx4sio_bd.irx`: the module *name* `mx4sio_bd` is heavily referenced, but it resolves via the generic `%.irx` rule + `vpath %.irx iop/embed/` then `$(PS2SDK)/iop/irx/` — there is **no** `iop/embed/mx4sio_bd.irx` at the vpath top level, and vpath is non-recursive, so the subdirectory copy can never be picked. The only reference to the path is the Makefile comment itself (`Makefile:346-350`, comment spans 346-352): "now resolves via the generic %.irx rule + vpath, i.e. from the SAME ps2sdk… The old pinned copy (iop/embed/PS2SDK_MX4SIO/, left in place, untouched)… Do NOT re-pin it here." Exactly as the finding states.

Fix is pure deletion — LESS-compliant. (The one place these files are still described as live is `COMPONENTS.md` — see Candidates; that is a docs defect, not a refutation: nothing builds, embeds or loads them.)

---

## Closing tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 3 | RE-POPS-049, RE-POPS-050, RE-POPS-056 |
| VERIFIED-DRIFT | 0 | — |
| WEAKENED | 3 | RE-POPS-040, RE-POPS-041, RE-POPS-044 |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — |

No finding is refuted: every hash, size, offset and census figure in all six findings reproduced exactly under independent re-derivation (38 files / 26 distinct / 1,778,343 B; offsets 1040/1043; 83,008 B; 182,654 / 63,493 / 58,999 B; redundant total 545,355 B ≈ the claimed ~530 KB). All three WEAKENED verdicts are scope overstatements in prose around a verified core, detailed per-finding above.

## Candidates (new defects — not verdicts)

1. **CANDIDATE — scope-census file count conflates tracked with on-disk.** The report's scope census says "639 tracked files"; `git ls-files` at the pin returns **609**. 639 is the on-disk file count including 30 git-ignored `__pycache__/*.pyc` files. (The byte total 30,417,169 B matches the 609 tracked files exactly, and the 38/26 binary census is exact, so the damage is confined to that one count. The "162 tracked Markdown files" is also off by one against my count of 163 `*.md`.)
2. **CANDIDATE — `COMPONENTS.md:400-405` presents the three dead RE-POPS-056 binaries as live.** It states `iop/embed/` blobs including `bdmfs_vfat.irx`, `mx4sio_bd.irx` (+`mx4sio_bd_mini.irx`) are "bin2c'd into the ELF" and that "The active `mx4sio_bd.irx` is pinned from `iop/embed/PS2SDK_MX4SIO` (Makefile:247-251)" — both contradicted by the Makefile itself (lines 346-352: SDK vpath resolution, old copy de-pinned). A reader trusting COMPONENTS.md gets exactly the wrong answer RE-POPS-056 warns about. (Distinct limb from RE-POPS-112, which covers the on-card payload list undercounting BDMA variants.)
3. **CANDIDATE — cross-finding byte overlap (accounting caution, not an error).** The `5ea4818b`/`70a369e4` duplicate bytes are counted in both RE-POPS-049 (83,008 B of ELF embed duplication) and RE-POPS-050's tracked-redundant total; any roll-up that sums finding-level byte savings across the report will double-count ~83 KB there and the 167,700 B default≡DEBUG copy in both RE-POPS-040's subject and RE-POPS-050 group (c).
