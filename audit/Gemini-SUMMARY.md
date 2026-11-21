# Cross-Repo Audit Summary (`Gemini-SUMMARY.md`)

Exhaustive read-only review of NathanNeurotic's five PlayStation 2 homebrew repositories under one principle: **LESS, NOT MORE**.

## Audited Commits, Footprint, and Host Checks

| Repo | Branch @ Commit (`HEAD`) | Tracked Files | Tracked Bytes | Local Tags Observed | Latest Host Verification Summary |
| --- | --- | ---: | ---: | --- | --- |
| `Launchstation` | `master` @ `9fb0598a` | 1,065 | 29,032,754 B | `build-1174`..`build-1177`, `latest` | `178/213` PASS, `35` FAIL, `0` TIMEOUT (`test_app_packages.py`, `test_ember_gameid.py`, `test_pccf.py` standalone `rc=0`; WinLibs MinGW `-fsanitize`/POSIX/CRLF/COFF host failures) |
| `POPSLoader` | `master` @ `29272cdd` | 609 | 30,647,906 B | (none locally; 37 remote tags / 38 remote branches) | `host_harness` `62/62`, `pad_harness` `13/13`, `test_disc_layout` `30/30`, `test_udpfs_config_runtime` `26/26`, `test_translation_handoff` `7/7`, `docs_verify` PASS; `test_udpfs_integration` FAIL (Windows CRLF on `PATHMAP.INI.example`), `png_decoder_harness` ERROR (missing `pkg-config`) |
| `PS2-Servers` | `main` @ `c5f021c4` | 596 | 12,538,450 B | `main-325-5179b4b`, `main-326-40c93c6`, `main-327-c5f021c` | `go test -count=1 ./...`: `10` packages PASS, `3` `[no test files]`; `version_source`, `verify_docs`, `check_release_compliance`, `check_ai_attribution`, 3 selftests PASS (`check_desktop_startup.py` exit `2` without arg); Python `unittest discover`: `1556` tests in `215.218s`, `failures=7, errors=46, skipped=41` |
| `RiptOPL` | `rebuild/main` @ `2e347d5a` | 2,381 | 101,134,908 B | `rolling-incebtion`, `rolling-korium`, `rolling-lite`, `rolling-llvm`, `rolling-ra` | `.github/scripts` parallel batch: `216/278` PASS, `50` FAIL, `12` TIMEOUT (`130.3s`) |
| `Simple-Media-System` | `master` @ `e65ced39` | 1,012 | 38,282,639 B | `rolling` | `check_devmenu` PASS (`62` writes), `sms_converter` `64` PASS; `docs-site/build.py --check` exit `1`; `tools/test_*.py` (`59` scripts): `32` PASS, `24` FAIL (`test_mpeg_ps_probe.py` `rc=1`, `test_boot_config.py` CRLF/BOM), `2` TIMEOUT, `1` SKIPPED |

Across all five repositories, exact byte-identical cross-repo files account for **5,400,497 B** (`181` distinct SHA-256 duplicate groups, excluding near-identical forked C, Python, Shell, and YAML trees).

---

## 1. Cross-Repo Duplicates and Shared Driver Bugs (`CROSS-001..017`)

Each shared duplicate tree or multi-repo driver defect is recorded once below instead of repeating it in individual repo files.

### CROSS-001: Duplicated POPS/BDMAssault/Ember binaries and tightly coupled kit fetchers (`4.63 MB` identical waste)
- **Category**: 2 (Duplication), 7 (Build/CI/repo clutter)
- **Location(s)**:
  - `POPSLoader` (`bin/POPSLDR/`, `POPSTARTER/`) & `RiptOPL` (`ship/Example/`, `modules/bdmassault/`): `25` byte-identical file groups totaling `4,629,038` B duplicate waste
  - `POPSLoader/tools/build_release_kit.sh:1-89` (lines `8-43` clone legacy `NathanNeurotic/Open-PS2-Loader.git` with `RIPTOPL_SHA=dfa28822...`, `RIPTOPL_EMBER_SHA=ebb62e1d...`, copying `POPS/{CHEATS.TXT,IGR_*.TM2,POPSTARTER.KELF,TROJAN_7.BIN}`)
  - `Launchstation/scripts/package_kit.py:54-75` (pins `RIPTOPL_EXAMPLE = "ship/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP"` and extracts `POPS/` + `EMBER/` from RiptOPL `ship/kit-externals.json`)
  - `POPSLoader/.github/workflows/ember-watch.yml:1-100` (`157` lines) vs `RiptOPL/.github/workflows/ember-watch.yml:1-100` (`222` lines)
- **Problem**: `RiptOPL` and `POPSLoader` commit `4.63 MB` of overlapping POPS/Ember/BDMAssault binaries, while `POPSLoader` and `Launchstation` both scrape assets from RiptOPL's checked-in `ship/Example/` bundle or the legacy `Open-PS2-Loader.git` fork and run parallel `ember-watch.yml` polling jobs.
- **Fix**: Before deleting `RiptOPL/ship/Example/` (`RIPTOPL-002`), update `Launchstation/scripts/package_kit.py` and `POPSLoader/tools/build_release_kit.sh` to fetch upstream `POPS`/Ember release assets from one pinned tag or CI artifact URL (dropping the stale `Open-PS2-Loader.git` URL), and keep `ember-watch.yml` in one owning repo.
- **Benefit**: Eliminates `4,629,038` B of cross-repo binary overlap, breaks brittle `ship/Example/` pin coupling, and retires one redundant CI watcher workflow (`~157` lines).
- **Effort**: M. **Risk**: Med. **Confidence**: High (READ).

### CROSS-002: Forked PS2 IOP hardware, storage, and IP driver trees duplicated across `Launchstation`, `RiptOPL`, and `POPSLoader`
- **Category**: 2 (Duplication), 7 (Build/CI/repo clutter)
- **Location(s)**:
  - `Launchstation/iop/` vs `RiptOPL/modules/`: `58` byte-identical file groups (`366,741` B exact duplicate waste across `8.43 MB` / `951` files), spanning `usbd-ra` vs `usbd`, `usbmass_bd`, `mx4sio_bd`, `mmceman` (which itself duplicates `ioplib.{c,h}` in both `mmceman` and `mx4sio_bd` across both repos), `pccf`, `ps2ips`, `ata_bd`/`atad`, `ps2hdd_osd`/`apa`, and `ee_libs/tcpips`
  - `POPSLoader/iop/ata_bd_fast` (already flagged for local deletion in `POPSLOADER-022`)
- **Problem**: Multiple repos carry full forked copies of nearly identical IOP storage, MMCE, ATA, USB, and network drivers rather than consuming one pinned `ps2build` toolchain package or upstream source tag.
- **Fix**: Consume unmodified stock IOP IRXs (`ata_bd`, `ps2hdd`, `mx4sio_bd`, `usbmass_bd`, `ps2ips`) directly from the pinned `ps2build` SDK sysroot during builds instead of vendoring copies in each repo, and maintain custom forks (`usbd-ra`, `mmceman`) in one canonical repo/package fetched in CI.
- **Benefit**: Eliminates `366,741` B of exact duplicate source bytes (`~8 MB` of redundant forked trees across checkouts) and prevents driver patch drift.
- **Effort**: L. **Risk**: Med. **Confidence**: High (READ hashes and directory trees; inner files audited in `CROSS-015` and `CROSS-017`).

