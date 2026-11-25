# Verification Batch D — RE-SERV-071 … RE-SERV-087 (PS2-Servers, adversarial redo verification)

**Pin confirmation:** `git -C ~/workspace/audit-clones-2026-11-13/PS2-Servers rev-parse HEAD` →
`c5f021c4d38698860f56b03498adc261dbb8d8dd` — matches the assigned pin exactly. Clone was read-only;
all executions ran against the clone's importable Python tree (read-only imports), `/tmp` copies
(Go probe test, CredentialStore fixtures), or a Go binary built to `/tmp/edgebuild/`.
No finding in this batch required UDP sendto, so no BLOCKED-ENV verdicts were needed.

---

### RE-SERV-071 — VERIFIED
- **Citations:** All exist. `native/ps2servers-edge/internal/webui/service.go:221-226` is
  `genericManager.Restart` calling `m.log.Info(...)` unconditionally and `return nil, nil`;
  `service.go:163-165` is openwrtManager's guarded `if m.log != nil`; `service.go:128-137`
  (`DetectServiceManager`) passes the logger through unchecked; `webui.go` `New` (79-…) sets
  defaults for LogLines/LogBuffer/MaxLogClients/Username but never requires `cfg.Log` non-nil.
- **Mechanism:** Re-derived. No defeating guard: `Serve` passes `s.cfg.Log` to
  `DetectServiceManager` (webui.go:173), and `HandleRestart` (api.go:227-241) serialises the
  returned slice — a nil slice renders as `"restarted": null` with `"ok": true`. The shipped
  binary always supplies a logger (main.go), so the panic path is library-construction-only,
  exactly as the finding's own INFERRED/latent note states.
- **Execution:** Probe test in a `/tmp` copy of the module:
  `(&genericManager{log: nil}).Restart("udpfs")` → **PANIC: runtime error: invalid memory
  address or nil pointer dereference** (test recovered and logged it). The false-success half
  is established by the code path above (`return nil, nil` → `{"ok": true, "restarted": null}`).
- **Fix:** Sound and minimal (guard like openwrtManager + return an error/manual-restart
  signal, inside the one method). LESS-NOT-MORE compliant.

### RE-SERV-072 — VERIFIED
- **Citations:** `status.go:48-49` — `// StatusQueryLen is the exact length of a query.` /
  `const StatusQueryLen = 10`. `status.go:107-126` — doc: "deliberately strict about length:
  a six-byte packet whose service ID is 0xF5F7 is the only thing that qualifies"; body tests
  `if len(packet) < StatusQueryLen`.
- **Mechanism:** Both halves of the doc are wrong as claimed. `MarshalStatusQuery` in the same
  file builds Header (2 B) + DiscoveryHeader (4 B) + `StatusMagic` (4 B) = 10 bytes, not six;
  and `<` (not `!=`) admits any packet ≥10 bytes with the right header/service/magic at
  bytes 6–10, trailing garbage included. No defeating comment elsewhere rescues the doc —
  the file header's "Safe to append because a longer packet … is still dropped" note actually
  supports the tolerance reading, making the IsStatusQuery doc the outlier.
- **Execution:** n/a (pure doc-vs-code; lengths counted from the marshal code).
- **Fix:** Sound — either rewrite the doc or tighten to `!=`; the finding correctly refuses
  to leave them disagreeing and does not prescribe which side wins.

### RE-SERV-073 — VERIFIED
- **Citations:** `launcher/servers.py:127-137` `_smb_argv` resolves
  `folder = (v.get("games_folder") or v.get("root_dir") or "").strip()` and raises
  `ValueError("SMB server requires a Games folder to share.")`; `servers.py:176-179`
  `_smb2_argv` does `"{}={}".format(share, v["games_folder"])` — direct indexing.
