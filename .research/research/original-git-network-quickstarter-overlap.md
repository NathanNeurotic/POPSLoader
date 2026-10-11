# POPStarter network-driver overlap — current 7z versus 2020 SMB quickstarter

## Full decompressed-payload verification — 2026-10-10 (supersedes metadata-only caveat above)

**Verified in [GitHub Actions run #38113818669](https://github.com/NathanNeurotic/POPSLoader/actions/runs/38113818669), job `verify-network-archives`, successful.** The research-only script [`verify_network_driver_payloads.py`](../tools/verify_network_driver_payloads.py) decoded all 12 members of the hosted 7z independently with the installed 7-Zip decoder, checked each extracted length and independently recomputed CRC-32 against the stored directory value, and required a successful full-archive `7z t`. All **12/12** passed. Python's `zipfile` separately decompressed and verified the six 2020 ZIP drivers. SHA-256 was then calculated from actual decompressed bytes from both packages, without executing IRX content or emitting distributable artifacts.

| Driver | SHA-256 of extracted 7z member **and** extracted 2020 ZIP member | Result |
|---|---|---|
| `poweroff.irx` | `573863a0f9b213b6f53f2eeaf074745b27b9c4d52dfddeaff8f0b112632cb504` | MATCH |
| `ps2dev9.irx` | `e2b83bb01a5904b3f4360e23fd7cfc07a2a11eaa413c1808961432dced80119c` | MATCH |
| `ps2ip.irx` | `1bf99ca297dcca410bccce14b8efa00f5efc536359e3e34be50edf0043c867b9` | MATCH |
| `ps2smap.irx` | `671fe9e3c5e0e735fb3ea3b81a8ea39898bd0fafbdacbf9ca7fa11fff391df8d` | MATCH |
| `smbman.irx` | `000296a2f03073dffd2f87a6f3eae249a1f83c2213ffb0ae25bad67b970ebed0` | MATCH |
| `smsutils.irx` | `91daae46a300138218bfd6a876a1b5012594412b71c2eebf6eadfb70fde38e1b` | MATCH |

**Full package fingerprints** (archive bytes, not member hashes):

- `network_modules.7z`: 93,934 bytes; SHA-256 `ee3aeec5a9259665c6d505b81ee1bbdd3025a6925185e7cc4d3657100f37fad2`
- `POPStarter_SMB_Quickstarter_Pack_20200209.zip`: 280,193 bytes; SHA-256 `94b432f6665132cd6862ae7465a2dc66807084f0c71c686899abe1f453c405d8`

**Scope of proof:** the six SMB drivers currently hosted in these two archive formats contain the exact same uncompressed bytes. The *historical* original October 27, 2017 Bitbucket `network_modules.7z` (listed at 59.0 KB) is absent; no byte identity, driver-version provenance, or historical member manifest is established for that old upload. The 7z's remaining six non-network members were successfully CRC-tested, but this SHA-256 equivalence table is **only** for the six network IRXs.

To reproduce on Linux: install `7zip` or `p7zip-full`, then run:

```bash
python3 .research/tools/verify_network_driver_payloads.py \
  .research/downloads/network_modules.7z \
  .research/downloads/POPStarter_SMB_Quickstarter_Pack_20200209.zip
```

The original section below records the **earlier directory-only stage**. Its claims that no payloads had been decoded are superseded by this verified follow-up, not evidence of any disagreement.


Evidence date: 2026-10-10, added to draft PR #580. Original 2017 Bitbucket package is unavailable; **these findings concern two packages currently hosted by POPSLoader**.


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

A 2020-derived copy of the six network IRXs therefore **already survives in two independently packaged repository archives**. The original 2017 Bitbucket archive remains listed as **59.0 KB**, compared with today's **93,934-byte** broader 7z bundle. Neither the independent 2020 ZIP nor the Git wiki text establishes the original 2017 archive's 7z bytes or member list. Original download URL requests and dated Wayback/Bitbucket retrieval attempts failed; a developer-hosted <https://psx-place.com/resources/popstarter.683/> resource links another network-module package location, but its bytes were **not retrieved or authenticated** and its release date is not a substitute for a 2017 checksum.

**Decision:** mark the six current SMB driver builds as cross-package-corroborated; continue to classify *2017 original archive equivalence* as unverified. Do not claim full 7z member CRC verification, change the network drivers, distribute an unverified source, or alter public documentation in this research-only PR.


## Reproduction method and confidence

- For the hosted 7z, run `python3 .research/tools/inspect_network_modules_header.py .research/downloads/network_modules.7z` in a checkout to decode and CRC-check its **directory**. The output yields member names, lengths and CRC values listed above; this does not unpack the solid payload.
- For the 2020 ZIP, standard Python `zipfile.ZipFile(...).infolist()` yields all 18 entries, including `file_size` and `CRC`. Filter entries whose names end in the exact six expected IRX basenames (case-insensitive), then compare member lengths and CRC-32. ZIP central-directory inspection is read-only and does not decompress individual members.
- To verify full file content, independently extract *data without executing it* from both archives and compute member SHA-256/CRC on the decompressed bytes; a 7z decoder must check each substream CRC and not rely only on directory metadata. Such full extraction is **not claimed here**.
- Source hashes: current ZIP Git blob `909426a2721d8eed1a10ee8a2c7ee0a2e6f9f413`, current 7z Git blob `a45c67dd2a90ba47d8d34466edadcf8a859e94ec`, current 7z full SHA-256 `ee3aeec5a9259665c6d505b81ee1bbdd3025a6925185e7cc4d3657100f37fad2`.


### ZIP package exclusions for the original NOPAL patch hunt

Read-only central-directory scans of **currently hosted** ZIPs found no `NOPAL_PATCH.7z`, `FORCEPAL_PATCH.7z`, `PATCH_9.BIN` or `PATCH_8.BIN` members in the `POPStarter_USB_Quickstarter_Pack_20200209.zip` (9 entries), `POPStarter_SMB_Quickstarter_Pack_20200209.zip` (18 entries), `POPStarter_r13_Beta_20190605.zip` (4 entries), `POPStarter_r13_RIP_06.zip` (5 entries) or `POPStarter_r13_WIP_06_OBT_20170128.zip` (12 entries). These specific bundles therefore do not independently authenticate or reproduce the original **2017 226-byte** `NOPAL_PATCH.7z`. The hosted HDD 2020 ZIP is **over 1 MB**, which the connector did not supply as a full base64 payload; **it has not been searched** and must not be counted as a negative result.

For network-module comparison, the new [read-only six-driver crosswalk script](../tools/audit_network_driver_crc_overlap.py) compares the stored `(file size, CRC-32)` directory fields in the current 7z and hosted 2020 SMB ZIP. It does **not** decompress, execute or overwrite any IRX file. An exact 6/6 match is a robust independent archival cross-reference, **not a direct match to the missing 2017 Bitbucket original**.
