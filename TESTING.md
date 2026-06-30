# POPSLoader — Tester Checklist (BETA-13 candidate)

**Build:** rolling `BETA-13-PLAY` (BETA-13 candidate; rolling now publishes from this branch — `BETA-12-PLAY` is frozen/archival). Public release is still BETA-12.
This is the structured "what to test" companion to **[ROLLING_NOTES.md](ROLLING_NOTES.md)** ("what's new"); for the canonical status / invariants / known-issues list see **[STATE.md](STATE.md)**. Regenerate when the rolling batch changes. _(Last refreshed: 2026-06-29 — added **per-device POPSTARTER.ELF resolution** (per-device builds incl. the USB-delay build; APA `hdd0:__common/POPS/`), the **normal-HDD-still-works** check after the shared-ATA-driver unification, and the **`POPS/ART/`** cover/details folder. Prior: end-to-end SMB (v1) network browsing; HDD (exFAT) / BDMA-ATA backend; on-screen-keyboard feedback fix.)_

**Devices:** USB · MX4SIO (SD over SIO2) · MMCE (SD2PSX / MemCard PRO) · HDD (internal PFS) · **HDD (exFAT) — BDMA Mode ATA** · **SMB (v1) network share — NEW**. Test the ones you use; **say which** in every report.

**How to report:** ✅ pass / ❌ fail / ⚠️ odd. On a fail give: **device**, **console model + region** (e.g. SCPH-90008 PAL), **how you launched POPSLoader** (from which device / which launcher), **exact steps**, and a **photo** — error screens now print the real reason on line 2.

---

## 🟥 P0 — Must work on every device (boot · launch · no regressions)

