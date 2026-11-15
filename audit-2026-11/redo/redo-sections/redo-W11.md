# W11 — Blind Redo Audit: third_party/ (integration), tools/, ship/

- Repo: RiptOPL, pin verified: `git rev-parse HEAD` = `2e347d5ac885cd0ff73e9ad4143781946396f492`
- Scope census (scripted): third_party/ 311 files / 8,334,877 B; tools/ 89 files / 684,791 B; ship/ 182 files / 9,637,271 B.
- Vendored bodies audited at integration level only (build lists, pins, tests); bodies listed as NOT-READ-BY-DESIGN in COVERAGE.
- Positive verifications (no finding): korium `UPSTREAM.json` archive SHA-256 matches `assets.zip`, and all 100 per-file digests match the archive contents (scripted). All 7 ca-roots DER fingerprints match `third_party/ca-roots/README.md` (scripted). mbedTLS `include/mbedtls/build_info.h:27-37` is version 3.6.7, matching the pin in `third_party/mbedtls/README.md`. `ship/POPS/UDPFS-NOTICES/PROVENANCE.json`: all 11 pinned member SHA-256s match the shipped files (scripted). Korium asset admission: every gfx file in the archive except `background.png` (reached via the `incebtion`→`background` rename in `tools/assets.py:174`) is embedded by `tools/assets.py embed`, which also re-verifies every digest before extracting (`tools/assets.py:141-158`). The PoeVeticaNew font is compiled in via `Makefile:1130` and `tools/assets.py:181`.

---

### W11-001 — ship/Example is a 5.9 MB snapshot of which the packager reads only 23 files; its full Neutrino tree is not what ships
- Category: 2 duplication / 7 repo clutter
- Locations: `RiptOPL/ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/` (whole tree, 137 files, 5,918,101 B — scripted); consumers at `RiptOPL/tools/package_edition.py:137-142` and `.github/scripts/package_release_app.py:24-26,228,238,248,257` (integration evidence)
- Problem: The packager consumes exactly 23 files / 1,752,047 B from this tree (scripted): the 8 `APPS/APP_RIPTOPL` template files, 8 `ART/*.png`, 6 `POPS` files (`CHEATS.TXT`, `IGR_BG.TM2`, `IGR_NO.TM2`, `IGR_YES.TM2`, `POPSTARTER.KELF`, `TROJAN_7.BIN`), and `EMBER/games/Per-Game-Folder/GAME FILES`. The remaining 4,166,054 B is never read by any tool (repo-wide grep): a complete second Neutrino distribution (78 files, 603,340 B, `neutrino/version.txt` = `v1.8.0-61-g7be8de2`, plus `neutrino/udpfs_server/*.py` sources), byte-duplicates of `ship/POPS/*` and `ship/EMBER/*`, and 5 `.url` files that duplicate `tools/pc/*.url`. The Example Neutrino copy is actively misleading: real kits take Neutrino from the pinned upstream/ORBIT archives at package time (`tools/package_edition.py:144-176`), so this snapshot can drift silently while looking like the shipped payload. The directory is also named `*.ZIP` while being a plain directory.
- Fix: Keep only the 23 consumed template files, under a name that does not claim to be a ZIP (e.g. `ship/app-template/`), and delete the rest of the tree — including the whole `neutrino/` snapshot, the duplicated `POPS`/`EMBER` payloads and the `.url` copies (the packager already takes shortcuts from `tools/pc/`). Move the 6 `POPS`-only files and the 1 `EMBER` file into `ship/POPS` / `ship/EMBER` so each kit source lives in one tree.
- Benefit: −4,166,054 B and −114 files of dead weight; one source per shipped file; no stale fake Neutrino in the repo.
- Effort: M · Risk: Med (a human may copy the Example tree by hand as an install reference — INFERRED; the packager does not) · Confidence: High (consumption READ + grep-verified; user-facing role INFERRED)

