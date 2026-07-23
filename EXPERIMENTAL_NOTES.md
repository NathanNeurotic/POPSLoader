# POPSLoader: Experimental Build 🧪

**This is the opt-in EXPERIMENTAL channel.** It exists so testers can try riskier changes in isolation, without them reaching anyone who did not ask for it. The public release (**1.1.0**) and the rolling test build are both untouched by anything here.

**How to tell you are running it:** Settings, then About: the Version row reads **v1.1.1-dev-EXP55**. The check is simple: a version ending in **-EXP55** = this build; **-EXP54** or lower = an older experimental, please update; plain **v1.1.1-dev** = the rolling build; **v1.1.0** = the public release.

**File size check:** if *About* does not show EXP54, the file on your card was not replaced.

**How to go back:** reinstall the latest entry on the Releases page. Nothing here changes your settings, your `POPS` folders, or your games, so switching back and forth is safe.

---

## New in EXP55: devices are now asked for BY NAME

**This is the fix the maintainer asked for at the very start, and it is the structural one.**

**What was wrong.** POPSLoader identified your drives by *slot number* -- "device 0", "device
1" and so on. Those numbers are handed out in the order things happen to connect, and they are
shared by every kind of drive. So "the MX4SIO is device 1" could quietly stop being true, and
the MX4SIO page would faithfully list whatever was actually sitting in that slot -- your
internal drive.

**What changed.** The PlayStation 2 SDK gives every drive a proper name: **`mx4sio0:`**,
**`ata0:`**, **`usb0:`**. Ask for `mx4sio0:` and the system can only ever hand back an MX4SIO
card -- it checks the drive's own identity, not its position in a queue. POPSLoader now asks by
name. The old slot-number search is kept only as a fallback for the case where a named device
has not appeared yet, and it is skipped entirely the moment a named one answers.

These names have been available in the build the whole time. We simply were not using them.

**This should also fix cover art.** Art is looked for in the `ART` folder *of the drive the game
came from*. When the page resolved to the wrong drive, we searched the wrong drive's `ART`
folder -- which is exactly why `Soul Blade_COV.png` did not load despite being correctly named
and correctly placed. `mx4sio0:/POPS/` and `mx4sio0:/ART/` are guaranteed to be the same card.

**What to test on EXP55:**
- **MX4SIO must list the MX4SIO card**, never the internal drive. Same for USB and the internal
  exFAT drive -- each page shows its own device only.
- **Cover art:** with a correctly named cover such as `Soul Blade_COV.png` in the card's `ART`
  folder, it should now appear.
- **Rescan (R1) and leaving/re-entering a page** should keep working rather than reporting the
  device missing. If the earlier "no MX4SIO detected" was the slot search losing track, this
  removes the cause; if it persists, it is something else and worth saying.
- Nothing should vanish: if a device listed before, it must still list.

**Still open:** the brief pause when pressing START on a game list, and DKWDRV's exit option.

---

## New in EXP54: found the actual thing that was freezing the list

**EXP53 moved cover loading into the background and the list still froze. This is why.**

There were **two** things reading the card while you navigated, and I only moved one of them.
The second was the per-game description file (the `.txt` that goes with a cover). It was still
being read on the drawing thread, once or twice for every new title, in the same big `ART`
folder -- and looking for a file that is not there is the slow case. That is the freeze.

Your report is what pinned it: the screen was **completely static, even long titles stopped
scrolling**. That means drawing itself was stopped, not just input -- so something was still
blocking on that thread after the covers were moved off it. And it happened only on MX4SIO and
USB, the two devices with a big `ART` folder, never on the internal drive, APA or SMB.

**What changed.** The description file is no longer read while you navigate. It is now read
only *after* a cover has actually loaded -- at which point that folder entry is already in hand
and the read is cheap. A game with no cover never pays for it at all, so a card with no art
(which is your case) now does **zero** card reads per title instead of two slow ones.

**Nothing was added to do this.** It is one read removed from the drawing path.

**A guard against this class of bug.** Four builds in a row missed this because every one of
them only looked at the cover loader. There is now an automatic check that selecting a game
performs **no** blocking card read of any kind -- not an image, not a text file. It was
verified to fail against EXP53 (it caught three reads) and pass here, so this cannot silently
come back.

**What to test on EXP54:**
- **MX4SIO and USB with cover art ON.** First page entry and moving between titles should no
  longer freeze. This is the whole point.
