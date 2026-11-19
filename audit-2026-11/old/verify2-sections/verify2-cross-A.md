# Sable Audit — FULL VERIFICATION (adversarial re-derivation): Cross-repo X-01 … X-16

- **Verifier role:** verification worker, cross-A. Each finding was assumed WRONG and re-derived from source / re-counted in the clones; the original SUMMARY text (Sable-SUMMARY.md, cross-repo section) was used only to locate the claims, never as evidence. Where a claim is a census/identity claim, it was **re-run**, not re-read.
- **Mode:** READ ONLY in all five clones. No clone was edited, updated, or committed to.
- **Date:** 2026-11-14

## Pin checks (verified at start AND end of this pass; `git status --porcelain` empty in all five at both checks)

| Repo | Expected pin (task) | Clone HEAD (full) | Clean |
|---|---|---|---|
| RiptOPL | `2e347d5ac885` | `2e347d5ac885cd0ff73e9ad4143781946396f492` | yes |
| Launchstation | `9fb0598a79f0` | `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` | yes |
| POPSLoader | `29272cddbf01` | `29272cddbf0122f14e76bc3bdd75e3b46aa870be` | yes |
| Simple-Media-System | `e65ced39a27e` | `e65ced39a27eee8d996e9257e21594d1cac1c93d` | yes |
| PS2-Servers | `c5f021c4d386` | `c5f021c4d38698860f56b03498adc261dbb8d8dd` | yes |

Note: these pins are **newer** than the pass-1 SUMMARY pins (which were e.g. RiptOPL `677812185ac5`, SMS `b9a5c882d6d6`), so small count drift against pass-1 figures is expected and is reported as drift, not silently absorbed.

## Verdict table

| ID | Verdict |
|---|---|
| X-01 | **VERIFIED-DRIFT** |
| X-02 | **VERIFIED-DRIFT** |
| X-03 | **VERIFIED-DRIFT** |
| X-04 | **VERIFIED-DRIFT** |
| X-05 | **VERIFIED** |
| X-06 | **VERIFIED** |
| X-07 | **WEAKENED** |
| X-08 | **VERIFIED** |
| X-09 | **VERIFIED** |
| X-10 | **VERIFIED** |
| X-11 | **VERIFIED-DRIFT** |
| X-12 | **VERIFIED-DRIFT** |
| X-13 | **VERIFIED** |
| X-14 | **VERIFIED-DRIFT** |
| X-15 | **VERIFIED-DRIFT** |
| X-16 | **VERIFIED-DRIFT** |

**Totals: 6 VERIFIED / 9 VERIFIED-DRIFT / 1 WEAKENED / 0 REFUTED.**

---

## X-01 — VERIFIED-DRIFT (every PS2 program ships every language)

Evidence trail:
- Launchstation: `src/lang.c:7-56` — read in full. Nine `Language` arrays built by `#include`-ing `../Lang/{ENG,ITA,SPA,GER,POR,PTBR,POL,FRE,HUN}.LNG` (ENG as `Lang_Default` + 8 others = **9 languages compiled in**, exactly as claimed, lines 5–56 as cited). External loading exists in the same file: `Load_External_Language` at `lang.c:452`, `External_Lang_Buffer` at `:63`.
- POPSLoader: `bin/POPSLDR/system.lua:2568` `PLDR.I18N = {` with tables at FR `:2569`, DE `:2876`, PT `:3184`, ES `:3492`, IT `:3799`, HU `:4107`, SK `:4432` — **7 translated tables inline** (EN is the source/fallback, named in `PLDR.LANGUAGE_NAMES` at `:2556`-area with 8 names). SUMMARY's hedged "7–8 languages" is accurate. TSV copies exist under `docs/translations/` (brazilian-portuguese, hungarian, slovak) plus `slovak.xlsx` (binary) beside `slovak.tsv` — as claimed.
- SMS: re-ran the pair census — `for f in lng/SMS.lng_*; cmp $f docs/translation/$n`: **19 packs in each tree, all 19 pairs DIFF** (BG, CA, CZ, DE, EN, ES, FR, HU, ID, IT, NL, PL, PT, PT-BR, RU, SE, SK, TR, UA). "All 19 diverged" reproduces exactly. Exact-count format (SMS-022) confirmed in its body: positional packs, `tools/test_language_packs.py` enforces exact count.
- RiptOPL: `Makefile:191-193` `TRANSLATIONS =` list = **35 names** (counted programmatically, 35 after removing line-continuation backslashes); the same list is duplicated at `tools/assets.py:42` (`TRANSLATIONS = """Albanian Arabic …`).

