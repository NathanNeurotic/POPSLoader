# POPSLoader — Rolling Test Build ⚙️

**This is a bleeding-edge TEST build, not a stable release.** It has everything from the latest stable **plus** features still being tested. Please try it and report anything odd — and mention you're on the **rolling** build. To go back to stable, just reinstall the latest entry on the **Releases** page.

Here's everything new or changed **since BETA-9**.

---

## 🆕 Currently testing (newest — we'd love your feedback)

- **HDD load crash — FIXED.** The big one: the HDD game list could fail with *"Failed to load HDD"* on the **second** boot (and stay broken until you cleared a file) because of a cache bug. That's fixed — the HDD list should now load reliably **every** boot. If you ever see *"Failed to load HDD"* again, please screenshot it — it now shows the real reason on a second line.
- **Display / Video standard fix** — *Settings → Video.* POPSLoader now honors your **Video Standard** choice, with a new **Auto** default that matches your console's region (fixes e.g. PAL consoles displaying in PAL when NTSC was selected). Two safety nets like OPL: **hold START during boot** to skip past video settings if a bad mode leaves you with no picture, and a **confirm/revert prompt** when you change the mode (it auto-reverts if you don't confirm in time).
- **Boot Page** — *Settings → Startup.* Choose where POPSLoader opens after boot: the device carousel (default), or jump straight into a specific device's game list (**MX4SIO / USB / MMCE / HDD**).
- **Multi-disc games** — *Settings → Game List.* Optionally hide the extra discs of multi-disc games so only **Disc 1** shows. It works by **filename**, so name your files like `Game (Disc 1).VCD` / `Game (Disc 2).VCD`. Launch Disc 1 and swap discs in-game with your VMC.
- **Hide games** — press **L2** on any game to hide/unhide it (drops a tiny `<name>.hide` file next to its `.VCD`, like the cover `.png`). *Settings → Game List → Hidden games:* **Hidden** filters them out of the list; **Visible (manage)** shows them dimmed so you can toggle with L2. In-app L2 hiding works on USB / MX4SIO / MMCE / Memory Card; on internal **HDD** it's read-only for now (add/remove the `.hide` file from a PC — the HDD probe above is testing whether in-app HDD writes can be unlocked).
- **HDD settings test** — on an HDD install, saving Settings pops a small message telling us whether your HDD can store settings directly. It's just a probe (your settings are unaffected) — please report what it says.

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
<!-- MAINTAINER: re-check this list on every push against the ACTUAL open bugs. Do not leave fixed items here. -->
- **The new features above aren't hardware-confirmed yet.** Boot Page, Multi-disc collapse, and the HDD settings probe are exactly what we're asking you to test — please report what works and what doesn't.
- **_"Failed to load HDD"_ — we believe this is now fixed.** It was the cache bug above, which hit setups that had loaded the HDD successfully at least once before. If you still hit it on this build, please report — it now shows the real error on a second line.

## ℹ️ Good to know (by design, not bugs)
- **HDD installs save their settings to the Memory Card** (`mc0:`), not the HDD — the HDD driver can't reliably write its own partition. The new HDD settings probe is testing whether that can change.

## Install
Extract to your device like any POPSLoader build, replacing your current install.