- [ ] **Boot to menu** — launch from each device. The welcome **splash appears instantly** (no black screen first), **centered from frame one**, then the carousel. Report any black screen, off-center/letterboxed splash, wrong region/res that flips mid-fade, or hang.
- [ ] **Normal PS1 launch** — select a game on each device → **X** → POPStarter boots it.
- [ ] **MX4SIO specifically** — confirm it still loads + launches. *(A −48 KB optimization re-pointed MX4SIO's embedded `usbd.irx`; proven byte-identical by inspection but not run on hardware — the one size change worth a deliberate test.)*
- [ ] **Preservation set — MUST still work:**
  - [ ] **HDD-resident POPSTARTER → HDD game (D-10):** on an HDD install where `POPSTARTER.ELF` lives on the HDD, launch an HDD game. No black screen.
  - [ ] ⭐⭐ **Normal internal HDD (PFS) still fully works** — boot from a normal internal PS2 hard drive → reach the menu, your **settings load and save**, and you can **scan + launch** a PS1 game from the **HDD (PFS)** list with no black screen. *(A behind-the-scenes change unified the internal-HDD and exFAT paths onto one shared ATA driver. Source analysis says normal HDD is unaffected — it's the same config OPL/NHDDL ship — but this is the single confirmation that closes it out. If a normal HDD game ever fails to launch or settings stop saving, say so.)*
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
- [ ] **Launch-arg routing (NEW — never HW-run):** booting with `-page=ata` (or `ata0`) opens the **HDD (exFAT)** page; `-page=hdd` / `hdd0` / `apa` / `apa0` / any `pfs` open the classic **HDD (PFS)** page. (`-page=ata -game=<VCD>` should auto-launch from the exFAT drive.) Confirm `-page=ata` no longer lands on the PFS page.
- Report: empty list, a game that lists but won't launch, the drive showing under the wrong device, or a hang — include **console model** and **drive type/size**.

### ⭐⭐ Per-device POPSTARTER.ELF — NEW, never run on hardware

POPSLoader now picks the `POPSTARTER.ELF` for a launch **per device**, so you can keep a different POPStarter build on each device. At launch the search order is: **(1)** an explicit **POPSTARTER Path** you set in *Settings* (or an absolute Profile pick) if it resolves → **(2)** the game's own **`<device>:/POPS/POPSTARTER.ELF`** if present → **(3)** the `POPSTARTER.ELF` next to where **POPSLOADER.ELF** launched from → **(4)** the `mc0:`/`mc1:/POPSTARTER` fallback. On the internal **PFS HDD**, step 2 is **`hdd0:__common/POPS/POPSTARTER.ELF`**. The device + cwd steps are existence-gated, so a device with no copy just falls through — **per-device builds are enabled, not forced.** The release ships multiple POPStarter builds for exactly this (a normal one, a **USB-delay** one, and debug variants — the "POPSTARTER VERSIONS" in the zip).

**Test (each removable device — USB / exFAT / MX4SIO / MMCE):**
- [ ] ⭐ **Per-device build pickup (the headline use):** drop a specific `POPSTARTER.ELF` build — e.g. the **USB-delay** build — into the **USB** drive's `POPS/` folder. Launch a USB game (ideally one that *only* runs with the USB-delay build) → it should now use **that** build and launch. Other devices keep using their own / the fallback build.
- [ ] **Existing setups unchanged:** a device with **no** `POPSTARTER.ELF` in its `POPS/` folder still launches games exactly as before (it falls through to the launcher's own copy / the Memory Card).
- [ ] **Custom path always wins:** set an explicit **POPSTARTER Path** in *Settings* (an absolute path) → that build is used on **every** device regardless of any per-device copies. Clearing it returns to the per-device order.
- Report: a per-device build that **isn't** picked up, an existing setup that **stopped** launching, or the wrong build being used.

**Test (internal PFS HDD — launch-critical, please be thorough):**
- [ ] ⭐⭐ **HDD game launches via `__common`:** on a PSBBN / HDD-OSD internal drive where the POPStarter binaries live at **`hdd0:__common/POPS/`**, launch a PS1 game from the **HDD (PFS)** list → it boots POPStarter with **no black screen**. *(The new `hdd0:__common/POPS/POPSTARTER.ELF` step routes through the same internal-HDD machinery as before, but it has not been run on hardware — this is the most regression-prone path.)*
- Report: a black screen, a "can't find POPSTARTER" message, or any hang launching an internal-HDD game.

### ⭐ Settings — collapsible sections (NEW, never run on hardware)

The Settings page already scrolls (focus-following viewport + scrollbar). New this build: each **section header** (Storage / Display / Startup / Carousel Devices / Game List / POPSTARTER / Memory Card) can **collapse/expand** so long groups (e.g. the per-device "Carousel Devices" checklist) fold away.
- [ ] Move the cursor onto a **section header** (it highlights; shows `-` when expanded, `+` when collapsed). Press **X** to toggle; **Left** collapses, **Right** expands.
- [ ] Collapsing a section hides its rows and the list gets shorter (less scrolling); expanding brings them back. The cursor stays on the header.
- [ ] ⚠️ **Save / Reset Defaults / Discard & Exit must ALWAYS stay reachable** regardless of which sections are collapsed — confirm you can still reach them after collapsing every section.
- [ ] Every existing setting still saves/persists exactly as before (collapse state is session-only — it resets on reboot, nothing new is written to your settings file).
- Report: a section that won't expand back, the actions becoming unreachable, the cursor getting stuck, or any setting failing to save.

### ⭐⭐ SMB (v1) network game browsing — NEW end-to-end, never run on hardware

SMB (v1) is now **implemented end-to-end** (CI + Rolling green) and **validating on hardware** — so far it has **zero hardware runs**. You set your server/share/credentials in a new **SMB / Network** Settings section, **install the in-game SMB streaming pack into `mc0:/POPSTARTER/`** (the same way BDMA installs its modules), then **browse and launch** PS1 games straight off a network share from the **SMB** carousel page. Networking is **lazy**: the stack comes up and the share opens **only** when you enter the SMB page or trigger a settings action — **nothing SMB runs at boot**. **NetBIOS is not supported** (the address type must be **IP**); the in-game pack is what POPStarter uses to stream the game off the share at launch.

**Setup:**
1. *Settings* → expand **SMB / Network** → set **Server IP**, **Share**, **User/Password**, **IP assignment** (DHCP/Static), **Port** (445), **Games path**, **Link mode**. Address type stays **IP**.
2. Set **SMB modules → Installed** and **Save** (this writes the pack + `SMBCONFIG.DAT`/`IPCONFIG.DAT` — see the install checks below).

**Settings + module install:**
- [ ] *Settings* → expand **SMB / Network**. Top row **SMB modules** (Installed / Not installed); below: **IP assignment** (DHCP/Static), **PS2 IP / Netmask / Gateway / DNS**, **Link mode**, **Address type**, **NetBIOS name**, **Server IP**, **Port** (445), **Share**, **User**, **Password**, **Games path**.
- [ ] **Cycle** rows change with **Left/Right** / **X**; **text** rows open the on-screen keyboard on **X**. Password masks (`****`); empty **Games path** shows *"(auto / cwd-relative)"*; empty Share/User show *"(not set)"*.
- [ ] Edit fields → **unsaved (accent) marker** → **Save Changes** → **reboot** → values **persisted** exactly as entered.
- [ ] ⭐ **SMB modules = Installed → Save:** `mc0:/POPSTARTER/` should now hold `poweroff.irx`, `ps2dev9.irx`, `ps2ip.irx`, `ps2smap.irx`, `smbman.irx`, `SMSUTILS.irx`, plus `SMBCONFIG.DAT` and (only when **IP assignment = Static**) `IPCONFIG.DAT`. Open `SMBCONFIG.DAT`: line 1 = `<Server>[:<Port>] <Share>`, then (if User set) username + password on lines 2/3. `IPCONFIG.DAT` = `<PS2 IP> <Netmask> <Gateway>`, and is **absent on DHCP**.
- [ ] ⭐ **Change an SMB field while Installed → Save:** the in-game `SMBCONFIG.DAT`/`IPCONFIG.DAT` are **backfilled on every save** — generated if missing, **regenerated** with the new values when changed (the 6 IRX are rewritten harmlessly).
- [ ] ⭐⚠️ **SMB modules = Not installed → Save:** the 8 SMB files are **removed**, but **`icon.sys`, `*.icn`, and any installed BDMA modules (`usbd.irx`/`usbhdfsd.irx`) MUST remain** — confirm BDMA still works afterward.
- [ ] **Reset Defaults** sets SMB modules → Not installed + fields to defaults (Save then uninstalls, mirroring BDMA→FAT32).
- [ ] ⚠️ **No regression:** every *other* setting still saves/loads as before, and **boot time is unchanged**.
- Report: a field that won't persist, the wrong files installed/removed, **BDMA modules or icons clobbered by SMB-off**, or any boot slowdown.

**Connect / browse / launch / disconnect (the new end-to-end path — never HW-run):**
- [ ] ⭐ **Lazy connect — confirm boot is untouched first:** boot straight to the menu and **stay off** the SMB page → **no** network activity, no slowdown, no errors. Networking must come up **only** on entering the SMB page (or a settings action), **never** at boot.
- [ ] ⭐ **Browse:** open the **SMB** carousel entry → it brings up the stack, opens the share, **scans `POPS/` and lists your VCD games** like any other device. Report a hang, an empty list with games present, or a connect error.
- [ ] ⭐ **Launch:** select an SMB game → **X** → it hands off to POPStarter (argv0 selector `smb:/POPS/SB.<name>.ELF`) and **POPStarter streams the VCD from its own `smb:/POPS` mount** (via `mc:/POPSTARTER/SMBCONFIG.DAT`). *(Hardware-only unknown: the exact device prefix POPStarter accepts — we ship `smb:/POPS/SB.<name>.ELF`, with `mass:/POPS/SB.<name>.ELF` then `mass:/SB.<name>.ELF` as fallbacks. If a game lists but won't launch, note the exact behaviour.)*
- [ ] ⭐ **Disconnect on exit:** leave the SMB page → the share is closed and the session logged off (`CLOSESHARE` + `LOGOFF`); a **failed** connect also tears down cleanly with **no half-open session** left behind. Re-entering the page should reconnect fresh.
- [ ] ⭐ **Blank-share picker:** clear the **Share** field, then enter the SMB page → it enumerates the server's shares (`GETSHARELIST`) and an in-UI **picker** lets you choose one; your choice **persists** (settings + the in-game `SMBCONFIG.DAT`) and it reconnects. Report a picker that lists nothing, a choice that doesn't stick, or a reconnect that fails.
- The `.DAT` byte format is from the recovered POPStarter docs and is **hardware-confirmable only** (report if POPStarter rejects a generated `SMBCONFIG.DAT`). Other hardware-only unknowns: the connect handshake and the `GETSHARELIST` DMA.

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
- [ ] ⭐ **Covers & details from `POPS/ART/`** (NEW layout) — covers and the `<game>.txt` details file are now looked up in a **`POPS/ART/`** subfolder **first** on every device (`<device>:/POPS/ART/<game>.png` and `.txt`; internal HDD: `__common/POPS/ART/`), and still found **beside the `.VCD`** for older art. Confirm a cover placed in `POPS/ART/` shows up, and one beside the `.VCD` still works. For a **multi-disc** game, one file named **without** the `(Disc N)` part covers/describes every disc.
- [ ] **Per-game info text** — add a `<game>.txt` (in `POPS/ART/` or beside the game) → *Settings → Game List → Game details = Left/Center/Right aligned* → blurb under the cover in that alignment, line breaks kept. *Off* hides it.
- [ ] **Description scroll** — long `.txt` scrolls with the **right analog stick** at a fixed **Fast** pace (~7 lines/sec, frame-counted). The Fast/Medium/Slow speed setting was removed (provato: Fast is best). Confirm the scroll feels right.
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
- [ ] **Unsaved-changes prompt** — change a *cycle* setting (Game details / cache / Boot sound / Overscan / Boot Page) and press **BACK** without saving → it warns you.
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
- [ ] **DualShock 4 over Bluetooth** (only if you use one) — lightbar colour + rumble still behave after a code fix that stopped the BT output report carrying ~29 bytes of uninitialized data. Confirm the DS4 still pairs, the lightbar sets, and rumble works.

## 📦 Release zip contents

- [ ] The rolling zip ships, at the **root**: a **`POPSTARTER/`** folder (SMB `.irx` pack), **`POPS/PATCH_5.BIN`**, **`POPSTARTER.ELF`** (also copied into **`POPS/`**) — confirm they're present in your download. *(POPS engine binaries are not redistributable and are NOT included; you still supply your own.)*

---

## ℹ️ Known issues — expected, please don't re-report (unless your case differs)

- **"Failed to load HDD" when POPSLoader is launched from a non-HDD device** via a launcher (config-specific, seen by Nuno) — most setups list the HDD fine. **If you hit it, post your exact boot config**; it now shows the real reason on a second line. Workaround: boot from the HDD, or open the HDD page a few seconds after the menu.
- **PAL console still showing PAL when NTSC is selected** (#495) — known, being chased; the "actual output" reading helps.
- **DKWDRV exit back to memory card "hangs on the pic"** — known open follow-on.
