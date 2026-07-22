# POPSLoader: Experimental Build 🧪

**This is the opt-in EXPERIMENTAL channel.** It exists so testers can try riskier changes in isolation, without them reaching anyone who did not ask for it. The public release (**1.1.0**) and the rolling test build are both untouched by anything here.

**How to tell you are running it:** Settings, then About: the Version row reads **v1.1.1-dev-EXP33**. The check is simple: a version ending in **-EXP33** = this build; **-EXP32** or lower = an older experimental, please update; plain **v1.1.1-dev** = the rolling build; **v1.1.0** = the public release.

**How to go back:** reinstall the latest entry on the Releases page. Nothing here changes your settings, your `POPS` folders, or your games, so switching back and forth is safe.

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
