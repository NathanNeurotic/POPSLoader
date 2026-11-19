# Round 3 — Section 01: `iop/smbd` + block-device IOP modules

**Repo / pin:** Launchstation, `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (verified `git rev-parse HEAD` at audit start and end; working tree clean throughout — read-only).
**Scope:** Task 1 (`iop/smbd` first-party code, libsmb2 patches, libsmb2 source inventory) and Task 4 (inventory + targeted Cat‑6 pass on RPC/devctl entry points of `iop/vmcman`, `iop/mmceman`, `iop/mx4sio_bd`, `iop/ata_bd`, `iop/usbmass_bd`).
**Confidence key:** **READ** = seen in code at the pin, line-cited. **INFERRED** = reasoned from filenames / upstream role / callers, not from reading that code (libsmb2 itself is absent in this clone — `.smbd-deps/` not present — and was **not** fetched, per instructions).
**Correction to the task brief (READ):** the `smbd` target at `ps2.yaml:295-363` lists **54** libsmb2 `lib/*.c` sources (lines 300–353), not 60, plus the 2 first-party sources. All counts below use 54.

---

## Task 1 — smbd

### 1.1 First-party inventory (READ)

| File | Lines | Role |
|---|---|---|
| `iop/smbd/smbd.c` | 340 | Platform half: replacement `malloc/free/calloc/realloc` over `AllocSysMemory`, iomanX/MCMAN file ops, server thread, `smbd:` device + devctl (`STATUS/STOP/START`) |
| `iop/smbd/smbd_fs.c` | 1016 | Protocol half: all `smb2_server_request_handlers` — authorize, tree connect, create/close/read/write, query-directory, query/set-info, rename |
| `iop/smbd/smbd.h` | 61 | Interface + limits: `SMBD_SHARES 2`, `SMBD_PATH_MAX 128`, `SMBD_NAME_MAX 64`, `SMBD_LEAF_MAX 31`, `SMBD_MAX_IO 65536`, `SMBD_MAX_CLIENTS 2` |
| `iop/smbd/config.h` | 16 | libsmb2 build config: `HAVE_*` for stdint/string/stdio/sys-types/errno; `NEED_RANDOM/SRANDOM/GETPID/GETLOGIN_R/WRITEV/READV/POLL/STRDUP` — i.e. declares what libsmb2's `compat.c` must supply on the IOP |
| `iop/smbd/imports.lst` (84), `irx_imports.h` (16), `linkfile` (155) | — | Build glue, not audited line-by-line (see Still Unread) |

Local history (`git log -- iop/smbd`, READ): only three commits, all 2026‑11‑11/12 — `1060b37` adds the server (#249/#350), `1683a16` moves shares/login into `LAUNCHSTATION.CNF` (#360), `9c1dda0` extends query-info coverage (#372). The module is **new, first-party, and fast-moving**; there is no long local delta against an older in-tree smbd to audit — the "delta" is exactly the two patch files below plus `config.h`.

### 1.2 The two libsmb2 patches — exactly what they do (READ, patch files)

| Patch | File touched (upstream) | Change | Kind |
|---|---|---|---|
| `iop/smbd/libsmb2-raw-query-info.patch` (14 lines) | `lib/smb2-cmd-query-info.c`, in `smb2_encode_query_info_reply` | One condition widened: when a query-info class has no encoder (`created_output_buffer_length == 0`), upstream copied the handler's raw `output_buffer` only `if (smb2->passthrough)`; patched to `if (smb2->passthrough \|\| rep->output_buffer_length)` — i.e. a non-zero handler-supplied buffer is now sent verbatim even in (server) non-passthrough mode | **Server behaviour — load-bearing.** `smbd_fs.c`'s raw classes (`SMB2_FILE_INTERNAL/EA/ID_INFORMATION`, FileStat/FileStatLx 68/70, encoded by `put_stat`/`put_le32` into `info.raw[96]`, `smbd_fs.c` query_info_cmd) have no libsmb2 encoder; without this patch those replies would be dropped/errored. Deleting the patch breaks Windows `stat`-class queries; it is not optional cleanup |
| `iop/smbd/libsmb2-session-key-leak.patch` (14 lines) | `lib/libsmb2.c`, in `smb2_session_setup_request_cb` | Adds `free(smb2->session_key); smb2->session_key = NULL;` immediately before each `ntlmssp_get_session_key(...)` fetch, so multi-round NTLMSSP session setup no longer leaks/overwrites-without-freeing the previous key allocation | **Leak fix only.** No wire behaviour, no auth-semantics change: the same key is fetched and used; only the previous allocation is released first. Especially material on the IOP, where `smbd.c`'s heap is `AllocSysMemory` with no compaction — a per-auth leak is permanent for the module's resident lifetime |

`config.h` (READ): no hidden behaviour; it is a capability declaration for `compat.c`. The only item worth noting is `NEED_GETLOGIN_R`/`NEED_GETPID`/`NEED_RANDOM` — compat shims a client library expects — consistent with §1.3's finding that much of the fetched library is client-shaped.

### 1.3 libsmb2 source inventory — all 54 sources in `ps2.yaml:300-353`

Classification basis: filenames + the calls/handlers visible in `smbd.c`/`smbd_fs.c` + the fetch script's note (`scripts/fetch_libsmb2.sh`: master pinned because "that master's server has `stop_requested`/`listener_ready`, which smbd needs" — READ). **Honesty note (per brief):** the target builds with `-ffunction-sections/-fdata-sections` and links `-Wl,--gc-sections` (`ps2.yaml`, smbd target `cflags`/`ldflags`, READ). Dead code below therefore costs **fetch time, build time, patch-rebase surface and audit surface — not shipped IRX bytes.** No ELF/IRX size saving is claimed for removing any row.

| # | Source | Class | Confidence / basis |
|---|---|---|---|
| 1 | `aes.c` | crypto/support | INFERRED — AES core for SMB3 signing/sealing |
| 2 | `aes_reference.c` | crypto/support — **probable duplicate of #1** | INFERRED — a second, reference AES implementation alongside `aes.c`; a server build needs at most one. Prime GC/deletion candidate (see R3A-06) |
| 3 | `aes128ccm.c` | crypto/support | INFERRED — AES-CCM for `smb3-seal` |
| 4 | `alloc.c` | support | INFERRED — libsmb2 allocation wrappers over `smbd.c`'s heap |
| 5 | `asn1-ber.c` | support (auth) | INFERRED — BER for SPNEGO/NTLMSSP tokens |
| 6 | `compat.c` | support | READ (role) — `config.h:1` states it supplies what the IOP lacks (`NEED_*`) |
| 7 | `errors.c` | server-core/support | INFERRED — status/error strings used by both halves |
| 8 | `hmac.c` | crypto/support | INFERRED |
| 9 | `hmac-md5.c` | crypto/support (NTLM) | INFERRED |
| 10 | `init.c` | support | INFERRED — library init |
| 11 | `libsmb2.c` | **server-core (mixed client+server monolith)** | READ (partial) — server symbols used at `smbd_fs.c:1001` (`smb2_serve_port`), `:998-1015` (`stop_requested`, `listener_ready`), session-setup callback is the leak-patch site. Cannot be dropped; its client half is inseparable at file granularity |
| 12 | `md4c.c` | crypto/support (NTLM MD4) | INFERRED |
| 13 | `md5.c` | crypto/support | INFERRED |
| 14 | `ntlmssp.c` | **server-core (auth)** | READ (role) — `authorize_user` (`smbd_fs.c`) + `smb2_set_password` delegate NTLM verification to it |
| 15 | `pdu.c` | server-core | INFERRED — PDU encode/decode used by every `smb2_cmd_*_reply_async` call in `smbd_fs.c` |
| 16 | `quic.c` | **client-only transport** | INFERRED — SMB-over-QUIC client transport; smbd is a TCP/445 listener (`socket.c`, `smbd_serve(445)`). A memory-card server cannot be a QUIC client, and nothing in `smbd_fs.c` references QUIC (READ: no references) |
| 17 | `smbdirect.c` | **client-only transport** | INFERRED — SMB Direct (RDMA) client transport; no RDMA hardware/path on PS2, no references in first-party code (READ: none) |
| 18 | `sha1.c` | crypto/support | INFERRED |
| 19 | `sha224-256.c` | crypto/support (signing) | INFERRED |
| 20 | `sha384-512.c` | crypto/support | INFERRED |
| 21 | `smb2-cmd-cancel.c` | server-core | READ (role) — `cancel_cmd` handler exists in `smbd_fs.c` |
| 22 | `smb2-cmd-close.c` | server-core | READ — `close_cmd` |
| 23 | `smb2-cmd-create.c` | server-core | READ — `create_cmd` |
| 24 | `smb2-cmd-echo.c` | server-core | READ — `echo_cmd` |
| 25 | `smb2-cmd-error.c` | server-core | READ — `reply()` uses `smb2_cmd_error_reply_async` |
| 26 | `smb2-cmd-flush.c` | server-core | READ — `flush_cmd` |
| 27 | `smb2-cmd-ioctl.c` | server-core | READ — `ioctl_cmd` (replies NOT_SUPPORTED, but the command must be parsed/answered) |
| 28 | `smb2-cmd-lock.c` | server-core | READ — `lock_cmd` |
| 29 | `smb2-cmd-logoff.c` | server-core | READ — `logoff_cmd` |
| 30 | `smb2-cmd-negotiate.c` | server-core | INFERRED — no local handler; negotiate is library-side and mandatory for any session |
| 31 | `smb2-cmd-notify-change.c` | server-core | READ — `change_notify_cmd` |
| 32 | `smb2-cmd-oplock-break.c` | server-core/support | INFERRED — `create_cmd` always returns `oplock_level = 0`, but the break PDU type must still exist in the dispatcher |
| 33 | `smb2-cmd-query-directory.c` | server-core | READ — `query_directory_cmd` |
| 34 | `smb2-cmd-query-info.c` | server-core | READ — `query_info_cmd`; also the raw-query-info patch site |
| 35 | `smb2-cmd-read.c` | server-core | READ — `read_cmd` |
| 36 | `smb2-cmd-session-setup.c` | server-core (auth) | READ (role) — pairs with `authorize_user`; leak patch is in its callback path |
| 37 | `smb2-cmd-set-info.c` | server-core | READ — `set_info_cmd` / `rename_handle` |
| 38 | `smb2-cmd-tree-connect.c` | server-core | READ — `tree_connect_cmd` (custom async reply) |
| 39 | `smb2-cmd-tree-disconnect.c` | server-core | READ — `tree_disconnect_cmd` |
| 40 | `smb2-cmd-write.c` | server-core | READ — `write_cmd` |
| 41 | `smb2-data-file-info.c` | server-core | INFERRED — encoders for the `info.*` structs filled in `query_info_cmd`/`query_directory_cmd` |
| 42 | `smb2-data-filesystem-info.c` | server-core | INFERRED — encoders for the FS classes in `query_info_cmd` |
| 43 | `smb2-data-security-descriptor.c` | support — **probably unused by this server** | INFERRED — `smbd_fs.c` implements no security-info query/set class (READ: `query_info_cmd` handles only FILE and FILESYSTEM types, `set_info_cmd` only FILE); SD encode/decode is a client-ACL need |
| 44 | `smb2-data-reparse-point.c` | support — **probably unused by this server** | INFERRED — no reparse handling in any local handler (READ: none); `put_stat` explicitly leaves ReparseTag 0 |
| 45 | `smb2-share-enum.c` | **client-only** | INFERRED — SRVSVC share-enumeration is a client RPC; shares here are hard-coded (`share_names[2] = {"mc0","mc1"}` in `smbd_fs.c`, READ) and answered by `tree_connect_cmd`, never enumerated |
| 46 | `smb3-seal.c` | server-core (crypto) | INFERRED — SMB3 encryption; server offers `SMB2_VERSION_ANY` (2.0.2–3.1.1, `smbd_fs.c` `on_new_client`) |
| 47 | `smb2-signing.c` | server-core | READ (role) — `server.signing_enabled = 1` in `smbd_serve` |
| 48 | `socket.c` | server-core | INFERRED — the TCP listener/connect socket layer; the server path needs its listener half |
| 49 | `spnego-wrapper.c` | server-core (auth) | INFERRED — SPNEGO wrapping around NTLMSSP in session setup |
| 50 | `sync.c` | **client-only** | INFERRED — libsmb2's synchronous client API (`smb2_open/read/…`-style wrappers); the server is entirely async/handler-driven and no sync API symbol is referenced in first-party code (READ: none) |
| 51 | `timestamps.c` | support | INFERRED — `smb2_timeval_to_win` conversions used throughout `smbd_fs.c` (READ: called) |
| 52 | `unicode.c` | support | READ — `smb2_utf16_to_utf8` called in `rename_handle` |
| 53 | `usha.c` | crypto/support | INFERRED — unified SHA glue over #18–20 |

**Tally (READ arithmetic on the table above):** server-core 27 · crypto/support & general support 22 · client-only 4 (`quic`, `smbdirect`, `smb2-share-enum`, `sync`) · probably-unused-by-this-server support 2 (`smb2-data-security-descriptor`, `smb2-data-reparse-point`) · probable duplicate 1 (`aes_reference`, counted inside support above — overlaps, hence 27+22+4+2 = 55 rows counting `aes_reference` once in support and once as duplicate-flagged; unique files = 54).

### 1.4 Findings — smbd

#### R3A-01 — SMB READ/WRITE offsets are truncated to 32 bits before reaching the card
- **Category:** 6 (network-facing, caller-supplied values) — also 2 (correctness)
- **Locations:** `iop/smbd/smbd.c:167-177` (`smbd_pread`/`smbd_pwrite`); callers `iop/smbd/smbd_fs.c` `read_cmd`/`write_cmd` pass `req->offset` (a 64-bit SMB2 field) straight through
- **Problem:** Both helpers do `iomanX_lseek(fd, (int)off, FIO_SEEK_SET)`. An authenticated remote client that sends offset `0x1_0000_0000` (or any value ≥ 2³¹) does not get an out-of-range error — the offset silently wraps ((int) cast; ≥2³¹ also becomes a *negative* seek). A WRITE at 4 GiB therefore lands at offset 0 and overwrites the start of the file; a READ returns the wrong bytes. Memory cards are far smaller than 2 GiB, so **every** legitimate offset fits in a signed 32-bit seek — which means every offset that truncates is by definition bogus and should have been refused, not wrapped. **READ** (the cast, and that no range check exists in either handler); impact scenario INFERRED from SMB2 offset semantics.
- **Fix (LESS):** One guard, no new machinery: in `smbd_pread`/`smbd_pwrite`, `if (off > INT32_MAX) return -EINVAL;` before the cast — two lines total, in the platform file where the truncation lives.
- **Benefit:** Remote write can no longer be redirected onto live file data by offset arithmetic. **Effort:** XS. **Risk:** None for legitimate traffic (no PS2 memory-card file can be ≥2 GiB). **Confidence:** High (code READ; no hardware needed to validate the arithmetic).

#### R3A-02 — `write_cmd` never caps the transfer length; `read_cmd` does
- **Category:** 6 / 2
- **Locations:** `iop/smbd/smbd_fs.c` `read_cmd` (caps: `if (len > SMBD_MAX_IO) len = SMBD_MAX_IO;`) vs `write_cmd` (no cap; `smbd_pwrite(card_fd, req->buf, (int)req->length, req->offset)`)
- **Problem:** The read path explicitly defends itself against an over-large `req->length`; the write path casts the same kind of field to `int` and hands it to iomanX. If libsmb2's PDU layer enforces the negotiated `server.max_write_size = SMBD_MAX_IO` (`smbd_serve`) on inbound writes, this is unreachable — but that enforcement is **INFERRED, not READ** (libsmb2 absent), and the asymmetry says the author did not rely on it for reads. A `(int)` cast of a length > INT_MAX would additionally go negative into `iomanX_write`.
- **Fix (LESS):** Mirror the read line in `write_cmd`: reject (not clamp — a truncated write corrupts silently) with `SMB2_STATUS_INVALID_PARAMETER` when `req->length > SMBD_MAX_IO`. One `if`, deleting the asymmetry.
- **Benefit:** The 64 KiB bound the server advertises becomes a bound the server enforces, on both directions. **Effort:** XS. **Risk:** Low; conforming clients already respect the negotiated maximum. **Confidence:** Medium — code asymmetry READ, exploitability INFERRED pending a libsmb2 read (see Still Unread).

#### R3A-03 — `SMBD_DEVCTL_START` can read past the caller's argument buffer for the password
- **Category:** 6 (caller-supplied length/contents at a devctl entry point)
- **Locations:** `iop/smbd/smbd.c:278-289` (`dev_devctl`, case `SMBD_DEVCTL_START`)
- **Problem:** Validation is only `arglen > 2 && ((char *)arg)[arglen - 1] == '\0'`. The code then does `strncpy(password, (char *)arg + strlen(arg) + 1, …)`. For a well-formed `"USER\0PASSWORD\0"` that is fine, and the one in-tree EE caller always sends exactly that (`src/init.c:2790-2793`, READ). But an arg consisting of a **single** string (`"USER\0"`, arglen 5) passes both checks, and `strlen(arg)+1 == arglen`, so the password `strncpy` starts reading **one byte past the caller's buffer** and keeps reading IOP memory until it happens on a NUL or exhausts 31 bytes — installing heap/stack residue as the server password. There is no check that a second string actually exists inside `arglen`. (The `user` copy itself is bounded by `strncpy(…, sizeof(user)-1)`; the stale-byte-31 concern is neutralised today because byte 31 is never written by either copy site — noted, not counted.)
- **Fix (LESS):** Add the missing existence check to the existing condition — `strlen(arg) + 1 < arglen` — one clause, no new code paths.
- **Benefit:** Closes an out-of-bounds read at the module's only credential-taking entry point. **Effort:** XS. **Risk:** None; the in-tree caller is well-formed. **Confidence:** High on the code path (READ); memory consequence INFERRED (IOP has no MMU isolation between modules, so the realistic outcome is a garbage password, not a fault).

#### R3A-04 — The SMB server ships with a known, published default login
- **Category:** 6 (auth handling)
- **Locations:** `iop/smbd/smbd.c:28` (`static char user[32] = "ps2", password[32] = "ps2";`); EE-side defaults `src/config.c:833-834` (same values written when no config exists); the values are also printed in the project's own docs/comments (`include/launchelf.h:338`)
- **Problem:** The deliberate, documented default credential pair for a network file server that exposes **writable** memory-card shares on TCP/445. The surrounding auth posture is otherwise sound (READ: `server.allow_anonymous = 0`, `signing_enabled = 1`, `authorize_user` rejects any username other than the configured one — all in `smbd_fs.c`), and the login is shown on the console screen and is user-changeable in Settings — so this is a known-tradeoff finding, not a hidden hole. Any LAN peer who has read the public source knows the first-run login.
- **Fix (LESS):** Do **not** add a credential generator or a setup wizard. The smallest honest change is deletion of the fallback's *silence*: keep the defaults for zero-config usability, but surface "server is using the default login" in the existing server status line (the screen already displays the login). If the maintainer prefers, deleting the compiled-in defaults in `smbd.c:28` (leaving config-supplied values as the only source) is a 1-line alternative — but note `_start`'s `argc > 2` path and `SMBD_DEVCTL_START` are the only other suppliers, so a module loaded with neither would then serve with empty credentials and `authorize_user` would reject everything: fail-closed, arguably the correct default.
- **Benefit:** First-run exposure becomes visible / fail-closed instead of silent. **Effort:** XS–S. **Risk:** Zero-config first use gets one extra screen of friction if the fail-closed variant is chosen. **Confidence:** High (defaults READ at both layers); LAN-threat weighting is the maintainer's call.

#### R3A-05 — smbd's replacement `calloc`/`malloc` do not check size arithmetic
- **Category:** 6 / 5 (robustness of the heap every libsmb2 allocation flows through)
- **Locations:** `iop/smbd/smbd.c:38-66` (`malloc`: `AllocSysMemory(ALLOC_FIRST, size + 8, NULL)` with `int size`; `calloc`: `malloc(n * size)` then `memset(p, 0, n * size)`)
- **Problem:** These functions replace the allocator for the **entire IRX, libsmb2 included**, i.e. for allocations whose sizes are influenced by remote PDU length fields. Neither checks its arithmetic: `size + 8` wraps for `size` near `INT_MAX`, and `calloc`'s `n * size` (computed in `size_t`, then narrowed into `malloc`'s `int` parameter) can wrap to a small allocation that the subsequent `memset(p, 0, n * size)` — recomputed at full `size_t` width — then overruns. Whether a remote-reachable libsmb2 call site actually feeds attacker-sized `n`/`size` into `calloc` is **INFERRED** (libsmb2 absent); the defect in the local code is READ.
- **Fix (LESS):** Two guards in one place: in `calloc`, `if (size && n > SIZE_MAX/size) return NULL;`; in `malloc`, reject `size < 0 || size > INT_MAX-8` (or type the parameter `size_t` and check once). ~3 lines, no new abstractions.
- **Benefit:** The single choke point for all server allocations stops being an overflow amplifier. **Effort:** XS. **Risk:** A wrapped request now returns NULL, which libsmb2 already handles (every handler in `smbd_fs.c` checks allocation failure). **Confidence:** Medium (local defect READ; remote reachability INFERRED).

#### R3A-06 — Four client-only libsmb2 files (plus one duplicate and two unused data files) are fetched and compiled for a server-only module
- **Category:** 1 (LESS NOT MORE — dead vendored weight)
- **Locations:** `ps2.yaml:315-316` (`quic.c`, `smbdirect.c`), `:344` (`smb2-share-enum.c`), `:349` (`sync.c`); also `:301` (`aes_reference.c`, duplicate of `:300 aes.c`), `:342-343` (`smb2-data-security-descriptor.c`, `smb2-data-reparse-point.c`); classifications and bases in §1.3
- **Problem:** libsmb2 is primarily a **client** library. smbd uses only its server half over plain TCP/445, yet the target compiles the QUIC and SMB-Direct client transports, the synchronous client API, and the share-enumeration client, plus a second (reference) AES implementation and two data encoders no local handler exercises. None of these symbols is referenced by `smbd.c`/`smbd_fs.c` (READ: grep of both first-party files). Because of `--gc-sections` they (mostly) cost **no shipped bytes** — the cost is real but different: every upstream-master re-pin must compile them on the IOP toolchain, every patch rebase and audit pass must read past them, and each is latent code one accidental reference away from being linked in.
- **Fix (LESS — pure deletion):** Drop the seven lines from the `smbd` source list in `ps2.yaml`. If an upstream file later proves necessary, the build fails loudly at link time and the line goes back — the fetch script and pin do not change. Verify with one smbd build + the existing `tests/smbd_live` host run.
- **Benefit:** −7 of 54 vendored compilation units (−13% of the fetched build/audit surface) with, by the GC argument, zero expected change to the shipped IRX. **Effort:** S (one build to confirm no hidden reference — e.g. `init.c`/`libsmb2.c` internally calling a `sync.c` or QUIC symbol would surface immediately as an undefined symbol). **Risk:** Low and self-revealing at link time; that link check is exactly the verification step and must not be skipped. **Confidence:** Medium-high — non-reference from first-party code is READ; intra-libsmb2 references are INFERRED-absent and can only be settled by the link test.

### 1.5 smbd — checked and clean (dissolved candidates)

- **Path traversal (READ, clean):** `make_path` (`smbd_fs.c`) rejects `..` components and any component containing `:`, skips `.`/empty components, strips leading separators, and checks `n + 1 + len >= SMBD_PATH_MAX` **before** each `memcpy`. A request cannot leave its share root by construction.
- **Tree connect (READ, clean):** `tree_connect_cmd` truncates the share name into `char name[8]`, but acceptance requires `len == 3 && ieq(name, share_names[i])` on the **untruncated** length — truncation cannot be used to alias a longer name onto `mc0`/`mc1`.
- **Rename (READ, clean):** `rename_handle` validates `buffer_length ≥ 20`, `FileNameLength ≤ len-20` and even, allocates `n+2` before `memcpy`; refuses root renames, cross-folder renames (same-prefix + leaf-only via `SMBD_LEAF_MAX` check), in-use targets, and non-empty semantics; the `SMBD-OLD.TMP` aside-buffer arithmetic `(b - to) + sizeof("/SMBD-OLD.TMP") > sizeof(aside)` is exact (allows exactly 128 including NUL). `smbd_rename`'s `strcpy(info.EntryName, leaf)` (`smbd.c:216`) is safe because the leaf is pre-checked ≤31 and `EntryName` is `char[32]` (`iop/vmcman/include/mcman.h:32`, READ).
- **Set-info lengths (READ, clean):** disposition checks `buffer_length < 1`; end-of-file checks `< 8`; both before dereferencing `buf`.
- **Query-info raw classes (READ, clean):** fixed-size raw classes are refused with `STATUS_INFO_LENGTH_MISMATCH` when `output_buffer_length` is too small, rather than truncated.
- **Handle table (READ, clean):** `lookup` validates index, `used`, **owner == requesting context**, and generation — one client cannot address another's handle, including via the all-ones compound-request id (the `last_create` shortcut still passes through the owner check).
- **Write-on-read-only-handle (dissolved, READ+INFERRED):** `write_cmd` does not itself test `handles[i].write`, but the single cached card fd is (re)opened by `card_fd_of` with exactly that handle's write flag, so a read-only handle's fd is `FIO_O_RDONLY` and the write fails at the iomanX/MCMAN layer. Defence exists, one layer down.
- **Auth surface (READ, clean apart from R3A-04):** no anonymous/guest (`allow_anonymous = 0`), signing enabled, username equality is case-insensitive but length-exact in effect (`ieq` returns true only when both strings end together — walked through prefix cases), `SMBD_MAX_CLIENTS 2` enforced in `on_new_client` with the `destruction_event` decrement matching the refused-client path by design (commented in code).
- **`smbd_share_root` ignoring `max` (dissolved):** `strcpy(out, "mc0:"/"mc1:")` with `(void)max` (`smbd.c`) looks like a footgun, but the only caller passes `SMBD_PATH_MAX` buffers and a share already range-checked to 0/1 — 5 bytes into 128. API smell, not a defect at the pin.
- **`match()` wildcard recursion (dissolved as bounded):** recursion depth is bounded by the number of `*` in the pattern and the haystack is a ≤31-byte card filename; worst case is wasted cycles on a 16 KiB server-thread stack, not overflow at realistic pattern lengths. Not counted.

---

## Task 4 — block-device / card IOP modules

### 4.0 Inventory summary (all READ from tree + `ps2.yaml` + README/ORIGIN/git log)

| Module | Files (.c/.h) | Lines | Origin | Built as |
|---|---|---|---|---|
| `iop/vmcman` | 12 files total in dir (8 .c/.h audited + README, exports/imports) | 9,775 | **Vendored PS2SDK** `iop/memorycard/mcman` @ `ff7c5f93763d90c8b10bc97fbce5d25939ed94fb` (`README.md`, READ) + local VMC fixes (geometry validation, mounted-state preservation, diagnostics, PS1-card re-read from saildot4k fork 9372a47) | **Two** targets from the same sources: `vmcman` (`BUILDING_VMCMAN`, adds `mciomanx_backing.c`) and `mcman_physical` (SDK flags), `ps2.yaml:119-151` |
| `iop/mmceman` | 20 | 4,043 | **Local/fork MMCE driver** (MMCE team upstream + heavy local hardening history in git log: wire-path guards, handle-slot, rename, boot-card devctls) | `mmceman` target uses only **6 of 8** .c files (`ps2.yaml:153-169`) — see R3A-10 |
| `iop/mx4sio_bd` | 19 | 2,715 | **Vendored PS2SDK** @ `2c670453…` via **RiptOPL's copy** ("taken unchanged from NathanNeurotic/RiptOPL `modules/mx4sio_bd`", `ORIGIN.md`, READ) + ps2sdk PR #936 retry fixes, PR #959 unaligned-buffer port, local ISR/data-integrity fixes | `mx4sio_bd_fork`, embedded under the SDK name, `ps2.yaml:174-187` |
| `iop/ata_bd` | 5 | 1,750 | **Vendored PS2SDK atad** (single `ps2atad.c`, 1,581 lines; header `atad.h` declares the sceAta export surface). Git log: untouched since the initial commit — no local delta at all | `ata_bd` with `ATA_ENABLE_BDM=1` (== upstream `ata_bd.irx`), `ps2.yaml:395-402` |
| `iop/usbmass_bd` | 9 | 1,481 | **Vendored ps2build/sdk-core** `usbmass_bd` tag `v2026.11.10` (`a3e4956`) == ps2sdk @ `0c36f32` (`ORIGIN.md`, READ) + 11 enumerated local two-drive/startup fixes | `usbmass_bd_fork`, embedded under the SDK name, `ps2.yaml:190-197` |

Entry-point map (the Cat-6 surface Task 4 asked for, READ): `vmcman` — iomanX `mc_devctl`/`mc_ioctl`/`mc_ioctl2` + the mcman library export table (no SIF RPC server of its own). `mmceman` — iomanX `mmce_fs_devctl`/`mmce_fs_ioctl`/`mmce_fs_ioctl2`. `mx4sio_bd`, `ata_bd`, `usbmass_bd` — **no devctl/RPC handler at all**; their caller surface is the BDM `block_device` callbacks (`read/write/flush/stop` with `sector`/`count` supplied by the BDM layer) plus, for `ata_bd`, the sceAta library exports to other IOP modules. Findings and dissolutions below follow that map.

### 4.1 Findings — block-device modules

#### R3A-07 — mmceman devctl dereferences `arg` as `u32` with no NULL/arglen check — in the same switch that already contains the correct pattern
- **Category:** 6
- **Locations:** `iop/mmceman/src/mmce_fs.c:1340-1341` (`MMCE_CMD_SET_CARD`), `:1353-1354` (`MMCE_CMD_SET_CHANNEL`), `:1394-1395` (`MMCE_SETTINGS_ACK_WAIT_CYCLES`), `:1399-1400` (`MMCE_SETTINGS_SET_ALARMS`) — all `args = *(u32*)arg;` — vs `:1377-1392` (`MMCE_CMD_SET_CARD_CHANNEL`), which checks `arg == NULL || arglen < 5` and reads bytes individually
- **Problem:** Four devctl commands read four bytes through `arg` unconditionally. A devctl issued with `arg == NULL` or `arglen < 4` (any EE-side caller bug, or any future caller that treats these like the no-arg commands around them — `PING`/`GET_STATUS` in the same switch take no arg at all) dereferences a null/wild pointer on the IOP. The file itself proves the guard is the house style: the newest command in the same function has it; the older four never got it.
- **Fix (LESS):** Apply the sibling's existing check to the four cases — one shared `if (arg == NULL || arglen < 4) { res = -1; break; }` shape, copied, not abstracted.
- **Benefit:** One malformed devctl stops being an IOP crash. **Effort:** XS. **Risk:** None — in-tree EE callers pass a real `u32`. **Confidence:** High (READ; the contrast with `:1377` is in the same function).

#### R3A-08 — mmceman `GET_GAMEID`: unbounded `strcpy` of a firmware-supplied string into the caller's buffer, whose length the handler never receives
- **Category:** 6 (host/device-supplied length at an entry point)
- **Locations:** `iop/mmceman/src/mmce_fs.c:1360-1361` (`res = mmce_cmd_get_gameid(buf);` — `buflen` not passed); `iop/mmceman/src/mmce_cmds.c:195-216` (`rdbuf[0xFF]` fixed 255-byte packet; `char *str = &rdbuf[0x4]; strcpy(ptr, str);`)
- **Problem:** The game ID is copied out of the card firmware's reply packet with `strcpy`. Nothing guarantees the firmware's string is NUL-terminated within the 251 bytes available after the 4-byte header: a malformed/malicious/compromised MMCE device (the string's source is removable hardware) that returns 251 non-NUL bytes makes `strcpy` read past the stack `rdbuf` and write past the EE caller's `buf` — whose size the IOP side cannot even check, because the devctl wrapper discards `buflen` instead of passing it. No in-tree EE caller for `GET_GAMEID` was found (grep, READ) — the only in-tree game-ID flow is `SET_GAMEID` — so this is a latent trap armed for the first caller who allocates a "reasonable" small buffer.
- **Fix (LESS):** Bound the copy by both ends: pass `buflen` through (one parameter), copy with `strncpy`-style bound `min(buflen-1, sizeof(rdbuf)-4)` and force termination — or, smaller still and matching the protocol's fixed packet, reject a reply whose bytes `[4..254]` contain no NUL. Either is a few lines in one function.
- **Benefit:** Removable-hardware input stops being a memory-corruption primitive. **Effort:** S. **Risk:** A firmware returning an unterminated ID now gets an error instead of a corrupt copy — strictly better. **Confidence:** High on the unbounded copy (READ); device-malice scenario INFERRED (accidental unterminated replies suffice — malice is not required).

#### R3A-09 — mmceman `SET_GAMEID`: unbounded `strcpy` into a 255-byte stack buffer, length pre-truncated through `u8`
- **Category:** 6
- **Locations:** `iop/mmceman/src/mmce_fs.c:1364-1366` (`char *str = (char*)arg; mmce_cmd_set_gameid(str)` — `arglen` ignored); `iop/mmceman/src/mmce_cmds.c:226-241` (`u8 len = strlen(ptr) + 1; u8 wrbuf[0xFF]; … strcpy(&wrbuf[0x4], ptr); mmce_sio2_tx_rx_pio(len + 5, …)`)
- **Problem:** The EE-supplied string is copied into `wrbuf[255]` at offset 4 with no length test: any string longer than 251 bytes overflows the stack buffer before the send length is even computed. The `u8 len` makes it worse, not better — for a 255+-byte string the declared wire length wraps while the copy does not. The one in-tree caller is safe by construction (`src/neutrino_gameid.c:248` passes a validated ID of exactly `NEUTRINO_GAME_ID_SIZE` = 12 bytes incl. NUL, `include/neutrino_gameid.h:6`, READ) — but, as in R3A-07, the IOP handler enforces nothing itself.
- **Fix (LESS):** One guard at the top of `mmce_cmd_set_gameid`: `size_t len = strlen(ptr) + 1; if (len > 0xFF - 4) return -1;` (and widen `len` off `u8`). Deletes both the overflow and the wrap in a single check.
- **Benefit:** Closes a stack overflow at a devctl entry point. **Effort:** XS. **Risk:** None for the real caller (12-byte IDs). **Confidence:** High (READ).

#### R3A-10 — mmceman ships two complete source files that no target builds (581 lines, incl. a second IRX module and a second SIO2 implementation)
- **Category:** 1 (LESS NOT MORE — dead code in tree)
- **Locations:** `iop/mmceman/src/mmcedrv.c` (413 lines; its own `IRX_ID("mmcedrv", 0, 1)` and `_exp_mmcedrv` export table) and `iop/mmceman/src/mmceigr.c` (168 lines; a self-contained SIO2 tx/rx implementation duplicating `mmce_sio2.c`'s role); the `mmceman` target compiles only `ioplib.c, sio2man_hook.c, mmce_sio2.c, mmce_cmds.c, mmce_fs.c, mmceman.c` (`ps2.yaml:155-162`, READ). Repo-wide grep for `mmcedrv`/`mmceigr` outside the files themselves and `.git` returns nothing (READ) — no other target, Makefile, or doc references them
- **Problem:** 581 lines — 14% of the module's tree — are unbuilt, unreferenced, and (for `mmceigr.c`) a *parallel implementation* of the module's most delicate part (SIO2 transfers). They still get read in every audit, still match every grep, and still look like live code to the next editor, who may patch the dead copy of a wire path and believe the fix shipped — precisely the failure mode this module's own git history (multiple "guard the wire paths" fixes) shows is expensive here.
- **Fix (LESS — pure deletion):** Delete both files (and `mmcedrv_config.h` if it serves nothing else — it is included only by `mmcedrv.c`, READ by grep). Git history preserves them if the standalone `mmcedrv` module is ever wanted again.
- **Benefit:** One SIO2 implementation, one mmceman module; −581 lines of audit/grep surface. **Effort:** XS. **Risk:** Near zero (nothing builds them; the deletion is the test — a full build either passes unchanged or names the hidden reference). **Confidence:** High (READ: target list + repo grep).

#### R3A-11 — vmcman backing validator is off by one: `slot > MCMAN_MAXSLOT` admits `slot == MCMAN_MAXSLOT`, one entry past the array
- **Category:** 6 / 2 (latent)
- **Locations:** `iop/vmcman/src/mciomanx_backing.c:46` (`if (slot > MCMAN_MAXSLOT) return -EOVERFLOW;` — also no `slot < 0` check) with the array at `:26` (`static vmc_cardinfo_t mcman_vmc_cardinfo[MCMAN_MAXSLOT];`), `MCMAN_MAXSLOT` = 10 in the VMCMAN build (`iop/vmcman/src/mcman-internal.h:106-108`)
- **Problem:** Every backing operation (mount/umount/getcardspec/erase/read/write) funnels through this validator, and it lets index 10 through to `&mcman_vmc_cardinfo[10]` — one struct past the end, whose `fd`/`mounted`/geometry fields would be read and written. **Reachability today: none found (INFERRED-dissolved in practice)** — every in-tree slot source is masked into range before the call (`mcman_unit2card`, `iop/vmcman/src/mcdev.c:220-223`: `unit & (MCMAN_MAXSLOT - 1)` under `BUILDING_VMCMAN`, READ), and the backing functions are internal, not exported. This is a wrong-on-its-face guard in vendored code that Launchstation locally patches anyway (per its README), one future caller away from live.
- **Fix (LESS):** One character plus the missing half: `if (slot < 0 || slot >= MCMAN_MAXSLOT)`. (If upstream-parity concerns argue against touching vendored code, this is exactly the kind of local delta the README already documents several of.)
- **Benefit:** The single choke-point validator actually validates. **Effort:** XS. **Risk:** None — no in-range behaviour changes. **Confidence:** High on the defect (READ); "currently unreachable" is INFERRED from the caller enumeration above.

### 4.2 Block-device modules — checked and clean (dissolved candidates)

- **vmcman devctl/ioctl/ioctl2 (READ, clean):** `mc_devctl`, `mc_ioctl`, `mc_ioctl2` (`iop/vmcman/src/mcdev.c:665-672, 788-800, 829-842`) are stubs that ignore `cmd/arg/arglen/buf/buflen` entirely and return 0 under the io semaphore. There is no copy to bound. (That they silently succeed is a pre-existing upstream semantic, not a Cat-6 issue.)
- **vmcman rename length (READ, clean):** the one grep hit that looked live — `memcpy(mctbl.EntryName, new_, l)` at `mcdev.c:703` — is preceded by `l = strlen(new_)` and an explicit `l <= (PS1 ? 20 : sizeof(EntryName)-1)` check with `-ENAMETOOLONG` on failure. All other `memcpy/strncpy` hits in vmcman are fixed-size struct/date copies or bounded `strncpy(…, 20/32/63)` into card-format fields (READ by inspection of every grep hit).
- **vmcman superblock `strcpy/strcat` (dissolved):** `strcpy(mcdi->magic, SUPERBLOCK_MAGIC); strcat(mcdi->magic, SUPERBLOCK_VERSION);` (`main.c:4371-4372`, `ps2mc_fio.c:51-52`) — both operands are compile-time constants totalling 35 bytes into the fixed superblock field they define; not caller-influenced.
- **ata_bd (READ, clean for this task's scope):** no devctl/RPC handler exists. The BDM callbacks `ata_bd_read`/`ata_bd_write` (`ps2atad.c:1552-1568`) forward `bd->devNr` — assigned internally at registration (`:357-368`, values 0–1) — and a `u16 count` that `ata_device_sector_io64` chunks correctly for both LBA28 (256) and LBA48 (65536, with the `len == 0` means-65536 encoding handled deliberately, `:1048-1053`). The exported `sceAtaSecurity*` functions copy a fixed 32 bytes from the caller's password pointer into a zeroed 512-byte param block (`:1132, :1153`) — fixed length, no caller length exists to abuse. The sceAta `device` index is not range-checked against `atad_devinfo[2]` inside the sector-io path (`:1050`), but `device` there comes only from other IOP modules / the BDM struct, never from EE or the network — trusted-caller surface, noted here rather than counted.
- **usbmass_bd `usb_queue_cmd` memcpy (dissolved by caller enumeration, READ):** `memcpy(ucmd.cbw.comData, cmd, cmd_len)` (`usb_mass.c:484`) into `comData[16]` (`:62`) has no local bound — but **every** caller passes `sizeof(comData)` of a 12- or 16-byte array (`scsi.c:84, 136, 156, 174`), and `queue_cmd` is an internal function pointer wired once (`usb_mass.c:848`). Safe at the pin; a one-line `if (cmd_len > 16) return -EIO;` would be cheap insurance but is not counted as a finding. The BDM read/write paths chunk by `scsi->max_sectors`, handle unaligned buffers one sector at a time through an `alloca` bounce of exactly `sectorSize` (`scsi.c:334` is `memcpy(misalign_buffer, buffer, sectorSize)` under `sc = 1`), and the local delta (ORIGIN.md items 1–11) is precisely a set of bounds/liveness fixes — no regression of them found.
- **mx4sio_bd sector truncation (dissolved with caveat, READ+INFERRED):** `spisd_read`/`spisd_write` take a `uint64_t sector` but pass `(uint32_t)sector` to the multi-block begin functions (`spi_sdcard_driver.c:618, 689`). Sector indices ≥ 2³² would need a >2 TiB SD card; card capacity is parsed from the CSD into `bd.sectorCount` (`spisd_get_card_info`) and SDXC tops out at 2 TiB = exactly 2³² sectors of 512 B, so every *valid* sector index fits in `u32`. Truncation is unreachable with a spec-conforming card; a card lying in its CSD is a BDM-layer concern above this driver. The unaligned-buffer paths added by the PR #959 port are correctly bounded (one sector through `bounce` per iteration, `:590-613, 655-679`).
- **Cross-module duplication — new (beyond the known ioplib pair):** `sio2man_hook.c` exists in both `mmceman/src` (320 lines) and `mx4sio_bd/src` (315 lines) and is **near-identical but diverged** (READ via diff): the mmceman copy carries a substantive behavioural delta — the `PORT_NR` hard-filter is commented out with a comment explaining MMCEMAN must not filter a slot, while the mx4sio copy keeps `#define PORT_NR 3` — plus its header differs in exactly one capability define (`SIO2MAN_HOOK_SUPPORT_SET_INTR_HANDLER 1` vs `0`). Likewise `sio2regs.h` (mmceman 201 lines vs mx4sio 174) has diverged register-macro definitions (`PCTRL1_ACK_TIMEOUT_PER` vs `…_AFTER` families). And `module_debug.h` exists in three divergent copies (mmceman, mx4sio_bd, usbmass_bd). **Not counted as a finding:** the sio2man_hook divergence is load-bearing (the two modules genuinely need different port behaviour), so "deduplicate" would be MORE, not less. Recorded here so round-3 synthesis does not re-derive it; `ioplib.c`/`ioplib.h` byte-identity (md5-verified again this round) is the known pass-1 item and is deliberately not repeated.
- **mmceman fs wire paths other than game-ID (spot-checked, READ):** the fs commands the local history hardened (open/remove/mkdir/read/write) build fixed-size header packets, validate names via `mmce_fs_wire_name_ok` before use (e.g. `mmce_fs_remove`), and treat firmware reply bytes as values, not lengths, in the paths read. The dread/getstat paths were not re-read end-to-end this round — see Still Unread.

---

## Still unread / not verified (explicit)

1. **All of libsmb2 itself** (54 files): absent from the clone, not fetched per instructions. Everything depending on its internals is INFERRED above — specifically: whether inbound WRITE length is enforced against `max_write_size` (R3A-02), whether `calloc` receives remote-sized arguments (R3A-05), whether intra-library references exist to the R3A-06 deletion candidates (link test required), how `query_directory_cmd`'s `rep->output_buffer_length = n * PAD8(sizeof(ent[0]))` relates to the encoder's real per-entry size, and whether `authorize_user`'s set-password pattern is verified by libsmb2 exactly as the comment in `smbd_fs.c` implies.
2. `iop/smbd/imports.lst` / `linkfile` / `irx_imports.h` — listed, not audited.
3. `tests/smbd_live/host.c` POSIX platform half — read only its header/first functions; it is a test harness, not shipped code, and was used only to confirm the `smbd.h` interface shape.
4. vmcman: `main.c` (4,398 lines), `ps2mc_fio.c`, `ps1mc_fio.c`, `mcsio2.c` internals beyond the grep-hit inspection — Task 4 scoped the Cat-6 pass to devctl/RPC entry points, and vmcman's are stubs (above); its mcman **library exports** (McOpen/McRead/…) are a separate, larger surface not in this task's scope.
5. mmceman: `mmce_fs.c` read/write/dread/getstat bodies end-to-end (only devctl/ioctl/ioctl2 + grep hits + the game-ID paths were read in full); `mmce_sio2.c` internals.
6. ata_bd `ps2atad.c` beyond the BDM callbacks, sector-io chokepoint, and security exports; usbmass_bd `usb_mass.c` bulk-transfer state machine beyond `usb_queue_cmd` and registration.
7. No build, no link test, no hardware: R3A-06's deletion and every fix above are code-read claims only — per the audit standard, nothing here is console-verified.
