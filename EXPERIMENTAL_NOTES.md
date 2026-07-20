# POPSLoader: Experimental Build 🧪

**This is an opt-in EXPERIMENTAL build.** The public release (**1.0.1**) and the rolling test build are untouched by anything here.

**How to tell you are running it:** open **Settings**, then **About**, and read the **Version** row: it says **v1.0.2-dev-EXP23**. A version with no EXP on the end is the rolling test build; no version at all means the public 1.0.1 release or older.

**This build is Rolling + one new thing.** Everything on the current rolling test build is in here (the working MX4SIO / MMCE / boot behavior, all the latest translations), plus the new exFAT change below. So testing it against rolling is apples-to-apples.

---

## EXP23: the internal exFAT / GPT drive, done the way the other launchers do it

The last exFAT attempt (EXP22) read the 4TB GPT drive but broke MX4SIO, MMCE, and boot time, because it forced the drive driver up at startup in a way that stepped on everything else. That was pulled back. This is the real fix.

We studied how wLaunchELF R3Z, Open-PS2-Loader, and NHDDL all support the internal exFAT drive **alongside** MX4SIO, MMCE, and USB without breaking anything. They all do the same thing: they bring the drive driver up **only when you open the drive page**, and they let the rest of the system keep running while it comes up. Loading it at startup, or loading it in a way that freezes the screen, is exactly what we were doing wrong.

**EXP23 loads the internal-drive driver on a background worker while the screen stays live** — the same approach Open-PS2-Loader uses. Nothing loads at startup, nothing else's driver is swapped, and the internal drive is kept completely separate from the memory-card-port devices (MX4SIO / MMCE), so bringing it up **cannot** touch them.

### What to test (the whole point of this build)

Please exercise **every** device in one session and report anything off, not just the exFAT drive:

1. **USB** page + launch a game
2. **MX4SIO** page — confirm **no ~40% hang / freeze**
3. **MMCE** page, then **launch a game** — confirm it launches cleanly (no POPSTARTER problems)
4. **Memory card** game
5. **Internal PFS / APA HDD** game (if you have one) — confirm normal HDD launching still works
6. **The 4TB GPT exFAT** page — this is the new part

For the exFAT page: it should either come up with your games, or, if something is still off, show a normal "no drive" result after a short wait. **It should not freeze the console.** If it does anything unexpected, a photo of the screen helps.

### Honest note

This is grounded in three shipping programs that already do exactly this, not a guess. The important guarantee: MX4SIO, MMCE, memory card, and PFS/APA are on separate paths and are byte-for-byte the same as rolling, so this build cannot regress them — if the exFAT page still needs another pass, the other five devices are safe regardless.

---

## How to report

Please say **which build** (v1.0.2-dev-EXP23, from Settings then About), **which device**, your **console model and region**, and what you did. A photo helps.
