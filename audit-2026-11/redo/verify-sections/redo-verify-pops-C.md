# Adversarial Verification — Redo-POPSLoader, Chunk C (tarball FatFs driver layer)

Worker: verification subagent (chunk C). Method: refute-first, every cited file opened at cited lines, mechanisms re-derived, censuses re-run with own shell commands.

Sources:
- Report: `~/workspace/Sable-audit-redo/Redo-POPSLoader.md`
- Clone (pin verified `29272cddbf0122f14e76bc3bdd75e3b46aa870be`): `~/workspace/audit-clones-2026-11-13/POPSLoader`
- Tarball tree: cited as `/tmp/bdma-verify/BDMAssault-mx4sio` in the task. Mid-run a concurrent re-extract shifted the tree to `/tmp/bdma-verify/BDMAssault-mx4sio/BDMAssault-mx4sio/`; content confirmed identical (e.g. `bdmfs_fatfs/src/fs_driver.c` md5 `9416ea58afd25c63d0f3a56a82ae544a` in both the nested copy and `/tmp/bdma-xverify/BDMAssault-mx4sio/`). All line numbers below are from that identical content.
- Component vs merged copies: `diff bdmfs_fatfs/src/fs_driver.c __bdm_assault/src/bdmfs/bdmfs_fs_driver.c` and the same for `ffsystem.c` differ **only in `#include` path spelling** — every finding below applies to both copies exactly as the report claims.

---

### RE-POPS-011 — WEAKENED

**Guard arithmetic: verified exactly.** `fs_driver.c:33` declares `fs_driver_mount_info[FF_VOLUMES]`; `ffconf.h:169` sets `FF_VOLUMES 10`; `fs_driver.c:35` defines `FATFS_FS_DRIVER_MOUNT_INFO_MAX` as the array element count, so MAX really is == FF_VOLUMES == 10. At `fs_driver.c:141` the guard is `if (mount_info_index > FATFS_FS_DRIVER_MOUNT_INFO_MAX) return NULL;` — index 10 passes (`10 > 10` is false) and line 144 reads `fs_driver_mount_info[10].mounted_bd`, one element (608 B struct: 600 B `FATFS` + pointer + int) past the 10-element array. No `< 0` check exists. The proposed fix (`< 0 || >= MAX`) is correct and LESS-compliant.

**Reachability: the report overstates it — this is where it weakens.**
- *Via FatFs `pdrv` (diskio.c, `file->obj.fs->pdrv`): REFUTED as a path to 10 or negative.* `pdrv` is a `BYTE` (unsigned, so never negative). Its value is `LD2PD(vol)` = `(BYTE)(vol)` (ff.c:257, `FF_MULTI_PARTITION 0`), and `vol` comes from `get_ldnumber()` (ff.c:3094+): a numeric drive prefix is accepted only when it is a **single digit** (`IsDigit(*tp) && tp + 2 == tt`, `i = *tp - '0'` → 0–9), and the string-ID path returns only `i < FF_VOLUMES`. So internal FatFs can only ever produce pdrv 0–9. Index 10 via pdrv is impossible in this tree.
- *Via `fd->unit` (fs_getstat:598, GET_DRIVERNAME:696, stop_single via devctl:787): NOT SETTLEABLE from the tarball.* Nothing in the tarball bounds `fd->unit`; it is assigned by iomanX (external PS2SDK code, not in the tarball or the clone) from the numeric suffix of the opened device name. If iomanX accumulates multi-digit units, `mass10:`-style opens reach index 10; if it takes a single digit, they cannot. Neither the tarball nor the clone contains the parser, so the report's flat assertion that index 10 is reachable through its named callers is unproven on the evidence in the package.
- *Negative indices: no demonstrated path.* pdrv is unsigned; the internal find-free/find-from-bd helpers return −1 but their callers check `!= -1` and then index the array **directly** (mount/unmount), never through this getter; `fd->unit` derives from filename digits (≥ 0 by construction in any digit parser).

