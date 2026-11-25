# POPSLoader — Blind Redo Audit, Section: Tracked Binaries + Build/CI/Tools

- Repo: NathanNeurotic/POPSLoader, pin `29272cddbf01` (master, HEAD verified by `git rev-parse`).
- Method: hashes/sizes/counts by script only; identity by `strings`/`file` only (no disassembly); provenance judged against `src/`, `modules/`, `iop/`, and the BDMAssault tarball extracted to `/tmp/redo-bdma`. All provenance judgements are INFERRED and state their basis.
- Headline: **38 tracked binaries, 26 distinct by SHA-256, 1,778,343 bytes tracked / ~1,364,446 distinct bytes. Only 2 of 26 distinct binaries have corresponding source in this repo (both via the BDMAssault tarball), 1 is partial, 23 have no in-repo source.**

---

## Findings

### RE-POPS-BIN-01 — Byte-identical BDMA blobs are embedded into the ELF twice; the alias pattern that fixes this already exists and was applied to only one of three cases
- Category: 2
- Locations: src/embed_assets.cpp:148-164; src/embed_assets.cpp:209-218; Makefile:115-119
- Problem: Script-verified hashes: `usbd.irx.usbexfat` = `usbd.irx.ilink` = `usbd.irx.mx4sio` (sha256 `5ea4818ba1cf…`, 48,500 B) and `usbhdfsd.irx.usbexfat` = `usbhdfsd.irx.udpfs` (sha256 `70a369e47745…`, 34,508 B). `src/embed_assets.cpp:149-153` documents and implements the fix for the mx4sio key — it aliases `asset_usbd_irx_usbexfat` instead of embedding a second copy. But the ilink usbd key and the udpfs usbhdfsd key still get their own `extern` symbols, their own Makefile `BIN2S` rules and their own `EMBEDDED_RSC` objects, so every built POPSLOADER.ELF carries the same 48,500-byte blob twice and the same 34,508-byte blob twice: 83,008 wasted bytes in the packed ELF, on a platform where the Makefile already reverted `-Os` partly over size/timing sensitivity.
- Fix: Alias `usbd.irx.ilink` to `asset_usbd_irx_usbexfat` and `usbhdfsd.irx.udpfs` to `asset_usbhdfsd_irx_usbexfat` in `embed_assets.cpp`, exactly as the mx4sio key is aliased, and drop the two redundant `EMBEDDED_RSC` objects and `BIN2S` rules. The on-disk files stay (the release kit stages/compares them by path), only the duplicate embeds go.
- Benefit: −83,008 bytes in every shipped POPSLOADER.ELF; one less copy to drift when a driver is updated.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BIN-02 — The same binaries are tracked two to four times in git under different paths
- Category: 2
- Locations: POPSTARTER/SMSUTILS.irx:1; bin/POPSLDR/popsmb/SMSUTILS.irx:1; iop/embed/BDMASSAULT_MX4SIO/usbd.irx:1; bin/POPSLDR/POPSTARTER.ELF:1; bin/POPSLDR/PROFILES/DEBUG/POPSTARTER.ELF:1
- Problem: Script-verified byte-identical groups beyond RE-POPS-BIN-01: (a) all six SMB-pack IRX (182,654 B total) exist identically in `POPSTARTER/` and in `bin/POPSLDR/popsmb/` — the popsmb copies are embedded into the ELF by the Makefile while the root copies ship at the release-zip root; (b) the BDMAssault pair (63,493 B) exists identically in `iop/embed/BDMASSAULT_MX4SIO/` and as `bin/POPSLDR/usbd.irx.*` / `usbhdfsd.irx.mx4sio`; (c) `bin/POPSLDR/POPSTARTER.ELF` is byte-identical to `bin/POPSLDR/PROFILES/DEBUG/POPSTARTER.ELF` (167,700 B — see RE-POPS-BIN-03). Redundant tracked bytes across all groups: ~530 KB of the 1,778,343 tracked binary bytes. Each duplicate is an independent drift risk: nothing in CI compares `POPSTARTER/` against `popsmb/` (only the UDPFS pair and the ilink pair have hash pins — see RE-POPS-BIN-05).
- Fix: Keep one canonical copy per distinct binary and have the packaging steps (`tools/build_release_kit.sh`, the rolling/experimental bundle steps) copy from it, instead of tracking the second copy. Where a path is itself a user-facing install location (root `POPSTARTER/`), generate it at bundle time from the canonical popsmb set.
- Benefit: ~530 KB less tracked binary weight; a driver update lands in exactly one place and cannot silently diverge between the embedded copy and the shipped copy.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-BIN-03 — The default shipped POPSTARTER.ELF is the DEBUG profile, not MAIN, and the 1–2 patch bytes that define all five profiles are documented nowhere in the repo
- Category: 6
- Locations: bin/POPSLDR/POPSTARTER.ELF:1040; bin/POPSLDR/PROFILES/MAIN/POPSTARTER.ELF:1040; bin/POPSLDR/PROFILES/USBDELAY/POPSTARTER.ELF:1043; tools/build_release_kit.sh:17-20
- Problem: Script-verified: all five POPSTARTER.ELF files are 167,700 B and differ from the MAIN profile at exactly two byte offsets — offset 1040 (0x00 in MAIN/USBDELAY, 0xFF in DEBUG/USBDELAY_DEBUG) and offset 1043 (2 in MAIN/DEBUG, 6 in USBDELAY/USBDELAY_DEBUG). So the profiles are one binary with two patch bytes, not four builds. The file every workflow and `tools/build_release_kit.sh` ships as *the* `POPSTARTER.ELF` is byte-identical to the DEBUG profile (0xFF at 1040), not to MAIN. No file in `src/`, `tools/`, the Makefile or the workflows names what either byte controls; the names DEBUG/USBDELAY are the only documentation. INFERRED (basis: profile names + the two-byte pattern): byte 1040 is a debug on/off flag and byte 1043 a USB-delay value, which would mean the default install ships with the debug flag on. That may be deliberate — but nothing in the repo says so, and if it is accidental, every release has shipped the debug variant as the default.
- Fix: Record, next to the profiles (or in the packaging script that ships them), what bytes 1040 and 1043 mean and which profile the top-level `POPSTARTER.ELF` is supposed to equal; if MAIN is the intended default, replace the top-level copy with the MAIN bytes and add a hash comparison to the kit verification so the default cannot silently become a different profile again.
- Justification: The hash comparison is an addition; it is justified because the current state — default file identical to a non-default profile, with no recorded intent — is exactly the failure it would catch, and the check is three lines in a script that already does sha256 pins.
- Benefit: The shipped default POPStarter variant becomes a recorded decision instead of an unverifiable accident; a wrong-profile copy is caught by CI rather than by a tester.
- Effort: S · Risk: Low · Confidence: Med (INFERRED — byte-difference facts are script-verified READ; the meaning of the bytes and whether DEBUG-as-default is wrong are INFERRED)

