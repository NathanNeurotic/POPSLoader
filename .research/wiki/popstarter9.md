<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/popstarter9 -->
<!-- primary snapshot: 20200804035332  |  3 captures, 2 distinct content version(s) -->
<!-- other distinct versions retained in _versions/popstarter9/: 20240825044156 -->
# popstarter9

# **POPStarter Rev 9 – Readme [2013/04/10]**

______________________________________________________________________________________________________________

## *LAUNCHER Bundle*

```
*********************************************
*  POPStarter Revision 9 [LAUNCHER Bundle]  *
*********************************************
[ SUITABLE FOR EXECUTION FROM OTHER DEVICES ]
#############################################
----------------
PACKAGE CONTENTS
----------------
__common/POPS/disc0 = Original virtual CD-ROM image of SLBB-00001
PP.YOUR_GAME_PARTITION/EXECUTE.ELF = The emulator, encapsulated in the POPStarter container (ELF)
LAUNCHER.ELF = The launcher that executes "EXECUTE.ELF"
CUE2POPS_v1.zip = BIN/CUE to IMAGE0.VCD conversion tool v1.0
README.TXT = This file
---------------------
EMULATOR INSTALLATION
---------------------
1) Mount the partition "__common" and create a directory called "POPS" (UPPERCASE) into it's root;
2) Open the "POPS" directory you've just created and put the file "disc0" into it;
3) Hardcode the name of your PlayStation game partition in "LAUNCHER.ELF" (31 CHARACTERS MAX, TERMINATED WITH 00h),
at offset 60h (decimal 96);
4) Mount the PlayStation game partition and put the file "EXECUTE.ELF" into it's root,
5) Copy your modified "LAUNCHER.ELF" anywhere you want to run it from.
-----------------
GAME INSTALLATION
-----------------
1) Dump your game as BIN/CUE with your favorite disc replication software (must output a raw Mode 2 disc image and an ASCII cue sheet);
2) Convert it to a POPS virtual CD-ROM image with "BIN/CUE to IMAGE0.VCD conversion tool v1.0" (CUE2POPS.EXE);
3) Create a parent partition in your PS2 HDD (example of a partition name : PP.PBPX-95000.MY_GAME);
4) Transfer your virtual CD-ROM image (HAVE TO BE RENAMED AS IMAGE0.VCD, UPPERCASE) to the root of the partition you've just created;
5) Put the file "EXECUTE.ELF" into the root of the game partition;
6) Not detailed here : Set up your game partition info/icons.
You may need uLaunchELF 4.42_ev and pfsshell-0.2a...
-------------
EXECUTION MAP
-------------
somedevice:/LAUNCHER.ELF -&#62; hdd0:/PP.PLAYSTATION_GAME_PARTITION/EXECUTE.ELF -&#62; POPS is running
* Firstly, LAUNCHER.ELF is executed by the user. Then LAUNCHER.ELF executes EXECUTE.ELF
- LAUNCHER.ELF have to know the location of EXECUTE.ELF, so you must hardcode the partition name at LAUNCHER.ELF's offset 60h.
- LAUNCHER.ELF can be renamed if necessary.
- EXECUTE.ELF can NOT be renamed or altered in any way, and have to be placed in the root of the game partition (along with IMAGE0.VCD)
- EXECUTE.ELF can NOT run directly. You must launch it by executing LAUNCHER.ELF
-----------------------------------
HIDING THE PARTITION IN THE HDD OSD
-----------------------------------
Optionally to BOOT2 = NOBOOT, you can hide the game partition in the PlayStation 2 HDD browser.
By replacing the parent partition prefix "PP." with "___" (_ three times) and putting at least one "." (dot) in the partition name.
Example :
PP.MY_GAME [VISIBLE]
___MY_GAME [WRONG !]
___MY.GAME [HIDDEN]
The system partition prefix is normally "__", but due to a container limitation, the partition name must comply that particular syntax.
--------------------
VIRTUAL MEMORY CARDS
--------------------
VMCs are created by the emulator in __common/POPS/. One separate directory for each game partition.
The container truncates the partition prefix, so make sure you always name your partitions with the parent partition prefix (PP.) or the hidden partition prefix (___); otherwise it will truncate the game name.
---------------
VIRTUAL CD-ROMs
---------------
Have to be named "IMAGE0.VCD" and located in the root of the game partition.
One copy of the original "disc0" have to be placed in __common/POPS/
--------------------
MBR CALLBACK aka IGR
--------------------
Your pad does not respond after pressing L1+START+SELECT ? Just disconnect the second pad or use the second pad to validate your choice o_O.
kHn, 2013/04/09

```

______________________________________________________________________________________________________________

## *PATINFO/KEXEC Bundle*

