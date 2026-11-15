# LNCHA — launcher/ server-management and platform layer (blind redo)

Repo: PS2-Servers @ c5f021c4d38698860f56b03498adc261dbb8d8dd. All executions ran with
`PYTHONDONTWRITEBYTECODE=1` against the read-only clone; no clone file was edited.
No finding in this section rests on a UDP `sendto` failure, so none is BLOCKED-ENV.

---

### LNCHA-01 — SMBv2/SMBv3 argv builder crashes on `root_dir`-only values and silently emits an empty share, where SMBv1 accepts and validates
- **Category:** 6
- **Locations:** launcher/servers.py:127-137 (`_smb_argv`: folder is `v.get("games_folder") or v.get("root_dir")`, empty folder raises `ValueError("SMB server requires a Games folder to share.")`); launcher/servers.py:176-179 (`_smb2_argv`: `"{}={}".format(share, v["games_folder"])` — direct indexing, no fallback, no emptiness check)
- **Problem:** The two SMB argv builders disagree on the same saved-config vocabulary. Executed: `SMBV1.build_argv({"root_dir": "/games"})` → `['--share', 'games=/games', '--smb-version', '1']`, but `SMBV2.build_argv({"root_dir": "/games"})` raises `KeyError: 'games_folder'` (an unhandled crash, not the friendly ValueError the GUI surfaces for SMBv1), and `SMBV2.build_argv({"games_folder": ""})` silently returns `['--share', 'games=', '--smb-version', '2']` — an empty share root handed to the server — where SMBv1 raises the clear ValueError. Any config source that supplies the folder under `root_dir` (the key UDPFS/HTTP/NFS all use), or an empty string, behaves differently per SMB dialect for no protocol reason.
- **Fix:** Make `_smb2_argv` resolve the folder exactly as `_smb_argv` does (`games_folder` or `root_dir`, stripped) and raise the same ValueError when empty.
- **Benefit:** One folder vocabulary across all folder servers; a bad config produces the designed error message instead of a KeyError traceback or a server started on an empty share.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### LNCHA-02 — Windows/Linux firewall port list still keys UDPFS single-port mode off the retired `modulo_mode` setting, so a migrated config silently gains a dead data-port rule
- **Category:** 6
- **Locations:** launcher/windows_setup.py:146-157 (data-port rule skipped only `if not values.get("modulo_mode")`); launcher/servers.py:271-299 (`migrate_saved` deletes `modulo_mode`, replacing it with `enforce_modulo=True` + `protocol_mode`); launcher/servers.py:344-350 (`_udpfs_argv` treats `enforce_modulo` or `protocol_mode == "modulo"` as single-port Modulo)
- **Problem:** This is a config round-trip that silently changes behaviour on save. `migrate_saved` exists precisely because a key with no widget is dropped on the next save — so after migration, no value dict the current GUI produces can ever contain `modulo_mode` again. Yet `windows_setup._server_ports` suppresses the UDPFS data-port rule only for that retired key. Executed: `server_ports("udpfs", {"enforce_modulo": True, "protocol_mode": "Legacy / Modulo only", "data_port": 40000})` and `server_ports("udpfs", {"protocol_mode": "modulo", "data_port": 40000})` both return the data port 40000 as a second rule; only `{"modulo_mode": True, ...}` suppresses it. In Modulo (single-port) mode the server ignores the data port (per the comment at windows_setup.py:148-153 itself), so a user who pinned a data port and later ticks Enforce Modulo — or whose legacy config was migrated — gets a Windows allow rule and a Linux hint line (via posix_firewall, which reuses this list) for a port nothing ever listens on.
- **Fix:** Test the current vocabulary in `_server_ports`: suppress the data-port rule when `values.get("enforce_modulo")` or the protocol mode resolves to modulo (reuse `servers.protocol_mode_value`), keeping the legacy `modulo_mode` check for un-migrated dicts.
- **Benefit:** The firewall surface matches what the server actually binds; the migration stops changing firewall behaviour as a side effect.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### LNCHA-03 — NFS and RetroAchievements never get the cooperative stop pipe, so on Windows Stop kills them outright — skipping NFS cleanup and orphaning the RetroAchievements engine child
- **Category:** 6
- **Locations:** launcher/servers.py:72-77 (the `cooperative_stop` contract: child "unwinds on the launcher's stop pipe … which on Windows is the only way its shutdown code … gets to run"); set at launcher/servers.py:387, 436, 452, 468, 568, 659 (SMBv1, SMBv2, SMBv3, UDPFS, HTTP, UDPBD) but absent from launcher/servers.py:624-652 (NFS) and launcher/servers.py:712-746 (RetroAchievements); launcher/process.py:114-178 (`request_stop` returns False for non-cooperative children, `stop()` falls through to `terminate()`); nfs4_server/nfs4_server.py:1094-1110 (cleanup exists: `finally: server.stop()`, plus its own SIGTERM→KeyboardInterrupt hook); launcher/achievements.py:362-410 (SIGINT/SIGTERM `stopped` event, engine subprocess supervised in a loop, `finally` closes viewer/bridge/lease and unlinks the account-port file)
- **Problem:** Both excluded servers have shutdown code that only runs on a graceful unwind, exactly like the six included ones. NFS's `main()` stops the server in a `finally`; the achievements process terminates its bundled engine subprocess, closes the Caduceus bridge/viewer, closes its service lease and removes its account-port file in a `finally`. With `cooperative_stop=False`, the launcher starts them with stdin=DEVNULL and no stop-pipe env, so on Windows Stop is `TerminateProcess`: NFS cleanup never runs, and the achievements engine child — a separate process the launcher does not track — is left running holding UDP 18194, so the next RetroAchievements start collides with the orphan. On POSIX the same Stop happens to work because `terminate()` delivers SIGTERM and serve.py's handler converts it — so stop behaviour for these two servers silently depends on the OS.
- **Fix:** Verify each of the two servers wakes on stdin EOF while idle (the check the flag's own comment requires), then set `cooperative_stop=True` on both ServerDefs; if either fails the wake-up check, fix that server's wait loop rather than leaving the flag off.
- **Benefit:** Stop means the same thing on every OS; no orphaned engine process holding the RetroAchievements port after the launcher says "stopped".
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ for the flag/process mechanism; INFERRED for the Windows orphan consequence, from the documented TerminateProcess semantics in launcher/process.py:14-18 and launcher/serve.py:84-93)