### RE-POPS-BIN-04 — Three iop/embed binaries and one vendored IOP source tree are dead: nothing builds, embeds or loads them
- Category: 1
- Locations: iop/embed/bdmfs_vfat.irx:1; iop/embed/mx4sio_bd_mini.irx:1; iop/embed/PS2SDK_MX4SIO/mx4sio_bd.irx:1; Makefile:338-350; iop/ata_bd_fast/ps2atad.c:1
- Problem: `iop/embed/bdmfs_vfat.irx` (30,013 B), `iop/embed/mx4sio_bd_mini.irx` (13,897 B) and `iop/embed/PS2SDK_MX4SIO/mx4sio_bd.irx` (15,089 B) are requested by no `IOP_MODULES` entry, no explicit Makefile rule and no Lua/C++ loader reference (grep-verified across Makefile, `src/`, `bin/POPSLDR/*.lua`); the generic `vpath %.irx iop/embed/` rule cannot even reach the PS2SDK_MX4SIO copy because vpath is not recursive. The Makefile itself says the PS2SDK_MX4SIO copy was de-pinned and "left in place, untouched" (Makefile:346-350), and says the same of the vendored `iop/ata_bd_fast/` source (46,533 B of C plus build files): its build rule is "kept but unused" because the embedded `ata_bd.irx` is pinned to a different binary (Makefile:338-343). Total dead weight: 58,999 B of binaries plus ~55 KB of source that a reader will reasonably assume is what ships.
- Fix: Delete the three binaries and the `iop/ata_bd_fast/` tree (git history preserves both). If `ata_bd_fast` is kept as reference for the pinned binary, it belongs in the provenance record of RE-POPS-BIN-05 saying so in one line — not as a buildable-looking source tree with its own Makefile rule.
- Benefit: −59 KB of tracked binaries and one whole misleading source tree; "what source produced this IRX" stops having a wrong-looking answer.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BIN-05 — 23 of 26 distinct binaries have no in-repo source, and most of them have no hash pin or provenance record either — a silent byte swap would pass CI
- Category: 6
- Locations: tools/test_udpfs_integration.py:17-23; tools/build_release_kit.sh:43-48; .github/workflows/compilation.yml:89-95; docs/third_party/okeanos_udpfs/PROVENANCE.json:1
- Problem: Provenance census (full table below; INFERRED, basis stated per row): only the BDMAssault core (`5ea4818b…`) and the usbmass_bd blob (`70a369e4…`) have corresponding source in this repo, inside `iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz`; `ata_bd.irx` is partial (vendored cousin source, pinned binary from elsewhere). The other 23 distinct binaries — the whole SMB pack, all four POPSTARTER.ELF variants, the ATA and MMCE BDMA pairs, the menu UDPFS trio — are opaque blobs. Pinning is inconsistent: the UDPFS pair has an exemplary `PROVENANCE.json` plus SHA-256 checks, the ilink pair is pinned in `tools/build_release_kit.sh:46-47`, `ata_bd.irx` is pinned in three workflows, and `tools/test_udpfs_integration.py:17-23` pins five blobs by git-blob SHA-1. Everything else embedded into the ELF (six popsmb IRX, the ATA/MMCE/usbexfat BDMA pairs) has no recorded expected hash anywhere: replace one with different bytes and every CI gate stays green.
- Fix: Extend the existing pin table — one file listing SHA-256, size, upstream origin and licence for every tracked binary, checked by the step that already exists in the lua-harness job — instead of the current three separate pinning mechanisms covering disjoint subsets.
- Justification: This adds a table and a check. It is justified by a concrete gap: these binaries run on the IOP with full hardware access, ship in every release, and for most of them the repo currently cannot distinguish "maintainer updated the driver" from "bytes changed".
- Benefit: Every shipped binary gets the UDPFS pair's standard of provenance; driver updates become deliberate, reviewable diffs.
- Effort: M · Risk: Low · Confidence: High (READ for the pin-coverage facts; INFERRED for the per-binary source census, basis in the inventory table)

