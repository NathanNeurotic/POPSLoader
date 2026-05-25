# POPSLoader Launch Hygiene

Date: 2026-05-25
Author: Claude (with NathanNeurotic direction; user thesis on hang/deinit problem confirmed)

## TL;DR

Four launch-related symptoms reported across recent hardware testing share a
single root cause: **POPSLoader does not survive an IOP that has `fileXio`
loaded from a parent process**. The `fileXio` IRX module holds threads and RPC
locks on the IOP that cause `SifIopReset` to hang silently. This bug is
documented upstream in [ps2sdk issue #425](https://github.com/ps2dev/ps2sdk/issues/425)
and partly addressed by [ps2sdk PR #426](https://github.com/ps2dev/ps2sdk/pull/426).
The fix family in this document covers the EE-side workaround (detach the RPC
client before resetting) and the resulting unification of three previously
unrelated-looking bugs.

## Symptoms

| Symptom | Reporter | Root cause |
|---|---|---|
| Launching POPSLoader from wLaunchELF black-screens (only for non-HDD targets) | CosmicScale 2026-05-25 | `_ps2sdk_memory_init` hangs on `SifIopReset` because wLaunchELF left `fileXio` loaded |
| DKWDRV from a custom HDD path black-screens | Nuno 2026-05-25 | Child loader's `SifIopReset` hangs because POPSLoader's `fileXio` (used to mount the partition) is still alive on the IOP |
| BOOT.ELF from HDD-booted POPSLoader black-screens | Nuno 2026-05-25 | Same hang shape as DKWDRV; the reset never completes |
| Atrocious boot times | NathanNeurotic | Sequential pre-Lua load of 11+ IRX modules in `main()`; unrelated to fileXio bug, but tracked as Layer C below |

## Why each "clean" parent works

PSBBN, Browser, HOSDMenu, OSDMenu either reset the IOP themselves before
handing off, or never loaded `fileXio` in the first place. wLaunchELF
[only resets the IOP when launching HDD targets](https://github.com/ps2homebrew/wLaunchELF/blob/master/loader/loader.c)
for backward compatibility with older homebrew; that's the asymmetry that
makes wLaunchELF-from-USB break while wLaunchELF-from-HDD works.

## The teardown contract

The robust pre-reset sequence is:

```c
SifExitRpc();        /* drop any inherited RPC client binding */
SifInitRpc(0);       /* fresh RPC handshake */
fileXioExit();       /* restore libc fio fn pointers if hijacked (PR #426) */
SifIopReset("", 0);  /* now succeeds */
SifIopSync();
SifInitRpc(0);       /* ready for module loads */
```

`SifExitRpc()` and `fileXioExit()` are both safe to call on uninitialized
state -- they're guarded. Clean parents see no behavior change; polluted
parents now reset cleanly.

## Fix layers

### Layer A -- EE bootstrap (`src/main.cpp` `_ps2sdk_memory_init`)

Adds the teardown contract above before the existing reset. Runs once, before
`main()`, as a ps2sdk weak-function override. Effectively a defensive prelude
for any future parent that leaves `fileXio` loaded.

### Layer B -- Child loader DKWDRV/BOOT.ELF reset branches (`src/elf_loader/src/loader/src/loader.c`)

PR #458 added new reset branches in the BRAM child loader's `main()` for
DKWDRV and BOOT.ELF targets. Without Layer B, those resets are subject to the
same hang because POPSLoader's own `fileXio` is alive on the IOP at hand-off
time. Layer B prepends `SifExitRpc(); SifInitRpc(0);` before each
`SifIopReset` to detach the RPC client cleanly.

### Layer C -- Lazy IRX loading (future PR)

`main()` currently loads 11 IRX modules sequentially before `boot.lua`
starts. Most aren't needed until the user navigates to a specific page.
Strategy:

- **Always at startup (core):** iomanX, fileXio, sio2man, mcman, mcserv,
  padman. These are needed for settings I/O, MC, controllers, RPC plumbing.
- **Lazy on device-page entry:** usbd + usbhdfsd (USB page), mmceman (MMCE
  page), mx4sio (MX4SIO page), ps2dev9 + ps2atad + ps2hdd + ps2fs (HDD pages,
  already lazy via `luaHDD.cpp`).
- **Lazy on first use:** audsrv + libsd (only when audio plays),
  ds34usb + ds34bt (only when user enables bluetooth pads in Settings).

Device detection: peek at `argv[0]` device prefix (`mass:`, `mc?:`, `hdd0:`,
`mmce?:`, `mx4sio?:`) in `setLuaBootPath()` to know which device the user
launched from. Settings sidecar resolution (cwd-anchored) stays unchanged.

Expected improvement: 30-50% reduction in pre-Lua startup time, possibly
more on cold boots where IRX loads dominate the budget.

### Layer D -- NHDDL-style launch arguments (future PR)

CosmicScale requested `-mode=ata` style boot arguments to skip directly to
a device page. Parse `argv` in `main()` before `runScript("boot.lua")` and
expose to Lua as a `LaunchArgs` global table. Candidate arguments:

- `-page=hdd` / `-page=usb` / `-page=mmce` / `-page=mx4sio` / `-page=smb` / `-page=bdma`
- `-game=<selector>` (auto-launch a specific game on boot)
- `-noaudio` (skip audio init for fastest possible boot)
- `-debug` (enable on-screen diagnostics)

## Safety audit (Layers A and B)

| Path | Layer A impact | Layer B impact |
|---|---|---|
| D-10 (HDD POPSTARTER + HDD game) | New teardown runs at POPSLoader boot; child loader HDD partition branch unchanged | Unchanged -- POPSTARTER target matches neither `is_dkwdrv_target` nor `is_boot_elf_target` |
| D-15 (USB POPSTARTER + HDD game) | New teardown runs at POPSLoader boot; direct path in elf.c unchanged | Not reached (POPSTARTER doesn't trigger child loader reset branches) |
| DKWDRV from MC (working baseline) | Boot teardown runs once | Not reached (MC DKWDRV uses direct path, not child loader) |
| BOOT.ELF from USB-booted POPSLoader | Boot teardown runs once | Routed through child loader (PR #458 change); now also gets the SifExitRpc pre-teardown |
| All clean-parent launches | SifExitRpc + fileXioExit are guarded no-ops; same effective state as before | N/A |

## References

- [ps2sdk issue #425 -- "`fileXio` somehow blocks `IOP` to reset"](https://github.com/ps2dev/ps2sdk/issues/425)
- [ps2sdk PR #426 -- libc fio pointer backup/restore in fileXioInit/Exit](https://github.com/ps2dev/ps2sdk/pull/426)
- [wLaunchELF loader source -- conditional IOP reset for HDD targets only](https://github.com/ps2homebrew/wLaunchELF/blob/master/loader/loader.c)
- [OPL ee_core/src/iopmgr.c -- gold-standard reset sequence with `SifSetReg` patches](https://github.com/ps2homebrew/Open-PS2-Loader/blob/master/ee_core/src/iopmgr.c)
