<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/popstarter11 -->
<!-- primary snapshot: 20200812191235  |  3 captures, 2 distinct content version(s) -->
<!-- other distinct versions retained in _versions/popstarter11/: 20240825044156 -->
# popstarter11

# **POPStarter Rev 11 – Readme [2013/04/24 & 2013/04/30]**

______________________________________________________________________________________________________________

```
**************************
* POPStarter Revision 11 *
**************************
////////////////
PACKAGE CONTENTS
////////////////
__common/POPS/disc0			= The original virtual CD-ROM image of SLBB-00001
__common/POPS/EXECUTE.ELF		= The emulator, encapsulated in the POPStarter container (it's the "PORTABLE" build, a stand alone
ELF)
PP.YOUR_GAME_PARTITION/EXECUTE.KELF	= The emulator, encapsulated in the POPStarter container (it's a KryptoELF, for use with the
HDD OSD)
LAUNCHER.ELF				= The launcher which executes __common/POPS/EXECUTE.ELF
CUE2POPS_v1.2.zip			= BIN/CUE to IMAGE0.VCD conversion tool v1.2
README.TXT				= This file
----------------------------------------
I - EMULATOR INSTALLATION [IS DONE ONCE]
----------------------------------------
1) Mount the partition "__common" and create a directory called "POPS" (UPPERCASE) into it's root;
2) Copy the files "disc0" and "EXECUTE.ELF" in the "POPS" directory you've just created.
----------------------
II - GAME INSTALLATION
----------------------
1) Dump your game as BIN/CUE with your favorite disc replication software (must output a raw Mode 2 disc image and an ASCII cue
sheet);
2) Convert it to a POPS virtual CD-ROM image with "BIN/CUE to IMAGE0.VCD conversion tool v1.2" (CUE2POPS_1_2.EXE);
3) Create a parent partition in your PS2 HDD (example of a partition name : "PP.PBPX-95000.MY_GAME")
4) Transfer your virtual CD-ROM image (IT HAS TO BE NAMED "IMAGE0.VCD", UPPERCASE) to the root of the partition you've just created
&#62; For HDD OSD users &#60;
5) Setup your partition icons;
6) Copy the file "EXECUTE.KELF" to the root of the game partition, or write "EXECUTE.KELF" to the KELF field of PATINFO.
&#62; No HDD OSD ? &#60;
5) Setup your partition icons (optional);
7) Rename "LAUNCHER.ELF" as the name of the game partition (for example, if the game partition name is "PP.PBPX-95000.MY_GAME",
rename "LAUNCHER.ELF" as "PP.PBPX-95000.MY_GAME.ELF");
8) Copy the ELF you've just renamed to any place you want to run it from (examples : USB mass drive, +OPL partition, a folder in a
PS2 Memory Card...).
You may need uLaunchELF 4.42_ev and pfsshell-0.2a...
/////////////////////
OVERVIEW OF THE SETUP
/////////////////////
*****************************************************************************************************************************************************************************************
* PARTITION NAME		| FOLDER NAME	| SUB FOLDER NAME	| FILE NAME			| COMMENTS									*
*****************************************************************************************************************************************************************************************
* ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||| *
*****************************************************************************************************************************************************************************************
* __common			| POPS		| 			| disc0				| The SLBB-00001 VCD, must be present.						*
*****************************************************************************************************************************************************************************************
* __common			| POPS		|			| EXECUTE.ELF			| Not needed if you don't use the LAUNCHER.					*
*****************************************************************************************************************************************************************************************
* __common			| POPS		| GAME_PARTITION_NAME	| SLOT0.VMC			| Created by the emulator. Is the Virtual Memory Card of the first slot.	*
*****************************************************************************************************************************************************************************************
* __common			| POPS		| GAME_PARTITION_NAME	| SLOT1.VMC			| Created by the emulator. Is the Virtual Memory Card of the second slot.	*
*****************************************************************************************************************************************************************************************
* __common			| POPS		| GAME PARTITION_NAME	| BIOS.BIN			| User dumped BIOS. Optional.							*
*****************************************************************************************************************************************************************************************
* __common			| POPS		| GAME_PARTITION_NAME	| OSD.BIN			| User made OSD replacement file of Version 1. Optional.			*
*****************************************************************************************************************************************************************************************
* ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||| *
*****************************************************************************************************************************************************************************************
* PP.GAME_PARTITION_NAME	| 		| 			| IMAGE0.VCD			| The PlayStation game VCD, as it was converted by CUE2POPS. Required.		*
*****************************************************************************************************************************************************************************************
* PP.GAME_PARTITION_NAME	| 		| 			| EXECUTE.KELF			| Only needed when doing a BOOT2 = pfs:/EXECUTE.KELF installation (HDD OSD).	*
*****************************************************************************************************************************************************************************************
* ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||| *
*****************************************************************************************************************************************************************************************
* +OPL				| APPS		|			| PP.GAME_PARTITION_NAME.ELF	| It's an example of a LAUNCHER.ELF installation				*
*****************************************************************************************************************************************************************************************
/////////////
EXECUTION MAP
/////////////
EXECUTE.KELF (booting from the HDD OSD)	-&#62; POPS is running
LAUNCHER.ELF (properly renamed)		-&#62; __common/POPS/EXECUTE.ELF (NOT renamed) -&#62; POPS is running
EXECUTE.ELF  (properly renamed)		-&#62; POPS is running
/////////////////////////////////////
HIDING GAME PARTITIONS IN THE HDD OSD
/////////////////////////////////////
Put the partition prefix "__." instead of "PP.".
Examples :
"PP.PBPX-95000.MY_GAME"	==	Shown
"__.PBPX-95000.MY_GAME"	==	Hidden
"PP.SCUS-80085_FAPFAP"	==	Shown
"__.SCUS-80085_FAPFAP"	==	Hidden
"PP.SCUS-84115_BAMBAM"	==	Shown
"__.SCUS-84115_BAMBAM"	==	Hidden
Make sure you wrote a DOT right after __
As explained later in "VIRTUAL MEMORY CARD", the prefix has to be 3 characters long !
Of course, there's no point in hiding the partition if you want to run the game straight from the HDD OSD...
////////////////////
VIRTUAL MEMORY CARDS
////////////////////
VMCs are created by the emulator in __common/POPS/. One separate directory for each game partition.
Examples
__common/POPS/PBPX-95000.MY_GAME/SLOT0.VMC
__common/POPS/PBPX-95000.MY_GAME/SLOT1.VMC
__common/POPS/SCUS-80085_FAPFAP/SLOT0.VMC
__common/POPS/SCUS-80085_FAPFAP/SLOT1.VMC
__common/POPS/SCUS-84115_BAMBAM/SLOT0.VMC
__common/POPS/SCUS-84115_BAMBAM/SLOT1.VMC
The container skips the partition prefix when naming the VMC directory, so make sure you always name your partitions with a valid 3
chars prefix ("PP." or "__."); otherwise it will truncate the game name.
Examples :
Partition "PP.PBPX-95000.MY_GAME"	==	VMC directory "PBPX-95000.MY_GAME"
Partition "PP.SCUS-80085_FAPFAP"	==	VMC directory "SCUS-80085_FAPFAP"
Partition "PP.SCUS-84115_BAMBAM"	==	VMC directory "SCUS-84115_BAMBAM"
Partition "__.PBPX-95000.MY_GAME"	==	VMC directory "PBPX-95000.MY_GAME"
Partition "__.SCUS-80085_FAPFAP"	==	VMC directory "SCUS-80085_FAPFAP"
Partition "__.SCUS-84115_BAMBAM"	==	VMC directory "SCUS-84115_BAMBAM"
///////////////
VIRTUAL CD-ROMs
///////////////
The virtual CD-ROM images has to be named "IMAGE0.VCD" (UPPERCASE)  and located in the root of your game partition.
Examples
PP.PBPX-95000.MY_GAME/IMAGE0.VCD
PP.SCUS-80085_FAPFAP/IMAGE0.VCD
PP.SCUS-84115_BAMBAM/IMAGE0.VCD
One copy of the original "disc0" has to be placed in __common/POPS/ (where "__common" is a system PARTITION and "POPS" is a
DIRECTORY).
__common/POPS/disc0
////////////////
PLAYSTATION BIOS
////////////////
You can use a PlayStation BIOS dump with POPS. Put a "BIOS.BIN" file in the VMC directory (example :
__common/POPS/PBPX-95000.MY_GAME/BIOS.BIN) so POPStarter can handle it.
If you didn't, POPS will use the built-in BIOS in fast boot mode (no PS OSD, just like POPStarter Rev.9 does).
///////////////////////////
PLAYSTATION OSD REPLACEMENT
///////////////////////////
POPStarter Revision 11 can replicate the PS-X EXE injection and execution method that was the heart of the POC1.
If you put an OSD replacement image in the VMC directory, named as "OSD.BIN" (example : __common/POPS/PBPX-95000.MY_GAME/OSD.BIN),
the container will inject it in the built-in BIOS for POPS to run it.
When using a OSD replacement file, the container ignores "BIOS.BIN" (no user defined BIOS execution is possble).
////////////////////
MBR CALLBACK aka IGR
////////////////////
Your pad does not respond after pressing L1+START+SELECT ? Just disconnect the second pad or use the second pad to validate your
choice o_O.
@@@@@@@@@
BLAH BLAH
@@@@@@@@@
Thanks to everyone who helped me in the making of POPStarter and CUE2POPS, with tests, bug reports and encouragements.
This should be the last revision of the container, as the POC2 (aka POPS-00001) is now obsolete... unless someone reports a critical
problem/bug/error.
My respect and gratitude to the former project maintainers. It has been a pleasure working with you, in despite of the bullshit that
followed the release of the second POC and the abortion of the development.
Please do not bother me if you wanna make an installer. I'm not interested in spending more of my time in POPS related stuff (other
than container/CUE2POPS bugs)...
Feel free to spread the binaries, pack them with an installer you made, improve CUE2POPS etc etc... but please, do not waste my damn
work like some lamers did with teh POPS-00001.
Hope u liek that release and find it useful.
---------
CHANGELOG
---------
POPStarter Revision 11 - 2013/04/30
+ Fixed BIOS &#38; OSD handlers activation failure in EXECUTE.KELF
POPStarter Revision 11 - 2013/04/24
+ Added the "ELF name to argument" thing in LAUNCHER (LAUNCHER.ELF) and PORTABLE (EXECUTE.ELF) builds
+ Solved a file length problem in the OSD replacement file handler
+ Now displays enrypoint relocations of OSD replacement files (limited to jumps from the segment start and the EOF)
+ LAUNCHER, PORTABLE and KEXEC builds were packaged all together
POPStarter Revision 10 [PATINFO/KEXEC Bundle] - 2013/04/19
+ Added on-screen debug info at container startup
+ Added an error handler
+ Added an user BIOS handler
+ Added an OSD replacement image handler
+ Fixed a bug in VMC directory naming
+ Container protections were completely rewritten
POPStarter Revision 9 [PATINFO/KEXEC Bundle] - 2013/04/09
First public release
kHn, 2013/04/30

```

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
