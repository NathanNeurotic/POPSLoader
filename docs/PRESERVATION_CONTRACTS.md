# POPSLoader Preservation Contracts

Date: 2026-06-20 (re-synced to BETA-12-PLAY HEAD 2859c60; BETA-12 released 2026-06-18 per STATE.md)
Branch documented: `BETA-12-PLAY`

Purpose: regression armor for the launch / ELF-handoff layer. Each contract below
is a load-bearing teardown or routing rule that survived a specific hardware
black-screen and must not be broken by future launch-path changes. For each
contract this document records: what it guarantees, the exact code that
implements it (`path:line`), the `reboot_iop` value it depends on, the action
that breaks it, and how to retest it on hardware.

Every technical claim is cited to the named function in this branch. Line numbers
are best-effort and drift as files change — treat the cited function (not the
`path:line`) as the unit of truth and grep for the function/identifier rather than
jumping to the literal line.

> **Read this before touching any of:** `src/elf_loader/src/elf.c`,
> `src/elf_loader/src/loader/src/loader.c`, `bin/POPSLDR/ui.lua` launch handoffs
> (`OpenDKWDRV`, `LaunchBootElf`, `ConfirmExit`), `bin/POPSLDR/system.lua`
> `LaunchEngine` / `RunPOPStarterGame` / `BuildPopstarterLaunchCommand` /
> `PrepareForExternalELFLaunch`, `src/luasystem.cpp` `lua_loadELF*`, or
> `etc/boot.lua` HDD-boot mount.

Related docs: `docs/archive/LAUNCH_HYGIENE.md` (launch-path architecture and fix
history), `docs/archive/U10_INVESTIGATION.md` (U-10 deep dive),
`docs/archive/HDD_POPSTARTER_HANDOFF.md` (archived D-10/D-14 diagnostic trail),
`QA_REGRESSION_MATRIX.md` (the hardware ledger and canonical test-case
definitions), `STATE.md` (current status, Known Issues, and Hardware Status — the
canonical source).

## How the launch chain is wired (orientation)

Launch is a three-stage chain. Lua decides the route and `reboot_iop`, the C
parent splits teardown by target family, and a BRAM child loader performs the
final `ExecPS2`.

1. **Lua orchestration** — `bin/POPSLDR/system.lua` `RunPOPStarterGame` (line 5568)
   → `BuildPopstarterLaunchCommand` (line 5546) sets `reboot_iop` → `LaunchEngine`
   (line 5351; loadELF/loadELFWithPartition dispatch at `system.lua:5444-5462`) picks
   the C binding. `ui.lua`
   `OpenDKWDRV` (line 1370), `LaunchBootElf` (line 1591), and `ConfirmExit`
   (line 1583) are the DKWDRV / BOOT.ELF / exit handoffs.
2. **C bindings + parent loader** — `src/luasystem.cpp` `lua_loadELF` (line 974),
   `lua_loadELFWithPartition` (line 1020), `lua_loadELFRebootIOP` (line 1068) →
   `src/elf_loader/src/elf.c`. Three teardown contracts live here:
   `LoadELFFromFileExecPS2RebootIOPWithPartition` (line 618, the central
   reboot/HDD fork), `LoadELFFromFileWithPartition` (line 481, BOOT.ELF + HDD
   DKWDRV special-cases), and `ExecuteViaEmbeddedLoader` (line 397, BRAM handoff).
3. **BRAM child loader** — `src/elf_loader/src/loader/src/loader.c` `main` (line
   280). Reads metadata from `0x00083C00`, picks one of three pre-`ExecPS2`
   teardown branches, then `ExecPS2`'s the final target.

The per-device `reboot_iop` default is `0`
(`PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER = 0`, `system.lua:2002`); it is raised
to `1` only when POPSTARTER itself lives on HDD (`system.lua:5554-5555`).

---

## Contract D-10 — HDD-resident POPSTARTER launching an HDD game

**QA definition:** `QA_REGRESSION_MATRIX.md` test-case `D-10` — "POPSTARTER resolves from sidecar
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
  `src/elf_loader/src/elf.c:645-648` (partition+filename guard) and
  `src/elf_loader/src/elf.c:655-656` (resolved-path/partition guard).
  `is_hdd_backed_exec_path` matches `hdd` or `pfs` prefixes only
  (`src/elf_loader/src/elf.c:114-117`).
