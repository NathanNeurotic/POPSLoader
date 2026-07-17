# POPSLoader: Experimental Build 🧪

**This is an opt-in EXPERIMENTAL build.** The public release (**1.0.1**) is untouched by anything here.

**How to tell you are running it:** open **Settings**, then **About**, and read the **Version** row: it says **v1.0.2-dev-EXP18**. A version with no EXP on the end is the rolling test build; no version at all means the public 1.0.1 release or older.

---

## EXP18: the first build that actually runs wLaunchELF R3Z's drive drivers

**sAGA, EXP17 was our mistake, not your hardware.** You spent six minutes on a build we told you matched R3Z. It didn't. Here is exactly what went wrong and what changed.

### What we got wrong

The internal drive uses four driver files together: the drive-system core, the FAT/exFAT filesystem, the USB reader, and the ATA reader. R3Z ships a specific combination of those four, and it works on your console.

Every attempt so far swapped **some** of them:

- **EXP12–15** took three of R3Z's four and kept our own stale ATA reader. → froze.
- **EXP17** took R3Z's ATA reader and kept our own three older ones. → froze (your 42%).

Neither build was ever R3Z's set. We kept saying "we're matching R3Z" while shipping combinations **nobody has ever shipped**, so of course they behaved in ways nobody had ever seen. Your 42% was not a wasted test: it proved the build we sent was not the build we thought we sent.

### What EXP18 is

**All four files, together, byte-for-byte identical to wLaunchELF R3Z v4.70.** Not "the same source." The same bytes, verified by checksum against R3Z's own released build:

| File | This build | Same as R3Z v4.70? |
| :--- | :--- | :--- |
| ATA reader | `16c5d9f0…` | yes |
| Drive-system core | `2ada1262…` | yes |
| FAT/exFAT filesystem | `597b23ad…` | yes |
| USB reader | `9b3ca260…` | yes |

The ATA reader is the one that had never been checked. Our build compiles against a PS2SDK snapshot from May that predates an upstream fix called *"atad: fix device probing"* — R3Z, OPL and the mainstream RiptOPL build all carry it; we never did. The old code resets the drive bus once, **assumes** the first drive is selected, then checks the second drive without telling the bus which drive should answer. On an aftermarket SATA adapter, which is what both affected testers use, that can simply stop, inside the driver's own startup, where nothing can interrupt it.

That fix was found by an independent audit that did the one check nobody else did: compare the **bytes** instead of the source.

### What to test

**Open the HDD (exFAT) page.** That is the whole test.

- **sAGA:** your 4TB GPT drive appearing and listing games is the win. This build also restores GPT support (the older drive-system core in the rolling build cannot read GPT at all). One honest caveat: drives over 2TB still report as 2TB, so keep games within the first 2TB for now.
- **Maintainer:** your drive should behave like it does on rolling, without the long stall.
- **Everyone:** this changes the drive drivers for **USB and MX4SIO too**. If either worked before and does not now, that is the single most important report you can make, and it is a one-step revert.

**If it still freezes:** then R3Z's exact drivers freeze in our build while working in R3Z's, which means the cause is something POPSLoader does around them, and we will say so plainly instead of inventing another theory. Either result is real information this time.

---

## How to report

Please say **which build** (v1.0.2-dev-EXP18, from Settings then About), **which device**, your **console model and region**, and what you did. A photo helps.
