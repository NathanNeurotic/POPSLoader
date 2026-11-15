# Redo Audit — Master Index (post-verification status ledger)

Stage C reconciliation of the blind redo audit. Every one of the 863 redo findings, with its final status after the Stage B adversarial verification. Statuses:

- **STANDING** — verification verdict VERIFIED; the finding stands exactly as filed in its redo report.
- **STANDING-DRIFT** — verdict VERIFIED-DRIFT; the mechanism and fix stand, but citations or figures were corrected during verification. **The corrected values live in the verify report named in the row's note and supersede the redo report's numbers** — finding bodies were not rewritten.
- **REVISED** — verdict WEAKENED; the defect is real but narrower than filed. The row's note states the narrowed true scope, which supersedes the filed scope.
- **WITHDRAWN** — verdict REFUTED; the row's note states the defeating evidence. A matching WITHDRAWN note was added under the finding's heading in its redo report.
- **NEW** — a distinct defect found by the Stage B verifiers (candidate screening class (a)); the full finding text is in `Redo-NEW-FINDINGS.md`.

Fix-scope extensions (candidate screening class (b)) are recorded in the parent finding's note; they add locations/instances to an existing fix and carry no number of their own. Rejected candidates (class (c)) are listed with reasons in Appendix A. Pins: RiptOPL `2e347d5ac885`, Launchstation `9fb0598a79f0`, POPSLoader `29272cddbf01`, SMS `e65ced39a27e`, PS2-Servers `c5f021c4d386`. Nothing under `~/workspace/Sable-audit/` was read at any stage.

## RiptOPL

