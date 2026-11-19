# Verification — Batch G: RE-SERV-127 … RE-SERV-160 (PS2-Servers, blind redo)

- **Pin confirmation:** `git -C ~/workspace/audit-clones-2026-11-13/PS2-Servers rev-parse HEAD` → `c5f021c4d38698860f56b03498adc261dbb8d8dd` — matches the assigned pin exactly. Clone read-only; all execution ran on copies/extractions under `/tmp/verifyG`.
- **Method:** every cited file/function/literal grepped; duplication claims re-derived by extracting and diffing the cited bodies and recounting by grep; mechanism claims re-derived from code, with execution where noted. No UDP network execution was needed (no BLOCKED-ENV items in this batch).

---

### RE-SERV-127 — VERIFIED
- **Citations:** `smb2_server/smb2_srvsvc.py:134-137` (`write` → `self.outbox += self.transact(data)`) and `:144-161` (`transact`: `frag_len > len(data)` → `RpcError("not a DCE/RPC v5 PDU")`; REQUEST without `PFC_FIRST_FRAG|PFC_LAST_FRAG` → `_fault(..., NCA_UNSPEC_REJECT)`) — exact. No buffering anywhere upstream: `smb2_server.py:1170` (`h_write`) passes each SMB WRITE's payload straight to `h.pipe.write(data)`; `:1390` FSCTL_PIPE_TRANSCEIVE calls `transact` directly.
- **Mechanism / Execution (EXECUTED, /tmp copy of `smb2_srvsvc`):** built a valid 72-byte BIND PDU with the module's own `_header`/syntax constants. Whole PDU in one `write()` → returns 72, BIND_ACK in outbox. Same PDU split: `write(pdu[:10])` raised `RpcError: short PDU` (which `h_write` maps to `STATUS_INVALID_PARAMETER`); the second chunk also raised. A REQUEST PDU with fragment flags `0` returned a FAULT PDU (ptype 3). Both limbs confirmed live, not just by reading.
- **Fix:** Sound. Buffering in `write()` until `frag_len` bytes are present covers the WRITE-split case in a few lines; the audit correctly leaves RPC-fragment reassembly as a documented limit. One unstated sub-case: a single WRITE carrying *two coalesced* PDUs is also mishandled today (`transact` slices to `frag_len` and discards the tail) — a buffering fix should loop, not just wait.

### RE-SERV-128 — REFUTED
- **Citations:** Definition and both callers exist exactly as cited (`udpfs_server/udpfs_server.py:2746-2767`, callers `:2968`, `:3003`), and the test seam exists (`tests/test_session_summary.py:296` monkeypatches it to return 1024). The mechanism claim built on them is false.
- **Mechanism / Execution (EXECUTED — extracted the actual method via AST and ran it):** the audit's proof ignores the tie-break limb. Candidates are iterated in order `(1024,512), (1280,256), (1408,128)`; on a packet-count **tie**, a larger alignment wins, and 1024 is visited *first*. Results from the real code: `_optimal_chunk_size(0)=1024`, `(1)=1024`, `(100)=1024`, `(1024)=1024`, `(1025)=1280`, `(2048)=1024`, `(5000)=1280`, `(12800)=1280`, `(20000)=1408`, `(100000)=1408`. Distinct outputs over the swept domain: `{1024, 1280, 1408}`. The audit's premises "the 1024- and 1280-byte candidates always need *more* packets" and "for every input, including 0, the method returns 1408" are both false — small transfers tie at 1 packet and 1024's alignment 512 beats the incumbent's 128.
- **Fix:** Invalid as proposed. Replacing call sites with `MAX_DATA_PAYLOAD` (1408) and deleting the method would *change wire behaviour* for every transfer ≤1024 bytes and for the 1280 ranges, and would break the very test seam the finding itself flags. Withdraw.

### RE-SERV-129 — VERIFIED
- **Citations:** `nfs4_server/nfs4_server.py:1045-1064` `build_parser` has no `--session-summary`; `grep -ci session nfs4_server/nfs4_server.py` = **0** (the word does not occur once in the file). Present as cited in `http_server/http_server.py:1155,1183` (import comment at `:47` literally reads `shared by every server`) and `udpbd_server/udpbd_server.py:399-402,444-449`. Recount repo-wide: SMBv1 (`smbserver_opl.py:1701,1752-1753`), SMBv2 (`smb2_server.py:1755,1789-1790`), UDPFS Core (`ps2servers_core.py:559,587-588`), HTTP and UDPBD all wire `launcher.session_stats.SessionStats`; NFS wires nothing. The launcher agrees: `launcher/servers.py` appends `--session-summary` in five argv builders (`:156,199,354,378,555`) and `_nfs_argv` (`:611`) is not one of them — so no crash, just the silent gap described.
- **Mechanism:** Absence claim, grep-verified as above.
- **Fix:** The "state the exclusion in parser help/README" alternative is the LESS-NOT-MORE-compliant half and costs ~1 line. The wiring alternative adds event-recording code to NFS (net addition, justified only as completing a shared feature, not as deduplication). Footnote: the standalone `udpfs_server/udpfs_server.py` main also lacks the flag, but UDPFS-the-server has the feature through the Core entry point; NFS has no entry point with it at all, so the title stands.

