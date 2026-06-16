# POPSLoader — Rolling Test Build ⚙️

**This is a bleeding-edge TEST build, not a stable release.** It has everything from the latest stable **plus** features still being tested. Please try it and report anything odd — and mention you're on the **rolling** build. To go back to stable, just reinstall the latest entry on the **Releases** page.

Here's everything new or changed **since BETA-9**.

---

## 🆕 Currently testing (newest — we'd love your feedback)

- **Boot Page** — *Settings → Startup.* Choose where POPSLoader opens after boot: the device carousel (default), or jump straight into a specific device's game list (**MX4SIO / USB / MMCE / HDD**).
- **Multi-disc games** — *Settings → Game List.* Optionally hide the extra discs of multi-disc games so only **Disc 1** shows. It works by **filename**, so name your files like `Game (Disc 1).VCD` / `Game (Disc 2).VCD`. Launch Disc 1 and swap discs in-game with your VMC.
- **HDD settings test** — on an HDD install, saving Settings pops a small message telling us whether your HDD can store settings directly. It's just a probe (your settings are unaffected) — please report what it says.

## 🎮 Since BETA-9 — the big stuff

**Internal HDD (PFS)**
- Major HDD reliability fixes — games that wouldn't launch from an HDD-resident POPSTARTER now work.
- The HDD game list now loads even when you start POPSLoader from **USB or Memory Card** (it waits for a cold drive to spin up instead of failing instantly).
- The HDD game list is now **cached** for instant repeat opens — press **R1** on the HDD page to force a rescan.
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
- **A few setups report _"Failed to load HDD"_ when POPSLoader is launched from a non-HDD device** (USB / Memory Card). Most consoles are fine. Workaround: launch POPSLoader from the HDD, or open the HDD page a few seconds after the menu appears.

## ℹ️ Good to know (by design, not bugs)
- **HDD installs save their settings to the Memory Card** (`mc0:`), not the HDD — the HDD driver can't reliably write its own partition. The new HDD settings probe is testing whether that can change.

## Install
Extract to your device like any POPSLoader build, replacing your current install.
