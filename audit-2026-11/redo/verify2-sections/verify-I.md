# Verification Batch I — RE-SERV-191 … RE-SERV-216 (Redo-PS2Servers)

- **Pin confirmation:** `git -C ~/workspace/audit-clones-2026-11-13/PS2-Servers rev-parse HEAD` → `c5f021c4d38698860f56b03498adc261dbb8d8dd` — matches the assigned pin exactly. All reading was in that clone (read-only); executions ran in `/tmp/vI` copies only.
- **Method:** refute-first — every cited file/symbol/asset grepped repo-wide; measurement claims re-measured; zero-caller claims grepped across code + tests + scripts; mechanism claims re-derived from source, hunting for defeating guards/caches first.
- **Environment note:** sandbox blocks UDP — the Go `internal/udpbd` package tests run in a `/tmp` copy fail with UDP loopback `i/o timeout`s. That is BLOCKED-ENV for those tests only and is not evidence for or against any finding here.

---

### RE-SERV-191 — VERIFIED
- **Citations:** All exist. `nfs4_server/nfs4_server.py:728-733` `_op_putfh` does `s.cfh = self.handles.lookup(fh)[1]` (keeps comps, discards element [0], the number); `_Compound` at :336-343 has `__slots__ = ("cfh", "sfh", "conn")` storing comps only; `_op_read` :761-766 and `_op_readdir` :825-835 both re-derive via `self.handles.handle(comps)`.
- **Mechanism:** `_Handles.handle` (:276-285) takes `self.lock` and, on a miss, inserts into both `self.numbers` and `self.paths` — i.e. a locked, potentially mutating lookup-or-insert on every READ/READDIR, exactly as claimed. No defeating guard: neither op checks a stored number first, because none is stored. `lookup()` already returns `(number, comps)`, so the number was in hand at PUTFH.
- **Execution:** n/a (code re-derivation; mechanism is deterministic from source).
- **Fix:** Sound and LESS-shaped: carry `(number, comps)` in the compound state; `handle()` then runs only in GETFH. No new subsystem.

