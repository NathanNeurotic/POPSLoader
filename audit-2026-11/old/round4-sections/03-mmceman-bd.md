# Round 4 — Section 03: Launchstation mmceman remainders (Task A) + block-device internals (Task B)

Repo: NathanNeurotic/Launchstation, pin `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (verified, no fetch/pull; clone left clean).
Scope note: READ = read in the source at the pin in this pass. INFERRED = conclusion that depends on protocol/hardware/SDK behaviour not in the tree. No PS2 build or hardware claims anywhere in this section.

---

## TASK A — mmceman remainders

### Coverage ledger (Task A)

| File | Lines | Ranges read |
|---|---|---|
| `iop/mmceman/src/mmce_fs.c` | 1,480 | 1–1480 in full (read/write/dread/getstat bodies end-to-end, plus open/close/lseek/lseek64/rename/devctl/ioctl2 re-read for cross-checks) |
| `iop/mmceman/src/mmce_sio2.c` | 602 | 1–602 in full |
| `iop/mmceman/include/mmce_restore_guard.h` | 58 | in full (validator the fs paths rely on) |
| `iop/mmceman/include/mmce_sio2.h` | 48 | in full |
| `iop/mmceman/include/mmce_fs.h` | 7 | in full |
| `iop/mmceman/src/mmce_cmds.c` | 344 | NOT re-read (prior rounds; only its caller lines into the SIO2 helpers were grepped) |
| `iop/mmceman/src/mmcedrv.c` / `mmceigr.c` | — | NOT re-read (already filed as LAUNCHSTATION-070, unbuilt) |

Not repeated (already filed): LAUNCHSTATION-054, -055, -057, -070 — confirmed still present at the pin in the re-read bodies (devctl's four unguarded `*(u32*)arg` derefs are the -057 set; nothing new in that switch).

### Proposed findings (Task A)

#### PROPOSED-001 — mmce_fs_write returns the firmware-supplied byte count unclamped; mmce_fs_read clamps the identical value
- Category: 6 (firmware-supplied length/count trusted)
- Locations: `iop/mmceman/src/mmce_fs.c:555-565` (count assembled from reply bytes at :555-558, returned at :565 after only a DPRINTF on mismatch); contrast `iop/mmceman/src/mmce_fs.c:477-485`
- Problem: READ. In `mmce_fs_read`, a firmware `bytes_read` larger than the requested `size` is clamped (`if (bytes_read > size) bytes_read = size;`, :480-481) before being returned to iomanX. In `mmce_fs_write`, the firmware `bytes_written` assembled from the same-shaped reply packet is returned verbatim (:559-565): a garbled or malicious card reply can make a write() report more bytes written than the caller ever supplied in its buffer. Callers that advance a cursor or retry the remainder by the returned count (the standard write-loop idiom) then skip unsent data or run the count negative — silent data loss on the card, produced entirely by a value the firmware controls.
- Fix: Mirror the read side: after the mismatch DPRINTF at :559-561, add the same two-line clamp (`if (bytes_written > size) bytes_written = size;`). No new helper, no protocol change.
- Benefit: Write results can never overstate the caller's own buffer; read/write become symmetric.
- Effort: 2 lines.
- Risk: Minimal — only changes behaviour for replies that were already inconsistent with the request.
- Confidence: High (READ; the asymmetry is in the code at the pin).

#### PROPOSED-002 — dread copies the firmware-supplied filename length into dirent->name with no NUL termination and no zeroing
- Category: 6 (firmware-supplied length sizes a copy)
- Locations: `iop/mmceman/src/mmce_fs.c:1040` (`filename_len = rdbuf[0x29];`), `iop/mmceman/src/mmce_fs.c:1043` (filename packet received directly into `dirent->name`)
- Problem: READ for the code; INFERRED for the firmware's counting convention. `filename_len` is a single firmware byte, so the copy is at most 255 bytes into `iox_dirent_t.name[256]` (SDK `io_common.h` layout; corroborated by the in-workspace PS2SDK stub headers) — there is **no overflow**, and that half is dissolved below. What the driver never does is terminate or clear the name: it does not memset the dirent (contrast the in-tree `iop/smbman/smb_fio.c:704`, which memsets its dirent) and never writes a NUL after the received bytes. Every other name path in this driver sends `strlen(name) + 1`, i.e. the count includes a terminator; if the dread reply's length byte instead counts raw characters (or a garbled reply inflates it to 255), `dirent->name` is an unterminated string and the EE-side caller reads past the received name into whatever the dirent buffer previously held.
- Fix: One line after a successful filename packet (:1043-1048 region): force `dirent->name[sizeof(dirent->name) - 1] = '\0';` — or, if the length is known to include the terminator, reject `filename_len == 0`. The forced terminator is the LESS change and is correct under both counting conventions.
- Benefit: Directory entries handed to the EE are always valid C strings regardless of firmware behaviour.
- Effort: 1 line.
- Risk: Truncates a hypothetical exactly-255-char name's last byte; wire names elsewhere in this driver are capped at 254 chars + NUL (`mmce_restore_guard.h:10`), so no legitimate name is affected.
- Confidence: Medium — the missing termination is READ; whether real firmware ever omits the terminator is INFERRED.

#### PROPOSED-003 — dopen stores any firmware fd except 0xff unchecked; open validates the same byte against MMCE_FS_MAX_FD
- Category: 6 (firmware-supplied value accepted without the sibling path's check)
- Locations: `iop/mmceman/src/mmce_fs.c:879-880` (dopen); contrast `iop/mmceman/src/mmce_fs.c:329` (open's `rdbuf[0x1] < MMCE_FS_MAX_FD` check, with 0xff mapped to -ENOENT)
- Problem: READ. `mmce_fs_open` rejects a firmware descriptor ≥16 (and treats only 0xff as "no such file"). `mmce_fs_dopen` accepts every reply byte except 0xff as a live directory descriptor and stores it in the handle slot. A garbled reply (line noise on SIO2, a card mid-reset) therefore creates a phantom directory handle that dread/dclose then present back to the firmware. No local memory unsafety was found — the value is never used as a local array index (slots are indexed by slot pointer, values are only cast to u8 and sent back) — so this is a consistency/robustness gap, not a corruption bug, and is filed at that weight.
- Fix: Give dopen open's condition: store only when `rdbuf[0x1] < MMCE_FS_MAX_FD`, keep 0xff → -ENOENT, anything else → -1 with `file->privdata = NULL` (the shape open already uses at :329-340).
- Benefit: One validation rule for firmware descriptors across the driver; garbled replies fail at open time instead of haunting a listing.
- Effort: ~4 lines, copied from the sibling function.
- Risk: Minimal; a firmware that legitimately returned dir fds ≥16 would already break open's file fds from the same pool.
- Confidence: High that the asymmetry exists (READ); Low severity.

#### PROPOSED-004 — The use_alarm setting is honoured by the SIO2 receive paths and ignored by the transmit paths
- Category: 4 (dead/inconsistent control surface)
- Locations: `iop/mmceman/src/mmce_sio2.c:287-288` and `:390-391` (rx_dma/rx_mixed guard `SetAlarm` with `if (mmce_sio2_use_alarm)`); `iop/mmceman/src/mmce_sio2.c:501`, `:542`, `:579` (tx_mixed's three stages call `SetAlarm` unconditionally); `iop/mmceman/src/mmce_sio2.c:220` (tx_rx_pio also unconditional). Setting written by `mmce_sio2_set_use_alarm` at `mmce_sio2.c:185-188`, reached from the devctl `MMCE_SETTINGS_SET_ALARMS` case in `mmce_fs.c` (already covered by -057 for its arg deref, not for this).
- Problem: READ. A caller that disables alarm-based timeouts through the settings devctl gets them disabled for reads only; every write chunk and every PIO command still installs the 2 s alarm. Whatever incompatibility the setting exists to avoid (the flag's purpose is not documented in-tree — INFERRED) therefore still applies to exactly half the traffic, and the setting reads as global while being path-local.
- Fix: LESS direction is a decision, not code: either guard tx_mixed's three `SetAlarm`/`CancelAlarm` pairs with the same `if (mmce_sio2_use_alarm)` the rx functions use (~6 lines, mechanical), or delete the setting and the devctl case if alarms are in fact always required (tx_rx_pio — used by every command — already cannot run without one, which is evidence for the deletion reading). Do not leave it half-applied.
- Benefit: The settings surface means what it says, one way or the other.
- Effort: Small either way.
- Risk: Guarding tx_mixed without guarding tx_rx_pio still leaves the primitive inconsistent — the coordinator should pick one reading (deletion is the more honest one, since tx_rx_pio at :220 proves no transfer in this driver actually runs alarm-free end-to-end).
- Confidence: High (READ asymmetry); the right fix direction is a maintainer call.

#### PROPOSED-005 — mmce_sio2_rx_dma (66 lines) has exactly one caller, and it is the unbuilt mmcedrv.c already filed for deletion
- Category: 1 (dead code — extension of LAUNCHSTATION-070)
- Locations: `iop/mmceman/src/mmce_sio2.c:246-311` (function); sole caller `iop/mmceman/src/mmcedrv.c:123`
- Problem: READ (caller set established by grep over the whole tree at the pin). -070 files `mmcedrv.c` + `mmceigr.c` (581 lines) as unbuilt. If that deletion lands, `mmce_sio2_rx_dma` — the "simplified read for sectors / MMCEDRV" helper, per its own comment at `mmce_sio2.c:245` — loses its only caller and becomes dead code inside an otherwise live file, where future readers will keep maintaining it as if it were reachable.
- Fix: When -070 is actioned, delete `mmce_sio2_rx_dma` and its prototype (`iop/mmceman/include/mmce_sio2.h:40`) in the same change. Until then, no action.
- Benefit: The -070 deletion is complete rather than leaving a 66-line orphan behind.
- Effort: Trivial, folded into -070's change.
- Risk: None while mmcedrv.c is unbuilt; if mmcedrv is ever revived the function returns with it.
- Confidence: High (READ + grep-verified caller set).

### Checked-and-clean / dissolved (Task A)

- **read/write data phases** (`mmce_fs.c:455`, `:537`): the byte counts moved by `mmce_sio2_rx_mixed`/`tx_mixed` are the *caller's* `size`, never a firmware value; the firmware count packet is read afterwards and (read side) clamped — the write-side clamp gap is PROPOSED-001, the transfer itself is clean. READ.
- **rx_mixed chunking** (`mmce_sio2.c:314-420`): traced for sizes 0, 255, 256, 4096, 5000, 8292 — DMA-element/PIO-remainder split, `offset_pio` bookkeeping and the post-loop FIFO copy are correct in every case, including the extra pass when the size is an exact multiple of 4 KiB plus a remainder. Dissolved. READ.
- **tx_mixed chunking** (`mmce_sio2.c:422-602`): traced for 0, 255, 4096, 5000 — full-4 KiB DMA stage, sub-4 KiB DMA+PIO stage and the waiting-stage poll sequence correctly; `bytes_done` accounting closes exactly on `size`. Dissolved (its alarm guard is PROPOSED-004, a separate point). READ.
- **tx_mixed waiting-stage reply content unchecked** (`mmce_sio2.c:462-475` approx.): the 2-byte "ready" poll result is tested only for timeout, never for content. Without the firmware protocol document this cannot be called a defect — the reply may be a pure synchronisation beat. INFERRED, not counted.
- **dread stat block** (`mmce_fs.c:985-1040`): fixed 0x2A-byte packet into a 0x2B-byte buffer; every field assembled byte-wise from indices ≤0x29. The filename *length* is the only firmware-sized element — see PROPOSED-002 (termination) and the dissolved overflow half there. READ.
- **getstat** (`mmce_fs.c:1062-1185`): fixed 0x2b-byte reply into a 0x2B buffer; the firmware failure byte at `rdbuf[0x29]` is checked *before* any stat field is decoded (:1130-1131), so no stale-field decode on failure. Clean. READ. (Inventory nit, not filed: `u8 wrbuf[0xFF]` at `mmce_fs.c:1070` is a 255-byte stack buffer of which 4 bytes are ever used — a 251-byte stack saving available whenever anyone next touches the function.)
- **lseek/lseek64** (`mmce_fs.c:571-625`, `:1253-1313`): firmware position bytes are assembled and returned as a *value*, never used as a length, count or index locally. Dissolved per the round's standing note. READ.
- **active-card synthetic handle** (`mmce_fs.c:34-200`): `mmce_fs_active_read` rejects negative size (:160), clamps to the discovered image size (:166-167), and preserves the cardman descriptor position around the read (:181-190); `mmce_fs_discover_active_fd` refuses to reset under open handles or a busy card (:110-121). Clean. READ.
- **negative/oversized `size` from the EE caller** in read/write: not guarded (only the synthetic path checks `size < 0`), but the EE caller is trusted code on the same console and the posture matches the trusted-caller treatment already recorded for ata_bd in earlier rounds. Dissolved as trusted-caller. READ.
- **wire-name lengths**: `mmce_fs_wire_name_ok` (`mmce_restore_guard.h:12-22`) caps names at 254 chars before any `strlen(name)+1` is narrowed to u8 in open/remove/mkdir/rmdir/dopen/getstat/rename — the narrowing is safe on every path that has the check, and every fs entry point in the re-read set has it. Dissolved. READ.
- **tx_rx_pio NULL buffers** (`mmce_sio2.c:190-243`): every in-tree caller pairs a NULL buffer with a 0 size for that direction (grep-verified across mmce_fs.c/mmce_cmds.c), so the unguarded `tx_buf[i]`/`rx_buf[i]` loops never dereference NULL at the pin. Dissolved. READ.

### Local-delta notes (Task A)
None applicable — mmceman is Launchstation's own code, not a vendored copy; no ORIGIN/upstream delta to verify.

---

## TASK B — block-device internals

### Coverage ledger (Task B)

| File | Lines | Ranges read |
|---|---|---|
| `iop/ata_bd/src/ps2atad.c` | 1,581 | 1–1581 in full |
| `iop/usbmass_bd/src/usb_mass.c` | 901 | 1–901 in full |
| `iop/usbmass_bd/src/scsi.c` | 440 | 1–440 in full |
| `iop/usbmass_bd/src/main.c` | 37 | in full |
| `iop/usbmass_bd/ORIGIN.md` | 48 | in full (the 11 enumerated local fixes) |
| `iop/usbmass_bd/src/include/scsi.h`, `module_debug.h` | 37 / 36 | in full |
| `iop/ata_bd/include/atad.h`, exports/imports | — | NOT read (not needed: interaction surface is the .c + build defines) |
| Build wiring | — | `ps2.yaml` ata_bd stanza (:395-407) and usbmass_bd_fork stanza (:189-199) read |

### Local-delta verification — usbmass_bd (ORIGIN.md's 11 fixes, all READ-verified present at the pin)

| # | Fix (per ORIGIN.md) | Verified at |
|---|---|---|
| 1 | Command semaphore serialising `usb_queue_cmd` across drives | `usb_mass.c:469` WaitSema / `:506` SignalSema; created initial-1 at `usb_mass.c:857` |
| 2 | Bounded TEST UNIT READY wait (1000 tries × 10 ms) | `scsi.c:18` (SCSI_READY_TRIES), `scsi.c:230` (bound + unplug check), `scsi.c:234` (DelayThread) |
| 3 | Failed start-up not handed to BDM | `scsi.c:397-400` (`scsi_warmup == 0 && bd->priv != NULL` → connect, else `bd->priv = NULL`) |
| 4 | Request straddling the 32-bit LBA limit uses READ/WRITE(16) | `scsi.c:150` (`lba + sectorCount <= 0x100000000ull` gates the (10) form) |
| 5 | Sector size 0 rejected | `scsi.c:244-249` — present, but see PROPOSED-006: ==0 is the *only* value checked |
| 6 | Zero-length packet ends a bulk transfer; short data fails the command | `usb_mass.c:143-156` (callback stops on `bytes == 0`), `usb_mass.c:430-432` (`remaining > 0` → -EIO) |
| 7 | Unplugging a failed-start-up drive frees its slot | `usb_mass.c` disconnect else-if branch (status cleared but devId set → devId = -1, DeleteSema) |
| 8 | Empty CSW re-read; truncated CSW fails with reset recovery | `usb_mass.c:280-283` (returnSize 0 → DATAUNDER retry path; partial → signature zeroed) plus manage_status retry/reset |
| 9 | Unplug during start-up stops start-up | `scsi.c:78` and `:129` (NULL-priv guards in scsi_cmd / read_capacity16), `scsi.c:230` (ready loop), `scsi.c:193` (warmup entry) — but see PROPOSED-007: the guard was not applied to the read/write path |
| 10 | Semaphore-creation failure fails start-up cleanly, freeing the created one | `usb_mass.c` init: both CreateSema results checked, the successful one deleted on failure |
| 11 | Unplug during the last start-up step keeps the drive out of BDM | `scsi.c:397` (post-warmup `bd->priv != NULL` re-check) |

All 11 fixes are present as described. No regression or partial application was found except the two gaps filed below (fix 5's narrowness, fix 9's incomplete spread) — both are "the fix is real but stops one step short", not reversals.

### Proposed findings (Task B)

#### PROPOSED-006 — scsi_warmup accepts any non-zero sector size a device reports; absurd values break the size print's arithmetic and wrap every transfer length
- Category: 6 (device-supplied value used as a divisor / size multiplier unchecked)
- Locations: `iop/usbmass_bd/src/scsi.c:244-249` (READ_CAPACITY(10) block length stored, only `== 0` rejected — local fix #5), `scsi.c:254` and `:267` (warmup size prints), `scsi.c:261` (READ_CAPACITY(16) block length, checked only `!= 0` at :259), `scsi.c:156` and `:174` (`bd->sectorSize * sectorCount` as the transfer length)
- Problem: READ for the arithmetic. The device-supplied block length is trusted after a single zero check. Two consequences in-tree: (1) the warmup capacity prints compute `sectorCount / ((1000*1000) / sectorSize)` and `sectorCount / ((1024*1024) / sectorSize)` — for any reported sector size above 1,000,000 the inner division yields 0 and the outer one divides by zero (on the IOP's MIPS core that produces an undefined quotient rather than a trap — INFERRED hardware behaviour — so the certain impact is garbage diagnostics, not a proven crash; the prints are live code in this build because the fork target at `ps2.yaml:190-199` does not define MINI_DRIVER, so `M_PRINTF` is a real printf per `module_debug.h:11-12`); (2) more seriously, the same value multiplies every READ/WRITE transfer length at :156/:174 in 32-bit arithmetic — a device reporting e.g. 0x20000-byte blocks wraps the product for counts above 32 KiB of payload, so the CBW data length, the BDM buffer expectation and the actual sector count disagree for the life of the device.
- Fix: Extend fix #5's existing check at :246 from `== 0` to a plausibility test — sector size must be a power of two in [512, 4096] (every real USB mass-storage block size: 512/1024/2048/4096) — and apply the same test to the capacity16 value before adopting it at :261. One condition in each of two places; no new code paths.
- Benefit: A broken or hostile device is rejected at warmup instead of corrupting transfer-length arithmetic on every subsequent I/O.
- Effort: ~2 lines.
- Risk: A hypothetical device with 8192-byte blocks would be rejected; no such USB mass-storage device is known, and the current code cannot serve one correctly anyway (see consequence 2).
- Confidence: High for the unchecked arithmetic (READ); Medium for real-world trigger (needs a misreporting device).

#### PROPOSED-007 — The unplug NULL-priv guard (local fix #9) covers the start-up commands but not scsi_cmd_rw_sector or the read/write chunk loops
- Category: 3 (missing guard on one path of a guarded set) / race
- Locations: guards present at `iop/usbmass_bd/src/scsi.c:78` (`scsi_cmd`) and `scsi.c:129` (read_capacity16); absent at `scsi.c:139-176` (`scsi_cmd_rw_sector` dereferences `scsi->queue_cmd` at :156/:174 with no priv check) and at `scsi.c:287` / `scsi.c:330` (`scsi_read`/`scsi_write` read `scsi->max_sectors` from a possibly-NULL priv); priv is nulled on disconnect at `scsi.c:426-431` (`scsi_disconnect`)
- Problem: READ for the code asymmetry; INFERRED for concurrent reachability. Fix #9's own rationale — a drive unplugged mid-operation must not be used through a cleared pointer — was implemented for the warmup command helpers but not for the data path: `scsi_disconnect` sets `bd->priv = NULL` unconditionally, and nothing in `scsi_read`/`scsi_write`/`scsi_cmd_rw_sector` re-checks it between or within chunk iterations. If a disconnect lands while a multi-chunk read/write is in flight on another thread, the next chunk dereferences NULL (`scsi->max_sectors` / `scsi->queue_cmd`) instead of failing with -EIO. Whether BDM serialises disconnect against in-flight I/O is not established in this tree — if it does, this is latent; the warmup guards show the maintainers did not rely on that serialisation during start-up.
- Fix: Mirror the existing guard: return -1/`-EIO` from `scsi_cmd_rw_sector` when `bd->priv == NULL` (one check, same shape as `scsi.c:78`), which also covers both chunk loops since every chunk funnels through it.
- Benefit: The data path gets the same unplug behaviour fix #9 already promised for start-up.
- Effort: 2-3 lines.
- Risk: Minimal; a NULL priv can only mean the device is gone.
- Confidence: Medium — asymmetry READ, exploitability INFERRED (depends on BDM threading, unverifiable from this tree alone).

### ata_bd inventory (no findings filed)

- **Provenance**: `git log` for `iop/ata_bd/src/ps2atad.c` shows exactly one commit (the repo's initial commit) — zero local delta at the pin, consistent with the task brief. READ.
- **Build configuration actually used**: `ps2.yaml:397-407` builds it with `ATA_ENABLE_BDM=1`, `ATA_USE_DEV9=1`, `ATA_GAMESTAR_WORKAROUND=1`. The AIFDEV9, MWDMA and ATA_ALL_PIO_MODES code paths read in this pass are compiled out in Launchstation's build; the BDM callbacks and DEV9 DMA/PIO paths are the live ones.
- **Interaction check**: the BDM surface is `ata_bd_read`/`ata_bd_write`/`ata_bd_flush`/`ata_bd_stop` (end of file) forwarding `bd->devNr` into `ata_device_sector_io64`, with `g_ata_bd[i].sectorCount` populated from `total_sectors_lba48` inside `ata_init_devices` before `bdm_connect_bd`. Nothing in how Launchstation wires the module (defines above; lazy loading from EE `init.c` is outside this task's files) changes the vendored code's assumptions. Per the task rule — findings only where a defect interacts with Launchstation's use — nothing met that bar beyond the items already dissolved in earlier rounds.
- One behaviour worth an inventory line, not a finding: `_start` calls `sceAtaInit(0)` and `sceAtaInit(1)` and ignores their NULL-on-failure returns, and `sceAtaInit` latches `ata_devinfo_init` before attempting the bus reset — a transient init failure is therefore permanent for the module's lifetime. That is pristine upstream design, identical in the SDK's own ata_bd.irx; inventory only.

### Checked-and-clean / dissolved (Task B)

- **ata u16 chunking / len==0-means-65536** (`ata_device_sector_io64`): re-verified in this full read — LBA48 chunk cap 65536 with `len = (u16)chunk`, LBA28 cap 256, buffer/LBA advance by `chunk` each pass; matches the prior rounds' dissolution. READ.
- **ata retry loop**: retries a chunk only on `ATA_RES_ERR_ICRC` (3 attempts), breaks on any other result; progress is guaranteed because `chunk ≥ 1` whenever `nsectors > 0`, so `ata_bd_read`/`ata_bd_write` returning `count` on success is sound. Dissolved. READ.
- **ata security commands**: fixed 32-byte password copies into a zeroed 512-byte `ata_param` — already dissolved in earlier rounds; re-confirmed unchanged. READ.
- **usb_transfer_callback progress accounting** (`usb_mass.c:136-156`): `remaining -= bytes` trusts the USBD callback's byte count; a count exceeding `remaining` would underflow the unsigned remaining and over-transfer. The count originates in the in-tree USB stack, not the device payload, and the pattern is pristine upstream — INFERRED, not counted.
- **usb_queue_cmd result composition** (`usb_mass.c:469-510`): a failed data phase forces -EIO after status handling; a failed CBW send skips status and returns -EIO; the semaphore is signalled on every non-ASYNC exit. Clean. READ. (The ASYNC variant shares `ucmd` without the semaphore, but ASYNC is not defined at the pin — the define is commented out at `usb_mass.c:17` — so that path is not built; dissolved.)
- **usb_bulk_manage_status / fix #8 mechanics** (`usb_mass.c` status region): empty CSW → retry after clear-halt; partial CSW → signature invalidated → reset recovery and -1; tag/signature/status==2 all gate success. Matches ORIGIN #8 exactly. READ.
- **scsi warmup capacity**: `sectorCount` is set from READ_CAPACITY's *last LBA* without +1 (`scsi.c:243`). Whether BDM expects a count or a last-LBA from this field is an upstream convention question, the code is pristine upstream in this respect (not among the 11 local fixes), and no in-tree consumer in scope proves a mismatch — inventory, not filed. READ/INFERRED.
- **scsi_cmd command block** (`scsi.c:71-85`): 12-byte comData with the allocation-length byte set from the caller's size; INQUIRY (36) and REQUEST SENSE (18-byte struct) both fit the field and their buffers. Clean. READ.
- **scsi_write misalignment bounce** (`scsi.c:318-345` approx.): alloca of `sectorSize + 4`, realigned, one sector per command with `memcpy` of exactly `sectorSize` — correctly bounded as recorded in the brief; re-confirmed. READ.
- **usb_mass_connect/disconnect slot lifecycle**: devId is published last in connect (after a compiler barrier) and freed on both disconnect branches (connected, and start-up-failed per fix #7); a connect that fails before devId publication leaves the slot at -1 and reusable. Clean. READ.

### Local-delta notes (Task B)
- usbmass_bd: delta = exactly ORIGIN.md's 11 fixes over sdk-core `v2026.11.10`; verification table above. The two proposed findings are both "fix stops one step short" (##5, #9), not regressions.
- ata_bd: delta = zero (single-commit history at the pin); all content is vendored PS2SDK atad v2.7 (IRX_ID 2,7 in-file).

---

## Section totals
- Lines read in full this pass: mmce_fs.c 1,480 · mmce_sio2.c 602 · ps2atad.c 1,581 · usb_mass.c 901 · scsi.c 440 · main.c 37 · supporting headers/ORIGIN/build stanzas ~200. Total ≈ 5,240 lines.
- Proposed findings: 7 (PROPOSED-001…007) — Task A: 5, Task B: 2.
- Left unread (declared): mmce_cmds.c body (prior-round coverage; only grepped), ata_bd headers/exports, usbmass_bd imports/irx_imports (build glue, no logic).