### W11-002 — genvmc segfaults when run without arguments (usage printed, then argv[1] dereferenced)
- Category: 6 bugs
- Locations: `RiptOPL/tools/pc/genvmc/src/genvmc.c:399-402`
- Problem: `main` calls `printUsage()` when `argc != 3` but does not return; it falls through to `strtol(argv[1], NULL, 10)`. Verified by execution in /tmp: compiled with the repo's own flags and run with no arguments, it prints usage and dies with SIGSEGV (exit 139). With one argument it proceeds with `argv[2] == NULL` as the output filename and fails later with a misleading "fatal error (-101)".
- Fix: Return `EXIT_FAILURE` immediately after `printUsage()` when `argc != 3`.
- Benefit: A user's first run of the tool stops crashing; wrong-argument use fails with the usage text only.
- Effort: S · Risk: Low · Confidence: High (READ + executed)

### W11-003 — ziso.py decompression loops forever on a corrupt or truncated ZSO block
- Category: 6 bugs
- Locations: `RiptOPL/tools/pc/ziso.py:62-75` (`lz4_decompress`), called from `RiptOPL/tools/pc/ziso.py:176-186`
- Problem: On `LZ4BlockError` the helper trims one byte off the input and retries, with no bound. Once the input is exhausted, decompressing `b""` raises the same error and `b""[:-1]` is still `b""`, so the loop never terminates and never raises — the `except Exception` in the caller never fires. Verified by execution: `lz4_decompress(b"\xff\xff\xff", 2048)` did not return within a 5 s timeout. Any damaged `.zso` hangs the tool at 100 % CPU instead of reporting the bad block.
- Fix: Stop when the trimmed input is empty (raise the error), or bound the retries to the original input length.
- Benefit: Corrupt ZSO files produce an error instead of an infinite hang.
- Effort: S · Risk: Low · Confidence: High (READ + executed)

### W11-004 — ziso.py carries a Python-3-broken helper and a never-called "future" feature
- Category: 1 dead code / 8 half-finished
- Locations: `RiptOPL/tools/pc/ziso.py:44-50` (`hexdump`), `RiptOPL/tools/pc/ziso.py:369-405` (`load_sector_table`)
- Problem: `hexdump` is never called anywhere in the file, and could not run if it were: it calls `ord(i)` on the ints produced by iterating `bytes` under Python 3, which raises `TypeError`. `load_sector_table` is likewise never called; its own comment says "In future we will support NC" — a per-sector compression-level feature that was never wired into `parse_args` or `compress_zso`. The tool itself is also outside the PC-tools build: `tools/pc/Makefile` builds only iso2opl, opl2iso and genvmc, and no repo file references `ziso.py` (grep-verified).
- Fix: Delete both functions (47 lines). Keep the tool itself, which is a usable standalone ZSO compressor.
- Benefit: −47 lines of dead/broken code; no behaviour change.
- Effort: S · Risk: Low · Confidence: High (READ + grep-verified)

### W11-005 — tools/lang_decompiler.py is dead: no caller anywhere, and it duplicates lang_compiler's YAML representer
- Category: 1 dead code / 2 duplication
- Locations: `RiptOPL/tools/lang_decompiler.py:1-60` (whole file); duplicate at `RiptOPL/tools/lang_decompiler.py:5-15` vs `RiptOPL/tools/lang_compiler.py:30-40`
- Problem: A repo-wide search finds zero references to `lang_decompiler` — no Makefile target, workflow, doc or script invokes it. It is a top-level script (no `__main__` guard, no arguments) that rewrites `lng_src/*.yml` from `lng/*.lng` as a side effect of being run, i.e. an accident hazard sitting next to live tools. Its `represent_str` YAML representer is a copy of the one in `lang_compiler.py`.
- Fix: Delete `tools/lang_decompiler.py`. The live direction (YAML → .lng) is `lang_compiler.py`, driven by `tools/assets.py:103-118`.
- Benefit: −60 lines; removes a script that silently rewrites translation sources if run.
- Effort: S · Risk: Low · Confidence: High (READ + grep-verified)

