# POPSLoader: Experimental Build 🧪

**This is an opt-in EXPERIMENTAL build. It is not a replacement for the public release, and it is not the rolling build either.** It exists so testers can try riskier changes in isolation, without them reaching anyone who did not ask for it. The public release (**1.0.1**) and the rolling test build are both untouched by anything here.

**How to tell you are running it:** the version reads **1.0.2-dev-EXP6** (Settings, and the build info on the boot/credits screen). If it says plain **1.0.1** you are on the public release, and if it says **1.0.2-dev** with no EXP on the end you are on the rolling build. Both are different builds to this one.

**What the name means:** this build is the **rolling** build (1.0.2-dev) plus the experiments below. It is not the 1.0.1 release plus experiments. Everything currently in rolling is in here too, including the menu and Settings cleanup. Earlier experimental builds were misleadingly named 1.0.1-EXP, which made this look like it was missing the newer work. It never was; the name was just wrong.

**How to go back:** reinstall the latest entry on the Releases page. Nothing here changes your settings, your `POPS` folders, or your games, so switching back and forth is safe.

---

## What is different in this build

**Two things: it is almost a quarter smaller, and you can optionally show both internal HDD pages at once.**

| Build | Size |
| :--- | :--- |
| 1.0.1 (public release) | 1,715,300 bytes |
| **This build (EXP6)** | **1,315,764 bytes** |
| | **399,536 bytes smaller (23%)** |

The size work removed weight the PS2 was never using. It changes no features, no settings and no menus: everything from 1.0.1 is here working exactly as it shipped. Three separate changes got us there, and they fail in **completely different ways**, so if something breaks we will know instantly which one did it.

The one actual new thing, the **Both** option for internal HDDs, is **off by default** and described further down.

*(The menu and Settings cleanup from the rolling build is in here too: shorter button bars, Credits moved into Settings, QWERTY keyboard default, and so on. That part is not what this channel is testing, but if you spot something odd there, say so anyway.)*

### Change 1: a stripped internal helper (about 194 KB)

POPSLoader carries a small helper program inside itself, used at the moment it hands your game over to POPStarter. That helper was stored with about 900 KB of leftover developer information attached (symbol tables a PS2 never reads). We now strip that off. The helper's actual code is byte for byte identical, same entry point, verified.

**If this one were broken, you would see:** a game failing to launch, a black screen at the handoff, or a hang. **You would not see menu problems.**

### Change 2: dropped unused font machinery (about 124 KB)

POPSLoader uses a font library that, by default, loads support for **every** font format it has ever known (BDF, PCF, Type1, CFF, SVG, Windows FNT, and more). We only ever draw one built-in TrueType font. Those unused format handlers were about a third of all the program code in the build. Now only the TrueType parts get included.

**If this one were broken, you would see:** missing, garbled, or blank text in the menus. **You would not see launch problems.**

### Change 3: dropped the JPEG decoder (about 82 KB)

POPSLoader was carrying a full JPEG decoder, which was **16% of all the program code in the build**. Nothing ever asked for it: cover art has always been looked up as `<GameName>.png`, and nothing in POPSLoader has ever searched for a `.jpg` file. The decoder could only ever kick in for a file *named* `.png` whose contents were secretly a JPEG, in other words a photo somebody renamed instead of converting.

**Cover art still works exactly as before. PNG (and BMP) are untouched.**

**The one case that changes:** if you have a cover named `GameName.png` that is really a renamed JPEG, it will now show the normal "no cover" placeholder instead of the picture. The fix is to open it and re-save it as an actual PNG. If your covers are real PNG files (they almost certainly are), you will not notice anything.

**If this one bothered you, you would see:** one specific cover missing, with everything else fine. **No launch problems, no text problems.**

---

## Also in this build: both internal HDD pages at once (NEW, opt-in, off by default)

Until now the two internal-hard-drive pages were an either/or: *Settings, Device List, Internal HDD* let you pick **APA / PFS** or **exFAT**, and the one you did not pick vanished from the device list. R3Z3N pointed out they can happily coexist, and he was right, so that setting now has a third choice: **Both**.

**Nothing changes unless you choose it.** The default is still **APA / PFS**, and an existing install keeps whatever it had. Pick **Both** and the device list simply shows both HDD entries.

**Why this was safe to do:** the two pages already shared one internal driver. A change back in June put APA/PFS and exFAT on a single shared ATA driver (with the exact one-second settling pauses R3Z3N described), because loading two copies of it was what caused the old 42% scan freeze. So "Both" only stops hiding a page that already worked. No driver code was touched for this.

**If you turn Both on, please test this specific order:** cold boot, open **HDD (exFAT) FIRST**, let it list your games, back out, and then open **HDD (PFS)**. That exact sequence was impossible before, so it is the one genuinely new situation in this build. If PFS then hangs on "Loading HDD modules", shows "HDD not usable", or lists nothing, say so, that is exactly the report worth having. Power-cycle between attempts: a failed HDD load is remembered for the rest of that boot, so retrying without a reboot is not a second try.

**If you leave it on APA / PFS** (the default), nothing about your setup changed at all.

---

## Also in this build: USB, for the two people it has never worked for (NEW)

**If your USB drive already works, skip this section. Nothing here changes anything for you.**

