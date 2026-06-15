# POPSLoader Preservation Contracts

Date: 2026-06-15
Branch documented: `BETA-12-PLAY` (this `docs-overhaul` worktree, shipped state)

Purpose: regression armor for the launch / ELF-handoff layer. Each contract below
is a load-bearing teardown or routing rule that survived a specific hardware
black-screen and must not be broken by future launch-path changes. For each
contract this document records: what it guarantees, the exact code that
implements it (`path:line`), the `reboot_iop` value it depends on, the action
that breaks it, and how to retest it on hardware.

Every technical claim is cited to source in this worktree. Where a citation is a
single line it is the exact line in the file at the time of writing; treat the
surrounding function as the real unit and re-confirm the line if the file moves.

> **Read this before touching any of:** `src/elf_loader/src/elf.c`,
> `src/elf_loader/src/loader/src/loader.c`, `bin/POPSLDR/ui.lua` launch handoffs
> (`OpenDKWDRV`, `LaunchBootElf`, `ConfirmExit`), `bin/POPSLDR/system.lua`
> `LaunchEngine` / `RunPOPStarterGame` / `BuildPopstarterLaunchCommand` /
> `PrepareForExternalELFLaunch`, `src/luasystem.cpp` `lua_loadELF*`, or
> `etc/boot.lua` HDD-boot mount.

Related docs: `docs/LAUNCH_HYGIENE.md` (launch-path architecture and fix history),
`docs/U10_INVESTIGATION.md` (U-10 deep dive), `HDD_POPSTARTER_HANDOFF.md`
(archived D-10/D-14 diagnostic trail), `QA_REGRESSION_MATRIX.md` (the hardware
ledger and canonical test-case definitions), `STATE.md` (current Known Broken
list).

## How the launch chain is wired (orientation)

Launch is a three-stage chain. Lua decides the route and `reboot_iop`, the C
parent splits teardown by target family, and a BRAM child loader performs the
final `ExecPS2`.

1. **Lua orchestration** — `bin/POPSLDR/system.lua` `RunPOPStarterGame` (line 4671)
   → `BuildPopstarterLaunchCommand` (line 4649) sets `reboot_iop` → `LaunchEngine`
   (the exec branch at `system.lua:4528`) picks the C binding. `ui.lua`
   `OpenDKWDRV` (line 1216), `LaunchBootElf` (line 1325), and `ConfirmExit`
   (line 1317) are the DKWDRV / BOOT.ELF / exit handoffs.
2. **C bindings + parent loader** — `src/luasystem.cpp` `lua_loadELF` (line 1008),
   `lua_loadELFWithPartition` (line 1054), `lua_loadELFRebootIOP` (line 1102) →
   `src/elf_loader/src/elf.c`. Three teardown contracts live here:
   `LoadELFFromFileExecPS2RebootIOPWithPartition` (line 604, the central
   reboot/HDD fork), `LoadELFFromFileWithPartition` (line 467, BOOT.ELF + HDD
   DKWDRV special-cases), and `ExecuteViaEmbeddedLoader` (line 383, BRAM handoff).
3. **BRAM child loader** — `src/elf_loader/src/loader/src/loader.c` `main` (line
   275). Reads metadata from `0x00083C00`, picks one of three pre-`ExecPS2`
   teardown branches, then `ExecPS2`'s the final target.

The per-device `reboot_iop` default is `0`
(`PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER = 0`, `system.lua:1897`); it is raised
to `1` only when POPSTARTER itself lives on HDD (`system.lua:4656-4661`).

---

## Contract D-10 — HDD-resident POPSTARTER launching an HDD game

**QA definition:** `QA_REGRESSION_MATRIX.md:80` — "POPSTARTER resolves from sidecar
or configured HDD path without blocking launch or hanging on a black screen" when
both POPSLoader/`POPSTARTER_PATH` and the game are on HDD.

**Hardware status:** PASS as of 2026-05-22 (`QA_REGRESSION_MATRIX.md:153-154`,
the B2 fix). Confirmed still-PASS after later BOOT.ELF/DKWDRV experiments
(`QA_REGRESSION_MATRIX.md:161`).

### What it guarantees

An HDD-backed POPSTARTER.ELF, launched to run an HDD-backed game, reaches its own
`ExecPS2` of the target with the IOP in a state the target tolerates — no
black screen, no silent `SifIopReset` hang.

### How it is implemented