**Drift (full reasoning):** the SUMMARY says the 35 translations are "maintained as a fork overlay" and RIPTOPL-033's body says `lng/fork/` holds "35 YAML files". At this pin `lng/fork/` holds **33 `.yml` files** (+ README.md, 34 files total) — the overlay is 33 files, the 35 figure is the full translation list (downloaded set + overlay). SMS pack byte totals have also moved since pass 1: `lng/SMS.lng_*` now sum to **98,202 B** and `docs/translation/SMS.lng_*` to **128,914 B** (pass-1 bodies said 156 KB / 180 KB). The mechanism — every language shipped to every user, in four different implementations — holds in all four repos; only the RiptOPL overlay count and the SMS byte totals are corrected.

## X-02 — VERIFIED-DRIFT (same media as GIF *and* MP4; generated docs committed)

Evidence trail:
- RiptOPL: `du -sb docs/assets` = **53,655,730 B** (claimed 53.7 MB ✓). File census: 6 GIF + 6 MP4 + 6 JSON + 53 PNG. The three tours (`info-navigation`, `library-tour`, `settings-navigation`) each exist as GIF **and** MP4 in **both** `docs/assets/ui/` and `docs/assets/ui/incebtion/` — the claimed "same three UI tours ×4" reproduces file-for-file. `README.md` = **1,116 lines** (`wc -l`, exact).
- Launchstation: `du -sb docs-site` = **17,359,939 B** (claimed 17.4 MB ✓). GIF/MP4 pairs: `application-views` (GIF 2,894,342 / MP4 337,371) and `theme-highlights` (GIF 4,885,148 / MP4 597,007) in both formats; `theme-tour` is MP4-only. The two GIF copies alone total 7,779,490 B, supporting the "≥7.7 MB duplicated" figure.
- POPSLoader: tracked-tree census via `git ls-files` + sizes: `.research/` = **312 files / 21,197,583 B** of a 30,417,169 B tracked tree = **69.7%** (claimed "70% of the repo, 21.2 MB" ✓).
- SMS: `docs-site/build.py:20-21` — `SITE = REPO/"docs"`, `WIKI = REPO/"wiki"` (both outputs of the generator, both committed). `docs/` = 240 tracked files / 23,069,339 B incl. `docs/downloads/SMS-manual.pdf` **9,321,329 B**. Byte-identity spot checks: `images/main_bg.png` ≡ `docs/assets/sms-wallpaper.png` ≡ `docs-site/static/assets/sms-wallpaper.png` (all md5 `4278004f98c8d4d2394e3ba3f40e1282`); search index committed in two serialisations (`docs/data/search-index.js` + `search-index.json` both present).
- All five repos: `git log --all --grep="softer dark-gray"` returns a "Docs site: softer dark-gray colour scheme" commit in **every** repo's history — the claimed synchronised docs-site maintenance is real.

**Drift:** SUMMARY's RiptOPL bullet says "70 docs files incl. dated checkpoint archaeology" (via RIPTOPL-025). At this pin `git ls-files docs` = **159 tracked files**, of which **71 are `.md`**. The "70" is defensible only as the markdown/docs-prose count (71), not as the docs/ file count (159). All other figures reproduce; the pattern (dual-format media + generated output committed as product, in all five repos) holds.

## X-03 — VERIFIED-DRIFT (branch and tag sprawl)

Evidence trail (re-counted at the pins; method: `git branch -r` excluding the `origin/HEAD` symbolic line, `git tag`):

| Repo | Remote branches (claimed → re-counted) | Tags (claimed → re-counted) |
|---|---|---|
| RiptOPL | 273 → **276** | 5 → **5** |
| PS2-Servers | 159 → **162** | 118 → **120** |
| Launchstation | 104 → **105** | 140 → **143** |
| SMS | 50 → **51** | 13 → **13** |
| POPSLoader | 37 → **38** | 37 → **37** |
| **Total** | **623 → 632** | **313 → 318** |

Sub-counts re-run: RiptOPL `claude/*` branches **227** (claimed 225); PS2-Servers `backup/*` branches **9** (exact); PS2-Servers auto tags `^main-<n>-` **82** (claimed 81); Launchstation `build-*` tags **91** (claimed 88); SMS `checkpoint-*` / `pre-*-checkpoint` branches present, mutable tags `latest` and `rolling` present (exact); POPSLoader `BETA-*` / `CHECKPOINT2` branches and `backup/*` / `checkpoint/*` tags present (exact). RiptOPL CI trigger confirmed: `.github/workflows/ps2build.yml:6` builds branches `[ps2build, rebuild/main, "claude/**"]`.

