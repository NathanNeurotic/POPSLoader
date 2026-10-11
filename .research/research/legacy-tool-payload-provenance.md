# Exact-member provenance for three legacy Pages-only tool archives

**2026-10-11 follow-up to PR #585.** This is a *read-only* audit of already retained files on `gh-pages` and already tracked archives in `.research/downloads/`. It does **not** execute binaries, repackage tools, replace downloads, or establish original Bitbucket bytes/safety.

## Reproducible comparison

Source and verifier: [`audit_legacy_tool_overlap.py`](../tools/audit_legacy_tool_overlap.py). [GitHub Actions run #38180081968](https://github.com/NathanNeurotic/POPSLoader/actions/runs/38180081968), job `audit-published-legacy-archive-payloads`, **PASS**. The job independently checked out current `gh-pages`, tested all existing old-7z full-payload CRCs, then decoded each of these **single-member** candidate archives into memory and compared decompressed member-name/size/SHA-256 against all **21 tracked ZIP/7z source archives**. No files were written from the payloads or executed.

| Existing Pages-only container | One decompressed member | Length | SHA-256 of member | Exact byte+name matches among 21 tracked ZIP/7z archives |
|---|---|---:|---|---:|
| `BATCHER_0.3.1.EXE.7z` | `BATCHER_0.3.1.EXE` | **24,064 B** | `19c3b2500f2240be2b5cb20c23b44d7f200829707c72d4621e3cf2c0593a26fe` | **0** |
| `DEBUG_AND_HALT.7z` | `DEBUG_AND_HALT.PPF` | **73 B** | `9f2d63ca888cb19812bc5ce57a8ce3a5449c5f045f49503ecd1662f3b7ef7c9f` | **1** — documented below |
| `uLE_kHn_20191110_2.7z` | `uLE_kHn_20191110.zip` | **2,122,686 B** | `4be6a8e3b7b991559cb5c9e5b39fe97ee7a6f398b8183956a6781776180b7729` | **0** |

**Important distinction:** 0 exact-name hits from tracked *archive-member* scans does not mean that no original exists on the public internet, nor does it prove any file is malicious or unusable. It means there was **no full byte+name match among the particular 21 repository ZIP/7z packages scanned**.

## 1. DEBUG_AND_HALT has confirmed byte-for-byte payload parity

The preserved 73-byte `DEBUG_AND_HALT.PPF` was found **inside** the already tracked `POPStarter_r13_WIP_06_OBT_20170128.zip`, at:

```text
POPStarter_r13_WIP_06_OBT_20170128/DEBUG_AND_HALT.PPF
```

The independently decompressed byte hashes match exactly (**SHA-256 `9f2d63ca888cb19812bc5ce57a8ce3a5449c5f045f49503ecd1662f3b7ef7c9f`**). That provides strong cross-package corroboration for the **functional historical PPF payload**, even though neither archive's *original Bitbucket upload bytes* were independently obtained.

Developer and recovered-wiki descriptions agree this patch enables boot-time debug text and halt-on-error, by manipulating the POPStarter **`$410` / `$411`** config bytes in releases that support those settings. Sources: [developer's original 2014 Metagames thread](https://www.metagames-eu.com/forums/playstation-2/popstarter-revision-13-a-134569.html), [preserved original Config Table wiki](https://nathanneurotic.github.io/POPSLoader/config.html), [early 2017 WIP package recovered in repo](../downloads/POPStarter_r13_WIP_06_OBT_20170128.zip).

**Verdict:** `DEBUG_AND_HALT.7z` **contains a known and now source-package-equivalent debug PPF**. Keep its historic 7z outer wrapper preserved; the matching contents do not require a new official download item.

## 2. BATCHER has a plausible filename and size match, but no payload witness

The original [Bitbucket Downloads listing](https://archive.ph/PBG1V) names an upload `BATCHER_0.3.1.EXE`, uploader Shaolin Assassin, dated **2016-11-28**, with displayed length **23.5 KB**. The existing Pages-only `BATCHER_0.3.1.EXE.7z` contains `BATCHER_0.3.1.EXE` measuring exactly **24,064 B = 23.5 KiB**, strongly *consistent* with the original name and rounded listing.

Independent usage evidence exists for POPStarter BATCHER v0.3.1, including [a 2017 community installation report](https://www.elotrolado.net/hilo_ho-pops-emulador-de-psx-para-ps2_1874054_s2650) and [later POPStarter installation advice](https://www.elotrolado.net/hilo_ho-pops-emulador-de-psx-para-ps2_1874054_s3550).

**Not established:** the original 2016 EXE bytes, an independently dated SHA-256, specific implementation/build version, executable safety, or permission to migrate the Pages-only 7z into curated downloads. **No other tracked release container had an exactly matching member name and SHA-256**, so the original-payload-identity issue remains *open*. Do not change the public link's classification based only on a filename and the matching size.

## 3. uLE is a nested *ZIP* preserving a plausible complete 2019 tool release

`uLE_kHn_20191110_2.7z` is an extra Pages-only 7z wrapper containing a single **intact original-form ZIP candidate** named:

```text
uLE_kHn_20191110.zip
```

The **inner ZIP** measured **2,122,686 B**, SHA-256 `4be6a8e3b7b991559cb5c9e5b39fe97ee7a6f398b8183956a6781776180b7729`. A separate **in-memory ZIP central-directory and complete CRC check PASSED** on **5 files totaling 2,790,163 uncompressed bytes**:

| ZIP member | Uncompressed byte length | CRC32 (from ZIP) |
|---|---:|---|
| `uLE_kHn_20191110/BOOT.ELF` | 1,077,692 | `4D452E25` |
| `uLE_kHn_20191110/BOOT.XLF` | 454,563 | `F783953D` |
| `uLE_kHn_20191110/MBR.KELF` | 455,168 | `72F86A5B` |
| `uLE_kHn_20191110/packed_BOOT.ELF` | 339,380 | `E89D206E` |
| `uLE_kHn_20191110/__mbr.raw` | 463,360 | `72E4BC09` |

The [2020 Bitbucket indexed upload listing](https://archive.ph/PBG1V) contains **`uLE_kHn_20191110.zip`**, uploaded by **El_Patas on 2020-02-09**, displayed as **2.0 MB**. This **inner-ZIP name and rounded-size match** is a credible source link, but **not historical byte authentication**: Bitbucket's original archive SHA-256 or full upload-byte count has not been recovered. The 2019 uLE variant's purpose, launching POPStarter VCD files directly, is independently documented in [the project's quickstart guide](https://nathanneurotic.github.io/POPSLoader/wiki/quickstart-usb.html), [the PSX-Place SMB discussion](https://www.psx-place.com/threads/how-to-get-popstarter-via-smb-to-work.37922/) and [a 2021 independent HDD-setup walkthrough](https://www.trisaster.de/forum/index.php?topic=256.15).

**Caution:** the candidate contains executable, packed ELF, and KELF/MBR binaries. This report **does not establish their redistribution rights, licensing, authenticity, or malware-scan status**. Preserve the current Pages-only archive identity, but do not extract or add the inner ZIP as a separate public official download without a separate provenance and distribution review.

## Remaining follow-up

- **DEBUG PPF:** cross-package payload identity closed; original-upload packaging identity remains unproven.
- **BATCHER EXE:** try to locate another independently dated binary/checksum for the original **2016-11-28** Bitbucket upload; compare `19c3b250…` with verified bytes, not name/size alone.
- **uLE ZIP:** locate a dated 2020 original upload/hash for `uLE_kHn_20191110.zip`, compare with inner-ZIP SHA-256 `4be6a8e3…`. Until then it is a **surviving candidate**, not an authenticated original.
- Continue independent retrieval of original 2017 `NOPAL_PATCH.7z` (226 B), `network_modules.7z` (~59.0 KB), October 2017 SMB/USB Quickstarter 7z, and missing screenshots. The new matches do **not** close those outstanding gaps.

**Publication impact: NONE.** No current Pages files, source-generated downloads, PS2 runtime, or archive members were changed in the process.