### RE-POPS-BIN-06 — Every rolling and experimental release zip embeds a full copy of the entire tracked tree, including the 21 MB research archive
- Category: 4
- Locations: .github/workflows/rolling-release.yml:228; .github/workflows/experimental-release.yml:224
- Problem: Both bundle steps copy every path from `git ls-files` into a `source/` folder inside the release zip (rolling-release.yml:228, experimental-release.yml:224; only `POPSTARTER/` is excluded because it ships separately). Script-verified: the tracked tree is 30,417,169 B, of which `.research/` alone is 312 files / 21,197,583 B (70%) — historical POPStarter downloads, screenshots and the docs-site corpus. So each rolling/experimental zip carries the whole research archive plus the 1.4 MB BDMAssault tarball and every tracked binary a second time (they also ship at the zip root / in the kit), on top of the actual payload.
- Fix: Exclude `.research/` (and any other non-build-input trees) from the `source/` copy, or drop the `source/` copy and point the release notes at the tagged repository tree, which GitHub already serves as a source archive.
- Benefit: Roughly 21 MB off every rolling/experimental download; the "source" in the zip matches what a user needs to rebuild.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BIN-07 — Byte-identical duplicates inside the research archive and the root docs
- Category: 2
- Locations: .research/assets/1165364186-Playstation-Button-L2.png:1; .research/assets/1258137434-pops05_zps81df52b9.jpg:1; OFFICIAL_NOTES.md:1; RELEASE_1.4.4.md:1
- Problem: Script-verified duplicate groups inside `.research/assets/`: six pairs where the same image is tracked under both a numeric-prefix name and a plain name (Playstation-Button-L2, -R2, -T ×2 files, -Select, `356screenshot1.gif`, `pops05_zps81df52b9.jpg`) — 57,552 redundant bytes. Separately, `OFFICIAL_NOTES.md` and `RELEASE_1.4.4.md` are byte-identical (1,841 B, same SHA-256), two root files that will drift apart at the next release edit.
- Fix: Delete one member of each duplicate pair (keep the name the site generator references) and delete `OFFICIAL_NOTES.md` or make it a one-line pointer to the release-notes file.
- Benefit: Small but free: −59 KB and one guaranteed future doc contradiction removed.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BIN-08 — The build pipeline is triplicated across three workflows; the same gates and the same ~170-line publish script are maintained in three places
- Category: 2
- Locations: .github/workflows/compilation.yml:112-176; .github/workflows/rolling-release.yml:106-170; .github/workflows/experimental-release.yml:102-166; .github/workflows/rolling-release.yml:339-519; .github/workflows/experimental-release.yml:270-501
- Problem: The Lua-syntax gate (~55 lines, including its explanatory comment history), the in-container host-harness step, the embedded-build-identity step and the bundle step appear near-verbatim in compilation.yml, rolling-release.yml and experimental-release.yml; the GitHub-API publish logic (release upsert, asset replace, stale-zip cleanup) is a ~170-line inline Python program duplicated between rolling-release.yml and experimental-release.yml with only names/notes/tag changed. The comments show the cost: the luac-gate fix ("it used to silently skip…") had to be written identically into all three files, and RE-POPS-BIN-10 is what happens when one copy is not updated.
- Fix: Extract the shared gates into one reusable workflow (or composite action) called by all three, and the publish Python into one script under `tools/` parameterised by channel (tag, notes file, asset prefix) — the rolling and experimental copies already differ only in those parameters.
- Benefit: A gate fix lands once; the three channels cannot silently diverge in what they check before publishing.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-BIN-09 — Two workflows are single-use artifacts: the official-release workflow is hardcoded to 1.4.4, and the retract workflow can only ever fire on its own edit
- Category: 8
- Locations: .github/workflows/official-release.yml:1; .github/workflows/official-release.yml:47-49; .github/workflows/official-release.yml:96-105; .github/workflows/retract-mislabeled-ember-beta.yml:5-9
- Problem: `official-release.yml` hardcodes the version in its name (line 1), concurrency group (line 17), version greps (`POPSLDR_VER = "v1.4.4"`, `Version=1.4.4`, `RELEASE_1.4.4.md` at lines 47-49), asset names and manifest text (lines 96-105) — the next release requires rewriting the workflow itself, and a missed spot publishes a mismatched release or fails closed late. `retract-mislabeled-ember-beta.yml` triggers only on a push to master that changes its own file (lines 5-9); it already performed its one deletion (its step exits 0 when the release is absent), so it is now inert automation that still runs a contents:write job if anyone touches the file.
- Fix: Parameterise official-release.yml from the tag/version it is releasing (derive the version from `etc/boot.lua` as the rolling workflow already does) so a release is data, not a workflow edit; delete retract-mislabeled-ember-beta.yml — its work is done and git history preserves it.
- Benefit: One less per-release workflow rewrite (a classic place to ship a wrong-version release); one less write-permissioned workflow sitting in the repo.
- Effort: M · Risk: Med · Confidence: High (READ)

