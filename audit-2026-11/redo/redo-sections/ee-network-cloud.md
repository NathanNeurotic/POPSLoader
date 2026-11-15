# Launchstation — Blind Redo Audit: EE Network / Cloud / Security

- Repo: `~/workspace/audit-clones-2026-11-13/Launchstation`
- Pin verified by `git rev-parse HEAD`: `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790`
- Method: read-only in the clone. No files under `~/workspace/Sable-audit/` were read, listed, or grepped. Every line citation below is from a file actually read in this pass. `INFERRED` marks claims the EE code alone cannot prove (usually IOP-side behaviour).
- OAuth material: this repo carries cloud OAuth material reachable via a generator script. Per instructions this report gives **location only** — `scripts/gen_cloud_client.py` (env-fed generation of an untracked header, consumed at `src/cloud_google.c:20-27`) — and prints no secret value or fragment anywhere. No committed secret value was found in the files read; the generated header (`.cloud-deps/include/`) is not present in the clone.

## Category legend (as used in this section)

| Cat | Meaning |
|---|---|
| 1 | Correctness bug |
| 2 | Security / credential handling |
| 3 | Performance / memory |
| 4 | Duplicated logic (one mechanism, several copies) |
| 5 | Dead / half-finished code |
| 6 | Parser / network / file-format bounds |
| 7 | Error-path / failure-recovery robustness |
| 8 | Simplification (LESS NOT MORE) |

## Coverage ledger

### Read in full
- `src/cloud_http.c` (1312 lines), `src/cloud_google.c` (1635), `src/self_update.c` (434), `src/update_psu.c` (364)
- `src/smb_cnf.c` (657), `src/smb_shares.c` (487), `src/neutrino_smb.c` (187), `src/neutrino_iso.c` (401), `src/gui_neutrino.c` (518)
- `src/ftp_session.c` (92), `src/dash_ftp.c` (134), `src/dash_smbd.c` (83), `src/config_network.c` (362)
- `src/dash_clock_sync.c` (482), `src/pc_game_receiver.c` (354), `src/remote_control.c` (111)
- `src/dash_store.c` (870 — read because cloud token/config paths are built from it)
- Headers: `include/cloud_google.h`, `include/cloud_http.h`, `include/cloud_google_roots.h`, `include/ftp_protocol.h`, `include/ftp_session.h`, `include/self_update.h`, `include/neutrino_smb.h`, `include/smb_shares.h`, `include/smb2man.h`, `include/nfsman.h`, `include/smbd_devctl.h`
- Scripts: `scripts/gen_cloud_client.py` (64), `scripts/build_cloud_tls.sh` (77), `scripts/fetch_libsmb2.sh` (31)

### Read in part (targeted sections, cited as such)
- `src/init.c` — network/SMB-server/DNS sections only: `load_ps2ftpd` (~1170-1198), `loadNetModules`/`isFtpNetworkReady`/`startSmbServer`/`smbServerLogin`/`configureDashboardDns`/`ensureDashboardIpNetworkReady` (~2749-2950)
- `src/dash_tools.c` — update-check and cloud sections only: JSON helpers and CA-path (~700-830), update job/install flow (~830-1020), cloud menu/recovery call sites (grep-located)
- `src/dash_main.c` — PC receiver / remote-command poll wrappers only (~720-800)
- `src/config.c` — SMB-server credential lines only (706-707, 833-834, 1050-1053, via grep + excerpt)

### Not read, with reasons
- `iop/**` (smbd, smb2man, smbman, nfsman, ps2ftpd, udpfs drivers): IOP side, outside this section's EE scope. Consequences that depend on IOP behaviour are labelled INFERRED.
- `src/neutrino_gameid.c`, `src/dash_settings.c` (4096 lines), `src/main*.c`, `src/filer*.c`, `src/mmce_*.c`, `src/mc_*.c`: game-ID, settings UI, and storage code — outside the network/cloud scope except where grep showed a call site.
- Remaining `scripts/*` (font/SFX/packaging/wiki/metrics helpers): not generators feeding cloud code; `scripts/download_metrics.py`, `scripts/package_kit.py`, `scripts/ps2build_sdk.sh` were grep-checked only for token handling (see Checked-clean).
- `ee_libs/tcpips/ps2ipc.c`, `tests/**`, `docs/**`, `windows/cloud-relay/**`: support/test/doc material, not EE network runtime code in scope.

