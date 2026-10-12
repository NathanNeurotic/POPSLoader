# Hosted POPStarter archives: complete direct-member patch census (2026-10-11)

**Scope:** research-only follow-up to draft PR #580. This report fingerprints and inspects **the 21 ZIP/7z archives** among **23 tracked files** in `.research/downloads/` at this branch revision. The remaining two files are plaintext `CHEATS.TXT` and `SAMPLE_CHEATS.TXT`. No release, hosted download, original extracted payload, public wiki page, or PS2 runtime was modified.

## Verified GitHub Actions execution

- [Successful historical archive research workflow run #38165914482](https://github.com/NathanNeurotic/POPSLoader/actions/runs/38165914482), job `audit-hosted-patch-members`.
- Read-only verifier: [`../tools/audit_hosted_patch_members.py`](../tools/audit_hosted_patch_members.py); scans repository archive filenames and **direct member names/declared sizes/CRCs**, with Python `zipfile` and 7-Zip's `l -slt`. No decompression of candidate binaries into working files and no execution.
- An initial run counted some zero-byte 7z **directory markers** as entries. The script was corrected to exclude zero-byte/CRC-less parents of known children; the table below is from the **corrected successful run**. The 12-file network 7z manifest agrees with the separate full-payload verifier.

## Additional full compressed-payload integrity verification (2026-10-11)

After the original directory-only census, the same verifier gained optional `--full-test` support. In [successful GitHub Actions run #38166162184](https://github.com/NathanNeurotic/POPSLoader/actions/runs/38166162184), all **21/21 hosted ZIP/7z containers passed full compressed-payload integrity tests**: Python `ZipFile.testzip()` for ZIP packages, and `7z t -bd -y` for 7z packages. The run printed a separate `PAYLOAD TEST PASS` for each archive and `Full payload integrity test PASS: 21/21 archive containers`; the same census still identified exactly two named patch members and no nested named archives.

These tests **decompress and verify package data without executing the contents or saving unpacked files for publication**. They are format-integrity checks of today's hosted bytes, **not** historical-original identification, file authorship/version checks, semantic correctness, malware analysis, emulator/PS2 testing, or independent cryptographic matching against 2017 sources. The original network-driver audit separately compares SHA-256 of extracted member bytes between two different packages.

To reproduce the full test, append `--full-test` to the command near the end of this document.

## Outcome

| Check | Result |
|---|---|
| Hosted archive containers listed | **21/21** ZIP/7z files |
| Non-archive files outside scan | **2** plain `.TXT` files |
| Nested ZIP/7z/RAR member names detected | **0** |
| Direct member matches for `NOPAL_PATCH.7z`, `FORCEPAL_PATCH.7z`, `PATCH_9.7z`, `PATCH_9.BIN`, `PATCH_8.BIN` or filenames containing `nopal`/`forcepal` | **2**, both in the already known namesake packages |
| Existing `NOPAL_PATCH.7z` member | `PATCH_9.BIN`, **67 bytes**, stored CRC `FB09FD04` |
| Existing `FORCEPAL_PATCH.7z` member | `$FORCEPAL_PATCH/PATCH_8.BIN`, **64 bytes**, stored CRC `28E6D956` |
| **2017-10-27 HDD Quickstarter** direct members | **7**, none matching target names |
| **2020-02-09 HDD Quickstarter** direct members | **7**, none matching target names |

**New negative evidence:** the previously inaccessible-to-base64 **2020 HDD Quickstarter ZIP**, as well as the October 2017 HDD Quickstarter archive, have now both had their actual tracked member directories inspected. Neither offers the missing historical 226-byte `NOPAL_PATCH.7z` under a directly named member, nor a separately named `PATCH_9.BIN`. The archived **2017 original NOPAL** and **2017 59.0 KB network_modules** uploads themselves are not recovered.

## Exact hosted archive fingerprints and direct-file counts

Hashes are SHA-256 of **whole hosted archive files**, as calculated by the GitHub Actions run, **not** historical Bitbucket hashes. A pass for archive *directory enumeration* does **not** mean every member's compressed payload was checksum tested; only the separate [network archive full-payload audit](original-git-network-quickstarter-overlap.md) makes that latter claim.

| Repository filename under `.research/downloads/` | Direct files | SHA-256 (hosted archive) |
|---|---:|---|
| `CUE2POPS_2.3.zip` | 3 | `8c9b45b4de2f4cadace2fb6efdd802ca2287c8d76a112d3d8e6968d4902a1fa2` |
| `Compatibility_Modes.zip` | 8 | `6e28851551eb02f13501e140fb25d8996058f86a0ec0ac29484ff9d5ed1c0165` |
| `DS3_modules_BT_20171017.7z` | 3 | `41ee249003a28563e7e6043418c77769fec19ae806c5c8cdaf0cd76777ae627f` |
| `DS3_modules_USB_20171017.7z` | 3 | `6a0683324a71356938a36df91901a00e4a24fa366ac98bdbc0363392a603655d` |
| `FORCEPAL_PATCH.7z` | 1 | `91f606681e071ccef3df66143a93573a578a811ce176de498eab96ea09130dab` |
| `IGR_textures_-_Chinese_pack.7z` | 3 | `9b22b02dc8332cbebfa64edc3bcf99924af6c25f74efd33087d1badb2c7a0db5` |
| `NOPAL_PATCH.7z` | 1 | `e07446f307cee99be54795d83bc1cf645def4c4aeba384aea474343ca0015d5d` |
| `POPStarter_HDD_Quickstarter_Pack_20171027.7z` | 7 | `f7ea51a52b011780365f90226623ca857a0cadb3205efb2d49ded5c70e690292` |
| `POPStarter_HDD_Quickstarter_Pack_20200209.zip` | 7 | `56fd170f7630055c8f8a3a4f74e20507a35a6908405a6acf880372d545223cbc` |
| `POPStarter_SMB_Quickstarter_Pack_20200209.zip` | 13 | `94b432f6665132cd6862ae7465a2dc66807084f0c71c686899abe1f453c405d8` |
| `POPStarter_USB_Quickstarter_Pack_20200209.zip` | 6 | `27c032cba8cb64d478a99326e35c025f910d16ac0326d9d767daa3e134ecc47b` |
| `POPStarter_r13_Beta_20190605.zip` | 3 | `a44df3316bb15afdf840e1bbd1ce4b41666ede601f1eacb91f7c9d7681b6153a` |
| `POPStarter_r13_RIP_06.zip` | 4 | `39873c93290f9813a357a17189b0d0c2a2190a2face5add0a09cb5ab3b2c3d77` |
| `POPStarter_r13_WIP_06_OBT_20170128.zip` | 10 | `cd458f0fb2ac26a14ccf1e3757b2e8d6cdfebd3ff1394861b48d1b2552617fef` |
| `RadHostClient.zip` | 2 | `9ae72acc9a8568894d2f22cac42fedd917a8c1503deaa1fcb0457b1cc22b544b` |
| `RadHostClient_1.8a.7z` | 1 | `8d1d6ea5f883de9363cb633e9b035daca9946bce1d61cdee182a685ff1766075` |
| `TROJAN_7.zip` | 1 | `cca0f9c18af15164e8fa442285bce1b41f29147e4fa338d8063922f3131e79cc` |
| `cdmage1-02-1b5.zip` | 2 | `1af5049bcd9b4f76647e5ac502abaf392a23011f7a2ce9a593347fb5d36a86bb` |
| `network_modules.7z` | 12 | `ee3aeec5a9259665c6d505b81ee1bbdd3025a6925185e7cc4d3657100f37fad2` |
| `pfsshell-0.2a.7z` | 8 | `298b6a92eb1f5d90a06d6944b90f02946505d1e6d49c75e3d2f8f32d24e8c8d7` |
| `pfsshell-0.2a.zip` | 6 | `17105f048f6be6f3d2ce70d84ec1d928459e257d9d0f37b2d332cb525abf84c7` |

## Scope, custody and interpretation

1. The script searches **direct archive member filenames** against specific historical patch names/aliases and flags named nested archives. It does not do arbitrary substring scans of binary payloads, search unknown external/Bitbucket files, or establish that differently named files lack equivalent functionality.
2. **Archive SHA-256 proves the identity of today's hosted files only.** The 2017 Bitbucket original `NOPAL_PATCH.7z` is reported as **226 B**, versus **188 B** tracked; `network_modules.7z` is reported as **59.0 KB**, versus **93,934 B** tracked. [Archived original upload listing](https://archive.ph/PBG1V). These 2017 upload bytes are not in the 21-archive set.
3. The **67-byte `PATCH_9.BIN` currently inside `NOPAL_PATCH.7z` has already been independently identified as an ELF-loader unhook patch**, matching a later developer-described use. Neither this census nor identical basename is proof it implements the earlier `$NOPAL` workaround. See [hosted patch-label conflict](original-git-hosted-patch-archive-inspection.md).
4. No Sony emulator/BIOS binary was imported or linked; directories were enumerated without redistributing payloads. **No claim of hardware testing or full authenticity.**

## Reproduce

```bash
# Ubuntu/Debian: sudo apt-get install 7zip
python3 .research/tools/audit_hosted_patch_members.py .research/downloads
```

**Result:** the specific previously uninspected hosted HDD-package lead is now exhausted at the level of directly named archive members. Remaining recovery needs authenticated external archival bytes, not another scan of the same already inventoried packages.