### LNCHA-04 — Choice-field values have no single stored vocabulary: the RetroAchievements mode default is the wire value while the other two choice fields default to display labels, and three separate tolerant readers compensate
- **Category:** 6
- **Locations:** launcher/servers.py:720 (RA `mode` Field `default="xerabora"` — the wire value; its choices are `("xeRAbora", "xerabora"), ("Caduceus", "caduceus")` at launcher/servers.py:686); contrast launcher/servers.py:485 (UDPFS `protocol_mode` default `"Auto (recommended)"` — a label) and launcher/servers.py:581-582 (HTTP `catalog_profile` default `"Legacy flat (OPL-HTTP)"` — a label); tolerant readers at launcher/servers.py:689-695 (`_achievements_argv` label-or-wire map), launcher/servers.py:302-312 (`protocol_mode_value`), launcher/servers.py:526-531 (`http_profile_value`), launcher/windows_setup.py:134-139 (mode tested against both `"caduceus"` and `"Caduceus"`); launcher/gui.py:881-885 converts wire→label on restore for UDPFS `protocol_mode` only — no equivalent conversion exists for `mode` or `catalog_profile`; launcher/servers.py:293-298 (`migrate_saved` writes a third spelling, `"Modulo"`, which is neither the label `"Legacy / Modulo only"` nor the wire value `"modulo"`)
- **Problem:** Executed census of the three choice fields: `protocol_mode` default is a label, `catalog_profile` default is a label, `mode` default is a wire value that does not appear in its own combobox's label list. The GUI choice widget is filled with labels, so an untouched RetroAchievements card persists `"xerabora"` while a touched one persists `"xeRAbora"` — the same setting round-trips through config in two spellings depending on whether the user opened the dropdown. Every downstream reader has grown its own case/spelling tolerance to cope (three converter functions in servers.py, a dual-spelling tuple in windows_setup.py, a UDPFS-only restore conversion in gui.py), and each new reader must remember to be tolerant or it silently misreads the setting (as LNCHA-02 shows one did).
- **Fix:** Pick the label as the one stored vocabulary for all choice fields (it is what the widget holds): change the RA `mode` Field default to `"xeRAbora"`, and let `migrate_saved`-style normalisation — not per-reader tolerance — handle legacy wire spellings at load. The existing converters can then shrink to the load path.
- **Benefit:** A saved setting means the same thing to every reader; the class of bug in LNCHA-02 (a reader keyed to the wrong spelling) stops recurring.
- **Effort:** M · **Risk:** Med · **Confidence:** High (EXECUTED — field-default census and per-spelling argv/firewall outputs)