- **Mechanism:** Confirmed by reading both builders; no fallback or emptiness check in `_smb2_argv`.
- **Execution:** Ran the builders from the pinned tree:
  - `SMBV1.build_argv({"root_dir": "/games"})` → `['--share', 'games=/games', '--smb-version', '1']`
  - `SMBV2.build_argv({"root_dir": "/games"})` → **KeyError: 'games_folder'**
  - `SMBV2.build_argv({"games_folder": ""})` → `['--share', 'games=', '--smb-version', '2']` (silent empty share)
  - `SMBV1.build_argv({"games_folder": ""})` → ValueError as designed.
  All four outcomes match the finding exactly (SMBV3 shares `_smb2_argv`).
- **Fix:** Sound, minimal, mirrors the v1 resolution exactly.

### RE-SERV-074 — VERIFIED
- **Citations:** `launcher/windows_setup.py:146-157` — data-port rule skipped only
  `if not values.get("modulo_mode")`; `launcher/servers.py:271-299` `migrate_saved` deletes
  `modulo_mode`, setting `enforce_modulo=True` and `protocol_mode="Modulo"`;
  `servers.py:344-350` `_udpfs_argv` treats `enforce_modulo` or `modulo_mode` as single-port.
- **Mechanism:** After migration no GUI-produced dict can contain `modulo_mode` again (the
  migration's own docstring states the widget-drop rationale), so the firewall suppression
  keyed to it is dead for migrated/current configs. `posix_firewall.firewall_hint_lines`
  consumes the same port list shape, so the Linux-hint consequence holds.
- **Execution:** Ran `windows_setup.server_ports("udpfs", …)`:
  - `{"enforce_modulo": True, "protocol_mode": "Legacy / Modulo only", "data_port": 40000}` →
    includes `('UDP', 40000, 'UDPFS data')` (dead rule present)
  - `{"protocol_mode": "modulo", "data_port": 40000}` → same, includes 40000
  - `{"modulo_mode": True, "data_port": 40000}` → 40000 suppressed (only the retired key works)
- **Fix:** Sound — test the current vocabulary (reuse `protocol_mode_value`), keep the legacy
  check for un-migrated dicts. Related to RE-SERV-076 (same vocabulary-drift family; 076 itself
  names this finding as an instance) but a distinct mechanism/location — not a duplicate.

### RE-SERV-075 — VERIFIED
- **Citations:** `cooperative_stop` contract comment at `servers.py:72-77`; flag set at
  387/436/452/468/568/659 (SMBv1, SMBv2, SMBv3, UDPFS, HTTP, UDPBD — grep-confirmed, those six
  only); NFS def (624-652) and RetroAchievements def (712-746) have no flag (default False).
  `launcher/process.py`: non-cooperative children get `stdin=DEVNULL`, no `PS2SERVERS_STOP_PIPE`
  env, `request_stop()` returns False, `stop()` falls through to `terminate()`.
  `nfs4_server/nfs4_server.py:1094-1110`: `finally: server.stop()` plus SIGTERM→KeyboardInterrupt
  hook. `launcher/achievements.py:362-410`: SIGINT/SIGTERM `stopped` event, engine subprocess
  supervised in a loop, `finally` closes viewer/bridge/lease and unlinks the account-port file.
- **Mechanism:** Every server is dispatched through `launcher/serve.py:158`
  `install_stop_handlers()`, whose stdin-EOF watcher raises KeyboardInterrupt in the main
  thread — but it only installs when the stop-pipe env is present, which the launcher only
  sets for cooperative children. So the two excluded servers genuinely never receive the pipe.
  On POSIX, `terminate()`'s SIGTERM happens to reach NFS's hook / RA's `stopped` handler;
  on Windows it is TerminateProcess (documented at process.py:14-18), so NFS cleanup is
  skipped and the RA engine child (spawned with `subprocess.Popen`, untracked by the
  launcher) is orphaned holding UDP 18194. That last consequence is INFERRED from the
  documented Windows semantics — the finding labels it exactly that way.
- **Execution:** n/a (Windows stop semantics not executable in this sandbox; mechanism is
  fully code-established).
- **Fix:** Sound and correctly hedged — it requires the wake-on-EOF check per server before
  flipping the flag, and fixing the wait loop rather than the flag if a server fails it.

### RE-SERV-076 — VERIFIED
- **Citations:** RA `mode` Field `default="xerabora"` (servers.py:720) with
  `RA_MODE_CHOICES = (("xeRAbora", "xerabora"), ("Caduceus", "caduceus"))` (686); UDPFS
  `protocol_mode` default `"Auto (recommended)"` (485); HTTP `catalog_profile` default
  `"Legacy flat (OPL-HTTP)"` (581-582). Tolerant readers all present: `_achievements_argv`
  label-or-wire map (689-695), `protocol_mode_value` (302-312), `http_profile_value`
  (526-531), windows_setup mode tested against both `"caduceus"` and `"Caduceus"` (134-139),
  gui.py:881-885 wire→label restore conversion for UDPFS `protocol_mode` only, and
  `migrate_saved` writing the third spelling `"Modulo"` (293-298).
- **Mechanism:** `gui.py:715-718` fills the choice combobox with labels only and initialises
  the var to `str(f.default …)` — so the RA card's untouched var holds `"xerabora"`, a value
  not in its own dropdown's label list, while a touched card persists `"xeRAbora"`. The
  two-spellings-per-setting round-trip follows directly.
- **Execution:** Field-default census from the pinned tree:
  `udpfs protocol_mode → 'Auto (recommended)'`, `http catalog_profile → 'Legacy flat (OPL-HTTP)'`,
  `retroachievements mode → 'xerabora'` — exactly the claimed asymmetry.
- **Fix:** Sound direction (one stored vocabulary + load-time normalisation); effort/risk
  honestly rated M/Med. Not a duplicate of RE-SERV-074 — this is the systemic cause, 074 is
  one concrete victim in a different file.

### RE-SERV-077 — VERIFIED
- **Citations:** `windows_setup.py:142-144` — one fallback `_parse_port(values.get("port"), 1025)`
  for all three SMB keys; `servers.py:211-218` `_SMB2_FIELDS` port Field `default=1445`;
  SMBV1 `default_port=1025` vs SMBV2/SMBV3 `default_port=1445`. Third literal site confirmed:
  `gui.py:308` and `gui.py:389` both use `values.get("port") or ("1025" if key == "smbv1" else "1445")`.
- **Mechanism:** `server_ports`'s own docstring claims "one source so the two never disagree"
  (windows_setup.py:124-129) while its SMB fallback disagrees with the registry for v2/v3.
- **Execution:** Full registry sweep from the pinned tree — `server_ports(key, {})` vs
  `REGISTRY[key].default_port` for all eight servers: **only smbv2 and smbv3 mismatch**
  (1025 returned vs 1445 actual); smbv1, udpfs, http, nfs, udpbd, retroachievements all agree.
  The finding's scope is exact — no more, no less.
- **Fix:** Sound and minimal (take the fallback from `REGISTRY[key].default_port`).

### RE-SERV-078 — VERIFIED
- **Citations:** Module contract at `netinfo.py:1-8` (prefer private LAN over VPN/WSL);
  `primary_ip` (84-93) is the UDP-connect-to-8.8.8.8 default-route address; `_lan_rank`
  (122-131); `best_lan_ip` (224-234) returns `primary_ip()` whenever it is not loopback and
  consults the ranked candidates only for 127.x; `all_ipv4` also adds `primary_ip()`
  unconditionally. GUI use confirmed: `gui.py:1320` and `gui.py:1785` pre-fill from
  `best_lan_ip()`.
- **Mechanism:** The ranking is dead in the common case, as claimed. (Note the function's own
  docstring argues the opposite preference — "Prefer the interface that actually routes
  off-box" — which strengthens, not defeats, the finding: header, docstring, and code tell
  three different stories, and the header's stated purpose loses.)
- **Execution:** No VPN exists in the sandbox, so I executed the logic with the two network
  primitives monkeypatched to the full-tunnel case: `primary_ip() → "172.58.0.2"`,
  `all_ipv4() → ["192.168.1.50", "172.58.0.2"]` ⇒ `best_lan_ip()` returned **`172.58.0.2`**
  (the tunnel address), never consulting the rank-0 LAN candidate; with primary stubbed to
  `127.0.0.1` the same candidate list correctly yielded `192.168.1.50`. The bypass is
  deterministic from the code path.
- **Fix:** Sound (prefer best-ranked private candidate, fall back to primary).

### RE-SERV-079 — VERIFIED
- **Citations:** All verified in place. `ra_web.py:82-104` `note_unlock` emits unlock entries
  with `at` and no `ago`; `ra_web.py:106-140` `to_dict` sets `"webapi": self.logged_in` and
  hardcodes `"gaps": 0, "dupes": 0, "torn": 0` (122-124). `ra_notifications.py:14-28` `_event`
  requires `type(seconds_ago) is int` for `ago` — owned entries are therefore all rejected,
  and `UnlockTracker` (consumed by `ra_session.py:100`) can never fire on owned data.
  `ra_overview.py:58-76` derives status from `value.get("state") == 2` plus `measured`/`percent`;
  owned achievements are built in `achievements.py` (208) with an `unlocked` boolean and none
  of those fields → every owned achievement renders "Not unlocked". `achievements.py:274-285`:
  the owned main loop calls `update_console(packets=state.packets + 1, frames=state.frames + 1)`
  once per evaluation taken — synthetic counters, as claimed.
- **Mechanism:** No adapter between the dialects exists anywhere I grepped. Corroborating
  cross-effect: Caduceus `read_events` (caduceus.py:226-229) gates unlock notices on
  `event.get("ago", 999) <= 2`, so owned-runtime unlocks (no `ago`) are silently suppressed
  there too — same root divergence, second victim.
- **Execution:** n/a (schema divergence is fully determined by the quoted producers/consumers).
- **Fix:** Sound — converge on one `/state` contract and stop fabricating counters; the
  finding offers the either-side option for `view_model` rather than prescribing both.

### RE-SERV-080 — VERIFIED
- **Citations:** `achievements.py:247-256` `logout()`: `service.clear_account()` +
  `account_cancel.set()` inside `context_lock`, then
  `service.run_account(lambda session: session.logout(forget=True))`, then
  `if not submissions.close(): raise TimeoutError(...)`. `ra_account_worker.py:405-416`:
  `logout(forget=True)` ends in `self.store.clear()` — the on-disk token is erased.
  `ra_web.py:518-543` `do_POST /logout`: any exception → `503 {"ok": false}`, and
  `owner.state.logout()` runs only on success. `ra_submissions.py:8-59`: `Submissions`
  shares the caller's cancel event; once set, `offer()` returns False forever and the
  consumer thread has exited; `close()` default join timeout is 2 s.
- **Mechanism:** All three conflations hold: (1) a button labelled "Sign out" passes
  `forget=True` (credential destruction, recoverable only via CLI `--login`/`--import-credentials`);
  (2) `account_cancel` is never cleared anywhere and the submissions consumer is closed inside
  `logout()`, so the still-running process can never submit or ping again; (3) revocation
  (clear_account, cancel, credential clear) all happen *before* the fallible
  `submissions.close()`, so a timeout reports 503 "could not be completed" after the account
  is already revoked and credentials already deleted, with `RAState.logout()` skipped —
  UI state and real state disagree, as claimed.
- **Execution:** n/a (ordering is fully visible in the quoted code; the 2 s vs worker-deadline
  asymmetry is in the defaults: `Submissions.close(timeout=2)`, `AccountWorker(timeout=30)`).
- **Fix:** Sound — `forget=False` for web sign-out, fallible shutdown before publishing
  revocation (or report success once revocation is done), don't close the shared consumer.

### RE-SERV-081 — VERIFIED
- **Citations:** `caduceus.py:170-190` `Bridge.start` binds UDP 18197/18198 on `0.0.0.0`;
  `caduceus.py:262` — any packet matching only the format regex
  `CADQ([12]) ([a-f0-9]{32})` sets `self.peer = peer[0]` (no HMAC); `caduceus.py:205-229`
  `read_events` sends `RAU1` unlock notices to `self.peer` on port 18195;
  `caduceus.py:278` CADA is HMAC-checked against `self.key`; `caduceus.py:92-108`
  `pairing_key` stores the key as `CADUCEUS.KEY` inside the ART directory, and
  `Bridge.__init__` (151-153) sets `self.art = Path(folder) / "ART"` where `folder` is the
  games folder. The module docstring itself describes the key as a "share-scoped pairing
  capability".
- **Mechanism:** Both halves hold. CADQ's side effect (last-sender-wins notice routing) is
  unauthenticated; the 40 req/s cap in `run()` is global, not per-sender. The CADA HMAC key
  sits in the served games tree — the share-readability step is INFERRED from the folder's
  role as the OPL games root, exactly as the finding labels it (Med confidence is honest).
- **Execution:** n/a (LAN packet injection not exercisable here; the routing mutation is a
  single unconditional assignment in the quoted code).
- **Fix:** Sound and LESS-NOT-MORE as justified in the finding (remove a side effect,
  relocate an existing file — no new mechanism).

### RE-SERV-082 — VERIFIED
- **Citations:** `achievements.py:160-175` `resolve_job` constructs a fresh `Transport()` per
  job and POSTs `{"r": "gameid", …}` directly, outside `AccountWorker`; the whole block is
  wrapped in `except Exception: return IdentificationResult()`. `ra_http.py:28-47`:
  `Transport._next_request` pacing state is per-instance, so a fresh instance always starts
  unpaced. `ra_account_worker.py`: `AccountWorker` retains `minimum_interval` and arms
  `self._not_before = max(…, now + result.retry_after)` from `RateLimited` results
  (217-218, 253-265) — the mechanism this call circumvents.
- **Mechanism:** `RateLimited` is a `ValueError` subclass carrying `retry_after`
  (ra_http.py:14-18); the blanket `except Exception` in `resolve_job` flattens it into a
  generic transient `IdentificationResult()`, the worker's cooldown is never armed, and the
  owned service treats a bare result as retryable (`ra_owned_service.py` / receiver
  `complete(job)` "invalid set remains retryable"), so re-identification repeats the unpaced
  call at receiver pace. No defeating path: nothing upstream of `resolve_job` paces it.
- **Execution:** n/a (would require live RA traffic; the pacing-state lifetime and the
  exception swallow are both directly read).
- **Fix:** Sound — route through the existing `AccountWorker`, or minimally keep one
  long-lived `Transport` and propagate `RateLimited`.

### RE-SERV-083 — VERIFIED
- **Citations:** `caduceus.py:48-52` `pad`: `max(128, ((len(data) + 64) // 64) * 64)`;
  `ra_protocol.py:99-106` `pad_reply`: `max(128, ((len(body) + 63) // 64) * 64)`, docstring
  noting the base client uses spaces while "CADQ/CADA have a separate NUL-padding contract"
  — i.e. the fill byte differs by design, the length formula is not stated to.
- **Mechanism:** For a body already on a 64-byte multiple, `+64` rounds up one full extra
  block; `+63` does not. All non-aligned lengths agree.
- **Execution:** Ran both functions from the pinned tree over lengths 0–192. Divergences at
  exactly the aligned lengths, matching the finding precisely:
  len 128 → Caduceus **192** vs `pad_reply` **128**; len 192 → Caduceus **256** vs
  `pad_reply` **192**; lengths 1, 63, 64, 65, 127, 129, 191 all agree.
- **Fix:** Sound, one character (`+ 64` → `+ 63`).

### RE-SERV-084 — VERIFIED-DRIFT
- **Citations:** `ra_credentials.py:62-70` `_check_path` raises on any group/other permission
  bit (POSIX); `ra_credentials.py:95-105` `_prepare` uses `mkdir(exist_ok=True, mode=0o700)`
  — which does not repair an existing directory's mode — then immediately `_check_path`s it;
  `ra_credentials.py:124-141` `load()` calls `_prepare()` when the owned directory exists and
  propagates the `ValueError`. Call sites in `achievements.py` at 163 (inside `resolve_job`)
  and 230 (startup, in `run_owned_runtime`, unguarded) confirmed.
- **Mechanism:** The wedge is real, with one scope correction to the finding's wording:
  `load()` does **not** unconditionally call `_prepare()` / create directories on a read
  path — it short-circuits to `return None` when the `owned` subdir does not exist, without
  ever checking the profile dir. So a pre-existing 0755 *profile* dir alone does not wedge
  `load()` (it wedges `save()`); the `load()` wedge requires the `owned` subdir itself to
  exist with non-0700 permissions (or both dirs). The permanent-lockout consequence is
  otherwise exactly as described: no code path chmods, so every subsequent call raises the
  same error, and the startup `load()` turns it into a hard failure instead of signed-out.
- **Execution:** Fixtures in `/tmp` against the pinned tree:
  - profile 0755, no `owned` subdir → `load()` returned `None` (twice, no wedge);
    `save()` → **ValueError: Credential paths must be private to their owner**.
  - profile 0700, `owned` 0755 → `load()` → **ValueError**; `save()` → **ValueError**.
  - both 0755 → `load()` → **ValueError**; `save()` → **ValueError**; repeated calls keep
    raising (wedge persists, no self-repair).
- **Fix:** Sound (repair mode for directories the store owns; hard raise reserved for
  unexpected files/symlinks). The "make `load()` return None for a missing store without
  creating directories" half is already the current behaviour for a wholly missing store —
  worth keeping in the fix only for the owned-exists-but-unreadable case.

### RE-SERV-085 — VERIFIED-DRIFT
- **Citations:** The shipped file exists exactly as quoted —
  `packaging/systemd/ps2servers-edge-webui.env` (4 lines): line 4 is
  `PS2EDGE_ARGS=--webui-port 8082 --bind 0.0.0.0 --config-file /etc/ps2servers-edge/config.json`,
  no `--auth-pass`, no `--insecure`, and no warning comments, unlike the sibling env files
  (e.g. `ps2servers-edge-smb.env` carries a full warning block). `packaging/systemd/README.md`
  does disclose the trap in prose, as the finding concedes. **Citation drift:** the binary
  rule is not at `main.go:476-484` (those lines are inside `runWebUI`'s flag definitions);
  the actual refusal is `ErrInsecureBind` at `internal/webui/webui.go:63-65`, enforced in
  `webui.New` at `webui.go:98-102`, reached from `main.go:520` (`webui.New(...)` inside
  `runWebUI`, main.go:470).
- **Mechanism:** Non-loopback bind + empty password + not AllowInsecure → `New` returns
  `ErrInsecureBind` before anything serves; the subcommand exits 1.
- **Execution:** Built the pinned tree with Go 1.27.4 to `/tmp/edgebuild/ps2servers-edge` and
  ran it with exactly the shipped arguments:
  `ps2servers-edge webui --webui-port 8082 --bind 0.0.0.0 --config-file /etc/ps2servers-edge/config.json`
  → **exit 1**, stderr: `error: refusing to serve the web UI on a non-loopback address
  without a password: pass --auth-user/--auth-pass, or --insecure to accept the risk`.
- **Fix:** Sound (ship `--bind 127.0.0.1` or port the sibling warning block into the env file).

### RE-SERV-086 — VERIFIED
- **Citations:** `packaging/systemd/ps2servers@.service:5-7` quoted verbatim from the file:
  "Separate from ps2servers-edge.service, which runs the Go build and serves only UDPFS and
  UDPBD. Edge has no SMB at all, so a user who needs SMB … cannot use that unit"; line 2
  presents the template's instance keys as only "smbv1, udpfs or udpbd".
- **Mechanism:** Every clause fails against the shipped tree: the binary has `smb` and
  `webui` subcommands; `packaging/systemd/ps2servers-edge@.service` exists precisely to run
  them ("A template: %i is the Edge subcommand — udpfs, udpbd or smb"); the systemd README
  states "**Edge now serves SMB too**" and its table gives `ps2servers-edge@.service` as
  "**SMBv1**, UDPFS, UDPBD"; and `ps2servers-edge.service`'s ExecStart is `udpfs` only —
  it serves UDPFS, not "UDPFS and UDPBD". The three-way disagreement on the template's scope
  also holds: header (3 keys) vs `launcher/servers.py` REGISTRY (8 keys: smbv1, smbv2,
  smbv3, udpfs, http, nfs, udpbd, retroachievements) vs README table (SMBv1, SMB2/3, UDPFS,
  HTTP, UDPBD).
- **Execution:** Ran the built binary: `ps2servers-edge -h` lists `udpfs`, `udpbd`, `smb`,
  and `webui` subcommands; `smb -h` and `webui -h` both produce real flag sets.
- **Fix:** Sound — rewrite the header to match the systemd README and state the template's
  key scope in one place only.

### RE-SERV-087 — VERIFIED
- **Citations:** `packaging/openwrt/files/ps2servers-edge.init:123` and `:172` —
  `config_get status_port smb status_port -1` / `config_get status_port udpbd status_port -1`
  (grep-confirmed, both sites). Shipped `packaging/openwrt/files/ps2servers-edge.config`
  sets `option status_port '0'` in both the smb section (~line 47) and the udpbd section
  (~line 63), each with the rationale comment: off by default because udpfs owns UDP 62966
  and two owners race first-starter-wins.
- **Mechanism:** With the option present, UCI supplies `0` and the fallback never fires;
  deleting the option (a normal UCI "reset to default") makes `config_get` substitute `-1`,
  enabling the status listener on the port udpfs owns — recreating the exact race the
  config comments warn about. The init script's own comment at the udpbd instance even
  restates the race while its fallback defaults to the racing value. The safety property
  therefore lives only in the one config line, contradicted by the layer beneath it.
- **Execution:** Binary default confirmed from the built binary: both
  `ps2servers-edge smb -h` and `udpbd -h` show
  `-status-port int … (default -1)`; the flag definitions agree
  (`main.go:302` and `:363`, `envInt("STATUS_PORT", -1)`).
- **Fix:** Sound, minimal — change both init fallbacks to `0`.

---

## Tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 15 | 071, 072, 073, 074, 075, 076, 077, 078, 079, 080, 081, 082, 083, 086, 087 |
| VERIFIED-DRIFT | 2 | 084 (load() short-circuits when `owned` is missing — the load wedge needs the `owned` subdir itself at non-0700; profile-only 0755 wedges save, not load), 085 (rule's real location is `webui.go:63-65, 98-102`, reached from `main.go:520`, not `main.go:476-484`) |
| WEAKENED | 0 | — |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — |
| **Total** | **17** | RE-SERV-071 … RE-SERV-087 |

**Duplicates within range:** none. Closest pair is RE-SERV-074 / RE-SERV-076 — 076 is the
systemic vocabulary-drift cause and itself names 074 as one instance, but the mechanisms,
files, and fixes are distinct (retired-key firewall suppression vs. choice-field stored
vocabulary). RE-SERV-077 is a different `_server_ports` defect (wrong numeric default, not
wrong key). RE-SERV-079 / RE-SERV-080 share the owned RA runtime but disjoint mechanisms
(schema divergence vs. logout semantics).

## CANDIDATES (new defects / extensions found during verification)

1. **Caduceus unlock notices are also suppressed for owned-runtime state (extension of
   RE-SERV-079's mechanism, second victim).** `launcher/caduceus.py:226-229` (`read_events`)
   gates `RAU1` notices on `event.get("ago", 999) <= 2`; owned-runtime unlock entries from
   `launcher/ra_web.py:82-104` carry `at` and no `ago`, so the gate is never satisfied and
   console unlock notices silently never fire on owned-runtime data — the same `at`-vs-`ago`
   divergence that blocks `UnlockTracker`, in a consumer the original finding did not cite.
2. **`best_lan_ip`'s own docstring contradicts the module contract (documentation drift
   adjacent to RE-SERV-078).** `launcher/netinfo.py:224-228` docstring says "Prefer the
   interface that actually routes off-box (the real LAN adapter)" while the module header
   (lines 1-8) states the opposite preference (private LAN over VPN/WSL). Even if the code
   is fixed per RE-SERV-078, the docstring would remain as a trap for the next reader.