- **Routing into the BRAM child loader.** HDD-backed launches do NOT take the
  direct `SifIopReset` path. `LoadELFFromFileExecPS2RebootIOPWithPartition`
  routes to `ExecuteHddBackedViaEmbeddedLoader` when both the partition and
  filename are HDD-shaped, or when the resolved path / partition is HDD-shaped:
  `src/elf_loader/src/elf.c:631-635` (partition+filename guard) and
  `src/elf_loader/src/elf.c:641-643` (resolved-path/partition guard).
  `is_hdd_backed_exec_path` matches `hdd` or `pfs` prefixes only
  (`src/elf_loader/src/elf.c:114-117`).
- **BRAM handoff and out-of-band metadata.** `ExecuteViaEmbeddedLoader` wipes
  BRAM, writes the `EmbeddedLoaderMetadata` (magic `POPL` = `0x504F504C`, version
  1) to the fixed address `0x00083C00`, copies the child loader's `PT_LOAD`
  segments into BRAM, then tears down and `ExecPS2`'s the child:
  `src/elf_loader/src/elf.c:383-465`. Metadata struct + address + magic:
  `src/elf_loader/src/elf.c:159-170`.
- **The decisive child teardown.** The parent passes a non-empty HDD partition
  context (`hdd?:PART:`, written at `src/elf_loader/src/elf.c:358`), so in the
  child loader `is_hdd_partition_context` is true (`loader.c:376`,`:78-84`) and
  `should_use_filexio_direct_load` short-circuits to 0 (`loader.c:88-89`).
  D-10 therefore takes the **partition-context branch (`loader.c:376-397`)**, NOT
  the generic branch. That branch `SifLoadElf`'s POPSTARTER from the
  parent-mounted `pfs0:` (`loader.c:352`), **unmounts the pfs prefix** it no
  longer needs (`loader.c:387-389`), then tears down with `SifExitRpc()` **and**
  `SifExitCmd()` (`loader.c:391-392`) before `ExecPS2` (`loader.c:396`). The
  umount-before-`SifExitCmd` ordering is the load-bearing part — it releases
  fileXio's hold on the partition so POPSTARTER can re-mount it.
  (The **generic** branch `loader.c:399-422` — `SifExitRpc` only, **no
  `SifExitCmd`** — is the *empty-partition-context* path used by BOOT.ELF and
  HDD DKWDRV, not D-10; see U-10. The historical comment at `loader.c:400-408`
  warns against adding `SifExitCmd` *there*; it dates from when HDD launches
  flowed through that branch without the umount, which is what produced
  "D-15-pass vs D-10-fail.")
- **`reboot_iop` value: `1`.** Set in `BuildPopstarterLaunchCommand` when
  `popstarter_on_hdd` is true: `bin/POPSLDR/system.lua:4657-4658`. A non-zero
  `reboot_iop` (here `1`) plus a present `exec_partition_context` is what makes
  `LaunchEngine` select the partition-aware binding (the gate is
  `exec_partition_context ~= nil and reboot_iop ~= 0`, `system.lua:4544-4546`).
- **Partition context is out-of-band.** `lua_loadELFWithPartition` requires a
  context shaped like `hdd?:PART:` and `reboot_iop != 0`, and never copies the
  context into the target argv: `src/luasystem.cpp:1067-1072` (the two guards),
  `src/luasystem.cpp:991-1006` (`is_partition_context_arg`).

### What breaks it

- Removing the `fileXioUmount` of the pfs prefix before `SifExitCmd()` in the
  partition-context branch (`loader.c:387-392`), or deleting the
  `is_hdd_partition_context` branch so D-10 falls through to the generic branch.
  The umount-then-`SifExitCmd` ordering in `loader.c:376-397` is what D-10
  depends on. (Relatedly, do not add `SifExitCmd()` to the generic branch
  `loader.c:399-422` — the comment at `loader.c:400-408` records that regression
  from when HDD used that branch; it now governs BOOT.ELF / HDD DKWDRV.)
- Re-excluding DKWDRV or otherwise letting an HDD-backed target slip both routing
  guards at `elf.c:631-635` / `elf.c:641-643` so it falls through to the direct
  `SifIopReset` path. The previous V3 logic did this and black-screened
  (`elf.c:614-635` comment; `QA_REGRESSION_MATRIX.md:124-134`).
