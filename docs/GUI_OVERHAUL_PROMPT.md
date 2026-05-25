# POPSLoader GUI overhaul — Berion mockups

**Status:** queued work, not yet started. Recorded 2026-05-24.
**Scope:** four screens (Context menu, Settings, Joypad config, OSK).
**Out of scope:** boot/splash screen, game list screen.

## Repository state of referenced files (as of 2026-05-24)

The prompt below references `app/screens.jsx`, `app/styles.css`, and an `index.html` mockup wrapper as the "visual oracle." **Those files are not currently committed to this repo.** They were delivered by the Designer agent as part of `assets.zip` (the PNG bundle landed in commit `f8fec64` "Add OSK + nav UI assets to bin/POPSLDR/IMG/"), but the HTML/JSX mockup wrapper itself was not extracted into the source tree.

Before starting this work, either:
- commit the mockup HTML/JSX into a fresh `app/` directory (recommended — gives future agents the same visual oracle the prompt assumes), or
- adapt the prompt to point at the screenshot PNGs / hosted mockup link the implementer has access to.

The PNG asset list the prompt cites is fully present under `bin/POPSLDR/IMG/` after `f8fec64`. The 33 new files are:

`arrow_choose_left_active.png`, `arrow_choose_left_active_no.png`, `arrow_choose_right_active.png`, `arrow_choose_right_active_no.png`, `arrow_pointer.png`, `bar_highlight.png`, `bar_top.png`, `checkbox_empty.png`, `checkbox_full.png`, `icon_sub_about.png`, `icon_sub_exit.png`, `icon_sub_joypad.png`, `icon_sub_mcmanager.png`, `icon_sub_settings.png`, `icon_sub_settings_restore.png`, `icon_sub_settings_save.png`, `joypad.png`, `osk_bg.png`, `osk_cursor.png`, `osk_highlight_1.png`, `osk_highlight_2.png`, `osk_highlight_3.png`, `osk_highlight_4.png`, `osk_highlight_5.png`, `osk_symbol_backspace.png`, `osk_symbol_caps.png`, `osk_symbol_clear.png`, `osk_symbol_mode.png`, `osk_symbol_space.png`, `scroll_bg_bottom.png`, `scroll_bg_middle.png`, `scroll_bg_top.png`, `scroll_zip.png`.

## Prerequisites before starting

