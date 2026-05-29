# POPSLoader GUI overhaul — Berion mockups

**Status:** queued work, not yet started. Recorded 2026-05-24.
**Scope:** four screens (Context menu, Settings, Joypad config, OSK).
**Out of scope:** boot/splash screen, game list screen.

## Repository state of referenced files (as of 2026-05-24)

The original prompt below referenced `app/screens.jsx`, `app/styles.css`, and an `index.html` mockup wrapper from Designer's package as the "visual oracle." **Those files are NOT the source of truth.** They are Designer's interpretation of Berion's design, and at least one spec they encode is wrong: Designer described Settings as "main page + per-category sub-pages," but Berion's actual mockup PNG shows Settings as a **single scrollable page** with section headers inline.

The **actual source of truth** is Berion's mockup PNG screenshots (Context menu, Settings, Joypad configuration, OSK) shared by the project owner on 2026-05-24. They should live in `docs/mockups/` once dropped on disk:

- `docs/mockups/context_menu.png`
- `docs/mockups/settings.png`
- `docs/mockups/joypad_config.png`
- `docs/mockups/osk.png`

> ⚠️ As of 2026-05-24, these mockup PNGs are not yet committed -- the project owner attached them inline in chat. Once dropped into `Documents/assets/` (or wherever convenient on disk), commit them under `docs/mockups/` and update this doc's image links.

The PNG asset list the spec cites is fully present under `bin/POPSLDR/IMG/` after commit `f8fec64`. The 33 production assets are:

`arrow_choose_left_active.png`, `arrow_choose_left_active_no.png`, `arrow_choose_right_active.png`, `arrow_choose_right_active_no.png`, `arrow_pointer.png`, `bar_highlight.png`, `bar_top.png`, `checkbox_empty.png`, `checkbox_full.png`, `icon_sub_about.png`, `icon_sub_exit.png`, `icon_sub_joypad.png`, `icon_sub_mcmanager.png`, `icon_sub_settings.png`, `icon_sub_settings_restore.png`, `icon_sub_settings_save.png`, `joypad.png`, `osk_bg.png`, `osk_cursor.png`, `osk_highlight_1.png`, `osk_highlight_2.png`, `osk_highlight_3.png`, `osk_highlight_4.png`, `osk_highlight_5.png`, `osk_symbol_backspace.png`, `osk_symbol_caps.png`, `osk_symbol_clear.png`, `osk_symbol_mode.png`, `osk_symbol_space.png`, `scroll_bg_bottom.png`, `scroll_bg_middle.png`, `scroll_bg_top.png`, `scroll_zip.png`.

## Prerequisites before starting (updated 2026-05-28)

- **D-10 / D-14 / D-15 are hardware-confirmed PASS** in BETA-10-5 (tag `9a0ebe2`, Nuno 2026-05-28). They are now preservation contracts, not active blockers. **Do not regress** these while doing the visual overhaul.
- **DKWDRV from MC and BOOT.ELF from USB-booted POPSLoader** are also hardware-confirmed PASS. Preserve.
- **DKWDRV from custom HDD path** and **U-10 BOOT.ELF from HDD-booted POPSLoader** are accepted known-broken in BETA-10-5 with documented workarounds. They are NOT blockers for the GUI overhaul.
- Do not regress any of the `S-*` / `U-*` rows in `QA_REGRESSION_MATRIX.md` while doing the visual overhaul.
- **Active blocker for starting this work**: Berion's mockup PNGs (`context_menu.png`, `settings.png`, `joypad_config.png`, `osk.png`) still need to land at `C:\Users\natha\Documents\assets\` and be committed to `docs/mockups/`. Without the visual oracle, the implementer can't match pixel-for-pixel.
- The current Settings page in `bin/POPSLDR/ui.lua` is the OPL-style focused-list. This overhaul replaces that with the category-page model below.

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
2. Settings — single scrollable page with inline section headers (see the 2026-05-24 correction below; do NOT implement per-category sub-pages)
3. Joypad configuration
4. On-screen keyboard (OSK)

---

### Constraints

- Match the mockups **pixel-for-pixel** where possible. The mockups are the source of truth, not your sense of "nicer."
- Render at the existing 640×480 native resolution.
- Do not add new dependencies. Use only what `ui.lua` already imports.
- Do not refactor unrelated code paths or rename existing globals. Add helpers locally next to where they're used.
- Keep the existing input model (D-pad navigation, ×/○/△/▢, L1/R1).
- Open a PR branch — **do not push to `BETA-12-PLAY`** (the canonical dev branch). Suggested branch name: `claude/gui-overhaul-berion-mockups`.

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

A vertically centered list, left-padded ~52 px. Rows are ~38 px tall with ~6 px gaps. Font weight 700 / ~22 px. The ~32×32 icon sits left of each label with ~16 px gap.

