# LNCHB — Launcher RetroAchievements + misc subsystem (blind redo)

Scope clone: `PS2-Servers @ c5f021c4d38698860f56b03498adc261dbb8d8dd`, read-only.
Method: every in-scope file read in full; censuses and caller counts by script
(AST import scan, repo-wide grep excluding `__pycache__`); one arithmetic
divergence executed in a `/tmp` copy. No secret values are printed anywhere
below — credential material is referred to by location only.
Note on reachability: the owned runtime (`launcher/achievements.py:339-366`,
`--owned-runtime`) is an opt-in, advanced, default-off preview
(`launcher/servers.py:707-708,733`); the bundled native engine is the default
path. Several findings concern the seam between those two stacks, which is
exactly where a user who enables the preview lands.

---

### LNCHB-01 — Owned-runtime `/state` schema diverges from the managed-engine schema its own consumers parse, and two counters are fabricated
- **Category:** 6
- **Locations:** launcher/ra_web.py:82-104 (`note_unlock` emits unlock entries with an `at` timestamp and no `ago`), launcher/ra_web.py:106-140 (`to_dict`: `"webapi"` is just `logged_in` copied, `gaps`/`dupes`/`torn` hardcoded to 0 at lines 122-124), launcher/ra_notifications.py:14-28 (`_event` requires an integer `ago` field — owned unlock entries are therefore all rejected, so `UnlockTracker` can never fire on owned-runtime data), launcher/ra_overview.py:58-76 (`view_model` derives status from `value.get("state") == 2` plus `measured`/`percent` — owned achievements built in launcher/achievements.py carry an `unlocked` boolean and none of those fields, so every owned achievement renders "Not unlocked" with no progress), launcher/achievements.py:274-285 (main loop increments `state.packets`/`state.frames` by exactly 1 per evaluation taken, regardless of real console counters)
- **Problem:** One producer, two incompatible `/state` dialects. The desktop overview, session tracker and unlock notifier were written against the bundled engine's dialect; the owned runtime's `RAState` speaks a different one (field names `unlocked` vs `state`, `at` vs `ago`) and fills the gaps with invented values (zero gap/dupe/torn counts, synthetic packet/frame increments, `webapi` equated with logged-in even though the owned client never uses a Web API key). A user on the owned preview sees unlocks that never notify, achievements that never show as unlocked in the native overview, and telemetry numbers that look measured but are not.
- **Fix:** Pick the managed-engine dialect as the single `/state` contract: make `RAState.note_unlock` also emit `ago` (seconds since the unlock, which it can compute from `at`), make owned achievement entries carry the same status fields `view_model` reads (or change `view_model` to accept the `unlocked` boolean — one side only), drop the hardcoded gap/dupe/torn zeros or remove those keys, stop equating `webapi` with `logged_in`, and feed real receiver counters into `update_console` instead of +1-per-evaluation.
- **Benefit:** The owned preview becomes observable through the existing UI instead of silently misreporting; no fabricated telemetry reaches the user.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### LNCHB-02 — Native RA dashboard builds achievement list with `innerHTML` from unescaped server-supplied titles/descriptions
- **Category:** 6
- **Locations:** launcher/ra_web.py:385-390 (`container.innerHTML = achievements.map(a => \`…${a.title …}…${a.description …}…\`)`)
- **Problem:** Achievement titles/descriptions originate from the RetroAchievements patch response (remote server data, relayed through `RAState.set_game` in launcher/achievements.py) and are interpolated into an `innerHTML` template with no escaping. A title containing markup (e.g. an event-handler payload) executes in the dashboard page's origin — the same origin that can `POST /logout`, whose Host/Origin checks a same-origin script passes trivially. Every other text field in the same `render()` function correctly uses `textContent`; only the achievements list uses `innerHTML`.
- **Fix:** Build the rows with `textContent`/`createElement` like the rest of `render()`, or escape `&<>"'` in title/description before interpolation.
- **Benefit:** Removes script injection into a credential-adjacent local page; aligns the one unsafe sink with the file's own safe pattern.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### LNCHB-03 — The owned runtime bypasses `AccountSession` entirely: hardcoded epoch 1 and fixed task IDs, while the session's begin/accept state machine runs only in tests
- **Category:** 8
- **Locations:** launcher/ra_account_worker.py:271-416 (`AccountSession` with `begin_login`/`begin_resume`/`begin_import`/`begin_set`/`begin_start_session`/`begin_award`/`begin_ping`/`accept`), launcher/achievements.py:183-190 (production resolver constructs `SetContext(creds.username, 1, …)`, `AccountTask(1, 1, "set", …)` and `AccountTask(2, 1, "start_session", …)` with literal epoch/task IDs), launcher/achievements.py:232 (`service.bind_account(creds.username, 1)`), launcher/achievements.py:298,311 (submission tasks take `ctx.epoch`, which is the same literal 1)
- **Problem:** Script census: `begin_*`/`accept(` have zero production callers — every caller is in `tests/` (`test_ra_account_worker.py`, `test_ra_evaluator.py`, `test_ra_owned_service.py`). The only production use of the session object inside `OwnedService` is `logout` via `run_account` (launcher/achievements.py:254). Meanwhile the production path hardcodes the epoch the whole generation-checking design exists to vary: `AccountSession.logout()` increments its epoch (launcher/ra_account_worker.py, `logout`), and `OwnedService` syncs that epoch internally, but the outer runtime keeps minting epoch-1 contexts and tasks, so the generation guarantees documented in `ra_account_worker.py:1-8` and `ra_evaluated_receiver.py` do not actually govern the shipped integration — they govern a parallel, test-only one.
- **Fix:** Either wire `run_owned_runtime` through `AccountSession` (begin/accept on the owner thread, epoch taken from the session), or delete the unused begin/accept surface and document the direct-worker flow as the design. Do not keep both.
- **Justification:** The fix is a choice between wiring existing code and deleting it; no new mechanism is proposed.
- **Benefit:** One commit boundary instead of two; the epoch/cancellation guarantees either become real or stop being claimed.
- **Effort:** L · **Risk:** Med · **Confidence:** High (READ; caller census EXECUTED by script)

