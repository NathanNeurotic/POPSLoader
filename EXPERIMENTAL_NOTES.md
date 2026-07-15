# POPSLoader: Experimental Build 🧪

**This is an opt-in EXPERIMENTAL build. It is not a replacement for the public release, and it is not the rolling build either.** It exists so testers can try one specific change in isolation, without it reaching anyone who did not ask for it. The public release (**1.0.1**) and the rolling test build are both untouched by anything here.

**How to tell you are running it:** the version reads **1.0.1-EXP1** (Settings, and the build info on the boot/credits screen). If it says plain 1.0.1, you are on the normal release, not this build.

**How to go back:** reinstall the latest entry on the Releases page. Nothing here changes your settings, your `POPS` folders, or your games, so switching back and forth is safe.

---

## What is different in this build

**Exactly one thing: it is smaller.** The program file dropped from about 1.72 MB to about 1.52 MB, roughly 11% smaller.

Nothing else changed. No new features, no settings changes, no menu changes. Everything from 1.0.1 is here exactly as it shipped.

**Where the space came from:** POPSLoader carries a small internal helper program inside itself, used at the moment it hands your game over to POPStarter. That helper was being stored with about 900 KB of leftover build information attached (developer symbol tables that a PS2 never reads). We now strip that off before packing it in.

**Why we still want it tested:** the removed data is provably never loaded by the console. We verified the helper's actual runtime code is byte for byte identical before and after, with the same entry point, and it passes every automated check. But that helper sits directly on the path that launches your games, and on this project hardware has the final say, not analysis. So we would rather have a handful of real launches confirm it than assume.

---

## What to test (the whole point)

Mostly just **use it normally and launch games**. If your games launch, the change is good.

- [ ] **Boot to the menu** from whichever device you normally launch POPSLoader from.
- [ ] **Launch a PS1 game** on each device you use (USB, MX4SIO, MMCE, internal HDD in either format, SMB share). This is the important one.
- [ ] **Internal hard drive users, please be thorough.** Launch a game from the HDD list, both with your `POPSTARTER.ELF` on the HDD and with it elsewhere. These are the paths that use the helper program most heavily.
- [ ] **Exit paths still work:** the Disc (DKWDRV) option, and exiting back to your launcher or the browser.
- [ ] **Anything that worked on 1.0.1 still works.** If something worked before you installed this and does not now, that is exactly the report we need.

**What a failure would look like:** a black screen when launching a game, or a hang at the handoff to POPStarter. If you see that, say so and we will drop this change immediately. It is a single, cleanly revertable commit.

## How to report

Please say **which build** (1.0.1-EXP1), **which device**, your **console model and region**, and what you did. A photo of any error screen helps, since the error text names the real reason on the second line.

If it all just works, that is a valuable report too. Say "EXP1 fine on USB and HDD" and that is enough.

---

## For the curious: why a separate build at all

Size work is easy to get wrong in ways that only show up on real hardware. This project has been burned once already: a compiler size optimization was shipped, a tester lost their USB device list, and it was reverted. That history is why this change is riding its own channel with one variable in it, instead of being folded into the rolling build alongside everything else. If this build misbehaves, there is exactly one suspect.
