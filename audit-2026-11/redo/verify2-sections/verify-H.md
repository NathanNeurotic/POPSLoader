# Verification Batch H — RE-SERV-161 … RE-SERV-190 (PS2-Servers, adversarial redo)

- **Pin confirmation:** `git -C ~/workspace/audit-clones-2026-11-13/PS2-Servers rev-parse HEAD` → `c5f021c4d38698860f56b03498adc261dbb8d8dd` — matches the assigned pin exactly. Clone read-only; executions ran in a `/tmp/ps2test` copy.
- **Method:** refute-first — every cited file/symbol grepped, duplication bodies extracted and diffed, zero-caller symbols grepped repo-wide (production + tests + attribute access + string references), mechanism claims re-derived from code, selftests executed where the sandbox allows (UDP sendto blocked → multiclient selftest not run, BLOCKED-ENV for that limb only).

---

### RE-SERV-161 — VERIFIED
- Citations: `launcher/directlink.py:1100 parse_packet`, `:1272 _foreign_offer_server_id` both exist at cited lines.
- Mechanism: extracted both TLV loops (1110–1119 vs 1294–1303) and diffed — byte-identical 11-line walk (pad/end/length slicing); only the trailing consumer differs. `parse_packet:1106` rejects `op != 1`, and `_foreign_offer_server_id:1282-1286` explicitly calls it first and returns None for requests, then re-parses replies by hand. No shared TLV helper exists.
- Execution: diff as above.
- Fix: sound, LESS-NOT-MORE (one helper, net removal).

### RE-SERV-162 — VERIFIED
- Citations: `launcher/config.py:20 _app_dir`, `launcher/servers.py:22 frozen_self_exe` exist.
- Mechanism: diff shows the identical candidate sequence (`NUITKA_ONEFILE_BINARY`, then `sys.argv[0]`, `abspath` + `os.path.exists` check). Real differences are in the wrapper, not the probe: config gates on `frozen/__compiled__`, returns `dirname(path)` and falls back to the repo root when unfrozen; servers is ungated, returns the path itself and falls back to bare `sys.executable`. Importers of the servers copy confirmed by grep: `elevate.py:12`, `windows_setup.py:14`, `main.py:420` — and also `gui.py:38` (finding omits gui, does not contradict it). config.py imports nothing from servers.
- Fix: sound; note the fix must keep config's frozen gate / dirname shaping when deriving from `frozen_self_exe()`.

### RE-SERV-163 — VERIFIED
- Citations: `launcher/servers.py:211 _SMB2_FIELDS`, `:441` and `:457 fields=_SMB2_FIELDS` exact.
- Execution: imported the module — `SMBV2.fields is SMBV3.fields is _SMB2_FIELDS` → `True`.
- Fix: `fields=list(_SMB2_FIELDS)` per server — sound, no behaviour change today.

### RE-SERV-164 — VERIFIED
- Citations: `launcher/ra_credentials.py:31 _dpapi`, `launcher/caduceus.py:55 read_secret` exist; grep confirms exactly two `CryptUnprotectData` implementations repo-wide.
- Mechanism: read both bodies. `_dpapi` sets argtypes/restype, validates `outgoing.size` against `LIMIT` (16384), memsets source **and** output before `LocalFree`, raises on failure. `read_secret` re-implements inline, memsets/frees only the result buffer, never wipes its source copy, has no output-size validation, and returns `""` on file-missing / oversize-input / DPAPI-failure / decode-failure alike.
- Fix: sound (decrypt-only reuse + exception→`""` translation at the one call site).

### RE-SERV-165 — VERIFIED
- Citations: all eight sites read at the cited lines: `ra_account.py:14-20`, `ra_credentials.py:25-28`, `ra_session_client.py:59-62`, `ra_set_client.py:16-19`, `ra_sets.py:55-56 (SetContext)`, `ra_account_worker.py:44-46 (AccountTask)`, `ra_evaluated_receiver.py:44`, `ra_owned_service.py:143-146`.
- Mechanism: three rule sets confirmed in the text: (a) username 1..64 **with** `\0\r\n` rejection (account, credentials, session_client, owned_service, account_worker); (b) username 1..64 **without** control-char rejection (`ra_set_client.py:16`, `SetContext` `ra_sets.py:55`, `ra_evaluated_receiver.py:44` — the last also lacks it, which the finding lists but does not individually flag); (c) username **may be empty** (`ra_account_worker.py:44`: `len(self.username) > 64` only, emptiness rejected later only for the `login` operation). Token legs are uniformly 1..4096 + `\0` where present. No shared validator exists.
- Fix: one validator in `ra_credentials` — justified, removes code overall.