### W11-006 — Two language packers exist: tools/lng_pack.sh is superseded by package_edition.language_pack but still shipped and documented
- Category: 2 duplication / 8 redundant feature
- Locations: `RiptOPL/tools/lng_pack.sh:1-98`; live replacement at `RiptOPL/tools/package_edition.py:86-105`
- Problem: `package_edition.py`'s `language_pack()` already builds `RIPTOPL-LANGS.zip` for every release, including the same Serbian-font-from-Croatian special case (`lng_pack.sh:54-58` vs `package_edition.py:98-103`) and an equivalent README. `lng_pack.sh` is invoked by no workflow, Makefile target or Python tool (grep-verified), yet it is 98 lines of legacy shell that derives its version from `make oplversion`, greps `VERSION =` out of the Makefile and parses `DETAILED_CHANGELOG` — machinery from the pre-ps2build build. Two implementations of one pack means a fix (like the historical "last language silently dropped" fix in `lng_pack.sh:37-40`) lands in only one of them.
- Fix: Delete `tools/lng_pack.sh` and update the two mentions in `docs/LANGUAGES.md` to name `package_edition.py`'s language pack.
- Benefit: −98 lines; one language-pack mechanism, the one releases actually use.
- Effort: S · Risk: Low · Confidence: High (READ + grep-verified)

### W11-007 — Translation downloads are unpinned, contradicting the "pinned" claim in tools/assets.py
- Category: 7 build/repo (reproducibility)
- Locations: `RiptOPL/tools/download_lng.sh:5-10`; claim at `RiptOPL/tools/assets.py:5`; contrast `RiptOPL/tools/download_lwNBD.sh:6-9` and `RiptOPL/tools/download_cfla.sh:5-9`
- Problem: `download_lwNBD.sh` and `download_cfla.sh` check out exact commits. `download_lng.sh` clones branch `main` of the lang repo and on update does `git reset --hard origin/main` — whatever upstream has that day is what gets compiled into `lng/*.lng` by `assets.py lang` and embedded in the release language pack, with no commit or digest recorded anywhere. `assets.py`'s own docstring says the fetch step is "pinned by tools/download_*.sh", which is false for the translations — the largest of the three downloads.
- Fix: Pin `download_lng.sh` to a commit the same way `download_lwNBD.sh` does (clone, then `git checkout <commit>`), and bump the pin deliberately.
- Benefit: Reproducible language packs; a bad upstream lang commit cannot silently enter a release build.
- Effort: S · Risk: Low · Confidence: High (READ)

### W11-008 — PSUManager integration is a claim without a runner: the C++ validator and the vendored tests are never built or run
- Category: 8 half-finished
- Locations: `RiptOPL/third_party/PSUManager/README.md:12-16`; `RiptOPL/third_party/PSUManager/src/core/tests/PsuArchiveTests.cpp`; `RiptOPL/third_party/PSUManager/src/core/CMakeLists.txt:9-13`
- Problem: The README states the independent C++ validator (`.github/scripts/verify_psu_with_psumanager.cpp`, which includes `third_party/PSUManager/src/core/PsuArchive.h`) "loads each save through this vendored core and compares every member byte for byte" — but a repo-wide search finds no workflow, test or script that compiles or runs that validator: `tools/run_tests.sh` runs only `.github/scripts/test_*.py` and the HTTP tests, and no `test_*.py` references it. Likewise the vendored core's own test suite (`PsuArchiveTests.cpp`, wired only into the vendored `CMakeLists.txt` under `BUILD_TESTING`) is never built — nothing in the repo runs CMake on this tree. What actually validates PSUs today is the packager's own Python `inspect_psu` (`.github/scripts/package_release_app.py`), i.e. the same code that wrote them, not the independent implementation the README describes.
- Fix: Either wire the existing validator into `tools/run_tests.sh` (one g++ line against `PsuArchive.cpp`/`PsuDate.cpp`) so the claim becomes true, or delete the orphan validator and the vendored tests and correct the README to say the core is preserved for provenance only. The first option adds one command to an existing runner — no new machinery.
- Justification (for the wiring option): it makes an already-written, already-claimed independent check real; the alternative (deletion) adds nothing and is equally acceptable under LESS-NOT-MORE.
- Benefit: The release PSU validation either genuinely is independent, or the docs stop claiming it is.
- Effort: M · Risk: Low · Confidence: Med (validator and tests READ; "never run" INFERRED from exhaustive grep of workflows, test runners and scripts)

