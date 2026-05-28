# U-10 Investigation: BOOT.ELF exit from HDD-booted POPSLoader

Date: 2026-05-26 (original), updated 2026-05-28 with PR #463/#464 outcomes, and again 2026-05-28 PM with the surprising resolution.
Author: Claude (with NathanNeurotic direction)

## Status (as of 2026-05-28 PM)

**PASS — unexpectedly resolved.** Nuno reports BOOT.ELF exit working "across the board" including HDD-booted POPSLoader on the rolling-release artifact built post-PR-#470/#472/#473.

None of those PRs architecturally touch the U-10 path (`LoadELFFromFileExecPS2RebootIOPWithPartition` direct path, IOP reset, MC module reload). The cause of the resolution is not obvious from the diff. Possible explanations:

1. **C-layer `EnsureUsbMass`-first reordering in `lua_mx4sio_init` (PR #472)** — the maintainer-enforced order now means `usbmass_bd`/`bdmfs_fatfs`/`bdm` are guaranteed loaded before any MX4SIO call, even when MX4SIO isn't actually present. This might be incidentally cleaning some IOP state that the U-10 reset path was tripping over.
2. **The "U-10 fails" reports were partially obscured by the now-fixed boot crash.** The 2026-05-28 morning rolling-release had the `ClassifyMassRootDriver` forward-reference nil-call crash (PR #473 hotfix). Earlier U-10 fail reports may have been misattributed; the actual failure point might have been earlier (boot crash) rather than at BOOT.ELF exit.
3. **Test-environment change** on Nuno's side (MC contents, HDD state, etc.).

This file is preserved as the **hypothesis catalog in case U-10 regresses**. If a future change reintroduces the failure, the diagnostic-first workflow below still applies: ship a colored sentinel build before another fix attempt.

### What was tried since the original investigation note

- **PR #463 diagnostic build** (`LOADER_ENABLE_DEBUG_COLORS=1`, branch `claude/diag-u10`): localized the hang. Last visible stage on hardware (Nuno 2026-05-26) was **YELLOW** (post-`SifLoadElf`, pre-`SifIopReset`). The **ORANGE** post-reset stage never paints — `SifIopReset` itself hangs. This matches **H5** below (stale `pfs1:` mount blocks the reset, similar to the documented `fileXio`-blocks-reset class from ps2sdk #425).
- **PR #464 F4 fix**: `LoadELFFromFileExecPS2RebootIOPWithPartition` unconditionally calls `unmount_pfs_slots_for_exec(build_exec_keep_mask(resolved_path))` before `SifIopReset` (was previously gated on HDD-backed exec path, which skipped the unmount for BOOT.ELF on MC). Plus `etc/boot.lua` normalizes any pfs slot prefix in `BOOTPATH` to `pfs1:` so Lua's cwd matches the actual mount slot. **Hardware result 2026-05-27 (Nuno): FAIL — still black-screens.** F4 unconditional unmount alone wasn't enough.
- **PR #466 release prep**: accepted U-10 as known-broken; closed PR #463 (diag) and PR #465 (HDD r/w driver swap probe) as superseded. Branches preserved.

The H5-based unmount approach (F4) doesn't fix it; the next investigation angle would likely be **H1** (explicit `dev9Shutdown` before exec) or stacking F1+F4. But the diagnostic-first discipline applies: confirm via colored sentinel that the hang point moved before claiming a fix on hardware.

> **This file is U-10-specific.** Other BOOT.ELF routes (autoboot / OSDmenu / Browser / HOSDMenu / PSBBN / USB-booted POPSLoader) work via the V2 route at commit `d23520a` and are hardware-confirmed. Do not collapse U-10 status into generic BOOT.ELF status.

## Symptom

When POPSLoader was booted from HDD (`argv[0]` starts with `hdd0:`, `etc/boot.lua` mounts `pfs1:` RW), selecting "Exit -> BOOT.ELF" black-screens. The target is `mc0:/BOOT/BOOT.ELF` or `mc1:/BOOT/BOOT.ELF` (whichever exists first).

When POPSLoader was booted from a non-HDD device (USB / MC / MMCE / MX4SIO), the same Exit -> BOOT.ELF flow works (L-07 PASS at V2 commit `d23520a`, 2026-05-23).

## What both flows have in common

After PR #460, both flows route the same way at the Lua / C boundary:

- USB-booted: `LaunchBootElf` -> `reboot_iop = 0` (because `PLDR.HDD.LOADSTATE == 0`) -> `System.loadELF(elf_path, 0)` -> `LoadELFFromFileWithPartition` -> BOOT.ELF special case at line 485 -> `ExecuteViaEmbeddedLoader("", resolved_path, 1, boot_argv)` -> child loader -> non-HDD branch -> `SifExitRpc + FlushCache + ExecPS2`. No IOP reset.

- HDD-booted: `LaunchBootElf` -> `reboot_iop = 1` (because `PLDR.HDD.LOADSTATE != 0`) -> `System.loadELF(elf_path, 1)` -> `LoadELFFromFileExecPS2RebootIOPWithPartition` -> direct path (no BOOT.ELF special case in the reboot variant after PR #460) -> `SifLoadElf + SifIopReset + reload SIO2MAN/MCMAN/MCSERV + ExecPS2`. IOP reset.

## What's different at exec time

| Aspect | USB-booted POPSLoader exit | HDD-booted POPSLoader exit |
|---|---|---|
| `etc/boot.lua` mount | nothing | `HDD.MountPartition(MNTPART, 1)` mounts `pfs1:` RW |
| `PLDR.HDD.LOADSTATE` | 0 | non-zero |
| HDD IRX loaded | only if user visited HDD page | always (loaded by boot.lua) |
| `_ps2sdk_memory_init` IOP reset at POPSLoader boot | yes (clears parent state) | yes (same code path) |
| EE RAM "POPSLoader residue" at exec time | child loader's `wipeUserMem` clears it | NO `wipeUserMem` -- direct path doesn't run it |
| IOP reset before ExecPS2 to BOOT.ELF | NO (works) | YES (still fails) |
| Module reload after reset | n/a | SIO2MAN, MCMAN, MCSERV |
| DEV9 hardware state | likely clean (never used) | active (HDD I/O happened) |
| `fileXio` RPC server state | likely never initialized | active (boot.lua + runtime use) |

**The two flows diverge in three concrete ways**: (1) the EE-RAM scrub via `wipeUserMem`, (2) the IOP reset, (3) the underlying DEV9 hardware state and what's been on the IOP between boot and exec.

## Hypotheses

### H1: DEV9 hardware state survives `SifIopReset`

`SifIopReset` reloads IOP firmware and IRX modules from ROM, but the **DEV9 expansion module (ATA + network)** has hardware state in the PS2's expansion hardware that the IOP firmware reset alone doesn't power-cycle. BOOT.ELF expects DEV9 in a particular state (off, or fresh-initialized); inheriting a "warm" DEV9 from HDD-active POPSLoader confuses BOOT.ELF's own DEV9 init.

**Evidence**: Forum threads on ps2dev describe needing explicit `dev9Shutdown()` (or PS2SDK `dev9PowerOff()`) before passing control to software that doesn't expect DEV9 active. NHDDL and OPL both have explicit DEV9 shutdown sequences before their ExecPS2 hand-offs.

**Testability**: high. Single sequenced call in the launch path. Risk-bounded (DEV9 isn't otherwise needed by BOOT.ELF).

### H2: EE-RAM pollution

The reboot-variant direct path doesn't run `wipeUserMem()`. BOOT.ELF inherits POPSLoader's `.bss` / heap residue. If BOOT.ELF reads uninitialized EE memory at startup and gets non-zero from POPSLoader, behavior is undefined.

**Evidence**: V2's working USB-booted route DOES go through the child loader which runs `wipeUserMem()`. So at least the wipe is correlated with success in the working case.

**Testability**: medium. Routing HDD-booted BOOT.ELF through `ExecuteViaEmbeddedLoader` (same as USB-booted, plus `wipeUserMem`) without adding any IOP reset branch would test this directly. PR #458 tried this but ALSO added a buggy `is_boot_elf_target` reset branch that broke both flows; testing H2 cleanly requires the wipe routing WITHOUT the reset branch.

### H3: IOP module-load conflict at BOOT.ELF startup

After the IOP reset, we reload `SIO2MAN`/`MCMAN`/`MCSERV`. BOOT.ELF may try to load its own copies (or rely on its own ROM-bundled versions) and encounter "already loaded" conflicts that crash its init.

**Evidence**: wLaunchELF's reference loader **never reloads modules after `SifIopReset`** -- it just resets and `ExecPS2`s with `argv` = original path. POPSLoader's reload is a divergence from the reference.

**Testability**: medium. Remove the post-reset `SifLoadModule` calls in the direct path (or special-case BOOT.ELF). Risk: if BOOT.ELF DOES expect these modules pre-loaded, we'd break the USB-booted case that currently works... except the USB-booted case doesn't go through this path. So this test is safe.

### H4: `SifInitRpc(0)` timing / handshake

After `SifIopReset`, the EE-side `SifInitRpc(0)` call may complete before the IOP-side RPC server is fully ready. The 2026-05-22 D-10 diagnostic series (recorded in `QA_REGRESSION_MATRIX.md`) hit this exact issue with a different target -- multiple sentinel builds hung at `SifInitRpc(0)` after reset, freezing on the diagnostic color marker.

**Evidence**: The B2 fix that resolved D-10 used `SifLoadElf via pfs0 mount` BEFORE `SifIopReset`, not after. The HDD POPSTARTER path NEVER re-runs `SifInitRpc(0)` post-reset because it doesn't need to (the target carries its own RPC bootstrap).

**Testability**: high if we have diagnostic colors. The existing `LOADER_ENABLE_DEBUG_COLORS` macro in `src/elf_loader/src/loader/src/loader.c` paints background at each stage. If H4 is right, we'd freeze on the green/cyan post-reset stage rather than going dark.

### H5: Stale `pfs1:` mount blocks IOP reset

`etc/boot.lua` mounts `pfs1:` via `HDD.MountPartition` at boot for HDD-booted POPSLoader. That mount is still active when LaunchBootElf fires. `PLDR.PrepareForColdExternalELFLaunch` is supposed to clear the keep mask and unmount tracked HDD slots, but if it misses the boot-time `pfs1:` (boot.lua mounted it before the runtime tracker existed), the reset could hang on a held PFS lock similar to the documented `fileXio`-blocks-reset bug (ps2sdk #425).

**Evidence**: ps2sdk #425 documents the general class of "an active IRX-server-side resource holds the IOP reset". Boot.lua's `pfs1:` mount is exactly this class of resource and may be untracked by the runtime.

**Testability**: high. Inspect `PLDR.PrepareForColdExternalELFLaunch` for whether it unmounts the boot-time `pfs1:` slot. If it doesn't, add an explicit `fileXioUmount("pfs1:")` to that function. Bonus: this fix would apply uniformly regardless of whether the IOP reset succeeds or is removed.

## Diagnostic plan

Before another fix attempt, ship a **diagnostic build** with `LOADER_ENABLE_DEBUG_COLORS` defined. The child loader paints the screen at each stage:

| Color | Stage |
|---|---|
| WHITE | main() entry |
| CYAN | after argv parse |
| GREEN | before SifLoadElf |
| BLUE | after SifLoadElf |
| YELLOW | SifLoadElf returned epc != 0 |
| ORANGE | after IOP reset (where applicable) |
| BROWN | before final FlushCache |
| PURPLE | immediately before ExecPS2 |

The HDD-booted BOOT.ELF flow currently goes through the **direct path** (not the child loader), so this instrumentation wouldn't fire as-is. To get diagnostic data on U-10 specifically, we need to also add stage colors to the **parent's direct path** in `LoadELFFromFileExecPS2RebootIOPWithPartition`. That's a ~5-line addition gated on the same `LOADER_ENABLE_DEBUG_COLORS` define.

One Nuno test session with this build gives us:
- The exact stage color at black-screen -> which stage died
- Whether ExecPS2 returned (and what rc) or never returned

That tells us which hypothesis to pursue and rules out the others.

## Candidate fixes (ordered by H plausibility + risk)

### F1: Explicit `dev9Shutdown` before exec (tests H1)

Add a call to `dev9Shutdown()` (or the equivalent SDK call) in the HDD-booted BOOT.ELF path before `SifLoadFileInit/SifLoadElf`. Targets H1. Low collateral risk.

Implementation site: `LoadELFFromFileExecPS2RebootIOPWithPartition` direct path, gated on `is_hdd_backed_exec_path(POPSLoader's own boot device)` -- i.e. we need a flag indicating "POPSLoader was booted from HDD" surfaced to elf.c, OR pass it via Lua.

Risk: low for BOOT.ELF (doesn't use DEV9). Higher if applied uniformly (could break HDD-game launches). Must be scoped to the BOOT.ELF-from-HDD-boot path specifically.

### F2: Route HDD-booted BOOT.ELF through child loader (tests H2)

Add the BOOT.ELF special-case routing to `LoadELFFromFileExecPS2RebootIOPWithPartition` (mirror line 485 of `LoadELFFromFileWithPartition`). The child loader's non-HDD branch runs `wipeUserMem` AND skips the IOP reset. Different from PR #458's broken attempt: this version does NOT add an `is_boot_elf_target` IOP-reset branch in the child loader; falls through to the existing non-HDD branch.

Risk: PR #458 tried this combined with the reset branch and BOOT.ELF still failed. Testing H2 cleanly requires JUST the routing, NO additional reset logic. Has not been tested in isolation.

### F3: Remove post-reset module reload for BOOT.ELF (tests H3)

In the direct path, when target is `mc?:/BOOT/BOOT.ELF`, skip the `SifLoadModule("rom0:SIO2MAN"...)` etc. block. Reset only, then ExecPS2.

Risk: medium. If BOOT.ELF needs MCMAN to read its own config, this breaks BOOT.ELF on memory-card filesystem. But BOOT.ELF is on MC and BOOT.ELF's own startup likely reloads what it needs.

### F4: Unmount `pfs1:` boot mount before reset (tests H5)

Modify `PLDR.PrepareForColdExternalELFLaunch` to explicitly call `System.unmountHddPartition("pfs1:")` (or whatever the API is) -- specifically targeting the boot-time PFS mount that boot.lua established.

Risk: low. The mount is no longer needed once we're committing to ExecPS2. If for some reason POPSLoader's cleanup path also needs that mount (it shouldn't -- we're exiting), unmount fails gracefully.

## Recommended sequencing

1. **Ship diagnostic build first.** No fix attempt without color data. ~30 minutes of code, 30 minutes of Nuno test.
2. If the screen freezes on **GREEN/CYAN** (pre-reset stages) -> H5 is most likely. Apply F4.
3. If the screen freezes on **ORANGE** (post-reset, pre-reload) or **BROWN** (post-reload, pre-FlushCache) -> H4 is most likely. SIF RPC is hung. Apply F1 (DEV9 shutdown might unblock it indirectly by removing an IOP-side resource holder).
4. If the screen freezes on **PURPLE** (just before ExecPS2) or goes dark immediately after -> H1/H2 most likely. ExecPS2 itself or BOOT.ELF's first few instructions hang. Apply F1 + F2 together.
5. If the screen goes through all colors then dark with no ExecPS2 return -> classic "target didn't start" -> H1/H2. Apply F1 + F2.

## Do NOT do without color data

- Random PR rotation. We've burned 5+ rounds of guess-fix-test on this. Stop.
- Combined fixes. Test one hypothesis at a time so the result is unambiguous.

## References

- ps2sdk issue #425 (fileXio blocks IOP reset): https://github.com/ps2dev/ps2sdk/issues/425
- wLaunchELF loader.c (reference for "reset + ExecPS2, no module reload"): https://github.com/ps2homebrew/wLaunchELF/blob/master/loader/loader.c
- OPL iopmgr.c (reference for ResetIopSpecial + explicit DEV9 handling): https://github.com/ps2homebrew/Open-PS2-Loader/blob/master/ee_core/src/iopmgr.c
- B2 fix that resolved D-10 (PFS unmount before ExecPS2): commit `4ae6679`
- V2 BOOT.ELF working route (non-reboot variant + ExecuteViaEmbeddedLoader): commit `d23520a`
- PR #458 reverts (failed reset branches): see `docs/LAUNCH_HYGIENE.md`