**Drift:** every count has grown slightly since the pass-1 pins (branches +9 net, tags +5 net) — the sprawl is *worse* than filed, not better, and no sub-claim was refuted. Corrected totals: **632 remote branches / 318 tags**.

## X-04 — VERIFIED-DRIFT (tests that grep source text)

Evidence trail (counts re-run with a Python census over the test trees):
- RiptOPL: `.github/scripts/test_*.py` = **278 files** (claimed 277); of those, **266 files use `read_text`** — the claimed 266 reproduces **exactly**; `read_text` occurrences = **697** (claimed 692 call sites; +5 by substring-occurrence counting, which also catches the RiptOPL host-shim's own `read_text` definitions). Sampled file (`.github/scripts/test_*` via the `unhost` shim) confirms the mechanism verbatim: tests monkey-patch `Path.read_text` and assert on production source text. The "suite did not finish in 120 s" runtime claim was **not re-executed** (it is a >120 s serial run; not needed for the verdict).
- Launchstation: `tests/test_*.py` = **213 files** (exact), **31,555 lines** (claimed 31,353; +202). `.github/workflows/compile.yml` = **813 lines** (claimed 812), with **212 `python3 tests/…` invocations** (exact). Sampled scrapers confirm source-text extraction (e.g. a test that regex-extracts `quickLaunchInput()` out of `src/dash_main.c` via `read_text()` and compiles the excerpt).
- SMS: `tools/test_*.py` = **59 files** (exact), 9,634 lines in the test files themselves; `test_mov_parser.py` mechanism (source extraction + re-declared C structs) is as described in SMS-019's body.
- PS2-Servers: real suite — `grep -rn "def test" tests/` = **1,529** (claimed 1,544). In-tree self-tests re-measured: `udpfs_server/compression_selftest.py` 545 + `multiclient_selftest.py` 643 + `pathguard_selftest.py` 241 + `udpbd_server/selftest.py` 179 = **1,608 lines, exact**.

**Drift (full reasoning):** two figures do not reproduce. (1) Launchstation's "127 source-text scrapers": **201 of 213** test files call `read_text` at all, and a conservative heuristic (file mentions a `src/`/`iop/`/`include/` path *and* calls `read_text`) gives **188** — no grep-based method I tried returns 127; that figure appears to have been a judgment classification, and by any mechanical count the scraping population is *larger* than filed, so the finding's direction is strengthened, not weakened. (2) SMS's "~14,000 lines" for `tools/` Python: at this pin all `tools/**/*.py` (excluding `__pycache__`) total **16,416 lines**. PS2's test count is −15. Everything else (266, 213, 212, 59, 1,608) reproduces exactly or within counting-method noise.

## X-05 — VERIFIED (.BAK / backup copies as a design habit)

Evidence trail: RiptOPL `.bak` sites at the exact cited lines — `src/sources/vcdsupport.cpp:2206,2287` (`snprintf(backup, …, "%s.bak", …)`), `:2326` (`// retain .bak for manual recovery`), `src/sources/vmcrebuild.cpp:124,173` + `include/vmcrebuild.h:5,12` (whole-card `<name>.bak` left permanently). POPSLoader: `bin/POPSLDR/system.lua:5234` `PromoteTmpToDest` (dest→`dest..".bak"` copy, then tmp→dest, then delete bak) called by `WriteAtomic` at `:5261` — the triple-write is present verbatim. SMS: `git ls-files | grep bak` returns tracked `images/jellyfish.jpg.bak-512` (**25,390 B**) despite `.gitignore:16` `*.bak`; live `jellyfish.jpg` is 44,236 B. PS2-Servers: `udpfs_server/ps2servers_core.py:7` — "The legacy udpfs_server.py entry point remains available for rollback" (module docstring, read directly), plus the 9 `backup/*` branches from X-03.

## X-06 — VERIFIED (POPSTARTER binaries duplicated within and across repos)

Evidence trail (`md5sum` over every `POPSTARTER.ELF` in both trees):
- POPSLoader: **5 copies**, each **167,700 B** (5 × 167,700 = **838,500 B total**, as claimed): `bin/POPSLDR/POPSTARTER.ELF` and `PROFILES/{MAIN,DEBUG,USBDELAY,USBDELAY_DEBUG}/`. The default-named copy and `PROFILES/DEBUG` are **md5-identical: `bbc61fa490df65d9527fcea7c4118170`** (the other three profiles differ) — "default = DEBUG" reproduces exactly. The POPStarter SMB IRX set is tracked twice byte-for-byte: all six pairs (`SMSUTILS, poweroff, ps2dev9, ps2ip, ps2smap, smbman` in `POPSTARTER/` vs `bin/POPSLDR/popsmb/`) are md5-identical (e.g. ps2ip.irx `525acea7f1d1e302bdb34e45c5363597` in both).
- RiptOPL: `ship/POPS/` holds **six** POPSTARTER ELFs (default + MAIN, DEBUG, USBDELAY, USBDELAY_DEBUG, USBDELAY_LONGER_DEBUG — three DEBUG builds, as claimed), and the identical six again under `ship/Example/…/POPS/` (12 total). Hashes match the POPSLoader set profile-for-profile (default/DEBUG `bbc61fa4…`, MAIN `4a39d44d…`, USBDELAY `668d310f…`, USBDELAY_DEBUG `5ba20aac…`).

## X-07 — WEAKENED (UDPFS: three copies in RiptOPL's IOP tree, three editions in PS2-Servers)

Evidence trail:
- PS2-Servers half — **stands.** `wc -l udpfs_server/udpfs_server.py` = **3,643 lines (exact)**; Core is a subclass (`ps2servers_core.py` `class AutoUdpfsServer(UdpfsServer)`, docstring at `:90-110` read directly: "Editing only the udpfs_server.py copy produces code that never executes on the shipped path, which has already happened once" — the quoted admission is real; SUMMARY cites it as `:98`, inside that docstring). Go Edge UDPFS exists as a third implementation (non-test Go under `native/ps2servers-edge/internal/udpfs/` = **3,384 lines**, not the claimed ~2,700). UDPBD-as-subset also exists 3× (standalone Python `udpbd_server/udpbd_server.py` 462 lines, standalone Go `internal/udpbd/{server,protocol}.go`, and the block handlers inside both UDPFS editions).
- Launchstation item — **stands.** `iop/__precompiled/udpfs_smap.irx` (8,081 B) is tracked beside the source-built target (`ps2.yaml:28-33` builds `iop/udpfs_smap/src/*.c`; `:644` embeds `udpfs_smap`). (There are in fact three precompiled UDPFS IRXs in `__precompiled/` — ioman and ministack as well.)
- RiptOPL half — **the central claim falls.** The SUMMARY says "the UDPFS IOP core is copy-pasted into 3 directories, byte-identical". At this pin the per-edition core files are **not copies at all**: `modules/network/udpfs_{bd,fhi,ioman}/src/udpfs_core.c` are 125-byte files whose entire content is a comment plus `#include "../../udpfs_shared/src/udpfs_core.c"`, and the `udprdma.c` files are 122-byte equivalents including `udpfs_shared/src/udprdma.c` (both read verbatim). The core was already de-duplicated into `udpfs_shared` — exactly the correction the audit's own round-2 pass recorded for RIPTOPL-008.

**What survives, exactly:** (a) the three PS2-Servers editions and the UDPBD triplication, unreduced; (b) Launchstation's stale precompiled IRX beside its source target; (c) on the RiptOPL side, only **header** triplication: `udpfs_packet.h` (9,812 B), `udprdma.h` (4,673 B), `udprdma_packet.h` (4,286 B), `udprdma_seq.h` (432 B), `udpfs_core.h` (2,474 B) and `irx_imports.h` (349 B) are md5-identical across `udpfs_bd/fhi/ioman`, and `mprintf.h` is md5-identical (`8724e63c…`) in **5** UDPFS dirs (bd, fhi, ioman, ministack, smap) — the "(mprintf.h in 5)" parenthetical reproduces. **What falls:** "core copy-pasted into 3 directories, byte-identical" — the .c core is a shared include, so the RiptOPL fix prescription ("one IOP source dir" for the core) is already half-done; the remaining RiptOPL work is the triplicated headers and the three directory shells. Hence WEAKENED, not VERIFIED-DRIFT: a headline mechanism, not just a count, is refuted on one of the finding's two sides.

## X-08 — VERIFIED (SMB implemented over and over, both sides of the wire)

Evidence trail: Launchstation `iop/smbman` = **7 `.c` sources** (as claimed) beside `iop/smb2man` (SMB2/3 client); the libsmb2 SMB **server** target in `ps2.yaml:295-363` lists **~56 vendored libsmb2 sources** (fetched at build time by `scripts/fetch_libsmb2.sh`, which exists and pins upstream + applies `iop/smbd/libsmb2-*.patch`), embedded alongside FTP/host:/NetFS. PS2-Servers: SMBv1 Python `smbv1_server/smbserver_opl.py` = **1,862 lines (exact)**; Go `internal/smb/{handlers 902, server 745, wire 263}` = **1,910 lines (exact)**; parity test `tests/test_smb_wire_parity.py` docstring read directly ("Edge's Go port therefore has to match *it*, not the SMB specification"). SMB2 CMAC stack in `smb2_server/smb2_crypto.py`: **four** implementations as claimed — `aes_cmac_pure` `:132`, `_bcrypt_cmac` `:192`, `_openssl3_cmac` `:260`, `_openssl1_cmac` `:306`, behind the `aes_cmac` dispatcher `:124`; hand-rolled MD4/AES/RC4/SPNEGO present in `smb2_auth.py` / `smb2_spnego.py`. IPC$ file `smb2_server/smb2_srvsvc.py` = **289 lines (exact)**. RiptOPL parallel stacks all present (`modules/network/{smbman-ra,smb2man,nfsman,httpclient}`, `src/sources/{eth,hdd,mmce,udpfs,bdm}*support`), and NBD is in every build: `Makefile:387,396` make `all`/`release` depend on `download_lwNBD`.

## X-09 — VERIFIED (per-device launch leg, copy-pasted)

Evidence trail: `grep -rn "strcpy(filename, game->startup)" RiptOPL/src` returns **exactly the six claimed sites at the exact claimed lines**: `bdmlaunch.cpp:904`, `ethsupport.cpp:1504`, `hddsupport.cpp:2787`, `mmcesupport.cpp:1556`, `udpfssupport.cpp:977`, `udpfssupport.cpp:1134` — 6 call sites in 5 files, no more, no fewer. Launchstation half: all named files exist — `src/{popstarter,popstarter_path,popstarter_vcd,popstarter_gameid,popstarter_elf}.c`, `src/{ember,ember_gameid}.c`, `src/{gui_neutrino,neutrino_iso,neutrino_smb,neutrino_gameid}.c`, each with its own game-ID implementation (`*_gameid.c` ×3 plus `main_gameid*`).

## X-10 — VERIFIED (iLink / IEEE 1394 carried end-to-end)

Evidence trail: RiptOPL's two iLink driver copies at the exact claimed sizes — `modules/ilink/iLinkman/src/iLink.c` **365 lines** vs `modules/bdmassault/ilink_bd_assault/src/iLinkman/src/iLink.c` **369 lines**; `diff` between them = 43 diff lines (include-path change, an added `BD_iLink_start` extern, and formatting) — different content, already diverged, as claimed. SMS: both IRX present in both forms (`irx/iLinkman.irx` + `.irx.xz`, `irx/IEEE1394_bd.irx` + `.irx.xz`), with iLink references in the five claimed EE files (`SMS_IOP.c, SMS_GUIDevMenu.c, SMS_GUIMenuSMS.c, SMS_FileDir.c, SMS_Config.c` — all grep-confirmed) plus a dedicated manual page (`docs-site/content/ilink.html`). POPSLoader: dedicated embed confirmed — `Makefile:234-235` bin2c rule for `bin/POPSLDR/usbd.irx.ilink` (48,500 B), registered twice in `src/embed_assets.cpp:164,218`.

## X-11 — VERIFIED-DRIFT (legacy parallel stacks for one flag / one variant)

Evidence trail: Launchstation `legacy_net_drivers` at the **exact claimed lines** `src/config.c:641,858,1018`; the v1.0 stack is `iop/__v10/{ps2dev9.irx 13,193 B, ps2ip.irx}` totalling **131,706 B** for the directory (≈131 KB as claimed). SMS: BDM conditionals re-counted — `grep -rn "ifdef BDM|ifndef BDM" src include` = **86 sites in 17 files** (claimed ~90 sites / 16 files); the CI job is verbatim as claimed (`compilation.yml` build-legacy job comment: "it is never shipped, but the knob exists, so keep it building"). SMS dual IOP delivery confirmed: `src/SMS_Data.c` = **1,634,985 B** legacy blob beside the `irx/` set (43 files). RiptOPL: edition/configuration tooling as claimed (`tools/build_edition.py:18` EDITIONS + lite meta-editions, `tools/build_configuration.py`, `tools/lite_devices.py`), and the wOPL foreign-format compat layer is present and commented as permanent dual-format support (`src/core/config.cpp:80-102`).

**Drift:** `ps2ip.irx` is **118,513 B** at this pin, not 118,183 B (+330); SMS BDM census is 86 sites / 17 files, not ~90 / 16. Both are within the findings' own "~" tolerances in spirit but are corrected here; no mechanism is affected.

## X-12 — VERIFIED-DRIFT (unsafe string handling, counts are the point)

Evidence trail:
- Launchstation: re-ran the count with scope `src + include + iop`, pattern `\b(strcpy|strcat|sprintf)\s*\(` over `.c/.h` = **863 hits — exact reproduction** of the claimed 863. The `%n` chain in config save is present (`src/config.c:548` `sprintf(tmp, "CNF_version = 3\r\n%n", &CNF_size)`, further `%n` at `:554,581,636,676,687,697`).
- RiptOPL: credential copies at the exact claimed lines — `ethsupport.cpp:1192-1194` (`strcpy(smb.user/pass/share, …)`) and the second block at `:1444-1446`; OSD-history `sprintf` sites present (`src/core/OSDHistory.cpp:41,153` sampled); unchecked malloc present (`src/platform/util.cpp:873-874`, malloc immediately followed by `sprintf(path, …)` with no NULL check).
- POPSLoader: all three sites read directly — `src/luagraphics.cpp:276-280` (`malloc(16)` + `sprintf(buffer, "%i", (int)image)`), `src/luasystem.cpp:721` (512-entry `sceMcTblGetDir` stack array), `luasystem.cpp:600,681` (unchecked `getcwd`).
- PS2-Servers: NFS cap present (`nfs4_server/nfs4_server.py:54` `MAX_CONNECTIONS = 32`); `_take_445` / LanmanServer takeover present (`smbv1_server/smbserver_opl.py:1546-1579`); no `flock`/`O_EXCL`/`LockFile` write-claim found in the Python or Go UDPFS trees.

**Drift (full reasoning):** SMS's counts do **not** reproduce under any scope I tried. SMS-014's stated method is "grep, src/*.c": that yields **118 strcpy / 51 strcat / 71 sprintf occurrences** at this pin. The widest scope (whole tree, occurrences) yields 169 / 59 / 82. Neither reaches the claimed **176 / 62 / 87**. The cited high-risk sites themselves are real (e.g. `src/SMS_ContainerM3U.c:351` `strcpy(lTitle, lpPtr + 1)` from playlist file content, read directly), so the defect stands, but the headline counts are corrected to **118 / 51 / 71** on the finding's own stated scope (240 total EE call sites — consistent with the audit's round-2 narrowing of SMS-014 to 238 EE call lines). One further overstatement in the SUMMARY's X-12 fix note: it says the single-writer fix already exists in Go Edge "with EBUSY" — in the Go UDPFS tree `EBUSY` appears only as an errno constant/mapping (`internal/udpfs/errno.go:7,28`, `errno_other.go:17`); no per-path write claim was found, so PS2SERVERS-013's "no exclusion in any edition" is the accurate statement.

