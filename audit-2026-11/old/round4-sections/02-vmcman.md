# Launchstation Round 4 — Section 02: vmcman internals, end-to-end

Pin: `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` (verified in-clone with `git rev-parse HEAD`; no fetch/pull; `git status --porcelain` empty at start and at finish — read-only throughout).
Repo: `NathanNeurotic/Launchstation`, clone `~/workspace/audit-clones-2026-11-13/Launchstation`.
Rule applied: LESS NOT MORE. No PS2 build or hardware claim — nothing here was compiled or run on a console; every Cat-5 item is structural (loop/call counts read from code). READ = the cited lines were read this round; INFERRED = mechanism/reachability reasoning on top of READ lines, labelled per finding.
Not re-filed, per brief: LAUNCHSTATION-068 (backing validator off-by-one, `mciomanx_backing.c:46`); the `mcdev.c:665-672,788-800,829-842` devctl/ioctl/ioctl2 stubs (clean); the length-checked rename `memcpy` at `mcdev.c:703`; the compile-time-constant superblock `strcpy/strcat` at `main.c` (`mcman_clearsuperblock`) and `ps2mc_fio.c:51-52`; the seven `#if 0` blocks in these files (already LAUNCHSTATION-018).

---

## 1. Coverage ledger (READ, line by line)

| File | Lines | Ranges read |
|---|---|---|
| `iop/vmcman/src/main.c` | 4,398 | 1–4398, every line, in sequential chunks (1–600, 601–1300, 1301–2000, 2001–2700, 2701–3400, 3401–4398), plus targeted re-reads at 240–285, 1760–1810, 2035–2070, 2598–2819, 3355–3570, 3721–3945 |
| `iop/vmcman/src/ps2mc_fio.c` | 1,472 | 1–1472, every line (1–750, 751–1472), plus re-reads at 283–295, 505–650, 1100–1135 |
| `iop/vmcman/src/ps1mc_fio.c` | 766 | 1–766, every line, plus re-reads at 108–130, 260–420, 435–465, 505–560 |
| `iop/vmcman/src/mcsio2.c` | 1,354 | 1–1354, every line (1–700, 701–1354), plus re-read at 100–150 |
| `iop/vmcman/src/exports.tab` | 91 | 1–91 (full export table) |
| `iop/vmcman/include/mcman.h` | 130 | 1–130 (public prototypes + import numbers) |
| `iop/vmcman/src/mcman-internal.h` | 381 | 1–381 (geometry constants, `MCDevInfo` layout, internal prototypes) |
| `iop/vmcman/README.md` | 37 | full (vendoring provenance + documented local changes) |

Supporting reads (context/interaction only, not audited as sections): `iop/vmcman/src/mciomanx_backing.c` (371 lines, full — the local VMC backing layer that `McGetCardSpec`/`McReadPage`/`McWritePage` dispatch to under `BUILDING_VMCMAN`); `iop/vmcman/src/mcdev.c:200-260` (unit→port/slot mapping, for the out-of-scope lead in §6). `git log --follow` per audited file and `git show` of the two post-import commits touching these files (see §2).

Total in-scope: **7,990 lines read in full** (4,398 + 1,472 + 766 + 1,354), plus 683 lines of headers/export table/README.

---

## 2. Local-delta inventory (what is Launchstation's, per README + git history)

Git history in this clone is shallow for this directory: the vendored tree arrived wholesale in the initial commit `944a2fc`; only two later commits touch the four audited files. Everything else local-vs-upstream is distinguished by the README's own list, by `BUILDING_VMCMAN` guards, by `printf` diagnostics, and by `// Unofficial:` markers in the source (READ). Upstream base: PS2SDK `iop/memorycard/mcman` @ `ff7c5f93763d90c8b10bc97fbce5d25939ed94fb` (`README.md:9-13`).

