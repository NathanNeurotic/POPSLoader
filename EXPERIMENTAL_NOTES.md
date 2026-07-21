# POPSLoader: Experimental Build 🧪

**This is an opt-in EXPERIMENTAL build. It is not a replacement for the public release, and it is not the rolling build either.** It exists so testers can try riskier changes in isolation, without them reaching anyone who did not ask for it. The public release (**1.0.1**) and the rolling test build are both untouched by anything here.

**How to tell you are running it:** open **Settings**, then **About**, and read the **Version** row: it says **v1.0.2-dev-EXP24**. The **Credits** page shows the same line at the bottom left, with the boot timing under it. A version ending in **-EXP24** = this build; any older EXP number = an older experimental, please update; plain **v1.0.2-dev** = the rolling test build; no version anywhere = the public 1.0.1 release or older.

**What the name means:** this build is the **rolling** build (1.0.2-dev) plus the experiments below, nothing missing.

**How to go back:** reinstall the latest entry on the Releases page. Nothing here changes your settings, your `POPS` folders, or your games, so switching back and forth is safe.

---

## New in EXP24: the 42% hangs (MX4SIO and internal exFAT HDD) get their real fix

The last round of reports made the picture click into place: the MX4SIO page and the internal exFAT HDD page were both hanging at 42%, on the rolling build and on the experimental build alike. That symmetry was the clue. It turned out to be two separate mistakes on our side, both now fixed in this build.

**Mistake one, and why MX4SIO broke: a mismatched driver pair.** Back in mid July, while fixing the "No USB backend detected" problem, we updated the core storage drivers to the set wLaunchELF R3Z ships. That fixed USB (and it stayed fixed). But one driver got left behind in the swap: the MX4SIO card driver stayed the old build. The new storage core and the old card driver do not speak the same dialect, and when the MX4SIO page loaded that old driver into the new core, the card never finished registering and the page waited forever at 42%. Every build since mid July has had this, which is why it looked the same on rolling and experimental, and why we wrongly blamed a different change at first. EXP24 ships all of these drivers from one matching set, including the MX4SIO one.

**Mistake two, and why the exFAT page froze: loading the internal drive's driver at the worst possible moment.** The internal drive's driver does all of its drive detection the instant it loads, inside the loading call itself, and one of its internal waits can wait forever if the timing goes wrong. Loading it while the whole system is busy (USB active, controllers polling, sound running) is exactly when the timing goes wrong, and that is what opening the exFAT page used to do. Worse, when that load wedges, the system's module loader is stuck for good, so the next page that needs to load a driver (MX4SIO) also hangs at 42%. One wedge, two broken pages. None of the launchers that handle these drives well (OPL, wLaunchELF R3Z, NHDDL) ever load this driver that way, and the EXP22 test proved the same driver works fine when loaded during startup instead. So in EXP24 the internal drive comes up during boot, before the system gets busy, and the exFAT page never loads drivers again. If the drive did not come up at boot, the page simply says no drive was found, it cannot freeze there anymore.

**Also in EXP24, kept from EXP22 because it worked:** the updated storage core that understands the newer GPT partition style. This is what let EXP22 read the 4TB drive, and it is required for that drive; the rolling build's core only understands the older MBR style.

**What EXP24 does NOT do, deliberately:** the EXP22 build loaded the internal drive stack on every single boot, unconditionally, and that caused collateral damage (MMCE game launches came out broken). EXP24 skips the internal drive stack entirely when POPSLoader was started from an MMCE device, so that path stays exactly as it is on rolling. Boots from USB, memory card, or the internal drive do run it; with no internal drive connected the check exits in well under a second, and with a real drive it costs a few seconds of boot time while the drive spins up (you will see it as "ata bdm stack" in the boot timing on Credits).

### The test list (one boot each, in any order)

1. **USB drive page and a USB game launch.** The storage core changes vintage here, so this is a real check, not a formality. Expected: works like rolling.
2. **MX4SIO page.** This is the headline retest. Expected: the page scans past 42%, lists games, launches one. If it still hangs at 42% on a fresh boot (without having opened the exFAT page first that boot), photograph the screen.
3. **Internal exFAT HDD page (the 4TB GPT drive).** Expected: boot takes a few extra seconds, then the page lists games and launches one, like EXP22 did. If the page says no drive was found, tell us what the boot timing line on Credits says.
4. **MMCE page and an MMCE game launch.** Expected: identical to rolling, this build keeps the drive stack completely away from MMCE boots.
5. **Memory card page.** Expected: unaffected.
6. **Internal drive with games installed as partitions (APA), if available.** Expected: works as before.

If something hangs, the one photo that answers everything is the frozen screen with its percent number and message.

---

## History

EXP23 tried to fix the exFAT freeze by moving the same page-time driver load to a background thread; the console stopped freezing outright but the load still wedged internally, so the page still hung at 42%, and it could still take the MX4SIO page down with it. Superseded by EXP24's boot-time load. EXP22 proved the boot-time load and the GPT-capable storage core read the 4TB drive on real hardware, but shipped without the MX4SIO driver fix and with the drive stack forced onto every boot including MMCE, which is what EXP24 corrects. Older experiment notes live in the git history of this file.