### LNCHA-05 — The SMB port default lives in three places and one of them is wrong: the firewall layer defaults SMBv2/SMBv3 to 1025, the servers default to 1445
- **Category:** 6
- **Locations:** launcher/windows_setup.py:142-144 (`port = 445 if take_445 else _parse_port(values.get("port"), 1025)` — one default for all three SMB servers); launcher/servers.py:211-218 (`_SMB2_FIELDS` port Field `default=1445`, used by both SMBV2 and SMBV3); launcher/servers.py:386-441 (SMBV1 `default_port=1025` vs SMBV2 `default_port=1445`)
- **Problem:** `windows_setup.server_ports` is documented as the "one source so the two never disagree" (launcher/windows_setup.py:124-129), but executed: `server_ports("smbv2", {})` and `server_ports("smbv3", {})` both return `[("TCP", 1025, ...)]` while the servers themselves listen on 1445 when no port is supplied. The GUI normally always supplies a port, which is why this stays latent — but any caller passing a sparse/hand-edited/older saved dict gets firewall rules (and Linux hint lines) for a port the server is not on, and the setup fingerprint is computed from the same wrong list. The default also exists a third time as literals in the GUI's hint/status helpers, so there are three places to keep in step.
- **Fix:** Take the fallback default from the registry (`REGISTRY[key].default_port`) in `_server_ports` instead of the hard-coded 1025.
- **Benefit:** Firewall rules and hints follow the server definition by construction; one less hand-synced constant.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### LNCHA-06 — `raw_storage` runs bare `powershell.exe` from PATH/CWD while every other PowerShell call site in the repo resolves the absolute System32 path specifically to prevent binary hijacking
- **Category:** 6
- **Locations:** launcher/raw_storage.py:358-367 (`argv = ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", ...]`, `creationflags=0x08000000`); the hardened pattern at launcher/windows_setup.py:57-90 (`_powershell_executable` docstring: "Resolving the bare name ``powershell`` via PATH/CWD could run an attacker-placed ``powershell.*`` … (binary hijacking)"), and the same absolute-path resolution copied at smbv1_server/smbserver_opl.py:1553-1563 and smb2_server/smb2_server.py:1496-1502
- **Problem:** The repo has an explicit, documented security rule for invoking PowerShell, and the raw-device metadata path — which runs an elevated-adjacent disk-enumeration script (`Get-Disk`/`Get-Partition`/`Get-Volume`) whenever a user lists or opens a raw drive — is the one call site that does not follow it. A `powershell.exe` planted in the working directory or an early PATH entry would be executed instead of the system interpreter. Census (scripted grep for `WindowsPowerShell` / `powershell.exe` across launcher + standalone servers): 3 absolute-path resolutions, 1 bare-name invocation.
- **Fix:** Call `windows_setup._powershell` (or its executable resolver) from `raw_storage._metadata` instead of building a bare-name argv; the function already sets the hidden-window flags raw_storage hand-rolls as `0x08000000`.
- **Benefit:** One hijack-resistant invocation path for all PowerShell use; also removes raw_storage's hand-copied hidden-window flag.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### LNCHA-07 — `netinfo.best_lan_ip()` returns the default-route address unconditionally, bypassing the private-LAN ranking the module exists to apply
- **Category:** 6
- **Locations:** launcher/netinfo.py:1-8 (module contract: "We deliberately prefer real private-LAN ranges (192.168/x, 10/x, 172.16-31/x) over VPN / WSL / link-local addresses"); launcher/netinfo.py:84-93 (`primary_ip`: UDP-connect to 8.8.8.8, i.e. whatever the default route is); launcher/netinfo.py:122-131 (`_lan_rank`); launcher/netinfo.py:224-234 (`best_lan_ip`: returns `primary_ip()` whenever it is not loopback; the ranked candidate list is consulted only when the primary is 127.x); launcher/netinfo.py:107-120 (`all_ipv4` also adds `primary_ip()` unconditionally)
- **Problem:** The ranking that implements the module's stated purpose is effectively dead in the common case: it runs only when the machine has no default route at all. With a full-tunnel VPN up — the exact case the header warns about ("NOT a VPN/WSL address", quoting the SMBv1 server's own warning) — the default route *is* the VPN, so `primary_ip()` returns the tunnel address and `best_lan_ip()` returns it without ever consulting `_lan_rank` or the interface list. That address is what the GUI pre-fills as the IP to type into OPL (gui.py uses `best_lan_ip()` for the LAN-IP field), so the user is handed the one address the PS2 cannot reach.
- **Fix:** In `best_lan_ip`, prefer the best-ranked private candidate from `all_ipv4()` and fall back to `primary_ip()` only when no private candidate exists (or when the primary is itself the top-ranked private address).
- **Benefit:** The pre-filled LAN IP matches the module's documented preference; the VPN case stops producing an unreachable suggestion.
- **Effort:** S · **Risk:** Low · **Confidence:** Med (INFERRED — the logic path is read directly; no VPN was available in the sandbox to execute against)