### LNCHB-04 — Web "Sign out" deletes the stored credentials, permanently cancels submissions, and can report failure after revocation already happened
- **Category:** 6
- **Locations:** launcher/achievements.py:247-256 (`logout()`: `service.clear_account()`, `account_cancel.set()`, then `session.logout(forget=True)` — i.e. `CredentialStore.clear()` — then `submissions.close()` and raises `TimeoutError` if the submission thread does not join in 2 s), launcher/ra_web.py:518-543 (`do_POST /logout` maps any exception from `logout()` to `503 {"ok": false}` and only calls `state.logout()` on success), launcher/ra_submissions.py:8-59 (`Submissions` shares the caller's cancel event; once set, `offer()` returns False forever and the consumer thread has exited)
- **Problem:** Three conflations in one button. (1) Sign-out semantics: the dashboard button labelled "Sign out" passes `forget=True`, erasing the on-disk runtime token — there is no login form in the native page, so the user can only recover by restarting with CLI `--login`/`--import-credentials`. (2) Irreversibility: `account_cancel` is never cleared and the submissions thread is closed inside `logout()`, so even the still-running main loop can never submit or ping again in this process. (3) Partial failure: revocation (`clear_account`, cancel) happens *before* the fallible `submissions.close()`; if the worker child is mid-request (AccountWorker deadline is up to 30 s vs the 2 s join), the page reports 503 "sign out could not be completed" while the account is in fact already revoked and credentials already deleted — the UI state and the real state disagree, and `RAState.logout()` is skipped.
- **Fix:** Make web sign-out `forget=False` (forgetting stays an explicit CLI action), perform the fallible thread shutdown before publishing revocation (or report success once revocation is done and log the shutdown timeout separately), and do not close the shared submissions consumer on a transient sign-out.
- **Benefit:** Sign-out means sign-out; the reported result matches the resulting state; no silent credential destruction from a status page.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### LNCHB-05 — Caduceus: unauthenticated CADQ sender becomes the unlock-notice destination, and the CADA pairing key lives in the console-served games folder
- **Category:** 6
- **Locations:** launcher/caduceus.py:170-190 (`Bridge.start` binds UDP 18197/18198 on `0.0.0.0`), launcher/caduceus.py:262 (any CADQ packet — no HMAC, format check only — sets `self.peer = peer[0]`), launcher/caduceus.py:205-229 (`read_events` sends `RAU1` unlock notices to `self.peer` on port 18195), launcher/caduceus.py:278 (CADA is HMAC-checked against `self.key`), launcher/caduceus.py:92-108 (`pairing_key` stores that key as `CADUCEUS.KEY` inside `<games folder>/ART`)
- **Problem:** The authenticated half of the protocol (CADA) is keyed by a secret stored in the ART subfolder of the very games folder the PS2 (and anything else that can read the share) is served — share-scoped readability is the design's own description in the module docstring, so the HMAC key is only as secret as the games share. Independently, the unauthenticated half (CADQ) has a side effect beyond its reply: the last CADQ sender on the LAN becomes the destination for subsequent unlock notices, so any LAN host can redirect those notices (or suppress the real console's, by being last) with one well-formed datagram. The 40 req/s global cap in `run()` does not distinguish senders.
- **Fix:** Do not let CADQ mutate notice routing — send notices only to the console address established by the authenticated/engine state; keep the pairing key out of the served tree (e.g. in the private RA profile, with only artwork in ART), accepting the pairing-flow change that implies.
- **Justification:** No new mechanism: both fixes remove an existing side effect / relocate an existing file.
- **Benefit:** The HMAC check stops being theatre against share readers, and notice routing stops being last-sender-wins on an unauthenticated packet.
- **Effort:** M · **Risk:** Med · **Confidence:** Med (READ; share-readability of the games folder is INFERRED from the folder's role as the OPL games root)

### LNCHB-06 — Caduceus Web API key is sent as a GET query parameter on every API request
- **Category:** 6
- **Locations:** launcher/caduceus.py:117-123 (`Account.request`: key read from the profile `apikey` file — location only — merged into `params` and placed in the request URL query string), launcher/caduceus.py:55-90 (`read_secret`, the loader for that file and for the profile `credentials` file)
- **Problem:** The RetroAchievements Web API key travels in the URL (`…API_<Endpoint>.php?…&y=<key>`) rather than a header/body. URLs are the most-logged artifact in any HTTP path (proxies, crash reports, history, `Referer` on redirects — mitigated here only by the `NoRedirect` opener). The owned-runtime stack was explicitly built to keep this class of secret out of URLs and argv (`ra_credentials.py:1-5`, `ra_resolver_process.py:5`); the Caduceus bridge predates/loosens that standard. Location of the stored key file is noted above; its value is never reproduced here.
- **Fix:** Where the RA API accepts it, move the key to a POST body; where it does not, at minimum document the exposure at the point the user is asked to paste the key, so the consent is informed.
- **Benefit:** Aligns the bridge with the repo's own credential-handling standard, or at least makes the exception explicit.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### LNCHB-07 — DPAPI unprotect is implemented twice, with divergent hygiene
- **Category:** 2
- **Locations:** launcher/ra_credentials.py:31-57 (`_dpapi`: sets argtypes/restype, validates output size against `LIMIT`, zeroes both the source buffer and the native output buffer before `LocalFree`, raises on failure), launcher/caduceus.py:55-90 (`read_secret`: re-implements the same `CryptUnprotectData` call inline; zeroes/frees only the result buffer, never zeroes its source copy, and returns `""` on every failure)
- **Problem:** Same platform primitive, two implementations, different guarantees: the Caduceus copy silently conflates "file missing", "DPAPI failure" and "empty secret" into `""` (callers then report a generic sign-in problem), and skips the source-buffer wipe and size validation the owned store treats as mandatory. Fixes to one copy (e.g. a buffer-handling correction) will not reach the other.
- **Fix:** Have `caduceus.read_secret` call the existing unprotect helper from `ra_credentials` (exposed for decrypt-only use) and translate its exception to `""` at that one call site if the silent behaviour is still wanted.
- **Benefit:** Net code removal; one audited DPAPI path for all credential files.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### LNCHB-08 — Account-identity / token validation re-implemented at eight sites with divergent rules
- **Category:** 2
- **Locations:** launcher/ra_account.py:14-20, launcher/ra_credentials.py:24-28 (`Credentials.__post_init__`), launcher/ra_session_client.py:58-66, launcher/ra_set_client.py:15-24 (username check omits the `\0\r\n` rejection the otherwise-identical check in `ra_session_client.py` has), launcher/ra_sets.py:50-60 (`SetContext`: account check omits control-character rejection), launcher/ra_account_worker.py:36-40 (`AccountTask`: username may be empty and is length-checked differently), launcher/ra_evaluated_receiver.py:44-46, launcher/ra_owned_service.py:139-143
- **Problem:** Script census found eight separate spellings of "username ≤ 64, token ≤ 4096" with three different rule sets (with/without control-character rejection, with/without non-empty username). Each layer currently catches most of what the laxer layers miss, so this is not a demonstrated bypass — it is eight places to keep in sync, and the divergence is already visible (set-client and context accept usernames the session client rejects, so the same bad value fails at different depths with different errors).
- **Fix:** One shared validator in `ra_credentials` (where `Credentials` already defines the canonical rule) called by the clients and `SetContext`; keep the extra per-operation checks (e.g. login requires a password) local.
- **Justification:** Sharing removes code overall: eight near-identical blocks become one plus call sites.
- **Benefit:** A future rule change (e.g. RA username charset) lands once; error behaviour stops depending on which layer is hit first.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ; census EXECUTED by script)