- **BRAM handoff and out-of-band metadata.** `ExecuteViaEmbeddedLoader` wipes
  BRAM, writes the `EmbeddedLoaderMetadata` (magic `POPL` = `0x504F504C`, version
  1) to the fixed address `0x00083C00`, copies the child loader's `PT_LOAD`
  segments into BRAM, then tears down and `ExecPS2`'s the child:
  `src/elf_loader/src/elf.c:397-479`. Metadata struct + address + magic:
  `src/elf_loader/src/elf.c:159-170`.
- **The decisive child teardown.** The parent passes a non-empty HDD partition
  context (`hdd?:PART:`, written at `src/elf_loader/src/elf.c:361`), so in the
  child loader `is_hdd_partition_context` is true (`loader.c:381`,`:83-89`) and
  `should_use_filexio_direct_load` short-circuits to 0 (`loader.c:93-94`).
  D-10 therefore takes the **partition-context branch (`loader.c:381-403`)**, NOT
  the generic branch. That branch `SifLoadElf`'s POPSTARTER from the
  parent-mounted `pfs0:` (`loader.c:357`), **unmounts the pfs prefix** it no
  longer needs (`loader.c:392-393`), then tears down with `SifExitRpc()` **and**
  `SifExitCmd()` (`loader.c:396-397`) before `ExecPS2` (`loader.c:401`). The
  umount-before-`SifExitCmd` ordering is the load-bearing part — it releases
  fileXio's hold on the partition so POPSTARTER can re-mount it.
  (The **generic** branch `loader.c:404-427` — `SifExitRpc` only, **no
  `SifExitCmd`** — is the *empty-partition-context* path used by BOOT.ELF
  (`ExecuteViaEmbeddedLoader("", ...)` at `elf.c:502`), not D-10. HDD DKWDRV does
  NOT use it: it passes a non-empty `hdd?:PART:` context (`ui.lua:1532`) and so
  takes the partition-context branch like D-10. The historical comment at
  `loader.c:405-413` warns against adding `SifExitCmd` *there*; it dates from when
  HDD launches flowed through that branch without the umount, which is what
  produced "D-15-pass vs D-10-fail.")
- **`reboot_iop` value: `1`.** Set in `BuildPopstarterLaunchCommand` when
  `popstarter_on_hdd` is true: `bin/POPSLDR/system.lua:5554-5555`. A non-zero
  `reboot_iop` (here `1`) plus a present `exec_partition_context` is what makes
  `LaunchEngine` select the partition-aware binding (the gate is
  `exec_partition_context ~= nil and reboot_iop ~= 0`, `system.lua:5441-5443`).
- **Partition context is out-of-band.** `lua_loadELFWithPartition` requires a
  context shaped like `hdd?:PART:` and `reboot_iop != 0`, and never copies the
  context into the target argv: `src/luasystem.cpp:1033-1038` (the two guards:
  partition-shape at 1033-1035, `reboot_iop != 0` at 1036-1038),
  `src/luasystem.cpp:957-972` (`is_partition_context_arg`, which now also accepts a
  `dvr_hdd?:` shape at `luasystem.cpp:968` in addition to `hdd?:`).

### What breaks it

- Removing the `fileXioUmount` of the pfs prefix before `SifExitCmd()` in the
  partition-context branch (`loader.c:392-397`), or deleting the
  `is_hdd_partition_context` branch so D-10 falls through to the generic branch.
  The umount-then-`SifExitCmd` ordering in `loader.c:381-403` is what D-10
  depends on. (Relatedly, do not add `SifExitCmd()` to the generic branch
  `loader.c:404-427` — the comment at `loader.c:405-413` records that regression
  from when HDD used that branch; it now governs BOOT.ELF only (HDD DKWDRV uses
  the partition-context branch).)
- Re-excluding DKWDRV or otherwise letting an HDD-backed target slip both routing
  guards at `elf.c:645-648` / `elf.c:655-656` so it falls through to the direct
  `SifIopReset` path. The previous V3 logic did this and black-screened
  (`elf.c:628-648` comment; `QA_REGRESSION_MATRIX.md:124-134`).
- Changing the `EmbeddedLoaderMetadata` layout, address, or magic in only one of
  the two files (`elf.c:159-170` writer / `loader.c:148-155` reader). A mismatch
  makes `read_embedded_loader_metadata` return `-3302` (`loader.c:169`), and
  `main` paints the RED background and bails (`loader.c:300-301`).
