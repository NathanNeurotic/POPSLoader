# Round 5 — Section T3: `iop/ps2hdd_osd` (Launchstation)

- Repo / pin: `NathanNeurotic/Launchstation` @ `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (verified, not fetched/updated)
- Scope: first end-to-end line read of this directory in any round (pass 1 only inventoried/grep-swept it; the one prior citation, `cache.c:56` `#if 0` block, is **not** repeated here)
- Method: READ ONLY. No build, no hardware claim. Claims labelled READ (seen in source at the cited line) or INFERRED. No secret-like values printed — password material is discussed by structure only.
- Live build flavour (controls almost every verdict below): `ps2.yaml:93-114` builds target `ps2hdd_osd` from the nine `.c` files with defines `APA_OSD_VER`, `APA_USE_DEV9`, `APA_USE_ATAD` (and iomanX compat `=0`), embedded as `ps2hdd` (`ps2.yaml:482`); `ps2fs.irx` still comes from the active PS2SDK. **Not** defined: `APA_XOSD_VER`, `APA_SUPPORT_BHDD`, `APA_SUPPORT_GPT`, `APA_USE_BDM`, `APA_USE_IOMANX`, `APA_POSIX_VER`, `APA_ENABLE_PASSWORDS`.

---

## (a) Provenance / local-delta determination

**Verdict: vendored PS2SDK `ps2hdd` (APA) sources, imported wholesale, with exactly one README-declared local change (HDD-unit tracking in open slots). Everything else that looks "local" is the upstream OSD variant selected by a build define, or upstream's own `Unofficial:`/`Non-SONY:` annotations. No source hunk in this directory has been edited in this repo's history after the import.**

Evidence:

