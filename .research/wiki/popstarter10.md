<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/popstarter10 -->
<!-- primary snapshot: 20240825044156  |  2 captures, 1 distinct content version(s) -->
# popstarter10

# **POPStarter Rev 10 – Readme [2013/04/19]**

______________________________________________________________________________________________________________

## *PATINFO/KEXEC Bundle*

```
*************************************************
* POPStarter Revision 10 [PATINFO/KEXEC Bundle] *
*************************************************
[       SUITABLE FOR HDD OSD INSTALLATION       ]
#################################################
----------------
PACKAGE CONTENTS
----------------
__common/POPS/disc0 = Original virtual CD-ROM image of SLBB-00001
PP.YOUR_GAME_PARTITION/EXECUTE.KELF = The emulator, encapsulated in the POPStarter container (KryptoELF)
CUE2POPS_v1.1.zip = BIN/CUE to IMAGE0.VCD conversion tool v1.1
README.TXT = This file
---------------------
EMULATOR INSTALLATION
---------------------
1) Mount the partition "__common" and create a directory called "POPS" (UPPERCASE) into it's root;
2) Open the "POPS" directory you've just created and put the file "disc0" into it;
3) Mount the PlayStation game partition and put the file "EXECUTE.KELF" into it's root, OR raw-write
"EXECUTE.KELF" to the PATINFO field of the game partition.
-----------------
GAME INSTALLATION
-----------------
1) Dump your game as BIN/CUE with your favorite disc replication software (must output a raw Mode 2 disc
image and an ASCII cue sheet);
2) Convert it to a POPS virtual CD-ROM image with "BIN/CUE to IMAGE0.VCD conversion tool v1.1" (CUE2POPS_1_1.EXE);
3) Create a parent partition in your PS2 HDD (example of a partition name : PP.PBPX-95000.MY_GAME);
4) Transfer your virtual CD-ROM image (HAVE TO BE RENAMED AS IMAGE0.VCD, UPPERCASE) to the root of the partition
you've just created;
5) Put the file "EXECUTE.KELF" into the root of the game partition, OR raw-write "EXECUTE.KELF" to the PATINFO
field of the game partition.
6) Not detailed here : Set up your game partition info/icons
You may need uLaunchELF 4.42_ev and pfsshell-0.2a...
--------------------
VIRTUAL MEMORY CARDS
--------------------
VMCs are created by the emulator in __common/POPS/. One separate directory for each game partition.
The container truncates the partition prefix, so make sure you always name your partitions with the parent
partition prefix (PP.); otherwise it will truncate the game name.
---------------
VIRTUAL CD-ROMs
---------------
Virtual CD-ROM images have to be named "IMAGE0.VCD" (UPPERCASE)  and located in the root of your game partitions.
One copy of the original "disc0" has to be placed in __common/POPS/ (where "__common" is a system PARTITION and
"POPS" is a DIRECTORY).
----------------
PLAYSTATION BIOS
----------------
You can use a PlayStation BIOS dump with POPS. Put a "BIOS.BIN" file in the VMC directory (example :
__common/POPS/PBPX-95000.MY_GAME/BIOS.BIN) so POPStarter can handle it.
If you didn't, the container will just use the built-in BIOS in fast boot mode (no OSD, just like POPStarter
Rev.9 does).
------------------
PS OSD REPLACEMENT
------------------
POPStarter Revision 10 can replicate the PS-X EXE injection and execution method that was the heart of the POC1.
If you put an OSD replacement image in the VMC directory, named as "OSD.BIN" (example :
__common/POPS/PBPX-95000.MY_GAME/OSD.BIN), the container will inject it in the built-in BIOS for POPS to run it.
--------------------
MBR CALLBACK aka IGR
--------------------
Your pad does not respond after pressing L1+START+SELECT ? Just disconnect the second pad or use the second pad
to validate your choice o_O.
---------
CHANGELOG
---------
POPStarter Revision 10 [PATINFO/KEXEC Bundle] - 2013/04/19
+ Added on-screen debug info at container startup
+ Added an error handler
+ Added an user BIOS handler
+ Added an OSD replacement image handler
+ Fixed a bug in VMC directory naming
+ Container protections were completely rewritten
POPStarter Revision 9 [PATINFO/KEXEC Bundle] - 2013/04/09
First public release
kHn, 2013/04/19
```

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