## X-13 — VERIFIED (config/settings implemented more than once per program)

Evidence trail: Launchstation duality present — `src/config.c` (1,782 lines, classic CNF) and `src/dash_store.c` (870 lines) both persist settings; `dashStoreSaveSettings` at `dash_store.c:683` (exact line from LAUNCHSTATION-024). PS2-Servers: all **nine** claimed Python parser entry points exist at the **exact claimed lines** — `udpfs_server.py:3441 main()`, `ps2servers_core.py:523 build_parser()`, `smb2_server.py:1727 main()`, `smbserver_opl.py:1674 main()`, `nfs4_server.py:1046 argparse`, `http_server.py:1131 argparse`, `udpbd_server.py:381 main()`, `achievements.py:333 argparse`, `directlink.py:1833 argparse` — plus the Go flag sets and Edge config formats. The six path-containment locations all exist (`smb2_server/smb2_paths.py`, SMBv1's own `Share.resolve`, UDPFS resolution, `http_server.py:389 _contained`, `launcher/virtual_exfat.py`, Go `internal/filesystem/root.go` + `internal/udpfs/pathops.go`). Edge WebUI's eight named files sum to **2,040 lines** (claimed ~2,050). Portable-mode probe read directly: `launcher/config.py:32-49` `_portable_dir()` writes a `tempfile.TemporaryFile` probe, called from the config accessors. SMS: TEMP diagnostic present at the claimed lines (`src/SMS_Config.c:66-69` `/* TEMP DIAGNOSTIC */ g_SaveDiag[64]`, uses at `:883,943-945,1074-1095`), and SMS-012's duplicated mc-icon copy is still there — the file now has a helper for one path (`SMS_Config.c:783ff`) whose own comment concedes "The legacy fixed-mc save further down deliberately keeps its OWN inline copy of this" (`:799`). POPSLoader triple-write is X-05, verified there.

## X-14 — VERIFIED-DRIFT (byte-identical files and agent/meta clutter)

Evidence trail (all hashes re-run):
- RiptOPL: `cmp AGENTS.md CLAUDE.md` → **identical**, md5 `f93ecc9893762f8ecb6c96f5c85d777b` both. `audio/bgm.ogg` = **324,182 B** (exact) with the Makefile "only as a reference" comment; second, different copy in the ship bundle = 369,632 B, md5 differs (`a639ef8b…` vs `af3e8d4b…`). Tracked prebuilt debug IRX present: `modules/debug/{drvtif,drvtif-ingame,tifinet,tifinet-ingame}.irx`.
- Launchstation: `iop/mmceman/src/ioplib.c` ≡ `iop/mx4sio_bd/src/ioplib.c` (md5 `14acaf5b34248d9c9c976580a5175d39` both); `res/bgm.ogg` = **462,185 B (exact)**; `res/sfx/boot.adp` = **143,984 B** (≈144 KB); `res/icons/*.png` = **16 files (exact)**; additionally `AGENTS.md ≡ CLAUDE.md` and the `res/memory-card/{copy,del,list}.icn` trio are md5-identical.
- POPSLoader: tarball `iop/embed/BDMASSAULT_MX4SIO/SourceCode-BDMAssault-mx4sio.tar.gz` = **1,466,084 B** (≈1.47 MB, exact); UI images both loose and embedded — `bin/POPSLDR/IMG/` = **67 PNG / 330,675 B (exact)** plus the `embed_assets.cpp` registry.
- SMS: plain `.irx` beside `.irx.xz` re-counted — **19 plain `.irx`, all 19 with `.xz` twins, 323,438 B of plain copies** (claimed 323 KB ✓). Handoff folder present with its README's first lines verbatim: "Delete this folder before the branch is merged to master" (`docs/investigations/2026-11-11-handoff/README.md`). `utils/DDrawSrv.exe` = 45,056 B (44 KB as claimed).
- PS2-Servers: banner tracked twice byte-identical — `ps2serversgithubbanner.png` ≡ `docs/assets/ps2servers-banner.png` (md5 `7d13770364c4192c47463f2ba0ee1ff0`); Go testdata under `native/**/testdata/` totals **3,216,216 B** (≈3.1 MB as claimed).

**Drift:** RIPTOPL-031's "twenty identical empty SDK stub headers" — the largest md5-identical group across `tests/host/sdk_stub/` + `tests/host/stub/` is **19 files** (the 13-byte `#pragma once` group, md5 `b5ad224e…`), not 20; `sdk_stub/` holds 23 headers total. One-file overcount; every other byte-identity claim in X-14 reproduces exactly, so the verdict is VERIFIED-DRIFT on that single figure.

## X-15 — VERIFIED-DRIFT (watcher/publisher workflow sprawl)

Evidence trail: RiptOPL **12 workflows (exact)**, six with `cron:` schedules — `docs-sync, ember-watch, neutrino-watch, orbit-neutrino-watch, ps2build-sdk-watch, wiki-publish` (the six claimed) — and the `claude/**` build trigger (X-03). Launchstation `download-metrics.yml:5` cron `'17 */3 * * *'` = **8×/day (exact)**. POPSLoader **10 workflows / 2,062 lines — both exact**, including `retract-mislabeled-ember-beta.yml` (a one-shot retraction: it triggers only on a push to its own path, its job already done) and `opencode.yml` (AI-comment bot, triggers on `/oc` comments). PS2-Servers' two release workflows: `release.yml` 606 + `release-on-main.yml` 489 = **1,095 lines (exact)** running the same build/source/edge/release job set. SMS has 6 workflows; `test-media.yml` republishes the media pack on every master push (trigger read: `push: branches: [master]`, no path filter).

**Drift (full reasoning):** two small corrections. (1) RiptOPL workflow total is **2,222 lines**, not 2,220. (2) The SUMMARY's SMS clause — "3 of 6 workflows rebuild/republish docs or media **on every master push**" — overstates two of the three: only `test-media.yml` fires on *every* master push; `docs.yml` (27 lines) and `wiki.yml` are **path-filtered** pushes (docs/wiki run `docs-site/build.py --check` / publish only when `docs-site/**`, `wiki/**` etc. change). SMS-024's own body states this correctly; the SUMMARY compression does not. The sprawl mechanism (watchers/publishers/one-shots living in product repos) holds in all five repos.

## X-16 — VERIFIED-DRIFT (second products inside first products)

Evidence trail — an unusual number of exact figures:
- PS2-Servers RetroAchievements: vendored C under `vendor/retroachievements/` = **52,963 lines (exact)** across 115 files; Python RA stack (`launcher/ra_*.py + achievements.py + achievement_loader.py + achievement_viewer.py + caduceus.py`) = **5,201 lines (exact)**; two runtimes confirmed (`launcher/achievements.py:339` `--owned-runtime` flag, help text "Run the experimental PS2-Servers owned RetroAchievements runtime instead of the bundled xeRAbora engine") and two modes in the registry entry. Direct-link product: `launcher/directlink.py` = **1,927 lines (exact)** plus the `gui.py` `_direct_link_*` family. Two SQLite catalogues at exact claimed sizes (`game_library.py` 497, `library_catalog.py` 642). Three management HTTP servers confirmed (`launcher/achievement_viewer.py:88`, `launcher/ra_web.py:545`, Edge webui) beside the legitimate game-serving `http_server/http_server.py:1097`. Discord presence / RA sounds / art fetch / OBS export files all present (`launcher/{discord_presence,ra_sounds,art_fetch}.py`, `obs_folder` field).
- Launchstation: Google Drive subsystem at exact claimed sizes — `cloud_http.c` 1,312 + `cloud_google.c` 1,635 + `qrcodegen.c` 1,027 lines, CA roots header `include/cloud_google_roots.h`, `WLE_NATIVE_CLOUD` defined in `ps2.yaml:626`, and the duplicate PC-side relay at `windows/cloud-relay/`. Exploit product: `main_exploit_installer.c` 2,519 + `kelf_signer.c` 1,153 lines; `exploits/` = **147,662 B across 14 files (exact)**.
- RiptOPL: `gfx/` holds **142 PNG files** (claimed ~130 embedded); both glyph sets in `tools/assets.py` (PNG_ASSETS + 24 glyph PNGs per RIPTOPL-011). FatFs: `modules/bdm/bdmfs_fatfs/fatfs/ffunicode.c` = **15,593 lines (exact)** compiled for `#define FF_CODE_PAGE 869` (`ffconf.h:87`). mbedTLS glob at the exact claimed lines: `tools/build_edition.py:114` and `:137` both append `"sources": ["third_party/mbedtls/library/*.c"]`.

**Drift:** one clause only — "three library UIs" (PS2-Servers). The launcher contains exactly **two** library UIs (`library_gui.py` 446 lines, `library_panel.py` 561 lines); the third library module, `library_index.py`, is an index over the folders, not a UI. PS2SERVERS-026's own location list names only the two as UIs. Corrected: **two SQLite catalogues and two library UIs (plus a third index module)**. Everything else in X-16 reproduces, most of it to the exact line.

---

## New candidate findings

**None.** Everything new surfaced by this pass is a correction to an existing finding's scope or figures, not a new defect: the RiptOPL UDPFS shared-include structure (folds into X-07, and was already recorded as the round-2 correction to RIPTOPL-008), the Launchstation path-filtered docs/wiki triggers (folds into X-15), the SMS count corrections (fold into X-12 / SMS-014), and the one-file stub-header overcount (folds into X-14 / RIPTOPL-031). No new cross-repo defect not already filed somewhere in the audit was found.

## Method / limits

- All verdicts are source/census-level at the pins above; no PS2 build or hardware exists in this VM, so runtime effects remain INFERRED exactly as in the original findings.
- Branch/tag counts (X-03) are a snapshot of the clones' fetched remote refs at the pins, not a fresh fetch from GitHub; a live fetch could move them again — which is itself the finding's point.
- The X-04 "suite did not finish in 120 s" runtime observation was not re-executed; every other numbered claim in X-01…X-16 was re-run or re-read as itemised above.