### RE-SERV-166 — VERIFIED
- Citations: all four validation loops read: `ra_sets.py:130-145 qualify_set` (ID via `_uint` = 1..2³²−1, expr 1..16384, no NUL, ASCII via encode, total > `MAX_RESPONSE` = 4 MiB, dup-ID rejection), `ra_account_worker.py:138-152`, `ra_resolver_process.py:38-60` (near-verbatim pair loop), `ra_evaluator.py:62-73`.
- Mechanism: `award_achievement` (`ra_session_client.py:117-145`) hand-rolls `json.loads` + `raw.get("Success")` and coerces with bare `int(raw.get("Score") or 0)`, while `start_session`/`ping` in the same class use `ra_sets.decode_response`, whose `_unique_object` hook rejects duplicate keys — confirmed at `ra_sets.py:23-42`.
- Fix caveat (not a refutation): `decode_response` also *raises* unless `Success is True`, but award's "User already has" path consumes a Success-false response — a naive switch would break it; the fix needs a decode variant that returns the dict without the Success gate. Duplication/bypass claim itself stands.

### RE-SERV-167 — VERIFIED
- Citations: `ra_protocol.py:109 clean_title`, `ra_receiver.py:115-117` (inline in `Receiver.complete`), `caduceus.py:35 clean`, `ra_notifications.py:9 safe_title`, `ra_overview.py:18 short` — all read.
- Mechanism: `clean_title` and `caduceus.clean` are character-identical bodies (NFKD → strip combining → ASCII-printable-or-space → limit; caduceus makes `limit` required, protocol defaults 63). The receiver copy is the same logic inlined with the comprehension clauses reordered and `[:63]` hard-coded (and `str(title)` without the `or ""` guard — equivalent for None via the join, output-equal). `safe_title` (whitespace-collapse, 96, keeps non-ASCII) and `short` (whitespace-collapse, caller limit, default 120 in overview) are the distinct display family, as filed.
- Fix: two surviving functions as proposed — sound.

### RE-SERV-168 — VERIFIED
- Citations: `ra_overview.py:94 fetch_engine_state`, `ra_session.py:133 SessionPoller._fetch` read side by side.
- Mechanism: identical construction — `account_url() + "state"`, `urlopen(timeout=2)`, `read(1024*1024 + 1)`, reject > 1 MiB, `json.loads`. Only differences: session version caches an explicit `self.url` when set, and the error strings differ exactly as quoted ("reply exceeds 1 MiB" vs "reply exceeded limit").
- Fix: sound, trivial net removal.

### RE-SERV-169 — VERIFIED
- Citations: all read — `game_library.Library` DB at `game_library.py:63` (`achievement-catalog.sqlite3`, own `games` schema :66-70) vs `library_catalog.default_database()` at `library_catalog.py:105-106` (`catalog.sqlite3`), same `<config>/library/` directory; folder prefs `library_panel.py:69` (`library/games_root.txt`, load/save :87-91) vs `library_gui.py:28` (shared config `game_library_folder`); importers `Catalog.import_image/import_images` (`library_catalog.py:467/500`, `copyfileobj` into `xb`) vs `Library.install/transfer` (`game_library.py:299/316`, temp + validation + `publish_new`, CD/DVD/POPS vs CD/DVD only); backups `Library.backup` (`game_library.py:178`) vs `Catalog.backup_sqlite` (`library_catalog.py:619`), both SQLite-online-backup implementations; UIs at `gui.py:641-648` (LibraryWindow) and `gui.py:1416-1421` (LIBRARY tab / LibraryPanel).
- Fix: direction sound; it is an L-effort consolidation, correctly labelled as such.

