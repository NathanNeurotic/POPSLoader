## From the official thread — compatibility notes & per-game fixes

> Sourced from the [official psx-place POPStarter thread](https://www.psx-place.com/threads/popstarter.19139/).

- **Merged multi-disc ISOs break per-game fixes.** POPStarter's automatic fixes are keyed to the game ID in
  `SYSTEM.CNF`; a merged "Crash 1+2+3" or all-in-one ISO carries the wrong ID, so the per-game fix never
  fires. **Use clean single-disc rips.** *(Peppe90 / El_Patas — high value, corrects a popular tutorial habit)*
- **`$COMPATIBILITY` modes are not universal — several are no-ops per game.** Mode 4 was never integrated for
  Chrono Trigger / Xenogears (won't fix sound); Mega Man X4 never had Mode 1; SOTN has Mode 1 but keeps its
  old problems. Xenogears flicker and Chrono Trigger area/menu sound-slowdown are **unfixable** by any mode.
  *(El_Patas)*
- **CD-read-sensitive games on USB** (e.g. Soul Blade): format the device **FAT32/exFAT with 16 KB clusters**.
  Larger clusters → corrupt loads/crashes. SMB and internal HDD are unaffected. *(hugopocked)*
- **PAL PS1 games scroll/roll vertically through some HDMI adapters;** `$NOPAL` stops the scroll but
  off-centres the image (re-centre with `$XPOS`/`$YPOS`). *(R3dRapt0r39)*

### Per-game datapoints (community-verified)

| Game | Fix |
| --- | --- |
| Mega Man 8 / Mega Man X4 (NTSC-U) | `$CODECACHE_ADDON_0` in CHEATS.TXT restores the charge-beam / voice SFX (preferred over swapping to the PSP 6.60 BIOS) |
| King's Field (JP, Eng-patched) | `$COMPATIBILITY 0x04` to avoid slowdowns |
| C-12: Final Resistance (SCES-033.64) | `$COMPATIBILITY_0x07` partly fixes missing textures (mode is incomplete — speech/subs still missing) |
| Resident Evil 3 (SLUS-00923) | completable with the GameHacking.org "Skip Door Transition" code + PSP 6.60 BIOS, no compat mode |
| Tekken 3 (PAL) | in-game scanline-generator hotkey **Select + R1 + R2** fixes bottom-screen artifacts |
| Tomb Raider 1 (USA) | only Rev0 works untouched; Rev1–6 need krHACKen's per-revision PS3-tools patches (restore levels **and** music). TR2 USA Rev0–3 are fine; Gold ports won't load levels |
| Speedball 2100 (US) | `TROJAN_7.BIN` clears the load freeze, but then reports "no controller in port 1" — a separate, unfixable emulation bug |

> **Known multi-track-audio bug:** newer Tomb Raider revisions and Air Combat lose all CD music/voice tracks
> even when levels load (a POPS emulation limitation). *(Peppe90)*