| ID | Title | Effort | Risk | Status | Note |
|---|---|---|---|---|---|
| RE-RIPTOPL-001 | SMB1 reply length is server-controlled and overflows the static SMB buffer | S | Low | STANDING | — |
| RE-RIPTOPL-002 | SMB1 ReadAndX trusts the server's data length and padding; WriteAndX in the same file was already hardened | S | Low | STANDING | — |
| RE-RIPTOPL-003 | Negotiate Protocol copies a server-controlled key length into an 8-byte field | S | Low | STANDING | — |
| RE-RIPTOPL-004 | SMB1 transaction replies use server offsets as raw indices into the receive buffer | M | Low | STANDING | — |
| RE-RIPTOPL-005 | UDPRDMA receive ISR lets a peer claim an app-header up to 60 bytes into 32-byte (or smaller) buffers | S | Low | STANDING | — |
| RE-RIPTOPL-006 | `sysWriteNeutrinoCheats` accumulates `snprintf` returns into a length with no truncation check | S | Low | REVISED | Narrowed scope: Latent unsafe `snprintf`-accumulation idiom only: the buffer is sized `512 + pairs*32` and each pair emits a fixed 28-char line with caller-bounded header inputs, so no reachable input truncates or makes `size - len` negative — no live heap overwrite as filed. |
| RE-RIPTOPL-007 | APA journal restore trusts the on-disk entry count and a possibly-NULL cache entry | S | Low | STANDING | — |
| RE-RIPTOPL-008 | mcemu (HDD): an unmapped VMC page silently maps to sector 0 | S | Low | STANDING | — |
| RE-RIPTOPL-009 | SYSTEM.CNF parser can return an unterminated key and reads before its bounds check | S | Low | STANDING | — |
| RE-RIPTOPL-010 | GPT parser trusts header entry size and never checks first_lba ≤ last_lba | S | Low | STANDING | — |
| RE-RIPTOPL-011 | ZSO decompression uses the unbounded LZ4 "fast" decoder on untrusted image data | S | Low | STANDING | Fix-scope extension (Stage B, RiptOPL CAND-03): ZSO `c_buff += b_size` advances by the unclamped index-derived size |
| RE-RIPTOPL-012 | BT DS4 LED/rumble report: 50 bytes initialised, 79 bytes sent | S | Low | STANDING | — |
| RE-RIPTOPL-013 | ps2ips RPC handlers trust EE-supplied length fields (`optlen`, `malign`) | S | Low | STANDING | Fix-scope extension (Stage B, RiptOPL CAND-02): ps2ips do_send/do_sendto `sendlen - pkt->malign` underflow |
| RE-RIPTOPL-014 | UDPFS core returns the server's claimed byte counts without checking them against what arrived | S | Low | STANDING | — |
| RE-RIPTOPL-015 | iLink SCSI layer silently wraps LBAs on drives over 2 TiB | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-016 | tar reader never validates the ustar header checksum, and size parsing ignores base-256 | S | Low | STANDING | — |
| RE-RIPTOPL-017 | TCP header length from the wire is trusted; `pbuf_header` result ignored | S | Low | STANDING | — |
| RE-RIPTOPL-018 | smap-ingame's low-level output copies a pbuf chain into a fixed frame buffer without a total-length check | S | Low | STANDING | — |
| RE-RIPTOPL-019 | MMCE `get_gameid` does an unbounded `strcpy` from the card reply into the caller's buffer | M | Med | STANDING | — |
| RE-RIPTOPL-020 | Hardcoded parental-lock master password in a public header | S | Low | STANDING | — |
| RE-RIPTOPL-021 | `HIOCGETSIZE` indexes the partition array with an unchecked EE-supplied index | S | Low | STANDING | — |
| RE-RIPTOPL-022 | `err_to_errno` macro never consults its table: every socket error collapses to EIO | S | Low | STANDING | — |
| RE-RIPTOPL-023 | Deferred dialog wait is unbounded while the sibling message wait is bounded | S | Low | STANDING | — |
| RE-RIPTOPL-024 | Self-update overwrites the running ELF in place and never verifies what landed | M | Med | STANDING | — |
| RE-RIPTOPL-025 | The default ship/POPS/POPSTARTER.ELF is byte-identical to the DEBUG variant, not the MAIN variant | S | Med | STANDING | — |
| RE-RIPTOPL-026 | `.bak` staging files can permanently block later writes and are never cleaned up | M | Med | STANDING | — |
| RE-RIPTOPL-027 | DEVCTL STOP_UNIT and STOP_ALL do the opposite of their names | S | Med | STANDING | — |
| RE-RIPTOPL-028 | APA partition helpers trust on-disk counts and indices | S | Low | REVISED | Narrowed scope: Only the `hddGetFileBlockInfo` half holds — `subs[stat.private_4]` is indexed unchecked at hdd.cpp:438-446; the negative-`nsub` half does not hold as stated, because `nsub` is an unsigned on-disk field and a value ≥2^31 makes the copy loop never execute and returns a bogus negative count rather than an out-of-bounds walk. |
| RE-RIPTOPL-029 | ELF program-header copies are unvalidated in two loaders, while a third loader in the same tree validates them | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-030 | `do_bind` dereferences unchecked `udp_new()`/`tcp_new()` results | S | Low | STANDING | Fix-scope extension (Stage B, RiptOPL CAND-01): do_bind RAW branch `raw_new()` unchecked (api_msg.c) |
| RE-RIPTOPL-031 | Sequential API and `lwip_accept` dereference NULL conn/PCB states the socket layer itself documents | S | Low | STANDING | — |
| RE-RIPTOPL-032 | `pbuf_realloc` use-after-free chain through `ps2ip_mem_realloc` | S | Low | STANDING | — |
| RE-RIPTOPL-033 | `copy_from_pbuf` walks off the end of the pbuf chain | S | Low | STANDING | — |
| RE-RIPTOPL-034 | Socket entry points dereference caller sockaddr pointers unchecked; `lwip_sendto` ignores connect/disconnect errors | S | Low | STANDING | — |
| RE-RIPTOPL-035 | `lwip_recvfrom`: error conflated with EOF, and the SMB header index is trusted | S | Low | REVISED | Narrowed scope: Only the error/EOF conflation holds (`lwip_recvfrom` returns 0 with errno 0 on `netconn_recv` failure); the header-index half is latent only — the sole in-tree caller passes the constant index 49, inside the 63 bytes copied into the 1024-byte `SMB_buf`, and downstream code already guards `index > avail_len`. |
| RE-RIPTOPL-036 | NBNS resolver validates only the header size, then reads the answer at a fixed offset | S | Low | STANDING | — |
| RE-RIPTOPL-037 | smb_fio path handling can walk before the buffer and can leave stored names unterminated | S | Low | REVISED | Narrowed scope: Only part (b) holds — `smb_dopen`/`smb_open` can leave stored names unterminated; part (a) is refuted, because `prepare_path`'s backward-walk condition is false on the NUL terminator for every input, so `p2` never decrements — the loop is dead, not a walk before the buffer. |
| RE-RIPTOPL-038 | Skip-Videos check reads before the path buffer for short filenames | S | Low | STANDING | — |
| RE-RIPTOPL-039 | SMB1 request assembly writes strings into the fixed packet buffer with no bound anywhere | S | Low | STANDING | — |
| RE-RIPTOPL-040 | ps2link file read trusts the host's byte count over the caller's buffer | S | Low | STANDING | — |
| RE-RIPTOPL-041 | fs_ioctl fabricates a 1024-byte argument length for fs_ioctl2 | S | Low | STANDING | — |
| RE-RIPTOPL-042 | mmce devctl dereferences `arg` unchecked in four cases — the fifth case in the same switch checks | S | Low | STANDING | Fix-scope extension (Stage B, RiptOPL CAND-07): mmce `MMCE_CMD_SET_GAMEID` uses `arg` as a string with no NULL/arglen check |
| RE-RIPTOPL-043 | APA cache entries are dereferenced after `apaCacheFree` | S | Low | STANDING | — |
| RE-RIPTOPL-044 | usbmass_bd SCSI: READ CAPACITY's last-LBA is stored as the sector count (off by one, both variants) | S | Low | STANDING | — |
| RE-RIPTOPL-045 | Partition notification dereferences a possibly-NULL `strchr` result | S | Low | STANDING | — |
| RE-RIPTOPL-046 | IOPRP patching runs `strcmp`/`strcpy` on fixed 10-byte ROMDIR names that need not be NUL-terminated | S | Low | STANDING | — |
| RE-RIPTOPL-047 | Network IP settings are parsed with unchecked `sscanf`, while the RA host IP in the same file is parsed properly | S | Low | STANDING | — |
| RE-RIPTOPL-048 | `lngGetFilePath` indexes `languages[langID - 1]` with no range check | S | Low | STANDING | — |
| RE-RIPTOPL-049 | `icmp_dest_unreach` uses an unchecked `pbuf_alloc` result | S | Low | STANDING | Fix-scope extension (Stage B, RiptOPL CAND-04): `icmp_time_exceeded` repeats RE-RIPTOPL-049's unchecked `pbuf_alloc` pattern |
| RE-RIPTOPL-050 | `ps2ip_input` interrupt path permanently loses queue slots on allocation failure | S | Low | STANDING | — |
| RE-RIPTOPL-051 | `common/smstcpip.h` import ordinals disagree with SMSTCPIP's export table | S | Low | STANDING | — |
| RE-RIPTOPL-052 | `recv_udp` leaks the pbuf when the connection has no receive mbox yet | S | Low | REVISED | Narrowed scope: The missing `else pbuf_free(p)` in `recv_udp` is real, but the claimed arrival window is not established: every entry point creates the recvmbox before the PCB can match a packet, and before bind/connect the PCB's local port is 0, so no concrete in-tree sequence reaches the NULL-mbox state with a deliverable datagram. Fix-scope extension (Stage B, RiptOPL CAND-05): `recv_raw` shares `recv_udp`'s missing-free shape |
| RE-RIPTOPL-053 | Peer MSS of 0 is accepted and yields zero-length segments | S | Low | STANDING | — |
| RE-RIPTOPL-054 | httpclient's response reader copies without knowing the caller's buffer size | S | Low | STANDING | — |
| RE-RIPTOPL-055 | raudp discovery compares a sender address that may never have been filled in | S | Low | REVISED | Narrowed scope: The uninitialised/stale `from` read in `ra_discover` is real, but it feeds only a skip-only `continue` gate; peer acceptance additionally requires `got >= 8`, the `"RAO1 OK "` prefix, a non-broadcast IP and ARP resolution, so a garbage `from` can at most spuriously skip one poll — it cannot steer the trust/pinning decision. |
| RE-RIPTOPL-056 | rapull setup leaks earlier allocations when a later one fails | S | Low | WITHDRAWN | Defeating evidence: The sole caller `rp_thread` frees every persistent block on any `rp_setup()` failure (rapull.c:337-347: `rp_win`, `rp_entry_off`, `rp_node_val`, `rp_stage`, `rp_list`), and `rp_setup` itself frees the scratch `bits` block on both paths — no allocation survives a failed setup, so there is no lifetime leak. |
| RE-RIPTOPL-057 | BDM VMC exports dereference the block device with no NULL check | S | Low | STANDING | — |
| RE-RIPTOPL-058 | HDD DeviceInit retries the APA header read forever | S | Low | STANDING | — |
| RE-RIPTOPL-059 | HDPro transfer loop retries a failing command indefinitely | S | Low | STANDING | — |
| RE-RIPTOPL-060 | ps2link receive loop spins forever when the host closes the connection | S | Low | STANDING | — |
| RE-RIPTOPL-061 | ps2link exception handler dereferences a possibly-NULL module name and copies unbounded | S | Low | STANDING | — |
| RE-RIPTOPL-062 | udptty write path always reports 0 bytes written and discards the send result | S | Low | STANDING | — |
| RE-RIPTOPL-063 | GPT driver reports success when its scratch allocation fails | S | Low | STANDING | — |
| RE-RIPTOPL-064 | USBMASS_IOCTL_GET_LBA dereferences a possibly-NULL block device | S | Low | STANDING | — |
| RE-RIPTOPL-065 | Mount-info index guard is off by one (and admits negatives) | S | Low | STANDING | — |
| RE-RIPTOPL-066 | bdm_disconnect_fs never unmounts anything | S | Med | STANDING | — |
| RE-RIPTOPL-067 | MBR sanity check is tautological and all-or-nothing | S | Low | STANDING | — |
| RE-RIPTOPL-068 | diskio GET_SECTOR_COUNT truncates a 64-bit sector count to 32 bits | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-069 | MX4SIO: unknown CSD structure version is accepted with a zero/stale sector count | S | Low | STANDING | — |
| RE-RIPTOPL-070 | MX4SIO recovery re-reads card geometry in place while BDM/FatFs stay mounted | S | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-071 | pademu USB: `outEndp` is never initialised, so the OUT endpoint is never opened on first connect | S | Low | STANDING | — |
| RE-RIPTOPL-072 | Standalone ds34 copies index `power_level[]` with an unvalidated device byte | S | Low | STANDING | — |
| RE-RIPTOPL-073 | Standalone ds34usb SET_LED RPC: EE sends 2 bytes, IOP reads 4 | S | Low | STANDING | — |
| RE-RIPTOPL-074 | BT `hid_readReport` length validation is absent (standalone) or offset-blind (pademu) | S | Low | STANDING | — |
| RE-RIPTOPL-075 | `get_data` memcpy size is never clamped to the 18-byte pad data union | S | Low | STANDING | — |
| RE-RIPTOPL-076 | pademu USB `readReport` has no transfer length at all | S | Low | STANDING | — |
| RE-RIPTOPL-077 | `usb_config_set` passes a partly uninitialised `led[4]` to LEDRumble | S | Low | STANDING | — |
| RE-RIPTOPL-078 | One L2CAP buffer, three different transfer sizes | S | Low | STANDING | — |
| RE-RIPTOPL-079 | Standalone USB `set_bdaddr` transfers 24 bytes, writes 23 | S | Low | STANDING | — |
| RE-RIPTOPL-080 | Standalone USB driver shares one transfer buffer and one result code across both pads | M | Med | REVISED | Narrowed scope: The shared `usb_buf`/`usb_resulCode` are real, but two-pad RPC interleaving cannot occur as framed because all pad operations are serialised through one `rpc_sf`/`SifRpcLoop` thread; the true hazard is narrower — the driver's own async USB configuration callback and a pending interrupt transfer completing into the shared buffer/result. |
| RE-RIPTOPL-081 | Exported iLink transaction-context accessors index the context array unchecked | S | Low | STANDING | — |
| RE-RIPTOPL-082 | `GetBIOSVersion` parses an uninitialised buffer when the ROM open/read fails | S | Low | STANDING | — |
| RE-RIPTOPL-083 | `InitializeConfigurationROM` silently drops and leaks every registered extra CROM unit | S | Low | STANDING | — |
| RE-RIPTOPL-084 | mmce command functions transmit uninitialised trailing stack bytes | S | Low | STANDING | — |
| RE-RIPTOPL-085 | mmce_fs truncates every filename length into a `u8` | S | Low | STANDING | — |
| RE-RIPTOPL-086 | genvmc segfaults when run without arguments (usage printed, then argv[1] dereferenced) | S | Low | STANDING | — |
| RE-RIPTOPL-087 | ziso.py decompression loops forever on a corrupt or truncated ZSO block | S | Low | STANDING | — |
| RE-RIPTOPL-088 | Unbounded `sprintf` in PadEmu info formatting (safe today only by input clamping) | S | Low | STANDING | — |
| RE-RIPTOPL-089 | File Manager paste path uses aliased `strcpy` inside another call's argument | S | Low | REVISED | Narrowed scope: Both cited lines exist, but there is no present correctness or security defect: at guifilemgr.cpp:446 the copy's result is the same under any argument evaluation order and source/destination are distinct arrays, and at :471 the `fmClip` slots are distinct and bounded-filled — only a readability/fragility smell remains. |
| RE-RIPTOPL-090 | `sysDeleteFolder` uses a `malloc` result without a NULL check | S | Low | STANDING | — |
| RE-RIPTOPL-091 | `getFileSize` truncates file sizes to `int` | S | Low | STANDING | — |
| RE-RIPTOPL-092 | ratls parses Content-Length two ways, one of them `atoi`; its body-length global is non-static | S | Low | REVISED | Narrowed scope: Only the Content-Length parsing half holds (dual parsing is real, with a third `atoi` site at ratls.c:157); the `make raTlsBodyLength static` half is refuted — it is a deliberate `extern` in include/ratls.h read by src/ui/selfupdate.cpp to size the download buffer, so making it static would break the link. |
| RE-RIPTOPL-093 | OSDHistory's least-used-slot eviction keeps the evicted slot's old timestamp | S | Low | WITHDRAWN | Defeating evidence: The takeover path resets the timestamp in the very range cited: the shared initialisation block sets `NewEntry->DateStamp = GetTimestamp();` at src/core/OSDHistory.cpp:258 alongside `LaunchCount = 1` at :255, so the new entry does not inherit the evicted slot's timestamp. |
| RE-RIPTOPL-094 | IGR font: 7 punctuation glyphs are copies of the '?' bitmap | S | Low | STANDING | — |
| RE-RIPTOPL-095 | Ten headers have no include guard at all | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-096 | The per-cheat code cap reuses the flattened-list cap, sizing the lazy cheat table at ~1.03 MB; the constants are duplicated in ee_core | S | Med | REVISED | Narrowed scope: Reuse, ~1.03 MB size and ee_core duplication hold, but the stated basis for a smaller per-cheat cap is circular: the parser's own per-cheat bound is the same `MAX_CHEATLIST` constant, so by the finding's derivation rule the cap is 510 — a smaller cap needs the flattened-list justification and a parser-bound change in the same edit. |
| RE-RIPTOPL-097 | BGM keeps a 768 KB static ring buffer resident even though BGM is off by default | S | Low | STANDING | — |
| RE-RIPTOPL-098 | HTTP catalog parsing pre-allocates for the maximum catalog and duplicate-checks in O(n²) | S | Low | STANDING | — |
| RE-RIPTOPL-099 | xhdd: a 407-line Windows IDENTIFY-device struct (and 512-byte static) to read one 16-bit field | S | Low | STANDING | — |
| RE-RIPTOPL-100 | usbd-ra (MINI_DRIVER): isochronous machinery is fully provisioned although no client in the tree can use it | M | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-101 | Both mbedTLS build definitions compile all 109 vendored library sources, including dozens that neither configuration can use | M | Med | STANDING | — |
| RE-RIPTOPL-102 | Whole-file staging for art re-grows its buffer by doubling, re-copying on every cover | M | Med | STANDING | — |
| RE-RIPTOPL-103 | utf8.h defines a 364-entry table and a function body in the header | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-104 | `USBA_crc32` keeps a 4× oversized table and rebuilds it on every call | S | Low | STANDING | Fix-scope extension (Stage B, RiptOPL CAND-11): PC-tool `crctab[0x400]` oversize in iso2opl and opl2iso |
| RE-RIPTOPL-105 | Stack VLAs sized by caller-supplied lengths in keyboard paths | S | Low | STANDING | Fix-scope extension (Stage B, RiptOPL CAND-10): Third keyboard-path VLA, `src/ui/menusys.cpp:306` `char newName[nameLength]` |
| RE-RIPTOPL-106 | `pio_profile` permanently reserves 8 KiB of IOP RAM for a one-shot start-up check | S | Low | STANDING | — |
| RE-RIPTOPL-107 | ship/Example is a 5.9 MB snapshot of which the packager reads only 23 files; its full Neutrino tree is not what ships | M | Med | STANDING | — |
| RE-RIPTOPL-108 | The ds34 pad drivers are maintained twice and have drifted in both directions | L | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-109 | Three MD4s, two DESes and two LM/NTLM hash implementations for one SMB feature set | M | Med | STANDING | — |
| RE-RIPTOPL-110 | The native PS2 launch sequence is re-implemented once per backend | L | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-111 | The PS1 launch (POPSTARTER/VCD and Ember/Cue) is re-implemented once per backend | L | Med | STANDING | — |
| RE-RIPTOPL-112 | Two near-identical iLink driver trees in one repo, already diverged | L | Med | STANDING | — |
| RE-RIPTOPL-113 | `deinit` and `deinitEx` are the same ~90-line teardown written twice | S | Low | STANDING | — |
| RE-RIPTOPL-114 | udpfs editions still carry per-edition copies of headers that the shared core made unnecessary | M | Low | STANDING | — |
| RE-RIPTOPL-115 | Two ministacks, three SMAP drivers, and small helpers copied between the udpfs and udpbd stacks | L | Med | STANDING | — |
| RE-RIPTOPL-116 | Two full ISO9660 directory walkers (plus two copies of the TOC entry struct) in one scope | L | Med | STANDING | — |
| RE-RIPTOPL-117 | mmce_fs remove/mkdir/rmdir are three copies of one function | M | Low | STANDING | — |
| RE-RIPTOPL-118 | Three message/hint wrapping boxes re-implement the same wrap-and-draw | M | Med | REVISED | Narrowed scope: Only two copies match the claimed measure/clamp/draw-rect shape (`diaDrawHint` in dia.cpp and `Notifications::render` in guinotify.cpp); the modal copy measures nothing, clamps no box and draws no rect, sharing only the `fntWrapText` + `lines * MENU_ITEM_HEIGHT` pattern — a full duplicate pair plus a partial third, with the ~60-line saving overstated. |
| RE-RIPTOPL-119 | Three carousel presenters duplicate the framed-cover (overlay) draw block | M | Med | STANDING | — |
| RE-RIPTOPL-120 | Streaming ring-buffer copy logic duplicated almost line-for-line (EE-DMA and IOP-memcpy variants) | M | Med | STANDING | — |
| RE-RIPTOPL-121 | freeze_diag_screen.c re-implements freeze_diag_format.c's formatting helpers | M | Low | STANDING | — |
| RE-RIPTOPL-122 | Five near-identical number-to-string converters in igs_api.c | S | Low | STANDING | — |
| RE-RIPTOPL-123 | The ps2ips 48-byte-tail peek/truncate receive workaround exists in three copies | S | Low | REVISED | Narrowed scope: The three peek/truncate copies are exact, but the prescribed fix breaks non-RA builds: `ranet.cpp` is compiled only in RA editions while `ratls_ps2.cpp` also builds in non-RA builds and `nettime.cpp` builds in every edition — consolidation needs a shared home in an always-compiled source, not a call into ranet. |
| RE-RIPTOPL-124 | The ~66-line platform prologue is copied into four files (and the app splits); the disc-timing constants inside it are dead in sysvmc.cpp | S | Low | STANDING | — |
| RE-RIPTOPL-125 | The 100 µs/1 ms MSG_DONTWAIT poll with a 10 s silence budget is implemented four times | M | Med | REVISED | Narrowed scope: The graduated 100 µs/1 ms poll with the `#399` comment exists in only 3 of the 4 claimed transports (SMB, SMB2, NFS); the HTTP `RecvBounded` copy polls at a flat 1 ms with no `#399` comment and shares only the poll + 10 s budget shape, so a helper extracted from the three would not drop into HTTP unchanged. |
| RE-RIPTOPL-126 | xatad duplicates atad's DMA-mode tables, and the copies have already diverged in reach | M | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-127 | crc32 and the integer typedef block are copied verbatim across the PC tools | M | Low | STANDING | — |
| RE-RIPTOPL-128 | The "NIC is reserved by a UDP transport" predicate exists in three copies | S | Low | REVISED | Narrowed scope: The three predicate copies are exact, but the prescribed fix breaks non-RA builds for the same reason as RE-RIPTOPL-123: ranet is RA-only while `nettime.cpp` builds in every edition and `ratls_ps2.cpp` in non-RA updater editions — consolidation requires moving the predicate to an always-compiled source. |
| RE-RIPTOPL-129 | The read-only-device CFG-folder helper is duplicated in BDM and ETH — and the copies already disagree | S | Low | STANDING | — |
| RE-RIPTOPL-130 | ~37-line include block copy-pasted verbatim into split-out GUI files, most of it unused | S | Low | STANDING | — |
| RE-RIPTOPL-131 | Two near-identical icon+text draw functions in uidraw.cpp | S | Low | STANDING | — |
| RE-RIPTOPL-132 | Drive enumeration duplicated between Drive Status and the File Manager | M | Med | STANDING | — |
| RE-RIPTOPL-133 | FNV-1a implemented twice, in adjacent art files | S | Low | REVISED | Narrowed scope: The FNV-1a core is duplicated, but the artworker version is not the plain special case of the artindex one: `hashName` case-folds `a-z` before hashing and `focusHashValue` does not, so folding them changes focus-change semantics — true scope is one shared FNV core with a case-fold flag. |
| RE-RIPTOPL-134 | Two different parsers for the same SYSTEM.CNF / BOOT2 job | M | Med | STANDING | — |
| RE-RIPTOPL-135 | Four tar finder functions duplicate one search | S | Low | STANDING | — |
| RE-RIPTOPL-136 | `readLeftJoy` writes the same deadzone switch twice | S | Low | STANDING | — |
| RE-RIPTOPL-137 | `sysCheckVMCEx` validates the VMC superblock geometry twice, with different rules | S | Low | REVISED | Narrowed scope: The two geometry blocks are mutually exclusive per call (strict block for size-only callers, lenient block when a superblock is present), not two validation passes over one call; keeping only the `== 512` rule as prescribed would delete the only validation superblock callers get and impose 512 on a path that deliberately accepts other page sizes. |
| RE-RIPTOPL-138 | lwnbdctl writes the same bounded pad-start retry block twice | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-139 | GSM DTV mode constants defined in three places, in three styles | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-140 | COMPAT_MODE_* bits defined at four sites; one redefinition is live today | S | Low | REVISED | Narrowed scope: The four definition sites hold, but the `patches.h` redefinition is a legal identical redefinition, and the prescribed `asm.S` fix is not asm-viable as stated — `ee_core.h` is a C header with externs/enums/prototypes that cannot be included from the assembler TU, so a fix needs an asm-safe shared defines header; deleting the `patches.h` copy remains sound. |
| RE-RIPTOPL-141 | GSMSourceGSRegs layout hand-mirrored in three representations | M | Med | STANDING | — |
| RE-RIPTOPL-142 | Two macro families for the same GS registers in igs_api.h, plus a third copy in igrmenu.c | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-143 | opl.h includes <debug.h> twice and mixes include-path styles | S | Low | STANDING | — |
| RE-RIPTOPL-144 | smb2man and nfsman duplicate the same front-end plumbing | M | Low | STANDING | — |
| RE-RIPTOPL-145 | Two copies of the 8-hex-digit argument parser, and they disagree on lowercase | S | Low | REVISED | Narrowed scope: The parser divergence is real (`mbHex8` lacks `a-f`), but the claimed live consequence has zero current reachability: both in-tree producers format addresses with uppercase-only hex, so no lowercase string can reach igrmbox from this tree — a latent parser inconsistency worth aligning, not a live load failure. |
| RE-RIPTOPL-146 | bd_defrag read and write are the same function written twice | S | Low | STANDING | — |
| RE-RIPTOPL-147 | bdmevent re-derives "unsupported sector size" by hand instead of using BDM's refused state | M | Low | REVISED | Narrowed scope: The cited bdmevent location does not exist (the file is 88 lines; the snapshot is at :12-56), BDM's `refused` flag is private to bdm.c and not exported so the fix needs a new export rather than reuse, and bdmevent's policy deliberately differs from BDM's on `sectorSize == 0` / `parNr` — only a partially-overlapping re-derivation with an intentionally different diagnostic rule remains. |
| RE-RIPTOPL-148 | mcemu carries an orphan, near-duplicate `ioman_add.h` that nothing in mcemu includes | S | Low | STANDING | — |
| RE-RIPTOPL-149 | genvmc: the same `mc_writecluster` error translation is hand-copied at eight sites | S | Low | STANDING | — |
| RE-RIPTOPL-150 | Two hand-rolled malloc/free shims, one per ilink module | M | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-151 | `scsi_read` and `scsi_write` are copy-paste twins | S | Low | STANDING | — |
| RE-RIPTOPL-152 | Two language packers exist: tools/lng_pack.sh is superseded by package_edition.language_pack but still shipped and documented | S | Low | STANDING | — |
| RE-RIPTOPL-153 | The "last 10 commits" release-notes block is implemented three times, with three different escaping rules | M | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-154 | build_edition.py redefines the add() helper it could import from build_configuration.py | S | Low | STANDING | — |
| RE-RIPTOPL-155 | The ps2build-mirror fallback is implemented twice: once in shell, once in Python, over the same pin contract | L | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-156 | `struct hostent` is defined twice because `<netdb.h>` only declares it | S | Low | STANDING | — |
| RE-RIPTOPL-157 | atad PIO transfer returns success without transferring, and its body is unreachable dead code | S | Low | STANDING | — |
| RE-RIPTOPL-158 | The whole APA partition-editing subtree is retained dead code (~700 lines) | M | Med | STANDING | — |
| RE-RIPTOPL-159 | The FULL_LWIP subsystem (~627 gated lines) is dead and cannot link if enabled | M | Low | REVISED | Narrowed scope: The ~627 gated lines, export stubs and the `lwip_select` timeout bug are real, but the headline 'cannot link if enabled' mechanism is defeated: the dhcp calls are double-gated by `#if LWIP_DHCP`, which is 0 unless `PS2IP_DHCP` is defined (nothing defines it), so they compile out in a plain `FULL_LWIP=1` build — true scope is a default-off, stubbed, internally buggy dead subsystem. |
| RE-RIPTOPL-160 | APA password DES (~460 lines) runs in a build where password comparison is compiled out | S | Med | STANDING | — |
| RE-RIPTOPL-161 | `hdd_blkio.c` compiles to an empty object in this build (415 lines of other builds' code) | S | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-162 | audio/bgm.ogg (324,182 bytes) is an orphan: not embedded, not packaged, and not the BGM file the packages actually ship | S | Low | STANDING | — |
| RE-RIPTOPL-163 | mem.c carries a full heap allocator that is dead in every build, plus a callerless `mem_reallocm` | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-164 | iso2opl.c keeps ~90 lines of superseded implementations commented out beside the live ones | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-165 | loopif is a complete dead module: file, header, and gated glue all ship but can never run | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-166 | usbmass_bd: the unselectable ASYNC implementation of `usb_queue_cmd` is carried alongside the live one | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-167 | Feature-off protocol code retained: `ip_forward` and debug-only `ip_lookup` | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-168 | ziso.py carries a Python-3-broken helper and a never-called "future" feature | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-169 | tools/lang_decompiler.py is dead: no caller anywhere, and it duplicates lang_compiler's YAML representer | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-170 | usmb2 entry points that this build never calls, one of them unsafe if ever enabled | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-171 | SMB1 ReadAndX carries a permanently-dead non-custom receive branch | S | Low | STANDING | — |
| RE-RIPTOPL-172 | Header declarations with no definition anywhere in the tree | S | Low | STANDING | — |
| RE-RIPTOPL-173 | `do_accept` is a registered no-op that never ACKs | S | Low | STANDING | — |
| RE-RIPTOPL-174 | The non-core-locking API path in tcpip.c is unreachable and silently drops calls | S | Low | STANDING | — |
| RE-RIPTOPL-175 | Dead code in smap_udpbd's transfer layer: an uncalled copy routine and a never-used event flag | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-176 | raudp leftovers: a write-only diagnostic counter and heartbeat fields kept for a removed feature | S | Low | STANDING | — |
| RE-RIPTOPL-177 | BDM: `g_bd_sectors_per_sector` is written but never read; the sector factor is hardcoded instead | S | Low | STANDING | — |
| RE-RIPTOPL-178 | smb.h declares a function that does not exist and ~150 constants the in-game clients never use | S | Low | STANDING | — |
| RE-RIPTOPL-179 | imgdrv keeps dead code and hand-rolled duplicates of the ioman types it already includes | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-180 | MX4SIO CRC16 support is compiled in but permanently switched off; CRC7 mode selection is broken-but-lucky | S | Low | STANDING | Fix-scope extension (Stage B, RiptOPL CAND-12): Broken `CRC7_MODE_RAM_TABLE` test also in `spi_sdcard_crc7.h` |
| RE-RIPTOPL-181 | Dead field: fatfs mount-info `mount_status` is declared and never used | S | Low | STANDING | — |
| RE-RIPTOPL-182 | ps2atad carries whole subsystems behind macros its Makefile never defines | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-183 | Broken, unused `PACKET_TCODE` macro | S | Low | STANDING | Fix-scope extension (Stage B, RiptOPL CAND-13): Second broken `PACKET_TCODE` copy at bdmassault `iLink_internal.h:92` |
| RE-RIPTOPL-184 | `DeinitIEEE1394` is dead and incomplete | S | Low | STANDING | Fix-scope extension (Stage B, RiptOPL CAND-14): Second dead `DeinitIEEE1394` copy in bdmassault `sbp2_driver.c` |
| RE-RIPTOPL-185 | sio2man_hook carries a permanently disabled mx4sio port-blocking feature | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-186 | pccf ships a formatter that is never included and a diagnostic entry point that is never defined | S | Low | STANDING | — |
| RE-RIPTOPL-187 | Retired ps2sdk fallback trees keep dead source files, and ps2sdk-socket's README describes the retired build as current | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-188 | tools/pc/xeRAbora.url is dead: the packager hardcodes its contents instead of copying the file | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-189 | Dead and no-op code: placeholder flag ORs, commented-out launch/teardown blocks, a commented-out size calculation | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-190 | Retired main-menu slot kept in the menu ID enum | S | Low | STANDING | — |
| RE-RIPTOPL-191 | `vmc_groups.cpp` ships dead data: malformed title IDs that can never match, and duplicated IDs | S | Low | STANDING | — |
| RE-RIPTOPL-192 | `PadManager::initialize` returns 1 on every path, making `startOne`'s failure branch dead; `keyPressed` lacks the bounds guard its siblings have | S | Low | STANDING | — |
| RE-RIPTOPL-193 | `sfxGetDropDiag` is a stub that reports zeros for counters that no longer exist | S | Low | STANDING | — |
| RE-RIPTOPL-194 | httpclient: an empty `HttpStreamEnd` kept "for symmetry", and `HttpSendGetRequest` skips the init guard | S | Low | REVISED | Narrowed scope: The `HttpSendGetRequest` init-guard half holds, but the `HttpStreamEnd` half is narrower and its fix unsafe as worded: the EE stub has zero EE callers, and its name and shared header declaration belong also to a live IOP `HttpStreamEnd` — delete only the EE stub definition, keep the declaration and the IOP teardown. Fix-scope extension (Stage B, RiptOPL CAND-16): Guard gap wider than RE-RIPTOPL-194 states: EE `HttpStreamBegin` and `HttpStreamRead` also lack the init guard |
| RE-RIPTOPL-195 | ioman.h documents a queue-removal function that does not exist | S | Low | STANDING | — |
| RE-RIPTOPL-196 | Remove_Padhook is declared but never defined and never called | S | Low | STANDING | — |
| RE-RIPTOPL-197 | Twelve gfx/ files (29,792 bytes) are never embedded in any flavour: seven device icons the code deliberately dropped, and four byte-identical duplicates whose blobs the code already shares | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-198 | ARP entries never expire: `etharp_tmr` is never scheduled because `LWIP_ARP` is defined nowhere | S | Low | STANDING | — |
| RE-RIPTOPL-199 | EE RPC socket surface is wired end-to-end to an empty stub | M | Med | STANDING | — |
| RE-RIPTOPL-200 | DESR/DVR support is a half-finished subsystem whose own header says it cannot claim to work | M | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-201 | `mmce_fs_ioctl` is registered but returns success for every command | S | Low | STANDING | Fix-scope extension (Stage B, RiptOPL CAND-18): `mmce_fs_ioctl2` returns 0 for every unknown command |
| RE-RIPTOPL-202 | SOCK_RAW is accepted, then silently hollow | S | Low | STANDING | — |
| RE-RIPTOPL-203 | `configRead` walks a five-rung filename fallback chain of accumulated migrations | M | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-204 | Favourites permanently carry a foreign-format import parser for other loaders' `favourites.bin` | M | Med | STANDING | — |
| RE-RIPTOPL-205 | Launch diagnostics are switched off by a hardcoded header constant, not a build option | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-206 | httpclient carries the scaffolding of chunked transfer encoding that was never implemented | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-207 | xhdd: HDPro transfer-mode stub reports success for doing nothing; two header prototypes have no definition | S | Low | STANDING | — |
| RE-RIPTOPL-208 | usbd-ra public header declares two exports that do not exist | S | Low | STANDING | — |
| RE-RIPTOPL-209 | The mmce "set alarms" setting is honoured by only two of the five transfer paths | S | Low | STANDING | — |
| RE-RIPTOPL-210 | PSUManager integration is a claim without a runner: the C++ validator and the vendored tests are never built or run | M | Low | STANDING | — |
| RE-RIPTOPL-211 | `ps2ip_ShutDown` is exported but does nothing | S | Low | STANDING | — |
| RE-RIPTOPL-212 | Neutrino / custom-loader path resolution is a ~630-line probing subsystem for "find one ELF" | L | Med | STANDING | — |
| RE-RIPTOPL-213 | Boot-directory resolution is a 496-line file with two budget ladders and three transport tiers | L | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-214 | A ~360-line asynchronous state machine exists to show a short disc ID in a caption | M | Med | STANDING | — |
| RE-RIPTOPL-215 | MMCE GameID card-switch waiting is six overlapping wait/settle mechanisms | L | Med | STANDING | — |
| RE-RIPTOPL-216 | Multi-view theme fallback *synthesizes* whole theme views by copying config blocks | M | Med | STANDING | — |
| RE-RIPTOPL-217 | Neutrino TOML sync carries two rewriters plus machinery that exists only to repair its own writes | L | Med | STANDING | — |
| RE-RIPTOPL-218 | Settings-home discovery is a second, larger fallback labyrinth — and save-side discovery disagrees with load-side | L | High | STANDING | — |
| RE-RIPTOPL-219 | `configWrite` stacks three separate save-safety mechanisms | M | Med | STANDING | — |
| RE-RIPTOPL-220 | host.cpp builds a four-interface service layer with exactly one implementation of each interface | M | Med | STANDING | — |
| RE-RIPTOPL-221 | Xerabora mode carries a hand-rolled JSON parser and maximum-size buffers for a paged list | M | Med | STANDING | — |
| RE-RIPTOPL-222 | UDPFS art lookup maintains an 8-spelling case-discovery subsystem for one folder name | M | Low | STANDING | — |
| RE-RIPTOPL-223 | Cheat loading stacks four fallback attempts per launch | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-224 | libview: a two-ring, pending/commit state machine to remember which list a page shows | L | Med | STANDING | — |
| RE-RIPTOPL-225 | One-line C forwarding wrappers layered over every C++ class split | L | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-226 | `pcdiag_cf_probe`'s sampling loop produces only traces the production caller throws away | M | Low | STANDING | — |
| RE-RIPTOPL-227 | Grid / PSBBN / Coverflow presenters each re-walk the whole game list per frame and per keypress | M | Med | STANDING | — |
| RE-RIPTOPL-228 | Cheat-config save walks 250 key removals; load silently drops every pick after the first gap | S | Low | REVISED | Narrowed scope: The 250-walk save cost stands, but the claimed round-trip loss does not occur: after removals the save side rewrites picks contiguously from 000, so files this code writes are gap-free — the load drop-after-gap is a latent fragility reachable only via a hand-edited or foreign-written config. |
| RE-RIPTOPL-229 | `fmChildren` re-lists from scratch on every ×4 growth step | M | Low | STANDING | — |
| RE-RIPTOPL-230 | All Games gathering walks every source's full list twice per rebuild | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-231 | cdvdman S-command path busy-spins on hardware registers and retries up to 2500 times | M | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-232 | usbmass_bd SCSI: a failing sector is retried 16 times back-to-back, each retry through full USB reset recovery | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-233 | Block cache keys blocks by unaligned request sector, defeating its own geometry | S | Med | STANDING | — |
| RE-RIPTOPL-234 | smap_udpbd's transmit holds its semaphore across the whole retry sleep loop | S | Med | STANDING | — |
| RE-RIPTOPL-235 | `sysShutdownDev9` retries in a delay-free spin | S | Low | STANDING | — |
| RE-RIPTOPL-236 | Debug art HUD builds a ~35-field formatted string every frame | S | Low | STANDING | — |
| RE-RIPTOPL-237 | Boot-splash glow redraws the logo 13 times per frame | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-238 | Select event machinery runs on every netconn event in builds that have no select | S | Low | REVISED | Narrowed scope: The `select_cb_list` walk is dead in shipped builds (`lwip_select` is `FULL_LWIP`-gated and its export stubbed), but the semaphore/`rcvevent` bookkeeping in the same function is live — `rcvevent` is consumed by the ungated `lwip_recvfrom` non-blocking check — so only the list walk may be gated/deleted; semaphore creation and the event counters must stay. |
| RE-RIPTOPL-239 | 57 second-half test files (12,240 lines) are referenced by no workflow, and three `tests/` suites run only through them / through a runner no workflow invokes | M | Med | WITHDRAWN | Defeating evidence: The 57 files are run in CI: .github/workflows/ps2build.yml:71 runs `tools/run_tests.sh -k`, whose loop at tools/run_tests.sh:5-9 globs every `.github/scripts/test_*.py` — the headline and loop-job fix fall; only the narrow residue survives, that `tests/smb2-live/run.sh` is invoked by no workflow or runner. |
| RE-RIPTOPL-240 | 18 first-half suites assert on source text only and never execute any code; several pin exact whitespace, so they fail on behaviour-preserving edits and pass on behaviour-breaking ones that keep the strings | L | Med | STANDING | — |
| RE-RIPTOPL-241 | Deliberately weakened assertions in the wired host tests: one literally vacuous `CHECK`, one either-way `CHECK`, and a known data defect that is counted but never asserted | S | Low | STANDING | — |
| RE-RIPTOPL-242 | Skip-to-pass: three places convert "cannot run" into a green result | S | Low | STANDING | — |
| RE-RIPTOPL-243 | The extract-a-C-function harness boilerplate is copy-pasted into 52 suites instead of living in one place | L | Med | STANDING | — |
| RE-RIPTOPL-244 | hostmap.py monkeypatches `pathlib.Path.read_text` globally so 11 suites can keep testing a source dialect that no longer exists | M | Med | STANDING | — |
| RE-RIPTOPL-245 | test_ee_hook_context.py verifies EE assembly with a hand-written Python MIPS interpreter instead of executing anything | M | Med | STANDING | — |
| RE-RIPTOPL-246 | Dead pre-C++-conversion layout branches: six suites still select between the old `src/*.c` tree and the current `src/**/*.cpp` tree at runtime | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-247 | `test_config.cpp` pins a lossy libconfig round-trip as correct behaviour, labelled only "characterisation" | S | Low | STANDING | — |
| RE-RIPTOPL-248 | flavours.yml hand-enumerates test files in ~30 steps, duplicating the glob runner; the two lists already disagree | M | Med | STANDING | — |
| RE-RIPTOPL-249 | docs-sync.yml embeds a ~150-line Python program inside YAML, with the same content written twice (Markdown and HTML literals), and no test covers it | M | Med | STANDING | — |
| RE-RIPTOPL-250 | Docs dependency pins exist in three places; two workflows inline them instead of using requirements-docs.txt | S | Low | STANDING | — |
| RE-RIPTOPL-251 | The main CI workflow runs the full host-test suite with no Python dependencies installed; four suites import PyYAML and only pass if the runner image happens to preinstall it | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. Fix-scope extension (Stage B, RiptOPL CAND-21): `test_ra_language_isolation.py`'s PyYAML exposure is live via ps2build/run_tests.sh |
| RE-RIPTOPL-252 | The format gate never checks a single C++ file, and the local and CI format mechanisms disagree about what is excluded | S | Low | STANDING | — |
| RE-RIPTOPL-253 | The top-level Makefile is a dead second build system whose duplicated lists have already drifted from the live one, yet tests and a packaging script still read it as a data source | L | Med | STANDING | — |
| RE-RIPTOPL-254 | BDMA driver identity is a hand-maintained table of exact byte sizes that churns every driver rebuild | M | Low | STANDING | — |
| RE-RIPTOPL-255 | tar.h's header comment claims CFG/CHT kinds are unwired; the code wires them | S | Low | STANDING | Fix-scope extension (Stage B, RiptOPL CAND-19): Same stale tar comment in `src/platform/tar.cpp:9` |
| RE-RIPTOPL-256 | pad.h mixes constexpr and #define for one sequential key enum | S | Low | STANDING | — |
| RE-RIPTOPL-257 | Byte-identical 48,500-byte IRX blob stored twice in bdmassault | S | Low | STANDING | — |
| RE-RIPTOPL-258 | atad ORIGIN.txt states a change the code does not contain | S | Low | STANDING | — |
| RE-RIPTOPL-259 | freepad "vendoring" exists only as a provenance note; the mechanism it describes does not exist | S | Low | STANDING | — |
| RE-RIPTOPL-260 | Translation downloads are unpinned, contradicting the "pinned" claim in tools/assets.py | S | Low | STANDING | — |
| RE-RIPTOPL-261 | tools/assets.py bakes transient agent scratch directories into the release version anchor | S | Low | STANDING | Fix-scope extension (Stage B, RiptOPL CAND-20): RE-RIPTOPL-261's scratch-dir exclusion list duplicated verbatim at `Makefile:111` |
| RE-RIPTOPL-262 | Current user/contributor docs still teach the legacy Makefile build — commands, flags and variant names that no longer exist | M | Low | STANDING | — |
| RE-RIPTOPL-263 | The migration doc's status section and a workflow comment describe flavours/CI that have since landed, as if they were still missing | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-RiptOPL.md` supersede the filed ones. |
| RE-RIPTOPL-264 | The language count is 31 in the README badge and the languages doc; the build builds 33 | S | Low | STANDING | — |
| RE-RIPTOPL-265 | Current reference docs cite source files at their pre-C++ flat paths, which do not exist | S | Low | STANDING | — |

### New findings — RiptOPL (Stage C, from Stage B candidates)

| ID | Title | Status | Note |
|---|---|---|---|
| RE-RIPTOPL-266 | `prepare_path`'s trailing-slash strip is dead code: the loop condition is false on the first test for every input | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-RiptOPL.md`, CAND-06). |
| RE-RIPTOPL-267 | `mmce_cmd_set_gameid` strcpy's a full game ID into a 255-byte stack buffer after u8 length truncation | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-RiptOPL.md`, CAND-08). |
| RE-RIPTOPL-268 | OSDHistory victim scan compares timestamps against a stale candidate (`LeastUsedRecordTimestamp` is not reset) | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-RiptOPL.md`, CAND-09). |

## Launchstation

| ID | Title | Effort | Risk | Status | Note |
|---|---|---|---|---|---|
| RE-LAUNCH-001 | libsmb2 randomness on the IOP is a 15-bit LCG seeded from boot seconds, a constant pid, and a heap pointer | M | Medium | STANDING | — |
| RE-LAUNCH-002 | vmcman overwrites derived geometry with raw superblock bytes; cluster reads then write past 1024-byte cache entries | S | Low | STANDING | — |
| RE-LAUNCH-003 | SMB1 NetShareEnum walks the share list on fully server-controlled offsets, count, and string lengths | S | Low | STANDING | — |
| RE-LAUNCH-004 | Anonymous FTP is the unauthenticated transport for a remote ELF-launch command inbox | M | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-005 | Self-update overwrites the running ELF in place with no recoverable copy — and the CHANGELOG tells users a `.BAK` exists during the swap | M | Medium | STANDING | — |
| RE-LAUNCH-006 | CNF loader copies unbounded file values into fixed SETTING fields with strcpy/sprintf | S | Low | STANDING | — |
| RE-LAUNCH-007 | Config save-text builder can overrun its heap buffer (unbounded sprintf chain measured with %n into a size estimate) | M | Low | WITHDRAWN | Defeating evidence: Allocation is sizeof(SETTING) 28,248 + sizeof(PathPad) 30,750 + 8,192 = 67,190 B while maximum output with every field full-but-valid is ≈61,038 B (slack ≈6,152 B) — the claimed ≈48 KB of path text is already contained inside the allocation, so no independent overrun occurs. |
| RE-LAUNCH-008 | smbd truncates 64-bit SMB file offsets to signed 32-bit before seeking on the card | S | Low | STANDING | — |
| RE-LAUNCH-009 | CI-wired test `test_copy_psu_listing.py` fails deterministically at the pin | M | Low | STANDING | — |
| RE-LAUNCH-010 | The SMB server ships with a published default login, stored in clear text and printed on the status screen | S | Low | STANDING | — |
| RE-LAUNCH-011 | No authentication throttling anywhere in the SMB server, against that same default login | S | Low | STANDING | — |
| RE-LAUNCH-012 | `GET_XPARAM_DB_SIZE()` is identically 1, so the 292-entry game-parameter database is searched over exactly one entry | S | Low | STANDING | — |
| RE-LAUNCH-013 | vmcman's FAT-chain walk indexes the 32-entry ifc_list with an unbounded cluster number | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-014 | hdl_info copies game name/startup with strcpy from disk data and from the EE rename packet | S | Low | STANDING | — |
| RE-LAUNCH-015 | ps2ips_rpc trusts the EE packet's `malign` value in send/sendto; negative lengths pass through recv | S | Low | STANDING | Fix-scope extension (Stage B, Launchstation CAND-05): C-V2-2 — ps2ips send path never validates pkt->length itself (gap in RE-LAUNCH-015's proposed fix) |
| RE-LAUNCH-016 | usbmass_bd uses the device-reported block length for a stack alloca and unchecked transfer lengths | S | Low | STANDING | Fix-scope extension (Stage B, Launchstation CAND-04): C-V2-1 — usbmass_bd warmup divides by zero for sectorSize > 1,000,000 (same ingest value as RE-LAUNCH-016, different, earlier sink) |
| RE-LAUNCH-017 | Unbounded sprintf/strcat path assembly in the copy/delete/MC-read path cluster | S | Low | STANDING | — |
| RE-LAUNCH-018 | scanSystemCnf uses strncat as if it were a bounded copy — duplicate SYSTEM.CNF keys overflow | S | Low | STANDING | — |
| RE-LAUNCH-019 | smbd file handles and auth state survive logoff and tree disconnect; handles bind to the connection, not the session | M | Medium | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-020 | `SMBD_DEVCTL_START` parses the credential blob past its stated length, and reports success for credentials it did not take | S | Low | REVISED | Narrowed scope: Past-length credential parse is real, but the claimed indefinite UI/wire divergence is defeated in-tree (init.c:2809-2810 guards the login update and the status screen shows the running login); true scope is a latent IOP over-read on a malformed blob from a future/non-stock caller plus a documented, EE-compensated no-op on START-while-running. Fix-scope extension (Stage B, Launchstation CAND-06): C-V2-3 — smbd START copies are not guaranteed NUL-terminated |
| RE-LAUNCH-021 | SNTP clock sync uses a predictable transmit timestamp, and the RTC it sets is what TLS certificate validation trusts | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-022 | TLS entropy callback always reports success, including when its only OS source failed and every other input is at its cold-boot value | S | Medium | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-023 | mmceman copies the card-supplied game ID with strcpy into the caller's devctl buffer | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-024 | SMB1 QueryPathInformation dereferences the server's DataOffset without validation | S | Low | STANDING | — |
| RE-LAUNCH-025 | hdl_info sums sub-partition lengths using the disk-controlled `nsub` past the 64-entry array | S | Low | STANDING | — |
| RE-LAUNCH-026 | mmceman set-game-ID narrows the length to u8 and strcpys into a 255-byte stack buffer | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. Fix-scope extension (Stage B, Launchstation CAND-09): CAND-V3-3 — mmce_cmd_set_gameid dereferences a possibly-NULL devctl arg |
| RE-LAUNCH-027 | Classic dialog helpers strcpy unbounded caller text into fixed stack buffers | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-028 | editorSaveAs appends the typed filename with strcpy at the end of a possibly-full path buffer | S | Low | STANDING | — |
| RE-LAUNCH-029 | smbd WRITE accepts lengths above the negotiated maximum the server itself advertised | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-030 | smbd CREATE does not enforce the card's 31-byte leaf limit that RENAME carefully enforces | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-031 | smbd file-id validation uses only 4 of the 16 file-id bytes, and the generation counter wraps at 16 bits | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-032 | smbd server identity is a compile-time constant and session ids restart from a fixed counter on every serve | S | Low | STANDING | — |
| RE-LAUNCH-033 | hdl_info APA chain walk follows disk `next` pointers with only a 10,000-count hack against cycles | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. Fix-scope extension (Stage B, Launchstation CAND-07): CAND-V3-1 — APA chain walk can loop forever, not merely 10,000 times (strengthens RE-LAUNCH-033) |
| RE-LAUNCH-034 | mmceman directory read stores the card-supplied filename without ensuring NUL termination | S | Low | STANDING | — |
| RE-LAUNCH-035 | vmcman VMC-backing slot validation is off by one and admits negative slots (latent) | S | Low | STANDING | — |
| RE-LAUNCH-036 | cloud_http maintains two divergent HTTP response parsers; chunked detection is case-sensitive and Content-Length goes through atoi | M | Low | REVISED | Narrowed scope: Buffered-path parser bugs are all real, but the streaming path is not stricter — it uses the same atoi (:1123) and the identical case-sensitive chunked check (:1139-1141); true scope is the buffered-path bug set plus a two-implementation hazard, with no stricter in-tree pattern to mirror. |
| RE-LAUNCH-037 | Custom OAuth client override contradicts its own "complete pair" rule: an ID alone silently discards the built-in secret | S | Low | STANDING | — |
| RE-LAUNCH-038 | Long-lived credentials are stored in clear text in ordinary config files on removable media | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-039 | smbd SET_INFO classes report success without performing the operation | S | Low | STANDING | — |
| RE-LAUNCH-040 | smbd LOCK succeeds without locking, and CREATE ignores share-access and oplock semantics | S | Medium | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-041 | smbd QUERY_DIRECTORY never validates the information class: unsupported classes return a successful empty listing, and FileId is always zero | S | Low | STANDING | — |
| RE-LAUNCH-042 | Vendored usmb2 contains an unhardened server-length memcpy in readdir, kept out of the IOP build only by a feature define | S | Low | STANDING | — |
| RE-LAUNCH-043 | Classic main-menu loop in main() is unreachable — DashRun never returns | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-044 | Classic config/info/editor screens are shadowed by dashboard interception — a second, parallel settings/UI system is carried but not presented | L | Medium | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-045 | Two test files are orphaned from CI — and architecture-maintenance.md claims every test runs there | S | Low | STANDING | — |
| RE-LAUNCH-046 | All 211 CI tests run as one sequential step: first failure masks the rest | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-047 | Updater menu path in README and both wiki guides points to a page that does not contain it | S | Low | STANDING | — |
| RE-LAUNCH-048 | Automatic IGR sync default stated as Off in two texts; code default is Local backup | S | Low | STANDING | — |
| RE-LAUNCH-049 | CNF rename to LAUNCHSTATION.CNF not propagated through dashboard.md and the LAUNCHELF.CNF template header | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-050 | Hand-rolled JSON string extraction is duplicated, and both copies mishandle escapes | M | Medium | STANDING | — |
| RE-LAUNCH-051 | The same C-function brace-extractor helper is copy-pasted into 103 test files | M | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-052 | Every directory listing allocates ~900 KB of FILEINFO; recursive size/delete allocate another ~900 KB per level | L | Medium | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-053 | Two identical 2049-entry sceMcTblGetDir static buffers are kept in BSS for two readers that never run concurrently | S | Low | STANDING | — |
| RE-LAUNCH-054 | Two animated GIFs duplicate their MP4s at 8–9× the size and dominate the published site and offline ZIP | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. Fix-scope extension (Stage B, Launchstation CAND-14): C3 — RE-LAUNCH-054 scope extension (same mechanism, listed for the fixer's checklist) |
| RE-LAUNCH-055 | 1,639,271 B of generated font C has no source font in the repo and no regeneration/comparison gate | S | Low | STANDING | — |
| RE-LAUNCH-056 | Two MMCEMAN driver sources (581 lines) are compiled by nothing | S | Low | STANDING | Fix-scope extension (Stage B, Launchstation CAND-12): C1 — Orphan export table for the dead driver (companion to RE-LAUNCH-056) |
| RE-LAUNCH-057 | Dead vendored code in the smbd compiled set: two empty-by-#ifdef translation units and two client-only libraries linked into a server IRX | S | Low | STANDING | — |
| RE-LAUNCH-058 | Dead file-based PSU extractors and the "historical" file download entry point have no production callers | S | Low | STANDING | — |
| RE-LAUNCH-059 | Action pinning is inconsistent: the `contents: write` build workflow uses mutable tags, the read-mostly metrics workflow pins SHAs for exactly that reason | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-060 | `scripts/stale_code_audit.sh` cannot find what it claims to scan, and is run by nothing | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-061 | res/README.md resource inventory is wrong on sounds, missing on the PS2 sound set, and lists 2 CA roots for a 3-root bundle | S | Low | STANDING | — |
| RE-LAUNCH-062 | 491,822 B of payload files are referenced by no build, script, test or doc-as-used asset | S | Low | STANDING | — |
| RE-LAUNCH-063 | Shipped LAUNCHELF.CNF template contradicts itself on the Triangle launch key | S | Low | STANDING | — |
| RE-LAUNCH-064 | SMB site page credits libsmb2 as the SMB2 driver; the shipped driver is source-built usmb2 | S | Low | REVISED | Narrowed scope: smb.html:86 is a provenance sentence about upstream work (where libsmb2 genuinely was the driver), and libsmb2 is a shipped driver for the IOP SMB server, not the smb: client; true scope is an ambiguous sentence needing a reword, not the proposed one-word swap. |
| RE-LAUNCH-065 | CHANGELOG Rolling NFS entry gives the pre-split settings location for NFS shares | S | Low | STANDING | — |
| RE-LAUNCH-066 | Documentation-site Ecosystem page is a full revision behind the Ecosystem markdown it mirrors | S | Low | STANDING | — |
| RE-LAUNCH-067 | Plan/follow-up status layer is stale: a merged feature is labelled "not merged", and the newest plans carry no status at all and are absent from the docs index | S | Low | STANDING | — |
| RE-LAUNCH-068 | architecture-maintenance.md's largest-files list is already wrong | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. Fix-scope extension (Stage B, Launchstation CAND-15): V6-C1 (from RE-LAUNCH-068): src/filer.c (2,556 lines) is a second omission from architecture-maintenance.md's largest-files list |
| RE-LAUNCH-069 | BUILDING.md claims to be generated from building.html; no generator exists, and the three build-prerequisite lists disagree | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-070 | dashboard.md calls the embedded interface sounds "Sony ADP samples"; the repo's own provenance statements say the opposite / unrecorded | S | Low | STANDING | Fix-scope extension (Stage B, Launchstation CAND-16): V6-C2 (pair with RE-LAUNCH-070): the "Sony ADP" provenance wording also lives in code at src/embed_blobs.S:81 |
| RE-LAUNCH-071 | __Headers/ ships four APA header sample sets for other applications with a one-line, misspelled README and no usage or provenance note | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-072 | `tests/nfsman_live/` is wired into no workflow and cannot run unattended | S | Low | REVISED | Narrowed scope: Unwired and unreferenced is verified, but 'cannot run unattended' overstates — run.sh's 3-arg mode is fully non-interactive against a pre-existing export; true scope is no unattended self-provisioning path and nothing invokes it. |
| RE-LAUNCH-073 | Two build targets are defined twice: root `ps2.yaml` and per-module `ps2.yaml` files must be kept in sync by hand | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. Fix-scope extension (Stage B, Launchstation CAND-19): CAND-V7-3 — The ps2ips sync assertion that 073 proposes copying does not cover headers/cflags (extends 073) |
| RE-LAUNCH-074 | Dependency version strings are duplicated between build scripts and tests, so a version bump must edit test fixtures | S | Low | STANDING | — |
| RE-LAUNCH-075 | One CI-run test tests a research model that is explicitly not the shipped code | S | Low | STANDING | — |
| RE-LAUNCH-076 | Two suites can report PASS while a named sub-check did not run | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-077 | `test_transition_latency.py` validates an audio asset through a Python reimplementation of a decoder that is not in this repo | S | Low | REVISED | Narrowed scope: All facts are true, but there is no defect, no fix, and risk is self-rated INFERRED; true scope is a caveat about test epistemology, not a countable finding. |
| RE-LAUNCH-078 | First-open retry loop is copy-pasted three times in filer.c, each with its own empty busy-wait | M | Medium | REVISED | Narrowed scope: Three-copy retry duplication is verified, but the fix cannot replace the MX4SIO copy as stated (the helper takes one path; MX4SIO probes four spellings with separate readiness flags); true scope is the ATA copy as only a near-exact replacement. |
| RE-LAUNCH-079 | The sixteen Misc_* launch strings are rebuilt by three separate hand-written sprintf blocks | M | Medium | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. Fix-scope extension (Stage B, Launchstation CAND-18): CAND-V7-2 — The Misc enumeration has at least five hand-written sites, not three (extends 079) |
| RE-LAUNCH-080 | MainExecuteContext is assembled field-by-field three times in main.c | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-081 | IPv4 validation is implemented three times with divergent semantics; the Neutrino copy accepts the leading-zero forms the SMB parser deliberately rejects | M | Low | STANDING | — |
| RE-LAUNCH-082 | BCD and calendar conversions are duplicated inside dash_clock_sync.c, with two different day-count algorithms | S | Low | REVISED | Narrowed scope: BCD pairs are byte-identical duplicates, but the proposed deletion breaks non-Ethernet builds — the SNTP copies live inside #ifdef ETH and the manual copies deliberately sit after #endif; true scope also splits on differing epochs (1970 vs 2000). |
| RE-LAUNCH-083 | The ps2ipc socket ABI block (externs, hostent view, sockaddr view, htons) is copy-pasted between the TLS and SNTP clients | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-084 | The SIO2 hook exists as two near-identical copies (mmceman, mx4sio_bd) already diverged in one behaviour | S | Low | STANDING | — |
| RE-LAUNCH-085 | Text editor result messages are shown with five empty busy-wait spins of 1.5 s each | S | Low | STANDING | — |
| RE-LAUNCH-086 | filer_copy recomputes strlen(out) on every character while counting path depth | S | Low | REVISED | Narrowed scope: The O(n²) strlen loop is real, but 'only such site in the core' is false — src/config_network.c:100 is a second, worse instance (and dash_card_tool.c:2452 a literal third hit); true scope is one of at least two same-mechanism sites. Fix-scope extension (Stage B, Launchstation CAND-20): CAND-V8-1 — Second (worse) strlen-in-loop site, refuting RE-LAUNCH-086's uniqueness claim |
| RE-LAUNCH-087 | SystemCnf_VMODE is parsed, stored and never read — write-only state | S | Low | STANDING | — |
| RE-LAUNCH-088 | WriteFont_C survives as a ~57-line commented-out function inside draw.c | S | Low | STANDING | Fix-scope extension (Stage B, Launchstation CAND-21): CAND-V8-2 — Third commented WriteFont_C artefact not cited by RE-LAUNCH-088 |
| RE-LAUNCH-089 | icon.c stores 2048 bytes as 2055 one-byte-per-line C source | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. |
| RE-LAUNCH-090 | Development scaffolding (autotest script player, theme tour) is compiled into production sources behind ifdefs | S | Low | REVISED | Narrowed scope: Both dev aids are documented intentional tooling (docs/dashboard.md:573-576, docs/themes.md:436); true scope is that the finding's own minimum alternative — recording usage next to the flag — is already satisfied. |
| RE-LAUNCH-091 | Failed smbd thread start leaks the created thread | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Launchstation.md` supersede the filed ones. Fix-scope extension (Stage B, Launchstation CAND-22): CAND-V8-3 — Same overwritten-tid cleanup flaw as RE-LAUNCH-091's defective fix, live in usb_mass |
| RE-LAUNCH-092 | ps2ftpd keeps one static 32 KB transfer buffer for the whole server | S | Low | REVISED | Narrowed scope: All facts are verified, but buffer sharing is safe by the server's single-threaded select() design, and with no defect/trigger/fix by its own admission; true scope is an observation, not a finding. |

### New findings — Launchstation (Stage C, from Stage B candidates)

| ID | Title | Status | Note |
|---|---|---|---|
| RE-LAUNCH-093 | xparam `_start` silently does nothing for `argc == 3` | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-Launchstation.md`, CAND-01). |
| RE-LAUNCH-094 | `ExecuteBrowserFrom` is a public, caller-less entry into the classic FileBrowser | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-Launchstation.md`, CAND-10). |
| RE-LAUNCH-095 | `tests/test_app_packages.py` is invoked twice in one compile.yml run | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-Launchstation.md`, CAND-11). |
| RE-LAUNCH-096 | Two divergent Python ADPCM decoders (float vs fixed-point) are maintained in parallel | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-Launchstation.md`, CAND-17). |

