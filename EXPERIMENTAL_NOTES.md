# POPSLoader: Experimental Build 🧪

**This is an opt-in EXPERIMENTAL build. It is not a replacement for the public release, and it is not the rolling build either.** It exists so testers can try size optimizations in isolation, without them reaching anyone who did not ask for it. The public release (**1.0.1**) and the rolling test build are both untouched by anything here.

**How to tell you are running it:** the version reads **1.0.1-EXP3** (Settings, and the build info on the boot/credits screen). If it says plain 1.0.1, you are on the normal release, not this build.

**How to go back:** reinstall the latest entry on the Releases page. Nothing here changes your settings, your `POPS` folders, or your games, so switching back and forth is safe.

---

## What is different in this build

**Only one thing: it is smaller. Almost a quarter smaller.**

| Build | Size |
| :--- | :--- |
| 1.0.1 (public release) | 1,715,300 bytes |
| **This build (EXP3)** | **1,314,708 bytes** |
| | **400,592 bytes smaller (23%)** |

No new features. No settings changes. No menu changes. Everything from 1.0.1 is here, working exactly as it shipped. We only removed weight that the PS2 was never using.

Three separate changes got us there, and they fail in **completely different ways**, so if something breaks we will know instantly which one did it.

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

## What to test

Mostly, **use it normally**. If your games launch and you can read the menus, both changes are good.

- [ ] **Boot to the menu** from whichever device you normally launch POPSLoader from.
- [ ] **Can you read everything?** Game names, menu text, Settings, the footer button hints. This covers change 2. If text looks *fine*, it is fine.
- [ ] **Launch a PS1 game** on each device you use (USB, MX4SIO, MMCE, internal HDD in either format, SMB share). This covers change 1, and it is the important one.
- [ ] **Internal hard drive users, please be thorough.** Launch a game from the HDD list, both with your `POPSTARTER.ELF` on the HDD and with it elsewhere. Those paths lean on the helper program the most.
- [ ] **Try a translated language** (Settings, Startup, Language: French, German, Portuguese, Spanish, Italian). Accented characters exercise the font path that change 2 touched.
- [ ] **Do your covers still show?** Scroll the game list with cover preview on. This covers change 3. If a cover vanished, that file is a renamed JPEG rather than a real PNG; re-saving it as PNG fixes it, but please tell us either way.
- [ ] **Exit paths:** the Disc (DKWDRV) option, and exiting back to your launcher or the browser.
- [ ] **One cosmetic thing worth a glance:** text weight. Dropping the unused font machinery also drops an automatic hinting step. Our font should not need it, but if the text looks noticeably thinner, blurrier, or just *different* from 1.0.1, that is worth reporting even though it is only cosmetic.

**Anything that worked on 1.0.1 and does not work here is exactly the report we need.** Both changes are single, cleanly revertable commits.

## How to report

Please say **which build** (1.0.1-EXP2), **which device**, your **console model and region**, and what you did. A photo helps, especially for anything text related.

If it all just works, that is a valuable report too. "EXP2 fine on USB and HDD, text looks normal" is genuinely all we need.

---

## For the curious: why a separate build, and why not just compress it

Size work is easy to get wrong in ways that only show up on real hardware. This project has been burned once already: a compiler size optimization was shipped, a tester lost their USB device list, and it was reverted. That is why these changes ride their own channel with clearly separable symptoms, instead of being folded into the rolling build alongside everything else.

A fair question is why we do not simply compress the art and the scripts. We tested it: the whole program file is **already** compressed as a unit when it is built, with a compressor stronger than zlib. Compressing the parts first actually made the final file **bigger** (the outer compressor cannot re-squeeze already-squeezed data, and you pay for the extra unpacking code). The art is also PNG, which is already compressed internally, so it gains about 3% and nothing after packing. That is why this work removes unused things instead of compressing used ones.