### W11-009 — Retired ps2sdk fallback trees keep dead source files, and ps2sdk-socket's README describes the retired build as current
- Category: 1 dead code / 7 repo clutter
- Locations: `RiptOPL/third_party/ps2sdk-socket/socket.c`, `RiptOPL/third_party/ps2sdk-socket/fdman.h`, `RiptOPL/third_party/ps2sdk-socket/README.md:3-7` vs `RiptOPL/third_party/ps2sdk-socket/UPSTREAM:4-6`; `RiptOPL/third_party/ps2sdk-ppctty/irx_imports.h:1-21` vs `RiptOPL/third_party/ps2sdk-ppctty/UPSTREAM:3-6`
- Problem: Both trees are provenance-only now. `ps2sdk-socket/UPSTREAM` says the fallback was "retired from build graphs… no fallback archive is linked", and the build confirms it: no build file references `socket.c`/`fdman.h` (grep-verified), and `tools/build_edition.py:253-257` copies only `LICENSE` and `UPSTREAM` from these trees into non-standard kits. Yet `ps2sdk-socket/README.md` still says in the present tense "Its build compiles `socket`, `bind`, `recvfrom`, `sendto` and `setsockopt` into a separate archive" — a reader (or a future agent) will believe a second socket implementation is live. `ps2sdk-ppctty/irx_imports.h` is the import header of a driver the tree's own `UPSTREAM` says is no longer bundled ("No bundled driver is built"); nothing includes it.
- Fix: Delete `socket.c`, `fdman.h` and `irx_imports.h`; rewrite `ps2sdk-socket/README.md` to past tense matching its `UPSTREAM` (provenance only). Keep `LICENSE`/`UPSTREAM` in both trees — they are what the kits actually redistribute.
- Benefit: −3 dead files (~21 KB tree shrinks to its redistributed records); the docs stop describing a phantom second socket stack.
- Effort: S · Risk: Low · Confidence: High (READ + grep-verified)

### W11-010 — The default ship/POPS/POPSTARTER.ELF is byte-identical to the DEBUG variant, not the MAIN variant
- Category: 6 bugs / 8 half-finished
- Locations: `RiptOPL/ship/POPS/POPSTARTER.ELF`; `RiptOPL/ship/POPS/POPSTARTER VERSIONS/DEBUG/POPSTARTER.ELF`; `RiptOPL/ship/POPS/POPSTARTER VERSIONS/MAIN/POPSTARTER.ELF` (same in the Example tree)
- Problem: Scripted MD5 census: all five `POPSTARTER VERSIONS/*` ELFs are distinct binaries of identical size (167,700 B), and the top-level default `POPSTARTER.ELF` — the one `package_edition.py` copies into every kit via `ship/POPS` — hashes identically to the `DEBUG` variant (`bbc61fa490df65d9527fcea7c4118170`), not to `MAIN` (`4a39d44dfb477ea747f5ca5e39ee011e`). Nothing in the tree documents the default being the debug build. INFERRED: either the default was copied from the wrong variant folder, or the DEBUG folder actually holds the intended default and is misnamed — one of the two labels is wrong.
- Fix: Decide which variant is the intended default; make `POPSTARTER.ELF` match it and, if DEBUG-as-default is deliberate, say so in one line next to the files (or in the POPS provenance notes).
- Benefit: Users get the POPStarter build the folder names promise; removes a silent mislabel in every shipped kit.
- Effort: S · Risk: Med (changing the default binary changes shipped behaviour; naming/documentation fix alone is Low) · Confidence: Med (hashes READ/scripted; intent INFERRED)