### RE-SERV-130 — VERIFIED
- **Citations:** Go, `native/ps2servers-edge/internal/udpfs/operations.go`: `handleWriteRequest` at `:547-595` does `st.WriteBuffer = make([]byte, 0, size)` and stores the declared `size` nowhere else (no `WriteExpectedLen` assignment — grep for `WriteExpectedLen` returns only `session/session.go:97,107,126`, `blockdev.go:301`, `operations.go:634-635,658`). The `> 0` enforcement at `:634-643` therefore only ever fires for BWRITE. `completeWrite` (`:653-…`) routes on `WriteIsBlock`; the file branch writes `buf`, syncs and `sendWriteDone(st, int32(n))` with no comparison to any declared length. `completeBlockWrite` (`blockdev.go:344-…`) has the exact-length check and the quoted "same defect as the overflow bug in inRange" comment, verbatim.
- **Mechanism:** Re-derived: a plain WRITE sequence is bounded only by `transferCap` and driven by the client's `totalChunks`; declared-vs-delivered is never compared on that path. No defeating guard found (`ResetWrite` zeroes `WriteExpectedLen`, `session.go:126`, and only `startBlockWrite` sets it).
- **Fix:** Sound and small: set `WriteExpectedLen` in `handleWriteRequest` and add the completion check to the non-block branch. Two implementation notes the fix should carry: (1) a declared size of 0 would still be unenforced under the existing `> 0` sentinel; (2) the field's doc comment (`session.go:97`, "how many bytes a BWRITE said it would deliver") must be updated or the next reader re-learns the wrong invariant.

### RE-SERV-131 — VERIFIED
- **Citations:** `launcher/main.py:107-409` is `_apply_gui_review_fixes` (next def at `:412`; ~302 lines), docstring at `:112-113` says "This stays as a runtime shim so release-risk remains low", de-duplication comments at `:130-145` region present. Patched `append_log` at `main.py:393-406`; original at `launcher/gui.py:3042-3053`.
- **Mechanism / Diff:** Extracted both `_append_log` bodies: identical except exactly one behaviour — the patched copy computes `at_bottom = widget.yview()[1] >= 0.99` and only `see("end")` if already at bottom; gui.py's original calls `widget.see("end")` unconditionally. Guard flag `_ps2_gui_review_fixes_patched` confirmed at the tail (`main.py:408-409` region). Drift claim is precise, not overstated.
- **Fix:** Sound (finish the migration into gui.py); it is a move, not a net deletion, but it does remove the second copy, which is the point.

### RE-SERV-132 — VERIFIED
- **Citations:** `launcher/ra_account_worker.py:271-416` `AccountSession` with all seven `begin_*` methods and `accept` — exact. Production literals confirmed in `launcher/achievements.py`: `SetContext(creds.username, 1, …)`, `AccountTask(1, 1, "set", …)`, `AccountTask(2, 1, "start_session", …)` in the resolver (~`:183-190`), `service.bind_account(creds.username, 1)` at `:232`, and submission tasks taking `ctx.epoch` (the same literal-1 context) at `:298,311`.
- **Mechanism / Census (recounted):** `grep -rn "begin_login|begin_resume|begin_import|begin_set|begin_start_session|begin_award|begin_ping|\.accept(" launcher/ tests/` — every caller of `begin_*`/`accept(` is in `tests/test_ra_account_worker.py`, `tests/test_ra_evaluator.py`, `tests/test_ra_owned_service.py`; zero in `launcher/`. The only production touch of a session object is `achievements.py:254` `service.run_account(lambda session: session.logout(forget=True))`. `AccountSession.logout()` does `self._epoch += 1` (`ra_account_worker.py:405-410`), so the generation design exists and the shipped runtime never uses it.
- **Fix:** The either/or framing (wire it or delete the surface) is the right shape; no new mechanism proposed. Complies with LESS-NOT-MORE under either branch.

### RE-SERV-133 — WEAKENED
- **Citations:** All exact: `launcher/ra_sets.py:156-158` accepts `{"opl", "orbit-v1.0.2", "caduceus"}` in `derive_direct_watch`, orbit validator `launcher/ra_watchlist.py:60-73` (1216-byte ceiling), `launcher/ra_resolver_process.py:27-29` validator set is only `{"opl", "orbit-v1.0.2"}`, production profile production at `launcher/achievements.py:152` is `"caduceus"` or `"opl"` only. Repo grep confirms no code constructs an `IdentificationResult` with profile `orbit-v1.0.2` (the only orbit-profile derivations are in tests).
- **Mechanism — true scope is narrower than filed:** the caduceus limb is **latent, not live**. The only production `ProcessResolver` is inside `AccountWorker` (`ra_account_worker.py:238`), and it **overrides** the validator with `validate=valid_account_result` — it never runs `valid_identification_result`. The caduceus production path (`achievements.py` `resolve_job` → `OwnedService`) never crosses the IPC validator at all; default-validator `ProcessResolver` instances exist only in `ra_resolver_process.py`'s own probes (`:186,191`) and tests. So no shipped flow currently discards a caduceus result; what exists is a closed-set disagreement that would bite the first caller who wires the default validator to the owned runtime.
- **Fix:** Still sound and small (one set edited, or the orbit profile deleted), but it should be filed as a vocabulary/latent-consistency fix, not as a live discard bug.

