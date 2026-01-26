# Repo map (POPSLoader)

## Project identity (from repo)
- POPSLoader is a Lua-scripted launcher built on the Enceladus runtime and packaged as `POPSLOADER.ELF` with scripts, textures, and modules in this repo.【F:README.md†L5-L8】

## Entrypoints and boot chain
- **EE entrypoint:** `main()` in `src/main.cpp` initializes IOP modules, sets the boot/app paths, then runs the embedded Lua boot script in a loop via `runScript(bootString, true)`.【F:src/main.cpp†L321-L437】
- **Lua boot:** `etc/boot.lua` sets the Lua `package.path`, initializes fonts, and loads `system.lua` via `System.resolveAsset` + `RunScript`.【F:etc/boot.lua†L9-L133】
- **Lua runtime:** `bin/POPSLDR/system.lua` loads UI modules (`ui.lua`, `images.lua`) and drives the main UI loop (`UI.WelcomeDraw.Play()` + `while true` scene dispatch).【F:bin/POPSLDR/system.lua†L241-L283】【F:bin/POPSLDR/system.lua†L1298-L1319】

## UI stack (Lua)
- **Scene/controller layer:** `bin/POPSLDR/ui.lua` defines `UI.SCENES`, menu logic, input handling, and per-scene render/interaction functions (main menu, profile selection, game list, credits).【F:bin/POPSLDR/ui.lua†L11-L603】
- **UI assets:** `bin/POPSLDR/images.lua` enumerates UI image assets and lazy-loads them via `Graphics.loadImage` using `System.resolveAssetType` fallback logic.【F:bin/POPSLDR/images.lua†L10-L65】

## Native runtime + Lua bindings
- **System/Lua bindings:** `src/luasystem.cpp` registers the `System` table and global flags like `MMCE_SLOT0_READY` / `MMCE_SLOT1_READY` for Lua-side device detection and asset resolution.【F:src/luasystem.cpp†L1104-L1135】
- **Graphics/Lua bindings:** `src/luagraphics.cpp` exposes `Font.ftPrint` (alignment parameter + width/height) that calls `fntRenderString`, forming the basis of UI text layout.【F:src/luagraphics.cpp†L114-L127】
- **Font alignment rules:** `src/fntsys.cpp` defines alignment bitmasks (`ALIGN_HCENTER`, `ALIGN_VCENTER`, etc.) and applies them in `fntRenderString`.【F:src/fntsys.cpp†L102-L109】【F:src/fntsys.cpp†L603-L623】

## Runtime layout & asset boundaries
- **Runtime layout rules:** `docs/RUNTIME_LAYOUT.md` is the canonical reference for asset layout and search order (flat layout first, legacy fallbacks).【F:docs/RUNTIME_LAYOUT.md†L1-L31】
- **Lua search path:** `etc/boot.lua` defines the Lua search order (APP_DIR first, legacy `POPSLDR/` fallback).【F:etc/boot.lua†L9-L11】

## Ownership/boundaries (what to touch for what)
- **`src/` (C/C++ runtime):** Bootstraps EE, loads IOP modules, provides Lua bindings, graphics/font subsystems, and device probing logic. Changes here affect the runtime and system APIs used by Lua.【F:src/main.cpp†L321-L437】【F:src/luasystem.cpp†L1104-L1135】【F:src/luagraphics.cpp†L114-L127】
- **`etc/` (embedded boot Lua):** Controls Lua boot sequencing, search paths, and font initialization. Changes here affect bootstrap and asset resolution order.【F:etc/boot.lua†L9-L133】
- **`bin/POPSLDR/` (Lua UI + launch logic):** UI scenes, input mapping, asset lookups, and game launch orchestration. Changes here affect user-visible behavior and launch flows.【F:bin/POPSLDR/system.lua†L14-L349】【F:bin/POPSLDR/ui.lua†L11-L603】
- **`docs/` (documentation):** Canonical docs for runtime layout, launch behavior, and debugging guidance. Updates here do not change runtime behavior.【F:README.md†L13-L20】【F:docs/RUNTIME_LAYOUT.md†L1-L31】