- **Selected row**: full white (icon + text both at full opacity).
- **Unselected rows**: dim grey -- match the opacity in Berion's mockup PNG (`docs/mockups/context_menu.png` once dropped). Treat the mockup as authoritative; the precise alpha is roughly in the 35-55% range but the eye-check against the PNG is the deciding factor.
- No bar highlight, no ▸ pointer, no value chevrons -- just the opacity contrast tells the user which row is focused.

Order, top to bottom:
1. Settings (`icon_sub_settings.png`)
2. Save Changes (`icon_sub_settings_save.png`)
3. Restore Default (`icon_sub_settings_restore.png`)
4. Joypad Configuration (`icon_sub_joypad.png`)
5. About (`icon_sub_about.png`)
6. Exit (`icon_sub_exit.png`)

(MC Manager entry can be added wherever appropriate using `icon_sub_mcmanager.png` — confirm placement with the project owner.)

#### 2. Settings — single scrollable page

> ⚠️ **2026-05-24 correction:** Designer originally specified Settings as "main page listing categories + per-category sub-pages." Berion's actual mockup PNG (`docs/mockups/settings.png` once dropped) shows a **single scrollable page** with all sections visible at once. The "Storage", "Display", and "Keyboard" labels are inline section headers within the same list, not separate pages. Discard the sub-page navigation model.

**One page**:
- Header strip (~44 px): `icon_sub_settings.png` (~24×24) at x≈18, "Settings" title (20 px / 700) at x≈52, 1 px bottom divider at rgba(170,190,240,0.25).
- Body: a single vertical list with section-header rows and setting-rows interleaved.
- Section-header rows: bold section name flush-left at the label column (no icon, no chevron, no bar highlight). Acts as a visual divider.
- Setting rows below each header.
- Right-edge scrollbar: thin ~2 px rail with `bar_top.png` (8 px wide × ~64 px tall) as the thumb. Scrollbar shows when content exceeds viewport.
- Selected setting-row uses `bar_highlight.png` tiled across the row width, with `arrow_pointer.png` (~12×12) at the left edge (left of the label).
- × on a value-row triggers the editor for that field (path editor, cycle, etc.); ← / → also cycle on cycle-rows. ○ returns to the prior screen.

**Section + row content (top to bottom)**:

- **Section: Storage**
  - `BDMA Mode:` value `Disabled (USB FAT32 driver)` -- chevrons on both sides for cycling.

- **Section: Display**
  - `Video Mode:` value `NTSC (60Hz, 480i/240p)` (cyclable).
  - `Language:` value `English` (disabled / grey, chevrons use `arrow_choose_{left,right}_active_no.png`).
  - `Theme:` value `Default` (disabled).
  - `Show Devices:` value `Custom` (cyclable).
  - Below "Show Devices", an **indented checkbox sub-list** (label column shifted right ~140 px from the parent label, no label-column reserve, no value column):
    - USB (disabled, off)
    - i.Link (disabled, off)
    - HDD BDM (disabled, off)
    - HDD APA (enabled, on)
    - MX4SIO (disabled, off)
    - MMCE (enabled, on)
    - SMB (disabled, off)
  - Checkbox state: `checkbox_empty.png` / `checkbox_full.png`. Disabled checkboxes render at ~42% opacity.

- **Section: Keyboard**
  - `Layout:` value `QWERTY` (cyclable).

**Row geometry (uniform for the whole list)**:
- Body padding: 6 px top / 8 px bottom / 24 px left / 32 px right (so the scrollbar rail can sit at ~x=628).
- Setting-row height ≈26 px, font 17 px / 700.
- Section-header rows are taller (~36 px) to give visual breathing room. Section text color is the dim variant (rgba(140,200,255,0.55) or similar) -- they read as labels, not as selectable rows.
- Label column starts at x≈64 (after the ▸-pointer reserve), ~175 px wide; value column begins at x≈260 with chevrons flanking the value.
- Disabled rows: text + chevrons at ~42% opacity.
- Selected-row visual: full-width `bar_highlight.png` + ▸ pointer.

**Focus behavior**:
- D-pad Up/Down moves focus between setting-rows AND checkbox-rows. Section headers and any spacer rows are skipped.
- D-pad Left/Right cycles the focused row's value (no-op for checkbox rows -- × toggles those).
- × activates the focused row (cycles a value, toggles a checkbox, opens a path editor).
- ○ exits Settings.

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
5. Open a PR against `BETA-12-PLAY` (the canonical dev branch) with the spec link, a short summary, and screenshots/captures from a PCSX2 run.

---

### Reference

**Visual oracle:** Berion's PNG mockup screenshots at `docs/mockups/{context_menu,settings,joypad_config,osk}.png`. If your Lua output and the mockup PNG disagree, the mockup PNG is correct.

Do NOT use Designer's `app/screens.jsx` / `app/styles.css` / `index.html` (from their assets.zip) as the visual oracle. Designer's interpretation of Berion's design got at least one major spec wrong (Settings sub-pages vs single page) and the project owner has explicitly flagged it as unreliable. The PNGs are the only authoritative reference for this overhaul.

If the mockup PNGs are missing under `docs/mockups/`, stop and ask the project owner to commit them before starting the Lua port.
