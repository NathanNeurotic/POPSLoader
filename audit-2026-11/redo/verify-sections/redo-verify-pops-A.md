# Adversarial verification — Redo-POPSLoader, chunk A (tarball partition drivers + block cache)

Verifier: subagent, refute-first re-derivation. Sources: `Redo-POPSLoader.md` (finding texts),
clone pin `29272cddbf0122f14e76bc3bdd75e3b46aa870be` (not needed for this tarball-scoped chunk),
tarball tree under `/tmp/bdma-verify/BDMAssault-mx4sio/…/BDMAssault-mx4sio` (note: the tree was
re-extracted mid-session with one extra nesting level; all key lines were re-spot-checked at the
corrected root and are byte-identical to the first read — `part_driver_gpt.c` md5
`9e636e58e1196ee632d9f5957a3742b9`, `bd_cache.c` md5 `3d8110834ef2bcc7735195205b833435`).
All `__bdm_assault` / `__usbd_bd_assault` mirrors were diffed against the primaries: identical
except `#include` path prefixes, so every verdict below applies to both copies.

## Cross-cutting trace (applies to 001 / 004 / 006 / 036)

- **Read contract — CONFIRMED `count × sectorSize`.** The only leaf block device in the tarball is
  USB SCSI (`usbmass_bd/src/scsi.c`; the ATA/MX4SIO leaves are not in this tree).
  `scsi_cmd_rw_sector:118` issues `queue_cmd(…, bd->sectorSize * sectorCount, write)`;
  `scsi_read:207` / `scsi_write:236` advance the buffer by `sc * bd->sectorSize`;
  `usb_queue_cmd` (`usb_mass.c:444`) passes `data_len` straight into the BOT CBW and
  `usb_bulk_transfer` chunks only per-URB (4096 B), never clamping the total. `max_sectors = 128`
  (`usb_mass.c:815`) caps sectors per command, not bytes. So a 1-sector read really DMAs
  `sectorSize` bytes into the caller's buffer on the raw path.
- **`sectorSize` provenance — unvalidated, device-controlled.** Sole assignment:
  `scsi.c:173 bd->sectorSize = getBI32(&rcd.block_length)` (READ CAPACITY verbatim, RE-POPS-005).
  No range/power-of-two check anywhere in the tree (grep over all `sectorSize` uses). Real-world
  values >512 exist (4096-native enclosures, 1024/2048 optical/MO, 520-byte DIF drives), and a
  hostile/broken device can report anything, including 0 or <128. `scsi_connect:279` even discards
  `scsi_warmup`'s return value and connects the device unconditionally.
- **Cache mediation — the whole-device path is NOT raw.** `bdm.c:60` wraps every whole device
  (`parNr == 0`) in `bd_cache_create`, and `bdm_try_mount:156` hands partition/FatFs drivers
  `mount->cbd != NULL ? mount->cbd : mount->bd`. Partition devices (`parNr != 0`) get **no** cache
  and are probed with the raw `bd`. This mediation is what drifts 001 and weakens 036 below.
  FatFs in this tree is fixed at `FF_MIN_SS == FF_MAX_SS == 512` (`ffconf.h:196-197`), so nothing
  downstream rescues a non-512 device either.

---

### RE-POPS-001 — VERIFIED-DRIFT

Evidence:
- `part_driver_gpt.c:36` `AllocSysMemory(ALLOC_FIRST, 512 * 2, NULL)`; `:43-44` header at
  `buffer+0`, entries at `buffer+512`; `:47` header `bd->read(bd, 1, pGptHeader, 1)`;
  `:80` entry-sector read into `buffer+512`, count 1. `part_driver_mbr.c:28` allocates
  `sizeof(master_boot_record)` — re-derived from the packed struct in `mbr_types.h`:
  218+6+216+4+2 + 4×16 + 2 = **512 bytes exactly**; `:37` reads 1 sector into it.
