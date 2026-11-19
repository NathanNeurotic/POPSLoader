# Redo Audit — New Findings (Stage C)

These 22 findings were not filed by the Stage A redo reports. Each is a distinct defect mechanism noticed by the Stage B adversarial verifiers while re-deriving the redo corpus, recorded as a candidate in a verify report, and screened at Stage C as class (a) NEW (see `Redo-MASTER-INDEX.md`, Appendix A, for the full screening of all 94 candidates). IDs continue each repo's redo series. Evidence for every finding is the cited verify report, whose author re-derived the mechanism at the pin; Confidence is High (READ) on that basis. Effort/Risk were assigned at reconciliation from each mechanism's scope (all are single-site, local fixes). Pins as in the master index. Nothing here is PS2-build- or hardware-verified.

---

## RiptOPL

## RE-RIPTOPL-266 — `prepare_path`'s trailing-slash strip is dead code: the loop condition is false on the first test for every input

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/network/smbman-ra/smb_fio.c:312-314`
- **Problem:** `p2` starts on the NUL terminator, so the trailing-slash/backslash strip loop's condition is false on the first test for every input: trailing separators are never stripped, and the copy loop at :318 copies through `p2` inclusive — prepared paths retain separators the code intends to remove. Memory-safe, functional only. (RE-RIPTOPL-037(a) filed the opposite claim at these lines — a dangerous backward walk — which verification refuted; the true defect is that the strip never runs.)
- **Fix:** Start the strip from the last real character so the loop runs as intended (or delete the dead loop and document that trailing separators are retained — the fix-as-intended is the smaller behavioural surprise).
- **Benefit:** SMB paths are prepared the way the code (and its callers) already assume.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-RiptOPL.md`, CAND-06)

## RE-RIPTOPL-267 — `mmce_cmd_set_gameid` strcpy's a full game ID into a 255-byte stack buffer after u8 length truncation

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/modules/mmce/mmceman/src/mmce_cmds.c:230,241`
- **Problem:** `u8 len = strlen(ptr) + 1` truncates the length, then `strcpy(str, ptr)` copies the full string into the fixed `u8 wrbuf[0xFF]` stack buffer regardless of `len`, so a game ID longer than ~250 bytes overflows the IOP stack buffer before the `len + 5` send is reached. Distinct from RE-RIPTOPL-084 (one trailing uninitialised byte in this function) and RE-RIPTOPL-085 (filename-length truncation in mmce_fs.c).
- **Fix:** Bound the copy by the destination size and NUL-terminate, or reject IDs longer than the buffer before copying.
- **Benefit:** Removes a stack overflow reachable with an over-long game ID on the MMCE command path.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-RiptOPL.md`, CAND-08)

## RE-RIPTOPL-268 — OSDHistory victim scan compares timestamps against a stale candidate (`LeastUsedRecordTimestamp` is not reset)

- **Category:** 6 (bugs/security)
- **Locations:** `RiptOPL/src/core/OSDHistory.cpp:174-183`
- **Problem:** In the least-used scan, when a strictly smaller `LaunchCount` is found, `LeastUsedRecord`/`LeastUsedRecordLaunchCount` are updated but `LeastUsedRecordTimestamp` is not reset to that record's `DateStamp`, so subsequent equal-count comparisons are made against a previous candidate's timestamp (or `INT_MAX`) and the oldest tie-break can pick the wrong victim. Distinct from the withdrawn RE-RIPTOPL-093, which concerned the new entry's fields after takeover.
- **Fix:** Reset `LeastUsedRecordTimestamp` to the new candidate's `DateStamp` whenever a strictly smaller `LaunchCount` updates the victim.
- **Benefit:** Eviction picks the genuinely least-used, oldest record as designed.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-RiptOPL.md`, CAND-09)

---

## Launchstation

## RE-LAUNCH-093 — xparam `_start` silently does nothing for `argc == 3`

- **Category:** 6 (bugs/security)
- **Locations:** `Launchstation/iop/xparam/src/xparam.c:30-45`
- **Problem:** `_start` handles `argc < 3` (game-ID lookup) and `argc > 3` (parameter pairs), so `argc == 3` — an ID plus one dangling argument — falls through and silently does nothing at all, skipping even the ID lookup. A different mechanism and fix site from RE-LAUNCH-012 (the DB-size macro) in the same module.
- **Fix:** Handle `argc == 3` explicitly: perform the ID lookup and validate/ignore the dangling argument rather than falling through.
- **Benefit:** A malformed launch stops being indistinguishable from a successful no-op.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-Launchstation.md`, CAND-01)

