<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/compatibility -->
<!-- primary snapshot: 20170629151818  |  14 captures, 5 distinct content version(s) -->
<!-- other distinct versions retained in _versions/compatibility/: 20191112230123, 20201204111637, 20221026104310, 20240620175949 -->
<!-- MERGED: this document unions every unique fact across all 5 distinct snapshots (2017-06-29, 2019-11-12, 2020-12-04, 2022-10-26, 2024-06-20). -->
# compatibility

# **Game Compatibility**

______________________________________________________________________________________________________________

POPS is able to emulate a large range of games perfectly fine with the POPStarter fixes – which makes it superior to [PS2PSXE](http://psx-scene.com/forums/f292/ps2psxe-public-preview-feedback-discussions-64878/). Best results are expected in internal HDD mode.

*(This intro paragraph and the "unplayable games" list below first appeared in the 2019-11-12 snapshot; the original 2017-06-29 snapshot opened directly with the compatibility-rate figures instead.)*

Unfortunately, some famous and epic games are still unplayable. Here’s a short list of them :

- Crash Bash (extreme flickering) ; *(listed in 2019/2020 snapshots; dropped from the 2024 snapshot's short list)*

- Tekken 3 (extreme flickering) :

- Spyro 2 & 3 (crashes) ;

- Gran Turismo 2 (black cars) ; *(listed in 2019/2020 snapshots; dropped from the 2024 snapshot's short list)*

- Dino Crisis (crashes) ; *(listed in 2019/2020 snapshots; dropped from the 2024 snapshot's short list)*

- Parasite Eve II (crashes, and no SFX/music until a cutscene is played) ;

- Resident Evil 3 (random crashes). *(listed in 2019/2020 snapshots; dropped from the 2024 snapshot's short list)*

______________________________________________________________________________________________________________

## *Compatibility rates (04/21/2016) :*

*(This section appears only in the original 2017-06-29 snapshot.)*

```

* MODE (Region) : XX% games playable (games partially or perfectly emulated/games tested)

```

- HDD (PAL) : 78% (343/438)

- HDD (NTSC) : 75% (165/219)

- USB (PAL) : 79% (298/377)

- USB (NTSC) : 83% (211/252)

- SMB (PAL) : 76% (133/174)

- SMB (NTSC) : 80% (92/114)

______________________________________________________________________________________________________________

## *Compatibility lists and forms :*

### ElOtroLado Compatibility List

*(The newest 2024-06-20 snapshot promoted the ElOtroLado list — managed by El_Patas — to the primary, current list and marked the Google-Docs "Official" lists below as obsolete.)*

- **ElOtroLado Compatibility List : [UPDATED – 20/01/2023]**

This compatibility list is managed by El_Patas.

| **Device** | **Compatibility list (read-only)** |
| --- | --- |
| **Internal HDD, USB & SMB** | [here](http://elpatas.epizy.com/pops/pops0-9.html?i=2) |

The El_Patas list has been hosted at several URLs over time (use the most recent):

- 2024-06-20 snapshot: <http://elpatas.epizy.com/pops/pops0-9.html?i=2>
- 2020-12-04 / 2022-10-26 snapshots: <https://elpatas.000webhostapp.com/pops/pops0-9.html>
- 2017-06-29 / 2019-11-12 snapshots (then called the "EOL" / "ElOtroLado Compatibility List"): <http://www.el_patas.byethost10.com/pops/pops0-9.html>

### Official Compatibility Lists (Google Docs)

*(In the 2017 snapshot these were titled simply "Rev 13 Official Compatibility Lists"; the 2024 snapshot relabels the whole section **[OBSOLETE & DEATH]**.)*

- **Rev 13 Official Compatibility Lists :** — **[OBSOLETE & DEATH] (per the 2024-06-20 snapshot)**

These compatibility lists are managed by AlGollan84 (aka Algol aka Allan58) and krHACKen.

| **Device** | **Compatibility list (read-only)** | **The form for submitting reports** |
| --- | --- | --- |
| **Internal HDD** *(older snapshots: "HDD")* | [here](https://docs.google.com/spreadsheet/ccc?key=0AkthiKwj1VJMdFIzb3NuOWU2eWZqUDNwVl9uTzFPTGc#gid=0) | [here](https://docs.google.com/forms/d/17fb0I0GxnPpIuCvayFgFhd8MlozcBqR42kdzuOA5b1I/viewform) |
| **USB Device** *(older snapshots: "USB")* | [here](https://docs.google.com/spreadsheet/ccc?key=0AkthiKwj1VJMdGJyVDdyRXBQR0RsOTNrM3hvaFdacmc#gid=0) | [here](https://docs.google.com/forms/d/10oPoxZvdtiO3YOe9kX_isgCkJMizCD_nvcf6TH4Xvck/viewform) |
| **SMB** | [here](https://docs.google.com/spreadsheets/d/1LoLl_YVY2qlJN6F3Ubwd0AvqkeK0tbHqrIEjBiGmDpQ/edit#gid=0) | [here](https://docs.google.com/forms/d/1zimkx1nufqgF808EyoDqC9_USV2FqSQKlka678wo67w/viewform) |

### Old Compatibility Lists (outdated & locked, for history)

*(This sub-list appears only in the 2017-06-29 snapshot.)*

- POPStarter Rev 12 : [here](https://docs.google.com/spreadsheet/ccc?key=0As_WFUFvrRw5dE5fWEU1TTlscW9XMUtuTE12aU04d3c#gid=0).
- POPS-00001 : [here](https://docs.google.com/spreadsheets/d/1OKjHsF2sk3LH6X9NiELvbK7fEkXnOyG3zidDjUvNRUk/edit#gid=0).

______________________________________________________________________________________________________________

## *Compatibility modes :*

If your game is poorly emulated, you can enable a compatibility mode to try to fix your issue. *(older 2017 snapshot wording: "you can try to enable a compatibility mode to see if it helps.")*

| **Compatibility mode** | **Description** |
| --- | --- |
| **0×01** | Helps restoring the music/voices in several games. |
| **0×02** | A variant of mode 0×01, with a second hack for not breaking the MDECoding of FMVs (was designed for the Colony Wars series). |
| **0×03** | Can be used if the mode 0×01 doesn’t provide the expected results. |
| **0×04** | Fixes slowdowns, flickering, and many other glitches (prevents the emulator from writing a garbage value in two of the virtual GPU registers). |
| **0×05** | Made for fixing the cutscenes of the PAL Resident Evil: Director’s Cut. |
| **0×06** | Disables the OSD shell of the emulator’s built-in BIOS, making some games that freeze on startup run. |
| **0×07** | Fixes the missing textures problems (example : [Tomb Raider III](https://www.youtube.com/watch?v=3LmGlgY_rNs&feature=youtu.be) ). Unfinished (breaks the gamma) **[NOTE: This Mode is obsolete]**. |

*Notes on mode 0×07 wording across snapshots:* the 2017 snapshot had no caveat; the 2019/2020/2022 snapshots added "Unfinished (breaks the gamma)."; the 2024 snapshot added "**[NOTE: This Mode is obsolete]**".

**Caution / Notes :**

- Modes 0×01, 0×02, 0×03 and 0×05 cannot be enabled in the same time or combined. These are variants of the same hack and they are conflicting, so use only use one of them at a time.

- *(2017 snapshot only)* Please let us know (at [ASSEMblergames](http://assemblergames.com/l/threads/ps2-pops-stuff.45347/)) if you managed to solve a problem in your game by forcing modes, so the fix can be integrated in POPStarter.

**How to enable / use a compatibility mode :**

- using a PATCH_#.BIN file from the [compatibility mode archive](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/Compatibility_Modes.7z) : place the PATCH_#.BIN file in the VMC directory of your problematic game and test. *(2017 snapshot added: if the compatibility mode doesn’t solve any problem in your game, delete the PATCH file from the VMC directory and redo the operations with the next PATCH file.)*

- using a CHEATS.TXT file : see the [cheat engine](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/cheat-engine) section to know how to enable a mode using the cheat engine.

- hardcoding the mode in POPStarter (advanced user) : read [POPStarter configuration table](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/configuration-table).

**Note :** *(added in the 2019-11-12 snapshot and kept since)* if your game lags badly or stalls randomly and that mode 0×04 doesn’t fix that, you can try to use [$CODECACHE_ADDON_0 command](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/special-cheats) in a GAME/CHEATS.TXT file. Do not use it by default on all your games because most games will stop working with it.

______________________________________________________________________________________________________________

## *Game fixes (manual) :*

*(This whole section — the manual TROJAN-file game-fix list — appears only in the original 2017-06-29 snapshot. Later snapshots replaced it with the "Automated fixes" internal database described below.)*

In the [game fixes archive](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/Game_Fixes.7z), you can find some TROJAN files fixing problematic games. Copy the file in the VMC directory of your problematic game.

**List of game fixes :**

- 007 – Demain Ne Meurt Jamais (SLES-02375) – AntiCrash Fix

- 007 – Der Morgen Stirbt Nie (SLES-02376) – AntiCrash Fix

- 007 – Tomorrow Never Dies (SLES-01324) – AntiCrash Fix

- 007 – Tomorrow Never Dies (SLPS-02604) – AntiCrash Fix

- 007 – Tomorrow Never Dies (SLUS-00975) – AntiCrash Fix

- Casper (SLES-00045) – LoadinFix

- Casper (SLUS-00162) – LoadinFix

- Crash Bandicoot Racing (SCPS-10118) – LoadinFix

- Crash Team Racing (SCUS-94426) – Boot Fix

- CTR – Crash Team Racing (SCES-02105) – Boot Fix

- Destruction Derby 2 (SCUS-94350) – AntiCrash Fix

- Destruction Derby 2 (SIPS-60012)  – AntiCrash Fix

- Destruction Derby 2 (SLES-00299)  – AntiCrash Fix

- Future Racer (SLES-03508) – “Boost” Fix + mode 0×04

- Harry Potter And The Chamber Of Secrets (SLES-03972) – AntiCrash Fix

- Harry Potter And The Chamber Of Secrets (SLES-03973) – AntiCrash Fix

- Harry Potter And The Chamber Of Secrets (SLES-03974) – AntiCrash Fix

- Harry Potter And The Chamber Of Secrets (SLUS-01503) – AntiCrash Fix

- Harry Potter And The Philosopher’s Stone (SLES-03662) – AntiCrash Fix

- Harry Potter And The Philosopher’s Stone (SLES-03663) – AntiCrash Fix

- Harry Potter And The Philosopher’s Stone (SLES-03664) – AntiCrash Fix

- Harry Potter And The Philosopher’s Stone (SLES-03665) – AntiCrash Fix

- Harry Potter And The Sorcerer’s Stone (SLUS-01415) – AntiCrash Fix

- Harry Potter To Kenja No Ishi (SLPS-03355) – AntiCrash Fix

- Metal Gear Solid (Disc 1) (SLES-01370) – Skip problematic CutScenes

- Metal Gear Solid (Disc 1) (SLES-01506) – Skip problematic CutScenes

- Metal Gear Solid (Disc 1) (SLES-01507) – Skip problematic CutScenes

- Metal Gear Solid (Disc 1) (SLES-01508) – Skip problematic CutScenes

- Metal Gear Solid (Disc 1) (SLES-01734) – Skip problematic CutScenes

- Metal Gear Solid (Disc 1) (SLPM-86111) – Skip problematic CutScenes

- Metal Gear Solid v1.0 (Disc 1) (SLUS-00594) – Skip problematic CutScenes

- Metal Gear Solid v1.1 (Disc 1) (SLUS-00594) – Skip problematic CutScenes

- Roadsters (SLES-02326) – AntiCrash Fix

- Roadsters (SLUS-01024)  – AntiCrash Fix

- Tomb Raider (PAL Retail) – SkipVSync

- Tomb Raider (SLUS-00152) – SkipVSync

- Tomb Raider 2 (SLPS-01200) – SkipVSync

- Tomb Raider II – Starring Lara Croft (Beta 1997-09-30) – SkipVSync

- Tomb Raider II – Starring Lara Croft (PAL Retail) – SkipVSync

- Tomb Raider II – Starring Lara Croft v1.0 (SLUS-00437) – SkipVSync

- Tomb Raiders (SLPS-00617) – SkipVSync

- WipEout (SCUS-94301) – AntiCrash Fix

- WipEout (SIPS-60003)  – AntiCrash Fix

- WipEout v1.0 (SCES-00010)  – AntiCrash Fix

- WipEout v1.1 (SCES-00010)  – AntiCrash Fix

______________________________________________________________________________________________________________

## *Automated fixes :*

*(2017 snapshot wording:)* A list of all the LC cracks, crash fixes & compatibility modes integrated into POPStarter can be found [here](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/automated). You don’t need to enable them/do something to get them enabled, as POPStarter will detect your game and apply the matching fix all by itself.

*(2019-and-later snapshots wording:)* POPStarter has an [internal database](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/automated) containing various fixes (compatibility modes, LibCrypt cracks and miscellaneous fixes) for a big amount of games. These fixes will be automatically applied to your game, as long as you use proper dumps (for identification).

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
