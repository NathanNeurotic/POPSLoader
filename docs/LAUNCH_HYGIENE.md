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

### Layer D -- NHDDL-style launch arguments (landed 2026-05-25)

CosmicScale requested `-mode=ata` style boot arguments to skip directly to
a device page. Shipped infrastructure:

**`src/main.cpp` `parseLaunchArgs()`** runs immediately after `argv[0]`
capture, before any IRX loads. Recognized flags:

| Flag | Effect |
|---|---|
| `-page=hdd|usb|mc|mmce|mx4sio|smb|bdma` | Auto-navigate hint for the UI |
| `-mode=<value>` | NHDDL-compatible alias for `-page` (e.g. `-mode=ata` maps to HDD) |
| `-game=<selector>` | Auto-launch hint (game selector / profile / path) |
| `-noaudio` | Skip `audsrv_irx` + `libsd_irx` at boot |
| `-debug` | Enable diagnostic output |

**Lua exposure**: `System.getLaunchArgs()` returns `{page, game, noaudio,
debug}`. `system.lua` reads this at init and stores normalized values in
`PLDR.LAUNCH_ARGS = {page, page_raw, game, noaudio, debug}`. Page values
are normalized via `NormalizeLaunchPage()` so `ata`/`pfs`/`apa`/`hdd` all
map to `"HDD"`, `usb`/`mass` to `"USB"`, etc.

**Auto-navigation wiring** is intentionally deferred. The infrastructure
is in place; downstream UI code in `ui.lua` can pick up `PLDR.LAUNCH_ARGS`
when ready to act on it. This avoids touching the existing initial-page
selection logic until that's a focused follow-up.

### Settings sidecar (landed 2026-05-25)

Replaces hardcoded `PLDR.SETTINGS_PATH = "mc0:/POPSTARTER/.pldrs"` with a
per-device sidecar resolution + MC fallback. New constants:

- `PLDR.SETTINGS_PATH_FALLBACK = "mc0:/POPSTARTER/.pldrs"` (legacy path)
- `PLDR.SETTINGS_PATH_SIDECAR` -- computed from `APP_DIR_LOCAL/.pldrs`
  when `APP_DIR_LOCAL` is NOT HDD-backed (avoid PFS RW remount). `nil`
  for HDD-backed installs.
- `PLDR.SETTINGS_PATH` -- the *active* path; resolved at load time to
  whichever file exists first (sidecar preferred, fallback otherwise).

Behavior:
- **Load**: try sidecar first, then fallback. Pin `PLDR.SETTINGS_PATH`
  to whichever loaded. If neither exists, leave it at the init default
  (sidecar preferred so the first save lands per-device).