1. **Single-shot import (READ).** `git log -- iop/ps2hdd_osd` shows three commits only: `944a2fc` "Initial commit for wLaunchELF_R3Z_RIPTOATTDASH" adds all 18 files (4,205 insertions, incl. every `.c`/`.h` at its current line count); `59411fa` deletes only `iop/ps2hdd_osd/Makefile` (14 lines, build retirement); `2c28941` edits one line of `README.md`. There is no post-import source edit to diff against — the local delta, if any, arrived inside the initial import.
2. **Upstream banner on every file (READ).** Every `.c`/`.h` carries the PS2DEV header "PS2DEV Open Source Project / Copyright 2001-2004, ps2dev / Academic Free License 2.0" (e.g. `apa.c:1-11`, `password.c:1-12`, `libapa.h:1-10`).
3. **README is the delta statement (READ).** `iop/ps2hdd_osd/README.md:1-15`: "This directory vendors the PS2SDK APA/ps2hdd sources needed to build `ps2hdd-osd.irx`. We keep a local OSD build because wLaunchELF needs protected-partition access, and the stock PS2SDK APA open-slot tracking treats partitions with the same APA ID as the same open partition even when they are on different HDD units. Local change: Track the HDD unit in each open file slot. Treat a partition as already open only when both the HDD unit and APA ID match."
4. **The declared change is present and complete in its own terms (READ).** Slot field `hdd.h:19` (`u32 device;` in `hdd_file_slot_t`); assignments `hdd_fio.c:625` and `hdd_fio.c:637` (`fileSlot->device = f->unit;` in `hddOpen`); all three duplicate-open scans compare unit **and** ID: `hdd_fio.c:223` (`getFileSlot`), `hdd_fio.c:493` (`apaRemove`), `hdd_fio.c:546` (`apaRename`). No fourth open-scan exists in the file (grep-verified). The APA header cache is likewise keyed by device+sector (`cache.c:141-147`), so no cross-unit header aliasing was found.
5. **The "OSD flavouring" is upstream, selected not edited (READ).** `apa-opt.h:18-37`: under `APA_OSD_VER` the header itself documents "All partitions can be accessed, even without the right password", defines `APA_STAT_RETURN_PART_LBA`, `APA_FORMAT_LOCK_MBR`, `APA_FORMAT_MAKE_PARTITIONS`, and does **not** define `APA_ENABLE_PASSWORDS`. In-source markers `cache.c:64` ("Unofficial: Free once…"), `free.c:72` and `hdd.c:137` ("Non-SONY: …64-bit arithmetic…"), `hdd_fio.c:530` ("Unofficial helper for renaming…"), `hdd_fio.c:779-793` ("This was the SONY original…") are PS2SDK-tree annotations, not Launchstation edits (INFERRED — no upstream copy was fetched, per the pin rule; the inference rests on the banners, the single-shot import, and the markers' third-person references to SONY/the original driver).
6. **Consequence for this audit (framing).** Pristine upstream hunks are inventory below. Findings are confined to: the entry-point surface as actually compiled in this build (iomanX ops / `ioctl2` / `devctl` in `hdd.c:47-84`, `hdd_fio.c`), defects that only exist **because** of this build's define set (T3-F4, T3-F10, T3-F11), journal/cache consistency, and the locally-kept decision to carry the whole vendored file set in the build.

**Sibling APA implementation (for the coordinator; sibling agent owns `hdl_info`).** READ, diff-evidenced:

| File | Lines | SHA-256 |
|---|---|---|
| `iop/ps2hdd_osd/apa.c` | 522 | `3bbab327115b78900a0e52db03372f7d22661fdec830266f7e04ca8970ac186d` |
| `iop/hdl_info/apa.c` | 320 | `fa2f1bf3a24395bd232096c9072b9bd620506554e01d582333fd159cb270e912` |

`diff` shows these are **not copies**: different includes, types and algorithm shape (`hdl_info/apa.c:1-30` is an HD-Loader-style partition-table walker with `apa_partition_table_t`/`apa_ptable_alloc`, no PS2DEV banner; `ps2hdd_osd/apa.c` is the cache/journal driver core). Shared ground is the APA on-disk format and the checksum-from-word-1 loop concept only. **No duplication finding is raised from this section.** `iop/ata_bd` contains no `apa.c` at all (only `src/ps2atad.c`, `include/atad.h`, exports/imports — `find`-verified, READ).

---

## (b) Coverage ledger

All files read end to end at the pin, unless marked otherwise.

| File | Lines | Coverage |
|---|---|---|
| `iop/ps2hdd_osd/apa.c` | 522 | Full, 1-522 |
| `iop/ps2hdd_osd/cache.c` | 218 | Full, 1-218 |
| `iop/ps2hdd_osd/free.c` | 89 | Full, 1-89 |
| `iop/ps2hdd_osd/hdd.c` | 406 | Full, 1-406 |
| `iop/ps2hdd_osd/hdd_blkio.c` | 431 | Full, 1-431 (all bodies conditional — see T3-F10) |
| `iop/ps2hdd_osd/hdd_fio.c` | 1207 | Full, 1-1207 |
| `iop/ps2hdd_osd/journal.c` | 88 | Full, 1-88 |
| `iop/ps2hdd_osd/misc.c` | 145 | Full, 1-145 |
| `iop/ps2hdd_osd/password.c` | 522 | Full, 1-522 (DES tables 60-522 read as structure; not line-audited as cryptography) |
| `iop/ps2hdd_osd/hdd.h` | 32 | Full |
| `iop/ps2hdd_osd/hdd_fio.h` | 38 | Full |
| `iop/ps2hdd_osd/hdd_blkio.h` | 82 | Full |
| `iop/ps2hdd_osd/libapa.h` | 219 | Full |
| `iop/ps2hdd_osd/apa-opt.h` | 50 | Full |
| `iop/ps2hdd_osd/README.md` | 15 | Full |
| `iop/ps2hdd_osd/imports.lst` / `irx_imports.h` | 84 / 43 | Inventoried (import lists; `irx_imports.h` read full) — not finding material |
| `ps2.yaml` (build definition for this module) | — | Ranges 93-114, 482 (grep + read) |
| `iop/hdl_info/apa.c` | 320 | Head + `diff`/`sha256sum`/`wc` only — sibling agent's section |

Total in-section source read: **4,628 lines** (3,628 `.c` + 371 `.h` in scope files + README; `imports.lst`/`irx_imports.h` inventoried).

---

## (c) Findings

### T3-F1 / `HIOCGETSIZE` indexes `fileSlot->parts[]` with a caller-supplied u32 and no bounds or pointer check / Category 1

- **Locations:** `iop/ps2hdd_osd/hdd_fio.c:957-958` (`rv = fileSlot->parts[*(u32 *)argp].length;`); same shape in the compiled-out sibling at `hdd_fio.c:977-978` (`HIOCGETPARTSTART`, gated by `APA_SUPPORT_IOCTL_GETPARTSTART`, which the OSD branch of `apa-opt.h:30-37` does not define — dead today, identical defect if ever enabled); array size at `iop/ps2hdd_osd/hdd.h:24` (`apa_sub_t parts[APA_MAXSUB+1]`); dispatch discards the length arguments at `hdd_fio.c:925-933` (`(void)arglen; (void)bufp; (void)buflen;`).
- **Problem:** READ — the `ioctl2` caller (any EE code with the partition open) supplies the index verbatim. There is no test against `fileSlot->nsub`, against `APA_MAXSUB`, and no `argp == NULL` / `arglen < 4` test anywhere in `hddIoctl2`. An out-of-range index reads past the heap-allocated slot array (`hdd.c:325`, slots are one `apaAllocMem` block) and returns the read word as the ioctl result; a null `argp` dereferences null in IOP space.
- **Fix:** In `HIOCGETSIZE` (and the gated `HIOCGETPARTSTART` before anyone enables it): reject `argp == NULL || arglen < sizeof(u32)` and `*(u32 *)argp > fileSlot->nsub` with `-EINVAL` before indexing.
- **Justification (if ADD):** The guard is an addition, justified by a concrete bug: it is the only check that keeps a caller value inside an array whose valid length the driver already tracks in `fileSlot->nsub`.
- **Benefit:** Closes an out-of-bounds read / null deref on a live, unprivileged-to-call ioctl path.
- **Effort:** S · **Risk:** Low (rejects only requests that are currently undefined behaviour) · **Confidence:** READ

### T3-F2 / `ioctl2Transfer` bounds check is overflowable and the transfer direction is caller-supplied / Category 1

- **Locations:** `iop/ps2hdd_osd/hdd_fio.c:265-282` (`ioctl2Transfer`): sub-index test `:267`, minimum-sector tests `:271-275`, end test `:277` (`if (fileSlot->parts[arg->sub].length < arg->sector + arg->size) return -ENXIO;`), transfer `:280-281` passing `arg->mode` straight to `blkIoDmaTransfer`.
- **Problem:** READ for the code shape — the only end-of-partition test is the sum `arg->sector + arg->size`; no overflow-safe form (`arg->size > length - arg->sector`) is used, and `arg->mode` is never validated as read-vs-write, so the caller's struct decides both span and direction. INFERRED for the wrap itself: the field widths live in the SDK's `hdd-ioctl.h` (not in this repo), but on any 32-bit field width a `sector` near the wrap point makes the sum small, passes `:277`, and the transfer then runs at `parts[arg->sub].start + arg->sector` for `arg->size` sectors — outside the partition the check exists to confine it to.
- **Fix:** Rewrite `:277` as `if (arg->size > fileSlot->parts[arg->sub].length - arg->sector)` after the existing minimum-sector tests (which already guarantee `arg->sector` is sane), and reject any `arg->mode` that is not exactly `BLKIO_DIR_READ` or `BLKIO_DIR_WRITE`.
- **Benefit:** The one raw-transfer ioctl that is supposed to be partition-confined actually stays confined.
- **Effort:** S · **Risk:** Low · **Confidence:** READ (missing checks) / INFERRED (wrap width)

### T3-F3 / `apaRename` signals `fioSema` on three of its exits and its caller signals it again — semaphore ownership is double-released on every rename error path / Category 6

- **Locations:** Helper `iop/ps2hdd_osd/hdd_fio.c:531-582`: inner `SignalSema(fioSema)` at `:539` (`-EEXIST`), `:548` (`-EBUSY`), `:562` (not-found return); the one inner return that does **not** signal is the system-partition refusal at `:556-559`; sole caller `hddReName` at `hdd_fio.c:808-817` does `WaitSema` → `apaRename` → `SignalSema` unconditionally.
- **Problem:** READ — every other helper in this file (`apaRemove`, `apaOpen`, `devctlSwapTemp`, …) leaves signalling to its caller; `apaRename` alone signals inside, on exactly three of five exits. Those three error paths therefore release the semaphore twice for one acquisition (the semaphore is created `initial=1, max=1` at `hdd_fio.c:293-296`). Whatever the IOP kernel does with an over-max signal, the count no longer means "one holder": a second thread can enter the APA critical section while the first still runs, over the shared cache, journal and slot table. This is the rename path — i.e. it fires precisely when a rename *fails*, the common case for a duplicate-name attempt.
- **Fix:** Delete the three inner `SignalSema(fioSema)` calls at `:539`, `:548`, `:562`. Pure deletion; the caller's existing signal then balances every exit, including `:556-559` which already relies on it.
- **Benefit:** Restores the file-wide locking convention and mutual exclusion over cache/journal/slots on rename errors.
- **Effort:** S (3-line deletion) · **Risk:** Low — the "correct" exits today (success, system-partition refusal) already run on caller-signal only, so deletion makes the error exits match the working ones · **Confidence:** READ

### T3-F4 / The OSDMBR journal-overlap guard is compiled out of the OSD build — the one build this module exists for / Category 2

- **Locations:** `iop/ps2hdd_osd/hdd_fio.c:1030-1052` (`devctlSetOsdMBR`): the guard at `:1039-1043` (`if (mbrInfo->start < APA_SECTOR_MIN_OSDSTART) return -EINVAL;`) sits inside `#ifdef APA_SUPPORT_GPT`; the constant itself is defined unconditionally at `iop/ps2hdd_osd/libapa.h:34` (`APA_SECTOR_MIN_OSDSTART` = journal headers end + 1, comment: "OSD program cannot overlap the journal"); live caller `HDIOC_SETOSDMBR` at `hdd_fio.c:1124-1126`; define set at `ps2.yaml:107-110` and `apa-opt.h:30-37` (neither defines `APA_SUPPORT_GPT`).
- **Problem:** READ — in the shipped configuration there is **no** validation of `mbrInfo->start`/`size` at all: any values are written into the MBR header, marked dirty and flushed through the journal (`:1044-1048`). A start below sector 263 points the OSD program area at the APA journal/MBR region itself — the exact overlap the (dead) guard describes. The guard's placement under GPT is an upstream config artefact, but its effect lands here: `devctlSetOsdMBR` is an OSD-only feature, and the OSD build is the one without the check. Secondary, in the dead branch only: the guarded `return -EINVAL` also leaks `clink` (no `apaCacheFree` before return, contrast `:1049`).
- **Fix:** Drop the `#ifdef APA_SUPPORT_GPT` / `#endif` around `:1039-1043` and add `apaCacheFree(clink);` before that return. Net: −2 preprocessor lines, +1 line.
- **Justification (if ADD):** The one added line prevents a cache-slot leak on the newly-live error exit; the check itself already exists in the source and costs nothing to enable.
- **Benefit:** `HDIOC_SETOSDMBR` can no longer be used to aim the OSD area at the driver's own journal.
- **Effort:** S · **Risk:** Low (rejects only starts the code's own comment already declares invalid) · **Confidence:** READ

### T3-F5 / Journal restore trusts the on-disk journal count and sector list completely, then erases the journal even when restore fails part-way / Category 6

- **Locations:** `iop/ps2hdd_osd/journal.c:58-88` (`apaJournalRestore`): count test `:70`, allocation `:73`, replay loop `:74-82`; journal layout `iop/ps2hdd_osd/libapa.h:184-189` (`apa_journal_t { u32 magic; s32 num; u32 sectors[126]; }`); callers at module start / mount: `hdd.c:342-348`, `hdd_blkio.c:132` and `:247` (the latter two in dead branches, see T3-F10).
- **Problem:** READ — after a magic check, `journalBuf.num` is taken from disk and used as (1) the loop bound and (2) the index into `sectors[126]`, with no `0 <= num <= 126` validation, no per-sector range validation, and no checksum/validity check on the journaled header before it is written verbatim to `journalBuf.sectors[i]` (`:79`). A corrupt or crafted journal block therefore replays out-of-bounds `sectors[]` values as destination LBAs for 2-sector header writes at startup. Two compounding defects in the same function: `clink = apaCacheAlloc();` at `:73` is unchecked before `clink->header` is dereferenced at `:76` (null deref when the cache is exhausted); and the function ends with `return apaJournalReset(device);` at `:87` unconditionally — a part-way replay failure (`break` at `:78`/`:82`) still erases the journal, destroying the only copy of the entries that were not replayed.
- **Fix:** Before the loop: return/reset only if `journalBuf.num < 0 || journalBuf.num > 126` is treated as "no valid journal"; check the `apaCacheAlloc()` result; on a replay error, return the error **without** calling `apaJournalReset`.
- **Benefit:** Startup journal replay — the driver's crash-recovery mechanism — stops being a disk-controlled arbitrary-header-write primitive and stops discarding unreplayed entries.
- **Effort:** S · **Risk:** Low · **Confidence:** READ

### T3-F6 / Journal write side has no capacity check, and the flush path ignores journal errors and resets the journal anyway / Category 6

- **Locations:** `iop/ps2hdd_osd/journal.c:47-55` (`apaJournalWrite`: writes at `(journalBuf.num << 1) + APA_SECTOR_APAL_HEADERS`, stores `journalBuf.sectors[journalBuf.num]`, `journalBuf.num++` — no bound test); `iop/ps2hdd_osd/cache.c:113-130` (`apaCacheFlushAllDirty`: calls `apaJournalWrite` per dirty entry ignoring its return, calls `apaJournalFlush` ignoring its return, transfers the headers, then `return apaJournalReset(device);`); capacity is the 126-entry array at `libapa.h:188`; cache size is set by the unbounded `-n` module argument at `hdd.c:279-281` (see T3-F12).
- **Problem:** READ for both mechanisms — (1) nothing in `apaJournalWrite` stops `num` reaching/passing 126, at which point the header write lands past the reserved journal-header area (`libapa.h:31-34` reserves sectors 10-262, i.e. exactly 126×2) and `sectors[num]` writes past the static `journalBuf`. In the default configuration the dirty-entry count per flush is bounded by the cache size (default 3, `hdd.c:218`), so reaching 126 needs a raised `-n` — reachability INFERRED, mechanism READ. (2) Unconditionally READ and reachable today: if the journal write or flush fails with `-EIO`, `apaCacheFlushAllDirty` proceeds to write the headers anyway and resets the journal — a failed protection step is silently converted into an unprotected metadata write, defeating the journal's stated purpose on exactly the disks that are already erroring.
- **Fix:** In `apaJournalWrite`, return `-ENOSPC` (and write nothing) when `journalBuf.num >= 126`. In `apaCacheFlushAllDirty`, propagate a journal-write/flush failure: skip the header transfers and the reset, and return the error.
- **Benefit:** Journal overflow becomes a clean error instead of an out-of-area disk write; journal failure stops masquerading as success.
- **Effort:** S · **Risk:** Low–Medium (callers of the flush helpers mostly ignore their returns today, so behaviour change is confined to not-writing on journal failure — which is the safe direction) · **Confidence:** READ (mechanisms) / INFERRED (overflow reachability at default cache size)

### T3-F7 / Four entry-reachable `apaCacheAlloc()` results are used without a null check, beside a fifth site in the same files that does check / Category 1

- **Locations:** Unchecked: `iop/ps2hdd_osd/apa.c:43-49` (`apaSetPartErrorSector` — alloc `:46`, deref `:47`); `iop/ps2hdd_osd/apa.c:455-463` (`apaGetFormat` — alloc `:463`, deref via `apaReadHeader(..., clink->header, ...)`); `iop/ps2hdd_osd/hdd_fio.c:329-335` (`hddFormat` — alloc `:333`, `memset(clink->header, …)` `:334`); `iop/ps2hdd_osd/journal.c:73` (counted in T3-F5). Checked, for contrast, same file: `apa.c:51-57` (`apaGetPartErrorSector` returns `-ENOMEM`). Entry reachability: `apaSetPartErrorSector` from `HIOCSETPARTERROR`/`HIOCGETPARTERROR` (`hdd_fio.c:961-972`) and `HDIOC_*` error paths; `apaGetFormat` from module start (`hdd.c:350`); `hddFormat` is the iomanX `format` op (`hdd.c:50`).
- **Problem:** READ — `apaCacheAlloc` returns `NULL` when the free list is empty (`cache.c:201-218`); the cache is small (default 3 entries) and entries are held across the nested `apaCacheGetHeader` walks these callers run under, so exhaustion is a real state, not a theoretical one. Each unchecked site turns it into a null dereference in IOP space instead of an error return.
- **Fix:** Add the `if (!clink) return -ENOMEM;` check the checked site already uses, at the three sites above (journal site is in T3-F5's fix).
- **Justification (if ADD):** Additions are justified by a concrete bug — allocator exhaustion is reachable under the module's own semaphore-held nested walks — and they copy the file's own existing pattern, adding no new mechanism.
- **Benefit:** Cache exhaustion degrades to `-ENOMEM` instead of crashing the HDD driver.
- **Effort:** S · **Risk:** Low · **Confidence:** READ

### T3-F8 / The on-disk `nsub` field is trusted as a loop bound and array index in four places; the guards that exist check a different variable / Category 1

- **Locations:** `iop/ps2hdd_osd/hdd_fio.c:728-736` (`fioGetStatFiller`: `for (i = 0; i < clink->header->nsub; i++) totalsize += clink->header->subs[i].length;` — `subs` is `apa_sub_t subs[APA_MAXSUB]` at `libapa.h:116`); `hdd_fio.c:872-874` (`ioctl2AddSub` writes `clink->header->subs[clink->header->nsub]` — the entry guard at `:838` tests `fileSlot->nsub < APA_MAXSUB`, not the header's `nsub` being written through); `hdd_fio.c:885-895` (`ioctl2DeleteLastSub` reads `subs[mainPart->header->nsub - 1]` — the guard at `:891` tests `fileSlot->nsub == 0`, not the header's; a diverged header `nsub` of 0 indexes `subs[-1]`); `hdd_fio.c:498-526` (`apaRemove`: sub-deletion loop bounded by the header's `nsub` read from disk).
- **Problem:** READ — `nsub` comes from the on-disk APA header (checksum-protected against corruption, but fully chosen by whoever wrote the disk image, and independently writable via `HDIOC_WRITESECTOR`, T3-F11). `fileSlot->nsub` and `header->nsub` are copies taken at open (`hdd_fio.c:469-471`) and incremented/decremented in tandem by AddSub/DeleteLastSub, so they agree in normal operation; every site that indexes by the header copy is one crafted/desynchronised header away from reading or writing outside `subs[]` inside the 1,024-byte cache allocation. `fioGetStatFiller` is the softest target: it runs on `getstat`/`dread` against any partition header present on the disk.
- **Fix:** Validate once where the header is first trusted (in `apaOpen`, after `clink` is obtained): reject/clamp `clink->header->nsub > APA_MAXSUB` with `-EIO`. One site, no per-callsite guards needed.
- **Justification (if ADD):** A single central validation is the smallest change that covers all four index sites; per-site guards would be more code for the same property.
- **Benefit:** A crafted partition header can no longer drive out-of-bounds reads/writes in stat, add-sub, delete-sub or remove.
- **Effort:** S · **Risk:** Low (legitimate headers always satisfy `nsub <= APA_MAXSUB` by construction of the format) · **Confidence:** READ (code) / INFERRED (practical divergence requires a crafted or raw-written header)

### T3-F9 / `fioInputBreaker` accepts a field exactly as long as its buffer, leaving IDs and passwords unterminated / Category 1

- **Locations:** `iop/ps2hdd_osd/hdd_fio.c:107-127` (both branches test `if (maxout < len) return -EINVAL;` — i.e. `len == maxout` passes — then `memcpy(outBuf, …, len)` with no terminator written); call sites `hdd_fio.c:161` (`params->id`, `APA_IDMAX`), `:166` (`params->fpwd`, `APA_PASSMAX`), `:175` (`params->rpwd`, `APA_PASSMAX`), all inside `fioGetInput` (`:134-210`), reached from `open`/`remove`/`getstat`/`devctlSwapTemp` name parsing.
- **Problem:** READ — `apa_params_t` is zeroed at `fioGetInput:146`, so any field shorter than its buffer is implicitly terminated; a field of exactly `maxout` bytes fills the buffer completely and is thereafter handled as a string with no terminator in bounds. Fixed-width consumers (`memcmp(…, APA_IDMAX)`) are unaffected, which is why this survives; length-sensitive consumers of the same fields (the `strcmp` BHDD name tests at `hdd_fio.c:432-437` family, `apaEncryptPassword`'s callers passing `params->id`, any future string use) read past the field into the adjacent `apa_params_t` member.
- **Fix:** Change both tests in `fioInputBreaker` from `maxout < len` to `maxout <= len` (reserve the terminator byte the zeroed struct currently provides only by luck of length).
- **Benefit:** Every parsed ID/password is provably terminated; the exact-length edge stops being a latent over-read.
- **Effort:** S (two characters) · **Risk:** Low (rejects only inputs that previously produced an unterminated field) · **Confidence:** READ

### T3-F10 / `hdd_blkio.c` (431 lines) compiles to nothing in the shipped build and is still listed as a build source; the BDM/vHDD backends it carries are dead weight with their own latent defects / Category 5

- **Locations:** `iop/ps2hdd_osd/hdd_blkio.c:17` (`#ifdef APA_USE_BDM` block, `:17-182`), `:182` (`#ifdef APA_USE_IOMANX` vHDD block, `:182-303`), `:305-431` (`#ifndef APA_USE_ATAD` block); the live backend is the `static inline` ATAD forwarding in `iop/ps2hdd_osd/hdd_blkio.h:17-82`; build listing at `ps2.yaml:96-104` (includes `hdd_blkio.c`) with defines at `ps2.yaml:107-110` (`APA_USE_ATAD` defined; neither `APA_USE_BDM` nor `APA_USE_IOMANX` defined anywhere in the build). Knock-on dead code: `hddMount`/`hddUmount` bodies at `hdd_fio.c:1168-1207` (same `APA_USE_IOMANX` gate; the ops table at `hdd.c:72-73` resolves to the `EPERM` macros in `hdd_fio.h:30-36`), and every `APA_SUPPORT_BHDD` / `APA_SUPPORT_GPT` branch across `apa.c`, `hdd.c`, `hdd_fio.c`.
- **Problem:** READ — an entire 431-line translation unit is preprocessed away on every build, while masquerading in the source list as the block-I/O layer (the real one is a header). The dead bodies are not inert documentation: the vHDD validator at `hdd_blkio.c:206-220` tests `if (slot > BLKIO_MAX_VOLUMES)` where `>=` is required (its BDM sibling at `:113-119` uses the correct form), so slot `== BLKIO_MAX_VOLUMES` would index one past `hdd_blkio_vhdd_diskinfo[]` if the backend were ever enabled as-is; `hdd_blkio_vhdd_mount` at `:228-256` also truncates `disksize >> 9` into an `int sectorcount`. Dead code with live-looking defects is how a future "just flip the define" change imports bugs unreviewed.
- **Fix:** Remove `iop/ps2hdd_osd/hdd_blkio.c` from the `ps2.yaml:96-104` source list and delete the file (the ATAD inline header is the whole live backend); alternatively, if BDM/vHDD support is genuinely planned, delete only the `#ifndef APA_USE_ATAD` fallback bodies and fix the `>` → `>=` test before the file is allowed back into a build. Deletion is the LESS-NOT-MORE default.
- **Benefit:** −431 lines of audit surface; the block-I/O layer becomes what the build actually uses; two latent defects leave with the dead backend.
- **Effort:** M (confirm no other target references the vhdd/BDM symbols — grep shows only the dead mount/umount pair) · **Risk:** Low for the shipped ATAD build (the file contributes no symbols to it) · **Confidence:** READ

### T3-F11 / Passwords are encrypted on input and then never verified in this build — the DES run on every `open`/`remove`/`getstat` name parse is dead work / Category 5

- **Locations:** `iop/ps2hdd_osd/password.c:25-35` (`apaPassCmp` returns `0` unconditionally when `APA_ENABLE_PASSWORDS` is undefined, with the comment "Passwords are not supported, hence this check should always pass"); `apa-opt.h:30-37` (OSD branch does not define it — deliberate, see provenance); callers that still pay for encryption: `hdd_fio.c:169-179` (`fioGetInput` runs `apaEncryptPassword` over both supplied password fields on every parse); verification-shaped call sites that therefore always pass: `hdd_fio.c:476-477` (`apaOpen`), `:504` (`apaRemove`), `:747` (`hddGetStat`), `:1011` (`devctlSwapTemp`).
- **Problem:** READ — this is **not** a "passwords are broken" finding: protected-partition access without passwords is the documented reason this OSD build exists (`README.md:5-8`, `apa-opt.h:18-23`), and the stored values still matter for interop with stock drivers, so `hddFormat`'s MBR encryption (`hdd_fio.c:363-366` area, `APA_FORMAT_LOCK_MBR`) and the DES implementation in `password.c:40-522` must stay. What is pure waste is the input side: every partition-name parse DES-encrypts (a ~480-line bit-permutation implementation, run in IOP software) two fields whose encrypted forms are then compared by a function compiled to `return 0`. It costs time on every open and, worse, makes the code read as if a check is happening.
- **Fix:** Guard the two `apaEncryptPassword` calls in `fioGetInput` (`hdd_fio.c:169-179`) with `#ifdef APA_ENABLE_PASSWORDS`. Non-OSD builds of the same source keep today's behaviour byte-for-byte; the OSD build stops encrypting inputs it will never compare.
- **Benefit:** Removes a full DES run (×2) from every name parse in the shipped driver and makes the no-verification design honest at the call site.
- **Effort:** S · **Risk:** Low (guarded by the same define that controls the comparator) · **Confidence:** READ

### T3-F12 / Module start arguments are range-checked in a way that admits 0 and negatives for `-o`, and no maximum at all for `-n` / Category 1

- **Locations:** `iop/ps2hdd_osd/hdd.c:265-281`: `-o` handling `:270-272` (`i = strtol(…); if (i - 1 < 32) apaMaxOpen = i;` — a signed test that `i = 0` and every negative `i` pass), `-n` handling `:279-281` (`if (cacheSize < i) cacheSize = i;` — no upper bound); consumers `:325` (`apaAllocMem(apaMaxOpen * sizeof(hdd_file_slot_t))`), `:333` (matching `memset`), `:335` (`apaCacheInit(cacheSize)`); defaults `hdd_fio.c:38` (`apaMaxOpen = 1`), `hdd.c:218` (`cacheSize = 3`).
- **Problem:** READ for the tests — `i - 1 < 32` was plainly meant as "1..32" but admits `i <= 0`: `apaMaxOpen = 0` makes every `getFileSlot` return `-EMFILE`; a negative value makes the `:325` allocation size a huge unsigned product (allocation fails → module refuses to start, the benign outcome) and desynchronises the `:325`/`:333` size expressions from any sane slot count. Unbounded `-n` is the enabling condition for T3-F6's journal-capacity overflow, and also sizes two `apaAllocMem` calls in `apaCacheInit` (`cache.c:28-42`) with no sanity ceiling. INFERRED for exposure: module arguments are supplied by the embedding loader, i.e. trusted local configuration rather than a remote input — this is a robustness/foot-gun defect, not a remotely reachable one.
- **Fix:** `-o`: accept only `1 <= i && i <= 32`. `-n`: accept only `3 <= i && i <= 126` (126 is the journal capacity from `libapa.h:188` — a cache larger than the journal can never be flushed safely, T3-F6).
- **Justification (if ADD):** The bounds are additions justified by concrete failure modes above; the `-n` ceiling is derived from an existing in-tree constant (`libapa.h:188`), not a new policy.
- **Benefit:** A mistyped loader argument can no longer zero out, negate, or over-size the driver's two core tables.
- **Effort:** S · **Risk:** Low · **Confidence:** READ (tests) / INFERRED (exposure is local-config only)

### T3-F13 / `HDIOC_READSECTOR` / `HDIOC_WRITESECTOR` take LBA, count and data pointer from the caller with no bound against the disk, and writes bypass the APA cache and journal entirely / Category 2

- **Locations:** `iop/ps2hdd_osd/hdd_fio.c:1136-1146` (dispatch in `hddDevctl`; `arglen`/`buflen` discarded at `:1060-1062`); the transfer primitives forward unchecked to `sceAtaDmaTransfer` via `hdd_blkio.h:37-40`.
- **Problem:** READ for the absence of checks — neither case tests `lba`, `lba + size`, or `size` against `hddDevices[f->unit].totalLBA` (available in the same switch at `:1087`), and no other devctl case in the switch does so either. READ for the consistency consequence: a `WRITESECTOR` over an APA header sector writes the disk underneath the header cache (`cache.c`) without invalidation and outside the journal protocol (`cache.c:113-130`), so subsequent cached reads serve the pre-write header and a later dirty-flush can silently resurrect it over the raw write. INFERRED for exploitability framing: devctl callers are EE-side code, conventionally trusted on PS2 — this is a hardening/consistency gap in a deliberately privileged interface, not a claim of a remote exploit.
- **Fix:** Add an overflow-safe bound `lba + size <= hddDevices[f->unit].totalLBA` to both cases (reject with `-EINVAL` otherwise), and for `WRITESECTOR` flush/invalidate the APA cache for the unit before returning (the flush helper already exists: `apaCacheFlushAllDirty`, `cache.c:113`).
- **Justification (if ADD):** Additions justified by two concrete bugs — an unbounded raw write primitive and a demonstrated cache-coherence hole — using only helpers and fields already in the file.
- **Benefit:** Raw sector access stays inside the physical disk and can no longer desynchronise the driver's own metadata cache.
- **Effort:** S · **Risk:** Low–Medium (a caller legitimately writing beyond `totalLBA` does not exist; cache flush on write adds IOP work to a rare path) · **Confidence:** READ (checks/coherence) / INFERRED (threat framing)

---

## (d) Checked and clean

- **Declared local delta (unit tracking)** — present and complete: `hdd.h:19`, `hdd_fio.c:223`, `:493`, `:546`, `:625`, `:637`; no fourth duplicate-open scan exists. Cache keying by device+sector (`cache.c:141-147`) matches it. READ.
- **`apaCacheFree`-then-read patterns** (`apa.c:163-166` in `apaInsertPartition`, `hdd_fio.c:475-477` in `apaOpen`, `apa.c:505-522` in `apaGetNextHeader`) — look like use-after-free, dissolve on inspection: `apaCacheFree` (`cache.c:186-199`) is a non-destructive return-to-pool (refcount + list relink, no memory release), all uses hold `fioSema`, and no allocation intervenes between free and read in `apaOpen` (`apaPassCmp` allocates nothing; in this build it does not even compare). Inherited upstream pattern; recorded so it is not re-flagged. READ.
- **Password handling, structure only** — no value printed or logged anywhere in the directory (grep for the format/encrypt paths: `apaEncryptPassword` outputs go only to header/params fields; `APA_PRINTF` sites print IDs, LBAs, sizes, times — no password field is ever a print argument). `apaPassCmp`'s always-pass behaviour in this build is the documented OSD design (see T3-F11), not a defect. READ.
- **`hddOpen` / `hddFormat` unit range checks** — `hdd_fio.c:608` and `:329` test `f->unit >= BLKIO_MAX_VOLUMES` before indexing `hddDevices[]`. (`hddDevctl`/`hddIoctl2` index through an already-open file's unit instead; see T3-F13 for what they do miss.) READ.
- **`ioctl2Transfer` sub-index itself** — `:267` rejects `arg->sub > fileSlot->nsub`, which is the correct inclusive bound for `parts[0..nsub]`; the defect in T3-F2 is the sector/size sum and mode, not the sub test. READ.
- **`fioDataTransfer` / `hddLseek` window** — both confine `post` to `< 0x1FF9` sectors and reject non-512-aligned sizes/offsets (`hdd_fio.c:243-262`, `:679-705`); the 4 MiB raw-access window is the historic `hdd` device semantic, not a truncation bug. READ.
- **`hddDread` name copy** — already bounds-checked (`strncpy(…, APA_IDMAX)` + explicit terminator, `hdd_fio.c:782-793`), with the unbounded SONY original preserved only as a comment. READ.
- **Journal single-buffer sharing across two units** — `journalBuf` is one static (`journal.c:27`), but every flush collects only the flushed device's dirty entries and flush+reset are atomic under `fioSema` (`cache.c:113-130`), and restore at start is per-device sequential (`hdd.c:342-348`); no cross-device journal mixing found. The journal defects are T3-F5/T3-F6, not sharing. READ.
- **`apaDeleteFixPrev`/`apaDeleteFixNext` 1 GiB merge cap** (`apa.c:255-362`, hard-coded `0x1FFFFF` with an in-source TODO naming `partitionMaxSize`) — upstream-acknowledged limitation that only leaves free space fragmented on delete; no incorrect merge was found (alignment and power-of-two tests at `:283`, `:336` are present). Inventory, no finding. READ.
- **`free.c` free-space walk** — the "Non-SONY" 64-bit guard at `free.c:72` is present in the overflow-sensitive comparison; the odd double loop at `:66-79` terminates (`partMax` strictly halves or breaks). No defect found. READ.
- **`misc.c` time/iLink helpers** — retry loops are bounded (20 iterations, `misc.c:71-92`, `:124-137`); the JST conversion in the non-IOP branch is host-only code. No finding. READ.
- **DES implementation (`password.c:40-522`)** — read as structure only; correctness of a standard DES-ECB against test vectors is not verifiable by reading and no claim is made either way. Its *use* is covered by T3-F11.

## (e) Still unread

- Nothing in the assigned section remains unread: all nine `.c` files, all five assigned headers and `README.md` were read end to end.
- Out-of-section by assignment (not gaps in this section): `iop/hdl_info/*` beyond the head/diff/hash recorded in (a) — sibling agent; upstream PS2SDK `ps2hdd` sources — not fetched, per the pin rule, so the provenance verdict in (a) rests on in-repo evidence (import history, banners, README, in-source markers) and is labelled accordingly; the SDK's `hdd-ioctl.h` field widths (relevant to T3-F2's wrap) live outside this repo and were not read — that sub-claim is INFERRED.
