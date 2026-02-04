# AGENTS.md (Enceladus POPSLoader fork)

This is a contributor + AI-agent guide for working on this repository while preserving boot behavior across devices (MC/USB/MMCE/MX4SIO/HDD/PFS).

The project has two layers:

- **Runtime (C/C++)**: Enceladus (Lua VM + graphics/audio/pad + system utilities)
- **App (Lua + assets)**: POPSLoader scripts/textures/configs under `bin/POPSLDR/`

When debugging, always identify which layer is failing:

- If you get a Lua error screen (blue text), the runtime is alive and `etc/boot.lua` ran.
- If you get a pure black screen with no text, you are likely hanging before graphics/screen init (often during early IOP init or module load), or not reaching `main()` at all.

---

## Repository map

Top-level:

- `Makefile` — builds the EE ELF, embeds IOP modules + `etc/boot.lua`, creates `bin/POPSLOADER_<variant>.ELF`.
- `src/` — Enceladus runtime sources.
- `iop/` — custom IOP modules (notably `iop/bdm_query/`).
- `modules/` — DS3/DS4 pad modules (ds34usb/ds34bt) + pademu.
- `etc/boot.lua` — Lua bootstrap embedded into the ELF at build time.
- `bin/` — runtime assets and packaged content (what ends up next to the ELF in releases).

App assets / scripts (POPSLoader layer):

- `bin/POPSLDR/system.lua` — app entrypoint the embedded `boot.lua` typically loads.
- `bin/POPSLDR/ui.lua` — UI logic and page routing.
- `bin/POPSLDR/pops_profiles.lua` — profile + POPStarter path logic.
- `bin/POPSLDR/IMG/` — PNGs plus `images.lua` describing image registration.
- `bin/POPSLDR/POPSTARTER.ELF` — POPStarter payload shipped alongside the launcher (may be overridden by the user).
- `bin/POPSLDR/*.irx.*` — device-specific IRX variants used by the Lua layer.

---

## Build variants

The Makefile defines a build variant via `VARIANT`:

- `VARIANT=mmce`  → `-DBOOT_MMCE`
- `VARIANT=mx4sio` → `-DBOOT_MX4SIO`
- `VARIANT=hdd`   → `-DBOOT_HDD`

Output:
- `bin/POPSLOADER_<variant>.ELF`

Common invocations:

```sh
make clean
make VARIANT=mmce
make VARIANT=mx4sio
make VARIANT=hdd
```

Packaging:
- `make package VARIANT=<variant>` produces `POPSLoader-<variant>.7z` from `bin/package/`.

---

## Runtime boot flow (EE)

Primary entry point: `src/main.cpp`.

Key boot steps (conceptual):

1. Parse `argv[0]` into:
   - `boot_path` = directory used for `chdir(boot_path)` (so Lua opens scripts relative to it)
   - `app_dir`   = directory prefix used by asset resolvers
2. IOP init / module load (IRX) via `SifExecModuleBuffer` (iomanX, fileXio, padman, libsd, etc.)
3. Initialize graphics (gsKit) and pads.
4. `chdir(boot_path)`
5. Run the embedded `etc/boot.lua` string via `runScript(bootString, true)`
6. On error, show the Enceladus error screen and wait for START.

Important globals and helpers:

- `boot_path` and `app_dir` are declared in `src/main.cpp`.
- Asset resolution helpers live in `src/system.cpp`.

---

## Asset resolution

Runtime-side path resolution is primarily implemented in:

- `src/system.cpp`
  - `ResolveAssetPath(...)`
  - `ResolveAssetPathTyped(..., ASSET_IMG|ASSET_IRX|...)`

Behavior summary:

- If the requested path is already “absolute” for PS2 I/O (contains `:`), it is used as-is.
- Otherwise, it tries combinations under `app_dir`, including:
  - `<app_dir><relative>`
  - `<app_dir>POPSLDR/<relative>`
  - For typed assets, also `<app_dir>IMG/<relative>` and `<app_dir>POPSLDR/IMG/<relative>` (images),
    and similar for IRX (`IRX/`).

Fallback:
- It will also attempt the current working directory (`getcwd`) with the same patterns.

Implication:
- For HDD/PFS boot, `argv[0]`, `boot_path`, `app_dir`, and current working directory are all high-leverage. Break those and you get “missing scripts/assets” at best, or a pre-graphics hang at worst.