### RE-POPS-BIN-10 — The publishing channels run a weaker gate set than CI: docs_verify runs only in compilation.yml, and the experimental channel also skips the PNG decoder harness
- Category: 7
- Locations: .github/workflows/compilation.yml:49-55; .github/workflows/rolling-release.yml:28-57; .github/workflows/experimental-release.yml:31-53
- Problem: compilation.yml's lua-harness job runs `tools/png_decoder_harness.py`, the host/pad/disc/UDPFS-config harnesses, `tools/docs_verify.py` (line 52) and the translation tests. The rolling-release lua-harness job — the gate for the channel users actually download — omits `docs_verify.py`; the experimental-release lua-harness job omits both `docs_verify.py` and `png_decoder_harness.py`. A doc/source drift or a PNG-decoder regression therefore cannot fail the builds that publish, only the CI build that does not.
- Fix: Add the missing step(s) to the rolling and experimental harness jobs (one line each; both are stdlib/host tools that already run in the sibling job) — or, with RE-POPS-BIN-08 done, inherit the shared gate.
- Benefit: The publishing channels enforce the same claims CI enforces; `docs_verify`'s stated purpose (it "sat unwired and red for months" once already, per compilation.yml:49-51) is not defeated by wiring it to the non-publishing workflow only.
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BIN-11 — opencode workflow runs an unpinned third-party action (`@latest`) with an API-key secret in its environment
- Category: 6
- Locations: .github/workflows/opencode.yml:27-32
- Problem: `opencode.yml:29` uses `anomalyco/opencode/github@latest` — whatever that action's master holds at run time executes in a job holding `DEEPSEEK_API_KEY` (line 31) and an `id-token: write` permission (line 17). The repo itself demonstrates the correct pattern one directory over: rolling-release.yml pins its credential-holding third-party action to a full commit SHA with a comment explaining why (the MEGA action). This workflow is the exception.
- Fix: Pin the opencode action to a reviewed full commit SHA, as the MEGA action is pinned, and bump deliberately.
- Benefit: Closes the one supply-chain hole in an otherwise carefully pinned workflow set (ps2dev image pinned, checkout pinned by major, MEGA action SHA-pinned).
- Effort: S · Risk: Low · Confidence: High (READ)

### RE-POPS-BIN-12 — test_udpfs_integration.py is named an integration test but is mostly substring-presence assertions on source text
- Category: 7
- Locations: tools/test_udpfs_integration.py:35-79
- Problem: Judged against its name: the blob half is real (hash/size/ELF-header pins, PROVENANCE.json cross-check, and — when passed a kit zip — byte comparisons against the packaged files). But the "integration" half (lines 35-79) is ~45 `assert "literal string" in file_text` checks over ui.lua, system.lua, luasystem.cpp, embed_assets.cpp and the Makefile. Those pass if the string survives in a comment and fail on any rename/refactor that preserves behaviour, i.e. they test spelling, not integration. The genuinely behavioural UDPFS coverage already exists in `tools/test_udpfs_config_runtime.py`, which executes the real Lua — this file's name promises the same class of proof and does not deliver it.
- Fix: Rename the file to reflect what it pins (e.g. `test_udpfs_pins.py`) and move the handful of wiring literals that matter into the runtime harness as executable checks over time; do not add more substring asserts.
- Benefit: The next reader (and CI triage) can tell which gate proves behaviour and which proves bytes; refactors stop failing a "test" that never ran the code.
- Effort: M · Risk: Low · Confidence: High (READ)

---

## Binary inventory (script-verified: size + SHA-256; identity by `strings` only)

