# PS2-Servers — Go Edge support packages (blind redo)

- **Clone / pin:** `~/workspace/audit-clones-2026-11-13/PS2-Servers` @ `c5f021c4d38698860f56b03498adc261dbb8d8dd` (verified with `git rev-parse HEAD`)
- **Scope:** `native/ps2servers-edge/cmd/ps2servers-edge/main.go` plus all non-test `.go` files in `internal/filesystem/`, `internal/logging/`, `internal/memory/`, `internal/protocol/`, `internal/session/`, `internal/sessionstats/`, `internal/statuslistener/`, `internal/webui/` — 18 files, 4,056 lines (counted by `wc -l`), every file read in full.
- **Method:** citations grep-verified against the tree; caller censuses by `grep -rn` over all `.go` files in `native/ps2servers-edge` (non-test callers distinguished from test callers); counts by script, never estimated. One executed probe (GOCORE-01) and one baseline test run were done in a `/tmp` copy; the clone was never edited.
- **Baseline test note (not a finding):** `go test` on the in-scope packages passes except `internal/webui` `TestStatusIdentifiesTheServiceByFlags`, which performs a live UDP loopback query/reply; the sandbox blocks UDP `sendto`, so this failure is **BLOCKED-ENV**, not a repo defect. `go vet` on the in-scope packages is clean.

---

