# Cross pass — artefacts census (coordinator-executed; the artefacts worker errored on infrastructure and this workstream was re-run by the coordinator with the same script method)

Method: `git ls-files` for all five clones (5,663 tracked files), sha256 of every tracked file, `file` run over the full set (179 ELF-typed files: RiptOPL 112 incl. ship tree, POPSLoader 40, SMS 19 plain .irx, Launchstation 8, PS2-Servers 0 — it builds in CI). Duplicate groups computed from the hash table, never estimated. Pins verified before and after.

## Cross-repo ELF identity groups (22 groups, same sha256 in 2+ repos)

Largest: the BDMAssault usbd/usbhdfsd family — 47 tracked files matching `usbd.irx*`/`usbhdfsd.irx*` across POPSLoader + RiptOPL, **11 distinct binaries**. Within it:
- `usbd.irx.usbexfat` ≡ `usbd.irx.mx4sio` ≡ `usbd.irx.ilink` — ONE binary (sha256 5ea4818ba1cf…, 48,500 B) under three variant names, 12 copies across the two repos.
- `usbhdfsd.irx.udpfs` ≡ `usbhdfsd.irx.usbexfat` — one binary (70a369e47745…) under two names.
- `usbd.irx.udpfs` (d1d5502454fb…) is a distinct binary shipped by both repos (POPSLoader/bin/POPSLDR + RiptOPL/ship/POPS).
- POPSTARTER set: root `POPSTARTER.ELF` in both repos is byte-identical to the **DEBUG** profile build (3ec327085ecc…, 167,700 B, 6 copies); MAIN profile is the same size and differs from DEBUG by exactly **1 byte** (cmp -l count = 1); USBDELAY and USBDELAY_DEBUG are further distinct builds.
- UDPFS IOP trio (`udpfs_smap.irx`, `udpfs_ioman.irx`, `udpfs_ministack.irx`) byte-identical across Launchstation `iop/__precompiled/`, POPSLoader `iop/embed/` (smap under the name `udpfs_net_smap.irx`), and RiptOPL's ship neutrino modules.
- POPSTARTER support IRXs (smbman, ps2ip, ps2smap, ps2dev9, poweroff, SMSUTILS) identical between POPSLoader's two in-repo locations and RiptOPL's ship/POPS tree.

## Provenance records

- RiptOPL `modules/bdmassault/PROVENANCE.md` tables 8 usbd/usbhdfsd variants with sha256s — all 8 hashes recompute exactly. It contains **zero** mentions of "udpfs": the `.udpfs` pair its own ship tree carries is absent from this record.
- The pair IS recorded in RiptOPL `ship/POPS/UDPFS-NOTICES/PROVENANCE.json` and in POPSLoader `docs/third_party/okeanos_udpfs/PROVENANCE.json` (both name `usbd.irx.udpfs` and `usbhdfsd.irx.udpfs`). Provenance for the pair therefore exists in both repos, but only in the UDPFS-notices records, not in RiptOPL's canonical bdmassault record.

## Within-repo duplication

- SMS `irx/`: 19 plain `.irx` + 24 `.irx.xz`; decompressing every `.xz` with a plain sibling gives **19/19 byte-identical payloads** (286,561 B total plain size by `du` of the plain set — coordinator note: total computed from the plain files). 5 `.xz` files have no plain sibling.
- RiptOPL `modules/debug/drvtif-ingame.irx` ≡ `modules/debug/drvtif.irx` (same sha256 66ed2eb23a13…), two names one binary, while the sibling tifinet pair are genuinely different binaries.
- RiptOPL `ship/EMBER/ember.elf` duplicated inside the ship Example ZIP tree (same hash).

## Candidate findings (for consolidation)

### ART-01 — Default POPSTARTER.ELF shipped by both repos is the DEBUG build
- Category: 7 (build/repo) / 8
- Locations: POPSLoader/bin/POPSLDR/POPSTARTER.ELF; POPSLoader/bin/POPSLDR/PROFILES/DEBUG/POPSTARTER.ELF; RiptOPL/ship/POPS/POPSTARTER.ELF (+ Example ZIP copies) — all sha256 3ec327085ecc…; PROFILES/MAIN/POPSTARTER.ELF differs by 1 byte.
- Problem: the unnamed default artefact users get is the DEBUG-profile build in both repos; the release-profile build exists only inside the versions/profiles folders. Whatever the 1-byte flag controls, the default is the debug setting.
- Fix: ship the MAIN build as the root/default POPSTARTER.ELF in both repos, or rename the root artefact to make its profile explicit.
- Benefit: users run the intended release configuration by default. Effort: S · Risk: Low · Confidence: High (READ — hash identity + cmp count executed).

### ART-02 — SMS ships every IRX twice: plain + xz with identical payloads
- Category: 4 (size) / 7
- Locations: Simple-Media-System/irx/ (19 pairs).
- Problem: 19 plain .irx files are byte-identical to the decompressed payloads of their .irx.xz siblings (verified 19/19 by xz -dc + sha256). One of the two forms has no consumer distinction established in this census.
- Fix: keep only the form the build/runtime actually consumes; delete the other set.
- Benefit: removes a full duplicate driver set from the tree. Effort: S · Risk: Low · Confidence: High for identity (READ/executed); which form is consumed is for the per-repo pass.

### ART-03 — BDMAssault variant names overstate the binary count; RiptOPL's provenance record omits the .udpfs pair
- Category: 7
- Locations: POPSLoader/bin/POPSLDR/usbd.irx.{usbexfat,mx4sio,ilink} + RiptOPL/modules/bdmassault/ + RiptOPL/ship/POPS/; RiptOPL/modules/bdmassault/PROVENANCE.md (zero "udpfs" mentions); RiptOPL/ship/POPS/UDPFS-NOTICES/PROVENANCE.json; POPSLoader/docs/third_party/okeanos_udpfs/PROVENANCE.json.
- Problem: 47 files / 11 distinct binaries; three usbd variant names are one binary and two usbhdfsd names are one binary, so the name matrix implies builds that don't exist. Separately, RiptOPL's canonical bdmassault provenance table omits the .udpfs pair (recorded only in the ship-side UDPFS notices), so the record a maintainer checks first is incomplete for the files RiptOPL ships.
- Fix: state the dedupe in PROVENANCE.md (it already does for the usbd triple) AND add the .udpfs pair rows to the bdmassault table; drop redundant copies where a name alias suffices.
- Benefit: provenance record matches the shipped set. Effort: S · Risk: Low · Confidence: High (READ/executed hashes).

### ART-04 — RiptOPL drvtif-ingame.irx is a byte-identical second copy of drvtif.irx
- Category: 2 (duplication) / 7
- Locations: RiptOPL/modules/debug/drvtif.irx; RiptOPL/modules/debug/drvtif-ingame.irx (sha256 66ed2eb23a13… both).
- Problem: two tracked copies of one IOP module under names implying different builds; the sibling tifinet pair genuinely differs, so the naming pattern claims a distinction this pair doesn't have. Any future rebuild of one silently desyncs them.
- Fix: keep one file; produce the -ingame name at package time if a consumer requires it, or document the identity where the build lists both.
- Benefit: one source of truth for the module. Effort: S · Risk: Low · Confidence: High (READ — hash identity).