## POPSLoader

| ID | Title | Effort | Risk | Status | Note |
|---|---|---|---|---|---|
| RE-POPS-001 | Partition parsers read a full device sector into a fixed 512-byte scratch buffer | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. Fix-scope extension (Stage B, POPSLoader CAND-02): Via-cache GPT entry read goes out of bounds: entries 4..31 are read past the 1,024-byte allocation because bd_cache.c:86 delivers only 512 B per read |
| RE-POPS-002 | USB descriptor walk trusts `bLength`/`bNumEndpoints` from the device in all four copies | M | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-003 | `pademu.c` SIO2 parsing reads past the transfer with no size floor, and the multitap slot becomes an unchecked array index | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-004 | Block cache hard-codes 512-byte sectors in its block geometry | S | Low | STANDING | — |
| RE-POPS-005 | SCSI capacity is off by one and the device-supplied block length is never validated | S | Low | STANDING | — |
| RE-POPS-006 | GPT header fields are trusted unchecked: entry count, entry size, and a possible divide-by-zero | S | Low | STANDING | Fix-scope extension (Stage B, POPSLoader CAND-01): GPT partition-scan counter `int i` compared against `u32 partition_count` — signed-overflow UB for a crafted count ≥ 2³¹ |
| RE-POPS-007 | USB mass connect walks endpoint descriptors on device-supplied lengths with no NULL or bounds check | S | Low | STANDING | Fix-scope extension (Stage B, POPSLoader CAND-04): `usb_mass_connect` also dereferences `config`/`interface` unchecked (extension of RE-POPS-007's site list) |
| RE-POPS-008 | Static-descriptor search takes its first step on an unchecked descriptor length | S | Low | REVISED | Narrowed scope: In-block misaligned scan returning a bogus descriptor stands, plus a 1-byte edge read at `staticDeviceDescEndPtr - 1`; the claimed read past the end pointer is defeated by the loops' short-circuit bound check (`descBuf < EndPtr && *descBuf`). |
| RE-POPS-009 | BT HCI/L2CAP/HID handlers ignore the received byte count and parse stale buffer bytes | M | Low | STANDING | Fix-scope extension (Stage B, POPSLoader CAND-08): USB `readReport`/`usb_data_cb` ignore the transfer byte count in both USB copies, exactly as RE-POPS-009 documents for BT |
| RE-POPS-010 | DS3 battery byte indexes the 6-entry `power_level[]` unchecked in all four copies | S | Low | STANDING | — |
| RE-POPS-011 | Mount-info lookup accepts the one-past-the-end index (and negative indices) | S | Low | REVISED | Narrowed scope: Latent helper defect only: the guard admits index 10 and negative indices, but FatFs `pdrv` is provably capped at 0–9 in-tree and `fd->unit` reachability depends on external iomanX parsing — no in-tree caller reaches a bad index today. |
| RE-POPS-012 | fs_ioctl2 / fragment-list paths dereference a possibly-NULL mounted block device | S | Low | STANDING | Fix-scope extension (Stage B, POPSLoader CAND-06): `USBMASS_IOCTL_GET_FRAGLIST` never validates `rdata` — NULL pointer + non-zero length = NULL-pointer write in `get_frag_list` (a fourth unchecked site for RE-POPS-012's fix) |
| RE-POPS-013 | Partition read/write pass-through enforces no partition bounds at all | S | Low | STANDING | — |
| RE-POPS-014 | GPT partition size is off by one and an inverted range is accepted | S | Low | STANDING | — |
| RE-POPS-015 | MBR partitions are mounted with no bounds, type, or extended-partition handling | S | Low | STANDING | — |
| RE-POPS-016 | SCSI layer caps every drive at 2 TiB inside an otherwise 64-bit stack | M | Med | STANDING | — |
| RE-POPS-017 | SCSI warmup failure is ignored, sense data is read uninitialised, and TEST UNIT READY can spin forever | M | Low | STANDING | — |
| RE-POPS-018 | Block cache marks a block valid and serves it even when the device read failed | S | Low | STANDING | — |
| RE-POPS-019 | Fragment-list walk can loop forever on a cyclic FAT chain, holding the global FS lock | S | Low | STANDING | Fix-scope extension (Stage B, POPSLoader CAND-07): `get_fat`'s error sentinel 1 is a fixed point of the frag-list loop (strengthens RE-POPS-019's non-termination case) |
| RE-POPS-020 | Isochronous done-queue cleanup clears the wrong LUT slot | S | Low | STANDING | — |
| RE-POPS-021 | Font ids from Lua index the 16-entry fonts[] array with no bounds check in four fntsys entry points | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-022 | Lua handles are raw pointers cast through integers with no validation: NULL/wild dereference and double-free are one bad integer away | M | Low | REVISED | Narrowed scope: Graphics/font handle dereferences, `freeImage` double-free, and Timer's dereference-first magic check stand at filed strength; the ADPCM limb narrows to wild/stale/double-free handles only — handle 0 is NULL-checked in `sound_playadpcm`/`sound_freeadpcm` and is safe. |
| RE-POPS-023 | Both ELF-loading stages copy program segments to header-supplied addresses with no bounds validation | M | Med | STANDING | — |
| RE-POPS-024 | `get_data` copies a caller-supplied `size` out of an 18-byte array, and the pademu copies never bounds-check `port` | S | Low | STANDING | — |
| RE-POPS-025 | Pademu BT copy clears the DS4 LED buffer with the DS3 length and sends 29 uninitialised bytes (fix exists in the standalone copy) | S | Low | STANDING | — |
| RE-POPS-026 | Standalone USB copy lost the DS3 null-report guard the other three copies have | S | Low | STANDING | — |
| RE-POPS-027 | Two Lua bindings trust a caller-supplied length over the actual string: loadImageEmbedded and IOP.loadModuleBuffer | S | Low | STANDING | — |
| RE-POPS-028 | Graphics.threadLoadImage passes a Lua-owned string pointer straight to a worker thread, and its second argument is unreachable | S | Low | STANDING | — |
| RE-POPS-029 | bd_cache_create dereferences unchecked allocations | S | Low | STANDING | — |
| RE-POPS-030 | atlas allocation results are never checked: OOM is a NULL dereference, not a failure return | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. Fix-scope extension (Stage B, POPSLoader CAND-11): `fntNewAtlas` (fntsys.cpp:428-437) + `atlasPlace` NULL-dereference chain — the caller-side half RE-POPS-030's fix omits |
| RE-POPS-031 | fntsys readFile ignores the read() result, so a short read hands FreeType an uninitialised tail | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-032 | graphics loadFont branches on an uninitialised magic value when the file cannot be opened | S | Low | STANDING | — |
| RE-POPS-033 | Pads.getPressure reads an uninitialised padButtonStatus when no pad read succeeds | S | Low | STANDING | — |
| RE-POPS-034 | HDD partition index from Lua is turned into a device-name byte with `'0' + index` and no range check | S | Low | STANDING | — |
| RE-POPS-035 | EE ds34 clients copy the RPC buffer to the caller even when the RPC failed | S | Low | STANDING | Fix-scope extension (Stage B, POPSLoader CAND-10): USB EE `ds34usb_get_bdaddr`'s unconditional copy also fires on outright RPC failure (scoping note inside RE-POPS-035's mechanism) |
| RE-POPS-036 | MBR parser leaks its allocation on the read-failure path | S | Low | REVISED | Narrowed scope: The 512 B leak on MBR's read-failure path is real but masked on whole devices by RE-POPS-018's error-swallowing; it is reachable only on uncached probes / crafted offset-0 partitions, and widens back to filed scope if RE-POPS-018 is fixed first. |
| RE-POPS-037 | FatFs re-entrancy grant ignores its own timeout | S | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-038 | fs_devctl dispatches STOP_UNIT to stop-all and STOP_ALL to stop-one | S | Low | STANDING | — |
| RE-POPS-039 | Callback thread reads the request after freeing it (GP-register build only) | S | Low | STANDING | — |
| RE-POPS-040 | The default shipped POPSTARTER.ELF is the DEBUG profile, not MAIN, and the 1–2 patch bytes that define all five profiles are documented nowhere in the repo | S | Low | REVISED | Narrowed scope: Byte matrix and default≡DEBUG stand, but the patch bytes are documented in `.research/build_site.py` ($410 debug-text, $413 USB-delay, $410–$42F table); true scope is undocumented in shipped/packaging locations, with the default=DEBUG intent recorded nowhere. |
| RE-POPS-041 | 23 of 26 distinct binaries have no in-repo source, and most of them have no hash pin or provenance record either — a silent byte swap would pass CI | M | Low | REVISED | Narrowed scope: 23-of-26 sourceless census and 18/26 with no enforced pin stand; the popsmb SHA-256s are recorded descriptively in a `.research` note and both usbexfat blobs' hashes are on record under their identical twins' names — the surviving gap is enforcement (18/26) and path-level checking of the usbexfat paths. |
| RE-POPS-042 | opencode workflow runs an unpinned third-party action (`@latest`) with an API-key secret in its environment | S | Low | STANDING | — |
| RE-POPS-043 | The "ABC" on-screen keyboard layout can never be selected: the system normalizer silently converts it to QWERTY | S | Low | STANDING | — |
| RE-POPS-044 | Shipped usbhdfsd.irx cannot be accounted for by the tarball, and the tarball's second driver is absent from the shipped set | S | Low | REVISED | Narrowed scope: Embed `usbhdfsd.irx` is MX4SIO v1.2 with no source in the tarball, but "usbd_bd_assault appears in neither shipped binary" holds only for the embed pair — repo-wide it ships as `bin/POPSLDR/usbhdfsd.irx.udpfs`/`.usbexfat`; README pairing is at lines 11–12, not 13–16. |
| RE-POPS-045 | The entire merged-driver tree is a second, hand-maintained copy of every component (ffunicode alone is 79% of the tarball) | M | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-046 | Every rolling and experimental release zip embeds a full copy of the entire tracked tree, including the 21 MB research archive | S | Low | STANDING | — |
| RE-POPS-047 | Whole `modules/pademu/` tree is built by nothing | S | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-048 | 52 of 143 registered Lua bindings have no caller in any Lua that can run | M | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. Fix-scope extension (Stage B, POPSLoader CAND-15): `print_uart` (luasystem.cpp:2660, registered via `lua_register` as a global) has zero Lua callers — a dead registration outside RE-POPS-048's `luaL_Reg` census scope |
| RE-POPS-049 | Two embedded IRX blobs are byte-identical duplicates of the usbexfat blobs, embedded a second time instead of aliased (83,008 B) | S | Low | STANDING | — |
| RE-POPS-050 | The same binaries are tracked two to four times in git under different paths | M | Med | STANDING | — |
| RE-POPS-051 | The generated bin2c blob `src/elf_loader/loader.c` (855,821 bytes) is committed and regenerated on every build | M | Med | STANDING | — |
| RE-POPS-052 | The block cache reserves 128 KiB of IOP RAM per whole device | S | Med | STANDING | — |
| RE-POPS-053 | ds34 drivers exist as two hand-synced copies per transport; fixes land in one copy only | L | Med | STANDING | — |
| RE-POPS-054 | Embedded-asset table stores every asset twice: 100 entries for 49 unique blobs | M | Med | REVISED | Narrowed scope: Duplication is real (100 rows / 49 unique symbols in source text; 98 rows / 48 compiled in this checkout because the `default.png` rows are `#ifdef`'d out), but `embedded_get` does not normalise bare names — the bare rows cannot be deleted until a bare→canonical mapping is added, or bare lookups such as `"USB.png"` will 404. |
| RE-POPS-055 | The entire translation database is inlined in system.lua: 2,276 lines / 172,314 bytes parsed on every boot, including for English users | M | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-056 | Three iop/embed binaries are dead: nothing builds, embeds or loads them | S | Low | STANDING | — |
| RE-POPS-057 | Vendored `iop/ata_bd_fast/` is kept but explicitly unused; the pinned binary wins | S | Low | STANDING | — |
| RE-POPS-058 | The superseded ps2atad stack is still embedded into every ELF, and two IMPORT_BIN2C externs are unused | S | Low | STANDING | — |
| RE-POPS-059 | SMB defaults that no longer exist (port 1111, preset LAN addresses, DHCP-by-default, guest) still presented as current | S | Low | REVISED | Narrowed scope: Present-tense wrong defaults stand at STATE:65, TESTING:131/135, ROLLING:130 and README:178 `(guest)`; STATE:237's DHCP clause and ROLLING:177 are past-tense explanations of older builds — from STATE:237 only its closing "Port default 1111 is deliberate" note stands. |
| RE-POPS-060 | i.Link documented as a stub / not implemented / Ember-only; it is implemented for Ember and POPSTARTER | S | Low | STANDING | Fix-scope extension (Stage B, POPSLoader CAND-21): The "Ember only" claim from RE-POPS-060 survives in two code comments: ui.lua:1067 (the `GILINK = 11` line) and system.lua:9161 (`InitILINKRoot` header) |
| RE-POPS-061 | fs_ioctl2's RENAME command is an admitted TODO stub, and the ops table is padded with dummy slots | M | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-062 | The `__RTL` renderer in fntsys.cpp is a half-finished second implementation that is never compiled and could not compile | S | Low | STANDING | — |
| RE-POPS-063 | GetMassRootByBackendName defeats the BDM cache and re-binds the RPC on every single call | S | Med | REVISED | Narrowed scope: The cache-defeating / RPC re-binding mechanism is verbatim in the C binding, but a repo-wide grep finds no Lua caller at the pin — the cost is latent in a registered-but-uncalled binding, not a live page-entry cost. |
| RE-POPS-064 | Settings screen rebuilds its entire item list — and ~100 fresh closures — on every rendered frame | M | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-065 | A failing sector is retried 16 times end-to-end with no delay, reset, or backoff | S | Low | STANDING | — |
| RE-POPS-066 | USBD always builds its largest pool configuration; the MINI_DRIVER configuration is unreachable | S | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-067 | fs_driver statically reserves 128 FIL and 16 DIR objects regardless of need | S | Med | STANDING | — |
| RE-POPS-068 | HDD.ListPartitions reserves a 512-entry × 33-byte static table (16,896 bytes of BSS) for a transient enumeration | S | Low | STANDING | — |
| RE-POPS-069 | `bdm_query` reports resident success when its only thread failed to start | S | Low | STANDING | — |
| RE-POPS-070 | ART_LOCATION: a removed setting still plumbed through ~10 live sites as inert cargo | M | Low | STANDING | — |
| RE-POPS-071 | The ABNT keyboard layout is a selectable layout whose rows are byte-identical to QWERTY | S | Low | STANDING | Fix-scope extension (Stage B, POPSLoader CAND-17): RE-POPS-071 fix-completeness: ui.lua:2614's fallback `_NormalizeLayout` also accepts `"ABNT"` (and divergently `"ABC"`) — unreachable in shipped load order but absent from 071's removal list |
| RE-POPS-072 | Game-list scene carries two permanently-empty scaffolding tables and an unreachable "Not implemented yet" branch, evaluated every frame | S | Low | STANDING | — |
| RE-POPS-073 | Adaptive BDMA: tester/rolling docs keep the pre-EXP70 USB rule and the old Off default | S | Low | STANDING | — |
| RE-POPS-074 | TESTING.md SMB setup instructs testers to set two Settings rows that no longer exist (Games path, Link mode) | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-075 | Two workflows are single-use artifacts: the official-release workflow is hardcoded to 1.4.4, and the retract workflow can only ever fire on its own edit | M | Med | STANDING | — |
| RE-POPS-076 | The IRX load-and-check helper is duplicated verbatim in main.cpp and luasystem.cpp | S | Low | STANDING | — |
| RE-POPS-077 | PNG and BMP decoders repeat the same row-buffer / CLUT / VRAM-upload blocks three times each | M | Med | REVISED | Narrowed scope: PNG triplication stands (row blocks at calloc lines 172/217/267; CLUT in the 2 palette branches, not 3) plus BMP pixel-conversion-stage triplication; the claimed three separate `loadbmp` VRAM-alloc/upload/free tails is refuted — `loadbmp` (428–849) has one shared VRAM tail. |
| RE-POPS-078 | ResolveAssetPath and ResolveAssetPathTyped duplicate the same candidate-walk | S | Low | STANDING | — |
| RE-POPS-079 | The PLDRGC1 game-list cache format is implemented twice (parser ×2, builder ×2) | M | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-080 | Dead HDD readable-path resolver that is a near-verbatim subset of the live one | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-081 | Three trailing-slash helpers where one mechanism suffices | M | Med | REVISED | Narrowed scope: The three-helper duplication stands, but consolidation onto the NormRaw variant is not provably behavior-identical: ui.lua:10534 passes raw `System.currentDirectory()` and the `gamelocation` sites (1784, 11463) are only isra-normalized, so NormRaw changes results on nil/backslash/duplicate-slash inputs at those sites. |
| RE-POPS-082 | DPRINTF is an unconditional no-op, so all EE diagnostic logging is dead in every build, including DEBUG builds | M | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-083 | Cache eviction is a fixed-point weight/aging scheme where a trivial policy suffices | S | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-084 | Dead C functions and dangling declarations left behind by removed subsystems | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-085 | GetFreeSize / AllocateLargestFreeBlock: a dead chain whose algorithm repeatedly mallocs the largest block in the heap | S | Low | STANDING | — |
| RE-POPS-086 | The async ATA bring-up worker is dead: KickAtaAsyncBoot / WaitAtaAsyncBootBounded have no callers anywhere | M | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-087 | embedded_get's bare-name fallback branch can never execute | S | Low | STANDING | — |
| RE-POPS-088 | images.lua's IMG_FALLBACKS mechanism can never fire | S | Low | STANDING | — |
| RE-POPS-089 | `default.png` is registered in Lua and embedded only conditionally, but the file is not in the repo and the registration is never requested | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-090 | Four defined-but-never-called functions, including one polluting the global namespace | S | Low | STANDING | — |
| RE-POPS-091 | Dead exported surface: unused PLDR/UI members, a load-time probe whose result nobody reads, and a self-described dead flag | S | Low | REVISED | Narrowed scope: Limbs (a), (b), (c) and (e) are dead as filed; limb (d) is refuted — `UI.ResolveSelectedVcdPath` is deliberate test surface consumed by `tools/host_harness.py` T54 (hard-fails at :2334-2335 if missing, called at :2375), so it must be kept or the harness migrated in the same change. |
| RE-POPS-092 | Twenty stale translation entries whose source strings no longer exist in the code | S | Low | STANDING | — |
| RE-POPS-093 | StripVcdExtension is defined independently in both Lua files | S | Low | STANDING | Fix-scope extension (Stage B, POPSLoader CAND-13): A third inline VCD-strip copy exists at system.lua:9585 (`PLDR.HDD.GameEntryDisplayKey`) — extends RE-POPS-093's consolidation |
| RE-POPS-094 | The scene-background image cascade is written out twice inside ui.lua | S | Low | STANDING | — |
| RE-POPS-095 | Three clamp implementations, one of them a same-name shadow inside a single function | S | Low | STANDING | — |
| RE-POPS-096 | Dead helpers and dead macros: `GetExportEntry` and the `hci_event_flag_*` family | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-097 | Dead duplicate files inside __usbd_bd_assault that its Makefile never compiles | S | Low | STANDING | — |
| RE-POPS-098 | A complete second, never-compiled ASYNC implementation of usb_queue_cmd is carried in-line | S | Low | REVISED | Narrowed scope: `ASYNC` is truly never defined, but the genuinely ASYNC-only dead code is ≈48 lines (usb_mass.c:426-442 + 492-522), not ~90; `struct usbmass_cmd` is not ASYNC-exclusive — the live sync path builds CBW/CSW through it (usb_mass.c:447, 459-479), so deleting it would break the live build, and "uncompilable" is unproven. |
| RE-POPS-099 | libbdm ships bd_defrag, which nothing in the package calls | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-100 | ffsystem.c carries dead sample code for four other operating systems | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-101 | Tarball CI builds only the merged drivers and libbdm; the five component modules are never compiled | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-102 | Merged USBD Makefile adds an include directory that does not exist | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-POPSLoader.md` supersede the filed ones. |
| RE-POPS-103 | The build pipeline is triplicated across three workflows; the same gates and the same ~170-line publish script are maintained in three places | M | Med | STANDING | — |
| RE-POPS-104 | The publishing channels run a weaker gate set than CI: docs_verify runs only in compilation.yml, and the experimental channel also skips the PNG decoder harness | S | Low | STANDING | — |
| RE-POPS-105 | test_udpfs_integration.py is named an integration test but is mostly substring-presence assertions on source text | M | Low | STANDING | — |
| RE-POPS-106 | Byte-identical duplicates inside the research archive and the root docs | S | Low | STANDING | — |
| RE-POPS-107 | Release/version headers frozen at 1.1.0 / v1.1.1-dev in five docs | S | Low | REVISED | Narrowed scope: The finding lists six docs, not five, and five of the six are explicitly dated snapshots (ARCHITECTURE/COMPONENTS/CONTRIBUTING "Last updated 2026-07-27"; PRESERVATION dated/re-synced 2026-07-27; DECISIONS:1 disclaims being a current-state snapshot); the genuinely present-tense, tester-harming instance is TESTING.md:3 alone. |
| RE-POPS-108 | "29 keys" settings lists enumerate only 23 keys (RETROGEM_GAMEID and the five EMBER_* keys missing) | S | Low | STANDING | — |
| RE-POPS-109 | "Cover art reads exactly ONE path per device" — UDPFS reads two | S | Low | STANDING | — |
| RE-POPS-110 | CONTRIBUTING.md packaging contract describes the pre-Ember ZIP (wrong top-level layout, phantom BUILD_INFO.txt, no EMBER/, no PSU) | S | Low | STANDING | — |
| RE-POPS-111 | Pervasive stale path:line anchors and line counts in ARCHITECTURE.md / COMPONENTS.md (and one in LAUNCH_ARGUMENTS.md) | L | Low | STANDING | — |
| RE-POPS-112 | COMPONENTS.md on-card payload lists only three of the six BDMA IRX variants | S | Low | STANDING | — |
| RE-POPS-113 | STATE.md still says Slovak is not in the language picker | S | Low | STANDING | — |
| RE-POPS-114 | STATE.md says the dropped Square binding still toggles cover art | S | Low | STANDING | — |
| RE-POPS-115 | STATE.md says carousel devices are "all shown by default"; i.Link ships hidden | S | Low | STANDING | — |

### New findings — POPSLoader (Stage C, from Stage B candidates)

| ID | Title | Status | Note |
|---|---|---|---|
| RE-POPS-116 | `bdm_connect_bd` silently drops a device when all 20 mount slots are full | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-POPSLoader.md`, CAND-03). |
| RE-POPS-117 | `chrg_connect` dereferences `config->bConfigurationValue` unchecked in both BT copies | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-POPSLoader.md`, CAND-09). |
| RE-POPS-118 | Three documents describe `PLDR.GetBootKind` as a consumed public API; it has no consumers | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-POPSLoader.md`, CAND-14). |
| RE-POPS-119 | Stale comment at ui.lua:2050 ("all other scenes use BKG.png") contradicts the cascade directly below it | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-POPSLoader.md`, CAND-16). |
| RE-POPS-120 | COMPONENTS.md:400-405 presents three dead binaries as live and misstates the mx4sio_bd pin source | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-POPSLoader.md`, CAND-19). |

