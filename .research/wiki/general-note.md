<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/general-note -->
<!-- primary snapshot: 20200812192725  |  5 captures, 3 distinct content version(s) -->
<!-- other distinct versions retained in _versions/general-note/: 20170629125310, 20240324023511 -->
# general-note

# **General note :**

______________________________________________________________________________________________________________

POPStarter is able to handle external files, so you can configure its settings, even though POPStarter is a GUI-less app. These external files come as TROJAN_#BIN, PATCH_#.BIN, BIOS.BIN, OSD.BIN, CHEATS.TXT, VMCDIR.TXT, DISCS.TXT...
These files can be placed into 2 different locations : POPS folder and VMC game folder.

As general rule :

- If a TROJAN_#BIN, PATCH_#.BIN, BIOS.BIN, OSD.BIN, CHEATS.TXT, VMC.DIR, WHATEVER... is placed into POPS folder, it will be applied to ALL games ;

- If a TROJAN_#BIN, PATCH_#.BIN, BIOS.BIN, OSD.BIN, CHEATS.TXT, VMC.DIR, WHATEVER... is placed into the game VMC folder, it will be applied to only this particular game ;

- POPStarter can handle multiple different external files at the same time ;

- POPStarter can handle multiple different external files at the same time from different locations.

**Example :**

```
POPS/PATCH_1.BIN
POPS/Crash Bandicoot (PAL)/CHEATS.TXT

```

Here, PATCH_1.BIN will be applied to all games while the CHEATS.TXT file will be only applied/active for Crash Bandicoot (PAL) game.

- When you use multiple external files **of same type** from both POPS folder and VMC game folder, the file which is in the VMC folder has priority;

**Example :**

```
POPS/TROJAN_2.BIN
POPS/Crash Bandicoot (PAL)/TROJAN_2.BIN

```

Here, only POPS/Crash Bandicoot/TROJAN_2.BIN will be applied.

- Only exception to this rule is when two CHEATS.TXT files are loaded from POPS and VMC game folder at the same time and that CHEATS.TXT file contains special command changing the video mode.

```
POPS/CHEATS.TXT --- with $480p written in it
POPS/Crash Bandicoot (PAL)/CHEATS.TXT --- with $FORCEPAL written in it

```

Here, 480p has priority and $FORCEPAL will not be applied.

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