### CROSS-003: Forked SMB1 / SMB2 / NFSv4 IOP drivers and `NTLM_Password_Hash` drift across three repos
- **Category**: 2 (Duplication), 6 (Bugs and security)
- **Location(s)**:
  - `Simple-Media-System/iop/smbman-sms/src/auth.c:14,52-56` (`NTLM_Password_Hash`)
  - `Launchstation/iop/smbman/src/auth.c:57-61`, `Launchstation/iop/smb2man/`, `Launchstation/iop/nfsman/nfsman.c:1-100` (`1,388` lines; `97.0%` similar to `RiptOPL`)
  - `RiptOPL/modules/network/smbman-ra/src/auth.c:57-61`, `RiptOPL/modules/network/smb2man/`, `RiptOPL/modules/network/nfsman/nfsman.c:1-100` (`1,407` lines; `unfs4.c` `97.3%` similar)
- **Problem**: Three repos independently maintain forked `smbman`, `smb2man`, and `nfsman` IOP trees (`37` identical groups = `197,161` B waste across `1.08 MB`), and bug fixes drift: `Launchstation` and `RiptOPL` clamp `pass_len > 255` in `NTLM_Password_Hash` (`auth.c:57-61`), whereas `Simple-Media-System/iop/smbman-sms/src/auth.c:14,52-56` still loops against `strlen((const char *)password)` every iteration writing `passwd_buf[512]` out of bounds on passwords `> 256` bytes.
- **Fix**: Immediately stop at `i < 256 && password[i] != '\0'` in `Simple-Media-System/iop/smbman-sms/src/auth.c:52-56` (`O(N^2)` `strlen` removal + IOP BSS overflow fix), then converge active SMB1/SMB2/NFSv4 IOP trees on one maintained `ps2build` source/artifact instead of editing three forks.
- **Justification**: Bounding `i < 256` adds one loop guard to stop IOP BSS corruption on long passwords; converging the three driver forks removes `~1 MB` of duplicated code.
- **Benefit**: Fixes a live IOP BSS overflow + `O(N^2)` `strlen` in `Simple-Media-System` and eliminates `197,161` B of exact duplicates (`1.08 MB` forked trees).
- **Effort**: S (for `auth.c` clamp), L (for full convergence). **Risk**: Low (clamp), Med (convergence). **Confidence**: High (READ).

### CROSS-004: Duplicated `ds34bt`/`ds34usb`/`pademu` controller drivers across four repos and 4-repo `SifCallRpc` stale-buffer bug
- **Category**: 2 (Duplication), 6 (Bugs and security)
- **Location(s)**:
  - `ds34bt_get_data`: `Launchstation/iop/ds34bt/ee/libds34bt.c:128-132`, `POPSLoader/modules/ds34bt/ee/libds34bt.c:128-132`, `RiptOPL/modules/ds34bt/ee/libds34bt.c:136-140`, `Simple-Media-System/src/libds34bt.c:137-141`
  - `ds34usb_get_bdaddr` & `ds34usb_get_data`: `Launchstation/iop/ds34usb/ee/libds4usb.c` (`Launchstation/iop/ds34usb/ee/libds34usb.c:75-82,132-136`), `POPSLoader/modules/ds34usb/ee/libds34usb.c:75-82,135-139`, `RiptOPL/modules/ds34usb/ee/libds34usb.c:83-90,140-144`, `Simple-Media-System/src/libds34usb.c:84-91,141-145`
  - Shared driver trees (`13` identical groups = `38,590` B waste; `~381 KB` total across the 4 PS2 repos; unused `POPSLoader/modules/pademu/` flagged in `POPSLOADER-022`)
- **Problem**: All four PS2 repos copy the same `ds34bt`/`ds34usb` EE+IOP source trees, including an identical RPC bug in every copy: `ds34bt_get_data`, `ds34usb_get_data`, and `ds34usb_get_bdaddr` unconditionally copy `rpcbuf` into caller buffers (and `ds34usb_get_bdaddr` masks `ret &= rpcbuf[0]`) even when `SifCallRpc(...) != 0`.
- **Fix**: Fix all four copies now by returning `0` on `SifCallRpc` failure before copying `rpcbuf`. Longer term, package one `ds34bt`/`ds34usb` build via `ps2build` (after trimming dead wrappers as in `SMS-048`) so controller fixes land once.
- **Justification**: Guarding `!ret` adds `~1-2` lines per function to prevent stale-DMA/uninitialized controller state across all four ELFs; packaging via `ps2build` removes three duplicated driver trees.
- **Benefit**: Fixes stale controller/MAC reads on failed IOP RPCs across all 4 ELFs and removes `38,590` B exact duplicates (`~280+ KB` forked source).
- **Effort**: S (RPC fix), M (consolidation). **Risk**: Low (RPC fix), Med (consolidation). **Confidence**: High (READ).

### CROSS-005: Forked UDPFS IOP trees, duplicate precompiled `.irx` binaries, and unported `SMSUdpfs` safety fixes
- **Category**: 2 (Duplication), 6 (Bugs and security), 7 (Build/CI/repo clutter)
- **Location(s)**:
  - Precompiled identical binaries (`24,739` B per extra copy): `Launchstation/iop/__precompiled/{udpfs_ioman,udpfs_smap,udpfs_ministack}.irx` == `POPSLoader/iop/embed/{udpfs_ioman,udpfs_net_smap,udpfs_ministack}.irx` == `RiptOPL/ship/Example/.../neutrino/modules/{udpfs_ioman,smap,ministack}.irx`
  - Unported fixes: `Simple-Media-System/iop/SMSUdpfs/udpfs/src/udpfs_core.c:91-98,132-133` and `udprdma.c:79,88-99` vs `RiptOPL/modules/network/udpfs_shared/src/udpfs_core.c:91,117` and `udprdma.c:43-80`
  - Total across `Launchstation`, `POPSLoader`, `RiptOPL`, `Simple-Media-System`: `22` identical groups (`106,310` B waste across `452,698` B)
- **Problem**: `Simple-Media-System` patched three real IOP bugs in `SMSUdpfs` (`result = {0}` zero-init in `udpfs_core.c:98`, `if (result.result > ret) return ret;` clamp at `132-133`, and `rx_mutex` serializing `_ist` vs ioman teardown/reset in `udprdma.c:79,88-99`), while `RiptOPL/modules/network/udpfs_shared/` still lacks all three fixes and `Launchstation`/`POPSLoader`/`RiptOPL` ship frozen older precompiled `udpfs_*.irx` binaries.
- **Fix**: Port the three `SMSUdpfs` safety fixes to `RiptOPL/modules/network/udpfs_shared/` now, rebuild one canonical set of `udpfs_*`/`ministack`/`smap` IRXs in a single upstream artifact, and drop redundant precompiled `.irx` copies (`Launchstation/iop/__precompiled/` where built from source or `ps2build`).
- **Justification**: Zero-init + `ret` clamp + existing mutex guard add `<15` lines to fix IOP memory-overread, stack-leak, and teardown race bugs on network I/O.
- **Benefit**: Fixes 3 IOP UDPFS bugs in `RiptOPL` and eliminates `106,310` B exact duplicate files (`22` groups) across 4 repos.
- **Effort**: M. **Risk**: Med. **Confidence**: High (READ).