- D-10 / D-14 / D-15 / U-10 hardware verification must settle first (per `memory/project-settings-redesign.md` standing rule). U-10 + DKWDRV-on-HDD are still in active hardware testing as of 2026-05-24 (PRs #451 / #452 merged, awaiting results).
- Do not regress any of the `S-*` / `U-*` rows in `QA_REGRESSION_MATRIX.md` while doing the visual overhaul. The current Settings page in `bin/POPSLDR/ui.lua` is the OPL-style focused-list (commit `c8312d8`); this overhaul replaces that with the category-page model below.

---

## Claude Code prompt — POPSLoader GUI overhaul

> Paste the block below into Claude Code with this repo (`NathanNeurotic/POPSLoader`) checked out. It has full context, the assets list, and per-screen specs derived from Berion's mockups.

---

### Role

You are working on **NathanNeurotic/POPSLoader**, a PS2 homebrew launcher whose GUI is rendered by `ui.lua` (~3,500 lines) on the LuaPlayer/PS2 engine via `Graphics.*` / `Image.new` / `Font.print` primitives. The mockups for this overhaul were produced by the graphics team (Berion) and the corresponding asset PNGs already exist in `bin/POPSLDR/IMG/`. Bonus asset: `icon_sub_mcmanager.png`. Binary size is expected to grow by ~150 KiB.

**Do not** alter:
- the boot/splash screen
- the game list screen

**Do** overhaul these four screens to match the mockups exactly (no improvising, no extra hints/labels/icons):
1. Context menu
2. Settings — restructured as a main page listing categories, each category opens its own page
3. Joypad configuration
4. On-screen keyboard (OSK)

---

### Constraints

- Match the mockups **pixel-for-pixel** where possible. The mockups are the source of truth, not your sense of "nicer."
- Render at the existing 640×480 native resolution.
- Do not add new dependencies. Use only what `ui.lua` already imports.
- Do not refactor unrelated code paths or rename existing globals. Add helpers locally next to where they're used.
- Keep the existing input model (D-pad navigation, ×/○/△/▢, L1/R1).
- Open a PR branch — **do not push to `master`**. Suggested branch name: `feat/gui-overhaul-berion-mockups`.

---

### Assets (already in repo under `bin/POPSLDR/IMG/`)

Common:
- `icon_sub_settings.png`, `icon_sub_settings_save.png`, `icon_sub_settings_restore.png`
- `icon_sub_joypad.png`, `icon_sub_about.png`, `icon_sub_exit.png`
- `icon_sub_mcmanager.png` (new — bonus)
- `bar_top.png` (scrollbar thumb), `bar_highlight.png` (selected-row band)
- `arrow_pointer.png` (▸ indicator on selected row)
- `arrow_choose_left_active.png`, `arrow_choose_right_active.png`
- `arrow_choose_left_active_no.png`, `arrow_choose_right_active_no.png` (disabled)
- `checkbox_empty.png`, `checkbox_full.png`

Joypad: `joypad.png` (640×432 controller with all leader-line labels baked in, transparent bg).

OSK:
- `osk_bg.png` (512×256 keyboard backdrop — every key tile + CLEAR/SPACE/MODE chamfers baked in)
- `osk_highlight_1..5.png` (selected-key glow variants)
- `osk_cursor.png` (the little arrow cursor)
- `osk_symbol_caps.png` (Aa), `osk_symbol_backspace.png` (←)
- `osk_symbol_clear.png`, `osk_symbol_space.png`, `osk_symbol_mode.png`

Load each via `Image.new("IMG/<file>.png")` (or whatever path convention `ui.lua` already uses) and cache once at module init, not per frame.

---

### Per-screen spec

#### 1. Context menu

A vertically centered list, left-padded ~52 px. Rows are 38 px tall with 6 px gaps, font weight 700 / 22 px / off-white when unselected, full white when selected. The 32×32 icon sits left of each label with 16 px gap. Unselected rows are 55% opacity (icon + text).

Order, top to bottom:
1. Settings (`icon_sub_settings.png`)
2. Save Changes (`icon_sub_settings_save.png`)
3. Restore Default (`icon_sub_settings_restore.png`)
4. Joypad Configuration (`icon_sub_joypad.png`)
5. About (`icon_sub_about.png`)
6. Exit (`icon_sub_exit.png`)

(MC Manager entry can be added wherever appropriate using `icon_sub_mcmanager.png` — confirm placement with the project owner.)

#### 2. Settings — main page + per-category pages

**Main page** (`Settings`):
- Header strip: `icon_sub_settings.png` (32×32) + title "Settings" (22 px / 700).
- Body: three rows, one per category. Each row is just the category name — **no hints, no chevrons, no descriptions, no icons.**
  - Storage
  - Display
  - Keyboard
- Selected row uses `bar_highlight.png` tiled to row width, with `arrow_pointer.png` (12×12) at left edge.
- Right-edge scrollbar: thin 2 px rail with `bar_top.png` (8 px wide × ~64 px tall) as the thumb.
- × on a row enters that category's page. ○ returns to the prior screen.

**Per-category page** (same header style, title becomes "Settings · <Category>"):

- **Storage**
  - `BDMA Mode:` value `Disabled (USB FAT32 driver)`, chevrons on both sides for value cycling.

- **Display**
  - `Video Mode:` value `NTSC (60Hz, 480i/240p)` (cyclable).
  - `Language:` value `English` (disabled — grey, chevrons use `*_no.png`).
  - `Theme:` value `Default` (disabled).
  - `Show Devices:` value `Custom` (cyclable).
  - Below "Show Devices", a sub-list (indented ~201 px from row start) of device checkboxes:
    - USB (disabled, off)
    - i.Link (disabled, off)
    - HDD BDM (disabled, off)
    - HDD APA (enabled, on)
    - MX4SIO (disabled, off)
    - MMCE (enabled, on)
    - SMB (disabled, off)
  - Checkbox state: `checkbox_empty.png` / `checkbox_full.png`.

- **Keyboard**
  - `Layout:` value `QWERTY` (cyclable).

Row geometry (all categories):
- Body padding: 6 px top / 8 px bottom / 24 px left / 32 px right.
- Row height 26 px, font 17 px / 700.
- Label column: 175 px wide; value column begins after that.
- Disabled rows: text + chevrons at ~42% opacity.
- Selected-row highlight + ▸ pointer same as the main page.

#### 3. Joypad configuration

- Header strip (44 px tall, 1 px bottom divider): `icon_sub_joypad.png` (28×28) + "Joypad Configuration" (20 px / 700).
- Below the header, draw `joypad.png` (640×432) at x=0, y=44. All leader-line labels are baked into the PNG — do not redraw text labels on top.

#### 4. On-screen keyboard

Layout container is 560 × 290 px, centered horizontally with 36 px top padding and 40 px side padding inside the stage.

- Title: "Edit POPStarter Path" (or whatever string the existing OSK uses), 20 px / 700, near-white, 14 px below header / 14 px above input.
- Input field: full-width, rgba(16,22,70,0.45) background, 1 px rgba(170,190,240,0.65) border, 9 px corner radius, 16 px medium-weight text in rgb(220,230,255), inner padding 6 px × 14 px, height 30 px.
- Keyboard bg: blit `osk_bg.png` scaled to 560 × 290.
- Overlay text labels at these centers (measured from the source 512 × 256 image, scale x by 1.09375, y by 1.1328125):
  - Letter rows (13 columns), x = 28 + 38·col, y = 49 / 79 / 112 / 142 (rows A–M / N–Z / .,:;_-+=!?#&% / /\\|()[]{}<>*$)
  - Bottom row (12 keys), x positions [37, 85, 123, 161, 199, 237, 275, 313, 351, 389, 427, 474], y = 175. Slot 0 is `osk_symbol_caps.png`, slots 1–10 are `0`–`9`, slot 11 is `osk_symbol_backspace.png`.
  - Tab labels CLEAR / SPACE / MODE centered at x = 77 / 256 / 435, y = 201 — use `osk_symbol_clear.png`, `osk_symbol_space.png`, `osk_symbol_mode.png` (the chamfered ribbon shape itself is part of `osk_bg.png`, do not redraw it).
- Selected key: blit `osk_highlight_1.png` (or whichever variant matches your size) centered over the key cell, **under** the letter label (z-order: highlight, then text, then cursor).
- Cursor: blit `osk_cursor.png` (~22×22) with its tip just inside the bottom-right of the selected cell.

---

### Workflow

1. Create branch `feat/gui-overhaul-berion-mockups`.
2. Read `ui.lua` end-to-end to locate the existing context-menu, settings, joypad-config, and OSK draw functions.
3. Implement each screen per the spec above. Keep diffs surgical — replace the body of each draw function, don't restructure the file.
4. Verify ELF still builds (whatever Makefile / build script the repo uses). Expect ~150 KiB binary growth from the new image assets.
5. Open a PR against `master` with the spec link, a short summary, and screenshots/captures from a PCSX2 run.

---

### Reference

A working HTML/JSX mockup of every screen above (rendered at native 640×480 with the exact assets in place) lives in this repo at `app/screens.jsx` + `app/styles.css`, presented through `index.html` via the design-canvas wrapper. Open that locally in a browser to confirm the visual target before/while writing the Lua port. Treat the mockup as the visual oracle — if your Lua output and the mockup disagree, the mockup is correct.

> ⚠️ **Note from 2026-05-24 archival:** the `app/` mockup files referenced in this paragraph are NOT currently committed to the repo. The PNG assets are present (commit `f8fec64`), but the HTML/JSX mockup wrapper from Berion's design package was not extracted into source. Future implementer: either commit the mockup files first or have a screenshot/hosted-mockup link as the visual oracle before writing Lua.