- Forcing `reboot_iop` away from `1` for HDD POPSTARTER, which drops the
  partition-aware route (`system.lua:5441-5443`).

### How to test on hardware

Per `QA_REGRESSION_MATRIX.md` test-case `D-10` and the `docs/archive/HDD_POPSTARTER_HANDOFF.md`
test sequence: boot from HDD, with HDD sidecar/CWD/Profile/default `POPSTARTER.ELF`,
select an HDD title, confirm with `X`. Expected: real POPSTARTER boots the game,
no black screen. Then repeat with `R2` ("HDD Alt" / `full_hdd_pfs0` mode,
`full_hdd_pfs0` guard `ui.lua:2774`, R2 launch `ui.lua:2808`, R2 "HDD Alt" label
`ui.lua:2935`). Record in `QA_REGRESSION_MATRIX.md` as D-10.

---

## Contract D-15 — HDD game launched from a non-HDD POPSTARTER

**QA definition:** `QA_REGRESSION_MATRIX.md` test-case `D-15` — boot from USB/MMCE/MX4SIO with
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
  `PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER`, `system.lua:2002`). When the policy
  is HDD (HDD game) but POPSTARTER is non-HDD, `BuildPopstarterLaunchCommand`
  explicitly pins `reboot_iop = 0`: `bin/POPSLDR/system.lua:5556-5557`.
- **Legacy selector path, no partition API.** With `reboot_iop == 0`,
  `use_partition_api` is false (`system.lua:5441-5443`), so `LaunchEngine` calls
  `System.loadELF(exec_path, reboot_iop, selector)` (`system.lua:5448` /
  `5454` / `5460`). `lua_loadELF` with `reboot_iop == 0` and one extra arg goes to
  `LoadELFFromFileExecPS2`; with no extra args, to `LoadELFFromFile`:
  `src/luasystem.cpp:993-1008`. The selector stays as the single target
  `argv[0]`.
- **Keep-PFS mask protects the game's slots across exec.** Before exec,
  `PrepareForExternalELFLaunch` computes the keep slots and calls
  `System.setExecKeepPfsMask`, then unmounts only the non-kept slots:
  `bin/POPSLDR/system.lua:1090-1118`, mask built by `BuildPfsKeepMask`
  (`system.lua:1077-1088`). On the C side the mask is 4-bit
  (`SetExecKeepPfsMask`, `src/elf_loader/src/elf.c:35-37`) and
  `unmount_pfs_slots_for_exec` preserves masked slots
  (`src/elf_loader/src/elf.c:97-107`, `build_exec_keep_mask` at
  `elf.c:109-112`).

### What breaks it