### RE-SERV-134 — VERIFIED
- **Citations:** `launcher/__init__.py:14-92` contains `_GuiFinder`/`_GuiLoader`, inserted at `sys.meta_path[0]`, with the quoted docstring concession ("The normal, boring implementation would be direct calls from the GUI build path"). `launcher/asset_skin.py:152-164` is `install()`; its tab-icon patcher replaces `ttk.Notebook.add` (`asset_skin.py:42-56`) and it calls `full_skin_controls.install`. `launcher/full_skin_controls.py:9-204`: `install` replaces `ServerCard._build` (`:198`) and `LauncherApp.apply_server_settings`/`revert_server_defaults` (`:202-203`), guarded by `_ps2_full_skin_controls_patched`. `launcher/gui.py:439` is the `LauncherApp._build` being wrapped. Patch-order/guard-flag description matches the code.
- **Fix:** Sound: the two direct calls at the top of `LauncherApp._build` replace ~78 lines of import machinery with no intended behaviour change. This is a genuine net-removal fix.

### RE-SERV-135 — VERIFIED
- **Citations:** `launcher/ps1_index.py` is exactly 147 lines, scanner at `:88-147`, `ember_name_problem` at `:52-61`, `Ps1Game` at `:34-47`.
- **Mechanism / Census (recounted):** `grep -rn "ps1_index|Ps1Game" launcher/ tests/` — no import or use anywhere in `launcher/` outside the module itself; only consumer is `tests/test_companion_fixtures.py:22,129-157`. The capability matrix quote is real: `docs/COMPANION-CAPABILITY-MATRIX.md:53` "not shown in the Library tab yet". Shipped PS1 handling via `game_library.MEDIA_TYPES["POPS"]` confirmed as the separate path.
- **Fix:** Either/or (surface or delete) is compliant; deletion is the LESS-NOT-MORE default if the Library-tab feature is unscheduled.

