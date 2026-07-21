# POPSLoader: Experimental Build 🧪

**This is an opt-in EXPERIMENTAL build. It is not a replacement for the public release, and it is not the rolling build either.** It exists so testers can try riskier changes in isolation, without them reaching anyone who did not ask for it. The public release (**1.0.1**) and the rolling test build are both untouched by anything here.

**How to tell you are running it:** open **Settings**, then **About**, and read the **Version** row: it says **v1.0.2-dev-EXP27**. The **Credits** page shows the same line at the bottom left, with the boot timing under it. A version ending in **-EXP27** = this build; any older EXP number = an older experimental, please update; plain **v1.0.2-dev** = the rolling test build; no version anywhere = the public 1.0.1 release or older.

**What the name means:** this build is the **rolling** build (1.0.2-dev) plus the experiments below, nothing missing.

**How to go back:** reinstall the latest entry on the Releases page. Nothing here changes your settings, your `POPS` folders, or your games, so switching back and forth is safe.

---

## New in EXP27: cover art stays inside the case frame

The maintainer's screenshot showed real cover art spilling out of the jewel-case frame (bottom-right), while the placeholder and disabled art sat correctly inside it. Confirmed by measuring the frame image and replaying the sizing math: the real cover was sized against a fixed screen box and anchored to the case's outer edge, so it overflowed the case's transparent cover window by 5px on the right on NTSC, 21px on PAL, and portrait covers ran 17px past the window bottom. EXP27 sizes and anchors the cover inside the case's actual window, measured from the frame image itself, so it scales with the case and stays contained on every video standard by construction. Placeholder and disabled art are untouched. One look at any game with cover art confirms it.

---

## EXP26: the loading-screen corruption is fixed

EXP25's maintainer test confirmed the two headline goals on real hardware: fast boot with the internal drive loading on demand from its own page, and the MX4SIO page working right after it. One cosmetic bug came with it: **severe visual corruption while the exFAT page loaded the drive**, clearing up the moment loading finished. That was ours: while the drive loaded in the background, the waiting loop flipped the screen every frame without drawing anything between flips, so the display alternated between two stale frames. EXP26 redraws the progress overlay properly on every frame instead, so the load now shows a steady, animated progress screen. Same fix applies to the brief wait the MX4SIO page does when the drive is still coming up.

Everything else is EXP25 unchanged, and the EXP25 test list below still applies. One extra ask this round: **launch an MX4SIO game** (not just the page). If POPSTARTER still comes up broken from an MX4SIO launch, that confirms the one remaining open issue (the launch handoff inherits the launcher's live system state, which only hurts MX4SIO because its SD card shares a bus with the pads and memory cards), and the candidate fix is already scoped.

---

## EXP25: fast boot is back, the internal drive loads on demand, and driver staging is two quick pastes

EXP24 proved its two big fixes on real hardware: the MX4SIO page scans again and the internal exFAT drive listed and launched a game. It also introduced one thing the maintainer rightly rejected (a 5 to 6 second black screen at boot for the internal drive stack) and exposed two launch-time problems (driver staging taking far too long, and an MX4SIO launch coming up broken). EXP25 keeps everything EXP24 proved and fixes what it got wrong.

**1. The boot black screen is back to normal.** The internal drive stack no longer loads at boot at all. Instead, the exFAT HDD page brings it up the first time you open it, in the background, with the screen alive and the progress counter visible while the drive spins up. This is the same arrangement OPL uses (we verified it in their source: they load the very same driver module mid-session on a background worker), so the pattern is proven on this exact hardware. The first visit to the exFAT page costs a few seconds while the drive wakes; every page after that is instant. If the drive cannot be brought up, the page says no drive was found and the rest of the program is unaffected.

**2. The two pages can no longer take each other down.** If you enter the MX4SIO page while the internal drive is still coming up, the page waits briefly for it to finish instead of piling its own driver load behind it. The old failure where one stuck load froze both pages at 42% is structurally gone.

**3. Driver staging at launch is now exactly what it should be.** Launching a game with Adaptive BDMA on used to sit "forever" on "Staging drivers for this device". The staging routine was writing every file three times over (a temp copy, a backup copy, and the final copy, because memory card renames are really copy-plus-delete) and running device probes it did not need. It now pastes the two driver files straight from inside the program to the memory card, writes the small marker file, and moves on. Same result on the card, a fraction of the writes. Staging is also safe to interrupt: if it ever fails partway, the next launch notices and re-stages cleanly.

**Unchanged, deliberately:** the matched driver set from EXP24 (the MX4SIO fix and the GPT-capable storage core), the APA partition boot path, and the launch handoff itself. The broken MX4SIO launch from the EXP24 test (POPSTARTER acting like it had bad modules) is NOT addressed in this build: the staged files were verified correct, and the leading suspect is that POPSTARTER inherits the launcher's live system state at launch. That fix touches a deliberate old design decision and gets its own build once the maintainer decides direction.

### The test list

1. **Boot time.** Check the Credits boot line. Expected: back to the normal fast boot, no "ata bdm stack" entry.
2. **Internal exFAT HDD page.** First open after boot: expected a few seconds of "Locating exFAT HDD..." with the screen alive (counter visible, no freeze), then the game list. Second open: instant. Launch a game.
3. **MX4SIO page.** Expected: scans and lists like EXP24 did. Try it both ways if you can: on a fresh boot directly, and right after opening the exFAT page.
4. **Adaptive BDMA staging speed.** Alternate a launch between two devices (so staging actually runs). Expected: "Staging drivers for this device" passes in a couple of seconds instead of sitting.
5. **USB, MMCE, memory card.** Expected: unchanged from EXP24 (USB and MMCE were both confirmed working there).

If something hangs, the one photo that answers everything is the frozen screen with its percent number and message.

---

## History

EXP24 fixed the two 42% hangs (mismatched MX4SIO driver vintage since mid July; the internal drive driver wedging when loaded late) and was hardware-confirmed for exFAT scan+launch and MX4SIO scan, but bought it with a 5 to 6 second boot-time drive load, which EXP25 replaces with the on-demand background load. EXP23's background-load attempt was actually the right mechanism sunk by two then-unknown bugs (a storage core that could not read GPT drives, and the mismatched MX4SIO driver); with both fixed in EXP24, EXP25 retries it clean. Older experiment notes live in the git history of this file.
