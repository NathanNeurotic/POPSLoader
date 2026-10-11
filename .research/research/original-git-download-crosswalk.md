# Original Bitbucket download references — historical crosswalk

**Read-only research for [PR #578](https://github.com/NathanNeurotic/POPSLoader/pull/578).** Compared added download URL basenames from the original AstroSnail-supplied Git history (2,140 commits) against the exact 23 files tracked in `.research/downloads/` on base commit `15ffb1c7`. The ZIP contains **wiki source text and links, not these download binaries**.

## Classification (80 distinct source forms)

| Class | Filename forms | Interpretation |
|---|---:|---|
| Exact filename currently hosted | 17 | Archived here under the exact source basename |
| Historical reference with no exact hosted file | 45 | **Research candidates**, not 45 verified missing binaries; may be renamed, inside a bundle, superseded, or unrecoverable |
| Likely format/filename variant, content unverified | 7 | Do not assume byte-equivalence |
| Explicitly mentioned inside existing package(s) | 3 | Contents require checksum/package inspection; not individually hosted |
| Historical safety exclusions | 4 | **Do not import automatically** |
| Invalid/incomplete or unrelated references | 4 | Do not count as missing downloads |
| **Total** | **80** | Source-file references, not unique historical binaries |

The current Downloads section hosts 23 files; the other six hosted files have different names or are sourced from additional mirrors/packaging. This is a filename-reference comparison, not a binary-content equivalence test.

## 45 historic source filenames without an exact hosted file

| Historical filename | Example original Git commit | Document where referenced |
|---|---|---|
| `BATCHER_0.3.1.EXE` | `0c1b34edee` | `popstarter-batcher.textile` |
| `BATCHER_0.3.EXE` | `68ec1c5fde` | `popstarter-batcher.textile` |
| `Compatibility_Modes_07252016.7z` | `d080270444` | `compatibility.textile` |
| `CUE2POPS_2.2.7z` | `30af41a3c1` | `apps-last-version.textile` |
| `cue2pops_src_linux.7z` | `51abeb7d6e` | `vcd.textile` |
| `cue2pops_src_linux.zip` | `8f569ea5a5` | `VCD.textile` |
| `Game Fixes.zip` | `938eaf9e52` | `Game Compatibility.textile` |
| `Game_Fixes.7z` | `a36a503715` | `compatibility.textile` |
| `hddosd_sample_files.7z` | `1dc243759b` | `popstarter-hddosd.textile` |
| `IGR Behaviour Modifiers.zip` | `949b7f4166` | `Game Compatibility.textile` |
| `IGR Textures - English pack.7z` | `65029585a5` | `IGR.textile` |
| `IGR Textures - French pack.7z` | `faf8b381af` | `IGR.textile` |
| `IGR Textures - Portuguese pack.7z` | `b477e79c7d` | `IGR.textile` |
| `IGR Textures - Spanish pack.7z` | `faf8b381af` | `IGR.textile` |
| `IGR_Behaviour_Modifiers.7z` | `7351fa6ddd` | `hotkeys.textile` |
| `IGR_Behaviour_Modifiers.zip` | `bb2a09c57e` | `igr.textile` |
| `IGR_sample_kit.7z` | `cd69a042ad` | `igr-textures.textile` |
| `IGR_sample_kit_04272016.7z` | `1428464956` | `IGR textures.textile` |
| `IGR_textures_-_English_pack.7z` | `ee7ecc9399` | `igr.textile` |
| `IGR_textures_-_French_pack.7z` | `ee7ecc9399` | `igr.textile` |
| `IGR_textures_-_German_Pack.7z` | `ee7ecc9399` | `igr.textile` |
| `IGR_textures_-_Polish_pack.7z` | `ee7ecc9399` | `igr.textile` |
| `IGR_textures_-_Portuguese_pack.7z` | `ee7ecc9399` | `igr.textile` |
| `IGR_textures_-_Spanish_pack.7z` | `ee7ecc9399` | `igr.textile` |
| `pfs-scripts.7z` | `536660e141` | `pfsshell.textile` |
| `POPStarter r13 WIP 05.zip` | `eb4d4d70fd` | `Home.textile` |
| `POPStarter_BATCHER_06192016.7z` | `0d1cdd640e` | `popstarter_batcher.textile` |
| `POPStarter_Quickstarter_Pack_HDD_20161002.7z` | `4dec8dfa45` | `quickstart-hdd.textile` |
| `POPStarter_Quickstarter_Pack_HDD_20161103.7z` | `562d2481e4` | `quickstart-hdd.textile` |
| `POPStarter_Quickstarter_Pack_HDD_2017_01_10.7z` | `a96be9c1c2` | `quickstart-hdd.textile` |
| `POPStarter_Quickstarter_Pack_SMB__2017_01_10.7z` | `8251123a5e` | `quickstart-smb.textile` |
| `POPStarter_Quickstarter_Pack_USB_20161002.7z` | `77fb27ce3` | `quickstart-usb.textile` |
| `POPStarter_Quickstarter_Pack_USB_20161103.7z` | `dcc7269d4` | `quickstart-usb.textile` |
| `POPStarter_Quickstarter_Pack_USB__2017_01_10.7z` | `6ab47ba67` | `quickstart-usb.textile` |
| `POPStarter_r13_WIP_05.7z` | `43f1930c2c` | `Home.textile` |
| `POPStarter_r13_WIP_06_OBT_13_20151207.zip` | `eb4d4d70fd` | `Home.textile` |
| `POPStarter_r13_WIP_06_OBT_20160723_OBT15.7z` | `43f1930c2c` | `Home.textile` |
| `POPStarter_SMB_Quickstarter_Pack_20171027.7z` | `f50684bfb8` | `quickstart-smb.textile` |
| `POPStarter_USB_Quickstarter_Pack_20171027.7z` | `bfef022077` | `quickstart-usb.textile` |
| `PPF Bunch pack v1.7z` | `a711cae2cb` | `POPStarter Configuration Table.textile` |
| `PPF_Bunch_pack.7z` | `316423c2f0` | `configuration-table.textile` |
| `ToolBox.7z` | `740cda4faa` | `apps-last-version.textile` |
| `ToolBox.zip` | `9fb9314cf4` | `HDD mode.textile` |
| `uLE_kHn_20150727.zip` | `efdac2fc9d` | `HDD mode.textile` |
| `uLE_kHn_20160723.7z` | `3c35465478` | `apps-last-version.textile` |

### Priority interpretation

- **Original development releases:** two WIP05 packaging variants, WIP06 OBT13/OBT15, 2016/2017 per-backend Quickstarter editions, and the 2017 USB/SMB packs may capture historical differences not present in 2019/2020 bundles. Historical filename alone does not prove they are distinct bytes.
- **Tools:** CUE2POPS 2.2, Linux CUE2POPS source archives, earlier ToolBox variants, batcher v0.2/0.3/0.3.1, PFS helper scripts and original uLE_kHn packages require separate provenance/recovery decisions.
- **Textures/patches:** IGR languages, sample kits, behavior modifiers, per-game fixes, PPF pack and compatibility-variant archives must be classified by *actual content*, not by similar names.
- **Sony content and malware heuristics:** do not distribute copyrighted emulator payloads or override the existing exclusions based solely on historical references. Preserve safe metadata about excluded items.

## 17 exact names already hosted

- `CHEATS.TXT`
- `Compatibility_Modes.zip`
- `DS3_modules_BT_20171017.7z`
- `DS3_modules_USB_20171017.7z`
- `FORCEPAL_PATCH.7z`
- `IGR_textures_-_Chinese_pack.7z`
- `network_modules.7z`
- `NOPAL_PATCH.7z`
- `pfsshell-0.2a.7z`
- `POPStarter_HDD_Quickstarter_Pack_20171027.7z`
- `POPStarter_HDD_Quickstarter_Pack_20200209.zip`
- `POPStarter_r13_Beta_20190605.zip`
- `POPStarter_r13_RIP_06.zip`
- `POPStarter_SMB_Quickstarter_Pack_20200209.zip`
- `POPStarter_USB_Quickstarter_Pack_20200209.zip`
- `RadHostClient_1.8a.7z`
- `SAMPLE_CHEATS.TXT`

## 7 possible aliases or different container formats (not established binary equivalence)

| Historic form | Compare against / alternate |
|---|---|
| `Compatibility Modes.zip` | `Compatibility_Modes.zip` |
| `Compatibility_Modes.7z` | `Compatibility_Modes.zip` |
| `CUE2POPS_2.3.7z` | `CUE2POPS_2.3.zip` |
| `IGR Textures - Chinese pack.7z` | `IGR_textures_-_Chinese_pack.7z` |
| `IGR Textures - Polish pack.7z` | `IGR_textures_-_Polish_pack.7z` |
| `IGR_textures_-_English_pack.zip` | `IGR_textures_-_English_pack.7z` |
| `IGR_textures_-_German_pack.zip` | `IGR_textures_-_German_Pack.7z` |

## 3 historically mentioned items reported inside hosted bundles (verify)

| Historic individual filename | Candidate hosted package |
|---|---|
| `DEBUG_AND_HALT.PPF` | `POPStarter_r13_WIP_06_OBT_20170128.zip` |
| `network_modules.zip` | `POPStarter_SMB_Quickstarter_Pack_20200209.zip` |
| `uLE_kHn_20191110.zip` | `POPStarter_USB_Quickstarter_Pack_20200209.zip` |

The existing docs indicate that these appear in bundles; this crosswalk **does not re-inspect binary contents**. A future check should compare extracted checksums and timestamps.

## 4 already-excluded items

| Historic source filename | Existing policy |
|---|---|
| `Disc_Combining_Kits.7z` | AV-flagged archive excluded by previous policy |
| `DISCS_POOPER.BAT.7z` | Excluded by established site policy |
| `DISCS_POOPER.EXE` | Excluded by established site policy |
| `POPStarter_ELFs BATCHER_05062016.7z` | AV-flagged archive excluded by previous policy |

## 4 malformed, incomplete or unrelated URL forms

| Form | Reason |
|---|---|
| `$FORCEPAL_PATCH.7z` | Malformed literal dollar-prefixed archive URL |
| `$NOPAL_PATCH.7z` | Malformed literal dollar-prefixed archive URL |
| `IGR_textures_-_` | Truncated/partial URL, not an artifact name |
| `lang_French.lng` | From unrelated historical sample.md |

## Audit-log consistency issue

`.research/_tmp/dl_manifest.tsv` is a stale retrieval/scrape ledger, **not an authoritative inventory of hosted files**. For example:

- It marks `NOPAL_PATCH.7z`, `network_modules.7z` and `SAMPLE_CHEATS.TXT` as missing, but these exact files are tracked in `.research/downloads/`.
- It marks `Disc_Combining_Kits.7z` and `POPStarter_ELFs BATCHER_05062016.7z` as recovered, but neither is currently hosted due to established exclusions.
- Its 50 entries do not cover all 80 name forms found across the complete original Git history.

**Do not use the raw intermediate recovery status to publish a 'missing downloads' count.** Prefer the tracked filesystem, exact bytes, and each release's dated historical attribution. A candidate can remain absent because it was intentionally excluded; the record should say so.

## Next evidence before proposing imports

1. Reconcile candidate names against existing mirror pages and the contents of hosted ZIP/7z packs.
2. Record cryptographic hashes, the original historical URL, revision date, package provenance, and any license/AV findings for every recoverable candidate.
3. Treat truly lost or excluded artifacts as *metadata-only preservation records*.
4. No downloads, source replacements, or release/package edits are authorized by this research PR.


## Independent Bitbucket download listing corroboration (2020-era archived index)

An archived [original Bitbucket Downloads listing](https://archive.ph/PBG1V) surfaced via web-search cache. The first **28 visible rows** give historical filenames, displayed sizes, uploader names and upload dates. This is a **partial source excerpt, not a complete download list**. Compared against 23 exact tracked files: **13 identical basenames**, **14 not hosted with that exact filename**, **1 previously withheld archive**. The 2020 rows credit **El_Patas** as uploader; the earlier 23 rows credit **Shaolin Assassin**. The snapshot independently confirms that historical CUE2POPS 2.3, BATCHER 0.3.1, IGR language packs, old HDDOSD sample and mode archives were genuine Bitbucket-listed uploads, not hypothetical filename mentions.

**Two high-priority provenance discrepancies:** `NOPAL_PATCH.7z` (**226 bytes** on original listing vs **188 bytes** tracked) and `network_modules.7z` (**59.0 KB** indexed vs **93,934 bytes** tracked). Identical filenames but demonstrably nonidentical sizes; the original URL recovery log reported failures. This **does not** establish that current variants are defective, but it forbids byte-for-byte archival-equivalence claims. Other archive sizes often match to displayed rounding but still need hash verification. See [independent 28-row evidence inventory](original-bitbucket-download-snapshot-2020.md) and [source metadata TSV](original-bitbucket-download-snapshot-2020.tsv).

The previously suggested CosmicScale GitHub mirror offers **localized TM2 image assets**, not the actual original `IGR_textures_-_*.7z` files. It is a potential **functional asset source**, not an authenticated archive of those historical Bitbucket packages. No package import/repack has been attempted.