### RE-SERV-136 — VERIFIED
- **Citations:** `launcher/app_icon.py` is exactly 246 lines with `_GLYPHS` (`:17`), `_rgba_pixels` (`:165`), `_draw_square`/`_draw_text` (`:214,221`), `_ico_image` (`:129`), and the per-pixel `tk_photo` at `:91-113`; docstring: generated "so the source tree does not need binary assets". `launcher/assets/theme/LOGO.png` exists (602,983 bytes) and is used for the About tab at `launcher/gui.py:1523-1524`. Third source confirmed: `launcher/tray_linux.py:61-95` `_icon_image` prefers LOGO.png and falls back to a Pillow-drawn rounded-rectangle "PS2" badge.
- **Fix:** Directionally sound, with one understated cost: `app_icon.py` is deliberately **stdlib-only** (that's why the rasterizer exists). "Keep only `write_ico`'s ICO container fed from the shipped image" is not pure deletion — feeding LOGO.png into an ICO without Pillow means embedding the PNG payload directly in the ICO container (possible, but new code), or accepting a Pillow dependency the module currently avoids. Effort Med is honest; the fix text should name that trade.

### RE-SERV-137 — VERIFIED
- **Citations / Diff:** `launcher/library_index.py:109` `read_index` is the full implementation. `launcher/library_catalog.py:451-454`: `Catalog.indexed_games` body is a docstring plus `return read_index(self.path, root, max_entries=max_entries, cancel=cancel)` — pure pass-through. `launcher/game_library.py:288-296`: `Library.shared_index` adds exactly one behaviour, translating the missing-catalogue `FileNotFoundError` into the friendlier `ValueError`. Caller census recounted: `indexed_games`' one production caller is `library_panel.py:326`; `shared_index`'s two call sites are `library_gui.py:177,399`; tests call all three layers.
- **Fix:** Sound and net-negative (~13 lines, one layer). "One wrapper maximum" is the right bound.

### RE-SERV-138 — VERIFIED
- **Citations / Census (recounted):** `conformance/integration/http_probe.py` is 219 lines. Repo-wide grep for `http_probe` across `*.py/*.yml/*.md/*.toml/*.txt` returns **zero** references outside the file itself. Sibling wiring confirmed in `.github/workflows/ci.yml:109,112,117` (`opl_http`, `riptopl_http`, `neutrino_smb`) and `edge.yml:70,127` (`udpfs_probe`).
- **Fix:** Wire-or-delete is compliant; no third option is defensible for a probe.

### RE-SERV-139 — VERIFIED
- **Citations / Diff:** `grep -n "session_id = int.from_bytes" smb2_server/smb2_server.py` → exactly two hits, `:863` and `:915`, both `conn.session_id = int.from_bytes(os.urandom(8), "little") or 1`, each immediately under `if conn.session_id == 0:` — one in the NTLM NEGOTIATE/CHALLENGE branch, one in the AUTHENTICATE branch of `h_session_setup`. Verbatim, as filed.
- **Fix:** Sound; a single post-dispatch check (or `ensure_session_id()`) removes the pair with no behaviour change.

### RE-SERV-140 — VERIFIED
- **Citations / Diff:** Extracted `smbv1_server/smbserver_opl.py:1128-1154` (`_build_trans2_reply`) and `:1344-1362` (RAP branch of `h_transaction`) and compared line-by-line: same `base = 32 + 1 + 20 + 2`, same `(base + 3) & ~3` param offset, same pad1/pad2 arithmetic, same `struct.pack("<HHHHHHHHHBB", …)` 10-word envelope, same body assembly. The RAP copy is the same construction with `rparams`/`data` substituted. ~18 duplicated lines, as filed.
- **Fix:** Sound; `_build_trans2_reply` already takes exactly the parameters the RAP copy would pass.

### RE-SERV-141 — VERIFIED
- **Citations:** `Share.compressed_source` at `smbv1_server/smbserver_opl.py:303-336` and the scan inside `_list_dir` at `:1156-1198` both exist as described: listdir → stem match → best extension in `exts` order. Differences recounted from the bodies: `compressed_source` requires the name to end `.iso` with `len(base) > 4`, collects `by_ext` case-insensitively on extension but case-sensitively on stem, then re-resolves and re-checks containment (`_inside`) + `isfile`; `_list_dir` instead tracks `taken` (real `.iso` names) and picks `chosen[stem]` by `exts.index(...)` comparison, with no containment re-check. The shared core (folder scan, stem, preference order) is genuinely implemented twice, and the surrounding rules genuinely differ.
- **Fix:** Sound as scoped — extract only the scan, keep each caller's own extra check at the call site. Net saving is small but real, and the anti-disagreement benefit is the actual justification.

### RE-SERV-142 — VERIFIED
- **Citations:** `smbv1_server/smbserver_opl.py:489-505`: `alloc_fid`/`alloc_tid`/`alloc_sid` are the same two-line body (`self.next_X = (self.next_X + 1) & 0xFFFF or <floor>; return self.next_X`) with floors `0x1000`/`0x0001`/`0x0001`. Call sites assign without any in-use check: `conn.files[fid] = of` at `:827` and `:938`, `conn.trees[tid] = …` at `:778`-region, `conn.searches[sid] = …` at `:1251`. `cleanup()` (`:501-504`) closes only what remains in `conn.files`.
- **Mechanism / Execution (simulated the allocator arithmetic):** starting from `next_fid=0x1000` (`:406`), the FID cycle has 61,440 distinct values (`0x1001…0xFFFF`, then `0x1000` via the `or` on wrap) before repeating — matching the filed "~61k opens". On repeat, `conn.files[fid] = of` silently evicts a still-open `OpenFile`, which `cleanup()` can then never close: the handle leak follows mechanically from the cited code, exactly as the finding's INFERRED label states.
- **Fix:** Sound. One parameterised helper plus skip-if-present on FID allocation; note the same skip logic should apply to TID/SID dicts, which the fix text mentions only via "the same unchecked pattern" in the problem statement.

### RE-SERV-143 — VERIFIED
- **Citations:** `udpfs_server/ps2servers_core.py:523-578` `build_parser` and `:591-686` `main`; standalone parser+main inside `udpfs_server/udpfs_server.py:3441-3639` (`main` — there is no separate `build_parser` there, a trivial framing difference). Both define the same option set (ports, bind, sector size, read-only, verbose, compression group, cache size, data-port, single-port, peer-timeout, metrics, max-transfer, max-sessions) with differing help text and differing validations (e.g. Core validates `--peer-timeout` range and `--port` via `_parse_port`; the standalone clamps timeout and exits differently on bad paths).
- **Mechanism / Counts (recounted by AST):** the compression-precedence block is the same four steps in both (`ENABLE_COMPRESSION` env → `NO_COMPRESSION` → `args.enable_compression` → `args.no_compression`; Core `:601-608`, standalone `:3563-3575` region, differing only in quote style and one extra `args.enable_compression = enable_compression` line in the standalone). Inside Core's `main`, the Modulo construction (`:625-652`) and Auto construction (`:655-682`) share exactly **17 keyword-argument names** (16 with identical values, plus `single_port` present in both with different values), differing by class, `modulo_compat=True`, and Auto's `protocol_mode`/`fallback_interval` — the filed count is correct.
- **Fix:** The in-`main` half (one kwargs dict, construct once) is an unambiguous net win. The cross-file half is honestly presented with its own alternative (declare the standalone the frozen copy and stop treating the parsers as peers); either branch complies.

### RE-SERV-144 — VERIFIED-DRIFT
- **Citations:** `udpfs_server/ps2servers_core.py:360-383` (`_route_data_via`) and `:384-400` (`_handle_data` preamble) both exist and do duplicate: `Header.unpack(data)`, `struct.unpack("<I", data[2:6])[0]`, `header_words = (data_header >> 14) & 0xF`, `data_bytes = (data_header >> 18) & 0x3FFF`, `payload_size = header_words * 4 + data_bytes`. `super()._handle_data` is called at `:475`, and the base handler (`udpfs_server.py:1641-1655`) parses again.
- **Corrections:** (1) The **oversize check is not duplicated** — `if payload_size > len(data) - 6: return` appears only in `_route_data_via`; `_handle_data` computes `payload_size` only to test `> 0` in its profile-resolution branches. The filed sentence "and apply the same oversize check" is wrong for the second copy. (2) The base class's third parse is not the same shifts/masks code: it uses `DataHeader.unpack(data[2:6])` and `data_hdr.hdr_word_count * 4 + data_hdr.data_byte_count` — the same *computation*, a different implementation. So: two identical manual parses in Core (minus the oversize check), plus one structurally different parse in the base.
- **Fix:** Still sound for the Core pair (parse once, carry on the queued item); the saving is the ~8-line preamble, not the preamble-plus-check the text implies.

### RE-SERV-145 — VERIFIED-DRIFT
- **Citations:** Core `_attach_session_stats` at `udpfs_server/ps2servers_core.py:581-588` and the inlined copy in `smbv1_server/smbserver_opl.py:1748-1754` are, extracted side by side, the identical dance: same repo-root computation from `__file__`, same `os.path.isdir(…/launcher)` + `sys.path.append` guard, same lazy `from launcher.session_stats import SessionStats`, differing only in the key (`"udpfs"` vs `"smbv1"`). That core claim is exact.
- **Correction:** the parenthetical "(A third server, the standalone UDPFS `main`, does the same again.)" is **false**. `grep -n "session_summary|SessionStats" udpfs_server/udpfs_server.py` returns nothing in its `main` at all — the standalone has no `--session-summary` argument and no attach code (its only hit is a comment at `:634` describing the attribute Core sets). The other servers that attach (SMBv2 `:1789-1790`, HTTP `:1183`, UDPBD `:448-449`) do it in one or two lines *without* the root/`sys.path` dance, so the identical-snippet population is exactly two, as the main text (but not the parenthetical) says.
- **Fix:** Sound for the two real copies (one helper parameterised by key). Delete the parenthetical's premise from any follow-up.

### RE-SERV-146 — VERIFIED
- **Citations:** `udpfs_server/udpfs_server.py:390-479` `get_compressed_info`, including the CD correction at `:425-440` with the quoted "same predicate as the CHD wrapper … so the size reported here can never disagree" comment — verbatim in the code. `udpfs_server/compressed_iso/chd.py:262-303` `ChdFileWrapper._parse_header` implements the same predicate (`unit_size == 2448 or any CD codec`) and the same correction (`total_frames * 2048`, then `exact_cd_iso_size` override) — the CD correction exists exactly **twice**, as filed. `cso.py:54-89` and `zso.py:64-107` wrapper parses duplicate the probe's magic/size/block extraction for CSO/ZSO. `limits.py:19-116` parses the same headers a third time (`indexed_header`, `chd_header`).
- **Mechanism nuance (does not change the verdict):** the third parse is not fully independent in the serving path — the wrappers, in `_strict` mode, *delegate* to `limits` (`indexed_header(self, header)` / `chd_header(header)`). `limits.py` is the opt-in inspection implementation; the duplication that is load-bearing by hand is probe ↔ wrapper, exactly where the finding puts the weight.
- **Fix:** Sound; the probe-from-wrapper variant must keep the probe allocation-light, which the fix text already stipulates.

### RE-SERV-147 — VERIFIED
- **Citations:** Pre-check at `udpbd_server/udpbd_server.py:208-209` (`is_raw and sector_nr + sector_count > self.bd.sector_count()` → `EINVAL`), followed at `:219-222` by `self.bd.seek(sector_nr, sector_count)` for raw backends. Census of `is_raw`: exactly two backends set it — `launcher/raw_storage.py:18` `RawDevice` and `launcher/virtual_exfat.py:64` `VirtualExfat`. Both enforce the same bound in `seek`: `RawDevice.seek` (`raw_storage.py:37-45`) raises `EINVAL` when `position + sector_count*512` exceeds the device size; `VirtualExfat.seek` (`virtual_exfat.py:228-233`) raises `EINVAL` when the request end exceeds its size. The write path (`udpbd_server.py:250-255`) has no pre-check and relies on `seek` raising, converting it to a `-1` reply — as filed.
- **Fix:** Sound; deleting lines 208-209 changes nothing observable for either raw backend (same exception type from the same call a few lines later).

### RE-SERV-148 — VERIFIED-DRIFT
- **Citations:** `nfs4_server/nfs4_server.py:880-884` (`_op_open_confirm`) and `:886-890` (`_op_close`), ops-table entries at `:368,371` — locations exact.
- **Correction — NOT byte-identical:** extracted bodies differ in the order of the first two statements:
  - `_op_open_confirm`: `stateid = r.fixed(16)` **then** `r.u32()`
  - `_op_close`: `r.u32()` **then** `stateid = r.fixed(16)`
  The remaining three lines (`self._need(s.cfh)` and the seqid-bump return) are identical. The transposition is not drift — it is required: OPEN_CONFIRM's wire order is stateid-then-seqid, CLOSE's is seqid-then-stateid. "Byte-identical bodies" and "the same five lines twice" are both wrong (the bodies are four lines, one pair transposed).
- **Fix:** Overstated as filed. A shared helper can only own the common *tail* (`_need` + bumped-stateid return, 2 lines) once each caller has parsed its two fields in wire order — a saving of ~2 lines, not ~5, and the helper signature must take the already-parsed `stateid`. The underlying observation (near-identical ops that must change together) stands.

### RE-SERV-149 — VERIFIED
- **Citations / Diff (executed):** extracted `http_server/http_server.py:1220-1237` and `nfs4_server/nfs4_server.py:1101-1113` and diffed: the executable code of `_stop_on_sigterm` is **identical**; the only difference is the 5-line docstring present in the HTTP copy and absent in the NFS copy — exactly the filed "identical code, already drifting in the small". Both servers' outside-directory imports confirmed (HTTP imports `launcher.session_stats` at `:47`; NFS inserts `smb2_server` into `sys.path` at `:40-43`), so the "standalone file" rebuttal holds.
- **Fix:** Sound (~13 lines removed, one home for the platform caveats). See the cross-check note: this fix and RE-SERV-157's fix should be executed once, together.

### RE-SERV-150 — VERIFIED
- **Citations:** Go, `native/ps2servers-edge/internal/compression/image.go`: `openImage` extent check at `:198-199` and `SizeOf`'s at `:330-331` — extracted both: `blocks := (size + block - 1) / block` (resp. `h.size`/`h.block`) followed by `if blocks > 1<<28 || uint64(headerSize)+(blocks+1)*4 > uint64(fileSize)` with the **identical** error string `"image index too large or extends past file size"` in both. `parseHeader`'s anti-drift comment at `:238-241` is verbatim as quoted, and it indeed covers only the 24-byte prologue.
- **Fix:** Sound; extracting the block-count/extent check is a small net deletion and completes the invariant `parseHeader`'s comment already claims.

### RE-SERV-151 — VERIFIED
- **Citations:** `parseCHDHeader` at `internal/compression/chd.go:31-95` and the header half of `readCDTrackTableOpt` at `internal/compression/chd_cuebin.go:193-230`: both open the file, read `chdV5HeaderBytes` (= **124**, `chd.go:15`), check magic `"MComprHD"`, version 5 and header size 124, and decode logical (`[32:40]`), hunk (`[56:60]`) and unit (`[60:64]`). Validation divergence confirmed: the track-table parser requires `logical % 2448 == 0` and `unit == 2448` (`logical%cdFrameBytes != 0` / `unit != cdFrameBytes` → error); `parseCHDHeader` requires neither and derives CD-ness from `unit == 2448` **or** any of the three CD codec IDs. And `parseCHDHeader` does call `exactCDISOSize` (`chd.go:92`), which re-opens the file and runs `readCDTrackTableOpt` (`chd.go:104`) — the double-parse is on one call path, not just in the codebase.
- **Fix:** Sound (one raw-header struct, per-caller extra constraints); net shrink plausible at Effort M.

### RE-SERV-152 — VERIFIED
- **Citations:** `itoa` at `internal/smb/server.go:244-256` (13 lines), sole caller at `:166` (`net.JoinHostPort(s.cfg.Bind, itoa(s.cfg.Port))`) — grep for `itoa(` returns exactly those two sites. Negative-input behaviour as filed: for `n < 0` the `for n > 0` loop never runs and the function returns `""`, where `strconv.Itoa` returns `"-…"`. The caller's value is range-checked upstream (`server.go:130`: `cfg.Port < 1 || cfg.Port > 65535` rejected), and the hand-sized `[8]byte` buffer is adequate only because of that check — all as filed.
- **Fix:** Sound; `strconv.Itoa` at the one call site is a pure deletion.

### RE-SERV-153 — VERIFIED
- **Citations / Diff:** `internal/smb/server.go:425-447`: `allocFID`/`allocTID`/`allocSID` extracted — identical increment-and-wrap bodies (`c.nextX++; if c.nextX == 0 { c.nextX = <wrap> }; return c.nextX`) differing only in the field and the wrap value (`0x1000` vs `0x0001`). The parenthetical is also correct: none of the three checks whether the wrapped ID is still in use.
- **Fix:** Sound (one helper parameterised by counter + wrap, or a small allocator type); net shrink.
- **Cross-reference:** this is the Go counterpart of RE-SERV-142's Python allocators — same pattern, different codebase and files; not a double-filing.

### RE-SERV-154 — VERIFIED
- **Citations / Count (recounted):** `grep -c 'val == "1" || val == "true"' internal/webui/config_uci.go` = **16**, at lines 63,79,81,93,95,103,109,115,125,133,135,139,149,157,159,163 (all inside `uciBackend.Load`, `:63-163`). `uciBool` at `:14-22` accepts `1/on/true/yes/enabled` case-insensitively and its only use in `Load` is at `:89` for `main.udp_batch` (its other references are tests). `Save` writing only `1`/`0` is consistent with the masking claim.
- **Fix:** Exemplary LESS-NOT-MORE: the helper already exists and is already tested; replacing the 16 inline tests is pure deletion of repeated logic. The resulting semantics change (accepting `on/yes/enabled` for all fields) is the finding's stated intent, not a side effect.

### RE-SERV-155 — VERIFIED
- **Citations / Counts (recounted by grep on `cmd/ps2servers-edge/main.go`):** `flag.NewFlagSet` = **4**; `"log-format"` definitions = **4** (`:161,304,365,489`); `--log-format` validations = **3** (`:194,322,381` — `runWebUI`, whose flag is at `:489`, has none, exactly as filed); `signal.NotifyContext` = **4** (`:247,335,431,541`); `edgelog.New` = **4** (`:241,325,384,518`). Logger/signal blocks at the cited ranges confirmed.
- **Fix:** Sound and self-justifying under the audit's own rule: identical logic in 4 places, drift already produced a behavioural bug (the missing webui validation), net line count goes down.

### RE-SERV-156 — VERIFIED-DRIFT
- **Citations:** SMBv1 `_take_445` at `smbv1_server/smbserver_opl.py:1546-1628`; SMBv2 `take_445` at `smb2_server/smb2_server.py:1479-1652` plus `listen_after_take_445` at `:1653`. Both stop LanmanServer, wait for Stopped, restore on exit. The absolute-PowerShell resolution is triplicated as filed: `launcher/windows_setup.py:57-71` (`_powershell_executable`), `smbserver_opl.py:1553-1560`, `smb2_server.py:1496-1502` — the two server copies are near-verbatim.
- **Correction (minor):** "the SMBv1 copy lacks foreign-dependent checks" overstates the gap. The SMBv1 copy *does* query srvnet's dependent services (`(Get-Service srvnet …).DependentServices.Name`) and names the running pin-holder before bailing when 445 stays bound. What it lacks is what SMBv2 added on top: **pausing** the srv/srv2/srvnet drivers (in dependency order, `_TAKE_445_SERVICES` at `smb2_server.py:1463`) and the `foreign_dependents()` gate on LanmanServer itself before pausing anything. The drift and the risk asymmetry are real; the SMBv1 copy is less primitive than the text implies.
- **Fix:** Sound in direction (one shared module, SMBv2 behaviour as the single behaviour; the cross-directory import precedent cited is real). Effort L is honest given this is the riskiest code in either server.

### RE-SERV-157 — VERIFIED
- **Citations:** `launcher/serve.py:79-102` `install_stop_handlers`, called at `serve.py:158` for every `--serve` child before the server module is loaded; it installs handlers for both SIGTERM and SIGBREAK (`_stop_like_ctrl_c`). HTTP calls its own `_stop_on_sigterm()` in `main` (`http_server.py:1203`, def `:1220`) and NFS likewise (`nfs4_server.py:1091`, def `:1101`); `signal.signal(SIGTERM, …)` replaces the serve.py-installed SIGTERM handler, while serve.py's SIGBREAK handler survives — so the effective handler set genuinely differs by entry point, as filed.
- **Fix:** Sound under either branch. **Overlap note:** the HTTP/NFS limbs of this finding rest on the same two function bodies as RE-SERV-149. The two findings are distinct claims (149: the two server copies duplicate *each other*; 157: in launcher mode they redundantly *re-install* what serve.py already installed), but they should be cross-referenced and fixed once — a single shared installer imported by both servers satisfies both.

### RE-SERV-158 — VERIFIED
- **Citations:** `launcher/process.py:19` `STOP_PIPE_ENV = "PS2SERVERS_STOP_PIPE"` (producer; set at `:59`, popped at `:61`) and `launcher/serve.py:72` `STOP_PIPE_ENV = "PS2SERVERS_STOP_PIPE"  # launcher/process.py sets it` (consumer; popped at `:105`). Exactly two definitions repo-wide, identical today, independently editable — as filed. serve.py already imports from the package (`from .servers import REGISTRY` in the serve path), so the shared-definition cost claim holds.
- **Fix:** Sound; one definition, imported.

### RE-SERV-159 — VERIFIED
- **Citations / Census (recounted):** `grep -rn "def _parse_port"` repo-wide returns exactly **3** definitions: `launcher/windows_setup.py:115-121` (unparseable/empty → caller-supplied `default`; `int(str(value), 0)`), `launcher/status_client.py:68-75` (unparseable/empty/`False` → `0`; also `int(str(port).strip(), 0)`), `udpfs_server/udpfs_server.py:3378-3383` (unparseable or out-of-range → raises `ValueError`; range `0-65535` checked). Three failure semantics — fall back, give up, fail hard — exactly as filed.
- **Fix:** Sound as scoped (one launcher parser with an explicit `default`; the UDPFS raising variant kept but renamed/commented as the strict CLI parser). Note it deliberately does *not* force one semantics on the server — compliant with LESS-NOT-MORE.

### RE-SERV-160 — VERIFIED-DRIFT
- **Citations:** All cited functions exist: `launcher/netinfo.py:28-41` `_parse_linux_ip_addr`, `:44-60` `_parse_macos_ifconfig` (returns `list[str]`), `launcher/directlink.py:356` `_parse_linux_adapters`, `:460-476` `_parse_macos_ifconfig` (returns `(status, [{ip, prefix, origin}])` — same name, different signature and return, confirmed by extraction). The same-name collision is real and is the strongest part of the finding.
- **Correction — the count "four times" is imprecise in both directions:** netinfo's `get_all_adapters_info` (`:139-…`) contains **two** inline re-parses (Linux branch `:172-183`, macOS branch `:185-198`), not one — so the site count is 2 helpers + 2 inline branches + 2 directlink functions = **6 parse sites / 5 distinct functions**. Conversely, directlink's Linux parser is *not* another copy of the inet-line grammar: it parses `ip -j` **JSON** (`json.loads(addr_json)`), a different input format that cannot share the text parsers. The genuinely shared-grammar population is: netinfo's two text helpers, netinfo's two inline branches, and the macOS pair across files. The inline branches have also drifted as filed (they add `127.`/`169.254.` filtering the helpers don't do).
- **Fix:** Half sound: making `get_all_adapters_info` build on netinfo's own helpers (extended to carry the interface name) and renaming directlink's macOS parser are both clean wins. Any version of the fix that tries to unify directlink's JSON parser with the text parsers would not be — the finding's fix text, to its credit, does not propose that.

---

## Cross-checks within the range (same-mechanism pairs)

- **RE-SERV-149 ↔ RE-SERV-157 — overlapping, cross-reference required.** Same two `_stop_on_sigterm` bodies; 149 claims HTTP↔NFS duplication, 157 claims triple installation (serve.py + both servers). Distinct angles, one fix. Neither is a pure duplicate of the other, but filing/fixing them independently risks two different "single homes" for the same function.
- **RE-SERV-131 ↔ RE-SERV-134 — adjacent, not duplicate.** Both are GUI monkeypatching, and both ultimately wrap `LauncherApp._build` (main.py's `launcher_build` and `__init__.py`'s `build_with_addons` stack on the same method), but the bodies, files and mechanisms (entry-point shim vs import-hook + skin patchers) are disjoint.
- **RE-SERV-142 ↔ RE-SERV-153 — same pattern, different codebases** (Python SMBv1 vs Go edge SMB). Not a double-filing.
- **RE-SERV-129 ↔ RE-SERV-145 — complementary** (NFS missing the session-stats feature; the attach snippet duplicated among servers that have it). No overlap in bodies.
- **RE-SERV-146 ↔ RE-SERV-150/151 — same theme** (compressed-header parsing in multiple places) **in different languages/files** (Python probe/wrappers/limits vs Go `image.go`/`chd.go`). No shared bodies.

## Fix-sanity / LESS-NOT-MORE summary

Fixes that are pure deletion or use an already-existing helper, fully compliant: 134, 137, 139, 140, 147, 149, 152, 153, 154, 155, 158. Fixes compliant as either/or (wire-or-delete / keep-or-document): 129, 132, 135, 138, 143, 157. Fixes whose stated saving is overstated: 144 (no duplicated oversize check to remove), 148 (~2 lines, not ~5). Fix that is **invalid because its premise is refuted**: 128. Fix with an understated dependency cost: 136 (stdlib-only constraint).

## Tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 27 | 127, 129, 130, 131, 132, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 146, 147, 149, 150, 151, 152, 153, 154, 155, 157, 158, 159 |
| VERIFIED-DRIFT | 5 | 144, 145, 148, 156, 160 |
| WEAKENED | 1 | 133 |
| REFUTED | 1 | 128 |
| BLOCKED-ENV | 0 | — |
| **Total** | **34** | RE-SERV-127 … RE-SERV-160 |

## CANDIDATES (new defects, separate from the findings above)

None confirmed. Two observations that did not rise to candidate defects:

1. `smb2_srvsvc.SrvsvcPipe.transact` slices `data[16:frag_len]` and silently discards any bytes past `frag_len` in the same WRITE, so two PDUs coalesced into one WRITE lose the second — noted inside RE-SERV-127's fix bullet as a constraint on the proposed buffering fix, not filed separately because it is the same transport-completeness mechanism.
2. `launcher/ra_account_worker.py:302` — `begin_login` constructs and discards an `AccountTask(1, 1, "login", …)` before calling `logout()` and minting the real task. It reads as an eager-validation probe (the discarded construction runs `AccountTask.__post_init__` before the session is torn down), so it is plausibly intentional; without a failing case it is not filed as a defect.