---

## Candidate findings (sorted by benefit)

### EENET-001 — Anonymous FTP is the unauthenticated transport for a remote ELF-launch command inbox
- **Category:** 2 (Security / credential handling)
- **Locations:** `src/init.c:1176-1183` (`load_ps2ftpd` passes `-anonymous`, optionally `-no-hdd`); `src/remote_control.c:86-88` (`EXECUTAR\t<path>` returns any path as `runpath`); `src/dash_main.c:766-790` approx. (poll wrapper: the only gates are HOME section, worker idle, and `isFtpNetworkReady()`; a path containing `:` is handed to `dashLaunchApp`); `src/pc_game_receiver.c:37-76,309-353` (same file-drop pattern accepts a job file that stages arbitrary-size files onto `ata0:`)
- **Problem:** The FTP server is started with anonymous access, and two file-drop protocols are polled whenever FTP is up: `PS2-COMANDO.TXT` can request launching an arbitrary ELF path (`EXECUTAR`), power-off, or OSDSYS, and `PS2-RECEBER.TXT` can start a bulk receive job. There is no credential, token, or source check anywhere in the EE path — possession of LAN access while the user has FTP running is the only requirement. The design intent (PC tools deliver these files over FTP, per the comments in `src/dash_main.c` and `src/pc_game_receiver.c`) makes FTP write access to `ata0:` part of the feature, so the command inbox inherits anonymous-FTP's trust level. INFERRED: the exact filesystem scope ps2ftpd exposes (which devices an anonymous client can read/write) is decided by the IOP module, which is out of this section's scope; the `ata0:` delivery path itself is verified from the EE code and comments.
- **Fix:** Require an opt-in for the command inbox separate from starting FTP (default off), and/or require the command/receiver files to carry a per-install token set in Settings and compared before consumption. Smallest viable change: gate `remoteCommandPoll`/`pcGameReceiverPoll` behind a new default-off setting so anonymous FTP alone no longer implies remote launch.
- **Justification if adds:** The setting/token is the smallest addition that breaks the anonymous-to-launch chain; no new protocol is needed.
- **Benefit:** High — removes a LAN unauthenticated arbitrary-ELF-launch path.
- **Effort:** M
- **Risk:** Low–Medium — PC companion tools must be told about the opt-in; file transfer over FTP is unaffected.
- **Confidence:** High for the EE chain (all lines read); Medium for full IOP filesystem scope (INFERRED).

