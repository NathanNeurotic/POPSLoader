<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/multi-disc -->
<!-- primary snapshot: 20250110103459  |  21 captures, 4 distinct content version(s) -->
<!-- other distinct versions retained in _versions/multi-disc/: 20170629121927, 20170812163854, 20240618063809 -->
# multi-disc

# **Swap disc feature**

______________________________________________________________________________________________________________

You can now play multi-discs games with POPS.

1. Create a DISCS.TXT text file containing the file names of your VCDs, one file name per line (with VCD extension)  ;

```
DISCS.TXT line 1 = disc 1
DISCS.TXT line 2 = disc 2
DISCS.TXT line 3 = disc 3
DISCS.TXT line 4 = disc 4
```

**Example :**

```
MGS_CD1.VCD
MGS_CD2.VCD
[Empty]
[Empty]
```

2. Copy/paste this DISCS.TXT file to the VMC folders of ALL your game discs ;

3. When required by the game, open the lid using the hotkey ;

4. Insert the disc you want to load using the hotkey ;

5. Close the lid using the hotkey.

**Hotkeys :**

- To open the lid : Select + L2 + R2 + △

- To insert Disc 1 : Select + L2 + R2 + ↑

- To insert Disc 2 : Select + L2 + R2 + →

- To insert Disc 3 : Select + L2 + R2 + ↓

- To insert Disc 4 : Select + L2 + R2 + ←

- To close the lid : Select + L2 + R2 + □

**Limitations :**

- Up to 4 file names in DISCS.TXT ;

- A file name must not exceed 89 characters ;

- The VCD files have to be in the same partition/folder ;

- If you have more than 4 lines in the DISCS.TXT file, the feature will not work.

**Example of working setup :**

```
mass:/POPS/MGS_CD1.VCD
mass:/POPS/MGS_CD2.VCD
mass:/POPS/XX.MGS_CD1.ELF
mass:/POPS/XX.MGS_CD2.ELF
mass:/POPS/MGS_CD1/DISCS.TXT
mass:/POPS/MGS_CD2/DISCS.TXT
```

DISCS.TXT content :

```
MGS_CD1.VCD
MGS_CD2.VCD
```

**Notes :**

- The swap disc feature is useful only if you must swap discs **without any PS1 reboot**. For the other games, you only need to swap the VMCs manually (copy/paste VMCs from VMC disc 1 folder to VMC disc 2 folder) – or you can use the “trick” below to avoid such a manipulation ;

- If your game has more than 4 discs, install the forth first ones, play them until disc 4, then uninstall discs 1, 2 and 3, and install disc 5, 6, 7…

- Does not work properly with all games ((not working with Final Fantasy IX and Grandia) ;

- Multi disc games [combined](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/Disc_Combining_Kits.7z) to single VCDs still work, up to ~2GB per VCD.

______________________________________________________________________________________________________________

## *Use a single pair of VMCs for multi-disc games :*

You can use the VMCDIR.TXT file to use only 1 pair of VMCs for a multi-disc game. This VMCDIR.TXT must be placed into disc 1 and disc 2 VMC game folders. Read [here](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/vmc) to know more about the VMCDIR.TXT file (“Setting a path for the VMC folder” section).

**Example :**

```
mass:/POPS/MGS_CD1.VCD
mass:/POPS/MGS_CD2.VCD
mass:/POPS/XX.MGS_CD1.ELF
mass:/POPS/XX.MGS_CD2.ELF
mass:/POPS/MGS_CD1/DISCS.TXT
mass:/POPS/MGS_CD1/VMCDIR.TXT
mass:/POPS/MGS_CD2/DISCS.TXT
mass:/POPS/MGS_CD2/VMCDIR.TXT
```

DISCS.TXT content :

```
MGS_CD1.VCD
MGS_CD2.VCD
```

VMCDIR.TXT content (= CD1 VMC game folder) :

```
MGS_CD1
```

In this situation, disc 1 and disc 2 share the same VMC folder.

______________________________________________________________________________________________________________

## *DISCS POOPER*

DISCS_POOPER is a little program that does the boring job for you.

- **Download :** [here](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/downloads/DISCS_POOPER.BAT.7z)

**How to use it :**

1. Create a new folder ;

2. Drop the VCD files of your multic-disc game in it ;

3. Drop DISCS_POOPER.EXE in the folder and run it ;

DISCS_POOPER creates :

. A VMC folder for each VCD in the folder ;

. A DISCS.TXT inside each VMC folder ;

. A VMCDIR.TXT inside each VMC to use only a pair of VMC for this multi-disc game.

4. Move your VCD and VMC game folders to your POPS folder ;

5. Enjoy.

**Limits :**

. Doesn’t comply with 4 CDs limit of the swap disc feature (don’t use it with more than 4 VCDs) ;

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
