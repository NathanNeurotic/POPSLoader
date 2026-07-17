# POPSLoader: Experimental Build 🧪

**This is an opt-in EXPERIMENTAL build.** The public release (**1.0.1**) and the rolling test build are untouched by anything here.

**How to tell you are running it:** open **Settings**, then **About**, and read the **Version** row: it says **v1.0.2-dev-EXP22**. A version with no EXP on the end is the rolling test build; no version at all means the public 1.0.1 release or older.

---

## EXP22: load the ATA driver when everything else loads, not on the page

The last several builds were me editing the ATA driver. That was wrong, and the diagnosis is settled: EXP18 and EXP19 shipped wLaunchELF R3Z's ATA driver **byte for byte**, and it still froze. A driver that reads the drive perfectly in R3Z cannot be the problem. It never was.

Reading R3Z's and OPL's actual source side by side made the real difference obvious, and it is not in the driver at all. It is *when* we load it.

- **OPL** loads all its drive drivers back to back at startup, on a background worker, and then scans.
- **R3Z** loads the whole ATA stack together on a freshly prepared system.
- **POPSLoader** loaded the USB driver at startup but the internal-drive (ATA) driver **minutes later, on the exFAT page, on the main thread that draws the screen.**

That last one is the freeze: the screen is frozen at step 45 because it is waiting on a driver load that we kicked off *right there on the drawing thread*, onto a system that has been running since power-on. It is the one arrangement neither working tool uses. And it is the exact mistake our own code already fixed for the USB driver a while back, and simply never fixed for the ATA one.

**EXP22 loads the ATA driver at startup, right next to the USB driver, the way OPL and R3Z do.** By the time you open the exFAT page, the driver is already up, so the step that used to freeze is now nothing to wait for.

### What this means for you

- The exFAT page should come up without the long stall at 45%.
- Boot may take a couple of seconds longer, because the drive driver now comes up during startup instead of when you open the page. If EXP22 fixes the freeze, that startup cost gets tuned down afterward so only people who actually have an internal drive pay it.

### What to do

Just use it normally. Boot, then open the **HDD (exFAT)** page.

- **Your games listing, without the long freeze** means this was it: the driver was being loaded at the wrong time, and now it is not.
- **A freeze somewhere else** (a different step number, or during boot) is still useful: it tells us the problem was never the driver load and points at the drive scan instead.

No unplugging anything, no waiting ten minutes, no special steps. If it still misbehaves, a photo of wherever it stops is all I need.

### Honest note

This is the first build in a while that changes *our* program instead of the driver or your setup, and it is grounded in what the two launchers that read your drive actually do. I am not going to promise it is the fix. But it is aimed at a real, specific difference between us and them, and if it is wrong it will be wrong in a way that finally points somewhere new.

---

## How to report

Please say **which build** (v1.0.2-dev-EXP22, from Settings then About), **which device**, your **console model and region**, and what you did. A photo helps.
