# UI map (rendering flow, scenes, input, alignment)

## Rendering flow (boot → UI loop)
1. **EE entrypoint** runs the embedded Lua boot script via `runScript(bootString, true)`.【F:src/main.cpp†L321-L437】
2. **Lua boot** (`etc/boot.lua`) sets `package.path`, initializes fonts, and loads `system.lua` via `System.resolveAsset` + `RunScript`.【F:etc/boot.lua†L9-L133】
3. **Lua runtime** (`bin/POPSLDR/system.lua`) loads `ui.lua` and `images.lua`, runs the welcome splash (`UI.WelcomeDraw.Play()`), then enters the main scene loop that calls per-scene `Play()` functions and `UI.flip()` each frame.【F:bin/POPSLDR/system.lua†L241-L283】【F:bin/POPSLDR/system.lua†L1298-L1319】

## Scenes/pages
- **Scene table:** `UI.SCENES = {GUSB, GSMB, GMX4SIO, GHDD, MMAIN, MPROFILE, CREDITS}` in `ui.lua`.【F:bin/POPSLDR/ui.lua†L11-L15】
- **Scene dispatch:** In the main loop, `MMAIN` → main menu, `MPROFILE` → profile picker, `<= GHDD` → game list, `CREDITS` → credits screen.【F:bin/POPSLDR/system.lua†L1304-L1314】
- **Main menu options:** UI presents `USB`, `MMCE`, `MX4SIO`, `HDD` and routes to the corresponding device pages and game list population logic.【F:bin/POPSLDR/ui.lua†L330-L428】
- **USB page model:** There is one USB game-list scene (`GUSB`) and it is fed by merged USB roots; do not document or design separate FAT32/exFAT USB pages in this branch.

## Input mapping (Pads → UI events)
- **Event mapping:** `Pad.Listen()` translates pad state into events:
  - `PAD_CROSS` → `CONFIRM`
  - `PAD_CIRCLE` → `BACK`
  - `PAD_TRIANGLE` → `EXIT`
  - `PAD_START` → `START`
  - `PAD_SELECT` → `SELECT`
  - D-pad → `NAV_UP/DOWN/LEFT/RIGHT` with neutral-gate handling.
  【F:bin/POPSLDR/ui.lua†L456-L552】
- **Action throttling:** `MIN_ACTION_MS` gates repeated action inputs to prevent rapid repeats.【F:bin/POPSLDR/ui.lua†L67-L69】【F:bin/POPSLDR/ui.lua†L518-L523】
- **Global exit handling:** Triangle triggers the exit modal unless a modal or launch is active.【F:bin/POPSLDR/ui.lua†L221-L233】【F:bin/POPSLDR/ui.lua†L135-L176】

## Layout and alignment rules
- **Screen constants:** Base UI resolution and midpoints come from `UI.SCR` (`X=702`, `Y=480`, `X_MID`, `Y_MID`, `_480p`).【F:bin/POPSLDR/ui.lua†L59-L66】
- **Font alignment:** `Font.ftPrint` takes an alignment bitmask that is passed to `fntRenderString`. Alignment flags include `ALIGN_HCENTER` and `ALIGN_VCENTER`, applied during render to shift text positioning. (UI commonly passes `8` for horizontal centering.)【F:src/luagraphics.cpp†L114-L127】【F:src/fntsys.cpp†L102-L109】【F:src/fntsys.cpp†L603-L623】【F:bin/POPSLDR/ui.lua†L109-L112】
- **Font initialization:** Built-in fonts are loaded and sized during boot in `etc/boot.lua`.【F:etc/boot.lua†L74-L80】

## UI assets (images)
- **Image registry:** `images.lua` lists UI image files (USB/MMCE/MX4SIO/HDD icons, button glyphs) and lazily loads them via `Graphics.loadImage` with `System.resolveAssetType` fallback logic.【F:bin/POPSLDR/images.lua†L10-L65】

## UI behaviors & pages (high-level)
- **Exit modal:** `UI.Modal.OpenExit()` shows a confirmation box and `System.exitToBrowser()` is called on confirm.【F:bin/POPSLDR/ui.lua†L135-L176】
- **Game list page:** `UI.GameList.Play()` renders the list, handles navigation, and calls `PLDR.RunPOPStarterGame` on confirm when a game is selected; for USB this launch now uses per-entry source metadata instead of a single global `mass` index.【F:bin/POPSLDR/ui.lua†L242-L303】【F:bin/POPSLDR/ui.lua†L1185-L1240】【F:bin/POPSLDR/system.lua†L1548-L1619】
- **Main menu routing:** Selecting USB triggers merged USB list population via `PLDR.GetMergedUsbGameList`, which aggregates games from detected `mass*:/POPS/` roots into the single USB page. MMCE/MX4SIO keep dedicated detection/list logic; HDD uses HDD module init and list build.【F:bin/POPSLDR/ui.lua†L1185-L1240】【F:bin/POPSLDR/system.lua†L639-L757】

## UNKNOWNs (not found in repo)
- **Exact meaning of alignment constants at the Lua call sites** beyond the `ALIGN_*` bitmask definitions is not described in docs; to confirm usage, inspect `fntRenderString` and call sites.
  - Suggested command: `rg -n "ftPrint" bin/POPSLDR src` (call sites) and `rg -n "ALIGN_" src/fntsys.cpp` (definitions).