### GOCORE-01 — Text-mode log lines with fields are fragmented into multiple LogBuffer lines (and subscribers get the fragments)
- **Category:** 6
- **Locations:** `native/ps2servers-edge/internal/logging/logging.go:45-49`; `native/ps2servers-edge/internal/webui/logbuffer.go:28-57`; `native/ps2servers-edge/cmd/ps2servers-edge/main.go:518`
- **Problem:** In text mode, `Logger.emit` writes one log line as several separate `Write` calls: the header `[%s] %s` with no newline, one ` %s=%v` per field, then a bare `Fprintln` newline. `LogBuffer.Write` treats each `Write` chunk as complete lines (`bytes.Split` on `\n`, storing every fragment). The web UI tees the logger into the buffer via `io.MultiWriter(os.Stdout, logBuffer)` (main.go:518), so every fielded text-mode line lands in the ring buffer — and is pushed to `/api/logs` subscribers — as one fragment per field plus an empty line that also consumes a ring slot. Executed proof (probe test in a `/tmp` copy): `Info("server started", {"addr": …, "shares": 2})` followed by one fieldless `Info` produced 5 stored lines: `"[info] server started"`, `" addr=127.0.0.1:8082"`, `" shares=2"`, `""`, `"[info] plain line"` — 2 log calls, 5 buffer lines. JSON mode is unaffected (single `Fprintln` at logging.go:36).
- **Fix:** Build the complete text line in memory inside `emit` and emit it with a single `Write`/`Fprintln`, as the JSON branch already effectively does. Do not add partial-line buffering to `LogBuffer` as well — one fix, at the producer.
- **Benefit:** The dashboard log view and the ring buffer contain the same lines the console shows; ring capacity (default 1,000) stops being burned ~4× faster by fielded lines and empty strings.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### GOCORE-02 — Live `/api/logs` stream forwards lines without the SSE sanitisation applied to every other line
- **Category:** 6
- **Locations:** `native/ps2servers-edge/internal/webui/api.go:62-70` (`sanitizeSSE` and its rationale); `native/ps2servers-edge/internal/webui/api.go:285-299` (sanitised paths); `native/ps2servers-edge/internal/webui/api.go:316` (unsanitised live path)
- **Problem:** `sanitizeSSE` exists because SSE framing is line-based: a raw `\n` in a line lets its producer inject extra events into the stream, and the comment names filenames and peer addresses as sources. The service-log snapshot (api.go:293) and the backlog replay (api.go:299) both pass through `sanitizeSSE`; the live subscription loop at api.go:316 writes the channel line verbatim (`fmt.Fprintf(w, "data: %s\n\n", line)`). Live lines come from the same `LogBuffer` fed by logger output carrying those same filenames/peers, so the one path that runs indefinitely is the one path unprotected.
- **Fix:** Pass the live line through `sanitizeSSE` at api.go:316, exactly as at lines 293 and 299. No new mechanism.
- **Benefit:** Closes an SSE event-injection hole in the authenticated management UI and makes all three emit sites in `HandleLogs` behave identically.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOCORE-03 — `ValidateConfig` accepts values the binary then refuses at startup (sector size, compression cache, peer timeout)
- **Category:** 6
- **Locations:** `native/ps2servers-edge/internal/webui/config.go:195-263` (esp. 254-262); `native/ps2servers-edge/cmd/ps2servers-edge/main.go:176-191` and `native/ps2servers-edge/cmd/ps2servers-edge/main.go:218-222`; `native/ps2servers-edge/internal/webui/schema.go:114`, `native/ps2servers-edge/internal/webui/schema.go:120`, `native/ps2servers-edge/internal/webui/schema.go:122`
- **Problem:** The API validator and the binary disagree, which is the exact failure `ValidateConfig`'s own doc says it exists to prevent ("a value that produces a server which refuses to start with no visible reason"). Three concrete divergences, all read from the code: (1) `sector_size` — API accepts any 1–65536 (config.go:254-255); the binary requires a multiple of 512, at least 512 in effect, at most 65536 (main.go:176-182), and the schema declares `Min 512, MultipleOf 512` (schema.go:120). So 513 or 1000 saves cleanly via the dashboard and udpfs then exits with an error. (2) `compression_cache_size` — API checks only `< 0` (config.go:257-259); the binary rejects `> compression.MaxCacheBlocks` (4096, main.go:188-191) and the schema declares `Max 4096` (schema.go:122), so a large saved value passes the API and fails (or, per main.go's own comment, was bounded precisely to avoid a huge allocation). (3) `peer_timeout` — `ValidateConfig` never parses it at all; the binary requires a parseable duration between 1m and 24h (main.go:218-222) and the schema declares that range (schema.go:114). A dashboard-saved `"peer_timeout": "soon"` is accepted and the service then refuses to start.
- **Fix:** Make `ValidateConfig` enforce the same three rules the binary and the schema already state (multiple-of-512 sector size in 512–65536; cache size 0–4096; peer_timeout parseable and within 1m–24h, reusing the duration parsing the binary uses rather than a second implementation). Do not loosen the binary or the schema to match the API.
- **Benefit:** A config the dashboard reports as saved is a config the services will actually start with; three documented contracts (API, binary, `--dump-schema`) stop contradicting each other.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOCORE-04 — UCI boolean parsing is duplicated 16 times inline and disagrees with the one use of the shared helper
- **Category:** 2
- **Locations:** `native/ps2servers-edge/internal/webui/config_uci.go:14-22` (`uciBool`); `native/ps2servers-edge/internal/webui/config_uci.go:89` (its only use in `Load`); `native/ps2servers-edge/internal/webui/config_uci.go:63-163` (16 inline occurrences of `val == "1" || val == "true"`, counted by script)
- **Problem:** `uciBackend.Load` parses booleans two ways in the same switch. `uciBool` accepts `1/on/true/yes/enabled` (case-insensitive) and is used exactly once, for `main.udp_batch` (line 89). Every other boolean field — all of main/smb/udpbd/webui, lines 63–163 — uses the narrower inline test `val == "1" || val == "true"`. A hand-written or third-party-generated UCI file (the schema in schema.go exists precisely for config generators) that writes e.g. `verbose 'on'` or `enabled 'yes'` is honoured for `udp_batch` and silently read as false for the other fifteen-plus booleans. `Save` only ever writes `1`/`0`, which masks the divergence until a config arrives from anywhere else.
- **Fix:** Replace all 16 inline tests with the existing `uciBool(val)` call. Pure deletion of repeated logic; no new helper needed because the helper already exists.
- **Benefit:** One boolean semantics for the whole UCI file, ~16 repeated expressions removed, and a class of "setting ignored" misreads eliminated.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOCORE-05 — The four subcommands copy-paste their flag scaffolding — and the copy in `runWebUI` already lost the `--log-format` validation
- **Category:** 2
- **Locations:** `native/ps2servers-edge/cmd/ps2servers-edge/main.go:161-163` + `:193-195` (udpfs); `native/ps2servers-edge/cmd/ps2servers-edge/main.go:304-307` + `:321-322` (udpbd); `native/ps2servers-edge/cmd/ps2servers-edge/main.go:365-368` + `:380-381` (smb); `native/ps2servers-edge/cmd/ps2servers-edge/main.go:489-491` (webui, no validation follows); logger/signal setup repeated at `native/ps2servers-edge/cmd/ps2servers-edge/main.go:241-249`, `:325-335`, `:384-431`, `:518-541`
- **Problem:** Each of `main` (udpfs), `runUDPBD`, `runSMB` and `runWebUI` re-declares the same `--log-format`/`--verbose`/`--quiet` flags (and the first three plus webui variously re-declare `--session-summary`, `--bind`-family env defaults), re-creates the logger, and re-creates the signal context. The copies have already drifted: udpfs, udpbd and smb each validate `--log-format` must be `text` or `json` and exit 2 otherwise; `runWebUI` declares the flag at line 489 and never validates it, so `--log-format garbage` is silently treated as text by `logging.New` (any non-`"json"` value is text) in the webui subcommand only. Script counts: 4 `flag.NewFlagSet`, 4 `log-format` definitions, 3 validations, 4 `signal.NotifyContext`, 4 `edgelog.New`.
- **Fix:** Extract one small helper that registers the common logging flags on a `FlagSet` and returns the validated logger inputs (rejecting a bad `--log-format` there, once), and call it from all four subcommands. This is the one place a shared helper removes code overall: four declaration blocks and three validation blocks collapse to one of each.
- **Justification:** The fix adds one helper function; it is justified because the identical logic exists in 4 places, the copies have already produced a behavioural bug (missing validation), and the net line count goes down.
- **Benefit:** One flag contract for all subcommands; the webui `--log-format` gap closes as a side effect of deduplication rather than as a fifth copy of the check.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ)

