# POPSLoader — Rolling Test Build ⚙️

**This is a bleeding-edge TEST build, not a stable release.** It has everything from the latest stable **plus** features still being tested. Please try it and report anything odd — and mention you're on the **rolling** build. To go back to stable, just reinstall the latest entry on the **Releases** page.

Here's everything new or changed **since BETA-9**.

---

## 🆕 Currently testing (newest — we'd love your feedback)

- **🆕 Internal HDD (exFAT) — NEW backend!** You can now play from an **exFAT-formatted internal SATA/IDE drive**, picked from the carousel's **HDD (exFAT)** entry. Set *Settings → BDMA Mode* to **ATA**, put the usual `POPS/` folder (with your `.VCD` files) on the exFAT drive, and it works just like USB / MX4SIO / MMCE — same layout, same `XX.` launch; the **BDM Assault** drivers (R3Z3N's ATA build) do the rest. It's built and the rolling build is green, but it **has not been tested on real hardware yet** — if you have an exFAT internal drive, please try it and tell us whether the **HDD (exFAT)** page lists your games and they **launch**. (Don't see your games? Confirm the drive is **exFAT**, BDMA Mode is **ATA**, and your files are in `POPS/`.)

**Newest this cycle — UI, cover art & navigation (please eyeball the items marked below):**
- **Per-game info text** — drop a `<game>.txt` next to a game, then turn on *Settings → Game details* (**Off / Left / Center / Right** alignment) to show it in a panel under the cover. Your line breaks are kept. Scroll long text with the **right analog stick**, and set the pace in *Settings → Description scroll speed* (**Fast / Medium / Slow**). The three speeds are now distinct (≈1, 3 and 7 lines/sec) — previously they all felt the same. Please tell us if the scroll feel is right.
- **Smoother list navigation** — the **left analog stick** now moves the cursor **one game at a time** (just like the d-pad), with a comfortable hold-to-repeat (it starts repeating after a short hold, then about 5 items/sec). **Left/Right** (d-pad or stick) jumps a **whole page**, and **L1** still bounces between top ↔ bottom. The stick only kicks in on real analog/DualShock pads now (a digital pad no longer injects a phantom direction), so up/down lands on individual items cleanly — **oldman63 and Nuno6573 confirmed this on hardware**. And the list no longer bogs down while cover art is on — it was redoing work every frame; please tell us if scrolling feels snappy with covers enabled.
- **Game list cache (opt-in)** — *Settings → Game list cache.* USB / MMCE / MX4SIO / HDD can save their scanned list per device so the "Building game list…" step only runs once (rebuild it any time with **R1**). **Off by default.** If you switch it on, please test that games still **launch** from the cached list, not just that it loads fast.
- **New cover-box artwork (newest)** — the placeholder in the preview box is now a proper **jewel-case picture** instead of a text label. With cover preview **off** you see a clean default case; with preview **on** but the game has **no** cover art, that default case gets a small "missing cover" mark layered on top. (The old **"Cover disabled"** text label is gone, and the single old `MISSING.png` placeholder was dropped — that alone shaved **~62 KB** off the build.) The default, the missing mark, and the frame outline all line up inside the jewel-case window. **Please eyeball this on a TV** — does the default cover + missing mark sit squarely inside the frame on **both NTSC and PAL**? It hasn't been checked on real hardware yet.
- **Cleaner game list** — wider list, the device name (e.g. "USB") no longer overlaps the top row, and the "Building…" progress bar is calmer.
- **Boot polish** — the welcome splash now appears **immediately** (covering the old boot black screen) and is centered from the first frame; leaner build (~48 KB smaller). Please just confirm boot still reaches the menu cleanly on each device.
- **Boot sound on/off** — *Settings.* A new **Boot sound** switch (**default On**) for the splash chime; turn it off for a silent boot. It saves with your other settings — **oldman63 confirmed it saves and survives a reboot** on hardware.
- **Overscan (CRT inset)** — *Settings → "Overscan (CRT inset)".* If a real CRT cuts off the edges of the menu, nudge this up (**Off, then 5 → up** in steps of 5) to pull the whole UI inward, OPL-style. It previews live as you adjust and reverts if you back out without saving; **Off** by default so nothing changes unless you ask. **This one needs CRT eyeballs** — try it on a tube TV and tell us whether the inset clears your overscan without leaving black borders.