### LNCHB-09 — Achievement-definition validation duplicated four times, and `award_achievement` bypasses the shared response decoder
- **Category:** 2
- **Locations:** launcher/ra_sets.py:130-145 (`qualify_set` definition loop), launcher/ra_account_worker.py:138-152 (`valid_account_result` re-validates the same definitions), launcher/ra_resolver_process.py:38-60 (`valid_identification_result` re-validates them a third time, near-verbatim), launcher/ra_evaluator.py:62-73 (`Evaluator.__init__` validates them a fourth time), launcher/ra_session_client.py:117-145 (`award_achievement` hand-rolls `json.loads` + `Success` checking instead of the `decode_response` used by its own `start_session`/`ping` in the same class)
- **Problem:** The "ID in 1..2³²−1, expression 1..16384 chars, no NUL, ASCII, total ≤ 4 MiB, no duplicates" rule exists in four copies (script census on the shared constants), and the award path opts out of the one decoder that rejects duplicate JSON keys and non-dict responses (`ra_sets.decode_response` with `_unique_object`) — it accepts duplicate-key responses and coerces scores with bare `int(...)` on unvalidated values. Any bound change must be made four times and can silently desynchronise the IPC validators from the producer, causing valid sets to be dropped at the process boundary as generic failures.
- **Fix:** Keep validation at the trust boundaries that need it (IPC receive, native activation) but generate both from one function in `ra_sets`; switch `award_achievement` to `decode_response` and validate score fields the way `AwardResult.__post_init__` already does.
- **Benefit:** Bounds cannot drift apart; the award response gets the same duplicate-key/size discipline as every other RA response.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ; census EXECUTED by script)