- Changing the `EmbeddedLoaderMetadata` layout, address, or magic in only one of
  the two files (`elf.c:159-170` writer / `loader.c:139-150` reader). A mismatch
  makes `read_embedded_loader_metadata` return `-3302` (`loader.c:160-165`), and
  `main` paints the RED background and bails (`loader.c:294-296`).
- Forcing `reboot_iop` away from `1` for HDD POPSTARTER, which drops the
  partition-aware route (`system.lua:4544-4546`).

### How to test on hardware

Per `QA_REGRESSION_MATRIX.md:80` and the `HDD_POPSTARTER_HANDOFF.md` test
sequence: boot from HDD, with HDD sidecar/CWD/Profile/default `POPSTARTER.ELF`,
select an HDD title, confirm with `X`. Expected: real POPSTARTER boots the game,
no black screen. Then repeat with `R2` ("HDD Alt" / `full_hdd_pfs0` mode,
`ui.lua:2261-2262`). Record in `QA_REGRESSION_MATRIX.md` as D-10.

---

## Contract D-15 — HDD game launched from a non-HDD POPSTARTER

**QA definition:** `QA_REGRESSION_MATRIX.md:85` — boot from USB/MMCE/MX4SIO with
the sidecar/CWD `POPSTARTER.ELF` on that same non-HDD device, launch an HDD title;
"HDD title still launches without a black screen when POPSTARTER itself remains
off-HDD."

**Hardware status:** PASS as of 2026-05-22 (`QA_REGRESSION_MATRIX.md:156`). This
is the reference-good case that the D-10 child teardown is calibrated against.

### What it guarantees

When POPSTARTER.ELF is on a non-HDD device but the selected game is on HDD, the
game launches. The game's HDD partition / pfs slots are not torn down out from
under the launch, and non-HDD POPSTARTER's normal one-argument selector contract
is preserved.

### How it is implemented

- **Non-HDD POPSTARTER keeps `reboot_iop = 0`** (the default,
  `PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER`, `system.lua:1897`). When the policy
  is HDD (HDD game) but POPSTARTER is non-HDD, `BuildPopstarterLaunchCommand`
  explicitly pins `reboot_iop = 0`: `bin/POPSLDR/system.lua:4659-4660`.
- **Legacy selector path, no partition API.** With `reboot_iop == 0`,
  `use_partition_api` is false (`system.lua:4544-4546`), so `LaunchEngine` calls
  `System.loadELF(exec_path, reboot_iop, selector)` (`system.lua:4551` /
  `4557` / `4563`). `lua_loadELF` with `reboot_iop == 0` and one extra arg goes to
  `LoadELFFromFileExecPS2`; with no extra args, to `LoadELFFromFile`:
  `src/luasystem.cpp:1027-1043`. The selector stays as the single target
  `argv[0]`.
- **Keep-PFS mask protects the game's slots across exec.** Before exec,
  `PrepareForExternalELFLaunch` computes the keep slots and calls
  `System.setExecKeepPfsMask`, then unmounts only the non-kept slots:
  `bin/POPSLDR/system.lua:1017-1045`, mask built by `BuildPfsKeepMask`
  (`system.lua:1004-1015`). On the C side the mask is 4-bit
  (`SetExecKeepPfsMask`, `src/elf_loader/src/elf.c:35-37`) and
  `unmount_pfs_slots_for_exec` preserves masked slots
  (`src/elf_loader/src/elf.c:97-107`, `build_exec_keep_mask` at
  `elf.c:109-112`).

### What breaks it

