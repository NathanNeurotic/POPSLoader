# Verification Batch C — RE-SERV-046 … RE-SERV-070 (PS2-Servers, blind redo)

- **Pin confirmation:** `git -C ~/workspace/audit-clones-2026-11-13/PS2-Servers rev-parse HEAD` → `c5f021c4d38698860f56b03498adc261dbb8d8dd` — matches the assigned pin exactly. All reading was in that clone (read-only); all executions were in `/tmp/verifyC/` copies.
- **Method:** refute-first — every cited file/function/string grepped and opened, defeating guards/callers/tests hunted first, then direct probes where mandated/feasible.
- **Environment note:** 32-bit (GOARCH=386) Go binaries cannot run in this sandbox at all (a trivial 386 test also dies with `signal: trace/breakpoint trap`); that affects only the *execution* leg of RE-SERV-068, whose mechanism is re-derived arithmetically with a 64-bit control probe (see there). No finding in this batch failed only because of the UDP `sendto` block.

---

### RE-SERV-046 — VERIFIED
- **Citations:** Go `native/ps2servers-edge/internal/smb/handlers.go` `transaction` (filed 840-871, actual function starts ~841) and `server.go:740-741` (`case ComTransaction: return c.transaction(r)`); Python `smbv1_server/smbserver_opl.py:1331ff` `h_transaction`. All exist.
- **Mechanism:** Re-derived both. Go: `transaction(r *req)` never touches `r.params`/`r.data`; it sorts share names and unconditionally builds the level-1 NetShareEnum reply via `trans2Reply`. Python: `h_transaction(conn, r)` never reads `r` beyond the signature; unconditionally returns `STATUS_SUCCESS` with the share-enumeration body. No guard, caller pre-filter, or test anywhere in either dispatch path discriminates by transaction name/RAP function. Defeating-evidence hunt: none found.
- **Execution:** n/a (READ mechanism is unambiguous; both handlers are pure functions of the share list).
- **Fix:** Sane, LESS-NOT-MORE compliant — parse-and-refuse (`StatusNotImplemented`) is the server's own pattern for other unimplemented commands. This RE number is itself the consolidation of the Go (GOPROTO-17) and Python (PYSMB1-08) filings of the *same mechanism in parallel implementations* — correctly merged, not a duplicate pair of RE numbers.

### RE-SERV-047 — VERIFIED
- **Citations:** `internal/webui/api.go` `sanitizeSSE` (~62-70, with the filenames/peer-addresses rationale comment verbatim), sanitised service-log and backlog emits, unsanitised live emit. All exist.
- **Mechanism:** The live loop is literally `fmt.Fprintf(w, "data: %s\n\n", line)` on the subscription channel line, while the two sibling emits in the same `HandleLogs` pass through `sanitizeSSE(line)`. Live lines come from the same `LogBuffer`. No downstream sanitisation exists.
- **Execution:** n/a.
- **Fix:** One call-site change to `sanitizeSSE(line)` — minimal, no new mechanism. Correct.

### RE-SERV-048 — VERIFIED
- **Citations:** `launcher/raw_storage.py:358` `argv = ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", ...]`, `creationflags`-equivalent `flags = 0x08000000`; hardened pattern at `launcher/windows_setup.py:57-90` (`_powershell_executable`, hijacking docstring verbatim) and copies at `smbv1_server/smbserver_opl.py:1553-1563`, `smb2_server/smb2_server.py:1496-1502`. All exist.
- **Mechanism:** My own census grep for `powershell` across `launcher/`, `smbv1_server/`, `smb2_server/`: exactly 3 absolute-path resolutions (windows_setup, smbv1, smb2) and exactly 1 bare-name invocation (`raw_storage.py:358`). (`launcher/directlink.py` calls the imported `_powershell` helper — not a fourth resolution.) Minor non-defeating nuance: the hardened resolvers themselves fall back to the bare name if the System32 file is absent; `raw_storage` uses the bare name unconditionally, which is the filed defect.
- **Execution:** n/a (Windows-only path, READ).
- **Fix:** Reuse `windows_setup._powershell`/its resolver — sane, removes the hand-rolled flag too.