True scope: a real, latent off-by-one + missing lower-bound in an exported (`extern` in `fs_driver.h:19`) helper — any present or future caller that can supply 10 or a negative index gets an OOB read whose result gates I/O — but no caller inside the tarball is shown to reach either bad index today, and the pdrv path the report names is provably capped at 0–9. Severity drops from "OOB read on the driver's most-called helper" to "harden the exported helper before someone calls it wrong."

### RE-POPS-012 — VERIFIED

All three sites read exactly as claimed in `fs_driver.c` (fs_ioctl2 locks at :669, switch at :671):
1. `USBMASS_IOCTL_GET_LBA` (:681–695): validates only `rdata`; `bd = fatfs_fs_driver_get_mounted_bd_from_index(file->obj.fs->pdrv)` is dereferenced unchecked in `clst2sect(...) + bd->sectorOffset`.
2. `USBMASS_IOCTL_GET_DRIVERNAME` (:696–704): `ret` is guarded by the ternary `(mounted_bd == NULL) ? -ENXIO : ...`, but the very next block executes `strncpy(rdata, mounted_bd->name, rdatalen)` whenever `rdata != NULL` — i.e. precisely in the call shape that wants the name, a NULL `mounted_bd` is dereferenced even though the return value already says −ENXIO.
3. `get_frag_list` (:624–653, backing CHECK_CHAIN and GET_FRAGLIST): `bd` from `file->obj.fs->pdrv` is dereferenced at `bd->sectorOffset` (:641) with no NULL check.

The neighbouring `USBMASS_IOCTL_GET_DEVICE_NUMBER` case (:710–733) does exactly the NULL check the report cites as the in-file model (`if (bd == NULL) ret = -ENXIO;`). Reachability of the NULL: `disconnect_bd()` clears `mounted_bd` and unmounts while already-open `FIL`s keep pointing at the same `FATFS` (whose `pdrv` is unchanged), so an ioctl on a still-open fd after a yank hits these sites with `bd == NULL`. In `get_frag_list` the deref is not conditional in practice: even a chain via cluster 0/1 reaches a fragment emission (see RE-POPS-019). Fix (NULL-check all three, return −ENXIO) is sane, minimal, and copyable from the same switch. Not a duplicate of RE-POPS-019: same helper function `get_frag_list`, different mechanism (NULL deref vs non-termination).

### RE-POPS-019 — VERIFIED

`get_frag_list` (fs_driver.c:624–653) loop re-derived:
```c
do { iClusterNext = get_fat(&file->obj, iClusterCurrent);
     if (iClusterNext != iClusterCurrent + 1) { /* emit fragment */ iClusterStart = iClusterNext; }
     iClusterCurrent = iClusterNext;
} while (iClusterCurrent < file->obj.fs->n_fatent);
```
`get_fat` (ff.c:1135+) faithfully returns the stored FAT entry for any cluster in [2, n_fatent). A cycle wholly inside that range (A→B, B→A, or a self-loop A→A) therefore never produces a value ≥ n_fatent and never terminates — the report's two-cluster example works, including when A+1 == B (the B→A step emits a fragment and resets the start, then repeats). EOC and disk-error values (≥ 0x0FFFFFF8 / 0xFFFFFFFF) do exit, which is why only in-range cycles hang.

**Strengthening the report missed:** the hang does not even need a cycle. `get_fat` returns **1** for any out-of-range input (`clst < 2 || clst >= n_fatent` → `val = 1`, "internal error"), and 1 < n_fatent, so a chain that reaches cluster 0, cluster 1, or any entry that makes `get_fat` return 1 becomes a fixed point: `get_fat(1) == 1` forever, emitting a fragment per iteration. Corrupt removable media supplies both shapes.

