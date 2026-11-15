# Round 2 — Topic 5: Hand-rolled crypto / hash / parsing inventory (all five repos)

READ ONLY. Pins verified 2026-11-14, all clones `git status` clean at delivery:
RiptOPL `2e347d5ac885`, Launchstation `9fb0598a79f0`, POPSLoader `29272cddbf01`,
Simple-Media-System (SMS) `e65ced39a27e`, PS2-Servers `c5f021c4d386`.
Method: `git grep` over `*.c/*.h/*.cpp/*.py/*.go/*.lua` + filename search + targeted reads; every size is `wc -l -c`-measured.
Classification: **FP** = first-party hand-rolled (written for this project, in its own tree);
**VEND-IN** = vendored-origin code copied into a first-party path (not under `third_party/`/`vendor/`);
**VEND** = vendored library under `third_party/`/`vendor/` or fetched at build time;
**STD** = system/stdlib. "Linked" claims are READ where a call site/Makefile/config was read, otherwise INFERRED and labelled.

Headline: the only true *same-program* library/hand-roll and hand-roll/hand-roll doubles are
(1) Launchstation EE SHA-256, (2) the `smb2man` IOP module's MD4+MD5 pairs (RiptOPL + Launchstation),
(3) RiptOPL EE's two CRC-32-family functions. Everything else is split across EE/IOP/host programs that cannot share a library.

---

## 1. MD5 (and MD4, SMB)

| Repo | FP hand-rolled (loc : size) | Vendored (loc : size) | Stdlib |
|---|---|---|---|
| RiptOPL | `modules/iopcore/cdvdman/smb2auth.c:82-121` `md5_block()` — unified MD4/MD5/SHA-256/HMAC file, 307 L / 9,549 B total (`smb2auth.h:1-42`, 42 L). Shared by cdvdman (`modules/iopcore/cdvdman/smb2.c:811-855`, HMAC-MD5) and the menu IOP `modules/network/smb2man/smb2man.c:49,156-205` (include comment READ). | **VEND-IN, EE:** `src/platform/md5.c:133-382` (`md5_process:133`, `md5_init:314`, `md5_append:324`, `md5_finish:362`) + `include/md5.h:50-91` — L. Peter Deutsch public-domain MD5, 382 L / 12,447 B + 91 L / 3,392 B. Makefile:290 READ: `md5.o` only in `RETROACHIEVEMENTS=1` builds; used by `src/sources/rahash.cpp:506-547,623-647,769-818,878-895`. **VEND, IOP usmb2:** `modules/network/smb2man/usmb2/md5.c:1-190` (condensed RSA MD5) 190 L / 6,394 B + `md5.h` 23 L, `hmac-md5.c` 99 L / 2,908 B (`VENDORED.txt` READ: sahlberg/usmb2 @7171d08). **VEND on disk, NOT enabled:** `third_party/mbedtls/library/md5.c` 426 L / 12,545 B — neither `riptopl_mbedtls_config.h` nor `…_slim_config.h` defines `MBEDTLS_MD5_C` (grep READ), so not linked (INFERRED). | Python tools/tests: `hashlib.md5` (one line). |
| Launchstation | `iop/smb2man/smb2auth.c:82-121` — **byte-identical** to RiptOPL's (`md5sum 262602b5…`, file 307 L / 9,549 B; `iop/smb2man/README.md:11,15` READ: "RiptOPL's … unchanged, byte for byte"). No EE MD5. | **VEND, IOP usmb2:** `iop/smb2man/usmb2/md5.c` 190 L / 6,394 B — **byte-identical** to RiptOPL's (`md5sum 0b8857f0…`), `hmac-md5.c` 99 L / 2,914 B (6 B diff). No mbedTLS tree in repo (fetched, §3). | Python scripts/tests: `hashlib` (one line). |
| POPSLoader | — none found in `src/`, `iop/`, Lua (grep READ). | — none. | `.research/` tools only: `hashlib` (one line). |
| SMS | — no MD5. | — none. | — none in C; Python tools `hashlib` (one line). |
| PS2-Servers | — no hand-rolled MD5 in Python/Go. | **VEND:** `vendor/retroachievements/rcheevos/src/rhash/md5.c` 382 L / 12,439 B + `md5.h` 91 L / 3,392 B — **same Deutsch file as RiptOPL's EE copy**: `diff` = 1 line only (`#include "include/md5.h"` vs `"md5.h"`, READ). Used by rcheevos `rhash/hash*.c`. | Python first-party: `hashlib.md5` / `from hashlib import md5` — `smb2_server/smb2_auth.py:42,155,166,176,186` (HMAC-MD5), `smb2_server/smb2_spnego.py:18,358`, `launcher/ps1_vcd.py:143`, `launcher/ra_compressed_hash.py:133`, `launcher/ra_session_client.py:102`. Go Edge: no MD5. |