### RE-SERV-049 — VERIFIED
- **Citations:** `launcher/ra_web.py:385-390` `container.innerHTML = achievements.map(a => \`…${a.title …}…${a.description …}…${a.points …}\`)`. Exists verbatim.
- **Mechanism:** Every other text assignment in the same `render()` uses `textContent` (grep: lines 326-375, including the unlock banner at 375); only the achievements list uses `innerHTML` with unescaped interpolation. Data flow confirmed: `launcher/achievements.py:200-215` builds `achievements_data` (title from `res.qualified.metadata`, i.e. remote patch/RA data) and passes it via `RAState.set_game` (`ra_web.py:72-79`) into `state.achievements`, which `render()` consumes. No escaping helper exists in the file. Same-origin `/logout` POST handler is at the bottom of the same script.
- **Execution:** n/a.
- **Fix:** `textContent`/`createElement` rows like the rest of `render()` — sane, aligns with the file's own pattern.

### RE-SERV-050 — VERIFIED
- **Citations:** `launcher/caduceus.py` `Account.request` (~117-123): `params.update(y=key)`, URL built as `…/API/<endpoint>.php?` + `urlencode(params)`, key from `read_secret(self.profile / "apikey")`; `read_secret` at 55-90. All exist.
- **Mechanism:** The Web API key is in the GET query string on every `Account.request` call (all endpoints, incl. `API_GetUserCompletionProgress` at line 333). Mitigation noted in the finding is real: `open_remote` uses the `NoRedirect` opener (caduceus.py:26-32), so the `Referer`-on-redirect leak is closed, but proxy/history/crash-report URL logging is not. Contrast files exist (`ra_credentials.py:1-5` "never stores … Web API keys"; `ra_resolver_process.py` "No credentials go on argv").
- **Execution:** n/a.
- **Fix:** Correctly conditional as filed ("where the RA API accepts it, POST; where it does not, document") — the RA Web API is GET-oriented, so the documentation half may be the only implementable half. That caveat is already in the finding; it does not weaken the exposure claim.

### RE-SERV-051 — VERIFIED
- **Citations:** `launcher/caduceus.py:329-356` `Bridge.progress`. Exists.
- **Mechanism:** `game_id, earned, maximum = 0, 0, 0` at entry; the `kind == "G"` branch fills `total` and per-row `earned`/`total` but never assigns the header `earned`/`maximum`; the `else` ("A") branch does (`maximum, earned = len(rows), sum(...)` before slicing). Reply body at ~368 formats `kind, page, total, game_id, earned, maximum, …` from those zeros. So every library ("G") reply header is 0/0 while its rows are correct — exactly as filed.
- **Execution:** n/a (pure code path, no branch recomputes the header).
- **Fix:** Direction right, one sanity caveat the finding understates: the "G" branch fetches only one page (`o=page*3, c=3`, `Results[:3]`), so "sum of row earned/MaxPossible" would be *page-local*, not library-wide. A fully correct fix needs aggregation over all pages (or an API aggregate field); a page-local sum is better than 0/0 but must not be labelled library progress. Defect itself unaffected.

### RE-SERV-052 — VERIFIED
- **Citations:** `.github/workflows/edge-build.yml` generated `WHICH-DEVICE.txt` block; `native/ps2servers-edge/cmd/ps2servers-edge/main.go:150` (and 301, 359). All exist.
- **Mechanism:** Workflow text (my read, ~lines 387-397): `Access : read-only by default. Pass --read-only=false to allow the console to write (saves).` followed by a Quick Start running `udpfs --root …` with no `--read-only`. Binary source: all three subcommands use `fs.Bool("read-only", envBool("RO", false), "serve files read-only; omit to allow the console to write saves")` with an explicit comment "Writable by default, matching the Desktop/Core server". Docs agree with the binary, not the archive text: `docs/EDGE.md:22` ("writes are allowed by default"), `docs/EDITIONS.md:39`, `docs/INSTRUCTIONS.md:16-17`. `grep -rn WHICH-DEVICE tests/` returns nothing (rc=1) — no test guards the text.
- **Execution (mine, mandated re-execution):** Built in `/tmp/verifyC/edge` with Go 1.27.4 (`~/workspace/tools/go1.27.4/bin`): **binary size 11,366,917 bytes**. `/tmp/verifyC/ps2servers-edge udpfs -h` lists `-read-only` as a plain bool flag with help text "serve files read-only; omit to allow the console to write saves" and **no default-true** (Go prints no `(default true)`); `smb -h` and `udpbd -h` likewise show bare `-read-only` flags. Actual default for all three: **writable**. Claim vs behaviour compared directly: the shipped text is false, the binary is writable by default.
- **Fix:** Rewrite the generated block to match EDGE.md's wording — sane, text-only, LESS-NOT-MORE exemplary.

