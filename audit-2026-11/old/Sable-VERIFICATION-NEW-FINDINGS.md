# Sable Audit — Verification Phase: New Findings

**Filed:** 2026-11-14, by the verification phase (adversarial re-verification of the audit's Category 6 findings, consistency census, and execution re-runs). These six findings were first derived inside the verification passes and are collected here in standard audit format, copied faithfully from the VERIFY deliverables. Pins are the round-2 pins, unchanged: RiptOPL `2e347d5ac885`, Launchstation `9fb0598a79f0`, POPSLoader `29272cddbf01`, SMS `e65ced39a27e`, PS2-Servers `c5f021c4d386`.

**Renumbering record:** the SMS verification pass filed its two candidates as **SMS-230** and **SMS-231** (`Sable-VERIFY-SMS-CAT6.md`, "New candidate findings (SMS-183 upward)"). They are renumbered here to the next free SMS numbers: **SMS-230 → SMS-183**, **SMS-231 → SMS-184**. The other four findings carry the numbers their verification passes assigned (RIPTOPL-602, POPSLOADER-108, PS2SERVERS-114, PS2SERVERS-115).

---

### RIPTOPL-602 / `hddFormat` reads a cache entry's sector after freeing the entry (second instance of the RIPTOPL-467 pattern) / Category 6

- **Category:** 6 (bug, latent)
- **Locations:** `modules/hdd/apa/src/hdd_fio.c:435` (`apaCacheFree(clink)`) and `modules/hdd/apa/src/hdd_fio.c:438` (`clink->sector` passed to `hddAddPartitionHere`), inside `hddFormat` (`hdd_fio.c:321…`), in the `#ifdef APA_FORMAT_WIPE_COMMON_ONLY` branch
- **Problem:** `clink` is obtained from `apaFindPartition(f->unit, "__sysconf", &rv)` at `hdd_fio.c:433`, released with `apaCacheFree(clink)` at `:435`, and then dereferenced — `clink->sector` is passed as the start sector for the new `__common` partition at `:438`. This is the same free-then-read pattern as RIPTOPL-467 (the `apaOpen` instance at `hdd_fio.c:510-512`, verified above) at a second site that finding did not cite. It is benign today by the same contract: `apaCacheFree` only decrements `nused` and relinks the entry into the cache free list (`modules/hdd/apa/src/cache.c:176-192`) — the memory is a static cache array — and no cache allocation intervenes between `:435` and the argument evaluation at `:438` (only `memset`/`strcpy` on `params.id`). Any future change that allocates a cache entry in that window, or makes `apaCacheFree` actually release/reuse storage, silently turns the `__common` partition's start sector into whatever the reused entry holds, on a format path. Scope note: the branch compiles only in the `APA_XOSD_VER` build variant (`APA_FORMAT_WIPE_COMMON_ONLY` is defined at `modules/hdd/apa/src/apa-opt.h:28`, under `APA_XOSD_VER` at `:26-29`); the default build does not contain this instance. RIPTOPL-467's instance, by contrast, is in the default build (`APA_ENABLE_PASSWORDS 1`, `apa-opt.h:36`).
- **Fix:** Hoist `u32 sector = clink->sector;` above the `apaCacheFree(clink)` at `:435` and pass `sector` at `:438` — the same reorder RIPTOPL-467 prescribes for `apaOpen`. One local, no new code paths.
- **Benefit:** Removes a latent use-after-free on the XOSD format path at zero cost, and closes the pattern family rather than leaving a second instance of a filed defect in the tree.
- **Effort:** S · **Risk:** Low · **Confidence:** High (ordering and branch condition READ at the pin by two independent readers; the "can it bite" half is latent-by-contract, as with RIPTOPL-467)

*(Source: `Sable-VERIFY-RiptOPL-CAT6.md` §5.)*

---

### SMS-183 / SMSTCPIP `lwip_getpeername` / `lwip_getsockname` ignore `netconn_peer` / `netconn_addr`'s return: a guarded error becomes a successful garbage result (and SMS-170's fix alone does not save `lwip_getsockname`) / Category 6

- **Category:** 6
- **Locations:** `iop/SMSTCPIP/src/sockets.c:827` (`lwip_getpeername` discards `netconn_peer`'s return), `:834` (uses uninitialised `naddr.addr`), `:840-841` (returns 0); `iop/SMSTCPIP/src/sockets.c:861` (`lwip_getsockname` discards `netconn_addr`'s return), `:868` (dereferences `naddr`), `:874-875` (returns 0); guarded callees `iop/SMSTCPIP/src/api_lib.c:219, 226-227` (`netconn_peer` returns `ERR_CONN` without writing its outputs when the PCB is NULL).
- **Problem:** `netconn_peer`'s PCB-NULL guard (the sibling guard SMS-170 is measured against) protects the callee, but its only sockets-layer caller throws the result away. In `lwip_getpeername`, `naddr` is an uninitialised stack `struct ip_addr` (:814); when the PCB is NULL (post-`err_tcp` abort, `api_msg.c:183`) or a UDP conn is unconnected, `netconn_peer` returns `ERR_CONN` without writing `*addr`/`*port`, and the caller proceeds to copy the uninitialised `naddr.addr` into the result sockaddr and return success with `sock_set_errno(sock, 0)`. The mirror defect in `lwip_getsockname` matters for SMS-170's remediation: even after `netconn_addr` gains the proposed guard and returns `ERR_CONN` without setting `*addr`, `lwip_getsockname` ignores that return and dereferences its uninitialised `naddr` pointer at :868 — the crash moves, it does not close. (The third `netconn_peer` caller, `lwip_sendto` at `sockets.c:452`, does check `== ERR_OK` — the correct shape exists in the same file.) Distinct from SMS-170 (missing guard inside `netconn_addr`, `api_lib.c`) and SMS-166 (`lwip_accept`'s NULL `newconn`): this is the caller-side ignored-return defect in `sockets.c`.
- **Fix:** Check both returns: on `!= ERR_OK`, `sock_set_errno(sock, ENOTCONN)` (or the recorded `conn->err`) and return −1, mirroring `lwip_sendto:452`'s existing test. For `lwip_getsockname` this check is required *together with* SMS-170's guard, not instead of it.
- **Benefit:** Post-abort / unconnected `getpeername`/`getsockname` return an error instead of success-with-garbage (or, after a partial SMS-170 fix, a relocated crash).
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ — callee guard, both call sites, and the checking sibling all line-read; INFERRED only for the abort-then-query ordering, as in SMS-170).

*(Source: `Sable-VERIFY-SMS-CAT6.md`, "New candidate findings", filed there as SMS-230; renumbered SMS-183 — see the renumbering record in this file's header.)*

---

### SMS-184 / USBD `hcdInit` never checks the HCD IRQ thread's creation: `hcdTid` failure leaves USB interrupts waking a nonexistent thread while `hcdInit` returns 0 / Category 6

- **Category:** 6
- **Locations:** `iop/USBD/src/hcd.c:464-482` (`static int hcdTid;` :464, `hcdTid = CreateThread(&thread)` :472 unchecked, `RegisterIntrHandler(…, iWakeupThread, (void*)hcdTid)` :476, `StartThread(hcdTid, NULL)` :482 unchecked), unconditional `return 0` at `hcd.c:496`.
- **Problem:** This is a third unchecked-thread site in `hcdInit`, distinct from SMS-180's callback thread (`driver.c:246`, called at `hcd.c:485`) and from SMS-162's arena allocation (`hcd.c:340`): the thread created here is `hcdIrqThread`, the thread the USB interrupt handler wakes to process HCD interrupts. If `CreateThread` fails (IOP thread exhaustion), the negative error id is stored in `hcdTid` — which also defeats the `if (!hcdTid)` retry guard at :466, since a negative id is truthy — `RegisterIntrHandler` registers a wakeup target that does not exist, `StartThread` is called on the invalid id with its result ignored, and `hcdInit` still returns 0. USBD loads resident with interrupts enabled (:494) and no IRQ thread: no interrupt is ever serviced. Neither SMS-162 (allocation + return-value masking in general) nor SMS-180 (callback thread specifically) cites this site or this thread.
- **Fix:** Test `hcdTid` after `CreateThread` (and `StartThread`'s result) in `hcdInit` and return an error on failure, so `_start` can fail the module load — the same propagation SMS-162/SMS-180 already require of this function.
- **Benefit:** Thread exhaustion at USBD load becomes a visible load failure instead of a resident USB stack whose interrupt path is dead on arrival.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ for the missing checks, the truthy-negative retry-guard interaction, and the unconditional return; INFERRED only for kernel-call failure modes, as in SMS-180).

*(Source: `Sable-VERIFY-SMS-CAT6.md`, "New candidate findings", filed there as SMS-231; renumbered SMS-184 — see the renumbering record in this file's header.)*

---

### POPSLOADER-108 / GPT partition `sectorCount` is one sector short for every valid partition (last LBA is inclusive) / Category 6

- **Category:** 6 (bugs/security) [tarball section's divergent label: 2 (correctness/safety)]
- **Locations:** `tarball!BDMAssault-mx4sio/bdm/src/part_driver_gpt.c:148` (`g_part_bd[partIndex].sectorCount = pGptPartitionEntry[x].last_lba - pGptPartitionEntry[x].first_lba;`); merged twin `__bdm_assault/src/bdm/bdm_part_driver_gpt.c` at the identical line (include-path diff only, spot-diffed this pass). Field semantics at `bdm/src/include/gpt_types.h:51` (`last_lba` — "Last LBA (inclusive, usually odd)").
- **Problem:** READ. GPT's `last_lba` is inclusive, so a partition's sector count is `last_lba - first_lba + 1`. The code omits the `+1`, so every GPT partition pseudo-device is one sector smaller than the partition on disk — its final sector is unreachable through the partition device. This is the GPT-partition sibling of POPSLOADER-088 (the same off-by-one on the SCSI whole-device count), and is distinct from POPSLOADER-074(b), which filed only the inverted-entry underflow of the same expression: for ordinary, valid entries the count is still wrong by one. The MBR sibling does it correctly by construction (`part_driver_mbr.c:89` copies the entry's explicit `sector_count` field).
- **Fix:** `sectorCount = last_lba - first_lba + 1` (after the inverted-entry rejection proposed in POPSLOADER-074, so the addition cannot reintroduce the underflow).
- **Benefit:** Medium-low — the last sector of every GPT partition (where a filesystem's trailing structures can live) becomes reachable; removes a silent one-sector truncation on the GPT path only.
- **Effort:** S / Risk: Low / Confidence: High (READ — expression, field comment, and the MBR contrast all in-tree)

*(Source: `Sable-VERIFY-OTHERS-CAT6.md`, POPSLoader section, "New candidate findings".)*

---

### PS2SERVERS-114 / SMB1 server's embedded SMB2: TREE_CONNECT and CLOSE always raise `struct.error` and kill the connection thread — on well-formed requests / Category 6

- **Category:** 6 (Bug / robustness)
- **Location(s):** `PS2-Servers/smbv1_server/smbserver_opl.py:572-581` (`h2_tree_connect`: `struct.pack("<BBII", …)` given 5 values for 4 format items), `:612-614` (`h2_close`: `struct.pack("<HHQQQQQI", …)` given 9 values for 8 format items); uncaught because the SMB2 branch of `serve_conn` (`:1435ff`) runs under the same `except (ConnectionError, OSError)` at `:1497` that PS2SERVERS-044 covers for SMB1.
- **Problem:** EXECUTED at this pin: both handlers raise `struct.error` on every call, regardless of input. Driven through `serve_conn`, one well-formed SMB2 TREE_CONNECT (0x0003) — the third message of every normal SMB2 session — terminates the connection thread with a traceback, and CLOSE (0x0006) does the same. This is distinct from PS2SERVERS-044 (there, *truncated SMB1* requests raise in the handler); here the requests are well-formed and the defect is in the handlers' own reply construction, so no client behaviour can avoid it. It also means the fake SMB2 of PS2SERVERS-042 cannot complete the standard session sequence at all.
- **Fix:** Correct the two pack formats to match the reply layouts they intend (add the missing `I` to `"<BBII"` → 5 fields; drop the surplus value or add the missing field in `h2_close`), or — preferably, as PS2SERVERS-042 already recommends deleting this whole implementation — delete it. If any of it is kept, `struct.error` should be caught alongside `OSError` in `serve_conn` (the PS2SERVERS-044 fix) so a handler bug drops one reply, not the thread.
- **Benefit:** A guaranteed thread-kill on a normal protocol message removed; no lines saved if fixed in place (deletion under -042 removes ~130 lines including this).
- **Effort:** S. **Risk:** Low. **Confidence:** High (READ + EXECUTED, both directly and through `serve_conn`)

*(Source: `Sable-VERIFY-OTHERS-CAT6.md`, PS2-Servers section, "New defect candidates".)*

---

### PS2SERVERS-115 / SMB1 server's embedded SMB2: the SMB2 header packer/parser is 66 bytes, not 64 — `Command` is encoded as a 4-byte field / Category 6

- **Category:** 6 (Bug / protocol correctness)
- **Location(s):** `PS2-Servers/smbv1_server/smbserver_opl.py:511-527` (`pack_smb2_hdr`, format `"<4sHHIIHIIQQQ16s"`, `struct.calcsize` = **66**) and `:529-535` (`Smb2Req`, same format); the header's own StructureSize field is written as 64.
- **Problem:** EXECUTED at this pin: in the pack format, `Command` is the second `I` (4 bytes) where MS-SMB2 defines Command as 2 bytes followed by CreditRequest/Response (2 bytes); every field after Command (credits, flags, message id, session id) is therefore shifted 2 bytes, and the produced "header" is 66 bytes that declare StructureSize 64. The implementation's own parser uses the identical wrong format, so in-repo loopback exchanges parse consistently and no in-repo test notices; but `Smb2Req` outright rejects a correctly-sized 64-byte SMB2 header (`struct.error: unpack_from requires a buffer of at least 66 bytes…`, observed when a 64-byte frame was fed to it during this verification), and a spec-conformant client's header parse of these replies would misread every field after Command (INFERRED for real-client interop; the 66-vs-64 size and the parser rejection are executed). This is a second, independent reason the PS2SERVERS-042 implementation cannot talk to a real SMB2 client, beyond its dummy handlers.
- **Fix:** None in place — this is further support for PS2SERVERS-042's deletion. If the implementation were ever kept, the format would need `Command`/`Credits` as `"<HH"` and the Reserved/TreeId split restored to reach a true 64-byte header, with a wire-size assertion (`calcsize == 64`) in a test.
- **Benefit:** Records why "just fix the dummy handlers" would still not make this implementation interoperable; prevents a partial fix of -042 from being mistaken for a working SMB2.
- **Effort:** S (record only; deletion is -042's fix). **Risk:** Low. **Confidence:** High (READ + EXECUTED for size/parser rejection; INFERRED for real-client behaviour)

*(Source: `Sable-VERIFY-OTHERS-CAT6.md`, PS2-Servers section, "New defect candidates".)*