- If you have *Game details* switched on, try it both ways.
- Drop in one correctly named cover (`<game name>_COV.png` in the device's top-level `ART/`)
  and confirm it still appears after you settle on that game.

**Honest caveat:** this fully explains the freeze if *Settings, Game List, Game details* is
switched **On**. If you have it **Off**, that code was already being skipped and something
else is blocking -- in which case the next build stops guessing and reports where the frame
actually stalls.

**Still not fixed:** MX4SIO reporting "no MX4SIO detected" after a rescan until you unplug and
replug, and DKWDRV's exit option. Both are next.

---

## New in EXP53: background cover loading, second attempt

**The art stutter is the target. This is the fix, rebuilt carefully after the last attempt would not boot.**

**What was wrong.** Looking for a cover happens on the same thread that draws the screen, so
while the console asks the card "is this picture here?", the screen is frozen. On a folder
shared with OPL, holding thousands of files, a lookup that comes back **no** is the slowest
possible answer, because the card has to be read to the end to be sure. That is the hang.

**What changed.** Cover lookups now happen in the background. The list draws immediately and
never waits. This is what OPL does, and it is why OPL is instant with the same folder.

**Why this should boot when the last attempt did not.** EXP49 introduced this and **booted**.
EXP51 added one small follow-up written in C, and that build black-screened. The program code
in EXP53 is **byte-for-byte the same as EXP49** -- the follow-up has been rewritten in the
script layer instead, where it cannot affect startup.

**Also added: a "Loading art..." line.** While a cover is being fetched, the box says so.
A silent empty box for a second reads as broken, and a user who thinks it is broken stops
waiting. It only appears while a fetch is actually in progress.

**The bug it also fixes.** Leaving a game list mid-fetch (pressing START, launching, backing
out) used to leave the loader jammed, and **covers would stop appearing for the rest of the
session**. It now clears itself.

**What to test on EXP53:**
- **Does it boot?** That is the first and most important question. If it black-screens, stop
  and go back to EXP52; that tells us the background loading itself is at fault, not the C
  follow-up, and it is the last thing I need to know.
- **USB with cover art ON:** first page entry and moving between titles should no longer hang.
- **MX4SIO with cover art ON:** same.
- Drop in one correctly named cover (`<game name>_COV.png` in the device's top-level `ART/`
  folder) and confirm it appears shortly after you stop on that game.
- Move onto a game, press **START** immediately, come back, keep browsing: covers must still
  appear.

**Known and NOT fixed here:** after a rescan (R1) or leaving and re-entering the MX4SIO page,
the card can report "no MX4SIO detected" until it is physically unplugged and replugged.
That is a separate device bug with a clean reproduction, and it is next.

---

## EXP52: EXP49 and EXP51 are removed -- EXP51 would not boot

**EXP51 black-screened on boot. Both it and EXP49 are completely gone from this build.**

EXP49 introduced background cover loading, which is the right fix for the MX4SIO stutter and
is how OPL stays instant with a shared `ART` folder. EXP51 added a small follow-up to it.
EXP51 does not boot, so both are out until the fault is found and fixed properly.

**EXP52 is EXP48's code exactly** -- every source file is byte-identical; only the version
stamp differs. EXP48 is a build that boots.

**What this means for you right now:**
- Booting is restored.
- The **MX4SIO cover stutter is back**, because the fix for it was in EXP49. If you want a
  smooth list today, set *Settings, Game List, Cover art* to **Off**.
- Everything else still works: the MX4SIO page fix (EXP41), the cover-art setting (EXP42),
  the exFAT freeze messages (EXP43), and the game-details fix (EXP48).

**The goal has not changed:** covers in a shared `ART` folder, loading instantly, exactly as
OPL does it. That needs the background loading from EXP49, done correctly. Two faults in that
code have already been identified: the worker's memory was reserved as a fixed block that
grows the program image, and its priority was set higher than the main program rather than
lower. Both are fixable without changing the approach.

**What to test on EXP52:** only that it boots and behaves like EXP48. That confirms the fault
was in EXP49/EXP51 and nothing older, which is what decides where to look next.

---

## New in EXP48: one more thing was reading your card on every single move

**If you have *Game details* turned ON, read this.** Separate from the cover picture, the
loader also looks for a `.txt` description file next to it. That lookup was checking
**nothing** first -- it did not remember folders it already knew were missing, and it did not
remember files it had already failed to find. So it went to the card **every time you landed
on a game, including games you had already visited**, which the cover lookup never did.

It also ran *before* the cover lookup, which is why none of the last three attempts touched
it: they all only changed the cover code.

It now uses the same two rules the covers use: skip a folder already known to be missing, and
remember a file that was not there so it is never asked for twice. **This adds no new reading
of your card, it only removes reading.**

**If you have *Game details* set to Off** (the default), this changes nothing for you, because
that whole path was already skipped.

**This still does not fix the main stutter.** That fix is the background-loading change
described under EXP47 below, and it is being built properly rather than rushed.

**What to test on EXP48:** if you use *Game details*, moving around the list should be
noticeably less heavy, especially going back to games you already looked at. If you do not
use it, just confirm nothing got worse.

---

## New in EXP47: we found the real cause of the cover stutter (and undid a wrong fix)

**EXP46 is undone.** It tried to read your whole `ART` folder once instead of looking for each
cover as you moved. Measuring the console's actual behaviour afterwards showed that reading a
folder that size costs one round-trip to the card **per file in it** -- so on your shared OPL
art folder that is thousands of round-trips, which is worse than what it replaced. It is out.

**You were right: there is no reason to scan the art at all.** The loader is back to doing
exactly what you described, and what OPL does: look for one file, load it if it is there, skip
it if it is not.

**So why is it slow?** Not because of *how many* times we look. Because of *where* we look from.
The lookup happens on the same thread that draws the screen, so while the card is being asked,
the picture on your TV is frozen. On a small folder that is invisible. On your shared OPL art
folder, a single "is this file here?" that comes back **no** takes roughly half a second,
because the console has to read the folder to the end before it can answer. One of those per
title is all it takes, which is why every attempt at making it look *fewer* times changed
nothing.

**OPL actually looks up MORE art than we do** (a picture for every row on screen, not just the
selected one) and never stutters, because it does the looking on a **background thread** and
draws a placeholder in the meantime. That is the entire difference between the two programs
here, and it is the fix.

**Honest status:** that background-loading change is the next thing, and it is a real change
rather than a one-line tweak, so it is not being rushed into this build after three misses in
one night. **EXP47 does not fix the stutter.** It removes a change that was probably making
things worse and puts the simple behaviour back.

**What to test on EXP47:** only that nothing got worse. With cover art **off**, MX4SIO should
be smooth. With it **on**, expect the same stutter as EXP43/EXP45 -- if it is noticeably
*worse* than that, say so, because that would be important. Everything else in the build (the
MX4SIO page fix, the cover-art setting, the exFAT freeze messages) is untouched.

---

## ~~New in EXP45: EXP44's cover-art change is reverted~~ (EXP46 also reverted; see EXP47)

**EXP44 did not work and is undone.** The MX4SIO stutter with cover art on is still there, and EXP44's attempt at it is out of this build. The cover code is back to exactly what EXP43 had.

**Why it is being pulled rather than adjusted.** EXP44 made the loader read the whole `ART` folder once and remember its contents. That same approach was tried before, in EXP34, and removed in EXP35 because it caused stutter and out-of-memory crashes on MX4SIO. Putting it back was a mistake, and the honest read is that this technique has now been implicated twice on this exact hardware. It stays out.

**Where this actually stands: the cause is still not known.** Two separate fixes have now been aimed at this and both missed. Rather than guess a third time, the code is back to its last known state while the cause is properly investigated. The current leading idea, which is **not yet confirmed**, is that looking for a cover that is not there is the slowest possible operation on this kind of card, and it happens while the screen is trying to draw. If that turns out to be right, the fix is to look for covers **in the background** instead of making the list wait, which is what OPL does.

**What to test on EXP45 (MX4SIO):**
- **With cover art OFF**, browsing should be smooth. Please confirm this is still true.
- **With cover art ON**, expect the stutter to still be there. That is not a regression from EXP44, it is EXP43's behaviour restored. Confirming it is unchanged (not worse) is genuinely useful.
- Everything else in this build (the MX4SIO page fix, the cover-art setting, the exFAT freeze messages) is untouched and still worth testing.

**One question that would settle a lot:** does your MX4SIO card have an `ART` folder at the root, even an empty one? If there is no `ART` folder at all, the loader is supposed to skip cover lookups entirely, and the fact that it still stutters would tell us something important.

---

## ~~New in EXP44: cover art is fast again on MX4SIO~~ (REVERTED in EXP45)

**The report:** MX4SIO stutters when the list first appears and again on every title you move to, with cover art on. Turn cover art off and it is perfectly smooth. It never used to do this.

**That is exactly right, and the cause was ours.**

**What was happening.** Cover art used to live next to your game files, in the same `POPS` folder the loader had just read to build the list. Because it had just read that folder, finding a picture in it was almost free, and there was only ever **one** file to look for.

When art moved to its own `ART` folder, that stopped being true. The loader now had to go read a **different** folder, and it did that **for every single game you moved to**. Worse, when a picture is *missing*, the console has to read the folder **all the way to the end** to be sure it is not there, while finding one lets it stop early. Multi-disc games looked twice. On an SD card over the memory card port, which is a slow connection, that adds up to exactly the stutter you described.

Turning art off skipped all of it, which is why it looked fine, and that was the clue that settled it.

**What changed.** The loader now reads the `ART` folder **once**, remembers what is in it, and after that every game is answered instantly from memory. Present or missing, there is no more folder reading while you navigate. Pictures that exist still load exactly as before.

**Why this is not a repeat of an earlier attempt.** A few builds back we tried reading the folder once and it caused out-of-memory crashes, so it was pulled out. That crash was real, but the reason was that the folder reading built a large amount of temporary data with no limit on it. It comes back now with that limit in place, and the temporary data is thrown away immediately. If a folder is unusually large the loader simply goes back to the old behaviour instead, so it can never crash the way it did before.

**What to test on EXP44:**
- **MX4SIO with cover art ON:** browse your list and hold on titles. The stutter on first list and on each title should be gone.
- **Your pictures still show.** Same folder, same names, nothing to change on your card.
- **Games with no picture** should now be *instant*, showing the plain empty case with no pause at all. This was the slowest case before.
- **Add a new cover while the loader is running,** then press **R1** to refresh: it should be picked up.
- **USB, MMCE and the internal drive** should be unchanged.

---

## New in EXP43: if the internal drive freezes, the screen now tells us where

**sAGA, this one is for you, and it is the important part of this build.**

**Nothing about the drive fix changed.** EXP40's "phantom slave" fix is in this build exactly as it was. What changed is what happens **if it does not work**.

**The problem with the last three builds.** EXP38, EXP39 and EXP40 all tried to fix the internal exFAT freeze, and all three asked you to boot, and none of them could tell us anything when they failed. The screen just sat on **"Locating exFAT HDD POPS folder..."** forever. That single message covered about a dozen separate internal steps, so "it froze" narrowed nothing down. Three of your test rounds produced no usable information, and that is our fault, not yours.

We had solved this once. Back in EXP11 that step was split into numbered sub-steps so a frozen screen named the exact stuck call. When the device layer was rebuilt a few builds ago, that got quietly dropped and nobody noticed.

**What changed.** It is back, and better placed. The bring-up now paints a specific message **before** each step that can hang:

- **exFAT step 1: starting the drive**
- **exFAT step 2.N: checking massN:**
- **exFAT step 3.N: identifying massN:**
- **exFAT step 4: reading the device list**

A frozen console cannot redraw the screen, so whatever message is showing when it stops **is** the answer. It tells us which call hung and, for the numbered ones, which drive slot.

**What to do (sAGA, one boot):** open the **HDD (exFAT)** page and give it up to two minutes, since some failure paths are slow rather than truly stuck.

- **If it lists your games:** the phantom-slave fix worked. That is the win we have been chasing, please say so.
- **If it freezes: photograph the screen.** The message on it, word for word including the number, is the whole diagnosis. That single photo is worth more than every report on the last three builds combined.
- **If you see "No exFAT HDD detected" after a few seconds:** that is a clean answer too, not a freeze. Tell us.

Also included, unchanged from the previous builds: the **MX4SIO page fix** (EXP41) and the **cover art setting** (EXP42), both described below.

---

## New in EXP42: cover art is a saved setting now

Two small interface changes. **EXP41's device fix is included in this build**, so if you have not tested EXP41 yet, testing EXP42 covers both. The EXP41 section below is still the important one.

**Cover art is now in Settings.** It used to be the **Square** button on a game list, which meant it reset to on every time you rebooted and there was nothing on screen telling you the button existed. It now lives in **Settings, Game List, Cover art**, defaults to **On**, and is saved with the rest of your settings. Turning it off shows the plain empty case instead of loading each game's picture, which is a little quicker on a big list. **Square now does nothing on a game list.**

**The "No cover. Looked for:" line is gone.** When a game had no picture, the box used to print the exact path it had checked. That was added as a self-check aid back when you could choose where covers lived; EXP35 locked that location down, so the line had stopped earning its space.

**What to test on EXP42 (interface):**
- **Settings, Game List, Cover art** turns pictures on and off, and the game list changes as soon as you save without needing to leave Settings.
- Set it to **Off**, save, reboot: it should still be **Off**. Then set it back to **On** and confirm that sticks too.
- **Reset Defaults** puts it back to **On**.
- A game with no picture shows the plain empty case and **no path text** underneath.
- Your existing settings still load normally after updating (this adds a new saved value, so an older settings file simply defaults cover art to On).

---

## New in EXP41: the MX4SIO page was showing the internal drive's games

**One bug, one fix, nothing else changed.** This build deliberately contains a single change so there is only one variable to judge.

**The report.** Boot POPSLoader from a memory card, open the internal exFAT page and it works, then plug in an MX4SIO card and open the MX4SIO page: it lists the **internal drive's** games, not the SD card's. Re-scanning does not help.

**What was actually wrong.** When POPSLoader asks the system what storage is connected, each drive comes back with a small set of numbers attached. EXP36 (a few builds ago) started using one of those numbers as "which drive slot is this." That number is not a drive slot. It is a partition-type marker, and for a whole drive it is always **zero**, for every device, on every console.

So the internal drive said zero, the SD card said zero, and both got filed as "slot 0". Slot 0 is whatever was plugged in first, which when you boot with the internal drive present is the internal drive. The MX4SIO page then faithfully listed slot 0, which was the HDD. It was not random or flaky: it was the same wrong answer every single time, which is exactly why re-scanning never helped.

The same mistake had a second symptom worth mentioning: on a drive using the older MBR partition style, that number is the filesystem-type byte instead, so a drive could be filed as a slot that does not exist and **disappear from its page entirely**.

**The fix.** POPSLoader now asks each drive slot directly what it is, which is the reliable answer and the one the loader used before EXP36. The reason EXP36 changed this was speed: the old method could stall the menu on a drive that was still waking up. That protection is kept, because slots that are not mounted yet are skipped before anything slow happens, so we only ask the slots that are genuinely ready.

**A note on how this got through.** The automated test that was supposed to cover this made up numbers the real hardware never produces, so it passed while the real thing was broken. That test has been rewritten to use the real values, and it now fails if anyone reintroduces the mistake.

**Honest status, please read this part.** This does **not** touch the internal exFAT freeze. EXP40's "phantom slave" fix is still the live theory there and is completely unchanged in this build. If your exFAT page froze on EXP40, expect it to behave exactly the same here. This build fixes which games show up on which page, nothing more.

**What to test on EXP41:**
- **The reported bug:** boot from your memory card, open the internal exFAT page, then plug in your MX4SIO card and open the MX4SIO page. It should now list the **SD card's** games. This is the one that matters.
- **Every device is on its own page:** check USB, MX4SIO, MMCE and the internal drive each list their own games and nothing borrowed from another device.
- **Nothing vanished:** if you have a drive that previously showed up, confirm it still does. This change moves how drives are matched to pages, so a device going missing is the failure mode to watch for.
- **sAGA / internal exFAT:** unchanged from EXP40. If you get a chance, the EXP40 question still stands (does the exFAT page list games, or still freeze), but nothing in EXP41 was aimed at it.

---

## New in EXP40: the phantom "device 1" — and back to lazy

Two things: undo a wrong turn, and finally test a real fix we wrote months ago but never ran on hardware.

**Back to lazy.** EXP38/39 loaded the internal drive **at boot** whenever the Internal-HDD setting was `EXFAT`/`BOTH` — but that setting only controls **which pages are visible**, not "use the drive now." That broke POPSLoader's lazy-by-design behavior and was never how the drive should come up. EXP40 undoes it: a normal MC/USB boot **no longer touches the internal drive at all** — it loads **only when you open the exFAT HDD page** (or launch straight to it). Every other device stays exactly as it was.

**The real fix — the phantom slave.** A deep byte-level + source investigation found a concrete mechanism for the freeze. The internal-ATA driver probes **two** devices, a "master" (your drive) and a "slave." A retail PS2 has no slave — but a 4TB drive behind a SATA adapter can float the bus so the driver *thinks* a slave is present. When it does, the storage layer tries to allocate a **second ~129 KB cache** (an allocation it never checks — if it fails, it crashes) **and** runs two sets of drive commands at once over one shared channel. POPSLoader loads more IOP modules than the lean reference tools, so it's the most likely to have no room left for that phantom second buffer — which is exactly why it hangs where R3Z/OPL don't, on the same drive.

**We already wrote the fix — and never tested it.** Back in EXP21 we made the driver tell itself *"there is no slave"* on a retail PS2 before it probes, which removes both the phantom buffer and the command collision (genuine dual-drive DVR consoles are left alone). It was buried under EXP22 ~40 minutes later, before anyone ran it on hardware. EXP40 revives it — the driver is now **built from source** with that one change — and puts it on the drive, on the correct lazy path.

**Honest status:** this is a **real fix attached to a testable hypothesis**, not a guaranteed win. If sAGA's exFAT page finally lists games → the phantom slave was the culprit and we've cracked it. If it still freezes → the device-1 theory is cleanly refuted, and the next build adds on-screen instrumentation to catch the exact line. Either way, it's decisive.

**What to test on EXP40:**
- **sAGA / internal exFAT:** boot normally from MC/USB (no more boot-time drive load), then open the **exFAT HDD** page — does it list your games instead of hanging at ~42%?
- **MX4SIO / MMCE / USB:** all unchanged — please confirm they're still healthy (this build recompiles the ATA driver from source, so a quick sanity pass matters).

---

## New in EXP39: the exFAT freeze — one clean variable (the boot chime)

EXP38 froze on the splash. A deep source-level comparison (byte-hashing every driver against the loaders that read sAGA's drive) settled two things for good, then found the real lead:

**It is NOT the drivers.** Our `ata_bd` is byte-identical to the one wLaunchELF R3Z and official OPL ship. We already shipped the *complete* byte-exact reference driver set (an earlier experiment) and it still froze — and RiptOPL ships an *older* ATA driver than ours and reads the drive fine. So the module bytes are fully exonerated. GPT parsing and 48-bit addressing are both present and working. Chasing the drivers is over.

**The real difference is something only POPSLoader does:** it starts the **boot chime** *before* it brings the internal drive up, and the chime keeps playing *through* the drive load. So the drive comes up while the audio hardware is actively streaming. **No other loader does this** — R3Z has no boot sound, NHDDL loads storage on a freshly-reset console, OPL/wOPL start their sound *after* storage. And it's the one thing that differs between the placement that **works** (EXP22 — drive loads before any audio) and the one that **froze** (EXP38 — drive loads during the chime).

**The change:** EXP39 keeps everything from EXP38 exactly the same, and moves **one thing** — the boot chime now starts **after** the internal drive is up, not before. The splash still covers the load; the only difference is the chime begins a moment later, in silence-then-sound instead of sound-through-load.

This is a deliberate **one-variable test.** If it works, the audio-during-storage collision was the freeze and we finally have the mechanism. If it still freezes, we've cleanly ruled audio out and the next suspect (the controller-adapter drivers initializing at the same time) is already lined up.

**What to test on EXP39:**
- **sAGA / internal exFAT drive:** boot to the menu. The splash may still sit a few seconds while the drive loads (that's expected — don't power off). Does it reach the menu now, and does the exFAT HDD page list your games instead of hanging on the splash? You'll notice the boot chime starts a touch later than before — that's the fix, not a bug.
- **MX4SIO / MMCE / USB:** confirm all still behave exactly as they did on EXP37/38.

---

## New in EXP38: the internal exFAT drive freeze — stop diverging from OPL

This is the fix for the internal **exFAT HDD freeze** — sAGA's 4TB GPT drive that stalls at *"Locating exFAT HDD POPS folder… 42%"* (and, on the boot-warm-up path, black-screened before the menu). It is **not** a module problem, a memory problem, or a "can't read GPT" problem — the drivers that read his drive are already in the build, byte-for-byte the same ones that read it on EXP22.

**What was actually wrong.** Every working loader — OPL, wLaunchELF R3Z, NHDDL — brings its whole storage stack up **the same way: together, in one go, under a loading screen, before anything else touches the drive bus.** POPSLoader had drifted into doing the opposite — loading the internal-drive driver (`ata_bd`) **late and by itself**, either mid-session when you open the page or on a background worker racing other startup work. On a big drive that late/split bring-up **wedges the drive bus** — which is the 42% hang (and, when it raced boot, the black screen). Same driver, wrong moment.

**The fix — do what the reference loaders do.** When the internal drive is enabled (Internal HDD = **exFAT** or **Both**, the default), POPSLoader now brings the `ata_bd` stack up **at boot, in one shot, while the welcome splash is on screen** — before the menu, before anything else uses the bus. This is the *exact* arrangement sAGA confirmed reads his drive ("works just fine" on EXP22), with the two reasons it was pulled last time both removed:
- **No black screen** — it runs under the splash (the picture is already up), so the few seconds the drive needs show the splash, not a black panel.
- **No race** — it finishes completely before the menu appears, instead of a background worker still churning as the menu loads (that race was the earlier black-screen).

**Scope — what this does *not* touch.** `ata_bd` lives on the dev9 (ATA) bus. This change **does not load or touch MMCE** (that's `mmceman` on the SIO2 bus — a completely separate thing) and does not change how MX4SIO or USB load. PFS-only setups skip it entirely and pay nothing.

**Honest status.** This restores the one configuration your drive is *known* to read, moved to a spot where it can't black-screen and can't race. I can't prove it on your hardware from here — so this build is the test. The one thing worth a second look is **MX4SIO** (it shares the block-device core with `ata_bd`): it was collateral damage the *last* time this was tried, but that was bundled with a driver swap we've since settled on, and the SDK drivers we now ship are the same ones OPL runs with `ata_bd` and MX4SIO resident together. If MX4SIO regresses, that's the next thread — but I expect it to be clean.

**What to test on EXP38:**
- **sAGA / internal exFAT drive:** boot to the menu (no black screen), then open the **exFAT HDD** page — does the game list finally come up instead of hanging at 42%? (The splash may sit a few seconds longer at boot while the drive comes up — that's the drive loading, and it's expected.)
- **MX4SIO:** browse the MX4SIO list as usual and confirm it's still healthy — no new hang or crash.
- **MMCE and USB:** confirm they behave exactly as they did on EXP37 (they shouldn't change at all).
- **PFS-only users:** boot should be as fast as before (this doesn't run for you).

---

## New in EXP37: the MX4SIO cover-art lag/crash — hardware-confirmed and fixed

The MX4SIO "browse a few games and it lags then crashes with *not enough memory*" bug is **found and fixed**, and this time it was confirmed on hardware before shipping: turning **Cover Art off (Square)** made the lag and the crash both vanish — which proved the cost was the per-game cover *lookup*, not the drive.

**What was happening.** When your covers aren't in the folder the app now reads (`<device>:/ART/<name>_COV.png`), *every* game you scroll to triggers a **failed file open** — and on MX4SIO a failed open of a file in a folder that isn't there is a slow driver dir-walk. Doing that for game after game piled up into the lag, and eventually the crash.

**The fix.** POPSLoader now checks whether the cover **folder** exists **once** (a single cheap check, remembered), and if it's not there it **skips the cover lookup for every game instantly** — no per-game file opens at all. If the folder *is* there, covers load exactly as before. So a device with no `ART` folder browses as fast as with Cover Art off, automatically.

**Also in EXP37:** the USB page no longer hunts for a drive **12 times** when there's none — it makes a reasonable, bounded try and fails fast and clean (you flagged the ~12-second hang crawling 38%→44%).

**What to test:**
- **MX4SIO:** browse the game list with Cover Art **on** — smooth now, no crash? (If you *want* covers, put them at `<device>:/ART/<gamename>_COV.png`.)
- **USB with no drive plugged:** opening the USB page should fail quickly and cleanly, not hang for ~12 seconds.

---

## New in EXP36: devices identify themselves directly (no more per-slot probing)

This is a device-layer cleanup that should make the MX4SIO and exFAT pages both **faster and steadier**, and is the right way to have done it from the start.

**The change.** When POPSLoader opens the MX4SIO page (or the exFAT page), it already knows which driver it just loaded — so it now asks the driver **directly** which storage slot it owns, using the enumeration the PS2 SDK already provides. Previously it did the opposite: it opened *every* `mass0:`…`mass9:` slot in turn and asked each one "who are you?" That per-slot interrogation is slow, and on a drive that's still spinning up it could **stall the console** — a plausible contributor to the "carousel appears then freezes" report. The per-slot interrogation is gone from these pages; the slower query now survives in exactly one place where it's genuinely needed (working out what an *old launcher* handed us when it boots us from a generic `mass:` path).

**Why it's safe.** Same drives, same files, same folders — only *how the page finds the right slot* changed, from "scan and ask everyone" to "ask the one driver we loaded." CosmicScale's exFAT drive is reached the same way, just directly. If the direct enumeration is ever unavailable, it falls back to the old scan, so nothing hard-breaks. The device layer now has 30 host-side tests (up from 29), including one that proves the page resolves its slot from the enumeration with **zero** per-slot probing.

**What to test on EXP36:**
- **MX4SIO and exFAT pages:** do they open at least as quickly as before, and steadily? (This change is aimed squarely at the freeze/stall path.)
- Everything from EXP35 still applies — the boot no longer probes exFAT, covers live at `<device>:/ART/<name>_COV.png`.

---

## New in EXP35: two EXP34 regressions fixed (boot black-screen, MX4SIO memory crash) + cover art hard-locked

EXP34's testing turned up two regressions the new defaults introduced. EXP35 fixes both and simplifies the cover system so it can't misbehave again.

**Boot no longer probes the internal exFAT drive.** EXP34 made *Internal HDD = Both* the default, and a leftover rule warmed up the exFAT drive **at every boot** because of it. On at least one console (a 4TB GPT exFAT internal drive) that boot-time probe **black-screened the machine before the menu** — an unrecoverable boot. EXP35 stops probing exFAT at boot entirely: the exFAT page brings the drive up **when you open it** (screen stays alive; if the drive is slow it says "still starting" instead of freezing), exactly like every other device. A normal boot never touches the internal drive now. *(If you deliberately launch straight to the exFAT page with a `-page=ata` argument, that still pre-warms it — you asked for that page.)*

**MX4SIO no longer lags-then-crashes on cover art.** EXP34 added a folder-listing step to the cover lookup; on MX4SIO that step could run away and end in an **"Enceladus ERROR! not enough memory"** crash after browsing a few games. That step is **removed**. Combined with the change below, looking up a cover is now a single, bounded file check per game.

**Cover art is hard-locked to one place and one name.** No more folder setting. Covers are read from **`<device>:/ART/<gamename>_COV.png`** — the OPL layout — full stop. (The internal HDD keeps its fixed `__common/POPS/ART/` location.) One folder, one name, so put `<GameID>_COV.png` files in `<device>:/ART/` and they show. The *Cover/details folder* setting is gone (it did nothing useful and was a foot-gun).

**Honest status:** the boot-probe removal directly addresses the black-screen mechanism, and the cover crash's most likely cause (the new listing step) is gone. Both are the kind of fault only your consoles can fully confirm — so this build is the test. If MX4SIO still misbehaves *with cover art turned off* (Square), that points past the art code at the device layer, and that's the next thread to pull.

**What to test on EXP35:**
- **sAGA / anyone with an internal exFAT drive:** does it boot to the menu now (no black screen)? Then open the exFAT page and see if the drive lists.
- **MX4SIO:** browse the game list — does it stay responsive without the memory crash? If it still stalls, try it again with **Cover Art OFF (Square)** and say whether that changes anything.
- **Covers:** put your art at `<device>:/ART/<name>_COV.png` and confirm it shows.

---

## New in EXP34: cover-art that stops stalling, OPL art out of the box, and better defaults

EXP33's testing surfaced two things at once: the APA "no games" report turned out to be **an accidentally-hidden game** (not a bug — the EXP33 readout is what exposed it), and the real remaining pain was **cover-art lookup lagging** on MX4SIO and USB. EXP34 fixes the lag, adopts OPL's art layout, and sets a batch of more useful defaults.

**Cover-art no longer stalls the list.** The old code checked for each cover by *trying to open several candidate files per game* — and on SD-over-SIO2 or USB 1.1 a missing file is a slow directory walk, done over and over. EXP34 lists each art folder **once** and then every check is instant, so a device with no art (or a game with none) never stalls the browser again. Covers that *are* present still load; they just don't drag the whole list down first.

**One art location, honored exactly — no more guessing.** Cover art is read from the single folder you choose in Settings (nothing else is probed):
- **`ART` (new default)** — a top-level `<device>:/ART/` folder. This is **OPL's layout**, so if you already have an OPL `ART` folder it just works.
- **`POPS/ART`** — an `ART/` subfolder next to your games.
- **`POPS`** — right beside the `.vcd`.

**OPL-compatible art naming.** Covers are now read as **`<gamename>_COV.png`** (OPL's convention) first, with the older plain `<gamename>.png` still accepted as a fallback so nothing you already have disappears. Put OPL's `<ID>_COV.png` files in `<device>:/ART/` and they show up.

**New defaults (all still changeable in Settings):**
- **Internal HDD = Both** (PFS *and* exFAT pages shown) instead of PFS-only.
- **i.Link page hidden** by default (re-show it under Settings → Device List if you use it).
- **Cover/details folder = `ART`** (see above).
- **Network/SMB defaults** refreshed to a common home-LAN layout: PS2 IP `192.168.1.10`, gateway/DNS `192.168.1.1`, server `192.168.1.100`, share `games`, user `guest`, port `1111`. (DHCP is still ON by default — flip it off in Settings if you want these static values used as-is.)

**APA "no games" now says *why*.** If a scan finds `.vcd` files but lists zero games, the message now tells you the reason — e.g. *"1 part, 5 files, 1 VCD (1 hidden — Global Hide is on)"* — so an accidentally-hidden game (exactly what EXP33 turned up) reads as "hidden," not "broken."

**These changes only affect NEW installs / unset options.** If you already saved settings, your existing choices (art folder, HDD filesystem, network, device list) are kept — the new defaults apply where you never set one.

**What to test on EXP34:**
- **Cover-art speed:** open MX4SIO and USB, scroll the list. It should stay responsive whether or not art is present. If you have OPL art, drop it in `<device>:/ART/` as `<name>_COV.png` and confirm it shows.
- **Existing covers:** if you were using plain `<name>.png` in your chosen folder, confirm they still appear (the legacy name is still accepted).
- **Defaults:** on a fresh install (or after a settings reset) confirm Internal HDD shows both pages, i.Link is hidden, and the SMB settings show the new values.

---

## New in EXP33: the two EXP32 field bugs — APA "no games" and re-entry stalls

**EXP32 rebuilt the device layer correctly, but two tester reports came back that the rebuild didn't cover.** EXP33 does not touch the EXP32 architecture — it fixes those two specific reports and, where a cause could not be proven off-console, makes the build *tell us what it saw* instead of failing silently.

**Report 1 — APA (internal PFS) lists no games, even on a fresh boot straight to APA.** "There should be at least 1 game." The partitions mount, but the game list comes back empty. Two things could cause this and EXP33 addresses both:
- **A boot-vs-page race on the internal drive.** In EXP32 the internal drive can be brought up from *two* places at once — the background boot warm-up and the moment you open the APA page — and if they overlap, the second one re-resets the live ATA bus mid-scan (the same class of fault as the old 42% freeze). EXP33 serializes the two: the page waits, screen alive, for the background warm-up to finish before it touches the drive, backed by a native lock so they can never both drive the bus at once.
- **A single dropped re-mount.** During the scan each POPS partition is mounted a second time to read its files; if that one attempt loses a race with the coexisting drive stack, that partition silently contributed zero games. EXP33 retries that mount once (after a 1-second settle) — but *only* for partitions already known to be present, so it can never reintroduce a stall hunting for a partition that isn't there.
- **And if it's neither of those:** the "no games" message now *reports what the scan actually saw* — how many partitions mounted, how many files and how many `.vcd` files it counted, or which partition's re-mount failed and with what error code. So the next report from hardware is self-diagnosing: "mounted 2/2, 40 files, 0 VCD" means the folder truly has no games; "mounted 1/2, remount-fail" means we caught the drop. No more opaque "partitions are empty."

**Report 2 — leave the MX4SIO (or USB) page and come back, and it stalls: only the background shows, activity light stuck on, then the list finally pops in.** Two causes, both fixed:
- **Cover-art probe firing during the screen transition.** Reading a cover is a synchronous file read, and a *missing* cover is a full directory walk (seconds on SD-over-SIO2 or USB 1.1). EXP32 could kick that off while the fade-in was still running, so the render loop blocked on the opaque overlay — exactly the "only the background shows" symptom. EXP33 holds the cover probe until the list has painted and the transition has finished.
- **The "this cover is missing" memory was thrown away on exit.** The first visit walks the disk for every missing cover and remembers the misses; EXP32 discarded that memory when you left the page, so re-entering walked the whole disk *again*. EXP33 keeps the negative-cover memory across a page exit (while still freeing the decoded images, so memory doesn't grow) — a re-entry no longer re-walks the disk for covers it already knows are absent. A manual refresh (R1) or switching to a different device still does a full, clean rescan.

**Honest status:** the re-entry stall fixes address the reported mechanism directly and are testable off-console (the regression net now has 27 host-side tests). The APA fixes are a mix: the race serialization and retry-once are real defensive fixes, but whether they *are* sAGA's / the reporter's exact cause is not something we can prove without the hardware — which is why the self-diagnosing readout is in this build. If APA still shows no games on EXP33, the message it prints tells us precisely where to look next.

**What to test on EXP33:**
- **APA no-games (whoever hit it):** boot straight to APA (MC boot is fine), open the internal PFS page. If games appear — good. If it still says "no games found," **read the second line of that message and send it verbatim** — that line is the whole point of this build.
- **MX4SIO / USB re-entry stall:** open the MX4SIO page, go into a game or another page, come back to MX4SIO. Then do the same for USB. Expected: the list repaints promptly, no long "only background, light stuck on" pause on the return. If you can, try it once with Cover Art on and once with it off (Settings) — that isolates whether covers are the culprit.
- **Everyone:** MC, MMCE, controllers and saves should behave exactly as EXP32; boot time unchanged.

---

## New in EXP32: the device layer rebuilt the way the working launchers do it

**This is the rebuild.** After sAGA's report (SCPH-30004, internal exFAT frozen at 42% on EXP30 *and* EXP31 — builds that carry every previous "fix"), we stopped patching and rebuilt the storage layer to match the launchers that actually work on your consoles: OPL/RiptOPL, wLaunchELF-R3Z and NHDDL. Their sources were read line-by-line for this; POPSLoader now follows their rules instead of its own inventions.

**What the comparison found.** The working launchers don't have *more* code for these problems — they have *less*. None of them has a "who owns the bus" latch, a restart dialog, a crash marker file, or per-device retry ladders. What they have instead: drivers load in one coordinated window into a near-empty system, every wait is short and bounded, a missing device is reported plainly, and a failed driver load is retried on the next visit instead of poisoning the session. On sAGA's exact case the evidence was decisive: the drive driver bytes are **identical** between the old build that worked on his console and the current one that freezes — what changed is *when* the driver loads (boot window vs mid-session) and how much traffic is in flight around it. The EXP22-era build that worked for him loaded it at boot; every reference does the equivalent.

**What EXP32 changes:**
- **Storage drivers load lazily, when you engage their device** — exactly wLaunchELF-R3Z's model (read from its source, now that it's available to us). The MX4SIO driver loads on your first visit to the MX4SIO page (or an MX4SIO boot), never for users who don't use it. Opening the page after that is a short, bounded check that cannot freeze the console.
- **MMCE and MX4SIO coexist — no gate.** Official OPL runs both drivers resident together in the field and it works; this build carries the same freesio2 bus manager OPL uses (from EXP31), so we follow OPL's model (maintainer decision). For the record: the wLE-R3Z author advises gating them (the adapters wire a memcard-port pin differently) and R3Z resets between them — if hardware testing ever shows cross-device weirdness with both adapters installed, that's the recorded fallback position.
- **A boot from an old launcher that says `mass` now finds its real device.** If your settings live on a `mass`-path cwd that isn't actually USB (an MX4SIO card or the internal exFAT drive handed to us by an older launcher), the boot-time search now escalates: USB first, then the MX4SIO driver, then the internal drive — bounded, a few seconds — instead of assuming USB and losing your settings.
- **The internal exFAT drive starts at boot, in the background** (behind the splash — boot stays fast), but *only* when your Internal HDD setting includes exFAT — no device is probed at boot that you didn't opt into. If it's still spinning up when you open the page, the wait is capped at ~10 seconds — screen alive — then *"the internal drive is still starting, open this page again in a moment"* instead of freezing. The old silent freeze paths (a synchronous fallback load and a re-entered 90-second wait) are gone entirely. APA (PFS) and exFAT internal remain fully coexisting — no gate between them (confirmed against R3Z source: *"ATA_BD + APA stack can coexist in one IOP session"*).
- **Deleted, wholesale:** the "device conflict / restart" *dialog*, the MX4SIO crash-marker files and the boot-skip logic that read them, the per-device 6/4-try retry ladders, the cross-page "cascade guard", and the custom bdm_query polling on the MX4SIO/exFAT paths. The one thing that returned in better form is the MMCE/MX4SIO gate above — as a simple decline-with-message, not the old marker/dialog machinery.
- **A regression net, finally:** the device layer now has host-side tests (26/26 passing — including the coexistence contract and the bounded-wait rules) so this layer can't silently regress again in a future build.

**Honest status:** the *architecture* now matches the launchers that work on your hardware, and everything testable off-console passes. What only your consoles can prove: sAGA's SCPH-30004 exFAT drive and FifthFox's MMCE+MX4SIO slim. No victory claims — this build is the test.

**What to test:**
- **sAGA (SCPH-30004, internal exFAT):** update to EXP32, make sure Settings → Device List → Internal HDD is set to **exFAT** (or Both), then open the exFAT page. Expected: your games list, or at worst the "drive is still starting" message once, then the list on re-entry. Please also confirm MC, MMCE and USB still behave.
- **FifthFox (SCPH-70012, MMCE + MX4SIO both installed, back on the 25th):** update to EXP32, open the MX4SIO page with both adapters in. Expected: your games list within a few seconds. Then MMCE in the same session (both are allowed together now, like OPL), plus controllers and memory-card saves. If anything acts strange only when *both* adapters are in, say so explicitly — that specific detail decides a recorded fallback plan.
- **Anyone:** boot time should feel unchanged (the drive spin-up hides behind the splash; PFS-only installs skip it completely).

---

## New in EXP31: MX4SIO that still freezes at 42% with an MMCE adapter also plugged in

**This is for FifthFox's report: the MX4SIO page stuck forever at "Locating MX4SIO POPS folder... 42%", on a slim (SCPH-70012) that has BOTH an MMCE memory-card adapter AND an MX4SIO/SD2PS2TD SD adapter installed at the same time. The same card works in RiptOPL and wLaunchELF-R3Z on that exact console, so the card is fine — this is us.**

**What we found.** The MX4SIO SD driver does not own the SIO2 bus by itself; it *hooks* the shared `sio2man` module and lets `sio2man` take turns between it and everything else on that bus — the controller, the memory-card reader, MMCE. POPSLoader ships Sony's stock `sio2man`, which does not arbitrate those turns. So when a **second** SIO2 device is physically in the console (your MMCE adapter sitting alongside the MX4SIO adapter), the memory-card reader and the MX4SIO card talk over each other on the bus and the read never comes back — the screen is frozen on the last thing it painted, "…42%". That is why the earlier driver-matching fix did not help you: it fixed a different 42% cause and never touched the bus manager. Single-adapter rigs (only MX4SIO, or only MMCE) do not hit it, which is why it did not reproduce here.

**What changed.** EXP31 swaps the SIO2 bus manager to **freesio2** (and its matching **freepad**), the queue-based versions that **OPL, wLaunchELF-R3Z and RiptOPL all use** — the launchers where your card already works. That is the whole change: same driver binaries the working references run, nothing else. It is a build-time blob swap, so it is easy to pull back if it misbehaves.

**Honest status:** this is the fix the *working* launchers use, not yet a fix we have watched clear your console — SIO2 timing is only provable on real hardware, so EXP31 is exactly that test.

**What to test (FifthFox, whenever you are back):** update to EXP31 with **both** adapters installed as before, open the **MX4SIO** page, and give it up to two minutes.
- If your games list appears — that is the win we are after.
- If it says **"No MX4SIO device detected"** after a few seconds instead of freezing — tell us; that means the deadlock is gone but detection still needs work (a different, smaller step), not another hard freeze.
- If it still freezes at 42% — tell us that too; then freesio2 is not the whole story and the next build adds a safety net so the page can never hard-freeze.

Because this swaps the bus manager that *everything* on SIO2 shares, please also give these a quick confirm on EXP31: **controllers still navigate the menu**, **memory-card save/settings still work**, **MMCE still lists games**, and (if you use it) **USB-pad / DualShock emulation still works**. If any of those regressed, that is important — say so and we pair freesio2 back with the stock pad driver.