- D-15 is the historical pass-side calibration point for the child teardown (the
  `loader.c:400-408` comment frames the no-`SifExitCmd` rule as "D-15-pass vs
  D-10-fail"), so any teardown change in the child loader should be re-tested
  against D-15 as well as D-10.
- Letting a second Lua argument leak into the non-HDD POPSTARTER call (the
  2026-05-20 D-15 regression at `QA_REGRESSION_MATRIX.md:137`). The fix was to
  keep `System.loadELF(path, reboot_iop, selector)` strictly one-selector;
  `lua_loadELF` enforces a single selector buffer (`src/luasystem.cpp:1016-1025`).
- Forcing `reboot_iop = 1` for non-HDD POPSTARTER, which would switch this case to
  the partition/reboot path it does not need.

### How to test on hardware

Boot from USB (or MMCE/MX4SIO), sidecar/Profile 1 `POPSTARTER.ELF` on that same
device, select an HDD title, confirm with `X`. Expected: HDD title launches, no
black screen. Per `HDD_POPSTARTER_HANDOFF.md` this is the **first** case to retest
after any launch-path change, because it is the known-good separator. Record as
D-15 in `QA_REGRESSION_MATRIX.md`.

---

## Contract U-10 — BOOT.ELF exit, `reboot_iop = 0` embedded-loader route

**QA definition:** `QA_REGRESSION_MATRIX.md:100` — open `HDD (PFS)` first so
dependency checks/scans run, return to the menu, launch `BOOT.ELF` from Exit;
"`BOOT.ELF` handoff succeeds without freezing or black-screening after HDD page
access."

**Hardware status: KNOWN BROKEN, accepted for release** for the HDD-booted
sub-case (`docs/U10_INVESTIGATION.md:6-8`). The contract documented here is the
**working** non-HDD BOOT.ELF route (L-07 PASS at V2 commit `d23520a`,
`docs/U10_INVESTIGATION.md:22,28`). The HDD-boot → Exit → BOOT.ELF path is NOT
fixed; do not assume current code fixes it (`QA_REGRESSION_MATRIX.md:162`,
`ui.lua:1346-1361`).

### What it guarantees (the working route)

For a non-HDD-booted POPSLoader, "Exit → BOOT.ELF" reaches `mc?:/BOOT/BOOT.ELF`
through the embedded child loader's no-reset branch and runs without hanging.

### How it is implemented

- **`reboot_iop` is computed, default `0`.** `LaunchBootElf` sets
  `reboot_iop = 0`, then raises it to `1` only if HDD was loaded this session
  (`PLDR.HDD.LOADSTATE != 0`): `bin/POPSLDR/ui.lua:1336-1345`.
- **The mc BOOT.ELF special-case routes through the embedded loader — only on the
  `reboot_iop = 0` branch.** `System.loadELF(elf_path, 0)` with no args →
  `LoadELFFromFile` → `LoadELFFromFileWithPartition`, which special-cases
  `mc0:/BOOT/BOOT.ELF` / `mc1:/BOOT/BOOT.ELF` and calls
  `ExecuteViaEmbeddedLoader("", resolved_path, 1, boot_argv)`:
  `src/elf_loader/src/elf.c:485-489`. The child then takes the non-HDD generic
  branch (`SifExitRpc` only, no reset): `loader.c:399-422`.
- **The `reboot_iop = 1` branch does NOT hit the mc special-case.** When HDD was
  loaded this session, `LaunchBootElf` passes `reboot_iop = 1`
  (`ui.lua:1343-1362`), which routes to
  `LoadELFFromFileExecPS2RebootIOPWithPartition` — the direct
  `SifLoadElf + SifIopReset + reload SIO2MAN/MCMAN/MCSERV + ExecPS2` path
  (`elf.c:645-700`). This is the HDD-booted sub-case that **remains broken**:
  `SifIopReset` hangs after `SifLoadElf` (`docs/U10_INVESTIGATION.md:16,34-36`).
- **U-10 partial fix that IS preserved (do not revert).** The direct-reset path
  now unconditionally unmounts non-kept pfs slots before `SifIopReset`, including
  the boot partition's `pfs1:`, instead of skipping the unmount for non-HDD
  targets like BOOT.ELF: `src/elf_loader/src/elf.c:654-672`, with the PR #463
  diagnosis comment at `elf.c:654-671`. This released `fileXio`'s hold on the
  `pfs1:` RPC server for the cases it covers; it did not by itself fix the
  HDD-boot sub-case (`docs/U10_INVESTIGATION.md:17`), but reverting it
  reintroduces the U-10 "freeze at YELLOW after `SifLoadElf`" sabotage.

### What breaks it

- Adding a BOOT.ELF-specific IOP-reset branch to the child loader. PR #458 did
  this and regressed V2's working USB-boot exit (forced a reset BOOT.ELF does not
  tolerate); PR #460 reverted it (`docs/LAUNCH_HYGIENE.md:56-71`,
  `QA_REGRESSION_MATRIX.md:169`). The child loader must stay reset-free for
  BOOT.ELF.
- Removing the mc BOOT.ELF special-case at `elf.c:485-489`, which would drop the
  working non-HDD route to the direct path.
- Re-gating the pre-reset unmount on `is_hdd_backed_exec_path` (the original
  sabotage, `elf.c:668-671`).
- Hard-coding `LaunchBootElf`'s `reboot_iop` back to a constant, discarding the
  HDD-aware conditional (`ui.lua:1346-1352`).