- **HDD load crash — FIXED.** The big one: the HDD game list could fail with *"Failed to load HDD"* on the **second** boot (and stay broken until you cleared a file) because of a cache bug. That's fixed — the HDD list should now load reliably **every** boot. If you ever see *"Failed to load HDD"* again, please screenshot it — it now shows the real reason on a second line.
- **Display / Video standard fix** — *Settings → Video.* POPSLoader now honors your **Video Standard** choice, with a new **Auto** default that matches your console's region (fixes e.g. PAL consoles displaying in PAL when NTSC was selected). On **PAL** the UI now renders **natively at 640×512** so it fills the whole screen — no more letterbox / dead band. Two safety nets like OPL: **hold START during boot** to skip past video settings if a bad mode leaves you with no picture, and a **confirm/revert prompt** when you change the mode (it auto-reverts if you don't confirm in time). PAL hardware verification is exactly what we'd love feedback on — does the screen fill edge-to-edge?
- **POPSTARTER Memory Card Folder toggle** — *Settings.* A new switch for the `mc:/POPSTARTER` folder on your Memory Card. Turning it **off deletes** `mc:/POPSTARTER` (you'll get a confirm prompt first — it's a destructive action). It's **interlocked with BDMA**: you can't disable the folder while BDMA mode is on, and you can't enable BDMA while the folder is off. (Heads-up for the curious: the installed BDMA mode is recorded in a `bdma_mode.txt` marker in your POPSTARTER pack folder — renamed from the old `.pldr_bdma_mode`; the legacy name is still read.)
- **Boot Page** — *Settings → Startup.* Choose where POPSLoader opens after boot: the device carousel (default), or jump straight into a specific device's game list (**MX4SIO / USB / MMCE / HDD**).
- **Multi-disc games** — *Settings → Game List.* Optionally hide the extra discs of multi-disc games so only **Disc 1** shows. It works by **filename**, so name your files like `Game (Disc 1).VCD` / `Game (Disc 2).VCD`. Launch Disc 1 and swap discs in-game with your VMC.
- **Hide games** — press **L3** on any game to hide/unhide it (drops a tiny `<name>.hide` file next to its `.VCD`, like the cover `.png`); press **R3** to reveal a device's hidden games — they show dimmed so **L3** can unhide them — or hide them again. *Settings → Game List → Hidden games:* **Hidden** filters them out of the list; **Visible (manage)** shows them dimmed so you can toggle them back with **L3**. In-app hiding now works on **every** device page — USB / MX4SIO / MMCE / Memory Card **and the internal HDD** (the HDD writes the `.hide` straight to its boot partition; the old "add the file from a PC" step is gone). If an HDD write ever fails, it falls back to telling you to add the `.hide` from a PC — please report it if you see that.
- **Carousel device visibility** — *Settings → Carousel Devices.* Hide carousel entries you don't use (including **SMB** if you don't have a network share, or the not-yet-implemented **iLink** stub) with a **Shown / Hidden** toggle per device; at least one device always stays visible. Your launch behavior is unchanged — hidden entries are just skipped on the carousel.
- **HDD settings now save on the HDD** — on an HDD install, your Settings save **directly to the HDD** (on its boot partition), right where POPSLoader lives — same as a USB / MX4SIO / MMCE install keeps its own settings. This used to be a read-only "probe"; it's a real save now. It boots on PCSX2 and provato confirmed the HDD is writable on real hardware, but the full save flow is still validating on hardware — so please save a setting, reboot, and tell us if it stuck.

## 🎮 Since BETA-9 — the big stuff

**Internal HDD (PFS)**
- Major HDD reliability fixes — games that wouldn't launch from an HDD-resident POPSTARTER now work.
- The HDD game list now loads even when you start POPSLoader from **USB or Memory Card** (it waits for a cold drive to spin up instead of failing instantly).
- The HDD game list opens instantly on repeat visits within a session — press **R1** on the HDD page to force a fresh rescan.
- **DKWDRV** launches from **custom HDD paths**, not just the default location.

**BOOT.ELF / Exit**
- "Exit → BOOT.ELF" handoff fixed for the common cases (booting from USB / MC / MMCE / MX4SIO / OSDmenu / Browser / PSBBN).

**Devices & launching**
- **MMCE**: controller input no longer goes dead after you open the MMCE game list.
- **Launch arguments** (`-page` / `-mode` / `-game`): other launchers can open POPSLoader straight to a device — or straight into a game.
- Settings now save **per device** (right next to the launcher) — a USB / MX4SIO / MMCE install keeps its own settings.

**Polish**
- Leaner, faster build (removed unused internals) and assorted stability fixes.
- A full documentation overhaul.

## ⚠️ Known issues / still being verified
<!-- MAINTAINER: this list is a tester-facing summary. The canonical bug list lives in STATE.md > Known Issues — reconcile against it on every push; don't leave fixed items here. -->
*Canonical list: **STATE.md > Known Issues**. Tester summary:*
- **Confirmed on hardware this cycle (thank you!):** the **Boot sound** toggle saves and survives a reboot (oldman63); up/down **and** left-stick navigation land on individual items with smooth continuous scroll (oldman63); and the latest rolling is running well overall (Nuno6573).
- **Still wants an eyeball (works in testing, not yet hardware-confirmed):** the new **cover-box artwork** (default cover + missing mark lining up inside the jewel-case frame on **NTSC and PAL**), the **Overscan (CRT inset)** on a real tube TV, and the **Description scroll speed** feel. Please report on these specifically.
- **Other new features aren't broadly hardware-confirmed yet.** HDD in-app hide (L3), HDD-resident settings save, native PAL 640×512, and the POPSTARTER Memory Card Folder toggle all boot on PCSX2, and provato confirmed the HDD is writable on real hardware — but the full flows are still validating on hardware. These are exactly what we're asking you to test; please report what works and what doesn't.
- **_"Failed to load HDD" on the second boot_ — FIXED.** That was the cache bug above (it hit setups that had loaded the HDD successfully at least once before). If you ever see it again, it now shows the real error on a second line — please screenshot.
- **_"Failed to load HDD" from a non-HDD boot_ — still open (config-specific).** On a specific setup, launching POPSLoader from **USB / Memory Card** via a launcher can fault while building the **HDD** game list (most setups list the HDD fine; POPSLoader itself starts normally). Workaround: boot POPSLoader from the HDD, or wait a few seconds on the menu before opening the HDD page. We're still isolating this one — if it hits you, tell us your exact boot setup.

## Install
Extract to your device like any POPSLoader build, replacing your current install.
