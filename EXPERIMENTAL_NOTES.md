# POPSLoader: Experimental Build 🧪

**This is an opt-in EXPERIMENTAL build. It is not a replacement for the public release, and it is not the rolling build either.** It exists so testers can try size optimizations in isolation, without them reaching anyone who did not ask for it. The public release (**1.0.1**) and the rolling test build are both untouched by anything here.

**How to tell you are running it:** the version reads **1.0.1-EXP2** (Settings, and the build info on the boot/credits screen). If it says plain 1.0.1, you are on the normal release, not this build.

**How to go back:** reinstall the latest entry on the Releases page. Nothing here changes your settings, your `POPS` folders, or your games, so switching back and forth is safe.

---

## What is different in this build

**Only one thing: it is smaller. About 19% smaller.**

| Build | Size |
| :--- | :--- |
| 1.0.1 (public release) | 1,715,300 bytes |
| **This build (EXP2)** | **1,396,900 bytes** |
| | **318,400 bytes smaller** |

No new features. No settings changes. No menu changes. Everything from 1.0.1 is here, working exactly as it shipped. We only removed weight that the PS2 was never using.

Two separate changes got us there, and they fail in **completely different ways**, so if something breaks we will know instantly which one did it.

### Change 1: a stripped internal helper (about 194 KB)

POPSLoader carries a small helper program inside itself, used at the moment it hands your game over to POPStarter. That helper was stored with about 900 KB of leftover developer information attached (symbol tables a PS2 never reads). We now strip that off. The helper's actual code is byte for byte identical, same entry point, verified.

**If this one were broken, you would see:** a game failing to launch, a black screen at the handoff, or a hang. **You would not see menu problems.**

### Change 2: dropped unused font machinery (about 124 KB)

POPSLoader uses a font library that, by default, loads support for **every** font format it has ever known (BDF, PCF, Type1, CFF, SVG, Windows FNT, and more). We only ever draw one built-in TrueType font. Those unused format handlers were about a third of all the program code in the build. Now only the TrueType parts get included.

**If this one were broken, you would see:** missing, garbled, or blank text in the menus. **You would not see launch problems.**

---

## What to test

Mostly, **use it normally**. If your games launch and you can read the menus, both changes are good.

- [ ] **Boot to the menu** from whichever device you normally launch POPSLoader from.
- [ ] **Can you read everything?** Game names, menu text, Settings, the footer button hints. This covers change 2. If text looks *fine*, it is fine.
- [ ] **Launch a PS1 game** on each device you use (USB, MX4SIO, MMCE, internal HDD in either format, SMB share). This covers change 1, and it is the important one.
- [ ] **Internal hard drive users, please be thorough.** Launch a game from the HDD list, both with your `POPSTARTER.ELF` on the HDD and with it elsewhere. Those paths lean on the helper program the most.
- [ ] **Try a translated language** (Settings, Startup, Language: French, German, Portuguese, Spanish, Italian). Accented characters exercise the font path that change 2 touched.
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