## RE-LAUNCH-094 — `ExecuteBrowserFrom` is a public, caller-less entry into the classic FileBrowser

- **Category:** 1 (dead code)
- **Locations:** `Launchstation/src/main_actions.c:875-886`, `Launchstation/include/main_actions.h:27`
- **Problem:** `ExecuteBrowserFrom` opens the classic FileBrowser via `getFilePath` + `executeBrowserSelection`, but a tree-wide grep finds no call site in src/, include/, tests/, or docs/. It is a public, caller-less entry into the classic browser surface, covered by neither RE-LAUNCH-043 nor RE-LAUNCH-044.
- **Fix:** Delete the function and its header declaration.
- **Benefit:** One less live-looking entry point into a surface the rest of the audit treats as legacy.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-Launchstation.md`, CAND-10)

## RE-LAUNCH-095 — `tests/test_app_packages.py` is invoked twice in one compile.yml run

- **Category:** 7 (build/CI/repo clutter)
- **Locations:** `Launchstation/.github/workflows/compile.yml:238`, `Launchstation/.github/workflows/compile.yml:448`
- **Problem:** The same suite runs at compile.yml:238 (inside the 211-test step) and again at :448 (the packaging step, after the builds), so the workflow's 211 named tests are 211 unique files across 212 invocations — the same hand-maintained-enumeration drift surface as RE-LAUNCH-045, as a duplicate rather than an omission.
- **Fix:** Remove one of the two invocations.
- **Benefit:** CI time and enumeration drift surface both shrink; the suite's result stops being counted twice.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-Launchstation.md`, CAND-11)

## RE-LAUNCH-096 — Two divergent Python ADPCM decoders (float vs fixed-point) are maintained in parallel

- **Category:** 2 (duplication)
- **Locations:** `Launchstation/scripts/gen_sfx.py` (`decode()`), `Launchstation/tests/test_transition_latency.py:9-21`, `Launchstation/tests/test_sfx_ps2.py:25`
- **Problem:** `gen_sfx.py`'s `decode()` — the reference decoder used by --check and by `tests/test_sfx_ps2.py` — uses float arithmetic, while `tests/test_transition_latency.py` reimplements the same decode in fixed-point integer arithmetic instead of importing it. The coefficients agree but the rounding does not, so the two host decoders can disagree on edge samples, and a fix to one silently leaves the other stale.
- **Fix:** Have the latency test import `gen_sfx.decode()` and delete the fixed-point reimplementation.
- **Benefit:** One reference decoder; host-side audio checks cannot diverge from each other.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-Launchstation.md`, CAND-17)

---

## POPSLoader

## RE-POPS-116 — `bdm_connect_bd` silently drops a device when all 20 mount slots are full

- **Category:** 6 (bugs/security)
- **Locations:** `POPSLoader` BDMAssault tarball, `bdm.c:50-66`
- **Problem:** When every mount slot in `bdm_connect_bd` is occupied, the scan finds no free slot and the function simply returns. The device is never mounted and no error is logged or propagated to the caller, so a full mount table is indistinguishable from a successful connect that found nothing.
- **Fix:** Surface an error (return code and/or the driver's existing log path) when no mount slot is free instead of returning silently.
- **Benefit:** Mount-table exhaustion becomes diagnosable instead of a silent missing device.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-POPSLoader.md`, CAND-03)

## RE-POPS-117 — `chrg_connect` dereferences `config->bConfigurationValue` unchecked in both BT copies