### RE-SERV-053 — VERIFIED
- **Citations:** Filed as `smb2_crypto.py:227-232`; actual path `smb2_server/smb2_crypto.py`, the `_bcrypt_cmac` self-test at ~227-232: `if cmac(bytes(16), b"") != bytes.fromhex("66e94bd4ef8a2c3b884cfa59ca342b2e") and aes_cmac_pure(bytes(16), b"") != cmac(bytes(16), b""): return None`. Exists verbatim.
- **Mechanism:** The condition is an `and`: a *correct* bcrypt backend fails clause 1 (its CMAC ≠ the constant) but passes clause 2 (pure == bcrypt), so the backend is accepted only via the fallback comparison — the hardcoded clause can never be true for a correct backend.
- **Execution (mine, mandated):** On the `/tmp` copy — `AES128(bytes(16)).encrypt_block(bytes(16)).hex()` = **`66e94bd4ef8a2c3b884cfa59ca342b2e`** (i.e. the filed constant is exactly AES-128(zero key, zero block) = the RFC 4493 §2.3 *L* block); `aes_cmac_pure(bytes(16), b"").hex()` = **`4387c14b46ef7e176dceefa862d72ff9`**, and the OpenSSL backend (`_openssl_cmac()(bytes(16), b"")`) independently returns the identical `4387c14b…f9`. Both filed values reproduced exactly.
- **Fix:** Replace the constant with `4387c14b46ef7e176dceefa862d72ff9` or drop the hardcoded clause and keep only the pure-comparison the OpenSSL path already uses — sane; the second option is the LESS-NOT-MORE one.

### RE-SERV-054 — VERIFIED
- **Citations:** Filed as `smb2_paths.py:70-102`, `part[-1]` at :97; actual path `smb2_server/smb2_paths.py`, `check_component` at ~70-102, trailing-dot/space test `if part[-1] in (".", " "):` confirmed. Docstring: "Raises PathError" / "Separate from Share.resolve so a server that walks a directory (the NFS server's READDIR)…". `Share.resolve` skips `part in ("", ".")` before calling it (~148-150). All as filed.
- **Mechanism:** Empty string passes the length, stream-separator, illegal-char, and reserved-name tests, then `part[-1]` raises `IndexError`, breaking the documented `except PathError` contract for any direct reuser.
- **Execution (mine):** `check_component("")` on the `/tmp` copy → **`IndexError: string index out of range`** (not `PathError`). Reproduced exactly.
- **Fix:** Empty-component `PathError` at the top — one guard, sane.

### RE-SERV-055 — VERIFIED
- **Citations:** `smbv1_server/smbserver_opl.py` `h_create_directory` (~1070-1096, comment "carries BufferFormat=0x04…" and strip `r.data[1:] if r.data[:1] == b"\x04"`) and `h_check_directory` (~1098-1110, decodes from byte 0, no strip). Both exist.
- **Mechanism:** `Share.resolve` treats the leading `\x04` as a literal first path component, so a spec-formed name resolves to a nonexistent `<root>/\x04DVD` path.
- **Execution (mine):** Drove the real handler on the `/tmp` copy against a share containing `DVD/`: plain `b"DVD\x00"` → `STATUS_SUCCESS` (0x00000000); spec-formed `b"\x04DVD\x00"` → **`STATUS_OBJECT_NAME_NOT_FOUND` (0xC0000034)**. Reproduced exactly as filed.
- **Fix:** Strip a leading `0x04` exactly as `h_create_directory` does — sane, symmetric.

### RE-SERV-056 — VERIFIED
- **Citations:** `smbv1_server/smbserver_opl.py:640-695` `h_negotiate`: `try: idx = dialects.index("NT LM 0.12") / except ValueError: idx = 0`, then unconditional `STATUS_SUCCESS` NT LM 0.12 response. Exists verbatim.
- **Mechanism:** No "no dialect chosen" (0xFFFF) or error path exists for the SMB1 branch (the SMB2 multi-protocol branch above it does return early only when an SMB2 dialect *is* found).
- **Execution (mine):** Drove the real handler: dialect list `["PC NETWORK PROGRAM 1.0"]` → **success, DialectIndex 0**; empty list → success, DialectIndex 0; `["NT LM 0.12"]` → success, DialectIndex 0 (correct there). Reproduced.
- **Fix:** Error status / 0xFFFF when "NT LM 0.12" is absent — sane.

