# POPSLoader: Experimental Build 🧪

**This is an opt-in EXPERIMENTAL build.** The public release (**1.0.1**) and the rolling test build are untouched by anything here.

**How to tell you are running it:** open **Settings**, then **About**, and read the **Version** row: it says **v1.0.2-dev-EXP20**. A version with no EXP on the end is the rolling test build; no version at all means the public 1.0.1 release or older.

---

## EXP20: the exFAT page was never frozen. It was waiting.

EXP19 answered the question we built it to answer, and the answer changed everything.

Its screen stopped at **step 45**, with wLaunchELF R3Z's own drive drivers in place, byte for byte. Those exact drivers read sAGA's drive perfectly in R3Z. So the drivers were never the problem, and we went looking at what our code does around them.

Here is what we found, in the driver's own source.

When the ATA driver starts, it waits for the drive to answer. That wait is a ladder of retries with growing pauses, and the last thirty rungs are **one full second each**. A single wait can therefore take about **31 seconds** before it gives up. It is not stuck. It is counting.

And it does that wait more than once, because the driver always checks for a **second drive**. A PS2 has only one ATA connector, so there is never a second drive to answer. Every one of those checks runs the ladder all the way to the bottom.

Several 31-second waits in a row is a page that sits there for minutes.

**That is the "freeze".** It matches what the maintainer has been seeing on his own drive the whole time: several minutes of the bar sitting in the 40s, and then it finishes and works. sAGA gave it two minutes, which was completely reasonable, and it simply was not enough.

### What EXP20 changes

The ATA driver is now built from source instead of shipped as a prebuilt file, with one change: **when it checks for the second drive that cannot exist, it stops waiting after a moment instead of a full second per rung.** Worst case for that check drops from about 31 seconds to about 4.

**The real drive's wait is deliberately left exactly as it was.** A cold drive can honestly need several seconds to spin up and answer, and rushing that would trade a slow page for a drive that does not get detected at all. Only the wait for the drive that is not there got shortened.

Everything else in the driver is identical to the stock one.

### What to do

Open the **HDD (exFAT)** page.

- **Your games listing, quickly** means this was it.
- **Still slow but it finishes** means we found a real part of it and there is more of the same to trim.
- **Stops at a step number again** means the waiting was not the whole story, and the step number tells us where to look next.

**One more thing, and it costs nothing:** if it is still slow, please let it run for **ten minutes** before you power off. EXP19 was very possibly going to finish for you, and we would never have known.

### Where things honestly stand

Six explanations have been ruled out, every one of them by your photos: it is not memory, not your drive, not your adapter, not GPT support, not a stale driver file, and not the driver set. That elimination is what made this findable. Your step-45 photo is the reason we went and read the driver's source instead of swapping more files, and the answer was sitting in there.

Thank you for six builds' worth of patience.

---

## How to report

Please say **which build** (v1.0.2-dev-EXP20, from Settings then About), **which device**, your **console model and region**, and what you did. A photo helps.
