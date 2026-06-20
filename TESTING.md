# POPSLoader — Tester Checklist (BETA-13 candidate)

**Build:** rolling `BETA-12-PLAY` (BETA-13 candidate) — 40 commits since BETA-12.
This is the structured "what to test" companion to **[ROLLING_NOTES.md](ROLLING_NOTES.md)** ("what's new"). Regenerate when the rolling batch changes.

**Devices:** USB · MX4SIO (SD over SIO2) · MMCE (SD2PSX / MemCard PRO) · HDD (internal PFS). Test the ones you use; **say which** in every report.

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

- [ ] **R3 = reveal / hide hidden games** ⭐ **BRAND NEW — never run on hardware. Test on each device:**
  1. Hide a couple of games with **L3**.
  2. *Settings → Game List → Hidden games → **Hidden*** (they vanish).
  3. On the device list press **R3** → list rebuilds, hidden games **reappear dimmed** + toast *"Showing hidden games (dimmed) — press L3 to unhide."*
  4. **L3** on a dimmed game → *"Game shown."*
  5. **R3** again → hidden games vanish + *"Hidden games are now hidden."*
  6. **Reboot** → the Hidden-games state persisted.
  - Report: empty/wrong list after R3, a crash, a device failing to re-scan, or the setting not sticking.
- [ ] **Left analog stick = fast page-jump** — push & hold the left stick up/down on a big list → flies a page at a time. (**L1** still jumps top ↔ bottom.)
- [ ] **Per-game info text** — drop `<game>.txt` next to a game → *Settings → Game details = Left/Center/Right* → blurb under the cover in that alignment, line breaks kept. *Off* hides it.
- [ ] **Description scroll** — long `.txt` scrolls with the **right analog stick**; *Settings → Description scroll speed = Fast/Medium/Slow* changes the pace.
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
- [ ] **Unsaved-changes prompt** — change a *cycle* setting (Game details / scroll speed / cache) and press **BACK** without saving → it warns you.
- [ ] **POPSTARTER MC Folder toggle + BDMA interlock** — toggle the `mc:/POPSTARTER` folder (off **deletes** it, with confirm). Can't disable the folder while BDMA is on, nor enable BDMA while the folder is off. *(BDMA mode now in `bdma_mode.txt`; legacy `.pldr_bdma_mode` still read.)*

## 🟦 P3 — Display / PAL (needs PAL hardware — we have none on the team)

- [ ] **Video Standard** — *Settings → Video*. **Auto** default should match your console's region. On **PAL** the UI should fill the screen **edge-to-edge at 640×512** (no letterbox). Report your console's **actual output** reading.
- [ ] **Display-change confirm/revert** — change the mode; if you don't confirm in time it **auto-reverts**.

## ⬜ P4 — Cosmetic / polish

- [ ] List a touch **wider**; device name (e.g. "USB") no longer overlaps the **top row**; disabled-cover box reads **"Cover disabled"** (centered); "Building…" overlay calmer.
- [ ] **Scroll position kept** returning from Settings (cursor doesn't snap to row 1).
- [ ] **Cover-art preview** toggles with **Square**.

## 🧪 P5 — Robustness (only if you hit it)

- [ ] **Corrupt / oversized cover** (PNG/JPEG/BMP) — must **not crash** the list (hardened this cycle).
- [ ] **Very long VCD filenames** — ~**73 chars** practical limit; longer may fail to launch.

## 📦 Release zip contents

- [ ] The rolling zip ships a **`POPSTARTER/`** folder (SMB `.irx` pack) and **`POPS/PATCH_5.BIN`** at the root — confirm they're present in your download.

---

## ℹ️ Known issues — expected, please don't re-report (unless your case differs)

- **"Failed to load HDD" when POPSLoader is launched from a non-HDD device** via a launcher (config-specific, seen by Nuno) — most setups list the HDD fine. **If you hit it, post your exact boot config**; it now shows the real reason on a second line. Workaround: boot from the HDD, or open the HDD page a few seconds after the menu.
- **PAL console still showing PAL when NTSC is selected** (#495) — known, being chased; the "actual output" reading helps.
- **DKWDRV exit back to memory card "hangs on the pic"** — known open follow-on.