## SMS (Simple-Media-System)

| ID | Title | Effort | Risk | Status | Note |
|---|---|---|---|---|---|
| RE-SMS-001 | Unknown extension makes the container probe chain call `s_CCreator[-1]` | S | Low | WITHDRAWN | Defeating evidence: The guard at `src/SMS_Container.c:152-153` compares `int lID` against `sizeof(s_CCreator)/sizeof(s_CCreator[0])`, a `size_t` — −1 converts to unsigned 4294967295, `4294967295 < 13` is false, so the branch is never taken for unknown extensions, `s_CCreator[-1]` is never indexed, and execution falls to the default-order `else memcpy` (proven with a compiled test of the identical expression shape). |
| RE-SMS-002 | MPEG-4 sprite trajectory: bitstream warp-point count overflows a 4-entry stack array | Trivial | Negligible | STANDING | — |
| RE-SMS-003 | ip_reass uses the byte-swapped total length to allocate and copy the reassembled packet | Small | Low | STANDING | — |
| RE-SMS-004 | FAT long-filename sequence number trusted into a 128-byte name buffer (SMSUMS) | Small | Low | STANDING | Fix-scope extension (Stage B, SMS CAND-04): FAT LFN negative offset |
| RE-SMS-005 | DTS: stream-controlled `prim_channels` (up to 8) overflows state and stack arrays sized for 5 | Trivial | None identified for valid streams | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-006 | `SMS_LZMA2Decompress` decompresses into the buffer it just freed (NULL) on size mismatch | Trivial | Low | STANDING | — |
| RE-SMS-007 | `SifExecDecompModuleBuffer` executes the output buffer on *any* XZ decode error | Trivial | Low | STANDING | — |
| RE-SMS-008 | ISO9660 filename length trusted past a 129-byte TOC buffer (SMSCDVD) | Small | Low | STANDING | — |
| RE-SMS-009 | get_socket() indexes the fixed socket table with no bounds check | Trivial | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-010 | DTS: header fields and a cumulative sum index fixed tables with no range checks (downmix / bitalloc / LFE / scale factors) | Small | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. Fix-scope extension (Stage B, SMS CAND-01): DTS downmix row-index overflow |
| RE-SMS-011 | DTS SPDIF passthrough: header frame size can make `memset` length negative (huge) and overrun the output buffer | Trivial | None for valid streams | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-012 | DXSB subtitle decoder trusts header dimensions against a fixed scratchpad row buffer; packet size never checked | Small | Low | STANDING | — |
| RE-SMS-013 | Stream/codec/user-data allocations are dereferenced without a NULL check in nine container creators | M | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-014 | Raw config blob is trusted as array indices with almost no validation | Small | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-015 | `sprintf` into the 64-byte `g_SaveDiag` with a 128-byte path overflows it | Small | Low | STANDING | — |
| RE-SMS-016 | ip_reass trusts IPH_LEN over the actual pbuf chain, and its bitmap index goes one byte out of bounds at exactly 5760 bytes | Small | Low | STANDING | — |
| RE-SMS-017 | UDF descriptor lengths trusted: allocation-descriptor offset and name decode unbounded (SMSCDVD) | Small | Low | REVISED | Narrowed scope: Allocation-descriptor OOB read is real, but `apData` points into the 18,576-byte `s_Buffer[9*2064]`, not a 2,048-byte buffer, and the claimed `UDFDecode` write overflow is unreachable at both call sites (constant 128 exact-fit at :138; u8 `lLFI` ≤255 into `s_ScanTemp[2048]` at :399) — true scope is that OOB read plus a latent decode contract and an OOB source read via `38 + lLIU`. Fix-scope extension (Stage B, SMS CAND-02): UDFDecode read-side defects |
| RE-SMS-018 | Path component copied unbounded into a 257-byte stack buffer (SMSUMS) | Small | Low | STANDING | — |
| RE-SMS-019 | `UmsWarmUp` loops over a device-supplied LUN count past a 16-entry name table (SMSUMS) | Small | Low | STANDING | — |
| RE-SMS-020 | USB device geometry (sector size / LBA) trusted unchecked, including divide-by-zero (SMSUMS) | Small | Low | STANDING | — |
| RE-SMS-021 | `TranslateUTF8` can write `bufSize + 1` bytes into the caller's buffer | Trivial | Low | STANDING | — |
| RE-SMS-022 | AAC: sample-rate index from ADTS/ASC (up to 15) indexes 12-entry window tables unchecked | Trivial | None | REVISED | Narrowed scope: ADTS (and ADIF) path fully exposed, but the ASC main index is rejected (`AudioSpecificConfig2` returns −2 when `get_sample_rate()==0`, checked by `_NeAACDecInit2`); ASC exposure survives only via the unvalidated SBR-extension sub-index (12–15) copied to `hDecoder->sf_index`. |
| RE-SMS-023 | AAC: DRC `excluded_channels` loop writes past fixed 64-entry masks, driven by stream bits | Trivial | None | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-024 | WMA: version-1 exponent bands can contain zero-width entries, and `decode_exp_vlc` underflows on a zero entry into a runaway write | Small | Low | STANDING | — |
| RE-SMS-025 | getsockopt/setsockopt read and write TCP PCB fields on UDP sockets and on NULL PCBs | Small | Low | REVISED | Narrowed scope: Headline UDP cross-struct corruption is refuted — `so_options`/`tos`/`ttl` sit in the common `IP_PCB` prefix at identical offsets in both PCB types and TCP-only fields are unreachable for UDP; surviving scope is only a NULL-PCB dereference after `err_tcp` at SOL_SOCKET/IPPROTO_IP level. |
| RE-SMS-026 | accept_function() registers callbacks on the new PCB before allocating the netconn's mbox/sem, then frees the netconn on failure, leaving the PCB pointing at freed memory | Small | Low | STANDING | — |
| RE-SMS-027 | tcp_process() SYN_SENT branch dereferences pcb->unacked without a NULL check | Trivial | Low | STANDING | — |
| RE-SMS-028 | ASF packet sync divides by a file-controlled `packet_size` that is never validated non-zero | S | Low | STANDING | — |
| RE-SMS-029 | AVI ODML super-index loading recurses on file-controlled offsets with no depth bound | S | Low | STANDING | — |
| RE-SMS-030 | AAC: codebook-11 escape values can index the 8,192-entry inverse-quant table out of bounds in the `vquant` asm | Small | Low | STANDING | — |
| RE-SMS-031 | AAC: the constant 16428320 (0xFAAD20) is wired into the decode path — one reachable sample overwrite, two dead remnants | Trivial | None | STANDING | — |
| RE-SMS-032 | AC3/DTS: two-entry float-to-int function-pointer table indexed by an unvalidated channel count in both decoders | Trivial | None for any stream the player can currently play | STANDING | — |
| RE-SMS-033 | MP123: granule gain pointer + scalefactor index can walk past the 378-entry `s_GainPow2` table | Small | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-034 | MPEG picture allocation path assumes success: unchecked callocs and a nullable picture lookup dereferenced unconditionally | Small | Low | STANDING | — |
| RE-SMS-035 | VLC/RL table construction and the DivX bitstream stash use allocation results without NULL checks | Small | Low | STANDING | — |
| RE-SMS-036 | List allocation contract is inconsistent: `Push`/`PushBackBuf` unchecked, 18 call sites dereference the result | Medium | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-037 | History load: unbounded, unchecked, and triplicated record loop | Medium | Medium | STANDING | — |
| RE-SMS-038 | Subtitle loaders: unchecked node allocation and unbounded node count from the subtitle file | Small–Medium | Low | STANDING | — |
| RE-SMS-039 | Object constructors and menu builders dereference `calloc`/`malloc` results without a check | Medium | Low–Medium | STANDING | — |
| RE-SMS-040 | Directory-tree scan/walk/destroy recurse to filesystem depth, and tree init is unchecked | Medium | Medium | STANDING | — |
| RE-SMS-041 | lwip_close() writes errno through a NULL socket pointer on any bad descriptor | Trivial | Low | STANDING | — |
| RE-SMS-042 | do_bind() uses udp_new()/tcp_new() results without the NULL check its sibling functions have | Trivial | Low | STANDING | — |
| RE-SMS-043 | icmp_dest_unreach() dereferences its pbuf_alloc() result unchecked and over-reads the offending packet | Trivial | Low | STANDING | — |
| RE-SMS-044 | ip_frag() dereferences both of its pbuf_alloc() results unchecked | Trivial | Low | STANDING | — |
| RE-SMS-045 | lwip_accept() dereferences the accepted conn, addr and addrlen without NULL checks | Small | Low | STANDING | — |
| RE-SMS-046 | netconn_recv() dereferences the PCB and the received buffer without the NULL checks its own TCP branch demonstrates | Trivial | Low | REVISED | Narrowed scope: A sequential post-reset TCP recv returns at the `conn->err` check first, so the :403 deref needs a narrow cross-thread race (recv passes the check, then `err_tcp` NULLs `pcb.tcp` before :403); the UDP NULL-buf half has no in-tree poster — true scope is the one racy TCP guard. |
| RE-SMS-047 | lwip_recvfrom() dereferences netbuf_fromaddr() which is NULL for every TCP buffer | Trivial | Low | STANDING | — |
| RE-SMS-048 | netbuf_ref() dereferences its pbuf_alloc() result unchecked | Trivial | Low | STANDING | — |
| RE-SMS-049 | pbuf_header() can underflow len/tot_len, and its main wire-facing caller strips 14 bytes without any length check | Small | Low | STANDING | Fix-scope extension (Stage B, SMS CAND-08): pbuf_header REF/ROM mirror underflow |
| RE-SMS-050 | UDPFS `_request` callers never check the reply actually arrived in full (SMSUdpfs) | Small | Low | STANDING | — |
| RE-SMS-051 | smbman-sms: two query replies parsed with none of the validation its sibling functions apply | Small | Low | STANDING | — |
| RE-SMS-052 | smbman-sms `smb_Echo` copies an EE-supplied length into the SMB buffer unchecked | Small | Low | STANDING | — |
| RE-SMS-053 | `lzma2_get_uncompressed_size` walks the XZ index with no bounds at all | Small | Low | STANDING | Fix-scope extension (Stage B, SMS CAND-09): lzma2_decode_size counter type mismatch |
| RE-SMS-054 | Unbounded whole-file loads sized by the file itself (language, font, asset copy, IRX module) | Medium | Medium for `_copy_file_to_mc`; Low for the caps | STANDING | — |
| RE-SMS-055 | `SMSContainer_DefReadPacket` dereferences a possibly-NULL packet, computes a clamp it never uses, and unallocates from stream 0 regardless of index | S | Low | STANDING | — |
| RE-SMS-056 | ASF fragment reassembly assigns `realloc`'s result and the new capacity before checking either | S | Low | STANDING | — |
| RE-SMS-057 | `SMSContainer_SetName` scans backwards for a path separator with no lower bound | S | Low | STANDING | — |
| RE-SMS-058 | MOV `mdhd` handler dereferences the stream that the M4A `hdlr` handler may already have freed | S | Low | STANDING | — |
| RE-SMS-059 | FLAC: fixed-predictor subframe reads up to 4 samples *before* the channel buffer for predictor orders 0–3 | Trivial | None | STANDING | — |
| RE-SMS-060 | WMA: superframe loop trusts container `block_align` (0 → hang; partial final frame → over-read) | Small | Low | REVISED | Narrowed scope: Partial-final-frame over-read and zero-`block_align` non-advance are verified as loop properties, but the claimed hang additionally requires `wma_decode_frame` to keep succeeding on a zero-length bit context — if it errors first, the function returns. |
| RE-SMS-061 | AC3: `_ac3_bit_allocate` can index `s_LATab` one past its 256 entries | Trivial | None | REVISED | Narrowed scope: The filed −512 / index-256 mechanism is disproven for parsed data — exponent deltas are bounded to ±2, capping the index at ≤255; residual scope is only a latent one-element over-read contingent on unproven `EXP_REUSE` stale-boundary data. |
| RE-SMS-062 | CDDA `_read_string` does `strlen` on an unterminated stack buffer filled from disc data | Small | Low | STANDING | — |
| RE-SMS-063 | Fixed-buffer `strcpy` of paths and names that other code allows to be longer | Small | Low | STANDING | — |
| RE-SMS-064 | IOP init failures masked by unconditional success returns (family, all modules) | Medium | Low | STANDING | — |
| RE-SMS-065 | mem_free() never checks the block was actually in use, so a double free silently corrupts the heap free-list | Trivial | Low | STANDING | — |
| RE-SMS-066 | ps2ip_getconfig() strcpy()s an unbounded name into a 4-byte field; netif_find() reads name[2] on any string | Trivial | Low | STANDING | — |
| RE-SMS-067 | err_tcp() is the only PCB callback that dereferences its netconn argument unchecked | Trivial | Low | STANDING | — |
| RE-SMS-068 | ip_output_if() keeps its working IP-header pointer in a function-static variable shared by all callers | Trivial | Low | STANDING | — |
| RE-SMS-069 | `SMS_Realloc` publishes the new size even when `realloc` fails; AVI index loaders write through the result unchecked | Small | Low | STANDING | — |
| RE-SMS-070 | SMSMAP TX gather bounded by the FIFO budget, not by the gather buffer (INFERRED) | Trivial | Low | REVISED | Narrowed scope: The bound mismatch is real in code (1520-byte gather buffer vs 4096-byte FIFO budget), but no in-tree path hands `SMap_Send` a chain over 1520 bytes (MTU/fragmentation caps frames at 1514) — a latent wrong constant, incidentally safe today. |
| RE-SMS-071 | SMSDev9 exported callback registration indexes fixed arrays unchecked (INFERRED) | Trivial | Low | REVISED | Narrowed scope: The unchecked exported callback arrays are real, but every in-tree caller passes constants (interrupts 2–6, DMA channel 1) — true scope is export-surface hardening with no demonstrated in-tree reachability. |
| RE-SMS-072 | do_connect() discards tcp_connect()/udp_connect() results; a synchronous TCP failure is never posted back, so netconn_connect() blocks | Small | Low | STANDING | — |
| RE-SMS-073 | Client netconns never get a semaphore, but netconn_write() waits on it | Small | Medium | STANDING | — |
| RE-SMS-074 | err_to_errno() maps every non-zero lwIP error to EIO | Trivial | Low | STANDING | — |
| RE-SMS-075 | tcpip_apimsg() silently frees a dropped API message; every netconn caller then blocks forever on a reply that will never come | Small | Medium | STANDING | — |
| RE-SMS-076 | lwip_sendto() discards both re-connect results and dereferences `to` unchecked | Small | Low | STANDING | — |
| RE-SMS-077 | lwip_getpeername()/lwip_getsockname() discard the peer/addr result; netconn_addr() itself has no NULL-PCB check | Trivial | Low | STANDING | — |
| RE-SMS-078 | TCP initial sequence numbers are predictable: a counter starting at 6510 advanced only by the 500 ms tick count | Small | Low | STANDING | — |
| RE-SMS-079 | tcp_keepalive() never sets the TCP flags byte; probes go out with whatever flags the recycled heap buffer last held | Trivial | Low | STANDING | — |
| RE-SMS-080 | udp_send() leaks the chained header pbuf on the no-route return | Trivial | Low | STANDING | — |
| RE-SMS-081 | netconn_new_with_proto_and_callback()'s error path leaks the mbox it created and the PCB do_newconn created | Small | Low | REVISED | Narrowed scope: The mbox leak on two error paths is verified, but the orphaned-PCB half is defeated — `do_newconn` sets `conn->err` only where `udp_new()`/`tcp_new()` returned NULL, so no registered PCB is orphaned; the fix scopes to `sys_mbox_free(conn->mbox)` only. |
| RE-SMS-082 | Packet-duration and FLAC-duration math divide by file-controlled values that can be zero | S | Low | STANDING | — |
| RE-SMS-083 | A Vorbis file with ≥3 channels returns −1 from the OGG creator and aborts the entire probe chain | S | Low | STANDING | — |
| RE-SMS-084 | DTS: mono float-to-int converter is an empty stub — mono DTS "decodes" to stale buffer contents | Small | Low | STANDING | — |
| RE-SMS-085 | WMA: `wma_init` divides by the container-supplied sample rate without a zero check | Trivial | None | STANDING | — |
| RE-SMS-086 | AC3/DTS: `Decode` writes uninitialized `lBitRate`/`lSampleRate` locals to the codec context when sync fails | Trivial | None | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-087 | AAC: multichannel frames are mixed through `pcm_synN` with phantom copies of channel 0 for 3–4 channel content | Small | Low | STANDING | — |
| RE-SMS-088 | DivX packed-B start-code scan never advances through the buffer | Trivial | Negligible | STANDING | — |
| RE-SMS-089 | DXSB frames are emitted with `m_EndPTS` never initialized | Trivial | Negligible | STANDING | — |
| RE-SMS-090 | DSP MDCT init: unchecked table allocation and a dead error test | Small | Low | STANDING | — |
| RE-SMS-091 | `MC_SeekS` can return an uninitialised value | Trivial | None | STANDING | — |
| RE-SMS-092 | `SMS_SubContID` can never return FLAC: it compares the wrong suffix | Trivial | Low | STANDING | — |
| RE-SMS-093 | `FindPath` computes a subdirectory's sector count from the root directory's size (SMSCDVD) | Trivial | Low | STANDING | — |
| RE-SMS-094 | UDPFS SMAP PHY-reset retry bound fires on the first poll (INFERRED) | Trivial | Low | STANDING | — |
| RE-SMS-095 | `g_ASCII` is declared 4,572 in its consumer and defined 5,416 in its data file | Small | Low | STANDING | — |
| RE-SMS-096 | `UnicodeToCP`'s binary search can never reach table index 0 (proven by simulation) | Trivial | Low | STANDING | — |
| RE-SMS-097 | Icon loader hand-declares `lzma2_uncompress` with the wrong type and ignores its result | Trivial | Low | STANDING | — |
| RE-SMS-098 | Give `libds34bt.h` / `libds34usb.h` include guards and `(void)` prototypes | Trivial | Very low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-099 | Shared bit reader (`SMS_Bitio.h`) has no end-of-buffer check in any reader — the root mechanism under most stream-side over-reads | None | None | STANDING | — |
| RE-SMS-100 | FLAC: decoder trusts the channel count beyond its 2-entry synth table and a shift-divide (currently saved only by the container's gate) | Trivial | None for any file the current container accepts | REVISED | Narrowed scope: The synth-table index is latent only — the shipped container gate (<3 channels) and `_decode_frame`'s assignment-mismatch check limit it to 0 or 1, and the claimed divide-by-zero is unreachable outright (channels are a 3-bit field, max 8, so `4096 >> nChannels` is ≥16, never 0). |
| RE-SMS-101 | `SMS_GetContainer`'s explicit-format path indexes the creator table with an unchecked caller value | S | Low | STANDING | — |
| RE-SMS-102 | The whole legacy SMSSMB tree is dead and internally duplicated — delete it | Small | Low | STANDING | — |
| RE-SMS-103 | Delete the dead generated header `include/s_iop_image.h` (3,820 lines, ~373 KB) | Trivial | Very low | STANDING | — |
| RE-SMS-104 | Move non-site binaries out of the GitHub Pages tree (`docs/downloads/`, `docs/investigations/` ≈ 11.9 MB) | Medium | Medium | STANDING | — |
| RE-SMS-105 | AC3: `s_Samples` workspace is 192 KB of BSS; the highest offset ever used is ~3,072 floats (~12 KB) | Trivial | Low | STANDING | — |
| RE-SMS-106 | Default (BDM) build carries 23,488 bytes of `g_DataBuffer` segments nothing can reach | Medium | Medium | STANDING | — |
| RE-SMS-107 | Remove ten defined-but-never-called EE functions (≈200 lines, incl. a 105-line IPU routine) | Small | Low | STANDING | — |
| RE-SMS-108 | Delete the thirteen never-called DS34 RPC client stubs | Small | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-109 | Delete the unreferenced `utils/` directory (prebuilt Win32 exe + orphan Loader) | Trivial | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-110 | Remove the orphan blob `irx/bdmfs_vfat.irx.xz` | Trivial | Very low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. Fix-scope extension (Stage B, SMS CAND-13): Second orphan IRX pair of the RE-SMS-110 class |
| RE-SMS-111 | `images/` contains an editor backup and two large source PNGs nothing references | Trivial | Low | STANDING | — |
| RE-SMS-112 | Turkish font pack ships the same font twice under two names | Trivial | Low | STANDING | — |
| RE-SMS-113 | Dead code shipped in the SMSTCPIP module: an uncompiled loopif, two debug-only lookup functions that always return 1, a compiled-out input queue, and compiled-out forwarding | Small | Low | STANDING | — |
| RE-SMS-114 | SO_REUSE port-sharing machinery is compiled in for a single-application media client that never shares ports | Medium | Medium | REVISED | Narrowed scope: The compiled-in, unused SO_REUSE machinery premise holds, but the filed fix (set `SO_REUSE` to 0) deletes nothing because every guard is `#ifdef`/`#ifndef` — removal requires leaving the macro undefined/`#undef`'d or converting the guards to `#if`. |
| RE-SMS-115 | memp reserves a RAW-PCB pool for a protocol that has no implementation file | Trivial | Low | STANDING | — |
| RE-SMS-116 | Half-finished API surface: six api.h functions have no implementation, and the exported shutdown entry point is an empty stub | Trivial | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-117 | Remove six declaration-only prototypes with no definition anywhere | Trivial | Very low | STANDING | — |
| RE-SMS-118 | Dead H.263 inter-unquantize path: empty function, `#if 0` body that cannot compile, wired but never called | Small | Low | STANDING | — |
| RE-SMS-119 | ASF stream-bitrate table is parsed into one array and applied from a different, never-written one | S | Low | STANDING | — |
| RE-SMS-120 | ASF index support is scaffolding for a feature that was never built | S | Low | STANDING | — |
| RE-SMS-121 | Write-only state: fields and struct members that are stored and never read | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-122 | DTS: file-scope sample-rate/bit-rate tables are dead duplicates of the live copies inside `_dts_syncinfo` | Trivial | None | STANDING | — |
| RE-SMS-123 | AC3 IMDCT: `aBias` parameter of `_ac3_imdct_512`/`_ac3_imdct_256` is threaded through every call but never used | Trivial | None | STANDING | — |
| RE-SMS-124 | AC3: `s_SAB` is declared `[20]` with only 8 entries initialized; its sole consumer reads 2 of them | Trivial | None | STANDING | — |
| RE-SMS-125 | `lzma2.c` exports dead, collision-prone functions named `encode` and `decode` | Trivial | None found | STANDING | — |
| RE-SMS-126 | Generated icon header (and its generator) still say "11 dev" — there are 13 dev slots | Trivial | None | STANDING | — |
| RE-SMS-127 | `src/SMS_Menu.c` is a dead duplicate stub that is not in the build | Trivial | None | STANDING | — |
| RE-SMS-128 | USBD exports three stubs that report success (USBD) | Trivial | Low | STANDING | — |
| RE-SMS-129 | File mapping is half-finished: every map returns the same fixed virtual address | Small | Medium | STANDING | — |
| RE-SMS-130 | `FATFS_Init` leaks its filesystem allocation on two early returns (SMSUMS) | Trivial | Low | STANDING | — |
| RE-SMS-131 | MOV carries two-to-three parallel copies of the `hdlr`/`stsd`/`esds` parsers that have already drifted apart | L | Med | REVISED | Narrowed scope: Duplication and drift are real, but one filed drift example is false (the probe `stsd` also walks child atoms), two ranges are inflated (demuxer `stsd` :322-382, `esds` :429-469), and the ~100-line saving is an upper bound. |
| RE-SMS-132 | Whole-file asset loading is triplicated (skin) and triplicated again (language) | Medium | Medium | STANDING | — |
| RE-SMS-133 | The PCB-creation switch is triplicated across do_newconn/do_bind/do_connect — and the copies have already diverged | Small | Low | STANDING | — |
| RE-SMS-134 | Fold the eleven one-declaration `SMS_Container*.h` stub headers into `SMS_Container.h` | Medium | Low-medium | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-135 | MOV/M4A creators select their parser by mutating a shared global parse table at runtime | M | Low | STANDING | — |
| RE-SMS-136 | Fold the redundant explicit object rules in the root Makefile | Trivial | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-137 | `dev9.h` duplicated verbatim in two IOP trees | Trivial | Low | STANDING | — |
| RE-SMS-138 | Deduplicate `AGENTS.md` / `CLAUDE.md` (byte-identical files) | Trivial | Very low | STANDING | — |
| RE-SMS-139 | IPU suspend/resume duplicated verbatim as "dummy" variants | Trivial | Negligible | STANDING | — |
| RE-SMS-140 | MOV index builder resets every stream's chunk cursor per chunk, making derived chunk sizing quadratic | S | Med | REVISED | Narrowed scope: The quadratic per-chunk cursor reset is real, but the filed pure-deletion fix is unsafe — the reset is what guarantees all cursors are 0 between per-stream `_mov_build_index` calls; the remedy is moving the reset to per-build, with offset-ordered chunk tables as a stated precondition. Fix-scope extension (Stage B, SMS CAND-16): MOV cursor cross-call invariant |
| RE-SMS-141 | `smb_GetShareList` spends one full NetShareEnum RPC per share (smbman-sms) | Medium | Medium | STANDING | — |
| RE-SMS-142 | Replace the hand-maintained 64-line host-test list in CI with discovery | Small | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |
| RE-SMS-143 | Drop stale `src/lzma2` references from `.gitignore` and the Makefile link path | Trivial | Very low | STANDING | — |
| RE-SMS-144 | Gate `test-media.yml` regeneration on media-relevant paths | Trivial | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-SMS.md` supersede the filed ones. |

### New findings — SMS (Simple-Media-System) (Stage C, from Stage B candidates)

| ID | Title | Status | Note |
|---|---|---|---|
| RE-SMS-145 | WMA v1 exponent rows 1+ are never filled: the band computation always writes row 0 | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-SMS.md`, CAND-03). |
| RE-SMS-146 | CDDA empty field leaves a node's `m_pName` as uninitialised malloc memory | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-SMS.md`, CAND-07). |
| RE-SMS-147 | `lwip_getpeername`/`lwip_getsockname` dereference `*namelen` with no NULL check | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-SMS.md`, CAND-10). |
| RE-SMS-148 | `netconn_addr` has no default case: returns ERR_OK with `*addr`/`*port` unset for non-UDP/TCP types | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-SMS.md`, CAND-11). |
| RE-SMS-149 | Packed SMSSMB.IRX segment (~19.6 KB) is dead bytes in `g_DataBuffer` in every build | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-SMS.md`, CAND-12). |
| RE-SMS-150 | Explicit-format path in `SMS_GetContainer` discards the creator's return value, so error teardown can never fire | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-SMS.md`, CAND-14). |