### LNCHA-08 — Port-445 takeover is two divergent full implementations (SMBv1 and SMBv2 servers), with the PowerShell-resolution helper copied a third time in the launcher
- **Category:** 2
- **Locations:** smbv1_server/smbserver_opl.py:1546-1648 (`_take_445`: stop LanmanServer, wait, restore); smb2_server/smb2_server.py:1479-1652 (`take_445` + `listen_after_take_445`: same LanmanServer stop/wait/restore, plus srv/srv2/srvnet driver handling and foreign-dependent checks the SMBv1 copy lacks); absolute-PowerShell-path resolution at launcher/windows_setup.py:57-71, smbv1_server/smbserver_opl.py:1553-1560, smb2_server/smb2_server.py:1496-1502
- **Problem:** One mechanism — "pause Windows file sharing, bind 445, restore on exit" — exists as two independent implementations that have already drifted: the SMBv2 copy learned to pause the SMB kernel drivers and to refuse when foreign services depend on LanmanServer; the SMBv1 copy did not, so the two servers behave differently for the same user-facing "Take port 445" checkbox built from near-identical launcher fields. Any future fix to the takeover/restore dance (the riskiest code in either server — it stops a Windows service) must be made twice, and the drift shows it already hasn't been. The small security-critical helper both need (absolute PowerShell path) is likewise copied per file instead of shared, which is how LNCHA-06's bare-name call site happened elsewhere.
- **Fix:** Move `take_445`/restore and the PowerShell resolver into one shared module both servers import (precedent exists: udpbd_server imports `launcher.raw_storage`/`launcher.virtual_exfat`, http_server imports `launcher.session_stats`), keeping SMBv2's stricter driver/dependent behaviour as the single behaviour.
- **Benefit:** One takeover implementation to verify on hardware; SMBv1 gains the driver/dependent safety the SMBv2 copy already proved necessary.
- **Effort:** L · **Risk:** Med · **Confidence:** High (READ)

