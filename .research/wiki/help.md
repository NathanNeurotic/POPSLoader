<!-- source: https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/help -->
<!-- primary snapshot: 20200804033921  |  6 captures, 3 distinct content version(s) -->
<!-- other distinct versions retained in _versions/help/: 20170629111840, 20240905220418 -->
# help

# **POPStarter Help**

______________________________________________________________________________________________________________
*[From wip05 documentation – ! outdated for some parts !]*

**POPStarter takes you to the PS2 browser after you launch it. All you can see is a black screen, then the PS2 menu**

- Verify your POPS, game and POPStarter installations.

- Apply DEBUG_AND_HALT.PPF to your POPStarter ELF/KELF. That will activate the display of the debug texts, so you can see what goes wrong.

- Take a look at the official release topic at ASSEMblergames and possibly ask for help.

**POPStarter finds your VCD, but the emulator does not and kicks you to the PS2 browser**

- Make sure the .VCD extension is UPPERCASE. The emulator is case sentitive.

**Your installation is correct but POPStarter fails to find your VCD**

- If the path of your POPStarter ELF is too long and gets truncated by the launcher, shorten the VCD name or put the ELF in the root of your device

- If the launcher you use for executing the POPStarter ELF does not send a valid argument, use another launcher like uLE, FMCB, FHDB...

**Your game is a European game but POPStarter fails to recognize it as a European game**

- Did you modify the boot logo or the license text of your game dump ?

- Did you patch it with a crack/trainer/translation (some groups/hackers make patches that replace the license text with their name/website URL...) ?

- Did you dump the game disc properly (there are softwares like UltraISO that rebuild the disc image instead of making a proper 1:1 raw copy) ?

- Check your disc dump integrity against [http://redump.org/](http://redump.org/)

- If the patch you’ve applied has messed up the license sectors, re-inject a valid European license in your dump/VCD.

- Also verify that you didn’t disable the Automatic PAL Patch feature of POPStarter.

If you can’t solve the problem and need to fix the screen position, choose one of those solutions :

- Use GSM to force the video output in NTSC (don’t set it in PAL, or you’ll get slowdowns and audio stuttering due to the emulator being clocked for NTSC)

- Patch your game dump to NTSC, using a software like Zapper 2000, PAL4U 2000 or the “vmode” function of CUE2POPS (NOT recommended)

- Force POPStarter to patch the emulator in PAL, by copying PATCH_8.BIN into the VMC directory of your game

**Your PAL game is NTSC patched, and its display is no longer centered because POPStarter patches the emulator in PAL**

- I’d recommend you reinstall an unaltered copy of your game.

Disabling the Automatic PAL Patcher is possible, just by copying the attached PATCH_9.BIN into the VMC directory of your game. If you want to disable the Automatic PAL Patcher for all your games, copy PATCH_9.BIN in the POPS directory instead of the games VMC directories.
Advanced users can also hardcode this setting in the [configuration table](https://bitbucket.org/SaulGoodman/popstarter-wiki/wiki/9.%20POPStarter%20Advanced%20Configuration) of the POPStarter ELF/KELF

**PAL sucks. You want to force NTSC display using GSM for playing all your PAL games in NTSC**

- You have to disable POPStarter’s PAL patcher first : copy the attached PATCH_9.BIN into the POPS directory. Then you can use GSM.

**Your game does not run and seems to stall while the PS OSD performs the disc auth (compatibility issue)**

- Put a PS BIOS in the VMC directory of your game (the BIOS region must match your game region, or be region-free), name it BIOS.BIN.

- If the game still does not run, delete the BIOS.BIN file you’ve copied and try the Compatibility Mode 0×06.

- If the game still does not run, the reason of the stall is something else that can’t be fixed for now.

**Your game isn’t emulated very well, and it isn’t in the POPStarter internal database**

- Go to the official release topic at ASSEMblergames to see if a new POPStarter version is available or if a PATCH/TROJAN for your game has been published

- Try the compatibility modes. This POPStarter build has 6 compatibility modes.

  1. Compatibility mode 0×01 helps restoring the music/voices in several games

  1. Compatibility mode 0×02 is a variant of mode 0×01, with a second hack for not breaking the MDECoding of FMVs (was designed for the Colony Wars series)

  1. Compatibility mode 0×03 can be used if the mode 0×01 doesn’t provide the expected results

  1. Compatibility mode 0×04 prevents the emulator from writing a garbage value in two of the virtual GPU registers (fixes slowdowns, flickering, and many other glitches)

  1. Compatibility mode 0×05 was made for fixing the cutscenes of the PAL Resident Evil: Director’s Cut.

  1. Compatibility mode 0×06 disables the OSD shell of the emulator’s built-in BIOS, making some games that freeze on startup run

Don’t combine modes 0×01, 0×02, 0×03 and 0×05. Activate only one of them, because they’re conflicting. Please let us know (at ASSEMblergames) if you managed to solve a problem in your game by forcing modes, so I could integrate the fix in POPStarter.

**/software name here/ always add a + character in the name of the partition you’re trying to create**

- Download and use the latest version of Akuhak’s unofficial LaunchELF build. At the time I write this help file, it is ule_wip7. Go check for update !

**/software name here/ cannot access the __common partition. It is hidden, or its access is denied**

- Download and use the latest version of Akuhak’s unofficial LaunchELF build. At the time I write this help file, it is ule_wip7. Go check for update !

**You can’t see the __.POPS partition you’ve created in the FileManager of uLE when browsing your internal HDD**

- Download and use the latest version of Akuhak’s unofficial LaunchELF build. At the time I write this help file, it is ule_wip7. Go check for update !

**You can’t create a __.POPS partition larger than 2GB**

- Download and use the latest version of Akuhak’s unofficial LaunchELF build. At the time I write this help file, it is ule_wip7. Go check for update ! There’s a link in 0-INTRODUCTION.TXT

**You made a 128GB __.POPS partition, it’s full, and you want to intall more VCDs in this HDD**

- Create another partition named __.POPS0 When using this launch type, POPStarter mounts and scans the partitions in this order : __.POPS -> __.POPS0 -> __.POPS1 -> __.POPS2 -> __.POPS3 -> __.POPS4 -> __.POPS5 -> __.POPS6 -> __.POPS7 -> __.POPS8 -> __.POPS9

**POPStarter cannot find the “POPS” directory which is in the root of your USB drive**

1. Make sure its filesystem is FAT12, FAT16 or FAT32

1. Make sure the POPS directory is in the ROOT of your USB drive, and that it contains POPS.PAK, PFS_WRAP.BIN and your VCDs

1. If the problem couldn’t be solved at this point, increase the USB access delay (offset $413 of the config table)

**A new version of the PFS Wrapper is out, and you want to use it with this POPStarter build**

1. Read carefully the PFS Wrapper documentation (if any) or the author’s post, in case it has been specified that it’s not compatible with this POPStarter build;

1. Replace the installed PFS_WRAP.BIN file with the new one;

1. If the PFS Wrapper comes with USBD.IRX or USBHDFSD.IRX modules (or both), copy it in your POPS directory, otherwise POPStarter’s embedded modules will be used by POPS.

______________________________________________________________________________________________________________

### [**Index**](https://bitbucket.org/ShaolinAssassin/popstarter-documentation-stuff/wiki/index)