### LNCHB-10 — Five different title-sanitising implementations across the RA files
- **Category:** 2
- **Locations:** launcher/ra_protocol.py:109-114 (`clean_title`: NFKD, strip combining, ASCII-only, limit 63), launcher/ra_receiver.py:118-121 (the same NFKD/combining/ASCII logic inlined again in `Receiver.complete`), launcher/caduceus.py:35-39 (`clean`: same logic, caller-supplied limit), launcher/ra_notifications.py:9-10 (`safe_title`: whitespace-collapse only, limit 96, keeps non-ASCII and control-adjacent characters the others strip), launcher/ra_overview.py:18-19 (`short`: whitespace-collapse, caller limit)
- **Problem:** Three copies of the wire-facing ASCII cleaner and two different display cleaners, with different limits and different character rules. Cross-file comparisons depend on this: `ra_overview.view_model` and `ra_session.SessionTracker` both compare titles produced through `safe_title`, while the console-facing notice path uses `clean_title` — a title that round-trips differently through the two families (accents, non-ASCII) compares unequal or displays differently per surface, and a fix to the wire cleaner must be made in three places.
- **Fix:** Keep exactly two functions — the wire cleaner in `ra_protocol` (used by `ra_receiver` and `caduceus`, which already import from the RA package) and the display cleaner in `ra_notifications` — and delete the inline copies.
- **Benefit:** Net removal; title equality across overview/session/notifications stops depending on which copy ran.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; census EXECUTED by script)