### RE-SERV-170 — VERIFIED-DRIFT
- Citations: `setup_guide.py:9 STEPS`, `library_panel.py:16 GUIDE` + standalone window `:520-561`, `library_gui.py:416-424 guide()` prose, `gui.py:1685 _open_ps2_setup_guide` — all exist; three distinct guide texts confirmed.
- Mechanism (corrected limb): the standalone panel window **is** unreachable in the shipped app — `_guide()` at `library_panel.py:516-519` delegates to `app._open_ps2_setup_guide` whenever present, and the panel's only instantiation (`gui.py:1416`) passes the app that defines it. **But** the finding's "both layers independently decide to auto-show a guide on first run" is overstated: the panel's auto-show is explicitly guarded at `library_panel.py:84-85` — `if not hasattr(app, "_open_ps2_setup_guide"): self.after_idle(self._show_first_run_guide)` — so in the integrated app the panel never auto-shows; only the app layer (`gui.py:1661-1675`, status in config `ps2_setup_guide_status` :1677-1682, :3539-3541) does. The doubled first-run *state* (panel `library/first_run_complete` marker :70, written only by the standalone window's Finish at :551-552, vs the config key) is real but inert in production for the same reason.
- Verdict rationale: core claim (3 guides, dead standalone window + GUIDE, doubled state) verified; the independent-auto-show limb corrected above.
- Fix: deletion list as filed remains sound (the guard at :84-85 goes with the machinery it guards).