Distinct = 26 hashes over 38 paths. "Source in repo?" basis: **tarball** = matching component source inside `iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz` (extracted to `/tmp/redo-bdma`; string/component-name match, no rebuild performed — INFERRED); **partial** = a cousin source exists but the Makefile states the shipped binary comes from elsewhere; **No** = no corresponding source found in `src/`, `modules/`, `iop/` or the tarball (INFERRED from directory census + grep).

| Path | Size | SHA-256 (short) | Identity (strings) | Source in repo? |
|---|---|---|---|---|
| POPSTARTER/SMSUTILS.irx | 1,305 | 91daae46a300 | `smsutils` IOP module | No |
| POPSTARTER/poweroff.irx | 3,413 | 573863a0f9b2 | `poweroff` / Poweroff_Handler | No |
| POPSTARTER/ps2dev9.irx | 11,505 | e2b83bb01a59 | `dev9_driver`, "DEV9 device driver … © 2003 Marcus R. Brown" | No |
| POPSTARTER/ps2ip.irx | 109,497 | 1bf99ca297dc | PS2IP (lwIP stack), few strings | No |
| POPSTARTER/ps2smap.irx | 12,605 | 671fe9e3c5e0 | `smap_driver`, "Version 2.25.0" | No |
| POPSTARTER/smbman.irx | 44,329 | 000296a2f030 | `smbman` (SMB1 client) | No |
| bin/POPSLDR/popsmb/SMSUTILS.irx | 1,305 | 91daae46a300 | = POPSTARTER/ copy | No |
| bin/POPSLDR/popsmb/poweroff.irx | 3,413 | 573863a0f9b2 | = POPSTARTER/ copy | No |
| bin/POPSLDR/popsmb/ps2dev9.irx | 11,505 | e2b83bb01a59 | = POPSTARTER/ copy | No |
| bin/POPSLDR/popsmb/ps2ip.irx | 109,497 | 1bf99ca297dc | = POPSTARTER/ copy | No |
| bin/POPSLDR/popsmb/ps2smap.irx | 12,605 | 671fe9e3c5e0 | = POPSTARTER/ copy | No |
| bin/POPSLDR/popsmb/smbman.irx | 44,329 | 000296a2f030 | = POPSTARTER/ copy | No |
| bin/POPSLDR/POPSTARTER.ELF | 167,700 | 3ec327085ecc | POPStarter (packed EE ELF, no section header); = DEBUG profile | No |
| bin/POPSLDR/PROFILES/MAIN/POPSTARTER.ELF | 167,700 | 734c813e8e8e | POPStarter; byte1040=0x00, byte1043=2 | No |
| bin/POPSLDR/PROFILES/DEBUG/POPSTARTER.ELF | 167,700 | 3ec327085ecc | POPStarter; byte1040=0xFF, byte1043=2 | No |
| bin/POPSLDR/PROFILES/USBDELAY/POPSTARTER.ELF | 167,700 | 613b16e1823a | POPStarter; byte1040=0x00, byte1043=6 | No |
| bin/POPSLDR/PROFILES/USBDELAY_DEBUG/POPSTARTER.ELF | 167,700 | 9bab715aa17f | POPStarter; byte1040=0xFF, byte1043=6 | No |
| bin/POPSLDR/usbd.irx.usbexfat | 48,500 | 5ea4818ba1cf | BDM core + FatFs, "BDM_ASSAULT: starting Fatfs side" | **Yes — tarball** (`__bdm_assault/`, `bdm/`, `bdmfs_fatfs/`) |
| bin/POPSLDR/usbd.irx.mx4sio | 48,500 | 5ea4818ba1cf | identical copy of the above | **Yes — tarball** |
| bin/POPSLDR/usbd.irx.ilink | 48,500 | 5ea4818ba1cf | identical copy of the above | **Yes — tarball** |
| iop/embed/BDMASSAULT_MX4SIO/usbd.irx | 48,500 | 5ea4818ba1cf | identical copy of the above | **Yes — tarball** (sits beside it) |
| bin/POPSLDR/usbd.irx.ata | 42,749 | 4e1d39365854 | BDM core + FatFs, strings prefixed `USBHDFSD:` (R3Z3N ATA build per embed_assets.cpp) | No |
| bin/POPSLDR/usbd.irx.mmce | 11,841 | 0fed25d9eecd | `iomanx` dummy/devnull-style driver (dummytty strings); no USB code visible in strings | No |
| bin/POPSLDR/usbd.irx.udpfs | 61,949 | d1d5502454fb | "UDPFS mass driver" + dev9/smap + UDPFSCONFIG.DAT logic (Okeanos UDPFS Assault 1.0.1 per PROVENANCE.json) | No (provenance documented, source external) |
| bin/POPSLDR/usbhdfsd.irx.usbexfat | 34,508 | 70a369e47745 | `usbmass_bd`, "USBD ASSAULT Start" | **Yes — tarball** (`__usbd_bd_assault/src/usbmass_bd/`, `usbmass_bd/`) |
| bin/POPSLDR/usbhdfsd.irx.udpfs | 34,508 | 70a369e47745 | identical copy of the above (PROVENANCE.json source name: `usbd_bd_assault.irx`) | **Yes — tarball** |
| bin/POPSLDR/usbhdfsd.irx.mx4sio | 14,993 | 61525fab3b34 | `mx4sio`, "MX4SIO: MX4SIO v1.2" (SD-card transport in the usbhdfsd slot) | No (no mx4sio source in tarball) |
| iop/embed/BDMASSAULT_MX4SIO/usbhdfsd.irx | 14,993 | 61525fab3b34 | identical copy of the above | No |
| bin/POPSLDR/usbhdfsd.irx.ata | 21,837 | 1cc865cd0999 | ATA transport merged with dev9 + atad strings ("USBHDFSD: starting ATA mass transport") | No |
| bin/POPSLDR/usbhdfsd.irx.ilink | 27,769 | 9cd849ea7f06 | `iLinkmand` / SBP2 IEEE1394 driver | No (pinned to RiptOPL commit in build_release_kit.sh:8,46) |
| bin/POPSLDR/usbhdfsd.irx.mmce | 19,733 | 9f7b77848935 | "Fake mass for mmce", MMCEMAN v%d.%d | No |
| iop/embed/ata_bd.irx | 11,917 | 16c5d9f00d64 | `atad`, "ATA device driver … © 2003 Marcus R. Brown" (R3Z v4.70 probe-fixed, per Makefile) | Partial — `iop/ata_bd_fast/ps2atad.c` is a cousin source; Makefile says the binary is pinned from elsewhere and that source is unused |
| iop/embed/bdmfs_vfat.irx | 30,013 | 8536a93f3cd1 | `bdmvfat`, "BDM VFAT driver (FAT12/16/32)" | No — and dead (RE-POPS-BIN-04) |
| iop/embed/mx4sio_bd_mini.irx | 13,897 | f7fd0c13ce00 | `mx4sio` (packed/obfuscated-looking string table) | No — and dead (RE-POPS-BIN-04) |
| iop/embed/PS2SDK_MX4SIO/mx4sio_bd.irx | 15,089 | 3185e57e0651 | `mx4sio`, "MX4SIO v1.2" — near-twin of 61525fab (49 vs 50 strings, +96 B) | No — and dead (RE-POPS-BIN-04) |
| iop/embed/udpfs_ioman.irx | 11,633 | 85faad5631fa | `udpfs` ioman, UDPFS send/recv retry strings (menu-side stack) | No |
| iop/embed/udpfs_ministack.irx | 5,025 | 854060627190 | `ministack`, "TTY via Udp" | No |
| iop/embed/udpfs_net_smap.irx | 8,081 | 4b81d9bf0c17 | SMAP network driver for the mini stack (imports only in strings) | No |

