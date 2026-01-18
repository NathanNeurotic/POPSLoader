# Behavior audit (code-derived)

> **Docs drift warning:** This document is derived from code inspection and overrides any conflicting docs. Where behavior is unclear or not observable from code, it is marked as **Unknown / requires confirmation**.

## Boot directory ("bootDir") derivation

**Current behavior:**

* **C runtime boot path (C layer):** `setLuaBootPath()` derives `boot_path` from `argv[0]` by truncating the last path segment (`/` or `\`) or device prefix, then normalizes the root and ensures it ends with a trailing slash. It falls back to a normalized preferred device root if `argv[0]` lacks a device prefix. `boot_path` is used as the working directory (`chdir(boot_path)`).【F:src/main.cpp†L221-L392】
* **Lua boot path (Lua layer):** `etc/boot.lua` defines `BOOT_PATH` as `System.deriveBaseDir(System.GetArgv0() or System.currentDirectory())`, sets the process working directory to this derived base, and exposes `BOOT_PATH` for subsequent scripts. It also sets `RUNTIME_ROOT = BOOT_PATH` and `POPSTARTER_PATH = BOOT_PATH.."POPSTARTER.ELF"`.【F:etc/boot.lua†L72-L199】
* **Current Directory usage:** `bin/system.lua` and `bin/pops_profiles.lua` rely on `System.currentDirectory()` and `BOOT_PATH` to resolve POPStarter paths and local assets, e.g., `JoinPath(System.currentDirectory(), "POPSTARTER.ELF")`.【F:bin/system.lua†L33-L58】【F:bin/pops_profiles.lua†L11-L37】

**Implication:** The code already treats the directory of the running ELF (or its derived base directory) as the primary boot root; both C and Lua layers enforce trailing slashes for `boot_path`/`BOOT_PATH` and use it for relative path resolution and `chdir()`.【F:src/main.cpp†L221-L392】【F:etc/boot.lua†L72-L199】

**Unknown / requires confirmation:** Whether `System.deriveBaseDir()` exactly matches the C-side `setLuaBootPath()` behavior in all edge cases (e.g., odd path formats, missing separators). This needs runtime verification.

## IRX discovery and load behavior

**Current behavior:**

* **Boot-time embedded IRXs:** The C runtime loads multiple embedded IRX modules on startup, including `mmceman_irx` and USB/MC-related modules. This happens unconditionally at boot and before the Lua UI runs.【F:src/main.cpp†L285-L368】
* **Lua auto-loading of external IRXs:** `bin/system.lua` scans the **current directory** for files whose last 4 characters are `.irx` (case-insensitive). If any are found, it loads **all** `.irx` files from that directory via `IOP.loadModule(...)` and logs each result.【F:bin/system.lua†L15-L32】

**Implication:** The system *already* auto-loads `.irx` files from the working directory on startup (Lua), and also loads the embedded `mmceman_irx` at boot (C). There is no on-demand IRX loading tied to device page activation in the current code. 【F:src/main.cpp†L285-L368】【F:bin/system.lua†L15-L32】

**Unknown / requires confirmation:** Any additional IRX loads performed by embedded Lua bundles or `SYSTEM_LUA` injection not visible in `bin/system.lua` itself.

## Device probing and POPS root detection

**Current behavior:**

* **C layer device probe:** `detectPreferredDevice()` checks a fixed order of roots (mmce1/mmce0 then mass0–3) for a `POPS/` directory, falling back to `mmce0:/`. MMCE availability is probed first; if no mmce devices respond, mmce roots are skipped and mmce is marked disabled for the session.【F:src/main.cpp†L45-L190】
* **Lua layer device probe:** `etc/boot.lua` uses `wait_for_ready` and `System.fileXioDopen` to find the first ready `POPS/` directory in a fixed order (mmce1/mmce0 then mass roots), then sets `BOOT_DEVICE_ROOT` accordingly.【F:etc/boot.lua†L90-L125】
* **UI selection behavior:** `bin/system.lua` uses `PLDR.FindPopsRootFor(...)` with device orders for USB and MMCE, and the UI sends a notification if no `POPS/` root is found for the selected device page.【F:bin/system.lua†L78-L160】【F:bin/ui.lua†L171-L214】

**Unknown / requires confirmation:** Whether `BOOT_DEVICE_ROOT` is always in sync with the C-side preferred device once Lua is running; there are two separate probe paths.

## Launch pipeline (current)

**Pipeline map (code-derived):**

1. **UI selection** (USB/MMCE/HDD) and game list refresh: `UI.MainMenu.Play()` selects a device, then `PLDR.FindPopsRootFor(...)` and `PLDR.GetPS1GameLists(...)` populate the list.【F:bin/ui.lua†L171-L214】【F:bin/system.lua†L120-L236】
2. **Profile resolution:** `bin/pops_profiles.lua` defines `PLDR.PROFILES` and sets `PLDR.POPSTARTER_PATH` from the selected profile, typically using `System.currentDirectory()` plus `POPSTARTER.ELF`.【F:bin/pops_profiles.lua†L11-L37】
3. **Path building:** `PLDR.RunPOPStarterGame()` builds `BOOTPARAM` from `gamelocation` + `game` with a device replacement for mass, and prefixes `XX.` for USB/MMCE scenes.【F:bin/system.lua†L371-L389】
4. **ELF handoff:** `System.loadELF(PLDR.POPSTARTER_PATH, PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER, BOOTPARAM, "--nr")` is invoked in Lua. The Lua binding prints the ELF path and argv values, then calls `LoadELFFromFile(...)` in C. The C loader ultimately calls `ExecPS2(...)` in `load_elf()` (via the embedded loader).【F:bin/system.lua†L371-L389】【F:src/luasystem.cpp†L666-L704】【F:src/system.cpp†L350-L420】

**Unknown / requires confirmation:** Whether `PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER` is ever toggled in the current UI; it defaults to `0` in `bin/system.lua` and no UI controls are shown in this audit.【F:bin/system.lua†L84-L104】

## Pad input timing behavior

**Current behavior:**

* The UI uses `UI.Pad.Listen()` which enforces a fixed debounce delay `PDELAY = 600` milliseconds. While the delay is active, `GPAD` is set to 0, otherwise `GPAD = Pads.get()` and `CLK` is updated. There is **no** explicit press-edge detection or hold-to-repeat behavior beyond this delay gate.【F:bin/ui.lua†L222-L244】

**Unknown / requires confirmation:** Whether the pad polling frequency or `Timer` resolution varies by platform configuration.

## Notes on requested behavior vs current implementation

The following requested behaviors **are not currently implemented** in the code, based on this audit:

* On-demand MMCE/MX4SIO external IRX load tied to device page activation; current code loads embedded mmceman at boot and loads all `.irx` from the current directory during Lua startup. 【F:src/main.cpp†L285-L368】【F:bin/system.lua†L15-L32】
* `bootDir`-scoped IRX pack discovery with marker files and deterministic ordering; current logic loads all `.irx` files in the current directory without ordering or filtering. 【F:bin/system.lua†L15-L32】
* LAUNCH_TRACE macro and detailed launch tracing; current Lua binding logs basic ELF path/argv but no macro-controlled trace or post-ExecPS2 watchdog. 【F:src/luasystem.cpp†L666-L704】
* Pad input debounce/repeat scheme with edge-trigger and configurable repeat delays; current logic is a single fixed delay. 【F:bin/ui.lua†L222-L244】

If these changes are still desired, they require code modifications beyond this documentation-only update.