## PS2-Servers

| ID | Title | Effort | Risk | Status | Note |
|---|---|---|---|---|---|
| RE-SERV-001 | Pre-authentication commands stay live after authentication and rewrite the session's security state (signing downgrade + negotiate-claims overwrite) | M | Med | STANDING | — |
| RE-SERV-002 | CREATE, SET_INFO and CLOSE perform create / truncate / rename / delete without checking the handle's granted DesiredAccess | S | Low | STANDING | — |
| RE-SERV-003 | READ is never gated on DesiredAccess; there is no read-access concept at all | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-004 | SET_INFO FileBasicInformation returns SUCCESS while doing nothing — and validates nothing | S | Low | STANDING | — |
| RE-SERV-005 | No throttling of failed logons, and the NTLM challenge survives a failed AUTHENTICATE | M | Med | STANDING | — |
| RE-SERV-006 | LOGOFF does not retire the SessionId; the next session on the connection silently reuses it | S | Low | STANDING | — |
| RE-SERV-007 | TREE_DISCONNECT, ECHO and LOGOFF answer SUCCESS with no session at all | S | Low | STANDING | — |
| RE-SERV-008 | A malformed KEY_EXCH wrapped key silently falls back to the SessionBaseKey | S | Low | STANDING | — |
| RE-SERV-009 | A corrupt trailing segment in a compound request discards every reply, including successes already computed | S | Low | STANDING | — |
| RE-SERV-010 | QUERY_DIRECTORY returns an entry larger than the client's OutputBufferLength | S | Low | STANDING | — |
| RE-SERV-011 | QUERY_DIRECTORY's pattern filter is bypassed for "." and ".." | S | Low | STANDING | — |
| RE-SERV-012 | A zero-length READ is answered STATUS_END_OF_FILE | S | Low | STANDING | — |
| RE-SERV-013 | NEGOTIATE silently accepts a dialect list shorter than DialectCount claims | S | Low | STANDING | — |
| RE-SERV-014 | FLUSH cannot fail: it is the only handle handler with no body-length check, and it swallows fsync errors | S | Low | STANDING | — |
| RE-SERV-015 | Receive framing has no size cap, and `_recv_exact` concatenates quadratically | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-016 | `send_msg` raises OverflowError for a reply over 16 MiB, killing the connection thread | S | Low | STANDING | — |
| RE-SERV-017 | No resource limits: unbounded connection threads, no timeout on accepted sockets, unbounded handles and trees per connection | M | Med | STANDING | — |
| RE-SERV-018 | Handles name paths, not files: lazy open-by-path serves whatever the path names at first use | M | Med | STANDING | — |
| RE-SERV-019 | FileAccessInformation always reports full access (0x001F01FF) | S | Low | STANDING | — |
| RE-SERV-020 | Rename ignores the RootDirectory field, so a directory-relative rename lands at the share root | S | Low | STANDING | — |
| RE-SERV-021 | The account password is taken on the command line, where any local user can read it | M | Low | STANDING | — |
| RE-SERV-022 | The `--smb-version 2/3` SMB2 handlers are stubs that claim success without doing any work | S | Low | REVISED | Narrowed scope: SMB2 stub fake success holds for session_setup/create/read/write/negotiate and the auth-bypass dispatch is real, but h2_tree_connect does not succeed — it raises struct.error on every call and kills the connection thread; QUERY_DIRECTORY is 0x000E, not the cited 0x000A (0x000A is LOCK), though 0x000E is unmapped so the cannot-list conclusion stands. |
| RE-SERV-023 | Short or malformed parameter blocks raise `struct.error` out of the handlers and kill the connection, with no SMB error reply | S | Low | STANDING | — |
| RE-SERV-024 | A non-ASCII configured password makes every login attempt raise `TypeError` in `hmac.compare_digest` | S | Low | STANDING | — |
| RE-SERV-025 | No bound tying accepted message size to the advertised buffer, no connection idle timeout, and unbounded thread-per-connection growth | S | Low | STANDING | — |
| RE-SERV-026 | QUERY_INFORMATION_DISK reports invented disk geometry and free space | S | Low | STANDING | — |
| RE-SERV-027 | Boolean environment values outside a four-word vocabulary silently parse as False — including `RO`, so `RO=2` yields a writable server with no warning — and env-enabled booleans have no CLI off-switch | S | Low | STANDING | — |
| RE-SERV-028 | GETSTAT on a symlink pointing outside the root raises TypeError and sends no reply | S | Low | STANDING | — |
| RE-SERV-029 | BREAD/BWRITE never validate the sector range against the device or file size; BWRITE past the end extends the host image and reports success | S | Low | STANDING | — |
| RE-SERV-030 | WRITE_DATA trusts the chunk header: `chunk_size` is never checked against the datagram, `total_chunks` is re-read from every chunk, and BWRITE completion reports success for short data | S | Low | STANDING | Fix-scope extension (Stage B, Cross CAND-01): Python `_complete_bwrite` discards the `write()` return value and credits `expected_size` to `stats['bytes_written']` even on short delivery or short OS write |
| RE-SERV-031 | Block-device handle 0 is one shared file object with one shared cursor across all sessions for READ, LSEEK and file-WRITE | M | Med | STANDING | — |
| RE-SERV-032 | No writer exclusion anywhere: two sessions can hold the same file open writable and interleave writes | M | Med | STANDING | — |
| RE-SERV-033 | READ/BREAD on a handle that is not open for reading crashes the reply: `-e.errno` on an errno-None exception | S | Low | STANDING | — |
| RE-SERV-034 | Serving-path compressed wrappers trust header geometry without bounds; the limits module only protects the opt-in inspection path | M | Med | STANDING | — |
| RE-SERV-035 | MKDIR passes the wire `mode` to `os.mkdir` unsanitised | S | Low | REVISED | Narrowed scope: Wire mode does reach os.mkdir unsanitised and the sticky bit survives end-to-end (0o1755 → 0o1750), but the filed setgid example did not reproduce (0o2755 → 0o750 on this host/fs), so setgid survival is host/group-dependent, not guaranteed. |
| RE-SERV-036 | UDPBD file-backed BlockDevice has no extent bounds: out-of-range WRITE silently extends the image, out-of-range READ silently returns zeros | S | Low | STANDING | — |
| RE-SERV-037 | UDPBD read-only file device silently swallows an entire write transfer and only reports failure at the very end — unlike both other backends, which raise on the first write | S | Low | STANDING | — |
| RE-SERV-038 | HTTP legacy-flat profile serves symlinks that escape the games folder; the containment check exists but is only applied in the path-aware profile | S | Low | STANDING | — |
| RE-SERV-039 | NFS: WRITE and SETATTR need no OPEN and no valid stateid — OPEN's access checks are dead letter for the write path | M | Med | STANDING | — |
| RE-SERV-040 | SMB WRITE_ANDX reports only the low 16 bits of the byte count it actually wrote | S | Low | STANDING | — |
| RE-SERV-041 | SMB WRITE_ANDX assembles its data length in a plain `int`, the exact 32-bit wrap `readAndX` was fixed for | S | Low | STANDING | — |
| RE-SERV-042 | SMB WRITE_ANDX ignores the handle's access mode and re-opens the file by path for writing | M | Med | STANDING | — |
| RE-SERV-043 | UDPBD read-only writes fake success at the device layer and arm a real write handshake at the handler layer | S | Low | STANDING | — |
| RE-SERV-044 | UDPBD write state is one global slot: any peer's INFO or READ silently destroys another peer's in-flight write (Go Edge and Python UDPBD) | S | Low | STANDING | — |
| RE-SERV-045 | UDPFS status "Busy" latches on for the life of a session after its first data packet | M | Med | STANDING | — |
| RE-SERV-046 | SMB TRANSACTION handler answers every transaction as a NetShareEnum, ignoring the request entirely — in both the Go Edge SMB server and the Python SMB1 server | S | Low | STANDING | — |
| RE-SERV-047 | Live `/api/logs` stream forwards lines without the SSE sanitisation applied to every other line | S | Low | STANDING | — |
| RE-SERV-048 | `raw_storage` runs bare `powershell.exe` from PATH/CWD while every other PowerShell call site in the repo resolves the absolute System32 path specifically to prevent binary hijacking | S | Low | STANDING | — |
| RE-SERV-049 | Native RA dashboard builds achievement list with `innerHTML` from unescaped server-supplied titles/descriptions | S | Low | STANDING | — |
| RE-SERV-050 | Caduceus Web API key is sent as a GET query parameter on every API request | S | Low | STANDING | — |
| RE-SERV-051 | Caduceus library (`G`) progress replies always report 0 earned / 0 maximum | S | Low | STANDING | — |
| RE-SERV-052 | WHICH-DEVICE.txt shipped in every Edge archive falsely claims the binary is read-only by default | S | Low | STANDING | — |
| RE-SERV-053 | The bcrypt CMAC self-test compares against the wrong constant: it is the CMAC *L* block, not a CMAC | S | Low | STANDING | — |
| RE-SERV-054 | `check_component("")` raises IndexError instead of PathError | S | Low | STANDING | — |
| RE-SERV-055 | `CHECK_DIRECTORY` never succeeds for a spec-formed request because it does not strip the `0x04` BufferFormat byte its sibling handler strips | S | Low | STANDING | — |
| RE-SERV-056 | NEGOTIATE returns success with DialectIndex 0 when the client never offered NT LM 0.12 | S | Low | STANDING | — |
| RE-SERV-057 | Core's `run()` drops the base server's per-datagram `OSError` containment, so one failed INFORM send can kill the whole server loop | S | Low | STANDING | — |
| RE-SERV-058 | Environment integer/float parsing crashes at parser construction, while the neighbouring duration/size parsers were deliberately made never to raise | S | Low | STANDING | — |
| RE-SERV-059 | `PROTOCOL_MODE` from the environment is neither stripped nor alias-mapped, slips past argparse's `choices`, and detonates later as an uncaught `ValueError` | S | Low | REVISED | Narrowed scope: Core defect is real (PROTOCOL_MODE=proper passes argparse's choices, then raises an uncaught ValueError at construction), but the trailing-space sub-claim is false — __init__ strips and lowercases, so "modulo ", " modulo", "MODULO" and "Standard" all construct fine; only unmapped values fail. |
| RE-SERV-060 | ZSO decompression retries once per input byte: a garbage block costs one LZ4 attempt per byte of input | S | Low | STANDING | — |
| RE-SERV-061 | Compressed block offsets are never validated in the serving path, and short/corrupt blocks are silently fabricated into data | M | Low | STANDING | — |
| RE-SERV-062 | Router-status replies never set FLAG_UDPBD or FLAG_DECOMPRESSES, even when the server serves a block device / decompresses | S | Low | STANDING | — |
| RE-SERV-063 | LSEEK whence handling disagrees by handle type: the compressed wrapper silently accepts any whence | S | Low | STANDING | — |
| RE-SERV-064 | UDPBD `BlockDevice` constructor validates the target type but not its size: >2 TiB images break INFO packing, non-512-multiple sizes silently lose their tail | S | Low | STANDING | — |
| RE-SERV-065 | HTTP flat index: path lookup serves the duplicate copy that the scan explicitly suppressed and that `games.csv` does not list | S | Low | STANDING | — |
| RE-SERV-066 | HTTP dispatcher sends a 500 response after a 206 header (and possibly partial body) is already on the wire | S | Low | STANDING | — |
| RE-SERV-067 | HTTP per-connection cached handle is keyed by path only, so an index refresh / file replacement is served from the stale handle with the new entry's size | S | Low | REVISED | Narrowed scope: Stale-handle mechanism is real only for same-path replacement (a re-dumped ISO is served from the stale handle with the new entry's size); the filed .chd→.iso swap cannot hit it because entry.path differs between extensions and forces a reopen. |
| RE-SERV-068 | LZ4 block decoder's length accumulator is unbounded, defeating its own output checks on 32-bit targets | S | Low | STANDING | — |
| RE-SERV-069 | Text-mode log lines with fields are fragmented into multiple LogBuffer lines (and subscribers get the fragments) | S | Low | STANDING | — |
| RE-SERV-070 | `ValidateConfig` accepts values the binary then refuses at startup (sector size, compression cache, peer timeout) | S | Low | STANDING | — |
| RE-SERV-071 | `genericManager.Restart` dereferences a possibly-nil logger and reports success for a restart that did nothing | S | Low | STANDING | — |
| RE-SERV-072 | `IsStatusQuery`'s documentation claims exact-length strictness the code does not implement | S | Low | STANDING | — |
| RE-SERV-073 | SMBv2/SMBv3 argv builder crashes on `root_dir`-only values and silently emits an empty share, where SMBv1 accepts and validates | S | Low | STANDING | — |
| RE-SERV-074 | Windows/Linux firewall port list still keys UDPFS single-port mode off the retired `modulo_mode` setting, so a migrated config silently gains a dead data-port rule | S | Low | STANDING | — |
| RE-SERV-075 | NFS and RetroAchievements never get the cooperative stop pipe, so on Windows Stop kills them outright — skipping NFS cleanup and orphaning the RetroAchievements engine child | M | Med | STANDING | — |
| RE-SERV-076 | Choice-field values have no single stored vocabulary: the RetroAchievements mode default is the wire value while the other two choice fields default to display labels, and three separate tolerant readers compensate | M | Med | STANDING | — |
| RE-SERV-077 | The SMB port default lives in three places and one of them is wrong: the firewall layer defaults SMBv2/SMBv3 to 1025, the servers default to 1445 | S | Low | STANDING | — |
| RE-SERV-078 | `netinfo.best_lan_ip()` returns the default-route address unconditionally, bypassing the private-LAN ranking the module exists to apply | S | Low | STANDING | Fix-scope extension (Stage B, PS2Servers CAND-03): CAND-D2 — best_lan_ip docstring contradicts the module contract |
| RE-SERV-079 | Owned-runtime `/state` schema diverges from the managed-engine schema its own consumers parse, and two counters are fabricated | M | Med | STANDING | Fix-scope extension (Stage B, PS2Servers CAND-02): CAND-D1 — Caduceus read_events unlock notices suppressed for owned-runtime state (at-vs-ago, second victim of RE-SERV-079) |
| RE-SERV-080 | Web "Sign out" deletes the stored credentials, permanently cancels submissions, and can report failure after revocation already happened | M | Med | STANDING | — |
| RE-SERV-081 | Caduceus: unauthenticated CADQ sender becomes the unlock-notice destination, and the CADA pairing key lives in the console-served games folder | M | Med | STANDING | — |
| RE-SERV-082 | Identification's `gameid` request bypasses all pacing, and its 429 backoff is discarded | M | Med | STANDING | — |
| RE-SERV-083 | Caduceus `pad()` over-pads by a full 64-byte block whenever the body is already block-aligned, diverging from the owned protocol's padding | S | Low | STANDING | — |
| RE-SERV-084 | `CredentialStore` wedges permanently if the profile directory pre-exists with non-0700 permissions, and `load()` can raise instead of returning "no credentials" | S | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-085 | Shipped systemd webui env file configures a start the binary refuses | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-086 | ps2servers@.service header falsely states "Edge has no SMB at all" | S | Low | STANDING | — |
| RE-SERV-087 | OpenWrt init script's fallback enables the shared status port that the shipped config deliberately disables | S | Low | STANDING | — |
| RE-SERV-088 | `tryTrans2` can never return an error, and `TestSearchesAreBounded` never asserts the bound | S | Low | STANDING | — |
| RE-SERV-089 | `TestServerPortFallback` never exercises the fallback or any port | S | Low | STANDING | — |
| RE-SERV-090 | `TestCompressionCacheDefaultsAndDisables` tests struct storage, not defaulting or disabling | S | Low | STANDING | — |
| RE-SERV-091 | `TestSafeCueNameRejectsInvalidAndOverlongUTF8` has no positive control; a reject-everything stub passes | S | Low | STANDING | — |
| RE-SERV-092 | Windows-only filesystem test can never run in CI | M | Low | STANDING | — |
| RE-SERV-093 | Three "behaviour" tests assert only that constants lie in a range | M | Low | STANDING | — |
| RE-SERV-094 | UDPFS test helper `result()` reports a truncated reply as success (0) | S | Low | STANDING | — |
| RE-SERV-095 | `TestUnknownServiceIDIsStillIgnored` is negative-only and passes with the transport completely dead | S | Low | STANDING | — |
| RE-SERV-096 | Duplicated test scaffolding: the same mutex log buffer twice in one package, and CSO fixture builders re-implemented four times | M | Low | STANDING | — |
| RE-SERV-097 | The fuzz target and the benchmark are never run as fuzzing or benchmarking anywhere | S | Low | STANDING | — |
| RE-SERV-098 | Dead keep-alive line for an unused import in `blockdev_test.go` | S | Low | STANDING | — |
| RE-SERV-099 | `TestBlockGeometryIsConsistent` asserts identities guaranteed by the implementation's own formulas | S | Low | STANDING | — |
| RE-SERV-100 | `TestSharedHandshakeFixtures` duplicates the hardcoded cases and degrades to a silent skip | S | Low | STANDING | — |
| RE-SERV-101 | The attribution test mutates, and depends on, the developer's real checkout | M | Low | STANDING | — |
| RE-SERV-102 | Eight test files silently run zero tests when executed directly | S | Low | REVISED | Narrowed scope: Census is exact (8 of 36 in-scope files lack unittest.main()), but the stated impact is narrower/false as written: plain `python tests/test_game_library.py` exits 1 with ModuleNotFoundError: No module named 'launcher', not silent exit-0 — the silent-0 behaviour occurs only with PYTHONPATH=. and adding the guard alone cannot fix direct runs. Fix-scope extension (Stage B, PS2Servers CAND-04): CAND-F1 — Direct script execution broken suite-wide by missing sys.path prologues |
| RE-SERV-103 | The Edge flag-extraction helpers are copied verbatim between test files | S | Low | STANDING | — |
| RE-SERV-104 | The shared ISO fixture lives inside a test module — and one consumer re-implements it anyway | M | Low | STANDING | — |
| RE-SERV-105 | test_library_preferences executes AST-extracted copies instead of the production methods | M | Low | STANDING | — |
| RE-SERV-106 | The netinfo detailed-format test asserts only the formatter's own constant strings | S | Low | STANDING | — |
| RE-SERV-107 | A traversal test whose name promises the opposite of what it asserts | S | Low | STANDING | — |
| RE-SERV-108 | The hardlink backup test passes vacuously where hardlinks are unavailable | S | Low | STANDING | — |
| RE-SERV-109 | The display-guard + full-app construction prologue is copy-pasted through the GUI tests | M | Low | STANDING | — |
| RE-SERV-110 | Mid-file `unittest.main()` orphans tests under direct execution in two SMB2 test files (23 + 5 tests) | S | Low | STANDING | — |
| RE-SERV-111 | Cross-implementation encoder test converts a Go timeout into a skip | S | Low | STANDING | — |
| RE-SERV-112 | Banner address test asserts nothing when the host returns no addresses | S | Low | STANDING | — |
| RE-SERV-113 | systemd unit tests assert only inside loops over parsed content, with no non-emptiness guard | S | Low | STANDING | — |
| RE-SERV-114 | Share-name test is tautological: it reads back the dict it just passed in | S | Low | STANDING | — |
| RE-SERV-115 | Setup-guide tests assert substrings of the GUI source instead of behaviour | M | Low | STANDING | — |
| RE-SERV-116 | Stop-all tests are AST inspections of gui.py, not executions of stop-all | M | Low | STANDING | — |
| RE-SERV-117 | "Every edge target has a purpose" test checks only that label strings exist | S | Low | STANDING | — |
| RE-SERV-118 | POSIX permission test passes by bare `return` on Windows instead of skipping | S | Low | STANDING | — |
| RE-SERV-119 | Identical helper bodies duplicated across test files | S | Low | STANDING | — |
| RE-SERV-120 | Two identical payload builders under different names inside test_transfer_limits.py | S | Low | STANDING | — |
| RE-SERV-121 | Whole-registry launcher test asserts only that build_argv returns a list | S | Low | STANDING | — |
| RE-SERV-122 | Real-socket recv-buffer test's only assertion cannot fail | S | Low | STANDING | — |
| RE-SERV-123 | FakeServices answers silent success to any PowerShell command it doesn't recognise | S | Low | STANDING | — |
| RE-SERV-124 | Tests patch shared stdlib module objects, so a missed restore leaks into the whole discover run | M | Medium | STANDING | — |
| RE-SERV-125 | Five test files each exec a private copy of ps2servers_core.py under a different module name | M | Medium | STANDING | — |
| RE-SERV-126 | `_local_ipv4_addresses` runs three enumeration mechanisms to print one cosmetic warning line | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-127 | The srvsvc pipe does not reassemble a PDU split across WRITEs (or across RPC fragments) | M | Low | STANDING | — |
| RE-SERV-128 | `_optimal_chunk_size` computes an "optimum" that is always 1408 | S | Low | WITHDRAWN | Defeating evidence: Executing the actual _optimal_chunk_size method (udpfs_server.py:2746) returns 1024 for totals 0/100/1024, 1280 for 1025/12800, and 1408 only for 20000/100000 — the audit missed the tie-break limb (on a packet-count tie higher alignment wins, candidates visited smallest-first, so 1024 displaces the 1408 incumbent). |
| RE-SERV-129 | NFS is the only server without the shared `--session-summary` feature | M | Low | STANDING | — |
| RE-SERV-130 | UDPFS plain file WRITE is never held to the length it declared, unlike the BWRITE path that was hardened for exactly this | S | Low | STANDING | — |
| RE-SERV-131 | The GUI's theme, admin panel and log trimming live as a ~300-line monkeypatch shim in the entry point, and its copy of `_append_log` has already drifted from gui.py's original | M | Med | STANDING | — |
| RE-SERV-132 | The owned runtime bypasses `AccountSession` entirely: hardcoded epoch 1 and fixed task IDs, while the session's begin/accept state machine runs only in tests | L | Med | STANDING | — |
| RE-SERV-133 | Watch-profile vocabulary disagrees across three files: `orbit-v1.0.2` is accepted but never produced, `caduceus` is produced but rejected by the IPC validator | S | Low | REVISED | Narrowed scope: Watch-profile vocabulary mismatch is real (sets exactly as cited; no producer emits orbit-v1.0.2), but the caduceus discard is latent, not live: the only production ProcessResolver (in AccountWorker) overrides the validator with valid_account_result, and the caduceus path never crosses valid_identification_result. |
| RE-SERV-134 | GUI behaviour is assembled by stacked monkey-patches, including a custom import-hook finder in `launcher/__init__.py` | M | Med | STANDING | — |
| RE-SERV-135 | `ps1_index.py` is a complete PS1 scanner with no consumer in the launcher | S | Low | STANDING | — |
| RE-SERV-136 | Three competing application-icon sources: shipped LOGO, a 246-line procedural icon generator, and a tray fallback badge | M | Med | STANDING | — |
| RE-SERV-137 | The "shared index" is wrapped in two pass-through layers on top of `read_index` | S | Low | STANDING | — |
| RE-SERV-138 | conformance/integration/http_probe.py is orphaned: no CI step, test or runner references it | S | Low | STANDING | — |
| RE-SERV-139 | The session-id minting line is duplicated inside `h_session_setup` | S | Low | STANDING | — |
| RE-SERV-140 | The Transaction response envelope is built twice, once for TRANS2 and once open-coded in the RAP handler | S | Low | STANDING | — |
| RE-SERV-141 | Compressed-image stem/extension matching is implemented twice, with subtly different rules | S | Low | STANDING | — |
| RE-SERV-142 | Three copy-pasted ID allocators, and FID wrap-around silently overwrites a live open file, leaking its handle | S | Low | STANDING | — |
| RE-SERV-143 | The entry-point surface (parser + validation + compression precedence + server construction) is duplicated between Core and the standalone server, and again inside Core's own `main()` | M | Low | STANDING | — |
| RE-SERV-144 | DATA header parsing and payload-size computation are duplicated between `_route_data_via` and `_handle_data` (and parsed a third time by the base handler) | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-145 | The session-stats attachment snippet is copy-pasted between Core and the SMB1 server instead of shared | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-146 | Compressed-header parsing is triplicated: the size probe, the three wrappers, and the limits module each parse the same headers, including the CD-CHD size correction twice | M | Med | STANDING | — |
| RE-SERV-147 | UDPBD `_handle_read`'s `is_raw` extent pre-check duplicates the bound both raw backends already enforce in `seek` | S | Low | STANDING | — |
| RE-SERV-148 | NFS `_op_close` and `_op_open_confirm` are byte-identical bodies under two names | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-149 | `_stop_on_sigterm` is duplicated between the HTTP and NFS entry points (and has already drifted) | S | Low | STANDING | — |
| RE-SERV-150 | CSO/ZSO index-extent validation is duplicated verbatim between `openImage` and `SizeOf` | S | Low | STANDING | — |
| RE-SERV-151 | The CHDv5 header is parsed twice, by two parsers with different validation rules | M | Med | STANDING | — |
| RE-SERV-152 | SMB hand-rolls `itoa` instead of using `strconv.Itoa` | S | Low | STANDING | — |
| RE-SERV-153 | SMB's FID/TID/SID allocators are three copies of one function | S | Low | STANDING | — |
| RE-SERV-154 | UCI boolean parsing is duplicated 16 times inline and disagrees with the one use of the shared helper | S | Low | STANDING | — |
| RE-SERV-155 | The four subcommands copy-paste their flag scaffolding — and the copy in `runWebUI` already lost the `--log-format` validation | M | Low | STANDING | — |
| RE-SERV-156 | Port-445 takeover is two divergent full implementations (SMBv1 and SMBv2 servers), with the PowerShell-resolution helper copied a third time in the launcher | L | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-157 | SIGTERM→KeyboardInterrupt stop handling is installed three times: once by serve.py for every launcher child, and again inside the HTTP and NFS servers | S | Low | STANDING | — |
| RE-SERV-158 | The stop-pipe environment name is a duplicated string literal in the two files whose agreement the whole cooperative-stop mechanism depends on | S | Low | STANDING | — |
| RE-SERV-159 | Three `_parse_port` implementations with three different failure semantics | S | Low | STANDING | — |
| RE-SERV-160 | Interface-address parsing is implemented four times across netinfo and directlink, including two different functions with the same name | M | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-161 | DHCP option-TLV parsing is written twice inside directlink.py because `parse_packet` cannot be reused for replies | S | Low | STANDING | — |
| RE-SERV-162 | Frozen-executable probing is duplicated between config.py and servers.py | S | Low | STANDING | — |
| RE-SERV-163 | SMBV2 and SMBV3 share one mutable `fields` list object | S | Low | STANDING | — |
| RE-SERV-164 | DPAPI unprotect is implemented twice, with divergent hygiene | S | Low | STANDING | — |
| RE-SERV-165 | Account-identity / token validation re-implemented at eight sites with divergent rules | M | Low | STANDING | — |
| RE-SERV-166 | Achievement-definition validation duplicated four times, and `award_achievement` bypasses the shared response decoder | M | Low | STANDING | — |
| RE-SERV-167 | Five different title-sanitising implementations across the RA files | S | Low | STANDING | — |
| RE-SERV-168 | The loopback `/state` fetch is duplicated verbatim in the overview and the session poller | S | Low | STANDING | — |
| RE-SERV-169 | Two parallel library subsystems: two catalogue databases, two folder preferences, two importers, two backups, two UIs | L | Med | STANDING | — |
| RE-SERV-170 | Three setup guides and two first-run mechanisms; the standalone LibraryPanel guide is unreachable in the shipped app | M | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-171 | Four separate games-folder scanners/indexers over the same trees | L | Med | STANDING | — |
| RE-SERV-172 | Two independent ISO9660 directory parsers (PS2 `disc_identity` vs PS1 `ps1_vcd`) | M | Med | STANDING | — |
| RE-SERV-173 | The PS2 disc-serial pattern is re-expressed five times, in five files, with five slightly different rules | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-174 | Console artwork conversion is implemented twice, with different palette rules and different write paths | S | Low | STANDING | — |
| RE-SERV-175 | Two incompatible "has this file changed?" stamps for the same images | S | Low | STANDING | — |
| RE-SERV-176 | Desktop release build duplicated across release.yml and release-on-main.yml; the copies have already drifted | L | Med | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-177 | Two parallel documentation systems (34 Markdown + 22 HTML) cover the same topics with no generator between them | L | Med | STANDING | — |
| RE-SERV-178 | Dead code with zero callers anywhere in the repo | S | Low | STANDING | — |
| RE-SERV-179 | No native CMAC backend is probed on macOS, so signed SMB3 there runs on the pure-Python AES | M | Low | STANDING | — |
| RE-SERV-180 | FIND_FIRST2 / FIND_NEXT2 return exactly one directory entry per round trip | M | Med | STANDING | — |
| RE-SERV-181 | WRITE_ANDX re-opens the file from disk on every write, and the open file's cached size is never updated by writes | M | Med | STANDING | — |
| RE-SERV-182 | `Share.resolve`'s comment promises a share-prefix strip the code does not perform | S | Low | STANDING | — |
| RE-SERV-183 | `classify_profile` contains an unreachable third branch that restates the first | S | Low | STANDING | — |
| RE-SERV-184 | Two names are imported from `udpfs_server` and never used | S | Low | STANDING | — |
| RE-SERV-185 | `main()`'s Modulo fast path bypasses `AutoUdpfsServer`, leaving Auto's own Modulo handling unreachable on the shipped path | M | Med | STANDING | — |
| RE-SERV-186 | A thread is spawned for every fallback timer, one per discovery, although at most one can ever act | S | Low | STANDING | — |
| RE-SERV-187 | `tx_start_seq` is write-only dead state | S | Low | STANDING | — |
| RE-SERV-188 | Selftest blind spots: skipped sections still print ALL PASSED on POSIX, and no in-scope selftest exercises a single write opcode or hostile wire input | M | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-189 | NFS `_Handles` grows without bound for the life of the server; every neighbouring table has a cap, this one has none | S | Low | STANDING | — |
| RE-SERV-190 | NFS: one global generation counter means any single write invalidates every connection's read handles and every cached directory listing | M | Med | STANDING | — |
| RE-SERV-191 | NFS PUTFH resolves the handle number and throws it away; READ and READDIR then re-derive it through the mutating `handle()` on the hot path | M | Med | STANDING | — |
| RE-SERV-192 | UDPBD `seen` peer map grows forever and the status reply reports it as the live session count | S | Low | STANDING | — |
| RE-SERV-193 | Every directory listing / OPEN / GETSTAT re-parses compressed-image headers from disk — no caching (Python UDPFS and Go Edge UDPFS) | M | Med | STANDING | — |
| RE-SERV-194 | SMB FIND_FIRST2's EndOfSearch branch is dead: the entry list can never have length 1 | S | Low | STANDING | — |
| RE-SERV-195 | `compression.Open` is a production-dead wrapper kept alive only by tests | S | Low | STANDING | — |
| RE-SERV-196 | OpenWrt `ServiceLogs` ignores its line limit, defeating the stated snapshot memory bound | S | Low | STANDING | — |
| RE-SERV-197 | `sessionstats` exports production API that only tests use: `Parse`, `WithClock`, `WithLimits` | S | Low | STANDING | — |
| RE-SERV-198 | Dead webui surface: an unread `API.log` field, and `Server.GeneratedPassword` / `Server.Close` with no callers | S | Low | STANDING | — |
| RE-SERV-199 | `Root.List` fully symlink-resolves and stats every directory entry, one `EvalSymlinks` per entry | M | Med | STANDING | — |
| RE-SERV-200 | The native-binary launch mechanism in the registry is dead: no registered server uses it | S | Low | STANDING | — |
| RE-SERV-201 | Virtual exFAT construction recomputes the full 65,536-entry Unicode upcase table on every instantiation (~130-180 ms for a one-file folder) | S | Low | STANDING | — |
| RE-SERV-202 | Opening one raw device re-runs the full OS disk enumeration up to twice, and every mount check re-runs it again | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-203 | session_stats' header contract names the wrong server set | S | Low | STANDING | — |
| RE-SERV-204 | Verified dead code: `derive_watch` alias, unused `ENDPOINT` attributes, two unused imports | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-PS2Servers.md` supersede the filed ones. |
| RE-SERV-205 | The same watch list is fully re-validated four times on every set activation | M | Med | STANDING | — |
| RE-SERV-206 | SSE `/events` uses one shared dirty-flag for all clients and ignores its result, so every client is sent the full state about once a second regardless of change | S | Low | STANDING | — |
| RE-SERV-207 | Zero-caller symbols: `AVAST_GEN_PUBLIC_NOTE`, `theme_assets.photo()`, `LauncherApp.on_close()`, `LauncherApp._quit_from_tray()`, and a double wrapper in dependency_panel | S | Low | STANDING | — |
| RE-SERV-208 | `Library.installed()` re-validates every path up to three times per call, and `Catalog.list_games()` stats every verified row on every listing | M | Med | STANDING | — |
| RE-SERV-209 | `LOGO.png` is 603 KB at 1229×1185 for display slots of at most 256 px; downscaling is integer-only subsampling | S | Low | STANDING | — |
| RE-SERV-210 | `gui.py` embeds ~10 KB of About/manual prose that is mutated at runtime by another module | S | Low | STANDING | — |
| RE-SERV-211 | Dependency checks are never cached: every panel refresh re-probes lz4 and re-`LoadLibrary`s libchdr candidates; the PATH cache is process-stale | S | Low | STANDING | — |
| RE-SERV-212 | OpenWrt package metadata is a release behind and describes a UDPFS-only read-only server that no longer exists | S | Low | STANDING | — |
| RE-SERV-213 | The portable/AppImage half of the release pipeline cannot fail, so missing downloads stay green | S | Low | REVISED | Narrowed scope: Core stands (portable/AppImage steps are fail-soft), but release.yml carries 11 continue-on-error: true, not 13, and the claimed if-no-files-found: error + continue-on-error pairing does not exist at release.yml:403-420 — that pairing actually occurs in release-on-main.yml's portable upload. Fix-scope extension (Stage B, PS2Servers CAND-08): CAND-I1 — release.yml portable upload omits if-no-files-found entirely |
| RE-SERV-214 | Go toolchain pinned three different ways across Edge's own build paths | S | Low | STANDING | — |
| RE-SERV-215 | Byte-identical 571,581-byte banner PNG tracked twice | S | Low | STANDING | — |
| RE-SERV-216 | ~3.16 MB of generated compression test fixtures are tracked as binaries | S | Low | REVISED | Narrowed scope: Per-file sizes are exact, but the fixtures are not 'generated' and not undocumented: testdata/README.md records them as unmodified upstream pcm720/udpfsd reference vectors at a pinned commit, which undercuts the filed fix; true sum is 3,215,374 B (≈3.22 MB), not ~3.16 MB. |

### New findings — PS2-Servers (Stage C, from Stage B candidates)

| ID | Title | Status | Note |
|---|---|---|---|
| RE-SERV-217 | SMB2 stub `h2_tree_connect` crashes on every call (struct.pack arity bug) | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-PS2Servers.md`, CAND-01). |
| RE-SERV-218 | NFS4 endless-empty-fragments test is timing-fragile by construction | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-PS2Servers.md`, CAND-05). |
| RE-SERV-219 | `h_trans2_find_first2` crashes with IndexError on an empty directory | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-PS2Servers.md`, CAND-06). |