- Read contract `count × sectorSize` confirmed end-to-end (cross-cutting trace). Overflow
  arithmetic re-derived: S=1024 → header read overruns its 512 half by 512 (still inside the
  1024 allocation), entry read overruns the allocation end by 512; S=2048 → 1536 / 1536;
  S=4096 → **3584 / 3584**. The report's "up to 3,584 bytes" is the S=4096 case and is correct.
  MBR overrun = S−512 in all cases. `entriesPerSector` (`:69`) uses the real `sectorSize` while
  the entry buffer is one fixed 512 half — the internal inconsistency the report cites is real.
- Proposed fix (size scratch from `sectorSize`; reject non-power-of-two outside [512, 4096]
  before parsing) is sane and minimal; the single-point variant in RE-POPS-005 would also close
  the input, but the per-parser defence is justified for the raw-probe path below.

Reasoning (why DRIFT, not VERIFIED): the mechanism — fixed 512-byte scratch vs a
`sectorSize`-scaled transfer — is exactly as claimed, and the overflow is reachable. But on the
**primary whole-device first-touch path the report describes, the overrun does not land in these
buffers**: the parsers receive the cached device (`bdm.c:156`), and `bd_cache._read` for count 1
never writes more than `count * 512` bytes into the caller's buffer (`bd_cache.c:86,122` memcpy);
the oversized transfer lands in the cache's own 4 KiB slot — that is RE-POPS-004's overflow,
which fires first. The direct scratch-buffer overrun as written occurs on the **raw path**:
`part_connect_gpt` has **no** `sectorOffset` guard (contrast `part_driver_mbr.c:24-25`), so GPT
is probed against every partition device with the uncached `bd`, and its LBA-1 read overflows the
1024-byte allocation before the signature check can reject — on every partition of a >512-sector
device. MBR's raw overflow is reachable only for a crafted offset-0 partition (MBR's own guard
skips all normal partitions). Corrected scope: mechanism and numbers stand; whole-device
manifestation is duplicated by / relocated to RE-POPS-004, direct manifestation is the
partition-probe path. Suspected-duplicate flag: **001 ↔ 004 share the `sectorSize != 512` root
cause and overlap on the whole-device path; distinct buffers, not a full duplicate.**

---

### RE-POPS-004 — VERIFIED

Evidence:
- `bd_cache.c:8` `SECTORS_PER_BLOCK 8` (comment "8 * 512b = 4KiB"), `:17`
  `cache[BLOCK_COUNT][SECTORS_PER_BLOCK*512]`, `:85-86` and `:120-122` offset
  `(sector - cached) * 512` + `memcpy(…, count * 512)`, `:116` fill
  `c->bd->read(c->bd, sector, c->cache[blkidx_best], SECTORS_PER_BLOCK)`.
- `bd_cache_create:155-194` copies `bd->sectorSize` into the wrapper (`:184`) but never compares
  it to 512 — no guard anywhere (grep). Created for every whole device: `bdm.c:60`
  (`parNr == 0` only), and `bdm_try_mount` prefers the cached device, so this is the default path.
- Re-derived fill overflow: 8×S bytes into a 4096-byte slot — S=1024 → 8192 (overrun 4096);
  S=2048 → 16384 (12288); S=4096 → 32768 (**28672**). The report's "8 × 4096 = 32 KiB into a
  4 KiB slot" is exact. Even S=520 (DIF) overflows by 64 bytes. For any S≠512 the `* 512` offset
  / memcpy arithmetic also serves wrong bytes without overflowing, as claimed; the count≥8
  direct path (`:61-64`) bypasses the cache and is the only unaffected route.
- Fix check: returning NULL / the raw `bd` for `sectorSize != 512` is tolerated by the caller —
  `bdm.c:60,78,156` all branch on `cbd != NULL` — so the proposed refusal degrades to uncached
  I/O cleanly. Sane, LESS-NOT-MORE compliant.

### RE-POPS-006 — VERIFIED

