# Cross extraction

## Verdicts
| ID | Title | Effort | Risk | Verdict |
|---|---|---|---|---|
| RE-X-01 | RiptOPL UDPRDMA receive copies a wire-controlled app-header length into fixed buffers; SMS already clamps it | S | Low | VERIFIED |
| RE-X-02 | RiptOPL read path returns a wire-controlled byte count from an uninitialised reply struct; SMS zero-inits and clamps | S | Low | VERIFIED |
| RE-X-03 | A pre-hardening copy of the UDPFS Python server ships inside RiptOPL with none of the current server's wire-value validation | S | Low | VERIFIED-DRIFT |
| RE-X-04 | Standalone UDPBD Python server range-checks READ only for raw devices and WRITE not at all; the Go server refuses out-of-range for both | S | Low | VERIFIED |
| RE-X-05 | Python and Go UDPFS servers disagree on BWRITE completion: Python silently truncates over-delivered data and reports 0, Go requires exact length and reports the byte count | M | Low | VERIFIED-DRIFT |
| RE-X-06 | SMS block read treats EOF/short reads as full success and leaves stale bytes in the caller's buffer; RiptOPL already handles both | S | Low | VERIFIED |
| RE-X-07 | SMS's SMAP FIFO read still drops the last byte of odd-sized frames; RiptOPL and Launchstation both carry the fix | S | Low | VERIFIED |
| RE-X-08 | SMS's send path accepts any ACK as covering the sent packet (stale-ACK check is arithmetically inert); RiptOPL waits on the same timer with a real coverage test | M | Medium | VERIFIED |
| RE-X-09 | SMS ignores `SetAlarm` failure and can wait forever for an ACK/timeout that will never be signalled; RiptOPL fails the wait as a timeout | S | Low | VERIFIED-DRIFT |
| RE-X-10 | Go UDPFS server returns all-zero timestamps (and zero attr) in OPEN_REPLY / DREAD_REPLY / GETSTAT_REPLY; Python returns real times | S | Low | WEAKENED |
| RE-X-11 | Discovery header's second field is documented as "reserved, must be 0" in C but is the data port in both servers; the C client ignores it and trusts the UDP source port instead | S | Low | VERIFIED |
| RE-X-12 | RiptOPL carries three byte-identical copies of every UDPFS wire header (plus the ACK helper); SMS proves one copy per module is enough | M | Medium | VERIFIED-DRIFT |
| RE-X-13 | Launchstation's dashboard starter `title.cfg` is written with spaced `title = / boot =` lines that RiptOPL's parser silently drops — the app vanishes from RiptOPL's Apps list | S | Low | VERIFIED |
| RE-X-14 | Same shared `title.cfg`, same concept, different key: Launchstation writes launch arguments as `arg=`, RiptOPL reads `argv1=` — each silently ignores the other's | S | Low | WEAKENED |
| RE-X-15 | POPSLoader `ata_bd_fast`: LBA48 chunk counted in a `u16` — requests over 65536 sectors never advance (livelock) | S | Low | WEAKENED |
| RE-X-16 | Tarball `usbmass_bd` scsi: READ/WRITE(10)-only (silent >2 TiB LBA truncation) and an unbounded TEST UNIT READY loop; the fixed driver exists byte-identical in RiptOPL and Launchstation | S | Low | VERIFIED |
| RE-X-17 | Tarball BDM core is the unhardened snapshot: GPT/MBR parsers and block cache lack every RiptOPL guard | M | Medium | VERIFIED-DRIFT |
| RE-X-18 | ps2ips RPC: the two copies fixed opposite halves — each still carries the other's bugs | M | Medium | VERIFIED-DRIFT |
| RE-X-19 | DS3 battery index `power_level[Power]` out-of-bounds in 8 of 10 ds34 copies | S | Low | VERIFIED |
| RE-X-20 | ds34bt DS4 LED report: `memset` length is the DS3 length in 4 of 5 copies (29 bytes of stack sent) | S | Low | VERIFIED |
| RE-X-21 | ds34usb endpoint walk: `bNumEndpoints == 0` makes `epCount = -1` and the do-while never terminates; no `bLength == 0` check anywhere | S | Low | VERIFIED |
| RE-X-22 | SMS lwIP `ip_frag`: reassembly bitmap is one byte short — a fragment ending exactly at `IP_REASS_BUFSIZE` writes out of bounds | S | Low | VERIFIED |
| RE-X-23 | Launchstation APA retains the SDK error-sector defects RiptOPL removed: NULL-deref, cache leak, and a write into the APA table sector from read paths | S | Low | VERIFIED-DRIFT |
| RE-X-24 | Launchstation `hdd_fio.c`: u32 `sector + size` overflow passes the bounds check, and on-disk `nsub` is unbounded past the 64-entry subs array | S | Low | VERIFIED |
| RE-X-25 | Launchstation + POPSLoader atad: no LBA range check and no 4Kn refusal (RiptOPL-only guards) | S–M | Low | VERIFIED-DRIFT |
| RE-X-26 | Tarball `bdmfs_fatfs` fs_driver: volume index is the raw ioman unit — cross-device filesystem misrouting that RiptOPL's copy fixed | M | Medium | WEAKENED |
| RE-X-27 | SMS `ums_fat`: FAT chain walks never validate the cluster number; BPB FAT-size/count fields unvalidated (no sibling fix exists) | S | Low | VERIFIED |
| RE-X-28 | Default POPSTARTER.ELF shipped by both repos is the DEBUG build | S | Low | VERIFIED |
| RE-X-29 | SMS ships every IRX twice: plain + xz with identical payloads | S | Low | WEAKENED |
| RE-X-30 | BDMAssault variant names overstate the binary count; RiptOPL's canonical provenance record omits the .udpfs pair | S | Low | VERIFIED-DRIFT |
| RE-X-31 | RiptOPL `drvtif-ingame.irx` is a byte-identical second copy of `drvtif.irx` | S | Low | VERIFIED |

