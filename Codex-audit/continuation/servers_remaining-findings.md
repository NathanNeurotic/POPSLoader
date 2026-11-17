# PS2-Servers continuation findings

Read-only audit of immutable snapshot 5179b4bb1f488ef2eb91956c8792e2194dda2fca. Deduplicated against existing PS2SERVERS-001–037. Benefit is INFERRED unless a measurement is stated.

## PS2SERVERS-100 / Stop building the same sixteen Edge targets twice on every main push / Category 2, 7

- Location(s): PS2-Servers/.github/workflows/edge.yml:24-26,223-234; PS2-Servers/.github/workflows/release-on-main.yml:4-6,259-265; PS2-Servers/.github/workflows/edge-build.yml:28-217.
- Problem: Every main push starts both workflows, and both invoke the same reusable sixteen-target Edge build/packaging matrix for the same commit. Only the rolling-release workflow consumes those release artifacts; the other copies remain separate workflow artifacts.
- Simplest fix: Run the edge.yml build matrix only for pull requests; retain its main-branch tests/source checks and the rolling-release workflow's matrix.
- Justification: Deletes duplicate scheduling without introducing cross-workflow artifact plumbing or another build layer.
- Benefit: Sixteen duplicate cross-build/package/attestation/upload jobs avoided per main push (source-declared matrix count; elapsed runner saving INFERRED).
- Effort: S. Risk: Low. Confidence: READ.

## PS2SERVERS-101 / Remove persistent NIC tuning from temporary direct-link setup / Category 3, 6

- Location(s): PS2-Servers/launcher/directlink.py:1015-1018,1042-1073.
- Problem: Enabling a direct link also disables three adapter power/energy settings and flushes the whole host ARP cache. Teardown restores IP/DNS/DHCP only; the advanced adapter settings are never saved or restored anywhere in the tree.
- Simplest fix: Delete the three advanced-property writes and global ARP-cache flush from ordinary address setup.
- Justification: These changes are not necessary to assign an address or answer DHCP; deleting speculative tuning avoids permanent unrelated NIC changes without adding snapshots or restoration machinery. Hardware-specific tuning can remain an explicit operator action.
- Benefit: Four privileged commands removed per configuration; preserves existing NIC settings and other interfaces' neighbor caches. Timing and power impact INFERRED.
- Effort: S. Risk: Low. Confidence: READ (absence of restoration checked by tree-wide reference search); hardware impact INFERRED.

## PS2SERVERS-102 / Preserve the requested action through administrator restart teardown / Category 6

- Location(s): PS2-Servers/launcher/gui.py:1949-1954,2228-2233,2526-2531,2725-2730,2817-2827,2961-2980,2993-3013,3507-3557.
- Problem: Start/firewall/direct-link elevation saves a pending action before launching the elevated copy, then stop_all invokes stop_server, which rewrites configuration without that marker. With any previously created server process in self.procs, the replacement launcher loses the requested continuation; the cleanup flow already contains a special fix for exactly this save ordering.
- Simplest fix: Apply the cleanup flow's existing ordering to these callers: preserve the intended active-server list and write the requested pending marker again after teardown, before destroying the old instance.
- Justification: Repairs four existing call sequences using the pattern already present for cleanup; no new restart coordinator or configuration layer is needed.
- Benefit: Administrator restart resumes the action the user requested; no material size/time saving claimed.
- Effort: S. Risk: Low. Confidence: READ (configuration overwrite follows directly from the call graph); complete Windows/UAC sequence INFERRED.

## PS2SERVERS-103 / Check other host networks before automatically adopting a console subnet / Category 6

- Location(s): PS2-Servers/launcher/directlink.py:672-725,895-904,1653-1674; PS2-Servers/launcher/gui.py:1879-1890,3345-3383.
- Problem: Initial direct-link setup excludes networks already used by other adapters/routes, but automatic rehoming adopts the console neighbor's /24 without that check. A console left on the same subnet as the PC's Wi-Fi/LAN can therefore install an overlapping Ethernet route and disrupt the working network the initial selection explicitly protects.
- Simplest fix: Before applying an automatic move, run the existing taken_networks/networks_overlap checks for the proposed subnet, excluding only the direct-link adapter; refuse the move if it overlaps.
- Justification: Reuses existing concrete collision logic at its missing mutation point, without another route manager or recovery mechanism.
- Benefit: Prevents an overlapping direct-link route from replacing access to a working LAN/VPN; impact depends on the host routing table (INFERRED).
- Effort: S. Risk: Low. Confidence: READ; host routing consequence INFERRED.