Two testers get **"No USB backend detected"** and an empty USB list, on hardware where wOPL and wLaunchELF browse the same drive off the same port with no trouble. That is our bug, not their console and not their drive. Two separate attempted fixes have now shipped and neither one moved it, so this build stops guessing and does two things instead.

**1. It says what actually went wrong.** Until now the USB error blamed the drive no matter what the real cause was, because the loader threw away the result codes of every USB driver it loads. It genuinely could not tell "a driver failed to start" apart from "the drivers are fine, no drive turned up". Those need completely different fixes, and we have been unable to tell which one we were even looking at. The error now carries a short line in square brackets, like `[modules OK, no drive seen]` or `[usbd failed (id -1, rc -1)]`.

**If you get the USB error, a photo of that bracket line is the single most useful thing you can send us.** It is the first real information this bug has ever produced.

**2. It waits a lot longer before giving up.** POPSLoader looked for a USB drive for about two seconds and then quit, permanently, for the rest of that boot. wLaunchELF never quits: it keeps re-checking the whole time you sit in its file browser, which is very likely why the same drive works there and not here. This build keeps looking for about twelve seconds and shows a "Looking for USB drive... (3/12)" counter while it does. If your USB already works you will never see the counter, because it stops the moment it finds the drive.

**If this fixes it for you, that tells us the drive was simply slow to appear and we were impatient.** If you still get the error after the full count, the bracket line tells us which half of the problem to go after. Either result is a real answer, which is more than we have had so far.

---

## Also in this build: boot timings on the Credits screen (NEW, nothing to do)

**This changes nothing about how POPSLoader works. It just shows a number.**

POPSLoader shows a black screen for a while when it starts. That is not the PS2 being slow: it is POPSLoader loading its drivers, and the screen is not switched on until every driver has finished. We want to move the welcome picture and the startup sound to the front, so they cover that wait instead of following it. Before changing anything in the startup order, which is the easiest part of the program to break, we want to know where the time actually goes.

So this build measures itself. Open **Settings** and then **About** and then **Credits**, and under the small grey build line there is now a second grey line like this:

`boot 4820ms (slowest: ds34usb+ds34bt load +2100ms)`

That is how long the black screen lasted, and which driver was the worst offender.

**If you can, please send a photo of those two grey lines.** Different consoles and different attached hardware will give very different answers, and that is exactly what we want to know. There is nothing to turn on and nothing to configure.

(Honest note: the loader has been able to measure this since long before now, but the numbers were only ever sent to a debug output that is switched off in the builds we give you. So they were collected and thrown away every single boot. Same for the USB error above. We are fixing that habit.)

---

## What to test

Mostly, **use it normally**. If your games launch, you can read the menus, and your covers show, the size work is good.

- [ ] **Boot to the menu** from whichever device you normally launch POPSLoader from.
- [ ] **Can you read everything?** Game names, menu text, Settings, the footer button hints. This covers change 2. If text looks *fine*, it is fine.
- [ ] **Launch a PS1 game** on each device you use (USB, MX4SIO, MMCE, internal HDD in either format, SMB share). This covers change 1, and it is the important one.
- [ ] **Internal hard drive users, please be thorough.** Launch a game from the HDD list, both with your `POPSTARTER.ELF` on the HDD and with it elsewhere. Those paths lean on the helper program the most.
- [ ] **Try a translated language** (Settings, Startup, Language: French, German, Portuguese, Spanish, Italian). Accented characters exercise the font path that change 2 touched.
- [ ] **Do your covers still show?** Scroll the game list with cover preview on. This covers change 3. If a cover vanished, that file is a renamed JPEG rather than a real PNG; re-saving it as PNG fixes it, but please tell us either way.
- [ ] **Exit paths:** the Disc (DKWDRV) option, and exiting back to your launcher or the browser.
- [ ] **One cosmetic thing worth a glance:** text weight. Dropping the unused font machinery also drops an automatic hinting step. Our font should not need it, but if the text looks noticeably thinner, blurrier, or just *different* from 1.0.1, that is worth reporting even though it is only cosmetic.

**Anything that worked on 1.0.1 and does not work here is exactly the report we need.** Every change here is a single, cleanly revertable commit, so any one of them can be dropped on its own.

## How to report

Please say **which build** (1.0.2-dev-EXP6), **which device**, your **console model and region**, and what you did. A photo helps, especially for anything text related.

If it all just works, that is a valuable report too. "EXP6 fine on USB and HDD, text and covers look normal" is genuinely all we need.

---

## For the curious: why a separate build, and why not just compress it

Size work is easy to get wrong in ways that only show up on real hardware. This project has been burned once already: a compiler size optimization was shipped, a tester lost their USB device list, and it was reverted. That is why these changes ride their own channel with clearly separable symptoms, instead of being folded into the rolling build alongside everything else.

A fair question is why we do not simply compress the art and the scripts. We tested it: the whole program file is **already** compressed as a unit when it is built, with a compressor stronger than zlib. Compressing the parts first actually made the final file **bigger** (the outer compressor cannot re-squeeze already-squeezed data, and you pay for the extra unpacking code). The art is also PNG, which is already compressed internally, so it gains about 3% and nothing after packing. That is why this work removes unused things instead of compressing used ones.
