# POPSLoader: Experimental Build 🧪

**This is an opt-in EXPERIMENTAL build.** The public release (**1.0.1**) and the rolling test build are untouched by anything here.

**How to tell you are running it:** open **Settings**, then **About**, and read the **Version** row: it says **v1.0.2-dev-EXP21**. A version with no EXP on the end is the rolling test build; no version at all means the public 1.0.1 release or older.

---

## EXP21: stop looking for a second drive that cannot exist

Two things worth trying, smallest first.

### First, and it costs nothing: let the build you already have run for ten full minutes

The maintainer's own drive takes about five minutes on the exFAT page and then works. If your drive is a little slower, two minutes was never going to be enough to see it finish. **On any recent build, open the HDD (exFAT) page and walk away for a full ten minutes before powering off.** If a game list appears, this was a very slow wait and not a freeze, and that changes everything we do next. This one test would tell us more than another build.

### What EXP21 changes

When the ATA driver starts, it checks the internal drive bay for **two** drives, a master and a slave, the way a PC hard-drive cable can carry two. A PlayStation 2's internal bay only ever holds **one**. So the driver has always been doing a second drive's worth of work against hardware that is not there, and that phantom second drive is the one piece of the startup that can trip over the part reading your real drive.

EXP21 simply stops looking for the drive that cannot exist.

That is the whole change. It is a deletion, not an addition, and it is correct regardless of whether it fixes the stall: there is genuinely no second drive to find.

### Honest odds

I will not oversell this the way EXP17 and EXP20 got oversold. This is a reasonable, safe change, and it might not be the fix. Here is the plain reasoning: wLaunchELF R3Z runs the exact same drive code on your exact drive and does **not** stall, which means either your adapter is not reporting a phantom drive at all (in which case this changes nothing for you), or it is and something else in our build is what tips it over. EXP21 removes one of the two things that would have to collide. If it works, good. If it stops at step 45 again, that is not a wasted result: it rules this out and points us at the other half.

It cannot make anything worse, and it does not touch your controller or sound.

### What to do

Open the **HDD (exFAT)** page.

- **Your games listing** means the phantom-drive work was the problem and we are done.
- **Stops at step 45 again** tells us the collision is elsewhere, and we look at the last remaining lead.

As before: if it is slow rather than stopped, please give it the full ten minutes before powering off.

### Where things honestly stand

Seven explanations have now been ruled out by your photos: not memory, not your drive, not your adapter, not GPT support, not a stale driver file, not the driver set, and not the busy-wait timing. What is left is a narrow timing question inside our own startup, and EXP21 tests the cleaner half of it.

---

## How to report

Please say **which build** (v1.0.2-dev-EXP21, from Settings then About), **which device**, your **console model and region**, and what you did. A photo helps.