Evidence:
- Only validation after the signature check (`part_driver_gpt.c:57`) is the per-entry LBA test at
  `:105`; the TODO at `:65-66` concedes revision/header-size/CRCs are unchecked, exactly as cited.
  `gpt_types.h:35-36` confirms `partition_count` (u32) and `partition_entry_size` are header fields.
- (1) Unbounded scan: loop at `:73` is bounded only by `partition_count` and `endOfTable`
  (set only on an all-zero type GUID, `:97-102`); one `bd->read` per table sector (`:77-80`).
  A hostile header/table with no empty entry drives reads to the end of the device and, on the
  raw path, out only when reads fail. Through the cache it is worse than the report states:
  cache reads never report failure (RE-POPS-018), so the "until reads start failing" exit does
  not exist on the whole-device path. The header's own `first_lba`/`last_lba` used by the `:105`
  check are themselves unvalidated, further weakening it.
- (2) Entry size ignored: `partition_entry_size` has **zero uses in any `.c` file** (grep over
  both copies); entries are strided by array indexing at `sizeof(gpt_partition_table_entry)` =
  16+16+8+8+8+72 = **128** (re-derived from `gpt_types.h:46-54`). Any other legal entry size
  (e.g. 256) is parsed at wrong offsets, as claimed.
- (3) Divide-by-zero: `entriesPerSector = bd->sectorSize / 128` (`:69`) is 0 iff
  `sectorSize < 128`; `i % entriesPerSector` / `i / entriesPerSector` at `:77,80` then divide by
  zero. Reachability is narrow but real: it needs a device reporting a 1–127-byte block length
  via the unvalidated `scsi.c:173` path (a 0 value traps earlier, in `scsi_warmup`'s own printf
  divisions at `scsi.c:176` — RE-POPS-005's site). One correction of flavour, not verdict: the
  IOP is MIPS, where integer divide-by-zero yields an undefined quotient rather than an x86-style
  trap, so the concrete failure is a garbage/infinite scan loop, not a clean exception.
- Fix check: header_size range, entry-size equality/stride, count capped against device size,
  `entriesPerSector > 0` — all cheap pre-scan validations, sane.

### RE-POPS-013 — VERIFIED

Evidence:
- `part_driver.c:52-80` read in full: `part_read` / `part_write` check only
  `part == NULL || part->bd == NULL` (`:56,71`), then forward
  `sector + bd->sectorOffset` with the caller's `count` (`:64,79`).
  `sectorCount` appears **nowhere** in `part_driver.c` (grep: NONE) — the partition's own bound
  field, set by both parsers, is never consulted by the only layer that could enforce it.
- No caller-side constraint defeats this: FatFs derives its requests from on-disk BPB metadata
  (device-controlled), and `diskio.c:131-132` hands FatFs the partition's `sectorCount` as the
  volume size, so corrupt FS metadata translates directly into out-of-partition requests that
  this layer passes through, writes included.
- Fix check: `sector + count > bd->sectorCount → -1` in both directions is correct against the
  partition device (`bd` here is `g_part_bd[]`, whose `sectorCount` is the partition length);
  `count` is u16 promoted into u64 arithmetic, no widening trap in practice. Two lines per
  direction, LESS-NOT-MORE compliant.

### RE-POPS-014 — VERIFIED

Evidence:
- `gpt_types.h:51`: `last_lba` documented "Last LBA (inclusive, usually odd)".
  `part_driver_gpt.c:143`: `sectorCount = last_lba - first_lba` — no `+1`; every GPT partition
  loses its final sector, and a single-sector partition (`first == last`) gets `sectorCount 0`.
  Report's off-by-one is exact.
- Inverted range: the only check, `:105`, tests `first_lba < header->first_lba` and
  `last_lba > header->last_lba` **separately**; `last_lba >= first_lba` is never tested. An entry
  with `first_lba=100, last_lba=50` inside a header range of [34, …] passes both tests, and
  `sectorCount` underflows in u64 to 2⁶⁴−50 — "near-2^64 / whole address space" as claimed.
  Impact is compounded by RE-POPS-013 (nothing downstream re-bounds it), but the mechanisms are
  distinct — not a duplicate.
- Fix check: `+1` plus adding `last_lba < first_lba` to the `:105` rejection is exactly minimal.

### RE-POPS-015 — VERIFIED

Evidence (`part_driver_mbr.c:64-91` read in full):
- Loop skips only `sector_count == 0` (`:67`); every other entry is mounted verbatim (`:82-90`).
  No test of `first_lba + sector_count` against `bd->sectorCount` anywhere in the file — a
  partition may claim space past the end of the device, and RE-POPS-013 passes later I/O through.
- `partition_type == 0x00` with non-zero count is mounted (type is stored into `parId` at `:86`
  but never used as a filter); extended types 0x05/0x0F/0x85 receive no EBR following and are
  mounted as data partitions; the TODO at `:72` ("Filter out unsupported partition types") is
  present and unimplemented, as cited. Only `primary_partitions[0]` is tested for the GPT
  protective type 0xEE (`:55`).
- Fix check: reject type 0, skip/follow extended, require
  `(u64)first_lba + sector_count <= bd->sectorCount` — fields are u32 (`mbr_types.h:31-32`), the
  widened sum cannot overflow u64. Sane and minimal.

### RE-POPS-018 — VERIFIED

Evidence:
- `bd_cache.c:116-117`: `c->bd->read(c->bd, sector, c->cache[blkidx_best], SECTORS_PER_BLOCK);`
  return value discarded; `c->sector[blkidx_best] = sector;` unconditional. `:120-123` then
  copies `count` sectors out and `return count` (success).
- The underlying read genuinely fails in this tree: `scsi_read` returns `-EIO` after 16 retries
  (`scsi.c:195-203`); it is all-or-nothing (count or −EIO), so "failed or short" in the report
  resolves to "failed" for the only leaf driver — no drift, the cache discards either way.
- Consequence chain verified end-to-end: on a failed refill the slot keeps its previous bytes
  (or uninitialised `AllocSysMemory` contents on first use — the report's hedge is correct, the
  allocator does not zero) while `sector[]` now labels them as the requested sector;
  `diskio.c:72-74` maps `res == count` to `RES_OK`, and the cache always returns `count`, so
  FatFs receives garbage as a successful read. This is the purest form of the claimed defect.
- Fix check: require the fill result to equal `SECTORS_PER_BLOCK` (the leaf contract returns
  `count` on success), otherwise leave the slot at the `0xffffffffffffffff` sentinel and return
  the error. Sane, minimal. Interaction note: this finding is what masks RE-POPS-036's trigger
  and removes RE-POPS-006(1)'s exit condition on the cached path.

### RE-POPS-029 — VERIFIED

Evidence:
- `bd_cache.c:160-162`: two `AllocSysMemory` calls (`cbd`, then `c`); first dereference is
  `c->bd = bd` at `:166` with no NULL check on either result; `cbd` is dereferenced from `:179`.
  A NULL `c` is a write through address ~0 on the IOP; a NULL `cbd` crashes at `:179`.
- Failure is realistic, not theoretical: `sizeof(struct bd_cache)` re-derived as
  131,072 (cache array) + 128 (weights) + 256 (sectors) + pointer/padding ≈ **131,464 bytes**
  per call (see RE-POPS-052), the largest single allocation on the connect path.
- Caller tolerance verified: `bdm.c:60` stores the result and `bdm.c:78,156` both branch on
  `cbd != NULL`, so returning NULL on allocation failure degrades to uncached I/O exactly as the
  report claims ("`cbd` is already allowed to be NULL there" — correct).
- Fix check: check both allocations, free whichever succeeded, return NULL. Minimal and correct;
  it also plugs the secondary leak of the first allocation when only the second fails.

### RE-POPS-036 — WEAKENED

Evidence:
- The code defect is exactly as cited: `part_driver_mbr.c:37-43` — on `bd->read(...) < 0` the
  function does `return rval;` with **no** `FreeSysMemory(pMbrBlock)`. Every other exit frees:
  bad signature `:50`, GPT-protective `:58`, normal exit `:97`; the allocation-failure return
  `:33` precedes any allocation. Leak size re-derived: `sizeof(master_boot_record)` = **512
  bytes** (see RE-POPS-001). GPT's parser frees on all of its read-failure paths by contrast
  (`part_driver_gpt.c:52,88`).

Reasoning (true scope is narrower than claimed): the report presents this as a per-device leak
on the hot plug/unplug path ("each unreadable or non-MBR device that fails at the read step
leaks 512 bytes"). In the current wiring that trigger is **masked on the whole-device path**:
`part_connect_mbr` receives the cached device (`bdm.c:156`), and `bd_cache._read` for count 1
**never returns < 0** — hit and miss paths both `return count` unconditionally
(`bd_cache.c:87,123`; RE-POPS-018). A genuinely unreadable device therefore never takes the
leaking branch; a merely non-MBR device reads fine, fails the signature check, and frees
correctly. The branch remains reachable only where MBR is probed on an **uncached** device whose
read can fail — partition devices get no cache, but MBR's own `sectorOffset != 0` guard
(`:24-25`) skips all normal partitions, leaving crafted offset-0 partitions (e.g. an MBR entry
with `first_lba == 0`) and any future cache-less configuration. Verdict: real missing free,
one-line fix is correct and worth taking, but today it is a latent leak on a narrow path, not
the routine per-insertion leak described. (If RE-POPS-018 is fixed first, this finding's scope
widens back to the report's version — the two must be sequenced together.)

### RE-POPS-052 — VERIFIED

Evidence (all figures re-derived):
- `bd_cache.c:8-9,17`: `cache[32][8 * 512]` = **131,072 bytes = 128 KiB** of payload per cache
  (≈131,464 B total struct with weights/sectors/pointer), allocated per whole device in
  `bdm.c:59-60` (`parNr == 0 → bd_cache_create`).
- Device ceiling: `NUM_DEVICES 2` in both `usbmass_bd/src/scsi.c:47` and
  `usbmass_bd/src/usb_mass.c:93` (and both `__usbd_bd_assault` mirrors) → at most 2 caches →
  **256 KiB = 12.5% of the IOP's 2 MiB**, as claimed, before USBD pools / FatFs / stacks.
- "No justification in tree": the only comments at the defines state the arithmetic itself
  (`// 8 * 512b = 4KiB`, `// 32 * 4KiB = 128KiB`); a grep of `libbdm/` for any benchmark or
  rationale text returns nothing. The workload characterisation (FAT/directory scans) is fair.
- Fix check: reducing `BLOCK_COUNT` to 8 (32 KiB/device, freeing up to 192 KiB across two
  devices — arithmetic checks) is a one-define change; the report honestly flags it Med risk
  pending a hardware benchmark. As a Category-4 waste finding the substance is the arithmetic,
  and the arithmetic is exact.

### RE-POPS-083 — VERIFIED-DRIFT

Evidence:
- Citations exact: `bd_cache.c:10` `BLOCK_WEIGHT_FACTOR 256` (24.8 fixed point); hit path
  `:79-82` clamps negative weight to 0 then `weight += count * 256`; miss path `:101` decays
  **every** block by `(8 * 256 / 32) + weight/32` = `64 + weight/32`; victim is the minimum
  weight (`:92,103-107`, sentinel `0x7fffffff`); fill resets victim weight to `count * 256`
  (`:121`, assignment — a detail the report omits but does not contradict). The machinery spans
  the cited `:79-122` for a 32-entry read-through / write-invalidate cache. The Category-3 core
  claim — a rotating victim or LRU counter does this job in a few obviously-correct lines, and
  the fix is a net deletion — stands.

Reasoning (the claimed misbehaviour is inverted — corrected figures from my own simulation of
the exact arithmetic, C truncation-toward-zero division, int32 weights):
- Untouched weights do **not** "drift negative" without bound, and drifting negative makes a
  block **more** evictable, not less — the victim is the *minimum* weight (`:103`). Simulated
  trajectory of an untouched block under repeated misses: 0, −64, −126, −187, −246, … converging
  to a **fixed point of exactly −2048**, where the decrement `64 + (−2048)/32` = 0. From
  −1,000,000 the weight converges *upward* to ≈−2048. A hot block (weight 1792 after a count-7
  hit) is never selected while floor blocks exist — the scheme behaves as a crude but
  directionally correct LFU/LRU hybrid, and cold-start victim order simulates as 0,1,2,3,…
  (sequential fill, i.e. round-robin-like).
- The scheme's real quirks (not the report's): (a) **floor saturation** — once all stale blocks
  sit at −2048 they are indistinguishable, so victim choice among them is scan-order arbitrary;
  (b) **unbounded positive growth on hits** — no decay without misses, so a hot block overflows
  int32 after 2³¹/256 = **8,388,608** count-1 hits (1,198,373 at count 7), wrapping negative and
  briefly making the hottest block the prime victim before the hit-clamp self-corrects it;
  (c) first-index tie bias from the strict `<` comparison.
- Corrected verdict basis: keep the finding as a complexity/LESS-NOT-MORE deletion (the
  replacement is strictly less code, as its justification states), but strike the parenthetical
  failure mode — "untouched blocks progressively *less* evictable" is backwards, and there is no
  unbounded negative drift. Severity is maintainability, not the implied eviction malfunction.

---

## Tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 8 | 004, 006, 013, 014, 015, 018, 029, 052 |
| VERIFIED-DRIFT | 2 | 001, 083 |
| WEAKENED | 1 | 036 |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — |
| **Total** | **11** | |

Duplicate / interaction flags:
- **001 ↔ 004** — same `sectorSize != 512` root cause; on the whole-device path 001's claimed
  scratch overflow is physically 004's cache-slot overflow. Distinct buffers/fixes; family, not
  a full duplicate.
- **018 → 036 / 006** — 018's error-swallowing is what currently masks 036's leak trigger and
  removes 006(1)'s read-failure exit on the cached path. Distinct mechanisms; fix order matters.
- **014 → 013** — 014's underflowed `sectorCount` is only exploitable because 013 enforces
  nothing. Distinct mechanisms.
- **006(3) vs RE-POPS-005** — different divide-by-zero sites and preconditions
  (`sectorSize == 0` in `scsi_warmup` printf vs `sectorSize ∈ [1,127]` in the GPT scan). Not
  duplicates.

## Candidates (new observations, not verdicts)

- **CAND-A — GPT scan counter signedness.** `part_driver_gpt.c:73`: loop counter is `int i`
  compared against u32 `partition_count`; the comparison converts `i` to unsigned, and a header
  with `partition_count > INT_MAX` drives `i` through signed-overflow UB before the bound can
  exit. Same file/loop as RE-POPS-006(1) but a distinct mechanism (type mismatch, not missing
  cap).
- **CAND-B — GPT entry OOB read via the cache on >512-sector devices.**
  `part_driver_gpt.c:93-97` indexes `pGptPartitionEntry[x]` for `x < entriesPerSector` (up to 32
  at S=4096), but on the cached path `bd_cache.c:86` delivered only 512 bytes into the 512-byte
  entry half of the 1024-byte allocation — entries 4..31 are read past the allocation from
  adjacent IOP heap and can mint bogus partitions. A chain consequence of 001/004/006; listed
  separately because the read-side overrun survives even if the write-side overflows are fixed
  piecemeal.
- **CAND-C — Silent drop when the mount table is full.** `bdm.c:50-66` `bdm_connect_bd`: if no
  `g_mount[i].bd == NULL` slot exists in `MAX_CONNECTIONS` (20), the device is silently dropped
  with no log or error path. Low severity; noted while tracing the connect path for 029/052.
- Checked and **not** a candidate: `scsi_connect:279` discarding `scsi_warmup`'s return value is
  already RE-POPS-017's headline claim.