### GOCORE-06 — OpenWrt `ServiceLogs` ignores its line limit, defeating the stated snapshot memory bound
- **Category:** 4
- **Locations:** `native/ps2servers-edge/internal/webui/service.go:67-82` (`maxServiceLogLines`/`clampLogLines` and the bound's rationale); `native/ps2servers-edge/internal/webui/service.go:173-176` (openwrtManager); `native/ps2servers-edge/internal/webui/service.go:208-212` (systemdManager, which does clamp); `native/ps2servers-edge/internal/webui/api.go:284-295` (the caller that then streams every returned line)
- **Problem:** service.go states the design rule itself: `maxServiceLogLines` "bounds one snapshot, and therefore the memory a request can make this process hold." The systemd manager honours it via `clampLogLines(lines)`; the OpenWrt manager ignores its `lines` parameter entirely and returns the full output of `logread -e ps2servers-edge` — however many lines the router's log ring holds — which `HandleLogs` then holds in a `[]string` and writes out line by line. OpenWrt is the primary router target (32 MB class hardware per the package comments), i.e. the platform where the bound matters most is the one that doesn't apply it.
- **Fix:** Truncate the `readLogCommand` result to `clampLogLines(lines)` entries (keeping the most recent) inside `openwrtManager.ServiceLogs`, mirroring the systemd path. No new mechanism — reuse the existing clamp.
- **Benefit:** The documented per-request memory bound becomes true on all three managers; a `/api/logs` connect on OpenWrt can no longer pull an unbounded log snapshot into the webui process.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOCORE-07 — `genericManager.Restart` dereferences a possibly-nil logger and reports success for a restart that did nothing
- **Category:** 6
- **Locations:** `native/ps2servers-edge/internal/webui/service.go:221-226`; contrast `native/ps2servers-edge/internal/webui/service.go:163-165` (openwrtManager's nil check); `native/ps2servers-edge/internal/webui/service.go:128-137` (`DetectServiceManager` passes the logger through unchecked); `native/ps2servers-edge/internal/webui/webui.go:198-206` (Serve passes `s.cfg.Log`, which `New` never requires to be non-nil)
- **Problem:** Two defects in four lines. (1) `genericManager.Restart` calls `m.log.Info(...)` unconditionally; the OpenWrt manager guards the identical call with `if m.log != nil`. A `webui.Server` built without a `Log` (nothing in `New` requires one) on a host with neither procd nor systemctl panics on the first restart request instead of answering it. (2) Even when it doesn't panic, it returns `(nil, nil)`: `HandleRestart` then reports `{"ok": true, "restarted": null}` for a restart that by definition did not happen, on exactly the hosts (generic/manual installs) where the operator most needs to be told to restart by hand.
- **Fix:** Guard the log call the same way openwrtManager does, and return an error (or an explicit empty restarted set with the manual-restart message surfaced) instead of a nil error. Keep the change inside this one method.
- **Benefit:** No panic path in a management endpoint, and the dashboard stops claiming a successful restart on generic hosts.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (INFERRED — the nil-logger path is latent: `main.go` always supplies a logger, so it is reachable via library-style construction of `webui.Server`, not via the shipped binary's webui subcommand)

### GOCORE-08 — `sessionstats` exports production API that only tests use: `Parse`, `WithClock`, `WithLimits`
- **Category:** 1
- **Locations:** `native/ps2servers-edge/internal/sessionstats/sessionstats.go:247-266` (`Parse`); `native/ps2servers-edge/internal/sessionstats/sessionstats.go:67-74` (`WithClock`, `WithLimits`)
- **Problem:** A grep census over all `.go` files in the edge tree shows zero non-test callers for all three. `Parse` is called only from `internal/smb/session_summary_test.go`, `internal/udpbd/session_summary_test.go` and `internal/udpfs/session_summary_test.go`; `WithClock` and `WithLimits` are called only from `internal/sessionstats/sessionstats_test.go`, and their own comments say so ("for tests"). They are exported, mutable-after-construction surface on a concurrency-sensitive type: `WithClock`/`WithLimits` rewrite `Stats` fields with no synchronisation, safe only because tests call them before first use — an invariant nothing enforces for a future production caller.
- **Fix:** Move the three helpers into the test files that use them (an in-package `sessionstats_test` helper can set the unexported fields directly), or if `Parse` is genuinely wanted by an external consumer, name that consumer in its doc. Do not keep exported production API whose only callers are tests.
- **Benefit:** Smaller, honest API surface for a package every server links; the unsynchronised mutators can no longer be picked up by production code by accident.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOCORE-09 — Dead webui surface: an unread `API.log` field, and `Server.GeneratedPassword` / `Server.Close` with no callers
- **Category:** 1
- **Locations:** `native/ps2servers-edge/internal/webui/api.go:22` (field) set at `native/ps2servers-edge/internal/webui/webui.go:206`; `native/ps2servers-edge/internal/webui/webui.go:106-107` (`GeneratedPassword`); `native/ps2servers-edge/internal/webui/webui.go:293-298` (`Server.Close`)
- **Problem:** Three grep-verified dead items in one package. (1) `API.log` is assigned in `Serve` but never read anywhere in api.go — every handler uses `a.logBuffer`, `a.manager` or `jsonError` (which writes to stderr directly). (2) `Server.GeneratedPassword` has no caller anywhere in the tree, test or non-test: `Serve` itself already logs the generated password at webui.go:271-273, so the accessor's stated purpose ("so the caller can print it") is already served and the method is pure extra surface. (3) `Server.Close` likewise has no caller; shutdown is driven by the context goroutine inside `Serve` (webui.go:281-289), and `main.go`'s webui path never calls it.
- **Fix:** Delete the `log` field from `API` and its assignment, and delete `GeneratedPassword` and `Close` (or, for `Close`, wire it only if a caller actually appears). All deletions, no replacements.
- **Benefit:** Less misleading surface: a reader no longer has to trace a logger field that does nothing or lifecycle methods that are never invoked.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOCORE-10 — `IsStatusQuery`'s documentation claims exact-length strictness the code does not implement
- **Category:** 6
- **Locations:** `native/ps2servers-edge/internal/protocol/status.go:48-49` (`StatusQueryLen` — "the exact length of a query"); `native/ps2servers-edge/internal/protocol/status.go:107-126` (`IsStatusQuery` doc and body)
- **Problem:** The doc says the check is "deliberately strict about length: a six-byte packet whose service ID is 0xF5F7 is the only thing that qualifies." Both halves are wrong against the code below it: a query is ten bytes, not six (2-byte header + 4-byte discovery header + 4-byte magic, per `MarshalStatusQuery` in the same file), and the length test is `len(packet) < StatusQueryLen` — any packet of 10 or more bytes with the right header, service ID and magic at bytes 6–10 qualifies, trailing garbage included. Either the strictness claim is stale documentation on a security-relevant guard (this check is what stops the server answering foreign discovery traffic, per the file's own header), or the intended `!=` check was never written. As shipped, a reader auditing the guard is told the opposite of what it does.
- **Fix:** Decide once: if trailing bytes are intentionally tolerated (the header comment argues longer packets are safely dropped elsewhere), rewrite the doc to say so and drop "exact"/"strict"/"six-byte"; if they are not, change the test to `len(packet) != StatusQueryLen`. Do not leave doc and code disagreeing on a packet guard.
- **Benefit:** The status-query guard's real acceptance rule becomes auditable; no future change "fixes" the code to match a comment that was simply wrong, or vice versa.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### GOCORE-11 — `Root.List` fully symlink-resolves and stats every directory entry, one `EvalSymlinks` per entry
- **Category:** 5
- **Locations:** `native/ps2servers-edge/internal/filesystem/root.go:235-259` (`List`); `native/ps2servers-edge/internal/filesystem/root.go:66-97` (`Resolve`, called per entry at root.go:247)
- **Problem:** `List` first resolves the directory itself (root.go:236), then for **every** entry calls `r.Resolve(child, false)` — which runs `filepath.EvalSymlinks` on the full path plus a `filepath.Rel` containment check — and then `os.Stat` on the result. A directory listing (the DREAD path a console issues per folder) therefore costs at least two path-walking syscalls per entry on top of `ReadDir`, on the router-class hardware this build targets, for folders that in the common case contain no symlinks at all. The per-entry escape check is a real security requirement and must stay for links; it is only the unconditional full resolution of plain files/directories that is wasted work.
- **Fix:** `Lstat` each entry first (one syscall, already implied by `ReadDir`'s type bits); only when the entry is a symlink run the existing `Resolve` containment path, otherwise join the already-resolved parent directory with the entry name and `Stat` only if size/mode are needed beyond the `Lstat`. Keep `Resolve` itself untouched for all other callers.
- **Benefit:** Directory listings drop from ~2 path resolutions per entry to ~1 `Lstat` per plain entry, with identical escape behaviour for the symlink entries that are the actual threat.
- **Effort:** M · **Risk:** Med · **Confidence:** Med (INFERRED — cost structure is read from the code and syscall counts are per-entry by construction; no benchmark was run, and symlink semantics must be re-verified against `root_test.go` when changed)

---

## Files read

All paths relative to `native/ps2servers-edge/`:

- `cmd/ps2servers-edge/main.go` (548 lines)
- `internal/filesystem/root.go` (259 lines)
- `internal/logging/logging.go` (79 lines)
- `internal/memory/budget.go` (135 lines)
- `internal/protocol/packet.go` (155 lines)
- `internal/protocol/status.go` (209 lines)
- `internal/session/session.go` (251 lines)
- `internal/sessionstats/sessionstats.go` (266 lines)
- `internal/statuslistener/listener.go` (108 lines)
- `internal/webui/api.go` (461 lines)
- `internal/webui/config.go` (264 lines)
- `internal/webui/config_json.go` (53 lines)
- `internal/webui/config_uci.go` (323 lines)
- `internal/webui/embed.go` (6 lines)
- `internal/webui/logbuffer.go` (97 lines)
- `internal/webui/schema.go` (194 lines)
- `internal/webui/service.go` (350 lines)
- `internal/webui/webui.go` (298 lines)

Total: 18 files, 4,056 lines. Caller censuses additionally grep-read individual call sites outside this scope (e.g. `internal/udpfs/`, `internal/smb/`, `internal/udpbd/`) solely to verify whether in-scope symbols are used; those files were not audited.

## Files not read (in scope)

- None. Every non-test `.go` file in scope was read in full. (`*_test.go` files were excluded by the task definition and were only grep-searched for caller censuses.)