## PS2SERVERS-104 / Export every catalogue row instead of silently truncating backups at ten thousand / Category 6, 5

- Location(s): PS2-Servers/launcher/library_catalog.py:178-193,580-585,588-617.
- Problem: export_json serializes list_games(), whose display query has LIMIT 10000, while scans/imports support up to 100000 entries. A successful JSON backup silently omits every later row; it also stats each inspected image merely to produce disposable display identity fields that import_json ignores.
- Simplest fix: Stream all rows from the existing games table into the backup, without the display limit or _current_identity filesystem refresh; retain the existing format and stored metadata.
- Justification: A direct export query avoids the GUI-specific transformation and does not need another catalogue abstraction.
- Benefit: Complete metadata backup for large libraries; up to 10000 unnecessary filesystem observations avoided per export (source limit; elapsed saving INFERRED).
- Effort: S. Risk: Low. Confidence: READ.

## PS2SERVERS-105 / Keep the preview engine's state compatible with its existing native views / Category 6, 8

- Location(s): PS2-Servers/launcher/ra_web.py:82-103,106-140; PS2-Servers/launcher/ra_overview.py:69-78; PS2-Servers/launcher/ra_notifications.py:13-24,64-77; PS2-Servers/launcher/caduceus.py:221-229.
- Problem: The reachable owned-runtime preview publishes achievement unlocked booleans and unlock at timestamps, while the native overview reads state==2 and both unlock consumers require ago. Consequently its overview labels earned achievements as locked and its native/Caduceus unlock notifications discard every generated event.
- Simplest fix: Convert those two fields to the existing consumer schema in RAState.to_dict, retaining the preview HTML's fields only if it still needs them.
- Justification: A small adapter change at the existing serialization point repairs three actual consumers; no new event model or notification layer is needed.
- Benefit: Correct achievement status and working notifications in preview mode; no performance saving claimed.
- Effort: S. Risk: Low. Confidence: READ.

## PS2SERVERS-106 / Hide the preview runtime checkbox until it has a usable desktop sign-in path / Category 8, 3

- Location(s): PS2-Servers/launcher/servers.py:707-708,733-734; PS2-Servers/launcher/achievements.py:124-149,229-237,339-344; PS2-Servers/launcher/ra_web.py:274-276,397-412,518-543.
- Problem: The desktop can launch the owned-runtime preview, but its account page provides only sign-out, its argv builder exposes neither login nor explicit credential import, and it uses a separate owned credential store. A user selecting this option from the normal GUI cannot sign in through that GUI/account page and is directed to terminal-only flags.
- Simplest fix: Remove the desktop preview checkbox and its argv plumbing until desktop account integration is complete; keep the explicit CLI experiment if maintainers still need it.
- Justification: Deletes an unfinished user-facing path instead of adding another authentication form, IPC route or credential workaround.
- Benefit: Removes a selectable mode that cannot complete first-run setup through the advertised no-terminal desktop flow; package/time saving unmeasured.
- Effort: S. Risk: Low. Confidence: READ.

## PS2SERVERS-107 / Render preview achievement text without interpreting HTML / Category 6

- Location(s): PS2-Servers/launcher/achievements.py:201-216; PS2-Servers/launcher/ra_web.py:381-393.
- Problem: Achievement titles obtained from a remote set are interpolated directly into innerHTML in the preview account page. Markup in a title is parsed as page content and can execute in the loopback page's origin; its account actions and status are available to that origin.
- Simplest fix: Populate title/description nodes using textContent, or escape the inserted text before the existing markup interpolation.
- Justification: Removes interpretation of external display text at one existing rendering point; no sanitizer dependency, CSP framework or wrapper is needed.
- Benefit: Prevents external achievement text from becoming executable account-page markup. Browser execution was not attempted; consequence INFERRED from innerHTML semantics.
- Effort: S. Risk: Low. Confidence: READ; runtime consequence INFERRED.

## PS2SERVERS-108 / Do not let a fresh NTLM negotiate clear an established session's signing key / Category 6