### LNCHB-11 — The loopback `/state` fetch is duplicated verbatim in the overview and the session poller
- **Category:** 2
- **Locations:** launcher/ra_overview.py:94-100 (`fetch_engine_state`), launcher/ra_session.py:133-144 (`SessionPoller._fetch`)
- **Problem:** Both functions build `account_url() + "state"`, `urlopen` with a 2 s timeout, read 1 MiB + 1, reject over 1 MiB, and `json.loads` — identical except the error-message wording. They will drift (one already says "reply exceeds 1 MiB", the other "reply exceeded limit"), and any change to the state endpoint (port file, size cap, auth) must be made twice in the two components the GUI runs simultaneously.
- **Fix:** Keep `fetch_engine_state` in `ra_overview` (or move it to `ra_session`) and call it from the other.
- **Benefit:** One /state client; trivial net removal.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### LNCHB-12 — Identification's `gameid` request bypasses all pacing, and its 429 backoff is discarded
- **Category:** 6
- **Locations:** launcher/achievements.py:160-175 (`resolve_job` constructs a fresh `Transport()` per job and POSTs `gameid` directly, outside `AccountWorker`), launcher/ra_http.py:28-47 (`Transport` pacing state `_next_request` is per-instance, so a new instance always starts unpaced), launcher/ra_account_worker.py (`AccountWorker` retains `minimum_interval`/`retry_after` across children — the mechanism this call circumvents)
- **Problem:** The stack goes to considerable lengths to pace RA requests and to remember server backoff across child processes, then the owned runtime's resolver — the entry point of every identification — makes an unpaced request through a throwaway transport before the paced worker is ever invoked. Worse, the whole block is wrapped in `except Exception: return IdentificationResult()`, so a `RateLimited` from this call (which carries `retry_after`) is flattened into a generic transient failure: the worker's cooldown is never armed, and the receiver will re-queue identification and repeat the unpaced call. Under a rate-limiting server this is a self-sustaining retry loop at receiver pace, not server pace.
- **Fix:** Route the `gameid` lookup through the same `AccountWorker` (it already has a process boundary and pacing) or, minimally, keep one long-lived `Transport` for `resolve_job` and let `RateLimited` propagate to the worker's `_not_before` handling instead of swallowing it.
- **Benefit:** The documented pacing/backoff design actually covers the first request of every identification; 429s slow the client down instead of speeding retries up.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### LNCHB-13 — Caduceus library (`G`) progress replies always report 0 earned / 0 maximum
- **Category:** 6
- **Locations:** launcher/caduceus.py:329-356 (`Bridge.progress`: `game_id, earned, maximum = 0, 0, 0`; the `kind == "G"` branch fills `total` and per-row `earned` counts but never recomputes the header `earned`/`maximum`, unlike the `A` branch at lines 348-351; the reply body is then formatted from those zeros)
- **Problem:** Every "My library" page sent to the console carries header progress of 0/0 regardless of the user's actual completion, while the per-row data in the same reply is correct — the console UI's aggregate progress for the library view is permanently wrong, not merely stale.
- **Fix:** In the `G` branch, derive the header fields from the fetched totals (sum of row `earned`/`MaxPossible`, or the API's aggregate fields) before formatting, the way the `A` branch does.
- **Benefit:** Library progress on the console matches the account it was fetched from.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### LNCHB-14 — Caduceus `pad()` over-pads by a full 64-byte block whenever the body is already block-aligned, diverging from the owned protocol's padding
- **Category:** 6
- **Locations:** launcher/caduceus.py:48-52 (`pad`: `max(128, ((len(data) + 64) // 64) * 64)`), launcher/ra_protocol.py:99-106 (`pad_reply`: `max(128, ((len(body) + 63) // 64) * 64)`, with the docstring noting CADQ/CADA deliberately use NUL rather than space padding — the fill byte differs by design, the length formula should not)
- **Problem:** Executed comparison (in a `/tmp` copy): body lengths 128 and 192 produce Caduceus datagrams of 192 and 256 bytes respectively, versus 128 and 192 from `pad_reply`; all non-aligned lengths agree. Any CADB reply whose formatted body lands exactly on a 64-byte multiple is sent 64 bytes longer than the shared contract — wasted datagram at best, and a length the console's DMA-aligned receive path was not sized from this formula at worst.
- **Fix:** Change `+ 64` to `+ 63` in `caduceus.pad` so only the intentional NUL-vs-space difference remains.
- **Benefit:** One padding contract across both console protocols; removes a boundary case that only triggers on exact-multiple bodies (i.e. rarely, and therefore late).
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### LNCHB-15 — Watch-profile vocabulary disagrees across three files: `orbit-v1.0.2` is accepted but never produced, `caduceus` is produced but rejected by the IPC validator
- **Category:** 8
- **Locations:** launcher/ra_sets.py:156-158,200 (profiles `{"opl", "orbit-v1.0.2", "caduceus"}` accepted; orbit gets its own validator), launcher/ra_watchlist.py:60-73 (`validate_orbit_watchlist`), launcher/ra_resolver_process.py:27-29 (`valid_identification_result` accepts only `{"opl", "orbit-v1.0.2"}`), launcher/achievements.py:152 (production produces only `"caduceus"` or `"opl"`)
- **Problem:** Repo-wide grep: no code anywhere ever constructs an `IdentificationResult` with profile `orbit-v1.0.2` — the orbit validator, its 1216-byte ceiling logic and its IPC allowance are dead capability. Conversely, the one non-default profile production *does* produce, `caduceus`, is not in the IPC validator's set, so a caduceus-mode qualified result crossing `ProcessResolver` validation would be discarded as invalid. The two halves of the profile system were each extended without the other.
- **Fix:** Decide once: either add `caduceus` to the resolver validator and delete the orbit profile until a producer exists, or wire an orbit producer and keep both. Do not keep an unproducible profile and an unvalidatable one.
- **Benefit:** Profile handling becomes a single closed set that producer, validator and deriver all agree on.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; producer census EXECUTED by grep)