## Narrowed scopes
- RE-X-10: Timestamps only — the attr half is not a divergence (Python hard-codes attr 0 in every stat path and OPEN_REPLY has no attr field), and full ctime/atime parity is new code, not a fill-in (DREAD's DirEntry carries only ModTime, os.FileInfo exposes no portable ctime/atime, most OPEN paths never stat, and no PS2 8-byte time encoder exists in the Go tree); mtime parity alone is the small sane fix.
- RE-X-14: Key-name divergence for the single-argument case only — RiptOPL's `argv1` is a single argument while Launchstation's `arg` is repeatable, one-per-line, multi-argument, so the proposed fix delivers only prospective single-argument parity in one direction and the unqualified benefit claim is overstated for existing and multi-`arg=` files.
- RE-X-15: A real livelock (trigger actually nsectors ≥ 65536) in unused vendored source only — the shipped `ata_bd.irx` is the pinned R3Z v4.70 binary, the Makefile states the `iop/ata_bd_fast` source/build rule is kept but unused, and the in-file BDM wrapper (u16 count, max 65535) cannot trigger it, so the filed shipped-loader exposure is not established; worth fixing before any re-enablement.
- RE-X-26: The tarball lacks transport-stable addressing only — `massN` identity follows connection order; within the tarball's own architecture (exactly one ioman driver named "mass", no `path` field, no typed drivers) no request is misrouted relative to the names the stack exposes, and RiptOPL itself preserves the same unit-as-index semantics for "mass".
- RE-X-29: Each of 19 payloads is stored twice in different encodings by design of the compress/gate pipeline, not as dead weight — the EE build consumes only the `.xz` form, but the plain set is the regeneration source for `tools/compress_irx.py`, the landing form for module rebuild scripts, and a gate input, so the filed fix would break the documented workflow; the finding survives only as a repo-hygiene preference, not the filed duplication defect.

## Defeating evidence
None.

Sub-claim refutations:
- RE-X-23 (sub-claim): The claim that the stripped Launchstation `iop/hdl_info/apa.c` (320 lines) contains the same `apaSaveError`/`apaSetPartErrorSector` pair is refuted — grep for `SaveError|SetPartError|GetPartError|apaCache|PART_ERROR` in that file returns 0 hits; it is a different, malloc-based APA parser with no cache and no error-sector writes (though it is built and loaded), so the fix scope is the single `ps2hdd_osd` copy only.

## Candidates
### CAND-01
- Label: Python `_complete_bwrite` discards the `write()` return value and credits `expected_size` to `stats['bytes_written']` even on short delivery or short OS write
- Mechanism: In `_complete_bwrite` the file-object `write()` result is discarded and `stats['bytes_written']` is credited the full `expected_size` regardless of how much was actually delivered or written. This is accounting/observability only; the on-wire behaviour is RE-X-05 itself.
- Locations: PS2-Servers `udpfs_server/udpfs_server.py:2176-2178` (current server); the stale shipped copy has the same pattern at `:1035-1037`
- Proposed class: EXTENSION of RE-SERV-030
- Justification: Same `_complete_bwrite` fix site — RE-SERV-030 already files the unconditional `expected_size` crediting on short delivery; the candidate adds the discarded `write()` return / short-OS-write limb.

### CAND-02
- Label: Scope extension of RE-X-13 — same spaced `title.cfg` form in a Launchstation docs example
- Mechanism: `Launchstation/docs/dashboard.md:318-327` shows the same spaced `title = …` / `arg = …` form in an example block for a file the page itself calls OPL format, so a docs copy-paste produces the same RiptOPL-vanishing file as the `dash_apps.c` starter.
- Locations: Launchstation `docs/dashboard.md:318-327`
- Proposed class: EXTENSION of RE-X-13
- Justification: Same wrong writer/form and same fix as RE-X-13; the verify report explicitly places it in RE-X-13's fix scope alongside `dash_apps.c` and the locking test, and no per-repo filing covers this docs instance.

### CAND-03
- Label: SMS `ip_frag` completeness loop never checks bitmap byte 89 (distinct from RE-X-22)
- Mechanism: SMS `ip_frag.c:192` completeness loop `i < ip_reasslen/64 - 1` never checks bitmap byte 89 for a 5760-byte datagram, so a hole at payload 5696-5759 passes as complete. RiptOPL fixed this too, with an explicit comment.
- Locations: Simple-Media-System `iop/SMSTCPIP/src/ip_frag.c:192`; RiptOPL fixed form `modules/network/SMSTCPIP/ip_frag.c:206-213`
- Proposed class: NEW
- Justification: Distinct loop-bound mechanism (false completeness) from RE-X-22's bitmap sizing and from RE-SMS-016's IPH_LEN trust / bitmap-index OOB; grep of the per-repo redo reports found no filing of this completeness hole.

### CAND-04
- Label: Extension of RE-X-27 — SMS `ums_fat` `FATFS_Init` likewise never zero-checks `m_nResSectors`
- Mechanism: `FATFS_Init` never zero-checks `m_nResSectors`; 0 reserved sectors makes FAT reads start at the BPB sector. This is the same unvalidated-BPB-field family RE-X-27 files for `m_nFATs`, `m_FATSize`, and `m_RootSize`.
- Locations: Simple-Media-System `iop/SMSUMS/src/ums_fat.c` (`FATFS_Init`, `m_nResSectors` at `:1067/:1079`)
- Proposed class: EXTENSION of RE-X-27
- Justification: Same function, same zero-check fix, and same field family as RE-X-27; the verify report explicitly describes it as an extension of RE-X-27 and grep found no per-repo filing of `m_nResSectors`.

### CAND-05
- Label: Folds into RE-X-24 — Launchstation `ioctl2Transfer` indexes `parts[arg->sub]` bounded only by unchecked on-disk `nsub`
- Mechanism: `ioctl2Transfer` indexes `fileSlot->parts[arg->sub]` where `arg->sub` is bounded only by the unchecked on-disk `nsub`; `nsub > 64` therefore also yields an out-of-bounds `parts[]` read in the transfer path, in addition to RE-X-24's stat/open walk.
- Locations: Launchstation `iop/ps2hdd_osd/hdd_fio.c:277, :280-282` (indexing), bound at `:267` vs the unbounded copy at `:473`
- Proposed class: EXTENSION of RE-X-24
- Justification: Same root cause and same fix as RE-X-24 (refuse/clamp `nsub > APA_MAXSUB`); the verify report explicitly says it folds into RE-X-24.

### CAND-06
- Label: Shared defect, both trees — `fatfs_fs_driver_get_mounted_bd_from_index` bounds-checks with `>` instead of `>=`
- Mechanism: The mount-info lookup guards with `>` instead of `>=`, so index == 10 reads one element past the 10-entry mount array. The defect is present identically in the tarball copy and in RiptOPL's maintained copy; it is not a divergence.
- Locations: Tarball `bdmfs_fatfs/src/fs_driver.c:141`; RiptOPL `modules/bdm/bdmfs_fatfs/src/fs_driver.c:140`
- Proposed class: REJECTED
- Justification: Full duplicate — the same function, guard, and index-10 OOB at the same sites are already filed per-repo as RE-POPS-011 (tarball copies) and RE-RIPTOPL-065 (RiptOPL maintained copy).