### LNCHA-09 — The GUI's theme, admin panel and log trimming live as a ~300-line monkeypatch shim in the entry point, and its copy of `_append_log` has already drifted from gui.py's original
- **Category:** 8
- **Locations:** launcher/main.py:107-409 (`_apply_gui_review_fixes`: wraps `ttk.Notebook`, `LauncherApp.__init__`, `LauncherApp._build`, replaces `LauncherApp._append_log`, injects the admin panel and the full ttk palette); launcher/main.py:393-406 (patched `append_log`); launcher/gui.py:3042-3053 (the original `_append_log` it replaces)
- **Problem:** This is a half-finished migration kept as runtime patching ("This stays as a runtime shim so release-risk remains low", main.py:112-113). The file's own comments record the cost: window sizing and the scrolling body *were* also patched here and had to be de-duplicated because "keeping a second copy here only gave the two a way to disagree" (main.py:130-145, 291-295). The log function is the remaining second copy, and it has already drifted by exactly one behaviour: the patched version scrolls only when the view was already at the bottom (`yview()[1] >= 0.99`), gui.py's original scrolls unconditionally — so the effective behaviour of the app depends on which copy a reader happens to open, and a fix applied to gui.py's version silently does nothing. The guard flag (`_ps2_gui_review_fixes_patched`) also means the patch set is invisible to anyone reading gui.py alone.
- **Fix:** Finish the migration the file already started for sizing: move `apply_theme`, the admin panel, `StyledNotebook` and the at-bottom `append_log` into gui.py (where the palette already has a single owner, launcher/theme.py), and delete `_apply_gui_review_fixes`.
- **Benefit:** One copy of each behaviour, in the file a maintainer edits; the drift class the comments describe stops recurring.
- **Effort:** M · **Risk:** Med · **Confidence:** High (READ)

### LNCHA-10 — The native-binary launch mechanism in the registry is dead: no registered server uses it
- **Category:** 1
- **Locations:** launcher/servers.py:70 (`binary_rel` field, never populated by any ServerDef); launcher/servers.py:87-93 (`resolve_binary`); launcher/servers.py:96-111 (`is_available` native branch, `launch_command` native branch); launcher/serve.py:156-159 (the "native server; run its binary directly" rejection); census: all 8 REGISTRY definitions declare `runtime="python"` (launcher/servers.py:386, 435, 451, 467, 567, 631, 658, 717), and a scripted grep for `binary_rel`/`resolve_binary` across launcher + tests returns only the declaration and its own methods
- **Problem:** A complete second launch path — per-OS binary resolution, availability checks, a separate serve.py rejection — exists for a `runtime="native"` server kind that no server in the registry has. It is untested by construction (nothing can reach it) and every reader of ServerDef must reason about a branch that cannot execute.
- **Fix:** Delete `binary_rel`, `resolve_binary`, and the native branches of `is_available`/`launch_command` (keep the `runtime` field itself only if a caller still reads it); re-add when a native server actually lands.
- **Benefit:** The registry shrinks to the one launch mechanism that exists; no untestable branch in the start path.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ, census by script)