### RE-SERV-171 — VERIFIED
- Citations: `library_catalog.py:266 scan_detailed`, `game_library.py:227 Library.installed`, `library_index.py:109 read_index`, `ps1_index.py:88 scan` — all read; four independent walkers/contracts as described (tree walk / top-level CD-DVD-POPS + index overlay / re-stat of catalogue rows only / POPS+EMBER walk).
- Mechanism: limits confirmed — `scan_detailed` default `max_entries=10_000` with cap `MAX_SCAN_ENTRIES = 100_000` (:27, the finding's "100,000" is the cap, not the default), `installed` unbounded-with-cancel, `read_index` cap 10_000, `ps1_index` cap 10_000. Result types differ as filed.
- Fix: sound as a direction; L/Med correctly labelled.

### RE-SERV-172 — VERIFIED
- Citations: `disc_identity.py:66 _IsoReader` (`root:100`, `find:120`, `extent:86`, `inspect:153`) and `ps1_vcd.py:20 VcdImage` (`root:63`, `extent:71`, `find:80`, `path_extent:104`) both exist with the cited shapes.
- Mechanism: spot-read both — disc_identity verifies both-endian fields (`_both_endian` :60-63), budgets reads/records; ps1_vcd's `extent` is little-endian-only and its limits are `MAX_DIRECTORY = 16 MiB` / `MAX_BOOT = 64 MiB` (:16-17) vs disc_identity's `MAX_DIRECTORY_BYTES = 1 MiB` / `MAX_CNF_BYTES = 16 KiB`. Sector mapping difference (2352-byte raw + header, `ps1_vcd.read` :44-60) is an adapter difference, as filed.
- Fix: shared record-walking over a `read(offset,length)` callable — justified (one full copy removed).

### RE-SERV-173 — VERIFIED-DRIFT
- Citations: grep census re-run — expressions found at `art_fetch.py:32 _OPL_ID`, `disc_identity.py:21 SERIAL` + `:22 FILENAME_SERIAL`, `game_library.py:163` inline `re.fullmatch`, `library_catalog.py:30 SERIAL_PREFIX`, `ps1_index.py:30 _PS1_NAME_ID`.
- Mechanism (count corrected): that is **six expressions in five files**, not five expressions — disc_identity holds two. PS2 spellings are five (the four outside disc_identity plus both of disc_identity's counted as the canonical pair), so the body's "the four PS2 expressions" undercounts by one. Substantive divergences verified in the patterns themselves: `SERIAL` is unanchored + `re.I` (used via `fullmatch` at :179, and case-insensitive unlike the others), `FILENAME_SERIAL` accepts `_`/`-`, `repair_cover`'s inline form accepts `_` only on an already-uppercased string, `SERIAL_PREFIX` requires a trailing separator, PS1 makes the dot optional. Duplicate `_`↔`-` conversions confirmed (`serial_forms` art_fetch.py:56-62; `.replace("-", "_")` at art_fetch.py:58 — the finding also cites library_catalog.py:225, which I did not individually re-read).
- Fix: import the disc_identity canonical pair in art_fetch/game_library; leave SERIAL_PREFIX and the PS1 pattern — sound.

### RE-SERV-174 — VERIFIED
- Citations: `game_library.py:132 repair_cover`, `library_catalog.py:120 _artwork_palette_image` + `:548 write_art` read in full.
- Mechanism: divergence exactly as filed — repair_cover always `convert("RGBA")` → `thumbnail((512,512))` → FASTOCTREE, saves via temp + `os.replace` (library) and temp + `publish_new` (ART copy); `_artwork_palette_image` uses FASTOCTREE only for real transparency, MEDIANCUT on RGB otherwise; `write_art` writes via `xb` directly. Limits differ: 16 MB / 16 MP (repair_cover :139/:146) vs 10 000 px per side / 50 MP (write_art :565). Both carry the FASTOCTREE/RGBA explanatory comment (:151-153 vs :130-132).
- Fix: sound.

### RE-SERV-175 — VERIFIED
- Citations: inline `"{size}:{mtime_ns}:{ctime_ns}"` at `game_library.py:256` (installed) and `:477` (Compatibility.check); `disc_identity.fingerprint()` at `disc_identity.py:37-45` (`dev:ino:size:mtime_ns[:ctime_ns]`, ctime omitted on Windows with the comment quoted in the finding); `library_index.py:173` emits the game_library format again for `IndexedGame.stamp` while :164 compares the catalogue's stored fingerprint via `disc_identity.fingerprint(info)` — the two formats coexist in the same function, as filed.
- Fix: sound; stored-stamp one-time miss correctly noted in the finding.

### RE-SERV-176 — VERIFIED-DRIFT
- Citations: `.github/workflows/release.yml` = 606 lines, `release-on-main.yml` = 489 lines (wc-verified); same 5-target desktop matrix in both (:20-44 of release-on-main); `edge-build.yml` header confirms the reusable-workflow rationale verbatim.
- Mechanism (duplication verified, drift proof corrected): my recount with a >20-char non-trivial line threshold gives **96 identical lines** (finding says 90 — same order, threshold-dependent). Drift corrections: (1) `verify-version` genuinely has **no** counterpart in release-on-main — verified. (2) The Windows desktop-startup check **does** have a counterpart: release-on-main.yml:119-121 runs the identical step (`Verify fresh-profile Windows desktop stays open` → `tools/check_desktop_startup.py dist/PS2Servers.exe`) inside its build job; the finding's claim of no counterpart is wrong. (3) The AppImage row at release-on-main:333-334 is guarded by `if [ -f PS2Servers-x86_64.AppImage ]`, and no step in that workflow (nor any artifact it downloads — uploads are per-matrix-asset only) can produce that file, so the row can never actually be emitted: it is dead conditional code, not a download table advertising an artifact users will look for.
- Verdict rationale: duplication + the verify-version drift are real; two of the three drift examples are overstated/wrong as corrected above.
- Fix: reusable-workflow extraction remains sound.

### RE-SERV-177 — VERIFIED
- Citations: census re-run — `git ls-files docs/` = **34 `.md`** and **22 `.html`**, exactly as filed. Overlapping pairs confirmed on disk for EDITIONS/editions, EDGE/edge, SMB/smb, NFS/nfs, HTTP/http, OPENWRT/openwrt, PROTOCOL-COMPATIBILITY/protocol-compatibility; the antivirus pair exists as `antivirus-transparency.md` + `antivirus.html` (different stems, same topic — as the finding's pairing implies). `tools/build_docs_index.py` only builds `docs/data/search-index.json` from the HTML; no MD→HTML generator found; `tests/test_edge_manual.py` exists as the one pinning test.
- Fix: direction sound (designate one source per topic); L/Med correctly labelled.

### RE-SERV-178 — VERIFIED
- Citations / per-symbol zero-caller census (whole repo, production + tests + conformance, including `wire.` attribute access and `import *` checks — none exist for these modules):
  - `native_cmac_name` (`smb2_server/smb2_crypto.py:186`) — **1 hit: its own definition.** No caller, no test, no string reference. Its "For logs" docstring is unfulfilled.
  - `STATUS_PENDING` (`smb2_server/smb2_wire.py:120`) — **1 hit: definition only.** No `wire.STATUS_PENDING` anywhere.
  - `FILE_SUPERSEDED` (`smb2_server/smb2_wire.py:181`) — **1 hit in smb2_wire.** Repo grep also finds a *separate, live* same-named constant in `smbv1_server/smbserver_opl.py:90`, used at :909 — a different module's definition, not a caller of the smb2_wire one. Dead as filed (the finding is scoped to smb2_wire.py:181).
  - `GLOBAL_CAP_DFS` (`smb2_server/smb2_wire.py:200`) — **1 hit: definition only.**
  - `PTYPE_BIND_NAK` (`smb2_server/smb2_srvsvc.py:28`) — **1 hit: definition only.**
  - Contrast set re-checked as filed: `blob_timestamp` and `lmv2_response` (`smb2_server/smb2_auth.py:221/:169`) are exercised by `tests/test_smb2_auth.py:28-29,158-162` — test surface, not dead. (`Share.relative`/`Share.resolve(must_exist=…)` not re-grepped individually; not part of the dead claim.)
- Fix: delete the five — sound.

### RE-SERV-179 — VERIFIED
- Citations: `smb2_server/smb2_crypto.py:173-184 _native_cmac`, docstring :15-22 read.
- Mechanism: probe is `win32 → _bcrypt_cmac()`, `linux → _openssl_cmac()`, **no other platform branch** — on macOS (`darwin`) `_NATIVE` caches `None` and every CMAC falls back to the pure-Python AES. The comment at :179-180 confirms the libcrypto-abort rationale. Docstring quantifies pure-Python AES at "under a megabyte per second" with the signature covering every byte of every READ reply. No startup banner or log names the backend (see 178: `native_cmac_name` has no caller).
- Fix: banner-only variant is the LESS-NOT-MORE choice and is sound; a CommonCrypto probe is untestable from this Linux sandbox.

### RE-SERV-180 — VERIFIED
- Citations: `smbv1_server/smbserver_opl.py:1200 h_trans2_find_first2`, `:1258 h_trans2_find_next2` read in full.
- Mechanism: FIRST2 packs `struct.pack("<HHHHH", sid, 1, eos, 0, 0)` — SearchCount literally 1 — and a single `_dir_entry_104` record; stores `(entries, 1)` as the cursor. NEXT2 packs count 1 and one record, advancing the cursor by 1. The full entry list is already materialised by `_list_dir` into `conn.searches`. `_dir_entry_104` stats per entry as filed. (Edge note: FIRST2 indexes `entries[0]` unconditionally — an empty directory would raise rather than return an empty result; see CANDIDATES.)
- Fix: sound; hardware re-test caveat in the finding is appropriate.

### RE-SERV-181 — VERIFIED
- Citations: `smbv1_server/smbserver_opl.py:1012 h_write_andx`, `:360-385 OpenFile.__init__` read.
- Mechanism: `h_write_andx` does `with open(of.path, "r+b") as w:` per request (:1035-1037 in current numbering) despite holding the `OpenFile`; the code itself documents why the read handle stays unbuffered (:368-375 comment). `OpenFile.size` is snapshotted once (`self.size = os.path.getsize(path)` :366, or the decoder's `uncompressed_size` :364) and **never updated by any write path** (grep of `.size` assignments: only :364/:366). `record_read` at :439 computes `expected = min(requested, max(0, of.size - offset))` from that stale size — the diagnostic consequence follows exactly as filed. No defeating guard found.
- Fix: sound, with the finding's own flush-coherence caution.

### RE-SERV-182 — VERIFIED
- Citations: `smbv1_server/smbserver_opl.py:268 Share.resolve`; the comment is at :298 in current numbering (finding says :297 — one-line drift, immaterial): `# Drop a leading "share/" if the client included it (some paths are share-relative already).`
- Mechanism: the full body read — `p = smb_path.replace("\\", "/").lstrip("/")`, then `os.path.realpath(os.path.join(self.root, p))` and the `_inside` check. No share-name comparison or strip exists anywhere in the function, and no caller pre-strips (callers at :813, :868, :1081, :1105, :1240, :1285 pass raw client names). A `\games\DVD\file.iso` path on share `games` therefore resolves under `<root>/games/…` exactly as the finding states.
- Fix: delete the comment (LESS-NOT-MORE default) — sound.

### RE-SERV-183 — VERIFIED
- Citations: `udpfs_server/ps2servers_core.py:71-88 classify_profile` read.
- Execution: brute-forced the extracted logic over all 4096×4096 (discovery, first-data) pairs — **third-branch hits: 0**. Proof sketch matches the finding: reaching branch 3 with `first == modulo` requires branch 1's side condition to have failed, i.e. `first == 0 and discovery == 0`, which forces `modulo == 1 ≠ 0` — contradiction.
- Fix: delete branch 3 — sound.

### RE-SERV-184 — VERIFIED
- Citations: import list `udpfs_server/ps2servers_core.py:18-48`; `MAX_SEND_RETRIES` at :24, `_widen_send_buffer` at :46.
- Execution: occurrence census over the file — `grep -c` returns **1 for each name** (the import line only); both names exist in `udpfs_server/udpfs_server.py` (they are real exports, just unused here). No `getattr`/string/dynamic use in the file.
- Fix: remove the two names — sound.

### RE-SERV-185 — VERIFIED
- Citations: `ps2servers_core.py:639-663 main()` Modulo fast path, `:107-120 AutoUdpfsServer.__init__`, `:306-335 _handle_discovery` Modulo branch — all read.
- Mechanism: `main()` constructs a plain `UdpfsServer(single_port=True, modulo_compat=True)` and returns when `args.protocol_mode == PROFILE_MODULO` (:639ff); the `AutoUdpfsServer` construction at :664 is reached only for auto/standard and passes `protocol_mode=args.protocol_mode`, which by then cannot be modulo. Grep confirms no other production construction of `AutoUdpfsServer` exists. Auto's Modulo branch **is** exercised by tests — `tests/test_udpfs_live_discovery_handoff.py:376ff` builds the class via `__new__` and sets `protocol_mode` directly — exactly the "only a programmatic construction or a test can reach it" scope the finding claims. The `_last_disc` limb verified: `_handle_discovery:309` reads it via `getattr(sess, '_last_disc', None)` and :318 sets it, but `_init_compat` (:122-138) never initialises it — first use is safe only because of the `getattr` default.
- Fix: second option (delete Auto's Modulo branch, base owns Modulo) is the smaller deletion, as filed.

### RE-SERV-186 — VERIFIED
- Citations: `ps2servers_core.py:242 _schedule_fallback`, sole call site :358.
- Mechanism: `_schedule_fallback` unconditionally creates and starts a new daemon `threading.Thread` per call (:262-265), which sleeps `fallback_interval` then re-checks session identity, `handshake_generation`, profile, `first_data_seen`, `rx_streaming`, `fallback_sent` — all but the latest generation exit as no-ops, as filed. Call site :358 is reached on every non-streaming, non-standard discovery in auto mode (streaming discoveries return earlier at :340-358's first block; standard mode returns before it). Thread churn is therefore proportional to discovery rate on that path.
- Fix: single pending timer / deadline-in-select — sound; the receive loop's periodic wakeup exists as claimed (INFERRED limb on broadcast rate is the finding's own, correctly labelled there).

### RE-SERV-187 — VERIFIED
- Citations / per-symbol census (whole repo, `grep -rn tx_start_seq`):
  - In `udpfs_server/udpfs_server.py`: :845 session-proxy property definition, :1690 assignment, :2966 assignment, :3001 assignment, :3208 `Session.__init__` assignment — **5 lines, all writes/definitions, zero reads in the file**, as filed.
  - Outside the file: `ps2servers_core.py:151` assignment (the one the finding flags), plus test/tool *writes* only — `tests/test_udpfs_live_discovery_handoff.py:140` (`sess.tx_start_seq = 10`), `tests/test_udpfs_resent_request.py:58` and `tools/replay_neutrino_udpfs.py:188` (constructor kwargs setting it to 0). **No read of the value exists anywhere in the repo** — no `getattr`, no comparison, no return. The limb is stronger than filed, not weaker.
- Fix: delete property + field + assignments (including the ps2servers_core.py:151 line and the two test/tool kwargs, which would otherwise set a dead attribute harmlessly) — sound.

### RE-SERV-188 — VERIFIED-DRIFT
- Citations: `udpfs_server/pathguard_selftest.py:190-192` UNC skip, `:237` unconditional PASSED line, `:155-185` separator-root section; `multiclient_selftest.py` and `compression_selftest.py` whole-file.
- Execution: ran both runnable selftests in the `/tmp` copy on this POSIX sandbox — `pathguard_selftest.py` printed `[unc] skipped (Windows ntpath semantics only)` and then **`ALL UDPFS PATH-GUARD TESTS PASSED`** (exit 0); `compression_selftest.py` also green. `multiclient_selftest.py` not run (UDP sendto blocked in this sandbox — BLOCKED-ENV for execution only; its content was still grep-censused).
- Mechanism: write-opcode census re-run — `grep -c 'BWRITE|WRITE_REQ|WRITE_DATA'` = **0 in all three selftests**, as filed. Correction on the separator-root limb: with root `/` the section's assertions are not wholly vacuous — they still assert exact join results (`/PS2/CD/game.iso`, top-level file, root itself, `..` clamping) — but any *containment/escape* assertion in that section is indeed un-falsifiable on POSIX, since nothing is outside `/`. The genuinely load-bearing containment cases live in the separate local-containment section (tmp root), which does run on POSIX; the skipped-on-POSIX surface is the UNC section (and the Windows-reinterpreted-name cases), which is the finding's main point and stands.
- Fix: SKIPPED accounting in the summary — sound.

### RE-SERV-189 — VERIFIED
- Citations: `nfs4_server/nfs4_server.py:261-316 _Handles`, caps at :54 (`MAX_CONNECTIONS = 32`), :820-821 (dir cache clear at 64), :868-869 (client eviction at 256) — all read.
- Mechanism: `_Handles.handle()` (:276-284) allocates a fresh number per distinct comps tuple and inserts into both dicts; the only removals are `removed()` (:302) and `renamed()` (:307), invoked only from the server's own REMOVE (:1002) / RENAME (:1037) handlers. No cap, no eviction, no TTL anywhere in the class.
- Execution: in the `/tmp` copy, allocated handles for 30 distinct paths via `_Handles.handle()` — table held **31 entries (30 + root) in both `paths` and `numbers`**, matching the finding's executed count, with no reclamation path.
- Fix: cap + oldest-first eviction reusing the :868-869 pattern — sound (STALE is a handled client error).

### RE-SERV-190 — VERIFIED
- Citations: `nfs4_server/nfs4_server.py:683 _changed`, `:958 _op_write` (calls `_changed()` with no comps), `:768 _op_read` (cached handle discarded when `cached[0] != self.generation`), `:797 _listing` (cache valid only for current generation) — all read.
- Mechanism: `self.generation` is a single server-wide counter; **every** `_changed` caller bumps it — including callers that do pass comps (:926, :973, :986, :1003, :1038), which additionally clear `dir_cache`. `_op_write` (:941-959) has `comps` in hand (`self._need(s.cfh)`) and still calls `_changed()` bare. Consequence as filed: any write invalidates every connection's cached read handles (up to 4 per connection, :776-781) and every listing cache slot on next use. Correctness is preserved; only cache warmth is lost — the finding says exactly this.
- Fix: per-path generation dict — sound; `_op_write` already knows its comps, as filed.

---

## Tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 26 | 161, 162, 163, 164, 165, 166, 167, 168, 169, 171, 172, 174, 175, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 189, 190 |
| VERIFIED-DRIFT | 4 | 170 (auto-show limb overstated — panel auto-show is guarded off in the integrated app), 173 (six expressions in five files, not five expressions; five PS2 spellings, not four), 176 (startup-check counterpart exists; AppImage row is a dead conditional, never emitted; identical-line count 96 by my threshold vs 90 filed), 188 (separator-root assertions not wholly vacuous — exact-join checks still run; containment limb un-falsifiable on POSIX as filed) |
| WEAKENED | 0 | — |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | (multiclient_selftest execution only, within 188; its grep census was completed) |

Total: 30 findings.

## CANDIDATES (new defects, separate from the findings above)

- **CAND-H-1 — `h_trans2_find_first2` crashes on an empty directory.** `smbv1_server/smbserver_opl.py:1243-1244`: `name, lp, sz = entries[0]` with no emptiness check after `_list_dir` succeeds. An empty (or all-filtered) games subfolder raises `IndexError` inside the handler instead of returning an empty/end-of-search reply. Evidence: handler body read in full during RE-SERV-180 verification; no `if not entries` guard exists between the `_list_dir` try/except and `entries[0]`. Severity/effort not assessed — candidate only.
- **CAND-H-2 — Same `_last_disc` getattr pattern in the base server.** `udpfs_server/udpfs_server.py:1627/1634` reads/writes `sess._last_disc` via `getattr` default exactly as `ps2servers_core.py:309/318` does (found during the RE-SERV-185 grep). Not a defect on its own (the getattr makes it safe), but any fix for 185 that initialises the attribute in `_init_compat` should be mirrored or consciously not mirrored in the base class.
- **Fix-hazard note (not a defect):** RE-SERV-166's proposed switch of `award_achievement` to `decode_response` cannot be done literally — `decode_response` (`launcher/ra_sets.py:40-42`) raises unless `Success is True`, while award's already-unlocked path depends on reading a Success-false response's `Error` field. The fix needs a non-gating decode variant.