- **Category:** 6 (bugs/security)
- **Locations:** `POPSLoader` ds34bt copies (clone and BDMAssault tarball), `chrg_connect`
- **Problem:** In both BT copies, `chrg_connect` obtains the config descriptor via `UsbGetDeviceStaticDescriptor` and immediately reads `config->bConfigurationValue` to set the device configuration. No NULL check intervenes, so a device with no config descriptor is a NULL dereference on the connect path. Not a site of RE-POPS-002's endpoint walk; no redo finding covers this function.
- **Fix:** NULL-check the config descriptor in `chrg_connect` in both copies before reading `bConfigurationValue`.
- **Benefit:** A descriptor-less device stops being an IOP crash on the DS34 charge-driver connect path.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-POPSLoader.md`, CAND-09)

## RE-POPS-118 — Three documents describe `PLDR.GetBootKind` as a consumed public API; it has no consumers

- **Category:** 7 (build/CI/repo clutter)
- **Locations:** `POPSLoader/DECISIONS.md:300`; `POPSLoader/STATE.md:128`; `POPSLoader/docs/archive/LAUNCH_HYGIENE.md:150`
- **Problem:** Three documents describe `PLDR.GetBootKind` as a consumed public API, while RE-POPS-090 proved the function has exactly one occurrence in code — its definition. The docs present dead code as a live interface other code depends on, which will mislead anyone deciding whether the function can be removed. (Doc residue of RE-POPS-090, which owns the dead code itself.)
- **Fix:** Correct the three passages to describe GetBootKind as defined-but-unconsumed, in the same change that settles RE-POPS-090's keep-or-delete.
- **Benefit:** The API documentation stops protecting dead code from deletion.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-POPSLoader.md`, CAND-14)

## RE-POPS-119 — Stale comment at ui.lua:2050 ("all other scenes use BKG.png") contradicts the cascade directly below it

- **Category:** 7 (build/CI/repo clutter)
- **Locations:** `POPSLoader/bin/POPSLDR/ui.lua:2050`
- **Problem:** The comment claims all other scenes use BKG.png, but the scene-background cascade directly below it — the code RE-POPS-094 files for duplication — does not do that. The comment misdescribes the live behaviour it annotates, inside the very cascade a fixer will be editing.
- **Fix:** Correct or delete the comment so it describes the cascade's actual behaviour.
- **Benefit:** The next editor of the cascade is not misled by its own header comment.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-POPSLoader.md`, CAND-16)

## RE-POPS-120 — COMPONENTS.md:400-405 presents three dead binaries as live and misstates the mx4sio_bd pin source

- **Category:** 7 (build/CI/repo clutter)
- **Locations:** `POPSLoader/COMPONENTS.md:400-405`; contradicting evidence `POPSLoader/Makefile:346-352`
- **Problem:** COMPONENTS.md:400-405 presents the three binaries RE-POPS-056 proved dead as bin2c'd/live, and describes the active mx4sio_bd as pinned from `iop/embed/PS2SDK_MX4SIO`. Makefile:346-352 contradicts both statements. A distinct limb from RE-POPS-112 (the same file's BDMA variant list).
- **Fix:** Rewrite the passage from Makefile:346-352: mark the three binaries dead and state mx4sio_bd's actual source/pin.
- **Benefit:** The component map stops asserting the opposite of the build file it documents.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-POPSLoader.md`, CAND-19)

---

## SMS (Simple-Media-System)

## RE-SMS-145 — WMA v1 exponent rows 1+ are never filled: the band computation always writes row 0

- **Category:** 6 (bugs/security)
- **Locations:** `Simple-Media-System/src/SMS_WMA.c:1354`; row selection at `Simple-Media-System/src/SMS_WMA.c:1635`
- **Problem:** The WMA v1 band computation always writes exponent row 0, while `decode_exp_vlc` selects the exponent row by block size. Rows 1+ therefore stay zero, triggering the zero-entry underflow without any repeated critical frequency. A distinct root cause (rows never populated) from RE-SMS-024's zero-width-entry guard, despite sharing the underflow sink — verification proved RE-SMS-024's reachability by simulation and found this alongside it.
- **Fix:** Write the computed exponents into the row selected by block size, not always row 0.
- **Benefit:** WMA v1 streams using larger block sizes decode with real exponent tables instead of hitting the zero-entry path.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-SMS.md`, CAND-03)

## RE-SMS-146 — CDDA empty field leaves a node's `m_pName` as uninitialised malloc memory

- **Category:** 6 (bugs/security)
- **Locations:** `Simple-Media-System/src/SMS_FileContext.c:803-822`
- **Problem:** On an empty CDDA field, `*apBuf` is never assigned, so the per-node `m_pName` remains uninitialised malloc memory, later consumed as a name string. Distinct from RE-SMS-062's unterminated-buffer `strlen` in the same function — a different trigger (empty field) and failure.
- **Fix:** Assign the empty string to `*apBuf` on the empty-field path.
- **Benefit:** CDDA listings with empty fields stop carrying heap garbage as a track name.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-SMS.md`, CAND-07)