### LNCHA-11 — SIGTERM→KeyboardInterrupt stop handling is installed three times: once by serve.py for every launcher child, and again inside the HTTP and NFS servers
- **Category:** 2
- **Locations:** launcher/serve.py:79-102 (`install_stop_handlers`, called for every `--serve` child at launcher/serve.py:158); http_server/http_server.py:1220-1233 (`_stop_on_sigterm`, near-verbatim); nfs4_server/nfs4_server.py:1101-1110 (`_stop_on_sigterm`, near-verbatim)
- **Problem:** In launcher mode the same mechanism is installed twice for HTTP and NFS: serve.py installs its handler first, then the server's `main()` overwrites it with its own identical one (serve.py additionally covers SIGBREAK, which the per-server copies omit — so the effective handler set differs by entry point). The per-server copies exist for standalone runs, but nothing states that, and a change to the launcher's stop semantics (e.g. a new signal) must be mirrored by hand into each server that copied the snippet.
- **Fix:** Keep the standalone copies only where a server genuinely runs outside the launcher, and note that in one line at each copy; or have HTTP/NFS import the installer from the launcher package as other servers already import `launcher.session_stats` / `launcher.raw_storage`.
- **Benefit:** Stop semantics defined once; SIGBREAK coverage stops depending on which entry point started the server.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### LNCHA-12 — The stop-pipe environment name is a duplicated string literal in the two files whose agreement the whole cooperative-stop mechanism depends on
- **Category:** 2
- **Locations:** launcher/process.py:19 (`STOP_PIPE_ENV = "PS2SERVERS_STOP_PIPE"`); launcher/serve.py:72 (`STOP_PIPE_ENV = "PS2SERVERS_STOP_PIPE"  # launcher/process.py sets it`)
- **Problem:** The producer (process.py sets the env var) and the consumer (serve.py pops it to decide whether to arm the stdin watcher) each define the constant independently. If either string is edited, cooperative stop silently stops working — no error, servers just go back to being hard-killed on Windows, which is the failure mode the mechanism exists to prevent (see LNCHA-03). serve.py already imports from the launcher package at call time (`from .servers import REGISTRY`), so a shared definition costs nothing.
- **Fix:** Define `STOP_PIPE_ENV` once (in process.py, as the comment already claims) and import it in serve.py.
- **Benefit:** The stop contract cannot drift apart silently.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### LNCHA-13 — Three `_parse_port` implementations with three different failure semantics
- **Category:** 2
- **Locations:** launcher/windows_setup.py:115-121 (unparseable → caller-supplied default); launcher/status_client.py:68-75 (unparseable/empty/False → 0, i.e. "do not query"); udpfs_server/udpfs_server.py:3378-3383 (unparseable or out-of-range → raise ValueError)
- **Problem:** The same-named helper means three different things depending on which file a maintainer is reading: fall back, give up, or fail hard. The two launcher copies both accept hex via `int(str(v), 0)` and both swallow the same exceptions, yet return different sentinels — a reader moving code between the firewall path and the status-poll path (both consume the same saved `port` values) can silently change behaviour. This is the same vocabulary-drift pattern as LNCHA-04/05 at function scale.
- **Fix:** One launcher-side parser with an explicit `default` parameter (windows_setup's shape) used by status_client too; the UDPFS server's raising variant stays, renamed or commented as the strict CLI parser it is.
- **Benefit:** Saved port values are interpreted one way in the launcher; the strict server parser stops masquerading as the same helper.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ, census by script: exactly 3 definitions repo-wide)