### How to test on hardware

- Working route (L-07): boot from USB/MC/MMCE/MX4SIO, Exit → BOOT.ELF. Expected:
  BOOT.ELF runs. Record as L-07/U-10 non-HDD.
- Broken route (U-10): boot from HDD, open `HDD (PFS)` first, return to menu,
  Exit → BOOT.ELF. Currently black-screens; the accepted workaround is Exit →
  OSDSYS or reboot (`docs/U10_INVESTIGATION.md:8`). Do not mark this PASS without
  a fresh HDD-launched hardware retest.

---

## Contract DKWDRV-from-MC vs DKWDRV-from-HDD

**QA definitions:** `QA_REGRESSION_MATRIX.md:62` (mc?: DKWDRV alias resolves and
launches), `QA_REGRESSION_MATRIX.md:59` (missing-path UI message). MC DKWDRV is
the confirmed-working baseline; HDD DKWDRV is source-verified V2-mimicry whose
hardware result has been FAIL on the tested builds.

**Hardware status:** MC DKWDRV works (`ui.lua:1242-1244` notes it confirmed
working; `docs/LAUNCH_HYGIENE.md:114`). HDD DKWDRV: the V2-mimicry route is
source-verified (`QA_REGRESSION_MATRIX.md:171`) but earlier HDD-DKWDRV builds
black-screened on hardware (`QA_REGRESSION_MATRIX.md:163,166`); treat HDD DKWDRV
as not-yet-confirmed and preserve the two-half contract regardless.

### What it guarantees

- **MC / non-HDD DKWDRV** (`mc?:/PS1_DKWDRV/DKWDRV.ELF`) launches via a full IOP
  reset with reloaded MC modules and a synthesized `argv[0]`.
- **HDD DKWDRV** (`hdd?:/`, `pfs?:/`, `ata?:/`, `apa?:/`) launches via the same
  BRAM embedded-loader contract as POPSTARTER-on-HDD — the V2 BOOT.ELF mimicry —
  rather than the direct path that black-screened.

### How it is implemented

- **Route selection in Lua by where DKWDRV lives.** `OpenDKWDRV` classifies the
  path and picks `dkwdrv_reboot_iop = is_hdd_path and 0 or 1`, then calls
  `System.loadELF(elf_path, dkwdrv_reboot_iop, elf_path)`:
  `bin/POPSLDR/ui.lua:1255-1261`. The route rationale (BOTH the Lua `reboot_iop=0`
  half AND the C-side embedded-loader half are required for HDD DKWDRV) is
  documented at `ui.lua:1241-1254`.
- **HDD DKWDRV C-side special-case** mirrors the BOOT.ELF case: when
  `is_dkwdrv_elf_path(resolved_path)`, `LoadELFFromFileWithPartition` routes
  through `ExecuteViaEmbeddedLoader("", resolved_path, 1, dkwdrv_argv)`:
  `src/elf_loader/src/elf.c:502-506`, with the V2-contract comment at
  `elf.c:491-501`. `is_dkwdrv_elf_path` matches a `DKWDRV.ELF` basename
  (case-insensitive) at a path boundary: `src/elf_loader/src/elf.c:119-144`.
- **MC DKWDRV** (`reboot_iop = 1`) → `lua_loadELF` with one extra arg →
  `LoadELFFromFileExecPS2RebootIOP` → the reboot variant
  (`LoadELFFromFileExecPS2RebootIOPWithPartition`, `elf.c:604`). Its non-HDD tail
  resets the IOP, reloads `rom0:SIO2MAN/MCMAN/MCSERV`, and synthesizes
  `argv[0] = resolved_path` for DKWDRV before `ExecPS2`:
  `src/elf_loader/src/elf.c:680-699` (module reload at `elf.c:682-684`, DKWDRV
  argv0 synthesis at `elf.c:691-697`).

### What breaks it

- Trying only the Lua half for HDD DKWDRV (`reboot_iop = 0`) without the C-side
  embedded-loader route — PR #452 (V4) did exactly this, fell through to direct
  `LoadExecPS2`, and black-screened (`elf.c:495-500` comment;
  `QA_REGRESSION_MATRIX.md:163`). Both halves are required.
- Removing the DKWDRV special-case at `elf.c:502-506`.
- Changing `is_dkwdrv_elf_path` (`elf.c:119-144`) so a real `DKWDRV.ELF` path no
  longer matches, which silently drops both the HDD route and the MC argv0
  synthesis.