### RE-SERV-057 — VERIFIED
- **Citations:** `udpfs_server/ps2servers_core.py:477-521` `AutoUdpfsServer.run()`; `udpfs_server/ps2servers_core.py:195-220` `_send_specific` (re-raises `OSError` on INFORM, deliberate, with the verbose-log comment); base `udpfs_server/udpfs_server.py:1048-1112` `run()`. All exist.
- **Mechanism:** Base loop calls `_handle_discovery`/`_route_data` *inside* the per-socket `try: … except OSError: pass`. Core's override restructures: `recvfrom` in its own narrow `try/except OSError: continue`, header parse in another, then `self._handle_discovery(data, addr)` / `self._route_data_via(...)` **unguarded**, inside a `while` whose only handler is `except KeyboardInterrupt`. `_handle_discovery` sends INFORMs via `_canonical_inform` → `_send_specific`, which re-raises `OSError`. One failed INFORM send therefore propagates out of `run()` and kills the server. (Scope is in fact slightly broader than filed: `_sweep_idle_sessions()`/`_emit_metrics()` are equally unguarded in Core's loop — same fix covers them.)
- **Execution:** n/a — correctly not claimed by the finding; a live send failure in this sandbox would be BLOCKED-ENV, not evidence. READ mechanism is complete.
- **Fix:** Per-datagram `except OSError: continue` around dispatch, mirroring the base — sane.

### RE-SERV-058 — VERIFIED
- **Citations:** `udpfs_server/ps2servers_core.py:529-543` (`_env_int` defaults for `--port`/`--sector-size`/`--compression-cache-size`), :566-567 (`_env_float` for `--tx-delay-ms`); definitions at `udpfs_server/udpfs_server.py:3297-3312` (`return int(v, 0) if v else default` / `return float(v) if v else default`, no guard). Neighbouring `_env_duration`/`_env_max_transfer`/`_env_max_sessions` exist lines away and are built never to raise. All as filed.
- **Mechanism:** The defaults are evaluated at `build_parser()` construction time, so a bad env value raises before argparse exists to format a usage error.
- **Execution (mine):** `PORT=oops` → `build_parser()` raises **`ValueError: invalid literal for int() with base 0: 'oops'`**; `TX_DELAY_MS=oops` → **`ValueError: could not convert string to float: 'oops'`**. Both reproduced. (`SECTOR_SIZE`/`COMPRESSION_CACHE_SIZE` share the identical helper — READ, as filed.)
- **Fix:** Warn-and-fall-back in the two helpers (fixes both entry points) — sane, matches the file's own standard.

### RE-SERV-059 — WEAKENED
- **Citations:** `udpfs_server/ps2servers_core.py:548-550` (`default=os.environ.get("PROTOCOL_MODE", "auto").lower()` on a `choices=` argument), :105-112 (`AutoUdpfsServer.__init__` validation), :591-690 (`main()`, construction unguarded); launcher alias table at `launcher/servers.py` (`_PROTOCOL_MODE_BY_NAME`, `"proper" → "standard"` at line 268, `protocol_mode_value` strips+lowercases and maps). All exist.
- **Mechanism — true part (executed by me):** `PROTOCOL_MODE=proper`: `build_parser().parse_args([])` succeeds with `protocol_mode='proper'` (argparse does not validate a *default* against `choices`), and constructing `AutoUdpfsServer(protocol_mode='proper')` raises **`ValueError: protocol_mode must be auto, standard, or modulo`**, which `main()` (source read in full) does not catch around construction. Legacy/unknown values from the environment do detonate as a traceback. Core defect stands.
- **Mechanism — false sub-claim (executed by me, defeating evidence):** The finding states "A trailing space (`PROTOCOL_MODE="modulo "`) fails the same way." It does not. `AutoUdpfsServer.__init__` normalises with `(protocol_mode or "auto").strip().lower()` (line 109) — I constructed the server with `"modulo "`, `" modulo"`, `"MODULO"`, and `"Standard"` and **all constructed without error**; only unmapped values (`"proper"`) raised. Whitespace/casing variants are already saved by the constructor's strip+lower, even though the parser default itself only lowercases. (The one wrinkle — `main()`'s exact-match `args.protocol_mode == PROFILE_MODULO` fast path is bypassed by `"modulo "` — is harmless: the Auto path then applies modulo itself, including `single_port`.)
- **True scope:** Only values that are not, after strip+lower, one of auto/standard/modulo — i.e. legacy aliases like `proper` and outright garbage — slip past argparse and raise the uncaught `ValueError`. Whitespace and case variants do not fail.
- **Fix:** Still sane in reduced form: map the env default through the launcher's existing alias table / `parser.error` on unrecognised values. The filed "normalise the same way `__init__` does (strip + lower)" half is already done by `__init__` and would change nothing.

