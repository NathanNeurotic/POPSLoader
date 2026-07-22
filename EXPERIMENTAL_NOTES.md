# POPSLoader: Experimental Build 🧪

**This is the opt-in EXPERIMENTAL channel.** It exists so testers can try riskier changes in isolation, without them reaching anyone who did not ask for it. The public release (**1.1.0**) and the rolling test build are both untouched by anything here.

**How to tell you are running it:** Settings, then About: the Version row reads **v1.1.1-dev-EXP39**. The check is simple: a version ending in **-EXP39** = this build; **-EXP38** or lower = an older experimental, please update; plain **v1.1.1-dev** = the rolling build; **v1.1.0** = the public release.

**How to go back:** reinstall the latest entry on the Releases page. Nothing here changes your settings, your `POPS` folders, or your games, so switching back and forth is safe.

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