### LNCHB-16 — Verified dead code: `derive_watch` alias, unused `ENDPOINT` attributes, two unused imports
- **Category:** 1
- **Locations:** launcher/ra_sets.py:204 (`derive_watch = derive_direct_watch` — repo-wide grep finds no caller other than the definition), launcher/ra_set_client.py:7 (imports `_NoRedirect`, never used — AST census), launcher/ra_set_client.py:13 and launcher/ra_session_client.py:56 (`ENDPOINT = Transport.ENDPOINT` class attributes; the set client's is referenced nowhere, the session client's only by a test assertion), launcher/achievements.py:13 (`import sys`, never referenced — AST census)
- **Problem:** Small but real clutter at exactly the seams a reader uses to orient: an alias that suggests a second derivation entry point, and endpoint attributes that suggest per-client endpoints when both clients actually post through `Transport.ENDPOINT`.
- **Fix:** Delete the alias, the set client's `ENDPOINT`, and both unused imports; keep the session client's `ENDPOINT` only if the test contract is considered public, and say so in a comment if kept.
- **Benefit:** Fewer false trails in the most security-sensitive files in the subsystem.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED — AST/grep census, zero callers)

### LNCHB-17 — The same watch list is fully re-validated four times on every set activation
- **Category:** 5
- **Locations:** launcher/ra_sets.py:200 (`derive_direct_watch` validates the derived bytes), launcher/ra_watchlist.py:101 (`WatchSession.install` validates again), launcher/ra_receiver.py:111 (`Receiver.complete` validates again before installing), launcher/ra_evaluator.py:73 (`Evaluator.__init__` validates a fourth time)
- **Problem:** `validate_watchlist` is an O(count + nodes) structural pass over up to 17,432 bytes with per-entry struct unpacking. On the owned path a single identification runs it at derivation, at receiver publication, at session installation and at evaluator construction — four passes over identical, already-immutable `bytes` within one call chain (`EvaluatedReceiver.complete_set` → `complete` → `Receiver.complete` → `WatchSession.install`, plus `Evaluator`). None of the later passes can fail if the earlier one in the same chain passed, because the object is the same immutable bytes object.
- **Fix:** Validate once at derivation and once at the IPC/trust boundary (where bytes arrive from another process); drop the redundant in-chain revalidations in `Receiver.complete`/`WatchSession.install` when the caller is the in-process evaluated path, or pass the already-produced `WatchList` object instead of raw bytes so revalidation is structurally unnecessary.
- **Benefit:** Removes repeated per-activation work on the identification hot path without weakening the cross-process check.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ; call sites grep-verified)