### RE-SERV-060 — VERIFIED
- **Citations:** `udpfs_server/compressed_iso/zso.py:165-171` retry loop (`while compressed_data: … compressed_data = compressed_data[:-1]`); contrast `limits.py:78-90` `indexed_block` (caps padding at `(1 << align) - 1`, comment "Never retry once per byte of an attacker-controlled, potentially megabyte-sized span"). Both exist; serving path is non-strict by default (`open_compressed` in `udpfs_server.py:379` constructs the wrapper with no `strict=`).
- **Mechanism:** Unbounded one-byte-at-a-time retry; cost is attempts × shrinking-input decompression.
- **Execution (mine):** Built a minimal valid-header ZSO in `/tmp` with one 20,000-byte garbage (`0xFF`) block and a counting `lz4.block.decompress` wrapper: **`ValueError` after 20,000 attempts in 0.52 s**. Filed: 19,990 attempts in 0.48 s for its garbage block — the small count difference is input-dependent (garbage content), not a mechanism difference; magnitude and timing match.
- **Fix:** Bound retries to `(1 << align) - 1` exactly as `indexed_block` does — sane, already the in-tree pattern.

### RE-SERV-061 — VERIFIED
- **Citations:** `udpfs_server/compressed_iso/cso.py:115-150`, `zso.py:125-163`, `base.py:53-97`. All exist; serving wrappers are constructed non-strict (see RE-SERV-060), and the strict `limits.indexed_block` path does validate span/decoded length — the contrast is real.
- **Mechanism:** Re-derived all three sub-defects. (1) CSO: for compressed blocks `read_size = next_offset - offset` with no sign/span check — a non-monotonic table makes it negative and `self.file.read(negative)` reads to EOF; ZSO's `compressed_size = next_offset - offset` is the same arithmetic. (2) CSO pads *any* short inflate to `block_size` unconditionally (`if len(decompressed) < self.block_size: decompressed += b"\x00" * …`), not only for the final block. (3) ZSO uncompressed branch `return compressed_data` however short, and `base.read()` does `result.extend(block_data[block_offset:block_offset + read_size]); self.pos += read_size` — position advances by the requested `read_size`, not by the bytes actually appended, so a short block both short-serves and skips.
- **Execution:** n/a (filed READ/Med; each sub-mechanism follows directly from the quoted lines and Python's documented `read(-n)` semantics).
- **Fix:** Refuse negative/overspanning `read_size`, raise on short non-final blocks, advance `pos` by bytes appended — sane, mirrors the strict path's invariants.

### RE-SERV-062 — VERIFIED
- **Citations:** `udpfs_server/udpfs_server.py:1563-1567` `_status_flags`; `udpfs_server/router_status.py:66-76` flag definitions (`FLAG_UDPBD = 1<<1`, `FLAG_DECOMPRESSES = 1<<4`). Exist.
- **Mechanism:** Full-repo grep: `_status_flags` is defined exactly once and `FLAG_UDPBD`/`FLAG_DECOMPRESSES` are referenced *nowhere* outside their definitions — no Core override sets them either. `_status_flags()` returns `FLAG_UDPFS | (FLAG_READ_ONLY if read_only)`. The facts are available on the same object (`self.bd_fh is not None`, `self.enable_compression`, `COMPRESSED_EXTENSIONS` — all used elsewhere in the same file, e.g. the `run()` banner at 1053-1065).
- **Execution:** n/a.
- **Fix:** Set the two bits from those predicates — sane, no wire change (bits already reserved).

### RE-SERV-063 — VERIFIED
- **Citations:** `udpfs_server/compressed_iso/base.py:99-127` `CompressedFileWrapper.seek`; `udpfs_server/udpfs_server.py:2189-2230` `_handle_lseek` (maps `ValueError` → EINVAL); `chd_cuebin.py` `MemoryFile.seek` (~310, `if whence not in (0,1,2): raise ValueError`) and `ChdBinFile.seek` (~418, explicit `else: raise ValueError("invalid whence")`). All exist.
- **Mechanism:** The wrapper's seek has `if/elif/elif` for whence 0/1/2 and **no else** — any other whence falls through to the clamp `self.pos = max(0, min(self.pos, self.uncompressed_size))` and returns success, so the handler's `ValueError`→EINVAL arm can never fire for CSO/ZSO/CHD wrappers, while plain files (Python `file.seek` raises `ValueError` on bad whence) and both CUE/BIN views raise. The secondary divergence is also real: the wrapper clamps overshoot to `uncompressed_size` where plain files report the true position.
- **Execution:** n/a (READ; the fall-through is structural).
- **Fix:** `else: raise ValueError` in the wrapper — one branch, lets the existing handler mapping work uniformly. Sane.

### RE-SERV-064 — VERIFIED
- **Citations:** `udpbd_server/udpbd_server.py:82-116` `BlockDevice.__init__`/`sector_count`; :201-203 INFO reply `struct.pack("<II", SECTOR_SIZE, self.bd.sector_count())`; raw-backend contrast at `launcher/raw_storage.py:30-33` (capacity must be "positive, 512-byte aligned, and fit UDPBD's 32-bit sector count (less than 2 TiB)"). All exist.
- **Mechanism:** `__init__` validates only the target *type* (regular file / not a raw device), then records `self.size` with no upper bound and no `size % SECTOR_SIZE` check. `sector_count()` is bare `size // SECTOR_SIZE`. The run loop's dispatch catches `(struct.error, IndexError)` and logs only when verbose (lines 362-365) — so an INFO pack overflow is a silent no-reply at default verbosity, exactly as filed.
- **Execution (mine, upgrading the filed INFERRED leg):** Created a sparse exactly-2 TiB file (2,199,023,555,552 bytes) in `/tmp`, constructed the real `BlockDevice` (accepted without complaint), `sector_count()` = **4,294,967,296 (0x100000000)**, and `struct.pack("<II", 512, sector_count)` raised **`struct.error: 'I' format requires 0 <= number <= 4294967295`**. Separately, a 1,000-byte image was accepted with `sector_count() == 1` and **no warning** — 488 tail bytes silently unservable.
- **Fix:** Mirror the raw backend's construction-time validation (reject `sector_count() > 0xFFFFFFFF`, warn/reject non-multiple sizes) — sane, precedent exists in-repo.

### RE-SERV-065 — VERIFIED
- **Citations:** `http_server/http_server.py:543-580` `_rebuild_flat` (`path_entries[rel_path_key] = entry` at ~564, *before* the `seen_names` duplicate `continue` at ~567-575), :763-784 `lookup` (path entries consulted first; ambiguity guard only on the basename fallback), :607-670 `_rebuild_path_aware` ("Only what the list advertises is served"). All exist.
- **Mechanism:** Suppressed duplicates are recorded in `_path_entries` before suppression, and `lookup()` checks `_path_entries` first, so the suppressed copy is reachable by qualified path while unreachable by bare name and absent from the CSV.
- **Execution (mine):** Real `GameIndex` on a `/tmp` tree — root `SLUS_333.33.Same.iso` (1,024 B) + `DVD/SLUS_333.33.Same.iso` (4,096 B): scan logged "serving \<root copy\>, ignoring \<DVD copy\>", CSV listed only the root copy, `lookup("SLUS_333.33.Same.iso")` → `None` (ambiguous), but **`lookup("DVD/SLUS_333.33.Same.iso")` → the suppressed 4,096 B DVD entry**. Reproduced exactly as filed, byte sizes included.
- **Fix:** Move the `path_entries` assignment below the `seen_names` check — one-line reorder, sane.

### RE-SERV-066 — VERIFIED
- **Citations:** `http_server/http_server.py:898-931` `_dispatch` (generic `except OSError` → `_send_short(500, …)`), :1006-1034 `_serve_game` (206 status+headers via `end_headers()` before the body), :1085-1090 `_send_bytes` short-read raise. All exist.
- **Mechanism:** In `_send_bytes`' manual path, a short read does `self.close_connection = True; raise OSError("short read on …")` — the raise propagates through `_serve_game` (headers already sent) into `_dispatch`, whose `OSError` clause unconditionally writes a complete 500 response onto the same socket, i.e. into the byte stream the driver is counting. The earlier `except (ConnectionResetError, BrokenPipeError)` clause does not catch a plain `OSError`. Scope note (not a weakening): the *sendfile* `OSError` path in `_send_bytes` is already contained (returns `False`, drops the connection) — the live vector is the manual/compressed short-read raise and any other post-`end_headers()` `OSError` that propagates, which is what the finding describes.
- **Execution:** n/a (filed INFERRED/Med; control flow re-derived in full from the cited lines).
- **Fix:** Headers-sent flag; in the `OSError` branch, if sent, just `close_connection = True` and return — sane, preserves the file's own "drop, don't desynchronise" contract.

### RE-SERV-067 — WEAKENED
- **Citations:** `http_server/http_server.py:867-881` `_handle_for` (cache hit iff `_cached_path == entry.path`), :530-541 `refresh` (rebuilds entries under the lock, no connection-cache invalidation — per-connection caches live on handler instances, reset only in `setup()`/`finish()` at 833-865), :1043-1057 `_send_bytes` (length from `entry.size`). All exist.
- **Mechanism — true part:** The cache key is the path string alone — not size, mtime, compressed flag, or entry identity. `refresh()` *does* rebuild on replacement ( `_signature_of` includes per-file size+mtime, a comment there explicitly discusses re-dumped ISOs), producing a new entry for the same path, while a keep-alive handler keeps serving the old open handle paired with the new entry's `size`/`compressed`. Same-path replacement (a re-dumped ISO under the same name — the finding's second example) genuinely hits this: old-larger streams unadvertised bytes; old-smaller short-sends into the RE-SERV-066 path.
- **Mechanism — false example (defeating evidence for that half):** The finding's first example, "a `.chd` swapped for an `.iso` of the same advertised name", **cannot** hit the bug: `entry.path` is the filesystem path, which differs between `Game.chd` and `Game.iso`, so `_cached_path == entry.path` fails and the handler reopens. Only replacements that keep the identical filesystem path are affected.
- **True scope:** Stale-handle/new-entry pairing on an existing keep-alive connection after an index refresh, **for same-path file replacements only**.
- **Fix:** Keying on `(path, size, compressed)` (or entry identity) remains sane and sufficient for the true scope; reopen cost is once per refresh.

