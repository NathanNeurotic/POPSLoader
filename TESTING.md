# POPSLoader — Tester Checklist (rolling `dev`)

**Build:** the rolling build published from `dev` (its version row reads **v1.1.1-dev**). Public release is **1.1.0** (2026-07-21).
This is the structured "what to test" companion to **[ROLLING_NOTES.md](ROLLING_NOTES.md)** ("what's new"); for the canonical status / invariants / known-issues list see **[STATE.md](STATE.md)**. Regenerate when the rolling batch changes. _(Last refreshed: 2026-07-27 — added the game-details `.txt` fix, the translation reachability sweep, and the launch-after-browsing regression watch. Prior: settings-review round 2; per-device POPSTARTER.ELF resolution; normal-HDD-still-works; SMB (v1); HDD (exFAT).)_

**Devices:** USB · MX4SIO (SD over SIO2) · MMCE (SD2PSX / MemCard PRO) · HDD (internal PFS) · **HDD (exFAT) — BDMA Mode ATA** · **SMB (v1) network share — NEW**. Test the ones you use; **say which** in every report.

**How to report:** ✅ pass / ❌ fail / ⚠️ odd. On a fail give: **device**, **console model + region** (e.g. SCPH-90008 PAL), **how you launched POPSLoader** (from which device / which launcher), **exact steps**, and a **photo** — error screens now print the real reason on line 2.

---

## 🟥 P0 — Must work on every device (boot · launch · no regressions)