- Flipping the HDD-path → `reboot_iop = 0` selection in `OpenDKWDRV`
  (`ui.lua:1255-1260`).

### How to test on hardware

- MC DKWDRV: configure `DKWDRV_PATH` to `mc?:/PS1_DKWDRV/DKWDRV.ELF`, launch the
  Disc option. Expected: DKWDRV runs (baseline). Record per
  `QA_REGRESSION_MATRIX.md:62`.
- HDD DKWDRV: set `DKWDRV_PATH` to an HDD path (e.g.
  `hdd0:/__common:pfs1:/APPS/PS1_DKWDRV/DKWDRV.ELF`), launch the Disc option.
  Currently unconfirmed/failing on tested builds; do not mark PASS without a fresh
  Nuno hardware result (`QA_REGRESSION_MATRIX.md:166,171`).

---

## Cross-cutting invariants (apply to all four contracts)

- **`EmbeddedLoaderMetadata` is duplicated and must stay byte-identical.** Writer:
  `src/elf_loader/src/elf.c:159-170`. Reader: `src/elf_loader/src/loader/src/loader.c:139-150`.
  Same magic (`0x504F504C`), version (`1`), address (`0x00083C00`), and field
  layout (`partition_context[128]`, `load_path[256]`). A mismatch → `-3302` from
  `read_embedded_loader_metadata` (`loader.c:160-165`) → RED background in `main`
  (`loader.c:294-296`).
- **The keep-PFS mask is 4-bit and single-shot.** `SetExecKeepPfsMask` masks
  `& 0x0F` (`elf.c:35-37`); only slots 0-3 are protected
  (`unmount_pfs_slots_for_exec`, `elf.c:97-107`). The boot partition is hard-mounted
  to `pfs1:` and "NEVER USE IT FOR ANYTHING ELSE" (`etc/boot.lua:45-48`), so slot 1
  must be kept across BOOT.ELF/exit or `SifIopReset` hangs (the U-10 mode). The
  bindings call `ClearExecKeepPfsMask()` only *after* the launch call returns
  (`src/luasystem.cpp:1032,1044,1097`) — and a successful `ExecPS2` never returns,
  so the mask is cleared only on failure.
- **A launch that returns is a failure.** `ExecuteViaEmbeddedLoader` returns
  `(ret != 0) ? ret : -3600` (`elf.c:463-464`); the child returns `-3500` /
  `-3200+ret` sentinels (`loader.c:373,397,422,427-429`). These negative codes
  surface in the `BlockLaunchFailure` diagnostic screen. Any non-hang return from
  a launch is fatal, not success.
- **`PrepareForColdExternalELFLaunch` forces the keep mask to 0** and unmounts all
  pfs slots (`system.lua:1047-...`, invoked from `LaunchEngine` when
  `context.cold_external_launch == true`, `system.lua:4529-4530`). Do not route a
  launch that needs `pfs1:` (e.g. HDD-boot BOOT.ELF) through the cold prep.

## Do not do

- Do not add `SifExitCmd()` to the child generic/empty-context branch
  (`loader.c:399-422`, used by BOOT.ELF / HDD DKWDRV). D-10's own branch
  (`loader.c:376-397`) intentionally DOES call `SifExitCmd()` — but only after
  unmounting the pfs prefix; do not remove that umount.
- Do not add IOP-reset branches for BOOT.ELF or DKWDRV to the child loader
  (reverted in PR #460; `docs/LAUNCH_HYGIENE.md:56-71`).
- Do not re-gate the pre-reset pfs unmount on `is_hdd_backed_exec_path`
  (`elf.c:668-671`).
- Do not edit the `EmbeddedLoaderMetadata` struct in only one of the two files.
- Do not change the POPSTARTER selector `argv[0]` contract or let partition
  context leak into target argv (`src/luasystem.cpp:1049-1053,1067-1072`).
- Do not mark D-10, D-14, D-15, U-10, or HDD DKWDRV as hardware-PASS without an
  actual hardware result recorded in `QA_REGRESSION_MATRIX.md`.
- After ANY edit to `src/elf_loader/src/loader/src/loader.c`, regenerate and
  commit `src/elf_loader/loader.c` (`make clean elfloader all`); CI enforces a
  byte-parity check (`HDD_POPSTARTER_HANDOFF.md:110-114`).