| # | Local delta | Where (pin lines) | Provenance |
|---|---|---|---|
| D1 | VMC backing layer itself (`mciomanx_backing.c`, `BUILDING_VMCMAN` dispatch in page/spec calls) | `mcsio2.c:490-497,530-532,639-641,735-737,797-799` (backing branches of erase/write/read/getcardspec); declarations `mcman-internal.h:289-296` | README:14-22; initial import |
| D2 | Mounted-state preservation: `McDetectCard`/`McDetectCard2` return success immediately for a formatted PS2 VMC instead of re-probing | `main.c:471-474`, `main.c:553-556` | README:19-20; initial import |
| D3 | Startup marker + unconditional `printf` diagnostics in `mcman_open2` (10 sites) and backing erase | `main.c:164-165`; `ps2mc_fio.c:679-681,718-720,860-862,932-934,959-961,973-975,1002-1007,1032-1034,1071-1073`; `mcsio2.c:493` | README:21-22; initial import |
| D4 | Geometry widening for VMC: `MCMAN_MAXSLOT` 4 → 10 under `BUILDING_VMCMAN` (sizes `mcman_devinfos[4][MCMAN_MAXSLOT]` and `mcman_fatcache[2][MCMAN_MAXSLOT]`) | `mcman-internal.h:105-109`; arrays `main.c:60,64` | initial import |
| D5 | uLaunchELF full-metadata restore: `MCMAN_ULE_FULL_INFO` (`0xFEED`) flag rewrites mode/unused/attr in setinfo | `mcman-internal.h:113-114`; `ps2mc_fio.c:445-458`; PS1 twin open-coded as `0xFEED` at `ps1mc_fio.c:562` | initial import (uLaunchELF heritage) |
| D6 | PS1 `linked_block` / cluster bounds patches, marked `// Unofficial:` in source (in `mcman_clearPS1direntry`, `mcman_FNC8ca4`, `mcman_cachePS1dirs`, `mcman_readdirentryPS1`) | `main.c:2681-2685,2850,3085,3847-3849` | initial import (uLaunchELF heritage) |
| D7 | PS1-card re-read across IOP reset: `mcman_probePS1Card2` falls through to `mcman_probePS1Card` when cached state is unknown/PS2; `mcman_probePS1Card` rebuilds header+directory via `mcman_setPS1devinfos` instead of trusting `cardform` | `mcsio2.c:1068-1082` (probePS1Card2 branch), `mcsio2.c:1134-1152` (probePS1Card branch) | commit `760258d` (#335, from saildot4k 9372a47); README:24-35 |
| D8 | Terminated-copy fix for caller `EntryName`: `setinfo2`/`setinfo1` copy `info->EntryName` into a 33-byte NUL-terminated buffer before `strcmp`/`mcman_chrpos`/`mcman_getdirinfo` use | `ps2mc_fio.c:383-402,422`; `ps1mc_fio.c:495-508` | commit `c29d991` (#231) |
| D9 | `private_0/1/2` stat fields only written under `MCMAN_ENABLE_EXTENDED_DEV_OPS` | `ps2mc_fio.c:307-311,354-358` | commit `760258d` |
| D10 | Physical target `mcman_physical`: the same sources built with `BUILDING_XMCMAN` only, embedded in place of the SDK's prebuilt mcman — this is what makes the XMCMAN-only export block (exports 42–52) a shipped Launchstation surface | README:24-35; `exports.tab:63-74` | commit `760258d` |

Everything not listed above in the four audited files is, to the evidence available in this clone, pristine upstream at the vendored pin (INFERRED from the shallow history + absence of local markers). Findings below are filed only where a local delta touches or interacts with the code (D1–D10), or where the brief explicitly ordered an export-surface validation pass; each finding states its basis.

---

## 3. Export-surface inventory (READ)

`exports.tab` is build-dependent — the same sources export three different tables:

- **vmcman** (`BUILDING_VMCMAN`, neither XMCMAN nor XFROMMAN): table `mcman 1.1` (`exports.tab:6-7`); exports 21–25 and 42–52 are `_dummy` (`exports.tab:40-45,75-87`). Live: `McDetectCard, McOpen, McClose, McRead, McWrite, McSeek, McFormat, McGetDir, McDelete, McFlush, McChDir, McSetFileInfo, McEraseBlock, McReadPage, McWritePage, McDataChecksum, McReadPS1PDACard, McWritePS1PDACard, McUnformat, McRetOnly, McGetFreeClusters, McGetMcType, McSetPS1CardFlag`.
- **mcman_physical** (`BUILDING_XMCMAN`): table `mcman 2.3` (`exports.tab:4-5`); additionally live: `McEraseBlock2, McDetectCard2, McGetFormat, McGetEntSpace, McReplaceBadBlock, McCloseAll, McGetModuleInfo, McGetCardSpec, McGetFATentry, McCheckBlock, McSetFATentry, McReadDirEntry, Mc1stCacheEntSetWrFlagOff, McCreateDirentry, McReadCluster, McFlushCache, McSetDirEntryState` (`exports.tab:26-27,34-39,63-74`).
- Validation pattern that *does* exist: every fd-taking export checks `(u32)fd < MAX_FDHANDLES` and `fh->status` before use (e.g. `McClose` `main.c:651-661`, `McRead` `main.c:802-815`, `McWrite` `main.c:838-851`, `McSeek` `main.c:767-780`, `McFlush`, `mcman_dread`). No port/slot-taking export performs the analogous check — see PROPOSED-003.

Static-buffer inventory (Cat 4 evidence base, all READ): `mcman_cachebuf` 36 × 1024 = 36,864 B (`main.c:45`); `mcman_backupbuf` 16,384 B (`main.c:53`); `mcman_devinfos` 4 × `MCMAN_MAXSLOT` × 384 B (`main.c:64`, struct size comment `mcman-internal.h:302`); `mcman_fatcache` 2 × `MCMAN_MAXSLOT` × 2,052 B (`main.c:60`; `McFatCache` = `int[1 + 256*2]` = 513 ints, `mcman-internal.h:122-124`); `mcman_eccdata` 512 B (`main.c:66`); `mcman_pagebuf` 1,056 B (`main.c:36`); `mcman_pagedata` 32 pointers (`main.c:52`); `mcman_replacementcluster` 16 ints (`main.c:58`); `mcman_dircache` 3 × 512 B (`main.c:61`). The 16- and 32-entry arrays are the fixed ceilings the geometry in PROPOSED-001 must respect and doesn't.

---

## 4. Proposed findings

### PROPOSED-001 — Superblock geometry is copied into `MCDevInfo` with no validation, then used as divisors, loop bounds and buffer offsets
- **Title:** Card-supplied geometry (`pages_per_cluster`, `clusters_per_block`, `cluster_size`, `FATentries_per_cluster`, backup blocks) trusted after the superblock copy
- **Category:** 6 (bounds/length validation on card-supplied values)
- **Locations:** `iop/vmcman/src/main.c:1391-1393` (raw 0x150-byte copy from page 0 over the whole geometry prefix of `MCDevInfo`, after only the magic check at `:1383-1386` and a version-digit check at `:1388-1389`); `iop/vmcman/src/main.c:1334-1354` (`mcman_setdevspec` computes sane derived values *before* the copy, and the copy overwrites them); interacting local validator `iop/vmcman/src/mciomanx_backing.c:107-141` (mount-time validation checks only magic, cardtype, `pagesize` ∈ {512, 528} and total file size). Sinks: `main.c:3791-3792,3835` (`McReadDirEntry`: division by `cluster_size >> 9`, which is 0 when the card sets `cluster_size` < 512); `main.c:1435,1439` (`%` and `/` by `clusters_per_block` in `mcman_setdevinfos` itself); `main.c:3766-3768` (`McReadCluster`: `pages_per_cluster` page reads into a 1,024-byte cache slot, `mcman_cachebuf` at `main.c:45`); `main.c:3419,3520-3524` (`mcman_flushcacheentry`: `pmce[16]` indexed by `cluster % clusters_per_block`); `main.c:52,3543,3553` (`mcman_pagedata[32]` indexed by page index up to `clusters_per_block * pages_per_cluster`); `main.c:1181,1186,1195-1215` (`McReadPage`: stack `eccbuf[32]` walked `count = (pagesize + 127) >> 7` times)
- **Problem:** `mcman_setdevspec` first derives geometry from the card *spec* (pagesize/blocksize/cardsize), setting `pages_per_cluster = 1024 / pagesize`, `cluster_size = 1024`, `FATentries_per_cluster = 256`, `clusters_per_block = blocksize / pages_per_cluster`. `mcman_setdevinfos` then overwrites all of it with the first 336 bytes of page 0 — data the card image itself supplies — checking nothing but the 28-byte magic and two version digits. A crafted or corrupted image can therefore set `cluster_size` to 0/256 (divide-by-zero in `McReadDirEntry`, reached from `mcman_setdevinfos` itself at `main.c:1401`), `clusters_per_block` to 0 (divide-by-zero at `main.c:1435`) or to >16 (stack write past `pmce[16]` in flush, read past `mcman_replacementcluster[16]` at `main.c:3738-3742`), and `pages_per_cluster * pagesize` to ≫1024 (each cluster read overruns its 1 KB cache slot into the neighbouring cache entries). Local-delta interaction (basis for filing): for the **physical** target (D10) there is no other gate — the superblock is the first card-controlled data the driver trusts. For the **VMC** target (D1), the local mount validator was added precisely to validate geometry, but it validates only `pagesize` and the *product* `pages_per_cluster * clusters_per_card` against file size; `blocksize`, `pages_per_cluster` alone, `clusters_per_block`, `cluster_size`, `FATentries_per_cluster`, `alloc_offset/end` and the backup-block numbers pass through unchecked in both layers, and `mcman_setdevinfos` re-reads page 0 rather than consuming the validated copy.
- **Fix:** LESS-first: after the copy at `main.c:1393`, reject the card (`return sceMcResNoFormat`) unless the copied fields equal the values `mcman_setdevspec` just derived (`pages_per_cluster`, `cluster_size`, `FATentries_per_cluster`, `clusters_per_block`) and `backup_block1/2 < clusters_per_card / clusters_per_block`. That is one comparison block reusing values already computed — no new tables, no new state. (For VMC, the same check makes the backing validator's partial job whole; do not add a second validator there.)
- **Benefit:** Closes the divide-by-zero, cache-slot overrun and `pmce[16]`/`pagedata[32]` over-index classes at the single point where card geometry enters the driver, for both build targets.
- **Effort:** S
- **Risk:** Low–Med — a non-standard but legitimate card whose superblock extension fields disagree with its spec would now be rejected as unformatted; that disagreement is exactly what the current code cannot survive anyway.
- **Confidence:** High (READ) for the absence of any check and for each sink's arithmetic; INFERRED for on-hardware trap/overflow behaviour (no build or hardware run).

### PROPOSED-002 — `McGetFATentry`/`McSetFATentry` index `ifc_list[ifc_index]` with an unbounded `fat_index` — and card FAT values feed the same path
- **Title:** Unbounded FAT index reaches `ifc_list[]` out-of-bounds in both FAT exports
- **Category:** 6
- **Locations:** `iop/vmcman/src/main.c:3905-3931` (`McGetFATentry`: `ifc_index = (fat_index / FATentries_per_cluster) / FATentries_per_cluster` at `:3911-3915`, then `mcdi->ifc_list[ifc_index]` at `:3917`); `iop/vmcman/src/main.c:3872-3902` (`McSetFATentry`, same arithmetic at `:3880-3886`); `ifc_list` is `u32[32]` inside `MCDevInfo` (`mcman-internal.h:335`). Card-fed caller: `main.c:3813-3828` (`McReadDirEntry` walks `clust = McGetFATentry(..., clust, &clust)` where `clust` is the previous FAT entry masked only with `& ~0x80000000`); `main.c:1597-1643` (`mcman_fatRseek` follows `fat_entry` the same way)
- **Problem:** Neither export checks `fat_index` against the card's FAT size (`max_allocatable_clusters` / `clusters_per_card - alloc_offset`). `fat_index` is (a) a direct argument of two library exports in the physical build (D10; `_dummy` in the vmcman build, `exports.tab:66,68`), and (b) derived from card-supplied FAT/dir data on internal walks: a FAT entry of, say, 0x01000000 yields `ifc_index` = 4096, reading `ifc_list[4096]` — ~16 KB past the array, across the rest of `MCDevInfo` and the following `mcman_devinfos` slots/globals — and the value read is then used as a cluster number for `McReadCluster`. `McSetFATentry` is the write-side twin: the same OOB-derived cluster is read, modified at `fc->entry[fat_offset]`, and marked dirty for flush. The one existing guard pattern in this area is negative-only: several callers test `fat_entry >= -1`/`< 0`, which says nothing about large positive values.
- **Fix:** One guard at the top of each export (or one shared two-line check): `if ((u32)fat_index >= mcdi->max_allocatable_clusters) return sceMcResNoEntry;` (set-variant returns the same). No new machinery; internal callers already handle FAT-walk errors.
- **Benefit:** Removes an OOB read (and a dirty-cache write primitive) reachable from a crafted card image's FAT chain alone, without any misbehaving IOP caller.
- **Effort:** XS
- **Risk:** Low — legitimate FAT indices are by construction below the allocatable-cluster count; the root-dir FAT cache path (`mcman_getFATindex`) is a different, already-bounded array.
- **Confidence:** High (READ) for the arithmetic and the array size; INFERRED for what the OOB read lands on in a given build layout.

### PROPOSED-003 — No port/slot validation on any mcman library export, although the fd exports validate fd
- **Title:** Export surface indexes `mcman_devinfos[port][slot]` (and `mcman_fatcache[port][slot]`) with caller port/slot unchecked
- **Category:** 6 (entry-point validation; latent, same class as LAUNCHSTATION-068)
- **Locations:** Array declarations `iop/vmcman/src/main.c:60` (`mcman_fatcache[2][MCMAN_MAXSLOT]`) and `:64` (`mcman_devinfos[4][MCMAN_MAXSLOT]`), `MCMAN_MAXSLOT` = 10 (VMCMAN) / 4 (physical) at `mcman-internal.h:105-109`. Unguarded first dereferences include `main.c:248-251` (`McGetFormat`), `:255-258` (`McGetMcType`), `:278-281` (`McGetFreeClusters`), `:1330` (`mcman_sparesize`, used by page paths), `:3333-3336` (`mcman_getFATindex`: also indexes `.entry[num]` unchecked), `:3724,3785-3786,3909` (`McReadCluster`/`McReadDirEntry`/`McGetFATentry`), `mcsio2.c:761-800` (`McGetCardSpec`), `mcsio2.c:564` (`McWritePage`), `main.c:1177` (`McReadPage`). Contrast: fd exports validate `(u32)fd < MAX_FDHANDLES` (e.g. `main.c:805,841`)
- **Problem:** Valid ports are 0–1 and valid slots 0–(`MCMAN_MAXSLOT`-1), but nothing enforces either bound; `port` indexes the *4-wide first dimension*, so `port >= 4` (or any negative port/slot) addresses memory outside both arrays entirely, and the many `&mcman_devinfos[port][slot]` sites then read/write `cardtype`/`cardform`/geometry through that pointer for the whole call. Reachability today is the -068 shape: in-tree callers derive port/slot from `mcman_unit2card` masking or from an already-open handle, so no live in-tree path was found — but Launchstation now ships this table as its physical driver (D10) and widens the slot dimension locally (D4), and the backing validator's own off-by-one (-068) shows slot handling at this boundary is already fragile. The brief for this task explicitly ordered this surface checked; it is reported as latent, not live.
- **Fix:** LESS: one file-local predicate used at the top of the ~10 port/slot exports that lack any other gate (`McDetectCard` is the natural funnel for the file-level exports — `McOpen/McGetDir/McDelete/...` already pass through it — so a check there plus the standalone spec/FAT/page exports covers the surface with a handful of lines). Do not add per-function bespoke checks.
- **Benefit:** Converts a whole class of wild-pointer IOP crashes from future/other-module callers into a clean error return, at the one boundary the fd side already defends.
- **Effort:** S
- **Risk:** Low — no in-tree caller passes out-of-range values (they would already be broken).
- **Confidence:** High (READ) for the absence of checks and the array dimensions; reachability INFERRED/latent (no live caller found, by grep of in-tree callers — same disclosure as -068).

### PROPOSED-004 — `McWrite` with a negative length reaches `memcpy` as a huge `size_t` in both write paths; `McRead` is safe in both of its paths
- **Title:** Negative `length` unvalidated at `McWrite` (exports #9) — write1/write2 `memcpy` size inversion
- **Category:** 6 (entry-point validation; latent)
- **Locations:** `iop/vmcman/src/main.c:838-875` (`McWrite` checks fd/status/wrflag only, forwards `length` verbatim); `iop/vmcman/src/ps2mc_fio.c:545-615` (`mcman_write2`: `if (nbyte)` at `:552,565`, then `size = nbyte` when `nbyte` is the smaller value at `:594-597`, `memcpy` at `:599`); `iop/vmcman/src/ps1mc_fio.c:308-375` (`mcman_write1`: same shape, `size = nbyte` at `:360-363`, `memcpy` at `:365`)
- **Problem:** With `length < 0`, `size` becomes that negative int and is passed to `memcpy`, where it converts to a near-4 GiB `size_t` — copying from the caller's buffer over the 1 KB cache slot (`cl_data + offset`) in write2, and the PS1 cache slot in write1, until a fault. The asymmetry proves this is an omission, not a convention: `mcman_read2` guards with `if (nbyte > 0)` after clamping (`ps2mc_fio.c:505-508`), and `mcman_read1` neutralises negatives by clamping through a `(u32)` comparison (`ps1mc_fio.c:267-268`). `McSeek` likewise clamps its result to ≥ 0 (`main.c:798`). Only the two write paths lack any equivalent.
- **Fix:** One line at the export, mirroring the read side: in `McWrite`, `if (length < 0) return sceMcResDeniedPermit;` (or treat as 0). Do not patch both fio files separately.
- **Benefit:** Removes a one-argument memory-corruption primitive at the export boundary; keeps the fix where the fd/status checks already live.
- **Effort:** XS
- **Risk:** Low — no legitimate caller writes a negative byte count.
- **Confidence:** High (READ) for the code path and the read/write asymmetry; reachability INFERRED/latent (needs a caller passing a negative length; EE-side libmc does not generate one in normal use).

### PROPOSED-005 — Card-supplied entry names are still passed to `strlen`/`strcmp`/`strcpy` unterminated — the D8 fix covered only the caller's copy
- **Title:** Unterminated on-card `McFsEntry.name[32]` used as a C string in the directory-search core and in `mcman_dread2`
- **Category:** 6
- **Locations:** `iop/vmcman/src/main.c:2041-2055` (`mcman_getdirinfo`: `strlen(fse->name)` up to three times per entry, result used as the `strncmp` length); `main.c:1405,1411` (`mcman_setdevinfos`: `strcmp(pfse->name, ".")` / `".."`); `main.c:2615` (`mcman_getPS1direntry`: `strcmp(p, pfse[0]->name)` on the PS1 20-byte name); `iop/vmcman/src/ps2mc_fio.c:283-284` (`mcman_dread2`: `strcpy(dirent->name, fse->name)` followed by a defensive `dirent->name[32] = 0` *after* the unbounded copy); contrast the bounded pattern already used at `ps2mc_fio.c:1129-1132` (`mcman_chdir` caps `len` at 32) and the D8 terminated-copy fix at `ps2mc_fio.c:383-390`
- **Problem:** A PS2 directory entry's name field is 32 bytes of card data and may legitimately use all 32 with no terminator (the D8 commit message in `ps2mc_fio.c:383` says exactly this about `EntryName`). The local fix copied the *caller's* `info->EntryName` into a terminated buffer before string use, but the *card's* names — the attacker-influenceable side — are still consumed as C strings in the search core every lookup runs. Consequences range from over-read past the 512-byte entry into the adjacent cache entry (comparisons then depend on neighbouring cache bytes) to, at `ps2mc_fio.c:283`, an unbounded `strcpy` into the caller's dirent whose own author clearly expected ≤32 bytes (hence the `[32] = 0` afterwards, which cannot undo an overflow that already happened).
- **Fix:** Reuse the D8 pattern once, in `McReadDirEntry`'s consumers rather than at every site: the minimal LESS form is (a) `strncpy(dirent->name, fse->name, 32)` at `ps2mc_fio.c:283` (the trailing `[32] = 0` already exists), and (b) in `mcman_getdirinfo`, compute `len` from a single bounded scan (`memchr`-style, cap 32) instead of three `strlen` calls. The two `strcmp(..., ".")` sites in `mcman_setdevinfos` can stay if (b)'s helper is not introduced — list them as residual, or convert to `strncmp(..., 2)`.
- **Benefit:** Card images can no longer make directory lookup read (or, via dread, write) past the name field; also removes up to three redundant `strlen` walks per entry scanned (see PROPOSED-009).
- **Effort:** S
- **Risk:** Low — names of exactly 32 unterminated bytes are the case the current code already mishandles; behaviour for terminated names is unchanged.
- **Confidence:** High (READ) for the unbounded string calls and for the D8 precedent; the *extent* of the dread over-write is INFERRED (the `iox_dirent_t` layout lives in PS2SDK headers outside this repo).

### PROPOSED-006 — PS1 `open`/`getstat`/`setinfo` dereference the dir-entry pointer before checking the lookup's return value
- **Title:** `fse->mode` read before the `r < 0` check in `mcman_open1`, `mcman_getstat1`, `mcman_setinfo1`
- **Category:** 6 (error-path robustness)
- **Locations:** `iop/vmcman/src/ps1mc_fio.c:116-118` (`mcman_open1`), `:443-449` (`mcman_getstat1`), `:511-517` (`mcman_setinfo1`); callee contract at `iop/vmcman/src/main.c:2598-2621` (`mcman_getPS1direntry` returns the error from `mcman_readdirentryPS1` immediately) and `main.c:3841-3869` (`mcman_readdirentryPS1` assigns `*pfse` only after a successful cluster read, `:3857-3861`)
- **Problem:** All three PS1 callers evaluate `fse->mode` (to translate a free entry into `r = -4`/`sceMcResNoEntry`) *before* testing whether the lookup succeeded. When the lookup fails on its first cluster read — card yanked or read error between `McDetectCard` and the operation, the exact failure these functions' error returns exist for — `*pfse` was never assigned, so `fse` is an uninitialised stack pointer and the mode read is a wild dereference inside the IOP. The PS2 counterparts show the intended order: `mcman_open2` initialises `fse1 = NULL` and returns on `r < 0` before any use (`ps2mc_fio.c:716-724`), and `mcman_getstat2` checks `r` first (`ps2mc_fio.c:326-330`).
- **Fix:** Move the existing mode test below the existing `r < 0` return in the three functions (in `open1`, guard the mode test with `r >= 0`). Pure reordering of lines that already exist; no new code.
- **Benefit:** The PS1 error path returns the intended error instead of dereferencing an uninitialised pointer — relevant to D7, which deliberately drives more PS1 re-reads through these paths after IOP resets.
- **Effort:** XS
- **Risk:** Low — success-path behaviour is byte-for-byte unchanged.
- **Confidence:** High (READ) for the ordering and for `readdirentryPS1`'s assign-on-success-only contract; INFERRED that a first-read failure is reachable in practice (card removal mid-operation is the driver's normal error case, not an exotic one).

### PROPOSED-007 — The 16-byte-chunk manual struct copy is open-coded 11 times where `memcpy` is the whole semantics
- **Title:** Hand-rolled `McFsEntry`/`McFsEntryPS1` copy loops ×11 (Cat 2 duplication)
- **Category:** 2 (duplication) / 1
- **Locations:** `iop/vmcman/src/main.c:1789-1796,1855-1864,1884-1893,1960-1969` (four copies into `mfe`/`mcman_dircache`), `main.c:2895-2904` (PS1 variant in `mcman_FNC8ca4`); `iop/vmcman/src/ps2mc_fio.c:415-424,728-737,869-878,1018-1027,1057-1066` (five copies in `setinfo2`/`open2`); counted by the shared `pfsentry/pfseend` idiom — 11 sites, ~10 lines each
- **Problem:** Each site copies exactly `sizeof(McFsEntry)` (or the PS1 struct) in 16-byte `u32[4]` chunks with hand-maintained pointer arithmetic. It is `memcpy(dst, src, sizeof(...))` written out 11 times — ~110 lines that must all stay correct together, and whose loop (`while (ptr < end)`, advancing 16) would silently over-copy by up to 15 bytes if either struct's size ever stopped being a multiple of 16 (both are today, which is the only reason it is safe). This is upstream-inherited text, filed because the directory-entry handling in these same functions is already locally patched (D5, D8, D9) — the copies are the part of those functions a future local fix will have to touch repeatedly.
- **Fix:** Replace each loop with the single `memcpy` it implements (the files already use `memcpy` for the same structs' date fields). Net ≈ −100 lines. No helper function needed — that would be MORE.
- **Benefit:** ~100 fewer lines in the most-patched directory code; the size rounding hazard disappears with the idiom.
- **Effort:** S (mechanical, but each site's dst/src order must be eyeballed — two sites copy in the reverse direction, `ps2mc_fio.c:1018-1027,1057-1066`)
- **Risk:** Low — semantics identical for the current struct sizes; the two reverse-direction sites are the only trap.
- **Confidence:** High (READ) for the count and the equivalence at current sizes.

### PROPOSED-008 — The PS1 cache write-flag bit computation `(x+1) − ((x+1) & ~7)` is open-coded 11 times
- **Title:** Modulo-8 `wr_flag` bit idiom duplicated across PS1 paths in both files
- **Category:** 2 (duplication)
- **Locations:** Live idiom at `iop/vmcman/src/main.c:2666-2672,2886-2892,2925-2931,2962-2968,2986-2992` (clear/FNC/cachePS1dirs paths, the last two ×3 inside `mcman_cachePS1dirs`) and `iop/vmcman/src/ps1mc_fio.c:187-193,239-245,531-536,703-709` (`open1` ×2, `setinfo1`, `close1`) — 11 live sites, 6–8 lines each, computing `(x+1) % 8` as `(x+1) − ((x+1) & ~0x7)` behind a dead-or-trivial sign guard
- **Problem:** Every PS1 site that marks a dir entry dirty re-derives the same bit index with the same sign-guard scaffolding (the guards' `#if 0` halves are already filed as LAUNCHSTATION-018 and are *not* re-filed here; the live lines outside those blocks are the duplication). Any correction to the bit mapping has to be made 11 times in two files — in precisely the PS1 dir-entry code the local D6 patches already touched three times.
- **Fix:** Replace each live block with the one-liner it computes: `mce->wr_flag |= 1 << ((x + 1) & 7);` for the reachable inputs (all callers pass a dir index in −1..14, for which the two forms agree; the sign-guard scaffolding exists only for inputs no caller produces). Net ≈ −60 lines, no helper needed.
- **Benefit:** One obvious form of a safety-relevant bit index; the PS1 delete/open/close paths become auditable at a glance.
- **Effort:** S
- **Risk:** Low–Med — equivalence is exact for non-negative `x+1`; a caller with `freeclink < −1` would diverge, and none exists (indices come from `mcman_readdirentryPS1`'s 0..14 range or a validated handle), but the change should be verified site by site, not sed-applied.
- **Confidence:** High (READ) for the site count and the arithmetic identity on the reachable range; INFERRED that no out-of-range caller exists (based on the handle/dir-index provenance read in §1).

### PROPOSED-009 — Directory scans re-walk the FAT chain from the directory head for every entry (non-root directories)
- **Title:** `mcman_getdirinfo` is O(N²) in FAT walks for subdirectories; the FAT cache serves only the root
- **Category:** 5 (structural performance; no timing claimed)
- **Locations:** `iop/vmcman/src/main.c:2018-2077` (`mcman_getdirinfo` calls `McReadDirEntry` once per entry index `i` in `0..pfse->length-1`); `main.c:3781-3829` (`McReadDirEntry`: for `cluster != 0` nothing is cached, and reaching index `k` walks `k / (cluster_size>>9)` FAT links from the head at `:3813-3828`; the `mcman_fatcache` fast path at `:3796-3811` applies only when `cluster == 0`); same per-entry pattern in `mcman_getentspace` (`main.c:1800-1807`) and the subdir emptiness scan in `mcman_delete2` (`ps2mc_fio.c:1349-1359`)
- **Problem:** For a subdirectory with N entries spanning C clusters, a single name lookup walks ≈ C²/2 FAT links (each link is a `McGetFATentry` = two cluster-cache lookups), because every `McReadDirEntry` call restarts at the directory's first cluster. The root directory escapes via the fatcache; every real save folder is a subdirectory. N is card-supplied (`pfse->length`, see PROPOSED-001/005 context), so a crafted directory also gets quadratic work per lookup on the IOP. Cache hits make the common small-folder case cheap in practice — this is a structural bound, not a measured slowdown.
- **Fix:** LESS option only: extend the existing root fatcache condition in `McReadDirEntry` to remember the last (cluster, index, clust) triple for *any* directory and resume from it when the next request is sequential — a few lines beside code that already does this for cluster 0. If that is judged MORE, the alternative is to leave the algorithm and cap `pfse->length` in `mcman_getdirinfo` at the directory's allocatable span (one comparison, shared with PROPOSED-002's bound) — pick one, not both.
- **Benefit:** Subdirectory scans become linear in FAT walks; the crafted-directory quadratic-work case is bounded either way.
- **Effort:** M for the resume-triple; XS for the cap-only variant
- **Risk:** Med for the resume variant (cache-invalidation correctness on dir mutation); Low for the cap variant
- **Confidence:** High (READ) for the walk counts; impact on real folders INFERRED (typical save directories are small and cache-resident).

### PROPOSED-010 — VMCMAN diagnostics print unconditionally from the `mcman_open2` create path (local D3 delta)
- **Title:** Ten `printf` sites in `open2` are not gated by the driver's own `DPRINTF` switch
- **Category:** 5
- **Locations:** `iop/vmcman/src/ps2mc_fio.c:679-681,718-720,860-862,932-934,959-961,973-975,1002-1007,1032-1034,1071-1073` (all under `#if defined(BUILDING_VMCMAN)`, none under `DEBUG`/`SIO_DEBUG`); the driver's conditional logging macro exists at `mcman-internal.h:81-92` (`DPRINTF` compiles out unless `DEBUG`/`SIO_DEBUG`)
- **Problem:** Every create-file/create-dir through the VMC device emits up to six formatted console prints (request, cachedirentry result, parent read, findfree, target read, flush) on the IOP, in the shipping build, forever — the README (D3) documents diagnostics as a deliberate local addition for bring-up, but bring-up is over and the prints sit in a hot, latency-visible path (folder creation in the filer). Every other diagnostic in these four files goes through `DPRINTF` and compiles away.
- **Fix:** Delete the ten `printf` blocks (keep the startup marker at `main.c:164-165`, which is one line at load). If any are still wanted, converting them to `DPRINTF` is the fallback — but deletion is the LESS answer for code whose stated purpose was diagnosis of a now-working path.
- **Benefit:** The create path loses up to six IOP console writes per call; ~30 lines of build-conditional noise leave the most locally-patched function in the file.
- **Effort:** XS
- **Risk:** Low — loses live diagnostic output the next time VMC create breaks; git history and `DPRINTF` remain available.
- **Confidence:** High (READ) for the sites and the gating contrast; the per-print cost is INFERRED (no timing measured).

### PROPOSED-011 — VMCMAN's `MCMAN_MAXSLOT` 10 costs ≈33.8 KB of IOP statics over the physical build's 4, for slots the device layer may not address
- **Title:** Slot-dimensioned statics (`mcman_devinfos`, `mcman_fatcache`) sized by the local D4 widening
- **Category:** 4 (large static buffers)
- **Locations:** `iop/vmcman/src/mcman-internal.h:105-109` (`MCMAN_MAXSLOT` 10 vs 4); `iop/vmcman/src/main.c:60` (`mcman_fatcache[2][10]` = 2 × 10 × 2,052 B = 41,040 B vs 16,416 B at 4); `main.c:64` (`mcman_devinfos[4][10]` = 15,360 B vs 6,144 B at 4 — 384 B/entry per `mcman-internal.h:302`); backing array likewise ×10 at `mciomanx_backing.c:26`
- **Problem:** The widening is a local delta (D4) and its cost is concrete: +24,624 B of FAT cache and +9,216 B of device-info statics — ≈33.8 KB of the IOP's 2 MB — held for slots 4–9. Whether any flow can populate them is doubtful from the device side (see the §6 lead: the VMCMAN unit→slot mapping masks with `MCMAN_MAXSLOT - 1` = 9, a non-contiguous mask), and no in-tree code found in this pass iterates slots beyond the two physical ports except through that mapping. This is filed as a question with numbers, not as a proven waste: if a real 10-slot consumer exists (e.g. a VMC-per-slot scheme outside `mcdev.c`), the cost is justified and this dissolves.
- **Fix:** If no consumer is identified: drop the VMCMAN override so both targets use 4 (deleting the `#ifdef` at `mcman-internal.h:105-109` is the whole change), reclaiming ≈33.8 KB. If a consumer exists, document it in the README next to the override instead.
- **Benefit:** ≈33.8 KB IOP RAM reclaimed, or a documented reason it is spent — either outcome removes an unexplained local divergence from upstream.
- **Effort:** XS (code) / S (proving the negative across EE-side VMC users)
- **Risk:** Med — reducing the slot count under a real multi-VMC feature would break it silently; do not apply without the consumer check.
- **Confidence:** High (READ) for the byte arithmetic; INFERRED that slots 4–9 are unpopulated (based on the `mcdev.c` mapping read for §6 and the absence of other slot sources in the audited files — EE-side usage was out of this task's scope).

---

## 5. Checked-and-clean / dissolved (do not re-derive)

- **fd validation on the handle exports — clean.** `McClose/McFlush/McSeek/McRead/McWrite/mcman_dread` all check `(u32)fd < MAX_FDHANDLES` and `fh->status` (and rd/wr/drd flags where relevant) before use (`main.c:651-661,767-780,802-830,838-870` and the flush/dread twins). This is the pattern PROPOSED-003/004 extend to port/slot/length.
- **`McRead` negative/huge length — dissolved.** `mcman_read2` clamps to `filesize - position` and guards `nbyte > 0` (`ps2mc_fio.c:500-508`); `mcman_read1` clamps through a `(u32)nbyte` comparison, which converts a negative length into a clamp to the remaining file size (`ps1mc_fio.c:267-268`). Only the write side is exposed (PROPOSED-004).
- **Per-cluster `memcpy` sizes in read1/read2/write1/write2 — clean (given sane geometry).** Every copy is bounded by `cluster_size - offset` or the PS1 `MCMAN_CLUSTERSIZE - offset` remainder (`ps2mc_fio.c:513-529,592-599`; `ps1mc_fio.c:280-295,358-365`). The exposure is the geometry that feeds `cluster_size`, which is PROPOSED-001, not these loops.
- **`McGetDir` `maxent` — clean as an export contract.** `mcman_getdir2` decrements `maxent` per emitted entry and also stops at the directory's entry count (`ps2mc_fio.c:1240-1310` region); a negative `maxent` still terminates at the directory end. `mcman_getdir1` is additionally bounded by the 15 PS1 entries (`ps1mc_fio.c:595-660` region). The caller owns a `maxent`-sized output array, as with the SDK's own libmc.
- **`mcman_curdirpath` copy — clean.** `strncpy(p, dirname, 1023)` + explicit `[1023] = 0` into the 1,024-byte static (`ps2mc_fio.c:1191-1193`). `mcman_PS1curdir` likewise `strncpy(..., 63)` into 64 bytes (`ps1mc_fio.c:610`).
- **PS1 linked-chain walks — mostly clean after the D6 patches, two by construction.** `mcman_readdirentryPS1` bounds-checks `cluster` (`main.c:3847-3849`); `mcman_cachePS1dirs` bounds-checks `linked_block` and tracks visited entries in `cluster_t[]` (`main.c:3085-3105`); `mcman_FNC8ca4` bounds its walk (`main.c:2850`); `mcman_fatRseekPS1`/`mcman_fatWseekPS1` are counter-bounded by `position / cluster_size`, so a cyclic chain cannot loop forever (`main.c:2750-2820` region); `mcman_clearPS1direntry` terminates on cycles because each visit rewrites the entry's mode class (`0x5x`↔`0xAx`) before following the link (`main.c:2656-2715`). Residual chain exposure is the PS2 FAT side (PROPOSED-002).
- **`sio2packet_add` command indexing — dissolved for the closed caller set.** `mcman_cmdtable[(cmd << 1) + 1]` is read at `mcsio2.c:107-108,118` *before* the `(cmd - 1)` range return at `:120-121`, which would matter for an arbitrary `cmd`, but the function is file-local in effect: every caller passes a literal in `0x00..0x11` or the two sentinels handled at `:95-104`, and `0x11` is the table's last entry (36 bytes, `mcsio2.c:36-54`). `sio2packet_add_funcs_array[(cmd - 1)]` at `:123` is only reached for `1..16`. Not an export; no external caller exists in-tree.
- **`McDataChecksum` (export #20) — clean.** Fixed 128-byte input walk and 3-byte ECC output by definition (`main.c:1236-1262`); callers pass page buffers.
- **`McEraseBlock` (v1.1 form) hardcoding slot 0 — clean/by ABI.** `main.c:1165-1168`; the slot-ful form is `McEraseBlock2` in the XMCMAN build.
- **`McGetEntSpace` on non-PS2 cards — semantic wart, not a bounds issue.** `main.c:874-893`: for PS1/PDA it returns `McDetectCard`'s success value without computing anything. Wrong-ish answer, no memory unsafety; upstream semantic, noted here so it isn't re-filed as Cat 6.
- **`mcman_writecluster`'s bad-block scan stopping at 16 entries — consistent, not a bug.** `main.c:2098-2107` scans `bad_block_list[0..15]`, matching the 16 replacement slots the rest of the driver maintains (`mcman_replacementcluster[16]`, `main.c:58`); entries 16–31 of the superblock list are format-time data (consumed in `mcman_setdevinfos`' allocatable walk at `:1437-1441`, which does scan all 16 it needs — the array there is the same list; no OOB either way).
- **Mounted-state early returns (D2) — checked, consistent.** Both `McDetectCard` (`main.c:471-474`) and `McDetectCard2` (`main.c:553-556`) gate on `cardtype == PS2 && cardform == 1` and fall through to the full probe otherwise; the PS1 re-read delta (D7) composes with them because a PS1 card never satisfies the PS2 gate.
- **D7 PS1 re-read branches — checked, no new finding.** `mcsio2.c:1068-1082,1134-1152` preserve the old returns for genuinely-cached PS1/PDA cards (`cardform > 0` → succeed, `< 0` → NoFormat) and only rebuild when the cached type is neither; `mcman_probePS1Card`'s rebuild path invalidates handles and clears the cache before `mcman_setPS1devinfos`, matching the insertion path's hygiene.
- **`mcman_flushcacheentry` static state — noted, not filed.** The function keeps `clusters_per_block/blocksize/pagesize/...` in `static` locals (`main.c:3418`) and a `static u8 eccbuf[32]` (`:3422`); mcman is single-threaded IOP code with one caller chain (`McFlushCache`), so no re-entrancy path was found in-tree. The `pmce[16]` indexing inside it is filed as a sink of PROPOSED-001 (card geometry), not as a statics issue.
- **Build-variant dead regions in `mcsio2.c` — inventory, not Cat 1.** The SIO2/SECRMAN halves compile out under `BUILDING_VMCMAN` and the flash halves under `BUILDING_XFROMMAN`; all three targets (vmcman, mcman_physical, and the SDK's xfromman lineage) share the file. Deleting any branch breaks a sibling target.
- **`_start` exported twice in `exports.tab` (slots 0 and 4) — inventory.** `exports.tab:9,13`; upstream ABI layout, shared with the SDK's own mcman table.
- **The seven `#if 0` blocks in these files — already filed.** `main.c:2913,3360,3372`; `ps1mc_fio.c:175,189,227,525` = LAUNCHSTATION-018. PROPOSED-008 covers only the *live* duplicated idiom outside those blocks.

## 6. Out-of-scope lead for the coordinator (not a finding of this section)

- **`mcman_unit2card` VMCMAN slot mask is not contiguous** — `iop/vmcman/src/mcdev.c:221-223` (READ as supporting context): `mcman_mc_slot = unit & (MCMAN_MAXSLOT - 1)` with `MCMAN_MAXSLOT` = 10 gives mask `9` (`0b1001`), so device units map only to slots {0, 1, 8, 9} and units 2–7 alias onto them. This is `mcdev.c`, which was Round 3's file, not this task's — but it is the other half of PROPOSED-011's question (whether slots 2–7/4–9 are reachable at all) and, if units > 9 are ever presented, an aliasing bug in its own right. Route to whoever owns `mcdev.c` next round; do not fold it into this section's numbers.

## 7. Method notes

- Local-vs-upstream calls rest on: README provenance (§2), `git log --follow` showing only `944a2fc` (import), `c29d991` and `760258d` touching the audited files, and in-source local markers (`BUILDING_VMCMAN` guards, `printf` diagnostics, `// Unofficial:` comments). Where the shallow history cannot separate a hunk from the vendored import, the finding says so and rests on a local interaction (D1–D10) instead.
- No secret-like values were encountered in these files. No files in the clone were modified; the only write is this section file.
