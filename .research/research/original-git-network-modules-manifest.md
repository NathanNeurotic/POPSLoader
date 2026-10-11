# Forensic directory audit: currently hosted `network_modules.7z`

**Later byte-level update (supersedes the metadata-only limitation recorded below):** [Full 12/12 decompressed 7z member CRC verification and 6/6 driver SHA-256 equality against the 2020 SMB ZIP](original-git-network-quickstarter-overlap.md#full-decompressed-payload-verification--2026-10-10-supersedes-metadata-only-caveat-above), confirmed by [successful GitHub Actions run #38113818669](https://github.com/NathanNeurotic/POPSLoader/actions/runs/38113818669). Earlier directory-only language is retained as research chronology; it no longer describes the current verification state.


**Status:** read-only, based on authenticated *current repository bytes*. The historic Bitbucket source archive itself is **unavailable**. No files have been executed or extracted into a distributable package, and no driver version or real-hardware behavior has been certified.

**New provenance lead (2026-10-11):** In [krHACKen's 2015-10-23 SMB/Beta 8 developer announcement](https://www.metagames-eu.com/forums/playstation-2/popstarter-revision-13-a-20-134569.html), the developer identified an earlier and separately named `POPStarter_Net_Modules_for_mc0.zip` distribution for the original network drivers and configuration templates. No authentic bytes for that archive have been retrieved. It is a **pre-2017 packaging/source lead**, not proof of equivalence with either the original 2017 `network_modules.7z` or today's 7z/2020 ZIP. See [dated source timeline](original-git-2015-network-and-patch9-timeline.md).

## Provenance and discrepancy

| Evidence | Value |
|---|---|
| Hosted file | `.research/downloads/network_modules.7z` |
| GitHub `master` Git blob | `a45c67dd2a90ba47d8d34466edadcf8a859e94ec` |
| Hosted archive length | **93,934 bytes** |
| Historical Bitbucket uploads listing | [Original preserved download index](https://archive.ph/PBG1V): `network_modules.7z`, **59.0 KB**, uploaded by **Shaolin Assassin** on **2017-10-27** |
| Original wiki HEAD download reference | `smb-mode.textile` line 20, original `960d675d` |
| GitHub file introduction | `d1bc30a24b81` (**2026-07-28**, initially tracking the reconstructed site corpus; no earlier repository commit for this filename found) |
| Full original payload byte comparison | **Unavailable**: 2017 source's member manifest and hashes have not been independently obtained |

The current file is almost certainly **not** an archive byte-for-byte duplicate of the 2017 upload given the large compressed-size discrepancy. The Bitbucket listing gives rounded display size only, but **59.0 KB vs 93,934 B** is far beyond rounding. The filenames matching is **not proof of contained driver equivalence**.

## Validated current-directory metadata

Retrieved the repository's *base64 source content*, decoded the 7z signature/start-header and next header, decompressed **only the LZMA1-encoded directory header** (353 compressed bytes → **874 uncompressed header bytes**), and verified the directory's declared CRC-32 **`AEAC064F`** against the decompressed header. The start/next header metadata also parses consistently. The file declares **12 members** under the **`POPSTARTER/`** folder, with a combined **300,384 unpacked member bytes**.

| Directory member (current archive) | Declared uncompressed bytes | Stored member CRC-32 | Group |
|---|---:|---|---|
| `POPSTARTER/IPCONFIG.DAT` | 30 | `1291EFBD` | Network configuration |
| `POPSTARTER/SMBCONFIG.DAT` | 40 | `C692C5FD` | SMB configuration |
| `POPSTARTER/icon.sys` | 964 | `524C7518` | Memory-card icon metadata |
| `POPSTARTER/popstarter.icn` | 33,688 | `B86505A4` | Memory-card icon |
| `POPSTARTER/poweroff.irx` | 3,413 | `ED3C7537` | Network |
| `POPSTARTER/ps2dev9.irx` | 11,505 | `5A99CB71` | Network |
| `POPSTARTER/ps2ip.irx` | 109,497 | `55A708D1` | Network |
| `POPSTARTER/ps2smap.irx` | 12,605 | `5A893F10` | Network |
| `POPSTARTER/smbman.irx` | 44,329 | `86A433F3` | Network |
| `POPSTARTER/smsutils.irx` | 1,305 | `7312FEA0` | Network |
| `POPSTARTER/usbd.irx` | 48,500 | `E83F6386` | USB |
| `POPSTARTER/usbhdfsd.irx` | 34,508 | `54FE9645` | USB |
| **Total** | **300,384** | | **12 files** |

Counts by group: **six network IRXs = 182,654 uncompressed bytes**; **two USB IRXs = 83,008**; **two memory-card icon files = 34,652**; **two configuration DAT files = 70**. The *names and declared lengths* match decoded 7z directory metadata, whose compressed header was checksum-validated.

**Important distinction:** the CRC-32 values in the table are **stored member checksums**, not CRCs independently recomputed from fully decompressed member data. The packed *solid member-data stream* was **not** decompressed or inspected; only the short directory stream was decompressed. This report makes **no claim** of passing an end-to-end 7z payload verification.

## Relationship to original wiki instructions

The original `smb-mode.textile` and recovered `.research/wiki/smb-mode.md` require the **six network drivers**: `poweroff.irx`, `ps2dev9.irx`, `ps2ip.irx`, `ps2smap.irx`, `smbman.irx`, `smsutils.irx`. The current archive contains all six as well as **two USB modules**, **two configuration templates**, and **two memory-card icon files**. The extra members make the current archive a broader package than the required six network IRXs and could explain **part** of the original-versus-hosted compressed-size difference. **It is not evidence that the original 2017 59.0 KB archive omitted those members**, since its own directory bytes are absent.

PS2 SDK, IOP module version, SMB protocol compatibility, module CRC equality, and hardware behavior remain **unknown**. Do not equate an archive-member filename with the particular upstream module build.

## Reproduce in a local repository checkout

```bash
python3 .research/tools/inspect_network_modules_header.py .research/downloads/network_modules.7z
```

The companion audit tool is **read-only**. It parses signature/encoded-header CRCs, LZMA1 directory metadata, and the declared member list; it explicitly refuses other archive layouts rather than guessing. Syntax checking and both positive/negative header tests were performed with a synthetic *header-only* 7z test fixture reconstructed from the authentic captured directory metadata; a corrupt encoded header caused a failure. A header-only test cannot validate the real payload stream.

A separate 7z or libarchive tool may be used for authorized future full-file payload CRC verification; do not execute any IRX binaries or overwrite the original 2017 release until an authenticated source is found.

## Next decision

Keep the current archive unchanged. An eventual trusted comparison requires authentic **2017-10-27 original archive bytes** (or a verifiable original member manifest) and then member-by-member SHA-256/CRC, version strings and legal-distribution review. This is an **open provenance gap**, not grounds to delete or replace the hosted archive.

## Independent second-source driver-manifest cross-check (2020 SMB quickstarter)

To test whether the six hosted SMB drivers were uniquely repacked, fetched the **full 280,193-byte** tracked `.research/downloads/POPStarter_SMB_Quickstarter_Pack_20200209.zip` (Git blob `909426a2721d8eed1a10ee8a2c7ee0a2e6f9f413`) with the GitHub connector, decoded its actual ZIP central directory in a separate read-only inspection, and compared every declared SMB-driver `(uncompressed size, CRC-32)` pair to the previously checksum-validated directory of the hosted `network_modules.7z`.

| SMB driver | Hosted network_modules.7z bytes / stored CRC-32 | February 2020 SMB ZIP bytes / stored CRC-32 | Match |
|---|---|---|---|
| `poweroff.irx` | 3,413 / `ED3C7537` | 3,413 / `ED3C7537` | Yes |
| `ps2dev9.irx` | 11,505 / `5A99CB71` | 11,505 / `5A99CB71` | Yes |
| `ps2ip.irx` | 109,497 / `55A708D1` | 109,497 / `55A708D1` | Yes |
| `ps2smap.irx` | 12,605 / `5A893F10` | 12,605 / `5A893F10` | Yes |
| `smbman.irx` | 44,329 / `86A433F3` | 44,329 / `86A433F3` | Yes |
| `smsutils.irx` (ZIP name `SMSUTILS.irx`) | 1,305 / `7312FEA0` | 1,305 / `7312FEA0` | Yes |

**Result: 6/6 exact size/CRC-32 metadata matches.** This provides strong independent evidence that the current hosted 7z archive and the 2020 quickstarter package preserve the **same six driver bytes**, although CRC-32 metadata equivalence is not a collision-proof content hash, and the entire 7z solid data stream has not been decompressed independently. Their non-driver contents and packaging differ:

- The 2020 quickstarter ZIP has **18 central-directory entries**, including its own launcher, CUE2POPS, readme, changes, directory metadata, and a `network_modules/mc0/POPSTARTER/` folder containing **six network IRXs plus two example .DAT files**. It contains **no** matching USB `usbd.irx` / `usbhdfsd.irx` or memory-card icon files in that nested driver directory.
- The hosted 7z includes those **six network IRXs plus two USB IRXs, two icons, and two .DAT templates**.
- The sample config templates have **different actual sizes/CRCs**: `IPCONFIG.DAT` is **30 B / 1291EFBD** in the 7z versus **38 B / F17BE668** in the ZIP; `SMBCONFIG.DAT` is **40 B / C692C5FD** versus **52 B / 70EA8D3D**. This demonstrates repackaging/template differences rather than a binary-identical bundle.

Separately, fetched all **93,934 bytes** of the existing hosted `network_modules.7z` by repository connector and computed a full-file **SHA-256 `ee3aeec5a9259665c6d505b81ee1bbdd3025a6925185e7cc4d3657100f37fad2`** with an independent SHA-256 implementation. Confirmed its stored 7z next-header CRC-32 `058FFDE0` equals the recalculated value. This fingerprints and validates the **current hosted file / header**, not the missing original. Its Git blob is `a45c67dd2a90ba47d8d34466edadcf8a859e94ec`.

### Historical provenance conclusion

The six currently hosted network IRXs therefore **survive as identical decompressed bytes in two differently packaged repository archives**, one labeled as the February 2020 SMB Quickstarter. The upstream driver build dates and the relationship to any 2015/2017 source package remain **unestablished**. The original 2017 Bitbucket archive remains listed as **59.0 KB**, compared with today's **93,934-byte** broader 7z bundle. Neither the independent 2020 ZIP nor the Git wiki text establishes the original 2017 archive's 7z bytes or member list. Original download URL requests and dated Wayback/Bitbucket retrieval attempts failed; a developer-hosted <https://psx-place.com/resources/popstarter.683/> resource links another network-module package location, but its bytes were **not retrieved or authenticated** and its release date is not a substitute for a 2017 checksum.

**Decision:** mark the six current SMB driver builds as cross-package-corroborated; continue to classify *2017 original archive equivalence* as unverified. Do not claim full 7z member CRC verification, change the network drivers, distribute an unverified source, or alter public documentation in this research-only PR.