Lock claim verified: both callers (`USBMASS_IOCTL_CHECK_CHAIN`, `USBMASS_IOCTL_GET_FRAGLIST`) are dispatched inside `fs_ioctl2` under `_fs_lock()` (:669 … unlock after the switch), and `_fs_lock` is the driver's global semaphore used by essentially every fs_* operation — the hang blocks the whole driver, as claimed. (No OOB write accompanies the hang: fragment stores are bounded by `iFragCount < iMaxFragments`; CHECK_CHAIN passes NULL/0.) Proposed fix (bound iterations by n_fatent / file clusters and error out) is sane and LESS-compliant.

### RE-POPS-037 — VERIFIED-DRIFT

Core claim exact. `ffconf.h:279–280`: `FF_FS_REENTRANT 1`, `FF_FS_TIMEOUT 1000`. `ffsystem.c:146–168` (`ff_req_grant`): the live IOP body is `WaitSema(sobj); return 1;` (:165–166) — WaitSema has no timeout, and the return is unconditional. The contract the report quotes is in the same file's own header comment (:141–144: "When a 0 is returned, the file function fails with FR_TIMEOUT") and in the `#if 0` Win32 sample in the same function (`WaitForSingleObject(sobj, FF_FS_TIMEOUT)`). Downstream, ff.c:894–898 `lock_fs()` returns `ff_req_grant(fs->sobj)` and callers (e.g. ff.c:3358) translate 0 to `FR_TIMEOUT` — a path that can now never fire. Merged copy identical except the include line.

**Corrected fix wording (the drift):** the report's "use a timed wait (poll/`iWaitSema` with the timeout)" misnames the IOP API — `iWaitSema` is the interrupt-context variant of WaitSema and also takes **no timeout argument**, and `PollSema` is not currently imported (`bdmfs_fatfs/src/imports.lst:44–49` imports only Create/Signal/Wait/DeleteSema). The implementable fix is a PollSema + delay/retry loop bounded by FF_FS_TIMEOUT (adding `I_PollSema` to imports), returning 0 on expiry. Direction and benefit as claimed; the named primitive is wrong.

### RE-POPS-038 — VERIFIED

`fs_devctl` (fs_driver.c:780–795): `case USBMASS_DEVCTL_STOP_UNIT:` calls `fatfs_fs_driver_stop_all_bd()` (:782); `case USBMASS_DEVCTL_STOP_ALL:` calls `fatfs_fs_driver_stop_single_bd(fd->unit)` (:787). The helpers are unambiguous and in the same file: `stop_single_bd(mount_info_index)` (:178) unmounts+stops one slot; `stop_all_bd()` (:189) loops all slots calling stop_single. The bodies are transposed relative to both the command names and the helper names, and the single-unit body is the one that consumes `fd->unit` — internal evidence is conclusive without the external header.

What can and cannot be settled (as the report itself hedges): the numeric values of `USBMASS_DEVCTL_STOP_UNIT/STOP_ALL` live in `usbhdfsd-common.h`, which is **not in the tarball and not in the clone** (grep of both trees finds the constants only at these two case labels), so their values cannot be confirmed here; and no caller in the POPSLoader clone issues either devctl against `mass:` (grep finds only SMB devctls in `src/luasystem.cpp`), so a hypothetical external caller that compensates for the swap cannot be excluded from this evidence. Neither caveat rescues the code: as written, a STOP_UNIT request stops every mounted device and a STOP_ALL request stops one. Fix (swap the two bodies) is trivially LESS-compliant.

### RE-POPS-061 — VERIFIED-DRIFT

RENAME stub exact: fs_driver.c:672–677 — `case USBMASS_IOCTL_RENAME: // TODO … ret = -ENOENT;` with the two-path comment the report paraphrases. `fs_remove` is registered in both the remove and rmdir slots (:812, :814), and `fs_dummy` (:266–271) returns −5, all as claimed.