### LNCHA-14 — Interface-address parsing is implemented four times across netinfo and directlink, including two different functions with the same name
- **Category:** 2
- **Locations:** launcher/netinfo.py:28-41 (`_parse_linux_ip_addr`); launcher/netinfo.py:44-60 (`_parse_macos_ifconfig` → returns a list of IPs); launcher/netinfo.py:172-183 and 185-198 (`get_all_adapters_info` re-parses the same `ip -o -4 addr show` and `ifconfig` output inline instead of calling the two helpers above it in the same file); launcher/directlink.py:356-... (`_parse_linux_adapters`, a third Linux parser, for `ip -j` JSON); launcher/directlink.py:460-476 (`_parse_macos_ifconfig` — same name as netinfo's, different signature and return: `(status, [{ip, prefix, origin}])`)
- **Problem:** The virtual-interface exclusion list and the inet-line grammar live in several parsers that must agree on what counts as a usable LAN address; the same-name pair is a standing trap — importing the wrong `_parse_macos_ifconfig` (or assuming the two are interchangeable in a refactor) yields a type error at best and wrong adapter data at worst. netinfo's inline copies already differ in detail from its own helpers (the inline macOS branch tracks the current interface header itself; the helper does the same — duplicated logic, two places to fix a parsing edge).
- **Fix:** Have `get_all_adapters_info` build on netinfo's own `_parse_linux_ip_addr`/`_parse_macos_ifconfig` output (extended to carry the interface name), and rename directlink's parser (e.g. `_parse_macos_ifconfig_block`) to end the name collision.
- **Benefit:** One inet-line grammar per OS in the launcher; no same-name/different-shape functions across sibling modules.
- **Effort:** M · **Risk:** Low · **Confidence:** High (READ)

### LNCHA-15 — DHCP option-TLV parsing is written twice inside directlink.py because `parse_packet` cannot be reused for replies
- **Category:** 2
- **Locations:** launcher/directlink.py:1100-1125 (`parse_packet`: BOOTP unpack + option TLV loop at 1110-1120); launcher/directlink.py:1272-1315 (`_foreign_offer_server_id`: hand-rolled BOOTP header checks + a second copy of the same TLV loop at 1294-1304)
- **Problem:** `_foreign_offer_server_id` re-implements the header validation and the option walk (pad/end handling, length slicing) that `parse_packet` already does, solely because `parse_packet` rejects `op != 1` replies. Two copies of a wire-format parser in one file will drift — a bounds or option-handling fix applied to the request parser (the one tests exercise through `handle_packet`) does not reach the foreign-server detector, which is a safety path (it is what refuses to run on a real network).
- **Fix:** Extract the option-TLV walk into one small helper used by both, and let `parse_packet` take the expected op (or return the raw op) so the reply path reuses the header validation too.
- **Benefit:** The safety-critical probe parses packets with the same, tested code as the responder.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### LNCHA-16 — Frozen-executable probing is duplicated between config.py and servers.py
- **Category:** 2
- **Locations:** launcher/config.py:20-29 (`_app_dir`: probes `NUITKA_ONEFILE_BINARY`, then `sys.argv[0]`, existence-checks each, falls back to `sys.executable`); launcher/servers.py:22-33 (`frozen_self_exe`: the same probe sequence for the same purpose)
- **Problem:** Both functions answer "where is the real program file in a frozen build" by walking the same candidate list with the same existence check — the subtle part (Nuitka onefile's inner exe vs the outer binary) is exactly the part that must not diverge, because config placement and server re-exec must agree on the program's folder. elevate.py, windows_setup.py and main.py all import the servers.py copy; config.py is the lone re-implementation.
- **Fix:** Have config.py derive its app dir from `servers.frozen_self_exe()` (servers.py imports nothing from the launcher package, so no cycle), or move `frozen_self_exe` into config.py and import it from servers.py.
- **Benefit:** One definition of the frozen-program location for both config storage and re-exec.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### LNCHA-17 — SMBV2 and SMBV3 share one mutable `fields` list object
- **Category:** 2
- **Locations:** launcher/servers.py:211 (`_SMB2_FIELDS = [...]`); launcher/servers.py:441 and 457 (`fields=_SMB2_FIELDS` for both SMBV2 and SMBV3 — executed: `SMBV2.fields is SMBV3.fields is _SMB2_FIELDS` is True)
- **Problem:** Sharing the definition list is intentional (one protocol, two dialects), but sharing the *same list object* means any in-place mutation — a future field addition for SMBv3 only, a test that appends, GUI code that sorts or filters in place — silently changes the other server's card too. The two ServerDefs already diverge where they should (separate `_build_argv` wrappers, separate labels/blurbs); the fields list is the one place the sharing is by reference rather than by construction.
- **Fix:** Pass a copy per server (`fields=list(_SMB2_FIELDS)`), keeping the single source list.
- **Benefit:** SMBv2/SMBv3 cards can diverge later without a shared-mutation surprise; no behaviour change today.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED — identity check)

### LNCHA-18 — Virtual exFAT construction recomputes the full 65,536-entry Unicode upcase table on every instantiation (~130-180 ms for a one-file folder)
- **Category:** 5
- **Locations:** launcher/virtual_exfat.py:39-45 (`upcase_table()` — pure function of the exFAT spec); launcher/virtual_exfat.py:71-95 (`__init__` calls it, then RLE-encodes all 65,536 entries with a second full loop); also launcher/virtual_exfat.py:31-37 (`name_units` encodes the name as UTF-16-LE twice per call and is re-invoked per node in scan, sizing and directory generation — 6 calls measured for a 2-entry tree)
- **Problem:** Executed in the sandbox: `upcase_table()` alone took ~180 ms; constructing `VirtualExfat` over a folder containing a single file took ~127-167 ms, essentially all of it this fixed cost that does not depend on the folder at all. Every UDPBD virtual-folder start pays it, and the table + encoded form are bit-identical for every instance and every process.
- **Fix:** Compute the upcase table and its encoded bytes once at module level (lazily, on first use) and reuse them across instances.
- **Benefit:** Virtual-folder server start drops the fixed ~0.15 s of pure-Python table building; repeated constructions in one process become nearly free.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED — timings)