### RE-SERV-192 — VERIFIED
- **Citations:** `native/ps2servers-edge/internal/udpbd/server.go` — `seen map[string]bool` declared :120, created :151; the only writes/reads in the whole file are :206 (`peers := len(s.seen)`), :350-351 (`first := !s.seen[...]`; insert). Repo grep for `seen` in the package returns no delete, no expiry, no reset.
- **Mechanism:** `statusReply` sets `Sessions: uint16(peers)` from `len(s.seen)` (:220) — a monotonically increasing ever-seen count, not a live-session count. Insertion is driven by any UDP INFO sender's source address, unauthenticated. Both limbs (unbounded growth + false status semantics) hold.
- **Execution:** n/a (the package's UDP tests are BLOCKED-ENV in this sandbox; the claim is a source census, which I reproduced).
- **Fix:** Sound: remove `seen` from `statusReply`; bound/expire it if kept for the first-contact log line.

### RE-SERV-193 — VERIFIED
- **Citations:** Go — `operations.go:282` (`prepareDirectory` → `compression.ListVirtualCD`), called from directory OPEN at :336; `resolveVirtualCD` :234-251 → `FindVirtualCD`, called at :344, :383, :781; `ListVirtualCD` `chd_cuebin.go:406-475` calls `readCDTrackTable` (:460) + `table.layout()` per `.chd`; `FindVirtualCD` :476-539 calls `readCDTrackTable` (:520). Python — `udpfs_server.py:1745-1790` (`_prepare_directory_entries` → `_get_compressed_stat` per compressed entry, :1760), `_get_compressed_stat` :1388-1405 → `get_compressed_info` :390-479 (opens the file; CD CHDs fall through to `exact_cd_iso_size`), `compressed_iso/chd.py:210-240` (`exact_cd_iso_size` opens again and walks `read_track_table`).
- **Mechanism:** Hunted for a track-table cache first: the Go compression package's only caches are decompressed-block/hunk caches (`image.go` block cache; `chd_cuebin_enabled.go` hunk cache) — no parsed-track-table/layout cache anywhere. Python side: no memoisation of `get_compressed_info` (grep for cache/memo near it returns only the unrelated decompression-block cache). Both implementations re-parse per listing/OPEN/GETSTAT as claimed.
- **Execution:** n/a (call-graph re-derivation in both languages; no timing claimed by me).
- **Fix:** Sound; the proposed invalidation key (`os.SameFile`+size+modtime in Go, `(path, st_mtime_ns, st_size)` in Python) already exists in the respective codebases. One small cache justified by a measured-by-inspection hot path — passes LESS-NOT-MORE.

### RE-SERV-194 — VERIFIED
- **Citations:** `native/ps2servers-edge/internal/smb/handlers.go` — `entries` is seeded with `"."` and `".."` (two appends before the names loop), then `eos := uint16(0); if len(entries) == 1 { eos = 1 }`.
- **Mechanism:** `len(entries) >= 2` by construction on every path reaching the check (early returns cover resolve/stat/readdir failures). The branch is unreachable and `eos` is always 0 on FIND_FIRST2, including for an empty directory. No defeating guard exists — the seeding is unconditional.
- **Execution:** n/a.
- **Fix:** Sound: delete the dead branch; derive EndOfSearch from the cursor/last-entry condition as `findNext2` does.

### RE-SERV-195 — VERIFIED
- **Citations:** `image.go:138`: `func Open(path string) (*Image, error) { return OpenCached(path, DefaultCacheBlocks) }` — a one-line wrapper, as cited.
- **Mechanism (zero-caller census):** Whole-module grep: every non-test reference to compression `Open(` is absent; production open paths are `compression.OpenCached` and `compression.OpenRaw`, both from `internal/udpfs/blockdev.go:396,402`. All `Open(` hits in the compression package outside `image.go` are in `*_test.go` files (`image_test.go`, `sizeof_test.go`, `chd_enabled_test.go`, `chd_disabled_test.go`, `corrupt_index_test.go`). Package is `internal/`, so no external consumer can exist.
- **Execution:** Census reproduced by grep over the whole Edge module.
- **Fix:** Sound deletion; tests call `OpenCached(path, DefaultCacheBlocks)`.

### RE-SERV-196 — VERIFIED
- **Citations:** `service.go:67-82` — `maxServiceLogLines = 500` with the stated rationale ("bounds one snapshot, and therefore the memory a request can make this process hold") and `clampLogLines`. `openwrtManager.ServiceLogs` (:173-176) ignores its `lines` parameter entirely: `return readLogCommand("logread", "-e", "ps2servers-edge")`. `systemdManager.ServiceLogs` (:208-212) clamps via `"-n", strconv.Itoa(clampLogLines(lines))`. Caller `api.go:284-295` streams every returned line into the response.
- **Mechanism:** Exactly as claimed — the bound exists, is honoured on systemd, and is not applied on OpenWrt. (Minor wording note: the finding's benefit says "all three managers"; the third, `genericManager`, returns an error and no lines, so the fix concerns the two log-returning managers. This does not weaken the defect.)
- **Execution:** n/a.
- **Fix:** Sound and minimal: truncate to `clampLogLines(lines)` inside the OpenWrt manager, reusing the existing clamp.

### RE-SERV-197 — VERIFIED
- **Citations:** `sessionstats.go:247-266` (`Parse`), `:67-74` (`WithClock`, `WithLimits`, both commented "for tests").
- **Mechanism (zero-caller census):** Repo-wide grep over all `.go` files: `sessionstats.Parse` is called only from `internal/smb/session_summary_test.go:100`, `internal/udpbd/session_summary_test.go:93`, `internal/udpfs/session_summary_test.go:43` (plus the package's own test); `WithClock`/`WithLimits` only from `internal/sessionstats/sessionstats_test.go`. The other `Parse(` hits in `main.go` are `flag.FlagSet.Parse`, a different symbol. Both mutators write `Stats` fields with no synchronisation, as claimed.
- **Execution:** Census reproduced by grep.
- **Fix:** Sound: move the helpers into test files (in-package tests can set unexported fields directly).

### RE-SERV-198 — VERIFIED
- **Citations / per-symbol census:**
  - `API.log` — field at `api.go:22`, assigned at `webui.go:206` (`log: s.cfg.Log`) and in a test literal (`webui_test.go:31`). Grep for reads of `a.log` in `api.go` returns none — handlers use `a.logBuffer`, `a.manager`, `a.logLines`, `a.logClients` (the `a.log*` hits are those distinct fields, not `a.log`).
  - `Server.GeneratedPassword` — `webui.go:106-107`; repo-wide grep returns only the definition. `Serve` already logs the generated password itself.
  - `Server.Close` (webui) — `webui.go:293-298`; no caller of the webui server's `Close` exists. The `server.Close()` calls in `main.go:334,436` are on the udpbd and smb server types, not webui; the webui path in `main.go` constructs `srv` via `webui.New(...)` and calls only `srv.Serve(ctx)`.
- **Mechanism:** All three items dead as claimed; I specifically checked the two `main.go` `Close()` calls as candidate defeaters and they are different types.
- **Execution:** Census reproduced by grep.
- **Fix:** Sound deletions, no replacements.

### RE-SERV-199 — VERIFIED
- **Citations:** `root.go:235-259` `List`: resolves the directory (:236), then per entry calls `r.Resolve(child, false)` (:247) and `os.Stat` on the result. `Resolve` (:66-97) runs `filepath.EvalSymlinks` plus a `filepath.Rel` containment check.
- **Mechanism:** Per-entry full resolution + stat on top of `ReadDir`, exactly as claimed; the only production caller is `internal/udpfs/operations.go:326` (the directory-listing path). No fast path for non-symlink entries exists. The finding itself labels the cost INFERRED/Med — fairly.
- **Execution:** n/a (no benchmark claimed or run).
- **Fix:** Sound in shape (Lstat first, full `Resolve` only for symlinks); correctly flagged Med risk — symlink semantics must be re-checked against `root_test.go`.

### RE-SERV-200 — VERIFIED
- **Citations:** `launcher/servers.py:70` `binary_rel` field; `:87-93` `resolve_binary`; `:96-111` native branches of `is_available`/`launch_command`; `launcher/serve.py:156-159` native-server rejection.
- **Mechanism (census):** All 8 `REGISTRY` ServerDefs declare `runtime="python"` (:386, 435, 451, 467, 567, 631, 658, 717). Repo-wide grep for `binary_rel`/`resolve_binary` returns only the declaration and its own two methods — no ServerDef populates `binary_rel`, no test exercises the native branch. The mechanism is unreachable as claimed.
- **Execution:** Census reproduced by grep.
- **Fix:** Sound deletions; keeping the `runtime` field itself is fine since `serve.py` reads it.

### RE-SERV-201 — VERIFIED
- **Citations:** `launcher/virtual_exfat.py:39-45` `upcase_table()` loops `for c in range(65536)`; `__init__` (:71-95) calls it and then RLE-encodes all 65,536 entries in a second loop; `name_units` (:31-37) encodes the name as UTF-16-LE twice per call.
- **Mechanism / measurement (my execution, in `/tmp`):** `len(upcase_table()) == 65536` confirmed in code and at runtime. My timings on this sandbox: `upcase_table()` alone ≈ 72 ms; `VirtualExfat` construction over a one-file folder ≈ 176 / 121 / 88 ms across three runs — the same order as the finding's claimed ~127-167 ms construction and ~180 ms table-only (my table-only figure is lower, hardware-dependent; the fixed-cost mechanism and its dominance of construction are confirmed). Table and encoded form are pure functions of the spec, identical per instance.
- **Execution:** Timed by me (see above); counts reproduced.
- **Fix:** Sound: compute once at module level (lazily) and reuse. Pure deletion of repeated work.

### RE-SERV-202 — VERIFIED-DRIFT
- **Citations:** `launcher/raw_storage.py:326-367` `_metadata()` (Windows: PowerShell `Get-Disk`/`Get-Partition`/`Get-Volume`, 20 s timeout at the `subprocess.run`; Linux: `lsblk` tree walk); `open_raw_device` :284-311; `mount_warning` :409-427; `list_devices` :392-407.
- **Mechanism:** The duplicate-enumeration claim holds, but the count is understated for one path. `_metadata()` call sites in one `open_raw_device`: (1) `_exclusive_target(path)` at :289 (exclusive only), (2) on Linux-exclusive, a **second** `_exclusive_target(path)` recheck at :299 after unmounting, (3) `mount_warning(path)` at :310, which calls `_metadata()` again (:413). Corrected counts: non-exclusive open = 1 enumeration; Windows-exclusive = 2; **Linux-exclusive = 3**, not "up to twice". The finding's body describes only calls (1) and (3) and misses the :299 recheck.
- **Execution:** Call-graph re-derivation from source (no Windows host here to time PowerShell; cost claim rests on the code's own 20 s timeout, as the finding states).
- **Fix:** Sound, and worth slightly more than filed: fetch metadata once per open and pass the record into both the recheck and the mount-warning computation.

### RE-SERV-203 — VERIFIED
- **Citations:** `launcher/session_stats.py:1-16` header: "Shared by every server (HTTP, SMBv1, UDPFS, UDPBD), so one parser reads all of their lines."
- **Mechanism:** Actual `SessionStats(...)` producers (repo grep, non-test): `http_server.py:1183` ("http"), `smbv1_server/smbserver_opl.py:1753` ("smbv1"), `smb2_server/smb2_server.py:1790` (`"smbv%d" % args.smb_version` → smbv2 **and** smbv3, neither named in the header), `udpfs_server/ps2servers_core.py:588` ("udpfs"), `udpbd_server/udpbd_server.py:449` ("udpbd") — six producers, two omitted. Conversely, the NFS (`servers.py:624-652`) and RetroAchievements (`:712-746`) ServerDefs have no `session_summary` field at all, so "every server" also overclaims. Both limbs hold.
- **Execution:** Census reproduced by grep.
- **Fix:** Sound: correct the parenthetical to (HTTP, SMBv1, SMBv2, SMBv3, UDPFS, UDPBD). Doc-only.

### RE-SERV-204 — VERIFIED-DRIFT
- **Citations / per-symbol census:**
  - `derive_watch` (`launcher/ra_sets.py:204`): repo-wide grep returns only the definition; all callers use `derive_direct_watch`. **Dead — confirmed.**
  - `import sys` (`launcher/achievements.py:13`): AST census by me — `sys` is never loaded as a name/attribute anywhere in the file. **Unused — confirmed.**
  - `_NoRedirect` import (`launcher/ra_set_client.py:7`): AST census — never used inside `ra_set_client.py`. **But** it is a load-bearing re-export: `tests/test_ra_sets.py:8` does `from launcher.ra_set_client import RASetClient, _NoRedirect` and uses it at :99. Deleting the import as filed would break that test import unless the test is switched to `launcher.ra_http` (where the class is defined, `ra_http.py:21`).
  - `ENDPOINT` attributes: the finding has the two clients **swapped**. It claims the set client's `ENDPOINT` (`ra_set_client.py:13`) "is referenced nowhere" and the session client's (`ra_session_client.py:56`) is referenced "only by a test assertion". My grep shows the opposite: the only test reference, `tests/test_ra_sets.py:84` (`request.full_url == client.ENDPOINT`), uses a **`RASetClient`** (constructed at :77); the **session** client's `ENDPOINT` has zero references anywhere. Both attributes remain test-only-or-less surface, so the clutter conclusion stands, but the per-client attribution and the keep/delete recommendation attached to it are reversed.
- **Mechanism:** Dead-code substance confirmed for all four items; two details corrected above.
- **Execution:** Grep + AST census reproduced by me.
- **Fix:** Mostly sound with corrections: delete the alias and the `sys` import; delete the **session** client's `ENDPOINT` outright; the set client's `ENDPOINT` is the one with a test contract; and the `_NoRedirect` deletion must be paired with updating the test's import to `launcher.ra_http`.

### RE-SERV-205 — VERIFIED
- **Citations:** `validate_watchlist` call sites confirmed at `ra_sets.py:200` (in `derive_direct_watch`), `ra_watchlist.py:101` (`WatchSession.install`), `ra_receiver.py:111` (`Receiver.complete`), `ra_evaluator.py:73` (`Evaluator.__init__`).
- **Mechanism:** Traced the owned chain: `EvaluatedReceiver.complete_set` (ra_evaluated_receiver.py:56) → `derive_direct_watch` (validation #1) → `EvaluatedReceiver.complete` (:111) constructs `Evaluator(...)` (validation #2, :130) and calls `receiver.complete(...)` → `Receiver.complete` validates again (#3, ra_receiver.py:111) → `session.install(...)` → `WatchSession.install` validates a fourth time (#4, ra_watchlist.py:101) — all over the same immutable `bytes` object within one activation. No later pass can fail where an earlier one in the same chain passed.
- **Execution:** Call-chain re-derivation from source.
- **Fix:** Sound: validate at derivation and at the IPC/trust boundary only; the fix correctly preserves the cross-process check.

### RE-SERV-206 — VERIFIED
- **Citations:** `launcher/ra_web.py:142-145` `wait_dirty` waits on the single `RAState._dirty` event then clears it; `:507` the `/events` handler calls `owner.state.wait_dirty(timeout=1.0)`, discards the return value, and unconditionally serialises `to_dict()` and writes it; `:567` `RAWebServer.close()` pokes `self.state._dirty.set()`.
- **Mechanism:** Exactly as claimed: one shared event for all clients (first waker clears it for everyone), result ignored, so every client gets a full-state push on the ~1 s timeout regardless of change. No per-client revision tracking exists anywhere in the file (grep for `_dirty`/`wait_dirty` returns only the sites above plus the `set()` calls in state mutators).
- **Execution:** n/a.
- **Fix:** Sound; the LESS option (delete `wait_dirty`/`_dirty`, keep the honest 1 s poll-push) matches current observable behaviour.

### RE-SERV-207 — VERIFIED
- **Citations / per-symbol zero-caller census (whole repo, code + tests + scripts + docs):**
  - `AVAST_GEN_PUBLIC_NOTE` (`launcher/release_metadata.py:73-79`): exactly one hit — its own definition. **Zero callers.**
  - `theme_assets.photo()` (`launcher/theme_assets.py:68-76`): zero callers; both real call sites use `photo_fit` (`launcher/asset_skin.py:20`, `launcher/gui.py:1523`). **Zero callers.**
  - `LauncherApp.on_close()` (`launcher/gui.py:3562-3563`): no caller of this method (other `on_close` hits are unrelated parameters/attributes in `setup_guide.py`, `achievement_viewer.py`, `ra_web.py`). **Zero callers.**
  - `LauncherApp._quit_from_tray()` (`launcher/gui.py:3774-3775`): exactly one hit — its own definition. **Zero callers.**
  - dependency_panel wrappers (`launcher/dependency_panel.py:43-48`): `summarize_status_for_ui()` is a one-line forward to `optional_deps.summarize_statuses()`; `_status_bits()` is a one-line forward to `summarize_status_for_ui()`; used at :53 and :60. **Double wrapper confirmed.**
- **Mechanism:** All five items as claimed.
- **Execution:** Census reproduced by repo-wide grep per symbol.
- **Fix:** Sound deletions; inlining `optional_deps.summarize_statuses()` at the two use sites.

### RE-SERV-208 — VERIFIED
- **Citations:** `launcher/game_library.py:227-286` (`Library.installed`); `launcher/library_catalog.py:94-103` (`_scan_path`: per-component `lstat` + `resolve(strict=True)`), `:178-218` (`list_games`/`_current_identity`); `launcher/library_index.py:157-158` (`read_index` already `_scan_path`-validates).
- **Mechanism:** In `installed()` with an index: `_scan_path` runs per media directory (:241), per file (:250), again per result row building `available` (:262), and again per indexed game (:272) — on top of the pass `read_index` already performed. In `Catalog.list_games()`, `_current_identity` runs on every row up to the 10,000-row LIMIT, and for verified/conflict rows does a fresh `Path.stat()` + fingerprint build (:206-218). Both limbs re-derived as claimed.
- **Execution:** n/a (call-graph re-derivation).
- **Fix:** Sound in direction; correctly Med risk (the root-mismatch check must be kept, as the finding says).

### RE-SERV-209 — VERIFIED
- **Citations / my measurements:** `stat`: `launcher/assets/theme/LOGO.png` = **602,983 bytes** — matches the claimed 602,983 / "603 KB". PNG header dimensions read by me: **1229×1185** — matches. Theme-asset total: 602,983 + 12,166 + 11,694 + 12,266 = **639,109 B**, so LOGO is 94.3% of shipped theme bytes (claimed 94% of 639 KB ✓).
- **Mechanism:** Consumers confirmed: About tab `photo_fit(..., max_width=150, max_height=150)` (`gui.py:1523-1524`); Linux tray resized to 64×64 (`tray_linux.py:71-76`); release workflow AppImage icon `-resize 256x256` (`.github/workflows/release.yml:284`). Nothing displays it above 256 px. `photo_fit` (`theme_assets.py:78-92`) shrinks by integer `subsample` only, as claimed.
- **Execution:** Measured by me (stat + PNG IHDR parse).
- **Fix:** Sound: re-encode at 256×256, data-only change.

### RE-SERV-210 — VERIFIED
- **Citations / my measurements:** Source segment `gui.py:126-221` measured by me at exactly **10,223 characters / 96 lines** — matches the finding's script count precisely. Two `+=` appends in the same file at :208 and :210; sole display site :1656 (`text.insert("1.0", ABOUT_TEXT)`).
- **Mechanism:** Runtime mutation from outside the module confirmed: `launcher/main.py:136-139` appends `ADMIN_ABOUT_TEXT`/`UNIX_ABOUT_TEXT` to `gui.ABOUT_TEXT` at startup. The displayed text exists in no single file, as claimed.
- **Execution:** Segment measured by me (the runtime-concatenated string is 10,159 chars by my AST evaluation — the finding's figure is the source-segment count, which is the number it cited).
- **Fix:** Sound: trim in place, delete duplicated guide/card-help prose, no new docs mechanism.

### RE-SERV-211 — VERIFIED
- **Citations:** `launcher/optional_deps.py:50-68,139-190`; `launcher/dependency_panel.py:51-69,71-83`.
- **Mechanism:** `check_all()` (:189-190) is `[check_lz4(), check_libchdr()]` with no memoisation; `check_libchdr()` walks candidates, calls `_prepare_native_dir` (mutating PATH/DLL dirs) and `ctypes.cdll.LoadLibrary` via `_try_load_library` on every call. Call sites re-run it on panel creation (`refresh_status_async`), on "Check" (`refresh_status`), and again in Details (`show_libchdr_details` → direct `check_libchdr()`). Conversely `_known_path_dirs()` caches the PATH snapshot in `_PATH_DIRS` forever (:47, :58-67) — process-stale, as claimed (the finding fairly labels that consequence INFERRED).
- **Execution:** n/a (call-chain re-derivation).
- **Fix:** Sound: memoise after first successful probe with invalidation on the install path; drop the `_PATH_DIRS` cache.

### RE-SERV-212 — VERIFIED
- **Citations:** `packaging/openwrt/Makefile:4` `PKG_VERSION:=0.8.2`; `:21` `TITLE:=PS2 Servers Edge UDPFS server`; `:26-28` description "A small read-only UDPFS server…". Source of truth `launcher/release_metadata.py:15` `PRODUCT_VERSION = "0.9.4"` — a full minor release ahead.
- **Mechanism:** `tools/version_source.py` guards only `edge-build.yml` (`VERSIONED_WORKFLOWS = (EDGE_WORKFLOW,)`; `--check-sources` checks that list) — the Makefile is not covered, as claimed. The binary's actual scope is four subcommands (`udpfs`, `udpbd`, `smb`, `webui` — usage text and dispatch in `cmd/ps2servers-edge/main.go:32-42,113-125`), and read-only is the package config's choice (`packaging/openwrt/files/ps2servers-edge.config` sets `read_only '1'`; the binary defaults writable, main.go comment at the udpfs flags). Title/description are stale on both axes.
- **Execution:** n/a (file reads + grep).
- **Fix:** Sound: extend the existing version guard to the Makefile; update title/description to the four-subcommand scope.

### RE-SERV-213 — WEAKENED
- **Citations:** `.github/workflows/release.yml` and `release-on-main.yml` read in full by me.
- **Mechanism — core stands, two filed details are wrong:**
  - **Count:** `grep -c "continue-on-error: true" .github/workflows/release.yml` = **11**, not the claimed 13 (the finding's own line list names only 11: 146, 228, 235, 252, 269, 343, 361, 379, 388, 403, 420). The 5 occurrences in `release-on-main.yml` are confirmed.
  - **The self-negating pairing is misattributed:** in `release.yml`, the portable upload step (:403) has `continue-on-error: true` but **no** `if-no-files-found` at all, and the AppImage upload (:420) pairs `continue-on-error: true` with `if-no-files-found: ignore` — the opposite setting. The only `if-no-files-found: error` in the file (:471, source-archive upload) is on a step **without** `continue-on-error`. The claimed pairing does exist, but in the *other* workflow: `release-on-main.yml`'s "Upload portable release asset artifact" step pairs `continue-on-error: true` with `if-no-files-found: error`.
  - What remains true: every portable/AppImage build, stage, checksum, attestation and upload step in `release.yml` is `continue-on-error: true`, and the publish job's only check is `ls -la release-assets` plus fallback rows in the notes generator — so a broken portable/AppImage build produces no red signal. The defect is real; its sharpest cited example is not in the file/line given.
- **Execution:** Workflow files grepped and read by me (counts above are mine).
- **Fix:** Still sound (drop `continue-on-error` from one final existence-verification step per optional artifact; remove the self-negating pairing — in `release-on-main.yml`, where it actually occurs).

### RE-SERV-214 — VERIFIED
- **Citations / my census of every Go toolchain pin in CI/build files:**
  1. `native/ps2servers-edge/go.mod:3` — `go 1.22`, consumed via `go-version-file` by `.github/workflows/edge.yml:44` (test job) and `.github/workflows/edge-build.yml:228`.
  2. `.github/workflows/edge.yml:198` — parity job hardcodes `go-version: "1.25"`.
  3. `packaging/docker/Dockerfile.edge:2` — `FROM golang:1.23-alpine`, and the Dockerfile runs `go test ./...` at image-build time with that third toolchain (line 7).
  No other pins exist (grep for `go-version`/`golang:`/Go version literals across workflows, packaging and tools returns only these).
- **Mechanism:** Three different compilers produce the unit-test evidence, the parity evidence and the shipped/container binary, exactly as claimed; nothing in-tree states the divergence is intentional.
- **Execution:** Census reproduced by grep.
- **Fix:** Sound: point the parity job at `go-version-file`; pin or document the Dockerfile divergence.

### RE-SERV-215 — VERIFIED
- **Citations / my measurements:** `stat`: both `ps2serversgithubbanner.png` and `docs/assets/ps2servers-banner.png` = **571,581 bytes**. `md5sum`: both `7d13770364c4192c47463f2ba0ee1ff0` — identical to the finding's claimed md5. `sha256sum` (mine): both `070f6dae62b290cef97cb16678d8acf2a8bb1052362d6931fcddef29dec3b28c`. `git ls-files -s`: both are the **same git blob** `b1469e3078d279a7515bcd646dd7df93ddf0cacf`. Byte-identity is total.
- **Mechanism:** The docs copy is the referenced one — `og:image`/`twitter:image` tags across `docs/*.html` point at `assets/ps2servers-banner.png`. Two tracked copies, two-place update hazard, as claimed.
- **Execution:** Measured by me (stat + md5 + sha256 + git blob id).
- **Fix:** Sound: keep one canonical copy. (GitHub's repo-social/banner use of the root file should be checked by whoever deletes — the finding already hedges this way.)

### RE-SERV-216 — WEAKENED
- **Citations / my measurements:** `stat` on `native/ps2servers-edge/internal/compression/testdata/`: `test.iso` = **1,110,016 B**, `test_cd.chd` = **1,055,592 B**, `test_dvd.chd` = **1,049,766 B** — each exactly as filed. My sum: **3,215,374 B = 3.22 MB** (3.07 MiB), not the "~3.16 MB" in the title — a small numerical drift.
- **Mechanism — two filed premises are refuted by an in-tree note the finding says does not exist:** the finding claims the fixtures are "generated" and that "no in-tree note says so" (about the deliberate choice). In fact `testdata/README.md` (842 B, tracked in the same directory) documents them: they are **unmodified copies from `pcm720/udpfsd` at a pinned commit**, kept as cross-implementation reference vectors whose decoded bytes and EOF behaviour the tagged tests check exactly, with the Core/Edge divergence explained. They are not synthetic fixtures this repo generated, and regenerating the ISO in-test would destroy the reference-vector property the README describes (the CHDs decode *to* that reference). The size cost in every clone/archive is real; the "undocumented, generated" framing is not.
- **Execution:** Sizes measured by me; README read by me.
- **Fix:** The filed fix (generate the ISO in-test, or record the choice) is largely moot — the choice is already recorded. What survives is only the bare size observation; any removal would need to argue against the documented reference-vector purpose, which the finding does not engage.

---

## Tally

- **VERIFIED:** 22 — RE-SERV-191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 203, 205, 206, 207, 208, 209, 210, 211, 212, 214, 215
- **VERIFIED-DRIFT:** 2 — RE-SERV-202 (Linux-exclusive open enumerates 3×, not up to 2×), RE-SERV-204 (ENDPOINT attribution swapped between the two clients; `_NoRedirect` is a test-used re-export)
- **WEAKENED:** 2 — RE-SERV-213 (11 not 13 `continue-on-error` steps in release.yml; the `if-no-files-found: error` + `continue-on-error` pairing is in release-on-main.yml, not release.yml:403-420), RE-SERV-216 (sizes exact but sum is 3,215,374 B ≈ 3.22 MB; fixtures are documented, unmodified upstream reference vectors, not undocumented generated files)
- **REFUTED:** 0
- **BLOCKED-ENV:** 0 findings (sandbox UDP block affected only the udpbd package tests, which no finding in this batch depends on)

Arithmetic check: 22 VERIFIED + 2 VERIFIED-DRIFT + 2 WEAKENED = 26 = RE-SERV-191…216. ✓

## CANDIDATES (new defects / corrections surfaced during verification)

1. **RE-SERV-202 undercount (folded into its DRIFT verdict):** `launcher/raw_storage.py:299` — the Linux-exclusive path in `open_raw_device` calls `_exclusive_target(path)` a second time after unmounting, so a Linux exclusive open pays **three** full `_metadata()` enumerations (:289 via `_exclusive_target`, :299 via `_exclusive_target`, :310 via `mount_warning`→:413), not two. Evidence: `grep -n "_metadata()\|_exclusive_target(path)\|mount_warning(path)" launcher/raw_storage.py` → lines 289, 299, 310, 316, 413.
2. **RE-SERV-213 adjacent gap:** `release.yml`'s portable upload step (:403) omits `if-no-files-found` entirely (upload-artifact default is `warn`), so even without `continue-on-error` a missing portable file would only warn at that step; the hard-`error` setting exists only on the non-optional source/primary uploads. Evidence: `.github/workflows/release.yml:401-410` (no `if-no-files-found` key) vs :471 (`error`, source upload).
3. No other new defects found. In particular, the two `server.Close()` calls in `main.go` that superficially contradict RE-SERV-198 are on udpbd/smb server types, and the `flag.FlagSet.Parse` hits that superficially contradict RE-SERV-197 are a different symbol — both checked and cleared.