**Corrected figure:** the ops table routes **nine** slots to `fs_dummy`, not six. `fs_functarray` (:802–830) contains `fs_dummy` at lines 804, 805, 819, 821, 822, 823, 824, 827, 828 — deinit + format up front, chstat, then chdir/sync/mount/umount, then symlink/readlink (standard iomanX ops order). The report's "six slots (format, chstat, and four others)" undercounts by three. Location ranges also sit a few lines high: the RENAME case is :672–677 (report: 668–674, which lands inside fs_ioctl2's prologue) and the table is :802–830 (report: 795–830).

Fix assessment: the report's preferred fix (implement RENAME via `f_rename` from `fd->unit` + the file's name) is weaker than it looks — a `FIL` stores no pathname, which is exactly the TODO's problem; the driver's working rename already exists as the `fs_rename` **op** (:743+, registered in the table), so the ioctl form is a legacy compat command. The report's alternative — return a distinguishable −ENOSYS-style error instead of −ENOENT — is the LESS-compliant fix and should be the primary recommendation.

### RE-POPS-067 — VERIFIED

Counts exact: fs_driver.c:231–235 — `#define MAX_FILES 128` / `static FIL fil_structures[MAX_FILES];`, `#define MAX_DIRS 16` / `static DIR dir_structures[MAX_DIRS];`, permanent BSS, no sizing comment anywhere in the file. The report's byte-size hedging ("tens of bytes", "several KiB", "not measured from a build") is honest; my own derivation: compiling the tree's real `ff.h`/`ffconf.h` (FF_FS_TINY 1, FF_FS_EXFAT 1, FF_LBA64 1, FF_USE_FASTSEEK 0) with `gcc -m32` gives `sizeof(FIL) = 76`, `sizeof(DIR) = 76` under 4-byte alignment of 64-bit types; IOP (MIPS o32) alignment can only keep or grow that (≤ ~88 B/FIL). So the reservation is ≈ 9.7–11.3 KiB for the FIL table plus ≈ 1.2 KiB for DIR — call it ~11–12.5 KiB total, i.e. the report's "several KiB" is if anything conservative. The judgement core (128 concurrent opens is unjustified for this driver's hosts, whose access is serialised by the global `_fs_lock` anyway) stands; the fix carries the Med risk the report already flags, since an external host that genuinely opens many files would hit `fs_find_free_fil_structure() == NULL`. No defeating evidence found.

### RE-POPS-099 — VERIFIED-DRIFT

