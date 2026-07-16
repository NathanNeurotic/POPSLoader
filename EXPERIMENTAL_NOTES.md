# POPSLoader: Experimental Build 🧪

**This is an opt-in EXPERIMENTAL build.** It exists so testers can try riskier changes in isolation, without them reaching anyone who did not ask for it. The public release (**1.0.1**) is untouched by anything here.

**How to tell you are running it:** open **Settings**, then **About**, and read the **Version** row: it says **v1.0.2-dev-EXP16**. A version with no EXP on the end is the rolling test build; no version at all means the public 1.0.1 release or older.

---

## EXP16: this build is now the same as rolling again

**The storage-driver experiment is reverted. This build is identical to the current rolling test build; only the name differs.**

Here is the honest story, because the testers earned it.

Some builds back, the internal-drive support was switched from wLaunchELF R3Z's storage drivers to a current PS2SDK set. The reason looked sound: sAGA's 4TB drive uses GPT partitioning, R3Z's drivers do not understand GPT, and the SDK set does. On hardware it went the other way. sAGA's drive stopped loading entirely, and the maintainer's own drive, which is fine on rolling, took about five minutes of stalling on the experimental build before it gave up. Two drives, two consoles, both worse. The swap was a regression, so it is gone.

We also chased a memory theory: the drive driver allocates a large block at startup without checking whether it succeeded, and a failure there would wedge the console exactly the way testers saw. sAGA's photos killed that theory cleanly. The build asked for 200 KB up front, got it, and still froze. Memory is not the problem, so the guard built around that idea is gone too.

**What we actually learned, and it is a lot:** the freeze is inside the ATA driver's own startup, it is specific to certain SATA adapters, and R3Z's drivers cope with those adapters while the SDK's do not. The numbered steps (43 through 50) and the "it froze at step N" message that made all of this visible are in the rolling build now, permanently. That instrumentation is why we know any of this, and every photo you sent went straight into it.

**Nothing is lost for the 4TB GPT drive.** It needs GPT support without the driver regression, which means a properly patched driver rather than a wholesale swap. That is the next experiment, and it will arrive here as its own build with its own test ask.

**What to do with this build:** nothing special. It should behave exactly like rolling. If it does not, that alone is a bug worth reporting.

---

## How to report

Please say **which build** (v1.0.2-dev-EXP16, from Settings then About), **which device**, your **console model and region**, and what you did. A photo helps.