### RE-SERV-068 — VERIFIED
- **Citations:** `native/ps2servers-edge/internal/compression/lz4.go:13-29` `readLen`, :37-40 the checks and slice it feeds; `image.go:420-460` `decodeBlock` (`maxRaw := blockSize*2 + 4096`; header `blockSize` valid up to 16 MiB per the cache comment at image.go:35-40). All exist.
- **Mechanism:** `readLen` accumulates `n += int(src[i])` per 0xFF extension byte with no cap. Re-derived: a token `0xF0` followed by 8,500,000 × `0xFF` and a terminating `0x00` yields `lit = 15 + 8,500,000×255 = 2,167,500,015`. On 64-bit that is caught by `lit > dstSize-len(dst)`. On a 32-bit `int` it wraps to −2,127,467,281, which passes *both* checks at lz4.go:37 (`lit > len(src)-i` and `lit > dstSize-len(dst)` are both false for a negative), and `src[i:i+lit]` then panics with slice-bounds-out-of-range. The raw-size bound permits the input: 8.5 MB of extension bytes fits under `maxRaw` for a 16 MiB-block image (~33.5 MB). The match-length use of `readLen` shares the unbounded accumulation (its negative case degrades to a no-op loop rather than a panic — the literal path is the crash).
- **Execution (mine):** 64-bit control probe in a `/tmp` copy of the package: the crafted input above returns **`invalid literal length`** (no panic) on amd64 — exactly the predicted 64-bit behaviour. The 32-bit leg is **BLOCKED-ENV for execution only**: GOARCH=386 test binaries cannot run in this sandbox at all (a trivial 386 test dies identically with `signal: trace/breakpoint trap`), so the panic itself was not executed; the verdict rests on the arithmetic re-derivation above, which is also the basis the finding itself claimed (Med/INFERRED).
- **Fix:** Fail inside `readLen` as soon as `n` exceeds the maximum legitimate length (`dstSize` or remaining input) — sane, local, prevents overflow on every word size.