### W11-011 — The "last 10 commits" release-notes block is implemented three times, with three different escaping rules
- Category: 2 duplication
- Locations: `RiptOPL/tools/publish_editions.py:325-333` (`release_notes`), `RiptOPL/tools/publish_lite.py:155-170` (`release_notes`), `RiptOPL/tools/publish_llvm.py:184-208` (`release_notes`)
- Problem: All three publishers generate the same changelog list from `git log --no-merges -10` and markdown-escape commit titles — three times, divergently: `publish_editions.py:331` escapes via `re.sub(r"([\\`*_[\]<>])", …)` on `%H`; `publish_lite.py:161` escapes via a per-character join over `"\\`*_[]<>"`; `publish_llvm.py:184-187` uses `%h` (short hash, then links it as if full) and an escape set built as `"\\*_[]<>" + chr(96)`. A title-escaping fix or format change must currently be made three times and has already drifted. The sharing precondition is met: `publish_llvm.py` already imports `publish_editions` as `common`, and `publish_editions.py` imports `publish_lite`, so one helper placed in `publish_lite` is importable by both others with no new module.
- Fix: One `changelog(sha, git, base)` helper in `publish_lite.py` returning the formatted lines; call it from all three `release_notes`.
- Benefit: One escaping rule for every channel's notes; ~15 duplicated lines removed.
- Effort: M · Risk: Low · Confidence: High (READ)

### W11-012 — build_edition.py redefines the add() helper it could import from build_configuration.py
- Category: 2 duplication
- Locations: `RiptOPL/tools/build_edition.py:68-69`; original at `RiptOPL/tools/build_configuration.py:14-15`; existing import at `RiptOPL/tools/build_edition.py:13`
- Problem: `build_edition.py` already imports `CONFIGURATIONS, apply_configuration` from `build_configuration`, then defines a second, byte-identical `add(target, field, *values)` two dozen lines later. Two copies of the dedup-append rule for build definitions can drift (e.g. one learning to handle a new field type).
- Fix: Import `add` from `build_configuration` and delete the local copy.
- Benefit: −2 lines and one definition of the rule.
- Effort: S · Risk: Low · Confidence: High (READ)

### W11-013 — tools/pc/xeRAbora.url is dead: the packager hardcodes its contents instead of copying the file
- Category: 1 dead code / 2 duplication
- Locations: `RiptOPL/tools/pc/xeRAbora.url:1-2`; `RiptOPL/tools/package_edition.py:182-186`
- Problem: `package_edition.py` copies the other five kit shortcuts from `tools/pc/*.url` by name (lines 182-184), but for xeRAbora it ignores the existing `tools/pc/xeRAbora.url` and writes the identical two lines inline (line 184: `[InternetShortcut]\nURL=https://github.com/hacan359/xerabora/releases/tag/v1.0.1\n` — byte-identical to the file, READ). The file is referenced nowhere (grep-verified), so a future xeRAbora version bump edited in the obvious place — the `.url` file beside the other shortcuts — would silently not ship.
- Fix: Add `"xeRAbora.url": "xeRAbora.url"` to the existing `shortcuts` dict for RA kits and delete the inline `write_text`. (Or delete the file and keep the inline write — but the dict route matches the other five.)
- Benefit: One place per shortcut; the version pin lives with its siblings.
- Effort: S · Risk: Low · Confidence: High (READ)