- **Save**: write to `PLDR.SETTINGS_PATH`. Only fail on
  `EnsurePopstarterDir` if the target IS the MC fallback (sidecar saves
  don't need `mc0:/POPSTARTER`).
- **HDD installs**: `SETTINGS_PATH_SIDECAR == nil`, so settings continue
  to use `mc0:/POPSTARTER/.pldrs`. Avoids the PFS-mounted-RW complexity
  for HDD-resident POPSLoader.

### Layer C -- Lazy IRX loading (partial; landed 2026-05-25, more queued)

Shipped in this PR:
- **Pre-Lua device classification hint**: `main.cpp`
  `detectBootDeviceHintFromArgv0()` returns the device-kind label for
  argv[0]. Stored in `boot_device_hint` global, exposed via
  `System.getBootDeviceHint()`. Used by `system.lua` for early decisions
  before `DetectBootDevice` runs full authoritative resolution.
- **`-noaudio` deferral**: skips `libsd_irx` and `audsrv_irx` IRX loads
  at boot when the flag is present. Lua sound code should check
  `PLDR.LAUNCH_ARGS.noaudio` before calling sound APIs (TODO: audit
  sound call sites).

Still queued for a focused follow-up (intentionally NOT in this PR
because aggressive deferral changes module load order which is high-
risk for input/controller availability):
- Defer `mmceman_irx` unless boot device is MMCE (saves ~1 module load)
- Defer `ds34bt_irx` unless user has BT pads enabled
- Defer `usbd_irx` unless boot device is USB / MX4SIO / DS3-4 USB
- Add `EnsureAudio()`, `EnsureBluetoothPad()` Lua-callable helpers

#### Layer C precursor (landed 2026-05-25)

`bin/POPSLDR/system.lua` `DetectBootDevice()` now recognizes additional
SDK device-kind prefixes that some homebrew launchers pass. These are
**additive** -- the existing detection chain (mmce, mx4sio, mass with the
mx4sio classify_mass_boot fix, pfs, hdd, smb, host) is unchanged. The new
branches are placed just before the `return nil` fallback so they only
catch what would otherwise be unclassified:

| Prefix pattern | Maps to | Rationale |
|---|---|---|
| `usb`, `usb0`, `usb1`, ... | USB | Newer ps2sdk SDK USB prefix (was `mass:` only) |
| `ata`, `ata0`, `ata1`, ... | HDD | ATA-backed HDD semantic prefix |
| `apa`, `apa0`, `apa1`, ... | HDD | APA partition system semantic prefix |

`mx4sio` was already in the existing detection (line 1705); the user's
"mx4sio's mass fix" lives entirely inside the `mass%d*` branch and is
not touched. Both old launchers (using `mass:`) and new launchers (using
`usb:`/`ata:`/`apa:`) now resolve to the correct device classification.

Expected improvement (when full Layer C lazy IRX loading lands): 30-50%
reduction in pre-Lua startup time, possibly more on cold boots where
IRX loads dominate the budget.

## Safety audit (Layers A and B)

| Path | Layer A impact | Layer B impact |
|---|---|---|
| D-10 (HDD POPSTARTER + HDD game) | New teardown runs at POPSLoader boot; child loader HDD partition branch unchanged | Unchanged -- POPSTARTER target matches neither `is_dkwdrv_target` nor `is_boot_elf_target` |
| D-15 (USB POPSTARTER + HDD game) | New teardown runs at POPSLoader boot; direct path in elf.c unchanged | Not reached (POPSTARTER doesn't trigger child loader reset branches) |
| DKWDRV from MC (working baseline) | Boot teardown runs once | Not reached (MC DKWDRV uses direct path, not child loader) |
| BOOT.ELF from USB-booted POPSLoader | Boot teardown runs once | Routed through child loader (PR #458 change); now also gets the SifExitRpc pre-teardown |
| All clean-parent launches | SifExitRpc + fileXioExit are guarded no-ops; same effective state as before | N/A |

## Flagged separately: settings sidecar is not currently implemented

User raised the concern that "settings sidecar may not be working" while
discussing Layer C. Confirmed during the 2026-05-25 audit:

- `PLDR.SETTINGS_PATH` is hardcoded to `"mc0:/POPSTARTER/.pldrs"` at
  `bin/POPSLDR/system.lua` line 1971.
- `PLDR.SaveSettingsAtomic()` writes to that exact path (no fallback).
- `PLDR.LoadSettingsNonFatal()` reads from that exact path (no fallback).
- The "sidecar" functions that DO exist (`BuildPopstarterSidecarCandidate`,
  `CollectHddBootSidecarCandidates`, `ResolveHddBootSidecarPopstarter`) are
  for resolving the **POPSTARTER.ELF** path -- not for settings.

So a POPSLoader running off USB/HDD/MX4SIO still writes settings to
`mc0:/POPSTARTER/.pldrs`. There is currently no per-device settings
sidecar, despite naming that suggests otherwise.

This is **not in scope of the launch hygiene fix**. A separate PR
should:
1. Add per-device settings sidecar resolution: try `<APP_DIR>.pldrs`
   first, fall back to `mc0:/POPSTARTER/.pldrs`.
2. Migrate write-side similarly (write to wherever it was loaded from).
3. Consider whether to copy from MC to sidecar on first run.

## References

- [ps2sdk issue #425 -- "`fileXio` somehow blocks `IOP` to reset"](https://github.com/ps2dev/ps2sdk/issues/425)
- [ps2sdk PR #426 -- libc fio pointer backup/restore in fileXioInit/Exit](https://github.com/ps2dev/ps2sdk/pull/426)
- [wLaunchELF loader source -- conditional IOP reset for HDD targets only](https://github.com/ps2homebrew/wLaunchELF/blob/master/loader/loader.c)
- [OPL ee_core/src/iopmgr.c -- gold-standard reset sequence with `SifSetReg` patches](https://github.com/ps2homebrew/Open-PS2-Loader/blob/master/ee_core/src/iopmgr.c)