### MD4 (SMB/NTLM) — four distinct implementation families

| Family | Locations (all READ, sizes wc) |
|---|---|
| A. Java-derived (Raif Naffah, via jimmikaelkael) `smbman/md4.c` | RiptOPL `modules/network/smbman-ra/md4.c` 182 L / 4,875 B; Launchstation `iop/smbman/md4.c` 182 L / 4,875 B; SMS `iop/smbman-sms/src/md4.c` 182 L / 4,875 B — **all three byte-identical** (`md5sum e80d2421…`). Companion `auth.c` (93 L / 2,644 B) byte-identical RiptOPL↔Launchstation (`abb33f31…`), SMS 88 L near-copy; `des.c` (568 L / 25,912 B) **byte-identical in all three** (`8c7d69cd…`). RiptOPL keeps a *second, diverged* copy of family A: `modules/network/smbinit/md4.c` 175 L / 4,645 B (`smbinit/des.c` 564 L) — diff vs `smbman-ra` = includes/`transform()` const/buffer-union only (READ). |
| B. RSA `md4c.c` (usmb2, VEND) | RiptOPL `modules/network/smb2man/usmb2/md4c.c` 240 L / 6,849 B + `md4.h` 43 L; Launchstation `iop/smb2man/usmb2/md4c.c` — **byte-identical** (`c3a91c69…`). |
| C. FP unified `smb2auth` `md4_block()` | `smb2auth.c:31-68` in both RiptOPL (cdvdman) and Launchstation (smb2man), byte-identical file (above). |
| D. FP Python | PS2-Servers `smb2_server/smb2_auth.py:75-128` `md4(data)` 324 L file / 14,389 B; docstring:75-84 READ justifies it (`hashlib.new("md4")` raises on OpenSSL 3). No other Python MD4 in repo (grep READ). POPSLoader: no MD4 anywhere. |

**In-program double (the MD5/MD4 headline):** the menu-side `smb2man` IOP module in *both* RiptOPL and Launchstation compiles usmb2 (family B MD4 + condensed MD5, used by `usmb2/ntlm.c`) **and** `smb2auth.c` (family C MD4 + MD5 + SHA-256, used for signing in `smb2man.c:156-205`) — i.e. **2× MD4 and 2× MD5 in one IOP binary** (files + both call-site sets READ; final link INFERRED — no Makefile in `smb2man/`, IOP build is external to that dir).