- [ ] **Boot to menu** — launch from each device. The welcome **splash appears instantly** (no black screen first), **centered from frame one**, then the carousel. Report any black screen, off-center/letterboxed splash, wrong region/res that flips mid-fade, or hang.
- [ ] **Normal PS1 launch** — select a game on each device → **X** → POPStarter boots it.
- [ ] **MX4SIO specifically** — confirm it still loads + launches. *(MX4SIO scanning and launching was hardware-confirmed on 2026-07-20, but the whole device layer was rebuilt after that, so it stays on the must-work list.)*
- [ ] **Preservation set — MUST still work:**
  - [ ] **HDD-resident POPSTARTER → HDD game (D-10):** on an HDD install where `POPSTARTER.ELF` lives on the HDD, launch an HDD game. No black screen.
  - [ ] ⭐⭐ **Normal internal HDD (PFS) still fully works** — boot from a normal internal PS2 hard drive → reach the menu, your **settings load and save**, and you can **scan + launch** a PS1 game from the **HDD (PFS)** list with no black screen. *(A behind-the-scenes change unified the internal-HDD and exFAT paths onto one shared ATA driver. Source analysis says normal HDD is unaffected — it's the same config OPL/NHDDL ship — but this is the single confirmation that closes it out. If a normal HDD game ever fails to launch or settings stop saving, say so.)*
  - [ ] **Launched-from-MC/USB (U-10 family):** boot POPSLoader from a memory card / USB via a launcher (OSD-XMB, wLaunchELF), then open the HDD page and launch.
  - [x] ~~**DKWDRV / Disc → exit to memory card:** no hang on the picture.~~ *(Closed 2026-07-23: the exit hang is DKWDRV-side, not POPSLoader — not ours to fix.)*
- [ ] **START-held recovery** — hold **START** during boot → boots to a safe state; with `-page`/`-game` args it suppresses auto-launch so you can recover.

## 🟧 P1 — New features this cycle

### ⭐⭐ Translations — messages that were stuck in English (NEW, never run on hardware)

A batch of on-screen messages was being assembled in a way that threw the translation away before it was looked up. Those now go through the translator, and Hungarian gained a fresh round of strings.
- [ ] Set *Settings → Startup → Language* to a non-English language and use the launcher normally. Report any row, toast or error screen still showing English when the rest of the page is translated, and any label that runs off the edge of a row.
- [ ] **Hungarian specifically:** on the HDD page, the "no games found" and "list refreshed" toasts should now appear in Hungarian, and the LAUNCH FAILED screen (including the "press this button" line under it) should be translated and name the right button for your console.
- [ ] A translation with a missing placeholder must fall back to English, never break the message. If any toast shows a raw `%s`, or a message vanishes where you expected one, report the language and the exact screen.

### ⭐⭐ Launching after browsing a list (regression watch, never run on hardware)

The cover loader was reworked, and it is emptied out before every handoff to another program.
- [ ] On **each** device you use, browse a game list for a while, then launch a game. **MX4SIO and USB matter most**, they are the ones with big `ART/` folders. It must still launch, with no hang on a "Loading ART..." message.
- [ ] Same check for **Exit → BOOT.ELF** and for **Disc (DKWDRV)** after you have browsed a list first.

### ⭐ Settings save on an HDD-loaded rig
- [ ] With the HDD game list loaded, change a setting and save it, then reboot and confirm it stuck. If you get a read-only or write-test message, report its exact wording.

### ⭐ Menu and Settings cleanup (NEW, never run on hardware)

Mostly a "does anything feel missing?" pass. Nothing was removed from what the launcher can DO, only from what it advertises.

- [ ] **Main menu button bar** reads exactly *Select / Settings / Exit*. Credits is gone from it.
- [ ] **Game list button bar** reads exactly *Launch / Back*. Settings and Credits are gone from the bar but still WORK: **START** still opens Settings. Confirm that. Note **Square no longer toggles cover art at all** — that moved to a saved setting, *Settings → Game List → Cover art* (default **On**). Square doing nothing on a game list is correct, not a bug.
- [ ] **Credits now lives in Settings** (*Settings, About, Credits*). Open it, then back out: you should land back on Settings, and **any setting you changed but did not save must still be changed**.
- [ ] **One menu for leaving Settings.** Change something, then press **Circle** to leave: you should get the same *Save Changes / Reset Defaults / Discard & Exit* menu that **START** opens (not the old X-Save/O-Cancel/Triangle prompt). With nothing changed, Circle should just leave with no prompt.
- [ ] **Select on the Settings page no longer hides the text.** It should do nothing there. It must still work on the device list and the game lists. Hide UI Text is now only *Settings, Display, Hide UI Text*.
- [ ] **Keyboard opens in QWERTY** on a fresh install (it was ABC). ABC is still selectable in *Settings, Startup, Keyboard Layout*.
- [ ] *Settings, **Device List*** (renamed from "Carousel Devices") still hides and shows devices exactly as before.
- [ ] *Settings, Game List, Hidden games* now has a dimmed line under it: **"How to hide a game / L3 on the game list"**. Try it: L3 on a game hides it.
- [ ] **Translations:** switch language and check the new rows (About, Credits, Device List, the hide hint) are translated and not blank.
- Report: any button that stopped working (as opposed to stopped being listed), a Credits trip that lost your unsaved settings, or a blank or missing label.

### ⭐⭐ HDD (exFAT) via BDMA ATA — worked on one console, stalled on another; needs a wide pass

The flagship new feature this cycle (R3Z3N's ATA BDM Assault drivers + saildot4k's backend work): play from an **exFAT-formatted internal SATA/IDE drive**, exactly like a big USB stick. **If you have an exFAT internal drive, this is still one of the most valuable things you can test.** It listed and launched from a 4TB GPT drive on one console, but on another console it stalled while starting the drive for weeks afterwards, and the current build changed *when* the drive driver loads without that change being confirmed on hardware yet. If the page stalls, photograph the screen before rebooting: the step number and the bracketed text on it are the whole diagnosis.

**Setup:**
1. Format the internal drive **exFAT** (NOT the classic APA/PFS HDL layout — that's the separate "HDD (PFS)" entry).
2. Put a **`POPS/`** folder at the drive root with your `.VCD` files (+ your own `POPS_IOX.PAK`, `POPSTARTER.ELF`) — same layout as a USB stick.
3. *Settings → BDMA Mode → **ATA*** and save. *(On apply, the `.ata` launch drivers are copied — with the `.ata` suffix stripped — to `mc?:/POPSTARTER/`.)*
4. *Settings → **Device List** → **Internal HDD*** and save. The choices are **APA / PFS**, **exFAT**, and **Both**; **Both** is now the factory default, so a fresh install should already show both internal-HDD entries on the carousel. Picking a single filesystem shows only that page. *(A `-page=ata` boot argument opens the exFAT page regardless of this setting.)*

**Test:**
- [ ] Open the **HDD (exFAT)** carousel entry → it scans `mass:/POPS` and **lists your games**.
- [ ] Select a game → **X** → it **launches** through POPStarter (same as USB/MX4SIO).
- [ ] ⚠️ **Classification:** the exFAT drive must list/launch **only** under HDD (exFAT) — confirm it does **NOT** also appear under **USB** or **MX4SIO**, and that USB/MX4SIO still work normally. *(ATA is matched by exact ioctl driver-name `ata`, so it shouldn't leak — but this is exactly what hardware needs to confirm.)*
- [ ] No exFAT drive present / BDMA Mode ≠ ATA → the page shows **"No exFAT HDD detected"** and does **not** hang. *(Remember the page itself is only on the carousel while **Internal HDD = exFAT**.)*
- [ ] **Launch-arg routing (NEW — never HW-run):** booting with `-page=ata` (or `ata0`, or `exfat`) opens the **HDD (exFAT)** page; `-page=hdd` / `hdd0` / `apa` / `apa0` / any `pfs` open the classic **HDD (PFS)** page. (`-page=ata -game=<VCD>` should auto-launch from the exFAT drive.) Confirm `-page=ata` no longer lands on the PFS page.
- [ ] **Boot Page = HDD (exFAT):** *Settings → Startup → Boot Page* now offers **HDD (exFAT)** — set it, save, reboot → POPSLoader lands straight in the exFAT game list. If a saved Boot Page's device is hidden (e.g. HDD (PFS) after switching Internal HDD to exFAT), boot lands on the carousel **with a toast saying why** instead of silently.
- Report: empty list, a game that lists but won't launch, the drive showing under the wrong device, or a hang — include **console model** and **drive type/size**.

### ⭐⭐ Per-device POPSTARTER.ELF — NEW, never run on hardware

POPSLoader now picks the `POPSTARTER.ELF` for a launch **per device**, so you can keep a different POPStarter build on each device. At launch the search order is: **(1)** an explicit **POPSTARTER Path** you set in *Settings* if it resolves → **(2)** the game's own **`<device>:/POPS/POPSTARTER.ELF`** if present → **(3)** the `POPSTARTER.ELF` next to where **POPSLOADER.ELF** launched from → **(4)** the `mc0:`/`mc1:/POPSTARTER` fallback. On the internal **PFS HDD**, step 2 is **`hdd0:__common/POPS/POPSTARTER.ELF`**. The device + cwd steps are existence-gated, so a device with no copy just falls through — **per-device builds are enabled, not forced.** The release ships multiple POPStarter builds for exactly this (a normal one, a **USB-delay** one, and debug variants — the "POPSTARTER VERSIONS" in the zip). *(The old 16-entry Profile preset list is gone — leave **POPSTARTER Path** on **Automatic** for the order above, or set a path to pin one build.)*

**Test (each removable device — USB / exFAT / MX4SIO / MMCE):**
- [ ] ⭐ **Per-device build pickup (the headline use):** drop a specific `POPSTARTER.ELF` build — e.g. the **USB-delay** build — into the **USB** drive's `POPS/` folder. Launch a USB game (ideally one that *only* runs with the USB-delay build) → it should now use **that** build and launch. Other devices keep using their own / the fallback build.
- [ ] **Existing setups unchanged:** a device with **no** `POPSTARTER.ELF` in its `POPS/` folder still launches games exactly as before (it falls through to the launcher's own copy / the Memory Card).
- [ ] **Custom path always wins:** set an explicit **POPSTARTER Path** in *Settings* (an absolute path) → that build is used on **every** device regardless of any per-device copies. Clearing it returns to the per-device order.
- Report: a per-device build that **isn't** picked up, an existing setup that **stopped** launching, or the wrong build being used.

**Test (internal PFS HDD — launch-critical, please be thorough):**
- [ ] ⭐⭐ **HDD game launches via `__common`:** on a PSBBN / HDD-OSD internal drive where the POPStarter binaries live at **`hdd0:__common/POPS/`**, launch a PS1 game from the **HDD (PFS)** list → it boots POPStarter with **no black screen**. *(The new `hdd0:__common/POPS/POPSTARTER.ELF` step routes through the same internal-HDD machinery as before, but it has not been run on hardware — this is the most regression-prone path.)*
- Report: a black screen, a "can't find POPSTARTER" message, or any hang launching an internal-HDD game.

### ⭐ Settings page — round-2 redesign (NEW, never run on hardware)

The Settings page is now an **accordion**: only the section your cursor is in shows its rows; the others fold to a single header line. Headers are **gold** (they're labels, not rows), read-only status lines (like *Actual output*) are **dimmed darker** than anything you can select, and a section now **unfolds over a few frames** instead of snapping open.
- [ ] Move Up/Down through the whole page — every section opens as you enter it, the one you left folds, and the unfold looks like a quick drop-down (not an instant snap, not a slow crawl).
- [ ] Nothing dimmed-dark can be selected, and everything selectable can be reached. The dim *Actual output* line under Video Standard is informational — confirm it's obviously not an editable field now.
- [ ] ⚠️ **Save / Reset Defaults / Discard & Exit moved off the list: press START** — a small menu opens (Up/Down + Confirm; the cancel button closes it). Confirm all three actions work from it, and that the old inline rows are gone.
- [ ] Backing out with unsaved changes still asks "Save your changes before leaving?" exactly as before.
- [ ] **Hide UI Text** now reads **On/Off** (it was Hidden/Visible). Confirm On hides the footer/help text as before and the value survives a save + reboot.
- [ ] Every existing setting still saves/persists exactly as before.
- Report: a section that won't open, the START menu not appearing, an action firing twice, the cursor getting stuck mid-animation, or any setting failing to save.

### ⭐ Region-native confirm button (NEW — needs a JAPANESE console + any Western console)

On Japanese consoles the PS2 convention is **Circle = confirm, Cross = cancel**. POPSLoader now reads the console ROM at boot and flips its buttons AND all on-screen hints to match.
- [ ] **On a Japanese console** (any NTSC-J model): Circle confirms/launches, Cross cancels/goes back — everywhere (menus, settings, keyboard, the "Keep this display mode?" prompt, exit dialog). Every footer hint and every "X:/O:" text names the right button.
- [ ] **On a US/PAL console**: absolutely nothing changed — Cross still confirms everywhere.
- [ ] The **confirm action is always the left-most item** in the button bar at the bottom of every page, on both console types.
- Report: any screen where the buttons and the printed hints disagree, or where the old mapping stuck.

### ⭐ On-screen keyboard rework (NEW, never run on hardware)

- [ ] The keyboard opens **UPPERCASE** with the cursor on the **letter row** (Q on QWERTY), and the **number row is at the top**.
- [ ] The **Case/Symbols (R2)** label names the mode you'd **switch to** — press R2 and the typed case follows.
- [ ] **Hold Confirm on a key** — the key stays visually pressed for as long as you hold (it used to blink once and go dark mid-hold). Releasing or moving off drops it. Held Confirm still types **one** character, not a stream.
- [ ] The **layout strip inside the keyboard is gone** — the layout (**QWERTY** default / DVORAK / ABC / AZERTY / QWERTZ / ABNT) is picked in *Settings → Startup → Keyboard Layout* only. Confirm changing it there changes the keyboard.
- Report: the cursor landing somewhere odd on open, a layout with a misplaced key, or the pressed-key highlight misbehaving.

### ⭐ POPSTARTER Path — "Automatic" (profile presets removed; NEW, never run on hardware)

The **Profile** row (Profile 1..16 presets) is gone. *Settings → POPSTARTER → POPSTARTER Path* now shows **Automatic** by default — POPSLoader finds `POPSTARTER.ELF` on its own (the per-device order above). Set a path to pin a specific build; **clear the path** in the editor to go back to Automatic.
- [ ] On **Automatic**, every device that launched before still launches (nothing to configure).
- [ ] Set an explicit path → that build is used; set a **wrong/unplugged** path → the launch **still works** via the automatic order (no error unless nothing is found anywhere).
- [ ] With **no** `POPSTARTER.ELF` anywhere, launching warns that none was found (instead of a silent failure).
- [ ] If you had a **Profile** selected in an older build: after updating, launches still work with zero setup — your preset choice is carried over into **POPSTARTER Path** automatically on first boot (check *Settings → POPSTARTER*: the old preset's path should be filled in; the default Profile 1 shows Automatic).
- Report: a setup that launched before the update and stopped after it — include where your `POPSTARTER.ELF` files live.

### ⭐⭐ SMB (v1) network game browsing — NEW end-to-end, never run on hardware

SMB (v1) is now **implemented end-to-end** (CI + Rolling green) and **validating on hardware** — so far it has **zero hardware runs**. You set your server/share/credentials in a new **SMB / Network** Settings section, **install the in-game SMB streaming pack into `mc0:/POPSTARTER/`** (the same way BDMA installs its modules), then **browse and launch** PS1 games straight off a network share from the **SMB** carousel page. Networking is **lazy**: the stack comes up and the share opens **only** when you enter the SMB page or trigger a settings action — **nothing SMB runs at boot**. **NetBIOS is not supported** (the address type must be **IP**); the in-game pack is what POPStarter uses to stream the game off the share at launch.

**Setup:**
1. *Settings* → expand **SMB / Network** → set **Server IP**, **Share**, **User/Password**, **IP assignment** (DHCP/Static), **Port** (default **1111** — set this to your server's actual SMB port; stock SMB servers listen on **445**, the 1111 default suits alternate-port SMBv1 setups), **Games path (folder holding POPS)**, **Link mode**.
2. Set **SMB modules → Installed** and **Save** (this writes the pack + `SMBCONFIG.DAT`/`IPCONFIG.DAT` — see the install checks below).

**Settings + module install:**
- [ ] *Settings* → expand **SMB / Network**. Top row **SMB modules** (Installed / Not installed); below: **IP assignment** (DHCP/Static), **PS2 IP / Netmask / Gateway / DNS**, **Link mode**, **Server IP**, **Port** (default 1111), **Share**, **User**, **Password**, **Games path (folder holding POPS)**. *(The old Address type / NetBIOS name rows are gone — NetBIOS was never supported at connect time; use the Server IP.)*
- [ ] **Cycle** rows change with **Left/Right** / **X**; **text** rows open the on-screen keyboard on **X**. Password masks (`****`); empty **Games path** shows *"(share root)"*; empty Share/User show *"(not set)"*.
- [ ] **Keyboard symbols:** in any SMB text field, toggle **R2** — the digit/bracket keys now type `@ # $ % ^ * " < > | { } ~ \`` so usernames like `user@host`, hidden shares ending `$`, and symbol-heavy passwords are enterable.
- [ ] **Input hygiene:** type a value with a trailing space or a junk Port like `44S` → the editor immediately shows what was actually kept ("... adjusted") instead of silently saving garbage; a wrong-shaped IP falls back to the default with the same notice.
- [ ] Edit fields → **unsaved (accent) marker** → **Save Changes** → **reboot** → values **persisted** exactly as entered.
- [ ] ⭐ **SMB modules = Installed → Save:** `mc0:/POPSTARTER/` (or `mc1:` on a slot-2-only console) should now hold `poweroff.irx`, `ps2dev9.irx`, `ps2ip.irx`, `ps2smap.irx`, `smbman.irx`, `SMSUTILS.irx`, plus `SMBCONFIG.DAT` and (only when **IP assignment = Static**) `IPCONFIG.DAT`. Open `SMBCONFIG.DAT`: line 1 = `<Server>[:<Port>] <Share>`, then (if User **or** Password is set) username + password on lines 2/3. `IPCONFIG.DAT` = `<PS2 IP> <Netmask> <Gateway>`, and is **absent on DHCP**.
- [ ] ⭐ **Change an SMB field while Installed → Save:** the in-game `SMBCONFIG.DAT`/`IPCONFIG.DAT` are **backfilled on every save** — generated if missing, **regenerated** with the new values when changed (the 6 IRX are rewritten harmlessly).
- [ ] ⭐⚠️ **SMB modules = Not installed → Save:** the 8 SMB files are **removed**, but **`icon.sys`, `*.icn`, and any installed BDMA modules (`usbd.irx`/`usbhdfsd.irx`) MUST remain** — confirm BDMA still works afterward.
- [ ] **Reset Defaults** sets SMB modules → Not installed + fields to defaults (Save then uninstalls, mirroring BDMA→FAT32).
- [ ] ⚠️ **No regression:** every *other* setting still saves/loads as before, and **boot time is unchanged**.
- Report: a field that won't persist, the wrong files installed/removed, **BDMA modules or icons clobbered by SMB-off**, or any boot slowdown.

**Connect / browse / launch / disconnect (the new end-to-end path — never HW-run):**
- [ ] ⭐ **Lazy connect — confirm boot is untouched first:** boot straight to the menu and **stay off** the SMB page → **no** network activity, no slowdown, no errors. Networking must come up **only** on entering the SMB page (or a settings action), **never** at boot.
- [ ] ⭐ **Browse:** open the **SMB** carousel entry → it brings up the stack, opens the share, **scans `POPS/` and lists your VCD games** like any other device. The overlay now reports **each phase** ("Loading network modules...", "Waiting for network link..." / "Waiting for link + DHCP lease...", "Logging on to the share...") instead of freezing on one frame, and a failure names the failing step (no link / IP config / DHCP / can't reach server / **server refused SMBv1** / login / share). Report a hang, an empty list with games present, or a connect error **with the exact message**.
- [ ] **Modules-not-installed guard:** with **SMB modules = Not installed**, entering the SMB page warns that games will list but won't boot, and pressing **X** on a game is blocked with the same explanation (browsing itself still works).
- [ ] ⭐ **Launch:** select an SMB game → **X** → it hands off to POPStarter (argv0 selector `smb:/POPS/SB.<name>.ELF`) and **POPStarter streams the VCD from its own `smb:/POPS` mount** (via `mc:/POPSTARTER/SMBCONFIG.DAT`). *(Hardware-only unknown: the exact device prefix POPStarter accepts — we ship `smb:/POPS/SB.<name>.ELF`, with `mass:/POPS/SB.<name>.ELF` then `mass:/SB.<name>.ELF` as fallbacks. If a game lists but won't launch, note the exact behaviour.)*
- [ ] ⭐ **Disconnect on exit:** leave the SMB page → the share is closed and the session logged off (`CLOSESHARE` + `LOGOFF`); a **failed** connect also tears down cleanly with **no half-open session** left behind. Re-entering the page should reconnect fresh.
- [ ] ⭐ **Blank-share picker:** clear the **Share** field, then enter the SMB page → it enumerates the server's shares (`GETSHARELIST`) and an in-UI **picker** lets you choose one; your choice **persists** (settings + the in-game `SMBCONFIG.DAT`) and it reconnects. Report a picker that lists nothing, a choice that doesn't stick, or a reconnect that fails.
- The `.DAT` byte format is from the recovered POPStarter docs and is **hardware-confirmable only** (report if POPStarter rejects a generated `SMBCONFIG.DAT`). Other hardware-only unknowns: the connect handshake and the `GETSHARELIST` DMA.

### ⭐⭐ Adaptive BDMA — NEW, never run on hardware (needs a two-device setup, e.g. MMCE + USB)

- [ ] Turn on *Settings → Storage → Adaptive BDMA* (leave **BDMA Mode** on whatever you normally use), save.
- [ ] ⭐ Launch a game from **MMCE**, then (after coming back) a game from **USB** — **both booting, without touching Settings in between, IS the pass.** This is the whole feature: before, whichever BDMA Mode was saved broke the other device's launches. *(There is deliberately no on-screen notice on success — the launch hands off to POPStarter before anything could be shown.)*
- [ ] Optional deeper check: after launching from a device, look at `mc:/POPSTARTER/bdma_mode.txt` (e.g. from wLaunchELF) — it should name that device's driver set (`MMCE`, `MX4SIO`, `USBEXFAT`, `ATA`, or `FAT32` after a FAT32-USB launch).
- [ ] If staging ever **fails**, the launch is **cancelled** and a warning notice explains why — you're never dropped into a black screen with wrong drivers. Report the notice text if you see one.
- [ ] If your USB drive is **exFAT**: keep **BDMA Mode = exFAT-USB** saved — USB launches keep the exFAT drivers. If it's **FAT32**: any other saved mode is fine — USB launches remove the drivers so POPStarter's built-in stack runs.
- [ ] MX4SIO and HDD (exFAT) launches pick their own drivers the same way. Classic **HDD (PFS)** games and DKWDRV are untouched by this feature.
- [ ] Turn Adaptive **off** again (after having launched from a different device) and save — your **BDMA Mode** row should still show the mode YOU chose, and the drivers for it should be back on the card (the turn-off restores them). A BDMA Mode row that silently changed to some other device's mode = bug, please report.
- [ ] With Adaptive on, trying to turn the **POPSTARTER Folder** off is blocked with a notice (turn Adaptive off first) — confirm the block appears.

### ⭐⭐ Partition-installed PS1 games on the HDD page — NEW, never run on hardware

*(For drives with HDDOSD / PSBBN-style installs: one partition per game, named `PP.Something` — or `__.Something` for hidden ones — with the disc image inside always called `IMAGE0.VCD`.)*

- [ ] Open the **HDD (PFS)** page on a drive that has such partitions → each should appear in the list **under its own name** (the partition name without the `PP.` part), alongside any classic `__.POPS` games. A drive with ONLY partition installs (no `__.POPS` at all) should open the page too.
- [ ] ⭐ **Launch one** → POPStarter should boot it. *(This exercises POPStarter's `PP.Name.ELF` launch convention from a launcher, which has never been run on hardware from POPSLoader. If it black-screens or drops back, note whether your POPStarter is the r13 beta and where it lives — that's the key data.)*
- [ ] `PP.` partitions that are **apps, not games** (e.g. CodeBreaker installs) should **NOT** appear — only partitions actually containing an `IMAGE0.VCD` are listed.
- [ ] Cover art / description for these games: name the `.png` / `.txt` in `__common/POPS/ART/` after the game (partition name without the `PP.` / `__.` part).
- [ ] **L3** hide / unhide works on them like any other game (the marker is written to the game's own partition).
- [ ] In-game **memory card saves (VMCs)**: check whether saves work and where they land (`__common/POPS/<name>/SLOT0.VMC` is the documented spot). The POPStarter wiki documents a known bug in this launch type around `__common` files — whether it bites VMCs on the current beta is exactly what we need to learn.

### ⭐ Boot chime re-encoded (half the size) — needs an ear-check

- [ ] The boot chime should sound **exactly like before** — same tune, same pitch, same speed, full length. *(It was re-encoded at a lower sample rate; analysis says nothing audible changed, but a real console's sound chip is the only proof. "Sounds slow/low/chipmunked or crackly" = report immediately, it's a one-commit revert.)*

### ⭐ HDD page diagnostics (for the "HDD list comes up empty when booted from USB/MC" rig)

- [ ] If the HDD page ever shows **"No '__.POPS' partitions"** on a drive that definitely has them: the notice now ends with **"(last mount rc: N)"** — please report that number.
- [ ] A new **"HDD dir read failed: ..."** notice means the partition mounted but wouldn't list — report it with the text.
- [ ] If the HDD page said "HDD not usable" right after boot, going back to the carousel and re-entering the page a few seconds later should now **recover on its own** once the drive spins up (it used to stay dead until reboot).

### Navigation & input — ✅ core nav CONFIRMED on hardware (oldman63); the rest still to feel out

- [x] **Up/Down + analog-stick item nav** — ✅ **CONFIRMED (oldman63):** d-pad and **left analog stick up/down** both land on **individual items** (item-by-item), and a held direction does smooth continuous scroll. *(The stick now folds into the d-pad and runs the same edge + auto-repeat path — no more "flies a whole page" / "can't select individual items" #501. A non-analog/digital pad is gated out so it can't inject a phantom direction; the auto-repeat is frame-counted, ~0.6 s before the first repeat then ~5/sec.)* Re-confirm on **each device's** list if you can.
- [ ] **Page-jump & top/bottom** — on a big list: **LEFT / RIGHT** (d-pad **or** left stick left/right) jumps a **page** at a time; **L1** ping-pongs **top ↔ bottom**. Confirm these still work after the nav rework.
- [ ] **R3 = reveal / hide hidden games** ⭐ **STILL never run on hardware. Test on each device** (HDD / USB / MX4SIO / MMCE — R3 is ignored elsewhere). **R3's reveal is a temporary, session-only view** — the persisted setting lives in *Settings → Game List → Hidden games*:
  1. Hide a couple of games with **L3** (with *Hidden games* set to **Visible (manage)**).
  2. *Settings → Game List → Hidden games → **Hidden*** and save (they vanish).
  3. On the device list press **R3** → list rebuilds, hidden games **reappear dimmed** + toast *"Showing hidden games (dimmed) -- press L3 to unhide"*.
  4. **L3** on a dimmed game → *"Game shown"*. *(L3 is blocked while Hidden mode is ON and no reveal is active — it says to press R3 first.)*
  5. **R3** again → hidden games vanish + *"Hidden games filtered out again"*.
  6. **Reboot** (or just leave and re-enter the page) → the reveal is gone and the SAVED Hidden-games setting is back in force — R3 never persists anything.
  - Report: empty/wrong list after R3, a crash, a device failing to re-scan, or a reveal that leaks across pages/reboots.
- [ ] **Boot sound On/Off** — *Settings → Game List → Boot sound* (default **On**) gates the splash chime. ✅ **save survives reboot CONFIRMED (oldman63);** still confirm Off actually silences the chime.
- [ ] ⭐ **Cover art location (now FIXED, not selectable)** — the *Cover/details folder* setting was **removed in EXP35**, and since **EXP71** exactly one path is read per device. Removable devices: **`<device>:/ART/<gamefilename>_COV.png`** (OPL's layout). Internal HDD/APA: **`hdd0:__common/POPS/ART/<gamefilename>_COV.png`**. The name must match the game file **exactly** — the disc-marker-stripped family name is no longer tried, so a multi-disc game needs one art file **per disc**, each named after that disc's `.VCD`. Confirm a cover in `<device>:/ART/` appears, and that art in the old `POPS/ART/` or beside-the-`.VCD` spots no longer does (that is intended, not a bug — move the files). Whether covers draw at all is *Settings → Game List → Cover art* (**default On**), which replaced the old session-only Square toggle. **If a cover does not appear** there is no longer any on-screen diagnostic caption (the "No cover. Looked for: `<path>`" line was removed in EXP42) — check the filename and folder against the exact path above.
- [ ] ⭐⭐ **Per-game info text (the headline test for this build)** — *Settings → Game List → Game details* defaults **Off**; set it to Left/Center/Right aligned and leave **Cover art** on. Put the `.txt` at exactly **`<device>:/ART/<gamefilename>.txt`** (internal HDD/APA: `hdd0:__common/POPS/ART/<name>.txt`), same folder and same exact name as the cover. Check three cases: a game with **both** a cover and a `.txt` (this one was broken in the previous build), a game with **only** a `.txt` (check it on the first visit **and** again after leaving the list and coming back), and a game with neither. Then scroll a mixed folder quickly and confirm no game ever shows **another** game's text. Line breaks are kept; *Off* hides the panel.
- [ ] **Description scroll** — long `.txt` scrolls with the **right analog stick** at a fixed **Fast** pace (~7 lines/sec, frame-counted). The Fast/Medium/Slow speed setting was removed (provato: Fast is best). Confirm the scroll feels right.
- [ ] **Game list cache (opt-in, default OFF)** — *Settings → Game list cache → ON:*
  - [ ] First entry builds; second entry / reboot **loads fast** (no "Building…").
  - [ ] ⚠️ **CRITICAL: launch a game FROM the cached list** on each device incl. **HDD** — it must still **launch correctly**, not just load fast.
  - [ ] **R1** forces a rebuild.
  - [ ] Toggle a list-affecting setting (Multi-disc / Hidden games) → cache **rebuilds**, doesn't serve a stale list.
- [ ] **Boot Page** — *Settings → Startup* → pick a device → after boot it lands **straight in that device's list** (or Carousel default).
- [ ] **Device List visibility** — *Settings → Device List* → hide e.g. SMB / i.Link → they leave the wheel with **no gaps**, ≥1 stays, launching the others unchanged.
- [ ] **Multi-disc collapse** — *Settings → Game List*, files named `Game (Disc 1).VCD` / `Game (Disc 2).VCD` → only **Disc 1** shows; swap discs in-game via VMC.

## 🟨 P2 — Hide / settings persistence

- [ ] **L3 hide/unhide** on every device incl. **HDD** (drops `.hide` next to the VCD; on HDD writes to the boot partition — old "add it from a PC" is now only a write-failure fallback).
- [ ] **Hidden games filter** — *Hidden* filters out; *Visible (manage)* shows dimmed so L3 can toggle them back.
- [ ] **Settings save & persist** — change a setting, **reboot**, confirm it stuck. **Especially HDD installs** (settings save to the HDD boot partition now — RW confirmed by provato, full flow wants more confirmation).
- [ ] **Unsaved-changes prompt** — change a *cycle* setting (Game details / Cover art / cache / Boot sound / Overscan / Boot Page) and press **BACK** without saving → it warns you.
- [ ] **POPSTARTER MC Folder toggle + BDMA interlock** — toggle the `mc:/POPSTARTER` folder (off **deletes** it, with confirm). Can't disable the folder while BDMA is on, nor enable BDMA while the folder is off. *(BDMA mode now in `bdma_mode.txt`; legacy `.pldr_bdma_mode` still read.)*

## 🟦 P3 — Display / PAL (needs PAL hardware — we have none on the team)

- [ ] **Video Standard** — *Settings → Display*. **Auto** default should match your console's region. On **PAL** the UI should fill the screen **edge-to-edge at 640×512** (no letterbox). Report your console's **actual output** reading.
- [ ] **Display-change confirm/revert** — change the mode; if you don't confirm in time it **auto-reverts**.
- [ ] **Overscan (CRT inset)** ⭐ **NEW — needs a CRT eyeball, not yet verified.** *Settings → Game List → Overscan (CRT inset)* (default **Off**; **LEFT/RIGHT steps ±5**, live preview). Raise it on a CRT that crops the edges → the whole UI should shrink **uniformly toward center** (OPL-style render inset). Discarding the settings change restores the previous value. Report the value that just clears your bezel.

## ⬜ P4 — Cosmetic / polish

- [ ] List a touch **wider**; device name (e.g. "USB") no longer overlaps the **top row**; "Building…" overlay calmer.
- [ ] **Cover placeholder art** ⭐ **NEW assets, needs an eyeball on NTSC + PAL.** No live cover now draws a layered jewel-case placeholder (`cover_default.png`), with a `cover_missing.png` overlay **only** when the preview is **ON** but the game has no cover. *(The old "Cover disabled" **text** label is gone.)* Confirm the default cover, the missing overlay, and `frame.png` all **register** with the jewel-case window (right-anchored, no drift) on both NTSC and PAL.
- [ ] **Cover-art preview** is *Settings → Game List → Cover art* (default **On**, saved across reboots; Square no longer toggles it) — OFF shows the plain default case (no overlay), ON shows the live cover or the missing-overlay placeholder.
- [ ] **Scroll position kept** returning from Settings (cursor doesn't snap to row 1).
- [ ] **On-screen keyboard feedback** (editing a POPSTARTER / DKWDRV path) — pressing a key now **flashes it** briefly, and the text caret **blinks** at a normal rate. *(Both were broken by a microsecond-vs-millisecond timer bug — the flash expired before the next frame so it never showed, and the caret blinked ~1000× too fast; purely cosmetic, no input behavior change.)*

## 🧪 P5 — Robustness (only if you hit it)

- [ ] **Corrupt / oversized cover** (PNG/JPEG/BMP) — must **not crash** the list (hardened this cycle).
- [ ] **Very long VCD filenames** — ~**73 chars** practical limit; longer may fail to launch.
- [ ] **DualShock 4 over Bluetooth** (only if you use one) — lightbar colour + rumble still behave after a code fix that stopped the BT output report carrying ~29 bytes of uninitialized data. Confirm the DS4 still pairs, the lightbar sets, and rumble works.

## 📦 Release zip contents

- [ ] The rolling zip ships, at the **root**: a **`POPSTARTER/`** folder (SMB `.irx` pack), **`POPS/PATCH_5.BIN`**, **`POPSTARTER.ELF`** (also copied into **`POPS/`**), and a **`POPSTARTER VERSIONS/`** folder (the MAIN / DEBUG / USBDELAY / USBDELAY_DEBUG POPStarter builds, for the per-device test above) — confirm they're present in your download. *(POPS engine binaries are not redistributable and are NOT included; you still supply your own.)*

---

## ℹ️ Known issues — expected, please don't re-report (unless your case differs)

- **"Failed to load HDD" when POPSLoader is launched from a non-HDD device** via a launcher (config-specific, seen by Nuno) — most setups list the HDD fine. **If you hit it, post your exact boot config**; it now shows the real reason on a second line. Workaround: boot from the HDD, or open the HDD page a few seconds after the menu.
- **PAL console still showing PAL when NTSC is selected** (#495) — known, being chased; the "actual output" reading helps.
- ~~**DKWDRV exit back to memory card "hangs on the pic"**~~ — closed 2026-07-23: DKWDRV-side behavior, not a POPSLoader defect.
