# POPSLoader — Tester Checklist (BETA-13 candidate)

**Build:** rolling `BETA-13-PLAY` (BETA-13 candidate; rolling now publishes from this branch — `BETA-12-PLAY` is frozen/archival). Public release is still BETA-12.
This is the structured "what to test" companion to **[ROLLING_NOTES.md](ROLLING_NOTES.md)** ("what's new"); for the canonical status / invariants / known-issues list see **[STATE.md](STATE.md)**. Regenerate when the rolling batch changes. _(Last refreshed: 2026-06-22 — added the new HDD (exFAT) / BDMA-ATA backend and the on-screen-keyboard feedback fix.)_

**Devices:** USB · MX4SIO (SD over SIO2) · MMCE (SD2PSX / MemCard PRO) · HDD (internal PFS) · **HDD (exFAT) — NEW, BDMA Mode ATA**. Test the ones you use; **say which** in every report.

**How to report:** ✅ pass / ❌ fail / ⚠️ odd. On a fail give: **device**, **console model + region** (e.g. SCPH-90008 PAL), **how you launched POPSLoader** (from which device / which launcher), **exact steps**, and a **photo** — error screens now print the real reason on line 2.

---

## 🟥 P0 — Must work on every device (boot · launch · no regressions)

- [ ] **Boot to menu** — launch from each device. The welcome **splash appears instantly** (no black screen first), **centered from frame one**, then the carousel. Report any black screen, off-center/letterboxed splash, wrong region/res that flips mid-fade, or hang.
- [ ] **Normal PS1 launch** — select a game on each device → **X** → POPStarter boots it.
- [ ] **MX4SIO specifically** — confirm it still loads + launches. *(A −48 KB optimization re-pointed MX4SIO's embedded `usbd.irx`; proven byte-identical by inspection but not run on hardware — the one size change worth a deliberate test.)*
- [ ] **Preservation set — MUST still work:**
  - [ ] **HDD-resident POPSTARTER → HDD game (D-10):** on an HDD install where `POPSTARTER.ELF` lives on the HDD, launch an HDD game. No black screen.
  - [ ] **Launched-from-MC/USB (U-10 family):** boot POPSLoader from a memory card / USB via a launcher (OSD-XMB, wLaunchELF), then open the HDD page and launch.
  - [ ] **DKWDRV / Disc → exit to memory card:** no hang on the picture.
- [ ] **START-held recovery** — hold **START** during boot → boots to a safe state; with `-page`/`-game` args it suppresses auto-launch so you can recover.

## 🟧 P1 — New features this cycle

### ⭐⭐ HDD (exFAT) via BDMA ATA — BRAND-NEW backend, NEVER run on hardware

The flagship new feature this cycle (R3Z3N's ATA BDM Assault drivers + saildot4k's backend work): play from an **exFAT-formatted internal SATA/IDE drive**, exactly like a big USB stick. **If you have an exFAT internal drive, this is the single most valuable thing you can test.** CI-green, but zero hardware runs so far.

**Setup:**
1. Format the internal drive **exFAT** (NOT the classic APA/PFS HDL layout — that's the separate "HDD (PFS)" entry).
2. Put a **`POPS/`** folder at the drive root with your `.VCD` files (+ your own `POPS_IOX.PAK`, `POPSTARTER.ELF`) — same layout as a USB stick.
3. *Settings → BDMA Mode → **ATA*** and save. *(On apply, the `.ata` launch drivers are copied — with the `.ata` suffix stripped — to `mc?:/POPSTARTER/`.)*

**Test:**
- [ ] Open the **HDD (exFAT)** carousel entry → it scans `mass:/POPS` and **lists your games**.
- [ ] Select a game → **X** → it **launches** through POPStarter (same as USB/MX4SIO).
- [ ] ⚠️ **Classification:** the exFAT drive must list/launch **only** under HDD (exFAT) — confirm it does **NOT** also appear under **USB** or **MX4SIO**, and that USB/MX4SIO still work normally. *(ATA is matched by exact ioctl driver-name `ata`, so it shouldn't leak — but this is exactly what hardware needs to confirm.)*
- [ ] No exFAT drive present / BDMA Mode ≠ ATA → the page shows **"No exFAT HDD detected"** and does **not** hang.
- Report: empty list, a game that lists but won't launch, the drive showing under the wrong device, or a hang — include **console model** and **drive type/size**.

### Navigation & input — ✅ core nav CONFIRMED on hardware (oldman63); the rest still to feel out

- [x] **Up/Down + analog-stick item nav** — ✅ **CONFIRMED (oldman63):** d-pad and **left analog stick up/down** both land on **individual items** (item-by-item), and a held direction does smooth continuous scroll. *(The stick now folds into the d-pad and runs the same edge + auto-repeat path — no more "flies a whole page" / "can't select individual items" #501. A non-analog/digital pad is gated out so it can't inject a phantom direction; the auto-repeat is frame-counted, ~0.6 s before the first repeat then ~5/sec.)* Re-confirm on **each device's** list if you can.
- [ ] **Page-jump & top/bottom** — on a big list: **LEFT / RIGHT** (d-pad **or** left stick left/right) jumps a **page** at a time; **L1** ping-pongs **top ↔ bottom**. Confirm these still work after the nav rework.
- [ ] **R3 = reveal / hide hidden games** ⭐ **STILL never run on hardware. Test on each device** (HDD / USB / MX4SIO / MMCE — R3 is ignored elsewhere):
  1. Hide a couple of games with **L3** (with *Hidden games* set to **Visible (manage)**).
  2. *Settings → Game List → Hidden games → **Hidden*** (they vanish). *(R3 toggles this same setting in place, so you can also just press R3.)*
  3. On the device list press **R3** → list rebuilds, hidden games **reappear dimmed** + toast *"Showing hidden games (dimmed) -- press L3 to unhide"*.
  4. **L3** on a dimmed game → *"Game shown"*. *(L3 is blocked while Hidden mode is ON — reveal with R3 first; otherwise it warns "[Global Hide ON] …".)*
  5. **R3** again → hidden games vanish + *"Hidden games are now hidden"*.
  6. **Reboot** → the Hidden-games state persisted. *(A failed save toasts "(could NOT save -- reverts on reboot)".)*
  - Report: empty/wrong list after R3, a crash, a device failing to re-scan, or the setting not sticking.
- [ ] **Boot sound On/Off** — *Settings → Game List → Boot sound* (default **On**) gates the splash chime. ✅ **save survives reboot CONFIRMED (oldman63);** still confirm Off actually silences the chime.
- [ ] **Per-game info text** — drop `<game>.txt` next to a game → *Settings → Game List → Game details = Left/Center/Right aligned* → blurb under the cover in that alignment, line breaks kept. *Off* hides it.
- [ ] **Description scroll** — long `.txt` scrolls with the **right analog stick**; *Settings → Game List → Description scroll speed = Fast/Medium/Slow* now actually changes the pace (default **Slow**, ~1 line/sec; the speed setting was previously ignored). Confirm Fast/Medium/Slow feel distinct.
- [ ] **Game list cache (opt-in, default OFF)** — *Settings → Game list cache → ON:*
  - [ ] First entry builds; second entry / reboot **loads fast** (no "Building…").
  - [ ] ⚠️ **CRITICAL: launch a game FROM the cached list** on each device incl. **HDD** — it must still **launch correctly**, not just load fast.
  - [ ] **R1** forces a rebuild.
  - [ ] Toggle a list-affecting setting (Multi-disc / Hidden games) → cache **rebuilds**, doesn't serve a stale list.
- [ ] **Boot Page** — *Settings → Startup* → pick a device → after boot it lands **straight in that device's list** (or Carousel default).
- [ ] **Carousel Devices visibility** — *Settings → Carousel Devices* → hide e.g. SMB / i.Link → they leave the wheel with **no gaps**, ≥1 stays, launching the others unchanged.
- [ ] **Multi-disc collapse** — *Settings → Game List*, files named `Game (Disc 1).VCD` / `Game (Disc 2).VCD` → only **Disc 1** shows; swap discs in-game via VMC.

## 🟨 P2 — Hide / settings persistence

- [ ] **L3 hide/unhide** on every device incl. **HDD** (drops `.hide` next to the VCD; on HDD writes to the boot partition — old "add it from a PC" is now only a write-failure fallback).
- [ ] **Hidden games filter** — *Hidden* filters out; *Visible (manage)* shows dimmed so L3 can toggle them back.
- [ ] **Settings save & persist** — change a setting, **reboot**, confirm it stuck. **Especially HDD installs** (settings save to the HDD boot partition now — RW confirmed by provato, full flow wants more confirmation).
- [ ] **Unsaved-changes prompt** — change a *cycle* setting (Game details / scroll speed / cache / Boot sound / Overscan / Boot Page) and press **BACK** without saving → it warns you.
- [ ] **POPSTARTER MC Folder toggle + BDMA interlock** — toggle the `mc:/POPSTARTER` folder (off **deletes** it, with confirm). Can't disable the folder while BDMA is on, nor enable BDMA while the folder is off. *(BDMA mode now in `bdma_mode.txt`; legacy `.pldr_bdma_mode` still read.)*

## 🟦 P3 — Display / PAL (needs PAL hardware — we have none on the team)

- [ ] **Video Standard** — *Settings → Display*. **Auto** default should match your console's region. On **PAL** the UI should fill the screen **edge-to-edge at 640×512** (no letterbox). Report your console's **actual output** reading.
- [ ] **Display-change confirm/revert** — change the mode; if you don't confirm in time it **auto-reverts**.
- [ ] **Overscan (CRT inset)** ⭐ **NEW — needs a CRT eyeball, not yet verified.** *Settings → Game List → Overscan (CRT inset)* (default **Off**; **LEFT/RIGHT steps ±5**, live preview). Raise it on a CRT that crops the edges → the whole UI should shrink **uniformly toward center** (OPL-style render inset). Discarding the settings change restores the previous value. Report the value that just clears your bezel.

## ⬜ P4 — Cosmetic / polish

- [ ] List a touch **wider**; device name (e.g. "USB") no longer overlaps the **top row**; "Building…" overlay calmer.
- [ ] **Cover placeholder art** ⭐ **NEW assets, needs an eyeball on NTSC + PAL.** No live cover now draws a layered jewel-case placeholder (`cover_default.png`), with a `cover_missing.png` overlay **only** when the preview is **ON** but the game has no cover. *(The old "Cover disabled" **text** label is gone.)* Confirm the default cover, the missing overlay, and `frame.png` all **register** with the jewel-case window (right-anchored, no drift) on both NTSC and PAL.
- [ ] **Cover-art preview** toggles with **Square** — OFF shows the plain default case (no overlay), ON shows the live cover or the missing-overlay placeholder.
- [ ] **Scroll position kept** returning from Settings (cursor doesn't snap to row 1).
- [ ] **On-screen keyboard feedback** (editing a POPSTARTER / DKWDRV path) — pressing a key now **flashes it** briefly, and the text caret **blinks** at a normal rate. *(Both were broken by a microsecond-vs-millisecond timer bug — the flash expired before the next frame so it never showed, and the caret blinked ~1000× too fast; purely cosmetic, no input behavior change.)*

## 🧪 P5 — Robustness (only if you hit it)

- [ ] **Corrupt / oversized cover** (PNG/JPEG/BMP) — must **not crash** the list (hardened this cycle).
- [ ] **Very long VCD filenames** — ~**73 chars** practical limit; longer may fail to launch.

## 📦 Release zip contents

- [ ] The rolling zip ships, at the **root**: a **`POPSTARTER/`** folder (SMB `.irx` pack), **`POPS/PATCH_5.BIN`**, **`POPSTARTER.ELF`** (also copied into **`POPS/`**) — confirm they're present in your download. *(POPS engine binaries are not redistributable and are NOT included; you still supply your own.)*

---

## ℹ️ Known issues — expected, please don't re-report (unless your case differs)

- **"Failed to load HDD" when POPSLoader is launched from a non-HDD device** via a launcher (config-specific, seen by Nuno) — most setups list the HDD fine. **If you hit it, post your exact boot config**; it now shows the real reason on a second line. Workaround: boot from the HDD, or open the HDD page a few seconds after the menu.
- **PAL console still showing PAL when NTSC is selected** (#495) — known, being chased; the "actual output" reading helps.
- **DKWDRV exit back to memory card "hangs on the pic"** — known open follow-on.