---

## IOP modules and why POPStarter changes the rules

The runtime loads IOP modules from embedded blobs (see Makefile `IOP_MODULES` list), then Lua scripts may load additional IRX depending on feature/page.

Critical POPStarter invariant (from maintainer notes):

- POPStarter typically **reboots the IOP** and does **everything based on `argv[0]`**.
- Any mounts or loaded IRX you set up before launching POPStarter are not guaranteed to persist.

Practical consequences for this repo:

- Do not assume “keep pfs0 open for POPStarter.” POPStarter will nuke your IOP state.
- The reliable input you can control is the path/argv you use to launch POPStarter.

---

## HDD / APA / PFS boot notes

Terminology:

- “APA HDD” usually implies PS2 internal HDD with APA partitions mounted via `pfsX:/`.
- Many launchers mount a PFS partition and execute an ELF from `pfs0:/.../POPSLOADER.ELF`.

Risk areas when HDD-booting:

- Resetting the IOP at the wrong time can invalidate launcher-owned mounts.
- Skipping SIF initialization (RPC) can prevent module loads and cause early hangs.
- Loading USB/BDM stacks too early (or in the wrong environment) can deadlock certain HDD launch paths.

The HDD variant should be conservative:

- Avoid any assumption that `mass:/` exists.
- Avoid “wait for mass root” loops when launched from `pfs`/`hdd0:`.
- Ensure whatever initialization you do still reaches `initGraphics()` and can display an error (never fail silently).

---

## Where to look first for “boot to black screen”

If a build black-screens before showing even the Enceladus error screen:

1. `src/main.cpp`:
   - Anything conditional on `BOOT_HDD`
   - Any waits/loops before `initGraphics()`
   - Any `SifInitRpc` / `SifIopReset` logic that differs by device
   - Any module loads that can hang the boot path (especially on HDD/PFS launchers)

2. `src/system.cpp`:
   - `__ps2_normalize_path` special-cases `pfs` paths
   - Asset path fallbacks that depend on `app_dir`/`cwd`

3. Lua app entry:
   - `bin/POPSLDR/system.lua` is the first file you typically need to find.
   - If `boot_path` is wrong, `system.lua` won’t be found, and you should see an error screen (unless you never reach graphics).

---

## “Safe change” rules for automated edits

- Prefer minimal changes around boot/mount logic.
- Treat `src/main.cpp` as high-risk: a small ordering change can brick multiple boot paths.
- Never hardcode a device root for assets (e.g., `mass0:`/`pfs0:`); preserve the existing dynamic resolution logic.
- Keep code style consistent and avoid introducing partial edits or unfinished blocks.

---

## Quick reference: files by responsibility

Runtime core:

- `src/main.cpp` — boot, module load, enter Lua
- `src/system.cpp` — path normalization + asset resolution
- `src/luasystem.cpp` — Lua-exposed system calls and storage probing utilities
- `src/luaHDD.cpp` / `src/luaSMB.cpp` — HDD/SMB Lua bindings and devctl usage
- `src/graphics.cpp`, `src/render.cpp`, `src/sound.cpp`, `src/pad.cpp` — subsystems

IOP:

- `iop/bdm_query/*` — custom module used to query BDM devices

Lua app:

- `bin/POPSLDR/system.lua` — main script
- `bin/POPSLDR/ui.lua` — UI
- `bin/POPSLDR/pops_profiles.lua` — profiles / POPStarter selection
- `bin/POPSLDR/IMG/images.lua` — image registration map

---

## Baseline smoke tests (before/after any change)

Boot the ELF from:

- `mc0:` (if supported by your launcher)
- USB `mass0:` (single + dual USB)
- `mmce0:` / `mmce1:`
- `mx4sio:` (mass1 or whichever the stack assigns)
- HDD `pfs0:` (APA partition launcher path)

Confirm:

- Enceladus splash/UI appears
- Pages load
- POPStarter launches (expect long stalls on some devices; that can be normal)
- Returning to UI doesn’t corrupt input or graphics

If you cannot reproduce easily, at minimum validate:

- No new infinite loops before `initGraphics()`
- `boot_path` and `app_dir` are consistent and normalized for `pfs` and `massN` paths
