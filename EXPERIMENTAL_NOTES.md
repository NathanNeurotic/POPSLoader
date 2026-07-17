# POPSLoader: Experimental Build 🧪

**This is an opt-in EXPERIMENTAL build.** The public release (**1.0.1**) and the rolling test build are untouched by anything here.

**How to tell you are running it:** open **Settings**, then **About**, and read the **Version** row: it says **v1.0.2-dev-EXP19**. A version with no EXP on the end is the rolling test build; no version at all means the public 1.0.1 release or older.

---

## EXP19: same drivers as EXP18, but the screen tells us where it stops

**sAGA: one button, one photo. That is the entire ask.**

EXP18 proved something important, even though it froze: it ran **wLaunchELF R3Z v4.70's exact four drive drivers**, verified byte-for-byte against R3Z's own released build. The same bytes that read your drive perfectly in R3Z froze in POPSLoader. So the drivers are cleared. Whatever is wrong is something POPSLoader does *around* them, and that is our problem to fix, not yours.

But EXP18 could only tell you "42%", because that build had no step numbers in it. That was our oversight: we removed the numbered steps from the rolling build for a good reason (they were writing to your memory card dozens of times and making the page crawl), and then built EXP17 and EXP18 on top of rolling, throwing away the one thing that was teaching us anything.

**EXP19 = EXP18's drivers + the numbered steps back.** The steps are now free: the memory-card writing that caused the slowdown is down to a single write, so nothing crawls.

### What to do

Open the **HDD (exFAT)** page once. Give it up to two minutes. Then photograph whatever is on screen.

- **A number between 43 and 50** tells us exactly which internal call stops, with R3Z's own drivers in place. That is information we have never had, and it points straight at the part of POPSLoader that is at fault.
- **Your games listing** means the driver set fixed it and we are done.
- **"No exFAT HDD detected"** after a few seconds means the freeze is gone and something smaller is left.

There is no wrong outcome here. Every one of them narrows it.

### Where things honestly stand

Five explanations have been ruled out, each by your photos: it is not memory, not your drive, not your adapter, not GPT support, and not the stale driver file we did (genuinely) have. That is real progress by elimination, even though it has not felt like it. What is left is small and it is on our side of the fence.

Your USB, for what it is worth, went from completely broken to working during the same stretch, and that was your reports too.

---

## How to report

Please say **which build** (v1.0.2-dev-EXP19, from Settings then About), **which device**, your **console model and region**, and what you did. A photo helps.