## RE-SMS-147 — `lwip_getpeername`/`lwip_getsockname` dereference `*namelen` with no NULL check

- **Category:** 6 (bugs/security)
- **Locations:** `Simple-Media-System/iop/SMSTCPIP/src/sockets.c` (~:815-875)
- **Problem:** Both functions dereference `*namelen` with no NULL check, so passing a NULL `namelen` crashes the sockets layer. Independent of RE-SMS-077 (a different argument and sink from its discarded-result / NULL-PCB mechanism).
- **Fix:** NULL-check `namelen` (and `name`) at entry to both functions and return an error, matching the layer's other guards.
- **Benefit:** A standard POSIX-style call with a NULL length pointer stops being an IOP crash.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-SMS.md`, CAND-10)

## RE-SMS-148 — `netconn_addr` has no default case: returns ERR_OK with `*addr`/`*port` unset for non-UDP/TCP types

- **Category:** 6 (bugs/security)
- **Locations:** `Simple-Media-System/iop/SMSTCPIP/src/api_lib.c:236-260`
- **Problem:** `netconn_addr` has no default case for non-UDP/TCP connection types. It returns ERR_OK with `*addr` and `*port` left unset, so a caller checking only the return code consumes uninitialised outputs as a valid address. Distinct mechanism (unset outputs on a success return) from RE-SMS-077's NULL-PCB dereference in the same function.
- **Fix:** Add a default case returning an error (ERR_ARG) for unsupported connection types.
- **Benefit:** Unsupported connection types fail loudly instead of handing callers garbage addresses under a success code.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-SMS.md`, CAND-11)

## RE-SMS-149 — Packed SMSSMB.IRX segment (~19.6 KB) is dead bytes in `g_DataBuffer` in every build

- **Category:** 4 (size/memory)
- **Locations:** `Simple-Media-System/src/SMS_Data.c`; `Simple-Media-System/include/SMS_Data.h:24,42`
- **Problem:** The packed SMSSMB.IRX segment occupies 19,641 B (19,648 aligned) of resident `g_DataBuffer` EE RAM with no EE consumer in any build. This byte set is counted by neither RE-SMS-102 (source tree) nor RE-SMS-106 (the UMS/USBD/SIO2MAN segments) — a distinct dead segment.
- **Fix:** Remove the packed SMSSMB.IRX segment from `g_DataBuffer` (deletion only; no consumer exists to update).
- **Benefit:** ~19.6 KB of resident EE RAM recovered in every build.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-SMS.md`, CAND-12)

## RE-SMS-150 — Explicit-format path in `SMS_GetContainer` discards the creator's return value, so error teardown can never fire

- **Category:** 6 (bugs/security)
- **Locations:** `Simple-Media-System/src/SMS_Container.c:198`
- **Problem:** The explicit-format path calls the container creator without assigning its return to `lSts`. The `lSts < 0` teardown can therefore never fire for explicit probes: a failed creator leaves a half-initialised container to be used as if creation succeeded. Distinct from RE-SMS-101's bounds claim at the same line — a lost return value, not an unchecked index.
- **Fix:** Assign the creator's return to `lSts` on the explicit-format path.
- **Benefit:** Failed explicit-format probes take the existing teardown path instead of proceeding on a half-built container.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-SMS.md`, CAND-14)

---

## PS2-Servers

## RE-SERV-217 — SMB2 stub `h2_tree_connect` crashes on every call (struct.pack arity bug)