### LNCHB-18 — `CredentialStore` wedges permanently if the profile directory pre-exists with non-0700 permissions, and `load()` can raise instead of returning "no credentials"
- **Category:** 6
- **Locations:** launcher/ra_credentials.py:62-70 (`_check_path` raises on any group/other permission bit), launcher/ra_credentials.py:95-105 (`_prepare` uses `mkdir(exist_ok=True)` — which does not repair permissions of an existing directory — then immediately `_check_path`s it), launcher/ra_credentials.py:124-141 (`load()` calls `_prepare()`, creating directories on a read path, and propagates the permission `ValueError`), launcher/achievements.py:163,230 (both `store.load()` call sites in the owned runtime are outside any recovery path — the startup one is entirely unguarded)
- **Problem:** The owned profile directory is shared territory: `achievements.profile_dir()` and the bundled engine also create/use it. If that directory (or the `owned` subdir) ever exists with ordinary 0755 permissions — created by another tool, an archive extraction, or a umask/platform difference — every `save`/`load`/`clear` raises the same error forever, with no in-app remedy short of manually chmodding, and the owned runtime's startup `load()` turns it into a hard failure rather than a signed-out state. The check is doing real security work; the failure mode around it is the defect.
- **Fix:** In `_prepare`, when the directories are ones this store created/owns, repair their mode (`os.chmod(..., 0o700)`) before checking, and reserve the hard raise for files/symlinks it did not expect; make `load()` return `None` for a missing store without creating directories.
- **Benefit:** A recoverable permissions drift stops being a permanent, opaque lockout of the owned account feature.
- **Effort:** S · **Risk:** Med · **Confidence:** Med (READ/INFERRED — the wedge follows from the code paths; the pre-existing-0755 precondition was not executed)

### LNCHB-19 — SSE `/events` uses one shared dirty-flag for all clients and ignores its result, so every client is sent the full state about once a second regardless of change
- **Category:** 5
- **Locations:** launcher/ra_web.py:142-145 (`wait_dirty`: waits on the single `RAState._dirty` event, then clears it — one client's wait clears the flag for all others), launcher/ra_web.py:507 (the `/events` handler calls `wait_dirty(timeout=1.0)`, discards the returned flag, and unconditionally serialises and writes the full state)
- **Problem:** The dirty mechanism cannot work as designed: with N connected browsers, whichever handler wakes first clears the event, and since the return value is ignored every handler wakes on the 1 s timeout anyway and pushes a complete `to_dict()` JSON. The result is per-second full-state serialisation per client (the exact cost the dirty flag exists to avoid), plus `RAWebServer.close()` poking the private `state._dirty` (launcher/ra_web.py:567) to compensate. On the LAN viewer path this state is also relayed onward.
- **Fix:** Either delete `wait_dirty`/`_dirty` and keep the honest 1 s poll-push, or make change notification per-client (each handler tracks the last-sent revision counter on `RAState`). The first option is the LESS fix and matches current observable behaviour.
- **Benefit:** Removes a misleading synchronisation mechanism (and a private-attribute reach from the server class) without changing what clients actually receive.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

---

## Files read

All in `~/workspace/audit-clones-2026-11-13/PS2-Servers/launcher/`, read in full:

- ra_account.py (23 lines)
- ra_account_probe.py (31 lines)
- ra_account_worker.py (416 lines)
- ra_compressed_hash.py (146 lines)
- ra_credentials.py (168 lines)
- ra_evaluated_receiver.py (186 lines)
- ra_evaluator.py (225 lines)
- ra_http.py (80 lines)
- ra_notifications.py (82 lines)
- ra_overview.py (252 lines)
- ra_owned_service.py (438 lines)
- ra_protocol.py (268 lines)
- ra_receiver.py (212 lines)
- ra_resolver_process.py (197 lines)
- ra_session.py (183 lines)
- ra_session_client.py (155 lines)
- ra_set_client.py (53 lines)
- ra_sets.py (205 lines)
- ra_setup.py (40 lines)
- ra_sounds.py (87 lines)
- ra_submissions.py (59 lines)
- ra_watchlist.py (116 lines)
- ra_web.py (571 lines)
- achievements.py (414 lines)
- achievement_loader.py (74 lines)
- achievement_viewer.py (109 lines)
- caduceus.py (411 lines)
- discord_presence.py (286 lines)

Notes on files with no findings filed: ra_account_probe.py, ra_compressed_hash.py,
ra_setup.py, ra_sounds.py, achievement_loader.py, achievement_viewer.py and
discord_presence.py were read in full and checked for the focus areas
(credential locations, subprocess/network boundaries, unchecked returns,
wedging state machines); no defect meeting the LESS-NOT-MORE bar was found
that is not covered by a finding above. `ra_account_probe.py`'s synthetic
credential is a labelled test fixture (location: launcher/ra_account_probe.py:11,18),
not a real secret. The Discord application ID in discord_presence.py is a
public client identifier, not a credential.

## Files not read (in scope)

None — all 28 in-scope files were read in full.