## Cross-repo

| ID | Title | Effort | Risk | Status | Note |
|---|---|---|---|---|---|
| RE-X-01 | RiptOPL UDPRDMA receive copies a wire-controlled app-header length into fixed buffers; SMS already clamps it | S | Low | STANDING | — |
| RE-X-02 | RiptOPL read path returns a wire-controlled byte count from an uninitialised reply struct; SMS zero-inits and clamps | S | Low | STANDING | — |
| RE-X-03 | A pre-hardening copy of the UDPFS Python server ships inside RiptOPL with none of the current server's wire-value validation | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Cross.md` supersede the filed ones. |
| RE-X-04 | Standalone UDPBD Python server range-checks READ only for raw devices and WRITE not at all; the Go server refuses out-of-range for both | S | Low | STANDING | — |
| RE-X-05 | Python and Go UDPFS servers disagree on BWRITE completion: Python silently truncates over-delivered data and reports 0, Go requires exact length and reports the byte count | M | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Cross.md` supersede the filed ones. |
| RE-X-06 | SMS block read treats EOF/short reads as full success and leaves stale bytes in the caller's buffer; RiptOPL already handles both | S | Low | STANDING | — |
| RE-X-07 | SMS's SMAP FIFO read still drops the last byte of odd-sized frames; RiptOPL and Launchstation both carry the fix | S | Low | STANDING | — |
| RE-X-08 | SMS's send path accepts any ACK as covering the sent packet (stale-ACK check is arithmetically inert); RiptOPL waits on the same timer with a real coverage test | M | Medium | STANDING | — |
| RE-X-09 | SMS ignores `SetAlarm` failure and can wait forever for an ACK/timeout that will never be signalled; RiptOPL fails the wait as a timeout | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Cross.md` supersede the filed ones. |
| RE-X-10 | Go UDPFS server returns all-zero timestamps (and zero attr) in OPEN_REPLY / DREAD_REPLY / GETSTAT_REPLY; Python returns real times | S | Low | REVISED | Narrowed scope: Timestamps only — the attr half is not a divergence (Python hard-codes attr 0 in every stat path and OPEN_REPLY has no attr field), and full ctime/atime parity is new code, not a fill-in (DREAD's DirEntry carries only ModTime, os.FileInfo exposes no portable ctime/atime, most OPEN paths never stat, and no PS2 8-byte time encoder exists in the Go tree); mtime parity alone is the small sane fix. |
| RE-X-11 | Discovery header's second field is documented as "reserved, must be 0" in C but is the data port in both servers; the C client ignores it and trusts the UDP source port instead | S | Low | STANDING | — |
| RE-X-12 | RiptOPL carries three byte-identical copies of every UDPFS wire header (plus the ACK helper); SMS proves one copy per module is enough | M | Medium | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Cross.md` supersede the filed ones. |
| RE-X-13 | Launchstation's dashboard starter `title.cfg` is written with spaced `title = / boot =` lines that RiptOPL's parser silently drops — the app vanishes from RiptOPL's Apps list | S | Low | STANDING | Fix-scope extension (Stage B, Cross CAND-02): Scope extension of RE-X-13 — same spaced `title.cfg` form in a Launchstation docs example |
| RE-X-14 | Same shared `title.cfg`, same concept, different key: Launchstation writes launch arguments as `arg=`, RiptOPL reads `argv1=` — each silently ignores the other's | S | Low | REVISED | Narrowed scope: Key-name divergence for the single-argument case only — RiptOPL's `argv1` is a single argument while Launchstation's `arg` is repeatable, one-per-line, multi-argument, so the proposed fix delivers only prospective single-argument parity in one direction and the unqualified benefit claim is overstated for existing and multi-`arg=` files. |
| RE-X-15 | POPSLoader `ata_bd_fast`: LBA48 chunk counted in a `u16` — requests over 65536 sectors never advance (livelock) | S | Low | REVISED | Narrowed scope: A real livelock (trigger actually nsectors ≥ 65536) in unused vendored source only — the shipped `ata_bd.irx` is the pinned R3Z v4.70 binary, the Makefile states the `iop/ata_bd_fast` source/build rule is kept but unused, and the in-file BDM wrapper (u16 count, max 65535) cannot trigger it, so the filed shipped-loader exposure is not established; worth fixing before any re-enablement. |
| RE-X-16 | Tarball `usbmass_bd` scsi: READ/WRITE(10)-only (silent >2 TiB LBA truncation) and an unbounded TEST UNIT READY loop; the fixed driver exists byte-identical in RiptOPL and Launchstation | S | Low | STANDING | — |
| RE-X-17 | Tarball BDM core is the unhardened snapshot: GPT/MBR parsers and block cache lack every RiptOPL guard | M | Medium | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Cross.md` supersede the filed ones. |
| RE-X-18 | ps2ips RPC: the two copies fixed opposite halves — each still carries the other's bugs | M | Medium | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Cross.md` supersede the filed ones. |
| RE-X-19 | DS3 battery index `power_level[Power]` out-of-bounds in 8 of 10 ds34 copies | S | Low | STANDING | — |
| RE-X-20 | ds34bt DS4 LED report: `memset` length is the DS3 length in 4 of 5 copies (29 bytes of stack sent) | S | Low | STANDING | — |
| RE-X-21 | ds34usb endpoint walk: `bNumEndpoints == 0` makes `epCount = -1` and the do-while never terminates; no `bLength == 0` check anywhere | S | Low | STANDING | — |
| RE-X-22 | SMS lwIP `ip_frag`: reassembly bitmap is one byte short — a fragment ending exactly at `IP_REASS_BUFSIZE` writes out of bounds | S | Low | STANDING | — |
| RE-X-23 | Launchstation APA retains the SDK error-sector defects RiptOPL removed: NULL-deref, cache leak, and a write into the APA table sector from read paths | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Cross.md` supersede the filed ones. One sub-claim refuted: the claimed second copy in `iop/hdl_info/apa.c` does not contain the error-sector pair (grep = 0 hits; it is a different malloc-based parser) — fix scope is the single `ps2hdd_osd` copy. |
| RE-X-24 | Launchstation `hdd_fio.c`: u32 `sector + size` overflow passes the bounds check, and on-disk `nsub` is unbounded past the 64-entry subs array | S | Low | STANDING | Fix-scope extension (Stage B, Cross CAND-05): Folds into RE-X-24 — Launchstation `ioctl2Transfer` indexes `parts[arg->sub]` bounded only by unchecked on-disk `nsub` |
| RE-X-25 | Launchstation + POPSLoader atad: no LBA range check and no 4Kn refusal (RiptOPL-only guards) | S–M | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Cross.md` supersede the filed ones. |
| RE-X-26 | Tarball `bdmfs_fatfs` fs_driver: volume index is the raw ioman unit — cross-device filesystem misrouting that RiptOPL's copy fixed | M | Medium | REVISED | Narrowed scope: The tarball lacks transport-stable addressing only — `massN` identity follows connection order; within the tarball's own architecture (exactly one ioman driver named "mass", no `path` field, no typed drivers) no request is misrouted relative to the names the stack exposes, and RiptOPL itself preserves the same unit-as-index semantics for "mass". |
| RE-X-27 | SMS `ums_fat`: FAT chain walks never validate the cluster number; BPB FAT-size/count fields unvalidated (no sibling fix exists) | S | Low | STANDING | Fix-scope extension (Stage B, Cross CAND-04): Extension of RE-X-27 — SMS `ums_fat` `FATFS_Init` likewise never zero-checks `m_nResSectors` |
| RE-X-28 | Default POPSTARTER.ELF shipped by both repos is the DEBUG build | S | Low | STANDING | — |
| RE-X-29 | SMS ships every IRX twice: plain + xz with identical payloads | S | Low | REVISED | Narrowed scope: Each of 19 payloads is stored twice in different encodings by design of the compress/gate pipeline, not as dead weight — the EE build consumes only the `.xz` form, but the plain set is the regeneration source for `tools/compress_irx.py`, the landing form for module rebuild scripts, and a gate input, so the filed fix would break the documented workflow; the finding survives only as a repo-hygiene preference, not the filed duplication defect. |
| RE-X-30 | BDMAssault variant names overstate the binary count; RiptOPL's canonical provenance record omits the .udpfs pair | S | Low | STANDING-DRIFT | Mechanism stands; corrected citations/values in `Redo-VERIFY-Cross.md` supersede the filed ones. |
| RE-X-31 | RiptOPL `drvtif-ingame.irx` is a byte-identical second copy of `drvtif.irx` | S | Low | STANDING | — |

### New findings — Cross-repo (Stage C, from Stage B candidates)

| ID | Title | Status | Note |
|---|---|---|---|
| RE-X-32 | SMS `ip_frag` completeness loop never checks bitmap byte 89: a 64-byte hole passes as complete | NEW | Full finding in `Redo-NEW-FINDINGS.md` (evidence: `Redo-VERIFY-Cross.md`, CAND-03). |

## Appendix A — Candidate screening (all Stage B candidates)

Every candidate recorded in the six verify reports, classified exactly once: NEW = numbered as a new finding in `Redo-NEW-FINDINGS.md`; EXTENSION = recorded in the parent finding's row above; REJECTED = not numbered, reason stated.

### RiptOPL

| Candidate | Class | Parent / New ID | Reason |
|---|---|---|---|
| CAND-01 — do_bind RAW branch `raw_new()` unchecked (api_msg.c) | EXTENSION | RE-RIPTOPL-030 | Same function and same unchecked-allocation mechanism as RE-RIPTOPL-030, which files only the UDP (`udp_new()`) and TCP (`tcp_new()`) branches — the RAW branch is an additional uncovered instance its fix should cover. |
| CAND-02 — ps2ips do_send/do_sendto `sendlen - pkt->malign` underflow | EXTENSION | RE-RIPTOPL-013 | Same unvalidated `pkt->malign` field and same handler fix site as RE-RIPTOPL-013, but an additional consequence/site (the GetOtherData length) that RE-RIPTOPL-013's memcpy/offset account does not cover. |
| CAND-03 — ZSO `c_buff += b_size` advances by the unclamped index-derived size | EXTENSION | RE-RIPTOPL-011 | Same ZSO read loop and same untrusted block-size field as RE-RIPTOPL-011, but an additional unclamped use (pointer advance) beyond the decoder call RE-RIPTOPL-011 files. |
| CAND-04 — `icmp_time_exceeded` repeats RE-RIPTOPL-049's unchecked `pbuf_alloc` pattern | EXTENSION | RE-RIPTOPL-049 | Same unchecked-`pbuf_alloc` mechanism in the same file as RE-RIPTOPL-049, at an additional function/site RE-RIPTOPL-049 (icmp_dest_unreach only) does not cover. |
| CAND-05 — `recv_raw` shares `recv_udp`'s missing-free shape | EXTENSION | RE-RIPTOPL-052 | Same missing-free mechanism and same file as RE-RIPTOPL-052, at an additional callback (`recv_raw`) that RE-RIPTOPL-052 (`recv_udp` only) does not cover. |
| CAND-06 — `prepare_path` trailing-slash strip is dead code | NEW | RE-RIPTOPL-266 | Distinct functional mechanism not filed in the redo corpus: RE-RIPTOPL-037(a) filed the opposite claim at these lines (a dangerous walk before the buffer), which verification refuted — no redo finding files the never-strips defect. |
| CAND-07 — mmce `MMCE_CMD_SET_GAMEID` uses `arg` as a string with no NULL/arglen check | EXTENSION | RE-RIPTOPL-042 | Same devctl switch and same unchecked-`arg` mechanism as RE-RIPTOPL-042 — a fifth, uncounted site in its family (string argument rather than `*(u32*)arg`). |
| CAND-08 — `mmce_cmd_set_gameid` `strcpy` of a full game ID into a fixed 255-byte stack `wrbuf` after u8 length truncation | NEW | RE-RIPTOPL-267 | Distinct mechanism as verification states: RE-RIPTOPL-084 covers only this function's one trailing uninitialised byte and RE-RIPTOPL-085 covers filename-length truncation in mmce_fs.c — neither files a full-string stack overflow in mmce_cmds.c. |
| CAND-09 — OSDHistory victim scan: `LeastUsedRecordTimestamp` not reset when a strictly smaller `LaunchCount` is found | NEW | RE-RIPTOPL-268 | Distinct mechanism in the victim-selection scan, explicitly distinct from RE-RIPTOPL-093's (refuted) claim about the new entry's fields after takeover, and covered by no other redo finding. |
| CAND-10 — Third keyboard-path VLA, `src/ui/menusys.cpp:306` `char newName[nameLength]` | EXTENSION | RE-RIPTOPL-105 | Verify report states it extends RE-RIPTOPL-105: same caller-supplied-length VLA mechanism, at a third location RE-RIPTOPL-105 (gui.cpp/diaeditors.cpp only) does not cover. |
| CAND-11 — PC-tool `crctab[0x400]` oversize in iso2opl and opl2iso | EXTENSION | RE-RIPTOPL-104 | Same defect mechanism as RE-RIPTOPL-104 (which covers only src/platform/system.cpp); RE-RIPTOPL-127 covers these files' crc32 duplication but not the oversize/per-call rebuild. |
| CAND-12 — Broken `CRC7_MODE_RAM_TABLE` test also in `spi_sdcard_crc7.h` | EXTENSION | RE-RIPTOPL-180 | Verify report states it extends RE-RIPTOPL-180: same broken macro test, at the header location RE-RIPTOPL-180 (which cites only the .c) does not cover. |
| CAND-13 — Second broken `PACKET_TCODE` copy at bdmassault `iLink_internal.h:92` | EXTENSION | RE-RIPTOPL-183 | Verify report states it extends RE-RIPTOPL-183: identical macro/mechanism, at a second copy RE-RIPTOPL-183 (modules/ilink only) does not cover. |
| CAND-14 — Second dead `DeinitIEEE1394` copy in bdmassault `sbp2_driver.c` | EXTENSION | RE-RIPTOPL-184 | Verify report states it extends RE-RIPTOPL-184: same dead function/mechanism, at a second copy RE-RIPTOPL-184 (modules/ilink only) does not cover. |
| CAND-15 — Fix-completeness for RE-RIPTOPL-171: `test_smb_read_closed.py` hard-exits if `USE_CUSTOM_RECV` disappears | REJECTED | — | Not a defect: the test is an intentional guard whose message directs the updater, and the note is only a fix-completeness instruction for RE-RIPTOPL-171 — no standalone defect mechanism is filed. |
| CAND-16 — Guard gap wider than RE-RIPTOPL-194 states: EE `HttpStreamBegin` and `HttpStreamRead` also lack the init guard | EXTENSION | RE-RIPTOPL-194 | Same file and same missing-init-guard mechanism as RE-RIPTOPL-194, at two additional entry points RE-RIPTOPL-194 (HttpSendGetRequest only) does not cover. |
| CAND-17 — `pbuf_dechain` phantom declaration also an IOP import at `smstcpip.h:39-40` | REJECTED | — | Already fully covered by RE-RIPTOPL-051, which files exactly this declaration (smstcpip.h:37-42, `I_pbuf_dechain` as import 41) and prescribes deleting it — a duplicate, not an extension of RE-RIPTOPL-172's lwIP-header copy. |
| CAND-18 — `mmce_fs_ioctl2` returns 0 for every unknown command | EXTENSION | RE-RIPTOPL-201 | Same silent-success mechanism as RE-RIPTOPL-201, at a separate uncovered instance (ioctl2 slot :1213) that RE-RIPTOPL-201 (ioctl stub :402-405, slot :1194 only) does not cite. |
| CAND-19 — Same stale tar comment in `src/platform/tar.cpp:9` | EXTENSION | RE-RIPTOPL-255 | Same stale comment/mechanism as RE-RIPTOPL-255, at an additional location (tar.cpp) that RE-RIPTOPL-255 (tar.h:4-8 only) does not cover. |
| CAND-20 — RE-RIPTOPL-261's scratch-dir exclusion list duplicated verbatim at `Makefile:111` | EXTENSION | RE-RIPTOPL-261 | Same scratch-dir exclusion list/mechanism as RE-RIPTOPL-261, at an additional verbatim copy (Makefile) that RE-RIPTOPL-261 (assets.py only) does not cover. |
| CAND-21 — `test_ra_language_isolation.py`'s PyYAML exposure is live via ps2build/run_tests.sh | EXTENSION | RE-RIPTOPL-251 | Same no-install PyYAML mechanism as RE-RIPTOPL-251, as an additional live instance beyond its four listed suites (251's merged note mentions the file only as dormant/unwired, which verification refuted). |