- D-15 is the historical pass-side calibration point for the child teardown (the
  `loader.c:405-413` comment frames the no-`SifExitCmd` rule as "D-15-pass vs
  D-10-fail"), so any teardown change in the child loader should be re-tested
  against D-15 as well as D-10.
- Letting a second Lua argument leak into the non-HDD POPSTARTER call (the
  2026-05-20 D-15 regression at `QA_REGRESSION_MATRIX.md:139`). The fix was to
  keep `System.loadELF(path, reboot_iop, selector)` strictly one-selector;
  `lua_loadELF` enforces a single selector buffer (`src/luasystem.cpp:982-990`).
- Forcing `reboot_iop = 1` for non-HDD POPSTARTER, which would switch this case to
  the partition/reboot path it does not need.

### How to test on hardware

Boot from USB (or MMCE/MX4SIO), sidecar/Profile 1 `POPSTARTER.ELF` on that same
device, select an HDD title, confirm with `X`. Expected: HDD title launches, no
black screen. Per `docs/archive/HDD_POPSTARTER_HANDOFF.md` this is the **first** case to retest
after any launch-path change, because it is the known-good separator. Record as
D-15 in `QA_REGRESSION_MATRIX.md`.

---

## Contract U-10 — BOOT.ELF exit, `reboot_iop = 0` embedded-loader route (preserve the fix)

**QA definition:** `QA_REGRESSION_MATRIX.md` test-case `U-10` — open `HDD (PFS)` first so
dependency checks/scans run, return to the menu, launch `BOOT.ELF` from Exit;
"`BOOT.ELF` handoff succeeds without freezing or black-screening after HDD page
access."

**Hardware status: RESOLVED — preserve-the-fix contract.** The HDD-booted
sub-case (HDD-boot → Exit → BOOT.ELF) that previously black-screened was **fixed
by PR #479**, which forces `reboot_iop = 0` for BOOT.ELF in **all** cases —
including the HDD-booted one — so it takes the same working embedded-loader
no-reset route as the non-HDD case (Nuno hardware-confirmed 2026-05-31;
`STATE.md` "Reported Hardware Status" U-10 row). The non-HDD BOOT.ELF route
(L-07) was already PASS at V2 commit `d23520a`. **Both** sub-cases now share one
route; this contract is no longer a known-broken item but a regression-armor
contract that keeps the `reboot_iop = 0` route in place. Do not reintroduce a
`reboot_iop = 1` / `SifIopReset` branch for BOOT.ELF.

### What it guarantees (the working route)

For BOTH a non-HDD-booted AND an HDD-booted POPSLoader, "Exit → BOOT.ELF" reaches
`mc?:/BOOT/BOOT.ELF` through the embedded child loader's no-reset branch and runs
without hanging.

### How it is implemented

- **`reboot_iop` is pinned to `0` for BOOT.ELF — always.** `LaunchBootElf` sets
  `reboot_iop = 0` and never raises it; the HDD-loaded flag is now used **only**
  to pick the pfs teardown, not to change `reboot_iop`:
  `bin/POPSLDR/ui.lua:1591-1628` (reboot_iop=0 set at `ui.lua:1602`). When HDD was
  loaded this session
  (`PLDR.HDD.LOADSTATE != 0`), it calls `PrepareForColdExternalELFLaunch` (which
  unmounts every pfs slot, the only HDD state that matters here); otherwise
  `PrepareForExternalELFLaunch`: `ui.lua:1604-1608`. The inline comment
  (`ui.lua:1609-1623`) records the PR #479 diagnosis — a `reboot_iop = 1`
  `SifIopReset("", 0)` soft reset **cannot** reboot an HDD-dirtied IOP (dev9 /
  atad / pfs / fileXio still loaded), so `SifIopSync` spins → the black screen;
  the cold-prep unmount makes the no-reset path correct **and** sufficient.
- **The mc BOOT.ELF special-case routes through the embedded loader.**
  `System.loadELF(elf_path, 0)` with no extra args → `LoadELFFromFile` →
  `LoadELFFromFileWithPartition`, which special-cases `mc0:/BOOT/BOOT.ELF` /
  `mc1:/BOOT/BOOT.ELF` and calls
  `ExecuteViaEmbeddedLoader("", resolved_path, 1, boot_argv)`:
  `src/elf_loader/src/elf.c:499-502`. The child then takes the non-HDD generic
  branch (`SifExitRpc` only, no reset): `loader.c:404-427`. Because `reboot_iop`
  is now `0` for the HDD-booted case too, the HDD-boot sub-case takes this exact
  route — that is the PR #479 fix.
- **`PrepareForColdExternalELFLaunch` is what makes the no-reset route safe after
  HDD use.** It forces the keep mask to 0 and unmounts all pfs slots (including
  the held boot `pfs1:`), so no `SifIopReset` is needed to release `fileXio`'s
  hold: see the cross-cutting invariant below and `system.lua` cold-prep. This
  replaces the old approach that tried to reset the IOP for BOOT.ELF after HDD
  use (PR #450/#451, the wrong mechanism per the `ui.lua:1609-1623` comment).

### What breaks it

- Re-raising `reboot_iop` to `1` for BOOT.ELF when HDD was loaded (the exact
  pre-PR-#479 regression). The `SifIopReset` soft reset cannot reboot an
  HDD-dirtied IOP and `SifIopSync` spins → black screen (`ui.lua:1609-1623`).
  Keep `LaunchBootElf`'s `reboot_iop` at `0` and use the HDD flag only to select
  the cold pfs teardown.
- Adding a BOOT.ELF-specific IOP-reset branch to the child loader. PR #458 did
  this and regressed V2's working USB-boot exit (forced a reset BOOT.ELF does not
  tolerate); PR #460 reverted it (`docs/archive/LAUNCH_HYGIENE.md:56-71`,
  `QA_REGRESSION_MATRIX.md:169`). The child loader must stay reset-free for
  BOOT.ELF.
- Removing the mc BOOT.ELF special-case at `elf.c:499-502`, which would drop the
  working route through the embedded loader.
- Routing BOOT.ELF (which needs the cold pfs teardown when HDD was loaded) so
  that `PrepareForColdExternalELFLaunch` no longer unmounts the held boot
  `pfs1:` before the no-reset exec — that reintroduces the held-mount hang.

### How to test on hardware

- Non-HDD route (L-07): boot from USB/MC/MMCE/MX4SIO, Exit → BOOT.ELF. Expected:
  BOOT.ELF runs. Record as L-07/U-10 non-HDD.
- HDD route (U-10): boot from HDD, open `HDD (PFS)` first, return to menu,
  Exit → BOOT.ELF. Expected: BOOT.ELF runs (fixed by PR #479, Nuno-confirmed
  2026-05-31). Re-run this after any change to `LaunchBootElf`'s `reboot_iop` /
  cold-prep selection or to the mc BOOT.ELF special-case, and record the result
  in `QA_REGRESSION_MATRIX.md`.

---

## Contract DKWDRV-from-MC vs DKWDRV-from-HDD

**QA definitions:** `QA_REGRESSION_MATRIX.md` L-05 (mc?: DKWDRV alias resolves and
launches), `QA_REGRESSION_MATRIX.md` L-02 (missing-path UI message). MC DKWDRV is
the confirmed-working baseline; HDD DKWDRV from a custom HDD path is RESOLVED/PASS
(Nuno hardware-confirmed 2026-06-04/06-06, PRs #486/#487) via the partition-aware
route + live pfs-slot scan. Earlier HDD-DKWDRV builds black-screened (forensic
chronology in QA_REGRESSION_MATRIX.md); that route is superseded — see
QA_REGRESSION_MATRIX.md:194 and STATE.md:105.

**Hardware status:** MC DKWDRV works (`ui.lua:1540-1541` notes it confirmed
working; `docs/archive/LAUNCH_HYGIENE.md:114`). HDD DKWDRV from a custom HDD path
is RESOLVED/PASS (Nuno hardware-confirmed 2026-06-04/06-06, PRs #486/#487) via the
partition-aware route (loadELFWithPartition → ExecuteHddBackedViaEmbeddedLoader) +
live pfs-slot scan (`QA_REGRESSION_MATRIX.md:194`; `STATE.md:53,105`). Earlier
direct-path builds black-screened (forensic chronology
`QA_REGRESSION_MATRIX.md:163,166`); preserve the two-half contract regardless.

### What it guarantees

- **MC / non-HDD DKWDRV** (`mc?:/PS1_DKWDRV/DKWDRV.ELF`) launches via a full IOP
  reset with reloaded MC modules and a synthesized `argv[0]`.
- **HDD DKWDRV** (`hdd?:/`, `pfs?:/`, `ata?:/`, `apa?:/`) launches via the same
  BRAM embedded-loader contract as POPSTARTER-on-HDD — the V2 BOOT.ELF mimicry —
  rather than the direct path that black-screened.

### How it is implemented

- **Route selection in Lua by where DKWDRV lives AND whether POPSLoader booted
  from HDD.** `OpenDKWDRV` (`bin/POPSLDR/ui.lua:1370`) resolves the configured
  path, then routes in three cases (`ui.lua:1453-1546`):
  (1) MC / non-HDD DKWDRV from an HDD-booted launcher (`hdd_loaded and not
  is_hdd_path`) → cold prep + `System.loadELF(elf_path, 0, elf_path)`
  (`ui.lua:1479-1487`);
  (2) HDD-resident DKWDRV (`is_hdd_path`, any boot source) → cold prep +
  `System.loadELFWithPartition(pfs:/REL, 1, hdd0:PART:, argv0)`
  (`ui.lua:1488-1532`), i.e. reboot_iop=1 via the partition-aware
  `ExecuteHddBackedViaEmbeddedLoader` route shared with POPSTARTER-on-HDD (NOT a
  plain `loadELF` with reboot_iop=0);
  (3) MC / non-HDD DKWDRV, non-HDD boot → `System.loadELF(elf_path, 1, elf_path)`
  (`ui.lua:1539-1545`), the confirmed-working MC reboot route.
  The per-case route rationale is documented inline at `ui.lua:1452-1477`.
- **HDD DKWDRV now uses the SAME partition-aware C path as POPSTARTER-on-HDD**,
  not the `is_dkwdrv_elf_path` special-case. `OpenDKWDRV` Case (2) calls
  `System.loadELFWithPartition(exec_path_norm, 1, partition_context, elf_path)`
  (`bin/POPSLDR/ui.lua:1532`) with a non-empty `hdd0:PART:` context →
  `lua_loadELFWithPartition` (`src/luasystem.cpp:1020`, registered at `:1351`) →
  `LoadELFFromFileExecPS2RebootIOPWithPartition` (`src/elf_loader/src/elf.c:618`).
  The HDD guard at `elf.c:645-648` (non-empty partition + `is_hdd_backed_exec_path`)
  early-returns `ExecuteHddBackedViaEmbeddedLoader` (`elf.c:336`), and the BRAM
  child loader takes the `is_hdd_partition_context` branch
  (`src/elf_loader/src/loader/src/loader.c:381-403`). The `is_dkwdrv_elf_path`
  special-case in `LoadELFFromFileWithPartition` (`elf.c:516-519`, contract comment
  `elf.c:505-515`) is RETAINED but is no longer on the live HDD route — it only
  fires via the `System.loadELF` path. See the in-source note at `elf.c:146-150`.
- **MC DKWDRV** (`reboot_iop = 1`) → `lua_loadELF` with one extra arg →
  `LoadELFFromFileExecPS2RebootIOP` → the reboot variant
  (`LoadELFFromFileExecPS2RebootIOPWithPartition`, `elf.c:618`). Its non-HDD tail
  resets the IOP, reloads `rom0:SIO2MAN/MCMAN/MCSERV`, and synthesizes
  `argv[0] = resolved_path` for DKWDRV before `ExecPS2`:
  `src/elf_loader/src/elf.c:686-711` (module reload at `elf.c:696-698`, DKWDRV
  argv0 synthesis at `elf.c:705-711`).

### What breaks it

- Trying only the Lua half for HDD DKWDRV (`reboot_iop = 0`) without the C-side
  embedded-loader route — PR #452 (V4) did exactly this, fell through to direct
  `LoadExecPS2`, and black-screened (`elf.c:509-514` comment;
  `QA_REGRESSION_MATRIX.md:163`). Both halves are required.
- Removing the DKWDRV special-case at `elf.c:516-519`.
- Changing `is_dkwdrv_elf_path` (`elf.c:119-144`) so a real `DKWDRV.ELF` path no
  longer matches, which silently drops both the HDD route and the MC argv0
  synthesis.
- Changing the HDD-path → `reboot_iop = 1` + `loadELFWithPartition` selection
  (Case 2) in `OpenDKWDRV` (`ui.lua:1488-1532`).

### How to test on hardware

- MC DKWDRV: configure `DKWDRV_PATH` to `mc?:/PS1_DKWDRV/DKWDRV.ELF`, launch the
  Disc option. Expected: DKWDRV runs (baseline). Record per
  `QA_REGRESSION_MATRIX.md:62`.
- HDD DKWDRV: set `DKWDRV_PATH` to an HDD path (e.g.
  `hdd0:/__common:pfs1:/APPS/PS1_DKWDRV/DKWDRV.ELF`), launch the Disc option.
  Expected: DKWDRV runs. RESOLVED/PASS — Nuno hardware-confirmed 2026-06-04/06-06
  (PRs #486/#487). Re-run after any change to the OpenDKWDRV HDD-path route, the
  partition-context builders, or the elf.c is_dkwdrv_elf_path special-case, and
  record the result in `QA_REGRESSION_MATRIX.md`.

---

## Cross-cutting invariants (apply to all four contracts)

- **`EmbeddedLoaderMetadata` is duplicated and must stay byte-identical.** Writer:
  `src/elf_loader/src/elf.c:159-170`. Reader: `src/elf_loader/src/loader/src/loader.c:144-155`.
  Same magic (`0x504F504C`), version (`1`), address (`0x00083C00`), and field
  layout (`partition_context[128]`, `load_path[256]`). A mismatch → `-3302` from
  `read_embedded_loader_metadata` (`loader.c:169`) → RED background in `main`
  (`loader.c:300-301`).
- **The keep-PFS mask is 4-bit and single-shot.** `SetExecKeepPfsMask` masks
  `& 0x0F` (`elf.c:35-37`); only slots 0-3 are protected
  (`unmount_pfs_slots_for_exec`, `elf.c:97-107`). The boot partition is hard-mounted
  to `pfs1:` and "NEVER USE IT FOR ANYTHING ELSE" (`etc/boot.lua:45-48`), so slot 1
  must be kept across BOOT.ELF/exit or `SifIopReset` hangs (the U-10 mode). The
  bindings call `ClearExecKeepPfsMask()` only *after* the launch call returns
  (`src/luasystem.cpp:998,1010,1063,1081,1086`) — and a successful `ExecPS2` never returns,
  so the mask is cleared only on failure.
- **A launch that returns is a failure.** `ExecuteViaEmbeddedLoader` returns
  `(ret != 0) ? ret : -3600` (`elf.c:478`); the child returns `-3500` /
  `-3200+ret` sentinels (`loader.c:378,402,427 (-3500); 432 (-3200+ret); 434 (-3201)`). These negative codes
  surface in the `BlockLaunchFailure` diagnostic screen. Any non-hang return from
  a launch is fatal, not success.
- **`PrepareForColdExternalELFLaunch` forces the keep mask to 0** and unmounts all
  pfs slots (`system.lua:1120-1130`, invoked from `LaunchEngine` when
  `context.cold_external_launch == true`, `system.lua:5426-5427`). Use it only for
  a no-reset launch that does **not** need any `pfs1:` mount to survive into the
  target. This is exactly the HDD-boot BOOT.ELF case post-PR-#479: BOOT.ELF takes
  the `reboot_iop = 0` embedded-loader route, so unmounting the held boot `pfs1:`
  is what makes the no-reset handoff safe (see Contract U-10). Conversely, a launch
  that needs `pfs1:` to survive (an HDD game / HDD POPSTARTER) must **not** go
  through the cold prep — use the keep-mask route instead.

## Settings-path mini-contract — `EnsureBootPartitionWritable` (HDD RW take-over)

`PLDR.HDD.EnsureBootPartitionWritable` is the boot pfs-slot "take over the mount"
routine: it explicitly unmounts the launcher's own boot partition and remounts the
**same partition read-write at the same pfs slot** (the OPL "own your mount"
pattern). It is now **load-bearing for HDD-resident settings save and for HDD
in-app `.hide`** (L3 toggle) — on an HDD install there is no
`mc0:` fallback, so this RW remount is the only path that lets the `.pldrs`
sidecar and `.hide` markers be written on-HDD. provato hardware-confirmed the HDD
is RW-writable via this take-over.

This is a **settings/persistence** path, not a launch / ELF-handoff path, so it is
not one of the four launch contracts above — but mount/launch changes must not
break it: do not change which pfs slot the boot partition owns, do not leave the
boot partition mounted read-only when settings need to persist, and do not unmount
it out from under the settings write. Cross-reference: `STATE.md` > "Settings
(single-device parity)", "Behavioral Invariants" (#2, #10), and the
`EnsureBootPartitionWritable` bullet under `STATE.md` > "Preservation Contracts".

## Do not do

- Do not add `SifExitCmd()` to the child generic/empty-context branch
  (`loader.c:404-427`, used by BOOT.ELF only; HDD DKWDRV takes the partition-context
  branch like D-10). D-10's own branch
  (`loader.c:381-403`) intentionally DOES call `SifExitCmd()` — but only after
  unmounting the pfs prefix; do not remove that umount.
- Do not add IOP-reset branches for BOOT.ELF or DKWDRV to the child loader
  (reverted in PR #460; `docs/archive/LAUNCH_HYGIENE.md:56-71`).
- Do not re-gate the pre-reset pfs unmount on `is_hdd_backed_exec_path`
  (`elf.c:686`).
- Do not edit the `EmbeddedLoaderMetadata` struct in only one of the two files.
- Do not change the POPSTARTER selector `argv[0]` contract or let partition
  context leak into target argv (`src/luasystem.cpp:1033-1038`).
- Do not mark D-10, D-14, D-15, U-10, or HDD DKWDRV as hardware-PASS without an
  actual hardware result recorded in `QA_REGRESSION_MATRIX.md`.
- After ANY edit to `src/elf_loader/src/loader/src/loader.c`, regenerate and
  commit `src/elf_loader/loader.c` (`make clean elfloader all`); CI enforces a
  byte-parity check (`docs/archive/HDD_POPSTARTER_HANDOFF.md:110-114`).