Profile verdict (asked explicitly): the five POPSTARTER.ELF files are **not** five builds. They are one 167,700-byte binary in four distinct hash variants, differing only at offsets 1040 (0x00/0xFF) and 1043 (2/6) — a 2×2 patch-byte matrix (MAIN / DEBUG / USBDELAY / USBDELAY_DEBUG), with the top-level shipped copy equal to DEBUG.

Naming note (strings-derived, INFERRED): in every BDMA pair the file named `usbd.irx.*` is the BDM/FatFs core and the file named `usbhdfsd.irx.*` is the transport (USB mass / MX4SIO / ATA / iLink / MMCE / UDPFS) — POPStarter loads the two slots by filename, so the names are slot names, not contents. This is coherent, but it means `usbhdfsd.irx.mx4sio` containing an SD driver and `usbd.irx.mmce` containing no USB code are expected, not mislabels.

---

## Workflow / tools notes

Workflows (all 10 read in full):

| File | Lines | Verdict |
|---|---|---|
| compilation.yml | 253 | CI gate + build + kit verify. The only workflow running docs_verify (see RE-POPS-BIN-10). Runs the full tool battery twice over (lua-harness job and again host-harness inside the container build job, where it self-skips without lupa). |
| rolling-release.yml | 576 | dev channel. Publishes only on push (PR gate present and commented). MEGA archive job correctly SHA-pins its third-party action. Bundle copies the whole tree (RE-POPS-BIN-06). |
| experimental-release.yml | 501 | experimental channel. Near-copy of rolling (RE-POPS-BIN-08); weakest harness job (RE-POPS-BIN-10). |
| official-release.yml | 131 | Publishes the exact CI artifact — good pattern, hardcoded version — RE-POPS-BIN-09. |
| docs-site.yml | 165 | Rebuilds the gh-pages site from `.research/`; deploy gated to push on dev. Depends on `.research/tools/*.py` (17 files, verified tracked). |
| wiki-sync.yml | 93 | Publishes `docs/wiki/` via `tools/sync_native_wiki.py --self-test` first; token handled via askpass, not embedded in URLs. Clean. |
| ember-watch.yml | 157 | Weekly; verifies Ember digest against both the upstream release and the RiptOPL pin before editing `tools/build_release_kit.sh`, commits to dev. Sound design. |
| research-network-driver-integrity.yml | 114 | PR-path-scoped forensic checks over `.research/downloads/` archives; all referenced `.research/tools/*.py` verified tracked. Pure archive archaeology — legitimate, but it is a fourth CI surface maintaining the research corpus, not the product. |
| retract-mislabeled-ember-beta.yml | 40 | One-shot, now inert — RE-POPS-BIN-09. |
| opencode.yml | 32 | Unpinned action + secret — RE-POPS-BIN-11. |