### Launchstation

| Candidate | Class | Parent / New ID | Reason |
|---|---|---|---|
| CAND-01 — CAND-1 (xparam argc gap, low) | NEW | RE-LAUNCH-093 | Distinct dispatch fall-through in the same module as RE-LAUNCH-012 but a different mechanism and fix site (argument handling, not the DB-size macro); no redo finding covers it. |
| CAND-02 — CAND-2 (save-builder suffix read past a short field, speculative) | REJECTED | — | Speculative and heap-content dependent; the verifier states it would need a host harness with independently-set Misc fields to settle, so it is unverifiable as filed. |
| CAND-03 — CAND-3 (NetShareEnum string termination, unsettleable in-clone) | REJECTED | — | `ShareEntry_t` is defined outside this repo (PS2SDK headers), so termination cannot be settled from the clone — unverifiable as filed. |
| CAND-04 — C-V2-1 — usbmass_bd warmup divides by zero for sectorSize > 1,000,000 (same ingest value as RE-LAUNCH-016, different, earlier sink) | EXTENSION | RE-LAUNCH-016 | Same unvalidated ingest value and same ingest-whitelist fix site as RE-LAUNCH-016; an additional, earlier crash sink for that mechanism. |
| CAND-05 — C-V2-2 — ps2ips send path never validates pkt->length itself (gap in RE-LAUNCH-015's proposed fix) | EXTENSION | RE-LAUNCH-015 | Same functions and same entry-validation fix site as RE-LAUNCH-015; an additional unvalidated field instance the parent fix must also cover. |
| CAND-06 — C-V2-3 — smbd START copies are not guaranteed NUL-terminated | EXTENSION | RE-LAUNCH-020 | Same START handler and credential-copy fix site as RE-LAUNCH-020; an additional termination defect in the copies that handler already has to fix. |
| CAND-07 — CAND-V3-1 — APA chain walk can loop forever, not merely 10,000 times (strengthens RE-LAUNCH-033) | EXTENSION | RE-LAUNCH-033 | Same walk, same mechanism and same visited-set fix as RE-LAUNCH-033; it extends the parent's capped-cycle scope to the unbounded ordinary-header case (already folded into 033's drift). |
| CAND-08 — CAND-V3-2 — VMCMAN mcman_unit2card mask cannot produce slots 2–7 | REJECTED | — | Tentative as filed — whether the encoding is linear or deliberately sparse depends on the EE-side unit-assignment convention, which the verifier could not settle, so no defect is established. |
| CAND-09 — CAND-V3-3 — mmce_cmd_set_gameid dereferences a possibly-NULL devctl arg | EXTENSION | RE-LAUNCH-026 | Same function and same entry-validation fix site as RE-LAUNCH-026 (a NULL check belongs in the same top-of-function guard); an additional missing-validation instance there, distinct only in trigger. |
| CAND-10 — CANDIDATE V4-1 — ExecuteBrowserFrom has no callers | NEW | RE-LAUNCH-094 | Distinct caller-less function in a file/mechanism neither 043 (main() loop/main_menu.c) nor 044 (config/info/editor screens) covers. |
| CAND-11 — CANDIDATE V4-2 (minor) — tests/test_app_packages.py is invoked twice in one workflow run | NEW | RE-LAUNCH-095 | Duplicate invocation is a distinct defect from RE-LAUNCH-045 (missing suites) and RE-LAUNCH-046 (single-step masking); no redo finding states it. |
| CAND-12 — C1 — Orphan export table for the dead driver (companion to RE-LAUNCH-056) | EXTENSION | RE-LAUNCH-056 | Same dead-driver mechanism and same deletion as RE-LAUNCH-056; an additional orphaned location that belongs in its fix. |
| CAND-13 — C2 — RE-LAUNCH-058's deletion removes a test oracle and breaks a guard test (unmentioned cost) | REJECTED | — | Not a defect — it is an implementation cost of RE-LAUNCH-058's fix (two test edits the fix understates); the verifier confirms no production caller exists, so nothing here stands as its own finding. |
| CAND-14 — C3 — RE-LAUNCH-054 scope extension (same mechanism, listed for the fixer's checklist) | EXTENSION | RE-LAUNCH-054 | Same GIF-deletion mechanism as RE-LAUNCH-054; additional locations (manifest entries and a fourth link mention) its fix must include. |
| CAND-15 — V6-C1 (from RE-LAUNCH-068): src/filer.c (2,556 lines) is a second omission from architecture-maintenance.md's largest-files list | EXTENSION | RE-LAUNCH-068 | Same list, same omission mechanism and same fix sentence as RE-LAUNCH-068; a second omitted instance. |
| CAND-16 — V6-C2 (pair with RE-LAUNCH-070): the "Sony ADP" provenance wording also lives in code at src/embed_blobs.S:81 | EXTENSION | RE-LAUNCH-070 | Same false-provenance claim and same one-line correction as RE-LAUNCH-070; an additional location in code. |
| CAND-17 — CAND-V7-1 — Two divergent Python ADPCM decoders, one of which the finding (077) missed | NEW | RE-LAUNCH-096 | A host-side divergence between two in-repo decoders is a distinct mechanism from RE-LAUNCH-077 (Python decoder vs the absent shipped decoder); no redo finding covers it. |
| CAND-18 — CAND-V7-2 — The Misc enumeration has at least five hand-written sites, not three (extends 079) | EXTENSION | RE-LAUNCH-079 | Same Misc enumeration/lockstep mechanism as RE-LAUNCH-079; two additional hand-written instances (enumeration, not construction) beyond its three rebuild blocks. |
| CAND-19 — CAND-V7-3 — The ps2ips sync assertion that 073 proposes copying does not cover headers/cflags (extends 073) | EXTENSION | RE-LAUNCH-073 | Same dual-definition drift mechanism and same sync-assertion fix as RE-LAUNCH-073; it extends the parent's scope to the fields its proposed pattern leaves unchecked. |
| CAND-20 — CAND-V8-1 — Second (worse) strlen-in-loop site, refuting RE-LAUNCH-086's uniqueness claim | EXTENSION | RE-LAUNCH-086 | Same strlen-in-loop mechanism and fix as RE-LAUNCH-086; an additional, worse instance that also supplies 086's narrowed scope. |
| CAND-21 — CAND-V8-2 — Third commented WriteFont_C artefact not cited by RE-LAUNCH-088 | EXTENSION | RE-LAUNCH-088 | Same dead WriteFont_C artefact and same deletion as RE-LAUNCH-088; an additional location its fix must include. |
| CAND-22 — CAND-V8-3 — Same overwritten-tid cleanup flaw as RE-LAUNCH-091's defective fix, live in usb_mass | EXTENSION | RE-LAUNCH-091 | Same overwritten-tid / failed-start thread-leak mechanism as RE-LAUNCH-091, live in a second module (grep of the redo report for `usb_mass`: 0 hits as a finding location); an additional instance for the same preserve-the-tid fix. |

### POPSLoader

| Candidate | Class | Parent / New ID | Reason |
|---|---|---|---|
| CAND-01 — GPT partition-scan counter `int i` compared against `u32 partition_count` — signed-overflow UB for a crafted count ≥ 2³¹ | EXTENSION | RE-POPS-006 | Same GPT scan and same validation fix site as RE-POPS-006 (unvalidated `partition_count`); an additional overflow consequence of the same unvalidated field. |
| CAND-02 — Via-cache GPT entry read goes out of bounds: entries 4..31 are read past the 1,024-byte allocation because bd_cache.c:86 delivers only 512 B per read | EXTENSION | RE-POPS-001 | Same mechanism and fix site as RE-POPS-001 — GPT indexing a 512-sized buffer by the real sector size — manifesting on the via-cache path RE-POPS-001/004 split. |
| CAND-03 — `bdm_connect_bd` silently drops a device when all 20 mount slots are full (no error surfaced) | NEW | RE-POPS-116 | No redo finding covers mount-slot exhaustion or silent connect failure in `bdm_connect_bd`; distinct mechanism and site. |
| CAND-04 — `usb_mass_connect` also dereferences `config`/`interface` unchecked (extension of RE-POPS-007's site list) | EXTENSION | RE-POPS-007 | Explicitly an extension of RE-POPS-007's site list: same function, same unchecked-descriptor mechanism, additional pointers. |
| CAND-05 — 1-byte over-read at `staticDeviceDescEndPtr − 1` in the hcd scan (the surviving edge of RE-POPS-008) | REJECTED | — | Full duplicate of RE-POPS-008's surviving narrowed scope — same site, same mechanism, no additional location or instance. |
| CAND-06 — `USBMASS_IOCTL_GET_FRAGLIST` never validates `rdata` — NULL pointer + non-zero length = NULL-pointer write in `get_frag_list` (a fourth unchecked site for RE-POPS-012's fix) | EXTENSION | RE-POPS-012 | Explicitly a fourth unchecked site for RE-POPS-012's fix: same `get_frag_list`/ioctl mechanism, additional caller site. |
| CAND-07 — `get_fat`'s error sentinel 1 is a fixed point of the frag-list loop (strengthens RE-POPS-019's non-termination case) | EXTENSION | RE-POPS-019 | Same non-termination mechanism and bound-the-walk fix as RE-POPS-019; an additional, non-crafted trigger for the same loop. |
| CAND-08 — USB `readReport`/`usb_data_cb` ignore the transfer byte count in both USB copies, exactly as RE-POPS-009 documents for BT | EXTENSION | RE-POPS-009 | Same ignored-byte-count mechanism as RE-POPS-009, in the two USB copies RE-POPS-009 did not cover. |
| CAND-09 — `chrg_connect` dereferences `config->bConfigurationValue` unchecked in both BT copies | NEW | RE-POPS-117 | Distinct function and driver (`chrg_connect`, the DS34 charge driver) not mentioned anywhere in the redo corpus; not a site of RE-POPS-002's endpoint walk. |
| CAND-10 — USB EE `ds34usb_get_bdaddr`'s unconditional copy also fires on outright RPC failure (scoping note inside RE-POPS-035's mechanism) | EXTENSION | RE-POPS-035 | Same function, same unconditional-copy mechanism and same fix as RE-POPS-035; an additional failure trigger (outright RPC failure) at the filed site. |
| CAND-11 — `fntNewAtlas` (fntsys.cpp:428-437) + `atlasPlace` NULL-dereference chain — the caller-side half RE-POPS-030's fix omits | EXTENSION | RE-POPS-030 | Caller-side half of RE-POPS-030's own mechanism and fix, at additional locations the filed fix omits. |
| CAND-12 — `System.getMassRootByBackendName` (luasystem.cpp:2581) is itself a zero-caller RE-POPS-048-family binding — decide RE-POPS-063's fix jointly with keep-or-delete | REJECTED | — | Full duplicate: `System.getMassRootByBackendName` is already counted in RE-POPS-048's census; the candidate is a decision cross-reference for RE-POPS-063, not a distinct defect. |
| CAND-13 — A third inline VCD-strip copy exists at system.lua:9585 (`PLDR.HDD.GameEntryDisplayKey`) — extends RE-POPS-093's consolidation | EXTENSION | RE-POPS-093 | Explicitly extends RE-POPS-093's consolidation: same duplicated operation, an additional third instance. |
| CAND-14 — DECISIONS.md:300, STATE.md:128, docs/archive/LAUNCH_HYGIENE.md:150 describe `PLDR.GetBootKind` as a consumed public API (doc residue of RE-POPS-090) | NEW | RE-POPS-118 | Distinct doc-vs-code defect at doc locations no redo finding covers; RE-POPS-090 owns the dead code, not these false consumption claims. |
| CAND-15 — `print_uart` (luasystem.cpp:2660, registered via `lua_register` as a global) has zero Lua callers — a dead registration outside RE-POPS-048's `luaL_Reg` census scope | EXTENSION | RE-POPS-048 | Same dead-binding mechanism as RE-POPS-048 with an additional instance its census scope (luaL_Reg tables only) missed. |
| CAND-16 — Stale comment at ui.lua:2050 inside RE-POPS-094's duplicate cascade ("all other scenes use BKG.png") contradicts the cascade directly below it | NEW | RE-POPS-119 | A stale-comment defect at a location no redo finding covers; RE-POPS-094 owns the cascade's duplication, not this contradictory comment. |
| CAND-17 — RE-POPS-071 fix-completeness: ui.lua:2614's fallback `_NormalizeLayout` also accepts `"ABNT"` (and divergently `"ABC"`) — unreachable in shipped load order but absent from 071's removal list | EXTENSION | RE-POPS-071 | Explicitly RE-POPS-071 fix-completeness: same ABNT-removal fix, an additional accepting site the filed fix misses. |
| CAND-18 — Subject-report scope-census drift: "639 tracked files" vs `git ls-files` = **609** (639 is the on-disk count including 30 ignored `__pycache__/*.pyc`; the byte total matches the tracked set); Markdown count 163 vs the report's claimed 162 | REJECTED | — | Census correction of the subject report itself, not a code defect in the repo. |
| CAND-19 — COMPONENTS.md:400-405 presents the three dead RE-POPS-056 binaries as bin2c'd/live and the active mx4sio_bd as pinned from `iop/embed/PS2SDK_MX4SIO` — contradicted by Makefile:346-352 (a distinct limb from RE-POPS-112) | NEW | RE-POPS-120 | Distinct doc-vs-code defect at COMPONENTS.md:400-405, expressly a different limb from RE-POPS-112; RE-POPS-056 owns the dead binaries, not this live presentation of them. |
| CAND-20 — Byte-accounting caution: the `5ea4818b`/`70a369e4` duplicate bytes are counted in both RE-POPS-049 and RE-POPS-050, and the 167,700 B default≡DEBUG copy in both RE-POPS-040 and RE-POPS-050(c) — report-level savings roll-ups would double-count (see §2) | REJECTED | — | Pure accounting caution with no defect, as the verify report's own §2 frames it. |
| CAND-21 — The "Ember only" claim from RE-POPS-060 survives in two code comments: ui.lua:1067 (the `GILINK = 11` line) and system.lua:9161 (`InitILINKRoot` header) | EXTENSION | RE-POPS-060 | Same false claim as RE-POPS-060, at additional locations (code comments) beyond the seven doc passages filed. |

### SMS (Simple-Media-System)

| Candidate | Class | Parent / New ID | Reason |
|---|---|---|---|
| CAND-01 — DTS downmix row-index overflow | EXTENSION | RE-SMS-010 | Same downmix table, sink and index-check fix site as RE-SMS-010 — an additional unchecked index at that sink. |
| CAND-02 — UDFDecode read-side defects | EXTENSION | RE-SMS-017 | Same `UDFDecode` function and bounds fix as RE-SMS-017 — additional read-side instances at that site. |
| CAND-03 — WMA v1 exponent rows 1+ never filled | NEW | RE-SMS-145 | Distinct root cause and fix (rows never populated) from RE-SMS-024's zero-width-entry guard, despite sharing the underflow sink. |
| CAND-04 — FAT LFN negative offset | EXTENSION | RE-SMS-004 | Same LFN offset computation and clamp site as RE-SMS-004 — an additional negative-offset instance of that mechanism. |
| CAND-05 — ASFContext calloc unchecked | REJECTED | — | Full duplicate — the identical site is already cited in RE-SMS-013 (ASF context calloc + memset at :157-159). |
| CAND-06 — Dead defensive check in netconn_recv TCP arm | REJECTED | — | Not a defect — the redundant check causes no failure; it is dead code only. |
| CAND-07 — CDDA empty-field uninitialised name | NEW | RE-SMS-146 | Explicitly distinct from RE-SMS-062's unterminated-buffer `strlen` — a different trigger (empty field) and failure in the same function. |
| CAND-08 — pbuf_header REF/ROM mirror underflow | EXTENSION | RE-SMS-049 | Same `pbuf_header` underflow mechanism and fix site as RE-SMS-049 — the additional REF/ROM arm. |
| CAND-09 — lzma2_decode_size counter type mismatch | EXTENSION | RE-SMS-053 | Same `lzma2_decode_size` walk and bounds-hardening fix site as RE-SMS-053 — an additional defect instance in that walk. |
| CAND-10 — getpeername/getsockname NULL namelen deref | NEW | RE-SMS-147 | Stated independent of RE-SMS-077 — a different argument and sink from that finding's discarded-result / NULL-PCB mechanism. |
| CAND-11 — netconn_addr missing default | NEW | RE-SMS-148 | Distinct mechanism (unset outputs on a success return) from RE-SMS-077's NULL-PCB dereference in the same function. |
| CAND-12 — Packed SMSSMB.IRX segment is dead bytes in every build | NEW | RE-SMS-149 | This byte set is counted by neither RE-SMS-102 (source tree) nor RE-SMS-106 (UMS/USBD/SIO2MAN segments) — a distinct dead segment. |
| CAND-13 — Second orphan IRX pair of the RE-SMS-110 class | EXTENSION | RE-SMS-110 | Same orphan-blob mechanism and class as RE-SMS-110 — an additional instance. |
| CAND-14 — Explicit-format path discards the creator's return | NEW | RE-SMS-150 | Distinct from RE-SMS-101's bounds claim at the same line — a lost return value, not an unchecked index. |
| CAND-15 — FLAC include-guard typo | REJECTED | — | Not a defect — the guard is internally consistent and functions as written. |
| CAND-16 — MOV cursor cross-call invariant | EXTENSION | RE-SMS-140 | Same chunk-cursor reset mechanism and site as RE-SMS-140 — the additional cross-call framing of that invariant. |

### PS2-Servers

| Candidate | Class | Parent / New ID | Reason |
|---|---|---|---|
| CAND-01 — CAND-A1 — h2_tree_connect in the SMB1 file's SMB2 stub crashes on every call (struct.pack arity bug) | NEW | RE-SERV-217 | Distinct crash mechanism underlying RE-SERV-022's failed tree-connect limb; no existing finding covers the pack-arity bug (RE-SERV-022 claimed fake success, RE-SERV-023 covers SMB1 parameter blocks). |
| CAND-02 — CAND-D1 — Caduceus read_events unlock notices suppressed for owned-runtime state (at-vs-ago, second victim of RE-SERV-079) | EXTENSION | RE-SERV-079 | Same at-vs-ago schema-divergence mechanism and same note_unlock fix site as RE-SERV-079, in an additional consumer (caduceus) the original finding did not cite. |
| CAND-03 — CAND-D2 — best_lan_ip docstring contradicts the module contract | EXTENSION | RE-SERV-078 | Same best_lan_ip preference mechanism and fix site as RE-SERV-078, adding the docstring location that a code-only fix for that finding would leave behind. |
| CAND-04 — CAND-F1 — Direct script execution broken suite-wide by missing sys.path prologues | EXTENSION | RE-SERV-102 | Same direct-execution failure and same test-file prologue fix site as RE-SERV-102, with additional instances beyond its 8 files and a second root cause at the same site. |
| CAND-05 — CAND-F2 — NFS4 endless-empty-fragments test is timing-fragile by construction | NEW | RE-SERV-218 | Distinct test-fragility mechanism not covered by any redo finding; no existing finding addresses this test's fragment-count/timeout construction. |
| CAND-06 — CAND-H1 — h_trans2_find_first2 crashes on an empty directory | NEW | RE-SERV-219 | Distinct empty-directory crash mechanism; RE-SERV-180 covers the same handler only for its one-entry-per-reply inefficiency, and no finding covers the entries[0] IndexError. |
| CAND-07 — CAND-H2 — Same _last_disc getattr pattern in the base server | REJECTED | — | Not a defect on its own — the getattr default makes the pattern safe, per the verify report's own assessment. |
| CAND-08 — CAND-I1 — release.yml portable upload omits if-no-files-found entirely | EXTENSION | RE-SERV-213 | Same fail-soft portable-upload mechanism and same release.yml step/fix site as RE-SERV-213, adding the omitted-key instance adjacent to that finding. |

### Cross-repo

| Candidate | Class | Parent / New ID | Reason |
|---|---|---|---|
| CAND-01 — Python `_complete_bwrite` discards the `write()` return value and credits `expected_size` to `stats['bytes_written']` even on short delivery or short OS write | EXTENSION | RE-SERV-030 | Same `_complete_bwrite` fix site — RE-SERV-030 already files the unconditional `expected_size` crediting on short delivery; the candidate adds the discarded `write()` return / short-OS-write limb. |
| CAND-02 — Scope extension of RE-X-13 — same spaced `title.cfg` form in a Launchstation docs example | EXTENSION | RE-X-13 | Same wrong writer/form and same fix as RE-X-13; the verify report explicitly places it in RE-X-13's fix scope alongside `dash_apps.c` and the locking test, and no per-repo filing covers this docs instance. |
| CAND-03 — SMS `ip_frag` completeness loop never checks bitmap byte 89 (distinct from RE-X-22) | NEW | RE-X-32 | Distinct loop-bound mechanism (false completeness) from RE-X-22's bitmap sizing and from RE-SMS-016's IPH_LEN trust / bitmap-index OOB; grep of the per-repo redo reports found no filing of this completeness hole. |
| CAND-04 — Extension of RE-X-27 — SMS `ums_fat` `FATFS_Init` likewise never zero-checks `m_nResSectors` | EXTENSION | RE-X-27 | Same function, same zero-check fix, and same field family as RE-X-27; the verify report explicitly describes it as an extension of RE-X-27 and grep found no per-repo filing of `m_nResSectors`. |
| CAND-05 — Folds into RE-X-24 — Launchstation `ioctl2Transfer` indexes `parts[arg->sub]` bounded only by unchecked on-disk `nsub` | EXTENSION | RE-X-24 | Same root cause and same fix as RE-X-24 (refuse/clamp `nsub > APA_MAXSUB`); the verify report explicitly says it folds into RE-X-24. |
| CAND-06 — Shared defect, both trees — `fatfs_fs_driver_get_mounted_bd_from_index` bounds-checks with `>` instead of `>=` | REJECTED | — | Full duplicate — the same function, guard, and index-10 OOB at the same sites are already filed per-repo as RE-POPS-011 (tarball copies) and RE-RIPTOPL-065 (RiptOPL maintained copy). |