### CROSS-006: Duplicated `ps2build` SDK installer, weekly watch script, GitHub workflow, and tests (`Launchstation` & `RiptOPL`)
- **Category**: 2 (Duplication), 7 (Build/CI/repo clutter)
- **Location(s)**:
  - `Launchstation/scripts/ps2build_sdk.sh:1-100` (`459` lines) vs `RiptOPL/tools/ps2build_sdk.sh:1-100` (`459` lines, `99.6%` identical; differs only in `USER_AGENT` lines `70-71`)
  - `Launchstation/.github/scripts/ps2build_sdk_watch.py:1-100` (`452` lines) vs `RiptOPL/.github/scripts/ps2build_sdk_watch.py:1-100` (`452` lines, `98.9%` identical; differs only in 5 constants at lines `40-44` + test defaults)
  - `Launchstation/tests/test_ps2build_sdk_watch.py` (`567` lines) vs `RiptOPL/.github/scripts/test_ps2build_sdk_watch.py` (`596` lines, `92.7%` similar)
  - `.github/workflows/ps2build-sdk-watch.yml` (`Launchstation` `245` lines vs `RiptOPL` `279` lines) and twin `neutrino-watch.yml`
- **Problem**: Both repos maintain copy-pasted copies of the `ps2build` SDK installer, weekly SDK monitor, tests, and workflow YAML, causing identical maintenance churn and Windows test-portability fixes (`test_ps2build_sdk_watch`) to drift.
- **Fix**: Host `ps2build_sdk.sh` and the watch helper once inside `ps2build` (or parameterize one reusable workflow) and delete the repo-local clones.
- **Benefit**: Deletes `~1,800+` duplicated shell, Python, and YAML lines across the two repos.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### CROSS-007: Four bespoke Python `.psu`/SAS packagers and duplicated desktop `.url` shortcuts
- **Category**: 2 (Duplication), 7 (Build/CI/repo clutter)
- **Location(s)**:
  - `RiptOPL/.github/scripts/package_release_app.py:35-100` (`PSU_ENTRY = struct.Struct("<HHI8sII8sI28s448s")`, `0x8027`/`0x8017`, `1024`-B clusters)
  - `Launchstation/scripts/package_apps.py:1-100`, `POPSLoader/tools/package_psu.py:1-100`, `Simple-Media-System/tools/package_sas.py:1-100`
  - `POPSLoader/tools/build_release_kit.sh:80-84` (compiles C++ `third_party/PSUManager` just to verify `package_psu.py` output)
  - Duplicated `.url` shortcuts: `Launchstation/ship/shortcuts/*.url` == `RiptOPL/tools/pc/*.url` == `RiptOPL/ship/Example/.../*.url` (`4` URL groups x3 copies)
- **Problem**: Four repos implement independent 80-to-150-line `.psu`/SAS packers around identical structs and `1024`-B cluster rules (plus `PSUManager` verification builds in `POPSLoader`), and two repos store `3` copies of identical `.url` shortcuts.
- **Fix**: Replace the four copies and `PSUManager` verification compile with one parameterized single-file packager script fetched in CI, and keep `.url` files in one release-packaging location (or drop redundant shortcut files).
- **Benefit**: Removes `~300` lines of redundant packager code, skips C++ `PSUManager` builds in `POPSLoader`, and deletes `8` redundant `.url` copies.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### CROSS-008: Duplicated embedded child ELF loaders and PS2 mbedTLS / MC-wake self-update shims
- **Category**: 2 (Duplication), 3 (Overengineering), 6 (Bugs and security)
- **Location(s)**:
  - Child ELF loaders: `Launchstation/loader/loader.c:1-200` (`446` lines), `RiptOPL/elfldr/loader.c:1-200` (`475` lines), `POPSLoader/src/elf_loader/src/loader/src/loader.c:1-100` (`442` lines), `Simple-Media-System/utils/Loader/loader.c:1-49`
  - PS2 mbedTLS glue: `Launchstation/src/cloud_http.c:101-200` vs `RiptOPL/src/sources/ratls_ps2.cpp:1-200` (`mbedtls_ms_time()`, `mbedtls_hardware_poll()`, non-blocking BIO loops)
  - MC-wake ELF updater flow: `Launchstation/src/self_update.c:1-100,190-543` vs `RiptOPL/src/ui/selfupdate.cpp:260-355` (`mcGetInfo` + `Rename`/`mcSetFileInfo`)