Census re-run over the whole tarball (119 files — the report's file count is exact): `grep -rn bd_defrag` hits **only** `libbdm/src/bd_defrag.c` (definition), `libbdm/include/bd_defrag.h` (declarations + the `bd_defrag` backwards-compat macro), and `libbdm/Makefile:14` (`IOP_OBJS = bd_defrag.o bd_cache.o`). No caller in any component, merged driver, or other library — including via the macro alias. `bd_cache` by contrast is genuinely used (`bdm/src/bdm.c:60,84`), so libbdm itself is live and only the defrag member is dead, exactly as scoped. The report's own caveat (static-archive member, never pulled by any link here; real fragment-list consumers live in host apps outside the package) is accurate, and dropping `bd_defrag.o` from `IOP_OBJS` is the correct LESS fix.

**Corrected figures:** `bd_defrag.c` is **101 lines** (report cites 1–102 and calls it a "102-line module") and `bd_defrag.h` is **30 lines** (report cites 1–31) — both off by one, presumably a trailing-newline counting difference.

### RE-POPS-100 — VERIFIED-DRIFT

Structure verified in `bdmfs_fatfs/src/ffsystem.c`: `ff_memalloc`/`ff_memfree` (:10–33) compile only under `FF_USE_LFN == 3` while this tree sets `FF_USE_LFN 2` (ffconf.h:116 — report cites :107, the define is at :116 in this tree; minor anchor drift). Each of the four sync-object functions contains an `#if 0` sample block (at :58, :108, :147, :180). My count: 102 of the file's lines sit inside `#if 0` or LFN==3 blocks; ~42 lines are live non-comment code (98 live lines including comments/blanks), so "live IOP code is roughly 60 lines" is a fair middle estimate. Merged copy identical except the include line.

**Corrected figures:** the file is **200 lines**, not 201 (report: "this 201-line file", locations 15–201). And the `#if 0` samples cover **five** OS variants — Win32, µITRON, µC/OS-II, FreeRTOS, CMSIS-RTOS — which the report's own problem text lists in full while its title says "four other operating systems". Title count is wrong; body list is right. Trim fix is behaviour-neutral and LESS-compliant.

### RE-POPS-101 — VERIFIED-DRIFT

CI.yml is the tarball's only workflow. Its Compile step (:34–36, inside the report's cited :33–46 block) runs exactly `make -C libbdm`, `make -C __bdm_assault/`, `make -C __usbd_bd_assault/`. Unpinned actions confirmed: `actions/checkout@v3` (:27), `actions/upload-artifact@v3` (:47), `marvinpinto/action-automatic-releases@latest` (:55), publishing a prerelease tagged "latest" on pushes to main (:53–62). Each unbuilt component directory does have a Makefile (`bdm/`, `bdmfs_fatfs/`, `usbd/`, `usbmass_bd/` all verified present), so a component compile break is invisible to CI, as claimed — and nothing in the workflow diffs component vs merged trees.

**Corrected figure:** there are **four** unbuilt component modules, not five. The report's body and fix both correctly say four ("bdm/, bdmfs_fatfs/, usbd/, and usbmass_bd/… Add the four component builds"); only the finding's title ("the five component modules") is wrong — presumably counting libbdm, which *is* built. Fix (add the four builds, pin actions) is sane.

---

## Closing tally

| Verdict | Count | Findings |
|---|---|---|
| VERIFIED | 4 | RE-POPS-012, 019, 038, 067 |
| VERIFIED-DRIFT | 5 | RE-POPS-037 (fix names a non-existent timed primitive), 061 (9 dummy slots, not 6), 099 (101/30 lines, not 102/31), 100 (200 lines, not 201; five sample OSes, not four), 101 (four unbuilt components, not five) |
| WEAKENED | 1 | RE-POPS-011 (guard defect real, but pdrv reachability refuted and fd->unit reachability unsettleable from the package) |
| REFUTED | 0 | — |
| BLOCKED-ENV | 0 | — |

No mechanism-level duplicates found among the assigned ten. RE-POPS-012 and RE-POPS-019 share `get_frag_list` but are distinct mechanisms (NULL deref vs non-termination); RE-POPS-037's lock-hang compounds RE-POPS-019's as the report itself notes, without duplicating it.

## Candidates (new defects, not verdicts)

- **CAND-C1 — `USBMASS_IOCTL_GET_FRAGLIST` never validates `rdata`.** fs_driver.c:707–709 passes `rdata`/`rdatalen` straight to `get_frag_list`, which writes through the cast pointer whenever `rdatalen > 0` (`iMaxFragments > 0`); a caller passing `rdata == NULL` with a non-zero length gets a NULL-pointer write in IOP code. The neighbouring GET_LBA and GET_DEVICE_NUMBER cases both validate `rdata != NULL` first — this is a fourth unchecked site in the same switch that RE-POPS-012's fix should sweep in.
- **CAND-C2 (strengthening, attached to RE-POPS-019) — `get_fat`'s error sentinel is a fixed point of the frag-list loop.** `get_fat` returns 1 for out-of-range clusters and 1 < n_fatent, so any chain reaching cluster 0/1 hangs `get_frag_list` without needing a crafted cycle. Recorded inside the RE-POPS-019 block above rather than as a standalone finding, since the fix (iteration bound) is identical.
