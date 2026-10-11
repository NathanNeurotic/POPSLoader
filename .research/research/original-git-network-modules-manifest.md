# Forensic directory audit: currently hosted `network_modules.7z`

**Status:** read-only, based on authenticated *current repository bytes*. The historic Bitbucket source archive itself is **unavailable**. No files have been executed or extracted into a distributable package, and no driver version or real-hardware behavior has been certified.

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