- Location(s): PS2-Servers/smb2_server/smb2_server.py:537-561,665-678,839-865,907-913.
- Problem: SESSION_SETUP is allowed unsigned even after authentication, and an NTLM negotiate clears signing_key/signing_required while leaving authenticated, trees and handles intact. Subsequent unsigned file requests therefore pass both the signature gate and the existing session guard without completing another credential proof.
- Simplest fix: Reject unsupported reauthentication on an already authenticated connection before changing its established signing/authentication state; require a new connection for a new session.
- Justification: A small guard closes this concrete integrity downgrade without introducing multiple sessions or a new authentication state machine.
- Benefit: Preserves signed-session integrity against an injected restart of the handshake; network injection was not attempted.
- Effort: S. Risk: Low. Confidence: READ; on-path packet-injection sequence INFERRED.

## PS2SERVERS-109 / Bind SMB2 handles to the tree whose permissions are being checked / Category 6

- Location(s): PS2-Servers/smb2_server/smb2_server.py:245-269,669-678,1160-1188,1312-1356.
- Problem: FileId lookup uses one connection-wide handle map and never checks the request's tree against the handle's share. WRITE/SET_INFO check permissions on the header's tree, then mutate the independently selected handle, so a writable tree can authorize changes through a handle belonging to a read-only share in the supported per-Share API.
- Simplest fix: Extend the existing handle lookup to verify its owning tree/share against the validated request tree, and reject mismatches before file operations.
- Justification: Tightens the existing concrete handle guard and its real callers; it requires no new access-control layer.
- Benefit: Restores handle/tree isolation and per-share read-only enforcement. The shipped CLI applies read-only globally, so the mixed-share bypass specifically affects API configurations (INFERRED deployment).
- Effort: S. Risk: Low. Confidence: READ; mixed-share runtime consequence INFERRED.

## PS2SERVERS-110 / Bound SMB2 compound replies before retaining every requested read / Category 6, 4, 5

- Location(s): PS2-Servers/smb2_server/smb2_server.py:425-495,579-597,1130-1157; PS2-Servers/smb2_server/smb2_wire.py:23-24,44-54,206-208,258-261.
- Problem: A compound frame can contain arbitrarily many READ commands within the 24-bit input length; each retains up to 1 MiB in replies, with no aggregate response/command bound or credit admission check. Reassembly then repeatedly copies the growing output, and a response exceeding the same 24-bit framing capacity finally raises OverflowError after all the reads/allocations.
- Simplest fix: Enforce a fixed compound/aggregate-reply bound inside the existing dispatch path before retaining more response data, and join the existing response pieces once instead of repeated bytes concatenation.
- Justification: These are local limits and container changes at the actual allocation boundary; no queue, protocol framework or configurable knob is needed.
- Benefit: Bounds compound RAM and avoids quadratic response copying. Nineteen full 1 MiB READ replies already exceed the transport's 16777215-byte response limit; much larger read amplification fits an input frame (calculated source capacities; runtime exhaustion not attempted).
- Effort: M. Risk: Med. Confidence: READ; amplification workload INFERRED.

## PS2SERVERS-111 / Use varied sector data in the block-concurrency regression test / Category 7, 5

- Location(s): PS2-Servers/udpfs_server/multiclient_selftest.py:216-222,554-594,608-614.
- Problem: The shared disk fixture constructs random.Random(7) anew for every byte, producing the same first byte throughout the image. The test then compares reads of different sectors against indistinguishable data, so wrong-offset/cross-client seek corruption can pass the test intended to detect it.
- Simplest fix: Generate disk.img with the existing _make_file helper and retain its returned bytes; delete the duplicate generator/write block.
- Justification: Reuses the already correct seeded fixture implementation, reducing code and repairing a meaningful regression check.
- Benefit: Distinct sector contents expose cross-client offset mistakes; avoids 262144 Random initializations for the 256 KiB fixture (source count; elapsed saving INFERRED).
- Effort: S. Risk: Low. Confidence: READ.

## PS2SERVERS-112 / Return SMB2 flush failures to the client / Category 6

- Location(s): PS2-Servers/smb2_server/smb2_server.py:1102-1111.
- Problem: FLUSH catches every OSError from buffered flush/fsync and still returns STATUS_SUCCESS. A disk or filesystem writeback failure is therefore reported to the console as a successful durability operation.
- Simplest fix: Delete this error suppression and let the existing dispatcher translate the OSError into its normal SMB failure status.
- Justification: Removes a misleading success path without adding retries, buffering or another error abstraction.
- Benefit: Clients can detect failed save flushes instead of receiving a false success; failure consequence INFERRED from the handler and filesystem API contract.
- Effort: S. Risk: Low. Confidence: READ.