- **Problem**: Three repos carry forked `loader.c` copies that already diverged on bug fixes (`Launchstation:162-168` added LLVM `pthread_setcancelstate`, and `Launchstation`/`RiptOPL` carry `LINKER_ONLY` stubs absent from `POPSLoader`), while `Launchstation` and `RiptOPL` maintain near-identical PS2 mbedTLS entropy/BIO shims and MC-wake self-updaters.
- **Fix**: Consume the upstream PS2SDK `elf-loader` (`loader.elf`) package rather than maintaining three forked `loader.c` copies (keep `Simple-Media-System`'s minimal `49`-line `Loader/loader.c` standalone), and share one small PS2 `mbedtls_hardware_poll`/BIO helper via `ps2build` if both TLS callers stay active.
- **Justification**: Replacing three diverged `loader.c` forks with upstream `elf-loader` and one shared TLS entropy snippet cuts `~1,000+` duplicated lines while landing the missing `pthread_setcancelstate` fix cleanly.
- **Benefit**: Eliminates `~1,000+` duplicated EE loader lines and prevents missing thread-cancellation fixes (`pthread_setcancelstate`) in `POPSLoader`/`RiptOPL`.
- **Effort**: M. **Risk**: Med. **Confidence**: High (READ).

### CROSS-009: Duplicated controller pad PNG icons across `Launchstation`, `POPSLoader`, and `RiptOPL`
- **Category**: 2 (Duplication), 7 (Build/CI/repo clutter)
- **Location(s)**:
  - `Launchstation/res/icons/{L1,L3,R1,select,cross,circle,triangle,square,start,down,right,R2,up,left,L2,R3}.png` (all `16` unreferenced in `Launchstation`; local deletion tracked in `LAUNCHSTATION-008`)
  - `POPSLoader/bin/POPSLDR/IMG/` (`10` unused buttons `L1..R3,up..right` in `POPSLOADER-011`; `6` active icons embedded via `Makefile`/`embed_assets.cpp`)
  - `RiptOPL/gfx/{L1,L3,R1,select}.png` (`16` identical groups totaling `33,034` B duplicate waste)
- **Problem**: Identical controller button PNGs are checked into three repos (`16` dead copies in `Launchstation`, `10` dead copies in `POPSLoader`, and active icons overlapping `POPSLoader` and `RiptOPL`).
- **Fix**: Delete the dead copies in `Launchstation` (`LAUNCHSTATION-008`) and `POPSLoader` (`POPSLOADER-011`), keeping only active icons in one shared art source if release kits bundle them.
- **Benefit**: Cuts `33,034` B of cross-repo PNG duplication (`16` groups).
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### CROSS-010: RetroAchievements `xerabora` / `rcheevos` files duplicated between `PS2-Servers` and `RiptOPL`
- **Category**: 7 (Build/CI/repo clutter), 2 (Duplication)
- **Location(s)**:
  - `PS2-Servers/vendor/retroachievements/xerabora/protocol/ra_watch.h` == `RiptOPL/.github/scripts/fixtures/xerabora-alpha16/ra_watch.h` (`6,670` B)
  - `PS2-Servers/vendor/retroachievements/xerabora/client/src/snapshot.c` == `RiptOPL/.github/scripts/fixtures/xerabora-alpha16/snapshot.c` (`5,732` B)
  - `PS2-Servers/vendor/retroachievements/rcheevos/src/rhash/md5.h` == `RiptOPL/include/md5.h` (`3,483` B)
  - `PS2-Servers/vendor/retroachievements/xerabora/protocol/ra_snap.h` == `RiptOPL/.github/scripts/fixtures/xerabora-alpha16/ra_snap.h` (`3,206` B)
  - `PS2-Servers/vendor/retroachievements/xerabora/client/LICENSE` == `RiptOPL/.github/scripts/fixtures/xerabora-alpha16/LICENSE` (`1,099` B)
- **Problem**: Five identical files (`20,190` B) live in both `PS2-Servers/vendor/retroachievements/` and `RiptOPL` (`fixtures/xerabora-alpha16/` and `include/md5.h`).
- **Fix**: Drop redundant vendored RA snapshot trees in `PS2-Servers` (`PS2SERVERS-002`/`013`) and keep only minimal contract definitions in `RiptOPL` (verified against one pinned upstream commit instead of multi-repo fixture mirrors).
- **Benefit**: Removes `20,190` B of duplicate files and prevents protocol header copies from drifting silently.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### CROSS-011: Identical `AGENTS.md` and `CLAUDE.md` policy files across four repos (`8` copies)
- **Category**: 7 (Build/CI/repo clutter)
- **Location(s)**: `Launchstation/{AGENTS.md,CLAUDE.md}`, `PS2-Servers/{AGENTS.md,CLAUDE.md}`, `RiptOPL/{AGENTS.md,CLAUDE.md}`, `Simple-Media-System/{AGENTS.md,CLAUDE.md}` (`1,269` B each, all `8` byte-identical)
- **Problem**: Four repos commit two identical copies each (`AGENTS.md` == `CLAUDE.md`) of the same `1,269` B policy file.
- **Fix**: Keep at most `AGENTS.md` in each repo (deleting `CLAUDE.md` or replacing it with a one-line pointer if tooling requires a filename).
- **Benefit**: Removes `8,883` B (`7` redundant `1,269` B copies) and eliminates multi-file policy sync edits.
- **Effort**: S. **Risk**: Low. **Confidence**: High (READ).

### CROSS-012: Shared `ds34bt`/`ds34usb`/`pademu` IOP driver bugs across `POPSLoader`, `Launchstation`, and `RiptOPL`
- **Category**: 6 (Bugs and security), 2 (Duplication)
- **Location(s)**:
  - `POPSLoader/modules/{ds34bt,ds34usb,pademu}/`
  - `Launchstation/iop/{ds34bt,ds34usb}/`
  - `RiptOPL/modules/{ds34bt,ds34usb,pademu}/`
- **Problem**: All three forked IOP `ds34bt`/`ds34usb`/`pademu` controller trees share identical driver defects: `CancelAlarm(..., NULL)` timer over-signaling, missing lower bound on `ret = -1 < MAX_PADS` allowing a `ds34pad[-1]` OOB read, unchecked `power_level[]` array indexing, and unsafe USB endpoint descriptor scans. (`POPSLoader/modules/pademu/` is also unreferenced locally; see `POPSLOADER-022`.)
- **Fix**: Guard `ret >= 0` before indexing `ds34pad[]`, bounds-check `power_level[]` and USB endpoint descriptor lengths/offsets, fix `CancelAlarm` timer handling, and converge onto one `ps2build` controller IRX package (`CROSS-004`).
- **Justification**: Bounds/index/alarm fixes prevent IOP crashes and timer races on Bluetooth/USB pad attach/disconnect while sharing one fixed driver across all three ELFs.
- **Benefit**: Eliminates `4` classes of IOP controller memory/timer bugs across `Launchstation`, `RiptOPL`, and `POPSLoader`.
- **Effort**: M. **Risk**: Med. **Confidence**: High (READ).

### CROSS-013: Shared `SMSTCPIP` lwIP `tcp_slowtmr` keepalive UAF, protocol/socket bugs, and dead `loopif` code (`Simple-Media-System` & `RiptOPL`)
- **Category**: 6 (Bugs and security), 1 (Dead code), 2 (Duplication)
- **Location(s)**:
  - `Simple-Media-System/iop/SMSTCPIP/` (`src/tcp.c:215,580-630`, `src/sockets.c`, `src/tcp_in.c`, `src/udp.c`, `src/icmp.c`, `src/api_lib.c`, `src/api_msg.c`, `src/etharp.c`, `src/ps2ip.c`, `src/loopif.c`, `include/lwip/loopif.h`)
  - `RiptOPL/modules/network/SMSTCPIP/` (`tcp.c:626-690`, `sockets.c`, `tcp_in.c`, `udp.c`, `icmp.c`, `api_lib.c`, `api_msg.c`, `etharp.c`, `ps2ip.c`, `loopif.c`, `include/lwip/loopif.h`)
- **Problem**: Both forked `SMSTCPIP` IOP stacks share an identical lwIP defect set: `tcp_slowtmr` keepalive use-after-free (`SMS:tcp.c:215,580-630`, `RiptOPL:tcp.c:626-690`), `err_to_errno`/`lwip_accept`/`*sockopt` bugs, `tcp_input` `hdrlen`/`pbuf_header`/OOSEQs bugs, `udp_send`, `icmp_*`, `api_lib.c`/`api_msg.c`, `etharp_query`, `ps2ip.c` `netif_name`, plus dead `loopif.{c,h}` and `tcpip_callback`. (SMS-only `ip_reass`/`get_socket`/`lwip_close`/`--aTimeout`/`MEMP_SYS_TIMEOUT` stay in `SMS-007`/`SMS-017`; RiptOPL-only `tcp_parseopt`/`snd_nxt`/`lwip_recvfrom`/`select` stay in `RIPTOPL-008`.)
- **Fix**: Fix `tcp_slowtmr` keepalive UAF (save next pointer / avoid dereferencing aborted `pcb`), patch the shared `sockets`/`tcp_in`/`udp`/`icmp`/`api`/`etharp`/`ps2ip` defects, delete dead `loopif.{c,h}` and unused `tcpip_callback`, and unify `SMSTCPIP` onto one maintained package.
- **Justification**: Fixes real IOP TCP use-after-free, socket/ARP/packet-header bugs while pruning dead loopback/callback code.
- **Benefit**: Eliminates IOP TCP UAF and shared lwIP protocol/socket bugs across both ELFs and deletes dead `loopif` code.
- **Effort**: M. **Risk**: Med. **Confidence**: High (READ).

### CROSS-014: Shared `smbman` IOP safety, concurrency, leak, and dead-code bugs (`Launchstation`, `RiptOPL`, `Simple-Media-System`)
- **Category**: 6 (Bugs and security), 1 (Dead code), 2 (Duplication)
- **Location(s)**:
  - `Launchstation/iop/smbman/`
  - `RiptOPL/modules/network/smbman-ra/`
  - `Simple-Media-System/iop/smbman-sms/` (`smbman.c`, `smb.c`, `poll.c`)
- **Problem**: Outside the `auth.c` clamp drift (`CROSS-003`), all three `smbman` forks share IOP defects across `prepare_path`, `strncpy`/`ServerIP` NUL-termination, unchecked `fh` file handles, `NetShareEnum`/`QueryPathInformation`/`Echo`, `LegacyOpenAndX` FID handling, `GetShareList` `UID`, `devctl`, `FileTimeToDate`, `init`/`deinit`/keepalive leaks & races, and `poll.c` `POLLNVAL` handling.
- **Fix**: Patch these shared `smbman` bounds/handle/teardown bugs once and converge the three IOP `smbman` copies onto a single package (`CROSS-003`).
- **Justification**: Bounds/handle/teardown checks prevent IOP file-handle corruption, path overflows, and disconnect races across all three console ELFs.
- **Benefit**: Fixes `10+` shared IOP SMB1 reliability and safety bugs once instead of three times.
- **Effort**: M. **Risk**: Low. **Confidence**: High (READ).

### CROSS-015: Shared IOP storage driver bugs and SIO2/MMCE duplication (`Launchstation` & `RiptOPL`)
- **Category**: 6 (Bugs and security), 2 (Duplication), 1 (Dead code)
- **Location(s)**:
  - `Launchstation/iop/{usbd-ra,usbmass_bd,mx4sio_bd,mmceman,sio2man_hook,ps2hdd_osd}/`
  - `RiptOPL/modules/{usbd,usbmass_bd,mx4sio_bd,mmceman,sio2man_hook,apa}/`
- **Problem**: Beyond file-level duplication (`CROSS-002`), both repos share common IOP storage driver bugs across `usbd-ra`/`usbd`, `usbmass_bd`, `mx4sio_bd`, `mmceman`+`sio2man_hook`, and `ps2hdd_osd`/`apa` (`apaOpen` UAF + `fioSema`), plus 5-file SIO2 duplication across `mmceman` and `mx4sio_bd` and dead `mmcedrv_config.h`.
- **Fix**: Fix `apaOpen` UAF/`fioSema` and shared USB/BDM/MMCE bugs once, delete dead `mmcedrv_config.h`, deduplicate the shared SIO2 files across `mmceman`/`mx4sio_bd`, and consume converged SDK packages (`CROSS-002`).
- **Justification**: Fixing `apaOpen` UAF/`fioSema` and driver defects avoids IOP filesystem corruption/locks while consolidating duplicated SIO2 files shrinks maintenance surface.
- **Benefit**: Resolves shared APA UAF/locking and USB/MMCE/MX4SIO driver bugs and removes 5-file SIO2 duplication per repo.
- **Effort**: M. **Risk**: Med. **Confidence**: High (READ).

### CROSS-016: Shared `udpfs` / `udprdma` / `ministack` / `udpfs_smap` IOP protocol/ISR bugs and `mprintf.h` duplication (`Launchstation`, `RiptOPL`, `Simple-Media-System`, `POPSLoader`)
- **Category**: 6 (Bugs and security), 2 (Duplication)
- **Location(s)**:
  - `Launchstation/iop/{udpfs*,udpfs_smap}/`
  - `RiptOPL/modules/network/{udpfs_shared,udpfs_smap}/`
  - `Simple-Media-System/iop/SMSUdpfs/` (and precompiled `udpfs_*.irx` in `POPSLoader/iop/embed/`)
- **Problem**: Outside the three SMS safety patches not yet ported (`CROSS-005`) and SMS-only `smap_fifo_read` odd-byte drop (`SMS-016`), the shared UDPFS codebase carries common IOP driver hazards across `udpfs_core`, `udpfs_ioman`, `udprdma` (`_ist` race), `ministack`, and `udpfs_smap` (`InitPHY`, `!SPD_REG16 &` bitwise/logical bug, `HandleRxIntr`, `CopyToFIFO`, and unbounded hardware wait loops), plus duplicated `mprintf.h` across `Launchstation` & `RiptOPL`.
- **Fix**: Fix the `!SPD_REG16 &` operator precedence, `InitPHY`, `HandleRxIntr`, `CopyToFIFO`, and `_ist` issues, bound hardware spin loops, share one `mprintf.h`, and distribute one rebuilt `udpfs` IRX set (`CROSS-005`).
- **Justification**: Prevents SMAP PHY/interrupt bugs and unbounded IOP hardware spins while ending multi-repo UDPFS fork drift.
- **Benefit**: Stabilizes UDPFS/SMAP packet TX/RX and teardown across all 4 console ELFs.
- **Effort**: M. **Risk**: Low. **Confidence**: High (READ).

### CROSS-017: Shared `ps2ips`, `smb2man`, `nfsman`, and `linkfile` IOP defects (`Launchstation` & `RiptOPL`)
- **Category**: 6 (Bugs and security), 7 (Build/CI/repo clutter)
- **Location(s)**:
  - `Launchstation/iop/{ps2ips,smb2man,nfsman}/`
  - `RiptOPL/modules/network/{ps2ips,smb2man,nfsman}/`
- **Problem**: Both repos share common RPC/bounds/teardown defects and redundant `linkfile` copies across their forked `ps2ips`, `smb2man`, and `nfsman` modules (`RiptOPL`-unpatched `ps2ips` `do_setsockopt` overflow/`do_gethostbyname` `NULL` and `smb2man` `SMB_DEVCTL_LOGON` teardown stay tracked in `RIPTOPL-007`).
- **Fix**: Apply shared `ps2ips`/`smb2man`/`nfsman` bounds and teardown fixes alongside converging `smb2man`/`nfsman` (`CROSS-003`) and switching `ps2ips` to SDK sysroot (`CROSS-002`).
- **Justification**: Closes shared IOP RPC/network teardown bugs while converging the duplicated IOP forks.
- **Benefit**: Eliminates shared IOP network RPC/driver defects and `linkfile` clutter across `Launchstation` and `RiptOPL`.
- **Effort**: M. **Risk**: Low. **Confidence**: High (READ).

---

## 2. Top 25 Findings Across All Five Repositories

Ranked by combined impact on correctness/data-loss, real PS2 ELF size & EE/IOP RAM savings, UI/boot responsiveness, and major repo/CI bloat:

1. **PS2SERVERS-001** (Cat 6, S/Low): Edge WebUI JSON/form serialization breaks UDPFS config saves, truncates fractional `tx_delay_ms`, and resets `session_summary`.
2. **POPSLOADER-014** (Cat 6/5, S/Low): `System.rename` self-truncation data-loss bug when `oldName == newName`, slow bytewise `BUFSIZ` copy, and ignored `remove()` errors.
3. **PS2SERVERS-005** (Cat 6, S/Low): Five SMB2 protocol/security bugs across Windows and POSIX hosts (directory symlink escape, stale session validation, open-handle rename failure, signed EOF unpack).
4. **PS2SERVERS-006** (Cat 6/5, S/Low): Edge Go SMB handler reopens file per write chunk (TOCTOU symlink race), skips directory-listing containment, and mishandles short-write/size accounting.
5. **CROSS-003** (Cat 2/6, S/Low for fix): Unbounded UTF-16LE password write and `O(N^2)` `strlen` in `Simple-Media-System/iop/smbman-sms` `NTLM_Password_Hash` (`Launchstation`/`RiptOPL` already clamp `pass_len > 255`), plus `1.08 MB` forked SMB/NFS trees.
6. **SMS-001** (Cat 4/6/1, M/Low): `1.15 MB` (`1,204,224 B`) stack allocation in `_find_signature`, `3` `CDDA` `NULL` dereferences, `2` leaks, and `2` dead `CDDA_Get*Picture` exports.
7. **LAUNCHSTATION-023** (Cat 6/4, M/Med): Deep recursive `copy()` stack frames on the `128 KB` EE thread stack risk stack overflow without CI stack-budget bounds.
8. **RIPTOPL-003** (Cat 4, S/Low): Permanent `768 KB` (`786,432 B`) static `.bss` `bgmBuffer` allocated in EE RAM even when BGM is disabled.
9. **LAUNCHSTATION-001** (Cat 2/4, M/Med): `17` IOP IRX drivers embedded twice (inside `wle_igr` and `wLaunchELF`), bloating ELF size by `~350-450 KB` uncompressed (`INFERRED`).
10. **SMS-002** (Cat 4, S/Low): `180 KB` (`184,320 B`) unused static `.bss` (`s_Samples`) and full-size zeroing in AC3 decoder.
11. **SMS-003** (Cat 4/6, M/Med): `162.0 KiB` (`165,892 B`) permanent static WMA `.bss` (`s_Ctx`) plus OOB index, infinite loop, and unchecked `malloc`/`MDCT` bugs.
12. **SMS-004** (Cat 6, S/Low): `SMS_Utils.S` `memmove` backward byte-tail loop (`small_byte_rmemcpy`) increments forward instead of backward and corrupts memory.
13. **RIPTOPL-005** (Cat 6, S/Low): `ee_core` `SyncDCache((void *)opcode, ...)` passes integer `0x10000025` instead of `&opcode`, risking missed instruction-cache invalidation during syscalls/patches.
14. **CROSS-004** (Cat 2/6, S/Low for fix): Four-repo `ds34bt`/`ds34usb` `SifCallRpc` stale `rpcbuf` copy bug (`ds34bt_get_data`, `ds34usb_get_data`, `ds34usb_get_bdaddr`), plus `~381 KB` of duplicated DS34 trees.
15. **PS2SERVERS-011** (Cat 6, S/Low): Live SSE newline/CR injection + DOM XSS in Edge/RA WebUIs, shared `threading.Event` wakeup race, and unauthenticated UDP reply redirection.
16. **LAUNCHSTATION-004** (Cat 4, S/Low): `~440 KB` pinned static EE `.bss` buffers in rare/on-demand utilities plus `2.56 MB` artwork cache ceiling.
17. **LAUNCHSTATION-007** (Cat 2/4, M/Med): `1.71 MB` of C font source (`585,728 B` pixel `.rodata`) plus classic `font_uLE.c`.
18. **POPSLOADER-002** (Cat 4/5, M/Low): All 7 non-English Lua localization tables (`~162 KB` minified / `172 KB` raw) compiled into EE RAM on every boot.
19. **POPSLOADER-001** (Cat 4/2, S/Low): Unaliased duplicate IRX blobs (`83,008 B` raw) and doubled 108-entry asset table linked into `POPSLOADER.ELF`.
20. **RIPTOPL-008** (Cat 6/1, M/Med): RiptOPL-only `SMSTCPIP` `tcp_parseopt` wrap infinite loop/OOB read, `snd_nxt` corruption, `lwip_recvfrom`/`select` bugs, and dead `udp_lookup`/stubs.
21. **RIPTOPL-009** (Cat 6/3, S/Low): `bdmfs_fatfs` `9` `NULL` `VolumeStr` crash, OOB `mount_info`, `GET_LBA` `NULL` `bd`/unaligned bug, `fs_dread` issues, and `11` redundant FatFs mutexes.
22. **RIPTOPL-012** (Cat 6, S/Low): `cdvdfsv`/`cdvdman` raw-sector `2048`-vs-`2328`/`2340 B` DMA overrun and `CDSC_IO_SEMA` `fno == 0` hazard.
23. **CROSS-005** (Cat 2/6/7, M/Med): `RiptOPL/modules/network/udpfs_shared/` and frozen precompiled `udpfs_*.irx` modules lack three `SMSUdpfs` safety fixes (`result` zero-init, `result.result > ret` clamp, `_ist`/ioman `rx_mutex`), plus `106,310 B` duplicate files.
24. **RIPTOPL-027** (Cat 6, S/Low): Windows packaging writes CRLF `ORBIT-RA.txt`, silently breaking RA-Neutrino runtime detection.
25. **POPSLOADER-003** (Cat 5/4, M/Med): Per-frame Lua table, `Color.new`, and closure allocations (`~60x/s`) in Settings and MainMenu loops causing UI GC hitches.

*(Honorable high-impact runners-up right behind #25: `SMS-005..011` memory/codec safety fixes, `RIPTOPL-001` `64.43 MB` `docs/`, `LAUNCHSTATION-006` `>17 MB` demo media & AI scratch, `POPSLOADER-010` `22.8 MB` `.research/`, `CROSS-001` `4.63 MB` POPS/BDMA binary overlap, `PS2SERVERS-008`/`009`/`002`/`003`, and `LAUNCHSTATION-003` ~`390+ KB` static PS1/MC `.bss` & `1 MB` dead double-buffer.)*

---

## 3. Quick Wins (`Risk: Low` and `Effort: S`)

Every item verified below has **exact** `Effort: S` and `Risk: Low` in its per-repo audit file (`151` single-repo items total plus `6` cross-repo items):

### RiptOPL (`32` S/Low items)
- **EE/ELF RAM & dead code**: `RIPTOPL-003` (`768 KB` `bgmBuffer`), `RIPTOPL-035` (`gColBlack` `guiShow()` + `hddPartitionMountableAt`), `RIPTOPL-042` (`12` unembedded `gfx/*.png` + `NULL` `textures.cpp`), `RIPTOPL-044` (`bd_defrag_write`/`bdm_fork`/dead drivers).
- **Correctness & IOP safety**: `RIPTOPL-005` (`SyncDCache(&opcode)`), `RIPTOPL-006` (`ee_core` `_strncmp` & `modmgr` leak), `RIPTOPL-007` (RiptOPL-unpatched `udprdma`/`ps2ips`/`smbman-ra`/`smb2man` bugs), `RIPTOPL-009` (`bdmfs_fatfs`), `RIPTOPL-011` (`bdm_disconnect_bd` deadlock), `RIPTOPL-012` (`cdvdfsv`/`cdvdman` raw-sector DMA), `RIPTOPL-014` (`cdvdman` `smb.c`/`smb2.c`), `RIPTOPL-015` (`BgmPlayer` ID `0`), `RIPTOPL-016` (`PadManager` multitap OOB), `RIPTOPL-017` (`TAR_KIND_ART` race), `RIPTOPL-018` (`readFileBuffer` blank-line double-free), `RIPTOPL-019` (`hddGetSpace`/`hddGetFileBlockInfo`), `RIPTOPL-020` (`IoQueue` sema leak), `RIPTOPL-022` (`usbmass_bd`/`isofs`/`usbd-ra`), `RIPTOPL-025` (`apemodpatch`/`f2techioppatch`), `RIPTOPL-027` (CRLF `ORBIT-RA.txt`), `RIPTOPL-028` (`Gui` bugs), `RIPTOPL-030` (`pccf_hw_start` stall), `RIPTOPL-032` (`smap-ingame`/UDPFS dup), `RIPTOPL-036`/`037` (`iso2opl`/`opl2iso` + `crc32()` OOB), `RIPTOPL-039`/`040`/`041` (`BdmSource`, `cheatman`/`OSDHistory`, unbounded HW loops).
- **Repo & CI**: `RIPTOPL-001` (`64.43 MB` `docs/` after updating `docs-sync`), `RIPTOPL-002` (`4.52 MB` `ship/Example` + `bdmassault` once `CROSS-001` fetchers update), `RIPTOPL-021` (`33` dup CI builds), `RIPTOPL-046` (PC `Makefile`/CI checks).

### Launchstation (`39` S/Low items)
- **EE RAM/assets & dead code**: `LAUNCHSTATION-002` *(partial S/Low: `src/mc_sha256.c`)*, `LAUNCHSTATION-003` (`1 MB` dead `filer_copy` buffer + `~390+ KB` PS1/MC `.bss`), `LAUNCHSTATION-004` (`~440 KB` utility `.bss` + artwork ceiling), `LAUNCHSTATION-005` (`~231.5 KB` non-concurrent `.bss`), `LAUNCHSTATION-008` (`462 KB` `bgm.ogg` + `16` PNGs), `LAUNCHSTATION-010` (`main_menu.c`/`dashDevicesScreen` + UI dup), `LAUNCHSTATION-034..036` (dead extractors/wrappers/`iop/mmceman`), `LAUNCHSTATION-038` (`dash_lib.c` `18 KB` stack alloc), `LAUNCHSTATION-049` (11 `#if 0` blocks + `~2 KB` `strtmp`).
- **Correctness, UI & IOP safety**: `LAUNCHSTATION-011..019` (RPC bounds, CNF parser, `dashModalKeyboard`, `make_icon`, `delete()`/`make_title_cfg`, `filer.c`, `loadFont`/`elf.c`, editor bounds/leaks), `LAUNCHSTATION-022`, `025`, `027..032` (`pc_game_receiver`, `smbd`, `hdl_info`, `ps2ftpd`, `xparam`, `ata_bd`, `edIoRun`, `mcSaveFromMcm`/`mc_card_export`), `LAUNCHSTATION-039..048` (`S_SMBD_PASS`, `gui_sort`, `fmodf`, UI/dup cleanup).
- **Repo & CI**: `LAUNCHSTATION-006` (`>17 MB` demo media & AI scratch), `LAUNCHSTATION-050` (shell/CI scripts).

### POPSLoader (`27` S/Low items)
- **EE RAM/ELF & dead code**: `POPSLOADER-001` (`83,008 B` dup IRXs + asset table), `POPSLOADER-006` (`ps2atad.o`), `POPSLOADER-007` (`ata_async_thread` `8 KB` stack), `POPSLOADER-008` (`Graphics.threadLoadImage` `4 KB` stack), `POPSLOADER-016`, `018`, `019`, `020`, `022`, `023`, `024`, `025`, `028` (hoist per-frame `Color.new`/wraps in 5 draw paths), `POPSLOADER-032` (footer legend + dead placeholder block).
- **Correctness & data safety**: `POPSLOADER-004` (BMP palette/stride), `POPSLOADER-012` (6 C bounds/fd checks), `POPSLOADER-013` (`System.listDirectory`), `POPSLOADER-014` (`System.rename`), `POPSLOADER-015` (timer sign + magic), `POPSLOADER-021` (`elf_loader`), `POPSLOADER-029` (Settings `PendingHideRebuild`), `POPSLOADER-030` (`RetroGemGameId` dirty check), `POPSLOADER-031` (`ApplyBdmaMode` + `ata` mask).
- **Repo & CI**: `POPSLOADER-009` (`347,956 B` dup `POPSTARTER/`), `POPSLOADER-011` (`527,408 B` unused images/docs), `POPSLOADER-026` (`PATHMAP.INI.example` LF pin), `POPSLOADER-027` (`33` stale branches & `19` tags).

### Simple-Media-System (`38` S/Low items)
- **EE RAM/assets & dead code**: `SMS-002` (`180 KB` AC3 `s_Samples`), `SMS-018` (`SMSSMB.IRX` + `UMS/USBD` under `#ifndef BDM` + unbuilt IOP trees), `SMS-019` (`377.6 KB` `s_iop_image.h`), `SMS-020` (`19,216 B` legacy IPU icons + `IPU_UnpackImage`), `SMS-045` (`g_ASCII[5416]` fix saves `5.4 KB`), `SMS-046` (`150+ KB` codec `.data` -> `.rodata` + `1,057 B` dedup), `SMS-047..051` (dead S/PDIF/AAC/DS34/GS/PAD/RC code, `4,566 B` dup IOP headers).
- **Correctness & IOP/EE safety**: `SMS-004` (`small_byte_rmemcpy`), `SMS-007` (`ip_reass`), `SMS-011` (`lq`/`sqc2` align + delay `nop`), `SMS-013` (display-list align + `m_pLastTag`), `SMS-016` (`smap_fifo_read` odd-byte), `SMS-017` (`SMSTCPIP` sockets/timeout/memp), `SMS-022` (S/PDIF overflow/truncation), `SMS-024`, `026..029`, `031..036`, `039..044` (`ASF`, `QPel`, `libsd` `core == 4`, `MP123`, `AC3`, `lzma2`, `MPEG4`, `DSP`, `DTS`, `GUIMenuSMS`, `IPU`, `MOV`, `AAC`, `JPEG`, `MPEG_PS`, `MSMPEG4`).
- **Repo & tooling**: `SMS-021` (`~2.06 MB` AI logs/`lng/`/`vu/`/IRXs), `SMS-053` (`docs-site` EOL + tests), `SMS-054`, `SMS-055`.

### PS2-Servers (`15` S/Low items)
- **Correctness, security & protocol parity**: `PS2SERVERS-001`, `005`, `006`, `011`, `012`, `016`, `017`, `020`, `021`.
- **Performance & repo cleanup**: `PS2SERVERS-008` (Edge UDPFS buffer reuse), `PS2SERVERS-013` (`~572 KB` dup banner + docs + 244 refs), `PS2SERVERS-015` (hoist `ctypes`), `PS2SERVERS-019`, `022`, `023`.

### Cross-Repo Quick Wins
- `CROSS-003` *(clamp slice: `Simple-Media-System/iop/smbman-sms/src/auth.c` `i < 256`)*, `CROSS-004` *(RPC guard slice across 4 repos)*, `CROSS-006`, `CROSS-007`, `CROSS-009`, `CROSS-010`, `CROSS-011`.

---

## 4. Suggested Order of Work

### Phase 1: Critical Correctness, Data-Loss & Protocol/Security Fixes (Do First)
Land small, zero-bloat correctness patches before any refactors or moves:
1. **PS2-Servers active bugs**: `PS2SERVERS-001`, `PS2SERVERS-005`, `PS2SERVERS-006`, `PS2SERVERS-011`, `PS2SERVERS-012`, `PS2SERVERS-016`, `PS2SERVERS-017`.
2. **PS2 data-loss & critical EE/IOP memory-safety bugs**:
   - `POPSLoader`: `POPSLOADER-014` (`System.rename`), `POPSLOADER-004`, `POPSLOADER-012`, `POPSLOADER-013`, `POPSLOADER-015`, `POPSLOADER-021`, `POPSLOADER-029`, `POPSLOADER-030`, `POPSLOADER-031`.
   - `RiptOPL`: `RIPTOPL-005` (`SyncDCache(&opcode)`), `RIPTOPL-006`, `RIPTOPL-007`, `RIPTOPL-008`, `RIPTOPL-009`, `RIPTOPL-010`, `RIPTOPL-011`, `RIPTOPL-012`, `RIPTOPL-014`, `RIPTOPL-027` (`ORBIT-RA.txt` CRLF), `RIPTOPL-037` (`crc32()` OOB).
   - `Simple-Media-System`: `SMS-004` (`small_byte_rmemcpy`), `SMS-005`, `SMS-006`, `SMS-007` (`ip_reass`), `SMS-008`, `SMS-009`, `SMS-010`, `SMS-011`, `SMS-012`, `SMS-013`, `SMS-016`, `SMS-017`, `SMS-022..036`.
   - `Launchstation`: `LAUNCHSTATION-011..019`, `LAUNCHSTATION-022`, `LAUNCHSTATION-023` (recursive `copy()`), `LAUNCHSTATION-025..032`.
3. **Cross-repo RPC & network driver safety fixes**: `CROSS-003` (`auth.c` `i < 256` clamp), `CROSS-004` (`SifCallRpc` guard across all 4 repos), `CROSS-005` (port `SMSUdpfs` safety fixes to `RiptOPL`), `CROSS-012`, `CROSS-013`, `CROSS-014`, `CROSS-016`.

### Phase 2: Quick ELF/RAM Savings, Repo Pruning & CI Cleanup (High ROI, Low Risk)
Clear static EE RAM waste, dead embedded IRXs/code, and repo/CI bloat:
1. **Update downstream kit pins first (`CROSS-001`)**: Switch `Launchstation/scripts/package_kit.py` and `POPSLoader/tools/build_release_kit.sh` away from `RiptOPL/ship/Example/` and the legacy `Open-PS2-Loader.git` URL before deleting `ship/Example/`.
2. **EE `.bss`/`.data`/stack/ELF trims**: `RIPTOPL-003` (`768 KB` `bgmBuffer`), `RIPTOPL-004` (`212 KB` stacks + `~120 KB` `.bss`), `LAUNCHSTATION-003` (`1 MB` + `~390+ KB`), `LAUNCHSTATION-004` (`~440 KB`), `LAUNCHSTATION-005` (`~231.5 KB`), `SMS-001` (`1.15 MB` stack), `SMS-002` (`180 KB` `s_Samples`), `SMS-003` (`162 KiB` WMA `.bss`), `SMS-014`/`015` (codec stacks), `SMS-018`/`019`/`020`/`045`/`046` (`~57 KB` `.data` + `.rodata` + `377.6 KB` `s_iop_image.h`), `POPSLOADER-001`/`006`/`007`/`008` (`83 KB` dup IRXs + `12 KB` stacks + `ps2atad.o`).
3. **Dead code, asset & CI/repo pruning**: `RIPTOPL-001`, `002`, `021`, `031`, `042`, `044`, `046`; `LAUNCHSTATION-006`, `008`, `010`, `034..036`, `038`, `049`, `050`; `POPSLOADER-009`, `010`, `011`, `016..020`, `022..027`, `032`; `SMS-021`, `047..051`, `053..055`; `PS2SERVERS-013`, `019..023`; `CROSS-006`, `007`, `009`, `010`, `011`.

### Phase 3: Performance, UI Responsiveness & Medium Refactors
Requires runtime testing across PS2 UI loops, EE threads, and hardware timers:
1. **PS2 UI & boot responsiveness**: `POPSLOADER-002` (single-language table load), `POPSLOADER-003` & `028` (hoist per-frame tables/`Color.new`/closures), `POPSLOADER-005` (`EnsureUsbMass` 1s sleep), `RIPTOPL-029` (single ISO9660/DVD-DL/ZSO probe), `RIPTOPL-030` (`pccf_hw_start` stall), `RIPTOPL-034`/`035` (`FavSource`/`guiShow`), `LAUNCHSTATION-024`, `LAUNCHSTATION-033`, `LAUNCHSTATION-037` (`pad.c` vs `pad_ds34.c`), `LAUNCHSTATION-040` (`gui_sort`).
2. **EE font/driver trims & C cleanup**: `LAUNCHSTATION-001` (stop double-embedding 17 IRXs), `LAUNCHSTATION-007` (font `.rodata` / `font_uLE.c`), `LAUNCHSTATION-009` (drop `v1.0` IP/DEV9 & dup UDPFS), `SMS-037`/`038`/`052`, `RIPTOPL-023`/`024`/`026`/`033`/`038`/`043`/`045`.
3. **PS2-Servers speed & thread responsiveness**: `PS2SERVERS-008`, `PS2SERVERS-009`, `PS2SERVERS-010`, `PS2SERVERS-015`, `PS2SERVERS-004`, `PS2SERVERS-014`, `PS2SERVERS-007`, `PS2SERVERS-018`.

### Phase 4: Major Architectural & Cross-Repo Consolidations
Schedule only after Phases 1 to 3 stabilize builds and tests:
1. **PS2-Servers desktop consolidation**: `PS2SERVERS-002` (retire redundant RetroAchievements runtimes) and `PS2SERVERS-003` (unify duplicated game-library SQLite/parsers).
2. **Launchstation legacy UI & SMB convergence**: `LAUNCHSTATION-010` (retire duplicate classic UI screens) and `LAUNCHSTATION-002` (converge 3 SMB codebases).
3. **Single-source PS2 IOP & SDK packaging**: Complete `CROSS-001`, `CROSS-002`, `CROSS-003`, `CROSS-004`, `CROSS-005`, `CROSS-008`, `CROSS-012`, `CROSS-013`, `CROSS-014`, `CROSS-015`, `CROSS-016`, and `CROSS-017` so shared IOP IRXs, `loader.elf`, and TLS/entropy glue build cleanly from one upstream/package source rather than per-repo forks.