### EENET-002 — Self-update truncates and overwrites the running ELF in place, with no recoverable copy
- **Category:** 7 (Error-path / failure-recovery robustness)
- **Locations:** `src/self_update.c:218-251` (`overwrite_elf`: `FIO_O_WRONLY | FIO_O_CREAT | FIO_O_TRUNC` on the running ELF's own path, then streamed write); `src/self_update.c:280-287` (a `.BAK` left by older builds is deleted; none is created); `src/self_update.c:351-358` (on write/close failure the result text itself says the ELF "may be damaged: copy the Launchstation ELF to this device again")
- **Problem:** The download itself is well verified before this point (SHA-256 checked in RAM at `src/self_update.c:291-303`, PSU structure and ELF magic checked before any write). But once `O_TRUNC` succeeds, any failure — power loss, card removal, a short write at step 2/3 — leaves a truncated, unbootable ELF as the only copy on the device. The pre-write free-space check (`src/self_update.c:341-348`) reasons about growth over the old ELF precisely because no second full copy ever exists.
- **Fix:** Write the verified ELF to a staging leaf in the same folder, verify its size (and re-hash or read-back) on disk, then swap: rename running → backup, rename staging → running, delete backup only after the new file verifies. If same-folder rename semantics on some device cannot be trusted, keep the downloaded package (already SHA-verified) on disk until the new ELF verifies, so a failed swap can be retried without a PC.
- **Justification if adds:** A rename/backup pair is the minimum mechanism that makes the one destructive step recoverable; everything else (download, hashing, PSU parsing) already exists.
- **Benefit:** High — a failed update currently bricks the install until the user re-copies the ELF from a PC; this makes it self-recovering.
- **Effort:** M
- **Risk:** Medium — rename behaviour differs across PS2 device drivers; needs per-device validation, ideally on real hardware.
- **Confidence:** High (mechanism fully read; failure consequence is stated by the code's own error text).

### EENET-003 — SMB file server ships with known default credentials `ps2`/`ps2`, stored and displayed in clear text
- **Category:** 2 (Security / credential handling)
- **Locations:** `src/config.c:833-834` (defaults: user and password both set to the same well-known value); `src/config.c:706-707` (both written in clear text to the config file); `src/init.c:2783-2816` approx. (`startSmbServer` copies them into the module args; `smbServerLogin` exposes them); `src/dash_smbd.c:23-24` (the running screen prints "User name: … Password: …" in clear text)
- **Problem:** The server shares both memory cards (`\\<ip>\mc0`, `\\<ip>\mc1` per `src/dash_smbd.c:20`) to the LAN. Anyone who knows this project's default — which is published in the source — can connect to a user who never changed it. The on-screen password print additionally exposes a user-chosen password to anyone who can see the TV. The only mitigation in the UI is the advice "Use a network you trust" (`src/dash_smbd.c:29`).
- **Fix:** On first SMB-server start with the default password still set, require the user to set a password (or generate and show a random one) before the server starts; stop printing the password on the status screen (show the user name and "password set" instead).
- **Justification if adds:** A first-run prompt is a small addition; removing the on-screen password is a deletion.
- **Benefit:** High for the default-install population — the server is otherwise one well-known credential away from full memory-card access.
- **Effort:** S–M
- **Risk:** Low — companion-PC workflows already type the credentials once.
- **Confidence:** High (all lines read; the default value is a credential the task's location-only rule does not cover — it is a published product default, not the cloud OAuth material).

### EENET-004 — Hand-rolled JSON string extraction is duplicated, and both copies mishandle escapes
- **Category:** 6 (Parser / network / file-format bounds)
- **Locations:** `src/cloud_google.c:61-107` (`json_string`); `src/cloud_google.c:109-122` (`json_int`, first-`strstr`-match companion); `src/dash_tools.c:715-745` (`releaseJsonString`, the second implementation); callers include OAuth token/device-code parsing (`src/cloud_google.c:389,599-612,642`), Drive `id` lookup (`src/cloud_google.c:744`), browse items (`src/cloud_google.c:815-825`), and the updater's release digest/commit parsing (`src/dash_tools.c:760-790,864,968`)
- **Problem:** One mechanism — "find `"key"`, scan to the closing quote" — exists twice with different bugs. (a) `json_string`'s end scan treats a quote as escaped whenever the previous byte is a backslash (`end[-1] != '\\'`, `src/cloud_google.c:84-88`), so a value ending in an escaped backslash (`"…\\"`) overruns into the following JSON and merges fields. (b) Neither copy decodes `\uXXXX`: `json_string`'s escape switch (`src/cloud_google.c:92-103`) falls through to copying the `u` literally, mangling non-ASCII Drive file names; `releaseJsonString` has no escape handling at all and ends the value at the first `"` even if escaped (`strchr(p, '"')`). (c) `json_string` silently truncates over-long values and still returns success, so a truncated token/ID is used as if valid. (d) Both search from the start of the body for the first key occurrence, which is only correct because callers happen to arrange the wanted object first.
- **Fix:** Replace both with one shared bounded extractor (e.g. in `cloud_http.c`/a small common unit) that tracks escape state correctly, decodes `\u` (at least to UTF-8 or a clean failure), and fails on truncation instead of returning a cut value. Delete the other copy.
- **Justification if adds:** No addition — a merge of two existing implementations into one, net deletion.
- **Benefit:** High — these parsers decide OAuth tokens, Drive file identity (including the `wle_sha256` recovery digest path), and the self-update's expected SHA-256/commit ancestry; a merged or truncated field lands directly in a trust decision.
- **Effort:** M
- **Risk:** Medium — many call sites; the host-test style already used for `smb_cnf.c` should be applied to the merged parser.
- **Confidence:** High.

### EENET-005 — SNTP clock sync uses a predictable transmit timestamp, and the RTC it sets is what TLS certificate validation trusts
- **Category:** 2 (Security / credential handling)
- **Locations:** `src/dash_clock_sync.c:149-152` (`nonce_hi = Timer() ^ constant`; `nonce_lo` is one LCG step from it — the whole 64-bit transmit timestamp is a function of the millisecond timer); `src/dash_clock_sync.c:207-215` (the only reply authentication is echo of that timestamp, plus stratum/mode checks); `src/dash_clock_sync.c:315-360` (`dashClockSyncInternet` writes the result to the RTC); `src/cloud_http.c:340-352` (TLS verify errors explicitly depend on "the PS2 date and time")
- **Problem:** SNTP is unauthenticated UDP. The origin-timestamp check is meant to bind the reply to the request, but the timestamp is predictable to anyone who can guess roughly when the user pressed "sync" (Timer() is milliseconds since boot). A LAN attacker who can spoof the pool server's address can set the console clock to any date in the accepted 2020-2100 window (`src/dash_clock_sync.c:229-233`). That clock is then the reference for X.509 expiry checks in the cloud/updater TLS path, so a shifted clock can make an expired certificate appear valid (or break all cloud access as a denial of service).
- **Fix:** Draw the transmit timestamp from the same conditioned entropy material the TLS stack already builds (`mbedtls_hardware_poll` inputs in `src/cloud_http.c`) instead of Timer() alone, and keep the existing stratum/era checks. This raises spoofing from "guess the boot-relative millisecond" to "guess 64 conditioned bits".
- **Justification if adds:** No new subsystem — it reuses entropy code that already exists in the same build.
- **Benefit:** Medium–High — protects the integrity anchor (wall-clock time) for every TLS decision the app makes.
- **Effort:** S
- **Risk:** Low.
- **Confidence:** High for predictability (lines read); Medium for exploitability in a given LAN (depends on attacker's ability to spoof the DNS-resolved server address — INFERRED network position).

### EENET-006 — Long-lived credentials are stored in clear text in ordinary config files on removable media
- **Category:** 2 (Security / credential handling)
- **Locations:** `src/cloud_google.c:317-355` (Google refresh token written as a plain `Refresh_Token = …` line to `WLE-CLOUD.TOK`, with a staged duplicate in `WLE-CLOUD.TOK.NEW`); `src/cloud_google.c:457-492` (custom OAuth client ID/secret written in clear text to `WLE-CLOUD.CNF`); `scripts/gen_cloud_client.py` + `src/cloud_google.c:20-27,229-241` (built-in OAuth client material — **location only**, no values reproduced); `src/smb_cnf.c` / `include/smb_shares.h:57-58` (SMB share user names/passwords held and persisted in clear text in `SMB2.CNF` / the `LAUNCHSTATION.CNF` share section)
- **Problem:** A Google refresh token is a durable, revocable-only-by-the-user credential for the `drive.file` scope. It, the client secret, and every SMB share password sit unprotected on a memory card/USB stick that other PS2 tools — and, while it runs, the anonymous FTP server of EENET-001 — can read. There is no secure storage on a PS2, so full encryption is not honestly available; the finding is about exposure surface and user awareness, not about a missing cipher.
- **Fix:** LESS NOT MORE options, in order: (1) document in the link flow itself that linking writes a reusable token to the card and that Disconnect (`cloudGoogleDisconnect`, `src/cloud_google.c:662-684`) is the revocation path; (2) ensure the token/config files are never inside any directory the built-in servers share by default; (3) do not keep the staged `.TOK.NEW` duplicate after a successful save (already done on the success path at `src/cloud_google.c:353` — keep that property under test).
- **Justification if adds:** Only (1) adds anything (UI text); (2)/(3) are placement/deletion.
- **Benefit:** Medium — bounds the blast radius of a lost card or an FTP session to what the user knowingly accepted.
- **Effort:** S
- **Risk:** Low.
- **Confidence:** High for storage format (lines read); the FTP readability of the settings folder specifically is INFERRED (depends on IOP FTP scope, see EENET-001).

### EENET-007 — cloud_http maintains two divergent HTTP response parsers; chunked detection is case-sensitive and Content-Length goes through `atoi`
- **Category:** 6 (Parser / network / file-format bounds)
- **Locations:** `src/cloud_http.c:501-526` (`header_value`: name match is case-insensitive, values are silently truncated to the caller's buffer); `src/cloud_http.c:560-680` (`read_response`: `strstr(value, "chunked")` case-sensitive at 597-599 and 658-659; `content_length = atoi(value)` at 596, 643-656); `src/cloud_http.c:953-1277` (`cloudHttpDownloadFdInternal`: a second, separate header/chunk/Content-Length implementation at 1122-1141 with stricter checks)
- **Problem:** The buffered path (all OAuth/Drive JSON and GitHub release JSON) and the streaming path (downloads) parse the same protocol differently. In the buffered path: a standards-legal `Transfer-Encoding: Chunked` (capital C) is not recognised, so raw chunk framing is handed to the JSON parsers as if it were the body; `Content-Length` is converted with `atoi`, whose behaviour on a value outside `int` range is undefined and which accepts trailing garbage; and a truncated `Location` value (over 2047 bytes) is silently used for the resumable-upload session URL. The streaming path already demonstrates the stricter pattern (explicit invalid-length rejection at 1122-1137).
- **Fix:** In `read_response`, match the transfer-coding case-insensitively, parse Content-Length with a bounded digit loop that rejects overflow/trailing characters (mirroring the streaming path), and fail instead of truncating when `Location` does not fit. Longer term, share the header-parsing helper between both paths.
- **Justification if adds:** No addition — alignment of the weaker parser with the stricter one already in the same file.
- **Benefit:** Medium — Google/GitHub currently send lowercase `chunked`, so this is latent; it becomes a hard failure (or a mis-parsed trust payload) the day a CDN in front of either changes casing or framing.
- **Effort:** S–M
- **Risk:** Low.
- **Confidence:** High.

### EENET-008 — Custom OAuth client override contradicts its own "complete pair" rule: an ID alone silently discards the built-in secret
- **Category:** 1 (Correctness bug)
- **Locations:** `src/cloud_google.c:227-241` (`load_client`: comment says a custom client is used "only as a complete pair", but the code returns as soon as `client_id[0]` is set, keeping whatever secret — including none — the file had); `src/cloud_google.c:205-212` (`builtin_client_available` likewise tests only the ID); `src/cloud_google.c:457-472` (`cloudGoogleSaveClientConfig` accepts an empty secret); `src/cloud_google.c:380-385` (`refresh_access_token` then omits `client_secret` from the token request when empty)
- **Problem:** A user who pastes only a custom client ID (or whose `WLE-CLOUD.CNF` loses its secret line) silently falls out of the working built-in configuration into a half-configuration: device-flow/refresh requests go out without the secret Google's device flow requires for this client type, and the failure surfaces only as a generic OAuth error far from the cause.
- **Fix:** Make `load_client` honour its comment: use the custom client only when both ID and secret are present; otherwise fall back to the built-in pair whole. Reject a secret-less save in `cloudGoogleSaveClientConfig` with a specific message.
- **Justification if adds:** No addition — a condition change in existing code.
- **Benefit:** Medium — turns a silent, confusing link failure into either correct behaviour or an actionable error.
- **Effort:** S
- **Risk:** Low — a deliberately secret-less public-client setup is not a flow this code supports elsewhere (the generator script enforces the pair the same way, `scripts/gen_cloud_client.py:31-34`).
- **Confidence:** High.

### EENET-009 — Dead file-based PSU extractors and the "historical" file download entry point have no production callers
- **Category:** 5 (Dead / half-finished code)
- **Locations:** `src/update_psu.c:183-211` (`selfUpdateExtractPsu`, `selfUpdateExtractPsuMem`); `src/update_psu.c:335-364` (`selfUpdateExtractPsuSidecar` file variant); declarations at `include/self_update.h:14-22`; `src/cloud_http.c:1279-1287` (`cloudHttpDownloadFd`, self-described in its comment as the "Historical self-update interface")
- **Problem:** Production update code uses only the RAM variants — `selfUpdateLocatePsuElf` and `selfUpdateExtractPsuSidecarMem` (`src/self_update.c:306,327,333`) and `cloudHttpDownloadMem`/`cloudHttpDownloadGoogleFd` for transport. A full-text search of `src/` in this pass found the file-based extractors and `cloudHttpDownloadFd` referenced only by the host test harness (`tests/test_app_packages.py`) — they are compiled into the EE binary, reviewed, and kept compiling for no runtime purpose, and the duplicated file-vs-memory `PsuIn` plumbing in `update_psu.c` exists largely to serve them.
- **Fix:** Delete `selfUpdateExtractPsu`, `selfUpdateExtractPsuMem`, `selfUpdateExtractPsuSidecar`, and `cloudHttpDownloadFd` (and their header declarations); keep the test harness exercising the RAM path it already also covers. If a future disk-based update is wanted, it can be reintroduced with its caller.
- **Justification if adds:** Pure deletion.
- **Benefit:** Medium — roughly 150 lines of parser-adjacent code leave the shipped binary and the review surface.
- **Effort:** S
- **Risk:** Low — verified no `src/` callers in this pass; the test file needs a small adjustment.
- **Confidence:** High.

### EENET-010 — IPv4 validation is implemented three times with divergent semantics; the Neutrino copy accepts the leading-zero forms the SMB parser deliberately rejects
- **Category:** 4 (Duplicated logic)
- **Locations:** `src/smb_cnf.c:149-171` (`isIpv4`: rejects leading zeros, with the comment at 162-163 explaining that `010` would reach the drivers' `inet_addr` as octal — a different host); `src/neutrino_smb.c:8-19` (`ipv4`: no leading-zero rejection) used at `src/neutrino_smb.c:55-58` when re-parsing the share URL for the Neutrino handoff; `src/config_network.c:86-124` (`ipStringToOctet`/`BuildOctets`: `atoi` per octet, no 0-255 range check at all)
- **Problem:** The same dotted-quad string can be valid for one subsystem and mean a different address in another. Concretely, a server string the browser validated under `smb_cnf.c` rules is re-parsed by `neutrino_smb.c` under weaker rules before being written into Neutrino's config (`src/neutrino_smb.c:130-187`), and the network-settings path accepts octet values the other two reject, persisting them into `IPCONFIG.DAT` (`src/config_network.c:56-66`).
- **Fix:** Keep the strictest implementation (`smb_cnf.c`'s, which documents the octal hazard) as the single validator and call it from `neutrino_smb.c`; range-check octets in `config_network.c` or route its parsing through the same helper.
- **Justification if adds:** No addition — two implementations deleted in favour of the existing strict one.
- **Benefit:** Medium — removes a wrong-host connection class and a source of "works in the browser, fails/differs in Neutrino" reports.
- **Effort:** S–M (header placement for the shared helper is the only friction; `smb_cnf.c` is deliberately host-testable).
- **Risk:** Low.
- **Confidence:** High.

### EENET-011 — TLS entropy callback always reports success, including when its only OS source failed and every other input is at its cold-boot value
- **Category:** 2 (Security / credential handling)
- **Locations:** `src/cloud_http.c:104-160` (`mbedtls_hardware_poll`: `getrandom` failure is zeroed and ignored at 127-129; the function returns 0/success unconditionally at 156-157); inputs are COP0 tick samples, `clock()`, the RTC, `Timer()`, a local counter, and network timing (`src/cloud_http.c:116-145`); wiring at `scripts/build_cloud_tls.sh:66` (`MBEDTLS_ENTROPY_HARDWARE_ALT`, `MBEDTLS_NO_PLATFORM_ENTROPY`)
- **Problem:** The code's own comment is honest that this is "defense-in-depth … not a claim that cpu_ticks is [a TRNG]". The residual defect is the failure contract: on a cold boot with a dead RTC battery (a common PS2 state — fixed default date, timer near zero, counter starting at 0), the material can be highly predictable across identical boots, yet the callback still presents a full-success entropy block to the CTR_DRBG that keys every OAuth/Drive/updater TLS session. SHA-256 conditioning mixes the inputs but cannot add entropy that is not there. INFERRED: the actual seed entropy on real hardware cannot be measured from this code; the finding is that nothing in the path can ever say "not enough entropy".
- **Fix:** Track whether at least one genuinely variable source contributed (e.g. `getrandom` returned bytes, or network timing jitter above a floor) and return `MBEDTLS_ERR_ENTROPY_SOURCE_FAILED` when none did, letting the existing TLS error path report it instead of silently keying a session.
- **Justification if adds:** A few lines in one function; no new mechanism.
- **Benefit:** Medium — converts a silent weak-key risk into a visible, retryable failure.
- **Effort:** S
- **Risk:** Medium — a too-strict floor could block cloud features on healthy hardware; the threshold needs hardware validation.
- **Confidence:** Medium (contract verified in code; real-world seed quality INFERRED).

### EENET-012 — BCD and calendar conversions are duplicated inside dash_clock_sync.c, with two different day-count algorithms
- **Category:** 4 (Duplicated logic)
- **Locations:** `src/dash_clock_sync.c:251-259` (`toBcd`/`fromBcd`) vs `src/dash_clock_sync.c:377-385` (`manualToBcd`/`manualFromBcd` — byte-identical bodies); `src/dash_clock_sync.c:219-249` (`civilDays`/`civilFromDays`, era arithmetic) vs `src/dash_clock_sync.c:392-412` (`dashClockDaysInMonth` + `manualSerialSeconds`, year-by-year loops)
- **Problem:** The SNTP path and the manual-entry path each grew their own copy of the same conversions. The BCD pairs are literal duplicates; the date paths implement the same civil-date math two ways, so a fix to leap-year or range handling in one (both feed verified RTC writes, at 291-313 and 414-482) can silently miss the other.
- **Fix:** Delete the `manual*` BCD pair and call `toBcd`/`fromBcd`; express `manualSerialSeconds` via `civilDays` (plus seconds-of-day) and delete the loop version.
- **Justification if adds:** Pure deletion within one file.
- **Benefit:** Low–Medium — small, but it is exactly the kind of drift that produced divergent validators elsewhere in this section (EENET-010).
- **Effort:** S
- **Risk:** Low — both RTC paths have read-back verification, so a conversion slip is caught at runtime.
- **Confidence:** High.

### EENET-013 — The ps2ipc socket ABI block (externs, hostent view, sockaddr view, htons) is copy-pasted between the TLS and SNTP clients
- **Category:** 4 (Duplicated logic)
- **Locations:** `src/cloud_http.c:37-75` (extern declarations, `CloudHostEnt`, `CloudSockaddrIn`, `cloud_htons`); `src/dash_clock_sync.c:22-48` (the same externs, `SntpHostEnt`, `SntpSockaddrIn`, `sntpHtons`)
- **Problem:** Both network clients hand-declare the same PS2IPS RPC surface because the internal header is not installed (explained at `src/cloud_http.c:37-40`). The copies can drift independently — a struct-layout or prototype fix in one client will not reach the other, and on this ABI a drift is a wire-format bug, not a style issue.
- **Fix:** Hoist the declarations into one small internal header (e.g. `include/ps2ipc_abi.h`) included by both `.c` files, and delete both private copies.
- **Justification if adds:** One header replaces two blocks; net deletion.
- **Benefit:** Low–Medium — prevents a future one-sided ABI fix.
- **Effort:** S
- **Risk:** Low.
- **Confidence:** High.

---

## Checked-clean notes (read and deliberately not flagged)

- **TLS verification posture** (`src/cloud_http.c:386-520` approx.): `VERIFY_REQUIRED`, hostname set, verify-result checked after handshake, CA either built-in Google roots (`include/cloud_google_roots.h`, four GTS roots) or a user PEM capped at 256 KiB (`read_file`). No verify-off path exists.
- **Bearer-token containment** (`src/cloud_http.c:953-1010,1030-1045`): the Drive downloader only accepts an initial `https://www.googleapis.com/drive/v3/files/` URL, rejects tokens containing CR/LF or over 2048 bytes, sends `Authorization` only to `www.googleapis.com` exactly, and re-validates every redirect host against `*.googleusercontent.com`/Google API hosts. Redirects are capped at 6, HTTPS-only, with relative-redirect handling that fails closed.
- **Resumable-upload location check** (`src/cloud_google.c:1240-1246,1330-1350` approx.): the upload `Location` must begin `https://www.googleapis.com/` (the trailing slash defeats look-alike-host prefixes) before the bearer-headed `PUT` is issued.
- **Recovery downloads** (`src/cloud_google.c:982-1200` approx.): snapshot/save recovery requires a valid Drive ID shape, a 64-hex SHA-256 in Drive metadata, digest equality over the downloaded bytes, and format validation (card geometry / `.psu` entries) before publishing under a fresh `RECOVER-CLOUD-###` name; nothing overwrites an existing file.
- **Drive query construction** (`src/cloud_google.c:125-205,700-760`): names/parents are quote-escaped (`q_escape`), form fields and query strings are percent-encoded (`append_url`/`form_field`), and folder/file IDs are shape-checked (`drive_safe_id`) before reuse.
- **SMB connect hygiene** (`src/smb_shares.c:230-330` approx.): SMB2 connect clears the credentials struct after the devctl; SMB1 uses hashed (LM/NTLM) logon by default and only sends clear text when the share explicitly opts in with `PLAINTEXT = 1`; failed SMB1 share-open logs off so no half-session remains. `smb_cnf.c` itself is unusually careful: values that do not fit are rejected with a named problem instead of truncated, ports are range-checked digit-by-digit, and duplicate/reserved names are rejected.
- **PSU package parser** (`src/update_psu.c:60-180`): entry counts are restricted to the known 4/6/10/11 shapes, every record's length and 1 KiB padding are bounds-checked against the package size before seeking, duplicate entries are rejected via the `seen` bitmask, and the extractor requires the final position to equal the package size exactly. Sidecar extraction additionally magic-checks the CA PEM and BGM headers.
- **Update ordering** (`src/dash_tools.c:830-1020`): the updater fetches the release's expected SHA-256 and size from the GitHub API over the same verified TLS channel, refuses diverged commit ancestry outright, and confirms with the user before installing an older/same release.
- **SNTP reply validation** (apart from EENET-005): mode/stratum/era checks, 2020-2100 acceptance window, timer-restart detection, and RTC read-back verification within 2 s (`src/dash_clock_sync.c:195-360`).
- **FTP control channel** (`src/ftp_session.c`): DMA buffers are static and generation-checked across IOP resets; a timed-out RPC is never reused while it may still complete, and abandoning the session requires explicit user confirmation in `src/dash_ftp.c:56-71`.
- **Entropy-adjacent script hygiene**: `scripts/gen_cloud_client.py` validates both env values against a strict character whitelist and the client-ID suffix before writing the generated header, and refuses a half-set pair; `scripts/build_cloud_tls.sh` pins the Mbed TLS archive by SHA-256 and verifies it before building; `scripts/fetch_libsmb2.sh` pins an exact commit and verifies it after checkout; `scripts/ps2build_sdk.sh` keeps its mirror token off the command line (fed to curl via stdin config) and unsets it before invoking subprocesses. `scripts/download_metrics.py` takes its token from the environment only. No secret values were printed in any of these files.
- **DNS setup** (`src/init.c`, `configureDashboardDns`): an existing (e.g. DHCP-assigned) resolver is never overwritten; the gateway-derived primary and public fallbacks are only installed when no server is configured.
- **Chunked decoders' bounds** (`src/cloud_http.c:528-558,871-950`): both the buffered `decode_chunked` and the streaming `download_chunked_consume` bound chunk sizes against the remaining buffer/space before copying, and the streaming path enforces `max_bytes` before every write, including the RAM sink used by the updater.