**Verdict — MD5/MD4: LESS.** One-copy candidates: family A is already one text in 3 repos (keep 1 canonical, sync, don't rewrite); families B+C in `smb2man` are the pure consolidation candidate — drop usmb2's `md5.c/md4c.c/hmac-md5.c` (529 L combined per repo) and route `ntlm.c` through `smb2auth`, or vice-versa; never both. RiptOPL EE Deutsch MD5 stays (RA hash, no library MD5 is even enabled in its mbedTLS configs). PS2-Servers Python MD4 stays (no stdlib alternative exists). SMS/POPS: nothing to add.

---

## 2. SHA-1 / SHA-256 (SHA-512 noted)

| Repo | FP hand-rolled SHA-256 (loc : size) | FP/VEND SHA-1 | Library / stdlib |
|---|---|---|---|
| RiptOPL | IOP only: `modules/iopcore/cdvdman/smb2auth.c:125-181` `sha256_block()` (+ K table:125-133) in the 307 L file above — byte-identical copy in Launchstation. **No FP EE SHA-256.** | No FP SHA-1. VEND on disk, NOT enabled: `third_party/mbedtls/library/sha1.c` 480 L / 14,189 B (no `MBEDTLS_SHA1_C` in either config, READ). | **VEND mbedTLS 3.6.7** (`third_party/mbedtls/README.md` READ: RA + updater builds only): `library/sha256.c` 983 L / 30,275 B, `library/sha512.c` 1,115 L / 37,656 B (configs define `SHA224/256/384/512_C`, READ). EE call sites: `src/ui/selfupdate.cpp:27,113,187-280` (`mbedtls_sha256_*`), `src/platform/ratls.c:24-32,203-285` (TLS). Python tools: `hashlib.sha256/sha1` (one line). |
| Launchstation | **Two FP SHA-256s.** (a) EE: `src/mc_sha256.c:20-94` (`block:20`, `mcSha256Init:43`, `Update:53`, `Final:74`) 94 L / 3,285 B + `include/mc_sha256.h:13-22` 24 L / 717 B — header READ: "Written from the FIPS 180-4 specification… linked in builds without the cloud TLS stack and runs on the host in tests." Callers: `src/mc_card_view.c:412-489`, `src/mc_save_export.c:81-88`, `src/mmce_save_versions.c:82-87,141-156,303-332`. (b) IOP: `iop/smb2man/smb2auth.c:125-181`, identical to RiptOPL's. | No FP SHA-1. | **VEND (external, not in repo):** mbedTLS 3.6.7 fetched by `scripts/build_cloud_tls.sh:7-9` (tarball SHA-256 pinned, READ) into untracked `.cloud-deps/`. EE call sites in the *same binary* as (a): `src/cloud_http.c:25,142,842-1267` and `src/cloud_google.c:18,1230-1262` (`mbedtls_sha256_*`); `src/mc_save_export.c:11-12,53-78` uses mbedTLS AES + `mbedtls_md_hmac(MBEDTLS_MD_SHA1)` — **the same file that also calls FP `mc_sha256.c`** (READ). Python: `hashlib.sha256` (one line). |
| POPSLoader | — none in `src/iop/Lua`. | — none. | Python `.research/`+`tools/`: `hashlib.sha256/sha1` only (one line). |
| SMS | — none (`src/xz_*` is CRC, §3). | — none. | Python tools: `hashlib.sha256` only (one line). |
| PS2-Servers | — no hand-rolled SHA-1/SHA-256 in Python or Go. | — none. | Python STD: `hashlib.sha256` (`smb2_server/smb2_crypto.py:34,352,413` HMAC-SHA256 signing/KDF), `hashlib.sha1` (`launcher/achievement_loader.py:31`, git-blob ID). `cryptography` lib in tests only (`tests/test_smb2_signing.py:80`, KBKDF reference). Go Edge STD: `crypto/rand`, `crypto/subtle` (`internal/webui/webui.go:5-6`); no `crypto/sha256` import found (grep READ). |

**In-repo library+hand-roll double #1 (SHA-256): Launchstation EE.** mbedTLS SHA-256 (external lib, `cloud_http.c`/`cloud_google.c`) **and** FP `mc_sha256.c` (94 L) are linked into the same EE program; `mc_save_export.c` alone uses both. It is *not* a pure deletion candidate as-is: the header's stated reason is real — non-cloud builds and host tests have no TLS stack. Verdict is conditional (below), not "delete today."
**RiptOPL is NOT a SHA-256 double:** its FP SHA-256 lives on the IOP (cannot call EE mbedTLS) and its EE uses mbedTLS only; the vendored `sha1.c/md5.c/base64.c/cmac.c` files are on disk but their `_C` switches are off in both configs (READ), so they cost repo size, not binary size.
**Bonus FP crypto in PS2-Servers (re-verified at this head, ex-PS2SERVERS-014):** `smb2_server/smb2_crypto.py` 431 L / 17,278 B hand-rolls AES-128 (`AES128:88-114`, `_expand_key:73-85`, S-box:41-58), AES-CMAC pure (`aes_cmac_pure:132-161`), RC4 (`rc4:361-385`) and SP800-108 KDF (`kdf:341-357`, over stdlib HMAC-SHA256). **CMAC has exactly 4 implementations behind 1 dispatcher** `aes_cmac:124-129` → `_native_cmac:173-183` → (1) pure-Python, (2) `_bcrypt_cmac:192-234` (Windows CNG), (3) `_openssl3_cmac:260-305` (EVP_MAC), (4) `_openssl1_cmac:306-340` (`CMAC_*`) — count re-verified READ at `c5f021c4`.

**Verdict — SHA: LESS.** Keep exactly one SHA-256 per processor: IOP `smb2auth` (both repos, already identical — keep synced); EE: Launchstation should delete `mc_sha256.c` (94+24 L) *only if/when* the non-cloud build variant is dropped, otherwise keep it and stop adding third callers — do not add a third. SHA-1: hand-roll nothing, ever; current state (library-only) is already minimal. PS2-Servers CMAC: keep pure + *one* native path per platform actually shipped; the OpenSSL-1.1 path (34 L) is the deletion candidate on any OpenSSL-3-only target (INFERRED applicability).

---

## 3. CRC16 / CRC32 (+ CRC7/CRC8)

No `crc32.c` from zlib/libpng exists in any repo (filename search READ) — zlib/libpng are PS2SDK-external, so there is **no vendored zlib CRC to count**; every CRC below is FP or vendored-in-tree. Distinct implementations *per program* are counted, not per file.

| Repo / program | FP hand-rolled (loc : size) | Vendored-in-tree (loc : size) |
|---|---|---|
| RiptOPL EE | **2 in one binary:** (1) `src/platform/system.cpp:465-492` `USBA_crc32()` — poly `0x04C11DB7` non-reflected (i.e. the Ogg/USB-`ul.` naming hash, *not* IEEE CRC-32), table built at runtime into `crctab[0x400]`; callers `src/sources/supportbase.cpp:656,1226,1473`, `ethsupport.cpp:1427`. (2) `src/core/bgm.cpp:359-376` `oggCrcTab[256]`+`oggCrcDelta()` — same poly, delta-only variant for Ogg page repair. | — |
| RiptOPL PC tools | Same `USBA_crc32` text **copied twice more**: `tools/pc/iso2opl/src/iso2opl.c:48-70` (file 608 L / 16,022 B) and `tools/pc/opl2iso/src/opl2iso.c:43-65` (300 L / 7,876 B) — 3 copies of one function in one repo (READ). | — |
| RiptOPL IOP | MX4SIO: `modules/mx4sio_bd/src/crc16.c:4-27` `crc16()` 27 L / 1,045 B (nibble-less SD CRC-16, call site `spi_sdcard_driver.c:463-471`, gated by `CONFIG_USE_CRC16`) + `spi_sdcard_crc7.c` 83 L / 3,166 B (CRC-7 table). iLink: `modules/ilink/iLinkman/src/iLink_crom.c:45-65` `iLinkCalculateCRC16()` (IEEE 1394 CRC-16, nibble) — **duplicated** in `modules/bdmassault/ilink_bd_assault/src/iLinkman/src/iLink_crom.c:45-…` (files 396 L / 14,781 B vs 398 L / 14,915 B). | BDM/FatFs: `modules/bdm/bdmfs_fatfs/fatfs/ff.c:3297-3312` `crc32()` bit-by-bit IEEE `0xEDB88320`, GPT-only (file 7,257 L / 259,722 B, ChaN FatFs VEND-IN). |
| Launchstation EE/IOP | EE: `src/mc_save_export.c:373-387` `zipCrc()` — IEEE CRC-32, reflected, 16-entry nibble table (64 B, comment READ: deliberate vs "zlib's 8 KB tables"), in file 504 L / 14,857 B. IOP: `iop/mx4sio_bd/src/crc16.c` 27 L / 1,045 B + CRC-7 — **byte-identical to RiptOPL's** (`md5sum 57e84b57…`, READ). No `USBA_crc32`, no iLink CRC in EE/IOP grep. | — none (no FatFs CRC copy found). |
| POPSLoader | — **none** in `src/`, `iop/`, Lua (grep READ; `iop/ata_bd_fast/ps2atad.c:50` is only a `// CRC32:` module-hash comment, also in RiptOPL/Launchstation/SMS atad copies). | — none. Python `.research`/tools: `zlib.crc32` STD only. |
| SMS EE | — no FP CRC-32. | **3 vendored codec CRCs in one binary:** (1) XZ IEEE CRC-32: `src/xz_crc32.c:28-59` `xz_crc32_table[256]`/`xz_crc32()` 59 L / 1,261 B (Collin/Pavlov, public domain, header READ). (2) Ogg CRC-32: `src/SMS_OGG.c:158-…` `crc_lookup[256]` (poly `0x04C11DB7`) + use:2595-2615 (Xiph OggVorbis, header READ; file 5,533 L). (3) FLAC CRC-8: `src/SMS_FLAC.c:52-74` `_crc()` 257-byte table (vendored codec code). Python tools: `lzma`/`zlib` STD. |
| PS2-Servers | — no hand-rolled CRC in Python/Go (grep READ). rcheevos `vendor/…/rhash/hash_zip.c:138,241` only *reads* a stored ZIP CRC-32, computes none. | — none. STD: Python `zlib.crc32` in `launcher/status_dot.py:33` (PNG chunk CRC). Go Edge: no CRC import found. |

Per-program CRC-32 count: RiptOPL EE **2** (USBA + Ogg-delta, same poly, different init/purpose), RiptOPL BDM IOP **1** (FatFs), Launchstation EE **1** (zipCrc), SMS EE **2×CRC-32 + 1×CRC-8** (all inside separate vendored codecs), POPSLoader **0**, PS2-Servers **0 hand-rolled** (1 stdlib call).

**Verdict — CRC: LESS, mostly already minimal.** Real waste is only RiptOPL's 3× `USBA_crc32` text (EE + 2 PC tools — extract one shared host/EE source, −2 copies ≈ 46 L) and the duplicated iLink CROM file. MX4SIO CRC-16/CRC-7 is already one-copy across RiptOPL↔Launchstation (identical — keep synced, do not "improve" separately). SMS's three are codec-mandated and mutually non-substitutable (different polys/checks); Launchstation's nibble `zipCrc` is a justified size trade, not a deletion candidate. No repo should adopt zlib just for CRC.

---

## 4. Base64

| Repo | FP hand-rolled | Vendored | Stdlib |
|---|---|---|---|
| RiptOPL | **None** in first-party C/C++ (alphabet + `base64` greps READ — suspects RA/selfupdate contain none; selfupdate uses mbedTLS SHA-256 only). | `third_party/mbedtls/library/base64.c` 322 L / 9,420 B on disk; `MBEDTLS_BASE64_C` in **neither** config (READ) → not linked (INFERRED). | Python tools: `base64` module where used (one line). |
| Launchstation | **None** in first-party C (cloud/OAuth code does no base64/JWT/PKCE encoding — grep for alphabet/`b64`/PKCE READ, negative). | mbedTLS is external (§2); any base64 in it is not in this repo. | Python: `scripts/download_metrics.py:8,187,209` `base64.b64decode/b64encode` (GitHub API content). |
| POPSLoader | None (grep READ, negative). | None. | None found. |
| SMS | None (grep READ, negative). | None. | None found. |
| PS2-Servers | None hand-rolled. | xerabora/rcheevos vendor tree: no base64 implementation found (grep READ). | Python STD: `launcher/status_dot.py:13,84` `base64.b64encode`. Go STD: `native/ps2servers-edge/internal/webui/webui.go:7,188` `encoding/base64` (`RawURLEncoding`, password generation). |

**Verdict — base64: already LESS (zero FP copies in five repos).** Nothing to consolidate; the only cost is RiptOPL's unlinked vendored `base64.c` on disk, which is inseparable from its byte-for-byte mbedTLS subset rule (README READ) — leave it.

---

## 5. JSON-ish parsing

No general-purpose JSON library is vendored into any first-party EE/IOP program. What exists is three independent hand-rolled extractors/tokenizers, plus stdlib everywhere on the host side.

| Repo | FP hand-rolled (core loc : host file size) | Vendored | Stdlib (one line each) |
|---|---|---|---|
| RiptOPL | **Full tokenizer/parser:** `src/sources/achievements.cpp:151-309` — `jsonWs:151`, `jsonPutUtf8:159`, `jsonString:182-244`, `jsonSkip:245-273`, `jsonObject:275-299`, `jsonInt:300-309` (≈159 L core; file 797 L / 27,825 B), entry points `achievementsParseXerabora:352-396`, `achievementsParseGameId:485-501`. Bounded, UTF-8/escape-aware — the most complete of the three. | — none for JSON (mbedTLS has none). | Python tools/scripts: `json` module throughout (one line). |
| Launchstation | **Two extractors in one EE binary:** (a) `src/cloud_google.c:61-122` `json_string()` (strstr-needle, escape handling) + `json_int()`, plus `json_escape:157-176` and array walker `drive_browse_parse:766-838` (file 1,635 L / 58,934 B). (b) `src/dash_tools.c:715-746` `releaseJsonString()` — a *second, weaker* copy of the same strstr-needle idea (no escape handling, `strchr` end) + `releaseAssetDigest:747-789` (file 1,735 L / 68,204 B). | — none. | Python scripts/tests: `json` module (one line). |
| POPSLoader | **None** — no JSON in `src/`, IOP C, or any of its 4 shipped Lua files (`bin/POPSLDR/*.lua`, `etc/boot.lua`; grep READ, negative). The "Lua json?" suspect is disproven at this head. | — none. | Python tools: `json` module (one line). |
| SMS | **None** in C (grep READ, negative). | — none. | Python tools: `json` module (one line). |
| PS2-Servers | First-party Python/Go: **none hand-rolled** — all `import json` / `encoding/json`. FP C in vendor tree is classified VEND (next column). | **VEND, two parsers:** (1) `vendor/retroachievements/xerabora/client/src/jsmn.h` 471 L / 12,145 B (jsmn tokenizer, single header) + FP-style wrapper in `raweb.c:33-280` (`json_get:55-100`, `obj_get:121`, `tok_copy:162`, file 720 L / 22,546 B) — this wrapper is vendored-tree code, not PS2-Servers first-party. (2) rcheevos' own JSON handling in `vendor/retroachievements/rcheevos/src/rapi/rc_api_common.c` 1,630 L / 46,751 B et al. Go Edge config: `internal/webui/config_json.go` 53 L uses STD `encoding/json` only. | Python STD `json.loads/dumps` in ~25 launcher/server files (one line); Go STD `encoding/json` in webui/logging (one line). |

**Verdict — JSON: LESS by one, inside Launchstation only.** Cross-repo one-copy does **not** apply: RiptOPL's parser is a real bounded tokenizer for an untrusted RA document, Launchstation's are single-key extractors for Google/GitHub replies — different contracts, different binaries. The actionable duplicate is *intra*-repo: Launchstation has two `…JsonString` implementations in one binary; fold `dash_tools.c:715-746` onto `cloud_google.c:61-108`'s (the escape-aware one) and delete ~32 L. PS2-Servers/POPS/SMS: stdlib/vendored state is already minimal — add nothing.

---

## 6. XML / INI / HTTP parsing — duplicate check only (per brief)

- **XML:** no hand-rolled XML parser found in any repo (grep `parse_xml/xml_parse` READ, negative ×5) — no duplicate, nothing to report.
- **INI/config:** RiptOPL `src/core/config.cpp` and Launchstation `src/config*.c` are divergent fork-era config readers, **not** a verified full duplicate of one parser (no byte-identical parser file found) — not counted as a one-copy candidate.
- **HTTP:** hand-rolled HTTP clients exist in RiptOPL (`src/platform/ratls.c`, achievements fetch) and Launchstation (`src/cloud_http.c`, 1,312 L) but are distinct implementations for distinct TLS stacks — not duplicates; PS2-Servers uses STD `http.server.BaseHTTPRequestHandler` (`http_server/http_server.py:41,816`, `launcher/serve.py`, `launcher/ra_web.py:446`). No 2-repo full duplicate — no verdict.

---

## 7. Cross-repo one-copy summary + every in-repo double

**Same algorithm, FP hand-rolled in 2+ repos (one-copy verdict applies):**
1. `smb2auth.c` (MD4+MD5+SHA-256+HMAC) — RiptOPL cdvdman ≡ Launchstation smb2man, byte-identical 307 L. *Already one text; keep it that way — single canonical home, sync, never fork it.*
2. SMB1 `md4.c`/`des.c`/`auth.c` — RiptOPL ≡ Launchstation ≡ SMS (MD4/DES byte-identical ×3). *Already one text ×3; same sync rule.*
3. MX4SIO `crc16.c` (+CRC-7) — RiptOPL ≡ Launchstation, byte-identical 27 L. *Already one text.*
4. Deutsch MD5 — RiptOPL EE tree ≡ PS2-Servers rcheevos vendor (1-line diff). *Same upstream file arriving by two vendoring routes; no action — different programs/languages of build.*
5. usmb2 `md5.c/md4c.c` — RiptOPL ≡ Launchstation, byte-identical (vendored). *One upstream, two copies; consolidation is per-repo (§1), not cross-repo.*

**Every in-repo library + hand-roll (or hand-roll + hand-roll) double:**
- **Launchstation EE — SHA-256: LIBRARY + FP.** mbedTLS (external) in `cloud_http.c/cloud_google.c` + FP `mc_sha256.c:20-94`; both inside `mc_save_export.c`. Conditional deletion candidate (non-cloud variant is the blocker, READ from header).
- **RiptOPL + Launchstation `smb2man` IOP — MD4 ×2, MD5 ×2: VEND + FP.** usmb2 `md4c.c/md5.c/hmac-md5.c` + FP `smb2auth.c`, one module. Pure consolidation candidate (§1).
- **RiptOPL EE — CRC-32 family ×2: FP + FP.** `system.cpp:465-492` USBA + `bgm.cpp:359-376` Ogg-delta (same poly, different contract — mergeable only into a shared table, not one function).
- **RiptOPL repo — `USBA_crc32` ×3 texts** (EE + iso2opl + opl2iso tools; different programs, repo-level duplicate only).
- **RiptOPL repo — SMB1 MD4 family A ×2 texts** (`smbman-ra/md4.c` 182 L vs diverged `smbinit/md4.c` 175 L, + `des.c` ×2) — different IOP modules, near-duplicate.
- **Launchstation EE — JSON string extractor ×2: FP + FP** (`cloud_google.c:61` vs `dash_tools.c:715`, one binary). Pure deletion candidate (~32 L).
- **PS2-Servers — CMAC ×4 behind 1 dispatcher** (pure + bcrypt + OpenSSL3 + OpenSSL1, `smb2_crypto.py:124-340`). Not library+hand-roll of a *hash*; counted here per brief — OpenSSL1 path is the only deletion candidate.
- **Explicitly NOT doubles:** RiptOPL SHA-256/MD5/base64/CMAC — mbedTLS copies are on-disk-only with their `_C` switches off, and its FP SHA-256 is IOP-only; SMS's 3 CRCs are different checks in different vendored codecs; POPSLoader has no FP crypto at all.

*Confidence: file existence, sizes, line ranges, byte-identity (md5sum/diff) and call sites are READ. Final link membership is INFERRED where a module has no in-tree Makefile (smb2man IOP) or the library is built externally (Launchstation mbedTLS, RiptOPL edition builds via `tools/build_edition.py`). No PS2 build was run. No secret values were read or recorded.*
