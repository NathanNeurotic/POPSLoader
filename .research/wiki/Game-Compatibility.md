<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Game-Compatibility -->
<!-- primary snapshot: 20160706185742  |  1 captures, 1 distinct content version(s) -->
# Game-Compatibility

# **Game Compatibility**

______________________________________________________________________________________________________________
*[Up-to-date with WIP 06, OBT 13 (2015/12/07)]*

## *Compatibility rates (04/21/2016) :*

```

* MODE (Region) : XX% games playable (partially or perfectly emulated/tested)

```

- HDD (PAL) : 78% (343/438)

- HDD (NTSC) : 75% (165/219)

- USB (PAL) : 79% (298/377)

- USB (NTSC) : 83% (211/252)

- SMB (PAL) : 76% (133/174)

- SMB (NTSC) : 80% (92/114)

______________________________________________________________________________________________________________

## *Compatibility Lists and Forms :*

These compatibility lists are managed by AlGollan84 (aka Algol aka Allan58) and krHACKen.

- **Rev 13 Official Compatibility Lists :**

<table class="wiki"> <tr> <td> <strong>Device</strong> </td> <td> <strong>Compatibility list</strong> </td> <td> <strong>Form to submit reports</strong> </td> </tr> <tr> <td> HDD </td> <td> <a href="https://docs.google.com/spreadsheet/ccc?key=0AkthiKwj1VJMdFIzb3NuOWU2eWZqUDNwVl9uTzFPTGc#gid=0">here</a> </td> <td> <a href="https://docs.google.com/forms/d/17fb0I0GxnPpIuCvayFgFhd8MlozcBqR42kdzuOA5b1I/viewform">here</a> </td> </tr> <tr> <td> USB </td> <td> <a href="https://docs.google.com/spreadsheet/ccc?key=0AkthiKwj1VJMdGJyVDdyRXBQR0RsOTNrM3hvaFdacmc#gid=0">here</a> </td> <td> <a href="https://docs.google.com/forms/d/10oPoxZvdtiO3YOe9kX_isgCkJMizCD_nvcf6TH4Xvck/viewform">here</a> </td> </tr> <tr> <td> SMB </td> <td> <a href="https://docs.google.com/spreadsheets/d/1LoLl_YVY2qlJN6F3Ubwd0AvqkeK0tbHqrIEjBiGmDpQ/edit#gid=0">here</a> </td> <td> <a href="https://docs.google.com/forms/d/1zimkx1nufqgF808EyoDqC9_USV2FqSQKlka678wo67w/viewform">here</a> </td> </tr> </table>

- **EOL Compatibility List** (managed by El_Patas) : [here](http://www.el_patas.byethost10.com/pops/pops0-9.html)

- **Old Compatibility Lists** (outdated & locked, for history) :

POPStarter Rev 12 : [here](https://docs.google.com/spreadsheet/ccc?key=0As_WFUFvrRw5dE5fWEU1TTlscW9XMUtuTE12aU04d3c#gid=0)

POPS-00001 : [here](https://docs.google.com/spreadsheets/d/1OKjHsF2sk3LH6X9NiELvbK7fEkXnOyG3zidDjUvNRUk/edit#gid=0)

______________________________________________________________________________________________________________

## *Compatibility modes :*

If your game is poorly emulated, you can try to enable a [compatibility mode](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/Compatibility%20Modes.zip) to see if it helps.

<table class="wiki"> <tr> <td> <strong>Compatibility mode</strong> </td> <td> <strong>Description</strong> </td> <td> <strong>File Name</strong> </td> <td> <strong>Cheat code</strong> </td> </tr> <tr> <td> 0×01 </td> <td> help restoring the music/voices in several games </td> <td> PATCH_1.BIN </td> <td> $COMPATIBILITY_0×01 </td> </tr> <tr> <td> 0×02 </td> <td> a variant of mode 0×01, with a second hack for not breaking the MDECoding of FMVs (was designed for the Colony Wars series) </td> <td> PATCH_2.BIN </td> <td> $COMPATIBILITY_0×02 </td> </tr> <tr> <td> 0×03 </td> <td> can be used if the mode 0×01 doesn’t provide the expected results </td> <td> PATCH_3.BIN </td> <td> $COMPATIBILITY_0×03 </td> </tr> <tr> <td> 0×04 </td> <td> prevent the emulator from writing a garbage value in two of the virtual GPU registers (fixes slowdowns, flickering, and many other glitches) </td> <td> PATCH_4.BIN </td> <td> $COMPATIBILITY_0×04 </td> </tr> <tr> <td> 0×05 </td> <td> made for fixing the cutscenes of the PAL Resident Evil: Director’s Cut </td> <td> PATCH_5.BIN </td> <td> $COMPATIBILITY_0×05 </td> </tr> <tr> <td> 0×06 </td> <td> disable the OSD shell of the emulator’s built-in BIOS, making some games that freeze on startup run </td> <td> PATCH_6.BIN </td> <td> $COMPATIBILITY_0×06 </td> </tr> </table>

**Caution :** Modes 0×01, 0×02, 0×03 and 0×05 cannot be enabled in the same time or combined. These are variants of the same hack and they are conflicting, so use only use one of them at a time. Please let us know (at ASSEMblergames) if you managed to solve a problem in your game by forcing modes, so I could integrate the fix in POPStarter.

**How to use a mode ?**

3 options :

1. Using a PATCH_X.BIN file;

1. Using a CHEATS.TXT file;

1. Hardcoding the mode into POPStarter (see [configuration table](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/POPStarter%20Configuration%20Table)).

**Using [PATCH_X.BIN file](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/Compatibility%20Modes.zip)**
Copy the PATCH file in the VMC directory of your problematic game then test the game;
If the compatibility mode doesn’t solve any problem in your game, delete the PATCH file from the VMC directory and redo the operations with the next PATCH file.

**Using CHEATS.TXT file**
[See 6. Features section](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Cheat%20Engine).

______________________________________________________________________________________________________________

## *Game fixes (manual) :*

In the [Game Fixes Archive](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/Game%20Fixes.zip), you can find some TROJAN files fixing problematic games. Copy the file in the VMC directory of your problematic game.

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

[Here](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Automated) is the list of all the LC Cracks, crash fixes & compatibility modes integrated into POPStarter.

______________________________________________________________________________________________________________

## *Related stuff :*

You may want to give a look at this :

- [COMPATIBILITY] [Troubleshooting games](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Troubleshooting%20games)

______________________________________________________________________________________________________________

# [**Back**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/Home)