### W11-014 — Both mbedTLS build definitions compile all 109 vendored library sources, including dozens that neither configuration can use
- Category: 4 size/memory (build size/time)
- Locations: `RiptOPL/tools/build_edition.py:114` and `RiptOPL/tools/build_edition.py:137` (`"sources": ["third_party/mbedtls/library/*.c"]`); configurations at `RiptOPL/third_party/mbedtls/riptopl_mbedtls_config.h` and `RiptOPL/third_party/mbedtls/riptopl_mbedtls_slim_config.h`
- Problem: The single glob compiles every one of the 109 `.c` files in `third_party/mbedtls/library/` (scripted count) for both the RA (full) and updater (slim) targets. Neither config enables the TLS server, server-side session cache/cookie/ticket, timing, sockets, debug, memory-buffer-allocator or PSA file storage (both configs READ in full; the vendor test at `.github/scripts/test_mbedtls_vendor.py:128-130` asserts several of these stay off), so the corresponding translation units — `ssl_tls12_server.c`, `ssl_tls13_server.c`, `ssl_cache.c`, `ssl_cookie.c`, `ssl_ticket.c`, `timing.c`, `net_sockets.c`, `debug.c`, `psa_its_file.c`, and the unused cipher/hash units (aria, camellia, des, md5, sha1, ripemd160, …) — can only ever produce empty or unreferenced objects. INFERRED (mbedTLS's per-file config-guard pattern; vendored bodies NOT-READ-BY-DESIGN): the ELF cost is mostly absorbed by the guards, so the certain cost is compile time and build-log noise on every edition build, plus a larger attack-surface review burden than the configs suggest. The glob is currently locked in by the vendor test (`.github/scripts/test_mbedtls_vendor.py:73,86` asserts the exact glob), so the waste is policy, not accident.
- Fix: Replace the glob with an explicit per-configuration source list in `build_edition.py` (the files each config's enabled modules need) and update the vendor test to assert the lists instead of the glob.
- Benefit: Faster, quieter edition builds; the compiled vendored surface matches the reviewed configs.
- Effort: M · Risk: Med (a missed required file fails the link loudly, so the risk is detectable, but both configs must be enumerated) · Confidence: Med (configs and glob READ; per-file emptiness INFERRED)

### W11-015 — The ps2build-mirror fallback is implemented twice: once in shell, once in Python, over the same pin contract
- Category: 2 duplication / 3 overengineering
- Locations: `RiptOPL/tools/ps2build_sdk.sh:123-149,347-377` (`mirror_fetch`, `pin_value`, `from_mirror`); `RiptOPL/tools/install_ports.py:89-160` (`mirror_file`, `mirror_pin`, `mirror_archive`)
- Problem: Two independent implementations fetch mirror releases, parse `pin.env`, and verify archives against `SHA256SUMS` whose own hash is pinned — the shell one for the SDK itself, the Python one for the ogg/vorbis packages, driven by the same environment variables (`PS2BUILD_SDK_MIRROR`, `PS2BUILD_SDK_TAG`, `PS2BUILD_SDK_SUMS_SHA256`, `PS2BUILD_SDK_MIRROR_TOKEN`, …). They already differ in detail (the Python side has the HTTPS-downgrade redirect guard and asset-id API path; the shell side has its own token handling in `api_fetch`), so a mirror-protocol fix or a security fix to token handling must be made — and reviewed — twice.
- Fix: Keep one mirror client. The Python implementation is the more complete one; have `ps2build_sdk.sh`'s mirror path call `install_ports.py`'s helpers (or a small shared module both use) instead of its own curl/parse code.
- Benefit: One mirror implementation to fix and audit; the token-handling rules exist once.
- Effort: L · Risk: Med (SDK bootstrap is on every CI path; the shell script currently has no Python dependency at its earliest stage) · Confidence: Med (both READ; net win INFERRED)

### W11-016 — tools/assets.py bakes transient agent scratch directories into the release version anchor
- Category: 7 repo clutter
- Locations: `RiptOPL/tools/assets.py:203-204`
- Problem: `opl_version()` computes the version's anchor commit by excluding paths from `git log`, and the exclusion list names local agent/tooling scratch dirs — `.claude`, `.agents`, `.codex`, `.codex-tmp-nhddl`, `.codex-tmp-wle-r3z` — alongside real repo paths. These are one-developer, one-machine temp directories (two are named for specific past tasks); they are not in the repository, so the exclusions do nothing in any clean checkout, and they fossilise a moment of one workstation's state into every future release's version logic.
- Fix: Drop the five scratch-dir entries from the exclusion list (keep `.github`, `notes`, `obj` and the other real paths).
- Benefit: Version logic describes the repository, not a workstation; −5 misleading entries.
- Effort: S · Risk: Low · Confidence: High (READ)

### W11-017 — iso2opl.c keeps ~90 lines of superseded implementations commented out beside the live ones
- Category: 1 dead code
- Locations: `RiptOPL/tools/pc/iso2opl/src/iso2opl.c:95-128` (commented `check_cfg` open/read version), `RiptOPL/tools/pc/iso2opl/src/iso2opl.c:169-195` (commented `write_cfg` version), `RiptOPL/tools/pc/iso2opl/src/iso2opl.c:226-273` (commented `write_parts` version); also `RiptOPL/tools/pc/iso2opl/src/isofs.c:161-173,1055-1058,1078-1080` (commented debug dump and open/close/lseek remnants)
- Problem: Each of iso2opl's three file-writing functions carries its previous POSIX-fd implementation in a block comment directly above the live `FILE*` implementation, and isofs.c carries smaller commented remnants of the same migration. The commented code is not compiled, not referenced, and duplicates the live logic closely enough that a reader must diff them to know which is real. Git history already preserves the old versions.
- Fix: Delete the commented blocks.
- Benefit: −~100 lines; the live implementation is the only one a reader can mistake for current.
- Effort: S · Risk: Low · Confidence: High (READ)

### W11-018 — crc32 and the integer typedef block are copied verbatim across the PC tools
- Category: 2 duplication
- Locations: `RiptOPL/tools/pc/iso2opl/src/iso2opl.c:48-76` and `RiptOPL/tools/pc/opl2iso/src/opl2iso.c:43-66` (`crc32` + `crctab[0x400]` global); typedef blocks at `RiptOPL/tools/pc/genvmc/src/genvmc.h:26-33`, `RiptOPL/tools/pc/iso2opl/src/iso2opl.h:63-70`, `RiptOPL/tools/pc/opl2iso/src/opl2iso.h:118-125`
- Problem: iso2opl and opl2iso are inverse tools over the same `ul.cfg` format and carry byte-identical `crc32()` implementations (including the same global 1 KB table and the same table-regeneration-on-every-call behaviour) — the CRC is the game-name hash that decides the `ul.<CRC>.<ID>.<part>` filenames both tools must agree on, so a divergence would corrupt interoperability, yet nothing keeps the copies in sync. The three PC-tool headers likewise repeat the same 8-line `u8…s64` typedef block. The sharing precondition (same logic in 2+ places, sharing removes code) is met for crc32: one `tools/pc/common/crc32.c`+header linked by both Makefiles is smaller than two copies.
- Fix: Move `crc32`/`crctab` into one shared source under `tools/pc/common/`, link it from the iso2opl and opl2iso Makefiles, and delete both copies. Leave the header typedef blocks alone if the shared header is not also adopted there.
- Benefit: One CRC implementation for the format both tools must agree on; −~55 duplicated lines.
- Effort: M · Risk: Low · Confidence: High (READ)

---

## COVERAGE

### Read in full (line-read)
- tools/ (all text files): `assets.py`, `build.py`, `build_configuration.py`, `build_edition.py`, `lite_devices.py`, `install_ports.py`, `package_edition.py`, `publish_editions.py`, `publish_lite.py`, `publish_llvm.py`, `analyze_coupling.py`, `audit_translations.py`, `check_llvm_purity.py`, `syntax_sweep.py`, `warning_gate.py`, `lang_compiler.py`, `lang_decompiler.py`, `make_bdmindex.py`, `make_save_icon.py`, `BUGREPORT-README.txt`, `coupling_baseline.json`, `warnings_baseline.json`, `download_cfla.sh`, `download_lng.sh`, `download_lwNBD.sh`, `install_ps2build.sh`, `lng_pack.sh`, `make_changelog.sh`, `ps2build_sdk.sh`, `run_tests.sh`.
- tools/pc/: `Makefile`, all six `*.url` files, `ziso.py`, `apa-recovery/apa_recover.py`, `apa-recovery/README.md`, `genvmc/Makefile`, `genvmc/src/genvmc.c`, `genvmc/src/genvmc.h`, `iso2opl/Makefile`, `iso2opl/src/iso2opl.c`, `iso2opl/src/iso2opl.h`, `iso2opl/src/isofs.c`, `opl2iso/Makefile`, `opl2iso/src/opl2iso.c`, `opl2iso/src/opl2iso.h`, `http/README.md`, `http/catalog_reference.py`, `http/http_conformance.py`, `http/fixtures/*.csv` (all 7), `http/fixtures/expected.json`, `http/tests/run.sh`, `http/tests/compare_catalog.py`, `http/tests/test_catalog.c`, `http/tests/test_catalog_limits.py`, `http/tests/test_conformance.py`, `http/tests/test_stream.c`, `http/tests/stub/*.h` (all 3).
- tools/hwtest/smb2probe/: `README.md`, `probe.c`, `probe_iop.c`, `probe_rpc.h`, `irx_imports.h`, `imports.lst`.
- third_party/ integration files: `korium/README.md`, `korium/UPSTREAM.json`, `ca-roots/README.md`, `mbedtls/README.md`, `mbedtls/riptopl_mbedtls_config.h`, `mbedtls/riptopl_mbedtls_slim_config.h`, `orbit-neutrino/README.md`, `orbit-neutrino/release.json`, `PSUManager/README.md`, `PSUManager/src/core/CMakeLists.txt`, `ps2sdk-ppctty/UPSTREAM`, `ps2sdk-ppctty/irx_imports.h`, `ps2sdk-socket/README.md`, `ps2sdk-socket/UPSTREAM`.
- ship/ text files: `POPS/UDPFS-NOTICES/PROVENANCE.json`, `POPS/UDPFS-NOTICES/README.md`, `POPS/UDPFS-NOTICES/PATHMAP.INI`, `POPS/UDPFS-NOTICES/THIRD_PARTY_NOTICES.md` (head), `POPS/UDPFS-NOTICES/README_CONFIG.txt` (head), `POPS/IPCONFIG.DAT`, `POPS/UDPFSCONFIG.DAT`, `neutrino/bsd-udpfsbd.toml`, `EMBER/Ember Official Webpage.url`, `EMBER/LICENSE-BETA.txt` (head), Example `APPS/APP_RIPTOPL/title.cfg`, `APPINFO.PBT`, `neutrino/version.txt`, `POPS/CHEATS.TXT` (head).
- Integration evidence outside scope (read for cross-checking only, not audited): `.github/scripts/test_mbedtls_vendor.py`, `.github/scripts/test_korium_builtin_assets.py`, `.github/scripts/package_release_app.py` (EXAMPLE/template usage), `.github/scripts/verify_psu_with_psumanager.cpp` (head), root `Makefile` (font/format/pc_tools targets), `.gitignore` (ship exceptions).

### Verified by script/execution
- Korium archive + 100 file digests; 7 ca-roots fingerprints; UDPFS `PROVENANCE.json` 11 digests; ship-wide MD5 census (duplicates, POPSTARTER variants); Example consumed-vs-total bytes; mbedTLS version 3.6.7; genvmc no-arg segfault (exit 139, /tmp build); ziso `lz4_decompress` hang (5 s timeout, /tmp).

### NOT read, with reason
- NOT-READ-BY-DESIGN (vendored bodies, per task): all of `third_party/mbedtls/library/` and `include/` except the two RiptOPL config headers and `build_info.h` version lines (280 files); `third_party/PSUManager/src/core/*.cpp/*.h` and `tests/PsuArchiveTests.cpp` bodies (integration only: CMakeLists + README read; the tests' non-execution is the finding, not their contents); `third_party/ps2sdk-socket/socket.c`, `fdman.h` bodies; `third_party/korium/assets.zip` (binary; digests verified instead); `third_party/ca-roots/*.der` (binary; fingerprints verified); `third_party/fonts/PoeVeticaNew.ttf` (binary).
- Binary/census-only (cannot line-read): all ship/ binaries and images (`.ELF`, `.KELF`, `.irx`, `.BIN`, `.TM2`, `.png`, `.icn`, `icon.sys`, `bgm.ogg`, `ember.elf`, POPSTARTER ELFs) — covered by scripted hash/size census; all `tools/**/__pycache__/*.pyc` (14 files, git-ignored build artifacts of sources read in `.py` form).
- Inside the W11-001 snapshot (not individually read; counted in its census and recommended for deletion unread on the same basis): `ship/Example/…/neutrino/` configs (31 `.toml`), `neutrino/README.md` (head only), `neutrino/udpfs_server/*.py` (6 files), and the Example duplicates of `ship/POPS`/`ship/EMBER` payloads (hash-verified duplicates of files covered above).
- `ship/POPS/UDPFS-NOTICES/UPSTREAM-README.md`, `LICENSE`, `AFL-2.0.txt`, `AFL-3.0.txt` and Example `POPS/IGR_*.TM2` etc.: provenance texts/binaries whose digests were verified against `PROVENANCE.json`; bodies not line-read.