## PS2SERVERS-113 / Bound each UDPFS peer's incoming datagram queue / Category 6, 4

- Location(s): PS2-Servers/udpfs_server/udpfs_server.py:936-949,2790-2810,3199-3240; PS2-Servers/udpfs_server/ps2servers_core.py:360-382.
- Problem: Every DATA datagram is retained in an unbounded Queue, including while its worker is blocked on file I/O, reply acknowledgements or paced retransmission. The session count and transfer-size limits do not bound this per-peer backlog, so one unauthenticated peer can grow retained memory independently of those limits.
- Simplest fix: Give the existing session queue a fixed finite datagram capacity and use nonblocking admission that drops overflow; retain the protocol's existing retransmission behavior and ensure shutdown can wake a full queue.
- Justification: Bounds the existing transport buffer in place; no new queue layer, retry policy or configuration knob is needed.
- Benefit: A finite per-peer memory bound replaces unbounded datagram retention; capacity and steady-state throughput require measurement, and no exhaustion traffic was generated.
- Effort: S. Risk: Med. Confidence: READ; memory exhaustion consequence INFERRED.

## PS2SERVERS-114 / Replace discovery's sleeping thread per packet with one pending deadline / Category 6, 3, 4

- Location(s): PS2-Servers/udpfs_server/ps2servers_core.py:242-265,344-358,493-520.
- Problem: Every pre-stream DISCOVERY starts another daemon thread that sleeps before checking whether a newer generation superseded it. Repeated discovery from one endpoint thus creates unbounded concurrent sleepers despite the peer cap; thread creation failure also escapes the receive loop and stops the server.
- Simplest fix: Store the current fallback deadline on the existing session and service due fallbacks from the existing select loop, retaining the current generation/profile guards.
- Justification: Replaces per-packet thread/sleep machinery with one deadline per already bounded session; no timer framework or worker pool is necessary.
- Benefit: At most one pending fallback per peer, no sleeping OS thread for each discovery, and no thread-creation failure on this receive path. Runtime impact INFERRED; no exhaustion attempt was performed.
- Effort: M. Risk: Med. Confidence: READ.

## PS2SERVERS-115 / Reject creation flags before read-only UDPFS opens can make directories / Category 6

- Location(s): PS2-Servers/udpfs_server/udpfs_server.py:1835-1840,1878-1891.
- Problem: The read-only guard checks only the write-access bit, while the later O_CREAT branch creates missing parent directories regardless of access mode. An O_RDONLY|O_CREAT request for a missing nested file therefore changes a read-only share before the subsequent rb open fails.
- Simplest fix: Reject creation/truncation/append flags in read-only mode before any filesystem mutation, using the same flag policy already applied to virtual CHD views.
- Justification: Extends the existing early policy check; no new filesystem wrapper or rollback is needed.
- Benefit: Read-only serving no longer permits directory creation through OPEN. The call sequence was read; no mutation probe was run against the checkout.
- Effort: S. Risk: Low. Confidence: READ.

## PS2SERVERS-116 / Check that UDPFS block writes actually wrote the declared sectors / Category 6

- Location(s): PS2-Servers/udpfs_server/udpfs_server.py:2083-2130,2156-2187,2551-2616.
- Problem: Block-write completion accepts any assembled chunk length, ignores the return value of bd_write/file.write, then counts the full requested sector length and returns success. A truncated chunk sequence or short host write can therefore leave part of a save unwritten while the client receives successful WRITE_DONE.
- Simplest fix: Require assembled length to equal the requested sector bytes before writing, and return the existing I/O error response if the underlying write count is short; count only bytes actually written.
- Justification: Adds two checks at the existing completion point, without retry or buffering machinery.
- Benefit: Prevents false successful sector-write completion and inaccurate byte totals. Short-write and malformed-client outcomes INFERRED; no destructive write probe was performed.
- Effort: S. Risk: Low. Confidence: READ.

## PS2SERVERS-117 / Apply the SMB connection timeout to blocked replies too / Category 6