### RE-SERV-069 — VERIFIED
- **Citations:** `internal/logging/logging.go:45-49` (text-mode `emit`: header `Fprintf` with no newline, one `Fprintf` per field, bare `Fprintln`), `internal/webui/logbuffer.go:28-57` (`Write` splits each call on `\n` and stores every fragment, pushing each to subscribers), `cmd/ps2servers-edge/main.go:518` (`io.MultiWriter(os.Stdout, logBuffer)`). All exist. JSON branch is a single `Fprintln` (logging.go:36) — unaffected, as filed.
- **Mechanism:** `LogBuffer.Write` has no partial-line reassembly, so each producer fragment becomes a stored/pushed line; a bare `"\n"` write splits to `["", ""]`, of which the first empty string is stored (only the *last* empty fragment is skipped) — hence the empty ring slot in the filed evidence.
- **Execution (mine):** Probe test in the `/tmp` Edge copy driving the real `Logger` (text mode): `Info("server started", {"addr": …, "shares": 2})` + one fieldless `Info` produced **5 separate `Write` calls** — `"[info] server started"`, `" addr=127.0.0.1:8082"`, `" shares=2"`, `"\n"`, `"[info] plain line\n"` — which through `LogBuffer.Write`'s documented splitting yields exactly the filed 5 stored lines (including the empty one) from 2 log calls.
- **Fix:** Build the line in memory and emit once, at the producer — sane; correctly rejects the alternative of adding partial-line buffering to `LogBuffer` as well.