- **Category:** 6 (bugs/security)
- **Locations:** `PS2-Servers/smbv1_server/smbserver_opl.py:573-581`
- **Problem:** `h2_tree_connect` packs `struct.pack("<BBII", 16, 0x01, 0, 0x00000030, 0x000f001f)` — 5 values into a 4-field format — so every SMB2 TREE_CONNECT raises `struct.error` unconditionally. The exception escapes serve_conn's `except (ConnectionError, OSError)` handling and kills the connection thread instead of returning even the stub's fake success. This is the real mechanism under RE-SERV-022's failed tree-connect limb (that finding claimed fake success there).
- **Fix:** Correct the format/values arity so TREE_CONNECT returns the stub response instead of raising.
- **Benefit:** An SMB2 TREE_CONNECT stops killing the connection thread on the SMB1 file's SMB2 stub path.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-PS2Servers.md`, CAND-A1)

## RE-SERV-218 — NFS4 endless-empty-fragments test is timing-fragile by construction

- **Category:** 7 (build/CI/repo clutter)
- **Locations:** `PS2-Servers/tests/test_nfs4_server.py:890`; `PS2-Servers/nfs4_server/nfs4_server.py:49-50`; `PS2-Servers/nfs4_server/nfs4_server.py:505-517`
- **Problem:** The test sends 264,193 empty fragments (`p32(0) * (MAX_RECORD//4 + 1)`), which the server consumes one `_recv` per fragment, closing only after `total > MAX_RECORD`, against a 5 s client socket timeout. It passes only near the timeout budget (observed 2.5–5.1 s, 5/5 isolated) and failed with TimeoutError in the original baseline run, so its result is load-dependent rather than deterministic — a flaky gate that will intermittently fail CI and intermittently mask real regressions.
- **Fix:** Make the test deterministic: bound the fragment count to what the server's per-fragment cost can consume well inside the timeout, or drive the server's close condition directly.
- **Benefit:** The NFS4 fragment-flood behaviour gets a gate whose pass/fail means something.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-PS2Servers.md`, CAND-F2)

## RE-SERV-219 — `h_trans2_find_first2` crashes with IndexError on an empty directory

- **Category:** 6 (bugs/security)
- **Locations:** `PS2-Servers/smbv1_server/smbserver_opl.py:1243-1244`
- **Problem:** `h_trans2_find_first2` unpacks `name, lp, sz = entries[0]` with no emptiness check after `_list_dir` succeeds. An empty (or all-filtered) games subfolder therefore raises IndexError inside the handler instead of returning an empty/end-of-search reply. (RE-SERV-180 covers the same handler only for its one-entry-per-reply inefficiency.)
- **Fix:** Check `entries` for emptiness and return the end-of-search/empty reply instead of indexing `entries[0]`.
- **Benefit:** Browsing an empty games folder stops crashing the SMB1 handler.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-PS2Servers.md`, CAND-H1)

---

## Cross-repo

## RE-X-32 — SMS `ip_frag` completeness loop never checks bitmap byte 89: a 64-byte hole passes as complete

- **Category:** 6 (bugs/security)
- **Locations:** `Simple-Media-System/iop/SMSTCPIP/src/ip_frag.c:192`; fixed form in `RiptOPL/modules/network/SMSTCPIP/ip_frag.c:206-213`
- **Problem:** SMS's `ip_frag.c:192` completeness loop (`i < ip_reasslen/64 - 1`) never checks bitmap byte 89 for a 5760-byte datagram, so a hole at payload 5696-5759 passes as complete and a datagram with a 64-byte gap is delivered upward as whole. RiptOPL's copy fixed this, with an explicit comment. A distinct loop-bound mechanism (false completeness) from RE-X-22 (bitmap sizing) and from RE-SMS-016 (IPH_LEN trust / bitmap-index OOB).
- **Fix:** Correct the completeness loop bound in SMS's `ip_frag.c` so the final bitmap byte is checked, matching RiptOPL's fixed form.
- **Benefit:** SMS stops delivering holed datagrams as complete on the reassembly path it shares ancestry with RiptOPL.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — evidence: `Redo-VERIFY-Cross.md`, CAND-03)