### LNCHA-19 — Opening one raw device re-runs the full OS disk enumeration up to twice, and every mount check re-runs it again
- **Category:** 5
- **Locations:** launcher/raw_storage.py:326-367 (`_metadata()`: on Windows a PowerShell `Get-Disk`/`Get-Partition`/`Get-Volume` sweep of every disk, 20 s timeout; on Linux an `lsblk` tree walk); launcher/raw_storage.py:284-311 (`open_raw_device`: calls `_exclusive_target` — which calls `_metadata()` — and then unconditionally sets `device.mount_warning = mount_warning(path)`, which calls `_metadata()` again at launcher/raw_storage.py:409-427); launcher/raw_storage.py:392-407 (`list_devices` calls it a further time per invocation)
- **Problem:** The enumeration is the expensive operation in this module (a fresh powershell.exe process walking all disks/partitions/volumes), yet a single exclusive raw-device open pays it twice back-to-back for the same answer, and `path_access`'s device check plus the UDPBD server's own open each pay it again. On a multi-disk Windows machine this is seconds of avoidable latency on the start path of the raw-drive mode, for data that cannot change between the two calls inside one open.
- **Fix:** Have `open_raw_device` fetch the metadata once and pass the matching record into the mount-warning computation (or memoise `_metadata()` for the duration of one open).
- **Benefit:** One enumeration per device open instead of two; raw-drive start and access checks stop paying duplicate PowerShell startup + disk sweeps.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — call graph within the one file; the per-call cost is documented in the code's own timeout and in windows_setup.py:19-34's measurements of PowerShell/firewall query cost)

### LNCHA-20 — session_stats' header contract names the wrong server set
- **Category:** 7
- **Locations:** launcher/session_stats.py:1-16 ("Shared by every server (HTTP, SMBv1, UDPFS, UDPBD), so one parser reads all of their lines"); counter-evidence: smb2_server/smb2_server.py:1789-1790 constructs `SessionStats("smbv%d" % args.smb_version)` — SMBv2/SMBv3 are users too and are not named; launcher/servers.py:624-652 and 712-746 — NFS and RetroAchievements have no `session_summary` field at all, so "every server" is also an overclaim
- **Problem:** The docstring is the contract a maintainer reads before touching the SESSION line format ("The line is a contract the launcher can read"). It omits two of the six actual producers and implies two non-producers are covered, so anyone extending the format (or the launcher-side parser in session_view.py) from this header will miscount the producers.
- **Fix:** Correct the parenthetical to the actual producer set (HTTP, SMBv1, SMBv2, SMBv3, UDPFS, UDPBD).
- **Benefit:** The format contract lists its real producers; no code change.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

---

## Files read

Fully read, in scope (18/18):

- launcher/servers.py (768 lines)
- launcher/serve.py (170 lines)
- launcher/config.py (139 lines)
- launcher/main.py (475 lines)
- launcher/__main__.py (10 lines)
- launcher/process.py (178 lines)
- launcher/session_stats.py (131 lines)
- launcher/status_client.py (201 lines)
- launcher/status_dot.py (86 lines)
- launcher/netinfo.py (235 lines)
- launcher/path_access.py (77 lines)
- launcher/raw_storage.py (427 lines)
- launcher/virtual_exfat.py (325 lines)
- launcher/single_instance.py (58 lines)
- launcher/elevate.py (107 lines)
- launcher/posix_firewall.py (93 lines)
- launcher/windows_setup.py (458 lines)
- launcher/directlink.py (1,927 lines)

Cross-reference only (partial reads/greps, not audited as scope): launcher/gui.py,
launcher/achievements.py, smbv1_server/smbserver_opl.py, smb2_server/smb2_server.py,
http_server/http_server.py, nfs4_server/nfs4_server.py, udpfs_server/udpfs_server.py,
udpbd_server/udpbd_server.py, and the tests/ tree (grep census only).

## Files not read (in scope)

None — every file in the assigned scope was read fully.