### RE-SERV-070 — VERIFIED
- **Citations:** `internal/webui/config.go:195-263` `ValidateConfig`; `cmd/ps2servers-edge/main.go:176-191, 218-222`; `internal/webui/schema.go:114, 120, 122`. All exist.
- **Mechanism:** All three divergences re-read and confirmed. (1) Sector size: API `SectorSize <= 0 || > 1<<16` (message claims range 1-65536, so 513/1000 pass); binary rejects `*sectorSize%512 != 0` (and ≤0 / >65536); schema `Min 512, Max 65536, MultipleOf 512`. (2) Compression cache: API checks only `< 0`; binary rejects `> compression.MaxCacheBlocks` (4096); schema `Max 4096`. (3) Peer timeout: `ValidateConfig` subjects `udpfs.peer_timeout` only to the `noControlChars` string-field check — `"soon"` passes; binary requires a parseable duration in [1m, 24h]; schema declares `MinValue "1m", MaxValue "24h"`. The validator's own doc comment states preventing exactly this ("a value that produces a server which refuses to start") as its purpose.
- **Execution:** n/a (READ; three independent code-to-code contradictions).
- **Fix:** Enforce the binary/schema rules in `ValidateConfig`, reusing the binary's duration parsing — sane; correctly directs *not* loosening the binary/schema.

---

## Duplicates within this range

- **No two distinct RE numbers in 046-070 share a mechanism.** RE-SERV-046 is itself a consolidation of two source filings (Go + Python) of one mechanism in parallel implementations — merged before numbering, not a duplicate pair.
- Related-but-distinct neighbours, checked and *not* duplicates: 058/059 (same file, different helpers — raising int/float parsers vs unvalidated `PROTOCOL_MODE` default); 060/061 (same ZSO/CSO serving wrappers — unbounded LZ4 retry vs unvalidated offsets/short-block fabrication); 065/066/067 (same HTTP server — flat-index suppression leak vs 500-after-206 vs stale per-connection handle; 067's short-send consequence flows into 066's path but the defects are independent); 047/069 (same log pipeline — 069's producer fragmentation feeds the stream 047's live path fails to sanitise; independent fixes).

## Tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 23 | 046, 047, 048, 049, 050, 051, 052, 053, 054, 055, 056, 057, 058, 060, 061, 062, 063, 064, 065, 066, 068, 069, 070 |
| VERIFIED-DRIFT | 0 | — |
| WEAKENED | 2 | 059, 067 |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — (execution leg only of 068's 32-bit panic; see that block) |
| **Total** | **25** | RE-SERV-046 … RE-SERV-070 |

## CANDIDATES (new defects found during verification)

None. No new defect with file:line evidence emerged from this batch's re-derivation and probes. Two observations were checked and are explicitly **not** candidates: (a) `main()` in `ps2servers_core.py` compares `args.protocol_mode == PROFILE_MODULO` exactly, so an env value of `"modulo "` bypasses that fast path — but the `AutoUdpfsServer` path it falls into applies modulo (incl. `single_port`) itself, so behaviour is equivalent (see RE-SERV-059); (b) the LZ4 *match*-length accumulation in `lz4.go` shares RE-SERV-068's unbounded `readLen`, but its negative-wrap case degrades to a no-op loop rather than a panic — same finding, same fix, not a separate defect.