Tools (all 13 read; host-runnable ones executed in a `/tmp` copy of the tree at the same pin):

| Tool | Lines | What it actually does / name accuracy | Run result |
|---|---|---|---|
| host_harness.py | 2,759 | Executes the real `system.lua`+`ui.lua` under mocked PS2 APIs (lupa), 62 distinct named checks (T1–T62). Name accurate; the strongest tool in the repo. | **62/62 PASS** |
| test_udpfs_config_runtime.py | 319 | Executes the real UDPFS IPv4 validators and `PrepareUdpfsConfig`/launch scenarios in fresh Lua VMs. Name accurate. | **PASS** (26 IPv4 scenarios + ~27 scenario blocks, 0 failures) |
| test_disc_layout.py | 56 | Extracts the real disc-icon draw block from ui.lua by string anchors and asserts geometry over 30 cases. Name accurate; anchor-based extraction is brittle to comment edits at the anchors, noted not faulted. | **PASS 30 cases** |
| test_translation_handoff.py | 91 | Real unittest suite (7 tests) over translation_handoff.py incl. synthetic XLSX/TSV fixtures. Name accurate. | **7/7 PASS** |
| test_udpfs_integration.py | 117 | Hash pins + substring asserts + kit-zip verification. Name overclaims — RE-POPS-BIN-12. | **PASS** (no-arg mode) |
| pad_harness.py | 131 | Compiles the real `src/pad.cpp` against stubbed libpad and asserts 13 timing/state behaviours. Name accurate. | **13/13 PASS** |
| png_decoder_harness.py | 187 | Compiles the real decoder slice of `src/graphics.cpp` against host libpng under ASan+UBSan, 15 PNG families × file/memory × delayed/immediate. Name accurate. | **60/60 PASS** |
| docs_verify.py | 259 | Mechanical doc/source drift checks (settings keys, version stamps, harness count, removed-behaviour phrases). Does what it claims. | **PASS** (notes only; confirms 29 settings keys, 62 harness checks) |
| lua_minify.py | 169 | Comment/whitespace stripper with a token-stream self-check that hard-fails the build on any change. Verified: system.lua 571,596 → 402,552 B; ui.lua 370,543 → 204,778 B; images.lua 2,702 → 2,023 B. Caveat (documented in its own docstring): a python3-less local build embeds the raw file, so local and CI ELFs differ. | **PASS** (3 files, self-check green) |
| package_psu.py | 102 | Builds/verifies the flat PSU; exact-file-set enforcement. Verified synthetically with a dummy 8-file payload (build + verify round-trip) since a real payload needs a compiled POPSLOADER.ELF. | **PASS** (synthetic) |
| sync_native_wiki.py | 158 | Wiki publisher with link rewriting, idempotence and overwrite guards; `--self-test` exercises all of it. | **PASS** (self-test) |
| translation_handoff.py | 250 | TSV/XLSX translator-handoff validator/converter; rejects formulas, unknown keys, placeholder drift. | **PASS** (`check_catalogs` clean) |
| build_release_kit.sh | 89 | Assembles the release kit from two pinned RiptOPL commits (network clone to a fixed `/tmp/riptopl-kit` path), byte-compares the POPS/EMBER payloads, pins the ilink pair by SHA-256, cross-verifies the PSU with RiptOPL's own C++ reader, strips any `bios.bin`. Not run here (needs network clone + a built ELF); read in full. Sound; the fixed `/tmp` path means a failed clone leaves state the next run must trip over (`set -eu` makes that fail-closed). | not run (by design) |

Makefile / repo-hygiene notes:

- Root Makefile (448 lines, read in full): release path is the workflows; the old `make package` target was deliberately deleted (comment at the `dummys` block) — good. Remaining oddities: `dummys`/`cleandummy` targets still create A.vcd–Y.vcd test files; the `EMBED/%.png` generic rule (Makefile:145) has no inputs — `EMBED/` contains exactly one file, `builtin_font.ttf` (133,488 B), used via the `%.ttf` rule.
- `.gitignore` (123 lines) vs tracked set: the blanket `*.elf`/`*.irx`/`*.ttf` rules plus explicit negations for every shipped binary were audited against `git ls-files` — every tracked binary in the inventory is covered by a negation, and **no `__pycache__`/`.pyc` is tracked** (`tools/__pycache__/` exists on disk from local runs and is correctly ignored, .gitignore:122). No finding.
- `bin/` asset tree: all 69 files under `bin/POPSLDR/IMG/` are hash-distinct (script-verified — no duplicate image assets in `bin/`); the duplicates that exist are the binary groups in RE-POPS-BIN-02 and the `.research` pairs in RE-POPS-BIN-07. `bin/POPSLDR/del.icn.bdma` = `POPSTARTER/del.icn` and `list.icn.bdma` = `POPSTARTER/list.icn` byte-identically (the non-`.bdma` `bin/POPSLDR/*.icn` differ) — two more members of the RE-POPS-BIN-02 pattern, icon-sized.
- `.gitattributes`: `* text=auto` with a `binary` carve-out only for `.research/ui/*.png` — the tracked PNG/JPG corpus elsewhere relies on git's binary detection; no corruption evidence found in hashes/strings, noted as an observation only.

---

## FILES READ

Clone root (`~/workspace/audit-clones-2026-11-13/POPSLoader` @ 29272cddbf01): `Makefile` (full), `.gitignore` (full), `.gitattributes` (full), `AGENTS.md` (full), `src/embed_assets.cpp` (full), `docs/UDPFS_BDMA.md` (full), `docs/third_party/okeanos_udpfs/PROVENANCE.json` (full), `docs/third_party/okeanos_udpfs/THIRD_PARTY_NOTICES.md` (full), `iop/embed/BDMASSAULT_MX4SIO/README.MD` (full).
Workflows (all 10, full): `.github/workflows/compilation.yml`, `docs-site.yml`, `ember-watch.yml`, `experimental-release.yml`, `official-release.yml`, `opencode.yml`, `research-network-driver-integrity.yml`, `retract-mislabeled-ember-beta.yml`, `rolling-release.yml`, `wiki-sync.yml`.
Tools (all 13, full except as noted): `tools/build_release_kit.sh`, `docs_verify.py`, `lua_minify.py`, `package_psu.py`, `pad_harness.py`, `png_decoder_harness.py`, `sync_native_wiki.py`, `test_disc_layout.py`, `test_translation_handoff.py`, `test_udpfs_config_runtime.py`, `test_udpfs_integration.py`, `translation_handoff.py` (all full); `tools/host_harness.py` (structure, all 62 check names and harness core read; not every Lua mock line).
Binaries: all 38 tracked binaries hashed/sized by script; `strings` extracted for all 26 distinct hashes; byte-diff offsets computed by script for the 5 POPSTARTER.ELF files; BDMAssault tarball file census (full listing) with component directories matched to binary strings.
Also read by script/grep for provenance and reference checks: `iop/ata_bd_fast/` (listing + string match in `ps2atad.c`), `git ls-files` census of the whole tree (609 files) including `.research/` counts and duplicate-hash census over every tracked file.

## FILES NOT READ

- All `src/*.cpp` / `src/*.h` except `src/embed_assets.cpp` (menu C++ is another section's scope); `src/luasystem.cpp` was only grep-matched by `tools/test_udpfs_integration.py`'s assertions and my reference grep, not read.
- `bin/POPSLDR/*.lua` (system.lua 11,784 lines, ui.lua 7,599 lines, images.lua, boot inputs) — executed by the harnesses and grep-checked, not read line-by-line (Lua logic is another section's scope).
- `etc/boot.lua` beyond its first 40 lines and the `POPSLDR_VER` line; `etc/update_lua_globals.sh` not read.
- Root prose docs (`STATE.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `COMPONENTS.md`, `README.md`, `QA_REGRESSION_MATRIX.md`, `EXPERIMENTAL_NOTES.md`, `ROLLING_NOTES.md`, `ROADMAP.md`, `TESTING.md`, `CONTRIBUTING.md`, release-notes files) — not read, except grep hits for `usbd.irx` provenance context and the byte-identity of `OFFICIAL_NOTES.md`/`RELEASE_1.4.4.md` established by hash.
- `docs/` other than `docs/UDPFS_BDMA.md` and the two `docs/third_party/okeanos_udpfs/` files named above (other third-party notices, `docs/wiki/**`, audit archives in `docs/` not read).
- `.research/` contents beyond the tracked-file census, hash-duplicate scan and the workflow-referenced paths (its build/audit scripts and corpus are not read; `.research/tools/*.py` verified tracked by listing only).
- `modules/` and `iop/` sources beyond listings and the `ata_bd_fast` string match (`modules/ds34*/**`, `iop/bdm_query/**` not read).
- BDMAssault tarball source files: directory/file census and names only; individual `.c`/`.h` contents not read.
- `bin/POPSLDR/` non-binary assets (`APPINFO.PBT`, `title.cfg`, `icon.sys*`, `*.icn*` contents, `PATCH_5.BIN`, `boot.adp`, `IMG/*` pixels) — hashed/listed only, contents not inspected.
- `.vscode/`, `banner.jpg`, `imageformat.png`, `LICENSE` — not read.