```
************************************************
* POPStarter Revision 9 [PATINFO/KEXEC Bundle] *
************************************************
[      SUITABLE FOR HDD OSD INSTALLATIONS      ]
################################################
----------------
PACKAGE CONTENTS
----------------
__common/POPS/disc0 = Original virtual CD-ROM image of SLBB-00001
PP.YOUR_GAME_PARTITION/EXECUTE.KELF = The emulator, encapsulated in the POPStarter container (KryptoELF)
CUE2POPS_v1.zip = BIN/CUE to IMAGE0.VCD conversion tool v1.0
README.TXT = This file
---------------------
EMULATOR INSTALLATION
---------------------
1) Mount the partition "__common" and create a directory called "POPS" (UPPERCASE) into it's root;
2) Open the "POPS" directory you've just created and put the file "disc0" into it;
3) Mount the PlayStation game partition and put the file "EXECUTE.KELF" into it's root, OR raw-write "EXECUTE.KELF" to the PATINFO field of the game partition.
-----------------
GAME INSTALLATION
-----------------
1) Dump your game as BIN/CUE with your favorite disc replication software (must output a raw Mode 2 disc image and an ASCII cue sheet);
2) Convert it to a POPS virtual CD-ROM image with "BIN/CUE to IMAGE0.VCD conversion tool v1.0" (CUE2POPS.EXE);
3) Create a parent partition in your PS2 HDD (example of a partition name : PP.PBPX-95000.MY_GAME)
4) Transfer your virtual CD-ROM image (HAVE TO BE RENAMED AS IMAGE0.VCD, UPPERCASE) to the root of the partition you've just created
5) Put the file "EXECUTE.KELF" into the root of the game partition, OR raw-write "EXECUTE.KELF" to the PATINFO field of the game partition.
6) Not detailed here : Set up your game partition info/icons
You may need uLaunchELF 4.42_ev and pfsshell-0.2a...
--------------------
VIRTUAL MEMORY CARDS
--------------------
VMCs are created by the emulator in __common/POPS/. One separate directory for each game partition.
The container truncates the partition prefix, so make sure you always name your partitions with the parent partition prefix (PP.); otherwise it will truncate the game name.
---------------
VIRTUAL CD-ROMs
---------------
Have to be named "IMAGE0.VCD" and located in the root of the game partition.
One copy of the original "disc0" have to be placed in __common/POPS/
--------------------
MBR CALLBACK aka IGR
--------------------
Your pad does not respond after pressing L1+START+SELECT ? Just disconnect the second pad or use the second pad to validate your choice o_O.
kHn, 2013/04/09

```

______________________________________________________________________________________________________________

## *PORTABLE Bundle*

```
*********************************************
*  POPStarter Revision 9 [PORTABLE Bundle]  *
*********************************************
[ SUITABLE FOR EXECUTION FROM OTHER DEVICES ]
#############################################
----------------
PACKAGE CONTENTS
----------------
__common/POPS/disc0 = Original virtual CD-ROM image of SLBB-00001
POPSTARTER_REV9.ELF = The emulator, encapsulated in the POPStarter container (Stand alone ELF)
CUE2POPS_v1.zip = BIN/CUE to IMAGE0.VCD conversion tool v1.0
README.TXT = This file
---------------------
EMULATOR INSTALLATION
---------------------
1) Mount the partition "__common" and create a directory called "POPS" (UPPERCASE) into it's root;
2) Open the "POPS" directory you've just created and put the file "disc0" into it;
3) Hardcode the name of your PlayStation game partition in "POPSTARTER_REV9.ELF" (31 CHARACTERS MAX, TERMINATED WITH 00h), at offset 60h (decimal 96);
4) Copy your modified "POPSTARTER_REV9.ELF" anywhere you want to run it from.
-----------------
GAME INSTALLATION
-----------------
1) Dump your game as BIN/CUE with your favorite disc replication software (must output a raw Mode 2 disc image and an ASCII cue sheet);
2) Convert it to a POPS virtual CD-ROM image with "BIN/CUE to IMAGE0.VCD conversion tool v1.0" (CUE2POPS.EXE);
3) Create a parent partition in your PS2 HDD (example of a partition name : PP.PBPX-95000.MY_GAME);
4) Transfer your virtual CD-ROM image (HAVE TO BE RENAMED AS IMAGE0.VCD, UPPERCASE) to the root of the partition you've just created;
You may need uLaunchELF 4.42_ev and pfsshell-0.2a...
-------------
EXECUTION MAP
-------------
somedevice:/POPSTARTER_REV9.ELF -&#62; POPS is running
* POPSTARTER_REV9.ELF can be run from any device. Unlike the "LAUNCHER Bundle", it does not require another ELF to be copied to the HDD.
- POPSTARTER_REV9.ELF have to know which partition to mount, so you must hardcode the partition name at POPSTARTER_REV9.ELF's offset 60h.
- POPSTARTER_REV9.ELF can be renamed if necessary.
-----------------------------------
HIDING THE PARTITION IN THE HDD OSD
-----------------------------------
Optionally to BOOT2 = NOBOOT, you can hide the game partition in the PlayStation 2 HDD browser.
By replacing the parent partition prefix "PP." with "___" (_ three times) and putting at least one "." (dot) in the partition name.
Example :
PP.MY_GAME [VISIBLE]
___MY_GAME [WRONG !]
___MY.GAME [HIDDEN]
The system partition prefix is normally "__", but due to a container limitation, the partition name must comply that particular syntax.
--------------------
VIRTUAL MEMORY CARDS
--------------------
VMCs are created by the emulator in __common/POPS/. One separate directory for each game partition.
The container truncates the partition prefix, so make sure you always name your partitions with the parent partition prefix (PP.) or the hidden partition prefix (___); otherwise it will truncate the game name.
---------------
VIRTUAL CD-ROMs
---------------
Have to be named "IMAGE0.VCD" and located in the root of the game partition.
One copy of the original "disc0" have to be placed in __common/POPS/
--------------------
MBR CALLBACK aka IGR
--------------------
Your pad does not respond after pressing L1+START+SELECT ? Just disconnect the second pad or use the second pad to validate your choice o_O.
kHn, 2013/04/10

```

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