- Location(s): PS2-Servers/native/ps2servers-edge/internal/smb/server.go:112-120,302-311,566-600,672-689; PS2-Servers/native/ps2servers-edge/internal/smb/wire.go:159-172.
- Problem: The five-minute deadline is set only for reads; response writes have no deadline. A peer that stops receiving after requesting enough replies can leave its worker blocked in Write forever, retaining a connection slot, and sixteen such connections keep every real console out despite the idle-socket protection.
- Simplest fix: Apply the existing per-message deadline to both reading and writing with SetDeadline, or set an equivalent write deadline before the existing send.
- Justification: Uses the existing timeout and socket API, without another timer, connection manager or configurable limit.
- Benefit: Every stalled connection eventually releases its bounded slot; the blocked-write availability outcome is INFERRED from net.Conn deadline semantics and was not load-tested.
- Effort: S. Risk: Low. Confidence: READ.

## PS2SERVERS-118 / Let a new Edge UDPFS request end the previous reply's acknowledgement wait / Category 6

- Location(s): PS2-Servers/native/ps2servers-edge/internal/udpfs/server.go:502-510,535-551; PS2-Servers/native/ps2servers-edge/internal/udpfs/negotiation.go:99-117; PS2-Servers/native/ps2servers-edge/internal/udpfs/transfer.go:41-104; PS2-Servers/udpfs_server/udpfs_server.py:2790-2855,2880-2943.
- Problem: Payload DATA, including a request carrying the preceding reply's ACK, is queued behind the worker that is waiting for that ACK; only empty DATA is admitted to the control path. Losing the separate FIN ACK therefore delays the next request by the full retry budget, and ordinary background discovery keeps resetting that budget so the peer can remain stuck indefinitely; the Python implementation already ends the old wait when the console moves on.
- Simplest fix: Let the existing per-peer acknowledgement wait observe queued requests: consume their ACK immediately, re-ACK duplicates without running I/O again, and end the previous transfer when a new request has superseded it, as the existing Python waits do.
- Justification: Repairs the existing worker/control handoff rather than adding retry layers or accepting stale ACKs as progress.
- Benefit: A lost final acknowledgement no longer prevents subsequent operations from being served. The interleaving follows from the read call graph; no new protocol proof program was created.
- Effort: M. Risk: Med. Confidence: READ; complete client/network interleaving INFERRED.

## PS2SERVERS-119 / Use the API's protocol field and values in the Edge dashboard form / Category 6, 8

- Location(s): PS2-Servers/native/ps2servers-edge/internal/webui/assets/index.html:113-119; PS2-Servers/native/ps2servers-edge/internal/webui/assets/app.js:149-159,168-208; PS2-Servers/native/ps2servers-edge/internal/webui/config.go:15,77,238-240.
- Problem: The UDPFS form sends protocol_mode with capitalized values, while the API accepts protocol with lowercase auto/standard/modulo. Saving or applying UDPFS replaces the service object with form values, decodes an empty Protocol and fails validation, so the dashboard cannot save any UDPFS edit.
- Simplest fix: Rename this existing select to protocol and use the API's three lowercase values, retaining readable option labels.
- Justification: Repairs the existing form contract with four literal changes; no mapping layer or new model is needed.
- Benefit: UDPFS Save/Apply works and the selected protocol reflects saved configuration. Failure established from serialization and validation; browser interaction was not run.
- Effort: S. Risk: Low. Confidence: READ.

## PS2SERVERS-120 / Preserve settings that an Edge dashboard form does not display / Category 6

- Location(s): PS2-Servers/native/ps2servers-edge/internal/webui/assets/app.js:168-208; PS2-Servers/native/ps2servers-edge/internal/webui/assets/index.html:95-252,266-326,340-401; PS2-Servers/native/ps2servers-edge/internal/webui/config.go:29,41,53.
- Problem: Saving one service replaces its complete saved object with only the visible form fields. session_summary is supported for all three services but has no form input, so any dashboard save silently disables an operator's existing session summaries.
- Simplest fix: Merge the form's edited fields into the service object already fetched for that save instead of replacing that object.
- Justification: Reuses the existing GET result and deletes the destructive replacement behavior; no hidden-field list or extra form controls are needed.
- Benefit: Unedited server options survive ordinary dashboard edits; no size or timing saving claimed.
- Effort: S. Risk: Low. Confidence: READ.
